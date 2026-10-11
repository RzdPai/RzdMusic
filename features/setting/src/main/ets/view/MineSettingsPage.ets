/*
 * 「我的」→「设置」的二级页面（NavDestination）。
 *
 * 为什么要单开一页：用户要求「我的」页本身只留账号卡 + 入口区块，
 * **搜索框和原本的设置项都进二级页**。这一页就是那个二级页 ——
 * 顶部系统的 `Search`，下面按分组列出各设置入口，点进去是本工程既有的
 * `SettingsDetailPage`（音源管理 / 播放设置 / 下载设置 / 主题外观 / 其它 / 关于 /
 * 平台账号 / 平台音乐），**设置项本体一行都没有搬走**，所以和 `SettingPage` 那个
 * 页签里的设置项永远指向同一批详情页。
 *
 * 与 `SettingPage` 的关系：
 *   - `SettingPage` = 「设置」页签（宽屏时左栏列表 + 右栏详情）；
 *   - 本页 = 同一套入口的「二级页」形态，窄屏一列卡片，只负责往下推详情页。
 *   两份入口清单各自声明是**有意**的：合并要把 `SettingPage` 拆成壳 + 内容两半，
 *   那属于「重写设置页」，超出本轮范围；这里用同样的 `sheetIndex` 常量保证一致。
 *
 * ⚠️ 只用 V2 装饰器；路由只用 NavPathStack（`RouterUrlConstants` 里已有的常量）。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { guardPlayerBack } from 'musicbasic';
import {
  AmbientState, AppStorageKeys, BreakpointType, MusicStoreService, RouterUrlConstants,
  ThemeState, TitleBarConstants, buildTitleMaterial, getStatusBarTopVpFromWindowUtil
} from 'musicbasic';
import {
  BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions,
  ScrollEffectType, TitleSize
} from '@kit.UIDesignKit';
import { SettingsDetailRouteParam } from './SettingsDetailPage';

/** 设置入口的一行。 */
class MineSettingRow {
  /** 系统符号图标（与 `MinePage` 的快捷入口同一批语汇）。 */
  symbol: Resource = $r('sys.symbol.gearshape_fill');
  label: string = '';
  /** 对应的 `SettingsDetailPage` sheetIndex。 */
  index: number = 4;
  /** 搜索关键词（中文别名一并塞进来，保证搜索命中率）。 */
  searchText: string = '';
}

/** 分组的行高（与 `SettingPage` 的行高同一档，观感一致）。 */
const SETTING_ROW_HEIGHT: number = 60;
/** 卡片圆角。 */
const SETTING_CARD_RADIUS: number = 16;
/** 分组间距。 */
const SETTING_GROUP_GAP: number = 14;

/**
 * 「我的」→「设置」二级页。
 *
 * 不接收 `scrollTopCommand`：二级页没有「点当前页签回到顶部」这条交互（那是页签才有的）。
 */
@ComponentV2
export struct MineSettingsPage {
  /** Window breakpoint for the responsive horizontal padding. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  @Local searchKeyword: string = '';
  @Local pathStack: NavPathStack = new NavPathStack();
  private pageScroller: Scroller = new Scroller();
  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  aboutToAppear(): void {
    // 光感等级与 SettingPage 取同一份 store，标题栏材质才不会两边不一样
    this.ambientState.level = MusicStoreService.getInstance().getAmbientLevel();
  }

  /** 光感等级变化时丢弃标题栏缓存，让沉浸材质跟着设置实时变。 */
  @Monitor('ambientState.level')
  onAmbientLevelChanged(): void {
    this.cachedTitleBar = undefined;
  }

  /** 平台账号（华为账号 + 音乐平台账号）。 */
  private accountRows(): MineSettingRow[] {
    const row = new MineSettingRow();
    row.symbol = $r('sys.symbol.person_crop_circle_fill_1');
    row.label = '登录平台音乐';
    row.index = 2;
    row.searchText = '平台账号 登录 华为账号 网易云 QQ 酷狗 扫码 cookie login';
    return [row];
  }

