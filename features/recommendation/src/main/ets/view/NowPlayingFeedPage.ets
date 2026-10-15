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

/**
 * 底栏页签「**现在就听**」：一屏一首歌、上下滑换歌，**可以无限刷**。
 *
 * ## 一、这一页做什么
 *
 *   · 滑动机制 = **竖向 `Swiper`**（`.vertical(true)`）：它天生就是"整页吸附 +
 *     前后各缓存一屏"的语义，比拿 `List`/`Scroll` 拼吸附可靠（见 {@link build} 注释）。
 *   · 推荐来源两条通道**都是首页现成的**（见 {@link loadChart} / {@link loadDaily}）：
 *     未登录 → 当前平台的新歌榜（`pickFeatureBoardId('newSongs', svcSource)` → `lxLeaderboard`）；
 *     已登录 → 该平台账号的每日推荐（`AccountService.getDailyTrackIds/getTrackDetails`）。
 *   · **播放入口只有两条，都是工程现成的**（用户 2026-10-15："打开这个页面自动播放当前歌曲，
 *     滑到哪首歌就播放哪一首"，而且**这一页不会打开播放器**）：
 *     ① 队列还不是屏幕上这一份 ⇒ `OnlinePlayUtil.playList(appState, 整份队列, 下标, uiContext, false)`
 *        （第 5 参 `openPlayer=false` ⇒ `playList` **不请求**全屏播放页）；
 *     ② 队列就是这一份、只需换当前曲 ⇒ 写 `PlaybackIntentState`（`openPlayerUi=false`），
 *        由壳层 `dispatchShellPlaybackIntent()` 去 `MediaService.loadAsset()`。
 *     两条都不 push 路由、不另起播控状态（全局播控唯一真源仍是 `MusicAppState`）。
 *     详见 {@link playAt} 的 §2 —— **别改成"调完 `playList` 再回滚 `isShowPlay`"**（理由写在那里）。
 *
 * ## 二、无限刷（**页码/游标怎么走、依据是什么**，全部读实现得来，不猜）
 *
 * 详见 {@link loadMore} 的长注释。一句话版：
 *   · **榜单（未登录）**：`lxLeaderboard(boardId, page, limit)` 里**只有 kg 真用了 `page`**，
 *     另外四个平台的实现把 page 丢掉 ⇒ kg 走"页码递增 + 固定页大小"，
 *     其余平台走"**窗口随页数变大 + 去重切前缀**"（不伪造任何一首歌）；
 *     {@link FEED_MAX_PAGES} / {@link FEED_EMPTY_STREAK} 两道收尾保护兜住"不许死循环打接口"。
 *   · **每日推荐（已登录）**：provider 侧**没有任何分页/游标**（一次给全）⇒
 *     按任务口径"**到末尾后回到开头循环**"，实现 = `Swiper.loop(true)`，不重复插入、key 不变。
 *   · **触发时机**：滑到**倒数第 {@link FEED_PREFETCH_REMAIN} 首**时在 `onChange` 里预取
 *     （见 {@link onFeedChanged}），另有 `feedFetching` 并发闸。
 *   · **到底不出现空白**：`loop` 打开后永远滑得到下一屏；`loop` 没开时也只会停在最后一屏
 *     （`edgeEffect(EdgeEffect.Spring)` 回弹），**不会出现空屏**。
 *
 * ## 三、界面（照用户给的参考图：华为音乐全屏播放页）
 *
 * 自上而下：顶栏（**左三条横线 / 右分享**，都无底色、无标题文字）→
 * **封面区（满屏贴边、不圆角，上下都化进页底色）** →
 * **小歌词两行（当前行 + 下一行，在歌名上方）** → 左对齐歌名 + 歌手/平台胶囊 →
 * 一行音质标签（描边胶囊）→ 动作行（红心+数字 / 不感兴趣 / 更多 ←→ **播放页同款的主播放/暂停键**）→
 * 一行进度（左当前时间 / 中间细条 / 右总时长，**明显在底栏之上**）。
 * 底部那条浮动胶囊底栏**是壳层的**，本页只让位（`bottomReserveVp + FEED_BOTTOM_GAP_VP`）。
 *
 * ★ **左右边距分两档**（照参考图量的，别混）：
 *   · **封面 = 0**（满屏贴边，用户明确"封面要铺满"）；
 *   · 它下面的每一行（歌词 / 歌名 / 歌手 / 音质 / 动作 / 进度）左右各留
 *     {@link FEED_SIDE_PADDING_VP}（20vp）。
 *   ⚠️ 这些边距只能挂在**那些行自己**身上，**不能挂回卡片根节点** ——
 *     挂在根节点上封面会被一起缩进（改动前就是这么错的，用户实测"封面离左右还有距离"）。
 *
 * ★ **整页分三层**（`build()` 里那个 `Stack`，自下而上）：
 *   ① **取色底** `pageTint` —— 当前这屏封面的主色经 `dealColor` 压暗（照歌手页那一套，见
 *      {@link extractCardColor}）；取色完成前是 `FEED_BASE_NEUTRAL`（由已有 token 算出的中性深色）；
 *   ② 顶部一段渐隐压深（把顶栏那两个白图标衬托出来，**高度只到封面顶边为止**，
 *      见 {@link topScrimHeightVp}）；
 *   ③ 内容（竖向 `Swiper`；封面在卡片里，**自带上、下两条 `pageTint` 渐变化进背景**，
 *      见 {@link FeedCover}）。
 *
 * ★★ **改动前那两层已经删掉，别再加回来**（用户 2026-10-15 二审："背景怎么还是模糊，
 *   我不是说了，封面铺满，然后背景根据封面动态取色，并且封面上下渐变到背景"）：
 *   · ❌ **整屏模糊封面**（`Image(...).blur(11vp).opacity(0.55)`）—— 用户明确不要模糊背景；
 *     背景现在就是 ① 那一层**纯取色底**；
 *   · ❌ **整屏 `[Transparent, 0] → [pageTint, coverGradientStop()]` 过渡层** ——
 *     "图片化进背景"这件事改由**封面自己那两条渐变**负责（相对封面高，比例色标），
 *     整屏那条不但多余，还会把封面整块染色（它的色标是按"封面顶边/下沿的估算位置"算的，
 *     而封面实际落点取决于字体行高 ⇒ 必然偏）⇒ 连同只给它用的 `coverGradientStop()` 一起删了。
 *
 * ★★ **配色一律走 token、不写死 hex**，而且这里用的是**播放页那一族"压在图上"的 token**
 *   （`app.color.player_text_primary` / `play_text_color` / `play_singer_color` /
 *    `slider_track` / `slider_select` / `info_scrim_*`）—— 它们在 `resources/base` 里有值、
 *    `resources/dark` 里**没有覆盖**，即"两个主题同值"。
 *    这正是官方/本工程对"压在照片/大图上的蒙层 + 它的文字必须成对且两主题同值"那条口径的做法
 *    （照片内容不可控，跟着主题翻就会出现"深字压深蒙层"不可读）。跨 HAR 引用 `app.color.*` 有先例：
 *    `features/recommendation/.../WearableHome.ets:42` 就在用 player 的 `app.color.font_color`。
 *    ⚠️ 两个**取色底 / 压深色**是把 token 的 RGB 过 `resourceManager.getColorSync` 读出来拼的
 *      （颜色只能是 string），拼法与理由写在 `feedTokenRgb` / `FEED_BASE_NEUTRAL` / `FEED_SCRIM_TOP`
 *      头上 —— 仍然"只有 token、没有新 hex"。
 *
 * ## 四、几条"别再踩"的硬约束（写在这里免得下一轮又撞上）
 *
 * 1. **`buildTitleMaterial` 从 `musicbasic` 导**（`common/musicbasic/src/main/ets/util/TitleMaterial.ets:23`），
 *    **不是** `@kit.UIDesignKit` 的导出成员 —— 写成后者直接编译不过。
 * 2. **`pickFeatureBoardId` 是 `RecommendDataUtil.ets` 里导出的【函数】**，直接 import 调用；
 *    它不是 `RecommendDataUtil` 的静态方法（挂上去会报 `Property does not exist on type`）。
 * 3. **页根/HDS 标题栏/让位**：`HdsNavDestination` + `titleMode(MINI)` + 空标题 +
 *    `ignoreLayoutSafeArea([SYSTEM], [TOP, BOTTOM])`；HDS 的 `titleBar.style.avoidLayoutSafeArea`
 *    **恒为 `true`**（真机定论，见 `PageTopInsetHelper` 注释）。
 *    ⚠️ 顶栏是"左 `backIcon` + 右 `menu`、`mainTitle: ''`"，且 `hideBackButton(false)`
 *    （HDS 文档原文：**true 才隐藏返回键**，默认 false；要用自定义图标就必须让它显示，
 *    官方 `HdsNavDestination` 示例里就是 `.titleBar({...}).hideBackButton(false)` 的写法）。
 * 4. **没有 `bindToScrollable`**：那个接口只收 `Array<Scroller>`
 *    （`component/nav_destination.d.ts:1213`），本页的控制器是 `SwiperController`，类型对不上 ⇒
 *    本页顶栏**没有**"滑过才渐变模糊"，只有 `systemMaterialEffect`。别硬塞。
 * 5. **`@Param` 的默认值不能引用私有成员**：所以主题色 token 写成模块级常量。
 * 6. **歌词 = 播放页现成的 `MiniLyricLinesComponent`**（当前行 + **下一行**，在歌名上方）。
 *    它**已经**由 `features/player/Index.ets` 导出（本轮加的那一行），本页直接
 *    `MiniLyricLinesComponent({ ignoreUserSetting: true })`。
 *    ⚠️ 它是"自取数"组件（自己连 `MusicAppState` + 按 `progress` 从当前曲的 `lyricText` 算行），
 *      **取词/解析/行号逻辑一字未改**；本轮只给它加了一个**opt-in 显示开关**
 *      `@Param ignoreUserSetting: boolean = false`（`MiniLyricLinesComponent.ets:27`），
 *      渲染门变成 `if (this.miniLyricState.enabled || this.ignoreUserSetting)`：
 *      **默认 false ⇒ 播放页逐字保持原行为**（仍由「设置 → 小歌词」控制），
 *      只有本页传 `true`（这一页自己就是"现在在听什么"的全屏呈现，两行歌词是它的正文之一）。
 *      ⚠️ 早先那版"本页去强开 `ShowMiniLyricState.enabled`"的做法是错的：那会**连带改掉播放页**的观感。
 *    ⚠️ 本页自己那条"当前行 + 上一行"的观察链（`lyricCurrent` / `lyricPrevious` /
 *      `@Monitor('appState.progress')`）**保留但已不用于显示**（也不删）：万一下一轮要回退组件、
 *      或者要拿它做别的（如歌词按钮），数据还在；它读的是
 *      `MusicStoreService.getCardLyric()`（播放链路 `MediaService.syncCardLyric()` 写进去的真源）。
 * 7. **全屏播放页在这条路上只有一个开关**：`OnlinePlayUtil.playList` 的第 5 参 `openPlayer`
 *    （默认 `true` = 原行为）与 `PlaybackIntentState.openPlayerUi`。本页两处都传/写 `false`，
 *    **不要**改用"事后把 `appState.isShowPlay` 掰回去"（那是"请求过又撤销"，
 *    壳层的 `@Monitor('appState.isShowPlay')` 会读到瞬时 true，见 {@link playAt} §2）。
 *
 * 诊断关键字：`grep RzdNowPlaying`（hilog 标签；load / page request / page result /
 * exhausted / dislike / favorite / **play toggle / play / play switch / play skip** / **tint** 各有独立字样，
 * 判读表见任务报告）。壳层那半条用 `grep PlaybackIntent` / `RzdPlayerRoute`。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import {
  AmbientState,
  AppStorageKeys,
  buildTitleMaterial,
  ColorConversion,
  HomeSourceState,
  Logger,
  MusicAppState,
  MusicStoreService,
  PageTopInsetHelper,
  PlayedSongRecord,
  PlaybackIntentState,
  SongItem,
  StyleConstants,
  WindowInfo,
  getWindowInfoState
} from 'musicbasic';
import {
  BlurStrategy,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  TitleSize
} from '@kit.UIDesignKit';
import {
  AccountChangedState,
  AccountService,
  buildSongShareText,
  lxGetQualityOptions,
  lxLeaderboard,
  LXQualityOption,
  MiniLyricLinesComponent,
  OnlinePlayUtil,
  PlatformAccount,
  PlatformTrackInfo,
  PlayerConstants,
  PlayerViewModel,
  showSystemShare
} from 'player';
import type { LXSearchSong, LXSearchResult } from 'player';
import { SongMoreMenu } from 'playlist';
import { RecommendPrivateSongUi } from '../model/RecommendUiModels';
import { pickFeatureBoardId } from '../util/RecommendDataUtil';

/** hilog 标签：`hdc shell hilog | grep RzdNowPlaying` 可捞本页整条链路。 */
const RZD_TAG: string = 'RzdNowPlaying';

/**
 * 未登录通道的**单页条数**（第 1 页就是它 —— 与上一版口径一致，首页那两张卡的行为不受影响）。
 */
const FEED_BOARD_LIMIT: number = 20;

/**
 * 非 kg 平台"窗口开大"时的**上界**（首）。
 *
 * 那四个平台的实现忽略 `page`（见 {@link loadMore}），只能把 `limit` 开大再切前缀；
 * 再大也只是把同一批歌反复取回来（还白等网络）⇒ 到顶之后新歌自然为 0，收尾保护接手。
 */
const FEED_BOARD_WINDOW_MAX: number = 100;

/** **收尾保护①**：页码硬上界。 */
const FEED_MAX_PAGES: number = 8;

/**
 * **收尾保护②**：连续这么多次"0 首新歌 / 请求失败"就停手。
 *
 * 必须 ≥ 2：非 kg 平台在窗口开大后**第一次**可能整批都是已见过的
 * （正好卡在窗口边界上），一次就判死会把还能翻的通道误杀。
 */
const FEED_EMPTY_STREAK: number = 2;

/** 滑到"**剩余几首**"时预取下一页（见 {@link onFeedChanged}）。 */
const FEED_PREFETCH_REMAIN: number = 3;

/**
 * 一屏卡片给底部让出的默认值（vp）。
 *
 * ⚠️ 真正的值由**壳层**按 `distributionOSApiVersion` 传进来（HDS 浮动胶囊底栏
 * 在 60100 起才存在：`56 + 16`，否则 `56`）—— 与壳层里 `shellProvidesFloatingMiniBar`
 * 那一句同源。留在这里的只是"组件被单独使用时"的兜底。
 *
 * ⚠️ 它必须加在**滑动卡片自己**的 `padding.bottom` 上，**不能**加在外层容器：
 * 加在外层会让整页少一块，滑动的每一屏都对不齐底栏。
 */
const FEED_DEFAULT_BOTTOM_RESERVE_VP: number = 56;

/**
 * 底栏让位之上**再让出的一段可见间距**（vp）—— 让"进度条整体明显在底栏之上"。
 *
 * 这一档就是 ① 要求的"进度条与底栏之间留出可见间距"，写法是**加号而不是新写一个魔法数**：
 *   `卡片 padding.bottom = bottomReserveVp（底栏让位，唯一来源） + FEED_BOTTOM_GAP_VP（间距）`
 * （见 {@link FeedCard} 的 `padding` 与 {@link cardChromeBottomVp}）。
 * ⚠️ 两处**必须同时**用 {0} + FEED_BOTTOM_GAP_VP，**不能**在别处再叠一次 —— 叠两次就是
 *   "封面变小 + 进度条上移两档"，与首页那类"同一个量算两遍"的旧账同族。
 * 12 的来历：官方那版进度条下沿到底栏胶囊上沿大约半个底栏高度（56/2 = 28），
 * 其中一半由底栏自己的 `barBottomMargin` 提供、另一半由这里补，取整 12vp。
 */
const FEED_BOTTOM_GAP_VP: number = 12;

