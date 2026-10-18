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
import {
  AmbientState, AppStorageKeys, areaLengthToVp, getWindowInfoState, ImmersiveType, Logger, MINI_BAR_ID,
  PlayerExpandState, StyleConstants, WindowInfo
} from 'musicbasic';
import { MusicAppState, PlayerViewModel } from 'player';
import { HomeMiniBarAlbumCover } from './HomeMiniBarAlbumCover';
import { HomeMiniBarPlayerAside } from './HomeMiniBarPlayerAside';

/**
 * Mini player shell: album cover with shared-element id, aside controls, padding by expand state,
 * vertical pan to full screen.
 */
@ComponentV2
export struct HomeMiniBarPlayer {
  /**
   * 鑳跺泭**棰濆**鍐嶆敹杩涙潵鐨勫乏鍙宠浣嶏紙vp锛夈€?
   *
   * 鏃犵晫 `topPageSideOf()` 鎵嬫満妗ｆ槸 **16**锛堝綊妗?`璁捐甯搁噺鍏ㄨВ绠?md`锛夛紝浣嗛偅鏄?*椤甸潰绾?*璁╀綅锛?
   * 鑰屾垜浠殑鑳跺泭宸茬粡鍧愬湪 HDS 椤电鏍忛噷锛堥偅涓€灞傝嚜甯﹀乏鍙宠浣嶏級鈬?鐩存帴鍔?16 浼?*鍙犲姞鎴?~26vp**锛?
   * 鐢ㄦ埛瀹炴祴銆屾挱鏀炬潯鐭ソ澶氥€嶃€?
   * 鈬?杩欓噷鍙ˉ 8锛堚増 16 鐨勪竴鍗婏級锛岃**鎬?*瑙嗚璁╀綅钀藉洖 16 闄勮繎锛岃兌鍥婂搴﹀洖鍒版甯搞€?
   * 鈿狅笍 鏀硅繖涓暟鍙湅"鑳跺泭宸﹀彸鍒板睆骞曡竟鐨勬€昏窛绂?锛屼笉瑕佸啀鍙犲姞鍒?16 鈥斺€?16 鏄〉闈㈢骇鍙ｅ緞锛屼笉鏄繖涓€灞傘€?
   */
  private static readonly MINI_BAR_SIDE_VP: number = 0;
  /**
   * 内容行（`Row`）的**上下内距**（vp）——本组件自然高度的唯一"额外厚度"。
   *
   * ★★★ 2026-10-20（用户：「首页是高度低调的播放条，你咋改成大的了」）：
   *   本组件的**自然高度 = 封面边长 + 2 × 本值**：
   *     · 双层底栏 · 上下两排（`hdsBarLayoutMode === VERTICAL`）：封面 30 ⇒ **46vp**
   *     · 沉浸式自由窗口：封面 40 ⇒ **56vp**
   *     · 单排 · 展开（`miniBarExpanded`）：封面 44 ⇒ **60vp**
   *     · 单排 · 折叠：封面 56 ⇒ **72vp**
   * ★★★ 2026-10-20（第五轮，用户：「首页播放条和二级页面不是一个」）：**本值只决定内容的自然高**，
   *   **不再**决定胶囊高 —— 两条宿主的胶囊高都是 `Index.FLOATING_MINI_BAR_HEIGHT_VP`(56) 这个常量。
   *   自然高 = 封面边长 + 2 × 本值：两排（封面 30）⇒ 46 / 沉浸（40）⇒ 56 / 单排（44）⇒ 60。
   *   宿主用 `contentHeightVp` 把行**钉在** 56 上（`constraintSize.maxHeight` + 根 Stack 居中），
   *   ⇒ 46 的那一档内容在胶囊里上下各留 5vp（"低调"），60 的那一档超出 2vp/边（与二级页同款）。
   *   ⚠️ 改这个数必须同时改 `products/default/.../Index.ets` 的 `HOME_MINI_BAR_CONTENT_PAD_VP`。
   */
  private static readonly CONTENT_PAD_VP: number = 8;
  /** 胶囊**内部**组件再收进来的左右呼吸（vp）—— 用户要求"组件离播放条两侧远一点"。 */
  private static readonly MINI_BAR_INNER_PAD_VP: number = 4;
  /**
   * `contentHeightVp === 0`（不钉高度）时喂给 `constraintSize.maxHeight` 的"无上限"。
   *
   * ArkTS 里没有 `undefined`/`Infinity` 这种"不约束"的写法（`height()` 只吃 `Length`），
   * 而 `maxHeight` 只要**大于自然高度**就等于没约束；4096vp 既远大于任何迷你条高度，
   * 又不会在 px 换算里溢出。
   */
  private static readonly CONTENT_HEIGHT_UNBOUNDED_VP: number = 4096;
  /** Player VM shared with cover and aside. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Global music UI state (mini bar expanded, play state). */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /**
   * 鏁撮〉褰㈠彉鐘舵€侊細鍙敤鏉ヨ"杩蜂綘鏉¤娣″埌澶氬皯"锛堝鏍囨棤鐣?`MiniMorph.alpha = 1 - p/0.20`锛夈€?
   *
   * 涓轰粈涔堣糠浣犳潯瑕佽浣嶏細鎾斁椤甸偅鏉″彲瑙嗙煩褰㈡槸浠?*杩蜂綘鏉″皝闈?*鐨勪綅缃暱鍑烘潵鐨勶紝
   * 鍓?20% 鍙湁灏侀潰鐨勪竴涓ゅ€嶅锛岃€屾暣鏉¤糠浣犳潯锛堝皝闈?+ 姝屽悕 + 鎸夐挳锛夋湁 300 澶?vp 鈥斺€?
   * 涓嶈浣嶅氨鏄?涓€鏉¤糠浣犳潯鍙宠竟绐滃嚭涓柟鍧?锛屼笉鏄棤鐣岄偅绉?鎾斁鏉￠€愭笎鍙樺ぇ"銆?
   * 闈欐鎬佸畠鎭掕繑鍥?1锛屾墍浠ヤ笉灞曞紑鏃堕€愬儚绱犱笉鍙樸€?
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /** Passed through to {@link HomeMiniBarPlayerAside} to toggle previous-track visibility. */
  @Param showPreviousTrack: boolean = false;
  /**
   * When false, row padding ignores global expand (list-style inset).
   * Cover image sizing is adjusted in HomeMiniBarAlbumCover.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /**
   * 閿佸畾灏侀潰涓?44vp锛堝崟鎺掓姌鍙犳€侊級銆備簩绾ч〉闈㈡偓娴兌鍥婂湪澶栧眰鍥哄畾浜?56vp 楂樺害锛?
   * 灏侀潰蹇呴』璺熺潃鍥哄畾锛屽惁鍒?HDS 鏍忔帓甯冨彉鍖栦細鎶婂皝闈㈢缉鍒?30vp銆?
   */
  @Param lockTwoRowCoverSize: boolean = false;
  /**
   * 是否由本组件自绘背板（{@link MiniBarBackplate}）。
   *
   * - `false`（**两个 HDS 宿主都传这个**）：首页那条（`Index.miniBar()`，底栏 `barFloatingStyle.miniBar`
   *   + `enableMiniBarBackground: true`）与二级页那条（`Index.floatingMiniBar()`，HDS 浮动底栏 +
   *   `systemMaterialEffect`）—— 胶囊与材质**都由 HDS 画**。这里再自绘一层就是
   *   「官方材质 + 半透明蒙版 + 模糊」叠两层，材质被洗白（2026-10-18 用户要的「沉浸光感」就看不出来了）。
   *   首页那条 2026-10-18 晚起也走这一支：用户明确要"光感"，代价是关闭播放器时**背板**不再跟着
   *   `morphSquashY` 压/弹（内容仍然一起压，`.scale` 挂在同时包含内容的根 `Stack` 上）。
   * - `true`（默认，**只剩**推荐页 `HomeFloatingMiniBar` / 歌单页 `PlaylistFloatingMiniBar` 这两个自绘胶囊宿主）：
   *   它们没有 HDS 底栏材质可接，背板必须自己画，否则整条是透明的。
   */
  /**
   * ★★★ 2026-10-20（第三轮，用户：「看看无界，它有光感又有弹一下」）——**背板到底谁画，本轮的判据**：
   *
   * 无界的迷你条背板**从来不是 MiniPlayer 自己画的**，它有两个来源，字节码逐条核过：
   *   · 首页那条：`MainPage.#miniBar`（`wujie.pa:148147-148177`）= `__Common__() { MiniPlayer(...) }`，
   *     **没有任何背板节点**；背板来自宿主 `HdsTabs` 的 `miniBar` 槽
   *     （`MainPage` 的 `miniBarCfg`（:143286-143289）**没写** `enableMiniBarBackground` ⇒ 取 SDK 缺省 `true`）。
   *   · 关闭播放器时那记"弹一下"：来源是形变浮层里的 **`morphGlass` 克隆**（`MainPage.morphGlass`，
   *     `wujie.pa:155701-155766`）= 一个 `MaterialCapsule`（我们子树里的 `HdsTabs` + 官方材质）
   *     被父级 `.scale({y: morphSquashY})` 压。
   * ⇒ 结论（本轮落地口径）：
   *   · **自绘背板（`true`）只在"没有 HDS 底栏可接"的宿主上保留**（推荐页 `HomeFloatingMiniBar`、
   *     歌单页 `PlaylistFloatingMiniBar`，它们没有官方材质可挂，只能自己画）；
   *   · 首页那条 / 二级页那条一律 `false`（背板/材质由 HDS 浮动栏画，见 {@link MiniBarMaterialCapsule}）；
   *   · "弹一下"由**形变克隆层**（壳层 `MiniBarGlassClone` + 三份克隆一起 `.scale({y: morphSquashY})`）
   *     负责，而不是靠本体背板 —— 这与无界把挤压挂在 `morphGlass` 克隆上是同一件事。
   */
  @Param showSelfDrawnBackplate: boolean = true;
  /**
   * 本组件根 `Stack` 是否**自己**承担挤压（`.scale({y: morphSquashY})`）。
   *
   * - `true`（缺省 = 推荐页 / 歌单页那两个自绘胶囊宿主，以及首页 HDS `miniBar` 槽里那条）：
   *   `.scale` 挂在根 `Stack` 上 ⇒ 自绘背板与内容一起压/弹。
   * - `false`（**住进 {@link MiniBarMaterialCapsule} 的宿主必须传**）：挤压由胶囊那层的 `.scale`
   *   统一负责（它压在"官方材质背板 + 内容"同一个变换域上）。这里若再压一次，
   *   两个 0.86 相乘 = **0.74**，会压过头（这是"一改就弹得太狠"的机械判据）。
   */
  @Param contentOwnsSquash: boolean = true;
  /**
   * 把本组件的**高度钉死**成宿主给的设计高度（vp）；`0`（默认）= 不钉，按自然高度排。
   *
   * 自然高度 = 封面边长 + 2 × {@link CONTENT_PAD_VP}(8)：
   *   两排 30 ⇒ **46** / 沉浸自由窗口 40 ⇒ **56** / 单排展开 44 ⇒ **60** / 单排折叠 56 ⇒ **72**。
   * 二级页那条要钉在 `FLOATING_MINI_BAR_HEIGHT_VP`(56)：本组件用 `constraintSize.maxHeight` 钉住，
   * 并靠根 `Stack` 的 `alignContent: Center` 让内容**居中** ⇒ 上下留白恒等。
   * 2026-10-20 起**内容行（`Row`）自己也吃同一个上限**：非沉浸档位行自然高 60 > 56，
   * 不钉就是"子件比容器大"（排布交给引擎兜底，2vp 向下偏差的候选来源）。
   *
   * ⚠️ 2026-10-20（第五轮）：**首页那条也要传 56**（`Index.FLOATING_MINI_BAR_HEIGHT_VP`），
   *   与二级页**同一个常量、同一个上限** —— 用户「首页播放条和二级页面不是一个」就是上一版
   *   首页不钉高度（46/56/60/72 随封面档位变）、二级页钉 56 造成的。
   *   推荐页 / 歌单页（`HomeFloatingMiniBar` / `PlaylistFloatingMiniBar`，自绘胶囊宿主）**不传**：
   *   那两条的胶囊本身就是按内容自然高画的，钉住反而会切开自绘背板。
   */
  @Param contentHeightVp: number = 0;
  /** 涓婃媺鎵撳紑鎾斁椤碉紙璺熸墜锛夛細椹卞姩鍏变韩褰㈠彉杩涘害锛屾敹灏捐ˉ闂翠氦缁欏３灞傘€?*/
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /**
   * 璇婃柇闂革細鏈疆鎵嬪娍鏄惁**宸茬粡璁拌繃涓€娆?*"璺熸墜鏇存柊琚垽鎹嫆鎺?銆?
   *
   * 鈿狅笍 **涓夋潯璺熸墜閾撅紙澹冲眰 `Index` + `MiniBarPlayer` + 鏈枃浠讹級蹇呴』閮芥湁杩欎竴涓瓧娈?*
   * 鈥斺€?涓婃媺璧锋墜鐐归€氬父鍦ㄨ糠浣犳潯涓婏紝鎵€浠?鐢ㄦ埛鍦ㄩ椤佃糠浣犳潯涓?drag"璧扮殑灏辨槸鏈枃浠惰繖鏉℃墜鍔裤€?
   * 灏戞帴涓€澶勶紝寰芥爣绗崄琛岀殑 `pd=` 灏变細鎭掍负 `0/0/0`锛屾妸"鍒ゆ嵁鎷掍簡"璇垽鎴?浜嬩欢娌″埌"
   * 锛堛€屽悓涓€褰㈢姸 N 澶勩€佸彧鏀逛簡涓€澶勩€嶉偅涓€佹瘺鐥咃級銆?
   * 璇箟涓庣敤娉曡 `PlayerExpandState.pullDropBegin`锛沗onActionStart` 閲屾竻闆躲€?
   */
  private pullDropCountedThisGesture: boolean = false;

