/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { wantAgent, common } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {AppStorageKeys,  Logger, MusicStoreService } from 'musicbasic';

/** Serializes start/stop so a pending WantAgent cannot restart a disabled task. */
export class BackgroundUtil {
  private static requested: boolean = false;
  private static running: boolean = false;
  private static observingCancel: boolean = false;
  private static observingSuspend: boolean = false;
  private static failureShown: boolean = false;
  private static operations: Promise<void> = Promise.resolve();
  /** 由 MediaService 注入的判定：现在是否仍需要长时任务（真在出声 / 待焦点恢复）。 */
  private static shouldHoldTask: (() => boolean) | undefined = undefined;
  /** 最近一次 start/stop 用的 context（系统取消回调里补申请时复用）。 */
  private static lastContext: common.UIAbilityContext | undefined = undefined;
  /** 最近一次 start 成功的墙钟：用来判断"这次任务活了多久"（见 tryRequeue）。 */
  private static startedAt: number = 0;
  /** 补申请的冷却时间（ms）：系统取消后**不要立刻**重申请，避免"取消风暴"变成忙等。 */
  private static readonly REQUEUE_DELAY_MS: number = 1500;
  /** 限流窗口（ms）与窗口内允许的最大补申请次数。 */
  private static readonly REQUEUE_WINDOW_MS: number = 120000;
  private static readonly REQUEUE_MAX: number = 3;
  /** 任务活过这么久，才算"上次补申请有效"，可把窗口计数清零。 */
  private static readonly REQUEUE_RESET_AFTER_MS: number = 30000;
  private static requeueWindowStart: number = 0;
  private static requeueCount: number = 0;
  private static requeuePending: boolean = false;

  /** 注入「是否仍需要长时任务」的判定（MediaService 启动时调用一次）。 */
  public static setTaskHoldPredicate(predicate: () => boolean): void {
    BackgroundUtil.shouldHoldTask = predicate;
  }

  private static diagnostic(message: string): void {
    const line: string = '[RzdLockScreenB] ' + message;
    Logger.info(line);
    MusicStoreService.getInstance().appendRuntimeDiagnostic(line);
  }

  /**
   * 长时任务状态快照，只用于日志取证（`requested` = 应用想要，`running` = 系统已受理）。
   * @returns 形如 `task req=1 run=1` 的一行文本
   */
  public static snapshot(): string {
    return `task req=${BackgroundUtil.requested ? 1 : 0} run=${BackgroundUtil.running ? 1 : 0}`;
  }

  public static startContinuousTask(context?: common.UIAbilityContext): void {
    BackgroundUtil.requested = true;
    if (context !== undefined) {
      BackgroundUtil.lastContext = context;
    }
    BackgroundUtil.enqueue(context);
  }

  public static stopContinuousTask(context: common.UIAbilityContext): void {
    BackgroundUtil.requested = false;
    BackgroundUtil.diagnostic('stop-continuous requested');
    BackgroundUtil.enqueue(context);
  }

  private static enqueue(context?: common.UIAbilityContext): void {
    BackgroundUtil.operations = BackgroundUtil.operations.then(async (): Promise<void> => {
      await BackgroundUtil.reconcile(context);
    }).catch((error: BusinessError): void => {
      BackgroundUtil.diagnostic(`continuous-queue(err=${error.code}) msg=${error.message}`);
    });
  }

  /**
   * 系统取消长时任务后，若"应用仍想要 + 真在出声（或待焦点恢复）"就补申请。
   *
   * ★ 2026-11-15（合并 PR #12，并按官方文档收紧）：
   *   - **只对 `SYSTEM_CANCEL`(2) 补**。`USER_CANCEL`(1) 是用户在通知栏主动取消，
   *     立刻再申请回来等于跟用户对着干，系统侧也有"非法使用后台任务"这类处置。
   *   - 上限不能"成功即清零"（那样等于无上限）：改成**时间窗限流** + **冷却 1.5s**，
   *     只有任务活过 30s 才认为这次补申请是有效的、允许重置计数。
   * @param why 触发来源（写进日志，方便 grep）
   * @param reason 官方取消原因码
   */
  private static tryRequeue(why: string, reason: number): void {
    if (!BackgroundUtil.requested) {
      BackgroundUtil.diagnostic(`requeue-skip why=${why} reason=${reason} (app stopped asking)`);
      return;
    }
    const hold: boolean = BackgroundUtil.shouldHoldTask !== undefined ?
      BackgroundUtil.shouldHoldTask() : false;
    if (!hold) {
      BackgroundUtil.diagnostic(`requeue-skip why=${why} reason=${reason} (nothing to hold)`);
      return;
    }
    if (BackgroundUtil.requeuePending) {
      BackgroundUtil.diagnostic(`requeue-skip why=${why} reason=${reason} (already pending)`);
      return;
    }
    const now: number = Date.now();
    if (BackgroundUtil.startedAt > 0 &&
      now - BackgroundUtil.startedAt >= BackgroundUtil.REQUEUE_RESET_AFTER_MS) {
      // 上一轮任务活够了 ⇒ 这次取消是"偶发被打断"，把额度还回去
      BackgroundUtil.requeueCount = 0;
    }
    if (now - BackgroundUtil.requeueWindowStart > BackgroundUtil.REQUEUE_WINDOW_MS) {
      BackgroundUtil.requeueWindowStart = now;
      BackgroundUtil.requeueCount = 0;
    }
    if (BackgroundUtil.requeueCount >= BackgroundUtil.REQUEUE_MAX) {
      BackgroundUtil.diagnostic(`requeue-giveup why=${why} reason=${reason} ` +
        `count=${BackgroundUtil.requeueCount} window=${BackgroundUtil.REQUEUE_WINDOW_MS}ms`);
      return;
    }
    BackgroundUtil.requeueCount++;
    BackgroundUtil.requeuePending = true;
    BackgroundUtil.diagnostic(`requeue-after-cancel why=${why} reason=${reason} ` +
      `attempt=${BackgroundUtil.requeueCount}/${BackgroundUtil.REQUEUE_MAX} ` +
      `delay=${BackgroundUtil.REQUEUE_DELAY_MS}ms`);
    setTimeout((): void => {
      BackgroundUtil.requeuePending = false;
      if (!BackgroundUtil.requested) {
        BackgroundUtil.diagnostic('requeue-drop (app stopped asking)');
        return;
      }
      BackgroundUtil.enqueue(BackgroundUtil.lastContext);
    }, BackgroundUtil.REQUEUE_DELAY_MS);
  }

