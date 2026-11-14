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

import { UIContext } from '@kit.ArkUI';
import { MusicAppState, MusicStoreService, PlaybackPreferenceService, SongItem } from 'musicbasic';
import { DownloadService, DownloadTask } from './DownloadService';

/**
 * 下载入口门面：所有下载统一进入 DownloadService 任务队列
 * （并发调度 + 进度 + 失败重试 + 元信息嵌入），不再内联下载。
 */
export class DownloadUtil {
  /** Resolve once at entry; retries only use DownloadTask.requestedQuality. */
  public static async resolveQualitySnapshot(explicitQuality: string = ''): Promise<string> {
    if (explicitQuality.length > 0) {
      console.info('[RzdDownloadQuality] snapshot selection=explicit tier=' + explicitQuality);
      return explicitQuality;
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    if (store.getDownloadQualityMode() === 'manual') {
      console.warn('[RzdDownloadQuality] mode=manual rejected missing explicit quality');
      return '';
    }
    const quality: string = await PlaybackPreferenceService.resolveDefaultQuality();
    console.info('[RzdDownloadQuality] snapshot selection=network-follow tier=' + quality);
    return quality;
  }

  public static async downloadBatch(rows: DownloadTask[], uiContext: UIContext | undefined): Promise<string[]> {
    const snapshots: DownloadTask[] = [];
    let defaultSnapshot: string = '';
    // Freeze every row before the first network await; callers may change selection meanwhile.
    const captured: DownloadTask[] = rows.map((row: DownloadTask): DownloadTask => row.clone());
    for (const row of captured) {
      const task: DownloadTask = row.clone();
      if (row.quality.length > 0) {
        task.quality = await DownloadUtil.resolveQualitySnapshot(row.quality);
      } else {
        if (defaultSnapshot.length === 0) {
          defaultSnapshot = await DownloadUtil.resolveQualitySnapshot();
        }
        task.quality = defaultSnapshot;
      }
      if (task.quality.length === 0) {
        continue;
      }
      task.requestedQuality = task.quality;
      console.info('[RzdDownloadQuality] enqueue explicit tier=' + task.quality + ' source=' + task.source);
      snapshots.push(task);
    }
    return DownloadService.getInstance().enqueueBatch(snapshots, uiContext);
  }

  /**
   * Downloads the current queue track at the given quality (queued via DownloadService).
   * @param appState Shared playback state.
   * @param quality Target quality ('128k'|'320k'|'flac'|'flac24bit'|...).
   * @param uiContext Used for prompts.
   */
  public static async downloadCurrentSong(appState: MusicAppState, quality: string,
    uiContext: UIContext | undefined): Promise<void> {
    const song: SongItem | undefined = appState.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      if (uiContext !== undefined) {
        uiContext.getPromptAction().showToast({ message: '暂无下载歌曲', duration: 2000 });
      }
      return;
    }
    const name: string = typeof song.title === 'string' ? song.title : '';
    const singer: string = typeof song.singer === 'string' ? song.singer : '';
    await DownloadUtil.downloadSong(song.source, song.songId, name, singer, quality, uiContext,
      song.cover, song.albumName);
  }

  /**
   * Queues an arbitrary online song for download via the DownloadService queue.
   * @param source Music source id ('kw'|'kg'|'tx'|'wy'|'mg').
   * @param songId Song id within the source.
   * @param name Song title.
   * @param singer Artist line.
   * @param quality Target quality ('128k'|'320k'|'flac'|'flac24bit'|...).
   * @param uiContext Used for prompts.
   * @param imgUrl Cover image url for metadata embedding (optional).
   * @param albumName Album name for metadata embedding (optional).
   */
  public static async downloadSong(source: string, songId: string, name: string, singer: string,
    quality: string, uiContext: UIContext | undefined, imgUrl: string = '', albumName: string = ''): Promise<void> {
    const snapshot: string = await DownloadUtil.resolveQualitySnapshot(quality);
    if (snapshot.length === 0) {
      return;
    }
    console.info('[RzdDownloadQuality] enqueue explicit tier=' + snapshot + ' source=' + source);
    DownloadService.getInstance().enqueue(source, songId, name, singer, snapshot, uiContext,
      imgUrl, albumName);
  }
}
