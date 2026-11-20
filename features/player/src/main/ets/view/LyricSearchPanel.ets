/*
 * 「搜索歌词」面板（播放页歌曲菜单的子页）。
 *
 * ★ 2026-11-09（用户：「MusicFree 很多源没有歌词接口，你在播放器内歌曲菜单中加个搜索歌词」）：
 *   在线歌的歌词只有两条来源：插件 `getLyric` / 洛雪内置接口。插件没实现 `getLyric`
 *   时（MusicFree 里很常见），当前歌就永远没有词。这里复用本地歌那套「逐平台搜索 +
 *   相似度打分」（`util/LyricMatch`，已下沉到 player，**没有第二份实现**），
 *   用户挑一条后落盘到 `MusicStoreService`，重播也有词。
 *
 * 面板是自绘的，不另开 bindSheet：播放器本身就是系统半模态，再叠系统弹层会打架
 * （与 LyricMatchSheet 同一结论）。
 */

import { lxGetLyricFull, LyricFullResult } from '../source/LXMusicSDK';
import {
  LyricCandidate, MATCH_PLATFORMS, MatchSongInfo, scoreCandidate, searchCandidates
} from '../util/LyricMatch';
import { lxSourceLabel } from '../util/SourceDeclaredInfo';
import { MediaService } from '../model/MediaService';
import { MusicStoreService } from 'musicbasic';

/** 一条候选：平台 + 歌 + 相似度。 */
class LyricSearchRow {
  info: MatchSongInfo = {
    songId: '', name: '', singer: '', albumName: '', albumId: '', source: '', interval: '', img: ''
  };
  score: number = 0;
}

/** 最多列多少条（一屏够看，避免几十条噪音）。 */
const MAX_ROWS: number = 30;

@ComponentV2
export struct LyricSearchPanel {
  /** 当前歌的歌名 / 歌手（搜索框初值 + 打分基准）。 */
  @Param songTitle: string = '';
  @Param songSinger: string = '';
  @Param songSource: string = '';
  @Param songId: string = '';
  /** 时长（毫秒；0 = 未知）。 */
  @Param durationMs: number = 0;
  /** 主题色（用户可改）。 */
  @Param accentColor: ResourceColor = '#E60012';
  /** 应用成功后通知宿主（关闭弹层 / 刷新歌词）。 */
  @Event onApplied: () => void = (): void => {};
  /** 返回歌曲菜单主列表（本子页自带返回，底部共用按钮栏在这里不显示）。 */
  @Event onBack: () => void = (): void => {};

  @Local keyword: string = '';
  @Local searching: boolean = false;
  @Local searched: boolean = false;
  @Local rows: LyricSearchRow[] = [];
  /** 正在取词的候选（`source|songId`；空 = 没在取）。 */
  @Local applyingKey: string = '';
  /** 当前歌是否已经有手动歌词（显示「恢复自动歌词」）。 */
  @Local hasManual: boolean = false;

  aboutToAppear(): void {
    this.keyword = this.songSinger.length > 0 ? (this.songTitle + ' ' + this.songSinger) : this.songTitle;
    this.hasManual = MusicStoreService.getInstance()
      .getManualLyric(this.songSource, this.songId).length > 0;
    void this.search();
  }

  /** 逐平台搜索，边搜边并进列表（一个平台失败不影响别的）。 */
  private async search(): Promise<void> {
    const keyword: string = this.keyword.trim();
    if (keyword.length === 0 || this.searching) {
      return;
    }
    this.searching = true;
    this.searched = true;
    this.rows = [];
    try {
      for (let p: number = 0; p < MATCH_PLATFORMS.length; p++) {
        const platform: string = MATCH_PLATFORMS[p];
        let results: MatchSongInfo[] = [];
        try {
          results = await searchCandidates(keyword, platform);
        } catch (_err) {
          continue;
        }
        const fresh: LyricSearchRow[] = [];
        for (let i: number = 0; i < results.length; i++) {
          const scored: LyricCandidate =
            scoreCandidate(results[i], this.songTitle, this.songSinger, this.durationMs);
          // 歌名完全不像的（归一化后毫无交集）不列，免得一屏全是无关的歌
          if (scored.score <= 0) {
            continue;
          }
          const row: LyricSearchRow = new LyricSearchRow();
          row.info = results[i];
          row.score = scored.score;
          fresh.push(row);
        }
        this.rows = this.merge(this.rows, fresh);
      }
    } finally {
      this.searching = false;
    }
  }

