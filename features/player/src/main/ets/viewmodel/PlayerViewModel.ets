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

import { AppStorageV2, UIContext } from '@kit.ArkUI';
import { AppStorageKeys, RouterUrlConstants, ToplistRouteParam } from 'musicbasic';
import { MusicAppState, PlayerTrackUi } from '../model/PlayerModels';
import { PlayerDataUtil } from '../util/PlayerDataUtil';

/** Observable fa莽ade for inline / mini player UI: track text, cover, and transport actions. */
@ObservedV2
export class PlayerViewModel {
  /** Global playback and queue state shared with the rest of the app. */
  @Trace public appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  /** Current queue item projected to PlayerTrackUi, or undefined when queue empty. */
  public currentTrack(): PlayerTrackUi | undefined {
    return PlayerDataUtil.getCurrentTrackUi(this.appState);
  }

  /** Title string for the current track, or empty when none. */
  public songTitle(): string | Resource {
    const track = this.currentTrack();
    return track !== undefined ? track.title : '';
  }

  /** Artist line for the current track, or empty when none. */
  public songSinger(): string | Resource {
    const track = this.currentTrack();
    return track !== undefined ? track.singer : '';
  }

  /** Cover Resource for the current track, or a default cover placeholder. */
  public songCover(): Resource {
    const track = this.currentTrack();
    return track !== undefined ? track.cover : $r('app.media.ic_avatar1');
  }

  /** Online cover image url for the current track; empty when unavailable. */
  public songCoverUrl(): string {
    const track = this.currentTrack();
    return track !== undefined ? track.coverUrl : '';
  }

  /** Opens full-screen playback immediately (no animation). */
  public openFullScreen(): void {
    this.appState.isShowPlay = true;
  }

  /**
   * 打开全屏播放页。
   *
   * ⚠️ **不要再把 `isShowPlay = true` 包在 `uiContext.animateTo` 里**（旧动画时代的写法）：
   *    那会给"挂载播放页浮层 + 形变几何初始化"整段套一层隐式动画，
   *    于是形变的起点被那层动画吃掉 —— 用户实测"直接点开播放器还是旧动画/从中间开始"
   *    就是这个。展开动画由播放页自己按反编译的 `doEnter` 播（350ms EaseInOut，
   *    起点状态在 `aboutToAppear` 就压好了），壳层只负责挂载。
   */
  public openFullScreenWithSharedElementTransition(_uiContext: UIContext): void {
    this.appState.isShowPlay = true;
  }

  /** Skips to previous track according to MediaService play mode. */
  public playPrevious(): void {
    PlayerDataUtil.playPrevious();
  }

  /** Advances to next track from explicit user control. */
  public playNext(): void {
    PlayerDataUtil.playNext();
  }

  /** Seeks current playback to ms (delegates to MediaService). */
  public seek(ms: number): void {
    PlayerDataUtil.seek(ms);
  }

  /** Toggles play/pause using current appState and MediaService first-load rules. */
  public togglePlayPause(): void {
    PlayerDataUtil.togglePlayPause(this.appState);
  }

  /** Navigates the given stack to the playlist detail route showing the current play queue. */
  public pushPlaylistDetail(pageIndexInfos: NavPathStack): void {
    const param = new ToplistRouteParam();
    param.sectionType = 'queue';
    param.listTitle = '播放列表';
    pageIndexInfos.replacePathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
  }
}
