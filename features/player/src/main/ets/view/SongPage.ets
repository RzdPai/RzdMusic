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

import { AppStorageV2 } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { MediaService } from '../model/MediaService';
import { sourceDisplayName } from '../util/SourceFallbackUtil';
import { AppStorageKeys, Logger, MusicAppState, SongItem, StyleConstants } from 'musicbasic';

@Builder
export function SongPageBuilder() {
  SongPage();
}

@ComponentV2
struct SongPage {
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  readonly halfWidth: string = '50%';
  private static readonly CROWN_STEP_DEGREE: number = 20;

  aboutToAppear(): void {
    if (this.state.isFirstLaunch) {
      MediaService.getInstance().loadAsset(0, true);
    }
    this.state.isFirstLaunch = false;
  }

  /** Currently playing queue item, if any. */
  private currentSong(): SongItem | undefined {
    return this.state.getCurrentSongItem();
  }

  /** True when the current track carries enough metadata to render the source block. */
  private hasSourceInfo(): boolean {
    const song: SongItem | undefined = this.currentSong();
    if (song === undefined) {
      return false;
    }
    return (song.source ?? '').length > 0 || (song.playScript ?? '').length > 0 ||
      (song.quality ?? '').length > 0;
  }

  /** Music platform label, e.g. "QQ". */
  private sourceLabel(): string {
    const song: SongItem | undefined = this.currentSong();
    const src: string = song?.source ?? '';
    return src.length > 0 ? sourceDisplayName(src) : '未知';
  }

  /** User source script that served the current playback url. */
  private scriptLabel(): string {
    const song: SongItem | undefined = this.currentSong();
    const script: string = song?.playScript ?? '';
    return script.length > 0 ? script : '未知';
  }

  /** Resolved quality id, suffixed with （缓存） when served from a local cached file. */
  private qualityLabel(): string {
    const song: SongItem | undefined = this.currentSong();
    // ★ 本地歌（source/quality 为 'local'）没有音质协商，按**歌曲本身**显示「本地」：
    //   全局音质字段是播放时写的，重启后恢复本地歌时它可能还是空的，
    //   照旧逻辑会掉到「未知」，而播放页徽标会掉到 128k —— 两处都要按歌曲判断。
    if (song !== undefined && (song.source === 'local' || song.quality === 'local')) {
      return 'local';
    }
    let q: string = song?.quality ?? '';
    if (q.length === 0) {
      q = this.state.currentQuality;
    }
    if (q.length === 0) {
      return '未知';
    }
    return song?.playCached === true ? q + '（缓存）' : q;
  }

  private handleCrownVolume(event: CrownEvent): void {
    event.stopPropagation();
    let newVolume = this.state.volume * 100 + event.degree / SongPage.CROWN_STEP_DEGREE;
    newVolume = Math.max(0, Math.min(100, newVolume));
    this.state.volume = newVolume / 100;
    try {
      Logger.info(`SongPage crown setVolume ${this.state.volume}`);
      MediaService.getInstance().avPlayer?.setVolume(this.state.volume);
    } catch (error) {
      Logger.error(`SongPage crown setVolume failed code: ${(error as BusinessError).code}`);
    }
  }

