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

import { UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { LiveViewLockScreenExtensionAbility } from '@kit.LiveViewKit';
import { LiveViewConst, Logger } from 'musicbasic';

const TAG = 'LiveViewExtAbility';

/**
 * Lock screen immersive live view extension (独立子进程).
 * Receives the initial lyric payload via want.parameters (passed from
 * liveViewLockScreenAbilityParameters) and hands it to the page through a
 * LocalStorage; subsequent updates arrive over common events.
 */
export default class LiveViewExtAbility extends LiveViewLockScreenExtensionAbility {
  /** Creates the lock screen page and seeds it with the initial lyric payload. */
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    Logger.info(TAG, 'onSessionCreate');
    const storage = new LocalStorage();
    const parameters = want.parameters;
    if (parameters !== undefined) {
      const raw: string | undefined = parameters[LiveViewConst.LIVE_VIEW_PARAM_KEY] as string | undefined;
      if (raw !== undefined && raw.length > 0) {
        storage.setOrCreate(LiveViewConst.LS_INIT_DATA_KEY, raw);
      }
    }
    try {
      session.loadContent('liveview/LockScreenPage', storage);
    } catch (error) {
      Logger.error(TAG, 'loadContent failed');
    }
  }
}