  /** 注册"系统取消 / 系统暂停"回调（只注册一次；两个事件都是后台断音的关键证据）。 */
  private static observeSystemEvents(): void {
    if (!BackgroundUtil.observingCancel) {
      try {
        backgroundTaskManager.on('continuousTaskCancel', (info): void => {
          // 官方 reason：1 = USER_CANCEL（用户取消）、2 = SYSTEM_CANCEL（系统取消）、
          //   3 = USER_CANCEL_REMOVE_NOTIFICATION（预留、暂未启用）；4~11 也多为预留。
          const reason: number = info.reason as number;
          BackgroundUtil.running = false;
          BackgroundUtil.diagnostic(`stop-continuous system-cancel reason=${reason} info=${JSON.stringify(info)}`);
          if (reason === backgroundTaskManager.ContinuousTaskCancelReason.SYSTEM_CANCEL) {
            BackgroundUtil.tryRequeue('system-cancel', reason);
          } else {
            BackgroundUtil.diagnostic(`requeue-skip reason=${reason} (not SYSTEM_CANCEL)`);
          }
        });
        BackgroundUtil.observingCancel = true;
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        BackgroundUtil.diagnostic(`observe-cancel(err=${err.code}) msg=${err.message}`);
      }
    }
    if (!BackgroundUtil.observingSuspend) {
      // ★ API 20+：对"申请了 AUDIO_PLAYBACK 却没在播放"的任务，系统先**暂停**（退后台挂起、
      //   回前台自动激活），连续检测失败才真正取消（detailedReason 6）。不登记这两个事件的话，
      //   用户只能看到"后台又断了"，查不到是系统判定"没在播"。
      try {
        backgroundTaskManager.on('continuousTaskSuspend', (info): void => {
          BackgroundUtil.diagnostic(`system-suspend id=${info.continuousTaskId} ` +
            `state=${info.suspendState} reason=${info.suspendReason}`);
        });
        backgroundTaskManager.on('continuousTaskActive', (info): void => {
          BackgroundUtil.diagnostic(`system-active id=${info.id}`);
        });
        BackgroundUtil.observingSuspend = true;
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        BackgroundUtil.diagnostic(`observe-suspend(err=${err.code}) msg=${err.message}`);
      }
    }
  }

  private static async reconcile(context?: common.UIAbilityContext): Promise<void> {
    if (!context) {
      BackgroundUtil.diagnostic('start-continuous(err=context-undefined)');
      return;
    }
    if (!canIUse('SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask')) {
      BackgroundUtil.diagnostic('start-continuous(err=capability-unavailable)');
      return;
    }
    if (!BackgroundUtil.requested) {
      if (!BackgroundUtil.running) {
        BackgroundUtil.diagnostic('stop-continuous idle');
        return;
      }
      try {
        await backgroundTaskManager.stopBackgroundRunning(context);
        BackgroundUtil.running = false;
        BackgroundUtil.startedAt = 0;
        BackgroundUtil.diagnostic('stop-continuous ok');
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        BackgroundUtil.diagnostic(`stop-continuous(err=${err.code}) msg=${err.message}`);
      }
      return;
    }
    if (BackgroundUtil.running) {
      return;
    }
    BackgroundUtil.observeSystemEvents();
    let stage: string = 'wantAgent';
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: context.abilityInfo.bundleName,
          moduleName: context.abilityInfo.moduleName,
          abilityName: context.abilityInfo.name
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(info);
      // Stop may have arrived while getWantAgent was pending.
      if (!BackgroundUtil.requested) {
        BackgroundUtil.diagnostic('stop-continuous cancelled-pending-start');
        return;
      }
      stage = 'startBackgroundRunning';
      await backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      BackgroundUtil.running = true;
      BackgroundUtil.startedAt = Date.now();
      BackgroundUtil.diagnostic('start-continuous(err=0) ok');
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      BackgroundUtil.diagnostic(`start-continuous(err=${err.code}) stage=${stage} msg=${err.message}`);
      if (!BackgroundUtil.failureShown) {
        BackgroundUtil.failureShown = true;
        AppStorage.setOrCreate(AppStorageKeys.LX_LAST_ERROR, '后台播放任务申请失败，请查看运行日志（' + err.code + '）');
      }
    }
  }
}