  /** Cover source for the current track: online url when available, else the local resource. */
  private currentCoverSource(): string | Resource {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined && song.cover.length > 0) {
      return song.cover;
    }
    return song !== undefined ? song.label : $r('app.string.page_show');
  }

  build() {
    NavDestination() {
      Stack() {
        Image(this.currentCoverSource())
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .objectFit(ImageFit.Cover)
          .blur(200)
          .opacity(0.4)
        Column() {}
        .backgroundColor('#801c1c1e')

        Column() {
          Column() {
          Text(this.state.getCurrentSongItem()?.title ?? '')
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.font_color'))
            .maxLines(1)
            .width(StyleConstants.FULL_WIDTH)
            .textAlign(TextAlign.Center)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .shaderStyle({
              direction: GradientDirection.Right,
              colors: [
                ['#00FFFFFF', 0.0],
                ['#FFFFFFFF', 0.5],
                ['#00FFFFFF', 1.0]
              ]
            })
            .marqueeOptions({
              start: true,
              fromStart: true,
              step: 6,
              loop: -1,
              delay: 0,
              fadeout: false,
              marqueeStartPolicy: MarqueeStartPolicy.DEFAULT
            })
          Text(this.state.getCurrentSongItem()?.singer ?? '')
            .fontColor($r('app.color.play_singer_color'))
          Column() {
            Text('平台：' + this.sourceLabel())
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('app.color.play_singer_color'))
              .opacity(0.75)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('音源：' + this.scriptLabel())
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('app.color.play_singer_color'))
              .opacity(0.75)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('音质：' + this.qualityLabel())
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('app.color.play_singer_color'))
              .opacity(0.75)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .margin({ top: 6 })
          .alignItems(HorizontalAlign.Center)
          .visibility(this.hasSourceInfo() ? Visibility.Visible : Visibility.None)
          }
          .width('85%')
          Row() {
          SymbolGlyph($r('sys.symbol.backward_end_fill'))
            .fontSize($r('app.float.play_song_img'))
            .fontWeight(FontWeight.Regular)
            .height($r('app.float.play_song_img'))
            .fontColor([$r('app.color.font_color')])
            .onClick(() => {
              MediaService.getInstance().playPrevious();
            })
          Stack() {
            Image(this.currentCoverSource())
              .width($r('app.float.play_circle_img'))
              .height($r('app.float.play_circle_img'))
              .borderRadius(StyleConstants.CIRCLE_BORDER_RADIUS)

            Progress({ value: this.state.progress, total: this.state.progressMax, type: ProgressType.Ring })
              .width($r('app.float.play_progress_width'))
              .backgroundColor(Color.Transparent)
              .color($r('app.color.font_color'))

            Image($r('app.media.play_btn'))
              .width($r('app.float.play_song_img'))
              .visibility(this.state.isPlay === true ? Visibility.None : Visibility.Visible)
              .onClick(() => {
                if (MediaService.getInstance().getFirst()) {
                  MediaService.getInstance().loadAsset(0);
                } else {
                    this.state.isPlay ? MediaService.getInstance().pause() : MediaService.getInstance().play();
                }
              })

            Image($r('app.media.pause_btn'))
              .width($r('app.float.play_song_img'))
              .visibility(this.state.isPlay === true ? Visibility.Visible : Visibility.None)
              .onClick(() => {
                MediaService.getInstance().pause();
              })
          }
          .width(this.halfWidth)
          .align(Alignment.Center)

          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize($r('app.float.play_song_img'))
            .fontWeight(FontWeight.Regular)
            .height($r('app.float.play_song_img'))
            .fontColor([$r('app.color.font_color')])
            .onClick(() => {
              MediaService.getInstance().playNextAuto(true);
            })
          }
          .justifyContent(FlexAlign.SpaceAround)
          .width('85%')

          Row() {
          SymbolGlyph($r('sys.symbol.heart'))
            .fontSize($r('app.float.play_icon_width'))
            .fontWeight(FontWeight.Regular)
            .height($r('app.float.play_icon_width'))
            .fontColor([$r('app.color.font_color')])
          Image($r('app.media.ic_watch_vip'))
            .width($r('app.float.play_icon_width'))
          Image($r('app.media.full_screen'))
            .width($r('app.float.play_icon_width'))
          }
          .width('60%')
          .justifyContent(FlexAlign.SpaceAround)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({ top: $r('app.float.play_column_padding'), bottom: $r('app.float.play_column_padding') })
        .justifyContent(FlexAlign.SpaceAround)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideTitleBar(true)
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .backgroundColor('#000000')
    .onDigitalCrown((event: CrownEvent) => {
      this.handleCrownVolume(event);
    })
  }
}