/**
 * 封面区高度相对**窗口高**的比例。
 *
 * 封面高度 = `clamp(min(窗口高 × 本值, 内容盒高 − {@link FEED_CHROME_VP}, 窗口宽),
 *               {@link FEED_COVER_MIN_VP}, 窗口宽)`（见 {@link coverHeightVp}）。
 *
 * **0.40 是量参考图得来的**（用户给的那张官方全屏播放页，按 原图像素 ÷ 3.0 ≈ vp 换算）：
 * 封面几何落点 ≈ 0.145×屏高 → 0.53×屏高（高 ≈ 0.39H），可见纹理从 0.20H 之后才开始淡出
 * —— 所以取 0.40（比改动前那套实际给出的 320vp 上限更贴近参考图，也仍然是"略降"）。
 * ⚠️ 封面**宽度恒 = 窗口宽**（满屏贴边），所以宽屏（平板）会先被"窗口宽"这一项夹住。
 * ⚠️ 改动前这里还挂着一个固定的高度上限 `FEED_COVER_MAX_VP = 320`，**已删**：
 *   在"比例 = 屏高 × 0.40"这条口径下，320 会**先于比例生效**（816 屏上 320 < 326、
 *   925 屏上 320 ≪ 370）⇒ 等于把"0.40 × 屏高"直接作废。宽/矮窗口的保护交给
 *   "窗口宽"与"内容盒高 − FEED_CHROME_VP"这两项，够用。
 */
const FEED_COVER_RATIO: number = 0.40;

/** 封面区高度下限（vp）：极矮窗口（平板横屏 / 折叠展开）宁可让内容挤一点，也不要压成一条。 */
const FEED_COVER_MIN_VP: number = 160;

/**
 * 封面圆角（vp）——**本轮已不使用，保留给"如果要给封面加圆角"的场景**。
 *
 * ⚠️ 为什么现在不圆角：官方那张图里的照片是**通栏铺满、不圆角**的
 *   （圆角只出现在"居中方形小卡"那种形态上），本页封面改成"按窗口宽铺满"之后
 *   再圆角就会在四角露出底色、把"图片化进背景"这件事做坏。
 *   所以 `FeedCover` 里**没有** `.borderRadius()`；要加回来必须同时想清楚四角怎么处理。
 */
const FEED_COVER_RADIUS_VP: number = 24;

/**
 * 封面**上**边那条"化进页底色"的渐变带宽（占**封面高**的比例）。
 *
 * `[pageTint, 0] → [Color.Transparent, 1]` 只画在封面高 `本值` 那一段里：
 * 封面顶边那一行**就是**页底色（与背后的取色底无缝接上），往下 20% 之内回到原图。
 * ⚠️ 它是**比例而不是 vp**（`linearGradient` 的色标口径，见 {@link FeedCover}）。
 * 20% 取自用户要求（"约封面高的 18~22% 内化开"）。
 */
const FEED_COVER_TOP_FADE: number = 0.20;

/**
 * 封面**下**边那条渐变带宽（占**封面高**的比例，从封面下沿**往上**算）。
 *
 * `[Color.Transparent, 0] → [pageTint, 1]` 画在封面高 `本值` 那一段里（贴在封面下沿）：
 * 封面下沿那一行**就是**页底色，往上 28% 之内回到原图。
 * ⚠️ 同样是**比例**。28% 取自用户要求（"约封面下沿往上 25~30% 内化开"）。
 */
const FEED_COVER_BOTTOM_FADE: number = 0.28;

/**
 * 封面以下**每一行**（歌词 / 歌名 / 歌手 / 音质 / 动作 / 进度）的左右内边距（vp）。
 *
 * ★ **封面自己不吃这个边距**（它是满屏贴边的 0 边距，用户明确要"铺满"），
 *   所以这个 padding 只能挂在那些行身上，**不能挂回卡片根节点** ——
 *   改动前挂在根节点上（`padding({left:24,right:24})`），封面就被一起缩进了 24vp，
 *   用户实测"封面离左右还有距离"。
 * ★ 20 是量参考图得来的（原图像素 ÷ 3.0 ≈ vp）：
 *   歌词行文字左沿 ≈ 20.7vp、歌名 ≈ 19.7vp、歌手行 ≈ 19.0vp、进度行 ≈ 19.3vp，
 *   最右那颗播放键的右沿距屏右 ≈ 19.7vp。取整 20。
 */
const FEED_SIDE_PADDING_VP: number = 20;

/**
 * 「除封面以外那一堆 + 呼吸留白」的合计占位（vp）—— 内容盒高减掉它之后才轮到封面
 * （见 {@link coverHeightVp}），同时也是 {@link coverTopVp} 里"居中之后封面落在哪"的预算。
 *
 * **为什么是 280**：要让 `justifyContent(FlexAlign.Center)` 居中之后，封面顶边正好落在
 * "标题栏下沿 + 0.02 × 屏高"（参考图上封面开始的位置）：
 *   · 内容盒高 = 屏高 − 顶部让位 − {@link cardChromeBottomVp}（360×816 上 = 816 − 94 − 84 = 638）；
 *   · 封面 = 0.40 × 816 = 326；
 *   · 预算 = 638 − 326 − 2 × (0.02 × 816 ≈ 16) ≈ 280。
 * **这 280 里有什么**：歌词两行 ≈ 24 + 歌名块 ≈ 57（歌名行 ≈ 32 + 间距 6 + 歌手行 ≈ 19）
 *   + 音质行 22 + 动作行 72 + 4 处 `Column({space:14})` = 56，合计 ≈ 231；
 *   余下的 ≈ 49 是**呼吸位**，留给"歌词组件按需渲染 / 字体行高在不同设备上的差异"。
 * ⚠️ 宁可封面矮一点（矮窗口上它被"内容盒高 − 本值"这一项夹住），也不要把动作行顶出屏幕 ——
 *   这是本页最容易出问题的一处（写死尺寸在平板横屏会把动作行顶出去）。
 * ⚠️ **不含歌词的真实高度**：`MiniLyricLinesComponent` 自己决定画不画、多高（见 {@link FeedLyric}）。
 */
const FEED_CHROME_VP: number = 280;

/** 音质标签在一张表值里的分隔符（`Map<string, string>` 存多枚标签，`Map` 不能直接存数组比较省事）。 */
const FEED_QUALITY_SEP: string = '|';

/**
 * 动作行高度（vp）。
 *
 * 由播放页同款的那颗主键决定：`app.float.image_play_width` = **72vp**（`float.json:96`），
 * 比改动前那颗 56vp 的白圆大一圈，所以这一行也得跟着长高 —— 否则它会撑破行高、
 * 与上面的音质标签挤在一起。
 */
const FEED_ACTIONS_ROW_VP: number = 72;

/** 主播放/暂停键边长 —— **同一个 token**（`app.float.image_play_width`，72vp），
 * 不再手写 56/72 这种数字；播放页主控区那颗用的就是它。 */
const FEED_PLAY_BUTTON_SIZE: Resource = $r('app.float.image_play_width');

/**
 * 主播放/暂停键的不透明度 —— 与播放页 `controlImageBuilder()` 的 `opacity(0.86)` 同值
 * （`ControlAreaComponent.ets:986`）：那颗按钮"看着是纯白圆"，实际是 86% 白，
 * 压在封面大图上才不会死白。**照抄这个数**，别自己调。
 */
const FEED_PLAY_BUTTON_OPACITY: number = 0.86;

/** 一屏最多画几枚音质胶囊（参考图是三枚，多了这行会溢出）。 */
const FEED_QUALITY_PILL_MAX: number = 3;

/**
 * 主题色 token（**压在封面大图上、且成对使用的那一族**，base/dark 同值，见文件头 §三）。
 *
 * ⚠️ 写成**模块级常量**而不是 `@Param` 默认值：`@Param` 的默认值表达式不能引用
 *  `this` 的私有方法，写成成员方法调用会编译不过。
 */
const FEED_TITLE_COLOR: Resource = $r('app.color.player_text_primary');
const FEED_SINGER_COLOR: Resource = $r('app.color.play_text_color');
const FEED_SOFT_COLOR: Resource = $r('app.color.play_singer_color');
const FEED_PAGE_BG: Resource = $r('app.color.page_background');
const FEED_PILL_BG: Resource = $r('app.color.slider_track');
const FEED_FAVORITE: Resource = $r('app.color.playlist_play_all_icon');
const FEED_TRACK: Resource = $r('app.color.slider_track');
const FEED_TRACK_PLAYED: Resource = $r('app.color.slider_select');
/** 整页深色底 token（`app.color.info_scrim_bottom` = `#E61C1C1E`）。
 *
 * ⚠️ 改动前它还兼任"白圆播放键上的图标色"，那颗键本轮改成**播放页同款的 `Image`**，
 *   自带白色圆底 ⇒ 那个用途没了。现在它只在两处被用到：
 *   ① 作为 {@link FEED_DARK_SURFACE_ARGB} 的**来源说明**（数字常量就是它的值）；
 *   ② 顶栏那两个槽位的透明背板用的是同族 α=0 档（{@link FEED_TRANSPARENT}）。
 *   ⚠️ 它**不再**直接喂给任何组件属性（整页底色改成取色 `pageTint`、兜底是 `FEED_BASE_NEUTRAL`）——
 *   保留常量是为了"值只有一个来源"这件事在代码里可见，别当它是漏用的死代码删掉。
 */
const FEED_DARK_SURFACE: Resource = $r('app.color.info_scrim_bottom');
/** 全透明档：同一枚 `1C1C1E` 的 α=0 值（`info_scrim_top`），用于"要透明背板"的地方。 */
const FEED_TRANSPARENT: Resource = $r('app.color.info_scrim_top');

/**
 * 取色完成**之前**的中性兜底底色（不透明 `rgb()` 字符串）。
 *
 * 底就是 {@link FEED_DARK_SURFACE} 这枚**已有 token**（`app.color.info_scrim_bottom`，
 * 本机 `features/player/src/main/resources/base/element/color.json` 里是 `#E61C1C1E`，
 * 而且**没有 dark 覆盖文件** ⇒ 两个主题同值、α 也恒定）。
 * 它的 RGB（`1C1C1E` = 28/28/30）本身就是"中性深色"，起点已经落在
 * {@link ColorConversion.dealColor} 的取值域里 —— 所以**不用任何新 hex**，
 * 把 token 的 ARGB 写成数字常量再拆通道即可。
 *
 * ⚠️ **不走 `resourceManager.getColorSync`**：那个接口在 Kit 导出的 `resourceManager`
 *   命名空间上**没有**（`.d.ts` 里是 `resourceManager.ResourceManager` 这个**类**的实例方法，
 *   名字空间是 `export default` 的模块对象）⇒ 直接调会报
 *   `Property 'getColorSync' does not exist on typeof resourceManager`，本机已实测。
 *   要用得先在运行时 `getUIContext().getHostContext().resourceManager` 拿实例，
 *   而模块级常量求值时还拿不到它。这里改成"把 token 值写成常量 + 注释锁死来源"。
 */
const FEED_DARK_SURFACE_ARGB: number = 0xE61C1C1E;

/**
 * 读不到资源时的最后兜底色 —— 与播放页 `PlaybackPage.defaultImageBgColor`
 * （`rgba(32, 32, 32, 1)`）**逐字同值**，两个页面的兜底观感一致。
 */
const FEED_NEUTRAL_HEX: number = 0x202020;

/**
 * 整页底色：取色完成前的中性兜底（见上方注释）。
 * 取色完成后由 `@Local pageTint` 覆盖成封面主色。
 */
const FEED_BASE_NEUTRAL: string = ((): string => {
  const tuned: number[] = ColorConversion.dealColor(
    (FEED_DARK_SURFACE_ARGB >>> 16) & 0xFF, (FEED_DARK_SURFACE_ARGB >>> 8) & 0xFF, FEED_DARK_SURFACE_ARGB & 0xFF);
  return `rgb(${tuned[0]}, ${tuned[1]}, ${tuned[2]})`;
})();

/**
 * 顶部压深层的 α（0.35）。
 *
 * ⚠️ 改动前是 0.55 —— 那时它压在一张**整屏模糊封面**上；那张模糊层已按用户要求删掉
 *   （背景现在只是 ① 那一层**纯取色底**），压深不再需要那么重 ⇒ 调弱到 0.35，
 *   只负责把顶栏那两个白图标从浅色封面里托出来。
 */
const FEED_SCRIM_ALPHA: number = 0.35;

/**
 * 顶栏那一段压深用的颜色（`rgba(28, 28, 30, 0.35)`）。
 *
 * 与 {@link FEED_TRANSPARENT}（同一枚颜色的 α=0 档）配成一对做 `linearGradient`：
 * **不改 hex、只改 α** —— 底仍然是 {@link FEED_DARK_SURFACE} 那枚 token 的 RGB。
 * 为什么不能沿用改动前那层"整屏 `[透明, 0] → [深色, 1]`"：它会把整页压成深色、
 * 把背景取色整块盖掉（取色就白做了）⇒ 现在只压最上面那一段（高度见 {@link topScrimHeightVp}）。
 */
const FEED_SCRIM_TOP: string = ((): string => {
  const r: number = (FEED_DARK_SURFACE_ARGB >>> 16) & 0xFF;
  const g: number = (FEED_DARK_SURFACE_ARGB >>> 8) & 0xFF;
  const b: number = FEED_DARK_SURFACE_ARGB & 0xFF;
  return `rgba(${r}, ${g}, ${b}, ${FEED_SCRIM_ALPHA})`;
})();

/**
 * 顶部压深层的**最小**高度（vp）—— 真实高度由 {@link topScrimHeightVp} 按窗口算：
 * `max(本值, coverTopVp())`，也就是"一直压到封面顶边为止"。
 *
 * ★ 为什么压到封面顶边就够：这一层的 α 是"从上往下 0.35 → 0"，而**封面顶边那一行本身就是页底色**
 *   （封面自带上渐变，见 {@link FEED_COVER_TOP_FADE}）⇒ 压深在封面顶边收到 0 的那一刻，
 *   画面正好换到"封面顶边的页底色"，**没有缝**；再往下压也看不见（被不透明的封面盖住）。
 * ★ 140 只是矮窗口（`coverTopVp()` 很小）时的兜底：保证状态栏 + 标题栏那一段一定被压到。
 */
const FEED_TOP_SCRIM_MIN_VP: number = 140;

/**
 * 由封面像素算出的页底色。
 *
 * ★★ 复用工程**现成**的那一套，一行新算法都不写：`effectKit.createColorPicker` 取封面主色
 *    → `ColorConversion.dealColor` 压暗 → 当页面底色 —— 与歌手页 `ArtistDetailPage.loadBackdropColor()`、
 *    专辑页 `AlbumDetailPage`、歌单页 `PlaylistDetailPage` **逐字同款**。
 *   （另一套 `vividFlowColors` 是播放页"流光"用的**鲜艳色**，亮度给到中高区间，
 *    压白字会读不清，所以底色这一档不用它。）
 * @param red 主色红通道 0–255。
 * @param green 主色绿通道 0–255。
 * @param blue 主色蓝通道 0–255。
 * @returns 不透明 `rgb(r, g, b)`（不透明度交给调用方的 `.opacity()`，别在这里编 α）。
 */
function feedTintOf(red: number, green: number, blue: number): string {
  const tuned: number[] = ColorConversion.dealColor(red, green, blue);
  const r: number = Math.max(0, Math.min(255, tuned[0]));
  const g: number = Math.max(0, Math.min(255, tuned[1]));
  const b: number = Math.max(0, Math.min(255, tuned[2]));
  return `rgb(${r}, ${g}, ${b})`;
}

/**
 * 数据来源（决定卡片脚注写什么、以及"没有通道"时空态说什么）。
 */
enum FeedOrigin {
  /** 还没加载 / 正在加载。 */
  NONE = 0,
  /** 当前平台的**榜单**（未登录）。 */
  BOARD = 1,
  /** 当前平台的**每日推荐**（已登录）。 */
  DAILY = 2,
  /** 加载失败或该平台没有通道（空态，写明原因）。 */
  EMPTY = 3
}

/**
 * 本页 `LazyForEach` 的数据源。
 *
 * ⚠️ 为什么要自己写一个、而不是用现成的 {@link RecommendSongUiDataSource}：
 *    `Swiper` 的 `LazyForEach` 项生成器里拿不到下标（签名只有 `item`），
 *    而点歌/补音质都需要"这一屏在队列里的下标" ⇒ 数据源必须能**按对象反查下标**。
 *    现成那个类只有 `getData/totalCount`，本页不为了自己改公共文件（它有别的引用方）。
 */
class FeedDataSource implements IDataSource {
  private rows: RecommendPrivateSongUi[] = [];
  private listeners: DataChangeListener[] = [];

  public constructor(rows: RecommendPrivateSongUi[]) {
    this.rows = rows;
  }

  public totalCount(): number {
    return this.rows.length;
  }

  public getData(index: number): RecommendPrivateSongUi {
    return this.rows[index];
  }

