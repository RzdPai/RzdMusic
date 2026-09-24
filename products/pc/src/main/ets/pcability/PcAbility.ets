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

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { appendPlayLog, getAppRuntime, Logger, WindowUtil } from 'musicbasic';
import { lxSourceManager, MediaService } from 'player';
import type { LXApiImportResult } from 'player';

/** AppStorage key：上一次「用派音打开脚本」的结果文案（供窗口就绪后 toast）。 */
const SOURCE_IMPORT_MSG_KEY: string = 'lxSourceImportMsg';

/**
 * PC UIAbility: loads Index, wires WindowUtil for free-window chrome, and initializes MediaService.
 */
export default class PcAbility extends UIAbility {
  /**
   * Logs ability creation (PC runtime may defer context until window stage).
   * @param want Launch want.
   * @param launchParam Launch parameters.
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('PcAbility: Ability onCreate');
    // ⚠️ 顺序不能动：先把上下文存进 AppRuntime（否则后面 flushSourceImportToast
    //    拿不到 uiContext，提示会静默丢掉），再把音源存储目录交给 LXSourceManager
    //    （否则导入写到无效路径、重启就没了），最后才做「用派音打开 .js」的导入。
    getAppRuntime().context = this.context;
    lxSourceManager.init(this.context);
    this.handleViewDataWant(want);
  }

  /**
   * 「用派音打开脚本文件」的处理（与手机壳层一致）。
   *
   * 文件管理器以 `ohos.want.action.viewData` + `file://...` 拉起本应用
   * （声明见 module.json5 的 skills：type = general.java-script，linkFeature = FileOpen），
   * 行为等同设置页里的「导入音源」：读文件 → `lxSourceManager.importApi`。
   * @param want 启动参数。
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
      const result: LXApiImportResult = lxSourceManager.importApi(script);
      if (!result.ok) {
        appendPlayLog('[音源] 导入失败 ' + uri + ' : ' + result.message);
        AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '导入失败：' + result.message);
        Logger.error(`PcAbility: source script rejected ${result.message}`);
        this.flushSourceImportToast();
        return;
      }
      appendPlayLog('[音源] 已导入脚本 ' + result.message + ' <- ' + uri);
      AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '音源「' + result.message + '」已导入');
    } catch (err) {
      const e: Error = err as Error;
      appendPlayLog('[音源] 导入失败 ' + uri + ' : ' + (e.message ?? ''));
      AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '导入失败：不是有效的音源脚本');
      Logger.error(`PcAbility: import source script failed ${e.message ?? ''}`);
    }
    this.flushSourceImportToast();
  }

  /** 窗口还没就绪时先把提示留着，等 onWindowStageCreate / onForeground 再提示。 */
  private flushSourceImportToast(): void {
    const message: string = AppStorage.get<string>(SOURCE_IMPORT_MSG_KEY) ?? '';
    if (message.length === 0) {
      return;
    }
    const ui = getAppRuntime().uiContext;
    if (ui === undefined) {
      return;
    }
    AppStorage.setOrCreate(SOURCE_IMPORT_MSG_KEY, '');
    try {
      ui.getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (error) {
      Logger.warn(`source import toast failed: ${JSON.stringify(error)}`);
    }
  }

  /** Logs ability destroy. */
  onDestroy(): void {
    Logger.info('PcAbility: Ability onDestroy');
  }

  /**
   * Loads pages/Index, assigns UIContext, initializes MediaService and WindowUtil (immersive title, window info).
   * @param windowStage Main window stage for the PC window.
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    Logger.info('PcAbility: Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      try {
        getAppRuntime().uiContext = windowStage.getMainWindowSync().getUIContext();
      } catch (error) {
        Logger.error(`getMainWindowSync error ${JSON.stringify(error)}`);
      }
      if (err.code) {
        Logger.error(`Failed to load the content. Cause: ${JSON.stringify(err)}`);
        return;
      }
      Logger.info('Succeeded in loading the content.');
      MediaService.getInstance();
      try {
        getAppRuntime().context = this.context;
        const windowUtil = WindowUtil.getInstance();
        windowUtil.setWindowStage(windowStage);
        windowUtil.setUIContext();
        windowUtil.updateWindowInfo();
        windowUtil.applyPcFreeWindowTitleImmersive(true);
      } catch (error) {
        Logger.error(`WindowUtil init ${JSON.stringify(error)}`);
      }
      // 冷启动如果是「用派音打开脚本」，导入已经做完了，这里把结果提示出来
      this.flushSourceImportToast();
    });
  }

  /** Tears down immersive title settings and releases WindowUtil. */
  onWindowStageDestroy(): void {
    Logger.info('PcAbility: Ability onWindowStageDestroy');
    try {
      WindowUtil.getInstance().applyPcFreeWindowTitleImmersive(false);
      WindowUtil.getInstance().release();
    } catch (error) {
      Logger.error(`WindowUtil release ${JSON.stringify(error)}`);
    }

    try {
      MediaService.getInstance().release();
    } catch (error) {
      Logger.error(`MediaService release ${JSON.stringify(error)}`);
    }
  }

  /** Logs foreground. */
  onForeground(): void {
    Logger.info('PcAbility: Ability onForeground');
    this.flushSourceImportToast();
  }

  /** 应用已运行时从文件管理器「用派音打开 .js」走这条路。 */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('PcAbility: Ability onNewWant');
    this.handleViewDataWant(want);
  }

  /** Logs background. */
  onBackground(): void {
    Logger.info('PcAbility: Ability onBackground');
  }
}
