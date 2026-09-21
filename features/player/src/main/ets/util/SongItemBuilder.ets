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
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { getAppRuntime, Logger, SongItem } from 'musicbasic';

/** Source id used by imported device audio (see features/localmusic). */
const LOCAL_SOURCE: string = 'local';

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
  /** FD of the opened sandbox audio file; -1 when the current build has none. */
  private localFd: number = -1;

  /** Resolves raw FD for songItem.src and stores it for getRealUrl(). */
  public async build(songItem: SongItem): Promise<SongItem> {
    await this.closeLocalFd();
    this.songItem = songItem;
    this.httpUrl = songItem.url.startsWith('http') ? songItem.url : '';
    if (this.httpUrl.length > 0) {
      this.realUrl = undefined;
      return this.songItem;
    }
    // Imported device audio lives in the app sandbox, so resourceManager cannot
    // reach it — the descriptor has to be opened directly.
    if (songItem.source === LOCAL_SOURCE) {
      this.realUrl = this.openSandboxFile(songItem.url);
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

  /** Opens a sandbox audio file read-only and returns the descriptor AVPlayer needs. */
  private openSandboxFile(path: string): resourceManager.RawFileDescriptor | undefined {
    if (path.length === 0) {
      Logger.error('local music path is empty');
      return undefined;
    }
    try {
      const stat: fs.Stat = fs.statSync(path);
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      this.localFd = file.fd;
      const descriptor: resourceManager.RawFileDescriptor = { fd: file.fd, offset: 0, length: stat.size };
      Logger.info('MediaAssetBuilder local fd ok:' + path);
      return descriptor;
    } catch (error) {
      Logger.error('open local music failed: ' + path);
      return undefined;
    }
  }

  /** Closes the sandbox FD opened by the previous build, if any. */
  private async closeLocalFd(): Promise<void> {
    if (this.localFd < 0) {
      return;
    }
    try {
      fs.closeSync(this.localFd);
    } catch (error) {
      Logger.error('Failed to close local music fd');
    }
    this.localFd = -1;
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
    await this.closeLocalFd();
    if (this.abilityContext && this.songItem !== null && this.httpUrl.length === 0
      && this.songItem.source !== LOCAL_SOURCE) {
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

