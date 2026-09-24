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

import { AbilityConstant, Callee, common, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { rpc } from '@kit.IPCKit';
import { CardImageHelper } from '../musiccard/CardImageHelper';
import { appendPlayLog, getAppRuntime, Logger, MusicCardBridge, MusicCardSnapshot, MusicStoreService, WindowUtil } from 'musicbasic';
import { lxSourceManager, MediaService } from 'player';
import type { LXApiImportResult } from 'player';

/** AppStorage key：上一次「用派音打开脚本」的结果文案（供窗口就绪后 toast）。 */
const SOURCE_IMPORT_MSG_KEY: string = 'lxSourceImportMsg';

/** Main UIAbility for the default phone product: wires app runtime, window util, and media singleton. */
export default class EntryAbility extends UIAbility {
  /** Timestamp of the last cross-process form-id refresh (kept out of the playback hot path). */
  private static lastFormIdRefresh: number = 0;
  private static cardPushSeq: number = 0;

  /** Persists UIAbility context on app runtime for global access. */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    getAppRuntime().context = this.context;
    Logger.info('EntryAbility: Ability onCreate');
    // ⚠️ 必须在这里（任何 importApi 之前）把音源存储目录告诉 LXSourceManager：
    //    它原来只由 LXSourceHost.aboutToAppear 赋值，而「用派音打开 .js」是 onCreate
    //    里导入的 —— 那时 filesDir 还是空串，脚本与列表被写到无效路径（静默失败），
    //    表现就是「音源管理里只剩刚导入的那个、重启后连它也没了」。
    lxSourceManager.init(this.context);
    this.applyStoredColorMode();
    EntryAbility.registerCardActionChannel(this.callee, this.context);
    // 冷启动也可能是「用派音打开 .js」（文件管理器点开），先把脚本吃进来
    this.handleViewDataWant(want);
  }

  /**
   * 「用派音打开脚本文件」的处理。
   *
   * 文件管理器 / 其他应用以 `ohos.want.action.viewData` + `file://...` 拉起本应用
   * （声明见 module.json5 的 skills：type = general.java-script，linkFeature = FileOpen）。
   * 行为与设置页里的「导入音源」完全一致 —— 读文件 → `lxSourceManager.importApi`。
   *
   * @param want 启动参数；不是 viewData 或没有 uri 时直接返回。
   */
  private handleViewDataWant(want: Want): void {
    if (want.action !== 'ohos.want.action.viewData') {
      return;
    }
    const uri: string = want.uri ?? '';
    if (uri.length === 0) {
      return;
    }
    try {
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let script: string = '';
      try {
        const stat: fs.Stat = fs.statSync(uri);
        const buf: ArrayBuffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf, { offset: 0, length: stat.size });
        script = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
      } finally {
        fs.closeSync(file);
      }
      // 导入结果要如实反映：落盘失败时不能再报「已导入」
      const result: LXApiImportResult = lxSourceManager.importApi(script);
      if (!result.ok) {
        appendPlayLog('[音源] 导入失败 ' + uri + ' : ' + result.message);
        AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '导入失败：' + result.message);
        Logger.error(`EntryAbility: source script rejected ${result.message}`);
        this.flushSourceImportToast();
        return;
      }
      appendPlayLog('[音源] 已导入脚本 ' + result.message + ' <- ' + uri);
      AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '音源「' + result.message + '」已导入');
      Logger.info(`EntryAbility: source script imported from ${uri}`);
    } catch (err) {
      const e: Error = err as Error;
      appendPlayLog('[音源] 导入失败 ' + uri + ' : ' + (e.message ?? ''));
      AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '导入失败：不是有效的音源脚本');
      Logger.error(`EntryAbility: import source script failed ${e.message ?? ''}`);
    }
    this.flushSourceImportToast();
  }

  /** 把「脚本导入结果」提示出来（窗口还没就绪时先留着，等 onWindowStageCreate 或回前台再提示）。 */
  private flushSourceImportToast(): void {
    const message: string = AppStorage.get<string>(SOURCE_IMPORT_MSG_KEY) ?? '';
    if (message.length === 0) {
      return;
    }
    const ui = getAppRuntime().uiContext;
    if (ui === undefined) {
      return;   // 窗口未就绪：留着，onForeground / loadContent 回调里再提示
    }
    AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '');
    try {
      ui.getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (error) {
      Logger.warn(`source import toast failed: ${JSON.stringify(error)}`);
    }
  }

  /** Applies the user-saved color mode on startup (0=light, 1=dark, 2=follow system). */
  private applyStoredColorMode(): void {
    const mode: number = MusicStoreService.getInstance().getColorMode();
    if (mode === 0) {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } else if (mode === 1) {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } else {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    }
  }

  /** Ability lifecycle teardown hook. */
  onDestroy() {
    try {
      this.callee.off('cardAction');
    } catch (_err) {
    }
    Logger.info('EntryAbility: Ability onDestroy');
  }

  /** Loads main page, captures UIContext, initializes window helper and MediaService singleton. */
  onWindowStageCreate(windowStage: window.WindowStage) {
    // Main window is created, set main page for this ability
    Logger.info('EntryAbility: Ability onWindowStageCreate');

    EntryAbility.registerCardUpdater();
    windowStage.loadContent('pages/Index', (err) => {
      try {
        getAppRuntime().uiContext = windowStage.getMainWindowSync().getUIContext();
      } catch (error) {
        Logger.error(`getMainWindowSync error ${JSON.stringify(error)}`);
      }
      // 冷启动如果是「用派音打开脚本」，导入已经做完了，这里把结果提示出来
      this.flushSourceImportToast();
      if (err.code) {
        Logger.error(`Failed to load the content. Cause: ${JSON.stringify(err) ?? ''}`);
        return;
      }
      Logger.info('Succeeded in loading the content.');
      MediaService.getInstance();
      try {
        const windowUtil = WindowUtil.getInstance();
        windowUtil.setWindowStage(windowStage);
        windowUtil.setUIContext();
        windowUtil.updateWindowInfo();
        const isDark: boolean = this.context.config.colorMode ===
          ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        windowUtil.applyNavigationBarColor(isDark);
      } catch (err) {
        let error = err as BusinessError;
        Logger.error(`WindowUtil init error ${error.code} ${error.message}`);
      }
    });
  }

  /**
   * Keeps the system navigation bar color in sync when the system color mode changes.
   * @param newConfig Latest configuration carrying the new color mode.
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    try {
      WindowUtil.getInstance().applyNavigationBarColor(
        newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      let error = err as BusinessError;
      Logger.error(`applyNavigationBarColor error ${error.code} ${error.message}`);
    }
  }

  /** Called when the main window stage is destroyed. */
  onWindowStageDestroy() {
    // Main window is destroyed, release UI related resources
    Logger.info('EntryAbility: Ability onWindowStageDestroy');
    try {
      MediaService.getInstance().release();
    } catch (error) {
      Logger.error(`MediaService release ${JSON.stringify(error)}`);
    }
  }

  onForeground() {
    // Ability has brought to foreground
    Logger.info('EntryAbility: Ability onForeground');
    // 前台时补建实况窗（本地实况窗仅前台可创建，覆盖后台起播场景）
    try {
      MediaService.getInstance().syncLiveViewOnForeground();
      MediaService.getInstance().refreshHiCarStatus();
    } catch (error) {
      Logger.error(`syncLiveViewOnForeground ${JSON.stringify(error)}`);
    }
    MusicCardBridge.notify();
    this.consumeCardAction();
    // 热启动的脚本导入结果在这里提示（onNewWant 时窗口已经就绪，通常当场就提示过了）
    this.flushSourceImportToast();
  }
  /**
   * Registers the interactive-card channel. Card buttons post
   * postCardAction(action: 'call', params: { method: 'cardAction', ... }), which the system
   * delivers to this callee handler as a serialized params string (see the official sample).
   */
  private static registerCardActionChannel(callee: Callee, context: common.UIAbilityContext): void {
    try {
      callee.on('cardAction', (data: rpc.MessageSequence): null => {
        EntryAbility.onCardAction(data, context);
        return null;
      });
      appendPlayLog('[卡片] 交互通道已注册');
    } catch (error) {
      Logger.error(`register card action channel failed: ${JSON.stringify(error)}`);
    }
  }

  /** Handles one card action: runs the media command and refreshes that card. */
  private static onCardAction(data: rpc.MessageSequence, context: common.UIAbilityContext): void {
    let params: Record<string, string> = {};
    try {
      params = JSON.parse(data.readString()) as Record<string, string>;
    } catch (_err) {
      appendPlayLog('[卡片] 动作解析失败');
      return;
    }
    const actionType: string = params.actionType ?? '';
    const formId: string = params.formId ?? '';
    appendPlayLog('[卡片] 收到动作: ' + actionType);
    // The callee callback arrives on an IPC thread: hop to the JS main thread before touching playback.
    setTimeout((): void => {
      if (actionType.length > 0) {
        MediaService.getInstance().handleCardAction(actionType);
      }
      if (formId.length > 0) {
        setTimeout((): void => {
          EntryAbility.pushCardDataTo(formId, context);
        }, 700);
      }
    }, 0);
  }

  /** Form ids of live cards; re-reads the shared file only when unknown, at most once every 2s. */
  private static resolveCardFormIds(): string[] {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const cached: string[] = store.getCardFormIds();
    if (cached.length > 0) {
      return cached;
    }
    const now: number = Date.now();
    // ⚠️ 这里原来是 60 秒节流：卡片是在 FormExtensionAbility 进程里添加的，formId 经共享存储回传，
    //    节流太长会导致「刚拖到桌面的卡片一分钟内不刷新」。改成 2 秒（仍然避免每次推都读盘）。
    if (now - EntryAbility.lastFormIdRefresh < 2000) {
      return cached;
    }
    EntryAbility.lastFormIdRefresh = now;
    const ctx = getAppRuntime().context;
    if (ctx !== undefined) {
      store.refreshStoreCache(ctx);
    }
    return store.getCardFormIds();
  }

  private static nextCoverName(): string {
    EntryAbility.cardPushSeq++;
    return 'cover' + EntryAbility.cardPushSeq + '_' + Date.now();
  }

  /** Pushes the current snapshot (with a prepared cover image) to a single card. */
  private static pushCardDataTo(formId: string, context: common.UIAbilityContext): void {
    EntryAbility.buildCardPayload(MusicCardBridge.snapshot(), formId).then((payload: Record<string, Object>) => {
      try {
        const data: formBindingData.FormBindingData = formBindingData.createFormBindingData(payload);
        formProvider.updateForm(formId, data).catch((_err: BusinessError): void => {
        });
      } catch (_err) {
      }
    });
  }

  private static async buildCardPayload(snapshot: MusicCardSnapshot,
    formId: string): Promise<Record<string, Object>> {
    const payload: Record<string, Object> = {};
    payload['title'] = snapshot.title;
    payload['singer'] = snapshot.singer;
    payload['playing'] = snapshot.playing;
    payload['lyric'] = snapshot.lyric;
    payload['formId'] = formId;
    const ctx = getAppRuntime().context;
    if (ctx === undefined || snapshot.cover.length === 0) {
      payload['imgName'] = '';
      return payload;
    }
    const imageName: string = EntryAbility.nextCoverName();
    const fd: number = await CardImageHelper.prepareCover(ctx.tempDir, snapshot.cover, imageName);
    if (fd >= 0) {
      const formImages: Record<string, number> = {};
      formImages[imageName] = fd;
      payload['imgName'] = imageName;
      payload['formImages'] = formImages;
    } else {
      payload['imgName'] = '';
    }
    return payload;
  }

  /** Pushes the current song snapshot to every live desktop card (fire and forget). */
  private static registerCardUpdater(): void {
    MusicCardBridge.setUpdater((snapshot: MusicCardSnapshot): void => {
      EntryAbility.pushCardSnapshot(snapshot);
    });
  }

  /** Pushes card data without blocking playback: no network work, cache refresh at most once a minute. */
  private static pushCardSnapshot(snapshot: MusicCardSnapshot): void {
    try {
      const ids: string[] = EntryAbility.resolveCardFormIds();
      if (ids.length === 0) {
        return;
      }
      for (let i: number = 0; i < ids.length; i++) {
        EntryAbility.pushCardDataTo(ids[i], getAppRuntime().context as common.UIAbilityContext);
      }
    } catch (_err) {
    }
  }

  /** Runs a desktop-card action queued while the app was in the background. */
  private consumeCardAction(): void {
    const action: string = MusicStoreService.getInstance().consumePendingCardAction();
    if (action.length === 0) {
      return;
    }
    const media: MediaService = MediaService.getInstance();
    if (action === 'playPause') {
      if (media.isPlayingState()) {
        media.pause();
      } else {
        void media.play();
      }
      return;
    }
    if (action === 'next') {
      media.playNextAuto(false);
      return;
    }
    if (action === 'previous') {
      media.playPrevious();
    }
  }

  /** App moved to background; notifies media layer for background-task policy. */
  onBackground() {
    // Ability has back to background
    Logger.info('EntryAbility: Ability onBackground');
    MediaService.getInstance().onApplicationBackground();
  }
  /** Warm-start delivery (no card payload here: card actions arrive on the callee channel). */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    appendPlayLog('[卡片] onNewWant');
    // 应用已在运行时，从文件管理器「用派音打开 .js」走这条路（导入音源脚本）
    this.handleViewDataWant(want);
  }
}