  /** 绐楀彛瑁呴グ鐘舵€侊細鍐冲畾鑳屾澘鐢ㄥ摢涓€妗ｅ簳鑹诧紙涓?{@link PlaylistFloatingMiniBar} 鍚屼竴濂?token锛夈€?*/
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 鐜鍏夋。浣嶏細鍐冲畾鑳屾澘鐨勬ā绯婂己搴︼紙涓庨椤靛簳鏍忔潗璐ㄥ悓妗ｏ級銆?*/
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;

  /**
   * 涓婃媺璧锋墜鍚庤ˉ閲忕粓鐐归敋鐐圭殑閲嶈瘯娆℃暟 / 闂撮殧锛坢s锛夈€?
   *
   * 涓?`PlaybackPage` 鐨?12 脳 32ms 鏄悓涓€涓獥鍙ｏ紙瀵规爣鍙嶇紪璇?`schedulePublishRetry`锛夛細
   * 鎾斁椤垫槸璧锋墜閭ｄ竴鍒绘墠鎸傝浇鐨勶紝"瀹冪殑澶у皝闈粈涔堟椂鍊欏彲閲?鍙栧喅浜庡竷灞€甯ф暟銆?
   */
  private static readonly PULL_ANCHOR_RETRY_MAX: number = 12;
  private static readonly PULL_ANCHOR_RETRY_MS: number = 32;