  /** 平台音乐（各平台曲库）。 */
  private platformRows(): MineSettingRow[] {
    const row = new MineSettingRow();
    row.symbol = $r('sys.symbol.auditorium');
    row.label = '平台音乐';
    row.index = 3;
    row.searchText = '平台音乐 曲库 歌单 收藏 playlist';
    return [row];
  }

  /** 音源管理。 */
  private sourceRows(): MineSettingRow[] {
    const row = new MineSettingRow();
    row.symbol = $r('sys.symbol.dot_radiowaves_left_and_right');
    row.label = '音源管理';
    row.index = 5;
    row.searchText = '音源管理 音源设置 引擎 脚本 导入 lx api';
    return [row];
  }

  /** 播放 / 下载。 */
  private playbackRows(): MineSettingRow[] {
    const playback = new MineSettingRow();
    playback.symbol = $r('sys.symbol.speaker_wave_2_fill');
    playback.label = '播放设置';
    playback.index = 4;
    playback.searchText = '播放设置 音质 歌词 声音 播放';
    const download = new MineSettingRow();
    download.symbol = $r('sys.symbol.circle_and_arrow_down_fill');
    download.label = '下载设置';
    download.index = 6;
    download.searchText = '下载设置 下载 保存 命名 目录';
    return [playback, download];
  }

  /** 外观。 */
  private themeRows(): MineSettingRow[] {
    const row = new MineSettingRow();
    row.symbol = $r('sys.symbol.paintpalette_fill');
    row.label = '主题外观';
    row.index = 7;
    row.searchText = '主题外观 主题 颜色 日夜 深色 光感';
    return [row];
  }

  /** 其它 / 关于。 */
  private otherRows(): MineSettingRow[] {
    const other = new MineSettingRow();
    other.symbol = $r('sys.symbol.ellipsis_circle');
    other.label = '其它设置';
    other.index = 8;
    other.searchText = '其它设置 其他 歌单 首页 推荐 添加位置';
    const about = new MineSettingRow();
    about.symbol = $r('sys.symbol.info_circle_fill');
    about.label = '关于';
    about.index = 9;
    about.searchText = '关于 版本 捐赠 日志 群 应用信息';
    return [other, about];
  }

  /** 按搜索词过滤一组；空关键词返回原组。 */
  private filterRows(rows: MineSettingRow[]): MineSettingRow[] {
    const keyword: string = this.searchKeyword.trim().toLowerCase();
    if (keyword.length === 0) {
      return rows;
    }
    const result: MineSettingRow[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const text: string = (rows[i].label + ' ' + rows[i].searchText).toLowerCase();
      if (text.indexOf(keyword) >= 0) {
        result.push(rows[i]);
      }
    }
    return result;
  }

  /** 是否有任何设置项命中当前搜索词（用于「没有匹配」提示）。 */
  private hasAnyMatch(): boolean {
    return this.filterRows(this.accountRows()).length > 0 ||
      this.filterRows(this.platformRows()).length > 0 ||
      this.filterRows(this.sourceRows()).length > 0 ||
      this.filterRows(this.playbackRows()).length > 0 ||
      this.filterRows(this.themeRows()).length > 0 ||
      this.filterRows(this.otherRows()).length > 0;
  }

  /** 推进一个设置详情页（本工程既有路由，`sheetIndex` 决定渲染哪一块）。 */
  private openDetail(index: number): void {
    const param = new SettingsDetailRouteParam();
    param.index = index;
    this.pathStack.pushPathByName(RouterUrlConstants.SETTINGS_DETAIL, param);
  }

