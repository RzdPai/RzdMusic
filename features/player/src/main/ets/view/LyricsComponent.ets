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
  StyleConstants,
  traditionalize
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
  /**
   * 是否隐藏"歌名 - 歌手"这行自带表头。
   *
   * ★★ 2026-10-15：**默认值从 `false` 翻成 `true`** —— 让"照搬无界"成为**默认行为**。
   *   理由：① 无界**没有**这个内建表头（`歌词页浮层封面与歌名定稿.md` L1449 原文：
   *   「无界没有 `LyricsComponent` 内建 header 这回事」）；② 播放页**三处**调用点
   *   （手机 Swiper 歌词页 / 宽屏 `GridCol` / 面板）现在**全部**显式传 `true`，
   *   而且那两条非手机分支各自都另有 `MusicPlayInfoBlock` 在显示歌名 ⇒ 留着就是重复。
   *   ⇒ 把默认值翻过来：**将来谁新加调用点忘了传，也默认落在"与无界一致"那一侧**，
   *     而不是默默多出一行重复的歌名（这正是 §56.19 记的"N 处只改一处"那类问题的防线）。
   */
  @Param hideLyricsMetaHeader: boolean = true;
  @Param panelBottomBar: boolean = false;
  @Param onSeekTime: (ms: number) => void = (): void => {};
  @Local lrcLines: AmllLyricLine[] = [];
  @Local rawLyricText: string = '';
  /**
   * `renderLines()` 的缓存（见该方法注释：`@Param` 按引用比对，不能每帧新建数组）。
   * `metaCutCacheSrc` 存"这份缓存是按哪个源数组算的"，源换引用即失效。
   */
  private metaCutCacheSrc: AmllLyricLine[] | undefined = undefined;
  private metaCutCache: AmllLyricLine[] = [];

  @Local currentLineText: string = '';
  @Local lyricViewHeight: number = 0;
  @Local translationLines: Array<TranslationLine> = [];
  @Local currentTranslation: string = '';
  /** 翻译/罗马音显示开关（绑定翻译按钮，开时按钮亮起；状态持久化） */
  @Local showSubLyricState: ShowSubLyricState =
    AppStorageV2.connect(ShowSubLyricState, AppStorageKeys.SHOW_SUB_LYRIC_STATE, () => new ShowSubLyricState())!;
  /** 是否存在翻译/罗马音副行（无副行时隐藏翻译按钮） */
  @Local hasSubLyric: boolean = false;
  /** 歌词繁体显示（简/繁按钮） */
  @Local lyricS2tEnabled: boolean = false;
  /** 歌词页模糊效果开关（设置页可调，关闭时上下行用透明度过渡） */
  @Local lyricBlurEnabled: boolean = false;
  /** No extra blur surfaces before the persisted preference has been read. */
  @Local lyricBlurPreferenceReady: boolean = false;
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
    const store = MusicStoreService.getInstance();
    const showTrans: boolean = store.getShowLyricTranslation();
    const showRoma: boolean = store.getShowLyricRoma();
    this.showSubLyricState.enabled = showTrans || showRoma;
    this.lyricS2tEnabled = store.getLyricS2t();
    this.syncLyricBlurPreference('appear');
    this.lyricFontSizeState.size = MusicStoreService.getInstance().getLyricFontSize();
    this.loadLyrics();
  }

  private syncLyricBlurPreference(reason: string): void {
    this.lyricBlurPreferenceReady = false;
    if (getAppRuntime().context === undefined) {
      this.lyricBlurEnabled = false;
      Logger.warn('LyricViewportBlur', `preference reason=${reason} synced=false effective=false`);
      return;
    }
    const store = MusicStoreService.getInstance();
    if (reason === 'shared-change') {
      // ★★ 2026-10-14 修「模糊开关经常不跟随设置」：外部（设置页/云同步/别处）改的是**共享状态**，
      //   这里原来一律拿 store 的值**反向覆盖**共享状态 —— 只要 store 落后一步（异步落盘、云同步只写了 store…）
      //   就会把用户刚选的开关**改回去**，表现就是"点了没反应/过一会儿又变回来"。
      //   共享状态是无歧义的用户选择，这一支直接以它为准并落库（不再回读 store）。
      this.lyricBlurEnabled = this.lyricBlurState.enabled;
      if (store.getLyricBlurEnabled() !== this.lyricBlurState.enabled) {
        store.setLyricBlurEnabled(this.lyricBlurState.enabled);
      }
    } else {
      const storedEnabled: boolean = store.getLyricBlurEnabled();
      this.lyricBlurEnabled = storedEnabled;
      this.lyricBlurState.enabled = storedEnabled;
    }
    this.lyricBlurPreferenceReady = true;
    Logger.info('LyricViewportBlur',
      `preference reason=${reason} shared=${this.lyricBlurState.enabled} effective=${this.lyricBlurEnabled} synced=true`);
  }

  @Monitor('lyricBlurState.enabled')
  onLyricBlurChanged(): void {
    // Settings writes the store before publishing shared state. Never persist a UI fallback.
    this.syncLyricBlurPreference('shared-change');
  }

  @Monitor('lyricFontSizeState.size')
  onLyricFontSizeChanged(): void {
    if (this.lyricFontSizeState.size !== MusicStoreService.getInstance().getLyricFontSize()) {
      MusicStoreService.getInstance().setLyricFontSize(this.lyricFontSizeState.size);
    }
  }

  /**
   * ★★★ 2026-10-16（**修"播放界面错位"的真根因**）：
   *   让 `hideLyricsMetaHeader` 这个 `@Param` **真正生效** ——
   *   在此之前它**只有声明**（`grep hideLyricsMetaHeader` 全文件只命中声明那一行），
   *   也就是说"藏掉歌词页自带表头"这件事**几轮前以为改了、其实从未生效**。
   *
   * ## 用户看到的现象与它怎么对上
   *
   * 用户截图里贴在一起的两行是 **`作词：唐恬` / `作曲：钱雷`** ——
   * 它们**不是小歌词组件画的**，而是**歌词正文的头两行**（LRC 里排在最前面的标题行）。
   * `AmllLyricView` 拿到**整份** `lrcLines`（含这两行），并把它当普通歌词**一起滚动**；
   * 这两行的 `startTime` 是 0，于是静止在封面页/歌词页时它们正好停在屏上那一条高度带里，
   * 与 `Swiper` **之外**那条歌名/歌手覆盖层（`LyricFloatLayer`）**重叠** ⇒ 就是"错位"。
   *
   * ## 为什么之前把修法放错了地方
   *
   * 我原以为那是"小歌词组件与歌名行抢位"，于是去改 `MiniLyricLinesComponent` 的让位量
   * （`MINI_LYRIC_SINK_VP = 44`）。**但小歌词那一支默认是关的**
   * （`MusicStoreService.getShowMiniLyric()` 的默认值是 `false`）⇒ 那条修法**根本不在渲染树里**。
   * 真正的渲染者是这里。
   *
   * ## 实现上的两条安全线（避免误伤）
   *
   * 1. **只掐"开头连续"的标题行** —— 一旦遇到第一行**非**标题行就停手。
   *    理由：有些歌词正文里会出现"作曲：我自己"这种句子，无条件过滤会把真歌词也删掉；
   *    而真实 LRC 的元信息**恒在最前面**。
   * 2. `hideLyricsMetaHeader === false` 时**原样返回**（零行为变化）——
   *    宽屏/面板那两支与老调用点不受影响。
   *
   * @returns 送进渲染器的行数组（可能比 `lrcLines` 短若干行）
   */
  private renderLines(): AmllLyricLine[] {
    if (!this.hideLyricsMetaHeader || this.lrcLines.length === 0) {
      return this.lrcLines;
    }
    // ⚠️ 必须缓存：`@Param` 是按**引用**比对的，每次 build 新建数组会让
    //    `AmllLyricView` 每帧都认为"歌词变了"（白重排 + 可能打断滚动动画）。
    //    失效条件：源数组换了引用（`loadLyrics` 每次都是整体赋值）或开关翻转。
    if (this.metaCutCacheSrc === this.lrcLines) {
      return this.metaCutCache;
    }
    let cut: number = 0;
    while (cut < this.lrcLines.length && isTitleLine(this.lineTextOf(this.lrcLines[cut]))) {
      cut++;
    }
    if (cut === 0) {
      this.metaCutCacheSrc = this.lrcLines;
      this.metaCutCache = this.lrcLines;
      return this.lrcLines;
    }
    // 全部都是标题行（极端：歌词只有元信息）⇒ 不裁，否则页面会变成"无歌词"空态
    if (cut >= this.lrcLines.length) {
      this.metaCutCacheSrc = this.lrcLines;
      this.metaCutCache = this.lrcLines;
      return this.lrcLines;
    }
    const kept: AmllLyricLine[] = [];
    for (let i: number = cut; i < this.lrcLines.length; i++) {
      kept.push(this.lrcLines[i]);
    }
    this.metaCutCacheSrc = this.lrcLines;
    this.metaCutCache = kept;
    return kept;
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
    // 简繁转换：对齐 lx player.isS2t
    const s2t: boolean = MusicStoreService.getInstance().getLyricS2t();
    let mainLyric: string = song.lyricText ?? '';
    let transLyric: string = song.lyricTranslation ?? '';
    if (s2t) {
      if (mainLyric.length > 0) {
        mainLyric = traditionalize(mainLyric);
      }
      if (transLyric.length > 0) {
        transLyric = traditionalize(transLyric);
      }
    }
    this.translationLines = this.parseTranslationLines(transLyric);
    if (mainLyric.length > 0) {
      this.rawLyricText = mainLyric;
      const text: string = mainLyric;
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
  /**
   * 是否显示「译」按钮：取决于当前歌曲是否有翻译/罗马音数据，
   * 与副歌词是否正在显示无关，避免关闭后按钮消失无法再打开。
   */
  private updateHasSubLyric(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined) {
      this.hasSubLyric = false;
      return;
    }
    this.hasSubLyric = song.lyricTranslation.length > 0 || song.lyricRoman.length > 0;
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
  /**
   * @param target 子歌词原文
   * @param asTranslation true=写入 translatedLyric；false=写入 romanLyric
   */
  private attachSubLyric(target: string, asTranslation: boolean): void {
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
          continue;
        }
        if (asTranslation) {
          this.lrcLines[i].translatedLyric = matched.text;
        } else {
          this.lrcLines[i].romanLyric = matched.text;
        }
      }
    }
  }

  /** Attaches the nearest translation (by line start time) to each lyric line. */
  private attachTranslations(): void {
    if (!MusicStoreService.getInstance().getShowLyricTranslation()) {
      // 关闭翻译时清空已有行上的译文
      for (let i: number = 0; i < this.lrcLines.length; i++) {
        this.lrcLines[i].translatedLyric = '';
      }
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.lyricTranslation.length === 0 || this.lrcLines.length === 0) {
      return;
    }
    let trans: string = song.lyricTranslation;
    if (MusicStoreService.getInstance().getLyricS2t()) {
      trans = traditionalize(trans);
    }
    this.attachSubLyric(trans, true);
  }

  /** Attaches the romanization (romaji) lyric to each line by time match. */
  private attachRoman(): void {
    if (!MusicStoreService.getInstance().getShowLyricRoma()) {
      for (let i: number = 0; i < this.lrcLines.length; i++) {
        this.lrcLines[i].romanLyric = '';
        this.lrcLines[i].romanWords = [];
      }
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.lyricRoman.length === 0 || this.lrcLines.length === 0) {
      return;
    }
    this.attachSubLyric(song.lyricRoman, false);
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
            // ★★★ 2026-10-16：**必须用 `renderLines()`**（掐掉开头的标题行），
            //   否则 `作词：唐恬` / `作曲：钱雷` 会当普通歌词一起滚上去，
            //   与歌名/歌手覆盖层重叠 —— 用户实测的「播放界面错位」就是它。
            //   详见 `renderLines()` 的注释。
            lyricLines: this.renderLines(),
            currentTime: this.state.progress,
            isPlay: this.state.isPlay,
            fontSize: this.activeFontSize(),
            fontWeight: '700',
            textColor: '#FFFFFF',
            glowColor: '#FFFFFF',
            lineWidthAspect: 0.95,
            enableBlur: this.lyricBlurEnabled,
            blurPreferenceReady: this.lyricBlurPreferenceReady,
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
        // 悬浮操作按钮：左「简/繁」单字切换与右「译」同框样式、中轴对称
        if (!this.panelBottomBar) {
          Row() {
            // 左侧：只显示当前态一字，点击在 简↔繁 间切换
            Text(this.lyricS2tEnabled ? '繁' : '简')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.play_text_color'))
              .width(28)
              .height(28)
              .textAlign(TextAlign.Center)
              .border({
                width: 1.5,
                color: $r('app.color.play_text_color'),
                radius: 6
              })
              .opacity(0.9)
              .onClick((): void => {
                const next: boolean = !this.lyricS2tEnabled;
                this.lyricS2tEnabled = next;
                MusicStoreService.getInstance().setLyricS2t(next);
                this.loadLyrics();
              })

            Blank()

            // 右侧：译 + 平板点赞（与左侧同尺寸描边框）
            Row({ space: 16 }) {
              if (this.isTablet) {
                Image($r('app.media.ic_public_likes'))
                  .width($r('app.float.likes_image_lg'))
                  .height($r('app.float.likes_image_lg'))
                  .objectFit(ImageFit.Contain)
              }
              if (this.hasSubLyric) {
                Text('译')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.play_text_color'))
                  .width(28)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .border({
                    width: 1.5,
                    color: $r('app.color.play_text_color'),
                    radius: 6
                  })
                  .opacity(this.showSubLyricState.enabled ? 0.9 : 0.35)
                  .onClick((): void => {
                    const next: boolean = !this.showSubLyricState.enabled;
                    this.showSubLyricState.enabled = next;
                    const store = MusicStoreService.getInstance();
                    store.setShowLyricTranslation(next);
                    store.setShowLyricRoma(next);
                    this.attachTranslations();
                    this.attachRoman();
                    this.updateHasSubLyric();
                  })
              }
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .padding({
            left: new BreakpointType(
              $r('app.float.lyric_margin_right_sm'),
              $r('app.float.lyric_margin_right_md'),
              $r('app.float.lyric_margin_right_lg'),
              $r('app.float.lyric_margin_right_lg')
            ).getValue(this.breakpointEnv.widthBreakpoint),
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

      // ★★★ 2026-10-21（甲方：「横屏播放页右下角那两个按钮去掉，没用还占空间」）：
      //   这里原来在 `panelBottomBar` 档画两颗 `SymbolGlyph`（全屏箭头 `arrow_up_left_and_arrow_down_right`
      //   + 菜单圆点 `dot_grid_1x2_circle`），**两颗都没有 `onClick`** —— 纯占位的死 UI，
      //   而且吃掉一行 `control_icon_height` 的歌词高度。⇒ 整块删掉。
      //   `panelBottomBar` 这个参数本身保留：它还在控制横屏歌词的**字号/行距**档
      //   （见本文件 `lyricFontSize()` / `renderLines()` 里的 0.85 / 0.8 缩放）。

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
