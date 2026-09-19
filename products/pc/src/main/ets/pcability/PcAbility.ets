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
import { getAppRuntime, Logger, WindowUtil } from 'musicbasic';
import { MediaService } from 'player';

/**
 * PC UIAbility: loads Index, wires WindowUtil for free-window chrome, and initializes MediaService.
 */
export default class PcAbility extends UIAbility {
  /**
   * Logs ability creation (PC runtime may defer context until window stage).
   * @param want Launch want.
   * @param launchParam Launch parameters.
   */
  onCreate(): void {
    Logger.info('PcAbility: Ability onCreate');
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
  }

  /** Logs background. */
  onBackground(): void {
    Logger.info('PcAbility: Ability onBackground');
  }
}
