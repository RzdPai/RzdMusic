/*
 * 「匹配歌词」面板（本地歌的手动纠正）
 *
 * 对应 listen 的文件：entry/src/main/ets/views/LyricMatchSheet.ets
 *
 * 适配点：
 *  - ArkUI 状态管理 V1（@Component + @Prop/@State）-> V2（@ComponentV2 + @Param/@Local）。
 *  - 主题：listen 用自带的 ui/Theme 常量（C_RED / F_SUB…），RzdMusic 里没有这些文件，
 *    改用 musicbasic 的 ThemeState（AppStorageV2）取强调色 + $r('sys.*') 系统资源取字号颜色。
 *  - 数据类型：listen 的 LxMusicInfo -> MatchSongInfo（见 core/LyricMatch.ets）。
 *  - 面板仍是自绘的，不要改成 bindSheet：播放器本身就是系统半模态，再叠系统弹层容易打架
 *    （listen 的 PlayerView 开头有同样的说明）。
 *  - 「选中的那条要记住」原本由调用方（PlaySession.refreshLyric）做；这里由本组件直接调
 *    localMusic.saveMatch 落盘，再通过 onPick 通知播放链路重新取词。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageKeys, ThemeState } from 'musicbasic';
import { localMusic } from '../core/LocalMusic';
import {
  infoToJson,
  LyricCandidate,
  MATCH_PLATFORMS,
  MatchSongInfo,
  platformLabel,
  scoreCandidate,
  searchCandidates
} from '../core/LyricMatch';

const DOMAIN: number = 0x0001;
const TAG: string = 'LyricMatchSheet';

/** 一条搜索结果（带它来自哪个平台、以及有多像这首歌） */
interface Candidate {
  source: string;
  info: MatchSongInfo;
  score: number;
}

/**
 * 手动匹配面板
 *
 * 为什么必须有它：本地歌没有平台身份，只能拿歌名 + 歌手 + 时长去猜（见 core/LyricMatch）。
 * 猜这件事一定有猜错的时候 —— 同名歌、翻唱、纯音乐、Live 版都会踩到，而**配错的歌词比没有歌词
 * 更难解释**（用户看到的是理直气壮的错词）。所以自动匹配做成了宁缺勿错，配不准就不显示；
 * 用户觉得该有词的时候，就来这里搜一次、自己挑正确的那条。
 *
 * 搜索按 MATCH_PLATFORMS 逐个平台来，边搜边出结果（一个平台搜不到不影响别的）；
 * 结果按相似度排序，每行标出来自哪个平台。
 */
@ComponentV2
export struct LyricMatchSheet {
  /** 本地歌的 key（选中结果后落盘到它上面） */
  @Param songKey: string = '';
  /** 本地歌的歌名 / 歌手：关键词的初始值 */
  @Param songName: string = '';
  @Param singer: string = '';
  /** 本地歌的时长（毫秒，0 = 未知），用来给结果排序 */
  @Param durationMs: number = 0;
  @Param bottomInset: number = 0;
  /** 用户选中一条时通知播放链路重新取词（本组件已经落盘，这里只做刷新） */
  @Event onPick: (info: MatchSongInfo, source: string) => void = (): void => {
  };
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local keyword: string = '';
  @Local searching: boolean = false;
  /** 已经搜过一轮（用来区分「还没搜」和「搜了但没有」） */
  @Local searched: boolean = false;
  @Local candidates: Candidate[] = [];

  aboutToAppear(): void {
    this.keyword = this.singer.length > 0 ? `${this.songName} ${this.singer}` : this.songName;
    void this.search();
  }

  /** 逐个平台搜，边搜边把结果并进列表（搜不到的、接口不通的都跳过） */
  private async search(): Promise<void> {
    const keyword: string = this.keyword.trim();
    if (keyword.length === 0 || this.searching) {
      return;
    }
    this.searching = true;
    this.searched = true;
    this.candidates = [];
    try {
      for (const platform of MATCH_PLATFORMS) {
        let results: MatchSongInfo[] = [];
        try {
          results = await searchCandidates(keyword, platform);
        } catch (e) {
          hilog.info(DOMAIN, TAG, 'search on %{public}s failed: %{public}s',
            platform, (e as Error).message);
          continue;
        }
        const fresh: Candidate[] = [];
        for (const info of results) {
          const scored: LyricCandidate = scoreCandidate(info, this.songName, this.singer, this.durationMs);
          // 歌名完全不像的（归一化后毫无交集）不列出来，免得一屏全是无关的歌
          if (scored.score <= 0) {
            continue;
          }
          fresh.push({ source: platform, info: info, score: scored.score });
        }
        this.candidates = this.merge(this.candidates, fresh);
      }
    } finally {
      this.searching = false;
    }
  }