  // ── `effectiveMiniBarExpanded()` 已删除（2026-10-20 第五轮）──
  //   它只被左右内距用过；左右内距改成常数（见 `sidePadVp()`），`miniBarExpanded` 在本组件里
  //   不再影响任何几何 ⇒ 留着就是"半套机制"。
  //   "收起 / 展开"仍然生效，只是**换了个载体**：胶囊高度/位置在宿主（`Index.homeMiniCapsule*`），
  //   封面档位在 `HomeMiniBarAlbumCover.isTwoRowBarLayout()`（读的仍是 `MusicAppState`）。

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鈽?鑷粯鑳屾澘锛堜慨鐢ㄦ埛瀹炴祴銆屾挱鏀炬潯鑳屾櫙涓嶅脊銆嶏級鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /**
   * 鑳屾澘搴曡壊 鈥斺€?涓?{@link PlaylistFloatingMiniBar.miniBarBackground} **鍚屼竴濂?token**锛堜笉鍙﹂€犻鑹诧級銆?
   */
  private miniBarBackplateColor(): ResourceColor {
    // ★★★ 2026-10-18（用户：「日间模式下这个播放条动画结束还是黑色」）：
    //   **对齐本仓既有那一套 token**（`features/recommendation/src/main/ets/view/HomeFloatingMiniBar.ets:35-43`
    //   给同一条迷你条画背板时用的就是下面这两枚），不另造第二套。
    //
    //   旧写法的两枚 token 都只有 **19% 不透明度**（base `#30F1F3F5` / dark `#33202224`），
    //   背板的观感几乎完全由"它下面那一层"决定 ⇒ 日间模式（浅色页面）里只要背板之下偏暗，
    //   看到的就是「一整块黑色圆角条」；深色模式页面本来就黑 ⇒ 看不出来，所以只有日间炸。
    //   现在换成 sheet 面：
    //     · base（日间）`#CCF1F3F5` —— 80% 不透明度的近白，与首页那条白色 HDS 胶囊同一套观感；
    //     · dark（夜间）`#CC202224` —— 深灰，观感与改动前一致（改动前是 `#33202224` 叠在近黑页面上）。
    //   两枚 token **亮/暗都有变体**，颜色由资源限定符切换，不需要在代码里再读一次明暗开关。
    //   ⚠️ 只换颜色：结构/尺寸/圆角/描边一律不动 —— 这一层仍在 `Stack` 里与内容同域，
    //      `build()` 末尾那个 `.scale({ x: 1, y: this.expandState.morphSquashY })` 照旧把背板与内容一起压、一起弹。
    if (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return $r('app.color.pc_floating_mini_bar_immersive_surface');
    }
    return $r('app.color.floating_mini_bar_sheet_background');
  }

