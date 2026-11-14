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

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  AppStorageKeys,
  BreakpointType,
  getAppRuntime,
  Logger,
  LyricBlurState,
  LyricFontSizeState,
  MusicStoreService,
  ShowSubLyricState,
  StyleConstants
} from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { AmllLyricLine, AmllLyricFormat, AmllLyricWord } from '../amll/model/AmllTypes';
import {
  amllDetectLyricFormat,
  amllGetCachedLyric,
  amllParseEncryptedQrc,
  amllParseLyricCached,
  amllParseLyricText
} from '../amll/parse/AmllAutoDetect';
import { AmllLyricView } from '../amll/render/AmllLyricView';
import { ControlAreaComponent } from './ControlAreaComponent';
import { LyricFile } from '../constant/LyricConst';
import { PlayerConstants } from '../constant/PlayerConstants';

const TAG = 'LyricsComponent';

/** One parsed translation line (LRC format). */
interface TranslationLine {
  time: number;
  text: string;
}

/** 主歌词标题行关键字（制作人/作词/作曲等元信息行，不参与翻译/罗马音匹配） */
const TITLE_LINE_RE: RegExp = new RegExp(
  '作词|作曲|编曲|制作人|制作|混音|母带|录音|监制|统筹|发行|和声|吉他|贝斯|鼓手|键盘手|' +
  '翻译|时间轴|字幕|OP[：:]|SP[：:]|' +
  'Produced|Producer|Composer|Lyrics|Mix|Master|Engineer|Guitar|Bass|Drum|Keyboard',
  'i'
);

function isTitleLine(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  return TITLE_LINE_RE.test(text);
}

@ComponentV2
export struct LyricsComponent {
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Param isShowControl: boolean = false;
  @Param isTablet: boolean = false;
  @Param hideLyricsMetaHeader: boolean = false;
  @Param panelBottomBar: boolean = false;
  @Param onSeekTime: (ms: number) => void = (): void => {};
  @Local lrcLines: AmllLyricLine[] = [];
  @Local rawLyricText: string = '';

  @Local currentLineText: string = '';
  @Local lyricViewHeight: number = 0;
  @Local translationLines: Array<TranslationLine> = [];
  @Local currentTranslation: string = '';
  /** 翻译/罗马音显示开关（绑定翻译按钮，开时按钮亮起；状态持久化） */
  @Local showSubLyricState: ShowSubLyricState =
    AppStorageV2.connect(ShowSubLyricState, AppStorageKeys.SHOW_SUB_LYRIC_STATE, () => new ShowSubLyricState())!;
  /** 是否存在翻译/罗马音副行（无副行时隐藏翻译按钮） */
  @Local hasSubLyric: boolean = false;
  /** 歌词页模糊效果开关（设置页可调，关闭时上下行用透明度过渡） */
  @Local lyricBlurEnabled: boolean = true;
  /** 设置页共享的模糊开关状态 */
  @Local lyricBlurState: LyricBlurState =
    AppStorageV2.connect(LyricBlurState, AppStorageKeys.LYRIC_BLUR_STATE, () => new LyricBlurState())!;
  /** 设置页共享的歌词字号状态（当前行高亮字号）。 */
  @Local lyricFontSizeState: LyricFontSizeState =
    AppStorageV2.connect(LyricFontSizeState, AppStorageKeys.LYRIC_FONT_SIZE_STATE, () => new LyricFontSizeState())!;

  /** 当前生效的歌词高亮行字号：竖屏/横屏取设置值，面板迷你布局取 0.85 倍。 */
  private activeFontSize(): number {
    return this.panelBottomBar ? Math.round(this.lyricFontSizeState.size * 0.85) : this.lyricFontSizeState.size;
  }

  /** 当前生效的歌词行高：字号 + 12。 */
  private activeLineHeight(): number {
    return this.activeFontSize() + 12;
  }

  /** Current highlighted line height (scaled normal line) used for centering math. */
  private scaledLineHeight(): number {
    const base: number = this.activeLineHeight();
    const scale: number = this.panelBottomBar ? 0.8 : 0.85;
    return base * scale;
  }

