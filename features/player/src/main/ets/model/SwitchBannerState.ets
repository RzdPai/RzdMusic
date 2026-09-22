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

/** Banner text shown on the playback page when the engine has switched to another
 * user script. Shared via AppStorageV2 so OnlinePlayUtil can publish a notice
 * and PlaybackPage can render it reactively.
 */
import { AppStorageV2 } from '@kit.ArkUI';

export const SWITCH_BANNER_STORAGE_KEY: string = 'lx_switch_banner_state';

@ObservedV2
export class SwitchBannerState {
  /** Localized banner text, e.g. "已切换音源：备用源". */
  @Trace public text: string = '';
  /** Timestamp used by the page to ignore stale clears. */
  @Trace public ts: number = 0;

  public static connect(): SwitchBannerState {
    return AppStorageV2.connect(SwitchBannerState, SWITCH_BANNER_STORAGE_KEY,
      (): SwitchBannerState => new SwitchBannerState())!;
  }
}