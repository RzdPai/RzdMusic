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
import { AppStorageKeys, ShowMiniLyricState, StyleConstants } from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { AmllLyricLine } from '../amll/model/AmllTypes';
import { amllParseLyricCached } from '../amll/parse/AmllAutoDetect';

/**
 * 播放页迷你歌词（当前行 + 下一行），渲染在播放条插槽中，
 * 紧贴进度条上方，不占用/压缩其他布局。
 */
@ComponentV2
export struct MiniLyricLinesComponent {
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local miniLyricState: ShowMiniLyricState =
    AppStorageV2.connect(ShowMiniLyricState, AppStorageKeys.SHOW_MINI_LYRIC_STATE, () => new ShowMiniLyricState())!;
  /** Parsed lyric entries of the current track (cached by song id). */
  private lyricEntries: AmllLyricLine[] = [];
  /** Song key the {@link lyricEntries} cache belongs to. */
  private cachedLyricKey: string = '';

  /** 当前歌词行索引 */
  private miniLyricCurrentIndex(): number {
    const song = this.state.getCurrentSongItem();
    const key: string = song !== undefined ?
      song.source + '_' + song.songId + '_' + song.lyricText.length : '';
    if (key !== this.cachedLyricKey) {
      this.cachedLyricKey = key;
      this.lyricEntries = song !== undefined && song.lyricText.length > 0 ?
        amllParseLyricCached(song.lyricText) : [];
    }
    const t: number = this.state.progress;
    let cur: number = -1;
    for (let i: number = 0; i < this.lyricEntries.length; i++) {
      if (t >= this.lyricEntries[i].startTime && t < this.lyricEntries[i].endTime) {
        cur = i;
        break;
      }
    }
    if (cur === -1) {
      for (let i: number = 0; i < this.lyricEntries.length; i++) {
        if (t >= this.lyricEntries[i].startTime) {
          cur = i;
        } else {
          break;
        }
      }
    }
    return cur;
  }

  /** Parsed lyric lines: [current line text, next line text] at the play position. */
  private miniLyricLines(): string[] {
    const cur = this.miniLyricCurrentIndex();
    const curText: string = cur >= 0 ? this.lyricEntries[cur].words.map((w) => w.word).join('') : '';
    const nextText: string = cur + 1 < this.lyricEntries.length ?
      this.lyricEntries[cur + 1].words.map((w) => w.word).join('') : '';
    return [curText, nextText];
  }

  build() {
    // 未开启时完全不占位；开启后常驻两行空间（切换页面/滑动不跳动）
    if (this.miniLyricState.enabled) {
      Column({ space: 3 }) {
        Text(this.miniLyricLines()[0])
          .fontSize(15)
          .fontColor($r('app.color.player_text_primary'))
          .opacity(0.92)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(StyleConstants.FULL_WIDTH)
        Text(this.miniLyricLines()[1])
          .fontSize(14)
          .fontColor($r('app.color.play_text_color'))
          .opacity(0.6)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(StyleConstants.FULL_WIDTH)
      }
      .width(StyleConstants.FULL_WIDTH)
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 2, bottom: -10 })
    }
  }
}