  /** 鑳屾澘妯＄硦妗?鈥斺€?涓?{@link PlaylistFloatingMiniBar.miniBarBlur} 鍚屾。銆?*/
  private miniBarBackplateBlur(): BlurStyle {
    switch (this.ambientState.level) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Thin;
    }
  }

  /**
   * 鈽呪槄鈽?2026-10-16锛堢敤鎴峰疄娴嬨€?*鍏抽棴鎾斁鍣ㄥ彧鏈夊唴瀹逛細寮癸紝鎾斁鏉¤儗鏅笉寮?*銆? 鐢ㄦ埛鎷嶆澘鏂规 A锛夛細
   * **杩蜂綘鏉℃敼鎴愯嚜缁樿儗鏉?*锛岃繖鏍峰畠涓庡唴瀹瑰湪鍚屼竴妫靛瓙鏍戦噷 鈬?`morphSquashY` 涓€璧峰帇銆佷竴璧峰脊銆?
   *
   * ## 涓轰粈涔堥潪瑕佽嚜缁?
   *
   * 鍘熸潵杩欐潯杩蜂綘鏉＄殑鑳屾澘鏄?**HDS 搴曟爮鑷繁鐢荤殑**锛堟垜浠牴 `Row` 鐨?`backgroundColor` 浠庢潵娌¤杩囷紝
   * 鏄€忔槑鐨勶級鈬?`Row.scale({y: morphSquashY})` 鍙兘鍘嬪埌鍐呭锛?*鑳屾澘鍘嬩笉鍒?*
   * 鈥斺€?杩欐鏄?鍏夋枃瀛楀脊涓€涓?鐨勬満鍒躲€傛垜浠湪鍘熺敓 HDS 閲屼篃娌℃硶缁欓偅鍧楄儗鏉垮崟鐙姞鍙樻崲銆?
   *
   * ## 鐜板湪鎬庝箞鎺ワ紙涓や晶鍚勪竴澶勫紑鍏筹級
   *
   * | 浣嶇疆 | 鏀瑰姩 |
   * | --- | --- |
   * | 棣栭〉锛坄Index.ets` 鐨?`barFloatingStyle.miniBar`锛?| `enableMiniBarBackground: false` 鈬?HDS **涓嶅啀缁欒糠浣犳潯鐢昏儗鏉?*锛堥〉绛捐兌鍥婇偅鍧楄儗鏉夸笉鍙楀奖鍝嶏紝瀹冩槸鍙︿竴鍧楋級 |
   * | 浜岀骇椤碉紙`Index.floatingMiniBar` 鐨?HdsTabs锛?| `barBackgroundColor(Color.Transparent)` + `barBackgroundBlurStyle(BlurStyle.NONE)` |
   * | 鏈粍浠?| 鑳屾澘鐢辫繖涓€灞傝嚜缁橈紝鎸傚湪**涓庡唴瀹瑰悓涓€涓?`Stack`** 閲?鈬?璺熺潃涓€璧峰帇 |
   *
   * 鈿狅笍 **涓や晶蹇呴』涓€璧锋敼**锛氬彧鍏?HDS 閭ｄ唤鑰岃繖閲屼笉鐢?鈬?杩蜂綘鏉″簳涓嬩細绌轰竴鍧楋紙鑳界湅鍒伴椤靛唴瀹归€忎笂鏉ワ級銆?
   * 鈿狅笍 棰滆壊/妯＄硦/鍦嗚**鍏ㄩ儴澶嶇敤鏃㈡湁 token**锛坄floating_mini_bar_*` + `comp_divider` + 28vp锛夛紝
   *   涓?{@link PlaylistFloatingMiniBar} 閫愬瓧涓€鑷?鈥斺€?涓嶆柊澧炰换浣曡嚜缂栭鑹层€?
   */
  @Builder
  private MiniBarBackplate() {
    Column()
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      .backgroundColor(this.miniBarBackplateColor())
      .backgroundBlurStyle(this.miniBarBackplateBlur())
      // 鍦嗚/鎻忚竟鍙ｅ緞涓?`PlaylistFloatingMiniBar` 涓€鑷达紙娌夋蹈鎬佷笉鎻忚竟銆佷笉鍦嗚锛?
      .borderRadius(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 28)
      .borderWidth(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 1)
      .borderColor($r('app.color.comp_divider'))
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 涓婃媺璧锋墜鍚庤ˉ閲?缁灏侀潰"鐨勭粓鐐归敋鐐广€?
   *
   * 鎾斁椤垫槸**璧锋墜閭ｄ竴鍒?*鎵嶆寕杞界殑锛屾墍浠ョ涓€甯ч噺涓嶅埌瀹冪殑澶у皝闈紙`getFrameNodeById` 杩斿洖绌猴級銆?
   * 鍙嶇紪璇戜晶闈?`onPullReady` 鍥炶皟琛ラ噺锛涜繖閲岀敤鍚屾牱鐨勭獥鍙ｏ紙12 脳 32ms锛夎疆璇紝
   * 涓€鏃﹂噺鍒板氨鎸夊綋鍓嶈繘搴﹂噸钀藉嚑浣曪紙`measureMiniDuringPull` 鍐呴儴鍋氾級锛?
   * 浜庢槸"鎵嬫寚宸茬粡鎷栧埌涓€鍗娿€佸皝闈㈡墠鍑虹幇"涔熻兘绔嬪埢鎺ヤ笂锛屼笉浼氫竴鐩寸己杩欎竴妫掋€?
   *
   * 鈽呪槄 2026-10-15锛坄娲鹃煶鍔ㄧ敾Bug娓呭崟.md` **P1-10**锛夛細褰㈠弬琛ヤ笂**榛樿鍊?`= 0`**锛?
   *    骞舵妸瀹堝崼浠?`attempt >= MAX` 鍔犲鎴?`!Number.isFinite(attempt) || attempt >= MAX`銆?
   *    涓轰粈涔堬細鍚屼竴浠介€昏緫鏈粨鏈?*涓変釜鍓湰**锛堟湰鏂囦欢 / `MiniBarPlayer.ets` / 澹冲眰
   *    `products/default/.../Index.ets` 鐨?`schedulePullAnchorRemeasure`锛夛紝
   *    鍘熸潵**鍙湁 `MiniBarPlayer` 甯﹂粯璁ゅ€?*銆備竴鏃﹀摢鏉¤矾寰勫啓鎴愭棤鍙傝皟鐢細
   *    `undefined >= 12` 鍦?JS 璇箟涓嬫槸 **false** 鈬?**涓嶆棭閫€銆佺収璺?*锛?
   *    鑰岄€掑綊閭ｄ竴鍙ヤ紶鐨勬槸 `attempt + 1` = **NaN**锛宍NaN >= 12` 鍚屾牱鏄?false
   *    鈬?姣?32ms 涓€涓畾鏃跺櫒锛?*姘歌繙鍋滀笉涓嬫潵**銆傚綋鍓嶅敮涓€鐨勮皟鐢ㄧ偣浼犱簡 `0`锛?
   *    鎵€浠ョ嚎涓婃病瑙﹀彂 鈥斺€?杩欐槸"涓嬫鏀瑰氨浼氳俯"鐨勬姢鏍忥紝涓嶆槸淇幇鐘躲€?
   *    鈿狅笍 澹冲眰閭ｇ涓変釜鍓湰灞炵鍖烘枃浠讹紙`products/default/src/main/ets/pages/Index.ets`
   *    `:565`锛夛紝**鏈疆娌″姩**锛岄渶瑕佸３灞傞厤鍚堬紙瑙佹湰杞姤鍛?闇€瑕佸３灞傞厤鍚堢殑鏉＄洰"锛夈€?
   * @param attempt 宸茬粡灏濊瘯杩囩殑娆℃暟锛堥粯璁?0锛涢潪鏈夐檺鏁颁竴寰嬬洿鎺ヨ繑鍥烇級
   */
  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (!Number.isFinite(attempt) || attempt >= HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    setTimeout((): void => {
      // 鈽呪槄鈽?2026-10-16锛?*鍚屼竴褰㈢姸绗?4/5/6 澶勶細鍘绘帀 `morphGenAlive` 瀹堝崼**锛?
      //   鍘熸潵鏄?`if (!pullDragging || !morphGenAlive(gen)) return;`銆?
      //   `morphGen` 鐨勮涔夋槸"杩欎竴杞舰鍙樹細璇濈殑缂栧彿"锛屽畠琚?`morphReset()` 鎺ㄩ珮 鈥斺€?
      //   鑰?鏃ч〉闈㈠疄渚嬪嵏杞?杩欑被涓庣敤鎴锋剰鍥炬棤鍏崇殑浜嬪氨浼氭帹楂樺畠
      //   鈬?鏁翠釜 12脳32ms 琛ラ噺绐楀彛鍦ㄧ 1 鎷嶉潤榛樻鎺夛紙涓嶅啓鏃ュ織锛屾煡涓嶅嚭鏉ワ級銆?
      //   杩欐鏄?搂102/搂104 鍦ㄥ３灞備慨鎺夌殑鍚屼竴涓舰鐘讹紙閭ｅ彞缁撹鍦ㄦ湰浠撳啓杩囦笁閬嶏級锛?
      //     > 鐢?浼氳瘽缂栧彿"鍘诲垽"鐢ㄦ埛杩樻兂涓嶆兂鐪嬫挱鏀鹃〉" 鈥斺€?涓よ€呮棤鍏炽€?
      //   鈬?鍙垽 `pullDragging`锛?杩欎竴杞繕娌¤蛋瀹?鎵嶆槸瑕佷笉瑕佺户缁ˉ閲忕殑鐪熷垽鎹級銆?
      if (!this.expandState.pullDragging) {
        return;
      }
      if (this.expandState.measureMiniDuringPull(this.getUIContext(), false)) {
        return;
      }
      this.schedulePullAnchorRemeasure(attempt + 1);
    }, HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MS);
  }

  /**
   * @returns 鑳跺泭鐨?*宸?*鍐呰竟璺濓紙vp锛夛細`楂樺害/2 鈭?灏侀潰杈归暱/2`銆?
   *
   * 杩欐槸閫嗗悜瑙勬牸閲?`MiniPlayer.sidePad` 鐨勫師寮忥紙`MiniPlayer鑳跺泭甯冨眬涓庡搴︾害鏉?md` 搂涓夛級锛?
   * 璇箟鏄?璁╁皝闈㈠湪鑳跺泭閲屽瀭鐩村眳涓€佷笖灏侀潰宸﹁竟缂樹笌鍐呰竟璺濆乏杈圭紭瀵归綈"銆?
   * 鎶樺彔鎬侀珮搴?`40 脳 1.4 = 56`銆佸皝闈?`40 脳 0.8 = 32` 鈬?`sidePad = 12`銆?
   *
   * 鈽呪槄 2026-10-15锛堥厤濂?鎾斁鏉℃洿绮?閭ｆ潯锛夛細鏈粨鐨勮糠浣犳潯灏侀潰璧?
   *   `HomeMiniBarAlbumCover.coverSideLengthVp()`锛岃€?*娌夋蹈寮忚嚜鐢辩獥鍙?*閭ｄ竴妗ｆ濂戒篃鏄?
   *   `40 脳 MINI_COVER_RATIO` 鐨?*瑙嗚**灏哄锛堣閭ｄ釜鏂规硶鐨勬敞閲婏級鈥斺€?
   *   鎵€浠?灏侀潰杈归暱"杩欎竴椤瑰湪杩欓噷**鐩存帴鐢?40**锛? 鏃犵晫鐨?`coverEdge()` 鍊硷級锛?
   *   鑰屼笉鏄啀涔樹竴娆?`MINI_COVER_RATIO`锛堥偅浼氱畻鍑?32锛屽唴杈硅窛鍋忓ぇ 4vp/杈癸紝
   *   鎶婅繖杞垰鍔犲帤鐨?8vp 鍙堝悆鍥炲幓涓€鍗婏級銆?
   *   `h/2 鈭?cover/2 = 56/2 鈭?40/2 = 8` 鈬?灏侀潰涓婁笅鍚勮创 8vp銆佹按骞冲乏缂樿创 8vp銆?
   */
  private sidePadVp(): number {
    // ★★★ 2026-10-20（第五轮，修用户「二级页内容偏右」）：左右内距改成**同一个数**。
    //   无界口径（`MiniPlayer胶囊布局与宽度约束.md` §三）：`sidePad() = capsuleH/2 − coverEdge/2`、
    //   `actionsTrail() = sidePad() + (capsuleH > 0 ? 0 : MINI_EDGE_PAD)` ⇒ capsuleH 已知时**严格对称**。
    //   本行自然高 = coverEdge + 2 × CONTENT_PAD_VP ⇒ 代入上式：
    //     sidePad = (coverEdge + 2×8)/2 − coverEdge/2 = 8 = CONTENT_PAD_VP   （与封面档位无关）
    //   再加 MINI_BAR_INNER_PAD_VP(4) 的呼吸（2026-10-17 用户"离两侧太近"那条）⇒ **12**。
    //   ⇒ 内容盒 = [12, W − 12] ⇒ 内容中心 ≡ 胶囊中心（一眼可算，没有第二个口径）。
    //   ⚠️ 旧实现的右侧是 `actionsTrail() + sidePad()`（二级页 22 + 12 = 34 vs 左 12）
    //      ⇒ 内容中心左偏 (34−12)/2 = 11vp，那是本组件里**唯一**的横向非对称来源，已消掉。
    return HomeMiniBarPlayer.CONTENT_PAD_VP + HomeMiniBarPlayer.MINI_BAR_INNER_PAD_VP;
  }

  /**
   * @returns 鑳跺泭鐨?*鍙?*鍐呰竟璺濓紙vp锛夛細`sidePad() + 锛堟湭閲忓埌楂樺害鏃剁殑 MINI_EDGE_PAD锛塦銆?
   *
   * 鈿狅笍 宸﹀彸**涓嶅绉?*鏄鏍奸噷灏辨湁鐨勶紙鍙嶇紪璇?`actionsTrail()`锛沗capsuleH` 宸查噺鍒版椂涓?0 澧為噺
   *    = 宸﹀彸鐩哥瓑锛屾湭閲忓埌鏃跺彸渚у 10vp锛夈€傝繖閲屾垜浠病鏈?capsuleH 宸查噺鍒?杩欎釜淇″彿锛?
   *    涓€寰嬫寜鎶樺彔鎬侀偅涓€妗ｇ粰锛堣繖涔熸槸棣栭〉杩蜂綘鏉＄殑甯告€侊級銆?
   *    **缁濅笉鑳藉湪鍙充晶棰濆鍔?16 涔嬬被鐨勫ぇ鍊?* 鈥斺€?涔嬪墠鍙充晶缁?16銆佸乏渚х粰 6锛?
   *    鍙充晶閭?16vp 浼氬拰鎸夐挳绨囨姠瀹藉害锛屾妸"鎾斁鍒楄〃"鎸夐挳鎸ゅ嚭鍙鑳跺泭銆?
   */
  private actionsTrailVp(): number {
    // ★★★ 2026-10-20（第五轮）：**恒等于左内距**（`capsuleH` 已知时的无界口径）。
    //   旧实现 = `sidePad() + (expanded ? 0 : MINI_EDGE_PAD)`，再在 `build()` 里对
    //   `!followAppMiniBarExpanded` 的宿主（= 二级页）又加一份 `sidePad()` ⇒ 右侧 34 / 左侧 12。
    //   那 10vp（MINI_EDGE_PAD）在无界里的语义是"**还没量到 capsuleH** 时给 actions 留的余量"——
    //   本仓两条宿主的高度都是**给定的常量**（`Index.FLOATING_MINI_BAR_HEIGHT_VP`），这个余量的
    //   前提根本不成立 ⇒ 按无界口径 `capsuleH > 0 ⇒ extra = 0` 处理，左右必须相等。
    return this.sidePadVp();
  }

  /**
   * 根 `Stack` 的高度上限（vp）：`contentHeightVp > 0` 时就是宿主给的设计高度，否则等于"不约束"。
   *
   * 为什么用 `constraintSize.maxHeight` 而不是 `height()`：ArkTS 里没有"auto/不设置"的表达式
   * （`height()` 只吃 `Length`），而 `maxHeight` 大于自然高度时完全等价于不约束 ⇒ 一套代码两用。
   * 钉住之后根 `Stack` 的高度就**与封面档位无关**（常规态 56 而不是自然 60），
   * `MINI_BAR_ID` 量到的形变起点几何也因此不再随窗口装饰档位漂移。
   * @returns 高度上限（vp）。
   */
  private contentMaxHeightVp(): number {
    if (this.contentHeightVp > 0) {
      return this.contentHeightVp;
    }
    return HomeMiniBarPlayer.CONTENT_HEIGHT_UNBOUNDED_VP;
  }

  /**
   * Composes cover and aside in a row with gesture to open the full player on upward pan.
   */
  build() {
    // 鈽呪槄鈽?2026-10-16锛堟柟妗?A锛夛細澶栧眰鎹㈡垚 `Stack`锛?*鑳屾澘涓庡唴瀹瑰湪鍚屼竴涓彉鎹㈠煙閲?* 鈥斺€?
    //   鎵€浠ヤ笅闈㈤偅涓€璁?`morphSquashY`锛堟寕鍦ㄦ牴鑺傜偣鐨?`.scale` 涓婏級浼?*杩炶儗鏉夸竴璧峰帇**锛?
    //   瑙傛劅灏辨槸鐢ㄦ埛瑕佺殑銆屽叧闂椂鏁存潯鎾斁鏉′竴璧峰脊銆嶃€?
    //   鈿狅笍 杩欎袱灞傚繀椤诲湪**鍚屼竴涓?* `Stack` 鍐呫€佷笖 `.scale` 鎸傚湪 `Stack` 涓婏細
    //     鎸傚埌鍐呭眰 `Row` 涓婂氨鍙堝彉鎴?鍙帇鍐呭"锛堥偅姝ｆ槸鏀瑰墠鐨勫舰鐘讹級銆?
    Stack({ alignContent: Alignment.Center }) {
      // 鑳屾澘鍦ㄤ笅銆佸唴瀹瑰湪涓婏紙`Stack` 鍚庡啓鑰呭湪涓婏級
      if (this.showSelfDrawnBackplate) {
        this.MiniBarBackplate()
      }
      Row({ space: 8 }) {
      HomeMiniBarAlbumCover({
        playerViewModel: this.playerViewModel,
        followAppMiniBarExpanded: this.followAppMiniBarExpanded,
        lockTwoRowCoverSize: this.lockTwoRowCoverSize
      })
      HomeMiniBarPlayerAside({
        playerViewModel: this.playerViewModel,
        showPreviousTrack: this.showPreviousTrack,
        floatingMeta: !this.followAppMiniBarExpanded
      })
        // 鎿嶄綔鍖猴細`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`锛屾瘮灏侀潰閭ｆ。鏇存棭娑堝け
        .opacity(this.expandState.miniBarOpacity())
    }
    // 鈽?闈炲绉板唴杈硅窛锛堢収鎶勯€嗗悜瑙勬牸 `MiniPlayer.sidePad / actionsTrail`锛夛細
    //   宸?= 楂樺害/2 鈭?灏侀潰/2锛堣灏侀潰璐翠綇鍐呭宸﹁竟缂樸€佸瀭鐩村眳涓級锛屽彸 = 宸?+ 鎶樺彔鎬?10vp銆?
    //   鈿狅笍 鍘熸潵鎶樺彔鎬佺粰鐨勬槸 `BreakpointType(16,24,32,32)`锛堝乏鍙?*瀹屽叏瀵圭О**涓斿ぇ鍒?32vp锛夛紝
    //      妯悜鍑€瀹借鍚冩帀 64vp锛屽彸杈归偅 32vp 姝ｅソ鍘嬪湪鎸夐挳绨囦笂 鈥斺€?杩欐槸"鍒楄〃鎸夐挳琚尋鍑烘挱鏀炬潯"
    //      鐨勫彟涓€鍗婂師鍥狅紙瑙?`MiniPlayer鑳跺泭甯冨眬涓庡搴︾害鏉?md` 绗叚鑺傜 2銆? 鏉★級銆?
    .padding({
      left: this.sidePadVp(),
      // 鈽?鐢ㄦ埛 2026-10-12锛氥€屽彸杈逛笁涓寜閽線宸︾Щ鍔ㄤ竴鐐广€嶁€斺€斾簩绾ч〉闈㈣繖鏉¤兌鍥婇噷锛屽唴瀹瑰 = 鑳跺泭瀹斤紝
      //   鑰?`actionsTrailVp()` 鏄収**棣栭〉閭ｆ潯**锛堝唴瀹规瘮鑳跺泭瀹斤級瀹氱殑 鈬?鎸夐挳绨囪创鐫€鑳跺泭鍙崇紭銆?
      //   鎶樺彔鎬侊紙= 浜岀骇椤甸潰锛宍followAppMiniBarExpanded === false`锛夊啀鏀朵竴浠?`sidePadVp()`锛?
      //   涓庡乏渚у皝闈㈠埌鑳跺泭宸︾紭鐨勮窛绂诲悓涓€涓彛寰勶紝涓嶆斁鏂扮殑榄旀硶鏁帮紱棣栭〉閭ｆ潯瀹屽叏涓嶅彉銆?
      // ★ 2026-10-20（第五轮）：`right` 现在与 `left` **逐字相等**
      //   （`actionsTrailVp() === sidePadVp()` = `CONTENT_PAD_VP + MINI_BAR_INNER_PAD_VP` = 12）
      //   ⇒ 内容盒 = `[12, W − 12]` ⇒ **内容中心 ≡ 胶囊中心**。
      //   上面那几段（含"折叠态右侧再多 10vp / 二级页再多一份 sidePad"）已作废。
      right: this.actionsTrailVp(),
      top: HomeMiniBarPlayer.CONTENT_PAD_VP,
      bottom: HomeMiniBarPlayer.CONTENT_PAD_VP,
    })
    .alignItems(VerticalAlign.Center)
    .width(StyleConstants.FULL_WIDTH)
    // ★★★ 2026-10-20（二级页「内容偏右下」）：**内容行自己也钉到胶囊高**。
    //   二级页 `contentHeightVp = 56`，而内容行自然高 = 封面 44 + 8 + 8 = 60 ⇒ 行比盒子高 4vp。
    //   "子件比容器大"时排布由引擎兜底（对齐可能退化成锚在左上），那就是 2vp 的**向下**偏差来源；
    //   给行同一个上限之后：行盒 ≡ 容器盒 ≡ 胶囊盒，而且上下内距对称（8/8），
    //   封面就算比行内 padding 区各高 2vp，也在 56 高的胶囊里**几何居中**（`clip` 默认 false ⇒ 不会被切）。
    .constraintSize({ maxHeight: this.contentMaxHeightVp() })
    }
    // 鈿狅笍 `Stack` **娌℃湁** `alignItems`锛堥偅鏄?`Row`/`Column` 鐨勶級鈥斺€?鐢?`.alignContent(Alignment.Center)`
    //   缁欒儗鏉夸笌鍐呭鍚屼竴涓眳涓熀鍑嗭紙鏈疆缂栬瘧鏈熷疄娴嬶細`Property 'alignItems' does not exist on type
    //   'StackAttribute'`锛孉rkTS 鎶ラ敊鐮?10505001锛夈€?
    .alignContent(Alignment.Center)
    .width(StyleConstants.FULL_WIDTH)
    // ★★★ 2026-10-18（晚，用户：「二级页面播放条没偏，但是上面的内容偏了」）：
    //   钉住高度（`contentHeightVp > 0` 时；0 = 完全不约束，与改动前逐字等价）。
    //   配合上一行的 `alignContent: Center` ⇒ 内容行在钉住的盒子里**上下等距**，
    //   二级页那条的"内容偏上"就在这一行 + 宿主那一层 `Stack(matchParent)` 之间被消掉。
    .constraintSize({ maxHeight: this.contentMaxHeightVp() })
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鑳跺泭绂诲睆骞曞乏鍙宠竟澶繎 鈫?寰€涓棿鏀?* 鈥斺€?鐢ㄦ埛绗?4 鏉★紝鐓ф棤鐣岋級
    //   鏃犵晫閭ｆ潯鑳跺泭鏈韩鍐欐 `width('100%')`锛屽搴﹀樊鏉ヨ嚜**瀹冪殑鐖跺鍣?*锛?
    //   椤甸潰绾у乏鍙宠浣?`topPageSideOf()` = 鎵嬫満 **16vp**锛堝綊妗?`璁捐甯搁噺鍏ㄨВ绠?md`锛?
    //   `topPageSideOf = 16 / 24 / 32` 鎸夊搴︽柇鐐癸紝鎵嬫満妗ｆ槸 16 鈥斺€?**灏辨槸鍘熷€硷紝涓嶆槸浼扮殑**锛夈€?
    //   鎴戜滑杩欐潯瀹瑰櫒鍘熸潵鏄?*閫氭爮**锛堝乏鍙?0锛夛紝鎵€浠ュ皝闈?鎸夐挳璐寸潃灞忓箷杈?鈬?瑙傛劅"澶繎"銆?
    //   鈬?鍦ㄨ繖涓€灞傚姞宸﹀彸鍚?16vp 鐨勫唴杈硅窛锛堣儗鏉夸笌鍐呭涓€璧锋敹杩涙潵锛岃兌鍥婃暣浣撳彉绐勫眳涓級銆?
    //   鈿狅笍 鍙姞**妯悜**鍐呰竟璺濓紱涓婁笅浠嶇敱澶栧眰璐熻矗锛堜笉鍔ㄩ珮搴?鈬?褰㈠彉璧风偣鍑犱綍鍙彉瀹姐€佷笉鍙橀珮锛夈€?
    .padding({ left: HomeMiniBarPlayer.MINI_BAR_SIDE_VP, right: HomeMiniBarPlayer.MINI_BAR_SIDE_VP })
    // 鈽?灞曞紑褰㈠彉鐨?*璧风偣鐭╁舰**灏辨槸杩欐潯鑳跺泭锛氱粰涓?id 璁?`getFrameNodeById` 閲忓畠
    // 锛坄onAreaChange` 缁欑殑鏄竷灞€鍑犱綍銆佷笉鍚鍏?transform锛岄噺鍑烘潵鐨勮捣鐐逛細鍋忥級
    .id(MINI_BAR_ID)
    .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
    // 诊断（`hdc shell hilog | grep RzdMiniBarGeom`）：本行**实测**高度 + 窗口 y（vp）。
    // 与 `MiniBarMaterialCapsule` 那两行（`grep RzdMiniBarCapsule` 的 `box …` / `content …`）一对：
    //   顶部留白 = content.y − 胶囊顶（content 行里的 `capsule y=`）；底部留白同理。
    // 判据：`pinned > 0` 时 `cap = pinned` 且 `content h = pinned` ⇒ 行盒 ≡ 容器盒 ≡ 胶囊盒。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      // ★ 2026-10-20（第五轮）：多打 `x=` / `padL=` / `padR=` —— 「二级页内容偏右」的
      //   横向收口判据只有一条：`padL === padR`（本组件内**唯一**的横向非对称来源，现在恒 12/12），
      //   以及 `x === 胶囊 x`（胶囊 x 见 `RzdMiniBarCapsule` 的 `content` 行里的 `capsule x=`）。
      Logger.info('RzdMiniBarGeom',
        `content h=${areaLengthToVp(area.height)} y=${areaLengthToVp(area.globalPosition.y)} ` +
          `x=${areaLengthToVp(area.globalPosition.x)} ` +
          `w=${areaLengthToVp(area.width)} pinned=${this.contentHeightVp} ` +
          `cap=${this.contentMaxHeightVp()} pad=${HomeMiniBarPlayer.CONTENT_PAD_VP} ` +
          `padL=${this.sidePadVp()} padR=${this.actionsTrailVp()} ` +
          `hosting=${this.followAppMiniBarExpanded ? 'home' : 'floating'} ` +
          `selfPlate=${this.showSelfDrawnBackplate} ownSquash=${this.contentOwnsSquash} ` +
          `squashY=${this.expandState.morphSquashY}`);
    })
    // 鈽呪槄 鎸ゅ帇锛坄morphSquashY`锛夋寕鍦?*Stack**涓?鈬?鑳屾澘涓庡唴瀹?*鍚屼竴涓彉鎹㈠煙**銆佷竴璧峰帇銆?
    //   鍑哄锛氭棤鐣?`squashLand` / `animateSquash`锛坄SQUASH_Y = 0.86` 鍘?110ms锛?
    //   鍐?320ms `cubic-bezier(0.34,1.56,0.64,1)` 杩囧啿鍥炲脊锛夈€?
    //   鈿狅笍 闈欐鎬?`morphSquashY` 鎭掍负 1 鈬?**涓嶆敼鍙樹换浣曢潤鎬佺増闈?*锛堝洖褰掔孩绾匡級銆?
    //   琛ラ棿鐢?`PlayerExpandState.squashLandAnim` 鐢?`animateTo` 璧?鈬?杩欓噷**涓嶈**鍐嶅姞
    //   `.animation(...)`锛堜袱濂椾竴璧蜂笂浼氫簰鐩歌鐩栵級銆?
    // ★★★ 2026-10-20：挤压由**谁**负责，看 {@link contentOwnsSquash}。
    //   自绘胶囊宿主（`true`）自己压；住进 {@link MiniBarMaterialCapsule} 的宿主（`false`）交给胶囊那层，
    //   否则两层 0.86 相乘 = 0.74（弹过头）。
    .scale({ x: 1, y: this.contentOwnsSquash ? this.expandState.morphSquashY : 1 })
    // 鈿狅笍 杩欓噷**涓嶈**缁欐暣鏉?Row 鍔犻€忔槑搴︼細鍙嶇紪璇戦噷杩蜂綘鏉℃槸**涓ゆ。**娣″嚭 鈥斺€?
    //    鍙充晶鎿嶄綔鍖?`1 - t/0.20` 鍏堟病銆佸皝闈?鍏冧俊鎭?`1 - t/0.35` 鍚庢病銆?
    //    涓ゆ。鍒嗗埆鍦?`HomeMiniBarPlayerAside` 涓?`HomeMiniBarAlbumCover` 涓婄敓鏁堬紝
    //    鍦?Row 涓婂姞涓€浠戒細鎶婂皝闈篃鎸?0.20 鎻愬墠娣℃帀锛堝氨鍒嗕笉鍑哄厛鍚庝簡锛夈€?
    .onClick((): void => {
      this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
    })
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((): void => {
          // 鈽?璇婃柇闂稿浣嶏細瑙?`pullDropCountedThisGesture`锛堜笁鏉¤窡鎵嬮摼蹇呴』閮芥帴璁℃暟锛夈€?
          this.pullDropCountedThisGesture = false;
          if (this.appState.isShowPlay) {
            return;
          }
          const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), false);
          if (!this.appState.isShowPlay) {
            this.appState.isShowPlay = true;
          }
          if (!ok) {
            // 鈽?涓庡３灞?`onPullOpenStart` 鐨?`!morphOk` 鏀悓鏃?鈬?璁″悓涓€涓暟锛坄pullDropBegin`锛夈€?
            this.expandState.notePullDropBegin();
            this.expandState.pullDragging = false;
            this.expandState.morphReset();
            this.expandState.morphSettleOpen();
            return;
          }
          // 鈽?璧锋墜杩欎竴鍒绘挱鏀鹃〉**鍒氭寕杞?*锛屽畠鐨勫皝闈㈣妭鐐硅繕娌″竷灞€瀹岋紙閲忎笉鍒帮級鈥斺€?
          //   鑰?缁灏侀潰"鐨勭粓鐐规鏄畠銆傝ˉ閲忓嚑娆★紙瀵规爣鍙嶇紪璇?`onPullReady` 鍥炶皟閲岄偅娆¤ˉ閲忥級锛?
          //   鍏嶅緱鎵嬫寚涓€璺線涓婃嫋銆佸睆涓婂嵈鍙湁搴曡壊绐楀彛鍦ㄩ暱澶с€佷竴寮犲皝闈㈤兘鐪嬩笉鍒般€?
          //   琛ラ噺鎴愬姛鍚庡氨鎸夊綋鍓嶈繘搴﹂噸钀戒竴娆″嚑浣曪紝鏀跺熬鏃朵笉浼氳烦銆?
          this.schedulePullAnchorRemeasure(0);
          // 鈽?澹冲眰娴眰閭ｄ唤缁灏侀潰锛坄Index.MorphCoverClone`锛変篃鍘嬪洖璧风偣锛?
          //   瀹冩湁鑷繁鐨勮繘搴?`morphOverlayP`锛堥潤姝㈡€佸垵鍊兼槸 1锛夛紝涓嶅帇鍥?0 鐨勮瘽
          //   娴眰鐨勭涓€甯т細鎸?钀戒綅鐨勫ぇ灏侀潰"鐢讳竴娆°€?
          this.expandState.morphOverlayReset();
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            // 鈽?璇婃柇锛堜竴娆℃墜鍔垮彧璁颁竴娆★紝鐞嗙敱瑙?`pullDropCountedThisGesture`锛夈€?
            if (!this.pullDropCountedThisGesture) {
              this.pullDropCountedThisGesture = true;
              this.expandState.notePullDropUpdate();
            }
            return;
          }
          this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(event.offsetY));
          // 璺熸墜鏈熶袱灞傚繀椤诲悓鍊硷紙鍚﹀垯鏉炬墜琛ラ棿鏃朵細鍏堣烦涓€涓嬫诞灞傞偅涓繘搴︼級
          this.expandState.syncMorphOverlayFromPage();
        })
        .onActionEnd((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            this.expandState.notePullDropEnd();
            return;
          }
          // 鈽?鎻愪氦鍒ゆ嵁**鍙湁涓€浠?*锛歚PlayerExpandState.pullOpenShouldCommit()`
          //   锛堟竻鍗?搂涓€ 1.2銆岃繘搴?OR 閫熷害銆嶏級鈥斺€?鍘熸潵杩欓噷鍙垽 `>= 0.45`锛?
          //   "浣嶇Щ涓嶅ぇ浣嗙敥寰楀緢蹇?鎵撲笉寮€銆傚垽鎹敹鏁涘悗锛屼袱鏉¤糠浣犳潯 + 澹冲眰涓夊涓€鑷淬€?
          this.expandState.requestPullOpenSettle(
            this.expandState.pullOpenShouldCommit(this.expandState.morphP,
              event.offsetY, event.velocityY));
        })
        .onActionCancel((): void => {
          if (!this.expandState.pullDragging) {
            this.expandState.notePullDropEnd();
            return;
          }
          this.expandState.requestPullOpenSettle(false);
        })
    )
  }
}
