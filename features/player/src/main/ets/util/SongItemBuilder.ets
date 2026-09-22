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

/** 导入设备音频（`features/localmusic`）使用的音源 id。 */
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
  /**
   * 本地歌（沙箱音频）自己打开的 fd；没有时为 -1。
   *
   * ⚠️ 必须自己记着并显式关闭：`resourceManager.closeRawFd` 管不到这个 fd，
   *    换歌不关就会**漏 fd**，几十首之后播放器直接打不开文件。
   */
  private localFd: number = -1;

  /** Resolves raw FD for songItem.src and stores it for getRealUrl(). */
  public async build(songItem: SongItem): Promise<SongItem> {
    // 先关掉上一首本地歌留下的 fd，避免换歌时泄漏
    await this.closeLocalFd();
    this.songItem = songItem;
    this.httpUrl = songItem.url.startsWith('http') ? songItem.url : '';
    if (this.httpUrl.length > 0) {
      this.realUrl = undefined;
      return this.songItem;
    }
    // ★ 本地歌（导入的设备音频）在**应用沙箱**里，`resourceManager.getRawFd`
    //   根本看不到它 —— 必须自己按路径打开文件拿 fd，否则播放器没有任何音源
    //   （表现就是"本地歌点了没反应/放不出来"）。
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

  /**
   * 以只读方式打开沙箱音频文件，返回 AVPlayer 需要的描述符。
   * @param path 沙箱里的绝对路径。
   * @returns 描述符；打开失败返回 undefined。
   */
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

  /** 关闭上一次 build 打开的沙箱 fd（如果有）。 */
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
    // 本地歌的 fd 是自己开的，先关它
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