  /** 并入结果：按相似度排序，同名同歌手只留第一条。 */
  private merge(current: LyricSearchRow[], fresh: LyricSearchRow[]): LyricSearchRow[] {
    const out: LyricSearchRow[] = current.slice();
    for (let i: number = 0; i < fresh.length; i++) {
      const item: LyricSearchRow = fresh[i];
      let exists: boolean = false;
      for (let k: number = 0; k < out.length; k++) {
        if (out[k].info.name === item.info.name && out[k].info.singer === item.info.singer) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        out.push(item);
      }
    }
    out.sort((a: LyricSearchRow, b: LyricSearchRow): number => b.score - a.score);
    return out.length > MAX_ROWS ? out.slice(0, MAX_ROWS) : out;
  }

  /** 选中一条：取词 → 落盘 → 应用。 */
  private async pick(row: LyricSearchRow): Promise<void> {
    const key: string = row.info.source + '|' + row.info.songId;
    if (this.applyingKey.length > 0) {
      return;
    }
    this.applyingKey = key;
    try {
      const full: LyricFullResult = await lxGetLyricFull(
        row.info.source, row.info.songId, row.info.name, row.info.singer);
      if (full.main.length === 0) {
        this.toast('这个平台没有取到歌词，换一条试试');
        return;
      }
      const ok: boolean = MediaService.getInstance().applyManualLyric(
        full.main, full.translation, full.romanLyric);
      if (!ok) {
        this.toast('当前没有正在播放的歌');
        return;
      }
      this.hasManual = true;
      this.toast('歌词已应用');
      this.onApplied();
    } catch (_err) {
      this.toast('取歌词失败，请检查网络');
    } finally {
      this.applyingKey = '';
    }
  }

  /** 恢复插件 / 内置接口的歌词（删掉手动结果）。 */
  private restoreAuto(): void {
    void MediaService.getInstance().restoreAutoLyric().then((): void => {
      this.hasManual = false;
      this.toast('已恢复自动歌词');
      this.onApplied();
    });
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
  }

  /** 一行：歌名 + 歌手 · 专辑 + 平台标签 + 时长。 */
  @Builder
  private RowView(row: LyricSearchRow) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(row.info.name)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(row.info.singer + (row.info.albumName.length > 0 ? ' · ' + row.info.albumName : ''))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(lxSourceLabel(row.info.source))
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(4)
        .backgroundColor($r('sys.color.background_tertiary'))

      if (this.applyingKey === row.info.source + '|' + row.info.songId) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.accentColor)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(10)
    .backgroundColor(Color.Transparent)
    .onClick((): void => {
      void this.pick(row);
    })
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.font_primary')])
          .padding({ right: 2 })
          .onClick((): void => {
            this.onBack();
          })
        Text('搜索歌词')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
      }
      .width('100%')
      .margin({ top: 8 })

      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '歌名 歌手' })
          .layoutWeight(1)
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .onChange((value: string): void => {
            this.keyword = value;
          })
          .onSubmit((): void => {
            void this.search();
          })
        Button('搜索')
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor(this.accentColor)
          .fontColor($r('sys.color.font_on_primary'))
          .enabled(!this.searching)
          .onClick((): void => {
            void this.search();
          })
      }
      .width('100%')

      if (this.hasManual) {
        Row({ space: 6 }) {
          Text('当前歌词是手动搜索的结果')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .layoutWeight(1)
          Text('恢复自动')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.accentColor)
            .padding({ left: 8, right: 4, top: 4, bottom: 4 })
            .onClick((): void => {
              this.restoreAuto();
            })
        }
        .width('100%')
      }

      if (this.rows.length === 0) {
        Column({ space: 8 }) {
          if (this.searching) {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(this.accentColor)
            Text('正在逐个平台搜索…')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          } else if (this.searched) {
            Text('没搜到匹配的歌，换个关键词试试')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 6 }) {
          ForEach(this.rows, (row: LyricSearchRow) => {
            ListItem() {
              this.RowView(row)
            }
          }, (row: LyricSearchRow) => row.info.source + '|' + row.info.songId)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