  /** 并入新结果：按相似度排序，同名同歌手的只留第一条 */
  private merge(current: Candidate[], fresh: Candidate[]): Candidate[] {
    const out: Candidate[] = current.slice();
    for (const item of fresh) {
      let exists: boolean = false;
      for (const one of out) {
        if (one.info.name === item.info.name && one.info.singer === item.info.singer) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        out.push(item);
      }
    }
    out.sort((a: Candidate, b: Candidate) => b.score - a.score);
    return out.slice(0, 40);
  }

  /** 选中一条：落盘（下次直接用它的歌词），再通知调用方刷新 */
  private pick(item: Candidate): void {
    applyPickedMatch(this.songKey, item.info, item.source);
    this.onPick(item.info, item.source);
  }

  build() {
    Column() {
      Text(`匹配歌词：${this.songName}`)
        .fontSize($r('sys.float.Subtitle_M'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Start)

      Text('本地歌没有平台身份，这里按歌名与歌手去平台上搜；选中的那条会记住，下次直接用它取词。')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .padding({ top: 4, bottom: 8 })
        .textAlign(TextAlign.Start)

      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '歌名 歌手' })
          .placeholderColor($r('sys.color.font_tertiary'))
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .height(44)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => {
            void this.search();
          })
        Button('搜索')
          .fontSize($r('sys.float.Body_S'))
          .height(44)
          .backgroundColor(this.themeState.color)
          .enabled(this.keyword.trim().length > 0 && !this.searching)
          .onClick(() => {
            void this.search();
          })
      }
      .width('100%')

      if (this.searching) {
        Text(this.candidates.length > 0 ? `正在搜索… 已有 ${this.candidates.length} 条` : '正在搜索…')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .padding({ top: 12 })
          .textAlign(TextAlign.Start)
      } else if (this.searched && this.candidates.length === 0) {
        Text('没有搜到相近的歌。换个关键词（比如只留歌名）再试一次。')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .padding({ top: 12 })
          .textAlign(TextAlign.Start)
      }

      List() {
        ForEach(this.candidates, (item: Candidate) => {
          ListItem() {
            Column({ space: 3 }) {
              Text(item.info.name)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Start)
              Row({ space: 8 }) {
                Text(item.info.singer)
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Start)
                if (item.info.interval.length > 0) {
                  Text(item.info.interval)
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor($r('sys.color.font_tertiary'))
                }
                Text(platformLabel(item.source))
                  .fontSize(11)
                  .fontColor($r('sys.color.font_secondary'))
                  .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                  .borderRadius($r('sys.float.corner_radius_level2'))
                  .backgroundColor($r('sys.color.background_tertiary'))
              }
              .width('100%')
            }
            .width('100%')
            .padding({ top: 9, bottom: 9 })
            .onClick(() => {
              this.pick(item);
            })
          }
        }, (item: Candidate) => `${item.source}_${item.info.songId}_${item.info.name}`)
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
      .margin({ top: 6 })
      .divider({ strokeWidth: 0.6, color: $r('sys.color.background_tertiary') })

      Column().height(this.bottomInset + 8).width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12 })
  }
}

/**
 * 记下用户手动选的那条匹配（落盘 + 版本号 +1，界面会重新读列表）
 *
 * 播放页的「匹配歌词」入口（**主 agent 接入点**）：在播放页对本地歌的「更多」菜单里加一项，
 * 打开本面板并传 songKey / songName / singer / durationMs，onPick 里调
 * `refreshLocalLyric()`（player 侧：清掉当前歌词文本后按新的 matchJson 取平台歌词）。
 * @param key 本地歌 key（空串时只回调不落盘）
 */
export function applyPickedMatch(key: string, info: MatchSongInfo, source: string): void {
  if (key.length === 0) {
    return;
  }
  const platform: string = source.length > 0 ? source : info.source;
  localMusic.saveMatch(key, platform, infoToJson(info));
}