  /** 左右安全边距（按断点，与其它页面同一档）。 */
  private contentPaddingSide(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** HDS title bar：与 `SettingPage` 同一套（透明 + 沉浸材质 + 滚动渐变模糊）。 */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    if (this.cachedTitleBar !== undefined) {
      return this.cachedTitleBar;
    }
    this.cachedTitleBar = {
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: $r('app.string.setting_title'),
          mainTitleSize: TitleSize.TITLE_ML
        },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          action: (): void => {
            this.pathStack.pop();
          }
        }
      }
    };
    return this.cachedTitleBar;
  }

  /** 一组设置项 = 一张卡片（行间细分隔线）。 */
  @Builder
  private RowGroup(rows: MineSettingRow[]) {
    Column() {
      ForEach(rows, (row: MineSettingRow, index: number) => {
        Column() {
          if (index > 0) {
            Divider()
              .strokeWidth(0.6)
              .color($r('app.color.comp_divider'))
              .margin({ left: 50 })
          }
          Row() {
            Row() {
              SymbolGlyph(row.symbol)
                .fontSize(20)
                .fontColor([$r('sys.color.font_primary')])
            }
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor($r('sys.color.background_secondary'))
            .justifyContent(FlexAlign.Center)

            Text(row.label)
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .height(18)
              .fontColor([$r('sys.color.icon_tertiary')])
          }
          .width('100%')
          .height(SETTING_ROW_HEIGHT)
          .padding({ left: 14, right: 14 })
          .stateStyles({
            normal: { .backgroundColor(Color.Transparent) },
            pressed: { .backgroundColor($r('sys.color.background_secondary')) }
          })
          .onClick(() => {
            this.openDetail(row.index);
          })
        }
        .width('100%')
      }, (row: MineSettingRow) => 'mine_setting_' + row.index)
    }
    .width('100%')
    .borderRadius(SETTING_CARD_RADIUS)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }

  /** 只在有命中项时才画这一组（搜索过滤后的空组不占位）。 */
  @Builder
  private FilteredGroup(rows: MineSettingRow[]) {
    if (this.filterRows(rows).length > 0) {
      this.RowGroup(this.filterRows(rows))
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        Scroll(this.pageScroller) {
          Column({ space: SETTING_GROUP_GAP }) {
            // 顶部占位：第一张卡落在透明标题栏下方，但跟着内容一起滚走
            // （用容器内边距会把这一段裁在标题栏下缘，看着像「被顶栏挡住」）
            Row() {
            }
            .width('100%')
            .height(getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP + 6)

            Search({ value: this.searchKeyword, placeholder: $r('app.string.setting_search_placeholder') })
              .id('mine_setting_search_input')
              .width('100%')
              .height(44)
              .borderRadius(22)
              .backgroundColor($r('app.color.card_background'))
              .onChange((value: string) => {
                this.searchKeyword = value;
              })

            this.FilteredGroup(this.accountRows())
            this.FilteredGroup(this.platformRows())
            this.FilteredGroup(this.sourceRows())
            this.FilteredGroup(this.playbackRows())
            this.FilteredGroup(this.themeRows())
            this.FilteredGroup(this.otherRows())

            if (!this.hasAnyMatch()) {
              Text('没有匹配的设置项')
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_tertiary'))
                .width('100%')
                .padding({ top: 24, bottom: 24 })
                .textAlign(TextAlign.Center)
            }

            // 底部预留：一级页是「我的」（底部有 HDS 浮动页签栏），二级页要避开它 + 系统手势条
            Row() {
            }
            .width('100%')
            .height(56 + 16 + 16)
          }
          .width('100%')
          .padding({ left: this.contentPaddingSide(), right: this.contentPaddingSide() })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .onBackPressed((): boolean => guardPlayerBack('MineSettingsPage'))
    .hideTitleBar(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .bindToScrollable([this.pageScroller])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

/** 路由表里注册的 Builder（`features/setting` 的 router_map.json）。 */
@Builder
export function MineSettingsPageBuilder(name: string, param: Object) {
  MineSettingsPage()
}