  /**
   * 按引用反查下标（`LazyForEach` 项生成器里拿不到下标的兜底）。
   * @param row 目标行。
   * @returns 下标；找不到返回 0（调用方点歌时 `playList` 自己会夹取）。
   */
  public indexOf(row: RecommendPrivateSongUi): number {
    const index: number = this.rows.indexOf(row);
    return index >= 0 ? index : 0;
  }

  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  /**
   * 追加一批行（翻页预取用）。
   *
   * ⚠️ 必须**逐行**发 `onDataAdd(index)`：`LazyForEach` 只认数据源发出来的通知，
   *    直接改内部数组**不会**渲染（表现就是"翻页请求成功了，屏幕上却没有新歌"）。
   * @param rows 新行（调用方已去重）。
   */
  public append(rows: RecommendPrivateSongUi[]): void {
    for (let i: number = 0; i < rows.length; i++) {
      this.rows.push(rows[i]);
      const index: number = this.rows.length - 1;
      for (let l: number = 0; l < this.listeners.length; l++) {
        this.listeners[l].onDataAdd(index);
      }
    }
  }

  /**
   * 删掉一行（「不感兴趣」用）。
   * @param index 行下标。
   */
  public deleteAt(index: number): void {
    if (index < 0 || index >= this.rows.length) {
      return;
    }
    this.rows.splice(index, 1);
    for (let l: number = 0; l < this.listeners.length; l++) {
      this.listeners[l].onDataDelete(index);
    }
  }
}

/**
 * 底栏页签「现在就听」。
 */
@ComponentV2
export struct NowPlayingFeedPage {
  /**
   * 一屏卡片底部要给壳层悬浮底栏让出的高度（vp）。
   *
   * 壳层按 `deviceInfo.distributionOSApiVersion >= 60100` 传 `56 + 16` / `56`
   * （与 `Index.ets` 里 `shellProvidesFloatingMiniBar` 同一判据）。
   */
  @Param bottomReserveVp: number = FEED_DEFAULT_BOTTOM_RESERVE_VP;
  /**
   * 壳层页签「再点一次」的下发信号。
   *
   * 竖向 `Swiper` 的"顶部"就是第 0 屏 ⇒ 收到信号切回下标 0
   * （与 `RecommendPage` / `EchoReviewPage` 的 `scrollEdge(Edge.Top)` 同语义）。
   */
  @Param scrollTopCommand: number = 0;

