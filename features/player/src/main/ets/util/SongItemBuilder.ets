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

/*
 * Moved from common/mediacommon/src/main/ets/utils/SongItemBuilder.ets
 */

import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { getAppRuntime, Logger, SongItem } from 'musicbasic';

/** Opens raw-file descriptors for SongItem.src and exposes them for AVPlayer.fdSrc. */
export default class SongItemBuilder {
  /** Host UIAbility context used to resolve raw assets. */
  private get abilityContext(): common.UIAbilityContext | undefined {
    return getAppRuntime().context;
  }
  /** Last resolved raw file descriptor for the current build; undefined until getRawFd succeeds. */
  private realUrl?: resourceManager.RawFileDescriptor;
  /** Online playback url for the current build; empty for local assets. */
  private httpUrl: string = '';
  /** Song metadata being prepared; null after release. */
  private songItem: SongItem | null = null;

  /** Resolves raw FD for songItem.src and stores it for getRealUrl(). */
  public async build(songItem: SongItem): Promise<SongItem> {
    this.songItem = songItem;
    this.httpUrl = songItem.url.startsWith('http') ? songItem.url : '';
    if (this.httpUrl.length > 0) {
      this.realUrl = undefined;
      return this.songItem;
    }
    if (!this.abilityContext) {
      return this.songItem;
    }
    let rawfileFd = await this.abilityContext.resourceManager.getRawFd(songItem.src)
      .catch((error: BusinessError) => {
        Logger.error(`resourceManager error code ${error.code} message ${error.message}`);
      });
    if (rawfileFd) {
      this.realUrl = rawfileFd;
    } else {
      Logger.error('get rawfileFd failed');
    }
    Logger.info('MediaAssetBuilder build realUrl:' + this.realUrl);
    return this.songItem;
  }

  /** Descriptor for AVPlayer.fdSrc after a successful build. */
  public getRealUrl(): resourceManager.RawFileDescriptor | undefined {
    Logger.info(`url ${this.realUrl}`);
    return this.realUrl;
  }

  /** Online http(s) url for AVPlayer.url; empty when the track is a local asset. */
  public getHttpUrl(): string {
    return this.httpUrl;
  }

  /** Closes the raw FD for the current songItem and clears internal state. */
  public async release(): Promise<void> {
    if (this.abilityContext && this.songItem !== null && this.httpUrl.length === 0) {
      try {
        await this.abilityContext.resourceManager.closeRawFd(this.songItem.src);
      } catch (error) {
        Logger.error('Failed to closeRawFd');
      }
    }
    this.httpUrl = '';
    this.songItem = null;
  }
}

