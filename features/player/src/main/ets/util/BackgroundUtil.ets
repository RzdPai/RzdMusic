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
import { Logger, MusicStoreService } from 'musicbasic';

/** Serializes start/stop so a pending WantAgent cannot restart a disabled task. */
export class BackgroundUtil {
  private static requested: boolean = false;
  private static running: boolean = false;
  private static observingCancel: boolean = false;
  private static failureShown: boolean = false;
  private static operations: Promise<void> = Promise.resolve();

  private static diagnostic(message: string): void {
    const line: string = '[RzdLockScreenB] ' + message;
    Logger.info(line);
    MusicStoreService.getInstance().appendRuntimeDiagnostic(line);
  }

  public static startContinuousTask(context?: common.UIAbilityContext): void {
    BackgroundUtil.requested = true;
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
    if (!BackgroundUtil.observingCancel) {
      try {
        backgroundTaskManager.on('continuousTaskCancel', (info): void => {
          BackgroundUtil.running = false;
          BackgroundUtil.diagnostic('stop-continuous system-cancel info=' + JSON.stringify(info));
        });
        BackgroundUtil.observingCancel = true;
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        BackgroundUtil.diagnostic(`observe-cancel(err=${err.code}) msg=${err.message}`);
      }
    }
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
      BackgroundUtil.diagnostic('start-continuous(err=0) ok');
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      BackgroundUtil.diagnostic(`start-continuous(err=${err.code}) stage=${stage} msg=${err.message}`);
      if (!BackgroundUtil.failureShown) {
        BackgroundUtil.failureShown = true;
        AppStorage.setOrCreate('lxLastError', '后台播放任务申请失败，请查看运行日志（' + err.code + '）');
      }
    }
  }
}