  /** 当前平台（首页「来源平台」设置）——本页的"对应平台"就取它。 */
  @Local homeSourceState: HomeSourceState =
    AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;
  /** 全局播控唯一真源：点歌只写它（经 `OnlinePlayUtil.playList`）。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /**
   * 播放页那颗主键用的**同一个 ViewModel** —— 本页的播放/暂停键必须走它（{@link onPlayButton}）。
   *
   * ★ 它没有构造参数（`features/player/Index.ets:37` 的导出）；内部那个 `@Trace appState`
   *   与本组件的 {@link appState} 是**同一条 `AppStorageV2` 通道**（`AppStorageKeys.MUSIC_APP_STATE`）
   *   ⇒ 两边看到的是同一份状态，不会多出一份播控真源。
   * ★ 为什么非走它不可：暂停/恢复的**真源在 `MediaService`**，
   *   `PlayerViewModel.togglePlayPause()` → `PlayerDataUtil.togglePlayPause(appState)`
   *   才带着"引擎首次加载要 `loadAsset(selectIndex)`"那条规则（`PlayerDataUtil.ets:88`）。
   */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** 收藏门的真源；它的 `@Trace favoriteVersion` 让收藏状态变化能驱动本页重绘。 */
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  /**
   * 播放意图（**工程硬规则"播放入口唯一"**）。
   *
   * ★ 本页"滑到哪播哪"里"队列已经在播、只需换当前曲"那一条走它：
   *   壳层 `@Monitor('intentState.requestVersion')` → `dispatchShellPlaybackIntent()`
   *   （`features/player/src/main/ets/util/PlaybackIntentShell.ets:29`），
   *   `queueIndex >= 0` 时由**它**去调 `MediaService.getInstance().loadAsset(queueIndex)`，
   *   而 `openPlayerUi === false` ⇒ 不会打开播放器（那一句写在 `if (openUi)` 里，`:45-48`）。
   *   两个 product 的壳层都挂了这条 monitor（`products/{default,pc}/.../Index.ets`）。
   * ★ 与 `MusicAppState` 同一个 `AppStorageV2` 通道（`AppStorageKeys.PLAYBACK_INTENT_STATE`），
   *   不新造状态、也不自己 `push` 路由。
   */
  @Local playbackIntentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE,
      () => new PlaybackIntentState())!;
  /** 底栏/标题栏沉浸光感档位（标题栏材质要用它，与首页同一套档位）。 */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /**
   * 账号变化信号（登录 / 退出 / 改账号）。
   *
   * ★ 本页"登录态"决定走**榜单**还是**每日推荐**两条完全不同的通道，
   *   所以账号一变就必须整页重载 —— 这里复用播放模块那个单调递增的版本号
   *   （与首页 `RecommendPage.@Monitor('accountChangedState.version')` 同一真源）。
   */
  @Local accountChangedState: AccountChangedState =
    AppStorageV2.connect(AccountChangedState, PlayerConstants.ACCOUNT_CHANGED_STATE,
      () => new AccountChangedState())!;
  /** 窗口信息（算封面边长、顶部让位用）。 */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 窗口断点（只为让封面边长在旋转/折叠展开时重算）。 */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;

  /** 竖向 Swiper 的控制器（"点当前页签回顶部" = `changeIndex(0)`）。 */
  private feedController: SwiperController = new SwiperController();
  /** 懒加载数据源（`LazyForEach` 直挂 `Swiper`）。 */
  @Local feedSource: FeedDataSource = new FeedDataSource([]);
  /**
   * 当前这一屏的下标（`onChange` 写入）。
   *
   * ★ 它有三个消费方：点歌/不感兴趣的定位、**背景取色**（`pageTint`）、
   *   以及"滑到哪就播哪"（见 {@link playAt}）。
   * ⚠️ `@Local` 是必需的：下面 `@Monitor('currentIndex')` 只能盯可观察的成员，
   *   写成普通私有字段的话翻页时取色**永远不会重新触发**（而且不报错）。
   */
  @Local currentIndex: number = 0;

  // ───────────────────── 背景：封面取色（照歌手页那一套）─────────────────────

  /**
   * 当前**生效**的页底色（**不透明** `rgb()`；取色完成前 = {@link FEED_BASE_NEUTRAL}）。
   *
   * 真源是封面（`row.coverUrl`），取色链路见 {@link extractCardColor}。
   */
  @Local pageTint: string = FEED_BASE_NEUTRAL;
  /** 已经取过色的封面地址（去重：同一张封面不要反复下载+解码）。 */
  private lastTintUrl: string = '';
  /** 取色代次：快速滑动 + 异步解码，靠它把过期的那一次结果丢掉（与播放页 `imageColorJobSeq` 同款）。 */
  private cardColorJobSeq: number = 0;
  /** 组件是否还挂着（异步回来时页面可能已经销毁）。 */
  private feedAlive: boolean = true;
  /** 加载中（空态/加载态的二选一）。 */
  @Local feedLoading: boolean = true;
  /** 已经加载的是哪条通道。 */
  @Local feedOrigin: FeedOrigin = FeedOrigin.NONE;
  /** 空态/脚注文案（**写明原因，不伪造数据**）。 */
  @Local feedHint: string = '';
  /** 已经按它加载过的平台值（去重，避免 `@Monitor` 与首次加载重复打网络）。 */
  private loadedSource: string = '';
  /**
   * 各首歌查到的音质档位标签（key = `source_songId`，值 = 多枚标签用 `|` 连起来，高档在前）。
   *
   * 音质是**按需异步查**的（`lxGetQualityOptions` 会打网络），所以只给"当前屏附近"
   * 那几首查，查到就写进这张表并通过 `qualityVersion` 触发重绘；查不到就空着，
   * 卡片上那一行**整块不显示** —— **不编一个假档位**（参考图上那三枚
   * `AUDIO Vivid / 超高清音频 / 空间音频` 是厂商品牌标签，本工程接口给不出，不冒充）。
   */
  @Local qualityLabels: Map<string, string> = new Map<string, string>();
  /** 音质表的版本号：`Map` 本身不是可观察的，靠它推动卡片重绘。 */
  @Local qualityVersion: number = 0;
  /** 已经发起过音质查询的 key（去重，避免来回滑反复打网络）。 */
  private qualityRequested: string[] = [];

  // ───────────────────── 无限刷（翻页累积）的状态 ─────────────────────

  /** 已经成功取到的页码（0 = 还没取过；第 1 页成功后 = 1，预取就是 2、3…）。 */
  private feedPage: number = 0;
  /** 并发闸：同一时刻只允许一个翻页请求在飞（滑动很快时会连续触发预取）。 */
  private feedFetching: boolean = false;
  /** 连续"0 首新歌 / 请求失败"的次数 —— 收尾保护②的计数（见 {@link loadMore}）。 */
  private feedEmptyStreak: number = 0;
  /** 这条通道还能不能往后取：true 之后**一律不再打接口**（收尾保护的总闸）。 */
  @Local feedExhausted: boolean = false;
  /** 是否让 `Swiper` 循环：到底之后打开 ⇒ 永远滑不到空白（"回到开头循环"）。 */
  @Local feedLoop: boolean = false;
  /** 已经插入过的 `source|songId`（**去重真源**，也是"同一首歌不重复插入"的判据）。 */
  private feedSeen: string[] = [];
  /** 本页点过「不感兴趣」的 key（只在**本页**隐藏，不落盘、不动播放队列）。 */
  private feedDisliked: string[] = [];
  /**
   * 数据源增删的版本号。
   *
   * ⚠️ `LazyForEach` 的数据源变了**不会**让外层 `if (totalCount() > 0)` 重算
   * （`totalCount()` 不是可观察的）⇒ 靠读这个 `@Local` 把外层订阅上，
   * 否则"删到一首不剩"时页面会停在空的 `Swiper` 上（一片空白）。
   */
  @Local feedRevision: number = 0;
  /**
   * 每首歌的总时长标签（key = `source|songId`，值 = 源数据自带的 `interval`）。
   *
   * 进度条右端的"总时长"取它（真实数据，取不到就显示 `--:--`）；
   * 正在播的那一屏改用 `MusicAppState.totalTime`（同一个真源给播放页用的那个值）。
   */
  private feedDurations: Map<string, string> = new Map<string, string>();

  // ───────────────────── 歌词两行（当前行 / 上一行）─────────────────────

  /** 当前歌词行（真源 = `MusicStoreService.getCardLyric()`，见文件头 §四.6）。 */
  @Local lyricCurrent: string = '';
  /** 上一行歌词（自己观察到的历史值，同样是真实数据）。 */
  @Local lyricPrevious: string = '';
  /** 上一次看到的是哪首歌（换歌就把两行清空，避免把上一首的残留行显示在新歌上）。 */
  private lyricSongKey: string = '';
  /** 换歌后"等一个新鲜值"：这期间收进来的值直接采纳，不写进"上一行"。 */
  private lyricAwaitingFresh: boolean = false;

  /** 本机收藏总数（红心旁边那个数字）。 */
  @Local favoriteTotal: number = 0;

  aboutToAppear(): void {
    // ⚠️ 收藏数**缓存**在这里，不要在 `build()` 里现算：`store.getFavorites()` 会
    //   `readList(KEY_FAVORITES)`（反序列化整份收藏），而进度一 tick 每张卡都会重绘
    //   ⇒ 每帧 2~3 次 JSON 解析，白白卡滑动。
    this.favoriteTotal = this.store.getFavorites().length;
    this.feedAlive = true;
    // 背景取色的兜底：进页面先按**当前这一屏**的封面取一次色
    // （`applyRows` 之后下标归 0，那次也会触发；这里覆盖"页面被复用、下标没变"的情况）。
    this.refreshCardColor();
    this.load();
  }

  /** 页面销毁：异步取色回来时不要再写状态（与播放页 `isAlive` 同一口径）。 */
  aboutToDisappear(): void {
    this.feedAlive = false;
  }

  /**
   * 翻屏 ⇒ 背景（取色底 + 封面上的两条渐变的端点色）跟着换。
   *
   * ⚠️ 不能改成"在 `onFeedChanged` 里直接调"：`applyRows`（首批装载）与 `deleteRowAt`
   *   （不感兴趣删行）也会改下标，而它们**不经过** `onChange` ⇒ 那些路径上背景不换。
   *   盯 `@Local currentIndex` 这一个真源，四条路径全覆盖。
   */
  @Monitor('currentIndex')
  onFeedIndexChanged(): void {
    this.refreshCardColor();
  }

  /** 收藏变化（`@Trace favoriteVersion`）⇒ 只更新那个数字，不做别的。 */
  @Monitor('store.favoriteVersion')
  onFavoriteChanged(): void {
    this.favoriteTotal = this.store.getFavorites().length;
  }

  /** 当前平台代号（tx / kg / kw / wy / mg）—— 与首页 `mapHomeSource` 同源口径。 */
  private svcSource(): string {
    const raw: string = this.homeSourceState.source;
    return raw === 'qq' ? 'tx' : raw;
  }

  /** 当前平台的展示名（脚注/空态里写出来，用户才知道"对应平台"到底是哪个）。 */
  private sourceLabel(): string {
    switch (this.svcSource()) {
      case 'tx':
        return 'QQ音乐';
      case 'wy':
        return '网易云音乐';
      case 'kg':
        return '酷狗音乐';
      case 'kw':
        return '酷我音乐';
      case 'mg':
        return '咪咕音乐';
      default:
        return this.svcSource();
    }
  }

  // ─────────────────────────── 数据加载（两条通道）───────────────────────────

  /**
   * 加载本页内容：有账号走"每日推荐"，没账号走"榜单"。
   *
   * ★ **"是否登录"只有一个真源** = `AccountService.listAccounts()`
   *   （`features/player/src/main/ets/account/AccountService.ets:117`），
   *   与首页 `RecommendViewModel.refreshGuestMode()` 同一口径。
   *   ⚠️ `AccountService` 需要 `init(context)` 才能读 preferences，
   *     所以在读之前必须先把宿主 context 交进去（`init` 是幂等的）。
   */
  public load(): void {
    this.feedLoading = true;
    this.feedOrigin = FeedOrigin.NONE;
    this.feedHint = '';
    // ★ 换通道 / 刷新 = **一切翻页状态归零**：否则会把上一条通道的页码、去重表、
    //   "已到底"结论带过来（表现就是"切了平台以后滑两下就再也刷不出新歌"）。
    this.resetPaging();
    const src: string = this.svcSource();
    this.loadedSource = this.homeSourceState.source;
    AccountService.init(this.abilityContext());
    const accounts: PlatformAccount[] = AccountService.listAccounts();
    const acc: PlatformAccount | undefined = this.pickAccount(accounts, src);
    Logger.info(RZD_TAG, `load platform=${src} accounts=${accounts.length} matched=${acc !== undefined}`);
    if (acc === undefined) {
      // 未登录（或该平台没登录）：走**当前平台的榜单**。
      void this.loadChart(src);
      return;
    }
    void this.loadDaily(src, acc);
  }

  /** 翻页状态归零（`load()` 与"刷新"共用）。 */
  private resetPaging(): void {
    this.feedPage = 0;
    this.feedFetching = false;
    this.feedEmptyStreak = 0;
    this.feedExhausted = false;
    this.feedLoop = false;
    this.feedSeen = [];
    this.feedDurations = new Map<string, string>();
  }

  /**
   * 从账号表里挑"当前这个平台"的账号。
   *
   * ⚠️ 不能只认第一个账号：工程可能同时登录了多个平台，而用户切了「来源平台」
   * 之后要的正是**那个平台**的每日推荐（用户原话"登录了用**对应平台**的每日三十首"）。
   * @param accounts 已登录账号。
   * @param svcSource 当前平台代号。
   * @returns 该平台的账号；没有返回 undefined（调用方据此走榜单通道）。
   */
  private pickAccount(accounts: PlatformAccount[], svcSource: string): PlatformAccount | undefined {
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].source === svcSource) {
        return accounts[i];
      }
    }
    return undefined;
  }

  /**
   * 未登录通道：当前平台的**新歌榜**（与首页「新歌推荐」卡同一张榜、同一个取数函数）。
   *
   * 榜单 id 全程走 `pickFeatureBoardId()`（`RecommendDataUtil.ets:87`）那张表，
   * **不手拼 `xx_数字`**；表里没有该平台时它返回**空串** ⇒ 这里直接给空态并写明原因。
   * @param src 平台代号。
   */
  private async loadChart(src: string): Promise<void> {
    const boardId: string = pickFeatureBoardId('newSongs', src);
    if (boardId.length === 0) {
      Logger.warn(RZD_TAG, `load no-board platform=${src}`);
      this.applyEmpty(`「${this.sourceLabel()}」暂无可用榜单`);
      return;
    }
    try {
      // 第 1 页与上一版逐字同口径（limit = FEED_BOARD_LIMIT）—— 只多了一个"这一页取多少"的函数。
      const limit: number = this.boardFetchLimit(1);
      const res: LXSearchResult = await lxLeaderboard(boardId, 1, limit);
      const rows: RecommendPrivateSongUi[] = [];
      for (let i: number = 0; i < res.list.length; i++) {
        rows.push(this.toRow(res.list[i], i));
      }
      Logger.info(RZD_TAG, `load board=${boardId} page=1 limit=${limit} raw=${res.list.length} songs=${rows.length}`);
      this.applyRows(rows, FeedOrigin.BOARD);
    } catch (err) {
      const e = err as BusinessError;
      Logger.error(RZD_TAG, `load failed board=${boardId} code=${e.code} msg=${e.message}`);
      this.applyEmpty(`「${this.sourceLabel()}」榜单暂时取不到`);
    }
  }

  /**
   * 已登录通道：**该平台账号的每日推荐**。
   *
   * 与首页登录态同源：`AccountService.getDailyTrackIds()`（:286）+
   * `getTrackDetails()`（:292），由该账号的 provider 取（tx / wy / kg 三个 provider 有实现）。
   * ⚠️ 没有对应 provider 的平台（kw / mg）会走到 catch ⇒ **空态并写明原因，不伪造**。
   *
   * ★★ 这条通道**没有下一页**（读 provider 实现得来，见 {@link loadMore} 的注释）⇒
   *    `applyRows` 会直接把 `feedExhausted` 置 true 并打开 `Swiper.loop`，
   *    "到末尾后回到开头循环"，不再试着往后取。
   * @param src 平台代号。
   * @param acc 该平台的账号。
   */
  private async loadDaily(src: string, acc: PlatformAccount): Promise<void> {
    try {
      const ids: string[] = await AccountService.getDailyTrackIds(acc.id);
      if (ids.length === 0) {
        Logger.warn(RZD_TAG, `daily empty platform=${src} account=${acc.id}`);
        this.applyEmpty(`「${this.sourceLabel()}」每日推荐暂时取不到`);
        return;
      }
      const tracks: PlatformTrackInfo[] = await AccountService.getTrackDetails(acc.id, ids);
      const rows: RecommendPrivateSongUi[] = [];
      for (let i: number = 0; i < tracks.length; i++) {
        rows.push(this.toRowFromTrack(tracks[i], i));
      }
      Logger.info(RZD_TAG, `load daily platform=${src} ids=${ids.length} songs=${rows.length}`);
      this.applyRows(rows, FeedOrigin.DAILY);
    } catch (err) {
      const e = err as BusinessError;
      Logger.error(RZD_TAG, `load daily failed platform=${src} code=${e.code} msg=${e.message}`);
      // kw / mg 在本工程**没有 provider 实现**（`features/player/.../account/providers` 只有
      // tx / wy / kg）⇒ 这两个平台的"每日推荐"拿不到是真实现状，如实写清楚。
      this.applyEmpty(`「${this.sourceLabel()}」未接入每日推荐，请切换到 QQ / 网易云 / 酷狗`);
    }
  }

  /** 把榜单歌转成本页的行模型（顺带记下它自带的时长，进度条右端要用）。 */
  private toRow(song: LXSearchSong, index: number): RecommendPrivateSongUi {
    const ui = new RecommendPrivateSongUi();
    ui.id = index;
    ui.title = song.name;
    ui.singer = song.singer;
    ui.source = song.source;
    ui.songId = song.songId;
    ui.coverUrl = song.img;
    this.feedDurations.set(this.songKey(ui), song.interval);
    return ui;
  }

  /** 把平台账号歌转成本页的行模型（与 `RecommendDataUtil` 那张私有映射同字段口径）。 */
  private toRowFromTrack(track: PlatformTrackInfo, index: number): RecommendPrivateSongUi {
    const ui = new RecommendPrivateSongUi();
    ui.id = index;
    ui.title = track.name;
    ui.singer = track.singer;
    ui.source = track.source;
    ui.songId = track.id;
    ui.coverUrl = track.picUrl;
    this.feedDurations.set(this.songKey(ui), track.interval);
    return ui;
  }

  /**
   * 装载成功：换数据源（**去重后**）+ 清音质表 + 回到第一屏 + 结算"这条通道还能不能翻"。
   * @param rows 原始行（可能含重复与空 songId）。
   * @param origin 这条通道。
   */
  private applyRows(rows: RecommendPrivateSongUi[], origin: FeedOrigin): void {
    this.feedSeen = [];
    const fresh: RecommendPrivateSongUi[] = this.filterFresh(rows);
    this.feedSource = new FeedDataSource(fresh);
    this.feedPage = 1;
    this.feedEmptyStreak = fresh.length === 0 ? 1 : 0;
    this.feedOrigin = origin;
    this.feedHint = origin === FeedOrigin.BOARD ?
      `来自 ${this.sourceLabel()} · 榜单` : `来自 ${this.sourceLabel()} · 每日推荐`;
    this.feedLoading = false;
    this.currentIndex = 0;
    this.qualityLabels = new Map<string, string>();
    this.qualityRequested = [];
    this.qualityVersion++;
    this.feedRevision++;
    // ★ 每日推荐**结构上没有下一页**（见 loadDaily / loadMore）⇒ 一开始就按"到底"处理，
    //   让循环直接生效。这样避免"用户滑到最后一首那一刻才切模式"（那一下会跳）。
    if (origin === FeedOrigin.DAILY) {
      this.feedExhausted = true;
      Logger.info(RZD_TAG, `daily has no paging -> loop total=${fresh.length}`);
    }
    this.syncLoop();
    // ⚠️ `Swiper.onChange` 在**切换到位**时才回调，而"首帧是否回调"没有保证 ⇒
    //    第 0 屏的音质**主动查一次**（见文件头 §四 的同一处坑）。
    if (fresh.length > 0) {
      this.requestQualityAround(0);
      // 首批就少到"已经落进预取区"（例如每日推荐只有两三首）：立刻补一页/开循环，
      // 否则要等用户先滑一下才会触发。
      if (fresh.length <= FEED_PREFETCH_REMAIN + 1) {
        void this.loadMore();
      }
      // ★★ **进页面自动播放**（用户 2026-10-15 原话："打开这个页面自动播放当前歌曲，
      //    滑到哪首歌就播放哪一首"）。首批数据刚到就起播第 0 屏。
      //    ⚠️ 只在**首屏装载**这一条路上起播：`appendRows`（翻页追加）不碰播放 ——
      //      否则每预取一页都会把当前在播的那首重放一遍。
      //    ⚠️ 用的是同一个 {@link playAt}：它自己会判"这首是不是已经在播"，
      //      所以"从别的页签切回来、歌还没变"时**不会重播**（用户要求）。
      this.playAt(0);
    }
  }

  /** 装载失败/无通道：空态，文案里写明原因。 */
  private applyEmpty(hint: string): void {
    this.feedSource = new FeedDataSource([]);
    this.feedOrigin = FeedOrigin.EMPTY;
    this.feedHint = hint;
    this.feedLoading = false;
    this.currentIndex = 0;
    this.feedExhausted = true;
    this.feedLoop = false;
    this.feedRevision++;
  }

  /** 宿主 UIAbilityContext（`AccountService.init` 需要；拿不到就返回 undefined，由它自己兜）。 */
  private abilityContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  // ─────────────────────── 无限刷：翻页累积 + 去重 + 收尾保护 ───────────────────────

  /** 行模型 ↔ 首页那两份 ID 口径的**去重键**：`source|songId`（任务口径，不含下标、不含封面）。 */
  private songKey(row: RecommendPrivateSongUi): string {
    return row.source + '|' + row.songId;
  }

  /**
   * 把一批行里"没见过的"挑出来。
   *
   * ★ 去重真源 = {@link feedSeen}（`source|songId`）。它还有第二个作用：
   *   非 kg 平台靠"把窗口开大"往前推（见 {@link boardFetchLimit}），
   *   那次请求会把**已经插入过的前缀**原样带回来 —— 这里正好把它们切掉。
   * ★ `songId` 为空的行直接丢：点歌/收藏/音质查询全都要它，插进来只会是一张点不动的卡。
   * @param rows 原始行。
   * @returns 可以插入的新行（顺序保持）。
   */
  private filterFresh(rows: RecommendPrivateSongUi[]): RecommendPrivateSongUi[] {
    const fresh: RecommendPrivateSongUi[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const key: string = this.songKey(rows[i]);
      if (key.length <= 1) {
        continue;
      }
      if (this.feedSeen.indexOf(key) >= 0 || this.feedDisliked.indexOf(key) >= 0) {
        continue;
      }
      this.feedSeen.push(key);
      fresh.push(rows[i]);
    }
    return fresh;
  }

  /**
   * 第 `page` 页要请求的 limit。
   *
   * · **kg = 真分页**（`kgLeaderboard` 把 `page` 当页号用，`LXMusicSDK.ets:3088`）
   *   ⇒ 页大小固定，零浪费、**不会漏歌**；
   * · 其余四个平台的实现忽略 `page`（见 {@link loadMore}）⇒ 只能"把窗口开大"再切前缀。
   *   上界 {@link FEED_BOARD_WINDOW_MAX}：再大也只是把同一批歌反复取回来（还白等网络）。
   * @param page 页码（1 起）。
   * @returns 本次请求的 limit。
   */
  private boardFetchLimit(page: number): number {
    if (this.svcSource() === 'kg') {
      return FEED_BOARD_LIMIT;
    }
    return Math.min(FEED_BOARD_LIMIT * page, FEED_BOARD_WINDOW_MAX);
  }

  /**
   * 预取下一页（滑到倒数第 {@link FEED_PREFETCH_REMAIN} 首时由 {@link onFeedChanged} 触发）。
   *
   * ## 两条通道"能不能翻页"，都是**读实现**得来的（不是猜 API 文档）
   *
   * ### 1、未登录 = 榜单 · `lxLeaderboard(boardId, page, limit)`
   *     （`features/player/src/main/ets/source/LXMusicSDK.ets:169`）
   *   它内部按平台前缀分发，**只有 kg 真用了 `page`**：
   *     · `kg` → `kgLeaderboard(id, page, limit)`：URL 里真的带 `&page=` + `&pagesize=`
   *       （`:3081`，`:3088`）⇒ **真分页**；
   *     · `kw` → `kwLeaderboard(id, page, limit)`：`page` **没用**，URL 写死 `pn=0&rn=limit`
   *       （`:3031`，`:3034`）⇒ 只能加大 `rn`；
   *     · `tx` → `lxTxToplist(id, limit)`：**签名里就没有 page**（`:179`，`:2065`），
   *       它自己按 `song_begin` 循环取到 `songNum` 为止 ⇒ 加大 `songNum` 才多给；
   *     · `wy` → `wyLeaderboard(id, limit)`：**签名里就没有 page**（`:198`）；
   *     · `mg` → `mgLeaderboard(id, page, limit)`：收下了 page 但**没用**（`:3153`）。
   *   ⇒ **能翻就翻**：kg 走"页码递增 + 固定页大小"；那四个平台走
   *     "**窗口随页数变大**（`limit = 单页 × 页数`，有上界）+ {@link filterFresh} 切前缀"。
   *     两条路都**只把接口真实返回的歌插进来**（`raw` / `added` 都打日志），**不伪造数据**。
   *
   * ### 2、已登录 = 每日推荐 · `AccountService.getDailyTrackIds()`
   *     （`features/player/src/main/ets/account/AccountService.ets:286`）
   *   provider 侧**没有任何分页 / 游标**：
   *     · `TxProvider.ets:1225`：内部固定翻 `Page = 1..3` 再 `Array.from(new Set(ids))`，
   *       返回的是**一份定长的列表**，没有"下一页"的参数可传；
   *     · `WyProvider.ets:427`：`POST /weapi/v3/discovery/recommend/songs`（`{}` 空体）单次返回；
   *     · `KgProvider.ets:522`：`everyday_song_recommend` 单次返回。
   *   ⇒ **不能翻**。按任务口径改成"**到末尾后回到开头循环**"，实现 = `Swiper.loop(true)`
   *     （`applyRows` 里对 DAILY 直接置 `feedExhausted` 并 {@link syncLoop}）：
   *     不重复插入同一首歌、`LazyForEach` 的 key 不变，滑到头也**不会出现空白**。
   *
   * ## 收尾保护（两道，避免死循环打接口）
   *   ① 连续 {@link FEED_EMPTY_STREAK} 次"0 首新歌 / 请求失败" ⇒ {@link markExhausted}，
   *      此后**一律不再打接口**（`feedExhausted` 是总闸）；
   *   ② 页码硬上界 {@link FEED_MAX_PAGES}。
   *   两者都会落一行 `RzdNowPlaying exhausted reason=…`（上机判读见任务报告）。
   */
  private async loadMore(): Promise<void> {
    if (this.feedFetching || this.feedExhausted) {
      return;
    }
    if (this.feedOrigin !== FeedOrigin.BOARD) {
      // 每日推荐 / 空态 / 还没加载完：没有下一页（依据见方法注释）。
      this.markExhausted('no-board-channel');
      return;
    }
    this.feedFetching = true;
    const page: number = this.feedPage + 1;
    try {
      const src: string = this.svcSource();
      const boardId: string = pickFeatureBoardId('newSongs', src);
      if (boardId.length === 0) {
        this.markExhausted('board-missing');
        return;
      }
      const limit: number = this.boardFetchLimit(page);
      Logger.info(RZD_TAG,
        `page request board=${boardId} platform=${src} page=${page} limit=${limit} prev=${this.feedSource.totalCount()}`);
      const res: LXSearchResult = await lxLeaderboard(boardId, page, limit);
      const rows: RecommendPrivateSongUi[] = [];
      for (let i: number = 0; i < res.list.length; i++) {
        rows.push(this.toRow(res.list[i], i));
      }
      this.feedPage = page;
      const added: number = this.appendRows(rows);
      Logger.info(RZD_TAG,
        `page result board=${boardId} page=${page} raw=${res.list.length} added=${added} ` +
          `total=${this.feedSource.totalCount()} streak=${this.feedEmptyStreak}`);
      if (added === 0) {
        this.feedEmptyStreak++;
      } else {
        this.feedEmptyStreak = 0;
      }
      if (this.feedEmptyStreak >= FEED_EMPTY_STREAK) {
        this.markExhausted('empty-page');
      } else if (page >= FEED_MAX_PAGES) {
        this.markExhausted('max-page');
      }
    } catch (err) {
      const e = err as BusinessError;
      this.feedEmptyStreak++;
      Logger.error(RZD_TAG,
        `page failed page=${page} streak=${this.feedEmptyStreak} code=${e.code} msg=${e.message}`);
      if (this.feedEmptyStreak >= FEED_EMPTY_STREAK) {
        this.markExhausted('page-error');
      }
    } finally {
      // ⚠️ `finally` 一定要有：失败路径上不放闸的话，这条通道就再也不会有下一次预取了。
      this.feedFetching = false;
    }
  }

  /**
   * 追加（**去重后**）并通知 `LazyForEach`。
   * @param rows 原始行。
   * @returns 真正插进去多少首（0 = 这一页全是已见过的 ⇒ 交给收尾保护计数）。
   */
  private appendRows(rows: RecommendPrivateSongUi[]): number {
    const fresh: RecommendPrivateSongUi[] = this.filterFresh(rows);
    if (fresh.length === 0) {
      return 0;
    }
    this.feedSource.append(fresh);
    this.feedRevision++;
    return fresh.length;
  }

  /**
   * 收尾：标记这条通道取不动了（此后不再打接口），并把"循环"接上。
   * @param reason 判读用的短原因（会打进日志）。
   */
  private markExhausted(reason: string): void {
    if (!this.feedExhausted) {
      this.feedExhausted = true;
      Logger.info(RZD_TAG,
        `exhausted reason=${reason} page=${this.feedPage} total=${this.feedSource.totalCount()}`);
    }
    this.syncLoop();
  }

  /**
   * 把 `Swiper.loop` 同步成"这条通道还能不能长大"。
   *
   * ⚠️ **只在取不动了之后才开循环**：还在翻页时开循环的话，"滑到最后一首"会立刻跳回第一首，
   *    用户就永远看不到刚预取进来的那几首（表现是"底部总是那几首在前面转"）。
   * ⚠️ 少于 2 首不开（循环 1 首等于原地不动，`Swiper` 也没意义）。
   */
  private syncLoop(): void {
    const enable: boolean = this.feedExhausted && this.feedSource.totalCount() >= 2;
    if (this.feedLoop === enable) {
      return;
    }
    this.feedLoop = enable;
    Logger.info(RZD_TAG,
      `loop -> ${enable} total=${this.feedSource.totalCount()} exhausted=${this.feedExhausted}`);
  }

  /**
   * 顶栏右侧「换一换 / 刷新」：**丢掉翻页进度**，重新走一次本通道的第一页。
   *
   * ⚠️ 不伪造"换一批"：榜单接口给的就是那张榜（每日推荐就是那天的推荐），
   *    所以这里老老实实重取第一页；`feedDisliked` 不清（用户点过"不感兴趣"的歌不该被刷新带回来）。
   */
  private refreshFeed(): void {
    Logger.info(RZD_TAG,
      `refresh platform=${this.svcSource()} origin=${this.feedOrigin} total=${this.feedSource.totalCount()}`);
    this.load();
  }

  /**
   * 「不感兴趣」：**只在本页**把这首歌摘掉。
   *
   * · 记进 {@link feedDisliked}（本页会话内生效，不落盘、不动 `MusicStoreService`、不动播放队列）；
   * · 走数据源的 `deleteAt` ⇒ 真的从 `LazyForEach` 里删掉（不是画个灰条）；
   * · ⚠️ `songId` 为空 / 只剩一首时不删：见 {@link deleteRowAt}。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  private dislike(row: RecommendPrivateSongUi, index: number): void {
    const key: string = this.songKey(row);
    if (key.length <= 1) {
      this.toast('这首没法标记不感兴趣');
      return;
    }
    if (this.feedSource.totalCount() <= 1) {
      this.toast('至少留一首吧');
      return;
    }
    if (this.feedDisliked.indexOf(key) < 0) {
      this.feedDisliked.push(key);
    }
    this.deleteRowAt(index);
    Logger.info(RZD_TAG,
      `dislike ${key} at=${index} total=${this.feedSource.totalCount()}`);
    this.toast('已减少这类推荐');
    // 摘掉一首之后"剩余"又少了一格 ⇒ 立刻看看要不要补一页
    if (this.feedSource.totalCount() - 1 - this.currentIndex <= FEED_PREFETCH_REMAIN) {
      void this.loadMore();
    }
  }

  /**
   * 从数据源里删掉一行，并把 `currentIndex` 收进合法范围。
   *
   * ⚠️ 删完可能只剩 1 首甚至 0 首：前者由 {@link dislike} 提前挡住，
   *    后者在空态分支兜住（外层 `if` 读 `feedRevision` 订阅，见那个字段的注释）。
   * @param index 行下标。
   */
  private deleteRowAt(index: number): void {
    this.feedSource.deleteAt(index);
    this.feedRevision++;
    const total: number = this.feedSource.totalCount();
    if (index < this.currentIndex) {
      this.currentIndex = this.currentIndex - 1;
    }
    if (this.currentIndex > total - 1) {
      this.currentIndex = Math.max(total - 1, 0);
    }
    this.syncLoop();
  }

  // ─────────────────────────── 音质标签（按需、异步）───────────────────────────

  /** 音质表的 key。 */
  private qualityKey(row: RecommendPrivateSongUi): string {
    return row.source + '_' + row.songId;
  }

  /** 给"当前屏前后各一屏"那几首查音质（`cachedCount(1)` ⇒ 前后各缓存一屏）。 */
  private requestQualityAround(index: number): void {
    const total: number = this.feedSource.totalCount();
    for (let offset: number = -1; offset <= 1; offset++) {
      const i: number = index + offset;
      if (i < 0 || i >= total) {
        continue;
      }
      this.requestQuality(this.feedSource.getData(i));
    }
  }

  /**
   * 查一首歌的可用档位标签（**全部**档位，不只最高那一档 —— 卡片上那一行要画成一排胶囊）。
   *
   * 用的是工程现成的 `lxGetQualityOptions(song)`（`features/player/.../source/LXQualityApi.ets`
   * —— 实时接口 → 脚本声明档位四级降级）；查不到就**不显示**，不编假档位。
   * @param row 目标歌曲。
   */
  private requestQuality(row: RecommendPrivateSongUi): void {
    if (row.songId.length === 0 || row.source.length === 0) {
      return;
    }
    const key: string = this.qualityKey(row);
    if (this.qualityRequested.indexOf(key) >= 0 || this.qualityLabels.has(key)) {
      return;
    }
    this.qualityRequested.push(key);
    const song: LXSearchSong = this.toLxSong(row);
    lxGetQualityOptions(song).then((options: LXQualityOption[]): void => {
      if (options.length === 0) {
        return;
      }
      // 音质表按低→高排 ⇒ 倒着走，最高档排在最前面（与参考图上那排胶囊的读法一致）。
      const labels: string[] = [];
      for (let i: number = options.length - 1; i >= 0; i--) {
        const label: string = this.qualityLabel(options[i].type);
        if (label.length > 0 && labels.indexOf(label) < 0) {
          labels.push(label);
        }
      }
      if (labels.length === 0) {
        return;
      }
      const next: Map<string, string> = new Map<string, string>();
      this.qualityLabels.forEach((value: string, mapKey: string): void => {
        next.set(mapKey, value);
      });
      next.set(key, labels.join(FEED_QUALITY_SEP));
      // 换新的 Map 引用 + 抬版本号：`Map` 本身不是可观察对象，只有这样卡片才会重绘。
      this.qualityLabels = next;
      this.qualityVersion++;
    }).catch((): void => {
      // 查不到就空着 —— 卡片上那一行整块不显示，不伪造。
    });
  }

  /**
   * 这一屏要画成胶囊的档位标签（最多 {@link FEED_QUALITY_PILL_MAX} 枚，查不到就返回空数组）。
   * ⚠️ 函数里必须先读一下 `qualityVersion`：`Map` 不是可观察的，读版本号才能让卡片订阅上重绘。
   * @param row 这一屏的歌。
   * @returns 标签数组（可能是空数组 ⇒ 那一行整块不显示）。
   */
  private qualityPills(row: RecommendPrivateSongUi): string[] {
    if (this.qualityVersion < 0) {
      return [];
    }
    const joined: string | undefined = this.qualityLabels.get(this.qualityKey(row));
    if (joined === undefined || joined.length === 0) {
      return [];
    }
    const all: string[] = joined.split(FEED_QUALITY_SEP);
    const pills: string[] = [];
    for (let i: number = 0; i < all.length && pills.length < FEED_QUALITY_PILL_MAX; i++) {
      if (all[i].length > 0) {
        pills.push(all[i]);
      }
    }
    return pills;
  }

  /** LX 音质 id → 卡片上的短标签（与 `RecordListPage.qualityLabel` 同一张对照表）。 */
  private qualityLabel(quality: string): string {
    switch (quality) {
      case '128k':
        return '128k';
      case '320k':
        return '320k';
      case 'flac':
        return 'FLAC';
      case 'flac24bit':
        return 'Hi-Res';
      default:
        return quality;
    }
  }

  // ─────────────────────────── 播放 ───────────────────────────

  /** 行模型 → LX 搜索歌（`OnlinePlayUtil.playList` 入参类型）。 */
  private toLxSong(row: RecommendPrivateSongUi): LXSearchSong {
    return {
      songId: row.songId,
      name: typeof row.title === 'string' ? row.title : '',
      singer: typeof row.singer === 'string' ? row.singer : '',
      albumName: '',
      albumId: '',
      source: row.source,
      interval: '',
      img: row.coverUrl,
      types: []
    };
  }

  /** 整份队列（顺序与屏幕上从上到下一致 —— 上下滑换歌与播放队列必须是同一个顺序）。 */
  private buildQueue(): LXSearchSong[] {
    const songs: LXSearchSong[] = [];
    const total: number = this.feedSource.totalCount();
    for (let i: number = 0; i < total; i++) {
      songs.push(this.toLxSong(this.feedSource.getData(i)));
    }
    return songs;
  }

  /**
   * 播放第 `index` 首 —— **进页面自动播放**与**滑到哪播哪**共用这一个入口。
   *
   * ## 1、三条分支（**先判"这首是不是已经在播"，避免重复起播**）
   *   · 已经在播的就是**这一首** ⇒ 直接 return（重复对同一首起播会把进度打回 0）；
   *   · 已经在播的是**同一个队列**里的**另一首** ⇒ 走 `PlaybackIntentState`
   *     （见 §2；队列不动、不重拉歌词、播放器不开）；
   *   · 其余（页面刚进来 / 队列被别处换过）⇒ 走**组队列**的官方入口
   *     `OnlinePlayUtil.playList(appState, 整份队列, 下标, uiContext, **false**)`。
   *
   * ## 2、★★ 「这个页面不会打开播放器」是怎么做到的（**两个入口各一条正规出口，不做事后回滚**）
   *   · **组队列那一条**：`playList` 第 5 个参数 `openPlayer` 传 `false`
   *     （`OnlinePlayUtil.ets:225` 起，默认 `true` ⇒ 现有 4 参调用点一行都不用改）。
   *     `playList` 内部就**不再调** `openFullScreen()` ⇒ `appState.isShowPlay` 从头到尾没被写过，
   *     浮层自然不出现。
   *     ⚠️ **不许**改用"调完再 `appState.isShowPlay = false`"的写法：`openFullScreen` 是在
   *       `uiContext.animateTo()` 的**闭包**里写这个字段的，事后回滚 = "请求过又撤销"，
   *       而壳层的 `@Monitor('appState.isShowPlay')`（`products/default/.../Index.ets:413`）
   *       会在 `pushPlayerRoute()` 里读到那个**瞬时的 true**。
   *   · **只换当前曲那一条**：走 `PlaybackIntentState`（工程硬规则"播放入口唯一"）——
   *     壳层 `@Monitor('intentState.requestVersion')` → `dispatchShellPlaybackIntent()`
   *     （`PlaybackIntentShell.ets:29`）：`queueIndex >= 0` 时它自己 `MediaService.loadAsset(queueIndex)`，
   *     而 `openUi === false` ⇒ **不触发** `onRequestOpenPlayerUi()`（那一句写在 `if (openUi)` 里，
   *     `:45-48`）。两个 product 的壳层都挂了这条 monitor。
   *     ⇒ 队列不动、不重建、不并发重拉歌词、播放器不开。
   *
   * ## 3、去抖
   *   ② 那条分支要求"**全局队列就是屏幕上这一份**"，而组队列只在第三条分支发生 ——
   *   于是快速连滑时：第一下组队列起播，后面每一下都只发一个 intent（`loadAsset` 一次），
   *   **不会连着重开队列**（每次重开队列都会把 20 首歌的歌词并发拉一遍，是本页最贵的一件事）。
   *   `MediaService.loadAsset` 自己还有 `loadRequestSeq` 代次判断，过期的那次不生效。
   * @param index 队列下标（= 屏幕上这一屏的下标）。
   */
  private playAt(index: number): void {
    const songs: LXSearchSong[] = this.buildQueue();
    if (songs.length === 0) {
      return;
    }
    const target: number = index < 0 || index >= songs.length ? 0 : index;
    const row: RecommendPrivateSongUi = this.feedSource.getData(target);
    const queue: SongItem[] = this.appState.playQueue;
    if (this.isCurrentSong(row)) {
      // 已经在播这一首（含"点封面/点播放键"重复点同一屏）：不动队列、不重置进度
      Logger.info(RZD_TAG, `play skip (already current) index=${target} ${row.source}_${row.songId}`);
      return;
    }
    if (queue.length === songs.length && this.queueMatchesFeed(queue)) {
      // 队列就是屏幕上这一份 ⇒ 走播放意图（壳层会调 loadAsset，**不会**打开播放器）
      const intent: PlaybackIntentState = this.playbackIntentState;
      intent.pendingPlaySongId = -1;
      intent.pendingQueueIndex = target;
      // ★ 必须**显式**写 false：它是壳层"要不要打开播放器"的唯一判据（`if (openUi)`）
      intent.openPlayerUi = false;
      intent.requestVersion++;
      Logger.info(RZD_TAG,
        `play switch index=${target} ${row.source}_${row.songId} (intent v=${intent.requestVersion})`);
      return;
    }
    // 组队列（官方入口）——整份队列 + 下标；★ 第 5 参 `false` = **不打开播放器**（见 §2）
    Logger.info(RZD_TAG, `play index=${target} songs=${songs.length} (playList openPlayer=false)`);
    void OnlinePlayUtil.playList(this.appState, songs, target, this.getUIContext(), false);
  }

  /**
   * 全局队列与屏幕上这一份是不是同一批歌（同长度 + **逐首同 `source_songId`**）。
   *
   * 用它决定"只换当前曲"还是"重新组队列"（见 {@link playAt}）——
   * 要比的是**身份**而不是下标，因为翻页追加/删行之后两份的下标含义可能不同。
   * @param queue 全局播放队列。
   * @returns true = 同一批歌、顺序也一致。
   */
  private queueMatchesFeed(queue: SongItem[]): boolean {
    const total: number = this.feedSource.totalCount();
    if (queue.length !== total) {
      return false;
    }
    for (let i: number = 0; i < total; i++) {
      const row: RecommendPrivateSongUi = this.feedSource.getData(i);
      if (queue[i].source !== row.source || queue[i].songId !== row.songId) {
        return false;
      }
    }
    return true;
  }

  /** 当前这一屏是否就是全局在播的那首（决定播放按钮画"播放"还是"暂停"）。 */
  private isCurrentSong(row: RecommendPrivateSongUi): boolean {
    const item = this.appState.getCurrentSongItem();
    if (item === undefined) {
      return false;
    }
    return item.source === row.source && item.songId === row.songId;
  }

  /**
   * 卡片上的播放/暂停按钮。
   *
   *  · 就是当前这首 ⇒ 走 {@link playerViewModel}`.togglePlayPause()`（**唯一正解**）；
   *  · 不是 ⇒ 走 {@link playAt} 从这首开始放。
   *
   * ★★ **不许只翻 `appState.isPlay`**（那是**显示位**：谁在读它？只有画按钮的那几处 UI。
   *   真正出声/静音的是 `MediaService`）—— 改动前就是这么写的
   *   （`this.appState.isPlay = !this.appState.isPlay`），表现正是用户实测的
   *   「那个暂停和恢复播放按钮**不会生效**」：图标会变、声音一点没动，而且下一次
   *   `MediaService` 回调还会把这个显示位**改回去**。
   * ★ 正解 = 走**播放页那颗主键的同一个入口**
   *   （`ControlAreaComponent.ets:659` → `PlayerViewModel.togglePlayPause()` →
   *   `PlayerDataUtil.togglePlayPause(appState)`，`PlayerDataUtil.ets:88`）：
   *   · `appState.isPlay === true` ⇒ `MediaService.pause()`；
   *   · 否则 ⇒ 引擎还没加载过（`getFirst()`）就先 `loadAsset(selectIndex)`，
   *     加载过才 `MediaService.play()` —— **"引擎首次加载"那条规则自带**，本页不用自己判。
   *   `MediaService.play()` 内部会 `updateIsPlay(true)` 再回写 `appState.isPlay`，
   *   所以按钮图标也会跟着对。
   * ★ 这里**不重开队列、不 `loadAsset` 别的下标** —— 只动"当前这首"的播放状态，
   *   否则进度会被打回 0（与 {@link playAt} 第一条分支同一个理由）。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  private onPlayButton(row: RecommendPrivateSongUi, index: number): void {
    if (this.isCurrentSong(row)) {
      this.playerViewModel.togglePlayPause();
      Logger.info(RZD_TAG, `play toggle via PlayerViewModel -> ${this.appState.isPlay}`);
      return;
    }
    this.playAt(index);
  }

  // ─────────────────────────── 收藏 ───────────────────────────

  /**
   * 收藏门：按 `store.isFavorite(source, songId)` 现算（`@Trace favoriteVersion` 会驱动重绘）。
   * @param row 这一屏的歌。
   * @returns true = 已收藏。
   */
  private isFavorited(row: RecommendPrivateSongUi): boolean {
    if (row.source.length === 0 || row.songId.length === 0) {
      return false;
    }
    // 读一下版本号，确保收藏状态变化被这个组件观察到（`favoriteVersion` 是 `@Trace`）。
    const version: number = this.store.favoriteVersion;
    return version >= 0 && this.store.isFavorite(row.source, row.songId);
  }

  /**
   * 收藏/取消收藏。
   *
   * 走的是工程**现成的那一条**（与 `MusicPlayInfoBlock.toggleFavorite()` 逐字同款口径，
   * 见 `features/player/src/main/ets/view/MusicPlayInfoBlock.ets:170`）：
   * `MusicStoreService.removeFavorite` / `addFavorite(PlayedSongRecord)` ——
   * 不新造收藏通道，也不写别的存储。
   * @param row 这一屏的歌。
   */
  private toggleFavorite(row: RecommendPrivateSongUi): void {
    if (row.source.length === 0 || row.songId.length === 0) {
      this.toast('本地歌曲暂不支持收藏');
      return;
    }
    if (this.store.isFavorite(row.source, row.songId)) {
      this.store.removeFavorite(row.source, row.songId);
      Logger.info(RZD_TAG, `favorite off ${row.source}_${row.songId}`);
      return;
    }
    const record = new PlayedSongRecord();
    record.songId = row.songId;
    record.name = typeof row.title === 'string' ? row.title : '';
    record.singer = typeof row.singer === 'string' ? row.singer : '';
    record.source = row.source;
    record.img = row.coverUrl;
    record.url = '';
    record.lyric = '';
    record.time = Date.now();
    this.store.addFavorite(record);
    Logger.info(RZD_TAG, `favorite on ${row.source}_${row.songId}`);
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  // ─────────────────────────── 交互信号 ───────────────────────────

  /**
   * 换歌到位：记下标 + 补音质标签 + **预取下一页** + **切歌播放**。
   *
   * ★ 触发时机就是这里（`Swiper.onChange`，`component/swiper.d.ts` 的 `Callback<number>` 档）：
   *   滑到**倒数第 {@link FEED_PREFETCH_REMAIN} 首**时请求下一页，让用户滑到底之前
   *   新歌已经进来了 —— 页面永远不会出现"滑不动了才知道没数据"。
   *   并发由 {@link loadMore} 里的 `feedFetching` 闸住（快速连滑只会有一个请求在飞）。
   * ★ **滑到哪就播哪**（用户 2026-10-15 原话）：真正起播的动作在 {@link playAt}
   *   （按"这首歌是不是已在播"去重，所以这里无脑调一次是安全的，不会重复起播）。
   */
  private onFeedChanged(index: number): void {
    this.currentIndex = index;
    const total: number = this.feedSource.totalCount();
    Logger.info(RZD_TAG,
      `swiper -> index=${index} total=${total} page=${this.feedPage} exhausted=${this.feedExhausted} loop=${this.feedLoop}`);
    this.requestQualityAround(index);
    if (total - 1 - index <= FEED_PREFETCH_REMAIN) {
      void this.loadMore();
    }
    this.playAt(index);
  }

  /**
   * 顶栏左侧「三条横线」：**不打开播放页**（用户 2026-10-15 明确「这个页面是不会打开播放器的」）。
   *
   * ⚠️ 这里**故意没有可执行的菜单**：本页能做的事（收藏 / 不感兴趣 / 更多 / 播放暂停）都已经
   *   画在卡片自己的动作行上，再抄一份菜单就是"同一件事两个入口"；而"打开完整播放器"这条路
   *   **被用户明确否掉**了（上一版那颗汉堡就是它，本轮整体移除）。
   *   所以保留成"点一下给一句提示"：**不静默、也不跳转**。
   *   真要给它加行为，正确做法是在这里 `bindMenu`（HDS 顶栏的图标槽位不吃自定义菜单）——
   *   见任务报告里的"未完成/存疑"。
   */
  private onFeedMenu(): void {
    Logger.info(RZD_TAG, `menu tapped index=${this.currentIndex} (no menu: page never opens the player)`);
    this.toast('本页的操作都在卡片上：收藏 / 不感兴趣 / 更多');
  }

  /**
   * 顶栏右侧「分享」：接的正是工程**现成**的那一条分享链路。
   *
   * 与播放页 `TopAreaComponent.ets:51`、专辑页 `AlbumDetailPage.ets:577` 逐字同款：
   *   `showSystemShare(uiContext, buildSongShareText(title, singer, source, songId), '歌曲分享')`
   *   —— 两个函数都从 `player` 的导出面来（`features/player/Index.ets:71`），不新写分享实现。
   * ⚠️ 没有歌可分享（空态/下标越界）时只给一句提示，不弹一个空分享面板。
   */
  private onShareSong(): void {
    const total: number = this.feedSource.totalCount();
    if (total <= 0) {
      this.toast('还没有可以分享的歌');
      return;
    }
    const index: number = this.currentIndex >= 0 && this.currentIndex < total ? this.currentIndex : 0;
    const row: RecommendPrivateSongUi = this.feedSource.getData(index);
    const title: string = typeof row.title === 'string' ? row.title : '';
    const singer: string = typeof row.singer === 'string' ? row.singer : '';
    Logger.info(RZD_TAG, `share song=${row.source}_${row.songId} title=${title}`);
    showSystemShare(this.getUIContext(), buildSongShareText(title, singer, row.source, row.songId), '歌曲分享');
  }

  /**
   * 播放进度 / 当前曲目变化 ⇒ 刷新"歌词两行"。
   *
   * ★ 歌词真源 = `MusicStoreService.getCardLyric()`
   *   （`common/musicbasic/.../MusicStoreService.ets:1393`）：播放链路的
   *   `MediaService.syncCardLyric()` 在**每个进度回调**里把"当前行"写进去
   *   （`features/player/.../MediaService.ets:326/350`），是这个页面能拿到的**唯一**真源。
   * ★ 为什么盯 `progress`：它 500ms 一跳（`MediaService` 的 updateTime 回调），
   *   正好够"换行就换字"；`selectIndex` 用来发现换歌。
   * ⚠️ `getCardLyric()` 不是可观察对象 ⇒ 必须靠这个 `@Monitor` 主动读、写进 `@Local` 才会重绘。
   * ⚠️ 换歌后先"等一个新鲜值"（`lyricAwaitingFresh`）：`syncCardLyric` 在新歌歌词还没加载时
   *   会**直接 return、保留上一首的残留值**（那是播放链路的行为，本页改不了）——
   *   不等一下就会把上一首的最后一行显示在新歌上。
   */
  @Monitor('appState.progress', 'appState.selectIndex')
  onPlaybackTick(): void {
    const song = this.appState.getCurrentSongItem();
    const key: string = song === undefined ? '' : song.source + '|' + song.songId;
    if (key !== this.lyricSongKey) {
      this.lyricSongKey = key;
      this.lyricCurrent = '';
      this.lyricPrevious = '';
      this.lyricAwaitingFresh = true;
      return;
    }
    const line: string = this.store.getCardLyric();
    if (this.lyricAwaitingFresh) {
      if (line.length === 0) {
        return;
      }
      this.lyricAwaitingFresh = false;
      this.lyricPrevious = '';
      this.lyricCurrent = line;
      return;
    }
    if (line === this.lyricCurrent) {
      return;
    }
    this.lyricPrevious = this.lyricCurrent;
    this.lyricCurrent = line;
  }

  /** 平台变了（用户在设置里切了「来源平台」）⇒ 整页换内容。 */
  @Monitor('homeSourceState.source')
  onHomeSourceChanged(): void {
    if (this.loadedSource === this.homeSourceState.source) {
      return;
    }
    Logger.info(RZD_TAG, `source changed -> reload ${this.homeSourceState.source}`);
    this.load();
  }

  /** 账号变了（登录/退出）⇒ 两条通道可能要互换，整页重载。 */
  @Monitor('accountChangedState.version')
  onAccountChanged(): void {
    Logger.info(RZD_TAG, `account changed (v=${this.accountChangedState.version}) -> reload`);
    this.load();
  }

  /** 壳层点了当前页签：回到第一屏。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.feedController.changeIndex(0);
  }

  // ─────────────────────────── 版式 ───────────────────────────

  /** 窗口宽（vp）；窗口尺寸还没量到时用 360（与改动前同一个兜底值）。 */
  private windowWidthVp(): number {
    return this.windowInfo.windowSize.width > 0 ?
      this.getUIContext().px2vp(this.windowInfo.windowSize.width) : 360;
  }

  /** 窗口高（vp）；窗口尺寸还没量到时用 780。 */
  private windowHeightVp(): number {
    return this.windowInfo.windowSize.height > 0 ?
      this.getUIContext().px2vp(this.windowInfo.windowSize.height) : 780;
  }

  /**
   * 封面区顶边在页内的 y（vp）—— 那个居中的封面**实际**从哪儿开始画（**按窗口算，不写死坐标**）。
   *
   * ★ 算术（`FeedCard` 里封面区是居中排的）：
   *   内容盒高 = 窗口高 − 顶部让位（{@link topStackOffsetVp}，卡片 `padding.top` 就是它）
   *     − {@link cardChromeBottomVp}（卡片 `padding.bottom`）；
   *   内容盒内部 = 顶部让位 + 上余量 + `[封面, 歌词, 歌名块, 音质, 动作]` + 下余量，
   *   而居中 ⇒ **上余量 = 下余量**
   *   ⇒ `封面顶边 y = 顶部让位 + (内容盒高 − (封面高 + FEED_CHROME_VP)) / 2`。
   *   （`FEED_CHROME_VP` = "除封面以外那一堆 + 呼吸留白"的预算，见它的常量注释。）
   * ★ 这样算出来落点就是参考图那个位置：360×816 上 ≈ 94 + (638 − 326 − 280)/2 ≈ **110vp**
   *   = "标题栏下沿 + 0.02 × 屏高"（参考图上封面开始的位置）。
   * ⚠️ 两处已知的近似（不影响用途，别拿它当像素级真值）：
   *   ① 预算 `FEED_CHROME_VP` 里带着 ≈ 49vp 呼吸位、而本函数**没减进度行**（那 20vp 是内列的兄弟）
   *      ⇒ 真实落点比本函数大约再低 10~15vp；
   *   ② 歌词组件按需渲染，行高在不同设备上有差异。
   *   本函数现在的唯一消费方是 {@link topScrimHeightVp}（顶部压深到封面顶边为止），
   *   十几 vp 的误差在那儿完全看不出来。
   * @returns 封面顶边 y（vp，从页盒顶部算；页盒从屏幕 y=0 起排）。
   */
  private coverTopVp(): number {
    const contentHeight: number = this.cardContentHeightVp();
    const used: number = this.coverHeightVp() + FEED_CHROME_VP;
    return this.topStackOffsetVp() + Math.max(0, contentHeight - used) / 2;
  }

  /**
   * 卡片内容盒的高度（vp）= 窗口高 − 顶部让位（状态栏 + HDS 标题栏）− 底部让位 + 间距。
   *
   * 与 {@link coverHeightVp} 里那个 `room` 是同一条算式（减去 `FEED_CHROME_VP` 之前的量）。
   */
  private cardContentHeightVp(): number {
    return this.windowHeightVp() - this.topStackOffsetVp() - this.cardChromeBottomVp();
  }

  /**
   * 卡片底部**总共**要让出的高度（vp）—— ①②两处唯一的让位来源。
   *
   * `= bottomReserveVp（壳层下发的底栏让位，唯一来源） + FEED_BOTTOM_GAP_VP（进度条与底栏之间
   *    的可见间距）`。
   * ⚠️ 语义**不变**：这里**只**给壳层那条浮动胶囊底栏让位，**不要**再往里加"迷你播放条"的量
   *    （那半条归壳层，壳层自己会把 `bottomReserveVp` 调成含它的值）。
   * ⚠️ `bottomReserveVp` **只在这里加一次**：{@link FeedCard} 的 `padding.bottom` 与
   *    {@link coverHeightVp} 的可用高度都用本函数 —— 两处各写一遍就是"封面变小 + 进度条上移两档"。
   * @returns 底部让位 + 间距（vp）。
   */
  private cardChromeBottomVp(): number {
    return this.bottomReserveVp + FEED_BOTTOM_GAP_VP;
  }

  /**
   * 封面区**高度**（vp）—— 宽度恒为**窗口宽**（`FeedCover` 里 `.width(FULL_WIDTH)`，满屏贴边）。
   *
   * 算式：`clamp(min(窗口高 × {@link FEED_COVER_RATIO}, 内容盒高 − {@link FEED_CHROME_VP}, 窗口宽),
   *              {@link FEED_COVER_MIN_VP}, 窗口宽)`。
   *
   * · **窗口高 × 0.40** 是设计目标（照参考图量的，见 FEED_COVER_RATIO 的注释）；
   * · **内容盒高 − FEED_CHROME_VP** 是"矮窗口别把动作行顶出屏幕"的安全闸
   *   （内容盒高 = 窗口高 − 顶部让位 − {@link cardChromeBottomVp}）；
   * · **窗口宽** 是宽屏（平板）的保护：封面再高也不该比屏还宽（它是满屏贴边的）。
   * ★ **不含歌词**：歌词组件 `MiniLyricLinesComponent` 自己决定画不画、多高（见 {@link FeedLyric}），
   *   它的高度由 `FEED_CHROME_VP` 里那段呼吸位吸收 —— 这也是本页最需要上机核的一处。
   * @returns 封面区高度（vp）。
   */
  private coverHeightVp(): number {
    const widthVp: number = this.windowWidthVp();
    const room: number = Math.max(0, this.cardContentHeightVp() - FEED_CHROME_VP);
    const byScreen: number = this.windowHeightVp() * FEED_COVER_RATIO;
    const size: number = Math.min(Math.min(byScreen, room), widthVp);
    const floor: number = Math.min(FEED_COVER_MIN_VP, widthVp);
    return Math.max(size, floor);
  }

  /**
   * 顶部压深层的**高度**（vp）= `max({@link FEED_TOP_SCRIM_MIN_VP}, {@link coverTopVp})`。
   *
   * ★ 它就是"把顶栏那两个白图标衬托出来"的那一段：从屏幕顶一路压到**封面顶边**，
   *   α 同时从 0.35 线性收到 0 ⇒ 在封面顶边处正好归零，而封面顶边那一行本身就是页底色
   *   （见 {@link FEED_COVER_TOP_FADE}）⇒ 两段接得没有缝。
   * ★ 按窗口算、不写死：封面高度/比例一改，这一段自动跟着走（不再是一个固定的 180vp）。
   * ★ 它挂在**内容层下面**（见 `build()` 的层序）：封面以下的部分本来就被不透明的封面盖住，
   *   所以"算得略长一点"没有任何副作用。
   * @returns 顶部压深层高度（vp）。
   */
  private topScrimHeightVp(): number {
    return Math.max(FEED_TOP_SCRIM_MIN_VP, this.coverTopVp());
  }

  /**
   * 页内内容整体下移多少（vp）= 状态栏 + HDS 标题栏（{@link PageTopInsetHelper}）。
   *
   * 页根是 `HdsNavDestination` + `ignoreLayoutSafeArea(TOP, BOTTOM)`（页盒从 y=0 起排，
   * 见 `build()`），所以"顶部让位"必须在内容自己身上做。
   */
  private topStackOffsetVp(): number {
    return PageTopInsetHelper.targetContentTopVp();
  }

  /**
   * HDS 标题栏 —— **左三条横线 + 右分享、没有标题文字**。
   *
   * ★ 做法是"用 HDS 自己的两个槽位"，不是另起一条自绘 Row：
   *   · 左侧 = `content.backIcon`（返回图标区域），配 `hideBackButton(false)`
   *     —— HDS 文档原文（`ui-design-hdsnavdestination`）：「**true：隐藏返回键；false：显示返回键**，
   *       默认 false」，官方 `HdsNavDestination` 示例也是 `.titleBar({...}).hideBackButton(false)`；
   *       要用自定义图标就必须让它显示，否则那个槽位整个不渲染。
   *     `HdsNavigationIconOptions.action` 会把默认的"返回上一页"替换成我们的动作（{@link onFeedMenu}）。
   *   · 右侧 = `content.menu.value`（与 `RecommendPage.ets:707` 的写法逐字同款），动作 = {@link onShareSong}。
   *   · `mainTitle` 给空串：参考图**没有标题文字**，但保留这一项可以让标题区域仍然占位、
   *     两个图标仍然分居两端（完全省略 `title` 的话布局由 HDS 内部决定，观感不可控）。
   *
   * ★ **两个按钮都没有背景**：两个槽位的 `backgroundColor` 都给 `info_scrim_top`
   *   （同一枚 `1C1C1E` 的 **α=0** 档）⇒ 只剩图标本体 + HDS 自己那圈点击热区，
   *   没有改动前那枚"圆形底"（用户 ① 的截图对比里明确要去掉）。
   * ★ 图标：
   *   · 左 = `sys.symbol.line_3_horizontal`（本机 `sysResource.js:3783` 核实存在，
   *     与 `line_2_horizontal`/`line_4_horizontal` 同族，就是"三条水平线"）；
   *     原来那枚 `sys.symbol.hamburgers` 是"带框的汉堡"，与官方图不一致。
   *   · 右 = `sys.symbol.share`（`sysResource.js:3617` 核实存在）——分享，
   *     换掉了改动前的 `sys.symbol.arrow_clockwise`（刷新/换一换）。
   *
   * ⚠️ 图标/标题**一律不给 `sys.color.*`**：本页顶上压着封面大图、底下是取色底，
   *   而 `sys.color.*` 跟着系统深浅色翻（日间变近黑 ⇒ 黑图标压深蒙层看不见）。
   *   用播放页那一族"压在图上、两主题同值"的 token。
   * ⚠️ 没有 `bindToScrollable`：那个接口只收 `Array<Scroller>`（`component/nav_destination.d.ts:1213`），
   *   本页控制器是 `SwiperController`，类型对不上 ⇒ 顶栏**没有**"滑过才渐变模糊"，别硬塞。
   */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    // ⚠️ 不能先写一个 `const onImageIcon = {…}` 再复用：ArkTS 禁止无类型对象字面量
    //   （`arkts-no-untyped-obj-literals`）。四个槽位只能各写一份内联字面量
    //   —— 内联时它由接口上下文定型，才合法（`RecommendPage.ets:676-697` 就是这么写的）。
    return {
      // ★ 真机定论（见 `PageTopInsetHelper.avoidLayoutSafeArea` 的注释）：HDS 标题栏容器
      //   本来就在状态栏下沿，true 会让它**再退一个状态栏** ⇒ 标题跑到 76..132。恒为 true 是本工程
      //   `RecommendPage` / `EchoReviewPage` 的现行口径，照抄。
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        // 顶栏背板透明（α=0 的同色 token）——否则会有一条实底压在封面/取色底上
        originalStyle: {
          backgroundStyle: {
            backgroundColor: FEED_TRANSPARENT
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: FEED_TITLE_COLOR
            },
            menuStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            },
            backIconStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: FEED_TRANSPARENT
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: FEED_TITLE_COLOR
            },
            menuStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            },
            backIconStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            }
          }
        },
        // ★ `buildTitleMaterial` 来自 **musicbasic**（`TitleMaterial.ets:23`），
        //   不是 `@kit.UIDesignKit` —— 见文件头 §四.1。
        //   档位与首页共用 `AmbientState.level`（0=跟随系统 / 1 / 2 / 3）。
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          // 参考图顶栏没有标题文字（只占位，保证左右两个图标分居两端）
          mainTitle: '',
          mainTitleSize: TitleSize.TITLE_ML
        },
        backIcon: {
          label: 'feed-menu',
          icon: $r('sys.symbol.line_3_horizontal'),
          isEnabled: true,
          action: (): void => {
            this.onFeedMenu();
          }
        },
        menu: {
          value: [
            {
              content: {
                label: 'share',
                icon: $r('sys.symbol.share'),
                isEnabled: true,
                action: (): void => {
                  this.onShareSong();
                }
              }
            }
          ]
        }
      }
    };
  }

  /** 空态/加载态。 */
  @Builder
  private FeedStatus() {
    Column({ space: 12 }) {
      if (this.feedLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(FEED_TITLE_COLOR)
      } else {
        SymbolGlyph($r('sys.symbol.music_note_circle_fill'))
          .fontSize(40)
          .fontColor([FEED_SINGER_COLOR])
        Text(this.feedHint.length > 0 ? this.feedHint : '暂时没有可以听的歌')
          .fontSize(14)
          .fontColor(FEED_SINGER_COLOR)
          .textAlign(TextAlign.Center)
          .maxLines(3)
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  /**
   * ② 封面区：**满屏贴边（左右 0 内边距）、不圆角**，**上下各自化进页底色**。
   *
   * ★ 三层（自下而上）：
   *   ① `Image`（宽 = 窗口宽、高 = {@link coverHeightVp}，都按窗口算、不写死）；
   *   ② **上渐变**：`[pageTint, 0] → [Color.Transparent, 1]`，只画在封面高
   *      {@link FEED_COVER_TOP_FADE} 那一段里 —— 封面顶边那一行就是页底色；
   *   ③ **下渐变**：`[Color.Transparent, 0] → [pageTint, 1]`，贴在封面下沿往上
   *      {@link FEED_COVER_BOTTOM_FADE} 那一段 —— 封面下沿那一行就是页底色。
   *   两条的端点色都是**页底色** {@link NowPlayingFeedPage.pageTint}，而页底就是同一枚
   *   取色（`build()` 层 ①）⇒ 封面**上下都与背景无缝接上**（用户 ②："封面上下渐变到背景"）。
   * ★ 改动前那条**整屏** `[Transparent,0] → [pageTint, coverGradientStop()]` 的过渡层**已删**：
   *   封面自己会往背景里化，整屏那条是多余的，而且它的色标按"封面顶边/下沿的**估算**位置"算
   *   （估算依赖字体行高）⇒ 实际会把封面整块染色。见文件头 §五。
   * ★ 不做圆角：参考图里封面是通栏铺满的（见 {@link FEED_COVER_RADIUS_VP}）。
   * ★ 两条渐变都是**遮罩**（`hitTestBehavior(None)`）⇒ 不挡点击，封面那一下"点封面=播这首"照旧。
   * ⚠️⚠️ `linearGradient({colors})` 里每个色标的第二个元素是**位置比例 `[0, 1.0]`**，
   *   不是 vp/px（官方原文："设置的值大于 1.0 时按 1.0 处理"）。本文件在这条上踩过一次
   *   （见全局记忆），所以这里两条给的都是 0 / 1 与那两个 0~1 的比例常量，**别再写成 vp**。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  @Builder
  private FeedCover(row: RecommendPrivateSongUi, index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(row.coverUrl.length > 0 ? row.coverUrl : $r('app.media.ic_avatar1'))
        .width(StyleConstants.FULL_WIDTH)
        .height(this.coverHeightVp())
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.ic_avatar1'))
        .draggable(false)
      // 上渐变：封面顶边 = 页底色（与背后的取色底无缝），往下 FEED_COVER_TOP_FADE 之内回到原图
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(this.coverHeightVp() * FEED_COVER_TOP_FADE)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[this.pageTint, 0], [Color.Transparent, 1]]
        })
        .hitTestBehavior(HitTestMode.None)
      // 下渐变：从封面下沿往上 FEED_COVER_BOTTOM_FADE 开始化开，下沿那一行 = 页底色
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(this.coverHeightVp() * FEED_COVER_BOTTOM_FADE)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[Color.Transparent, 0], [this.pageTint, 1]]
        })
        .position({ x: 0, y: this.coverHeightVp() * (1 - FEED_COVER_BOTTOM_FADE) })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(this.coverHeightVp())
    .onClick((): void => {
      this.playAt(index);
    })
  }

  /**
   * ③ 歌词：**直接用播放页现成的「当前行 + 下一行」小歌词组件**
   * （`features/player/.../view/MiniLyricLinesComponent.ets`）。
   *
   * ★ 用户 ① 的那张官方图里，歌词两行在**歌名上方** —— 本页现在也放在歌名上方
   *   （`FeedCard` 里封面之后、歌名之前）。
   * ★ 它是"自取数"组件：`@Local state: MusicAppState` 自己连 AppStorageV2，
   *   行号与两行文本都由 `state.progress` + 当前曲的 `lyricText` 现算出来 ⇒ **本页不给任何入参**，
   *   也**不改它的渲染逻辑**（用户明确"歌词渲染不在范围"）。
   * ★ 对齐：**左对齐**、左右内边距 = {@link FEED_SIDE_PADDING_VP}（与下面的歌名/歌手/音质/
   *   动作/进度**同一列**）—— 参考图里这两行就是左对齐贴着歌名那一列的左沿，
   *   改动前那个"居中收窄（左右 12vp + 居中）"是错的。
   *   组件自己写死了 `.alignItems(HorizontalAlign.Start)` 与每行 `width(FULL_WIDTH)`
   *   ⇒ 这里只把外面这层 `Column` 的对齐与 padding 改掉即可，
   *   **没有碰组件的渲染逻辑**（没改它的文件）。
   *
   * ⚠️ 组件带 `.margin({ top: 2, bottom: -10 })`，高度 ≈ 15 + 14 + 3(space) + 2 − 10 ≈ 24vp
   *   （按"行高 ≈ 字号"估的；真实行高由字体决定，这点差异由 {@link FEED_CHROME_VP} 里
   *   那段呼吸位吸收）。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedLyric(row: RecommendPrivateSongUi) {
    Column() {
      // `ignoreUserSetting: true` ⇒ **无视「设置 → 小歌词」那个开关**强制渲染这两行。
      // ⚠️ 只放宽"画不画"，组件内部的取词/解析/行号逻辑一字未动；
      //   播放页不传这个参数（默认 false）⇒ 它的行为与改动前逐字相同。
      MiniLyricLinesComponent({ ignoreUserSetting: true })
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: FEED_SIDE_PADDING_VP, right: FEED_SIDE_PADDING_VP })
  }

  /**
   * ④ 歌手 + 一枚描边胶囊（**胶囊紧贴在歌手名右边**，与参考图里那枚 VIP 的位置一致）。
   *
   * ⚠️ 参考图那一枚是 **VIP**，但本工程**没有任何"这首歌需要会员"的真实字段**
   *   （`LXSearchSong` / `PlatformTrackInfo` / `LXQualityOption` 都没有 pay/vip 成员；
   *    `grep privilege` 只命中 kg 音质网关里当"可用档位"用的那个字段）——
   *   给每首歌挂一枚 VIP 就是伪造。所以同一个位置放**来源平台**（真实数据，`row.source`）。
   * ★ 歌手名用 `constraintSize({ maxWidth: '70%' })` 限宽而不是 `layoutWeight(1)`：
   *   后者会让名字把整行撑满、把那枚胶囊一路顶到**行的最右边**（参考图里它是紧挨着名字的）。
   *   限宽之后名字过长仍会 `Ellipsis` 截断，不会挤掉胶囊。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedArtist(row: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      Text(row.singer)
        .fontSize(14)
        .fontColor(FEED_SINGER_COLOR)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '70%' })
      Text(this.sourceTagOf(row))
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(FEED_SOFT_COLOR)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .borderRadius(4)
        .borderWidth(1)
        .borderColor(FEED_SOFT_COLOR)
        .backgroundColor(FEED_PILL_BG)
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(VerticalAlign.Center)
  }

  /** 行里的来源平台代号 → 展示名（`row.source` 为空时返回空串 ⇒ 不画那枚胶囊）。 */
  private sourceTagOf(row: RecommendPrivateSongUi): string {
    switch (row.source) {
      case 'tx':
        return 'QQ音乐';
      case 'wy':
        return '网易云';
      case 'kg':
        return '酷狗';
      case 'kw':
        return '酷我';
      case 'mg':
        return '咪咕';
      default:
        return '';
    }
  }

  /**
   * ⑤ 音质标签行（左对齐、描边胶囊）：**查到几枚画几枚**，一枚都没有就整块不显示。
   * ⚠️ 参考图那三枚（`AUDIO Vivid` / `超高清音频` / `空间音频`）是厂商品牌标签，
   *   本工程接口只给得出编码档位（128k / 320k / FLAC / Hi-Res）⇒ 画真实档位，不冒充品牌名。
   * ★ 左右内边距 = {@link FEED_SIDE_PADDING_VP}（与歌词/歌名/动作/进度同一列）。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedQualityRow(row: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      ForEach(this.qualityPills(row), (label: string) => {
        Text(label)
          .fontSize(10)
          .fontColor(FEED_SOFT_COLOR)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(9)
          .borderWidth(1)
          .borderColor(FEED_SOFT_COLOR)
          .backgroundColor(FEED_PILL_BG)
      }, (label: string): string => 'qp-' + this.songKey(row) + '-' + label)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(22)
    .alignItems(VerticalAlign.Center)
    .padding({ left: FEED_SIDE_PADDING_VP, right: FEED_SIDE_PADDING_VP })
  }

  /**
   * ⑥ 动作行：**左** = 红心（+ 收藏数）/ 不感兴趣 / 更多；**最右** = 大号白色圆形播放键。
   *
   * · 红心走本页已接好的 {@link toggleFavorite}（`MusicStoreService` 那一条）；
   *   旁边的数字是**本机收藏总数**（`getFavorites().length`，真实数据）——
   *   参考图那个 `370w+` 是全网热度，工程里没有，不编。
   * · 「不感兴趣」= {@link dislike}（真的把这首从本页摘掉，不是画个图标）；
   * · 「更多」= 工程现成的 `SongMoreMenu`（上一轮已接好，**不许改回没动作**）；
   * · 最右那个大圆键 = {@link onPlayButton}（当前这首走
   *   {@link playerViewModel}`.togglePlayPause()`，否则从这首起播）。
   * ★ 整行左右内边距 = {@link FEED_SIDE_PADDING_VP} ⇒ 最右那颗键的右沿距屏右 20vp
   *   （量参考图 ≈ 19.7vp）；左侧那三枚图标都 24vp（参考图同量级）。
   * ⚠️ 白圆底在**两个主题下都必须是白的** ⇒ 底用 `player_text_primary`（#FFFFFF，两主题同值）、
   *   图标用 `info_scrim_bottom`（#1C1C1E 系，两主题同值）。**不能**用 `font_primary`
   *   （它在夜间是白 ⇒ 白图标压白圆，直接看不见）。
   * ⚠️ 那颗键**仍用 {@link FEED_PLAY_BUTTON_SIZE}（72vp）不改** —— 它与播放页主键同源
   *   （`app.float.image_play_width`），用户要求"照播放页那个做"。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  @Builder
  private FeedActions(row: RecommendPrivateSongUi, index: number) {
    Row() {
      Row({ space: 18 }) {
        Row({ space: 4 }) {
          SymbolGlyph(this.isFavorited(row) ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(24)
            .fontColor([this.isFavorited(row) ? FEED_FAVORITE : FEED_SINGER_COLOR])
            .onClick((): void => {
              this.toggleFavorite(row);
            })
          Text(String(this.favoriteCount()))
            .fontSize(12)
            .fontColor(FEED_SINGER_COLOR)
            .maxLines(1)
        }
        .alignItems(VerticalAlign.Center)

        SymbolGlyph($r('sys.symbol.heart_slash'))
          .fontSize(24)
          .fontColor([FEED_SINGER_COLOR])
          .onClick((): void => {
            this.dislike(row, index);
          })

        // 「更多」= 工程现成的歌曲菜单（播放/下载/加歌单/加收藏/加队列/查看评论）
        SongMoreMenu({
          song: this.toLxSong(row),
          iconSize: 24,
          iconColor: FEED_SINGER_COLOR
        })
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      // ── 最右：**播放页同款**的主播放/暂停键（用户 ⑥："照播放页那个主播放/暂停按钮做"）──
      // ★ 逐条对齐 `ControlAreaComponent.ets:648-661`（播放页主控区那颗）：
      //   · 图标 = `app.media.ic_public_play` / `app.media.ic_public_pause`
      //     ⚠️ **名字与图形是反的**（本工程既有口径，别"修正"）：`ic_public_play` 画的是**两条竖线**（暂停）、
      //       `ic_public_pause` 画的是**三角形**（播放）—— 所以正在播时给 `ic_public_play`。
      //   · 尺寸 = `$r('app.float.image_play_width')`（`float.json:96`，**72vp**；
      //     `_lg` 档 88vp 只在宽屏用，本页按 `FEED_PLAY_BUTTON_VP` 固定即可）。
      //   · 按压态 = `@Extend(Image) controlImageBuilder()` 那三条：
      //     `aspectRatio(1)` + `objectFit(Contain)` + **`opacity(0.86)`**（同 `ControlAreaComponent.ets:983-988`）。
      //   · 它自己就带白圆底（SVG 里的白色圆形路径）⇒ **不再另画 `Circle`**，
      //     所以改动前那个"纯白圆 + 另一个图标"的组合整体删掉了。
      //   行为 = 本页的 {@link onPlayButton}（当前这首走 `PlayerViewModel.togglePlayPause()`，
      //   否则从这首起播）。
      Image(this.isCurrentSong(row) && this.appState.isPlay ?
        $r('app.media.ic_public_play') : $r('app.media.ic_public_pause'))
        .width(FEED_PLAY_BUTTON_SIZE)
        .height(FEED_PLAY_BUTTON_SIZE)
        .aspectRatio(1)
        .objectFit(ImageFit.Contain)
        .opacity(FEED_PLAY_BUTTON_OPACITY)
        .draggable(false)
        .accessibilityText(this.isCurrentSong(row) && this.appState.isPlay ? '暂停' : '播放')
        .accessibilityLevel('yes')
        .onClick((): void => {
          this.onPlayButton(row, index);
        })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(FEED_ACTIONS_ROW_VP)
    .alignItems(VerticalAlign.Center)
    .padding({ left: FEED_SIDE_PADDING_VP, right: FEED_SIDE_PADDING_VP })
  }

  /**
   * 本机收藏总数（红心旁边那个数字；真实数据，不是全网热度）。
   * ⚠️ 只读缓存字段 —— 缓存怎么维护见 `favoriteTotal` 与 {@link onFavoriteChanged}。
   */
  private favoriteCount(): number {
    return this.favoriteTotal;
  }

  /**
   * ⑦ 细进度条 + 两端时间（**一行**：左当前时间 / 中间细条 / 右总时长）。
   *
   * · 正在播的那一屏：左端 = `MusicAppState.currentTime`，右端 = `totalTime`，
   *   已播比例 = `progress / progressMax`（**同一个真源**给播放页用的那两个值）；
   * · 其它屏：左端 `00:00`，右端 = 这首歌源数据自带的 `interval`（取不到就 `--:--`），
   *   已播比例为 0 —— 不是"进度丢了"，而是"这首没在播"。
   * ★ 字号 12fp（参考图两端时间 ≈ 12fp 量级）、条厚 3vp、圆角 2vp；
   *   左右内边距 = {@link FEED_SIDE_PADDING_VP}（与上面各行同一列，参考图量得 ≈ 19.3vp）。
   * ★ 它下面紧接的就是 {@link cardChromeBottomVp}（底栏让位 + {@link FEED_BOTTOM_GAP_VP} 间距）
   *   ⇒ 视觉上正好贴在壳层那条胶囊底栏的上方。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedProgress(row: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      Text(this.isCurrentSong(row) ? this.appState.currentTime : '00:00')
        .fontSize(12)
        .fontColor(FEED_SOFT_COLOR)

      Row() {
        Column()
          .width(this.playedPercentOf(row))
          .height(3)
          .borderRadius(2)
          .backgroundColor(FEED_TRACK_PLAYED)
      }
      .layoutWeight(1)
      .height(3)
      .borderRadius(2)
      .backgroundColor(FEED_TRACK)

      Text(this.durationOf(row))
        .fontSize(12)
        .fontColor(FEED_SOFT_COLOR)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(20)
    .alignItems(VerticalAlign.Center)
    .padding({ left: FEED_SIDE_PADDING_VP, right: FEED_SIDE_PADDING_VP })
  }

  /** 这一屏右端的"总时长"文案。 */
  private durationOf(row: RecommendPrivateSongUi): string {
    if (this.isCurrentSong(row) && this.appState.totalTime.length > 0) {
      return this.appState.totalTime;
    }
    const interval: string | undefined = this.feedDurations.get(this.songKey(row));
    return interval !== undefined && interval.length > 0 ? interval : '--:--';
  }

  /** 这一屏已播部分的宽度（百分比字符串；只有正在播的那一屏会 > 0）。 */
  private playedPercentOf(row: RecommendPrivateSongUi): string {
    if (!this.isCurrentSong(row)) {
      return '0%';
    }
    const max: number = this.appState.progressMax;
    const current: number = this.appState.progress;
    if (max <= 0 || current <= 0) {
      return '0%';
    }
    const ratio: number = current >= max ? 1 : current / max;
    return Math.round(ratio * 100) + '%';
  }

  /**
   * 一屏卡片 = 参考图自上而下的那一整列。
   *
   * ⚠️ 整块自己带 `padding.bottom = bottomReserveVp + FEED_BOTTOM_GAP_VP`（{@link cardChromeBottomVp}）——
   *    **不能**把它加在外层容器上，否则滑动的每一屏都对不齐底栏；
   *    **也不能**在别处再叠一次（{@link coverHeightVp} 读的是同一个函数）。
   * ★ 顶部 `padding.top = ` 顶部让位（{@link topStackOffsetVp} = 状态栏 + HDS 标题栏）：
   *    本页是沉浸页（`ignoreLayoutSafeArea(TOP)`，页盒从 y=0 起排），顶部让位必须在**卡片自己**身上做，
   *    否则"封面以下那一整块居中"会把封面顶到标题栏底下（让位白算）。这样封面顶边就落在
   *    "标题栏下沿 + 0.02 × 屏高"（参考图的位置，见 {@link coverTopVp}）。
   * ⚠️ **卡片根节点没有左右 padding**：封面必须满屏贴边（用户 ②："封面铺满"），
   *    左右 20vp 挂在**歌词/歌名/歌手/音质/动作/进度那些行自己**身上
   *    （{@link FEED_SIDE_PADDING_VP}）。
   * ⚠️ 卡片自己**不画背景**：整页的底色由 {@link build} 的层 ① 负责（取色纯色）。
   * @param row 这一屏的歌。
   * @param index 这一屏在队列里的下标。
   */
  @Builder
  private FeedCard(row: RecommendPrivateSongUi, index: number) {
    Column({ space: 0 }) {
      Column({ space: 14 }) {
        // ② 封面区（满屏贴边、不圆角、上下都化进页底色）
        this.FeedCover(row, index)
        // ③ 小歌词（当前行 + 下一行，在**歌名上方**，与歌名同一左内边距）
        this.FeedLyric(row)
        // ④ 歌名（左对齐、粗体）+ 歌手 / 平台胶囊
        Column({ space: 6 }) {
          Text(row.title)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(FEED_TITLE_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(StyleConstants.FULL_WIDTH)
            .textAlign(TextAlign.Start)
          this.FeedArtist(row)
        }
        .width(StyleConstants.FULL_WIDTH)
        .alignItems(HorizontalAlign.Start)
        // 左右边距挂在这一块上（歌名 + 歌手行都在里面），封面不受影响
        .padding({ left: FEED_SIDE_PADDING_VP, right: FEED_SIDE_PADDING_VP })
        // ⑤ 音质标签行
        this.FeedQualityRow(row)
        // ⑥ 动作行（最右是播放页同款的主播放/暂停键）
        this.FeedActions(row, index)
      }
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // ⑦ 细进度条 + 两端时间 —— 它下面那一档就是 `cardChromeBottomVp()`（底栏 + 间距），
      //    所以进度条**整体明显在底栏之上**（用户 ① 的要求）。
      this.FeedProgress(row)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // ★ 顶部让位（沉浸页：页盒从 y=0 起排，让位在卡片自己身上做）
    // ★ 底部给壳层浮动底栏让位 + 留出可见间距（见文件头与常量注释）
    // ⚠️ 左右**没有** padding（封面要满屏贴边）；`bottomReserveVp` 的语义不变 —— 只给壳层那条
    //    胶囊底栏让位，**不要**再往里加"迷你播放条"的量（那半条归壳层）。
    .padding({ top: this.topStackOffsetVp(), bottom: this.cardChromeBottomVp() })
  }

  build() {
    // 页根与 `RecommendPage` / `EchoReviewPage` 同款：HdsNavDestination + MINI 标题栏 +
    // ignoreLayoutSafeArea(TOP, BOTTOM)（页盒从 y=0 起排 ⇒ 背景层可以一直铺到状态栏后面）。
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // ── 层 1：**取色背景**（用户 ②：背景按封面动态取色）────────────────────
        // `pageTint` = 当前这一屏封面的主色经 `ColorConversion.dealColor` 压暗
        // （见 {@link extractCardColor}，与歌手页 / 专辑页 / 播放页同一套口径）；
        // 取色完成前是 {@link FEED_BASE_NEUTRAL}（由**已有 token** 算出来的中性深色兜底）。
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .backgroundColor(this.pageTint)
          .hitTestBehavior(HitTestMode.None)
        // ── 层 2：顶部压深（顶栏那两个白色图标压在浅色/花哨的封面上会读不清）──────
        // · 只压最上面一段（α 从 0.35 渐隐到 0），**高度按窗口算 = 一直到封面顶边为止**
        //   （{@link topScrimHeightVp} = max(FEED_TOP_SCRIM_MIN_VP, coverTopVp())）：
        //   压深收到 0 的那一刻正好是封面顶边，而封面顶边那一行本身就是页底色
        //   （封面自带的上渐变，见 {@link FeedCover}）⇒ 两段接得**没有缝**。
        // · ⚠️ 它**在内容层下面**：封面以下的部分被不透明的封面盖住，所以"算长一点"没有副作用。
        // · ⚠️ 改动前那一层是"整屏压到深色"，会把层 1 的取色整个盖掉 ⇒ 取色就白做了；别改回去。
        // · 色标是**比例**（0 → 1），不是 vp（见 {@link FeedCover} 的同一条警示）。
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(this.topScrimHeightVp())
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [FEED_SCRIM_TOP, 0],
              [Color.Transparent, 1]
            ]
          })
          .hitTestBehavior(HitTestMode.None)

        // ── 层 3：内容 ────────────────────────────────────────────────
        // ⚠️ 改动前这里还有两层，**都已删掉**（用户 ② 明确"背景不该是模糊的"）：
        //   · 层"整屏模糊封面"（`Image(...).blur(11vp).opacity(0.55)`）；
        //   · 层"整屏 `[Transparent, 0] → [pageTint, coverGradientStop()]` 过渡层"。
        //   "图片 → 背景"的过渡现在由**封面自己那两条渐变**负责（见 {@link FeedCover}）。
        Column() {
          if (this.feedRevision >= 0 && this.feedSource.totalCount() > 0) {
            // ★ 竖向 Swiper = "一屏一首、上下滑换歌"：
            //   · `.vertical(true)`（`component/swiper.d.ts:1790`）—— 竖向整页吸附；
            //   · `.indicator(false)`（:1666，`boolean` 档）—— 不要圆点（一屏一首时圆点没意义）；
            //   · `.cachedCount(1, true)`（:1910）—— 前后各缓存一屏，滑动不掉帧；
            //   · `.loop(this.feedLoop)`（:1731）—— **到底之后**打开 ⇒ 滑不到空白（见 syncLoop）；
            //   · `.nestedScroll(SELF_ONLY)`（:2412 / enum :1384）—— 竖向滚动自己消费，
            //     不把壳层那条"上拉打开播放页"的手势搅进来；
            //   · `.onChange((i: number) => …)`（:2132，`Callback<number>` 档）。
            //   ⚠️ 不用 `List` + 吸附：`List` 的吸附接口叫 `scrollSnapAlign(ScrollSnapAlign)`
            //     （`component/list.d.ts:1925`），而工程里见过的 `scrollSnap({…})` 是 **`Scroll`** 的
            //     属性（`component/scroll.d.ts:1875`）—— 照抄到 `List` 上直接编译错。
            Swiper(this.feedController) {
              // `LazyForEach` **直挂** `Swiper`（中间不套容器），key 稳定 ⇒ 复用正确。
              // ⚠️ key **不含下标**（翻页追加时下标会变，key 一变就要重建节点、丢掉滑动位置）。
              LazyForEach(this.feedSource, (row: RecommendPrivateSongUi) => {
                this.FeedCard(row, this.feedSource.indexOf(row))
              }, (row: RecommendPrivateSongUi): string => this.feedKey(row))
            }
            .vertical(true)
            .indicator(false)
            .cachedCount(1, true)
            .loop(this.feedLoop)
            .duration(280)
            .effectMode(EdgeEffect.Spring)
            .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
            .width(StyleConstants.FULL_WIDTH)
            .layoutWeight(1)
            .onChange((index: number): void => {
              this.onFeedChanged(index);
            })
          } else {
            this.FeedStatus()
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideTitleBar(false)
    // ★ 参考图的左汉堡就挂在 HDS 的"返回图标区域"上 ⇒ 必须显示返回键（HDS 文档原文：
    //   true 才隐藏）。见 getTitleBar() 的注释。
    .hideBackButton(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    // 内容让位靠**每张卡片自己**算（`FeedCard` 的 `padding.top = topStackOffsetVp()`，
    // `coverHeightVp` 也用同一个值），所以这里不再额外 padding ——
    // 一屏一首的页，留白加在外层会让"整屏"对不齐，而且封面就不能铺到屏幕左右边了。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(FEED_PAGE_BG)
  }

  /**
   * **当前这一屏**那张封面（空串 = 没有可用封面）。
   *
   * ⚠️ 现在唯一的消费方是 {@link refreshCardColor}（取色）—— 改动前它还给"整屏模糊封面"那一层
   *   供图，那一层已按用户要求删除（见文件头 §五）。
   */
  private currentCoverUrl(): string {
    const total: number = this.feedSource.totalCount();
    if (total <= 0) {
      return '';
    }
    const index: number = this.currentIndex >= 0 && this.currentIndex < total ? this.currentIndex : 0;
    return this.feedSource.getData(index).coverUrl;
  }

  // ─────────────────────────── 背景：封面取色 ───────────────────────────

  /**
   * 当前这一屏的封面换了就取一次色（见 `@Monitor('currentIndex')` 与 `aboutToAppear`）。
   *
   * 去重判据是**封面地址**而不是下标：翻页追加 / 删行之后同一个下标可能是另一首歌，
   * 而同一张封面无论在哪个下标都只需要取一次。
   */
  private refreshCardColor(): void {
    const url: string = this.currentCoverUrl();
    if (url.length === 0 || url === this.lastTintUrl) {
      return;
    }
    this.lastTintUrl = url;
    void this.extractCardColor(url);
  }

  /**
   * 下载封面 → 解码 → 取主色 → 写成页底色。
   *
   * ★★ **一行新算法都没有**，整条链路与歌手页 `ArtistDetailPage.loadBackdropColor()`
   *    （`features/setting/.../ArtistDetailPage.ets:293`）逐条同款：
   *      ① `http.createHttp().request(url, { expectDataType: ARRAY_BUFFER })` 下封面字节；
   *      ② `image.createImageSource(buffer)` → `createPixelMap()`；
   *      ③ `effectKit.createColorPicker(pixelMap, cb)` → `getLargestProportionColor()`；
   *      ④ `ColorConversion.dealColor(r,g,b)` 压暗 → {@link feedTintOf} → `.backgroundColor()`。
   * 资源释放（`pixelMap.release` / `src.release` / `req.destroy`）也与那一份一致 ——
   * 本页**每次翻屏都会走一次**，漏一个 release 就是一路泄漏。
   *
   * ⚠️ 过期结果必须丢掉：快速连滑会同时有几条在飞，靠 {@link cardColorJobSeq} 代次判断
   *   （与播放页 `imageColorJobSeq` 同一套做法）；失败**不改颜色**，保留上一个色/兜底色。
   * @param url 封面地址。
   */
  private async extractCardColor(url: string): Promise<void> {
    const jobSeq: number = ++this.cardColorJobSeq;
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 15000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        Logger.warn(RZD_TAG, `tint skip http=${resp.responseCode} url=${url}`);
        return;
      }
      const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        const pixelMap: image.PixelMap = await src.createPixelMap();
        try {
          await new Promise<void>((resolve: () => void) => {
            effectKit.createColorPicker(pixelMap,
              (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
                try {
                  if (error === undefined && colorPicker !== undefined) {
                    const color: effectKit.Color = colorPicker.getLargestProportionColor();
                    const tint: string = feedTintOf(color.red, color.green, color.blue);
                    if (this.feedAlive && jobSeq === this.cardColorJobSeq) {
                      this.pageTint = tint;
                      Logger.info(RZD_TAG, `tint ${tint} url=${url}`);
                    }
                  }
                } finally {
                  resolve();
                }
              });
          });
        } finally {
          try {
            pixelMap.release();
          } catch (_err) {
            // 释放失败无所谓：这只是一张临时位图
          }
        }
      } finally {
        src.release();
      }
    } catch (err) {
      const e = err as BusinessError;
      // 取色失败不影响播放 —— 保留上一个色（或兜底色）
      Logger.warn(RZD_TAG, `tint failed code=${e.code} msg=${e.message} url=${url}`);
    } finally {
      req.destroy();
    }
  }

  /**
   * 列表项稳定 key。
   *
   * ⚠️ 必须**不含下标**（用下标当 key 会让"翻页追加 / 删掉一首"之后的复用整体错位，
   *    用户手上的滑动位置也会跟着跳）；`source_songId` 是天然唯一键；
   *    `coverUrl` 拼在末尾是为了"封面异步补进来之后这一屏重绘一次"
   *    （同 `HeroSongListCard.rowKey` 的口径）。**去重也用同一个 `source|songId` 口径**。
   * @param row 这一屏的歌。
   * @returns 稳定 key。
   */
  private feedKey(row: RecommendPrivateSongUi): string {
    return 'feed-' + row.source + '_' + row.songId + '-' + row.coverUrl;
  }
}
