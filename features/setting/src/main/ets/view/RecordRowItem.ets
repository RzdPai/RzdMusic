import { PlayedSongRecord, SongTitleMarquee, NowPlayingIndicator } from 'musicbasic';
import { SongMoreMenu } from 'playlist';

/**
 * 历史 / 收藏列表的单行（V2 复用组件 `@ReusableV2`）。
 *
 * ★ 为什么单独抽出来（用户 2026-11-08：「进入历史页和收藏页很卡」）：
 *   原来是页面里的 `@Builder RecordRow()` —— `@Builder` 不能进入组件复用池，
 *   `LazyForEach` 滑出屏幕就销毁、滑回来重建整棵子树（每行含跑马灯、播放指示条、
 *   右侧歌曲菜单）。官方实测把这类行改成复用组件后
 *   `BuildLazyItem` 从 10.277ms 降到 0.749ms（丢帧率 3.7% → 0%）。
 *
 * ★★ 2026-11-10 修复「历史/收藏页只有数字、一行都没有」：
 *   上一版这里写的是 V1 的 `@Reusable + @Component`，而父页面 `RecordListPage` 是
 *   `@ComponentV2`（V2 普通组件）。官方《自定义组件混用场景指导》的矩阵里
 *   **「V2 普通组件 + V1 复用组件」= 编译期只告警、运行期不创建子组件（静默失效）**，
 *   所以 `LazyForEach` 明明拿到了 200 条数据，行组件却一个都没实例化 ⇒ 列表全空。
 *   现在整行改成 V2 体系：`@ReusableV2 + @ComponentV2 + @Param`，
 *   与内部的 `SongTitleMarquee / NowPlayingIndicator / SongMoreMenu`（都是 V2）同体系。
 *
 * ★ 为什么要这么多参数：复用组件必须把「行渲染用到的状态」全部显式传进来，
 *   不能像 `@Builder` 那样直接闭包页面字段 —— 否则复用池里的旧行会保留上一首歌的状态。
 *   父组件已经算好 `selected / current / 文案`，这里只负责画，避免每行再做一遍查表。
 *   `@Param` 是**引用传递**（不像 V1 `@Prop` 会深拷贝 `PlayedSongRecord`），200 行少 200 次拷贝。
 */

const R_COVER: number = 14;
const F_ITEM: number = 16.5;
const F_SUB: number = 12.5;
const LIST_ROW_HEIGHT: number = 70;
const ROW_COVER: number = 46;

@ReusableV2
@ComponentV2
export struct RecordRowItem {
  /** 行数据。 */
  @Param record: PlayedSongRecord = new PlayedSongRecord();
  /** 行下标（>0 时画顶部分割线）。 */
  @Param rowIndex: number = 0;
  /** 是否处于多选模式。 */
  @Param selectionMode: boolean = false;
  /** 是否被勾选（父组件算好）。 */
  @Param selected: boolean = false;
  /** 是否是当前播放的那首歌（决定歌名用主题色 + 是否显示竖条）。 */
  @Param isCurrent: boolean = false;
  /** 播放器是否在播（竖条动画）。 */
  @Param playing: boolean = false;
  /** 用户主题色（歌名高亮 / 勾选框）。 */
  @Param accent: string = '';
  /** 音质文案（父组件已做兜底，如「—」）。 */
  @Param qualityText: string = '';
  /** 平台标签文案（如「酷我」）。 */
  @Param platformText: string = '';
  /** 平台品牌色（数据，不是配色）。 */
  @Param platformTint: string = '#888888';
  /** 点整行。 */
  @Param onTapRow: (record: PlayedSongRecord) => void = (record: PlayedSongRecord): void => {};
  /** 勾选框变化。 */
  @Param onToggleRow: (record: PlayedSongRecord, on: boolean) => void =
    (record: PlayedSongRecord, on: boolean): void => {};
  /** 行内菜单换源后要求父组件重建列表。 */
  @Param onSongSwitched: () => void = (): void => {};

  build() {
    Column() {
      if (this.rowIndex > 0) {
        Divider()
          .strokeWidth(0.6)
          .color($r('app.color.comp_divider'))
          .margin({ left: 72 })
      }
      Row({ space: 12 }) {
        if (this.selectionMode) {
          Toggle({ type: ToggleType.Checkbox, isOn: this.selected })
            .width(24)
            .height(24)
            .selectedColor(this.accent)
            .onChange((isOn: boolean) => {
              this.onToggleRow(this.record, isOn);
            })
        }
        if ((this.record.img ?? '').length > 0) {
          Image(this.record.img)
            .width(ROW_COVER)
            .height(ROW_COVER)
            .borderRadius(R_COVER)
            .objectFit(ImageFit.Cover)
        } else {
          Row() {
            SymbolGlyph($r('sys.symbol.music_note_list'))
              .fontSize(16)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width(ROW_COVER)
          .height(ROW_COVER)
          .borderRadius(R_COVER)
          .backgroundColor($r('sys.color.background_tertiary'))
          .justifyContent(FlexAlign.Center)
        }
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            SongTitleMarquee({
              text: this.record.name,
              titleFontSize: F_ITEM,
              titleFontColor: this.isCurrent ? this.accent : $r('sys.color.font_primary'),
              titleFontWeight: FontWeight.Normal,
              hugContent: true
            })
            if (this.isCurrent) {
              NowPlayingIndicator({
                playing: this.playing,
                color: this.accent
              })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text(((this.record.singer ?? '').length > 0 ? this.record.singer : ''))
            .fontSize(F_SUB)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (!this.selectionMode) {
          Column({ space: 4 }) {
            Text(this.qualityText)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
            Text(this.platformText)
              .fontSize($r('sys.float.Caption_S'))
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius($r('sys.float.corner_radius_level2'))
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor(this.platformTint)
          }
          .alignItems(HorizontalAlign.Center)
          SongMoreMenu({
            song: {
              songId: this.record.songId, name: this.record.name, singer: this.record.singer,
              albumName: this.record.albumName, albumId: this.record.albumId, source: this.record.source,
              interval: this.record.interval, img: this.record.img, types: []
            },
            iconSize: 18,
            // 换源后立刻重建列表，保证平台标签/封面实时更新
            onSongSwitched: (): void => {
              this.onSongSwitched();
            }
          })
        }
      }
      .width('100%')
      .height(LIST_ROW_HEIGHT)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        if (this.selectionMode) {
          this.onToggleRow(this.record, !this.selected);
          return;
        }
        this.onTapRow(this.record);
      })
    }
    .width('100%')
    // 行底**透明**（= 页面底色）：参考工程的历史列表就是普通 List，不是卡片
    .backgroundColor(Color.Transparent)
  }
}