  /** Top/bottom inset so the first and last lyric lines can also sit at screen center. */
  private lyricCenterOffset(): number {
    return Math.max(0, (this.lyricViewHeight - this.scaledLineHeight()) / 2);
  }

  private get lyricAbilityContext(): common.UIAbilityContext | undefined {
    return getAppRuntime().context;
  }

  aboutToAppear(): void {
    this.showSubLyricState.enabled = MusicStoreService.getInstance().getShowSubLyric();
    this.lyricBlurEnabled = MusicStoreService.getInstance().getLyricBlurEnabled();
    this.lyricFontSizeState.size = MusicStoreService.getInstance().getLyricFontSize();
    this.loadLyrics();
  }

  @Monitor('lyricBlurState.enabled')
  onLyricBlurChanged(): void {
    this.lyricBlurEnabled = this.lyricBlurState.enabled;
  }

  @Monitor('lyricFontSizeState.size')
  onLyricFontSizeChanged(): void {
    if (this.lyricFontSizeState.size !== MusicStoreService.getInstance().getLyricFontSize()) {
      MusicStoreService.getInstance().setLyricFontSize(this.lyricFontSizeState.size);
    }
  }

  @Monitor('state.progress')
  updateCurrentLineText(): void {
    const progress: number = this.state.progress;
    if (this.lrcLines.length === 0) {
      this.currentLineText = '';
    } else {
      let found: string = '';
      let lo = 0;
      let hi = this.lrcLines.length - 1;
      let idx = -1;
      while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        if (this.lrcLines[mid].startTime <= progress) {
          if (progress < this.lrcLines[mid].endTime) {
            idx = mid;
            break;
          }
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      if (idx === -1 && hi >= 0) {
        if (progress >= this.lrcLines[hi].startTime && progress < this.lrcLines[hi].endTime) {
          idx = hi;
        }
      }
      if (idx >= 0) {
        found = this.lrcLines[idx].words.map((w) => w.word).join('');
      }
      if (this.currentLineText !== found) {
        this.currentLineText = found;
      }
    }
    if (this.translationLines.length === 0) {
      if (this.currentTranslation !== '') {
        this.currentTranslation = '';
      }
      return;
    }
    let lo = 0;
    let hi = this.translationLines.length - 1;
    let idx = -1;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (this.translationLines[mid].time <= progress) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    const foundTrans: string = idx >= 0 ? this.translationLines[idx].text : '';
    if (this.currentTranslation !== foundTrans) {
      this.currentTranslation = foundTrans;
    }
  }

  /** Parses LRC translation text into time-sorted lines. */
  private parseTranslationLines(text: string): Array<TranslationLine> {
    const result: Array<TranslationLine> = [];
    if (!text || text.length === 0) {
      return result;
    }
    const lines: string[] = text.replace(/\r\n/g, '\n').split('\n');
    for (let i: number = 0; i < lines.length; i++) {
      const m: RegExpMatchArray | null = lines[i].match(/^\[(\d{1,2}):(\d{2})[.:](\d{1,3})\](.*)$/);
      if (m === null || m.length < 5) {
        continue;
      }
      const content: string = (m[4] || '').trim();
      if (content.length === 0) {
        continue;
      }
      const ms: number = (Number.parseInt(m[1]) * 60 + Number.parseInt(m[2])) * 1000 +
        Number.parseInt(m[3].padEnd(3, '0'));
      const entry: TranslationLine = { time: ms, text: content };
      result.push(entry);
    }
    result.sort((a: TranslationLine, b: TranslationLine): number => a.time - b.time);
    return result;
  }

  @Monitor('state.selectIndex', 'state.playQueueIds', 'state.playQueue', 'state.lyricVersion')
  loadLyrics(): void {
    this.lrcLines = [];
    this.rawLyricText = '';
    this.currentLineText = '';
    this.translationLines = [];
    this.currentTranslation = '';
    this.hasSubLyric = false;
    const song = this.state.getCurrentSongItem();
    if (!song) {
      return;
    }
    this.translationLines = this.parseTranslationLines(song.lyricTranslation);
    if (song.lyricText && song.lyricText.length > 0) {
      this.rawLyricText = song.lyricText;
      const text: string = song.lyricText;
      const hit: AmllLyricLine[] | undefined = amllGetCachedLyric(text);
      if (hit !== undefined) {
        // 缓存命中（播放器打开时已预热）：直接应用
        this.lrcLines = hit;
        this.attachTranslations();
        this.attachRoman();
        this.updateHasSubLyric();
        return;
      }
      // 未预热：延迟到页面切换动画结束后再解析，避免切页掉帧
      const self = this;
      setTimeout((): void => {
        if (self.rawLyricText !== text) {
          return;
        }
        self.lrcLines = amllParseLyricCached(text);
        self.attachTranslations();
        self.attachRoman();
        self.updateHasSubLyric();
      }, 250);
      return;
    }
    if (!this.lyricAbilityContext) {
      return;
    }
    const lyricPath = song.lyric;
    if (!lyricPath || lyricPath.length === 0) {
      return;
    }
    try {
      this.lyricAbilityContext.resourceManager.getRawFileContent(lyricPath)
        .then((value: Uint8Array) => {
          let textDecoder = util.TextDecoder.create(PlayerConstants.ENCODING, { ignoreBOM: true });
          let stringData = textDecoder.decodeToString(value, { stream: false });
          if (lyricPath.endsWith(LyricFile.krc)) {
            this.lrcLines = amllParseLyricText(stringData, AmllLyricFormat.KRC);
          } else if (lyricPath.endsWith(LyricFile.qrc)) {
            // QRC 可能是加密的 16 进制串，也可能是明文
            const fmt: AmllLyricFormat = amllDetectLyricFormat(stringData);
            this.lrcLines = amllParseLyricText(stringData, fmt);
            if (this.lrcLines.length === 0 && fmt === AmllLyricFormat.QRC) {
              this.lrcLines = amllParseEncryptedQrc(stringData);
            }
          } else {
            this.rawLyricText = stringData;
            this.lrcLines = amllParseLyricText(stringData);
          }
          this.attachTranslations();
      this.attachRoman();
      this.updateHasSubLyric();
        })
        .catch((error: BusinessError) => {
          Logger.error(TAG, `getRawFileContent failed, code: ${error.code}, message: ${error.message}`);
        });
    } catch (error) {
      Logger.error(TAG, `${error.code} + ${error.message}`);
    }
  }

  /** 是否有任意副行（翻译/罗马音）：没有则隐藏翻译开关按钮 */
  private updateHasSubLyric(): void {
    let found = false;
    for (let i = 0; i < this.lrcLines.length; i++) {
      const line = this.lrcLines[i];
      if (line.translatedLyric.length > 0 || line.romanLyric.length > 0) {
        found = true;
        break;
      }
    }
    this.hasSubLyric = found;
  }

  /** 通用歌词文本解析：支持 LRC/QRC/ESLRC/YRC/TTML 等任意格式，返回按时间升序的行 */
  private parseAnyLyricLines(text: string): Array<TranslationLine> {
    const result: Array<TranslationLine> = [];
    if (!text || text.length === 0) {
      return result;
    }
    const lines: AmllLyricLine[] = amllParseLyricText(text);
    for (let i: number = 0; i < lines.length; i++) {
      let lineText = '';
      for (let w: number = 0; w < lines[i].words.length; w++) {
        lineText += lines[i].words[w].word;
      }
      const lineTextRaw = lineText.trim();
      // 版权声明行（如 "QQ音乐享有本翻译作品的著作权"）不参与匹配也不消费
      if (lineTextRaw.includes('QQ音乐') || lineTextRaw.includes('著作权')) {
        continue;
      }
      // 空行 / QQ 占位行（//）保留：用于消费标题行（歌名/作詞/作曲等）的匹配位，
      // 使真歌词行能匹配到真正的翻译/罗马音；文本置空表示"有行但无内容"
      const textValue: string = lineTextRaw.startsWith('//') ? '' : lineTextRaw;
      const entry: TranslationLine = { time: lines[i].startTime, text: textValue };
      result.push(entry);
    }
    result.sort((a: TranslationLine, b: TranslationLine): number => a.time - b.time);
    return result;
  }

  /** 拼接主歌词行的全部文本（用于标题行识别） */
  private lineTextOf(line: AmllLyricLine): string {
    let text = '';
    for (let w: number = 0; w < line.words.length; w++) {
      text += line.words[w].word;
    }
    return text.trim();
  }

  /**
   * 将子歌词行（翻译/罗马音）附加到主歌词行。
   * 逐主行找"未消费"且时间最近（<= 窗口）的子行，每个子行至多匹配一个主行；
   * 窗口内无对应子行的主行留空（不补）。空文本子行只消费不附加（防止标题行抢走真歌词行）。
   */
  private attachSubLyric(target: string): void {
    if (target.length === 0 || this.lrcLines.length === 0) {
      return;
    }
    const subLines: Array<TranslationLine> = this.parseAnyLyricLines(target);
    if (subLines.length === 0) {
      return;
    }
    const MATCH_WINDOW_MS: number = 300;
    const used: boolean[] = new Array<boolean>(subLines.length).fill(false);
    for (let i: number = 0; i < this.lrcLines.length; i++) {
      const mainTime: number = this.lrcLines[i].startTime;
      // 标题行（制作人/作词/作曲等）不参与匹配，防止抢走第一句真歌词的翻译/罗马音
      if (isTitleLine(this.lineTextOf(this.lrcLines[i]))) {
        continue;
      }
      let bestIdx: number = -1;
      let bestDiff: number = Number.MAX_VALUE;
      for (let j: number = 0; j < subLines.length; j++) {
        if (used[j]) {
          continue;
        }
        const diff: number = Math.abs(subLines[j].time - mainTime);
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = j;
        }
      }
      if (bestIdx >= 0 && bestDiff <= MATCH_WINDOW_MS) {
        used[bestIdx] = true;
        const matched: TranslationLine = subLines[bestIdx];
        if (matched.text.length === 0) {
          // 空占位行：消费掉，不附加任何内容
          continue;
        }
        if (target === this.state.getCurrentSongItem()?.lyricTranslation) {
          this.lrcLines[i].translatedLyric = matched.text;
        } else {
          this.lrcLines[i].romanLyric = matched.text;
        }
      }
    }
  }

  /** Attaches the nearest translation (by line start time) to each lyric line. */
  private attachTranslations(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.lyricTranslation.length === 0 || this.lrcLines.length === 0) {
      return;
    }
    this.attachSubLyric(song.lyricTranslation);
  }

  /** Attaches the romanization (romaji) lyric to each line by time match. */
  private attachRoman(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.lyricRoman.length === 0 || this.lrcLines.length === 0) {
      return;
    }
    this.attachSubLyric(song.lyricRoman);
    this.attachRomanWords(song.lyricRoman);
  }

  /**
   * 解析罗马音逐字时间戳（QRC/YRC 等带字级时间格式），
   * 按最近时间匹配将逐字词附加到主歌词行的 romanWords（用于逐字高亮）。
   */
  private attachRomanWords(target: string): void {
    const subLines: AmllLyricLine[] = amllParseLyricText(target);
    if (subLines.length === 0) {
      return;
    }
    const MATCH_WINDOW_MS: number = 300;
    const used: boolean[] = new Array<boolean>(subLines.length).fill(false);
    for (let i: number = 0; i < this.lrcLines.length; i++) {
      const mainTime: number = this.lrcLines[i].startTime;
      // 标题行（制作人/作词/作曲等）不参与匹配，防止抢走第一句真歌词的翻译/罗马音
      if (isTitleLine(this.lineTextOf(this.lrcLines[i]))) {
        continue;
      }
      let bestIdx: number = -1;
      let bestDiff: number = Number.MAX_VALUE;
      for (let j: number = 0; j < subLines.length; j++) {
        if (used[j]) {
          continue;
        }
        const diff: number = Math.abs(subLines[j].startTime - mainTime);
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = j;
        }
      }
      if (bestIdx >= 0 && bestDiff <= MATCH_WINDOW_MS) {
        used[bestIdx] = true;
        const words: AmllLyricWord[] = subLines[bestIdx].words;
        if (words.length > 1 || (words.length === 1 && words[0].startTime !== subLines[bestIdx].startTime)) {
          this.lrcLines[i].romanWords = words;
        }
      }
    }
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.lrcLines.length > 0) {
          AmllLyricView({
            lyricLines: this.lrcLines,
            currentTime: this.state.progress,
            isPlay: this.state.isPlay,
            fontSize: this.activeFontSize(),
            fontWeight: '700',
            textColor: '#FFFFFF',
            glowColor: '#FFFFFF',
            lineWidthAspect: 0.95,
            enableBlur: this.lyricBlurEnabled,
            enableScale: true,
            hidePassedLines: false,
            showSubLyric: this.showSubLyricState.enabled,
            enableSpring: true,
            wordFadeWidth: 0.5,
            contentStartOffset: this.lyricCenterOffset(),
            contentEndOffset: this.lyricCenterOffset(),
            onSeekTime: (ms: number): void => {
              this.state.progress = ms;
              this.onSeekTime(ms);
            }
          })
            .width('100%')
            .height('100%')
            .accessibilityGroup(true)
            .accessibilityText(this.currentLineText)
            .accessibilityLevel('yes')
        } else {
          // 无歌词：不显示"纯音乐"占位，由外层布局处理（竖屏隐藏歌词页/横屏封面居中）
          Text('')
            .width('80%')
        }
        // 悬浮操作按钮（不占布局空间）：竖屏的翻译/点赞按钮叠在歌词右下角，
        // 释放原按钮行占用的高度，歌词 Canvas 下边界可延伸到控件行
        if (!this.panelBottomBar) {
          Row({ space: 16 }) {
            if (this.isTablet) {
              Image($r('app.media.ic_public_likes'))
                .width($r('app.float.likes_image_lg'))
                .height($r('app.float.likes_image_lg'))
                .objectFit(ImageFit.Contain)
                .margin({
                  right: $r('app.float.likes_margin')
                })
            }
            if (this.hasSubLyric) {
              SymbolGlyph($r('sys.symbol.translate_square'))
                .fontSize(20)
                .fontWeight(FontWeight.Regular)
                .height(20)
                .fontColor([$r('app.color.play_text_color')])
                .opacity(this.showSubLyricState.enabled ? 1 : 0.35)
                .onClick((): void => {
                  const next: boolean = !this.showSubLyricState.enabled;
                  this.showSubLyricState.enabled = next;
                  MusicStoreService.getInstance().setShowSubLyric(next);
                })
            }
          }
          .justifyContent(FlexAlign.End)
          .margin({
            right: new BreakpointType(
              $r('app.float.lyric_margin_right_sm'),
              $r('app.float.lyric_margin_right_md'),
              $r('app.float.lyric_margin_right_lg'),
              $r('app.float.lyric_margin_right_lg')
            ).getValue(this.breakpointEnv.widthBreakpoint),
            bottom: this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
              this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD ? 24 : 12
          })
        }
      }
      .layoutWeight(1)
      .width(StyleConstants.FULL_WIDTH)

      if (this.panelBottomBar) {
        Row({ space: 48 }) {
          SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
            .fontSize(32)
            .fontWeight(FontWeight.Regular)
            .height(32)
            .fontColor([$r('app.color.play_text_color')])
          SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
            .fontSize(32)
            .fontWeight(FontWeight.Regular)
            .height(32)
            .fontColor([$r('app.color.play_text_color')])
        }
        .width(StyleConstants.FULL_WIDTH)
        .height($r('app.float.control_icon_height'))
        .justifyContent(FlexAlign.End)
      }

      if (this.isShowControl) {
        ControlAreaComponent()
          .margin({
            top: $r('app.float.control_lyric_margin'),
            bottom: $r('app.float.music_component_bottom')
          })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height('100%')
  }
}
