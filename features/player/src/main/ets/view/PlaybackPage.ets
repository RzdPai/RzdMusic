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

// 闂佸疇娉曟刊瀵哥箔?`TextController` 闂?ArkUI 闂?*闂佺绻堥崝宀勬儑椤掑嫭鍋濇い鏍ㄥ嚬閺嗘梻绱掗銉殭闁?*闂佹寧绋戦悧鍛箔婢舵劖顥嗛柍褜鍓涢幉?import闂佹寧绋戦悾鐠弖sicPlayInfoBlock` 闂佸憡鑹鹃張顒勵敄濞嗘挻鏅?
import { AnimatorOptions, AnimatorResult, AppStorageV2, uiObserver, UIUtils, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import {
  AppStorageKeys,
  BreakpointConstants,
  // 闂?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`BarCollapse`闂佹寧绋戦¨鈧紒鍙樺嵆楠炴帟顦查柛鈺傤殜瀵爼鍩勯崘銊у綄闂佸憡鏌ｉ崝宥夊极閸︻厽灏?闁诲繒鍋炲ú鏍閹达附鍎嶉柛鏇ㄥ墮椤や線鏌涢弮鍥ㄧ《濠殿喗鎮傞獮鈧ù锝堫潐缁?
  BarAction,
  BarCollapse,
  CoverRadiusState,
  CoverTintState,
  MeshWarmState,
  getWindowInfoState,
  ImmersiveType,
  isWidthBreakpointLgOrXl,
  Logger,
  MorphDrive,
  MorphStage,
  MusicStoreService,
  PlayedSongRecord,
  // 闂?2026-10-15闂佹寧绋戦悧鎰般€呴锔藉剮闁哄诞鍛嬀缂傚倷鑳堕崰宥囩博閹绢喗鏅鑸电〒缁愭绱掗弮鎴濈仯闁稿缍侀弻宀冪疀閺冨倶鍋為梺姹囧妼鐎氼剟鎮ラ崼鏇熺厒闊洤娴烽悷銏⑩偓瑙勬偠閸庨亶宕ｉ崸妤佹櫖闁割偅绻傞弬褔鏌℃径鍫濆姎鐟滄妸鍥ф嵍?`MusicPlayInfoBlock` 闂備焦褰冮惉濂稿极閵堝鏅?
  PLAYER_BIG_COVER_ID,
  // 闂?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`PLAYER_ROOT_ID`闂佹寧绋戦¨鈧紒鍙樺嵆濡啴鎮欓弶鎴澒闂佸憡鏌ㄩ悘婵嬪矗瑜斿濠氼敇閳藉棙鐭楅梺鐟板槻缁夋挳骞撻埡鍛亗鐟滃繐鈻撻幋锔界劷闁挎繂瀚伴崵瀣煠閸濆嫬鈧宕戦敐澶嬫櫖? 閻熸粏鍩囬崹纭呫亹婢跺备鍋撻崷顓熷殌婵炲懏甯￠弫?
  PLAYER_ROOT_ID,
  // 2026-10-19：诊断写进应用内运行日志（用户没有 hdc，设置里能看）。
  appendPlayLog,
  // 闂?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?ShrinkOverlay闂佹寧绋戦¨鈧紒鍙樺嵆濡啴鎮欓弶鎴澒闂佸憡鏌ㄩ悘婵嬪矗瑜斿濠氼敇閻樺磭鏆犻棅顐㈡祩閸嬪棝宕ｆ惔銊ョ哗闁告挷鑳剁槐姘箾閹碱厼鏋涢柣?
  MorphShrinkState,
  type MorphShrinkRect,
  PLAYER_META_TITLE_ID,
  PLAYER_META_SINGER_ID,
  MorphMetaEndpoint,
  areaLengthToVp,
  PlaybackShellConstants,
  PlayerExpandState,
  // 闂?2026-10-16闂佹寧绋掔喊宥咃耿閻楀牄浜滈梻鍫熺⊕闊?`.onDisAppear()` 闂備焦褰冮惌渚€銆呴敃鍌氱?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暟閻斿懘鏌ｉ姀锝囩翱缂佺粯娲熷畷鐑藉Ω閵堝洨鎲归梺闈╄礋閸斿秹鎮ラ妶澶嬬厒?闂佹寧绋戦悧鎰帮綖?`playerRouteStillPushed`闂?
  RouterUrlConstants,
  ShowMiniLyricState,
  StyleConstants,
  // 2026-10-18：meta 行「评论」按钮靠它把请求传给 `ControlAreaComponent`（共享序号，见字段注释）。
  PlaybackIntentState,
  WindowInfo,
  WindowUtil
} from 'musicbasic';
import type { LyricMorphRect } from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { SwitchBannerState } from '../model/SwitchBannerState';
import { MediaService } from '../model/MediaService';
import { ColorConversion } from '../util/ColorConversion';
import { PlayerConstants } from '../constant/PlayerConstants';
import { ControlAreaComponent } from './ControlAreaComponent';
import { LyricsComponent } from './LyricsComponent';
import { MiniLyricLinesComponent } from './MiniLyricLinesComponent';
import { MeshCoverBg } from './MeshCoverBg';
// 闂?缂傚倸鍟崹鍫曟偋閹间焦鍤勯悘鐐靛亾閻濐垶鏌ｉ妸銉ヮ仼鐟滄澘娲畷鍫曟倷椤掑倶鍋婂┑顔矫顓㈠吹鎼淬劍鏅柛顐犲灩瀵箖鏌熺喊鍗炲婵☆偁鍊濋幃?`design/logic/MeshSource.ets`闂?
import { SRC_EDGE, enhanceColors, boxBlurRgba } from '../util/MeshSource';
// 闂佸疇娉曟刊瀵哥箔?闂佸綊娼ч鍡椻攦閳ь剛绱掗幇顒€顏╅柣顐㈡閹?*婵?0 閻庤鐡曠亸娆戝垝閳╁啰鈻旂€广儱娲﹂弳蹇涙倵閻熸澘鏆曠紒?*闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸澹嗘禍鍛婄瑹閳ь剙顭?濠殿喗绻傞懟顖炲箖閺囥垹缁╅悷娆忓閻?`Swiper` 婵犮垼鍩栭悧婊冣枔閹寸姵鍟洪柛鈩冪懄绾句即鎮橀悙鎻掍喊缂佽鲸宀搁弫?
//    婵?*闁诲海顢婂Λ鍕儓?/ 闂傚倸鐗勯崹鍝勵熆濡吋鏆滈柛鎰╁妿濠€浼存⒑椤撱劎瀵奸悶姘朵憾瀵爼鍨鹃崘鑼偓濠氭煛閳ь剟顢涘▎鎴犵厳闂侀潻璐熼崝搴ㄥ极?*闂佹寧绋戝濉巙sicPlayInfoBlock` 闂?1817 / 2101 婵炴垶鎸堕崐鏇⑺囬埡鍛櫖?
//    闂?import 婵炴垶鎸哥粔鐑藉礂濮椻偓瀹曟岸鎮╅鐟颁壕闁稿瞼鍋涙禍婵嗏槈閹惧崬鈧牕顭囬鐐茬闁糕剝蓱閺嗘粓鏌ｉ妸銉ヮ伀缂侇喚鍎ょ粙澶愬焵椤掑嫬鍙婃い鏍ㄧ懅閻熸挸鈽夐幘顖氫壕闂佺鍕垫缂佽鲸鐟╁顐﹀级閹寸姵缍勯柣蹇撶箣缁舵艾顭囬悧鍫涗簻闁稿繐鎽滈悷銏ゆ偡閺囩偞顥犳繛鎻掞功娴狅箓宕掑顓炩偓銈嗩殽閻愰鍟囩紒杈ㄥ哺婵?
import { MusicPlayInfoBlock } from './MusicPlayInfoBlock';
import { TopAreaComponent } from './TopAreaComponent';

/** Clamps a numeric RGB channel to an integer byte in [0, 255]. */
function clampRgbByte(n: number): number {
  if (!Number.isFinite(n)) {
    return 0;
  }
  return Math.max(0, Math.min(255, Math.floor(n)));
}

/** cubic-bezier 的单轴分量：P0 = 0、P1 = p1、P2 = p2、P3 = 1。 */
function morphBezierAxis(p1: number, p2: number, t: number): number {
  const u: number = 1 - t;
  return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t;
}

/**
 * @returns `cubic-bezier(0.23, 1.0, 0.32, 1.0)` 的 **y(x)**。
 *
 * 这就是上游 `EASE_OUT_STR`（`wujie.pa` 的 `Tokens[15]`），也是本仓几何那条 `animateTo` 用的同一条曲线。
 * 二分反解 `t` 使 `X(t) = x`（X 在本组控制点下单调），再取 `Y(t)` ⇒ 与
 * `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)` 逐值同源。
 *
 * 为什么需要它：`animateTo` **不会**把状态变量逐帧插值（见 `startContentTicker()` 的说明），
 * 而内容窗口（`pullChromeOpacity` / `pullBottomIn` / `pullBgIn` / `metaRiseVp`）必须吃**真进度**，
 * 所以内容时间线改成 16ms ticker 逐帧写 `contentP = morphEaseY(t / 560)`。
 */
function morphEaseY(x: number): number {
  const cx: number = x < 0 ? 0 : (x > 1 ? 1 : x);
  let lo: number = 0;
  let hi: number = 1;
  let t: number = cx;
  for (let i = 0; i < 24; i++) {
    if (morphBezierAxis(0.23, 0.32, t) < cx) {
      lo = t;
    } else {
      hi = t;
    }
    t = (lo + hi) / 2;
  }
  return morphBezierAxis(1.0, 1.0, t);
}


/** 婵炴垶鎸撮崑鎾寸箾閸″繆鍋撳畷鍥唸闂傚倸鐗滃鈧紒妤€鎳忓顏堝磹閻旀粍甯″畷娆撴惞鐟欏嫮鏆犳繛鎴炴尪閸婃洜妲愰懜鍨鐎广儱鎳忕粋鍫ユ煥濞戞澧ｆい?`PlaybackPage.loadOnlineCoverPair`闂佹寧绋戦ˇ顓㈠焵?*/
class CoverDecodePair {
  /** 闂佺绻堥崝宀勫及閸屾壕鍋撻悽鍛婁氦缂佽鲸绻冪粭?`effectKit` 闂佸憡鐟﹂悧鐐寸珶婵犲洤违?*/
  full: image.PixelMap | undefined = undefined;
  /** 64闁?4闂侀潧妫旈梼娣旴A_8888闂侀潧妫旂粈浣姐亹閼碱剛纾介柡宥庡墰鐢?闂佺偨鍎查弻锟犲焵?缂傚倸鍟崹鍫曟偋閹间焦鍤勯悘鐐靛亾閻濐垶鏌ｉ妸銉ヮ仾缂侇煈鍣ｆ俊?*/
  mesh: image.PixelMap | undefined = undefined;
}

/** Minimal shape for probing {@link image.PixelMap.release}; {@link Resource} does not carry this. */
interface PixelMapReleaseProbe {
  release?: () => void;
}

/**
 * Full-screen playback page: layered background, breakpoint-specific layout, dismiss gestures,
 * and dynamic tint from album art.
 */
@ComponentV2
export struct PlaybackPage {
  /**
   * 婵犮垻鎳撻崯鍧楁儑娴煎瓨鍎嶉柛鏇ㄥ枤閻斿懘鏌ｉ姀锝夊摵闁绘牓鍊濋弫宥夊锤閸戭洈dex.ets:237 @Provider('pageIndexInfos')` 闂佸湱绮崝鎺旀閻㈠憡鏅璺虹墐閸?
   *
   * 闂?2026-10-16 闂佸搫鍊瑰姗€路閸愵喗鏅?*闂佸摜鍎愰崹顖滅博閹绢喗鍋ㄩ柕濞炬杹閸?*闂佸搫瀚烽崹鐢割敊閳ь剟鏌￠崼顐㈠⒋闁靛棗顦靛畷?`.onDisAppear()` 闂備焦褰冮懟顖炲垂?
   * 闂侀潧妫楅張顒勫箰闁秴缁╁Δ锝呭暔閳ь剙顦遍幑鍕敍濠婂嫭娈搁梺鍝勫閸垳绮径鎰強妞ゆ牗绻勭粻鐑芥煕閿斿搫濡介柣鏍ュ€濋弻宀€浠﹂悜鈺佷壕鐎广儰璁查崑鎾诲棘鐞涒€充壕?闁?{@link playerRouteStillPushed}闂?
   * 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ矌閻熸繂霉閻樻煡顎楃€殿噮鍓熷顐ｏ紣娴ｈ櫣鍊為梺鎸庣⊕閻＄嬁laybackPageCoverContent` / `PlaybackPageBuilder` 闂備緡鍠涙慨銈呂?`@Builder`闂?
   * 婵犮垼鍩栭惌顔炬閼哥數鈻旈柍褜鍓氱粙?`NavPathStack` 闁荤喐娲戦悞锕傚极閸忚偐鈻斿璺侯煬濡茶京绱掑☉娆忓姢闁诡喗娲熼弫宥呪柦濡楁阀rovider/@Consumer` 闂佸搫瀚烽崹鍗烇耿閺夋鍟呴柕澹偓閺屻倗鈧鐡曠亸娆戝垝閿熺姴鎹堕柕濞у嫭娈㈤梺?
   * 闁诲氦顫夎摫闁哄瞼鍠栭獮瀣箛椤掑娈搁梺鍝勭墕閹碱偊宕哄Δ鍛櫖闁秆冨殬ndex.ets` 閻庤鐡曠亸娆戝垝閿熺姴鍙?`@Provider`闂佹寧绋戦¨鈧紒杈ㄧ箞楠炴帡濡烽妶鍥朵紘濠电偛妫岄埀顒€鍟跨粊顕€鏌涘▎妯虹仜闁?
   */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Window width/height breakpoint for responsive layout branches. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Global music UI and queue state. */
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Mini lyric switch shared with settings. */
  @Local miniLyricState: ShowMiniLyricState =
    AppStorageV2.connect(ShowMiniLyricState, AppStorageKeys.SHOW_MINI_LYRIC_STATE, () => new ShowMiniLyricState())!;
  /** Status bar / navigation bar metrics for safe padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  @Local coverRadiusState: CoverRadiusState =
    AppStorageV2.connect(CoverRadiusState, AppStorageKeys.COVER_RADIUS_STATE, () => new CoverRadiusState())!;
  /** 濠电偟绻濈粈渚€宕㈠鍫熷殑閻忕偟鍋撻悵顖炴煟閵娿儱顏ч悶姘抽哺缁嬪顢旈崼顐ｆ緬闂佽偐顢婇婊呮濞嗘挻鍋ㄩ柛妤冨仧濞堥亶姊婚崼娑樼仼濠殿喒鏅犻獮鈧ù锝囶焾缁插潡鏌ょ憴鍕祷闁哥喐鎹囧畷妤呭Ψ椤栨粎顦梺?*/
  @Local coverTint: CoverTintState =
    AppStorageV2.connect(CoverTintState, AppStorageKeys.COVER_TINT_STATE, () => new CoverTintState())!;
  /**
   * ★★★ 2026-10-17（用户实测「点击打开播放页时背景是别的歌的颜色 / 对不上」）：
   * 壳层预热好的**当前歌曲 64×64 网格缓存**（{@link MeshWarmState}）。
   *
   * 挂载那一拍 `state.getCurrentSongItem()` 可能还是**上一首** ⇒ 绝不能盲用缓存
   * （上一轮就是这么炸的：显示上一首的颜色）。所以：
   * 1. `onAppear` 里先试一次（`adoptWarmMesh()`，内部**比对 key**）；
   * 2. 缓存更新时（{@link onMeshWarmVersionChanged}）再试一次 —— 那时 key 已经是当前歌。
   */
  @Local meshWarm: MeshWarmState =
    AppStorageV2.connect(MeshWarmState, AppStorageKeys.MESH_WARM_STATE, () => new MeshWarmState())!;
  /** 閻庣懓鎲¤ぐ鍐姳閺屻儲鍋ㄩ柕濞垮劚閻撳倿鏌ｉ鐔蜂壕闂佽壈顫夎ぐ鍐ㄢ枍閹烘鍎嶉柛鏇ㄥ亜缁插潡鏌ょ涵鍛毢濠⒀勵殜瀵敻顢楅埀顒冦亹閸ф鏅€光偓閸曨亞绱氶梺绋跨箰缁夋挳骞冮幘瀵糕枖闁逞屽墯缁傛帗绂掔€ｅ灚婢掗梺鑹邦潐閻擄繝宕抽崨濠傜窞鐎广儱瀚悷鎾绘煕濞嗘劕鐏ョ紒鏃傚厴婵?*/
  private appliedTintVersion: number = -1;
  /**
   * Background cover source (Resource).
   *
   * 闂佸疇娉曟刊瀵哥箔?2026-10-15闂佹寧绋掓穱娲磿濡ゅ懎鐤炬い鏍ㄧ⊕閺嗩參鎮楅崷顓炰沪婵＄偛鍊歌灒闁挎稑瀚棟闂佸憡鑹鹃崙鐣屾濠靛瀚夋い鎺嗗亾闁烩姍鍐ｆ灁?*闂佽鍘界敮濠勬嫻?`Resource`**闂? `song.label`闂佹寧绋戦懟顖滄暜椤愶絾鍙忛悗锝庝簽濞堥亶姊婚崼顐ｇ窙缂佽鲸宀搁弫?
   *   婵炴垶鎸哥粔鎾疮閳ь剟鎮跺鐓庝函缂佷焦鎸抽獮?`effectKit` 婵☆偅婢樼€氼厾鎲伴崱娑樿摕闁规儳鍟垮В澶愭煛婢跺牆鍔ゆ繛鍫熷灥铻ｉ柨娑樺钘?PixelMap闂佹寧绋戦悧鎾诲磻閸涙潙绾ч梽鍥儗閹屽晠闁圭粯甯婄划濠氭煟閵忊晝鍘滅紒杈ㄧ箘閹?
   *   {@link getImageColorAsync}闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婅崵鎮锕€鍨傞悗锝傛櫇缁犱粙鏌?`PixelMap | Resource` 闂佸搫瀚烽崹顖滄嫻閻斿摜顩查柛鈩冾殔閹垿鎮?
   *   {@link isPixelMapCover} / {@link originalCoverSource} 闂備緡鍙忕徊鎯ь焽椤栫偛绀傛繝濠傚暟娣囨椽鏌涢幒鎴烆棡闁轰緡鍣ｆ俊?
   */
  @Local imageLabel: image.PixelMap | Resource = $r('app.media.ic_avatar1');
  /** Cross-script source-switch banner state; AppStorageV2-backed for reactive UI. */
  @Local switchBanner: SwitchBannerState = SwitchBannerState.connect();
  /** Last seen banner timestamp for the deferred clear (avoids stale clears). */
  private bannerTs: number = 0;
  /** Pending clear timer id for the banner. */
  private bannerClearTimer: number = -1;
  /** Whether large / grid layout shows transport in the lyric column. */
  @Local isShowControlLg: boolean = false;
  /** Passed to child components that branch on tablet spacing. */
  @Local isTablet: boolean = true;
  /** Inverse tablet flag for lyric column variants. */
  @Local isTabletFalse: boolean = false;
  /** When true, renders the wide split panel layout (no top bar, custom paddings). */
  @Param panelLayout: boolean = false;
  /** Swiper page index (lyrics vs main stack on some layouts). */
  /** 閻熸粎澧楅幐鍛婃櫠?Swiper 婵＄偑鍊楅。顔炬? = 闁诲繐绻嬬欢姘焽閻楀牄浜滅痪鏉款槺缁€? = 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻缁炬澘顦辩粈鍡涙煏?*/
  @Local playbackSwiperIndex: number = 0;
  /** 濠殿喗绻傞張顒€煤閹间焦鍤曟繝濠傚暙缁€瀣煥濞戞澧﹂柛瀣噺缁嬪鍩€椤掆偓铻ｆい蹇撴祩閺€浠嬫煟閵娿儱顏ラ柍褜鍓欓張顒€煤閹稿骸绶炴慨妯稿劗閸嬫挸顓艰箛鏇狀槴闂佸搫瀚烽崹浼村箚娴ｈ桨娌柡鍥╁仧绾惧鏌ㄥ☉娆戭敚heet 闂?`ControlAreaComponent` 闂佹眹鍨洪惇褰掑焵?*/
  @Local playMenuOpen: boolean = false;
  /**
   * 共享播放意图（`AppStorageV2`）：本页只负责 bump 评论入口的序号，
   * 真正挂评论面板的是 `ControlAreaComponent`（它 `@Monitor('intent.commentRequestSeq')`）。
   *
   * ★★★ 2026-10-18（用户：「收藏旁边的歌曲菜单改成评论（已有实现）」）：
   *   评论面板是 `ControlAreaComponent` 那个**唯一**弹层里的子页（一个组件只能挂一个
   *   `bindSheet`），所以这里不新建面板，也不复制实现 —— 只递增序号，那边走
   *   它自己的 `openCommentSheet()`（= 底部「评论」按钮同一条路径）。
   */
  @Local intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
    AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
  /** 閻熸粎澧楅幐鍛婃櫠閻樿鍗抽柛娆忣槹绗戦梺鍛婄啲缁犳垿宕欓敓鐘茬哗闁诡垳澧楅ˉ鎴︽煥濞戞澧﹂柛瀣噺缁嬪鍩€椤掆偓铻ｆい蹇撴祩閺€浠嬫煕濞嗗繐甯犻柡鍛埣閹啴宕熼銈咁洭閻熸粓鍋婂浣烘濮樿泛违闁稿本鐟ч悷?`MusicPlayInfoBlock` 闂佸憡鑹炬總鏃傜博鐎涙闄勬俊銈呭閸ゃ垽鏌涢幇顓犳噣闁?*/
  @Local isCurrentFavorite: boolean = false;
  @Local favStore: MusicStoreService = MusicStoreService.getInstance();

  /**
   * 缂傚倸鍟崹鍫曟偋閹间焦鍤勯悘鐐靛亾閻濐垶鏌ｉ妸銉ヮ仾缂侇煈鍠楅幏鍛吋閸涱喚顩梺?4闁?4闂侀潧妫旂粈渚€宕欓埄鍐╀氦?`enhanceColors` + `boxBlurRgba(9,3)`闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`MeshCoverBg`闂佹寧绋戦¨鈧紒鍙樺嵆瀵敻顢楅崟鈹惧亾婢舵劕绠板ù锝堫潐缁犳帡鎮楅悷鏉挎殶婵炲牊鍨块幃浠嬫偄闁垮娈ラ梺鍛婄◤閸斿秴锕?闂佺偨鍎查弻锟犲焵?
   *   闂佺懓绠嶉崹娲偤閺囥垹绫?`publishMeshSource` 闂備焦褰冮敃銉╁棘娴ｅ湱鈻斿┑鐘辫兌椤忚京鈧鍠氭刊瀵告鏉堛劎鈻旈柧蹇撳帨閺佸嫰鏌￠崘鈺佸姸闁稿孩顨婂鏌ヮ敍濮樿鲸鍕鹃梻渚囧亐閸嬫捇鏌?闁诲骸婀遍崑鐐差渻閸屾鐔兼晬閸曨厔鍥⒑椤撱劎鍒扮紒鍗炵埣瀹?闂?
   */
  @Local meshSrc: image.PixelMap | undefined = undefined;
  /**
   * ★★★ 2026-10-18（用户实测「点击展开时背景**似乎是上一首歌的颜色**」）：
   * 当前 `meshSrc` **归属的曲目 key**（`''` = 还没有源）。
   *
   * 为什么必须有它：`MeshCoverBg` 只认 `src`/`srcVersion`/`seed`，它无法知道"这张图是哪一首歌的"。
   * 换歌时页面既不清 `meshSrc` 也不动 `meshSrcVersion`，而 `seed` 变了 ⇒ 组件会把**上一首的图再采用一次**，
   * 上一首封面为空/下载失败时就整场都是上一首的颜色。
   * ⇒ 换歌时显式作废旧源（等价上游把 `K_IMG_LOCAL` 写成 `""`，`wujie.pa:292472` / `:292490` 两支失败分支），
   * 并把它记在这里，供 `adoptWarmMesh` / `adoptCachedMesh` 判断"这一首是不是已经有源了"。
   */
  private meshTrackKey: string = '';
  /** 闂佺懓绠嶉崹鐟懊瑰Ο鑽ゎ浄闁靛牆娲ら·鍌炴煥濞戞ɑ缍丮eshCoverBg` 闂傚倸鐗忔慨鎾偩閻樺灚鍠嗛柨鏇楀亾鐟滄澘鍊块弻灞筋吋閸℃鍘愭繛鎴炴尭閿曪絿妲愰崼鏇熸櫖鐎光偓閸愮偓缍勯梻渚囧弿缂嶄線宕抽悜鑺ュ剭?`@Monitor`闂佹寧绋戦ˇ顓㈠焵?*/  @Local meshSrcVersion: number = 0;
  /**
   * 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*濞ｅ浂鍠撻埀顒€鑻惈宥咁嚕閳ь剚娼婚崶鈹炬煠濞戞搩鍘藉Σ鍛婄▔婵犱胶顏卞Λ锝嗙墬閻℃洟鎯冮崟顖ｆ澒闁肩懓鐪伴埀?*闁?
   *
   * `coverTint` 闁?*閻犳亽鍔戦妴澶愭閵忕姴褰欏ù?*闁汇劌瀚哥槐妾侫ppStorageV2` 闁?`CoverTintState`闁挎稑顧€缁辨繄鈧懓鍟ぐ褔宕?
   * 闁炽儲鏌￠埀?闁兼澘鑻悾鐘诲及椤栨瑧顏遍悘鐐插€块幗闈涱煥閳╁啯娈婚悘鐐茬箳濞堟垿鎯堥埀顒勬嚌閹绘帗鐝?婵炴挻鍔曡ぐ澶屼沪閸岋妇绀夌紓鍐╁灦閻楀憡娼诲Ο鑽ゆ⒕闁告帡顣︾紞鍛村籍鐠鸿櫣鏆婇悘蹇氶哺濡?闁煎啿鏈▍?
   * 闁?闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣銊ュ濮樸劑寮伴妯峰亾鐏炵晫娼旂€殿喒鍋撻弶鈺佹川閳诲吋绋夐鐔感﹀☉鎾筹梗缁斿瓨锛冮弽銊ф憙闁汇劌瀚伴·渚€鎳濈仦鍌楀亾瀹ュ啠鍋?
   *
   * 闁?闁哄牜鍓欓悺褍鈻?= "**鐟滅増鎸告晶鐘虫交濞嗗海顏卞Λ?*闁汇劌瀚伴·渚€鎳濋幓鎺戝殥缂備礁绻嬬粭鍛村矗閹达絿绠栧ù?闁?
   *   鐠?闁圭鍊藉ù鍥籍閸撲胶鏋傞柛瀣祫缁辨瑦銇勯悽鍛婃〃婵絽绻戦濂稿箥閹惧磭纾婚梺顔垮Г濡叉悂寮弶璺ㄦ澖濞撴艾顑戠槐姘舵晬?
   *   鐠?`applyCoverTint()` 闁活亞鍠愰婊勭▔鐎ｎ亜绲洪柡鍐ㄥ閻ゅ棝鎯囬悤鍌滃耿
   * 闁宠法濯寸粭?闁活亞鍠撶紞澶愬冀绾绀刞MeshCoverBg`闁挎稑顦粭宀€鈧懓鍟Λ銈夊礂缁涘湱绐楃紓鍐╁灦閻楁悂寮垫径搴℃鐎规瓕浜▓?`src`/闁稿繑绮岀花宕囩磾閹寸偟澹愰柨娑樺缁楀绗熷┑濠勵洬闁哄牜鍓欓悺褍鈻撻悙鍏夊亾?
   */
  @Local tintReady: boolean = false;
  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁硅矇鍐ㄧ厬闁告牞娅ｅ﹢锛勨偓鍦仒缁楀倸鈻?*闁挎稑婢妏闁挎稑鐬奸悰銉╁矗閿濆懏缍忛柡宥呮祫缁辨岸鍨鹃弬琛″亾?闁?`SWIPER_GAP_ROW_ID` 闂侇叏绲鹃悧鎾础閻樿京绉撮柡澶涚磿濞?
   * `.onAreaChange` 闁告劖鐟辩槐娆撳矗椤忓浂鍤㈤梺鎻掔箲缁佹挳鏁嶇仦鐐骏闁告搩鍨紞鏃堟偨椤帞绀嗛柕鍡曠箹metaOffsetY()` 闁活潿鍔岄悾鐘诲磻?闁告帩鍋勭敮鍥ㄦ交濞戞瑥浠橀柛鎺曟硾鐏?闁汇劌瀚伴幐鎼佸礆闊祴鍋?
   * 闁宠法濯寸粭?闁告帗绻傞埀?-1 = 閺夆晜蓱閻ュ懘鏌岃箛鎾崇厒闁挎稒鐩崑鍛村籍閸撲焦鏆忛柟鎭掑妿閻ｅ宕愰悡搴″箲閹煎瓨娲忛埀顒€鍊块崳娲礆妫颁胶顓洪柛姘凹缁辨壆鎲撮敃鈧ぐ鍌涚▔閳ь剙鈻庨敓鐘叉鐎点倗灏ㄧ槐婵嬫煢閸愭彃鐓戦梻鍛箰瀹撳棝鎮介悢鍛婃珡闁?
   */
  // ⛔ 2026-10-18（第五轮）：`@Local chromeTopMeasured` 已删除（上面那条 JSDoc 是它的旧说明）。
  //   它唯一的读者是 `miniLyricTopY()` 里那条钳制的第 ② 档；小歌词改走"歌名行流式兄弟"后不再需要。
  /** 闂佸搫娲╃亸娆徝烘导鏉戠闁哄秲鍔嶉弳顏堟煢濡櫣绠冲褎顨婂鐢割敆閳ь剝銇愭径鎰闁哄秲鍔嶏拷緔呮惔顖氫壕闁稿鎳樺?*/
  // ⚠️ 紧邻上方那行单行 `/** … */` 是本轮 `edit` 误插入的**双重编码乱码注释**（本仓已知问题：这类字符
  //   无法被 `edit` 逐字匹配 ⇒ 删不掉）。它**只是注释**、不含代码、不参与布局；下次整段重排时顺手清掉。
  // ⛔ 2026-10-18（第五轮）：`@Local chromeBlockTopVp` 与 `@Local miniLyricBlockHVp` 已删除。
  //   两者都只服务 `miniLyricTopY()`（「控制区上沿 − 块高 − 8」那条钳制）；小歌词改成歌名行的
  //   **流式兄弟**之后，位置完全由 `estBoxHVp()` / `metaOffsetY()` / `LYRIC_META_ROW_H_VP` 决定，
  //   **不再需要任何实测上沿/实测块高**（块高由 `.height(MINI_LYRIC_BLOCK_H_VP)` 钉死）。
  //   `@Local chromeTopMeasured`（上面那条 JSDoc 说的那个量）同样只剩写、没有读 ⇒ 也没有了；
  //   它的写入点（`SWIPER_GAP_ROW_ID` 的 `.onAreaChange`）已一并删除，该行只保留 `.id` 供诊断日志读矩形。

  /** 闂佸搫娲╃亸娆徝烘导鏉戠闁哄秲鍔嶉弳顏堟煢濡櫣绠冲褎顨婂鐢割敆閳ь剝銇愭径鎰闁哄秲鍔嶉ˇ褔鏌涢幒妤佹暠闁哄苯锕ㄧ粻娑㈠礃閵娿劌鐓傞梺?*/
  @Monitor('state.selectIndex', 'favStore.favoriteVersion')
  onFavoriteChanged(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      this.isCurrentFavorite = false;
      return;
    }
    this.isCurrentFavorite = this.favStore.isFavorite(song.source, song.songId);
  }

  /** 闂佸憡甯掑ú锕€鐣烽弻銉ョ哗闁诡垳澧楅ˉ鎴︽煥濞戞澧㈤柛娆忛叄楠?`MusicPlayInfoBlock.toggleFavorite()`闂佹寧绋戞總鏃傛崲濮樿鲸瀚氬ù锝囨焿閳峰牆顭跨捄鍝勵伂妞ゃ垺鍨剁粙澶嬫姜閹殿噮浼囬梺鑲╂焿閹活亞妲愬璺何?*/
  private toggleFavorite(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      return;
    }
    if (this.favStore.isFavorite(song.source, song.songId)) {
      this.favStore.removeFavorite(song.source, song.songId);
    } else {
      const record = new PlayedSongRecord();
      record.songId = song.songId;
      record.name = typeof song.title === 'string' ? song.title : '';
      record.singer = typeof song.singer === 'string' ? song.singer : '';
      record.source = song.source;
      record.img = song.cover;
      record.url = song.url;
      record.lyric = song.lyricText;
      record.time = Date.now();
      this.favStore.addFavorite(record);
    }
  }

  // 闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑?闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿矉濡囩粈鍕煕濞嗘兛鎴濈暦閹绘帩鍤曢煫鍥ュ劤缁€鍡涙煟閵娿儱顏╅柛銈嗗灦閹?+ 缂備焦妫忛崹鎶藉磻閿濆棛鈻斿┑鐘插暙琚氶梺鎸庣☉閻楀棝顢氶鈧浠嬪炊閵婏讣楠忛梺?`floatingCover.onAreaChange 闂?publishMorphTargets`闂佹寧绋戦ˇ顐﹀绩閵忋倕鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵?

  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();

  // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯閻戣棄鍌ㄩ柣鏂挎啞闂勫秹鏌￠崼婵愭Х缂佹梹鎸冲顐も偓闈涙憸濞堝鏌曢崱妤勫鐟滄澘顦甸獮鎴﹀閻樼數顢呴柣鐔告礀濡稑煤婵犲嫪娌柛灞厩氶崑鎾愁吋閸ャ劎鏆犻梺鍛婄懄閻楁洟鍩€椤掑倸甯舵繛?闂佺偨鍎查弻锟犲焵?**2026-10-17 閻庣懓鎲¤ぐ鍐垂瑜版帗鈷?*闂?
  //      `coverLayerBase()` / `coverLayerScale()` / `coverLayerTx()` / `coverLayerTy()` /
  //      `coverLayerRadius()`闂? 闂佺硶鏅涢幖顐﹀闯椤栫偞鍎楅柍杞版祰閸?/ 缂傚倸鍊甸弲婊堝棘?/ 婵炶揪绲界粔鏈电昂 / **闂佸憡顨呴敃銈囨?婵?scale**闂佹寧绋戦ˇ顓㈠焵?
  //   闂佸憡甯炴繛鈧繛鍛叄閹爼宕卞▎鎰闂佹寧绋戦悧鍡涘垂瑜版帒绀堢€广儱顦崑鎾诲箛椤忓牆娈?grep 闂佺绻堥崝瀣垝閵娧勫厹妞ゆ梹顑欓崥鍥⒒閸℃艾鐓愮紒澶愵棑閹峰湱娑甸崨顏勪壕闁告粌鍟扮粈鍡涙煥?
  //   閻?闁诲海鎳撻崯鈺侇煥閹达箑鍙?*閻庤鐡曠亸顏堬綖閿曞倸绠婚柕鍫濇噺缁€鈧梺姹囧妼鐎氫即宕戦崨顔锯枖闁逞屽墴閹?*闂?闂佺硶鏅涢幖顐﹀闯?+ `.scale()` + `.translate()`"闂佹寧绋戦ˇ鍗炩枔閹寸偟顩茬憸蹇旀櫠閸ф鏅?
  //     闂佺粯绮嶆刊浠嬨€侀幋鐘冲皫?**`coverLocalRect()`**闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎮鹃悩鍏哥剨閺夊牄鍔嶇瑧 `lyricFloatRect()` 闂?*闂佺儵鏅滈幐鎶藉焵?*
  //     闂佹寧绋戦悧鍡涘及閸屾壕鍋?婵炶揪绲界粔鍫曟偪?闂侀潻绠戝Λ婊堬綖濡や胶鈻旈柍褜鍓欓銉р偓锝庡墯缁绢垶鏌熼幁鎺戝姎闁哥喐鎸诲?`.width/.position/.borderRadius`闂?*闂佸搫鐗滈崜婵囦繆椤撱垺鍊烽悷娆忓濮婇箖鏌￠崼婵愭Ъ闁搞倖绮岄蹇旀綇閳哄倻鏆?`.scale()`**闂佹寧绋戦¨鈧紒?
  //   閻?闂佸摜鍎愰崹顖滅博鐎涙ɑ浜ゆ俊顖滃劋闊剟鎮归崶顏嶅殭闁伙絿濮电粋鎺楊敆閸屾稓鏆犻梺鍝勫閸垳绮崨瀛橆棃闁靛繈鍊曟禍婵嬫煛?`RzdCoverRect` 闁荤姴娲ら敃銉╁蓟閸ヮ剙绫嶉柕澶堝劤缁犲爼姊洪幓鎺旂伇婵?`base=/tx=/ty=` 婵炴垶鎸搁ˇ浼搭敊?闂佺偨鍎查弻锟犲焵?
  //     闂佸吋婢橀惌鍌炲磻閸涱喚鈻斿璺侯儛閸炰粙姊洪幓鎺旂婵炲牊鍨甸～銏ゆ晲閸℃?闂佸憡鐟禍婵嗭耿娴ｅ壊鍟呴柤濂割杺濞煎爼鏌熸穱鍗炩偓鏇灻洪弽顓熺劷闁挎繂瀚閬嶆煟濡も偓閻楀﹥鏅堕悩璇插珘濠㈣泛鏈悾閬嶆⒑? 闂?闂佷紮绲鹃悷褍顭囬崘顔肩煑妞ゅ繐鍟扮粣妤呮偣閸ヨ泛鐏犳い鏇憾瀹曘儲鎯旈姀锟犳婵炲瓨绮庣亸銊ф濞嗗浚鍟呴棅顐幘椤忚鲸顨ラ悙鑸电【闁搞劌缍婇獮鎺撳緞濞戞氨顦梺?
  //   閻?闂?闁诲繐绻堥崐鏇㈠矗?`coverLayerRadius()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴鍊搁弲鎼佹煟椤愮喎浜鹃梺闈涙閼活垰銆掗崜褎鍠嗛柟鍝勭Ф缁嬪﹪鏌ｉ～顒€濡兼繝鈧?*闂佸搫鐗滄禍鐐电磽婢舵劕缁?*闂佹眹鍔岀€氼垱淇婇銏″€烽梺顐ｇ〒閻?闂?闂婎偄娲ら幊姗€濡磋箛娑欌挃闁靛牆瀚花?scale闂侀潧妫楃粙鍕?
  //     婵炴垶鎸稿ù鐑界嵁閸モ晜鍋樼€光偓閸愭儳鏅柣?*濠殿喗绻愮徊浠嬪Χ娴犲鍎庣紒瀣仢閸愨偓**闂佹寧绋掑銊╃嵁閸ヮ剙鎹堕柕濞垮妿缁犵懓鈽夐幙鍐ф捣濠碘槅鍙冮幃?*濠电偛澶囬崜婵嗭耿?* `.scale()` 闂?闂佺粯鎸嗛崘顏呮疁闂?闂傚倸瀚ㄩ崐鎾寸?scale"
  //     婵炴潙鍚嬬喊宥嗕繆閸濄儰鐒婇煫鍥ㄦ尵濞堥亶姊婚崼娑樼伈闁稿鎳愮划鈺咁敍濠婂嫮鏆犻梺闈╃畱濡粓锝炲Δ鍛哗闁诡垎浣锋捣闂?~6.7 闂佺锕ょ粙鍕濞嗘挻鍎戦悗锝庡墯缁插鏌涘鍛闂佸弶绮庢禍姝岀疀閹炬潙顩梺缁橆殔濞村嫮妲愬璺何?*闁哄鏅滈悷锕€危濮濆瞼鐤€闁告稒鐣埀顒€绻樺畷姘舵偐閸愯尙顏遍柣搴ｆ嚀閸熸澘鈻撻幋锔藉剮閻庢稒锚婢跺秹鏌涘Ο鐓庢瀻婵炲弶绮撴俊?*

  /**
   * 闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本鐟ч悷鎰版煙闊彃鍔橀柍褜鍓欓張顒勫箰闁秴缁╁Δ锝呭暔閳ь剙顦辨禍鍛婄瑹閳ь剙顭囬幍顔惧崥妞ゆ牗绮屾禒顖炴煏閸℃袪闁?
   *
   * 闂?闁诲簼绲婚～澶愭偉閿濆绫嶉柣妯虹仛濞?`floatingCover.onAreaChange 闂?publishMorphTargets()`闂?*闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本绻傚▓鎵偓鍦焾瀹曨剙顫濋妸鈺佸強妞ゆ牜鍋涘▍銈嗙箾閺夋埈鍎愮紒?*闂?
   * 闂佸疇娉曟刊瀵哥箔?**闂佸憡鐟禍婊冿耿椤忓棔鐒婂〒姘ｅ亾婵炶偐澧楅妵鍕偨閸涘﹪銈┑顔界箥濠胶妲愬鍊€ 闂?0`闂佹寧绋戦ˇ鏉款渻閸屾稓鈻斿┑鐘插暙琚?*闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁慨妞诲亾闁逞屽墯閺屟囨嚈閹寸偞浜ゆ繛鍡楁捣椤忛亶鎮橀悙鎻掆偓璇测枔閹寸偞濯寸€广儱娲ㄩ弸鍌炴煛閸曢潧鐏ユい顐畳閵囨劙濮€閻樿尙绉俊鐐垫嚀瀹曨剚鎱ㄩ埡鍛剭闁告洖澧庣粈?
   *    闂佺娉涢敃锔跨昂闂佸憡鏌ｉ崝瀣嚈閹达附鍎嶉柛鏇ㄥ幘閸欐劗鎲搁懜顒€鐏╅柛鐔告崌瀹曞爼鎮欏▓澶哥磽闂佺粯鍔欓埀顒佺〒缁愭鎲搁懜顒€鐏柛銊﹁壘椤垽鏁愰崨顓炲敤婵☆偓绲介悧鐐垫濞嗘垹鍗氭い鏍ㄧ矊娴狀垶鎮洪幒鎴練缂佹劕娲ㄩ幖鐐節閸屾瑧鍓ㄩ梺鎸庣☉椤︻參鍩€?
   */
  private reportPlayerCoverFromOverlay(area: Area): void {
    if (this.lyricMorphT > 0.001) {
      return;
    }
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*閻熸粏鍩囬崹纭呫亹婢跺鈻旀い鎾寸箘椤忚京鈧灚婢橀鍕箔婢跺鈻斿┑鐘插暙琚?*闂佹寧绋戦悧鎰帮綖?`coverAnchorMeasurable()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煏?
    //   闂佺粯鍔楅幊鎾舵?闂佽　鍋撻柟顖滃瀹曟娊鏌￠崘鈺佸姸妞も晩鍋婇幆鍕冀瑜忓﹢鏉懨归崗闂翠孩缂佹劧绻濋幆鍫ュ焵椤掑倵鍋撻崷顓熷殌婵炲懏甯楃粙澶愬焵椤掑倹灏庡瀣捣缁辨岸鏌ㄥ☉妯肩劯闁稿鎳樺顕€宕奸弴鐐搭仭闂佸憡甯楁竟鍡椻枔閹达附鍎楅柍杞版祰閸╁矂鏌?闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨惧畷鍥唸闂傚倸鐗勯崹浠嬪磻閸涱喚鈻曢柛顐ｇ缚娴?闂?
    //   闂佸憡鍔栭悷銊ф崲?`endCover*` 婵炴潙鍚嬬喊宥嗕繆閸濄儳纾兼い鎾卞焺濡囨倶韫囧海绐旀繛闂村嵆閹啴宕熼鐘电厜闂佺粯鍔楅幊鎾诲疮閹捐閿?闂?闂備緡鍙忕徊鑲╃博閺夋嚦娑㈠箳瀹ュ洨鎲归梺姹囧灮缁垶宕归妸锔绘Ч闁绘劖褰冮悡鍌炴⒑閹稿海鎳呮繛鍫熷灩娴滄瓕绠涢弴鐘插絹閻熸粓鍋婂鍧楀焵?
    if (!this.coverAnchorMeasurable()) {
      return;
    }
    const gx: number = areaLengthToVp(area.globalPosition.x);
    const gy: number = areaLengthToVp(area.globalPosition.y);
    const gs: number = areaLengthToVp(area.width);
    // 闂佸疇妫勯幊澶娢?2026-10-15 闁荤姴娲ら敃銉╁蓟閸ヮ剚鐓ユ慨妯哄船娴狀垶鏌ㄥ☉妯荤秮hdc shell hilog -x | Select-String 'RzdCoverRect'`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
    //   婵炴垶鎸撮崑鎾寸箾閸″繐澧插┑?*婵炴垶鎸搁ˇ顕€鏌屽鍫熷剹闁宠桨娴囬崺?*闂佺懓鐏氶幐鎼佸吹椤撱垹绾ч柕澶樺灣缁€澶愭煟椤剙濡芥繛鑲╂暬瀹曟岸濡堕崨顖涙瘞"闁诲繐绻嬬欢姘焽娴煎瓨濯伴柣锝呰嫰娴狀垰鈽夐幘宕囆㈡い?闂佸憡甯楀妯艰姳瀹曞洣娌柣鎰閼归箖鏌涘┑鎰胺缂佹柨顕划鏂款吋韫囨洜顦?*婵炴垶鎸堕崐妤咃綖閹烘挾鈹嶆い鏃傛櫕閵嗗﹪鎮楅悷鎷屽闁告瑥绻戠粙澶婎吋閸涱喖鈧?*闂佹寧绋戦¨鈧紒?
    //     閻?`measured` = `onAreaChange` 闂?`globalPosition`闂侀潧妫楅崐闈涒枔閹间焦鏅?闁诲海鎳撻崯顖毼?*闁汇埄鍨伴崯顐︽儑椤掑嫬绀勯柣妯夸含缁?*闂?
    //       **婵炴垶鎸哥粔鎾箚閸儱瀚夋い鎺戝暙铻￠梺缁樺姉椤㈠﹪宕靛鍐惧晠閺夊牃鏅滈悾?`.scale()` / `.translate()`**闂佹寧绋戦悧濠傦耿閻楀牏顩烽柟鎯х摠閺嗗牓姊洪幓鎺炲伐妞わ附瀵у鍕礋椤愩垻绠掗柣鐘差儏閸熷磭鎹㈤崘鈺備氦婵炲棗娴烽閬嶆煟閹邦喗顏熺紒杈ㄥ哺閺?
    //     閻?`geometry` = 缂備胶铏庨崹浼村吹閹寸偞濯撮柡鍥╁娴煎倿鏌ｉ幇顔筋仧缂佽鲸鐛媝layerCoverGeomRect()`闂?*婵炴垶鎸哥粔鐢告偂閳╁啰顩烽悹浣哥－缁夊潡鏌ら崫鍕偓濠氬磻?*闂佹寧绋戦懟顖烆敋椤曗偓瀵粙宕堕妸锔奸獜闂?
    //       `CoverMorph` 闂佺绻堥崝搴ㄥ煝閸忚偐鈻旂€广儱顦▍銈嗙箾閺夋埈鍎滅紒杈ㄥ哺閺?
    //     閻?`base/tx/ty` = 闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本绮嶉悾閬嶆煕濞嗗繐鈧粙鍩€椤掆偓閸熶即鏌堢€涙鈻旈幖瀛樼箘缁夊绱?闂佺偨鍎查弻锟犲焵?**濠电偞鎸稿鍫曟偂鐎ｎ偅濯?= base + translate**闂?
    //   **闂佸憡甯囬崐鏍х暤?*闂?
    //     闂?闂?`dxy` 闂?婵炴垶鎸搁敃锝囩箔閸涱垪鍋撻悷閭︽Ц闁告瑥绻樺畷鐘裁洪鍡楄拫闁硅壈鎻拋锝囨濞嗘挸绀勯柣妯诲絻绾?vp闂侀潧妫斿鎺旂箔閺嶃劎鈻斿┑鐘辫兌閻熸挸鈽夐幘鍗炩偓鎾绘煂濠婂牆妫橀柣鐔哄閸婂鏌?闂?**闂佸憡鍔曢幊搴敊閹扮増鍎庨柟鐑樺灣閻掑﹦绱?*闂傚倸鍋嗛崳锝夈€?
    //        闂?闁诲繐绻楁ご绋课?`PlaybackPageRoute` 闂備緡鍙忕徊鎯ь焽椤栨稏浜滈柛顭戝亞婢瑰矂鏌熺喊妯绘珔闁活偄绉归弫宥夊锤閸掝櫨pandSafeArea` + `ignoreLayoutSafeArea`闂佹寧绋戦ˇ顖氾耿椤忓棛涓嶉柍钘夋噽楠?
    //     闂?闂?`dxy` 闂?*闂佸憡甯╅崑鍡椻枔閹寸姵鏆滈柛娑橈攻濞?/ 婵?`tx,ty` 闂佸憡鑹鹃懟顖炲焵?* 闂?**闂備焦褰冪换鎴犵矈閹绢喖鐭楅柨婵嗘噽缁?*闂傚倸鍋嗛崳锝夈€?
    //        闂?闁荤姴娲ら悺銊ノｉ幋鐘冲珰闁靛绠戞儫**濠电偞鎸稿鍫曟偂鐎ｎ偅濯寸€广儱绻掔粈鍒se + translate闂?*闂佸吋婢樻總鏃傜箔婢舵劕鍙婃い鏍ㄦ皑椤忔挳鎮橀悙鈺佷壕婵炶揪绲界粔鍨叏閵堝棛鈻斿┑鐘插€哥粻鐢告煥濞戞澧曢柟顖欑窔瀹?缂備焦妫忛崹鎶藉磻閿濆鍋ㄩ柛妤冨仧濞堥亶姊婚崼娑樼伄闁伙絽顭锋俊?
    //          闁诲繐绻嬬欢姘焽娴兼潙鐭楅柛顐ゅ枎閻﹁崵绱掗弮鎴濈仯闁稿缍侀幏鍐箣閹烘梻孝"婵炴潙鍚嬮懝楣冩嚋娴兼潙绠?*濠殿喗绻嗗畷鐢哥嵁?*闂佹寧绋戦惌渚€顢氶妶鍜佸晠妞ゆ棁宕电粣妤呮偠濮樼厧浜為懣娆撴倵鐟欏嫯澹樻繝鈧幘顔界叆濞达綁顥撶粔?闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕傤敆濠婂牆鍙婃い鏍ㄧ⊕閹烽亶鏌￠崒婵愭綈缁绢叀娉涢埢鏃堝Ω閳轰焦鐝甸梻?
    //          闂佸搫鍟犻弲娑橆潩閵娾晛绀冩繛鍡樺笧缁犳牠鏌?闂佺厧顨庢禍婊呮崲娓氣偓閺屽矁绠涘顒侇唶閻?闂佹寧绋戦ˇ顓㈠焵?
    //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷锕€顭囬鐐茬睄闁靛鍎崇粻?*闂佸憡鐟禍锝夘敋閻楀牏鈻旂€广儱鎳庨弲?*闂佹寧绋戞總鏃傜箔婢跺簺浜归柛妤冨仦閹瑥霉閻樹警鍞虹紓宥呯Ф閹壆浠﹂懝鎵槹闂佹寧绋戝濉篹portBig` 闂佹眹鍔岀€氼剟宕ｉ崱娑樼煑闁稿本鐟ч閬嶆倵濞戞瑯娈曟繝鈧銏犵哗闁谎冩憸缁€鍡涙煏?
    const geom: LyricMorphRect = this.expandState.playerCoverGeomRect();
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闁诲繐绻嬬欢姘焽娴兼潙鏄ラ柛婵嗗濞呮瑩鏌涢幋鐘残＄紓宥呯Ч閹虫盯顢旈崶鈺傤潔**闂佹寧绋戦悧濠勬暜閹捐钃熼柕澶堝劚瑜扮娀姊哄▎鎯ф灈闁?`RzdCoverGeom`闂?
    //   婵炴垶鎸撮崑鎾绘煛婢跺棌鍋撻搹顐ゆ闂佺厧鐤囧Λ鍕垂?闁诲繐绻嬬欢姘焽閻楀牊濯寸€广儱娲ㄩ弸鍌炴倵閻㈢硶鍋撳☉姘辨喒闁?闂佹寧绋戞總鏃傜箔婢跺海鐤€闁告侗鍘奸弲娆撴⒒閸垹校闁糕晛鎳樺畷鑸点偅閸愩劍顏￠梺绋跨Т缁绘帞绮堝畝鍕櫖?
    //     闂佸搫鐗忛崰鎰耿濠婂牊鏅柛顐ゅ枎椤や線鏌?360闁?80 闁哄鏅滈悷锕傚Υ閸岀偞鏅鑸电〒缁愭edge=328`闂侀潧妫斿姊遍梺?36`闂? 婵＄偑鍊栭崕鑲╃博閻斿吋鏅璺虹墐閸嬫挻绋婇·銆唍ter=300`闂?
    //     閻?`edge` 闂佸搫瀚€涒晛螣婢跺绶炵憸宀€鑺?328闂佹寧绋戦悧鍛閵夛缚绻?393/369闂佹寧绋戦ˇ顐﹀闯?闁诲酣鈧稓鐭欐い锝傛櫇缁螖閳ь剙顕ｉ悽鍛婂仺闁靛绠戦悘?闂佽桨绀侀顓㈡偘閵壯€鍋?婵炲瓨绮屽Λ瀵告?
    //     閻?`y` 闂佽浜介崕瀵告崲?`(winH闂佹剚鍘芥慨鈧琩ge)/2`闂佹寧绋戦悧鍐╂櫠?298闂佹寧绋戦ˇ顐﹀闯?闂佸憡鐟ラ悧鍡氥亹婢舵劕鐐?闂侀潻璐熼崝搴ㄦ偘閵夆晛鐭楅柨婵嗩槸濞咃繝鎮橀悙鍙夊櫢闁?闂佹寧绋戦悧鍐疮?闂佹椿娼块崝宥夊春濞戙垹绠柕澹嫮鏆?婵炶揪绲界花鑲╄姳閳╁啰闄勯柦妯侯樈濡?闂佹寧绋戦ˇ顓㈠焵?
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverGeom edge=${geom.size.toFixed(1)} x=${geom.x.toFixed(1)} y=${geom.y.toFixed(1)} ` +
      `centerY=${(geom.y + geom.size / 2).toFixed(1)} radius=${geom.radius.toFixed(1)} ` +
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `padTop=${this.expandState.topInsetVp().toFixed(1)} padBottom=${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      // 闂?闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴顫㈠婕瀗terY` 闂佸搫瀚烽崹鍗烇耿閺夊簱鏋?*闂佺硶鏅涢幖顐﹀闯?*闂佹眹鍔岀€氼亪鎳欓幋锝囩杸闁告劧鑵归崑鎾诲磼濞戞瑥鐒搁梺鍝勭墛閸愯崵妲愬▎鎾崇閻庯綆鍋呯花姘舵煥? padTop + 244 闂?300闂?
      //   闂佸吋鐪归崕閬嶆偩閻樿绠抽柕澶堝妿缁?`win/2`闂佹寧绋戦悧鍐╂櫠?62闂佹寧绋戦ˇ顐﹀闯?闂佸憡鐟ラ悧鍡椕洪弽顓炵?缂備焦鍔栭〃鍛般亹濞戞矮娌柛娑卞墲閸?闂佹寧绋戦悧蹇涘极閵堝绠ｉ梺鍨儏琚氶梺?婵?闂佹寧绋戦ˇ顓㈠焵?
      `expectCenter=${(this.expandState.topInsetVp() + 244).toFixed(1)} ` +
      `(windowCentered-y=${((this.expandState.windowHeightVp - geom.size) / 2).toFixed(1)})`);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverRect measured=(${gx.toFixed(1)},${gy.toFixed(1)},${gs.toFixed(1)}) ` +
      `geometry=(${geom.x.toFixed(1)},${geom.y.toFixed(1)},${geom.size.toFixed(1)}) ` +
      `dxy=(${(gx - geom.x).toFixed(1)},${(gy - geom.y).toFixed(1)}) ` +
      // 闂佸疇娉曟刊瀵哥箔?2026-10-17闂佹寧绋掗懝鍓ф暜椤愶箑绾ч柕澶堝妿缁犲綊姊洪幓鎺旂劮缂佺粯娲熷?`base=/tx=/ty=` 婵炴垶鎸搁ˇ浼搭敊瀹€鍕櫖鐎光偓閸曨剦鍚?闂佸憡鐟﹁摫鐎规洘褰冮锝堢疀濮樺吋鑸归梺鐑╂櫆閻楁洟鎯?闂備緡鍙忕徊鑲╃博鐎垫瓕濮抽柛銉椤忛亶鎮硅閸㈡煡宕硅ぐ鎺撯挃闁靛牆瀚崯?
      //   闂佹寧绋戦悧鍡涙偩閻樺磭顩锋い鎺戝濞呫倝鏌ｉ妸銉ヮ仼鐟滄妸鍥у珘濠㈣泛锕ら崵鎺楁偠濮樼厧浜濋柟鍛婄懇瀹曞爼鎮欓崫鍕凹婵炴垶鎸撮崑鎾绘煟濡も偓閻楀﹥鏅堕悩璇插珘濠㈣泛鏈悾閬嶆⒑閹绘帡鐛滅紒杈ㄧ箘閹插瓨鎷呯憴鍕闂佸搫鍊稿ú锝呪枎?:247 闂傚倸瀚€氼垳鎹㈡惔銊︾劷闁挎繂妫崬浠嬫偣娴ｇ懓顎滃璺哄閺佸秵寰勯崼姘壕?
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `padTop=${this.expandState.topInsetVp().toFixed(1)} miniY=${this.expandState.miniY.toFixed(1)} ` +
      `miniSize=${this.expandState.miniSize.toFixed(1)} t=${this.lyricMorphT.toFixed(3)}`);
    this.expandState.reportBig(
      gx,
      gy,
      gs,
      this.coverRadiusState.radius);
  }

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16 闂佸搫鍊瑰姗€路閸愵喗鏅?*"缂傚倷绀侀悧蹇涘磻閿濆鐓ユ慨妯哄船娴狀垶鏌涘▎妯规捣闁稿繑锕㈠畷鐑藉Ω閵夈儱浼庨柣蹇撶箰閹碱偊顢氶銏＄劷闁挎繂瀚閬嶆偨椤栧棗鍊婚悷鎰版煙?** 闂佺偨鍎查弻锟犲焵?婵?
   * {@link PlaybackPage.reportPlayerCoverFromOverlay} 闂佹眹鍩勯悡澶屾濞嗘挻鐒介柨婵嗗閳峰牆顭?`reportBig` 闂佹眹鍔岀€氼剚鏅堕悩鐢电＞妞ゆ梻鍘ч悘鏌ユ煙鐠団€虫珯缂佽鲸宀告俊?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箘缁犳垵顪冮妶鍡橆潡妞も晪闄勫璇测枎閹炬彃顥氶梻鍌氬亞閻撳妲愬▎鎾村€烽柣鐔告緲濮ｅ﹪鏌熼崹顐ｅ碍缂佽鲸鍨甸埢浠嬪焺閸愨晝鐣抽柣蹇撶箣缁舵艾顭囨导鏉戠闁靛ě鍕瘞闂佹眹鍔岀€氼喖锕㈤敓鐘茬闁绘浜粔鍨渻鐎ｎ亪鍙勬繛鍛崌閺?
   *
   * 闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本绮嶉悾?`.id(PLAYER_BIG_COVER_ID)` + `onAreaChange` 闂佸搫鍟ㄩ崹鍝勎?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺〒濞堥亶姊?闂?*闂佸摜鍎愰崹顖滅博閹绢喗鐓傞煫鍥ㄦ⒒閵堝瓨绻?*闂?
   * 闂佸憡鐟ラ悧鎰帮綖閿曞倸绠伴柛灞剧闊?*閻熸粏鍩囬崹纭呫亹婢跺备鍋撻崷顓熷殌婵炲懏甯″畷姗€宕ㄩ弶鎴濆Г**闂侀潧妫楅崐椋庤姳椤掑嫬鍙婃い鏍ュ€楃粣?
   * ```
   *   闁诲骸婀遍幊鎾斥枍閹烘埈鍟呴柤纰卞墰閻ュ懘鎮跺鐓庝簻閻㈩垰娲畷姘跺箯鐏炴儳闂梺缁樺姉濞呫垻妲愬姝漚le 闂?0.08闂佹寧绋戦ˇ顔剧不閿濆瑙﹂幖鎼灣缁€澶娒归悩渚敽缂傚秴绉电粙澶愬焵椤掆偓閳?onAreaChange 闂佺缈伴崕鎵箔閸岀偛绾ч柕澹嫮鏆?
   *   globalPosition/width 闂備緡鍠涙慨銈呂ｉ幖浣肝ラ柟閭﹀灣绾板啫霉閿濆洤校婵炵⒈鍨虫禍鍛婄瑹閳ь剙顭囨导瀛樼劷闁挎繂瀚悿鍕倶韫囨挾绠為柍褜鍓氶崹鐟扳枔閹达附鍎楅柍杞版祰閸?
   *   闂?闁诲海鎳撻崯鈺冩娴兼潙绠?`endCoverSize/endCoverX/endCoverY` 闂佸憡鍔栭悷锕傚垂濮橆厽浜ら柧姘€荤粙鎴︽煛婢舵稓纾挎繛鍫熷灩娴滄悂宕崟闈涙
   *   闂?缂傚倷绶￠崣鍐夐敐鍥︾剨濞撴埃鍋撴繛闂村嵆閺佸秹宕奸悢鑽ゆ闁诲繒鍋涢崐鎼佸储閻樼粯鈷曢柛鈽嗗幘缁€鍡涙煟?*缂傚倷绀侀悧蹇涘磻?*闁荤偞鍑归崑鍕疮閹捐閿ら煫鍥ュ劤缁愭姊洪銊у缂佹梹娼欒灋闁圭儤娲﹀ú锝呪槈閺傝法澧旂紒妤€顦甸幃钘壭ч崶锝呬壕濞达絿鐡斿ú锝呪槈閺傝法澧︽い銉秮瀹曟碍锛愭担渚紘婵炴垶鎼╂禍顏堝极婵犲嫭瀚氭い鏍ㄧ矋閻ｉ亶鎮樿箛鎾剁闁绘挴鏅為妵?
   * ```
   * 闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸虫俊?*闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱 / 闂佺粯鍔楅幊鎾诲吹椤曗偓瀹曟骞庨懞銉川 / 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧梻渚囧枦婵倝鎯€閸涙潙瀚夊璺猴功濞堥亶姊婚崼娑樼仼濠殿喒鏅犻幃?*闂侀潧妫楃粔宕囩箔鐏炵偓浜ゆ繛鍡樺姈閽傚鎮楅悷鎷屽闁告瑥绻樺畷銉ф嫚閸欏鈧?闂佺偨鍎查弻锟犲焵?
   * 闂佺粯鍔楅幊鎾诲吹椤旂偓宕夋い鏍ㄦ皑缁愮偛鈽夐幘绛归練妞も晩鍋婇幆鍕冀瑜忓﹢鎾煛?*闂傚倸鎳庣换姗€濡存径鎰棃妞ゎ偒鍘鹃閬嶆偣瑜旈弨杈┾偓鍨礃濞?*闂佹眹鍔岀€氬摜妲愬┑鍫氬亾閻熸澘鏆熸繛鍫熷灩缁參顢栫捄顭戜紘濠?`onAreaChange` 閻庡灚婢橀悧鍡氥亹閺屻儲鍤勯柦妯侯槹閻ㄦ垿鏌﹂埀顒勬寠婢跺鍚?
   * "闁诲骸婀遍幊鎾斥枍閹烘埈鍟呴柤濂割杺濞煎爼鏌涘Ο渚剰闁糕晛鐬奸幐褎顦版惔鈥插寲"婵炴垶鏌ㄩ鍛村箖濡ゅ懎违?
   *
   * 闂?闂佸憡甯囬崐鏍х暤娓氣偓閺?*闁诲骸婀遍幊鎾斥枍閹烘鍙婃い鏍ㄧ◥閼割亞绱掑☉姗嗘Ц鐟滄澘顦甸獮鎴︼綖椤斿墽顦ーmorphScale 闂?1`闂佹寧绋戦ˇ顔剧箔閺嵮€鏌﹂柍鈺佸暞缁犳帡鎮锋担椋庮槮濠㈠厜鍋?*闂佸搫鍟抽崺鏍ㄦ櫠閻樿绀傚ù锝囩摂閸熷懎鈽夐幘绛规敾濠殿喓鍊濇俊?
   *   閻熸粏鍩囬崹纭呫亹婢跺鈻旀い鎾卞妿缁€鍒瀖orphClipping()` 婵炴垶鎹佸▍锝咃耿閿熺姵鏅璺侯槺椤忚京鈧灚婢橀鍕箔婢跺鈻斿┑鐘插暙琚?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯ь渻閸岀偞鐓傞煫鍥ㄦ尭閻撳倿鏌ｉ妸銉ヮ伃闁稿繑蓱缁嬪顓奸崱妯?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝囧劋閸╁倿鎮楅崷顓炰户闁绘挴鏅為妵?闂?
   * 闂佸疇娉曟刊瀵哥箔?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝囧劋閻?`morphScale` 闂佽鍘界敮濠勬嫻?1 闂?闁哄鏅滈悷鈺傜妤ｅ啯鈷掗柕濞垮劜闊剟姊婚崼鐔烘噭妞ゆ帗鐩獮鈧?*闂佽鍘界敮鐐诧耿?*闂佹寧绋戞總鏃傜箔婢跺簺浜归柛妤冨仦閹瑩鏌￠崘锕€鐏繝鈧担鐑樺仒閻忕偠澹堢粈瀣煏?
   * 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸哥€涒晛螞閿曞倸瀚夊璺烘湰閻?`lyricMorphT > 0.001` 闂備緡鍙忕紞浣圭妤ｅ啯鈷掗柕濠忛檮绗?*婵炴垶鎸堕崐鏍ь焽椤栫偞鍋戞い鎺戝€昏ぐ宀勬煛婢跺棌鍋撻崣澶樺仺**闂佹寧绋戦悧鎾诲磻閸涙潙绾ч柨娑樺閸氣偓"濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垹澹婂Λ褔鎮跺☉妯侯殭闁?闂佹寧绋戦¨鈧紒?
   *   婵炴垶鎸堕崐鏍ь焽椤栫偞鐒鹃柦妯侯槺缁犳垵顪冮妶鍫敽缂佺粯宀搁幃鎯р枎瀹ヤ礁浜?
   */
  private coverAnchorMeasurable(): boolean {
    if (this.expandState.morphClipping()) {
      return false;
    }
    return this.expandState.morphScale >= 0.999;
  }

  /**
   * 婵炴垶鎸搁敃銉︽叏閵堝拋娼伴悘鐐跺Г閸?濠殿喗绻傞張顒佹櫠濠婂牊鍎?*闂佸湱鍎ょ敮鐐存櫠濡ゅ啰鍗氭い鏍ㄧ矊娴?*闂佹寧绋戦悧鍡涙嚋娴兼潙鐭楁俊顖濐嚙鎯熼梺鍝勫€稿ú銈夋偤瑜旈幃浠嬪础閻愵亙娴烽梺鍛婄懄閿氶柣?闂佹眹鍨瑰畷顒勬儍椤掑嫬鐭楁俊顖涗航娴滐綁鏌￠崘顓炵厫閻庡灚绮撳畷銉т沪閼测晩浼囨繝闈涘€归〃鍛存偤瑜庨幏鍛村箻閸愬弶顥濋梺杞拌兌婢ф銇愰崘顔肩９缁绢參顥撶粈鍡涙煏?
   *
   * 闂?闁哄鏅滈悷銈囨偖鏉堛劎鈻旀い蹇撳暟閻熸劙鏌熼煬鎻掑姎閻㈩垼鍋婂鍫曞Ψ閵夛箒鍚?`MusicPlayInfoBlock` 闂備焦褰冪悮顐﹀焵椤掆偓閸婃悂鎮鹃悩宕囶浄閹艰揪绲垮畷鏇㈡倶閻愯尙绠婚柕?0 缂備礁顦…宄扳枍鎼淬劌瑙﹂幖杈剧磿缁犳垵顪冮妶鍥╁笡闁诡垰顦靛畷姘跺箯瀹€鈧粻褰掓⒑?闂佺偨鍎查弻锟犲焵?
   *   闂佸憡鐔粻鎴﹀垂椤栨粎鍗氭い鏍ㄧ矊娴狀垶姊洪幓鎺旂缂佹顦靛畷?闂?**闁诲繐绻嬬欢姘焽閹殿喚纾介柍鍝勫€搁悘?0闂佹寧绋戦悧蹇擄耿閸涱喚鈻旂€广儱鐗滃宀勬煥? 闁诲繒鍋炲ú鏍閹达箑绀夐柕濞у嫭姣庡┑鐐插閸撴繂锕㈡担铏瑰崥妞ゆ牗绮屾禒?*闂?026-10-15 闂備緡鍙忕徊楣冾敃閻撳海鏆﹂柍鍝勫€婚惃楣冩煟閵娿儱顏柣妤佹尦瀹曞爼鎮崨顖滎槴闂?
   * 闁诲孩绋掗妵鐐电礊鐎ｎ喖鐭楅柛灞剧⊕濞堣泛鈽夐幘鎶藉弰闁稿鎳忕粙澶愬焵椤掑倹鍋?*闁诲骸婀遍崑銈咁瀶椤栨哎鈧帡宕ｆ径灞藉脯闂佹眹鍔岀€氼剟鍩€?*婵烇絽娲︾换鍐偓鍨⒐缁嬪鍩€椤掑嫭鍤婇弶鍫濆⒔缁€鍒濴YRIC_META_TITLE_FP` / `LYRIC_META_ARTIST_FP`闂佹寧绋戦ˇ顓㈠焵?
   */
  private publishMetaEndpoint(singer: boolean): void {
    const song = this.state.getCurrentSongItem();
    const endpoint: MorphMetaEndpoint = new MorphMetaEndpoint();
    endpoint.id = singer ? PLAYER_META_SINGER_ID : PLAYER_META_TITLE_ID;
    endpoint.controller = singer ? this.singerController : this.titleController;
    const raw: string | Resource = singer ? (song?.singer ?? '') : (song?.title ?? '');
    endpoint.content = typeof raw === 'string' ? raw
      : this.getUIContext().getHostContext()!.resourceManager.getStringSync(raw.id);
    // 闂?2026-10-15闂佹寧绋掗惌顔剧箔閸岀偛绠?*閻熸粎澧楅幐鍛婃櫠閻樿櫕浜ゆ繛鍡楁捣椤忛亶鎮?*闂佹眹鍔岀€氼剟鎮鸿瀹曪綁宕欓妶鍥╊槱婵炴垶鎸堕崐妤咁敂椤掑嫬绠甸柟鐑樺灍閸嬫捇鎳栭埡鍌滄殸缂傚倷鐒﹂幐濠氭倶婢舵劖鏅鑸电〒缁€澶愭煠閺夊灝顨欑紒妤€顦靛浼搭敍濮橆厾銈奸柣搴ゎ潐濮樸劌鈻撻幋婵愭桨鐎光偓閸愵亝袚婵＄偑鍊濆褔鍩€?闂佺偨鍎查弻锟犲焵?
    //   闂佸憡鐔粻鎴﹀垂椤栨縿浜归柕蹇曞Т缂嶄胶绱掗弮鎴濈仯闁稿缍侀弻宀冪疀閹惧磭鍘掗梺姹囧妼鐎氼厼危閸涘﹦鈻旈柍褜鍓氱粙?闂佸憡鐟禍婊冿耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊曢悘姘櫠閻樿绠ｉ柟閭﹀枤瑜?闂佹眹鍔岀€氼剟鎮鸿瀹曪綁宕欓妶鍥╊槷闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏㈩焾娴滄繂鈽夐幘顖氫壕缂備焦妫忛崹顖滄娴兼潙纾婚煫鍥ㄦ尵濮ｅ牓鏌?
    endpoint.fontFp = singer ? this.metaArtistFp() : this.metaTitleFp();
    endpoint.family = singer ? PlayerConstants.FONT_FAMILY_BLACK : PlayerConstants.FONT_FAMILY_BOLD;
    endpoint.weight = singer ? 400 : 700;
    endpoint.color = singer ? $r('app.color.play_singer_color') : $r('app.color.play_text_color');
    endpoint.opacity = singer ? 1 : 0.86;
    endpoint.maxLines = 1;
    this.expandState.registerMorphMeta(false, singer, endpoint);
  }

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16 闂佸搫鍊瑰姗€路閸愵喗鏅慨姗嗗墰濞堥亶姊婚崼娑樼伇闁诡垬鍊栭幏鍛吋婢跺鍚?`lyricMorphT` 闂佸憡鐟﹂敋閻庡灚鐓″顕€鎳滈棃娑掑徍婵炴垶鎸撮崑鎾寸箾閸″繆鍋撻幇浣告闁荤姵鍔ч梽鍕涢埡鍕杸婵＄偛鐨烽崑?
   *
   * 闂佸疇娉曟刊瀵哥箔?`lyricMorphT` 闂?*闂備緡鍋呴崝鏇㈠箮?*闂佽　鍋撻柛锔诲幗閻ｉ亶鏌ㄥ☉妯煎ⅲ閽樼喖姊婚崒娑欏唉闁革絿鍏樺畷妯衡枎濞嗘垹顦梺鎸庣☉閺堫剚鏅跺鍡欘浄闁靛鍔庣粻褰掓⒑?*闂婎偄娲ら幊姗€濡?*闂佸搫鐗嗛ˇ铏繆椤撶伝?闂佺偨鍎查弻锟犲焵?
   *   闂佺厧鎼崐鍦矈閿旂晫鈻旈幖绮光偓宕囶唽闂備焦褰冪粔褰掑礂濮椻偓瀹?{@link PlaybackPage.logCoverLocal} 闂備焦褰冮惌澶屾?00ms + 缂備焦绋掗崕鎶藉箖閺囩倫鎺楀棘濞嗘儳娈搁梺鎸庣☉椤︻參鍩€?
   * 闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdCoverLocal'`
   */
  @Monitor('lyricMorphT')
  onLyricMorphTChanged(): void {
    this.logCoverLocal();
  }

  /** 闂佸搫娲╃亸娆徝烘导鏉戠煑婵☆垰鎼褔鏌￠崘銊у煟闁革絾鎮傞獮搴ㄥΨ閵堝牃鎷℃繛鎴炴惄娴滄繈寮搁崘顏佸亾濞戞瑯娈樻い蹇ｅ墴閹瑩鎯傞崫銉ь槱闂佸憡顭囬崰鎰焽閻㈢鎹?`MusicPlayInfoBlock` 闂?`@Monitor` 闂備焦褰冮惌澶屾濮樿泛违?*/
  @Monitor('state.selectIndex')
  onMetaEndpointChanged(): void {
    this.publishMetaEndpoint(false);
    this.publishMetaEndpoint(true);
  }

  /**
   * @returns 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垻顭堟禍婵嗏槈閹绢垰浜惧┑鈽嗗灱娴滐綁銆侀幋锔藉剭?*閻庡綊娼荤粻鎴﹀船鐎涙ɑ缍囩痪顓炴噽閻?*闂佹寧绋戝濡忛梺鎸庣☉椤︻參鍩€?
   *
   * 闂?`lyricMorphT` 闂侀潻璐熼崝瀣偖鏉堛劎鈻旀い蹇撴－娴煎倿鏌ｉ幇鎵冲亾濞戞凹鍚呴梻鍌氬€搁悺銊ㄣ亹閸愵喖纾圭痪顓㈩棑缁?
   * 閻?`t = 0`闂佹寧绋戦悧鍡涙儍濠靛顥堥柕蹇嬪€戦埀顒€顦甸弫? 婵＄偑鍊楅弫璇差焽閻楀牊缍囩痪顓炴噽閻涒晠鏌ㄥ☉妯绘拱闁烩剝娲熷畷銉ヮ吋閸涱垱鐙楁繛鎴炴惄閸樿偐浜搁姘兼桨闁挎繂瀚悷鎾绘煛閸屾粍顏熺紒?
   * 閻?`t = 1`闂佹寧绋戦悧濠囨偤閺囩姵瀚氱€广儱顦埀顒€顦甸弫? **闁诲繐绻愮换鎰版儍濠靛顥堥柕蹇曞Т缁€浣虹磽?+ 12**闂佹寧绋戦張顒勫几閸愵亖鍋撳☉娆樻畽妞ゆ柡鍋撻悗娈垮枓閸嬫捇鎮樿箛鎾剁闁汇劍绻堝Λ鍐綖椤戣棄浜?
   * 闂佸搫鍟版慨鐑藉疾椤愶附顥?`floatingCover` 婵?`metaRow` 婵炴垶鎸堕崐鏇㈡儑娴煎瓨鍎嶉柛鏇ㄥ劒椤撱垹瑙﹂柟杈鹃檮閺呪晛霉閿濆懐啸闁规椿浜畷姘跺级閹稿骸鈧崬鈽夐幘顖氫壕闂佽桨绀侀悧濠囨倶婢舵劖鏅€光偓閸愵亞顔愰梻浣瑰絻閻ジ寮妶澶婄闁告稒澹嗛悵鍫曟偣閻戞绠氶柕鍡楀暞濞煎繑绌遍幍浣镐壕?
   * 闁诲繐绻戦崹宕囩博鐎甸晲娌柛灞厩氶崑鎾存媴妞嬪海妲忔繝銏犵亪閺呮繈宕濊濮婃崘绠涘杈╊啋闁硅壈鎻粻鎺旀崲濞戞氨纾兼い鎾卞妿缁€鍕槈閹惧磭小缂佸彉鍗冲畷鐑藉Ω閵堝棗鏀┑鈽嗗亝鐢帡骞庡杈ㄥ磯闁稿繐鎳愰鍗炩槈閹炬剚鍎滅紒杈ㄥ哺婵?
   */
  private lyricMetaLeftInset(): number {
    const side: number = PlaybackPage.LYRIC_META_SIDE_VP;
    const t: number = this.lyricMorphT;
    const coverRight: number = this.lyricFloatRect().x + this.lyricFloatRect().size;
    return side + (coverRight + PlaybackPage.LYRIC_META_GAP_VP - side) * t;
  }

  /**
   * @returns 闂佺绻愰崯鈺傜┍婵犲洤绠掓い鏍ㄧ箥閺€浠嬫煕?*闂佺硶鏅涢幖顐﹀闯椤栫偞鍎?*闂備焦褰冮惉鐓庘枔閹寸偞濯寸€广儱娉﹂埡鍛櫖闁秆咁棗闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闁诲簼绲婚～澶愭偉閿濆绫嶉柣妯虹仛濞?`floatingMeta` 闂佸憡鍔曢幊搴ㄦ儑娴煎瓨鐒介柨婵嗘閽?
   *   `.offset({ y: metaOffsetYAt(swiperProgress) })`闂佹寧绋戝澧倁jie.pa:195907-196008`闂佹寧绋戦ˇ顓㈠焵?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐秵濞诧綁鏌涢幋婵堢閻㈩垪鍋?闁诲繒鍋涢幊宥夋嚈閹寸偞濯寸€广儱娲ㄩ弸?
   * 闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗閳峰牓鎮橀悙鎻掆偓鐟拔?*闂佸憡甯掑Λ妤佸?*闂佹眹鍔岀€氬摜妲?
   * ```
   *   婵犮垼鍩栭悧鏇㈡儑?Column().width('100%').height(overlayBaseH()).justifyContent(FlexAlign.Center)
   *        闂?闂佺娉涢敃銈夋偤濞嗘挸绀冮柛娑卞弾閸熷洭鏌涜箛鎾跺闁瑰弶绮撳畷姘跺级鐠恒劌鏁ら梺鍛婂灥濡稑煤閸涘瓨鍎?*缂備焦姊归悧婊兠洪幐搴ｂ枖妞ゆ挾鍋熸俊?*
   *   闂佸憡鍔曢幊搴ㄦ儑?Column().offset({ y: metaOffsetYAt(t) })
   *        闂?闂佸憡鐟禍锝夊Υ閸愨晜缍?闂佺儵鏅濋…鍫ヮ敋椤曗偓閺屽洭鏁愰崟顖氭疂闁诲繒鍋涢幊宥夋嚈閹寸偞濯寸€广儱娲ㄩ弸鍌炴煟閵娿儱顏╁ù婊冩憸缁?
   * ```
   * 闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡樺姈閽?`.offset()` 闂備焦褰冮張顒勫棘娓氣偓閹啴宕熼銈囩暠婵＄偑鍊楃划顖毼?*闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撶墕濞呫倗绱?* 闂?
   * ```
   *   metaOffsetY() = metaTopGeomY(t, rowH) 闂?(闂佺硶鏅涢幖顐﹀闯椤栫偞鍎庨柟鐑橆殘瑜?闂?rowH) / 2
   *                                         闂佸疇顫夐弻锟犲绩閵忋倕鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍?闁诲繒鍋涢幊宥夋嚈閹达箑瑙﹂幖娣€ら弨钘夘渻閵堝棗鍔剁紒鏃傚枛閹嫮绮欏▎鎯ф闂佺儵鏅滅敮锟犲Υ婵犲洦鍎嶉柛鏇ㄤ簽缁夊绱?闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂?
   * ```
   * 闂?闁荤偞绋戦惌鍌炲Υ婵犲啯缍囬悷娆忓娴犳绱撴担鍝ュⅲ闁诡垬鍊濆畷?`metaTopGeomY(t, rowH)`闂佹寧绋戞總鏃傜箔鐏炲墽鈻斿┑鐘辫兌椤忛亶鏌ｅΔ鈧悧鎾诲磻閸涙潙绾?
   *   `.position({ y: metaTopGeomY(...) })` **闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯兼暩閹肩厧霉?*闂佹寧绋戦悧濠傜暦閺屻儲鍎嶉柛鏇ㄥ墯绗戠紓鍌欑劍閹稿鎮楅娑氣枖閹肩补鈧磭绋夐悗鍨緲鐎氬摜妲愬┑鍥┾枖鐎广儱妫欑瑧闂佽桨鐒﹀姗€鍩€椤掑倶鈧妲愬璺何?
   *
   * 闂佸疇娉曟刊瀵哥箔?**婵炴垶鎸哥粔鐑筋敊韫囨稑绀冪€广儱瀚?`1/morphScale`**闂佹寧绋掗悺鐚癳taTopGeomY` 闂佹眹鍔岀€氼亞鎮潏銊р枖妞ゅ繐妫导鍌炴煟閹邦剛绉洪柛蹇旓耿瀵?闁诲骸婀遍幊鎾斥枍閹烘绠掗柟鐑樻⒒閹煎ジ鏌?闂佹眹鍔岀€氼剟宕甸幋鐐村闁哄浂浜炵粈?
   *   閻庤鐡曠亸娆戝垝閿熺姴鍙婃い鏍亼閳ь剙顦靛畷?缂備焦鍔栭〃鍛般亹濞戙垹瑙﹂悘鐐跺亹椤忓崬鈹戦崒娑辨當婵炲吋顨婂浠嬪炊妞嬪骸鑰挎繛鎴炴⒐鐪夌紒顭掔磿娴滄悂宕ｅΟ鑲╃崶闂備焦褰冪粔鍫曠嵁閸ヮ剚鍋ㄩ柕濠忕畱閻撴洟鎮楅崷顓炰沪缂佷焦鎸抽幆鍐礋閳规儳浜?*闂佺绻愰悧鎾凰夐敐澶嬬劵闁绘梻鈷堝Λ褔鏌涢幒鎾寸凡闁汇劍绻堝Λ鍐綖椤斿墽顦梺缁樺笩濞夋盯骞冨Δ鍛鐎广儱瀚悷鎾绘煛?*闂侀潧妫楃粔鏌ュ焵?
   * 闂佸疇娉曟刊瀵哥箔?闂佺硶鏅涢幖顐﹀闯椤栫偞鍎庨柟鐑橆殘瑜邦垶鏌?`estBoxHVp()`闂? 闂佸憡鐟崹鎶藉极閵堝棭娈?闂?闂佺鐭囬崘銊у幀闂佸憡鐗滅亸銊ф濠靛洨鈻旈幖娣灪閿熴儵鏌?`overlayBaseH()` 闂佸憡鑹炬總鏃傜不閻斿吋鏅璺虹墐閸?
   *   闁诲海鎳撻崯宕囨崲閺囩偐鏌﹂柨鐔哄Т濞呫倝鏌涢幒鏂款暭婵＄偛鍊圭粙?0 闂佺偨鍎查弻锟犲焵?婵炴垶鎸搁澶婎焽娴煎瓨鍋?`(baseH 闂?rowH)/2` 闂佺儵鏅涢悺銊ф暜鐎靛摜涓嶆俊銈咁儑缁€? 婵炴垶姊婚崰鏇㈠吹濠婂厾娲棘閵堝洨顦╂繛鎴炴尭缁夊磭妲?NaN闂佹寧绋戦ˇ顓㈠焵?
   */
  private metaOffsetY(): number {
    const rowH: number = PlaybackPage.LYRIC_META_ROW_H_VP;
    const baseH: number = this.expandState.estBoxHVp();
    const centeredTop: number = (baseH - rowH) / 2;
    // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁绘挆鍕骏闁伙絽鐭夌槐鐗堟媴瀹ュ泦鈺呭矗椤忓懏绠掑☉鎾亾闁?`metaOffsetYAt(t)`闁挎稑鏈惀鍛村嫉婢跺宕插ù锝嗘礋閹告悂宕?*闁?
    //
    // 闁哄牜鍓濋悿鍡涘箮婵犱胶鐟愭繛鎾存倐閸嬪懏绋夋径濠勬勾闁稿繈鍔戦崕瀛樼鎼达紕鎽熼柤鍝勫€婚悥婊堟煂鐏炶棄绲垮ù婊冩閸ゎ參寮堕妷顖滅闂侇偅鍔栧顖溾偓闈涚秺缂嶅牓鏁?
    // ```
    //   floatingMeta闁挎稑婀?71797-171846闁挎稑鑻惈姗€骞€?L195907-196008闁?
    //     Column().width('100%').height(this.overlayBaseH())
    //             .justifyContent(FlexAlign.Center).hitTestBehavior(Transparent)
    //       Column().width('100%').alignItems(Start)
    //               .offset({ y: this.morph.metaOffsetYAt(this.swiperProgress) })
    //         metaRow()
    //   overlayBaseH()闁挎稑婀ayerPage闁? swiperBoxH > 0 ? swiperBoxH
    //                                : (!chromeHidden && swiperProgress <= 0.001 ? 0 : estBoxH())
    //   metaOffsetYAt(t)闁挎稑婀憃verMorph闁? lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
    // ```
    // 闁?濞戞挸锕ラ悥?*婵炲备鍓濆﹢浣圭鐠佸磭绉?闁告帩鍋勭敮鍥ㄦ交濞戞瑥浠橀柛鎺曟硾鐏?闁汇劌瀚伴幐鎼佸礆?*闁挎稒鐭紞鍛磾椤旇偐鏆氶柛蹇嬪妿閺侀亶鏌囬敐鍕伇闁?lerp + 閻忕偛鎳嶉懙鎴︽儎閹烘垵鏋€閻庤鍝庨埀?
    //   闁瑰瓨鍨垫晶鐘诲礄閻橀潧顣奸柛鏃傚Х濞堟垿鏌﹂崘鎻掔厬闁挎稑鐗嗛幏浼存偨閵娿儳鏉芥繛?chromeTop 闁汇劌瀚晶妤呭嫉椤掑﹦绀嗛梺顔垮Г濡?*闁瑰瓨鍨奸崵婊堝礆濞戞碍鐣?*闁?
    //   闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳濡寸仦鐐毉鐎电増銇炵粭澶屸偓鐢垫缁辨繂袙閺傚墽顓洪柛鎾崇Х缁绘洖顔忛琛″亾瀹ヤ讲鍋撻弬琛″亾閺冣偓閹告瑩宕堕悜鍥╃闁诡厹鍨归ˇ鑼棯椤栨艾娈ゅù锝嗘磸閳?
    //   闁宠法濯寸粭?閻熸瑥顦欢?闁告ê顑勭紞鍥ㄦ交濞戞ê顔婇柡?闁哄啳顔愮槐婵堟啺娴ｇ袟闁汇劌瀚Σ?*閻忓繋绶氬鎵博椤栨粌浠?/ gap(50) / 闁硅矇鍐ㄧ厬闁告牗妞介。鈺冪不?*閺夆晜鐟ょ粭渚€鎳撻崨顒傤吅濞戞挴鍋撻柨?
    //     濞戞挸绉靛Σ鎼佸捶閵婏妇鎽冮柛姘Х椤㈡垶绋夋繝鍌氼潱缂佹鍏涚花鈺傜▔椤忓啰绉寸紒澶岀帛缁噣濡?
    const absTop: number = this.expandState.metaTopGeomY(this.lyricMorphT, rowH);
    return absTop - centeredTop;
  }
  /** False after teardown to ignore async image callbacks. */

  /**
   * @returns 灏忔瓕璇嶅潡搴旇惤鐨?*椤靛唴**椤惰竟锛坴p锛夆€斺€?鐢ㄦ埛瑕佹眰銆屽皬姝岃瘝鏀惧埌姝屾墜琛屼笅鏂广€嶃€?
   *
   * 椤?0 鐨?`Stack` 鏀逛负 `TopStart` 鍚庯紝杩欎竴鍧楃敤 `.position({x:0,y:...})` 缁濆瀹氫綅锛?
   * 鐩爣 = 姝屽悕琛岄《杈?+ 琛岄珮 + 闂磋窛锛屽啀鍑忓幓椤电洅椤讹紙`lyricBoxTopVp`锛岀粨鏋勪笉鍙橀噺甯告€?0锛夈€?
   * 鈿狅笍 闈欐鎬佸氨鏄€屾瓕鎵嬭涓嬫部 + 12vp銆嶏紱褰㈠彉鎬佷粛鐢?`contentRiseVp()` 浠庝笅鏂瑰崌璧凤紙绐?0.45鈫?.00锛夛紝
   *   鑰屾瓕鍚嶈璧扮殑鏄洿鏃╃殑 `metaRiseVp()`锛?.18鈫?.62锛夆噿 鍏ㄧ▼涓嶄細杩藉埌姝屽悕琛屼笂闈€?
   */
  // ⛔ 2026-10-18（第五轮）：`miniLyricTopY()` / `miniLyricTopLoggedY` 已**整段删除**。
  //   小歌词不再"按窗口绝对 y 绝对定位"，而是歌名行的**流式兄弟**：
  //     小歌词顶边 = 歌名行顶边 + `LYRIC_META_ROW_H_VP`（见 `LyricFloatLayer()` 里那段注释）。
  //   ⇒ 位置只由 `estBoxHVp()` / `metaOffsetY()` / `LYRIC_META_ROW_H_VP` 三个量决定，
  //     不再有 `miniLyricTopY` 那套"锚点 + 间距 + 控制区上沿钳制"的第二套坐标系。
  //   （上面那条 JSDoc 是旧的 `RzdMiniLyricTop` 打印说明，已无代码引用，留作备查。）
  /** False after teardown to ignore async image callbacks. */
  private isAlive: boolean = true;
  /** Bumps on each {@link getImageColorAsync} run so stale async work skips UI updates and releases pixels. */
  private imageColorJobSeq: number = 0;
  /** Cached UIAbility context for resource and color extraction. */
  private context: common.UIAbilityContext | undefined = undefined;
  /** Logger tag for this page. */
  private static readonly logTag: string = 'PlaybackPage';
  /** 闂佽　鍋撻柟顖滃瀹曟娊鏌熼璺槮闁哥偛顕埀顒€婀遍幊鎾绘儑娴兼潙纭€闁绘鏁稿畷鍫曟煕濞嗘瑧绉柣婵愬枟閹棃鏁傞悙顒傛殸闂佽皫鍕姢闁搞劌楠歌闁哄啯鎸剧粣妤呮偣閹邦厽缍戠紒銊ㄦ珪缁嬪鍩€椤掑嫬绾ч柍钘夋噽缁€澶婎熆閸棗妫楀В鈧紓浣圭☉椤︻喚鑺遍浣逛氦闁炬艾鍊荤粙鎴︽煛婢舵稓绡€闁稿鎳忕粙澶愬焵椤掑嫬绾ч幒鎶藉焵?*/
  private static readonly COLLAPSED_HEIGHT_PERCENT: number = 9;
  /** 闁诲繒鍋炲ú鏍閹达箑绀夐柕濞у嫭姣庨梺姹囧妼鐎氼垶骞戦敐澶嬪€风痪顓炴噽缁犲骞栨潏鎹愵吅缂? 闁诲海鎳撻懟顖炲矗韫囨稑缁╅柟顖滃瀹曟娊鏌ㄥ☉姗嗘Ф闁?*/
  private static readonly EXPAND_START_PROGRESS: number = 100;
  /** 闁诲繒鍋炲ú鏍?闂佽　鍋撻柟顖滃瀹曟娊鏌涢弬璇插闁轰線绠栧顕€宕奸弴鐔哥槪闂佹寧绋戝鐨婇梺鎸庣☉椤р偓缂佽鲸绻冪粙澶嬫償閳ヨ櫕顥濋梺鍏兼緲閸燁偅瀵奸幇顔剧煓?`OPEN_PLAYER_UI_ANIMATION_MS` 婵炴垶鎸撮崑鎾绘煠闁垮鏆橀柍?*/
  private static readonly EXPAND_DURATION_MS: number = 380;
  /**
   * 闁诲骸婀遍幊鎾斥枍閹烘洏浜归柕蹇曞Т缂嶄線鎮橀悙瀛樼缂佽鲸鍨块幆鍐礋椤掍緡妲梻鍌楀亾闁告牭绱曠粈鍒磗闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸搫鍟版慨鐑藉疾?Tokens 闂佹眹鍔岀€氼亞鈧潧鏈顏堫敆閳ь剙鈹冮埀顒佷繆濡ゅ瀵肩紓宥呮嚇瀵?300ms / 420ms闂佹寧绋掔粙鏍崲閺嶎厽鐓傞悘鐐舵缁?420ms 闂備緡鍙忕徊楣冨Υ閸岀偞鍎嶉柛鏇ㄥ櫘濞煎酣鏌熼幍顔兼珢缂佽鲸鐟╁顐﹀箻椤旇　鍋撴径鎰嵍闁靛ě鍛闂佽　鍋撻柟鎯ф噽缁€?
   * 濠殿噯绲鹃弻銊╂儑椤掑嫭鐒鹃柕濞垮劚鐢绱掓潏鈺佇ｇ€规洖寮堕幏鍛吋婢跺绮柣鐔告磻閻掞箑煤閹稿骸绶炴慨姗嗗幗椤ρ囨⒒閸屾繃褰х紒杈ㄥ哺閺佸秶浠﹂悙顒勬暅缂備焦宕樺▔鏇㈠极閵堝洠鍋撻悷鏉挎殶婵?`cubic-bezier(0.23, 1.0, 0.32, 1.0)`闂佹寧绋戦悧鍡涘箵閳哄懎绀勯柧蹇撴贡婢跺嫰鏌涜箛瀣姷缂佽鲸宀告俊?
   */
  // ★★★ 2026-10-18 更正（字节码直证）：**上游「点击打开」这条路上没有 350ms 的 `doEnter`。**
  //   ```
  //   setupExpandTransition 的 `param.pull === true` 分支（wujie.pa:179258-179317）
  //     只做 expand.init() + pullMode=true + pullGeomReady=false 然后 return；
  //     **没有** NavTransition.register。
  //   doAnimation / doEnter 的唯一调用者 @37*#^2（wujie.pa:193340-193367）
  //     只被 NavTransition.register 写进 registry（wujie.pa:179427，**只存在于 param.srcId 分支**）；
  //   navContentTransition 在 registry 里取不到 param 就 `return undefined`（wujie.pa:52444-52482）
  //     ⇒ 该 push 走系统默认转场，而 beginMorphEnter 是 pushPath(..., animated=false)（wujie.pa:146617-146622）
  //     ⇒ doEnter 一次都不跑。
  //   ```
  //   ⇒ 形变路径的**容器几何**只由 `onPullTChanged → expand.applyPullProgress(effT())`
  //     （wujie.pa:174826-174889）驱动；`effT = isMorphTarget() ? pullT : 1`（wujie.pa:171535-171549），
  //     而 `pullT` 就是 `morphT` = `animateMorphT(1, ENTER_MS=560, EASE_OUT_STR)`
  //     （wujie.pa:163524-163547 调用 / 154167-154169 常量 / 145608-145661 本体）。
  //   ⇒ **几何与内容是同一条 560ms + `cubic-bezier(0.23,1.0,0.32,1.0)`。**
  //   写 350/EaseInOut 的后果（= 甲方说的"飞入时间不对"）有两层：
  //     ① 封面早 **210ms** 落位（350 vs 560）；
  //     ② 前段几乎不动（EaseInOut 是 S 形慢起；上游 ease-out 在 20% 时间就到 66%、50% 到 88%）。
  private static readonly MORPH_OPEN_DURATION_MS: number = 560;
  /**
   * 闁诲骸婀遍幊鎾斥枍閹烘洏浜归柕蹇曞Т缂嶄線鏌￠埀顒勫箚閻楀牆闂梺鎸庣☉閻楀棗顕ｆ禒瀣Е闁规惌鍨崇粈鍡涙煟閵娿儱顏俊鐐插€垮褰掑礌閿涘嫮顦﹎s闂佹寧绋戦¨鈧紒杈ㄦ緲琚欓柡鍌濇硶濞兼梻鈧鍠掗崑鎾绘煟閿濆啫鍔氶柟鐑╂櫊閺佸秶浠﹂悙顒佹瘑闁荤姍鍥ㄦ暠婵炶偐鏁搁幉鐗堟媴缁嬪灝褰欓梺鍏兼綑濡酣鍩€?
   */
  /**
   * 闂佺绻戞繛濠偽涢幘顔芥櫖闁割偅绻傞崘鈧梺鍛婄閸ㄧ敻鎳滄导鏉戠煑婵鐗忕粈鍡涙煟?*闂佺硶鏅炲▍锝夈€侀崨鏉戠睄闁割偅娲樺В?*婵?*闂佸搫鍟悥濂稿汲鏉堛劎鈻旈悗锝庡枟椤庢瑦鎱ㄩ敐鍡樼叄缂?*闂佹寧绋戦悧鍡涱敋椤曗偓瀵粙宕堕妸锔奸獜闂?`MainPage` 闂佹眹鍔岀€氼亞鎮潏銊р枖妞ゅ繐瀚崺妤呮⒑閹绘帡鐛滅紒杈ㄥ哺婵?
   *
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸绻冪粚閬嶎敊鐞涒€充壕閻忕偠妫勮ぐ鐘绘⒒閸屻倕骞楅柟鎼佷憾瀵劑骞嗚閻濄倝鏌涢幋鐘残＄紒鐙€鍠栭埢浠嬪灳閸愭畫妤呮煟閵忥紕婀介柍褜鍓欑粙鍕濮樿埖鏅?
   *   `reverseMs = round(REVERSE_MS 闁?max(REVERSE_MIN_RATIO, morphT))`
   *   闂佹寧绋戝濉ecover/logic-src/閻庢鍠掗崑鎾绘煕韫囨碍鐝柟鎼佷憾瀵劑骞嗚閻?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄦ皑缁愮偤鎮楃憴鍕殤妞?md` 闁? 闂備緡鍋嗛崰鎰版偂?L29 / 闁圭厧鍊垮畷?闁汇埄鍨遍幃鍌炲闯閾忚鍋?L620-625闂佹寧绋戦ˇ顓㈠焵?
   *   闂?濠电姴艌閳ь剙纾鏃傗偓娈垮枓閸嬫捇鏌?**460ms**闂佹寧绋掔粙鎴ｃ亹瑜旈獮蹇斿緞婵犲嫮锛涙繛鎴炴尨閸嬫捇鏌ｉ幇顒佽础闁稿缍侀弫宥夊锤閸掔rphT < 0.4`闂佹寧绋戦ˇ鏉款渻閸岀偛绠板璺侯槺閻熸捇姊?**460闁?.4 = 184ms**闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?闁荤偞鍑归崑鍛瑰☉銏犵闁靛繆鈧磭顏遍梺姹囧妼鐎氼厼螞椤愩倖鏆滈柟闂寸濞?`MORPH_CLOSE_DURATION_MS = 350` 闂佸搫鐗嗛ˇ顔炬偖鏉堛劌绶為柛鏇ㄥ灡閺呪晠鏌ㄥ☉妯煎ⅵ闁稿繑蓱缁嬪顓奸崱妯?闂佽桨鐒﹀姗€鍩€椤掑倸甯跺ù婊勬礈閹?闂佹寧绋戦¨鈧紒?
   *   闂?**闂佸搫鍟悥濂稿汲闁秴纾婚煫鍥ㄦ礈閸?*闂?50 vs 闂佸搫鍟版慨鐑藉疾椤愩埄鐓ラ柍銉ョ－濞兼梻鈧鍠掗崑?460闂佹寧绋戦懟顖炴儍椤栨稓顩?24% 闂佹眹鍔岀€氼垶銆侀幋鐘电煓閻庯綆鍋呴ˇ褔姊婚崒婵囧涧缂?
   *   闂?闂佸搫娲ㄩˉ鎰般€呴敃鍌氬窛闁伙絽鏈悾閬嶆煛?*缂傚倸鍊归幐鍛婃叏閳哄懎鏋侀悗娑櫳戦拏瀣煙鐠哄搫顏柡?*闂佹寧绋掔喊宥呂涢锝囶浄闁挎繂娲ㄩ崹鎶芥煟?`cubicBezier(0.23, 1.0, 0.32, 1.0)`
   *      闂? `EASE_OUT_STR`闂佹寧绋戦惌鍌炲磻閸涙潙鍙?*闂佺懓鐏氶幐鍝ユ閹达箑绠甸柟閭︿簼閸?*闂佹椿娼块崝搴♀枔閹达箑鍗抽柤纰卞墮濞堢娀鏌ㄥ☉姗嗘缂佽鲸绻勯埀?*闂?15% 闂佸搫鍟悥鐓幬涚捄銊ょ剨閺夊牜鍋夊▔鏌ユ倵閻熸壆鐏遍悗?70% 闁荤偞绋戦惉濂稿煝?*
   *      闂?350ms 闂備焦褰冮惉鑲┾偓?50ms 闁诲繐绻楁禍顒傜磽婢跺备鍋撻悷鎷岊潶闁逞屽厸缁€浣规櫠閹稿海鈻?300ms 闂佸憡鍨规慨宕囩不椤曗偓濡啫鈻庨幇闈涘 = 闂佹椿娼块崝宥夊春濞戞碍瀚氶悗闈涙啞閻?**闂佸憡鍨规慨宕囩不椤斿皷鏌﹂柍銉ュ暱琚熼梺?*"闂?
   *   闂佸搫鍟版慨鐑藉疾?闂佺绻戞繛濠偽涢幘顔肩闁归偊浜濋崬?闂佹椿娼块崝搴♀枔閹达箑鍙?**`REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`**闂佹寧绋戦悧濠囧矗閸愵喖瑙︽い鏍ㄨ壘琚熼梺鎸庣☉椤︻參鍩€?
   *   闁诲海鎳撻張顒勫汲閿濆洠鍋撻棃娑欒础闁告瑥瀛╃粙?闂佸憡甯╅崑鍛村箖鐠哄懙搴ㄦ憥閸屾粎鎲︽繝銏ｆ硾鐎氼喚妲愰敃鍌氱?闂佹眹鍔岀€氼垶顢氶埡鍛強閹肩补鈧櫕娅㈤梺?`closeFullScreenPlayback()` 闂備焦褰冪悮顐﹀焵?
   */
  private static readonly REVERSE_MS: number = 460;

  /**
   * `page 0` 闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱娲︾粊鏌ユ倵闂堟稓绉洪柕鍡楊槹閹棃寮撮悩宕囨殸**婵炴垶鎸搁鍛暜閸ヮ剚鐓?*闂佹寧绋戝濡忛梺鎸庣☉椤︻參鍩€?
   *
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍛村箞閵娾晜鍋ㄩ柕濠忕畱閻撴洟鎮楅崷顓炰沪缂佷焦鎸虫俊瀵镐沪閻愵剙鍟婇梺琛″亾闁告挆鍕彧闂傚倸鐗勯崹鑲╂崲閺嶎厽鐓傜€光偓閸曨剚娅撴繛杈剧到缁夋煡鍩€椤掆偓缁嬪嫮妲愬鑸垫櫖婵ɑ鍓氬?`MiniLyricLinesComponent` 闂備緡鍙忕徊浠嬎囬埡鍐╁闁告劦浜濋弳蹇涙煟閹邦剚璐℃繛鍫熷灥閳绘棃濡搁埡浣圭彽 闂佺偨鍎查弻锟犲焵?
   *   闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱鎳庨弬褔鏌℃径鍫濆姤闁告帗绋掗妵鍕濞戞矮浜㈤梺鎸庣☉閺堫剟顢楀鍕檮闁稿﹦鍠愰崕浼存煕?`Swiper` 婵炴垶鏌ㄩ鍛此囨繝姘劷闁挎繂妫欓拏?*濠殿喗绻傞懟顖炲箖?濠殿喗绻傞張顒佹櫠濠婂懏鍟洪柛鈩冪懄绾句即鎮?*闂佹眹鍔岀€氫即鎮甸鑺ュ劅闁挎洍鍋撻柣銏╁亰閺屽苯鐣濈€ｎ剛顦╅梺?60~690vp闂佹寧绋戦ˇ顓㈠焵?
   *   闂佸憡鐟﹂悧鏇㈠焵?= `PlayerExpandState` 闂備焦褰冮張顒勬偤閺囥垹瑙︾€广儱鎳忛崑銉╂煟閵娿儱顏柣婵愬枟閹棃鏁冮埀顒冦亹濞戞﹩鍤楅柛鏇炲缁€鍒濴YRIC_META_BLOCK_H_VP = 44`闂佹寧绋戦¨鈧紒?
   *   闂佽浜介崝宀€妲?婵炴垶鎸堕崐娑€侀幋锕€妫橀柛銉戝懏鎲?闂備緡鍙忕徊鑲╃不閻愭潙绶炴慨姗嗗墮缁侇噣鏌涘▎妯虹伈缂侀亶浜跺Λ鍐ㄢ枎閹伴潧澹橀梺璇″厸缁€渚€鎮鹃悩璇茬煑妞ゅ繐鎳忕瑧婵炴垶鎸撮崑鎾斥槈閹垮啩绨绘繛瀛樺姉閳ь剝顫夐惌顔剧礊閸涱垳鐭撳ù鍏肩懅缁€?*婵炴垶鎸哥粔鏉戭嚕椤掍胶鈻旈幖瀛樼箖瀹曟彃霉閿濆棙绀夐挊鐔兼⒒?*闂?
   */
  private static readonly MINI_LYRIC_SINK_VP: number = 44;

  /** 灏忔瓕璇嶅潡 鈬?姝屽悕/姝屾墜琛?鐨勭珫鐩撮棿璺濓紙vp锛夛紝鐢ㄦ埛瑕佹眰"钀藉埌姝屾墜琛屼笅鏂?銆?*/
  // ⛔ 2026-10-18（第五轮）：`MINI_LYRIC_GAP_VP` 已**删除**（上面那行是它的旧 JSDoc，留作备查）。
  //   小歌词与歌名行之间不再有任何间距常数 —— 位置由"歌名行的流式兄弟"给出。
  /**
   * 小歌词块行数（当前行 + 下一行，见 `MiniLyricLinesComponent`）——
   * ★ 2026-10-18（第五轮）：这两个量现在**只用来解释 `MINI_LYRIC_BLOCK_H_VP = 57` 是怎么来的**，
   *   不参与定位（定位已改为"歌名行流式兄弟"，见 `LyricFloatLayer()`）。
   */
  private static readonly MINI_LYRIC_LINES: number = 2;
  /** 小歌词单行占位高（vp，= 字号 18/17fp 按 1.4 倍行高取整）。 */
  private static readonly MINI_LYRIC_LINE_H_VP: number = 26;
  /**
   * 小歌词块高（vp）= `MINI_LYRIC_LINES(2) × 26 + 行距 3 + 上边距 2`。
   * ★★ 2026-10-18（第五轮）：它现在有**两个**用途，都写在 `LyricFloatLayer()` 调用点：
   *   ① `.height(MINI_LYRIC_BLOCK_H_VP)` 把块高钉死（否则居中盒会被它撑高、歌名行被上抬）；
   *   ② 位移壳的 `offset` 补 `MINI_LYRIC_BLOCK_H_VP / 2`（把 ① 让出的那半抬回来）。
   */
  private static readonly MINI_LYRIC_BLOCK_H_VP: number = 57;
  /**
   * 小歌词块的不透明度系数：调用点 `.opacity(pullChromeOpacity() × MINI_LYRIC_OPACITY)`
   * ⇒ 静止态 `pullChromeOpacity() === 1`，落到 **0.55**（用户实测要求"更淡"）。
   * ★ 2026-10-18（第五轮）：`MINI_LYRIC_GAP_VP` / `MINI_LYRIC_CEILING_PAD_VP` /
   *   `MINI_LYRIC_COVER_META_GAP_VP` 三个"定位用"常量已随 `miniLyricTopY()` 一起删除 ——
   *   小歌词的位置现在由歌名行那条流决定，**不再有任何间距/钳制常数**。
   */
  private static readonly MINI_LYRIC_OPACITY: number = 0.55;
  /** 闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱鎷嬮崯鍥煕閿濆啫濡挎繛鍫熷灩缁辨帡宕熼鍜佸仺 id闂佹寧绋戦悧鍡氥亹瑜忕槐?{@link PlaybackPage.logLayoutBoxes} 闂備焦褰冪换鎴犵矈閹绢喗鍋ㄦい顓熷笧缁€澶娾槈閹惧磭孝鐎殿噮鍓氱粙澶嬫償濠靛洤搴婃繛杈剧稻濞茬喖鍩€椤掍焦顫楃紒棰濆亰閺佸秵寰勯崼姘壕?*/
  private static readonly MINI_LYRIC_BOX_ID: string = 'rzd_page0_mini_lyric_box';

  /** 缂傚倸鍟崹鍫曟偋閹间焦鍤勯悘鐐靛亾閻濐垶鎮橀悙鎻掆偓璇测枔閹寸姷纾奸柛鏇ㄤ簼椤?id闂佹寧绋戦悧鍡氥亹瑜忕槐?{@link PlaybackPage.logBgLayer} 闂備焦褰冪换鎴犵矈閹绢喗鍋ㄦい顓熷笧缁€鍡涙煏?*/
  private static readonly MESH_BG_ID: string = 'rzd_mesh_bg_layer';

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*GLM5.3 婵炴潙鍚嬫穱娲儊閺嶎厼鐭楅柟瀵稿Т缁犳盯鏌ㄥ☉娆戭暡闁搞劍绮嶇粙澶嬬節娴ｄ警浼囬柡澶屽剱閸ｏ綁宕戦崨瀛樼劶闁瑰墽绮敍宀勬煛?濠殿喗绻傞…宄拔?**闂?
   *
   * ## 婵炲瓨绮岄鍡涘疾閻樼數纾奸煫鍥ㄦ皑缁犳牠鏌ㄥ☉妯煎妞も敪鍛亾閸︻厼浠╂い鏂挎喘閺佸秶浠﹂挊澶屽姸闂佸憡鍔曠粔鑸垫叏闁秵鏅?
   * 闂佺懓鐡ㄩ崹鍦垝娴兼潙绀冮柛娑卞弾閸熷洭鎮?`.onAppear()` 闂佹眹鍔岀€氼剟宕㈢憴鍕劅闁哄洨鍋涢悗濠氭煛閳ь剟顢涘顒夋奖闁哄鏅涘ú锝囩博閹绢喗鐒?闁荤姵浜介崝宀勬偪閸曨剛鐟归悗锝庡亝椤ρ囨⒒閸屾凹鍤熼柣?闂傚倸鍋嗛悡澶屾濠靛绀嗛柕鍫濇缁侊箓鏌涢幇顓犳噮婵炲牊鍨垮?
   * `PlaybackPage.lastCloseAtMs > 0 && Date.now() - PlaybackPage.lastCloseAtMs < CLOSE_WINDOW_MS`闂?
   * GLM 闂佸湱顭堝ú銈夊吹椤撱垺鏅?*闂佽桨鑳剁换婵嬪船閵堝绀傞柟鎯板Г閿涙柨霉閻欏懐鎮奸柣鏍ㄧ矒閺屽瞼浠﹂崜褎鈷曢梺鍝勭墕椤︻噣骞戦姀鈩冨闁哄洦姘ㄩ閬嶆偠濞戞瀚伴柛?`lastCloseAtMs`闂佹寧绋戦惌渚€鍩€?`CLOSE_WINDOW_MS` 婵炴垶姊婚崰宥囧垝閻樿瀚夋い蹇撳缁憋綁鏌?*
   * 闂?闂備緡鍙忕紞浣圭妤ｅ啯鈷?*闂佽鍘界敮鎺撶?*闂佹寧绋戦惉濂告偤閹寸偟顩查幖瀛樼箘閻棗鈽夐弬璺ㄥⅵ闁稿繑锚閳讳粙鍨鹃崘宸奖闂侀潧妫楅崐褰掑垂濠婂牆钃熼柕澶堝妿濡插牆霉濠婂啯顥炴俊鐐插€垮鑽も偓鐢殿焾濞堢娀鏌ㄥ☉娆忓摵闁稿鎳忕粋鎺楁寠婢跺鐭楁繛杈剧稻缁瞼浜搁婊呯＝闁哄稁鍓涚敮鍡涙煥?3:54闂?
   *   **闂佸搫鎳忛惌顔捐姳椤掑嫬瀚夐柍褜鍓熷畷銉︽償濠靛牜浼囧┑鐐叉閸撴繈宕瑰璺虹闁绘柨鎽滈埀顒夊灠椤曟瑩鎮€靛摜顦?3:49闂?* 闂?**闁诲海鎳撻崯鈺冨垝閻樿瀚夋い蹇撴祩濞煎墎绱撻崒娑氬⒊闁幌佸嫭浜?*闂佹寧绋戦惉濂稿极閵堝绠ｉ柣銈庡灱濡懘鏌涢幒鎾愁棆婵炲牊鍨垮畷鐘诲川閺夋垶顏為梺鍝勭Х椤锕㈤弶搴撴煢闁斥晛鍟粻鎺楁倵閻熸澘鏆旈柍?
   * 闂?闂佽桨鐒﹂悷銊╊敊閸曨垱鏅?*闂佽　鍋撻梺顐ｇ〒閸熷﹥绻濊閸旀鎮ュ鍡欑杸闁告稒鐣埀顒€绻楅妵鎰板箻閾忣偆鐨婚梺鍝勵儏鐎氼剛绱?*闂?闂佺懓鐡ㄩ崹鍨叏閻愬顩查柛鈩冪⊕閿?婵?闂傚倸鍊堕崝灞斤耿椤忓懐顩茬憸蹇旀櫠閸ф鐓?闂佸搫瀚烽崹顖滄偖鏉堛劎顩烽柡鍫㈡暩閻ㄦ垿鏌?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劜娴犳﹢鎮?闁荤姵浜介崝宀勬偪閸曨剛鐟?闂佹眹鍔岀€氼剟宕规禒瀣?
   * 闂佸搫鐗滈崜鐔煎Υ婢舵劕绠ラ柍褜鍓熷?`@Local` / 缂備礁顦悞锕€锕㈡担琛″亾濞戞瑯娈曟い鏂跨焸閺屽牓鎳為妷蟺?*闁诲骸婀遍崑妯兼閵壯傛勃闁逞屽墴閺?*闂佹眹鍔岀€氬摜妲愰柆宥嗗殌?`morphReset()` 婵炴潙鍚嬬喊宥嗕繆?
   * `PlayerExpandState` 闂備焦褰冮惌鍌炲磻閸涱喚闄勬俊銈咁儑缁€鍒瀖orphSessionStarted` / `morphStage` / `morphGeomReady`闂佹寧绋戦ˇ顖炲矗韫囨挶鈧帡宕ㄩ鑲╊伇闂?
   * 闂?闂佺绻戞繛濠偽涚€涙ɑ濯存繛鍡樺姇閻ㄩ箖鏌﹂埀顒勬寠婢跺鍚?*闂佸搫鍊瑰姗€鎮块崟顒傜懝?*闂傚鍓﹂崑鍌滅箔閸岀偛绫嶉悹浣告贡缁€澶愭倵閸︻厼浠掔紒韬插劤娴狅箓鍩€椤掑嫭鐒鹃柕濞у嫮鏆犻梻鍌氬€堕崝宀勫矗韫囨稒鐒鹃柕濞垮劘娴滃ジ鏌￠崟顐ゆ槀闁?
   *   闂佸憡鐟禍锝夊礂濮椻偓閹粙濡搁妶鍥朵紘婵?*闁荤姵浜介崝宀勬偪閸曨剛鐟归悗锝庝簻瑜版瑥霉?*闂佹眹鍔岀€氼厼顪冮崒鐐茬閻犲洩寮撶划鐢告煕閹哄鈧牕鐣?闂?闂佸搫鐗滈崜鐔奉焽閵堝绠戝ù锝呮憸閹界喐绻涢崼銏犱化闁?
   *
   * 闂佸疇娉曟刊瀵哥箔?**婵炴垶鎸堕崐鎾绘煂濠婂應鍋撳☉娆樻畷妞ゆ柨鐭佺粻娑㈠川濞ｎ兘鍋撹箛娑樼闁归偊鍓﹂崵鐘裁归敐鍫熺《闁?*闂佹寧绋掗悺鐚痑stCloseAtMs` 闂?*闂佺绻戞繛濠偽涢幘顔界叄闁硅鍔楅悢?*闂?
   *    闂佹寧绋戝濉﹍oseFullScreenPlayback` 闂佺绻堥崕杈亹濞戙垺鏅鑸电〒缁€濉LOSE_WINDOW_MS` 闂佸憡鐟禍婊冿耿椤忓嫷娼伴柕鍫濇媼濡茶京鎲搁悧鍫熷暗闁绘稏鍎靛畷锝夋晲閸滀礁鏅柟鑹版彧鐠愮喖鍩€?
   *    闂佸憡甯╅崑鍕疮閳ь剟鏌涢幋锝嗩仩妤?闂佸憡鐟禍锝夘敋閻楀牏鈻旂€广儱鎳庨弲?闂佹寧绋戦悧鎾诲磻閸涱収娼伴柨婵嗘绗戞繛鎴炴尭閿曪絿绮╃€涙ɑ濮滄い鏃傚亾閻ｅ崬霉濠婂喚鍎愰柡鍛█閺佸秵寰勯崼姘壕?
   */
  private static lastCloseAtMs: number = 0;

  /**
   * 闂?2026-10-17闂佹寧绋掗惌顔剧箔閸屾稓鈻旈柍褜鍓欓埢搴ㄥ灳閸愭彃缍橀梻?*闁荤姍鍥舵殥缂侇煉绻濋弻鍛村焵椤掑嫬绀岄柡宥庡墰閻斿懐鈧?*闂佹眹鍔岀€氼剛鏁锕€鐐婇柣娆忔噽缁€鍕煟椤撗冨箺闁绘牭绲跨划鐢稿箻閸涱垰鑰跨紓?= 濠电偛鐪查妶鍫熷发闂備緡鍋€閸嬫捇鏌涢弽銊у缂佽鲸宀告俊?
   *
   * 闂?`closeLiveMorphFallback()` 闂佸憡鍔栭悷锝夊焵椤戞寧顣糲loseFullScreenPlayback()` 闂?`ev('CLO', 闂?` 闁荤姴娲╅褔鎳?*濠电偞鎸搁幊鎰板煘?*
   * 闂?閻庡灚濯芥慨銈夋偉閿濆洨绠旀い鎺嗗亾鐎规洖瀚粙澶嬪緞鎼搭喗鏂€闂?`CLO:闂?fb=<闂佸憡顭囬崰搴∶?` 闁诲繐绻楁ご绋课?闁哄鏅滈悷锕傤敃閸忓吋浜ら柡鍌涘缁€鈧梺绋跨箲婵炲﹤螞鐎靛憡灏庨柟娈垮枟閻ｉ亶鏌￠崟闈涚仩闁圭儵鏅犻幃陇顦剁紒缁樻礋瀵即顢涘☉娆嶄户婵?闂佹眹鍔岀€氼喖煤閸ф绠抽柕澶樼厛閸ゃ垽鏌℃担钘夌劷闁?
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟禍婊冿耿?闂備緡鍋€閸嬫捇鏌涢弽銊у⒌闁稿鎳忕粙澶愬焵椤掆偓閳?闂佸搫鐗嗛ˇ顖炲焵椤掑倶鈧妲愬┑鍫熷珰閻犲洩灏欓弳姘舵煕濡ゅ嫭鐝紒鏂款煼閺佸秹宕煎┑鍥у墾闂佸憡甯楅悷銈囨閹殿喗鍋栨い鎰╁灮缁夊ジ鏌熺€涙ê濮囬柣鏍煐閵囨瑩鎳￠妶鍛咃箓鏌熼璺ㄧ瓘缂佽鲸宀告俊?
   */
  private static closeFallbackReason: string = '';

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺绻戞繛濠偽涚€涙ɑ浜ら柛銉㈡杹閺屻倝鏌ｉ妸銉ヮ仾婵＄偛鍊归幆?婵帗绋掗崹鐢典焊閸懇鍋?** 闂佺偨鍎查弻锟犲焵?闂佺懓鐏氶幐楣冩偋?濠电偛澶囬崜婵嗭耿娴ｇ儤濯奸柟顖嗗本校闁荤姴娲ㄧ划顖炲汲?闂佹眹鍔岀€氼剟宕楁繝鍕勃闁逞屽墴閺?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箘缁犳垵顪冮妶鍫殭濞寸姵鐩獮?闁荤姵浜介崝宀勬偪閸曨剛鐟归悗锝庡枟妤楊垶鏌熼璺ㄧ獢闁衡偓閿濆洠鍋?
   * 闂佹椿娼块崝宥夊春濞戙垹绠柕澹嫮鏆犳繛鎴炴尪閸婃牕顭囬鐐存櫖闁割偅绋堥崑鎾朵沪閽樺缍橀梻鍌氬亞閸樿棄顪冮崒鐐村殑閻忕偟鍋撻悵顖炴煕濞嗘ü绨诲褎瀵х粙澶愬焵椤掑嫬绾ч幒鎶藉焵椤掆偓缁夋煡鍩€椤掆偓閼活垶宕ｈ濮婂顢橀悙鏉戔偓鐢告煕濞嗗繒澧涢柡鍌欑劍缁嬪鍩€椤掑嫭鐒肩€广儱鎳愬鏃傗偓娈垮枓閸嬫捇鏌曢崱妤冣枌缂?*闂備緡鍠涘Λ鍕亹閸岀偞鍋ㄩ柣鏃堟敱闊剟鏌涜箛鏂库枙婵☆偄鐡ㄥ濠氬炊閳圭偓鐓犳繛?*闂?
   * 闂?*闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柛蹇撴憸椤?pop闂佹寧绋戦懟顖炴儓閸℃鈻斿┑鐘叉搐娴滄繂鈽夐幙鍐х盎缂佹劖锕㈠浠嬪炊瑜庨惃鎴︽偣閾忕懓鏋旀繛鐓庡暙閳讳粙鍨鹃懠顒€鏅?* 闂?婵炲瓨绮岄鍛村箖濡ゅ啯瀚氶悹浣哥－閻熸繈鏌涢幒妤婃殥闁瑰箍鍨洪幏鍛村即濮橀硸鍋ㄩ柣鐔割殙閿熴儵鍩€?
   * 闂?闂佺娉涢敃銈夊矗瑜旈弻銊╊敊閼姐倗娈ゆ繛瀵稿У閸庡ジ顢欓崶銊︿氦?*濠碘槅鍨埀顒冩珪閸嬨儳绱掗悪娆忔处妤楊垶鏌熼鑳厡妤犵偛妫滈妵鎰板閵忋垹顦╅梺?*闂佹寧绋戦惉濂告偤?*婵炴垶鎸搁鍕博閺夋垟鏋庨柍鈺佸暙閳數鈧鍠掗崑鎾绘煙缂併垹骞楅柡鍌欑劍閵?*闂佸憡鍔曠粔闈浳熸径宀€鐭?闂?闁诲繐绻楁ご绋匡耿娴ｅ湱顩?婵炴垶鎸搁敃锝囩博閺夋垟鏋庨柍銉ュ暱瑜扮娀姊?闂佹眹鍔岀€氼剟鎮鹃鍕瀬閻庢稒蓱椤ρ囧箹閺夋垹绠為柍?
   *
   * ## 闁荤姳绶氶。锔惧垝閸喓鈻曢柛顐墰缁€鍕煕濞嗘ü娴锋い?闂佺粯顭堥崺鏍焵椤戞寧绁版繛鏉戞缁?婵?闂佺绻戞繛濠囧极椤撱垹绀勯柛婵嗗缂?闂?*婵炴垶鎸哥粔鐑筋敊閸ヮ灝鎺曠疀閹炬潙顫?*闂佹寧绋戦懟顖炲箚娓氣偓瀹曟艾鈻庨幋婵堢暰閻熸粏鍩囬崹鑽ゆ閿曞倸绀冮棅顐幘缁愭鎮跺鐓庝簻闁糕晜鐩獮鎺撳緞濞戞氨顦?
   * ```
   *   CLO  = closeFullScreenPlayback 闂佺绻堥崕杈亹濞戙垺鏅柛顐ｇ箓閺呯鈽?lastCloseAtMs闂?
   *   LV   = morphBeginLeaving闂佹寧绋戦悧濠囧极閸︻厽灏庡瀣缁佹彃霉閿濆懐鈻岀紒?
   *   SET  = 闂佺绻戞繛濠偽涢幘顔肩哗閻犻缚娅ｉ崯鏌ユ倵鐟欏嫮顣叉俊鐐插€垮畷鎶藉Ω閵夈儳鍘掗梺缁樺姉濞呫垻妲愬▎鎾粹挃?closeGen / alive / 闁荤姍鍥舵殥缂侇煉绻濆畷顐︻敂閸愵亶浼囬梺琛″亾妞ゆ牓鍊楃粈?
   *   LND  = morphLand闂佹寧绋戦悧鎰板箚閵堝鐐婇柣鎰绾板啫霉閿濆洤校婵炵⒈鍨堕弫?
   *   SQZ  = squashLandAnim闂佹寧绋戦悧濠勪焊鐎ｎ喖鍌ㄩ悗锝庡幗瀹曟娊鏌?
   *   RST  = morphReset闂佹寧绋戦悧鍡涘吹閹寸偞濯撮柡鍥╁仦缁€鈧梺璇″幗鐢偤鎮洪幋锔芥櫖?
   *   POPT = 婵犮垻鎳撻崯鍧楁儑娴兼潙绠?isShowPlay 缂?false闂佹寧绋戦悧鎰杺闂?popPlayerRoute闂?
   *   REM  = 婵犮垻鎳撻崯鍧楁儑娴煎瓨鍎戦柣鏃傚劋閻ｉ亶鏌熺捄鐚存敾闁规悂浜跺銊︺偅閸愶腹鍋撴径灞惧磯妞ゆ牗绮嶉弳鐘绘煕閹烘柨校閻㈩垪鍋撴繛瀛樼矊濡妲愬淇籵pPlayerRoute` 闂備焦褰冮惉鐓庘枔?`pop/removeByIndexes`闂?
   *          闂?**`RST` 婵?`REM` 闂?`t+` 閻?*闁诲繐绻楁ご绋课?濠电姴艌閳ь剙纾灞解槈閹垮啫寮俊顐㈡健楠炩偓?闂佸搫鐗嗛ˇ顖炈囬崸妤佲拹闁告牭绱曠粈鍕煟椤剙濡介柛鈺傜〒缁?闂?闂佸搫顧€缁辨洖鈻撻幋锕€绀嗛柕鍫濇缁侊箓鏌?
   *   DIS  = 闂佸憡鍔曢幊搴敊閹邦喕娌?onDisappear闂佹寧绋戦悧鎾愁瀶?wasAlive闂?
   *   AP   = 闂佸憡鍔曢幊搴敊閹邦喕娌?onAppear闂佹寧绋戦悧鎾愁瀶椤旂偓灏庡Λ棰佽兌閸熷﹪鏌涘┑鎰凹婵炵⒈鍨跺畷姘跺幢濡粯娈伴梺?
   *   INTR = playExpandIntro 闁荤姍鍐ㄦ缂?*闂佸吋鐪归崕閬嶅吹椤撱垺鍋濋柡澶嬪闊剟鏌涜箛鏂库枙婵☆偄鐡ㄧ粙濠勨偓锝庝簼閸婄敻鏌ㄥ☉妯垮婵ǜ鍔戝?闂佸憡鐟ラ悧濠囧棘娴ｅ湱鈻旈柍褜鍓熼弻鍡楊吋閸涱垱缍岄悗娈垮枓閸?闂佹眹鍔岀€氼喖煤閸ф绠抽柕澶堝妿濡插牓鏌?*闂?
   *   OPN  = 婵犮垻鎳撻崯鍧楁儑?isShowPlay=true闂佹寧绋戦悧鎰杺闂?pushPlayerRoute闂?
   * ```
   * 濠殿噯绲界换姗€濡村鍥ㄦ殰闁挎棁娉曢鍗炩槈閹垮啩绨芥繛鏉戭槺閳ь兛绲婚～澶婎渻閸岀偞鈷掗弶鍫濆⒔缁€鍒磗闂佹寧绋戦惉鐓幟规径灞稿亾闂堟稒璐＄紒鎲嬬畵瀹曟﹢骞撻幒鎴︽闂備焦褰冮惉濂割敄閸ャ劎鈻旈柍褜鍓熷鍫曞煡閸涱垳顦梺?
   *
   * ## 闁荤姴娲ㄧ划顖滄兜閸洘鏅柛顐ｇ箘閻涳箓鏌?*缂備焦顨忛崜娆忕暦閸曨剛鈻斿璺哄瘨閺€?*闂?
   * 缂傚倸鍊归幐鎼佸疮閸ф绀?*婵炲濮伴崕鎵博閺夋垟鏋庨柍銉ュ暱瑜扮娀姊婚崒銈呭箳閻犳劗鍠栧畷锟犲即濮樿京孝**闂佹寧绋戝濉丩O` 婵炴垶鎸撮崑鎾绘煕閹烘挻绶叉慨妯稿妼閵嗘帡宕ㄩ妤佹櫈闂備焦褰冪粔闈涱焽閻㈠憡鏅鑸电〒缁€澶愭煙绾版ê浜炬繛瀵稿О閸庢挳顢氭导鏉戠闁规鍠楅悾杈ㄦ叏濡崵鎽冪紒缁樼懇瀵?闂佸搫鐗冮崑鎾诲级閳哄倸鐏ｇ紒鏃€娼欓埢搴ㄥ灳閸愭彃缍橀梻?闂佹眹鍔岀€氼剟宕ｈ箛鏃€浜ら柛銉㈡杹閺屻倝鏌?
   * 濠殿喗绻愮徊浠嬫偉閸洖绀傞柟鎯板Г閿涙棃鏌涘顒勫弰闁革絾鎮傚顒勬偋閸績鍙洪悗娈垮枓閸嬫捇鏌ㄥ☉妯垮缂併劏灏妵鎰板箻閼哥數鐣介梺鍛婂笚濠㈡﹢鎳滈悧鍫滅箚闁稿矉濡囩粣?
   * ```
   *   t0 CLO 闂?t+2 LV 闂?t+480 SET:ok/gen=3 闂?t+481 LND 闂?t+482 SQZ 闂?t+483 RST 闂?t+484 POPT 闂?t+490 DIS:alive=0
   * ```
   * 閻庢鍠栭崐鎼佹偉閹埇浜归柕蹇嬪灩绗戞繛鎴炴尭妤犳悂骞嗛崼鐔衡枙濠㈣埖绋撶粣?
   * - 闂佸憡鍨煎▍锝夌嵁?**`INTR`**闂佹寧绋戦悧鍡楋耿?DIS 婵炴垶鏌ㄩ鍛村箖濡ゅ懏鏅璺烘濞?缂佺虎鍙庨崰娑㈩敇婵犳艾鍙?闂佺绻戞繛濠偽涚€涙ɑ濯存繛鍡樺姇閻ㄩ箖姊洪幓鎺斝ｉ柡鍌欒兌娴狅箓寮撮悙鐢碉紱"闂?
   * - 闂佸憡鍨煎▍锝夌嵁?**`OPN`**闂佹寧绋戦悧鍡楋耿椤忓牆绀傞柟鎯板Г閿涙梹绻涢崼婵嗘倎缂佺媴缍佸畷銉︽償椤栨粎顦梺鍏兼緲閻ジ寮妶澶婄鐎瑰嫭濯界€氭瑦绻涘畝瀣？闁稿绲介锝夊焵椤掑嫭鏅璺烘濞?婵犮垻鎳撻崯鍧楁儑娴兼潙绠┑鐘插暞鐏忥繝鏌￠埀顒併偅閸愶腹鍋撴径鎰煑闁割偆鍠庨懙鐟懊瑰鍐╊棛缂佹梹娼欓埢搴ㄥ煡閸涱垰鑰?
   * - `SET:genBAD` / `SET:dead` 闂?闂佽　鍋撻悹楦挎閸熸煡鎮楃憴鍕暡婵＄偛鍊垮畷鎶藉Ω閵娿劍宸㈡繛瀛樼矊濡瑥螞椤撱垺鐒婚柍褜鍓熷銊╊敍閵堝洨顦?*闂佸憡鍨规慨宕囩礊瀹ュ棛鈻旂€广儱瀚粣妤€顭跨捄铏剐＄紓?* 闂?闂佺厧鍟块張顒€鈻嶅▎鎾崇煑妞ゅ繐瀚埛鏍р槈閹绢垰浜鹃梺鍝勵槴閳ь剝娅曢崐杈ㄧ節瑜庨崝褏妲愬鑸垫櫖?
   * - **濠电偛澶囬崜婵嗭耿?`RST`** 闂?`morphReset()` 濠电偛澶囬崜婵囨櫠閻ｅ本鍋?闂?闂佸憡鍨规慨宕囩礊瀹ュ纾绘繝濠傚暞闊剙鈽夐幙鍐ㄥ籍婵☆偄娼￠獮鈧〒姘功楠?
   * - `RST` 闂?`REM`闂佹寧绋戦悧鎰版儗妤ｅ啯鍋ㄩ弶鍫氭櫆閸╁倿鎮跺鐓庝簻闁搞劌缍婇獮鎺撳緞濞戞氨顦?*婵炴垶鏌ㄩ鍛櫠閻樺灚鎯ラ柛娑欏缁犳牕鈽夐幘顖氫壕闁?* 闂?闁诲孩绋掗敋婵犫偓?pop 婵炲瓨绮屽Λ鏃傚緤妤ｅ啫绀勯柣妯夸含缁夎法鈧鐡曠亸娆戝垝閳ユ剚鐓ラ柍銉ョ－濞?闂佹眹鍔岀€氼亪鎳欓幋锔解拻闁哄鍨舵慨?
   *   闂佹寧绋戝﹢姗狹 闂佹眹鍔岀€氼剚绂嶉敐鍥ㄥ闁规儳鎳愮粈澶愬箹?23.3 闂佺偨鍎查弻锟犲焵?婵炴垶姊婚崰搴☆潩閵娾晛鍙婃い鏍ㄧ矋閺嗗繘鏌熼幘顕呮妞?闂?闂佸搫顧€缁辨洖鈻撻幋锕€纾规繛鍡樻尨閸嬫挻寰勭€ｎ偆鐨婚梺鍛婂笩椤旀劗妲愬璺何?
   */
  private static evLog: string = '';
  private static evT0: number = 0;
  private static evCount: number = 0;

  /**
   * 闁荤姳绶氶。锔剧博閹绢喖绾ч柍鈺佸暞椤ρ囧箹閺夋垹绠ｇ紒銊ｅ妽缁傛帞鎷嬮崷顓狀槱闁?{@link PlaybackPage.evLog}闂佹寧绋戦ˇ顓㈠焵?
   * @param tag 婵炲瓨绮岄鍕枎閵忋倕瑙︾€广儱绻掔粈鍕槈閹剧韬繛闂村嵆閺屽洭鏁愰崨顖滃€為柣鐐寸◤閸旀垿宕抽悜鑺ュ剭闁告洦鍘鹃崣姘舵煛瀹ュ懏宸濇い鎺斿厴閺?
   * @param detail 闂佸憡鐟崹鍫曞焵椤掆偓椤﹀崬鈻撻幋鐘冲仒闁靛鍎辩敮鐘绘煥濞戞澧旂紒韬插劜娣?`ok` / `genBAD` / `dead`闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?**public static**闂佹寧绋戦悧鍛箔婢舵劕鍙?private闂佹寧绋戦¨鈧紒杈╁缁旂喖宕橀懠顒佸嬀 `products/default/.../pages/Index.ets` 闂?
   *    `@Monitor('appState.isShowPlay')` 闂備焦褰冮惌渚€銆呴敂鐐?`OPN` 闂佺偨鍎查弻锟犲焵?闂侀潧妫楅懟顖炲矗瑜斿濠氼敇閻愭潙鈧敻鏌涘▎蹇曞闁哄倷鐒︾粙澶愬焵椤掑嫭鐒肩€广儱鎳愬鏃傗偓娈垮枓閸嬫捇鏌曢崱妤冃ゆ繛?
   *    婵犮垼鍩栧娆掋亹鐠恒劉鍋撳顒傜伇闁哄甯炴禍鍛婃綇閵娤€?*婵犮垻鎳撻崯鍧楁儑娴兼潙绠┑鐘插暞鐏忥繝鏌￠埀顒併偅閸愶腹鍋撴径鎰煑闁割偆鍠庨懙鐟懊瑰鍐╊棛缂佹梹娼欓埢?*闂佹寧绋戦惌鍌炲磻閸涱喚鈻旈柍褜鍓涚划顓㈠棘閸喗閿梺鍝勭墕椤︻垶鏁嶉幘鏈垫勃闁稿本绻傞崢鎾偣娴ｈ棄鐒介柍?
   *    闂佹寧绋戦悧鍡涙晬閹炬湹娌?闂?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柛顭戝亝绗戦梺鍛婎殕濞叉牠骞冨鍕懝婵犻潧锕﹂々顐︽煥濞戞瑧鎽layer` 闂佹眹鍔岀€氼參濡存繝鍥ф闁搞儻闄勯鐣屸偓瑙勭摃鐏忔瑧鍒掗敍鍕ㄥ亾閻㈤潧甯堕柛?`PlaybackPage`闂佹寧绋戞總鏃傜箔婢舵劕鍑犻柛鏇ㄥ墮閻忓洨鈧敻鍋婃禍鐐虹嵁閸℃稑违闁稿矉濡囩粈?
   */
  public static ev(tag: string, detail: string = ''): void {
    const now: number = Date.now();
    // 闂?缂傚倸鍊归幐鎼佸疮閸ф绀岄弶鐐侯暒缁?*婵炴垶鎸撮崑鎾寸箾閸″繆鍋撻崘鎻掔稑闂?*婵炴垶鎸搁幖顐㈢暦閻斿憡濯寸€广儱绻掔粣姊嶤LO`闂佹寧绋戦悧鍡涘矗瑜斿濠氼敇閵忊剝鍤戦柣鐘辫閸ㄤ即宕ｉ崱娑樼煑闁挎繂绻掔粈鍡椻槈閹绢垰浜鹃梺鍛婂笚濠㈡ê顫濋妸鈺佺濠电姳鑳堕悷鎰槈閹绢垰浜鹃柡澶屽剱閸犳寮抽敐鍛灁闁割煈鍋嗛鎼佹煙閸濆嫷妲堕柍褜鍏涘姊?` 闂備焦褰冪粔鍫曟偪閸℃稑绀嗛柟宄扮灱缁犵懓鈽夐幘顖氫壕闂佸憡甯楅惇褰掑焵?
    //   婵炴垶鎹佸銊у垝閸喓鈻曢柛顐悼缁犲綊鏌″鍛Щ闁搞劌绻橀弫宥咁潩椤掑倻宕烽梺鍝勭Т濞诧箑危?*缂備焦绋戦ˇ顔剧箔閸涱喚鈻旈柍褜鍓欓埢搴ㄥ焺閸愩劉鍙洪悗娈垮枓閸嬫捇鏌熺紒銏犲箺闁哄倷鐒﹂妵?*闂佸綊娼х粔闈浳熸径宀€鐭嗛柧蹇氼潐閻ｉ亶鏌ㄥ☉妯煎闁告鍥ㄢ拻妞ゆ挴鎳囬崑鎾诲棘閹规劕骞€婵＄偑鍊楅弫璇差焽閺夋鍟呴柤纰卞墰閻ュ懘鎮?pop闂佹寧绋戦¨鈧紒?
    //   闂佸吋鐪归崕鎵箔婢跺鈧帡宕崘顏嗩槷闁荤姴娲╅褔宕哄畝鍕剭闁告洦鍓氱瑧"婵犻潧鍊藉Λ鍕吹閹寸偞濮滄い鏂库偓鐔衡敍闂侀潻璐熼崝瀣博鐎靛憡灏?闂佹眹鍔岀€氼厼螞閳哄嫮鐤€婵°倕顑囩粈濉+` 婵炴垶姊婚崰宥囨閻楀牏鈻旈柍褜鍓熼幆鍕级閹寸姷鐛㈡繛鎴炴尭閿曘儳鈧宀稿畷姘跺箥椤旂晫鐣芥繛鎴炴尭缁夋挳宕甸銏″剮缂佸顑欓崵鐘绘煛閸愵厽纭剧紒顭戝弮婵?
    //   闂佸憡甯掑ú锕傚垂?闂佸搫鐗冮崑鎾诲级閳哄倸鐏ｇ紒鏃€娼欓埢搴ㄥ灳閸愭彃缍橀梻?婵炴垶鏌ㄩ鍛村箖濡ゅ懏鏅€光偓閸愭儳娈哄┑鐐差槹濞叉牕顫濋妸鈺佺倞闁告繂瀚弳浼存煙?`t+0 CLO 闂?闂佺偨鍎哄▔锕傛煏?
    if (tag === 'CLO') {
      PlaybackPage.evLog = '';
      PlaybackPage.evT0 = now;
      PlaybackPage.evCount = 0;
    } else if (PlaybackPage.evT0 === 0) {
      PlaybackPage.evT0 = now;
    }
    PlaybackPage.evCount++;
    const rel: number = now - PlaybackPage.evT0;
    const item: string = detail.length > 0 ? `${tag}:${detail}` : tag;
    PlaybackPage.evLog = `${PlaybackPage.evLog} t+${rel} ${item} |`;
    // 闂佺粯绮犻崹浼存嚋娴煎瓨鏅慨妯虹－瀛濋柡?900 闁诲孩绋掗〃鍫ヮ敄娴ｈ桨鐒婇弶鍫氭櫇閸╁棝鏌熼崫鍕垫Ч婵炴挸鐖煎顕€鍩￠崨顓濈凹濠电偛鐗忛。顔炬濞嗘劗鈹嶆繝闈涙噽缁?闂佸搫鐗冮崑鎾诲级閳哄倸鐏╂繛鍫熷灴瀹曟骞庨懞銉川闂佺绻堥崝蹇曟崲閸愵亞鐭?闂?
    if (PlaybackPage.evLog.length > 900) {
      const cut: number = PlaybackPage.evLog.indexOf('|');
      if (cut >= 0) {
        PlaybackPage.evLog = PlaybackPage.evLog.substring(cut + 1);
      }
    }
  }

  /** 闂佺绻戞繛濠偽涚€涙ɑ濯存繛鍡樺姇閻ㄥ墽绱掗幇顓ф當鐟滅増鐩弫宥夊锤椤ｆ瑩鏌ㄥ☉姗嗘Т闁逞屽墯閺岋繝鍩€?`lastCloseAtMs` 闂佹眹鍔岀€氼剟顢欓弮鈧幆鏃堟晜鐞涒€充壕闁稿本顨嗛蹇涙煥?閻庤鎮堕崕鎶藉煝婵傜绀嗛柕鍫濇閻掍粙鏌涙繝鍕┾偓瀣濠靛洨鈻旂€广儱妫欑瑧闂備緡鍋勫Λ妤呭箖濠婂牆纾圭痪顓㈩棑缁€鍕偡濞嗗孩顦风紒妤€鍊垮顒傛兜閸滀礁娈梺鍝勫閸戠晫妲愬璺何?*/
  private static readonly CLOSE_WINDOW_MS: number = 1500;

  /**
   * `scheduleMorphResetAfterPop()` 闂佹眹鍔岀€氼垶鎮块崱娆愬珰闁靛繈鍊栭敍鐔兼⒒閸涱喗顥栫紒杈ㄧ崱s闂佹寧绋戦ˇ顔剧箔瀹€鍕珘闁逞屽墯瀵板嫯顦虫い鎰偢瀵偊鎳滈钘変壕?
   *
   * 闂佸疇娉曟刊瀵哥箔?**閻庤鎮堕崕鎶藉煝婵傜绀嗛柕鍫濇閻掍粙鏌涙繝鍕┾偓瀣濠靛洨鈻旂€广儱妫欑瑧闂備緡鍋勫Λ妤呭箖濠婂牆纾?*闂佹寧绋掔喊宥呂涢妶澶嬪仼閻忕偛澧藉楣冩煛閸繍妲肩紒缁樼墵瀵?缂?pop 闂佸憡鍔曠粔鎾囬崣澶嬪?闂佹眹鍔岀€氼厼螣婢跺鍤曢煫鍥ㄦ皑閺嬪倿鎮?
   * 闂佹寧绋戦悧鍡涙偩閻樼粯鍎嶉柛鏇ㄥ灛閳ь剙顦靛Λ鍐閳╁唭锔戒繆椤栨澧查柍褜鍏涚欢銈囨濠靛缁╅柟顖滃瀹曟娊鎮楅悷鐗堟拱闁搞劍宀稿畷锟犲礃閹绘帞銈婚柡澶屽仦閺嬭崵妲愬璺何ラ柛灞剧箘缁犲綊姊洪幓鎺曞鐟滄妸鍥у強妞ゆ牗纰嶇粈鍫濃槈閹捐泛鍔嬮柛銊︾矋缁傛帡顢楅崒娑氭殸闁荤姳璀﹂崹鎶藉极?pop 闂?*閻庢鍠栭崐褰掝敆?*闂佹眹鍔岀€氥劑鍩€?
   * 32ms 闂?婵炴垶鎸堕崐鏇㈠箮濮樿埖鏅? 濠?闂?256ms 婵炴垶鎸搁敃顏勵瀶濞差亝鏅柛顐悼瀛濋梺鍝勫暢濞夋盯宕㈢憴鍕劅闁哄洨鍎愬Σ璇裁归敐鍛枌缂佽鲸绻勯埀顒勨偓娑氼槮鐟滅増鐓″鎻掝潩椤愩倗妲忔繛鎴炴尭缁夌兘宕楀Ο鑽も枖鐎广儱妫涢鎼佹煥濞戞﹩妲堕柍?
   */
  private static readonly RESET_POLL_MS: number = 32;
  private static readonly RESET_POLL_MAX: number = 8;

  /** 婵炴垶鎸搁敃锝囩博閺夋垟鏋?`RzdBgLayer` 闂佹眹鍔岀€氼噣顢楅悜钘夎Е鐎广儱绻掔粈鍕煠閸濆嫬鈧湱绮婇敃鍌涙櫖濠㈣泛鐗冮崑?*/
  private lastBgLayerLog: string = '';

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16 闂佸搫鍊瑰姗€路閸愵亝瀚氬┑鐘插暞閻掍粙鏌?*闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本鑹鹃悡鍌炲箹鐎涙ɑ绀冩俊鎻掓啞瀵板嫬顫濋鍙ユ捣闂侀潧妫旂粈渚€藝閹稿海鈻旂€广儱顦崑鎾圭疀閺冣偓椤?*闂?
   *
   * ## 闁诲海鎳撻崯顐﹀垂閼恒儳顩烽柍褜鍓氱粙濠囧醇椤掑倻顦╅梺娲绘娇閸斿秹宕哄☉銏犵煑鐎广儱鎷嬪Σ濠氭煙闊彃鍔ゆ繛鍫熷灦缁嬪濡堕崱妯挎嫬闂備緡鍠曠划娆忣焽椤掑倵鍋撻悷鏉挎殭闁伙綁绠栭獮鈧憸婵堟?
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdBgLayer'
   *   闂?RzdBgLayer box=(x,y,w,h) win=WxH clip=闂?p=闂?op=闂?squashing=闂?meshSrc=yes|no playing=闂?
   * ```
   *
   * | 闁荤姴娲╅褔宕哄畝鍕剭?| 闂佸憡鍑归崑鍌滅不?|
   * | --- | --- |
   * | `box.w/h 闂?win` **婵?`op 闂?1`** | 闂佺厧鍟块張顒€鈻嶅▎鎾虫瀬闁哄鍨瑰灞解槈閹惧磭效闁逞屽墮缁绘垵危?闂?闁哄鏅滈悷锔芥櫠閻樿鍙婃い鏍ㄇ氶崑?*闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛鍎冲?*闂侀潧妫楃粔璺衡枔閹达絻浜归柕蹇嬪灩绗?|
   * | `box.w/h 闂?win` 婵?`op` 閻庡灚婢橀悧鍡涙儍椤掑嫭鏅?.04~0.3闂?| 闂佺厧鍟块張顒€鈻嶅▎鎾虫瀬闁哄鍨瑰灞矫归敐鍛棞闁搞倖鍨剁粙濠冩償閵娿垹浜鹃煫鍥ㄦ⒐椤?闂?**婵炴垶鎸哥€涒晛螞閵堝鍋╅悘鐐跺Г閸婅京鎲?*闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸曨偂绨奸柣蹇曞仜閸婇寮ч崘顔兼嵍闁靛绠戞慨顒勬倶閻愯尙绠伴柣顏冨嵆閺屽苯鐣濈€ｎ剛顦?|
   * | `box.w/h` 闂佸搫瀚€涒晛螣婢跺奔鐒婇煫鍥ф捣閼?`win` | 闂佺厧鍟块張顒€鈻嶅▎鎴炲仏妞ゆ劧闄勯娆撴煕閹烘洘纭炬繝鈧鍡曠剨闊洦娲滃畷鍫曟煕濞嗘瑧绉柛锝囧厴閺佸秹宕煎┑鍡欑◥婵炴垶鎸撮崑鎾剁磼婢跺﹦孝闁奸晲鍗抽幃鈺冩媼閸︻厾顦?|
   * | `meshSrc=no` | 缂傚倸鍟崹鍫曟偋缁嬪簱鏌﹂柍鈺佸暟閻?闂?闁诲繒鍋涚换瀣箔閸岀偛鍙?*闂佺绻戠划宀€鑺遍幎钘夌煑闁哄秲鍔庢竟澶愭煠?*闂佹寧绋戦悧鍡楋耿椤忓棛妫柟绋挎捣閹藉啴鏌￠崶銊у弨闁稿鎳愭禒锕傚磼濞戞?`rgba(20,20,22,0.5)`闂?|
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟禍锝夘敋娴煎瓨鏅慨姗嗗幗閹烽亶鏌￠崒婵愭綈缁绢叀鍩栫粙澶婎吋閸涱厽娅㈡繛瀵稿Ь椤斿﹦绱炲澶嬪亹闁煎摜顣介崑鎾存媴绾版ê浜?
   */
  private logBgLayer(): void {
    let box: string = 'none';
    try {
      const node = this.getUIContext().getFrameNodeById(PlaybackPage.MESH_BG_ID);
      if (node !== null) {
        const p: Position = node.getPositionToWindowWithTransform();
        const s: Size = node.getMeasuredSize();
        box = `(${areaLengthToVp(p.x).toFixed(1)},${areaLengthToVp(p.y).toFixed(1)},` +
          `${this.getUIContext().px2vp(s.width).toFixed(1)},${this.getUIContext().px2vp(s.height).toFixed(1)})`;
      }
    } catch (err) {
      box = 'err';
    }
    const op: number = this.backgroundRevealOpacity();
    const sig: string = `${box}|${op.toFixed(2)}|${this.expandState.morphP.toFixed(2)}`;
    if (sig === this.lastBgLayerLog) {
      return;
    }
    this.lastBgLayerLog = sig;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdBgLayer box=${box} win=${this.expandState.windowWidthVp.toFixed(0)}x` +
      `${this.expandState.windowHeightVp.toFixed(0)} clip=${this.expandState.morphClipHeight.toFixed(0)} ` +
      `p=${this.expandState.morphP.toFixed(3)} op=${op.toFixed(3)} ` +
      // 上游 `padTop()/padBottom()` 的同名映射（`wujie.pa:175314-175353` / `175250-175309`）。
      // 只打日志、不接布局：本仓背景宿主是 `MeshCoverBg` 的父，加 padding 会把网格压成中间一块，
      // 上下露出 `defaultImageBgColor`；上游那个带 padding 的列是**正文列**、网格是它的兄弟
      // （依据见背景宿主上方那段注释）。这两个数留给真机核对"内容让位够不够"。
      `bgPad=${this.expandState.bgHostPadTopVp().toFixed(1)}/` +
      `${this.expandState.bgHostPadBottomVp().toFixed(1)} ` +
      `squashing=${(this.expandState.morphSquashY !== 1)} stage=${this.expandState.morphStage} ` +
      `meshSrc=${this.meshSrc !== undefined ? 'yes' : 'no'} playing=${this.state.isPlay} ` +
      `active=${this.state.isShowPlay}`);
  }

  /** 上一次 `RzdBgPhase` 的签名（去重，避免 20fps 刷屏）。 */
  private lastBgPhaseLog: string = '';

  /** 网格背景诊断：结合 RzdBgPhaseMesh 检查取源版本、透明度与画布尺寸。 */
  private logBgPhase(): void {
    const op: number = this.backgroundRevealOpacity();
    const sig: string = `${this.expandState.pullMode ? 1 : 0}|${op.toFixed(3)}|` +
      `${this.meshSrc !== undefined ? 1 : 0}|${this.tintReady ? 1 : 0}`;
    if (sig === this.lastBgPhaseLog) {
      return;
    }
    this.lastBgPhaseLog = sig;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdBgPhase pull=${this.expandState.pullMode ? 1 : 0} ` +
      `mode=${this.expandState.pullMode ? 'pull' : 'content'} op=${op.toFixed(3)} ` +
      `p=${this.expandState.morphP.toFixed(3)} clip=${this.expandState.morphClipHeight.toFixed(0)} ` +
      `mesh=${this.meshSrc !== undefined ? 1 : 0} ver=${this.meshSrcVersion} ` +
      `tint=${this.tintReady ? 1 : 0} background=mesh ` +
      `playing=${this.state.isPlay ? 1 : 0} active=${this.state.isShowPlay ? 1 : 0}`);
  }

  /**
   * 闂佺鐭囬崘銊у幀闂?*婵炴垶鎸搁ˇ浼搭敊瀹€鈧槐鎺楀箻鐎电硶鍋?*闂佹眹鍔岀€氼亞鎮柆宥呭唨闁荤喐婢樼粣妤€霉閿濆懐校婵炵⒈鍨堕弫宥夊醇閵忋垻鐓佹繛?id闂佹寧绋戦懟顖濄亹瑜忕槐?{@link PlaybackPage.logLayoutBoxes} 闂備焦褰冪换鎴犵矈閹绢喗鍋ㄦい顓熷笧缁€鍡涙煏?
   *
   * 闂佸憡鍨甸幖顐λ囬埡鍛櫖婵﹩鍘介敓銉╂煟?overlay 闂?builder 闂佸搫绉甸崺濠勬濡惧€僽jie.pa:190464` / `190497`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
   * ```
   *   Row().height(lerp(swiperGap(), 10, swiperProgress))   // 190464  闂?"Swiper 闂?闁哄鏅滅粙鎴犫偓瑙勫▕瀵?
   *   Row().height(chrome().gapScrub)                       // 190497  闂?"闁哄鏅滅粙鎴犫偓瑙勫▕瀵?闂?婵炵鍋愭慨鍓ф椤撱垹绾?
   * ```
   * 闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯鈺侇煥?*婵炴垶鎸哥粔闈浳?padding**闂佹寧绋戦張顒€危?*闂傚倸妫滃▔娑㈠船鐎电硶鍋?Row**闂佹寧绋戝濉乷lumn` 闂備焦褰冮惉鐓庘枔閹达箑鐤炬い鏇楀亾闁逞屽墯閼归箖宕㈤弬娆惧殨闁绘棁顕ц灐闂佺粯鍔楀▍銏㈡濮樿泛鐏抽柡鍌濄€€閸?
   *   闂佸湱顣介崑鎾趁?婵炴垶鎸搁ˇ浼搭敊?闂?`[Swiper | gapSwiper 闁?| gapScrub 闁?| 闁哄鏅滅粙鎴犫偓瑙勫▕瀵?婵炵鍋愭慨鍓ф椤撱垹绾фい鈽嗘灲闂?
   * 闂佸疇娉曟刊瀵哥箔?闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗閳峰牆霉閻樺灚娅曢柡浣靛€濋幆鍐礋椤掍絿?`.height(lerp(...))`闂佹寧绋戦悾鐠磂rp` 缂備焦顨忛崗娑氱箔娴ｈ　鍋撻崷顓炰粶鐎殿噮鍓熷?`swiperProgress`闂?
   *   闂佸綊鏀遍悧妤冣偓姘健楠炲秹骞樺畷鍥╋紱/闂佺绻戞繛濠偽涢幘顔藉剭闁告洦鍠氱粻鏍磼鐎ｎ亶鍎庨柤鍨灦濞艰鈻庢惔銈傛嫛闂佸搫绉烽～澶婎焽椤栨稑顕辨慨妯虹－椤庘偓闂佹椿鍋€閸嬫捇鎮跺☉鏍у姦婵☆偄娼￠弫宥夊锤閸?swiperGap, b=10`闂佹寧绋戦ˇ顓㈠焵?
   *   闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡楁捣椤忓崬銆掑鈧崟顓熲挄闂?`swiperProgress` 闁哄鏅滈悷銈夋煂濠婂牊鐓傞煫鍥ュ劤缁€鍕煙鐎涙ê鐏ｆ繝濠冨灴閹啴宕熼銈嗙秾閻庢鍠掗崑鎾诲级閳哄倻鈽夐悗瑙勫▕瀹?`morphP`闂佹寧绋戦惌渚€顢氶姀锛勨枙濠㈣泛顦遍悷婵嬫煕濮橆剛鐒跨紒杈ㄥ哺閺?
   *   闂佸湱顣介崑鎾趁?*闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝囶焾缁?`swiperGap()` 闂備緡鍙忕徊鑲╃博鐎靛摜鍗?*闂? `lerp(t=0)`闂佹寧绋戦¨鈧紒杈ㄧ箚閵囨劙濮€閻樿尙绉梺鍝勭墢閸犲秶绮径鎰?闂佺偨鍎查弻锟犲焵?闁荤喐鐟ら悞锕傚蓟閻斿皝鏋栭柡鍥╁枑閺嗗牓姊洪幓鎺濈劸闁?
   */
  private static readonly SWIPER_GAP_ROW_ID: string = 'rzd_gap_swiper_row';
  private static readonly CHROME_SCRUB_GAP_ROW_ID: string = 'rzd_gap_scrub_row';

  /**
   * @returns 闂侀潧妫楅鐜緄per 闂?闁哄鏅滅粙鎴犫偓瑙勫▕瀵埖骞婇柍褜鍓欑粔鏉戠暦閻楀牊濯寸€广儱妫欓拏瀣煟閵娿儱顏柣婵愬枟閹棃鏁傞懖鈺冾槱vp闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佸搫鍟版慨鐑藉疾?`swiperGap()`闂佹寧绋戝澧倁jie.pa:180127`闂佹寧绋戦ˇ顓㈠焵?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐悼缁犲綊姊洪幓鎺撴拱婵?*婵炴垶鎸撮崑鎾斥槈閹垮啩绨婚柣鏍х埣瀵?*闂侀潧妫斿鎺旂箔婢舵劕鍙?`lerp`
   *
   * 闂佸搫鍟版慨鐑藉疾椤愶箑绀冩繛鍡樺灦閻ｉ亶鏌?`lerp(swiperGap(), 10, swiperProgress)`闂佹寧绋戦懟顖氱暤?*闂佸綊鏀遍悧妤冣偓姘健楠炲秹骞樺畷鍥╋紱/闂佺绻戞繛濠偽涚€涙ɑ浜ら柛銉㈡杹閺屻倕鈽?*闁哄鏅滈悷锕傛偋閹绢喖绾?
   * 婵?`swiperGap()` 闂佽　鍋撻悹鍝勬惈閻?10vp闂侀潧妫旂换鏉漺iperProgress` 闂?*闁诲海鎳撻崯鎶藉吹濠婂喚鍟呴弶鍫氭櫆閻?*婵炴垶鎸搁鍡樺垔閻戞ɑ浜ゆ繛鎴灻濠囨⒑閹绘帡鐛滅紒?闂? 闁诲海鏁搁幊鎾惰姳閺屻儱绀傞柟鎯板Г閿涙棃鏌涢弬璇插缂傚秵妫冮弫宥嗗緞濞戞氨顦?
   * 闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡楁捣椤忓崬銆掑鈧崘鎯ф闁圭厧鐡ㄥ璇测枔閹达箑鍙?`expandState.morphP`闂佹寧绋戦悧鍡涙儓瀹ュ拋鍤曢柍褜鍓氬璇测槈濡警鍞洪梺?*闂佸搫鍊婚幊鎾诲箖濠婂嫮鈻旈幖杈剧稻缁佹彃霉閿濆懐效闁稿繑蓱缁嬪顓奸崨顔尖偓?*闂?
   * 闂佺懓鐡ㄩ崹鍐差煥閹达箑鍙?婵炲濮村锔惧寲閻樿櫕濯撮柣妯挎珪閽傚姊婚埀顒勫垂椤旇偐鍘掗梺杞扮劍濞兼瑩鎯?闂佹寧绋戦懟顖炴偩閻樿鍙?婵炲濮寸€涒晠寮抽敐鍥︽勃闊洦鎸剧粣鏂库槈閹炬剚鍎愰悗姘儑閹?闂佹寧绋戦ˇ顓㈠焵?
   * 闂?缂佺虎鍙庨崜娆撱€?`lerp(..., morphP)` 婵炴潙鍚嬮懝鍓ф闁秴绀?*闂佸憡鐟ョ粔璺好?*闂佹眹鍔岀€氼厼煤閸濄儳妫柛鏍电磿缁€鍕倶閻愬瓨绀€缂佽鲸鍨垮顔炬崉閸濆嫬鍞ㄩ梺鍏兼緲閺堫剟寮崷顓犵幓闁告洖澧庣粈鍡涙煥濞戞鐒搁柛瀣嚇瀵?*闂佸搫鍊烽崡鎶藉焵椤掑倸小缂佹柨鐡ㄧ粙澶愵敂閸ヨ埖鏂€婵?*闂?
   *   婵炴垶鎸哥粔闈浳ｉ幖浣瑰亗鐟滃酣骞嗘径鎰ラ柛灞剧☉椤ｆ彃霉閻橆喖鍔︽繛绗哄€曢～銏ゅ閳锯偓閸嬫挻鎷呯憴锝呬壕濞达綀袙閸嬫挻鎷呴崫銉︽緰闁诲骸婀遍崑娑溿亹?`lerp` 闂?`t=0` 闂備緡鍙忕徊鑲╃博鐎靛摜鍗氭い鏍ュ€楃粈鍒瀞wiperGap()`闂佹寧绋戦¨鈧紒?
   *   濡ょ姷鍋犻崺鏍ㄤ繆?閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮殺婢舵劖鈷?闂佽皫鍕潡妞ゆ柨娲︾粙澶愬传閸曨厾顎€闂佸憡姊婚崕鎴犳濡句縼zdMusic閻庡灚婢橀幊鎰板灳濡吋濯奸柕鍫濇椤忔悂鏌?md` D4-b闂佹寧绋戦ˇ顓㈠焵?
   */
  private swiperGapRowHVp(): number {
    return this.expandState.swiperGapVp();
  }

  /**
   * @returns 闂侀潧妫楅惌浣烘崲濡粯鍎熼柨鏃囧Г閽?闂?婵炵鍋愭慨鍓ф椤撱垹绾ч幒鎶藉焵椤掆偓缁夋潙鐣烽悧鍫熷鐎广儱妫欓拏瀣煟?*婵☆偆澧楃换鍌炈?*婵°倕鍊归敋閻庤濞婇弫宥夊锤绾炬帡鏌ㄥ☉姗嗘Ф闁?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佽鍘界敮濠勬嫻?0闂?*婵炴垶鎸哥粔闈浳ｇ粙娆剧叾闊洦鎸风划?*闂佹寧绋掓穱铏规崲閺嶃劎鈻旈柍褜鍓欓埢鎾绘偨閸偆鏆犻梻鍌氬€婚ˉ鎰玻濞戙垹绠ｉ柟瀛樼矋缁?*閻庤鐡曠亸娆戝垝閿熺姴瀚夊璺侯槺閸?*闂佹寧绋戞總鏃傜礊閸涱垳纾炬い鏂垮悑闊?
   *   `ControlAreaComponent.bottomPanel()` 闂備焦褰冮惌鍌炲磻閸涱喚鈻?`Column` 闂?`.margin({ bottom: 闂?})`
   *   闂佹寧绋戦悧濠勨偓鍨矒瀵剟顢橀悩韫寲闂?`app.float.slider_margin_bottom*`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婄懓螞閵堝鍋╃€光偓閸愶腹鍋撻崘顔界厒鐎光偓閸愵亞顔愭繛鎴炴尨閸嬫挻绻涢崼銉︽锭鐟?`gapScrub`
   *   闂佹寧绋戝﹢妗縇L 28 / MEDIUM 20 / COMPACT 14闂佹寧绋戦ˇ顓㈠焵?
   * 闂?闁哄鏅滈悷鈺呭闯闁垮鈹嶆繝闈涚墛濞堝苯鈽夐幘顖氫壕婵?0 婵°倕鍊归…鍥р枔閹达箑鐭楁い鏍仜濞呫倖绻涢弶鎴創濠碘槅鍙冮幃娆撴儌閸濄儳顦?*闂佸憡鐟禍娆戞嫻?*闂?闁诲骸婀遍崑鐐电矈閹绢喗鈷掔痪鎯ь儑閻?vs `gapScrub`"闂佺懓鐏氶幑浣烘崲濮椻偓瀵噣濡烽妷褏顔?
   *   闂佹寧绋戝濉晍dSwiperBox`闂佹寧绋戦¨鈧紒杈ㄧ箘缁灚寰勭仦鎯х劯闂佸搫鐗忛崕銈夊汲閻旂厧绠叉い鏂垮悑缁€鈧梺鍝勵槶閸庨亶宕埀顒勬煕閹邦剙鏆遍柣锝夌畺瀵?闂?margin 闂佺懓绠嶉崹娲垂?`gapScrub`"闁哄鏅滆摫婵?婵烇絽娲︾换鍕汲閳ь剚绻涢弻銉х暫闁绘挸鐖煎畷銏ゆ偄鐏忎礁浜?闂?
   *   闂佺粯绮嶅妯猴耿?*婵炴垶鎸哥粔鎾嚐閻旂儤鍋橀悘鐐舵椤?*闂佹寧绋戦悧鍡涘箚娓氣偓瀹曟艾鈻庤箛鏃傛闂佸搫瀚烽崹浼村箖閹惧鈻旈柍褜鍓欓埢鎾绘偨閸涘绱甸柣鐘靛劋缁烩偓閻炴岸浜跺鍫曞灳閸愯尙绋夐悗?闂佺偨鍎查弻锟犲焵?闂佸搫鐗滈崗娑氬垝閵娾晛鐭楃€广儱鎷嬪Σ濠氭椤忎焦娅堢紒璇插暣閹啴宕熼銉ョ厒闂佺粯顭堥鎰濮樿泛违?
   */
  private chromeScrubGapRowHVp(): number {
    return 0;
  }

  /**
   * 闂?2026-10-15 闁荤姴娲ら敃銉╁蓟閸ヮ剚鐓ユ慨妯哄船娴狀垶鏌ㄥ☉娆戭暡濠?*闂佹悶鍎茬粙鎰版煂濠婂嫬顕辨慨姗嗗亞闂夊秹鏌ｉ埡鍐剧劸閻㈩垰娲幆鍐礋椤愶絽浠?*闂佹眹鍔岀€氼噣鎮伴妷鈺佺煑闁挎繂娲ㄩ崣鎰喐闁附绶氱紒鏃€娼欓埢搴ㄥ焺閸愩劉鍙洪梺鍛婂灩閸庛倕顭囬悽绋课?
   *
   * 闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdBoxes'`
   *
   * 闂佺懓鐏氶幐鎯р枔閹达箑鍙?*缂備焦鍔栭〃鍛般亹濞戙垹閿ら柟閭﹀幘閸?*闂佹寧绋戝濉痚tPositionToWindowWithTransform()`闂佹寧绋戦ˇ顔剧箔?*闁诲骸婀遍崑鐐电矈鐎甸晲鐒婇柛婵嗗閸?*闂?
   * 婵炴垶鎸稿ù鐑藉极閵堝绠ｉ梺鍨儏閻掑鏌涢妷銉モ挃婵炲牊鍨垮畷鎾圭疀閺囩媭妲洪梺鍛婄懐閸垱绂嶉幒妤佸剮閻庢稒锚婢跺秹鏌熼獮鍨伄闁伙綀宕甸埀顒傛暩椤㈠﹥寰勯崟顖涙櫖闁割偆鍠愰幏閬嶆煛?1224闁?776 闂佽鎯屾禍婊兠?闂?3px/vp闂佹寧绋戦¨鈧紒?
   * ```
   *   RzdBoxes cover=(x,y,w,h) title=(闂? singer=(闂? lyric=(闂?
   * ```
   * **闂佸憡甯囬崐鏍х暤娓氣偓閺佸秹宕煎┑鍥ㄥ枦婵炴垶鎸堕崐鎾绘煂濠婂牆閿ゆ俊銈呭暞閸╁倿鏌ｉ妸銉ヮ伀婵炴潙顦扮粋宥夊Χ閸愶絽浜惧ù锝呮啞閻ㄦ垿鏌￠埀顒冦亹閹烘垳绨兼繛鎴炴尨閸嬫捇鎮楅悽鍨仧缂?*闂?
   *   閻?`lyric.top` 闂佽В鍋撻柦妯侯槹闊?`[singer.top, singer.bottom]` 闂佸憡鐗楀钘壩涢崸妤€绀?闂?**闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱鎳庣粩楣冩煕閿斿搫濡介柣鈩冩礋瀹?濠殿喗绻傞張顒佹櫠濠婂牊鐒介柨婵嗗椤忛亶鎮跺☉妯侯殭缂?*
   *     闂?闁?`MINI_LYRIC_SINK_VP`闂佹寧绋戦悧濠傦耿閻楀牏顩烽柟鎯у暱閸ゆ帡鏌?婵炴垶鎸堕崐娑€侀幋锕€妫橀柛銉戝懏鎲?闂佹眹鍔岀€氫即宕抽搹鍦／鐟滃繒鍒?44闂佹寧绋戦¨鈧紒?
   *   閻?`lyric.bottom` 闁烩剝甯掗敃銊ф崲閸愵喖绠崇憸宥夊春濡ゅ懎绀屾繛宸簵閳ь剙锕ュ?闂?闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱鐗滃鍫曟煙鐠ㄥ鍟悡鎴︽煕閺嵮勬儓閻㈩垰娲﹂幏?闂?闂備緡鍙忕徊鎯ｉ幖浣哥煑闁挎棁娉曢鍗烆熆鐠哄搫顏电紒杈ㄢ攷wiper 闂佸搫顦崯鎾闯閹间礁绀嗛柛鈩冪☉鐢娊鏌ㄥ☉姗嗘缂?
   *   閻?`cover.bottom` 婵?`title.top` 闂佹眹鍔岀€氭澘螞鐠恒劍宕?闂?0 闂?濠殿喗绻傞懟顖炲箖閺囩姵顫曠憸鎴﹀礆濞戞矮鐒婂〒姘ｅ亾婵為棿鍗抽弫宥夊锤閸戔劇RIC_META_GAP_VP` 闂備緡鍙忕徊鑲╃博閺夋埈娴栭柨婵嗙箳缁€鍡涙煏?
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟禍锝夘敋娴兼潙违濞达綁顥撻悷婵嬫煕閹邦厾鎳曠紒鍙樺嵆瀵敻顢楁担鍦幍濠电偛顦板ú鎴犵箔婢舵劕缁╅柣鐔告緲缂嶄礁霉閻樹警鍞虹紓宥呯Ч閹晠鎳滅喊妯轰壕濞撴艾锕︾粈鍕槈閹惧磭小缂佽鲸濯介妵鎰板閳ュ磭浜?闂備焦褰冪换鎴犵矈閹绢喖鐒奸柟鐑樻尰閺嗩參鏌ｅΟ鍨厫闁逞屽厸鐠佹煡宕€ｎ喖绀冪€广儱顦▍銈嗙箾?闂佹眹鍔岀€氼參顢楅幘顔藉仢妞ゆ牓鍊楃粈鍡涙煏?
   */
  private logLayoutBoxes(): void {
    const g = (id: string): string => {
      try {
        const node = this.getUIContext().getFrameNodeById(id);
        if (node === null) {
          return 'none';
        }
        const p: Position = node.getPositionToWindowWithTransform();
        const s: Size = node.getMeasuredSize();
        return `(${areaLengthToVp(p.x).toFixed(1)},${areaLengthToVp(p.y).toFixed(1)},` +
          `${this.getUIContext().px2vp(s.width).toFixed(1)},${this.getUIContext().px2vp(s.height).toFixed(1)})`;
      } catch (err) {
        return 'err';
      }
    };
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdBoxes cover=${g(PLAYER_BIG_COVER_ID)} title=${g(PLAYER_META_TITLE_ID)} ` +
      `singer=${g(PLAYER_META_SINGER_ID)} lyric=${g(PlaybackPage.MINI_LYRIC_BOX_ID)} ` +
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `pad=${this.expandState.topInsetVp().toFixed(1)}/${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      `sink=${PlaybackPage.MINI_LYRIC_SINK_VP} t=${this.lyricMorphT.toFixed(3)}`);
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂侀潧妫楅張顒勬偤閺囥垹瑙︾€广儱鐗滈弨浠嬫煕濡警鍎忔繝鈧鍛氦婵炴垶锚椤斿﹪鏌℃径鍡忓亾閼碱剛鎲梺闈涙缁夎泛鈻撻幋锕€鐭楁い鏍仜濞呫倖绻涢弶鎴剰闁搞劋绮欓獮?*闂?
    //   `chromeTop` = `gapSwiper` 闂備緡鍙忕徊楣冩偋閹绢喖纭€闁绘浜粔鎾煛婢舵稓纾挎繛鍫熷灩閳ь剙婀遍崑鐐电矈鐎靛摜鐜绘俊銈傚亾鐟滅増绋掗妵鍕箚閹殿喚褰?= **闂佺鐭囬崘銊у幀闂佸憡鐗滈崕銈夘敆濠婂嫮鈻斿┑鐘插暞閻?*闂?
    //   `metaTop` = 濠殿喗绻傞懟顖炲箖閺囩姵鍋?*闁荤姳鐒﹀畷姗€顢橀幖浣哥９?*闂佹寧绋戝濉礶taTopGeomY`闂佹寧绋戦¨鈧紒杈ㄧ串metaBoxTop` = 濠殿喗绻傞懟顖炲箖閺囩姵鍋?*闁诲骸婀遍崑鐐电矈?*婵＄偑鍊栭崕鑲╃博閻旂厧违?
    //   闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴顫㈠鐢aBoxTop + LYRIC_META_ROW_H_VP > chromeTop` 闂?缂佺虎鍙庨崰鏍偪閸曨垰鍌ㄩ悗锝庡幘缁犲鏌熺挩澶婂暙閻撴垿鏌?
    //   闂佹寧绋戦悧鎾诲磻閸涙潙绫嶉柟顖炲亰閸ゅ鏌涢弬璇插婵炲牊鍨垮浼搭敍濡嘲浜鹃悘鐐垫櫕濞堥亶姊婚崼娑樼伄妞ゅ浚鍓熼幃?/ gap(50) / 闂佺鐭囬崘銊у幀闂佸憡鐗楀浠嬨€傞埡鍐笉婵＄偛鐨烽崑鎾愁吋閸垻顔愭繛鎴炴尭椤︽娊鍩€椤掆偓閹冲秹鎳欓幋锔藉剭闁告洦浜為鍗炩槈閹垮啩鎮嶇紒?
    //     **婵炴垶鎸哥粔鐑姐€?*闂侀潻璐熼崝宥夋偤閺囥垹瑙︾€广儱鐗滈弨钘夆槈閹剧宸ラ柛鐔插亾闂佸憡姊绘慨鎹愭＂闂佺顑呴妵妯肩礊閸涱垳鐭?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鑲╂娴兼潙绠ｉ柟閭︿海缁€瀣磼濡ゅ﹤鍘哥紒銊㈡櫆缁嬪顢旈崘顏喰㈢紓浣割槺缁垳鑺遍鈧弫宥嗗緞閸艾浜?
    //   闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdMetaChrome'`
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMetaChrome chromeTop=${this.boxTopY(PlaybackPage.SWIPER_GAP_ROW_ID).toFixed(1)} ` +
      `metaBoxTop=${this.boxTopY(PLAYER_META_TITLE_ID).toFixed(1)} ` +
      `metaTop=${this.expandState.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP).toFixed(1)} ` +
      `rowH=${PlaybackPage.LYRIC_META_ROW_H_VP} ` +
      `coverBottom=${(this.coverLocalRect().y + this.coverLocalRect().height).toFixed(1)} t=${this.lyricMorphT.toFixed(3)}`);

    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*闂佺鐭囬崘銊у幀闂佸憡鐗炲銊х箔娴ｇ硶鏋旈柣銏㈡暩濞夈垽鏌?*闂佹眹鍔岀€氼剟顢氶鐐闁挎棁濮ら敍澶愮叓閸ャ劊浠犻柍?
    //   闂佸憡甯囬崐鏍х暤娓氣偓閺佸秹宕奸姀鈥崇劯闂佸搫鐗愬銊х箔閸屾稓鈻旈柍褜鍓欓埢搴ㄥ灳閾忣偆娈ゆ繝銏犲閸ｏ妇妲愬鑸垫櫖婵﹩鍓涢弶鑺ョ箾?Swiper 婵°倕鍊归敋閻?vs `estBoxH()`闂? `usableH 闂?chromeTotal`闂佹寧绋戦¨鈧紒?
    //   婵炲濮伴崕鍗烆嚕闁垮鈻旈柕鍫濇婢瑰矂鏌涘Δ鍐ㄐ＄紓宥呮嚇瀵爼鏁嶉崟顒傛殸闁诲骸婀遍崑鐐电矈鐎涙﹩娈?vs 闁圭厧鐡ㄥ鐟帮耿娴ｈ娈楁俊顖滅《閸嬫捇宕掑顓涙灆閻庣數澧楅〃鍛此?闂?闂佺懓鐡ㄩ崹鍐差煥閹达箑绠崇憸宥夊春濡ゅ懎绀岄柧蹇氼潐閻ｉ亶鏌ゆ總澶夌敖闁告枮鍕垫畻婵☆垳鍎ょ€氭煡鏌￠崘顏勑ラ柡鍜佸亞閹即濡搁妷顔兼婵炴垶鎸哥粔宕囩箔閸岀偞鏅?
    //   闂備緡鍙忕徊鎯ь渻閸岀偛绀冪€广儱鎳庨弸鈧柣?閻庡灚澹嬮崑鎾绘偠濞戞牕濮傞柛锝夘棑閳ь剟娼х紞濠勭礊?闁哄鏅滆摫婵?闂佽　鍋撻悷娆忓閻忓霉閻欌偓閸撴繈宕靛鍐惧晠閺夊牃鏅滈悾鍗炍旈崒娴㈩亞鈧?闂?*婵炴垶鎸哥粔鐑姐€呴敂鐣屸枖闁靛牆鎳屾禒鍫濃槈閹绢垰浜鹃柣鐘欏洦鏁遍柡?*闂佹寧绋戦ˇ顓㈠焵?
    //   闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdSwiperBox'`
    const gapWanted: number = this.expandState.swiperGapVp();
    const gapGot: number = this.boxH(PlaybackPage.SWIPER_GAP_ROW_ID);
    const scrubWanted: number = this.expandState.chromeGapScrubVp();
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdSwiperBox tier=${this.expandState.chromeTier} usableH=${this.expandState.usableHVp().toFixed(1)} ` +
      `chromeTotal=${this.expandState.chromeTotalVp().toFixed(1)} ` +
      `estBoxH=${this.expandState.estBoxHVp().toFixed(1)} ` +
      `gapSwiper want=${gapWanted.toFixed(1)} got=${gapGot.toFixed(1)} ` +
      `gapScrub want=${scrubWanted.toFixed(1)} got=${this.boxH(PlaybackPage.CHROME_SCRUB_GAP_ROW_ID).toFixed(1)}`);
  }

  /** @returns 闂佸搫鏈崝鎺楁煂濠婂懐纾奸柛鏇ㄤ簼椤?id 闂?*闁诲骸婀遍崑鐐电矈鐎涙﹩娈楁俊顖氭惈椤?*闂佹寧绋戝濡忛梺鎸庣☉閻倿宕抽悜妯尖枖鐎广儱鎳庨悡鍌炲级閳哄倹鐓ユ繛?-1闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佸憡鐟禍鐐靛垝閹殿喗瀚氬┑鐘插暞閻掍粙鏌￠崘锕€鍔氱紒缁樻閹粙濡搁敐鍌氫壕?*/
  private boxH(id: string): number {
    try {
      const node = this.getUIContext().getFrameNodeById(id);
      if (node === null) {
        return -1;
      }
      return this.getUIContext().px2vp(node.getMeasuredSize().height);
    } catch (err) {
      return -1;
    }
  }

  /**
   * @returns 闂佸搫鏈崝鎺楁煂濠婂懐纾奸柛鏇ㄤ簼椤?id 闂?*缂備焦鍔栭〃鍛般亹濞戙垹閿ら柟閭﹀幘閸ㄧ厧顪冮妶鍡楀姸缂?*闂佹寧绋戝濡忛梺鎸庣☉閻倿宕抽悜妯尖枖鐎广儱鎳庨悡鍌炲级閳哄倹鐓ユ繛?-1闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佸憡鐟禍鐐靛垝閹殿喗瀚氬┑鐘插暞閻掍粙鏌￠崘锕€鍔氱紒缁樻閹粙濡搁敐鍌氫壕?
   *
   * 闂?2026-10-17闂佹寧绋掗懝鐐叏閻愮鍋撻悷鏉挎殲婵℃彃鎲＄粙澶嬫姜閹殿喖鏅╃紓鍌欑劍閻燂綁鍩€?*濠殿喗绻傞懟顖炲箖閺囩姵鍋橀悘鐐舵缁旈箖鏌涢敂鍝勫缂佺粯蓱閹棃鏁傞懞銉ㄦ嫬婵?*闂侀潧妫楃粔椋庢崲閺嶃劎鈻旈柍褜鍓熷鍫曞灳閼碱剦浼囨繛?*闂佸憡鐟崹鍫曞闯閸濆娊鍦偓锝庡墯閻ｉ亶鏌涢幒瀣偓鏍х暤?*
   *   闂佹寧绋戦悧濠囧垂濠婂喚娼伴柕鍫濇噹椤ゅ懘鏌涘▎妯规捣闁稿繑锕㈠Λ鍐偐閸愯尪鍚傜紓?chrome 婵＄偑鍊栭崕鑲╃博閻斿吋鏅悘鐐村劤閼靛綊鏌涢幋鐘插妺婵炵厧鐏氱粙澶愬Χ閸滀焦顔囬梻渚囧枛閳ь剛鍠庡▓鐗堢箾閸欏鐏紒杈ㄧ箘缁灚寰勬径宀冨濠电偛澶囬埀顒€鍟块悘鏌ユ煙鐠団€虫珯缂佽鲸宀告俊?
   *   闂佺粯绮嶅妯猴耿椤忓牆绠?`gapSwiper` 闂備緡鍙忕徊楣冩偋閹绢喖纭€闁绘浜粔鎾煛婢跺棙顫夌紒? 闂佺鐭囬崘銊у幀闂佸憡鐗滈崕銈夘敆濠婂嫮鈻斿┑鐘插暞閻撴瑩姊洪銊у缂佹梹鎸冲浠嬫儌閸濄儳顦梺姹囧妼鐎氼剟鎮块崟顐€鍦偓锝庡枔閳ь剙锕ュ蹇曟喆閸曨偀鍙洪梺鍛婂灩閸庛倕顭囬悽鍛婃櫖?
   * ```
   *   闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴顫㈢粈绲玪e.y + 闁荤偞绋戦惌鍌炴偟?> gapRowTop(闂?闂佺鐭囬崘銊у幀闂佸憡鐗楀浠嬪Υ婵犲啯缍?  闂?濠殿喗绻傞懟顖炲箖閺囩姵鍋樼€光偓閳ь剟鍨惧Ο灏栧亾閸︻厼浠滈悽顖氭处濞艰鈽夊▎蹇庣帛闂佸憡甯熷▔娑氫焊?
   *   闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdBoxes'`
   * ```
   * 闂佸疇娉曟刊瀵哥箔?闂?`getPositionToWindowWithTransform()`闂佹寧绋戦悧鍡涘箚閸懇鍋撻崷顓熷殌婵炲懏甯″畷锝呂熺拠鎻掔哎闂佹寧绋戦ˇ顐﹀闯?閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏃€妞块崵銏ゆ煛娓氣偓椤ｏ妇寮ч崘鈺侇嚤婵ê纾鈧梺娲诲亐閸嬫捇鏌涘▎鎰跺叕缂?
   *   闂佸湱顣介崑鎾趁归悩顔煎姎鐟滄妸鍥ㄥ剳?*闂佽В鍋撻柦妯侯槺閺嗕即鏌?*闂備緡鍙忕徊浠嬪吹閹寸姵鍋橀悘鐐靛劦閸?
   */
  private boxTopY(id: string): number {
    try {
      const node = this.getUIContext().getFrameNodeById(id);
      if (node === null) {
        return -1;
      }
      return areaLengthToVp(node.getPositionToWindowWithTransform().y);
    } catch (err) {
      return -1;
    }
  }
  /** 闂佺绻戞繛濠偽涢幘顔肩睄闁割偅娲樺В鎰叏閿濆棙鐓ｇ紒韬插劦閹啴宕熼鍡欐啴闂傚倸瀚崝褏妲愬淇秓rphT` 闁诲繐绻愮换瀣姳椤掑倵鍋撻悷鏉挎殲婵＄偛鍊块獮鎰緞婵犲嫭娈滅紓浣哄У椤ㄦ劗妲愬璺虹伋闁哄倽銆€閸?闁诲簼绲婚～澶愭偉閿濆绫嶉柣妯虹仛濞?`REVERSE_MIN_RATIO = 0.4`闂?*/
  private static readonly REVERSE_MIN_RATIO: number = 0.4;
  /**
   * 闂佺粯鍔楅幊鎾诲吹?闁荤姍鍥ㄦ暠闁规悂浜堕獮鍥疀閹惧顩梺鐟扮仛閹稿摜妲愰幋锕€绫嶉悹浣告贡缁€澶愭偠濞戞牕鍔︽俊?*閻庣偣鍊涘▔娑㈠箖濡や胶鈻旈柕鍫濇噺婵?*闂佸憡鍔曠粔鐑藉箲閿濆鏅柛褜鏆€闂佹寧绋戦ˇ顓㈠焵?
   *
   * 婵＄偑鍊楅弫璇差焽閻楀牊浜ゆ繛鍡楁捣椤忛亶鎮介鍡楀椤ゅ懘鏌涢幒鎾额暡閻庡灚娲樺顏呮叏閹般劌浜惧ù锝囨櫕缁犻攱绻涘畝瀣？闁轰胶鍋撳濠氬炊閳哄﹤鍓虫繛鎴炴尨閸嬫捇鎮介鍡楃Ф楠炪垽鏌涘顒冨闁硅埖姘ㄩ幐褔鎮块鈧径鎰拻閻庨潧鎲￠悾閬嶆偣閸ャ劎绠扮紒杈ㄧ箘缁灚寰勫畝濠傚壋婵炴垶鎸撮崑鎾绘偨椤栧棗鎳忛崺鍌炴煟閵娿儱顏柡渚€绠栧畷娆撴倻濡妾烽梺?
   * 闂佸憡鏌ｉ崝搴ㄥ极閹屽晠闁肩⒈鍓涢惀鍛存偣瑜旈。锔捐姳閿熺姴绀勯柣妯诲絻绾锯晜鎱ㄩ敐搴′簽妞?闂佺偨鍎查弻锟犲焵?闂佹椿娼块崝宥夊春濞戙垺鍎戦悗锝庝簻閻撳倿鏌ｉ妸銉ヮ仼婵ǜ鍔戝?闂佺儵鏅涢悺銊ф暜閹绢喗鍊烽柣鐔稿绾惧鏌￠崟闈涚仧缂侇喚濮电粙澶愵敇閵忊槄绱甸悗娈垮枓閸嬫挸鈹戦纰卞剳婵?闂?
   */
  private static readonly MORPH_INTRO_DELAY_MS: number = 50;
  /**
   * 婵炴垶鎸撮崑鎾寸箾閸犅板€楅鈧梺褰掓涧椤戝嫮妲愰幍顔藉珰婵犻潧鐗婇悾閬嶆煛閸艾浜鹃梻鍌楀亾闁割煈鍠楅崐銈夋煟閻愬弶顥炴俊鐐插€垮褰掑礌閿涘嫮顦﹎s闂佹寧绋戦ˇ顓㈠焵?
   *
   * `pullDragging` 濠电偛鐗嗛鍥汲閳ь剟鏌￠崘銊ヮ暢闁稿缍佸畷娆戠磼濡　鍙洪悗娈垮枓閸嬫挸霉閸忛棿浜㈤柣鎴檮濞煎宕惰閸╁矂鏌涘▎鎯奉亪宕归崹顐ｅ弿閻庯綆浜滈褔鏌ㄥ☉妯煎ⅵ闁逞屽厴閸嬫捇鏌涢弽銊у闁搞劍宀搁幊鎾存媴缁嬪晝妤呮煟椤厾涓茬紒杈ㄥ哺閺佸秴鐣濋崘顏嗩啇闂佸搫顧€缁绘繂危閸ヮ剙纾归柤娴嬫櫆閺嗗繘鏌?
   * 闂佸憡甯囬崐鏇㈡偩?闁哄鏅滈悷銈夋煂濠婂牆鍐€闁搞儺浜堕崬鍓佲偓瑙勭摃鐏忔瑧鍒掗埄鍐╀氦闁搞儯鍔嶉崺?闂佹寧绋掗惌顔剧博閺夋垟鏋庨柍銉ㄥ皺閻熸劙鏌?婵炴垶鎸搁鍡樺垔閻戞鈻旂€广儱鎳庣拋鏌ユ煠鐎圭姴袚閻庡灚姊荤槐?2 缂備礁顦扮敮濠冪閹烘挾鈻斿┑鐐茬氨閸?
   */
  private static readonly PULL_DRAG_MAX_MS: number = 2000;
  /**
   * 闂備焦瀵у銊╁磻閿濆棙浜ゆ俊顖濆吹濮婇箖姊洪幓鎺旂闁糕晛鐭傚顕€宕滄担鍦殸闂備焦褰冪粔鐑芥儊椤栫偞鈷掗柟缁㈠枟椤撻箖鏌ㄥ☉妯绘〃s闂佹寧绋戦ˇ顓㈠焵?
   *
   * "闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱"闂備緡鍙忕徊鑲╃博閹绢喖绀嗛柡鍕箳绾板啫霉閿濆洤校婵?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺〒閸╂鎮介娑氭憙缂佺粯娲栭埢浠嬪灳瀹曞浂浼岄柣蹇曞亹閸嬫捇鎮楅悷鎵効缂佽鲸鐛媑etFrameNodeById` 闂佺懓鍢查妵妯肩箔婢舵劕绀嗛柟宄拌嫰铻￠梺缁樺姉濞呫垻妲愬鑸垫櫖?
   * 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亗缁灚绻涙径瀣婵?*濠电偛顦崝宀勫船閻ｅ奔鐒婇弶鍫氭櫅瀹曟洟鏌涢妷褍浠╅柣銊у枔缁灚寰勭仦鍓хシ**闂侀潧妫斿ù鍥焵椤掆偓婵傛梻绮径鎰強妞ゆ牜鍋愰崑鎾诲焵椤掑嫬绀岄柡宥冨妼閻忓洭鏌ゆ０浣侯槮濠殿喒鏅犻幃鑺ュ濞嗘垵鑰块梺鐟扮摠閸ㄥ啿顭ㄩ幋鐐翠氦婵炲棙鎸稿▍锟犳煟椤剙濡奸柛銈嗗灩閺侇喛顦归柛锝呮憸閹风娀寮撮悩鍨儯婵炲濮撮崲鏌ユ偪閸曨垱鍋濋柤鍓插厴閸?
   */
  private static readonly MORPH_RETRY_MS: number = 32;
  /**
   * 闂佸憡鎸撮弲娆戠礊閹达附鐓傜€广儱鐗忓Σ鍛婄箾閸″繐澧查柡鍡欏枛閺佸秹宕奸悢鐑樞栧┑鐐叉閸撴繃鏅堕敃鈧锝夊焵椤掑嫭鐓傜€广儱娲ㄩ弸鍌炴煥濞戞﹩妲撮柍褜鍓氶弻锟犲焵?**闂佺粯鎸嗛崟顐嬶繝鏌涘▎蹇曅ょ紒槌栦簽閹风娀骞嬮悩宕囨殸 `PlayerPage.schedulePublishRetry`**闂?
   *
   *   闂佸搫鐗冮崑鎾愁熆閼搁潧鍝洪柛锝呮憸閹?12 濠电偛鏋撮幍鍐蹭壕濞达絽婀卞Σ銊︾箾閸☆厾绡€婵☆偄娼″?32ms闂佹寧绋戦悧濠囧焵椤掑啫鍚归柣娑栧劦瀹曪綁鏁愰崶褜鍞?384ms闂佹寧绋戦¨鈧紒杈ㄧ箞閹粙濡搁敂浠嬫缂?闂佸憡甯楃喊宥団偓鍨礃濞碱亝鎱ㄩ幇銊ヤ壕濞达絿鏅粻閿嬬箾鐏炵硶鍋撳畷鍥朵紝闁诲繒鍋愰崑鎾绘倵?闂?
   *   闂佺儵鏅╅崰妤呮偉閿濆鍤嶉柛灞剧矊娴狀垶鏌涘▎鎯挎垿宕瑰璺虹煑妞ゆ牜鍋涘▍銈嗙箾閺夋埈鍎嶉柍褜鍓欓崐绋款嚕閻ｅ瞼纾介柡宥庡墰濡差垳绱撴担瑙勫磩妞ゆ梹鍨块弫宥咁潩椤撶噦楠忛梺浼欑到閻厧鈻撻幋锕€绠绘い鎾跺枑閺夌懓顪?*婵炴垶姊婚崰宥囩箔婢跺本鏆滈柟闂磋閺?*闂佹寧绋戦悧鍡涘箖閹捐鍐€闂佸灝顑嗙瑧 push 闂佸憡鍨归崕銈咁焽閻㈠憡鍎嶉柛鏇炲缁€鍡涙煥?
   *   闁诲海鎳撻崯鈺冪不閿濆绠ラ柍褜鍓氱粋?缂備焦顨忛崗娑氱博閺夋垟鏋庨柍銉ㄦ珪閻ㄦ垿鏌￠崼婵愭Ц闁汇劍绻堝Λ鍐閵堝孩锛囬梺?闂佹寧绋戦惌鍌氼焽椤掑嫭鍎嶉柛鏇ㄥ亝閻ㄦ垿鏌￠崟闈涚仴缂佺粯鐗楃粙澶愵敂閸繃顏熼柣鐘叉处濞叉粓鎮伴妷鈺佺煑?+ `setFinalStatus()` 闂佺绻戠划宀€鑺遍幎钘壩?
   */
  private morphRetryLeft: number = 12;
  /**
   * 闂侀潧妫楅懟顖濄亹閸欏顩烽柕澶堝劤绾捐鈹戦纰卞剳闁轰胶鍋撶粋宥夊幢閹般劌浜剧€广儱娲﹂悾閬嶆⒒閸屻倗鍘滅紒杈ㄥ閵囨劙濮€閻樿尙绉梺娲讳簽閸犳劙顢楀鍐惧殨闁逞屽墯閹便劎鈧絽澧庣粈鍕煕閹寸姴小缂傚秴绉归弻宀冪疀閹惧磭鍘掑Δ鐘靛仩濞夋稓鏁崶顒€绀嗛柟宄版湰瀹曟娊鏌ｉ幇顔筋仧缂佽鲸纰嶇粙濠勨偓锝庝簻椤ゅ懘鏌ㄥ☉妯绘拱闁哄棴绲鹃妵鍕礂閸濄儳顔旈梺?*闂佺绻堥崝鎴﹀焵椤掆偓缁绘垵危?*闂?
   *
   * 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劜娴犳﹢鎮烽弴姘鳖槮闁伙絿濞€閺佸秴顫濋銉ь槹婵炲瓨绮屽Λ妤呭储濞戙垺鐓傞煫鍥ㄦ尭閻?闂佸憡顭囬崰搴ㄥ及閸屾壕鍋撻棃娑欐喐婵炲牊鍨规禍鍛婄瑹閳ь剙顭囨导瀛樺剹闁宠桨娴囬崺?闂佹寧绋戦張顒傗偓鍨礃濞碱亪鎸婃径瀣偓鐢告煕閹烘挻绶查柤闀愬嵆瀹曪絽螣閾忓湱锛涙繝娈垮枛椤戝嫮绮婚敐澶嬧拻缂傚牏濮风粣妤呮煛?1~2 闁?
   * 闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熶緱濡插崬霉?*闂佸搫鐗滄禍鐐电磽婢跺奔鐒?*闂佺粯顭堥崺鏍焵?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊浠嬪吹閹寸姵鏆滅憸鎴犫偓姘ュ灲閹ゎ槻闁绘牕澧庣槐鎺懳熼崫鍕幀闁诲繐绻愯ぐ澶屾娴煎瓨鈷掓い蹇撳暟椤忓崬鈽夐幘鎰佸剰闁伙綆鍓熷顐も偓娑櫳戠亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢舵劕违?
   * 闂佺绻楀▍鏇犳暜閳ь剛绱撴担濮戭亪宕哄Δ浣衡枖鐎广儱鎳庨〃娑㈡煕濠靛棛孝缂佹棃顥撴禒锕傚焵椤掑嫭鏅柛褍鍩acity` 婵炴垶鎸哥粔鏉戭嚕椤掍胶鈻旈幖杈剧磿椤忔挳鎮橀悙鈺佷壕闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲秹鍩€椤掍胶顩烽柕澶嗘櫅濞呫倖绻涢弶鎴剳闁告瑥娴烽弫顔碱潰瀹€鈧粻濠氭偠濞戞顫﹂柍?
   */
  @Local introPaintReady: boolean = false;
  /**
   * 閻熸粏鍩囬崹纭呫亹婢舵劕绫嶉柍鍝勫€归崺?闁圭厧鐡ㄥú鐔奉焽閻楀牞绱ｆ繝濠傛椤?濠电儑绲洪埀顒€鍟垮鎶芥煟閵娿儱顏紒顔芥崌閹瑧娑甸崨顖滎啋闁硅壈鎻拋锝囨?闂?闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨鹃懠顒傛闂佸搫瀚烽崹鏉匡耿椤忓懏浜ゆ繛鍡楅叄閸ゅ寮堕埡鍌溾槈閻庣懓鍟胯彁闁炽儱纾弳姘舵煟閵娿儱顏电紒杈ㄧ崑PlayerExpandState.miniBarOpacity` 闂?0.20闂佹寧绋戦¨鈧紒?
   * 婵炴垶鎸堕崐娑氱博閻旇崵鐤€闁告稒鐣埀顒€绻掗埀顒勬涧缂嶅﹦绱為崼銉︽櫖婵﹩鍓涙穱娲⒒閸偅绶涚紒杈ㄧ懄閹棃寮撮垾鎰佹 + 闂佸憡鐟﹂悧鐐寸珶婵犲嫪娌柛宀嬪缁€鍡涙煕閹烘挸顎滅紒缁樼墵閺屽瞼浠︾紒銏犲Η婵犻潧鍊芥慨銈呂ｉ幖浣哥妞ゆ挾鍠愰弶鐟邦渻閵堝洦鏆╂繝鈧垾鎰佹桨闁挎繂娲﹂悾閬嶆煠閸愬弶婀版繛鍛懇閹虫繄鎷犺缁€?
   * 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨鹃崘鑼帓闁哄鏅滈悷鈺呭闯瀹勯偊娼伴柨婵嗘噷閸嬨劍绻涢幋婵堝闁?闂佺偨鍎查弻锟犲焵?闁荤喐鐟ラ崐褰掑礉閸涱垯鐒婇弶鍫涘妽绗?闂佸湱铏庨崢浠嬪棘娓氣偓瀵爼鏁嶉崟顒傛殸婵☆偆澧楃划蹇旂珶婵犲洤绀岄柡宥冨妼閻忓洤霉濠婂啯顥㈤柕鍡楊樀濡啴濮€閿濆懎澹掗梺鍝勬媼閸剟鍩€椤戣法顦﹂柤鑽ゅ枔閹瑰嫰鎮㈤悜妯肩シ闂傚倵鍋撻柛顭戝枔娴?闂?
   */
  private static readonly MORPH_BG_FADE_TO: number = 0.20;
  /**
   * 闁诲繐绻嬬欢姘焽?+ 濠殿喗绻傞懟顖炲箖閺囥垹违鐎光偓閳ь剟鎮界紒姗嗘Ч闁绘劖褰冮悡鍌涙叏濠靛棛鐒烽柣锔界箖閵囧嫰鎮介幖鐐╁亾婵犲洦鐒鹃柕濠忕岛閸嬫挸顓奸崶銊ф殸闂佸搫鍟悥濂稿汲闁秵鏅柛褜鏆€闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婂綊鎯侀鍙ユ勃闁哄洨鍋熺壕濠氭煟閿濆啫鍔ら柣鎿冨弮閺佸秶浠﹂懞銉ь槶婵炴垶鎸搁幖顐︽偩閻樿鐭楁い蹇撴噺绗戦柣蹇曞亹閸嬫捇姊洪鍝勫闁告ɑ鎸惧Σ鎰版偐閸愭彃绨ユ繛杈剧到缁夋煡鍩€?
   *
   * A2 闁荤姍鍛効缂佺粯鐗犲鍫曞焺閸愨晩妲梻鍌楀亾?*闂佹椿浜為崰鎾斥枔閹寸姵鍋栨い鎰╁€栭弳蹇撯槈閹剧姊楃紒?*闂佹寧绋戝濉imateLyricMorph` 闂?`animateTo`闂佹寧绋戦¨鈧紒鍗炲船椤垽濡堕崨顓ф瀫闂佽桨鐒﹀娆撱€冨鍐炬桨鐎光偓閸愵亝袚婵?
   * 闁诲繐绻嬬欢姘焽閹峰被浜归柕蹇曞Т缂嶄線鎮?`lyricMorphVisible = false` 闂佸搫鍟版慨闈涱焽椤栨稓顩烽悹鍝勬惈瑜扮娀鏌ｉ鐔蜂壕闂佹寧绋戦惌浣烘崲閺嶃劎鈻旀い蹇撳閸╂姊洪幓鎺旂婵℃彃鎽滅划姘舵惞鐟欏嫮鏆犻梺?
   */
  private static readonly LYRIC_MORPH_DURATION_MS: number = 360;
  /** 闂佺鐭囬崘銊у幀闂佸憡鐗楀钘夘焽閵堝拋娼伴柕蹇曞濡鈽夐弬鎸庡櫣闁诡喗顨婇幊娑㈩敂閸曨倣妤呮煛閳ь剟骞嗛悧鍫濋棷闂佹寧绋戝鐨婇梺鎸庣☉椤︻參鍩€?*/
  /**
   * 闂佺鐭囬崘銊у幀闂?*缂備礁鏈钘壩涙禒瀣殜妞ゅ繐瀚闂佽　鍋撻柟顖滃瀹?*闂佹眹鍔岀€氼噣鎮洪幋婵愬殫闁告侗鍠楅ˇ褔姊婚埀顒勫礌閿涘嫮顦﹎s闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`PlayerPage.IDLE_MS`闂佹寧绋戦¨鈧紒?*5000**闂?
   *   闂佸憡鍨甸幖顐λ囬埡鍛櫖婵繃顒眜jie.pa:197964` 闂?`stlexvar 0x0, 0x8` 闂佸憡鎸哥粔宕囩博閹绢喖绾?`ldai 0x1388`
   *   闂佹寧绋戝?x1388` = **5000**闂佹寧绋戦¨鈧紒杈ㄧ箞閹?`startIdle()`闂佹寧绋戝澧倁jie.pa:179936-179938`闂?
   *   闁诲繐绻楁ご绋课?`setTimeout(<濞?, IDLE_MS)`闂佹寧绋戦惌鍌炲磻閸涱喚鈻?濞达絽绉归弫宥夊锤?93408-193418`闂佹寧绋戦ˇ顖涚濞戞瑧顩烽柍褜鍓氱粙濠囧醇閻旀劅锕傛煛閸曨偅鎹ｉ柍銉︼耿閹啴宕熼崜浣虹崶
   *   `idleTimer = -1; this.hideChrome();`闂?
   * 闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹鏌?**3000**闂佹寧绋戦悧濠傦耿閻楀牏顩烽柟鍓ф嚀濞堜即鎮楃憴鍕闁逞屽墰閵嗗妲愬┑瀣睄闁绘ɑ褰冨В澶婎熆鐠哄搫顏电紒杈ㄥ哺閸?闁哄鏅滈悷銉ヮ潩閵娾晛鍙?缂備礁鏈钘壩涙禒瀣睄闁割偅娲橀敍鐔封槈閹惧磭小缂佹梹鎸冲?闂佹眹鍔岀€氼厼顭囬棃娑掓敠闁规壋鏂侀崑?
   */
  private static readonly CHROME_AUTO_HIDE_MS: number = 5000;
  /**
   * 闂佺鐭囬崘銊у幀闂?婵炲瓨绮犻崰鏍吹?/ 闂佽　鍋撻柟顖滃瀹?闂備緡鍙忕徊鎯ь焽椤栨粍鍋橀柕澶嗘櫆閿涚喖鏌ｉ妸銉ヮ仾婵＄偛鍊垮褰掑礌閿涘嫮顦﹎s闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`PlayerPage.CHROME_ANIM_MS`闂佹寧绋戦¨鈧紒?*350**闂?
   *   闂佸憡鍨甸幖顐λ囬埡鍛櫖婵繃顒環owChrome()` 婵?`hideChrome()` 闂佸憡鑹剧€氼垶宕靛鍫熺劷闁挎繂妫崑?`animateTo(...)` 闂?`duration`
   *   闂備緡鍠涙慨銈呂?`throw.undefinedifholewithname "CHROME_ANIM_MS"`
   *   闂佹寧绋戝濉磑gic-src/PlayerPage.abc.txt` 闂?11967-11976 婵?4210-4219闂佹寧绋戦¨鈧紒?
   *   闁汇埄鍨遍幃鍌炲闯濞差亜纾?350 闁?`_recover/logic-src/MiniMorph濠电偞鎸稿鍫曟偂鐎ｎ喖妫橀梺顐ｇ〒閻熴垹顪冮妶鍫熺【缂併劍濞婂鍊熺疀閺冨洨鐛ラ梺绋跨箞閸庨亶宕ｉ弴鐑嗗殨?md:163`
   *   闂佹寧绋戝濉丠ROME_ANIM_MS | 350 | 婵＄偑鍊涢崺鏍偉椤曗偓瀵増銈ｉ崘鈺婂悈闂佸搫鍟悥濂稿汲闁秵鏅? D_MAIN闂佹寧绋戣棟闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹鏌?**240 + `Curve.EaseIn`闂佹寧绋戦悧濠囧极閸︻厽灏庨柛鎴欏€楃粈? `Curve.EaseOut`闂佹寧绋戦悧鍡涘极濠婂牆绀勯柣姘嚟缁€?*闂?
   *   闂?*闂佸搫鐗滈崗娑氬垝閵娾晜鍤婃い蹇撳閺嗕即鏌?*闂佹寧绋戦悧濠偽涢妶澶婄闁告繂瀚峰Σ閬嶆煥濞戞﹩妲撮柛?闂?婵炴垶鎸哥粔鐑筋敊韫囨柨绶為柣鐔稿閺併劑鏌ゆ總澶夌敖缂侀硸浜畷?闂佽　鍋撻悷娆忓閻忓洭鏌￠崘顏勑ラ柡鍜佸亰閺屽洭鏁愰崟顔规嫛婵炴垶鎼╂禍婊堝焵椤掑倶鈧妲?
   *   **350ms + `Curve.EaseInOut`闂佹寧绋戦悧濠偽熸径鎰ュ〒姘ｅ亾婵炲牞缍佸畷銉т沪閼测晩浼囬梺鍝勵槴閸撴繂煤閸濄儳妫柛鏍电磿缁€鍡涙煏?*
   */
  private static readonly CHROME_ANIM_MS: number = 350;
  /** 闂佸綊娼ч鍡椻攦閳ь剛绱?Swiper 闂備焦褰冪悮顐﹀焵椤掆偓閺堫剟鎮洪弴鐘冲珰鐎广儱顦埀顒€顦垫俊鏉戭吋閸ャ劎鏆犳繛鎴炴尭椤戝棝鎮ラ敐澶嬫櫖? = 闁诲繐绻嬬欢姘焽閻楀牄浜滅痪鏉款槺缁€鍡涙煏?*/
  private static readonly SWIPER_INDEX_LYRIC: number = 1;
  /**
   * 濠殿喗绻傞惌渚€鎯佸┑瀣?*婵炴垶鎸搁敃锝囩箔閸涱収鐓ラ柟瀛樼箓閻庡ジ鏌熼獮鍨仾閻㈩垰鐖煎畷姘辨崉閸濆嫰娈?*闂佹眹鍔岀€氭澘危閸ヮ剙纾圭痪顓㈩棑缁€鍓塸闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佺粯鎸嗛崟顐嬶繝鏌￠崘顏勑ラ柡?`SWIPE_TOGGLE_VP`闂?
   *
   * 闂佸憡鍨甸幖顐λ囬埡鍛櫖婵繃鐡峫ayerPage.onLyricSwipe`闂佹寧绋戝濉ecover/logic-src/PlayerPage.abc.txt:6942` 闂?
   * `throw.undefinedifholewithname "SWIPE_TOGGLE_VP"`闂佹寧绋戞總鏃€绂嶉幒妤€鐭?*婵°倕鍊硅摫闁?*闂佹眹鍔岀€氼剟鎮鸿濡啴濮€閵堝懏顏?
   * `6974 ldai 0x18` = **24**闂佹寧绋戦¨鈧紒杈簿閵囨劙骞掗幘鎵佸亾閸屾粍鏆滈柟闂寸濞呫倝鎮?`MiniMorph濠电偞鎸稿鍫曟偂鐎ｎ喖妫橀梺顐ｇ〒閻熴垹顪冮妶鍫熺【缂併劍濞婂鍊熺疀閺冨洨鐛ラ梺绋跨箞閸庨亶宕ｉ弴鐑嗗殨?md:171`
   * 闂佸憡鑹鹃張顒勬偋鏉堚晜濯奸柟娈垮枟缁?`SWIPE_TOGGLE_VP | 24`闂?
   * 闂佸疇娉曟刊瀵哥箔?闂佸搫鐗滈崗娑氬垝閵娾晛鍌ㄩ柣鏂挎啞闂勫秹鏌涢幇顓犳噮婵炲牊鍨垮?**12**闂佹寧绋戦悧鎰板吹濠婂應鍋撶憴鍕殤婵炲牊鍨剁粙澶愬焵椤掑嫬纭€濠电姴绻掔粈鍡涙煃?婵犮垽顤傛禍婊堫敊閹版澘鍙婇柟鎹愵嚃閸ゆ牠鎮峰▎娆掝吅缂佽鲸鐟╁鐢割敆閳ь剟鎯囨导鏉戝強?`parallelGesture`闂佹寧绋戦ˇ顓㈠焵?
   */
  private static readonly SWIPE_TOGGLE_VP: number = 24;
  /**
   * 濠殿喗绻傞惌渚€鎯佸┑瀣?*婵炴垶鎸搁敃銉у垝閿曞倹鈷曢柟閭﹀灡椤ユ垿鏌熺挩澶婂暙閻撴垿鏌?*闂備緡鍙忕徊鑲╃博閹绢喖缁╂い鏍ㄧ⊕绗戦梺鍛婄啲闂勫嫰寮担鍓插殨闁?闂佺偨鍎查弻锟犲焵?闁诲海鏁搁幊鎾惰姳閺屻儱绫嶉柣妯虹仛濞呮洟鏌?`entryAllowsManual(lyricImmersive)` 闂傚倸鍊堕崝濠囧焵?
   *
   * 闂佸搫鍟版慨鐑藉疾椤愶附鏅慨婵囩摫ntryAllowsManual(mode) = mode === MANUAL || mode === BOTH`闂佹寧绋戦惌渚€鍩€?
   * `LyricEntryMode` 婵帗绋掗…鍫ヮ敇鐠囧樊娴栭柨婵嗘绗?**AUTO**闂佹寧绋戝澶嬫叏濠靛棛鐒烽柣锔界箖閵囧嫰宕归銉ф闁诲繒鍋涢崐鎼佹儍濠靛顥堟い顐幘閻熴垺鎱ㄥ┑鍡氬闁诡喗娲滈埀顒冾潐濮樸劑鈥?md` 闁?闂佹寧绋掗悺瀛嶧0 / AUTO1 / MANUAL2 / BOTH3闂?
   * 闂?**婵帗绋掗…鍫ヮ敇鐠囧樊娴栭柨婵嗗閻?婵炴垶鎸搁敃銉у垝閿曞倹鈷曢柟閭﹀灡椤?婵炲濮崑鎾斥槈閺傝法澧﹂柛蹇斏戠粙澶婎吋閸涱剛椹?*闂佹寧绋戦悧鎾诲磻閸涱喚鈻旈柍褜鍓熷銊╊敍濞戞瑦顔掑┑鐐茬墔缁插锝為敃鍌涒拻闁靛绠戦惃鈥趁归敐鍛寸崪缂佽鲸宀告俊?
   * 闂佸搫鐗滈崗娑氬垝閵娿儮鏌﹂柍鈺佸暞缁犳帡寮堕埡鍌滄噥闂佸弶绮撻幃浠嬪Ω閿曗偓閻撴洟鎮规担绋库挃闁汇倕妫濋弫宥夊醇閵夛附銆冮梺鍝勵槸濞硷繝宕冲畡鎵虫煢闁斥晛鍟粻?濠电偛鑻ˇ浼寸叓閸繍娼扮€光偓閸愵亝袚濠碘槅鍨埀顒€纾涵鈧?闁哄鏅滈悷銈囩博鐎涙ǜ浜滈柣褍鎽滅粈鍡涙煃?闂?*婵帗绋掗…鍫ヮ敇?*闁荤偞绋戞總鏃傛嫻閻旂厧违?
   *
   * 闂佸疇娉曟刊瀵哥箔?**闂佽　鍋撻柣鐔哄缁€鈧?true 闁诲繐绻楁ご绋课?婵炴垶鎸搁敃銉у垝閿曞倹鈷曢柟閭﹀灡椤ユ垿鏌熺挩澶婂暙閻撴垿鏌?闂備焦褰冪粔鐢稿蓟婵犲洦鍋ㄩ柣鏂挎啞濞?*闂佹寧绋戦悧鍛博鐎靛憡鍋樼€光偓鐎ｎ剛顦梺鎸庣⊕缁嬫垿宕欓敓鐘叉嵍?
   *   `RzdMusic閻庡灚婢橀幊鎰板灳濡吋濯奸柕鍫濇椤忔悂鏌?md` 缂?33 闂佸搫顧€缁绘繈宕抽悜钘夊強閹艰揪绲洪埀顒侊耿濮婂顢欓懡銈団槈"闁荤喐娲戝鎺旂箔婢跺本鍟哄ù锝囨櫕缁犵懓鈽夐幙鍐х凹濠⒀勭矒瀹?闂?
   */
  // ⚠️ 2026-10-17 订正：上一轮为「上滑是否允许手动收起」自造的 `LYRIC_SWIPE_ALLOWS_MANUAL = false` **已删除** ——
  //   判据抄错了：上游**默认档就允许**手动收起（见下方 `LYRIC_IMMERSIVE_MODE` / `entryAllowsManual()`）。
  /** 照搬无界 `LyricEntryMode`（`_recover/disasm/wujie.pa:264094-264130`，
   *  反编译函数 `&entry.src.main.ets.player.LyricFollow&.#%#LyricEntryMode`）：
   *  ```
   *    OFF    = 0    // ldai 0x0
   *    AUTO   = 1    // ldai 0x1
   *    MANUAL = 2    // ldai 0x2
   *    BOTH   = 3    // ldai 0x3
   *  ```
   */
  private static readonly LYRIC_ENTRY_MANUAL: number = 2;
  private static readonly LYRIC_ENTRY_BOTH: number = 3;
  /**
   * 上游 `PlayerPage.lyricImmersive` 的**默认档 = BOTH(3)**，两处独立佐证：
   * 1) `@State` 初值：`wujie.pa:169039-169056` —— `tryldglobalbyname "ObservedPropertySimplePU"`
   *    + `ldexternalmodulevar "LyricEntryMode"` + `ldobjbyname "BOTH"` ⇒ `__lyricImmersive` 用 **BOTH** 构造；
   * 2) 进页从偏好读：`wujie.pa:169819-169825`（`this.lyricImmersive = this.pref.lyricImmersiveMode()`），
   *    而 `PreferenceStore&1.0.0.#~@0>#lyricImmersiveMode` 里 `getSync(KEY_LYRIC_IMMERSIVE_MODE, v0)` 的默认值
   *    来自 `nop / ldai 0x3 / sta v0` ⇒ **3 = BOTH**
   *    （抽法：`node tools\extract_fn.js disasm\wujie.pa '>#lyricImmersiveMode'`）。
   * ⇒ 上游默认档**允许手动上滑收起**：`entryAllowsManual(BOTH) === true`。
   * 本仓没有「歌词沉浸档」这个设置项 ⇒ 恒取上游默认档 BOTH。
   */
  private static readonly LYRIC_IMMERSIVE_MODE: number = 3;

  /**
   * "濠电姴锕ラ懝鐐叏閳哄倻顩风€广儱鎳忛煬顒勫级閳哄倻顬兼い?闂佹眹鍔岀€氼剟宕归悾灞稿亾鐟欏嫭鐨戦柣娑栧劦閺佸秹宕搁。娆撴煥濞戞﹩妲撮柍褜鍓氶弻锟犲焵?闁?`lastScrollAtMs` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电偛绨遍崑?
   *
   * 闂?2026-10-16闂佹寧绋掓穱铏规崲閺嶃劎鈻旈柍褜鍓熷?*婵炴垶鎸哥粔闈浳ｉ幖浣哥闁靛ě鍕瘞闂佸搫鍟悥濂稿汲闁秴违濞达綁顥撻悷婵嬫煛閸曢潧鐏ユい顐㈡喘楠炲洭鎮㈠畡鐗堫棟闂?*闂佹寧绋戦惌渚€鍩€椤掆偓閺堫剙危?婵炴垶鎸堕崐妤咃綖閹烘挶浠氶柛妤冨仜琚熼梺鍝勫€婚幊鎾舵閿熺姷宓侀悹楦挎閹?闂佸搫鍟晶搴♀枔閹寸偟顩烽柤濂割杺濮婂潡鏌?
   *   `onContentDidScroll`闂佹寧绋戦悧鎾诲焵椤掍礁濮囬柟鑸电濞艰鈽夊Ο渚敽闂佹寧绋戦ˇ顖滅礊鐎ｎ兘鍋撶涵鍛厫婵＄偛鍊块弫宥団偓鐟扮倰yncLyricMorphToPage()` 闂?闂佽В鍋撻柦妯侯槺閺?闂婎偄娲ら幊姗€濡磋箛鏇熷闁宠　鍋撶紓宥呮嚇婵?
   *   闂佸疇娉曟刊瀵哥箔?120ms 闂?7 闁汇埄鍨庡鍥╃崶闂佸綊娼ч鍡欌偓鍨哺楠炲酣顢楅崘鈺侀棷闂?swiper 闂佹眹鍔岀€氼參宕曟繝姘畱鐟滃海鍒掗幘顔肩闁靛鍊楅閬嶆煕鐎ｎ偆鐜荤紒杈ㄧ箞閹峰啴鎸婃径灞炬瘞闁诲繐绻楃划楣冨礂濮椻偓楠炴帡濡疯閸氣偓闂佽　鍋撻悹楦挎閸熸煡鏌?
   *   闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯鈺冪箔?`Swiper` 闂佺厧顨庢禍婊呮崲娓氣偓閹?`duration` 闂佸搫鍟版慨鎾矗瑜旈弫宥夊醇閵夈儰绨兼繛鎴炴惄娴滄粏銇愯瀹曠兘濡歌閺屻倝骞栭弶鎴犵閻庡灚鐓″畷姘跺炊椤戦敮鍋撴径鎰睄闁诡垳澧楀畷鍐裁归敐鍡欑煂闁轰降鍊濋弫宥嗗緞閸艾浜?
   */
  private static readonly SCROLL_SETTLE_WINDOW_MS: number = 120;
  /**
   * 重发"歌词页终点几何"的最大重试次数与间隔（**照搬上游**
   * `PlayerPage.PUBLISH_RETRY_MAX` / `schedulePublishRetry`，`wujie.pa:175916-175929`）。
   */
  private static readonly PUBLISH_RETRY_MAX: number = 6;
  private static readonly PUBLISH_RETRY_MS: number = 32;
  /**
   * 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垻顭堟禍婵嗏槈閹绢垰浜惧┑鈽嗗灱娴滐綁銆侀幋锔芥櫖闁割偅绻嶉崵鐘绘煛瀹ュ懏澶勬俊顐犲€濋幃?`metaRow`闂佹寧绋戦ˇ鍗炩枔閹达箑绠抽柟鐑樻煥椤ｅジ鎮介娑欏€愰柛?闂佺偨鍎查弻锟犲焵?闂佽桨鐒﹀姗€鍩€椤掑倸甯剁憸鏉挎喘閹?
   * `PlayerPage闁诲海鎳撻張顒勫汲椤ゆ杯闁诲氦顫夊銊┾€?md` 闁?.2闂佹寧绋掔喊宥夋偉閿濆棴绱?`15` / 缂備緡鍠楅妵鐐电礊?/ 闂?/ `opacity 0.86`闂佹寧绋戦張顒勬偤閺囥垹绠?`12` / 闁汇埄鍨遍悺鏇綖婢舵劕违?
   */
  private static readonly LYRIC_META_TITLE_FP: number = 15;
  private static readonly LYRIC_META_ARTIST_FP: number = 12;
  /**
   * **闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏㈩焾娴滄繂鈽夐幘顖氫壕缂?*闂佹眹鍔岀€氼參鎮洪弴銏犺Е?濠殿喗绻傞張顒佹櫠濠婂應鍋撳☉娆樻當鐟滄澘娼￠弫宥夊锤閹额亪鏌ㄥ☉姗嗘Т闁逞屽墯閺岋繝鍩€?闁诲簼绲婚～澶愭偉閿濆绫嶉柣妯虹仛濞?`chrome().titleSize` / `chrome().artistSize`闂佹寧绋戝﹢妗縇L 濠碘剝顨愮紞鍥╂濮樿泛违?
   *
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂侀亶浜跺鐢割敆閸愵亝鐎繛瀵稿Т妤犳悂鎮鸿閹崇偤宕掑鍛仯闂佸湱绮崝鏇°亹閸ヮ剚鏅?*闂佸憡鑹鹃張顒€顪冮崒婊呮／闁绘ɑ鍓氶崝鈧梺鐟扮摠閸ㄥ磭绮崒娑氣枖闁逞屽墯濞碱亪顢欓悙顒傛殸婵炴垶鎸撮崑鎾愁熆鐠哄搫顏い鏇樺€楅幏?*闂佹寧绋戦¨鈧紒?
   *   闂佸搫鍟版慨鐑藉疾椤愶附鐒?*婵炴垶鎸撮崑鎾斥槈?* `Text` 闂佹眹鍔岀€氼剟鎮鸿瀹曪綁鏌ㄧ€ｎ倣?*闂佸湱绮敮鎺楀焵?*闂佸憡鍨归崕銈咁焽閻㈠憡鍎嶉柛鏇炲缁€鍒瀢ujie.pa:194905-194939`闂佹寧绋戦悾鐠磂rp` 婵炴垶鎸搁ˇ顖氼嚕椤掑倹瀚柛鎰典簼閺嗗繘鏌ㄥ☉姗嗘缂?
   * ```
   *   fontSize( lerp( chrome().titleSize * sizeK(),   // 闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏☆問娴?= 20 闁?sizeK
   *                   15 * sizeK(),                   // 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垺顔栨导?= 15 闁?sizeK
   *                   metaProgress() ) )              // 闁哄鏅滅粙鎴犫偓瑙勫▕閺? swiperProgress闂?
   * ```
   *   濠殿喗绻傞張顒佹櫠濠婂牆瑙︾€光偓閳ь剟骞冩繝鍥ㄦ櫖婵繃顒rp( chrome().artistSize * sizeK()(=14), 12 * sizeK(), metaProgress() )`闂?
   *   闂?**闁诲繐绻嬬欢姘焽閻楀牄浜?20 / 14闂佹寧绋戦張顒勬偤閺囩姵瀚氱€广儱顦埀?15 / 12**闂佹寧绋掗惌鏉漣zeK()` 闂?缂備焦鍔栭〃鍛般亹濞戞埃鍋撶涵鍛棄閻庤濞婇幆鍐礋椤愩垺鐦ｉ梺?
   *     闂佹寧绋戦悧濠冩櫠濠婂牆瀚夐弶鐐村閻?闂?闂佹寧绋戦懟顖炴煢閳哄懎绾?PC 闂佸綊娼х粔闈涳耿娴ｅ壊鍟?闂佺偨鍎查弻锟犲焵?闁?`RzdMusic閻庡灚婢橀幊鎰板灳濡吋濯奸柕鍫濇椤忔悂鏌?md` E5闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂?*婵炴垶鎸堕崐婵嬪Υ婢舵劖鐒鹃柦妯侯槹缁佸ジ鎮?15 / 12** 闂?**闁诲繐绻嬬欢姘焽閻楀牄浜滈柛顭戝亞閹藉啴鏌涘顒傂㈠ù婊冩憸娴?33%闂?5 vs 20闂?*闂侀潧妫旈悞锕傛偤閺囥垹绠ラ悗锝庝簷閻掑﹪鎮樿箛鎾荤崪缂?2 vs 14闂佹寧绋戦ˇ顓㈠焵?
   * 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏇炴缁€鍕箹?6.27闂佹寧绋戦ˇ浼村垂濠婂嫮鈻旈柍褜鍓氶幆鏃堟晜閽樺）鈺呮倵閻熸澘鏆㈡い鏇氬嵆楠?闁诲孩绋掗〃鍛般亹鐠恒劍鍟?*婵?* `metaProgress()`"闂佹寧绋戦懟顖炴嚐閻旂厧绠叉い鏃傜摂閸斿啴鏌?婵炴垶鎸哥粔鐑筋敊韫囨稑缁? 闂佺偨鍎查弻锟犲焵?
   *   **闂備緡鍙忕徊濂告煂濠婂懏瀚氱紓浣诡焽閵嗗﹪鏌￠崟闈涚仸闁轰礁锕幆?*闂佹寧绋戦悧濠冧繆?`lerp` 閻熸粎澧楅幐濠氬垂濮橆厾顩查柛鈩冩礈椤旀帗绻涙径瀣┛缂佽鲸绻冪粋宥嗘償閵忊寬锕€霉閻橆喖鍔欓悹鎰枔娴滃憡绗熼埀顒€顭囬悧鍫涗簻闁稿繐鎽滅粣妤呮煕濞嗘兛鎴﹀垂?0 闂佸憡鐟ラ崲鏌ユ偤瑜旈弫宥嗗緞閸艾浜?
   *   闂佹椿浜為崰鎾趁规径鎰強妞ゆ牗绋戠徊濠氭煕婵犲嫨鈧妲愰幍顔瑰亾濞戞瑯娈旂憸?*婵炲濮寸花鑲╃箔婢跺ň妲堥柛顐ｇ缚娴?*闂佹寧绋戦懟顖濄亹瑜斿?*闂?20 闂佽　鍋撻悹鍝勬惈閻?15**闂侀潧妫楅崐鐟帮耿閻楀牊濮滄い鏃囨閻﹀鏌ｉ鍡楁灁婵炴潙顦靛銊ф喆閸曢潧濡ч梺?
   */
  private static readonly META_TITLE_FP_COVER: number = 20;
  private static readonly META_ARTIST_FP_COVER: number = 14;

  /**
   * 閻熸粎澧楅幐鍛婃櫠閻樿櫕浜ゆ繛鍡楁捣椤忛亶鎮介鍡楁噺閻?*濠殿喗绻傞懟顖炲箖閺囩姭鍋撳☉娆樻當鐟?*闂佹寧绋戝姝遍梺鎸庣☉椤︻偊鍩€椤掍焦鐓涢柍?婵炴垶鎸堕崐妤咁敂椤掍胶鈻曢悗锝庡枟閿涚喖鏌?*濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻濞达絽鍟扮粻濠氬箹?*闂佸湱绮敮鎺楀焵椤掑偆鍎犻柍?
   *
   * 闂?闂?`lyricMorphT`闂佹寧绋戦悧濠傦耿閻楀牄浜?闁诲繐绻嬬欢姘焽閻楀牄浜?闂?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻?闂佹眹鍔岀€氼垳鎹㈠Ο缁樺劅闁挎棁鍋愮粈鍡欐喐閻楀牊灏版俊顐犲€濋幃?`metaProgress()` 闂佹眹鍔岀€氼噣鎮洪幋鐐殿浄濡炲楠搁埛鏍煥?
   *   闂傚倸鐗婇悷锕傤敆濞戙垹鎹堕柕濞垮劤濞堥亶姊婚崼娑樼伈闁?= 0 闂?`20fp`闂佹寧绋掗惄顖氼焽閵堝拋娼伴柕蹇曞У闊剚鎱ㄥ┑鍡欑劮闁伙附绻冮妵?= 1 闂?`15fp`闂佹寧绋掔粙鎴﹀垂韫囨柣浜滈柣銏㈩焾娴?360ms 闂備焦褰冮惌浣烘崲濞戞氨纾兼い鎿勭磿缁犳牗绻涢幘鈧幍鍐蹭壕?
   * @returns 濠殿喗绻傞懟顖炲箖閺囩姭鍋撳☉娆樻當鐟滄澘娼￠弫宥夊锤閹额亪鏌?
   */
  private metaTitleFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_TITLE_FP_COVER,
      PlaybackPage.LYRIC_META_TITLE_FP, this.lyricMorphT);
  }

  /**
   * 閻熸粎澧楅幐鍛婃櫠閻樿櫕浜ゆ繛鍡楁捣椤忛亶鎮介鍡楁噺閻?*濠殿喗绻傞張顒佹櫠濠婂應鍋撳☉娆樻當鐟?*闂佹寧绋戝姝遍梺鎸庣☉椤р偓缂佽京娅?4`闂佹寧绋戦悧鍡涙儍濠靛顥堥柕蹇嬪€戦埀顒€顦甸弫宥嗗緞閸℃娅?`12`闂佹寧绋戦悧濠囨偤閺囩姵瀚氱€广儱顦埀顒€顦甸弫宥嗗緞閸艾浜鹃柛灞剧矋閸婄偤鏌ｉ姀鐘茶埞闁?{@link metaTitleFp}闂?
   * @returns 濠殿喗绻傞張顒佹櫠濠婂應鍋撳☉娆樻當鐟滄澘娼￠弫宥夊锤閹额亪鏌?
   */
  private metaArtistFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_ARTIST_FP_COVER,
      PlaybackPage.LYRIC_META_ARTIST_FP, this.lyricMorphT);
  }

  /**
   * 婵炴垶鎸堕崐妤咁敂椤掍胶鈻曢悗锝庡枟閿涚喖鏌ｉ妸銉ヮ伀闁搞倕閰ｉ獮鈧憸搴ゃ亹閸愵喖纾圭痪顓㈩棑缁€鍒瀟` 婵犮垹澧庨幊鎾诲春?0..1闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婅崵鍒掗悧鍫⑩枖濠电姴娲﹀銊モ槈閹惧崬鈧捇鏌屽鍛亾濞戞瑯娈旂憸鏉挎健閹粙濡搁敐鍌氫壕?
   * @param from `t = 0` 闂備緡鍙忕徊鑲╃博鐎靛摜鍗氭い鏍ㄧ矋閻ｉ亶鏌?
   * @param to `t = 1` 闂備緡鍙忕徊鑲╃博鐎靛摜鍗氭い鏍ㄧ矋閻ｉ亶鏌?
   * @param t 闁哄鏅滅粙鎴犫偓瑙勫▕閺佸秹宕煎鍕簥闂佽婢樼换鎰版偪閸曨垰鏋侀悽顖ｅ枤缁€澶愭煕閹邦剚鍤囬柛搴＄摠瀵板嫰鎮烽弶璺ㄦ偧闂?
   * @returns 闂佸湱绮敮鎺楀焵椤掑啫浜圭紒顔哄姂瀵?
   */
  private static lerpFp(from: number, to: number, t: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return from + (to - from) * p;
  }
  /** 闁诲繐绻愮换鎰版儍濠靛顥堥柕蹇曞Т缁€浣虹磽閸屾耽顏堝春鐏炵瓔娼伴悘鐐跺Г閸婃娊鏌ｉ妸銉ヮ伃婵☆偉娉曢幑鍕攽閹惧墎顦﹙p闂佹寧绋戦ˇ顓㈠焵?*/
  private static readonly LYRIC_META_GAP_VP: number = 12;
  /** 闁荤姴娲㈤崕鎾€侀幋锕€鐭楅柛蹇撴噺濞呯娀鏌ｉ敐鍡欐噮婵炲憞鍥ㄦ櫖闁秆咁棗闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?缂傚倷鐒﹂悷锕傚极瑜版帗瀵?闂佸搫娲﹀娆撍囬幐搴ｂ枖闁靛牆瀚伴崵瀣煕閵壯冧壕闁绘牭绲块幏瀣煛閳ь剛绱為崨鏉懳?*/
  private static readonly LYRIC_META_SIDE_VP: number = 16;
  // 闂佸疇娉曟刊瀵哥箔?2026-10-15闂佹寧绋掗悺鐙禮RIC_META_ICON_FP` **閻庣懓鎲¤ぐ鍐垂瑜版帗鈷?* 闂佺偨鍎查弻锟犲焵?闂佽　鍋撻柟顖滃椤?/ 闂佸搫娲﹀娆撍囬崸妤佺劷闁挎繂瀚埛鍫濃槈閹垮啩绨绘繛瀛橈耿瀵粙宕堕妸锔芥瘔闂?
  //   `this.expandState.chromeFavSize()`闂?*闂佸湱顭堥ˇ浼村Υ閸屾稒濯寸€广儱鐗勯埀顒€鍟村畷锝夊冀瑜夐崑?* 24 / 22 / 20闂佹寧绋戦¨鈧紒?
  //   闁诲海鎳撻張顒勫汲閿濆绀勯柛婵嗗濡查亶鏌ㄥ☉妯荤秮chrome().favSize`闂侀潧妫斿姊瑄jie.pa:195193 / 195316`闂侀潧妫旈悞锕傚Υ閸屾稒濯寸€广儱鐗勯埀?`93534`闂佹寧绋戦ˇ顖炲疮閹捐鎹堕柕濞炬櫅娴滄繂鈽夐幙鍐х凹闁哄瞼鍠庨埢鏃堝即濮樿京鎲梺?
  //   闂佸憡甯炴慨鎾偩閻樼粯鍎嶉柛鏇ㄥ亜閺傃囨煕閵壯冾€撶紒鍙樺嵆瀹曘垽鎮㈤崨濠囨闁哄鏅滈悷鈺呭闯閻戣棄绀冩繛鍡樺姦閸?`22`闂佹寧绋戦悧濠囧极閻愮儤鐓傚┑鐘叉噹濞堜即姊?闂佸憡鐟﹂悧鏃傜箔鐏炵煫鐑樸偅閸愵亜寰撴繛鎴炴尨閸嬫捇鏌ゅ畡閭﹀殶婵炲牊鍨剁粙澶愬焵椤掆偓椤?闂?*婵炴垶鎸哥粔闈浳ｉ幖浣哥睄闁绘ê鐏氬▍鏇㈡煟閵娿儱顏╅柍?*闂佹寧绋戦¨鈧紒?
  //   闂佺懓绠嶉崹娲垂?getter 婵炴垶鏌ㄩ鍛村箖濡や焦浜ゆ繛鍡楅叄閸ゅ鎮介娑欏€愰柛锝堟娴?*濠电偛澶囬崜婵嗭耿娴ｇ儤瀚柛鎰典簼閺嗗繘鏌ら弶鎸庡櫢缂?* 闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥粔鍫曞汲閳ь剚鎱ㄥ┑濠庡敽闁哥儐鍓熼幆宥嗙瑹婵犲嫮顦╅梺鍛婅壘閺堫剙螞鐏炲鈧帡宕ㄩ娑樷偓鐐烘偡?闁?6.15 / 闁?6.20闂佹寧绋戦ˇ顓㈠焵?
  /** 闂佹悶鍎抽崑鎾绘偉閿濆鍎嶉柛鏇ㄥ幖娴狀垶鏌涢幋锝呭惞闁稿骸缍婂畷鐘炽偊鐠恒劎褰鹃梻鍌楀亾闁告牭绱曠粈鍓塸闂佹寧绋戦懟顖炴偩婵傜妫?`HIT = 44`闂佹寧绋戦ˇ顓㈠焵?*/
  private static readonly LYRIC_META_HIT_VP: number = 44;
  /**
   * 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垻顭堟禍婵嗏槈閹绢垰浜惧┑鈽嗗灱娴滐綁銆侀幋锔藉剭?*闁荤偞绋戦惌鍌炴偟?*闂佹寧绋戝濡忛梺鎸庣☉椤︻偊鍩€椤掍焦鐓涢柍?婵炴垶鎸堕崐娑€侀幋锕€妫橀柛銉戝懏鎲婚梺鎸庣☉閻楀﹪鎮ラ敐鍡矗?15 / 濠殿喗绻傞張顒佹櫠?12 + 2 闂傚倸鍊婚ˉ鎰玻濞戙垺鏅? 闂佹悶鍎抽崑鎾绘偉閿濆鍋╂繛鍡樺灦椤忋倝鏌?
   * 闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯顐ャ亹瑜旈幃浠嬪Ω閵堝洩澹?缂備焦姊归悧婊兠虹捄銊ゆ勃闁告侗鍓濋崢顒勬偠濞戞牕鍔氬ù?闂佹寧绋戦悧鎰帮綖?`LyricFloatLayer` 闂?`.position()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煥?
   *    **婵炴垶鎸哥粔鐑姐€?*闂佽　鍋撻悷娆忓閻忓洭鎮樿箛搴ｇ獢婵炶偐澧楀蹇氥亹閹烘挻鐦?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鑲╂娴兼潙绠┑鐘插€诲▓閬嶆⒒閸稑鐏查柕鍡楊樀閹啴宕熼鍌涙啓闂佸憡鑹剧粔瀵告濮橆厾鈻旈悗锝庡亜閼靛綊鏌涘Δ鈧敃锝夋煂濠婂嫬绶炵憸宥夋儍濠靛顥堥柕蹇嬪灪閻ｅ崬螖閸屾耽顏嗏偓瑙勫▕婵?
   */
  private static readonly LYRIC_META_ROW_H_VP: number = 34;
  /** 缂傚倸鍟崹鍫曟偋閹间焦鍤勯悘鐐靛亾閻濐垱绻濊閸旀鈻撻幋锔藉剮闁圭儤鍨圭涵鈧┑鈽嗗灲缁辨洜娑甸敃鍌氱濠电姴鍊荤粣?/ 闁哄鍎愰崰妤呭汲閻斿吋鏅柛顐ゅ枑閿熴儵鏌?`MeshCoverBg` 闂?`BLUR_RADIUS` / `BLUR_PASSES`闂佹寧绋戦ˇ顓㈠焵?*/
  private static readonly MESH_BLUR_RADIUS: number = 9;
  private static readonly MESH_BLUR_PASSES: number = 3;
  /** 闁诲繒鍋炲ú鏍閹达附鍎戦悗锝庡枟閿涘矂鏌ｅ▎鎰垫缂佽鲸鐛闂佹寧绋戦¨鈧紒杈ㄥ閹奸箖宕ㄩ绛嬫Н闁哄鏅滆摫闁汇儱鎳樺畷鍫曟倷閹绘帞鍘掗柣搴ｆ嚀閺堫剟寮抽敐澶婄畱濞达絽鎲￠惃鎴犫偓娈垮枛閹碱偊宕哄Δ鍛倞闁绘劖褰冮悡鍌炴倵閻熺増婀伴柡鍡秮楠炩偓濞达絿顣介崑?*/
  private static readonly COLLAPSE_WATCHDOG_MS: number = 900;
  /** 闁诲繒鍋炲ú鏍閹达附鍎戦悗锝庡枟閿涘矂鏌ｅ▎鎰垫當闁伙綁绠栧顔炬崉閻戞褰滈梺鍛婄懀閸庢煡鎮炲ú顏勎?*/
  private collapseWatchdogTimer: number = -1;
  /** 濠殿喗绻愮徊钘夛耿椤忓牆绠绘い鎾跺枑閺嗩亪鎮硅閸㈠弶鎱ㄩ埡鍛仺濞村吋鐟х粈鍕⒒閸愩劌绾фい鎺撶⊕濞煎鎮欓棃娑楀寲闁哄鏅滈弻銊ッ洪弽顓炵妞ゆ挻绻嗛埛鍫ユ⒑椤掆偓缁嬪嫮妲愬璺何?*/
  private isClosing: boolean = false;
  /**
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸曘劌浜鹃柛鈩冾殕閸?P0-3闂佹寧绋戦¨鈧紒鍙樺嵆瀹曞爼鎮欓懠璺哄⒕闂佽　鍋撻悹楦挎閸熸煡鏌?*闂佺粯鐟崜娑㈡偟濞戞瑧顩烽柨婵嗘－閸?*闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?**婵炴垶鎸哥粔鐑姐€呴敃鍌涘仺?`morphGen` 闂佸搫绋勭换婵嬫偘濞嗘劖浜ゆ繛鍡楁捣椤忚鲸鎱?*闂佹寧绋掗悺鐚皁rphGen` 闂?闂佸憡鍨规慨宕囩礊瀹ュ棛顩烽柨婵嗘－閸?闂?
   *   `morphBeginEntering` / `morphBeginLeaving` / `morphReset` 闂備緡鍠楅崹婵堟?`++`
   *   闂佹寧绋戝濉抣ayerExpandState` L2330 / L2437 / L2456闂佹寧绋戦ˇ顐﹀闯?240ms 缂備焦鍔栭〃鍛般亹濞戙垺鐓傞悘鐐舵濞懷囨偡閺囨碍绁伴柟鐧哥稻缁?*婵炲濮鹃濠勭礊?*闂佸搫鍊块。锔炬閹殿喗瀚氭繝鍨尵缁€?
   *   闁哄鏅滈悷锕傤敃婵傜缁╅悹楦挎閸熸煡鎮樿箛姘辩翱妞?*闂傚倸鐗婇悷鈺冨垝椤栨粍宕夐悗鍦Х缁?*闂佹寧绋掔粙鏍焵椤掆偓閼活垶鎮鹃悩璇插強?*闂佸摜鍎愰崹顖滅博?*闂?`morphDrive` 濠电偞鎸搁幊搴∶?`NONE` 闂佹眹鍔岀€氼剙锕㈤幘顔兼?
   *   闂佹寧绋戝濉祇rphSettleOpen()` L2421闂佹寧绋戦ˇ顐﹀闯?`morphSessionDriving()`闂佹寧绋戝﹢?487闂佹寧绋戦ˇ鐗堢娴犲鍎?
   *   闂?婵犮垻鎳撻崯鍧楁儑娴兼潙绀傞悗锝庡枟閻ｇ兘鎮橀悙鎻掍喊缂佽鲸鐟︾粙澶嬪緞婢舵劕娈濋梺鍦焾椤︾敻骞?/ 濠殿喗绻傞懟顖炲箖閺囥垺鏅璺猴功閸╂顪冪涵鍜佸殭婵犫偓椤忓棔娌煫鍥ф捣閻熸劙鏌?
   *   闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴顫㈠鈺燾 shell hilog -x | Select-String 'RzdMorph'` 闂佺偨鍎查弻锟犲焵?婵炴垶鎸撮崑鎾诲级?婵炴垶鎸搁鍡樺垔濞差亜鐒奸柟鐑樻尰缁堕亶鏌?闂?
   *   闂?`morph open (settled)` 闂佸搫鐗嗛ˇ浼存儉閸涙潙瀚夊璺猴工濮ｅ鏌ｅ鍡楃劷闁?
   */
  private dismissSettleGen: number = 0;
  /**
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸曘劌浜鹃柛鈩冾殕閸?P0-2闂佹寧绋戦¨鈧紒鍙樺嵆瀵偊骞橀琛″亾婢舵劕绀傞柟鎯板Г閿涙棃鏌?*闂佺粯鐟崜娑㈡偟濞戞瑧顩烽柨婵嗘－閸?* + 闂佸憡顨嗛悺鏇灻归崶鈹惧亾鐟欏嫮顣叉俊鐐插€垮畷鎶藉Ω閵夈儳绋忛梺鍝勮嫰鐎氥劑鍩€?
   *
   * 闂佸憡顭囬崰鎰焽閻㈢鐭楁い蹇撶墛濞?`isClosing` 闂佸綊娼荤换婵嬪闯閹间礁绀傞柕澶樺灣缁€澶愭煠閺夎儻瀚伴柣锝囧█瀹?`morphCloseMs + 20`闂佹寧绋戦悧鍐╂櫠?70ms闂佹寧绋戦ˇ顖氼潩閵娧勫仏妞ゆ劧绲块鎼佹煕?`false`闂?
   * 闂備緡鍙忕徊鑲╃博閹绢喖绀嗙紓浣股戠亸锟犳煛閳ь剚銈ｉ崘锔瑰亾?*闂佸憡鐟崹鐢稿礂濡粯浜ゆ俊顖濆吹濮?unmount** 闂?缂備焦顨忛崗娑氳姳閳轰讲鏋庨柨娑樺娴狀垶鏌涢幋鐐搭潡闁稿繑锕㈠畷妯侯吋閸喎闂繛鎴炴尨閸嬫捇鏌?350ms 闁荤偞绋忛崕闈浳?+ 缂備焦顨忛崗娑氳姳閳哄倻鈻旀い蹇撳缁佸寮堕悙鑸殿棄闁伙綁绠栧顔炬崉閻戞褰滈梺?
   * 闂?`morphGenAlive` 闂佸搫绋勭换婵嬫偘濞嗘挸绠柨鏃囨硶閻熸繂霉閿濆懘鐛滅紒杈ㄧ懄缁嬪濡堕崱妯挎嫬闂備焦鍎虫晶钘夆枔?`morphGen` 闂佺儵鏅濋…鍫ュ箖閹剧粯鏅璺虹墐閸?
   * 闂佺粯绮嶅妯猴耿椤忓牊鏅慨姗嗗墮缂嶆牠鏌＄仦钘夘仼闁宦板妽缁嬪鈧綆鍋呴梽宥夋煕濞嗘ê鐏ユい顐畵瀹曪綁寮介妸顬?+ 婵炲濯寸徊楣冾敃閸忚偐鈻旈柕澶涘婢规劙鏌″蹇曠瘈闁?闂?"缂備焦顨忛崗娑氳姳閳轰讲鏋庨柨娑樺娴狀垶鏌?闁荤喐娲戝鎺旂不閻愬灚鍋栨い鎰剁稻椤牜鐥褍鏋涢柟椋庡厴閹箖濡烽敐鍌氫壕濞达絿鐡斿ú锝呪槈閺傝法澧曢柛蹇涗憾瀹曟瑩鍩€椤掑嫬绠抽柕澹苯鎮侀梺?
   */
  private closeGen: number = 0;
  private closeSettleTimer: number = -1;
  // 2500ms is a failure deadline, well beyond snapshot 350ms / live <=460ms
  // plus render/snapshot dispatch. Only normal completion decides animation completion.
  private static readonly CLOSE_WATCHDOG_MS: number = 2500;
  private static closeSerial: number = 0;
  private static closeOwner: number = 0;
  private static instanceSerial: number = 0;
  private static ownerInstance: number = 0;
  private static cancelCloseOwner: (() => void) | undefined = undefined;
  private closeInstance: number = 0;
  private closeToken: number = 0;
  private closeWatchdogTimer: number = -1;
  private closePath: string = 'live';

  public static cancelPendingCloseForOpen(): void {
    const cancel: (() => void) | undefined = PlaybackPage.cancelCloseOwner;
    PlaybackPage.closeOwner = 0;
    PlaybackPage.ownerInstance = 0;
    PlaybackPage.cancelCloseOwner = undefined;
    if (cancel !== undefined) {
      cancel();
    }
  }

  private closeDiagnostic(event: string, path: string = this.closePath): void {
    MusicStoreService.getInstance().appendRuntimeDiagnostic(
      `RzdCloseChain path=${path} instance=${this.closeInstance} close=${this.closeToken} ${event}`);
  }

  private ownsClose(token: number, event: string): boolean {
    const owns: boolean = token !== 0 && token === this.closeToken &&
      token === PlaybackPage.closeOwner && this.closeInstance === PlaybackPage.ownerInstance;
    if (!owns) {
      this.closeDiagnostic(`stale-callback-dropped event=${event} token=${token}`);
    }
    return owns;
  }

  private beginCloseGuard(path: string): number {
    this.clearCloseGuard();
    this.closePath = path;
    this.closeToken = ++PlaybackPage.closeSerial;
    PlaybackPage.closeOwner = this.closeToken;
    PlaybackPage.ownerInstance = this.closeInstance;
    const token: number = this.closeToken;
    PlaybackPage.cancelCloseOwner = (): void => {
      this.closeDiagnostic('stale-callback-dropped event=new-open');
      this.clearCloseGuard();
      this.stopGeoDriver();
      const pixmap: image.PixelMap | undefined = this.morphShrinkState().pixmap;
      this.morphShrinkState().reset();
      this.releasePixelMapQuiet(pixmap);
      this.expandState.endSnapshotShrink();
      this.snapshotFlight = false;
      this.isClosing = false;
      ++this.closeGen;
    };
    this.closeWatchdogTimer = setTimeout((): void => {
      if (!this.ownsClose(token, 'watchdog')) {
        return;
      }
      this.closeDiagnostic(`watchdog-fire source=${this.closePath}`, 'fallback');
      this.finishCloseGuard(token, true);
    }, PlaybackPage.CLOSE_WATCHDOG_MS);
    return token;
  }

  private clearCloseGuard(): void {
    if (this.closeWatchdogTimer !== -1) {
      clearTimeout(this.closeWatchdogTimer);
      this.closeWatchdogTimer = -1;
    }
    if (this.closeSettleTimer !== -1) {
      clearTimeout(this.closeSettleTimer);
      this.closeSettleTimer = -1;
    }
  }

  private finishCloseGuard(token: number, fallback: boolean = false): void {
    if (!this.ownsClose(token, 'finish')) {
      return;
    }
    const path: string = fallback ? 'fallback' : this.closePath;
    // Hide intent -> synchronously remove only player route -> reset -> release ownership.
    this.state.isShowPlay = false;
    const names: string[] = this.pageIndexInfos.getAllPathName();
    const index: number = names.indexOf(RouterUrlConstants.PLAYER_PAGE);
    const top: number = names.length - 1;
    // ★★ 2026-10-20（「退出后满屏封面 + 整屏点不动」的诊断结论）：
    //   原来**一律** `removeByIndexes([index])`，而且**丢弃返回值**、诊断无条件打印成功。
    //   两次真机事故的播放页都在**栈顶**（index===top，分别 0 / 1）。栈顶只 remove 不 pop 时，
    //   栈账腾了但 NavDestination 节点未必卸掉；紧接着 `morphReset()` 又把几何复位成满屏
    //   （morphP=1 / clipHeight→整窗）⇒ 满屏封面留在最上层并独占整屏触控；
    //   而壳层安全网 `popPlayerRoute()` 因为栈里查不到 player 下标而空跑
    //   —— 这正是日志里**缺** `RzdCloseChain route-remove source=Index` 的指纹。
    //   ⇒ 栈顶必须 `pop(false)`；非栈顶才 remove，校验返回值，为 0 时兜底 pop。
    let removed: number = -1;
    let removeMode: string = 'none';
    try {
      if (index >= 0) {
        if (index === top) {
          removeMode = 'pop';
          this.pageIndexInfos.pop(false);
        } else {
          removeMode = 'remove';
          removed = this.pageIndexInfos.removeByIndexes([index]);
          if (removed === 0) {
            removeMode = 'remove-then-pop';
            this.pageIndexInfos.pop(false);
          }
        }
      }
      this.closeDiagnostic(
        `route-remove ${removeMode} index=${index} top=${top} size=${names.length} removed=${removed}`, path);
    } catch (error) {
      this.closeDiagnostic(`route-remove-failed error=${error} index=${index} top=${top}`, path);
      try {
        this.pageIndexInfos.pop(false);
        this.closeDiagnostic('route-remove-fallback-pop', path);
      } catch (inner) {
        this.closeDiagnostic(`route-remove-fallback-failed error=${inner}`, path);
      }
    }
    try {
      this.stopGeoDriver();
      this.expandState.morphReset();
      this.closeDiagnostic('reset', path);
    } catch (error) {
      this.closeDiagnostic(`reset-failed error=${error}`, path);
    } finally {
      this.isClosing = false;
    }
    this.snapshotFlight = false;
    const pixmap: image.PixelMap | undefined = this.morphShrinkState().pixmap;
    this.morphShrinkState().reset();
    if (fallback) {
      this.releasePixelMapQuiet(pixmap);
    }
    this.expandState.endSnapshotShrink();
    this.clearCloseGuard();
    ++this.closeGen;
    PlaybackPage.closeOwner = 0;
    PlaybackPage.ownerInstance = 0;
    PlaybackPage.cancelCloseOwner = undefined;
    // ★ 64ms 存活自检：路由没真的卸掉时（节点残留 = 满屏封面 + 吃触摸），再弹一次。
    setTimeout((): void => {
      try {
        const left: string[] = this.pageIndexInfos.getAllPathName();
        const still: number = left.indexOf(RouterUrlConstants.PLAYER_PAGE);
        MusicStoreService.getInstance().appendRuntimeDiagnostic(
          `RzdCloseState +64 alive=${this.isAlive ? 1 : 0} show=${this.state.isShowPlay ? 1 : 0} ` +
            `size=${left.length} idx=${still} names=${left.join(',')}`);
        if (still >= 0) {
          if (still === left.length - 1) {
            this.pageIndexInfos.pop(false);
          } else {
            this.pageIndexInfos.removeByIndexes([still]);
          }
          MusicStoreService.getInstance().appendRuntimeDiagnostic(
            `RzdCloseState +64 re-pop idx=${still} top=${left.length - 1}`);
        }
      } catch (error) {
        MusicStoreService.getInstance().appendRuntimeDiagnostic(`RzdCloseState +64 failed error=${error}`);
      }
    }, 64);
  }
  /**
   * 闂佸搫鐗滈崜姘额敃閸忚偐鈻旈悗锝庡亜椤庢瑩鎮归搹鐟版瀾濠⒀勭矒瀵即顢涘顓炲墾閻庤鐡曠亸娆戝垝閿熺姴绠┑鐘插€介崺宀勬煕濞嗘劦鐒芥繛鏉戭槹閹峰懎顓奸崨顓犫偓濂告煕?LEAVING闂佹寧绋戦悧鍡涱敋椤曗偓瀵粙宕堕妸锔奸獜闂佷紮绲介惉鐓庘枔?`drive = FINGER`闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸搫鐗嗛ˇ顔捐姳閿涘嫧鍋撻悷鏉挎灕缂佽鲸绻堝鍫曟倷椤掆偓椤や線鏌￠崘顓炵厫濠⒀呭█閹虫鎸婃径濠勨偓缁樼箾?闁哄鏅滈悷锕傤敃閸忚偐鈻旈悗锝庡亜椤庢瑩鏌ｉ鍡楁灁婵炲牊鍨归幑鍕偄缁嬫鏉归柡?闂?闂佸憡鐟禍婵單ｉ幖浣稿嚑濞达綀娅ｉ崣姘舵煟閵娿儱顏х紒鏃€娼欓埢搴ㄥ焺閸愩劎褰岄梺?闂?
   * 闂佸憡鑹惧锕傚焵椤掆偓閹冲秶绮径鎰殑闁芥ê顦粻鐢告煕閺傝濡奸柤闀愬嵆瀹曪絽螣閸忚偐銈叉繛杈剧到缁嬪嫮妲愬┑瀣Е闁挎洍鍋撻柛顭戝灡鐎电厧顫濋鐐嶁晠姊婚崼鐔烘噭妞ゆ帗鐩幆?OPEN 闂佽鍏涢悞锕傚极婵傜绠?LEAVING闂?
   */
  private dismissMorphActive: boolean = false;
  /**
   * 闂佸搫鐗滈崜姘额敃閸忚偐鈻旈悗锝庡亜椤庢瑩鏌￠埀顒勫箚閻楀牆闂?*闁荤姍鍥ㄦ暠濠⒀勭矒閺屽洭鏁愰崟顓т紘闂?*闂佹眹鍔岀€氼剟鎳滄导鏉戠煑婵☆垵娉曠粻濠氬箹鏉堟崘顓虹紒杈ㄧ崑morphP`闂?..1闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佺绻戞繛濠偽涢幘顔肩闁归偊浜濋崬澶愭煟?*闂佺儵鏅濋…鍫ヮ敋椤曗偓閺?*闂佸憡甯囬崐鏍х暤娓氣偓閹啴宕熼銈呮暏闂佸憡鍨靛Λ搴ㄥ焵?
   *
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`reverseQuitDelta`闂佹寧绋戦¨鈧紒鍙樺嵆瀵噣鎮╅崹顐ｇ彧闂佹眹鍔岀€氼剟宕ｈ濮婂顢橀悢椋庡€掓繛瀛樺殠閸婃挾绮径鎰強?缂傚倸鍊甸弲娑㈠春鐏炴儳绶炴慨姗嗗墰濮ｅ矂鎮樿箛鎾宠埞闁?闂?
   *   闂佸吋婢橀張顒€危?**濠殿噯绲惧Λ渚€骞戦敐澶嬪€烽柣鐔稿缁愭棃鏌涢妷褍浠╅柧鏂款儐缁傚秹宕卞Δ濠冣柤闁?*"闂佹寧绋掗悺鐚焑lta >= max(baseT/2, COMMIT_T)`闂?
   *   闁荤姍鍥ㄦ暠濠⒀勭矒瀵喚鎹勯悜妯垮惈 `morphBeginLeaving()` 婵炴垶鏌ㄩ鍛櫠閻樺灚濯奸柡澶庢硶缁夊潡鏌￠崼顐㈠闁逞屽墰閵嗗妲愰柆宥呯骇闁绘劦鍓欓·渚€鏌￠崘銊ヮ暢闁?`delta = baseT 闂?閻熸粎澧楅幐鍛婃櫠閻樿櫕浜ゆ繛鎴灻濂伴梺?
   *   闂佸疇娉曟刊瀵哥箔?闂佸憡甯楃换鍌炲焵椤掑倸甯剁憸?**1**闂佹寧绋戦悧濠傤嚕瑜忔禒锕傚即閻愮數锛涢梺鎸庣☉椤︻偊鍩€椤掍焦鐓涢柍?婵?婵炲濮撮柊锝咁焽閵堝拋娼伴柕蹇嬪灪閻ｉ亶鏌熺紒銏犲箺闁哄倷鐒﹂妵鍕濞戞氨锛涙繝娈垮枛椤戝嫮绮崨鏉戠?闁哄鏅滈悷銈囩博鐎靛憡鏆滈柛娑樑堥崑鎾存媴妞嬪寒浼囬梺鑲╂焿閹活亞妲?
   *      闂佹椿浜為崰鎰邦敆濠婂懏灏庨梺鍨儏椤や線鏌￠崘鈺傛瀯缂佽鲸澹嗛幃顕€顢曢妶鍥х秳闂佸憡甯楀Σ鎺椼€呴锔藉剮闁哄秶鏁哥粈鍕偡?`onDismissDrag` 闂備焦褰冮惌渚€顢欓崶顏備汗闁哄洨鍋熼弳濠囨煟閵娿儱顏柛瀣噺缁嬪鍩€椤掑倹鍋樼€光偓鐎ｎ剛顦梺?
   */
  private dismissBaseT: number = 1;
  /**
   * 婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹曟娊鏌熼棃娑卞剰濠电偛绉归幆?*闁荤姍鍥ㄦ暠濠⒀勭矋閹峰懎顓奸崶鍡忔櫊濮婂濡搁埡鍌も偓?*闂佹寧绋戝濡忛梺鎸庣☉椤︻參鍩€?
   *
   * 闂?闁诲簼绲婚～澶愭偉閿濆绫嶉柣妯虹仛濞?`PlayerPage` 婵＄偑鍊曢悥濂稿磿閹绢喖绀傞柟鎯板Г閿涙棃鏌熼棃娑卞剰濠电偛绉归幆?
   *   `PanGesture({ direction: PanDirection.Down, distance: 8 })`
   *   闂佹寧绋戝濉ecover\logic-src\閻庢鍠掗崑鎾绘煕韫囨碍鐝柟鎼佷憾瀵劑骞嗚閻?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄦ皑缁愮偤鎮楃憴鍕殤妞?md` 闁? 闂備緡鍋嗛崰鎰版偂閿涘嫭鍋?/ 闁?.1 闂?/ 闁?.3闂?
   *   闁诲孩绋掗〃澶嬩繆椤撱垺鍎?`wujie.pa:181153-181157`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?**闁诲繐绻楁ご绋课ｉ幖浣哥睄闁绘ê鐏氬▍鏇㈡煟閵娿儱顏柛瀣噺缁?8闂佹寧绋戞總鏃傜箔婢舵劕鍙婃い鏍ㄧ☉閻忓霉閻欌偓閸忔盯宕ｆ繝鍥ㄥ剭?*闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲灪閺?*濠碘剝顨呭Λ娆撴倶閿斿墽妫?*闂傚倸鍊堕崝鎴濐瀶濞差亜违濞达綀袙閸嬫挾浠﹂懖鈺冩喒闂?{@link onDismissDrag} 闂備焦褰冮張顒佹櫠濠婂牆绀?`if (offsetY < N) return;`闂?
   *   `PanGestureOptions.distance`闂佹寧绋戦悧濠傦耿娴兼潙瀚?`gesture.d.ts:2380` 缂佺虎鍙庨崰妤€锕㈡担鐑樺珰闁靛鍎抽幗鐔哥箾閸埄鏆滅紒?*婵帗绋掗…鍫ヮ敇?5vp**闂?
   *   闂?闂佸綊娼ч鍡欌偓鍨皑閹秆囨偋閸繂袣婵犮垼鍩栭懝楣冩儍椤栫偛绠?*闁荤姴娲ゅΛ妤呭春?*闁哄鏅滈悷銈夋煂濠婂牆绠ラ悗锝庝簻閳?闂佺偨鍎查弻锟犲焵?濠电偛鐪查妶鍫熷发濠电姴艌閸撴繂顪?`onActionStart/Update/End`
   *   闂佸搫绉烽～澶婏耿閻楀牏鈻旂€广儱瀚粣妤呮偡濞嗘瑧鐣辩憸?闂?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝囩摂濞?1~2vp 闂佺鍩栭悧鏇熸叏閳哄懎绠抽柕濞垮妿缁?`LEAVING`闂佹寧绋戝澶嬬箾閺屻儳鐣洪柣鎾崇埣瀹曟繈濡歌閺嗙檱ug濠电偞鎸搁幊搴＄暦?md` P0-4闂?*闂侀潻璐熼崝宥囪姳椤旇棄绶炵紓鍫㈠Х閻熸繈鏌熺€涙ê濮夐柣?*闂?
   *   闂佸吋婢橀張顒佹櫠濠婂牆绀冩繛鍡楃箰閻忔煡鏌熺拠鈥虫灆缂佽京澧楀鍕潩椤愩値浼囧┑鐐叉閳ь剝灏欓悷婵嬪级閳哄啫浠ч柣銏狀煼閺佸秹宕奸敐鍥垛偓鈧梺褰掓涧椤戝牏鎹㈠Ο缁樺劅闁挎洍鍋撴繝鈧鍫熲拻闁靛ň鏅滈娆撴⒑椤撱劎瀵肩紒鏂款嚟閺侇喛顦辩紒?0 闂佺儵鏅涢悺銊ф暜鐎靛憡宕夐柛鎰絻閻?`N/span`闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇娉曟刊瀵哥箔?**闂佺懓鐏氶幐鍝ユ閹达箑妫橀柣鐔哄閸婅鈽夐幘宕囆㈠┑?*闂佹寧绋掗惌顔炬偖闁秴绾ч梽鍥╁寲閻樿櫕濯撮柣妯挎珪閽傚鏌?`panOption` 婵烇絽娲︾换鍐偓鍨⒐椤偓婵☆垱顑欓崥?5vp 闂佺偨鍎查弻锟犲焵?
   *   闂備緡鍙忕徊楣冾敆濠婂嫮闄勯柣锝呯灱閹肩厧霉濠婂啫顒㈡俊顐犲€濋幃鍓т沪閼测晝鎲┑鐘诧攻閸ㄨ埖鏅堕敃鈧锝夊焵椤掑嫬绠ラ悗锝庝簻閳笺垽鏌?`{ direction: PanDirection.Vertical, distance: 5 }`
   *   闂佹寧绋戦悧鍡涘箖閹捐妫橀柛銉ｅ妸閳?闁?.1 闂佸啿澧庢刊瀵告濮樿埖鏅悘鐐村劤椤ｆ彃霉閻橆喖鍔﹂柛瀣嚇閺屽瞼浠﹂悙顒婄礂婵炴垶鎸哥粔瀛樻叏閻愬鈻曢柣鏂垮閻熸繈鏌￠埀顒勭嵁鎼存挸浜?
   */
  private static readonly DISMISS_PAN_DISTANCE_VP: number = 8;
  // 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹曟娊鏌ｉ妸銉ヮ仹閻炴俺椴哥粙?*闂佸憡甯囬崐鏍х暤娴ｇ儤鏆滈柟闂寸濞?*闂佹寧绋戦悧濠呫亹娴ｅ湱顩查柕鍫濐槹椤矂鏌?38 / 闂佺绻戠划宀€鑺卞畷鍥ㄥ仒鐎光偓閳ь剟鍩㈤悡骞帡寮崜褌绱?0.42闂?*閻庡湱顭堝鍫曞极瑜版帒鏋佹繛鎴灻悡?*
  //    `PlayerExpandState.DISMISS_COMMIT_PROGRESS` / `PlayerExpandState.DISMISS_DRAG_SPAN_RATIO`
  //    闂佺偨鍎查弻锟犲焵?闂佸憡顭囬崰搴ㄥ储濞戞埃鍋撻悷鏉挎殨婵犲﹥鍨剁粙澶嬫償閵忕姭鍙洪悗娈垮枓閸嬫捇鏌￠崒婊勫殌闁诡喗绮撻幆?`PULL_OPEN_COMMIT_FRACTION` 闂佸憡甯掑Λ妤呮儑閾忣偆鈻旈柕鍫濆閸ゅ鏌￠崒姘煑婵炲棎鍨芥俊瀛樻媴鐟欏嫸楠忔繛瀛樺殠閸婃洖顕ｉ崼鏇炲唨闁跨喓濮峰畷?
  //    闂佹寧绋戝澶嬬箾閺屻儳鐣洪柣鎾崇埣瀹曟繈濡歌閺嗙檱ug濠电偞鎸搁幊搴＄暦?md` P0-1闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婂骞冩繝鍥ㄥ仺闁告瑦顭囬悷?婵炴垶鎸哥粔鐑筋敊韫囨稒鍋傜憸搴繆闁秴绫嶉柣妯虹仛濞?0.32"闂佹眹鍔岀€氼垶顢氶埡鍛強閹兼番鍔岄崢鎾煕閿斿搫濮傞柛瀣嚇閺屽苯鐣濋埀顒€鈻撻幋婵冩灃闁靛ň鏅涘▍鐐烘⒑閹绘帟顫﹂柍?
  /**
   * 婵炴垶鎸搁鍡樺垔濞差亜绾ч柣鎰靛墮椤や線鏌￠崘銊ヮ暢婵?*闂備緡鍋嗛崰搴ｂ偓?*闂佸湱绮崝鎺戭潩閿曞倹鈷撻柛顐ｇ妇閸嬫挾娑垫搴ｎ槱vp/s闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸憡鍨甸幖顐λ囬埡鍛櫖婵繃鐡皁cs\闂佸搫鍟版慨鐑藉疾椤愩儯浜归柕蹇曞Т缂嶄線鏌熼棃娑卞剱闁?闂佽В鍋撻柦妯侯槺閺変粙鏌涢幒鏃€鐝攝dMusic濠电偞鎸搁幊搴＄暦?md` 闁圭厧鍊圭粙澶愬焵?1.2闂侀潧妫楅張顒冦亹娴ｅ湱顩查柕鍫濇噹閻忔煡鎮?闂佺偨鍎查弻锟犲焵?闁哄鏅滅粙鎴犫偓?OR 闂備緡鍋嗛崰搴ｂ偓瑙勫▕婵℃潙顓艰箛鏇犵崶
   * `commit = (morphT >= COMMIT_T 闂?0.32) || (velocity <= COMMIT_VELOCITY 闂?900)`
   * 闂?闂佸搫鍟版慨鐑藉疾椤愶附鍎?`COMMIT_VELOCITY = 900`闂?*闁哄鏅滈悷銈夋煂濠婂牆鏋侀柣妤€鐗婄瑧婵炲濮寸€涒晠寮搁崘顭戞禆闁挎繂鎳庣徊鍧楁煟閵娿儱顏电紒杈ㄧ箖缁嬪顓奸崱妯烇箑霉閸忕厧顥嬫繛鍫熷灴婵?*
   *
   * 闂佸疇娉曟刊瀵哥箔?婵?*缂傚倷鐒︾换鈧紒妤€顦甸幃陇顦冲┑陇浜埀顒傛嚀閸熸澘鈻撻幋婢帡寮崶鈺冪崺闂佸搫鍊婚幊鎾诲箖?濠殿喗绻愮紞鈧紒鈧€ｎ喖鐭?*闂佹寧绋掔喊宥呂涢妶澶嬪仼閻忕偟鍋撶瑧"婵炴垶鎸搁敃銉﹀垔濞差亜绠ラ柟鎯х－绾?闂佹寧绋戦惌浣烘崲閺嶎厽鐓傞悘鐐靛亾绗?婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹?闂佹寧绋戦張顒勫蓟閻旂厧瑙﹂柟瀵稿У缁佹煡鏌涘▎蹇曗枌缂?
   *   闂佸搫鍊稿ú锕傚Υ閸屾稓鈻曢柣鏂挎啞椤牠鎮?缂備焦顨愮粻鎴ｃ亹鐠恒劍鍟哄ù锝囶焾鐢儵鎮楅崷顓炰沪缂佷焦鎸虫俊瀛樻媴缁嬭法鍔堕梺缁樻寙閸曨倠?闂侀潧妫楅崐浠嬶綖?{@link onDismissDrag}闂?
   *   **闂佸搫鍊婚幊鎾诲箖濠婂牊鍋ㄩ柛娆愵焽缁夊绱掓径搴殭闁搞劋绮欐俊瀛樻媴閹肩偘娴烽柣蹇撶箰缁绘帡寮?`Math.abs(velocityY)` 闂?* 闂?闂佸搫绉归埀顒佺〒閻熸劕鈽夐幘宕囆ф繛鎾冲閹茬増鎷呴梹鎰崳闁荤姳绀佹晶浠嬵敄娓氣偓瀹曪綁寮搁鐔蜂壕?
   */
  private static readonly DISMISS_COMMIT_VELOCITY: number = 900;
  /**
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸曘劌浜鹃柛鈩冾殕閸?P0-4闂佹寧绋戦¨鈧紒杈╁缁嬪鈧綆鍋勯娆撴煛閳ь剟骞嗛悧鍫濋棷闂?*闂佸搫鐗冮崑鎾绘倶韫囨挾绠洪柟鐧哥秮楠炲秶鈧絺鏅濈粔瀵哥磼?*闂佹寧绋戝濡忛梺鎸庣☉椤︻參鍩€?
   *
   * 濠电偛澶囬崜婵嗭耿娴ｈ　鍋撻悷鏉挎殶婵炲牊鍨垮顔炬崉鐞涒€充壕婵炲棙鐟х粈澶愭偣閾忕懓鏋戝褎绮撳畷姘跺幢濡粯娈伴梺鍛婄懐娴滐綁銆?`offsetY > 0`闂?*1vp 闂備緡鍠氶弲顐︽偩?*闂佹寧绋戦ˇ顖氼潩閵婏箑顕?`morphBeginLeaving()`
   * 闂?闂佺儵鏅犻弲鑼礊閸涱垱鍋栨い鎰剁到閼靛綊寮?`LEAVING` 婵?`morphGen++`闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎯堥崱妯尖枖濠电姴鍊稿▓銈呪槈閺傝法鍑圭紒顔肩墛缁嬪﹪宕奸妷銉ュ箣濠电偛澶囬埀顒€鍟胯闂?
   * 闂佸搫顦遍崑鎾存櫠濠婂牆鐐婇柣鎰煐閸庝即鏌￠崘顓熺【鐎殿喚鏁哥槐鎺戔枎閹寸偟銈叉繛杈剧到缁夊瓨绂掑☉娆戔枖闁逞屽墮閳?220ms 闁荤偞绋忛崕闈浳?+ 240ms 闁诲氦顫夌喊宥咁渻閸岀偛闂?
   * 闂?闁荤喐鐟ラ崐褰掑礉閸涙潙鍙?闁哄鍋炲Σ鎺撶閵堝鍙撴い鎾寸箘椤忓崬鈽夐幘鎰佸剰婵ǜ鍔戝濠氼敂閸愵亶浼囨繛?闂佹寧绋戦懟顖炲箖閹捐绫嶉柤鎼佹涧鎯?P0-3 闂備緡鍙忕徊鎯ь焽椤栨埃鏋旈悗锝庡墯濞堝矂鏌ｅΟ鍨厫闁逞屽厸閼宠泛鈻撻幋锔解拻闁靛绠戦埅鐢碘偓娈垮枓閸嬫捇鏌?
   * 8vp 闂?2.5mm闂?*闁哄鏅滅划宀勬儍椤掍胶顩?*闁荤姴娴傞崹浣冾杺闁诲繐绻愰幖顐も偓瑙勫▕閺佸秹宕煎顑芥嫼10vp闂佹寧绋戦ˇ顔剧箔瀹€鍕剳闁绘棃顥撻弶钘夆槈閹炬剚鍎愬┑顖濇閹秆囨煥鐎ｎ亶鏉归梺鎸庣☉閻楀棝宕甸幋锕€纭€?vp闂?
   * 闂?**闂佸憡鐟禍婵堜焊閸涙潙绠柡宓唭妤呮煏閸℃洘顦风紒妤€顦甸獮鎰版缂佹劧绻濋獮?*闂佹寧绋戦悧鍛箔閸涱喚鈻旈柍褜鍓氱粙?`onActionUpdate` 婵炴垶鎸撮崑鎾绘煛閸愯法鐣崇紒澶屽劋濞煎宕惰閺嗗﹪鏌ｉ幘妤€鍟伴崺妤呮偣瑜旈弨杈ㄦ櫠濠婂牊鏅璺虹墐閸?
   * 闂佸疇娉曟刊瀵哥箔?闂佸搫鍟版慨鐑藉疾椤愶絿鐟?*濠电偛澶囬崜婵嗭耿?*闁哄鏅滈悷銈夋煂濠婂牊鈷掗柕濞炬櫆椤?闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕€危缁嬫５鐑樸偅閸愵亜寰撻梺鐓庮殠娴滄粎鎹㈡笟鈧幆鍐礋椤愩埄娼遍梺鎼炲劤鐏忋劎妲?*闂佽桨绀侀幊蹇涘礈閻楀牏鈻旂€广儱瀚悷銏ゆ倵閻熸澘鏆欐い鏇ㄥ枟椤?*闂?
   */
  private static readonly DISMISS_MIN_START_VP: number = 8;

  /** @returns 缂備焦鍔栭〃鍛般亹濞戞瑯娈楁俊顖氭惈椤斿﹪鏌ㄥ☉妯荤筏p闂佹寧绋戦¨鈧紒閬嶄憾楠炲繑寰勯崫銉ф喒闂佸憡甯炴晶妤€顪冮崒婊呯＜婵炲棗娴烽鍗炩槈閹垮啩绨婚柛妯款潐閹棃寮撮悙鈺佷壕缁绢參顥撶粈澶娗庨崶銊х畾闁伙箑顦甸獮蹇涘冀閵娿儺浼″┑顕嗙稻閺屟呮閵夛妇鈻旂€广儱瀚粣妤呮⒒閸曗晛鈧繂霉閸岀偛违?*/
  private deviceHeightVp(): number {
    const px: number = this.windowInfo.windowSize.height;
    if (px <= 0) {
      return 780;
    }
    return this.getUIContext().px2vp(px);
  }

  /**
   * @returns 婵炴垶鎸搁鍡樺垔濞差亜绀嗛柡澶庢硶娣囨椽鏌熺喊妯轰壕闂傚倸娲犻崑鎾绘煟閵娿儱顏紒鎰〒缁瀵煎▎鎴狀槱vp闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闁荤姾娅ｉ崰鎰櫠濠婂棎浜归柟鍝勭Ф椤忛亶鏌涢弽銊у⒈婵?*闂佸憡甯掑Λ娆撴儊?*闂?
   *
   * 闂?D2闂?*婵炴潙鍚嬮敋闁告ɑ鐩幃浠嬪Ω閵壯勬緰濠?*闂佹寧绋戦張顒傗偓锝勭劍缁嬪顓奸崨顓犲帓闂佸綊娼х粔褰掑焵椤戣棄浜鹃梺鎼炲劤閸嬬喖鎮伴妷鈺佺煑闁挎繂妫涘Σ宄般€掑顒夊剭闁逞屽墮閸婃悂顢氶绛嬬€查柟閭﹀幗閿熴儵鏌?
   *   `pullRangePx = coverRect.top > 0 ? coverRect.top : windowHeight * 0.32`
   *   闂佹寧绋戝濉猳cs\闂佸搫鍟版慨鐑藉疾椤愩儯浜归柕蹇曞Т缂嶄線鏌熼棃娑卞剱闁?闂佽В鍋撻柦妯侯槺閺変粙鏌涢幒鏃€鐝攝dMusic濠电偞鎸搁幊搴＄暦?md` 闁圭厧鍊圭粙澶愬焵?1.1闂佹寧绋戦ˇ顓㈠焵?
   *
   * **婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箘閺夎姤绻涢弶鎴剰闁逞屽墰閸樠嗐亹?`expandState.miniY`**闂佹寧绋掓穱铏圭玻閿熺姴绠ラ悗锝庡幘缁犲骞栨潏楣冩婵″弶鎮傛俊瀵镐沪閹屾澒闂佸湱顭堝ú锝囩礊閸涱垳鐭撻柤濮愬€栭悾杈╃磼缂併垹鐏犻柛銈変憾瀵偊鎳滈钘変壕?
   *   闂佹寧绋戝濉竢ogress = offsetY / span`闂佹寧绋戦¨鈧紒杈ㄧ箞瀹曟岸宕卞Ο鍏夹撻梺姹囧妼鐎氼垶顢氶姀锛勨枙濠㈣泛锕ラ惃鎴︽煛?闂佸綊娼ч鍡欌偓鍨皑閹秆囧级鐠恒劍娈梺杞拌兌缁绘繈鏌屽鍫濈哗闁诡垳澧楀畷鎶芥煕閺傝濡虹紓宥嗘⒒閹茬増鎷呴崐鐔稿发婵犮垼鍩栨穱铏规崲?闂?
   *   闂佽　鍋撻柟顖滃瀹曟娊鏌ｉ妸銉ヮ伀婵炶弓鍗冲浠嬪炊閵娤€锕傚级閳哄嫭鑵圭紓宥嗭耿瀵爼鍨惧畷鍥唸闂傚倸鐗勯崹浠嬪磻閸涱喚鈻旈柍褜鍓涙禍姝岀疀閹炬潙浠撮梺鎸庣☉閻線鍩€椤掆偓閼活垶鎮鹃悩缁樺剭闁告洦鍨埀顒€锕ュ蹇涙偡閻楀牏娈ら梺闈╄礋閸斿酣鎮伴妷鈺佺煑闁挎繂鎳忕紞蹇涙煛?`miniY` 闂佺偨鍎查弻锟犲焵?閻熸粏鍩囬崹纭呫亹婢跺备鍋撻崷顓熷殌婵炲懏甯″畷?`p = 0`
   *   闂佸搫鍟晶搴♀枔閹达箑鐭楁い鏍ㄧ箥濞兼帡鏌ｉ娑欐珔闁煎摜澧楅妵鍕箚閹殿喚褰惧┑顔界箰缁叉儳危?`miniCoverY`闂? `miniY`闂佹寧绋戦惉濂稿极?`morphInitParams()` 婵炲濮存鎼佸箖閹惧鈻旈柍褜鍓氱粋鎺楁寠婢跺本婢栧┑鐐存綑椤戝懘鍩€椤掑啫浜归柣锝咁煼瀹曟瑩鎮€靛摜顦梺?
   *   濠电姴艌閳ь剙纾宀勬煙椤戣法绐旈柕鍡楋攻濞煎繒鎲撮崟顑?0 闂?闁荤姍鍕凡闁伙綆鍓熷畷妤呭Ω瑜夐弻?= 婵＄偑鍊栭崕鑲╃博閻斿摜顩?0 闂佺懓澹婃禍婊堝春?`miniY` 闂?闁荤偞绋戦惉濂稿煝?`miniY`闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?**闂佽　鍋撻柣鐔告緲閻庣粯鎱ㄩ敐鍛＄紒妤€顦扮€电厧顫濇潏鈺傜劸缂備礁顦介崹鐗堢閸濄儳鐭?*闂佹寧绋戦悡顏囶槻闁?缂?3 闂佸搫顧€缁辨洖鈻撻幋锕€绀嗛柕鍫濇缁侊箓鏌ㄥ☉姗嗘缂佽京娅梔ismissProgressFromDrag()` 婵炲濮寸粔鍫曞礉瑜斿?
   *   `clamp(offsetY / span * 100)` 闁哄鏅滈悷褔锝?**閻熸粎澧楅幐鍛婃櫠?*闂佸綊娼ч鍡欌偓鍨皑缁辨帒鈹戦崱鈺佹婵炶揪绲界粔鏈电昂"闂佹眹鍔岀€氼噣宕欐禒瀣闁兼亽鍎插▓鍫曟煥?*婵炴垶鎸哥粔鐑筋敋閻楀牏鈻斿┑鐘辫兌椤忛亶鎮?*闂?
   *   闂佸吋婢樻總鏃傜箔?`miniY` 闂侀潻璐熼崝瀣博閺夋垟鏋庨柍鈺佸暙閻濇盯鏌涢弬璇插婵犫偓閿熺姵鈷掗悗娑櫳戠瑧闁汇埄鍨遍幃鍌炲闯?闂佺偨鍎查弻锟犲焵?闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨鹃搹顐ュ惈閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮悑閿涚喖鏌?`Visibility.Hidden`
   *   闂?*婵烇絽娲︾换鍕汲閳ь剟鎮介姘殭闁?*闂侀潧妫旂欢姘焽閹殿喚鐭撴い鏍ㄧ懅閻熸繈鏌涘▎鎰跺叕缂佽鲸宀搁弫宥囦沪閼测晝鎲规繛鏉戝悑閼归箖宕埀顒勬偡濞嗘瑧鐣辩憸?`onAreaChange` 婵炴垶鎸搁敃銉︽叏?闂?闂佸憡甯掑Λ娆撴儊濠靛洨鈻旂€广儱瀚粣妤呮煕閿斿搫濡介悗姘儔瀹曟繈濡搁妶鍫濆箑闂備緡鍋呭Λ渚€鎮滈敃鍌氱煑婵☆垳纭堕崑?
   */
  private dismissSpanVp(): number {
    const measured: number = this.expandState.miniY;
    if (measured > 0) {
      return measured;
    }
    return this.deviceHeightVp() * PlayerExpandState.DISMISS_DRAG_SPAN_RATIO;
  }

  /**
   * 闂佹眹鍨兼ご鍝モ偓姘儔楠炲繘宕愰悢铏瑰春缂備礁鍊荤划顖氱暦閼碱剛涓嶆俊銈勭劍閺嗩亪鎮硅閺屽鎹㈠Ο缁樺劅闁挎棁銆€閸?
   * @param offsetY 闂佸綊娼ч鍛箾瀹ュ鍎嶉柛鏇ㄥ幘瑜般劑鏌ｉ埡鍐瘈缂傚秴鎳愮划鏃€瀵煎▎鎴狀槱vp闂佹寧绋戦懟顖炲箖濠婂嫮鈻旈悗锝傛櫈缁€瀣叏濠垫挾绉剁紒杈ㄥ哺婵?
   * @returns 闁哄鏅滅粙鎴犫偓?0..100闂?
   */
  private dismissProgressFromDrag(offsetY: number): number {
    const y: number = offsetY > 0 ? offsetY : 0;
    const span: number = this.dismissSpanVp();
    if (span <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(100, (y / span) * 100));
  }

  /**
   * 婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹曟娊鏌熼棃娑卞剰濠电偛绉归弫宥咁潩椤撶偟褰岄梺鍛婃煟閸斿秴锕㈤敓鐘斥拻?*闁荤姾娅ｉ崰鎰櫠?*闂佽　鍋撶痪顓炴噽缁犲骞栨潏鎹愵吅缂佽鲸鐟︾粙澶婎吋閸絾宸?animateTo闂佹寧绋戦張顒佹櫠瀹ュ棛顩烽柕澶涢檮绗戦梺鍛婎殙濞呮洖顪冮崒鐐村剭闁告洖澧庣粈鍡涙煥?
   * 闂佸搫顦遍崑鎾存櫠濠婂牆绫?**闁哄鏅滅粙鎴犫偓纭呮珪濞煎宕堕渚囨綋闂?OR 闂備緡鍋嗛崰搴ｂ偓鐟扮－閹奸箖宕樺顔筋€嶉棅?* 闁诲繐绻楁ご鎼佸极閸︻厽灏庨柛鎴欏€楃粈澶愭煕濮樺墽鐣遍柛顭戝灣閹即濡烽埡鍌︾吹閻庢鍠氶幊鎾趁洪弽顐熷亾閻熺増婀伴柡鍡秮楠炩偓濞达絿顣介崑?
   *
   * 闁哄鏅滈悷銉┿€冨鍕洸闁靛牆瀚棄宥夋煕濠婂啳瀚扮€殿噮鍓熼幊鎾诲礃閵娿倗鐭楃紓?MusicHome 闂?`PanGesture` 婵炴垶鎸撮崑鎾绘煠閻ゎ垱褰х紒杈ㄧ懅閳ь剛鎳撻崯鏉库枔?`dismissPanOffsetY`
   * 闂?`dismissSheetHeightPercent` + `coverLinearScale` 闂佸搫瀚烽崹浼村箖閹惧鈻旈柍褜鍓氱粋鎺楀嫉閻㈢數娈ら梺鎸庣☉椤︻參鍩€?
   *
   * 闂?D1闂佹寧绋掑畝鎼佸焵椤掑倸鏋庨悗纭呮珪閵囧嫮娑甸崪浣圭秳婵炴垶鎸搁澶婎焽?{@link PlaybackPage.DISMISS_COMMIT_VELOCITY}闂?
   * @param offsetY 閻熸粎澧楅幐鍛婃櫠閻樼數鍗氶柡宥庡亝缁绢垰霉閿濆懐肖娴滄盯鏌ㄥ☉妯荤筏p闂佹寧绋戦懟顖炲箖濠婂嫮鈻旈悗锝傛櫈缁€瀣叏濠垫挾绉剁紒杈ㄥ哺婵?
   * @param ended 闂佸搫瀚烽崹浼村箚娓氣偓瀵即顢涘☉娆戠箒闂佸綊娼ч鍐焵?
   * @param velocityY 闂佸搫顦遍崑鎾存櫠濠婂牆绫嶉柛鎾茬劍閻ｈ京绱掗弮鈧悧婊兠洪崸妤佺劵闁绘柨鍢查濠囨煥濞戞澧涙繛鑲╂暬閹?`GestureEvent.velocityY`闂佹寧绋戦ˇ顓㈠焵?
   *   闂佸疇娉曟刊瀵哥箔?**闂佸搫鐗滈崜娆撳吹闁秴鏋佸Λ棰佽兌閻熸繂銆掑顓犵畾缂佸倸妫涢埀顒傛嚀閸熸澘鈻撻幋鐘电當闁挎洍鍋撶憸?*闂佹寧绋戦悧鎰帮綖閸℃鈻旈悗锝呭缁€鍡涙煥濞戞ɑ婀板褍绉电粋鎺楀Ψ閳哄啫绗￠柣鐘遍檷閸婃洟鍩€?0 婵炴垶姊婚崰宥囩箔婢跺顕辨慨妯虹亪閸嬫捇鎮╅幓鎺撶様"闁荤姴娴傞崹杈亹娴ｅ湱顩?闂?
   */
  private onDismissDrag(offsetY: number, ended: boolean, velocityY: number = 0): void {
    if (this.isClosing) {
      // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋掓穱铏规崲閺嶃劎鈻旈柍褜鍓涢幃鎵沪闂傚闉嶉梺鍛婃尭缁夐潧危?*闂傚倸鐗婇悷鈺冨垝?* return闂佹寧绋戞總鏃傝姳椤掑嫬鍙?婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹曟娊鎮楅悷鎷屽闁告瑥绻戠粙澶婎吋閸埄鈧偓闂?闁哄鏅滈悷銈呪枎閵忥紕顩?
      //   闂侀潻璐熼崝宥呂涢埡鍕杸婵°倕鎳庡▍鈥斥槈閹绢垰浜鹃梺缁樺姇濠€鍗炍涢弮鈧鏄忋亹閹烘垵骞嬪┑鐐插閸撴繂锕㈡笟鈧弫宥夊醇閻斿鏉归梺鍦焾濞层倖鎱ㄩ埡鍌滎洸闁糕剝鍔忛崑鎾存媴閸濄儲缍勬繛鎴炴尭閿曘儵鎯€閸涙潙绀夐柕濠忕岛閸嬫挻鎷呯憴鍕剁礆闂婎偄娲﹂妵鐐靛姬閸愩劉鏌﹂柍銉ュ暱閺呮悂鏌ㄥ☉姗嗘缂佽鲸绻堝畷锝夘敂閸パ冨箣闂傚倸鐗忔慨椋庘偓鍏哥矙婵?
      //   闂佺粯绮嶅妯猴耿椤忓牆绠┑鐘插€婚弳濠囨煙閸偅灏柛銈庡弮瀵爼濡烽婊呯崶`hdc shell hilog -x | Select-String 'RzdMorph dismiss blocked'`
      //   闂佺偨鍎查弻锟犲焵?闂佸憡鍨煎▍锝夌嵁閸モ斁鍋?= `isClosing` 闂佸憡銇涢埀顒冨皺缁夎泛霉濠婂啯锛旂紒杈ㄧ懅閹?`closeFullScreenPlayback()` 闂佹眹鍔岀€氼垵妫㈠┑鐘虫礀缁绘垿寮悙鐑樼厒濠电姴绻掔粈鍡涙煥?
      //   **闁诲海鎳撻懟顖炲矗韫囨梻鈻旂€广儱鎳庡В澶愭煟?* = 闂佸綊娼ч鍛箾瀹ュ鍐€閻熸瑥瀚幏杈ㄧ箾鐏炵硶鍋撻崘鑼帓闁哄鏅滈悷杈╂濞嗘挻鐒介柨婵嗘绗戦梺褰掓涧椤戝懏绻涘鍥ㄥ磯妞ゆ牗绮嶉弳鐘绘⒒閸屻倕娅嶆い锝勭矙閺佸秶浠﹂挊澶岊唽闂?`RzdMorph dismiss pan start`闂佹寧绋戦ˇ顓㈠焵?
      Logger.warn(PlayerExpandState.LOG_TAG,
        `RzdMorph dismiss blocked: isClosing=true offsetY=${offsetY.toFixed(1)} ended=${ended}`);
      return;
    }
    const progress: number = this.dismissProgressFromDrag(offsetY);
    // 闂佸疇妫勯幊澶娢?D1闂佹寧绋戦悧濠傘€掗懜娈挎畻婵☆垰婀遍崰姗€鏌涜箛鎾跺ⅱ濡ょ姴娲弫宥嗗緞濞戞氨鐛ラ梺鍦帛閸旀帒顫濋敃鍌氱闁靛牆鎳愰弳?= **闁哄鏅滅粙鎴犫偓?OR 闂備緡鍋嗛崰搴ｂ偓?*闂佹寧绋戦悧濠偽涢妶澶嬪仼?闁圭厧鍊圭粙澶愬焵?1.2闂佹寧绋戦ˇ顓㈠焵?
    //   闂佸憡鐟禍婵嗭耿娴ｈ浜ゆ繛鎴灻濠囨煛閸愵収鍟囩紒?婵炶揪绲界粔鏈电昂婵炴垶鎸哥粔鎾春?38% 婵炶揪绲藉Λ娑㈠极閵夈儺鍤楁俊銈傚亾缂佽翰鍨肩粻?闂佽　鍋撻柡鍫㈡暩閻熸繈鎮硅閺€鍗烆焽?闂佺偨鍎查弻锟犲焵?闂佹椿娼块崝宥夊春濞戙垹绠ラ悗锝庡亜婵″啿鈽夐幘绛瑰伐婵ǜ鍔戝?闂婎偄娴傞崑鍡涘极閵夈儮鏌﹂柍銉ュ暱閸愨偓闁?闂?
    //
    //   闂佸疇娉曟刊瀵哥箔?**婵炴垶鎸哥粔鐑筋敊韫囨稒鍋?`velocityY` 闂佹眹鍔岀€氼噣顢栨笟鈧畷?*闂佹寧绋戦悧濠囧几閸愵煈娴?闁圭厧鍊垮畷?缂?3 闂?+ 闁圭厧鍊垮畷?D1 闂?闂佸疇娉曟刊瀵哥箔瀹ュ鏅鑸电〒缁?
    //     闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗙墢閻濆爼鏌?闂佸憡纰嶉崹宕囩箔閸涱喚鈻旈柣鎴烇供閸斺偓"闂佹寧绋戦惌渚€鍩€椤掆偓閺堫剟宕瑰鍕浄妞ゆ帒鍟扮粻褰掓⒑閹绘帗婀版俊?*婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹?*闂侀潧妫旈悞锕傚蓟閻旂厧瑙﹂柟瀛樼矌閻熴垽鎮楅悷鏉挎殶婵炴潙顦靛畷锝咁吋韫囨洜顦?
    //     闂佺粯鎸嗛崟顐嬧剝鎱ㄥ┑鎾剁К缂佲偓鐎ｎ喖鐭楃€瑰嫭澹嗙粻鎴︽⒑閹稿海鎳曠紒閬嶄憾閹?SDK 闂?`GestureEvent.velocityY`闂佹寧绋戝濉痚sture.d.ts`闂佹寧绋戦悺鎭爄nce 10闂?
    //     婵炴垶姊婚崰鎰版儉閸涙潙瀚夊璺侯儏椤ョ偤鎮归崶顏咁仩妞ゆ垳绶氬畷锝夋煥鐎ｎ偆鍘甸梺鍛婄閸垶鍩€椤掆偓閸婅鏅跺鍡欘浄闁靛鍔庣粻褰掓⒑閹绘帒顨欑紒顔惧█瀵粙鏌呭☉姘辨啰缂傚倷鐒﹀ú鏍閹达附鏅?
    //       閻?**闂佸搫鍊婚幊鎾诲箖?*闂佸憡鐟禍鐐哄极?*婵炶揪绲界粔鏈电昂**闂?闂佺偨鍎查弻锟犲焵?`offsetY > 0` 闂?闁哄鏅滈悷锕傤敃婵傜绠柡宓唭妤呮煛閸喓绠栭柡浣告贡閹秆囨煥鐎ｎ偆鍘甸梺?闂?
    //       閻?**婵犮垹鐖㈤崘顏呯槗**闂佸憡鐟禍婊嗐亹?`Math.abs(velocityY)`闂?
    //     闂?闂佸搫鍟版慨楣冾敊閹寸姴瀵查柤濮愬€楅崺鐘电磽娴ｅ湱鎳呮繛鍫熷灴瀵?+900 闁哄鏅滆摫婵?闂?00闂佹寧绋戦懟顖炲垂閻ｅ备鍋撶憴鍕殤缂侇喓鍔戝绋款煥閸繂骞嬫繛鎴炴尨閸嬫捇鏌″鍛缂?*濠电偛澶囬崜婵嗭耿娴ｅ湱顩烽悹浣哥－缁?缂備焦顨愮粻鎴ｃ亹鐠恒劉鍋撻崷顓炰沪缂?闂佸憡鎸哥粔鍫曟偪閸℃稑绾ч柍銉ュ级椤?*闂?
    //   闂傚倸鍟悧鍡涘焵?900 闂佸憡鐟﹂悧鐐哄吹濠婂牆妫橀柛銉ｅ妸閳ь剙鍊块弫宥夊醇閿濆孩缍?`DISMISS_COMMIT_VELOCITY` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煥濞戞ê顨欑紒妤€顦靛浼搭敍濠婂懏銇濋梺姹囧妼鐎氥劑鍩€?
    const collapsingDirection: boolean = offsetY > 0;
    const speed: number = Math.abs(velocityY);
    const fastFlick: boolean = collapsingDirection && speed >= PlaybackPage.DISMISS_COMMIT_VELOCITY;
    // 闂?閻熸粏鍩囬崹纭呫亹婢舵劖鐒介柨婵嗘媼濞堜即鏌ㄥ☉娆戠叝缂佹鎳橀獮蹇斿緞鐎ｎ偅姣嗛柣鐘欏啫妲绘慨妯稿姂瀵?*闂佸憡鐟ョ粔鎾箖濠婂懏宕夐柟瀛樼箖閸婂崬鈽夐幘顖氫壕婵犻潧鍊归〃鍛村吹閹寸偞濯?*闂佹寧绋戦悧濠偽涢妶澶嬪仼閻忕偠鍋愰惁宥夋煛閸曢潧鐏犻柟顔芥尰缁嬪鍩€椤掍胶鈻?progress 濠殿喗绻愮徊钘夘嚕閼恒儳鈻旈柕鍫濇处閺嗗繘鏌?
    //   闂佺偨鍎查弻锟犲焵?闂佽桨鐒﹂幐鎶藉Υ婢跺瞼纾介柍杞扮劍缁€鈧柡澶嗘櫈濞撳湱绱炲鈧鍫曟晸閻樿弓绨兼繛鎴炴尨閸嬫捇鎮樿箛鎾剁婵炵》绻濇俊瀛樻媴缁涘鈷栭梺鍛婃惄娴滅偤鎮伴妷鈺佺煑闁挎繂妫欓弳顏堟煕閵壯冧粶妤犵偞鎹囨俊瀛樻媴閻ｅ瞼顣ㄦ繛杈剧悼婵潧顭囬鐐茶Е閻忕偟鍋撻ˇ褎绻涢敐鍌楀亾閾忣偆顦ラ梺鍝勵槶閸庮垶鍩€?
    if (this.expandState.morphUsable) {
      if (!ended) {
        if (!this.dismissMorphActive) {
          // 闂佸疇妫勯幊澶娢?P0-4闂?*闂佸搫鐗冮崑鎾绘倶韫囨挾绠洪柟鐧哥秮楠炲秶鈧絺鏅濈粔瀵哥磼婢跺鐓兼俊顐墴濮?*闂佹寧绋戦悧鍛閻戣棄绠叉い鏃€顑欏?`DISMISS_MIN_START_VP` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煏?
          //   婵炶揪绲界花鑲╄姳椤掑倵鍋撻悷鏉挎殭婵ǜ鍔忛妵鎰板箻閸︻厾顔愬┑鐐叉閸撴繄鈧艾顑夊畷婵嬪Ω閵堝洨鎲归柣搴㈢⊕閿氭繝鈧鍫熸櫖婵﹩鍋嗛悷婵嬫煛閳ь剟宕烽鐔恒偛婵炶揪绲界粔鏌ュ焵椤戞寧顦风紒?++ 婵炲濯寸徊楣冾敃婵傜违濞达綁顥撻悷婵嬫煕閹烘垵妲婚柛銈嗗灦閹峰懘寮撮鍡欘槷闂佺儵鏅涢悺銊ф暜鐎涙ɑ浜ら柡鍌涘缁€鈧梺?
          //   婵炴垶鎸搁鍕博鐎涙鈻?`onActionUpdate` 闂佸憡鐟禍锝夈€呴敂鐐儱濠电姴鎳愮粻鏍⒒閸屾ê濮傛俊鎹愭娴滄悂宕ｅΟ鑲╃崶濠殿喗绻愮徊浠嬫偉閸撲焦灏庨梺鍨儏椤?闂?闁荤姾娅ｉ崰鎰櫠濠婂嫮鈻旂€广儱瀚粣妤呮煕濞嗘劦鐒剧紒缁樼矒閺岋箑鈹戦崟銊ヤ壕?
          //   闂佸疇娉曟刊瀵哥箔?**`fastFlick` 闂婎偄娲ら幊姗€濡磋箛娑欏殑闁伙絽鐬奸幖蹇涘级閳轰焦鍠樻俊顐墴濮?*闂佹寧绋掗惌顔剧博閺夋垟鏋?闂佸搫顑勭粈渚€骞撻埡鍌涘闁糕剝娲滅粔瀵哥磼婢跺寒鍤欑紒韬插灮娴?闂佹眹鍔岀€氼亞绮崨瀛樺仺?
          //      闂?ms 闂佸憡鍔曢幊搴ゃ亹瑜忛幐褎锛愭担鍝勬櫓闂?vp闂佹寧绋戦ˇ顖滄暜椤愶箑瀚夋い鎺戝濞村棝姊洪銈呮瀻閻庣娅曢妵鍕偡閻楀牏娈ら梺鐓庣枃婵倝寮崷顓熷皫闁告垯鍊楃粈澶愭偠濮樼厧浜版俊顐墴濮婁粙骞囬鐐垫闂佺懓鎼ˇ顖氼潩閵娾晛绠ｉ柟閭︿簽閸?闂婎偄娴傞崑鍡涘极閵夈儮鏌﹂柍銉ュ暱閸愨偓闁?
          //      闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊楣冾敆濠婂牆鍙?D1 閻熸粎澧楅幐鎼佸垂閻㈠灚鍟哄ù锝夋敱閸欏繘鏌ｉ妸銉ヮ仾闁伙附妞介幆鈧柛娑卞亐閸嬫捇宕掑☉姗嗘殹婵炲濮伴崕瀵告崲閺嶎厽鐓傞悘鐐靛亾绗?`婵炶揪绲界粔鏈电昂濠电偛鐪查妶鍥╃暫闂傚倸鍊堕崝鎴濐瀶?**婵?* 婵炴垶鎸哥粔闈浳ｅ宀€鐤€妞ゆ劑鍊栭弳鎭呴梺?
          if (offsetY < PlaybackPage.DISMISS_MIN_START_VP && !fastFlick) {
            return;
          }
          this.refreshCollapseGeometry();
          this.dismissMorphActive = true;
          // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佸彉鍗冲畷妤呭箮閼恒儻绱ㄩ梺鍦帛閸旀帒顫濋敃鍌氱哗閻熸瑥瀚悘?*闂佺儵鏅濋…鍫ヮ敋椤曗偓閺?*闂佸憡甯囬崐鏍х暤娓氣偓閺佸秵寰勫☉姘辩崶闁荤姍鍥ㄦ暠濠⒀勭矋濞艰鈻庢惔锝庝紘闂佸憡甯熼褔宕㈠☉銏犵濠电姴鍊荤粔濂告煕閹惧磭啸缂佺粯蓱閹棃鏁冩笟鍥ф暪婵炴垶鎸搁鍡楊焽?闂佺偨鍎查弻锟犲焵?
          //   闂佸搫顦遍崑鎾存櫠濠婂牆绫嶉柛鎾茬劍閻ｉ亶鏌涢幒瀣偓鏍х暤娓氣偓瀵?**濠殿噯绲惧Λ渚€骞戦敐澶嬪€烽柣鐔稿缁愭棃鏌涢妷褍浠╅柧鏂款儐缁傚秹宕卞Δ濠冣柤闁?*"闂佹寧绋戝濉猠lta`闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪顓奸崱妯?缂傚倸鍊甸弲娑㈠春鐏炲墽顩查柛鈩冾殢濡鎮?闂?
          //   闂佸搫鍟版慨鐑藉疾?`reverseQuitDelta()`闂佹寧绋掗悺鐚秛it = delta >= max(baseT/2, COMMIT_T)`
          //   闂佹寧绋戝濉ecover/logic-src/閻庢鍠掗崑鎾绘煕韫囨碍鐝柟鎼佷憾瀵劑骞嗚閻?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄦ皑缁愮偤鎮楃憴鍕殤妞?md` 闁圭厧鍊垮畷?L351-353 / L386闂?
          //   闁诲孩绋掗〃澶嬩繆椤撱垺鍎?L151812-151838闂佹寧绋戦ˇ顓㈠焵?
          //   闂佸疇娉曟刊瀵哥箔?闂婎偄娲ら幊姗€濡磋箛娑樻嵍?`morphBeginLeaving()` **婵炴垶鏌ㄩ鍛櫠?*闂佸憡鐟﹂悧顓犳閻楀牏鈻旈悗锝傛櫇椤忚鲸鎱ㄥ┑鍕姍缂佸彉鍗冲銊╁捶椤撶喓銈叉繛杈剧到缁夋煡鍩€?
          this.dismissBaseT = this.expandState.morphP;
          PlaybackPage.ev('LV', `finger p=${this.dismissBaseT.toFixed(2)}`);
          this.expandState.morphBeginLeaving();
        }
        this.expandState.morphDrive = MorphDrive.FINGER;
        this.expandState.applyMorphProgress(1 - progress / 100);
        return;
      }
      if (!this.dismissMorphActive) {
        return;
      }
      this.dismissMorphActive = false;
      // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫宥咁潩椤掆偓瑜扮娀姊婚崒銈呭箺鐟滈鐒︾粋宥夊Χ閸℃ɑ姣夐梺?*闂佺儵鏅濋…鍫ヮ敋椤曗偓閺?*闂佸憡甯囬崐鏍х暤?`delta >= max(baseT/2, COMMIT_T)`
      //   闂佹寧绋戦悧濠偽涢妶澶嬪仼?`reverseQuitDelta()`闂佹寧绋掔粙鎴﹀吹椤撶喎绶為柛鏇ㄥ亝閸婂崬鈽夐幘鎰佺叚缂佽鲸宀告俊?
      //   閻?`delta` = 闁荤姍鍥舵闁稿绲惧璇测槈濡警鍞?闂?閻熸粎澧楅幐鍛婃櫠閻樿櫕浜ゆ繛鎴灻?= "闁哄鏅滈悷銈囩博閹绢喖绠柡宓懐鐛㈤梺鎼炲劤閸嬬娀鎽傜€ｎ偆顩查柛鈩冾殢濡鎮?闂?
      //   閻?**濠电姴艌閳ь剙纾鏃傗偓娈垮枓閸嬫捇鎮硅閺€杈ㄦ櫠?*闂佹寧绋戝濉╝seT = 1`闂佹寧绋戦ˇ顐﹀闯?闂傚倸鍟悧鍡涘焵?= `max(0.5, 0.32) = 0.5` 闂?**闁荤喐娲戦悞锔藉垔濞差亜鐐婇柣鎰絻缁?50% 闂佸綊娼х粔鎾矗?*
      //     闂佹寧绋戦悧濠囧极婵傜绀堢€广儱妫欑瑧"缂傚倸鍊甸弲娑㈠春?38% 闁诲繐绻愬畷顒勫矗?闂?`delta 闂?0.38` 闂?**闂佸搫娲﹀娆擃敊閹版澘鍙婇柟鎹愵嚃閸ゆ牠鏌?*闂佹寧绋戦¨鈧紒?
      //   閻?`baseT` 闁诲繐绻愮换瀣姳?0.64 闂佸搫鍟悥鐓幬ｉ崶顒€纾瑰┑鍌滅《閸嬫捇鍩€椤掑嫬绀?`COMMIT_T = 0.32`闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸曨偂绨奸梺?`max` 闂佹眹鍔岀€氼剝銇愰悢鍝モ枖闁逞屽墴瀹曗剝绻濊箛鏇狀槴闂?
      //   闂佸疇娉曟刊瀵哥箔?闂備緡鍋嗛崰搴ｂ偓纭呮珪閵?*婵炴垶鎸哥粔鐑藉礂濡崵鈻?*闂佹寧绋掔喊宥呂涢妶澶嬪仼閻忕偠鍋愰惁宥夋煛?`闁哄鏅滅粙鎴犫偓?闂?闂備緡鍋嗛崰搴ｂ偓鍦墢闂佹寧绋戦悡顏囶槺缂?1.2闂佹寧绋戦¨鈧紒?闂婎偄娴傞崑鍡涘极?闂婎偄娲ら幊姗€濡磋箛娑欏亗鐟滃酣鎮ч柆宥嗗殑闁芥ê顦ぐ鐘绘煏?
      const currentT: number = 1 - progress / 100;
      const dismissDelta: number = this.dismissBaseT - currentT;
      const dismissThreshold: number = Math.max(this.dismissBaseT / 2,
        PlayerExpandState.PULL_OPEN_COMMIT_FRACTION);
      const shouldClose: boolean = dismissDelta >= dismissThreshold || fastFlick;
      // 婵炴垶鎸搁敃銉モ攦閳ь剟鏌熼悜妯虹瑲闁绘搫绻濋幃浠嬧€﹂幒鏃傜崶`hdc shell hilog -x | Select-String 'RzdMorph dismiss commit'`
      // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈囩博鐎靛憡鍋?*闂佽桨绀侀幊蹇涘礈娴兼潙瑙﹂悘鐐靛亾椤ρ囨煙閸偅灏悶姘抽哺缁嬪顢旈崨顔惧幍闂佸憡纰嶉崹鐟扳枔閹达附鈷撻柛顐ｇ妇閸嬫捇姊荤€靛摜鎲挎繛鎴炴尪閸婃捇鏌屽鍫濈闁糕剝顭囧Σ?*闂佹寧绋戦悧鍡楊嚕椤掑倹鍠?
      //    `PlayerExpandState.pullSpanIsMeasured()` 闂佹眹鍔岀€氼參寮悙鐑樼厒?/ `濠电偞鐓＄粻鏍偂閸洖绀夐柕濞у嫭姣嶣ug濠电偞鎸搁幊搴＄暦?md` 闁?.5闂佹寧绋戦¨鈧紒?
      //    闂佸憡鐟禍婵囨櫠?濠殿噯绲鹃弻銊╁焵?vs 闂傚倸鍟悧鍡涘焵?婵炴潙鍚嬪銊╁箣妞嬪海纾兼い鎾墲椤ユ垵霉?婵炴垶鎸堕崐鏍ㄤ繆閸濄儰鐒婇柛婵嗗閹藉秴鈽夐幘宕囆ｆ俊鍙夋倐瀹曘儳浠﹂懖鈺婁紘婵炴垶鎼╂禍顏堝汲鏉堛劍鍎?闁哄鏅滈悷銈呪枎閵忥紕顩查悗锝冨妷閸?
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdMorph dismiss commit progress=${progress.toFixed(2)} baseT=${this.dismissBaseT.toFixed(3)} ` +
        `delta=${dismissDelta.toFixed(3)}/${dismissThreshold.toFixed(3)} ` +
        `velocityY=${velocityY.toFixed(1)} ` +
        `absVelocity=${speed.toFixed(1)} dir=${collapsingDirection ? 'collapse' : 'open'} ` +
        `fastFlick=${fastFlick} velocityThreshold=${PlaybackPage.DISMISS_COMMIT_VELOCITY} ` +
        `span=${this.dismissSpanVp().toFixed(1)} spanSrc=${
          this.expandState.miniY > 0 ? 'measured' : 'ratio'} ` +
        `openThreshold=${PlayerExpandState.PULL_OPEN_COMMIT_FRACTION} openSpan=${
          this.expandState.pullSpanVp().toFixed(1)} openSpanSrc=${
          this.expandState.pullSpanIsMeasured() ? 'measured' : 'ratio'} commit=${shouldClose}`);
      if (shouldClose) {
        // 婵炲瓨鍤庨崐妤冨垝?closeFullScreenPlayback闂佹寧绋掗懝楣冩偩閻樺啿顕辨慨姗嗗幖婢跺秹鏌ｉ鐔蜂壕闂佺娉涢敃銈夋嚋娴兼潙鐭楁俊顖氬帬婢舵劖鈷掗柡澶嬪灥閻?0 闂佸憡鍔曠粔鏉戠暤韫囨梹濮?
        this.closeFullScreenPlayback();
        return;
      }
      // 濠电偛鐪查妶鍥╃暫闂傚倸鍟悧鍡涘焵椤掑倶鈧妲愰弶娆惧殨闁荤喓澧楃粈鈧柣搴ｆ嚀閺堫剟寮抽敐澶婄畱濞撴艾锕︾粈澶嬵殽閻愯泛鐓愬┑鈩冩倐閹嫰姊归幇顔拘㈤梺琛″亾閻犺櫣鍎ょ粈鈧?OPEN
      this.expandState.morphDrive = MorphDrive.ANIM;
      // 闂佸疇妫勯幊澶娢?P0-3闂佹寧绋掑銊ッ规径瀣鐎广儱鎳愮粔鍝劽归敐鍛ｉ柡浣搞偢閹?*闂佺粯鐟崜娑㈡偟濞戞瑧顩烽柨婵嗘－閸?*闂佹寧绋戦悧鍛閻戣棄绠叉い鏃€顑欏宀勬倵濞戞瑯娈曟い?`dismissSettleGen` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煥?
      //   婵炴垶鎸哥粔鎾疮閳ь剙顭跨捄铏剐ら柡?`morphGen` 闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯鈺冩閹殿喗鍋栨い鎰ㄥ墲瀹曟彃霉閿濆棙绀冮柡灞斤攻鐎电厧顫濆畷鍥ㄢ枔 ++闂佹寧绋戦懟顖烆敋闁秵鍤婄痪鎯ь儑缁犺绻涢崱蹇撳⒉闁轰礁婀辨禍鎼佸箲閹板灚钑夐梻鍌氱墛閻熲晝鍒掗婊勫磯閻庡湱濮风粻鏍煥?
      //   闂?`morphDrive` 闁诲繐绻楁ご绋款浖閸喐浜ゆ繝濠傚暕缁鏌?`ANIM`闂?
      const settleGen: number = this.dismissSettleGen + 1;
      this.dismissSettleGen = settleGen;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
        this.expandState.applyMorphProgress(1);
      });
      setTimeout((): void => {
        if (!this.isAlive || this.isClosing) {
          return;
        }
        if (settleGen !== this.dismissSettleGen) {
          // 闂佸搫鐗滈崜婵嬫偪閸℃稑鐐婇柣鎰蔼閸撱劎鈧鐡曠亸顏堬綖閿旂晫鈻旈悗锝傛櫇椤忚鲸绻涢崱蹇婂亾閾忣偆顦ラ悗娈垮枤閹虫捁銇愰崶銊ь浄?
          return;
        }
        // 闂?闂佺儵鏅犻弲鑼礊閸涱収鍟呴柤濂割杺濞煎爼鏌涢幒婵嗕簽婵炲牊鍨剁€电厧顫濆畷鍥ㄢ枔闂佽浜介崕鎶筋敇閸濄儰鐒婇柛妤冨仧缁犳垵顪冮妶鍥╁笡闁哄倷绶氶獮宥団偓锝呭缁愭鏌￠崒鐑嗘殥缂佹柨鐡ㄥ顏堫敊閽樺褰岄梺鍛婃煟閸斿妲愭导鏉戠?`drive` 缂?`FINGER`闂?
        //   `morphBeginEntering` 婵炴潙鍚嬬喊宥嗕繆?`stage` 缂?`ENTERING`闂侀潧妫斿姊抣oseFullScreenPlayback`
        //   婵炴潙鍚嬬喊宥嗕繆?`isClosing` 缂傚倸鍠氶崰姘耿?闂佺偨鍎查弻锟犲焵?婵炴垶鎸搁ˇ閬嶏綖閹烘绠抽柕澹苯鎮侀梻渚囧枛閳ь剛鍠庨崢鎾偠濮樼厧浜楃紒妤€鍊垮Λ鍐閻樺弶顓婚梺鍝勵槴閸撴繄浜搁崨顔藉闊洤顑傞崑?
        //   闂佸憡鐟禍婵嗭耿?闂佸搫鐗滈崜婵嬫偪閸℃顩风€广儱妫欑瑧闂佺儵鏅犻弲鑼礊閸涱喚鈻旈悹浣芥珪閻?闂佸搫鍟抽崺鏍ㄦ櫠閻樻亽浜归柟鍝勭Ф缁夋挳鏌?
        if (this.expandState.morphStage !== MorphStage.LEAVING
          || this.expandState.morphDrive !== MorphDrive.ANIM) {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss bounce: phase taken over stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}, skip settle`);
          return;
        }
        // 闂?`morphSettleOpen()` 闂佸憡鍔曢幊姗€宕曠€涙ê顕辨慨姗嗗幖鎯?`morphDrive` 閻?`NONE`
        //   闂佹寧绋戝濉抣ayerExpandState` L2421闂?*闂佺绻堥崝瀣垝閵娾晛鑸规い鏍ㄧ懅椤?*闂佹眹鍔岀€氼厾绮╂繝姘挅闁告挷绀佹禒顖炴煥濞戞﹩妲撮柍褜鍓氶弻锟犲焵?
        //   闁哄鏅滈悷銈囩博閺夋埈娼伴柕澶堝劜閻ㄦ垿鏌?婵犮垻鎳撻崯鍧楁儑娴兼潙绀傞悗锝庡枟閻ｇ兘鎮橀悙鎻掆偓鎼佹偉閼哥偣浠?闂備緡鍙忕徊鎯ь焽?bug 闂佹眹鍔岀€氼垵顣鹃梺鑲╃摂閸ㄧ晫妲?*婵炴垶鎸哥粔鐑姐€呴敂鍓х＜闁哄浄绱曠粻鏍倵?*闂?
        this.expandState.morphSettleOpen();
      }, 240);
      return;
    }
    // 闂佸搫鍟版慨闈涳耿娓氣偓瀵偊宕奸妷锔芥珨闂佺粯鍔欓埀顒佺〒閻熸繈寮堕埡鍌氬妞ゃ垺鍨垮顔款槻閻㈩垰娲獮宥嗘媴閸濄儺浼岄柣蹇曞亹閸嬫捇鏌ㄥ☉妯绘拱婵犮垺顨婇獮宥団偓锝庡亜婵剟鎮洪幒鎾斥枙婵℃彃娲畷鎰板礂閻撳寒鏋€闂佺儵鏅涢悺銊ф暜閹绢喖绀傞柟鎯板Г閿涙棃鏌?
    if (!ended) {
      return;
    }
    const shouldCloseFallback: boolean = progress >= PlayerExpandState.DISMISS_COMMIT_PROGRESS || fastFlick;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMorph dismiss commit(noMorph) progress=${progress.toFixed(2)} velocityY=${velocityY.toFixed(1)} ` +
      `absVelocity=${speed.toFixed(1)} dir=${collapsingDirection ? 'collapse' : 'open'} ` +
      `fastFlick=${fastFlick} commit=${shouldCloseFallback}`);
    if (shouldCloseFallback) {
      this.closeFullScreenPlayback();
      return;
    }
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
      this.collapseProgress = 0;
    });
  }

  // 闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸?闁诲繐绻嬬欢姘焽?+ 濠殿喗绻傞懟顖炲箖閺囩姷纾兼い鎾卞焺濡囨煕閹烘柨顣奸柣鈩冩礈閹风姴顓兼径鍫氬亾婢跺浜滈柛顐ｆ礀閸斻儵鏌ㄥ☉妯荤2闂佹寧绋戦ˇ顐﹀绩閵忋倕鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵?

  /**
   * 闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸闁硅埇鍔嶅▍婊堟煃閻戞ê濮€闁?闁诲繐绻嬬欢姘焽?/ 濠殿喗绻傞懟顖炲箖閺囩伝褰掝敊閼测晜鍕鹃梺?*闁荤姵浜介崝鎴﹀Υ婢跺备鍋撶憴鍕叝缂?*闂佹寧绋戦悧鍡涱敋椤曗偓瀵粙宕堕妸锔奸獜闂?`floatingCover` / `floatingMeta`闂佹寧绋戦ˇ顐﹀疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸闁硅埇鍔嶅▍婊堟煃閻戞ê濮€闁哄懏鐓￠崺?
   *
   * 闂佸憡甯掑ú銈夊春鐏炵瓔娼扮€光偓閸愵亝袚婵＄偑鍊曢悘姘渻閸屾粍濯?*闂佸憡鑹炬總鏃傜博閺夋埈鍤曢柣妯垮皺濞堥亶姊?+ 濠殿喗绻傞懟顖炲箖?*缂傚倸鍊甸弲娑㈡儍椤掑嫮宓侀柛鎾茬悼閳哄懎绀嗛柣妤€鐗忛幗鍐偣閸パ呅ч柕鍡楊槹閵囧嫰宕奸弴鐐插Г闂佹寧绋戦懟顖炲垂韫囨稑鐐婇柣鎰皺濞堥亶姊婚崼娑樼伈闁靛棗顦靛顔炬崉閸濆嫭鏋鹃柣鐘辫閸ㄥ爼藟閿濆鐐?闂佺偨鍎查弻锟犲焵?
   * **闂?Swiper 闂佹眹鍔岀€氼厾鍒掗幘顔肩闁靛鍔庣粻濠氬箹鏉堝墽鐣甸柍褜鍓氶崝鏇㈠箮濮橆厹浠氶柛妤冨仜琚?*闂佹寧绋戦悧鍛箔婢舵劕鍙婃い鏍ㄧ潧婢舵劖鈷掗柟缁㈠枓閺€鎶芥煕閺冩垹鍘滅紒杈ㄥ哺婵?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ゅ枑绗戦柡澶嗘櫆閻燂箓鎮ч柆宥嗘櫖闁割偓绲洪崑鎾朵沪閼测晝鎲归梺?婵炴垶鎸堕崐婵嬪Υ婢舵劕瑙﹂柛鏇ㄥ幗閺嗘澘鈽夐幘顖氫壕婵?闂?
   *
   * 闂佸搫鍟版慨鐑藉疾椤愶附鍎?`playerPane` 闂?`Stack { Swiper{ 闁诲繐绻嬬欢姘焽閻楀牄浜?; 缂備礁鐬奸崕銈夋偤閺囩姵瀚氱€广儱顦埀?} ; floatingCover ; floatingMeta }`
   * 闂佺偨鍎查弻锟犲焵?闁诲繐绻嬬欢姘焽閻楀牏鈻旈幖娣灮閹藉啴鏌?*闂佸湱顭堥崐绋匡耿?Swiper 婵炴垶鏌ㄩ鍛此?*闂佹寧绋戦懟顖炲垂韫囨柣浜滈柛顭戝亝椤ρ囨煛?*闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳鐢绱?*闂侀潻璐熼崝灞炬叏閳哄懏鏅繛鎴炵懅閹藉啴鎮归崶褏效闁靛棗顦甸弻鍥晲閸曨収浼囨俊鐐€曢悘姘耿娴煎鍙曟い鎰剁稻绗戞繛鎴炴惄娴滅偤鍩為弽銊х彾缂佹稑婀辩粈?
   * 闂佸憡鐟禍婵嗭耿?`padding({ top: lyricPadTop() })` 闁荤姳璁查弲娆戠礊閸涙潙违?
   *
   * ## 婵炴垶鎸搁ˇ顕€鏌屽鍕枖鐎广儱鎳庣紞渚€姊?
   *
   * 1. **闂佺绻堥崝灞解攦閳ь剟鏌涘▎妯圭凹婵犫偓娴ｅ湱鈻旈柍褜鍓欓锝夋偐閼碱剚顔堥梻?*闂佹寧绋掗懝楣冩儍濠靛顥堥柕蹇嬪€戦埀顒€顦甸弻鍥晲閸曨偅鏆呴梺娲讳簽閸犲酣鎯冨┑瀣棃闁靛繒濮撮崵鎺旂磽娴ｅ摜绠伴柤鑽ゅ枑濞艰鈽夊▎鎺旀闁诲繒鍋涢崑濠勬濡句炕age 0` 闂佸憡鐟禍婊勬櫠?
   *    `MiniLyricLinesComponent` 缂備礁鑻幖顐︽晬閹剧粯鏅鑸电〒缁€?婵炴垶鎸堕崐鎾诲船閵堝洣鐒婂〒姘ｅ亾婵為棿鍗冲畷銉т沪閻愵剦妲梺鍛婄懐閸ㄧ敻锝?婵炲濮村ù椋庡垝閵娾晛鍑犻柛鏇ㄤ簽閻熸劙鎮樿箛鎾崇秮缂佹顦靛畷锝夘敍濠靛棗骞嬮梺?
   *    闂佸湱顣介崑鎾趁?*濠电偛澶囬崜婵嗭耿?婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲秶鑺遍幍顔藉仒?闁哄鏅滈悷銉ッ洪弽銊ь洸?*闂佹寧绋戦悧濠偽涢锔解拻?`lyricFloatActive()` 閻庣懓鎲¤ぐ鍐垂瑜版帗鏅鑸电〒楠?
   * 2. **闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝囨焿閳峰牆顪冮妶澶嬫锭闁诡喖娲幊娑㈩敂閸艾浜鹃柟閭﹀墮閸撹偐绱掓潏鈺佇＄紒妤€顦靛畷?*闂佹寧绋掗悺鐚?= 0` 闂備緡鍙忕徊鑲╃博鐎靛摜鍗氭い鏍ㄧ閻ㄦ垿鏌￠崟闈涚仯婵犫偓閿涘嫪鐒婂〒姘ｅ亾婵為棿鍗抽幆鍐礋椤旇棄鍔欓梺缁樺姇濠€閬嶆偂閳哄嫨浜?
   *    闂佹寧绋戝濉抣ayerExpandState.lyricMorph(0)` 婵犮垼娉涚粔鍫曞极閵堝洨纾兼い鎾卞焺濡囨倶韫囧海绐旀繛?`p=1` 闂佹眹鍔岀€氼剟骞冮幘瀵糕枖闁逞屽墮閳绘捇鎮藉▓澶哥磽闂佺粯鍔楅幊鎾诲吹閹寸偞濯撮柡鍥朵簽缁€鍡涙煥?
   *    闂佸湱顣介崑鎾趁归悩顔煎姍婵﹫绠戣灋闁圭儤顨呮禍婵嗏槈閹绢垰浜鹃柣銏╁瀻閸曨厽鈷曢梺鍝勭墕椤︻垵銇愰懠顒佸磯鐎规洖娲﹂悾杈┾偓鐟板閸ｎ垳妲?
   * 3. **濠电偞鎯岄崰鏍儑閻楀牏鈻旂€广儱鎳庣拋鏌ユ煟椤剙濡兼慨妯稿姂瀵偊寮堕幋顓燁唶婵炴垶鎸哥粔鎾箚鎼淬劍鍋?*闂佹寧绋戝濉磞ricFloat()` 婵炴垶鎸搁幖顐ｇ閿濆鏅慨姗嗗墰濞堥亶姊婚崼娑樼仾闁汇儱鎳橀弻宀冪疀閹惧磭鍘?/ 闁诲海顢婂Λ鍕儓閸℃稒顥堥柕蹇婂墲缁舵煡鎮硅濠㈡銇愰悢鍝モ枖闁逞屽墯缁鸿棄螖閳ь剛绮╂搴濇勃闁逞屽墴閺?
   *    闂佺偨鍎查弻锟犲焵?婵炲濮崑鎾斥槈閺傝法澧﹂柛蹇斏戠粙澶婎吋閸ャ劍姣庨梺闈涙濮婃yricPadTop()` 婵炴垶姊婚崰鎰?0闂佹寧绋戞總鏃傜箔鐏炶В鏌﹂柍鈺佸暞缁犳帡寮堕埡鍌滄噧妞ゃ劍绮嶇粙澶婎煥閸℃劕浠鹃梺鍝勫暞濠€鍦博閹绢喗鍤婃繛锝庡厴閸?
   *
   * 闂佸疇娉曟刊瀵哥箔?**濠殿喗绻傞惌渚€鎯佸┑瀣畱閹煎瓨绻勯悿鍕煟閵忥綆鍞虹紒鏂跨摠缁嬪顢旈崟顓熸喕濠电偛澶囬埀顒€鍟胯**闂佹寧绋戝濉媦ricsComponent` / `AmllLyricView` 婵炴垶鎸哥粔鍫曪綖椤愶附鏅鑸电〒缁€?
   *   闁哄鏅滈悷鈺呭闯閻戣棄鐭楁い蹇撳琚?闁诲繐绻嬬欢姘焽?濠殿喗绻傞懟顖炲箖閺囩伝褰掝敊閼测晜鍕鹃梺姹囧妼鐎氼垰鈻旈弴鐔翠簻闂傚牊绋撻弳鏉棵?婵炴垶鎸哥€涒晠鎮洪弴鐘冲珰鐎广儱顦埀顒€顦甸幆鍐礋椤栨ǚ鍋撴繝鍥ㄧ劸闁靛ě鍕暚闂佽皫鍐炬綗闁?
   *
   * ## 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*婵＄偟鎳撳畷顒佹叏閳哄懎妫橀柣鐔稿绾偓閻庤鐡曠亸娆撳矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽京澧楀璇测槈濡警鍞洪悗娈垮枛妤犲繒妲愬┑鍥┾枖鐎广儱妫欑瑧闁荤偞绋忛崕闈浳涢崹顕呭殨?*闂?
   *
   * 闁哄鏅滈悷鈺呭闯閻戣棄鍌ㄩ柣鏂挎啞闂勫秹鏌￠崼婵愭Х缂佹柨鐡ㄧ粙?`animateLyricMorph(toLyric)`闂佹寧绋掑銊╁极?`animateTo(360ms, EaseInOut)` 闂?
   * `lyricMorphT` 婵?0 闁荤偞绋忛崕閬嶅春?1闂佹寧绋戦悧濠囧垂閵娾晛鐭楃€广儱鎳忛崐濠氭煥濞戞﹩妾х紒杈ㄧ箞閻涱噣宕滄担瑙勬 `.onAnimationStart` 闁荤姴顑呴崯浼村极閵堝违?
   * **闂佺粯绮嶅妯猴耿椤忓棌鍋撻悷鏉挎殭闁告埊绻濆畷姘舵偐缂佹褰?*闂佹寧绋戦惉濂稿箖婵犲洦鍋ㄩ柟鎻掝儑缁€鍕叏閿濆懐绠ｇ紒鏃€鎸冲鍫曟晸閻樻彃骞嬮梺鍦焾濞层倝骞冨鍫濈睄闁绘ê鐏氬▍鏇㈡煟閵娿儱顏╅悽顖ｅ亰瀵剟宕舵搴ｎ槴闂?
   *
   * ```
   *   闂?闂佸搫鍟版慨鐑藉疾?*濠电偛澶囬崜婵嗭耿娴ｈ浜ゆ繛鍡樺姈閽傚鎮跺☉鏍у姦婵?*闂佹寧绋掗懝楣冩偩閻樼粯鍎嶉柛鏇ㄥ亞濞堥亶姊婚崼顐ｇ窔缂傚秴鎳愮槐鏃堫敊閻愵剛鍑介梺瑙勪航閸庢彃危?`morph.scaleAt/txAt/tyAt(swiperProgress)`
   *      闂佺偨鍎查弻锟犲焵?`swiperProgress` 闁诲繐绻楁ご绋课?Swiper 闂佹眹鍔岀€氼厾鍒掗幘顔肩闁靛鍔庣粻濠氬箹鏉堟崘顓虹紒杈ㄧ懅閹?闁?16.2 闂佹眹鍔岀€氫即鍩€椤掍礁濮堟繛纰卞灣閳ь剚绋掗〃澶嬩繆椤撱垺鍎樺〒姘功缁€鍡涙煏?
   *   闂?`.onAnimationStart` 闂備緡鍙忕徊鎯ь焽椤栨粍宕夋い鏍ㄦ皑閺併劑鎮楅悷鎵鐎规洖銈告俊瀵糕偓鍏夋殬dex === targetIndex 闂?闁荤姴鎼悿鍥╂崲閸愵喖违?
   *      闂?闂佸憡鐟禍锝夈€呴敃鍌氱闁搞儺鍏欓埀顒€顦扮粙澶婎吋閸℃?婵炴垶鎸撮崑鎾寸箾閸☆厾纾挎繝鈧垾鎰佺叆闁瑰瓨绻傝"闂佹寧绋戦悧蹇涘煝閸忓吋鍎熼煫鍥ㄦ尭椤曆囨煕閹烘垶鍠橀柕?/ 闂備焦褰冪粔鐢碘偓鍨礃濞碱亪鎸婃径濠勪淮婵犳鍠栭澶愬Υ婢跺鈻旂€广儱妫欑瑧 0 / 婵＄偑鍊曢崥鈧紒妤€鐭傞幃鈺呮嚋绾版ê浜惧ù锝夘棑閻熸繂鈽夐幘顖氫壕闂佽偐鏌夐幓顏嗘濮樿埖鏅?
   *        闂佽桨鐒﹀娆撱€冨鍕垫Ч闁绘劙顤傞弨?*濠殿喗蓱閻℃洜鎹㈠▎鎰枖鐎广儱鎳忛崕娆撴煕?* 闂?`lyricMorphT` 闂?0 闂?闁诲繐绻嬬欢姘焽娴兼潙绠掗柟鍝勭Х缁€瀣熆閸棗鍟板▓閬嶆⒒閸偅濞囬柍?
   *        **闂佹椿娼块崝宥夊春?2026-10-16 闂佹眹鍔岀€氼參宕洪崨鏉戠倞闁绘劦鍓﹂崝鈧梺鍝勫閸ㄧ數鎹㈤弽銊р枖妞ゅ繐瀚崺宀勬煟?*闂佹寧绋戦悧鍡涘Φ閸モ晙鐒婂〒姘ｅ亾婵為棿鍗冲畷锝夋偐閸偆绁峰┑顔界箓閻線鎯佸┑瀣櫖濠㈣泛鐗冮崑?
   *   闂?闂佸憡甯炴慨鐢垫暜閳ь剙鈽夐弬娆惧剰闁?`t` 闂?`onSwiperContentDidScroll()` **闂備緡鍋呴崝鏇㈠箮?*闂佸憡鍔栭悷杈╂濞嗘垟鍋撶憴鍕嗘垿寮?SDK闂?
   *      "invoked ... on a frame-by-frame basis"闂佹寧绋戦¨鈧紒?*婵炴垶鎸哥粔宕囨妞嬪孩灏庨柡宥忛檮瀹曟彃霉?闂佸憡鐟﹂崹褰掑极閹惧瓨浜ら柛銉椤忚鲸绻涢崱蹇撳⒉缂侇噯绠撳畷?**闂?
   * ```
   *
   * 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸告鎼佹偩閻樺磭鈻旈柍褜鍓涢幐褔鎽庨崒婊呮喒闂佸憡鍔曠粔鐑斤綖閿旇姤濯撮悹鎭掑妽閺嗗繘鏌ｉ妸銉ヮ伂缂佺粯娲熷鍨緞濞戞氨鐛lyricSwiperSettled` / `lyricFlightSettled`闂佹寧绋戦悧鎾诲磻閸涱垪鍋?婵炴垶鎸堕崐婵單涢崼鏇炵闁斥晛鍟·?闂?
   *    婵?`LYRIC_MORPH_DURATION_MS`闂侀潧妫楅崐鎼佹偩閻樺磭顩?*婵烇絽娲︾换鍕汲閳ь剙鈽夐幘铏儓闁烩姍鍐ｆ灁?闁汇埄鍨遍幃鍌炲闯?*闂佹寧绋戦悧鍡欑玻濮椻偓瀵粙宕堕敂鍓х厳闂佺懓鐏氶幐绋跨暤閸愵喖绀堢€广儱瀚埛鍫濃槈閹垮啩鎮嶇紒杈ㄥ哺閺?
   *    婵?*濠电偛澶囬崜婵嗭耿娴ｆ悶鈧帡宕ｆ径灞藉脯闂佹椿娼块崝鎴﹀焵?* 闂佺偨鍎查弻锟犲焵?闂佸吋鐪归崕鎶藉灳濡吋濯奸柕鍫濆閻熸繈姊婚崶锝呬壕闁荤喐娲戠欢銈囨濠靛鐭楁い鏍ㄧ懁缁ㄤ即鏌℃担鍓插殶缂侇喖绉瑰畷姘舵偐閸愯尙顏遍梺?
   * 闂佸疇娉曟刊瀵哥箔?`lyricMorphVisible` / `lyricMorphOpacity` 闂佺粯绮嶅妯猴耿?*闂佸憡鐟禍锝夛綖閿曗偓椤曘儵鎳為妷褍鐏遍柣?*闂佹寧绋戞總鏃傜箔婢舵劕绀冪€广儱顦伴敍灞矫归敐鍛闁瑰箍鍨洪幏鍛村即閻橀潧绗￠梺?
   *    闂佹寧绋戦悧濠囧垂濠婂牆绠┑鐘插€稿鍧楁⒑椤斿搫濡界紒澶愵棑閹峰綊宕烽鐐板寲濠电偞鎸搁幊鎰板磻閿濆棙浜ら柛銉╊棑缁愭姊婚崟鈺佲偓鎾惰姳閿涘嫭灏庨悗锝庝簴閸嬫捇鎳栭埡浣峰寲闂佹寧绋戦懟顖濄亹瑜斿?`refreshDiagText` 闂侀潻璐熼崝蹇涱敋娴煎瓨鏅璺虹墐閸?
   *    闂?闂佸湱顣介崑鎾趁?闂佸搫绉村ú銈囨崲閺傚簱鏌﹂梽鍥綖閿旇棄绶炵€广儱瀚粔?婵炴垶鎸哥粔宕囨娴煎瓨鐒婚柣妯哄暱閻忓洤霉閻樹警鍞虹紓宥呯Ф閹叉挳宕掑☉妯何ら梻鍌氬亞閸ｏ綁銆傛禒瀣櫖闁割偓绲跨粻鐟扳槈閹绢垰浜鹃梺缁樺姌椤危?*濠电偞鎸搁幊鎰板磻閿濆绀勯柣鎴炆戦梽宥夋煟?*闂佹寧绋戞總鏃傜箔婢舵劕鍙婃い鏍ㄧ☉閼靛綊鏌￠崒銈呭伎缂佽鲸宀告俊?
   */

  /**
   * `Swiper.onContentDidScroll` 闂佹眹鍔岀€氼剟藝閳哄懏鍋犻柛鈩冾殕閻?闂佺偨鍎查弻锟犲焵?**闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ枤缁犲骞栨潏楣冩缂?*闂佹寧绋戦悧鎾诲焵椤掍礁濮堟繛纰卞灦閹ゎ槼濠碉繝浜堕弫宥嗗緞閸艾浜?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*婵烇絽娴傞崰姘跺极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓張顒勬偤閺囩姵瀚氱€广儱顦埀顒€顦辨禍鍛婄瑹閳ь剙顭囬弶搴撴煢闁炽儱鍟跨紞渚€鎮樿箛鎾剁疄闁逞屽厸缁€浣姐亹閺冨牆鎹堕柕濠忓閹藉啴鎮归崶褏小缂佹鍊垮Λ鍐綖椤戣棄浜剧€广儱娲﹂悾閬嶆煛?*闂?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箘缁犳垵顪冮妶鍥╁笡婵犫偓娴ｈ　鍋撻悷鏉挎灕缂佽鲸鐟╁畷銏ゆ偄閸涘﹪妾烽梺姹囧妼鐎氫即鍩炲澶婄闁靛濡囬悥閬嶆煛閸曢潧鐏﹂柡浣革躬閹啴宕熼崜浣侯槴
   * 闂佸憡顭囬崰鎰焽?`lyricMorphT` **闂?*闂?`.onAnimationStart` 婵＄偟鎳撳畷顒佹叏閳哄懏鏅€光偓閸愶絽浜剧€光偓閸曨偂绨兼繛鎴炴惄娴滄粌煤閺嶎偅瀚柛鎰╁妿閺併劌鈽夐幘顖氫壕婵炴垶鎼╂禍婊堟偩瑜斿畷?
   * 闂侀潧妫楅悾鐠眓dex === targetIndex` 闂?闁荤姴鎼悿鍥╂崲閸愵喖违鐎广儱鍟犻崑鎾诲磼濞嗘巻鎷＄紓浣割槸缁夌敻宕曡箛娑樼闁稿繐鎽滈悷鎾诲级閳哄倻鎳侀梺鍙夌矌閳ь剛鎳撻悧鍡楃暦閸忕厧顕辨慨妯诲墯閸炪劑鏌℃担瑙勭稇妞ゃ劍绮嶉ˇ浼存倷妫版繃鏂€**濠殿喗蓱閻℃洜鎹㈠▎鎰枖鐎广儱鎳忛崕娆撴煕?*闂?
   *   閻?婵＄偑鍊楅弫璇差焽娴兼潙绀嗛柛銉ｅ妼鎼村﹤鈽夐幘宕囆ｆ俊?婵炴垶鎸撮崑鎾寸箾閸☆厾纾挎繝鈧垾鎰佺叆闁瑰瓨绻傝"闂佹寧绋戦悧鍛閵夛缚绻?swiper 闁荤偞鍑归崑鍡涘煝閸忓吋鍎熼煫鍥ㄦ尭椤曆囨煕閹烘垶鍠橀柕鍡楊樀婵″瓨鎷呴悷鎵粣闂備焦褰冪粔鐢碘偓鍨礃濞碱亪鎳為妷锔绘Н闂佸憡甯楃换鍌烇綖閹邦厹浜滈梻鍫熺⊕閻ㄦ垵鈽夐幘宕囆ｆ俊?0闂佹寧绋戦¨鈧紒?
   *   閻?闂備焦褰冪粔鐢碘偓鍨礃濞碱亪鎸婃径瀣偓?婵?婵?闂佺粯顭堥崺鏍焵?婵炴垶鎸哥粔宕囩博閹绢喗鍤婇弶鍫濆⒔缁€鍒瀘nAppear` 婵犮垼娉涚粔宕囩礊閸涱喗浜ら柛銉㈡櫅閸嬪秶鈧鍠楀ú鈺冩濮樿泛违?
   * 闂?`lyricMorphT` 闂?0 闂?闁诲繐绻嬬欢姘焽娴兼潙绠掗柟鍝勭Х缁€瀣熆閸棗鍟板▓閬嶆⒒閸偅绶涚紒杈ㄧ箞閹虫挾浠﹂崜褎鎲欓柣鐘叉搐缁夌敻顢楀鍫濇闁搞儮鏅涘楣冩煛瀹ュ鏁辨俊顖氼槺缁?闂?
   *   **闁诲繒鍋涚换瀣箔閸屾粈鐒婇弶鍫涘妽绗?婵犮垹鐖㈤崘顏咁唸闂傚倸鐗勯崹纭呫亹閺冨牊鍎撻柍褜鍓欓～銏犵暆閸愵亝袚"**闂佹寧绋戦悧蹇涘极閵堝绠?2026-10-16 闂佽鎯屾禍婊兠瑰鈧弫宥嗗緞閸艾浜?
   *
   * ## 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亗缁灚绻涙径瀣┛缂佽鲸鐛媤ujie.pa` L190026-190075闂佹寧绋戦懟顖炴偩閸撗呯煓?闁?.2 闂備緡鍋呴崝鏍ь焽椤栨稒濮滄い鎺嗗亾闁哥喐鎹囬弫?
   * ```ts
   *   let p = position;
   *   if (index === 0) {              // 闂?闂佸憡鐟禍婊冿耿?閻熸粎澧楅幐鍛婃櫠閻樼偨浜滈柛顭戝亝绗戦梺鍦檸閸樹粙寮担骞夸簻?闁哄鏅滈悷銈囩博鐎涙鐟圭憸宥囩礊婵犲啰鈻旈柍褜鍓熷畷?
   *     if (p < 0) { p = -p; }        //    閻庡灚澹嬮崑鎾绘煕閹惧磭校缂侇噯绠撳?position 婵炴垶鎹囩紓姘辩矆?闂?缂傚倸鐗忕划顖烆敆?
   *     if (p > 1) { p = 1; }         //    婵炴垶鎸搁敃銈夊Φ濞嗘挸绀?1
   *     this.swiperProgress = p;
   *   }
   *   publishCoverStyle(); syncMotion();
   *   if (this.swiperProgress > 0.5 && !this.chromeHidden) { this.showChrome(); }
   * ```
   *   闂佸疇娉曟刊瀵哥箔?**闂佸憡鑹炬绋跨暦閹邦兘鏋旂痪鏉款槺缁€鍕叏濠靛棛鐒烽柣锔界箖閵囧嫰鎮界粙澶哥凹婵炴垶鎸撮崑鎾炽€掑鈧鍥╊槴婵烇絽娲︾换鍐偓鍨⒐缁嬪绻濇担渚紘濠电偛妫寸槐鏇炩枔閹达箑纾?* 闂?**闂佺顑嗙划灞斤耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊曢悘姘渻?`p` 闂佽鍘界敮濠勬嫻?1**闂?
   *   闂佸疇娉曟刊瀵哥箔?闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗙墢閻?`onChange` **婵炴垶鎸哥粔鎾疮?* `swiperProgress`闂佹寧绋戦悧鍡涙偩閻樿鐭楁い蹇撳缁?idle/chrome 婵?
   *      `atLyricScreen = (v === 1)`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佸湱顣介崑鎾趁归悩顔煎姕婵犫偓娴兼潙妫橀悷娆忓閵嗗﹪鏌熼棃娑毿ｆ俊鍙夋倐瀹曨剟顢涘▎鎴紘闂佸憡鍔栭悷褔宕戦敐澶娢?
   *
   * ## 闂佺懓鐡ㄩ崹鍐差煥閹达附鍎嶉柛鏇ㄥ墮婢跺秵绻涙径瀣┛缂佽鲸鐟╁畷銉т沪閼测晩浼囨繛瀵稿Т閳ь剛鍣ラ崵鏂库槈閺傛妾х紒?
   * `lyricMorphT` 闁诲繐绻楁ご绋课ｉ幖浣稿珘妞ゆ垼娉曞▔銏ゆ煟?`swiperProgress`闂? = 闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏☆問娴?/ 1 = 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垺顔栨导鍌炴煥濞戞﹩妾х紒?
   *   閻?闂佺绻愰悧濠冧繆閸濄儲顫曢柕蹇曞Х缁屽潡鎮规担鐟邦€滃璺哄閺佸秹宕搁崚绯緾hange` 闂?缂備礁顑呴鍛姳椤撱垹绀岄柡宓啰鈧厧顪?闂佸搫鍟冲▔娑溿亹閺屻儲鍤勯柟瀛樺笧閻熸繈鎮峰▎娆戠暠鐟滄澘鍊块弫宥呯暆閸愵亞顔愰梻浣瑰絻閻倿鍩€椤掍礁濮囬柟鑸靛哺閺屽牓鎳為妷锔剧暢闂佺锕﹂妴瀣濮樿埖鏅?
   *   閻?闂佸憡鍔曠粔鍨繆濮濆被浜归柟鍝勭Ф椤忛亶鏌涢弽銊уⅹ闁诡喗顨婇幆?`p` 闂佸摜濮撮崐鑽ゅ垝?`lyricMorphT`闂?*闂備緡鍋呴崝鏇㈠箮?*闂佹寧绋戞總鏃傜箔瀹€鍕睄闁绘ê鐏氬▍鏇㈡煕濮橆剛鐒跨紒杈ㄥ哺閺?
   *   閻?闂佺粯甯熷▔娑㈠箖濡ゅ啯瀚?`syncLyricMorphToPage()` 闂?闂傚倸鐗婇悷锕傤敆濞戞氨鍗氭い鏍ㄧ矊娴狀垶鐓崶褎鍤囬柕鍡楃箳缁灚寰勬径宀冨閻熸粎澧楅幐鍛婃櫠閻樼偨浜?闂佹眹鍔岀€氼剟宕㈢憴鍕劅?
   *     闂佹寧绋戦悧鎰枖閺囩喐浜?0.5 闂佸搫鍟冲▔娑㈡偩閻樺啿顕辨慨妯圭婢跺鈻旈柍褜鍓欓埢搴ㄥ煡閸涱垳顦繛锝呮处缁诲棝鎯佹径瀣枖鐎广儱瀚粣妤呮煕鐎ｎ偆鐭婃繝鈧鍛枖闁靛牆娴傛导鍌氣槈閺傛鍎旀俊顐㈡健閺佸秵寰勯崼姘壕?
   *   闂佸疇娉曟刊瀵哥箔?婵＄偑鍊曢幖顐︽偨椤愶箑绠┑鐘插暞閿熴儵鏌ｉ敐鍛劯闁稿鎳樺畷?`if (p > 0.5 && !chromeHidden) showChrome()` 婵炴垶姊婚崰鎰板箚婢跺浜ら柛銉ｅ妽闂?闂佺偨鍎查弻锟犲焵?
   *      闁诲海鎳撻崯顐㈩潩閵娾晛鍙?濠电姴锕ラ崹鐢稿春鐏炲墽鈻旈柍褜鍓熷畷鈩冪節閸愩剮鈺呮煙鐠ㄥ鍟悡鎴︽煕閺嵮勬儓闁轰焦绮撳畷娆撴倻濡妾?闂佹眹鍔岀€氼厽鏅跺鍫濈疀闁绘梻琛ラ崑?
   * @param index 閻熸粎澧楅幐鍛婃櫠閻樼偨浜滅痪鏉款槺缁€? = 闁诲繐绻嬬欢姘焽閻楀牄浜滅痪鏉款槺缁€? = 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻缁炬澘顦辩粈?
   * @param position 闂佸憡鍔曢幊搴敊閹扮増鍎庣紒瀣儥閸ょ姴鈽夐幘瀛橆潡闂佹媽浜幐褎顦版惔鈥插寲闂佹眹鍔岀€氼喕绨洪梺鍛婃煟閸斿秹鎯侀鐣岀懝閻庯絽澧庣粈鍕倵鐟欏媶鎴﹀蓟?SDK 闂佸憡顭囬崰鎰板几閸愵喗鏅?
   */
  private onSwiperContentDidScroll(selectedIndex: number, index: number, position: number): void {
    this.diagScrollCount = this.diagScrollCount + 1;
    this.diagScrollLast = `${selectedIndex}/${index}/${position.toFixed(3)}`;
    // 闂佸啿鍘滈崑鎾绘煃閸忓浜?闂備緡鍋呴崝鏍ь焽椤栫偞鍋傜憸搴繆闁秴绫嶉柣妯虹仛濞呮洟鏌ｉ妸銉ヮ仼缂傚秴锕ョ粙澶愬焵椤掑嫬绀?闂佸啿鍘滈崑鎾绘煃閸忓浜?
    // ★★★ 2026-10-21（**照搬无界** `PlayerPage.onContentDidScroll`，`wujie.pa:190026-190075`）：
    //   上游反编译出来就是（`a4` = index、`a5` = position）：
    //   ```ts
    //     if (0 !== index) return;
    //     if (position < 0) position = -position;
    //     swiperProgress = position > 1 ? 1 : position;
    //     this.publishCoverStyle();      // coverScale / coverRadius
    //     this.syncMotion();
    //     if (swiperProgress > 0.5 && !chromeHidden) this.showChrome();
    //   ```
    //   ⇒ 只认页 0、只把负值翻正、上限 1 —— 与本仓上一版逐条相同。
    //   **上一轮我擅自改成"两页都接受"，那是错的（已回退）**：页 1 的 position 语义
    //   不同 SDK 上可能是 `1→0` 也可能是 `-1→0`，换算一旦猜错进度就整条歪掉。
    //   ⚠️ 真正的差别不在这里，而在上游每帧还会调 `publishMorphTargets()`（见下）。
    let p: number = position;
    if (index === 0) {
      if (p < 0) {
        p = -p;
      }
      if (p > 1) {
        p = 1;
      }
      this.lyricMorphT = p;
      // 照搬上游 `publishMorphTargets()`：封面页静止时把"歌词页终点几何"重发一次（带重试）。
      this.publishLyricMorphTargets();
    }
    // 诊断（`grep RzdLyricFloat`）：进度或页号变了才打一行，避免每帧刷屏。
    const diagKey: string = `${selectedIndex}/${index}`;
    if (diagKey !== this.lyricDiagKey || Math.abs(this.lyricMorphT - this.lyricDiagP) > 0.08) {
      this.lyricDiagKey = diagKey;
      this.lyricDiagP = this.lyricMorphT;
      Logger.info('RzdLyricFloat',
        `swipe sel=${selectedIndex} idx=${index} pos=${position.toFixed(3)} ` +
          `t=${this.lyricMorphT.toFixed(3)} float=${this.expandState.lyricFloat() ? 1 : 0} ` +
          `coverSize=${this.expandState.lyricCoverSizeOf().toFixed(1)} ` +
          `geomReady=${this.expandState.lyricGeometryReady() ? 1 : 0}`);
      // ★ 2026-10-19（用户用不了 hdc）：同一条诊断也写进**应用内运行日志**
      //   （设置 → 播放/关于里那块"运行日志"，`AppStorage['lxPlayLog']`），
      //   用户截图就能把 `t / anchor / big / win / cover / float` 全带回来。
      //   `rect=` 是**浮层封面的最终矩形**（x,y,size,height）：t=1 时它必须是 48.7 的小方块，
      //   `rv=` 是 `realCoverVisible()`（真封面是否该显示）—— 这两个数一起看就能判定
      //   "是浮层没缩小" 还是 "真封面没让位（两张封面同时在）"。
      const rect: LyricMorphRect = this.coverLocalRect();
      appendPlayLog(`[歌词页] t=${this.lyricMorphT.toFixed(3)} ${this.expandState.lyricDiagLine()} ` +
        `rect=${rect.x.toFixed(0)},${rect.y.toFixed(0)},${rect.size.toFixed(1)},${rect.height.toFixed(1)} ` +
        `rv=${this.expandState.realCoverVisible() ? 1 : 0} ` +
        `br=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
        `ms=${this.expandState.morphSessionDriving() ? 1 : 0} ` +
        `hs=${this.expandState.hdsBarSuppressed ? 1 : 0} ` +
        `pp=${this.expandState.playerPaints() ? 1 : 0} ` +
        `op=${this.expandState.morphOverlayProgress().toFixed(2)}`);
    }
    // 闁荤姳鐒︽刊鑺ュ緞?濠电姴锕ラ懝鐐叏閳哄倻顩风€广儱鎳忛煬顒勫级閳哄倻顬兼い?闂佹寧绋戦悧鎰帮綖?`lastScrollAtMs` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粣妤呮煢閳ь剟鎸婃径灞炬瘞闂婎偄娲ら幊姗€濡磋箛鏇熷闁宠　鍋撶紓宥呮噽缁辨帒鈻庨幘顖氫壕闁归偊鍓氭慨搴ㄥ级閳哄倻鈽夐悗瑙勫▕閺?
    // ★★★ 2026-10-17（③ 照搬无界：`PlayerPage.onContentDidScroll` = `wujie.pa:190026-190075`）
    //   上游这个**逐帧**回调里只写 `swiperProgress`（= p），外加一句
    //   `if (p > 0.5 && !chromeHidden) { showChrome(); }` —— **一处都不写"当前第几页"**；
    //   页码只由 `onChange`（`wujie.pa:190080-190110`）与落位动画结束决定。
    //   本仓前两轮都错在"在这个回调里写索引"：SDK 原文说 `onContentDidScroll` 对视口内
    //   **每一页**逐帧回调 ⇒ 落位那一帧只要有一帧 selectedIndex/index 是 0，索引就被写回 0
    //   ⇒ `canHideLyricChrome()` 恒 false ⇒ 控制区永远收不起来。
    //   现在这里只留滚动时间戳（`syncLyricMorphToPage` 用它做 settle 窗口判定）。
    this.lastScrollAtMs = Date.now();
    // 缂備椒绌堕崹鍦閳哄啯濯奸柟宄拌嫰椤︹晠鏌ㄥ☉妯荤秮onContentDidScroll` 闂備緡鍋呴崝鏇㈠箮濮樿埖鐒鹃柣锝呯灱閼?`index`闂佹寧绋戦張顒勬儊?`onChange` 闂佸搫娲﹀娆掋亹閺屻儲顥堥柣娆忔噽缁€?
    // ⚠️ 本函数**不再**写 `playbackSwiperIndex`（前两轮就是在这里写索引 ⇒ 收不起来）。
    // 闂傚倸鐗婇悷锕傤敆濞戞氨鍗氭い鏍ㄧ矊娴狀垶鏌涜箛鏃傜煀缂併劍濞婇弫宥咁潩閾忣偆銆婇柡?0.5 婵炴垶鏌ㄩ鍛村箖濡ゅ懎绠?`t` 闂佽В鍋撻柦妯侯槺閺嗕即鏌涢幒鎾寸凡缂傚秴顑夊畷婊冾吋婢跺牃鍋撴径灞稿亾閻㈠灚鍤€缂併劍鐓￠幆鍐礋椤撗傜磽闂?
    // 闂佹寧绋戝濉粂ncLyricMorphToPage()` 闂佸憡鍔曢幊姗€宕曢幘顔惧祦闁稿本绮庨幖濂告煥濞戞ê顨欑紒妤佺墬椤︿即鎮欐０婵囨杸婵炴垶鎼╅崢铏圭箔婢跺顕辨慨姗嗗幖閳敻鏌￠崒銈呭绩閽樼喖姊婚崒婵囧涧缂?
    this.syncLyricMorphToPage('scroll');
    // 闂佸搫鍟版慨鐑藉疾椤愶箑瑙﹂悘鐐佃檸閸庛儵鏌ㄥ☉娆戭暡缂侇噯闄勫濠氬炊瑜嶇壕鍦磼鐎ｎ亶鍎忔慨妯稿姂楠炲孩绻濋崘銊ょ帛闂佸憡甯熷▔娑氫焊椤栫偛鑸归柕鍫濇噹濮ｅ鏌℃径鍫濆姷缂佽鲸鐛媍hromeHidden` 婵炴垶鎸搁幖顐ｇ閿濆绫嶉柤鎼佹涧椤ゅ懘鏌涢悙顏勨偓褏妲?
    // 照搬无界同一处：`if (p > 0.5 && !chromeHidden) { showChrome(); }`
    // （只唤出，**不**在这里续 5s 定时器 —— 上游的 startIdle 只在 onChange / 点歌词时调）。
    if (this.lyricMorphT > 0.5 && !this.chromeCollapsed) {
      this.showChrome('scrollProgress>0.5');
    }
  }

  /**
   * 闂?闁诲繐绻嬬欢姘焽閺夋５褰掝敊閼测晜鍕炬俊鐐差儑閸嬬娀銆侀幋鐐翠氦婵炴垶锚椤?**闁诲酣娼х紞濠勭礊閸儱绀嗛柡澶庢硶缁夊ジ鏌涢幘宕囆ч柕?* 闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥粔宕囨妞嬪孩灏?闂佸憡鐟﹂崹褰掑极閹惧瓨浜ら柛銉椤忚鲸绻涢崱蹇撳⒉缂侇噯绠撳畷?闂?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*婵烇絽娴傞崰姘跺极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓張顒勬偤閺囩姵瀚氱€广儱顦埀顒€顦辨禍鍛婄瑹閳ь剙顭囬弶搴撴煢闁炽儱鍟跨紞渚€鎮樿箛鎾剁鐟滅増妫冨畷鐑藉Ω閿旂偓鎲欓柣鐘叉搐缁夊磭绮崒鐐搭棃妞ゎ偒鍏橀崑?*闂?
   *
   * ## 闂佹椿娼块崝宥夊春濞戙垺鍎嶉柛鏇ㄥ櫘濞煎酣鎮楅悽闈涙珢缂佽鲸鐟╁畷姗€宕橀懠顒佹瘞闂佽鍎稿鍥╊槴
   * 闂佽鎯屾禍婊兠瑰鈧弻?*濠殿喗绻傞懟顖炲箖?濠殿喗绻傞張顒佹櫠?濠殿喗绻傞惌渚€鎯佸┑鍡╂桨闁挎繂妫欓悗顕€鏌￠崟闈涚仩閻㈩垰娲畷鐑藉Ω閵壯勵唸闂傚倸鐗滃鈧紒妤€鍊块幆?* 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯?*闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏㈩焾娴滄繂鈽夐幘顖氫壕缂備焦妫忛崹鍐测枔閹存緷褰掝敊閼测晜鍕炬繛杈剧到缁夊爼鎮?*
   * 闂佹寧绋戦悧濠囨偤閺囥垹瑙︾€广儱鎳忛煬顒勬倶韫囧海绐旀繛鑲╁缁嬪鈧綆鍋呴悡?`META_GAP_BELOW_COVER(50)`闂侀潧妫旂粈渚€鎯冨┑瀣棃闁靛繆鍓濈瑧闂佽桨绀侀顓㈡偘閵夆晜鐒介柨婵嗗椤忓崬霉?331闂佹寧绋戦ˇ顓㈠焵?
   * 闂佸吋婢橀張顒勬偤閺囩姵瀚氱€广儱妫崝鈧梺?*閻庤鐡曠亸娆戝垝閿熺姴鍙婇柛鎾椾椒绮甸梺鍛婂灩閸庛倕顭囬崹顐ゎ洸?*闂佹寧绋戦悧鎾诲磻閸涘瓨顥嗛柍褜鍓涢幉?swiper 闂侀潻璐熼崝搴敄?2 婵＄偑鍊楅。顔炬濮樿泛违?
   * 闂?婵炴垶鎸堕崐鎾斥枎閵忥紕顩查悗锝庝簼閸婇亶鏌￠崘顓炵厫闁搞劍姘ㄧ划鈺冣偓锝庝簻濞懷囨煛閸繍妲风紒鏂款嚟缁柨顓奸崺鎸庡浮閺屽本绻濊箛鏇犵崶**婵＄偑鍊濆褔宕硅箛鏃傤洸闁糕槅鍘剧粈澶嬬箾閹碱厼鏋涢柣顏呮緲閳讳粙妾辩紒?*闂佹寧绋戦悧鍡欑玻濮椻偓瀵?`edge=331 t=0.00` 濠殿喗绻愮徊鎯ｉ崫銉㈠亾閻熸澘鏋︾紒杈ㄥ哺婵?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箓閺傃囨煛婢跺牆鍔ゆ繛鍫熷灴瀹曟ê鈻庨幇顔衡偓濠偯归崗鑲╊暡缂?
   * `lyricMorphT` 闂佹眹鍔岀€氼剟寮鐣屸枖闁逞屽墯閵囨瑩宕￠悙娈嬫鏌ｉ幇顖ｆ綈婵?`.onAnimationStart`闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎮鹃悩鍨殰闁挎棁娉曢鍗炩槈閹垮啩绨婚柣锛卞洤纭€?
   * 闂?*閻庤鐡曠亸娆戝垝閿熺姴鎹堕柕濞у嫮鐛ラ梺鍝勭Т濞差參濡存径瀣洸闁糕剝顨嗛惃鎴︽偣閸濆嫮鏋冪紒?*闂佹寧绋戝濉眓dex === targetIndex`闂佹寧绋戦ˇ顓㈠焵椤掆偓缁夋煡鍩€椤掆偓閸婇鑺遍鍕強妞ゆ牗鑹惧☉褔鎮烽弴姘鳖槮闁搞値鍙冮幃?
   * "閻熸粎澧楅幐鍛婃櫠閻樼偨浜?= 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁绘劕鍘滈崑鎾存媴鐟欙絽浜?`lyricMorphT` 婵炲濮寸粔闈浳?0"闁哄鏅滈悷褔锝?*婵炴垶鎸哥粔宕囩博閹绢喗鍤婇悗闈涙啞閻ｉ亶鏌涢幒鎾剁畵妞ゎ偅鍔欓獮鈧?*闂佹寧绋戦懟顖氼潩閵娾晛绀冪€广儱瀚惁宥嗙箾鐏炵澧叉繝鈧担鍦浄閻犱礁纾粔鍨槈閹惧鐭庨柕鍫熷鐎电厧顫濋鈧粻闈浨庨崶璺烘灍妞ゆ帗绮庨埀顒傛嚀閸犳稓妲?
   *   閻?闁哄鏅滅粙鎺楀箰闁秴缁╅柟顖嗗嫮褰滈梺鍝勫暞閸庤偐鈧哎鍨诲Σ鎰板閻樼數鈹涢悗鍦焾瀵泛危?1闂佹寧绋戦悧鍛箔閸屾稓鈻旈柍褜鍓氬?`onAppear` 婵犮垼娉涚粔宕囩礊閸涱喗浜?0闂侀潧妫旈悞锕傚垂閵娧勵潟闁靛繒濮风粚鍧楁煛婢跺牆鍔ラ柛銈嗙矒瀹曟岸顢曢姀鈺傂熼梺鎸庣☉椤︻偊宕?闁诲海鎳撻悧鍡楃暦婵傚憡鍎庨悗娑櫭径宥夋偣閸濆嫮鏋冪紒璇插暣閺?
   *   閻?闂佺厧鎼崐濠氬磻閿濆鐓傜€广儱鎳愮槐锕傛煕?`onAppear` 闂?`lyricMorphT` 閻熸粎澧楃敮鎺楀春?閻熸粎澧楅幐鍛婃櫠閻樼偨浜滈梻鍫熶緱閸ょ娀骞栫€涙ɑ鈷掓繛鍫熷灩缁晠顢涘鍐у寲"闂佺偨鍎查弻锟犲焵?
   *     闂?*閻熸粎澧楅幐鍛婃櫠閻樼偨浜?*闁哄鏅滈悷銈夋煂濠婂牆纾归柛蹇撳悑閹烽亶妫呴澶婁函閻庢哎鍨虹粙?swiper 闁诲骸婀遍崑銈咁瀶椤栫偛纾绘繝濠傛噺閻ｅ崬顪冮妶鍛倎缂佹顦扮粙澶愬焵椤掑嫭鍤婇弶鍫濆⒔缁€澶屾喐閻楀牆绗掗柛銈庡弮瀵爼濡疯閻ｉ亶鎮樿箛姘跺摵婵″弶鎮傞弻銊モ枎閹寸偟鏆犵紓浣规閸ㄦ娊宕戦敐澶娢?
   *
   * ## 濠殿喗绻愮徊鍧楀灳濮椻偓閹啴宕熼銏犵稑缂備緡鍨槐顔炬濞嗘挸纭€闁哄洦姘ㄩ閬嶆煟椤忓棗鏋戠紒顭戝櫍閺?
   * ```
   *   playbackSwiperIndex闂佹寧绋戦悧鍡欑礊鐎ｎ喖绀堢€广儱顦埀顒€顦甸弫? 闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍛婂姇閸熷潡鎮炬ィ鍐ㄧ厴闁逞屽墴閸╃偤鍩€椤掑嫬鐓? lyricMorphT 闂?*闂傚倸鐗婇悷锕傤敆濞戞氨鍗氭い鏍ㄧ矊娴?*
   *                                        闂? = 闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏㈩焾娴滄繂鈽夐幘顖氫壕缂備焦妫忛崹鐣屾? = 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垻顭堟禍婵嗏槈閹绢垰浜剧紓浣规閸ㄧ晫妲?
   *   濠电姴锕ラ崹鍨叏閳哄倹浜ら柛銉㈡杹閺屻倕鈽夐幙鍐ㄥ箻婵炲牊鍨归幃浼村Ψ閳哄偊绱甸梺鍛婄懐娴滄繂危?婵炲濮寸花鑲╃博鐎涙鈻旀い蹇撴－娴煎倿鏌ｉ幇顕呮敯闁炬柨顑夊畷姘跺级閸喚绋愭繛鎴炴尨閸嬫挸鈽夐幙鍐х敖妞ゅ浚鍓熼幃?闂?
   *   闂?*闂傚倸鐗婇悷锕傤敆濞戙垹绠?*濠殿喗蓱閻℃洜鎹㈠▎鎴犻┏濠㈣泛顦遍懝?閻熸粎澧楅幐鍛婃櫠閻樼偨浜滈梻鍫熶緱閸ょ娀骞栫€涙ɑ鈷掓繛鍫熷灩缁晠顢涘鍐у寲"闂?
   * ```
   * 闂?闂佸搫鐗滈崜姘跺蓟閻斿皝鏋栭柡鍥╁仦閻ㄦ垿鏌￠崟闈涚仸闁稿鎳樺鍫曞灳閸愭彃缍樼紓渚囧灥瀹曢潧鈻撻幋鐘亾閸︻厼浠ф鐐叉喘閺佸秴顫濇潏鈺佺秳闂佸憡顨夊▍鏇熶繆?`t` 缂傚倸鍠氶崰鏍春瀹€鍐︿汗闁规儳鍟块·鍛渻閵堝娑фい鏇ㄥ枟閹棃寮崒娑氭殸缂備焦妫忛崹鎶藉磻閿濆鏅柛顐ｇ矌閻熸繈鏌涢弬璇插闁轰線绠栭弫宥嗗緞閸艾浜?
   *   閻?婵炴垶鎸哥€涒晝鍒掗敃鍌氱闁靛鍊涢崢顒勬煟閵娿儱顏挊鐔兼⒒?*婵炴垶鎸哥粔鎾疮鐠恒劎鐜?*闂佹寧绋掓穱楦挎＂闂傚倸鍊瑰娆掋亹瑜斿畷?`lyricMorphVisible === true`闂佹寧绋戦悧鎾凰夐敐鍥ㄥ仒閻忕偠澹堥崢顒勬煥濞戞﹩妲规俊鐐插€块獮宥咁吋閸℃鐣抽梺瑙勬緲缁诲绮婚悢鍏兼櫖?
   *     闂佸吋婢橀張顒€锕㈡导鏉戞閻熸瑥瀚妴濠囨煕濞嗘ü绨绘繝鈧?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夘棑閻熸捇鏌涘▎鎰仼妤犵偛娲︾粙澶婎吋閸曨収浼囬梺?闂佸搫鍟崕濂革綖閿旂偓瀚柛鎰典簼閺嗗繘鏌ㄥ☉妯煎ⅲ妞ゎ偄妫涢幏顐﹀礃椤忓懏娈㈤梺缁樺姉濞呫垻妲愬璺何?
   *   閻?濡ょ姷鍋涢崐濠氭偤閹达附鏅慨姗嗗墮閸ゆ帞绱撴担鍝ョ婵犫偓椤忓嫷娼伴柨婵嗘礌閳ь剚顭囩划鈺咁敍濠婂啩鍖栭梺鍝勫暢濞夋盯宕幘璇茶Е閻忕偠鍋愰鍗炩槈閹垮啩绨婚柍褜鍓涢妴瀣濠靛洨鈻旂€广儱鐔嗛弴銏犵煑闁瑰瓨绮嶅畷鎻捗归敐鍡樼闁革絽鎽滅槐鎺懳熼悜妯锋灆閻庢鍠栭崐鍫曞焵?
   *
   * 闂佸疇娉曟刊瀵哥箔?闁荤姴顑呴崯浼村极閵堝鍊烽柣褍鎽滅粣姊巃boutToAppear()`闂佹寧绋戦悧鎾诲Υ婢舵劖顥堥柕蹇娾偓宕囨Ц闁哄鍋犳慨銈咁渻閸屾壕鍋撻棃娑氱Ш缂傚秴鐗婄粙澶愬焵椤掆偓閳诲酣鍩ラ崨顖滎槴婵炴垶鎸告鎼佸船鐎电硶鍋撻崷顓熷殌闁?`.onAppear()`
   *    闂佹寧绋戦悧鎰繆椤撱垺鍊烽柣鐔告緲濮ｅ鏌ｅ鍛暭婵＄偛鍊婚埀顒勬涧缂嶅﹦绱為崼鐔衡枖闁逞屽墮閳诲酣鍩ラ崨顖滎槴闂?*婵炴垶鎸哥粔鐑姐€?*闂佽　鍋撻柟瑙勫姉缁犵粯绻濇繝鍐ㄧ仴濠殿喒鏅犲畷鍫曟倷閸撲焦顔嶉梻浣瑰絻閻妲愬▎鎾寸劷闁挎繂瀚粣妤呮煙閸偅灏伴柡灞芥川閹即濡烽埡鍌︾吹闂佹寧绋戦ˇ顓㈠焵?
   * @param reason 闂佸憡鐟禍鐐哄极閵堝棛顩查幖娣灪閿涘鐓崶顭戞缂佽鲸鐛媌oot` / `appear`闂?
   */
  /**
   * 重发「歌词页终点几何」——**逐条照搬上游** `PlayerPage.publishMorphTargets`
   * （反编译 `wujie.pa:175872-175935`，逻辑还原见下）。
   *
   * 上游反编译原文（`a2` = 快照）：
   * ```ts
   *   if (swiperProgress > 0.02) return;                 // 只在"停在封面页"时重发
   *   if (!isMorphTarget()) return;                      // 只有目标是歌词页才需要
   *   if (swiperBoxH <= 0 || metaH <= 0) {               // 几何还没量到
   *     if (publishRetries < PlayerPage.PUBLISH_RETRY_MAX) schedulePublishRetry();
   *     return;                                          // ← 带**有界重试**
   *   }
   *   expand.scaleValue = …; expand.translateX = …; expand.translateY = …;
   * ```
   * ⇒ 上游之所以"打断动画后再打开也正常"，就是因为**每一帧停在封面页时都会把终点几何
   *   重发一遍**，而且量不到时有 12×32ms 那样的重试。本仓原来只有"打开时上报一次"，
   *   打断后重开、大封面矩形与上一轮完全相同 ⇒ `onAreaChange` 不再触发 ⇒ 几何停在 0
   *   ⇒ `lyricCoverSizeOf()` 为 0 ⇒ 歌词页封面不缩。
   *
   * 本仓对应物：`expandState.lyricCoverSizeOf() > 0` = 几何就绪；
   * 重发动作 = `expandState.resyncBigCoverAnchor()`（量一次大封面并回填 `bigSize`）。
   */
  private publishLyricMorphTargets(): void {
    // 上游第一道闸：只有停在封面页（进度 ≈ 0）才重发。
    if (this.lyricMorphT > 0.02) {
      this.publishTargetRetries = 0;
      return;
    }
    // 上游第二道闸 `if (!isMorphTarget()) return;` 的语义是"本页是不是形变的目标（展开态）"，
    // 而我们这个方法就写在 `PlaybackPage` 里 —— **本页在渲染就一定是目标** ⇒ 等价于不过闸。
    // ⚠️ 不能拿 `lyricMorphTarget` 来顶：那是"目标 Swiper 页是不是歌词页"，停在封面页时它是 false，
    //   而重发终点几何**恰恰只在封面页静止时**才需要（上游第一道闸就是 `swiperProgress <= 0.02`）。
    // 几何已就绪 ⇒ 不用重发。
    if (this.expandState.lyricCoverSizeOf() > 0) {
      this.publishTargetRetries = 0;
      return;
    }
    // 还没量到：有界重试（上游 `publishRetries < PUBLISH_RETRY_MAX` ⇒ `schedulePublishRetry()`）。
    if (this.publishTargetRetries >= PlaybackPage.PUBLISH_RETRY_MAX) {
      return;
    }
    this.publishTargetRetries = this.publishTargetRetries + 1;
    Logger.info('RzdLyricFloat',
      `publish targets retry=${this.publishTargetRetries}/${PlaybackPage.PUBLISH_RETRY_MAX} ` +
        `t=${this.lyricMorphT.toFixed(3)} coverSize=${this.expandState.lyricCoverSizeOf().toFixed(1)}`);
    setTimeout((): void => {
      if (!this.isAlive) {
        return;
      }
      this.expandState.resyncBigCoverAnchor(this.getUIContext());
      this.publishLyricMorphTargets();
    }, PlaybackPage.PUBLISH_RETRY_MS);
  }

  private syncLyricMorphToPage(reason: string): void {    const want: number = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闁荤姳璁查弲娆戠礊閸涱垳纾兼繛鍡樻尨閸嬫捇骞囬浣割潛闁哄鏅滅粙鎴犫偓?*闂佹寧绋戦惌渚€锝?`lastScrollAtMs` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煥?
    //   `onContentDidScroll` 濠殿喗绻愮徊钘夛耿椤忓牊鐒婚柟閭﹀墯婵酣鏌?`lyricMorphT` 闂佸搫鍟抽鎰濠靛洦浜ゆ繛鍡樻尭濞?*婵炴垶鎸哥粔鐑筋敊韫囨稒濯伴柦妯侯槺閺?* 闂佺偨鍎查弻锟犲焵?
    //   闂佸憡鐔粻鎴﹀垂椤栨稓鈻旈柕鍫濈墐閸嬫捇宕ㄩ鐐栭柣銏╁瀻閸屾粓鐎洪梺鐑╂櫅閹测剝鎱ㄩ悩璇茬９缁绢參顥撶粈鍕節婵犲啫鐏ラ柛鈺佹湰缁嬪鍩€椤掑嫬纭€濠电姴鎷嬪璺衡槈閹绢垰浜鹃梺纭呮硾閿曘劑顢欓弴銏犵闁规鍣导鍌炴煟?闂?闂佹眹鍨归…宄邦焽閹殿喗宕夌紒娑樻贡缁€鍡涙煏?
    //   闂佸疇娉曟刊瀵哥箔?`boot` 闂備緡鍙忕徊楣冾敃?*闂婎偄娲ら幊姗€濡磋箛娑樼哗闁硅鍔﹂弨?*闂佹寧绋戦悧鎾诲Υ婢舵劖顥堥柕蹇娾偓宕囨Ц闁哄鍋犳慨銈咁渻閸屾稒浜ゆ俊顖濆吹濮婇箖鏌￠崼婵愭Х闁瑰箍鍨洪幏鍛村即閻旂儤纭﹂梺鍛婃閻撳妲愬妾抋stScrollAtMs` 婵?0闂佹寧绋戦ˇ顓㈠焵?
    // ★★★ 2026-10-18（用户第十一轮：「滑到歌词页**封面不变小**」）：
    //   `swiperEnd` 就是"滚动已经结束"的权威事件，仲裁窗只该拦**滚动进行中**的 sync。
    //   原来它同样被 `lastScrollAtMs`（`:1691` 每帧刚盖过）挡掉 ⇒ 唯一能把 `lyricMorphT`
    //   钉到端点 1 的那条路 100% 失效，封面尺寸只能靠 SDK 逐帧 position 的末值（常停在 0.997 甚至更小）
    //   `⇒ 封面永远大`。上游没有这条窗口：它唯一写进度的就是逐帧回调（`wujie.pa:190026-190049`）。
    if (reason !== 'boot' && reason !== 'swiperEnd' &&
      Date.now() - this.lastScrollAtMs < PlaybackPage.SCROLL_SETTLE_WINDOW_MS) {
      return;
    }
    if (Math.abs(this.lyricMorphT - want) < 0.0001) {
      return;
    }
    Logger.info('RzdLyricFloat',
      `sync to page reason=${reason} index=${this.playbackSwiperIndex} want=${want} ` +
      `from=${this.lyricMorphT.toFixed(3)}`);
    this.lyricMorphT = want;
    this.lyricMorphTarget = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
    this.lyricSwiperSettled = true;
    this.lyricFlightSettled = true;
    this.lyricMorphVisible = false;
    this.lyricMorphOpacity = 1;
  }

  /**
   * 闂佽　鍋撻悹楦挎閸熸煡鏌ㄥ☉娆戞憘wiper 闂佺厧顨庢禍婊呮崲娓氣偓閹啴宕熼銏⑩偓濂告煙楠炲灝鐏╁┑顔规櫊閹晫鎷嬪畷鍥╂喛濠电偞鎯岄崰鏍儑閻楀牜妲归柣鎰邦杺閺€?*闂備緡鍠氶弲顐ゅ垝閵娾晛绾?*婵炴垶鏌ㄩ鍛村箖濡ゅ懎绠ョ€广儱鎳庣粊濠氭煙?婵＄偛顑囬崑鐘汇€侀幋鐐碘枖?闁哄鏅滈悷銈囩博閺夋埈娴栭柨婵嗗暊閸?
   *
   * 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯?*婵炴垶鎸哥粔闈浳?*闂佺娉涢敃銈夋儍濠靛顥堟い顐幘椤忛亶鏌涢幒鍡椾壕闂佸憡甯掑ú锔炬暜閳ь剟鏌ㄥ☉娆戭暡閻犲洨鍋熸禒锕傚磼濞戞?*闁汇埄鍨遍幃鍌炲煘?*闂佹眹鍔岀€氬摜妲愬┑瀣闁瑰瓨甯炵粔鎾煕濮橆剛鍑圭紒顔界洴閹?`playbackSwiperIndex`
   * 闂佸憡甯掑Λ娆撳极椤曗偓瀹曟﹢宕橀懠顒佹瘞闁诲海鎳撻崯鎶藉箚閵堝鎹堕柕濞垮劜閹插灝鈽夐幙鍐х敖妞ゅ浚鍓熼幃娆撴儌閸濄儳顦╁┑顔界箓閻線鎯佸┑鍥ヤ簻闁汇垹鎲℃顖涙叏濠靛嫬鐏柍褜鍏涘鎺斿垝濞戙垺鍊块柟顖炲亰濞诧綁鏌￠崟顐⑩挃闁靛洦宀搁弻鍥晲閸涱垳鍊為柣蹇撶箰缁绘劙鎯冨┑瀣棃?+ 濠殿喗绻傞懟顖炲箖閺囥垺鏅璺虹墐閸?
   * 闂佸憡顭囬崰鎰焽閻㈠憡鍎嶉柛鏇ㄥ亜閺呭憡绻涙径瀣婵?`lyricMorphVisible = false` 闂佸搫鍟版慨闈涱焽椤栨稓顩烽悹鍝勬惈閺呭憡鎱?闂?闂佽桨鐒﹀娆撱€冨鍐炬桨鐎光偓閸愵亝袚婵＄偑鍊濆褔鎯冨┑瀣棃闁靛繒濮鹃崺宀勬煕濞嗘兛鎴澪ｉ幖浣哥鐎规洖娲︾徊濠氭煟閵娿儱顏ラ柍?
   *
   * ## 闂佸疇妫勯幊澶娢?2026-10-16闂?*閻庣懓鎲¤ぐ鍐垂閻ｅ备鍋撶憴鍕叝閻犳劗鍠庨～銏㈡媼閸愬弶鏆曢梺娲诲枙缁躲倗妲愬┑鍥┾攳婵犻潧鐗婂▓灞解槈閹惧磭孝闁?*闂?
   *
   * 婵炴垶鎸堕崐鎾绘煂濠婂牊鍋犻柛鈩冪懄閺嗙娀鏌ㄥ☉妯肩劯闁稿繑锕㈠浼搭敍濞戞凹浼曢梺缁樺姉閹虫捇宕甸銏犵骇闁靛／鍕殸闂?
   * 1. 闂佸搫鐗滈崜娆撳吹闁秴鏋侀柟宄扮焾濞诧絾鎱?`lyricSwiperSettled && lyricFlightSettled` **婵炴垶鎸堕崐婵單涢崼鏇熺劸闁芥ê顦悡鍌毭?*闂?
   *    闂佸吋婢橀惉濂告偪?`lyricFlightSettled = true` 闂?*闂佸摜鍎愰崹顖滅博?*闂侀潻濡囨晶妤呭蓟閻旂厧鍌ㄩ柣鏂挎啞闂勫秹鏌?`animateLyricMorph()` 闂佹眹鍔岀€氼參寮崷顓濈剨?
   *    `setTimeout` 闂?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊濂告煂濠婂牆妫橀悷娆忓閵嗗﹪鏌￠崼顐㈠⒉闁汇倕妫楅蹇涘蓟閵夛富鍚?闂佽　鍋撶痪顓炴噽缁犲骞栨潏鍓х暤闁崇懓绉瑰畷?婵炴垶鎸撮崑鎾绘偣瑜嶉崲鏌ュ垂瑜版帗鈷旈柕鍫濈箳缁€鍕偡濞嗗海鍔嶉柡瀣暞缁傛帡寮甸悽鐢垫啰闂佸搫鍊哥紞濠囧磻閸涱厸鏋斿ù锝呭枤閸ゆ盯鏌￠崟顐㈠毐缂?
   *    闂?`lyricFlightSettled` 濠殿喗蓱閻℃洜鎹㈠▎鎾冲強?`false`闂佹寧绋戦悧鎾斥枍鎼淬劍顥?`syncLyricMorphToPage()` 闂佽В鍋撻柦妯侯槺閺嗕即鏌￠崘銊ヮ暢闁汇倕妫濋幆鍥偆閸屾粎顦?
   *      婵炶揪绲藉Λ婵嬪磻閸涙潙绾ч梽鍥儗閻愵剛鈻?`lyricMorphVisible` 閻庤鐡曠亸娆戝垝閿涘嫭鍋栨い鎰╁灮閺嗗﹪鏌ゆ總澶夌盎缂佽鑳剁槐鏃堫敊閽樺浜?`false`闂?
   *    闂?闂佸搫鐗滈崜娆撳吹闁秴鏋?*闂婎偄娲ら幊鎰板礉瑜斿畷鐑藉Ω瑜滈崕鎴濃槈閹绢垰浜炬繛?`if` 婵犮垼娉涚€氼垳鎹㈤幋锕€鐐?*闂?
   * 2. 闂佸搫鐗滈崜娆撳吹闁秴鏋侀柡澶婄仢濞懷囨煕?`lyricMorphVisible` / `lyricMorphOpacity` 婵炴垶鎸堕崐鎾绘煂濠婂應鍋撳☉娆樻畷妞ゆ柨鐭傞弫?
   *    闂佸吋婢橀惌浣烘崲閺嶃劎鈻旈柕鍫濆閸ゅ鎮楀☉娆樻畷妞?*闂佺粯绮嶅妯猴耿椤忓牆鐭楁い蹇撴祩濞煎墎鈧灚濯芥慨銈夋偉閿濆洦瀚?*闂佹寧绋戦悧鍡涘矗韫囨稒鐒鹃柕濠忓鍟搁柣鐘冲姇濠€閬嶅磻閿濆拋鍟呴柛娆忣槺椤忔悂鏌ｉ幇顔筋仧缂佽鲸宀搁崺?闂佸憡顨呴崢鏍ㄧ箾閸モ斁鍋撻悷鏉挎殺缂佹劕娲畷姘紣娴ｅ搫鏅╂繛鎴炴⒒閸犳劙鎯€閸涙潙瀚夊璺侯儓椤╊偊鏌＄仦鐐碍濠靛倹鐗犲畷顐㈩吋閸愶絽浜?
   *
   * 闂?婵烇絽娲︾换鍕汲閳ь剟鏌ら弶鍨殭缂佹顦靛畷姘舵偐閸偆鏆犻梺鑽ゅ仜濡盯寮柆宥嗘櫖婵﹩鍓涢弳濠囨煛?婵炴垶鎸堕崐婵單涢崼鏇炵闁斥晛鍟·?闂備緡鍙忕徊浠嬨€冨鍛闁硅鍔﹂崥鈧梺姹囧妼鐎氼參寮崷顓濈剨闁告挆灞肩磽闂?*闂佸吋鐪归崕閬嶆儍閵忋倕绾ч柕澶涚細閸掓帒顭跨捄铏剐ラ挊鐔兼⒒閸屾稒灏﹂柍鐟扮Ч瀹?*
   *    闂佹寧绋戦悧鍛閵夛缚绻嗛柛灞捐壘缁叉椽鏌ｅ鍕€滅紒缁樕戦幆鏃堟晝閸屾鏁甸梺鍛婃煟閸斿苯锕㈤鍫濊摕闁归偊浜崵瀣煛閸繃鎯堥柣搴ㄦ敱缁嬪绻濇担铏规喒闂佸憡鐟崹鎶藉极閵堝鏅鑸靛姈娴犳﹢鎮烽弴姘鳖槮闁伙絿濮电粙澶愬焵椤掑倹灏庨梺鍨儎閸掓帒顭跨捄铏光枌缂?
   *    闂佸憡甯炴慨宕囪姳閿涘嫪鐒婇柛妤冨仧缁讳礁霉?git 闂佸憡锚濡銇愰崼鏇熺厒閻忕偞鍎抽懜褰掓煏?*闁诲海鎳撻崯鈺冪箔婢跺顕辨慨姗嗗幗缁犳帡鎮?*闂佹寧绋戦悧鍡欐崲閳ь剟鏌ｉ幒鏇炵厫婵☆偒鍙冮弻鍛村焵椤掑嫬违濞达綁顥撻悷顒勬煕濞嗘ü绨婚柛鐔告尭椤曘儵鎳為妷褍鐏遍柣鐘叉穿瀹曢潧鈻撻幋鐘亾濞戞瑯娈曟い鏂跨焸閺佸秵寰勯崼姘壕?
   * 闂佸疇娉曟刊瀵哥箔?闂佸吋鐪归崕鎶藉灳濡吋濯奸柕鍫濈墢缁犲骞栨潏鍓х暤闁崇懓绉瑰畷婵嬪Ω椤儲姊婚埀顒冾潐閻旑剛妲愬┑瀣煑妞ゆ牗鐟ょ花浼存煙鐠虹尨宸ラ柣?+ `lyricSwiperSettled` / `lyricFlightSettled` /
   *    `LYRIC_MORPH_DURATION_MS` **闂佽桨绀侀顓犲垝瀹ュ绀嗛柣妯哄暱缁?*闂?
   */
  private finishLyricMorph(gen: number): void {
    if (gen !== this.lyricMorphGen || !this.lyricSwiperSettled || !this.lyricFlightSettled) {
      return;
    }
    this.lyricMorphVisible = false;
    this.lyricMorphOpacity = 1;
    Logger.info('RzdLyricFloat',
      `flight settled gen=${gen} toLyric=${this.lyricMorphTarget} ` +
      `t=${this.lyricMorphT.toFixed(3)} index=${this.playbackSwiperIndex}`);
  }

  /**
   * @returns 濠电偞鎯岄崰鏍儑娴煎瓨鐓傞悘鐐垫櫕濞堥亶姊婚崼娑樼伄婵炲牊鍨剁粙澶愬焵椤掑倹鏆滅憸蹇涙偂閳哄嫨浜规い顐枤缁€鍓塸闂佹寧绋戦惉濂告偘閵夆晛鐭楅柨婵嗘噺缂嶅繘鏌″鍛カ缂佽鲸宀告俊?
   *
   * 闂佸疇娉曟刊瀵哥箔?2026-10-15闂佹寧绋戦悧蹇涱敄?2 闂佺鍕垫▌闁汇値鍨煎ú顒勬煟閳哄倻澧柣顏呭缁辨帡鎮㈤崜渚囦紘闂?*闂佸憡甯炴慨鐢垫暜閳ь剙霉濠婂啯顥欑紒妞剧劍缁嬪顢旈崟顐㈡濠殿喗绻嗗畷闈涒枔閹寸姷鐭撳ù锝堫潐缁犳帡鏌￠崒婵愭綈缁?*闂?
   *   閻?`lyricFloatActive()` 闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐ゆ暜椤愶箑绾ч柕澶涢檮绗戝┑鐐存儗閸犳牠鎯囨导瀛樺剭闁告洦鍨遍敍宀勬煥濞戞澧曠憸鎶婂洤鎹?婵＄偛顑囬崑鐘汇€侀幋鐐碘枖?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻?闂佸綊娼х粔鍫曞极妤ｅ啯鏅鑸电〒楠?
   *     闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本绋掗弳顓㈡煙?*闁汇埄鍨遍幃鍌炲煘?*婵炴垶鏌ㄩ鍛村箖濡も偓閳讳粙鍩勯崘鈺冪暢婵炲濮鹃濠勭礊瀹ュ洦瀚柛鎰典簼閺嗗繘鏌ｉ幇顒傜暛闁?
   *   閻?`lyricFloatMetaOpacity()` 闂佺偨鍎查弻锟犲焵?闂佸憡顭囬崰鎰焽閻㈠灚濯奸柍鍝勫€婚幗鍐煕濮橆剛孝婵犫偓?`t=0` 闁诲海鎳撻懟顖炲矗韫囨稒鐒婚煫鍥ㄦ⒐椤牠鏌ㄥ☉妯煎ⅵ闁稿鎳忕粙澶愬焵椤掑嫬绀嗛悹鍥皺濞堥亶姊婚崼娑樼伈闁靛棗顦甸弻鍥晲閸曨偅鏆呭┑顔界箓閼活垶骞?
   *     闂?`MusicPlayInfoBlock` 闂佹椿婢€缁鳖喚妲愬鑸垫櫖婵炴埈娼块埀?0 婵炴垶鎸哥粔鎾疮閳ь剟鏌ｉ姀锝庡殭闁汇劍绻堝Λ?濠殿喗绻傞懟顖炲箖閺囩喓鈻曢悗锝庝簼閸婄敻鎮楅悷鏉挎殲濞存粏濮ょ粙?1闂?
   *   閻?`lyricFloatMetaWidth()` 闂佺偨鍎查弻锟犲焵?濠殿喗绻傞懟顖炲箖閺囥垹閿ゆ俊銈傚亾閻㈩垼鍋婂鍫曞Ψ閿旇棄鐦诲Δ鐘靛仜閸熷潡鎯囬搹顐も枖妞ゆ挻澹曢崑鎾存媴閻戞ɑ娈㈤柣搴ｆ嚀閸熶即鎮炬繝姘敜婵°倐鍋撴い鏃€妫冮弫?
   *     闂佺粯绮嶅妯猴耿椤忓牆鍙?*婵炴垶鎸撮崑鎾翠繆椤栵絼娴锋い?*闂佹寧绋戦悧鍡樼▕韫囨稑绀冮柛娑欏閻濆爼鎮归悜妯肩畼闁?`lyricMetaLeftInset()` 缂傚倷鐒﹂悷杈╂濮樿埖鏅悘鐐跺亹閻熸繈鏌涢幇顒傂ф繛鎾冲閹茬増鎷呴崫銉︽疁闂?
   *   闂佺儵鏅濋…鍫ュ矗瑜嶉埢鏃堝Ω閳轰焦鐝甸梻浣瑰絻閼活垶宕甸幒鎾翠氦婵☆垰鎼弲鎼佹煟椤愮喎浜?闂傚倸鍊堕崝灞斤耿?`lyricFloatActive()`"闂佹眹鍔岀€氼剙锕㈤幘顔兼鐟滅増甯掗崢瀵糕偓鐟版啞瑜板啫顫濋妸鈺佹嵍闁绘鐗婇弳顓熸叏濠垫挾绁烽柍?
   */
  private lyricFloatRect(): LyricMorphRect {
    return this.expandState.lyricMorph(this.lyricMorphT);
  }

  /**
   * @returns 闁诲繐绻嬬欢姘焽娴煎瓨鐒介柨婵嗗椤忛亶鎮?*闁诲骸婀遍崑銈咁瀶椤栨粍鍟哄ù锝囶焾閺呮悂寮?`.position()` 闂佹眹鍔岀€氼噣鎮￠埡鍕╀汗?*闂佹寧绋戝濡忛梺鎸庣☉椤︻參鍩€?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂侀€涘嫎閸婃洖煤閺嶎厼绠ｉ柟瀛樼矌閻熸劕鈽夐幘顖氫壕闂佺粯顨呴悧蹇撯枔閹达附鐒婚柛鈩冾殔缂嶄線鏌?*闂佹寧绋戦惉濂稿极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓懟顖炴儍濠靛顥堥柕蹇婂墲绗戞俊鐐差儑閸嬫盯宕哄畝鈧禒锕佺疀閹鹃鍟傛繝銏ｅ煐閻楁捇鍩€椤掆偓缁嬪嫮妲愬鑸垫櫖?
   *
   * 婵炴垶鎸搁敃锝囩博閹绢喗鍋嬮柛顐ゅ枎閻忓鏌涢敂鍝勫缂佺粯鐗犻弻灞界暆閸愵亝顔?`coverLocalRectFor()` 闂?闁诲繒鍋涚换鎰不閻戣棄閿ら柟閭﹀幘閸?闂?闁诲骸婀遍幊鎾斥枍閹烘瀚夋い鎺嗗亾婵犫偓閹绢喖閿ら柟閭﹀幘閸?闂佹眹鍔岀€氫即鍩€椤掆偓濡銇愭径鎰妞ゎ偒鍠氱粈?
   * 闂佸憡鎸哥粔浣冦亹娓氣偓瀵?**`.scale()` 缂傚倷鐒﹀ú鏍敊閹版澘闂柕濞垮€涢崢顒勭叓?*闂侀潧妫楅崐璇诧耿閿熺姴瀚夐弶鐐村閻熸劗绱撴担瑙勫鞍闁诲繐顦靛浼搭敍濮樿鲸顔堥梻?*婵＄偛顑囬崑娑㈠吹椤撶姳娌煫鍥ㄦ尵椤?*闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈夋煂濠婂牆绀堢€广儱妫楃徊褰掓煕閿斿搫濡芥繝鈧悧鍫㈩浄?*闂佸搫鍟犻弲娑橆潩閵娾晛瀚夊璺烘捣缁犳牕鈽夐幘顖氫壕濠电偛妫寸槐鏇烇耿閿熺姴瀚夐柛婵嗗閸愨偓闁?*闂佹寧绋戝濉祇rphCoverRectAt()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电偛绨遍崑?
   *   `LyricFloatLayer` 婵＄偑鍊曢悥濂稿磿?闂佸疇娉曟刊瀵哥箔?2026-10-15 闂佸憡甯炵划顖炲礈閻楀牏鈻旂€广儱妫欓弳?闂備緡鍙忕徊鑲╃博閺夋垟鏋旂痪鏉款槺缁€鍡涙煥?
   *   > 闂侀潧妫楅惌鍌炲焵椤掆偓濡銇愭径鎰闁靛繒濮电粈鈧俊鐐€濆褔宕幘顔奸敜闁归偊鍘鹃崹?闂佺偨鍎查弻锟犲焵?闂佹椿浜為崰鎰攦閳ь剛绱撴担瑙勫鞍闁?**闁诲繐绻嬬欢姘焽閹殿喗宕夐柟瀛樼箓閻撳倻鈧綊娼荤紓姘辩箔閸屾粍鍠?*"闂佹寧绋戦悧鎰邦敋閳哄懎鍙?`.scale()` 闂佹眹鍔岀€氼參鎮橀幋鐐村?
   *   >   **婵炴垶鎸哥粔闈浳ｉ幖浣哥闁瑰瓨绮堢花鏉库槈閹捐顏犳繛鍫熷灩閳ь剙婀遍幊鎾斥枍閹烘挾鈻旀い鎾跺仧婵?*闂佹寧绋戦ˇ顐﹀闯?闁荤姴娲㈤崕鏌ュ蓟閻斿娴栭柛顐ｇ矌缁嬪﹪骞栫€电娅愮紒?*闂佸憡甯╅崑鍕疮閳ь剟鎮?*闂侀潧妫楅崐鍫曞焵?
   *   闂?闂佺懓鐡ㄩ崹鑲╂崲閺嵮€鏋庨柨娑樺閹肩厧霉?*闂佸憡顭囬崰搴★耿閹绢喗鐓傜€广儱鐗呴崚濠偯瑰鍐╊棛缂佹梹鎸抽弻?*闂佹寧绋戦張顒勫汲閳ь剟鎮规笟鍥у绩妞ゆ柨娲﹀?`RzdMusic闁荤姳鐒﹀妯兼崲?md` 闁?6闂?
   *
   * ## 闂佺粯绮嶅妯猴耿?= 缂備胶铏庨崹浼村吹閹寸偞濯撮柡鍥ㄇ氶崑?*婵炴垶鎸哥粔瀛樼濞戞瑧顩烽悹浣哥－缁夊潡鏌涜閸旀牠鎮ラ敐鍥у缂備焦锚鎼村﹦绱?*闂佹寧绋戦悧鍡楊潩閵娾晛鍙婃い鏍ㄧ矋閺嗗繘鏌熼幘顕呮闁炽儲顭囬幏瀣Χ閸垻鐣?闂佺粯绮嶅妯猴耿椤忓嫷娼伴柨婵嗘噽閸╂霉?闂佹眹鍔岀€氫即宕戦崨顔锯枖闁逞屽墴閹囧醇椤掑倻顦?
   *
   * ```
   *   闁诲繐绻愰幖顐︻敋?/ 婵炶揪绲界粔鍫曟偪?/ 闂侀潻绠戝Λ婊堬綖濡や胶鈻旈柍褜鍓欓銉р偓锝庝簻缁?lyricMorph(t)闂? 闂佸搫鍟版慨鐑藉疾?CoverMorph 闂佹眹鍔岀€氼垳娆㈤銏犵闁绘艾顕粈?
   *   闂佺儵鏅涢悺銊ф暜閹绢喖绀冩繛鍡樺笧缁?.position() / .width() / .borderRadius()
   * ```
   * 闂佸搫鐗滈崜娆撴儑娴兼潙绠伴柛灞剧闊剛鎲搁懜顒€鐏╃憸鏉款槺閳ь剙婀遍幊鎾斥枍?*闂佸憡鍔曢幊姗€宕?*闂佹寧绋戦張顒佹櫠瀹ュ棛顩烽柕澶堝劥閸╁矂鏌涘▎鎯峰ジ鎳欓幋鐘亾閻熸澘鏆熸繛?*闁诲骸婀遍崑銈咁瀶?*闁诲繒鍋涚换鎰不闁垮濯寸€广儱瀚粣妤呮偠濮樼厧浜滄い鏃€鍔欏畷鎶藉Ω閵夈儳绉梺鐟扮畭閸ㄨ櫣浜搁幘鑸靛皫?
   * 闂佹寧绋戝澧? 闂?t閻犺櫣妞奰闂佹寧绋戦惌渚€锝?`LyricFloatLayer` 婵＄偑鍊曢悥濂稿磿閹绢喗鐒介柨婵嗘－閸炰粙鏌熼幁鎺戝妞ゆ洟浜堕弫宥嗗緞閸″繐浜鹃柡鍌濄€€閸?闁哄鏅滈悷锕€顭?闂佽В鍋撻柟瀛樺笧缁夋挳鏌￠崘顓炵厫妞ゆ帗绮庡☉鐢割敊鐞涒€充壕濞达絾鐡曢崺宀勬煕濞嗘兎濂告嚈閹达箑纾?
   * 闂佹眹鍔岀€氼剝銇愬☉姗嗗殫?*闂佹椿娼块崝宥夊春濞戙垹鎹堕柕濞у嫬鐒搁梺鍝勭墣濡椼劎绮崒娑辨鐎光偓閸愵亞鐣洪梺闈涙濞村洭锝為崶顒€绠涢柣鏂垮槻鐠佹煡鏌熼幁鎺戝姎鐟?*闂佹寧绋戦悧鍡涙儍濠靛顥堥柕蹇ョ悼椤庘偓闂佹椿鍋€閸嬫捇鎮楅崷顓熷殌婵炲懏甯楃粙澶愬焵椤掑倹灏庡瀣捣缁辨岸鏌涘顓炵伇缂侇垳濮甸幏鍛存偐閾忣偉鎷梺鎸庣☉椤︻參鍩€?
   * 闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯顖炲垂濮樿京鍗氶悗锝庡墯閻ｉ亶鏌涢幘宕囆ｇ憸棰佺窔瀵?`t = 1`闂佹寧绋戦悧鎰板箚閵堝棙濯寸€广儱绻掔粈鍡涙煛閸愵厽纭炬い鏃€鍔欏畷鎶藉Ω閿斿彨锕傛煙椤撶喎绗ч柣鈩冨灴瀹曪絽螣鐠囨彃绨?闂佺偨鍎查弻锟犲焵?闂佸吋婢橀惌鍌炲磻閸涱収娼伴柨婵嗘绗戦梻鍌氱墛閻燂箓顢楀☉銏犵畱濞撴艾锕︾粈澶愭煙椤撶喎绗氶柛銊︽皑缁晝鈧絻鍔夐崑?
   */
  private coverLocalRect(): LyricMorphRect {
    return this.lyricFloatRect();
  }

  /** 婵炴垶鎸搁敃锝囩博閺夋垟鏋?`RzdCoverLocal` 闂佹眹鍔岀€氼垶骞嗛妶鍡樺鐎广儱娴傞崝顕€鏌涘顒傗枌缂佽鲸鐟╅幊鐐哄磼濞戞哎鍋婇梺姹囧焺閻撳妲愬┑瀣煑妞ゅ繐瀚煬顒勬煟椤忓棗鏋旀繛鍫熷灴瀹曪絽螣閸︻厼鏅╅梺褰掓涧缁夊灚鏅堕敃鍌涙櫖濠㈣泛鐗冮崑?*/
  private lastCoverLocalLog: string = '';
  /** `RzdCoverLocal` 闂佹眹鍔岀€氫即宕虫导鏉戝唨闁汇値鍨拌灐濠电偟绻濈欢銈囨濡炬悞闂佹寧绋戦懟顖炴嚋娴兼潙鐭楁俊顖滅帛椤ρ勬叏閿濆懐绠伴柟鑸靛哺閺屽牓骞嬮幒鏃傜崶闂佸憡鐟﹂敃顐ゆ濠靛洤绶炴い蹇撳濡叉洖霉閸忚壈澹橀柛鈺傜〒娴狅箒绠涢妷褏顦梺?*/
  private static readonly COVER_LOCAL_LOG_MS: number = 100;
  private lastCoverLocalAtMs: number = 0;

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16 闂佸搫鍊瑰姗€路閸愵亝瀚氬┑鐘插暞閻掍粙鏌?*闁诲繐绻嬬欢姘焽娴煎瓨濯伴柟瀛樺笧缁夋挳鏌ｉ妸銉ヮ仾妞?闂佸憡鐟ョ粔纾嬨亹婢舵劕绠查柕蹇曞閸ょ娀鎮?*闂?
   *
   * ## 闁诲海鎳撻崯顐﹀垂閼恒儳顩烽柍褜鍓氱粙?
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdCoverLocal'
   *   闂?RzdCoverLocal t=闂?s=闂?tx=闂?ty=闂?screen=(x,y,w,h,r) local=(x,y,w,h,r)
   * ```
   * 閻?`s = 1 / tx = ty = 0`闂佹寧绋戦悧鎾愁焽閵堝拋娼伴柕蹇婃閸嬫挻绗熸繝鍕槴闂?婵炴垶鎸堕崐鎾绘煂濠婂牊鍎楅柍杞版祰閸╁矂鐓崶褎鍤囬柕?*闂備緡鍋呴崝鏇㈡偤瑜旈幆鍕矙閹稿骸鈧?*闂佹寧绋戦悧鍡楊嚕娴犲鐭楁俊顖濐嚙鎼村﹪鏌￠崟闈涚仭濞存粎鏅划鍨緞鐏炲墽鏆犻梺鎸庣☉椤р偓缂?
   * 閻?閻熸粏鍩囬崹纭呫亹婢跺鈻?闂?`local` 闂婎偄娲ら幊姗€濡?*闁哄鏅滅划宀勫Φ閸ャ劎顩?* `screen`闂佹寧绋戦悧鍡椕哄鍕枖濡わ附顑欏ú锝夋偠?`s` 闂佸憡锚椤戝懎煤閺嶎厼鍌ㄥù鍏肩懅缁€鍡涙煥?
   *   婵?`local.x/y` 闂佸憡鐟崹鐢稿礂濡崵鈻斿Δ锕佹硶椤︿即鏌ㄥ☉妯煎闁汇劍绻堝Λ鍐閻樺疇鍚柣鐔舵缁€浣圭珶閳ь剛绱掗幇顓ф當鐟滅増绋掔粙濠勨偓锝庝憾濡棝鏌ｉ妸銉ヮ伃闁稿鎳忕粙澶愬焵椤掑嫬绠ｆい蹇撴捣缁€澶愬级閳哄倻鎳勬俊鑼焾椤垽鏁愰崨顖氱厬闂佹眹鍔岀€氬摜妲愬鑸垫櫖?
   * 閻?**闂佸憡甯囬崐鏍х暤?*闂佹寧绋掔喊宥嗕繆?`s / tx / ty` 婵?`screen` 婵炲濯寸紞鈧紒缁橆焽閳ь剙婀遍幊鎾斥枍閹烘鐭楁俊顖濐嚙鎼?
   *   `y_闁?= H/2 + (y_闂?闂?H/2)s + d` 闁圭厧鐡ㄥΛ浣烘崲閺囥垹鍌ㄩ柣鏂垮槻濮?`screen.y` 闂佺偨鍎查弻锟犲焵?闂佸吋鐪归崕瀵告崲閺囥垹鍌ㄩ柣鏂垮閻熸繈鏌涢幋鐘插妺婵炶偐鏁婚弫?
   *   闁荤姴娲ら悺銊ノｉ幋鐘亾閸︻厽鍤€婵炲懏甯￠幆鍐礋椤掑倷鏉柡?闁诲繐绻愰幖顐︻敋椤撱垹纾婚柛銉憾閸熷骸鈽夐幘鎶筋€楅柣銈呭閹櫕锛愭担铏规喒缂備焦顨愮拋锝囨濞嗘挻鐒介柨婵嗘椤ρ囨偡閺囨氨鍔嶉柡浣搞偢閹啴宕熼浣?`coverHostH()`闂佹寧绋戞總鏃傜箔婢舵劕鍙婃い鏍ㄦ皑濞堥亶姊婚崼顐ｇ窙缂佽鲸宀告俊?
   */
  private logCoverLocal(): void {
    const now: number = Date.now();
    if (now - this.lastCoverLocalAtMs < PlaybackPage.COVER_LOCAL_LOG_MS) {
      return;
    }
    const screen: LyricMorphRect = this.lyricFloatRect();
    const local: LyricMorphRect = this.coverLocalRect();
    const sig: string = `${screen.x.toFixed(0)},${screen.y.toFixed(0)},${local.x.toFixed(0)},${local.y.toFixed(0)}`;
    if (sig === this.lastCoverLocalLog) {
      return;
    }
    this.lastCoverLocalAtMs = now;
    this.lastCoverLocalLog = sig;
    const s: number = this.expandState.morphScale;
    Logger.info('RzdLyricFloat',
      `RzdCoverLocal t=${this.lyricMorphT.toFixed(3)} s=${s.toFixed(4)} ` +
      `tx=${this.expandState.morphTx.toFixed(1)} ty=${this.expandState.morphTy.toFixed(1)} ` +
      `winH=${this.expandState.windowHeightVp.toFixed(0)} clipH=${this.expandState.morphClipHeight.toFixed(0)} ` +
      `screen=(${screen.x.toFixed(1)},${screen.y.toFixed(1)},${screen.size.toFixed(1)},${screen.radius.toFixed(1)}) ` +
      `local=(${local.x.toFixed(1)},${local.y.toFixed(1)},${local.size.toFixed(1)},${local.radius.toFixed(1)}) ` +
      `realCover=${this.expandState.realCoverVisible()} clone=${this.expandState.morphOverlayBridging()} ` +
      `squash=${this.expandState.morphSquashY.toFixed(3)}`);
  }

  // 闂佸疇娉曟刊瀵哥箔?2026-10-16闂佹寧绋掗悺鐚凲UASH_MIN` / `squashWrapHVp()` / `squashWrapOffsetYVp()` **閻庣懓鎲¤ぐ鍐垂瑜版帗鈷?*闂?
  //
  // 闁诲海鎳撻崯鈺侇煥閹达箑鍙婃い鏍ㄧ☉閻忓鈽夐幘绛规缂佹梹鎸抽幃褔宕煎鍡欘槹婵炲瓨绮屽Λ婊堫敊閳?闂佺厧鍟块張顒€鈻嶅▎鎰枙闁绘棁宕甸鈧梺娲诲亐閸嬫挾鈧?闂佸吋婢橀懟顖涙叏閻愮儤鍎嶉柛鏇ㄤ簽椤忛亶鎮橀悙鎻掆偓鍊熸＂闂佺顑呴悘婵嬵敊閹版澘闂?
  // 闂佹寧绋戝?height(winH 闁?k)` + `.offset({y: 闂佹剚鍘芥慨绉坣H(1闂佹剚鍘芥慨?/2})` + `.scale({y: k})`闂佹寧绋戦ˇ顓㈠焵?
  // 闂佸搫鐗滈崜婵嬫偪閸℃稑绠┑鐘插暞閿熴儵鏌ｉ敐鍛伇婵?*闁诲繒鍋涢崐缁橆殽?*闁荤姴娲ら…鐑藉焵椤掍胶鐓紒鐙呯秮瀹曘儲鎯旈婊咁槷闂備緡鍙忕徊濂告煂濠婂懏鍋橀柕澶堝劙缂?*闂佽桨鑳剁换婵嬫煂濠婂嫮鈻旂€广儱顦版禒姗€鎮烽弴姘樂缂?*闂?
  // 闂佸搫鍟版慨鐑藉疾椤愶附鍎?`MeshCoverBg` 闁诲繐绻愬畷顒€锕?*闁?`scale/translate/clip` 闂佹眹鍔岀€氫即宕戦崨顔锯枖?Stack 闂備焦褰冮惌鍌氼焽?*
  // 闂佹寧绋戝澧倁jie.pa` 191388 闂備緡鍙忕徊濂告煂?`PLAYER_ROOT_ID` 闁诲骸婀遍幊鎾斥枍閹烘鏅€光偓閸愮偓缍?`build()` 闂備焦褰冮惌鍌炲磻閸涱厸鏋旈梻鍫熶緱閸熷洭鏌涢敐鍐ㄥ闁绘牗鐓￠弫宥嗗緞濞戞氨顦?
  // 闂?闁诲海鎳撻崯顐﹀Φ婢舵劖鍊块柟顖涘椤庘偓闂佹椿鍋€閸嬫捇鎮楅崷顓熷殌婵炲懏甯楃粙澶愬焵椤掑倹灏庡瀣捣缁辨岸鏌曢崱鏇燁樂缂佹柨顕幐褔鎮块锝嗚晧闁荤喍妞掗梽宥夊焵椤戞寧顦风紒鈥冲暞瀵板嫰鍩￠崘銊バ侀梺闈╄礋閸斿繘鎯屾ィ鍐╁仺闁告鍎戠槐锕傛⒑椤撱劎绋绘繛?`morphSquashY` 闂佹眹鍔岀€氼亞绱為弮鍫熷仺闁靛鍎抽崢鐢告⒑閹绘帟顫﹂柍?
  // 闂?闂佺厧鍟块張顒€鈻嶅▎蹇ｅ晠闁告瑥顦惁濠氭煛閸愵亜啸闁哄拋鍋婇獮鏍敆閳ь剙煤閺嶎偀鍋撻崷顓熷殌婵炲懏甯″畷姗€宕ㄩ弶鎴濆Г闂佹寧绋戦惌浣烘崲閺嶃劎鈻旈柍褜鍓涙禒锕傚磼濠箑顦靛畷鎴︽嚄椤栨粎顔曢梺鍛婅壘閼活垶鎮鹃悩缁樺剭闁告洦鍋嗛崺妤呮⒑閹绘帞绠ｇ紒鏂款嚟閹秆冪暋閺夎法浠奸梺鐟版惈椤︻參鍩€?

  // 闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸?闂佺鐭囬崘銊у幀闂佸憡鐗犵紓姘跺吹濠婂牆绀夐柕濠忛檮閺嗩亪鎮?闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸?

  // 闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸闁硅埇鍔嶅▍婊堟煃閻戞ê濮€闁哄懏鐓￠崺?闂佸疇妫勯幊澶娢ｉ崟顖氱叀?闂佺粯绮嶅妯衡攦閳ь剟鏌ゆ總澶夋捣闁伙箑顦銉╂嚍閵壯冪伇闂?*婵炴垶鎸哥粔宕囨妞嬪孩灏?hdc**闂佹寧绋戦ˇ顐﹀疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸闁硅埇鍔嶅▍婊堟煃閻戞ê濮€闁哄懏鐓￠崺锟犲箛閵婏附鐝?
  //
  // ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箓椤綁鎮?
  //
  // 闂侀潧妫楅惉濂稿磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸?/ 闂佺粯鍔楅幊鎾诲吹椤曗偓瀹曟骞庨懞銉川 / 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧┑鐐插閸撴繂锕㈡担杞扮剨濞撴埃鍋撴繛闂村嵆瀹曟繈濡歌閺嗕即鏌曢崱妤冃ョ紒缁樼墵瀵爼鏁撻悩绛圭椽婵☆偆澧楅敃顐ゆ濠靛瀚夋い鎺戝暟閺嬪倻鈧鐡曠亸娆戝垝閿熺姴缁╅梺顐ｇ〒閸?3 婵?
  // 闂佹寧绋戦悡?2 闂佺厧鍟块張顒€鈻嶅▎鎰枖鐎广儱顦崑鎾圭疀閺冣偓椤牠骞?/ 闁?3 闂佸湱顭堥崐钘壝归崶顒€绀嗛柕鍫濇缁?/ 闁?4 缂傚倷绀侀悧蹇涘磻閿濆鐓ユ慨妯哄船娴狀垶姊洪幓鎺旂缂佷焦鎸冲濠氣€﹂幒鏃傤槴闂佹寧绋戞總鏃傚緤?*闂佹椿娼块崝宥夊春濞戞瑧鈻旂€广儱鐗嗛崢鎾煟?hdc**闂?
  // 闂佺懓鐡ㄩ崹鍓佲偓锝勭劍缁嬪顓奸崨顓犲帓 `RzdCoverLocal` / `RzdMorphOwnership` 闂備緡鍙忕徊鑲╄姳濞差亜绫嶉柕澶堝劤缁?闂?闂佸憡鐟禍锝夊礂濮椻偓濡?闂佽　鍋撻梺顐ｇ〒閸熷﹪鏌涢幇顒傂ユい鏂哄亾闂佹椿娼块崝宥夊春濞戞碍鍟?闂?
  // 闂佸吋婢橀惌浣烘崲閺嶎厼绾ч柨鐔哄У閹崇姴鈽夐幘绛规敾婵犫偓?5~6 婵炴垶鎼╂禍婊堝垂娴犲妫樻い鎾卞妿缁€?*闂佺儵鏅涘鍫曞极婵傚憡鍎嶉柛鏇ㄤ簻閺佲晛霉閻樻彃妲婚柛鎴磿缁辨帟绠涘鍏艰晧闁荤姴娲ｉ悞锕€危閹达箑鍑犲ù锝嗘偠娴?*闂佹寧绋戦悡?6~闁?4 闂?8 闁哄鍎愰崳顖滄濮樿泛违?
  //
  // 闂?闂佸憡姊绘慨宕囩博鐎涙鈻?*婵＄偑鍊楅弫璇差焽閻楀牏鈻斿┑鐘插缁绢垶鏌熼幁鎺戝姕婵☆垰顦辩划鍫ュ传閸曨偆浼堥梺?*闂佹眹鍔岀€氼剟鎯冮鈧銉╂嚍閵壯冪伇闂佹寧绋掑銊╁极閵堝绠ｅ瀣娴狀垳鈧鍠掗崑鎾绘煙缂併垹骞楅柡鍌欑窔瀹曟娊濡搁妷锕€鈧敻鏌熺捄鐚村伐闁活偄妫欑粙澶嬬節閸パ傜凹婵炴垶鎸堕崐娑€侀幋锕€鏋侀柡澶庢硶閹界喖鐓崶顒佹锭闁搞値鍙冨鍫曞Ψ椤栨粎顦?
  //   闂佺懓鐡ㄩ崹闈涱潩閵娾晜鍤勯柟瀛樺笧椤忚鲸绻涢崱蹇婂亾瀹曞洦姣庢繛杈剧到缁夋挳宕哄畝鍕闁炬艾鍊荤粔濂告煕濠垫劒绨风紒鏂跨摠缁嬪顢旈崟顐や紙闂佸搫鍋嗛崢铏规嫻閻旂厧纾婚柛銉ｅ劗閸?*闁荤喍绀侀幊宥囩博閺夋垟鏋庨柨鐔哄О閳ь剙锕畷鈩冩媴鐠団€充还闂佺儵鏅涘鍫曞极婵傜违?*
  //
  // ## 闂佹椿娼块崝宥囨兜閸洘鏅柛顐犲灪閺嗗繘鏌熺壕瀣吂闁哄懎鐖奸弫?
  // ```
  //   閻?闁哄鏅濋崑鐔煎磻閿濆绠绘い鎾跺枑閺夌懓顪冮妶鍥ㄦ毈闁靛棗锕弻?3 濠电偛妫屽Σ鍕濞嗘挻鍊?闁哄鏅滈弻銊ッ?閻庡灚澹嬮崑鎾绘煕濞嗗繐甯犵紒鏃€鎸抽幃娆掋亹閹烘垳绨奸梺缁橆殔濞层劑鍩為弽顓熷剬闁哄倶鍊楃粈澶愭煙鐎涙澧遍柛瀣剁到椤垻浠﹂懞銉モ偓?濠殿喗绻傞張顒佹櫠濠婂牊鐒介柨婵嗗椤忛亶鎮跺☉妯肩効缂?
  //   閻?闁诲繒鍋涚换瀣箔閸岀偛绀勯柧蹇曟嚀缁犳稑鈽夐幘顖氫壕闁诲繐绻愮换鎰焽閳╁喚娓堕柟瀛樼箘娣囨椽鏌ｈ濡嫰鎮鸿閺佸秶浠﹂崐鐔风厒婵犵鈧啿浜扮紒?
  //       V 8f3a2c1 sess=1 usable=1 cont=1 clip=1 scale=0.082 p=0.000
  //       real=0 clone=1 snap=330/56 end=328/328 op=0.040 stage=1 drv=2
  //   閻?闂佺娉涢敃銊ф崲閺嶃劎鈻旈柕鍫濈墱閺€浠嬬叓閸モ晜鏆╃紒顔诲嵆楠炲骞嬮婊咁槱闂佺懓鐡ㄩ悧妤呭春閸涙潙鐐婇柟鎯ф噽缁€鍡涙煕濡も偓閸熻儻銇愰弻銉︽櫖婵炴垶锚閺呮瑩鏌?3 濠电偛妫岄埀顒€鍟跨拋鏌ユ煕韫囨碍鐝悽顖楀亾
  // ```
  // 闂佸疇娉曟刊瀵哥箔?**闁诲海鎳撻崯顐ャ亹瑜斿畷鐑藉Ω閵娧咁啎闂?3 濠电偛妫岄埀顒冨皺椤撴椽鏌涘顒€顒㈠褏濞€瀹曟瑩鎼归悷鎵杸** 闂?濠殿喗绻愮徊浠嬫偉閸洖绠氶柛娑卞幖閺嬪苯鈽夐幘鎰佸剳闁轰降鍊濋獮瀣暋閹殿喗娈梺绋跨箞閸斿骸锕㈤崨顔锯枖鐎广儱鎳庨悡鍌炴煥濞戞ê顨欑紒妤€顦抽妵鎰板础閻愬瓨鍎ラ柣鐔哥懃閸婂綊宕濋崨鏉懳?
  // 闂佸疇娉曟刊瀵哥箔?缂備胶铏庨崹鎷屻亹瑜忛幏鐘冲濞嗘垹鐛ユ繛鎴炴尭缁夋挳宕幘瀵割浄閻犱礁纾粔鍨槈閹炬娊顎楀┑顔规櫊閹晫绱掑Ο鑽ょ暢闂佺绻愮壕顓炩枔閹达附鍋愰柤鍝ヮ暯閸嬫挻绗熸繝鍕槱闂佸憡鐟禍婊堝疮?`diagBadgeOn` / `diagText` 婵炴垶鎸堕崐鎾绘煂濠婂牆瀚夋い鎺戝閳ь剙顦遍埀顒佺⊕椤ㄥ棝顢欏畝鍕櫖濠㈣泛鐗冮崑?
  //
  // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*閻庢鍠掗崑鎾绘煕韫囨碍鐝柡浣搞偢楠炲骞囬娑氥€婇柣搴℃贡閸嬫娆㈤妷褎濯奸柡澶庢硶缁?* 闂佺偨鍎查弻锟犲焵?闂佺儵鏅涢悺銊ф暜鐎涙鈻旈弶鐐村閸?闁诲繐绻戦崹濂割敊閳ь剟鏌ｉ～顒€濡介柛鈺傜洴閹倿宕愰悢铏瑰礈婵炴垶鎸撮崑鎾诲级?闂佹寧绋戦¨鈧紒?
  //   閻庡灚濯芥慨銈夋偉閿濆洨绠旀い鎺嗗亾鐎规洖瀚粙澶嬪緞鎼搭喗鏂€闁荤姴娲╁畷闈涒枔閹达箑鍙?*闂傚倸鐗婇悷锕傚焵?*婵炲瓨绮岄鍕枎閵忋倕绫嶉柕澶堝劤缁犲爼鏌ㄥ☉妯煎缂佹鍊圭粙澶愬焵椤掆偓閳诲酣鍨鹃崘鎻掔稑闂傚倸鍋嗛崢鎯р枔閹达箑绀傞柕濞垮妿缁犳牜绱掔€ｎ亶鍎滅紒杈ㄥ哺閺佸秴鐣濋崘锝呬壕鐎光偓閸愭儳娈洪柣搴ｆ嚀閼活垶鎮鹃悩缁樺剭闁告洦鍊ｉ銏犵闁圭瀛╃瑧
  //   闂侀潧妫楅懟顖炲矗瑜斿?闂?**闂備焦褰冪粔鐢稿蓟婵犲洤绠ラ柟鎯х－绾惧鏌熺紒銏犲箺闁哄倷鐒﹂妵?* 闂?闂佺懓鐏氶幐鍝ユ閹存繍鍤楅柤鎭掑劤閸?闂?闂佽鎯屾禍婊兠瑰鈧俊鏉戭吋閸愶絽浜鹃柛灞捐壘鐠?`diagBadgeOn` 闂佸憡顭囬崰鎰焽閻㈢鍙?*闁诲骸婀遍崑妯兼閵壯傛勃闁逞屽墴閺?*闂?
  //   闂?濠殿噯绲界换鎴︻敃婵傚憡鐓傜€广儱妫欓悡鈧梺鐟扮仛閹稿摜妲愰幋锔界劸闁芥ê顦扮粈鈧梺?闂?闂佹寧绋戦惉濂稿极閵堝绠ｇ€瑰嫭澹嗙换?*闂佸憡鍔曠粔椋庢崲濞戙垺鍊?3 濠?*闂佸綊娼х粔璺猴耿閸涱収鍤楁俊銈傚亾闁?闂佺偨鍎查弻锟犲焵?婵犮垼鍩栭惌顔剧博閺夋埈娼伴柕澶堝劜閻ㄦ垵顭块懜鐢电叝缂佹梹娼欓埢搴ㄦ妞ゆ洜澧楃粙澶婎吋閸涱厾鍘掗梺姹囧妼鐎氫即藟閹剧粯鈷旈柍鐟扮氨閸?
  //   闂?闂佸憡姊绘慨宕囩博鐎涙鈻旀い蹇撶墛妤楊垶鏌熼璺ㄧ獢闁哄棗鎳樺畷鎾圭疀閵壯呯崶**閻庢鍠掗崑鎾斥槈閹绢垰浜惧┑鐐叉閳ь剝娅曢惃鎴濃槈閹绢垰浜鹃梺鐑╂櫅閻°劌危缁嬫鍤曢柍褜鍓熼幆?*闂佹寧绋戦悧蹇撁洪崸妤€绀嗛柡澶婄仢閺呮瑩寮堕埡鍐ㄤ户闁?3 濠电偛妫岄埀顒€鍟胯ぐ鐘绘煙閸濆嫷妾х紒杈ㄧ箞楠炲寮介鍌滎啋缂備礁顑呴澶愬闯閹间礁瑙︽い鏍ュ€楃粈鍡涙煏?
  private static diagBadgeOnStatic: boolean = false;
  @Local private diagBadgeOn: boolean = PlaybackPage.diagBadgeOnStatic;
  @Local private diagText: string = '';
  private diagTapCount: number = 0;
  private diagTapLastMs: number = 0;
  /**
   * 闂?闂佺厧顨庢禍锝夋儊婢跺本濯奸柍鈺佸暞濞堝爼鏌ㄥ☉妯煎鐟滄妸鍛＜婵炲棗绻掗悰锕傛煛瀹ュ懏宸濋柡浣靛€濋弫宥囦沪閼测晝鎲归悷婊勬緲瀹曨剟骞栭柨瀣浄閻犱礁纾粔鍧楁⒑椤愶絾顫楃紒棰濆亰閺佸秵寰勫☉姘辩崶
   * 閻?`diagRemeasureTries` 闂佺偨鍎查弻锟犲焵?`onAppear` 闂備焦褰冮惌鍌炲磻閸涱厸鏋庨柍銉ュ暱濞堛倕霉閿濆棙绀夐挊鐔兼⒑閹绘帞绠烘い顐閹奉偊宕橀鍛婵炲瓨绮屽Λ妤呭吹閹存績鏋庨柍钘夋噽楠?
   * 閻?`diagOverlayKicks`   闂佺偨鍎查弻锟犲焵?闂佺绻戝﹢褰掓嚈?闁荤偞绋忛崕鐢稿闯濞差亜绠ｉ柟閭﹀墮椤娀鏌涘顒勫弰闁靛棗閰ｉ獮宥団偓锝庡幗瀹曞啿霉濠婂啯顥為悹鍥╁仧娴狅箓宕掑锕€顦靛?闂佸憡鍨规慨鐢割敃婵傜违?
   * ```
   *   婵炴垶鎸堕崐娑㈠焵椤掆偓閹虫﹢宕?0 闂?闂備緡鍙忕徊楣冾敊鐏炲墽顩烽柨婵嗘川閸ㄦ娊鏌″鍫綈婵犫偓閺夊簱鏌﹂梽鍥╃玻閸ヮ剙绀嗛悽顖ｅ枤缁€鍒瀘nAppear` 闁荤姍鍥舵殥缂侇煉绻濆畷姘额敃閵堝棛鏆犻梺鍛婂笒濡瑩寮鈧弫?
   *   1 / 1    闂?闁荤偞绋忛崕鐢稿闯閻戞鈻旈幖娣€栧畷铏繆椤愶絽娴柛蹇旓耿瀹曪綁骞嬮悩铏婵?闂?闂佸吋鐪归崕閬嶆儍濠靛顥堟い顐幘閻繂鈽夐幘宕囆фい銉秮閺佸秴鐣濋崟顒婄椽婵☆偆澧楅敋婵犫偓椤忓牆绀勯柣妯夸含缁夊潡鏌涙繝鍕┾偓瀣濞嗘挻鍎?snap / end闂?
   *   1 / 0    闂?闁荤偞绋忛崕鐢稿闯閾忚宕夐柟瀛樼矌閸熷﹤霉?`morphUsable` 婵炲濮寸粔宕囨嫻閻旂厧纾?闂?闂?usable / end 婵炴垶鎸堕崐鏇㈠垂?
   * ```
   */
  private diagRemeasureTries: number = 0;
  private diagOverlayKicks: number = 0;

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*Swiper 闂佹悶鍎抽崑鐘绘儍閻旇　鍋撻崷顓炰粶鐎殿噮鍓涢幏瀣级鐠恒劎协** 闂佺偨鍎查弻锟犲焵?婵?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闂傚牊绋撳▓閬嶆⒒閸稑鐏柣銉ユ嚇瀹曪絽螣閾忚鐦?闂?*闂佸憡鍔曢崯鍧楁偩妤ｅ啫绠?*闁荤姴娲ㄧ划顖炲汲閻斿吋鏅?
   *
   * 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箘缁犳垵顪冮妶鍡橆潡妞ゆ柨娲ㄩ埀顒傛嚀閸犳稓妲愰悧鍫⑩枖濠电姳鑳堕閬嶆煙娴ｅ喚娼愰柛銊︾矒瀹曠兘濡搁妸褏顔愰梺鍝勵檧缁绘繈骞楅崗鑲┾枖濠电姴瀚弳?*闂傚倸鐗婇悷锕傚焵椤戣法鍔嶉悽顖氱秺閹?*闂侀潻璐熼崝瀣偖鏉堚晝鐭撶€广儱鎳嶅ù鐑芥偣娴ｇ缍栫紒鐙呯秮濮婅崵鈧稒蓱閸熸岸鏌?闂佺偨鍎查弻锟犲焵?
   * ```
   *   闂佺顑呭ú鈺咁敊?A闂佹寧绋掗悺?onAnimationStart` **闂佸搫绉烽～澶婏耿閺夊簱鏌﹂梽鍥杺闂?*闂佹寧绋戦悧鍡涘垂韫囨柣浜滈柛顭戝亞濮婇箖鎮硅婢ф鍒掗敃鍌氱闁靛鍎茬粈鈧柣鐘差儏閸犳稓妲?
   *   闂佺顑呭ú鈺咁敊?B闂佹寧绋掓穱楦款杺闂佸憡鐟﹂崹宕囪姳閳╁啯濯?*闁荤偞鍑归崑鍕偩瑜斿畷锟狀敃閿濆懐娈归梺?*闂佹寧绋戝濉眓dex === targetIndex`闂?
   * ```
   * 婵炴垶鎸堕崐娑㈠焵椤掆偓閹虫劕鈻撻幋鐐碘攳妞ゆ梻鏅妴?*闁诲海鎳撻懟顖炲矗韫囨梻鈻旂€广儱鎳忛崐?*闂佹寧绋戝﹢?闁荤喐娲戠粈浣革耿椤忓牆绠伴柛灞剧箖缁?闂佸憡甯掑ú顓㈠Υ婢舵劕绫嶉柟顖氬彄婢跺鈻旈柍褜鍓欓埢搴ㄥ灳閹颁礁娈告慨鎺旂帛閸斞呮閻?闁荤喐娲戦悞锕傚极閼测斁鍋撻悷鎵鐎规洖銈搁幆鍐礋椤愩垻浼堥梺纭咁嚃閸ｎ垳妲愬鑸垫櫖?
   * 闂佸吋婢橀懟顖濄亹瑜斿鍨緞鐏炴儳鐒搁梺鍝勭墦缂傛岸顢氭导鏉戞瀬闁瑰嘲鑻崢鎾煕閹烘垶顥″瀛樻倐婵℃挳宕掑Δ鈧▍?闁荤姳绶氶。锔剧箔閸涙潙绾ч柕澶樺灣缁€澶娾槈閹绢垰浜惧┑鐐叉閳ь剙纾弳鏉棵归敐鍛犻柍?
   *
   * 闁荤姴娲ㄧ划顖滄兜閸洘鏅柛顐ｇ箘閻涳箓鏌?*缂備焦顨忛崜娆撳矗閹捐埖鍋?*闂佹寧绋戦¨鈧紒?
   * ```
   *   ast=<index>-<target>   婵?`ast=0-1` = 婵炲濮村ù鐑筋敄?0 婵＄偑鍊曢悘姘卞垝閿曞倸瑙﹂柟瀵稿閸?1 婵＄偑鍊楅。顔炬濞嗗浚娼伴柨婵嗘噽閸╂鏌涢幒鎴炴悙闁糕晛鑻～銏犵暆閸愵亝袚婵＄偑鍊楅。顔炬?
   *                          `ast=-1--1` = **闁哄鏅滈悷銈夋煂濠婂牆鐐婇柣鎰濞堣泛鈽夐幘顖氫壕濠电偛妫寸换婵嬪礂濡　鏌﹂梽鍥╂崲濮椻偓瀵爼濡烽妸褏鐣?*闂佹寧绋戦悧鍡樼閿濆洦濯?A 闂佺懓鐡ㄩ崝妤呮偟濞戙垺鏅?
   *   skp=<闁诲海鎳撻悧鍡楃暦婵傜绠伴柍鈺佸暙缁旀挳鏌ｉ妸銉ヮ仾妞ゆ劕銈稿?   > 0 闂?ast 闂佸搫鐗嗛ˇ顖炲焵?闂?闂佺顑呭ú鈺咁敊?B 闂佺懓鐡ㄩ崝妤呮偟濞戙垺鏅柛顐ｇ箖缁€鈧柣鐘差儏閸熷磭鎹㈠Ο鑽ゎ洸闁糕剝娲滅粙濠氭偠?`index===target` 闂佸湱纭跺Σ鍕?
   *   aend=<index>/<濠电偛妫岄崜婵嬪汲?    `onAnimationEnd` 闂佸搫鐗冮崑鎾绘煕濮橆剛鍑圭紒鏃€娼欓埢搴ㄦ晬閸曨剛鏆犻柣搴℃贡閸嬫稑顕ｉ浣衡枖閹兼番鍩勯崑褔鏌?
   *   chg=<index>/<濠电偛妫岄崜婵嬪汲?     `onChange` 闂佸搫鐗冮崑鎾绘煕濮橆剛鍑圭紒鏃€娼欓埢搴ㄦ晬閸曨剛鏆犻柣搴℃贡閸嬫稑顕ｉ浣衡枖閹兼番鍩勯崑褔鏌℃担绋跨盎缂佽鲸鐛╳iper 闂佺厧顨庢禍婊呮崲娴ｇ儤濯奸柕鍫濆缁€瀣煕鐎ｎ偆鐭婃繝鈧鍫濅紶妞ゅ繐鍟伴鍗烆渻閵堝浂鏆滅紒?
   * ```
   */
  private diagAnimStart: string = '-1--1';
  private diagAnimSkip: number = 0;
  private diagAnimEnd: string = '-';
  private diagAnimEndCount: number = 0;
  private diagChg: string = '-';
  private diagChgCount: number = 0;
  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋掗悺鐚硁ContentDidScroll` 闂?*闁荤姴顑呴崯浼村极閵堝洦濯奸柍鈺佸暞濞堣泛鈽夐幘鍐差劉婵炴挸鐖煎畷銉︽償濠靛牜浼囧┑鐐叉閳ь剙纾弶浠嬫煕?* 闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕€危閹间礁瀚夋い鎺戝暟閺嬪倿鏌ｉ鍡楁瀾妞ゆ帗绮撻幆鍐礋椤愩垻浼堥梺纭咁嚃閸犳捇鍩€?
   *
   * 闁荤姴娲ㄧ划顖滄兜閸洘鏅柛顐ｇ箘閻涳箓鏌?*缂備焦顨忛崜娆撳矗閹捐埖鍋?*闂?`scr=`闂佹寧绋戦¨鈧紒?
   * ```
   *   scr=<濠电偛妫岄崜婵嬪汲? last=<index>/<position>
   *     scr=0        闂?闁哄鏅滈悷銈夋煂濠婂牆鐐婇柣鎰濞?*婵炴垶鎸撮崑鎾寸箾閸☆厾绡€闁稿繑锚閳讳粙妾辩悮婵嬫煕?*闂佹寧绋戦悧鎾诲磻?SDK 婵炴挻鐨滈崘鈺冩濠电偛澶囬崜婵嗭耿娴ｈ浜ゆ繛鎴灻濠冪節瑜庨崝鏇°亹閺屻儲鍋ㄦい顓熷笧缁€澶愭偡閺囨氨鍔嶇€规洘鐓″顒傛喆閸曞灚鏁甸梺?
   *     last=0/0.37  闂?濠殿喗绻愮徊钘夛耿椤忓懐顩烽幖杈剧磿濞堥亶姊婚崼娑樼伈闁靛棗顦…銊╁箣濠靛洤鈧粯鎱ㄥ┑鍡欑劮闁伙附绻冮妵鍕枈婢跺瞼顦ーposition` 闂佸搫瀚烽崹鍏呯昂闂佸憡鏌ｉ崝宥夋儊椤旂晫鐟归悗锝呭缁€?
   *     last=0/1.000 闂?闂?**闂佺顑嗙划灞斤耿椤忓嫷娼扮€光偓閸愵亝袚婵?*闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閳ь剙鈻撻幋锝冧汗闁瑰搫绉堕閬嶆煕閺嶃劎澧┑鈥虫憸閳ь剛鎳撻崯顐﹀Φ濞嗘挸绀?1闂佹寧绋戞總鏃傜箔閺嵮屾桨闁靛牆鎳忛崐闈涒槈閹惧磭孝闁哥啿鍋撻梺鍝勬搐閻°劑寮绘繝鍥ㄦ櫖?
   * ```
   * 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ幘閹肩厧霉閻樻椿妫戝褑娉曟禍鍛婃綇閵娤€?`swiperProgress`闂佹寧绋掔粙鎴︽偩閻樿鍙?goal 缂?1 闂佸搫顦崜婵堚偓鍨皑閳ь剝顫夊銊モ枔?*闁哄鏅滅粙鎴犫偓鐟板暱閳?*闂?
   */
  private diagScrollCount: number = 0;
  private diagScrollLast: string = '-';
  /** 歌词页滑动诊断的去重键（`selectedIndex/index`）与上次打印的进度（见 `onSwiperContentDidScroll`）。 */
  private lyricDiagKey: string = '';
  private lyricDiagP: number = -1;
  /** 「歌词页终点几何」重发已重试次数（上游 `publishRetries`，见 `publishLyricMorphTargets`）。 */
  private publishTargetRetries: number = 0;
  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋掗懝楣冨船鐎电硶鍋撻崷顓熷殌闁?`.onAppear()` **闁荤姍鍥舵殥缂侇煉绻濆畷顐︻敂閸涱喛鎷梺鍛婂笒濡瑩寮?* 闂佺偨鍎查弻锟犲焵?闁诲氦顫夐惌顔剧礊?闂佺绻戞繛濠偽涢幘顔艰Е閹艰揪绲垮畷鎰版煟閹烘洘纭剧€殿喚鏁诲銊╁箚瑜忓鏃傗偓娈垮枓閸?闂?
   *
   * 闂佸憡鐟﹂悧鏇㈠焵椤掑倶鈧妲?
   * ```
   *   '-'        = 闁哄鏅滈悷銈夋煂濠婂牆鐐婇柣鎰濞堝爼寮堕埡鍋垫垿鎯€閸涱喗浜ゆ繛鎴炵矌缁?
   *   'morph'    = 闁荤姍鍥舵殥缂侇煀銈冧汗闁靛繒濮寸紞渚€鏌涢幒鎴烆棡闁轰緡鍣ｉ弫宥夊锤椤ｆ檪phContainerActive || morphSessionStarted闂佹寧绋戦ˇ顐€?濠殿喗绻愮徊浠嬫偉?
   *   'intro'    = 闁荤姍鍥舵殥缂侇煉绻濆畷妤€顭ㄩ崘顏冧孩闂佸憡甯掑Λ娆撳极椤曗偓閻涱噣骞嗛悧鍫濋棷婵?playExpandIntro()  闂?闂?闂佸吋鐪归崕閬嶅吹椤撱垺鍋濋柡澶嬪闊剟鏌涜箛鏂库枙婵☆偄鐡ㄥ濠氬炊閳圭偓鐓犳繛鎴炴惄閸欏繒妲愬┑鍫滅剨閺夊牄鍔嶇瑧闂?bug
   *   'skipClose'= 闁荤姍鍥舵殥缂侇煉绻濆畷妤€顭ㄩ崘顏冧孩闂佸憡甯掑Λ娆撳极椤旇姤濯撮柛鈩冨嚬濞?濠殿喗绻愮徊钘夛耿椤忓牆绀傞柟鎯板Г閿?闂備緡鍙忕紞浣圭妤ｅ啯鈷掗柕濠忕畱椤忊€斥槈?闂佺繝绀侀幏鎴犳濞嗘挸瀚夋い鎺戝暟閺嬪倿鏌￠崒娑欑凡妞ゃ倕鍟撮幆鍐礋椤栨冻绱濋梺?
   * ```
   * 闂佸憡甯囬崐娑㈩敋娴煎瓨鏅慨姗嗗墮瑜扮娀姊婚崒銈呭箹闁诡喗顨婇幊鐔煎Ψ瑜庣粻娆撴煕?`intro` 闂?闂傚倸鍊堕崝宥夋儉閸涙潙绠柨鏃囨硶缁夊爼鏌ㄥ☉妯煎ⅲ妞も晪绠撳畷妯侯吋閸℃瑥寮ㄩ梺鍛婂竾閸婃牕鐣垫笟鈧弫宥嗗緞濞戞艾鑰块梺娲讳簻椤戝懘宕?`skipClose` 闂?闂傚倸鍊堕崝搴ㄥ极閹捐鏋侀柛顐ｇ矌閸熷﹪鏌?
   */
  private diagAppearBranch: string = '-';
  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本绻傚▓鎵偓瑙勭摃娴滎剙鈻撻幋鐘亾閸︻厼浠︾紒浣规尦閹矂鍩℃担钘夌厒**闂佹寧绋戦悧蹇涙偘閵夆晛鐭楅柨婵嗘噺缂嶅繘鏌″鍛カ缂佽鲸鑴妏闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闁诲氦顫夐惌顔剧礊?闂佸搫鐗嗛ˇ鎶藉磿濡ゅ懎鐤炬い鏍ㄧ懅缁嬭螖閸屾耽顏嗏偓瑙勫▕閹囨焻濞戞氨校"闂?
   *
   * 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箓缁€瀣煟濞嗘ê澧撮柛锝堟閳ь剛鎳撻崰娑氭娴煎瓨鍤勯悘鐐靛亾閻濐垶鎮橀悙鎻掍喊缂佽鲸鐛婱eshCoverBg` 闂備緡鍙忕徊濂告煂濠婂應鍋撻悷鑸粧閻?`Column`闂佹寧绋戦ˇ鏉课?*閻熸粏鍩囬崹纭呫亹婢跺备鍋撻崷顓熷殌婵炲懏甯￠幆鍐礋椤愩倖鎲ら梺鐓庢惈閸婂宕?*闂?
   * 闂佸吋婢樻總鏃傜箔閺嶎厼鍙?`.height('100%')` + `.position({x:0,y:0})` 闂?闁诲海鎳撻崯鏉库枔閹寸儐娈楁俊顖氭惈椤?*闁诲海鎳撻懟顖炲矗韫囨稒鍋ㄩ柛妤冨剱閸熷洭鏌涢敐鍐ㄥ闁哥姴鎳愰埀?*闂?
   * 闂佹椿娼块崝宥夊春濞戙垹绠柕澶涚岛閸嬫挾浠﹂悙顒傜暢闂佺厧鍟块張顒€鈻嶅▎鎰闁糕剝蓱绗?*婵°倕鍊归敋閻庤濞婇幃褔鏌呭☉姘毙?*闂侀潧妫楃粔闈涱渻閸岀偞鏅悘鐐跺亹閻熷繒绱掓径濠勑㈢憸鐗堢叀閹虫鎸婃径宀€鐣辨俊鐐€涢褔宕规惔銏＄秶妞ゎ厽甯炵粣?
   * ```
   *   闂?闁诲骸婀遍幊鎾斥枍閹烘鍎嶉柛鏇ㄥ櫘濮婂潡鏌涢幙鍐х敖闁绘稏鍎靛畷锝夋晲閸℃ɑ瀚抽梺鍝勵槶閸庡崬顫濋妸鈺佸強妞ゆ牜鍋涙禍婵嗏槈閺傝法澧曢柣顭戝墴閺佸秹宕搁崚顣抜pH` 闁荤姴娲ㄧ划顖炲汲閻斿吋鏅璺烘濞?濠殿喗绻愮徊浠嬫偉閸洘鏅悘鐐靛亾绗戦梺鍛婃煟閸斿酣寮悙顒傗枖妞ゆ挾鍣ラ崬?
   *   闂?闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本绮嶉悾閬嶆煟閳哄倸绗掗柣鈩冪懅閹噣顢曢姀鐘殿伝闂佺懓鐡ㄩ崝鎺旇姳閿熺姴鍑犲ù锝呮憸濮ｅ牓鏌ㄥ☉妯煎婵犫偓閹殿喗瀚氱紓浣股戝▓?`bgH`闂? 闂?闁汇埄鍨伴崯顐︽儑椤掑嫭鈷掓い鏇楀亾妞わ絼绮欓弫宥夊醇閵忊槅浠撮梺鍛婂笒濡瑩鎯侀鈧弻褔鎮欓浣哄姺婵炲瓨绮屽Λ瀵告?
   *   闂?闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本绮嶇壕顏堟倵濞戞瑥濮堟い鎺撶矌閺侇噣姊归幇顔旧戦柣?*濠电儑绲洪崜婵堟暜閳?*婵炲瓨绮屽Λ瀵告濡句繝g` 婵炴垶鎸哥粔褰掑焵椤掆偓缁绘垵危閹寸偞鍎熼柨鏃囧亹缁€鍡涙煃?闂?`backgroundRevealOpacity()` 闂佹眹鍔岀€氼亞鑺?
   * ```
   * 闂?`MeshCoverBg` 闂佸湱顣介崑鎾绘煕閿斿搫濡兼い鏃€鐗楃粙?`Column` 闂?`.onAreaChange()` 闂佸憡鍔栭悷杈╂濞嗘挸鐭楁い蹇撴祩閸ゃ垽鏌ㄥ☉妯绘拱婵☆偁鍊濆畷婊堫敍濞嗘垹鈻曢梺姹囧焺閻撳妲愬璺何?
   * 闂佸疇娉曟刊瀵哥箔?`onAreaChange` 缂傚倷鐒﹂悷褍鈻撻幋锕€鍙?*闁汇埄鍨伴崯顐︽儑椤掑嫬绀勯柣妯夸含缁?*闂佹寧绋戦悧鍛箔婢舵劕瑙︽い鎰╁€ゅ▓顖炴煕?transform闂佹寧绋戦ˇ顐﹀闯?闂備焦婢樼粔鎾箖鎼粹槅鍤楅柤鎭掑劤閸ㄨ偐绱掑Δ濠傚幐缂佹柨顕幃鏉跨暆閳ь剙鈻?
   *    `scale` 闂佸綊娼х粔鐑藉礂濡粯浜ゆ俊顖氭惈閺?闁诲繒鍋涚换瀣箔閸屾稑绶炴慨妯哄瑜?闂? `bgH 闁?scale`闂佹寧绋戦ˇ顓㈠焵?
   */
  @Local private diagBgBox: string = '-';
  /**
   * 婵炴垶鎸搁敃锝囩博閺夋垟鏋?`onContentDidScroll` 闂佹眹鍔岀€氼厼顪冮崒鐐粹拻閻庢稒锚閻撳牓鏌ㄥ☉妯绘〃s闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?**闂佹椿娼块崝宥咁焽閻㈠灚濯?闂佽В鍋撻柦妯侯槺閺?闁荤姳璁查弲娆戠礊閸涱垳纾?闂備緡鍋呴崝鏇㈠箮濮橆厽浜ゆ繛鎴灻?**闂?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧鎰崲閺嶎厼鍙婃い鏍ㄧ⊕閹烽亶寮堕悜鍡楁灈缂佺儵鍋撴俊鐐€涢褔藝閳哄懏鍋犻柛鈩冪懄閻ｅ崬鈽夐幘顖氫壕婵?*闂佹椿浜為崰搴ㄦ偪閸曨垰绀冮柤纰卞墰瀹?*闂佹寧绋戦¨鈧紒?
   * `onContentDidScroll` 闂備緡鍋呴崝鏇㈠箮濮樿泛绀?`lyricMorphT = p`闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?
   * 闂?`syncLyricMorphToPage()` 闂?闂?`t` 闂佽В鍋撻柦妯侯槺閺嗕即鏌涢幒鎾寸凡缂傚秴顑夊畷婊冾吋婢跺牃鍋撴径灞稿亾閻㈠灚鍤€缂併劍鐓￠幆鍐礋椤撗傜磽闂?闂佹寧绋戦悧鍛博閹绢喖绠┑鐘叉媼閸熷酣鏌涢幒妤婃殥缂傚秴鎳橀弫宥嗗緞閸艾浜?
   * 婵炴垶鎸堕崐娑㈠焵椤掆偓閹虫挾鈧哎鍨藉畷銉т沪閻愵剦妲梺姹囧灮閸犳劙寮查妷褌鐒婇柛娆愵焽缁?*濠殿噯绲界换鎰板箮濮橆厾顩查柟鐑樻⒐缁佹煡鏌熼煬鎻掔仼闁?*闂佹寧绋戦悧濠勫垝閿曞倸绀嗗Λ棰佽兌椤忛亶鏌涘Δ鈧敃銊╋綖閿曞倹濯伴柦妯侯槺閺嗕即鏌?1 闂?闂佹眹鍨归…宄邦焽閹殿喗宕夌紒娑樻贡缁€鍡涙煏?
   * 闂?闂佸憡甯囬崐鏍х暤娓氣偓閺?*闂佸搫鐗冮崑鎾诲级?120ms 闂佸憡鍔曢幊蹇擄耿娴ｅ壊鐓ユ慨姗嗗墮琚熼梺鎼炲劤閸嬬娀鎯?闂?闁哄鏅滈悷銈囩博閺夋垟鏋旈柣銏犵仛閺?闁哄鏅滅粙鎴犫偓?閻熸粎澧楅幐鎼侇敊瀹ュ鏅悘鐐跺亹閻熸繈鎮规担鍦憙闁诡垬鍊楅埀?*闂?
   *   闂?20ms 闂?7 闁汇埄鍨庡鍥ц€块梺褰掓涧椤戝棛鈧灚宀搁獮搴敆閸愨晛闂梺?swiper 闂佹眹鍔岀€氼參宕曟繝姘畱鐟滃海鍒掗幘顔肩闁靛鍊楅閬嶆煕鐎ｎ偆鐜荤紒杈ㄧ箞閹峰啴鎸婃径灞炬瘞闁诲繐绻楃划楣冨礂濮椻偓楠炴帡濡疯閸氣偓闂佽　鍋撻悹楦挎閸熸煡鏌曢崱妤€浜扮紒?
   *   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈夋煂濠婂牆绫嶉柛顐ｆ礃閿涚喓绱?*闂佸憡鐟禍婊冿耿?婵炴垶鎸堕崐妤咃綖閹烘挶浠氶柛妤冨仜琚熼梺鍝勫€婚幊鎾舵閿熺姷宓侀悹楦挎閹?闂佸搫鍟抽崺鏍ㄦ櫠閻樿瀚夊璺侯儏婢瑰牆鈽?*闂佹寧绋戦懟顖炴偩閻樺磭鈻旂€广儱妫欑瑧闂佸憡鏌ｉ崝搴ㄥ极妤ｅ啫绫嶉柛顐ｆ礃濮ｆ劙鏌曢崱鏇燁樂缂佲€冲暞缁嬪顓奸崱妯烇箓鏌ゆ總澶夌敖缂侀硸浜畷锝夊磼濞戞瑦顔?闂佺偨鍎查弻锟犲焵?
   *      闁诲海鎳撻崯顖毼?闂佸憡甯囬崐鏇㈡偩閹岀叆婵﹩鍓欒闂佸搫瀚烽崹浼村箚娴ｅ湱顩风€广儱鎳忛煬顒勫级閳哄倻顬兼い?闂佹眹鍔岀€氫即宕虫导鏉戝唨濡炲娴峰畷鍫曟煥濞戞澧旂紒?`PULL_ANCHOR_RETRY_MS = 32` 闂佸憡鑹炬總鏃傜博閹绢喖绠戠憸鎴濐啅濠靛鏅璺虹墐閸?
   */
  private lastScrollAtMs: number = 0;

  /**
   * 婵＄偑鍊曢悥濂稿磿閹绢喗鐒介柨婵嗘噺閸?闂傚倸鎳忛崝鏇㈡嚋娴煎瓨鍊绘い鎾跺仜闂?闂佹眹鍔岀€氼噣宕戦敐澶婄闁哄嫬娴氶崥鈧梺杞扮鎼存粎妲?*闁哄鏅濋崑鐔煎磻?3 濠?*閻庢鍠掗崑鎾绘煕韫囨挾鏋冮柛銈嗙矌閹风姵鎷呴崫銉у捶闂佸搫绉村ú銏ゅ焵?
   *
   * 闂?800ms 闂佹眹鍔岀€氼噣鎮伴妷鈺佺煑闁挎繂鎳庨悘鏌ユ倵?闁哄鏅濋崑鐔煎磻?闂佹寧绋掗惄顖毼涢崸妤佲挄闁哄啫娲ㄥ瓭闁哄鏅涘ú銈咁潩閵娾晜鐓傜€广儱妫欓悡鈧柣鐘辫閸撴繈寮抽悢鐓幬?
   */
  private onDiagHotspotTap(): void {
    const now: number = Date.now();
    if (now - this.diagTapLastMs > 800) {
      this.diagTapCount = 0;
    }
    this.diagTapLastMs = now;
    this.diagTapCount = this.diagTapCount + 1;
    if (this.diagTapCount >= 3) {
      this.diagTapCount = 0;
      this.diagBadgeOn = !this.diagBadgeOn;
      // 闂?2026-10-17闂佹寧绋掓穱鍝勨枖閺囩姭鍋撻崷顓炰粧缂佽翰鍎抽幏瀣级鐠恒劎鐣甸梺鎸庣☉閻楁劙锝?`diagBadgeOnStatic` 闂備緡鍙忕徊楣冾敊瀹€鍕櫖濠㈣泛鐗冮崑?*闂婎偄娲ら幊姗€濡磋箛娑樼闁归偊鍓﹂崵鐘绘煕?*闂?
      //   闂佸憡鐟禍锝夘敋閻楀牏鈻旂€广儱鎳庨弲?= 閻庢鍠掗崑鎾绘煕韫囨碍鐝俊妤€鐗婂璇差煥閸愨晝顦ラ梺?false闂佹寧绋戦悧鎾诲磻閸涱収娼伴柨婵嗘绗?闂佹椿娼块崝宥夊春濞戙垺鍎岄柛濠勫枔閻涙挸鈽夐幘顖氫壕闁?闂佹眹鍔岀€氼剟鎳滄导瀛樺亹閻犱礁婀辩粈鍡涙煏?
      PlaybackPage.diagBadgeOnStatic = this.diagBadgeOn;
    }
  }

  /**
   * 闂佺娉涢敃銈囩礊鐎ｎ喖绀堢€广儱顦禍婵嗏槈閹绢垰浜炬繛鎴炴尰瑜板啴宕规禒瀣妞ゆ棁妫勯濠氭煙鐎涙ê濮冮悶姘充含閹壆浠﹂悾灞炬喕缂備焦顨愮紓姘辨啺閸℃稒鏅?*闂佸憡鐟禍婊冿耿椤忓嫷鍤楅柤鎭掑劤閸ㄨ偐鈧鍠掗崑鎾绘煟椤愮喎浜鹃梺鍝勫暞閸庡ジ鎯冮悢鍏煎仺?*闂佹寧绋戦ˇ顓㈠焵?
   *
   * 濠殿噯绲界换瀣博鐎涙ǜ浜滅憸鐗堝笒閸樻挳鎮楅悽鍨殌缂併劍鐓″鐢割敆閸愵亝鐎梺琛″亾缁绢厼鎳愮粻鏍煙鐎涙澧柍褜鍏橀崑鎾绘煟閵堝棗鐏辩紒璇插暣閹啴宕熼鍡╀紘婵炴垶鎼╂禍婊堝垂娴犲妫樻い鎾卞妿缁€澶愭煕濞戞粍顥夐柟顔芥礃缁嬪鎯斿┑鍡樻殨闂佹椿鍠曠粈渚€鎮鸿閳绘捇宕楅崫銉紘婵炴垶鎸撮崑鎾绘倵閻㈠灚鍤€缂併劍鐓￠弫?
   * ```
   *   sess   = morphSessionStarted        闂佹寧绋戦悡?3闂佹寧绋掗懝楣冩晬閹炬湹娌柛灞捐壘閸ゆ帡鎮硅濞撳湱妲愰幍顔藉珰婵犲灚鎸剧粈?
   *   usable = morphUsable                闂佹寧绋戦悧鍡涘吹閹寸偞濯撮柡鍥╁枑绗戦梺鍛婄啲缁犳捇宕抽悜姗嗙€查柟鏉垮缁€?
   *   cont   = morphContainerActive()     闂佹寧绋戦悧鍡涱敊閹版澘闂柕濠忛檮绗戦梺鍛婄啲缁犳垵锕㈤鍥ヤ汗闁靛繒濮寸紞渚€鏌涢埡鍐ㄦ珢缂?
   *   clip   = morphClipping()            闂佹寧绋戦悧鎰八夐崱娑樼妞ゅ繐鎳忕瑧闂佸憡鐔俊鍥极閹捐鏋侀柛顐墰缁€?
   *   scale  = morphScale                 闂? = 闂佽鍘界敮鐐烘偤閹达附鏅?.08 = 閻庣懓鎲¤ぐ鍐暜閸ヮ剙绀嗛柟宄版湰瀹曟娊鏌ｉ幇顔筋仧缂?
   *   p      = morphP                     闂佹寧绋戦悧鍡涙嚋娴兼潙鐭楁俊顖濇硶缁犲骞栨潏鎹愵吅缂?
   *   real   = realCoverVisible()         闂佹寧绋戦悧濠囧箰闁秴缁╁Δ锝呭暔閳ь剙顦甸幆鍥偄妞嬪孩顔堥梻鍌氱墑閸ㄥ搫危閹间礁瑙﹂柨鏃傚亾閺嗕即鏌?
   *   clone  = morphOverlayBridging()     闂佹寧绋戦悧鍡涙晬閹炬湹娌柛灞剧矌閺佹儳顪冪€ｎ剙浠滈柣銊︾箞濡啴濮€閳╁唭锕傛煕濮樻儳顩柡渚€绠栭弫?
   *   snap   = snapStartW / miniSize      闂佹寧绋戦悧鎰板箲閿濆鍊烽柣褍鎽滅粣妤冪磽娓氬洤寮い銉悼娴滃憡绗熼埀顒€顭囬幍顔瑰亾绾懏顥夐悗?/ 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨惧畷鍥唸闂傚倸鐗滃浣烘?
   *   end    = endCoverSize / endCoverH   闂佹寧绋戦悧蹇曞垝閹剧粯鍊烽柣褍鎽滅粣妤呮煙缂併垹骞楅柡鍌欑劍閵囧嫰妫冨☉姘唸闂傚倸鐗滃浣烘?
   *   op     = backgroundRevealOpacity()  闂佹寧绋戦悧鎰板磿濡ゅ懎鐤炬い鏍ㄧ懅閻熸繈姊洪銏㈢婵″弶鍨堕幆鏃堟晜閼测晝顦?
   *   stage / drv = morphStage / morphDrive
   * ```
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡甯囬崐娑㈩敋閹殿喗鍟哄ù锝呮惈娴狀垶鏌ㄥ☉妯煎闁哥喐鎹囧畷鐑藉Ω閵娧咁啇闂備焦褰冮惌澶屾濠靛鍋ㄩ柕濠忕畱閻撴洟鐓崶褏浠涢柡鍡欏枔閳ь剚绋掗〃鍡楊渻閸岀偛绠ｉ柟杈剧到濞堟壆鈧湱顭堝畷顒勵敋椤曗偓瀹曪綁宕欓妶鍥╊槴闂?
   * 閻?`clone=1` 婵?`real=0` 闂?闁诲繐绻嬬欢姘焽閹殿喗瀚氶柕澹嫭娈告繝銏㈡嚀閸熷潡鎯囬弶妫靛綊顢欓懖鈺傚嬀闂佹椿婢€缁鳖喚妲愰柆宥嗗殣闁靛鍎冲灞解槈閹剧鏀婚柣銉ユ嚇瀵?闂?闂?`snap/end` 闂佸搫瀚烽崹浼村箚娓氣偓濡啴鎮欓悜妯笺偐闂?
   * 閻?`clone=0` 婵?`real=1` 闂?闁诲繐绻嬬欢姘焽閹殿喗瀚氶柕澹嫭娈搁梺鍦檸閸樹粙寮担骞夸簻闁汇垹鐏氶弳浼存煥濞戞澧﹂柛瀣嚇瀵喚鎹勯搹瑙勬疁闂侀潻璐熼崝宀勵敊閹版澘闂柕濞炬櫅濞咃繝鏌ㄥ☉妯侯殭缂佽鲸澹嗛幃顕€顢曢妶鍥╃闂佽　鍋撻柟鎯ф噽缁€鍡涙煥?
   * 閻?`clone=0` 婵?`real=0` 闂?**婵炴垶鎸堕崐娑氱博閻斿吋鐒鹃柟瀛樺笧閻熸繈鏌?*闂佹寧绋戦悧鍡楊潩閵娾晛鍙?闁诲海鎳撻懟顖炲矗韫囨挴鏌﹂柍鈺佸暞缁犳帡鎮樿箛搴ｇ獢婵?闂佹眹鍔岀€氫即宕戦崨顔锯枖妞ゅ繐瀚崺宀勬煟濡鍟囩紒杈ㄥ哺閺?
   * 閻?`op=0.04` 婵?`p闂?` 闂?闂佺厧鍟块張顒€鈻嶅▎鎾崇婵娅曞畷铏叏濠靛嫬鍔电紒杈╂禇op=1` 闂?閻庡湱顭堝璺侯嚕瑜旀俊?
   */
  private refreshDiagText(): void {
    if (!this.diagBadgeOn) {
      return;
    }
    const e = this.expandState;
    // 闂?2026-10-16闂佹寧绋戦悧蹇旀櫠濡ゅ懎瀚夋い鎺嶈兌閸ㄥジ鎮?`b41d7e9` 闂?`c52e0a7` 闂?`d73f1b8`闂佹寧绋戦¨鈧紒鍙樺嵆閺屽洭鏁愰崟顓т紘闁哄鍎愰崰鏍ㄦ叏閻愮儤鍎嶉柛鏇ㄥ墯绗?
    //   goal 缂?2 闂佸搫顧€缁辨洖鈻撻幋锕€鎹堕柛鈩冨嚬濞硷繝鏌ゆ總澶夋捣闁伙箑顦伴幏鍛吋韫囨洜顦╃紓浣诡殢閸撴瑥煤閹捐埖鍋?`rad`/`radVis`/`edge`/`t`闂佹寧绋戦ˇ顔剧箔?
    //   "闂佸憡顨嗛悺鏇灻归崶顒€缁╅柣鎰靛墯缂嶁偓闂佸憡甯囬崐鏍х暤?闂佹眹鍔岀€氼剟鎮鹃崜褏鐭欓柛鏍电磿缁€鍒瀖orphSessionOughtToLive`闂佹寧绋戦ˇ顓㈠焵?
    //   **闂佹椿娼块崝宥夊春濞戙垹绠?濠电偛澶囬埀顒€鍟胯闂?闂佸搫鍟冲▔娑㈠储濞戙垺鍎戦悗锝庡墻閸庢垵鈽夐幘顖氫壕闁荤偞绋戦惉鐓庘枔?`sess` / `geom` 婵炴垶鎸堕崐鎾剁礊?*闂?
    //     `sess=0` 闂?婵炴潙鍚嬫穱娲儊閻ｅ本鍋栨い鎰剁悼椤忔悂鏌熼崫鍕垫Х缂侇煉绻濋弫宥夊锤閸掔剭outToDisappear` 闂備緡鍙忕徊鎯ь焽椤栨粍宕夋い鏍ㄧ〒濮婇箖鎮跺鐓庝簼閻庢哎鍊栭幏鍛扮疀閵壯咁槴闂?
    //     `geom=0` 闂?缂傚倷绀侀悧蹇涘磻閿濆绀勯柣妯夸含缁夊灝鈹戦纰卞剳缂侇喗鎸搁埢浠嬫晸閻樺弶顏￠梺?闂?闁诲骸婀遍幊鎾斥枍閹烘绠掗柟鐑樻⒒閹?闂?濠殿喗绻愮徊鎯?濠电偛澶囬崜婵嗭耿娴ｈ桨鐒婂〒姘ｅ亾婵?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鍕瘞"闂?
    // 闂?2026-10-17闂佹寧绋戦悧蹇旀櫠濡ゅ懎瀚夋い鎺嶈兌閸ㄥジ鎮?闂?**`af66eb1`**闂佹寧绋戦¨鈧紒鍙樺嵆閺屽洭鏁愰崟顓т紘闁哄鍎愰崰鏍ㄦ叏閻愮儤鍎嶉柛鏇ㄥ墯绗?*缂備焦顨忛崜娆忕暦閸曨厽鍋橀悘鐐垫櫕閸熸煡姊洪鍝勫婵?`pd=`**
    //   闂佹寧绋戦悧鎰玻閿熺姴绠ラ悗锝傛櫇閻熷繐鈽夐幙鍐х凹閻庢艾妫涚槐鎺戔攽閸繀鍖栭梺姹囧妼鐎氼噣鎮块鐐闂勫洭顢橀幖浣告瀬閻㈩垼鍠氱粈鍡涙煏閸℃鈧敻宕?**闂佹椿娼块崝宥夊春濞戙垹绠?婵炴垶鎸哥粔椋庣玻閿熺姴绠?闂佸搫鍟冲▔娑㈠储濞戙垺鍎?`pd`**闂?
    //     `pd=0/0/0` 闂?闂佸憡甯囬崐鏍х暤娓氣偓瀹曟濡歌閺屻倝鏌￠埀顒勫箲閹板灚鏂€闂佹寧绋戦惌鍌毼涢懜纰夌矗婵☆垳鍎ら煬顒€霉濠婂喚鍎庢繛?闂佸綊娼ч鍛箾?闂佺粯顨呴悧鍡欐閿熺姵鏅繛鎴烆殕瀹曟彃鈽夐幘顖氫壕闂?0 闂?闂佸搫瀚烽崹浼村垂娴犲绠叉い鏃囨閻濇洟鏌ｉ妸銉ヮ仴闁?
    const line1: string = `V af66eb1 sess=${e.morphSessionStarted ? 1 : 0} ` +
      `usable=${e.morphUsable ? 1 : 0} geom=${e.morphGeomReadyNow() ? 1 : 0} ` +
      `cont=${e.morphContainerActive() ? 1 : 0} ` +
      `clip=${e.morphClipping() ? 1 : 0} scale=${e.morphScale.toFixed(3)} p=${e.morphP.toFixed(3)}`;
    const line2: string = `real=${e.realCoverVisible() ? 1 : 0} ` +
      `clone=${e.morphOverlayBridging() ? 1 : 0} ` +
      `snap=${e.snapStartWVp().toFixed(0)}/${e.miniSize.toFixed(0)} ` +
      `end=${e.endCoverSizeVp().toFixed(0)}/${e.endCoverHVp().toFixed(0)} ` +
      `op=${this.backgroundRevealOpacity().toFixed(3)} stage=${e.morphStage} drv=${e.morphDrive}`;
    // 闂?缂備焦顨忛崗娑氱箔娴ｇ儤鍋樼€光偓鐎ｎ剛鐛ラ梺纭呯焽閸愩劎鍘梺鍛婄墬濡炰粙銆傞埡鍐笉婵°倕顑囩粈?*婵炴垶鎸哥粔鍫曞极?hdc 婵炴垶姊婚崰鏇㈠礂濮椻偓瀵粙宕ㄦ繝鍐块獜闂佷紮绲介惌鍌炲磻閸涱喚闄勬俊銈勭劍濞堝爼鏌?*闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
    //   `usableH` 闁圭厧鐡ㄥ鍦偓鍨矒瀵噣鎮╅崹顐ｇ彧 `winH 闂?padTop 闂?max(avoidBottom, bottomGap)` 缂備胶濮甸〃鎰?
    //   `padBot` 闁荤姴娲╅褔宕哄畝鍕剭闁告洦鍋€閸嬫捇鎮℃惔锝呯暔婵?`gap` 闂佸憡甯楅〃鎰濮楊枦LL 65闂佹寧绋戦ˇ顔剧博閹绢喗鍤婇弶鍫濆⒔缁€鍕⒒閸曗晛鈧繂顭囬鍡忓亾閸︻厼浠︾紒浣规尦閺屽棝鎳楅锝呮暏闂佸憡鐗滈崕銈夋儊椤旈敮鍋撻悷鏉挎殺缂佺粯娲樺鍕檪缂佽鲸宀告俊?
    const line3: string = `usableH=${e.usableHVp().toFixed(1)} padBot=${e.padBottomVp().toFixed(1)} ` +
      `avoid=${e.navigationBarBottomVp.toFixed(1)} gap=${e.chromeBottomGapVp().toFixed(0)} ` +
      `gapScrub=${e.chromeGapScrubVp().toFixed(0)} tier=${e.chromeTier}`;
    // 闂?缂備焦顨忛崜娆徝洪幘鑸靛仒鐎光偓鐎ｎ剛鐛?*闂佸搫鐗滈崜婵嬫偪閸℃稒鍎嶉柛鏇ㄤ海閳峰牆鈽夐幙鍐х盎濠殿喒鏅滈幏鍛煥閸♀晛鎮侀梺?*闂佹寧绋戦悧鍡涘垂?婵炲濯寸徊鍧楁偉濠婂牆瀚夊璺侯儑濮婇箖鏌￠崼婵愭Ъ缂佹劕娲畷?濠殿噯绲鹃弻銊╁垂娴犲纾归柛蹇撳悑缁绢垶姊婚崼銏犘㈠褏濞€閺佸秴鐣濋崘鐐秳闁诲孩绋掗〃鍡涱敊鐏炶В鏋栭柕濞炬櫅濞呯偤鏌ㄥ☉姗嗘Ф闁?
    //   闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戝娌穉l 缂?2 闂佸搫顥￠幍鍐蹭壕鐎光偓閸曗斁鍋撴径鎰棃闁靛繒濮垫俊鍥偡濞嗘劕绗掗柛鐔插亾闂佸搫绉归弲鑼博閹绢喗鐒肩€广儱鍟犻崑鎾愁吋閸ャ劎鏆?*闂佺厧顨庢禍锝夋儊婢跺濯?* 闂佺偨鍎查弻锟犲焵?**閻庤鐡曠亸顏堫敇閻熼偊娼伴柨婵嗙墢缁犳牕鈽夐幘顖氫壕濠?*闂?
    //
    //   闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹褰掝敄閸ャ劎鈻旈柍褜鍓熼幃褔宕奸悢鑲?`rad`/`radVis` 闂備焦褰冪换鎴﹀垂濮橆厾顩?`morphRadius` 闂佺偨鍎查弻锟犲焵?**闂備緡鍙忕徊鎯?闁诲骸婀遍幊鎾斥枍閹烘鍤婃い蹇撳缁?闂佹眹鍔岀€氼剙銆掗崜褎鍠?*闂?
    //      婵炴垶鎸哥粔闈浳ｉ崫銉ょ剨濞撴埃鍋撴繛闂村嵆閹啴宕熼锝咁洭闁荤喐鐟︾敮顏嗘濠靛洨鈻旈柕鍫濈墐閸嬫捇宕ㄩ鍙?*婵炴垶鎸堕崐鏍ь焽椤栫偞鍋戞い鎺戝€昏ぐ宀勬煟閵娿儱顏柟?*闂佹寧绋戦悧鍡涘春閸℃搴ㄥ礄閵堝洨顦梺?
    //   ```
    //     闁诲骸婀遍幊鎾斥枍閹烘鎹堕柛鈩冨嚬濞?morphRadius = initRadiusVisual 闁?(1 闂?t) / scale
    //        閻?闁荤姍鍥舵闁?= 闁哄鏅炲〒鍦礊濮椻偓瀵爼妾遍柛蹇撶焸瀹曡埖绻濋崒娑橆洭闁荤喐鐟︾敮鐐测枔閹寸偟鈻旈柍褜鍓熷畷鈩冪節韫囨洜顦紓鍌欑閻楀繘宕?= **0**闂佹寧绋戦悧鎾诲箺闂堟侗鐓ラ柍銉ョ－濞?闂?闁诲骸婀遍幊鎾斥枍閹烘挾鈻旂€广儱鐗滈崵澶愭煛閸繍妲告繛鎾冲⒔閹叉挳骞掗悙鐢殿槴
    //        閻?闂佸搫鍟版慨鐑藉疾椤愶箑瑙﹂悘鐐佃檸閸庛儵鏌ㄥ☉娆戞懀pplyPullProgress 闂?radius 闂佸憡甯掑Λ娆撳极椤曗偓閺?1054-51086闂?
    //        闂?闂佸湱顣介崑鎾趁?t=0 闂佸搫鍟冲▔娑㈡偩閻樿绠板璺哄瘨閸熷酣鎮规担娴嬪亾閾忣偆娈ら梺?0 闂佺偨鍎查弻锟犲焵?闂佺懓鐡ㄩ崹褰掝敄閸ャ劎鈻旈柍褜鍓熼幃褔宕奸悢椋庢啨闁诲海鎳撻崯顐ょ礊?闁诲繐绻嬬欢姘焽娴兼潙鎹堕柛鈩冨嚬濞?闂佹寧绋戦惌渚€顢氭导鏉戞瀬闁瑰嘲鑻▓浼存煟閹烘洘纭鹃柛娆忕箻瀵?0闂?
    //
    //     闁诲繐绻嬬欢姘焽娴兼潙鎹堕柛鈩冨嚬濞?coverLocalRect().radius = lyricMorph(t).radius
    //        閻?闂佸搫鍟版慨鐑藉疾?`radiusAt(t) = visualRadiusAt(t) / scaleAt(t)`
    //          闂佺绻戝﹢褰掓嚈?`visualRadiusAt(t) = lerp(radiusPlayer, radiusLyricVisual, t)`
    //          `radiusPlayer = 8`闂佹寧绋戝濯ie.pa:85761 ldai 0x8闂?
    //          `radiusLyricVisual = 12`闂佹寧绋戦悧鍡涘箖閹捐绫嶉煫鍥ㄦ尵閸╂姊洪幓鎺楃崪缂?
    //        閻?闂佸搫鐗滈崗娑氬垝?`lyricMorph()` 闂備焦褰冮懟顖氼潩閵娾晛鍙?`lerp(COVER_RADIUS_PLAYER_VP(8), COVER_RADIUS_LYRIC_VISUAL_VP(12), p)`
    //        闂?婵炴垶鎸堕崐妤咁敂?*闂備緡鍋呴崝鏇㈡偤瑜庣粙澶愬焵椤掑嫭鍤?*闂佹寧绋掗?0 闂?8闂佹寧绋掔涵?1 闂?12
    //   ```
    //   闂?闁哄鏅滈悷銈囩博鐎靛憡鍋樼€光偓閳ь剟鐛崶顒€鎹堕柕濞炬櫅濞呫倝鏌ｉ妸銉ヮ仾婵?*闁诲繐绻嬬欢姘焽娴煎瓨鐒介柨婵嗘閽傚姊?*闂佹寧绋戝濉㏑ad` / `cRadV`闂佹寧绋戦悾?= cover闂佹寧绋戦¨鈧紒?
    //     濡ょ姷鍋炲﹢鍦崲濮樿埖鍋╂繛鍡楁禋閸熷洭鏌涢敐鍐ㄥ闁稿鎳樺鍫曞煡閸涱垳顦ーrad`/`radVis`闂佹寧绋戦ˇ顔界閹烘挾鐟归柛顭戝櫘閸ょ娀鏌?闂佺偨鍎查弻锟犲焵?婵炴垶鎸堕崐鏍ь焽椤栫偞鐒鹃柤鎭掑劚閳敻鏌涢幋鐘插妺婵炶偐鏁婚弫宥囦沪閼测晩浼囬梺娲讳海婢瑰牓宕楀鈧畷姘跺幢濮樿泛鎽甸梺?
    //   闂佸憡甯囬崐娑㈩敋娴煎瓨鏅慨婵囶劗=0` 闂?**cRad = cRadV = 8.00**闂佹寧绋掗惌鏉?1` 闂?**12.00**闂?
    //         閻熸粏鍩囬崹纭呫亹婢跺鈻?`cRadV = cRad 闁?morphScale` 闁圭厧鐡ㄩ弻銊╋綖閹邦喚纾奸柛顐ｇ箖闊?**8~12 婵炴垶鏌ㄩ澶娢?*闂佹寧绋戦悧鍛箔婢舵劖鈷?scale 闂佺鍩栭悧鏇熸叏閳哄懏鏅璺虹墐閸?
    //   婵犮垼娉涚粔鐢告偋閹惰棄绀傞柕澶堝劚缂嶆捇鏌ㄥ☉娆庝孩缂佺粯鐩幃娆戞喆閸曨剙鍟婇梺琛″亾濡わ絽鍟ㄩ埀顒€顦蹇涙晜鐠恒劎鎲柣?3 濠电偛鏋撮幍鍐蹭壕?
    const coverRect: LyricMorphRect = this.coverLocalRect();
    const line4: string = `remeasure=${this.diagRemeasureTries} overlayKick=${this.diagOverlayKicks} ` +
      `seek=${e.chromeSeekSize().toFixed(0)} edge=${coverRect.size.toFixed(0)} t=${this.lyricMorphT.toFixed(2)} ` +
      `cRad=${coverRect.radius.toFixed(2)} cRadV=${(coverRect.radius * e.morphScale).toFixed(2)} ` +
      `rad=${e.morphRadius.toFixed(2)} radVis=${(e.morphRadius * e.morphScale).toFixed(2)}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*goal 缂?1 闂佸搫顥￠幍鍐蹭壕閻忕偠妫勭敮妤€菐閸ワ絽澧插ù鐓庢噽閹壆浠﹂悜鈺佷壕鐎广儱娲﹂悾閬嶆煟濠婂嫭绶叉繝褉鍋撻梺鐓庮殠娴滐綁鎯?闂佺偨鍎查弻锟犲焵?缂備焦顨忛崗娑氱箔娓氣偓閹囧醇椤掑倻顦梺鍛婂竾閸婃盯顢氶弶娆惧晠闁圭粯甯為弳鎵磼?*闂?
    //   `metaTop` = 闂佸搫鐗滈崜婵嬨€?*闂佹椿浜為崰搴ㄦ偪閸曨偁鈧帡宕ｆ径灞藉脯闂?* = `metaTopGeomY(t, rowH)`闂佹寧绋戦悧鍡楊潩閵娾晛鍙婃い鏍ㄧ懅閻熸劙姊婚崼娑樼伈闁稿鎳樺?`.position().y`闂?
    //               **闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳濮ｆ劙鏌℃担钘夌劷闁逞屽厸閻掞箓鎯€閸涙潙瀚夊璺虹焾閸庢垵霉濠婂啫顨欓柛鐐€楅幃浼村Ω閵婏箑娑ч悗?*闂佹寧绋戦¨鈧紒?
    //   `metaOld` = **婵炴垶鎸搁敃锝囩博閹绢喗鍋嬮柛顐犲劚娴滄繈鏌℃竟婧垮€曞▓浼存倵鐟欏嫯澹樼紒鎲嬬磿閳?*闂佹眹鍔岀€氼剟鍩€椤掑倶鈧妲愬淇祔ricMetaMorphY(t) + t闁?size闂佹剚鍘芥慨鐨亀H)/2`闂?
    //               闁?`metaTopInUseYAt()`闂佹寧绋戦惉濂哥嵁閸ヮ剙鎹堕柕濞垮劚濞懷囨煟椤剙濡虹紒顭戝墰閳ь剛鏁搁、濠冨緞閸曨垱鏅?*婵炴垶鎸哥粔鎾疮閳ь剟鏌涘▎蹇撯偓椋庣箔鐏炲鈧帡宕ｆ径灞藉脯**闂佹寧绋戦¨鈧紒?
    //   `metaD`   = `metaOld 闂?metaTop`闂?
    //   ## 闂佸憡甯囬崐娑㈩敋娴煎瓨鏅柛顐ｇ矎閳峰牏绱掗弮鎴濈仸闁稿繑锕㈠?*閻庤鐡曠亸娆撴偂閿涘嫭鏆滈柛娑橈攻濞?*闂佹寧绋戦張顒佹櫠瀹ュ棛顩烽柕澶堝妿缁犵懓鈽夐幘顖氫壕闁荤偞绋戦惉濂哥嵁閸ヮ剙鎹堕柕濞垮劚鐠佹煡鎮归崶锔筋樂闁告艾顦甸弫?
    // ```
    //   t = 0闂佹寧绋戦悧鍡涙儍濠靛顥堥柕蹇嬪€戦埀顒€顦甸弫宥嗗緞濞戞氨鐛etaD 闂?**闂?0**
    //       闂佺偨鍎查弻锟犲焵?闂佸搫鍞查崘顏嗩攨闁诲孩绋掗崝妤€鈻?from 闂?`LYRIC_META_GAP_VP(10)`闂佹寧绋戦悧濠傦耿閻楀牏顩烽柟鐐絻瀵兘鎮楃憴鍕闁逞屽墰閵嗗妲愬鑸垫櫖?
    //          闂佸搫鍊瑰妯兼閿涘嫧鍋撳☉娆忓闁?`COVER_FIT_META_GAP_VP(50)`闂佹寧绋戦悧濠偽涢妶澶嬪仼?`fitPlayerOverlay` 闂佹眹鍔岀€氼噣鍨鹃弽顐ょ＝闁哄稁鍋嗛崹?a8闂?
    //          闂?闂佸搫鍞查崘顏嗩攨闁诲孩绋掗崝鏍儊椤曗偓瀵剟寮剁捄銊ь攨闁诲孩绋掗崝娆撴偟?40vp 闂?metaOld 闂?metaTop = 闂?0
    //   t = 1闂佹寧绋戦悧濠囨偤閺囩姵瀚氱€广儱顦埀顒€顦甸弫宥嗗緞濞戞氨鐛etaD 闂?**闂?.64**
    //       闂佺偨鍎查弻锟犲焵?闂佸搫鍞查崘顏嗩攨闁诲孩绋掗崝鏇㈠春?闁诲繐绻愮换鎰版儍濠靛顥堥柕蹇嬪€戦埀顒€锕ュ?+ (size闂佹剚鍘芥慨鐨亀H)/2"闂佹寧绋戦張顒勫蓟婵犲偆鍤曢煫鍥ㄦ尵閹藉秹鏌?闁诲繐绻愮换鎰版儍濠靛顥堥柕蹇嬪€戦埀顒€锕ュ?+ 28 闂?rowH/2"闂?
    //          婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲骸螣?= 28 闂?size/2 = 28 闂?48.72/2 = 3.64 闂?闂佸搫鍞查崘顏嗩攨闁诲孩绋掗崝娆撴偟?3.64vp
    //   闂?婵炴垶鎼╅崢浠嬵敊瀹€鍕強妞ゆ牗绻勭粻鐟扳槈閹惧崬鈧顢旈鍕剭闁告洦鍘煎▓鐘绘煙椤戭剙瀚徊濠氭煕婵犲嫷鍎犻柍?
    //   闂佸疇娉曟刊瀵哥箔?闂?t=0 婵?metaD 婵炴垶鎸哥粔闈浳?闂佹剚鍠栭悧鍐垂?0闂佹寧绋戦悧鍛閵夛缚绻?闂?闂佹寧绋戦ˇ顐﹀闯?闁荤姴娲ら悺銊ノ?`bigEndpointRect()` 婵炴垶鎸搁柊锝夊磻閸涙潙绾ч柍鈺佸暞閿涘鈧鍠栫换鎰版偤?
    //      闂佹椿娼块崝搴♀枔閹达附鍎楅柍杞版祰閸╁矂鏌℃径鍫濆姕缂侇煈鍠楃粙澶婎吋閸涱喖鈧亶鏌ㄥ☉妯煎婵☆偒鍋勯锝堢疀閹捐埖鎲ら柣?`lyricMetaFromYOf()`闂佹寧绋戞總鏃傛偖闁秵鍤€闁告稒娼欓崢鎾煕閳哄嫭銆冪紒?`bigEndpointRect`闂?
    //      闂佽崵鍋涘Λ婊堫敊閹寸偟鈻斿┑鐘插€归崐杈ㄧ節瑜庨崝褏妲愬璺虹伋闁哄倽銆€閸?闂備緡鍙忕徊鎯ь渻閸岀偛绠ョ€广儱顦版禒姗€鎮烽弴姘卞妽闁绘搫绻濇俊?
    // ```
    const metaTop: number = e.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const metaOld: number = e.metaTopInUseYAt(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const line6: string = `metaTop=${metaTop.toFixed(1)} metaOld=${metaOld.toFixed(1)} ` +
      `metaD=${(metaOld - metaTop).toFixed(1)} (t=0 闂佸搫鐗忛崰鎰耿?闂?0 / t=1 闂佸搫鐗忛崰鎰耿?闂?.6) ` +
      // 闂?2026-10-17闂?*闁哄鏅滈悷銈囩博閹绢喖绾ч柍銉ュ暱閸ゆ帞绱撴担鍝ョ缂?閻庡灚婢橀幊鎾活敋娴煎瓨鍎嶉柛鏇ㄥ亜閻忔煡鏌?闂傚倸瀚粔鑸殿殽閸ャ劎鈻?缂傚倷鐒﹂幐濠氭倵椤栨稓鈻旂€广儱鎳庣紞渚€姊洪幓鎺旂闁圭晫濞€瀹?**闂佹寧绋戦¨鈧紒?
      //   `lBox` = 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闂傚牊绋戦弫鍫曟倵閻熺増璐℃繛鎻掓嚇閹?*缂備焦鍔栭〃鍛般亹濞戞瑣浜滈柟顖涘閻?*闂佹寧绋戝濉篹portLyricBoxTop` 闂佸摜濮撮崑濠勬濮樿泛违?
      //   缂傚倷鐒﹂幐濠氭倵椤栨稓鈻斿┑鐘插暕閼割亜鈽?**0**闂?闂?闁诲繐绻楁ご绋课?Swiper 闂佹眹鍔岀€氼喖煤閸涘瓨鏅€光偓閸愶絽浜?Swiper 闂佸湱顣介崑鎾绘煕閿斿搫濡挎繛?`Column` 婵?
      //   `LyricFloatLayer()` 闂佸搫瀚烽崹浼村箖閹惧鈻旈柍褜鍓氱粙澶愵敂閸愵亞鎲归柣?padding 闂?`Stack` 闂佹眹鍔岀€氼剟顢楅姀鈶╁亾濞戞瑥濮х紒杈ㄧ箖缁嬪寮崶璺烘畽 `Stack`
      //   闂佹眹鍔岀€氼剟宕€电硶鍋撻悷鐗堣础婵炴彃鎳庨蹇涙晜鐠恒劎鎲柣?= 缂備焦鍔栭〃鍛般亹濞戙垹鍌ㄩ柣鏂挎惈娴?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻張顒勫汲閿濆洦瀚氬ù锝囨嚀缁侊箓姊洪悙顒€绀冩い?`PlayerExpandState.lyricBoxTopVp` 闂?JSDoc闂?
      //   闂?`lyricPadTop()` 闂備緡鍙忕徊鎯ь焽?缂備焦鍔栭〃鍛般亹濞戙垹閿ら柟閭﹀幘閸?+ 23"闂佹眹鍔岀€氼剛妲愰敍鍕ㄥ亾?*閻庤鐡曠亸娆戝垝?*缂備焦绋戦ˇ顕€鎮抽娑氼洸閹兼番鍨洪敓銉╂煟閿濆懐鐏辨繛鍫熷灴閹嫰骞掗幋婵囨殽閻庢鍠栫换鎰版偤?闂?
      //     **婵炴垶鎸哥粔鐟般€掗崜浣瑰暫濞达絿鎳撴惔濠勭磼閻樻剚娈ｇ紒杈ㄧ箖缁嬪﹪鎮㈤崜浣烘喒闂婎偄娲ら幊搴ㄥ疮閳ь剟鎮归崶銊︻潡缂佺粯鐗楃粙澶愵敂閸涱喗顔嶆繛瀛樼矊濡酣鍩€?*
      //   闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯浼寸嵁閸ヮ剙鎹堕柕濞垮劚濞懷囨煛閸繍妲风紒鏂跨摠缁嬪顢旈崱妯绘闂備緡鍋呭Λ鎴犳?*闂佸吋鐪归崕閬嶆儍閵忋倕绾ч柕澶涢檮缁犳帒霉濠婂棙顏犵紒顔诲嵆閺屽洭鏁愰崟顔规嫛闁诲繒鍋涢崐鍛婃叏閻愬顩?padding闂佹寧绋戦惌浣烘崲閺嶎厽鐓傞悘鐐跺亹缁愭鎮归崶顏嶅殭闁糕晛鐭傚鐗堟償閵忊檧鏋栭梻?0** 闂佺偨鍎查弻锟犲焵?
      //     闂備緡鍙忕徊鎯ь渻閸岀偛绠ョ€广儱顦版禒姗€鎮烽弴姘卞妽濠?`lyricPadTop` 闂佺懓绠嶉崹娲垂?`(濠电偞鎯岄崰鏍儑閻楀牊鍎熼柡鍥风磿閻?闂?lBox) + 23`闂佹寧绋戦悧鍛博鐎靛憡鍋樼€光偓鐎ｎ剛顦梺?
      //   闂佸疇娉曟刊瀵哥箔?闂佸憡鏌ｉ崝搴ㄥ极閻愵剛鈻旀い鎾跺仧閺嗗﹪鏌涘▎妯虹仴闁稿繑锕㈤幆澶愵敆娴ｈ妲梻?0闂佹寧绋戦悧鎾诲磻閸涙潙鍙婃い鏍ㄥ嚬閸熷洭鏌涢敐鍐ㄥ鐟滄澘顦甸獮鎴﹀閿濆洨鐣洪梺?`globalPosition.y`闂佹寧绋戦張顒勵敆濠婂懏鏆滈梻鍫氭櫇缁€鍡涙煃?闂?*闂傚倸鐗婇悷锕傤敆濞戙垹绠?*闂佹眹鍔岀€氼垶顢氭导鏉戞瀬闁煎壊鍏橀崑?
      `lBox=${e.lyricBoxTopVp.toFixed(1)}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*"濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闂傚牊绋撳▓閬嶆⒒閸稑鐏柣銉ユ嚇瀹曪絽螣閾忚鐦?闂佹眹鍔岀€氼喖煤閸ф绠抽柕澶堝劚閻忔煡鏌?*闂佹寧绋戦惉濂稿极閵堝绠ｅ瀣閸╁倿鏌￠崼銏犲妺闁糕晛鎳樺畷鍫曞箚瑜庨崐鐢告煕閺冨倸顎撶紒杈ㄥ哺閺?
    //   闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸虫俊鏉戠暆閸愵亞顔愰梺鍝勫閸ㄩ亶鎮洪弴鐘冲珰鐎广儱顦埀顒€顦甸弫宥呯暆閸曨偂绨兼繛鎴炴惄娴滄粓鎯冨┑瀣棃闁靛骏绱曞楣冩煕濞嗘兎顏堟儍椤掑嫬违鐎广儰绀佸▍?闁荤姴娲ㄧ划顖炲汲?`t=0.00 edge=331`闂?
    //   闁诲繐绻嬬欢姘焽閹殿喕鐒婇柛婵嗗閸?= `lyricMorph(lyricMorphT).size`闂佹寧绋戦惌渚€鍩€?`lyricMorphT` 闂佸憡鐟禍婵嗭耿?0/1 婵炴垶鎸堕崐鎾绘煂濠婂懐鐭欓柛鎰皺閺嗕即鏌涙繝鍕┾偓瀣?
    //     閻?`t=0` 闂?闁诲繐绻嬬欢姘焽?= `endCoverSize`闂佹寧绋戦悧濠囧汲閿濆洨鐜绘俊銈呮噹娴滄繂鈽夐幘顖氫壕婵?闂?331闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闁诲繐绻楁ご绋课ｉ幖浣瑰仺闁靛绠戦悡鏇㈡煟椤忓嫷鍎忛柛鈺佺焸閹啴宕熼鐘辨捣闁诲繐绻嬬欢姘焽娴煎瓨鏅?
    //     閻?`t=1` 闂?闁诲繐绻嬬欢姘焽?= `lyricCoverSizeOf()`闂佹寧绋戦悧鍡涙儍椤掑倷鐒婂〒姘ｅ亾婵?闂?48.72闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闁圭厧鐡ㄥ鐟帮耿娓氣偓閹啴宕熼鍌氼棊闁诲孩绋掗崝鎴﹀焵?
    //   闂?闂佸湱顣介崑鎾趁?濠电偛澶囬埀顒€鍟跨紞渚€鎮? 闂?**`lyricMorphT` 濠电偛澶囬埀顒€鍟块悡?1**闂侀潧妫楅崐鐣屾崲閺嶃劎鈻旈柍褜鍓涢幃鏉跨暆閳ь剙煤閸ф绠抽柕澹懓鍩楅梺鍛婂灥閹碱偊鎮鹃悩宕団枖閺夌偞澹嗛惌鍡椻槈閺傝法澧涢柣銉ユ嚇瀹曟氨鏁鍓х崶
    //     閻?`sw`  = `playbackSwiperIndex` 闂佺偨鍎查弻锟犲焵?**婵炴垶鎸哥粔闈浳?1** 闂?闂佸搫绉烽～澶婏耿閺夊簱鏌﹂柍銉ュ暱閻庡ジ鏌涢幒鏂款暭闁烩剝娲滈幏鐘差吋婢跺牃鍋撴径鎰櫖闁割偆鍠庨悘妤冪磼娓氬灝鐏╃紒鎵佹櫇閹噣顢曢姀鈺傂╂繛杈剧到缁嬪嫮妲?
    //     閻?`tgt` = `lyricMorphTarget`   闂佺偨鍎查弻锟犲焵?婵?`sw` 婵炴垶鎸哥粔宕囩博閹绢喗鍤?闂?闁荤偞绋忛崕闈浳涢崸妤€妫橀柣鐔哄閸婂鏌涘▎蹇曅＄紒?/ 濠电偛澶囬崜婵嬪极閸︻厺鐒?
    //     閻?`vis` = `lyricMorphVisible`  闂佺偨鍎查弻锟犲焵?`0` 闂?`lyricFloat()` 闂佸憡甯囬崐鎾舵嫻閻斿摜鈻旂€广儱鎳庣拋鏌ユ煟閵忊晝鍘滅紒杈ㄧ箞瀵偊寮堕幋顓燁唶婵＄偛顑囬崑鐘汇€侀幋婵冩煢闂勫洭骞?
    //     閻?`sg` / `fs` = `lyricSwiperSettled` / `lyricFlightSettled` 闂佺偨鍎查弻锟犲焵?婵炴垶鎸堕崐婵單涢崼鏇炵闁斥晛鍟·浣圭箾瀹€瀣瘈缂?
    const line7: string = `sw=${this.playbackSwiperIndex} tgt=${this.lyricMorphTarget ? 1 : 0} ` +
      `vis=${this.lyricMorphVisible ? 1 : 0} op=${this.lyricMorphOpacity.toFixed(2)} ` +
      `sg=${this.lyricSwiperSettled ? 1 : 0} fs=${this.lyricFlightSettled ? 1 : 0} ` +
      `lcEdge=${e.lyricCoverSizeOf().toFixed(1)} lcY=${e.lyricCoverYOf().toFixed(1)} ` +
      `float=${e.lyricFloat() ? 1 : 0}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*Swiper 闂佹悶鍎抽崑鐘绘儍閻旇　鍋撻崷顓炰粶鐎?* 闂佺偨鍎查弻锟犲焵?闁荤喐鐟ょ粈渚€鎮鸿閳?`diagAnimStart` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煥?
    //   `ast=-1--1` = `onAnimationStart` **婵炴垶鎸撮崑鎾寸箾閸☆厾绡€闁稿繑锚閳讳粙妾辩紒缁橈耿瀵爼濡烽妸褏鐣?*闂佹寧绋戦悧鍐闯?闂佸憡甯掑ú顓㈠Υ婢跺ň鏌﹂梽鍥憘鐎ｎ亶鐓ラ柟瀛樼箓琚熼梺鎼炲劤閸嬬娀鎯冮悢鍏兼櫖濠㈣埖绋撻獮?
    //   `ast=0-1` + `skp>0` = 闁哄鏅滅粙鎺戭焽閸偆顩查柛鈩冩礈缁嬪鎮跺鐓庝簻闁伙急鍥х妞ゆ劧绲介惃锟犳煙閸濆嫷妾х紒杈ㄧ懇閸?闁荤喐娲戦悞锕傚极閼测斁鍋撻悷鎵鐎规洖銈稿畷姘跺Χ閸℃銈﹂梺鎸庣☉椤р偓缂?
    //   `chg=1/闂佺偨鍎哄▔?闂?`sw=0` = swiper 闁荤姳闄嶉崐鎾舵嫻閻旂厧鎹堕柕濠忓閹藉啴鎮归崶褏效闁靛棗顦垫俊瀛樻媴閸濆嫅锕傛煙椤戣法顦︾€规挸鐗忛幏瀣箥椤旂晫绁?0闂佹寧绋戦悧鍐闯?闂佺粯顭堥崺鏍焵椤戣法鍔嶉柣銉ユ嚇瀹曘儳浠︾紒銏犲Ρ闂佹寧绋戦ˇ顓㈠焵?
    const line8: string = `ast=${this.diagAnimStart} skp=${this.diagAnimSkip} ` +
      `aend=${this.diagAnimEnd}/${this.diagAnimEndCount} ` +
      `chg=${this.diagChg}/${this.diagChgCount}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闁哄鏅滅粙鎴犫偓鐟板暱閳瑰啴骞囬姘唶闁?* 闂佺偨鍎查弻锟犲焵?goal 缂?1 闂佸搫顦崜婵堚偓鍨皑閳ь剝顫夊銊モ枔?`swiperProgress` 缂備焦绋戦ˇ顕€鎮抽鐐村亱闁冲搫顑囩粈鍡涙煥?
    //   `scr` = `onContentDidScroll` 闂佹眹鍔岀€氼垶鎯冮悢鍏煎仺闁靛瀵岄崑褔鏌℃担绋跨盎缂?*闂備緡鍋呴崝鏇㈠箮?*闁荤喐鐟辩粻鎴ｃ亹閸岀偞鏅€光偓閸愮偓缍勯柣搴ゎ潐钃遍柡?SDK 闂佸憡顭囬崰鎰板几閸愵喗鏅鑸电〒楠?
    //   `last` = 闂佸搫鐗冮崑鎾绘煕濮橆剛鍑圭紒鏃€娼欓埢搴ㄥ灳瀹曞洦婢栭梺?`index/position`闂?
    //   闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴顫濋璺ㄤ笉闂侀潻璐熼崝宥夋偤閺囩姵瀚氱€广儱顦埀顒€顦靛顔炬崉閾忕懓鐣ㄩ悷婊呭閹告儳锕㈤崨鏉戠?**`last=0/1.000`**闂佹寧绋戦悧濠偽涢妶澶嬪仼閻忕偞鍎虫儫 `position` 婵犮垹澧庨幊鎾诲春?1闂?
    //   婵炴垶鏌ㄩ鍛村箖?`index === 0` 闂佸綊娼х粔闈浢洪崸妤€妫橀柤鍓插厴閸嬫挻鎷呴悷閭︽殹婵炲濮伴崕閬嶆偩閻樼數鐭欓柛鎰皺閺嗕即鏌涚€ｎ偆鐭婃繝鈧?1闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂備緡鍙忕徊鎯ь渻?`lyricMorphT` 婵炴垶姊婚崰搴ｈ姳閸欏鈻?1闂?
    //   闁诲繐绻嬬欢姘焽?`edge` 闁圭厧鐡ㄩ弻銊ㄣ亹婢舵劕绠ｉ柟閭﹀墰濮ｅ牓鎮樿箛搴ｇ獢婵為棿鍗抽弫宥夊醇濮橆剦鏆?8.7闂佹寧绋戦ˇ顓㈠焵?
    //   `scr=0` 闂?闁哄鏅滈悷銈夋煂濠婂牆鐐婇柣鎰濞堣泛鈽夐幘顖氫壕濠电偛妫寸换婵嬪礂濡　鏌﹂梽鍥杺闂佸憡鐟﹂崺濠勬濞嗘垶鍟哄ù锝囨嚀鎼村﹪寮堕埡鍌溾槈閻庣懓鍟块埞鍐箛閸撲胶顦梺?
    const line9: string = `scr=${this.diagScrollCount} last=${this.diagScrollLast}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺绻戞繛濠偽涚€靛憡宕夋い鏍ㄦ皑缁愮偤鏌ｉ妸銉ヮ伀妤犵偛娲畷閿嬨偊濞嗘儳娈洪梺?* 闂佺偨鍎查弻锟犲焵?闂佹椿娼块崝宥夊春?23:19/23:20 婵炴垶鎸搁ˇ鏉款焽椤栫偛鐭楃€广儱顦藉ú顖炴煟閵娿儱顏╅柣锝囧亾閹峰懎顓奸崶銊︽闂?
    //
    // 闂佹椿娼块崝宥夊春濞戙垹鐭楃€广儱顦藉ú顖炴煥濞戞澧曢悽顖ｅ亞閹风姴鈹戦崶鑸垫悙闂佺懓顨庨崜銊ф濮樿埖鏅?
    // ```
    //   闂?闂佸搫鐗嗛ˇ鏉款渻?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柣銏犲濞存洖顪冮妶鍛倎缂佹鎳樺顒勬偡閺夋寧顓绘繛鎴炴惄娴滄繄鈧灚绮撻弻锕傤敊閼姐倗妲忔繛鏉戝悑瀹€绋库枔閿濆瀵?
    //   闂?"闁哄鏅滈弻銊ッ洪弽顓炵闁规儼濮ら敍鏃堟煙缂併垹骞楅柡鍌欑窔瀹曟娊濡搁敃鈧悘澶愭煕濞嗘劕鐏╂鐐叉处缁嬪顓奸崱妯烇附绻涚仦鍕╁€曢崜褰掓煛閸滀礁鐏茬紒杈ㄧ箖閹峰懘鎮╅崹顐ょ暯闂備緡鍙忕徊鑲╃博閹绢喖绾ч柍钘夋噽缁€澶愭煛?*闂佸搫鐗嗛ˇ鎶藉磿濡ゅ懎鐤炬い鏍ㄧ懅缁嬪鏌￠崟闈涚仸闁绘繍鍠楅幆鏃堟晜閹屾婵?*"
    //   闂?"婵炴垶鎸搁鍡樺垔濞差亜绀傞柟鎯板Г閿涙棃鏌熺紒銏犲箺闁哄倷绶氬畷鎶藉Ω閵壯勵唸闂傚倸鐗勯崹鍝勎ｉ崨濠冧氦婵炲棗閰ｉ崵瀣倶韫囨挾绠版繛鎾村礃閵囨劙锝為鍓ь槷闂佺粯甯熷▔娑㈠箖濡ゅ懎绀夐柕濞у嫭姣庣紓鍌欑劍閹歌顭囬锝囶洸?*缂備焦鍔掗懗鍫曞礉瑜斿鍫曞Ψ閵堝娈濋柣蹇曞仦濞叉牜妲愰幋锕€绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ婵炲牊鍨垮畷婵嬪Ω瑜庨弳?*"
    // ```
    // 闁哄鏅滈悷銈囩箔娓氣偓瀵爼鏁撻悩鎻掑箣闂佸憡鐟﹂崹褰掑极閹捐鎹?*闂佺绻戞繛濠偽涚€涙ɑ浜ら柛銉㈡杹閺屻倕鈽?*闂佹寧绋戦惌渚€鍩€椤掆偓婵傛梻绮崒鐐搭棃?1~9 闁荤偞绋戦懟顖炲Φ閸ャ劌绶炴慨姗嗗幗绗?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝囩摂閸ゃ垽鏌? 闂?闂婎偄娲ら幊姗€濡磋箛鏇熷仒闁靛鍔庣粻鐟扳槈閹绢垰浜鹃柣鐐寸☉鐞氼偊鍩€?
    //
    // 闂佸憡鑹剧€氫即宕冲ú顏呭剭闁告洦鍋勯悘鏌ユ偣閸ワ妇涓茬紒?
    // ```
    //   show  = 婵犮垻鎳撻崯鍧楁儑?isShowPlay闂侀潧妫楅崐鐢稿箟?闂佹眹鍔岀€氼剟濡甸弮鍫濈煑鐎瑰嫭澹嗚ぐ宥夋煟閵堝棗鐓€缂佸彉鍗抽幊鐔煎Ψ閵壯勬疁闂侀潻璐熼崝宀勫矗瑜斿濠氼敇閳垛晛浜鹃柡鍌涘礃閸橆剟鏌涘▎鎯奉亜煤?true闂?
    //           婵犮垻鎳撻崯鍧楁儑?`@Monitor('appState.isShowPlay')` 婵?`pushPlayerRoute()`
    //           闂?**闂備焦褰冪粔鐢稿蓟婵犲洤绠抽柕濞垮劚瀵啿鈽夐幘顖氫壕婵炴垶鎼╂禍婵嬪蓟婵犲洦鍎嶉柛鏇ㄥ墯鐏忥繝鏌￠埀顒併偅閸愶腹鍋撴径灞稿亾閸︻厼浠掔紒?* 闂?闁诲繐绻楁ご绋课?闂佸憡鐟ラ悧濠囧棘娴ｅ湱鈻旈柍褜鍓熼弻鍡楊吋閸涱垱缍岄悗娈垮枓閸?
    //   clos  = isClosing闂佹寧绋戦悧鍡涘矗瑜斿濠氼敇閵忊剝鍤戦柣鐘辫閸ㄤ即宕欓敍鍕皫闁告垯鍊楃粈?
    //   coll  = 闂佺鐭囬崘銊у幀闂佸憡鐗曢幖顐﹀礄閿熺姴缁╅柟顖滃瀹曟娊鏌ㄥ☉妯煎闁?闂佹眹鍔岀€氼喖煤閸ф绠抽柕澶樼厛閸ゃ垽鏌℃担绋跨盎缂? = 闂備緡鍙忕徊浠嬪吹閹寸偟鈻旀い蹇撴噹閻﹀姊虹粵瀣灍婵″弶鎮傞幐濠呯疀閺囩喓绁烽梺姹囧妼鐎氬摜妲?
    //   p     = morphP闂佹寧绋戦悧鍡涘矗瑜斿濠氼敇閻斿壊妲梺?0 闁荤姍鍐ㄧ盎缂?
    //   clipH = **闂佸憡鍔栭悷銊ф崲濡皷鍋撻崷顓熷殌婵?`.height()` 闂佹眹鍔岀€氼垶藟閸℃稑绀堟い蹇撴瀹曞爼鏌涘▎娆戠М闁?*闂佹寧绋戦悧鍐箟?闂佹眹鍔岀€氼喖煤閸ф绠抽柕澶樼厛閸ゃ垽鏌℃担绋跨盎缂?
    //           闂佺厧鍟块張顒€鈻嶅▎鎾冲強妞ゆ牗鍑归崯鍥煕閿濆啫濡挎繛鍫熷灩閳ь剚绋掗崝妯讳繆椤撱垺鍊?闂?闁诲骸婀遍幊鎾斥枍閹烘梹鍋栨い鎰╁労濮婂潡鏌熺€涙ê濮囨い锔藉椤ㄥ洤顫滈崼銏㈩槷闂佺厧鍟块張顒€鈻嶅▎鎴滅剨闁告鍋涘☉褔鏌ｉ姀锝庡殭妞わ附瀵ч〃鍥ь潨閸垻顦?
    //           闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝呮憸鐎?= 0闂佹寧绋戦悧濠囶敆濠靛绫?`.height()` 闂佸憡鍔曢幊姗€宕曠€靛憡灏?'100%'闂佹寧绋戦¨鈧紒閬嶄憾瀹曟骞庨懞銉川婵炴垶鎼╅崢铏规閻楀牊浜ら柣鎰暩閺侀箖鏌涘▎鎯奉亪宕?闂?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩闈涜拫
    //   bg    = 闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本鐟ч悷婵嬫⒑椤愩垻绠叉俊鍙夊灦閹棃鏁傞懖鈺冾槱闂?闂佹椿浜滈鍛存偩閻樿瀚夊璺侯儑濮婇箖鏌￠崼婵愭Ъ妞ゎ偓绠戣彁闁斥晛鍟粩鎾煥?
    //   drv   = morphDrive闂佹寧绋戝﹢妗癗GER/ANIM/NONE闂?
    //   sq    = morphSquashY闂佹寧绋戦悧鎰板箚閵堝棙濯寸€广儱妫楅惃銊╂煕濡警鍎滅紒杈ㄧ箞閸? 闂佸搫鍟冲▔娑橈耿椤忓嫷鍤曢柣褍鎽滅粈?
    //   pd    = **闁荤姾娅ｉ崰鎰櫠?闁荤偞鍑归崑鍛偓?闁荤姳璁查崜婵嬪汲?*闂佹寧绋戦悧鍐ㄎ?2026-10-17 闂佸搫鍊瑰姗€路閸愵喗鏅€光偓閳ь剙煤閸ф绠抽柕澶堝€涚粈瀣煟椤剙濡介柛鈺傜洴閹啴宕熼埞鎯т壕閻忕偠鍋愰悷鎰節婵犲啫鐏ｇ紒妤€顦甸幊妤呭磹閻旈攱顔囬梺娲绘線缁屽爼鍩€椤掆偓缁嬪嫮妲?
    //           `<闁荤姍鍥ㄦ暠濠⒀勭矒楠?/<闂佸搫娲ら悺銊╁蓟婵犲洤绠?/<闂佸搫顦遍崑鎾存櫠濠婂牆绠?`闂?*缂備線纭搁崹鐢割敇閹间礁纾圭紒妤勩€€閸嬫挻鎷呮搴ｆ喒濠电偞鎸搁幊妯好?*闂佹寧绋戦悧鎾诲闯閹间礁瑙?App 闂佸綊娼х粔瀵哥礊婵犲洦鈷栭悹浣告贡缁€鍡涙煏?
    //           闂佹椿娼块崝宥囨兜閸洘鏅慨妯诲墯閸炪劎鈧灚濯芥慨銈夋偉閿濆拋鍤曢柍褜鍓熼幆鍫ュ焵?闂?闂佺顑嗛惌顔剧博閺夋垟鏋庨柍銉ㄥ皺閻熸劙鏌?闂?闂佹椿浜滈鍫㈡崲閺嶃劎鈻斿璺侯樀閸ゅ鏌?*闂佸搫鐗嗛ˇ浼存儉閸涙潙瀚夊璺猴工缂?*闂?
    //           閻?闂佸憡鐟︾湁缂?闂?闂侀潧妫楁總鏃傜箔婢跺本宕夐柣鏃傤焾椤や線鏌曢崱妤冃ｆ俊?*闂佸憡甯囬崐鏍х暤?*闂佸綊鏀辩敮鐐测枔閹达附鏅悘鐐跺亹閻燁剙鈽夐幘顖氫壕闂佹椿浜ｉ崑鎰耿閸涙潙绀勯柣鎴炆戠瑧闂佸憡绻嶆禍娆戠博鐎涙鈻旀い蹇撴捣缁?
    //              缂?1 婵炴垶鎼╂禍婵堚偓?= 闁荤姍鍥ㄦ暠濠⒀勭矒閺屽洭鏁愰崟顓т紘闂佸憡甯熼褔宕甸幋鐐村闁哄洨鍠撳楣冩⒑閹绘帞绠荤紓宥呯墦閺佸秹宕奸姀锛勫嚱闂佽浜介崕鐢稿箺闂堟侗鐓ラ幒鎶藉焵椤戣法鍔嶆俊顐犲€楅幑鍕偄缁嬫鏉归梺鍛婃煟閸斿酣寮ィ鍐╂櫖?
    //                          闂?闂?`measureMiniDuringPull` / 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍩勯崘鈹箓鏌涘鍓х暠闁告埊绻濋獮鎰板磼濠靛洨銈伴梺?
    //              缂?2 婵炴垶鎼╂禍婵堚偓?= 闂佸綊娼ч鍡欌偓鍨哺瀹曠兘濡搁妷銉愭霉?`pullDragging` 闂佸搫瀚烽崹鐗堢閿濆鏅柛顐ゅ枑閹疯京绱掗銈囧笡婵炴挸鐖煎畷锝夘敍濠婂嫮鈧潡鏌ｉ妸銉ヮ仹缂佹梹鎸冲鍫曞煡閸涱垳顦?
    //                          闂佸憡锚濡銇愰懜鐢碘枖濠电姴鎳愮粻鐟扳槈閹绢垰浜剧紓渚囧亯椤曆囧礄閿涘嫮纾奸煫鍥ㄦ尭濮ｅ寮堕埡浣圭煑閻炴艾宕埢搴ㄥ灳閾忣偆顦ラ悷婊呭鐢亞妲愰悧鍫熷€時ound-36 闂?`staleClr`闂?
    //                          闂?闂?闁荤姴顑勯悞锔戒繆?`pullDragging` 濠电偞鎸搁幊蹇涘垂濮橆厾顩查柛鈩冦仦濞?闂?
    //              缂?3 婵炴垶鎼╂禍婵堚偓?= 闂佸搫顦遍崑鎾存櫠?闂佸憡鐟﹂悧妤冪矓妞嬪孩鍋栨い鎰╁灩閻忔煡鏌熺拠鈥虫灍閻庢艾妫濋弫宥夊醇閻斿憡姣嗛柣蹇撶箳閸嬫捇鎯€閸涱垱灏?闂?婵＄偑鍊楅弫璇差焽娴兼潙纭€闁炽儴娅曢煬顒勬煕濡も偓閿曘劑鎯屾ィ鍐╂櫖濠㈣泛鐗冮崑?
    //           閻?婵炴垶鎸撮崑鎾斥槈閹垮啩閭柛蹇斆埢浠嬪灳閸愯尙绉?闂?闂佸憡甯囬崐鏍х暤娓氣偓瀹曟濡歌閺屻倝鏌￠埀顒勫箲閹板灚鏂€ 闂?闂傚倸鍋嗛崳锝夈€傛禒瀣嵍?*(b)婵炲瓨绮岄鍕枎?闂佸綊娼ч鍛箾瀹ュ洦瀚氶柛鈩冾殔閻?闂佺粯顨呴悧鍡欐?*闂?
    //             **婵炴垶鎸哥粔鐑姐€呴敃鍌氱鐎广儱鎳庣粻鐢告煕閺傝濡垮┑顔芥倐楠炩偓濞达綀顫夌花?*闂佹寧绋戦悧鍛村箞閵娿儮鏋栭柡鍥╁仧閺嗘岸鏌涜箛瀣缂佹顦靛畷銉ョ暆鐎ｎ剛顦梺?
    //           闂佸疇娉曟刊瀵哥箔?缂?2 婵炴垶鎼╂禍婵單?*闂佸湱顭堥ˇ鐗堟櫠濠婂牆绀夐柤鎰佸灱閸氣偓濠?*闂佹眹鍔岀€氬摜妲愬▎鎰枖闁逞屽墮閳诲酣鍩勯崘顭戞澒闂佸憡姊圭€笛冦€掗懜闈涚窞?+1闂佹寧绋戦¨鈧紒杈ㄧ箘閹?
    //              `Index.pullDropCountedThisGesture` 闂佹眹鍔岀€氼垶顢氶埡鍛強閹煎瓨绋堥崑?
    // ```
    const line10: string = `show=${this.state.isShowPlay ? 1 : 0} clos=${this.isClosing ? 1 : 0} ` +
      `coll=${this.chromeCollapsed ? 1 : 0} p=${e.morphP.toFixed(2)} ` +
      `clipH=${e.morphClipHeight.toFixed(0)} bg=${this.backgroundRevealOpacity().toFixed(2)} ` +
      `drv=${e.morphDrive} sq=${e.morphSquashY.toFixed(3)} ` +
      `pd=${e.pullDropBegin}/${e.pullDropUpdate}/${e.pullDropEnd}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佸憡鍔曢幊搴敊閹邦喕娌?onAppear 闁荤姍鍥舵殥缂侇煉绻濆畷顐︻敂閸涱喛鎷梺鍛婂笒濡瑩寮?* 闂佺偨鍎查弻锟犲焵?闁诲氦顫夐惌顔剧礊?闂佺绻戞繛濠偽涢幘顔艰Е閹肩补鈧啿鐝橀梺琛″亾闁告瑣鍎抽閬嶆⒑椤掆偓缁夋挳鎯堝鍜佸殨闁?闂佹寧绋戦¨鈧紒?
    //   `ab` = morph闂佹寧绋戦悧鍡涙嚋娴兼潙鐭楁俊顖氭惈閻庡鏌￠埀顒勵敍閵堝洨顦┑顔界箰缁蹭粙鎮ラ崼鏇熸櫖? intro闂佹寧绋戦悧鎰板箲閿濆棛顩?playExpandIntro 闂?闂佺绻戞繛濠偽涢幘顔肩睄閻犲搫鎼В澶愭煟濠婂嫭绶茬€?bug闂?
    //        / skipClose闂佹寧绋戦悧鍡涘储鐟欏嫭鍎熼柡鍥╁仜閻庡鏌￠埀顒勵敍濞嗘垹蓱闁?濠殿喗绻愮徊钘夛耿椤忓牆绀傞柟鎯板Г閿?闂佹眹鍔岀€氭澘螞椤掑嫬绠柨鏃囨硶閻熸捇鏌ㄥ☉妯绘拱婵犫偓閻楀牊濮滄い鏃囧Г閻撯偓婵犫拃鍛壋缂?
    //   `ap` = introPaintReady闂佹寧绋戦悧濠囧汲閿濆棎浜滈柣銏㈡暩鐢盯鏌涢幒鎴犲煟婵☆偒鍓熼弫?
    const line11: string = `ab=${this.diagAppearBranch} ap=${this.introPaintReady ? 1 : 0} ` +
      `stage=${e.morphStage} exit=${this.expandIntroRunning ? 1 : 0} bgBox=${this.diagBgBox} ` +
      // 闂?2026-10-17闂佹寧绋掗悺鐚癳sh` = 缂傚倸鍟崹鍫曟偋缁嬪簱鏀﹂柟閭﹀墯闊剙鈽夐幘宕囆㈡繝鈧鍫熸櫖? = 闁荤姍鍕凡闁告顫夐幆鏃堝即閻愯尙鎮奸梺鍝勭Ф閺屽绔熸繝鍕勃闁稿矉濡囩粈澶愭⒑椤撱劎鍒伴柣?*闁?alpha**闂佹寧绋戦ˇ顓㈠焵?
      //   闂佸憡甯囬崐鎴﹀焵椤掆偓閻ジ宕戦敐澶婄缂備焦蓱鐏忥繝鏌￠埀顒勬倷椤掍浇鎷梺鐟扮仛閹稿摜妲愰幋婵冩煢闁斥晛鍟粻鎺楁煠閸愬弶婀版繛鍛懇婵℃潙顓艰箛鏇犵崶`mesh=0` 闂?闂佸搫瀚烽崹鎷屻亹閸ヮ剙鐐婂Δ锝呭暞閹崇姵绻涚仦绯曞亾閼碱剛鎲梺鍝勵槶閸庤崵妲愬▎鎾村剳?`RzdBgRetry`闂佹寧绋戦¨鈧紒?
      //   `mesh=1` 闂佸吋婢橀懟顖炴儓閸℃鈻斿┑鐘辫兌閻繃绻涚仦绋垮⒉婵犫偓?闂?闂佸搫瀚烽崹宕囧垝椤栫偛绀?闁荤喍妞掔粈浣圭珶閳ь剟鏌ｉ妸銉ヮ仹缂併劊鍔戦弫宥夊醇閵忥紕鐣?`bgBox` 婵?`clipH`闂佹寧绋戦ˇ顓㈠焵?
      `mesh=${this.meshSrc !== undefined ? 1 : 0} ` +
      `lcl=${PlaybackPage.lastCloseAtMs > 0 ? (Date.now() - PlaybackPage.lastCloseAtMs).toFixed(0) : 'never'}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺鐭囬崘銊у幀闂佸憡鐗犵紓姘跺吹濠婂懏瀚?* 闂佺偨鍎查弻锟犲焵?闁诲氦顫夐惌顔剧礊閸涘瓨鍋ㄩ柕濠忕畱閻撴洜绱?1 闂佸搫顥￠幍鍐蹭壕閻忕偟鍋撶粻鎺楁煛閸愨晜鏋勭紒妤€鎳樺顒勬偡閺夋寧顓绘繛鎴炴惄娴滄繄鈧灚绮撻弻锕傤敊閼姐倗妲忔繛鏉戝悑瀹€绋库枔閿濆瀵犻煫鍥ь儌閸嬫挸顓艰箛鏇狀槴
    //   闂婎偄娲ら幊姗€濡磋箛娑欏殑闁芥ê顦悗濠氬级閸稑濮€缂佺粯鐗楃粙澶嬪緞瀹€濠冪稈閻熸粏鍩囬崹缁樻叏閹间焦鏅柛顐ｇ矋閸欏繑绻涙径瀣闁伙綆鍓熷畷妤呭Ω閵堝洨鎲归梺鍛婅壘閻妲愬鑸垫櫖?
    //     闂?闂佺厧顨庢禍婊勬叏閳哄懎缁╅柟顖滃瀹曟娊鏌ㄥ☉妯煎ⅲ妞ゆ梹娲滈幏瀣妞ゃ垺鍨剁粙澶愭偖鐎靛摜鐛ラ梺鍝勫暟婵兘寮?`IDLE_MS = 5000`闂佹寧绋戦懟顖濄亹瑜斿畷?`isPlay` 闂佸搫鍟晶搴ㄥ极閹捐鏋侀柛顐墰缁€?
    //        闂?`cc=1` + `cpr=0` + `chH` 濠殿喗绻愮徊浠嬫偉?闂?**婵炴垶鎸哥粔闈浳?bug**
    //     闂?闁荤偞鍑归崑澶愃夐崱娑樼濠㈣埖绋撶粈鍕倵閸︻厽鍤€婵炲懏甯為幉妤佹媴缁嬫姊剧紓浣瑰姈椤ㄥ懓銇愬☉銏犵濠电姴鍟禒姗€鏌涢幒鏇熺【閻忓浚鍨跺畷姘跺炊閵娿儳顏遍梺鎸庣☉椤︻偊宕?`clipH` 閻庡灚婢橀悧鍡涙儍椤掑嫭鍤€?`chH` 濠殿喗绻愮徊浠嬫偉?闂?闂佸搫瀚烽崹浼搭敊閹版澘闂柕濞垮劚濞堛倕霉閿濆棙绀堟繛鍫熷灦缁?
    //     闂?婵°倕鍊归敋閻庣娅曠换鍛暆閸曨剦浠﹂梺鎸庣☉濞煎〈yricChromeHeight` 闂備焦褰冪换鎴﹀垂?0 闂?`.height(0 * progress)` = 0闂?
    //        闂?`chH=0` 闂?闂?*闂備焦褰冪换鎴犵矈?*闂佹眹鍔岀€氼亞鑺遍妸鈺傛櫖闁秆冨煇yricChromeMeasurePending` / `wasConstrained` 闂備緡鍙忕徊鎯ь焽椤栫偞鐓ｉ柟鎯ф噽缁€?
    //   `cpr` = lyricChromeProgress闂? = 闂佺绻堥崝宀勫吹椤撱垹违? = 闂佺绻堥崝宥夊极瑜版帗鏅鑸电〒楠烆晢chH` = lyricChromeHeight闂?
    //   `ofs` = chromeOffsetY闂佹寧绋戦悧濠囧极閸︻厽灏庨梺鍨儐椤ρ冣槈閹炬剚鍎戞禍?46vp闂?
    const line12: string = `cc=${this.chromeCollapsed ? 1 : 0} cpr=${this.lyricChromeProgress.toFixed(2)} ` +
      `chH=${this.lyricChromeHeight.toFixed(0)} ofs=${e.chromeOffsetY().toFixed(0)} ` +
      `pend=${this.lyricChromeMeasurePending ? 1 : 0} play=${this.state.isPlay ? 1 : 0}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?缂備焦顨忛崗娑氳姳閼碱剚鍋樼€光偓鐎ｎ剛鐛?*闂佸憡鏌ｉ崝瀣礊閺冣偓濞碱亪濡搁妸锕€顫?*闂佹寧绋戦悧濠傘€掗懜鍨氦?6 婵炴垶鎼╂禍婊勬叏閳哄倹濯存繝濠冨姉缁€澶愭煙缁嬫妲哥憸鏉垮€块幃浠嬫偄缁楄　鍋撴惔銏″劅?`>` 闁哄鏅濋崑鐐垫暜閹绢喗鏅璺虹墐閸?
    //   婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ゅ枑娴犳﹢鏌￠崼婵愭Ш闁轰降鍊濋弫宥咁潩瀹曞洨顔愰梺鍝勵檧缁绘繈骞楅崗鑲┾枖?婵＄偑鍊曢幖顐よ姳?闂佸搫鐗滈崜婵嬫閳哄啩鐒婇弶鍫涘妽绗戦梺鐓庮殠娴滄粏銇愭径鎰厒闊洦娲橀悾閬嶆煛閸艾浜炬繝銏犵垻閸愶絽浜?闂佺偨鍎查弻锟犲焵?
    //   闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳濮ｆ劙鏌℃担瑙勭凡闁告ɑ绋撻幏顐﹀礃椤撶姷顔庨梺鍝勫閸ㄤ即骞冨Δ鍐╁闁告劘娉曠粈澶岀磽娴ｈ灏伴柣蹇擃槺閳ь剛鎳撻懟顖炲矗韫囨梻鈻旂€广儱鎳忛崐閬嶆煥濞戞鍙?3 闂?`onAppear` 闁荤姴娴傞崹浼村垂娴犲违濞?03 闂?
    //   `onDisappear` 闁荤姴娴傞崹鍗烆焽閸愵喗鐒鹃柤鎭掑劜绗戞俊鐐€曢幖顐よ姳椤撱垺鈷掓い鏇楀亾妞わ絼绮欓弫宥嗗緞濞戞氨顦梺鍏兼緲閼活垱鏅堕悩璇茬倞婵炴垶绮犻弨浠嬫煕濞嗘ü绨芥繝鈧崨顓у殫婵°倐鍋撻柛?閻熸粎澧楅幐鍛婃櫠閻樿纾?闂?
    //   闂佸憡甯囬崐娑㈩敋閹殿喚鐭嗛弶鐐村娴兼劙鏌ㄥ☉妯煎ⅱ闁稿缍佸畷娆戠磼濡　鍙洪悗娈垮枓閸嬫捇骞栫€涙ɑ鐓ョ紓宥咁儔閹洨鈧綆浜滈悡鍌炴煟閵娿儱顏╅柤闀愬嵆閹晝鎷嬮崷顓狀槴闂?
    //     `clickOpen>beginOk>settle0C>settle1C>measOk>tween`  闂?婵炴垶鎸撮崑鎾绘偣娓氼垰鐏ラ柧鏂款儔閺?
    //     `clickOpen>beginOk>settle0C>settle1C>闂佺偨鍎哄▔锕傛煥濞戞澧涙俊?measOk闂佹寧绋戦ˇ顐﹀闯?闁荤偞绋忛崕鐢稿闯閻戞鈻旈柍褜鍓熼幆鍕偓娑欘焽濮婇箖鏌熺€涙ê濮囧┑?
    //     `clickOpen>skip`                                     闂?闁?`pullDragging`/闂佺儵鏅犻弲鑼礊閸涙潙绠伴柍銉ㄥ皺閸?
    //     `闂?tween>settleSkip`                                 闂?闁荤偞绋忛崕闈浳涚捄銊﹀皫闁炬艾鍊婚崯濠偯归敐鍛棥闁诡垬鍊栭幏鍛吋閸偅钑夐柣鐘叉惈閻ゅ洨鎹㈤崘顔芥櫖闁?04 闂備緡鍙忕徊璺ㄦ偖椤愶附鏅?
    const line5: string = `trace=${e.morphTrace.length > 0 ? e.morphTrace : '(empty)'}`;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*缂備焦顨忛崜娆忕暦閸曨剛鈻斿璺哄瘨閺€浠嬫煥濞戞瑨澹橀柛娅诲洦鈷掓い鎿勭磿缁犳牜绱?婵帗绋掗崹鐢典焊閸懇鍋?** 闂佺偨鍎查弻锟犲焵?闁荤姴娲ㄧ划顖滄兜閸撲焦鍠?{@link PlaybackPage.evLog}闂?
    //   婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劜娴犳﹢鎮烽弴姘鳖槮闁伙絿濞€閺佸秴顫濇潏銊︽闂佽鎸抽弨杈ㄦ叏閵堝鍎嶉柛鏇ㄤ海閳峰牓鏌℃径鍡橆潐缂佽鲸鐟╂俊瀵镐沪閽樺缍橀梻鍌氬亞閸樿棄顪冮崒鐐村殑閻忕偟鍋撻悵顖炴煕濞嗘ü绨诲褎瀵х粙澶愬焵椤掑嫬绾ч幒鎶藉焵椤掆偓缁夋煡鍩€椤掆偓閼活垶宕ｈ濮婂顢橀悙鏉戔偓鐢告煕濞嗗繒澧涢柡鍌欑劍缁嬪鍩€椤掑嫭鐒肩€广儱鎳愬鏃傗偓娈垮枓閸嬫捇鏌曢崱妤冣枌缂?
    //   **闂備緡鍠涘Λ鍕亹閸岀偞鍋ㄩ柣鏃堟敱闊剟鏌涜箛鏂库枙婵☆偄鐡ㄥ濠氬炊閳圭偓鐓犳繛鎴炴惄閸欏繒妲愬┑瀣殌鐎光偓閸曨偂绨兼繛鎴炴尨閸嬫捇鏌涢幒鏇ㄥ殭缂佹劖锕㈠浠嬪炊瑜嶉崵鎺楁⒒閸涱厾绠查柟鎼佷憾瀵劍銈ｉ崘锔瑰亾婢跺鈻旈柍褜鍓涢幐褔鏌ㄧ€ｎ儷銉ヮ熆?* 闂?婵炲瓨绮岄鍛村箖濡ゅ啯瀚氶悹浣哥－閻熸繈鏌涢幒妤婃殥闁瑰箍鍨洪幏鍛村即濮橀硸鍋ㄩ柣鐔割殙閿熴儵鍩€?
    //   闂?婵炲瓨绮岄鍕枎閵忋垺濯奸柡澶嬪闊?*濠碘槅鍨埀顒冩珪閸嬨儳绱掗悪娆忔处妤楊垶鏌熼鑳厡妤犵偛妫滈妵鎰板閵忋垹顦╅梺?*闂備焦褰冮惌澶屾濠靛牏椹冲璺侯槺閻熸挸鈽夐幘顖氫壕濠电偛妫岄崜婵囨櫠閿曗偓椤曪綁鍩€椤掑嫬绠绘い鎾跺枑閺夌懓顪冮妶澶嬫锭闁哥啿鍋撻梺鍝勫婢т粙濡?闂?闁诲繐绻楁ご绋匡耿娴ｅ湱顩查柛鈩冩礈閻熸劕鈽夐幘顖氫壕濠电偛妫岄埀顒€鍟胯ぐ鐘绘⒒閸屻倕骞樻繛鍫熷灩閳ь剛鎳撻張顒勫汲閿濆绫嶉悹楦挎绾板秹鏌?
    //
    //   闂佸疇娉曟刊瀵哥箔?闂佸搫瀚晶浠嬪Φ濮樿泛绫嶉柤鎼佹涧鎯?`|` 闂佺懓绠嶉崹娲垂濮樿泛绠查柕蹇ョ秵閺€浠嬫煥濞戞瑧鐓紒鏂款嚟閹壆浠﹂懖鈺婁紘婵炴垶鎼╂禍娆戣姳閵婏妇顩烽悹浣告贡缁€澶娾槈閹绢垰浜鹃悗娈垮枤婵敻宕洪崨鏉戠倞闁诡垎鍕闂佺厧鍟块埀顒傚櫏閸ゃ垽鎮?
    //     闂佹寧绋戦悧鍛箔婢舵劕绠查柕蹇ョ秵閺€浠嬫煟閵娿儱顏柣锕佸Г濞煎骞嬪┑鍡欙紟闁诲孩绋掗〃鍫ヮ敄娴ｇ懓顕辨慨姗嗗幖閻ㄣ劑鏌熺€涙ê濮冪紒鏃€鎸冲畷鎼佲€﹂幒鏃傤槷11fp 婵炴垶鎸搁鍛村吹閹寸偟鈻曢幖瀛樼箘閻熸繈鏌涘▎妯虹仴妞ゆ洑鍗抽弫宥嗗緞閸艾浜?
    const evRaw: string = PlaybackPage.evLog;
    const line13: string = evRaw.length > 0
      ? `ev#${PlaybackPage.evCount}\n${evRaw.split('|').join('\n')}`
      : `ev#${PlaybackPage.evCount} (no events yet)`;
    const next: string =
      `${line1}\n${line2}\n${line3}\n${line4}\n${line5}\n${line6}\n${line7}\n${line8}\n${line9}\n${line10}\n${line11}\n${line12}\n${line13}`;
    if (next !== this.diagText) {
      this.diagText = next;
    }
  }

  /** 闂佺厧顨庢禍锝夋儊婢跺鍤楅柤鎭掑劤閸ㄥジ鏌￠崼顐㈠幐缂傚秴顑夐弫宥夊醇閵壯勫闁圭厧鐡ㄥú婊冣枍瑜忛埀顒佺⊕閵囨粓鍩€椤戞寧顦风紒妤€顦靛畷銉╁礃瑜忛惃鎴澝归悩铏瑰牚闁逞屽厸缁€浣烘暜閸ヮ剙鎹堕柕濠忛檮娴犳ê鈽夐幘绛硅含婵為棿鍗抽弫宥嗗緞閸艾浜?*/
  @Builder
  private DiagBadge() {
    Text(this.diagText.length > 0 ? this.diagText : 'V af66eb1 (no data)')
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor('rgba(0, 0, 0, 0.78)')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(6)
      // 闂?2026-10-16闂佹寧绋掗懝鍓х玻濮椻偓瀵粙宕堕埡浣虹杸闂侀潻璐熼崝宥咃耿?**13 闁?*闂佹寧绋戦悧鍐焵椤掑﹤顩い鎴濇喘瀹曗剝鎷呮搴ｆ闁荤偞绋戦張顒傛暜閸洖绀嗛悹鍝勬惈闂呮﹢鏌ゆ總澶夋捣闁?/ 缂備焦顨忛崜娆忕暦閸曨剛鈻斿璺哄瘨閺€浠嬫煕韫囨柨鈻曟俊顐㈢摠濞煎宕堕埞鐐厾婵炲瓨绮岄鍕枎閵忋倕绫嶉柕澶堝劤缁犲爼鏌?
      //   婵炲瓨绮岄鍕枎閵忋倕绫嶉柕澶堝劤缁犲爼鏌￠崼顐㈠⒉闂傚ň鏅濇禍鍛婃綇閵娤€锕€顭块懜鍏镐孩妞ゃ垺鍨块崹楣冨棘鐞涒€充壕闁哄倸澧介閬嶆偠濞戞ê顨欑紒鏂跨摠缁嬪顢旈崘顏嗘婵炲濮鹃鎰濮樿泛鐒?`maxLines` 闂婎偄娲ら幊姗€濡磋箛鏂跨窞闁绘洖鍊荤粈澶愭煕濮樺墽鐣遍柛顭戝灦瀵敻鍩€椤掑嫬瑙﹂幖瀛樼箘椤忛亶鎮跺☉妯侯殭缂佽鲸澹嗛幃顕€顢曢敐鍛姷闂佺懓鎼ˇ顓㈠焵?
      .maxLines(32)
      .position({ x: 8, y: 120 })
      .zIndex(99)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 婵＄偑鍊曢悥濂稿磿?闂傚倸鎳忛崝鏇㈡嚋娴煎瓨鍊绘い鎾跺仜闂?闂佹寧绋掓穱铏规崲濞戙垺鍊?3 濠电偛妫岄埀顒€纾壕濠氭煕韫囨挾鏋冮柛銈嗙矌閹风姵鎷呴崫銉у捶闂佸搫绉村ú銏ゅ焵?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佽　鍋撻柟顖嗗嫯鍚?*婵＄偑鍊涢崺鏍偉椤旂晫鈻曢悗锝傛櫇閻熸捇鏌曢崱鏇狀槮闁哥偛顕埀顒€缍婇埀顒佺〒椤撳搫鈽?*闂佹眹鍔岀€氼亞绮╃€涙鈻旀い蹇撴瀹曟洟鏌℃径鍡橆潐缂佽鲸鐟﹂〃?48vp闂侀潧妫斿鎺旂箔婢舵劕绠柨鏇楀亾闁告瑥澧介埀顒傛嚀閸熲晛顫濋敂鐣岊洸闁瑰搫绉崇花鏉款熆閼哥數澧辨繛鍫熷灦缁嬪顭ㄩ崱鎰痪闂佹寧绋戦¨鈧紒?
   *   闁诲海鎳撻崯顐ャ亹瑜斿畷銉╁礃閳轰胶顏遍梺鐓庮殠娴滄粎鎹㈡担瑙勪氦婵炲棗娴烽閬嶆煛婢跺棌鍋撳畷鍥ㄦ殧闁诲孩绋掗崝鎺旂箔閸岀偞鍎嶉柛鏇ㄥ幖娴狀垶鏌涢幋婊呬覆缂佽鲸绻冪粙澶婎吋閸涱収娈梺鍛婄箓缁夌敻骞愰柆宥呯哗?闂佸憡甯掑ú锕傛偤?濠殿喗绻傞惌渚€鎯佸┑鍡╃叆婵﹩鍓欒闂?
   */
  /**
   * 婵＄偑鍊曢悥濂稿磿?闂傚倸鎳忛崝鏇㈡嚋娴煎瓨鍊绘い鎾跺仜闂?闂佹寧绋掓穱铏规崲濞戙垺鍊?3 濠电偛妫岄埀顒€纾壕濠氭煕韫囨挾鏋冮柛銈嗙矌閹风姵鎷呴崫銉у捶闂佸搫绉村ú銏ゅ焵?
   *
   * 闂佸疇娉曟刊瀵哥箔?**2026-10-16 婵烇絽娴傞崰鏇犵博鐎涙ê绶為柛鏇ㄥ墮閻忓鏌ゆ總澶夌盎缂佽绀侀锝夊即閻愭彃姹查梺姹囧妼鐎氼亜顫濋敂鐣岊洸闁圭儤鍨剁粈鈧悷?*闂佹寧绋掑銊╊敄閸ャ劎鈻旈柍褜鍓熼幃褔宕煎┑鍡樻闂佹眹鍔岀€氼厼危?
   *   `Row().width('100%').height(48).position({x:0, y:96})` 闂佺偨鍎查弻锟犲焵?
   *   闂?*婵犮垹婀辨晶妤€危閹存繍鍤?`.onClick` 婵炴潙鍚嬬喊宥囩矓妞嬪孩瀚婚柣鐔哄閸ゆ帒鈽夐幙鍐ㄥ箹閻忓浚鍨跺畷?*闂佹寧绋戝濉噄tTestMode` 婵帗绋掗…鍫ヮ敇閼姐倐鍋撻悽娈挎敯闁搞倖绮撻悡顒勵敃閵夈儳妲洪梺?Block闂?
   *   闂?闁诲海鎳撻崯顖涗繆?96闂?44 闂?*婵炴垶鎸撮崑鎾绘煛娴ｅ摜鎽犳繛纰卞灠铻ｆい蹇撳閸婂鎮介銈囩暠闁?*闂佹眹鍔岀€氼噣宕戦敐澶婄閻犲洦褰冨鍧楁煕濮橆剙鏆為悽顖楀亾婵炲瓨绮屽Λ搴ㄥ焵?
   *   闂侀潻璐熼崝宥夋偤閺囩姵瀚氱€广儱顦埀顒€顦扮粙澶嬬節閸パ傜凹婵炴垶鎸撮崑鎾绘偨椤栥倝妾俊?*濠殿喗绻傞惌渚€鎯佸┑鍫熷仒?*闂佹寧绋戦悧蹇涘磻閿濆拋娼扮€光偓閸愵亝袚闁荤姴鎼悿鍥归崱娑欐櫖濠㈣泛妫楀▍?闂佹椿浜為崰搴ㄦ偪閸曨垰绀夐柣鏃囶嚙閸樻挳鎮跺鐓庝簼閻忓繐鎳樻俊?
   *
   * 闂?闂佺粯绮嶅妯猴耿椤忓牆缁╅悷娆忓閻?*閻庡綊娼荤紓姘辩箔閸屾粍鍠嗛柟鍝勭Ф椤忛亶鎮樿箛鎾剁婵?*闂?20闁?0 @ y=88闂佹寧绋戦¨鈧紒杈ㄧ箞瀹曪綁顢旈崶鑸佃埞闂佺儵鏅滈悧鏇㈡儍濠靛顥堥柕蹇曞С缁狀垰鈽夐幘绛归練妞ゎ偅顨婇弻鍥晲閸パ屾毈婵炴垶鎸哥粔纾嬨亹閺屻儲鍤勯柤鎭掑劜缁犳帒霉濠у灝鈧挾鑺辨导瀛樺剭闁告洦鍋勯梾姗€鏌涢埡鍐ㄦ珢缂?
   *   閻?闁诲繐绻嬬欢姘焽閻楀牄浜滅痪鏉款槺缁愭姊洪銊у缂佹柨顕弫顕€鏁傞懞銉愶箓鎮樿箛搴ｇ獢婵為棿鍗冲畷鍫曞箚瑜嶉崜濂告煛閸偄澧查梻濞炬櫊閺佸秹宕奸悢闈╅獜闂佺粯鍔楅幊鎾诲吹椤旂偓瀚氭い鎾寸箘閻ゅ懘鏌ㄥ☉姗嗘缂?
   *   閻?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻缁炬澘顦辩粣姊巐yricPadTop()` 婵烇絽娲︾换鍡涙儊婢跺娼扮€光偓閸愵亝袚濠殿喗绻愮徊楣冨几閸愨晝顩烽幖娣灱閻т線鎮橀悙鎻掆偓椋庣箔閸涙潙妫橀柣鐔稿绾捐鈹戦纰卞劀缂佽鲸绻冪粙澶婎吋閸曨厾鐛ラ梺瑙ｅ亾闁芥ê顦悡鍌炲级閳哄倻鎳佺紒鏂款嚟娴滄瓕绠涢幘鏉戜淮闂備焦褰冪悮顐﹀焵?
   *   閻?婵＄偑鍊涢崺鏍偉椤曗偓瀹?`y < 88`闂佹寧绋戞總鏃傚姬閸愵亜鏋堝Λ棰佽兌閻熸繈鏌涢幒鏇炵劷闁?
   * 闂佸疇娉曟刊瀵哥箔?闂佸吋鐪归崕閬嶅箺閵忊€崇窞闁冲搫瀚粻褰掓煕瑜庨妵鐐靛姬閸愵喗顥嗛柍褜鍓涢幉鐗堟媴閻ｅ本顔嶆繛杈剧到缁夊爼鎮块崱娑欐櫖?*闂佺绻愰悧蹇涘灳濡吋濯奸柕鍫濆閻熸繈鏌涘Ο渚剰婵犫偓?闂佸搫鐗嗛ˇ顔碱潩閿旂晫顩查柟鐑樻⒐閻ｉ亶鎮介銈囩暠闁?婵?*闂?
   */
  @Builder
  private DiagHotspot() {
    Row()
      .width(120)
      .height(40)
      .backgroundColor(Color.Transparent)
      .position({ x: 0, y: 88 })
      .zIndex(98)
      .onClick((): void => {
        this.onDiagHotspotTap();
        this.refreshDiagText();
      })
  }

  // 闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸?闂佺鐭囬崘銊у幀闂佸憡鐗犵紓姘跺吹濠婂牆绀夐柕濠忛檮閺嗩亪鎮?闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸?

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`BarCollapse`闂佹寧绋戦¨鈧紒鍙樺嵆楠炲繘寮借琚熼梺纭呯焽閸愩劎鍘梺鍝勵槴閸撴繈寮崷顓熷皫?闁诲繒鍋炲ú鏍閹达附鍎?*闂佸綊娼ч鍛箾瀹ュ鍋愰柤鍝ヮ暯閸嬫挻鎷呯憴鍕毣**闂?
   * 闂備緡鍋呴崝鏍ь焽椤栨稒濮滄い鎺嗗亾闁哥喐鎸鹃幉?`common/musicbasic/.../model/BarCollapse.ets`闂佹寧绋戦悧鍡涘箚閸懇鍋撳☉娆樻畽濠碘槅鍙冮幆宥嗘媴缁涘鏂€闂佸憡鐟ラ崲鏌ヮ敋椤曗偓閹ゎ樁闁靛棗鍟撮弫宥嗗緞閸艾浜?
   * 闂佸憡鐟禍婵嗭耿?`onChromeBarTouch()` 婵炴潙鍚嬪銊╁极閵堝洠鍋撻悷鏉挎殧闁?
   */
  private barCollapse: BarCollapse = new BarCollapse();

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`PlayerPage.showChrome()`闂佹寧绋戦¨鈧紒?*闂?婵炲瓨绮犻崰鏍吹椤撱垹绠崇憸宥夊春濡ゅ懎绀?闂佹寧绋戞總鏃傜箔婢舵劖鐓傜€广儱娲ㄩ弸鍌滅磼鐏炵偓銇濇俊顐ゆ櫕閹峰鍩勯崘鈺婃Н**闂?
   *
   * 闂佸憡鍨甸幖顐λ囬埡鍛櫖闁秆冨灣recover/logic-src/PlayerPage.abc.txt:11942-11982`闂佹寧绋戦¨鈧紒?
   * ```
   *   showChrome() {
   *     if (chromeHidden) {
   *       getUIContext().animateTo({ duration: CHROME_ANIM_MS, curve: Curve.EaseInOut },
   *                                () => { chromeHidden = false; });   // 濞达絽鍕?*#
   *     }
   *   }
   * ```
   * 闂?闂佺绻戞繛濠囧极椤撱垺鏅?*闁诲海鎳撻崯鎾闯閻戣姤顥堥柕蹇ョ磿濮婇箖鏌?`startIdle()`**闂佹寧绋戝濉癷deChrome` 闂備焦褰冩總鏃傚姬閸愩劉鏌﹂柍鈺佸暞缁?`clearIdle()`闂佹寧绋戦ˇ顓㈠焵?
   *   婵炴垶姊婚崰搴☆潩閵娾晛鍙婃い鏍ㄧ箥閸?闂佸摜鍋戦崐鏇㈠吹椤撱垹绠崇憸宥夊春濡ゅ懎绀?婵?闁荤姍鍥舵闁宠鐗犲濠氭嚑妫版繂鎮侀梺?闂佸搫瀚烽崹鍗炍涢妶澶嬪仼鐎光偓閸曨偅顏?*婵炴垶鎸堕崐鎾斥枎閵忋倖鍋戞い鎺戝€昏ぐ宀勬煟閵娿儱顏х紒?*闂?
   *   闁荤喐娲戝鎺旂箔婢跺本鍟哄ù锝堝Г瀹曟娊鎮规担鎻掑⒉婵＄偛鍊块幃?*闁荤姴顑呴崯浼村极閵堝鍊?*闂佸憡鍔曢崯鍧楁偩妤ｅ啯鏅柛顐秵濞?{@link PlaybackPage.onSwiperIndexChanged} 婵?
   *   `onLyricInteract` / `onLyricSwipe`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婂綊宕瑰鍕浄妞ゆ巻鍋撻悽顖ｅ亰瀵爼濡烽敃鈧儫婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲繐鐣风€ｎ喖绠ｉ柟閭︿簽椤忓崬鈽?`touchChrome()`闂?
   *   婵炲瓨绮岀€涒晛危閹间礁鎹?闂佸憡甯掑ú銈夊春瀹€鈧禍鍛婄瑹閳ь剙顭囬悧鍫涗簻?闂備緡鍙忕徊鎯ь焽椤栨粍宕夋い鏍ㄧ懅閻熸劕霉?*婵＄偑鍊楅崕銈嗘櫠濠婂牆绠┑鐘插閺佸嫰姊婚崒婵嗚敿妞ゆ挻鎮傚顕€寮甸悽鐢垫闁荤姍鍛効闁圭櫢缍佸?* 闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥€涒晛螞閵堝鍋╃€光偓閳ь剙霉婢舵劕鐭楃€广儱绻掔粈鍕⒑椤撱劎绉柛锝囧厴瀵?`clearIdle()`闂佹寧绋戦ˇ顓㈠焵?
   */
  private showChrome(src: string = ''): void {
    // 照搬无界 `PlayerPage.showChrome`（`_recover/disasm/wujie.pa:179483-179528`）：
    //   if (!chromeHidden) { return; }                      ← 已经是展开态就什么都不做
    if (!this.chromeCollapsed) {
      return;
    }
    //   getUIContext().animateTo({ duration: CHROME_ANIM_MS(350), curve: Curve.EaseInOut },
    //                            () => { chromeHidden = false; })     ← 闭包 λ `@5*#`（179518）
    this.getUIContext().animateTo({
      duration: PlaybackPage.CHROME_ANIM_MS,
      curve: Curve.EaseInOut
    }, (): void => {
      this.chromeCollapsed = false;
      this.lyricChromeProgress = 1;
    });
    Logger.info('RzdLyricChrome',
      `show 触发源=${src} naturalHeight=${this.lyricChromeHeight}`);
  }

  /**
   * 闁荤姳鐒﹀妯肩礊瀹ュ棛鈻旈柍褜鍓欓埢搴ㄥ焺閸愩劋绮梺鍛婂笩濞夋稓浜搁娑氼洸闁靛牆瀚棄宥夋煥?*闂佸摜鍋戦崐鏇㈠吹?+ 闂備焦褰冪粔鍫曟偪閸℃稒鍤婃い蹇撳琚熼梺琛″亾闁诡垳澧楀畷鎶芥偣娴ｆ彃澧叉俊?*闂?
   *
   * 闂佸搫鍟版慨鐑藉疾椤愶附鐓傜€光偓閸愵亞顔愭繛鎴炴尪閸婃挸鈻庨姀锛勵洸閻庯綆鍋呯瑧闂佸憡甯掑Λ妤冩閹达附鍎嶉柛鏇炲缁€鍒瀞howChrome()` 婵?`startIdle()`闂佹寧绋戦¨鈧紒杈ㄧ箞瀹曪綁顢旈崨顔剧暢
   * "闂佹椿娼块崝宥夊春濞戙垹鎹堕柕濠忓閹藉啴鎮归崶褏效闁靛棗顦扮粙澶嬬節閸曨偂鍖栨繛?婵炴垶鎸搁鍡欏垝閿旂晫顩?闁哄鏅滈悷褏鎮?*闂佹椿浜為崰宥咁潩閿旂晫顩?*闂佸綊娼х粔鎾箖閹捐绫嶉悹楦挎〃缁潧鈽夐幘鍗炩偓鎾斥枎?闂佺偨鍎查弻锟犲焵?闂佸湱顣介崑鎾趁归悩顔煎姤缂佺粯鐗犻弻宀€浠﹂懖鈺冾啍闂佷紮绲鹃悷銊ф崲閺嶃劎鈻旀い蹇撴閻鏌涘顒傚闁告瑥妫濆畷锝夋晲韫囨洜顦?
   * 闂佹眹鍨肩划楣冩儍閻斿吋鍋ㄩ柕濞у啩鍖栭梺鐓庮殠娴滄粎鎹㈡笟鈧弻鍛緞濞戞氨顦╅梺鍛婂笒濞差參濡存径鎰劷闁挎繂妫欓拏瀣偣娓氼垰鐏犵憸鎶婂懏瀚柛鎰╁妼瀵版挸鈽夐幙鍐ㄥ箳缂佹柨鐡ㄧ粙澶愵敂鎼达絿顦柣?`onSwiperIndexChanged`闂佹寧绋戦ˇ顓㈠焵?
   */
  private touchChrome(src: string = ''): void {
    this.chromeTouchedAtMs = Date.now();
    this.showChrome(`touch:${src}`);
    this.scheduleChromeAutoHide(`touch:${src}`);
  }

  // 闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸?闁荤喍妞掔粈浣圭珶閳ь剟鎮楅崷顓熷殌婵炲懏甯熼妵鎰板閻樿尙绉梺鎸庣☉閻楀棝顢氶鈧浠嬪炊閵婏讣楠忛梺?ExpandAnimation闂佹寧绋戦ˇ顐﹀绩閵忋倕鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵椤掑嫬鐓橀柍褜鍓熼崺鐐哄焵?

  /**
   * @returns 闂佽桨鐒﹂幐鎶藉Υ婢跺鈻旂€广儱顦崑鎾圭疀閺冣偓椤牠骞栨潏鎹愵吅缂?*闂佽鍘界敮濠勬嫻?1**闂佹寧绋戦悧鍡涱敊閹版澘闂柕濠忛檮閹烽亶妫呴澶婁簵缂佹顦彁闁宠棄鎳愮粈鍡涙煏?
   *
   * 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯閻戣棄鍌ㄩ柣鏂挎啞闂勫秹鏌?`p/0.12` 濠电儑绲洪埀顒€鍟垮鎶芥煛娴ｈ櫣绡€闂佸弶绮庨埀顒€婀遍幊鎾斥枍閹烘鏅悘鐐靛亾绗?*闂佺懓鐡ㄩ崹濂稿吹濠婂喚鍟呴弶鍫氭櫆閻ｉ亶鏌涘▎鎰仸婵?*闂佹寧绋戦懟顖氼嚕閻ｅ瞼纾介柡宥庡墰濡差垶姊?
   *    `applyPullProgress` 婵炴垶鎸哥粔鍫曪綖椤愶絿顩烽悹浣哥－缁夊潡姊洪銏㈢婵″弶鍨堕幆鏃堟晜鐞涒€充壕濞戞棏鏌晇erlayColor` 婵炴垶姊婚崰鎰閼恒儳鈻?`#00000000`闂?
   *    闁诲海鏁搁幊鎾惰姳閺屻儲鍎?闁荤姍鍥舵闁稿绲剧粙澶婎吋閸ワ絾鏅?闂佹眹鍨肩划楣冨磿濡ゅ懎鐤炬い鏍ㄦ皑濠€鎾煟?`pullBgIn`闂?闂?.30闂佹寧绋戦ˇ顔剧箔瀹€鍕煑闁绘ê寮堕煬顒勬煛閸艾浜炬繛鎴炴尭閿曨亜顭囨导瀛樺剭闁告洦鍘鹃弫鎯ь渻鐎ｎ剙浠滈柣銊︾箞濡?闂佺绻愰澶娾枔閺囩姳娌柛灞剧箘椤︿即鎮归幇鍓佺シ闁?
   *    闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷礁鐡ㄧ粙濠囨偄鐞涒檧鍋撳Ο鍏煎闁靛牆鐗忕粻鏍级閳哄倻鎳佺紒鏃€鎸抽幃娆撴儌閸濄儳鐛?闂佸搫鍟版慨鐑藉疾椤愶箑绀夐柕濞у嫭姣庨悗娈垮枓閸嬫挸鈹戦纰卞剮缂佹顦靛浼搭敍閻愨晛浜鹃煫鍥ㄦ⒐椤牠鏌?闂?
   */
  private morphOpacityValue(): number {
    // 闂?闂佺厧顨庢禍锝夋儊婢跺鍤楅柤鎭掑劤閸ㄥジ鏌ㄥ☉娆掑濠殿喒鏅犻幃鐣岀磼濡鐒搁梻鍌氬€归幐鎶藉焵椤掍礁濮囬柟鑸靛哺瀹曟岸鏌ㄧ€ｎ偆鍘愰柣鐘叉川缁垶寮抽悢鍏兼櫖闁割偅绻勯悰锕傛煛瀹ュ懏鎼愰柛娅诲洦鍎撻柍褜鍓熷顔炬崉閾忚娈滅紓浣规煥椤戝懘宕?return闂佹寧绋戦惌鍌毭归崒姘煎殨闁逞屽墴閺屻劑鍩€椤掑嫭鏅璺虹墐閸?
    //   闂佽　鍋撻柟顖嗗嫯鍚柡澶嗘櫆閻熲晠宕抽悜钘夊強妞ゆ牗纰嶇粈鍫濃槈閹捐泛鍔嬫繝鈧导鏉戠闁兼亽鍎插▓?*濠殿噯绲界换鎰板箮濮樿埖鐒鹃柛濠勫櫏濞煎爼鎮圭€ｎ亜鏆熼柡?*闂佹寧绋戞總鏃傜箔閺嶎厼绀冩繛鍡樺灦閻ｉ亶鏌￠崟闈涚仧閻炴俺椴哥粙澶愵敂閸涱喗瀚虫俊?`@Local` 闁诲孩绋掗〃鍡涱敊瀹€鍕櫖?
    //   婵炴垶鎸告鍛婃叏閳哄懏鍋ㄩ柤濮愬€曠瑧闂佽鍏涚粈渚€鎮鹃鍕闁靛闄勯敓銉╂煕韫囨洦鍔滅紒杈ㄧ懅閻ヮ亪顢涘顒侀敪闁荤姴娲ｇ槐顔炬濮樿泛违闁稿本绮嶉弳蹇涙煙閺夋垵妲绘繝鈧鍫濈闁靛ě鍕瘞**缂傚倷鐒﹂幐璇差焽椤愶絿鈻曢悗锝庝簼閸?*闁荤姴娲╅褔宕哄畝鍕剭闁告洦鍋呴惃鎴︽煛閸曢潧鐏￠柡浣告贡娴滃憡銈ｉ崘銊ょ凹婵炴垶鎸撮崑鎾绘煕閹烘洖鍚规繛鍫熷灴瀹曟劗绮悰鈥充壕?
    this.refreshDiagText();
    // 闂?缂傚倷鐒﹂敋闁糕晜顨婂濠氣€﹂幒鏃傤槱闁?`introPaintReady`闂佹寧绋戦¨鈧紒杈ㄥ閵囨劙濮€閻樿尙绉悗娈垮枓閸嬫挸鈹戦纰卞剮缂佺媴缍佸畷婊冾吋閸℃ɑ顔掓俊鐐€曢崥鈧紒妤€顦甸幃鑺ュ濞嗘垹顦梻渚囧墮閻忔繈宕㈤妶澶嬬劷?1~2 闁汇埄鍨庨崶顭掔础闂佸憡鍨甸幖顐︽偩椤掑嫬鏋侀悗娑櫳戠亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢舵劕违?
    // 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸堕崐鏍ь焽?*闂婎偄娲ら幊姗€濡磋箛娑樼哗闁硅鍔﹂弨?*闂佹眹鍔岀€氼參宕曡箛娑樼缁炬澘顦辩粈鍕煕濮樺墽鐣遍柛顭戝灣娴滃憡娼忛妸蟺?闂佸湱铏庨崢浠嬪棘娓氣偓閹儳鐣濋崟顒併€冮梺鐟扮仛閹搁绮径濠庡殨闁?闂佹寧绋戦¨鈧紒?
    //   1. 閻庤鐡曠亸娆戝垝閿熺姵濯伴柟瀛樺笧缁夋挳鏌ㄥ☉妯煎ⅱ婵炴潙顦伴幏?OPEN闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佸搫鍟版慨楣冾敊閹达附鈷掗柕濠忛檮绗戞繛瀵稿Л閸嬫挸鈽夐弬璺ㄥⅱ濠殿喗鎮傞獮鈧〒姘功缁€澶愭⒒閸喓鎳勬い鎺撶洴楠炩偓濞达綁顥撻杈┾偓鍨緲椤戝牓銆呴敃鍌涘仺濞村吋鐟ч獮?
    //   2. 闂佸綊娼ч鍡欌偓鍨壘椤垽鏁愰崨顔垮惈婵＄偟鎳撳畷顒佹叏閳哄懏鏅柛顐ｇ矌閻熸劙鏌?婵炴垶鎸搁鍡樺垔閾忚宕夐柣鏃傤焾椤や線鏌ㄥ☉姗嗘Т闁逞屽墯閺岋繝鍩€?闂備緡鍙忕徊鎯ь焽椤栨粍宕夋い鏍ㄧ懅閻熸繈寮?`tryStartMorphIntro` 闂佹眹鍔岀€氼剛妲愰幋锔解拻闁靛鍎遍悗濠氭煛閳ь剟顢涢妶鍥╊槷
    //      闂傚倸鍊堕崝瀣閻楀牏鈻旈柍褜鍓熼幆鍕级閹存繂缍橀梺娲诲亐閸嬫捇鏌ㄥ☉妯煎ⅲ缂佺粯鐗曢～銏ゆ晲閸℃锕€鈽夐幘绛规缂佹梹鎸抽幃?闂佺懓鐏氶幐椋庣箔婢跺鍤曢柍褜鍓熼獮姗€顢橀悢鍛婃緬闂佷紮绲介惌鍌氼焽?闂佹眹鍔岀€氼參鎮ч幘顔肩倞闁绘瑥鎳愮粈鍡涙煏?
    if (this.expandState.morphStage === MorphStage.OPEN || this.introPaintReady ||
      (this.expandState.morphUsable && this.expandState.morphSessionDriving())) {
      return 1;
    }
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER &&
      this.expandState.morphUsable) {
      return 1;
    }
    // 闂佸疇妫勯幊澶娢?2026-10-16闂佹寧绋戦悧蹇涘磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸嬫捇鏌ｉ妸銉ヮ伀妞ゆ垵娲︾粋宥囦沪閽樺锛欓梺鎸庣☉椤р偓缂?
    //   闁哄鏅滈悷銈囩博閺夋垟鏋旈柛顭戝亝绗?婵犮垻鎳撻崯鍧楁儑閺夋鍟呴棅顐弨缁€瀣级閳哄倻鎳佺紒鏂跨摠濞碱亪顢欓幐搴￠棷婵炲瓨绮屽Λ妤呮嚋娴兼潙鐭楁俊顖氭贡缁愭鎮归崶銊х缂佽鲸鐛媘orphSessionStarted`闂佹寧绋戦¨鈧紒杈ㄧ箖閹峰懘宕卞Δ鈧▓銈吤归敐鍡樼缂佺粯娲栭埢浠嬪灳閸愯尙顏婚梺鍛婂笚婵粙骞戦敐澶嬪€?
    //   闂?闁哄鏅滈弻銊ッ?0闂佹寧绋戦悧濠囧汲閿濆棎浜滈柛蹇撴憸閻熸繈鏌ｉ～顓犱覆缂佽鲸宀搁弫宥囦沪閹呮婵?闂佸湱顭堥崐钘壝归崶顒佺劷?1~2 闁汇埄鍨庨崶顭掔础闂佸憡鍨甸幖顐︽偩椤掑嫬鏋侀悗娑櫳戠亸锟犳煛閳ь剚銈ｉ崘锔瑰亾?闂?
    //   闂佸疇娉曟刊瀵哥箔?闂佸憡鎼╅崹顖滅礊閺冨牊鍋ㄦい顓熷笧缁€鍕偓瑙勭摃鐏忔瑩鎮￠敓鐘参ュù锝囨嚀婢跺秹鏌涘▎鎰垫缂佽鲸宀搁弫宥咁潩瀹曞洨顔愰梺鍛婂灩婵挳骞庡鑸电厒?*婵犮垻鎳撻崯鍧楁儑娴煎瓨鍎嶉柛鏇ㄥ亜鐢菐閸ワ絽澧插ù鐓庢嚇瀹曟鈧綆鍠楅悾鐑芥倶閻愭彃浜扮紒杈ㄧ崑MorphMetaBridge`闂佹寧绋戦ˇ宕囨崲閺囥垹鎹堕柕濞у嫭姣?*
    //     闂佹寧绋戦悧鍡涙偩閻樿鎹堕柕濞у懎鐐婇梺鍛婄懕缁茶棄顭囧Δ鍛唨闁搞儻濡囬悷鎰版煏閸℃洘顦风紒妤€顦靛畷銉╁礃閳哄倹瀚虫俊鐐€楅弫绋库枔?opacity闂佹寧绋戦ˇ顐﹀闯?闁诲繒鍋涚换瀣箔閸屾稑顕辨慨姗嗗幗缁犳帒鈽夐幘顖氫壕闁荤偞绋戦張顒勬偤閺囥垹瑙?濠殿喗绻傞張顒佹櫠濠婂牆绀傞柛顐ｇ矊閻︺劑鏌ｉ鐔蜂壕闂?
    //     闁哄鏅滈悷锕€危閹间礁绫嶉柣妯虹仛濞呮洟鏌涘顒佹拱闁诲寒鍨堕幆鍐礋椤愩儱鐓傞梺缁橆焾椤旀劗妲愬▎鎴斿亾閻熸澘鏆熸繛?`floatingMeta` 婵炴垶姊婚崰搴★耿椤忓牆绠绘い鎾跺枑閺夌懓顪冮妶鍛倎缂佺媴绲惧鍕冀閻㈢數顦梺?*婵炴垶鎸哥粔鎾疮閳ь剟鏌涘▎娆戠暠濞寸姵绋撻幃浼村Ψ閵堝浂浼?*闂?
    return 0;
  }

  /**
   * 閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮悑閿?闂佺厧鍟块張顒€鈻嶅▎鎾虫瀬闁哄鍨瑰﹢?闂佹眹鍔岀€氼亞绮径鎰劵闊洦姊归～鏍箹鏉堟崘顓虹紒杈ㄧ懇濡啫鈻庨幇闈涘闂佽鍏涢悞锔界?1闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺粯鎸嗛崟顐嬶繝鏌￠崘顏勑ラ柡?`pullBgOpacity`**闂佹寧绋戞總鏃堝箞閵娾晜鍋ㄩ柕濠忕畱閻撴洟鎮楅崷顓炰沪缂佷焦鎸虫俊瀵镐沪閻愵剙鍟婇梺琛″亾闁诡垎鍕綔闁诲繒鍋炲ú鏍閹寸偞浜ゆ俊顖滅帛绗戦梺鐓庡暱閺堫剙鈻嶅▎鎾崇闁靛鍎冲宀勬煏閸℃鈻岀紒?
   *
   * ## 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亜閺傃呪偓娈垮枛妤犲繒妲愬▎鎴斿亾濞戞瑯娈欏┑鈽嗗弮閹秵绗熼埀顒勫焵椤掍礁濮堟繛纰卞灣閹风姷鎷犻幓鎺撶様闂佸搫顦崕鍐测枔閹达附鏅?
   *
   * ```
   *   PULL_BG_FLOOR = 0.04          wujie.pa:179978-179979  (fldai 4.0e-2)
   *   PULL_BG_IN_END = 0.30         wujie.pa:179980-179981  (fldai 3.0e-1)
   *
   *   pullPaintable = pullGeomReady && !morphSquashing      wujie.pa:176560-176579
   *   pullBgIn      = clamp(effT / PULL_BG_IN_END)          wujie.pa:176295-176326
   *                   // effT = 閻熸粏鍩囬崹纭呫亹婢跺鈻?? morphT : 1  闂?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夆偓娑滃焻 1
   *   pullBgOpacity = !pullPaintable ? 0
   *                                 : PULL_BG_FLOOR + pullBgIn 闁?(1 闂?PULL_BG_FLOOR)
   *                                                          wujie.pa:176331-176372
   * ```
   *
   * ## 闂佸疇娉曟刊瀵哥箔瀹ュ鐓ｉ柣娆忔噽閻?闂佸搫鐗滈崜婵嬫偪?*闁荤姳闄嶉崹娲敆濠婂嫮鈻旈柍褜鍓氬鍕礋椤掆偓閻忓鎮归崶顏嶅殭鐎殿喛濮ょ粋宥夊幢濞嗘劗鏆犻梺鍝勵儎閻掞箓鍩€?*闂佹寧绋戦悧鍡涘春閸℃稑绀冪€广儱娲ゅ楣冩煟椤愮喎浜鹃梺鍝勫敳閸曨剚娈橀梻浣瑰絻閿曘儵寮總绋跨倞闁绘劖褰冪粻鐢告煥?
   *
   * 闂佺懓鐡ㄩ崹鍨櫠閻樺磭鈻旈柍褜鍓熼幃褔宕奸悢鑲?`pullBgOpacity` 闁荤姴娲ㄧ划顖炲垂?闂佺粯鍔楅幊鎾诲吹椤斿彞娌柡鍥╁仧绾惧鏌?`pullPaintable()` 婵炴垶鎸搁幖顐ｇ?闂?闂佺厧鍟块張顒€鈻嶅▎鎰枖鐎广儱娲﹂弳?闂?
   * 濡ょ姷鍋犻崺鏍х暤娴ｅ壊娼伴柕鍫濈墱閸炪劑鏌￠崼顐㈠闁搞倝浜跺顐﹀级閹稿氦鍚梻鍌氱墢閸嬬姷绮ｉ敓鐘茬閻庯綆浜ｉ崺宀勬煕濞嗘兛鎴濐渻?`return 0`闂?*闁荤姴娲╅褍顕ｉ懞銉ь洸?*闂?
   *
   * * `jnez L` 闂佹眹鍔岀€氼垶顢氶姀锛勨枙濠㈣泛顑嗙瑧"**闂佸搫顦埀顒€寮堕钘夆槈閹捐櫕鎯堝ù?*闂佸搫鍟崕濂告倻?闂佹寧绋戦悧鍡涘礄閿熺姵鍋?`playerSwiperGapOf` 闂備緡鍙忕徊鐐繆閸濄儰鐒婇柛婵嗗閹藉秹姊洪挊澶樻Ч妞ゆ帗鎸抽弫宥嗗緞濞戞艾鑰?
   * * `lda pullPaintable(); isfalse; jnez L2` 闂?**`pullPaintable() === true` 闂佸搫鍟崕濂告倻閿曞倸绀?L2**闂?
   *   闂?L2 闂佸綊娼х粔闈浳?缂?`PULL_BG_FLOOR + pullBgIn 闁?0.96`"闂備緡鍙忕徊鑲╃博閹绢喖缁╂い鏍ュ€楅獮?
   * * 闂佸憡鐟禍婵嗭耿?`pullPaintable()` 婵炴垶鎸搁幖顐ｇ閿濆绠?`ldai 0x0; return`闂?
   *
   * 闂?`pullPaintable = pullGeomReady && !morphSquashing`闂佹寧绋戝濉祇rphSquashing` 闂佸憡鐟禍婊冿耿?
   * 闂佺绻戞繛濠偽涢幘顔藉闁瑰瓨甯炵粔鎾⒑椤撱劎瀵肩紒鏂款嚟閹峰鎮ч崼婵堟瘍闂佸憡锚椤戝棗锕㈤敓鐘斥拻缂傚牏濮剧粈瀣煟椤忓棗娅愮紒杈ㄥ哺閸?**婵炴垶鎸搁敃銉﹀垔?闂佺粯鍔楅幊鎾诲吹椤斿彞娌柡鍥╁仧绾惧鏌涜箛瀣闁宠鍚嬬粙澶愭惞鐟欏嫬鐒?* 闂?**闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鈧弻銈夋⒑椤旂偓娅曢柡?*闂?
   * 闂?闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸虫俊?*闂佸搫鍟版慨鐑藉疾椤愶箑绀夐柕濞у嫭姣庨柡澶嗘櫅濞层劑鍩㈡總绋垮珘濠㈣泛楠搁崜褰掓煛閸滀礁鐏ｆ繛鍫熷灴閺佸秹宕奸敐鍛啎闁诲繐绻戦崹鐢告偪閸曨垰瀚夐柣鎴炆戠瑧闁哄鏅滈悷锕傛偋闁秵鏅?*闂侀潧妫楃粔鐢割敆濠婂牆鍙婃い鏍ㄧ箘缁犲綊鏌℃径娑氱？閻庢凹鍘剧划鈺冣偓锝庡幘濡插牓鏌熺拠鈥虫灁闁?
   *
   * ## 缂傚倷鐒﹂幑渚€顢欓幋锔芥櫖闁割偆鍠愰幏鍗灻归悩铏鞍婵℃儹鍛剨闁告洖澧庣粈?
   *
   * | 闂侀潻濡囬崕銈呪枍?| 缂傚倷鐒﹂幐濠氭倶?|
   * | --- | --- |
   * | 闂傚倸鐗婇悷锕傤敆濞戙垹绠?| 1 |
   * | 閻熸粏鍩囬崹纭呫亹婢跺鈻?| `PULL_BG_FLOOR + pullBgIn 闁?(1 闂?PULL_BG_FLOOR)` = `0.04 闂?1`闂佹寧绋戝濉竨llIn 闂?0.30` 闂佸憡鑹剧€涒晜绂?1闂?|
   * | 闂佽В鍋撻柟瀛樺笧缁夋挳鏌熼幖鐐测偓鏇犳暜閸ヮ剚鏅柛褍鍩搊rphSquashing`闂?| 0闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸曨偂绨兼繛鎴炴尨閸嬫挻淇婂Δ瀣缂佲€冲暞缁嬪鍩€椤掑嫬鍐€闁告垯鍊楃粈?|
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佸搫鍞查崟顒佹畼闂備焦褰冮敃顏堝闯?**婵炴垶鎸哥粔鐑姐€?*闂佺粯鎸嗛崟顐?`clamp(p/0.30)`"闂備緡鍙忕徊鎯ь焽椤栨粎纾奸柟鎹愵嚃閸?*閻庤鐡曞鎾剁礊閺冣偓閹?*闂佹寧绋掗懝楣冩偩閻樿绠柛娑卞幘婵″洭鏌ｉ妸銉ヮ仾婵?闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本纰嶉煬?
   * **闁荤偞鍑归崑澶愃夐崱娑樼妞ゅ繐妫欓悾閬嶆倶韫囨挾绠抽柣娑栧劦瀹曪綁鏁愭径濠冾仦**闂?0% 闁诲繐绻楁ご绋款嚕瑜庣粙澶婎吋婢跺棗浜鹃煫鍥ㄦ⒐椤?闂?缂備焦鍔栭〃鍛般亹濞戙垺鐓傞悘鐐跺亹椤忛亶鏌℃担瑙勭稇婵炲皷鍓濋—鈧?闂侀潧妫楅崐浠嬪焵椤掆偓閻線宕曞Δ鍛柧妞ゆ牗姘ㄥ﹢鎾煟濠婂嫭绶叉繝鈧鍫濆強?*闂侀潻璐熼崝蹇浰夐崱娑樼妞ゅ繐瀚烽崯鍥煕閿濆啫濡奸柛鐐存尦閺?*
   * 闂佹寧绋戦悡?0 闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦鍋嗗﹢瀵哥磼閻欐瑥绉剁粈鍡涙煥濞戞鐒搁柛瀣噺缁嬪顢旈崟顔肩厒闂佺粯蓱濠€鍦箔婢跺备鍋撳☉娅亜锕㈤鍛洸闁糕剝鍔忛崑?
   *
   * 闂佸疇娉曟刊瀵哥箔?**2026-10-16 婵炲瓨绮岄張顒勵敃閼测晜濯奸柕蹇婃閸斺偓闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓惉濂稿磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸?闂佺粯鍔楅幊鎾诲吹椤曗偓瀹曟骞庨懞銉川/缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧柡澶嗘櫆钃辨俊鑼焾閳讳粙鍩勯崘鈺冪暢闂侀潧妫楃粙鍕?*闂?
   *   婵炴垶鎸搁澶婎焽娴煎瓨鐒介柨婵嗘噹缂?`if (this.expandState.morphSquashY !== 1) return 0;` **闂佸搫瀚烽崹鍫曞极婵犲洦鍎?* 闂佺偨鍎查弻锟犲焵?
   *   闁诲海鎳撻崯顖氾耿娴兼潙绠涢煫鍥ㄦ⒐绗戦悷?闂佽В鍋撻柟瀛樺笧缁夋挳鏌熼幖鐐测偓鏇犳暜?闂佹寧绋戦悧濠偽涢妶澶嬪仼?`morphSquashing`闂佹寧绋戦¨鈧紒杈ㄧ箖閹?`morphSquashY` 闂?*闂佺粯鍔楅幊鎾诲吹?闁哄鏅滈弻銊ッ?*闁哄鏅滈悷锕€顭囬婊勫磯妞ゆ牗鐟ч悷?
   *   婵炴垶姊婚崰宥囨閻楀牏鈻旂€广儱娲ㄩ幖鐓幟?1闂佹寧绋戦悧鍡涘矗瑜斿濠氼敇閳╁啫鍔欐繛杈剧到缁夊綊宕戦崨顔锯枖闁逞屽墰閹?110ms+320ms 闂佹眹鍔岀€氼厾浜哥€ｎ喖鍌ㄩ悗锝呭缁€鍡涙煥濞戞ê顨欑紒顭戝墴瀵即顢涘☉娆愵啋闂佸搫顥￠妶鍥╁敶闂佹眹鍔岀€氼垶宕曞Δ鍛柧妞ゆ牗绻嶅鍫曟煕濡警鍎愰柛?0
   *   闂?闂佹椿娼块崝宥夊春濞戙垺鍎戦悗锝庝簻閻撳倿鏌ｉ妸銉ヮ仾婵?**闂佸憡鐟禍婵嗭耿娴ｅ湱鈻斿┑鐘插暙椤庢瑩姊洪銊хɑ婵炵⒈鍨跺鍨緞鎼粹€冲闂?*"闂?
   *   闂?闂佺粯绮嶅妯猴耿椤忓牆缁╅悷娆忓閻忓洭鏌?*闂佸憡鐟禍锝夈€呴敃鍌氬珘濠㈣泛锕ㄩ崺宀勬煕濞嗘劧鍏紒杈ㄧ箞閹虫浠﹂悙顒傚讲闁诲繐绻楁ご鍝モ偓?`pullBgIn` 婵炴垶鎸搁敃銉ф嫻娴兼潙绀?*闂佹寧绋戞總鏃傜箔婢舵劕绀冪€广儱鎷嬮崵?Drive 闂佺懓鐡ㄩ悧妤冧焊鐎ｎ喖鍌ㄩ悗锝庝簷缁敻鏌ｅΔ鍕垫綈闁伙絺鏅犲畷姘跺Χ閸℃鍔烽梺?
   *     闂佺厧鍟块張顒€鈻嶅▎蹇ｅ晠闁肩⒈鍓涢惀鍛存偠濮樼厧浜滄い鏃€鍔欏畷鎶藉Ω椤垶鈷栭梺鍛婃惄娴滈妲愬▎鎰€?0闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲秹鍩€椤掍胶顩?閻熸粏鍩囬崹纭呫亹婢舵劕绫嶉柍鍝勫€归崺鍌炴煛娴ｈ缍戦柣?闁哄鏅滈悷銈夋煂濠婂嫨浜滈柟瑙勫姈椤庢岸鏌￠崼顐㈠⒉闂傚ň鏅滅粙濠囨偄閸撲胶鎲归柣搴㈢⊕閿氭繝鈧鍛洸闁糕剝鍔忛崑?
   *
   * 闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯顐﹀箖閹捐绫嶉柛鎾茬贰閸氣偓闂佹椿鍋€閸嬫捇鏌ㄥ☉娆掑闁诲繑纰嶉幆鏃堝即閻愬灚鍕鹃梺闈涙缁€浣姐亹閸ヮ剙鍐€闁汇値鍨伴ˉ蹇涙倶閻愭彃鈧爼鍩€椤戣儻鍏岀紓宥咁樀瀵粙鎮℃惔锝嗗嬀闂侀潧妫旂粈浣烘閻愬搫瑙﹂柟瀵稿仦椤斿倿鎮?闂佺偨鍎查弻锟犲焵?闂佽　鍋撻柣鐔稿閺嗗﹦绱掑☉姗嗘Х缂侇煈鍓熷銊ф兜閸涱垳顔愰梺鎼炲劜缁嬫垿鎯囨导鏉懳?
   * 闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdBgOpacity'`
   * @returns 0..1闂佹寧绋戦悧鎾愁焽閵堝拋娼伴柕蹇婃閸?= 1闂?
   */
  /** 实心承托与播放器共用既有表面几何，不另建裁剪或缩放域。 */
  @Builder
  private MorphSolidSurface() {
    if (this.expandState.morphClipping()) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.morph_mini_solid_surface'))
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.state.imageColor)
          .opacity(Math.max(0, Math.min(1, this.expandState.contentP)))
      }
      .width(this.expandState.windowWidthVp)
      .height(this.expandState.windowHeightVp)
      .opacity(this.backgroundRevealOpacity())
      .hitTestBehavior(HitTestMode.None)
    }
  }

  private surfaceLogTime: number = 0;

  @Monitor('expandState.contentP', 'expandState.morphStage')
  private logSolidSurface(): void {
    const now: number = Date.now();
    const p: number = this.expandState.contentP;
    if (now - this.surfaceLogTime < 80 && p > 0 && p < 1) {
      return;
    }
    this.surfaceLogTime = now;
    Logger.info('RzdMorphSolid',
      `p=${p.toFixed(3)} stage=${this.expandState.morphStage} ` +
        `solid=${this.expandState.morphClipping()} bgAlpha=${this.backgroundRevealOpacity().toFixed(4)} ` +
        `tailAlpha=${this.expandState.morphTailOpacity().toFixed(4)} scale=${this.expandState.morphScale} ` +
        `clipH=${this.expandState.morphClipHeight} radius=${this.expandState.morphRadius} ` +
        `tx=${this.expandState.morphTx} ty=${this.expandState.morphTy} ` +
        `sourceHidden=${this.expandState.sourceBarHidden} miniOut=${this.expandState.miniOut} ` +
        `squash=${this.expandState.morphSquashY}`);
  }

  private backgroundRevealOpacity(): number {
    // ★★★★ 2026-10-17（**照搬无界的取值链**，修用户反复报的「点击打开背景仍对不上」）：
    //
    // 上游把不透明度挂在 `MeshCoverBg` 的**外层 `__Common__` 包装**上，按入口分两套取值
    // （`wujie.pa:192150-192178`，λ `@36***^2**#`）：
    // ```
    //   __Common__()
    //     .opacity(this.pullMode ? this.pullBgOpacity() : this.expand.contentOpacity)
    //     { MeshCoverBg({ coverPath, seed, playing, active, entryFade }) }
    // ```
    // ⇒ **下拉那条路**（用户从迷你条往上拖）走 `pullBgOpacity()` = `0.04 + pullBgIn×0.96`（从 4% 起长）；
    //   **其余所有入口**（点击打开 / 关闭 / 系统返回）走 `expand.contentOpacity`
    //   —— 也就是本仓的 `expandState.morphContentOpacity`（与页面上其它内容用**同一条**透明度曲线）。
    //
    // ⚠️ 上一轮把两条路并成"只算 pullBgOpacity"（注释说是为了修首帧全不透明），
    //   结果点击打开时背景在自己的 0.04→1 曲线上跑，而控件/封面在 contentOpacity 曲线上跑
    //   ⇒ 形变整段"背景亮度和别人不一样" = 用户说的对不上。现在按上游拆回两套。
    return this.expandState.pullMode ? this.pullBgOpacity() : this.expandState.morphContentOpacity;
  }

  /**
   * 照搬无界 `PlayerPage.pullBgOpacity()`（`wujie.pa:176331-176372`）：
   * ```
   *   pullPaintable = pullGeomReady && !morphSquashing      // :176560-176579
   *   pullBgIn      = clamp(effT / PULL_BG_IN_END)           // :176295-176326
   *   pullBgOpacity = !pullPaintable ? 0 : PULL_BG_FLOOR + pullBgIn × (1 - PULL_BG_FLOOR)
   * ```
   * `pullGeomReady` 在本仓 = {@link PlayerExpandState.morphGeomReadyNow}；
   * `morphSquashing` 在本仓 = `morphSquashY !== 1`。
   * @returns 0..1
   */
  private pullBgOpacity(): number {
    const paintable: boolean = this.expandState.morphGeomReadyNow() && this.expandState.morphSquashY === 1;
    if (!paintable) {
      return 0;
    }
    return PlaybackPage.PULL_BG_FLOOR + this.pullBgIn() * (1 - PlaybackPage.PULL_BG_FLOOR);
  }

  /** 闂佸搫鍟版慨鐑藉疾?`PULL_BG_FLOOR`闂佹寧绋戝澧倁jie.pa:179978-179979`闂佹寧绋戦悾鐠甽dai 4.0e-2`闂佹寧绋戦ˇ顓㈠焵?*/
  private static readonly PULL_BG_FLOOR: number = 0.04;

  /** 闂佸搫鍟版慨鐑藉疾?`PULL_BG_IN_END`闂佹寧绋戝澧倁jie.pa:179980-179981`闂佹寧绋戦悾鐠甽dai 3.0e-1`闂佹寧绋戦ˇ顓㈠焵?*/
  private static readonly PULL_BG_IN_END: number = 0.30;

  /**
   * @returns 闂佸搫鍟版慨鐑藉疾?`pullBgIn() = clamp(effT / PULL_BG_IN_END)`闂佹寧绋戝澧倁jie.pa:176295-176326`闂佹寧绋戦ˇ顓㈠焵?
   *
   * `effT = 閻熸粏鍩囬崹纭呫亹婢跺鈻?? morphT : 1` 闂?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夆偓娑滃焻 1闂佹寧绋戦悧鍡楃暤?`pullBgIn = 1`闂佹寧绋戦ˇ顓㈠焵?
   * 闂佸疇娉曟刊瀵哥箔?闂佸搫鐗滈崗娑氬垝閵娾晜鍎?閻熸粏鍩囬崹纭呫亹婢跺浜ゆ繛鎴灻?闁诲海鏁搁幊鎾惰姳?`morphP`闂佹寧绋戦悧鍡涙儓瀹ュ拋鍤曢柍?0闂? / 闂佽　鍋撻柟顖滃瀹?1闂?闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪鎯旈姀鈽呴獜闂佷紮绲介惉鐓庘枔?`morphT` 闂佸憡鑹鹃懟顖濄亹濞戞﹩鍤楅柛鏇楁杹閸?
   */
  private pullBgIn(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    // 内容窗口（上游 `pullBgIn = clamp(effT / PULL_BG_IN_END)`，`wujie.pa:176295-176326`）取**内容时间线**
    // ⇒ 560ms + `EASE_OUT_STR`，与几何那条 350ms 分开（见 `PlayerExpandState.contentP` 的说明）。
    const raw: number = this.expandState.contentProgress() / PlaybackPage.PULL_BG_IN_END;
    return raw < 0 ? 0 : (raw > 1 ? 1 : raw);
  }

  /**
   * 闂佸湱鍎ょ敮鎺楁偩妤ｅ啯鍤婃い蹇撳琚熼梺琛″亾闁诡垳澧楀畷鎶芥煏?
   *
   * 闂?`setTimeout` 闂佸吋婢樻總鏃傜箔婢舵劕鍙?`setInterval`闂佹寧绋掗懝鎹愩亹瑜忛幉鐗堟媴閸︻厽袞濠电偛妫岄埀顒€寮堕崬澶娒瑰鍕诞闁革絾鎮傚顒勬偋閸繄鐟╂繛鎴炴尨閸嬫挻绻涢崱蹇婂亾閾忣偆娈ゆ繝銏犲閸犲秶鑺遍敓鐘虫櫖?
   * 闁汇埄鍨遍幃鍌炲煘濡ゅ啠鍋撶憴鍕暡婵＄偛鍊垮畷鎶藉Ω閵堝洨鐛ラ梺闈╄礋閸旀垿濡存径鎰棃妞ゎ偒鍘鹃悷婵嬫煕濞嗘ê鐏ユい顐㈡瀵噣宕滄担鍙夋櫈闁哄鍎愰崜銊ф濞嗘挸绠绘い鎾跺枑閺夌懓顪冮妶鍥ㄦ毄缂侇噯绱曢弫顕€骞栨担瑙勭槪闂佸搫鍟悥鐓幬涢崸妤€绠伴柛灞剧矋缁插鏌ㄥ☉姗嗘Ф闁?
   */
  private scheduleChromeAutoHide(src: string = ''): void {
    // 照搬无界 `PlayerPage.startIdle`（`_recover/disasm/wujie.pa:179903-179985`）：
    //   clearIdle();
    //   if (!entryAllowsAuto(this.lyricImmersive)) { return; }        ← 唯一的一道门（179946-179963）
    //   this.idleTimer = setTimeout(() => { this.idleTimer = -1; this.hideChrome(); }, IDLE_MS);
    //                                                                  ← `IDLE_MS = 5000`（MiniMorph…md:172）
    // ⚠️ 本仓原先在这条门里还串了 `!state.isPlay` —— 上游**没有**这一条，
    //    它的效果是"一暂停就永远收不起来"，本轮删掉（就是用户说的"始终无法收起"）。
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
    this.chromeTimerId = setTimeout((): void => {
      this.chromeTimerId = -1;
      // 上游 `entryAllowsAuto(this.lyricImmersive)` 在本仓的等价物 = 手机 Swiper 布局的歌词页；
      // `play=` 只作为诊断量打印，**不再当门**（上游没有这条）。
      if (!this.isAlive || this.chromeCollapsed || !this.canHideLyricChrome()) {
        // 5s 到点却什么都没发生 = 命中这条 bail；把判据一次打全，真机 grep RzdLyricChrome 即可判读。
        Logger.info('RzdLyricChrome',
          `hide auto bail cc=${this.chromeCollapsed ? 1 : 0} ` +
          `canHide=${this.canHideLyricChrome() ? 1 : 0} ` +
          `play=${this.state.isPlay ? 1 : 0} sw=${this.playbackSwiperIndex} ` +
          `pend=${this.lyricChromeMeasurePending ? 1 : 0} chH=${this.lyricChromeHeight.toFixed(1)}`);
        return;
      }
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`hideChrome()` 闂?闂傚倸鐗勯崹鍝勵熆濡警鍤曢柍褜鍓熼幆鍫ュ焵椤掑倷鐒婇柛娆愵焽閻熸繈鏌￠埀?闂佹寧绋戦悾鐠c.txt:4124-4225`闂佹寧绋戦¨鈧紒?
      //   闂備緡鍙忕徊鑲╃博閹绢喖绾ч柍鈺佸暞绗?10 婵炴垶鎼╂禍顏勵焽娴兼潙绾?flag 闂佹眹鍔岀€氼噣鎮￠鐘冲磯妞ゆ牗绋戦悘妤呮⒑閻愵剚瀚曠紒閬嶄憾瀵敻顢栫捄銊﹀皾闂佹眹鍔岀€氼剟宕规惔銊︾厒闊洦鍑瑰?`auxSheetOpen` 闂佹眹鍔岀€氼參寮悙鐑樼厒?
      //   闂佹寧绋戦悧鎰亹瀹ュ纭€闁哄洦姘ㄩ閬嶆煛?闂?`playMenuOpen`闂佹寧绋掗惄顖毼ｉ敃鍌氱?闂佺绻戝﹢鍦垝椤掑嫭鍋嬮柛顐ゅ枑閹?闂?`auxSheetOpen`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婇鎮潏銊р枖妞ゅ繐鐗嗛崢鎾偡閺囨氨顦﹂柛銊ょ矙婵?
      // 面板守卫已经收进 `hideChrome()`（照搬上游：守卫在 hideChrome，不在定时器起手处）。
      // 濠殿喗绻愮徊钘夛耿椤忓牆缁╅柟顖滃瀹?闁诲繒鍋炲ú鏍閹达箑绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ婵＄偛鍊圭粙澶婎吋閸℃せ鍙洪梺?
      if (this.isCollapsing()) {
        return;
      }
      // 到点就收：能不能收（面板开着/已收起/正在收起）全权交给 `hideChrome()` ——
      // 上游同样是这个分工（`startIdle` 只管定时，守卫都在 `hideChrome`）。
      this.hideChrome(`idle:${src}`);
      Logger.info('RzdLyricChrome', `hide auto naturalHeight=${this.lyricChromeHeight}`);
    }, PlaybackPage.CHROME_AUTO_HIDE_MS);
    Logger.info('RzdLyricChrome',
      `idle arm 触发源=${src} ms=${PlaybackPage.CHROME_AUTO_HIDE_MS} sw=${this.playbackSwiperIndex}`);
  }

  /**
   * @returns 闂佺鐭囬崘銊у幀闂佸憡鐗滈崕銈呂ｉ幖浣歌Е闁挎洍鍋撶憸鏉垮级缁?闂佽　鍋撻柟顖滃瀹曟娊鏌?闂佹寧绋戦悧鎰板吹濠婂牆绀夐柕濞р偓閺佸嫰姊婚崒姘骇闁轰礁婀遍幐?+ 闂佸綊鏀遍悧鏇熸叏閳哄懎缁╅柟顖滃瀹曟娊鏌涜箛姘惈闁轰降鍊栧璇测枎鎼达綆浼囬梺纭呮硾閿曨亜螞椤掑嫭鏅璺虹墐閸?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闁荤姳闄嶉崹娲敆濠婂嫮鈻斿┑鐘辫兌椤忛亶寮堕悜鍡楁灓婵炲牊鍨剁粙澶愬焵椤掍胶鈻旀い蹇撶墛閺呪晝绱撴担瑙勫磩妞?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐ょ礊鐎ｎ喖绫嶉悹鍝勬惈濞懷囨煟?`startIdle` 闂佸憡鍔曢幊姗€宕曢幘顔芥櫖閻忕偛澧界涵鈧繛瀛樼矊濡瑦鏅跺澶婂珘濠㈣泛娴峰▓鍫曟煟椤剙濡块柛?*闂佹寧绋戦ˇ顓㈠焵?
   *
   * ## 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄤ簽閻ㄦ垿鎮楅崷顓炲壋缂佽鲸澹嗙划姘洪鍜冪闯闂佽　鍋撻柟顖滃瀹?*闂佸憡鐟禍婊冿耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊濆褑銇愰崒鐐村仺?*
   *
   * 婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏃囨閻忓鎮归崶顏嶅殭闁?`startIdle()`闂佹寧绋戝濉抣ayerPage.abc.txt:12394-12435`闂佹寧绋戦ˇ鐢稿闯閻戣姤鐒介柨婵嗩槷婢规洟姊婚崒妯哄婵?
   * `entryAllowsAuto(this.lyricImmersive)`闂佹寧绋戦惌渚€鍩€?`lyricImmersive` 闂?*闂佹椿娼块崝宥夊春濞戙垹纾婚煫鍥ㄦ尪閸?*
   * 闂佹寧绋戝澧倁jie.pa:169823-169825`闂佹寧绋掗悺鐚糷is.lyricImmersive = pref.lyricImmersiveMode`闂?
   * 闂?婵炲瓨绮岀€涒晛危閹间礁绀冩繛鍡楁捣閸熷﹪鏌?*闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ灡閿涘苯鈽?閻熸粎澧楅幐鍛婃櫠閻樿鎹堕柕濞垮劜閹插灝鈽夐幘顖氫壕婵?闂佸搫鍟版慨鎾矗?闂?闁诲繐绻嬬欢姘焽閻楀牄浜滈柛蹇撴憸閻﹀秴霉閸忓吋鐨戦柍瑙勭墵濮婂宕ｆ径瀣瘑闁?*闂侀潧妫楃粙鍕?
   * 濡ょ姷鍋犻崺鏍ㄤ繆閹间礁瀚夋い鎺嶇劍閻撴瑦绻涙径瀣闁哄倷鑳堕埀顒傤攰濡嫰宕?`usesPhoneSwiperLayout()`闂?
   * **闂備緡鍙忕徊濂告煂濠婂牆绠抽柕濠庣厛閸熷牓鏌￠崟闈涚仸闁轰礁锕幆?* 闂佺偨鍎查弻锟犲焵?婵＄偑鍊楅弫璇差焽娴煎瓨鍎嶉柛鏇ㄥ灡椤庢瑩鏌涢幒鎾存瀯缂佹顦靛畷?`startIdle` 闂備焦褰冮惌澶屾濠靛鍤€閻忕偠濮ら煬?*闁诲海鎳撻崯鏉库枔閹存粳鎺曠疀鎼达綆浼囨繛鎴炴惄娴滐綁鎯冮悢鍏煎仺闁靛ě鍐у寲**婵炴垶鎸搁…顓犳?
   *
   * | 闁荤姴顑呴崯浼村极閵堝鍊?| 闁诲孩绋掗〃澶嬩繆椤撱垺鍎?| 闂佸搫顦埀顒€寮堕?|
   * | --- | --- | --- |
   * | swiper `onChange` | `abc.txt:23189-23215` | **`index === 1`闂佹寧绋戦悧濠囨偤閺囩姵瀚氱€广儱顦埀顒€顦甸弫宥嗗緞閸℃顏?`startIdle()`**闂佹寧绋掔粙鎴﹀箚娓氣偓瀹?闂?`clearIdle() + showChrome()`闂?*婵炴垶鎸哥粔鐑藉箲閿濆洦濯奸柍鈺佸暞椤?*闂?|
   * | 濠殿喗绻傞惌渚€鎯佸┑瀣濡わ箑鏅濋弴銏犵闁告稑锕よⅵ闁荤姍鍐ㄦЩ濠?| `abc.txt:6914-6932`闂佹寧绋戝濉穘LyricInteract`闂?| 婵炲濮撮幊搴★耿?*濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻?*婵?`!chromeHidden` 闂?`startIdle()` |
   * | 濠殿喗绻傞惌渚€鎯佸┑瀣閺夌偞澹嗛悷鎾寸節?| `abc.txt:6938-6985`闂佹寧绋戝濉穘LyricSwipe`闂佹寧绋戦悾鐠穎fsetY 闂?SWIPE_TOGGLE_VP 24`闂?| 婵炲濮撮幊搴★耿?*濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻?*闂佹寧绋掗悺鐚籬owChrome() + startIdle()` |
   * | 濠电偛鑻ˇ浼寸叓閸惊鐔煎灳瀹曞洨顢呴梺鍛婄懄钃辨繛?| `abc.txt:7766-7800` | `entryAllowsAuto(mode) && !chromeHidden && swiperProgress > 0.5` |
   *
   * 闂?**闂佹悶鍎茬粙鎰版煂濠婂懏灏庡瀣娴狀垶鏌涜箛瀣婵犫偓椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊楅。顔炬濠靛鍤€閻忕偠妫勯悗濂告煕閹烘挻绶查柣銊︾箞濡啴濮€閵堝啠鍋撴径鎰劷闁挎繂瀚閬嶆煛閳ь剟顢涘☉娅猴箓鏌￠崟顒€鍔ょ紒鎲嬬節閹?`clearIdle()`**
   *   闂?**闂佸搫鍟版慨鐑藉疾椤愶箑鎹堕柕濞垮劤濞堥亶姊婚崼娑樼伈闁靛棗顦扮粙澶婎吋閸曨厾鐛ョ紓浣告湰濡炶棄螞娴犲缁╅柟顖滃瀹曟娊鏌熺挩澶婂暙閻撴垿鏌?*闂?
   *   闂?闂佸吋婢樻總鏃傜箔閺嶃劍浜ゆ繛鍡樺姦閸斺偓闂佸搫瀚烽崹鎶藉极閵堝绠ｉ梺鍨儐閿涘秹鏌涜箛鎾跺濠殿喓鍊濋幆鍐礋椤栨矮绨兼繛鎴炴尨閸嬫捇鏌℃径鍡橆潐缂佸彉鍗虫俊瀵镐沪閻愵剛鐣抽梺?*闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柣銏犲濞存洖顪?*婵炴垶鎸搁鍡涘蓟閻旂厧绀勯柣姗€浜堕崵瀣煙缁嬫妯€闁规瓕娅曠粙濠囨偄閸撲胶鐛ラ梻鍌氭噺閸旀ê螞瀹€鍕ョ€广儰璁查崑鎾诲棘鐞涒€充壕?
   *     闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏犳啞椤撴椽鏌﹀Ο铏圭婵?*闂佺懓鐡ㄩ崹鍐差煥?*闁汇埄鍨界粻鎺旀崲濮椻偓瀵爼濡疯閻ｉ亶鎮跺☉妯侯殭閻犳劗鍠栭弫宥囦沪閼测晝鎲归梺鍝勫閸ㄥ崬螞閵堝鍋╃€光偓閳ь剙鈻撻幋锕€违?
   *
   * ## 闂佺粯绮嶅妯猴耿椤忓牊鍎嶉柛鏇ㄥ亜閻忔煡鏌?
   * 闂佸綊娼ч鍡椻攦閳?Swiper 闁汇埄鍨伴崯顐︽儑椤掑嫭鏅柛顐ｇ箘濞堥亶姊婚崼娑樼伈闁?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻濞达絽鍟扮粻鐟扳攽閸屾侗娈ｇ紒?*婵?*闂佺顑嗙划灞斤耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊楅崑锝夊焵?
   * 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈囩箔鐏炲墽鈻斿┑鐘辫兌椤忛亶寮堕悜鍡楁灆缂佺媴缍佸畷婊冾吋閸ャ劎鏆犻梺鍛婂姈閻燂妇娑甸懜鐢碘枖闁逞屽墴閹虫稒娼忛崜褏顦ーWIDTH_SM && 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻缂佲偓娴煎瓨鏅鑸电〒缁€澶屸偓鐟板閸犳牠宕洪崱娑樼煑妞ゅ繐鎳忕瑧闁诲海顢婂Λ鍕偓瑙勫▕瀹曟岸濡堕崱妤冦偊闂佺懓绠嶉崹娲垂濮橆厾顩?
   *   `usesPhoneSwiperLayout()`闂佹寧绋戦悧鍛箔?`Swiper` 闂佹椿浜為崰搴ㄦ偪閸曨垰鍙婃い鏍ㄧ閸庡﹤霉閿濆牊纭堕柡浣靛€濆畷銉т沪閼测晩浼囬梺鍛婄懕缁茬晫娆㈤悙鐑樻櫖閻忕偟鍋撶痪顖滅棯椤撗冨⒕缂佽鲸宀告俊?
   * 闂佸疇娉曟刊瀵哥箔?闂佸搫鐗滈崜鐔肺涢鍕強?闂佺厧顨庢禍婊勬叏閳哄懎缁╅柟顖滃瀹?+ 闂佸綊鏀遍悧鏇熸叏閳哄懎缁╅柟顖滃瀹?闂佺绻楁禍顒勫极閵堝鍎?闂佺偨鍎查弻锟犲焵?婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲繒鈧灚绮撳顕€鎮╅崹顐ｇ彧婵?*闂備緡鍠涘Λ鍕亹瑜斿畷鐑藉Ω閿旂偓鎲欓柣鐘叉搐缁夊綊濡?*闁荤姍鍡樿吂缂傚秵妫冮幃?
   *   闂佹寧绋戝濉€arCollapse` 闂佸湱顭堥崐绋匡耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊楅弫濠氬磻閸涱喚闄勬俊銈勭娴犳﹢鏌涢幒鏇熺【閻忓浚鍨辩粙澶嬬節韫囨洜顦梺?
   */
  private canHideLyricChrome(): boolean {
    return this.usesPhoneSwiperLayout() &&
      this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
  }

  /**
   * 照搬无界 `LyricFollow.entryAllowsManual(mode)`
   * （`_recover/disasm/wujie.pa:264350-264367`，`LyricFollow&.#*#entryAllowsManual`）：
   * ```
   *   lda a3                        // a3 = mode
   *   ldlocalmodulevar 0x13         // LyricEntryMode
   *   ldobjbyname "MANUAL"
   *   stricteq 0x2, a3              // mode === MANUAL
   *   callruntime.istrue
   *   jnez L                        // 命中 ⇒ true
   *   ldlocalmodulevar 0x13
   *   ldobjbyname "BOTH"
   *   stricteq 0x6, a3              // mode === BOTH
   * L: return
   * ```
   * ⇒ `entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`。
   * 同族 `entryAllowsAuto(mode) = mode === AUTO || mode === BOTH`（`wujie.pa:264331-264348`，
   * 本仓 `scheduleChromeAutoHide()` 里那道门的等价物）。
   */
  private entryAllowsManual(mode: number): boolean {
    return mode === PlaybackPage.LYRIC_ENTRY_MANUAL || mode === PlaybackPage.LYRIC_ENTRY_BOTH;
  }

  /**
   * 照搬无界 `PlayerPage.hideChrome`（`_recover/disasm/wujie.pa:171993-172088`）。
   *
   * ```ts
   *   hideChrome() {
   *     if (this.chromeHidden) { return; }                    // 171999-172002
   *     if (this.queueOpen || this.settingsOpen || this.addplaylistOpen ||
   *         this.lyricmatchOpen || this.qualityOpen || this.lyricsetOpen ||
   *         this.sleepOpen || this.customSleepOpen || this.lyricoffsetOpen ||
   *         this.versionOpen) { return; }                     // 172004-172081（10 个面板的 || 链）
   *     this.getUIContext().animateTo({ duration: CHROME_ANIM_MS, curve: Curve.EaseInOut },
   *                                  () => { this.chromeHidden = true; });   // 172082-172087，闭包 λ `@6*#`
   *   }
   * ```
   * ⚠️ 上游这里**没有**"必须已经在歌词页"这条门（那条门在 `startIdle` 里）；
   *    本仓上一版的 `!canHideLyricChrome()` 与 `isCollapsing()` 都属于自造门，已删。
   */
  private hideChrome(src: string = ''): void {
    if (this.chromeCollapsed) {
      return;
    }
    // 上游 10 个 sheet flag 在本仓只有两个真面板：更多/音质菜单 与 辅助 sheet。
    if (this.playMenuOpen || this.auxSheetOpen) {
      Logger.info('RzdLyricChrome',
        `hide skip 触发源=${src} panel(menu=${this.playMenuOpen ? 1 : 0} aux=${this.auxSheetOpen ? 1 : 0})`);
      return;
    }
    this.stopChromeAutoHide();
    this.getUIContext().animateTo({
      duration: PlaybackPage.CHROME_ANIM_MS,
      curve: Curve.EaseInOut
    }, (): void => {
      this.chromeCollapsed = true;
      this.lyricChromeProgress = 0;
    });
    Logger.info('RzdLyricChrome',
      `hide 触发源=${src} naturalHeight=${this.lyricChromeHeight}`);
  }

  /**
   * Swiper 闂佺懓绠嶉崹浠嬪Υ婢舵劕绫嶉柛鎾茬劍閻ｉ亶鏌熺挩澶婂暙閻撴垿鏌涢弽顐㈠妺闁轰礁婀辨禍?闂佺偨鍎查弻锟犲焵?**闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔界劷闁挎繂瀚伴崵?`onChange` 濞?闂佹眹鍔岀€氫即鍩€椤掍礁濮囬柣鈯欏懐纾奸柟鎯ь嚟閳?*
   * 闂佹寧绋戝濉ecover/logic-src/PlayerPage.abc.txt:23189-23215`闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戝娌穉l 闂佽　鍋撻悹楦挎閸熸彃顭跨捄铏剐ｉ柣妤佸▕閺?*闂佹悶鍎抽崑娑氭暜椤愶絾鍙忛悗锝庝簽閹界喖鏌ら崫鍕偓濠氭偉濠婂懏鍏滄い鏃€顑欓崥?*闂佹寧绋戦懟顖炲吹椤撶喎绶?
   *   `_recover/disasm/wujie.pa:190080-190111`闂佹寧绋戦懟顖氱暤?`PlayerPage.@34*^1*#^1`闂佹寧绋戦¨鈧紒?
   * ```ts
   *   onChange(index) {                                  // a3 = index
   *     const L = 1;                                     // 190081-190082闂? SWIPER_INDEX_LYRIC闂?
   *     if (index === L) { this.startIdle(); }            // 190083-190089  闂?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻缁炬澘顦辩粣妤呮偣瑜忛弻澶愵敇閹间礁绫?
   *     else { this.clearIdle(); this.showChrome(); }     // 190091-190099  闂?闁诲繐绻嬬欢姘焽閻楀牄浜滅痪鏉款槺缁愭鏌涚€ｎ偆鐭庢い鎾存倐瀵?+ **闂佸搫瀚崕宕囨閿熺姴鑸归柕鍫濇噹濮?*
   *     this.atLyricScreen = (index === L);               // 190100-190105
   *     this.syncKeepScreenOn();                          // 190106-190109
   *   }
   * ```
   * 闂?**缂備礁鏈钘壩涢悾灞惧闁斥晛鍟ˇ褔鏌涘▎妯圭盎婵犫偓椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊撶徊濠氬箲?*闁哄鏅滈悷銈囩博閹绢喗鍊烽柣褍鎽滅粈澶愭煛閸曢潧鐏熺紒妤€鍊搁妴鎺楀传閵夛妇鏆?*闂佸搫瀚崕宕囨閿熺姴绀嗛柛鈩兩戦弳?*闂佹寧绋戦悧鍛箔婢舵劕鍙婃い鏍ㄧ☉閻忓霉閻欌偓閸撴氨鏁ぐ鎺戞妞ゆ挾濮甸悾閬嶆煥濞戞﹩妲存繝鈧?
   *    闂佺偨鍎查弻锟犲焵?goal 缂?4 闂佸搫顥￠幍鍐蹭壕鐎光偓閳ь剟鍩為弽顓熲拻闁煎ジ顤傞崥鈧梺鍝勫暢缂堜即鍩€椤掆偓缁夋挳宕虹仦绛嬫桨?*闂佸搫鐗嗛ˇ鏉跨暤娓氣偓瀹曪綁顢涘☉姘绩**闂佹寧绋戞總鏃傜箔婢舵劖顥嗛柍褜鍓涢幉鐗堟媴缁嬫寧娅冮梺鍝勭У閹爼鍩€?
   *    闂佹寧绋戦悧鍡氥亹閻斿吋鏅慨婵囶劖tartIdle` 闂佹眹鍔岀€氼厼顪冮崒鐐粹拹闁割煈鍠氶崺妤呮⒑?`IDLE_MS` 闂佸憡鐟禍婊冿耿椤忓棙瀚氶柕澶堝劚濮ｆ劙鏌℃担宄板祮闁革絿鍏樺畷娆撴惞閻熸壆鐤€婵炴垶鎸撮崑鎾寸箾閸″繑顫夌紒?
   *      `wujie.pa:179903-179985`闂佹寧绋掔粙鎺戯耿閻楀牏顩烽柟鐐墯閸ょ娀骞?`PlaybackPage.CHROME_AUTO_HIDE_MS = 5000`闂侀潧妫楅崑濠勬?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹鏌￠崟闈涚仭婵☆偁鍊濆鍫曞灳閸欏鍋?`touchChrome()`闂? 闂佸摜鍋戦崐鏇㈠吹?**+** 闁荤姍鍛効妞ゆ挻鎮傚顔炬媼閸︻厾顦梺鎸庣☉閼活垶宕埀顒勬煕閿斿搫濮傛繛纰变簻椤垹鐣濋崘顏呅撴俊鐐€撶徊鏄忔＂婵炴垶鎸撮崑鎾绘煕?
   *   `stopChromeAutoHide()`闂侀潧妫楅崐鍧楀磻閸涙潙鍐€鐎瑰嫮澧楅煬?*闂佸憡甯掑ú銈夊春瀹€鈧禍鍛婄瑹閳ь剙顭囬悧鍫涗簻?*闂佸搫鍟抽崺鏍?闂佺绻愰悧鎰板箲閿濆洦濯奸柍鈺佸暞椤ρ囨煕閹邦剛孝濞寸姷濞€楠?闂?
   *   闂佸憡鍨熼崑鎾绘煛娴ｅ摜澧涢柣蹇擃樀閹煎綊鎮剧仦钘壭佹繛鎴炴⒒閸犲酣顢氶鈧弫宥囦沪閼测晝蓱婵炴垶鎸哥€涒晛螞閵堝鍋?闂備緡鍙忕紞渚€宕抽悜钘夊唨閻熸瑥瀚幏鍗炩槈閹惧磭孝闁轰焦绮撳畷?vs 闁哄鏅滈悷鈺呭闯闁垮顕辨慨姗嗗墯閺嗗懘鏌?闂佹眹鍔岀€氼剙螣婵犲洤绀嗘い鎰╁労濞煎爼鏌熼幆閭︽綈閻㈩垪鍋撴繛?闂佺偨鍎查弻锟犲焵?
   *   闂佸搫鍟版慨鐑藉疾椤愶箑绀嗛柛銉戝啰鍘掗柣蹇撶箣缁舵艾顭囬悧鍫涗簻闁割煈鍋呯瑧**闂佸搫瀚崕宕囨閿熺姴鑸归柕鍫濇噹濮?*闂佹寧绋戦悧蹇涘极閵堝绠ｉ柧姘€婚惌銈嗘叏濠靛棛鐒烽柣锔界箖閵囧嫰宕归銈嗗闂佹悶鍎抽崑鐐差焽閻㈢绫嶉柤鎼佹涧娴犳﹢鏌涢幒鏇熺【閻忓浚鍨辩粙澶愬焵椤掑倵鍋撶憴鍕暡婵℃彃鎲＄粋宥夘敊閻愵剛鏆犻梺鎸庣☉椤р偓缂?
   *   闁哄鏅滈悷銈囩博閹绢喖绾ч柍鈺佸暙閻忓霉閻欌偓閸撴盯锝為銏╁晠鐟滃瞼寮ч崘顏佸亾閻㈠灚顏熺紒杈ㄧ箖閹?*闂佸憡鏌ｉ崝宥呪攦閳ь剙鈽夐幘宕囆㈤柟?*闂佹寧绋戞總鏃傜箔閺嶎偂鐒婇柟瀛樼矌閸?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垻顭堟禍婵嗏槈閹绢垰浜鹃梺琛″亾妞ゆ牗鐟ч悷婵嬫煕閻愵亜鈧洟宕?闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟遍梽鍕耿?*闂佸搫鐗嗛ˇ浼村礈娴兼潙缁╅柛鎾茶兌瀹?*闂佹寧绋掔喊宥夊垂濠婂嫮顩锋い鎺戝娴滄繂鈽夐幘顖氫壕闂佽　鍋撴い鏍仜濞呪€愁熆閼哥數鐓紒鏃€鎸抽弻?`canHideLyricChrome()`
   *   闂? `usesPhoneSwiperLayout() && 闂佺顑嗙划灞斤耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊楅妵鎰版煥濞戞﹩妲撮柛?闁诲海顢婂Λ鍕儓?闂傚倸鐗勯崹鍝勵熆濮椻偓閺屽洭鏁愰崟顔规嫛闂佽　鍋撴い鏍ㄧ懅閻熸繈鎮硅閺屽顢橀幖浣哥睄闂婎剚绁撮崑?
   *   婵炴垶鎸搁敃銉╂偉?`startIdle` 闂佺厧顨庢禍婊呮崲娴ｈ浜ゆ俊顖滅帛缁犳帗绻涚仦绛嬫Ч闂婎偄鐗嗚灒闁炽儱纾涵鈧紓浣圭☉椤︻垶宕幘顔界劸闁靛ň鏅滈ˇ鈺呮煥濞戞澧涙繝鈧悧鍫㈩浄闁圭偓鍓氶崵鐘诲箹?`entryAllowsAuto` 闂備緡鍙忕徊鎯ь焽椤栫偞鏅璺虹墐閸?
   *
   * @param index 闂佸搫鍊规竟鍡椻枔閹寸偑浜滈柛蹇撴憸閻熸捇鏌″鍛カ缂? = 闁诲繐绻嬬欢姘焽閻楀牄浜滅痪鏉款槺缁€? = 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻缁炬澘顦辩粈?
   */
  private onSwiperIndexChanged(index: number): void {
    if (index === PlaybackPage.SWIPER_INDEX_LYRIC) {
      // startIdle闂佹寧绋掗悺鐚籧heduleChromeAutoHide()` 闂佸憡鍔曢幊姗€宕曢幘顔藉殜妞ゅ繐瀚弫?`canHideLyricChrome()` 婵炴垶鎸哥粔鐢稿垂濮樿京鍗氶悗锝庝簼閻ㄦ垵鈽夐幘宕囆ｉ柡?
      this.scheduleChromeAutoHide('swiperOnLyric');
      return;
    }
    this.stopChromeAutoHide();
    this.showChrome('swiperOffLyric');
  }

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`BarCollapse`闂佹寧绋戦¨鈧紒?*闂佸綊鏀遍悧鏇熸叏閳哄懎绠崇憸宥夊春濡ゅ懎绾ч柍鈺佸暞閺嗩亪鎮?/ 闁诲繒鍋炲ú鏍?*闂?
   *
   * 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ墮椤や線鏌涢弮鍥ㄧ《濠殿喗鎮傞獮鈧ù锝堫潐缁ㄦ岸鏌ㄥ☉妯荤秮design/src/main/ets/logic/BarCollapse.ets`闂佹寧绋戦懟顖炴偤瑜旈幊鐐哄磼濠婂懎鐏?
   * `wujie.pa:83706-84140`闂佹寧绋戦ˇ顖炲礄閿熺姵鐒婚柟閭﹀幗閽傚寮堕悜鍡楀闁哥喐鎹囧畷?`common/musicbasic/.../model/BarCollapse.ets`
   * 闂佹寧绋戦悧鍡涘箚?`THRESHOLD = 1.5`闂侀潧妫斿ù鍥煀闁秴瑙﹂柟杈鹃檮閺佹岸鎮楃憴鍕惛闁逞屽厸濮婃ⅳun` 缂備線纭搁崹瀹犫叾闂侀潧妫旈懗璺好烘导鏉戝唨闁搞儻濡囬閬嶆煠妞嬪海绡€缂佹顦靛畷婵嬪Ω閵堝洨鈻曢梺?*250ms 闂佺厧鎼崐鍦矈?*闂佹寧绋戦ˇ顓㈠焵?
   * 闂佸搫鐗滈崜姘跺蓟閻斿皝鏋栭柡鍥╁仜濞懷囨煕鐎ｎ偆鐓悶姘抽哺缁傛帡寮甸悽鐢垫闂?*闂佺娉涢敃銊杺闂侀€涚矙閺呰尙鑺遍妸锔绢浄閻犺櫣鍎ゅ鎾诲级閳哄倻鈽夋?* + **闂佸湱顭堥ˇ顖炴偩閻樿櫕浜ら柡鍌涘缁€鈧梺姹囧妼鐎氼剚鎱ㄩ埡鍌涘婵犲﹤鐗冮弨鎶芥煕閺傝濡介柡浣告贡閹?闁诲繒鍋炲ú鏍?*闂?
   *
   * 闁荤姴娴傞崢铏圭不閻斿吋鏅柛顐犲灩瀵箖鏌熺捄鍝勵仼闁诡喗顨婇幆鍐礋椤曞懏鏂€婵炴垶鎸剧亸銊ф濮樿埖鏅?
   * ```
   *   閻?缂備線绠栧褔骞冨鍕枖閻庯綆鍋勯娆戠磼妲屾牕鐏ユい?闂?闂?.5vp 闂?COLLAPSE闂佹寧绋戦悧濠勬暜閸洖绀嗛悹鍝勬惈闂呮﹢鏌￠埀顒勫箚閻楀牆闂梺?
   *   閻?缂備線绠栧褔骞冨鍕枖濠电姴鍟懙鍦磼妲屾牕鐏ユい?闂?+1.5vp 闂?EXPAND  闂佹寧绋戦悧濠勬暜閸洖绀嗛悹鍝勬惈闂呮﹢鎮橀悙瀛樼缂佽鲸鍨块弫?
   *   閻?濠碘槅鍨兼禍婊堝箖濠婂牊鐓ュù锝呮憸閺?闂?闂佽桨鑳剁换婵堟啺閸℃稑绠ラ悗锝庝簻閳笺垽鐓崶鈺傛珪闁哄棙鍔欓弫宥夊醇濠婂懐鎲规繛鏉戝悑閼归箖骞忛弶娆炬桨鐎光偓閸愵亝袚濠碘槅鍨兼禍婵堝垝閿曞倸绠ラ柟鎯ь嚟娴犳悂鏌?
   * ```
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鏌ｉ崝搴ㄥ极閹€鏌﹂悹鎭掑妽閺嗗繘鏌￠崼顐㈠⒋闁靛棗顦靛顕€濮€閳╁啰鐣抽梺姹囧妼鐎氫即宕戦崨顔锯枖闁逞屽墯缁鸿棄螖鐎ｎ剛顦ーchromeCollapsed` + `lyricChromeProgress`闂?40ms `EaseOut`闂佹寧绋戦¨鈧紒?
   *   婵炴垶鎸稿锕傚吹濠婂牆绀夐柕濠忛檮閺嗩亪鎮硅閸ゆ牜妲?s 缂備礁鏈钘壩涙禒瀣櫖?*闂佺绻楁禍顒勫极閵堝瑙﹂悘鐐跺亹椤忛亶鏌℃竟婧垮€楅悢鍛偓?* 闂?婵炴垶鎸堕崐妤咃綖閹烘绀傞柕澶堝劚缂嶆捇鎮峰▎蹇撯偓褰掑礉閸涱喚鈻旈柍褜鍓熼幊娑樓庨钘変壕?
   * 闂佸疇娉曟刊瀵哥箔?闂佽　鍋撻柟顖滃瀹曟娊姊婚崒妯哄闂侇喓鍔戦幃?`canHideLyricChrome()` 闂佺偨鍎查弻锟犲焵?**婵炴垶鎸稿锕傚吹濠婂牆绀夐柕濠忛檮閺嗩亪鎮硅閻忔岸鍩€椤戣法鍔嶉悗姘儔瀹曟繈濡搁敂鑺ユ瘑闁荤姍鍐ㄦЩ闁诡喗鎸荤粙澶愬焵椤掑嫬绠┑鐘叉处閿?*
   *   闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`startIdle` 闂佸憡鑹炬鎼佹偩閻樺樊鍟呴柛娆忣槹閺夊綊鎮楃涵鍛棄闁?闂佸綊娼ч鍡椻攦閳?Swiper 闁汇埄鍨伴崯顐︽儑?闂佹寧绋戦懟顖炲箚閸澀鐒婂〒姘ｅ亾婵炶偐澧楅妵鍕枈婢跺瞼顦柣鐔哥懁缁舵岸宕戦崨顔锯枖妞ゅ繐鎳忛悡娆愮箾婢跺绀堟繛鍫熷灥閳绘棃濡搁埡浣圭彽闂佹寧绋戦ˇ顓㈠焵?
   *   闂佸湱顣介崑鎾趁归悩顔煎姍缂佹顦扮€电厧顫濋鈧В澶愭煟?闂佺厧顨庢禍婊勬叏閳哄懏鍤勯柤鎭掑劜閺嗩亪鏌曢崱鏇犲妽閻庢艾顑夊畷婵嬪Ω閵堝洨鎲归梺鐓庣枃婵倝寮?闁哄鏅滈悷褔锝為幒鎾垛枖鐎广儱瀚閬嶆煠闁垮鏆橀柍?
   * @param event 闂佺鐭囬崘銊у幀闂佸憡鐗曢幖顐︻敊閹版澘闂柕濞垮€楅悷鎰版煟閵娿儱顏悮婵嬫煙娴犲娅滅紒銊ｅ妽缁?
   */
  private onChromeBarTouch(event: TouchEvent): void {
    if (!this.canHideLyricChrome()) {
      return;
    }
    const touches: TouchObject[] = event.touches;
    const first: TouchObject | undefined = touches.length > 0 ? touches[0] : undefined;
    const action: BarAction = this.barCollapse.reportTouch(event.type,
      first !== undefined ? first.windowX : 0,
      first !== undefined ? first.windowY : 0,
      touches.length, Date.now());
    if (action === BarAction.COLLAPSE) {
      Logger.info(PlaybackPage.logTag,
        `RzdBarCollapse action=COLLAPSE collapsed=${this.barCollapse.isCollapsed()} axis=${this.barCollapse.lockedAxis()}`);
      this.hideChrome('barCollapse');
    } else if (action === BarAction.EXPAND) {
      Logger.info(PlaybackPage.logTag,
        `RzdBarCollapse action=EXPAND collapsed=${this.barCollapse.isCollapsed()} axis=${this.barCollapse.lockedAxis()}`);
      // 闁诲繒鍋炲ú鏍?= 闂佸搫鐗滈崜鐔煎Υ婢舵劕绫嶉柕蹇婂墲缁犳帡鏌?闂佸摜鍋戦崐鏇㈠吹椤撱垹绠崇憸宥夊春濡ゅ懎绀?闂佹寧绋戝濉紀uchChrome()` 闂備焦褰冮惌鍌炲磻閸涱厸鏋?240ms 闂佸憡鏌ｉ崝搴ㄥ极?+ 闂備焦褰冪粔鍫曟偪閸℃瑧鐭氭繛宸簼閿涙繈鎮规担鎻掑⒉婵＄偛鍊块弫?
      this.touchChrome('barCollapse');
    }
  }

  /** 闂佺顑嗙划宥囨暜閳ь剟鏌ゆ總澶夌盎濠殿喒鏅犲銊╁箚閻楀牆闂柣鐘辫閸撴繂顪冮崒鐐存櫖闁割偁鍎埀顒€顦靛Λ鍐閻樿尙銈婚柡澶屽仜椤洟鍩€椤戣法顦︾紒杈ㄥ灦閹便劎鈧綆鍋呴弳顏堟偣瑜旈弨閬嶅箰闁秴缁╅柟顖嗗嫮褰滈梺鍝勫暞閸庡ジ鎯冮悢鍏煎仺妞ゎ厽甯炵粈鍡涙煏?*/
  private stopChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
  }

  /**
   * 闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮?`PlayerPage.onLyricInteract()`闂佹寧绋戝濉ecover/logic-src/PlayerPage.abc.txt:6914-6932`闂佹寧绋戦¨鈧紒?
   *
   * ```ts
   *   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
   * ```
   * 闂佸湱顭堥崐钘壝归崶顒佸€烽柣鐔哄闊剟鏌涘顒佹拱闁哄鍟粋?`190116-190130`闂佹寧绋掗懝鎹愩亹瑜斿?**`TouchType.Down`** 闁荤姴顑呴崯顐︽偩閻樿违?
   *
   * 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸堕崐鎾绘煂?婵炴垶鎸哥粔鐑姐€呴敃鍌氱闁绘劗鍎ら弲?闂?
   *   閻?闁?*闂佸憡鐟禍锝夊箲閿濆洦濯奸柍鈺佸暞椤?*闂佹寧绋戝濉籺artIdle`闂佹寧绋戦¨鈧紒?*婵炴垶鎸哥粔鎾极濠婂牆绀?*闂佺鐭囬崘銊у幀闂?闂?闁哄鏅滈悷鈺呭闯閻戣姤鍋?`scheduleChromeAutoHide()`
   *     闂?*婵炴垶鎸哥粔闈浳?* `touchChrome()`闂佹寧绋戦悧鍡涘箖濡ゅ懏鍤€?= `showChrome()` + 闁荤姍鍛効妞ゆ挻鎮傚顔炬媼閸︻厾顦梺鍝勫閸ㄦ媽銇愰悢鍝モ枖闁逞屽墴瀵爼妾遍柣顓犲亾缁嬪绻濋崟顒傛殸缂傚倷绀佺€氼剟骞冩惔銊︽櫖濠㈣泛鐗冮崑?
   *   閻?闂佸搫顦埀顒€寮堕浠嬫煛?`!chromeHidden`闂佹寧绋戦悧鍡涘礄閿涘嫮纾奸煫鍥ㄦ⒐閺嗩亪鎮硅閺€鍗烆渻?*婵炴垶鎸哥粔鐑藉箲?*闁荤姳璁查崜婵嗩渻閸岀偞鏅璺烘濞?闁哄鏅滈悷鈺呭闯妞嬪簶鍋撻悽鍨殌缂?`!chromeCollapsed`闂?
   */
  private onLyricInteract(): void {
    if (this.chromeCollapsed) {
      return;
    }
    this.scheduleChromeAutoHide('lyricInteract');
  }

  /**
   * 婵犮垻鎳撻崯鍧楁儑娴兼潙绠柨鏇楀亾闁糕晛鐬奸崠鏍嚒閵堝洤鐓氶柡澶嗘櫆閺屻劌煤閺嶎厽鏅柛顐秵濞诧絾鎱ㄩ悷鏉库偓鎼佸矗瑜斿濠氼敇閻旂鍟婇梺琛″亾濡わ絽鍟ㄩ埀顒€顦甸弫宥嗗緞閸℃娅?闂佸湱铏庨崢浠嬪极閸︻厽灏庣€瑰嫭婢樿闂佹椿婢€缁鳖喚妲愬┑鍥┾枖鐎广儱鐗滃ú锝夋煟閳轰胶鎽犻悽顖涙綑閳藉宕煎┑鍕澀闂?
   *
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍡椕洪弽顓熺劵闁逞屽墴瀹曘儲鎯旈妸銉︻仧闂佺顑嗛悢顒傛濮樿埖鏅?*闂佸憡甯炴慨鐢垫暜閳ь剟鏌涘Ο鐓庢瀾婵炶偐鏁婚弻鍥晲閸涱厾绋?`setTimeout(0)`**闂?
   *   閻熸粎澧楅幐鎼佸礋妤ｅ啯鍎嶉柛鏇ㄥ墯閺嗗牓姊洪幓鎺炲伐闁哥喐鎹囬幆鍐礋椤掍絿?婵炴垶鎸哥粔鐑姐€呴敃鍌氭嵍?`@Monitor` 闂佹悶鍎抽崑鐘绘儍閻斿吋鐓傜€光偓閳ь剙煤閸ф绠?`animateTo`闂佹寧绋戦張顒€锕㈡笟鈧畷锝夘敍濠靛棗骞嬫繛鎴炴尭缁変絻銇愰崘顔肩９? 闂佺偨鍎查弻锟犲焵?
   *   闁哄鏅滈悷銈夋煂濠婂牊鍋濋柟宄扮焷閺変粙鏌￠崟闈涚仯婵犫偓閿涘嫧鍋撻崷顓炰粶闁宦板姂瀹曠兘濡歌閻ｉ亶鏌ㄥ☉妯侯殭缂佹煡绠栧浠嬫偡閻楀牏顦繛鎴炴尭缁夐潧危?闂佸憡鏌ｉ崝搴ㄥ极閻愵剚濯存繝濠傛噺閺嗗繘鏌?闂佹寧绋戦惌渚€鍩€椤掆偓閺堫剙危閸濄儮鍋撶憴鍕嗘垿寮婚悢鍏煎剭?
   *   **闂侀潧妫楅懟顖氾耿?`@Monitor` 婵炴垶鎼╅崣鈧悮婵嬫煕?`animateTo` 闂佸搫鍟﹢鍦箔婢舵劕鍙婇柛鎾椾椒绮甸梺鍛婃煟閸斿酣寮ィ鍐ㄎ?*闂?
   *   V2 闂佺粯顭堥崺鏍焵椤戣法顦︾憸鏉款樀閺屽矁绠涙惔銏犲伎闂佽　鍋撻悷娆忓绗戦悗娈垮枛閸婂綊顢楅悙鍝勫唨闁搞儺浜滄竟鍫ユ煥濞戞ɑ鎭璻omise 閻庣敻鍋婇崰鏇㈠箲閵忋倕绀夐柍钘夋噽缁€鍡涙煥濞戞鐒烽柍?`animateTo` 缂備焦鏌ㄩ鍛村春閵忋倕绀嗛梺鍨儐閻撯偓闂佸吋娼欑换妤佷繆椤撱垺鍊烽柣鐔告緲閺嬧偓闁诲氦顫夊畝鎼併€呴懡銈嗘殰鐟滄繄妲?
   *   闂?`@Monitor` 闂佹悶鍎抽崑鐘绘儍閻斿吋鐓傜€光偓閸忣垰顦靛鑽ゅ鐎ｎ剛顔庡┑鐐插閳ь剙纾壕璇测攽椤旂⒈鍎滅紒杈ㄧ箘閹噣顢曢妶鍡欙紘闂佸憡鍑归崜娑樷枔閹达附鍋愰柤鍝ヮ暯閸嬫挻鎷呴崨濠勬閻庤鐡曠亸娆戝垝閿熺姴鎹堕柕濠忓閸ㄥジ鏌ら弶鎴犵婵¤绠撳畷姘旈崨顓燁仦 闂?婵☆偓绲鹃悧鏇㈠箮?闂佸湱绮敮鎺楀焵椤掑嫭锛熺紒妤€顦遍埀顒勬涧缁犲秹鍩€?
   *   闁诲氦顫夎摫闁哄瞼鍠栭弫宥夊锤閸掔劋kts-new-applysync-flushupdates-flushuiupdates`闂侀潧妫楁總鏃€绻涢崶顒佸仺闁靛鍎茬花姘舵煛?閻?闂佸憡鏌ｉ崝宥夊疾閵夆晛鎹堕柣鎴炆戦悵顖炴煏閸℃鈻岀紒杈ㄦ皑缁辨帒鈻庨幋鐐垫殸闂佸憡鍔栭悷锔炬兜?
   *   闁诲繐绻楁ご绋课ｉ幖浣告嵍?`animateTo` 闂佹眹鍔岀€氭澘螞閹绢喖绀岄柛娑欐綑濞咃繝鏌?`UIUtils.applySync` 闂佸憡鑹鹃張顒勵敆閻愬搫绀嗛梺鍨儐閻撯偓闂佺儵鏅╅崰妤呮偉閿濆纾?闂佺偨鍎查弻锟犲焵?
   *   `closeFullScreenPlayback()` 闂備焦褰冮懟顖炲礄閿涘嫮纾奸煫鍥ㄦ煥閻﹀寮堕埡鍌滄噥闂佸弶绮撳畷妯衡枎閹邦喓鈧﹪鏌￠埀顒勬焻濞戞艾鏅╅梺鎸庣☉閺堫剚鏅跺鍡欘浄闁靛鍔庣粻褰掓⒑閹绘帟瀚扮憸鏉垮级缁傛帡濡疯缁绢垶鏌熼幁鎺戝姤闁汇劎鍠栭幃浠嬪Ω閿濆倸浜?
   */
  @Monitor('expandState.collapseVersion')
  onCollapseRequested(): void {
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`MainPage.closeWithAnimation()` 闂佹眹鍔岀€氭澘顭囬鍫濈閻庯綆浜滈埣銏ゆ煕閹烘垶顥為柡渚囧櫍閺佸秵寰勫☉姘辩崶
    //   闁哄鏅滈悷锕€顭?Monitor 闂?*闂佸摜鍎愰崹顖滅博?*闂?闂傚倸鐗忛崑鐐存櫠濠婂牆绀夐柛顭戝枛瑜扮娀姊?闂佺绻堥崕杈亹濞戙垺鏅柛褍鍩€uardPlayerBack()` / 婵犮垻鎳撻崯鍧楁儑?`onBackPress()`
    //   闂備緡鍠栭埀顒傚枙濞?`expandState.requestCollapse()` 闂?`collapseVersion++`闂佹寧绋戦ˇ顓㈠焵?
    //   婵炴垶鎸搁鍡樺垔濞差亝鐒介柨婵嗘閽傚鎮?*婵炴垶鎸哥粔鍓佸垝閳╁啯浜ら柛銉簽缁犲綊姊?*闂佹寧绋戦悧鍡涙偩閻樼粯鍎庨悗娑櫭径宥夋偣?`closeFullScreenPlayback()`闂佹寧绋戦ˇ顓㈠焵?
    //   闂?闂佸湱顣介崑鎾趁归悩顔煎姤缂佺粯鐗犻弻宀€浠︾紒銏犲Η婵犻潧鍊藉Λ鍕敋椤旇姤鍎熼柡鍐ｅ亾婵☆偁鍊濋幃鎯х暆閳ь剙鈻?`pullMode === false` 闂備緡鍙忕徊鑲╃博閹绢喖缁╂い鏍ュ€楃粣?*闂佺懓鍢茬粔鎾箵閳哄懏鍋傜憸蹇曠磽婢舵劕鐐婇柟鎯ф噽缁€澶娾槈閹惧磭孝濠殿喒鏅涚叅濠电姵鍝庨埀顒€顦靛Λ?*闂?
    // ★★★ 2026-10-18（用户第五轮：「播放器**展开过程中**系统返回关闭会**抽搐**」）——照搬上游那道守卫：
    //   上游 `PlayerPage.closeWithAnimation`（`wujie.pa:171058-171075`）第一件事是
    //     `if (pullMode && ExpandSnapshot.onReverseMorph(myMorphSnap)) return;`
    //   即"形变会话还在跑 ⇒ **不收快照**，改成把**活着的形变反向收回去**"。
    //   我们原来无条件走"快照 + 收缩"：展开动画还在跑时，快照拍到的是**半路的样子**，
    //   随后被 `ShrinkOverlay` 整体缩小 ⇒ 观感就是"抽搐"（半路画面定住再缩）。
    //   ⇒ 展开中（`expandIntroRunning`）或相位还在 ENTERING/LANDING 时，走**活体反向**那条
    //     （`closeFullScreenPlayback()` = `morphBeginLeaving()` + `460×max(0.4,p)` 的 `REVERSE_EASING` 补间）。
    const closeStage: MorphStage = this.expandState.morphStage;
    const morphRunning: boolean = this.expandIntroRunning || closeStage === MorphStage.ENTERING
      || closeStage === MorphStage.LANDING;
    if (morphRunning) {
      // ★★★ 2026-10-18（用户第十轮：「展开中按返回**要等好久**才收起」+「会闪」）——照搬上游 `reverseIntentOf`：
      //   上游 `ENTERING` 相位收到关闭 ⇒ `START`：`retargetToLiveCover()` → `setMorph(LEAVING,ANIM)` →
      //   `animateMorphT(0, round(460×max(morphT,0.4)), REVERSE_EASING)`（`wujie.pa:154070-154133`）
      //   —— **立刻反向**，不等待、不拍快照。
      //   它之所以不闪，是因为 `pullT` 只有**一条**补间：反向就是把那条**重定向**。
      //   ⇒ 我们这边补上缺的那半句：先 `reverseInFlight = true` 让**壳层那条 560ms 打开收尾让路**
      //     （它原本到点会 `morphSettleOpen()` 把 `morphP` 拍回 1 ⇒ 闪；而且我们必须等它跑完 ⇒ "等好久"），
      //     再 `closeFullScreenPlayback()` 立刻反向。
      Logger.info(PlaybackPage.logTag,
        `RzdCloseLiveMorph reverse-now stage=${closeStage} intro=${this.expandIntroRunning ? 1 : 0} ` +
          `p=${this.expandState.morphP.toFixed(3)} cp=${this.expandState.contentProgress().toFixed(3)}`);
      this.closeAfterOpen = false;
      this.expandState.reverseInFlight = true;
      this.expandIntroRunning = false;
      this.closeFullScreenPlayback();
      return;
    }
    this.closeWithAnimation();
  }
  /** Fallback page background tint when art or color pick fails. */
  private static readonly defaultImageBgColor: string = 'rgba(32, 32, 32, 1)';

  /** 闂佺厧鍟块張顒€鈻嶅▎鎴犵＞闁瑰鍋熸竟鎰節瑜庨崝妯兼崲閺囩偐鏌﹂柍銉ュ暱閻撳倿鏌熼棃娑卞剱婵＄偛鍊块幆?*闂佸搫鐗嗛ˇ閬嶅疾椤愶附鐓傜€广儱鎳庣徊?*濠电偛妫岄崜婵嬪汲閻斿吋鏅柛顐秵濞?{@link scheduleBackgroundRetry}闂佹寧绋戦ˇ顓㈠焵?*/
  private static readonly BG_RETRY_MAX: number = 4;
  /** 婵炴垶鎸堕崐鏍敃婵傚憡鐓傜€广儱鎳庣徊鍨槈閺傛鍎旀俊顐㈡健閹啴宕熼娑崇吹闂傚倸鎳忓Λ鎴犳濡炬悞闂佹寧绋戦ˇ顓㈠焵?*/
  private static readonly BG_RETRY_MS: number = 400;

  /**
   * 闂佺厧鍟块張顒€鈻嶅▎鎴犵＞闁瑰鍋熸竟鎰節瑜庨崝妯兼崲閺囩偐鏌﹂柍銉ュ暱閻撳倿鏌?闂?闂傚倸鎳忛弻褏绮╃€涙ê顕辨慨姗嗗墮婵粙鏌涢幇顒傂㈢憸鏉挎处缁嬪鍩€椤掆偓閳诲酣鍩ラ崨顖滎槱**闂佸搫鐗嗛ˇ閬嶅疾?*闂佹寧绋戦ˇ顓㈠焵?
   *
   * 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劜娴犳﹢鎮烽弴姘鳖槮闁伙絿濞€閺佸秹宕奸姀鈩冩闂佽娼欓崲鏌ユ偪閸曨個鍦偓锝呭缁€鍡涙煥濞戞瑧顣叉繝鈧銏犵妞ゆ挾鍠愰弶褰掓煟濡灝鐓愰柍褜鍏涢懗鍫曞磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸嬫捇鏌熺紒銏犲箺闁哄倷绶氬畷鎶藉Ω閿旂瓔妲梺鐓庡暱閺堫剙鈻嶅▎鎾冲強妞ゆ牜鍋熼幏銊╂煟?闂佺偨鍎查弻锟犲焵?
   * 闂佹悶鍎虫慨宕囨嫻閻旂厧鎹堕柕濞у啯鐤囧┑顔界箓閺堫剙煤閹间焦鍎嶉柛鏇ㄥ幗閸╁倹鎱ㄥ┑鎾剁К闁稿孩顨婂鏌ヮ敍濞戞?*缂傚倸鍟崹鍫曟偋閹间礁鐐?*闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎮鹃悩鍨暫濞达綀娅ｉ幖?`song.cover` 闂佸憡甯炴晶妤佹櫠濠婂牆绠ョ€广儱鐔嗛幒鎴殫婵°倐鍋撻柛銈庡弮瀵爼濡烽婊冭€?
   * 闂佸湱铏庨崢浠嬪棘娓氣偓閹晠鎳滅喊妯轰壕濞达綁顥撶粣妤€顪冮妶鍥у妺濠⒀勭矒楠?metadata 闂佺懓鍢查ˇ鐢电礊閸儲鏅悘鐐村劤椤ｆ彃霉?闂佺粯鍔欓埀顒佺〒椤忓崬鈽夐幘鎰佸剱闁规悂浜跺銊╁箚瑜庨惃鎴炴叏濠垫挾鍒伴柣?闂?
   * 闂佺厧鍟块張顒€鈻嶅▎鎾崇煑妞ゅ繐娴傞崵澶愭偣?闁诲繐绻嬬欢姘焽娴兼潙瀚夊璺侯儑濮婇箖鏌￠崼婵愭Ц闁糕晛鐭傞獮?闂佸搫鐗嗛ˇ顖炲矗?闂?闁哄鏅滈悷鈺呭闯妞嬪海纾兼繛鍡楃箳閺嗗﹤鈽夐幘顖氫壕婵?*闂佽　鍋撻柤绋跨仛濞?*闂佹眹鍔岀€氼厼鈹冮埀顒€霉閸忕厧鎼搁柍?
   * @param jobSeq 闂佸憡鐟﹂崹濂稿箲閿濆鐒介柨婵嗘－閸嬔囨煕濞嗘劗澧冲鐟帮躬閹啴宕熼銈囶暡闂佸憡鐟ラ崵鏍濞嗘挻鍋ㄩ柕濞垮劤閺嗗﹪鏌涘▎妯虹仧濞存粍甯楃粙澶愬閻樼數锛為柡澶嗘櫅濞诧箑锕㈤敓鐘冲剭闁告洦浜為閬嶅级閻戝棗娅欑紒?
   * @param attempt 閻庣懓鎲￠悡锟犲闯閸濄儲瀚氶柡鍥╁櫏閸嬔囨煛?
   */
  private scheduleBackgroundRetry(jobSeq: number, attempt: number): void {
    if (!Number.isFinite(attempt) || attempt >= PlaybackPage.BG_RETRY_MAX) {
      Logger.info(PlaybackPage.logTag,
        `RzdBgRetry give up attempt=${attempt} meshVer=${this.meshSrcVersion}`);
      return;
    }
    setTimeout((): void => {
      // 婵炴垶鎸搁ˇ鍨妤ｅ啯鈷掓い顓熷笧缁愭顪冮妶鍥ㄦ毈婵炶偐澧楀璇参熼悜妯垮惈闂侀潧妫斿ù鍥╂崲閺嶃劎鈻旈柍褜鍓氬顏堫敊閻ｅ本鈷曢柣鐐村嚬閸嬪懘寮绘繝鍥ㄥ剭闁告洦浜為閬嶅级閻戝棗娅嶉柕鍡楋躬楠炴帗寰勯崼姘壕濞撴埃鍋撻柕鍡楊樀濡啴濮€閿濆洨顔庨梺娲讳簻椤戝懐娆㈡潏鈺傚枂?
      if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
        return;
      }
      if (this.meshSrcVersion > 0) {
        Logger.info(PlaybackPage.logTag, `RzdBgRetry ok attempt=${attempt}`);
        return;
      }
      Logger.info(PlaybackPage.logTag, `RzdBgRetry retry attempt=${attempt + 1}`);
      void this.getImageColorAsync();
    }, PlaybackPage.BG_RETRY_MS);
  }

  /**
   * Banner watcher: when switchBanner.ts advances, schedule a 3s clear.
   * Compares the parsed timestamp so an older clear does not blank a newer banner.
   */
  onBannerChange(): void {
    const ts: number = this.switchBanner.ts;
    if (ts <= this.bannerTs) {
      return;
    }
    this.bannerTs = ts;
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
    }
    this.bannerClearTimer = setTimeout((): void => {
      this.switchBanner.text = '';
      this.switchBanner.ts = 0;
      this.bannerClearTimer = -1;
    }, 3000);
  }

  /**
   * Re-runs onBannerChange whenever a new banner is published via AppStorageV2.
   */
  @Monitor('switchBanner.ts')
  onSwitchBannerTsChange(): void {
    this.onBannerChange();
  }

  /**
   * 闂佸憡鐟﹂悧鐐寸珶婵犲嫧鍋撻悷鐗堟拱闁搞劍宀稿畷銉︽償閵忕姈鈺呮煛閸屾瑥宓嗘い銈勭窔閹虫繈鎳犻鎸庡磽闁哄鏅滅粙鎺旂矈閿曞倸绀傚璺烘湰缁插鏌ょ憴鍕祷婵炲懏甯℃俊?
   *
   * 闂?`setEffectParams`闂佹寧绋戦悧鎰板焵椤掆偓婵傛梻绮径鎰強妞ゆ牜鍋涘▍銏⑩偓?`visualEffect`闂佹寧绋戦¨鈧紒鍙樺嵆楠炴垿濮€閿涘嫭鎲欓梺鍛婄懐娴滄繂煤閸ф妫?uniform闂?
   * 婵炴垶鎸哥粔宕囨娴煎瓨鐓傜€广儱鎳忛崕娆撴煟椤愮喎浜鹃梺鑹邦潐瑜板啫鈻嶉幒妤€违濞达綁顥撻惁宥呪槈閹惧磭小缂佽鲸澹嗛幏瀣煛閸屾嚎鍋婇梺?闁?闂佹悶鍎抽崑鐘诲箲閿濆鍊锋鐐茬氨閸?
   */
  @Monitor('coverTint.version')
  onCoverTintVersionChange(): void {
    this.applyCoverTint();
  }

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮?`MorphGuard` 闂?闂備焦婢樼粔閿嬬珶婵犲嫧鍋撻悷閭︽█婵炵鍊楃划锝呂旈埀顒冦亹?** 闂佺偨鍎查弻锟犲焵?闁?`morphQuietUntilMs` 闂佹眹鍔岀€氼厾鏁崷顓涘亾閻㈢偣鈧妲?
   *
   * @returns 闂佺粯绮嶅妯猴耿?*婵炴垶鎸哥粔鐑藉礂?*婵炴垶鎸搁敃銊︾珶婵犲洤绫嶉柟顖涘缁犵兘鎮烽弴姘冲厡闁烩剝鍨跺鍕潩椤掑倹鐦?ms闂? = 闂佸憡鐟崹顖涚閹烘梻鍗氶悗锝庝簻缁侇喖鈽夐幘绛归練濠㈢懓锕弫宥嗗緞閸艾浜?
   *   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸哥粔鐑藉礂濡崵鈻斿┑鐘叉噹椤ュ繘鏌￠崘顓炵厫婵犫偓娴兼潙绀勯柤鎭掑劜濞堣泛霉?*婵＄偑鍊楅崕銈嗘櫠濠婂牆绠抽柟鍝勭Ф椤忚鲸绻涢崱顓犵瘈闁革絽鎽滈幏?*闂佹寧绋戦悧鍡欑不閹惧墎椹冲鑸电〒缁愭colorRetryQueued` 闂佸憡鐟禍婊堝储閹寸姵濯奸梻鈧幇顕呬紘闂佸搫顦埀顒冩珪闊剙顪冪€ｎ剙鍓崇紒杈ㄥ哺閺?
   *   闂備焦褰冪粔鐑芥儊椤栫偞鈷掗柟缁㈠枟椤?= `wait + 32ms`闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸曨偂绨兼繛?`0x20` 婵炶揪绲鹃悷鈺呭闯濞差亝鏅鑸电〒缁€澶娾槈閹惧啿顒㈡俊顐犲€濋幃?`MainPage` 闂佹眹鍔岀€氼剟宕幘鏂ユ灃闁哄洠鎳囬崑鎾诲箛椤撶喕鎷柣搴ｆ暩閹虫挾鑺遍弻銉ノ?
   */
  private colorApplyWaitOrRetry(): number {
    const wait: number = this.expandState.colorApplyWaitMs();
    if (wait <= 0) {
      return 0;
    }
    if (!this.colorRetryQueued) {
      this.colorRetryQueued = true;
      setTimeout((): void => {
        this.colorRetryQueued = false;
        // 闂?2026-10-17闂佹寧绋掑畝鎼佸Υ婢舵劖顥堥柕蹇曞Т閸ゆ帡姊洪鐔蜂壕闂侀潻绠戦幖顐㈩潩閵娾晛绀嗘い鎰╁灩閺呮瑥鈽夐幘绛归練濠?闁荤偞绋忛崕宕囩礊婢舵劕鍐€?闂佺偨鍎查弻锟犲焵?
        //   闂佸搫鐗滈崜鐔煎Υ婢舵劖鍎嶉柛鏇ㄥ亜缁插潡鏌ょ憴鍕弨闁瑰€熷亹閹瑰嫰顢涘顓″惈闂備緡鍋€閸嬫捇鏌涢敂鎯у妺婵＄偛鍊圭€电厧顫濋銏㈡В闂佸憡鏌ｉ崝鎴﹀闯閹绢喖缁╅柛娆嶅劤缁夋挳鏌涢妷锔藉珪缂佽鲸鐟ч幉?`onDisappear` 闂備焦褰冮惌鍌炲磻閸涱喚鈻旈柕鍫濇噹缂?`releasePixelMapQuiet`闂佹寧绋戦¨鈧紒?
        //   闂佸吋鐪归崕瀵告崲閺嶎厼绾ч柨鐔哄Т濞呫垽鎮归崶銊︾缂佺粯娲熷畷?`commitMeshSource`闂佹寧绋戦惌鍌炲磻閸涱垯鐒婇弶鍫涘妽绗戦梺鐟板槻閵囨绮╅弶鎴殨?*閻庤鐡曠亸娆戝垝閿熺姵鐓傚┑鐘插暞閺夊綊寮堕埡浣瑰窛婵?*婵炶揪绲界粔鏉懨瑰鈧畷銏㈢磼濡搫绨ュ┑鐘欏嫬濮傞柍?
        if (!this.isAlive) {
          return;
        }
        // 婵炴垶鎸哥€涒晛螞閵堝鍋╃€光偓閸曨偂绨兼繛鎴炴惄娴滎亪宕抽崫銉﹀珰?濞?婵炴垶鎸撮崑鎾绘煠閻ゎ垱褰х紒鍙樺嵆瀹曟宕奸悢鍛婃緬閻庢鍠掗崑鎾搭殽閻愭彃鈧鎮洪幋锕€鍐€闁搞儺浜堕崬鍫曟煥濞戞瀚伴柛鐔插亾闂佺娉涢敃锝囩箔閸岀偞鍤岄柡灞诲劚濞呫垽鎮归悜妯虹仯缂佹梹鎸抽弻?
        // 闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閸愵亝顔嶉梺姹囧妼鐎氼厼危?`syncReportChrome()`闂佹寧绋掔粙鎺戯耿閻楀牏顩烽柟鐐墯閸ょ娀骞栫€涙ɑ鈷掓繛鍫熷灩娴滃憡娼忛妸蟺锕傚级閳哄倻鎳侀悶姘抽哺缁嬪顢旈崘顏嗘啰闂佽偐顢婄亸娆撳磻閿濆鏅璺虹墐閸?
        this.applyCoverTint();
        this.republishMeshSourceIfAny();
      }, wait + 32);
    }
    Logger.info(PlaybackPage.logTag,
      `RzdFlowLight color apply deferred ${wait.toFixed(0)}ms (morph quiet window)`);
    return wait;
  }

  /** 闂?{@link coverTint} 闂備焦褰冮惉鐓庘枔閹寸儑绱ｆ繝濠傛椤ュ繘鏌熼幁鎺戝缂侇喕鍗抽幆鍫ュ焵椤掑嫭鍤岄柟缁樺笚閻濄倝鏌ㄥ☉妯煎闁诡喗鎹囬幃褔宕奸悢鍛婂闂佸憡鐟ラ崲鑼躲亹瑜旈獮鎺楀Ω閵堝浂浼囧┑鐐叉濡插嫮妲愬璺何?*/
  private applyCoverTint(): void {
    if (this.coverTint.version === this.appliedTintVersion) {
      return;
    }
    // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁告瑯浜濆﹢?鐟滅増鎸告晶鐘虫交濞嗗海顏卞Λ锝嗙墱閻ｅ宕欓悜妯荤厐濡増绮忔竟?闁归潧绉堕悾?ready**闁?
    //   `coverTint` 闁哄嫷鍨靛▔鏇熴亜閻㈠憡妗ㄩ柛蹇撳綁闂娾晠鎯冮崟鍓佺獥闁圭鍊藉ù鍥焽閿濆嫮顏遍柛鎺曨嚙閻ｇ娀鎯?`version` 鐎规瓕灏欑划锟犲及?*濞戞挸锕ｇ粩瀛橈純?*闁伙絾鐟ょ粭鍛存儍閸曨偀鍋撶粭琛″亾?
    //   闁?`aboutToAppear` 闂佹彃鏈俊?`appliedTintVersion` 闁告帗绻傞～鎰板礌閺嶏箒绀嬬憸鐗堟尭婢х姵娼诲▎搴ㄥ殝 version闁? 閻熸瑥妫旂拹?鐎圭寮剁粔鐑藉礌?闁挎稑顧€缁?
    this.tintReady = true;
    // 闂?閻熸粏鍩囬崹纭呫亹婢跺备鍋撻悷閭︽█婵炵鍊楃划锝呂旈埀顒冦亹濞戙垹绀冮柛娑卞墰閻熸繂鈽夐幘绛归練濠㈢懓锕弫宥夊醇閿濆孩缍?`colorApplyWaitOrRetry`闂佹寧绋戦¨鈧紒杈ㄥ缁灚寰勫畝鈧畷鍫曟煕濞嗘瑧绉紒璇插暣瀹曘垻鎷犻懠顒佹疁婵炴潙鍚嬫穱娲吹濠婂喚鍟呴梺顒€绉村▍銏ゆ偣閸ャ劍纾荤紒鏃€娼欓埢搴㈠箠闁?
    if (this.colorApplyWaitOrRetry() > 0) {
      return;
    }
    this.appliedTintVersion = this.coverTint.version;
  }

  /** 闂備浇椴哥敮鐐裁烘导鏉戠闁归偊鍠撴禒娑欎繆椤栵絼绨荤紒鐘崇懇閺佸秴顫濋崜浣稿緭濠电姍鍕闁告挸銈稿鐢割敆閸愨晝銆婇梺鐓庣摠绾板秴锕㈡导鏉戠闁搞儯鍔屾惔濠囨煛閸愵厼鐓愭俊顖氼槺缁牓鎮€靛摜顦? 缂備礁顦扮敮鎺楀箖濡ゅ懏鍤婃い蹇撳琚熼梻鍌氭噺閸旀ê螞瀹€鍕?*/
  @Builder
  private SwitchBanner() {
    if (this.switchBanner.text.length > 0) {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_right_circle'))
          .fontSize(20)
          .fontColor([Color.White])
          .margin({ right: 8 })
        Text(this.switchBanner.text)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
      }
      .width('88%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .borderRadius(16)
      .backgroundColor('rgba(220, 60, 60, 0.95)')
      .margin({ top: 56 })
      .align(Alignment.Center)
    }
  }

  /**
   * 濠电偞鎯岄崰鏍儑閹殿喒鍋撶憴鍕叝缂傚秴鎳樺畷锝夋晲閸涱垳鐛梺鎸庣☉閻楀﹪寮總绋跨鐎广儱顦禍婵嬫煟濡も偓閻楀﹪寮悙鐑樼厒濠电姴鍟瑧**闂備焦瀵ч悷褍鈻?*闂?026-10-15 闂佸湱顭堥ˇ鏉匡耿娴兼潙瀚?SDK 闂佸搫娲ら悺銊╊敆濠婂牊鏅璺虹墐閸?
   *
   * 闂?闂佸搫鍞查崱鈺佹濠电偛顦板ú鈺冩娴兼潙违閻庣懓娼畂sition({x, y})` 闂佸搫瀚烽崹鏉匡耿?*闂佺厧顨庢禍鐐哄礉瑜庨幏鍛吋閸モ晜鐎?*婵炴垶鎸搁敃銈夊疮閳ь剟鏌涢弮鍌毿㈠ù婊冩憸缁梹瀵煎▎鎴狀槷闂佸湱顣介崑鎾趁归悩顔煎姎闁活亣娅曠粙澶愵敇閻樺磭鏆?Stack 闂備焦褰冮惌渚€銆呴敃鍌氱闁割偅绻傚▍?
   *    `(缂備焦鍔栭〃鍛般亹濞戞矮鐒婇柛婵嗗閸?闂?闂佺厧顨庢禍婊呮崲娴ｈ桨鐒婇柛婵嗗閸? / 2`闂侀潧妫楃粔鏌ュ焵?*婵炴垶鎸哥粔鐢稿垂濮樿京鍗氶悗锝冨妷閸?*
   *
   * 闂?闂佸搫鐗滈崜姘攦閳?SDK 闂佸憡顭囬崰鎰板几閸愵喗鏅柛褍澧昫k\default\openharmony\ets\component\common.d.ts:25284`闂?
   *    `position(value: Position | Edges | LocalizedEdges)`闂佹寧绋戦¨鈧紒?
   *    闂?*Sets the absolute position of the component relative to the position of the
   *    parent component.**闂侀潧妫楃粔顕€鍩€椤掍焦鐓涢柍?闁诲繐绻楁ご绋课?*闂佺儵鏅濋…鍫ヮ敋椤曗偓閹儵宕滄担铏圭厑婵炲濮惧▔娑欑▕韫囨梻鈻斿┑鐘叉媼濞硷繝鏌ｉ妸銉ヮ伀缂侇噣顥撻埀顒傛暩閹虫捇鎮鹃悙顒佸?*闂佹寧绋戞總鏃傜箔瀹€鍕殜妞ゅ繐妫楁慨褍霉閿濆懐肖闁?`alignContent` 闂佸搫鍟版慨鎾矗瑜旀俊?
   *
   * 闂?缂傚倷鐒﹂幑渚€顢欓幋锔芥櫖闁割偆鍠愰幏閬嶆煛閸屾碍鐭楁繛鍡愬灲楠炲秹鍩€椤掑嫬瀚夊璺侯儓閻т線鎮橀悙鎻掆偓鍧楀礂濮椻偓楠炴劖寰勬惔锝囶啇闂佸搫顦埀顒€鍟块弲鎼佹煥濞戞﹩妾х紒?
   *    闂佸憡鐟禍锝夈€呴敃鈧湁妞ゆ棁鍋愬﹢鎾煙绾版ê浜鹃梺闈╄礋閸斿矂顢欓幇鏉块棷?*閻庡綊娼荤紓姘辩箔閸屾粍鍠嗛柟鐑樺灦閻ㄦ垿鏌￠崟闈涚仯闁绘稏鍎靛畷锝夋晲閸涱厽鏋鹃梺?*闂佹寧绋戦悾鐠搇ayerExpandState` 婵炲瓨鍤庨崐鏇㈠吹椤撱垺鍎?*缂備焦鍔栭〃鍛般亹濞戙垹閿ら柟閭﹀幘閸?*
   *    闁诲繐绻楃划楣冨礂濮椻偓閹嫮鈧稒锚婢跺秶鎲?`.position({x, y})` 闂佹眹鍩勯悡澶屾?*闂佺绻堥崝鎴﹀箺婵傚憡鈷栭柤鎼佹涧鎼村﹦绱?*闂?
   *    `MorphCoverBridge`闂佹寧绋戦悧鍡涘箖閹惧鈻旈柍褜鍓涙禒锕傚磼閿斿墽顦梺鍦焾椤﹂亶鎮伴妷鈺佺煑闁挎繂鎳忕紞蹇涙煛瀹ュ懏绌块柟顖樺€栭幏鍛吋閸涱厼娈ラ柣鐐村嚬閸嬪棗锕㈤敓鐘插珘婵炲樊浜炲畷锝夋偣閸ワ妇绛忕紒杈╂禇LyricFloatLayer` 闂佸憡鑹鹃懟顖炴儑娴兼潙瑙﹂悘鐐舵缂嶆挾鈧灚婢樼€氥劑鍩€?
   *
   * 闂佺粯绮嶆竟鍡樻叏閹间焦鏅繛? 闂佹眹鍔岀€氼參鎮洪弴鐘冲珰鐎广儱顦埀顒€顦湁妞ゆ棁鍋愬﹢鎾煟閵忕姴缍佺紒妤€鎳樺Λ鍐閵忥紕鏆?{@link LyricFloatLayer} 闂佺懓鐏氱€笛勫垔閹绢喗鏅?
   * 闁哄鏅滈悷銈囨偖鏉堛劎鈻?`morphWindow*Vp()` 闂佸搫瀚烽崹鍗灻洪崸妤€绫嶉柍鍝勬噹娴滄繈鏌ｅΔ鈧悧鐐垫濞嗗浚鍟呴柟缁樺笒閻忊晠鏌ㄥ☉妯欏槜yricCoverOverlay` 闂佹眹鍔岀€氱増绂掗幇鐗堝仼婵炲棗绻愮徊鍧楁煕婵犲嫬甯舵繛鍛浮閺佸秶浠﹂懖鈺冾啍闂佷紮绲鹃悷銈囩箔婢舵劕绀夐柕濠忕岛閸?
   */
  /** @returns 濠电偞鎯岄崰鏍儑娴兼潙鐭楅柛灞剧妇閸嬫捇宕橀鍛闂佹眹鍔岀€氼噣鎮伴妷鈺佺煑闁挎繂鎷嬮崯宥夊箹鏉堟崘顓虹紒杈ㄧ崼p闂佹寧绋戦ˇ顓㈠焵?*/
  private morphWindowWidthVp(): number {
    return this.expandState.windowWidthVp;
  }

  /** @returns 濠电偞鎯岄崰鏍儑娴兼潙鐭楅柛灞剧妇閸嬫捇宕橀鍛闂佹眹鍔岀€氼噣鎮伴妷鈺佺煑闁挎繂顦辫ぐ顖炲箹鏉堟崘顓虹紒杈ㄧ崼p闂佹寧绋戦ˇ顓㈠焵?*/
  private morphWindowHeightVp(): number {
    return this.expandState.windowHeightVp;
  }

  /** 闂佽　鍋撻柟顖滃瀹曟娊寮堕埡鍌溾槈閻?0..100闂?*0 = 闁诲海鎳撻張顒勫汲閿濆绠绘い鎾跺枑閺夌懓顪冮妶鍥舵殰缂佽鲸鐟╁Λ鍐ㄢ枎閹伴潧澹橀梺璇″厸缁躲倗妲?*闂?00 = 闂佽　鍋撻柟顖滃瀹曟娊鏌熺€涙ê濮岄柛鎺撶⊕閹棃寮撮悩宕囨殸婵炴垶鎸撮崑鎾绘煛婢规粍澹嬮崑?*/
  @Local collapseProgress: number = 0;

  /**
   * 闂佺绻愯ぐ澶愭閳哄懏鍎嶉柛鏇ㄥ亞濞兼梻鈧鍠掗崑?閻熸粏鍩囬崹纭呫亹婢舵劕绀勯柣妯夸含缁夊潡鏌ㄥ☉妯煎缂佹鏈粩鐔煎礃閼碱剚鍕鹃梺闈涙濞村洨鍖栭悩铏闁绘娅曢拏瀣煏閸℃洜顦﹂柕鍥ф川娴滃憡绗熼埀顒€顭囨导鏉戠閺夊牃鏅滈弳蹇涙煕濮橆剙顨欑紒鏂跨摠缁嬪顢旈崟顓熸緰婵炴挻鑹鹃鎴犳濮樿泛违?
   *
   * 闂備焦褰冮惌鍌氼焽娴煎瓨鍎?`morph` 闁诲骸婀遍幊鎾斥枍閹烘柡鍋撳☉娆樻畷妞ゆ柨鐭傞弫宥夊锤閻х浛le / translate / clipHeight / radius闂佹寧绋戦ˇ顖氼潩閵娾晛鍙?
   * 闂佸搫鍟版慨鐑藉疾?`ExpandAnimation` 闂備緡鍙忕徊浠嬨€?闂佽桨鐒﹂幐鎶藉Υ婢跺瞼纾介柍鍝勫€归弶?+ 缂備焦姊归悧婊兠虹捄銊﹀晳濞达絿顭堥ˉ鍛磼閹邦収娈旂憸?闂佹眹鍔岀€氼喗鎱ㄩ幖浣哥畱濞撴艾锕﹂獮?
   * 婵犮垻鎳撻崯鍧楁儑娴兼潙鎹堕柕濞垮妿椤庘偓闂佸綊娼ч鍡楊渻閸岀偛缁╅柣鐔稿閺嗗﹪鏌ㄥ☉妯绘拱婵犫偓閻楀牄浜滈柣銏犵仛缁绢垶鏌熼幁鎺戝姤妞ゆ洑鍗冲鍫曞Ψ閿曚緡娲梺鍝勬湰閹稿爼鍩€?
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * 闁荤姾娅ｉ崰鎰櫠濠婂嫮鈻斿┑鐘插暙椤庢瑩鏌￠崘顓炵厫濠碘剝鎮傚畷妤呭矗濮椻偓閻撯晠寮堕埡鍌溾槈閻庤濞婂鐟邦煥閸愩劌澹栭柡澶嗘櫆缁嬫帒顭囬悽绋课?
   *
   * 婵犮垻鎳撻崯鍧楁儑娴煎瓨鏅柛褜婀紀ducts闂佹寧绋戦ˇ顖氾耿椤忓懏浜ら柧姘€荤粙鎴︽煛婢跺棌鍋撻懠顒傛啰闂佺顑嗛惌顔剧箔閸岀偛绠璺侯儏椤や線鏌涢弮鍥烽獜闁逞屽厸閻掞箓寮?`expandState.morph`闂?
   * 闁哄鏅滈悷鈺呭闯閻戣棄鐭楁い蹇撴川椤︿即鎮归幇鍓佸埌婵犫偓?*闂傚倸鐗忛崑娑㈩敊閹版澘闂柕濞垮劥閸╁矂鏌?*闂佹眹鍔岀€氼垶鍩€椤戞寧绁伴柣顓熷劤椤曘儵宕熼崜浣侯槱闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佹寧绋戦ˇ顔剧箔閸涱喚鈹嶆繝闈涙搐閻?`collapseProgress` 闂佸憡鑹鹃張顒勵敆閻愬搫违?
   */
  @Monitor('expandState.transitionProgress')
  onTransitionProgressChanged(): void {
    if (this.expandState.morphContainerActive()) {
      // 闁诲骸婀遍幊鎾斥枍閹烘洏浜归柕蹇曞Т缂嶄線姊洪銊хɑ婵炵⒈鍨抽幑鍕敍濞嗘垹鎲归梺?collapseProgress闂佹寧绋戦悧鎾绘偟椤旇姤鍎熼柨鏃€鍨濋懜?100%闂佹寧绋戦惌渚€锝?sheetHeightPercent闂?
      return;
    }
    this.collapseProgress = this.expandState.transitionProgress;
  }

  /**
   * 婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹曟娊鏌熼棃娑卞剰濠电偛绉归弫宥夊醇閵忋垹寤洪梺鐑╂櫅閻°劑寮婚悢鐓庤Е闁规惌鍨崇粈鍡涙煏?
   *
   * 闂佸疇娉曟刊瀵哥箔?`distance` 闂?*闂佸搫鍟版慨鐑藉疾椤愩倐鍋撻棃娑氱Ш缂傚秴鐗撳畷?*闂佹寧绋戦悧鎰帮綖?{@link PlaybackPage.DISMISS_PAN_DISTANCE_VP} 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煥?
   *    婵炴垶鎸哥粔鎾疮閹惧灈鍋撻悷鏉挎殲婵＄偛鍊搁々濂稿幢濡棿妗撴慨鎺撶⊕椤牓顢?**5vp**闂佹寧绋戦惌鍌炲磻閸涱喚鈻旈柍褜鍓欓々濂告晲閸曨厾鐛ラ柣?1~2vp 闂佹眹鍔岀€氼厽鎱ㄩ崼銉ョ闁靛鍔庡Σ鏇㈡煕閹烘繂浜濋柛?閻庢鍠掗崑鎾斥攽椤旂⒈鍎庣紒妤€鎳橀獮?闂?
   */
  private panOption: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Vertical,
    distance: PlaybackPage.DISMISS_PAN_DISTANCE_VP
  });

  // 闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸?闁诲繐绻嬬欢姘焽娴兼潙违鐎光偓閳ь剟鎮界紒姗嗘Ч闁绘劖褰冮悡鍌涙叏濠靛棛鐒烽柣锔界箖閵囧嫰鎮欓崗澶婁壕鐎广儱绻掔粈鍕倵娴ｅ喚娼愰柣?闂佸搫鍟版慨鐑藉疾椤愶附顥婇柛蹇撴噽椤?CoverMorph 闂佸憡鐟ラ惉濂割敂椤掑嫭鍊烽柣褍鎽滅粈鍡涙煃閻戞ê濮€闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸闁硅埇鍔嶅▍婊堟煃閻戞ê濮€闁哄懏鐓￠崺?

  /**
   * 闁诲繐绻嬬欢姘焽閹殿喚纾兼い鎾卞焺濡囧级閳哄倻鈽夐悗瑙勫▕閺? = 闂佺顑嗙划灞斤耿椤忓棔娌柡鍥╁仧绾捐顪冮妶鍛倎缂傚秴鎳愮槐鏃堫敋閸℃瑧顦? = 閻庣懓鎲¤ぐ鍐春鐏炵瓔娼扮€光偓閸愵亝袚婵＄偑鍊曢崥鈧紓宥呮噽缁辨棃顢欑悰鈥充壕?
   *
   * 闂傚倸鐗婇悷锕傤敆濞戙垹鎹堕柕濠忛檮鐏忥繝鏌￠埀顒併偅閸愶腹鍋撴径鎰睄闁肩鐏氱瑧 0闂?*婵炴垶鎸哥粔鍫曞极閻愵剦妲归柣鎰邦杺閺€浠嬫倶韫囧海绐旀繛?*闂佹寧绋戞總鏃傜箔鐏炶В鏌﹂柍鈺佸暞缁犳帡寮堕埡鍌滄噧妞ゃ劍绮撳畷婵嬪Ω瑜庨弳浼存煛閸愩劎鍩ｉ柍褜鍓氶崝鏇㈠磿濮樿鲸顫曢柣妯夸含椤忛亶鏌ら悿顖涘涧缂佽鲸宀搁弫?
   * 闂佸憡鐟禍婵嗭耿娓氣偓瀹曟岸宕惰閻撳倹鎱ㄥ┑鍡欑劮闁伙附绻冮妵?闂佸憡甯掑ú銈吤洪弽顐＄剨濞撴埃鍋撴繛鑲╁閵囧嫰鎮介崹顐ゆ殸闂?360ms 闂備焦褰冮張顒佹櫠?0闂? 闁哄鏅涘ú锕€霉椤曗偓婵?
   */
  @Local lyricMorphT: number = 0;
  /** 婵＄偛顑囬崑鐘汇€侀幋鐘辩剨濞撴埃鍋撴繛闂村嵆瀵即顢涘顓炲墾闂佸憡鐟崹鐢革綖閸℃稒鏅柛顐犲劜妤楊垱鎱ㄥ┑鍕仾闁逞屽厸濡炴帞绮╅弶鎴殫?false闂佹寧绋戞總鏃傛崲濮樿鲸瀚氬ù锝夘棑閻熸繄鎲搁弶鍨埞闁硅偐鍏樺Λ鍐ㄢ枎閹般劌浜惧ù锝呮憸椤忔挳鎮橀悙鈺佷壕闂佹寧绋戦ˇ顓㈠焵?*/
  @Local lyricMorphVisible: boolean = false;
  @Local lyricMorphOpacity: number = 1;
  private lyricMorphGen: number = 0;
  private lyricMorphTarget: boolean = false;
  private lyricSwiperSettled: boolean = false;
  private lyricFlightSettled: boolean = false;
  @Local lyricChromeProgress: number = 1;
  @Local lyricChromeHeight: number = 0;
  @Local lyricChromeMeasurePending: boolean = true;
  private lyricChromeWidth: number = 0;

  // 闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸?闂佺鐭囬崘銊у幀闂佸憡鐗楀钘夘焽閵堝拋娼伴柕蹇ョ到濞堜即鏌涢弬璇插闁轰礁婀遍幐褔宕欓妶鍥╊槱闁诲簼绲婚～澶愭偉?闂佸搫鍟版慨鐑藉疾椤愶附顥婇柛蹇撴噽椤?BarCollapse闂佹寧绋戦ˇ顐﹀疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸闁硅埇鍔嶅▍?

  /** 闂佺鐭囬崘銊у幀闂佸憡鐗滈崕銈呂ｉ幖浣歌Е闁挎洍鍋撻柛鎴節閹虫盯顢旈崟顐嶆鏌￠埀顒勫箚閻楀牆闂梺鎸庣☉閻楀﹪寮崷顓熷皫鐎瑰嫮澧楅崐鐢告煟閹版壋鍋撳☉娆忓簥闂佽婢樼换鎰八囬埡鍛埞闁靛牆鎳庡В澶愭煥濞戞﹩妲堕柍?*/
  @Local chromeCollapsed: boolean = false;
  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`PlayerPage.hideChrome()` 闂?闂傚倸鐗勯崹鍝勵熆濡警鍤曢柍褜鍓熼幆鍫ュ焵椤掑倷鐒婇柛娆愵焽閻熸繈鏌￠埀?闁诲海鎳撻悧鍡楃暦婵傚憡鏅鑸电〒缁?
   * **闂佸湱铏庨崢浠嬪棘娓氣偓濮婂ジ鎮㈠畡鎵粴 / 闂佺绻戝﹢鍦垝椤掑嫭鍋嬮柛顐ゅ枑閹?*闁哄鏅滈悷銈囨偖鏉堛劎鈻旀い蹇撳閸撱劑鎮橀悙鎻掆偓鐟拔ｉ幖浣歌Е闁挎洍鍋撶紒杈ㄥ灴閹牓鍩€椤掑嫭鏅柛顐犲灪閺?`ControlAreaComponent.onAuxSheetOpenChange` 婵炴垶鎸搁敃銉︽叏閵堝鏅璺虹墐閸?
   *
   * 闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗椤忛亶鏌℃径鍡忓亾瀹曞洦娈﹂梺鍛婎殢閸嬪懎危?10 婵?flag 闂佹眹鍔岀€氼噣鎮￠鐘冲磯妞ゆ牗绋戦悘妤呮⒑閻愵剚瀚曠紒杈ㄧ崑abc.txt:4124-4225`闂佹寧绋戦¨鈧紒?
   * 闂佸搫鐗滈崗娑氬垝閵娾晜鍤曟繝濠傚暙缁€?sheet 闂備緡鍙忕徊鑲╃博閹绢喖绫嶉煫鍥ュ劤缁€鍒瀞ettingsOpen`/`qualityOpen`/闂佺偨鍎荤拋锝囨濮樿埖濯伴柦妯侯槹闊?*婵炴垶鎸撮崑鎾斥槈?* `bindSheet` 闂備焦褰冮惌澶屾?
   * 閻庤鐡曠亸娆撳极?`playMenuOpen` 婵炲濯寸紞鈧柕鍡楀暣閺佸秴鈽夊Ο琛℃寘婵炴垶鎸搁鍫㈡崲閺嶃劎鈻旈柕鍫濆閸ゅ鏌ｉ姀锝夊摵婵犫偓閹殿喒鍋撳☉娆樻畷妞ゆ柨鏈粋鎺楁晲閸稈鍋?闂?婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲酣骞冩惔锝嗗皫闂佸灝顑嗛梽?= "婵炲濮鹃濠勭礊瀹ュ顥堥柕蹇婂墲缁惰尙鈧鍠掗崑鎾绘煟椤愮喎浜?闂?
   * 闂佸疇娉曟刊瀵哥箔?婵?`playMenuOpen` **闂婎偄娲ら幊姗€濡磋箛鏃傗枖闁逞屽墰閹?*濡ょ姷鍋為崕鑲╂崲濮椻偓瀵劑骞嗛悧鍫濋棷闂傚倸鍋嗛悡澶屾濞嗘挸瑙﹂悘鐐跺亹椤忛亶鏌℃径鍡忓亾瀹曞洦娈﹂梺鍛婎殢閸嬪棗鈻撻幋鐐碘枖闁靛牆瀚伴崵瀣煕閹烘垶顥㈤柛锝嗘そ閺佸秶浠﹂懖鈺冩喒闁荤姳鑳堕…鍫ｃ亹瑜斿畷姘跺Χ閸曨収浼囨繛鎴炴惄娴滈妲愬璺何?
   */
  @Local auxSheetOpen: boolean = false;
  /**
   * 闂?2026-10-17闂佹寧绋掗悺鐙筼rphGuard` 闁诲海鎳撻ˇ闈涱焽閵堝洨鐜绘俊銈傚亾鐟滅増鐩幆?闂備焦褰冪粔鐑芥儊椤栫偛鐭楁い蹇撴噹缁楁挸鈽夐幘顖氫壕闂?濡ょ姷鍋涢崐濠氭偤閹达箑鍐€闁搞儺浜堕崬?
   * 闂佹寧绋戦悧鍡涱敋椤曗偓瀵粙宕堕妸锔奸獜闂?`MainPage.colorModeRetryQueued`闂佹寧绋戦悾鐡€ujie.pa:145966/145979`闂佹寧绋掗惄顖炲闯閸濄儲瀚?濞?闂備焦褰冮懟顖炈囬崣澶嬪鐎广儱绻掔粈鍡涙煏?
   */
  private colorRetryQueued: boolean = false;
  /**
   * 闂?2026-10-17闂佹寧绋掗懝楣冩偩閵娾晜顥堟繛鍡樺灩瀹曞爼鏌涘▎娆戠ɑ婵犫偓閿熺姵鈷?*閻庡灚婢橀幊鎾规＂**闂佹眹鍔岀€氼喚绱炴径鎰唨闁艰婢橀崜褰掓煛閸滀礁鐏＄紒顭戝櫍閺佸秹宕奸姀銏犵倞闂佸憡鐟辩紞鈧紒璇插暣瀹曘垻鎷犻崣澶娾偓鐢告煟?
   * {@link republishMeshSourceIfAny} 闂佸湱绮崝鎺戭潩閿曞倹鏅璺虹墐閸嬫捇宕掑☉姗嗘殹闂佸搫鐗嗛ˇ鏉款焽閸儱鎹堕柕濠忛檮閹峰崬顪冮妶鍥舵殰缂佽鲸绻堝鎾箰鎼粹€崇哎闂佸搫鍟悥濂稿闯閹绢喖缁╅柣鎰靛墯閿涘鏌ｉ妸銉ヮ仴闁?
   */
  private pendingMeshPm: image.PixelMap | undefined = undefined;
  /** 闂佺厧顨庢禍婊勬叏閳哄懎缁╅柟顖滃瀹曟娊鎮规担鎻掑⒉婵＄偛鍊垮畷鎶藉Ω閿濆倸浜?*/
  private chromeTimerId: number = -1;
  /** 闂佸搫鐗冮崑鎾绘煕濮橆剛鍑圭紒鏃€娼欓埢搴ㄥ焺閸愩劋绮梺鍛婂笩濞夋稓浜搁娑氼洸闁靛牆瀚棄宥夋煛閸愩劎鍩ｆ俊顐㈡健閺佸秹宕搁。娆撴煥濞戞﹩妲堕柍?*/
  private chromeTouchedAtMs: number = 0;

  // 闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸?闁诲繒鍋炲ú鏍閹达箑绫嶉柛鎾茬劍閻ｉ亶姊洪锝呭闁告ɑ鎸惧Σ鎰版偐鐎圭姷鐛ラ梺绋跨箞閸庤崵妲愬▎鎾村殜妞ゅ繐鎳庨惁顕€寮堕埡鍌溾槈閻庤濞婇弫宥囦沪閼测晝鎲规繝銏ｆ硾缁夊爼寮妶澶婄闁告瑦锕㈤悡鈺呮煟閳哄懏娅滅紓宥呮嚇閺佸秵寰勯崱妯荤彸闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮?

  /**
   * 闁诲繒鍋炲ú鏍閹寸姵鍋橀柕澶嗘櫆閿涚喖鏌￠崟闈涚仩闁诡垯绶氬畷鐑藉Ω閵娧呭礈闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷锕€危?*闂佸搫鐗滈崜娆忥耿?*闂佸搫绉村ú銈囨崲閺冨牊鏅悘鐐跺亹閻燁剟鏌涘▎妯圭敖闁轰降鍊濆鍫曞Ψ閵夈儲鐎柣?闁荤喐娲戝鎺旂箔婢跺本鍟哄ù锝囧劋閺嗗繘鏌涢弬璇插闁轰線绠栧畷?闂佹寧绋掔粙鎴ｃ亹瑜忛幉鐗堟媴閸濄儲娈滈梺?false闂?
   * 闂佸湱顣介崑鎾绘煛閸繍妲归悹鎰嵆瀹曟濡烽妷銉ф偧闂佺锕Λ璺ㄧ博閺夋埈鍤楅悗锝庡幘缁犳煡鏌涢妷褍浠辨繛绗哄€曢～銏ゅ閳锯偓閸嬫挻绗熸繝鍕槱1 / 0闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婄晫鎹㈤弽顓炲唨闁炬艾鍊婚悷婵嬫倵濞戞顏勶耿?闂佸搫绉村ú銈囨崲閺傚簱鏋旈悗锝庡墯濞堝矂鎮楁担鍐棈闁搞伇鍥х闁告侗鍙庨崯鍥⒑椤愩垻绠叉俊?闂佹眹鍔岀€氼剝銇愰弻銉﹀殑?
   * 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯ｉ幖浣稿嵆闁告挆鍛⒕闂佹眹鍔岀€氼喖锕㈤敍鍕ㄥ亾?bug闂佹寧绋戦悧蹇涘极閵堝绠ｉ柛鎴欏€楃粣妤呮倶韫囧海绐旀繛鍏兼緲鑿愰柍鈺佸暢缁愭鏌涢幋锝嗩仩妤犵偛娲畷銉︽償閵忊剝顔掓俊鐐€楅弫鎼佸煘閺嶎厽鍎岄柡鍌樺€楃粈鍡涙煏?
   //  閻熸粏鍩囬崹纭呫亹婢跺浜ゆ繛鎴灻濠傗槈閹惧磭孝鐟滄壆鍠撻埀顒佺⊕閿氱憸鏉款樀閺屽矁绠涢妷褏鐛ラ梺鐑╂櫅閻°劎鏁€涙ê绶炵€广儱娲﹂弳?`collapseProgress`闂佹寧绋戦悧鎰帮綖?`morphProgress()`闂佹寧绋戦¨鈧紒?
   //  闂備緡鍓欓悘婵嬪储?婵°倕鍊归敋閻庤濞婂畷姘紣娴ｅ搫鏅╂繛杈剧到濡稓绱撴径鎰哗闁绘劦鍓涘楣冩煕?闂佹眹鍔岀€氼亞鎮潏銊ч檮婵°倕瀚烽崥鈧梺鍝勫暙閻栧ジ寮繝鍐╁鐎广儱鍟犻崑?
   */
  @Local expandIntroRunning: boolean = false;
  /**
   * ★ 2026-10-18（第六轮）：展开过程中收到"关闭"请求 ⇒ **只记标记、不动画**，
   * 等打开收尾（`morphSettleOpen()`）之后再走正常快照关闭。
   * 原因：壳层另有一条 560ms 的打开收尾会 `applyMorphProgress(1)`，
   * 与"活体反向"抢同一个 `morphP` ⇒ 表现为"返回动画消失 → 突然完整 → 又消失"（用户实测"会闪"）。
   */
  private closeAfterOpen: boolean = false;
  /** "快照已进手"（快照回调里置真）⇒ 真封面让位，避免"快照一颗 + 真封面一颗"。 */
  @Local snapshotFlight: boolean = false;
  /** "展开中收到关闭"排的那个闹钟句柄（-1 = 没排；见 `onCollapseRequested`）。 */
  private closeAfterOpenTimer: number = -1;

  /** Seeds cover Resource from the current queue item. */
  aboutToAppear(): void {
    PlaybackPage.cancelPendingCloseForOpen();
    this.closeInstance = ++PlaybackPage.instanceSerial;
    // 闂佺绻愰悧鎰邦敊閸ャ劎鈻旈柍褜鍓熷?闁哄鏅滈悷銈囩博鐎涙ǜ浜滈柛顭戝亜閻︻垶寮堕悙璺盒撴俊鐐插€婚幐褔骞嶉鐣屾殸闂佸搫瀚烽崹浼村箺閵忋倕绾ч梽鍥儗?闂佹寧绋掑銊╁磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸?vs 婵炴垶鎸搁敃銉﹀垔濞差亜绠ラ柟鎯х－绾惧鏌ｉ妸銉ヮ仼閻忓浚鍨跺畷姘额敃閵忥紕娈ら梺?`pullDragging`闂?
    // 闂佸湱鍎ょ敮妤呮偂?闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闁哄鏅滆摫婵″弶鎮傚顔款槻濠殿喒鏅犻幃?闂佸搫鍟崕鑲╂崲閺嶃劎鈻旈柍褜鍓涢幃鎵沪閻愵兛绮梺绋跨箲婵炲﹪寮銏℃櫖闁秆冨焻dc shell hilog | grep "expand intro"`闂佹寧绋戦ˇ顓㈠焵?
    Logger.info(PlaybackPage.logTag,
      `aboutToAppear: pullDragging=${this.expandState.pullDragging} ` +
      `usable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*婵烇絽娴傞崰姘跺极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓張顒勬偤閺囩姵瀚氱€广儱顦埀顒€顦辨禍鍛婄瑹閳ь剙顭囬弶搴撴煢闁炽儱鍟跨紞渚€鎮樿箛鎾剁疄闁逞屽厸缁€浣姐亹閺冨牆鎹堕柕濠忓閹藉啴鎮归崶褏小缂佹鍊垮Λ鍐綖椤戣棄浜?*闂佹寧绋戦¨鈧紒?
    //   婵＄偑鍊楅弫璇差焽?*闂佸湱顭堥崐钘壝归崶顒佺劷闁挎繂瀚閬嶆煕?*闁诲繐绻楁ご鍛婁繆?闁诲繐绻嬬欢姘焽閺夋５褰掝敊閼测晜鍕炬俊鐐差儑閸嬬娀銆侀幋鐐翠氦婵炴垶锚椤?闁诲酣娼х紞濠勭礊閸儱绀嗛柡澶庢硶缁夊ジ鏌涢幘宕囆ч柕?闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕€危閹间礁瀚夋い鎺戝閳ь剙顦辩划顓㈩敄鐠侯煈浼囧┑鐐叉閸撴繂锕㈡笟鈧鍨姜閹殿喚鐛ラ梺绋款儐娣囪櫣鎹㈤弽銊ь浄闁哄牏鏁搁惃鎴︽煥?
    //   闂佸吋婢樻總鏃傜箔閺嶎偀鍋撻悷鏉挎殨缂?闂佸搫瀚烽崹浼村箚娓氣偓瀹曪綁骞嬮悩铏闁哄鏅涘ú锝囩博閺夋垟鏋庨柍鈺佸暟閹枫劑鏌?闂佸搫鍟版慨鎾矗瑜旈弫宥夊醇閵忊€斥偓鐐烘煟閵忥絿绨挎い?`syncLyricMorphToPage()` 闂佹眹鍔岀€氫即寮抽崡鐐╂灃闁靛ň鏅涘▍鐐烘煥濞戞﹩妲堕柍?
    //   闂佹椿娼块崝宥夊春濞戙垺鐒介柨婵嗘噽閻愬﹪鏌熼幖顓濈盎婵炲瓨锚椤垽鏁愰崱妯烇箓寮堕埡鍌滄噥闂佸弶绮忛妵鎰板閵忕姌锕傛煥?*swiper 闂侀潻璐熼崝宥夋偤閺囩姵瀚氱€广儱顦埀顒€顦垫俊瀛樼▕椤ょ灤ricMorphT` 闁哄鏅滆摫婵?0** 闂?婵犮垹鐖㈤崘顏咁唸闂?+ 濠殿喗绻傞惌渚€鎯佸┑瀣Е閻忕偟鍋撻ˇ褔鏌涢敂鍝勫婵犙€鍋撻梺?
    //   闂佸疇娉曟刊瀵哥箔?闂佽　鍋撻柟顖嗗嫯鍚?`aboutToAppear`闂佹寧绋戝鍍紃uct 缂備胶瀚忔担鎻掍壕濞达絿鎳撻惁顖炲级閻愯埖顥夌€规挸妫濆鍨緞濞戞氨顦梺鍏兼緲婵傛梻绮径鎰煑妞ゅ繐瀚煬顒勬煕閹邦剚鍣规い鏃€鍔楁禒?`.onAppear`闂佹寧绋戦悧鎰繆椤撱垺鍊烽柛锔诲弮閻涙捇鏌?
    //      闂佸憡甯掑Λ娆撳极椤曗偓閺屽苯顓奸崨顖滃闂佸綊娼х粔椋庣玻閸ヮ剚鏅璺烘閸嬫捇寮悰鈥充壕?婵炴垶鎸堕崐鏇⑺囬埡鍛劸闁稿﹦鍣ュú锝夋煥濞戞瀚版繛鍙夌矋缁嬪娼幏灞告嫛闂佸吋婢橀幊蹇擃渻閸岀偛瀚夐弶鐐村閻熸繈鏌涘顒傜効缂佽鲸鐟╁畷婊冾吋閸艾浜鹃柛娑卞枟閿涘秴霉濠婂啴鍙勬い鈺勫吹閺侇喛顦茬紒鏃堫棑娴狅箓鍩€椤掑嫭鏅悘鐐跺Г閸婄敻鏌ら弶鎸庡櫤婵炲懎瀚粋宥嗘償閵忕姷妲搁柡澶屽仦閺嬭崵妲愬璺何?
    this.syncLyricMorphToPage('boot');
    // 闂?**闂佺厧顨庢禍婵嬪礈?*闂佹寧绋掓穱娲綖?`onDisAppear` 闂備焦褰冮惌鍌炲磻閸涱厸鏋斿ù锝呭枤閸ゆ盯鏌?闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷銈囨偖鏉堛劎鈻旀い蹇撴噽閸ㄥジ鎮规笟鈧。锔剧博閹绢喖绫嶉柨鏃傛櫕閺嗘瑩鏌ｉ敐鍡欐嚂缂佽鲸绻堥幃娆撴偡閺夋寧鐦栭梺鐟扮仛閹稿摜妲愰幋鐘辩剨閺夊牄鍔嶉、宥夊级?
    //   闁荤姴鎼悿鍥╂崲閸愵厹浜归柕蹇曞Т缂嶄線鏌涢幒鎾剁畵妞ゎ偅鍔欏畷鐘诲冀閻㈢數顦梺鍛婄懐娴滄繈骞愰柆宥嗗殌濞达絿顭堣闂佹眹鍨洪惇褰掑焵椤掆偓閸婄晫鎹㈤弽顓熺厒閻忕偠妫勯弲娆撴煕韫囨梻鐭嗙紒鏂款嚟娴狅箓宕掗敂鍓х崶闂佸憡鐟禍婵嗭耿?缂佺虎鍙庨崰鏍偪閸曨垰鎹堕柕濞у嫮鐣介梺褰掓涧椤戝懏绻?闂佹寧绋戝鎭焛ve=FINGER闂?
    //   闂佸綊娼х粔鐑筋敇缂佹鈻旈柣鎴灻·渚€鏌熺粙鎸庢悙婵犫偓椤忓懌浠氶柛妤冨仜琚熼梺鎸庣⊕缁嬫牠鍩€椤掆偓婵傛梻绮弽顓炵闁稿繐鎳庨埢蹇撯攽閳ュ啿鈧綊顢楀┑瀣櫖閻忕偠妫勫☉褔鎮烽弴姘鳖槮闁告埊绱曠槐鎺曠疀濮樿京鐣烘繛?2 缂備礁顦扮敮鐔烘崲閺囩偐鏌﹂柍鈺佸暞閺嗩亪鎮樿箛鏃€瀚曠紒杈ㄧ箘娴滄悂宕ｅΟ纰变紘闁诲氦顫夌喊宥呂ｇ粙搴撴灁閻庯綆鍓氬▓?
    //   闂佹寧绋戦悧鍛博閺夋垟鏋庨梽鍥╃玻閿熺姴绠ラ悗锝傛櫇閻熸繈鏌涘▎妯虹仴闁稿繑锕㈤獮鎰媴閾忚鏆伴梻渚囧弿缁茶偐绮婚悙瀵糕枙闁告粌鍟扮粈鍡涙煥濞戞鐏辨繛鎻掓健楠炴帡濡烽敂缁紩闂佺懓鎼ˇ顓㈠焵?
    const dragAgeMs: number = Date.now() - this.expandState.pullStartedAtMs;
    const dragGenuine: boolean = this.expandState.pullDragging &&
      this.expandState.morphDrive === MorphDrive.FINGER && dragAgeMs >= 0 &&
      dragAgeMs < PlaybackPage.PULL_DRAG_MAX_MS;
    if (this.expandState.pullDragging && !dragGenuine) {
      Logger.warn(PlaybackPage.logTag,
        `aboutToAppear: clearing stale pull session (drive=${this.expandState.morphDrive} age=${dragAgeMs}ms)`);
      this.expandState.pullDragging = false;
      this.expandState.morphDrive = MorphDrive.NONE;
    }
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘极閵堝绠ｉ柛鎴欏€楃粣?*闂侀潧妫楅張顒勫垂濠婂嫮顩锋い鎺戝€归悾閬嶅级閻戝棗鐏熸繛鍡愬灲閺屽苯鐣濋崟顒併€冮梺鍝勭墕椤︻噣鏌屽鍫熷殜妞ゅ繐瀚弳鏉库槈閺傛妲搁柣銊︾箞濡啴濮€閻樺啿顩柣鐔哥懄鐢﹦寮ч崘顔肩闁绘浜崯濠囨煕濮樷偓娴ｆ彃浜?*闂?
    //   闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡楁捣椤忛亶鏌涘▎宥呭姕婵?`= MusicStoreService.getInstance().getCoverCornerRadius()`
    //   闂佺偨鍎查弻锟犲焵?闁荤姳绀佹晶浠嬫偪閸℃ǜ浜滈柣銏㈩焾娴滄繂鈽夐幙鍐х暗闁逞屽墮閼活垶鎯冨┑瀣棃闁靛繒濮垫俊鍥偡濞嗘劕閲滅紒杈ㄧ懇閹嫮澹曠€ｅ灚鍋?闁?婵?婵?闁烩剝甯掗幊搴ㄥΦ閸ヮ剚鏅璺虹墐閸嬫挸顓兼径鍡椾壕婵ê纾粻鏍倵閻熸澘鏆㈢紒缁樏妴鎺楀矗婢跺苯甯梺?
    //   闂佺粯绮嶅妯猴耿椤忓牆鎹堕柛鈩冨嚬濞硷繝鏌涘▎妯圭凹婵犫偓?*婵炴垶鎸撮崑鎾斥槈閹垮啩绨兼繛濂告涧閳?*闂佹寧绋掔喊宥呂涢妶澶嬪仼?`CoverMorph.radiusPlayer = 8`
    //   闂佹寧绋戝濉抣ayerExpandState.COVER_RADIUS_PLAYER_VP`闂佹寧绋戦ˇ顐﹀闯?闁荤姳绀佹晶浠嬫偪閸℃稑纾归梻鍌氼嚟閻熸繈鏌涢幇顒傂㈢€殿噮鍓氱粙澶嬫償濠靛洤搴婃繛杈剧稻濞叉鎲伴崱娑樿摕闁圭偓澧庨崑?
    //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈囩博閹绢喖鐭楅柕澶堝劤缁犳垵顪冮妶鍫濆惞闁哄棌鍋撻梺娲诲亐閸嬫捇鏌ㄥ☉妯煎濠碘剝鎮傚畷妤呭矗濮椻偓閻撯晠鏌ｅΟ鍨厫闁逞屽厸缁€浣烘暜閸ヮ剙鐐婇柣鎰级閸娿倖绻涙径瀣闁逞屽墰閵嗗妲愬鑸垫櫖婵繃顑巓verRadiusState` 闂備焦褰冮懟顖濄亹閺屻儲鍤勯柤鎭掑劤閺嗘瑩鏌ｉ敐鍡欐噭婵☆偒鍋婂畷鎰箔鐞涒€充壕?
    this.coverRadiusState.radius = PlayerExpandState.COVER_RADIUS_PLAYER_VP;
    // 闂?濠电偟绻濈粈渚€宕㈠鍫熷殑閻忕偟鍋撻悵顖溾偓娈垮枓閸嬫捇鏌涜箛鏇ㄥ姕缂?*闂婎偄娲ら幊姗€濡磋箛娑樻嵍闁靛鍔庣粻褰掓⒑閹绘帒顨欑紒顔惧█楠炴劖鎷呮搴ｆ毌闂佸憡鐗楅悧鏇㈡偤閵娾晛纾奸柕濞у倹宕撻柡?V2 闂佺粯顭堥崺鏍焵?*闂?
    // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁?濞戞挸锕ｇ粩瀛橈純閺嶎偅娈屽☉鎾愁儑濞堟垵霉娴ｇ甯ㄩ柣顐熷亾闁?閻熸瑥妫旂拹鐔奉啅閸欏啸闁?* 闁炽儲鏌￠埀?濞ｅ浂鍠撻埀顒€鑻惈宥咁嚕閳ь剚娼诲Ο缁樞﹀☉鎾筹梗缁斿瓨锛冮弽顐ｇ暠濡増绮忔竟濠囧Υ瀹ュ繒绀?
    //   `coverTint` 闁?`AppStorageV2` 闁稿繐褰夐棅鈺呮偐閼哥鍋撴笟濠勭獥闁圭鍊藉ù鍥焽閿濆嫮顏遍柛鎺曨嚙閻ｇ娀鎯?`version` 鐎规瓕灏欑划锟犲及?*濞戞挸锕ｇ粩瀛橈純?*闁伙絾鐟ょ粭鍛存儍閸曗斁鍋?
    //   闁兼澘鏈﹢鐗堛亜?`appliedTintVersion` 闁告帗绻傞埀顒€鍚嬪Σ?-1 闁?`@Monitor('coverTint.version')` 濞戞挴鍋撳☉鎾筹攻濞肩數浜搁崡鐐村殥濞?
    //   闁?`applyCoverTint()` 闁?*濞戞挸锕ｇ粩瀛橈純?*闁汇劌瀚伴·渚€鎳濋煫顓犵憮闁告瑦鍨圭划浼存儓閳ь剟鎳濋幓鎺撶彜闁靛棔绀侀懟鐔煎箮?`tintReady` 缂傚喚鍠氬﹢?
    //   闁?闂侇叏缍佹禍?缂佹稑顦紞瀣礈瀹ュ牏绠瑰Λ锝嗙墱濞堟垶锛愬鍡楊棌"闁汇劌瀚板Λ顒冦亹閹捐櫕绨氶悶姘煎亞缁偅娼婚崶椋庣濞戞挸锕ｇ粩鎾偋閸繃鐨戦悹鎰╁劚濠€顏呮交濞嗘挸娅￠柨娑橆槶閳?
    //   闁?闁圭鍊藉ù鍥籍?*闁稿繐鐗嗛顔筋瀲?*闁挎稒纰嶆俊姝屻亹閹惧啿顤?version 閻犱胶澧楅崹?鐎圭寮剁粔鐑藉礌?闁挎稑鐣璽intReady` 濞ｅ洦绻冪€垫棃宕戦崶椋庡耿
    //     闁归潧绉崇槐浼存儑閻斿壊鍔€濞戞挸顑呰ぐ鍌炵嵁閼稿灚鏉归悶娑樼焸閸嬪懏绋夐埀顒備沪閸屾ǚ鍋?
    this.appliedTintVersion = this.coverTint.version;
    this.tintReady = false;
    Logger.info('RzdPlaybackMeshOnly', 'background=mesh fixed=1');
    const song = this.state.getCurrentSongItem();
    this.releaseBackgroundCoverIfPixelMap();
    this.imageLabel = song !== undefined ? song.label : $r('app.media.ic_avatar1');
    this.applyKeepScreenOn(true);
    // 婵＄偑鍊楅弫璇差焽娴兼潙绠ラ柟鎯х－绾惧鏌￠崘顓熺【妞も敪鍥у嚑婵犲﹤鍟崵鎺楁煛閸繍妲规繝鈧鐔镐氦闁搞儯鍔嶉崺鍌炴煟閵娿儱顏柧鍡橆殽閻愬弶瀚呯紒杈ㄧ箘缁晝鈧綆浜滅粊顕€鎮峰▎娆戠暠鐟滄澘鍊搁妴鎺楀川椤栨稑鈧偤鎮规担鎻掑⒉婵＄偛鍊挎俊?
    if (this.switchBanner.ts > 0) {
      this.onBannerChange();
    }
    // 闂?闁诲繒鍋炲ú鏍閹达箑绀夐柕濞у嫭姣庨梺鎸庣⊕閼归箖宕㈠☉銏犳嵍?`aboutToAppear` 闂佺娉涢敃銊ф崲濡粯鍎熼柨鏃囧Г閺夊綊鏌?闂佽　鍋撻柟顖滃瀹?闂?*婵烇絽娲︾换鍡涙儊婢跺瞼绠旀い鎴ｆ硶椤忛亶鎮介鍡楁噺閺嗕即鏌涢幋鐘插妺婵炶偐鏁告禍鍛婃綇閵娤€锕傛偣閹邦厽缍戠紒銊﹀▕閹啴宕熼鍡╀紘闂?*闂?
    //   婵犵鈧啿鈧綊鎮樻径鎰哗闁诡垎鍐帓 `onAppear` 闂佸憡鍔曠粔鍫曟偪閸℃稒鏅悘鐐跺亹缁愭鏌涜箛鎾跺閻熸洖妫濆濠氬箻閸愬弶鐦旀繛鎴炴尨閸嬫捇鎮介鍡楀暟閺嗘岸鏌℃担鍝ユ憼闁规悂浜跺銊︺偅閸愶腹鍋撴径鎰鐎广儱妫欓弳顏堟煕閵壯冧粶妤犵偞鎹囬弫宥呯暆閳ь剙锕㈤崨瀛樺創闁逞屽墰娴滃憡娼忛妸蟺锕傛⒒閸屻倓绨风紒鏂跨摠缁嬪鈧絻鍔夐崑?
    //
    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*婵犮垻鎳撻崯鍧楁儑閺夋鍟呴柤纰卞墰閻ュ懘鎮硅濞撳湱鑺遍檱閵囨劙濮€閻樿尙绉梺鍝勫暢椤旀劗妲愬┑鍥ㄤ氦婵炲棗娴烽杈ㄤ繆濡ゅ瀵肩紒妤€顦遍幏瀣矙閸喗娅冮梺?*闂?
    //   闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亞濞兼梻鈧鍠掗崑?*闂佸憡鐟禍婵嗭耿娴ｅ湱鈻旈柍褜鍓氱粙澶愵敂閸曨倣妤呮煟閵忥綆鍞洪悗?* 闂佺偨鍎查弻锟犲焵?婵犮垻鎳撻崯鍧楁儑娴煎瓨鍎?`ExpandAnimation.doEnter`闂?50ms闂佹寧绋戦ˇ鐢稿煘瀹ュ绀夐柕濠忛檮濞堣顪冮妶鍥ㄦ毄婵?
    //   `scale/translate/clipWidth/clipHeight`闂佹寧绋掔粙鎺楀箰闁秴缁╁Δ锝呭暔閳ь剙顦甸幊娑㈩敂閸曨厾鐣?*濠电偛澶囬崜婵嗭耿?*缂備焦顨忛崗娑氳姳閳哄倻闄?闁荤姵鍔栧娆戣姳閾忣偆鈻旈柍褜鍓熷鍫曟晸閻樿櫕鐦ｆ繛鎴炴尭閿曘儱顭?闂?
    //   闂?`collapseProgress` 闁哄鏅滈悷銉┿€冨鍫熸櫖闁割偅绻傞弫鍫曟倵閸︻厽鍤€闁?`height` 婵炲濮村锕傚礆濞戞瑦鍎熼柡鍥ㄦ皑椤忛亶鏌℃径娑氱瘈闁哄棝浜跺畷?100%闂佹寧绋戦ˇ鏉课?*濠电偞鐓＄粻鏍偂閸洖绫嶇憸鎴︽儗?*闂?
    //   婵炴垶鎸堕崐鏍ь焽椤栫偛瑙﹂悘鐐靛亾椤ρ囨煕閿斿搫濮€缂佹劕娲ㄦ禍鍛婃綇閵娤€锕傛煟椤剙濡介柛鈺傜〒閳ь剙婀遍崑鐐电矈閹绢喗鍎嶉柛鏇楁杹閸嬫挸鐣濋埀顒勫磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸嬫捇鏌熺紒銏犲箺闁哄倷绶氬畷鎶藉Ω閿旂偓鈷曢梺鍝勭墕椤︻垱鎱ㄩ埡鍛仺?/ 闂佺厧鍟块張顒€鈻嶅▎鎰枖鐎广儱鎷嬮崵鐘绘煏閸℃鈻岀紒?
    //   婵＄偑鍊楅弫璇差焽閹殿喗鍋栨い鎰剁稻閿涘鎮规笟顖氱仭閻?闁荤姵鍔栧娆戣姳閾忣偆鈻旈柍褜鍓熷?闁荤姍鍥ㄦ暠濠⒀勭矒閺佸秴鐣濋崘锝呬壕閻忕偛鈧喎鐓傞梺鍛婄懄椤洤鈻撻幋鐘冲皫濡炲楠告禒顖炴煕閹寸姴小缂傚秴绉撮蹇涙嚑椤掑倻姊鹃柣鐐村嚬閸嬪嫰鏁嶉幘鏈垫勃闁稿本绋戦惁濠氬级閳哄嫭鑵圭紓宥嗭耿瀵爼妾遍柛蹇撶焸瀹曡埖绻濋崒姘鳖伝婵犻潧鍊归崹婵堣姳閿熺姴违?
    //   闂佸憡甯囬崐鏍х暤娓氣偓閹?`morphContainerActive()`闂佹寧绋戝鍍糰ge 闂?ENTERING/LEAVING/LANDING闂佹寧绋戦¨鈧紒杈ㄥ閳ь剛鎳撻崯顐耿?
    //   `pullOpenBegin()` 闂備焦褰冮懟顖氼潩閵娧呯＞妞ゆ梻顑曢崑銊ッ瑰鍐╋紨缂佽鲸绻堥幊鎾朵沪閺傘倗澶勯柣蹇曞仜閸婄懓危?*闂?begin 闂?pushPath**闂佹寧绋戦悧鍡涱敋椤曗偓瀵粙宕堕妸锔奸獜闂?
    //   `beginMorphEnter` 闂佸憡鍔曢幊姗€宕曢幘顔藉殜妞ゅ繐瀚粻?push 闂佹眹鍔岀€氫即濡存惔銏″劅闊洢鍎崇粈鍡涙煃?`aboutToAppear` 闁哄鏅滈悷銈囩博閹绢喖绀嗛柡鍕禋閸ゃ垽鏌涢幒鎾愁棆婵炲牊鍨规禍鍛婃綇閵娤€锕傛煟椤忓棗鏋旀繛鏉戭樀婵?
    const shellOwnsMorph: boolean = this.expandState.morphContainerActive();
    if (shellOwnsMorph) {
      this.collapseProgress = 0;
    } else {
      this.collapseProgress = PlaybackPage.EXPAND_START_PROGRESS;
    }
    this.dismissMorphActive = false;
    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋掗悺鐚Closing` 闂?`onDismissDrag()` / `closeFullScreenPlayback()` 闂?*缂備焦顨忛崗娑氱博閹绢喗鐒奸柟鍓х帛椤?*闂?
    //   闁诲海鎳撻崯鈺冪博閹绢喖绫嶉柨鏃傛櫕閺嗘瑩鏌ｉ敐鍡欐噭闁?true闂佹寧绋戞總鏃傜箔閸涙潙绠璺侯儐閺嗩亪鎮硅濞撳湱绮畝鍕闁规儼濮ら敍鏃堟煙缁嬫妯€闁圭纾禍鎼佸础閻愯尪鎽曢梺鍛婄懃閼活垶濡甸幋锕€鏋侀柛顐墰缁€鍕偣閸ラ鐣虫い?`closeFullScreenPlayback()` 闂?
    //   闂備緡鍙忕徊鎯ь焽?`morphGenAlive` 闂佸搫鍟犻弲鐘诲焵椤戣棄浜鹃梺鍛婂笒濡瑩寮鈧幆鍐礋椤斻垹顦…瀹犵疀閺冣偓閺嗗牓姊洪幓鎺濈叚缂佽鲸宀告俊鎾磼濞戞妲搁柡澶屽仩婵倕顪?*闂佸搫鍟版慨闈涱焽椤栨稓顩?*濠电偞鎸搁幊宥囩博閺夋垟鏋庨柍钘夋噽缁?
    //   闂佸搫鍊绘晶妤冣偓鍨礃濞碱亪鎮剧仦鍓ф殸婵＄偑鍊楅弫璇差焽閻楀牏鈻旂€广儱鎳庣拋鏌ユ煠?濠殿喗绻愮徊钘夛耿椤忓牆缁╅柟顖滃瀹?闂佹寧绋戞總鏃堝箲閵忊剝濯撮柡鍥╁枔閺嗘瑩鏌ｉ敐鍡欐噰闁稿繑锕㈠畷锝夘敂閸曨偉顔夐梺鐓庣枃婵倕顭囬悽鍛婂殜妞ゅ繐鍟伴悷鎰槈閹绢垰浜鹃柡澶屽剱閸犳锕㈤鐘冲皫闁哄娉曢弳姘舵煟閵娿儱顏х紒杈ㄥ閹风姴鈹戦崟銊ヤ壕?
    this.isClosing = false;
    // 濠殿噯绲界换鎴︻敃婵傜绠ラ柟鎯х－绾惧姊洪鑽ょ煓闁革絽鎽滅槐鏃堫敋閳ь剟宕抽崫銉﹀珰闁哄洢鍩勯弶娲箹鏉堟崘顓虹紒杈ㄧ懇閹ゎ槼濠?`schedulePublishRetry` 闂?12闁?2ms闂?
    this.morphRetryLeft = 12;
    // 闂?闁诲骸婀遍幊鎾斥枍閹烘洏浜归柕蹇曞Т缂嶄線姊洪銊хɑ婵炵⒈鍨抽幑鍕敍閵堝洨顦╅柣搴濈祷椤鎮ラ敐澶婄睄闁绘ê鐏氬▍?ExpandAnimation闂佹寧绋戦¨鈧紒杈╁缁嬪顓奸崱妯烇箑鈽夐幘绛规敾濠殿垱妞介獮蹇斿緞鎼达絿顔掗梺鍝勵槶閸庡啿鈻撻幋锔芥櫖闁割偁鍨规禒顖炴煕?/ 闁荤姍鍥ㄦ暠闁规悂浜堕獮鍥疀閹惧顩梺鐟扮仛閹稿摜妲愰幋锔芥櫖?
    //   闁?*闁诲繐绻愬畷顒€锕?*闁荤姍鍡樿吂缂佹梹娼欓埢搴ㄥ灳鐎圭姴鐓傞梺?闂佺偨鍎查弻锟犲焵?闂佸憡鍨规慨宕囩礊瀹ュ鍌ㄩ悗锝庝簻閻撳倿鎮硅椤ユ捇宕戦敐澶嬫櫖闁?= 0 = 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨惧畷鍥唸闂傚倸鐗勯崹浠嬪磻閸涱喚鈻旈柍褜鍓涙禍姝岀疀閹炬潙浠撮梺鎸庣☉椤р偓缂?
    //   婵炲瓨绮岀€涒晛危閸濄儳绠旀い鎴ｆ硶椤忛亶鎮介鍡楁噺閺嗕即鏌涢幋鐘插妺婵炶偐鏁告禍鍛婃綇閵娤€?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹闂備焦褰冮惉鐓庘枔閹寸偟鈻旈柍褜鍓涙禍姝岀疀閹炬潙浠?闂佹寧绋戦惌浣芥＂闂傚倸鍊瑰娆忥耿?`onAppear` 闂備焦褰冮惌浣虹玻閸ヮ剙违?
    //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈弻銊ッ?false 闁荤姴娲ら悺銊ノｉ幋锕€绀勯柣妯夸含缁夋寧绻涘畝瀣瘈闁革絿鍎ら‖鍥箛閸撲胶顦╅柡澶嗘櫈濞撳湱绱炲鈧鍫曞灳瀹曞洦顔堥梻鍌氱墑閸ㄦ椽鎯€閸涱喚鈻斿┑鐘插暙琚?/ 闁诲海鎳撻妵妯尖偓闈涜嫰閳讳粙鍨鹃搹顐ｎ潊闁诲海鏁诲鑽ゆ濮樿埖鏅慨姗嗗墰缁犳垵顪冮妶鍥╁笡濠碘剝鎮傞幆鍕⒐閹邦喚孝闂備緡鍋€閸嬫捇鏌涢妷褍浠滄鐐存崌閺?
    //      闂佸憡鐔粻鎴﹀垂?`sheetHeightPercent()` 婵炴潙鍚嬮惌顔剧博閹绢喗鍎庣痪鎯ь儑缁犳煡鏌?100%闂佹寧绋戦惌渚€鍩€椤戞寧绁伴柣顓熷劤椤曘儵宕熼鐔烘殸"闁荤姵鍔栧娆戣姳閾忣偆鈻旈柍褜鍓熷鍫曟晸閻樿櫕鐦ｆ繛鎴炴尭閿曘儱顭?婵炴垶姊婚崰鏇綖閿曞倸纭€闁斥晛鍟粩鎾煥?
    //      闂佹椿娼块崝宥夊春濞戙垺鍎戦悗锝庝簻閻撳倿鏌ｉ妸銉ヮ仼婵ǜ鍔戝?闂佺粯鍔楅幊鎾舵閹达箑绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ闁汇儱鎳樺鍨緞婢跺搴婃繛杈剧稻濞叉牗鎱ㄩ埡鍛仺?闂?
    // 闂?**婵炴垶鎸哥粔鐑姐€呴敃鍌氭嵍闁靛绠戦惁顖炲级閻愯泛袚婵＄偛鍊绘禍鍛婃綇閵娿儙鈺呮煕閹寸姴小缂傚秴绉瑰畷銏⑩偓锝庝簻閻撳倿鎮硅椤ユ捇宕?*闂佹寧绋戦悧鎰崲閺嶃劎鈻旈柍褜鍓熷鍫曞焺閸愨敩锕傛煛閸愵亜啸闁?`expand.init` 闂佹眹鍔岀€氫即濡存惔銏″劅闊洢鍎崇粈澶娾槈閺傛鍎忓褏濞€閹啴宕熼锛勯┏濠电偛顦板ú鏍ь嚕閼恒儳顩查柛鈽嗗幘缁€鍡涙煥?
    //   闂佸憡鐟ョ粔鍓佹椤忓棙瀚氶柟杈剧畱濞?`setupExpandTransition` 闂?**闂佺绻愰悧鎾诲闯濞差亝鍎庢い鏃傛櫕閸ㄥジ鏌ら崫鍕偓濠氬磻閿濆鍎楅柍杞版祰閸?*闂佹寧绋戦悧濠囶敆濠靛绀嗙紓浣股戠亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢跺浜ゆ俊顖濆吹濮婂墽绱撻崒妤佹澓闁逞屽厸閻掞箑危閹间礁鍌ㄩ柣鏃堟敱濡测偓闁诲海鏁诲鑽ゆ?
    //   闂?闂?start 閻熸粏鍩囬崹纭呫亹?闂侀潧妫楅崐褰掑垂濠婂牆鍌ㄩ柣鏂挎啞闂勫秹鏌?`aboutToAppear` 闁?`morphBeginEntering()`闂? 缂備焦鏌ㄩ鍛村春閵忋垻纾介柍杞扮閻撳倿鎮硅椤ユ捇宕戦敐澶嬫櫖濠㈣埖绋撶粈?
    //   婵炲瓨绮岀€涒晛危閸濄儳椹冲璺猴工閻撳倿鏌ら崗鍛煓闁革絾妞介幆鍐礋椤掍緡妲梺绋匡攻閻熻京妲愬┑瀣厒闊洦鎸搁悡鍌炴煟閵娿儱顏俊?*闁荤偞鍑归崑鍕暜閸ヮ剙绠ュ〒姘ｅ亾闁稿鎳忕粙澶愬焵椤掑倹鏆?*闂佹眹鍔岀€氼剟鎯冨┑瀣棃?闂佺偨鍎查弻锟犲焵?缂傚倷绀侀悧蹇涘磻閿濆洣鐒婇弶鍫亽濞煎爼鏌涢幇顓犳噧婵炲吋鐗楃粋宥夊幢椤撶姷鐛?
    //   "缂備焦顨忛崗娑氱博閺夋垟鏋庨柍鈺佸暟濮婇箖鏌￠崼婵愭Ц闁汇劍绻堝Λ鍐閵堝孩锛囬梺?闂?缂傚倷鐒﹂幐璇差焽椤愶箑绫嶉悹鐑樹航娴滐綁鎮樿箛鎾剁缂佹顦遍埀?闂?闂佸憡鐟禍鐐扮昂闂佸憡鏌ｉ崝瀣箔婢跺瞼纾介柍鍝勫€归弶?闂佺绻堥崝宥呂ｉ崨濠冧氦婵炲棗娴烽閬嶆煛婢跺棌鍋撳畷鍥┾敍闁荤姍鍥舵婵炲牊鍨挎俊?
    //   闂佺粯绮嶅妯猴耿椤忓牆缁╅悷娆忓閻忓洭鏌ㄥ☉娆戭暡閻庡灚娲樺顏呯鐎ｎ偀鏋嗗┑鐐茬墕閸氣偓缂侇喖鐗婄粙濠囧醇閵夈儱骞嬫繛鎴炴尭缁夊瓨绂掑☉銏℃櫖鐎光偓閳ь剟寮?`playExpandIntro()`闂佹寧绋戝绁匒ppear 闁荤姍鍐ㄦ缂佽鲸绻勯弫?12闁?2ms 闂備焦褰冪粔鐑芥儊椤栫偞鏅?
    //   闂?*婵☆偓绲鹃悧妤咁敃婵傚憡鐓傞煫鍥ㄦ尭閻?*闂佹眹鍔岀€氫即宕戦崨顔锯枖闁逞屽墴瀹曟氨绱掑Ο渚瀫 `measureMini` + `morphBeginEntering()` 闂佺偨鍎查弻锟犲焵?闂備焦褰冪换鎺戔枔閹达箑鍙婃い鏍ㄨ壘閺傃囨倶韫囨挻鎯堟い鏇ㄥ弮閹矂鍩℃担钘夌厒闂?
    //   缂備焦鐦遍崟顐㈩槻闂佹椿鍋€閸嬫捇鏌涘顒€顨欑紒鏂款嚟閺侇喛顦查悽顖氭喘瀹曟岸骞忕仦鎯ч棷闂佺粯鍔楀▍銏㈡濞嗘挻鐓€鐎广儱鎳忛崐銈呪槈閹炬剚鍎旀繛闂村嵆閹?`introPaintReady` 闂傚倸鍋嗛悡澶屾濠靛洨鈻旂€广儱瀚粣妤呮⒒閸屻倓绨婚柛銈庡幘閳ь剛鎳撻張顒勫汲閿濆绠绘い鎾跺枑閺夌懓顪冮妶鍥舵殰缂佽鲸宀告俊?
    // 闂佸疇娉曟刊瀵哥箔?闂佹椿浜滈澶娢涢鍕亼婵°倕顑囩粣妤€鈽夐幘铏煑缂佹柨鐡ㄧ粙澶屸偓锝庡枟濡?`onAppear` 闂備焦褰冮惉鐓庘枔閹寸姵鍋橀柕澶嗘櫆閿涚喖鏌涢妷褍小閻犳劗鍠愮粋鎺旀媼瀹曞洨协闂佸憡顭囬崰搴∶哄鍐ｆ煢闂勫洨绮ｉ崶鈺傚皫闂佸灝顑嗛梽宥夋煥?
    //   闁哄鏅滅粙鎴犫偓鐟扮－娴滄悂宕ｅΟ鑲╃崶濠殿喗蓱閻℃洜鎹㈠▎鎾崇；婵犲﹤鍟煬?闂佽　鍋撻柟顖滃瀹?闂佹寧绋戦惉濂稿极閵堝绠ｅ瀣缁犳瑩鏌涢幒鎾愁棆婵炲牊鍨垮浼搭敍濞戞ǚ鍙烘繛鎴炴尭缁夊妲愰幋锕€绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥΩ闁?
    //   闂佸搫鐗冮崑鎾诲级?COLLAPSE_WATCHDOG_MS 婵炴垶鏌ㄩ鍛村箖濡も偓椤曪綁宕崟顐ゅ幀闂佹悶鍎抽崑娑㈠春瀹€鈧埀顒傛嚀閺堫剟寮抽敐澶婄畱?闂佺偨鍎查弻锟犲焵?闁诲酣鈧稓顦︾憸鐗堝絻閳讳粙鍩勯崘鈺冪暢闂佸憡鏌ｉ崝搴ㄥ极妤ｅ啫违?
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
    }
    this.collapseWatchdogTimer = setTimeout((): void => {
      this.collapseWatchdogTimer = -1;
      if (this.collapseProgress > 0) {
        Logger.error(PlaybackPage.logTag,
          `expand watchdog fired progress=${this.collapseProgress}, force full screen`);
        this.collapseProgress = 0;
      }
    }, PlaybackPage.COLLAPSE_WATCHDOG_MS);
  }

  /**
   * 闂佺绻戞繛濠偽涢幘顔藉闁瑰瓨甯炵粔鏉戔槈閺傛鍎忛柟顔筋殜閺?*缂備焦绋戦ˇ浼村箰闁秴缁╁Δ锝呭暔閳ь剙顦甸幆鍥偄閻戞鏆犳繛瀵稿Т濮橈箓鎯屾ィ鍐╁仺閺夊牄鍔庨崹浠嬫⒑閹绘帒顨欑紒妤€鎳樺畷锝囨暜椤斿墽顦梺鍛婂姇缁夋挳藝閸欏濯寸€广儱鎳撻崺宀勬煕濞嗘兎顏堝吹閹寸偞濯?*闂?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ矌閻熸繈鏌ょ€圭姵顥夋繝鈧鍫濊Е閻忕偠鍋愰?tick 闂備焦褰冮懟顖炈囬崣澶嬪鐎广儱绻掔粈鍕煟椤剙濡介柛鈺傜〒缁?闂?闂佸搫顧€缁辨洖鈻撻幋锕€瀚夐柛婵嗗閻撴垿鏌?
   * 闂佺绻戞繛濠偽涢幘顔肩哗閻犻缚娅ｉ崯鏌ユ煕濡厧鏋戞繛鑲╂暬瀵?`isShowPlay = false`闂佹寧绋戦悧鍐疮?婵犮垻鎳撻崯鍧楁儑?`@Monitor` **閻庢鍠栭崐褰掝敆?* pop闂?
   * 缂備焦鐦遍崱娆樷偓鈧梺娲诲亐閸?*闂佸憡鑹鹃張顒勵敆?* `morphReset()`闂侀潧妫楅崐浠嬪焵?`morphReset()` 婵?
   * `morphStage = NONE` + `morphP = 1` + `morphClipHeight = 0` + `morphScale = 1`
   * 闂?闁诲骸婀遍幊鎾斥枍?*婵炴垶鎸哥粔鐑剿夐崱娑樼妞ゅ繐鍊甸崑鎾存媴妞嬪海鎲圭紓鍌氬€甸弲婊堝棘?* = **濠电姴艌閳ь剙纾宀勬煙缂併垹骞楅柡鍌欑劍閵?*闂?
   * 闁荤姳璀﹂崹鎶藉极闁秴纭€缁炬儳顑愬ú锝夋煕閹烘鏆掔紒妤€鎳忕粙澶愬焵椤掑倹鏆滅憸搴㈡櫠閻樺灚鍋栨い鎰剁稻閸犲懘鏌熼崫鍕垫缂佽鲸鐛婡Monitor` 濠电偛寮堕崕瀹犮亹閸屾稓鈻旈柍褜鍓涙禒?+ 闁汇埄鍨伴崯顐︽儑椤掑嫬绠烘慨妞诲亾婵炲懎瀛╃粙澶愬焵椤掑倷娌柛宀嬪缁€?
   * 闂?婵炴垶鎼╅崣鍐ㄎ涢崸妤佺劷?1~2 闁汇埄鍨庨崘鈺冩闂?閻庤鐡曠亸娆戝垝閿涘嫮纾介柍鍝勫€搁悘鍥倶韫囨挾绠版繛鎾荤畺閹?闂?缂備焦鍔掗懗鍫曞礉瑜嶉…銊╁灳瀹曞洦缍?闂?濠电偞鍨甸悧鍡涘Φ?闂?
   * 闂佹椿娼块崝宥夊春濞戙垹绠甸煫鍥ㄨ壘閻楁岸鏌熺€涙ê濮傞柍褜鍓欓懟顖涙叏閳哄懏鍋ㄩ柤濮愬€楀▔銏ゆ煛婢跺苯鏋嶇紒?*缂備焦鍔掗懗鍫曞礉瑜斿鍫曞Ψ閵堝娈濋柣蹇曞仦濞叉牜妲愰幋锕€绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ婵炲牊鍨垮畷婵嬪Ω瑜庨弳?*闂侀潧妫楃粔鏌ュ焵?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻?闂佸搫鎳忛惌顔剧博閹绢喗鍊烽柣鐔煎亰濡茶霉?闂佸搫瀚烽崹浼存偩閵娾晛绀傞柕濞у嫮鏆?
   * `morphLand()` 閻庤鐡曠亸娆戝垝閿熺姴绠┑鐘插鐢盯鏌涢幒鏇炵厫婵炵厧鐗婄粋宥夊Χ閸垻顔庣紓鍌欑劍閻熴劎鍖栭悩铏闁绘娅曢拏瀣瑰鍐╋紨缂佽鲸绻堥幊?闁荤偞鍑归崑澶愃夐崱娑樻嵍闁靛鍔庣喊鍐归敐鍥ｆ繛纰卞灦閺屽洭鏁愰崟顓犳澖婵?闂佹眹鍔岀€氫即宕戦崨顔锯枖闁逞屽墯缁傛帡鎸婃径濠冾吇婵?
   * **闂侀潻璐熼崝鎴﹀Υ婢舵劖顥堟い顐幘閻熸捇鏌涘▎鎿冩殥缂佺媴缍佸畷婊冾吋閸♀晛濡ч梺鍝勫閸ㄩ亶顢楀鍛厹妞ゆ梻鍋撻悾閬嶆煛閸曨偄鈷旈柕鍥ㄥ哺閹晠鎳滅喊妯轰壕?* 闂?婵犮垼娉涚粔宕囩礊閸涱厸鏌﹂柍鈺佸暞缁犳帒霉閻樹警鍞虹紓宥呯Ч閹爼宕卞▎鎰闂佺缈伴崹鐟帮耿?pop 闂佸憡鎸哥粔鐟邦焽娴兼潙违?
   * 闂佸憡鐟ョ粔椋庢崲閸愵喖绾ч柕澶樺灣缁€?*婵炴垶鎸哥粔鎾囬崣澶嬪鐎广儱瀚粣妤佹叏閸忓澧查柣鎾愁儐缁嬪鈧絺鏅濋閬嶅级?*闂佹寧绋戦悧鍡涘吹閹寸偞濯撮柡鍥╁枎閻︻垶鏌?AppStorageV2 婵炴垶鎸搁敃銉ノｉ幖浣哥闁告瑦锕㈤悡鈺呮煟閵娿儱顏电紒杈ㄥ哺閸?闂婎偄娲ら幊姗€濡磋箛鏂跨窞鐎广儱瀚粔鎾煥濞戞瀚扮憸鎶婂洤鍙婃い鏍ㄧ箥濞诧綁鏌￠崨顔兼惛闁?
   *
   * ## 闂佸憡甯囬崐鏍х暤娴ｅ湱鈻旈弶鐐村閻棗鈽夐弬璺ㄥⅱ闁?闂佺厧鎼崐濠氬磻?闁荤姳璀﹂崹鎶藉极闁秵鐒鹃柟瀛樺笧閻熸捇鏌涘▎鎿冩殥缂?闂佸吋婢樻總鏃傜箔婢舵劕鍙婃い鏍ㄧ缁佸ジ鎮楃憴鍕婵炲棎鍨藉?
   * 闂佹悶鍎遍幖顐︽偩閹屽殘闁肩鐏氶ˇ褔鏌ㄥ☉妯煎缂佽翰鍎叉穱?64ms闂佹寧绋戦ˇ顖濄亹瑜斿?*闁?* pop 濠殿噯绲鹃弻銊╂偩閻樿櫣鐤€妞ゆ劦鍓涢獮銏ゆ偣瑜嶉惌浣烘椤撶姳鐒婇弶鍫涘妼閳ь剚鎹囬獮鍐礋椤栨浜鹃柍褜鍓熷畷鍫曟倷閹绘帗鏋?bug闂?
   * 婵炴垶鎸堕崐鎾绘煂?*闂佺儵鏅涢悺銊ф暜鐎靛憡瀚氱紓浣股戝▓?*闂備緡鍠栭埀顒傚櫏濞诧絾绻濇繛鎰╁€曢崰鏇㈡煙闂堟稓孝妞わ箑寮堕幏鍛吋韫囨洜顦梺鎼炲劤婵磭鎷归悢鐓庣闁哄洨濮电粻娆忊槈閹绢垰浜炬繛鎴炴惄娴滎亪宕楀Ο璇差嚤?婵犮垼娉涚粔宕囩礊閸涱収鍤楁俊銈傚亾闁靛洤锕?闂?
   * 閻?`!this.isAlive`闂佹寧绋戦悧鎰繆椤撱垺鍊烽柛锔诲弮閻涙捇鏌ㄥ☉姗嗘Т闁逞屽墯閺岋繝鍩€?`onDisappear` 闂佸搫瀚烽崹鍨繆椤撱垺鍊烽柛锔诲幗閸╁倿鏌ｉ妸銉ヮ仾缂佸鏀卞鍕綇閵婏富妲梺褰掓涧缁夌柉顤傞梺鍛婄懄閸╁﹦妲?
   * 閻?`!playerRouteStillPushed()`闂佹寧绋戦悧鎰版儗妤ｅ啯鍋ㄩ弶鍫氭櫊閻涙捇鏌ㄥ☉姗嗘Т闁逞屽墯閺岋繝鍩€?闂佸憡鐟辩徊鐣屾閻愬鈻旈幖绮规缁憋箓鎮?`playerRouteIndex()` 闂備緡鍋呴崝鏇㈡偤瑜庣粙澶愬焵椤掑嫭鍤婃繛锝庡厴閸?
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟禍鐐诧耿閸涱垱宕夋い鏍ㄧ矋閺嗙姴霉?*婵犮垽顤傛禍婵單?*闂佹寧绋掗悺鐚祇p()` 闂佸憡鐟禍婵單ｉ幖浣哥哗?`NavPathStack` 闂?*闂佽桨鑳舵晶妤€鐣?*闂?
   *    闂佺厧鎼崐濠氬磻閿濆鍎嶉柛鏇ㄥ墯閸犲懘姊婚崟鈺佲偓娑€呴敂鍓ч┏濠㈣泛顦遍悷鎾斥槈閹绢垰浜惧┑?layout 闂?闁荤姳璀﹂崹鎶藉极閸楃儐鍟呴棅顐幘閻熸捇鏌涘▎鎺戠劷闁逞屽厸濞村洦淇婇銏″€风痪顓炴噽缁犵兘鏌涢敂鍝勫闁活偄妫欑粙澶嬬節閸曨剛鏆犻梻渚囧弿缁茶偐绮╃€靛憡鏆滅憸搴∥ｉ崫銉㈠亾濞戞顏勶耿椤忓牊鍎嶉柛鏇楁杹閸?
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟禍鐐诧耿閸涘瓨鍤嶉柛灞剧矊娴狀垰鈽夐弮鍌氭瀺缂?*婵犮垽顤傛禍婵單?*闂佹寧绋掗懝楣冨矗瑜斿濠氼敇閳垛晛浜鹃柡鍌涘礃閸橆剟鏌?闂佸憡甯掑Λ娆撳极椤曗偓閺屽苯顓奸崨顖滃"闂佸憡鑹鹃張顒勬偋鏉堛劌顕辨慨妯诲閺囥垹鐭?`onDisappear`闂佹寧绋戦悧濠傦耿娴兼潙妫橀柛銉檮椤?5000+ 闁?
   *    闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姳鑳堕悷鈺呮⒒閸屾ê濮€妞ゆ柨顦板濠氬炊椤忓棛顔愭繛瀵稿У濠€鍦姳閵娾晜鏅璺烘閸嬫捇寮悰鈥充壕?闂備緡鍙忕徊鎯ь渻閸岀偞鍤嶉柛灞剧矊娴狀垶寮堕埡鍋偐妲愭导鏉戠倞闁绘劕鐡ㄩ梽宥夋煏?
   * 闂?婵炴垶鎸堕崐娑㈠焵?*闂佸憡鑹鹃張顒€顪?*闂佺懓鐡ㄩ崝妤呮偟濞戙垹绠ョ€广儱妫欑瑧"闂佹椿浜為崰鎾斥枔閹寸姵灏庡Λ棰佽兌閸?闂佹寧绋掔粙鎴﹀疮閳ь剟鏌?`attempt >= RESET_POLL_MAX` 闂佺绻戠划宀€鑺遍幎鑺ユ櫖?
   *    婵烇絽娲︾换鍡涙儊?闂佸憡绻嶆禍婵嬪焵椤掍焦纾婚悶姘抽哺缁嬪顢旈崶璺烘闂佽桨妞掗崡鎶藉礂濮椻偓瀹曟瓕绠涢弬璺伇闂佹寧绋戦懟顖炲吹閹寸偞濯撮柡鍥ㄦ皑閻﹀秴鈽夐幘顖氫壕闁诲氦顫夐惌顔炬閹殿喗鍋栨い鎰╁焺濡茶霉?闂佹寧绋戦悧鍡涙偩閻愬搫鐭楁い鏍ㄧ⊕閻濇捇鏌ㄥ☉妯侯殭缂佹顦靛畷锝夘敍濞嗘垹鎲瑰┑鐐存尭閹锋垹妲愬璺何?
   *
   * ## 婵炴垶鎸堕崐婵囩閸撗€鍋撻悷鎵鐎规洖銈搁弫宥夊醇閵忕姷绠掓繛鎴炴尨閸嬫挸鈽夐幘宕囆㈢憸鐗堢叀閺?
   * 閻?`closeGen !== this.closeGen`闂佹寧绋掓穱铏规崲閺嶃劎鈻旈柍褜鍓氬顏堫敊閻撳骸缍橀梻鍌氬亞閸樺ジ宕欓敍鍕仏?婵炴垶鎸搁鍕博閺夋垟鏋庨柍銉ュ暱瑜扮娀姊婚崒銈呭绩妞ゆ洦鍓欐晥?闂佸憡鐟﹂悧鏃堝船?闂?闂佸憡甯╅崑鍛博婵犳碍鏅?
   * 閻?`!morphGenAlive(resetGen)`闂佹寧绋掗懝楣冨吹閹寸偞濯撮柡鍥ㄦ皑閻燁垰霉閻欏懐鍒扮憸鏉跨仢椤斿繘鎳犻鍌滄⒕闂佸憡鐟︾湁缂?闂?閻庤鐡曠亸娆戝垝閿熺姴瀚夊璺猴工閻掔厧霉濠婂懎鐨戠紒杈ㄧ懇瀵剚锛愭担渚紘闁哄鍎愰崰妤佹櫠閿曗偓椤曪綁鍩€椤掑嫭鍎嶉柛鏇ㄥ枛濞堜即鏌?
   *   `staleClr` / `leakClr`闂佹寧绋戦ˇ鎵博缂佹ɑ浜ら柛銉戝棗鐝梻浣瑰絻缁夊绱撻幘瀵割洸闁糕剝娲滅粣妤呮偣?闂?**闂佸憡鍔曠粔鐢电博缂佹鈻旈柍褜鍓欓埢搴ㄥ灳閾忣偆娈ゆ繛鏉戝悑绾板秵淇婇幖浣哥婵娅曞畷鎶芥煟閵娿儱顏х紒杈ㄥ閹风姴鈹戦崶褏鐟㈠┑?*
   *   闂佹寧绋戦悧鎾诲磻閸涱収娼伴柨婵嗘绗?闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱濠电偛澶囬崜婵嗭耿娓氣偓瀹曟繈濡歌閺?闂佹眹鍔岀€氼參宕瑰璺虹倞闁绘瑥鎳愮粈鍡涙煏?
   *
   * @param closeGen 闂佺顫夊ú婵嬬嵁韫囨稒鍤婃い蹇撳瑜扮娀姊婚崒銈呭绩闁圭櫢缍侀獮宥団偓锝庡墯閻ｉ亶鏌涜箛鏂库枙婵☆偄鐡ㄧ粙澶愬冀閿曗偓閺佲晠鏌?
   * @param resetGen 闂佺顫夊ú婵嬬嵁韫囨稒鍤婃い蹇撳瑜扮娀姊婚崒銈呭箺闁轰礁婀辨禍鍛娿偅閸愩劋绨兼繛鎴炴尨閸嬫捇鏌涢幒鏇炲惞婵炲牊鍨奸妵鎰板閻樿尙绉繛鎴炴尰閻楁棃宕鍕煑?
   * @param attempt 閻庤鐡曠亸娆戝垝閳╁啯濮滄い鏃€顑欓崵鍕级閳轰焦鎼愰柛銈嗗灥閳诲酣鍩ラ崨顖滎槱闂佸憡鍔曢幊姗€宕曢幘顔界劵闁圭儤鍨圭粔娲煟閵忊晝鍘滅紒?
   */
  private scheduleMorphResetAfterPop(closeGen: number, resetGen: number, attempt: number): void {
    setTimeout((): void => {
      if (closeGen !== this.closeGen) {
        PlaybackPage.ev('RST', 'skip(newerClose)');
        return;
      }
      if (!this.expandState.morphGenAlive(resetGen)) {
        PlaybackPage.ev('RST', 'skip(newerSession)');
        return;
      }
      const nodeGone: boolean = !this.isAlive;
      const routeGone: boolean = !this.playerRouteStillPushed();
      if (!(nodeGone && routeGone) && attempt < PlaybackPage.RESET_POLL_MAX) {
        this.scheduleMorphResetAfterPop(closeGen, resetGen, attempt + 1);
        return;
      }
      this.expandState.morphReset();
      // 闂?2026-10-17闂佹寧绋戦悧蹇涘极閵堝绠ｉ梺鍨儏琚氶梺闈涙婵傛梻绮崒鐐茬濠㈣泛顑嗙亸锟犳煛閳ь剟鎮欓浣芥嫬闂佸憡鍔曠粔鏉懨洪弽顓炲偍濞村吋鐟х粈澶愭煙缂併垹骞楅柡鍌欑窔瀵爼鍨鹃崘鑼М闂?*缂備胶铏庨崹鍨珶婵犲洤纭€濠电姴娲犻崑鎾圭疀閺冣偓椤?*闂侀潧妫楃粔顕€宕?闂?闁荤姴顑勭粈浣革耿椤忓牆纭€闁绘ê鐏氱徊濠氬级閳哄嫭鑵圭紓宥嗭耿瀵爼鏁嶉崟顒傛殸
      //   缂傚倷鐒﹂敋闁糕晜顨婂?婵炴垶姊婚崰鎰櫠閿旇姤浜ゆ繛鎴炵矌缁犵懓鈽夐幘顖氫壕闂佸搫顦Σ鍕濮樿埖鏅慨婵囩摤ar=` = `sourceBarHidden`闂? = 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍩勯崘鈺傤啋闂佸搫顥￠妶搴㈣晧闂佽姤锚缁绘骞戦敐澶婄骇闁靛鍊楅崯濠囨煥?
      //   濠殿喗绻愮徊浠嬫偉閼稿灚鍎熼柡鍌濇硶缁夊ジ鏌?**0**闂佹寧绋戦¨鈧紒杈╂禇ovl=` = 婵犮垻鎳撻崯鍧楁儑閺夋５褰掝敊閼测晜鍕鹃梻渚囧弿缁茶偐绮╅弶鎳虫盯骞掗弮鈧悾閬嶅级閳哄倻鈽夐悗瑙勫▕閺佸秹宕搁崚纾憆phOverlayP`闂佹寧绋戦惌鍌氼焽閵堝拋娼伴柕蹇婃閸嬫挻鎷呴崫銉ョ暔閻熸粎澧楅幐璇参?1闂佹寧绋戦¨鈧紒?
      //   `own=` = 闂佺绻愰崯鈺傜┍婵犲洤绠掓い鏍ㄨ壘鐢剟姊婚崨顓燁棞闁活亙鍗冲浼搭敍濮橆厼鍓ㄩ柡澶嗘櫆閿氱€规洑鍗抽幆鍫ュ焵椤掑倻纾兼俊顖氭惈閻撴垿鏌℃径濠傛灕缂? = 闁哄鏅滈敋婵犫偓椤忓牆纭€?闂?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹婵炲濮炬慨銈夋偤閺囥垹瑙︾€广儱鐗滃鍫曟煕濡警鍎愰柛?0闂佹寧绋戦ˇ顓㈠焵?
      //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銉╁吹閹寸偟鈻旀い蹇撶墕濞?*闂佸憡鐟禍婊冿耿椤忓懏浜ゆ繛鍡樻尭濞咃繝鎮?*闂佹寧绋戝濉祇rphReset()` 闂佸憡甯楅懝楣冨垂娴兼潙绠┑鐘插€婚弳濠偯归悪鈧崜娆戠礊婵犲啯濯寸€广儱绻掔粈鍡涙煥濞戞ɑ婀板褍绉电粋鎺楀Ψ閵壯勬疁闂佸憡鐟ョ粔闈浳ｈ閹啴宕熼浣?
      //   "闂佽　鍋撻悹楦挎閸熸煡鏌涚€ｎ偉澹橀柣锝庡墯缁嬪﹦鈧綆浜濋崐?闂佹眹鍔岀€氼喖锕㈤敍鍕ㄥ亾閸︻厼浠у┑顔芥倐楠炩偓?闂佺偨鍎查弻锟犲焵?闂佹椿娼块崝宥夊春濞戞瑧鈻旈悗锝庡亽閸嬔囨煙閸偅灏紒杈ㄥ灥椤曘儵鎳為妷褍鐏遍柣蹇撶箺缁箖宕楀鈧幆鍥┾偓锝庝簻閻撳倸鈽夐幘绛规缂佹梹娼欓埢搴ㄥ灳閸愭彃缍橀梻鍌氬亞閸橀箖寮抽埀顒€鈽夐幘鎰佸剮缂併劉鍓濈粋鎺楀焵椤掍胶鈻曢柛顐ｇ▓閸?
      PlaybackPage.ev('RST',
        `p=${this.expandState.morphP.toFixed(2)} stage=${this.expandState.morphStage} ` +
        `cont=${this.expandState.morphContainerActive() ? 1 : 0} ` +
        `try=${attempt} node=${nodeGone ? 1 : 0} route=${routeGone ? 1 : 0} ` +
        `bar=${this.expandState.sourceBarHidden ? 1 : 0} ` +
        `ovl=${this.expandState.morphOverlayProgress().toFixed(2)} ` +
        `own=${this.expandState.metaBridgeOwnsPaint() ? 1 : 0}`);
    }, PlaybackPage.RESET_POLL_MS);
  }

  /**
   * 闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暟閻斿懘鏌?*闂佸搫瀚烽崹浼村箚娴ｈ浜ゆ俊顖滃劋闊剙顭块悷鏉挎毐闁活亙鍗抽幆?`NavPathStack` 闂?*闂?
   *
   * 闂?2026-10-16 闂佸搫鍊瑰姗€路閸愵喗鏅柛顐ｇ箖閺嗘粌鈽夐幘顖氫壕闁荤姴顑呴崯浼村极閵堝鍊烽柣褍鎽滅粣姊?onDisAppear()` 闂備焦褰冮惌鍌炲磻閸涘瓨鐒?`isShowPlay` 闂佺绻戠划宀€鑺遍幎鑺モ拻妞ゎ厽甯炵粈鍡涙煏?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劜娴犳﹢鎮烽弴姘鳖槮闁?
   * `isShowPlay` 闂?*婵犮垻鎳撻崯鍧楁儑閹殿喗宕夋い鏍ㄧ矋閺嗙娀鏌ｉ妸銉ヮ伃闁崇懓绉瑰畷婵嬪Ω閿斿墽鍩?*闂佹寧绋戝濉坣dex.@Monitor('appState.isShowPlay')`
   * 闂?`popPlayerRoute()`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婁粙鍩€?`.onDisAppear()` 闂?*闂佺厧鎼崐濠氬磻閿濆洨妫?*闂佹悶鍎抽崑鐘绘儍閻斿吋鏅悘鐐跺亹缁愭鏌?
   * "闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佸搫鍟抽崺鏍涢銈傚亾閸︻厼浠掔紒韬插劦瀹曗€愁潰鐏炲墽銈?/ 闂佸憡甯掑Λ娆撳极椤曗偓閺屽苯顓奸崨顖滃"闁哄鏅滈悷銈囪姳濞差亜鎹堕柛婵嗗閸?*婵?*闁荤喐鐟辩粻鎴ｃ亹?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯ь渻閸岀偛绠绘い鎾跺枑閺夌懓顪冮妶鍕シ闁活參绠栭幃鑺ユ綇閵婏富娼犻梺鍝勫妤犵锕㈤鍫濆唨闁割偁鍎卞▍锟犳煏?
   * 闂佸湱顣介崑鎾趁归悩顔煎姤妞も晪绠撳畷?`isShowPlay = false` 婵炴垶鏌ㄩ鍛櫠閻樼粯鏅悘鐐垫櫕缁犳垵顪冮妶鍫殭闁告ɑ绋撳☉鐢割敊濞嗘儳鎮?闁哄鏅滈悷銈囩博閺夋垟鏋庨柨娑樺閸╁倿鏌ｉ妸銉ヮ仾婵℃彃鎲＄粙澶屸偓锝庝簻闁?闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟辩徊鐣屾閻愬鈻旈幖绮规缁憋箓鎮橀悙鎻掆偓璇测枔?{@link Index.playerRouteIndex} **闂備緡鍋呴崝鏇㈡偤瑜庣粙澶愬焵椤掑嫭鍤?*闂佹寧绋戝濉痚tAllPathName()` +
   *    `indexOf(PLAYER_PAGE)`闂佹寧绋戦¨鈧紒杈ㄧ箖濞艰鈻庨幇顔碱棊婵炴垶鎸堕崐娑氱博閻旇　鍋?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺⊕闊剙鈽夐幘宕囆㈡繝鈧鍫濆唨闁割偁鍎卞▍?濠殿喗蓱閻℃洜鎹㈠▎鎾冲強妞ゆ牗纰嶉崐鍗炩槈閹绢垰浜炬繛鎴炴惄娴滅偤鎮洪悢濂夋禆闁割偅绋堥崑?
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟﹂悧鏃傜箔婢舵劕绀嗛柣妤€鐗忛崹浠嬫煥濞戞ɑ缍丂Consumer` 濠电偛澶囬崜婵堟暜鐎涙鈻斿┑鐘茬箳缁€鍡涙煛?*闁哄鏅滈弻銊ッ?true**闂? 婵烇絽娲︾换鍌炴偩瑜忛幏瀣Χ閸曨喚顦?闁哄鏅滈敋婵犫偓椤忓牆鍐€闁割偁鍎卞▍?闂佹寧绋戦¨鈧紒?
   *    闁诲酣鈧稓顦︾憸鐗堝絻椤疇绠涢弬璺伇婵炴垶鎸撮崑鎾寸箾?Hard-exit 闂佺绻戠划宀€鑺遍幎鑺ユ櫖閻忕偠鍋愰惁宥囩磽娴ｅ湱绠戠紒妤€顦靛畷姗€骞掗弮鈧徊?闂佺娉涢敃銈夊垂娴兼潙绠ラ柟鎯х－绾惧鏌ｉ妸銉ヮ仾闁规悂浜跺銊︺偅閸愶腹鍋撴径濠庡殨閻熸瑥瀚粩?闂佹眹鍔岀€氫即藟閹剧粯鈷旈柍鐟扮氨閸?
   */
  private playerRouteStillPushed(): boolean {
    try {
      const names: string[] = this.pageIndexInfos.getAllPathName();
      if (names === undefined) {
        return true;
      }
      return names.indexOf(RouterUrlConstants.PLAYER_PAGE) >= 0;
    } catch (err) {
      Logger.warn(PlaybackPage.logTag, `playerRouteStillPushed failed: ${err}`);
      return true;
    }
  }

  /**
   * @returns 闁哄鏅滈悷锕傤敃婵傜纭€婵繂鏈粊?*闁荤姴娲㈤崕鎵箔婢跺本瀚氶柕澶涚畱鎯熼悷婊嗗焽閸ㄧ銇愭径宀€纾兼俊顖氭惈閻撴垿鏌℃径濠傛殨婵﹫闄勫璇参熼懖鈺勫煑闁哄鏅炲〒鍦礊濮椻偓瀵?*闂? 闁荤姴娲㈤崕鎵箔婢跺本瀚?`morphReset()`闂佹寧绋戦ˇ顓㈠焵?
   *
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*"闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱濠电偛澶囬崜婵嗭耿娓氣偓瀹曟繈濡歌閺?闂佹眹鍔岀€氼厼銆掗崜浣虹＜闁割偅绻傞悘鏌ユ煙?* 闂佺偨鍎查弻锟犲焵?婵炴垶鎸搁ˇ鎶芥偪閸℃瑦瀚氶柡鍥ュ灪閺呪晠鏌涘顒勵€楅柣锝呭⒔缁瑩宕犻敍鍕槴
   *
   * ## 闁荤偞鍑归崑鍕箚娓氣偓楠炴帗寰勭仦鍓ф殸婵炴垶鎸堕崐鎾绘煂濠婂牊鍋嬮柛顐ゅ枑閹烽亶鏌ㄥ☉妯煎闁糕晛妫濆畷妯侯吋閸涱喚顦ラ梺鍛娒肩槐顔炬?
   * | 闂佸憡甯囬崐鏍х暤?| 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劜閺?|
   * | --- | --- |
   * | `morphUsable`闂?闂佸憡鍨规慨宕囩礊瀹ュ拋鍟呴柟缁樺笚閻ㄦ垹绱?闂?| **婵犮垽顤傛禍婵嗏枍?*闂佹寧绋掑銊╁磻閿濆绀勯柡鍕箳閻斿懐鈧灚婢樼€氼剙锕㈤鍫濈闁稿本绻冪粊浼存⒑椤撱劎瀵肩紒鏃€鎸冲畷姘舵嚒閵堝洨鐓夐梺缁樺姇缂嶅﹪寮€ｎ喗鍊风痪顓炴噽缁犻攱绻涘畝瀣瘈闁革絾妞藉畷?闂?闂佽鍘界敮鎺撶?闂?闂傚倸鍊堕崝宥咁浖閸喐浜ゆ繝濠傚暟绾惧鏌ｉ鐔蜂壕 |
   * | `playerRouteStillPushed()`闂?闁荤姳璀﹂崹鎶藉极鏉堛劍浜ゆ俊顖滃劋闊剟鏌″鍛ⅵ闁?闂?| **婵炴挻纰嶇换鍡欑矉閸℃娴栭柛鈩冾焽娴犳悂鎮圭€ｎ亜鏆欓悗?*闂佹寧绋掗悺?onDisAppear` 闂備緡鍙忕紞浣圭妤ｅ啯鈷掗柕濠忛檮绗?`setTimeout(0)`闂侀潧妫斿姊恇outToDisappear` 闂佸搫瀚烽崹浼村箖閹炬剚娼伴柕澶樺灣缁€澶愭煠?`popPlayerRoute()` 闂?*闂佸憡鐟辩紓姘辩博鐎涙鈻?* `@Monitor` 闂佹悶鍎抽崑鐘绘儍閻斿吋鐓傜€光偓閸愵亞宕?闂佺偨鍎查弻锟犲焵?婵炴垶鎸搁ˇ鎶藉焵椤掆偓閹虫捇鎯冨┑瀣闁割偓绲垮▓閬嶆煕濮橆剟鍙勬繛绗哄€濋獮鈧ù锝囩摂閸ゃ垹鈽夐幘宕囆㈤柛銈庡弮瀵爼濡烽婊咁槱`RzdMusic闁荤姳鐒﹀妯兼崲?md` 闁?10 閻庤鐡曠亸顏堫敊閸ャ劎鈻旈弶鐐村閻熸繄鐥褍鏋涢柣锝囧亾閵囧嫰鎯傞崫銉ь槴 |
   *
   * ## 闁诲氦顫夊銊┾€﹂崼銉ョ闁靛牆妫楃粊?= **闂佹椿娼块崝宥夊春濞戙垹绠涢煫鍥ㄦ尰缁?*闂佹寧绋戝濉眘ShowPlay`闂? 婵炴垶鎸撮崑鎾绘煛婢舵稓纾块柍銉︾墬缁楃喓鈧綆浜跺Ο?
   * ```
   *   !isAlive          闂?闂佹椿浜為崬瑙勵槹鎼达絿鐓佹繛瀵稿Ь濞夋稑鐣佃箛鏃€濮滈柡鍌樺€楃粈鍕槈閹惧磭校婵?闂佺懓鐏氶幐鍝ユ閹达箑绫嶉柤绋跨仛閿涘鎮楅崷顓炰粧缂佽翰鍎抽幏瀣煛閳ь剛绱?闂佹寧绋戦ˇ顐﹀闯?闂婎偄娲ら幊姗€濡磋箛娑樼哗闁绘劦鍓氱紞鈧?
   *   morphGeomReady    闂?闁哄鏅滈悷銈囩博鐎涙ɑ濮滄い鏃傚亾閸╁倿鏌ｉ妸銉ヮ仼婵犫偓椤忓牆绠绘い鎾卞妿缁€鍕磽娴ｅ摜澧㈤柛瀣剁秮瀹曟瑩鎮╂潏鈺冃悗鐟版啞閻擄繝宕冲ú顏勭閻㈩垼鍠氱粈鍡涙煃?缂傚倷鐒︾换鈧紒妤€顦甸幊妤呮嚍閵夈儮鍙洪梺?
   *   state.isShowPlay  闂?婵犮垻鎳撻崯鍧楁儑娴兼潙鑸规い鏍ㄧ懅椤忛亶鏌?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭枤閸ゅ鈽夐幘宕囆ユい鏇熷哺瀹曠兘濡搁妷褎缍勬繛?闂佹椿浜為崰鎰姳?闂?闂佽　鍋撻柣鎰靛墯缂嶁偓 = 闂佺娉涢敃銉︽櫠閿曗偓椤曪綁鍩€椤掑嫭鍤婃い蹇撳缁犳帡鏌熼悜妯哄闁?
   * ```
   *   閻?**闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱**闂佹寧绋掗懝楣冩晬閹炬湹娌柛灞捐壘閻忕娀鏌?`isShowPlay` 缂?`true` 闂?闁哄鏅滈悷銈囩博閺夋垟鏋庨柍銉ュ暱缁佸寮堕悙鏉戠亰缂佹顦靛畷锝夘敃閿濆棙婢掗梺?闂?
   *   閻?**闂佺绻戞繛濠偽?*闂佹寧绋戦悧鍡涘矗瑜斿濠氼敇閻旈妯嗛梻?/ 婵炴垶鎸搁鍡樺垔?/ 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧梺鎸庣☉椤р偓缂佸彉鍗冲畷妤呭箮閼恒儻绱ㄩ梻浣哄亾瀹曟﹢鎯岄幆褜鍟呴柤纰卞墰閺?`false` 闂?闂佽　鍋撻柣鎰靛墯缂嶁偓 闂?
   *   閻?婵炴垶鎸堕崐鏍ь焽椤栫偞鐒鹃柟瀛樺笧閻熸繂銆掑顓犵畾缂?婵犮垼娉涚€氼噣骞冩繝鍥ㄧ劷闁挎繂瀚閬嶆煕閹烘梻甯涢柣鏍ュ€濋弻宀€浠﹂悙顒傜暢婵炲濮崑鎾斥槈? 闂?**婵炴垶鎸哥粔宕囨妞嬪孩灏庨柡宥忛檮瀹曟彃霉閿濆棙绀冩俊鐐插€归幆?*闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?`!isAlive` 闂備緡鍙忕徊鎯ь焽?*闂婎偄娲ら幊姗€濡磋箛鏃傗攳?*闂佹寧绋掗懝楣冩偩閻樿瑙﹂悘鐐靛亾椤ρ勭箾閹存繄澧涢悽顖楀亾"婵炴潙鍚嬫穱娲儊閽樺鏋栭柛鏇ㄥ墰绾偓"闂佺偨鍎查弻锟犲焵椤掍焦鈷愮痪顓犲Т椤疇绠涙惔锝囩崶闁荤姳璁查弲娆戠箔閸涱喚鈻旈柍褜鍓欓埢搴ㄦ晬閸曨偂鍖栭梺鍛婂灦濡叉帡顢氭导鏉戠?
   *    `isFreshSession = false` 闂佸吋婢橀惌渚€鎽?闂佽　鍋撻柟顖嗗懐锛炴繛鏉戝悑娣囨椽鎯?闂佸憡甯掑Λ娆撳极椤曗偓閺佸秹宕煎┑鍡楃彉濠电偛澶囬埀顒€鍟胯闂佹椿婢€缁鳖喚妲愬璺何?
   *    闂備焦婢樼粔鎾€冨鍫熷剭闁告洦鍋勯獮鎴﹀箹鐎涙ɑ绀€婵犫偓?`Index.beginOpenMorphOnClick`闂佹寧绋戝濉磂akClr` 闂備緡鍙忕徊鎯ь焽椤栫偞鍤婃い蹇撴噹婢у綊鏌ㄥ☉姗嗘Ф闁?
   * 闂佸疇娉曟刊瀵哥箔?婵?`.onDisAppear` 闂備焦褰冮惌鍌炲磻閸涘瓨鐒奸柟鍓х帛閿?*闂婎偄娲ら幊姗€濡磋箛娑樿Е閻忕偠鍋愰鍗炩槈閹垮啩绨婚柛銊ょ矙楠?*闂佹寧绋戦悧鍡涘箖閹惧鈻旈柍褜鍓濋妵鎰板閵忕姌锕傛煥濞戞ê顨欑紒妤€顦遍幏瀣矙閹稿骸鈧鏌涢幇顓犳噥缂佹柨鐡ㄧ缓钘壩旂€ｎ剛顦梺?
   */
  private morphSessionOughtToLive(isAliveAtUnmount: boolean = this.isAlive): boolean {
    if (!isAliveAtUnmount) {
      return false;
    }
    if (this.expandState.morphGeomReadyNow()) {
      return true;
    }
    return this.state.isShowPlay;
  }

  aboutToDisappear(): void {
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*"闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱 / 闂佺粯鍔楅幊鎾诲吹椤曗偓瀹曟骞庨懞銉川 / 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧?濠电偛澶囬崜婵嗭耿娓氣偓瀹曟繈濡歌閺?闂佹眹鍔岀€氼厼銆掗崜浣虹＜闁割偆鍠庨懙褰掓煙?*闂佹寧绋戦¨鈧紒?
    //   闂佸憡顭囬崰搴ゃ亹閻愬搫鍙?*闂佸搫鍟版慨闈涱焽椤栨稓顩烽棅顒佺ゴ閸嬫挻鎷呴崨濠傗偓杈ㄦ叏?*闂?`morphReset()`闂侀潧妫楅崐浠嬪焵?`morphReset()` 婵炴潙鍚嬮懝鐐濞戙垹鐐婃繛鎴烆殕椤愯棄霉濠婂喚鍎滅紒?
    // ```
    //     morphGen++                  闂?闂佸湱顣介崑鎾绘煛?`morphGenAlive` 闁诲海鎳撻悧鍡楃暦閼测晝鍗氶悗锝庝簻閻撴繈寮堕埡浣瑰婵犫偓?
    //     morphUsable = false         闂?闁?02/闁?04 婵烇絽娴傞崰鏍Χ娴犲鍎嶉柛鏇ㄥ灠娴滄繂鈽夐幘鎰佹Ц妞わ腹鏅濋埀顒傛嚀閻楀棗鐣锋總绋跨煑闁割偅绻傚鍧楀箹?
    //     morphSessionStarted = false 闂?闁?08 闂佸憡姊绘慨宄扳枔?闂佸搫鍊块。锔炬閹殿喗瀚?闂佸憡甯囬崐鏍х暤娴ｇ儤鍋栨い鎰剁到铦庨梺?
    //     morphGeomReady = false      闂?婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏃傚帶椤綁鏌?`pullGeomReady` 闂傚倸鍊堕崝蹇涳綖閿曞倸绀傞柛鎰级缁€鈧梺?
    // ```
    //   闂佸疇娉曟刊瀵哥箔?闂?*闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佸搫鍟抽鎰濠靛绫嶇憸搴ㄥ箰闁秴缁╁Δ锝呭暔閳ь剙顦遍埀顒€婀遍崑妯兼閵夆晜鍎?`aboutToDisappear` 闁诲繐绻愬畷顒€锕㈤鍛氦婵炲棗娴烽閬嶅级閻戝棗鏋﹂柟鐧哥秮楠炲秶鈧絺鏅濋娲煕濮橆剚鍞夌紒?*
    //   闂佹寧绋戦悧濠傦耿娴兼潙妫橀柛銉檮椤?`:4235` 闂佺厧顨庢禍婊呮崲娓氣偓瀹曟ê鈻庨幒鏃傜暫"闂佸搫鍊瑰姗€鎮块崟顒傜懝?`onAppear` 婵炴垶鎸哥€涒晛螞椤愩倐鍋撻崷顓炰粧缂?`onDisappear` 闂佸憡鍨规慨宕囩不椤曗偓瀹曘儳浠﹂懞銉ヮ潛"闂?
    //     `aboutToDisappear` 濠?`onDisappear` **闂佸搫娲ら悺銊ノ?*闂佹寧绋戦惌渚€鍩€椤掆偓婵傛梻绮?*濠电偛澶囬崜婵嗭耿娴ｅ湱顩烽悹浣哥－缁夎法鈧偣鍊栭崕鑲╂崲?*闂?
    //   闂?闁诲海鎳撻崯顖涗繆?*闂佸憡甯楅懝楣冨垂閺夋鍤堥柧蹇撴贡瑜板苯鈹戦崒婊勬珪婵炲牊鍨垮顒侊紣娴ｄ警浼囬柡澶屽剱閸犳洜妲愰幍顔藉珰?*闂佽桨鑳剁换婵嬫煂濠婂啨鈧帡宕ㄩ鑲╊伇闂?
    //     閻?`beginOpenMorphOnClick` 闂?`isFreshSession` 闂佸憡甯囬崐鏍х暤娴ｇ儤鍋栨い鎰剁到铦?闂?闁?闂佽　鍋撻柟顖嗗懐锛炴繛鏉戝悑娣囨椽鎯?闂備緡鍙忕徊鎯ь焽椤栫偛绀嗛柛鈩兩戦弳婊堟煥?
    //     閻?`settlePullOpen` 闂佹眹鍔岀€氼垵妫㈤梻浣瑰絻缁绘﹢骞楁總绋跨濠电姴鍊稿▓銈吤归敐鍡樼闁革絾妞藉畷鍫曟倷鐎涙﹢妾锋繛鎴炴煥椤戝懘骞冨Δ鍛櫖閻忕偠妫勭€氬霉閸忚偐顣叉繝鈧担鍦洸闁告繂瀚弲娆愮箾閹捐櫕鍣哥紒鏃€娼欓埢搴ㄥ煡閸涱垰鑰?
    //     閻?闁荤喐鐟ラ崐褰掑礉閸涱垯鐒婇弶鍫涘妽绗戦梺娲绘娇閸斿秹宕哄☉銏犵闁靛／鍕殸闂備緡鍙忕徊鑲╃箔娓氣偓瀵?闂佺偨鍎查弻锟犲焵?**闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱 / 闂佺粯鍔楅幊鎾诲吹椤曗偓瀹曟骞庨懞銉川 / 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧?闂備緡鍠涙慨銈夋儉閸涙潙瀚夊璺猴功濞堥亶姊?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鍕瘞**
    //       闂佹寧绋戦悧鎰板焵椤掆偓婵傛梻绮崒鐐茬濠㈣埖鍔曟禍婵嬫煛婢规嚎鍊楅悢鍛槈閹惧磭肖缂侇喒鍓濆?闂佸搫鍞查崘顏呮緰婵炴挻鑹鹃鍛暤韫囨梹濮?闂佹寧绋戦張顒佹櫠瀹ュ棛顩烽柕澶堝€楅閬嶆煟閳轰胶鎽犳い鎺撶矌閺侇噣妫冮埡鍐槴闂?
    //
    // ## 闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴顫㈢欢绫癷nk morphSessionOughtToLive}闂佹寧绋戦悧鍛箔娴ｈ濮滄い鏃囨硶濡叉悂姊洪幐搴ｆ噧闁诡喗顨堥埀顒冾潐濮樸劑鈥﹂崼銉︽櫖鐎光偓閳ь剟骞冩繝鍥ㄥ仺闁告鍋涢弲鎼佹煕閿斿搫濮傞柛瀣嚇閺屽苯鐣濈€ｎ剛顦?
    // ```
    //   !isAlive                闂?闂佹椿浜為崬瑙勵槹鎼达絿鐓佹繛瀵稿Ь濞夋稑鐣佃箛鏃€濮?闂?闂婎偄娲ら幊姗€濡磋箛娑樼哗闁绘劦鍓氱紞鈧梺鎸庣☉閻楁劗鎹㈤弽顓炵骇闁炽儴娅曢崐閬嶆煛閸愵厼鐓愮紒澶屽厴楠?婵炴潙鍚嬫穱娲儊閽樺鏋栭柛鏇ㄥ墰绾偓"闂?
    //   morphGeomReady          闂?闁哄鏅滈悷銈囩博鐎涙ɑ濮滄い鏃傚亾閸╁倿鏌ｉ妸銉ヮ仼婵犫偓椤忓牆绠?闂?缂傚倷鐒︾换鈧紒妤€顦甸幊妤呮嚍閵夈儮鍙洪梺?
    //   state.isShowPlay        闂?闂佹椿娼块崝宥夊春濞戙垹绠涢煫鍥ㄦ尰缁?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭枤閸ゅ鏌涢敂鍝勫闁活偄妫欑粙? 闂?闂佽　鍋撻柣鎰靛墯缂嶁偓 = 闂佺懓鐏氶幐鍝ユ閹寸姵鍋栨い鎰╁劚濞堟壆鈧鐡曟ご鍝ユ暜鎼淬劌妫?
    // ```
    //   闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鐢稿储濞戙垹瑙﹂幖娣€楀Σ鎼佸级?`morphUsable` 婵?`playerRouteStillPushed()`闂佹寧绋戞總鏃傛偖鏉堛劎鈻旀い蹇撶墕閸樻挳姊洪幐搴ｆ嚂缂佽鲸绻堝畷銏ゆ偄闁垮顦柣?
    //      `morphSessionOughtToLive()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍕槈閹绢垰浜炬繛鎴炴惄娴滄粓濡垫繝鍥х柧婵ǜ鍎崑鎾存媴妞嬪寒浼囨繛鎴炴惄娴滄瑧娆㈡搴㈠皫闁哄稁鐓堥弨閬嶆煛鐎ｎ偄鍔堕柣銊у枑閹棃鏁傞懖鈺冾槴闂?
    if (this.closeInstance === PlaybackPage.instanceSerial && !this.morphSessionOughtToLive() &&
      !(this.closeToken !== 0 && this.closeToken === PlaybackPage.closeOwner &&
      this.closeInstance === PlaybackPage.ownerInstance)) {
      this.expandState.morphReset();
    } else {
      Logger.info(PlaybackPage.logTag,
        'RzdMorphAboutToDisappear keep session (morphSessionOughtToLive: isAlive/showPlay/geom)');
    }
    ++this.lyricMorphGen;
    this.lyricMorphVisible = false;
    this.lyricChromeProgress = 1;
    this.applyKeepScreenOn(false);
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
      this.bannerClearTimer = -1;
    }
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 闂佺鐭囬崘銊у幀闂佸憡鐗犵紓姘跺吹濠婂牆绀夐柕濠忛檮閺嗩亪鎮硅椤ユ挸鈻撻幋鐘冲闁斥晛鍟ˇ褍鈽夐弮鍌氭灆妞も晪绠撳畷鎴濐煥閹邦喚鐛ユ俊鐐€楅弫璇差焽娴煎瓨鐒鹃柛濠勫枙濞夋彃霉濠婂啯锛旂紒杈ㄧ箞瀹曟岸顢曢姀鐘虫珒闁荤姳璁查弲娑㈡偩妤ｅ啫绫嶉悹铏瑰劋閻濄倗绱掑畝鍕窗婵?
    this.stopChromeAutoHide();
    // 婵炴垶鎸搁鍕博閺夋垟鏋庨梽鍥╂崲濮椻偓瀵?`aboutToAppear` 婵炴潙鍚嬪畝鎼佸闯閹间礁妫橀柟娈垮枤閺嬪倿鏌熺€涙ê濮堥柡浣告贡閹秆囧礄閵堝洨顦柡澶嗘櫆閻熲晠宕抽柨瀣窞鐎广儱瀚粔鎾煕濞嗘ü绨兼俊鎻掓啞缁嬪娼幍顔兼櫓婵炴垶鎸哥粔鍫曞汲閳ь剟鏌ら弶鎴犵濠殿喗鎮傞獮鈧?
    this.collapseProgress = 0;
  }

  /**
   * 闂侀潧妫楁總鏃傜博閹绢喗鈷愭繝濠傚暙閻撳倿骞栫€涙ɑ纾搁柍褜鍓欑粔鎾儓瀹ュ拋鍤曢柍褜鍓熷畷婵嬪Ω瑜庨弳浼存煥濞戞瑧顣插┑鈥虫啞濞艰鈽夊Ο渚敽婵?闂佽　鍋撻柟顖滃瀹?闁荤偞绋忛崕闈浳涢崸妤€绀?0闂?
   *
   * 闂佸綊娼ч鍡欐兜閸撲讲鍋撻悷鎷屽闁告瑥绻橀幃陇顦茬€殿噮鍓熼幊鎾诲礃閵娿倗鐭楃紓?MusicHome闂?*闂佸憡鐟禍鐐哄极?`height` / `translate` / `scale` 婵炴垶鎸搁ˇ顕€鏌屽鍫濇槬闁绘垶蓱閹烽亶鎮橀悙闈涗沪闁?*闂?
   * 婵炴垶鎸哥粔鍫曪綖椤愶絿顩烽悹浣哥－缁夎法鎲搁懜顒€鐏┑顔兼憸閹叉鎷呯粙娆炬⒕ 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕紞鈧紒鏃傚枛楠炴﹢顢橀悢鍛婃緬婵＄偑鍊曢崥鈧紒妤€鎳庨…銊╁箣閻愬瓨姣嗛柣鐘欏洦鏁辨俊鐐插€块幆?闁诲繐绻嬬欢姘焽娴兼潙鐭楁俊顖濇濮?闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棗娴烽悿鍕煕鐎ｎ偅鐨戞繛鍫熷灴閺?
   * `dismissSheetHeightPercent` + `coverLinearScale`闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲骞嬪鍕嫧闂佸憡鐟禍婵單ｉ幖浣哥濠电姴鍊归崐鍗炩槈閹绢垰浜炬繝闈涘€归〃澶屾崲濡粯鍎熼柨鏇楀亾鐎殿喕绮欏畷銉╁箣閿濆洨宕滄繛鎴炴尨閸嬫捇姊洪鈧粔鏌ュ焵?
   *
   * 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐悼缁犲綊鏌″鍛Щ婵ǜ鍔嶅鍕偄閸撲礁鏅╅梺鎸庣⊕閼归箖宕€电硶鍋撻崷顓熷殌闁?`justifyContent(FlexAlign.End)` 闁荤姵鍔曢顓烆焽閸愨晜鍎熼柡鍥风磿閻濆爼鏌?
   * 婵°倕鍊归敋閻庣娅曠粋?闁荤姵鍔栧娆戣姳閾忣偆鈻旈柍褜鍓熷?闂傚倵鍋撻柛顭戝枛閻?100% = 婵炲濮存鍝ヨ姳閹惰姤鐒鹃柕濞垮劜閸婅鈽夐幘绛硅含闁逛粙娼ч…銊╁煡閸涱垰鑰块柣蹇撶箣缁舵艾顭囨导瀛樺仺?`layoutWeight(1)`闂?
   * 婵°倕鍊归敋閻庤濞婂畷锝呂熼搹瑙勭槗闁诲海鎳撻崯鎶藉吹濠婂喚鍟呴柛妤冨仦閻ㄦ垿鏌涘▎鎯奉亪鎯冮鍕櫖閻忕偠鍋愰懝楣冩煛?闁诲繐绻嬬欢姘焽娴兼潙绠為柕蹇娾偓鍐茬睄闂佸憡鐟﹂敋闁?婵炴垶姊婚崰宥囩博鐎靛憡灏庨梺鍨儐闂勫秴霉濠婂啯顥撻柍?
   */
  private playExpandIntro(): void {
    // 闂?**缂傚倷鑳堕崰宥囩博閹绢喖绀傞柕澶堝劚缂?+ 闂佸搫鍟版慨鐑藉疾椤愩埄鍤曢煫鍥ㄦ尭楠炴垿骞?*闂佹寧绋掔喊宥嗘櫠瀹ュ瀚夊璺侯儏閳數鈧鍠掗崑鎾绘煛閸屾粍鍤€缂佹唻绻濋弫宥夊醇閵忕姳鍖栭梺鍛婂灦閻綊鍩€椤戞寧绁伴柟鐧哥秮楠炴﹢顢橀悢宄邦棈闂佹悶鍎伴崟姗€鍩€椤戞寧顦风紒妤€鍊块獮蹇斿緞鐎ｎ偆绻侀梺褰掓涧椤戞垹妲愬鑸电劸闁瑰瓨甯為惌銈夊级閳哄倻鎳囬柛锝夋敱濞艰鈽夐弽銈呬壕?
    //   閻?闂佸綊娼ч鍡欌偓鍨壘椤垽鏁愰崨顔垮惈婵＄偟鎳撳畷顒佹叏?闂?闁荤姳璁查弲婵堝垝娴兼潙绠ラ悗锝庝簻閳笺垽鏌?
    //   閻?婵炴垶鎸堕崐妤咁敂椤掑嫭鐓ユ慨妯哄船娴狀垶鏌ㄥ☉妯煎ⅲ缂侇垳濮甸幏鍛存偐閾忣偉鎷柣蹇撶箣缁舵艾顭?+ 闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺〒濞堥亶姊婚崼顐ｇ窙缂佽鲸宀搁弻鍫熺鐎ｎ亝顏￠梺鍛婂浮椤ｏ妇鑺?闂?闁荤姍鍕凡闁奸晲鍗冲畷锝咁潨閸垻顦ーtryStartMorphIntro`闂佹寧绋戦¨鈧紒?
    //   閻?闁哄鏅滆摫闁汇儱鎳忛‖鍥箛閸撲胶顦╅梺缁樺姉閹虫捇宕甸鈧弻鍥晲閸曨収浼囬梺鍛婂笧缁垶骞愰柆宥呯哗濡わ絽鍟ㄩ埀顒€顦靛畷姘潩椤撶偟妲搁柡澶屽仜椤洟鍩€椤戣法顦﹂柣銊︾箞濡啴濮€閿濆洨顔庡┑鐐插閳ь剙纾鎾倶閻愨晛浜鹃柣搴ｆ嚀閻妲愬璺虹劶?**闂備焦褰冪粔鐑芥儊椤栫偞鍤愰柕澶堝劚閸欙繝鎮?*闂?
    //     闁诲簼绲婚～澶愭偉閿濆绫嶉柣妯虹仛濞?`beginMorphEnter` 婵犮垺鍎肩划鍓ф喆閿曞倸绫?濠电偛顦崝宀勫船?onPullReady 缂備焦绋戦ˇ顖氼潩閵娧呯＜?闂佹眹鍔岀€氼剚绂掑☉妯锋灃闁哄洦菤閸?
    //
    // 闂佸疇娉曟刊瀵哥箔?闂佸憡甯囬崐鏍х暤娴ｇ晫鐤€闁告稒鐣埀顒€绻樺?*婵炴垶鎸堕崐妤咁敂?*闂備焦瀵у銊╁磻閿濆鏅柛褍鍩搊rphIntroAnchorsReady`闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪顓奸崼婵嗗箣闂佸憡鐟禍婊堝垂?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩鍙夘仭闂佸憡甯￠。锔捐姳?闂?
    //    缂傚倷绀侀悧蹇涘磻閿濆鏅柛顐ゅ枑鐏忥繝鏌￠埀顒併偅閸愶腹鍋撴径灞肩剨濞撴埃鍋撴繛闂村嵆閺佸秵寰勭€ｎ剚鈷曢柣蹇撶箺娴滎剟宕℃惔銊ョ睄?`endCoverSize = 0`闂佹寧绋戦惉濂告偨缂佹﹩妲归柣鎰皺濞堥亶姊婚崼娑樼仾闁绘鎸冲鐢割敄鐠恒劎鎲规繛鏉戝悑濮樸劑寮?
    //    闂佹寧绋戝濉祇rphBridging()` 婵?false闂佹寧绋戦¨鈧紒杈ㄧ箞閹虫挾浠﹂悙顒€鍟婇梺琛″亾濡わ絽鍟ㄩ埀顒€顦甸幊娑㈩敂閸曨厾鐣抽梻渚囧弿缁茬晫妲愰崜浣风剨濞撴埃鍋撴繛闂村嵆瀵?闂佽В鍋撻柟瀛樺笧缁夋挳鏌熼棃娑毿ゆ?闂佺偨鍎查弻锟犲焵?
    //    婵炲瓨绮岀€涒晛危閸涘﹤绶炵紓鍫㈠Х椤忓崬鈽夐幘鍗炩偓鏍敃閼测晙娌柡鍥╁仧绾惧鏌ｉ妸銉ヮ伂妞ゎ偄娲獮鍥偄闁垮娈ら梺?闂佺粯鍔楅幊鎾舵閹达箑鐒奸柟鍝勭Ф閻棗鈽夐弬璺ㄥⅵ闁稿繑锚閳讳粙鍩勯崘鈺冪暢闂佹剚鍋呯敮鎺楀汲濡崵鈻旈柍褜鍓氱粙澶屸偓锝庝簻閻撳倸霉?闂?
    //    闂佸憡绮岄惉濂稿极閵堝绠ｉ梺鍨儏椤矂鎮归崶褜妲烘繛?闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闁哄鏅滆摫婵″弶鎮傚顔款槻濠殿喒鏅犻幃?闂佸憡鍨规慨宕囩不椤曗偓瀹曟岸宕遍弴鐘垫喒闂佸憡鍨归崕銈咁焽閻㈢违?
    if (this.tryStartMorphIntro()) {
      return;
    }
    if (this.morphRetryLeft > 0) {
      this.morphRetryLeft--;
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready, retry (left=${this.morphRetryLeft}) ` +
        `usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()}`);
      setTimeout((): void => {
        if (this.isAlive && !this.isClosing) {
          this.playExpandIntro();
        }
      }, PlaybackPage.MORPH_RETRY_MS);
      return;
    }
    // 闂?闂備焦褰冪粔鐑芥儊椤栫偞鍋ㄩ柕濞垮劜閺?闂?**闂佺儵鏅涢悺銊ф暜閹绢喗濯伴柟瀛樺笧缁夋挳鏌ㄥ☉妯肩伇缂侇噣鏀辩粙澶婎吋閸℃ê鍟婇梺濂割暒缁€浣规叏閳哄懏鍋?*闂佹寧绋戦悧鍡涱敋椤曗偓瀵粙宕惰閸愨偓缂傚倸鍊归悧鐐烘儊瑜旈幆?`setFinalStatus()`闂佹寧绋戦¨鈧紒?
    //   闂佸憡鐟ョ粔鍓佹椤忓棙瀚?`setupExpandTransition` 闂?`expand.init(...)` 闁哄鏅滈弻銊ッ?false 闂佹眹鍔岀€氼剟宕㈢憴鍕劅闁哄洨鍋為惃鎴︽煛?
    //   "闂佽　鍋撻柟顖嗗懐锛為梺鍛婃煟閸斿酣寮ィ鍐ㄎュù锝囧劋缁绢垶鏌熼幁鎺戝姤闁诡垬鍊栭幏?闂侀潧妫楅崐鍧楀焵椤戣棄浜鹃梺鎼炲劤閸嬫盯鐛幘璇茬?闂佸憡锚椤戝棙鏅舵惔銊ョ闁告侗鍙庨崯鍥倶閻愭彃鈧潡鎮甸鑺ュ劅?闂備緡鍙忕徊浠嬨€冨鍫熷殌濞达絿顭堣闂佹眹鍨荤划顖毼?*闂佺懓鐡ㄩ崹鐟扳枔閹达箑鐭楅柟瀵稿仦椤?*闂?
    //   婵炴垶姊婚崰鎰邦敆濠婂牆鍙婃い鏍ㄧ矋閺嗗繘鏌熼弶鎴濇Щ鐎殿喛濮ゅ鍕吋閸涱厼鍞ㄦ俊顐到閻楀繐鈻?闂佺粯鍔楅幊鎾诲吹?闁哄鏅滈弻銊ッ洪弽顓熷仺闁靛ě鍕殸闂佸搫瀚烽崹鍗炍涢锕€绀夐柕濞у嫭姣?闂佹眹鍔岀€氼厼顭囬棃娑掓敠闁规壋鏂侀崑?
    Logger.error(PlaybackPage.logTag,
      'expand intro: anchors never became ready, landing without animation (setFinalStatus)');
    this.expandState.morphReset();
    this.expandState.morphSettleOpen();
    // 闂佸搫鍟版慨瀛樻叏閳哄懏鍋ㄩ柡鍕箲閸庢澘霉閿濆懐小缂佲€冲暢缁犳盯宕ㄥǎ顑藉亾韫囨搩鍤曢柍褜鍓熷濠氣€﹂幒鏃傤槷闂佸憡鐔粻鎴﹀垂椤栫偛鏋侀柟缁㈠枔閳ь剙顦扮€电厧顫濋銈庝紘闂佺儵鏅滃娆愮閻樿鎹?婵炴垶鎸哥粔鍫曞极?闂佹眹鍔岀€氼喗鎱ㄩ幖浣哥畱濞撴艾锕︾粈鍕煙閸偅灏紒妤€顦锝夊焵椤掑嫬绠绘い鎾跺枑閺夌懓顪冮妶鍥舵殰缂?
    this.introPaintReady = true;
    this.collapseProgress = 0;
    this.expandIntroRunning = false;
  }

  /**
   * 闁诲繐绻戠换鍡涙儊椤栨粍灏庨柡澶庡劵閸╁矂鏌涘▎鎯奉亪鎯堝鍜佸殨闁逞屽墰閹瑰嫰顢涘杈╃嵁闂佹寧绋掑畝鎼佸闯濞差亝鐓ユ慨妯哄船娴?闂?闁哄鏅滅粙鎾趁规径瀣?闂?闁荤姍鍛効閽樼喖姊婚崒娑氭殬闁?
   * @returns true = 閻庤鐡曠亸娆戝垝閿熺姴绠板璺猴龚閸╁矂鏌涘▎鎰电劸闁活厽鍎抽銉╁礋椤愩倗锛涙繝娈垮枛椤戞垹妲愬▎鎴炲闁告劦浜濋弳蹇涙煛閸岀偐鍋撳☉姘辨喒闁荤喐娲戠粈渚€宕埀顒勬偣瑜庢刊浠嬪焵椤戞寧绁伴柣顓熷劤椤曘儵宕熼崜浣侯槴
   */
  private tryStartMorphIntro(): boolean {
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER) {
      // 闂佸綊娼ч鍡欌偓鍨壘椤垽鏁愰崨顔垮惈婵＄偟鎳撳畷顒佹叏閳哄懏鏅慨妯虹－濞堝崬鈽夐弮鍌氭瀻闁糕晛妫濋獮搴綖椤旀儳鑰跨紓鍌欑劍閿氶柛鈺傤殜濮婂濡搁妶鍥╂婵炴垶鎸撮崑鎾搭殽閻愯泛鐓愰柡鍌欒兌閹澘鐣濈€ｎ剛顦╅柡澶嗘櫆閻燂箑顭囬婊勫磯妞ゆ牗鐟ч悷婵嬪级閳哄倻鈼ョ紒妤€鎳樺Λ鍐閵忥紕鏆犻悗娈垮枓閸嬫捇姊婚崒妯哄闁搞劌閰ｅ銊╊敍閵堝洨顦?
      // 婵☆偓绲鹃悧妤咁敃閸忚偐鈻斿┑鐘插暙椤庢瑩鏌ｉ妸銉ヮ伀婵炶弓鍗冲浠嬪炊瑜忓В锝夋煛閸偂绨荤紒鏃堫棑娴狅箓鍩€椤掑嫬绫嶉柡鍫㈡暩閻繂菐閸ャ劎绠栭悗鍨閺屽懓绠涢弮鈧～鏍煕韫囧濡奸柡鍕€婚埀顒傛暬濞艰崵妲愬┑鍫熷仒闁靛鏅涘▍銈夋煙鐎涙ê濮囧┑顔界洴瀹曟ê顓奸崱妯绘緬闁荤偞绋戠悮顐﹀焵?
      this.introPaintReady = this.expandState.morphUsable;
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
      return true;
    }
    this.expandState.pullDragging = false;
    // 闂?闂佸憡甯囬崐鏍х暤娓氣偓瀵?*婵炴垶鎸堕崐妤咁敂椤掑嫭鐓ユ慨妯哄船娴狀垶姊洪鑽ょ煓缂?*闂佹寧绋戝濉祇rphIntroAnchorsReady`闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪顓奸崱妯?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩鍙夘仭闂佸憡甯￠。锔捐姳?闂?
    //   缂傚倷绀侀悧蹇涘磻閿濆鏅柛顐ゅ枑鐏忥繝鏌￠埀顒併偅閸愶腹鍋撴径灞肩剨濞撴埃鍋撴繛闂村嵆閺佸秵寰勭€ｎ剚鈷曢柣蹇撶箺娴滎剟宕℃惔銊ョ睄?`endCoverSize = 0`闂佹寧绋戦惉濂告偨缂佹﹩妲归柣鎰皺濞堥亶姊婚崼娑樼仾闁绘鎸冲鐢割敄鐠恒劎鎲规繛鏉戝悑濮樸劑寮?
    //   闂佹寧绋戝濉祇rphBridging()` 婵?false闂佹寧绋戦¨鈧紒杈ㄧ箞閹虫挾浠﹂悙顒€鍟婇梺琛″亾濡わ絽鍟ㄩ埀顒€顦甸幊娑㈩敂閸曨厾鐣抽梻渚囧弿缁茬晫妲愰崜浣风剨濞撴埃鍋撴繛闂村嵆瀵?闂佽В鍋撻柟瀛樺笧缁夋挳鏌熼棃娑毿ゆ?闂佺偨鍎查弻锟犲焵?
    //   婵炲瓨绮岀€涒晛危閸涘﹤绶炵紓鍫㈠Х椤忓崬鈽夐幘鍗炩偓鏍敃閼测晙娌柡鍥╁仧绾惧鎮樿箛姘跺摵婵?闂佺粯鍔楅幊鎾舵閹达箑鐒奸柟鍝勭Ф閻棗鈽夐弬璺ㄥⅵ闁稿繑锚閳讳粙鍩勯崘鈺冪暢闂佹剚鍋呯敮鎺楀汲濡崵鈻旈柍褜鍓氱粙澶屸偓锝庝簻閻撳倸霉?闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎戞繛?缂備焦顨忛崗娑氱博閺夋垟鏋庨柍鈺佸暟濮婇箖鏌￠崼婵愭Ц闁汇劍绻堝Λ鍐閵堝孩锛囬梺?闂佹寧绋戦ˇ顓㈠焵?
    //
    // 闂?婵＄偑鍊曢幖顐よ姳椤撱垺鍋?`prepareMorphEntry` 闂佹悶鍎遍幖顐︽偩妤ｅ啯鏅?*婵炶揪绲剧划宀€鑺遍崜褏纾奸柛顐犲灩娴?闂?闂侀潻璐熼崝宀€鏁銈勭剨闁告繂瀚烽崵鐔兼煛閸愩劎鍩ｉ柛?闂?闂佸憡鍔曠粔瀵告暜閸ヮ剙绀嗛柟宄版湰瀹曟娊鏌?*闂?
    //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯?*闂佽桨绀侀幊蹇涘礈閻楀牏鈻旂€广儱鎳嶇划?`alreadyRunning` 婵炴垶鏌ㄩ鍥╂偖椤愶附鍎嶉柛鏇ㄥ幘閸欐岸鎮?*闂佹寧绋掗惌顔剧博閹绢喖绫嶉柨鏂垮⒔閸欐岸鎮规笟顖氱伈缂佽鲸绻勬禍鎼佸矗濡偐鐛ラ梺?
    //      "缂傚倷绀侀悧蹇涘磻閿濆拋鍟呴柛娆忣槹缁犳帡鏌曢崱鏇燁樂缂佹煡绠栧鐢割敆閸愵亝鐎柡澶嗘櫆钃遍柣銉ユ噺濞艰鈽夊鍛暫閻熸粏鍩囬崹纭呫亹?闂佹眹鍔岀€氼亪鎳欓幋锔解拻閻庢稒菤閸嬫挻鎷呮搴ｆ啴闁荤姴鎼悿鍥╂崲閸愵喖鍌ㄩ悗锝庡幗瀹曟娊鏌ｉ幇顔筋仧缂?
    //      婵炲瓨绮岀€涒晛危?`collapseProgress`/闂傚倸鍊堕崝搴㈡叏閹间礁绠戝ù锝夘棑閻熴垽鏌ｉ埡鍛珳缂傚秴鎳愰埀顒傛暬閳ь剚绋撻悷婵嗏槈閹炬剚鐒鹃柍褜鍓欓崐鍝ョ不閹惧墎椹冲鑸靛姇濞呫垽鏌涜箛瀣姕婵℃彃鎽滈埀顒傛嚀椤︻垶宕ｈ箛娑欏剭闁告洍鏂侀崑?
    //   婵炴垶鎸搁敃锝囩博閹绢喗鍋嬮柛顐犲灪閻?bug 濠殿喗绻愮徊钘夛耿椤忓懏浜ゆ繛鍡樻尭濞咃繝鏌ㄥ☉娆戠叝缂傚秵姊归幆鏃堟偄瀹勯澏妤€霉閿濆棛鐭庢い顐畵瀵劑骞嗚闊?`morphBeginEntering()` 闂佸憡鍔曢幊姗€宕曢幘顔芥櫖?
    //   濠殿喗绻愮徊浠嬪Χ娴犲绠┑鐘插€搁悘鐘绘⒑閹绘帞绠伴柛鈺佺焸閹啴宕熼鐘电厜闂佺粯鍔橀～澶嬫叏娴犲绠?闂?闂備焦褰冪粔鐑芥儊椤栫偛瀚夐柣鏂垮槻鐎氬鎮跺☉鏍у姍缂佹顦靛畷鍫曟倷鐎涙﹢妾烽梺鎸庣☉濞煎〉orphLive()` 闂佸綊娼荤槐鏇烆焽閸愵喗鏅?
    //   闂?闂備焦褰冪粔鐑芥儊椤栫偞鍋ㄩ柕濞垮劜閺呭ジ鏌￠崘顏勑㈠┑顔规櫊閹粙寮拌箛鏂垮姍婵?闂?**闂佺粯鍔楅幊鎾诲吹椤旂偓宕夋い鏍ㄦ皑缁愮偛霉閻樻彃顒㈡繛濂告涧閳讳粙妾辩紒缁樕戝?`playMorphOpenIntro()`**闂?
    if (!this.expandState.morphUsable) {
      return false;
    }
    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍡椕洪弽顓熺劵闁逞屽墴瀹曘儲鎯旈妸銉︻仧闂佺顑嗛悢顒傛?*婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箥濡棝姊婚崼娑樼伇妞も晪绠撳畷鐘诲川椤掑偆浼囬柣?`UIUtils.applySync`**闂?
    //   `prepareMorphEntry` 闂佹眹鍔岀€氼厼銆掗崼鏇炶Е閹煎瓨绻勯杈ㄦ叏濠靛嫬鍔滄俊?闂佺娉涢敃銈夊吹閹寸偞濯撮柡鍥╁仜缁旈箖鏌涢幒鎾愁€滈柟鐧哥秮閹?闂佹寧绋戝濉plyMorphProgress(0)`闂佹寧绋戦¨鈧紒?
    //   缂備焦鐦遍崟顐㈩槻闂佹椿鍋€閸?*闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳暞瀹曟煡鏌涢弮鎾剁瘈闁?*闁诲繐绻楃划楣冨箲閿濆洦鍋橀柕澶嗘櫆閿涚喖鏌曢崱妤€鈧粙鍩€?V2 闂佹眹鍔岀€氼喗鎱ㄩ幖浣哥畱濞达絿顭堢紞渚€姊洪幓鎺旂闁逛究鍔戝?*婵炴垶鎸哥粔宕囨閹殿喚鍗氶悗锝庝簻缁侇噣鏌″鍛┛闁?*闂佹寧绋戦悧濠冩叏?Promise 閻庣敻鍋婇崰鏇㈠箲閵忋倕绀夐柍钘夋噽缁€鍡涙煥?
    //   `animateTo` 闂佸憡顨堢换婵堟?*缂備焦鏌ㄩ鍛村春閵忋倕绀嗛梺鍨儐閻撯偓閻庡湱顭堝鍫曟偉閿濆鍤囬煫鍥ㄨ壘铻￠梺缁樺姌椤顭囬悽绋跨闁告劘灏欓弳浼存煕閺傝濡介柡鍛劜閿涘啴寮借婵?* 闂?闂佸憡锚椤戝牓骞戦敐澶嬪€风憸鐗堝笒娴滄繂鈽夐幘顖氫壕婵?*濠电偛鐭夌槐鏇㈠极閹捐鏋?*闂佹寧绋戦惌鍌炪€呴懡銈嗘殰鐟滃繘寮妶澶婄睄鐟滃秹鍩€椤掑偆鍎犻柍?
    //   闁诲氦顫夎摫闁哄瞼鍠栭弫宥夊锤閸掔劋kts-new-applysync-flushupdates-flushuiupdates`闂佹寧绋戦ˇ鏉课ｉ幋鐘冲厹妞ゆ梹顑欏鎰版倵鐟欏嫪浜㈢紒缁樼墱缁?
    //   "闂佸憡鏌ｉ崝宥夊疾閵夆晛绀堢€广儱妫欑粻鎺懳涢悧鍫㈢畵妞わ妇绮粚閬嶎敊閼恒儲姣?闂佹眹鍔岀€氼剙鈹冮埀顒勬煛閸滀礁鐏ユい鈺嬬畵閹?`UIUtils.applySync` 闂佸憡鑹鹃張顒勵敆閻愬搫绀嗛梺鍨儐閻撯偓闂佸憡鑹炬鎼佸疮閳ь剟鎮硅閸㈠弶鎱ㄩ埡鍛仺?闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕傤敆濠婂牆鍙?
    //   "闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佸憡绮岄張顒佹櫠濠婂牆绠伴柛銉ｅ妼閻濇盯鏌涢弬璇插濠⒀嶇畱椤曪綁鍩€椤掑嫬鍙婃い鏍ㄧ懆閳峰牆鈽夐幙鍐х盎濠殿喒鏅犻幃?闂佹眹鍔岀€氼喚鍒掗妸鈺佸嚑闁告洦鍏橀崑鎾诡槼闁绘鎸冲畷鍫曟偑閸涱垳顦?0ms 閻庣偣鍊栭崕鑲╂崲?闂備焦褰冪粔鐑芥儊?缂傚倷鐒﹂敋闁糕晜顨婂濠氬Ω閳轰礁骞嬮梺鍝勫閸ㄤ即鎮鹃悩缁樺剭闁告洦鍟熸径瀣枖濞撴艾锕︾粈鍡涙煏?
    //   闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯顐ャ亹瑜忛幉鎾晲閸涱厽鐎?*闂佸搫绉村ú鈺呭礈?*闂侀潧妫斿鎺旂箔婢跺本鍠嗛柨婵嗘噹閺嬧偓**闁汇埄鍨伴崯顐︽儑?*闂佹寧绋掑銊╂偤閹寸姳鐒婂〒姘ｅ亾婵為棿鍗抽幊鐐哄磼濠婂啩鍖栭梻浣瑰絻缁绘劗娆㈤柆宥呯濡鑳堕惌婵嬫煟閹烘挸鍔舵い鈺嬬畵濡啴鎮╂潏鈺冩啰闂傚倸鐗勯崹璇测枔閹达附鐓傜€广儱鐗忓Σ鍝ョ磼閹邦収娈旂憸鐗堢洴婵?
    let prepared: boolean = false;
    UIUtils.applySync((): void => {
      prepared = this.expandState.prepareMorphEntry(this.getUIContext(), true);
    });
    if (!prepared) {
      // 婵烇絽娲︾换鍕汲閳ь剟鏌￠崼顐㈠⒉闁汇倕妫涙禍鍛婃綇閳轰礁纾块梺缁橆焾閸╂牠鍩€椤戣法绛忕紒杈ㄧ箘缁灚寰勬繝鍕€€婵炴垶鎸搁鍕博閺夋垟鏋庨柍銉ュ暱閺傃囨倶韫囨挻鎯堟い鏇ㄥ幘閺侇噣宕橀妸褎鎷遍梺鎸庣☉婵傛梻绮径鎰嵍闁靛ň鏅涘▍銏ゆ偣閸ャ劍绀嬫俊顐㈡健瀹曘垻鈧綆鍓涚槐?婵犮垼娉涚粔宕囩礊閸涱垱鏆滈柛鎰╁妿濠€浼存煏?
      return false;
    }
    if (!this.expandState.morphIntroAnchorsReady()) {
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready ` +
        `(usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()})`);
      return false;
    }
    // 闂佸憡鍨规慨宕囩礊瀹ュ洣鐒婇弶鍫氭櫅瀹曟洟鏌ㄥ☉娆掑缂佽鲸鍨垮濠氣€﹂幒鏃傤槷闂佺绻嬪ù鍥敊韫囨洜纾兼俊顖氭惈閻撴垿鏌ㄥ☉妯煎妞ゆ帗绻堝顔炬崉閸濆嫬娈ョ紓鍌欑缁绘垵危?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹婵炴垶鎸撮崑鎾绘倶韫囨挾绠版繛?闂佹眹鍔岀€氼垶骞戦敐澶嬪€烽悷娆忓閸嬫挻绗熸繝鍕槴
    this.introPaintReady = true;
    this.expandIntroRunning = false;
    this.collapseProgress = 0;
    this.playMorphOpenIntro();
    return true;
  }

  /**
   * 闂佸ジ顣﹀ù鍥儗閹屽殫闁告洖澧庣粈鍕煕閹寸姴小缂傚秴绉撮埢浠嬫晸閻樺弶顏￠梺鍛婂笧婢ф顪冮崒鐐村剭闁告洦鍋勯獮鎴﹀箹鐎涙ɑ绌跨紒杈ㄥ哺閺佸秴顫濋鈧弫鍫曟倵閸︻厽鍤€闁活亝澹嗛幏鍦偓闈涙啞缁插骞栫€涙ɑ绀夌紒鏃傚枛閺佸秴鐣濋崟顓炶拫闁硅壈鎻紓姘卞垝?闁荤姵鍔栧娆戣姳閾忣偆鈻旈柍褜鍓熷?闂傚倵鍋撻柛顭戝枛閻?100%闂?
   *
   * 闂佸憡鐟禍婊冿耿?`morphUsable === false` 闂佸搫鍟抽崺鏍ㄦ櫠閻樺啿顕辨慨妯虹枃濞夋煡鏌涢幒鎾愁€滅紒缁樼墵閺?闂佺偨鍎查弻锟犲焵?濠殿喗绻愮徊浠嬫偉閸洖绠氶柛娑卞幖閺嬪矂鏌ㄥ☉妯煎ⅲ缂侇垳濮甸幏鍛存偐閾忣偉鎷梺闈╄礋閸斿﹪鍩€椤戣法顦︽い鏃€鐗楃粙澶屾嫚閹绘帒娈ラ梻浣瑰絻缁绘劙宕哄畝鍕櫖?
   * 婵炴垶鎸撮崑鎾垛偓鍨緲椤戝牓鎽傜€ｎ厹浜归柕蹇曞Т缂嶄線姊洪銊хɑ婵炵⒈鍨抽幑鍕敍濡嘲浜?
   */
  private playLegacyExpandIntro(): void {
    try {
      // 闂備緡鍋呴崝鏇㈠储閹捐埖顫曢柣妯虹枃缁愭鏌涜箛瀣姢闁?*闂佸搫鐗滈崜鐔煎Υ婢舵劖鍤婃い蹇撴噹閻?*闂佹眹鍔岀€氼垳鎹㈠Ο缁樺劅闁挎棁鍋愮粈? = 闁荤姵鍔栧娆戣姳閹惰棄缁╅柟顖滃瀹?闂?0 = 闁诲海鎳撻懟顖炲矗韫囨洑娌柡鍥╁仧绾惧鏌ㄥ☉姗嗘缂佽鲸绻冪粙澶嬫償閵娧冭拫闁硅壈鎻粻鎺曟＂闂傚倸鍊瑰娆撳箖閹捐埖灏庣€瑰嫮澧楅崐閬嶆煢閳ь剚鎱ㄩ幇銊ヤ壕?
      // 闂佸疇娉曟刊瀵哥箔?闂佸憡甯炵划顖炲礈閻楀牏鈻旂€广儱鎷嬪Σ濠氭煟椤剙濡奸柛娆屽墲缁?`PlayerExpandState` 闂?preparing/animating 闂佺儵鏅犻弲鑼礊閸涘瓨鏅?
      //    闂備緡鍙忕徊浠嬨€冨鍫熷剮闂傗偓閹邦喚孝闂佹眹鍔岀€氼噣鎮块崱妯诲鐎广儱娲ゆ禒顖炴煕閿斿搫濮傞柛锝嗘倐瀵悂宕熼鍥у箑闂佺绻堥崝瀣槈椤忓懐顩查柛鈽嗗幘缁€澶愭煙閹帒鍔欑紒妤€鍊垮畷銏㈡嫚閹绘帗閿繛鏉戝悑閼瑰墽娆㈤柆宥呯濡娴囬埛鍫㈢磼婢跺﹦孝婵炲吋鐗滅槐鎺楀箻鐎甸晲鍑?闂佺偨鍎查弻锟犲焵?
      //    闂侀潧妫楅張顒佺閻ｅ本灏庡ù鐓庣摠婵粓鏌涢弬璇插闁轰線绠栧畷姘跺幢濡粯娈?闂?濠电儑绲洪埀顒€鍟垮宕囩磼濞戞﹩妲风紒顭戝墮閳讳粙鍨鹃崘鍙夋闂侀潧妫楃粔鐢稿垂閵娾晛违閻忕偛澧介崹濂哥叓閸ヮ煈娈曢柣锝庡亰閹?闂?闂佽桨鐒﹀娆忣焽閿熺姴绀冮柛娑卞弾閸熷洨绱掗悩鎰佹畷闁搞劍宀搁弻鍛扮疀閺冣偓椤牠鏌ㄥ☉妯煎闁汇劍绻堝Λ鍐閻樻彃寮楀┑鐑囩岛閳ь剝娅曢崐鍨箾閹存繄澧曢柕鍥ㄥ灴婵″瓨鎷呯憴鍕啋婵＄偑鍊楅弫鎼佸煘閺嶎厽鍎岄柡鍌樺€楃粈鍡涙煏閸℃袪闁?
      //    闂佸搫鐗滈崜鐔煎Υ婢舵劖鍤婃い蹇撴噹閻?+ 闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夆偓娑滃焻闁哄鏅滈弻銊ッ?1闂佹寧绋戦懟顖氼潩閵婏妇鈻旂€广儱鎳愰幗鐘绘煕閿斿搫濡介柣锝庡亰閹儳鈻庨幇銊ヤ壕濞达絿顣介崑?
      this.expandIntroRunning = true;
      this.getUIContext().animateTo({
        duration: PlaybackPage.EXPAND_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        this.collapseProgress = 0;
      });
      setTimeout((): void => {
        if (!this.isAlive) {
          return;
        }
        this.expandIntroRunning = false;
      }, PlaybackPage.EXPAND_DURATION_MS + 30);
    } catch (err) {
      // 闁荤偞绋忛崕闈浳涚捄銊﹀皫闁炬艾鍊婚悷婵嬫煛婢跺牆鍔氭慨妯稿妿缁晝鈧綆浜滈悡婵嬫煕閵壯冧粶闁糕晛鐬奸埀顒傛嚀閺堫剟寮抽敐澶婄畱濞撴艾锕﹂獮銏ゆ煟椤忓嫷鍎旀俊顐墴閹亜螖娓氬洤濡伴梺鍝勫暞閸庤偐鎹㈤弴鐐╂煢闁炽儱鍟块悡鍌炴煟閹邦喗顏熺紒杈ㄧ箞瀹曟岸顢曢妷顔兼暏婵＄偑鍊楅弫璇差焽娴兼潙纾绘繝濠傚暞闊?闂佽　鍋撻柟顖滃瀹?闂備緡鍙忕徊鑲╃博閹绢喖绾ч柍銉ㄥ皺閻?
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `expand animateTo failed code=${e.code} msg=${e.message}`);
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
    }
  }

  /**
   * 闁诲骸婀遍幊鎾斥枍閹烘洏浜归柕蹇曞Т缂嶄線鎮规笟顖氱仩缂佸墎鍋ら幆鍐礋椤愩倖缍岄悗娈垮枓閸嬫捇鎮跺☉鏍у姦婵☆偄娼￠弫宥咁潩椤掆偓濞堛倕霉閿濆棙绀€婵犫偓?`aboutToAppear` 閻庤鐡曠亸娆戝垝閿熺姴鍌ㄩ悗锝庝簻閻撳倿鎮硅椤ユ捇宕戦敐澶嬫櫖闁?= 0闂?
   * 婵炴垶姊婚崰搴☆潩閵娾晛鍙?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹闂佸搫顥￠妶鍛腐闂?闂佹寧绋戦¨鈧紒杈ㄧ箖濞艰鈻庨幘铏仦闂佸憡鐟禍婵囦繆閸濄儮鍋撻悷鏉挎殲閻㈩垰缍婂畷?1闂佹寧绋戦悧鎾诲箺闂堟侗鐓ラ柍钘夋噽缁€鍡涙煏?
   *
   * 闂佸疇娉曟刊瀵哥箔?`animateTo` 闁荤偞绋忛崕鍐测枔閹达箑鍙?*闁诲繒鍋熼崑鐐哄焵椤戭剙鍟犻崑?*闂佹寧绋戝鍍le / translate / height / borderRadius / opacity闂佹寧绋戦¨鈧紒?
   *    婵炴垶鎸哥粔闈浳?`morphP` 闂佸搫鐗滈崜婵嬫?闂佺偨鍎查弻锟犲焵?闂佸湱顣介崑鎾趁归悩顔煎姦婵☆偅鎸冲畷鐘诲川閺夋垶顏為梺鍛婄懐娴滐綁銆呴敃鍌氱濠电姴瀚瑧闂佽鍏涘ù鍥箚閵堝绀嗛柟娈垮枤閻帡鏌ｉ幇顔藉殌鐎规挸妫濆畷锝夘敍閵堝洨顦繛鎴炴惄閸欏啫螞鐠恒劍鏆滅憸蹇涘极閸楃儐娴栭柛鈩冾焽娴犳悂鏌熺紒妯虹瑨闁逞屽墰閵嗗妲?
   *    闂佸湱顣介崑鎾绘煛閸繍妲虹紒顕嗙畵瀹曠兘濡搁妷锕€鈧崬鈽夐幘顖氫壕婵炲濮烽弲顐ｆ叏閹间礁绠戝ù锝夘棑閻熸劙鏌ｉ妸銉ヮ仼闁活偅锕㈤獮鈧憸宀€妲愰悧鍫⑩枖闁逞屽墰閹秆囨偪椤栨繃宸㈤梺鍛婅壘婵傛梻绮╅幘顔肩骇闁斥晛鍟柨銈囩磼閹规劧楠忛柍?
   */
  private playMorphOpenIntro(): void {
    this.expandIntroRunning = true;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍡椕洪弽顓熺劵闁逞屽墴瀹曘儲鎯旈妸銉︻仧闂佺顑嗛悢顒傛濮樿埖鏅?*闂佸憡甯炴慨鐢垫暜閳ь剟鏌涘Ο鐓庢瀾婵?閻庣偣鍊涘▔娑㈠箖?50ms 闂佸憡鍔曠粔鐑藉箲閿濆洦鍋橀柕澶嗘櫆閿?闂備緡鍙忕徊鑲╃博閺夋埈娼?*闂?
    //   闁诲海鎳撻崯顐ょ礊鐎ｎ喚宓侀悗娑櫳戠瑧婵炴垶鎹佸銊ц姳閿涘嫮纾奸柡鍥╁仧绾捐鈽夐幘顖氫壕婵炴垶鎼╂禍鐐诧耿閿涘嫧鍋撻崷顓炰粶闁宦板姂瀹曠兘濡歌閻ｉ亶鏌涜閸╁﹦妲?*V2 闂佹眹鍔岀€氼喗鎱ㄩ幖浣哥畱濞达絿顭堢紞渚€姊洪幓鎺旂婵?閻庢鍠栭崐褰掝敆閻愬搫鍐€闁搞儺浜滄竟?闂佹寧绋戝﹢顪竜mise 閻庣敻鍋婇崰鏇㈠箲閵忋倕绀夐柍钘夋噽缁€鍡涙煥?
    //   闂?`animateTo` 婵炴潙鍚嬪銊╂偟濞戙垹绀嗛悹鍥ㄥ絻閻撴洟鏌￠崒娑欑凡闁告埊绻濆浠嬪炊椤忓嫬顥嶉梺鐓庢惈閸婂宕戦敐澶婄骇闁靛鍎遍弸鈧柣搴ゎ潐閼圭偓鎱ㄩ埡鍛瀬闁割偁鍎哄ù鏇㈡偨?* 闂佺偨鍎查弻锟犲焵?婵炲瓨绮岀€涒晛危?闂佺绻愰悧濠冧繆閹间礁绀勯柣妯夸含缁夊潡鏌涘Ο渚剰闁糕晛鐬奸幐褎顦版惔鈥插寲闂?
    //   闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳暞瀹曟煡鏌涢弮鎾剁瘈闁革絿鍏樺畷妯侯吋閸喎闂柣鐐寸◤閸庨潧螞?闂佸搫鍟抽鎰濠靛鍌ㄩ悗锝庡幗瀹曟娊鏌ｉ幇顒傜Ш闁稿鎳忕粙澶愬焵椤掍胶鈻?*濠电偛鐭夌槐鏇㈠极閹捐鏋?*闂佹寧绋戦惌鍌炪€呴懡銈嗘殰鐟滃繐煤閸ф绠抽柕澹嫭娈㈤梺鍝勫敳閸愶絽浜剧紒妤勩€€閸?
    //   闁诲氦顫夎摫闁哄瞼鍠栭弫宥夊锤閸掔劋kts-new-applysync-flushupdates-flushuiupdates`闂佹寧绋戦ˇ杈╁垝娴煎瓨鍎嶉柛鏇ㄥ暕閹烘垟鏋栭柡鍥╁枑绗?
    //   `UIUtils.applySync(() => { 闂?})`闂佹寧绋掗懝楣冨箖閹炬剚娼伴柕澶堝劚閻撴洟鏌￠崒娆忓祮婵☆偅鎸冲畷鐘诲川椤撶偞鏆ラ梺姹囧妼鐎氼喗鎱ㄩ幖浣哥畱濞达絿顭堢紞渚€鏌涢弽銊у缂佽鲸绻堝畷妯侯吋閸喎闂梺鍛婎焽閸犳劕顭囬悽鍛婂剭闁告洦鍋勮闂佹眹鍨洪惇褰掑焵?
    //   闂佸搫鐗滈崜姘跺蓟閻斿皝鏋栭柡鍥ュ灩鐢娊鏌?`tryStartMorphIntro` 闂備焦褰冮惌鍌炲磻閸涱垯娌?`applySync` 婵炶揪缍€濞夋洟寮?闂佺偨鍎查弻锟犲焵?
    //   闁哄鏅滈悷銈囧姬閸愵喖鍙?闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佸憡绮岄張顒佹櫠濠婂牆绠伴柛銉ｅ妼閻濇盯鏌涢弬璇插濠⒀嶇畱椤曪綁鍩€椤掑嫬鍙婃い鏍ㄧ懆閳峰牆鈽夐幙鍐х盎濠殿喒鏅犻幃?闂佹眹鍔岀€氼喚鍒掗妸鈺佸嚑闁告洦鍏橀崑鎾诡槼闁绘鎸冲畷鍫曟偑閸涱垳顦?0ms/闂備焦褰冪粔鐑芥儊?缂傚倷鐒﹂敋闁糕晜顨婂濠氬Ω閳轰礁骞嬮梺鍝勫閸ㄤ即鎮鹃悩缁樺剭闁告洦鍟熸径瀣枖濞达絿顣介崑?
    // 闂佸疇娉曟刊瀵哥箔瀹ュ鐓ｉ柣娆忔噽閻?2026-10-17 缂備礁澧芥慨鐢割敆濠婂嫮鈻旈柍褜鍓氬?*闂佺懓鐡ㄩ崹濂稿吹濠婂喚鍟呴柛妤冨仜閺呮悂姊洪幐搴ｆ噮婵炲牊鍨甸埢鏃堝Ω閳轰焦鐝?*闂佹寧绋戦悧鍡涙偩閻樿鍙婃い鏍ㄧ懅閻熸捇姊婚崼娑樼伈闁稿鎳忕粙?bug 闂佹眹鍔岀€氼厼顭囬棃娑掓敠闁规澘澧庣粈鍡涙煥?
    //   闁哄鏅滈悷鈺呭闯閻戣棄鍌ㄩ柣鏂挎啞闂勫秹寮堕埡鍋亪宕幘缁樺創闁逞屽墴婵″浠﹂悾灞炬瘔闂佸搫鍊稿﹢杈╁垝娴煎瓨鍎嶉柛鏇ㄥ亜閺呭憡绻涙径瀣婵ǜ鍔戝浼搭敍濮橆叀鍚?`animateTo` 闂佹眹鍔岀€氭澘螞閹绢喖绀岄柛娑欐綑濞咃繝鏌?`UIUtils.applySync`
    //   闂佸憡鑹鹃張顒勵敆閻愬搫绀嗛梺鍨儐閻撯偓闂佺儵鏅╅崰妤呮偉閿濆纾圭紒妤勩€€閸嬫挸顓兼担鎻掍壕闁哄倽銆€閸?*闂備緡鍙忕徊鎯ｉ幖浣圭叆婵炲棙鍨堕悾?*闂侀潧妫楅崐鎼佹偩婵傜妫樼憸鐗堝笒娴滄繂鈽夐幙鍐х盎婵犙€鍋撻梺鍝勬媼閸ㄥ崬危?
    //   闂?*闂佸憡鏌ｉ崝宥夊疾閵夛妇鈻曢悗锝庝簻椤?*闂佸搫鐗嗛ˇ鐢嘎烽崒娑樼窞闁哄稄闄勯崣蹇涙煛閳?闂?闂?`applySync` 闂?*闁荤姍鍥舵闁?*闂佽В鍋撻柦妯侯槹閸曢箖鏌?*闂?*闁?`animateTo`闂侀潧妫楃粙鍕?
    //   闂?**`animateTo` 闂傚倸鍋嗛崢鑲┾偓鍨耿閺屽瞼浠﹂挊澶嬮敪闁荤姳鑳堕…鍫ュ疮閹剧粯鍎庢い鏃傛櫕閸ㄥジ鏌?*闂佹寧绋戦悧鍡涘疮閹惧顩烽柍褜鍓氱粙濠囧醇濠靛洨娈ら柣鐐寸◤閸庨潧螞閸ф绀嗛柡澶嬪閹插潡姊洪幓鎺旂効缂佽鲸宀告俊?
    //   闂佺娉涢敃銈夋偩閻樿缁╅柟瑙勫姉缁犲姊婚崒銈呭箹閻庡灚锕㈤弻?= 闂佺娉涢敃锕€煤娴兼潙鍐€闁搞儜鈧崑鎾绘嚃閳哄啫缍勯梺鍛婂笩椤曆囧春濞戙垹绀勯柛婵嗗缁?闂?**闁荤偞绋忛崕闈浳涚捄銊﹀仏妞ゆ劑鍎抽崕鏌ュ级?* 闂?闂佺儵鏅涢悺銊ф暜鐎靛憡宕夌€规洖娲ㄩ惌鎺楁煟閹邦剛鐣柍?
    //   闂?闂佸搫鐗滈崜姘跺几閸愨晝顩烽柛顐ｆ礀濞?`applySync` 闂佹眹鍔岀€氼參顢楀鍛厹妞ゆ棁宕电粔瀵哥磽閸愭儳鏋涚憸鎶婂洤瀚?闁荤偞绋忛崕闈浳涢幐搴ｂ枙閻庯綆浜滈·?闂佹寧绋戦悧鎰帮綖?:3158 / :3737 婵炴垶鎸堕崐鏇⑺囬埡鍛櫖濠㈣泛鐗冮崑?
    //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸婚悧鏃堝船椤掑嫬鐭楅柛鎴欏€楃粣妤呮煛閳ь剛鎹勯搹鐟版殹闂佹悶鍎抽崑鐘绘儍閻旇崵鐤€闁告稒鐣埀顒€绻愯闁哄倹顑欓崵?`morphGen`闂佹寧绋戦悧鍡楊嚕閻ｅ瞼纾介柡宥庡墰濡差垶姊?`animGen++` + onFinish 闂佸搫绋勭换婵嬫偘濞嗘挻鏅鑸电〒缁€?
    //    闂佸憡鐔粻鎴﹀垂椤栨繄鐤€妞ゆ劧鑵归崑鎾绘偄閼姐倗顔曢梺?闂佽　鍋撻柟顖滃瀹曞啿霉閸忚偐鐓悷鏇炴閹晠鎳滅喊妯轰壕濞达絿顣介崑?
    const gen: number = this.expandState.morphGen;
    // ★★★ 2026-10-18（第六轮真因）：`beginContentTween()` 必须排在几何 `animateTo` **之前**。
    //   它内部 `from = this.morphP`（见 `PlayerExpandState.beginContentTween`），而下面那条
    //   `animateTo` 的闭包会**同步**把 `morphP` 写成 1 ⇒ 排在后面就只能拿到 `from = 1`，
    //   整条内容时间线退化成"始终停在终点"（这就是「底部控件出现过早」的真因）。
    const contentGen: number = this.expandState.beginContentTween();
    try {
      // ★★★ 2026-10-18（用户第十轮：「展开过程中返回没动画」）：几何改成**逐帧**驱动
      //   —— 与跟手那条（手指写 `applyMorphProgress`）同一个机制，理由见 `startGeoDriver()`。
      this.startGeoDriver(0, 1, PlaybackPage.MORPH_OPEN_DURATION_MS, false);
      // ★★★ 2026-10-18：**内容时间线单独一条补间**（用户实测「进度条和下面几个控件飞入比无界早了很多」）。
      //
      // 上游是**两条**时间线，同一起点、各走各的（`_recover/logic-src/ExpandAnimation驱动与补间定稿.md:480-483`
      // + `MiniPlayer布局与形变栈补充定稿.md:222-235`）：
      // ```
      //   容器几何（scale/translateX/Y/clipHeight/radius）← ExpandAnimation.doEnter = 350ms + Curve.EaseInOut
      //                                                      ↑ 就是上面那条 animateTo
      //   内容窗口（歌名行 0.18→0.62 / 进度条+传输行 0.45→1.00 / 背景 0→0.30）
      //       ← MainPage.animateMorphT(1, ENTER_MS, EASE_OUT_STR, λ) = **560ms + 快出慢收**
      //         wujie.pa:154167-154169  ldai 0x230 → definepropertybyname "ENTER_MS"    // 0x230 = 560
      //         wujie.pa:163524-163547  animateMorphT + ENTER_MS + ldexternalmodulevar 0x16 "EASE_OUT_STR"
      //         wujie.pa:145608-145661  animateMorphT = createAnimator + onFrame 逐帧写 morphT
      //   PlayerPage 那边读的是同一份 AppStorage 键（`pullT ≡ morphT`，pullT写入算式与形变枚举.md:24-81）
      //   ⇒ `effT()`（wujie.pa:171535-171548）= isMorphTarget() ? 1 : pullT 就是这个 560ms 的进度。
      // ```
      // ⛔ 不许把这两层合并进同一个 animateTo：合并就等于把内容窗口压进 350ms（墙钟上早 37%），
      //    正是用户看到"飞入比无界早"的量化来源。
      // ★★★ 2026-10-18（第六轮真因）：内容时间线改由**逐帧 ticker** 驱动（见 `startContentTicker()`）。
      //   ⛔ 这里原来是 `this.getUIContext().animateTo({duration: 560, curve}, () => { contentP = 1 })`：
      //     `animateTo` **不会**逐帧插值状态变量（闭包里的赋值一次写成终点），
      //     加上 `beginContentTween()` 的 `from` 当时读到的 `morphP` 已是 1
      //     ⇒ `contentP` **第一帧就是 1** ⇒ `pullBottomIn` / `pullBottomOpacity` /
      //     `pullChromeOpacity` / `pullBgIn` / `pullBottomYVp` 全部恒为终点值（窗口公式全废）。
      //   ✅ 上游是 `animateMorphT` = `createAnimator` + `onFrame(v) => morphT = v`
      //     （`wujie.pa:145608-145661`），每帧写真进度。
      this.startContentTicker();
      this.logChromeReveal('intro');
      Logger.info(PlaybackPage.logTag,
        `RzdMorphOpen geoMs=${PlaybackPage.MORPH_OPEN_DURATION_MS}/EASE_OUT_STR(0.23,1,0.32,1) ` +
          `contentMs=${PlayerExpandState.MORPH_CONTENT_DURATION_MS}/EASE_OUT_STR(0.23,1,0.32,1) ` +
          `settleMs=${PlayerExpandState.MORPH_CONTENT_DURATION_MS + 30} gen=${contentGen}`);
      // 内容补间收尾（世代号不匹配时 `endContentTween` 自己丢弃旧回调）。
      setTimeout((): void => {
        this.stopContentTicker();
        this.expandState.endContentTween(contentGen, 1);
      }, PlayerExpandState.MORPH_CONTENT_DURATION_MS + 30);
    } catch (err) {
      // 闁荤偞绋忛崕闈浳涚捄銊﹀皫闁炬艾鍊婚悷婵嬫煛婢跺牆鍔欑紒鈥冲暟閹茬増鎷呴懞銉ュ姍闂佸憡甯楀姗€鎮鹃鍕瀬閻庢稒菤閸嬫挻绗熸繝鍕槷缂傚倷鐒︾换鈧紒妤€顦甸幊妤呮嚍閵夈儙鈺呮煙缂併垹骞楅柡鍌欑劍閵囧嫰鎮介崹顐ｇ暚闂?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹婵炴垶鎸撮崑鎾绘倶韫囨挾绠版繛?
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `morph open animateTo failed code=${e.code} msg=${e.message}`);
      this.stopContentTicker();
      this.expandIntroRunning = false;
      this.expandState.morphSettleOpen();
      return;
    }
    setTimeout((): void => {
      if (!this.expandState.morphGenAlive(gen) || this.isClosing || !this.isAlive) {
        this.expandState.logMorphOwnership('open-finish-expired');
        return;
      }
      this.expandIntroRunning = false;
      // 闂佸疇妫勯幊澶娢?2026-10-16闂?*闂佸憡鑹炬總鏃傜博閹绢喖绾?婵炴垶鎸哥粔鐑姐€呴敃鍌氭嵍闁靛濡囧楣冩煛閸繍妲搁柛銈嗗灦閹峰懘寮撮悢鍓叉Н闂佽В鍋撻柟瀛樺笧缁?闂佹眹鍔岀€氼垶锝炴径鎰?*闂佹寧绋戦惌渚€锝?`Index.settlePullOpen`闂佹寧绋戦¨鈧紒?
      //   闁哄鏅滈悷銈囩博閹绢喖鐭楅柕澶堝劚閺傃囨煛婢跺牆鍔滄俊顐犲€濆鍫曞灳閸欏鍋ㄩ梺瑙ｅ亾闁瑰瓨甯炵粔鎾煏閸℃鈧晫鈧哎鍨藉鐢割敆閸愵亝鐎梺鍛婂灩婵磭绱炲鍡樺弿閻庯綆鍓涢惌鎺撶箾瀹€瀣瘈闁革絾妞藉畷姘辨暜椤斿墽顦ーmorphGeomReady` 婵炴垶鎸搁幖顐ｇ閿濆鏅鑸电〒缁€?
      //   `morphSettleOpen()` 闂佸憡鍔曢幊姗€宕曢幘顔藉剭?`applyMorphProgress(1)` 婵炴潙鍚嬫穱娲綖閿曞倹鐒介柨婵嗩槷婢规洟姊婚崒妯哄閻忓繐鎳橀獮鎺撳緞閸艾浜?
      //   闂佸吋婢橀惉鐓幟规径瀣鐎广儱鎳庣粊杈╃磽閸垻甯涢柛?OPEN 闂?闁诲骸婀遍幊鎾斥枍閹烘纾绘繝濠傚暞闊剟鏌熼鐔风闁?+ 闂佺儵鏅犻弲鑼礊?OPEN 闂?*闂佸憡顨呴敃銉╊敆閹绢喗鍋愰柤鍝ヮ暯閸?*闂?
      //   闂?闂佸湱顭堥ˇ鏉课涢妶澶嬪仼閻忕偟鍎甸崑鎾崇暆閸曨偅顏℃繛鎴炴尭缁夋挳宕哄畝鈧禍鎼佹焼瀹ヤ礁浜鹃柍褜鍓熷畷鍫曟倷鐎涙褰梻?push(闂佸搫鍟版慨鎾嚋娴兼潙鐭?闂侀潧妫楃粔璺衡枔閹达箑鐭楅柨婵嗘噽缁愮偤鏌ㄥ☉娆掑鐟滄妸鍥х濠电姴瀚粊鎻捗归敐鍛ｉ柡浣哥秺閻涱噣骞撻幒鎴炵彎闂佹寧绋戞總鏃傜箔婢舵劖濯伴柟瀛樺笧缁夋挳鏌?
      if (!this.expandState.morphGeomReadyNow()) {
        this.expandState.pushMorphTrace('openNoGeom');
        this.expandState.morphReset();
        this.expandState.morphStage = MorphStage.OPEN;
        this.expandState.morphP = 1;
        // 直接落位：内容时间线也一起落 1（两条线静止态必须同值）。
        this.expandState.cancelContentTween();
        this.expandState.contentP = 1;
        this.expandState.measureGeometry(this.getUIContext(), true);
        return;
      }
      this.expandState.morphSettleOpen();
      // 闂?闂佽В鍋撻柟瀛樺笧缁夋挳鏌?*闂備焦褰冪粔褰掑闯閻戞鈻旈柍褜鍓欓埢?*闂佸憡鍨规慨宕囩礊瀹ュ鏅慨妯虹－缁犵懓鈽夐幘顖氫壕闂佸憡甯掗…鐑藉Υ婢舵劖顥堥柕蹇曞Т閸ゆ帞绱撴担鍝ョ婵″弶鎮傚畷銏ゆ偄闁垮顫呴柣搴ｆ暬濞艰崵妲愬姝漚le=1闂侀潧妫斿鎺旂礊閸涱垳鐭?0闂佹寧绋戦¨鈧紒?
      //   闂備焦褰冪换鎰板春瀹€鍕剭闁告洦鍓氱瑧濡ょ姷鍋炶ぐ鍐闯閿濆鍎嶉柛鏇ㄥ幘閻帡鏌ｉ幇顒佽础闁绘挴鏅為妵鎰帮綖椤旀儳鑰块梺鍛婅壘閺堫剙顪冮崒鐐茬?aside 闂佹眹鍔岀€氼剟顢欓弮鈧幆鏃堟晝閳ь剟宕哄☉銏犳濡鑳堕閬嶆⒑椤掆偓缁嬪嫮妲愬顨猄 闁圭厧鐡ㄥú姗€鎮ラ鈧獮鎺楀箳閹寸媭浼岄梺鍛婄懐閸ㄧ敻宕楀鈧畷锝呂熺捄銊х暫闂佹寧绋戦ˇ顓㈠焵?
      //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈囩博閹绢喗鐓傞煫鍥ㄦ尭濞懷呮喐閺夊灝鑸归柟?*婵炴垶鎸搁鍕博鐎涙ɑ濮?*闁诲繒鍋炲ú鏍閹达附鏅柛顐ｇ矌閻熸繈鏌涢弬璇插婵犫偓閻楀牊濮滄い鏂垮⒔閻帡鏌ｉ幇顔筋仧缂佽鲸宀搁弫宥囦沪閹屾殹婵炲濮伴崕閬嶆偩閻樿鍙?婵炴垶鎸搁鍕博鐎涙ɑ濮滄い鏃囧Г缁绢垶鏌?闂佹眹鍔岀€氼亞鎹㈠鑸碘挃闁冲搫顑囩粈?
      //      婵炴垶鎸哥粔闈浳ｉ幖浣稿珘妞ゆ帒鍟伴弸鍌炴煢閳ь剟骞嬮幒鏃傂㈤柣搴ｆ暬閳ь剚绋撻悷婵嬫倵闂堟稒璐℃繛鍫熷灦缁楃喎鈹戦崶褏銈﹂梺?
      this.expandState.measureGeometry(this.getUIContext(), true);
      // ★★★ 2026-10-18：**落位（ENTERING → OPEN）推到内容时间线跑完那一刻**，与上游一致。
      //   上游 `finishEnter()` 是 `animateMorphT(1, ENTER_MS, EASE_OUT_STR, λ@5**#)` 的 **onDone**
      //   （`wujie.pa:163537` 的 `definefunc 0x21 …@5**#` + `wujie.pa:163554-163559` 的 `finishEnter`），
      //   它里面才 `setMorph(OPEN, NONE)`（`ExpandAnimation驱动与补间定稿.md` §四 第 4 步）。
      //   ⛔ 这里原来用的是 `MORPH_OPEN_DURATION_MS + 30`（= 380ms，几何那层的收尾）：`morphSettleOpen()`
      //      会把 `morphStage` 置 OPEN ⇒ `morphLive()` 变假 ⇒ `pullChromeOpacity()` / `pullBottomIn()`
      //      全部**立刻返回 1**，内容窗口被硬切成"到点"—— 那 560ms 的内容补间就白跑了（用户实测的就是这个）。
    }, PlayerExpandState.MORPH_CONTENT_DURATION_MS + 30);
    // ★★★ 2026-10-18（用户第六轮：「展开过程中按返回**不抽搐了但会闪**（返回动画突然消失 → 突然出现完整播放器 → 又消失）」）：
    //   闪的原因是"活体反向"与**壳层那条 560ms 的打开收尾**抢同一个 `morphP`：壳层到点会 `applyMorphProgress(1)`
    //   把页面**snap 回展开态**（= "突然出现完整播放器"），随后我们的反向计时到点又 pop（= "又消失"）。
    //   上游能直接反向，是因为它那边只有**一条**驱动；我们这边壳层还有一条独立计时器。
    //   ⇒ 展开中收到关闭请求时**不动画**，只记一个标记；等打开收尾（`morphSettleOpen()`）之后再走**正常快照关闭**
    //   （那时 `morphStage === OPEN`，快照拍到的就是完整的展开态，不会闪）。
    if (this.closeAfterOpen) {
      this.closeAfterOpen = false;
      Logger.info(PlaybackPage.logTag, 'RzdCloseLiveMorph deferred-close now');
      this.onCollapseRequested();
    }
  }

  /**
   * @returns 闂佸憡鍔曢幊搴敊閹邦喕娌柛宀€鍋熻ぐ顖炲箹鏉堟儳顩繛鍛姂瀹曟岸宕卞Ο鍏夹ラ柣搴㈢⊕椤ㄥ牓顢栨担鍦枖閻忕偛鍊甸崑?
   *
   * 闁哄鏅滅粙鎴犫偓?0 闂?`'100%'`闂佹寧绋戦悧鍛箔鐏炶В鏌﹂柍鈺佸暞缁犳帡鏌涢弬璇插闁轰線绠栧顕€宕奸弴妤€浜鹃柟閭﹀墮閸撹偐绱掓潏鈺佇＄紒鏃€鎸抽幊娑欐綇閸撗咁槷闁哄鏅滈悷锕€危閹间礁瀚夐柍褜鍓熼弻灞筋吋閸偅鐭楅梺姹囧妼鐎氼參鍩€椤戭剙妫楃粣娑㈡煥濞戞﹩妾х紒?
   * 闁哄鏅滅粙鎴犫偓?100 闂?`COLLAPSED_HEIGHT_PERCENT`闂佹寧绋戦悧鎰板礆濞戞瑦鍎熼柡鍥ㄦ皑椤忛亶鏌℃径鍡橆潐缂佽鲸绻冨鍕樁闁搞伇鍛剨閺夊牄鍔嶇瑧闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹婵炴垶鎸撮崑鎾绘煛婢舵稓纾挎繛鍫熷灦椤ㄥ洤螣閸濆嫷鍞洪梺鎸庣☉椤︻參鍩€?
   */
  private sheetHeightPercent(): string {
    // 闂佸疇娉曟刊瀵哥箔?闁诲骸婀遍幊鎾斥枍閹烘洏浜归柕蹇曞Т缂嶄線鏌ㄥ☉妯煎婵☆偁鍊濋幃鎯х暆閸曨偂绨兼繝闈涘€归〃鎰濮樿泛瀚夐柣鏂垮悑閿?*闂婎偄娲ら幊姗€濡磋箛娑樼畳闁瑰搫绉风粈?100%**闂佹寧绋掑畝鎼佸磻閸涱喚闄勬俊銈傚亾鐟滄妸鍥棃?婵犮垼鍩栭悧鏇㈡儑閹殿喒鍋撻崷顓熷殌婵炲懏甯炵槐鎾诲煛閸屾稒婢?+ 闁荤喍妞掔粈浣圭珶閳?闁诲海鎳撻張顒勫垂濮樺彉娌柡鍥╁仧绾惧鏌?
    //    闂佸吋鐪归崕瀵告崲閺嶎厽鐓傞悘鐐跺Г閸婇亶鏌￠崘顓炵厫閻?collapseProgress 闂佸憡锚椤戝洨绱撴径鎰闁告侗鍙庨崯鍥倶閻愭彃鈧潡鎮甸鑺ュ劅闁挎棁鍋愮粈澶愭倶韫囨岸鍝烘繝鈧担鍦枖闁靛牆鎷嬪▓浼存煕閺傝濡块柡渚€绠栧畷鐑藉Ω閿旇姤姣夐梺鍛婅壘婵傛梻绮╅幘顔藉亱闁搞儜鍜佷紝闁诲繒鍋愰崑鎾绘煥?
    //    闁荤偞绋忛崝搴ㄧ嵁閸ャ劎鈻旈柛婵嗗閺佸爼鎮楅崷顓ф敯妞ゎ偓绠撳畷銏⑩偓锝庡亜椤ｆ娊鏌曢崱鏇狀槮闁汇劍绻堝Λ鍐閵堝棙娅撴繛杈剧到缁夋煡鍩€?
    if (this.expandState.morphContainerActive()) {
      return '100%';
    }
    const p: number = Math.max(0, Math.min(100, this.collapseProgress));
    if (p <= 0) {
      return '100%';
    }
    const h: number = 100 - (100 - PlaybackPage.COLLAPSED_HEIGHT_PERCENT) * (p / 100);
    return h.toFixed(2) + '%';
  }

  /**
   * @returns 闂佽　鍋撻柟顖滃瀹曟娊寮堕埡浣瑰窛闁宠鍚嬬粙澶愵敇閻旀劅锕傛煕濮樺墽鐣虫い鈺嬬畵閹稿﹨绠涘顓為棷闂佸搫绉村ú顓€?闂佺鐭囬崒娑卞仺闂?
   *
   * 闂婎偄娲ら幊姗€濡磋箛娑欏癄闊洢鍎崇粣妤呮煕閹邦剚鍣规い鏃€鍔楅幃顕€顢曢姀鐘殿伝闂佺懓鍚€缁€渚€宕哄畝鍕煑妞ゅ繐瀚埛鏍р槈閹绢垰浜鹃梺鍝勵槴閸撴繂顪冮崒鐐存櫖閻忕偠濮ょ粊濂告倵鐟欏嫬鍝洪柣婵愬枟閹棃鏁傞悙顒傛殸闂佺鐭囬崘銊у幀闂佸憡鐗炲銊ф娴兼潙绠┑鐘插€诲▓閬嶆⒒閸稑鐏悘蹇擃儔楠?0 婵?
   * 闂佹寧绋戦悧鍡楊嚕椤掑嫭鍤€闁告劑鍔嬬槐锝囩磼鐎ｎ亶鍎庣紒鈥冲暣瀵即顢涘┑鍫㈩啇婵炴垶鏌ㄩ悧鍡浰囬埡鍛仩闁糕剝鐟﹂悾?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯鏉库枔?`isDismissPhase2HideMeta()` 婵炴垶鎸撮崑鎾诲级閳哄倻鈼ョ紒銊㈡櫅閳绘捇妫冨☉娆戞闂?meta闂佹寧绋戦ˇ顓㈠焵?
   */
  private isCollapsing(): boolean {
    // Morph dismiss keeps natural layout mounted; opacity/clip handles chrome continuously.
    return !this.expandState.morphContainerActive() && this.collapseProgress > 45;
  }

  /**
   * 闂?2026-10-17闂佹寧绋掗惌顔剧箔閸屾稓鈻旈柍褜鍓欓埢?*闂佹椿浜為崰鎰邦敆濠婂嫮鈻旈悗锝庝簻缁叉椽鏌熺€涙ê濮囧┑?*闂佹眹鍔岀€氼剟鎮ラ懜鐢殿洸妞ゆ柨顫曢埀顒€鍊归幏鍛吋韫囨洜顦ーundefined` = 闁哄鏅滆摫闁汇儱鎳橀獮瀣箛椤掆偓椤娀寮?/ 婵犮垺鍎肩划鍓ф喆閿曗偓椤斿繘骞撻幒鎾额槬濠电姴锕ラ悢顒傛濮樿泛违?
   *
   * 闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮?`WindowInfo.setKeepScreenOn`闂佹寧绋戝濉猠sign/animation/WindowInfo.ets`闂佹寧绋戦ˇ鍗炩枔閹达妇宓侀柛灞剧矌閹煎ジ鏌涢幒瀣偓鏍х暤娓氣偓閺?
   * ```ts
   *   setKeepScreenOn(on) {
   *     if (this.screenOn === on) return;                 // 闂?闂佺锕ら崥瀣儉閸涙潙鐭楁俊顖滃劋閻ㄦ垵鈽夐幘宕囆＄紒妤€鎳樺畷锝夊箣椤栨粎顦╁Δ鐘靛仜閸婂鎮洪幋锔芥櫖?
   *     if (window === undefined) return;
   *     this.screenOn = on;
   *     window.setWindowKeepScreenOn(on).catch(濞?);       // 闂?濞?闂佹寧绋掗鐩縭n + `screenOn = false`闂佹寧绋戦悧鍡涘Φ閹寸姵瀚婚柕澶堝劜缁€鈧┑鐘诧攻閻旑剛妲?
   *   }
   * ```
   * 闂佸疇娉曟刊瀵哥箔?**闂佹悶鍎抽崑鐐靛垝閹绢喗鐒介柨婵嗘噹绾惧綊鏌℃径鍡楀⒉婵″弶鎮傚畷妤呭箮閼恒儲娈?*闂佹寧绋掓穱铏光偓姘ュ灪缁嬪顓奸崨顔绢槬濠电姴锕ラ悢顒傛濠靛洤绶為弶鍫亯琚濇繛鎴炴煥椤戝懘骞冨Δ鍐＝闁规儳纾幗鐘绘煕婵犲洦锛熺紒妤€鐭傞幆鍥偄妞嬪孩婢栭梺绋匡躬濡法绮径瀣枖闁逞屽墴閹?闂?婵炴垶鎸搁鍕博閺夋垟鏋庨柍銉ㄦ珪閸婇亶鏌涙繝鍛棈妞ゆ洦鍓欐晥闁稿本鐟х粣妤呮偠濮樼厧浜滅紒鐘虫尵缁灚寰勯幇顓ㄧ礉闂佸湱纭堕崜婵堟暜閳?
   *   闂?**濠殿喗蓱閻℃洜鎹㈠▎鎰枖鐎广儱鎳庨弲娆忊槈閹炬剚鍎忕憸?*闂佹寧绋戦悧鍛箔瀹€鍕珘妞ゆ垼娉曞▔銏ゆ煕濞嗗繒孝妞わ附鐓￠悡顏堝煛閸愨晝鏆?闁荤姍鍥ㄦ暠濠⒀勭矌缁辨棃顢欓悙顒€鐒?闂佽　鍋撻悹楦挎閸熻尙绱撻崘鎯ф灈濞?婵炴垶鎸哥粔鐢稿垂濮樻墎鍋?闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳閸╁矂鏌ｅΟ娆惧晣缂佽鲸宀告俊?
   */
  private keepScreenOnApplied: boolean | undefined = undefined;

  /** Applies the keep-screen-on switch while the playback page is visible. */
  private applyKeepScreenOn(enabled: boolean): void {
    try {
      // 闂佺绻愰悧蹇涙偩?*闂佹椿浜為崰鎰邦敆濠婂懏鍟哄ù锝夘棑閻熸捇鏌涘▎鎰仼婵炲牊鍨垮畷?*闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫰顣﹂悞濠傗攽閸屾稑鐏婄紒妤€鏈妵鍕偨閸涘﹥銆冮梺鐑╂櫊閺呰尙绱為崨瀛樼劸闁稿﹦鍣ュú锝嗙節婵炴劑鍊曢崰鏇㈡煥濞戞﹩妾х紒杈ㄧ箞瀹曟ê顓奸崱妤冩啨闁诲海鎳撻崯顐ｇ濞戙垻宓侀柛灞剧矌閹煎ジ鏌涢幒瀣偓鏍х暤?
      // 闂佸疇娉曟刊瀵哥箔?婵＄偑鍊曢幖顐よ姳椤撱垺鏅慨姗嗗墰缁犳垵顪冮妶鍫殭婵犫偓椤忓牆鐭?UIContext 婵炴垶鏌ㄩ鍛櫠閻樼粯鏅柛顐ゅ枑閿熴儵鏌ｉ敐鍛殭缂佲€冲暣瀵即顢涘顓″惈闂?window 婵炴垶鏌ㄩ鍛櫠閻樿绀傞柛顐ゅ枔濡?`screenOn`闂佹寧绋戦ˇ顓㈠焵?
      const keep: boolean = enabled && MusicStoreService.getInstance().getKeepScreenOn();
      if (this.keepScreenOnApplied === keep) {
        return;
      }
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (ctx === undefined) {
        return;
      }
      this.keepScreenOnApplied = keep;
      window.getLastWindow(ctx).then((win: window.Window): void => {
        // 闂?闂佸憡鍔曢幊搴ㄦ儑?promise 婵炴垶姊婚崰鏇€?catch闂佹寧绋掗悺鐚籩tWindowKeepScreenOn` 闂佸搫鐗滈崜婵嬫閳哄倹浜ら柡鍌涘缁€鈧?Promise闂?
        //   婵炴垶鎸哥粔鐢垫暜鐎涙ɑ濯撮煫鍥ㄦ尰閻ㄦ垿鏌￠崟闈涚仧缂佹柨鐡ㄧ粙澶愵敂閸涱喖绱︽繝銏ｆ硾鐎氼噣骞冩繝鍥ㄥ剭?rejection闂佹寧绋戦悧鍡欐暜椤愶箑绾ч柕澶堝妿缁犲綊姊洪幓鎺撴拱妞ゆ帗绮撳浼搭敍濠靛牏顔愰梺鍝勭Т閸ゆ牜妲愬鑸垫櫖鐎光偓閸愶絽浜鹃悘鐐跺亹閻燁剙顭块幆鎵翱閻熸瑱绠撳?*闂婎偄娲ら幊姗€濡磋箛娑樼倞闁绘劕顕▔?*闂?
        win.setWindowKeepScreenOn(keep).catch((_err: Object): void => {
          this.keepScreenOnApplied = undefined;
        });
      }).catch((_err: Object): void => {
        this.keepScreenOnApplied = undefined;
      });
    } catch (_err) {
      this.keepScreenOnApplied = undefined;
    }
  }

  /** Cover source for the current track: online url when available, else the local cover, else default. */
  private currentCoverSource(): string | Resource {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined) {
      if (song.cover.length > 0) {
        // 闂侀潻璐熼崝搴ㄥ吹鎼达絼鐒婂〒姘ｅ亾婵?URL 闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥€涒晠骞愰柆宥呯哗濡わ絽鍟ㄩ埀顒€顦辨禍鍛婄瑹閳ь剙顭囨导瀛樻櫖闁秆冨殼layerViewModel.songCoverUrl()`闂?*闂佸憡鑹炬總鏃傜博閹绢喖绾ч柕澶涘閻?*闂?
        // 缂傚倷绶￠崣鍐夐敐鍥︾剨濞撴埃鍋撴繛闂村嵆楠炲秴顓奸崟顓犳喒婵炴潙鍚嬮懝楣冨吹椤撱垺鍋?闂佸搫顦埀顒€鐤囬崺宀勬煟椤旇崵绐旈柛锝囧厴瀵即顢涘杈唸闂傚倸鐗滃鍧楀焵椤戣法绐旀い銉稻濞煎宕堕妸锕傛闁哄鏅滈悷銉ф閸洖鍙婃い鏍仧鐢盯鎮规担闈涒偓鏇㈠Φ閺冨牆纾?
        return song.cover;
      }
      // 闂佸搫鐗滈崜娆忥耿?濠电偛鏈悷褔顢欓崼顫剨濞撴埃鍋撴繛闂村嵆閺佸秴顫㈠鐠el` 闂佸搫瀚烽崹鍐诧耿閳ユ剚娼伴柨婵嗘处閻ｉ亶鎮樿箛搴ｇ獢婵?Resource闂佹寧绋戦悧鍛箔婢舵劕鍙?`ic_avatar1`闂?
      return song.label;
    }
    return $r('app.media.ic_avatar1');
  }

  // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涱敄閸ャ劎鈻斿璺猴工绾锯晛鈽夐弮鈧换鍡涙偪?/ Round 20闂佹寧绋戦¨鈧紒鍙樺嵆瀹曘垽鎮㈠畡鏉垮紬闂佸湱顭堥崐绋匡耿椤忓懏浜ゆ繛鍡樻尭濞咃繝鏌ｉ妸銉ヮ仾闁哄棴绲介埢?JSDoc 闂佺顕х换妤呭醇椤忓牊鍎嶉柛鏇ㄥ墯绗?`originalCoverSource()`
  //   闂佹寧绋戦悧蹇涱敄閸ャ劎鈻斿璺猴工绾锯晛鈽夐幘鍐叉殺闁汇倕妫楅蹇涘箵閹烘垹浠奸梻鍌氬閸娧呮濠靛牊鍠?RzdMusic闁荤姳鐒﹀妯兼崲?md 闁?6.13闂佹寧绋戦¨鈧紒杈ㄧ箞閻涱噣寮甸悽鐢垫噸闂備緡鍋呭銊╂儊閹烘埈鍤曢柡鍥╁У閺?`backgroundImageSource()`
  //   闂佹寧绋戦悧濠傦耿閻楀牊濮滄い鏃傚帶閸ゆ帡鏌涢幒鏂库枅婵炲懎閰ｉ弫宥嗗緞閸℃顏?閻庡湱顭堝璺何?*闁诲孩绋忛崐鏇㈠礉閻熸壋鏋栭柕濞炬櫅濞?*闂佹寧绋戦張顒勫汲閿濆應鏋旈柛顭戝亞椤忔悂鏌熼崫鍕垫Ф闁?
  //   闂佸疇娉曟刊瀵哥箔?`isPixelMapCover()` **婵炲濮寸粔鍫曞礉瑜斿畷鐑藉Ω瑜庨弳?*闂佹寧绋戦悧蹇擄耿閿涘嫧鍋撻崷顓炰哗闁汇劎鍠栭幃浠嬪Ω瑜嶆禒顖炴煥濞戞瑧鎽eleaseBackgroundCoverIfPixelMap()`闂佹寧绋戦¨鈧紒?
  //   **婵炴垶鎸哥粔鐑姐€呴敂鐐磯闁绘梻鍎ょ徊濠氭煕?*闂?

  // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涱敄閸ャ劎鈻斿璺猴工绾锯晛鈽夐弮鈧换鍡涙偪?/ Round 20闂佹寧绋戦¨鈧紒杈╂珬backgroundImageSource()` **閻庣懓鎲¤ぐ鍐垂瑜版帗鈷?* 闂佺偨鍎查弻锟犲焵?
  //   闁诲海鎳撻崯鎶藉吹濠婂喚鍟呴弶鍫氭櫆閻?JSDoc 闁诲繐绻愬畷顒勫疮閹捐鍙?闂佸摜鍎愰崹顖滅博鐎靛憡瀚柛鎰典簼閺嗗繘鏌ｉ幇顖ｆ綈婵?phoneSwiperBackdropImage闂佹寧绋戦惌渚€鍩€椤掆偓閻倿宕戦崨顔锯枖?builder 闂佸搫鐗滈崜婵嬫閳哄懎鍙婃い鏍ㄤ緱閸斻儱霉閻欏懐鎮奸柣?
  //   闂?闂?`phoneSwiperBackdropImage` 婵炴垶鎸撮崑鎾绘偣瑜戝〒鍦箔閸涱垳妫柛鏍电磿缁€澶愭煕韫囧濡虹紒顔哄姂濮婂潡骞嗛幍顔筋啀闂佹椿娼块崝蹇涘焵椤掆偓閹冲矂鍩€?
  //   闂佸憡甯炴繛鈧繛鍛缁楃喎鈹戦崶褏銈︽繛鎴炴尭缁ㄥ吋顨ラ崶顒佸亱闁冲搫鍠氶崕濠囨煕濞嗘垶鐒块柛銈嗙矊铻為柍褜鍓熼弫宥夊锤椤ｆ槴ules.abc GONE闂佹寧绋戦ˇ鎶斤綖?RzdMusic闁荤姳鐒﹀妯兼崲?md 闁?6.15闂?

  /**
   * True when value looks like a decoded PixelMap ({@link Resource} has no release).
   *
   * 闂佸疇娉曟刊瀵哥箔?2026-10-15闂佹寧绋掓穱娲磿濡ゅ懎鐤炬い鏍ㄧ⊕閺嗩參鎮楅崷顓炰沪婵＄偛鍊歌灒闁挎稑瀚棟闂?`imageLabel` **闂佽鍘界敮濠勬嫻?`Resource`**闂佹寧绋戦悧鍛箔婢舵劕绀冪€广儱鐗滃鍫曟偣瑜嶉鍡涘垂濮橆厾顩烽悹浣哥－缁?
   *   PixelMap闂佹寧绋戦ˇ顐﹀闯?闂佸搫鐗滈崜姘跺蓟閻斿皝鏋栭柡鍥╁仦闊剟鎮圭€ｎ亜鏆熼柡浣靛€濋幃娆戞喆閸曨亣鍩呴柡澶嗘櫆閺屻劌煤?false闂佹寧绋戦懟顖炴偪閸曨垱鈷旈柛娑卞幖閸ゆ帡鏌?*闂佺绻戠划宀€鑺卞畷鍥ｅ亾閻熸壆澧曠€?*闂?
   *   婵烇絽娲︾换鍕汲閳ь剙鈽夐幘宕囆㈤柛銊ョ秺閺佸秴顫㈠鐮甽easeBackgroundCoverIfPixelMap()` 婵炲濮寸粔鐟邦焽椤掑倵鍋撻悷鏉挎殭闁搞劎鏅悮鍓ф嫚閼碱兘鍋撻悜鑺ユ櫖闁割偓绲介崜褰掓煛閸滀礁鐏﹂柛瀣嚇瀵爼妾遍柣顓熷劤椤斿繘骞撻幒鎾瑰惈
   *   缂備焦顨忛崗娑氱箔娓氣偓瀹曗剝鎷呮搴ｆ闁哄鍎愰崳锝呪枔?`backgroundImageSource()` 婵炴垶鎸撮崑鎾绘偣瑜戝〒鍦箔閸涱垳妫柛鏍电磿缁€澶愭偡?RzdMusic闁荤姳鐒﹀妯兼崲?md 闁?6.15闂佹寧绋戦¨鈧紒?
   *   婵炲濮伴崕閬嶅箖濡ゅ懏鍤愰柕澶涢檮缁犳帒霉濠婂嫭銇濋柛锝嗘倐瀵剟鎮ч崼婢晠鎮峰▎娆戞偧闁绘牗绮庣槐鎺楀箻鐎甸晲鍑介梺琛″亾闁硅鍔楃粻?`imageLabel`闂佹寧绋戦惌浣烘崲閺嶎厼绾ч柍銉ュ暱閻庡鏌￠埀顒勵敍濞嗘垹鐛ラ梺鐓庮殠娴滄粍鎱ㄩ埡鍛厒鐎广儱妫欓悡鈧梺姹囧灮閸犳劙寮查妷鈺佄?
   */
  private isPixelMapCover(value: string | image.PixelMap | Resource): boolean {
    if (typeof value !== 'object' || value === null) {
      return false;
    }
    const probe = value as PixelMapReleaseProbe;
    return typeof probe.release === 'function';
  }

  /**
   * Releases native PixelMap backing if {@link imageLabel} is a decoded bitmap (not a Resource).
   *
   * 闂佸疇娉曟刊瀵哥箔?2026-10-15闂?*閻庤鐡曞鎾剁箔婢舵劕绀冪€广儱瀚粣妤呮煕濞戞瑥鐏婇柤鍨灦缁傛帞鎷嬪畷鍥┬繛鎴炴尰缁繘濡?*闂佹寧绋戝濉眒ageLabel` 闂佽鍘界敮濠勬嫻?`Resource`闂佹寧绋戦惌渚€锝?
   *   {@link isPixelMapCover}闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婇鎮潏銊р枖妞ゅ繐娲ㄥ▓鍫曟煟椤剙濡块柛瀣剁秮閺佸秹宕搁崚鐒峯utToAppear` / `onDisAppear`闂佹寧绋戦ˇ顔炬崲濮樿埖鍋╂繛鍡楃箰閺傃囨煛瀹ュ懎娈╃紒?
   *   闂佹悶鍎虫慨宕囨嫻閻斿憡浜ゆ繛鍡樺姈绗戞繛鎴炴尨閸嬫捇鏌?*闁诲海鎳撻ˇ顖炲矗韫囨洜纾?*闂佹寧绋掗惌顔剧博閻愵剛鈻旈柍褜鍓氱粋鎺楀Ψ閵夛箑鈧敻鏌涘▎蹇曞婵犫偓娴ｅ湱顩查柣鎴灻儫婵炶揪绲界粔鏉懨瑰Ο鑽ょ畽闁绘劕澧庣粻?`imageLabel`闂佹寧绋戦懟顖炴偩閻樺磭顩风€广儱娲ゆ慨褍霉閸忛棿浜㈢紒鈧€ｎ剚瀚婚柨婵嗩槸濞呯偤鏌￠埀顒佺┍閹典礁浜?
   *   闂佸疇娉曟刊瀵哥箔?闂佸憡鐟ョ粔鐟邦焽娴兼潙鏋佹繛鍡樺俯閸炴煡鏌ㄥ☉妯煎婵犫偓閺夊簱鏋庨柍鈺佸暞閺嗩參鏌涢弬璇插闁靛棗娴烽弫顕€鏁冩担鍥ㄥ浮瀹曟ê鐣烽崶銊ф殸闂佹寧绋戦¨鈧紒杈╁缁傛帡濡烽妷銉瀫闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本绋栭々顐︽煛鐏炵偓灏垫繛?*濠殿喗绻愮徊鎯?*闁哄鏅滈悷鈺呭闯闁垮顕辨慨妯诲墯濞煎爼姊洪幓鎺炴敾闁哄倷绶氶幆鍐礋椤栨矮绨奸悗?
   *   PixelMap 闂佺偨鍎查弻锟犲焵?"闂佺绻愰悧鎾诲闯閹绢喖缁╁ǎ鍥ㄥ閸嬫挻鎷呯粙鎸庢珒闂?`@Local` 闁荤喐鐟辩粻鎴ｃ亹閸岀偛绠查柕蹇ョ磿閻?婵炴垶鎼╅崣鍐ㄎ涢崸妤佲挄闁哄啫鍊圭徊濠氭偣鐎ｎ亜鏆欓悗瑙勫▕閺佸秶浠﹂悾灞惧墤婵炲瓨绮岀€涒晝绱為弮鍫濇嵍?use-after-free闂?
   */
  private releaseBackgroundCoverIfPixelMap(): void {
    if (!this.isPixelMapCover(this.imageLabel)) {
      return;
    }
    try {
      (this.imageLabel as image.PixelMap).release();
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(PlaybackPage.logTag,
        `background cover PixelMap.release failed, code=${err?.code}, message=${err?.message}`);
    }
  }

  /** Safe PixelMap.release for locals (blur/decoded temps). */
  private releasePixelMapQuiet(pm: image.PixelMap | undefined | null): void {
    if (pm === undefined || pm === null) {
      return;
    }
    try {
      pm.release();
    } catch (error) {
      Logger.warn(PlaybackPage.logTag,
        `pixelMap.release failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** Restores system-bar colors; window layout stays non-full-screen. */
  private restorePlaybackWindowChrome(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackNavigationBarColor(false);
    wu.applyPlaybackWindowChrome(false, false);
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(false);
    }
  }

  /**
   * 闂佺绻戞繛濠偽涢幘顔肩闁靛鍎冲宀勬煙缂併垹骞楅柡鍌欑劍閵囧嫮鍠婃径宀€鐛ラ梺绋跨箰閻楀﹪骞愰柆宥呯哗闁诡垳澧楀畷鎶芥煕閺傝濡块柡渚€绠栭弫宥夊醇閿濆洨顔掗柟?0 闂?闂佽　鍋撻柟顖滃瀹曟娊鏌ㄥ☉姗嗘缂佽鲸绻堥獮姗€顢橀悙鍨闂佸憡鍔曠粔鍨椤旇棄绶炵€广儱娲ㄥ畷鍫曟煕?chrome 濡ょ姷鍋犲▔娑樼暤韫囨梹濮滃┑顔藉姀閸?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡顨嗛悺鏇灻归崶顒€缁╅柟顖嗗嫯鍚?*闁诲氦顫夌喊宥咁渻閸岀偛闂?*闂備焦褰冮惌渚€鍩€椤掆偓婵傛梻绮径鎰強?`animateTo` 闂佹眹鍔岀€氼剟鎮鹃鍕闁归偊鍓氱粈鈧柣鐘差儏閸犳稓妲愭导瀛樼劷闁挎繂瀚伴崵瀣煕閵壯冧哗闁汇劎鍠栧畷鐑藉Ω閳轰礁濮ら梺鍛婂笒濡鈹冮埀顒勬煛閸滀礁鐏熺紒妤€顦扮粚鍗炩攽婵犲嫭顫嶉柣鐔哥懕缁犳垼銇愰崒鐐存櫖?
   * 闂傚倸鐗忔慨鎾偩閻樿纭€婵繂鏈粊浼存倶韫囨挸缍佺紒鍙樺嵆瀹曪絽螣鐠囪尙浜?闁哄鏅滈弻銊ッ洪弽顓熺叆妞ゆ棁妫勯惁璇裁瑰鍐╊棡闁汇儱鎳樺畷锝咁吋閸涱垰鐣?闂侀潧妫楅崐鎼佹偩妤ｅ啫绫嶉悹铏瑰劋閻濄倝鏌熺粙娆炬Ч婵＄偛鍊垮褰掑垂椤旂厧绠查柟鐓庣摠濞测晝妲愬┑瀣珘闁逞屽墴瀹曟瓕绠涢弬鍨闂佸憡鍔欏褑銇愯瀵即顢涘☉娆愭瘑闁荤姍鍐ㄦЩ濠殿喒鏅犻幃浠嬪及韫囷絾钑夐柣鐘叉惈閻ゅ洨鎹㈤崘顔芥櫖?
   * 闂佺绻戞繛濠偽涚€涙鈻旈柍褜鍓涢埀顒冾潐閻喚妲愭导鏉戠煑闁瑰濮甸弲鎼佹煏?
   */
  private refreshCollapseGeometry(): void {
    if (this.expandState.morphStage !== MorphStage.OPEN) {
      // ★★★ B（2026-10-20，照搬上游 `MainPage.retargetToLiveCover()`，`wujie.pa:151569-151756`）：
      //   **形变会话内**（ENTERING / LEAVING）关闭走的就是这一支 —— 原来这里直接 `return`
      //   ⇒ `morphBeginLeaving()` 用的是会话起手时那份 `barWin*`（迷你条胶囊），落点可能是旧的。
      //   现在补一次"反向开始前 retarget 到活的迷你条"（详见
      //   `PlayerExpandState.retargetCollapseAnchorForReverse()` 的说明）。
      //   ⚠️ 只重量**迷你条**（`MINI_BAR_ID` / `MINI_BAR_FLOATING_ID`：形变期是
      //      `Visibility.Hidden` ⇒ 占布局、量得到），**不量**播放页大封面（页面正被缩放）。
      const retargeted: boolean =
        this.expandState.retargetCollapseAnchorForReverse(this.getUIContext());
      Logger.info(PlaybackPage.logTag,
        `RzdReverseRetarget collapse-anchor ok=${retargeted ? 1 : 0} ` +
          `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(3)}`);
      return;
    }
    this.expandState.measureGeometry(this.getUIContext(), true, true);
    this.expandState.morphInitParams();
    this.expandState.freezeMorphMeta(this.getUIContext());
    this.expandState.logMorphOwnership('close-freeze-natural-open');
    Logger.info(PlaybackPage.logTag, 'collapse geometry refreshed while OPEN');
  }

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`MainPage.closeWithAnimation()`闂佹寧绋戦悾鐡€ujie.pa:171054-171095`闂佹寧绋戦¨鈧紒?
   * **闂傚倸鐗忛崑鐐存櫠濠婂牆绀夐柛顭戝枛瑜扮娀姊?*闂佹寧绋戦悧鍡涘矗瑜斿濠氼敇閻旈妯嗛梻?/ 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧梺鎸庣☉椤︻偊鍩€椤掍焦鐓涢柍?缂傚倸鍊甸弲婵嗏枔?*婵炴垶鎸哥粔闈浳ｇ粙妫电儤绻濆銉㈠亾婢舵劖顥?*闂佹寧绋戦惌渚€鍩€椤掆偓閺堫剙危?*婵炴垶鎸撮崑鎾垛偓娈垮枤婵潧顕ｈ缁絽螖閳ь剟骞撻埡鍛亗?*闂?
   *
   * ## 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亜閺傃囨煛閸屾碍鎼愰柤闀愬嵆閹?
   * ```
   *   closeWithAnimation() {
   *     if (pullMode && ExpandSnapshot.onReverseMorph(myMorphSnap)) return;   // 闂?婵炴垶鎸搁鍡樺垔濞差亝鐒介柨婵嗘閽傚鎮规笟顖氱伈缂佸彉鍗抽幊娑㈩敂閸曨厾鐣虫繝銏ｆ硾鐎氼噣骞?
   *     getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 濞达絽鍕?*#);     // 闂?闂佸憡鐔粻鎴﹀垂椤栫偞鏅慨姗嗗幖椤庣偤鐓崶璺轰簽闁?
   *   }
   *   濞达絽鍕?*#闂佹寧绋戝濯ie.pa:181020-181077闂佹寧绋戦¨鈧紒?
   *     婵犮垺鍎肩划鍓ф喆?闂?hilog.warn('root snapshot failed, fallback: 闂?) + nav.pop()    闂佹寧绋戦悧濠偽涢妶澶婄煑?= 婵炴垶鎸哥粔鎾偨椤愶絾濮滄い鎺嗗亾婵犙€鍋撻梺?
   *     闂佺懓鐡ㄩ崝鏇熸叏?闂?ExpandSnapshot.onShrinkBack(pixmap, this.mySrcBox) + nav.pop(false)
   *   onShrinkBack 闂?ShrinkOverlay.start(闂?     闂?闂佸搫鐗滈崗娑氬垝閵娾晜鍎?MorphShrinkState
   * ```
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐秵濞诧綁鏌ｉ幘妤€瀚崕鏃堟煥濞戞澧㈤柡浣靛€濋獮瀣槹鎼搭喖鍓?闂?闂佸搫顥￠幍鍐蹭壕閻忕偟鍋撶粻鎺楁煠閸愬弶婀版繛鍛懄閹峰懘宕卞Ο鎭嶏箑螖閸屾耽顏嗏偓瑙勫▕閹囨焻濞戞氨校闂侀潧妫楃粙鍕?
   * 闂佺懓鐡ㄩ崹鍐差煥閹寸偟鈻旈柍褜鍓熼幆鍕偓娑櫳戠瑧"闂佸憡鏌ｉ崝宥咁渻閸ф鍎嶉柛鏇ㄥ墯鐏忥繝鏌￠埀顒併偅閸愶腹鍋?闂佹寧绋戦悧濠囧极閼测晜鍟戝ù锝囶焾椤ュ懐绱掗幇顓ф當鐟?+ 缂傚倸鍊甸弲婊堝棘娓氣偓閺佸秵寰勯崱妤侇仸 闂佸憡鐟禍锝夈€呴敂鐣屸枖闁靛牆鐗冮崑鎾诲川椤掑倻鎲归梺鍛婅壘閺堫剟顢楅悙鐑樻櫖閻忕偟鏅灞解槈閹剧宸ユ慨妯稿姂瀵?
   * "闂佸搫鐗嗛ˇ鎶藉磿濡ゅ懎鐤炬い鏍ㄇ氶崑鎾存媴妞嬪海蓱闂佸憡鐟禍婊勬櫠閸噮鍤楅柛顐犲灮閸欐繈鏌ｉ妸銉ヮ仹缂佹梹鎸冲?闂侀潧妫楅崐浠嬪焵?*缂傚倸鍊甸弲娆戠博閺夋埈鍤曢柣妯哄级缁?*闂佸搫鍟崕濂稿磿濡ゅ懎鐤炬い鏍ㄧ懅閻熴垽鎮樿箛搴ｇ獢婵?*闂佸憡鑹鹃張顒勬儊椤旂晫鐟?*闂佹寧绋戦惌鍌炲磻閸涱垳鐭撶€广儱鎳撻崺宀勬煟濡粯鏋勭紒妤€顦靛畷锝夘敍濠靛棗骞嬮梺鍛婂灱濞咃綁鐛崶顒€违?
   *   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁鍡樺垔濞差亝鐒介柨婵嗘閽傚鎮?*婵烇絽娲︾换鍕汲閳?*濠电偞褰冮…鐑藉Υ婢跺簺浜归柕蹇曞Т缂嶄線鏌ㄥ☉妯煎婵☆偁鍊濋幃鎯х暆閳ь剙鈻?`onReverseMorph` 闁诲繐绻楁ご绋课ｉ崫銉㈠亾閻熸澘鏋︾紒杈ㄥ哺閸ㄩ箖寮悰鈥充壕?
   *     闂佹椿娼块崝宥夊春濞戞﹩鍟呴柤纰卞厴閳ь剚顭囬幏瀣Χ閸愶絽浜鹃悘鐐叉啞閸犳鈽夐幘绛规敾濠殿垱妞介獮宥夊箻瀹曞洨锛?婵炴垶鎸搁鍡樺垔濞差亜绀傞柟鎯板Г閿涙棃鏌ｉ妸銉ヮ仼闁汇劍绻堝Λ?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鍕瘞濠殿喗绻愮徊浠嬫偉閸洖违鐎广儱绻掔粈澶娾槈閹惧磭孝濠殿喒鏅濋埀顒傛嚀閸熴劑鍩€?
   *
   * ## 闂佸搫鐗滈崗娑氬垝閵娾晜鍎嶉柛鏇ㄥ墯琛奸柣?
   * ```
   *   闂佸搫鍟版慨鐑藉疾?pullMode            闂佹剚鍋呴崝蹇涘疮?闂佸搫鐗滈崜娆撍?闂佸搫瀚烽崹顖滅箔婢舵劕鍙婃い鏍ㄧ懅閻倕鈽夐幘鎰佸剱濠殿垱妞介弻鍥晲閸℃鎷柣鐘辫閸ㄥ崬顭囬悽鍛婂剭?闂佹寧绋掔喊宥咃耿娴兼潙妫橀悷娆忓閵?*闂佸憡鐟禍锝夛綖閿曞倹顥堥柣鎰綑椤や線鏌涢弬璺ㄤ虎闁告瑥妫濆畷锝夋晲閸垺顔嶉梺?*
   *                                 闂佹寧绋戦悧鎰帮綖?`onCollapseRequested`闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲秹鍩€椤掍胶顩烽柕澶堝妿缁犲鏌℃径鍫濆姎婵ǜ鍔戝?闂?闂佽　鍋撴い鏍ㄇ氶崑?
   *   闂佸搫鍟版慨鐑藉疾?PLAYER_ROOT_ID      闂佹剚鍋呴崝蹇涘疮?闂佸搫鐗滈崜鐔煎Υ婢跺簺浜归柕蹇曞Т缂嶄線鎮楅崷顓熷殌婵炲懏甯楃粙澶嬬節閸曨剛鏆?`.id(PLAYER_ROOT_ID)`闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嗗亾闁诡喗鎸荤粙澶愬焵椤掍焦濯寸€广儱娲ㄩ弸鍌炴煥?
   *   闂佸搫鍟版慨鐑藉疾?mySrcBox            闂佹剚鍋呴崝蹇涘疮?`expandState.barWinX/Y/W/H`闂佹寧绋戦悧鎰寲閻樿櫕濯撮柣妯挎珪閽傚鏌ょ€圭姵纭炬繛澶樺弮閹啴宕熼鐘茬倞闂佸憡鐟辩徊鍧楁偂閳哄嫨浜规い顐枤缁€濉縫闂?
   *   闂佸搫鍟版慨鐑藉疾?nav.pop(false)      闂佹剚鍋呴崝蹇涘疮?`state.isShowPlay = false`闂佹寧绋戦悧鍡涙晬閹炬湹娌?`popPlayerRoute()` 闂佹椿娼块崝搴♀枔閹达箑鍙?
   *                                 `pageIndexInfos.pop(false)` 闂?闂佸搫鐗滈崜娆忣潩?*婵炴垶鎸哥粔鎾偨椤愶絾濮滄い鎺嗗亾婵犙€鍋?*闂?
   *   闂佸搫鍟版慨鐑藉疾椤愶絽绶為弶鍫亯琚濋梺琛″亾?nav.pop()     闂佹剚鍋呴崝蹇涘疮?闂佸憡鑹鹃張顒勬偋鏉堚晝纾?`isShowPlay = false`闂佹寧绋戦悧濠囧垂濠婂嫮顩锋い鎺戝€归悾?pop 闂佽鍘界敮妤€螞閵堝棙濮滄い鎺嗗亾婵犙€鍋?闂?缂備焦绋戦ˇ顕€鎮抽鐐存櫖?
   * ```
   *
   * 闂佸疇娉曟刊瀵哥箔?`mySrcBox`闂佹寧绋戦悧鎰板礂瀹€鍕倞濠电姴瀚崣鎰喐闁附绶涚紒?*闂佸憡鐟禍婊冿耿椤忓洢浜归柕蹇曞Т缂嶄礁霉閸忛棿浜㈤柣锕佹椤曟瑩鎼归崷顓炵秳闂佸搫鍟悥濂稿闯濞差亜绀?*闂佹寧绋戝濉篹portMini` 闂?`barWin*`闂佹寧绋戦ˇ顓㈠焵?
   *   闂備焦褰冪换瀣箔婢舵劕绀嗛柣妤€鐗婇ˇ?`MorphShrinkState.start` 婵炴潙鍚嬫穱娲憘鐎ｎ喖绫嶉柣妯虹仛濞呮洟姊洪銊хɑ婵?`start skipped: no srcBox` 闂佽　鍋?
   *   闂佹寧绋戝濉縤sible=false` + `onDone()`闂佹寧绋戦ˇ顐﹀闯?闂備緡鍋€閸嬫捇鏌涢弽銊у闁?闂佸搫鍟版慨瀛樻叏閳哄懏鍋ㄩ悹鍥ㄥ絻瑜扮娀姊?闂?*婵炴垶鎸哥€涒晛螞閵堝鍋╃€光偓閳ь剙鈻撻幋锔界劵闁逞屽墴瀹曠娀寮介鍌滃敶閻庡灚婢樼€氼亞绮╅幘顔藉殜?*闂?
   *   闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅桼zdShrinkOverlay` / `root snapshot failed`闂?
   */
  private closeWithAnimation(): void {
    if (this.isClosing) {
      return;
    }
    // 同 `closeFullScreenPlayback()` 那条：打开期的逐帧内容 ticker 不认关闭请求，必须先掐掉。
    this.stopContentTicker();
    const winW: number = this.expandState.windowWidthVp;
    const winH: number = this.expandState.windowHeightVp;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂婎偄娲ら幊姗€濡磋箛娑欏仢濞村吋娼欏▍銈呪槈閹绢垰浜惧┑鐐叉灤閵堝懎甯梺鎼炲劚閿曪箓鎮￠埡鍕╀汗?* 闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕€危?闁哄鏅滈弻銊ッ洪弽顓炵闁规儼濮ら敍鏂棵归崗鑲╃叝缂佹顦扮€电厧顫濋鈧紞渚€鏌熺€涙ê濮堟俊顐犲€濆畷婵嬪Ω瑜庨弳?闂佹眹鍔岀€氼剛妲愰幋锕€绀傜紒娑樻贡缁€鍡涙煥?
    //   `barWinX/Y/W/H` 闂?`measureGeometry()` 闂佸憡鍔栭悷杈╂濠靛鍤€閻忕偟鏅弳?*闂佸憡鐟禍婊冿耿椤忓懐鈻旈柕鍫濇媼濡?*闁荤偞鍑归崑澶愭儍閻斿吋鍋ㄦい顓熷笧缁?
    //     閻?闂佸憡鑹剧€氼厼顭?opening 闁荤姳璀﹂崹鎵閻愮儤鍎嶉柛鏇ㄥ暉婢舵劖鐓傞煫鍥ュ劤缁€鍒瀖easureMiniDuringPull` 闂佸憡鍔曢幊姗€宕曢幘顔界劷闁挎繂妫欓拏瀣⒑閻愵剚瀚曠紒杈ㄥ哺閺?
    //     閻?**`refreshCollapseGeometry()`**闂佹寧绋戦悧濠偽涢锕€绀傞柟鎯板Г閿涙棃鎮规笟顖氱仩缂佸墎鍋ゅ畷鐑藉Ω閵婏箑闂梺褰掓涧椤戝棗顪冮崒鐐村仢濞村吋娼欏▍銈呪槈閹绢垰浜惧┑鐐叉濡插嫮妲愬璺何?
    //   闂?闂佸吋鐪归崕鎻掞耿娴兼潙绾ч梽鍥儗閻愵剛鈻?`barWin*` 婵炲濮寸粔宕囨嫻?0闂佹寧绋戦悧鍛閵夛缚绻嗛柛灞剧☉閳數鈧鍠掗崑鎾绘偣瑜庢竟鍡椻枔閹达箑鍙婃い鏍亹閸嬫捇鍩€椤掑嫬绀岄柡宥庡墰閻斿懐鈧灚婢樼€氥劑鍩€椤戞寧顦风紒顔惧Т閳讳粙鏁撻悩鍙夘仭闂佸憡甯楁刊鐣屾崲閸愵喗鏅鑸电〒缁€?
    //     `MorphShrinkState.start()` 婵炴潙鍚嬫穱娲憘鐎ｎ喖绫嶉柣妯虹仛濞呮洟姊洪銊хɑ婵?`start skipped: no srcBox` 闂佽　鍋?
    //     闂?**闁哄鏅滈弻銊ッ洪弽顓炵闁规儼濮ら敍鏃堟煕濞嗘兛鎴﹀垂?闂佸搫鍟版慨瀛樻叏閳哄懏鍋ㄩ柤濮愬€栫痪顖炴煙閹帒鍔滅紒澶愭敱瀵?**闂佹寧绋戦悧鎾诲磻閸涙潙鍙婃い鏍ㄨ壘鐠佹煡鎮峰▎搴ｎ槮婵炲弶鐗為妵鎰板箳閻愮數顦繛鎴炴尭缁夐潧危?濠电偛澶囬埀顒€寮堕崣蹇撯攽?闂備緡鍙忕徊鑲╃不閻愬瓨濮滃ù鍏肩懅缁€鍡涙煏?
    //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯?*闂佺儵鏅涢悺銊ф暜鐎靛憡瀚?`measureGeometry`**闂佹寧绋戞總鏃傜箔婢舵劖鍋ㄩ柕濠忛檮閿涘鏌?`refreshCollapseGeometry()` 闂佺偨鍎查弻锟犲焵?
    //      闂佸憡鑹惧锕傚焵椤掆偓閹虫捇宕靛鍛殰?`morphStage === OPEN` 闂傚倸鍋嗛悡澶屾濞嗘挻鐒婚柍褜鍓熷畷鐘诲冀閵娿儮鍙洪悗娈垮枓閸嬫捇鏌￠崘鈺傛瀯缂佸彉鍗冲?LANDING/NONE 闂?婵炲濮崑鎾斥槈閺傝法澧﹂柛蹇斏戠粙澶婎吋婢跺﹥顏￠梺鎸庣☉椤р偓缂?
    //      闂佸吋婢橀懟顖炲箵閳哄懏鍋傜憸鎴︽儗閹屽殫?*闂佸憡鐟禍顏勩€掗崜浣瑰暫濞达綀妫勯崢锟犳煕閵夈儻鍔熼柣鎾櫈閵?*闂佹寧绋戦悧濠偽涢锔藉剭?`morphInitParams`/`freezeMorphMeta` 闂佸搫瀚烽崹宕囧垝?
    //      濠电偞褰冮…鐑藉Υ婢跺本鍋橀柕澶嗘櫆閿涚喖鏌ｉ～顒€濡挎繛鍫熷灴閺佸秶浠﹂悙顒佸闁荤姳璀﹂崹鎵閻愬鈻旂€广儱顦版禒姗€鎮烽弴姘辩瓘缂佽鲸宀告俊?
    const measured: boolean = this.expandState.measureGeometry(this.getUIContext(), true, true);
    const srcBox: MorphShrinkRect = {
      left: this.expandState.barWinX,
      top: this.expandState.barWinY,
      width: this.expandState.barWinW,
      height: this.expandState.barWinH
    };
    // 闂佺绻楀▍鏇㈠箰闁秴缁╅柟顖嗗嫮褰滈柡澶嗘櫆閻熴倗绮╃€涙鈻旈悗锝傛櫇閻熸繈鎮烽弴姘鳖槮闁哥啿鍋撻梺鐓庮殠娴滄粍鎱ㄩ埡鍛哗闁兼悂娼ф禒姗€鏌涢幒鏇熺【閻忓浚鍨堕弫宥夊醇濠婂懐鎲?closeFullScreenPlayback 闂佸憡鑹炬總鏃傜博閹绢喖绾ч柍钘夋噽缁€?
    this.stopChromeAutoHide();
    this.isClosing = true;
    const closeToken: number = this.beginCloseGuard('snapshot');
    PlaybackPage.lastCloseAtMs = Date.now();
    // ★★★ 2026-10-18（定「系统返回关闭时两颗侧键瞬间偏一点」用）：**关闭起点那一帧的取值快照**。
    //   一次系统返回只打一行，grep 关键字 `RzdCloseFrame`。
    //   期望值（任何一项不满足，它就是"偏一点"的来源）：
    //     `cl=0`（此刻还没进形变，`pullBottomYVp()` 走 0 分支）
    //     `p=1.0000` / `cProg=1.0000`（`contentTweenOwned=false` ⇒ 内容窗口退化成 morphP）
    //     `pbIn=1.0000` / `pbY=0.00`（底栏已在落位，位移必须为 0）
    //     `pbOpa=1.000` / `chrome=1.000`（两处不透明度都满）
    //     `scale=1.0000` / `ty=0.00` / `radius=0.00`（静止展开态，无缩放/位移/圆角）
    //     `clipH == winH`（`morphClipping()` 翻真时 `.height()` 不该变，否则整页重排）
    Logger.info(PlaybackPage.logTag,
      `RzdCloseFrame sys-back stage=${this.expandState.morphStage} ` +
        `cl=${this.expandState.morphClipping() ? 1 : 0} usable=${this.expandState.morphUsable ? 1 : 0} ` +
        `p=${this.expandState.morphP.toFixed(4)} cProg=${this.expandState.contentProgress().toFixed(4)} ` +
        `pbIn=${this.expandState.pullBottomIn().toFixed(4)} pbY=${this.expandState.pullBottomYVp().toFixed(2)} ` +
        `pbOpa=${this.expandState.pullBottomOpacity().toFixed(3)} ` +
        `chrome=${this.expandState.pullChromeOpacity().toFixed(3)} ` +
        `scale=${this.expandState.morphScale.toFixed(4)} ty=${this.expandState.morphTy.toFixed(2)} ` +
        `radius=${this.expandState.morphRadius.toFixed(2)} clipH=${this.expandState.morphClipHeight.toFixed(1)} ` +
        `winH=${this.expandState.windowHeightVp.toFixed(1)} ` +
        `ctrlOffY=${this.expandState.chromeOffsetY().toFixed(1)} ` +
        `ctrlOpa=${this.expandState.chromeOpacity().toFixed(2)}`);
    // ★★★ 2026-10-20：快照路的同一条口径（`path=snapshot`）。
    //   期望：`overlayPaint=0`（拍快照前已 `snapshotShrinkOwned` 挡住克隆层）、
    //        `realCover` 这里的值是**拍之前**那一帧；快照成功后会 `beginSnapshotShrink()`
    //        把克隆层彻底关掉（见下方回调）。
    Logger.info(PlaybackPage.logTag,
      `RzdClosePath path=snapshot overlayPaint=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
        `realCover=${this.expandState.realCoverVisible() ? 1 : 0} ` +
        `target=(${this.expandState.barWinX.toFixed(1)},${this.expandState.barWinY.toFixed(1)},` +
        `${this.expandState.barWinW.toFixed(1)},${this.expandState.barWinH.toFixed(1)}) ` +
        `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(3)}`);
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂婎偄娴傞崑鍡涘矗鎼达絾宕夋い鏍ㄦ皑缁愮偤鏌涘▎妯虹仯闁轰降鍊濋獮鈧憸鏃堛€傞埡浣勬盯鍩€?* 闂佺偨鍎查弻锟犲焵?闁?`closeLiveMorphFallback` 闂佹眹鍔岀€氼剟宕规惔鈽嗘桨鐟滄垿顢氶埡鍛強閹兼惌鍨崇粈?
    //   婵炴垶鎸堕崐鎾绘煂濠婂牆绀堢€广儱妫楃徊褰掓煥濞戞瑥鐒归柟?闂佺厧鐤囧▔娑樷枖椤撱垺鍎楅柍杞版祰閸╁矂鏌ㄥ☉妯荤秮srcBox`闂佹寧绋戦ˇ鐢稿闯濞差亜绀嗗Λ棰佽兌閸熷﹪鏌ㄥ☉娆戔枔闁?缂備焦鍔栭〃鍛般亹濞戞矮鐒婇柛婵嗗閸ょ喖鏌￠崼婵愭Ц闁逞屽墰閵嗗妲愬渚籵rphShrinkState.start`
    //   闂佹眹鍔岀€氼亞鎮潏鈺冨崥妞ゆ牗鑹捐ぐ鍡欌偓娈垮枛缁绘﹢宕楀鈧畷銉╁礃閵娧勬疁闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婄兘骞戦姀锛勨枖闁逞屽墯缁嬪顓奸崱妤冧海缂備焦鏌ㄩ鍛潩閵娾晜鍎庨悗娑櫭径宥夋偣瑜岄崡鎶藉焵椤戣棄浜鹃梺鍛婄墬閻楃偤鎯岄幆褜鍤楅柛鏇炲缁€?*婵炴垶鎸哥粔鎾嵁閹捐绠€广儱顦禍婵堚偓娈垮枤婵敻寮悙纰樺亾鐟欏嫮顣查柣銉ユ嚇閹粙濡歌閻ｉ亶鐓崶璺轰簽闁?*闂?
    if (srcBox.width <= 0 || srcBox.height <= 0 || winW <= 0 || winH <= 0) {
      this.closeLiveMorphFallback(
        `noSrcBox meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
        `win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      return;
    }
    PlaybackPage.ev('CLO', `snapshot p=${this.expandState.morphP.toFixed(2)} ` +
      `meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
      // 閳?2026-10-17閿?閺堝妞傞崐娆庤⒈娑擃亜鐨濋棃?鐟曚浇鍏樻稉鈧▎鈥冲灲鐠囦紮绱氶敍姘Ω"鐠嬩礁婀悽璇茬殱闂?娑撳閲滈柌蹇氼唶鏉╂稐绨ㄦ禒鑸垫）韫囨ぜ鈧?
      //   `rc` = 閹绢厽鏂佹い鐢垫埂鐏忎線娼伴崷銊ф暰閵嗕梗oc` = 婢瑰啿鐪伴崗瀣畷鐏炲倸婀悽姹団偓涔s` = 鏉╂瑤绔撮崗鍐茬秺韫囶偆鍙庨妴?
      //   韫囶偆鍙庨幋鎰閻ㄥ嫭顒滅敮鍛娾偓浣哥安瑜版挻妲?`rc=1 oc=0 ss=1`閿涙稖瀚㈤崙铏瑰箛 `oc=1` 閳?韫囶偆鍙庨梻銊潶缂佹洝绻冩禍鍡愨偓?
      `rc=${this.expandState.realCoverVisible() ? 1 : 0} ` +
      `oc=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
      `ss=${this.expandState.snapshotShrinkOwnedFlag() ? 1 : 0} ` +
      `tint=${this.tintReady ? 1 : 0}`);
    Logger.info(PlaybackPage.logTag,
      `RzdShrinkOverlay closeWithAnimation: snapshot ${PLAYER_ROOT_ID} ` +
      `win=${winW.toFixed(0)}x${winH.toFixed(0)} ` +
      `bar=(${srcBox.left.toFixed(1)},${srcBox.top.toFixed(1)},` +
      `${srcBox.width.toFixed(1)}x${srcBox.height.toFixed(1)})`);
    // 闂佸疇娉曟刊瀵哥箔?闂婎偄娴傞崑鍡涘矗鎼淬倗鐤€闁告稒鐣埀顒€绻樺畷?*閻熸粏鍩囬崹纭呫亹婢跺鍤曢柍褜鍓氶幈銊р偓锝傛櫇椤撴椽鏌?*闂佺懓鍢茬粙鍕閺夋娼伴柕鍫濇噹閻撴繈鎮楅崷顓熷殌婵炲懏甯″浼搭敍濞戞鍩呯紓浣圭☉椤︻垵銇愭径鎰妞ゎ偒鍠氱粈鍕節婵為敮鍋撳畷鍥ㄧ秳闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲繐顓奸崨顓犲帓闂佹眹鍔岀€氼厽鏅堕悩璇插強?濠电姴艌閳ь剙纾宀勬⒑椤撱劎瀵肩紒鏃€娼欓?闂?
    //   闂佸疇娉曟刊瀵哥箔瀹ュ鐓ｉ柣娆忔噽閻?`restorePlaybackWindowChrome()` **婵炴垶鎸哥粔鐑藉礂?*闂佽　鍋撻柟顖嗗嫯鍚梺鐟板槻缁夋挳骞撻埡鍛亗鐟滃瞼绮婚敐澶婄?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯鈺冩娴兼潙绠掗柕蹇曞濡茶崵绱掗幇顓ф當鐟滅増绋撻弫顕€宕橀妸褎鎷?
    //     闂佹寧绋戝濉plyPlaybackWindowChrome(false,闂?`闂佹寧绋戦張顒€锕㈤悧鍫涗簻闁革富鍘界粣妤呮煕閿斿搫濡介柟鎼佷憾瀵劍銈ｉ崘锔瑰亾婢跺顕辨慨姗嗗幖鎯熺紓浣瑰姈椤ㄥ懓銇愬☉銏＄叄闁告繂瀚悡鍌炴煛娴ｅ壊鍤熼柣娑栧劦閺佸秵寰勫☉姘鳖槷
    //     闁汇埄鍨伴崯顐︽儑椤掍胶鈻旈柍褜鍓熷畷锝咁潨閸垻顦梺鐟板槻缁夋挳宕哄畝鍕剭闁告洦鍋呴惃鎴濃槈閹惧磭校婵?濠电姴顭槐鏇㈡偘閵夆晜鐒介柨婵嗗椤忚京鈧?闂侀潧妫楅崐椋庣箔瀹€鍕睄鐟滄垿鎯岄幆褜鍤楅柛鏇ㄤ簽椤忛亶鏌ら悿顖涘涧缂?*闂佽　鍋撻悹楦挎閸熸煡鏌￠崘顓炵厫濠⒀呭█楠炰線濮€閻欌偓濡?*闂?
    // 闂佸疇娉曟刊瀵哥箔瀹ュ鐓ｉ柣娆忔噽閻?2026-10-17闂?*闂佹椿娼块崝宥夊春濞戙垹绠ｆい蹇撳缁傚牓鏌￠崱妯诲唉婵犫偓閸洘鍎嶉柛鏇ㄥ幗閸?bug**闂佹寧绋掗惌顔捐姳閵婏妇顩烽柤绋跨仛閿涘鐓?`CLO:闂?fb=snapFail` 闂?闂婎偄娴傞崑鍡涘矗?*濠殿噯绲界换鎴︻敃婵傚憡鐒鹃柦妯侯槶娴滃ジ鎮?*闂?
    //   婵炲瓨绮岀€涒晛危缁嬪晝鎺曠疀鎼达綆浼囧┑鐐叉灤閵堝洨顔夐梺鎼炲劤閸嬫盯宕ｈ濮婂顢橀姀鐘插箣闂備緡鍋€閸嬫捇鏌涢弽銊уⅹ闁糕晛鑻叅濠电姵鍝庨埀顒€顦抽妵鎰板閻樿尙绉?闂?**闂佹椿娼块崝宥夊春濞戞瑧顩烽幖娣灪闂勫秵绻涘畝瀣？婵犫偓閸涙潙绀嗛柟宄扮灱缁犳牠鏌￠崘顏勑ラ柡鍜佸亰閺屽洭鏁愰崱妯挎嫬闂婎偄娴傞崑鍡涘矗鎼淬劌缁╅柛鎾茶兌缁?*闂?
    //   婵炲濮甸悧妤佹叏閵堝鍎?闁诲繐绻嬬欢姘焽娴兼潙妞界€光偓閸愩劌澹掗梺鍝勬媼閸ㄧ數鎹㈤弴銏犲強妞ゆ牗鐟ч杈ㄤ繆椤栨せ鍋撻懠顒変紘闂佸搫绉归ˉ鎾斥枔閹达附鈷掓い鏇楀亾妞?闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棗閰ｉ崵瀣煥濞戞﹩妲堕柍?
    //   闂佸搫绉堕幊鎾趁哄鍫熸櫖?*闂佺懓鐡ㄩ崹鍐差煥閹寸姵瀚柛鎰典簼閻ｉ亶鏌￠崟闈涚仩闁告瑥绻掓禒锕傚焵椤掑嫭鐒介柨婵嗗閸ゅ鈧懓鎲¤ぐ鍐姳閹屽殨闁告劦浜濋悾閬嶆⒑閹绘帞啸婵?*闂侀潧妫旂换鏈刼hos.arkui.componentSnapshot.d.ts`
    //   `function get(id, callback, options?)` 闂佸搫绉村ú銊ヮ焽?**`@deprecated since 18`**闂侀潧妫斿鎺旂箔閺嶃劌顕辨慨姗嗗幖椤?
    //   `100001 - Invalid ID`闂佹寧绋掔粙鏍焵?*婵炴垶鎸搁敃銉╂偉閸洘鍋ㄩ柕濞у嫮鏆犻梺?`UIContext` 闂備緡鍙忕徊鑲╃博閹绢喖缁?*闂?
    //   `wujie.pa:171077-171093`闂佹寧绋戝濉抣ayerPage.closeWithAnimation` 闂?濞达絽绉归弫宥嗗緞閹般劌浜鹃柟閭﹀幗閽傚鎮峰▎娆戝埌闁搞値鍙冨鍫曞Ψ閿旇濡ч梺?
    //   ```ts
    //     this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 濞达絽鍕?*#)
    //   ```
    //   闂?闂佺粯绮嶅妯猴耿椤忓牊鍋傜憸宀€绮崒姘モ偓鎺楀箹娴ｉ晲绨兼繛鎴炴尨閸嬫捇鏌℃径鍡楀⒉闁轰礁銈稿畷妯衡枎濞嗘垹顦╅梺鍝勭墱閸撴岸寮搁崘鈺冾浄?L3464 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴娲ゅ▍?*闂佸搫鍟犻弲娑橆潩閵娾晛绀冩繛鍡樺灦缁?*闁哄鏅滈悷銈夋煂濠婂棎浜归柕蹇嬪灩绗戦梺鎸庣☉婵傛棃宕鍕剺濞达絿顭堢粊杈ㄧ箾鐏炲嫨鍊楅鈧繛鎴炴尭椤厾妲愬璺何?
    //   闂?婵犮垺鍎肩划鍓ф喆閿曞倸鍌ㄩ柣鏃堟敱缁€鍫ユ煟閹炬瀚敍瀣级閳哄倻鈼ョ紒銊ｅ妽缁傛帡鎳滈崹顐礆闂婎偄娲﹂〃鎰濠靛宓?*闂?err.code 婵炴垶姊婚崰搴ㄦ偨椤愶絿鈻?*闂佹寧绋戝濉産=snapFail(100001)`闂佹寧绋戦¨鈧紒?
    //     401 = 闂佸憡鐟ラ崐褰掑汲閻斿吋鐓?/ 100001 = 闂佸綊娼цぐ鐐电箔婢舵劕绀嗛柟宄扮灱缁犵懓鈽?id 闂?婵炴垶鎸撮崑鎾寸箾閸″繐澧查柛鈺佹嚇瀹曞爼骞嗚缁侇噣鏌涘▎妯虹仩闁伙絽澧介幏瀣箒閹哄棗浜?
    this.closeDiagnostic('snapshot-request');
    let snapshotReturned: boolean = false;
    try {
      this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID,
      (err: BusinessError, pixmap: image.PixelMap): void => {
      if (snapshotReturned || !this.ownsClose(closeToken, 'snapshot-callback')) {
        this.closeDiagnostic('stale-callback-dropped event=snapshot-callback');
        if (pixmap !== undefined && pixmap !== this.morphShrinkState().pixmap) {
          this.releasePixelMapQuiet(pixmap);
        }
        return;
      }
      snapshotReturned = true;
      this.closeDiagnostic(`snapshot-callback ${(err === null || err === undefined) && pixmap !== undefined ? 'ok' : 'miss'}`);
      if (pixmap === undefined && (err === null || err === undefined)) {
        this.closeLiveMorphFallback('snapshot-empty');
        return;
      }
      // ★★★ 2026-10-18（用户第十轮：「收起过程中**按钮/封面又成了两个**」）：
      //   快照已经进手 ⇒ 接下来屏上由**快照层**代表一切（`beginSnapshotShrink()`），
      //   页面上那颗真封面必须让位，否则就是"快照一颗 + 真封面一颗"。
      //   ⚠️ 只在这一刻（回调里）才置真——不能在 `get()` **之前**置，否则快照本身没有封面（上一轮的病）。
      if (err === null || err === undefined) {
        this.snapshotFlight = true;
      }
      // 闂佸啿鍘滈崑鎾绘煃閸忓浜?闂佸湱绮崝鎺戭潩閿曞倸绀傞柟鎯板Г閿涙棃鏌￠崘銊ヮ暢婵?*闂佸搫鐗滈崗娑氬垝閵娾晜鍋嬮悷娆忓缁犳帡鏌￠埀顒傛崉閾忕懓鏆?*闂佹寧绋戦悧濠偽涢妶澶嬪仼閻忕偛澧藉楣冩煛?濠电偛鑻ˇ浼寸叓閸垻鐜绘俊銈傚亾鐟?闁哄鏅滈悷銉┿€冨鍫熸櫖閻忕偞鍎抽。鎻捗归悩顔煎姎闁伙絿濮撮埢浠嬪焺閸愨晝鐣抽柡澶嗘櫆閻熴倗鎮柆宥呯煑闁靛鍨崇粈?
      //   闂?闂佽鍘归崹褰捤囬懠顒€瀵查柤濮愬€楅崺鐘绘煛?缂備焦鍔栭〃鍛般亹?chrome 闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥粔鍨椤旇棄绶炵€广儱娲﹂悾閬嶆偣閸ャ劎绠氱紒缁樺灴瀹曞爼鎮欓幓鎺戠稑闂傚倸鍋嗛崢铏圭不閿濆瑙﹂幖娣妸閳ь剙锕鍊熺疀鎼达絿鐛ラ梺绋款儐缁苯锕?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柛顭戝亞閻掕姤绻?闂備緡鍙忕徊鑲╃博鐎涙闄勬俊銈呮噹鐢娊鏌ょ涵鍜佸殝缂?
      //   闂?`morphLand()` 婵炲瓨鍤庨崐娑氭崲閺囩姷纾兼俊顖氭惈閻撴垿鏌?闂?闁哄鏅炲〒鍦礊濮椻偓瀵?*闂佹椿浜為崰鏇㈡?*缂備焦鏌ㄩ鍛村春閵忋倕鍙婇柟顖嗗啯鐦旈梺?
      //      闂佹寧绋戦悧鍛箔婢跺顩查柕鍫濈墢缁犵兘鏌ｉ妸銉ヮ伂闁伙妇鏅幉鐗堟媴閾忚鎯ｅ┑鐐存儗閸犳牠鎯囬弶澹冲酣鍨鹃崘鍙夌様 闂?50ms 婵炴垶鏌ㄩ鍛村箖濡ゅ懎绠ョ€广儱娲︾粻娆撴煕閹烘挸顎滅紒顖滃У閹峰懘鎮╅搹顐ユ嫬"闂?闂侀潻闄勫姗€宕甸銏″仢閻㈩垼鍠氱粈鍡涙煏?
      //   闂佸疇娉曟刊瀵哥箔?`morphLand()` 闂佺娉涢敃锕€霉婢跺濯寸€广儱娲ㄩ弸?`LANDING`闂佹寧绋戞總鏃傚緤閹屾桨闁靛牆鎳庨悡?`morphP = 1`闂佹寧绋戦悧鍡涘垂?`refreshCollapseGeometry`
      //      闂佸憡甯為弻澶屾崲閸愵喗鏅璺烘濞?闁诲骸婀遍幊鎾斥枍?`.height(morphClipHeight)` = 闂佽桨绀侀顓㈡偘閵夆晛违濞戞棏鏌焎ale = 1` = **闂佽鍘界敮鐐烘偤?*
      //      闂?闂傚倸妫欓崕濂革綖閸ヮ剙绠涢柣鏂垮槻缂嶄線鏌涢弽銊у缂佽精椴搁幏鍛村即閻愬弶鐎搁梻?1~2 闁汇埄鍨庨崒婊呮啰闂傚倸鐗勯崹鑲╂崲閺囥垺鍎庨柡宥庡亝缁茶鈽夐幘宕囆ч柍褜鍓欑换鎴澪ｉ幋锔藉剭闁告洦鍋呰ぐ銉╂煟閹炬瀚惂渚€鎮橀悙鎻掆偓鍫曞焵?
      //   闂佸疇娉曟刊瀵哥箔?**婵犮垺鍎肩划鍓ф喆閿曞倸缁╂い鏍ㄧ懅閻熸繈寮堕埡鍌滎灱缂佺粯鐗楃粙澶愬焵椤掑倵鍋?*闂佹寧绋戦悧鍡涙偩閻樺灚鍟哄ù锝呪偓鐔稿发闂備緡鍋€閸嬫捇鏌涢弽銊у⒊闁活厽鍎抽銉╁礋閸撲胶顦梻渚囧弿缁叉儳顪?`morphLand()` 婵炴潙鍚嬬喊宥嗕繆閹间焦鍎庨梻鈧幇顔拘㈤梺鍦帛閸旀洘鏅堕悩鐢电缂備焦锚缁旀挳鏌?
      //      闂?`closeFullScreenPlayback()` 闂傚倸娲犻崑鎾绘偡閺囨碍顦风紒?闁哄鏅滈敋婵犫偓椤忓棔娌柡鍥╁仧绾惧鏌?闁荤姍鍥ㄦ暠濠⒀勭矒閺佸秵寰勯崱妤侇仸 闁荤喐鐟ゅ鎺旂箔閸涘瓨顥?`if` 闂佹眹鍔岀€氼亞绱為崨顖滅＞妞ゆ棁銆€閸?
      if (err !== null && err !== undefined) {
        Logger.warn(PlaybackPage.logTag,
          'RzdShrinkOverlay root snapshot failed, fallback: ' + JSON.stringify(err));
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂佸搫鐗滈崗娑氬垝閵娾晛绀嗙紓浣姑竟鍫ユ煟閵娿儱顏╅柛銊ラ椤垼顦撮柛?*闂佹寧绋戦¨鈧紒鍙樺嵆瀵噣鎮╅崹顐ｇ彧闂佹眹鍔岀€氼剟濡甸幋鐘冲闁靛闄勯弳婊堟煛?`nav.pop()`闂佹寧绋戦悧濠偽涢妶鍡樺妞ゆ巻鍋撴繝褉鍋撻梺鎸庣☉椤р偓缂?
        //   闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡樻尭濞咃繝姊洪鐔蜂壕闂?*闂佸搫鐗滈崗娑氬垝閵娾晛绫嶉柕蹇婂墲缁犳帡鏌ｉ妸銉ヮ仾婵＄偞瀵ч妵鍕濞戞粌鐓傞梺?*闂佹寧绋戝濉﹍oseFullScreenPlayback()`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婂骞冩繝鍥ㄥ仺闁规彃顑囩粣?
        //   閻?闂佸搫鍟版慨鐑藉疾椤愶箑绠€广儱娲﹂悾閬嶆煛?`PLAYER_ROOT_ID`闂佹寧绋戦悧鍛博鐎涙鈻旀い蹇撴噺閻濐噣姊?Stack闂佹寧绋戦¨鈧紒閬嶄憾楠炲骞嬪鍕嫧闂佺懓鍢茬粔璺衡枔閹达箑鍙?**`NavDestination(DIALOG)`
        //     闂備焦褰冮惉鐓庘枔閹达附鍤嶉柛灞剧矊娴?*闂佹寧绋戦惌浣烘崲閺嶎厼绾ч柍鈺佸暢椤╊偊鏌＄仦鐐磩闁活厽鍎抽銉╁礋椤掍絿?*闂佺懓鐡ㄩ崹鍐差煥閹达附鍋嬮悷娆忓缁犳帡鏌?* 闂?婵炴垶鎸撮崑鎾绘煛?`componentSnapshot` 闂侀潻璐熼崝蹇曟崲閺嶎厼绾ч梽鍥儗閻愵剛鈻?
        //     缂備緡鍨靛畷鐢靛垝濞差亜绠戠憸宥堛亹閸ャ劎鈻旂€广儱鎳庨悡鍌炴煕閵夛附瀚曠紒?*濠殿噯绲界换瀣博閺夋垟鏋庨梽鍥╂崲閹达箑鐐婇柣鎰絻瑜扮娀姊?*闂備緡鍠楅崹婵堟娴煎瓨鐒婚柍褜鍓熷畷鐘诲冀閵娿儳浜?婵＄偑鍊楅弫璇差焽娴煎瓨鍎庨悗娑櫭径宥嗙箾閹存繄澧曢柕? 闂佺偨鍎查弻锟犲焵?
        //     闂備緡鍙忕徊鎯ｇ粙鍟?闂佺厧鍟块張顒€鈻嶅▎鎾崇煑妞ゅ繐瀚埛鏍р槈閹绢垰浜鹃梺?婵炴垶鎸堕崕鐢稿闯缁嬫鍤楁俊銈傚亾妞わ箑娼￠幆鍐礋椤愩垼顔夐柣鐔哥懁缁€浣该洪弽顑句汗闁硅櫣鍋熼獮?
        //   閻?濠电偞褰冮…鐑藉Υ婢跺簺浜归柕蹇曞Т缂嶄線鏌￠崼顐㈠⒉闂傚ň鏅犲?*閻庤鐡曠亸顏堬綖閿曞倹鍋ㄩ柕濠忕畱閻撴洜鐥褍鏋︽い鎾愁煼瀹曪綁顢涘鍕**闂佹眹鍔岀€氫即宕戦崨顔锯枖闁逞屽墯缁鸿棄螖鐎ｎ剛顦╅梺鍐茬壄閹靛啿浜鹃悘鐐跺亹閻熸劙鏌熷畡閭︽Ч濠⒀嶇畱椤曪綁鍩€?婵炴垶鎸搁鍡樺垔濞差亜绀傞柟鎯板Г閿涙棃鏌ｉ妸銉ヮ仼闁汇劍绻堝Λ?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鍕瘞濠殿喗绻愮徊浠嬫偉閸洖违鐎广儱绻掔粈鍡涙煥?
        //     闂備緡鍋€閸嬫捇鏌涢妷褍浠滄鐐存崌瀵敻鍩€椤掑嫬閿ら煫鍥ф捣閻﹀秹鏌涘▎妯圭凹婵″弶鎮傚畷鍫曟倷閹绘帞鍘掗梺鍛婎焽閸犳劕顭囬悽鍛婂剭闁告洦鍣搴ㄦ煙閹殿喖鏋旈柟韫嵆閹潡鎮欓崗澶婁壕?
        //   闂佸疇娉曟刊瀵哥箔?婵犮垺鍎肩划鍓ф喆閿曞倸鍌ㄩ柣鏃堟敱缁€鍫ユ煟閹炬瀚敍瀣煙?`Logger.warn`闂佹寧绋戦懟顖炴嚐閻旂厧绠┑鐘插€搁弬褔鏌涢妷褍孝闁汇埄鍋呭璇测槈濡ゅ啰娈ゆ繛瀵稿Ь閸╂牕螞閳哄嫮鐤€婵°倕顑囩粈鍒濩LO` 闂?`fb=`闂佹寧绋戦¨鈧紒?
        //     **婵炴垶鎸撮崑鎾寸箾閸″繐澧查柛鈺佹嚇瀹曞爼骞嗚缁侇噣鏌涘▎妯虹仩闁搞劎鏅幏?*闂佹寧绋戦悧鎰帮綖?`closeFallbackReason`闂佹寧绋戦ˇ顓㈠焵?
        this.closeLiveMorphFallback(`snapFail(${err.code})`);
        return;
      }
      this.restorePlaybackWindowChrome();
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*婵烇絽娴傞崰姘跺极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓懟顖炲矗瑜斿濠氼敇閻斿壊妲繛鏉戝悑閼归箖宕甸銏″仢濡娴囬埛鍫濃槈閹垮啩绨婚柣銊︾箞濡啴锝為钘変壕?*闂?
      //   闂婎偄娴傞崑鍡涘矗鎼粹槅鍟呴柤纰卞墰閻ュ懘鏌熷畡鎵㈤柛鈺佹湰缁傚秹宕卞Δ鍐╊唸闂傚倸鐗滃浣烘濠靛鍤€閻忕偠鍋愰悷鎾绘⒒?`morphLand()` 婵炴潙鍚嬬喊宥嗕繆閹间焦鍎庨梻鈧幇顔拘㈢紓鍌氬枤閸犳宕?`LANDING`
      //   闂佺偨鍎查弻锟犲焵?`LANDING` 闂?`morphContainerActive()` 闂備焦褰冮惉濂告偩?闂佹椿浜為崰鎾斥枔閹达箑鎹堕柕濠忛檮鐏? 闂?婵犮垻鎳撻崯鍧楁儑娴兼潙绀傞悗锝庡枟閻ｇ兘鎮橀悙鎻掆偓椋庢閹殿喗鍋栨い鎰剁畱娴滄繈鏌?
      //   闂佺儵鏅犻弲鑼礊閸涙潙绀傛繝濠傚暟娣囨椽鏌涘▎妯轰函闁圭櫢缍佸?闂?**闂婎偄娴傞崑鍡涘矗鎼淬劍鐓傜€光偓閸曨偂绨奸悗娈垮枤婵挳鎯冨┑瀣棃?+ 闂佺绻愰澶娾枔閺囩姳娌柛宀€鍋涙禍婵堚偓娈垮枤婵挳鎯冨┑瀣棃闁靛繒濮甸崐閬嶆煛閸愩劎鍩ｆい?* = 婵炴垶鎸堕崐鎾绘煂濠婂懍鐒婂〒姘ｅ亾婵為棿鍗虫俊?
      //   闂?闂?`morphLand()` **婵炴垶鏌ㄩ鍛櫠?*婵犮垹婀辨晶妤€危?闁哄鏅滈悷銈囩博閹绢喖绀傞柛鎰皺缁夋椽鐓崶璺轰簽闁?闂佹寧绋戦張顒傛嫚閻愬吀娌柛宀€鍋為敍宀勬煥濞戞ɑ缍乵orphOverlayBridging`闂?
      //     闂傚倸鎳庣换鎰板箖濡ゅ懎绠掗柟鐑樺灣濞寸兘鏌曢崱妤€浜扮紒杈ㄧ懇瀹曪綁顢旈崟顒冨惈闂婎偄娴傞崑鍡涘矗鎼淬劌绠ｉ柟閭﹀墮椤娀寮堕埡鍌滄噥缂佹梹鎸冲銊╊敍濮樺墽鐭楅梺鍝勫閸戠晫妲愭潏銊ョ窞閺夊牜鍋夎闂佽　鍋撴い鏍ㄧ箥濞诧綁姊洪鐔蜂壕闂佹悶鍎抽崑鐐差渻閹稿簺浜滈梻鍫熺閸╁矂鏌涘▎鎰跺叕缂佽鲸绻冪粋鎺戭吋婢跺绮柣鐔告磻閻掞妇鎷犻悙鍏告勃闁稿本菤閸嬫捇宕掗敂鍓ь槴
      this.expandState.beginSnapshotShrink();
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍?*缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧梺绋跨箲婵炲﹤螞閹绢喖绠绘い鎾跺枑閺夊綊鏌涢敐搴ｅ帨缂佽鲸绻堥獮姗€顢橀悢鍛婃緬闂佸搫顧€缁绘繈宕戦崨顔锯枖濠㈣泛顦甸崵瀣煙缁嬫妯€闁瑰憡濞婂畷娆撴惞閻熸壆鐤€闂佹眹鍔岀€氼厼锕㈡笟鈧幃娆戞喆閸曨剨绱炴繛?*闂侀潧妫楃粙鍕?
      //   闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞?*缂備焦鏌ㄩ鍛村春?* `morphLand()` 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯?婵炲瓨鍤庨崐娑氭崲閺囩姷纾兼俊顖氭惈閻撴垿鏌?闂?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁嶉崟顒€鐒搁梻濠庡墻閸嬪懎螣婢舵劕绀勯柣鎴炆戦梽?闂備緡鍙忕徊鑲╃博閺夋埈娼伴柕澶樺灣缁€?
      //   婵炲瓨绮岀€涒晛危濮濆瞼鐤€妞ゆ劑鍊曞楣冨级閳哄伒鎴︽儉閸涱垳纾介柍杞拌兌閺嗘岸鏌ㄥ☉妯煎濠?50ms闂佹寧绋戦¨鈧紒杈ㄧ箖閹棃寮村杈╂啴闂佹眹鍔岀€氼垳鍖栭悩铏闁绘娅曢拏瀣煥濞戞澧曢柟顖氱墦閺屽洭鏁愰崟顓犳啨婵炴垶鎼╂禍婵堚偓鍨矒閺岋箓顢氶崱娆戭槴闁诲繐绻愬畷顒勫礄閿涘嫮纾奸煫鍥ㄧ⊕閼荤喖鏌涢幋鐘插妺婵炵厧鐏氱粋?
      //   闂?闁荤喐鐟ラ崐褰掑礉?闂佸湱顭堥ˇ鐢稿箰閹惰棄绀傞柛顐ｇ箓濮ｅ鏌ｅ鍡楃劷闁逞屽厸缁€渚€鎯冨┑瀣棃闁靛繒濮甸崐鐢告煢閳ь剟骞嬮幒鏃傂?闂?
      //   闂?闂佺懓澹婃禍婊堝春瀹€鍕哗闁告挷鑳剁槐?*缂傚倷鐒﹂幐璇差焽?*闂佹寧绋戝濉籬rink.start` 闂?onDone闂佹寧绋戦惌渚€锝為崱妯尖枖閻庯絽澧庣粈鍡涙煏閸℃鈧晫鎹㈤弽銊р枖闁逞屽墰閹瑰嫰顢涘▎鎴犳啰闂佺儵鏅犻弲鑼礊閸涱喚鈹嶆繝闈涙搐閻?ENTERING/LEAVING闂?
      //     `realCoverVisible()` 婵炴垶姊婚崰搴∶哄鍐炬桨闁靛牆娲﹂崺娑氱磽娓氬洤寮ㄦい鏂哄亾婵炶揪绲界粙鍕濠靛洨鈻旂€广儱瀚粣妤呮煕閹邦剛孝闁哥喎顑夊畷娆撴惞鐠団€冲壋婵炲瓨绮岄懟顖滄閸撲椒鐒婂〒姘ｅ亾婵為棿鍗虫俊?
      //   闂佸疇娉曟刊瀵哥箔?`morphLand()` 闂佸憡鐟禍婊勬櫠?闂佺儵鏅犻弲鑼礊?闂?LANDING + 婵炲瓨鍤庨崐娑氭崲閺囩姷纾兼俊顖氭惈閻撴垿鏌?婵炴垶鎸堕崐鎾斥枎閵忥紕顩查悗锝呭缁€澶愭煛?350ms 闁荤姴顑呴崯顖炴儉閸涙潙瀚夊璺猴工椤ュ苯霉閿濆棛鐭岄柡浣靛€濇俊?
      const shrink: MorphShrinkState = this.morphShrinkState();
      this.closeDiagnostic('shrink START');
      shrink.start(this.getUIContext(), pixmap, srcBox, winW, winH, (): void => {
        if (!this.ownsClose(closeToken, 'shrink-finish')) {
          return;
        }
        this.closeDiagnostic('shrink FINISH');
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠?`MainPage` 闂備緡鍙忕徊濂告煂?**onDone 濞达絽鍕?2*#**闂佹寧绋戦悾鐡€ujie.pa:154940-154949`闂佹寧绋戦¨鈧紒?
        // ```ts
        //   () => { this.miniHidden = false; this.shrinkPixmap = undefined; }
        // ```
        //   閻?`miniHidden = false` 闂佺偨鍎查弻锟犲焵?闂佸搫鐗滈崗娑氬垝閵娧€鍋撻悽鍨殌缂併劍鐓￠幆鍐礋椤掍絿?闁哄鏅炲〒鍦礊濮椻偓瀵?*闂佹椿浜為崰鏇㈡?*闂佸憡鐟崹鐢革綖?闂?
        //     闁诲繐绻楁ご绋课?`morphLand()`闂佹寧绋戦悧鍛潩閿旇姤浜ゆ俊顖濆亹鐢盯鏌涢幒鏇炵厫婵炵厧鐗撻弫宥嗗緞閸艾浜?*闁诲海鎳撻崯顐ゆ崲閳ь剙顪冮妶鍫殭婵犫偓椤忓牆缁╅柛鎾茶兌缁辨氨绱撴担瑙勫鞍婵炵⒈鍋呭璇测枎鎼达綆浼囬梺?*闂佹寧绋戦惌渚€锝為崱妯尖枖濠电姴娲﹀銊╂煟閵娿儱顏い鏇楁櫊瀵増鎯旈婊冭€?
        //   閻?`shrinkPixmap = undefined` 闂佺偨鍎查弻锟犲焵?闂?**闂婎偄娲ら幊姗€濡磋箛娑樼；?*闂佹寧绋掑畝鎼佸磻閸涙潙鍙婃い鏍ㄧ懅椤忚京鈧?*濠电姴顭槐鏇㈡偘?* PixelMap
        //     闂?080闁?400闁?B 闂?10MB 缂備胶瀚忓鍥╊槴闂佹寧绋戦懟顖炲矗閳╁啰顩叉い鎰╁€曠瑧闂佽鍏涘鎺旂博閹绢喗鍎庨柡澶嬪灩缁屽潡鏌ｉ～顒€濡挎繛鐓庡暟閳ь剛鎳撻崯顐㈩潩閵婏妇鈻旂€广儱瀚粣妤呮偠濮樼厧浜滄繛鍙夌墵瀵劑鐓ù瀣壕?
        //     婵炴垶鎸搁敃锝囩博閹绢喗鍋?*濠电姵娲栫换瀣姳閳╁啯浜ゆ繛鍡楁捣椤忛亶鏌?* 闂?濠殿噯绲界换鎰板矗瑜庣粙澶愬焵椤掆偓閳诲酣鍩勯崘鈺佸晩闂佽　鍋撻柟顖嗗嫮褰滈柣蹇撶箰瀹曨剟藝閸ф鍋╂繛鍡楁捣椤忚京鈧鍠氭刊瀵告濞嗘挻鍎庨柡澶嬪灥閻撳倸鈽夐幘鎰佸剮缂佹梹娼欓埢搴ㄥ灳閸愭彃缍橀梻鍌氬亞閸樿姤鏅堕悩鍨仏妞ゆ劑鍎哄ú顒勬煟閳哄倻澹勭紒杈ㄥ哺婵?
        Logger.info(PlaybackPage.logTag, 'RzdShrinkOverlay onDone (overlay hidden, pixmap dropped)');
        //   闁靛棗鐬奸弫銈囧寲閼姐倗鍩犻弶鈺傛煥濞叉牠宕楅幎鑺ワ紨闁挎稑鑻慨鈺呮偨閼姐倗娉㈤柡澶屽枔濞堟垿寮捄琛″亾濞嗘帒鍓归柡鍜佸灠娴犵娀宕烽妸锔芥嫳闁哄鍎冲▓鎴烇紣濠婂棗顥忛柨娑樼灱閸斞囧触?*缂佹劒鑳堕崝褔宕ｅΟ璇茬亣闁诲繑濯芥竟?*闁靛棗绋勭槐?
        //   闁告鍠庡ú婊堟晬濮濇orphLand()` 闁硅泛锕﹀ù澶嬫媴瀹ュ洨鏋傞柟?`LANDING` 闁?`morphContainerActive()` 濞寸姴绉崇拹鐔兼儑?
        //   闁?鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞呮帞绱掕閻㈣崵鎮?`morphClipHeight()` 閻熶椒鐒﹂崹姘▔閳ь剟寮舵幊閳ь兛姊桵eshCoverBg` 闂侇叏绲肩粩瀵镐沪閸屾繄顎€闁活偀鍋撻悶姘煎亯椤ュ棝骞?闂佹彃绉寸紓?
        //   闁?闂傚洦褰冮崵顓犫偓鐟般仒鐎靛矂鎯冮崟顏嗙憹闂侇偄绻戝Σ鎴炴償閺囩偤鐛撻柤纭咁嚋缁辨獋defaultImageBgColor` = 婵烇綀浜导鍡涙晬? 闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣?缂佹劒鑳堕崝褔宕ｅΟ闂寸礂"闁?
        //   濞戞挸锕ラ悥鍫曟焽閿濆嫰鍤?`onDone 娴ｅ硺闁挎稑娼墂ujie.pa:154940-154949`闁挎稑顦ぐ褔宕戝顐モ拡濞寸姵婀圭花銊╂晬?
        //   `miniHidden = false` + `shrinkPixmap = undefined` 闁炽儲鏌￠埀?**婵炲备鍓濆﹢?*"闁硅泛锕ュ鎸庛亜闂堟侗妲诲ù?閺夆晜鐟ょ粩鏉戭潰閵夘垳绀?
        //   闁搞儳濮崇拹鐔衡偓鐟板暟濞堟垶銇勯悽鍛婃〃闁革负鍔岄幓鈺呮偂瑜戦幑锝夊级閵壯勭暠闁告艾濂旂粩鎾礆鐠囧弶鐨戠€规瓕灏欑划?pop 闁瑰搫顦花锟犲Υ?
        //   闁?閺夆晜鐟╅崳鐑藉触鐏炲墽澹夐柛娆樹簼缁?pixmap闁挎稒绋撳ù澶嬫媴?闁告垹濮崇紞宥夋儍閸曨偒妲诲ù锝呯С濮橈妇绱?`onDisappear 闁?morphReset()`
        //     闁挎稑鐗撻崑鍛村及椤栨瑧绐楅悹鍥ㄧ箓閺侇喗绋夐埀顒勬儍閸曨偒妲诲ù锝呯Ф閸嬶綁鏁嶅畝鍐炬綄 `morphReset` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柕?
        shrink.clearPixmap();
        // 濠电偞鎯岄崰鏍儑娴兼潙缁╅悹楦挎閸熸煡鏌ㄥ☉妯煎濠?50ms闂佹寧绋戦ˇ顔剧不閿濆瑙﹂幖绮光偓铏珒闂佽　鍋撻柟顖嗗懐锛涢梻鍌氬€归幃鍌毼涢鍕櫖婵﹩鍙庨崝鈧柣銏╁灡閻℃洟鎯岄幆褜鍤楅柛鏇ㄤ簽閻熸捇姊洪銊хɑ婵＄偛鍊归妵鍕偨閸涘﹥銆冮梺鍝勫暊閺呮盯宕欓敍鍕仏?pop闂?
        // 闁哄鏅滈悷銈囩博閹绢喖鐭楅柕澶堝劚濞懷囨煛?婵炴垶鎸稿ú锝囩博閺夋垟鏌?pop 闂?闂佹眹鍔岀€氼垶宕靛鍫濈疀闁割偒鍓涚粈鍕煕濮橆剝瀚伴柕鍥ㄥ灩閹峰綊濡烽敂鑺ユ闂佹眹鍔岀€氼噣骞冩繝鍥ㄥ仺闁规彃顑囩粈鍡涙煏?
        // ★★★ 2026-10-18（用户第十轮：「收起过程中按钮/封面还是两个」）：
        //   上游 `shrink.start` 的 onDone 是 **两件事**（`wujie.pa:154940-154949`）：
        //   `miniHidden = false` + `shrinkPixmap = undefined`。
        //   我们原来只做了后者 ⇒ 真迷你条从"快照起飞"到"快照落位"这一段**一直是画着的**，
        //   屏上就同时有「飞行中的快照里那颗封面/那排按钮」+「真条那颗/那排」= 两份。
        this.expandState.endSnapshotShrink();
        this.finishCloseGuard(closeToken);
      });
      PlaybackPage.ev('SQZ', `shrink win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      this.state.isShowPlay = false;
      // 鈽呪槄鈽呪槄 2026-10-17锛堜慨銆岀郴缁熻繑鍥炲叧闂椂宸︿笅寰幆 / 鍙充笅姝屾洸鍒楄〃涓ら鎸夐挳娑堝け銆嶏級
      //   閭ｄ袱棰?`SymbolGlyph` 涓嶆槸琚銆佷篃涓嶆槸鎹簡鍒嗘敮 鈥斺€?瀹冧滑**娌¤繘杩欏紶蹇収**銆?
      //   瀹樻柟 `componentSnapshot` 鏂囨。瀵圭涓変釜鍙傛暟鍘熻瘽锛氥€岃缃槸鍚﹀己鍒剁郴缁熷湪鎴浘鍓嶇瓑寰呮墍鏈夌粯鍒舵寚浠?
      //   鎵ц瀹屾瘯鈥﹁閫夐」鍙敖鍙兘纭繚鎴浘鍐呭鏄渶鏂扮殑鐘舵€侊紝**搴斿敖閲忓紑鍚?*銆嶏紝骞跺啓鏄庛€屽鏋滃湪缁勪欢瑙﹀彂
      //   鏇存柊鐨勫悓鏃惰皟鐢ㄦ埅鍥撅紝鏇存柊鐨勬覆鏌撳唴瀹逛笉浼氳鎴彇鍒般€嶃€傛湰鏂规硶鍦ㄦ媿鍥?*涔嬪墠**鍒氭爣鑴忔覆鏌撴爲
      //   锛坄measureGeometry` / 浜嬩欢鏃ュ織锛夆噿 绗﹀彿瀛楀舰鏉ヤ笉鍙婄敾杩涘浘锛宍Image` 閭ｅ嚑棰楀嵈宸插湪鍥鹃噷
      //   鈬?鍙墿 prev/play/next銆傜粰蹇収寮€ `waitUntilRenderFinished`锛坥ptions 蹇呴』鍦ㄧ涓変綅锛夈€?
    }, { waitUntilRenderFinished: true });
    } catch (error) {
      if (this.ownsClose(closeToken, 'snapshot-throw')) {
        this.closeDiagnostic(`snapshot-callback miss throw=${error}`);
        this.finishCloseGuard(closeToken, true);
      }
    }
    //   ★★★ 2026-10-18（**回退上一轮那次改动** —— 用户实测「系统返回关闭时那两个按钮**又会消失**」）：
    //     `waitUntilRenderFinished: true` 在本仓是**必须**的：这两颗是 `SymbolGlyph`（字形光栅化晚于节点绘制），
    //     关掉它 ⇒ 截图里没有字形 ⇒ 一关就"消失"（历史结论见 §178）。
    //     上游能只用两个实参，是因为它那两颗在同一次绘制里已经画好；**这一处不能照搬**。
    //     ⇒「关闭瞬间偏一点」改从**方盒**那一侧解决（`ControlAreaComponent` 里已按上游删掉
    //       `.width/.height(chromeSeekSize())`，圆角裁剪不再切到 32vp 方盒的边缘）。
  }

  /** 闂佸憡鐟﹂悧鏇犳闁秴绀傞柛娆愶耿閻撯晠鏌ｉ妸銉ヮ仼闁圭儵鏅犻幃陇顦抽柡浣告贡缁辨捇鍩￠崘銊愶箓鏌熼璺ㄧ瓘缂佽鲸鐟︾粙澶嬫償閳藉懐澶勯柣?`Index` 闂佸憡鑹炬總鏃傜博鐎涙鈻?AppStorageV2 闁诲骸婀遍崑妯兼閵夆晜鏅璺虹墐閸?*/
  private morphShrinkState(): MorphShrinkState {
    return AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
  }

  /**
   * 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋掗懝楣冨箵閳哄懏鍋傜憸鎴︽儗閹屽殫闁告洦浜為悷婵嬫煕濞嗘ê鐏ｉ柡浣靛€濆顕€宕滄担鍦殸**闂備緡鍋€閸嬫捇鏌涢弽銊уⅹ闁搞値鍙冨畷?* 闂佺偨鍎查弻锟犲焵?闂備緡鍋€閸嬫捇鏌涢妷褍浠︽繝鈧悧鍫㈩浄闁规儳鐡ㄩ敍鍡涙煛閸繍妲烘繛?濠电偞褰冮…鐑藉Υ婢跺簺浜归柕蹇曞Т缂?闂佺绻戞繛濠偽涢幘顔嘉?
   *
   * ## 闁哄鏅滈悷锕€危閸涘﹦鈻旈幖娣灪閿熴儵鏌ｉ敐鍛伇婵?*婵炴垶鎸撮崑鎾愁熆鐠哄搫顏╅柛鈹垮灲楠炲洩绠涢幘宕団偓缁樻叏?*闂佹寧绋戦悧鎰邦敊閸ヮ剙鎹堕柕濠忓瘜閺€鎶芥煥濞戞瀚伴柛鈺佹瀹曟ê顓奸崨顖溞繛?濠电偛鐭夌槐鏇㈠矗鎼淬劌绠?闂?
   * 闂佸搫鍟版慨鐑藉疾?`濞达絽鍕?*#`闂佹寧绋戝澧倁jie.pa:181020-181077`闂佹寧绋戦ˇ顖氾耿椤忓洨鐤€妞ゆ劑鍊曞鎯ь熆閹壆绨块悷娆欑畵瀵噣鎳滈崹顐?`nav.pop()`闂?*闂佸搫鍟版慨鏉戭嚕?= 婵炴垶鎸哥粔鎾偨椤愶絾濮滄い鎺嗗亾婵犙€鍋?*闂佹寧绋戦¨鈧紒?
   * 婵炴垶姊婚崰搴☆潩閵娾晛鍙?婵＄偑鍊楅弫璇差焽娴煎瓨鍎庨悗娑櫭径宥嗙箾閹存繄澧曢柕?闂侀潧妫楅崐褰掑垂濠婂嫮顩?*婵?*闂佺粯鎸嗛崟顒€鍓堕梻渚囧弿缁茶偐绮╅幘顔肩骇闁宠棄鎳愮粈澶愭煟閻愬弶顥犻柡浣介哺缁嬪濡堕崱妯挎嫬闂?
   * 1. 闂佺懓鍢茬粔璺衡枔閹寸姭鍋撻悽娈挎敯闁芥牕瀚粙澶婎吋閸涱喖鈧亶鏌ㄥ☉娆戭暡婵☆偁鍊濋幃鍓т沪閹屸偓?`PLAYER_ROOT_ID`闂佹寧绋戦悧鍛博鐎涙鈻旀い蹇撴噺閻濐噣姊?`Stack`闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲骞嬪鍕嫧闂佺懓鍢茬粔璺衡枔閹达箑鍙?
   *    **`NavDestination(DIALOG)` 闂備焦褰冮惉鐓庘枔閹达附鍤嶉柛灞剧矊娴?* 闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕€顭囬姘モ偓鎺楀矗婢跺苯甯柣鐘辫閸ㄦ壆娆?*闂佸搫瀚烽崹閬嶅垂濠婂嫮顩锋い鎺戝€搁ˉ妤呮煛閸繍妲烘繛?*闂?
   *    婵炴垶鎸撮崑鎾绘煛?`componentSnapshot` 闂侀潻璐熼崝蹇曟崲閺嶎厼绾ч梽鍥儗閻愵剛鈻斿┑鐘插閸忓洨绱撴担鍝勬瀾闁逞屽劯閸愩劎鎮兼繛鎴炴尭缁夋挳宕哄畝鍕倞闁规儳鎳愮粈?*濠殿噯绲界换瀣博閺夋垟鏋庨梽鍥╂崲閹达箑鐐婇柣鎰絻瑜扮娀姊?*闂備緡鍠楅崹婵堟娴煎瓨鐒婚柍褜鍓熷畷鐘诲冀閵娿儳浜?
   *    "婵＄偑鍊楅弫璇差焽娴煎瓨鍎庨悗娑櫭径宥嗙箾閹存繄澧曢柕?闂佹寧绋戦惌鍌炲磻閸涙潙鍙?*濠?闂佺厧鍟块張顒€鈻嶅▎鎾崇煑妞ゅ繐瀚埛鏍р槈閹绢垰浜鹃梺?婵炴垶鎸堕崕鐢稿闯缁嬫鍤楁俊銈傚亾妞?*闂佹眹鍔岀€氼剝銇愰懠顒佸枂濞达絽鎲＄粈鈧悷婊呭鐢亞妲?
   * 2. 濠电偞褰冮…鐑藉Υ婢跺簺浜归柕蹇曞Т缂嶄線鏌?*闂佹椿娼块崝宥夊春濞戞﹩鍟呴柤纰卞厴閳ь剚顭囬幏瀣Χ閸涱叀顔夐梺?*闂佹眹鍔岀€氫即宕戦崨顔锯枖闁逞屽墯缁鸿棄螖鐎ｎ剛顦╃紒缁㈠弾閸犳盯顢樼拠灞傗偓鎺楀川椤撶偟顦?闂佸啿鐗幍鍐蹭壕閻忕偠鍋愰悷鎰版煙瀹勯偊妲瑰褝绠戦锝夊焵?婵炴垶鎸搁鍡樺垔濞差亜绀傞柟鎯板Г閿涙棃鏌ｉ妸銉ヮ仼闁汇劍绻堝Λ?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鍕瘞濠殿喗绻愮徊浠嬫偉閸洖违鐎广儱绻掔粈鍡涙煥?
   *    闂備緡鍋€閸嬫捇鏌涢妷褍浠滄鐐存崌瀵敻鍩€椤掑嫬閿ら煫鍥ф捣閻﹀秹鏌涘▎妯圭凹婵″弶鎮傚畷鍫曟倷閹绘帞鍘掗梺鍛婎焽閸犳劕顭囬悽鍛婄劷闁挎繂娲ゆ禒顖炴偡濞嗗繐鈧綊宕濋崨瀛樺仭闁哄洨濮甸悡蹇涙煏?
   *
   * ## 闁荤喐鐟辩粻鎴ｃ亹閸岀偛绾ч柍銉ュ级椤愪粙鏌ㄥ☉妯煎閻炴俺椴稿鍕礋椤旂偓顔嶉梺娲绘娇閸斿酣宕戦敐澶嬫櫖?
   * 閻?`closeWithAnimation()` 闂?*婵☆偅婢樼€氼參藟?*闂佹寧绋掓穱娲礂瀹€鍕倞濠电姴瀚崣鎰喐?/ 缂備焦鍔栭〃鍛般亹濞戞矮鐒婇柛婵嗗閸ょ喎霉閻樹警鍞虹紒鏂跨摠缁嬪顓奸崨顓☆唹闂佹眹鍩勯悡澶屾濡句繝ar=0x0`闂佹寧绋戦¨鈧紒?
   *   濠殿喗绺块崐鏍ь渻閸屾稒浜ら柣鎰级瑜般儵鏌ｉ幘妤€娲ら崢鏉戔槈閹惧磭孝妤犵偞鎹囬獮蹇擃吋韫囨洜顦╅梺鐟板槻缁夊磭鑺遍埄鍐枙闁绘柨鎽滃楣冩煟閵忊晝鍘滅紒杈ㄥ哺閺?
   * 閻?闂婎偄娴傞崑鍡涘矗鎼淬劌鐐婇柣鎰濞堝爼鏌?*婵犮垺鍎肩划鍓ф喆閿曞倸缁?*闂佹寧绋戝濉璻r` 闂傚倸鐗忛崑鐔煎煘閺嶎厽鏅璺虹墐閸?
   *
   * ## 闂佸憡鐟崹鐢割敋娴兼潙绠?
   * 闂佸憡顭囬崰搴∶哄鍫濈婵炲棙甯炵粻濠氭⒒閸喓鎳勯柍?`closeFallbackReason`闂佹寧绋戦惉濂稿极?`closeFullScreenPlayback()` 闂?`ev('CLO', 闂?`
   * 婵炴垶鎸撮崑鎾绘偣瑜旈弨杈ㄦ櫠閿旇姤浜ゆ繛鎴烆殘閻ㄦ垵霉閻樺搫鐓愭俊顐熸櫈缁犳稑螖鐎ｎ剛顦╅悗鍨婵倝鎮ラ敐鍥╃當妞ゆ巻鍋撶€规洖瀚粙澶嬪緞鎼搭喗鏂€闂?`fb=`闂佹寧绋戦ˇ顐﹀闯?**婵炴垶鎸撮崑鎾寸箾閸″繐澧查柛鈺佹嚇瀹曞爼骞嗚閻ㄦ垿鏌ゅ畷鍥ㄦ珪婵犫偓閸涙潙绀勫Δ锕佸劵濞夊弶绻涚仦鍕╁€涘▔鏌ユ⒑椤愮喎浜鹃梺?*闂?
   * @param reason 闂備緡鍋€閸嬫捇鏌涢弽銊уⅹ閻㈩垼鍋婂畷鍫曟偑閸涱垳顦╅梺娲诲弾閸樹粙鎮ラ敐鍥╅┏闁规儳鎳愮粈澶娒归崗闂翠孩缂佺粯蓱缁傚秶鈧絺鏅滈浠嬫煛閸愶箑鍔氱紒缁樻閺?
   */
  private closeLiveMorphFallback(reason: string): void {
    this.closeDiagnostic(`live-fallback reason=${reason}`, 'fallback');
    Logger.warn(PlaybackPage.logTag,
      `RzdShrinkOverlay fallback 闂?live morph (${reason})`);
    PlaybackPage.closeFallbackReason = reason;
    // `closeFullScreenPlayback()` 闂佹眹鍔岀€氼噣顢栭崶銊р枖闁逞屽墴閺屽棝骞樼紒姗嗘П闁诲繐绻楁ご绋课?`isClosing`闂佹寧绋戦懟顖滄崲閳ь剙顪冮妶鍥╁笡闁哄倷绀侀锝夊焵椤掑嫬绠ョ€广儱鐗忕粻鑽も偓鐢靛椤ㄥ懘鐛幘璇参?
    this.isClosing = false;
    this.closeFullScreenPlayback();
  }

  private closeFullScreenPlayback(): void {
    if (this.isClosing) {
      return;
    }
    // ★★★ 2026-10-18（用户：「展开过程中按返回**没有动画**」）：
    //   打开期的那条内容时间线是**逐帧 ticker**（见 `startContentTicker()`），它一直按自己的起点
    //   写到 560ms 为止、**不认**关闭请求 ⇒ 反向一开始就被它把 `contentP` 又顶回 1
    //   （底栏/传输行/背景全停在展开值），容器缩、内容不缩 = 看着像"没动"。
    //   上游只有**一条** `morphT`，`animateMorphT(reverseMs, 0, …)` 就是把它就地重定向
    //   ⇒ 这里必须先掐掉那条 ticker，反向才真的是反向。
    this.stopContentTicker();
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*缂?闂佺绻戞繛濠偽涚€涙ɑ濯存繛鍡樺姇閻ㄥ墽绱掗幇顓ф當鐟?闂佺儵鏅滈悧婊堟偟?闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷銈囩博鐎靛憡鍋橀悘鐐靛亾绗戞繛鎴炴尭閿曪絿绮╃€涙ɑ濮滄い鏃傛櫕绾偓闂佺懓鎼ˇ鍗炩枔?*闂?
    //   闁?`lastCloseAtMs` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粣妤呮煕閹邦剚鍣规い鏃€鍔楁禒?`.onAppear()` 闂佹眹鍔岀€氼剟宕㈢憴鍕劅闁哄洨鍋涢悗濠氭煛閳ь剟顢涢悙瀛樼ギ闁诲海鎳撻崯顐﹀垂娴犲妫?
    //   "闁哄鏅滈悷銈囩博閺夋垟鏋庨柍銉ュ暱濮ｅ鏌ｅ鍕棆婵炲牊鍨块幊鐐哄磼濠婂啩鍖栭梺鍝勫閸垳绮径鎰強妞ゆ牗鑹鹃悘鐘绘煙闂堟稓效闁稿鎳庨埢搴ㄥ灳閸愭彃缍橀梻鍌氬亞閸樻儳鈻撻幋鐐村婵炲棙鍔曢惃?闂?*闂佸憡鐟禍婊冿耿椤忓懏浜ゆ繛鍡樻尭濞咃繝鏌涢幇顓犳噣闁逞屽厸缁舵岸宕戦崨瀛樼厒鐎光偓閸愭儳娈?*闂?
    //   婵炴垶鎸堕崐鏇⑺囬埡鍛闁归偊鍓﹂崵鐘绘煥濞戞澧旂紒妤€鍊圭粙澶愬焵椤掍焦濮滄い鏃傚帶濞懷囨煛閸繍妲兼い鏇氬嵆婵″瓨鎷呴崷顓熲挄闂佸搫鐗嗛ˇ顖炲疮?闂?闂傚倸鍊堕崝宥嗙娴犲纾婚柛銉╊棑缁€鍡涙煏?
    PlaybackPage.lastCloseAtMs = Date.now();
    // 闂?闂佸搫鍟冲▔娑氳姳椤撶噥娓堕柟瀛樼箓閻ㄣ儵鎮楀☉娆忓Ё缂佸彉鍗冲鐢割敆娓氬洤浠归梺绋跨箲婵炲﹤螞閺夋埈鍤曢柍褜鍓氶幈銊р偓锝呭缁€鍕偡?`evLog` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈?
    //   闂?2026-10-17闂佹寧绋掗悺鐚=` = 闁哄鏅滈悷銈囩博閺夋垟鏋庨柍鈺佸暞绗?*婵炲濮存鎼佸箵閳哄懏鍋傜憸鎴︽儗閹屽殫闁告洦鍨崑鎾诲焵椤掑嫬绀岄柡宥庡墰缁犳牠鏌℃径鍫濆姢婵?*闂佹寧绋戦悧鎰帮綖?`closeFallbackReason`闂佹寧绋戦¨鈧紒?
    //   闁荤姴娲╅褔鎮鹃鍕闁惧浚鍋嗛?闂?`fb=` 缂?= 闁荤姍鍕棆婵炲牊鍨肩粻娑㈩敃閵堝懎瀛ｉ柣鐘辫閸ㄦ壆娆㈤悙鐑樻櫖婵炲本顣籦=snapFail` / `fb=noSrcBox 闂佺偨鍎哄▔?= 闁荤姍鍥舵殥缂併劉鈧秮鐑樼節濮樸儮鍋撴径搴涗汗闁靛繒濮寸紞渚€鏌?
    const fb: string = PlaybackPage.closeFallbackReason;
    PlaybackPage.closeFallbackReason = '';
    PlaybackPage.ev('CLO', `gen=${this.closeGen + 1} p=${this.expandState.morphP.toFixed(2)}` +
      (fb.length > 0 ? ` fb=${fb}` : ''));
    // 闂佸疇妫勯幊澶娢?P0-2闂佹寧绋掔喊宥咃耿閻楀牊濮滄い鏃傚帶瑜扮娀姊婚崒銈呭箻婵?*闂佺粯鐟崜娑㈡偟濞戞瑧顩烽柨婵嗘－閸?* + 闂佸憡鐟﹂悧妤冪矓闁垮鈻斿┑鐘辫兌椤忛亶寮堕悜鍡楁灈鐟滅増鐓￠幊妤呭磹閻旇櫣顔庨梺鍦焾閸婅顭囬崘顔藉剭闁告洦鍋勭粊濠氬级閻愯埖顥夐柣锝夌畺瀵喚鎹勯悜妯煎綔闂?
    //   `isClosing` 闂佸湱纭堕埀顒€纾换浣该?闂佽　鍋撻柟顖滃瀹曟娊鏌涢弬璇插闁轰胶鍋撳璇测槈濠婂孩鏂€婵?闂佹眹鍔岀€氫即宕抽幖浣哥闁靛鍨崇粈澶娒归敐鍛棞闁伙絿濞€瀹?`morphCloseMs + 20`闂佹寧绋戦悧鍐╂櫠?70ms闂?
    //   闁诲繐绻楃划楣冿綖閿曗偓閵嗘帡宕ㄩ鐔侯槬 `false`闂佹寧绋戦惌渚€鍩€椤掆偓閻倿宕戦崨顔锯枖闁逞屽墴瀹曟氨绱掑Ο璇插晩闂佽　鍋撳Δ锝呭暔閳?*闂佸憡鐟崹鐢稿礂濡粯浜ゆ俊顖濆吹濮?unmount** 闂?缂備焦顨忛崗娑氳姳閳轰讲鏋庨柨娑樺娴狀垶鏌涢幋锝庡敽缂佸彉鍗冲畷妯侯吋閸喎闂繛鎴炴尨閸嬫捇鏌?
    //   350ms 闁荤偞绋忛崕闈浳?+ 缂備焦顨忛崗娑氳姳閳哄倻鈻旀い蹇撳缁佸寮堕悙鑸殿棄闁伙綁绠栧顔炬崉閻戞褰滈梺鎸庣☉閻線鍩€椤掆偓婵傛梻鎮柆宥呯骇闁跨喓濮甸幊鐘绘煟?`morphGen` 闂佺儵鏅濋…鍫ュ箖?闂?`morphGenAlive` 闂佺懓鍤栫紓姘辩箔婢跺濯撮煫鍥ь儌閸?
    //   闂佸搫鐗嗛ˇ顔捐姳?`closeGen` + 闂佸憡鐟ｉ崕鏌ユ倿濞差亝鏅€光偓閳ь剟顢栭崶銊ь洸閻忕偟铏庨崑褔鏌ｉ幇顔藉殌闁搞値鍠氶幉鐗堟媴妞嬪海鏉介柣鐐村嚬閸嬪懎危閹寸姵鍏滄い鏂垮悑鐎氬綊鏌ｉ敐鍐ㄥ姌闁逞屽厸濞村洭銆呴敂鐣屸枙闁割偅绻傞崣锟犳煕閹存柨浜鹃梺瑙勪航閸庢娊顢橀幖浣肝?
    const closeGen: number = this.closeGen + 1;
    this.closeGen = closeGen;
    if (this.closeSettleTimer !== -1) {
      clearTimeout(this.closeSettleTimer);
      this.closeSettleTimer = -1;
    }
    this.refreshCollapseGeometry();
    this.isClosing = true;
    const closeToken: number = this.beginCloseGuard('live');
    this.closeDiagnostic('shrink START');
    // 濠殿喗绻愮徊钘夛耿椤忓牆缁╅柟顖滃瀹曟娊鏌熺紒銏犲箺闁哄倷绶氬畷鎶藉Ω閿旂瓔妲繛鎴炴尭缁夌兘銆呴敃鍌氱鐎广儱鐗嗗▓浼存煕閺傝濡介柡浣哥秺楠炴帟顦查柛鈺傤殜瀹曠娀鎮€靛摜顦╂繛鎴炴尪閸婃捇鏌屽鍫濈闁靛ě鍕瘞闂佸憡鐟ф慨宕囩博鐎靛憡灏庨柧姘€荤粣妤冣偓鍨緲閻楀懐鎷归敓鐘虫櫖?
    this.stopChromeAutoHide();
    // 闂佺绻戞繛濠偽涢幘顔煎珘闁绘柨鍚嬮敍鐔煎级閳哄倻鈽夐悗纭呮珪鐎电厧顫濋璺ㄤ笉闂?闂佽　鍋撻柟顖滃瀹?闂佸憡鍨规慨宄扳枍閵娿儛鎺楊敃閵堝孩鍋ラ梺鎸庣☉閼活垶宕洪崱娆愬闁宠桨鑳跺鏃傗偓娈垮枓閸嬫捇鏌ｉ鍕靛剶婵☆偒鍓熼幃顏勎旀担鑲濃晠鎮楅悷鏉挎殲濠殿喚濞€瀹曞爼鎮欓懠顒佹闂佽桨绀侀悺銊╁焵?
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 闂?闁荤姍鍕棆婵炲牊鍨垮浼搭敍濮樺啿鐓傞梺鍛婄懄椤牓鎯岄幆褜鍤楅柛鏇ㄥ亝閻?*闂佸憡鐟ョ粔鎾箖濠婂懏宕夐柟瀛樼箖閸婂崬鈽夐幘顖氫壕婵犻潧鍊归〃鍛村吹閹寸偞濯?*闂佹寧绋掔喊宥夊汲閿濆棎浜滈柣銏㈡暩缁辨岸鏌涢妷褍浠╃紒顖滃У閹峰懘鎮╅搹顐ユ嫬闂備緡鍙忕徊鑲╃博鐎甸晲鐒婇煫鍥ㄦ尰閸嬨儵鏌曢崱鏇熺グ妞ゃ儱妫濆畷婊堫敂閸℃瑥鐐婇梺鍛婄懕缁查箖寮ぐ鎺戠倞闁绘劖褰冪粻鐢告煥?
    //   闂佸搫鐗冮崑鎾绘煕濮橆剚鍞夐柟顖樺€濆畷鍫曟倷閸撲胶顣ㄦ繛杈剧悼婵潧顭囬鐐存櫖闁革妇鍤凬DING闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婃悂鎯堝鍜佸殨闁?闂佽　鍋撻柟顖滃瀹曟娊鎮樿箛姘跺摵婵″弶鎮傚畷銉т沪閼测晩浼囨繝闈涘€归〃鍛嚕椤掑嫬鏋侀柟娈垮枟閻ｈ鲸鎱ㄥ┑鎾跺埌鐎殿喛濮ょ粙澶愬Χ婢跺鍠氶梺鎸庣☉婵傛棃骞戦姀銈呯疀闊洦姊归ˇ褔鏌涢幒鎴吋闁稿繑锕㈤幊娑㈩敂閸涱厽鏁ч梺?
    //   闂佸疇娉曟刊瀵哥箔?闂佸憡甯囬崐鏇㈡偩妤ｅ啯鍋?`morphUsable` 闂?*婵炴垶鎸哥粔闈浳?* `morphContainerActive()`闂佹寧绋掑銊ㄥ綂闁诲氦顫夐懝楣冩儓瀹ュ拋鍤曢柍褜鍓熼獮鈧ù锝囧劋閻ｉ亶鏌ｉ埡鍛珳缂傚秴鎳樺?
    //      OPEN闂佹寧绋戦悧鍛箔婢舵劕鍙?ENTERING/LEAVING闂佹寧绋戦¨鈧紒杈ㄧ箞閹粙濡搁妷锕€鈧敻鏌ら弶鎸庡櫣闁搞劎鏅埀顒冾潐閻喚妲愭导鏉戠濠㈣泛锕ョ粈鈧?闂佸憡锚椤戝棙鏅舵惔銊ョ闁告侗鍙庨崯鍥倶閻愭彃鈧潡鎮甸鑺ュ劅?闂佹眹鍔岀€氼垶鍩€椤戣法顦﹀┑顔规櫊閹?闂佺偨鍎查弻锟犲焵?
    //      闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸冲畷姘跺箥椤旂晫鏆犻梺闈涙閻ジ寮妶鍥у闁煎鍊楅崺鐘诲级閳哄倹鐓ユ繛鍙夌墵瀹曟骞庨懞銉川闁哄鏅滆摫婵″弶鎮傚顔款槻濠殿喒鏅犻幃钘壭ч崶锝呬壕鐎广儱鎳忛惃鎴︽煛閸曢潧鐏ョ紒缁樼墵閺屽瞼浠﹂悜鈺佷壕?
    if (this.expandState.morphUsable) {
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佽　鍋撻柟顖滃瀹曟娊寮堕埡鍌滄噥缂佹柨鐡ㄧ粭鐔活槺缂佲€冲暟閹茬増鎷呴悾宀€鐣?闂佸憡鍨规慨宕囩礊瀹ュ洣鐒婇弶鍫氭櫅瀹?闂備緡鍙忕紞浣圭妤ｅ啯鈷?*闂佹寧绋戦¨鈧紒?
      //   闂佸搫鐗滈崜婵嬫偪閸℃瑧纾?`applyMorphProgress` 闂佸憡姊绘慨宕囪姳閳╁啰鈻旈柍褜鍓熼弻鍡涘箻鐎涙﹫楠忛梺浼欑到閻厧鈻撻幋锔解拻妞ゎ厽甯炵粈鍒瀖orphGeomReady`闂佹寧绋戦惌渚€锝為崱娑欑劷闁挎繂瀚伴崵瀣倵濞戞瑯娈曟い鏂跨焸閹啴宕熼浣规畼闂備焦褰冮…顓犳濮樿埖鏅?
      //   闂佸憡鍨规慨宕囩礊瀹ュ應鏌﹂柍銉ㄦ珪閻ㄦ垹绱撴笟鍥︾凹婵＄偛鍊婚埀?*婵炲濮崑鎾斥槈閺傝法澧﹂柛蹇斏戠粙澶婎吋閸涱剛椹?*闂侀潧妫楅崐瑙勬櫠閿曗偓椤曪綁鍩€椤掍焦浜ゆ繛鍡樺姈閽傚鎮规笟顖氱仸婵?`measureMiniDuringPull` 缂傚倸鍠氶崰鏇犵礊閸涘瓨鏅?
      //   闂?闂佺粯鍔楅幊鎾诲吹椤曗偓瀹曟骞庨懞銉川 / 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧梺绋跨箲婵炲﹤螞?闂佸搫瀚烽崹顖滃垝?*閻庤鐡曠亸娆戝垝閿熺姵濯伴柟瀛樺笧缁夋挳鏌ｉ妸銉ヮ仾濠⒀嶇畱椤曪綁鍩€椤掑嫬绠?*閻庡灚澹嬮崑鎾绘煕閵壯冧哗缂?闂佺偨鍎查弻锟犲焵?濠殿喗绻愮徊浠嬫偉閼稿灚鍎熼柡鍌濇硶缁夎偐鈧鐡曠亸娆撴偪閸℃ɑ濯寸€广儱绻掗獮?
      //   婵炶揪绲藉Λ妤冩閹捐埖鏆滄慨婵嗙灱閻斿懐鈧灚婢樼€氬摜妲愬▎鎾崇闁规儳纾壕濠氭煛閸愨晛鍔堕挊鐔兼⒑閹绘帞绠伴柕鍥ㄥ灩閹峰綊濡烽妸褏鐣烘繛鎴炴尨閸嬫挻绻涢崰鈩冨閸嬫挻绋婇·纭俽phReset` 婵炴垶鏌ㄩ鍛村箖濡ゅ懎鐭楅柛顐悼缁犲鏌℃径鍫濆姉闁逞屽墾鐠侊絿妲愬顓烆嚤婵ɑ鍓氶崬銊╂倵閻熸澘鏆炴俊鍙夋倐瀹曟垿宕舵搴ｎ槷
      //   闂備緡鍙忕徊鎯ь渻閸屾稓鈻旈悗锝庡枟濡椼劑姊?460ms 闂佹眹鍔岀€氼參寮崷顓熷皫闁汇値鍨佹径鎰拻闁哄鍨堕惃鎴︽煛?*闂佽桨绀侀悺銊╊敊瀹€鈧划姘偊閹稿海銈?* =
      //   闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸抽幆鍐礋閳规儳浜剧€光偓閳ь剟宕戦敐澶婄閻犲洦褰冭ぐ鐘绘⒒?/ 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧?濠电偛澶囬崜婵嗭耿娴ｈ桨鐒婂〒姘ｅ亾婵?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鍕瘞闂侀潧妫楃粔鏌ュ焵?
      //   闂?闁哄鏅滈悷鈺呭闯閻戣姤鍋ㄩ柕濠忕畱閳數鈧鍠掗崑鎾绘煙椤戣法顦﹂柛鎴節瀵灚寰勭仦鍓ф殸缂備焦妫忛崹鎶藉磻閿濆绀勯柣妯夸含缁夊潡鏌涜箛鏃傜煀缂併劍濞婂銊╁箲閹板灚鏂€闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閳ь剙鈻撻幋锕€缁╅柟顖滃瀹曟娊鏌￠崼顐㈠婵炶偐鏁告禍鎼佸矗濡偐鎲归梻浣瑰絻缁夌敻寮绘繝鍥ㄧ厒闊洦娲滈惌鎺楁煟閹邦喗顏熺紒杈ㄥ哺婵?
      if (!this.expandState.ensureMorphGeomForClose()) {
        Logger.warn(PlaybackPage.logTag,
          'close: geometry unresolved on both ends 闂?close without morph animation');
      }
      // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂?*闂佺绻戞繛濠偽涢幘顔肩睄闁割偅娲樺В鎰槈閹捐櫕鎹ｇ紒鎲嬬畵瀹?*闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
      //   **闁哄鏅滈悷銈囩博鐎涙ê绶為柛鏇ㄥ亝閻ㄦ垿鏌￠崟闈涚仯闁轰降鍊濋獮瀣暋閹殿喗婢栧┑鐐存綑椤戝啴鍩€椤掆偓閼活垶宕ｈ濮婂顢橀悢绋垮晩闂佽　鍋撻柟顖嗗嫮褰滈梺鍛婂灩婵磭绮婚灏栨煢闁炽儱鍟胯闂佹眹鍨洪惇褰掑焵椤掆偓缁夎泛鈻撻幋锔藉剳闁绘柨鎽滄竟宀勬煕閵壯冃為柍?*
      //   闂佸搫鍟版慨鐑藉疾?闂佺绻戞繛濠偽涢幘顔肩闁归偊浜濋崬?闂佹寧绋戝绺癷t闂佹寧绋戦ˇ顖炲垂鎼淬劌缁╂い鏍ュ€楃粈鍒瀇recover/logic-src/閻庢鍠掗崑鎾绘煕韫囨碍鐝柟鎼佷憾瀵劑骞嗚閻?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄦ皑缁愮偤鎮楃憴鍕殤妞?md`
      //   闁? 闂備緡鍋嗛崰鎰版偂閿涘嫭鍋?L27/L29闂佹寧绋戦懟顖炴偉閸洘鐓傞煫鍥ㄥ搸閳?闁圭厧鍊垮畷?L620-633闂佹寧绋戦¨鈧紒?
      //     `reverseMs = round(REVERSE_MS(460) 闁?max(REVERSE_MIN_RATIO(0.4), morphT))`
      //     `animateMorphT(reverseMs, t = 0, REVERSE_EASING)`
      //     `REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`   闂?闂?**闂侀€涚┒閸ㄥ綊骞嗘惔銊ョ?*
      //   闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹鏌?**350ms + `cubicBezier(0.23, 1.0, 0.32, 1.0)`**闂佹寧绋戦惌渚€鍩€椤掆偓閻倿宕戦崨鏉戠骇?
      //      闂佹寧绋戝濉傾SE_OUT_STR`闂佹寧绋戦ˇ鏉课?*闂佺懓鐏氶幐鍝ユ閹达箑绠甸柟閭︿簼閸?*闂佹椿娼块崝搴♀枔閹达附鏅?*闂?15% 闂佸搫鍟悥鐓幬涚捄銊ょ剨閺夊牜鍋夊▔鏌ユ倵閻熸壆鐏遍悗?70% 闁荤偞绋戦惉濂稿煝?*
      //      闂?350ms 闂備焦褰冮惉鑲┾偓?50ms 闁诲繐绻楁禍顒傜磽婢跺备鍋撻悷鏉款殭缂侇煉绻濇俊瀛樻媴缁嬪簱鎸呮繛?300ms 闂佸憡鍨规慨宕囩不椤旂晫顩烽柍褜鍓氱粙濠囧醇閵夈儱骞嬪┑鐐插閳ь剙鍟跨徊娲煟?闂佺偨鍎查弻锟犲焵?
      //      闂佹椿娼块崝宥夊春濞戙垹绠涢柣鏃囨閸欌偓闁诲繐绻楁ご绋课?**闂佺绻戞繛濠偽涢幘顔肩闁绘浜鍛箾鐏炵硶鍋撻崘娈嬫鏌?*"闂佹寧绋掗惌顔剧箔婢舵劕鍙婃い鏍ㄧ〒濮婇箖鏌熺紒銏犲伎缂佽鲸绻堝?*婵炴垶鎸撮崑鎾绘煟椤忓倸濡挎繝褍鍊绘禍鍛婃綇閵娧勨挄婵?*闂?
      //   闂?婵炴垶鎸堕崐鏇⑺囬埡鍛劸闁兼亽鍎遍惁濠氭煛閸愵亜啸闁哄拋鍋婂銊╂儌閸濄儳鐛ラ梺鍝勫暙閻栧ジ寮?`460 闁?max(0.4, morphT)`闂侀潧妫旈懗鍓佹閿曞倸绀?**`REVERSE_EASING`**闂?
      //      婵炴垶鎸搁鍥疾?`460闁?.4 = 184ms` 婵烇絽娲︾换鍡涙儊?闂佸憡鐟禍婵囧垔閸濆嫷鍤曢柍褜鍓氱粙澶愬焵椤掑嫭鍊烽柛锔诲幖娴狀垶鎮樿箛姘跺摵婵犮垺顨婇獮?闂佸搫鍟﹢鍦姬閸愨晜浜ゆ俊顖滅帛缁犳帒鈽夐幙鍐х盎闁稿孩宀稿鑺ヮ槹鎼淬垻鏆犻梺琛″亾閻犲搫鎼埣銏ゆ煏?
      //   闂佸疇娉曟刊瀵哥箔?**闂佸憡甯╅崑鍛繆閸涘﹦鈻旈柕鍫濇閽傚绱撻崒娑欏碍濠殿喒鏅犻獮鏍倷绾惧鈹?*闂佹寧绋戦悧鍡涙偩閸撗呯煓?闁圭厧鍊垮畷?L385 闂佸憡顭囬崰鎰板几閸愵喗鏅慨妯稿劗閸嬫挾鈧懓纭VERSE_EASING` 闂佸憡鐟禍婊冿耿?
      //      '闂佸湱绮崝鎺戭潩閿曞倸绀傞柟鎯板Г閿?quit)'闁哄鏅滈悷銈囩博閹绢喖缁╂い鏍ㄧ矋閺嗗繘鏌?*闂佸憡鐟﹂悧妤冪矓閻戣棄鐐婇柣鎰蔼閸撱劑鏌涘▎蹇曅ラ柍褜鍓欓惉濂稿极?`EASE_OUT_STR`**闂侀潧妫楃粙鍕濮樿埖鏅?
      //        閻?闂佺懓鐏氶幐鍝ユ閹达箑绠甸柟閭︿簼閸?/ 闂佺懓鐏氶幐鍝ユ閹达箑鐭楅柡宥冨妿鍟?闂?`EASE_OUT_STR`
      //        閻?**闂佺绻戞繛濠偽涢幘顔肩闁归偊浜濋崬?闂?`REVERSE_EASING`**
      //        閻?闂佺绻戞繛濠偽涢幘顔肩煑闁哄秲鍔庡暩闂佹寧绋戦悧鍡椕洪弽褜鍤曢柣褍鎽滅粈鍡涙煃?`EASE_OUT_STR`
      //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滅粙鎴犫偓鐟扮枃缁犳盯宕ㄥǎ顑藉亾韫囨稑鎹?`morphBeginLeaving()` **婵炴垶鏌ㄩ鍛櫠?*闂佸憡鐟﹂悧顓犳濞嗘劗鈻旈悗锝庡枟濡椼劑姊洪銊у闂?`applySync` 闂備焦褰冩總鏃傛娴兼潙缁╅柛锔诲幗缁佹彃霉閿濆懐鈻岀紒杈ㄥ哺婵?
      const closeFromT: number = this.expandState.morphP;
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂佹寧绋戦悧鍛偖鏉堛劎鈻旀い蹇撳濡棝姊洪鍝勫閼垛晠鏌涢妸銉剮缂佽鲸澹嗛幏鐘崇節閸屾稑鈧?*闂佺绻愬畷顒勫箖閹捐绠伴柛銉戝嫬鈧?*闂佹眹鍔岀€氫即宕戦崨顔锯枖闁逞屽墴瀵爼鍩ラ崨顖滎槷闂佸憡姊绘慨宕囪姳閿熺姴绠柕鍫濇閸╁鏌ㄥ☉姗嗘缂?
      //
      // ## 闂佹眹鍎卞ú銊︽叏?
      // 闂侀潧妫楅惉濂告焾鐎靛摜纾奸柣鏃囧吹缁犳煡鏌?/ 闂佺绻戞繛濠偽涢幘顔肩濠㈣埖鍔栫亸?/ 婵炴垶鎸搁鍡樺垔濞差亜绾ч柣鎰靛墮椤や線鏌ㄥ☉娆掑闁汇劍绻堝Λ?*闂佺儵鏅涢悺銊ф暜鐎涙鈻旈悗锝庝簻缁?/ 闂佺儵鏅涢悺銊ф暜閹绢喖绀嗛柡澶庢硶濮ｅ牓鏌涢敃鈧Λ妤呮嚋?*闂佹寧绋戦張顒勬儉閸涙潙瀚夊璺鸿嫰椤忣亞绱掗弬娆惧剶妞ゃ儻绲块幃鏉跨暆閸曨偂绨兼繛鎴炴尨閸嬫挻淇婇锝呯闁?
      // ## 闂佸搫鐗嗛幖顐﹀春?
      // 闂佽　鍋撻柟顖滃瀹曟娊鎮跺☉鏍у姦婵☆偄娼￠幆鍐礋椤旇棄闂梺缁樺姌椤危?*濠电偞鎯岄崰鏍儑娴煎瓨鍤婃い蹇撳缁犳帡鏌ｉ妸銉ヮ伂缂佺粯蓱閹?* `morphOverlayP`闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎮鹃悩璇叉嵍闁靛鍊楅悷鎾绘⒒閸稑鐏辩紒缁樼墱缁柨顓奸崱妤€澹堥悷婊嗗焽閸ㄤ粙宕抽悜钘夊強?**0**闂?
      //   閻?闂佺懓鐏氶幐鍝ユ閹达附鐒介柨婵嗗椤忚鲸淇婇锝呯婵炲牊鍨甸湁妞ゆ棁鍋愬﹢鎾偠濞戞牕鍔︽俊顐㈢仢閳讳粙鏁撻悪鈧Λ褔鎮硅閺€鍗烆焽閻㈠憡鏅柛顐ｇ矌娴兼劕鈹戦垾鍐测偓浠嬶綖?`hostsMorphOverlay` / 闂佸搫鍟犻弲鐘诲焵椤戣棄浜鹃梺鍦《閸撴繄鏁埀顒勬煥濞戞﹩妾х紒?
      //     闂?`morphOverlayReset()` 闂?P 闂佸憡锚椤戝懎煤?0 婵炴垶鏌ㄩ鍛村箖濡ゅ啩鐒婇柛妤冨仜閺呮瑦绻涚仦鍕╁€ゅ鍫曟煙閹帒濡虹紒妤€鍊垮畷銏″濞嗘垵鑰?
      // 闂?婵炲瓨绮岀€涒晛危?`morphOverlayTweenTo(false)` 闂佺懓鍢查悘婵嬪春?`from = 0`闂侀潧妫斿姊﹐ = 0`
      //   闂?闁?`|to - from| < 1e-4` **闂佸搫鍟犻弲鐘诲焵椤戣棄浜?*闂佹寧绋戦悧鎰崲?animateTo 闂備緡鍠楅崹婵堢箔婢跺鍤堥柣姘嚟缁€?
      //   闂?闂?`morphOverlayBridging()` 闂佹眹鍔岀€氼喖霉婢跺濯寸€广儱鎳庨獮鎴﹀箹鐎涙ɑ绀€闁搞劌閰ｅ?*婵炲濮寸粔鍫曞礉瑜庣粙澶愭惞鐟欏嫬鐒?*
      //     闂佹寧绋戝濉祇rphContainerActive() && snapStartW > 0 && endCoverSize > 0`闂?
      //   闂?闂佺绻愰澶娾枔閺囩姳娌?*闂佽桨绀侀悺銊╊敊瀹€鍕闁规儼濮ら敍鏃堟⒑椤旂偓娅曢柡渚€绠栧畷?`morphCoverRectAt(0)` = 闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹婵炴垶鎼╂禍婊堟儍椤掑嫬鎹?*婵炴垶鎸搁…顓犳濠靛洨鈻旈柍褜鍓熷畷婵嬪Ω閵堝洨鎲归梺鍛婃煟閸斿﹪鍩€?
      //
      // ## 婵烇絽娴傞崰妤冩兜閸洘鏅柛顐ゅ枎琚橀梺鍝勭Т缁绘帗鏅跺Δ鍛櫖?*闂佸憡鐟禍婊冿耿?缂佺虎鍙庨崰鏍偪閸曨偀鏌﹂柨鐔哄濡囧级?闂?*闁诲酣娼х紞濠勭礊閸儲鏅€光偓閳ь剛鍒掗柨瀣枖鐎广儱妫楅埅鐢告煛閸屻倕骞楁い鎺撶矒瀹曠兘濡搁埡濠冿紘闂佹眹鍔岀€氼垳鎹㈠Ο缁樺劅闁挎棁鍋愮粈?
      // 闂佸吋鐪归崕鑼嫚閻愬吀娌柛灞剧箘缁犲骞栨潏鍓х窗缂侇喗鐩畷鎴濐煥閸愨晞鍚?0闂侀潧妫斿ù鍥焵椤掆偓閻倿濡存径鎰棃闁靛繒濮风粔濂告煕閹惧磭啸缂佺粯蓱閹?> 0 闂?闂佺娉涢敃銈夋偩閻樼鍋撻棃娑氱Ш缂傚秴鐗撳畷姘濞ｎ兘鍋撴径鎰棃闁靛骏绲跨粻濠氬箹?
      // 闂? 閻庡湱顭堝璺猴耿娓氣偓閹?`syncMorphOverlayFromPage()`闂佹寧绋戦惌渚€顢氶姀锛勨枙濠㈣泛顑愰崝鈧梺?濠电偞鎯岄崰鏍儑閻楀牊浜ゆ繛鎴灻?:= 婵＄偑鍊楅弫璇差焽閻楀牊浜ゆ繛鎴灻?闂佹寧绋戦¨鈧紒?
      // 闁哄鏅滈悷锕傛偋闁秴缁╅柟顖滃瀹曟娊鎮跺☉鏍у姦婵☆偉娉曟禍鍛婃綇閵婏妇鐣虫繛瀛樼矊濡稑锕㈤敍鍕ㄥ亾閸︻厼浠╅柟鐧哥秮閹瑩鎯傞崫銉ь槱婵炴挻鑹鹃鍛淬€?1 闂?0闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪鍩€椤掑嫭鈷愭繝濠傚暙閻撳倿骞栫€涙ɑ绀冨褏濞€楠炲骞囬鎯х秳闂?
      // 闂佸疇娉曟刊瀵哥箔?**婵炴垶鎸哥粔鐑藉礂濮椻偓瀵噣鎮╅搹顐ユ嫬婵炲濮惧▔娑㈩敋椤旂瓔鐎?*闂佹寧绋掓穱铏光偓姘ュ灩闇夋い鏃囧亹濠€瀛樻叏濠垫挾鍒版繝鈧?1闂佹寧绋戦悧鍡涘Φ閸モ晙鐒婂〒姘ｅ亾婵炶偐澧楅幏鍛吋閸モ晜鐎梺鎸庣☉椤︽娊鍩€椤掆偓閻倿濡存径鎰棃闁靛繒濮撮崵鎺楁偠濮樼厧浜濆褎绮撻獮鎰板炊閵娿儳褰岄梺?0.05闂?
      //   闂佸搫鍟版慨闈涱焽椤栨稓顩烽悹杞拌閸ょ姴顫楃紒妯哄缂佽鲸澹嗛幏瀣煛娴ｇ鑴梻鍌氭噹濡鎯?*婵炲濮存鎼佸Φ閸モ晙鐒婂〒姘ｅ亾婵為棿鍗抽幆澶愵敆閸曨剨绱甸柣鐘叉惈閸熷潡宕虹仦鐐氦闁炬艾鍊荤粙鎴︽煛?* = 婵炴垶鎸撮崑鎾寸箾閸″繆鍋撻崘鑼额唹闁荤喐鐟ら懗璺衡枔閹寸姵宕夐柛鎰絻缂嶄線鏌?
      if (this.expandState.morphOverlayProgress() <= 0.001 && closeFromT > 0.001) {
        this.expandState.syncMorphOverlayFromPage();
        PlaybackPage.ev('OVA', `align overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
          `to p=${closeFromT.toFixed(3)}`);
      }
      // 闂?闂佺绻愰悧濠冧繆?闁哄鏅滅粙鎴﹀矗閸℃稑缁╅柟顖滃瀹曟娊鏌ｉ埡鍛珳缂?+ 闂佸憡鍔樺畷鐢靛垝閵娾晛绀勯柣妯夸含缁?闂佸憡鑹鹃張顒勵敆閻愬搫绀嗙€瑰嫭婢樺В澶愭煕濡湱涓茬紒杈╁濞艰鈻庢惔锝庝紘濠电偛鐗嗛悘姘ｉ崫銉﹀仒闁靛鏅滈敍?*婵炴垶鏌ㄩ鍛櫠?*闂佹眹鍔岀€氫即路閸屾稑绶為柡宥忛檮閸欏繘鏌￠埀顒勬儌閸濄儳顦?
      //   闂佸湱顭堥ˇ顖炴偩婵傜妫樼痪顓炴媼濞兼劙鏌涢幒鎾舵噧缂佺儵鍋撴俊鐐€涘畷鐢稿极?`applySync` 闂佸憡鑹鹃張顒勵敆閻愬搫鍐€闁搞儺浜滄竟鍫ユ煥濞戞瀚伴柟顖欑窔瀹曟艾鈻庨幑銈咁樀濮婂骞橀鍛闁汇埄鍨庨崒婊呯崶闂佹椿娼块崝宥呂涢锕€纾圭紒妤勩€€閸?
      UIUtils.applySync((): void => {
        // 闂?2026-10-17闂?*闂佹椿娼块崝宥夊春?08:46 闂佽鎯屾禍婊兠瑰鈧弻灞界暆閸曨偂绨奸梺鍝勵檧缁辨洟鎮￠弴銏″剮闁告挆鍕殸闁诲氦顫夌喊宥夊焵椤戭剙鎳忛弳?*闂佹寧绋戦¨鈧紒?
        //   闂備緡鍙忕徊鑲╃博閺夋埈鍤曢柣妯挎珪閿涘鐓崶顭戞畷婵?`CLO:gen=1 p=1.00` 缂備焦鐦遍崟顐㈩槻闂佹椿鍋€閸?`LV:anim from=0.00`
        //   闂佺偨鍎查弻锟犲焵?婵炴垶鎸堕崐娑€侀幋鐘冲珰闁煎鍊栭悾閬嶆煛?*闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳閹界喐绻?* `morphP`闂佹寧绋戞總鏃堟嚈閹达附鈷?*濠电偛澶囬崜婵嗭耿娴ｅ湱顩烽悹浣哥－缁夊潡鏌涢幇顓犳噧闁?*
        //   闂佹寧绋戝濉祇rphP` 闂佺绻堥崝瀣垝閵娾晛鐭楁い蹇撴噺缁?3 婵炴垶鎼╂禍婊堝疮閹捐绀傞柕澹啩鍖栭梺鎸庣⊕閻＄尩ullOpenBegin` 闂佹眹鍔岀€氼剟濡甸幋鐘冲闁靛闄勯弳?/ `applyMorphProgress` /
        //     `morphReset`闂佹寧绋戦惌鍌炲礂濡崵鈻旂€广儱鎳忛煬?`closeFullScreenPlayback` 闁哄鏅滈悷锕€顭囬鐐村剮閻庣數顭堝▓鐘测槈閹炬剚鐓紒杈ㄥ哺婵?
        //   闂?闂佸憡鐟禍婊勬櫠閹稿海鈻旈柕鍫濇祩濞兼岸鏌涘▎妯虹仴闁稿繑锕㈤弫宥囦沪閻ｅ瞼鐣辨俊鐐€涢濠勭博閺夋垟鏋庨梽鍥敋娴兼潙鏋侀柡澶婄仢閻庤崵鈧鍠掗崑鎾绘煥?
        //     闂?婵炴垶鎸堕崐娑€?*婵炴垶鎸哥粔闈浳ｉ幖浣歌Е閻忕偠鍋愰杈ㄧ箾閸″繆鍋撻崘鎻掔稑闂?*闂佹寧绋戦悧鍛姳閵婏妇顩烽柛鎾茶兌婢跺嫰鏌涢幇顒€绾ф俊鍙夋倐濡啫鈻庨幇銊ヤ壕濞达絿鍎ら悾閬嶆煏閸℃洜鍔嶉悗鍨矌閳ь剚绋掗〃鍫ヮ敄娴ｇ儤鍟戝ù锝囶焾閻庡ジ鏌?
        //        闂佽崵鍋涘Λ婊堫敊閹寸偟鈻斿┑鐘插€哥拋鏌ユ煠鐎圭姴袚閻犳劏鏅犲畷妤呭Ψ閵夈儳绋愭繛鎴炴尨閸嬫挻绻涢崱蹇婂亾閸愭彃缍橀梻鍌氬亞閸樻儳鈻?`LV`闂佹寧绋戦ˇ顐﹀闯?闂?**`closeGen`** 闂佺懓鐏氶幑浣烘崲濮椻偓瀵爼濡烽妷銉с偖闂佸憡鐟崹浼村垂閻ｅ备鍋?
        //        闂佹寧绋戝濉丩O` 闂備緡鍙忕紞鈧い銏″灴瀵敻顢楁担褰掓闁诲繐绻楁ご绋匡耿?`gen=`闂佹寧绋戦¨鈧紒?
        //     闂?`morphP` 闂佹椿浜為崰鎾斥枔閹达箑鎹堕柕濞垮妿缁犵懓鈽夐幘鍗炩偓娑€侀幋鐐碘枙閻庯綆鍠楅敍鐔兼偠濮樼厧浜濋柡浣稿悑缁?闂?`pNow=`闂?*濠殿喗绺块崐鏇⑺?*闂備焦褰冪粔鐢稿蓟婵犲嫭瀚氶悹浣哥－椤忚鲸绻涢崱蹇旑潐缂佽鲸纰嶇粙?`from=`
        //        婵炴潙鍚嬮懝楣冨箖閹捐绫嶉柡鍫滅祷缁€?0闂佹寧绋戦惌渚€鍩€?`CLO` 闂備緡鍙忕紞鈧い銏″灴瀵?1.00闂?
        PlaybackPage.ev('LV', `anim gen=${this.closeGen} from=${closeFromT.toFixed(2)} ` +
          `pNow=${this.expandState.morphP.toFixed(2)}`);
        this.expandState.morphBeginLeaving();
        // ★★★ 2026-10-18：**live-morph 关闭路的第一帧快照**（与上面 `RzdCloseFrame sys-back` 对照）。
        //   这一行必须与上一行**同一帧**、且在 `morphBeginLeaving()` 之后 ⇒ 能直接看到
        //   `morphClipping()` 从 0 翻到 1 的那一帧里 `pbY` / `pbOpa` / `radius` / `clipH` 有没有跳。
        //   grep 关键字 `RzdCloseFrame`。期望：`cl=1 pbIn=1.0000 pbY=0.00 pbOpa=1.000 radius=0.00 clipH==winH`。
        Logger.info(PlaybackPage.logTag,
          `RzdCloseFrame live-morph stage=${this.expandState.morphStage} ` +
            `cl=${this.expandState.morphClipping() ? 1 : 0} ` +
            `p=${this.expandState.morphP.toFixed(4)} cProg=${this.expandState.contentProgress().toFixed(4)} ` +
            `pbIn=${this.expandState.pullBottomIn().toFixed(4)} pbY=${this.expandState.pullBottomYVp().toFixed(2)} ` +
            `pbOpa=${this.expandState.pullBottomOpacity().toFixed(3)} ` +
            `radius=${this.expandState.morphRadius.toFixed(2)} ` +
            `clipH=${this.expandState.morphClipHeight.toFixed(1)} ` +
            `winH=${this.expandState.windowHeightVp.toFixed(1)}`);
        // ★★★ 2026-10-20：**这条路上封面归谁 + 落点在哪**，一行判死。
        //   grep 关键字 `RzdClosePath`。`path=reverse` 的期望值：
        //     `overlayPaint=0` —— 壳层 `MorphCoverClone` **不画**（`morphOverlayBridging()===false`）；
        //     `realCover=1`    —— 播放页**真封面在画**（`realCoverVisible()===true`）；
        //     `target=(x,y,w,h)` —— 与迷你条实测胶囊一致（≤1vp），即 B 那一刀 retarget 后的落点。
        Logger.info(PlaybackPage.logTag,
          `RzdClosePath path=reverse overlayPaint=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
            `realCover=${this.expandState.realCoverVisible() ? 1 : 0} ` +
            `target=(${this.expandState.barWinX.toFixed(1)},${this.expandState.barWinY.toFixed(1)},` +
            `${this.expandState.barWinW.toFixed(1)},${this.expandState.barWinH.toFixed(1)}) ` +
            `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(3)}`);
      });
      const closeScale: number = closeFromT < PlaybackPage.REVERSE_MIN_RATIO ?
        PlaybackPage.REVERSE_MIN_RATIO : closeFromT;
      const morphCloseMs: number = Math.round(PlaybackPage.REVERSE_MS * closeScale);
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`MorphGuard.animateMorph` 闂佹眹鍔岀€氼噣顢栭崶銊р枖闁逞屽墴瀹曪綁濡烽婊咁槴闂佹寧绋掓穱娲箲閿濆洦鍋橀柕澶嗘櫆閿涚喎鈽夐弬娆惧剰濠⒀呭█楠?闂備焦婢樼粔閿嬬珶婵犲嫧鍋撻悷閭︽█婵炵鍊楃划锝呂旈埀顒冦亹?
      //   闂佽浜介崝宀勫春?*闁哄鏅滈悷锕€顭囬婊勫仒闁靛鏅滈敍鐔虹磽娴ｈ灏版繛?*闂佹寧绋戝濉箄ietMs` 闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棙鍔栭拏瀣偠濞戞牕鍔︽俊顐㈡健閹虫盯顢旈崟顓犵暢闂佹眹鍔岀€氼厼顪冮崒鐐粹拹?闂佺偨鍎查弻锟犲焵?闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗濞呯姴鈽夐弮鍌氭瀾婵″弶鎮傞獮鎰緞鎼达絾顔嶉梺娲绘娇閸斿酣宕戦敐鍡楊嚤闁绘ê鐏氶悾閬嶆煥?
      //   婵炴挻鑹鹃鍛淬€?`closeSearchMorph` 婵?`SP_SEARCH_SETTLE_MS`闂佹寧绋戦張顒€锕㈤悧鍫濈窞闁告洦鍓涘楣冩煛閸繍妲烽柟骞垮灪閹峰懘寮撮悢鍝ュ帎闂備緡鍋嗘慨鎾偉閸洘鐓傞煫鍥ュ劤缁€鍡涙煏?
      //   闂?闂佺绻戞繛濠偽涢幘顔肩闁靛ě鍕瘞闁荤姷鍎ら崹鐟邦焽閸愵喗鍎嶉柛鏇ㄥ墯椤ρ囨煕婵犲啰鎳曠紒杈ㄧ箞楠炴垿濮€閿涘嫭鎲?闂佸憡鐟﹂悧鐐寸珶婵犲嫧鍋撻悷鐗堟拱闁搞劍宀搁幆?婵炴垶鎸搁敃銊︾珶?婵炴垶鎸撮崑鎾垛偓鍨緲椤戝懐娆㈠璺鸿Е閹兼番鍨归惃鎶芥煥濞戞ê顨欑紒妤€顦扮€电厧顫濋浣藉惈闂佸憡鏌ｉ崝搴ㄥ极閻愵剛鈻旀い鎾噰閸嬫捇寮崶鈺佸姕闂佽偐鎳撻惇浼村焵?
      this.expandState.markMorphQuiet(morphCloseMs);
      // 闂佸疇妫勯幊澶娢?濠电偞鎯岄崰鏍儑娴煎瓨鐒介柨婵嗗椤忚鲸淇婇锝呴嚋缂佽鲸鐟︾粩鐔煎礃閼碱剚鍕?`MorphCoverClone` 闂佹眹鍔岀€氼噣鎮界紒姗嗘Ч闁绘劘灏欏▓閬嶆⒒閸偅绶涚紒?*闂婎偄娲ら幊姗€濡磋箛娑欏仺閺夊牄鍔嶉幏鍗烆熆鐠哄搫顏╅柟顔芥尭椤垽濡烽埞鐐暤闂?* 闂佺偨鍎查弻锟犲焵?
      //   婵炴挻纰嶇换鍐ㄧ暤娴ｇ儤鍠?`PlayerExpandState.applyMorphProgress` 闂?闂佸憡甯炴慨鐢垫暜閳ь剟鏌ゆ總澶夌盎濠殿喒鏅滃鍕吋閸曨厾孝"闂備緡鍙忕徊楣冾敊?+ 闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸抽幆?
      //   闂侀潧妫楁總鏃傜箔閸涙潙绠璺猴工瑜扮娀姊婚崒銈呭箺婵＄偛鍊绘禍鍛婄瑹閳ь剙顭囨导鏉戠闁靛ě鍕瘞闂佸搫瀚烽崹浼存儓瀹ュ拋鍤曢柍褜鍓熼弻鍥晲閸曨収浼囨繝闈涘€归妵婊堝焵椤掆偓缁夋煡鍩€椤掆偓閻ジ鏌堢€靛摜纾奸柣鏃囧吹缁犳煡鏌涢妷褍浠滈柛娅诲洦鈷掓い鎾跺枔濮婇箖鏌￠崼婵愭Ц闁汇劍绻堝Λ鍐閻樻畫妤呮煟閵忥紕婀介柍褜鍓欑粔鏌ュ焵?
      //   闂佸疇娉曟刊瀵哥箔?闂佸憡顭囬崰鎰焽閻㈢鐭楁い蹇撶墛濞村棗顭块悷鏉挎毐闁?`@Monitor('expandState.morphStage')`闂佹寧绋掗悺? 闂?`@Monitor` 闂?*閻庢鍠栭崐褰掝敆?*闂佹悶鍎抽崑鐘绘儍閻斿吋鏅?
      //      闂佸吋婢橀張顒€锕㈡导鏉戠闁兼亽鍎插▓鍫曟煟閵娿儱顏柡浣告贡娴滄悂骞嗚閺嗕即鏌￠崘顓熺【婵炲懏甯￠弫宥夊锤閸掔rphCloseMs + 20`闂佹寧绋戦ˇ鐢稿闯闁垮顕辨慨妯虹－缁犻箖鏌ｉ鐔蜂壕闁?
      //      `morphLand()` 闂?`morphReset()`闂佹寧绋戦悧鍡涘箖濡ゅ懏鍤€?*闂佸憡鑹鹃張顒勵敆?*闂?`morphOverlayP` 濠?0闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
      //      闂佸憡鐟禍锝夈€?`@Monitor` 闂佹眹鍔岀€氼剙煤閺嶎偅瀚柛鎰ㄦ櫅缁楁捇鏌涢敂鍝勫妞わ箑寮堕幏鍛吋閸曨収鍚呴梺鍛婅壘閸戠晫妲愬┑鍫滅剨濞撴埃鍋撴繛闂村嵆閺屽洭鏁愰崟顓т紘濠碘槅鍋呯敮鎺戭潩?*闂佽桨绀侀悺銊╊敊鐏炶В鏌﹂柍鈺佸暞鐏?*闂?
      //      闁哄鏅滈悷鈺呭闯閻戣棄鎹堕柕濞垮妽瀹曟娊鎮跺☉鏍у姦婵☆偅瀵х粙濠勨偓锝庝簻椤?*闂佸憡鑹鹃張顒勵敆?*闂佸摜濮撮敃锝囩博鐎涙鐝堕悽顖ｅ枤缁€澶婎渻閵堝懏鎯堢紒顭戝幘娴滄悂宕ｅΟ鑲╂喒闂佸憡鍔曠粔纾嬨亹閸ヮ剙绀冮柛蹇撴噽閼瑰墽鈧敻鍋婇崰鏇㈠箲閵忋倕绀夐梽鍥儍閻斿憡鍎熼柨鏃囥€€閸?
      //   闂佸疇娉曟刊瀵哥箔?濠电偞鎯岄崰鏍儑娴煎瓨鐒介柨婵嗘閽傚鎮跺☉鏍у姦婵?*閻庤鐡曠亸娆戝垝閿熺姴鎹堕柕濞垮妿閻?*闂佸搫鍟﹢鍦箔婢跺本鍟哄ù锝囨嚀椤儵鏌ㄥ☉妯荤秮overlayTweenAnimating()`闂佹寧绋戦¨鈧紒?
      //      婵炴垶鎸搁敃銉﹀垔?闂佹悶鍎抽崑娑㈡嚇婵犲洦鐒介柨婵嗘閽傚鏌ｉ姀鐘茶埞闁挎稒鎸炬禒?`settlePullOpen` 闂佸憡鐟﹂崹濂稿箲閿濆鏅悘鐐靛亾閻撴瑩鏌涘顓炵仯缂佹鐭傚鐢割敆娓氬洤浠规繛鎴炴尨閸嬫捇鏌ら悿顖涘涧缂佽鲸绻堥獮搴ㄥ閿濆洨鐣洪梺鍝勵槶閸庤精銇愯鐎电厧顫濋鐐╁徍闂佸搫鍋嗛崢濂告偩閻樿违?
      //      闂佹寧绋戝濉畂cusMorphOverlayForPageCollapse` 闂佸憡鍔曢幊姗€宕曠€涙ɑ浜ゆ俊顖滅帛缁犳帒鈽夐幘顖氫壕闁?闂佸搫鐗滈崜婵嬫偪閸℃稑鐭楁い蹇撴祩閸熷懘鎮硅濞撳湱绮╅弶鎴旀瀻?闂佹眹鍔岀€氼剛绮婚幘鍓侀┏濠㈣泛顑呰闂佸搫绉存蹇曟?
      //        闂佹悶鍎虫慨宕囨嫻閻斿摜鐝堕柛鎰皺濠€鎾煟?`@Monitor` 婵炴垶姊婚崰宥囨閹殿喗瀚柛鎰╁妿閺?闂佺偨鍎查弻锟犲焵?闁荤喐鐟ゅù鍥敋濮樿泛绀勯柤鎭掑劜濞堝爼鏌ｉ妸銉ヮ仾闁轰胶鍋ら弻灞剧箾鎼存挸浜鹃柛宀嬪缁€?
      this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
      Logger.info(PlaybackPage.logTag,
        `RzdMorph close tween from morphT=${closeFromT.toFixed(3)} 闂?${morphCloseMs}ms ` +
        `(=REVERSE_MS ${PlaybackPage.REVERSE_MS} 闁?max(REVERSE_MIN_RATIO ${PlaybackPage.REVERSE_MIN_RATIO}, morphT)) ` +
        `easing=REVERSE_EASING(0.85,0,0.5,0.88) overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
        `overlayAnimating=${this.expandState.overlayTweenAnimating()} ` +
        `coverClone=${this.expandState.morphOverlayBridging()} ` +
        `realCover=${this.expandState.realCoverVisible()}`);
      const gen: number = this.expandState.morphGen;
      // ★★★ 2026-10-18（用户第十轮：「展开过程中系统返回**直接没动画了**」）：反向也走逐帧
      //   —— `animateTo` 只把状态变量一次写成终点，几何的写入口是**异步**的 `@Monitor('morphP')`，
      //   于是"反向"没有可插值的旧值→新值，一帧跳完。上游 `animateMorphT(0, reverseMs, REVERSE_EASING)`
      //   （`wujie.pa:154103-154131`）是 `createAnimator + onFrame(v) => morphT = v`，逐帧写真进度。
      //   `morphBeginLeaving()` 已 `cancelContentTween()` ⇒ `applyMorphProgress` 会同时驱动内容窗口，
      //   两层共用这一条 `460 × max(0.4, morphT)` + REVERSE_EASING（不再另写 `contentP`）。
      this.startGeoDriver(closeFromT, 0, morphCloseMs, true, (): void => {
        if (!this.ownsClose(closeToken, 'live-finish')) {
          return;
        }
        this.closeDiagnostic('shrink FINISH');
        if (!this.isAlive || !this.expandState.morphGenAlive(gen)) {
          this.finishCloseGuard(closeToken, true);
          return;
        }
        if (!this.isAlive) {
          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂佹椿娼块崝宥夊春濞戞氨绠?闂?闂佸搫顥￠幍鍐蹭壕閻忕偟鍋撶粻鎺楁煠閸愬弶婀版繛鍛懄閹峰懘宕卞Ο鎭嶏箑螖閸屾耽顏嗏偓瑙勫▕閹囨焻濞戞氨校闂侀潧妫楃粔璺衡枔閹寸偛绶為柡澶嬪灥婵炲洭鎮楀顒傜伇闁哄甯炴禍鎼佸础閻愮鍚柡澶嗘櫆閻熲晠宕?*闂佹寧绋戦ˇ顓㈠焵?
          //
          // ## 闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鏌?闂佺儵鏅涢悺銊ф暜?return"闂佹寧绋戞總鏃傚垝閸喓鈻曢柛顐ゅ枑閺嗩亪鎮樿箛娑氱暫闁稿繑蓱缁嬪顓奸崨顒傞┏
          // ```ts
          //   if (!this.isAlive) { ev('SET','dead'); return; }   // 闂?闂佸搫鍞查崘銊︽濠?
          // ```
          // 婵炲瓨绮岀€涒晛危閹间礁绀勯柣妯夸含缁?*濠殿喗蓱閻℃洜鎹㈠▎鎾崇；婵犲﹤鍟煬顒勬偠濞戞牕鍔︽俊顐ユ硶閹瑰嫰骞嬪┑鍡欏帓闂佹眹鍔岀€氫即宕戦崨顔锯枖妞ゅ繐鍟扮粔瀵哥磽?*闂佹寧绋掑銊ッ规径瀣鐎广儱鐗忕粻鐑芥煛?`LEAVING`
          // 闂?`morphContainerActive()` 闂?闂?`morphClipping()` 闂?
          // 闂?闁诲骸婀遍幊鎾斥枍?`.height()` 闂佸憡鑹鹃崯鏉库枔閹达箑鍙?`morphClipHeight`闂佹寧绋戦悧鍐╂櫠?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹婵炴垶鎸撮崑鎾趁归悩铏伄缂佽鲸绻堝畷娆撴偐閹绘帞锛?vp闂?
          // 闂?**闂佽桨鐒﹂幐鎶藉Υ婢舵劕鐭楁い蹇撴閺嗕即鏌涢幋婵囨儓缂佽翰鍨介幆宀勵敊閻愵剛鏆犳繛鎴炴尨閸嬫捇鏌?*闂佹寧绋戦惌渚€鍩€椤掆偓閻線宕曞Δ鍛柧妞ゆ牓鍊楃粈鍒濵eshCoverBg`闂佹寧绋戦ˇ鏉课ｉ崫銉㈠亾閸︻厽鍤€婵炲懏甯￠幆鍐礋椤愩倖鎲ら梺鐓庢惈閸婂宕?
          // 闂?闁诲繒鍋涚换瀣箔閸屾粈鐒婇弶鍫涘妽绗戦梺娲绘娇閸斿秹宕哄☉姘珰閻庨潧鎲￠悾閬嶆煏閸℃婀版繝鈧笟鈧幊妤冧沪閻愵剛褰叉繛杈剧到濡瑥危閸涘娈楁俊顖氭惈椤斿﹪鏌ｅΔ鍛亾濞戞氨校闂侀潧妫楃粔鏌ュ焵?
          //
          // ## 婵炴垶鎹佸銊у垝閸喓鈻?婵＄偑鍊楅弫璇差焽閺夋娼伴悹浣哥－閸?闂佸憡鐟ョ粔鐑藉焵椤掆偓閺堫剙煤閸ф顥嗛柍褜鍓涢幉鐗堟媴鐟欏嫭姣嗛柣?
          // 闁哄鏅滈悷銈囩博閹绢喖缁╂い鏍ㄧ矋閻ｉ亶鏌涘鐓庝簵缂佺姷鍠栧?闂佽　鍋撻悹楦挎閸熸煡鎮楃憴鍕暡婵＄偛鍊垮畷鎶藉Ω閳轰焦娅旈梺鍝勵槶閸庢彃顪冮崒娑栦簻闁汇垹鎲″銊р偓瑙勭摃鐏忔瑧鍒掗敓鐘茬婵繂鏈粊鏉棵?闂佹寧绋戦惌渚€鍩€?*闂佸憡鍨规慨宕囩礊瀹ュ鍙婃い鏍ㄨ壘瑜版瑥霉濠婂骸浜炴繛?*
          // 闂佹寧绋戝濉抣ayerExpandState` 闂佸湱顭堥崐绋匡耿?AppStorageV2 婵炴垶鎸搁…顓犳濮樿泛鐒?婵＄偑鍊楅弫璇差焽閺夊簱鏌﹂柍銉ㄥ皺閸熷﹪鏌曢崱鏇狀槮闁搞倖鍨堕幏鍛村即閿涘嫮顔庡┑顔界箥娴滅偛顭囬崘顔芥櫖?
          // 婵炴垶鎸搁鍕博閺夋垟鏋庨柍鈺佸暙閳數鈧鍠掗崑鎾绘倶韫囨岸鍝烘俊鎻掓啞缁傛帗鎯旈妶鍥╊啇婵炴垶鎸撮崑鎾趁归悩鍝勑撴い鎺炵秮瀹曟瑩鎮╂潏鈺冃柣鐘欏洦鏁卞褎绮撴俊?
          //
          // 闂?婵炴垶鎸哥花鑲╃箔閸涘瓨顥堥柕蹇嬪€曟禍婵嬫煛?婵炴垶鎸婚悧鏃堝船椤掑嫬鐭楅梺鍨儐閿涘秹姊洪鐔蜂壕闂佽　鍋?**闁诲酣娼х紞濠勭礊閸儱绠ｉ柟閭﹀墯閸婂崬鈽夐幘顖氫壕婵炴垶鎼╂禍婊堟嚋娴煎瓨鍋?*闂佹寧绋戦悧鎾诲磻閸涙潙绾ч柍鈺佸暞閹烽亶鏌℃径鍫濆姎婵ǜ鍔戝浼搭敍濮樼厧娈搁梺姹囧妼鐎氬摜妲愬鑸垫櫖?
          //   缂傚倸鐗愬畷闈浢规径瀣?+ 闂佸憡顨嗛悺鏇灻归崶顒€违闁稿本顨嗛蹇涙煥?婵炲濮寸粔鍫曞礉?*婵炴垶鎸哥粔鐑芥儍?`morphReset()`** 闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷鈺呭闯瀹勬壋鏌﹂柍鈺佸暞缁犳帡鏌涘▎妯虹仸婵炵⒈鍓熼幆?
          //   "婵＄偑鍊楅弫璇差焽閺夋鍟呴柤纰卞墰閻ュ懎鈽夐幘鎰佸剰鐟?闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴鐣濋崘锝呬壕?`morphReset()` 婵炴潙鍚嬮懝鎯э耿椤忓懌浜滈柣銏犳啞濡椼劑寮堕埡鍋亜锕㈤鍡曟勃闊洤娴烽悷鎰版煛閸愵厼鐓愬┑鈥虫憸閳ь剙婀遍幊鎾斥枍閹烘挸绶炵€广儱瀚粔鎾煙鐎涙ê濮堢€殿啫鍛勃?
          //   闂佹寧绋戦悧鎾诲磻閸涱垯鐒婇弶鍫涘妽绗戦梺娲绘娇閸斿秹宕哄☉姘辩當?闂?闂佸搫顦Σ鍕濮樿泛违闁稿本鍑瑰Σ璇裁归敐鍛ゆ繛鍫熷灥椤垽鏁愰崶锝傚亾濮椻偓瀵噣鎳滈崹顐ょ毣闁?`scheduleMorphResetAfterPop()`闂?
          PlaybackPage.ev('SET', `dead闂佹剚鍋呮晶绂+POPT p=${this.expandState.morphP.toFixed(2)}`);
          this.isClosing = false;
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          return;
        }
        // 闂?P0-2闂佹寧绋掔喊宥咃耿閻楀牊濮滄い鏃傚帶瑜扮娀姊婚崒銈呭箹闁告埊绱曢幃?婵炴垶鎸搁鍕博閺夋垟鏋庨柍銉ュ暱瑜扮娀姊婚崒銈呭绩妞ゆ洦鍓欐晥?闂佸憡鐟﹂悧鏃堝船?闂?闂佽　鍋撻悹楦挎閸熸彃霉濠у灝鈧鍒掓导瀛樼劷闁挎繂瀚閬嶅级閻戝棗娅欑紒杈ㄧ箖濞艰鈻庨幘铏仦婵炲濮崑鎾斥槈閺傝法澧﹂柛蹇斏戠粙澶婎吋閸涱剛椹?
        if (closeGen !== this.closeGen) {
          PlaybackPage.ev('SET', `genWait`);
          return;
        }
        // 婵炴垶鎸哥花鑲╃箔閸屾稓鈻旈柍褜鍓熷?*闂備緡鍠栭埀顒傚櫏濞?*闂佹寧绋掗悺鐚歭oseGen` 闂?闂備焦褰冪粔鎾囬弻銉ョ闁规儼濮ら敍?闂佹寧绋戦悾鐠祇rphGenAlive` 闂?闂佺绻戞繛濠偽涢幘顔界劵闁哄倹宕橀崢顒勬煕濞嗗繒澧ｆい顐娴狅箓寮撮悙鐢碉紱"
        if (!this.expandState.morphGenAlive(gen)) {
          // 闁哄鏅滈悷銈囩博鐎涙ɑ濮滄い鏃囧Г閺嗩亪鎮硅閸㈡煡宕欓敍鍕＜闊洦鍑瑰鍫曟煛閸屾稑顥嬫繛鍫熷灱閵囨劙濮€閻樿尙绉繛鏉戝悑娣囨椽鎯佹禒瀣煑闁哄稄绠戦弫鈺呮煥濞戞澧旂紒妤伾戠粋鎺楁晲閸涱厼鈻忛梺鍛婄懄鐪夌紒顭掔節閺佸秵寰勫☉姘辩崶闂佸搫鐗滈崜婵嬫偪閸℃ɑ濯存繝濠傚暟閻旑剟鏌?
          //
          // 闂佸疇妫勯幊澶娢?2026-10-15 闁荤偞绋忛崕鑼閿熺姵鏅柛顐犲灪閺嗗繘鏌熼弶鎴濇Щ闁汇倕瀚湁閻庯絻鍔夐崑?*濠电偛澶囬崜婵堟兜閼哥數鈻旈悗锝庡亜椤庢瑩鏌涜箛鏂库枙婵☆偅鎸抽獮姗€顢橀悢鍛婃緬闂?*闂?闂侀潧妫楅懟顖炲矗瑜斿濠氼敇閻旂鍟婇梺琛″亾闁诡垎鍕綔闂佸憡鍨规慨宕囩不椤斿皷鏌﹂柍銉ュ暱琚熼梺姹囧灪閻綊鍩€椤掆偓缁嬪嫮妲愬鑸垫櫖?
          //   闂佸搫鐗滈崜婵嬫偪閸℃稒鍎嶉柛鏇ㄥ墯閺嗩亪鎮硅閺€鍗炍涢敃鍌涘€块柡鍫㈡暩缁嬪﹪骞栫€电娅愮紒杈ㄧ箘娴滄悂宕￠悙鐢电暠婵?*闂?`isClosing` 闂佽　鍋撻柣鎰靛墮缁?*闂侀潧妫楅崐鎼佹偩閻樿鐭楁い蹇撳闊剙鈽夐幘鎰佸剶婵為棿鍗抽弻鍥晲閸℃鎷┑顔界箰缁蹭粙鎮ラ崼鏇炵哗閻犻缚娅ｉ崯鏌ユ⒑閹绘帞鐒锋い顐畱閵嗘帡宕崘顏嗩槷
          //   闂佸吋婢橀惌浣烘崲閺嶎厼绾ч柍鈺佸暞閿涘秹姊洪鐔蜂壕闁荤姳璀﹂崹鎵?*濠电偛澶囬崜婵嗭耿娴ｅ湱顩烽悹浣哥－缁夊灝霉濠婂棙銆冪紒鍙樺嵆瀹曟ê顓奸崱娆樹紩闁?* 闂?闂佸憡銇涢埀顒冩珪闊?`true` 婵炴垶鏌ㄩ鍛村箖濡ゅ懏鏅?
          //     閻?`onDismissDrag()`闂佹寧绋戦悧濠傦耿娴兼潙妫橀柛銉檮椤愮晫绱?567 闁荤偞绋戦惌澶屾濮樿京绠旀い鎴ｆ硶椤忛亶鎮跺☉妯垮婵?`if (this.isClosing) return;`
          //     閻?`closeFullScreenPlayback()`闂佹寧绋戦悧蹇涱敄?1779 闁荤偞绋戦惌澶屾濮樿泛瑙﹂悘鐐插⒔婢瑰绱掑Δ濠傚幐缂佹柨顕幃鎵沪閼恒儳娈?return
          //   闂?**婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹曞啿鈽夐幘鎶筋€楅柛娅诲洦鈷掓い鎾跺枎閻﹀姊虹粵瀣灈鐎殿喖顭峰畷锝囦沪閻愵剦鏀虫繛鎴炴煥閹冲酣濡甸幋锕€鏋?*闂佹寧绋戦惌渚€鍩€椤掆偓婵傛梻绮弽顐℃勃闊洤娴烽悷鎰箾鐏炵澧叉繝鈧担鍦浄閻犱礁纾粔鍧楁煕閺傝濡块柡?
          //     闂佹寧绋戦悧鎰帮綖閸ヮ剙绠涢柣鏂垮閸斺偓闂?闂佺绻戞繛濠偽涢幘顔肩妞ゆ挾鍠愰弶褰掓煕閿濆啫濡奸柛銈嗗灦缁嬪﹥鎯旈姀銏♀挄闂佸憡鏌ｉ崝搴ㄥ极?闂佺偨鍎查弻锟犲焵?闂佹悶鍎虫慨宕囨嫻閻旂厧绀傞柟鎯板Г閿?*闂佸搫绉烽～澶婏耿閺夊簱鏌﹂柍銉ㄦ珪閸庢瑩鏌?*闂佹寧绋戦ˇ顓㈠焵?
          //   闂佸憡鐟禍婵嗭耿娴ｅ湱鈻旈悗锝庡亽閸嬔囨⒑閹绘帞校闁哄苯锕ュ璇测槈濞嗘劕鍟婇梺琛″亾濡わ絽鍟ㄩ埀顒€顦甸弫宥夊醇閻斿摜鍘愰柣搴℃贡閸嬫娆㈤妷鈺傛櫖濠㈣泛顑呴·鍛?闂佺厧顨庢禍婊呮崲娴ｅ湱闄勯柟瀛樺笧閸?闂佹寧绋戦張顒佹櫠瀹ュ棛顩烽柕澶堝妿缁犵懓鈽?bug 閻庡灚婢橀悧鍡涱敊閹版澘鍙婇柟鎹愵嚃濞煎墎鎲搁悧鍫熷鞍闁搞劍宀稿畷鎴犳崉閸濆嫮宀涢梺?
          //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃顏勵焽?`closeGen !== this.closeGen` 闂備緡鍙忕徊鎯ь焽?*婵炴垶鎸哥粔鐑藉礂?*闁哄鏅滈悷锕傛偋閸楃偑鈧帡宕崘顏嗙崶闂備緡鍙忕徊鎯?闂佸搫鍊块。锔剧博鐎涙ɑ濮滄い鏃傚帶瑜扮娀姊婚崒銈呭箹闁告埊绻濋獮鎺楀Ψ瑜滈崥鈧?闂?
          //      闂佸搫绉村ú銈囨崲閺冨洢浜归柟鐑橆殔娴滄繂鈽夐幘顖氫壕闁哄鍎愰崰姘额敇閹间焦鏅柛顐ｇ箘閺嗗﹪鎮硅濠㈡﹢宕虹仦鐐氦婵炲棙鎸稿▍锟犳煛閸愨晜鏋勭紒鍙樺嵆閹虫盯顢旈崟顓犵暢濠电偞鎸搁幏鎴犳濠靛鐓ｉ柟顖嗗懐顢呴梺鐓庮殠娴滄繈宕滈妶澶嬫櫖濠㈣泛鐗冮崑?
          Logger.warn(PlaybackPage.logTag,
            `RzdMorph close aborted by new morph session gen=${gen} ` +
            `liveGen=${this.expandState.morphGen} stage=${this.expandState.morphStage} ` +
            `闂?release isClosing + finish the close`);
          this.isClosing = false;
          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*"闂佺粯鍔楅幊鎾诲吹椤曗偓瀹曟骞庨懞銉川 / 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧?闁哄鏅滈悷銈囩博閹绢喖绾ч柨娑樺閻ｉ亶鏌￠崼姘壕闂佸憡鑹剧花鑲╃博閹绢喖閿?*闂佹寧绋戦¨鈧紒?
          //   婵炴垶鎸搁敃顏勵焽娴煎瓨鐒介柨婵嗘閽傚鏌￠崘锝嗘珚闁逞屽厴閸?*闂佸憡鐟禍婵嬪棘娴ｅ壊鍤曢柍褜鍓氱粋?`isClosing`闂佹寧绋戦張顒勬儉閸涙潙瀚夊璺侯儏閼靛綊寮?闂佺绻戞繛濠偽?闁哄鏅滈悷銈呪枎閵忥紕顩查悗锝庡亝閹烽亶妫?*
          //   闂?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柛蹇撴憸缁?*濠殿喗蓱閻℃洜鎹㈠▎鎾村仼婵炲棗绻戦煬顒勬倶閻愯尙绠ｇ紒?*闂佹寧绋戦悧蹇涘极閵堝绠ｅ瀣娴狀垶鏌涜箛鏂库枙婵☆偄鐡ㄧ粙濠勨偓锝庝簼閸婄敻鎮橀悙鑼缂佹鍊圭粋鎺楀焵椤掍胶鈻曢柛顐犲劚閸樺瓨绻涚仦绯曞亾閸愯尙宀涢梺姹囧灮閸ｏ妇妲愬璺何?
          //   婵炴垶鎹佸銊у垝閸喓鈻曢柛顐秬濞夋煡鏌涢幒鎾愁€滅紒缁樼墵閺屽苯鐣濈€ｎ剛鐛ラ梺琛″亾闁诡垳澧楀畷鎶藉级閳轰焦宸濋柍璇插悑缁嬪顢橀垾鎰佷户 `morphGen` 闁?`morphReset()` 濠电偞鎸搁幊鎾舵崲閸愨晝鈻旈柍褜鍓欓埢?
          //   闂佹寧绋戦悧鍡涘触閳ь剟鏌涢妸銉剱婵炲ジ娼ч埞鍐箛閸撲胶鐛ラ梺鍦檸閸樹粙寮担骞夸簻濞达絽鍟▓浼存椤掑浜炴繛?`onDisappear` / 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨鹃崣澶嬬彿闂佸憡顨嗛悺鏇灻?/ 婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏃傛櫕閺嗘瑩鏌ｉ敐鍡欐噭缂佹柨顭烽幃鍫曞幢椤撶姷顦梺?
          //   婵炴垶鎸婚悧鏃堝船椤掑嫬鐭楃€瑰嫮澧楅惃鎴濃槈閹惧啿顒㈡繝鈧悧鍫熷妞ゆ棁妫勭粈瀣煠妤ｅ喚妫戞繛鍫熷灦缁嬪顓奸崨顔尖偓?闂佺偨鍎查弻锟犲焵?闂?*闁哄鏅滈悷銉╂嚐閻斿摜鈻旂€广儱瀚弫鈺呮偠?闂佹椿娼块崝宥夊春濞戞瑧鈻旂€广儱妫楅崢鎺楁煕韫囨挸甯犵紒?**闂?
          //   闂?闂佸搫鐗滈崜婵嬫偪閸℃稑绫嶉柕蹇嬪灩婵囨煛?闁荤喐娲戠粈渚€宕?闂佹寧绋戦懟顖氼潩閵娾晛绠┑鐘插€歌ぐ鐘绘⒒閸屻倕骞楅悽顖氱秺瀹曟岸寮剁捄銊や孩闂?
          //     闂?闂佺儵鏅涢悺銊ф暜閹绢喗濯伴柟瀛樺笧缁夋挳鏌ㄥ☉妯荤秮morphLand()`闂佹寧绋戞總鏃傜箔鐏炵瓔娼伴柨婵嗘噽閸╂鏌￠埀顒傛崉閾忕懓鏆￠梺鍛婅壘婵傛梻绮╅弶鎴桨闁靛鍨崇粈鍡涙煥?
          //     闂?闂佸憡顨嗛悺鏇灻归崶顒€绠绘い鎾跺枑閺夌懓顪冮妶鍥舵殰缂佽鲸鐛媔sShowPlay=false`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
          //        闂佺儵鏅犻弲鑼礊閸涱喚鈻旈幖绮光偓铏吇婵炶揪绲惧ú婊冣枔閹存縿鈧帡宕ㄩ娑樷偓鐐烘煟?*闂佸憡顨嗛悺鏇灻归崶顒佺叄闁硅鍔曞▓鎵偓瑙勭摃娴滎剙鈻?* `onDisappear 闂?morphReset()` 闁荤姵鍔楅崰鏇㈡儗濡ゅ懏鏅?
          //        闁哄鏅滈悷鈺呭闯?*婵炴垶鎸哥粔褰掑闯閸涘﹤绶炵€广儱鐗忓▓?*闂佹寧绋戦悧鎾诲闯閸涘﹤绶炵€广儱鐗忓▓璺好归崗鑹板闁哥啿鍋撴繝銏ｅ煐绾板秶鏁憴鍕枖闁逞屽墮閳?`morphGen`闂佹寧绋戦懟顖炲春濡ゅ懏鐒婚柣妯夸含閻熸挸鈽夐幘顖氫壕闁哄鍎愰崰姘枔閹达箑瑙︾€光偓閳ь剛鎮锔解拻妞ゆ洍鍋撴い锝勭矙閺佸秵寰勯崼姘壕?
          //   闂佸疇娉曟刊瀵哥箔?濡ょ姷鍋涢崐濠氭偤?闁诲海鎳撻ˇ顖炲矗韫囨稒鏅慨婵囶劉sShowPlay` 闂佸吋鐪归崕閬嶅礄閿熺姴鍙?false闂佹寧绋戦悾鐟籑onitor` 婵炴垶鎸哥粔宕囨娴煎瓨鐓傜€广儱鎷嬪Σ濠氭煕閺傝濡虹紓宥嗘閺?
          //      `morphLand()` 闂侀潻璐熼崝鎴濐焽椤忓洢浜归柕蹇曞Т缂嶄線鏌熼璺ㄥ妽婵℃彃鎽滈埀顒傛嚀椤︻垶宕ｈ箛娑欏剭闁告洦鍘搁弫鍕煙閸喚小缂傚秵姊婚幏鐘活敇濠靛牏鏋€闂佹寧绋戦悧鍡氥亹瑜忕槐娆撴嚒閵堝棛銈叉繛?+ 婵炲瓨鍤庨崐娑氭崲閺囥垹绠ラ柍褜鍓熷鍨緞鐎ｎ偆绉梺鎸庣☉椤︻參鍩€?
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          PlaybackPage.ev('SET', `genBAD闂佹剚鍋呮晶绂+POPT`);
          return;
        }
        PlaybackPage.ev('SET', `ok gen=${closeGen}`);
        this.isClosing = false;
        this.restorePlaybackWindowChrome();
        // LANDING闂佹寧绋掔喊宥夘敆濠靛绀嗙紓浣股戠亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢跺鍟呴柤纰卞墰閻ュ懐绱撻崒妤佹珕闁搞劍宀搁弻鍛扮疀閺冣偓椤牠鏌ｉ妸銉ヮ仹缂佹柨顕禍姝岀疀閹炬潙浠撮梺鎸庣☉閺堫剚淇婇崨濠冧氦闁炬艾鍊荤粙鎴︽煛婢跺棌鍋撻崣澶婃敪闁哄鏅滈…鍥╁垝閹殿喒鍋?
        // 闂佹寧绋戝濉礽niBarOpacity()` 闂侀潻璐熼崝鎴濐焽?ENTERING/LEAVING 闂佸搫鍟抽崺鏍ㄧ閼恒儳鈻?1闂佹寧绋戦¨鈧紒杈ㄧ箞瀹曟ê顓奸崨顓犮偦闁哄鍋涢～鏇㈠焵?
        this.expandState.morphLand();
        PlaybackPage.ev('LND');
        // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`squashLand`闂佹寧绋戦¨鈧紒?*闂佽В鍋撻柟瀛樺笧缁夋挳姊洪銊у缂佹柨顕弫顔款樁闁?闂佸湱铏庨崢浠嬪棘娓氣偓瀵爼鍩勯崘銊ф瘍闂?闂?闂佹悶鍎抽崑娑㈡嚇?**闂?
        //   婵＄偑鍊曢幖顐よ姳椤撱垹妞介悘鐐靛亾閿熴儵鏌ｉ敐鍛劯闁逞屽墯閸旀洟鎮鸿缁嬪鍩€椤掑嫭鍤婇弶鍫濆⒔缁愭setMorph(LANDING)`闂?`morphLand()`闂佹寧绋戦張顒€锕㈤幍顔芥殰鐟滃酣骞愰柆宥呯哗濡わ絽鍟ㄩ埀顒€顦靛畷鎴濐煥閸涱垱鍣抽梺?
        //   闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁嶉崟顒€鐒搁梻濠庡墻閸嬪懎螣婢舵劕绀勯柣鎴炆戦梽宥夋煥濞戞﹩妲撮柛?`animateSquash(SQUASH_Y 0.86, 110ms)` 闂?320ms 闁哄鏅涘ú銈夊疮閸ф鐐婇柣鎰蔼閸撱劑鏌?
        //   闂?闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸抽幆鍐礋閳规儳浜鹃悘鐐靛亾閿熴儵鏌ｉ敐鍛板闁告鍥ㄢ拻妞ゆ挾鍠愰ˇ褔鏌熺紒銏犲箺闁哄倷绶氬鍫曞灳閼碱剛鐛ラ悗娈垮櫍閳ь剚绋撻鍗炩槈閹炬剚鍎嶉柍褜鍓欑粔鏉戭潩閵娾晛鍙婃い鏍ㄧ箘缁犵懓鈽夐幘顖氫壕闁诲海鏁搁、濠呮＂闂傚倸鍊归悾顏堝焵?
        //   闂佸疇娉曟刊瀵哥箔?闂婎偄娲ら幊姗€濡磋箛娑樻嵍?`morphLand()` 婵炴垶鏌ㄩ鍛村箖濡ゅ懏鏅慨姗嗗幗閿涘秴鈽夐幘顖氫壕闁汇埄鍨庨崘鈺冩闂?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暟缁犵兘鏌涢敂鍝勫闁轰線绠栨俊瀛樻媴鐟欏嫯鎷梺绋跨箰閻楀棝鎳?闂?
        //   闂佸疇娉曟刊瀵哥箔?**2026-10-17 闁荤姳闄嶉崹娲敆?*闂佹寧绋掓穱铏规崲閺嶃劎鈻旈柍褜鍓熷畷锝夊Ψ閵夈儲鏋鹃梺鍝勵槶閸庤尙鏁幘顔藉創闁逞屽墴瀹?婵?`morphReset()` 闂佹眹鍔岀€氫即濡存惔銏″劅闊洤娴烽悷婵嬫煠鐎圭姵顥夌€?闂?
        //      闂佺粯绮嶅妯猴耿?`morphReset()` 閻庤鐡曠亸娆戝垝?*婵炴垶鎸哥粔鏉戯耿椤忓懏浜ゆ繛鍡樻尭濞?*婵炲瓨绮屽Λ瀵告濞嗘挸缁╅悷娆忓閻?缂?pop 婵炴垶鏌ㄩ鍛村箖?闂?
        //      闁荤喐鐟ゅ鎺旂箔閸涘瓨顥堥柕蹇嬪€曟禍婵囩箾閸粎绁锋い鏇楁櫊瀵増鎯斿┑鍫㈡喛 `scheduleMorphResetAfterPop()`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
        //      闂佸湱顣介崑鎾趁归悩顔煎姎闁伙絿濮电粙?`squashLandAnim()` 婵炴垶鏌ㄩ澶娢涢幐搴ｂ枖鐎广儱鎳庨弲娆撴煛閸繍妯€闁靛棗瀛╅幆鏃囩疀濞戞瑱绱俊顐ゅ鑿ч柍?
        //      闂佸疇娉曟刊瀵哥箔?婵?`morphReset()` **婵炲濮寸粔鍫曞礉瑜庣粙澶婎吋閸ヨ埖楠?* `morphSquashY`闂佹寧绋戦悧濠勪焊鐎ｎ喖鍌ㄩ悗锝庡亝绗戦梺缁樼懐閸撴盯鎮靛☉銏″剭闁告洦浜為閬嶆煛婢跺棗澧查柣鏍电秮閺屽矁绠涢妷褏顦梺?
        //      闂佸湱顣介崑鎾趁归悩顔煎姦闁稿鎳忕粙澶愬焵椤掆偓铻為柟鐑樺灦闊剙顭跨捄铏剐＄紓宥呮噺缁嬪﹦鈧綆浜濋崐鐢告煟閹炬瀚竟澶娒归崗鑲╊暡濠?0.86 閻庢鍠氶幊鎾趁?1闂?*闁哄鏅滈悷锕€危閸濄儲鍟哄ù锝囧劋閻?*闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閳ь剙鈻撻幋锔藉闁瑰瓨甯炵粔鎾煕閵壯冧粶闁兼潙锕弫宥嗗緞閸艾浜?
        this.expandState.squashLandAnim(this.getUIContext());
        PlaybackPage.ev('SQZ');
        this.state.isShowPlay = false;
        PlaybackPage.ev('POPT',
          `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂佹椿娼块崝宥夊春濞戞氨绠?闂?闂佸搫顥￠幍鍐蹭壕鐎光偓閳ь剟鎮版繝鍥ㄥ€块柤绋跨仛闂勫秴鈽夐幙鍐х盎闁活偄绉撮锝夊焵椤掑嫬绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ婵炲牊鍨垮畷婵嬪Ω瑜庨弳浼存煏閸℃肖婵炲牊鍨垮鐢稿传閸曨偆鍘紓浣哄珡閸屾稑寮垮┑?*闂佹寧绋戦ˇ顓㈠焵?
        //
        // ## 闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鏌?闂佸憡鑹炬總鏃傜博?tick 闂備焦褰冮懟顖炲箖閹炬剚娼?morphReset()"闂佹寧绋戞總鏃傛嫻閻斿摜顩烽柍褜鍓氱粙濠囧醇閵夈儰绨奸梺鍝勫閸ㄥ爼寮繝鍥ㄥ剭?
        // ```ts
        //   this.state.isShowPlay = false;   // 闂?婵犮垻鎳撻崯鍧楁儑?@Monitor闂佹寧绋戝﹢? 閻庢鍠栭崐褰掝敆閻愮儤鏅璺烘閺?popPlayerRoute()
        //   this.expandState.morphReset();   // 闂?闂佸憡鑹鹃張顒勵敆閻愮儤鏅€光偓閳ь剟骞撻敐鍥ㄥ磯闁绘柨鍢插鎾绘煕?
        // ```
        // `morphReset()` 婵炴潙鍚嬬喊宥嗕繆?`morphStage` 濠电偞鎸搁幊蹇涘垂?`NONE`闂侀潧妫斿姊瀘rphP` 婵犮垼娉涚粔宕囩礊閸涙潙绠?1闂?
        // `morphClipHeight` 濠电偞鎸搁幊妯好归崒鐐参ュ☉鏃戞煃orphScale` 婵犮垼娉涚粔宕囩礊閸涙潙绠?1
        // 闂?`morphContainerActive()` 缂傚倸鐗愰褎绂?闂?闁诲骸婀遍幊鎾斥枍?*婵炴垶鎸哥粔鐑剿夐崱娑樼妞ゅ繐鍊甸崑鎾存媴妞嬪海鎲圭紓鍌氬€甸弲婊堝棘娓氣偓婵″瓨鎷呮搴ｆ喒婵炶揪绲界粔鏈电昂** = **濠电姴艌閳ь剙纾宀勬煙缂併垹骞楅柡鍌欑劍閵?*闂?
        // 闂佸吋婢橀惌渚€鎯屾ィ鍐╁仺閺夊牜鍋掑ú锝夋煕?*婵炴垶鎸搁鍕博鐎靛憡鏆?*闂佸綊娼х粔鐑斤綖?`pop(false)` 闂佺濮よ摫閻㈩垪鍋撻梺鎸庣☉濞煎牼Monitor` 濠电偛寮堕崕瀹犮亹閸屾稓鈻旈柍褜鍓涙禒?+ 闁汇埄鍨伴崯顐︽儑椤掑嫬绠烘慨妞诲亾婵炲懎瀛╃粙澶愬焵椤掑倷娌柛宀嬪缁€?
        // 闂?婵炴垶鎼╅崣鍐ㄎ涢崸妤佺劷?1~2 闁汇埄鍨庨崘顏呯秳婵炴垶鎸搁敃銈咁潩閵娾晛鍙婃い鏍ュ€楃粣?
        // ```
        //   閻庤鐡曠亸娆戝垝閿涘嫮纾介柍鍝勫€搁悘鍥倶韫囨挾绠版繛鎾荤畺閹瑩鎯傞崫銉ь槱LANDING闂佹寧绋戦惌渚€锝為敂鐐晳濞达絽鎲￠煬顒勫级閳哄嫭鑵圭紓宥嗭耿瀵爼鏁撻悩韫凹婵炴垶鏌ㄩ悧鎾绘偟椤曗偓閺?闂?缂備焦鍔掗懗鍫曞礉瑜嶉…銊╁灳瀹曞洦缍勯梺鍦檸閸樹粙寮担骞夸簻?闂?濠电偞鍨甸悧鍡涘Φ?
        // ```
        // 闁荤喐鐟ラ崐褰掑礉閸涱収娼伴柨婵嗘绗戦梺娲绘娇閸斿秹宕哄☉姘珰閻庨潧鎲￠悾閬嶆煏閸℃瀚板┑顔规櫊閹粙鎳￠妶鍥ㄥ皾闂佸搫顦遍崰宥囪姳?*缂備焦鍔掗懗鍫曞礉瑜斿鍫曞Ψ閵堝娈濋柣蹇曞仦濞叉牜妲愰幋锕€绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ婵炲牊鍨垮畷婵嬪Ω瑜庨弳?*闂侀潧妫楃粔鏌ュ焵?
        //
        // ## 婵烇絽娴傞崰妤冩兜閸洘鏅?*缂備焦绋戦ˇ鐢稿Υ婢舵劖顥堥柕蹇嬪灪閸╁倿鏌ｉ妸銉ヮ仹缂佹鎳樺畷锝夊级閸喗娅冩繝銏ｆ硾缁夊磭绱為崨鏉戠闁绘浜粔?*
        // 闂佽В鍋撻柟瀛樺笧缁夋挳鏌ㄥ☉妯荤秮morphLand()`闂佹寧绋戦ˇ顖炲礄閿涘嫮纾奸煫鍥ㄦ煥鎯熺紓鍌欑劍閿氶柛鈺傤殜瀵爼宕樿閸炲寮堕埡鍌ょ劷缂侇喚澧楀濠氭憥閸屾粎鈽夐梺鍝勵槴閳ь剝灏欓崯濠囨煥濞戞鐒搁柛瀣噺缁嬪鍩€椤掍胶顩?闁荤偞鍑归崑澶愃夐崱娑樻嵍闁靛鍔庣喊鍐归敐鍥ｆ繛纰卞灦閺屽洭鏁愰崟顓犳澖婵?闂?
        // 闂佸憡鍨规慨宕囩礊?*闂侀潻璐熼崝鎴﹀Υ婢舵劖顥堟い顐幘閻熸捇鏌涘▎鎿冩殥缂佺媴缍佸畷婊冾吋閸℃锕傛倵閻熸媽瀚伴柛娆忕箰椤垽鏁愰崶锝傚亾濮椻偓閹啴宕熼浣叉灃缂備讲鍋撻柧蹇曟嚀绗戦梺?*闂佹寧绋戦悧蹇涘极閵堝绠ｅ瀣缁犳瑩鏌涢幒鎾愁棆婵炲牊鍨规禍鍛婃綇閵娤€锕傚级閳哄嫭鑵圭紓宥嗭耿瀵爼鍩ラ崨顖滎槴闂佺偨鍎查弻锟犲焵?
        // 闂佸湱顣介崑鎾趁归悩顔煎姎妞わ箑寮堕幏?*濠电偛澶囬崜婵嗭耿娴ｅ湱顩烽悹浣哥－缁夊潡鏌ｉ悙鍙夘棤闁?*闂佺缈伴崹鐟帮耿?pop 闂佸憡鎸哥粔鐟邦焽娴兼潙纾绘慨妯稿劗閸?
        // 闂佸疇娉曟刊瀵哥箔?婵炶揪绲藉Λ鏃傚姬閸愨晝鈻旂€广儱鐗嗛崢鏉戔槈閹惧磭孝濞寸姵鐩弫宥咁潩椤掆偓濞堛倕霉閿濆棙绀冩俊鍙夋倐瀹曟宕ｅ鈧悡鈺呮煟閵娿儱顏电紒杈ㄧ箖缁嬪顓奸崪浣剐╂繛杈剧到缁夊磭妲愰弶鍟冄囧焺閸愵亜甯繛鎴炴尭椤戝嫮绮╃€涙ɑ濮滄い鏇炴缁€鍕偡?`morphGenAlive` 闂備緡鍙忕紞浣圭妤ｅ啯鈷掓い顓熷笧缁€鍡涙煏?
        // 闂?婵炲瓨鍤庨崐妤冨垝?`scheduleMorphResetAfterPop()`闂?*闁哄鍎愰崰娑㈩敋濡ゅ懎绀?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暟閻斿懘鏌ｉ姀鐘茶埞闁告埊绱曠槐鎺曠疀鎼达絿鎲归梺闈╄礋閸斿秹鎮ラ妶澶嬬厒?闂佸綊娼х粔鎾囬崣澶嬪?*闂?
        //   濡ょ姷鍋犲▔娑㈡偨?闂佸搫鍊块。锔剧博鐎涙ɑ濮滄い鏃囧吹缁愭鎮归崶銊х畵闁告埊绻濋獮鎺楀Ψ瑜滈崥鈧柣蹇撶箰瑜板绮径灞惧闁告稑锕﹂?闂佹眹鍔岀€氼剙顕ｉ懡銈傚亾閻熸壆澧曠€规洖銈告俊?
        this.finishCloseGuard(closeToken);
      });
      return;
    }
    // 濠电偛澶囬崜婵嗭耿娓氣偓瀹曪綁顢涢悙瀛樼ギ闂佸憡鍨规慨宕囩礊瀹ュ绫嶉柛鎾茬劍缁绢垶鏌熼幁鎺戝姎闁告鍥ㄢ拻妞ゆ挶鍔庣粈澶岀磽娴ｅ湱绠戠紒妤€顦靛畷鍫曟倷鐞涒€充壕闁逞屽墴瀹曟岸寮堕崹顔绢伝闂佺懓鍚€缁€渚€宕€电硶鍋撻崷顓熷殌闁活亙鍗抽幆鍐礋椤掍緤绱滈柡澶屽剱閸撴瑥鈹冮埀顒勬煏?
    Logger.warn(PlaybackPage.logTag, 'collapse without geometry: immediate landing');
    PlaybackPage.ev('CLO', 'noGeom');
    this.isClosing = false;
    this.restorePlaybackWindowChrome();
    this.state.isShowPlay = false;
    PlaybackPage.ev('POPT', 'noGeom');
    // 闂?闂?濠殿喗绻愮徊浠嬫偉閸洖缁╅悹楦挎閸熸煡鏌￠埀?闂佹寧绋掗懝楣兯囬崣澶嬪鐎广儱鎳庡▓銈吤归敐鍡樼缂佺儵鍋撴俊?*缂備焦绋戦ˇ鐢稿Υ婢舵劖顥堥柕蹇嬪灪閸╁倿鏌ｉ妸銉ヮ仹缂佹鎳樺畷?*闂佹寧绋戦悧鎰帮綖?`scheduleMorphResetAfterPop`闂佹寧绋戦ˇ顓㈠焵?
    this.scheduleMorphResetAfterPop(this.closeGen, this.expandState.morphGen, 0);
    // 闂佺绻戠划宀€鑺卞畷鍥ㄥ磯妞ゆ牗姘ㄧ粣鐐测槈閺冨倸鏋欐い鈺嬬畱椤曪綁鏌呭☉姘间紘婵炴垶鎸搁鎴犳娴兼潙瑙﹂柨鏇楀亾闁?闂佸憡鍨规慨宕囩礊瀹ュ應鏌﹂柨鐔哄Т濞呫倝鏌?闂佸搫鍟崕鑲╂崲閺嶎厼绾ч柍銉ㄦ珪閺嗘粌鈽夐幘顖氫壕闂佹眹鍔岀€氼參寮崷顓熷皫鐎瑰嫭婢橀崘鈧俊顐到閻楀棗顫濋妸鈺佹瀬缂傚牏濞€閸ゅ绻涚仦绋垮⒉婵犫偓?
    this.expandState.squashLandAnim(this.getUIContext());
    this.closeDiagnostic('shrink FINISH no-geometry');
    this.finishCloseGuard(closeToken);
  }

  /** 婵炴垶鎸搁敃銉╊敃?`logBranchSurface()` 闂佺懓鐏氶幑浣烘崲閸愵喗鍎嶉柛鏇ㄥ弾閸旑噣鏌涘顒傗枌缂佽鲸鐟╅幃浠嬪Ω閿斾粙妾烽梺纭呮硾閿曨亪宕抽崨濠傜窞鐎广儱顦▍銏㈢磽娴ｅ顏嗘暜閸ヮ剙绠ｉ柟閭︿簽椤忛亶鏌℃径鍡橆潐缂佽精浜幉瀛樻媴缁涘娈欓梺鍝勫€介～澶屾兜鐠鸿　鏋栭柕濞炬櫅濞呯偤鏌ㄥ☉姗嗘Ф闁?*/
  private lastBranchLog: string = '';

  /**
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇撁烘导鏉戝唨?闂?闂?*闂佸憡甯掑Λ娆撳极椤旇￥浜归柟鐑樺灩濞硷綁鎮归崶褝鏀婚柡?+ 闂佺粯顨呴悧鎾愁焽閻楀牏鈻旂€广儱鎳庣紞渚€姊洪幓鎺旂闁搞倖绮岃灋闁?*闂佹寧绋戦¨鈧紒鍙樺嵆楠?闂佺粯绮嶅妯猴耿椤忓牆绀嗛柡澶庢硶娣囨椽鎮硅婢瑰棗鈻撻幋锕€浼犳い蹇撳暟椤忛亶鏌℃径鍡忓亾閸愯尙鈧鏌￠埀?+
   * 闂備緡鍙忕徊鑲╃博閹绢喖缁╂い鏍ㄧ矋閻ｉ亶鎮楅崷顓炰沪缂佷焦鎸冲畷娆撴偐鏉堚晝协 + **婵炴垶鎸哥粔纾嬨亹婢舵劖鐓傞煫鍥ㄦ⒐绗戦梺鍛婄啲闂勫嫰宕瑰杈╁崥?*"闂佺懓鐏氶幐鎼佸吹椤撱垹绾ч柕澶涚岛閸?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劜娴犳﹢鎮烽弴姘鳖槮闁?
   *
   * 闂佸搫鐗滈崜鐔煎Υ婢舵劖鍎嶉柛鏇ㄥ亞椤忔挳鎮橀悙鈺佷壕闂?*婵炴垶鎸搁ˇ鏉款焽椤栫偛绀嗛柛鈩兩戦弳?*闂佹寧绋戝濉╱ildControlStack()`闂佹寧绋戦¨鈧紒?
   * ```
   *   panel闂佹寧绋戦悧鎾愁焽娴兼潙绾ч柛鏍电磿缁€? 闂?usePanelLayout()
   *   wide闂佹寧绋戦悧鍡涱敊閺冨倷娌?濡ょ姷鍋犲▍鏇烆熆濮椻偓閺佸秵寰勯崱妤佹珝 闂?SM 婵炴垶鎸诲Λ鍐焽椤忓牊鏅柛锔绘惓 + HEIGHT_SM闂?
   *   phone闂佹寧绋戦悧濠冩櫠濠婂牆瀚夐柣姘嚟缁€? 闂?闂佺绻戝﹢鍦礊?
   * ```
   * 闂?*闂佸憡鐟禍婵嗭耿娓氣偓楠炲秶鈧綆鍋呯花姘辨喐閼割剙鐏柍褜鍏涚粈浣革耿椤忓牆瀚夋い鎺嶇劍缁ㄦ岸鏌涘▎妯虹仭闁诲寒鍨堕弻?* 闂?闁诲海顢婂Λ鍕儓?濡ょ姷鍋犲▍鏇烆熆?濠碘槅鍨兼禍婊堟儓?PC 闂備緡鍙忕徊鑲╂偖闁秴绾?*婵炲濮寸€涒晛顭囬棃娑掓煢闂勫洭锝為敂绛嬫鐎光偓閸愵亞鐣?*闂?
   * 缂備焦绋戦ˇ鎵偓锝勭窔瀹曟碍瀵奸弶鎴滅凹婵炲瓨绮嶇粙鎴︽嚋娴兼潙绠戝ù锝堫潐椤ρ囨煥濞戞鐏辨い鎴濇处缁嬪鍩€椤掍胶顩烽柟顖炲亰濞诧綁鏌ｉ婊冨姦濞存粓绠栭幆鍐礋椤忓棛娈ら梺?**闁诲海鎳撻崯顐﹀春鐏炵偓鍎熼柡鍤躲倖宸㈡繛瀛樼矊濡骞楅姀锛勨枖闁逞屽墴瀵?*"闂佺偨鍎查弻锟犲焵?
   * 闂佹悶鍎虫慨宕囨嫻閻斿摜鈻斿璺侯儐閽傚鏌涢幒鎴烆棡闁轰緡鍣ｉ幆?*闁诲繐绻嬬欢姘焽閺夎￥鈧帡宕ｆ径灞藉脯闂佸吋婢橀幊宥囩箔婢舵劕瑙?*闂佹寧绋戝绌恛ne = 闁荤喐娲栧Λ娑樏烘繝鍕勃?`LyricFloatLayer`闂佹寧绋掔涵顦廳e/panel = `MusicPlayInfoBlock`闂佹寧绋戦¨鈧紒?
   * 婵炴垶鎸撮崑鎾绘煛閸愯法鐣遍柛銊ラ叄瀵劑顢涘顒備紙闂佺顕栭崰鏇犵箔鐏炴拝绱ｉ柛鏇ㄥ墯閸╁倸鈽夐幘宕囆ゆい鎴滅窔閺佸秴鐣濋埀顒€螞娓氣偓閹晠寮甸悽鐢电崶闁荤偞绋忛崝搴ㄧ嵁閸ャ劎鈻?闁诲繐绻嬬欢姘焽閻楀牊濯寸€广儱娲ㄩ弸鍌溾偓鍨緲閻楀棝銆冨畝鍕畱?闂佹寧绋戦惌渚€鍩€椤掆偓閺堫剟鎮ч幘顔肩倞闁绘ɑ褰冨鎾绘倵閸︻厼浠︽俊?闁荤姍鍌氬祮闁轰礁锕ョ粋宥夊幢濡粯娈?闂?
   *
   * ## 婵炴垶鎸哥粔纾嬨亹婢舵劖鐓傞煫鍥ㄨ壘濞堢増淇婇鐔蜂壕闂佹寧绋戝濉眓v=` 闂備緡鍙忕徊鑲╃博閹绢喖绀嗘俊銈咁儑缁€鍡涙煃閵夛附鐓涢柍?闂?闂佹椿浜滈鍥ь焽閸愨晝鈻旂€广儱鎷嬮崵?闂佸憡鐟﹁摫闁?闂佸搫鍟ㄩ崕杈╂崲閺冨牊鍎庨悗娑櫭径宥夋偣閸モ晝绡€缂佹顦甸獮瀣箛椤旀儳缍?
   *
   * | 闂佸搫绉村ú鈺咁敊?| 闂佸搫鍋嗛崣鈧柍?| 婵炴垶鎸哥粔鐢稿垂濮樿京鍗氶悗锝庡弾閸ゆ盯鏌￠崟顐ゅ嚬缂侇喖鐗婄粙?|
   * | --- | --- | --- |
   * | `coverNone` | 闁诲繐绻嬬欢姘焽娴煎瓨鍤嶉柛灞剧矊娴狀垶姊洪幓鎺旂缂佸爼浜跺畷?| 闂備緡鍙忕徊鑲╃博閹绢喖缁╂い鏍ㄧ〒濮婇箖鏌?`PLAYER_BIG_COVER_ID` 闂佸湱顭堥崐椋庣箔?闂?闁诲海顢婂Λ鍕偓?缂備焦妫忛崹鎶藉磻閿濆鐓ｉ柛娆嶅劤缁愭姊洪鐔蜂壕闂?|
   * | `coverSquare` | 闁诲繐绻嬬欢姘焽閹殿喒鍋撻柅娑氱煓闁绘繍鍠栭?闂?1vp | 闁诲繐绻嬬欢姘焽閹殿喗鍋栨い鎰╁灩缁旈箖鏌熼崗鍝ョ瓘缂佽鲸鐛媍onstraintSize` / `layoutWeight` 闂佸綊顤傚鈧紒顭掔磿缁艾煤椤忓拑绱甸梺鎸庣☉椤︻偊宕?缂傚倷绶￠崣鍐夐敐鍥︾剨濞撴埃鍋撴繛闂村嵆閹峰啴骞嬮幒鏃傂㈡繛鏉戝悑娣囨椽鎮?|
   * | `metaGapOk` | 濠殿喗绻傞懟顖炲箖閺囩喆浜滈柟顖涘閻?闂?闁诲繐绻嬬欢姘焽閻楀牊鍎熼柡鍥风磿閻?闂?1vp闂佹寧绋戦悧鍛箔婢舵劖鐓傜€广儱鎳庣紞宀勬煥?| **濠殿喗绻傞懟顖炲箖閺囥垹鍌ㄩ悗锝庝簼闊剙顭块崼鍡楀暟濞堥亶姊婚崼顐ｇ窔缂?* 闂?闂佹椿娼块崝宥夊春濞戙垹绠柕澹嫮鏆?闂備焦瀵ч悷銈囩礊?闂佹眹鍔岀€氼亞绮╃€靛摜鐭?|
   * | `metaOrder` | 濠殿喗绻傞張顒佹櫠濠婂嫨浜滈柟顖涘閻?闂?濠殿喗绻傞懟顖炲箖閺囩喆浜滈柟顖涘閻濆爼鏌ㄥ☉妯煎闁烩剝娲熼獮宥団偓锝庝簼闊剚鎱ㄥ┑鍡氬闁?*婵炴垶鎸搁澶婎焽?*闂?| 婵炴垶鎸堕崐娑€侀幋鐐簻闁告繂瀚喊宥夋煕濞嗗繒小缂?|
   * | `metaInWin` | 濠殿喗绻傞懟顖炲箖?濠殿喗绻傞張顒佹櫠濠婂嫭鍎熼柡鍥风磿閻?闂?缂備焦鍔栭〃鍛般亹濞戞瑯娈?| 濠殿喗绻傞懟顖炲箖閺囩姵鍋栨い鎰剁到閻ㄣ劑鏌涢幋婵囨儓闁活偄妫濋悰顕€寮撮鍡欘槱闂佸憡锚濡銇愰懜鐢碘枖?闂佺顑呯换瀣礊?164vp"闂備緡鍙忕徊濂告煂?bug 闂佹眹鍔岀€氼剟鎳滄导瀛樺亹閻犱礁婀辩粈?|
   * | `miniClear` | 闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱顦埀顒€锕ュ?闂?濠殿喗绻傞張顒佹櫠濠婂嫭鍎熼柡鍥风磿閻濆爼鏌?*闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱瀚悷婵嗏槈閹惧啿顒㈤柣鈩冩礋瀹曘儱顓兼径濠冾仧闂?*闂?| 闂?闁哄鏅滈悷锕傤敆濠婂牆鍙婃い鏍ㄧ矋閺嗗繘鏌熼幘顔芥暠濠殿喓鍊濋幆鍐礋閳规儳浜鹃悘鐐靛亾鐏忥繝鏌￠埀顒勫礈瑜庡▍鏇㈡⒒閸稑鐏查柡浣革攻閹峰懎顓奸崘锝呬壕鐎广儱绻掔粈鍕箹?7 闂?`MINI_LYRIC_SINK_VP=44` 婵烇絽娴傞崰姘枔閹达附鏅?|
   * | `branchSane` | 闂佸憡鑹炬總鏃傜博鐎甸晲娌?*闂佸憡鐟禍婵嗭耿娴ｅ湱鈻旈柍褜鍓熷?*闂佹寧绋戝濉絪ePanel` 婵?`phoneSwiper` 婵炴垶鎸哥粔鎾箖閹捐绫嶉柤鎼佹涧鎯熼梺鍛婅壘婵傛梻绮╅幘顔奸敜婵°倐鍋撻柛鐐差嚟閳ь剛顢婇～澶嬫櫠椤撶喓顩锋俊顖濆亹閼歌泛鈽夐幘鍗炩偓妤咃綖閹烘梻纾奸柟鎯ь嚟閳ь剦鍨堕弫?| 闂佸憡甯囬崐鏍х暤娓氣偓閺屽苯顓奸崨顓犵Ь闂佸憡鐗犵紓姘讹綖閿曞倻鍙掗柍杞扮閻?闂?闂佺绻愰悧鍛村箞閵娾晛绀嗛柕鍫濇缁侊箓鏌涢幇顒傂ラ柣銊ｅ劤閺侇噣宕橀妸褎鎷?|
   *
   * ## 闁诲海鎳撻崯鈺冨垝閻樿浼犳い蹇撳婵粙鎮跺鐓庝函闁汇劎鍠栭弫宥夊醇濮橆収娼?闁哄鏅滈悷銈囩博閺夋垟鏋旈柛顭戝亝閹烽亶妫呴澶婁簼婵℃彃鎲＄粙澶愵敂閸曨厽婢栧┑鐐存綑椤戝洨鍒掗妸褎濯奸柣姘嚟缁€?
   *
   * 闂佸疇娉曟刊瀵哥箔?**婵炴垶鎸哥粔鐑藉礂濮椻偓閹嫮鈧稒锚婢跺秹鏌涢幇顓犳噧婵犫偓?`@Builder` 婵炶揪绲鹃幑鍥闯?* 闂佺偨鍎查弻锟犲焵?闂佸搫鐗滈崜婵嬫偪閸℃瑢鍋撻崷顓炰沪缂佷礁顕槐鎾诲冀椤掑倹袧闂佺缈伴崕鐢稿极婵犲洦鏅?
   *   `'this.logBranchSurface('wide')' does not meet UI component syntax`
   *   闂佹寧绋戝﹢寮恔TS 闂?`@Builder` 婵炶揪绲鹃幐姝屻亹瑜旈獮鎺楀Ψ閵夈儳绉?**UI 缂傚倷绀佺€氼亜鈻庨姀銏″珰妞ゆ挾鍠撻妴?*闂佹寧绋戦ˇ顓㈠焵?
   * 闂?闂佺粯绮嶅妯猴耿椤忓牆绠伴柛灞剧闊?*婵炴垶鎸搁ˇ鏉款焽椤栫偛绀嗛柛鈩兩戦弳婊堟煕濮橆剙顏柛銈嗙矒閹啴宕熼鍌氼棏闁诲骸婀遍幊鎾斥枍?*闂?`.onAppear()` 婵?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鑲╃博閹绢喖缁?*婵☆偓绲鹃悧妤咁敃婵傜绠伴柛灞剧箖缁?*闂佸搫鍟崕鑹邦杺闂佸憡鐟﹂崹宕囩博閺夋垟鏋庨柍钘夋噽缁€?
   *   闂佸綊娼ч鍡椻攦閳ь剟鏌嶉锝嗙叆妞ゆ梹姊绘禒锕佺疀婵犲倹娅栭梻鍌氱墑閸ㄥ搫顭垮Ο鑽ゎ洸闁圭儤姊圭粊鏌ユ煕閹烘垶澶勭€规洘鐓″顔炬崉閻戞ê鈧鏌℃径鍫濆姍缂佹梹娼欓埢搴ㄥ煡閸涱垳顦╅悷婊嗗焽閸ㄧ銇愭径鎰珘闁绘柨鍚嬮敍鐔封槈閹惧磭小缂佽鲸澹嗛幉鎾晝閳ь剝銇愰崒鐐存櫖濠㈣泛鐗冮崑?
   *   闂佺儵鏅╅崰鏍ㄦ櫠閻樿绠伴柛灞剧懅閸熷﹤鈽夐幘鎰佹Ц妞わ腹鏅犻弫宥咁潩椤掑鏅柣蹇曞仜缁绘﹢宕戦崨鏉戠哗妞ゆ牗绮嶉悾?`Column`闂侀潧妫旈悞锔芥櫠濠婂牆瀚夋繛宸簻娴滄繈鏌￠埀顒勵敍濠婂嫮鏆?`Swiper`闂侀潧妫旂欢姘焽娴兼潙绾ч柛褎顨呮禍婵嬫煛閳ь剟顢涘鍕殸闂?`Stack`闂?
   *   `branch` 闂佸憡鐟ラ崐褰掑汲閻斿吋鍋?*闂佸憡鑹剧€氼垶鎯冮悢鍏煎仺闁靛ě鍐у寲闂佺厧顨庢禍婊呮崲娴ｅ湱鐝堕柣妤€鐗婇～?*闂佹寧绋戦悧鍡涙偩閻樼鍋撳☉娆樻疁婵炶偐澧楃粙澶嬬節閸屾稓娈ら梺娲诲幑閸庡灚绂嶆ィ鍐╁殜妞ゅ繐瀚粻鎺楁煛閸曢潧鐏ラ柣銊︾箞閺佸秵寰勯崼姘壕?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箓鐠佹彃霉閻橆喖鍔ゆ繛鎻掓健楠炴帡濡烽妷銉︽闂?`@Builder` 闂?
   *
   * 闂佹寧绋戦悧濠囶敆濠靛绾ч柍銉ュ暱閸ゆ帒霉閿濆棛鐭婄紒?闂佺偨鍎查弻锟犲焵?闁荤喐鐟ゅ鎺旂箔閸岀偛违濞ｅ洦顭笲uilder` 婵炶揪绲鹃幐姝屻亹瑜旈獮鎺楀Ψ閵夈儳绉?UI 缂傚倷绀佺€氼亜鈻庨姀銏″珰妞ゆ挾鍠撻妴濠囨煥濞戞ɑ婀板褍绉电粋鎺楀Ψ閿曗偓閻︻垶鏌?`.onAppear()`闂侀潧妫楅崑濠勬?
   *
   * 闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdBranch'`
   * 闂佸疇娉曟刊瀵哥箔?闂佸憡鐟禍锝夘敋娴煎瓨鏅慨姗嗗亞閻熸繈鏌涢幇顓犳噥闁瑰箍鍨洪幏鍛村即閻樻畫锕傛煙椤戣法绛忕紒杈ㄧ崑lastBranchLog` 闂佸憡鐟禍婵單ｉ幖浣哥睄闁靛鍎崇粻鍫曟煠閸濆嫬鈧湱绮婇敃鍌涘仺闁靛ě鍕殸闁诲孩绋掗〃鍫ヮ敄娴ｅ湱鈻旈悹鍥囧懐顦梺?
   * @param branch 閻熸粎澧楅幐鍛婃櫠閻樿绀嗛柛鈩兩戦弳婊堟煕濮橆剛鈻岀紒?phone' / 'wide' / 'panel'闂?
   */
  private logBranchSurface(branch: string): void {
    const rectOf = (id: string): LyricMorphRect | undefined => {
      try {
        const node = this.getUIContext().getFrameNodeById(id);
        if (node === null) {
          return undefined;
        }
        const p: Position = node.getPositionToWindowWithTransform();
        const s: Size = node.getMeasuredSize();
        return {
          x: areaLengthToVp(p.x),
          y: areaLengthToVp(p.y),
          size: this.getUIContext().px2vp(s.width),
          height: this.getUIContext().px2vp(s.height),
          radius: 0
        };
      } catch (err) {
        return undefined;
      }
    };
    const fmt = (r: LyricMorphRect | undefined): string => r === undefined
      ? 'none'
      : `(${r.x.toFixed(0)},${r.y.toFixed(0)},${r.size.toFixed(0)},${r.height.toFixed(0)})`;
    const cover: LyricMorphRect | undefined = rectOf(PLAYER_BIG_COVER_ID);
    const title: LyricMorphRect | undefined = rectOf(PLAYER_META_TITLE_ID);
    const singer: LyricMorphRect | undefined = rectOf(PLAYER_META_SINGER_ID);
    const lyric: LyricMorphRect | undefined = rectOf(PlaybackPage.MINI_LYRIC_BOX_ID);
    // 闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑?婵炴垶鎸哥粔纾嬨亹婢舵劖鐓傞煫鍥ㄨ壘濞堢増淇婇鐔蜂壕闂佹寧绋戦悧鍡涘矗韫囨稒鐒鹃柕濠忛檮绗?婵炴垶鎸哥粔鐢稿垂濮樿京鍗氶悗锝庡亜椤ゅ懘鎮归崶鈺婃闁?闂佹眹鍔岀€氼剟鎳滈弶娆惧殨闊洢鍎崇粈澶愭⒑椤掆偓閻忔繈宕㈤妶澶婄睄闁靛鍎崇粻鍫曟⒑閹绘帒顨欑紒鏃€鎸冲畷?true闂?闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑鎾绘煃閸忓浜鹃梺鍐插帨閸嬫捇鏌嶉崗澶婁壕闂佸啿鍘滈崑?
    const bad: string[] = [];
    if (cover === undefined) {
      bad.push('coverNone');
    } else if (Math.abs(cover.size - cover.height) > 1) {
      bad.push(`coverSquare(${cover.size.toFixed(0)}x${cover.height.toFixed(0)})`);
    }
    if (cover !== undefined && title !== undefined && title.y < cover.y + cover.height - 1) {
      bad.push(`metaGapOk(title.y=${title.y.toFixed(0)}<cover.b=${(cover.y + cover.height).toFixed(0)})`);
    }
    if (title !== undefined && singer !== undefined && singer.y < title.y) {
      bad.push('metaOrder(singer above title)');
    }
    const winH: number = this.expandState.windowHeightVp;
    if (winH > 0 && singer !== undefined && singer.y + singer.height > winH) {
      bad.push(`metaInWin(singer.b=${(singer.y + singer.height).toFixed(0)}>${winH.toFixed(0)})`);
    }
    // 闂?闁哄鏅滈悷锕€顭囬婊€鐒婇弶鍫涘妽绗戦梺娲绘娇閸斿秹宕哄☉銏犵闁靛／鍕殸闂侀潧妫楅張顒勫箰闁秴缁╅柛鎾楀嫭鐝梻鍌氱墑閸ㄤ粙寮繝鍐╁鐎广儱鍟犻崑鎾愁吋閸ャ劎鏆犻梺鍝勭墕閹碱偄鈻嶉幒妤€绀嗛柕鍫濇缁侊箓鏌ㄥ☉妯煎彃?7 闂?MINI_LYRIC_SINK_VP 婵烇絽娴傞崰姘枔閹达附鐒介柨婵嗘閽傚鏌ㄥ☉姗嗘Ф闁?
    if (lyric !== undefined && singer !== undefined && lyric.y < singer.y + singer.height - 1) {
      bad.push(`miniClear(lyric.y=${lyric.y.toFixed(0)}<singer.b=${(singer.y + singer.height).toFixed(0)})`);
    }
    // 闂佸憡甯囬崐鏍х暤娓氣偓閺屽苯顓奸崨顓犵Ь闂佸憡鐗滅亸銊ф閻ф椄 + 濠碘槅鍨兼禍婊堟儓閸℃稑绫?usePanelLayout() 婵?usesPhoneSwiperLayout() 闂佸憡鐟崹鐢稿礂濮椻偓瀹曘儳浠﹂悙顒夋Н婵炴垶鎹佸▍锝咃耿閿熺姴违?
    // 闂佺粯绮嶅妯猴耿椤忓牊顥?`if` 婵＄偑鍊曢幖顐よ姳椤撱垹绀傛繝濞惧亾缂傚秴娲弫宥夊醇閵夛附銆冮梺鍝勵槼閸庡宕曢妸鈺佺闁绘艾顕粈鍡涙煃?闂佸憡鐟禍锝夈€?闂傚倸鐗勯崹鍝勵熆濮椻偓瀵劑顢涢悙鍙夘仦闁哄鏅滈…鍫ヮ敇缂佹鈻斿Δ锕€鐏濆▓鎵偓瑙勭摃妞寸危?phoneSwiper"闂佹寧绋戦懟顖氼潩閵娾晛鍙婃い鏍仦椤撴椽鏌熼鍡欑シ闁?
    const panel: boolean = this.usePanelLayout();
    const phoneSwiper: boolean = this.usesPhoneSwiperLayout();
    if (panel && phoneSwiper && branch !== 'phone') {
      bad.push('branchSane(panel闂佹剚鍙忕粻鐬檕neSwiper both true)');
    }
    const sig: string = `${branch}|${this.expandState.windowWidthVp.toFixed(0)}x` +
      `${this.expandState.windowHeightVp.toFixed(0)}|${fmt(cover)}|${fmt(title)}|${fmt(singer)}|${fmt(lyric)}`;
    if (sig === this.lastBranchLog) {
      return;
    }
    this.lastBranchLog = sig;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdBranch branch=${branch} win=${this.expandState.windowWidthVp.toFixed(0)}x` +
      `${this.expandState.windowHeightVp.toFixed(0)} bp=(${this.breakpointEnv.widthBreakpoint},` +
      `${this.breakpointEnv.heightBreakpoint}) panelLayout=${this.panelLayout} ` +
      `usePanel=${panel} phoneSwiper=${phoneSwiper} ` +
      `cover=${fmt(cover)} title=${fmt(title)} singer=${fmt(singer)} lyric=${fmt(lyric)} ` +
      `pad=${this.expandState.topInsetVp().toFixed(1)}/${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      // 闂佸疇娉曟刊瀵哥箔?缂備礁鐬奸崕銈夊汲閻旇櫣纾奸柛鏇ㄥ櫘濞诧綁鏌熼崹顐ｅ鞍闁?`ok`闂佹寧绋戞總鏃傜箔婢舵劖鍤勯柤鎭掑劚閳數绱掑畝鍐┿€冮悷?闂佺偨鍎查弻锟犲焵?闂佸憡鐔粻鎴﹀垂?闂佸搫鍟ㄩ崕杈╂崲閺冨牊鐓傜€光偓閸曨偂绨兼繛鎴炴尨閸嬫挻绻涢崼婵堜粵闁汇儱鎳忕粋?闂?濠电偛鐪查妶鍛唶濠碘槅鍋€閸?闂佸憡甯掑Λ鏃傜箔婢跺鈧帡宕ㄩ鐔蜂壕?
      `inv=${bad.length === 0 ? 'ok' : bad.join(';')}`);
  }

  /** True for small-width + medium-height window (phone landscape-ish). */
  private isSmHeightMdLayout(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD;
  }

  /** True when the wide split panel layout should be used (param or wide window). */
  private usePanelLayout(): boolean {
    const size = this.windowInfo.windowSize;
    const landscape: boolean = size.width > size.height && size.height > 0;
    return this.panelLayout || (landscape &&
      this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_SM);
  }

  /**
   * @returns 闂佸搫瀚烽崹浼村箚娴ｇ儤灏庨柤鍓插厴閸嬫挾浠﹂幆褜鏉归梺?Swiper闂侀潧妫楃粔褰掑磻閸涱喚鈻旈柍褜鍓熷銊╊敍濮橀硸浼岄柣蹇曞亹閸嬫捇鏌ㄥ☉妯煎闁汇劍绻堝Λ鍐閵堝啠鍋?/ 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻?*濠碘槅鍨兼禍婊堝箖濠婂牆绀嗛柛銉ｅ妼鎼?*闂佹眹鍔岀€氫即宕戦崨顔鹃檮婵°倕顑囩粈鍡涙煏?
   *
   * 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涱敄閸ャ劎鈻曟繝闈涳功閺嬪倻鎹?*闂佽　鍋撻悷娆忓閸斺偓婵炴垶鎸撮崑鎾愁熆?濠电偛顦崝鎴﹀闯鐎涙鈻旈幖杈剧磿閺変粙鏌ｅ鍫殥缂佹顦辩划?**闂佹寧绋戦¨鈧紒?
   *   闂佸憡顭囬崰鎰板极閻愮儤鐓傚┑鐘插€搁弲鎼佹煟閵娿儱顏俊鍙夋倐婵″浠﹂挊澶屼紙闂佺顕栭崰鏇犵箔?`buildControlStack()` 闂備焦褰冮惌鍌炲磻閸涱喚鈻?`if` 闂佹眹鍔岀€氼剝銇愰崶顒€鐭?*闂備緡鍋呴崝鏇㈡偤瑜庣粙澶愬焵椤掑嫭鍤?*闂?
   *   `SM`闂佹寧绋戦悧鍛箔婢跺本濯兼繛宸簽瑜邦垶鏌ㄥ☉姗嗘Ч闁?**`MD + HEIGHT_SM`**闂侀潧妫楃粔顕€鍩€椤掍焦鐓涢柍?
   *   闂佸疇娉曟刊瀵哥箔?**闁诲骸婀遍崑鐔肩嵁閸ヮ剚鐓傞悘鐐电摂閸?MD 濡ょ姷鍋犻崺鏍儉閸涙潙瀚夊鑸靛姉瑜邦垶骞栨潏楣冩婵炵⒈鍨辩粋?*闂佹寧绋戦悧鍡楊潩閵娾晛鍙?`widthBp === WIDTH_MD` 闂佸搫鐗滈崜婵嬫閳哄懏鏅璺虹墐閸嬫捇宕掑▎鎺嗘嫛闂佸憡鐟ｉ崕鎵箔婢跺鈻旈柍褜鍓熼幊娑欐綇閸撗咁槷
   *   闂佸吋婢樻總鏃傜箔?*婵炴垶鎸哥粔宕囩博閹绢喗鍤婇悗闈涙啞閻ｉ亶姊洪銊у闂佸弶绮撳顒勬偡閻楀牆鈧鏌?闁诲骸婀遍崑鐔肩嵁閸ヮ剙鍗抽柡澶嬪焾閸?**闂佹寧绋戝﹢顤?+ 婵炲濮风划顖炲礈閻楀牜娈楁俊顖氭惈椤斿﹪姊洪灏栧亾閻旇櫣顔夐梺?true闂佹寧绋戦ˇ顓㈠焵?
   *
   *   闂佺粯绮嶅妯猴耿椤忓牊鍎嶉柛鏇ㄥ亞閺変粙姊婚崟顐ｅ殌妞ゆ洏鍨虹粙濠冨緞濞戞氨顦╅梺缁樻寙閸愵亝婢栭梺缁樼矋濠㈡﹢宕幘缁樻櫖?*闂佸搫鐗滄禍婵嬪极閼测晜鍋橀悘鐐跺缁€?*闂佹寧绋戦¨鈧紒?
   * ```
   *   widthBp === SM                      闂?true
   *   widthBp === MD                      闂?true      闂?闂佸疇娉曟刊瀵哥箔?婵炴垶鎸哥粔鎾箚閸噥娈楁俊顖氭惈椤斿﹪鏌涢幒瀣偓鏍蓟?
   *   闂佺绻戝﹢鍦礊閹达附鏅柛锔惧殞 / XL闂?                     闂?false
   * ```
   *   闂?闁诲海鎳撻崯顖炴儊?`buildControlStack()` 闂備緡鍙忕徊鎯ь焽?`if` 闂佹眹鍔岀€氼剝銇愰崶顒€鐭?*婵犮垼鍩栭懝楣冨箠閳╁啰鈻?MD + 闂?HEIGHT_SM"**闁哄鏅滈悷銈囩博閺夋埈娴栭柨婵嗗暊閸?
   *
   * ## 闂?婵?`usePanelLayout()` 闂?*闂備焦褰冪粔纾嬨亹閺冨牆绀?*闂佹寧绋戦悧鍡涘礄閿熺姵鍎岄柡鍕禋閸炲爼鏌ㄥ☉妯垮闁糕晛妫濆畷鐑藉Ω閵娧咁啇闂備焦褰冮懟顖涘閺冨牆纾婚梺鍨儐閺嗩參鏌?
   *
   * ```
   *   usePanelLayout() 闂?(濠碘槅鍨兼禍婊堟儓?&& widthBp !== SM) 闂佸搫鍟﹢鍦嫻閻斿吋鍎?
   *   闂?闂備焦褰冪粔纾嬨亹?= 闂侀潧妫欓崝鏍惎闁诲繒鍋涚换鍫ュ焵椤掍礁鐏熼柍褜鍓氭导鍒琩thBp === MD闂?
   * ```
   * 婵犻潧鍊藉Λ鍕囬埡鍛強?`buildControlStack()` 闂?`if (usePanelLayout())` **闂侀潻璐熼崝灞炬櫠?* 闂?闂傚倸鐗勯崹鍝勵熆濮椻偓瀵劑顢涘┑鍡楀闂佸憡鍨舵禍浠嬪焵?
   * 闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本绻嶅鍫曟煛閸偄澧柛銈変憾瀵偊鎮ч崼婵堟闂?闂?**婵炴垶鎸哥粔宕囨娴煎瓨鍋ㄩ悹浣哥枃閳峰牆霉閻樼儤顥夐柣銊︾箞濡?*闂?
   * 闂佺鍐妞わ腹鏅犲浼搭敍濠靛牏顔愰柣蹇曞仧閸嬫鑺?**闂?if 婵＄偑鍊曢幖顐よ姳椤撱垹绀傛繝濞惧亾缂?*"闂佹寧绋戞總鏃傜箔婢舵劕鍙?闂佸憡甯囬崐鏍х暤娴ｅ湱顩查柟鐑樻尰閻?闂?
   * 闂佸疇娉曟刊瀵哥箔?**闂佸搫鐗滈崜娆撳吹闁秴鏋侀柟宄扮灱缁犻绱掗悪鍛？婵?`isPhoneLyricsStyleBackdropLayout()`闂佹寧绋戦悧鎰板磿濡ゅ懎鐤炬い鏍ㄧ〒婢瑰鈧鍠栫换姗€骞楁總鍛婃櫖?* 闂?
   *   闂佺娉涢敃銈夋偩閻樿缁╅柛鎾茶兌瀹曟洟鏌?`&& !usePanelLayout()` 闂?*闂佸憡鐟崹鐢革綖閸℃瑦鍋橀悘鐐跺缁€瀣煕濞嗘兎顏嗏偓?*闂佹寧绋戦悧濠囨惎闁诲繒鍋涚换妤呭磿濡ゅ懎鐤炬い鏍ㄧ〒婢瑰鈧鍠栫换瀣娴兼潙鐭楁慨妤€鐗忕粈鍡涙煥?
   *   闂佸吋婢橀張顒勬惎闁诲繒鍋涚换鎰版嚋娴兼潙绠戝ù锝堫潐閹烽亶鏌￠崼鐔搞仢闁绘稒鐟︾粙澶婎吋閸曨厼鏅?闂?**闂佺绻愰悧鍡涘窗閸涙潙绾ч柍銉ュ级椤?*闂佹寧绋掗悺鐚倆dBranch` 闂侀潻璐熼崝搴★耿閿熺姴瀚夐弶鐐村閻熸劙姊洪幓鎺旂闁搞値鍙冮弻灞筋吋閸涱厾绉鹃梺鍛婄墳濞咃絽鈻撻幋鐘亾閸︻厼浠辨俊缁㈠灦瀹曟岸宕卞Ο缁樻
   *   闂佹寧绋戝濉╮anchSane` 闂佸搫鍋嗛崣鈧柍璇茬墦閺佸秵寰勬径宀婂悈闂佸憡鑹鹃崙鐣屾濠靛绀冪€广儱鎳庨弸鈧柣搴ゎ潐绾板秹寮憴鍕枖鐎广儱妫欓弳顏嗙磼閹邦剙顏ラ柍褜鍓欓崐璇测枍閵壯勫闁哄顑欏Σ閬嶆煥?
   *   `_recover/logic-src/闂佺儵鏅╅崰妤呮偉閿濆鐓?闁诲海顢婂Λ鍕儓閸℃稒顥堥柕蹇婂墲缁惰尙绱撴担鍝勬瀺缂?闂佸搫鍊藉Λ鍕閹版澘鐐婇柛娆嶅劤閻熴垹螖閻樺弶婀伴柡?md` 闁?闂侀潧妫楅懟顖炲垂娴犲绠叉い鏇楀亾闁革絾鎮傚畷锝夋偐椤旂懓浜剧€广儱鍟犻崑?
   */
  private usesPhoneSwiperLayout(): boolean {
    if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
      return true;
    }
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD;
  }

  /**
   * True for the narrow-phone Swiper layout (not fold inner dual-pane, not lg/xl grid).
   * Album and lyrics pages share the same blurred backdrop + imageColor so the tint matches.
   */
  private isPhoneLyricsStyleBackdropLayout(): boolean {
    if (isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint)) {
      return false;
    }
    if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD) {
      return false;
    }
    return true;
  }

  // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涱敄閸ャ劎鈻斿璺猴工绾锯晛鈽夐弮鈧换鍡涙偪?/ Round 20闂佹寧绋戦¨鈧紒杈╂珬@Builder phoneSwiperBackdropImage()` **閻庣懓鎲¤ぐ鍐垂瑜版帗鈷?* 闂佺偨鍎查弻锟犲焵?
  //   闁诲海鎳撻崯鎶藉吹濠婂喚鍟呴弶鍫氭櫆閻?JSDoc 闁诲繐绻愬畷顒勫疮閹捐鍙?`grep -n "phoneSwiperBackdropImage"` 闂佸憡鐟禍婵嗭耿娴ｈ　鍋撶憴鍕叝缂佺姷鍠愬鍕礋椤斿墽顔愭繛鎴炴尨閸嬫挸鈽夐幙鍐х盎闁规枼鍓濈粙?闂?闂佸搫鐗滈崜姘焽閻㈠吀鐒婇弶鍫涘妽绗戝┑顔界箚椤斿﹪宕鍕剺?闂?
  //   闂佸憡甯炴繛鈧繛鍛叄瀹?`backgroundImageSource()` 婵炴垶姊婚崰鏍р枔閵忥紕鈻曢悗锝庡枟缁佲晠鎮圭€ｎ亜鏆熼柡浣靛€濋幊鎾诲椽閸愵亞顦╂繛鎴炴尪閸婃盯鍩€椤掆偓閹冲秶绮╃€靛憡灏庨柧姘€婚悷鎾剁磼閹冪殹缂佽鲸宀告俊?
  //   闂佸憡甯炴繛鈧繛鍛缁楃喎鈹戦崶褏銈︽繛鎴炴尭缁ㄥ吋顨ラ崶顒佸亱闁冲搫鍠氶崕濠囨煕濞嗘垶鐒块柛銈嗙矊铻為柍褜鍓熼弫宥夊锤椤ｆ槴ules.abc GONE闂佹寧绋戦ˇ鎶斤綖?RzdMusic闁荤姳鐒﹀妯兼崲?md 闁?6.15闂?

  /** Main Stack: background art, breakpoint-specific controls and lyrics grid. */
  @Builder
  buildControlStack() {
    Stack() {
      if (this.usePanelLayout()) {
        this.panelControlContent()
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          if (!(this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM ||
            (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
              this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_SM))) {
            // 濡ょ姷鍋犲▍鏇烆熆?濠碘剝顨呴惌鍌氼焽娴煎瓨鏅繛鍡欘仧idRow 閻庡綊娼荤粻鎴ｃ亹閹间礁绀嗛柛鈩冾焽閸╁鏌ㄥ☉妯煎闁汇劍绻堝Λ?| 濠殿喗绻傞惌渚€鎯佸┑瀣櫖濠㈣埖绋撶粈澶婎渻閵堝懐鍩ｉ柛?padding 闁荤姳璁查弲娆戠礊閸涱垳纾兼繛鍡樺灩閸╃姴鈽夐幘顖氫壕 TopArea
            Column() {
              GridRow({
                columns: { md: BreakpointConstants.COLUMN_MD, lg: BreakpointConstants.COLUMN_LG, xl: BreakpointConstants.COLUMN_LG },
                gutter: 48
              }) {
                GridCol({
                  span: { md: 4, lg: 5, xl: 4 }
                }) {
                  MusicPlayInfoBlock({
                    state: this.state,
                    metaBlockTranslateYvp: 0,
                    isDismissing: this.isCollapsing(),
                    coverLinearScale: 1,
                    // 2026-10-17锛歚showControlArea` 榛樿 true 涓斿叏浠撲粠鏈紶杩?false 鈬?灏侀潰椤甸噷浼?*鍐嶇敾涓€浠?*
                    // 鎺у埗鍖猴紙Slider + 5 棰椾紶杈撻敭 + 4 棰楀浘鏍囪锛夛紝涓庡簳閮ㄥ叡浜偅涓€浠介噸鍙犮€傜敤鎴锋姤鐨?绗簩涓帶鍒跺尯"灏辨槸瀹冦€?
                    showControlArea: false
                  })
                }
                .margin({
                  bottom: 20
                })
                .padding({
                  left: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 48 : 0,
                  right: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 48 : 0
                })

                GridCol({
                  span: { md: 4, lg: BreakpointConstants.COLUMN_LYRIC_LG, xl: 8 }
                }) {
                  LyricsComponent({
                    isShowControl: this.isShowControlLg,
                    isTablet: this.isTabletFalse,
                    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?/ 闂佺儵鏅╅崰妤呮偉?闂佸疇顔愮徊濠氬焵椤掆偓閼活垶顢欓弮鍌欐勃鐎电増绋撻崗妯侯焽娴兼潙绾у鑸电摃閳峰牓鏌涢幒鎴烆棡闁轰緡鍠氱槐鎺楁偄閸撲緡浼囬梺闈涙缁嬪嫮妲愬鑸垫櫖?
                    //   闂佸搫鍟版慨鐑藉疾?*濠电偛澶囬崜婵嗭耿?* `LyricsComponent` 闂佸憡鍔曢幊搴ｇ磽?濠殿喗绻傞懟顖炲箖?- 濠殿喗绻傞張顒佹櫠?闁荤偞绋忛崝宀勫Φ閺冣偓濞艰鈻庤箛鏃傤槬婵?
                    //   闂佹寧绋戝濉ecover/logic-src/濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁割煈鍋夐惂渚€鎮橀悙鎻掆偓鎼佹儍濠靛顥堟い顐幘閻熴垺鎱ㄥ┑鍡氬闁诡喗娲滈埀顒冾潐濮樸劑鈥?md` L1449 闂佸憡顭囬崰鎰板几閸愵喗鏅?
                    //   闂侀潧妫楅張顒€螞閵堝鍋╅悘鐐插⒔濮婇箖鏌?`LyricsComponent` 闂佸憡鍔曢幊搴ｇ磽?header 闁哄鏅滈悷銉ッ洪弽銊ь洸閻庯絻鍔夐崑鎾愁吋韫囨洜顦梺?
                    //   闂佸疇娉曟刊瀵哥箔?闂佸綊娼ч鍡椻攦閳ь剟姊洪銊у缂佹梹鎸冲銊╊敍閵堝洨顦╂繛鎴炴尭椤戝顭?L2002 闂備緡鍙忕徊浠嬎囬埡鍛櫖濠㈣泛鐭堥崕?1 闂佺鍕垫當闁告埊绱曠槐鎺曠疀鎼达絿鍊炴繛?`true`闂?
                    //      闂?*闁诲海顢婂Λ鍕儓?闂傚倸鐗勯崹鍝勵熆濡粯浜ゆ繛鍡楁唉閳峰牆顭跨捄鍝勵仼缂傚秴顑夊顕€鎳滈悽鐢殿攨婵?* 闂佺偨鍎查弻锟犲焵?闂佸憡鐟ラ悧濠偽?
                    //      闁?6.1.6 / 闁?6.16 / 闁?6.17 闂備緡鍙忕徊濂告煂濠婂牆违閻忕偠濮ら崐鍗炩槈閹绢垰浜鹃悷婊嗗焽閸ㄧ粯鎱ㄩ幖浣稿珘?N 婵犮垼娉涚€氥劑鍩€椤戣法顦︾憸鎶婂洤缁╅梺顐ｇ〒閸熷﹤鈽夐幘顖氫壕婵犮垼娉涚€氥劑鍩€椤掆偓缁夎泛鈻撻幋锔藉殌濞达絽婀卞Ο鍛存煟閵夈儲鍣烽柍?
                    //   闂佸憡鍔栭妵鐐电礊閹达箑鍙婃い鏍ㄦ皑閺変粙鏌熼崹顐ｅ碍闁汇倕瀚伴幆鍐礋閸撲胶鐛ラ梺鍝勭墱閸撴瑩宕规惔銊ョ哗妞ゆ牗鐟ч悷鎰版⒒閸稑鐏╂慨妯稿姂瀵?`MusicPlayInfoBlock`闂佹寧绋戝﹢?908闂佹寧绋戦ˇ顖氾耿椤忓牆鍙婇柛鎾椾椒绮?
                    //   闁诲繐绻嬬欢姘焽?+ 濠殿喗绻傞懟顖炲箖?+ 濠殿喗绻傞張顒佹櫠?闂?濠殿喗绻傞惌渚€鎯佸┑瀣鐎广儱鐗嗗▓浼存煙闊彃鍔欑紒鏃€娼欓埢搴ㄥ灳閾忣偆娈ら梺?闂佸憡鑹炬總鏃傜博鐎涙﹫绱旈柡宥冨妿閹藉啴鏌涘顒傂㈤柛銈庡弮閹櫕锛愭担瑙ｆ嫛濠?闂?
                    //   闂?闂佽姤锚缁绘垹鏁埀顒勬倵?*婵炴垶鎸哥粔鍐测槈椤忓懐顩烽悹浣哥－缁夊灝菐閸ワ絽澧插ù?*闂佹寧绋戞總鏃傜箔閺嶃劎鈻旈幖娣灪閿熴儵鏌ｉ敐鍛伇婵炲牊鍨归幉鎾磼濞戞ê韦婵炴垶鎸撮崑鎾绘煠闁垮鏆橀柍?
                    hideLyricsMetaHeader: true,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .margin({
                  bottom: 20
                })
              }
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)
              .clip(true)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding'),
              top: 80
            })
            // 闂佸疇妫勯幊澶娢?闂佺儵鏅╅崰妤呮偉?闂?闂?*闂佸憡甯掑Λ娆撳极椤旇￥浜归柟鐑樺灩濞硷綁鎮归崶褝鏀婚柡?*闂佹寧绋戦悧鎰帮綖?`logBranchSurface()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煏?
            //   闂佸疇娉曟刊瀵哥箔?**闂婎偄娲ら幊姗€濡磋箛娑樼闁稿本纰嶉煬?`.onAppear()` 闂備焦褰冮惌澶屾濠靛洨鈻旂€广儱鐗嗛崢鎾煟閳轰胶鎽犻悽顖涙尦瀹?`@Builder` 婵炶揪绲鹃幐鎼佸船鐎靛憡瀚柛鎰典簼閺?* 闂佺偨鍎查弻锟犲焵?
            //      ArkTS 闂?`@Builder` 婵炶揪绲鹃幐姝屻亹瑜旈獮鎺楀Ψ閵夈儳绉?**UI 缂傚倷绀佺€氼亜鈻庨姀銏″珰妞ゆ挾鍠撻妴?*闂佹寧绋戦惉鐓幟洪崸妤€绠抽柕澶堝劚閺呮悂鏌￠崒婵愭綈缁绢厼澧庨幏顐﹀礃椤忓懏娈㈡繛鏉戝悑濮樸劎妲愰鍡樺珰闁瑰鍋涜闂?
            //      闂佹寧绋戦悧濠傦耿閻楀牊濮滄い鏃囧亹閺夎姤绻涢弶鎴劀缂佽京娅?this.logBranchSurface('wide')' does not meet UI component syntax`闂佹寧绋戦ˇ顓㈠焵?
            //   闂佸疇娉曟刊瀵哥箔?婵?*婵炴垶鎸哥粔鐑藉礂?*闂佸湱顭堥崐绋匡耿?闂備緡鍙忕徊鑲╃博閹绢喖缁╂い鏍ㄧ矋閻ｉ亶鏌″鍥ㄥ殌妞ゆ梹鍔欏畷?婵炴垶鎸搁敃銈咁潩閵婏妇顩烽柕澶堝€涚粈瀣熆閸撲礁鏋嶇紒顭掔節閺佸秴顫濆畷鍥╊啇闂備焦褰冮張顒傗偓鍨礋瀹?`Column` 婵炴垶鎸搁…顓犳?
            //      闁诲海鎳撻崯顐ャ亹瑜斿畷?*闂佸搫鐗滈崜姘跺极椤旀枻绱旈柡宥庣厛閸嬔囨煙缁嬪灝鈧棄霉?*闂佸搫鍟崕鑹邦杺闂?闂?闂佸綊娼ч鍡椻攦閳ь剟鏌嶉锝嗙叆妞ゆ梹姊绘禒锕佺疀婵犲倹娅栭梻鍌氱墑閸ㄥ搫顭垮Ο鑽ゎ洸闁圭儤姊圭粊鏌ユ煕閹烘垶澶勭€规洘鐓″顔炬崉閻戞ê鈧鏌℃径鍫濆姍缂佹梹娼欓埢搴ㄥ煡閸涱垳顦?
            //      閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮悑閿涚喎鈽夐幘宕囆＄紒鍙樺嵆瀹曟艾鐣￠幍顔界秳闂佹寧绋戝濉磑gBranchSurface` 闂佸憡鍔曢幊姗€宕曠€涙ɑ浜ゆ俊顖滅帛缁犳帒鈽夐幘顖氫壕闁诲繒鍋涢崐濠氼敆閻戣棄瑙︾€广儱鐗嗚灐濠电偟绻濈欢銈囨濮樿泛违?
            .onAppear((): void => {
              this.logBranchSurface('wide');
            })
          } else {
            // 闂佸綊娼ч鍡椻攦閳ь剟鏌ㄥ☉娆戞憘wiper 闁诲繐绻嬬欢姘焽?濠殿喗绻傞惌渚€鎯佸┑鍡╃叆闁瑰瓨绻傝 + 闁圭厧鐡ㄥú鐔煎磿閹绢喖绠崇憸宥夊春濡ゅ懎绀?
            Column() {
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佹椿娼块崝宥夊春濞戙垺鍎戦柣鏂挎啞缁ㄦ岸鏌熼幖顓濈盎婵炲瓨顭囬弫顕€鏁冮埀顒勫吹椤撱垺鍎嶉柛鏇ㄥ灡閿涙牕螞閻楀牞鍏紒杈ㄦ緲椤垹鐣濋崘顏呅撴俊鐐€濆褔鎯冨┑瀣棃闁靛骏绱曞楣冩煕濞嗘兎顏堟儍?*闂?
              //
              // ## 闁荤姴娲ㄧ划顖炲汲閻斿吋鏅柛顐犲灪閺嗗繘鏌?2026-10-16 22:42 闂佽鎯屾禍婊兠瑰鈧弫?
              // ```
              //   V d73f1b8 闂?scale=1.000 p=1.000
              //   real=1 clone=0 snap=30/30 end=331/331 op=1.000 stage=2 drv=0
              //   闂?edge=331 t=0.00        闂?闂?闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棗娴烽閬嶆倵閻㈠灚顏熺紒杈╂疄 闂佺顑嗙划灞斤耿?0 闂?闁诲繐绻嬬欢姘焽?= 331闂佹寧绋戦悧濠囧汲閿濆洨鐜绘俊銈呮噹娴滄繂鈽夐幘顖氫壕婵炲濮甸弸鑽ゆ?
              // ```
              //   闁诲繐绻嬬欢姘焽閹殿喕鐒婇柛婵嗗閸?= `lyricMorph(lyricMorphT).size`闂佹寧绋戦惌渚€鍩€?`lyricMorphT` 闂佸憡鐟禍婵嗭耿?0/1 婵炴垶鎸堕崐鎾绘煂濠婂懐鐭欓柛鎰皺閺嗕即鏌涙繝鍕┾偓瀣?
              //     `t=0` 闂?闁诲繐绻嬬欢姘焽?= `endCoverSize`闂佹寧绋戦悧鍐╂櫠?31闂佹寧绋戦懟顖炲Φ閸モ晙鐒婂〒姘ｅ亾婵為棿鍗抽弫宥嗗緞濞戞艾鑰縛t=1` 闂?`lyricCoverSizeOf()`闂佹寧绋戦悧鍐╂櫠?8.7闂佹寧绋戦懟顖炴儍椤掑倷鐒婂〒姘ｅ亾婵為棿鍗抽弫?
              //   闂?闂侀潧妫楅懟顖炴儍濠靛顥堥柕蹇ョ磿濮婇箖鏌涘▎鎯奉亪鎯冮鍕ョ€广儰绀侀埛?**`lyricMorphT` 濠电偛澶囬埀顒€鍟块悡?1**闂?
              //
              // ## `lyricMorphT` 闂佹眹鍔岀€氼剟寮鐣屸枖闁逞屽墴瀹曟ê鈻庤箛鎾虫辈闂佸吋婢橀幊蹇撐?`animateLyricMorph`闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎮鹃悩璇茬煑妞ゅ繐鍟伴惌銈夊级閳哄倻鎳囬柛锝夘棑閹噣顢曢妷褎顔?
              // ```
              //   .onAnimationStart((index, targetIndex) => {
              //     if (index === targetIndex && !this.lyricMorphVisible) { return; }   // 闂?闁诲海鎳撻悧鍡楃暦?
              //     this.animateLyricMorph(targetIndex === SWIPER_INDEX_LYRIC);
              //   })
              // ```
              //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈夋煂濠婂應鍋撻悷鎵鐎规洖銈搁幆鍐礋椤曞懎娈ф繛鎴炴煥椤︽澘危?**閻庤鐡曠亸娆戝垝閿熺姴鎹堕柕濞у嫮鐛ラ梺鍝勭Т濞差參濡存径瀣洸?*闂佹寧绋戝濉眓dex === targetIndex`闂佹寧绋戞總鏃傜箔婢舵劕鍙婃い鏍ㄧ懅椤忚鲸绻涢崱顓犵？婵犫偓閳ユ剚鐓ラ柟瀛樼箓琚熼梺?
              //     闁诲繐绻楃划楣冩倻閿旇姤浜? 闂佺偨鍎查弻锟犲焵?闂?`Swiper` **濠电偛澶囬崜婵嗭耿娴ｈ櫣纾奸柟瀛樼箘閺?`.index()`**闂?
              //     `playbackSwiperIndex` 闂佸憡鐟禍鐐哄极?`.onChange` 闂佸憡鍔栭悷锝夊焵椤戣法顦﹂柤鑽ゅ枛瀹?`onAppear` 闂備焦褰冮惌渚€锝為敂钘夌窞鐎广儱瀚粔鎾煙?0闂?
              //   闂?闂佸憡鐟禍锝夈€?闂備焦褰冪粔鐢碘偓鍨礃濞碱亪鎳為妷锔绘Н swiper 闂佹眹鍔岀€氼剟宕归崹顐ｅ弿閻庯綆鍠撻埀?闂?闂佺粯顭堥崺鏍焵椤戣法绐旈柛锝囧厴閹啴宕熼妯峰亾?闂佹寧绋戦惌鍌炲Υ婢跺鈻旈幖杈剧到绗戦梺璇″厸缁€浣割潩?*闂傚倵鍋撻柟绋垮閸╁倸鈽夐幘宕囆＄紒鏃€鎸抽幊?*闂?
              //     闂佺粯顭堥崺鏍焵椤戞寧绁版い鏂挎喘閹牓鍩€椤掆偓椤垹鐣濋崘顏呅撴俊鐐€楅崑锝夊焵椤戝灝顧剋iper 闂佺顑嗙划灞斤耿椤忓棛绠?0 婵＄偑鍊楅。顔炬濞嗘挸绠ｉ柡宓啫鍞ㄦ繛鎴炴煥椤戞垹妲愬璺虹劷?闂佹椿娼块崝宥夊春濞戙垺鍎戦悗锝庝簻閻撳倹鎱ㄥ┑鍡欑劮闁伙附绻冮妵鍕枈婢跺瞼顦?
              //     婵炶揪绲藉Λ娆撴儉閸涙潙瀚夊璺侯槹瀹曟彃霉?濠电姴锕ラ崹鍨叏?闂佸憡鐟﹂崹褰掑极?闂?`animateLyricMorph` **婵炲濮寸€涒晛顭囬棃娑掓煢闂勫洭锝為敂鐐闁告劦浜濋弳?* 闂?`lyricMorphT` 闂?0
              //     闂?闁诲繐绻嬬欢姘焽娴兼潙绠掗柟鍝勭Х缁€瀣熆閸棗鍟板▓閬嶆⒒閸偅濞囬柍?*闁哄鏅滈悷銈囩箔瀹€鍕妞ゅ繐瀚粋鍫ユ倵閻熸媽瀚伴柛娆忕箻瀹曘儳鎷犻崣澶娾偓?*闂?
              //
              // ## 闂佽　鍋撻悷娆忓閵嗗﹪鏌ㄥ☉妯煎濠碘剝鎮傞幃鈺呮嚋绾版ê浜惧ù锝堫潐缁ㄦ岸鏌熼幁鎺戝姎婵炲弶鐗犲畷銏″濞嗘垹鐛ラ柣?swiper 闂佹眹鍔岀€氼剟宕归崹顐ｅ弿閻庯綆鍠撻埀?= 闂佺粯顭堥崺鏍焵椤戣法绐旈柛锝囧厴閹啴宕熼妯峰亾婢舵劖鏅?
              //   `.index(this.playbackSwiperIndex)` 闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕€危?ArkUI `Swiper` 闂佹眹鍔岀€氼剟鎮炬總绋挎闁荤喐澹嗗锝夋煙椤戭剙绉剁粈?
              //   闂佸吋婢橀張顒勫垂濠婂嫮顩锋い鎺嶇劍閹烽亶鏌℃径鍫濆姎婵ǜ鍔戦獮搴㈢節閸涱垳顔愭繛鎴炴惄娴滄粓鍩€椤掑倸甯剁紓?閻熸粎澧楅幐鍛婃櫠閻樼偨浜?闂佹眹鍩勯悡澶屾濡?onChange` 闂佸憡鍔栭悷銉╂偩閻樿违濞戞棏鏌昻Appear` 婵犮垼娉涚粔宕囩礊閸涱垪鍋撻悷鏉挎灕缂佽鲸宀告俊?
              //   闂佸疇娉曟刊瀵哥箔?**婵炴垶鎸哥粔瀵告閳哄懎绀傞柕澶堝€栧畷鎻捗归敐鍡樼闁哄苯锕顐﹀级鎼存挸浜?*闂佹寧绋掗懝楣冩偩閻樿鍙?闂佺娉涢敃銈夊礄閿熺姴瀚夊璺烘湰閻ｉ亶鏌ｅΟ鍨厫闁逞屽厸閻掞妇鏁幘顔肩闁瑰嘲鐭堝鎺楁煕閵夈儱缍栫紒?闂佹寧绋戦懟顖炴儓濡崵鈹嶆い鏃囧吹椤忛亶鏌ゅ畡鎵憼闁逞屽劯閸″繐浜鹃悘鐐跺亹閻熸繈鏌￠崟闈涚仴闁汇劎鍠栧畷锝夊磼濡嘲浜?
              //   闂佸疇娉曟刊瀵哥箔?闂?026-10-16 闁荤姳闄嶉崹娲敆濠婂牆违闁硅揪绲跨粻褰掓⒑閹绘帟瀚伴悽顖ｅ亰瀵爼濡烽妷銉︽闂佹椿鍋€閸?`onAppear` 闂備焦褰冮惌鍌炲磻閸涙潙鐭?
              //      `playbackSwiperIndex = 0` 婵炲濮寸粔宕囨崲濮樿埖鍋? 闂佺偨鍎查弻锟犲焵?**闂備緡鍙忕徊鍊熴亹閻愬樊鍟呴柤纰卞墰閻ュ懘鏌涢幒鏂啃ｉ悽顖楀亾婵?*闂?
              //      闁诲海鎳撻崯顖毼ｉ幖浣瑰殟闁稿本绮屾禒顖滅磼閻欐瑥鍟粈鈧柣鐘差儏閸熸挳宕抽悜鑺ュ剭闁告洦鍋勯弲鎼佹煕韫囧鍔电紒杈ㄧ箖鐎电厧顫濋鐑嗘降闂佺懓鎼ˇ閬嶅极閵堝绠ｇ€瑰嫭澹嗙粔濂告煕閹惧磭效闁靛棗顦甸弫?
              //      "闂佺懓鐏氶幐鍝ユ閹达箑绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ婵炲弶鐗滄禍鍛婄瑹閳ь剙顭囬悧鍫涗簻?闂?*闂佺懓鐏氶幐鍝ユ閹达箑绠涢煫鍥ㄦ尰缁?*闂佹眹鍔岀€氼垱绂嶇€靛憡瀚婚柨婵嗙箳缁€鍕偡濞嗗海顦﹂柛鐐差嚟閳ь剙婀遍幊鎾绘儑?`onAppear` 闂備緡鍙忕徊楣冾敊瀹€鍕拹闁圭瀛╅弳鍫ユ⒑閹绘帩鐓紒杈ㄥ哺婵?
              //   婵犮垼娉涚粔鐢告偋閹惰棄绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽鲸婢橀銉╂嚍閵壯冪伇**缂備焦顨忛崗娑氱博妞嬪孩鍋?* `sw=` / `tgt=`闂佹寧绋戦悧濠囧蓟婵犲洤绀夐柣娆忔噽缁€鍡涙煃閵夛附鐓涢柍?
              //     `sw=1 tgt=1` 闂佸綊娼х粔闈浳ｇ粙娆炬桨鐎光偓閸愵亝袚婵＄偑鍊楅弫绋库枔閹存繍娼伴柨婵嗘噽閸╂鏌熼璺ㄧ瓘缂佽京娴梥w=0` 闂佸吋婢樻總鏃傜礊濮椻偓瀹曠兘濡搁敂鐐啓闁荤姴娲ょ粔褰掑Υ?闂?闁诲繐绻楁ご绋课ｉ幖浣稿珘妞ゆ帊鐒﹂拏瀣煏?
              Swiper() {
                Stack({ alignContent: Alignment.TopStart }) {
                  //   闂佸搫鍟版慨鐑藉疾椤愶附鍎?`playerPane` 闂?`Swiper` 婵炴垶鎸堕崐婵嬪Υ婢舵劖鐒鹃柦妯侯槸濞懷囨煛?`Column().width/height('100%')`闂?
                  //   **闁诲繐绻嬬欢姘焽閻楀牏鈻旈幖娣灮閹藉啴鏌涘顒傂ｉ柣妤佹尦瀵敻顢栫捄銊ф喒闂侀潻璐熼崝鎴﹀Υ婢舵劖鐓?*闂佹寧绋戦惌渚€鍩€椤掆偓閼活垰锕?`Swiper` 婵炴垶鏌ㄩ鍛此囨繝姘剭闁告洦鍣ú顒勬煟閳哄倻澧柣?
                  //   闂佹寧绋戝濉甽oatingCover` / `floatingMeta`闂佹寧绋戦惌渚€锝?`PlayerPage闁诲海鎳撻張顒勫汲椤ゆ杯闁诲氦顫夊銊┾€?md` 闁? / 闁? / 闁?闂佹寧绋戦ˇ顓㈠焵?
                  //   闂?闁哄鏅滈悷鈺呭闯閻戣棄绀嗛柣妯哄暱缁?`MusicPlayInfoBlock`闂佹寧绋掗懝楣冩偩閻樼粯鍤婃い蹇撳閺併劑鎮樿箛搴ｇ獢婵?+ 濠殿喗绻傞懟顖炲箖閺囥垺鏅?
                  //     闂佷紮绲鹃悷褍顭囬崘顏冪剨闁告瑦顭囩粣妤呮煕濠婂啰鐒搁柛瀣噺缁?*闂佸摜鍎愰崹顖滅博閹绢喗鍎嶉柛鏇ㄥ櫘濞差剟鏌ｉ埡鍌滃ⅹ闁?*闂佹眹鍨荤划顖炲垂濮橆厾鈻旈柕鍫濆閺佹粓鎮樿箛搴ｇ獢婵為棿鍗虫俊?
                  //   闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯顐ゆ暜椤愶箑绾ч柕澹嫮鏆犳繛鎴炴尪閸婃捇鏌屽鍫熷殏鐎光偓閸愵亞鍘梺鎸庣☉濞?id(PLAYER_BIG_COVER_ID)` + `reportBig`闂?
                  //      `.id(PLAYER_META_*_ID)` + `publishMeta`闂?*閻庤鐡曠亸娆戝垝閿熺姴绠规い鎺嗗亾闁糕晛鐬奸幉浼村幢濞嗘劗锛愰柣?*闂佹寧绋戦悧鎰帮綖?
                  //      `reportPlayerCoverFromOverlay` / `publishMetaEndpoint`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
                  //      闁哄鏅滈悷锕€危閸涘﹥浜ゆ繛鍡樺姦閸嬔囨煠鐎圭姵顥夐柛銊ョ秺閹啴宕熼銏╂瀫闂佸湱绮崝褏妲愭潏銊р枖濠电姳鑳堕閬嶅级閻戝棗鏋涙慨妯稿姂瀵即顢涘☉姘鳖攨婵炲瓨绮屽Λ婊呮崲閺嶃劎鈻旈柍褜鍓欓～銏ゅΨ椤栨粎顦柣搴濈祷婢瑰牓宕?闁诲繐绻嬬欢姘焽閺夊簱妲堥柛顐ｇ缚娴?+ 闂佸憡鏌ｉ崝搴ㄥ极妤ｅ啫绀傞柕濞垮劤閻?闂?
                  //   闂佸疇娉曟刊瀵哥箔?闁诲海顢婂Λ鍕儓?闂傚倸鐗勯崹鍝勵熆濮椻偓閺屽洭鏁愰崟顔规嫛闂佸搫顦埀顒€鍟块悗濠氭煛閳ь剟顢涘▎鎴犵厳闂侀潻璐熼崝搴ㄥ极閵堝洠鍋撻悷鏉挎灕缂佽鲸鐛婸laybackPage` 闂佸憡鍔曢幊搴ゃ亹閻旂厧瀚夊璺侯槼閳峰牆顭跨捄鍝勵伒缂佽鲸宀搁弫?
                  //      闂佸湱顣介崑鎾趁?import 婵烇絽娲︾换鍕汲閳ь剟鏌?
                  // ★★★ 2026-10-18（照搬上游结构 · 第五轮）：**第 0 页 = 空壳**。
                  //   上游 `playerPane` 的 Swiper 第 0 页就是一个只有 width/height 的**空 `Column`**
                  //   （`wujie.pa:189547-189573`，λ `@34*#^2`，全文 12 条指令、**零子节点**）；
                  //   歌名行之下没有任何节点（`:171747-171846`）。⇒ 本页现在也是空壳。
                  //
                  //   ⛔ 这里原来挂着小歌词块，用 `.position({ x: 0, y: this.miniLyricTopY() })` 定位：
                  //      那是**窗口绝对 y**，而歌名行走的是「满盒高 Column + justifyContent(Center)
                  //      + `offset({ y: this.metaOffsetY() })`」（`PlaybackPage.LyricFloatLayer`）——
                  //      **两套坐标系**，只要 `estBoxHVp()` ≠ 窗口高就必然偏，调公式永远调不出来。
                  //   ⇒ 小歌词已整体搬进 `LyricFloatLayer()`，成为歌名行的**流式兄弟**（那里有完整算式与
                  //      上游行号）；本页不再有任何定位量。
                  //
                  //   ⚠️ 下面这段是旧实现的**注释残页**（本仓该段中文注释是双重编码乱码，`edit` 无法逐字
                  //      匹配，为不误伤文件只删代码、留注释文本）；**代码已全部删除，不参与任何布局**，
                  //      下次整段重排时可以整块清掉。
                        // 閳藉應妲勯埥鍛 2026-10-17閿涘牏鏁ら幋鍑ょ窗閵?*鐏忓繑鐡曠拠宥嗘杹娑撳娼?*閵? 閹搭亜娴橀柌灞界暊閸樺婀灞芥倳鐞涘奔绗傞敍?
                        //   鐎瑰啯澧嶉崷銊ф畱妞?0 `Stack` 閺?`alignContent: Bottom` 閳?鏉╂瑤绔撮崸妤冩畱娑撳绔?*鐠愬娼?
                        //   swiper 閻╂帒绨虫潏?*閿涘矁鈧本鐡曢崥宥堫攽濮濓絽銈芥稊鐔锋躬闁絼绔撮弶鈥崇敨娑?閳?韫囧懐鍔ч柌宥呭綌閵?
                        //   閳?缂佹瑤绔存稉?*閸氭垳绗傞幎?*閻ㄥ嫪绗呮潏纭呯獩閿涘本濡搁弫鏉戞健閹额剙鍩?濮濆苯鎮曠悰灞肩瑓濞?閳?鏉╂稑瀹抽弶鈥茬瑐濞?娑斿妫块妴?
                        //   閳跨媴绗?56 閺勵垶顩婚悧鍫濆絿閸婄》绱欓埉?娑撱倛顢戝宀冪槤閻ㄥ嫰鐝惔?+ 娑撯偓閻愮懓鎳犻崥闈╃礆閿涙稒瀵滈幋顏勬禈瀵邦喛鐨熺亸杈ㄦ暭鏉╂瑤绔存稉顏呮殶閵?

                        // 闂佺补鍋?2026-10-17闂?*闂佸憡顭囩划顖滄暜閳ь剟鎮归幇顔兼瀻妞わ妇绮蹇曟兜閸涱垳宕?* 闂佺偨鍎查弻锟犲焵?闂佸湱顭堥ˇ顔剧箔閸屾哎鈧?gemini 婵犮垼娉涚粔鐢告偋瀹曞洨纾奸柟鎹愵嚃閸熷牓鏌?
                        //   婵?0 闂備焦褰冮惉鐓庘枔閹达箑绀冮柛娑卞弾閸熷洭鐓崶褎鍤囬柕?*濠电偟绻濈粈浣烘?*闂佸湱鍎ょ敮鎺旂博閻戣棄鎹堕柕濠忛檮閹峰崬顪冮妶澶嬫锭妞ゆ梹鍔欏畷鎶藉Ω閳轰焦顏為梺?*婵炴垶鎸哥粔鐑筋敊韫囨稒鍋ㄩ柕濞у懎宕柣搴ｆ暩閹虫捇鎮鹃悙顒佸?闁荤姵鍔楅崰搴ㄋ囩紒妯荤秶缁绢厼鎳愰悰?
                        //   闂佺娉涢敃銈夋偩閻樿绠抽柕濞垮劚閻撳倹鎱ㄥ┑鍡氬闁诡喗娲滈幃鏉跨暆閸曨偂绨兼繛鎴炴尨閸嬫捇鏌℃径鍡忓亾瀹曞洦鏆?*闂佹寧绋戦懟顖炲箚娓氣偓瀹曟艾鈻庤箛姘厒闂佸憡鐟﹁摫婵犫偓閳╁啫顕辨慨姗嗗亞閻熴垺鎱ㄥ┑鍡氬闁诡喗娲滈幃鎵沪閻戔晛浜惧ù锝囨櫕缁犲骞栨潏楣冩婵炵⒈鍨堕幆鍕川婵犲啫顕￠梺?
                        //   闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鏌?`bottom: -MINI_LYRIC_SINK_VP`闂佹寧绋戦悧濠冧繆閸濄儮鍋撻悷鏉挎殭缂佽埖纰嶇粙澶屸偓锝庡亜閼?112vp 闂?闂備緡鍓欓悘婵堟閹存繍娼伴悘鐐跺Г閸?闂佹寧绋戦¨鈧紒?
                        //   闂佸吋婢橀張顒勬偤閺囥垹瑙︾€广儱鐗滈弨浠嬫煟濠婂嫭绶叉繝鈧鍕靛晠闁告瑥顦伴弳顓㈡煟?*婵＄偑鍊濆褔宕幘顔奸敜闁归偊鍘鹃崹?*闂佹寧绋戦悧鍛箔閸屾哎鈧帞绮欓崹顔剧▔閻庡灚婢樼€氬摜妲愬璺虹劷?婵炴垶鎸哥粔鎾疮閳ь剟姊婚崶锝呬壕闁荤喐娲戝ù鍥╂崲閺嶃劎鈻旀い蹇撴硽婢跺鈻斿〒姘功缁€?
                        //   闂佷紮绲鹃悷褍顭囬崘顔肩煑鐎广儱鐗冮崑鎾朵沪閼测晝鐛ラ梺纭呮硾閿曘倝鎮鹃悩璇茬闁靛鍎遍悡鍌炴煛閸モ晝绡€缂佹鎳樺Λ鍐閻樿尙顔岄梺鐟板⒔閸嬬姷鎹㈠Ο缁樺劅闁挎棁濮ら拏瀣煏閸℃浜扮紒?
                      // 闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱鎳愬锝吤?闂佸憡鍔曢幊搴敊?闂佹寧绋掗懝鎯ь嚕閻ｅ瞼纾介柡宥庡墰濡差垶姊?`contentOpacity` 闂佽В鍋撻柟瀛樺笧缁夋挳鏌熼棃娑毿ら柣?1
                      // ★ 2026-10-18（用户：「我要的是小歌词和歌曲名歌手名一样从下面飞上来」）：
                      //   歌名/歌手那一行（`floatingMeta`）的不透明度走 `targetMetaOpacity()` → `pullChromeOpacity()`
                      //   = `clamp((pullT − 0.18)/0.44)`（无界 `wujie.pa:176459-176505`，吃 `effT = pullT`，
                      //   见 `PlayerExpandState.pullChromeOpacity`）；
                      //   小歌词原来乘的是 `morphContentOpacity`（本仓**恒 = 1**，见 `applyMorphGeometry`）
                      //   ⇒ 它没有淡入窗口：形变裁剪窗口（`morphClipHeight()`）一扫到它，它就是"整块 0.55
                      //   直接出现、再往上挪"，而同一时刻歌名行才刚开始淡入 ⇒ 观感上不在同一组里。
                      //   改成与歌名行**同一个窗口、同一条曲线**，再乘用户要求的 0.55 淡（静止态仍是 0.55，
                      //   与改动前逐值一致）。位移本来就与歌名行同名（下一行 `.translate({ y: metaRiseVp() })`）
                      //   ⇒ 两组从此同起同落。

                      // 闂佸疇妫勯幊澶娢?2026-10-15 闂佹椿娼块崝宥夊春濞戞埃鍋撶憴鍕孩闁汇劎鍠栭弫宥咁潩閵夈垹浜?*闂佺绻愰悧鎾凰夐敐澶婄闁靛／鍕殸闂佸搫瀚烽崹浼存儍椤掆偓椤垹鐣濋崘顏呅撻梺鍛婄矊閺堫剟寮ぐ鎺撳癄闊洦鏌ㄩ惁濠氭⒑?*闂?
                      //   闂?闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱鐗愬▔?*缂備焦顨忛崗娑氱博鐎靛摜纾?*闂佹眹鍔岀€氼厼顪冮崒鐐粹拻閻庨潧鎽滃畷鍫曟煥濞戞ɑ缍乪arlyRiseVp()`闂佹寧绋戦張顒€螞椤撶喓顩查幖娣灩娴犳﹢鏌涢幒鏇熺【閻忓浚鍨堕弻鍥晲閸曨収浼囩紓鍌欑鐎氬摜妲愬鑸垫櫖?
                      //   婵炲濮寸花鑲╃箔閸涙潙纭€闁搞儺浜濆畷?180vp闂佹寧绋掗惄顖氼焽閵堝拋娼伴柕蹇婃閸嬫挻鎷呮搴Ｐ㈢紓浣割槺缁垱绂?0闂佹寧绋戦惉鍏兼櫠濡ゅ懏顥堥柕蹇嬪€愰崑鎾诲箛椤掆偓閸撹偐绱掓潏鈺佇＄紒妤€顦靛畷锝呂熺化鏇炰壕?
                      // ★ 2026-10-17（用户实测「小歌词位置太低 / 大小不对」）：竖直升入改走**歌名行同一个窗口**
                      //   （`metaRiseVp()` = 0.18→0.62）。原来用的是控制区那组 `contentRiseVp()`（0.45→1.00）
                      //   ⇒ 形变中段歌名行已经在往上飞了，小歌词还沉在下面 ~180vp ⇒ 屏上就是"压到进度条下面"。

                      // 闂佽　鍋撻柟顖滃瀹曟娊寮堕埡浣瑰窛闁宠鍚嬬粙澶愵敇閻愬弶鏆ラ柣搴℃贡椤㈠﹪锝為敃鍌氬偍閻庯綆鍋勯。鎶芥煥濞戞瀚伴柣顭戝墮椤垹鐣濋崘顏呅撴繛鏉戝悑閼归箖骞忔导鏉戠鐟滃秹宕哄Δ鍛閺夌偞澹嗛棄宥夋煟閳轰焦鎲告繛鎻掞攻閹?
                      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘极閵堝绠ｉ柛鎴欏€楃粣?*闂侀潧妫楅懟顖炴儍椤掆偓椤垹鐣濋崘顏呅撻梺缁樼矋濠㈡ê锕㈤鍫濈煑婵☆垵顕ч悘鍥瑰鍐╊棞濠殿喒鏅犻幃浠嬫嚒閵堝洦灏濋梺鍝勵槺閸犲秶绮婚敐澶婅Е閹兼番鍨归·鍛存煕閹达絾顏犳鐐叉喘閺佸秶浠﹂悙顒佹瘔婵炴垶鎸撮崑鎾斥槈閹炬剚鍎滅紒?
                      //   闂佸憡鐟ラ崐浠嬪焵椤掆偓閸燁偊宕ｉ崜褉鍋撻悷鏉挎殭婵炵》绻濋獮鈧幖瀛樼箘閻ゅ嫬顪冪€ｎ剙浠滈柛娆忔婵?*闂佹寧绋戦ˇ顐﹀闯?闂侀€涘嫎閸婃洖煤閺嶃劎鈻斿┑鐘辫兌椤忛亶鏌?閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏃€妞块崬銊р偓娈垮枓閸?闂佹眹鍔岀€氭澘鈻撻敐澶嬪癄闊洦绋掗敍宀勬煥?
                      //   闁诲海鎳撻崯顐﹀箯娴兼潙绀嗘い鎰╁€栭悾閬嶆煕瑜庨妵鐐电博閹绢喖鍐€闁告垯鍊楃粈?*閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏃堟敱閻ㄦ垿鎮归崶銉ュ姎婵犫偓椤忓牆鎹?*闂侀潧妫斿ù鍥憘鐎ｎ剛绠旀い鎴ｆ硶椤忚京绱撴担绋款仾婵＄偛鍊垮鑽も偓闈涙憸瀹?`earlyRiseVp()` 婵炲濮寸花鑲╃箔閸涙潙纭€闁搞儺浜濆畷?
                      //   闂佹寧绋戦悧鍛箔閸岀偞顥堥柕蹇嬪€曟禍婵嬫煛?`.translate`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婂锝為锕€绠婚柣鎰劋閿涙牕螞閻楀牜鐒介柡浣稿船椤垻浠﹂懞銉モ偓鎶芥偠濞戞ɑ婀伴柡浣稿悑閵囧嫰妫冨☉妯绘殽闂佺鍕闁绘牭绲块幉鎾晲閸涱厽鐎梺鎸庣☉婵傛梻绮径鎰棃闁绘鍎らˉ鎴︽倵閻熸澘鏆旈柍?

                  // 闂?2026-10-15 闁荤姴娲ら敃銉╁蓟閸ヮ剚鐓ユ慨妯哄船娴狀垶鏌ㄥ☉妯荤秮hdc shell hilog -x | Select-String 'RzdBoxes'`闂佹寧绋戦¨鈧紒?
                  //   闂?*婵炴垶鎸搁ˇ顕€鏌屽鍕嚤婵﹩鍋嗛棄宥夋煟閳哄喚鐒鹃悽顖氭喘閹啴宕熼锝呬淮**闂佹眹鍔岀€氼噣鎮伴妷鈺佺煑闁挎繂娲ㄩ崣鎰喐闁附绶氱紒鏃€娼欓埢搴ㄥ焺閸愩劉鍙洪梺鍛婂灩閸庛倕顭?闂佺偨鍎查弻锟犲焵?
                  //     `lyric` 闁诲繐绻愮换鎴︽偤閺囩姵瀚?/ `title` 濠殿喗绻傞懟顖炲箖?/ `singer` 濠殿喗绻傞張顒佹櫠?/ `cover` 婵犮垹鐖㈤崘顏咁唸闂傚倸鐗滃鍧楀焵?
                  //   闂佸憡甯囬崐鏍х暤娓氣偓閺佸秴顫㈠鐡俽ic.top` 婵?`singer.bottom` 闂佺儵鏅犻弲鎻掝潩?闂?闁诲繐绻楁ご绋课ｉ幖浣瑰仺闁靛绠戦悡鏇㈡煙闊彃鍔ゆ繛?闁哄鏅滈悷鈺呭闯閻戣姤鐓ユ繛鍡楁捣缁?闂?
                  //         婵炴垶鎸哥粔璺好规径瀣洸闁靛牆鐗冮崑鎾朵沪閼测晝鐓楅梺娲讳簻椤戝洤顭囬崘顔煎偍閻庯綆浜濋煬顒€鈽夐幘顖氫壕闁?闂?闂備緡鍙忕徊鎯?*缂傚倷鐒﹂敋闁?*闂佹寧绋戝鍍le/clip闂佹寧绋戦ˇ鎶藉焵椤掆偓婵傛梻绮径鎰強妞ゆ牗绋戠粭鎾绘煟濡も偓閻楃偟妲愬┑瀣煑闁挎棁妫勯ˉ婵嬫煏?
                  // 鈽呪槄鈽呪槄 2026-10-17锛堢敤鎴凤細銆屽皬姝岃瘝瑕佽惤鍒版瓕鎵嬭涓嬫柟銆嶏紱姝ゅ墠瀹冧笅杈硅创鐫€ swiper 鐩掑簳 鈬?蹇呯劧鍘嬩綇姝屽悕琛岋級
                  //   鏀规垚 TopStart + 缁濆瀹氫綅锛歽 = metaTopGeomY + 琛岄珮 + 闂磋窛 鈭?鐩掗《锛坄lyricBoxTopVp` 鏄棦鏈夋帰閽堬級銆?
                  //   闈欐鎬?= 姝屾墜琛屼笅娌?+12vp锛涘舰鍙樻€佷粛鐢?`contentRiseVp()` 浠庝笅鏂瑰崌涓婃潵锛堢獥 0.45鈫?.00锛夈€?

                }
                .width(StyleConstants.FULL_WIDTH)
                // 闂?濠殿喗绻傞懟顖炲箖?濠殿喗绻傞張顒佹櫠濠婂牊鐒介柨婵嗗椤忛亶鎮?*闂佸憡鐟禍锝夋憘鐎ｎ偁浜滈柤鍝ユ暩閸╁姊洪銊у缂佹梹娼欓々?*闂佹寧绋戝濉竨llChromeOpacity = clamp((effT-0.18)/0.44)`闂?
                //   0.18 闂?0.62闂佹寧绋戦¨鈧紒杈ㄧ箞瀹曟繈濡歌閺嗕即寮堕埡浣瑰窛闁宠鍚嬬粙澶愵敇閻愬娈ら柣鐘叉储閸庤尙鎷规导鏉戠?闂佺偨鍎查弻锟犲焵?婵炴垶鎸稿ù鐑藉极閵堝绠ｉ梺鍨儏椤庣偤鏌℃径搴㈢《婵炲牊鍨圭划?2 闂佸搫顦埀顒冨皺椤忛亶鏌ら柨瀣殬闁?
                //
                // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯閻戣棄鍌ㄩ柣鏂挎啞闂勫秹寮堕埡鍋亣銇愰弮鈧粋宥夊幢閺囩媭浼囬柣?`metaOpacityValue() = clamp(1 - morphP/0.35)`闂?
                //   闂?*闂佸搫瀚烽崹鐢靛寲閻樿櫕濯撮柣妯挎珪閽傚姊洪銊у缂佹柨鐡ㄧ粭鐔活槾婵炲牊鍨佃彁闁炽儱鍟垮В?*闂佺娴氶崜娆戞閿熺姵鏅柛?0.35 闁诲繐绻愬畷顒傜礊婵犲洦鈷栭悹浣告贡缁€鍡涙煥濞戞瀚版い銊︾矒瀹曠兘濡搁敂钘夊晩闂佽　鍋撳Δ锝呭暔閳ь剙顦板璇测枎鎼达綆浼囬柣鐐寸☉婵傛梻绮?
                //   = 闂佹椿娼块崝瀣偖鏉堛劎鈻旀い蹇撶墛閿涘苯顭块崜浣瑰殌闁诡喗鎸荤粙澶愬焵椤掑嫬閿ゆ俊銈傚亾闁哥偛顕埀?闂佺偨鍎查弻锟犲焵?`pullChromeOpacity` 闂佸搫瀚€涒晛危閹存繍鍟呴柤纰卞墰閻ュ懘鏌?1闂?
                //   闂佸憡顨堥ˉ鎰帮綖?`metaOpacityValue` 闂佸湱顭堥ˇ顖炲春?0闂佹寧绋戞總鏃傝姳椤掑嫬鍙婃い鏍ㄧ〒閹藉啴鏌?濠殿喗绻傞張顒佹櫠?*闂佺绻堥崝搴ㄥ煝閸忚偐鈻旂€广儱鎳庣拋鏌ユ偡濞嗗酣妾烽柍褜鍏涘ù鍥箚閵堝棙濯寸€广儱妫楅·鍛存煕閹邦厼绗掗柛銈庡弮瀵?*
                //   闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎戞繛鍫熷灴婵″浠﹂悾灞剧秾閻庢鍠掗崑鎾斥槈閹垮啫骞楅柡瀣暟閳ь剚绋掗〃鍫澝洪崸妤€绀嗛柟娈垮枤濞夈垽鏌℃径灞芥瀾濠⒀呭█瀹曟瑩鎼归悷鎵杸闂侀潧妫楃粙鍕濮樿泛违?
                //   闂佸憡甯炴慨鐢垫暜閳ь剟寮堕埡鍌滄噥缂佹柨顕禒锕傚磼閿斿墽鐛MusicPlayInfoBlock.MusicInfoTexts` 闂佺厧顨庢禍婊呮崲娴ｅ壊鍟呴柤纰卞墰閻ュ懘鎮?`pullChromeOpacity`闂?
                .opacity(this.expandState.pullChromeOpacity())
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.music_component_top'),
                  bottom: this.isSmHeightMdLayout() ? 0 : $r('app.float.music_component_bottom')
                })
                .padding({
                  left: this.isSmHeightMdLayout() ? 0 : $r('app.float.common_padding'),
                  right: this.isSmHeightMdLayout() ? 0 : $r('app.float.common_padding')
                })

                Column() {
                  LyricsComponent({
                    isShowControl: false,
                    isTablet: this.isTabletFalse,
                    // 闂?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁稿繐鎽滈悷婵嬫煕閹邦剛啸闁搞倖绮庨弫?濠殿喗绻傞懟顖炲箖?闁荤姴娲ょ粔闈浢?闁荤偞绋忛崝宀勫Φ?*闂?
                    //   闂佸搫鍟版慨鐑藉疾椤愩埄娼扮€光偓閸愵亝袚婵＄偑鍊楅弫濠氬Υ婵犲啰鈻斿┑鐘插€归惃鎴︽煛閸曢潧鐏﹂柛瀣噺缁嬪鍩€椤掑嫬绾ч柍鈺佸暢閻т線鎮橀悙鎻掆偓褰掓惎闁荤偞绋戦惌澶屾濞嗘垳鐒婇煫鍥ㄦ尵濞堥亶姊?+ 濠殿喗绻傞懟顖炲箖?+ 闂佽　鍋撻柟顖滃椤?闂佸搫娲﹀娆撍囬崸妤佹櫖濠㈣埖绋撶粈?
                    //   濠殿喗绻傞惌渚€鎯佸┑鍡╂桨闁挎繂妫欓悗顕€姊洪幓鎺撴拱闁汇儱鎳樺鍨緞瀹€濠傚壋婵炲瓨绮屾總鏃堟煂濠婂喚娼伴悘鐐跺Г閸婃娊鏌曢崱妤€鈧摜鏁锕€绾ч柕澶堝妿缁犲綊姊洪幓鎺撴拱婵?`isSmHeightMdLayout()`
                    //   闂?缂備焦姊归悧鏇㈡儓閸℃鈻斿┑鐘辫兌缁?*闂佸憡鑹鹃張顒€顪?*闂佸憡鍨煎▍锝夌嵁閸ヮ灐褰掝敊閼测晜鍕鹃梺姹囧妼鐎氼參鎮洪弴銏犺Е鐎广儱鎳忕€氬弶鎱ㄥ┑鍡欑劮闁伙附绻堥幊娑㈩敂閸曨厽鏆旈梺?
                    //   "闂佸搫鐗嗛ˇ鐢杆夐幘璇茬睄闁绘ɑ妞垮Λ鎴︽煟閵娿儲顥￠柛銈嗙矒閹?- 闂佺粯绮岄鍕博鐎涙ɑ濯?/ 闁荤姴娲ょ粙鍕娴煎瓨顥堥柟鐑樻尵閸?闂佹寧绋戦惌渚€锝為崶顒€绠涢柣鏃堟敱閻ㄦ垿鏌?濠殿喗绻傞懟顖炲箖閺囥垹绀勯柧蹇曟嚀缁犳稑鈽夐幘鍗炩偓鏍敃?闂?
                    hideLyricsMetaHeader: true,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闁哄鏅滈悷銈囩博閹绢喖閿ゆ俊銈勮兌閵堟挳姊洪幓鎺旂闁告垟鍓濈粋?闂佸憡甯囬崐鏍х暤?闂傚倸瀚粔鑸殿殽閸ャ劎鈻?闂佸憡绺块崝宀勫矗?** 闂佺偨鍎查弻锟犲焵?缂傚倷鐒﹂幑渚€顢欓幋婵愬晠闁哄被鍎查敍鏃堟煕濮橆剛澧崇紒杈ㄥ哺閺?
                //   婵炴垶鎸搁敃銉︽叏閵堝拋娼扮€光偓閸愵亝袚婵＄偑鍊濆褔宕€电硶鍋撻悷鐗堣础婵炴彃鎳橀幆?*缂備焦鍔栭〃鍛般亹濞戞瑣浜滈柟顖涘閻?*闂侀潧妫楅崐鍝ョ礊鐎ｎ喖绀嗘繝闈涙椤綁鎮楅悷鏉挎殲婵℃彃鎲＄粙澶嬫姜閹殿喖鏅╅柣?`lyricPadTop()` 闁荤喐娲戝鎺旂箔婢跺本鍟哄ù锝囨嚀鎼村﹦绱掗悩鎰佹當婵炲吋顨婂?闂?
                //   闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗閸?`boxH/2 + bottomYAtLyric` 闂佸憡鑹鹃悧鎰板箲閿濆绾ч柕澶堝劜閻ㄦ垿鏌?濠电偞鎯岄崰鏍儑閻楀牊鍎熼柡鍥风磿閻?*闂佺儵鏅濋…鍫ヮ敋椤曗偓閹嫰骞掑灏栧亾?*"闂?
                //   闂佸吋婢橀張顒€锕㈤悧鍫㈩浄闁圭偓娼欓悷?*缂備焦鍔栭〃鍛般亹濞戙垹閿ら柟閭﹀幘閸?*閻熸粎澧楅幐鎯洪崨鏉戠闁告侗鍨辩粊鏌ユ倵闂堟稓绉洪柛锝嗘そ閹?闂?闂佸憡鐟禍婊冿耿椤忓牊鍎庨柟鐑樸仠閳?闂?0 闂佸搫鍟晶搴ㄦ偤閹寸偟顩烽柡瀣靛亐閸?
                //   闂?**闂佽　鍋撻悹楦挎閸熻尙绱撴担瑙勫磩妞ゆ梹鍨块弫宥咁潩鏉堛劎锛婃俊鐐€曟晶搴ｅ垝閵娾晛鍑犻柛鏇ㄤ簽閻熸劙鎮樿箛姘跺摵婵?0**闂?闂?= Swiper 闂佹眹鍔岀€氼喖煤閸涘瓨鏅慨鍦．iper 闂佸湱顣介崑鎾绘煕閿斿搫濡挎繛?`Column`
                //     婵?`LyricFloatLayer()` 闂佸搫瀚烽崹浼村箖閹惧鈻旈柍褜鍓氱粙澶愵敂閸愵亞鎲归柣?padding 闂?`Stack` 闂佹眹鍔岀€氼剟顢楅姀鈶╁亾濞戞瑥濮х紒杈ㄧ箖缁嬪寮崶璺烘畽 `Stack`
                //     闂佹眹鍔岀€氼剟宕€电硶鍋撻悷鐗堣础婵炴彃鎳庨蹇涙晜鐠恒劎鎲柣?= 缂備焦鍔栭〃鍛般亹濞戙垹鍌ㄩ柣鏂挎惈娴?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻張顒勫汲閿濆洦瀚氬ù锝囨嚀缁侊箓姊洪悙顒€绀冩い?`PlayerExpandState.lyricBoxTopVp`闂?
                //     闂?**婵炴垶鎸哥粔鐟般€掗崜浣瑰暫濞达絿鎳撴惔濠勭磼閻樻剚娈ｇ紒杈ㄧ箖缁嬪﹪鎮㈤崜浣烘喒闂婎偄娲ら幊搴ㄥ疮閳ь剟鎮归崶銊︻潡缂佺粯鐗楃粙澶愵敂閸涱喗顔?*闂侀潧妫楅崐椋庢崲濮樿埖鍋╂繛鍡楁捣閻熸劙鏌熼煬鎻掑姎鐟滄妸鍕枖?闁诲繐绻愬Λ娆忣焽閻㈢瀚夊璺侯槹閻粙鏌?padding 闂佸搫鍟崕濂稿礂濮椻偓瀹曪綁骞嬮悩鑼杸"闂?
                //   闂佸疇娉曟刊瀵哥箔?闂婎偄娲ら幊姗€濡磋箛娑欏仺?`globalPosition`闂佹寧绋戦悧蹇涙偘閵夆晛鐭楅柨婵嗘噺缂嶅繘鏌″鍛カ缂佽鲸宀搁弫宥団偓鐟版疆osition` 闂佸搫瀚烽崹鍐裁规径灞稿亾闂堟稒璐￠柛鈺傤殘缁辨帡宕熼鍜佸仺闂佹眹鍔岀€氥劑鍩€?
                //   闂佸疇娉曟刊瀵哥箔?闂佸憡鏌ｉ崝搴ㄥ极閻愵剛鈻旀い鎾跺仧閺嗗﹪鏌涘▎妯虹仴闁稿繑锕㈤幆澶愵敆娴ｈ妲梻?0闂佹寧绋戦悧鍡涱敊閹版澘闂?`.scale/.translate` 闂佸憡鐟﹁摫鐎规洖寮跺濠氬炊閳哄倻鏆犻柣鐘叉川缁垶寮抽悢鍏兼櫖閻忕偟铏庨崝鈧柣銏╁灦濞艰崵妲愬鑸垫櫖?
                //     闂佸憡鐟禍婵嗭耿?*闂傚倸鐗婇悷锕傤敆濞戙垹绠?*闂佸搫瀚€涒晛螣婢舵劖顥?0 闂佸綊娼х粔鐑筋敋閳哄懎鍙婇幖杈剧悼濞夈垽鏌＄€ｎ亜顏╃憸鏉款槹缁傚秹宕遍幇銊ヤ壕?
                .onAreaChange((_oldValue: Area, newValue: Area): void => {
                  this.expandState.reportLyricBoxTop(areaLengthToVp(newValue.globalPosition.y));
                })
                // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`PlayerPage.onLyricSwipe(offsetY)` 闂佺偨鍎查弻锟犲焵?**闂備緡鍋呴崝鏍ь焽椤栨壕鍋撻棃娑氱Ш缂?*闂?
                //
                // 闂佸搫鍟版慨鐑藉疾椤愶附鏅柛褍鍨硆ecover/logic-src/PlayerPage.abc.txt:6938-6985`闂佹寧绋戦張顒傗偓鍨礋瀹?`LyricsView` 婵炴垶鎸搁…顓犳濮樿埖鏅?
                // ```ts
                //   onLyricSwipe(offsetY) {
                //     if (offsetY <= -SWIPE_TOGGLE_VP) {                 // 闂?婵炴垶鎸搁敃銉у垝?
                //       if (entryAllowsManual(this.lyricImmersive)) {   // 闂?闂?闁哄鏅滈悷銈囩博閹绢喖缁?*闂佸搫鐗嗛ˇ闈浳?*
                //         hideChrome(); clearIdle();
                //       }
                //     } else if (offsetY >= 24) {                        // 闂?婵炴垶鎸搁鍡欏垝閿曞倹鏅柛顐ｇ箘閹界喖姊婚崼娑樼伈闁?0x18 = 24闂?
                //       showChrome(); startIdle();                       // 闂?闁哄鏅滈悷銈囩博閹绢喖缁?*闂佸搫鍟版繛鈧俊?*
                //     }
                //   }
                // ```
                // 闂?婵炴垶鎸堕崐鏇⑺囬埡鍌溾枖閹肩补鈧櫕鏋鹃柣搴℃贡閸嬬喖鐛崶顒佸剭闁告洦鍋呴埢鏇㈡煕閹烘繂浜剧紒杈ㄧ懇閺屽牓鎸婃径濠傛闂佸湱顭堥ˇ顖炴偤瑜旈幊鐐哄磼濠婂懎鐏ｉ柣鐘遍檷閸ㄦ椽顢楀鍫熸櫖濠㈣埖绋撶粣?
                //   闂?闂傚倸鍟悧鍡涘焵椤掑倶鈧妲愭导鏉戠闁瑰瓨绮嶇划锕傛煕濡厧鏋戞繛鑲╂暬瀹曟ê鈻庨幋鐐垫殸闂?**12**闂佹寧绋戦悧濠傦耿閻楀牏顩烽柟鍓ф嚀濞堜即鎮楃憴鍕殤婵炲牊鍨剁粙澶愬焵椤掑嫬纭€濠电姴绻掔粈鍡涙煥濞戞ɑ婀版俊顐犲€濋幃?*婵炴垶鎸堕崐鎾诲疾閸洘鐒鹃柤鎭掑劜绗?24**
                //      闂佹寧绋戦悧鍛礊閸℃稑缁╂い鏍ㄧ箚濞?`SWIPE_TOGGLE_VP`闂侀潧妫旂欢姘舵偟椤曗偓瀵劑顢涘☉娅猴箓鎮楀☉娆樻疁婵為棿鍗抽弻?`ldai 0x18`闂?
                //        閻熸粎澧楃敮妤呭Υ閸屾粍鏆滈柟闂寸濞呫倝鎮?`MiniMorph濠电偞鎸稿鍫曟偂鐎ｎ喖妫橀梺顐ｇ〒閻熴垹顪冮妶鍫熺【缂併劍濞婂鍊熺疀閺冨洨鐛ラ梺绋跨箞閸庨亶宕ｉ弴鐑嗗殨?md:171` 婵炴垶姊婚崰鎰?`SWIPE_TOGGLE_VP | 24`闂佹寧绋戦ˇ顓㈠焵?
                //      闂佸疇娉曟刊瀵哥箔?12 婵犮垽顤傛禍婊堫敊閹版澘鍙婇柟鎹愵嚃閸ゆ牠鎮峰▎娆掝吅缂佽鲸鐟╁鐢割敆閳ь剟鎯囨导鏉戝強?`parallelGesture`闂佹寧绋戦張顒勬偤閺囩姵瀚氱€广儱瀚杈┾偓鍨閸嬫挸鈽夐幘绛规敾閻庢艾顑囨禍鎼佸础閻戝棙顎?12vp闂佹寧绋戦ˇ顓㈠焵?
                //   闂?婵炴垶鎸搁敃銉у垝閿曞倹鐒介柨婵嗗椤忛亶鏌￠埀顒勵敍濮橆叀鍚梺鍝勫暟婵兘寮查锔界厒?*闁?`entryAllowsManual` 闂?*闂佹寧绋戦惌渚€鍩€?
                //      `entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`闂?
                //      婵帗绋掗…鍫ヮ敇鐠囧樊娴栭柨婵嗘绗?**AUTO**闂佹寧绋戝濉媦ricEntryMode` 4 濠碘剝顨愮紞鍥╂閻фォF0/AUTO1/MANUAL2/BOTH3闂?
                //      闁?`濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁割煈鍋夐惂渚€鎮橀悙鎻掆偓鎼佹儍濠靛顥堟い顐幘閻熴垺鎱ㄥ┑鍡氬闁诡喗娲滈埀顒冾潐濮樸劑鈥?md` 闁?闂佹寧绋戦ˇ顐﹀闯?**婵帗绋掗…鍫ヮ敇鐠囧樊娴栭柨婵嗗閻熸挸鈽夐幘绛规敾缂侇噯闄勭粋鎺楀焵椤掍胶鈻曢柛顐犲劚閸樻潙鈽夐幘宕囆㈠ù?*闂?
                //      闂佸搫鐗滈崗娑氬垝閵娿儮鏌﹂柍鈺佸暞缁犳帡寮堕埡鍌滄噥闂佸弶绮撻幃浠嬪Ω閿曗偓閻撴洟鎮规担绋库挃闁?闂?闂佸憡鐟禍锝夊礂濮椻偓瀹?*婵帗绋掗…鍫ヮ敇?*闁荤偞绋戞總鏃傛嫻閻斿吋鏅柛顐秵濞?`LYRIC_SWIPE_ALLOWS_MANUAL`闂佹寧绋戦ˇ顓㈠焵?
                //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁鍡欏垝閿曞倹鐒介柨婵嗗椤忛亶鏌￠埀顒勵敍濮橆叀鍚梺鍝勫暟婵兘寮查锔界厒?*濠电偛澶囬崜婵嗭耿娓氣偓濮?* 闂?闂佺懓鐡ㄩ崹鍐差煥閹达箑绫嶉柣妯挎珪閽傚霉閻樿櫕鏋勭紒缁樺哺閹儳鈻庡▎鎴狀槱`showChrome` + 闁荤姍鍛効妞ゆ挻鎮傚顔炬媼閸︻厾顦梺?
                .parallelGesture(PanGesture({ direction: PanDirection.Vertical })
                  .onActionUpdate((event: GestureEvent): void => {
                    // 照搬无界 `PlayerPage.onLyricSwipe(offsetY)`（`_recover/disasm/wujie.pa:174643-174689`）：
                    //   174644-174649  ldlexvar SWIPE_TOGGLE_VP / `neg 0x0` / `lesseq` ⇒ 判 `offsetY <= -SWIPE_TOGGLE_VP`
                    //   174650-174676  成立 ⇒ `if (entryAllowsManual(this.lyricImmersive)) { hideChrome(); clearIdle(); }`
                    //                  （`jmp jump_label_4` 直接跳走 ⇒ 这一支**不**再判下滑阈值）
                    //   174677-174686  不成立 ⇒ 再判 `offsetY >= 24`（174678 `ldai 0x18`）⇒ `{ showChrome(); startIdle(); }`
                    // ⚠️ 两侧阈值**不同号**：上滑 ≤ **-24**、下滑 ≥ **+24**（同一个 `SWIPE_TOGGLE_VP`，见 `:1009`）。
                    // ⚠️ 上游的 `clearIdle()` 本仓已并进 `hideChrome()`（它开头就 `stopChromeAutoHide()`）；
                    //    上游的 `startIdle()` 并进 `touchChrome()`（= `showChrome()` + `scheduleChromeAutoHide()`）。
                    if (event.offsetY <= -PlaybackPage.SWIPE_TOGGLE_VP) {
                      if (this.entryAllowsManual(PlaybackPage.LYRIC_IMMERSIVE_MODE)) {
                        this.hideChrome('lyricSwipeUp');
                      }
                    } else if (event.offsetY >= PlaybackPage.SWIPE_TOGGLE_VP) {
                      this.touchChrome('lyricSwipeDown');
                    }
                  }))
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.margin_lyric')
                })
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding'),
                  // 闂佸疇妫勯幊澶娢?A2闂?*闂佸湱顭堥ˇ鎵嫚閻愬吀娌柛灞剧箥閸炪劌霉?*闂佹寧绋戦悧蹇涙偤閹寸偟顩烽梺鍨儐閿熴儵鏌ｉ敐鍛伇婵?`lyricPadTop()`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
                  //   闁荤姳璁查弲婊堟偤閺囩姵瀚氱€广儱妫崝鈧梺鍝勫€稿ú锝囩箔婢舵劖鐓㈤悹鍥ㄥ絻閻撳倸顪冮妶鍛煟闁稿孩鎸抽弻鍥晲閸涱垳鍊為柣蹇撶箣缁舵艾顭?+ 濠殿喗绻傞懟顖炲箖閺囩伝褰掝敊閼测晜鍕鹃柟鐓庣摠濞叉垹绮崨鏉懳?
                  //   `lyricPadTop()` 闂佺厧顨庢禍婊呮崲娴ｅ湱鈹嶆繝闈涳功濡?濠电偞鎯岄崰鏍儑閻楀牏鈻旂€广儱鎳庣拋鏌ユ煟椤剙濡芥俊鐐插€瑰濠氬棘閹稿海顦?0"闂佹寧绋戝?lyricFloat 闂?0`闂佹寧绋戦¨鈧紒?
                  //   闂佸湱顣介崑鎾趁归悩顔煎姤缂佺粯鐗犲?padding 闂侀潻璐熼崝宀勵敊閺冨倷娌?/ 闁诲繐绻嬬欢姘焽閻楀牊浜ゆ俊顖濆吹濮婇箖姊洪幓鎺旂闁糕晛鐭傚顕€寮甸悽鐢垫喛闂佽　鍋撻柣鐔告緲琚熼梺?*闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯夸含椤忛亶鏌?*闂?
                  //   闂佸疇娉曟刊瀵哥箔?闂佸憡鐟禍婊勬叏閳哄懏鍋╂繛鍡樺灦椤忋倝鏌?*濠殿喗绻傞惌渚€鎯佸┑瀣闁告侗鍙庨崯鍥р槈閹绢垰浜炬繛鎴炴惄娴滄粓鎮鸿缁嬪顓奸崱妯绘瘔**闂?
                  top: this.expandState.lyricPadTop()
                })
                // 濠殿喗绻傞惌渚€鎯佸┑鍫滄勃闁绘劖澹嗛懝?闂佸憡鍔曢幊搴敊?闂佹寧绋掗悺鐚歰ntentOpacity`闂佹寧绋戦悧鎰板箚閵堝棙濯寸€广儱妫楅·鍛磽?1闂?
                .opacity(this.expandState.morphContentOpacity)
              }
              .layoutWeight(1)
              .indicator(
                new DotIndicator()
                  .top($r('app.float.options_padding'))
                  .selectedColor($r('app.color.select_swiper'))
                  .color($r('app.color.slider_track'))
              )
              .clip(false)
              .loop(false)
              // 闂佺补鍋?2026-10-16闂?*闂侀€涘嫎閸婃洖煤閺嶎厼绠ｉ柟瀛樼矌閻熸劕鈽夐幘顖氫壕闁哄鍎愰崰鏍ㄦ叏閻愮儤鍎?`.index()` 缂傚倷鐒﹂崹鐢告偩?*闂佹寧绋戦¨鈧紒?
              //   婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏃囨閻忓鏌?`.index(this.playbackSwiperIndex)` 闂佸搫瀚烽崹閬嶅礂?闂佺娉涢敃锔芥叏閹间礁绠戝ù锝囨嚀婢跺秹鏌涢幒鎾愁€滄い顐㈩儔瀹曞爼宕ｉ妷褏鎲?闂?
              //   婵?*闂佸搫鍟版慨鐑藉疾椤愶箑鍐€閻熸瑥瀚幏鍗炩槈閹惧磭啸缂佺粯鐗楃粙濠囧醇濠靛懐椹?*闂佹寧绋掗懝楣冩偩閻樼粯鍎?`swiperProgress` 闂?`onContentDidScroll`
              //   闂備緡鍋呴崝鏇㈠箮濮樿泛绀冩繛鍡楃М閸嬫挻绋婇·绁匔hange` **婵炴垶鎸哥粔鎾疮?*闁诲海鎳撻崰娑氭濞嗘帇浜归柟鐑樻尪閳ь剙鍊婚埀顒冾潐濮樸劑鈥?闁?.2 闂備緡鍋呴崝鏍ь焽椤栨壕鍋撳☉娆樻畽濠碘槅鍙冮幆宥嗙瑹婵犲嫮鐛?
              //   闂侀潧妫楅悾鐟?4*^1*#^1`闂佹寧绋戝濉穘Change`闂佹寧绋戦?90080-190110闂?*婵炴垶鎸哥粔鎾疮?* `swiperProgress`闂侀潧妫楃粙鍕濮樿泛违?
              //   闂?`.index()` 婵?闂備緡鍋呴崝鏇㈠箮濮樿泛绀?progress"闂佽　鍋撻柟顖嗗嫯鍚繛鎴炴尨閸嬫捇鎮硅濞撳湱妲愰悧鍫㈩洸闁圭儤姊圭粊鏌ユ煙閸偅灏伴柣蹇ョ畵閺?
              //   `Swiper` 闂佹眹鍔岀€氼參寮抽敐鍡愪簻闂傚牊绋戦悗濂告煙楠炲灝鐏繝鈧导瀵稿彆妞ゆ劧绱曠粣?*缂傚倸鐗婂Σ鎺旀崲?* index 0 闂佸綊娼х粔鎾春?1闂佹寧绋戦惌浣衡偓?index 闁荤偞鍑归崑鍡欏垝閿旈敮鍋撶憴鍕婵?0闂?
              //   swiper 婵炴潙鍚嬫穱娲綖閿曞倸绠柦妯侯槹缁€鈧梺?闂?闂佹椿娼块崝宥夊春濞戙垹鍐€閻熸瑥瀚幏閬嶆煕閹烘垶鐭楃紒妤€顦靛畷姘舵偋閸垺鎲欓柣鐘叉搐缁夊綊濡存径鎰?
              //   闂?闂佽　鍋撻柣鐔哄缁€鈧?**婵炴垶鎸哥粔鍓佸垝閿旈敮鍋?index闂佹寧绋戦張顒勫极婵傚憡鍋?`onContentDidScroll` 婵＄偟鎳撳畷顒佹叏?*"闂佹寧绋戦悧鎰帮綖閸℃鈻旈悗锝庡枟濡椼劑姊洪銊хɑ妞ゆ柨鐭傞弫宥嗗緞閸艾浜?
              //
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦鍠氱粻濠氬箹鏉堥箖妾紒?* 闂佺偨鍎查弻锟犲焵?婵?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闂傚牊绋撳▓閬嶆⒒閸稑鐏柣銉ユ嚇瀹曪絽螣閾忚鐦?闂佹眹鍔岀€氼參鎮ч幘顔芥櫖?
              // ---------------------------------------------------------------
              // 闂佸憡鍨甸幖顐λ囬埡鍛櫖婵﹩鍓涚粔鐑樹繆濡ゅ鍒伴柣锝呭⒔缁?`_recover/logic-src/濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁割煈鍋夐惂渚€鎮橀悙鎻掆偓鎼佹儍濠靛顥堟い顐幘閻熴垺鎱ㄥ┑鍡氬闁诡喗娲滈埀顒冾潐濮樸劑鈥?md` 闁?.2
              //   闂佹寧绋戦悧鎾诲焵椤掍礁濮堟繛纰卞灣閳ь剚绋掗〃澶嬩繆椤撱垺鍎?L189489-189540 缂傚倷鐒﹂崹鐢告偩妤ｅ啯鍊?+ L190026-190075 婵犮垼娉涚€氼噣骞冩繝鍥ч棷妞ゎ厽甯炵粈?
              // 闁诲氦顫夎摫闁?SDK闂佹寧绋戝濉粀iper.d.ts:onContentDidScroll`闂佹寧绋戦悺鎭爄nce 12闂佹寧绋戦¨鈧紒?
              //   "During page scrolling, the ContentDidScrollCallback callback is invoked
              //    for all pages in the viewport **on a frame-by-frame basis**."
              //   `(selectedIndex, index, position, mainAxisLength)`
              //     閻?`selectedIndex` = 闂佸憡鏌ｉ崝搴ㄥ极閹屽殨闁逞屽墯閹便劎鈧綆浜滈·鍛存⒑椤愩埄妲烽柤鍨灴閹啴宕熼妯峰亾?
              //     閻?`index`         = **閻熸粎澧楅幐鍛婃櫠閻樼偨浜?*
              //     閻?`position`      = 闂佸憡鍔曢幊搴敊閹扮増鍎庣紒瀣儥閸ょ姴鈽夐幘瀛橆潡闂佹媽浜幐褎顦版惔鈥插寲闂佹眹鍔岀€氼喕绨洪梺鍛婃煟閸斿秹鎯侀鐣岀懝?
              //
              // 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亽濡查亶鏌ｉ悙鍙夘棞婵炲懏甯炵划鍨緞婢跺苯绠氶柣搴℃贡閸嬬喖鐛崶顒佹櫖闁割偁鍎崑鎾诲箛椤撶喕鎷梺缁樻寙閸曨倠锟犳煥濞戞瀚伴柟?闂佸憡鐟禍婊冿耿椤忓懐鈻旈柍褜鍓氱粭鐔活槻缂傚秴锕ョ粙澶愬焵椤掑嫬绀?闁哄鏅滈悷锕€顭囬鐐茬闁规儼濮ら弳娑㈡偣娴ｇ懓绀冩い鎾存倐閺佸秵寰勫☉姘辩崶
              // ```ts
              //   let p = position;
              //   if (index === 0) {              // 闂?闂佸憡鐟禍婊冿耿?閻熸粎澧楅幐鍛婃櫠閻樼偨浜滈柛顭戝亝绗戦梺鍦檸閸樹粙寮担骞夸簻?闁哄鏅滈悷銈囩博鐎涙鐟圭憸宥囩礊婵犲啰鈻旈柍褜鍓熷畷?
              //     if (p < 0) { p = -p; }        //    閻庡灚澹嬮崑鎾绘煕閹惧磭校缂侇噯绠撳?position 婵炴垶鎹囩紓姘辩矆?闂?缂傚倸鐗忕划顖烆敆?
              //     if (p > 1) { p = 1; }         //    婵炴垶鎸搁敃銈夊Φ濞嗘挸绀?1
              //     this.swiperProgress = p;
              //   }
              // ```
              //   闂?**闂佸憡鑹炬绋跨暦閹邦兘鏋旂痪鏉款槺缁€鍕叏濠靛棛鐒烽柣锔界箖閵囧嫰鎮界粙澶哥凹婵炴垶鎸撮崑鎾炽€掑鈧鍥╊槴婵烇絽娲︾换鍐偓鍨⒐缁嬪绻濇担渚紘濠电偛妫寸槐鏇炩枔閹达箑纾?* 闂?**闂佺顑嗙划灞斤耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊曢悘姘渻?`p` 闂佽鍘界敮濠勬嫻?1**闂?
              //   闁哄鏅滈悷锕傤敆濠婂牆鍙婃い鏍ㄧ☉閻忓霉閻欌偓閸忔稓绮╅幘顔藉剮閻庣數顭堢换渚€鏌ｉ妸銉ヮ伃闁稿鎳忕粙澶愵敂閸繃顏￠梺鎸庣⊕閼归箖鎮?*婵炴垶鎸哥粔宕囨妞嬪孩灏?闂佸憡鐟﹂崹褰掑极閹惧瓨浜ら柛銉椤忚鲸绻涢崱顓犵？闁轰降鍊濋獮瀣煥鐎ｎ剚瀚ч梺?**闂佺偨鍎查弻锟犲焵?
              //   闂佸憡鐟禍锝夈€呴敂濮愪簻闁汇垹鎲″銊╂煟椤忓棗鏋旀繛鍫熷灴瀹曟岸宕堕鍡欑暫闂佸憡顭堥濠勮姳閿熺姵鏅悗鐟板父ndex` 闁诲繐绻愯ぐ澶屾娴兼潙鐭楁俊顖濐嚙閻?0/1闂侀潧妫斿姊 闁诲繐绻愯ぐ澶屾娴兼潙绀?1闂?
              //
              // 闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡楁捣椤忓崬銆掑鈧崨顔炬殸闂佽浜介崕鑼兜閸洘鏅?*闂佸憡鑹炬總鏃傜博鐎涙顩烽柛濠勫櫏閸ゆ柨鈽夐弬娆炬缂佽鲸绻堝畷妯衡枎韫囨挾鍘?`lyricMorphT` 婵?*闂佹寧绋戦¨鈧紒?
              //   `lyricMorphT` 闁诲繐绻楁ご绋课ｉ幖浣稿珘妞ゆ垼娉曞▔銏ゆ煟?`swiperProgress` 缂備焦绋戦ˇ顕€鎮抽鐐村亱闁冲搫顑囩粈? = 闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏☆問娴?/ 1 = 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垺顔栨导鍌炴煥濞戞﹩妾х紒?
              //   闂佸湱顣介崑鎾趁归悩顔煎姢婵炴彃娼￠獮鎺楀Ψ閿曗偓鎯熼悷婊呭鐢﹦绮╅幘顔肩闁哄诞鍕偓鐢告煟?`p` 闂佸摜濮撮崐鑽ゅ垝閹殿喒鍋撻悷鏉挎灕缂侀亶浜跺畷妯侯吋閸ャ劍娈?`syncLyricMorphToPage()` 闁荤姵鍔楅崰鏇㈡儗?
              //   "闂佸搫鐗冮崑鎾剁磽娴ｅ摜澧︽繛绗哄€曢～銏ゅ閵忊晙绱撻梺缁樺姉閹虫挾鎹㈤埀顒€顪冮妶鍫濆惞闁烩剝鍨剁粋宥嗘償閿涘嫮歇闂佸憡鎸哥粔褰掑Υ婢跺备鍋撻悽鍨殌缂併劍鐓￠幆鍐礋椤撗傜磽闂?闂佹寧绋戦悧鎰枖閺囩喐浜?0.5 闂佸搫鍟崕鑹版＂婵炴垶鎸撮崑鎾寸箾閸″繑顫夌紒杈ㄥ哺婵?
              .onContentDidScroll((selectedIndex: number, index: number,
                position: number, _mainAxisLength: number): void => {
                this.onSwiperContentDidScroll(selectedIndex, index, position);
              })
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`onLyricInteract` 闂佺偨鍎查弻锟犲焵?濠殿喗绻傞惌渚€鎯佸┑瀣?*闁荤喐鐟遍梽鍕箠?*闁诲繐绻樻禍鍫曞闯閸濄儳纾炬い鏃堟暜閺佸嫰姊婚崒婵嗚敿妞ゆ挻鎮傚顔炬媼閸︻厾顦?
              //
              // 闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗椤忓崬銆掑鈧鍥╊槱`_recover/logic-src/PlayerPage.abc.txt:6914-6932`闂佹寧绋戦¨鈧紒?
              // ```ts
              //   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
              // ```
              // 闂佸湱顭堥崐钘壝归崶顒佸€烽柣鐔哄闊剟鏌涘顒佹拱闁哄鍟粋?`190116-190130`闂?*`TouchType.Down`** 闂佸綊娼х粔鐑芥儍閻斿吋鏅柛顐ｇ矌閻熸繈鏌?Move/Up闂佹寧绋戦ˇ顓㈠焵?
              // 闂佸疇娉曟刊瀵哥箔?闂佺绻戞繛濠囧极椤撶儐鍟呮い鏃傚帶閻掑ジ鏌ㄥ☉娆掑闁?*闂?* `startIdle()`闂?*婵?* `showChrome()`
              //   闂?闂佸湱顣介崑鎾趁归悩顔煎姤缂佺粯鐗犻弻宀€浠﹂懖鈺冩**婵炴垶鎸哥粔鐑藉礂?*闂?`touchChrome()`闂佹寧绋戦悧鎾诲磻閸涱喚鈻旀い蹇撳暟缁愭顪冮妶鍥у妺濠⒀勭矒楠炲孩绻濋崘銊ょ帛闂佸憡甯熷▔娑氫焊椤栫偛鑸归柕鍫濇噹濮ｅ鏌℃径鍫濆姷缂佽鲸宀告俊?
              // 闂佸疇娉曟刊瀵哥箔?闂佸湱顭堥崐钘壝归崶顒佸€风憸鐗堝坊閸嬫挻寰勬繝鍐惈 `Swiper` 闂佸吋婢樻總鏃傜箔婢舵劕鍙?濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垻顭堟禍婵嗏槈閹绢垰浜惧┑鈽嗗亰濞佳囨偤濞嗘挸鍐€?闂佹寧绋掔喊宥咃耿閻楀牏顩?`scheduleChromeAutoHide()`
              //   闂佸憡鍔曢幊姗€宕曠€涙ɑ浜ゆ俊顖滅帛缁?`canHideLyricChrome()`闂?*闂佸憡鐟禍婊冿耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊曢崥鈧悹鎰枛閹?*闂佹寧绋戦ˇ宕囨崲閺嶎厽鐒奸柟鍓х帛閿?
              //   闂?闂侀潻璐熼崝宀勬儍濠靛顥堥柕蹇嬪€戦埀顒€顦遍幉鎾晜閼恒儱娈濋梺鍛婎殔閸樻牗绻涢崶鈺傚皫闁炬艾鍊婚崯濠囨偣娴ｆ彃澧叉俊鐐插€垮畷鎶藉Ω閵堝洨妲?*婵炴垶鎸哥粔宕囨?*闂佽　鍋撻柟顖滃瀹曞啿霉閻樹警鍞虹紓宥呯У缁嬪顭ㄩ崱鎰痪
              //   闂?婵炴垶鎸哥€涒晛螞閵堝鍋?闂佸憡鐟禍婊冿耿椤忓嫷娼扮€光偓閸愵亝袚婵＄偑鍊曢悘姘扁偓?**闁荤偞绋戞總鏃傛嫻閻旇櫣椹冲璺侯槺楠?*闂佹寧绋戦悧鍡涙儍椤栫偛绠伴柡宥忓椤忛亶鎮橀悙鎻掆偓鎼佹偤濞嗘挸鍐€闁瑰濮甸悾閬嶆倶閻愰潧浠﹂柍褜鍎搁崶銊﹀殤闂佹寧绋戦ˇ顓㈠焵?
              // 闂佸疇娉曟刊瀵哥箔?`.onTouch` 闂佸憡鐟禍锝夛綖閸モ斁鍋撻悽闈涙瀭闁?*婵炴垶鎸哥粔鐢电矓妞嬪孩瀚?*婵炲瓨绮岄鍕枎?闂?婵炴垶鎸哥粔瀛樼附閺嶎厼浼?Swiper 闂佺厧顨庢禍婊呮崲娓氣偓閹啴宕熼鍌涘闂佸憡鏌ｉ崝濠囧焵?
              .onTouch((event: TouchEvent): void => {
                if (event.type !== TouchType.Down) {
                  return;
                }
                this.onLyricInteract();
              })
              // 闂?闂佺儵鏅╅崰妤呮偉?闂?闂?*闂佸憡甯掑Λ娆撳极椤旇￥浜归柟鐑樺灩濞硷綁鎮归崶褝鏀婚柡?*闂佹寧绋戦悧濠冩櫠濠婂牆瀚夐柣鎴炆戦弳婊堟煥濞戞﹩妲撮柍褜鍓氶弻锟犲焵?闁?`logBranchSurface()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电偛绨遍崑?
              //   闂佸湱顭堥崐绋匡耿?`Swiper`闂佹寧绋戦悧鍡涙偩閻樿鐭楁い蹇撳閹界娀鏌涢敂鍝勫缂侇煈鍓熼獮宥団偓锝庡亝缁ㄦ岸寮堕埡鍌滄噥缂佹梹鎸冲銊╊敍閵堝洨顦梺?`.onAppear()` 婵炴垶鎸搁…顓犳?
              //   闂佸疇娉曟刊瀵哥箔?闂佸湱顭堥崐绋匡耿?`@Builder` 婵炶揪绲鹃幑鍥闯闁垮顕辨慨妯夸含濡炰粙鎮归崶銊ョ仸濠殿喓鍊濋弻銊モ枎濞嗘垹顦ーdoes not meet UI component syntax`闂佹寧绋戦張顒€锕㈤悧鍫熷妞ゆ棁鍋愰弶鑺ョ箾閺夋埈鍎滅紒杈ㄥ哺婵?
              .onAppear((): void => {
                this.logBranchSurface('phone');
              })
              // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯?*婵炴垶鎸哥粔鎾疮閳?*缂傚倷鐒﹂悷锕傚汲閿濆棛鈻?Swiper 闂?`contentOpacity`闂佹寧绋掔喊宥団偓鍨矒瀹曪絽顓奸崶鈺傘仢闁荤姴娲﹂崺濠勬濠靛鐭楁い蹇撴噺缁?
              //    **闁诲繐绻嬬欢姘焽?濠殿喗绻傞惌渚€鎯?*闂?闂佽В鍋撻柟瀛樺笧缁夋挳鏌熼棃娑毿㈤柛銈庡弮閹?闂佹眹鍔岀€氼剟宕€电硶鍋撻崷顓燁仧缂佽鲸绻堥幊?*濠殿喗绻傞懟顖炲箖?濠殿喗绻傞張顒佹櫠濠婂牊鐒介柨婵嗗椤忛亶鎮?*闁诲繒鍋熼崑妯艰姳椤掍降浜滈柤鍝ユ暩閸╁姊洪銊у缂佹梹娼欓々?
              //    闂佹寧绋戝濉竨llChromeOpacity` 0.18闂?.62闂佹寧绋戦¨鈧紒杈ㄧ箘閹茬増鎷呴崨濠呭惈闂佸憡鏌ｉ崝搴ㄥ极閻愵剚浜ら柛銉㈡杹閺屻倝姊洪幓鎺曞婵ǜ鍔岃彁闁炽儱鍟垮鎶芥煏?
              //    闂佸湱顣介崑鎾趁归悩顔煎姎闁搞劌娴烽惀顏囶槺缂佹鎳愮划鏃€瀵煎▎鎴犵崶闁诲繐绻嬬欢姘焽?闂?MusicPlayInfoBlock 闂佺厧顨庢禍婊呮崲娴ｇ儤鏆滈柨鏃囧亹楠?
              //    濠殿喗绻傞惌渚€鎯?闂?闂佸憡鑹剧€氼垶宕靛鍫熺劷闁挎繂瀚埛鍫澝?LyricsComponent闂佹寧绋掔粙鎴︽儍椤掆偓椤垹鐣濋崘顏呅?闂?MiniLyricLinesComponent闂?
              .onAnimationStart((index: number, targetIndex: number, _event: SwiperAnimationEvent): void => {
                // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闁哄鏅滈悷鈺呭闯闁垮鈻旂€广儱鎳庨弲娆忣渻閻熸澘鑸瑰┑?`lyricMorphT`** 闂佺偨鍎查弻锟犲焵?婵＄偟鎳撳畷顒佹叏閳哄懎绾ч柛鎰╁妼閸ゆ帒霉濠у灝鈧鍒?
                //   `onContentDidScroll`闂佹寧绋戦惌渚€锝為崱娑樺珘?`Swiper` 婵炴垶鎸搁敃銉╁蓟閻斿吋鐒介柨婵嗘－閸炰粙姊婚埀顒勫箰鎼淬垺娈橀梻浣瑰絻椤厾妲愬璺何?
                //   闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鎮?`animateLyricMorph(...)`闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎮鹃悩鍨殰闁挎洍鍋撻柣锛卞洤纭€?
                //   闂侀潧妫楅悾鐠眓dex === targetIndex` 闂?闁荤姴鎼悿鍥╂崲閸愵喖违鐎广儰绀佸▍?闂佸憡鐟禍锝夈€呴敃鍌氱闁搞儺鍏欓埀顒€顦扮粙澶婎吋閸℃?婵炴垶鎸撮崑鎾寸箾閸☆厾纾挎繝鈧垾鎰佺叆闁瑰瓨绻傝"
                //   闂佹寧绋戦悧蹇涘煝閸忓吋鍎熼煫鍥ㄦ尭椤曆囨煕閹烘垶鍠橀柕?/ 闂備焦褰冪粔鐢碘偓鍨礃濞碱亪鎸婃径濠勪淮婵犳鍠栭澶愬Υ婢跺鈻旂€广儱妫欑瑧 0闂佹寧绋戦¨鈧紒杈ㄧ箞瀵偊寮堕幋顓燁唶婵＄偛顑囬崑鐘汇€?*濠殿喗蓱閻℃洜鎹㈠▎鎰枖鐎广儱鎳忛崕娆撴煕?*闂?
                //   闂?闂佺粯绮嶅妯猴耿椤忓懏浜ゆ繛鍡樻尭濞咃繝鏌涘▎妯圭盎濞?*闁荤姴娲ら敃銉╁蓟閸モ晜濯奸柍鈺佸暞濞?*闂佹寧绋戦悧鍛崲濮樿埖鍋╂繛鍡樺焾閸庢垿鏌涜箛锝呬函妞?`ast=` / `skp=`闂佹寧绋戞總鏃€绂嶉幒鎾剁懝闁割煈鍣崵鐘虫叏閿濆棙鈷愰柡灞斤躬瀵喛顦舵い銏″灦缁嬪鎮€靛摜顦梺?
                //     闂佺儵鏅犻弲鑼礊閸涱喚鈻旈幖娣€楃粻濠氬箹鏉堝墽绱扮紒鏃€娼欓銉р偓锝庡墯閺?`onSwiperContentDidScroll()` 闂佸憡鍔曢崯鍧楁偩妤ｅ啫违?
                //   闂佸疇娉曟刊瀵哥箔?婵烇絽娲︾换鍕汲閳ь剟寮堕埡鍌滄噭妞ゆ柨鐭傚浼搭敍濞戞瑧鐣抽梺瑙勬緲缁绘帒鈻撻幋锔芥櫖婵﹩鍋嗛璇测槈閹绢垰浜?`onContentDidScroll` 闂侀潻璐熼崝宥夋偂閸ャ劎顩叉繛鎴炵懄缁ㄦ岸鏌涢妸銉剮缂佹鍊圭粙澶婎吋閸╂寧娲熷畷锝夊箣椤栨粎顦?
                //      缂備焦顨忛崜娆撳矗閹捐埖鍋樼€光偓閳ь剙鈻?`ast=0-1` 闁诲繐绻楁ご绋课?濠电姴锕ラ崹鍨叏閳哄懎鐐婇柣鎰濞堝爼鎮楀☉娅亜锕㈤鍛闁糕剝姘ㄧ粻濠氬箹鏉堝墽鐣辨繛鍙夌墱閹奉偊宕樿閻熸繈鎮楀☉娅亜锕?闂佹眹鍔岀€氼垶鎯佹径鎰妞ゆ棁銆€閸?
                this.diagAnimStart = `${index}-${targetIndex}`;
                if (index === targetIndex && !this.lyricMorphVisible) {
                  this.diagAnimSkip = this.diagAnimSkip + 1;
                }
              })
              .onAnimationEnd((index: number, _event: SwiperAnimationEvent): void => {
                // 闂?A2闂佹寧绋掗悺鏀歩per 闂佺厧顨庢禍婊呮崲娓氣偓閹啴宕熼鍌涘闂佸憡鏌ｉ崝搴ｅ垝閵娾晛绾?闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥€涒晝鎷犻悙鍏告勃闁稿瞼鍎愬Λ褔鎮跺☉妯肩伇婵炲牊鍨垮銊ф崉閾忕懓鏆￠梺?*婵炴垶鎸堕崐婵單涢崼鏇炵闁斥晛鍟·?*
                //   闂佹寧绋戝濉磞ricSwiperSettled && lyricFlightSettled` 闂備緡鍠涘Λ鍕春鐏炲墽顩查柛鈩兠·鍛存煕濡も偓閹诧紕鏁埀?婵＄偛顑囬崑鐘汇€侀幋鐐碘枖?闂備緡鍙忕徊鑲╃博閺夋埈娴栭柨婵嗙箳缁€鍡涙煏?
                //   闂佸疇娉曟刊瀵哥箔?闂佽　鍋撻柣鐔告緲椤ゅ懘寮堕埡鍌滄噰闁革絿鍏樺畷锝夘敂閸涱厸鍙洪梺鍝勫暔閸庤京鎹㈤弮鍫澪?*婵炲濮寸花鑲╃箔婢跺瞼纾炬い鏃囧吹缁?`lyricSwiperSettled`** 闂?
                //   `finishLyricMorph` 濠殿喗蓱閻℃洜鎹㈠▎鎰氦婵炴垶顨堥悷婵嬫煕濡湱涓茬紒杈ㄧ懇瀵偊寮堕幋顓燁唶濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闂傚牊绋撳▓閬嶆⒒閸稑鐏╅柤闀愬嵆瀹曪絽螣缂佹锔芥叏濠靛﹤鍚规繛鍫熷灴閺佸秵寰勯崼姘壕?
                this.lyricSwiperSettled = true;
                this.finishLyricMorph(this.lyricMorphGen);
                this.diagAnimEnd = `${index}`;
                this.diagAnimEndCount = this.diagAnimEndCount + 1;
                // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佽　鍋撻悹楦挎閸熸煡鏌﹂埀顒勬寠婢跺本姣?* 闂佺偨鍎查弻锟犲焵?闂佺粯鎸嗛崟顒€鍓?`onContentDidScroll` 婵炴垶鏌ㄩ鍛村箖濡ゅ嫮鐤€闁告稒鐣埀顒€绻掗幃浼村Ψ瑜庨悾鍗炩槈閹绢垰浜惧┑顔界缚閸庤崵妲愬鑸垫櫖?
                //   `onContentDidScroll` 闂備緡鍋呴崝鏇㈠箮濮樿京纾兼繛鍡樺灦閻ｉ亶鏌?*濠殿噯绲鹃弻褏娆?*闂佹寧绋戦張顒€銆掗崼鏇炶Е閹煎瓨绻勯閬嶆偨椤栧棗瀚鎾荤叓閸パ勫櫤妞ゆ帗绮嶇缓浠嬫嚍閵壪€?0/1
                //   闂佹寧绋戦悧鍡涙偪閸曨個鍦偓锝庝簽閸╂鎮?0.997 闁哄鏅滈悷褔锝為幒妤佹櫖濠㈣埖绋撻獮銏ゆ煠?`syncLyricMorphToPage()` 婵帗绋掗…鍫ヮ敇缂佹ê顕?*闁荤姳璁查弲娆戠礊閸涱垳纾兼繛鍡樺姉濞夊﹪鏌?*
                //   闂佹寧绋戝濉朇ROLL_SETTLE_WINDOW_MS` 闂備緡鍙忕紞浣圭閸撗呯幓婵°倕顑囩粈鍡涙煥濞戞ɑ婀板褍绉电粋鎺楀Ψ閿旂偓纭﹂梺鍛婃煟閸斿绮╅幘顔肩；婵犲﹤鍟惃鎴︽偡閺囨氨鍔嶆繝鈧担鍦洸闁绘垶锚鎯?`t` 闂佽В鍋撻柦妯侯槺閺嗕即鏌涢幒鎾愁棆妞ゅ浚鍓熼幃娆撶嵁鎼存挸浜?
                //   `onAnimationEnd` 濠殿喗绻愮徊鎯?swiper 闂佺顑嗙划搴ゅ綂"闂佹眹鍔岀€氼剟鎮炬總绋挎闂侇偅绋愮换鍡涙煕濞嗗繐娈╃紒杈ㄧ懄缁嬪寮捄銊︽殧闂佸搫鐗冮崑鎾剁磽?`index`闂佹寧绋戦ˇ顓㈠焵?
                //   闂佸疇娉曟刊瀵哥箔?婵＄偑鍊曢幖顐よ姳椤撱垺鏅?*闂?*闂?`index` 婵烇絽娴傞崰妤咁敆?`playbackSwiperIndex`闂?*闂?*闂佽В鍋撻柦妯侯槺閺?
                //      闂佹寧绋戦悧鍡涘箚娓氣偓瀹?`want` 婵炴潙鍚嬪銊╁极閵堝绫嶇憸蹇涘磼閵娿儺鍤曢柡鍥╁Х閺嗩剟鏌ㄥ☉姗嗘Ф闁?
                if (index !== this.playbackSwiperIndex) {
                  this.playbackSwiperIndex = index;
                }
                this.syncLyricMorphToPage('swiperEnd');
                Logger.info('RzdLyricFloat',
                  `swiper end index=${index} gen=${this.lyricMorphGen} t=${this.lyricMorphT.toFixed(3)}`);
                // ③ 落位结束也是"切页完成"的权威事件：在这里再对齐一次 idle/chrome。
                // （`onContentDidScroll` 已不再写索引 ⇒ 索引只由 `onChange` / 这里写。）
                this.onSwiperIndexChanged(index);
              })
              .onChange((index: number): void => {
                this.diagChg = `${index}`;
                this.diagChgCount = this.diagChgCount + 1;
                this.playbackSwiperIndex = index;
                // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔界劷闁挎繂瀚伴崵?`onChange` 濞?闂佹眹鍔岀€氫即鍩€椤掍礁濮囬柣鈯欏懐纾奸柟鎯ь嚟閳?* 闂佺偨鍎查弻锟犲焵?闂佸憡顭囬崰鎰焽閻㈢鍙婃い鏍ㄧ⊕閿熴儵鏌℃径鍡忓亾閸欏鍋?`touchChrome()`闂?
                //   闂佸搫鍟版慨鐑藉疾椤愶附鏅柛褍鍨硆ecover/logic-src/PlayerPage.abc.txt:23189-23215`闂佹寧绋戦¨鈧紒?
                // ```
                //   const v = 1;
                //   if (index === v) { startIdle(); }            // 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻缁炬澘顦辩粣妤呮煕濞嗘ü娴烽柟鐧哥悼缁艾煤椤忓拑绱抽柣鐘辫閸撴繂顪?
                //   else { clearIdle(); showChrome(); }          // 闁诲繐绻嬬欢姘焽閻楀牄浜滅痪鏉款槺缁愭鏌涚€ｎ偆鐭庢い鎾存倐瀵?+ 闂佸摜鍋戦崐鏇㈠吹椤撱垹绠崇憸宥夊春濡ゅ懎绀?
                //   this.atLyricScreen = (index === v);
                // ```
                //   闂?婵炴垶鎸堕崐鎾绘煂濠婂牆绀傞柟鎯板Г閺嗘稓鈧懓澹婇崰鏍春閸℃稒鏅柛顐犲劚閸樻挳鎮跺鐓庝簼闁搞劍绮嶇粋鎺楊敆閳ь剛鏁锕€绾ч柕澶嗘櫅娴滄繈鏌?`touchChrome()` 闂佽鍎奸～澶屾暜閳ь剙霉濠婂啯锛旂紒杈ㄥ哺閺?
                //     闂?闂佸憡甯掑ú銈夊春?*濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻?*婵炴垶鎸哥粔鎾极濠婂牆绀勯柣鎴灻禒姗€鏌涢幒鏇熺【閻忓浚鍨堕弫宥夊锤閸撳檴uchChrome()` 婵炴潙鍚嬮懝楣冨极濠婂牆绀勯柣姘嚟缁€鍡涙煥?
                //     闂?闂佸憡甯掑ú銈夊春?*闁诲繐绻嬬欢姘焽閻楀牄浜?*闁?*闂佸搫瀚崕宕囨閿熺姴鑸归柕鍫濇噹濮?*濡?*闂佺顑嗙划宥囨暜閳?*缂備礁鏈钘壩涢悾灞惧闁斥晛鍟ˇ?
                //        闂佹寧绋戝濉紀uchChrome()` 闂?闂佺绻愰悧鎰板箲閿濆洦濯奸柍鈺佸暞椤ρ囨煕閹邦剛孝濞寸姷濞€楠?闂佹寧绋戦懟顖炲闯閿濆鏋侀柛顐ゅ枔娴滎垶鏌涘顒傜効缂佽鲸绻冮幏鍛村幢濡ゅ啯鐦滄繛瀛樼矊濡繈宕戦崨鏉戠骇闂勫洭顢氶姀锛勨枙濠㈣埖绋撶粈鍡涙煏?
                this.onSwiperIndexChanged(index);
              })

              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*闂佺鐭囬崘銊у幀闂佸憡鐗炲銊х箔娴ｇ硶鏋旈柣銏㈡暩濞夈垽鏌＄€ｎ亜顏繛鍫熷灦缁嬪濡堕崱娆忣棏闂佸憡顨堟慨宕囩礊閸涙潙绾?*闂?
              //   闂佸搫鍟版慨鐑藉疾?overlay 闂?`Swiper` 婵?闁哄鏅滅粙鎴犫偓瑙勫▕瀵?婵炵鍋愭慨鍓ф椤撱垹绾?婵炴垶鏌ㄩ澶娢涚捄銊ょ剨閺夊牄鍔嶇瑧闁哄鏅滈悷銈囨偖闁秴鍐€?*闂傚倸妫滃▔娑㈠船鐎电硶鍋?Row**
              //   闂佹寧绋戝澧倁jie.pa:190464` / `190497`闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪顓奸崱妯?padding闂?
              //     `[Swiper | gapSwiper 闁?| gapScrub 闁?| 闁哄鏅滅粙鎴犫偓瑙勫▕瀵?婵炵鍋愭慨鍓ф椤撱垹绾фい鈽嗘灲
              //   闂?`gapSwiper` 闁?*闁哄鏅濋崑鐔兼偨?*闂佺娴氶崜娆戞?`playerSwiperGapOf(usableH) = clamp(0.065闁煎鐗?16,56)`
              //      闂佹寧绋戝澧倁jie.pa:93497`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?**婵炴垶鎸哥粔闈浳ｉ幖浣歌摕闁靛璐熼埀顒€鍊归幏鍛吋閸稈鍋?*闂佹寧绋戦悧鎰板Υ閸愵喗鐓傜€光偓閸曨偂绨?48/32/20 闂佸憡鐟禍婊冿耿?濠电偛澶囬崜婵嗭耿娴ｈ　鍋撻崷顓炰沪缂?
              //      `usableH` 闂佸搫鍟抽崺鏍ㄦ櫠閻樼粯鍋?闂佹寧绋戦惌渚€锝?`playerChromeTotalOf` 闂佹眹鍔岀€氼亞鎮潏銊ョ窞闁告洦鍓欓悘鍥倵娴ｅ喚娼愮€规洘鐓″畷鎰兜妞嬪海顦梺?
              //   闂?`gapScrub` 闂佸搫瀚烽崹閬嶆偂閿涘嫭鍋橀柕濞垮劗閸嬫挾娑垫搴ｎ槷婵炶揪绲藉Λ娆撳垂濠婂嫮顩锋い鎺戝暟缁犵懓鈽夐幘顖氫壕婵?*閻庤鐡曠亸娆戝垝?*闂佸搫鐗嗛ˇ顖炲箖閹惧鈻旈柍褜鍓欓埢鎾绘偨閸涘绱甸柣鐘靛劋缁绘劗妲愬渚皁ntrolAreaComponent`
              //      闂?Slider 闂備緡鍙忕徊鑲╃博鐎靛憡鍋樼€光偓閳ь剙鈻?`bottom` margin闂佹寧绋戦ˇ顐﹀闯?闁哄鏅滈悷鈺呭闯妞嬪海纾?0闂佹寧绋戦惌鍌涘閳哄懎绀傜€广儱鎳忛崐鍗炩槈閹绢垰浜惧┑鐐茬墕閸氣偓閻炴岸浜跺鍫曞灳閸愯尙绋夐悗鍨緲鐎氬摜妲?
              //      闂佺绻愰悧蹇涘极閵堝绫嶉柕澶堝劤缁犲爼鏌?闁诲骸婀遍崑鐐电矈?vs `gapScrub`"闂備焦褰冪换鎰板吹椤撱垹绾ч柕澶樺灣缁€鍕偡?`chromeScrubGapRowHVp()`闂佹寧绋戦ˇ顓㈠焵?
              //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸堕崐鏍偋閹绢喗鐒鹃柤鎭掑劜绗?`Row()`闂佹寧绋戦悧鍛箔婢舵劕鍙?`Blank()`闂佹寧绋戦¨鈧紒鍙樺嵆瀵噣鎮╅崹顐ｇ彧闁诲繐绻楁ご绋课?`Row`闂佹寧绋戞總鏃傜箔閺嶎偆鐭?`Row` 闂?`Column`
              //      闂備焦褰冮張顒傗偓?`.height()` 缂備緡鍠栨晶浠嬪灳濮椻偓瀹曪繝鎮╂潏鈺冃㈤梺鎸庣☉婵傛梻绮径瀣嚤婵﹩鍓欓崜?`Blank` 闂備緡鍙忕徊楣冩偋闁秴瑙﹂柛鎰╁妼閳锋牕霉閿濆棛鎳呴柍瑙勭墵濮婅菐椤戣棄浜?
              Row() {
              }
              .id(PlaybackPage.SWIPER_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.swiperGapRowHVp())
              .hitTestBehavior(HitTestMode.None)
              // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁硅泛锕ョ敮鍫曞礆鐠哄搫闅橀柣銊ュ濠€锛勨偓鍦仒缁楀倸鈻介崸妤€娅ゅ☉鎾愁儐濞?* 闁炽儲鏌￠埀?闁哄秴娲。鐣屾偘瀹€鍕碍闁告帗鍎奸々锕傛偨閵娿儳鏆婇柨?
              //   閺夆晜鐟ょ粩鎾冀閻熺増鐨戦柡?闁硅矇鍐ㄧ厬闁告牜鍎ら婊勭▔婵犲啯鐓?闁汇劌瀚畷鐗堟媴瀹ュ棙钂?闁?閻庣懓鍟板▓鎴犵玻濡も偓瑜版稒銇勯幆鎵彾 = 闁硅矇鍐ㄧ厬闁告牞妗ㄧ粭鍌氣柦鐟併倐鍋?
              //   闁宠法濯寸粭?闊洤鎳橀妴蹇涘礃濞嗘帞绠?`@Trace`/`@Local`闁挎稒宀搁崳娲礆妫颁胶顓洪柛姘唉椤?*閻熸瑱绠戣ぐ鍌涚▔閳ь剙鈻庨敓鐘叉鐎?*闁?
              //     闁告熬绠戦崹?`metaOffsetY()` 闂佹彃鐭傞崑鍛枎閿熺姵灏柛鎺戝閺併倝鎯冮崟顒佇?閺夆晜蓱閻ュ懘鏌岃箛鎾崇厒"闁汇劌瀚崢瑙勬償閺囩喎鑵圭紒鐘愁殔閳?闁?鐟滆埇鍨归幃鎾斥柦閳ュ厖绮?
              //     闁挎稑鐗愮换鏍ь潰閿濆棙笑濞戞挸锕ｇ粩鎾偋?闂佽棄鍟块崺妤€鈻介敍鍕櫢闁?闁汇劌瀚敮顐﹀炊閻欏懐绀嗛柕?


              Row() {
              }
              .id(PlaybackPage.CHROME_SCRUB_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.chromeScrubGapRowHVp())
              .hitTestBehavior(HitTestMode.None)

              // 闂佺鐭囬崘銊у幀闂佸憡鐗滅亸銊ф娴煎瓨顥堟繛鍡樺姦閸?3 缂備礁顦扮敮鐔煎吹濠婂牆绀夐柕濠忛檮閺嗩亪鎮硅閸ゆ牜妲愬┑瀣€?缂佸彞鍗抽。锕傚箲閵忋倕绠涢煫鍥ㄦ惄濡查亶鏌涢悙顏勨偓鏇㈠吹椤撱垺鏅柛顐ｇ箥閸ょ娀鏌″鍛婵☆偁鍊濋幃鎯х暆閸曨厼寰撴繛?BarCollapse闂?
              Column() {
                Column() {
                  // 闂佸疇妫勯幊澶娢?2026-10-15 闂佹椿娼块崝宥夊春濞戞埃鍋撶憴鍕孩闁汇劎鍠栭弫宥咁潩閵夈垹浜?*闁哄鏅滅粙鎴犫偓瑙勫▕瀵爼鍨鹃搹顐㈩伅婵炴垶鎸搁澶婎焽娴煎瓨鍎嶉柛鏇ㄥ灠娴滄繈鏌涢銏☆棡閻庡灚绮撻弻锕傤敊閼姐値浼囬柣鐘欏懎鍘存い銉秮瀹?*闂侀潧妫楃粔顕€鍩€椤掍焦鐓涢柍?
                  //   闁诲海鎳撻崯鈺侇煥閹达箑鍙婃い鏍ㄧ懅椤忚京绱撴担绋款伒缂佸彉鍗冲顐も偓鐢殿焾椤ｅ鏌熺挩澶婂暙閻撴垿鏌涢弽褎鎯堟繝鈧?*闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撴噺椤ρ囨⒒閸屾凹鍤熼柣?*闂備焦褰冩總鏃傚垝閻樺磭鈻旈悗锝庝簻绾惧啿鈽夐幘绛规敾婵炶偐鏁婚弫宥夊醇閿濆孩缍?`contentRiseVp()`闂佹寧绋戦¨鈧紒?
                  //   闂佸湱顣介崑鎾趁归悩顔煎姤缂佺粯鐗犻弻?*婵炴垶鎸哥粔鎾疮閳?*缂傚倷鐒﹂悷銊ф崲濡粯鍎熼柨鏃囧Г閽傚鏌涘Δ浣圭閻庢凹鍙冮弻銊モ枎韫囨挻些闂佹寧绋戦悧鍛箔閸屾稓鈻旈柍褜鍓熼幃褔宕煎┑鍥╂闂佸搫瀚烽崹鍫曞磻閸涱喚鈻曢柛顐ｇ箑缁敻姊洪幐搴ｆ噮婵炲牊鍨块弫宥嗗緞閸艾浜?
                  ControlAreaComponent({
                    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*婵炴垶鎸哥粔鐑姐€?*闂備緡鍙忕徊鑲╃博鐎靛憡鍋?婵炴垶鎸搁鍫澝?闁荤姴娲ょ€氼垶顢?闂佸搫娲﹀娆撍?闂?
                    //   闂佸搫鍟版慨鐑藉疾椤愶附鍎?`transport` 闂佸憡鐟禍婵嗭耿?5 婵炴垶鎼╂禍椋庢娴兼潙绠绘い鎾跺枑閺夎淇婇妞诲亾瀹曞洨顢?/ 婵炴垶鎸搁敃锝囩博鐎涙﹫绱?/ 闂佸湱铏庨崢浠嬪棘娓氣偓瀵娊宕掑顐や笉 / 婵炴垶鎸搁鍕博鐎涙﹫绱?/ 闂佸湱铏庨崢浠嬪棘娓氣偓濮婂ジ鎮㈠畡鎵粴
                    //   闂佹寧绋戝濉抣ayerPage闁诲海鎳撻張顒勫汲椤ゆ杯闁诲氦顫夊銊┾€?md` 闁?.3闂佹寧绋戦惌鍌炲焵椤掍礁濮嶉柕鍡楃Ч閺屽牓鎸婃径瀣惈闂佹寧绋戦¨鈧紒?*濠电偛澶囬崜婵嗭耿娴ｈ櫣绠旀い鎴ｆ硶閻у矂鎮?*闂?
                    //   濠电偞鐓＄粻鏍偂閼搁潧绶炴慨姗嗗墮濮ｅ鏌℃径鍫濆姢婵炲牊鍨跺璇测枎鎼达綆浼囬柣鐐寸☉閼活垰锕㈤鍫濈妞ゅ繐瀚粋鍫ユ⒑閹绘帒顨欑紒鏃€鎸抽幆鍥偂鎼绰ゎ唹闁?闂?闂佺绻楀▍鏇犳暜閳ь剟鎮楅悷鏉挎殲濠⒀呭█瀵?闂佺粯鎸嗛崟顒€鍓?闂?
                    //   闂佸疇娉曟刊瀵哥箔?闂備緡鍙忕徊钘壝洪幘瀵糕枖妞ゅ繐瀚鎶芥煕濞嗘瑧绋绘繝鈧导瀵稿彆妞ゆ劧绲垮楣冩煕閹烘柨顎撶紒杈ㄧ崑ControlAreaComponent` 闂備焦褰冩總鏃傚垝濞戙垹鎹舵い顓熷笧缁€鍡涙煥?
                    //      闁荤喐娲戦悞锔界椤旇棄绶炵€广儱妫楁儫闁哄鏅滈悷鈺呭闯閻戣棄缁╅柣鐔哄缁€鈧?`true` 闂佸憡顨呴崯鑳亹閺屻儱违?
                    showBottomOtherRow: false,
                    // 闂?闂佸吋瀵х划灞界暦閻斿吋鍋愰柤鍝ヮ暯閸嬫挻鎷呯粙鍨闂佸湱绮崝鏇炵暦瀹€鍕闁绘鐗婇幏鍗烆渻閵堝浂鏆滅紒杈ㄧ懇閺屽洭鏁愰崟顓т紘濠碘槅鍨兼禍锝夈€侀幋锔藉剭闁告洍鏂侀崑鎾朵沪閻愵剛鍑芥繝銏ｅ煐閸濆酣鍩€椤掆偓缁夋潙霉濮椻偓瀵粙宕惰闊剟鏌￠崼顐㈠⒋闁靛棗顦甸弫宥嗗緞濞戞氨鐛?
                    //   `ControlAreaComponent` 婵?`@Local` 闂佽　鍋撻悷娆忓閻忓洤霉?`@Param` + `@Event`闂?
                    showMenuSheet: this.playMenuOpen,
                    onMenuSheetChange: (open: boolean): void => {
                      this.playMenuOpen = open;
                    },
                    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`hideChrome()` 闂?闂傚倸鐗勯崹鍝勵熆濡警鍤曢柍褜鍓熼幆鍫ュ焵椤掑倷鐒婇柛娆愵焽閻熸繈鏌￠埀?闁诲海鎳撻悧鍡楃暦婵傚憡鏅鑸电〒缁?
                    //   闂佸吋瀵х划灞界暦?sheet 閻庤鐡曠亸娆撳极鏉堛劎鈻斿┑鐘叉处濡椼劑姊洪銊у缂佹柨顕埀顒勬涧濠€鍗烇耿閸涱収鍤楁俊銈呭濞煎矂鏌?*闂佺绻戝﹢鍦礊閹寸偟鈻旈柕鍫濆閸ゅ鈧鍠氶幊鎾绘儑?*闂佹寧绋戦悧濠囧箰闁秴缁╁Δ锝呭暞琚濋梺?/ 闂佺绻戝﹢鍦垝椤掑嫭鍋嬮柛顐ゅ枑閹烽亶鏌?
                    //   闂侀潻璐熼崝宥咃耿閹殿喚纾奸柛鏇ㄤ簼椤愪粙鏌涢幇顒佸殗闁稿孩鎸抽弫宥囦沪缁涘鏅辨繛鎴炴崄瀹曢潧锕㈤崨顔锯枖鐎广儱鎳庨悡?闂?闂佹眹鍨肩划鍓ф崲閺嶃劎鈻旀い蹇撳缁€鈧柣鐘差儏閸燁垱鎱ㄩ妶鍡欌枖濠电姴鍟梽宥夋煥濞戞瀚伴柤鑽ゅ枑濞艰鈽夊▎鎰瘑闁荤姍鍛幋婵☆偒鍓熼弫宥夊醇閿濆孩缍?`auxSheetOpen`闂佹寧绋戦ˇ顓㈠焵?
                    onAuxSheetOpenChange: (open: boolean): void => {
                      this.auxSheetOpen = open;
                    },
                    chromeOffsetY: this.expandState.chromeOffsetY(),
                    chromeOpacity: this.expandState.chromeOpacity()
                  })
                    .width(StyleConstants.FULL_WIDTH)
                }
                .width(StyleConstants.FULL_WIDTH)
                .flexShrink(0)
                .height(this.canHideLyricChrome() && !this.lyricChromeMeasurePending &&
                  this.lyricChromeHeight > 0 ? this.lyricChromeHeight : undefined)
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding'),
                  bottom: 10
                })
                .onAreaChange((_oldArea: Area, newArea: Area): void => {
                  // Measure natural inner content only while fully expanded, never the clipping shell.
                  const width: number = Number.parseFloat(newArea.width.toString());
                  const height: number = Number.parseFloat(newArea.height.toString());
                  if (Math.abs(width - this.lyricChromeWidth) > 0.5) {
                    this.lyricChromeWidth = width;
                    // Release only inner constraint; outer retains last height during the measuring frame.
                    const wasConstrained: boolean = !this.lyricChromeMeasurePending;
                    this.lyricChromeMeasurePending = true;
                    Logger.info('RzdLyricChrome', `invalidate naturalHeight width=${width}`);
                    if (wasConstrained) {
                      return;
                    }
                  }
                  if (!this.chromeCollapsed && this.lyricChromeProgress === 1 && !this.isCollapsing() &&
                    height > 0 && (this.lyricChromeMeasurePending ||
                    Math.abs(height - this.lyricChromeHeight) > 0.5)) {
                    this.lyricChromeHeight = height;
                    this.lyricChromeMeasurePending = false;
                    Logger.info('RzdLyricChrome', `measure naturalHeight=${height}`);
                  }
                })
                .opacity(this.canHideLyricChrome() ? this.lyricChromeProgress : 1)
                .translate({ y: this.canHideLyricChrome() ? (1 - this.lyricChromeProgress) * 24 : 0 })
              }
              .width(StyleConstants.FULL_WIDTH)
              .height(this.canHideLyricChrome() && this.lyricChromeHeight > 0 ?
                this.lyricChromeHeight * this.lyricChromeProgress : undefined)
              .clip(true)
              .margin({ bottom: this.expandState.chromeOffsetY() })
              // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍡椕洪弽顓熺劵闁逞屽墴瀹曘儲鎯旈妸銉︻仧闂佺顑嗛悢顒傛濮樿埖鍋ㄩ柕濠忕畱閻撴洟鎮楃憴鍕孩闁汇劎鍠栭弫宥咁潩閵夈垹浜?*婵炴垶鎸哥粔鐑姐€呴敃鈧彁闁炽儱鍟垮铏箾閿濆倵鍋撻崘鍙夌様**闂侀潧妫楃粔顕€鍩€椤掍焦鐓涢柍?
              //   闂佺鐭囬崘銊у幀闂佸憡鐗炲銊х箔婢舵劕绀冪€广儱顦板ù鍡涙⒑椤愩垻绠叉俊鍙夊灦閹棃鏁冮埀顒勫吹椤撱垹鎹堕柣姘嚟缁€鍕煕濡厧鏋戞繛鐓庣仛濞艰鈻庨幘铏仦闂?`.opacity(pullBottomIn())`闂佹寧绋戦¨鈧紒?
              //   闂佽　鍋撻悷娆忓閻?*婵炲濮寸花鑲╃箔閸涙潙纭€闁搞儺浜濆畷鎶芥煟閵娿儱顏х紓宥呮噽缁?*闂佹寧绋掔喊宥夊汲閿濆鍋嬮柛銉ｅ妼娴犳﹢鏌涢幒鏇熺【閻忓浚鍨跺畷鐑藉Ω閵娿儲顔囬悗瑙勭摃娴滎剙鈻撻幋锕€绫嶉柛顐ｆ礃閿涚喓绱掗幇顓ф當闁哥偛鐡ㄧ粋鎺撴償濠靛牏鎲梺?180vp 闂佸憡顨呭ú銈夊春鐏炵偓濯寸€广儱绻掔粈?
              //   婵炴垶鎸堕崐妤冨垝瀹ュ鍎嶉柛鏇ㄥ亜鐢儵鏌涘顒佸攭妞?PlaybackPage 婵＄偑鍊曢悥濂稿磿閹绢喗鍎?`WIN_A_*` / `WIN_B_*` 闁荤姴娲ら悺銊ノｉ幋锕€违?
              //   闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夘棑缁夊绱掓径宀€甯涘ù?0闂佹寧绋戝濉祇rphClipping()` 婵炴垶鎸搁幖顐ｇ閿濆绫嶉柛鎾茬劍缁绢垶鏌熼幁鎺戝姤缂佺粯鍨垮畷?0闂佹寧绋戦ˇ顐﹀闯?闂佺粯顨呴悧鎾愁焽娴煎瓨鐒婚柟閭﹀墮閸撹偐绱掓潏鈺佇＄紒妤€顦靛畷锝呂熺化鏇炰壕?
              // ★★★ 2026-10-17（修「关闭播放页时传输行两颗图标下移一点点」——**时间线**那条，不是静态对齐）
              //   上游把这一对**挂在底栏自己身上**（取的是同一个式子）：
              //     · scrubber  `Column().translate({y: pullBottomY()}) .opacity(pullBottomOpacity())`
              //       —— `wujie.pa:197161` / `197172`
              //     · transport `Row().translate({y: pullBottomY()}) .opacity(pullBottomOpacity())`
              //       —— `wujie.pa:181213` / `181224`
              //   本仓这一层同时盖住进度条与传输行 ⇒ 挂一次即等价。
              //   `pullBottomY = pullMode ? 200 × (1 − pullBottomIn()) : 0`（`wujie.pa:176430-176470`），
              //   `pullBottomIn = clamp01((effT−0.45)/0.55)`（`wujie.pa:176377-176410`）。
              //   ⛔ 旧实现用 `contentRiseVp()` = `(1−w) × 180 / morphScale`：**除以 scale** 使得屏幕上
              //      恒为 180vp、不随卡片收缩 ⇒ 收起来时整排相对卡片底部一路下沉（上游是 200×scale）。
              //   ⚠️ `pullBottomOpacity()`（`wujie.pa:176411-176429`）原来**没接**（旧注释的理由是
              //      "用户要求关闭期间这两颗一直在"）—— 2026-10-18 已按上游接上，见紧接的下一行。
              .translate({ y: this.expandState.pullBottomYVp() })
              // ★★★ 2026-10-18（修「下面那行控制飞入时间还是不对」）：**接上上游的 `pullBottomOpacity()`**
              //   上游把这一对挂在**同一个节点**上，取的是同一个式子：
              //     · scrubber  `Column().translate({y: pullBottomY()})` + `.opacity(pullBottomOpacity())`
              //       —— `wujie.pa:197161` / `197172`
              //     · transport `Row().translate({y: pullBottomY()})` + `.opacity(pullBottomOpacity())`
              //       —— `wujie.pa:181213` / `181224`
              //   `pullBottomOpacity = !pullMode ? 1 : pullBottomIn()`（`wujie.pa:176411-176429`），
              //   而 `pullBottomIn = clamp01((effT − 0.45) / 0.55)`（`wujie.pa:176377-176410`）
              //   ⇒ 底栏的**淡入窗口 = 位移窗口 = 0.45 → 1.00**，两者同起同落，一直走到形变**最后一帧**。
              //   ⛔ 本仓原来只有位移、`opacity` 恒 1 ⇒ 整排在形变期**全程不透明**，
              //      观感就是"出现得太早、太硬"，墙钟上永远对不上"歌名行"那一组（`pullChromeOpacity` 0.18→0.62）。
              //   静止态（`morphStage = OPEN/NONE`）`pullBottomIn()` 返回 1 ⇒ 本行落到 1，与改动前逐像素一致。
              //   回退口径（甲方旧要求"关闭期间两颗一直在"）：把本行换成 `.opacity(1)` 即可，其余不用动。
              .opacity(this.expandState.pullBottomOpacity())
              // ⛔ 2026-10-18（第五轮）：这里原来挂着一条"把控制区上沿量进 `chromeBlockTopVp`"的
              //   `.onAreaChange` —— 它是 `miniLyricTopY()` 那条钳制的输入（`chromeTop − blockH − 8`）。
              //   小歌词改成歌名行的**流式兄弟**后不再需要任何实测上沿，该量与其 `@Local` 已一并删除。
              .onTouch((event: TouchEvent): void => {
                this.touchChrome('controlTouch');
                // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*闂佸綊鏀遍悧鏇熸叏閳哄懎绠崇憸宥夊春濡ゅ懎绾ч柍鈺佸暞閺嗩亪鎮?/ 闁诲繒鍋炲ú鏍?*闂佹寧绋戝濉€arCollapse`闂佹寧绋戦ˇ顓㈠焵?
                //   闂佸搫鍟版慨鐑藉疾?`design/src/main/ets/logic/BarCollapse.ets` 闂佹眹鍔岀€氼厽鏅跺鍫濈閻犳亽鍔岀瑧闂佽鍏涢悞锕€鈹冮埀?
                //   闂佹寧绋戦悧鍡涙偤瑜旈幊鐐哄磼濠婂懎鐏?`wujie.pa:83706-84140`闂佹寧绋戦ˇ顖炲礄閿熺姵鐒婚柟閭﹀幗閽傚寮堕悜鍡楀闁哥喐鎹囧畷?
                //   `common/musicbasic/.../model/BarCollapse.ets`闂佹寧绋戦惌浣烘崲閺嶎厽鐓傞悘鐐舵濞懷囨煛閸曢潧鐏″┑鈥虫憸閹叉挳鏁傞懞銉ユ疂婵炲瓨绮岄鍕枎閵忋倕绐楅柛灞剧矌閼稿爼鎮楅悷鏉挎殧闁?
                //   闂佸疇娉曟刊瀵哥箔?闁诲海鎳撻崯顐ャ亹瑜忛幏鐘诲幢濡も偓閻?*缂備線绠栧褔骞?*闂佸綊娼ч鍛箾瀹ュ鏅柛顐ゅ敾椤撱垹瑙﹂柟杈鹃檮閺佹岸鎮楃憴鍕闁诡喗顨婂顐ょ礄閻樹警娲棅顐㈡川閺咁偊寮抽幇鐗堟櫖濠㈣泛妫楀▍?婵炴垶鎸哥粔宕囨娴兼潙妞介悘鐐插⒔閹藉啴鎮归崶褏校闁惧棝鏌涘顓炵仸缂侇噯绠撳畷婵嬪Ω閿曗偓閳敻鏌＄€ｎ厾鍫柍?
                this.onChromeBarTouch(event);
              })
              // Full player collapse retains its existing path; lyric hide reclaims layout continuously.
              .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
          }
          // 缂傚倷鑳堕崰宥囩博?TopArea闂佹寧绋戦悧鍡楃暦閻斿摜鈻旈柍褜鍓涢埀顒€婀遍崑妯兼閵夆晜鏅悘鐐舵缂嶅矂鏌涢弮鍌毿＄紒顭戝墴瀹曟﹢宕ㄩ褍鏅ｆ繛鎴炴煥椤戝嫮绮崒鐐存櫖閻忕偠妫勯悗濂告煙楠炲灝鐏柡灞芥喘閹瑧鎲撮崟顒夋Н婵炴垶鎸哥粔褰掑绩閵忕姌鎺撶瑹閳ь剟宕崇粙娆惧殘闁绘艾顕粈?
          TopAreaComponent({
            isShowPlay: this.state.isShowPlay,
            onBackClick: (): void => {
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦鍋勮ぐ鐘绘⒒閸屻倕骞栭柛銊ラ闇?* 闂佺偨鍎查弻锟犲焵?闂佹椿娼块崝宥夊春濞戙垹违鐎光偓閳ь剟鏌堢€靛摜纾奸柣鏃囧吹缁犳煡鏌?闂佺绻戞繛濠偽涢幘顔肩濠㈣埖鍔栫亸锕傛煛閸曢潧鐏犻柛妯荤☉椤劑骞嬪鍜佷紘濠电偛鐗撳褔宕埀顒€顪冪€ｎ剙浠滄繛鍙夌墵瀹曘垹效閸ワ絽浜剧€广儱绻掔粈?
              //   闂佸搫鍟版慨鐑藉疾椤愶附鏅慨妯垮煐婵粓鏌熼棃娑卞剰濠电偛绉瑰畷妤呭箮閼恒儻绱ㄩ梺鎸庣☉閻楁劗鎹㈤幋锕€鐐?/ 闂佺绻戞繛濠偽涢幘顔肩濠㈣埖鍔栫亸锕傛煥濞戞﹩妲奸柧?`closeWithAnimation()` = **闂佺懓鍢茬粔鎾箵閳哄懏鍋傜憸蹇曠磽婢舵劕绀嗛柟宄拌嫰閸橈繝鏌?*闂?
              //        闂佹眹鍨归…宄邦焽娴兼潙鍐€閻熸瑥瀚幏鍗炩槈?濠?闂?*濠电偞褰冮…鐑藉Υ婢跺簺浜归柕蹇曞Т缂嶄線鏌涘▎妯圭敖闁哄棌鍋撶紓鍌欑劍閻熴倗绮崨鏉戠濠㈣泛顑呴·渚€鏌?*闂佹寧绋戝濉穘ReverseMorph`闂佹寧绋戦ˇ顓㈠焵?
              //   闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹寮堕埡鍌滄噰闁革絿鍏橀幆鍕偓娑櫭径?`closeFullScreenPlayback()`闂? 濠电偞褰冮…鐑藉Υ婢跺簺浜归柕蹇曞Т缂嶄線鏌ㄥ☉姗嗘Т闁?婵＄偑鍊楅弫璇差焽娴兼潙绀傞柛顐ゅ枔閹枫劌鈽夐幘顖氫壕濠电偛鐗忛。顔炬?
              //        闂佸憡鍔曠粔鍫曞极鏉堛劎鐝堕柛鎰皺濠€鎾⒑椤撱劎瀵肩紒鏃€娼欒灋闁圭儤顨忓Λ褔鏌涢妷褍浠滄?闂?闁诲繐绻楁ご绋课ｉ崨濠冨闁绘ê鐏氱粻娆撴煕閹烘挸顥嬫繛?闂佺绻愰悧濠勫垝閿旂晫鈻旈柍褜鍓欓埢鎾跺枈婢跺瞼顦梺缁樺笩濞夋盯骞冨Δ鍛鐎广儱顦藉Λ褔鏌涢妷褍浠滄?闂?
              //   闂佸疇娉曟刊瀵哥箔?`closeWithAnimation()` 闂佺厧顨庢禍婊堟偨椤愶絿鈻旈柕鍫濇喘閻涙捇鏌涜箛鏃傜煀缂併劍濞婇弫宥夊醇閿濆懎甯梺鎼炲劚閿曪箓鎮￠埡鍕╀汗?缂備焦鍔栭〃鍛般亹濞戞矮鐒婇柛婵嗗閸ょ喎鈽夐幘宕囆㈢憸鐗堢叀閹粙濡搁敐鍌氫壕濞达絽鎲¤ぐ銉╂煟閹炬鍟ㄦ禍濂告偣閹扳晛鍔电紒?
              //     闂?闂備緡鍠楅崹婵堢箔婢跺顕辨慨姗嗗幖鎯熼梺鍦檸閸樹粙寮担骞夸簻闂傚牊绋戦獮銏犆归敐鍛疄闁?
        this.expandState.requestCollapse();
            }
          })
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding')
            })
            .zIndex(2)
            // 婵＄偑鍊涢崺鏍偉椤曗偓閺佸秴顫濋鈧崘鈧紓鍌氬€归悧鐐烘儊?`pullChromeOpacity = clamp((effT-0.18)/0.44)`闂?.18 闂?0.62 濠电儑绲洪埀顒€鍟垮?
            //闂?闂佸湱顭堥ˇ鐢稿箰閾忣偆鈻曢柣鏂挎啞绗戦梺闈╄礋閸斿本鎱ㄩ埡鍛仺闁哄嫬绻掔粻鏍磼鐎ｎ亶鍎忔慨妯稿姂瀹曟瑩鎼归悷鎵杸婵?闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棗娴烽閬嶆倶閻愭彃鈧綊鎯侀鑺ュ劅闁哄洨鍠撻崺澶愭煛閸愶絾娅呯紒鎯伴哺瀵板嫬顫濋崜褏顦?
            .opacity(this.expandState.pullChromeOpacity())
            .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽京澧楅妵鍕偨閸涘﹥銆冩繛鎾寸殰閸愩劌缍橀梻鍌氬亞閸樿姤鏅跺鍫濈閻犳亽鍔嶉悾?*缂備焦顨忛崗娑氳姳閳哄倻鈻旀い蹇撴噹閻︻垶寮堕悙鍨珪闁?*闂?
            //   闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亜瑜扮娀姊婚崒銈呭箺濠⒀勭矒瀹曟繈骞愭惔锛勬Ц婵?*婵炴垶鎸堕崐鏇⑺?*闂佹寧绋戝濉ecover/logic-src/閻庢鍠掗崑鎾绘煕韫囨碍鐝柟鎼佷憾瀵劑骞嗚閻?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄦ皑缁愮偤鎮楃憴鍕殤妞?md`
            //   闁?.1 闂?闂?婵?闂佸疇缈伴崕鑽ゆ濮樿埖鏅?
            //     闂?`PlayerPage` 婵＄偑鍊曢悥濂稿磿閹绢喗鐒介柨婵嗘閽?Row闂佹寧绋戝濉抋nDirection.Down`, `distance:8`闂佹寧绋戦ˇ顐﹀疮?**婵炴垶鎹侀褔宕ｉ崱娑樼煑?*
            //     闂?闂佸憡鍔曢幊搴敊閹邦喒鍋撻崷顓熷殌婵?
            //   闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹鏌涘▎妯圭凹婵犫偓?闂佽桨鐒﹂幐鎶藉Υ婢舵劕鍐€?闂備緡鍙忕徊鑲╃博鐎涙ê绶為柛鏇炲缁€鍕煃椤旇偐澧愰柟鍐插暣閺佸秵寰勯崼姘壕闁稿本绺鹃崑鎾朵沪閻愵剚顔掓俊鐐€曢悘姘舵偋鐎涙鈻斿┑鐘插閻ｈ京绱掗弮鈧悧婊兠洪崸妤€绠柡宓唭?*婵炴潙鍚嬫穱娲綖閿曞倸绀冮柛娑欐綑閸?
            //   闂佸憡鐟崹杈╁垝閹绢喖绀?/ 闁诲孩绋掗崝鏍ㄦ櫠濠婂牆绀夐柛顭戝枛鐢儵鏌涘顒€鏆為悽顖楀亾**闂佹寧绋戝﹢寮恔UI 闂佸綊娼ч鍛箾瀹ュ绀冮柟鐑樻尭濠р偓闂佹寧绋掗懝楣冩偤濞嗘挻鍤嶉柛灞剧矊娴狀垰霉閸忔祹顏堝储濞戙垺鏅璺烘濞?
            //   闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸虫俊瀵镐沪閸撗勨挄濠电偛顦板ú鎴犵箔閸涙潙绠璺猴工瑜扮娀姊婚崒銈呭箺闁规悂浜跺銊╁箚瑜庨悵銈夋煏閸℃袪闁?
            //   婵＄偑鍊涢崺鏍偉椤旇姤浜ゆ繛鍡楁捣椤忛亶鏌℃径鍡楀⒉婵?*闂傚倸鐗忛崑鐐靛垝閹绢喖绀夐柕濞у嫮鏆犻梺鎼炲劚閹碱偊鎮炬ィ鍐ㄧ骇闁炽儱纾弫?*闂侀潧妫旂粈浣烘崲閳ь剟鎮楃憴鍕暡闁轰胶鎳撻銉ノ旈埀顒勫春瀹€鈧划鈺呭冀椤愶絿鍑介梺褰掓敱閻楁洘鎱?闂?闁荤偞绋忛崕鎵箔閸屾壕鍋撻悷鏉挎灕缂佽鲸绻冪粙澶嬫償閵忊槄楠忛梺浼欑到閼活垶骞冮幘璇插嚑闁告洍鏂侀崑?
            //   闂?缂備胶铏庨崹浼绰烽崘顔界厒闊洤顑傞崑鎾存媴妞嬪海鎲归梺琛″亾闂侇偅绋掑畷鎻捗归敐鍡樼婵☆偓绠撳鍨緞鎼搭喗鏂€婵炴垶鎸剧亸銊ф娴兼潙宸濋柟瀛樺笩閸橆剟鏌ｉ妸銉ヮ伂缂佺粯娲熷浼搭敍濮橆厼鈧崬鈽夐幘顖氫壕婵?`onDismissDrag()`闂?
            //      闂佸憡鐟禍婵嗭耿?闁荤姍鍥ㄦ暠濠⒀勭矒閹峰啴鎸婃径瀣惈婵＄偑鍊涢崺鏍偉椤旂晫鈻?闂佸搫鍟抽崺鏍ㄦ櫠閻樼粯鍋ㄩ柛妤冨仧閺嗗﹪鏌熼幁鎺戝姢妞ゆ挻鎮傞弫宥夊锤?gesture()` 闁诲孩绋掗崝妯讳繆椤撱垺鍊烽梺顐ｇ〒閸犳﹢鏌涜箛鎾跺⒊缂佽鲸宀搁弫?
            //      婵＄偑鍊楅弫璇差焽娴兼潙绀傞悹楦挎閺嗗﹪鏌涢弽褎鎯堥柣鎾寸懇閹啴宕熼渚婄礂闂佸搫鐗嗛ˇ鎶姐€侀幋鐐碘枖閺夌偞澹嗛閬嶆倵濞戞瑣浠︾紒妤€顦靛畷锝呂熺化鏇炰壕?
            //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸堕崐鏇⑺囬埡鍌樹簻闁煎摜鏁搁崺澶愭倵閸︻厼浠掔紒韬插劦閺佸秹宕奸悢鍛婂婵?+ 婵炴垶鎸搁澶婎焽?`!panelLayout` 闂備緡鍙忕徊楣冨极椤曗偓閺?*闂婎偄娲ら幊姗€濡磋箛娑欑劸闁兼亽鍎遍惁?* 闂佺偨鍎查弻锟犲焵?
            //      闂佸憡鐔粻鎴﹀垂椤栨粈鐒婇弶鍫涘妽绗?闁?6.1.6 / 闁?6.16 闂備緡鍙忕徊濂告煂濠婂牆违閻忕偠濮ら崐鍗炩槈閹绢垰浜鹃悷婊嗗焽閸ㄧ粯鎱ㄩ幖浣稿珘?N 婵犮垼娉涚€氥劑鍩€椤戣法顦︾憸鎶婂洤缁╅梺顐ｇ〒閸熷﹤鈽夐幘顖氫壕婵犮垼娉涚€氥劑鍩€椤掆偓缁夎泛鈻撻幋锔藉殌濞达絽婀卞Ο鍛存煟閵夈儲鍣烽柍?
            .gesture(
              PanGesture(this.panOption)
                .onActionStart((): void => {
                  Logger.info(PlayerExpandState.LOG_TAG,
                    `RzdMorph dismiss pan start(topBar) isClosing=${this.isClosing} ` +
                    `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
                })
                .onActionUpdate((event: GestureEvent): void => {
                  this.onDismissDrag(event.offsetY, false, event.velocityY);
                })
                .onActionEnd((event: GestureEvent): void => {
                  this.onDismissDrag(event.offsetY, true, event.velocityY);
                })
                .onActionCancel((event: GestureEvent): void => {
                  Logger.info(PlayerExpandState.LOG_TAG,
                    `RzdMorph dismiss pan cancel(topBar) offsetY=${event.offsetY.toFixed(1)}`);
                  this.onDismissDrag(event.offsetY, true, 0);
                })
            )
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({
          bottom: this.windowInfo.navigationBarBottomVp,
          top: this.windowInfo.statusBarTopVp
        })
      }
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
    // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯閻戣姤鏅柛褍鍨簎ildControlStack` 闂佹眹鍔岀€氼參鎮ч幘顔芥櫖?*婵炴垶鎸哥粔鐑姐€?*闂佸憡鍔曠粔鍓佸垝?`backgroundColor(imageColor)`闂?
    //    闁诲海鎳撻崯顖毼ｉ崨濠勨枖闁逞屽墰娴?*闂佽鍘界敮濠勭箔婢舵劖鐒婚煫鍥ㄦ⒐椤?*闂佹眹鍔岀€氼剝銇愰崶顒佸殞闁圭粯甯炴穱娲煥濞戞ɑ缍乮mageColor` 闂?alpha 闂?0.4闂佹寧绋戞總鏃傚緤閻愵剚鍎熼柡鍥ｂ偓鎰佹闂佸搫鐗滈崜婵嬫閳哄懏鏅?
    //    闂佺偨鍎查弻锟犲焵?閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮悑閿涚喖鎮锋担椋庮槮濠㈠厜鍋撶紓浣瑰姈椤ㄥ懓銇愬☉銏犵煑妞ゅ繐鎳忕粻鎺戔槈閹绢垰浜鹃柣蹇撶箰缁绘劕顭囬敓鐘虫櫖閻忕偟鏅弳濠偯归崗闂翠孩缂佺粯鐩畷銉ョ暆閳ь剟鎮伴妷鈺佺煑闁挎繂瀚閬嶆偣瑜旈弨杈ㄤ繆閸涘﹦鈻旈悗锝庡枟濡椼劑鏌ｉ妸銉ヮ伃妞も晝绮妵鍕偨閻㈤倱鍥煙閸濆嫷妾х紒?
    //    闂佸憡鍔曠粔瀛樻叏閻愬搫绀冮柛娑欐綑閸斻儵姊洪銊у埌闁活亞澧楀濠氬箣閿旂偓瀚ч柟鐓庣摠濞叉繃绔熸繝鍥ㄦ櫖鐎光偓閸愮偓缍嗛梺瑙勫閸犲骸顫濋妸鈺佸強?闁诲繒鍋炲ú鏍閹寸偟鈻旀い鎾偓鍐插闂佸搫鎷嬮崹鍗炍ｉ崨濠庢付闁瑰濮甸悾?闂?
    //    闂佺厧鍟块張顒€鈻嶅▎鎾村殞闂婎偒鍘鹃杈┾偓鍨緲椤戝洭寮潏銊р枖濠电姴娲﹀?*闁汇埄鍨介梽鍕嫻娴兼潙绀傞柕澹懎鐐婇梺?*闂佹眹鍔岀€氼亞鎮潏鈺€娌柛灞剧箘椤︿即鎮归幇鍓佺Ф缂佽鲸鐟﹂幆鏃堝即閳ユ剚妫?+ 闂佸憡鐟﹂悧鐐寸珶婵犲嫪娌柛宀嬪缁€鍡涙煥濞戞鐒风紒缁樼墵閺屽瞼浠﹂懖鈺冾啍闂佸綊鏅茬欢姘跺焵椤掆偓缁绘垵危閹达箑违?
  }

  /** Wide split panel layout: cover + controls on the left, lyrics + dual-action bar on the right. */
  @Builder
  private panelControlContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: 56 }) {
        Column() {
          MusicPlayInfoBlock({
            state: this.state,
            metaBlockTranslateYvp: 0,
            isDismissing: this.isCollapsing(),
            coverLinearScale: 1,
            panelLayout: true
          })
        }
        .layoutWeight(1)
        .padding({ top: 80, bottom: 48 })

        Column() {
          LyricsComponent({
            isShowControl: false,
            isTablet: this.isTabletFalse,
            panelBottomBar: true,
            // 闂?闂佸憡鑹鹃懟顖烆敊閺冨倷娌煫鍥ㄧ☉娴滄繂顭跨捄鍝勵伒缂佸彉鍗抽幐濠呯疀閺傝法顏?`LyricsComponent` 闂佺厧顨庢禍婊堟偨椤愩倖鍋橀柕濞垮劘娴犲牓鏌ㄥ☉妯煎婵☆偁鍊濋幃鍓т沪閸撗勨挄闂佸搫鐗嗛ˇ顖炴偩閻樼粯鏅璺虹墐閸?
            //   闂佸搫鐗滈崜娆撳垂鎼淬劌缁╂い鏍ㄧ懅閻熸劙姊?L2233 闂?`MusicPlayInfoBlock` 閻庤鐡曠亸娆戝垝閿熺姴鎹堕柕濠忛檮閳绘梻绱掗埀顒勫传閸曨厽顔堥梻?+ 濠殿喗绻傞懟顖炲箖?+ 濠殿喗绻傞張顒佹櫠?
            //   闂?婵炴垶鎸哥粔宄拔涘畝鈧禍鍛婃綇閵娤€?闂佸憡鑹炬總鏃傜博鐎涙﹫绱旈柡宥冨妿閹藉啴鏌涘顒傂㈤柛銈庡弮閹櫕锛愭担瑙ｆ嫛濠?闂侀潧妫楅崐鎼佹偩椤掑嫬鏋侀悗闈涙啞閸婄偤鏌ｉ姀锝囩翱妞?L1926 闂備緡鍙忕徊浠嬎囬埡鍛剭闁告洦鍓氶弳鍫ユ⒑閹绘帩鐒鹃柍?
            hideLyricsMetaHeader: true,
            onSeekTime: (ms: number): void => {
              MediaService.getInstance().seek(ms);
            }
          })
        }
        .layoutWeight(1)
        // 濠殿喗绻傞惌渚€鎯佸┑鍫滄勃闁绘劖澹嗛懝?闂佸憡鍔曢幊搴敊?闂佹寧绋掗悺鐚歰ntentOpacity`闂佹寧绋戦悧鎰板箚閵堝棙濯寸€广儱妫楅·鍛磽?1闂?
        .opacity(this.expandState.morphContentOpacity)
        .padding({ top: 72, bottom: 74 })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .padding({
        left: 56,
        right: 56,
        top: this.windowInfo.statusBarTopVp,
        bottom: this.windowInfo.navigationBarBottomVp
      })
      // 闂?闂佺儵鏅╅崰妤呮偉?闂?闂?*闂佸憡甯掑Λ娆撳极椤旇￥浜归柟鐑樺灩濞硷綁鎮归崶褝鏀婚柡?*闂佹寧绋戦悧鎾愁焽娴兼潙绾ч柟绋垮閺嗘粓鏌ㄥ☉姗嗘Т闁逞屽墯閺岋繝鍩€?婵炴垶鎸告鎼侇敊閺冨倷娌煫鍥ㄧ☉娴滄繂顭跨捄鍝勵仾闁搞劍姘ㄩ埀顒傛暩濞呫垻妲愬┑瀣仩闁糕剝鐟﹂弳鐘绘偡濞嗗海顦﹂柣锝囧У缁嬪绻濋崶銊︺€冮梺姹囧妼鐎氼參寮悙鐑樼厒濠电偛绨遍崑?
      .onAppear((): void => {
        this.logBranchSurface('panel');
      })

      if (!this.panelLayout) {
        TopAreaComponent({
          isShowPlay: this.state.isShowPlay,
          onBackClick: (): void => {
            // 闂?闂佸憡鑹炬總鏃傜箔閸岀偞鏅柛顐犲灩瀵箖鏌熺喊鍗炲婵☆偁鍊濋幃鎯х暆鐎ｎ剛鐛ラ梻鍌氱墢閸嬬偞鏅跺鍫濈闁割煈鍠栬ぐ鐘绘⒒?= 闂婎偄娴傞崑鍡涘矗鎼淬劌缁╅柛鎾茶兌缁辨岸鏌ㄥ☉妯侯殭缂佹顦靛浼搭敍濞戞瑣浠ф俊鐐€濆褔鎳滄导鏉戠煑婵鐗忕粈?
        this.expandState.requestCollapse();
          }
        })
          .padding({
            left: 56,
            right: 56
          })
          .zIndex(2)
          .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
          // 闂?闂佸憡鑹炬總鏃傜箔閸岀偞顥堥柕蹇嬪€曟禍婵嗩熆鐠哄搫顏柕鍡楋躬瀵€熺疀閵壯呯崶婵＄偑鍊楅弫璇差焽閻楀牏鐟圭憸宥夊矗瑜斿濠氼敇閻斿鏉归梺鍛婃濞夋洖鈻撻幋鐘电當妞ゆ垼娉曢惂灞解槈閹垮啩绨奸悗鍨礃濞碱亪鎮剧仦鎴掑寲闂佹寧绋戦悧鍡涱敋椤曗偓瀵粙宕堕妸锔奸獜闂?闂?婵＄偑鍊曢悥濂稿磿?Row闂佹寧绋戦ˇ顓㈠焵?
          //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈囩博鐎涙ê绶?*闂婎偄娲ら幊姗€濡磋箛鏃傗枖閹煎瓨绻勯悷鎰版⒒閸稑鐏查柛瀣噺瀵板嫰宕熼鈧悘鍥倵閻㈠灚鍤€闁宦板姂瀹?*闂佹寧绋戦惉濂稿箖婵犲洦鍋ㄩ柛娆愵焽閻熴垽鎮楅悷鐗堟拱闁哄棴绲块幏鐘碘偓娑櫳戦～鏍偡濞嗗孩顦风紒妤€鍊垮Λ鍐閵堝懍绨煎┑鐐茬墕閻忔岸寮悙鐑樼厒濠电偛绨遍崑?
          .gesture(
            PanGesture(this.panOption)
              .onActionStart((): void => {
                Logger.info(PlayerExpandState.LOG_TAG,
                  `RzdMorph dismiss pan start(topBar-wide) isClosing=${this.isClosing} ` +
                  `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
              })
              .onActionUpdate((event: GestureEvent): void => {
                this.onDismissDrag(event.offsetY, false, event.velocityY);
              })
              .onActionEnd((event: GestureEvent): void => {
                this.onDismissDrag(event.offsetY, true, event.velocityY);
              })
              .onActionCancel((event: GestureEvent): void => {
                Logger.info(PlayerExpandState.LOG_TAG,
                  `RzdMorph dismiss pan cancel(topBar-wide) offsetY=${event.offsetY.toFixed(1)}`);
                this.onDismissDrag(event.offsetY, true, 0);
              })
          )
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  /** True when PC window uses immersive free-form decor (affects title button styling). */
  private isPcFreeWindowDecor(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  // 闂佸疇娉曟刊瀵哥箔?2026-10-17闂佹寧绋掓穱铏规崲閺嶎厽鐓傞悘鐐舵閺傃囨煛婢跺牆鍔ョ紒缁樻礋瀵灚寰勬径宀婁紘婵?`applyWindowSafeAreas()` 闂佺偨鍎查弻锟犲焵?**閻庣懓鎲¤ぐ鍐垂瑜版帗鈷?*闂?
  //   闁诲海鎳撻崯鈺冪箔鐏炲墽鈻旈悗锝庡枟濡椼劑姊洪銊у闂?*濠电偠灏畷闈涱焽閸愵喗鍎?* `applyPlaybackWindowChromeImmediately()`闂佹寧绋戦悧鍡涘极椤旂晫鈻旈柍褜鍓涢幏顐﹀礃椤忓懏娈㈤梺?:5534闂?
  //   闂?*闂佸憡鑹炬總鏃傜博鐎涙顩烽柡鍫㈡暩閻ㄦ垿鏌ｉ妸銉ヮ仹閻炴俺椴哥缓钘壩旈埀顒勫疮閹炬枼鏋?*闂佹寧绋戦懟顖濄亹瑜嶉蹇涱敊閼姐値浼囬梺?`applyPlaybackNavigationBarColor(true)`
  //   闂?闂傚倸妫欓崕濂告儍閻斿吋鍋ㄩ柕濞у啩鍖栭梺闈涙閼冲爼寮抽埀顒勬煟椤愮喎浜鹃柣蹇撶箺妞寸危?闂佽　鍋撶憸鐗堝笚閺呪晠鏌涢敂鎯ь暭闁?闂佹眹鍔岀€氼剟宕ｉ崱娑樼煑闁挎繂绻掔粈鍕煛閸偄鍘哥紒顔哄妼椤斿繘鎳犻鍌滄⒕婵炴垶鎹囩紓姘辨崲閺嶃劎鈻旀い蹇撳閸╁矂鏌ｅΟ鎸庣【闁诡喖妫欏濠氬炊瑜嬮崑銊╂煕閹寸姴校妞ゆ劕鍚嬬粋宥堢疀閵壯咁槴闂?
  //   闂?闂佹椿浜為崰鏇€呴敃鍌氱哗閻熸瑥瀚亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢舵劖鍎嶉柛鏇ㄥ幘瀹曞爼鏌涘▎娆戠К妞ゃ儱锕ラ〃婊呮暜椤斿墽顦?*闂佸憡鐟禍婵嬪极閸忚偐鈻旈悗锝庡枟濡椼劑姊洪銊у缂佹柨鐡ㄧ粙?*闂?

  /** Applies playback window chrome: system-bar colors only, window layout stays non-full-screen. */
  private applyPlaybackWindowChromeImmediately(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackNavigationBarColor(true);
    // Player is an overlay, not a new window. Switching window layout here also relayouts
    // the retained destination underneath and moves its HDS title into the status bar.
    // Keep layout policy owned by EntryAbility; only recolor system chrome.
    wu.applyPlaybackWindowChrome(true, false);
    Logger.info('RzdPlayerRoute', 'enter overlay: window layout unchanged');
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(true);
    }
  }

  /** Refreshes dynamic background tint when the current track or queue changes. */
  @Monitor('state.selectIndex', 'state.playQueueIds')
  onCurrentTrackForBackground(): void {
    // ★ 2026-10-18：**换歌先作废旧网格源**（等价上游把 `K_IMG_LOCAL` 写成 `""`，wujie.pa:292472 / :292490）。
    //   不作废就会沿用上一首的 PixelMap ⇒ 用户看到的"背景似乎是上一首歌的颜色"。
    this.dropMeshSourceForTrackChange();
    if (this.context === undefined) {
      return;
    }
    this.getImageColor();
  }

  /**
   * 换歌时作废旧网格源（同一首只是队列增删 ⇒ key 不变 ⇒ 什么都不做）。
   * ⚠️ `meshSrcVersion` 必须 +1：它才是 `MeshCoverBg` 的 `@Monitor` 令牌（只改 `meshSrc` 不触发重绘）。
   */
  private dropMeshSourceForTrackChange(): void {
    const key: string = this.currentMeshKey();
    if (key === this.meshTrackKey) {
      return;
    }
    this.meshTrackKey = key;
    const old: image.PixelMap | undefined = this.meshSrc;
    this.meshSrc = undefined;
    this.meshSrcVersion = this.meshSrcVersion + 1;
    if (old !== undefined) {
      this.releasePixelMapQuiet(old);
    }
    Logger.info(PlaybackPage.logTag,
      `RzdBgPhase drop-stale-mesh ver=${this.meshSrcVersion} key=${key.substring(0, 48)}`);
  }

  /** Entry point: kicks off async album-color extraction without blocking UI. */
  getImageColor(): void {
    void this.getImageColorAsync();
  }

  /**
   * 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*閻犳亽鍔戦妴澶愭閵忋垻绉归柡宥呭悑缁喚绱撻幘宕囨憼** 闁炽儲鏌￠埀?濞ｅ浂鍠撻埀顒€鑻惈宥咁嚕閳ь剟鎯冮崟顒侇槯闁稿﹥鐟﹀Σ鎼佹嫅濠靛﹤顥忛柕鍡楃▌缁?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸繄娼旂€殿喒鍋撻柡鍐煐濡叉悂鎷戝┑濠傤棌
   *   闁哄啰濮烽弲顐︽焽閿濆嫮顏卞〒?`MeshCoverBg` 闁衡偓閸撲焦鐣遍柡?**`$$.imgLocal`闁挎稑鐗婂﹢浼村捶閺夎法娈遍梻鍫涘灪閺嬪啯绂掔拋鍦** 闁炽儲鏌￠埀?闁圭虎鍘介弬渚€宕抽妸锕€鈪电€殿喒鍋撻梺顓ㄧ导缁旀挳宕?
   *   閻忓繋绶氬鏉款啅閼碱剛鐥呴柛锔哄妽濠€浼村捶?闁?闁煎啿鏈▍娆戠箔椤戣法顏遍悽顖嗗啯鐨戦柡?*闁活亞鍠庨惃婵嬫?*闁汇劌瀚伴崢銈夋嚌鐠囇呯缂備礁瀚▎銏ゆ煂瀹€鍕簼濞?`makeFallback()`
   *   闁挎稑鐗婄€?`seed` 闁肩灏欏ù澶愭焻閻樺灚鐣?*闁搞儲绋栭～?HSL 婵炴挻鍔曡ぐ?*闁挎稑顦悢鈧柡鍫墰閺併倖绋夊鍕憪闁?
   *   闁瑰瓨鍨冲鎴炴交濞嗗海顏卞〒姘€鍐闂傚牄鍨归ˇ鍧楀及?*闁革负鍔庨崵?URL**闁挎稒宀搁妴澶愭閵忥紕妲ㄦ繛鍡忓墲婢э箑顕ｉ埀顒勬焾閼恒儲笑闁哄倹婢橀悿鍕瑹鐎ｃ劉鍋撴稊顤砮shSrc` 濞戞捁娅ｉ埞?闁?
   *   缂備礁瀚▎銏ゅ礃?`makeFallback()` 闁稿繐鐗撻妴濠冪▔?闁?閻忕偛绻嬬粭鍌滀焊鏉堛劍笑闂侇叏绲界槐鍫曞箰?seed 闁肩灏欏ù澶愭偨鐠囨彃姣夐柡澶堝劤濞堟垿宕楀鍐亢缂傚啯鍨堕悧鎼佹晬?*闁藉啯绻嗘竟?*闁挎稑顧€缁?
   *   缂佹稑顦卞﹢锛勪焊娓氣偓濞肩増绋夌€ｎ厽绁伴悷娆欑悼閻栨粎鈧懓鏈晶鐘诲箲閵忋垺鍩傞梺鏉跨Х婢瑰﹪鏁嶅畝鍕簼闁哄啳娉涙慨鈺呮偨缂佹ɑ锛嶇紓浣规尰濞碱偅绂嶉崱鎰ㄥ亾?
   *
   * ## 闁稿纰嶇涵鍫曟晬閸垻鎼煎ù鐘烘腹缁剚绋夋繝鍐煑"闁哄牜鍓欏﹢瀵镐焊娓氣偓濞肩増绋夐埀顒勬儎閺夋垶韬?闁?
   *   婵絽绻戦濂稿箵閹邦亝鍞夌紓鍐╁灦閻楃鈹冮幇顓燁槯闁挎稑鏈俊?*鐎规瓕灏欑划?enhance+blur 閺夆晛娲ㄥ▓?64閼?4 RGBA 缂傚倹鎸搁崯?*闁?6KB闁挎稑顦崇换娑㈠触鐏炵晫鏆婇柣?key
   *   閻庢稒蓱閸?*闂傚牊鐟﹂埀顑跨閻⊙冣枔?*闁挎稒绋愮粭鍛▔閳ь剙鈻庨敓鐘偓澶愭閵忊€崇槸閺夌偠濮ゅ鍌炴嚐?key 閺夆晜蓱濡叉悂宕ョ仦鑲╊伇濡絾鐗槐婵堜焊鏉堚晜绾柟鎭掑劙缁姵娼诲▎搴℃暅缂傚倹鎸搁崯鍧楁煂瀹ュ懐绱?PixelMap
   *   闁?闁瑰灚鎸哥槐鎴﹀礉閵娧勬毎缂佹鍏涚粩瀵告暜瑜嶅銊╁及椤栨粍鍩傞梺鏉跨Х婢瑰﹪鏁嶇仦钘夊箲閹煎瓨娲滅紞澶愬冀閻撳骸娑ч柣顏嗗枑椤掓粓宕楀鍐亢闁?
   *   闁宠法濯寸粭?閻?*缂傚倹鎸搁崯?*闁兼澘濂旂粭澶愬及?PixelMap闁挎稒纰嶆晶宥夊嫉婢跺缍€缂佺姭鍋撻柛妤佹穿缁辨瑧鐥姘暥閻庢稒锕槐姘舵晬瀹€鍕┾偓澶愭閵忥紕妲ㄦ繛鍠°倕娈扮€规悂浜堕埀?PixelMap闁?
   *     闂侇偀鍋撻柛锕佹閸欏酣寮閸ゆ粌顔忛柆宥呮珵闁衡偓?闁?濞戞挸绉崇槐浼村矗瀹€鍕闂佹彃锕ラ弬渚€濡?
   *   闁宠法濯寸粭?key 濞戞挸绉寸亸顕€鏌婂蹇曠闁瑰箍鍨洪悺鏇㈡晬婢跺棗娅?濞戞挸绉归崳浼存偨椤帞绀勫☉鎾崇С缁变即骞庢繝浣虹憪濞戞挴鍋撳Λ锝嗙墱濞堟垿鏌婂鍫濐棌濞戞挻褰冮崺灞炬交濞嗗海顏卞Λ锝嗙壄缁辨岸濡?
   *
   * ## 闁粹偓?2026-10-17 鐟滅増鎸搁妵澶愬箻閵堝懏绀€闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳?*閻忕偞娲栫槐鎴炴交閸モ斁鏌ゅ☉鎿冨幘濞堟垿寮伴娆戠憪濞戞挴鍋撳Λ锝嗙墬閻℃洟鎯冮崟顖ｆ澒闁?*闁靛棗绋勭槐?
   *   闁哄秶鎳撳ú婊堟晬?*濡炪倗鏁诲浼村箰閸屾繃绁伴梺顓ㄧ导缁旀挳骞?`state.getCurrentSongItem()` 閺夆晜蓱濡插憡绋夋繝浣侯伇濡?*闁挎稑鐗忔慨鎼佸箑娴ｇ儤鏆犻悹瀣暟閺併倝寮悷鐗堝€甸柛鎰懕缁辨岸鏁?
   *   濞存粌瀛╁Σ?`currentMeshKey()` 濞戞梻鍠愬Σ鍛婄▔婵犱胶顏卞Λ锝嗙墱濞?key 闁?闁告稒鍨濋懙鎴炵▔婵犱胶顏卞Λ锝嗙墱濞堟垹绱撻幘鍐叉毐 闁?鐎殿喒鍋撻柛锕€鎼慨鈺呮偨缂佹ɑ鏉归柣銊ュ濡?*濞戞挸锕ｇ粩瀛橈純閺嶎偅鐣遍梺鏉跨Х婢?*闁?
   *   闁挎稑鐗嗛幃鎾寸▔閳ь剟骞忓鍕憪 `meshSeed()` 濞戞梻鍠嶇槐浼村矗閺嵮冪厒濞戞挸锕ｇ粩瀛橈純?闁?闁稿繑绮岀花宕囩磾閹寸偟澹愰柛姘湰閻楅亶寮伴娆戠憪濞戞挴鍋撳Λ锝嗙墱濞堟垿鎳濋懠顒佺ゲ闁靛棗鍋婄槐?
   *   闁?**閻犳亽鍔戦妴澶愭閵忋垻澶勯悗娑櫳戦弳锝呪枔闂堟稐绮婚柣?*闁挎稑鐗呯粭鍛存?`adoptCachedMesh()` 濞ｅ洦绻勯弳鈧悗鍦仧楠炲洦鎷?*闁哄啰濮鹃惃鐔兼偨閵娧冧化**闁?
   *     闁告劖鐟х槐锕傚礃閺屻儱浜濆☉鎾卞€涢、鎴炵▕閻斿嘲鍤掗柛鎺斿█濞呭酣鏁嶆径鍫氬亾閸屾繍娲ｉ柟顓滃灩椤﹁尙鈧懓鍠涚槐婵婄疀閸涙番鈧繘宕楅崼锛版帡宕?闁圭鍊藉ù鍥籍閸撲礁笑闁诡兛鐒﹀Σ鍛婄▔婵犱胶顏卞Λ?閺夆晜鐟ら柌婊堝礈瀹ュ棗绲?
   *   闁炽儲鏌￠埀?濞撴艾顑呴々褔鎮介崡鐑囩处閻忕偛鍊稿﹢?push 闁告挸绉垫俊姝屻亹閹惧啿顤呮慨婵嗚嫰閸熸挻娼诲☉姘﹂柟顑跨筏缁辨繈骞嬮弽顑藉亾閸涱喖惟缂傚啯鍨堕悧鎼佸磻濮橆厼鐏?`AppStorageV2` 闁稿繐褰夐棅鈺呮偐閼哥鍋撴担纰樺亾?
   *     闁?婵繐绲藉﹢顏堝箻椤撶喐鏉归柣銊ュ閸嬪懏绋夐埀顒侊純?閻犳劗鍠曢惌妤冪磼鐎涙ê袘闁?*濞戞挸绉烽々?*闁告瑯浜濇俊鍝ョ磽閹惧磭鎽犻梺鎻掔У閺屽﹪骞掗妷銈囩憪濞存粌妫旂花銊╁Υ?
   */
  private static meshBufKey: string = '';
  private static meshBuf: Uint8Array | undefined = undefined;

  /** @returns 鐟滅増鎸告晶鐘差潰鐏炵偓閿ら柣銊ュ缂嶅寮介懖鈺冨閻?key闁? 閻忓繋绶氬?URL / 闁哄牜鍓欏﹢瀵告導閸曨剛鐖遍柡宥呮穿閻︽垿鏁嶅☉妯虹悼濞戞挸绉撮崺宀€绮氭潪鎷岊洬闁挎稑顦埀?*/
  private currentMeshKey(): string {
    const song = this.state.getCurrentSongItem();
    if (song === undefined) {
      return '';
    }
    if (song.cover.length > 0) {
      return song.cover;
    }
    return typeof song.label === 'string' ? song.label : `res:${song.label.id}`;
  }

  /**
   * 闁活潿鍔嬬粭鍌涚▔閳ь剟宕楀畷鍥ㄦ畬濞戞挸顑囧▓鎴犵磽閹惧啿鏆遍梺鎻掔Т缂傛挾绱旈幋鐐靛婵犙勫姂閳?
   * 闁粹偓?**鐟滅増鎸告晶鐘诲籍閻樿櫣娈堕柣顫妿閸?*闁挎稑鐗愰～鍡樼▔婵犲洦妗ㄩ柕鍡楄嫰缂嶅寰勯埡鍌涘闁搞儳鍋戦埀顒€绉归崑鍛枔绾板绀嗛柍銉︽煛閳ь剚姊圭€垫洘娼懞銉︻槯 `getCurrentSongItem()` 闁告瑯鍨甸崗姗€寮伴娆戠憪濞戞挴鍋撳Λ锝嗙壄缁?
   *   闁烩晛鐡ㄧ敮鎾煂閸モ晜鏆忓ù鍏肩婵″憡绋夋繝浣侯伇濡絾鐗滃▓鎴︽煀瀹ュ牆顥忛柡鈧幆褍鐓傜€殿喒鍋撻柛锕€鎼慨鈺呮偨鐠佸磭鐟愰柕鍡楀€风换姘舵偩濞嗗繒鏉介柣婊呭濡插憡绋夋潪鎵晩閻忓繐妫欏?闁绘鍩栭埀顑跨閸樻稓浜搁崣妯肩Т"濞戞柨顑呴幃妤呭礃瀹ュ棗澶嶉柛銉у仦濞肩敻濡?
   */
  /**
   * ★★★ 2026-10-17（用户实测「点击打开播放页时背景是别的歌的颜色」）：采用壳层预热好的网格缓存。
   *
   * 两条硬规矩：
   * 1. **必须比对 key**：挂载那一拍 `state.getCurrentSongItem()` 可能还是**上一首**
   *    （上一轮就是因为盲用缓存，屏上出现了上一首的颜色）；key 对不上就什么都不做，
   *    等 `@Monitor('meshWarm.version')` 再来一次（那时 key 已经是当前歌）。
   * 2. 只用 `snapshot()` 的**字节副本**新建 PixelMap，不跨页面持有 PixelMap（避免双重释放）。
   */
  private async adoptWarmMesh(): Promise<void> {
    // ★ 2026-10-18：判据从"已经有源"改成"**这一首**已经有源"。
    //   旧写法 `meshSrcVersion > 0` 会把"上一次采用（可能是上一首）"当成"已经好了"，
    //   之后再触发也被挡死 ⇒ 整场都是上一首的颜色（用户实测「似乎是上一首歌的颜色」）。
    if (!this.isAlive || (this.meshSrc !== undefined && this.meshTrackKey === this.currentMeshKey())) {
      return;
    }
    const key: string = this.currentMeshKey();
    // ★★★ 2026-10-17（诊断：**两个 key 一次打全** —— 一眼就能判出"预热没跑"还是"key 失配"）
    //   `hdc shell hilog -x | Select-String 'RzdMeshWarm adopt'`
    //     hit=0 且 key-warm 为空           ⇒ 壳层预热根本没跑（见 `RzdMeshWarm skip-*`）
    //     hit=0 且 key-warm 非空但 key 不同 ⇒ key 口径不一致（`meshWarmKeyOf` vs `currentMeshKey`）
    //     hit=1                            ⇒ 采用成功，背景应当已是当前歌的网格
    const warmKey: string = this.meshWarm.key;
    const hit: boolean = key.length > 0 && warmKey === key && this.meshWarm.bytes !== undefined;
    Logger.info(PlaybackPage.logTag,
      `RzdMeshWarm adopt key-warm=${warmKey.substring(0, 48)} key-cur=${key.substring(0, 48)} ` +
      `hit=${hit ? 1 : 0} ver=${this.meshSrcVersion} alive=${this.isAlive ? 1 : 0}`);
    if (!hit) {
      return;
    }
    const copy: Uint8Array | undefined = this.meshWarm.snapshot();
    if (copy === undefined) {
      return;
    }
    try {
      const pm: image.PixelMap = await image.createPixelMap(copy.buffer, {
        size: { width: SRC_EDGE, height: SRC_EDGE },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
      if (!this.isAlive || (this.meshSrc !== undefined && this.meshTrackKey === this.currentMeshKey())) {
        this.releasePixelMapQuiet(pm);
        return;
      }
      Logger.info(PlaybackPage.logTag, `RzdMeshWarm adopt mesh (prewarmed) key=${key.substring(0, 48)}`);
      this.commitMeshSource(pm, this.meshSrc);
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag, `RzdMeshWarm adopt failed code=${e?.code}, message=${e?.message}`);
    }
  }

  /** 预热缓存更新时再取一次（壳层是按 `selectIndex` 变化触发的，此时 key 已经是当前歌）。 */
  @Monitor('meshWarm.version')
  onMeshWarmVersionChanged(): void {
    void this.adoptWarmMesh();
  }

  /**
   * ★★★ 2026-10-17（⑤ 照搬无界的等价做法：**页面 `onAppear` 里先 await 一次采用、再取色**）：
   * `adoptWarmMesh()` 内部已比对 `meshWarm.key === currentMeshKey()`，key 对不上就什么都不做；
   * 取色（`getImageColor()`）必须在它**之后**跑，否则两条链路并发/抢先 ⇒ 背景与封面不是同一首。
   */
  private async adoptWarmMeshThenTint(): Promise<void> {
    await this.adoptWarmMesh();
    // 页面可能在这一拍已经被关掉（`onDisappear` 里 `isAlive = false`）⇒ 不再取色。
    if (!this.isAlive) {
      return;
    }
    Logger.info(PlaybackPage.logTag,
      `RzdMeshWarm tint after adopt adopted=${this.meshSrcVersion > 0 ? 1 : 0}`);
    this.getImageColor();
  }

  /**
   * ★★★ 2026-10-18（用户第三轮「点击展开动画过程背景颜色还是不对」；**照搬无界的那一步"打开前就有本地封面"**）：
   * **同步**采用预热缓存 ⇒ 形变**第 1 帧**就有真封面，不会先亮 `hueOfSeed(title+artist)` 那条哈希色。
   *
   * 上游为什么不会闪哈希色：`coverPath = K_IMG_LOCAL` 是**本地文件路径**，由 `PlaybackService.updateCover`
   * 在 `coverCache.ensure()` 成功后写成 `"file://"+path`（`wujie.pa:292406-292448`），失败两支显式写 `""`
   * （`:292472` / `:292490`）；`decodeCover('')` 立刻 null、且 `node.src === null` 时画布**空着**（透出下层），
   * **绝不会先画一张哈希色的兜底再切**。我们这边 `meshSrc` 是页面异步下载/解码来的，`await` 那一拍只能先画兜底。
   * ⇒ 这里用 `createPixelMapSync` 把已预热好的 64×64 字节**同步**变成 PixelMap 并提交，
   *   与 `adoptWarmMeshThenTint()`（异步那条）互补；同步这条先跑，命中时 `meshSrcVersion` 已 > 0，
   *   后面的异步 adopt 会被"这一首已有源"的守卫挡掉。
   */
  private adoptWarmMeshSync(): void {
    if (!this.isAlive) {
      return;
    }
    const key: string = this.currentMeshKey();
    if (key.length === 0 || this.meshWarm.key !== key) {
      return;
    }
    if (this.meshSrc !== undefined && this.meshTrackKey === key) {
      return;
    }
    const copy: Uint8Array | undefined = this.meshWarm.snapshot();
    if (copy === undefined) {
      return;
    }
    let pm: image.PixelMap | undefined = undefined;
    try {
      pm = image.createPixelMapSync(copy.buffer, {
        size: { width: SRC_EDGE, height: SRC_EDGE },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag,
        `RzdMeshWarm adopt-sync failed code=${e?.code} msg=${e?.message}`);
      return;
    }
    if (pm === undefined) {
      return;
    }
    Logger.info(PlaybackPage.logTag, `RzdMeshWarm adopt-sync key=${key.substring(0, 48)}`);
    this.commitMeshSource(pm, this.meshSrc);
  }

  private async adoptCachedMesh(): Promise<void> {
    // ★ 2026-10-18：同上——只挡"这一首已经有源"，不再用"任何源都算好了"。
    if (!this.isAlive || (this.meshSrc !== undefined && this.meshTrackKey === this.currentMeshKey())) {
      return;
    }
    const buf: Uint8Array | undefined = PlaybackPage.meshBuf;
    const key: string = this.currentMeshKey();
    if (buf === undefined || key.length === 0 || PlaybackPage.meshBufKey !== key) {
      return;
    }
    try {
      const copy: Uint8Array = buf.slice();
      const pm: image.PixelMap = await image.createPixelMap(copy.buffer, {
        size: { width: SRC_EDGE, height: SRC_EDGE },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
      if (!this.isAlive || (this.meshSrc !== undefined && this.meshTrackKey === this.currentMeshKey())) {
        this.releasePixelMapQuiet(pm);
        return;
      }
      Logger.info(PlaybackPage.logTag, 'RzdBgCache adopt cached mesh (no download needed)');
      this.commitMeshSource(pm, this.meshSrc);
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag, `adoptCachedMesh failed code=${e?.code}, message=${e?.message}`);
    }
  }

  /**
   * @returns 闂佺厧鍟块張顒€鈻嶅▎鎴犵＞闁瑰鍋熸竟鎰版煟?*闂佺绻戠划宀€鑺卞畷鍥╃煋鐎广儱鎳愰幗?* 闂佺偨鍎查弻锟犲焵?闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮?`seedOfParts($$.title, $$.artist)`
   *   闂佹寧绋戝濉抣ayerPage.ets:5252` 闂佹眹鍔岀€氼剟鎮块崟顖氱煑闁稿矉濡囩粈鍡涙煏?
   *
   * 闂佸憡鐟禍鐐哄极閵堝棛顩?闁诲繐绻嬬欢姘焽娴兼潙鐭楅柡宥忓閻熸繈鏌涢幒鏂款暭婵?闂備緡鍋嗘慨鎾储鐟欏嫭鍎熼柡鍥╁Х缁夊綊鏌″鍥モ偓瀣濡句净eshCoverBg.makeFallback` 闂?`hueOfSeed` 闂?`fillFallback`闂佹寧绋戦ˇ顓㈠焵?
   * 婵炴垶鎸搁敃銉╂偉?`seedOfParts` 闂佹眹鍔岀€氼厾鈧碍鍎抽埢鏃堝即閻愮鍚悷婊呭鐢濡撮崒婊呯當闁哄啫娴傞崬鍫曟⒑閹绘帗婀伴柣銉ユ嚇瀵灚寰勯幇銊ヤ壕闁归偊鍓涢幗鐔兼倶閻愬瓨绀€缂佽鲸鍨块弫宥呯暆閸愵亞顔愰梻浣瑰絻閻ジ寮?`title|singer`
   * 闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐ャ亹瑜戦妵鎰板础閻愬瓨鍎?*闂佽偐顢婄亸娆徝?*闂佹寧绋戝濉皍eOfSeed` 闂?Java 閻庢鍠栫换鎰版偤瑜忕划顓㈡晜閼愁垼娲梺鍛婄箓閻楀棛绮崶顒佹櫖濠㈣埖绋撶粈澶愭煙瀹勬澘鎮戠痪顓″煐缁嬪顓奸崨顔尖偓閬嶆煕濞嗘ü绨风紒鍙樺嵆楠炴垿锝為銏犳疂闂佽偐顢婄亸娆徝规径鎰櫖?
   * 婵炴垶鎸哥粔瀛樼附閺嶎厼浼?闂佸搫鐗嗛ˇ浼存儉閸涙潙瀚夊璺洪閸撳綊鏌?闂?
   */
  private meshSeed(): string {
    const song = this.state.getCurrentSongItem();
    if (song === undefined) {
      return '';
    }
    const title: string = typeof song.title === 'string' ? song.title : '';
    const singer: string = typeof song.singer === 'string' ? song.singer : '';
    // ★★★ 2026-10-17（照搬无界 `seedOfParts(title, artist)`）：
    //   `contract...Identity&1.0.0.#*#seedOfParts`（反编译）里是
    //   `"" + a + "" + b + ""` ⇒ **就是 `title + artist` 直拼，没有分隔符**。
    //   本仓原来用 `${title}|${singer}` —— 多一个 `|` 就让 `hueOfSeed()` 的哈希
    //   （`h = h*31 + charCode`，`wujie.pa:91914-91957`）完全不同 ⇒ 兜底网格色相与上游不同。
    return title.length > 0 || singer.length > 0 ? `${title}${singer}` : '';
  }

  /**
   * 闂佺娉涢敃銈夋儍濠靛顥堟い顐幖閻︽粓鏌ら悷鏉跨骇鐎规洝灏欑划璇参旀担鍝ヤ海濠电偟绻濈粈渚€宕㈠鍫熷仺闁靛ě鍕殸婵炴垶鎸堕崐鎾绘煂濠婂嫸绱ｆ繝濠傛椤ュ繑顨ラ悙鑸电【鐟滄澘鍊婚弫顕€宕橀敂鐟颁壕?
   *
   * 闂?`coverTint` 婵炴潙鍚嬫穱楦款杺闂?{@link onCoverTintVersionChange}闂佹寧绋戦惉濂稿极鏉堚斁鍋撻悷鏉挎殲濠碘€虫啞閿涙劕顭ㄩ崱妤婃婵炴垶鎸搁鍛般亹閸屾粎纾兼繛鍡樺灦缁插鏌ょ憴鍕祷婵炲懏甯℃俊?
   *
   * **婵炴垶鎸哥粔鎾垂娴犲妫樻い鎾跺仧绾惧鏌?*闂佹寧绋掔喊宥呯暦閼碱剛涓嶆俊銈勭劍閹烽亶妫呴澶婁簻鐟滄妸鍥у強妞ゆ牗鑹惧▓銈嗙箾閸☆厾纾块柣锝咁煼瀵敻顢涢妶鍥╊槷闂佺绻愮壕顓烆焽閸愨晝鈻曢柣鏂垮槻鐢儳绱掗悩鎰佹當闁靛牏鏅埀顒佺⊕椤牓骞戦敐澶婄骇?闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕傛偋闁秵鍋ㄩ柕濠忕畱閻?
   * 闂侀潻璐熼崝蹇涱敊閺囩姷纾炬い鏇楀亾闁革綁鏀辩粙澶愬焵椤掑嫬绠ラ柟鎯х－绾捐崵鈧鍠掗崑鎾绘煕韫囨洦鍔滅紒杈ㄧ箘缁參顢栫捄顭戜紘闁汇埄鍨庨崨顔炬殸濠电偟绻濈粈渚€宕㈠鍕剁矗婵犲﹤妫楅ˉ蹇涙倶韫囨挸鑸归柛鎴磿缁辨帟绠涢弮鈧瑧閻熸粎澧楅幐鍛婃櫠閻樺吀鐒婂〒姘ｅ亾婵為棿鍗抽幊婵堟嫚瑜忕粈澶娾槈閹惧磭小缂佸彉鍗冲畷妤呭醇閵夛讣绱℃繛鎴炴尨閸嬫挸鈽夐幘鎰佸剰闁告顫夐幆鏃堝即閳ユ剚妫岄梺?
   *
   * @param red 闁诲繐绻嬬欢姘焽閻楀牏鈻旈柡鍕箰椤ュ繒绱掓穱鍗炵伈闁逞屽墯瀹€鍛婄?0闂?55闂?
   * @param green 闁诲繐绻嬬欢姘焽閻楀牏鈻旈柡鍕箰椤ュ繒绱撴担鍛婂仴闁逞屽墯瀹€鍛婄?0闂?55闂?
   * @param blue 闁诲繐绻嬬欢姘焽閻楀牏鈻旈柡鍕箰椤ュ繘鏌﹂崘鈺冪疄闁逞屽墯瀹€鍛婄?0闂?55闂?
   */
  private publishFlowLightColors(red: number, green: number, blue: number): void {
    if (!this.isAlive) {
      return;
    }
    const vivid: string[] = ColorConversion.vividFlowColors(red, green, blue);
    this.coverTint.sourceColor = vivid[0];
    this.coverTint.targetColor = vivid[1];
    this.coverTint.version = this.coverTint.version + 1;
    Logger.info(PlaybackPage.logTag, `flow light tint updated src=${vivid[0]} dst=${vivid[1]}`);
  }

  /**
   * Loads cover bytes, derives theme background color, and (before 2026-10-15) built the
   * blurred background PixelMap.
   *
   * 闂佸疇妫勯幊澶娢?2026-10-15闂?*婵炴垶鎸哥粔鎾疮閳ь剙霉濠х姴鍟В澶娒归悩渚敽缂傚秴绉归幊妤冧沪閻愵剛褰查柟鐓庣摠濞叉牕霉?*闂侀潧妫楅崐浠嬪磿濡ゅ懎鐤炬い鏍ㄦ皑濠€鎾煛閳ь剛鎲撮崟顐や海闂侀潧妫楅懟顖滄暜椤愶絾鍙忛悗锝庝簽濞堥亶姊?+ 缂傚倷绀佺€氼亜鈻庨姀銏㈡／鐟滃秹鎮块崟顖氱睄闁煎摜娈戞担鍝勫濠电偛绨遍崑?
   *   闂佹寧绋戝鏈刲ink originalCoverSource} + {@link backdropBlurRadiusVp}闂佹寧绋戦ˇ顐﹀闯?闁哄鏅滈悷鈺呭闯閻戣棄鐭楁い蹇撳閳锋牕鈽夐幘鍗炩偓鎾斥枎閵忥紕顩查悗锝呭缁?
   *   闂?闂?`imageLabel` 婵犮垼娉涚粔宕囩礊閸涙潙绠?*闂佸憡顭囬崰搴綖閹邦喕鐒婂〒姘ｅ亾婵?*闂佹寧绋戝濉昬source`闂佹寧绋戦¨鈧紒閬嶄憾閸?缂備胶濮甸〃鍛村吹?`state.imageColor`
   *   闂佹寧绋戦悧濠囧箰闁秴缁╁Δ锝呭暔閳ь剙顦甸幊妤冧沪閻愵剛褰查梻渚囧弿缁蹭粙鎯囨导鏉戠煑闁哄秲鍔庢竟澶愭煠绾拋鍤嬬紒? 濠电偟绻濈粈渚€宕㈠鍫熷殞閻忕偛鍊甸崑鎾诲磼濞嗘帒骞€闂傚倸鍊婚ˉ鎰暰闂佹椿鍠曠粈渚€宕甸銏犵骇闁靛／鍕殸 PixelMap **闂佸憡鐟禍鐐哄极閵堝棛顩查幖绮光偓宕囨偧闂佽偐顢婇婊呮濠靛鍋ㄩ柕濞垮劤閺嗘岸鏌涘Δ鈧崯璺ㄦ?*闂?
   */
  private async getImageColorAsync(): Promise<void> {
    const jobSeq: number = ++this.imageColorJobSeq;
    const ctx = this.context;
    if (!ctx) {
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (!song) {
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘极閵堝绠ｉ柡瀣靛亐閸嬫挸鐣濋埀顒勫磻閿濆绀勭紓浣股戠亸锟犳煛閳ь剟鎮欓浣芥嫬闂佺懓鐏氶幐鍝ユ閹寸偞浜ゆ俊顖滅帛绗戝┑鐐插閸撴繂锕㈡笟鈧幊妤冧沪閻愵剛褰查梺闈涙缁夎泛鈻撻幋鐐碘枖闁逞屽墴瀵爼鏁嶉崟顒€鐒搁梺鍛婂灩婵磭绱炲澶婄煑妞ゆ牗绻傞崢鎾煥濞戞﹩妾х紒?
      //   闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂備緡鍙忕徊鑲╃博閹绢喖绀嗗┑鐘冲搸閳ь剙顦靛Λ鍐閻樿尙浠╅梺鍦焾閸婅棄霉閸ヮ剚鏅悗鐟扮倰tate.getCurrentSongItem()` 闂佸憡鐟崹鐢稿礂?*闁哄鏅滆摫闁汇儱鎳愰幉鎾晲閸℃瑢鍋撴禒瀣闁绘垶蓱闂?*
      //   闂?闁哄鏅滈悷鈺呭闯閻戣棄鍌ㄩ柣鏂挎啞闂勫秹鏌ｉ埡浣烘憼閻?`return` 闂?闂佸搫鍠氬鈧紒妤€顦靛畷锝夊冀椤掆偓椤ュ繐鈽夐弮鍌氭瀺缂佹顦娆撴惞閸︻厾效闂佸搫绉堕妴瀣濠靛鍤€閻忕偠鍋愰悷?*濠电偛澶囬崜婵嗭耿娴ｅ湱顩烽悹浣哥－缁夊灝霉濠婂啯鎯堥柛鐔插亾闂佸搫顦崕杈亹閵婏妇鈻旈柍褜鍓欓埢?*
      //   闂佹寧绋戦悧鍡涘箖閹惧鈻旈柍褜鍓氶敍鍐冀閵娧勬啓婵炴垶鎸哥粔宕囨閹殿喗鍠嗛柨鏇楀亾鐟?`selectIndex`/`playQueueIds` 闂?`@Monitor`闂?
      //   闂?闁哄鏅滈悷銈囩博閹绢喖鏋侀柡澶嬪灥瑜扮娀姊洪鍨撻柣銉ユ嚇瀵灚寰勬惔鈥冲闂佸搫鎷嬮崹鐣屾濠靛鍎庨柡澶嬪灥閻撳倿鏌ｉ～顒€濡介柛鈺傜洴瀹曟岸宕堕妸褎鎲欓梺闈涙閸婄敻宕?闂佽　鍋撻悷娆忓閻忓洭鎮硅濠㈡﹢骞冮幘瀵糕枖闁逞屽墴瀵?*闂佸搫鐗嗛ˇ閬嶅疾椤愶附鐓傜€广儱鎳庣徊?*闂佹寧绋戦悧濠傘€掗懜闈涚窞?4 濠?闁?400ms闂佹寧绋戦ˇ顓㈠焵?
      this.scheduleBackgroundRetry(jobSeq, 0);
      return;
    }
    this.releaseBackgroundCoverIfPixelMap();
    // Online songs without a resolved cover use the default art for the blurred backdrop.
    this.imageLabel = song.source.length > 0 && song.cover.length === 0 ? $r('app.media.ic_avatar1') : song.label;

    // Online songs always use a neutral dark backdrop; the blurred cover renders on top.
    // Local color extraction is only for local tracks and never tints red.
    if (song.source.length > 0) {
      if (this.isAlive) {
        this.state.imageColor = 'rgba(20, 20, 22, 0.5)';
      }
      // 闂侀潻璐熼崝搴ㄥ吹鎼粹槅娼伴悘鐐靛亾闁裤倝鏌ㄥ☉娆掑鐟?*闁荤喐鐟辩徊鍧楁偉?*闁诲繐绻嬬欢姘焽閹殿喚纾兼繛鍡樺姉閵堬箓鏌涜箛鎿冩Ц鐟滄澘娲幊婵嬫嚑椤掍焦娈㈤梺?
      //
      // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋掓穱铏规崲閺嶎厽鐓傞悘鐐舵閺傃囨煛婢跺牆鍔ョ紒缁樻礃鐎?`effectKit.createEffect(coverPm).blur(imageBlurRadius())`
      //   婵☆偅婢樼€氼厾鎲伴崱娑樿摕闁规崘灏欓杈┾偓娈垮枤婵絻鍟紓?PixelMap 閻熸粎澧楅幐鍝ヨ姳閹惰棄鐐?闂佺偨鍎查弻锟犲焵?**闁荤姴娲㈤崕鐢搞€傞埡浣碘偓鎺楀矗婢跺苯甯悗鍦焾瀵爼寮抽敐鍡樺闁规儳鍘栫划濠氭煟?*闂佹寧绋戦悧鎰板磿濡ゅ懎鐤炬い鏍ㄧ⊕閺嗩參鎮楅崷顓炰沪婵＄偛鍊歌灒闁挎稑瀚棟闂?
      //   闁圭厧鐡ㄥú鏍瑰Ο鑲╃＜婵炲棙鍨堕悾閬嶆煛?{@link originalCoverSource()} 闂佹眹鍔岀€氼剛鏁锝嗗弿閻庯綆浜炲▓閬嶆⒒閸偅绶涚紒杈ㄥ哺婵?
      //   闂?`imageLabel` 婵炴垶鎸哥粔鎾疮閳ь剟鎮跺鐓庝函缂佷焦鎸抽獮瀣箛椤掓垝鑳堕崠鏍ㄧ節閸屾稓顩梺鎸庣⊕缁嬫牞顣鹃梺娲诲枙濞村洨鎹㈤弽銊р枖闁逞屽墮椤垽濡烽妶鍥╊啍闂佷紮绲鹃悷杈╂濠靛鐐婇柣妯跨簿缁€?
      if (song.cover.length > 0 && this.isAlive) {
        try {
          const pair: CoverDecodePair =
            await PlaybackPage.loadOnlineCoverPair(song.cover);
          // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋掑銊х礊婢舵劕鍐€闁艰婢橀崜褰掓煛閸滀礁鐏ｆ繛鍫熷灥閳瑰啴骞囬崜浣侯槱64闁?4闂佹寧绋戦ˇ顖氾耿椤忓牆瑙﹂悘鐐跺亹椤忚鲸绻涢崱蹇婂亾閼碱剛鎲柡澶屽仒缁瑩宕抽悜钘夌闁绘艾顕粈澶娒瑰┃鍨偓妤冨垝娴煎瓨鍤勯悘鐐靛亾閻濐垶鎮?
          if (pair.mesh !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            this.publishMeshSource(pair.mesh);
          } else {
            this.releasePixelMapQuiet(pair.mesh);
          }
          this.releasePixelMapQuiet(pair.full);
        } catch (_err) {
          // 闂佸憡鐟﹂悧鐐寸珶婵犲啫绶為弶鍫亯琚濇繛鎴炴尭缁夊瓨绺介弽顓炰紶鐎广儱妫欑亸锟犳煛閳ь剟骞橀崨顖滅崶闂佺厧鍟块張顒€鈻嶅▎鎴炲皫闁哄娉曢弶浠嬫煛閸愵厼鐓愰懚鈺冪磼椤栨凹鐓紒杈ㄧ箖缁嬪顓奸崨顓熸珒闂傚倸娲犻崑鎾绘偡閺囨碍绁扮紒缁樼墪椤曪綁鎮╁ú缁樻濠电偞鎸稿鍫曟偂鐎ｎ喖鐐?
        }
      }
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘极閵堝绠ｉ柡瀣靛亐閸嬫挾浠﹂悙顒€绱﹂梺鍦檸閸樹粙寮笟鈧幃鈺呮嚋绾版ê浜惧ù锝呮惈娴狀垶鏌涢幋鐘靛笡濠⒀嶇畱椤曪綁鍩€椤掑嫬绠绘い鎾跺枑閺夊綊鏌?闂?闂佺厧鍟块張顒€鈻嶅▎鎾冲強妞ゆ牜鍋熼幏銊╂煟閵娿儱顏电紒閬嶄憾閹瑩鏌呭☉姘间紘婵炴垶鎸搁鍡涘箰闁秴缁╅柟顖嗗嫮娈ゅ┑顔界箰缁蹭粙鎮ラ崼鏇炍ョ€广儱绻掔粈?
      //
      // ## 闂佸搫鐗嗛幖顐﹀春濡ゅ懏鏅柛顐秵閸ゃ垹霉閻欏懐鎮奸柣鏍ㄧ矒瀹曪繝宕橀懠顒傜畳闂佹寧绋戞總鏃傜箔婢舵劕鍙婃い鏍ㄧ矊椤曟煡鏌?
      // ```
      //   闂侀潻璐熼崝搴ㄥ吹鎼粹槅娼伴悘鐐靛亾闁裤倝鏌ｉ妸銉ヮ伂闁稿孩顨婂?*婵炴垶鎸哥粔闈浳ｉ幖浣哥煑闁哄稁鍓欓ˉ蹇涙倶?*闂佹寧绋戦悧鎾诲磻閸涱喚鈻旈柍褜鍓涙禒锕傚磼濞戞锕傛煕閹邦厾鎳勬い鎺撴尦閹啴宕熼鍓ь唴婵?rgba(20,20,22,0.5)闂佹寧绋戦¨鈧紒?
      //   闂佹椿浜為崰鎰邦敆濠婂牊鍎嶉柛鏇ㄥ枛閸撳綊鏌￠崪浣哥仭婵?*缂傚倸鍟崹鍫曟偋閹间礁鐐?*闂佹寧绋戝濉竨blishMeshSource(pair.mesh)`闂佹寧绋戦¨鈧紒杈ㄧ箞閹虫挾浠﹂悾灞炬疁闂佸憡鐟禍婊冿耿?
      //   `song.cover.length > 0` 闂佸搫鍟抽崺鏍ㄦ櫠閻樺啿顕辨慨妯诲墯濞煎爼鎮峰▎娆戝埌闁搞値鍙冨鍫曞Ψ閿濆倸浜?
      //   闂佸搫鐗滄禍婵嬪箰闁秴缁╅柣鎰靛墯椤ρ囨倶韫囧海绐旀繛?URL 闂佸憡鐟崹鐢稿礂濡粯浜ゆ俊顖濆吹濮婇箖鏌涢幒鏂款暭濠⒀勭矒閺佸秹宕搁。濯data 闂?resolve闂佹寧绋戦ˇ顐﹀闯?闂佸搫鍟ㄩ崹娲儉閸涱垳纾鹃柟瀵稿仧婢规劕鈽夐弮鍌氭瀾闁汇儱鎳樺畷锝夊冀椤掆偓椤?
      //   闂?闁诲繒鍋涚换瀣箔閸屾粈鐒婇弶鍫涘妽绗戦梻渚囧弿缁蹭粙鎯囬悧鍫熶氦闁硅揪濡囬幏銊╁箹?= 闂佹椿娼块崝宥夊春濞戙垺鍎戦悗锝庝簻閻撳倿鏌?闂佺厧鍟块張顒€鈻嶅▎鎾冲強妞ゆ牜鍋熼幏銊╂煟?闂?
      //   婵炴垶鎸撮崑鎾绘煟閹邦垼娼愰柟鎼佷憾瀵?闂?闁诲繐绻嬬欢姘焽?metadata 闂佸憡甯￠。锔剧礊?闂?`onCurrentTrackForBackground` 闂佸憡鍔曠粔椋庣玻閸ャ劎鈻旈柍褜鍓欓埢?闂?濠殿喗绻愮徊浠嬫偉閸洖违?
      // ```
      // ## 婵犮垼娉涚€氼噣鎮块崱娑欐櫖?*婵炴垶鎸哥粔纾嬨亹閸岀偛鍙婇幖瀛樼箖瀹曟彃霉閿濆棙绀夋い顐㈩儑閹插瓨寰勬繛鎯т壕?*闂佹寧绋戦懟顖濄亹瑜忛幏瀣煛娴ｇ儤娈滈梺鐓庮殠娴滄粎鎹㈡笟鈧銊╂嚋閸偅鐣伴梺?
      //   闂佺厧鍟块張顒€鈻嶅▎鎾崇煑妞ゅ繐娴傞崵澶愭偣?闁诲繐绻嬬欢姘焽娴兼潙瀚夊璺侯儑濮婇箖鏌￠崼婵愭Ц闁糕晛鐭傞獮?闂佸搫鐗嗛ˇ顖炲矗瑜旀俊?*婵炴垶鎸哥€涒晠骞愰柆宥呯哗闁告挆鍐冿箓鏌熼璺ㄥ妽婵☆偁鍊濆畷?*
      //   闂?闁诲繐绻嬬欢姘焽閻楀牊浜ゆ俊顖濆吹濮婇箖鏌涢幒鏂款暭濠⒀勭矒瀵喚鎷嬮崷顓狀槷**闂佸搫鐗嗛ˇ閬嶅疾椤愶箑鎹?*闂傚倸鎳忛弻褏绮╃€涙ê顕辨慨姗嗗墮婵粙鏌涢幇顒傂㈢憸鏉挎处缁嬪鍩€椤掆偓閳诲酣鍩ラ崨顖滎槱闂佸搫鐗冮崑鎾愁熆?`BG_RETRY_MAX` 濠电偛妫屽Σ鍕?
      //     濠殿噯绲界换鎴︻敃婵傚憡鐒鹃柛濠勫櫏濞诧綁寮?`isAlive` + `jobSeq` 闁哄鏅滈悷銈囨偖闁秵鐒奸柟鍓х帛閿涘矂鏌ㄥ☉姗嗘Ф闁?
      //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸哥粔鐑藉礂濮椻偓瀵噣鎮╃紒姗嗏偓娆撴⒑閹绘帞啸闁伙富鍨堕弫宥咁潩椤掑倹顔堥梻鍌氱墑閸ㄥ鍨惧Ο灏栧亾閸︻厼浠掔紒妤€顦遍埀顒佺⊕閿氭繝鈧鍫熸櫖闁割偆鍠愰幏閬嶆煕閿旀儳顣兼俊顐犲€濆畷?闂佽浜介崕杈亹濞戞﹩娼╅梻鈧幇顔炬毌婵犮垺鍎肩划鍓ф喆閿曞倹鏅璺侯儐椤ρ囨偡閺囨氨顦﹀ù鐘靛█楠炲秶鈧絻鍔夐崑?
      if (song.cover.length === 0 || this.meshSrcVersion === 0) {
        this.scheduleBackgroundRetry(jobSeq, 0);
      }
      return;
    }

    let mediaData: Uint8Array;
    try {
      mediaData = await ctx.resourceManager.getMediaContent(song.label.id);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(PlaybackPage.logTag,
        `getMediaContent failed, code=${err?.code}, message=${err?.message}`);
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    }
    if (!mediaData || mediaData.byteLength === 0) {
      Logger.error(PlaybackPage.logTag, 'getMediaContent returned empty buffer');
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    }

    let pixelMap: image.PixelMap | undefined = undefined;
    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`decodeCover`闂佹寧绋戦¨鈧紒鍙樺嵆瀹曘儳浠﹂懖鈺婁紘濠电偛鏋撮妵鐗堝浮閹?*婵＄偑鍊楅崕銈嗘櫠濠婂牆绀冪€广儱鎳庡В澶娾槈閹绢垰浜鹃悗?64闁?4**闂?
    //   闁诲海鎳撻崯顖涙櫠閻樿鍙婃い鏍ㄧ矌缁夊綊鏌″鍫濐棈闁稿孩顨婂鏌ヮ敍濠婂嫮鏆犲┑鐘欏嫬濮х紒杈ㄧ懇瀵噣鎮╅崹顐ｇ彧 `SRC_EDGE = 64`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婄锕?64闁?4 婵炴垶鎸搁敃銈嗙?`enhanceColors`
    //   + `boxBlurRgba(9, 3)`闂佹寧绋戦懟顖炲疮閳ь剟鎮?`drawPixelMapMesh` **闂佽　鍋撻柟顖嗕椒娴烽梻浣稿⒔閸庛倕顕ｈ瀵偊寮堕幋鐘崇秳** 闂?
    //   闁荤喐鐟ラ崐褰掑礉閸涙潙鍙?婵犮垹鐖㈤崱妤婃闂佺鍕垫畷缂佷緤绠撳畷?闂佹寧绋戞總鏃傜箔?闂佺绻堥崝宀勫垂鎼淬垺缍囬柕濞у啳濮甸梺缁樻寙閸涱収鏆?+ 婵°倕鍊硅摫闁哄苯顦灒闁挎稑瀚棟"闂佸搫瀚烽崹顖滄偖鏉堚晝鐭撶€广儱瀚浠嬫偡濡ゅ嫸楠忛柍?
    let meshPm: image.PixelMap | undefined = undefined;
    const imageSource = image.createImageSource(mediaData.buffer as ArrayBuffer);
    try {
      pixelMap = await imageSource.createPixelMap();
      // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋掑銊х礊婢舵劕鍐€闁稿繗鍋愰悥?*闂佸憡顨嗗ú婊呪偓姘煎幗缁嬪鍩€椤掍胶鈻?try** 闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐﹀Φ閹寸姵瀚?*婵炴垶鎸哥粔鐑藉礂?*闂?闂佸憡鐟﹂悧鐐寸珶?闂備緡鍙忕徊鎯ь焽椤栨粍宕夋い鏍ㄧ懅椤忛亶鎮?abort闂?
      //   闂佸憡顭囬崰鎰焽閻㈢鍙婃い鏍ㄧ箘椤庘偓婵炴垶鎸诲Σ鎺曨暰闂佹椿鍠曠粈渚€骞冮幘瀵糕枖闁逞屽墯缁?`try`闂佹寧绋戦惌渚€鍩€椤掆偓閻倿宕戦崨顔锯枖?`catch` 婵?`return`闂佹寧绋戦悧鍡涙嚐閻旂厧绀冩繛鍡樻尵鐢盯鎮规担闈涒偓鏇犺姳閹惰姤鍤岄悹鍥囧懐顦?
      //   闂?64闁?4 闂備緡鍙忕徊鑲╃博閺夋埈娼伴柕澶堝€楅璇测槈閹绢垰浜炬繝銏″劶缁墽鎲撮敃鍌涙櫖鐎光偓閸愵亞顔?`state.imageColor`闂佹寧绋戦悧鎰板磿濡ゅ懎鐤炬い鏍ㄨ壘缁插潡鏌″鍥ㄧ効濠㈢懓锕弫宥嗗緞閹邦剙骞嬫繛鏉戝悑閻喚绮╃€靛憡灏庨柧姘€规稉銏ゆ煏?
      //   缂傚倸鍟崹鍫曟偋缁嬪簱鏀﹂柟閭﹀幖閻熷繐鈽夐幘宕囆㈤柛鈺佺焸瀹曪綁顢旈崘顏嗙崶闂備緡鍋€閸嬫捇鏌?闁诲骸婀遍崑鐐差渻閸屾鐔兼晬閸曨厔鍥箹鐎涙ɑ绀€婵?闂佹寧绋戦張顒€危?*闂佸憡鐟崹璺侯瀶妞嬪海妫?*闂佹眹鍔岀€氬摜妲愬┑鍥┾枖鐎广儱鐗滈崵澶愭煙闁垮澧柣蹇旂箞瀹曪綁寮介鈧ˉ蹇涙煏?
      try {
        meshPm = await imageSource.createPixelMap({
          desiredSize: { width: SRC_EDGE, height: SRC_EDGE },
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
          editable: true
        });
      } catch (meshError) {
        const me = meshError as BusinessError;
        Logger.warn(PlaybackPage.logTag,
          `mesh source decode failed, code=${me?.code}, message=${me?.message}`);
      }
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(PlaybackPage.logTag,
        `createPixelMap failed, code=${err?.code}, message=${err?.message}`);
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    } finally {
      try {
        imageSource.release();
      } catch (error) {
        const err = error as BusinessError;
        Logger.warn(PlaybackPage.logTag,
          `imageSource.release failed, resourceId=${song.label.id}, code=${err?.code}, message=${err?.message}`);
      }
    }

    if (pixelMap === undefined) {
      return;
    }

    if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
      this.releasePixelMapQuiet(pixelMap);
      return;
    }

    await new Promise<void>((resolve: () => void) => {
      effectKit.createColorPicker(pixelMap,
        (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
          try {
            if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
              return;
            }
            if (error || colorPicker === undefined) {
              const msg =
                error ? `${(error as BusinessError).code} ${(error as BusinessError).message}` : 'no picker';
              Logger.error(PlaybackPage.logTag, `createColorPicker failed: ${msg}`);
              this.state.imageColor = PlaybackPage.defaultImageBgColor;
              return;
            }
            const color = colorPicker.getLargestProportionColor();
            const colorArr = ColorConversion.dealColor(color.red, color.green, color.blue);
            const r = clampRgbByte(colorArr[0]);
            const g = clampRgbByte(colorArr[1]);
            const b = clampRgbByte(colorArr[2]);
            this.state.imageColor = `rgba(${r}, ${g}, ${b}, 0.4)`;
            // 闂佸憡鑹炬總鏃傜博閺夋垟鏋庨柍銉ュ暱缁插潡鏌ょ涵鍛毢婵炲牊鍨圭槐鎺楀箻鐎甸晲鍑芥俊鐐€曢幖顐︽偨椤愩倗涓嶆俊銈勮兌閵堬箓鏌涜箛鎿冩Ъ濠㈢懓锕弫宥呯暆閳ь剙銆掗悜钘夌濠㈣泛锕ら弲娆戔偓鐐瑰€涘銊х博鐎涙鈻?ColorPicker 闂佹眹鍔岀€氼剛妲愰幋锔界叆闁?
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });

    if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
      this.releasePixelMapQuiet(pixelMap);
      return;
    }

    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋掓穱铏规崲閺嶎厽鐓傞悘鐐舵閺傃囨煛婢跺牆鍔滄俊鍙夋倐婵″鈧懓纰乫fectKit.blur(imageBlurRadius())` 婵☆偅婢樼€氼厾鎲伴崱娑樿摕闁规崘灏欓杈┾偓娈垮枤婵絻鍟紓?PixelMap
    //   闁荤姍鍐惧剳缂?`imageLabel` 閻熸粎澧楅幑渚€宕曞Δ鍛柧妞ゆ牗姘ㄦ穱娲煕閵夈倕瀚庨柍褜鍓欑粔鏌ュ焵椤掆偓閸婁粙宕曞Δ鍛柧妞ゆ牗绋掗弳顓㈡煙鐎涙ê濮囬柣銈呭瀵噣鎳滈惃鍕兌閸栨牗绻濋崒娑樷偓?*闁哄鏅滈悷锕€顭囬婊勫磯妞ゆ牗鑹鹃崵鎺楁煛娴ｈ櫣绡€缂傚秴顑夊畷鎴濐煥閸涱喗娈?* 闂佺偨鍎查弻锟犲焵?
    //   `imageLabel` 婵烇絽娲︾换鍐偓鍨⒐缁?`song.label`闂?*闂佸憡顭囬崰搴綖閹邦喕鐒婂〒姘ｅ亾婵?Resource**闂佹寧绋戦¨鈧紒?
    //   闂?{@link originalCoverSource} 婵炲瓨鍤庨崐妤冨垝娴煎瓨鍤勯悘鐐靛亾閻濐垶鎮?+ 缂傚倷绀佺€氼亜鈻庨姀銏㈡／?`.blur()` 闂佸憡顭堥褔鎮块崟顖氱睄闁煎摜娈戞担鍝勫濠电偛绨遍崑?
    //   闁荤喐鐟辩徊鍧楁偉濠婂牆绀勯柣鎴炆戦梽宥夋煟?PixelMap 闂佸憡鐟禍婵嗭耿閸ヮ剙绀夐柍銉ㄥ皺閼规儳鈽夐幘绛硅含婵為棿鍗抽弻鍥晲閸♀晛浠归梺鍛婄懄閻楃偞绔熸繝鍥ㄦ櫖鐎光偓閳ь剟寮妶鍥ｅ亾閻熸媽瀚扮€规挸妫楅锝夊礃閿旂懓浜?
    //   闂佸疇娉曟刊瀵哥箔?婵＄偑鍊曢幖顐︽偨椤愩倖鍠嗛柨婵嗘缁旀潙鈽夐幘顖氫壕婵炴垶鎼╂禍顏勨枔閿濆绠栭柨婵嗙箳缁愭霉閻橆喖鍔氬褏濮烽幃顕€顢曢敃鈧▍鐐烘煛閳ь剟宕滆閻ｈ鲸鎱ㄥ┑鎾剁ɑ婵?濠殿喗绻愮徊钘夛耿椤忓洢浜归柟鎯х－娣囨椽鏌涢妷褍浜鹃悷鏇炴瀵骞橀懜鐢垫殸闂備緡鍙忕徊鐣屾?PixelMap"
    //      闂佹寧绋戦悧鍛箔閸涱厸鏋庨柍鈺佸暙鎼村﹥鎱?婵＄偑鍊楅弫璇差焽娴兼潙纭€婵繂鏈粊浼存煛?`releaseBackgroundCoverIfPixelMap()` 婵炴潙鍚嬪畝鎼佸闯閹绢喖缁╅柟顖嗗懏娈滈梺鎸庣☉椤р偓缂?
    //      闂佺粯绮嶅妯猴耿?`imageLabel` 闂佽鍘界敮濠勬嫻?Resource 闂?**闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本鐟ч悷婵嬫煕閹邦剛校閻庡灚妫冨鍨緞婢跺搴婃繛杈剧稻濞叉垹妲愰幍顔藉仏妞ゆ劧绠戝▍鐐烘煛閳ь剟宕滆閻ｅ崬霉閿濆懐孝婵?*闂?
    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋掔喊宥咃耿娴兼潙鎹?闂佸憡鍔曢幊鎰版偪閸℃瑤鐒婂〒姘ｅ亾婵為棿鍗抽幆?64闁?4 缂傚倸鍟崹鍫曟偋缁嬪簱鏀﹂柟閭︿簽閻﹀秴霉濠у灝鈧洟宕甸銏犲偍濞村吋鐟х粈鍕煠閸愬弶婀版繛鍛懅娴狅箓宕掑鍕闂佹寧绋戦¨鈧紒?
    //    闁诲海鎳撻崯鏉库枔閹达附鍋ㄩ柣鏃堟敱閸ゆ帡鏌涘☉鏍у婵犫偓閿熺姴缁╅柛锔诲幗閺?`meshSrc` 闂佸綊鏅查悞锕€锕㈡笟鈧弫宥夊醇閻斿嘲绨ュ┑顔界箓閺堫剙顪冮崒鐐寸厒濠电姴鍟弶鐟扳槈閹剧姊楃紒鏃€娼欓锝夋偑閸涱垳顦柣?`publishMeshSource`闂佹寧绋戦ˇ顓㈠焵?
    this.publishMeshSource(meshPm);
    this.releasePixelMapQuiet(pixelMap);
  }

  /**
   * 闂佺娉涢敃銈夋儍濠靛顥堟い顐幘缁夋挳鏌涢妷锕€鍔ゅù鐘崇洴楠?*缂傚倸鍟崹鍫曟偋閹间焦鍤勯悘鐐靛亾閻濐垶鏌ｉ妸銉ヮ仾缂?*濡ょ姷鍋炲﹢鐟邦潩閿斿墽纾兼繛鍡樺笒閸撳綊鏌￠崪浣哥仩闁活亙鍗虫俊?
   *
   * 闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦鍋勭徊鍧楁煕閵夛箑鍔ょ憸鐗堢☉椤曘儵宕熼崜浣侯槱`闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暙閸撳綊鏌?MeshGradient婵炴垶鎸搁幊淇hSource闁诲氦顫夊銊┾€?md` 闁? / 闁?闂佹寧绋戦¨鈧紒?
   * ```
   * 64闁?4 RGBA_8888闂佹寧绋戦悧鍡氥亹閼碱剛纾介柡宥庡墰鐢棝鏌?
   *   闂?enhanceColors(u8)                              婵炶揪绲芥鎼侇敋椤斿す?/ 婵°倕鍊归敃銏ゅΧ闁秴妞?/ 闂佺顑呯换鎴濃枔椤愶附鏅柛顐ｇ箘缁夊ジ鏌ら崘鍙夋拱婵炲懏鐟︾粙澶婎吋閸℃娼甸梺鍛婃尭缁夐潧鈻嶅▎鎾存櫖?
   *   闂?boxBlurRgba(u8, 64, 64, 9, 3)                  闂佺儵鏅滅敮鎺旀閳ユ緞鐔兼晬閸曨厔鍥煥濞戞ɑ婀版俊?gamma
   *   闂?闂佹悶鍎抽崑娑㈠疮?PixelMap闂佹寧绋戞總鏂款潩閿斿墽纾?MeshCoverBg闂佹寧绋戦悧蹇曠礊婢舵劕鍐€闁稿繐鍚嬮弶鐟邦熆閸棗娲﹂幊娆愮節婵炵偓顫夌紒?
   * ```
   * 闂佸疇娉曟刊瀵哥箔?`enhanceColors` 闂備焦褰冮惉鐓庘枔?`0.4` 婵?`闁?` 闂?*闂備焦婢樼粔鎾€冨鍫熷剭闁告洦浜為閬嶆倵?*闂佹寧绋戦懟顖炲春閸℃稑鐭楁い蹇撴噺閺嗩厼鈽夐幘顖氫壕婵炴垶鎼╂禍椋庢濞嗘劕顕辨慨妯虹－缁犳牠鏌￠崶銊х畺闁搞劊鍔戝畷锝夊箣閻樿京绀傞梺鎸庣☉椤︻參鍩€?
   * 闂佸疇娉曟刊瀵哥箔?闂佸搫鍊绘晶妤€螞椤愶絿顩查柕鍫濇缁傚苯顪冮妶鍛儓缂侇煈鍙冮弫?*闂佺绻愰悧鎾诲闯閹绢喖缁╅柛娆嶅劤閻熸劕鈽夐幘顖氫壕閻庢鍠氭慨浼村焵椤戣法顦﹂柛鐔插亾闁荤姍鍐惧剰闁逞屽墰閸樠囨嚐?`++meshSrcVersion`** 闂佺偨鍎查弻锟犲焵?
   *    `MeshCoverBg` 闂?`@Monitor` 闂佺儵鏅滈崹鐢稿箚婢舵劖鍎嶉柛鏇ㄥ墯绗?*闂佺粯顨呴悧濠傦耿娴兼潙鐭?*闂佹寧绋戝濉抜xelMap` 闂佸憡顭囬崰搴★耿閹绢喖缁╅柣鐔告緲閺佸爼鎮楄ぐ鎺嗗亾濞戞氨鎲规繛鏉戝悑娣囬缚顤傞梺鍛婄懄閸ㄧ敻宕哄☉銏犳閻㈩垼鍠氱粈鍡涙煏?
   */

  private publishMeshSource(pm: image.PixelMap | undefined): void {
    if (pm === undefined) {
      return;
    }
    try {
      const bytes: number = pm.getPixelBytesNumber();
      const buf: ArrayBuffer = new ArrayBuffer(bytes);
      pm.readPixelsToBufferSync(buf);
      const u8: Uint8Array = new Uint8Array(buf);
      enhanceColors(u8);
      boxBlurRgba(u8, SRC_EDGE, SRC_EDGE, PlaybackPage.MESH_BLUR_RADIUS, PlaybackPage.MESH_BLUR_PASSES);
      pm.writeBufferToPixelsSync(buf);
      // 鈽呪槄鈽呪槄 2026-10-17锛堝瓙浠ｇ悊瀹氫綅 + gemini 澶嶆牳锛夛細**鎶婂鐞嗗ソ鐨?64脳64 瀛樿繘璺ㄩ〉闈㈢紦鍐?*
      //   鍦ㄦ涔嬪墠 `meshBuf/meshBufKey` 鍏ㄤ粨**鍙湁璇汇€佹病鏈夊啓**銆乣adoptCachedMesh()` **闆惰皟鐢ㄨ€?*
      //   鈬?姣忔鎵撳紑鎾斁椤甸兘瑕佷粠 HTTP 涓嬭浇灏侀潰鍐嶈В 64脳64锛岃€?鐐瑰嚮鎵撳紑"鐨勫舰鍙樺彧鏈?350~400ms
      //   鈬?鏁存褰㈠彉鎷夸笉鍒扮湡婧愶紝灞忎笂鏄?`makeFallback()` 鎸?title|singer 鍝堝笇鍑烘潵鐨勮壊鐩?
      //   = 鐢ㄦ埛鍙嶅鎶ョ殑銆岀偣鍑诲睍寮€鑳屾櫙杩樻槸鏈夐棶棰?/ 棰滆壊涓嶅銆嶃€?
      //   鈿狅笍 瀛?*瀛楄妭**涓嶅瓨 PixelMap锛堣法椤?release 浼氬弻閲婃斁锛涢潤鎬?PixelMap 缂撳瓨瀹炴祴浼氭樉绀轰笂涓€棣栵級銆?
      const warmKey: string = this.currentMeshKey();
      if (warmKey.length > 0) {
        PlaybackPage.meshBufKey = warmKey;
        PlaybackPage.meshBuf = u8.slice();
      }
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag, `mesh source build failed code=${e?.code}, message=${e?.message}`);
      this.releasePixelMapQuiet(pm);
      return;
    }
    const old: image.PixelMap | undefined = this.meshSrc;
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`MorphGuard` 闂?闂備焦婢樼粔閿嬬珶婵犲嫧鍋撻悷閭︽█婵炵鍊楃划锝呂旈埀顒冦亹?闂佹寧绋戦¨鈧紒杈ㄥ閵囨劙濮€閻樿尙绉柣鐐寸◤閸庨潧螞鐠恒劍宕夐柟瀵稿У缁插鏌ｉ妸銉ヮ仾婵＄偛鍊垮畷?*婵炴垶鎸哥粔闈涚暦閺屻儲鍤勯悘鐐靛亾閻?*
    //   闂佹寧绋戦悧濠傜暦閺屻儲鍤勯悘鐐靛亾閻?= 闂佽桨鐒﹀娆撴儑閹殿喚纾鹃柟瀵稿仧婢规劙姊洪幓鎺斝ら柡渚€绠栭弫宥呯暆閸愮偓缍嗛梺瑙勫閸犲骸顫濋妸鈺佸強?闂佸憡鏌ｉ崝搴ㄥ极閻愵剛鈻旀い鎾噰閸嬫捇寮崶褍澹掗梺鍝勬媼閸ㄥ灚绔熸繝鍕磯闁稿繐鎳愰鍗炩槈?闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婂鎮伴妷鈺佺煑闁挎繂鐗忕粻鏍煕濡鍤欓柟顔筋殜閹虫盯顢旈崟顐嶆鎮跺☉鏍у姍缂佹鍊垮鐢稿焵椤掑嫬瑙﹂幖瀛樼箘椤忚鲸绻涢崰鈩冨閸?
    // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*缂備焦顨忛崗娑氱博閺夋埈鍤曢柣妯虹－閻栬京绱撴担鍦畱缂佹顦遍幏瀣潰瀹€濠冭晧闁哄鏅滈悷鈺傜閸撗呯幓婵°倐鍋撶憸鐗堢洴楠炴帡濡搁妸褏顔?* 闂佺偨鍎查弻锟犲焵?婵烇絽娴傞崰姘跺极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓惉濂稿磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸嬫挻绻涚仦绋垮⒉婵犫偓娓氣偓閹虫浠﹂悙顒傚讲闂侀潧妫楃粙鍕?
    //   `old === undefined` 闁荤偞绋忛崝搴ㄥΦ濮樼偨浜归柟鎯у暱椤?*闂佸搫绉烽～澶婏耿閺夊簱鏌﹂柍鈺佸暞缁犳帞绱撻崘鈺佺仸闁绘顭堥埞?*闂佹寧绋戦悧蹇涘磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸嬫捇姊洪銊у缂佹梹鎸冲畷姘節濮樸儮鍋撴径鎰棃闁靛繒濮撮悘鐘绘煙缁嬪灝鈧棄霉閸ヮ剙违濞达綀顕栭崝鈧梺闈╄礋閸斿繗顣鹃梺娲诲枙缁躲倗妲愬璺何?
    //   闁哄鏅滈悷褔锝為幒妤€绫嶉悹楦裤€€閸嬫挸鈻庤箛鎾存珒"缂備焦绋戦ˇ顖炴偩閵娾晜顥堟繛鍡樺灩瀹曞爼鏌涘▎娆戠К缂佽鍟村畷?闁诲繐绻愬畷顒冦亹瑜斿畷婊堝煛娴ｇ绠查柟鐓庣摠濞叉牞銇愰崶顒€鍐€闁汇値鍨伴ˉ蹇涙煥濞戞澧曢柣?alpha 闂?闂佸憡顨呴敃顏堝焵椤掆偓缁绘垵危閹达附鏅璺烘濞?闂佹椿娼块崝宥夊春濞戙垺鍎戦悗锝庝簻閻撳倿鏌ｉ妸銉ヮ仾婵?
    //   濠电偛澶囬崜婵嗭耿娓氣偓閹虫浠﹂悙顒傚讲闂侀潧妫楅崐鐢稿闯?缂備焦顨忛崗娑氱博閺夋埈鍤曢柣妯虹－閻?*缂備焦鏌ㄩ鍛村春閵忋倕绠甸柟閭︿簼閸?*闂佹寧绋掔粙鎴ｃ亹瑜斿?闂佸搫娲︾€笛冪暦閹绘帩鍟呴柛娆忣槹缁犳帗绻?闂佸綊娼х粔鐑芥憘鐎ｎ剛鐜绘俊銈傚亾鐟滅増鐩弫宥夊醇閵夈儰绨奸梺褰掓涧缁夐潧危?闂佸憡鏌ｉ崝搴ㄥ极閻愵剛鈻旀い鎾噰閸嬫捇寮崶鈺佸姕闂?闂佹眹鍔岀€氼剙鈹冮埀顒勬煛閸滀礁鐏茬紒杈ㄥ哺婵?
    if (old !== undefined && this.colorApplyWaitOrRetry() > 0) {
      const dropped: image.PixelMap | undefined = this.pendingMeshPm;
      this.pendingMeshPm = pm;
      if (dropped !== undefined && dropped !== pm) {
        this.releasePixelMapQuiet(dropped);
      }
      return;
    }
    this.commitMeshSource(pm, old);
  }

  /**
   * 闂佺娉涢敃锔剧礊婢舵劕鍐€闁稿繗鍋愰悥閬嶆煟椤忓棗鏋戞い鎺撶矒楠炴劙宕掑▎鎴犳啰闂佸憡眉缁鳖喚妲愬顤唋ink publishMeshSource} 闂?闂佸湱绮崝鎺戭潩?闂備緡鍙忕徊钘夌暦閹扮増鏅璺虹墐閸?
   * @param pm 闂佸搫鍊规竟鍡椻枔閹寸姷纾鹃柟瀵稿仧婢规劖绻濊閸斞呮濞嗘挸绠ラ柍褜鍓熷鍨緞鐎ｎ偆绉柡澶屽剱閸撴稐绨虹紓鍌欑劍閻燂箑锕㈤悧鍫涗簻缁炬澘顦辩粈?
   * @param old 闁荤偞鍑归崑鍛瑰☉銏犵闁靛繆鈧磭顏遍梺姹囧妼鐎氼厼螞椤愨懇鏀﹂柟鏉垮缁€鍕⒒閸垹浠ч柍瑙勭墵瀹曟艾鈻庨幘铏彽闂佽　鍋撻柟鎯ф噽缁€?
   */
  private commitMeshSource(pm: image.PixelMap, old: image.PixelMap | undefined): void {
    this.meshSrc = pm;
    this.meshSrcVersion = this.meshSrcVersion + 1;
    // ★ 2026-10-18：记下这张图**归属哪一首**（`dropMeshSourceForTrackChange` 与 adopt 守卫都用它）。
    this.meshTrackKey = this.currentMeshKey();
    if (old !== undefined && old !== pm) {
      this.releasePixelMapQuiet(old);
    }
  }

  /**
   * 闁诲海鎳撻ˇ闈涱焽閵堝洨鐜绘俊銈傚亾鐟滅増绋掑濠氬炊瑜嶇粻鐢告煕濮橆剚鍞夐挊鐔封槈閹剧鏀绘繛鎾崇埣瀹曘儲鎯斿┑鍫紘濠电偛妫寸槐鏇犵礊婢舵劕鍐€闁稿繗鍋愰悥?闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥€涒晛螞閵堝鍋╃€光偓閸曨偂绨兼繛鎴炴惄娴滎亪宕抽崫銉﹀珰?濞达絽绉归弫宥夊锤閸撳jie.pa:157930-157939`闂?
   * 闁?`syncReportChrome()` 闂佸搫瀚烽崹浼村箖閹惧鈻旈柍褜鍓氱粋鎺楀嫉閻㈢數娈ら梺?*缂備焦鍔栭〃鍛般亹濞戞瑧鈻旈柍褜鍓氬濠氬炊瑜庨惃鎴︽煙鐠虹尨鏀绘繛鎾崇埣瀵剚瀵奸弶鎴濊祴闂佽偐顢婄亸顏囨＂婵炴垶鎸搁敃銈夌嵁?*闂?
   * 濠电偛澶囬崜婵嗭耿娴ｅ壊鍤楅柛娑樺彄婢舵劖鍎嶉柛鏇ㄥ墰閻栭亶鏌￠崘顓炵厫婵℃彃鎽滅划姘舵倻濡粯鍎ユ繛杈剧稻閸ゅ酣鍩€?
   */
  private republishMeshSourceIfAny(): void {
    const pending: image.PixelMap | undefined = this.pendingMeshPm;
    if (pending === undefined) {
      return;
    }
    this.pendingMeshPm = undefined;
    this.commitMeshSource(pending, this.meshSrc);
  }

  /** Downloads an online cover url and decodes it into a PixelMap (best-effort). */
  /**
   * 婵炴垶鎸撮崑鎾寸箾閸″繆鍋撻懠顒傛啴闁哄鍋涢埀顒傚晿閹烘绀勯柧蹇氼潐閻ｅ崬鈽夐幘鍗炩偓鏇犳閼稿灚濯寸€广儱鎳忕粋鍫ユ煥濞戞瑨澹橀柛娆忕箳娴滄悂宕崟闈涙闂佹寧绋戦悧濠勭矈閿曞倸绀傚璺猴工缁插潡鏌ょ涵鍛毢闁轰降鍊濋弫? **64闁?4 缂傚倸鍟崹鍫曟偋缁嬪簱鏀?*闂佹寧绋戦悧鎰板磿濡ゅ懎鐤炬い鏍ㄧ矋閺嗗繘鏌ㄥ☉姗嗘Ф闁?
   *
   * 闂?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛伇婵炲牊鍨垮畷锝夊冀瑜庣粋鍫ユ煕濞嗘瑧鍒扮紒鍓佸仱閺佸秵寰勫☉姘辩崶闂?64闁?4 闂備緡鍙忕徊鑲╃博閺夋埈鍤曢柣妯挎珪閺夊綊鏌?*闂佸憡鑹炬總鏃傜博閺夋垟鏋庨梽鍥暰闂?*闂備焦褰冮懟顖炲吹椤撱垺鏅?
   *   婵炴垶鎸哥粔瀵告崲閳ь剙鈽夐幘鑽ょ窗闁稿孩顨婂鏌ヮ敍濮橆剚娅冩繛鎴炴尭椤戝牆霉閸ャ劎鈻旈柍褜鍓熼弻鍡楊吋閸涱垱顔堥梻鍌氱墱濞煎潡鍩€椤戣法绠筪esiredSize` + `editable` 闂佸搫瀚烽崹鎵崲閳ь剙顪冮妶鍫濆惞婵?闂佺偨鍎查弻锟犲焵?
   *   缂傚倸鍟崹鍫曟偋缁嬪簱鏀﹂柟閭﹀灱濞诧綁鏌?64闁?4 婵炴垶鎸搁敃銈囨暜椤愶箑鎹堕柡澶娿仒缁?`enhanceColors` / `boxBlurRgba`闂佹寧绋戦悧鎰帮綖?`publishMeshSource`闂佹寧绋戦ˇ顓㈠焵?
   */
  private static async loadOnlineCoverPair(url: string): Promise<CoverDecodePair> {
    const out: CoverDecodePair = new CoverDecodePair();
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 15000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        return out;
      }
      const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        out.full = await src.createPixelMap();
        out.mesh = await src.createPixelMap({
          desiredSize: { width: SRC_EDGE, height: SRC_EDGE },
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
          editable: true
        });
      } catch (err) {
        const e = err as BusinessError;
        Logger.warn(PlaybackPage.logTag, `online cover decode failed, code=${e?.code}, message=${e?.message}`);
      } finally {
        src.release();
      }
      return out;
    } catch (_err) {
      return out;
    } finally {
      req.destroy();
    }
  }

  /**
   * @returns 閻熸粏鍩囬崹纭呫亹婢跺备鍋撻崷顓熷殌婵炲懏甯￠幆?*婵°倕鍊归敋閻?*闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁俊顖滅帛閸╁倿姊婚崒姘辨憼婵?缂備焦姊归悧婊兠虹捄銊﹀晳濞达絿顭堥ˉ鍛磼閹邦収娈旂憸?闂佹寧绋戦悧鍡氥亹瑜斿Λ渚€骞撻幒鎴炵様婵炴垶鎸搁敃顏勵焽閻楀牊浜ゆ繛鍡楁捣椤忛亶鏌℃径鍡橆潐缂佽鲸宀搁弫?
   *          闂佺绻戝﹢鍦礊閹达箑绫嶉柛顐ｆ礃閿涚喖鏌熼鐔风瑐閻?`'100%'`闂? 婵炴垶鎸哥€涒晠鎯€閸涙潙瀚夊璺烘捣缁犵懓鈹戦崒娑辨當濠殿喒鏅犻幃鐣岀磼濡椿妲梻渚囧亝閸旀洟宕曞杈潟闁绘浜閬嶆煠閻ゎ垱褰х紒杈ㄥ哺婵?
   *
   * 闂佸疇娉曟刊瀵哥箔?闂傚倸鐗婇悷锕傤敆濞戙垹绠?*闂婎偄娲ら幊姗€濡?*缂?`'100%'` 闂佸吋婢樻總鏃傜箔婢舵劕鍙婃い鏍ㄧ懄瀹曟彃霉閿濆棙绀堥柣锝咁煼瀹曟瑩鎮滃Ο濠氭闂佹眹鍔岀€氼參寮抽悢琛″亾濞戞瑯娈ｇ紒杈╁缁嬪﹦鈧綆浜滈·鍛存煟椤剙濡奸柣銈呭闇夐悗锝庡墯閻?
   *    `contentHeightVp` 閻熸粎澧楅幑鍥ь焽閵堝拋娼伴柕蹇嬪€楄ぐ顖炲箹鏉堟崘顓虹紒杈ㄧ箞閹虫挾浠﹂懖鈺冩啰闂佺缈伴崕鑼姳椤曗偓楠炰線寮剁憗銈呬缓闂?*闁哄鏅滈悷銉╂儑娴煎瓨鍤婃い蹇撳缁犳帡鎮跺鐓庝函妞ゃ儱妫濆畷婊堫敂閸涱噮妲梺姹囧妼鐎氫即鎮甸鑺ュ劅?*闂?
   *    婵炴垶鎸撮崑鎾寸箾閸″繆鍋撻懠顒傛啰闂佺懓鍢查ˇ顔剧不閿濆瑙﹂幖娣€楃粻鐟扳槈閹垮啩绨婚柍褜鍓涢崢褍顫濋妸褎鍋栨い鎰╁灩閺呮悂鏌?~360vp闂佹寧绋戞總鏃傝姳椤掑嫬鍙婃い鏍ㄧ〒濡层劍绻涢崱蹇撳⒉濠⒀嶇畱椤曪綁鍩€椤掑嫬绠绘い鎾跺枑閺夌懓顪冮妶澶嬫锭缂併劍濞婇弻鍫ュΩ閳轰礁骞嬬紓鍌氬€藉銊х博閹绢喖閿?
   *    闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎忕€殿喛濮ら敍鍐醇椤掑倻顦梺闈涙閸婅鈻嶉妸鈺佺闁糕剝顭囧Σ宄拔旈崒娴㈩亞鈧濞婇幃鑺ユ綇閳轰胶鍘柣搴℃贡閹虫挸鈻嶉幒妤佹櫖闁割偆鍠庢慨顒勬倶閻愯尙绠版い鏃€鐗楃粙澶嬪濞嗘垹顦梺鍛婂姇閸熷潡鎮炬ィ鍐╂櫖閻忕偠鍋愰悷婵嬫煕濞嗘ê鐏ラ柛蹇旑焽缁螖閸涱喗娅撻梺?
   */
  /**
   * @returns 閻熸粏鍩囬崹纭呫亹婢跺备鍋撻崷顓熷殌婵炲懏甯￠幆?*婵°倕鍊归敋閻?*闂? 缂備焦姊归悧婊兠虹捄銊﹀晳濞达絿顭堥ˉ鍛磼閹邦収娈旂憸鐗堢洴閺佸秵寰勫☉姘辩崶闂傚倸鐗婇悷锕傤敆濞戙垹绠?`'100%'`闂佹寧绋戦悧蹇涙偤閹寸偟顩烽柧姘€婚懝鎯р槈閹惧磭啸妞ゃ儱妫濆畷婊堫敂鎼达絿顦梺?
   *
   * 婵炴垶鎸哥粔纾嬨亹婢舵劖鐓傞煫鍥ュ劤缁愭鎮锋担椋庮槮濠㈠厜鍋撴俊銈呭€归敋閻?= 闂佸憡鐟崹鐢革綖鐎ｎ偒娈楁俊顖氭惈椤?/ 缂傚倸鍊甸弲婊堝棘?闂?闁诲繒鍋涚换瀣箔閸岀偞鐒介柨婵嗘噺閸嬨儵鏌涘▎妯虹仴妞ゎ偄顑夐幆宀勫煛娴ｈ棄鐓傞梻?*濠殿喗绻愮徊浠嬪Χ?*闂佸搫瀚烽崹閬嶅汲閿濆棎浜滅痪鏉款槺缁€?
   * 闂佸搫鍟ㄩ崹娲儉閸涙潙瀚夊璺烘湰濞堝矂鏌ｈ閺嬭崵妲愬▎鎴犵當妞ゆ巻鍋撴繛鍙夋崌閹?婵帗绋掗崹褰掓偘閵夆晛鐭楅柨婵嗙箳缁€澶娾槈閹垮啫寮俊顐ｅ缁嬪鍩€椤掍胶鈻旀い蹇撳濮ｅ牓鏌熺紒銏犲箺闁哄倷鐒﹂妵?闁诲繐绻楁ご绋课ｉ幖浣瑰仼婵炲棙鍨堕銈夋煥濞戞﹩妾х紒杈ㄧ箖缁嬪﹪鎮㈤崫銉︹挄闂佸搫鐗嗛ˇ鎶剿夐崱娑樼闁搞儯鍎崑?
   * 闂佸疇娉曟刊瀵哥箔?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝呮憸缁犳垵顪冮妶鍫濆惞缂?`'100%'` 闂佸吋婢樻總鏃傜箔婢舵劕鍙婃い鏍ㄧ懄瀹曟彃霉閿濆棙绀堥柣锝咁煼瀹曟瑩鎮滃Ο濠氭闂佹眹鍔岀€氼參寮抽悢琛″亾濞戞瑯娈ｇ紒鍙樺嵆閹倿骞嗚閻庣粯鎱ㄩ敐鍡樷拻闁轰礁宕…銊╁灳瀹曞洦缍勯柣搴ｆ嚀閵囨鈧潧鐭傚畷姗€宕橀懠顒佹瘞闂?
   *    婵炴垶鎸哥粔宕囨閹殿喗鍋栨い鎰剁悼閸樻瑦绻涢崱蹇婂亾鐎圭姴鐓傞梺鍛婄懄椤洤鈻撻幋鐐碘枖妞ゆ挶鍨洪敍鐔兼煙椤戣法顦﹂柛鐔告崌閹虫绠涢妷褏顦?闁圭厧鐡ㄥú鐔煎磿鐎靛摜纾介弶鐐村椤忛亶鏌?闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棗娴烽悿鍕煛婢跺牆鍔ゆ繛鍫熷灴閺佸秵寰勯崼姘壕?
   */
  private morphClipHeight(): Length {
    if (!this.expandState.morphClipping()) {
      // 闂佸疇娉曟刊瀵哥箔瀹ュ鐓ｉ柣娆忔噽閻?2026-10-17闂?*闂佹椿娼块崝宥夊春濞戞氨绠?1/2 闂?闁荤偞绋忛崕闈浳涢崹顔规煢闁斥晛鍟粻鎺楁煕閺傝濡块柡?闂佹眹鍔岀€氼剟鍩€椤掍胶鎳囬柍褜鍓欓ˇ鏉库攦閳ь剟鏌?*闂佹寧绋戦¨鈧紒?
      //   闁哄鏅滈悷鈺呭闯閻戣棄鍌ㄩ柣鏂挎啞闂?*闂佸搫鍟版慨闈涱焽椤栨稓顩烽柟顖涘缁犳煡鏌?`'100%'`闂佹寧绋戦悧鍡涙偤瑜忕划顓㈡晜閼愁垼娲梺?*闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎳滄导鏉戠煑婵☆垳绮崺鍌炲级閳哄倹鐓ユ繛鍙夌墵閹啴宕熼浣?*闂佽桨鐒﹀姗€鎮?*
      //   闂?`.height()` 闁哄鏅滈悷銈夋煂濠婂懍娌柣鎰ˉ閸嬫捁顦叉繝鈧?*闁诲孩绋掗〃鍫ヮ敄娴ｅ湱鈻?闂?闂佽桨鐒﹀姗€鎮鸿缁嬪﹦鈧綆鍠楅敍鐔兼煕閹烘垶澶勭€规洝灏欓悮鍓ф嫚閼碱兘鍋?*闂?
      //     ArkUI **闂佸搫鍟版慨鐢垫兜閸洖鎹堕柕濞垮€涢埛鍫㈢磼婢跺﹦肖閻炴凹鍋婂畷鍦偓锝傛櫇椤撴椽姊婚崒姘辨憼鐟滄澘鍟村畷?* 闂?闁荤偞绋忛崕闈浳涢幐搴ｂ枖闁逞屽墰閹秆囨煥鐎ｎ亶鏉归柣?*闂佺儵鏅涢悺銊ф暜鐎靛憡宕夐柛鎰絻閻撳倻绱撴担鍝ュⅱ闁?*
      //     闂佹寧绋戦悧鎰帮綖閸ヮ剙绠?= "闁诲繐绻嬬欢姘焽娴煎瓨鍎庨悗娑櫭径宥夋倶韫囨挸鑸归柛鈺佺灱缁辨帡骞樼€涙ê鐨㈡繛杈剧到缁夊爼鎮?/ 闂佺儵鏅涢悺銊ф暜鐎涙鈻旈悗锝庝簻缁犵敻鏌ㄥ☉妯绘拱闁汇儱鎳樺鍨緞婵犲倐妤呮煟?闂佹寧绋戦ˇ顓㈠焵?
      //   闂?婵炴垶鎹佸銊у垝閸喓鈻?闂佸綊娼ч鍡欌偓鍨皑閹瑰嫰鎮㈢粙娆炬澒闂備緡鍙忕徊鎯ь焽椤栫偛鍙婃い鏍ㄥ搸閸嬨劑鏌?闂佹寧绋掑畝鎼佸磻閸涙潙绾ч梽鍥儗閹灝鎺曠疀鎼达綆浼囬柣銏╁瀻閸パ冨箣闂侀潻璐熼崝宀勫疮?*闂佽桨鐒﹀姗€鎮?*闂佹寧绋戦懟顖炲矗韫囨洜鐭欓悗锝庝簼閸婅京绱掗銉殭闁?闂?
      //   闂?婵炴垶鎹佸銊у垝閸喓鈻曢柛顐秵濞?return 闂佽桨鐒﹀姗€鎮鸿閹虫挾浠﹂懖鈺冩喒闂佸搫瀚烽崹顖滄崲濮樿埖鍋?'100%'闂佹寧绋掑畝绋款焽閵堝拋娼伴柕蹇婃閸嬫挻绗熼埀顒勫磻閸涙潙绾ч柍鈺佸暞閺嗗牓姊洪幓鎺炴敾濠殿垳顥愮粻娑㈠礃椤忓懐鏆犻梺?
      //     "**闂備焦褰冪换鎰板吹椤撱垹绾ч柕澹嫮鏆犻梺鍛婂姇閹冲酣顢欓幇顓ф畻婵☆垰鎼?*婵炴潙鍚嬫穱娲綖閿曞倸钃熼柟閭﹀弾閸嬔呮喐閼割剙鐏╃憸鏉款樀瀹曟ê鈻庨幒鎴濐棈"闂?闁圭厧鐡ㄥú鐔煎磿鐎靛摜纾介弶鐐村椤忛亶鏌?闂佹寧绋戦¨鈧紒?
      //     闂?*缂備焦鍔栭〃鍛般亹濞戞瑯娈楁俊顖氭惈椤?*闂?`reportWindow` 缂傚倷鐒﹂悷褍鈻撻幋锕€绾ч柛鎰╁妷閺嬪棝鏌涙繝鍕靛劆闁逞屽厸濡炴帞绮径鎰煑闁稿本鐟ч悷銏㈡喐閼割剙鐏╃憸?闂?濠电偛澶囬崜婵嗭耿娓氣偓閺屽洭鏁愰崟顖氭疂婵＄偛顑呴柊锝呪枍閹捐违?
      //   闂佸疇娉曟刊瀵哥箔?闁诲骸婀遍幊鎾斥枍閹烘鍋夐柛鎾茬窔閻涙捇鏌￠崟闈涚仭鐎殿啫鍛勃闊洦鎼╅崯蹇撯槈?闂?闂佽桨鐒﹀姗€鍩€椤掑嫭锛熺紒?`winHVp` 闁诲繐绻楁禍顒勬偤閹寸偟顩?`'100%'`闂?
      //     缂備焦鍔栭〃鍛般亹濞戞矮鐒婇柛婵嗗閸ょ喖寮堕埡鍋垫垿鎯€閸涱喚鈻斿┑鐘插暙琚氶梺鍝勫暢椤旀劗妲愬▎鎾冲嚑濞达綀顫夐敍宥夋煛閸垹娅愮紒杈ㄥ哺楠炲秴顓兼径鍡椾壕闁逞屽墴瀹曞爼鎮欓懠顒佹喕缂備焦顨愮紓姘辨啺?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯ｉ幖浣歌埞妞ゆ牗鐟ч閬嶆煟閵娿儱顏х紒鏃€娼欓埢搴ㄦ晬閸曨噮娼堕梺鎼炲妼椤戝懘宕硅箛娑樼妞ゎ偒鍠氱粈?
      //     婵炴垶鎸婚弻銊ㄣ亹閸岀偞鍋ㄩ柣鏃堟敱闊剟鏌￠崼顐㈠⒋闁靛棗顦靛畷姘潩椤撶偟妲搁柡澶屽仜椤洟鍩€椤戞寧绁扮紒缁樻礀閳讳粙鍩勯崘鈺冪暢婵炲濮鹃濠勭礊瀹ュ洦鍋橀柕澶嗘櫆閿涚喖鏌ｉ妸銉ヮ仾婵＄偛鍊垮畷鎰枎瀹ヤ礁浜?
      const h: number = this.expandState.windowHeightVp;
      return h > 0 ? h : '100%';
    }
    return Math.max(1, this.expandState.morphClipHeight);
  }

  /**
   * @returns 「内容列」的高度 —— **恒等于整窗高**（形变期也不跟着裁剪窗缩）。
   *
   * ★★★ 2026-10-18（第六轮「播放器展开过程中底部控件出现过早」· 候选 1 的真身）：
   *   上游 `wujie.pa:191772-191782` 的正文列是 `Column().width(winWVp).height(winHVp)`
   *   —— **固定整窗高**，而裁剪窗是它的**父** `Stack`
   *   （`:191442-191451` `.height(expand.clipHeight)`、`:191462-191469` `.clip(true)`）。
   *   ⇒ 上游的底栏（进度条 + 传输行）挂在**整窗底边**上，形变期 `clipHeight` 还很小 ⇒
   *     它整块落在**裁剪窗外** —— 这就是「无界连进度条都还没出现」的那道**裁剪门**。
   *   ⛔ 本仓这一层原来是 `.height('100%')` ⇒ 高度跟着**裁剪窗**走 ⇒ 底栏永远贴着
   *     裁剪窗的**底边**、裁剪对它**永不生效**（只剩 `pullBottomOpacity` 一道门）⇒ 只要不透明度
   *     一抬头就整块露出来。这与「同一层的背景列早就是固定整窗高」自相矛盾
   *     （见 `MeshCoverBg` 的 `.height(this.expandState.windowHeightVp)`，那一段的注释解释了
   *     "形变期网格画布 = 整窗恒定，卡片长大是被 `clipHeight` **揭开**的"）。
   *   两级高度从此一致：背景列与内容列都固定整窗，只有外层 `Column C` 吃 `clipHeight`。
   */
  private morphContentHeight(): Length {
    const h: number = this.expandState.windowHeightVp;
    return h > 0 ? h : StyleConstants.FULL_HEIGHT;
  }

  // ═══════════ 内容时间线的**逐帧驱动**（对齐上游 `animateMorphT` 的 `onFrame`） ═══════════
  //
  // ★★★ 2026-10-18（用户第十轮：「展开过程中系统返回**直接没动画了**；无界是动画结束才返回」）：
  //   真因是**几何**那条也犯了和下面 `contentP` 一样的毛病 —— `playMorphOpenIntro()` 里
  //   `animateTo({duration:560}, () => { morphP = 1 })` 的闭包把 `morphP` **一次写成 1**，
  //   于是数据面上"进度"从第一帧就是 1：
  //     · `closeFullScreenPlayback()` 的 `closeFromT = morphP` 恒 **1.000** ⇒ 反向时长恒 `460×1`；
  //     · `actionsOpacityAt(1) = clamp(1 − 1/0.20) = 0` ⇒ 克隆层按钮"从全灭直接硬跳全亮"（观感＝两份按钮）；
  //     · 反向那条 `animateTo` 只是把已经到位的终点值再写回胶囊值，**没有真进度可插值**。
  //   上游只有**一个** `morphT`：`createAnimator + onFrame(v) => morphT = v`（`wujie.pa:145608-145661`），
  //   跟手 / 点击打开 / 反向**三条路共用它**；本仓跟手那条（手指写 `applyMorphProgress`）明明是好的，
  //   所以点击打开与反向也改成**同一个逐帧驱动**：几何从 `animateTo` 换成 ticker。
  //   ⚠️ 不要退回 `animateTo`：一旦退回，`morphP` 在数据面上就又是"终值"，反向必然拿不到起点。
  private geoAnimator: AnimatorResult | undefined = undefined;
  private geoFrom: number = 0;
  private geoTo: number = 0;

  /**
   * 起几何补间：`morphP` 从 `from` 走到 `to`。
   * @param from 起点进度（跟手/反向就是"此刻的真实进度"）
   * @param to 终点进度（打开 1、关闭 0）
   * @param durMs 时长（ms；`<= 0` 直接落位）
   * @param reverseCurve 是否用反向曲线 `REVERSE_EASING`
   */
  private startGeoDriver(from: number, to: number, durMs: number, reverseCurve: boolean,
    onDone?: () => void): void {
    this.stopGeoDriver();
    this.geoFrom = from;
    this.geoTo = to;
    const openToken: number = to === 1 ? this.expandState.beginOpenGeometryAnimation() : -1;
    if (durMs <= 0) {
      this.expandState.applyMorphProgress(to);
      if (to === 1) {
        this.expandState.finishOpenGeometryAnimation(openToken);
      }
      return;
    }
    const options: AnimatorOptions = {
      duration: durMs,
      // 上游两条曲线原样交给 animator（`EASE_OUT_STR` / `REVERSE_EASING`），不在这里自己解贝塞尔。
      easing: reverseCurve ? 'cubic-bezier(0.85, 0, 0.5, 0.88)' : 'cubic-bezier(0.23, 1, 0.32, 1)',
      delay: 0,
      fill: 'forwards',
      direction: 'normal',
      iterations: 1,
      begin: 0,
      end: 1
    };
    const anim: AnimatorResult = this.getUIContext().createAnimator(options);
    anim.onFrame = (value: number): void => {
      if (!this.isAlive || this.geoAnimator !== anim) {
        return;
      }
      this.expandState.applyMorphProgress(this.geoFrom + (this.geoTo - this.geoFrom) * value);
    };
    anim.onFinish = (): void => {
      if (!this.isAlive || this.geoAnimator !== anim) {
        if (onDone !== undefined) {
          this.closeDiagnostic('stale-callback-dropped event=geo-finish');
        }
        return;
      }
      this.expandState.applyMorphProgress(to);
      if (to === 1) {
        this.expandState.finishOpenGeometryAnimation(openToken);
      }
      if (onDone !== undefined) {
        onDone();
      }
    };
    this.geoAnimator = anim;
    anim.play();
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMorphGeoTick start from=${from.toFixed(3)} to=${to} ms=${durMs} ` +
        `curve=${reverseCurve ? 'REVERSE_EASING(0.85,0,0.5,0.88)' : 'EASE_OUT_STR(0.23,1,0.32,1)'}`);
  }

  /** 停掉几何补间（幂等）。 */
  private stopGeoDriver(): void {
    if (this.geoAnimator !== undefined) {
      this.geoAnimator.cancel();
      this.geoAnimator = undefined;
    }
  }

  // ★★★ 2026-10-18（同一条反馈的**真因**）：
  //   上游 `MainPage.animateMorphT(to, ms, easing, onDone)`（`wujie.pa:145608-145661`）是
  //   `createAnimator(... primaryAnimator)` + **`onFrame(v) => morphT = v`** —— 每帧写真进度，
  //   而 `effT() = isMorphTarget() ? pullT : 1`（`:171535-171549`）读的就是它。
  //
  //   ⛔ 本仓原来用 `animateTo({duration:560, curve}, () => { contentP = 1 })` 来"补间内容"：
  //     `animateTo` **不会**逐帧插值状态变量 —— 闭包里的赋值是**一次写成终点**，
  //     框架只把由此产生的*可动画属性*（scale/height/opacity/translate…）从旧值补到新值。
  //     更糟的是 `beginContentTween()` 的 `from` 读的是 `this.morphP`，而那时几何那条
  //     `animateTo` 的闭包**已经**把 `morphP` 写成 1 了 ⇒ `from = 1` ⇒ `contentP` 从第一帧就是 1。
  //   ⇒ `pullChromeOpacity()` / `pullBottomIn()` / `pullBottomOpacity()` / `pullBottomYVp()` /
  //     `pullBgIn()` / `metaRiseVp()` / `earlyRiseVp()` / `contentRiseVp()` **全部恒等于终点值**
  //     （1 / 1 / 1 / 0 / 1 / 0 / 0 / 0）—— 所有内容窗口公式**一行都没生效**。
  //     落到屏上：底栏从第一帧就是 100% 不透明、且没有那 200vp 的升入位移，只剩几何在遮它。
  //
  //   ✅ 照搬：内容进度改由 16ms ticker 逐帧写 `contentP = morphEaseY(elapsed / 560)`
  //     （本文件顶部的 `morphEaseY` = `cubic-bezier(0.23,1,0.32,1)` 的 y(x)，与几何那条同源）。
  //     `beginContentTween()` 也已挪到几何 `animateTo` **之前**，保证 `from = 0`。
  private static readonly CONTENT_TICK_MS: number = 16;
  private contentTickTimer: number = -1;
  private contentTickGen: number = 0;
  private contentTickAtMs: number = 0;

  /** 起逐帧内容补间（`contentP` 从 0 走到 1，560ms + EASE_OUT_STR）。 */
  private startContentTicker(): void {
    this.stopContentTicker();
    this.contentTickGen = this.contentTickGen + 1;
    const gen: number = this.contentTickGen;
    const dur: number = PlayerExpandState.MORPH_CONTENT_DURATION_MS;
    this.contentTickAtMs = Date.now();
    this.contentTickTimer = setInterval((): void => {
      if (gen !== this.contentTickGen || !this.isAlive) {
        this.stopContentTicker();
        return;
      }
      const raw: number = (Date.now() - this.contentTickAtMs) / dur;
      const x: number = raw < 0 ? 0 : (raw > 1 ? 1 : raw);
      this.expandState.contentP = morphEaseY(x);
      this.logChromeReveal('tick');
      if (x >= 1) {
        this.stopContentTicker();
      }
    }, PlaybackPage.CONTENT_TICK_MS);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMorphContentTick start gen=${gen} ms=${dur} ` +
        `step=${PlaybackPage.CONTENT_TICK_MS} from=0 ease=EASE_OUT_STR(0.23,1,0.32,1)`);
  }

  /** 停掉逐帧内容补间（幂等；收尾 / 关闭 / 卸载都要调）。 */
  private stopContentTicker(): void {
    if (this.contentTickTimer >= 0) {
      clearInterval(this.contentTickTimer);
      this.contentTickTimer = -1;
    }
  }

  /** `RzdChromeReveal` 的节流窗口（形变期每 50ms 最多一行）。 */
  private static readonly CHROME_REVEAL_LOG_MS: number = 50;
  /** `chromeTotalVp()` 取不到时的兜底底栏高（vp）。 */
  private static readonly CHROME_REVEAL_BLOCK_FALLBACK_VP: number = 160;
  private chromeRevealAtMs: number = 0;
  private chromeRevealKey: string = '';

  /**
   * 形变期「底栏（进度条 + 传输行）可见度」诊断 —— **只在值变化时打**，每 50ms 最多一行。
   * ```
   *   RzdChromeReveal p=<几何进度> in=<pullBottomIn> opa=<pullBottomOpacity>
   *                   y=<pullBottomYVp> clipH=<裁剪窗高> vis=<实际可见度> bh=<底栏高> src=<触发点>
   * ```
   * `vis` = **几何重叠比例 × `opa`**（= 屏上真正的可见度，判据就是看它 `< 0.05`）：
   * ```
   *   blockTop = pageH − bh + y      // 底栏挂在**整窗底边**（上游 Column().height(winHVp)）
   *   geo      = clamp01((clipH − blockTop) / bh)
   *   vis      = geo × opa
   * ```
   * ⛔ 改前这一层是 `.height('100%')` ⇒ 底栏贴的是**裁剪窗底边**（`blockTop = clipH − bh + y`）
   *    ⇒ `geo` 恒 ≈ 1 ⇒ 裁剪门对它失效，只剩 `opa` 一道门（而 `opa` 又恒为 1，见 `startContentTicker`）。
   * grep：`hdc shell hilog -x | Select-String 'RzdChromeReveal'`
   */
  private logChromeReveal(src: string): void {
    const now: number = Date.now();
    if (now - this.chromeRevealAtMs < PlaybackPage.CHROME_REVEAL_LOG_MS) {
      return;
    }
    const st: PlayerExpandState = this.expandState;
    const p: number = st.morphP;
    const inp: number = st.pullBottomIn();
    const opa: number = st.pullBottomOpacity();
    const y: number = st.pullBottomYVp();
    const pageH: number = st.windowHeightVp;
    const clipRaw: number = st.morphClipHeight;
    const clipH: number = st.morphClipping() && clipRaw > 0 ? clipRaw : pageH;
    const bhRaw: number = st.chromeTotalVp();
    const bh: number = bhRaw > 0 ? bhRaw : PlaybackPage.CHROME_REVEAL_BLOCK_FALLBACK_VP;
    const blockTop: number = pageH - bh + y;
    const geoRaw: number = bh > 0 ? (clipH - blockTop) / bh : 0;
    const geo: number = geoRaw < 0 ? 0 : (geoRaw > 1 ? 1 : geoRaw);
    const vis: number = geo * opa;
    const key: string = `${p.toFixed(3)}|${inp.toFixed(3)}|${opa.toFixed(3)}|` +
      `${y.toFixed(1)}|${clipH.toFixed(1)}|${vis.toFixed(3)}|${bh.toFixed(1)}`;
    if (key === this.chromeRevealKey) {
      this.chromeRevealAtMs = now;
      return;
    }
    this.chromeRevealKey = key;
    this.chromeRevealAtMs = now;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdChromeReveal p=${p.toFixed(3)} in=${inp.toFixed(3)} opa=${opa.toFixed(3)} ` +
        `y=${y.toFixed(1)} clipH=${clipH.toFixed(1)} vis=${vis.toFixed(3)} ` +
        `bh=${bh.toFixed(1)} src=${src}`);
  }

  /** Root: 闂佽桨鐒﹂幐鎶藉Υ婢跺瞼纾介柍鍝勫€归弶?+ 缂備焦姊归悧婊兠虹捄銊﹀晳濞达絿顭堥ˉ鍛磼閹邦収娈旂憸鐗堢洴閺佸秹宕煎┑鍡氼唹闁荤喐鐟ュΛ娑㈡偂閳哄嫨浜归柕蹇嬪€曞▍鈩冩叏濠垫挾鍒伴柕鍫滅矙瀵即顢涘☉娆愵啋婵＄偑鍊楅。顔炬? 濠碘剝銇滈崕鑼暜鐎甸晲鐒婂〒姘ｅ亾婵為棿鍗虫俊?*/
  build() {
    // 闂?缂備焦顨忛崗娑氳姳閺屻儲鍋嬮柛顐墰缁?*闂佽桨鐒﹂幐鎶藉Υ婢跺瞼纾介柍鍝勫€归弶?+ 缂備焦姊归悧婊兠虹捄銊﹀晳濞达絿顭堥ˉ鍛磼閹邦収娈旂憸?*闂?
    //   闂佸憡鐟崹鐢革綖鐎ｎ喗鍎楅柍杞版祰閸╁苯霉?*闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹闂佸搫顥￠妶鍛腐闂?*闂傚倵鍋撻柛顭戝枛閻撳倿鏌℃担瑙勭稇闁活偄妫濋弫?闂佽桨鑳剁换婵嬫煂濠婂牆绠绘い鎾跺枑閺夊綊鏌℃径鍡忓亾閾忣偒鍋ㄦ繛鏉戝悑閹倿骞楅棃娑卞殨闁?闂佹寧绋戦¨鈧紒?
    //   婵炴垶鎸搁鍫㈢博閻旂厧鎹堕柕濞垮劚椤?25% 闁诲繐绻楃划楣冨礆濞戙垹绀嗛柡澶嬵儥閸熷繐鈽夐幘璇″殭缂併劏娅曞蹇涙儌閸濄儳顦╅梺鍛婄啲缁犳垿宕归娑欏劅闁哄洢鍨归崝銉╂⒑椤撱劎鍒伴柛銈嗗灴瀹?vp 闂佽桨绀侀悺銊╊敊瀹€鍕闁靛ě鍕瘞闂備緡鍠氶弲顐﹀煘閺嶎厽鍎撻柍褜鍓熼弫宥嗗緞濞戞艾鑰?
    //   闂佸憡鍔曢幊搴敊閹邦喕娌柛宀€鍋熻ぐ顖炲箹?= 闁荤喍妞掔粈浣圭珶閳ь剙螖閸屾耽顏嗏偓?= 闂佸憡鐟崹鐢革綖鐎ｎ偒娈楁俊顖氭惈椤?/ 缂傚倸鍊甸弲婊堝棘娓氣偓閺佸秶浠﹂幆褜鏆℃繛瀵稿О閸庤精銇愰懠顒佸枂闁糕剝鐟ч崣鎰喐閼割剙鐏查柛?*濠殿喗蓱閻℃洜鎹㈠▎鎰畽妞ゆ劧绲芥慨顒勬煛娴ｈ灏﹂柕?*闂?
    //   濠电偛澶囬崜婵嗭耿娓氣偓閹儳鈻庨幋鐑嗕槐闂侀潧妫斿鎺斿姬閸愨晝鈻旂€广儱瀚粣妤呮偠濮樼厧浜い銉ユ閺佸秴鈽夊Ο鐑樻殽闁诲骸婀遍幊鎾绘儑閹殿喚椹冲璺猴工鐠佹煡鎮峰▎蹇旑棤闁绘挴鏅為妵鎰板閻欌偓閸熷秴螖閸屾惮鎴︽儊椤曗偓楠炴帡濡烽妸褏顔呮俊鐐€楅弫璇差焽娴兼潙绫嶉柤鎼佹涧椤ゅ懏绻涢幖顓炴灓妤犵偛娲弫?
    //   闂備緡鍓欓悘婵嬪储閵堝棛鈻旀い鎾跺櫏閸炰粙鏌ｉ鍕靛剰闁糕晛鏈粙澶愬焵椤掆偓椤曪綁鎮╂笟顖涜晧闂佸憡锚椤戝棙鏅舵惔銊﹀剭闁告洦鍨埀顒€顦靛Λ鍐綖椤斿墽顦╅梻渚囧弿缁查箖顢楀鍫濆強?婵炲濮寸花濂告嚈閹达附鈷掗柡澶嬪灩绾捐鈹戦纰卞剭闁逞屽厸閼宠泛锕㈤崨顔锯枖鐎广儱鎳庡В澶愭倶閻愬瓨绀€缂佽鲸鍨跺濠氬炊閳圭偓鐓?闂佹眹鍔岀€氼厼顭囬棃娑掓敠闁规澘澧庣粈鍡涙煏?
    //   闁诲繐绻嬬欢姘焽娴煎瓨鍋ㄩ弶鍫氭櫇閺佹儳顪冪€ｎ剙浠滈柣銊︾箞濡啴濮€閻樿尙顦伴梺缁樼懐閸撴盯鎮界紒姗嗘Ч闁绘垵娲ㄧ粈?*p = 1 闂佸綊娼х粔鐑藉箚閵堝棙濯?*闂?026-10-15 闁荤姍鍛幋闁稿鎳忕粙澶愬焵椤掆偓铻為柟鐑樻⒐閺嗕即鏌?*婵犮垻鎳撻崯鍧楁儑閺夋５褰掝敊閼测晜鍕?*
    //   `Index.MorphCoverClone()` 闂備焦褰冮惌澶屾閻╊棭 婵犮垻鎳撻崯鍧楁儑閻楀牏顩风€广儱鎳忛煬顒勬煛閸偄澧撮柕鍡楊樀閹?`MorphCoverBridge`闂佹寧绋戦ˇ顓㈠焵?
    Stack({ alignContent: Alignment.TopStart }) {
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*闂佺厧鍟块張顒€鈻嶅▎鎾虫瀬闁哄鍨瑰﹢鎾煙绾板崬澧柛鈺佺焷閵囨劙濮€閻樿尙绉柣搴℃贡閹虫挸鈻嶉幒鎾垛枙閻庯綆浜跺Ο?*闂?
      //   闂佸搫鍟版慨鐑藉疾椤愶附鍎?`MeshCoverBg` 闂?`playerPane` **婵炴垶鏌ㄩ鍛此?*闂佹寧绋戦悧鍛箔瀹€鈧埀顒傛嚀閸燁偊骞冮幘鍓佹／鐟滄繄妲愬璺虹劷?闁诲海鎳撻崯鈺冪箔婢舵劕鐭楅柛灞剧懅閻熴垽鏌熺紒銏犲箺闁哄倷鐒﹂妵鍕偨閸偆鏆?
      //   `scale / clip` 闂?闁荤喐鐟ラ崐褰掑礉閸涙潙鍙婃い鏍ㄇ氶崑?*闂佸憡鍔曢幊搴敊閹邦収妲归柣鎰閻熸劙鏌℃径鍫濆姌闁逞屽厸濞村洭宕曞Δ鍛柧妞ゆ牗鐟ч悷婵嬫煕?*闂侀潧妫楃粔鏌ュ焵?
      //   闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹鏌熺捄鐚村伐闁伙絿濞€瀵劑骞嗚闊剛鎲搁懜顒€鐏╃憸鏉款槺閳ь剙婀遍幊鎾斥枍?*闂佸憡鍔曢幊姗€宕?* 闂?闁荤姾娅ｉ崰鎾愁焽閸愵亝鍋栨い鎰╁€楅幖鍏兼叏閿濆棙鐓ラ悽顖氭喘瀹曟岸骞嶉纰卞敽 34% 闂佸憡鍔曠粔鐢稿棘娴ｇ懓绶炵憸婵堟?
      //   闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷礁顕禍鍛婃綇閵娤€锕傛煏?*闂佺绉寸换鎰暜閸モ晝纾介柍鍝勫暞閻ｉ亶鏌ら崘鍙夋拱婵炲懏鐟╅弻褔宕崟顓狅紱**闂侀潧妫楃粔鏌ュ焵?
      //   闂佸疇娉曟刊瀵哥箔?闂佸湱鈷堥崜娆撳吹椤撱垹绾ч柕澶堝劜閸婄敻鎮?*婵炴垶鎸哥粔鎾疮閳ь剟鎮跺鐓庝函妞ゃ儱妫濆畷婊堫敂閸℃瑥鐐婇梺鍛婄懕缂嶁偓妞?*闂佹寧绋戦悧濠囧汲閿濆洣娌煫鍥ㄦ尭鐠佹煡鎮峰▎搴ｇ瓘缂佽鲸宀搁弫宥囦沪閹屾殹婵炲濮伴崕閬嶆嚋娴兼潙鐭楁俊顖滅帛閸╁倿鏌ｉ妸銉ヮ仼鐟滄媽灏欓幉瀛樻媴閽樺妲洪梺鎼炲劜閹稿啿顭?
      //     `backgroundRevealOpacity()`闂? 闂佸搫鍟版慨鐑藉疾?`pullBgIn`闂?闂?.30 濠电儑绲洪埀顒€鍟垮鎶芥煥濞戞﹩妲烘い?闂佺偨鍎查弻锟犲焵?婵炴垶鎸哥€涒晛螞閵堝鍋╅悘鐐跺Г閸婇亶鏌涘▎娆戝埌缂佸墎鍋ゆ俊?
      //   闂佸疇娉曟刊瀵哥箔?闂佺绻戠划宀€鑺卞畷鍥︽勃闁稿本鑹剧粻鐢告煙閸濆嫷妲风紒?`borderRadius(this.expandState.morphRadius)`闂佹寧绋掔喊宥夊汲閿濆洣娌煫鍥ㄦ尵濠€鏉戔槈閹惧磭效婵炴挸澧庨幉鐗堟媴閸涘﹤顩柣鐔哥懄鐢洭鍩€?
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧鍛村箞閵娾晜鍋ㄩ柕濠忕畱閻撴洟鎮楅崷顓炰沪缂佷焦鎸虫俊?*闂佺绻戞繛濠偽涢幘顔肩妞ゆ挾鍠愰弶褰掓煕閿濆啫濡肩憸鎶婂洤瀚夊璺猴工閺佸爼鎮楄ぐ鎺嗗亾濞戞氨鐛ラ悗娈垮枤濞呫垻妲愬┑瀣殑閻忕偟鍋撻悵顖炲级閳哄伒鎴澪ｉ崨濠勨枖鐎广儱瀚粣妤冣偓?*闂侀潧妫楃粙鍕濮樿埖鏅?
      //   闂佺娉涢敃銊╁磿濡ゅ懎鐤炬い鏍ㄧ⊕濞堝鎮橀悙鎻掆偓鎼併€冨鍕氦婵炴垶顨堥鍗炩槈?*婵炴垶鎸告鎼佸船鐎电硶鍋撻崷顓熷殌闁诡喗鎸荤粙澶愬焵椤掑嫬绾ч柍鈺佸暙閻ㄣ劑鏌?*闂佹眹鍔岀€氼剟顢欓幇鏉块棷闁靛ň鏅涘▍锟犳煏?
      //
      // ## 闂佸憡顭囬崰鎰焽閸偆鈻旈弶鐐村閻棗鈽夐弬璺ㄥ缂佹顦?
      //
      // 闂佺绻楀▍鏇㈠箰闁秴缁╅柟顖嗗嫮褰滈梺鍝勫暙閻栧ジ宕戦崨顔锯枖闁逞屽墰閹?閻?闂?`morphSquashY`闂佹寧绋戦悧蹇涙偟椤愶箑瑙﹂柟瀛樼箓缁旈箖鏌熼崗鍝ョ瓘缂佽鲸纰嶉妵娆撳础閻愭畫妤呮煟閵娿儱顏电紒杈ㄧ箘閳ь剛鎳撻崯顖溾偓鍨礋瀹?*闁荤姳璀﹂崹鎶藉极鏉堛劎鐝?*
      //   闂佹寧绋戝濉抣aybackPageRoute.ets` 闂?`.scale({y: morphSquashY})`闂佹寧绋戦ˇ顔剧箔鐏炵偓浜ら柧姘€荤粙鎴︽煛婢跺棌鍋撻懠顒傛啰闂?
      //   闂佸吋婢樻總鏃傜箔閸屾稓鈻旈柍褜鍓熼獮宥囨喆閸曨偆浜梺纭呮硾閿曘劑宕曞Δ鍛柧?*闂佸湱鈷堥崜娆撳吹椤撶喓顩查柛鈩冾殙閸╁矂鏌涘▎鎯奉亪顢欓幇鏉块棷?*闂侀潧妫旈悞锔锯偓鍨礋瀹曟岸鎮ч崼鐔稿婵＄偑鍊曢悘姘舵偋?`Stack` 闂佺偨鍎查弻锟犲焵?闂?`Stack` **婵炴垶鎸哥粔鏉戯耿椤忓棙宕夋い鏍ㄧ矋閺嗙姴顭跨憴鍕枙闁稿鎳忕粙?
      //   scale 闂佹眹鍔岀€氼亞绱為弮鍫熷仺闁靛鍎抽崢鐢告⒑?*闂佹寧绋戦悧鎰版儗妤ｅ啯鍋ㄩ柛妤冨剳缁憋箓鏌?scale 闂佸憡鐟禍婊呮暜閸モ斁鍋撻悷鏉挎殺闁搞倖绮岄蹇涙焼瀹ュ懍绨煎┑鈽嗗亰濞佳囨偤濞嗘挸鍐€闁硅揪绠戝▍锟犳煟閵娿儱顏х紒妞煎灮閹叉煡宕犻敍鍕槴闂?闂佸憡鍔曢幊搴敊閹邦剦鍤曟鐐茬氨閸嬫挻鎷呴挊澶婂闂佸搫鎷嬮崹鍐残уΔ浣衡枖婵犻潧鎳愰悷婵嬫煕閺傝濡搁柍?
      //
      // ## 闂佺粯绮嶅妯猴耿椤忓牆绠戦幖瀛樼箘閻ゅ嫮鈧鍠氬▍銏㈡濞嗘劗鈻旈柡鍌濆劵閸╁矂鏌ｅΟ鍨厫妞ゆ帗绮庡☉鐢割敋閸℃瑧顦?
      //
      // 婵犮垼鍩栭悧鐘差焽閻楀牏闄勬俊鐐插⒔椤忛亶鎮橀悙鎻掆偓鎼侇敊閹版澘闂い顓熷笧缁€澶岀磽娴ｅ湱鎳冮柣?`.height(H 闁?k)` + `.offset({y: 闂佹剚鍘芥晶?1闂佹剚鍘芥慨?/2})` + `.scale({y: k})`闂?
      // 婵炶揪绲介悘婵嬫偩閻樼粯鍎?*闁荤喐鐟ュΛ婊堬綖鎼淬劍鍎楅柍杞版祰閸╁矂鏌熼鐔风闁烩剝鍨剁粋?`0 闂?H閻犺櫣妫╅柧蹇撳寲**闂侀潧妫斿鎺旂箔?*缂傚倷鐒﹀ú婊堟偘閵夆晛鐭楅柨婵嗗閸橆剟鐓?*闂佸憡锚椤戝棙鏅舵惔銊︽櫖?
      // ```
      //   闁汇埄鍨伴崯顐︽儑椤掑嫭鍎楅柍杞版祰閸?y 闂?[闂佹剚鍘芥晶?1闂佹剚鍘芥慨?/2 , 闂佹剚鍘芥晶?1闂佹剚鍘芥慨?/2 + Hk]
      //   闂佹寧绋戝?offset` 闂佸憡鐟禍婵堜焊閹惧墎纾兼俊顖氭惈閻撴垿鏌ｉ埡鍌氶嚋缂佽鲸绱瓵lignment.TopStart` 婵炴垶鎸搁鍡楋耿椤撱垹纾婚煫鍥ㄦ长閳哄懎绫嶉悹楦挎鐎瑰鈽?[0, Hk]
      //     闂?闂佸憡鍨电换鎰扮嵁?H(1闂佹剚鍘芥慨?/2 閻庣數澧楅〃鍛村春鐏炲墽鈻斿┑鐘叉处濡椼劑寮堕埡鍌滄噥闂佸弶绮撳畷鐘裁洪鍜冪吹闂?
      //   闁汇埄鍨伴崯顐︽儑椤掍胶鈻旀い鎾跺仧婵?y_c = (闂佹剚鍘芥晶?1闂佹剚鍘芥慨?/2 + (闂佹剚鍘芥晶?1闂佹剚鍘芥慨?/2 + Hk))/2 = H(2k闂?)/2 = Hk 闂?H/2
      //   `.scale` 缂?*闂佺厧顨庢禍锝夋閳哄倻鈻旀い鎾跺仧婵?*缂傚倸鍊甸弲婊堝棘?闂?婵炴垶鎼╅崢鑲╃紦閻愵剛鈻旂€广儱鎳庤闂侀潧妫旂欢姘舵偟椤旇姤鍎?闁煎鐗?
      //   闁荤喐鐟ュΛ婊堬綖鎼淬埄娈楁俊顖氭惈椤?= Hk闁?闂侀潧妫斿ù鍥綖鐎ｎ剚鍠嗗璺侯槼閸橆剟鐓?= Hk 闂?H/2
      //   闂?闁荤喐鐟ュΛ婊堬綖?top = (Hk 闂?H/2) 闂?Hk闁?2 = H(2k 闂?1 闂?k闁?/2 = 闂佹剚鍘芥晶?1闂佹剚鍘芥慨?闁?2
      //   闂?闁荤喐鐟ュΛ婊堬綖?bottom = 闁荤喐鐟ュΛ婊堬綖?top + Hk闁?= H(2k 闂?1 + k闁?/2 = H(1+k)闁?2 闂?H
      // ```
      // **婵炴垶鎸堕崐妤咁敂椤掑嫭鐒鹃柟瀛樺笒缁鳖剟鏌″鍛倯妞ゆ帗绮庡☉?*闂佹寧绋掗悺鐚?= 1` 闂?`[0, H]`闂? 闂佽桨鐒﹀娆撴儓閸℃稒鏅€光偓閸曘劌浜鹃柟閭﹀墮閸撹偐绱掓潏鈺佇ラ柣鈩冨灦缁傛帡宕欓妶鍥╊槴闂?
      // `k = SQUASH_Y` 闂?闁荤喐鐟ュΛ婊堬綖鎼淬劍鍎楅柍杞版祰閸╁矂鏌熼鐔哥凡闁靛牅绮欏?缂傚倷鐒﹀ú婊堟偘閵夆晛鐭楅柨婵嗗閸橆剟鐓崶褍鏆炲┑锛勵焾椤劑鍨惧畷鍥ㄧ秳闂佸憡锚椤戝懘宕?k"闂佹眹鍔岀€氼喚鍒掗妸鈺佸嚑婵犲﹥鍔楃粣?
      //   `(H 闂?Hk)/2 = H(1闂佹剚鍘芥慨?/2`闂佺偨鍎婚懙褰掑焵?婵炲濯寸徊浠嬪矗?`k` 闂佸憡鐗楅悧婊堟偩濠靛棭鍤?`闁荤喐鐟ュΛ婊堬綖?top = H(1闂佹剚鍘芥慨?闁?2`闂?
      //   闂?缂傚倷鐒﹀ú鎴︽嚈閹达絿鐤€闁告劑鍔岀粩楣冩煕?k"闂?top 闂?`H(1闂佹剚鍘芥慨?/2` 闂?婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲骸锕?`k = 1` 婵?`k 闂?0` 婵犮垼娉涚€氼亞绮╅幘顔藉殜婵烇綆鍏橀崑?
      //   婵炴垶鎼╅崣鍐ㄎ涢崸妤€绠戝ù锝堫潐娴犳ê顭块懜浣冨婵?`H(1闂佹剚鍘芥慨?(k)/2`闂?
      //   闂佸疇娉曟刊瀵哥箔?**闁哄鏅滈悷锕€危閹间礁瀚夋い鎺嶇贰閸嬔囨煕閻戝棗鐏熺紒鏂跨摠缁嬪鍩€椤掍礁绶?闁哄鏅滈崹鎶藉箮閳?**闂佹寧绋戦懟顖炪€呰閳ь剙婀遍崑鐔封枍閵壯勫閻㈩垼鍠氱粣妤呮⒒閸喓鎳勬い鎺撶洴楠炩偓濞撴艾锕︾粈鍒瀔 = 1`闂?*闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯夸含閻熸繈鏌?*闂佸搫瀚烽崹宕団偓娑掓櫇閻ヮ亪宕犻敍鍕槷
      //     閻熸粏鍩囬崹纭呫亹婢跺鈻旀い鎾卞灪閿涚喖鏌熼璺ㄧ獢闁稿鎳樺畷?vp 闂佹眹鍔岀€氼剚绂嶇粙娆惧晠妞ゆ梹顑欏ú锝呪槈閹剧鏀绘繝褉鍋撻梺?闂佺偨鍎查弻锟犲焵?闂佸吋鐪归崕鍐诧耿閿熺姴瀚夐弶鐐村閻?闂佸憡锚椤戝洨绱撴径鎰睄闁诡垱婢橀崜褰掓煛閸滀礁鐏熺紒妤€鍊圭粙澶屸偓锝庡枟閼荤喖寮?闂?
      //     闁诲繐绻楁ご鍛婁繆?`.scale` 闂佺懓绠嶉崹娲垂?`.scale({centerY: '50%'})` 婵炴垶鏌ㄩ鍛此囨繝姘剭闁告洦鍋勭紞妤€鈽夐幘顖氫壕闂佸搫顥￠妶鍥╁敶闂佹寧绋戦悧蹇涘极閵堝棛鈻旈柕鍫濇噽濠€鎾偡娴ｉ顦﹀鍏夊亾闁荤偞绋忛崕杈ㄥ閳哄懏鏅鑸电〒缁€?
      //     闂備緡鍙忕徊鎯ь渻閸岀偛绀冪€广儱妫欓弳顓㈡煥?*婵炴垶鎸哥粔鐑姐€呴敃鍌涘仢闁哄瀵ч煬顒勬煕閹搭厼骞橀悗鍏哥矙瀹曟繈鎮╅懠顒€鐓戦梺?*闂?
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦鍋嗗﹢瀵哥磼?*闂佹寧绋掓穱娲磿濡ゅ懎鐤炬い鏍ㄧ缁€鈧梺鍛婂笚濠㈡﹢鎳滄导鏉戠煑婵☆垯璀﹂崯鍥煕?*闂佸憡鍔曢幊姗€宕?*闂?
      //
      // ## 闂佺懓鐡ㄩ崹宕囩不閿濆绀堢€广儱顦伴弲鈺呮煕閿斿搫濡奸柟濮愬灲閺佸秹宕奸敐鍥╊啎闂備焦瀵ч悷銈囩箔娴ｈ濮滄い鏇炴缁€澶愭煟椤剙濡介柛鈺傜洴瀹曡泛鈽夊▎妯轰还闁诲骸婀遍崑鐐电矈閹绢喖绠ラ柟鎹愭珪缁€鈧梺?
      //
      // 闂佺懓鐡ㄩ崹宕囩博閹绢喗鍎庣紓鍫㈠С缁ㄦ澘鈽夐幘璺哄妺婵☆偁鍊濋幃鎯х暆閳ь剙鈻?`MeshCoverBg` 闂?`playerPane` **婵炴垶鏌ㄩ鍛此?*闂佹寧绋戞總鏃傝姳椤掑嫬鍙婃い鏍ㄧ☉鎯熼柣搴ｆ嚀閸燁垶骞嗘径鎰闁绘鐗婇幏鍗烆渻閵堝懐浠涢柣?`Stack`
      // 闂?闁?*婵炲濮村ù鐑筋敄閸ャ劎鈻旈柍褜鍓涢弫顔款槻婵ǜ鍔戝顐﹀级閹寸姵缍?*闂侀潧妫斿ù鍥焵椤掆偓婵傛梻绮?*闁荤喍妞掑鎺旂箔婢舵劕绀?*闂侀潧妫楅崐濠氬极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍?*闂佸湱铏庨崢浠嬪棘娓氣偓瀹曟娊濡搁妷褎缍岄悗娈垮枓閸嬫捇寮堕埡鍋垫垵危閹间焦鍤勯悘鐐靛亾閻濐垶鏌涜箛瀣闁?*闂侀潧妫楃粔鏌ュ焵?
      //
      // 闂佸搫鐗滈崜婵嬫偪閸℃稑绠┑鐘插暞閿熴儵鏌ｉ敐鍛伇婵?*闁诲骸婀遍幊鎾斥枍閹烘鍐€?*婵炴垶鎸撮崑鎾绘偣娓氼垰鐏ユい鏇氬嵆閺屽懎顫濋銈呮櫓闂佹寧绋戝澧倁jie.pa`闂佹寧绋戦¨鈧紒?
      // ```
      //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   闂?闂?Stack
      //   @36***# (191388)  Stack(TopStart)
      //                       .scale({x: expand.scaleValue, y: 闂佺偨鍎哄ú?      191400-191415
      //                       .translate({x: expand.translateX, 闂佺偨鍎哄ú?     191416-191431
      //                       .width(expand.clipWidth)                  191432-191441
      //                       .height(expand.clipHeight)                191442-191451
      //                       .borderRadius(expand.radius)              191452-191461
      //                       .clip(true)                               191462-191469
      //                       .id(PLAYER_ROOT_ID)                       191470-191478
      //                     闂佸疇顫夋竟鏇㈠绩?If (191716 @36***#^4 闂?@36***^4*#/^1)
      //                     闂?   闂佸疇顫夐弻锟犲绩?Column (191756 @36***#^5)
      //                     闂?        闂佸疇顫夋竟鏇㈠绩?If (191972 @36***#^7 闂?@36***^7*#)  = **playerPane**闂佹寧绋戝﹢锕恮闂?
      //                     闂?        闂佸疇顫夐弻锟犲绩?If 闂?**MeshCoverBg**              192105 / 192191
      //                     闂佸疇顫夐弻锟犲绩?闂?
      // ```
      // 闂?**`MeshCoverBg` 闂?`PLAYER_ROOT_ID` 闂備緡鍙忕徊濂告煂?Stack 闂佹眹鍔岀€氫即宕抽悜鑺ヮ棃?*
      //   闂?闁?*闁荤姾娅ｉ崰鎾愁焽閸愵亖鍋撻崷顓熷殌婵炲懏甯楃粙澶愬焵椤掑倹灏?scale闂侀潧妫斿鎺旂博鐎靛憡灏庨柣銈庡灱濞?clip**闂?
      //   闁哄鏅滈悷銉ヮ潩閵娾晛鍙?闁诲繒鍋炲ú鏍閹达箑绫嶉柟顖涙緲閸撳綊鏌￠崪浣哥仧缂佹顦扮€电厧顫濋鐔割啋闁诲繒鍋涚换鍫ュ焵椤戞寧绁伴柍褜鍓欓張顒€危閸涘﹦顩烽幖杈剧磿濮ｅ牏绱掗幇顓ф當鐟滅増鐩弻灞界暆閸曨剚鐦ｉ梺鍛婂灩閸庛倕顭?闂佹眹鍔岀€氼厼鈹冮埀顒勬煕閹烘洜鍫柍?
      //
      // 闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹宕囩箔閸屾稓鈻旈柍褜鍓熼幃褔宕奸妷銉ょ凹闂?闂佸搫鍟版慨鐑藉疾椤愶附鍎?MeshCoverBg 闂?playerPane 婵炴垶鏌ㄩ鍛此囨繝姘櫖闁割偅绮庨悷銏ゆ倵閻熸澘鏆欓柟顔芥尵閻ヮ亣顧傜紒?**闂佸搫瀚烽崹鍫曞极婵犲洦鍎?*闂?
      //   闂佸搫顦崕鑼姳椤曗偓瀵即顢涘顒侀敪闂佹椿浜滈鍕姳閿熺姵鍋嬮柛銉厛閸炰粙鏌曢崱鏇犲妽闁汇儱鎳橀獮?`PLAYER_ROOT_ID` 闂備緡鍙忕徊濂告煂?Stack 闂?*闂傚倸鍋嗛崢濂稿箖鎼淬劍鍤戦柛鎰╁妽缁?*闁荤姴娲╅褔宕甸銏犵骇闁靛绲洪崑?
      //   闂佹寧绋戝濉晍dMusic闁荤姳鐒﹀妯兼崲?md` 闁?6.50 闂備焦褰冩總鏃傚姬閸愵喖鍙婃い鏍ㄧ箘缁犵懓鈽夐弬璺ㄥ闁哥喐鎹囬幆?闂佺偨鍎查弻锟犲焵?婵炴垶鎸撮崑鎾搭殽閻愬瓨鏋勭紓宥嗘⒐閹棃鎮㈢划鐟颁壕闁稿矉濡囩粈?
      //
      // ## 闂佸湱鈷堥崜娆徝洪弽顓炲偍閻犱礁纾娲煕濮橆剟顎楅柟顔芥崌瀵噣骞嗛棃鑸靛浮瀹曟ê鐣烽崶銊ф殸婵炴垶鎸堕崐鎾斥枎閵忥紕顩?
      //
      // 1. **闁诲繒鍋炲ú鏍閹寸偟鈻旂€广儱鎳庨弲?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛鍎冲?**闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁俊顖滅帛閸╁倿鎮楅崷顓熷殌婵炲懏甯″畷锝夘敂閸涱喚鐣抽柡澶嗘櫈濞撳湱绱炲鈧鍫曟晸閻樿弓绨兼繛鎴炴煥閻楀棝濡?闂?闂佺厧鍟块張顒€鈻嶅▎鎰枙闁绘柨鍢插☉褔鏌涢敂鍝勫闁稿鎳忕粙澶愬焵椤掑倷鐒婇煫鍥ㄦ尰閸嬨儵姊洪幓鎺旂効缂?
      //    闂傚倸鎳庣换鎰邦敊閹版澘闂柕濞炬櫆濮ｆ劕顭块崼鍡楁閸嬫挸鐣濋崟顒佸殘閻庢鍠掗崑鎾绘煥濞戞澧ｇ紒缁樼墵楠炲秴顓奸崱妯?婵＄偛顑囬崑妯肩箔閸岀偛绾?闂佹眹鍔岀€氼垶锝為崶顒€绠涢柣鏇炲€荤粈鍡涙煥?
      // 2. **闂佺绻戞繛濠偽涢幘顔肩睄闁诡垱婢橀崜褰掓煛閸滀礁鐏ョ紒鎰剁節閹牓鍩€椤掍胶鈻旈柍褜鍓涢幐褍鐣￠弶璺伝**闂佹寧绋掗懝楣冾敊閹版澘闂柕濠忛檮閹烽亶鏌℃径鍫濆姎婵ǜ鍔戝畷鐑藉Ω閵娧呭敶闂佹眹鍨瑰畷顒勬晬閹剧粯鐒介柨婵嗘閽?`morphSquashY` 闂佹眹鍔岀€氼亞绱為弮鍫熷仺闁靛鍎抽崢鐢告⒑?
      //    闂佹寧绋戝濉抣aybackPageRoute.ets` 闂?`.scale({y})` 闂佸憡锚椤戝棝寮抽敐鍡欌枖妞ゅ繐鎳忕亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢舵劖鏅璺烘濞?**婵炴垶鎸哥粔鎾疮閳ь剟姊婚崶锝呬壕闁荤喐娲戦悞锕傚垂濠婂嫮鈻斿┑鐘辫兌椤忛亶鏌?
      //    闂佸憡姊绘慨宄扳枔閹达附鐒介柨婵嗗閸?`.scale + height + offset` 闁荤偞绋忛崕杈ㄥ閳哄啠鍋撻崷顓熷殌婵?*闂佹寧绋戦悧鍡涘礄閿熺姴绀嗛柣妯肩帛閻濈喖鏌ㄥ☉妯肩劮妞?`squashWrapHVp` 闂佹眹鍔岀€氼剟宕硅ぐ鎺撯挃闁靛牆鐗滈崬鍓佹喐閻楀牊绌跨紒杈ㄥ哺婵?
      Column() {
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦鍙庨崕鎴濃槈閹炬剚妲搁柣顏呭閵囨劙濮€閵忕姌?*闂佹寧绋掗懝楣冨船鐎甸晲娌?`Stack` 婵炴垶姊婚崰搴ｆ崲閳ь剙顪冮妶鍥╁笡婵?`TopStart`闂?
        //   闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗩槸濞咃繝鏌￠崟闈涚仧缂佹梹鎸冲畷?`Column闂佹寧绋戦悧鍡涱敊?100% + winHVp + padTop/padBottom闂佹寧绋戣棟 闂佺儵鏅涢悺銊ф暜閹绢喖閿ら柟閭﹀墯闊?
        //   `Stack(TopStart)` 闂?闂佺偨鍎查弻锟犲焵?**濠电偟绻濈粈浣烘閿涘嫧鍋撳☉娆忓濠碘槅鍙冮幃?*闂侀潧妫旂粈浣该归幇顔瑰亾鐟欏嫭鐨戦柣娑栧劦瀹曪綁鏁愭径灞借拫闂侀潧妫楅崐褰掑垂濠婂嫮顩锋い鎺戝暟缁犲綊鎮橀悙鎻掆偓鍝ユ暜椤愶箑绾ч柕澶涢檮绗戞慨鎺撶⊕椤牓顢?
        //   闂佹寧绋戝濉乪nter`闂? 闁诲海鎳撻妵妯尖偓?`.position(0,0)`闂佹寧绋戞總鏃傜箔鐏炲墽鈻斿┑鐘插暟閸╂鈽夐幘宕囆ｆ俊鍙夋倐瀹曘儳浠﹂懖鈺婁紘婵炴垶鎼╂禍婊堟嚋娴煎瓨鍋愰棅顒佺ゴ閸?
        //   闂?闂佽　鍋撻悷娆忓閻?`TopStart`闂佹寧绋戦懟顖烆敊閺嶃劎鈻旈柤濮愬€栭悾閬嶆煕閵夈儲鎯堥柣锝呭⒔娴滄悂宕崟闈涙闂佸綊娼х粔闈涳耿娓氣偓楠炲洩绠涙惔锝囨瀫闂佹寧绋戦悧濠囨儉閸涙潙瀚夊璺猴功閺嗗﹪鏌ㄥ☉妯垮婵炲瓨鍔楅埀顒冾潐瀹€鎼佹偟椤曗偓閹啴宕熼顐㈠Ψ闁诲孩绋掗崝鎺旀閹殿喗鍋栨い鎰╁灮濠€宄扳槈閹垮啫骞楅悘蹇旀尵閹秆呮暜椤斿墽顦梺?
        Stack({ alignContent: Alignment.TopStart }) {
          // 闂?闂佺厧鍟块張顒€鈻?= **闂佸憡顨呴敃顏堝焵椤掆偓缁绘垵危?闂?婵炴垶鎸哥粔褰掑焵椤掆偓缁绘垵危?*闂佹寧绋掗懝鍓ц姳閹惰姤鍤岄棅顐幘閻熴垽鏌涘▎鎰⒊濠㈢懓锕︽禒锕傚磼濞嗘埈浼囬柣鐘欏懏鐒块柧鏂款儔瀹曪絽顓奸崶鈺傘仢闁荤姴娲﹂崹鐟扳枔?
          //   `pullBgIn = clamp(effT / 0.30)`闂? 闂?0.30 濠电儑绲洪埀顒€鍟垮鎶芥煥濞戞﹩妲堕柍?
          // 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃顏勵焽娴煎瓨鐒介柨婵嗗閳峰牓鏌涘▎宥呭姷缂?闁圭厧鐡ㄥú婵囩珶婵犲啰鈻旈幖绮光偓宕囨偧闂佽壈顫夎ぐ鍐儑閻楀牏鈻旈柍褜鍓涢幐褔鎮块婵囧发 `pullBgIn`"闂佹寧绋戦ˇ顐⑽?**閻庤鐡曞鎾剁礊閺冣偓閹?*闂?
          //   闂?2026-10-15 闁荤姍鍐ㄦ缂佽鲸绻堥弻鍥晲閸曨喒鎷￠柣?*闂佽桨鐒﹀娆撴儓閸℃瑧妫い鏍ㄧ箓椤ュ繘鎮橀悙鎻掆偓鎼佸礄閿涘嫮纾奸煫鍥ㄦ⒐濞堝鎮橀悙鎻掆偓鎼佸垂瑜版帗鈷?*闂佹寧绋戦悧鍛箔閸涘瓨顥堥柕蹇曞У閻ㄦ垿鏌￠崟闈涚仩闁搞劌缍婂浠嬪Χ閸涱喖鈧敻鏌ｉ妸銉ヮ伀妤犵偛娲畷鐑芥偖鐎靛摜顦梺?
          //
          // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*闂佸搫鍟版慨鐑藉疾椤愨懇鏌﹂柍鈺佸暞缁犳帞绱掔紒銏犵仴濠㈢懓锕畷褰掝敃閵忣澀浜㈤梺鎸庣☉閻偐绱炴径鎰唨闁稿繐鍚嬮幏閬嶆椤掑浜滄慨妯稿姂瀵即顢涘鍙樹孩**闂?
          //   婵炴挻纰嶇换鍐ㄧ暤?`_recover/logic-src/闂佸搫鍟版慨鐑藉疾閻滅氮濠电偞鐓＄粻鏍偂?閻庣懓澹婇崰鏍閹捐绀嗛柛鈩冾焽閳?md` L303-304闂?
          //     闂?闂侀潧妫楅悾鐟縪lumn().backgroundColor('#1c1c1e').opacity(...)` 闁哄鏅滈崹璺ㄥ垝閿曞倸鍨傛い鎰╁灮娣囨椽鎮橀悙鎻掆偓鍫曞焵椤掆偓缁夘噣宕?闂佸搫鍟版慨鐑藉疾椤愶絿鐟?**闂?*闂?
          //     闂?闂侀潧妫楅悾鐟縪lumn().backgroundColor(state.imageColor)` 闁诲繐绻嬬欢姘焽娴兼潙鐭楅柡宥冨妿婢瑰鏌ょ憴鍕祷闁活亙鍗虫俊鏉戭吋娴ｅ憡娅?**濠电偛澶囬崜婵嗭耿娴ｈ　鍋撻悽鍨殌缂併劍鐓￠幃?*闂?
          //   婵炴垶鎸堕崐鏇㈡儑娴煎瓨鐒鹃柤鎭掑劜绗戝┑鐐寸叀缁犳牠鎮￠崼鏇炵睄鐟滄垿鎯屾ィ鍐╂櫖婵炴垶顭囬弳濠偯归悪鈧崜娆掋亹閺冨牆鎹堕柕濞у懐效闂佸搫绉瑰Λ璺ㄧ不閿濆棛鈻旈悗锝呭缁€澶愭煕濞嗘ü绨风紒杈ㄥ閹?闁诲繒鍋炲ú鏍閹存繍鍤曢柍褜鍓氶幈銊р偓锝庡枛娴滄繂鈽夐幘顖氫壕闂?婵犮垼鍩栭懝楣冨吹椤撶喓鈻旈柍褜鍓熷畷绋课旈崘褏绀傞梺鍝勬椤ㄥ牓宕撻悽纰樺亾?
          //   闂佹寧绋戦悧鎰帮綖?`backgroundRevealOpacity()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煏?
          //
          //   闂?闂備緡鍙忕徊浠嬫儑?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夘棑閻熸繈姊洪銏㈢婵″弶鍨堕幆?闂佺粯绮嶅妯猴耿椤忓牆绠规い鎺嗗亾闁糕晛鏈粋?*闁荤姳璀﹂崹鎶藉极鏉堛劎鐝?*婵炴垶鎸搁…顓犳濞嗘劖浜ゆ繛鍡樺姈绗戦梺鍝勫暟婵兘寮查锔藉剭闁告洦浜炵粔瀵哥磽閸愭儳娅欑紒?
          //     `wujie.pa:190867-190884` 闂?`.backgroundColor(pullMode && effT()>=1 ?
          //     PULL_REST_BG : expand.overlayColor)`闂佹寧绋戦¨鈧紒杈ㄧ箞閹峰啴鎮剧仦鎴掑寲闁?
          //     `PlaybackPageRoute.ets` 闂?`PlaybackPageRouteShell`闂?
          //       閻?閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂跨毞閸嬫捁绠涢弮鈧～?闂?缂備焦鍔栭〃鍛般亹濞戞瑥绶為柡宥庡幐閸嬫捁绠涢幘铏様婵☆偓绲鹃悧鐘诲Υ婢跺鈻旈幖娣€楃喊鍐归敐鍥ｆ繛纰卞灦閺佸秹宕煎┑濠傜厒闂佸憡鐟﹂…鍥р枔閹达箑绀堢€广儱妫楃徊褰掓煥濞戞﹩妾х紒?
          //       閻?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夘棑閻熸繈姊洪銏㈢婵?闂?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暙濞堟壆鈧鐡曟禍顒€鈻撻幋鐐村劅闁哄浂浜炵粈澶婎渻閵堝懏鎯堥柣銏╁亰閹嫰寮介敂鍓ら梺缁橆焾閸╂牠鍩€椤戣法鍔嶉柣鏍村枟缁嬪鎯旈敍鍕孩闂備緡鍠撻崝鎴﹀磻閸涱喚鈻旈柕鍫濇閽?
          //         闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓懟顖炲船鐎电硶鍋撶涵鍜佹綈闁汇儱鎳庨娆撳嫉闂堟稑娈ら柡澶嗘櫆缁嬫挻鎱ㄩ幖浣哥畱濞达絽婀遍崺澶愭煏閸℃袪闁逞屽墮閼活垳鑺遍幎鑺ョ劸闁靛鍊楅閬嶆煛婢舵稓纾块柍瑙勭墵閹倿鎳為妷褏顢呴梺鍛婂灥閹碱偊骞冨Δ鍛棃闁靛繒濮撮弫鍫曟倵閻熸壆鐣柍褜鍓欑粙鍕濮樿泛违?
          //     闂?闂佸湱顣介崑鎾趁?*婵＄偑鍊楅弫璇差焽娴兼潙绀冮柛娑卞墰閻熸繈鏌涢幇顒傂ф繛鎾冲閹?*婵炲濮鹃濠勭礊瀹ュ鏋侀柡澶嬪灩濞煎瞼绱掔紒銏犵仴濠㈢懓锕︽禒锕傚磼閿斿墽顦梺鍛婂笧婵數鏁埀顒勬倵閻熸澘鏆曠紒妤€顦扮€电厧顫濋鈧В澶愭煟?闂佺厧鍟块張顒€鈻嶅▎鎴犵煔閺夌偞澹嗛閬嶆煕?闂?
          //
          //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁澶婎焽閹殿喚纾鹃柟瀵稿仧婢规劙姊洪銊у埌闁活亙鍗抽幆?`backgroundRevealOpacity()` **婵烇絽娲︾换鍕汲閳?*闂佹寧绋掗懝楣冩偩閻樺吀鐒婇弶鍫涘妽绗戦梺鍝勫暟婵兘寮查锔藉剭?`pullBgIn`
          //      闂佹寧绋戦悧鎰板箲閿濆鍊?0闂侀潧妫斿ù鍥╃玻閿熺姵鍎撻柍褜鍓濋妵鎰板閻樿尙绉柡澶嗘櫆缁嬫垹鈧濞婂畷?1闂佹寧绋戦¨鈧紒杈ㄧ箞濡啫鈻庨幇闈涘闂佽鍏涢悞锔界閼恒儳鈻?1闂?

          // 闂佸疇娉曟刊瀵哥箔?缂備焦鐦遍崶顭戝悅闂佺绻楀▔娑㈠箖濡ゅ懏鍎嶉柛鏇ㄥ灠娴滄繃绻?闁诲骸婀遍崑鐐差渻閸屾鐔兼晬閸曨厔鍥箹鐎涙ɑ绀€婵?闁荤姴娲ら悺銊ф兜閸洖鐓?**婵炴垶姊婚崰搴ㄥ礄閳╁啯濯存繝濠傚暟閻?*闂佹寧绋掑畝鎼佸磻閸涱収鍤?`Image(闁诲繐绻嬬欢姘焽?.blur(11)`
          //   閻庡湱顭堝鍫曞汲閿濆洣娌柛灞捐壘閻忊晠姊?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐ゆ暜椤愶箑绀傞柛顐ｇ箓濞懷兠?缂傚倸鍟崹鍫曟偋缁嬪簱鏀﹂柟閭﹀枛缁讳線鎮介锝呭箺婵＄偛鍊块幆鍐礋椤愩垹绠查柟?闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶宕㈢憴鍕劅闁哄洨濮寸粻娑㈡煕閿斿搫濡介柡浣搞偢楠炲骞囬鍡楁櫓**缂備胶铏庨崹鎷屻亹閸ヮ剙鍐€闁汇値鍨伴ˉ?*
          //   闂佹寧绋戦悧鎰帮綖閸℃鈻旈悗锝庡枟濡?`else` 闂佸憡甯掑Λ娆撳极椤曗偓閺佸秵寰勯崼姘壕闁稿本鑹鹃悘鈺呮倵閻熸澘鏆熸繛鍫熷灴瀹曘垽鎮㈤柨瀣槶闂佹寧绋掗懝楣冩偩閻樼數椹冲璺侯槺閼?*闂侀潻璐熼崝搴ｇ礊婢舵劕鍐€闂傚倸顕鍝勵熆閼哥數澧€殿喚鏁婚幃鐣屾媼瀹曞洤鏅╂繛鎴炴尨閸嬫挾鈧鍠氭慨鎾儍濠靛顥?*闂?
          //   闂佺懓绠嶉崹鍝勵焽閻㈠憡鍋ㄩ柕濠忕畱閻撴洟鎮楅崷顓炰沪缂佷焦鎸抽幆鍐礋閳规儳浜剧€光偓閸曨偂绨兼繛鎴炴惄娴滄瑧鎮崡鐑嗗殨闁绘灏欏▓閬嶆⒒閸稑鐏╃憸鎶婂嫬顕辨慨姗嗗墯闊剟鏌涢弬璇插闁轰胶鍋撳濠氬炊閳圭偓鐓犳繛鎴炴惄閸樺ジ宕甸銏″仢闁煎壊鍏橀崑鎾愁吋閸愶絽浜?
          //   闂?`backdropBlurRadiusVp()` / `LIVE_BACKDROP_BLUR_VP` / `originalCoverSource()`
          //     闂佺粯绮嶅妯猴耿?*閻庡湱顭堝璺何涢妶鍥ㄥ闁告劦浜濋弳蹇涙煠?*闂佹寧绋戦悧蹇涘汲閳ь剟鏌涢敂鍝勫闁哄鍟粋鎺楀醇閺囩偞顏為梺鍝勫閸垳鎷归悢鍝ヮ洸闁糕剝娲滈悷婵嬫煟濡ゅ懏娑у┑?`isPixelMapCover` 闂備緡鍙忕徊鎯ь焽椤栨粎灏甸悹鍥皺閳ь剛鍏樺畷姘跺幢濡粯娈伴梺?
          //     闁诲海鎳撻崯鈺侇煥閹达附鍎嶉柛鏇ㄥ墯濞堣霉閿濆棙灏扮紒鏂款煼閹爼宕卞Δ鍐ㄩ梺?闂佸憡甯炴慨闈浨庨幎鑺ヮ棅闁硅埖鍨濈划锝夋煟?闂備緡鍙忕徊鑲╃博閹绢喖閿ゆ俊銈咁儑缁€澶愭偡?`RzdMusic闁荤姳鐒﹀妯兼崲?md` 闁?6.6闂佹寧绋戦ˇ顓㈠焵?
          // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫宥咁潩閸愭彃澹掗梺鍝勬媼閸ㄦ壆鑺遍搹顐ｅ劅鐟滃骸鐣烽弻銉ョ?**缂傚倸鍟崹鍫曟偋濮濆被浜归柕蹇曞Т缂嶄線鏌ら崘鍙夋拱婵?*闂佹寧绋戝濉巈shCoverBg`闂佹寧绋戦ˇ顓㈠焵?
          //   闁荤喐鐟ョ€氼參鎮ч幖浣规櫖婵繃鐡╮ecover/logic-src/闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暙閸撳綊鏌?MeshGradient婵炴垶鎸搁幊淇hSource闁诲氦顫夊銊┾€?md`
          //   闂佹寧绋戝濉嶦SH_SUB=4`闂侀潧妫斿妗絉C_EDGE=64`闂侀潧妫斿姊憃xBlur(9,3)`闂侀潧妫斿姊攊splaySync` 20fps闂侀潧妫旂欢姘渻閸曨垱鈷?= `playing && active`闂佹寧绋戦ˇ顓㈠焵?
          //   闁诲海鎳撻崯鎶藉吹濠婂懏鏆?*閻庡灚婢樼€氼剟骞冨鍫濇辈婵°倕瀚峰?*闂佹寧绋戝濉籧rim` 婵帗绋掗…鍫ヮ敇?true闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲秹鍩€椤掍胶顩烽柕澶堝€楅悷鎾绘⒒閸稑鐏查柛瀣噽娴狅箓宕掑鍐句痪缂備焦鏌ㄩ鍥р枔?`radialGradient`
          //   闂侀潻璐熼崝搴ｇ礊婢舵劕鍐€闁兼祴鏅滈弲鎼佹煛娴ｅ摜澧涙俊鐐插€界粻娑㈠川濞ｎ兘鍋撹箛娑樼闁惧浚鍋勭粩鎾煥濞戞瀚伴柟顖欑窔瀹曟艾鈻庢惔锝囩崶闂佸憡鐟ф慨宕囨偖鏉堛劎顩烽柤鎭掑劜椤斿倿鎮峰▎鎰闁?
          //   闂佸疇娉曟刊瀵哥箔?缂傚倸鍟崹鍫曟偋缁嬪簱鏀﹂柟閭﹀灣缁犻攱绻涚仦绯曞亾瀹曞洨澶勬繝闈涘€归弸鑽ゆ濞嗘挸绠查柕蹇ョ磿閹藉啴姊洪銊у缂佹梹鎸抽幆澶愵敆婵犲嫮顦梺?*闂備緡鍋€閸嬫捇鏌涢妷褍浠滈柣銈呭瀵噣鎳滈惃鍕兌閸栨牗绻濋崶褌绨奸悗娈垮枤婵潙霉?*闂佹寧绋戞總鏃傜箔婢跺顕辨慨姗嗗墮濮ｅ鏌?闂佺厧鍟块張顒€鈻嶅▎鎴犵煔閺夌偞澹嗛閬嶆煕?闂?
          // 濠电偟绻濈粈渚€宕㈠鍫熷殑閻忕偟鍋撻悵顖炴煥濞戞澧ｆい鏃€娲滅槐鏃堫敋閳ь剟濡村鍜佸殨闁逞屽墴瀹曟绮甸崷顓狀槴闂佹寧绋掗懝鍓ф崲閳ь剙顪冮妶鍫殭婵犫偓椤忓牆绀冮柛娑卞弾閸熷洭鎮橀悙鎻掆偓椋庣不閿濆绀堢€广儱娲ㄧ敮娑㈡煕閹烘洦鍟囩紒杈ㄧ箞瀹曘儵鏁冮埀顒勫垂椤栨稑顕辨慨妯块哺绾炬澘霉閿濆懐绠伴柣銊︾箞濡啴濮€閻樺啿顏┑顔界箓閻線鎯?
          this.MorphSolidSurface()
          // RzdPlaybackMeshOnly: 已固定为网格背景，保留现有 MeshCoverBg 绘制与取源链路。

          // 闂佸疇妫勯幊澶娢?2026-10-15闂?*閻庡灚婢樼€氼剟骞冨鍫濇辈婵°倕瀚峰?*闂佹寧绋戝澶愭煛閸愵亜啸闁哄懐骞梥濠电偞鐓＄粻鏍偂?閻庣懓澹婇崰鏍閹捐绀嗛柛鈩冾焽閳?md` 闁?.4闂侀潧妫楅懟顖烆敋椤旂瓔鐎查柟閭﹀墰缁憋箓鎮?閻?闂?闂佸憡鐟禍婊勬叏閻愬樊鍤楅柛鏇ㄥ亝閸婂鏌￠崱姗嗘畽妞ゎ偅顨婃俊鏉戭吋韫囨洜顦梺?
          //   闁哄鏅滈悷銈囩博閹绢喖绾ч柍鈺佸暞绗戦梻渚囧弿缁插ジ宕妶澶婃闁搞儯鍔婇埀顒€鍊荤槐鎺戔枎閹寸偟鏆?*闂佸搫鐗冮崑鎾绘倶韫囨挾绠洪柣顓炲⒔閻?*闂佹寧绋掑銊╁礄閼恒儳鐝堕柣妤€鐗婇～鏍偓娈垮枛缁诲牓鍩€椤戣法绐旀繛鏉戝€垮顒侊紣娴ｉ缚绌块柣鐘欏嫮澧﹂柍褜鍏涢懗鍫曟偟濞戙垹绀嗛悹鍥ㄥ絻鐠佹煡鏌?
          //   闂佺偨鍎查弻锟犲焵?婵?缂傚倸鍟崹鍫曟偋缁嬫５瑙勬媴缁嬪晝妤呮煠閸愬弶婀版繛?闂佹寧绋戝濉巈shCoverBg`闂佹寧绋掗悺鐙給deContainer` + 闂佺厧顨庢禍婊堟偩閻愵剛鈻?`RenderNode.drawPixelMapMesh`
          //   + `displaySync` 闂備緡鍋呴崝鏇㈠箮濮橆厹浜滈柛鎾茬娴狀垶鏌ㄥ☉妯肩劮妞?`闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暙閸撳綊鏌?MeshGradient婵炴垶鎸搁幊淇hSource闁诲氦顫夊銊┾€?md` 闁?闂?*闂佸憡甯掑Λ妤冩?*闂?
          //   闂備緡鍙忕徊浠嬨€冨鍫濆珘妞ゆ帒鍟伴弸?*婵炴垶鎸哥粔瀛樼?*闂佹寧绋戦惌浣烘崲閺嶎厽鐓傞悘鐐舵濞懷囨煕濞嗘垵小缂佹柨顕禒锕傚磼濮樿京鐛梺鍛婄閸ㄧ數鏁崶顒€姹叉俊鐐茬毞閸?
          //
          //   闂備緡鍋呴崝娆撳Υ瀹ュ鏋侀柡澶婄氨閸嬫挻绺界粙鍨箣闂佸憡鐟﹂悧鐐哄吹濠婂牆妫橀柛銉ｅ妸閳ь剙鍊块弫宥夊锤閸掓劙鏌涘Δ浣圭缂併劎鏁恅闂佹寧绋戦懟顖炲吹椤撶喎绶為柛鏇ㄥ亜閺呮悂鏌￠崟顐ゅ嚬濞存粍甯楃粭鐔煎垂椤曞懏些闂佸搫绉瑰鑽ゆ濮樿埖鏅?
          //   `闂佸搫鍟版慨鐑藉疾閻滅氮濠电偞鐓＄粻鏍偂?閻庣懓澹婇崰鏍閹捐绀嗛柛鈩冾焽閳?md` 闁?.4 缂傚倷绀佺€氼亜鈻庨姀銈呭唨闁瑰鍋炲Ч鐐烘偠濞戞ê顨欑紒妤€鐭傛俊瀵镐沪閸涘﹤娅嶉梺闈涙缁夊綊宕戦崨顔锯枖闁逞屽墮閳?闂佺偨鍎查弻锟犲焵?闂佸搫鍟版慨鐑藉疾?
          //   `MeshCoverBg` 闂?`Stack` **闂佸搫鐗冮崑鎾斥槈閹剧韬繛?*闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棗娴烽閬嶆倶?`Column().radialGradient(...)`闂?
          //   闂佸吋婢橀張顒勫垂濠婂嫮顩锋い鎺戝€归悾?`Stack` 闂?闂佸憡鍔曢幊搴敊閹邦喕娌?闂佹寧绋戝濉╱ildControlStack`闂佹寧绋戦ˇ顔惧姬閸愵喖鍙婃い鏍ㄧ⊕娴犳﹢鏌涘顒佹崳闁轰線绠栭幆鍐礋閳规儳浜?
          //   闂?婵炴垶鎹佸銊ц姳閳╁啰鈻旂€广儱鎳忛崐鏍煕閹烘挻绶查柛鐐差嚟閳ь剙婀遍幊鎾绘儑娴煎瓨鏅€光偓閸愵亞顔愰梻浣瑰絻閺堫剟寮笟鈧畷?*闁诲繐绻嬬欢姘焽閻楀牊鍎熼柡鍥╁仦缁傚牓鎮橀悙鎻掆偓椋庣不閿濆瑙?* 闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐耿椤忓牆鍐€闁割偁鍎卞▍锟犳煟閵娿儱顏紒顕呭灦瀹曟岸寮甸悽鐢敌㈢紓?
          //      婵炴垶鎸哥€涒晛螞閵堝鍋?闂佸憡锚椤戝懎锕㈤鍫濇瀬缂傚牏濞€閸ゅ鏌ら崘鍙夋拱婵炲懏鐟︾粙濠勨偓锝傛櫇閻熸劙鏌曢崱鏇狀槮闁哥偛顕埀顒€缍婇埀顒佺〒椤撳搫鈽?闂佹眹鍔岀€氼垶顢氶姀锛勨枙濠㈣泛鐬奸幖鐓幟归悩鎻掓缂佽鲸鐟╁顕€鎮╅崹顐ｇ彧闂備緡鍙忕徊鑲╃博鐎甸晲娌柛灞剧懅椤撳搫鈽夐幘鎰佸剱婵℃彃鎽滅槐鏃堝箣閻愰潧顥曢梺鐓庡暱閺堫剙鈻嶅▎鎾存櫖?
          //      闂佺懓鐡ㄩ崹鍐差煥閹达附鍎嶉柛鏇ㄥ亜閺佸爼鎮楅崷顓熷殌闁活亙鍗冲?*婵炴垶鎸哥粔褰掑焵椤掆偓缁绘垵危?*闂佹眹鍔岀€氼喚鈧凹鍘剧划鈺冣偓锝庝簽濠€鎾煥濞戞ê顨欑紒妤€顦靛畷锝呂旈埀顒勬偩閻樻亽浜归柛妤冨仦閹瑩鏌ㄥ☉姗嗘Ф闁?
          //   閻?`center: ['50%', '50%']` 闂佺偨鍎查弻锟犲焵?闂侀潻绠戝Λ妤冪紦妤ｅ啫鎹堕柕濠忓瘜閸斺偓婵炴垶鎼╅崣蹇曟濞嗘挸妫橀柛銉ｅ妸閳ь剙鍊垮畷銉т沪缁涘袩闂佹寧绋戦¨鈧紒?
          //   閻?`radius: '70%'` 闂佺偨鍎查弻锟犲焵?闂佸搫鍊稿ú锕傚Υ閸岀偛瑙﹂悘鐐电摂濡查亶鏌ㄥ☉娆戔槈闁伙絽銈稿?`ts-universal-attributes-gradient-color`
          //     闂?026-10-15 闂佸憡鐟﹂悧婊冣枔閹达箑鍌ㄩ柣鏂挎啞閻庮噣鏌ㄥ☉姗嗘缂佸彉鍗虫俊瀵镐沪閻ｅ瞼鐛梺鍛婄閸ㄥ墎绮惔銊ョ煑婵☆垰鍚嬮悾閬嶆煕濡も偓閿曘倗娆㈤悙鐑樻櫖閻庡湱妞僲ber 缂備緡鍋夐褔鎮楅悜钘夌睄閻犲搫鎼粈瀣归敐鍛￠悹?vp闂?
          //     闁荤姳绀佹晶浠嬫偪閸℃稒鍎嶉柛鏇ㄥ亐閸嬫捇姊荤壕瀣槹 undefined 闂佸搫鍟晶搴ㄦ焾鐎靛摜纾奸柣鏃傤焾閻﹁崵绱撴担绋款仹婵炲棎鍨绘禍鎼佸传閸曢潧娈堕梺鐓庮殠娴滄粍鎱ㄩ埡鍐笉婵＄偛鐨烽崑鎾愁吋娴ｅ憡顏?闁哄鏅滈悷鈺呭闯妞嬪海纾?*闂佽皫鍕姢闁搞劌楠歌闁哄倽娉曢幗鐔虹磼濡ゅ绱伴悷?*闂?
          //     闂傚倸鎳庣换鎰邦敊閹版澘闂い顓熷笧缁€? 闂佽桨鐒﹀娆撴儓閸℃稒鏅璺烘唉濞夋煡鏌ㄥ☉妯侯殭缂佹顦靛浼搭敍濮橆厾銈奸柣?vp闂?
          //   閻?`colors: [['#26000000', 0], ['#26000000', 0.45], ['#66000000', 1]]`
          //     闂佺偨鍎查弻锟犲焵?闂佸搫鍊稿ú锕傚Υ?闁?.4 闁汇埄鍨遍幃鍌炲闯閾忚鍋樻い顓熷笧缁愭SCRIM_CENTER = "#26000000"`闂佹寧绋戦悢鍌炲箥娴ｅ壊鏆?5%闂佹寧绋戦ˇ顓㈠焵?
          //     `SCRIM_EDGE = "#66000000"`闂佹寧绋戦悢?40%闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪顢橀悙闈涱洭闂佽偐顢婂鎾剁博閹绢喗鍎庨柟缁㈠枟閹虫瑩鏌涢幒鎾寸凡鐎规洘鍔曢銉╁礋椤撶喓鏆?45% 闂佸綊娼х粔瀵告閹寸偞鍙忛悗锝庝簻缁旈箖鏌￠崱姗嗘缂?
          //     闂佹寧绋戦悧鍡涙偪閸曨垱鍋濆ù鍏兼綑濞咃繝鏌涢幇顓犳噭闁搞劍姘ㄧ划鍨緞婵炴儳浜鹃柤娴嬫櫆閻ｉ亶鏌涘鍓ь槮闁告瑦纰嶅璇测槈濡櫣鍘柣搴㈢⊕椤ㄥ﹤顭囨导瀛樼厒?`0x26/0x66`闂佹寧绋戞總鏃傜箔瀹€鍕Е閻忕偟鍋撻悗顔济归悩鐑樼【闁告瑧鍋撻幏鍛枎閹邦喚鎳侀梺?闁圭厧鐡ㄥú婵囩珶婵犲洤绀冩繛鍡樺姉閵嗗﹤鈽夐幘顖氫壕闂佸ジ鏀遍悾顏堝焵椤掆偓閸嬪﹦妲?
          //   閻?闂佽偐鎳撳鍫曟偉閿濆鍎嶉柛鏇ㄥ弾閸庢垵霉濠婂啫顨欓梺鍙夌矒瀹曟宕橀鍡╂Ш闂?*濠殿噯绲鹃弻褏娆?[0,1.0]**闂佹寧绋戞總鏃傜箔婢舵劕鍙?vp 闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷銈囩箔娴ｇ懓绶?0 / 0.45 / 1 闂佸搫鐗滈崜姘焽閻㈠吀鐒婇弶鍫涘妽绗?
          //     濠殿噯绲鹃弻褏娆㈤妷鈺佺婵炲棙鍔楅妴濠囨煥濞戞澧曢柟?闁?1.1 闂備緡鍙忕徊鎯ь焽椤栫偛纭€闁哄洦姘ㄧ粔鎾煕瑜庨崺濠勬鏉堚斁鍋撶憴鍕嗘垿寮婚悢鐓庡偍闁绘柨鎲￠悗顕€鏌曢崱妤勫鐟滄澘娲畷鎰版嚌閺夎法妲洪梺鎼炲劤缁绘繄鎷?[0, 1.0]闂侀潧妫楃粙鍕濮樿泛违?
          //
          //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸哥€涒晛螞閵堝鍋╃€光偓閳ь剙鈻撻幋鐐碘枖闁逞屽墯瀵?*閻庤鐡曠亸娆撴偂閳ユ剚鍟呮い鏃傚帶閻?*闂佹寧绋掔喊宥呂涢妶澶嬪仼鐎光偓閸曨偂绨兼繛鎴炴尨閸嬫捇鎮橀悙鎻掆偓鐟拔?*闂佽鍘界敮鎺旀?*闂佹寧绋戦悧鍡氥亹瑜旈幃?`scrim` 闁汇埄鍨伴崯顐︽儍閻㈠憡鈷掗柕濠忕畱娴犳﹢鏌ㄥ☉姗嗘缂?
          //      闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡樻尭濞咃繝鏌?*閻熸粏鍩囬崹纭呫亹?闁哄鍎愰崜娆忊攦閳ь剟鏌￠崼銏犳灈婵☆偄娼″畷妤呮惞椤愩垻顏?*闂佹寧绋戦悧鍡浰囬弻銉﹀仺?`backgroundRevealOpacity()` 闂佸憡鑹鹃張顒勵敄濞嗘挻鍎?
          //      `morphContainerActive()` 闂佸憡甯囬崐鏍х暤娓氣偓閺佸秵寰勯崱蹇撲壕闁哄倽銆€閸?闂佸憡鐔粻鎴﹀垂椤栨縿浜归柕蹇曞Т缂嶄礁鈽夐幙鍐ㄥ籍闁稿鎳忕粙澶愵敂閸ヨ埖钑?scale+clip 闂佹眹鍔岀€氼剟鎯冮鍌滅幓婵°倐鍋撶憸鐗堢洴閺?
          //      婵炴潙鍚嬮懝楣兯囬幐搴ｂ枖闁逞屽墰娴狅箓宕掑顒傤伝闂佸搫妫欓〃鎰濠靛洨鈻?闂佸憡顨呴敃顏堝焵椤掆偓缁绘垵危?闂?婵炴垶鎸哥粔褰掑焵椤掆偓缁绘垵危?闂備緡鍙忕徊鎯ь焽椤栫偛绫嶉柕蹇婂墲缁犳帡鏌涘▎娆戝埌缂佸墎鍋ら獮宥夊箻鐎甸晲妗撻梺?
          //      闁荤喐鐟ラ崐褰掑礉閸涙潙鍙婃い鏍ㄧ閸庡﹪鎮烽弴姘卞妽闁轰礁銈搁獮瀣箛椤撴繆鍩呴悗娈垮枓閸嬫捇鏌?*闂佸憡鐟禍锝夊礂濡崵鈻斿┑鐘插暞缁ㄦ岸鏌?*闂佹寧绋戦悧鎰帮綖閸℃稑瀚夋い鎺戝暟閺嬪倿鏌熼煬鎻掑姎闁硅绻濋幆?闂佸憡鐟禍锝夊礂濡崵鈻斿┑鐘插暞缁ㄦ氨鐥褍鏋︽い?濠电偞鎸搁幊搴＄暦閻斿吋鏅璺虹墐閸?
          // 闂?缂傚倸鍟崹鍫曟偋閹间焦鍤勯悘鐐靛亾閻濐垶鏌ゆ總澶夌盎闁汇埄鍋婂鍐参旈崟鍨仴 闂?闂佸憡鐟禍婵嗭耿?*闂備緡鍋€閸嬫捇鏌涢妷褍浠﹂懚鈺冪磼椤栨熬宸ョ紒銊﹀▕瀹?*闂備緡鍙忕徊鎯ь焽椤栨粍宕夋い鏍ㄧ☉椤ゅ懘姊婚崶锝呬壕闁荤喐娲戝ù鍥╂崲閺嶃劎鈻旈柍褜鍓涙禒?
          //   闂佹寧绋戦悧鍡涘箚娓氣偓瀹曟艾鈻庢惔锝囩崶闂佸憡鐟ф慨宕囨偖鏉堛劎顩烽柤鎭掑劜椤斿倿鎮峰▎鎰嚋缂佽鲸绻冪粙澶愵敇閻愰潧顩柣鐐村嚬閸嬪嫮鏁崶銊р枖闁靛牆顦幉楣冩煥濞戞﹩妲堕柍?
          if (this.meshSrc === undefined) {
            // ★★★ 2026-10-18（用户第二轮：「点击展开过程背景还是有问题（**似乎是上一首歌的颜色**）」）：
            //   **去掉这层兜底暗角**。上游播放页背景只有网格一层、连背景宿主都没有底色
            //   （见 `_recover/logic-src/full/差异表-背景.md` 的 P1 / B6），而这一层 `if (meshSrc === undefined)`
            //   恰好**只在"还没有网格源"的起手几帧存在** ⇒ 打开那一瞬屏上就是
            //   「透出来的下层首页 + 一圈 15%~40% 黑的暗角」= 用户看到的那块"上一首的颜色"。
            //   ⇒ 起手就保持纯透明（与上游一致）；网格源到了由 `MeshCoverBg` 自己画（它恒有兜底网格，不会空）。
            Blank()
              .width(0)
              .height(0)
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘极閵堝绠ｉ柛鎴欏€楃粣妤呮煏閸℃顨欑紒妤€鍊块獮蹇斿緞鐎ｎ亖鍙洪悗娈垮枓閸嬫捇鏌￠崼婵愭Ъ闁稿孩顨婂鏌ヮ敍閵堝洨顦?*闂佺粯鍔楅幊鎾诲吹椤斿彞娌柡鍥╁仧绾?/ 闂佺绻戞繛濠偽?/ 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧┑鐐插閸撴繂锕㈡笟鈧幊妤冧沪閻愵剛褰?*闂侀潧妫楃粙鍕?
              //
              // ## 闂佸搫鐗嗛幖顐﹀春濡ゅ懏鏅柛顐秵閸ゃ垹霉閻欏懐鎮奸柣?+ 婵炴垶鎸堕崐鎾绘煂濠婂懏瀚氱紓浣股戝▓鍫曟煕濡も偓閸熻法娆㈤柆宥嗘櫖?
              // ```
              //   缂傚倸鍟崹鍫曟偋閸濄儰娌柛灞剧⊕绗?`if (meshSrc === undefined) { 闂佺绻戠划宀€鑺?} else { MeshCoverBg(...) }`
              //   闂佺粯鍔楅幊鎾诲吹椤斿彞娌柡鍥╁仧绾?/ 闂佺绻戞繛濠偽涢幘顔肩煑闁瑰濮甸弲鍝モ偓鐢靛椤ㄥ棗螞椤撱垺鏅悘鐐佃檸閸斿啴鏌?`song.cover` 闁哄鏅滆摫闁汇儱鎳樺畷姘舵偋閸繍鏉?闂?meshSrc === undefined
              //   闂?缂傚倸鍟崹鍫曟偋閸涘﹦鈻旂€广儱妫楅惁顖炲级閻愬瓨鐏紒閬嶄憾閹虫挾浠﹂挊澶婄闁圭厧鐡ㄥú婵堟崲閺嶃劎鈻旈柕鍫濇噽濠€鎾煟閵娿儱顏繛鍫亞閹叉挳骞掗幋鐘冲嬀闂佸憡顭囬崰鎰焽閻㈢绀冩繛鍡樺灦缁?
              //        .opacity(morphContainerActive() ? 0 : 1)
              //     闂?**閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮閸斺偓婵犻潧鍊芥慨銈嗕繆閸濄儮鍋撻悷鏉挎殭闁告鍥х?* 闂?闁诲繒鍋涚换瀣箔閸岀偛鐭楁い蹇撳閳锋牠寮堕埡鍌氱伌缂侇噯绠撳畷锝夊冀閵娧冾棊闂?= "濠电偛澶囬崜婵嗭耿娓氣偓閹虫浠﹂悙顒傚讲"
              //   婵炴垶鎸搁敃銉﹀垔濞差亜绠ラ柟鎯х－绾惧鏌熼鍌滃笡婵″弶鎮傚畷锝夊箣閻樿櫕娅㈤梺闈╄礋閸斿矂鎯冨┑瀣棃闁靛繒濮撮～锝夊级閻愯埖顥夐柣锝庡墯缁嬪﹦鈧綆浜濋崐?闂?缂傚倸鍟崹鍫曟偋閹间礁鎹?闂?濠殿喗绻愮徊浠嬫偉?闂?
              // ```
              // ## 闂佽　鍋撻悷娆忓閵?
              //   闂佺绻戠划宀€鑺卞畷鍥︽勃闁稿本绮嶉悾閬嶆煛閸℃﹩娈欐い?*婵炴垶鎸哥粔鐑筋敊韫囨稑鎹堕柕濞垮劥閸╁矂鏌涘▎鎯挎垵锕㈤垾鏂ユ闁割偅绺挎禍?* 闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顖烆敆濠靛绀嗙紓浣股戠瑧**闂佸摜鍎愰崹顖滅博閹绢喗鍎嶉柛鏇ㄥ枛閸撳綊鏌?*闂?
              //   闂佹寧绋戦悧蹇曠礊婢舵劕鍐€闁绘挸娴烽幗鐘绘煕閿斿搫濡芥俊鐐插€瑰璇测枎閹邦叀鎷梺鍛婂笒濡瑩寮鈧鐣屾喆閸曨剚瀚虫繛鎴炴尭缁夐鎹㈠鈧弫宥囦沪閹屾殹婵炲濮伴崕鎵箔婢跺顕辨慨姗嗗墯鐎氳尙绱撻崘鈺佺仸闁绘鎮傞幊娑㈩敂閸曨厽鏆旈梺姹囧妼鐎氼厼鈻撻銈嗗枂闁圭儤鍨电紞灞解槈閹惧崬鈧捇宕妶澶娢ラ柛宀嬪缁€?
              .opacity(1)
              .hitTestBehavior(HitTestMode.None)
          }

          // 闁诲繐绻嬬欢姘焽閹殿喚纾兼い鎾卞焺濡勭箾閹碱厼鏋涢柣顏冨嵆閺佸秴顫濋鍙ョ泊闂侀潻璐熼崝蹇涘磿濡ゅ懎鐤炬い鏍ㄧ懅閻熴垽鏌涢幇顒佸櫣妞ゆ梹鍔栫粙濠勨偓锝庡枟閿涚喖鏌ㄥ☉妯垮闁搞劌绻戦妵鍕偨缁嬪じ绨?0.36 缂備礁顦扮敮锟犲闯闁垮浜滈柤绋跨仛缁傚苯鈽夐幘鍗炩偓鏇犳閸洘顥堟繛鍡樺姀閸嬫挻鎷呴崫銉︻唸闂?
          // No cover overlay: the lyric page has no matching image destination.

          // 闂佸疇妫勯幊澶娢?2026-10-15 闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷礁鐡ㄧ粙澶愬Χ閸℃鎷梺鎸庣☉閻胶鎹㈤弽銊р枖闁逞屽墯瀵板嫰宕熼浣囷箓鏌涜箛鎾宠埞闁诡喗鎹囬幆鍐礋椤掑倸顥戦梺?
          //   闂?*闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱妫欑瑧婵炲濮寸€涒晠宕瑰鍛剨濞撴埃鍋撴繛闂村嵆閹虫浠﹂懞銉モ偓鐢告煕閹达絾顏犳?*闂佹寧绋戞總鏃傜箔婢舵劕鍙婃い鏍ㄧ懅閻倕鈽夐幘鎰佸剱闁哄瞼鍠愰ˇ浼存倷閹殿喚鎲梺鍝勵槶閸庮垶鍩€?闂侀潧妫楅惌浣烘崲濡粯鍎熼柨鏃囧Г閽傚霉閸忛棿浜㈡い顐畵楠炴劙鍨鹃懠顒傂ら梺鎸庣☉閻楀棝宕曞璺哄強妞ゆ牗姘ㄥ▓閬嶆⒒閸稑鐏悘蹇撴嚇閹啴宕熼崜浣侯槴闂?
          //   闂?缂傚倷绶￠崣鍐夐敐鍥︾剨濞撴埃鍋撴繛闂村嵆瀹曘垽鎮㈤崨濠囨闂佹眹鍨奸褍锕?*闂佽桨鐒﹂幐鎶藉Υ婢舵劕绀冮柛娑卞弾閸熷洤鈽夐弬娆惧剮缂?*闂佹寧绋戦悧濠囨偋?Stack 闂佹眹鍔岀€氼厼銆掗崼鏇炶Е閹煎瓨绻勯鍗炩槈閹垮啩绨绘い鎺嬪灮閳ь剚绋掗崝褏妲愬鑸垫櫖閻忕偠鍋愰懝楣冩煛?
          //     閻?婵炲濮寸花鑲╃箔閸涙潙纭€闁搞儺浜濆畷鎶芥煟?*闁诲繐绻愮换鎴︽偤閺囩姵瀚?*闂佺绻愰悧鎰帮綖閿旈敮鍋撻悷鏉挎殲閻忓繐鎳橀幆鍫ュ焵?闂?闂佹椿浜滈鍫ュ箲閿濆绾ч柕澶涢檮绗?婵炲濮存鎼佹儍濠靛顥堥柕蹇ョ到閸撳綊鏌涘顒勵€楅柛鐔奉儔瀹曟瑩鎮滃Ο濠氭"闂?
          //     閻?闂佸憡鑹鹃張顒勬偋鏉堛劎顩烽幖瀛樼箘閻熸捇鏌涘Δ鈧ú鈺呭箲閿濆鍎?*闂佺鐭囬崘銊у幀闂?*闂佹寧绋戦悧鎰崲濡粯鍎熼柨鏃囧Г閽?闂佸湱顭堥ˇ鐢稿箰閹惰姤鏅璺侯槺閻﹀秴霉閸忛棿浜㈡い顐閳ь剛鎳撻崯顐ゆ暜閸ャ劍濯撮煫鍥ь儌閸?
          //   闂佺粯绮嶅妯猴耿椤忓牆绠┑鐘插€婚弳濠囨煙閸撹弓绨婚柛?*闂佸憡鍔曢幊搴敊閹邦喕娌柛灞剧懅椤撴椽鏌?*闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁俊顖滅帛閸╁倿姊婚崒姘辨憼闁规悂浜跺銊︺偅閸愶腹鍋撴径鎰殜妞ゅ繐瀚粻鎺楁⒑椤撱劎鍒扮紒鍗炵埣閹洭鎮㈡搴㈩唸闂傚倸鐗勯崹鍝勎ｉ幖浣光挄闁归偊鍨遍ˉ鎴︽煟?
          //   闂佹寧绋戝濉篹alCoverVisible()` 婵炴垶鎸搁幖顐ｇ?闂?闁诲繐绻嬬欢姘焽閺夎锝夊箣閹烘梻孝闂佸搫瀚烽崹鎶藉煘閺嶎厽鍎嶉柛鏇楁杹閸嬫挻绗熼埀顒勫焵椤掆偓缁绘垵危閹达附鍎嶉柛鏇炲缁€鍡涙煥濞戞ɑ婀板褍绉电粋鎺楀Ψ瑜忛弫鎯ь渻鐎ｎ剙浠滈柣銊︾箞濡啴濮€閵忕姴瀛ｉ梺鍝勭Ф閸忔﹢鍩€椤掆偓缁绘劗娆㈤柆宥呯闁绘垶蓱闂勫秹鏌?
          //   婵炶揪绲界粔鍫曟偪閸℃鈻旈幖缁伴娴烽柣蹇撶箰缁诲绮╅弶鎳崇喖鍨鹃懠顒変紘闂佸搫绉撮崵鏍濞嗘垟鍋撻悷鏉挎殲婵犫偓娴兼潙绾ч柕澶堝劜閻ㄦ垿鏌￠崟闈涚仭閻?闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨惧畷鍥唸闂?闂?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺〒濞堥亶姊?闂佸湱绮敮鎺楀焵椤掑啫浜归柡渚€绠栭幆鍐礋閸撲胶顦梺?
          //   闂?*闂佸湱顣介崑鎾绘煛閸繍妲哥€规洖鏈粙澶嬬節閸愨晠妾烽梺姹囧妼鐎氼剟宕€电硶鍋撻悷鎵Ш闁稿繑锕㈠畷鐑藉Ω閵壯勬疁婵炴垶鏌ㄩ鍕箔?* 闂?婵炴垶鎸堕崐妤冨垝瀹ュ棭妲归柣鎰絻瀵娊姊洪灏栧亾閻斿嘲骞嬮柣鐐村嚬閸嬪棗锕㈤崨顖涘枂濞撴艾锕︾粈澶娾槈閺冨倸鏋嶇紒妤€顦靛畷妯侯吋閸曨參鐎洪梺鐑╂櫆閹倹瀵奸崟顖氱?闂佺偨鍎查弻锟犲焵?
          //   闁哄鏅滈悷锕€危閸濄儳纾奸柟鎯ь嚟閳ь剦鍨辩粙澶嬬節閸曨剛鏆犳繛锝呮处缁诲棝鎯佹径鎰櫖閻忕偠鍋愰悷?闂備焦褰冪换鎰闁秴绀勯柛鈩冩礈閻熸繈鏌?闂佸搫鍟版慨鎾矗瑜旀俊?
          //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸哥粔鐑姐€呴敃鍌氱鐎广儱妫楅惃鎶芥煕閵壯冧粶妤犵偞鎹囬弫宥夊春?7 闂備緡鍙忕徊楣冾敃?闂佹椿浜滈鍕箔婢跺本鍠?闂佸搫瀚烽崹閬嶅垂濠婂牆瑙﹂悘鐐跺亹椤忛亶寮堕悜鍡楁灈濠殿喚鍋ら幆?`barOpacity` 闂佺娉涢敃銊у寲閻樿櫕濯撮柣妯挎珪閽傚鏌ｉ鍡楁灆闂傚ň鏅滅粙濠囨偄缂佹﹩妫忔繛瀛樼矊濡繈鍩€椤掑倸校闁搞劍宀搁幆鍐礋閸撲胶顦?
          //      闂備緡鍙忕徊濂告煂濠婂牊鈷掗柕濞垮劚閸ゆ帞绱撴担鍝ョ闁搞劌缍婂浠嬪Χ韫囨洖鑰块梺鍝勭墱閸撴繃淇婇鐔镐氦婵炲棙鍨甸。鍏肩箾鐏炵澧叉繝鈧担琛″亾閻熸澘鏋︾紒杈ㄥ哺婵?
          // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍡涙晬閹炬湹娌柛灞剧閻т線鎮橀悙鎻掆偓鍧楀磻閸涱喚鈻旈柍褜鍓氬顏堫敋閸℃瑧顦梺?*闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柛蹇撴憸閻熸繈鏌涢幇顒傂ら柡浣哄亾濞艰鈻庤箛鏇犲€炵紓鍌欑贰閸欏啴藟閿濆洣鐒婂〒姘ｅ亾婵?* 闂佺偨鍎查弻锟犲焵?
          //   `hostsMorphOverlay()` 婵炴垶鎹佸▍锝咃耿閿熺姵鏅柛顐ゅ枎椤や線鏌?濡ょ姷鍋犲▍鏇烆熆濡￥浜归柕蹇婃閸嬫挻绗熸繝鍕槴闂佸搫鍟抽鎰濠靛鐒介柨婵嗗椤忚鲸淇婇锝呯瑨闁告埊绱曠槐?*闂佸湱鈷堥崜娆撳春鐏炲墽鐝堕柛鎰皺濠€瀛樼箾閹碱厼鏋涢柣?*
          //   闂佹寧绋戝濉竢oducts/default/src/main/ets/pages/Index.ets` 闂?`MorphCoverClone()`闂佹寧绋戦¨鈧紒?
          //   濡ょ姷鍋炲﹢鍦箔閺嶎厽鍋?*闁诲海鎳撻崯鎶藉吹濠婂喚鍟呴弶鍫氭櫆閻ｉ亶寮堕埡鍌溾槈閻?* `morphOverlayP` 婵＄偟鎳撳畷顒佹叏閳哄懏鏅?60ms闂?
          //   `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)`闂佹寧绋戦ˇ顓㈠焵?
          //   闂佷紮绲鹃悷銉ワ耿椤忓牆绠绘い鎾跺枑閺夌懓顪冮妶鍥ㄦ毈闁革絿鍏橀幃浠嬫嚒閵堝棛鏆犻梻渚囧弿缁茶偐绮╅幘顔藉亱闁割偆鍠愮粻鎺戔槈閹绢垰浜炬繛鎴炴惄娴滅偟鍒掗妸鈺佸嚑闁告洦鍏橀崑鎾诡槼闁伙附妞介幆鈧柛婊冨暟缁愭鎮楅悷鏉挎殭婵犫偓椤忓懏浜ゆ繛鍡楅叄閸?*闁?scale+translate 闂佸憡鐟﹁摫鐎规洖寮跺濠氬炊閵夈垹浜?
          //   闁哄鏅滈敋闁?`.clip()` 婵炴垶鎸告鍛婃叏閳哄懎绠?`.height(morphClipHeight())` 闂佹眹鍔岀€氼剟顢欓幇鏉块棷?*闂備焦褰冮惌澶屾濠靛鍎楅柍杞版祰閸╁矂鏌涘Δ鈧悺銊ノｉ崫銉х幓婵°倐鍋撶憸鐗堢洴瀹曟悂骞囬鐘茬伇
          //   闂?闂佸憡鐟禍婵嗭耿?p=1闂佹寧绋戦悧濠冪閻ｅ瞼椹冲璺猴工缂嶄線鏌熺拠鈩冪窙缂佽鲸宀搁獮宥咁吋閸曨偆鑸归梺鍝勭Т閸氬顢楀鍛厹妞ゆ洖妫涚粈澶娾槈閹垮啫寮柍褜鍓氶弻銊ㄣ亹瑜旈幊?闁哄鏅滈崹鎶藉箮閳?闂佹寧绋戦懟顖氼啅婵犳艾鐭楅棅顐幘閻熸劙鏌涘▎蹇曅㈡い锔界叀瀹?闂佸憡鎸哥粔鏉戠暦閹邦兘鏋旈柣銏犵仛缁犳瑥鈽夐幘宕囆ユい?/
          //   闁荤偞鍑归崑鍕春閸℃稒鍎嶉柛鏇ㄤ簽椤愪粙鎮峰Δ浣割嚋閻忓繐鎳忛幏?闂侀潧妫楅崐鍦嫚閻愬吀娌柛宀€鍋涙禍婵喢归悩鍐茬亰缂佹顦靛畷鐑藉Ω閵娧咁啇婵炴垶鎼╂禍婊堫敊閹版澘闂柕濞炬櫅濞咃繝鏌ㄥ☉妯绘拱闁汇儱鎳樺鍨緞鎼达絿顔愭繛鎴炴惄娴滎亜螞閼哥绱ｆ俊顖滅《閸?
          //   闂佸疇娉曟刊瀵哥箔?闂佸憡甯囬崐鏍蓟閸ヮ剙绾ч柍銉ュ级椤愯棄鈽夐幘宕囆ｆ俊?p 闂佸憡甯炴晶妤呮儉閸涙潙绀?闂佹寧绋戦惌渚€鍩€椤掆偓閺堫剙危?*闁诲海鎳撻妵妯尖偓闈涚焸瀵灚寰勭€ｎ剚鈷曢梺鍝勭墕椤︽壆鏁€靛摜涓?*闂佹寧绋戦悧鎰帮綖?`hostsMorphOverlay()`闂佹寧绋戦¨鈧紒?
          //     PC 婵犮垻鎳撻崯鍧楁儑娴煎瓨鏅柛褍鍩oducts/pc`闂佹寧绋戦ˇ宕囨崲閺囩偐鏌﹂柍鈺佸暙婢跺秹寮堕埡鍌滄噥闁哥偑鍊曢湁妞ゆ棁鍋愬﹢鎾煥濞戞鐒搁柛瀣噺濞?*缂傚倷缍€閸涱垱鏆伴梺姹囧灱妞存悂骞愰柆宥呯哗濡わ絽鍟ㄩ埀顒€顦甸幊娑㈩敂閸曨厾鐣抽梺?*
          //     闂佺偨鍎查弻锟犲焵?闂佸憡鐔粻鎴﹀垂椤栨稑顕辨慨姗嗗墮濮ｅ鏌?婵炴垶鎸堕崐娑氱博閻斿吋鐒鹃柟瀛樺笧閻熸繈鏌?闂?*闂佸搫鍟版慨鎾儍濠靛顥?*缂備礁鐬奸崕銈夊Υ閸岀偛违?
          //   闂佸疇娉曟刊瀵哥箔?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暙濞堟壆鈧鎮傛禍鍫曞磻閸涱収鍤?*闂佹椿浜為崰搴ㄦ儍濠靛顥?*闂侀潻璐熼崝宀勬嚋娴兼潙鐭楁俊顖滅帛閸╁倿姊婚崒婊呯瘈缂侇喗鐩幃鐐哄嫉閻㈢數鎲归梺娲绘線缁鳖喚妲愬淇絜alCoverVisible()` 闂備緡鍙忕徊鐐繆閹间焦鈷掗柕濠忓濮婇箖鏌涢弮鎴犲帨缂佽鲸宀搁弫?
          //     闂佸憡鐔粻鎴﹀垂椤栨稑顕辨慨姗嗗墮濮ｅ鏌ｅ鍫殥閻炴俺椴哥粙澶愵敂閸曨厽顔堥梻鍌氱墱濠胶妲愭潏銊р枖闁靛牆鐗冮崑鎾诲川椤掆偓缁鳖剟鏌″澶嬶紵缂併劍澹嗛幃浼村Ψ閿濆倸浜?
          if (this.expandState.morphBridging() && !this.expandState.hostsMorphOverlay()) {
            this.MorphCoverBridge()
          }

          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦鍋嗗﹢瀵哥磼?*闂佹寧绋掓穱娲磿濡ゅ懎鐤炬い鏍ㄧ闊剛鎲搁懜顒€鐏╃憸鏉款槺閳ь剙婀遍幊鎾斥枍?*闂佸憡鍔曢幊姗€宕?*闂?
          //
          // ## 闂佺懓鐡ㄩ崹宕囩不閿濆绀堢€广儱顦伴弲鈺呮煕閿斿搫濡奸柟濮愬灲閺佸秹宕奸敐鍥╊啎闂備焦瀵ч悷銈囩箔娴ｈ濮滄い鏇炴缁€澶愭煟椤剙濡介柛鈺傜洴瀹曡泛鈽夊▎妯轰还闁诲骸婀遍崑鐐电矈閹绢喖绠ラ柟鎹愭珪缁€鈧梺闈涙閺堫剟骞愰柆宥呯哗闁诡垎鍕綔闁诲繒鍋炲ú鏍閹寸偞浜ゆ俊顖滅帛绗戦梺鐓庡暱閺堫剙鈻嶅▎鎾崇闁靛鍎冲宀勬煏閸℃鈻岀紒?
          //
          // 闂佺懓鐡ㄩ崹宕囩博閹绢喗鍎庣紓鍫㈠С缁ㄦ澘鈽夐幘璺哄妺婵☆偁鍊濋幃鎯х暆閳ь剙鈻?`MeshCoverBg` 闂?`playerPane` **婵炴垶鏌ㄩ鍛此?*闂佹寧绋戞總鏃傝姳椤掑嫬鍙婃い鏍ㄧ☉鎯熼柣搴ｆ嚀閸燁垶骞嗘径鎰闁绘鐗婇幏鍗烆渻閵堝懐浠涢柣?
          // `Stack` 闂?闁?*婵炲濮村ù鐑筋敄閸ャ劎鈻旈柍褜鍓涢弫顔款槻婵ǜ鍔戝顐﹀级閹寸姵缍?*闂侀潧妫斿ù鍥焵椤掆偓婵傛梻绮?*闁荤喍妞掑鎺旂箔婢舵劕绀?*闂?
          //
          // 闂佸搫鐗滈崜婵嬫偪閸℃稑绠┑鐘插暞閿熴儵鏌ｉ敐鍛伇婵?*闁诲骸婀遍幊鎾斥枍閹烘鍐€?*婵炴垶鎸撮崑鎾绘偣娓氼垰鐏ユい鏇氬嵆閺屽懎顫濋銈呮櫓闂佹寧绋戝澧倁jie.pa`闂佹寧绋戦¨鈧紒?
          // ```
          //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   闂?闂?Stack
          //   @36***# (191388)  Stack(TopStart)
          //                       .scale({x: expand.scaleValue, y: 闂佺偨鍎哄ú?      191400-191415
          //                       .translate({x: expand.translateX, 闂佺偨鍎哄ú?     191416-191431
          //                       .width(expand.clipWidth)                  191432-191441
          //                       .height(expand.clipHeight)                191442-191451
          //                       .borderRadius(expand.radius)              191452-191461
          //                       .clip(true)                               191462-191469
          //                       .id(PLAYER_ROOT_ID)                       191470-191478
          //                     闂佸疇顫夋竟鏇㈠绩?If (191716 @36***#^4)
          //                     闂?   闂佸疇顫夐弻锟犲绩?Column (191756 @36***#^5)  闂?濠电姴顭槐鏇㈡偘閵壯€鍋?+ winHVp + padTop/padBottom
          //                     闂?        闂佸疇顫夋竟鏇㈠绩?If (191972 @36***#^7 闂?@36***^7*#) = **playerPane**闂佹寧绋戝﹢锕恮闂?
          //                     闂?        闂佸疇顫夐弻锟犲绩?If 闂?**MeshCoverBg**             192105 / 192191
          //                     闂佸疇顫夐弻锟犲绩?闂?
          // ```
          // 闂?**`MeshCoverBg` 闂?`PLAYER_ROOT_ID` 闂備緡鍙忕徊濂告煂?Stack 闂佹眹鍔岀€氫即宕抽悜鑺ヮ棃?* 闂?闁?*闁荤姾娅ｉ崰鎾愁焽閸愵亖鍋撻崷顓熷殌婵炲懏甯楃粙澶愬焵椤掑倹灏?
          //   `scale`闂侀潧妫斿鎺旂博鐎靛憡灏庨柣銈庡灱濞?`clip`**闂侀潧妫楅崐鐣屾崲閺嶎厼绠ョ€广儱妫欑瑧"闁诲繒鍋炲ú鏍閹达箑绫嶉柟顖涙緲閸撳綊鏌￠崪浣哥仧缂佹顦扮€电厧顫濋鐔割啋闁诲繒鍋涚换鍫ュ焵椤戞寧绁伴柍褜鍓欓張顒€危閸涘﹦顩烽幖杈剧磿濮ｅ牏绱掗幇顓ф當鐟滅増鐩弻灞界暆閸曨剚鐦ｉ梺鍛婂灩閸庛倕顭?闂佹眹鍔岀€氼厼鈹冮埀顒勬煕閹烘洜鍫柍?
          //
          // 闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鍫曨敆濠靛绀堢€广儱顦禍婵嬫煕?闂佸搫鍟版慨鐑藉疾椤愶附鍎?`MeshCoverBg` 闂?`playerPane` 婵炴垶鏌ㄩ鍛此囨繝姘櫖闁割偅绮庨悷銏ゆ倵閻熸澘鏆欓柟顔芥尵閻ヮ亣顧傜紒?**闂佸搫瀚烽崹鍫曞极婵犲洦鍎?* 闂佺偨鍎查弻锟犲焵?
          //   闂佸搫顦崕鑼姳椤曗偓瀵即顢涘顒侀敪闂佹椿浜滈鍕姳閿熺姵鍋嬮柛銉厛閸炰粙鏌曢崱鏇犲妽闁汇儱鎳橀獮?`PLAYER_ROOT_ID` 闂備緡鍙忕徊濂告煂?Stack 闂?*闂傚倸鍋嗛崢濂稿箖鎼淬劍鍤戦柛鎰╁妽缁?*闁荤姴娲╅褔宕甸銏犵骇闁靛绲洪崑?
          //   闂佹寧绋戦悧鍡楊啅婵犳艾鐭楅柛娆忣槹閺嗗牓姊洪幓鎺炶含闁革絿鍏樺畷娆撴缂佺粯鐗楃粙濠囧醇濠靛棙娅㈤梺姹囧妼鐎氼亞绮╅幘顔惧祦闁哄牏鏁哥粙濠囧箹鐎电鏋傞柍褜鍓欓崑濠勬?
          //
          // ## 闂佽　鍋撻柟顖嗗嫯鍚柣搴℃贡閹虫挸鈻嶉幒妤佺厒閻忕偠濮ら崐閬嶆煛閸愨晛鍔剁悮娆撴煕閹邦剙甯犻悶姘抽哺缁傛帡寮甸悽鐢垫
          //
          // 1. **闁诲繒鍋炲ú鏍閹寸偟鈻旂€广儱鎳庨弲?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛鍎冲?**闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁俊顖滅帛閸╁倿鎮楅崷顓熷殌婵炲懏甯″畷锝夘敂閸涱喚鐣抽柡澶嗘櫈濞撳湱绱炲鈧鍫曟晸閻樿弓绨兼繛鎴炴煥閻楀棝濡?闂?闂佺厧鍟块張顒€鈻嶅▎鎰枙闁绘柨鍢插☉褔鏌涢敂鍝勫闁稿鎳忕粙澶愬焵椤掑倷鐒婇煫鍥ㄦ尰閸嬨儵姊洪幓鎺旂効缂?
          //    闂傚倸鎳庣换鎰邦敊閹版澘闂柕濞炬櫆濮ｆ劕顭块崼鍡楁閸嬫挸鐣濋崟顒佸殘閻庢鍠掗崑鎾绘煥?
          // 2. **闂佺绻戞繛濠偽涢幘顔肩睄闁诡垱婢橀崜褰掓煛閸滀礁鐏ョ紒鎰剁節閹牓鍩€椤掍胶鈻旈柍褜鍓涢幐褍鐣￠弶璺伝**闂佹寧绋掗懝楣冾敊閹版澘闂柕濠忛檮閹烽亶鏌℃径鍫濆姎婵ǜ鍔戝畷鐑藉Ω閵娧呭敶闂佹眹鍨瑰畷顒勬晬閹剧粯鐒介柨婵嗘閽?`morphSquashY` 闂佹眹鍔岀€氼亞绱為弮鍫熷仺闁靛鍎抽崢鐢告⒑?
          //    闂?婵炴垶鎸哥粔鎾疮閳ь剟姊婚崶锝呬壕闁荤喐娲戦悞锕傚垂濠婂嫮鈻斿┑鐘辫兌椤忛亶鏌ｅΔ鈧悧鍡樻叏閻愮儤鍎?`.scale + height + offset` 闁荤偞绋忛崕杈ㄥ閳哄啠鍋撻崷顓熷殌婵炲懏甯￠弫宥夊醇濠靛棗娈ラ梺鍛婂笧婵妲愬璺何?
          //
          // 闂佸疇娉曟刊瀵哥箔?婵炶揪绲界粔鍫曟偪閸℃稒鏅慨姗嗗墻閸熷洭鏌?`Column` 闂?*缂備焦顨忛崗娑氱博鐎涙鈻旀い蹇撳閸斿鎮?*闂佹寧绋戦悧鎰板磿濡ゅ懎鐤炬い鏍ㄧ闊剙鈽夐幘鎰佸剭闁逞屽厸缁€渚€宕€电硶鍋撻崷顓熷殌婵犫偓椤忓懐鈻斿┑鐘茬箳缁€鍡涙煥?
          //   `.position({x:0,y:0})` 闁荤喐娲栧Λ娑樏烘繝鍥ф瀬缂傚牏濞€閸ゅ鎮楅崷顓熷殌婵?闂?婵炴垶鎸哥粔鏉戭嚕椤掍胶鈻旈幖杈剧稻濡鏌涘顓炵仸閻㈩垱鎸鹃弫顕€宕樼捄銊ь槱闂佸憡鐔粻鎴﹀垂椤栨稑顕辨慨姗嗗幖鎯熼梺鍛婂姇閹冲酣顢欓幇鏉跨闁靛牆瀚悷鎾绘煕濡湱涓茬紒杈ㄥ哺婵?
          Column() {
            // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*缂傚倸鍟崹鍫曟偋閸濄儰娌柛灞炬皑閸╂顪冮柅娑氫覆缂佽鲸绻冪粙澶婎吋閸涱厽娅冮梺?`if` 闂侀潻璐熼崝宀勬嚋娴兼潙鐭楁俊顖滎攰閸橆剟姊洪锝嗏拹閻庡灚娲樺?* 闂佺偨鍎查弻锟犲焵?
            //   婵烇絽娴傞崰姘跺极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓惉濂稿磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸嬫捇鏌ㄥ☉娆掑濠殿喒鏅犻幃浠嬪及韫囨洜鐣虹紓浣割儏椤戝棝鎯€閸涘瓨鍤勯悘鐐靛亾閻濐垶鏌曢崱鏇狀槮濠殿喒鏅犻幃浠嬫嚒閵堝洦灏濋梺鍝勵槺閸犲骸顫濋妸鈺佸珘濠㈣泛鐗冮崑鎾愁吋韫囨洜顦?
            //
            // ## 婵炴垶鎹佸銊у垝閸喓鈻?闂佸搫顦埀顒€寮堕浠嬫煙缁嬪灝鈧棄霉?婵炴潙鍚嬬喊宥囨閿熺姴绠冲璺侯儐濞堢粯绻涢崼銉︽锭濠殿喒鏅犻幃?
            //   闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佸搫鍟悥濂稿Υ婢舵劖顥堥柕蹇曞Т閻忕娀鏌熺粙鍨偓钘壝归崶顒€违濞戞棏鏌峞shSrc` 闁哄鏅滆摫婵?undefined 闂?`if` 闁荤姍鍕凡闁告顫夐幆鏃堝即閻愯尙鈧鏌￠埀顒勵敍閵堝洤鑰?
            //   缂備焦绋戦ˇ杈╃礊婢舵劕鍐€闁稿繗鍋愰悥閬嶆煕閹烘柨顣煎褎绮撻弫宥夊醇濠靛棙顓婚梺鍛娿仦缁ㄣ儵鏌涢幋鐘残ユ繛?ms 闂佸憡鑹鹃崙鐣屾濮濇f` 闂佸綊娼х粔鍫曟倷閺囥垺鍎?闂?**`MeshCoverBg` 闂侀潻璐熼崝宀勬嚋娴兼潙鐭楁俊顖濇硶缁犲鎮跺☉妯垮闁糕晛鏈粙澶愬焵椤掑嫬纭€濠电姴鍟ˇ?
            //   闂佸綊娼х粔鍫曨敄閸ャ劎鈻旈柍褜鍓欓埢搴ㄥ焺閸愩劎妲搁柡?*闂侀潧妫楅崐浠嬪焵?`NodeContainer` + `RenderNode` 闂侀潻璐熼崝搴ㄣ€冨☉銏犵闁割偆鍣ラ崝鈧柣?`animateTo`
            //   闁荤偞绋忛崕闈浳涢崸妤佹櫖闁秆冨焻eight`/`clip` 濠殿噯绲界换鎰板箮濮樿泛鎹堕柕濞垮劚缂嶄線鏌ㄥ☉姗嗘Ш婵炲牊鍨垮鐢告偄閸忕》绱垫俊顐稻閻楁顢曟總绋跨闁稿本绻冪粊浼存煛閸愵収鍟囩紒杈ㄧ箞閹虫盯顢旈崱娆忕闂佸憡鍔曢幊搴敊閹邦喗鍟哄ù锝堟閹煎ジ鎮跺☉鏍у姦婵☆偄娼″銊ф崉閾忕懓鏆￠梺?
            //   闂佽桨绀侀悺銊╂晬閺囥垹鍐€闁瑰瓨绻傜换渚€鏌涢幒鏂垮幋闁稿鎳忕粙澶愬焵椤掑倹鏆滅憸搴㈡櫠閻樺灚鍋栨い鎰╁灪閸娿倝鏌熺€涙ê濮囬柛銈庡弮瀵爼濡烽婊咁槱婵犮垼鍩栭悧鐘诲磿鐎涙ê绶炵€广儱妫涙竟?`gemini-4-argon-thinking` 缂?1 闂佸搫顦Σ鍕?
            //   "闂?`NodeContainer` 闂佹眹鍔岀€氼垱淇婇銏″€烽柣鐔哄闊剟鎮跺☉鏍у姦婵☆偄娼″鐢告偄閸忕》绱垫繛鎴炴尭缁夌兘銆呴敃鍌氱闁靛鑵归崑鎾存媴鐟欏嫭姣?`height`/闂備焦褰冪粔瀵糕偓?`clip`闂?
            //    闂佸憡鐔粻鎴﹀垂椤栫偛鐭楁い鏍ㄧ箓閸樻挳鏌℃担瑙勭稇婵炲皷鍓濈粙澶婎吋閸涱厽顥濇繛鎴炴尭妤犳悂骞冩惔銊ョ?闂佹寧绋戦ˇ顐﹀闯?闁诲繒鍋涚换瀣箔閸岀偛鏋侀悗娑欙供閸炰粙鏌涢弬璇插闁轰線绠栭弻鍫ユ嚍閵壪€锔剧磼瀹€鍐╊仩婵炲牊鍨挎俊?
            //   闂?闂佺粯绮嶅妯猴耿?*闁汇埄鍨遍幃鍌炲煘?*闂佹寧绋掗惌顔惧垝閻樼偨浜滈柣銏犳啞濡椼劑鏌熺粙鍨偓钘壝归崶顒佺劷闁挎繂瀚閬嶆煕閹烘洦鍤欐慨妯稿妿閳ь剚绋掗敋婵犫偓椤忓牊鏅柛顐ｇ箚閸╁矂鏌涘▎鎯奉亞妲愰幋鐐村弿閻庯絺鏅濋娲煕閹惧磭鈻岀紒杈ㄥ哺閺佸秶浠﹂挊澶嬮敪闂?`src` 闂侀潻璐熼崝宀冦亹婢舵劕违?
            //     闂佸搫瀚扮粻鏍р枔?濠电儑绲洪埀顒€鍟垮鍐裁归悩鑼ら柛鏂炲洤鐭楁い蹇撴閺?`backgroundRevealOpacity()` 缂備胶濡抽幍鍐蹭壕?
            //   闂佸疇娉曟刊瀵哥箔?闂佺绻戠划宀€鑺遍幎鑺ュ剭?闂佸憡鐟﹂悧妤呮偋闁秵鍤?婵炴垶鎸哥粔鎾疮閳ь剟鏌￠崟闈涚仧缂佹柨顕禒锕傚磼濮橆剙绗ч悗娈垮枤閸犳洘淇婇銏″€烽柣褍鎽滅粈鍒濩olumn` 闂備焦褰冩總鏃傛偖鏉堛劎鈻?100% 闁诲孩绋堥弲娑㈡偤濞嗘劕顕辨慨妯块哺濡鏌涘顓炵仸閻㈩垱鎸搁锝夊焵椤掑嫭鏅鑸电〒缁€?
            //     闁诲海鎳撻崯鏉库枔閹达附鍤傜€光偓閸愵亞鍘悗瑙勭摃鐏忔瑧鍒掗敓鐘冲仺?*闁诲海鎳撻妵妯尖偓闈涚焸閹虫盯顢旈崟顓犵暢闂?`.backgroundColor`**闂佹寧绋戦悧鍛箔婢舵劖鐒婚煫鍥ㄦ⒐椤牠骞栫€涙ɑ绀€濡ょ姴娲弫宥嗗緞鐎ｎ亶妫￠梺鐟板槻閹冲矂鍩€?
            MeshCoverBg({
              src: this.meshSrc,
              srcVersion: this.meshSrcVersion,
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`seed: seedOfParts($$.title, $$.artist)`闂佹寧绋戦¨鈧紒?
              //   闂佸憡鐟﹂悧鏃傜箔婢舵劕绀嗛柡澶庢硶濞堥亶姊婚崼娑樼仾婵＄偛鍊荤槐鎺楀礋椤忓拋鍋ㄩ梺鍛婂姇閹虫劙寮妶鍡樹氦婵炲棗閰ｉ崵瀣磼婢跺﹦孝闁烩剝鐟╅弻鍛存偐閹绘帒绠查柟鐓庣摠濞叉粎绱炴径鎰唨缁绢參顥撶粈鍒瀎illFallback` 闂佹悶鍎茬粙鏍綖?HSL 濠电偞鎸婚崝鏇°亹婢舵劖鏅璺虹墐閸?
              seed: this.meshSeed(),
              playing: this.state.isPlay,
              active: this.state.isShowPlay,
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锕€鍌ㄩ柣鏂挎啞閻?*闂佹寧绋掗悺鐚爊tryFade: !pullMode || effT() >= 1`闂?
              //   `wujie.pa:192183-192320` 闂佹眹鍔岀€氼剟鎮块崟顖氱煑闁稿瞼鍋愰崑鎾诲箛椤掑倹鎲婚柣蹇撶箺妞寸危閸涘﹥浜ゆ繛鍡楅叄閸ゅ鎮跺☉鏍у闁规椿浜滈锝堢疀鐎Ｑ冧壕闁稿本绻嶉崵鏂库槈閺傛妾х紒?
              //     閻?婵炴垶鎸哥粔闈浳ｉ崨濠勨枖閻庯綆鍋勯娆撴⒑椤撱劎绋绘繛纰卞灦閺佸秹宕奸姀鐘卞寲闂佸憡鍨圭划顖涙櫠閿曗偓椤曪綁鍩€?/ 闂佺绻戞繛濠偽?/ 缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧梺鎸庣☉椤︻偊宕?**婵炴垶鎸哥粔鐢垫嫻娴兼潙绀?*闂佹寧绋戦悧蹇涙偟濞戙垹绀嗛悹鍥ㄥ絻鐠佹煡鎮峰▎搴ｇ瓘缂佽鲸宀搁弫?
              //     閻?婵炴垶鎸搁鍡樺垔濞差亝鐒介柨婵嗘閽傚鏌ㄥ☉娆掑鐟滄妸鍥у珘濠㈣泛锕ㄩ崺宀勬煕濞嗘劦鐒鹃柧鏂款儑閳ь剛鎳撻惌澶屾濡句骏ffT() >= 1`闂佹寧绋戦ˇ鐗堟櫠閻樺磭鈻旂€广儱鎳庨弲娆愮箾閿濆倵鍋撻崘鎻掓辈闂?
              entryFade: !this.expandState.pullMode || this.expandState.effT() >= 1,
              // 闂佺补鍋?2026-10-17闂?*闂備緡鍋€閸嬫捇鏌?0 = 闂佹眹鍨奸褏绮╂搴㈠磯闁绘梻鍎ょ徊濠氭倵閻熻埇浠掗悗闈涚灱閳ь剙婀遍崑鐐电矈鐎甸晲鐒婇柛婵嗗閸?* 闂佺偨鍎查弻锟犲焵?闂佹椿娼块崝宥夊春濞戞埃鍋撻崷顓炰沪缂佷焦鎸抽幆鍐礋椤愶絿顦ラ悷婊呭鐢亞妲?
              //   婵炴垶鎸搁敃锝囩博閹绢喗鍋嬮柛顐ｇ矌閻?`windowHeightVp` 闂佽鍨靛▍鏇熶繆閹间焦鍋ㄩ悹鍥皺椤忔挳姊洪挊澶樻Х缂傚秴娲弫宥夊醇閻斿墎鐟?闂佸憡锚椤戝棙鏅舵惔銊ョ劶闁圭儤鎸搁娆徝?闂佹寧绋戦¨鈧紒?
              //   缂傚倷鐒﹂幐濠氭倶婢舵劖鍋ㄩ柕濠忕畱閻撴洟鏌熼煬鎻掑姌闁?*闂佺粯鍔楅幊鎾诲吹椤曗偓楠炴﹢顢橀悢鍛婃緬闂佸憡鏌ｉ崝搴ㄥ极閻愵剚浜ら柛銉㈡杹閺屻倝寮堕埡鍋垫垵危缁嬪簱鏌﹂梽鍥磿濡ゅ懎鐤?*闂佹寧绋戦懟顖涙叏閳哄懏鍋ㄩ柤濮愬€楀▔銏ゆ煛婢跺苯鏋庨柟顔筋殜楠炲秴顓奸崱妯肩暢闂侀潧妫楃粙鍕?
              //   `fixedHVp > 0` 闂?`RenderNode.frame` **濠殿噯绲鹃弻銊╂偩閻樿绠ラ柍褜鍓熷畷鐑藉Ω瑜庨悾閬嶆⒑椤撱劎瀵奸梺鍙夌矒閹嫰骞掗幋鐘虫啢婵?*闂?
              //   闂佸吋婢橀懟顖炴嚋娴兼潙鐭楁俊顖滅帛閸╁倿姊洪銊у闂佸弶绮撻幆鍕箳閹寸姵鎲ら柣蹇撶箺妞寸危閸濄儲鍟戝ù锝囶焾椤ュ懐绱掗幇顓ф當鐟滅増鐩弫宥夊醇濠靛棙顓婚梺鍛娿仦缁ㄣ儵鏌涢幋鐘残ユ繛?vp闂佹寧绋戦ˇ顐﹀闯?闁烩剝甯掗幊搴ㄥ吹椤撱垺鍋夐柛鎾茬劍绾绢亪鏌ｉ妸銉ヮ伀缂侇噮鍨跺畷姘跺箚闁附钑夐梺杞扮劍濞兼瑥顭囬敓鐘茬闁哄啫鐗婇悵?
              //   闂?**閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮閻棗鈽夐弬璺ㄥⅵ闁稿繑蓱缁嬪顓奸崶銊︽瘞**闂佹寧绋掔粙鏍箚閵堝棙濯寸€广儱鎳忛崐闈涒槈閹惧崬鈧盯鍩€椤掆偓閹虫劕霉婢跺瞼椹?闂?闂佸憡鐟ラ悧濠囶敆濠婂懏鏆滈柟鑲╁亹閸?
              //   闂?闂佸憡鐟崹鐢革綖閸℃稑绠戠憸宀€妲愰銏犵闁割偒鍓涚粣妤€霉?0闂佹寧绋戦惌渚€顢欓埀顒勬煟閵忥綆鍤欑紒鏂垮槻椤繂顫㈠畝鈧粻鑲╃磼濞戞﹩妲风紒顭戝墰閳ь剛鎳撻妵妯尖偓闈涚焸閹嫰骞掗幋鐘虫啢闂? 婵炴垶鎸撮崑鎾绘煟閳哄喚妫庨柛蹇旓耿閹晫鎷犻幓鎺撶様闂佸搫顦崕鑽ゆ濮樿泛违?
              //   闂佸疇娉曟刊瀵哥箔?婵炲濯寸徊濂告偝椤栫偛鍙婃い鏍ㄤ亢閸╁矂鏌涘▎鎯挎垵锕㈤敍鍕＞闁瑰鍋熸竟鎰归崗鐓庡摵婵炲牄鍨婚幉妤佹媴缁嬫姊剧紓浣瑰姈椤ㄥ懓銇愬☉娆戔枖闁逞屽墰閹秆冪暋閺夎法顏?闂佺懓鍢查¨鈧紒杈ㄧ懇閹粙濡搁敃鈧悡鏇㈡煛閸愶絾娅呭褏濞€楠炲孩娼忛妸銏犱壕闁靛鍔庣粻鏍煟閵娿儱顏柛瀣嚇瀵爼鍩ラ崨顖滎槴闂?
              //     闁荤喐娲戠粈渚€骞冮幘璇茬睄闁兼悂娼ф慨顒勬偤?闂佹眹鍨奸褏娆㈤柆宥呯?+"婵炴垶鎸哥粔瀵告暜閸ヮ剙绠?闂佹寧绋戦懟顖滄闁秴绠查柕蹇曞Т閻掑ジ鏌ｉ妸銉ヮ仾婵犙€鍋撻梺鍛婂笩椤旀劗妲愬▎鎰懝閻庯綆浜跺ú銈夋煙鐠虹尨榫氶柛搴㈩殜瀵煡顢涘┃鐐╂櫊瀹曟岸骞忕仦鎯ь嚄闂佺粯顨呴悧鍛不閿濆棗绶為柡宥庡亝閺嗙姴顭块悷鏉挎毐闁活亝澹嗛幉妤佹媴缁嬫姊鹃梺鎸庣☉椤р偓缂?
              //     婵炴垶鎸哥粔鐑姐€呴敃鍌氱鐎广儱娲﹂弳?闂佹眹鍨奸褏绮╁畡闈舵帡寮崒娑氾紛闁诲孩绋掗崝鏇㈠Φ?闁哄鏅滈悷褔锝為幒妤€绀冩繛鍡樺姉閵嗗﹪鏌?
              fixedHVp: 0
              // ⛔ 2026-10-17：`fallbackColor`（取样色定兜底色相）**已删除** —— 上游没有这一路，
              //   兜底色相恒为 `hueOfSeed(seed)`（见 `MeshCoverBg.makeFallback()` 的注释）。
            })
              .id(PlaybackPage.MESH_BG_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .opacity(this.backgroundRevealOpacity())
              .hitTestBehavior(HitTestMode.None)
              .onAreaChange((): void => {
                this.logBgLayer();
                this.logBgPhase();
              })
          }
          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佺厧鍟块張顒€鈻嶅▎鎴斿亾閻熻埇浠掗悗闈涙湰缁嬪鍩€椤掆偓椤?100%闂?闂佹悶鍎遍幖顐︽偩閸撗傜剨闁告繂瀚烽崵?闂佸憡鐟禍鐐靛垝閹殿喚纾鹃柟瀵稿仧婢规劙鏌ｉ姀锝庡殭缂佹梻鍏橀弫宥囦沪閼测晝鎲圭紓鍌欑劍閻熴儳绮╂搴濇勃闁?*闂?
          //
          // ## 婵炴垶鎸搁敃锝囩博閹绢喗鍋嬮柛顐犲劜閺呪晠鏌涢敂鍝勫闁瑰鍨介弫宥夊醇閵忊剝娈㈤梺瑙勬綑閸㈡煡鎮块崟顐€鍦偓锝呭缁?*闂佺厧鍟块張顒€鈻嶅▎鎴斿亾閻熸媽瀚伴柛娆忕箲缁嬪顓奸崼顐ｇ秳婵?*闂佹寧绋戦惌鍌氼焽閵堝拋娼伴柕蹇婃閸嬫挻鎷呮搴ｆ濠电偛澶囬崜婵嗭耿娓氣偓閺?
          //   婵炴垶鎸搁敃锝囩博閹绢喗鍋嬮柛顐ゅ枎鎯?*闁诲海鎳撻妵妯尖偓?*闂佹眹鍔岀€氫即鎮甸鑺ュ劅闁挎棁娉曢惌?`'100%'` 闂佽　鍋撻悷娆忓閻忓洭鏌涢妷銉︽儓闁?`windowHeightVp`闂侀潧妫楅崐鎼侇敊閺嶃劎鈻旂紓浣股戠瑧
          //   `.position({x:0,y:0})` 闂佹眹鍔岀€氼喚鍒掓搴樺亾閻㈠灚鍤€闁伙絿鍋撻幏鍛吋閸涱垱鎲ら梺鐓庢惈閸婂宕戦敐澶嬫櫖鐎光偓閸愶絽浜剧€光偓閳ь剟宕哄Δ鍐ｅ亾閸︻厽鍤€婵炲懏甯楅〃?= `morphClipHeight()`闂?
          //   婵炴垶鎸撮崑鎾斥槈閹垮啩绨奸柣锔诲枤閹叉鎷呯粙娆炬⒕缂備焦鍔栭〃鍛般亹濞戞瑥绶炵憸蹇撯枔閹达箑鐐婇柛婵嗗閺嗕即鎮樿箛鎾存儓妞ゆ洦鍙冮幆鍕箳閹寸姵鎲ら梺鍛婄懃閸婇绮畝鍕亯闁告挷绀侀濠囨煛?闁荤喍妞掔粈浣圭珶閳ь剟姊洪悙顒€鍔ら柟顔筋殜閺佸秶浠﹂悙顒侇啋闁诲繒鍋涢崐绋款潩?*婵炴垶鎸哥粔鎾疮閳ь剟鎮跺鐓庝簽缂侇噮鍨跺畷?*
          //   闂佹寧绋戝﹢妾坢ini-4-Argon 婵犮垼娉涚粔鐢告偋閹惰棄瑙︾€光偓閳ь剛鍒掗妸褎濯奸柣姘嚟缁愭〗tack 闁诲孩绋掗崝妯讳繆椤撱垺鍊风痪顓炴噽瀛濋梺鍛婂灴缂傛岸锝?`.clip(true)` 闂佹眹鍔岀€氼噣宕哄Δ鍛剮闁圭儤鎸婚ˇ褔鏌?
          //   濠电偞鎸稿鍫曟偂鐎ｎ剛涓嶉柨娑樺濞堢姴霉閸忚偐顣查柡鍡秮瀹曠螖閳ь剚鏅惰濮婁粙濡惰箛鏇炶€块柣鐔哥懕缁犳垼銇愰崒娑欎氦闁搞儻濡囬杈ㄧ箾閸″繆鍋撻懠顒夊悈闂?*闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夘棑閻﹀秴鈽夐幘宕囆＄紒鍙樺嵆閹虫盯顢旈崟顓犵暢闂佹悶鍎抽崑鐐差焽?*闂佹寧绋戦ˇ顓㈠焵?
          //   闂佺补鍋?**婵炴垶鎸哥粔鐑姐€?*闂佸憡鍔曠粔鍨繆閸濄儮鍋撻悷鑸粧閻庨潧鐭傞幆鍐礋椤愶絾顫呴柣搴ㄦ涧閹测€崇暦閺屻儱绠ｉ柟閭﹀墯缁佸ジ鎮楃憴鍕暡闁?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐ゆ崲閳ь剙顪冮妶鍫濆惞闁轰線浜堕幃銉╁礈娓氣偓閻?100% 闂佸湱鍋撻崹鐢垫閹达箑违?
          //
          // ## 闂佹椿浜為崰鎰邦敆濠婂懏鍟哄ù锝夋敱閸欏繘鏌ｉ妸銉ヮ仾婵?缂傚倸鍟崹鍫曟偋缁嬪晝鎺曠疀閺冩垵浠归梻浣瑰絻缁夌數鏁?闂? 闂佸憡锚椤戝棙鏅舵惔銊ョ劶闁圭儤鎸搁娆徝规總鍛婁氦缂佽鲸宀搁弫宥呯暆閸曨偂绨兼繛瀵稿У濠€鍦姳閵娾晛鐭楅柟瀵稿У閺呮悂鏌?*闂佹眹鍨奸褏绮?*婵?
          //   `NodeContainer.onAreaChange 闂?controller.resize(w,h) 闂?field.update(w,h)`
          //   闂?闁荤姴顑勯懗璺衡枔閹达附鍎庨柟鐑樺灩閹藉秹鏌涢敂鍝勫鐟滄澘顦甸弫宥呯暆閳ь剛绱炴径鎰唨闁绘挸瀛╅惃鎴︽煙缁嬫妲奸柣銊︾箞閹啴宕熼鍌浶ユ繛鎾磋壘椤戝宕崇粙娆惧殘婵炲樊浜楅埀顒€锕幃娆撴偡閹峰苯鐝梻浣瑰絻缁夊綊宕虫导鏉戝唨闁哄鍋€閸?
          //   闂佸疇娉曟刊瀵哥箔?**2026-10-17 闂佺粯绮嶆竟鍡樻叏閹间焦鏅慨婵囩摬ixedHVp` 閻庣懓鎲￠悡锟犲焵椤戣棄浜鹃梺?0**闂佹寧绋戦悧蹇涘极閸撗勬殰闁告劦鍘鹃鈧梺娲诲亐閸嬫捇鎮楅悷鑸粧閻庨潧鐭傞幆鍕箳閹寸姵鎲ら梺鎸庣☉椤︻參鍩€?
          //     闂佸搫娲﹀畷姗€鎯侀娑欎氦闁搞儯鍔屾儫闁诲海鎳撻崯鎾箯閵堝绠?`windowHeightVp` 濠?闂佸憡锚椤戝棙鏅?闂佹寧绋戞總鏃傚緤?*闂佹眹鍨奸褏绮╁畡闈舵帡寮崒娑氾紛闁诲孩绋掗崝鏇㈠Φ?闂?闂佽桨鐒﹀娆忣焽閿熺姴绀堥柡鍐ㄧ墛閻?*
          //     闂?閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮閻棗鈽夐弬璺ㄥⅵ闁稿繑蓱缁嬪顓奸崶銊︽瘞闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎庨悶姘船閳诲酣鍩ラ崨顖滎槴闂侀潧妫楅崐姝屻亹閼碱剚鍠嗗ù锝呭帨閸嬫捁顦辩紒槌栧弮瀹曟宕奸鍌滎槷闂佸憡锚椤戝棙鏅舵惔銊︾劷闁挎繂妫欓拏瀣煕韫囨挾澧㈤柡鍡忓亾闂佹椿鍋€閸嬫捇鏌?
          //     闁荤喐娲戠粈渚€骞冮幘璇茬睄闁兼悂娼ф慨顒勬偤閹烘棏鍔滅紒杈ㄧ箓椤曘儱螖娴ｈ倽鈺呮煠閸愬弶婀版繛?*缂備礁顦抽褔宕甸掳浜归柕蹇曞Т缂嶄線鎮楅崷顓熷殌婵?*闂佹寧绋戦悧鍡浰囨繝姘劸闁靛鍎哄Σ濠氭煛瀹ュ浂鐒剧紓鍌涙尵閹峰顢欓悙顒傛殸闂佸搫鍊介～澶愩€?A闂佹寧绋掓穱娲磿濡ゅ懎鐤炬い鏍ㄦ皑濠€鏉戔槈閹炬娊顎楁い鏃€鍔欏畷鎶藉Ω閵夛箑鈧京绱掗悪娆庤閸?
          //     闂佺厧顨庢禍婊呮崲娓氣偓閹?`clip` + `scale/translate` 闁荤姾娅ｉ崰鏍р枔閵忋倖鏅鑸电〒缁€澶娾槈閹惧磭校婵℃彃鎽滈幏顐﹀礃閵婏附顫呴柣搴＄仛閻℃洟宕楀Ο鍏煎枂闁挎繂鎳庨弸鈧梺姹囧妼鐎氥劑鍩€?
          .width(StyleConstants.FULL_WIDTH)
          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～澶愭煃?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔芥櫖婵﹩鍓﹂崯蹇撯槈閹剧懓鍚规繛鍫熷灩娴滄悂宕崟闈涙闂佸搫瀚烽崹顖滅博鐎涙鈻旀い蹇撳缁佸ジ鎮楃憴鍕暡闁?`winHVp`闂佹寧绋戞總鏃傜箔閺嶎厼鍙婃い鏍ㄧ〒閵堬妇鈧鍠栫换鎰版偤濞嗘挻鍤嶉柛灞剧矊娴?*闂?
          //
          // 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亽閸熷洭鏌涢敐鍐ㄥ闁绘牗鐓￠弫宥夊锤閸撳jie.pa:191756`闂佹寧绋戦惌鍌炲焵椤掍礁濮屾い銏″灴瀵棄顫㈠畝鈧粻鏍煥濞戞﹩妾х紒?
          // ```
          //   Stack(TopStart) .scale .translate .width('100%') .height(clipHeight) .clip(true)
          //     闂佸疇顫夐弻锟犲绩?Column  闁?100% + **height(winHVp 闂佹悶鍎遍幖顐︽偩妤ｅ啫鏋?** + padTop/padBottom     闂?濠电偟绻濈粈浣烘閿涘嫧鍋撳☉鎺撴珔闁烩剝鐟╅弫宥囦沪閻愵剨楠?.position
          //          闂佸疇顫夋竟鏇㈠绩?playerPane
          //          闂佸疇顫夐弻锟犲绩?MeshCoverBg
          // ```
          // 闂?婵炴垶鎸堕崐鎾绘煂濠婂懏鍟哄ù锝呮惈娴狀垶鏌ㄥ☉妯煎闁搞劍绮嶇粋鎺楊敄鐠侯煈鍚呴梺鍛婃尭缁夊磭鎮柆宥呯骇闁跨喓濮撮崢鎾⒑閹稿海鎳曠紒杈ㄥ哺閺?
          //   闂?**闂佺厧鍟块張顒€鈻嶅▎鎴斿亾閻熻埇浠掗悗闈涚焸閹啴宕熼婊冭拫闁硅壈鎻梽鍕ｉ幖浣哥倞闁告繂瀚弳鎵磼閹邦収娈旂憸鐗堢⊕椤?*闂佹寧绋戞總鏃傜箔婢跺本宕?`clipHeight` 闁?闂?`NodeContainer` 闂?
          //      `onAreaChange` **闂佸憡鐟禍锝堫杺闂佸憡鐟﹂崹宕囩博閺夋垟鏋?*闂佹寧绋戦悾鐠昬nderNode.frame` 闁诲繐绻愰幖顐︻敋?*闂佽鍘界敮鎺楁偩?* 闂?闂佺厧顨庢禍鐐靛垝椤栫偛绀冮柛娑卞弾閸熷洤鈽夐幘宕囆＄紒?
          //      濠殿噯绲界换鎰板箮濮樿鲸鍋栨い鎰剁畱濞呫垻鈧?婵犮垺鍎兼ご鎼佸疾閵夆晛违闁稿本绋戦悘澶娒归悪鈧崜娆戞暜椤愶箑绾ч柕澶堝劚閺?`'100%'` = 闁荤姾娅ｉ崰鎾愁焽閸愵亝鍟戝ù锝囶焾椤ュ懐绱掗幇顓ф當鐟滅増绋戣闊洦鎸绘慨搴ㄦ煕?闂?濠殿噯绲界换鎰板箮?`resize()`
          //      闂?缂傚倸鍟崹鍫曟偋缁嬪晝鎺曠疀閹炬潙顫撻梻浣瑰絻缁夌敻寮绘繝鍥ㄧ厒闁搞儯鍔庢竟?闂備焦褰冪粔瀵哥磽閹剧粯鏅悘鐐测偓鐔风厒闂佸憡鐟﹁摫婵犫偓閿熺姷宓侀柤鑹版硾婢у嘲霉閻橆偄浜炬繛鎴炴煥閻楁捇宕楀Ο鑽も枖鐎广儱鎳庨埛?闂?闂佹椿娼块崝宥夊春濞戙垺鍎戦悗锝庝簻閻撳倿鏌?闂佺绻堥崝搴ㄥ煝閸忕⒈娓?闂?
          //   闂?闁诲海鎳撻崯顖毼?*濠电偟绻濈粈浣烘閿涘嫧鍋撳☉娆忓濠碘槅鍙冮幃?*闂佹寧绋戦悧濠囨儉閸涙潙瀚?`.position`闂佹寧绋戦¨鈧紒杈ㄧ箞濡啴鎮╅棃娑氬幀 `Stack(TopStart)` 闁荤姵鍔栧娆愮▕韫囨梻鈻斿┑鐘叉媼濞硷繝鏌?
          //      闂佺懓鐡ㄩ崹鍐差煥閹达箑鍌ㄩ柣鏂挎啞闂勫秹鏌?`.position(0,0)` 闂佹眹鍔岀€氼喚鍒掓搴樺亾閻㈠灚鍤€闁伙絿鍋撻幏?闂?闂備焦婢樼粔鎾箖?闁烩剝甯掗幊搴ㄥ吹椤撶姵鍋?clip 闂佹眹鍔岀€氼噣宕哄Δ鍛剮?婵炴潙鍚嬫穱娲綖閿曞倸鏋侀柡澶嬪灦閸嬨儵鏌涢幘瀛橆棃婵?
          //      闂佹寧绋戦悡?59 闂備緡鍙忕徊楣冾敃?闂佺厧鍟块張顒€鈻嶅▎鎴斿亾閻熸媽瀚伴柛娆忕箲缁嬪顓奸崼顐ｇ秳"闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棙鍔栭拏瀣煥濞戞﹩妲堕柍?
          //   闂佸疇娉曟刊瀵哥箔?闂傚倸鐗婇悷锕傤敆濞戙垹绠戝〒姘功缁愭鎮楅崷顓熷殌婵炲懏甯楅〃?= 缂備焦鍔栭〃鍛般亹濞戞瑯娈?闂?闂佹悶鍎遍幖顐︽偩閻愵剦娈楁俊顖氭贡閻?`'100%'` **闁诲海鎳撻懟顖炲矗韫囨洜椹冲璺侯槺楠?* 闂?闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯夸含閻熸繈鏌涘▎鎯芥粓鍩€?
          // ═══════════ 背景宿主 vs 上游 `padTop()/padBottom()`：**故意不加 padding**（回原文核过） ═══════════
          //
          // 用户给的线索是"上游 `wujie.pa:191756-191800` 的背景宿主 = Column().width(winWVp)
          // .height(winHVp).padding({top: padTop(), bottom: padBottom()})"。**直读字节码后可以确认：
          // 那个带 padding 的列不是网格的宿主，而是【正文列】；网格是它的兄弟。**
          //
          // ```
          //   191756  .function @36***#^5                       ← 正文列（playerPane 的父）
          //   191761-191771  Column().width(this.winWVp())
          //   191772-191782  .height(this.winHVp())
          //   191783-191800  .padding({ top: this.padTop(), bottom: this.padBottom() })
          //   191801-191822  .opacity(this.pullMode ? this.pullChromeOpacity() : this.expand.contentOpacity)
          // ```
          // 而网格（MeshCoverBg）挂在哪：**同一个 λ 体内的另一个 `If` 分支**，且在正文列之前
          // ```
          //   190941   .function @36**#                          ← 缩放/裁剪那个 Stack 的 builder 体
          //   190966-190971  observeComponentCreation2(If, λ@36***#^2)      ← 背景这支 If
          //   190972-190975  If.pop()                                       ← 先关掉
          //   190980-191003  If(@36***#^3) motion 层 / If(@36***#^4) 快照层
          //   191008-191012  observeComponentCreation2(Column, λ@36***#^5)  ← 才创建正文列
          // ```
          //   ⇒ `If.pop()` 发生在 Column 创建**之前** ⇒ 网格与正文列是**兄弟**，网格铺满
          //     `Stack` 的 `clipHeight`（`.clip(true)` 在 `191462-191469`），**不吃 padding**。
          //     `λ@36***#^2` 体内（`:192088-192114`）就是 `__Common__(){ MeshCoverBg() }`，
          //     它的 `.opacity(pullMode ? pullBgOpacity() : expand.contentOpacity)` 在 `:192150-192178`。
          //
          // ⇒ 所以本仓这一层**保持无 padding**：本仓的 `MeshCoverBg`（`.width('100%').height('100%')`）
          //   是**当前 Column 的子节点**，加 padding 会把网格压成"去掉上下各一段"的中间一块，
          //   上下露出本节点的 `defaultImageBgColor` —— 正是判据里不许出现的"新露出的底色"。
          //   上游之所以看起来"网格只铺中间那块"是错觉：网格铺的是整块 Stack，上下被 `clipHeight` 裁，
          //   裁掉那部分由 Stack 自己的底色兜。
          // ⇒ `PlayerExpandState.bgHostPadTopVp()/bgHostPadBottomVp()`（= 上游 padTop/padBottom 同式）
          //   只接进诊断日志 `RzdBgLayer ... bgPad=T/B`，等真机量出"内容让位够不够"再决定要不要动结构。
          //
          // 判据（真机）：① 静止态封面上方/下方**不出现新露出的底色**；② 形变期背景仍随卡片裁剪。
          .height(this.expandState.windowHeightVp)
          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*婵炴垶鎸哥粔褰掑焵椤掆偓缁绘垵危閹寸偞鍎熼柡鍥╁仱閻?* 闂佺偨鍎查弻锟犲焵?缂傚倸鍟崹鍫曟偋閸涘﹦鈻旈柛銉椤忚鲸绻涘畝瀣？闁轰線绠栧畷娆撴倻濡妾烽梺鎸庣☉婵傛梻寮ч崘鈺冣枖鐎广儱瀚粣妤呮⒒閸ャ劌绲婚柛銈庡幗閿涘啴寮介婧惧亾?闁哄鏅炲〒鍦礊濮椻偓瀵爼鍩ラ崨顖滎槴
          //   闂?`defaultImageBgColor`闂佹寧绋戝濉篻ba(32,32,32,1)`闂佹寧绋戦張顒€锕㈤悧鍫涗簻闂傚牊绋戦弬褔鏌￠崼婵愭Ш婵?闁哄鏅滆摫闁汇儱鎳樺鍨緞婵犲倻鎮奸梺鑲╂嚀瀵泛顪冮崒鐐村剭闁告洦鍋嗘穱娲煠?闂佹寧绋戦ˇ顓㈠焵?
          //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸哥粔鐑藉礂濮椻偓瀹曟繈鎮╅崘鑼海"缂備焦顨忛崗娑氳姳閳哄倻鈻旀い蹇撳閹藉秹鏌ら崫鍕偓濠氬磻?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻妵妯尖偓闈涚焸瀵即顢涘鐓庢櫍闂侀潻缍嗛悡澶屾濠靛洨鈻旈柕鍫濆閸?100% 闁诲孩绋堥弲娑㈡偤濞嗘劕顕辨慨妯块哺濡鏌涘顓炵仸閻㈩垱鎸搁锝夊焵椤掑嫬违?
          // ★★★ 2026-10-18（照搬无界「背景宿主没有底色」——用户「点击展开动画过程背景还是有问题，没搬全」）
          //   上游背景宿主那一层**没有任何 `backgroundColor`**（见 `_recover/logic-src/full/差异表-背景.md` P1；
          //   `PlayerPage完整UI定稿.md` 里那个带深色底的 Column 是 `motionLayer`，不是背景宿主 —— 旧注释记错了）。
          //   原来这里是不透明的 `defaultImageBgColor`（`rgba(32,32,32,1)`），而形变早期 `MeshCoverBg`
          //   自己的 opacity 只有 `pullBgOpacity() = 0.04 + pullBgIn×0.96`（`wujie.pa:176560-176579`）
          //   ⇒ 屏上 96% 露出来的是**这块深灰卡片**；上游露出来的是**透明底（能看到下面的首页/迷你条）**。
          //   这是"点击展开过程中背景观感与无界不一样"最直接的一条。
          //   ⚠️ 静止态不受影响：那时 `backgroundRevealOpacity() === 1`，网格本身是不透明的。
          .backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.None)
          // 闂佺补鍋?2026-10-17闂?*婵炴垶鎸哥粔宕囩不婵犳艾鐭楃€广儱娲ㄧ槐姘舵煛閳?* 闂佺偨鍎查弻锟犲焵?婵炴挻纰嶇换鍐ㄧ暤娓氣偓瀵即顢涘鍕闂佽鎸抽ˉ鎾跺垝娴煎瓨鍎嶉柛鏇ㄥ墯閿熴儵鏌ｉ敐鍛殭闁煎灚鍨甸埢鎾诲垂椤愩垻鍔甸梺鎼炲劜閹锋繄妲?
          //   闂佸搫鍟版慨鐑藉疾椤愶絿鈻旀い鎾跺櫏閸炰粙鏌熼幖顓濈盎婵炲瓨锕㈠浼村礈瑜嬫禒娑㈡煥?*缂傚倸鍟崹鍫曟偋閹间礁鍙婃い鏍仦閹虫瑦绻濇繛鎯у⒉闁哄棴绲介锝夋偐閹绘帒鑰块梺缁橆殔濞层劌鈻?*闂佹寧绋戦悧濠囨偋閸濄儮鍋撳☉娆忓婵炲牄鍨藉畷锟犳晬閸曨偒鏆繛鎴炴尨閸嬫捇鎮硅閺屽锝為敃鍌氬偍?闁诲繒鍋炲ú鏍閹达附鏅?
          //   闂?闂佺厧鍟块張顒€鈻嶅▎鎴炲磯闁绘梻鍎ょ徊濠氭倵閸︻厽鍤€婵炲懏甯炵槐鎾诲煛閸屾稒婢掗梺鍝勭墱閸撴繈妫呴埡鍛強妞ゆ牗鍑归崵鐘绘煟閵娿儱顏电紒杈ㄧ箞瀹曪絽顓奸崶鈺冪闂佽　鍋撻柛娆嶅劤缁愭鎮规担鍙夋珔闁活偄妫欑粙澶嬬節閸屾碍閿梺鍛婃尨閺呮瑧绮╅弶鎴殨闁绘ê鍟挎慨顒勬倶韫囨挻鎯堟い鏇ㄥ幘缁辨棃骞嬮悙闈涱棔闂?*婵炴垶鎸撮崑鎾绘煕瑜庨〃鍛村垂韫囨稒鍋?*闂?
          //   闂佹寧绋戦悧鍡楊啅婵犳艾鐭楅柡灞诲劚娴滄繂鈽夐幘鍗炩偓娑氱矙濞戙垹鐭楃€广儱娲ㄧ槐姘舵煛閳ь剚銈ｉ崘銊ュ箣閻庡湱顭堝鍫曞箰濞嗘挸鐐婇柣鎴濇川缁€濉gInverseScale()` 婵炴垶姊婚崰搴ㄥ礄閿熺姴绀嗛柣妯肩帛閻濈喖鏌曢崱妤€浜扮紒?
          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺厧鍟块張顒€鈻嶅▎鎴滄勃闁稿本绻傚▓浼存偣?* 闂佺偨鍎查弻锟犲焵?闁?`diagBgBox` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煥?
          //   闂備焦褰冪换鎺戔枔閹达箑鍙?*闂佸搫鐗滈崜娆撴儑娴煎瓨鏅柛顐到閸撳綊鏌￠崪浣哥仩妞ゆ梹鐗楃粙澶嬪濞嗘垹顦?*闂佹眹鍔岀€氼剛绮╂搴濇勃闁逞屽墴閹矂鍩℃担钘夌厒闂侀潧妫楅崐濠氬极閵堝绠ｉ梺鍨儏琚?闂佸搫鐗嗛ˇ鎶藉磿濡ゅ懎鐤炬い鏍ㄧ懅缁嬭螖閸屾耽顏嗏偓瑙勫▕閹囨焻濞戞氨校"闂佸搫鍟抽鎰?
          //     閻?`bgH` 閻庡灚婢橀悧鍡涙儍椤掑嫭鍤€?`clipH` 婵炴垶姊婚崰搴ㄦ儍?闂?濠殿喗绻愮徊浠嬫偉閸洘鏅柛顐ｇ箓琚熼梺姹囧灱椤斿﹪鎳欓幋婵冩灁缁炬澘顦辩粈澶愭倵閸︻厽鍤€婵炲懏甯炴禍鎼佸础閻愬弶閿梺鍝勭墕椤︾敻宕戦崨顔锯枙闁割偅绺挎禍锝夋煥?
          //     閻?`bgH` 閻庡灚婢橀悧鍡涙儍椤掑嫭鍤€?`clipH` 婵炴垶鎸哥粔鎾儍?闂?**闂佽皫鍕姢闁搞劌楠歌闁哄啫鐗婇幊鐘绘煛閸屻倕骞掔紒?*闂佹寧绋戦悧鎰板磿濡ゅ懎鐤炬い鏍ㄧ〒濮婇箖姊洪崜褍鍔嬬€殿啫鍛亾閸︻厽鍤€婵炲懏甯￠弫?
          //     閻?`bgH` 濠殿喗绻愮徊浠嬫偉?闂?闂傚倸鍋嗛崳锝夈€傛禒瀣嵍?*婵炴垶鎸哥粔褰掑焵椤掆偓缁绘垵危閹寸偞鍎?*闂佹寧绋戦悧蹇擄耿?`bg`闂佹寧绋戦ˇ浼村垂?*缂傚倷鐒﹂敋闁?*闂佹寧绋戦悧鍛箔婢舵劕鍙婃い鏍ㄦ皑椤忔挳鎮橀悙鈺佷壕闂?
          .onAreaChange((_oldArea: Area, area: Area): void => {
            const w: number = areaLengthToVp(area.width);
            const h: number = areaLengthToVp(area.height);
            this.diagBgBox = `${w.toFixed(0)}x${h.toFixed(0)}`;
          })

          // 闂?闂佸憡鍔曢幊搴敊閹邦喕娌柛宀嬪缁愭鎮樿箛鎾存儓妞ゆ洦鍙冮獮渚€骞掑鍫㈩槹 100%闂? 闁荤喍妞掔粈浣圭珶閳ь剛绱掗幇顓ф當鐟?= 闂佸憡鐟崹鐢革綖鐎ｎ喗鍎楅柍杞版祰閸?/ 缂傚倸鍊甸弲婊堝棘娓氣偓閺佸秵寰勫☉姘鳖槷闂佸湱顣介崑鎾趁归悩顔煎姕婵℃鐗婂璇差煥閸愯法绋忓┑鐘才堥埀顒€鍟跨拋鏌ユ偡濞嗗繑顥犻柣鎾櫈閵?
          Column() {
            Column() {
              this.buildControlStack()
            }
            // 闂?闂佸ジ顣﹀ù鍥儗閹屽殫闁告洖澧庣粈鍕煕閹寸姴小缂傚秴绉撮埢浠嬫晸閻樺弶顏￠梺鍛婂笧婢ф顪冮崒鐐村剭闁告洦鍋勯獮鎴﹀箹鐎涙ɑ绌跨紒杈ㄥ哺閺佸秴顫濋鈧弫鍫曟倵閸︻厽鍤€闁活亝澹嗛幏鍦偓闈涙啞缁插骞栫€涙ɑ绀夌紒鏃傚枛閺佸秴鐣濋崟顓炶拫闁硅壈鎻紓姘卞垝?闁荤姵鍔栧娆戣姳閾忣偆鈻旈柍褜鍓熷?闂傚倵鍋撻柛顭戝枛閻?100%
            .height(this.sheetHeightPercent())
          }
          .width(StyleConstants.FULL_WIDTH)
          // ★★★ 2026-10-18：**固定整窗高**（上游 `wujie.pa:191772-191782` 的
          //   `Column().width(winWVp).height(winHVp)`）—— 原来是 `FULL_HEIGHT`（= '100%'），
          //   高度跟着**裁剪窗** `morphClipHeight()` 走 ⇒ 底栏永远贴裁剪窗底边 ⇒ 裁剪门失效。
          //   详见 `morphContentHeight()` 的说明。
          .height(this.morphContentHeight())
          .justifyContent(FlexAlign.End)
          .clip(true)
          // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯?*婵炴垶鎸哥粔鎾疮閳?*缂傚倷鐒﹂悷锕傚汲閿濆洣娌柛灞捐壘椤綁姊洪銏㈢婵″弶鍨堕幆?闁圭厧鐡ㄥú婵囩珶婵犲洦鏅慨妯虹亪閸嬫捁绠涢弮鈧～鏍箹鏉堝墽鐣遍柛鎴節楠炴劖寰勬繝鍌氬敤缂傚倸鍊归悧鐐烘儊瑜旈獮蹇涘幢濡櫣浜ｆ繛鎴炴尭椤︻垶鎯囬幍顔剧幓婵°倐鍋撶憸?
          //   闂佹寧绋戦悧鎰板磿濡ゅ懎鐤?`pullBgIn` / 婵＄偑鍊涢崺鏍偉?`pullChromeOpacity` / 闁圭厧鐡ㄥú姗€鎮?`pullBottomIn`闂佹寧绋戦¨鈧紒?
          //   闁圭厧鐡ㄥú婵囩珶婵犲洦鍋ㄩ柛妤冨仩閸╁矂鏌涘▎鎯奉亪顢欓幇鏉块棷闁靛ň鏅涘▍锟犳⒑椤撱劎瀵奸梺鍙夌矒瀹曪綁寮介鈧ˉ蹇涙倶閻愭彃鈧晫绮堢€ｎ剚瀚婚柨婵嗙箳缁€澶愭煕濮樺墽鐣遍柛顭戝灦濡啫鈻庨幇闈涘闂佽鍏涘鎺旀閹殿喕鐒婇柟瀛樼矌椤忛亶鎮橀悙鎻掆偓鍧椔锋笟鈧幊婵堜沪閸屾浜?
          // 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃銉﹀垔濞差亜绠ラ柟鎯х－绾?*婵炴垶鎸哥粔鏉戯耿椤忓懏浜ゆ繛鍡樻尭濞咃繝鏌?*闂佹寧绋掗懝楣冩偩閻樿櫣鐤€闁告稒鐣埀顒€绻橀獮鎰板磼濮橆叀鍚繝銏㈡嚀閸熷潡鎯囨导瀛樻櫖闁秆屾辜oducts闂佹寧绋戦ˇ顓㈠焵?
          //    闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺⊕闊?`isShowPlay=false` 闂佸搫鍟崕鑲╂崲閺囩偐鏌﹂柍鈺佸暙閻︻垶寮堕悙瀛樼伄缂佽鲸绻冮妵鍕偨閸涘﹥銆冮梺琛″亾闁哄牏鏁搁悷婵嬫煕閹烘柨顣煎褎绮撻獮鎰板炊閿斿墽娈ゆ繛瀵稿Ь缂堜即鍩€?
          //    闂佺厧宕惌渚€鎯屽Δ鍛闁圭儤鍨甸悗濠氭煥?*婵炴垶鎸搁敃銉﹀垔?婵犮垻鎳撻崯鍧楁儑?闁哄鏅炲〒鍦礊濮椻偓瀵爼鍩ラ崨顖滎槱闂?morphP 0闂?闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪鈧綆鍋勯娆撴煛閳ь剟骞嗛悧鍫濋棷=闂佸搫鐗滈崜鐔煎Υ婢舵劖鏅柛顐ｈ壘閺?morphP 1闂?闂?*闂?
          //
          // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯?*婵炲濮崑鎾斥槈閺傝法澧﹂柛蹇斏戠粙澶婎吋閸曨厾鎲梺?*闂佹寧绋戦悧濠偽涢敂鐣屸枖鐎广儱瀚悷鎰版煙闊彃鍔氶柡鍕€婚埀顒傛暬濞艰崵妲愬┑鍥┾枙闁绘柨澧庨悷婵嬫煕閹邦剛小缂佹鍊块獮搴ㄥΨ閵夈儲鏋鹃梺缁樺姉濞呫垻妲愬璺何?
          //    闂佸搫鐗滈崜娆撴儑閹殿喕鐒婇弶鍫涘妽绗戦梺褰掓涧椤戝棗鈹冮埀顒€銆掑鈧崨顔炬殸 `MORPH_HOST_ID`闂佹寧绋戦惌渚€鍩€椤掆偓閼活垶鎮鹃悩缁樺剭闁告洦鍨宠ぐ顖炲箹鏉堥箖妾俊?*闁荤喍妞掔粈浣圭珶閳ь剛绱掗幇顓ф當鐟滅増绋掗〃鍥熼崫鍕靛敽**
          //    闂佹寧绋戦悧鍡涙嚋娴兼潙鐭楁俊顖滅帛閸╁倿姊?~60vp 闂?濠电姴艌閳ь剙纾宀勬煥濞戞﹩妾х紒杈ㄧ串globalPosition` 婵炴垶姊婚崰鏇犵玻閿熺姵鍎撻柍?translate 闁?闂佺偨鍎查弻锟犲焵?
          //    闂佺懓鍢查悘婵嬫偩閻樻亽浜?闂備礁澧介崕銈咁嚕瑜旈幆鍕敊閻ｅ苯鐏?闁诲繐绻楁ご绋课ｉ崫銉х當妞ゆ垼娉曠€瑰绻涢崰掳鍊曞▓浼存煕閿濆骸澧剧紒杈ㄧ懄缁嬪鍩€椤掑嫬閿ゆ俊銈呮噽閹枫劑骞?+ 闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺〒濞兼柨鈽夐幘宕囆㈢紒杈ㄥ灴閺佸秵寰勫☉姘鳖槷
          //    闂佺懓鍢查悘婵嬫偩閻樻亽浜?闂佺鍕闁绘牭缍佸畷銏ゆ偄閸濆嫪鍖?闁诲繐绻楁ご绋课ｉ崫銉﹀闁宠桨绀侀弬褔鏌ｉ幇顕呮敯闁归鍏橀幆鍫ュ焵椤掑嫭鍤婃い蹇撳缁犳帡鏌ｉ妸銉ヮ仹闁煎灚鍨垮鑽も偓娑櫱氶崑鎾存媴閻ｅ瞼宕滈梺鎸庣☉閻楁劙骞戦敐澶嬪€?闂佺绻愰澶娾枔閺囩姳娌柛灞剧⊕濞堣霉閿濆棙宕岄柡浣革攻閹峰懎顓艰箛鏇狀槴闂?
          //    **闂佺鍕闁绘牭缍佸畷锝夋晲閸涱垳鐛梺绋跨箞閸旀垿骞楅懖鈺冪＜闁绘柨澧庨杈╃磼閹邦収娈旂憸鐗堢洴瀹曟悂骞囬鐘茬伇**闂佹寧绋戦悧鎾诲闯閸濆娊鍦偓锝庡亝閹烽亶鏌℃径鍫濆姎婵ǜ鍔戝浼搭敍濠婂懎鐐婇梺鍛婄懕缁茶棄顭囧Δ鍛唨闁搞儵顥撶粈澶愭煕韫囨搩鍎旀繛鍫熸礈娴狅箓宕掑鍕殸
          //    `.position()` 婵炴垶姊婚崰鏇㈠箚閵堝鎹堕柕濠忕畱婵剟鎮?Stack 婵炴垶鎸搁…顓犳濠靛瑙﹂悘鐐舵缂嶆挾鈧灚婢樼€氬摜妲愬鑸垫櫖閻忕偞鍎抽。鎻捗归悩顔煎姕闁绘鎸冲鐢割敄鐠恒劎鎲归梻鍌氭礌閸嬫捇鎮烽弴姘鳖槮閻㈩垼鍋婇幃娆戞喆閸曨偄绨ョ紓浣哄У閵囨粓鍩€?
          //    閻熸粏鍩囬崹纭呫亹婢跺奔鐒婇柛婵嗗閸ょ喖鏌ｉ妸銉ヮ仼闁轰緡鍠楃粙澶愬焵椤掑嫬绾ч柛鎰╁妷閺嬪棝鏌￠崟闈涚仩闁挎稒鎸炬禒锕傚磼濞戞妯?`windowSize` 婵炴垶鎸搁敃銉︽叏閵堝鍎?`reportWindow`闂?
          .onAppear(() => {
            this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            this.isAlive = true;
            // 鈽呪槄鈽呪槄 2026-10-17锛堝瓙浠ｇ悊瀹氫綅锛夛細**鍏堝悆璺ㄩ〉闈㈢紦鍐?*锛屽啀璧板師鏉ョ殑缃戠粶/璧勬簮鍙栨簮銆?
            //   鍦ㄦ涔嬪墠 `adoptCachedMesh()` 闆惰皟鐢ㄨ€?鈬?姣忔閮戒粠闆朵笅杞?鈬?鐐瑰嚮鎵撳紑閭?350ms 鍐呮病鏈夌湡婧愩€?
            // 鉀?2026-10-17 鍋滅敤锛氭寕杞介偅涓€鎷?`getCurrentSongItem()` 鍙兘杩樻槸**涓婁竴棣?*
            //   鈬?鍛戒腑涓婁竴棣栫殑缂撳啿 鈬?鐢ㄦ埛瀹炴祴銆屾墦寮€鏃剁殑鑳屾櫙鏄笂涓€棣栨瓕鐨勯鑹层€嶃€?
            //   鎺ュ洖鏉ョ殑鍓嶆彁锛氶鐑姸鎬侊紙鎸?褰撳墠鏇茬洰鍙樺寲"鍐欏叆锛夊厛钀藉湴銆?
            // void this.adoptCachedMesh();
            // ★★★ 2026-10-17：先用**壳层预热好的**缓存（内部比对 key，key 不对就等 version 变化）；
            //   然后再走原来的网络/资源取源链路（拿不到时 MeshCoverBg 用取样色兜底）。
            // ★★★ 2026-10-17（⑤）：**先 await 一次 `adoptWarmMesh()`，再 `getImageColor()`**。
            //   原来这里是 `void this.adoptWarmMesh(); this.getImageColor();` —— 两条链路并发，
            //   取色那一路甚至可能先落地，屏上就出现"背景与封面不是同一首"。
            // ★★★ 2026-10-18（第三轮）：**先同步采用一次预热缓存**（`createPixelMapSync`），
            //   形变第 1 帧就有真封面 —— 等价上游"打开前本地封面文件已在"（`wujie.pa:292406-292448`）。
            //   然后再走异步那条（拿网络/资源，顺便取色）。
            this.adoptWarmMeshSync();
            void this.adoptWarmMeshThenTint();
            this.applyPlaybackWindowChromeImmediately();
            // 婵＄偑鍊楅弫璇差焽閻楀牞绱旈柡宥庣厛閸嬔囨煕閹达絾顏犳鐐叉喘瀵喚鎹勯悜妯衡偓杈ㄦ叏濠靛嫬鍔欑紒鏃€娼欓埢搴ㄥ灳瀹曞洨锛涢梺绋跨箰绾绢厽鎱ㄩ幖浣哥畱濞撴艾锕︾粈鍕偣娴ｇ鈷旈柣銈呮閵囧嫰妫冨☉妯款唹闂佺厧鐤囧Λ鍕垂娴兼潙缁╃痪顓炴噽缁犳牠鏌?
            this.applyCoverTint();
            // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佸憡甯炴慨鐢垫暜閳?`playbackSwiperIndex = 0`闂佹寧绋掔粙鎾诲磼閵娿儺鍤曢柡鍥╁仧缁?闂佺懓鐏氶幐鍝ユ閹达箑绠涢煫鍥ㄦ尰缁?缂?*闂?
            //
            // ## 闂佸憡顭囬崰鎰焽閻㈠憡鐒介柨婵嗘噹缂嶆牕鈽夐幘瑙勩€冪紒顔肩墛缁嬪﹪宕奸悢鍝ョ暢闁?
            //   闁诲海鎳撻崯顖毼?*闂佺厧鎼崐濠氬磻閿濆洨妫憸宥吤洪弽顐ｅ?*闂佹寧绋戦悧濠傦耿?`Column` 闂?`.onAppear`闂佹寧绋戦懟顖炲垂鎼淬劌缁╂い鏍仜濞呫垻鈧偣鍊涘銊у姬閸愨晛顕辨慨妯虹－閻涙捇鏌ㄥ☉姗嗘█闁革絿鍏橀幆鍐礋椤愩垺娅㈤梺绋跨箞閸庤崵妲?
            //   闂?`playbackSwiperIndex` 闂?Swiper 閻熸粎澧楅幐鍛婃櫠閻樼偨浜?闂佹眹鍔岀€氼剟寮鐣屸枖闁逞屽墴閹晠鎳滅喊妯轰壕濞撴艾锕︾粈澶娾槈閹惧瓨鈷掓鐐叉喘瀹?
            //   **缂傚倷鐒﹂崹鐢稿春鐏炲墽顩?`Swiper.index()`**闂佹寧绋戦悧鎰帮綖?`Swiper()` 婵炴垶鎸搁敃銉╁蓟閻斿吋鐒介柨婵嗘－閸炰粙姊婚埀顒勫箰鎼淬垺娈橀梻浣瑰絻椤厾妲愬璺何?
            //   婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲繘寮担鍦枖闁逞屽墰閹秆冪暋閻楀牏娈ら梺鍝勫閸ㄧ數鎹㈤弽銊р枖妞ゅ繐瀚崺宀勬煟濡鍟囩紒?
            // ```
            //   闂佹椿娼块崝宥夊春濞戞瑧顩烽幖杈剧磿娣囨椽姊洪鍝勫濠殿喗鎮傞獮鈧ù锝呮贡閸?濠殿喗绻愮徊钘夛耿椤忓牆绠绘い鎾跺枑閺?闁哄鏅滅粙鎺楀箰闁秴缁╅柟顖嗗嫮褰?闂?闂佺懓鐏氶幐鍝ユ閹达箑绠涢煫鍥ㄦ尰缁傚牓鏌熺捄鐚村姛闁稿被鍔岄锝夊即閻樺灚鐎?0闂佹寧绋戦悧鎰邦敊閺囩姵濯奸柍銉﹀墯濞层倖鎱ㄥ┑鍕偓褏妲愬┑鍫熷枂?
            //     PlaybackIntentShell闂佹寧绋戦ˇ顐﹀疮?闂佹椿娼块崝宥夊春濞戞﹩鐓ラ柟瀛樼箓閻撳倹鎱ㄥ┑鍡欑劮闁伙附绻冮妵鍕枈婢跺瞼顦╃紓浣风┒閸ㄥ湱妲?= 1闂佹寧绋戦悾鐠磞ricMorphT` = 1闂?
            //   闂佸搫鏈崝鎺楁煂濠婂牊鍤嶉柛灞剧矊娴狀垶姊洪幓鎺斝㈢紓?闂?闂?`onAppear` 闂佸憡鐟ラ悧鎰玻閸ャ劎鈻旈柍褜鍓欓埢?闂?缂備椒绌堕崹鍦閳哄啯鍋栨い鎰╁灩閺呮悂鏌?0
            //   闂?`Swiper` 闁荤姴鎼崯鍨洪弽顐＄剨濞撴埃鍋撴繛鑲╁閵?+ `lyricMorphT` 婵炴垶鎸哥€涒晠寮绘繝鍐︿簻闁稿繐鎽滈悷婵嗏槈閹绢垰浜鹃梺?
            //   闂?闁荤喐鐟ラ崐褰掑礉閸涘瓨鏅?*闂侀潻璐熼崝宥夋偤閺囩姵瀚氱€广儱顦埀顒€顦甸弫宥囦沪閻ｅ本顔堥梻鍌氱墑閸ㄧ懓鐣甸崼鐔衡枖鐎广儱鎳庣紞渚€鎮?*闂佹寧绋戦悧蹇涘极閵堝绠?2026-10-16 闂佹椿浜為崰鎰攦閳ь剟鏌熼幖顓濈盎婵炲瓨顭囬埀顒€婀遍崑鐐电矈閹绢喗鏅?
            // ```
            //   闂佸疇娉曟刊瀵哥箔?闂佸吋婢樻總鏃傜箔閺嶃劍浜ゆ繛鍡楅叄閸?婵犮垼娉涚粔宕囩礊?闁?*闂佸憡鍔曢崲鏌ュ箚鎼淬劌绀夐柕濞炬櫅娴滄繈鏌℃竟婧垮€楅悢鍛存煛閸偄澧繛鑲╂暩娴滄悂宕￠悜鍡樷柤婵?*闂佹寧绋掔喊宥嗘櫠閿曗偓椤曪綁鍩€椤掑嫬绠绘い鎾跺枑閺夊綊鏌涢敐鍐ㄥ婵?
            //      `PlaybackIntentShell` / `ProductViewModel` 闂備緡鍙忕徊鑲╃博閹绢喖绾ч柍銉ュ暱閸ゆ帞绱撴担鍝ョ濠碘€虫憸濡叉劙濮€閻樼數鈹涚紓?0 婵?
            //      闂佹寧绋戦悧鍡涙偩閻樿鍙?闂佺懓鐏氶幐鍝ユ閹达箑绠涢煫鍥ㄦ尰缁?闂佹眹鍔岀€氼亞绮╅幘顔界劸闁靛鍎遍悗濠氭煥濞戞﹩妲堕柍褜鍓欓崐鑺ヤ繆椤撱垺鍊烽柛锔诲弮閻涙捇鏌涢妷褍浠╅柣銊у枛瀹曟ê顓奸崱妤婃降婵炴垶鎸撮崑鎾寸箾閸″繆鍋撻崘鍙夐敪婵炴潙鍚嬬喊宥嗕繆閹间焦鍋ㄩ柕濠忕畱閻?*閻熸粎澧楅幐鍛婃櫠閻樼偨浜?*闂佺懓鐏氶幐鑽ゆ暜閳ь剟鏌?
            //
            // ## 闂佺粯绮嶅妯猴耿椤忓牊鍎嶉柛鏇ㄥ亜閻庤崵鈧鎮堕崕鑽ゆ濞嗘挸纭€闁哄洦姘ㄩ閬嶆煟椤忓棗鏋戠紒顭戝櫍閺佸秶浠﹂挊澶屽姸闂佸憡鍔曠粔鐢垫嫻閳哄懎瑙﹂柛顐墰缁€?
            //   閻?**闂佺懓鐏氶幐鍝ユ閹达箑绠绘い鎾跺枑閺夊綊鏌?* 闂?闂佹眹鍨兼ご鍛婃櫠閿曗偓椤曪綁鍩€椤掑嫬绠涢煫鍥ㄦ尰缁傚牏绱?`playbackSwiperIndex = 0`闂佹寧绋戦悧濠傦耿閻楀牄浜滈柛蹇撴憸閻熸繈鏌涘▎蹇撯偓椋庣箔瀹€鍕櫖濠㈣埖绋撻獮?
            //   閻?**闂佹椿娼块崝宥夊春濞戞﹩鐓ラ柟瀛樼箓琚?*   闂?`.onChange` 闂佸憡鍔栭悷褔宕掗妸銉殨?+ `.onAnimationStart` 婵＄偟鎳撳畷顒佹叏?`lyricMorphT`闂?
            //   閻?**闂佺厧鎼崐濠氬磻閿濆绀勯柧蹇曟嚀缁?*   闂?闂佸憡鐟禍婊堝箖閹炬剚娼?闂佸搫鐗滈崜鐔煎Υ婢舵劖鍤婃い蹇撳缁犳帡鏌ｉ妸銉ヮ伂妞ゎ偄顑囬幉瀛樺緞鐏炲彨锕傛煙?闂?*婵炴垶鎸哥粔鍫曪綖椤愶附鍋ㄩ柕濠忕畱閻撴洟鏌涢敂鍝勫闁瑰鍨虹粙澶愬焵椤掍降浜?*闂?
            //
            // ## 婵?闁诲繐绻嬬欢姘焽閹殿喚纾兼い鎾卞焺濡?闂備緡鍙忕徊鑲╃博鐎电硶鍋撻棃娑欒础婵炲牊鍨垮畷妤€鐣烽崶顒€鍘欓梺鎸庣☉閻楁劗鎹㈤弽顓熺厒鐎光偓閳ь剙鈻撻幋鐐茬窞鐎广儱瀚粔?*闂婎偄娲ら幊姗€濡磋箛娑欏仼?*闂?
            //   婵炴垶鎸搁澶婎焽閻楀牏鈻旈柕鍫濇噹缂嶆牠鏌?*闂佸搫鐗滈崜鐔煎Υ婢舵劖鍤婃い蹇撳缁犳帡鏌ｉ妸銉ヮ仾婵烇絾濞婇幃浠嬫偄閸濆嫅锕傛煙?*闂佹寧绋戞總鏃傜箔婢舵劕鍙?闂佹椿娼块崝宥夊春濞戙垹鎹堕柕濞垮劜閹插灝鈽夐幘顖氫壕婵?闂?
            //   `lyricMorphT` / `lyricMorphVisible` 闂佺顕х换妤呭醇椤忓牊鍎嶉柛鏇ㄥ墯绗?闁诲繐绻嬬欢姘焽閻楀牜妲归柣鎰邦杺閺€浠嬫煕閺傝濡块柡浣哄亾濞艰鈽夊搴㈡杸闂佸憡甯楀姗€骞?闂?
            //   闂佺厧鎼崐濠氬磻閿濆鐓傜€广儱鎳愮槐锕傛煕濮橆剟顎楃紒鐑╁亾婵＄偑鍊涢褍煤閺嶎厼绀嗗ù鐓庣摠妤楊垱鎱ㄥ┑鍕仾闁逞屽厸缁躲倗妲愬▎鎾宠Е闁挎洍鍋撻柛顭戝灡鐎电厧顫濋璺ㄤ笉闂侀潻璐熼崝瀣博鐎涙鈻旀い蹇撴硽婢舵劖鈷掔紓鍫㈠Ь閸橆剟姊婚崒姘辨憼闁逞屽厸缁躲倗妲愬璺何?
            //   闂佸疇娉曟刊瀵哥箔?婵?*缂備椒绌堕崹鍦閳哄倻鈻?1 闂佸搫鍟﹢鍦箔婢舵劖鍤勯柣锝呮湰闁裤倝鏌ｉ埡濠傛灍濠?`lyricMorphT` 閻?0** 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鑲╂閹殿喗濯?闂侀潻璐熼崝宥夋偤閺囩姵瀚氱€广儱顦埀?闁哄鏅滈悷銈囩博鐎靛憡鏆?
            //      闂佹眹鍔岀€氼剟鎯冨┑瀣棃闁靛繒濮寸紞渚€鏌涢妷褍浠滈柕鍥ф川娴滃憡绗熼埀顒€顭囨导瀛樻櫖闁割偆鍣ラ崝鈧梺鍝勫閸ㄥ崬锕㈤弶搴撴瀻闂勫洭銆呴敂鐣屸攳妞ゆ梻鍋撻悾閬嶆煟濠婂嫬顎滈柦鏍у閺佸秵寰勯崼姘壕闁稿本顨呭▍?闂佸湱顭堥ˇ閬嶅磼閵娿儺鍤曢柡鍥╁仜閺嬧偓闁诲氦顫夊畝绋款焽閵堝拋娼伴柕蹇婃閸嬫挻绗熸繝鍕崶
            // ```ts
            //   this.lyricMorphT = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
            // ```
            //   闂?闂傚倸鐗婇悷锕傤敆濞戙垹绠?= 閻熸粎澧楅幐鍛婃櫠閻樼偨浜滈梻鍫熶緱閸ょ娀骞栫€涙ɑ鈷掓繛鍫熷灩缁晠顢涘鍐у寲"闂佹寧绋戦惌浣烘崲閺嶃劎鈻曢柣鏂挎啞绗?`lyricMorphT` 婵炴垶鎸堕崐鎾绘煂濠婂懐鐭欓柛鎰皺閺嗕即鏌涙繝鍛汗婵炲牊鍨归埀顒冾潐閻喚绮婚悢鐓幬?
            //   闂?2026-10-16闂佹寧绋戦悧蹇涱敄閸ャ劎顩茬€光偓閳ь剚鏅跺Δ鍛櫖濠㈣埖绋撶粣妤呭级閳哄倻鎳囬柛锝囧厴瀹曘垽鎮㈤崨濠囨闂佸搫瀚烽崹顖滅博閹绢喖鐭楅柕澶堝劚閺佸爼鏌ゆ潏銊︾叄缂佹ぞ绶氬畷妤呭礃閿旂懓浜鹃柛灞剧矊缁犳盯鏌涢敂鍝勫闁轰礁缍婂顐⑩槈濠婂懐顔?
            //     `syncLyricMorphToPage()` 闂佺偨鍎查弻锟犲焵?闂佹悶鍎虫慨宕囨嫻?*闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳閸ょ姴顫楃紒妯哄濠殿喒鏅滈幏鍛煥閸愨晞鍚梺鍦焾閸婅棄霉閸ヮ剙绫嶉柡鍫㈡暩閻﹀秹鎮烽弴姘鳖槮濞寸姵绋掔粙澶愬焵椤掆偓閳?*
            //     闂佹寧绋戝濉outToAppear`闂佹寧绋戦¨鈧紒杈ㄧ箖缁嬪濡堕崪浣剐熼棅顐㈡搐閹虫﹢濡磋箛娑樿Е閻忕偠鍋愰閬嶆煕濞嗘瑧鍒扮紒鍓佸仱閺佸秹宕奸敐搴㈢秳闂備緡鍙忕徊濂告煂濠婂牆妫橀悷娆忓閵嗗﹪鏌ｉ妸銉ヮ仾闁轰胶鍋ら弻灞剧節韫囨洜顦梺?
            this.syncLyricMorphToPage('appear');
            // 闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷銈囩博閹绢喖鐭?*闂婎偄娲ら幊姗€濡磋箛娑欏仼婵炲棗绻戦煬顒€顭块懜鐢靛⒌婵?*闂佹寧绋掗悺鐚粂ncLyricMorphToPage()` 闂?閻庤鐡曠亸娆戝垝閿涘嫧鍋撻棃娑氱Ш缂?闂佸搫鍟﹢鍦?*闂佸搫鍟犻弲鐘诲焵椤戣棄浜?*闂?
            //   闂?闂佺厧鎼崐濠氬磻閿濆鐓傜€广儱鎳愮槐锕傛煕濮橆剛鍑圭紒妤€顦遍幏瀣矙婢跺摜涓嶉梺闈╄礋閸斿繗妫㈤梻鍌氬€荤换婵嬫嚈閹达附鈷掗悗娑櫱氶崑?闁哄鏅滈悷锕€顭囬婊勫暫濞达絽婀卞﹢瀛樻叏閿濆懐绠叉い?`onAppear` 闂備緡鍠栭埀顒傚櫏濞诧絾绻濇繛鎰╁€曢崰鏇㈡煏?
            this.lyricMorphVisible = false;
            // 闂佺鐭囬崘銊у幀闂佸憡鐗滅亸銊ф閻楀牊浜ゆ繛鎴炵懄闂勫秹鏌涜箛鎾跺闁轰焦绮撳畷娆撴偖鐎靛摜顦? 缂備礁顦扮敮妤呮儉閸涙潙绀夐柕濞垮妼濞堜即鏌涢弬璇插闁轰礁婀遍幐?
            this.chromeCollapsed = false;
            this.touchChrome('appear');
            // 闂?2026-10-15 闁荤姴娲ら敃銉╁蓟閸ヮ剚鏅慨妯挎珪閸庢澘霉閿濆懐小缂佺媴缍佸畷銉︽償閳ヨ櫕娅冮梻浣瑰絻缁诲绮╅弶鎴旀瀻闁炽儴娅曠壕钘夆槈閹垮啩绨绘繛纭风節閹啴宕熼鐘茬倞闂佸憡鐟辩徊鍧楁偂閳哄嫨浜规い顐枤缁€鍕偡?`logLayoutBoxes()`闂佹寧绋戦ˇ顓㈠焵?
            //   480ms 闂?闁诲繒鍋炲ú鏍閹寸姵鍋橀柕澶嗘櫆閿涚喖鏌ㄥ☉妯煎婵炴挸鐖煎?560ms 闂佹眹鍔岀€氼厾鎷犻悙鍏告勃闁稿瞼鍋涙禍婵嬫煛?+ 20ms 闂佽　鍋撻悹楦挎閸熸煡鏌ㄥ☉姗嗘Ц闁绘柡鍋撻梺鍝勭墱閸撴繈鎽傜€ｎ兘鍋?闂佹眹鍔岀€氫即宕抽搹鍦／鐟滄繄妲?
            //   闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮?`RzdBoxes`闂侀潧妫楅崐闈涒枔閹间焦鏅?闂佸憡鐟禍锝夘敋娴煎瓨鏅悘鐐跺亹閻熸繄鎲搁弶鍨埞闁瑰ジ鏀辩粋鎺旀媼瀹曞洨协闂佺粯顭堥崺鏍焵椤戝潡妾烽柍?
            setTimeout((): void => {
              if (this.isAlive) {
                this.logLayoutBoxes();
                // 闂?闂佺儵鏅╅崰妤呮偉?闂?闂?S1 濠殿喗绺块崕鎾吹濠婂懏瀚氬〒姘功缁€鍕煙閻戞ê绗氶柣鎿勭節瀹曟骞庨懞銉︽闁?`RzdSizeTier`闂佹寧绋戦¨鈧紒?
                //   闂佸搫绉堕…鍫ヮ敋?`sizeScaleOf` / `topPageSideOf` 闂?*闂佸綊娼ч鍡椻攦閳ь剚淇?*婵炴垶鎸搁敃銉ノｉ幖浣歌Е闁挎梹鍨濈槐妤€鈹戦崒婊勬珪闁烩剝鍨剁粋宥嗘償閵忕姷浜繛?
                //   閻庤鐡曠亸娆戝垝閿熺姴鎹堕柕濞у嫭娈㈤梺姹囧妼鐎氼剙霉閹邦喒鍋撶憴鍕闁逞屽墰閵嗗妲愬淇縤zeK = 1` / `side = 16`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂佸搫鐗忛崰鎰耿?`fixedOk=true`闂?
                this.expandState.logSizeTier(this.breakpointEnv.widthBreakpoint);
                // 闂?闂佺儵鏅╅崰妤呮偉?闂?闂?S2 濠殿喗绺块崕鎾吹濠婂懏瀚氬〒姘功缁€鍕煙閻戞ê绗氶柣鎿勭節瀹曟骞庨懞銉︽闁?`RzdWideCols`闂佹寧绋戦¨鈧紒?
                //   闂佺娉涢敃銈夘敊閺冨倷娌?/ 闂傚倸鐗勯崹鍝勵熆濡崵鈻旈柕鍫濇閳ь剙鍊块幆?*闂佸憡顨堟慨鐢告儊椤旂晫鈻旈幖瀛樼箚閳峰牓鏌″鍛妞ゆ梹姊归幆?*闂佺懓鐏氶幐鎼佸吹椤撱垹绾ч柕澶樺灣缁€鍕煙闂堟侗鍎愭繝褉鍋撴繛鎴炴尭閿曘倝鎮鹃悩宕囶浄妞ゆ垼娉曢悷婵嬫煕濞嗗繐鈧绮畝鈧弫顕€宕橀妸褎鎷遍梺?
                //   闂佸憡鐟禍婵單ｉ幖浣哥濠电姴鍟▓鍓佺磼閻樻剚娈旈柛銈庡弮瀵爼濡烽妷顔叫ｉ梺鍝勮閸庤崵妲愬璺何ラ柛宀€鍋為敍鐔兼偣閻戞绠扮紒杈ㄧ崠utter/space闂?*婵炴垶鎸哥粔鏉戯耿椤忓牆绀傞柡鍫滅祷閸?* 闂佺偨鍎查弻锟犲焵?闁?S2 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电偛绨遍崑?
                this.expandState.logWideColumns(this.breakpointEnv.widthBreakpoint, this.usePanelLayout(),
                  this.getUIContext());
              }
            }, 480);
            // 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃銉﹀垔濞差亜绠ラ柟鎯х－绾惧鏌￠崘鈺佸姸缂佺粯蓱閹棃鏁冮埀顒勫礄閿涘嫮纾奸煫鍥ㄦ尰闊剟鏌熼柨瀣ⅹ濠殿喒鏅滅粙澶愵敇闄囧▔鎻捗瑰鍐╊棛缂佹梹鎸抽弻鍫ュΩ閵夈儳鈧鏌ㄥ☉妯肩劮缂佺粯鐗犻弻宀€浠﹂懖鈺冩喒闂佺厧鍘栫划娆撳闯閸濄儳纾炬い鏇炴楠?
            //    闂佺粯鍔楅幊鎾诲吹?闁荤姍鍥ㄦ暠闁规悂浜堕獮鍥疀閹惧顩梺鐟扮仛閹稿摜妲愰幋锕€绫嶉柟顖涘缁犲骞栨潏楣冩婵?0闂佹寧绋戦悧鎰帮綖?aboutToAppear闂佹寧绋戦ˇ顓㈠焵?
            this.collapseProgress = 0;
            // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*閻熸粏鍩囬崹纭呫亹婢跺顕辨慨妯虹－濡牏鎲搁悧鍫濈瑨闁挎稒鎸炬禒锕傚磼濞戞瑯妲梺鎸庣☉閺堫剙锕㈤悧鍫涗簻闁稿繐鎽滈悷婵嬫偣瑜戝〒褰掑箲閵忊剝濯撮柡鍥╁仧濞兼梻鈧鍠掗崑鎾绘偠濞戞牕鍔︽俊?*闂?
            //   闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗙墢閻濆爼鏌熺紒銏犲箺闁哄倷鐒﹂妵鍕媴閸愩劍顔囬悗鍦焾瑜板绮径鎰妞ゆ挾鍋熷鏃傗偓娈垮枓閸?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯顐ャ亹瑜斿浼搭敍濠垫劖钑夋繝銏㈡嚀閸熷潡鎯囨导瀛樺剭?`ExpandAnimation`
            //   闂?`scale/translate/clip` 闂佽浜介崝搴☆焽閸愵喖鐭楁慨妤€鐗忕粈澶愭偠濞戞牕鍔︽俊顐㈡健瀹曠兘濡搁妷顖滃闁诲繒鍋涢崑濠勬濡句靠ettlePullOpen`闂佹寧绋戦ˇ顓㈠焵?
            //   闂佸搫鐗滈崜鐔煎Υ婢跺娼伴柕鍫濇噹閻撴繈鏌涘▎妯圭盎濞寸姵绋掔粙澶愬焵椤掍胶顩烽柡鍫㈡暩閻ㄦ垿鏌?*闂佺娉涢敃锔惧垝椤栫偛绀嗛柛顐ｆ礃閿涘矂鏌熼崹顐ｅ碍缂?*闂佹寧绋戦悧鍡涘吹閹寸偞濯撮柡鍥╁仜閸ゆ帞绱撴担鍝ョ婵℃彃鎲＄粩鐔煎礃閼碱剚鍕鹃梺鍛娒鍛村Χ娴犲鍎嶉柛鏇ㄥ枟瀹曟娊鏌ｉ幇顔筋仧缂佽鲸宀告俊?
            //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷鈺呭闯?*婵炴垶鎸哥粔鐑筋敊?*闂佸憡鍔曠粔闈浳涢妶澶婄骇闁炽儱寮堕浠嬫偣?`playExpandIntro()`闂佹寧绋掗懝楣冩偩閻樺啿顕辨慨妯虹枃濞?`tryStartMorphIntro()`闂?
            //      闂佸吋婢橀惌鍌炲磻閸涙潙绾ч梽鍥儗閸撗勫暫?闂備焦褰冪换鎰板春瀹€鈧槐鎺楀醇閵忕姳鍖栭梻浣瑰濮樸劑宕?闂佸綊娼х粔鐑藉磻濡ゅ啯灏庨柣銈庡瀬婢舵劖鈷掓繛锝庡厴閸嬫挻绗熼埀顒勫闯閻戞鈻旂€广儱鎳庨悡鍌炴倶韫囨稐鎲鹃柍褜鍏橀崑鎾绘煕閺嶃劎澧柛?
            //      `playLegacyExpandIntro()`闂佹寧绋戦悧鎰板礆濞戞瑦鍎熼柡鍥ㄦ皑椤忛亶鏌℃径娑氱瘈闁哄棜椴哥粙澶嬬節閸愨晠妾?= 濠电偞鐓＄粻鏍偂閸洖绫嶇憸宥嗘叏閳哄懏鍋ㄥù鍏肩懅缁€?
            //      闂?闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳瀵娊鏌涘▎娆戠ɑ婵犫偓娓氣偓瀵噣鎳滈崹顐嶏箓鏌￠崒娑欑凡濠殿喒鏅犻幃钘壭ч崶锝呬壕濞达綀顫夌粻鎺楁煛閸愵厼鐓愭俊鍙夋倐瀵喛顦插┑顔规櫊閹姤瀵煎▎鎴狀槷濠殿喗绻愮徊鎯ｉ幖浣肝ラ悘鐐靛亾閻撯偓闂佸搫鍞查崟顐熷徍闂佸搫顑堢紙浼村焵椤掆偓缁夎泛鈻撻幋锝冧汗闁靛繈鍨圭瑧闂?
            //
            // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱濠电偛澶囬崜婵嗭耿娴ｈ桨鐒婂〒姘ｅ亾婵?闂佺厧鍟块張顒€鈻嶅▎鎾崇闁靛ě鍕瘞闂佹眹鍔岀€氼喖锕㈤敓鐘插唨闁荤喓澧楃粈?*闂佹寧绋戦¨鈧紒?
            //   闂佸憡甯囬崐鏍х暤娓氣偓瀹曘垽鎮㈤崨濠囨闂佸憡鐟禍婵嗭耿?`morphContainerActive()`闂?*闂佺粯鍔楅幊鎾诲吹椤旂偓宕夋い鏍ㄦ皑缁愮偤鏌涢敂鍝勫閻庡灚娲樺顏呯鐎ｎ亙绨兼繛鎴炴尨閸嬫捇鏌涢幒鏇ㄥ殭闁伙絿濮靛璇参熺紒妯烇箓鏌?*闂?
            //   ```
            //     闂佺粯鍔楅幊鎾诲吹椤曗偓閺佸秴顫濋濠勫闁?beginOpenMorphOnClick 闂?pullOpenBegin
            //            闂?prepareMorphEntry 闂佸憡鐟﹂崹褰掔嵁?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暟缁犻攱绻涚仦绋垮⒉閻庡灚娲樺顏呮叏閹般劌浜惧ù锝呮憸濞堥亶姊婚崼娑樼伈闁革絿鍎ょ粙澶婎吋閸涱厾鍘?
            //            闂?闁?!ready 闂佸憡甯掑Λ娆撳极椤曗偓閺佸秴顫㈤悾淇絧hStage = ENTERING闂侀潧妫斿▽鐒phDrive = FINGER
            //            闂?婵炶揪绲藉Λ瀵告濞嗘挸瑙﹂悘鐐跺亹閻熸劙鏌?*morphUsable = false闂侀潧妫斿▽鐒phP = 0** 闂?morphContainerActive() 婵炴垶鎸搁幖顐ｇ?
            //            闂?pushPlayerRoute 闂?闂佸搫鐗滈崜鐔煎Υ?onAppear 闂?闂佺懓鎼ˇ宕囨崲?else 闂佸憡甯掑Λ娆撳极?闂?**闂佸湱铏庨崢钘壡庨幎鑺ヮ棅闁惧浚鍋呴敍瀣煕閺傝濡块柡?*闂?
            //     婵炴垶鎸搁敃銉﹀垔濞差亝鏅慨姗嗗墾缁憋箓鎮?onPullOpenStart 闂?pullOpenBegin闂?*闂侀潻璐熼崝鎴﹀Υ婢舵劖顥堥柕蹇娾偓宕囨Ц闁哄鍋為崹婵堢不閿濆绀?*闁?
            //            morphBeginEntering()闂佹寧绋戦悧鎾诲磻閸涙潙绫嶉柟顖涘绾板啫霉閿濆洤校婵炵⒈鍨堕弻宀冪疀閹惧墎绠掗梺鍛婂笒鎼存粎妲愬璺虹劷?闂佸湱顭堥崐钘壝归崶顒€绫?stage = ENTERING 闂?闁荤姍鍕凡妞ゆ洦鍣ｅ畷姘跺幢濡粯娈?
            //   ```
            //   闂?闁荤偞绋忛崕鎵博閹绢喖绾ч柍銉ュ暱閻忔煡鏌熺拠鈥虫珯缂?*婵犮垻鎳撻崯鍧楁儑閺夋鍟呴柤纰卞墰閻ュ懎鈽夐幘鑽ょ窗缂佺粯鐗楃粙澶愬焵椤掍焦濮滄い鏃€瀵у畷鎶藉级閳轰焦鎼愰柤闀愬嵆瀹曪絽螣閸︻厾鐛ラ柣?*闂佹寧绋戝濉祇rphSessionStarted`
            //     闂?`prepareMorphEntry` 缂備焦顨忛崗娑氱博閺夋埈娼伴柕澹懏鐎繛杈剧到缁嬪嫮妲愬┑鍥┾枖濠㈣泛顑嗛拏瀣煕韫囧鍔氱憸鐗堢洴閺屽牓骞嬮幒鏃傜崶缂傚倷绀佺换妤冩崲閸愵亖鍋撻悷鏉挎灕缂佽鲸宀告俊?
            //     闁诲海鎳撻崯顖炲垂濮樿京鍗?闂?闁哄鏅滈悷銈囩博鐎涙ǜ浜滈柣銏犵仛閻ｈ京绱掑Δ濠傚幐缂佹柨顕弫顔款槻婵ǜ鍔庨幏?婵炴垶鎸哥粔鍫曞极?闂佹寧绋戦悧蹇涙偤閹寸偟鐝堕柛鎰皺濠€鎾煙鐠虹尨宸ラ柛銈嗗灦閹峰懘寮撮悙鑼伝闂佸憡甯楁刊浠嬪箲閿濆鍊烽柣褍鎽滅粈鍡涙煥?
            //     闂佸吋婢樻總鏃傜箔婢舵劕鍙婃い鏍ㄧ箓濞堟壆鈧湱顭堝畷顒傛閹寸偞鍙忛悗锝庡亝鐏忥繝姊洪銊у埌妞?`collapseProgress` 闂佸搫鍞查崘銊愭鏌ｉ姀锛勬菇闁?
            // ★★★ 2026-10-18（用户：「点展开时用系统返回打断动画，再打开播放器，滑到歌词页封面不会变小」）：
            //   每轮进场都**重新上报一次**大封面锚点（幂等）。原因见
            //   `PlayerExpandState.resyncBigCoverAnchor()` 的注释：`bigSize` 每个形变会话开头会被清零，
            //   而它唯一的补给是 `MusicPlayInfoBlock` 的 `onAreaChange` —— 打断动画后重开时
            //   大封面矩形与上一轮完全相同 ⇒ 那个回调**不再触发** ⇒ `bigSize` 停在 0
            //   ⇒ `lyricCoverSizeOf() === 0` ⇒ 滑到歌词页封面不缩、不飞。
            //   ⚠️ 打两枪：`onAppear` 这一帧布局可能还没算完，量不到就再来一次；
            //     两枪都量不到（例如页面还在进场动画里被压扁）也没关系 —— 下次进场还会再试。
            setTimeout((): void => {
              if (!this.isAlive) {
                return;
              }
              this.expandState.resyncBigCoverAnchor(this.getUIContext());
            }, 0);
            setTimeout((): void => {
              if (!this.isAlive) {
                return;
              }
              this.expandState.resyncBigCoverAnchor(this.getUIContext());
            }, 96);
            if (this.expandState.morphContainerActive() || this.expandState.morphSessionStarted) {
              this.diagAppearBranch = 'morph';
              this.introPaintReady = true;
              this.expandIntroRunning = false;
              // 闂佸疇妫勯幊澶娢?2026-10-16闂佹寧绋戦悧蹇涘磻閿濆绀勯柡鍕箳閻斿懐鈧灚婢樼€氼喖鈻?*闂佸憡鍨规慨宕囩礊瀹ュ洦鍋橀柕澶嗘櫅濞?*闂佹寧绋戦¨鈧紒?
              //   闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂?`pullOpenBegin` 闂佸搫瀚烽崹鏉匡耿?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暟缁犻攱绻涚仦绋垮⒉閻庡灚娲樺?闂備緡鍙忕徊鑲╃博閹绢喖绀嗛柡鍕箳閻涙捇鏌?闂?闁诲海鎳撻崯顐ゆ閵忋倕鐭楁い鏍ㄧ箓閸?
              //   闂佺懓鍢查妵妯肩箔婢舵劕绀嗛柟娈垮枤閻帡鏌ｉ幇顒傜Ш闁轰礁顑夐幃娆撴儌閸濄儳顦╅梺鍦檸閸樹粙寮担骞夸簻闂傚牊绋撳▓閬嶆⒒閸稑鐏卞┑鈽嗗弮閹瑧娑甸崨顖滎啂婵炴垶鎸哥粔鎾偤閵娾晛鎹舵い顓熷笧缁€鍡涙煃?`morphUsable = false`闂?
              //   婵犮垻鎳撻崯鍧楁儑娴煎瓨鐒介柨婵嗙墢閻濆爼鏌?12闁?2ms 闂佹眹鍔岀€氼垵妫㈤梻浣瑰絻缁绘帡鎮伴妷鈺佺煑闁挎繂绻掔粈鍒瀞chedulePullAnchorRemeasure`闂佹寧绋戦¨鈧紒?
              //   婵炶揪绲藉Λ婵嬪磻閸涙潙鍙?*婵犮垻鎳撻崯鍧楁儑?*闂佹眹鍔岀€氼垱淇婇鐔洪檮闊洢鍎抽獮銏ゆ煛閸偄澧撮柕鍡楊樀楠炴劙宕掑┑鍥┿偘闂備緡鍙忕徊鑲╃博閹绢喖绀嗙紓浣股戠瑧"闁诲繐绻嬬欢姘焽娴煎瓨鍤嶉柛灞剧矊娴?*闂佸憡甯楅懝楣冨垂閹殿喒鍋撳☉娅亜锕?*"闂?*闂佸搫鐗冮崑鎾绘煛?*闂佸搫鍟抽崺鏍р攦閳ь剟鏌?
              //   闂侀潻璐熼崝蹇曟崲閺嶎厽鐓傜€光偓閸忣垰顦甸弻宀冪疀鎼达綆浼囧┑鐐叉濡插嫮妲愬┑鍠版帡寮崒婊勬儯婵犮垻鎳撻崯鍧楁儑閻楀牏鈻旈悗锝傛櫇椤忛亶鏌熷畡鎵枌缂佽鲸鐟╁鐢稿焵椤掍礁绶?32ms 婵炴垶鏌ㄩ鍛村箖濡ゅ懏鏅璺侯儐缁绢垶鏌涢幋婵囶棑闁?
              //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁ˇ浼搭敆閻愬灚灏庨悽顖ｅ枤缁€澶岀磽閸屾繃銆冪紒鏃€娼欓～銏ゅΨ閵夛妇娈ゆ繛?闁荤偞绋忛崕鐢稿闯濞差亜绠ｉ柟閭﹀墮椤姴霉閿濆懏顥犳繛鏉戭槹閹峰懎顓奸崼銏㈩啂闂佺顑嗙划灞斤耿椤忓牆绫嶇憸搴ㄥ焵?闂?
              //     闂?`prepareMorphEntry` 闂佺偨鍎查弻锟犲焵?闂備焦褰冪换鎰板吹閹寸偞濯?+ `morphInitParams` + 闂佸憡锚椤戝懘宕哄畝鈧幐褎顦版惔鈥插寲闂?
              //     闂?`morphBeginEntering` 閻庤鐡曠亸娆戝垝閿熺姵鍋ㄩ柛妤冨仧閺嗗﹪鏌涢幇顒佸殗闁稿骸顕幏顐﹀礃椤撶姷鐣洪梺鎸庣☉濠躬ady 闂佸搫鍟抽鎰濮樿埖鏅?
              //     闂?闁荤偞绋忛崕鐢稿闯濞差亜绠ｉ柟閭﹀墮椤娀鏌?*闂婎偄娲ら幊姗€濡?*闂佺娉涢敃銉ф嫚閻愬吀娌柛宀€鍋涙禍婵嗏槈閹绢垰浜惧┑鈽嗗亝鐢偛鈻撻幋鐘冲仒闁靛鏅滈敍鐔封槈閺冨倸鏋欓柟鐧哥悼閹秆囨煥鐎ｎ偊妾烽梺鎸庣☉閻楀棝骞嗘笟鈧畷姘枎韫囨洘顔堥梻鍌氱墱濠⑩偓缂侇喗鐩幃鐐哄嫉閻㈢數鎲规俊鐐差儑閸庢垹妲愬璺何?
              setTimeout((): void => {
                if (!this.isAlive || this.isClosing) {
                  return;
                }
                this.diagRemeasureTries = this.diagRemeasureTries + 1;
                // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佸憡鑹炬總鏃傜博绾惧浜归柕蹇嬪灩绗戦梺姹囧妼鐎氼噣顢?3 婵?*闂佹寧绋掗懝鎯ь嚕閻㈢鍙?缂備胶濮甸〃鍛村吹椤撱垹绾ч柕澶堝€楅崯?閻熸粎澧楅幐濠氬垂?闂備焦褰冪换鎰板春鐏炲墽顩?闂佹寧绋戦¨鈧紒?
                //   闁哄鏅滈悷銉ㄣ亹閻愬搫鍌ㄩ柣鏂挎啞闂勫秹鏌?`if (morphUsable) { return; }` 闂佺偨鍎查弻锟犲焵?闂?`morphUsable` 闂?
                //   `morphInitParams()` 闂佹眹鍔岀€氼喚鍒掗妸褎濯奸柣姘嚟缁?*闂佸憡鐟禍锝夈€?barW/boxW 闂備焦褰冪换鎰板春鐏炲墽顩查柛鈩冾殘閺嗗﹪鎮樿箛鎾崇秮閻犳劗鍠栭幆?*闂?
                //   **闂佸搫绉烽～澶婏耿閻楀牏鈻旂€广儱娴傞崥鈧紓鍌欑閻楀繘宕戦敐澶嬬叆婵ê宕禒顖炴煛閸繍妲归柣銉ユ嚇瀵?*闂侀潧妫楅崐椋庤姳椤掑嫬鍙婃い鏍ㄧ矊娴狀垶鏌涢幋鐘靛笡濠⒀嶇畱椤曪綁鍩€椤掍焦浜ゆ繛鍡樺姈閽傚鎮规笟顖氱仧缂佹鍊块弫?
                // ```
                //   pullOpenBegin 闂?morphInitParams() 闂佺懓鐡ㄩ崝鏇熸叏濞戙垺鏅柛顐悼绾板啫霉閿濆洤校婵炵⒈鍨跺鍨緞婵犲倹顓绘繛杈剧稻濞测晝妲愬璺虹劷?morphUsable = true
                //   闂佸湱顭堥崐钘壝?闂?闁哄鏅滈悷鈺呭闯妞嬪孩瀚氶悹鍥ㄥ絻閻?morphUsable === true 闂?**闂佺儵鏅涢悺銊ф暜?return**
                //        闂?闂佸搫鐗滈崜鐔煎Υ婢跺浜ゆ繛鍡樺姦閸?闂佸搫鐗冮崑鎾绘煛閸愶絾娅囨繛鍫熷灩閹即濡烽埡浣诡仭闂佸搫鍟抽崺鏍р攦閳?闁荤偞鍑归崑鍡椻枍瑜旈幆鍌炲箣閹烘挷娑梺?
                // ```
                //   闂佸吋婢橀惉鑲╁垝閹剧粯鍊风憸鐗堝笚閺咁亪鏌ｉ幇顔藉殌婵犫偓?*闂佸搫鐗滈崜鐔煎Υ婢舵劕绠伴柛灞剧箖缁佹澘鈽夐弬娆惧剰濠?*闂佸搫瀚烽崹宕囧垝妞嬪簶鍋撻棃娑氱Ш闁革絿鍎ょ粙澶婎吋閸涱厾鍘掗梺姹囧妼鐎氬摜妲愬▎鎾村殟闁稿本绮屾禒顖炲级閳哄伅鑲╃箔婢跺备鍋撳☉娅亜锕㈤鍫熸櫖?
                //   闂?闁诲繐绻愬畷顒冦亹瑜斿畷婊堝煛娓氬﹦澶勯柣蹇曞仜閸婂潡宕戦崨鏉戠骇?12闁?2ms 闂佺绻戠划宀€鑺遍幎鑺ユ櫖閻忕偠澹堥埛鍫ユ煛婢跺棌鍋撶€圭姴鐝柣鐐寸☉閻厧鈻撻幋鐘冲仒闁靛鏅涘▍?*婵炴垶鎸撮崑鎾绘煛婢舵稓绡€闁稿繑锚閳讳粙妾辩紒?*闂?
                //   闂?闂佸憡甯囬崐鏍х暤娓氣偓楠炴垿濮€閳ュ磭浜?{@link PlayerExpandState.morphGeomReadyNow}闂? 闂佸搫鍟版慨鐑藉疾?`pullGeomReady`闂?
                //     闂佸憡鐟禍婵嗭耿娓氣偓閹洭鎮㈤悜妯兼殸闂備焦褰冪换鎰板春瀹€鈧槐鎺楀醇閵忕姳鍖栭梻渚囧弿缁茶偐绮╅幘顔肩鐎广儱妫楅·鍛槈閹捐顏犳繝鈧敓鐘虫櫖濠㈣泛鐗冮崑?*闂佸搫鐗滈崜鐔煎Υ婢舵劕绠伴柛灞剧箖缁佷即寮堕埡鍌滄噥缂佹梹鎸冲畷姘辩磼濮楀棗濡ч梺?缂傚倷绀侀悧蹇涘磻閿濆鍤嶉柛灞剧矊娴狀垶鏌涢幒鎾瑰闁宦板姂瀹?闂佹眹鍔岀€氼厼銆掗崼鏇炵睄闁冲搫鍊归ˇ褔鏌?*闂?
                //   闂佸疇娉曟刊瀵哥箔?婵?`morphUsable` 闂佹眹鍔岀€氼剟宕规惔鈽嗗晠闁靛鐓堝宀勬⒑椤撱劎瀵奸梺鍙夌矌閳ь剚绋掗〃鍡涱敊瀹€鍕剭闁告洦鍓氶弳鍫ユ⒑閹绘帩鐓紒杈ㄧ箞瀹曟岸顢曢姀鐘虫珒濠电儑缍侀ˉ鎾诲极閵堝违?
                if (this.expandState.morphGeomReadyNow()) {
                  return;
                }
                this.expandState.pushMorphTrace('appearRem');
                UIUtils.applySync((): void => {
                  this.expandState.prepareMorphEntry(this.getUIContext(), true);
                });
                if (this.expandState.morphGeomReadyNow()) {
                  this.diagOverlayKicks = this.diagOverlayKicks + 1;
                  this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
                  Logger.info(PlaybackPage.logTag,
                    `RzdMorphOnAppear remeasured usable=${this.expandState.morphUsable} ` +
                    `stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive} ` +
                    `overlayP=${this.expandState.morphOverlayProgress().toFixed(3)}`);
                }
              }, 0);
            } else {
              // 闂佺绻戠划宀€鑺遍幎鑺ユ櫖婵﹩鍓濋崺宀勬煕濞嗘兛鎴︽儉閸涱垱灏庨梺鍨儐闂勫秹鏌ㄥ☉妯煎闁搞倖鍨堕幏鍛村即閻旂儤鈷曢梻浣瑰絻缁绘绱為崼銉﹀剭闁告洦鍨崑鎾诲焵椤掑嫬绀岄柡宥庡墰閻斿懐鈧灚婢樼€氬摜妲愬顓狀浄鐎广儱妫欓敍瀣偣瑜庢刊浠嬪焵椤戣法绐旈柛瀣噺缁鸿棄螖鐎ｎ剛顦梺鍛婂俯閸嬪顢欓埀顒€顪冮妶鍥ㄦ毈婵為棿鍗抽獮宥夊箻閼碱剛鎲归悗娈垮枓閸嬫捇鏌?
              //
              // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*婵烇絽娴傞崰姘跺极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欐總鏃傜箔閸涙潙绠璺猴工瑜扮娀姊婚崒銈呭箹闁诡喗顨婇弫宥囦沪閽樺－妤呮煟閵忥絽鍚圭紒顔哄姂瀵爼鎮㈤崜浣告櫓缂備焦鍔掗懗鍫曞礉瑜斿畷锝夊醇閻斿憡婢掓繛鎴炴尨閸嬫捇姊洪鈧粔鎾儓瀹ュ拋鍤曢柍褜鍓熸俊?*闂?
              //
              // ## 闁哄鏅滈悷锕€顭囬鐐茬闁糕剝蓱閺嗘粌鈽夐幘瑙勩€冪紒顔肩墛缁嬪﹪宕煎鍛崶闂?闂佺绻戞繛濠偽?闂佸搫鍟崕濂革綖閿旂偓灏庨柡澶婄仢閻?
              // 闂?`.onAppear()` 闂?*闂佺厧鎼崐濠氬磻閿濆洨妫?*闂佹悶鍎抽崑鐘绘儍?闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯鈺冩娴兼潙鎹?*闂佸憡甯掑Λ娆撳极椤曗偓閺屽苯顓奸崨顖滃**闂佸搫鍟﹢鍦姬閸愵亝鍠嗛柨鏇楀亾鐟滄澘鍊块弫?
              // 婵炴垶鎸哥粔纾嬨亹瑜斿?婵＄偑鍊楅弫璇差焽閹殿喗鍋栨い鎰剁到閳數鈧鍠掗崑?闂備緡鍙忕徊鑲╃博閺夋垟鏋庨幒鎶藉焵椤掆偓閸婁粙鍩€椤掆偓閼活垶宕ｈ濮婂顢橀姀鈩冨殤闁荤姳璀﹂崹鍫曞闯?`morphReset()` 婵炴潙鍚嬬喊宥嗕繆?
              // `morphSessionStarted` 濠电偞鎸搁幊搴∶?false闂佹寧绋戝濉祇rphStage` 闂佸憡鐟﹁摫闁?NONE闂佹寧绋戦ˇ顐﹀闯?
              // 婵炴垶鎸搁敃顏勵焽娴煎瓨鐒介柨婵嗗閸?`if` 闂佹眹鍔岀€氼亞鎮潏銊р枖妞ゅ繐瀚悘鏌ユ煙?*闂佸憡鑹鹃張顒€顪冮崒鐐茬煑婵☆垵妗ㄥù?* 闂?闂佽В鍋撻柦妯侯槸閻撳倿寮堕埡鍌滄噰闁?闂?**闂備焦褰冪粔鐢稿棘娴ｅ湱鈻旈柍褜鍓熼弻鍡楊吋閸涱垱缍岄悗娈垮枓閸嬫捇鏌涢弬璇插闁?*闂?
              //
              // ## 闂佸憡甯囬崐鏍х暤娓氣偓閺佸秹宕煎鍛啨闂備緡鍓氶幖顐ゆ?*缂備焦顨忛崗娑氱箔娓氣偓瀵爼鍩勯崘鈹箓鎮归幁鎺戝闁汇倕瀚粭鐔衡偓锝庡墯閻?*闂?
              //   闂?`isClosing` 闂佹眹鍨瑰畷顒勫矗瑜斿濠氼敇閵忊剝鍤戦柣鐘辫閸ㄦ娊鎮块崱娑欏剳闁绘洖鍊荤粈鍒瀋loseFullScreenPlayback()` 婵☆偓绲鹃悧鐘诲磿閹绢喗鏅鑸电〒楠?
              //   闂?`morphStage === LANDING` 闂佺偨鍎查弻锟犲焵?`morphLand()` **闂佸憡鐟禍婊冿耿椤忓牆绀傞柟鎯板Г閿涙棃鎮规笟顖氱仩缂?*闁荤偞鍑归崑澶愭儍?
              //      闂佹寧绋戦悧鍡涘矗韫囨搩鍟呴柕澹偓閺屻倖绻涢幘铏櫧闁稿缍侀弫宥咁潰濮濆崹aybackPage` 婵炴垶鎸堕崐鏇⑺?+ `Index:1088`闂佹寧绋戦ˇ顐﹀闯?闂?閻庤鐡曞鎾愁潩閿旇姤浜ゆ俊顖濇硶绾板啫霉閿濆洤校婵?闂佹眹鍔岀€氼喖霉婢跺濯寸€广儱绻掗獮?
              //   闂?闂?`lastCloseAtMs` 闂佸搫鍟悥鐓幬涚捄銊х幓?闂佺偨鍎查弻锟犲焵?**闁荤姵浜介崝宀勬偪閸曨剛鐟?*闂佺绻愯ぐ澶愭閳哄懏鏅柛顐秵濞煎矂姊洪銊у闂佸弶绮撳Λ鍐ㄢ枎閹般劌浜惧ù锝呮憸閹界喐绻涢崼銏℃毄婵炲牊鍨甸埢鏃堝Ω閳轰焦鐝甸梺鎸庣☉椤︻參鍩€?
              //      闂佸疇娉曟刊瀵哥箔?闂佸啿澧庢慨顓㈠箟?闂備緡鍠涙慨銈呂?*闁诲骸婀遍崑妯兼閵壯傛勃闁逞屽墴閺?*闂佹眹鍔岀€氬摜妲愭导鏉戞闁哄娉曢弶钘夈€掑顒夊剳婵?`aboutToAppear` 婵炴潙鍚嬬喊宥嗕繆?`isClosing`
              //         **闂佸搫鍟版慨闈涱焽椤栨稓顩烽柤鍝ユ暩椤忔悂鏌?false**闂佹寧绋戦悾鐠祇rphReset()` 闂佸憡鐟ラ悧濠冧繆?`morphStage` 閻?NONE
              //         闂?闂佺绻戞繛濠偽涚€涙ɑ濯存繛鍡樺姇閻ㄩ箖鏌﹂埀顒勬寠婢跺鍚梺鍝勫€瑰姗€鎮块崟顒傜懝閻庯絺鏅濋悷鎰版煛?*婵炴垶鎸堕崐鏍ь焽椤栫偛绀傞柕濞у應鍋?* 闂?闂婎偄娲ら幊姗€濡磋箛娑欘棃?闂佹娊顤傚鍧楀焵?
              //      闂佸疇娉曟刊瀵哥箔?闂?闂佹眹鍔岀€氼剟宕幘缁樺€?*闂佸憡鐟禍婵嗭耿?* `closeFullScreenPlayback()` 婵☆偓绲鹃悧鐘诲磿鐎涙鈻旈柍褜鍓氬鍕礋閸撲胶顦╂繛鎴炴尪閸婃洟藝閳哄懎绠ｉ柟閭﹀墻閸ょ娀鏌?
              //         婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏂垮悑閻ㄦ垿鏌￠崟闈涚仭缂佹墎鍓濈粋宥夊幢濞戞ü绨兼繛鎴炴惄娴滄粓宕幘缁樺€锋鐐茬氨閸嬫挻绗熼埀顒€螞椤掑嫬绠掗柟鐑樺灣濞?闂?闂佽皫鍡椥撻柡浣稿悑缁嬪鍩€椤掍焦濮滄い鏇炴缁€鍡涙煏?
              const sinceCloseMs: number =
                PlaybackPage.lastCloseAtMs > 0 ? Date.now() - PlaybackPage.lastCloseAtMs : -1;
              if (this.isClosing || this.expandState.morphStage === MorphStage.LANDING ||
                (sinceCloseMs >= 0 && sinceCloseMs < PlaybackPage.CLOSE_WINDOW_MS)) {
                this.diagAppearBranch = 'skipClose';
                PlaybackPage.ev('AP', `skipClose since=${sinceCloseMs}`);
                Logger.info(PlaybackPage.logTag,
                  `RzdMorphOnAppear skip intro: closing. isClosing=${this.isClosing} ` +
                  `stage=${this.expandState.morphStage} sinceClose=${sinceCloseMs}ms ` +
                  `p=${this.expandState.morphP.toFixed(3)}`);
                // 闂?闂?婵炴垶鎸哥粔鐢稿箰闁秴绀夐柕濞у嫭姣?婵炴垶鏌ㄩ鍛此囩紒妯讳氦婵☆垵娅ｇ粻鎴濐渻?*闂佺娉涢敃銈夊吹閹寸偞濯撮柡鍥ｅ墲閸庝即鎮?*闂?
                //   闂佸憡鐔粻鎴﹀垂椤栨壕鍋撻崷顓熷殌婵炲懏甯″畷锝夘敍濠靛棗骞嬮梺绋款儐缁苯锕㈤鍡樺仏妞ゆ兊銈呭箑闂佸搫鍋嗛崢鎯р枔閹寸偟鈻旀い鎾卞灪閿?scale闂佹寧绋戦悧蹇涘极閵堝绠ｉ梺鍨儏琚氶梺?闂佺厧鍟块張顒€鈻嶅▎鎾崇煑妞ゅ繐瀚埛鏍р槈閹绢垰浜鹃梺?闂佸憡鑹鹃張顒傝姳椤曗偓閺佸秵寰勯崼姘壕?
                this.expandState.morphSettleOpen();
                this.introPaintReady = true;
              } else {
                this.diagAppearBranch = 'intro';
                PlaybackPage.ev('INTR', `sinceClose=${sinceCloseMs}`);
                this.playExpandIntro();
              }
            }
          })
          .onDisAppear(() => {
            // 闂佸疇妫勯幊澶娢?2026-10-16闂?*闂佺绻愰悧鍡氥亹?闂佸憡顨嗛悺鏇灻归崶顒佺劷闁挎繂瀚閬嶆煕?闂?isAlive 闂婎偄娴傞崑鍡涘矗?*闂?
            //   婵炴垶鎸搁澶婎焽娴煎瓨鐒介柨婵嗙墱閺€钘壝归崗鑲╊暡濠?`isAlive` 闂佸憡鑹鹃張顒勵敆閻愮數纾?false闂佹寧绋戦惌渚€鍩€椤掆偓閺堫剙锕㈡导鏉戠倞闁绘劕澧庡▓鍫曟⒑閹绘帞鐏辨繛鍫熷灴瀹曟岸濡堕崱妤冦偊闂?*閻庣偣鍊涢崺鏍ь渻閸屾稓鈻旈柍褜鍓熼獮?*闁荤姷鍎ら崹鐟扳枔?闂佺偨鍎查弻锟犲焵?
            //   闂佺儵鏅涢悺銊ф暜鐎靛憡瀚氶悹鍥皺閹界喐绻涢崼銏℃毄婵炲牊鍨归幏鐘测攽閸ヮ煈鏀抽柡澶嗘櫆缁繘顢氭导鏉戠?false 闂?闂佸憡甯囬崐鏍х暤娓氣偓閺?`!isAlive` 闂備緡鍙忕徊鎯ь焽椤栫偛绠掗柟鐑樻⒐閸?
            //   闂?閻庣偣鍊涢崺鏍ь渻閸岀偞鐒介柨婵嗩槷婢规洟姊婚崒妯哄闁烩剝鍨剁粋宥嗘償閵忋垺鈷曢梺鍛婃⒒婵妲愬▎鎰氦婵炲棙鍔﹂崝鈧梺鍝勫閸垳绮崒娑氣枖闁逞屽墴閹?`morphUsable` 闂備緡鍙忕紞浣圭妤ｅ啯鈷掗柕濞у嫮鏆犻梺鍛婅壘閻偐鎮锔界叆婵炲棙甯╅崵鏍煥?
            //     **闂佸憡甯囬崐鏍х暤娴ｇ儤瀚氶悹鍥ㄥ絻閻撳倿鏌ｉ妸銉ヮ仾婵?闁荤偞鍑归崑澶愬吹濠婂喚鍟呴弶鍫涘妽閺嗩參寮堕埡浣圭煑缂佺媴缍佸畷?闂佹眹鍔岀€氼剟鍩€?*闂佹寧绋戦ˇ顓㈠焵?
            const wasAlive: boolean = this.isAlive;
            this.isAlive = false;
            PlaybackPage.ev('DIS', `wasAlive=${wasAlive ? 1 : 0} show=${this.state.isShowPlay ? 1 : 0}`);
            // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佸憡甯炴慨鐢垫暜閳ь剟寮堕埡鍌滄噰闁革絿鍏橀弻鍥晲閸涱厾绋忛梺鍛婅壘閺堫剟顢楅悙鐑樺剭?`state.isShowPlay = false`**闂佹寧绋戦¨鈧紒?
            //   闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鏌涢幇顓犳噮婵?`this.state.isShowPlay = false;`闂侀潧妫楅崐鎼佹偩閻樿鍙婃い鏍ㄧ懅椤忓崬鈽?*闂佺厧鎼崐濠氬磻閿濆洨妫?*闂佹悶鍎抽崑鐘绘儍閻斿吋鐓傜€光偓閳ь剙鈻撻幋锕€绀冩繛鍡楃箰瀵娊鏌?
            //   闂?`isShowPlay` 闂?*婵犮垻鎳撻崯鍧楁儑閹殿喗宕夋い鏍ㄧ矋閺嗙娀鏌ｉ妸銉ヮ伃闁崇懓绉瑰畷婵嬪Ω閿斿墽鍩?*闂佹寧绋戝濉坣dex.@Monitor('appState.isShowPlay')`
            //   闂?`popPlayerRoute()`闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婇鎮柆宥嗗殌闁告侗鍠楅崕妤呮煕閿斿搫濡虹紒鏂款嚟閹秆勵槹鎼淬垻鏆犻梺鍛婅壘鐎涒晠鎮樻径鎰強妞ゆ牗绻勭粻鐟扳槈閹垮啩绨婚柤闀愬嵆閹晝鎷嬮崷顓犵崶
            // ```
            //   闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佹寧绋掗懝楣冩晬閹炬湹娌柛灞剧☉鎯?isShowPlay 缂?true 闂?闂佽浜介崝宀勫矗閸℃稑绠绘い鎾跺枑閺夌懓顪冮妶鍕シ闁活參绠栭幃?
            //   闂佸憡鑹炬總鏃傜博鐎靛憡鏆?婵炴垶鎸搁鍕博鐎靛憡鏆滅憸婵堟?*闂佸搫鍞查崟顒€鍟婇梺琛″亾濡わ絽鍟ㄩ埀顒€顦遍埀顒€婀遍崑妯兼?*闂佹寧绋戦悧濠囧垂閵娾晛绀嗛柛鈩兩戦弳婊堟⒑閹绘帞孝缂傚倹鎹囬幆鍐礋椤栨矮绨兼繛鎴炴惄娴滐絾淇婇銏″€烽柣褍鎽滅粈鍡涙偡濞嗘瑧鐣辩憸?onDisAppear
            //   闂?闁诲海鎳撻崯顖涗繆?isShowPlay 闂佸憡鍔栭悷銉ッ?false
            //   闂?婵犮垻鎳撻崯鍧楁儑閹殿喚鍗氶悗锝庝簻閻?popPlayerRoute() 闂?**闂佸憡甯楃喊宥嗘櫠閿曗偓椤曪綁鍩€椤掑嫭鍎嶉柛鏇ㄥ墯鐏忥繝鏌￠埀顒併偅閸愶腹鍋撴径灞惧仏妞ゆ劑鍨奸崜銊╂煙?/ 闂佸憡鏌ｉ崝搴ㄥ极閸撗勫仏妞ゆ劧绲界粭宀勬煛?*
            // ```
            //   闂佸疇娉曟刊瀵哥箔?闂佸吋婢樻總鏃傜箔閺嶃劍浜ゆ繛鍡樺姈绗?*濡ょ姷鍋涢崐濠氭偤閹达箑绠戠憸宥咁嚕閼恒儳顩查柛鈩冪懄閻?*婵炴垶鎸撮崑鎾愁熆鐠哄搫顏电紒杈ㄦ緲閳绘棃濡搁埡浣圭彽 `:2709` 闂佺厧顨庢禍婊呮崲娓氣偓瀹曟ê鈻庨幋鐐电シ
            //     闂侀潧妫楅悾鐠眘ShowPlay` 闂佸吋鐪归崕閬嶅礄閿熺姴鍙?false闂佹寧绋戦悾鐟籑onitor` 婵炴垶鎸哥粔宕囨娴煎瓨鐓傜€广儱鎷嬪Σ濠氭煕閺傝濡虹紓宥嗘婵℃潙顓兼担鎻掍壕闁哄倽銆€閸嬫捇寮崼婵呯凹闂?闂佺绻戞繛濠偽涢幘顔界叄闁硅鍔楅悢?闂佹眹鍔岀€氼垶顢氶姀锛勨枙濠㈣泛鐗冮崑?
            //     闂佺绻戞繛濠偽涢幘顔界叄闁硅鍔楅悢鍛槈?`isShowPlay = false` 闂?*婵炴垶鎸搁ˇ顖炈囬埡鍛骇闁告劑鍔夐弸鍡涙偣娴ｇ鈷旈柣銈呮閹?*闂佹寧绋戦惌鍌炲礂濮椻偓瀹?
            //     `closeFullScreenPlayback()` 闂備焦褰冪悮顐﹀焵椤戣法绐旈柛蹇旓耿瀹曠兘濡搁敂璇插Η缂佺虎鍙庨崰姘枔閹达箑绫嶉悹鍝勬惈閻撴繈鏌?
            //       閻?`:2712` 闂佸搫鍟版繛鈧柡浣割儔閹瑧鎲撮崟顒婄礊闂備緡鍋€閸嬫捇鏌￠埀?
            //       閻?`:2729` 濠殿喗绻愮徊浠嬫偉閸洖缁╅柟顖滃瀹曟娊鎮跺☉鏍у姦婵☆偄娼″銊ф崉閾忕懓鏆￠梺琛″亾?
            //       閻?`:2738` "濠电偛澶囬崜婵嗭耿娓氣偓瀹曪綁顢涢悙瀛樼ギ闂佸憡鍨规慨宕囩礊瀹ュ鍎庨悗娑櫭径宥夋煕韫囨柨鈻曟俊?闂備緡鍋€閸嬫捇鏌涢弽銊у闁?
            //   闂?闂佸搫鐗滈崜娆撍?*婵炴垶鎸哥粔鐟般€掗崜浣瑰暫?*闂佸憡鍔曠粔鎾疮閹惧鈻旈柍褜鍓欓埢搴ㄥ煡閸涱垰鑰块梺浼欑稻閻熝冾焽閸愵喖鐭楁い蹇撳暟缁愭鎮?闂佺懓鐏氶幐鍝ユ?闁荤偞鍑归崑澶愬吹濠婂喚鍟呴弶鍫亽閸ゆ牠鏌涢幒瀣偓鏍垂?闂佺绻戞繛濠偽?闂?
            //   闂佸疇娉曟刊瀵哥箔?闂佸吋鐪归崕閬嶅箺閵忊€崇窞闁冲搫鍟崺鍌炴⒒閸ワ絽浜鹃柣鐔告磻缁€渚€宕㈢憴鍕劅闁哄浂浜炵粈鍕€掑顒夊剰妞?Hard exit 闁荤姍鍥舵殥缂佹顦靛畷姘紣娴ｈ櫣鎲梻鍌氱墱濠⑩偓缂佹ぞ鐒﹀鍕礋閸撲胶顦梺?
            //      **闂婎偄娲ら幊姗€濡?*闂佺绻愰悧鍡涘垂?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滃ù锝呭暟閻斿懘鏌ｉ姀锝勫惈闁炽儲顭囬埀顒€婀遍崑娑㈠礄閿涘嫮纾奸煫鍥ф捣閻熸繈鏌涢敂鍝勫闁绘牓鍊濋弻?闂佸憡鍔曠粔鎾疮?闂佺偨鍎查弻锟犲焵?闂佸憡鐔粻鎴﹀垂椤栫偛鐭楅柛顐ゅ枑绗戦柡澶嗘櫆閻熴倝鏌屽鍡愪汗闁靛繈鍨圭瑧闂?
            //      闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梤oute: push player` 婵?`route: remove player at index=` 闂佹眹鍔岀€氼厼顪冮崒娑欏劅闊洤顑傞崑?
            //
            // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺鍩栫湁闁煎灚鍨垮畷鎴濐潩椤撶姰鈧﹪鏌ㄥ☉娆愮殤闁哄棌鍋撴繛鎴炴尭椤戝懘鎮鹃妸鈺佺闁靛ě鍛ч梺鎸庣☉婵傛梻寰婇崜褏纾兼繛鍡楃箳閺嗗﹤鈽夐幘顖氫壕婵?闂佸憡鐟禍婊冿耿椤忓懐鈻旈悗锝庝簻闁伴亶鏌￠崘鈺佸姸鐞氭繈鏌?闂佹眹鍔岀€氼厼顭囬娑氼浄?*闂佹寧绋戦¨鈧紒?
            //   闂佺儵鏅涢悺銊ф暜閹绢喖绀嗛柣妯哄暱缁旀挳鎮楅悷鏉挎殲婵犫偓娴ｈ妲归幖娣妽閻?闂佺偨鍎查弻锟犲焵?`Hard exit`闂佹寧绋戦悧鍛閵夛缚绻嗛柛灞剧矒閸忓洨绱撴担鍝勬瀾濠碉紕顭堣灒闁斥晛鍟犻崑鎾存媴鐟欏嫭顔掓繛鎴炴惄娴滄繈寮ぐ鎺戠濠㈣泛鐗冮崑鎾存媴閻熸壆浠愰梺鍛婂俯閸嬪棗鈻撻幋婢喖鍨鹃搹顐淮闂佺儵鏅涢悺銊ф暜?
            //   `popPath`闂佹寧绋戦ˇ鏉款渻?*濠电偛澶囬崜婵嗭耿娴ｅ湱顩烽悹浣哥－缁夊灝霉?*婵炴潙鍚嬬喊宥嗕繆閸涘﹥浜ら柧姘€荤粙鎴︽煛婢跺棌鍋撻崣澶婃敪闁哄鏅滈敋婵炲弶鐗犲鍫曞Ψ閿濆倸浜鹃柛灞剧☉椤ｆ彃霉閻橆喖鍔欑紒妤€顦靛畷姘舵偑閸涱垳顦梺琛″亾閻熸瑥瀚悘?**闂佸憡鐟禍婊冿耿椤忓棙鍏滄い鏃€顑欓崥?
            //   闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈梻鍫熺☉閸ゆ帞绱撴担鍝ョ缂佹顦靛畷鐑藉Ω閵娧呭敶闂佹眹鍨兼ご鎼佹偉閵堝鐓?*闂佸搫鍟抽崺鏍ㄦ櫠閻樿绀?闂佹寧绋戦懟顖炴嚐閻斿摜鈻?*闂佽浜介崝蹇曟崲濠婂嫮鈻旈柍褜鍓熼獮?*闂佹寧绋戦悧鎰邦敊閳ь剟鏌涘顒冨闁硅埖宀稿畷姗€宕ㄩ鐐额唹闂佺厧鐤囧Λ鍕亹閸岀偞鍋ㄩ柣鏃傚劋閻?
            //   push 闂佺绻愰悧鎰板箚閵堝鍐€闁割偒鍓涚粈鍡涙煥?
            //     閻?闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佹寧绋掑畝鎼佸磻閸涱喚鈻旈柍褜鍓熼獮蹇擃吋閸℃瑥鐏查梻?*閻庡湱顭堝璺猴耿?*闂佸湱铏庨崢浠嬪棘娴ｅ箍浜?闂?婵炴垶鎸哥粔鎾疮?闂?婵炴垶鎸哥粔宕囨閹殿喗鍋栨い鎰╁労閸ゆ牠鏌涢幒瀣偓鏍垂濮樿泛绀傞柟鎯板Г閿?闂?
            //     閻?缂備緡鍨靛畷鐢靛垝閻戞ɑ浜ら柡鍌涘缁€鈧?/ 闂佺绻戞繛濠偽涢幘顔肩濠㈣埖鍔栫亸锕傛煥濞戞瑥鍝洪柛瀣噺缁嬪寰勬繝搴⑿熼梺鍝勵槸閸燁偊鍩㈡径鎰€烽柣鐔告緲閸ゆ帞绱撴担鍝ョ闁哥喐鎸诲濠氬炊妞嬪海顦ーisShowPlay` 閻庡湱顭堝璺何?false闂?
            //       闂備焦褰冪粔鎾囬弻銉ョ婵炲棙鍔栫瑧濡ょ姷鍋涢崐濠氭偤閹达附鍎嶉柛鏇ㄥ幐閺佸嫰鏌熼崹顔拘＄紓宥嗘閺佸秵寰勯崱妯碱唵
            //     閻?Hard exit 婵炴垶鎸诲褰掓儉閸涱喚顩查柛婵嗗閺呮悂鏌ㄥ☉娆忓摵闁稿鎳忕粙澶愬焵椤掑嫬绠€广儱妫涢崹浠嬫⒑閹绘帗婀伴柣銉ユ嚇瀵灚寰勭€ｎ偄鍟婇梺琛″亾濡わ絽鍟ㄩ埀?闂?闂?false 闂?婵犮垻鎳撻崯鍧楁儑娴兼潙缁╅悹楦挎閸?闂?
            setTimeout((): void => {
              if (this.closeInstance !== PlaybackPage.instanceSerial || this.playerRouteStillPushed()) {
                Logger.info(PlaybackPage.logTag,
                  'RzdMorphOnDisappear keep isShowPlay (player route still on the stack)');
                return;
              }
              if (!this.state.isShowPlay) {
                return;
              }
              Logger.warn(PlaybackPage.logTag,
                'RzdMorphOnDisappear fallback: player route gone but isShowPlay still true 闂?release it');
              this.state.isShowPlay = false;
            }, 0);
            // 婵炴垶鎸搁鍕博閺夋垟鏋庨柍鈺佸暙閳數鈧鍠掗崑鎾绘⒑閹绘帞校闁哄苯锕﹂幐?闂佺绻愰悧鎾诲闯濞差亜绀冪€广儱娲ㄧ槐?闂佹眹鍔岀€氫即濡存惔銏″劅闊洢鍎崇粣妤呮煙鐠虹尨鍔熺紒顕呭灦瀹曟岸宕奸弴鐕傜礉婵炴垶姊婚崰搴ㄥ矗瑜斿畷鍫曟倷閹绘帞顔?
            this.introPaintReady = false;
            // 闂?婵＄偑鍊楅弫璇差焽娴兼潙纭€婵繂鏈粊浼存煛閸愵厽纭炬い锕€寮堕幏?闁荤姾娅ｉ崰鎰櫠濠婂嫬顕辨慨妯虹－濡?闂佹眹鍔岀€氼亞鎮潏銊р枖妞ゅ繐鎳愰崹濂告偣娴ｈ棄鐒介柍?
            //   `pullDragging` / `morphDrive` 闂佸憡鍔曢崯鍧楁偩妤ｅ啯鍊烽柣鐔告緲濮ｅ﹪鏌熼崹顐ｅ碍缂佽鲸鍨垮顕€骞嗛柇锔界煑婵炴垶鎸哥粔鐑姐€呴敃鍌氱；婵﹩鍓濋崺宀勬煕濞嗘兎顏堝垂閸偅鍙忛悗锝庝簻椤曆囨煥?
            //   闂佸憡鐟禍锝夈€呴敃鍌氬珘濠㈣泛顦遍閬嶅级閻戝棗鏋熷褎绮撳畷婵嬪箰鎼达絾鈷曢柣鐘欏嫭绶查柛鈺佺焸瀵劎鎹勯搹鐟版殹闂佹寧绋戦悧鎰帮綖閿旀儳瀵查柤濮愬€楅崺鐘绘煙闊彃鐏遍柧鏂款儔婵″瓨鎷呴悿顖氬箑闂備緡鍋呴弻銊ョ暤韫囨梹濮滃┑顔藉姀閸嬫挻鎷呯悰鈾€鍋撻弽顓炵闁规儼濮ら敍鏃堟煃閵夘垵顓虹紒杈ㄦ皑閳ь剛鎳撻崯顐㈩潩閵婏箑顕辨慨姗嗗幘閺嗘瑩鏌ｉ敐鍡欐嚂缂?
            //   濠电偛鐗嗛鍥汲閳ь剟鏌?(true, FINGER) 闂佸搫鍟晶搴ㄥ磻閿濆绀勭紓浣姑埅鐢碘偓娈垮枓閸嬫挸霉?*濠殿喗蓱閻℃洜鎹㈠▎鎴炲磯閻庡湱濮风粻鏍喐閼割剙鐏╃憸?*闂?
            //   闂備緡鍋€閸嬫捇鏌涢弽銊у闁?`collapseProgress` 闂備緡鍙忕徊浠嬨€冨鍫熷殌濞达絿顭堣闂佹椿婢€缁鳖喚妲愬▎鎾村仺闁靛绠戦悡鏇㈡倵閸︻厼浠︾紒浣规尦閺?闂佺粯鍔楅幊鎾诲吹?闁哄鏅滈弻銊ッ洪弽顓熷仺闁靛ě鍕殸闁哄鏅滆摫婵℃彃鎲＄粙濠勨偓锝庝簻椤ゅ懘鏌ｉ妸銉ヮ仼濠殿喒鏅犻幃?闂佹寧绋戦ˇ顓㈠焵?
            this.expandState.pullDragging = false;
            this.expandState.morphDrive = MorphDrive.NONE;
            // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*"闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱濠电偛澶囬崜婵嗭耿娓氣偓瀹曟繈濡歌閺?闂佹眹鍔岀€氼厾鑺遍钘夌窞闁哄鍨堕惃鎴︽煕閿斿搫濮€缂佺粯鐗犻弻?*闂佹寧绋戦¨鈧紒?
            //   婵炴垶鎸搁澶婎焽娴煎瓨鐒介柨婵嗘噹缂嶆牠鏌涘Ο鐓庢瀾婵炶偐鏁诲?*闂佸搫鍟版慨闈涱焽椤栨稓顩?*闂?`morphReset()`闂侀潧妫楅崐浠嬪焵?`morphReset()` 婵?
            //   **`morphGen++` 婵?`morphUsable = false` 婵?`morphSessionStarted = false`**闂?
            //   闂傚倸鍋嗛崳锝夈€傛禒瀣嵍闁靛鍊楅懝楣冩煥?*闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佸搫鍟抽鎰?闂佸搫鍊绘晶妤呭箰闁秴缁╁Δ锝呭暔閳ь剙顦甸幆?`onAppear`"婵?闂佸搫鍞查崶銉㈠亾婢舵劖顥堥柕蹇曞Х閺夎棄銆掑顒夊剳婵?`onDisappear`"
            //   闂佸憡鍨规慨宕囩不椤曗偓瀹曘儳浠﹂懞銉ヮ潛闂佸憡鐟﹂崹褰掑极?* 闂?闁哄鏅滈悷銈囩博閹绢喖鐭楅柕澶堝€楃粣妤呮煙?*闂佸憡甯楅懝楣冨垂娴煎瓨鍋ㄩ柛妤冨剳缁憋箓鎮橀悙鎻掆偓鍝ョ磽閹惧墎鍗氶悗锝庝簵閸嬨劑鏌ｉ妸銉ヮ仾闁哄苯锕ョ粙澶愬焵椤掍焦濮滄い鏃囧閸╁矂鏌涘▎鎯疯偐妲愰幍顔藉珰?*婵炴垶鎸撮崑鎾绘偣瑜旈弨杈╃博婵犳艾绠?
            //   闂?`morphUsable` 濠殿喗蓱閻℃洜鎹㈠▎鎰枖闁告繂瀚ù?闂?闁诲骸婀遍幊鎾斥枍閹烘纾绘繝濠傚暞闊剟鏌熼鐔风闁?闂?**闂佺厧鍟块張顒€鈻嶅▎鎾虫瀬闁哄鍨瑰宀勬煏閸℃洜鍔嶉柣銉ユ嚇瀵灚寰勬繝鍌傛鏌?*闂?
            //
            //   闂?闂佸憡姊绘慨宕囩博閹绢喗鐒奸柟鍓х帛閿涘矂鏌?*闂佽浜介崝蹇曟崲濠婂嫮鈻旈柍褜鍓熼獮蹇擃吋閸涱厽娅冨┑鐐存尭閹锋垹妲愬┑瀣祦闁哄牏鏁搁悷?闂佸吋鐪归崕鐢稿磻閸涱喚鈻旈柍褜鍓熼獮蹇擃吋閸涱厼娈ョ紓鍌欑缁绘垵锕㈡担璇ユ椽鎳￠妶鍡欑シ闂佹眹鍔岀€氼亞妲愰幍顔藉珰婵犻潧妫欓惃鎴︽偣閸濆嫮鏋冪紒?**闂?
            //     闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佸憡甯囬崐鏍х暤娴ｇ儤濯奸柕蹇婃閸斺偓闂佹寧绋掗悺鐚皁rphUsable` 闂?`morphSessionOughtToLive()`**闂佹寧绋戦¨鈧紒?
            //       闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鏌?`morphUsable`闂佹寧绋戦悧鍡涘吹閹寸偞濯撮柡鍥╁仜閸ゆ帡鎮樿箛姘惈闁告閰ｉ弫宥嗗緞閸″繐浜鹃柡鍌濄€€閸?*闂侀潻璐熼崝搴ㄥ磻閿濆绀勯柡鍕箳缁犲綊鏌℃竟婧垮€楅悢鍛槈閹剧宸ラ柣锝囧Ь缁犳盯宕ㄩ姘佹繛鎴炴尭閹碱偅绂?*闂?
            //       闁荤姍鍥ㄦ暠濠⒀勭矋缁嬪鎯旈姀鐘垫Ц闁哄鍋樼划娆撳磻閸涱喚鈻旈柍褜鍓熷畷姘舵嚒閵堝洨鐓夐梺缁樺姇缂嶅﹪寮€ｎ喗鍊风痪顓炴噽缁犻攱绻涘畝瀣瘈闁革絾妞藉畷姘辨暜椤斿墽顦甡morphUsable` 闁诲繐绻楁ご绋课?false
            //       闂?闁哄鏅滈悷鈺傜妤ｅ啯鈷?*濠殿喗蓱閻℃洜鎹㈠▎蹇ｅ殨闁逞屽墴閹牓鍩€?* 闂?婵炴垶鎸稿锕傦綖閿曞倸绀嗛柣妯哄暱缁旀挳鏌ｉ妸銉ヮ伃闁稿鎳樺畷锝夊Ψ閿旀枻楠忛梺鍝勵槴閳ь剙寮堕?`morphReset()` 缂備焦绋戦ˇ顕€鎮抽鐐参?
            //       闂?闂佸搫鐗滈崜婵嬫偪閸℃瑧纾肩憸蹇涙偨閼姐倖濯奸柕蹇婃閸斺偓闂佹寧绋掗悺鐚皁rphSessionStarted`闂佹寧绋戦悧鍛箔閸屾稓鈻旈柍褜鍓熼幃褔宕奸鍌滎槴婵?`playerRouteStillPushed()`
            //         闂佹寧绋戦悧鍛箔閸屾稓鈻斿┑鐘辫兌椤忛亶鏌ｅΔ鈧悧鐐垫濮樿埖鐒鹃柟瀛樺笧閻熸繈鎮楅悽鍨仧缂佽鲸绻堥幃鍫曞幢濞嗘劖娈搁柣?{@link morphSessionOughtToLive} 闂佹眹鍔岀€氼剟顢氶鈧幃陇顦堕柕鍡楀暣婵?
            //       闂佸疇娉曟刊瀵哥箔?婵?`aboutToDisappear()` **闂婎偄娲ら幊姗€濡磋箛娑樿Е閻忕偠鍋愰鍗炩槈閹垮啩绨婚柛銊ょ矙楠?*闂佹寧绋戦悧鍡涘箖閹惧鈻旈柍褜鍓濋妵鎰板閵忕姌锕傛煥濞戞ê顨欑紒妤€顦遍幏瀣矙閹稿骸鈧鏌涢幇顓犳噥缂佹柨鐡ㄧ缓钘壩旂€ｎ剛顦梺?
            setTimeout((): void => {
              if (this.closeInstance !== PlaybackPage.instanceSerial ||
                (this.closeToken !== 0 && this.closeToken === PlaybackPage.closeOwner) ||
                this.morphSessionOughtToLive(wasAlive)) {
                Logger.info(PlaybackPage.logTag,
                  'RzdMorphOnDisappear keep session (morphSessionOughtToLive)');
                return;
              }
              Logger.info(PlaybackPage.logTag, 'RzdMorphOnDisappear reset (session no longer needed)');
              this.expandState.morphReset();
            }, 0);
            this.stopChromeAutoHide();
            this.imageColorJobSeq++;
            this.releaseBackgroundCoverIfPixelMap();
            // 闂?2026-10-15闂佹寧绋掑銊х礊婢舵劕鍐€闁艰婢橀崜褰掓煛閸滀礁鐏ｆ繛鍫熷灥閳瑰啴骞囬鍡櫺㈤梺鎼炲劚瑜扮偟寮ч崘顓滀汗闁圭儤鎸婚幏鍗烆渻閵堝懐浠涢悗鍨瀵?闂?闂備緡鍋€閸嬫捇鏌涢敃鈧幖顐ゆ崲閳ь剙顪冮妶鍫敽缂佹柨顕幐褔鎮滈挊澶嬬彽闂佽　鍋?
            //   闂佹寧绋戦悧鍡涘箚娓氣偓瀹曟艾鈻庨幇顔叫栧┑鐐叉灤閵堝洨顔掗梺鍛婂灩閸庛倝骞愰柆宥呯哗濡わ絽鍟ㄩ埀顒€顦甸弻鍫ュ箣閹烘梻鐛ュ┑鐘虫礀缁诲绮╅弶鎴殨?64闁?4 闂?PixelMap闂佹寧绋戦ˇ顓㈠焵?
            this.releasePixelMapQuiet(this.meshSrc);
            this.meshSrc = undefined;
            // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂?*闁荤偞绋忛崕鑼?*闂佹寧绋戦¨鈧紒杈╂珬闁?40` 闂佸搫鍊瑰妯绘叏閻愮儤鍎?闁诲海鎳撻ˇ闈涱焽閵堝洨鐜绘俊銈傚亾鐟滅増绋戦銉╁川閸忣偄顦辩槐鏃堝箣閻愰潧顥曞┑?婵炴垶姊婚崰搴ｇ礊婵犲洤瀚夋い鎺戝閳ь剙顦甸獮鎰媴鐟欏嫮鐣?闂佺偨鍎查弻锟犲焵?
            //   闁诲海鎳撻崯顐耿椤忓棛鐜绘俊銈傚亾鐟滅増鐩鐢告偄瀹勭増鏆ラ梺鍛婄懐娴滄繂危?*闂佸湱顭堥崐璇差焽?*闂佹寧绋戝濉竐ndingMeshPm`闂佹寧绋戦¨鈧紒杈ㄧ箞閹崇喖濡烽妸褏顔愬┑鐐茬墢閺佸宕抽柨瀣ㄤ簻闁汇垹鎲″銊╂倶韫囨稐鎲鹃柍褜鍏橀崑鎾绘煕閿曚焦銆冪紒顭掔節閺?
            //   婵炴垶鎸搁敃顏勵焽娴煎瓨鐒介柨婵嗘噹缂嶆牠鏌涘▎妯归偗闁革絾鎸冲?`meshSrc`闂?*闂佸湱顭堥崐璇差焽閸愵喗鍎嶉柛鏇ㄥ枤缁犲湱鈧鍠氭慨鏉戭潩閵娿儺娼╂慨婵嗙灱缁犲吋绻濋弴鐐电閻㈩垪鍋?*闂佹寧绋戦悧鍡涘箖閹惧墎灏甸悹鍥ㄥ絻閺佸爼鎮楀☉娅亜鐣锋總鍛婂仺闁绘柨鍚嬮敍鏍涢悧鍫叕缂?
            //   婵?闁?37 闂備緡鍙忕徊濂告煂?闂婎偄娴傞崑鍡涘矗?PixelMap 濠电姵娲栫换鎴犵博?闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳閸╁矂鏌ｅΟ娆惧晣缂佽鲸宀告俊?
            this.releasePixelMapQuiet(this.pendingMeshPm);
            this.pendingMeshPm = undefined;
            this.imageLabel = $r('app.media.ic_avatar1');
            // 婵＄偑鍊楅弫璇差焽娴煎瓨鐒婚柍褜鍓熷畷鐑藉传閸曨亞涓嶉梺鐟版惈椤﹀崬顭囬崘顔藉殞闁圭粯甯楅悵銈夋煕閺傝濡块柡渚€绠栭弫宥咁潩椤撶喐顔掗柣蹇曞仜缁绘垹绮婇敃鍌氱濠㈣泛顑嗙瑧闂佸綊鏅查懗鍫曟偨婵犳碍鍎?GPU 閻庢鍠掗崑鎾绘⒑鎼存挸浜鹃梺鎸庣☉閼活垶骞冨Δ鍛煑濡鑳堕悷婵嬫偣閸ャ儱鍔ゆ繛鍛囧洦鍤€婵°倕鍟弳?
            const wu = WindowUtil.getInstance();
            wu.applyPlaybackWindowChrome(false, false);
            Logger.info('RzdPlayerRoute', 'leave overlay: window layout unchanged');
            wu.applyPcPlaybackDecorButtonStyle(false);
          })

          // 闂佸疇妫勯幊澶娢?A2闂佹寧绋掔喊宥夋偤閺囩姵瀚氱€广儱顦埀顒€顦伴妵鍕醇閺囩偛濮ら梺姹囧妼鐎氥劑鍩€椤掆偓閼活垶鎯冨┑瀣棃?+ 濠殿喗绻傞懟顖炲箖閺囥垹违鐎广儱妫滈惂渚€鎮橀悙鎻掆偓鍫曞焵?
          //   闂佽　鍋撻柟顖嗗嫯鍚?Stack C 闂?*闂佸搫鐗冮崑鎾绘煕濮橆剛鍑圭紒鏂跨摠缁嬪顢旈崟闈涘Ψ闁?*闂佹寧绋掗悺鐚祇sition` 闂?闂佺儵鏅濋…鍫ヮ敋椤曗偓閹儵宕滄担铏圭厑婵炲濮惧▔娑欑▕韫囨梻鈻斿┑鐘叉媼濞硷繝鏌ｉ妸銉ヮ伀缂侇噣顥撻埀顒傛暩閹虫捇鎮鹃悙顒佸?闂?
          //   闂佸吋婢橀張顒€锕㈤幍顔绘勃闁稿本绮嶉悾杈┾偓褰掓交缂傛氨绮崒婊勫枂闁圭儤鍨堕惃鎴︽煛閸曢潧鐏ｉ柣娑栧劦瀹曪綁鏁愰崨顓熸灳闂佺粯鍔楀▍銏㈡濞嗘劗鈻?`MorphCoverBridge` 闂佸憡鑹鹃惉鍏碱殽閸ヮ剙瑙﹂悘鐐舵缂嶆挾鈧灚婢樼€氬摜妲愬璺虹劷?
          //   `PlayerExpandState.lyricMorph()` 婵炲瓨鍤庨崐鏇㈠吹椤撱垺鍎嶉柛鏇ㄥ幘瀹曞爼鏌涘▎娆戝埌婵炲吋顨婂浠嬪炊瑜嶇拋鎻捗归悩顔煎姢婵炴彃娼￠獮鎺楀Ψ瑜庨弳蹇涙煥?
          //   闂佸憡鑹鹃張顒€顪冮崒婧惧亾閻熸澘鏆欐繝鈧鍛氦婵炲棗閰ｉ崵瀣偠?`scale/translate/clip` 闂佸憡鐟﹁摫鐎规洖寮跺濠氬炊閳哄倻鏆犻柣搴℃贡閹虫挸鈻嶉幒妤佺厒?闂?**闂佽　鍋撻柟顖滃瀹曟娊鏌￠崘鈺佸姸缂佹劧绻濋幆鍫ュ焵椤掍胶鈻旈柍褜鍓涢幐褎顦版惔锝囩**闂?
          //
          // 闂佺补鍋撻柡鍌滃劋绾?2026-10-16闂?*闂佸搫鐗滈崜婵嬫偪閸℃瑦瀚氶柡鍥风磿缁犳牕鈽夐幘顖氫壕濠?闂佸湱顭堥ˇ鏉课涢妶澶嬪仼閻忕偟鏅﹢瀵哥磼閻欐瑥瀚崕鏃堟煕閹哄秴宓嗛柕鍡楊樀濡啴濮€閿涘嫬顥戠紓?闂佹寧绋戦張顒傛暜閸︻厸鍋撻悽闈涘付闁伙綆鍓涙禍鍛婃綇閵婏箑顕梺鎼炲劤閸嬫鑺?*闂佹寧绋戦¨鈧紒?
          //   闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亞濠€瀵哥磼閻欐瑥鎳夐埀顒侇焽閳ь剙婀遍崑鐐参?濠电偞鎯岄崰鏍ㄦ叏閳哄啩娌柛灞剧懅閻?`playerPane` 闂佸憡鑹鹃惉鍏碱殽閸ヮ剙违濞达絽鎲￠煬顒傛喐閼割剙鐏╃憸鏉款槺閳ь剙婀遍幊鎾斥枍閹烘挾鈻曢悗锝庝憾濡?
          //   闂佹寧绋戝澧倁jie.pa:1861` 闂?builder 婵＄偑鍊曢幖顐よ姳椤撶姵鍋樻い顓熷笧缁?1 `floatingCover` / 12 `metaRow` /
          //    13 `floatingMeta`闂佹寧绋戦惉濂割敄?**52** 闂佸綊娼х粔闈浳?`playerPane`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
          //   婵?*闂佺懓鐡ㄩ崹鍐差煥閹寸偟鈻旂€广儱鐗嗛崢鎾煟閹炬瀚崕鏃堟⒑椤撱劎瀵奸梺鍙夌矌娴狅箓宕掑鍫㈠礈**闂佹寧绋戦懟顖滄暜椤愶箑鐐婇柣妯哄级闊?闁哄鏅滈悷銈夋煂濠婂應鍋撻崷顓熷殌婵炲懏甯″畷鐑藉Ω閵娧咁啇婵炴垶鎼╂禍婵堟嫚閻愬吀娌柛灞剧懅閻熸劕顭块懜浣冨闁稿繗椴哥粋宥夊幢閺囩媭浼囨繛瀵稿У濠€鍦姳?闂?
          // ```
          //     闂佸搫鍟版慨鐑藉疾椤愶附鏅慨姗嗗墰濞堥亶姊婚崼娑樼仼闁哄嫬鍊婚埀?= edge 闁?scaleAt(t)闂佹寧绋戝﹢鎲僾erMorph 缂備胶铏庨崹浼村吹閹寸偞濯撮柡鍥╁Х閺嗩剟鏌涢幋鐘插妺婵炶偐鏁婚幆鍐礋閸撲胶顦?
          //     闂佺懓鐡ㄩ崹鍐差煥閹达附鏅慨姗嗗墰濞堥亶姊婚崼娑樼仼闁哄嫬鍊婚埀?= morph.size 闁?**闁诲骸婀遍幊鎾斥枍閹烘鍎?morphScale**闂?闂佸憡鐟﹁摫鐎规洘褰冮?闂備緡鍙忕徊鑲╃博鐎电硶鍋?
          //           .scale(morph.size/base.size) + .translate(...) 闂佹眹鍔岀€氼亝顨ラ崶顒佸亱闁冲搫顑囩粈澶愭偡?
          //           `LyricFloatLayer` 闂?闂?闂佽浜介崝宀勵敋闁秵鏅?
          // ```
          //   闂?闁诲骸婀遍幊鎾斥枍?`scale` 闁哄鏅滈悷銈囩博閺夋嚦娑㈠箳閹寸偠鍚梺鐟扮摠閸ㄥ啿顭ㄩ幋鐐翠氦婵炲棙甯為悵?*闂佸憡鑹鹃張顒€顪?*闂佺懓鐏氱€笛勫垔鐎涙顩?闂佸憡鍔曢幊搴敊閹邦喕娌柛灞剧箘椤庘偓闂佹椿鍋€閸嬫挾绱?婵?
          //     "濠电偞鎯岄崰鏍儑閹殿喕鐒婂〒姘ｅ亾婵炶偐澧楃粋鎺撴償閵忊剝顔掔紓浣瑰姈椤ㄥ﹪宕戦崨顔锯枖闁逞屽墯缁傛帡鎮惧畝鈧槐姘舵煕閹烘挸顎滅紒顖滃У閹峰懘鎮╅搹顐ユ嫬闂備緡鍙忕徊鑲╃博鐎涙顩?**婵炴垶鎸堕崐鎾斥枎閵忥紕顩?*闂佹寧绋掔粙鎺懳涢妶澶嬪仼閻忕偠妫勫☉褔鏌熼崹顐㈩嚋濠殿垱鎸冲畷婊冾吋閸艾浜鹃柛娑卞亐閸?
          //   闂?闂佺娉涢敃銉ф嫚閻愬吀娌柛灞剧⊕閸庢棃鏌涢幋婵囨儓妞ゆ梹鍔欏畷?= 婵炴垶鎸堕崹铏规暜閳ь剟鏌涘顒佸攭闁?闂?闁诲繐绻嬬欢姘焽娴兼潙鎹堕柕濞垮劚琚熼梺姹囧灱椤斿﹪鎳?*闁?`morphScale` 闂?*
          //     闂佹寧绋戦悧鎰板箲閿濆绠ラ悗锝庡亝椤?闂?0.082 闂?闂佸憡鐟禍婊勬櫠?8%闂佹寧绋戦ˇ顓㈠焵椤掆偓閸婂潡宕戦崨顓ф桨闁挎繂妫欑瑧闂佹椿娼块崝宥夊春?*閻庤鐡曠亸娆戝垝閿涘嫧鍋撻崷顓炰沪缂佷礁鐡ㄥ?*闂佹眹鍔岀€氼剟鎳滄导瀛樺亹閻犱礁婀辩粣?
          //     `morphOverlayBridging()` 濠电偛顦崝鎴﹀闯閹绢喗鐓傜€光偓閳ь剙鈻撻幋锕€违閻忕偟鏅▓閬嶆⒒閸偅绶氱紒顔惧У缁嬪鈧綆浜炵粣鏂库槈閹剧韬い銉秮婵?闂侀潧妫楅懟顖炴儍濠靛顥堥柕蹇嬪灮缁辨岸鏌熺€涙ê濮冪紒鏃€鎸抽幃娆撶嵁鎼存挸浜剧€广儱鍟犻崑?
          //   闂?**闁荤喐娲戦懗璺猴耿閿熺姵鍋傜憸搴ㄥ箚婢舵劖鐒介柨婵嗗閸ゅ鎮橀悙鎻掆偓缁橆殽閸ヮ剚鏅悘鐐舵椤ゅ懐绱撻崘鎯ф灍婵炵⒈鍨辩粋鎺楁嚋閸倣锕傛煕韫囨挾澧涘┑鈥虫憸娴滃憡绗熼埀顒€顭囨导瀛樺剭闁告洦鍋呭Σ鈧柣搴ㄦ涧閹测€愁焽闂堟稈鏀﹂柟閭﹀幗閺嗩參鏌?`scaleAt(t)`**
          //     闂佹寧绋戦悧鍡涚嵁閹捐绠冲鑸靛姇娴滄繂鈽夐幘顖氫壕闁?`.scale/.translate`闂佹寧绋戦¨鈧紒杈ㄧ箞閺屽洭鏁愰崱妯烇箓鎮归幁鎺戝缂佹ぞ鐒﹀鍕礋椤撶喓鏆犵紓鍌欑劍閹稿鎮楅鐐茬哗闁荤喐婢樿 + **闂婎偄娲ら幊姗€濡磋箛娑樺珘濠㈣泛瀵掗崯搴☆熆鐠虹儤鍠橀柍褜鍓氶崝鏇㈠箮濮樿埖鍎?*闂?
          //   闁诲海鎳撻張顒勫汲閿濆鍋犻柛鈩冪懄閺嗙娀鎮峰▎搴ｅ妽婵犫偓娴兼潙妫橀柛銉檮椤愪粙鏌?`Stack` 闂備焦褰冮惌鍌炲磻閸涱厸鏋?`闂佺补鍋撻柡鍌滃劋绾?婵炴垶鎸哥粔鐑姐€呴敃鍌氱濠电姴鍟抽惂渚€鏌涢弬璇插闁活亙鍗抽獮鏍敆閳ь剟宕虹仦鐐氦婵炲棙鎸稿▍顡?闂佹眹鍔岀€氼參寮悙鐑樼厒濠电偛绨遍崑?
          if (this.usesPhoneSwiperLayout()) {
            this.LyricFloatLayer()
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-17闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`PLAYER_ROOT_ID`闂佹寧绋戦¨鈧紒?*闂傚倸鐗忛崑鐐存櫠濠婂牆绀夐柛顭戝枛瑜扮娀姊婚崒銈呭绩妞も晪绠撻獮蹇擃吋閸ャ劎鏆犻梻渚囧弿缁茬晫妲愰幆鎵杸妞ゆ劑鍊曞楣冩倶韫囨岸鍝烘俊鍙夋倐瀵敻顢楅崘銊庢繈鏌?*闂?
      //
      // 闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗椤忓崬銆掑鈧鍥╊槷`.id(PLAYER_ROOT_ID)` 闂佸湱顭堥崐绋匡耿?*闁?`.scale/.translate/.clip` 闂佹眹鍔岀€氫即宕戦崨顔锯枖?Stack 婵?*
      // 闂佹寧绋戝澧倁jie.pa:191400-191478`闂佹寧绋掗悺?scale` 191400-191415 闂?`.translate` 191416-191431 闂?
      //   `.clip(true)` 191462-191469 闂?**`.id(PLAYER_ROOT_ID)` 191470-191478**闂佹寧绋戦¨鈧紒?
      // 闂?`MeshCoverBg` 婵?`playerPane` 闂備緡鍠涘Λ鍕耿椤忓棌鍋?*闂備焦褰冮惌鍌氼焽?*闂佹寧绋戦悧濠傦耿閻楀牄浜?:4952-4970 闂備緡鍙忕徊楣冾敊瀹€鍕劵闁归偊鍨奸弨浠嬫倵闂堟稒璐￠柛娆忛叄閺佸秵寰勯崼姘壕?
      //
      // 闂?闂佸湱顣介崑鎾趁归悩顔煎姤缂佺粯鐗犻弻宀€浠﹂懖鈺冩闂佸湱顭堥崐绋匡耿?*閻熸粏鍩囬崹纭呫亹婢跺备鍋撻崷顓熷殌婵?*闁哄鏅滈悷銈囩博鐎甸晲娌柛宀嬪缁€鍕槈閹惧磭校婵℃彃鎽滈埀顒傛嚀閸熸澘鈻撻幋锔藉亯?`Stack`闂佹寧绋戦¨鈧紒?
      //   闂傚倸鐗婇悷锕傤敆濞戙垹绠戝〒姘功缁€鍒瀖orphScale=1 / translate=(0,0) / 闂佸搫鍟版慨楣兯夐崱娑樼闁绘碍妫冮弫宥嗗緞婵犲嫭娈滈柣蹇撶箺妞寸危?*濠电姴艌閳ь剙纾宀勬煟閵娿儱顏柟鎼佷憾瀵劍銈ｉ崘锔瑰亾?*闂?
      //   闂婎偄娴傞崑鍡涘矗鎼淬劌绠柛顭戝枛閻撳倿鏌ｉ妸銉ヮ仾妞ゆ帗绮撳?濠电姴艌閳ь剙纾宀勬⒑椤撱劎瀵肩紒鏃€娼欓? 闂佺偨鍎查弻锟犲焵?闁哄鏅滈悷锕傤敆濠婂牆鍙?`ShrinkOverlay` 闁荤喐娲戦悞锕傛儑閹殿喗灏庡瀣娴狀垰鈽夐幘鍐差劉鐎殿啫鍛勃闊洦绋堥崑鎾诲箛椤掆偓閸撹偐绱掓潏鈺佇㈡い鏇ㄥ枟椤洭骞囬鐣屾殸闂佸憡鎸哥粔浣冦亹娓氣偓婵?
      //   闂佸疇娉曟刊瀵哥箔?闂佹悶鍎虫慨鐢割敆?`componentSnapshot.get(PLAYER_ROOT_ID, 闂?` **闂婎偄娲ら幊姗€濡磋箛娑樻嵍闁靛鍎撮崺宀勬煕濞嗘兎顏嗘閹寸偞鍙忛悗锝傛櫇椤撴椽鏌?*闁?
      //      闂佹寧绋戦悧濠偽涢妶澶嬪仼鐎光偓閳ь剙鈻?`closeWithAnimation()` 婵炴垶姊婚崰鎰ｉ幖浣告嵍?`pullMode` 婵炴垶鏌ㄩ鍛此囨繝姘ュ〒姘ｅ亾闁靛棗顦靛Λ鍐閿濆洨顔庡┑鐘才堥埀顒€纾宀勬煛閸愵厼鐓愬褏濞€楠炲繐顓艰箛鏇狀槴闂?
      //   闂佸疇娉曟刊瀵哥箔?婵?`MESH_BG_ID` / `MINI_LYRIC_BOX_ID` 缂?*濡ょ姷鍋犲▔娑㈡偤?*闂佹寧绋戝濉痚tFrameNodeById` 闂?id 闂佸搫琚崕鑽ゆ?
      //      婵炴垶鎸撮崑鎾斥槈閹垮啩娴峰┑鈽嗗弮閹瑩鎮烽弶鎸庨敪闂佸搫鐗嗛ˇ顔剧博鐎涙鈻?id闂佹寧绋掔粙鏍崲閺嶎厼绀勯柣姗€浜堕崵瀣煛?*婵炴垶鎸哥粔鎾箖閹剧粯鍤嶉柛灞剧矊娴?*闂佹寧绋戞總鏃傝姳閻楀牏鈻旂€广儱鎳庨〃娑㈡煕濠靛棛鈻岀紒杈ㄥ哺婵?
      .id(PLAYER_ROOT_ID)
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佽浜介崕鎵箔閸屾稓鈻斿┑鐘插暟閸╂姊洪銊у闂?LANDING 闂佸搫鍟冲▔娑欑閻樼數绠?闂佹眹鍔岀€氼喚鍒掗鐐茬闁割偅娲橀敍?* 闂佺偨鍎查弻锟犲焵?`playerPaintsOf`闂?
      //
      // ## 婵炴垶鎸搁敃銉╂偉閸洘鐒介柨婵嗗椤忛亶鏌℃径鍡楀⒉婵?*闂佸搫鐗嗛ˇ鎵矓妞嬪孩瀚荤痪顓炴噳閸?*闂佹眹鍔岀€氬摜妲愬鍊僽jie.pa:153390-153430`闂佹寧绋戦悾鐠廰inPage` 闂佸憡鐟﹂崹鐢电博閻ゎ垬浜归柕蹇曞Т缂嶄線鏌ｅΟ鍨厫闁逞屽厸缁舵岸宕戦崨瀛樼厒鐎光偓鐎ｎ剛顦?
      // ```ts
      //   AppStorage.setOrCreate(K_MORPH_SQUASH, playerPaintsOf(stage) ? true : false);  // 闂?闁诲繐绻楁ご绋课ｉ崨濠冧氦婵炲棗閰ｉ崵瀣偨椤栨艾鏆欓柣?
      //   if (stage !== MorphStage.LANDING) { this.stopLandAnim(); this.morphSquashY = 1; }
      // ```
      // 闂?`playerPaintsOf(stage) = stage !== MorphStage.LANDING`闂佹寧绋戝濉巓rphState.ets`闂佹寧绋戦悾鐡€ujie.pa:93205`闂?
      // 闂?**闁?LANDING 闂備緡鍙忕徊鑲╃博閹绢喖绀嗛柡鍕箲瀹曟娊鏌ㄥ☉妯绘拱闁规悂浜跺銊︺偅閸愶腹鍋撴径鎰瀬闁圭虎鍠撻埀顒€顦扮粙澶婎吋閸涱厽娅冪紓鍌欑劍閿氶柛?*闂?
      // `PlayerPage` 婵炴挻鐨滈崱鈺佹闁诲海鎳撻崯顐㈩潩閵娾晛鍙?`pullPaintable = !pullGeomReady ? true : playerPaints(stage)`闂?
      //
      // ## 闂佸搫鐗滈崗娑氬垝閵娾晛鍌ㄩ柣鏂挎啞闂?*濠电偛澶囬崜婵堟暜?*闂佹寧绋戦悧濠囶敆閹绢喗鈷掓い顓熷笧缁€?
      // `PlayerExpandState.playerPaints()` 闂佸搫鍟犻弲娑橆潩閵娾晛绀冩繛鍡楃箞閸嬨劌霉濠婂啯锛旂紒杈ㄧ崑return stage !== LANDING;`闂佹寧绋戦¨鈧紒?
      // 濠电偛顦崝鎴﹀闯閹绢喗鐓傞悘鐐跺亹閻﹀秹鏌涢幇顓犳噮婵炵厧鍟伴埀顒傛嚀閸熸潙危婵犳碍鍎嶉柛鏇ㄥ墯绗戞繛瀵稿Л閸嬫挸鈽夐弬璺ㄥ⒊缂?
      // > 闂侀潧妫楅娆癗DING = 閻庤鐡曠亸娆戝垝閳╁啰顩查柕鍫濈墢缁犻绱撴担鍦噯缂侇垳濮甸幏鍛存偐閾忣偉鎷梺鎸庣☉閻楀棝顢氶鈧?`playerPaintsOf = false`闂佹寧绋戦¨鈧紒杈╁濞艰鈻庢惔锝庝紘闁汇埄鍨庨崱妯洪棷闂佸湱铏庨崢浠嬪棘娴ｅ箍浜?
      // >   **婵炴垶鎸哥粔鎾疮閳ь剟鏌?*闂佹寧绋戦懟顖炲箚娓氣偓瀹曟艾鈻庢惔锝囩崶闂侀潻璐熼崝蹇曞寲閻樿櫕濯撮柣妯挎珪閽傚鎮樿箛搴ｇ獢婵炶偐澧楃粙澶嬬節閸曨剚鐣繛鎴炴尨閸嬫挸鈽?*闂佸憡鑹鹃懟顖炲及閸屾壕鍋撻棃娑欐喐婵炲牊鍨佃彁閺夊牜鍋勯ˉ蹇涙倶韫囨挾绠查柡宀€鍠栧畷?*闂佹寧绋戦惉鐓幟洪崸妤€绀嗛柟宄扮焾濞煎爼鏌涘Δ浣烘憙婵炴潙娲俊鎾磼濡嘲浜?
      // 婵炶揪绲藉Λ妤呮偩?*闂傚倸妫滈崺鏍矓妞嬪孩瀚荤痪顓炴噳閸?* 闂?闂備緡鍙忕徊鍊熴亹閻愬灚瀚氭繝闈涙搐娴煎酣寮堕埡鍌氼棆婵炲牊鍨块幃鎶藉箯瀹€鍐╂緰婵炴垶鎸撮崑鎾绘煟閳哄倹缍戞繝鈧鍫濈煑闁瑰濮甸弲鎼佹煏閸℃鈧粙鍩€?闂佸憡鑹鹃懟顖炲及閸屾壕鍋撻棃娑欐喐婵炲牊鍨规禍姝岀疀閺冣偓閻撴瑩鏌?闂侀潻璐熼崝宥嗘櫠濠婂牆瀚夐弶鐐村閻熸劖鎱ㄥ┑鎾剁ɑ婵?
      // **婵炴垶鎸撮崑鎾绘煛婢跺棌鍋撳畷鍥у絺闂佹椿鍙庨崰姘枔閹达附鍤勯悘鐐靛亾閻?*闂佹寧绋戦悧鍡涱敊閹版澘闂?`scale 闂?0.082` 闁?`clipHeight 闂?683` 闂?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹闂?
      // 330闁?6 闂佹眹鍔岀€氼厽鏅舵惔銊у祦鐎规洖娲ㄩ崣鎰喐闁附绶涚紒杈ㄥ哺閸ㄩ箖寮悰鈥充壕?婵炴垶鎸稿ù鐑藉极閵堝绠ｅ瀣瘨閸?闂?闂佸搫顥￠幍鍐蹭壕?*闂佸搫鐗嗛ˇ鎶藉磿濡ゅ懎鐤炬い鏍ㄧ懅缁嬪鏌￠崟闈涚仸闁绘繍鍠楅幆鏃堟晜閹屾婵?*闂侀潧妫楃粔褰掑焵椤掍礁濮囬柣鈯欏洤瑙﹂悹鍥у级閸娿倝鏌?
      //
      // ## 婵炴垶鎹佸銊у垝閸喓鈻?`.visibility(Hidden)` 闂佸吋婢樻總鏃傜箔婢舵劕鍙?`.opacity(0)` 闂佺懓鐡ㄩ悧妤€顭囬娑氼浄闁奸晲绲婚々顐︽煛?
      //   閻?`Hidden` = **婵炴垶鎸哥粔鍓佸垝椤栫偛绀嗛棅顒佺ゴ閸嬫挻鎷呮搴Ｉ戞繛锝呮处缁诲嫰寮抽埀顒勬偨椤栨艾鏆欓柣?* 闂?婵?闂佺顑嗙划搴ㄦ偡?闂佸憡鑹炬總鏃傜不閻斿吋鏅悘鐐跺亹閻燁剙鈽夐幘宕囆㈠┑顔规櫆缁傛帞鎷嬪畷鍥┬梻浣瑰絻缁绘垹绮?闂備焦瀵у銊╁磻?
      //     闂佹寧绋戝濉痚tFrameNodeById` 闂佹眹鍔岀€氼噣鎮￠埡鍕╀汗妞ゎ偒鍏橀崑鎾寸▕椤ょAreaChange` 婵炴垶鎸搁敃銉︽叏閵堝鐒鹃柟瀛樺笧閻熸繈鏌涘▎鎰垫當濠靛倹鐗犲畷顐㈩吋韫囨洜顦梺?
      //   閻?`.opacity(0)` 婵炲濮寸粔宕囨閹殿喗灏庨柟娈垮枤鐢盯鏌涢幒鎴濐暢妞ゆ挸鎽滈惀顏堝礌閿涘嫮顦?闂佺顑嗙划搴ㄦ偡?濠电偛澶囬埀顒€鍘栫划鐢告煕閹烘垵绨荤紒杈ㄥ哺閺佸秴鐣濋崘锝呬壕閻忕偠鍋愰悷顒勬煛閸偄澧撮柕鍡楊樀閹?`.opacity` 閻庤鐡曠亸娆戝垝閿熺姴鍙?
      //     `morphOpacityValue()`闂佹寧绋戦悧濠冪?1闂佹寧绋戦惌渚€锝為崱娑欑劷闁挎繂顦▍锟犳煟閵娿儱顏柡浣哄仱閺屽本绻濊箛鏇狀槴闂?
      //   閻?闂佸搫顦埀顒€寮堕鑺ョ箾閹惧啿绾ч柣鎾愁儐鐎电厧顫濋鐐嶁晠鏌ら崫鍕偓濠氬磻閿濆棛顩烽幖娣灮閸╂劕鈽夐幘绛规敾闁瑰弶濞婇獮?闂?闂備焦褰冪换鎴犵矈閺夋垟鏀﹂柟閭﹀幘鍟告繝銏ｅ煐閸炶崵妲愬渚綥AYER_BIG_COVER_ID` 缂備焦绋戦¨鈧紒杈ㄥ哺閺佸秴鐣濋崟鍨棖闂傚倸瀚ч弲娑㈠Φ閸ヮ剙违?
      // 闂佸疇娉曟刊瀵哥箔?闂婎偄娴傞崑鍡涘矗鎼淬劌鎹?`morphLand()` **婵炴垶鏌ㄩ鍛櫠?*闂佺懓鍢茬粙鍕濞嗘垶鍠?`closeWithAnimation` 闂佹眹鍔岀€氫即濡存惔銏″劅闊洢鍎崇粈鍡涙煃?闂佸搫鐗滈崜鐔肺涢鍌滅閻犲洩寮撳ù鐑芥煛?
      //    闂佹悶鍎查崕鎶藉礄閿涘嫮纾奸煫鍥ㄦ尭閻撳倿鏌熼棃娑卞劀缂佽鲸绻冪粙澶婎吋閸曨厾鐛ラ梺鐟板槻缁夋挳宕虹仦鍓р枖闁逞屽墮椤曪綁鎮╃喊妯绘櫈闂佹悶鍎伴崟姗€鍩€?
      // 闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃锝囩博鐎靛憡鏆滅憸宀€鍒掑☉銏犲強?LEAVING闂佹寧绋戦悧鍡楋耿椤忓牊鍋ㄥù鍏肩懅缁€鍡涙煃?闂佺绻戞繛濠偽涢幘顔肩闁靛ě鍕瘞闂佸搫鐗滈崜婵嬫閳哄倻鈻旂€广儱鎳庣紞鈧悷婊勬緲瀹曨剟骞栭悜钘壩?
      .visibility(this.expandState.playerPaints() &&
        (!this.expandState.morphClipping() || !this.expandState.morphPaintHidden()) ?
        Visibility.Visible : Visibility.Hidden)
      // 闁荤喍妞掔粈浣圭珶閳ь剛绱掗幇顓ф當鐟滅増绋掗〃鍥熼崫鍕靛敽 = 闂佸憡鐟崹鐢革綖鐎ｎ偒娈楁俊顖氭惈椤?/ 缂傚倸鍊甸弲婊堝棘?闂?缂傚倸鍊甸弲婊堝棘娓氣偓瀹曘儲鎯旈姀鈺佸Η婵犻潧鍊芥慨銈呂ｉ幖浣圭劷闁挎繂鎳忛崑銉╂煕濞嗘ê鐏ユい顐㈩儔閹矂鍩℃担钘夌厒
      .height(this.morphClipHeight())
      // 闁哄鐗嗗﹢閬嶅疾椤愩倖鍟戝ù锝囶焾椤ュ懘鏌ㄥ☉妯煎婵炴挸澧介幉鎾箳閺冣偓閺嗙娀鏌涘顒€顏╂繛瀛橆焽娴狅箓宕掑┑鍡橆唶闁汇埄鍨界拋锝囨鏉堛劎鈻旂€广儱娲﹂弳?clipShape闂佹寧绋掗懝楣冩偩閻樺啿顕辨慨妯诲墯濞差剟鏌?borderRadius闂?
      // 闂佸吋婢樻總鏃傜箔閺嶎偀鍋撻悷鏉挎殶婵炲牊鍨奸妵鎰板閵忕姌锕傛倵闂堟稓绉虹紓宥呯墢閹风娀顢樺┑鍫㈡瀫闂侀潻璐熼崝宥呂涢妶鍥ㄥ闁诡垎灞拘ｉ梺鍝勫暢閸╂牠鎯€閸涱厸鏋栭柡鍥ュ灮瀹曪綁鎮归崶锔剧瓘缂?
      .clip(this.expandState.morphClipping())
      // 闂佽桨鐒﹂幐鎶藉Υ婢跺瞼纾介柍鍝勫€归弶?+ 婵炶揪绲界粔鏈电昂闂佹寧绋掑畝绋款焽閵堝拋娼伴柕蹇婃閸?scale=1 / translate=0闂佹寧绋戞總鏃傜箔鐏炶В鏌﹂柍鈺佸暞缁犳帡寮堕埡鍌滄噧妞ゃ劍绮撳畷婵嬪Ω瑜庨弳浼存煛閸愩劎鍩ｉ柍褜鍓氶崝鏇㈠磿濮樿鲸顫曢柣妯夸含椤忛亶鏌?
      //
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛伇婵?*闂佸搫瀚崕宕囨閿熺姵鐓ユ慨妯哄船娴?*闂佹寧绋戦¨鈧紒?
      //   闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗閸ゅ鎮楅崷顓熷殌婵炲懏甯￠弫宥夊锤閸撳jie.pa:191400-191415`闂佹寧绋戦ˇ顖炲疮閹剧粯鍎嶉柛鏇ㄥ墯绗?
      //     `.scale({ x: expand.scaleValue, y: expand.scaleValue })`
      //   闂佸吋婢橀懟顖炴偩閻樼粯鍎?`initTranslateX/Y` 闂?*闂?缂傚倷鐒﹀ú鎴︽嚈閹达絿鐤€闁告劦浜炵槐姘舵煛閳?闂佸憡鐟ョ粔鐤暰闂佸憡鍨归崕銈咁焽?*闂?
      //   闂佹寧绋戝濉眓itParams` 51524-51575闂佹寧绋掗悺?缂備焦鍔栭〃鍛搭敊閺冨牆鐒鹃柟璺侯唸xW)/2 闂?left` / `(h 闂?h閻犺櫣妞€)/2 闂?top`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
      //   婵炴垶姊婚崰搴☆潩閵娾晛鍙婃い鏍ㄧ箥閸?*"缂傚倷鐒﹀ú鎴︽嚈閹达絿鐤€?闂佸搫瀚烽崹浼存偩閻樼粯鍎嶉柛鏇ㄥ亜椤ゅ懘鏌?*闂佹寧绋戦懟顖濄亹瑜斿浼搭敍閻愬瓨绁慨鎺撶⊕椤牓顢樻繝姘９闁绘挸楠搁獮鈧梺缁樼矎閸╁洭鍩€?
      //   闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡楁捣椤忓崬銆掑鈧崟顐殹闂佸搫鐗嗛ˇ顖炲吹閹寸偞濯撮柡鍥朵簽缁€鍒瀒nitTranslateX/Y`闂侀潧妫斿姊抩verHostW/H`闂侀潧妫旂欢姘跺焵椤掆偓濡銇愭径鎰闁靛繆鈧疇鍚傞柣搴ｆ暩閵嗗妲愬鑸靛仺闁靛ě鍕殸婵炴垶姊婚崰鎰?
      //   闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳椤ゅ懘鏌熺紒妯哄Ё缂佽鲸绻堥獮宥夊焵椤掍胶顩烽柕澶堝妿缁犲綊姊?*闂佺娉涢敃銈夋偩閻樿鍙婇柟顖嗗懐顢呴梺鍛婂姈閻熴儵宕甸銏犵骇?*闂佹寧绋掓穱娲敋閵忥紕鈻曞璺虹灱閹肩厧霉閻樻彃娈╃紒杈ㄧ箖閹峰懘宕卞Ο浣曗晠鏌涚€ｎ亝绌挎い鏃€娲熼弻锔藉緞鐎ｉ潧濮?闂佺偨鍎查弻锟犲焵?
      //   婵炴垶鎸稿ú锝囩博鐎甸晲鐒婇柛鈩兩戦梽?ArkUI 闂佽　鍋撻梺顐ｇ〒閸熷﹤顫楀☉娆樼劸妞ゆ挸顭烽弻銊ヮ潩閸楃偘鍖栭梺鎸庣☉閻胶鎹㈤弽銊р枖闁逞屽墰閹澘鐣濋崘銊ュ箣闂佸湱纭堕埀顒冨皺缁?闂佽桨鐒﹀娆撱€冨鍫濈闁绘浜粔鍨槈閹绢垰浜鹃柣鐘欏懎鍘撮柡浣革攻閹?闂?
      //   闂佸疇娉曟刊瀵哥箔?**闂佸憡鐟禍婵嗭耿?`centerX/centerY` 闂?闂佺儵鏅濋…鍫ヮ敋椤曗偓閹虫盯顢旈崶顒傚彁闂佹眹鍔岀€氼喖鈻嶉妸鈺佺闁糕剝顭囧Σ?**闂?0% = 闂佺厧鎼崐濠氬磻閿濆鍤婃い蹇撳缁犳帡鏌ｉ妸銉ヮ仹闁煎灚鍨肩粻娑㈠礃鐠恒劎顦梺?
      //     闂佸湱顣介崑鎾趁归悩顔煎姎婵犫偓椤忓懐顩烽悹浣哥－缁夊潡鎮樿箛鎾存儓妞ゆ洦鍘界粙澶屸偓锝庡枛閸樺绱掑☉姗嗘Х闁绘粠鍨辩粋?缂傚倷鐒﹀ú婵嬪吹濠婂牏鍙曟い鎯点倕骞€闂?闂?
      .scale({
        x: this.expandState.morphScale,
        y: this.expandState.morphScale,
        z: 1,
        centerX: '50%',
        centerY: '50%'
      })
      .translate({ x: this.expandState.morphTx, y: this.expandState.morphTy })
      .borderRadius(this.expandState.morphRadius)
      .opacity(this.morphOpacityValue() * (this.expandState.morphClipping() ?
          this.expandState.morphTailOpacity() : 1))

      // 闂佺补鍋撻柡鍌滃劋绾?2026-10-16 闂佺偨鍎查弻锟犲焵?**婵炴垶鎸哥粔鐑姐€呴敃鍌氱濠电姴鍟抽惂渚€鏌涢弬璇插闁活亙鍗抽弫宥夊醇濠靛牊顔堥梻?濠殿喗绻傞懟顖炲箖閺囥垺鏅璺侯儐閸庢棃鏌涢幒鎾愁€滅紒缁樼墵閺屽苯鐣濈€ｎ剛顦╂俊鐐€楅弫璇差焽娴兼潙鍐€闁革富鍙冮悰鎾绘煥?*闂?
      //
      // ## 闂佺懓鐡ㄩ崹璺猴耿閻楀牊濮滄い鏃囨硶濡叉悂寮堕埡浣圭煑缂佹梹娼欓埢搴ㄥ煡閸涱垳顦梺瑙勪航閸斿矂顢氭潏鈹惧亾閻熸媽瀚版慨妯稿姂楠炴﹢濡堕崨顔绢槬婵炲瓨绮屽Λ瀵告濞嗘垶濯煎Λ棰佽兌閻熸捇鏌℃径鍫濆姎闁告ǜ鍊曢銉ヮ渻閸撗呮啴濠电偛妫岄埀顒€鍟块弲娆撴偣閸ャ劍绌跨紒?
      // 闂佸搫鍟版慨鐑藉疾椤愶附鍎?*闁诲繒鍋涢崐缁橆殽?*缂佺虎鍙庨崰鏍偪閸曨垰鍙?濠电偞鎯岄崰鏍ㄦ叏閳哄啩娌柛灞剧懅閻?`playerPane` 闂佸憡鑹鹃惉鍏碱殽閸ヮ剙违濞达絽鎲￠煬顒傛喐閼割剙鐏╃憸鏉款槺閳ь剙婀遍幊鎾斥枍閹烘挾鈻曢悗锝庝憾濡?
      // 闂佹寧绋戝澧倁jie.pa:1861` 闂?builder 婵＄偑鍊曢幖顐よ姳椤撶姵鍋樻い顓熷笧缁?1 `floatingCover` / 12 `metaRow` /
      //  13 `floatingMeta`闂佹寧绋戦惉濂割敄?**52** 闂佸綊娼х粔闈浳?`playerPane`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
      // 闂佸湱顣介崑鎾趁归悩顔煎姕闁搞劍绮嶇粙澶愬焵椤掍焦鍎熼柨鏃囨鎯熼柣搴ｆ嚀閸燁垶骞嗘径鎰濡鑳堕崯濠囨煛閸偄澧柣顏冨嵆閺佸秴鐣濋埀顒勫箖婵犲洦鍋ㄩ弶鍫涘妽绗?闁汇埄鍨伴崯顐︽儑椤掑嫭鍎庨柟鍝勭Ф閻熴垽鏌＄€ｃ劌鐏遍梺浼翠憾閺屽牓鎮剧仦钘夊闂?闂?闁荤喐鐟ラ崐褰掑礉閸涙潙鐭楁俊顖氭惈椤曆冣槈閹惧瓨銇濇繛?闂?
      //
      // ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐犲劚娴滄繂鈽夐幙鍐х敖闁诡喖锕幃?*闂佸搫瀚烽崹鍫曞极婵犲洦鍎?*
      // 闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ墲閻т線鏌涢弬璇插闁活亙鍗抽弻灞界暆鐎ｎ剛顦柣蹇撶箣缁舵艾顭囨导瀛樺仺闁靛ě鍕殸闂?*缂備胶铏庨崹浼村吹閹寸偞濯?+ 婵炴垶鎸撮崑鎾寸箾?`scale`**闂?
      // ```
      //   CoverMorph.scaleAt(t) = lerp(1, lyricScale, t)      // 85856-85743
      //   濠电偞鎸稿鍫曟偂鐎ｎ兛鐒婇柛婵嗗閸?= edge 闁?scaleAt(t)                        // 85856 闂備緡鍙忕徊鑲╃博閺夋埈娴?
      // ```
      // 闂?*闂佺懓鐡ㄩ崹鍐差煥閹寸偞浜ゆ繛鍡楁捣椤忛亶鎮橀悙鎻掆偓璇测枔閹寸姳鐒婂〒姘ｅ亾婵為棿鍗冲?闂佸憡鐟﹁摫鐎规洘褰冮?**闂佹寧绋戝濉媦ricFloatLayer` 闂備焦褰冮惌鍌炲磻閸涱垪鍋?
      // `.scale(morph.size / base.size)` + `.translate(...)`闂佹寧绋戦惌渚€锝為崱娑欑劷闁挎繂顦▍锟犳煟?闂?闂佽浜介崝宀勵敋闁秵鏅璺烘閸嬫捇寮悰鈥充壕?
      // 闁诲海鎳撻崯鏉库枔閹寸姳娌煫鍥ㄦ尵椤斿酣鎮樿箛鎾存儓妞?= **`morph.size` 闁?闁诲骸婀遍幊鎾斥枍閹烘鍎?`morphScale`**闂侀潧妫楅崐椋庡姬閸愵亙鐒婇弶鍫涘妽绗戦柣鐘叉穿閹活亞妲?
      // ```
      //   闁诲骸婀遍幊鎾斥枍?scale 闁哄鏅滈悷銈囩博閺夋嚦?*闂佸憡鑹鹃張顒€顪?*闁荤姵鍔楅崰鏇㈡儗濡や胶鈻旈柕鍫濆椤愯棄霉濠婂喚鍎滅紒?
      //     闂?闂佸憡鍔曢幊搴敊閹邦喕娌柛宀嬪缁€鍓噊pBar/scrubber/transport/濠殿喗绻傞惌渚€鎯佸┑瀣櫖濠㈣泛娴烽鈧梺娲诲亐閸嬫挾绱?闂佺偨鍎查弻锟犲焵?闂佸搫鍟版慨鐑藉疾椤愶絿鈻曢柣鏂挎啞缁犳帡鏌?
      //     闂?濠电偞鎯岄崰鏍儑閹殿喕鐒婂〒姘ｅ亾婵為棿鍗抽幆?*闁诲繐绻愰幖顐︻敋?*婵?闂佽桨绀侀顓㈡偘閵夆晜鐒介柨婵嗗椤忓崬霉?缂傚倸鍊甸弲娑㈠春?闁哄鏅炲〒鍦礊濮椻偓瀵爼鏁撻悩韫凹婵炴垶鎸撮崑鎾趁? 闂佺偨鍎查弻锟犲焵?闂佸搫鍟版慨鐑藉疾?*濠电偛澶囬崜婵嗭耿?*闂佹寧绋戦悧鍡涙偩閻樼粯顥?scaleAt闂佹寧绋戦ˇ顓㈠焵?
      // ```
      // 闂?闂佺娉涢敃銉ф嫚閻愬吀娌柛灞剧⊕閸庢棃鏌涢幋婵囨儓妞ゆ梹鍔欏畷鎶藉Ω瑜庨悾閬嶆⒑椤撱劎瀵肩紒鏃€鎸冲畷姘濞嗘垹顦梺?闁诲繐绻愯ぐ澶娾槈椤忓懐顩?闂?闁诲繐绻嬬欢姘焽娴兼潙鎹堕柕濞垮劚琚熼梺姹囧灱椤斿﹪鎳?*濠殿噯绲惧褰掝敆濠婂懏鍏滄い鏂跨毞閸嬫捇鎮℃惔锝嗙槗 `morphScale` 闂?*
      //   闂佹寧绋戝濉祇rphScale` 闂侀潻璐熼崝蹇涘箲閿濆绠ラ悗锝庡亝椤?闂?0.082 闂?闁诲繐绻嬬欢姘焽娴兼潙鐭楁い蹇撳閳?8%闂佹寧绋戦ˇ顓㈠焵?
      //   闂備緡鍙忕徊楣冾敆濠婂牆鍙?*闂佹椿娼块崝宥夊春濞戞﹩鍟呴柤纰卞墰閻ュ懘鎮楅崷顓炰沪缂佷礁鐡ㄥ?*闂佹眹鍔岀€氼剟鎳滄导瀛樺亹閻犱礁婀辩粣?
      //     `PlayerExpandState.morphOverlayBridging()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴鍊搁弬褔鏌?闂佺偨鍎查弻锟犲焵?
      //     闂侀潧妫楅張顒勫垂濠婂嫮鈻斿┑鐘辫兌椤忛亶鏌ｅΔ鈧悧鍡涘矗瑜旈獮鎺撳緞婵犲嫭娈滈梺闈涙閻掞箓寮懖鈺傚闁冲搫鍊圭亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢舵劖鐓傜€光偓閸曨偂绨奸悗娈垮枤婵嘲锕㈤敍鍕剨濞撴埃鍋撴繛闂村嵆閹亪顢楅崘銊︻唶闂佺懓鐏氱€笛勫垔閹绢喗鏅€光偓閳ь剛鍒掗妸鈺佸嚑婵犲﹤瀚瑧闂佹寧绋掗崺鍐焵椤掑﹦鐣虫い顐㈡喘楠炲洭鎮㈢粙璺ㄤ海婵?
      //       闂?*闁诲繐绻嬬欢姘焽閻楀牏顩烽幖瀛樼箘閻熸挾鈧灚澹嬮崑鎾斥槈閹剧韬い?*闂侀潧妫楃粙鍕濞嗘挻鍋ㄩ柕濠忕畱閻?2026-10-16 闁诲骸婀遍崑鐐电矈閹绢喗鏅璺虹墐閸嬫挸顓艰箛鏇狀槷
      //     婵炲濮伴崕鍗烆嚕?`闁诲繐绻嬬欢姘焽閹殿喚纾介柍鍝勫€搁悘鍥р槈閹绢垰浜鹃梺缁樺姇缁犲秹鍩€椤戣法顦﹂柣顐㈢Т椤曪綁鍩€椤掑嫬绀夐柕濞у嫭姣庡┑鐐插閸撴繂锕㈡担铏瑰崥妞ゆ牗绮屾禒鐥?闂備緡鍙忕徊浠嬪吹閹存績鏋庨幒鎶藉焵?
      //
      // ## 缂傚倷鐒﹂幑渚€顢欓幋锔芥櫖闁割偅绮庨悷鎾斥槈閹绢垰浜炬繛鎴炴惄娴滄瑥效婢舵劖鍎庨悗娑櫭径宥夋煟閹炬妫涚粻褰掓煛婢规嚎鍊涘▔鏌ユ煥?
      //   濠电偞鎯岄崰鏍儑?*闂婎偄娲ら幊姗€濡磋箛娑欏仼婵炲棗绻戦煬顒傛喐閼割剙鐏╃憸鏉款槺閳ь剙婀遍幊鎾斥枍閹烘鐓?*闂侀潧妫楅崐鐟拔涢妶澶嬪仼閻忕偠鍋愰娲煙绾版ê浜炬繛瀵稿О閸庢挳宕楀鈧銊╁箚瑜庨煬顒€顭块懜鐢靛⒌婵為棿鍗抽弫宥囦沪閻愵儷锕傛煕閵壯冃￠悹鎰枔閳ь剛鎳撻崯鏉库枔?*闁诲繐绻嬬欢姘焽娴煎瓨鍤婃い蹇撴喘閻?*闂?
      //   缂備胶铏庨崹浼村吹閹寸偞濯撮柡鍥朵簽缁€鍕倶韫囨挻鎯堟い?婵炶揪绲界粔鍫曟偪?闂侀潻绠戝Λ婊堬綖濡ゅ懎绀傞柕濞炬櫅閸斻儳绱掗悩鎰佹當闁搞値鍙冨鍫曞Ψ椤栨粎顦繛鎴炴尭缁夋挳骞冮崱妯碱浄閻犱礁纾粔璺ㄧ磼娴ｅ湱澧柛妯荤洴瀹曪絽螣鐠囨彃绨ラ梺鎸庣☉椤︻參鍩€?
      //   闂?闁荤喐娲戦懗璺猴耿閳ユ剚娼伴柨婵嗘搐瀵箖鏌熺喊鍗炲⒋闁稿鎳忕粙澶愵敂閸曨厽鍕剧紓浣哄珡瀹ュ洨顦梺鍛婃尭缁夊爼鎮块崱娑樼骇闁炽儱寮堕浠嬫煛?*闂佺绻愰悧濠冧繆閸濄儰鐒婂〒姘ｅ亾婵為棿鍗抽幆鍐礋椤愶絾顫呴柣搴ㄦ涧閹测€愁焽闂堟稈鏀﹂柟閭﹀幗閺嗩參鏌?`scaleAt(t)`**
      //     闂? 闂佸憡顭囩划顖滄暜閳?闂佸憡鐟﹁摫鐎规洘褰冮?闂備緡鍙忕徊鑲╃博鐎电硶鍋?`.scale/.translate`闂佹寧绋戦惌渚€顢欓埀?`lyricMorph(t)` 闂佺儵鏅涢悺銊ф暜鐎靛摜纾?
      //      闁诲繒鍋涚换鎰不妞嬪簼鐒婇柛婵嗗閸ょ喖鏌ㄥ☉姗嗘缂佽鲸绻堥弻鍥晲閸℃锕€鈽夐幘顖氫壕濠?*闁荤姵浜介崝瀣箔娴ｇ懓绶?*闂佹眹鍔岀€氼喚鍒掗妸鈺佸嚑闁告洦鍓氶弳顓㈡煕閺冩垹鍘滅紒杈ㄧ箖缁?*闂婎偄娲ら幊姗€濡磋箛娑樺珘濠㈣泛瀵掗崯搴☆熆鐠虹儤鍠橀柍褜鍓氶崝鏇㈠箮濮樿埖鍎?*闂?
      //   婵犮垼娉涚粔鐢告偋閹惰棄宸濋柟瀛樺笚婵垽鏌ㄥ☉娆戞憿grep -rn "LyricFloatLayer()" RzdMusic --include=*.ets`
      //     闂佹寧绋戦悧濠傦耿閿熺姴瀚夋繛鎴濈－缁愭鏌涘▎妯圭凹婵犫偓?*闁诲骸婀遍幊鎾斥枍閹烘绀?*闂備緡鍙忕徊鑲╃博鐎涙ê绶為柛鏇ㄥ枤濞堝爼鏌ｉ姀鈺冨帨缂?

      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂?*闂佺粯绮嶅妯衡攦閳ь剟鏌ゆ總澶夋捣闁?*闂佹寧绋戦悧鎰崲濞戙垺鍊风憸鐗堝竾閳ь剙锕弻?3 濠电偛妫岄埀顒€纾壕濠氭煕韫囨洦鍔滅紒杈ㄧ箘閹?`onDiagHotspotTap()` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴绻掔粈鍡涙煏?
      //   闂佽　鍋撻柟顖嗗嫯鍚悷婊嗗焽閸ㄧ銇愭径灞稿亾閸︻厽鍤€婵?*婵炴垶鏌ㄩ鍛此?*闂佹寧绋戦悧鍛箔婢跺本鍋栨い鎰╁€楃槐姘舵煛閳?闁荤喍妞掔粈浣圭珶閳ь剟鏌ㄥ☉姗嗘缂佽鲸绻堥獮宥夊焵椤掍胶顩烽柕澶堝劤閺嗗﹪鏌￠崟顐⑩挃闁靛洦宀搁幆鍐礋椤掍焦顔嶉柣搴㈢⊕閵囩偟绮畝鈧幏鐘电磼濡粯顔嶉梺鍛婅壘閼活垵銇愬☉姗嗗殫闁告洍鏂侀崑?
      //   闂佸疇娉曟刊瀵哥箔?閻庡灚濯芥慨銈夋偉閿濆绀傜€规洖娲︾徊濠氭煛?`diagText` 婵炴垶鎹佸▍锝夊煘?闂?闂佺粯鍩堥崢鑲╀焊椤栫偛鍙?*闁诲海鎳撻懟顖炲矗韫囨稒鐒婚煫鍥ㄦ⒐椤?*闂佹眹鍔岀€氼亞绮╅幘顔肩骇閹烘娊鍩€椤戣法顦︾紒鎰耿瀵粙宕堕浣恒偐濠电偞鎸稿鍫曟偂鐎ｎ喖违?
      this.DiagHotspot()
      if (this.diagBadgeOn) {
        this.DiagBadge()
      }

      // 闁荤姵浜介崝蹇涘礈婵傜瀚夋い鎺嶇鎼村﹥绻濊閸旀瑩宕€ｎ喗鍎庢い鏃囨缁插湱绱掗埀顒勬倻濡浚鍙冮悰顕€宕崘顏嗩槱闂佽鍣崜姘辨嫚閻愬搫鎹堕柕濠忛檮娴犳ê鈽夐幘绛硅含婵為棿鍗抽弫?
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }

      // 闂佸疇娉曟刊瀵哥箔?缂傚倷绶￠崣鍐夐敐鍥︾剨濞撴埃鍋撴繛闂村嵆閺佸秹宕搁崙鐚硆phCoverBridge`闂?*婵炴垶鎸哥粔鏉戯耿椤忓懏浜ゆ繛鍡樻尭濞?*闂?026-10-15 闁荤姍鍐ㄦЩ闁伙絿濞€閹晫鎷犻崣澶庡惈**闂佸憡鍔曢幊搴敊閹邦喕娌柛灞剧懅椤撴椽鏌?*
      //    闂佹寧绋戦悧鎰帮綖閸℃鈻斿┑鐘叉处濡椼劑鏌?Stack 闂備焦褰冮惌鍌炲磻閸涱厸鏋旈柛顭戝亝閺嗗牓姊洪幓鎺濈叚缂佽鲸宀搁崹楣冨棘鐞涒€充壕?闂佹眹鍨奸褍锕㈤鍛氦婵炲棗娴烽閬嶆倶閻愭彃浜扮紒杈ㄧ懇瀹曟﹢宕ㄩ褍鏅ｆ繛鎴炴煥椤戝嫮绮崒鐐存櫖濠㈣泛顦辩粣妤呮煙鐠虹尨姊楃紒顔惧У缁嬪鈧綆浜滅壕鎶芥偣瑜旈ˉ鎾斥枔?
      //    闁诲繐绻愮换鎴︽偤閺囩姵瀚?闂佽　鍋撻柟顖滃椤ユ垿鏌熺粙娆炬█闁?闁哄鏅滅粙鎴犫偓瑙勫▕瀵?闁圭厧鐡ㄥú鐔煎磿閹绢喖绠板鑸靛姈鐏忥箓鏌涜箛瀣闁稿繑锕㈠畷銏⑩偓锝傛櫇缁夊爼鏌ㄥ☉妯肩伇闁轰降鍊濋獮瀣暋閹殿喗婢栧┑?闁诲繐绻愮换鎴︽偤閺囩姵瀚氱€广儱瀚惌銈夋倶韫囧海绐旀繛闂村嵆閹虫浠﹂懞銉モ偓鐢告煕閹达絾顏犳鐐叉喘婵″瓨鎷呴悾宀€顔掗柟鑹版彧闂勫嫬顭囬婊勫仏妞ゆ劧绲介惃?闂?
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 闂?婵炴垶鎸搁鍡樺垔濞差亜缁╅柟顖滃瀹曟娊鏌熺紒銏犲箺闁哄倷绶氬畷鎶解€﹂幒鏃傤槱MusicHome 闂佸憡鑹鹃張顒勵敄濞嗘劗顩查柕鍫濆闂夊秹鏌ㄥ☉姗嗘缂佽鲸澹嗙划鈺呭冀椤愶絿鍑介梺褰掓敱閻楁鈧俺娉曢幑鍕偄缁嬫鏉归梺琛″亾闁诡垳澧楀畷鎶芥煥濞戞ɑ婀版繝銏☆殜楠炲秶鈧綆鍋勯惁濠氭⒒閸愩劎澧曢柍褜鍓涢崢褔宕伴崨顖楀亾鐟欏嫯澹樻鐐存崌閹儳鈻庡浣镐壕?
    //   闂佸湱顭堥崐绋匡耿椤忓牆瀚夐柍褜鍓氬鍕冀瑜忓﹢鎾煥濞戞瑧鈯曢柣鈩冩礈閹风姴顓兼径濠佺凹缂備礁顦粔纾嬨亹閹绘帩鐓ユ慨姗嗗墮琚熼柣搴㈢⊕閸旀ɑ淇婇銏″€烽梺顐ｇ〒缁愭鏌涜箛鎾跺閻㈩垱鎸冲畷姘跺箥椤旀儳寤洪梺鐑╂櫅閻°劍鏅跺鍫濈闁告牭绱曠粈?
    //   闂佸湱顣介崑鎾趁归悩顔煎姎婵犫偓椤忓嫷娼扮€光偓閸愵亝袚婵炴垶鎸搁敃銉у垝鐎涙鈻旂€广儱瀚粣妤呮偣閸ヨ泛鐏ョ悮婵嬫煕濞嗘劕鐏﹂柡浣告贡閹秆囧礄閵堝洨顦〢rkUI 闂佹眹鍔岀€氼厽鏅跺鍫濈闁割煈鍠栭弲顏呯箾婢舵稓绡€闁靛棗瀛╅幆鏃囩疀閵壯呯崶闁诲孩绋掗崝妯讳繆椤撱垺鍊烽梺顐ｇ〒閸犳﹢鏌涜箛鎾跺⒊缂佽鲸宀告俊?
    .gesture(
      PanGesture(this.panOption)
        // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎嶉柍褜鍓欓張顒勬儉閸涱厸鏋栭柡鍥ㄦ皑閻熸捇鏌熷畡閭︽Ц闁告鍥ㄢ拻妞ゆ挾鍠愮亸锟犳煛閳ь剟骞嗚閻濄倝鏌曢崱妤冃ゆ繛鍫熷灴楠炴帡骞掑Δ渚囧敹闂備焦瀵у銊╁磻閿濆鏅鑸电〒缁?
        //   闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗗閺佹粓鏌熼棃娑卞剰濠电偛绉瑰浼搭敍濮樿鲸鏆?`onActionStart 闂?dragBackStart()` 闂?
        //   闂佹寧绋戝濉ecover/logic-src/閻庢鍠掗崑鎾绘煕韫囨碍鐝柟鎼佷憾瀵劑骞嗚閻?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄦ皑缁愮偤鎮楃憴鍕殤妞?md` 闁?.3闂佹寧绋掗悺鐙wn / distance:8` +
        //   闂佹悶鍎茬粙鎰版煂濠婂牆鐐婇柣鎰濞?start/update/end/cancel 婵帞绮崝鏇㈠矗韫囨稒鏅璺虹墐閸嬫捇宕掑☉妯间函婵炲濯崜娆戞暜椤愶箑绾ч柕澶堝劚濞懷囨煛?update/end
        //   闂?婵炴垶鎸撮崑鎾绘煛?婵炴垶鎸搁鍡樺垔閸濆嫧鏌﹂柍銉ュ暱閸愨偓闁?闂?*闂佸憡甯掑Λ鏃傜箔婢跺鈧帡宕ㄩ鍙箓鏌熼棃娑卞剰濠电偛绉撮埢浠嬪灳閸愯尙鍘掗柡澶嗘櫆閻燂綁鍩€椤戞寧绁扮紒缁樻礋瀵即顢涘顒傚帓婵炲瓨绮屽Λ鏃傚緤閸撗勫仏妞ゆ劧闄勯敍宀勬煙缁洖澧查悽顖楀亾**闂?
        //   闂佺粯绮嶅妯猴耿椤忓牆绠┑鐘插€婚弳濠囨煙閸偅灏柛銈庡弮瀵爼濡烽婊咁槱`hdc shell hilog -x | Select-String 'RzdMorph dismiss pan start'`闂佹寧绋戦¨鈧紒?
        //     閻?婵炴垶鎸搁鍡樺垔濞差亜绫?*闂佺懓鐏氶幐鍝ユ闁秴绀勯柣鎴炆戦梽?* 闂?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄧ矋閺嗙姵鎱ㄥ┑鎾跺埌闁绘牕鐖奸弫宥呯暆閸曨剨绱俊顐ゅ閿氭繝鈧鍫熲拻?闂傚倸鍟悧鍡涘焵?
        //       闂佹寧绋戦悧濠勬暜閹绢喗鍎撻柍褜鍓熼幆?`RzdMorph dismiss blocked` 婵?`RzdMorph dismiss commit`闂佹寧绋戦¨鈧紒?
        //     閻?**闂佺懓鐏氶幐椋庣箔婢舵劕绀勯柣鎴炆戦梽?* 闂?缂備焦姊归悧婊兠洪崸妤€绠柡宓唭妤佺箾鐏炲嫨鍊栭崕浼存煕閹烘柨顣兼繝鈧导瀛樺殟闁稿本绮屾禒顖氣槈閹炬剚鐓紒杈ㄧ懅閹噣顢曢敍鍕啰闁诲繒鍋涢崐褰掑垂閵娧€鍋撳☉娆忓闁活亙鍗冲畷銉╁礃閳轰胶顏遍梺鎸庣☉椤︻偊宕?闁荤喐娲戦悞锕傚极婵傜绠伴柛灞剧箖缁佷即鏌ｉ幇顔筋仧缂?
        //       闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亗缁灚绻涙径瀣婵″弶鎮傞獮鎰板磼濮橆叀鍚?*婵＄偑鍊涢崺鏍偉椤曗偓閺屽洭鏁愰崟顓т紘闂?Row**闂佹寧绋戦悧鎾愁焽椤忓嫷鐓ユ慨姗嗗墮琚熼梺闈涙缁€浣烘崲閳ь剟鎮楃憴鍕暡闁轰礁缍婂畷姘辨暜椤斿墽顦梺鍏兼緲婵傛梻绮径鎰強妞ゆ牗绋掑▓璇差渻閵堝洤浠柍?
        .onActionStart((): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan start isClosing=${this.isClosing} ` +
            `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}`);
        })
        .onActionUpdate((event: GestureEvent): void => {
          // 闁荤姾娅ｉ崰鎰櫠濠婂牆瀚夐柣鏂垮悑閿涚喎鈽夐弮鍌氭灁缂?velocityY闂佹寧绋掔喊宥団偓姘儔瀹曟繈濡搁妶鍫濆箑闁诲海鎳撻崯鈺冪箔婢跺簺浜归柛妤冨仦閹瑩鏌涢幒瀣偓鏇㈡偩妤ｅ啯鏅柛顐ｇ箓閻忔煡鎮楃憴鍕鐟滄妸鍥ф嵍闁靛闄勭欢閬嶆煙闂堟侗鍎旈柛瀣噺缁嬪鍩€椤掑倹鏆滅憸蹇涘极閵堝鏅鑸电〒缁€?
          // 婵炵鍋愭慨鍓ф崲濮椻偓瀹曘垻绱掑Ο鎭嶏箑鈽夐幘瑙勩€冪紒顭掔節瀵噣濡烽妷褏顔嶉梻浣瑰絻閻線宕楀鈧畷銉т沪閻愵剦妲梺娲讳簻椤戝懘宕?婵炶揪绲界粔鏈电昂 + 闂備緡鍋嗛崰搴ｂ偓?闂佹眹鍔岀€氼剟鎮鹃鍕瀬閻庢稒蓱闁裤倗绱掗幑鎰堕獜闁?
          this.onDismissDrag(event.offsetY, false, event.velocityY);
        })
        .onActionEnd((event: GestureEvent): void => {
          // 闂?D1闂佹寧绋掔喊宥咁熆濡ゅ懎绠ラ悗锝庡幘缁犵懓鈽夐幘顖氫壕闁汇埄鍨庨崨顔炬殸 `velocityY` 闁诲繐绻楁ご绋课ｉ幖浣圭劵闁绘柨鍢查濠囨煙缂佹ê濮冩慨姗堢畵瀹曟岸濡堕崨顖涙瘞闂佹眹鍔岀€氼垳娆㈤銏犵闁靛鍨崇粈鍒濭estureEvent.velocityY`闂?
          //   `gesture.d.ts` @since 10闂佹寧绋戦張顒€锕㈡导鏉戝珘?SDK 閻庡湱顭堝鍫曟偋瀹曞洠鍋撻悽鍨殌闁宦板姂瀹曠兘鈥﹂幒鏃傤槴闂侀潧妫楅崐濠氼敄娓氣偓瀹曪綁鎽庨崒婊呮喒闂佹眹鍨兼ご鎼佸垂濠婂嫮顩锋い鎺嗗亾濞存粣绲块幏瀣箻閸涱垳顦柣?`onDismissDrag`闂?
          this.onDismissDrag(event.offsetY, true, event.velocityY);
        })
        // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍡涱敋椤旂瓔鐎查柟閭﹀幗閿熴儵鏌?闂佹悶鍎茬粙鎴澝洪弽顐ｅ?闂佹寧绋戦¨鈧紒?*闁哄鏅滈悷銈囩博閹绢喖缁╂い鏍ㄧ懁缁ㄤ即鏌涢幘宕囆ｆ俊鎻掓憸缁辨捇鎼圭憴鍕殸**闂?
        //   婵犮垻鎳撻崯鍧楁儑娴煎瓨鐒介柨婵嗗閻熷繘鏌℃径鍡忓亾閾忣偄鈧京绱掗銈囧笡濠⒀勭矒瀹?*闂備緡鍠涙慨銈咃耿?*闁?闂佺偨鍎查弻锟犲焵?`products/default/闂?Index.ets` L1786闂佹寧绋戝濉穘PullOpenCancel()`闂佹寧绋戦ˇ顓㈠焵?
        //   `MiniBarPlayer.ets` L166闂侀潧妫斿妗痮meMiniBarPlayer.ets` L235 闂?闂佸憡鐟ラ悧濠偽?
        //   "**闂佸憡鑹炬總鏃傜博绾惧浜归柕蹇嬪灩绗戦梺?N 婵犮垼娉涚€氥劑鍩€椤戣法顦︾憸鎶婂洤缁╅梺顐ｇ〒閸熷﹤鈽夐幘顖氫壕婵?*"闂佹寧绋戦悡?6.1.6 闂備緡鍙忕徊鎯ь焽椤栫偛鏋佹繛鍡樺俯閸炴煡鏌ｉ妸銉ヮ伀妞ゆ垵娲︾粋宥囦沪缂併垹浠归梺缁樼矋濠㈡﹢鎳滄导瀛樻櫖濠㈣泛鐗冮崑?
        //
        //   缂傚倸鍊搁幖顐︽偩閻樼粯鍎嶉柛鏇ㄥ亝閸婄敻鏌＄€ｎ偆鐭嗙紒妤€鏈粙澶嬬節娴ｄ警浼囬柡澶屽剱閸犳洟骞堥妸鈺傚剭?`isClosing` 濠电偛鐗嗛鍥汲閳?*闂佸憡鑹炬總鏃傜博鐎靛摜灏?*闂佹寧绋掔喊宥嗘櫠濠婂牆绀夐柤鎰佸灱濞艰泛鈽夐幙鍐ㄥ籍闁逞屽墯濮婅鏅堕敃鍌氭妞ゆ挾鍠愰ˇ?
        //   闂佹寧绋戦悧蹇涙焾鐎靛摜纾奸柣鏃傤焾椤や線鏌?/ 闂佸搫顦崕鎶藉极缁嬭鐔碱敂閸曨厾鏆?/ 闂佺粯鐗曟晶搴㈩殽閸ヮ剙绠柕蹇娾偓鎰佹澒闂?/ 婵＄偑鍊楅弫璇差焽閹殿喗鍋栨い鎰╁灩閻庡ジ鎮硅鎼存粎妲愬姝皀ActionEnd` **濠殿喗锕㈤弲鑼箔婢跺本鍠嗛柨鏇楀亾鐟?* 闂?
        //     閻?`dismissMorphActive` 濠电偛鐗嗛鍥汲閳?`true`闂佹寧绋掗惌顔剧箔閸涱厸鏋庨柍銉ㄥ皺閻熸捇鏌熷畡閭︽Ч婵?`!ended` 闂佸憡甯掑Λ娆撳极椤旇棄顕?*闁荤姴鎼悿鍥╂崲?
        //       `morphBeginLeaving()`**闂佹寧绋戦悧鍡涙偩閻樿鐭楁い蹇撳闊?`!dismissMorphActive` 闂佸搫鍟抽崺鏍ㄦ櫠閻樺灚灏庨梺鍨儏椤や線鏌ㄥ☉姗嗘Т闁?闂佸憡鍨规慨宕囩礊瀹ュ棛鈻旂€广儱鎳庨悡鏇㈡煛閸屾繂鐒介柍褜鍏涘ù鍥╃玻閿熺姴绠ラ悗锝庡枟閺呪晛鈽夐弮鈧崬鑽ゆ?
        //     閻?闂佺儵鏅犻弲鑼礊閸涱厸鏋旈悗锝庡墯濞?`LEAVING` 闂?`morphContainerActive()` 闂佽鍘界敮鐐诧耿?闂?
        //       `beginOpenMorphOnClick()` 闂佹眹鍔岀€氼剟鎮捐瀹曪繝顢曢敐鍛?闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱"闂佸憡甯囬崐鏍垂?**閻庤鐡曠亸娆戝垝閿熺姴鎹堕柕濞垮€楃粣妤呮偣閸ャ劎绠為柛?*"闂佸吋婢橀惉鐓幟洪崸妤€绠?return false
        //       闂?**闂佺粯鍔楅幊鎾诲吹椤曗偓楠炲秹骞樺畷鍥╋紱闂佸憡鐟ラ悧鎾诲焵椤戣棄浜鹃梺鍛婄墬閻楁宕瑰顑炵儤銈ｉ崘顏勫緭闂佸搫鍞查崘銊愭鏌?*闂佹寧绋戦悧濠囶敆濠婂牆鍙婃い鏍ㄧ矋閺嗗繘鏌熼弶鎴濇Щ闁汇倕瀚湁閻庯綆鍓氶悾閬嶆⒑椤撱劎绋绘繛纰卞灦閹偓闁搞儮鏅涚瑧闂佹寧绋戦惌渚€鍩€椤掆偓婵傛梻绮弽褜鍤楅柛顐犲劜椤曟稑顭跨捄铏剐ゆ鐐叉喘楠?缂備礁顑呴崯鍧楁偩妤ｅ啫閿?闂佹寧绋戦ˇ顓㈠焵?
        //
        //   闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ亜閺呭憡绻涙径瀣婵ǜ鍔戝?*闂佺娉涢敃銈堛亹閸パ€妲堥柛顐ｇ箘缁夊ジ鏌熺€涙ê濮堟繝銏☆殜楠?*闂佹寧绋掗悺鐚硁ActionCancel 闂?dragBackEnd(0)`
        //   闂佹寧绋戝濉ecover/logic-src/閻庢鍠掗崑鎾绘煕韫囨碍鐝柟鎼佷憾瀵劑骞嗚閻?闂佸綊娼ч鍛箾瀹ュ洦宕夋い鏍ㄦ皑缁愮偤鎮楃憴鍕殤妞?md` 闁?.3闂佹寧绋掗崺鍐箟?闂備緡鍙忕徊鎯ь焽椤栫偛绠ラ悗锝庝簻閳笺垽鏌涢妷锔锯棩闂佸弶绮撳畷鍫曟倷閸撲焦顔嶆慨鎺旂帛閸旀洟宕ｈ箛娑欐櫖?
        //   cancel 闁荤姍鍕棆婵炲牊鍨垮?`pullEnd(0)`闂佹寧绋掔粙鍫ュ箠?闁?`dragBackEnd(0)`闂佹寧绋戦ˇ顓㈠焵?
        //   闂佸疇娉曟刊瀵哥箔?`velocityY` 闂婎偄娲ら幊姗€濡磋箛鏂款嚤?**0**闂佹寧绋掗懝鎹愩亹閸パ€妲堥柛顐ｇ矌閻熸繈鎮归崶銉ュ姤妞ゎ偓绠掗妵鎰板箻閺夋垹浜?闂婎偄娴傞崑鍡涘极?闂佸吋婢橀張顒冦亹娴ｅ湱顩查柕鍫濇閺嗩亪鎮硅閸ゆ牜妲愬淇stFlick` 闁?闂?00闂佹寧绋戦ˇ顓㈠焵?
        .onActionCancel((event: GestureEvent): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan cancel offsetY=${event.offsetY.toFixed(1)} ` +
            `dismissMorphActive=${this.dismissMorphActive} ` +
            `stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive}`);
          this.onDismissDrag(event.offsetY, true, 0);
        })
    )
    // 闂佸疇妫勯幊澶娢?2026-10-15闂?*闂侀€涘嫎閸婃洖煤閺嶃劎鈻斿┑鐘辫兌椤忛亶寮堕悜鍡楁灓婵炲牊鍨剁粙澶愬焵椤掍礁绶為柛鏇ㄥ墯閺嗩參鏌?*闂佹寧绋戦懟顖炴嚐閻旂厧绠┑鐘插€搁弬褔鏌涢妷褍孝闁哥喐鎸搁妴?闂佺偨鍎查弻锟犲焵?闁荤喐鐟ゅ鎺旂箔閸涘瓨鏅?
    //
    // 婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏃囨閻忓鏌涢敂鍝勫缂佺粯鐗犻弻灞界暆閸忣垰顦板?`.id(MORPH_HOST_ID)`闂佹寧绋戦惉濂稿箖婵犲洦鍋ㄩ弶鍫涘妽绗?闂佸搫鐗滈崗娑氬垝閵婏妇鈻旈柕鍫濇媼濡茶鲸绻涙径鍫濆闁革絾鎸抽弻鍫ュ磹閻曚礁娈梺褰掓涧椤戝棗鈹冮埀顒€銆掑鈧崱娆戭啇婵?id
    // 闁诲繐绻楁ご绋课ｉ幖浣哥妞ゆ挾鍠愰弶鐟邦渻閵堝嫮绁烽柛銈嗙矊椤斿繑娼忛埡鍌滄殸闂佸搫绉堕幊鎾活敊閹版澘闂い顓熷笧缁€澶愭煠閺夋寧婀伴柟鎼佷憾瀵劍銈ｉ崘锔瑰亾婢跺顩烽幖娣灮濮婇箖鏌熺粙鍨偓鐣屾崲閸愵亖鍋?闂?*闂備緡鍙忕徊濂告煂濠婂牊鍋犻柛鈩冪懄閺嗙娀鏌￠崟闈涚仸闁轰礁锕幆鍐礋閸撲胶顦悗鍦焾瀵爼骞愬▎鎾崇倞闁绘劦浜栭崑?*
    //
    // 闂佹椿浜為崰鎾趁规径鎰櫖闁割偆鍠愰幏閬嶅级閻戝棗鏋涢柛娆忕箲缁傛帡骞樼€电顥愰柣搴ｆ暩濞呫垻妲愬鑸垫櫖?
    // ```
    //   .id(MORPH_HOST_ID) 闂佹眹鍔岀€氼喚鍒掗敂閿亾鐟欏嫭鐨戦柛瀣剁秮閺?
    //     products/default/.../Index.ets:1796   闂?婵犮垻鎳撻崯鍧楁儑?*闂?Stack**闂?*闁汇埄鍨遍幃鍌炲煘?*闂佹寧绋戦惌渚€锝為崱娆屽亾閻熸澘鏆㈤柛銈嗙矊椤斿繘鏌嗗鍛凹濠电偛鐗嗛悘姘跺极閻愮儤鐓傚┑鐘茬箳缁€?
    //     products/pc/.../Index.ets:345         闂?PC 婵犮垻鎳撻崯鍧楁儑娴兼潙鍐€?Stack闂佹寧绋戦悧鍡涙偉閼哥偣浠氬ù鍏肩懅缁€?
    // ```
    // 闂?闂佸綊娼ч鍡椻攦閳?*闁荤姳璀﹂崹鎶藉极閸楃倣鐔煎灳瀹曞洨顢?*婵炴垶鎸搁鎴犳濠靛绠绘い鎾跺枑閺夌懓顪冮妶鍛粵婵℃彃鎲＄粩鐔煎礃閼碱剚鍕鹃梺?Stack 闂備焦褰冮惌鍌炲磻閸涱喚鈻?`HdsNavigation` 闂?*闁诲孩绋掗崝妯讳繆椤撱垺鍊?*
    //   闂?婵炴垶鎸堕崐鎾绘煂濠婂牊鍤嶉柛灞剧矊娴?*闂佸憡鑹鹃張顒€顪冮崒鐐叉嵍闁靛ě鍛厑婵炲濮鹃崺鏍偉閸欏鈻?*闂侀潧妫楅崐瑙勬櫠瀹ュ棛顩烽柕澶樺灣缁?
    //     閻?**缂傚倷鐒︾换鈧紒妤€顦甸幊?*闂侀潻璐熼崝宥夊箰闁秴缁╁Δ锝呭暔閳ь剙顦板璇测枎鎼达綆浼囬柣蹇曞仜閸婃悂宕埀顒勬煙缁嬪灝鈧绮╅弶鎴旀瀻?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯ｉ幖浣肝?*闂?id 婵炴垶鎸堕崐鎾诲船閵堝鍤嶉柛灞剧矊娴?*闂侀潧妫楃粙鍕?
    //       闂佸吋婢橀張顒€锕㈤悧鍫㈩浄闁圭偓鍓氶崵鐘诲级閳哄倻鎳佹繛鍡愬灪缁傚秶鈧綆鍋呯粻鎺楁煛閸曨偅鎹ｉ柍銉︻焽閹峰寮剁捄銊梺鎸庣☉濞煎「roducts/default/.../Index.ets` 闂佺绻愰崢鏍姳?`MINI_BAR_ID` 闂佹眹鍔岀€氼亞鎮潏銊ョ窞闁告洦鍓氶弳鍫ユ⒑閹绘帩鐓紒?
    //       "婵炴垶鎸堕崐鎾诲船閵堝瑙?id 闂佹眹鍔岀€氼垱淇婇銏″€烽柣褍鎽滅粈濉etRectangleById` 闂備焦褰冪换鎰板春瀹€鍕紶妞ゅ繐鍟伴鍗灻归悩鍐茬亰缂佹顦卞☉鐢割敊閼测晜姣庨梺鎸庣☉閻線骞戦敐澶嬪€烽柣鐔哄閻ㄦ垿鏌?闂佹寧绋戦ˇ顓㈠焵?
    //       
    //     閻?婵炲瓨绮岀€涒晛危?`PlayerExpandState.measureGeometry()` 闂備焦褰冮惌鍌炲磻閸涱喚鈻?
    //       `measureNode(ui, MORPH_HOST_ID)` 闂?*闂佸綊娼ч鍡椻攦閳ь剟鎮规笟顖氱仯闁轰礁宕灒闁炽儱纾涵鈧繛?*闂備焦褰冪换鎰板春瀹€鍕剭闁告洦鍓氱瑧**婵犮垻鎳撻崯鍧楁儑娴煎瓨鐒介柨婵嗗椤忛亶鎮?*
    //       闂佹寧绋戦悧鎰板焵椤掆偓婵傛梻绮径鎰強妞ゆ牗绋掔亸锟犳煛閳ь剚銈ｉ崘锔瑰亾婢舵劖鍎嶉柛鏇ㄥ櫘濮婂潡鏌涢幙鍐х敖闁绘稏鍎靛畷锝夋晲韫囨洜顦梺鐐藉劜閺岋繝鍩€?闁哄鏅滈悷锕€危?*闁诲酣娼у﹢鍗炩枔閹达箑违濞达綁顥撻惁宥嗘叏濠垫挾绋绘俊鎻掓憸閳ь剛鎳撻崯顖炲礂閸屾粍鍟哄ù锝囧劋閻?*闂?
    //       闁诲海鎳撻崯顖涗繆閸濄儳纾奸柟鎯ь嚟娴滎垶鏌涘▎妯圭盎闁哥喐鎸诲璇测槈濞嗘劧绱氶棅顐㈡处椤ㄦ劗妲愬淇琽stNode=闂佺偨鍎哄▔锕傛煥濞戞﹩妾х紒杈ㄧ箞閻涱噣寮甸悽鐢垫噸闂侀潻璐熼崝搴ㄥ箵閿濆鐒介柤濮愬€栭悾杈ㄧ箾婢跺牆濮傞柛锝嗘尦閺屽苯鐣濋埀顒勫磻閿濆瑙?
    //       "**缂傚倷鐒︾换鈧紒妤€顦甸幊妤呮嚍閵夈儳鎲﹂柣搴ｆ嚀閸燁偆绱炵€ｎ喗鐓ｉ柣鎴灻慨顒勬煟閳哄﹤鏋熼柣?*闂佹寧绋戦悧鎾诲磻閸涙潙鍙婃い鏍ㄧ矤閸庢垵霉濠婂嫭鈷愭い鎰偢閹虫盯顢旈崟顒傚建闂?闂?
    //     閻?婵炴垶鎸搁敃锝囩博鐎涙ɑ濮滄い鏃囨閻忓鎮归崶璺虹仧濞存粍甯楃粙澶愭倻濡亶?濠电姵娲栫换鎴犫偓? 闂?缂傚倷鐒﹂幑渚€顢欓幋鐘冲闁靛繆妲呴崝鈧繛鎴炴尵鐏忋劎妲?*闁哄鏅滈悷锕€危閹间礁绀嗙紓浣姑竟鍫ユ煟閵娿儱顏ラ柍褜鍏涢悞锕傤敆濠婂懏鍏滄い鏃傚亾閻?*闂?
    //
    // 闂佸疇娉曟刊瀵哥箔?闂備緡鍙忕徊鑲╂偖鏉堛劌绶為柛鏇ㄥ亜閺呮悂鏌ｉ鐔蜂壕"闂佸綊娼ч鍡椻攦閳ь剙銆掑鈧崟顒€鍟婇梺琛″亾濡わ絽鍟ㄩ埀顒€顦靛?Stack 闁诲繐绻楁ご绋课?`MORPH_HOST_ID`"闂佹眹鍔岀€氼參寮悙鐑樼厒?*闂佸搫瀚烽崹鍫曞极婵犲洦鍎?*闂?
    //    閻庣懓鎲¤ぐ鍐潩閵娾晛鎹堕柟宄扮焾閸氬倹鎱ㄥ┑鎾剁Ф缂佽鲸鐟ч幉?`PlayerExpandState.measureGeometry()` 婵?`contentWidthVp/HeightVp` 婵炴垶鎸堕崐鏇⑺囬埡鍛櫖濠㈣泛鐗冮崑?
  }

  /**
   * 閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮悑閿?缂傚倷绶￠崣鍐夐敐鍥︾剨濞撴埃鍋撴繛?濠电偞鎯岄崰鏍儑娴煎瓨鏅慨姗嗗亞椤忚京鈧鍠氭慨楣冨礉濮樿京鐭夐悹鍥皺椤忔挳鎮橀悙鈺佷壕闂侀潧妫旈悞锔锯偓鍨矌閳ь剛鎳撻妵妯尖偓闈涚焸瀹曟悂骞囬鐘茬伇闂佺妫勫Λ娆撳棘娓氣偓閹啴宕熼銈嗩唸闂傚倸鐗滃鍧楀焵?
   *
   * 闂佸疇娉曟刊瀵哥箔?**2026-10-15闂佹寧绋掓穱铏规崲閺嶃劎鈻旈柍褜鍓欒灋闁圭儤鍨甸崵鎺旂磽娴ｅ摜绠查柟顖氼樀瀹曟岸寮堕崠锛勫闁诲繒鍋涢崐鍦嫚閻愬吀娌?*闂佹寧绋戝濉坣dex.ets` 闂?`MorphCoverClone()`闂佹寧绋戦¨鈧紒?
   *    闂佸搫鐗滈崜鐔煎Υ婢舵劕鐭楁い蹇撳闊?`hostsMorphOverlay()` 婵炴垶鎸搁幖顐ｇ閿濆鍎嶉柛鏇ㄥ亽閸熷繐鈽夐幘鑼覆缂佽鲸鈹奀 婵犮垻鎳撻崯鍧楁儑娴煎瓨鏅璺侯槺閻熸劙寮堕埡鍌ょ劸闁汇劎鍠撻埀?闂佺偨鍎查弻锟犲焵?
   *    闁荤姴顑呴崯浼村极閵堝鍊烽梺顐ｇ〒閻熸劙鏌ｉ妸銉ヮ仾闁轰胶鍋ら弻灞剧節閸屾碍娅㈠┑鐐存尭閹冲秶鑺遍埄鍐枖閺夌偞澹嗛惌鍡椻槈閺傝法澧戦柍褜鍓欓崐鎼佸吹闁秴鏋佸Λ棰佽兌缁夌厧菐閸ャ劎绠橀柡鍡忓亾闂佹寧绋掗悺宀?闂備緡鍙忕徊鎯ь焽椤栨粍宕夋い鏍ㄧ懅閻繈鏌ｉ幒鎴犲煟婵炴挸澧庨幉鐗堟媴閸濄儲娈滈梺?
   *    闂佸吋婢樻總鏃傜箔閺嶎厼绀嗛柣妯哄暱缁旀挳鎮楅悷鏉挎殭婵ǜ鍔岄銉ノ旈埀顒勫箖閹捐绫嶉悹鍝勬惈閻忊晠鏌?PC 闂佹眹鍔岀€氼剟鎯冨┑瀣棃闁靛繒濮风粔鍏间繆椤愶絽閲滅紒杈ㄧ懇閺屽洭鏁愰崱妯烇箓鏌涘▎娆戠窗缂佹柨鐡ㄧ粋鎺楀嫉閻㈢數娈ら梺鎸庣☉椤︻參鍩€?
   *
   * 闂傚倸鐗婇悷锕傤敆濞戙垹绠?*婵炴垶鎸哥粔铏殽閸ヮ剚鍋ㄩ柣鏃囧煐瀹曟彃霉閿濆棙绀夊┑鈽嗗弮閹?*闂佹寧绋戝濉祇rphBridging()` 婵?false闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲秹鍩€椤掍胶顩烽柕澶堝劤閺嗗﹤鈽夐幘宕囆㈢憸鐗堢叀閹虫鎸婃径濠庢闂佸憡绻傜粔鐟邦焽閵堝绠戝ù锝呮憸椤忔挳鎮橀悙鈺佷壕闂?
   * `HitTestMode.None` 闂佸搫瀚烽崹鎵崲閳ь剙顪冮妶鍫濆惞婵炲牊鍨块弫宥咁潩椤撶喐顔掗柣蹇曞仜閸婂潡骞楅棃娑辩叆闁炽儱纾灞绢殽閻愬瓨绌跨紒杈ㄧ箖椤偓婵☆垱顑欓崥鍥煕濞戞瑥鐏婇柤鍨灴閹啴宕熼鐐枔婵炴潙鍚嬬喊宥嗕繆閹间礁绠绘い鎾跺枑閺夌懓顪冮妶鍛粵濠⒀冪Ч瀵灚寰勭仦鎴掑寲闂佸憡鍨奸褔骞冮崱娑樼濠㈣泛鐗冮崑?
   */
  @Builder
  MorphCoverBridge() {
    Stack() {
      Image(this.currentCoverSource())
        .width(this.expandState.morphCoverBridge().size)
        // 闂佸疇娉曟刊瀵哥箔?婵°倕鍊归敋閻?*闂佸憡顨嗗ú婊呪偓姘煎弮瀹?*闂佹寧绋戦悧鍛箔婢舵劕绀冪€广儱鎳庨弲鍛婃叏濠靛牏甯涢柛?`size`闂佹寧绋戦¨鈧紒鍙樺嵆楠炴﹢顢橀悢鍛婃緬婵＄偑鍊濆褔鎯冨┑瀣棃闁靛繒濯Ο鍡涙煛?`layoutWeight(1)` +
        //    `constraintSize(maxWidth/maxHeight)`闂佹寧绋戦惌鍌炲闯濞差亜绀嗛柟娈垮枟閻ｉ亶鏌ｉ娑欐珔闁煎摜澧楃粙澶婎吋閸曨厾顔旈柣鐘叉矗閻掞箑危缁嬫娼伴柨婵嗘閻撴瑧鎲搁柇锔藉▏闁?
        //    闂佸湱顭堥ˇ浼搭敆濠婂牆妫橀柣鐔稿閸╁矂鏌ｉ姀锝庡殭闁搞値鍙冨鍫曞Ψ瑜庨悾杈╃磽娓氬洤寮い銉悼娴滃憡绗熼埀顒€顭囨导瀛樻櫖閻?1 婵炲瓨鍤庨崐鏍夊Δ鍐＜婵炲棙鍨堕崺鍌炴倵閸︻厼浠滈柣銊︾箞濡啴濮€閵忥紕鏆犻梻渚囧弿缁茶偐绮╅幘顔肩閻犲洤寮堕惃鎴澝归崗闂翠孩闁绘埊闄勭粙澶愬焵椤掍胶鈻?
        //    闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎戞繛鍫熷灴婵℃潙鐣濋埀顒傚垝閵娾晛绾ч柣鏂挎啞椤ρ囨倶韫囧海绐旀繛鑲╁閹峰懎顓奸崶鈺傜€?婵犮垹鐖㈤崘顏呯槗闁荤姴鎼崢鏍博鐎涙鈻旈悗锝冨妷閸嬫挸顓艰箛鏇狀槴闂?
        .height(this.expandState.morphCoverBridge().height)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.expandState.morphCoverBridge().radius)
        .clip(true)
        .position({
          x: this.expandState.morphCoverBridge().x,
          y: this.expandState.morphCoverBridge().y
        })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .opacity(this.expandState.morphBridgeOpacity())
    .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垺鎮堕埀顒€锕弻鍫ュΩ瑜庨悾閬嶆煏閸℃瀚伴柣銊︾箞濡?+ 濠殿喗绻傞懟顖炲箖?濠殿喗绻傞張顒佹櫠濠婂牆违鐎广儱妫滈惂渚€鎮橀悙鎻掍喊缂佽鲸鐟ч埀顑跨祷椤鎮ラ敐澶婄睄闁绘ê鐏氬▍?`PlayerPage.floatingCover` / `floatingMeta`闂佹寧绋戦ˇ顓㈠焵?
   *
   * ## 闁诲海鎳撻崯顖毼ｉ崨濠勵浄闁逞屽墯缁嬪﹪宕奸鍌滎槱A2闂佹寧绋掔喊宥嗙椤旇棄绶炵€广儱鍟犻崑鎾朵沪閸撗勬啓闁荤姴娲ょ粔褰掑Υ婢跺浜滈柛顐ｆ礀閸斻儵鏌￠崼婵愭Ц闁汇劍绻堝Λ?+ 濠殿喗绻傞張顒€煤閹间礁瑙︾€广儱娉﹂悙鍝勎ョ€广儱绻掔粈?
   *
   * 闂佸搫鍟版慨鐑藉疾椤愶附鍎?`playerPane` 闂?`Stack { Swiper{ 闁诲繐绻嬬欢姘焽閻楀牄浜?; **缂?*濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻?} ; floatingCover ; floatingMeta }`
   * 闂佺偨鍎查弻锟犲焵?闁诲繐绻嬬欢姘焽閻楀牏鈻旈幖娣灮閹藉啴鏌涘顒傂ｉ悗鍨礋瀹?`Swiper` **婵炴垶鏌ㄩ鍛此?*闂佹寧绋戦懟顖炲垂韫囨稑绀嗛柣妤€鐗忛幗鍐偣閸パ呅ч柕鍡楊樀瀵?*闂佸憡鑹炬總鏃傜博鐎涙鈻旀い蹇撳鐢绱?*缂傚倸鍊甸弲娑㈡儍椤掑嫮宓侀柛鎾茬悼閳哄懎绀嗗ù鍏肩暘閳ь剙锕弻鍫モ€﹂幒鏂胯€?
   * 濠殿喗绻傞惌渚€鎯佸┑鍥ヤ簻闁汇垻顭堟禍婵嗏槈閹绢垰浜炬俊鐐€曢悘姘耿娴煎鍙曟い鎰╁灩濞懷囨煛?`padding({ top: lyricPadTop() })`闂侀潧妫楅崐鐣屾崲閺嶎厽鐓傞悘鐐跺Г閻ㄦ垿鏌￠崟闈涚仸闁稿鎳忕粙澶愬焵椤掑倷娌柛灞厩氶崑?
   *
   * ## 婵炴垶鎸搁ˇ顕€鏌屽鍛／闁挎棁濮ょ亸鍡涙煥濞戞澧㈢€规瓕椴哥粙澶愬焵椤掑嫬绾ч柍銉ㄦ珪閻ㄦ垵霉閸忚壈澹橀柛銈庡弮閹虫挻鎷呴崷顓熲枍闂佹眹鍎遍幏鎴犳?
   *
   * 1. **闂佸憡鑹炬總鏃傜博閹绢喖绫嶉悹鍝勬惈閻撴繈鏌ゅ畡鏉挎毐妞わ附瀵х粙澶愬焵椤掆偓椤曪綁鎮╅懠顒侇唸闂?*闂佹寧绋掔喊宥咃耿閺夋５褰掝敊閼测晜鍕鹃梺鍦焾閸婅棄霉?闂?闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏㈩焾娴滄繂霉閻樺灚娅曟繝鈧敍鍕剨濞撴埃鍋撴繛鍏煎閹?`.opacity(0)` 闂佽姤锚缁绘骞戦敐澶婄骇?
   *    闂?闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本绋掔瑧**闂佸摜鍎愰崹顖滅博?*闂佹眹鍔岀€氼剟鎯冨┑瀣棃闁靛緵銈庢船闂佸搫鏈幑渚€鍩€椤掆偓閹锋垹妲?*濠电偛澶囬崜婵嗭耿?婵炴垶鎸堕崐娑㈠焵椤掆偓閹冲秶鑺遍幍顔藉仒?闁哄鏅滈悷銉ッ洪弽銊ь洸閻庯絺鏅濋崯?*闂佹寧绋戝濉磞ricFloatActive()` 閻庣懓鎲¤ぐ鍐垂瑜版帗鏅璺虹墐閸?
   *    闂佹寧绋戦悧濠勬嫚閻愬吀娌?`t = 0` 闂佹椿娼块崝搴♀枔閹寸姳鐒婇弶鍫涘妽绗戦梺娲讳簽閸犲酣鎯冨┑瀣棃闁靛繈鍨洪悾閬嶆煢閳ь剟鎮剧仦鎴掑寲闂佸憡鍨规慨宕囩礊瀹ュ鏅€光偓閸愮偓缍?`PlayerExpandState.lyricMorph`闂佹寧绋戦¨鈧紒?
   * 2. **闂傚倸鐗婇悷锕傤敆濞戙垹绠戝ù锝夘棑閻熸繂霉濠х姴鎳忛弲绋款熆閼哥數鐓紓宥嗗灴閹崇偤宕掑鍐у寲**闂佹寧绋掗懝楣冩儍濠靛顥堥柕蹇嬪€戦埀顒€顦靛Λ鍐ㄢ枎閹伴潧澹橀梺?`lyricMorphT = 0` 闂?闂佸憡鐟﹁摫鐎规洖寮剁粙澶愭倻濡鍩呯紓浣圭☉椤︻參鍩€椤戞寧顦风紓宥呮噽缁辨棃顢欓悡搴ｃ偖闁汇埄鍨伴崯顐︽儑椤掍焦濯?
   *    闂佹寧绋戝濉磞ricFloatActive()` 闂備緡鍙忕徊鐐繆閹间焦鈷掗柕濞垮劚閸ゆ帡鏌涢幒鏂库枅婵?闂佺偨鍎查弻锟犲焵?闁荤喐娲栧Λ娑樏烘繝鍕勃闁稿本姘ㄩ崺妤€顪冮柅娑氫覆缂佽鲸绻勯幉?闁圭厧鍊荤划?2 闂佺鍕垫缂佽鲸宀告俊?
   *    `if` 闂佸憡甯掑Λ娆撳极椤曗偓閹嫮鈧稒锚婢跺秴鈽夐幘宕囆㈢紓鍌涙崌閹崇偤宕掑鍐у寲 闂?闂傚倸鐗婇悷锕傤敆濞戙垹鎹堕柕濞垮劤濞堥亶姊婚崼娑樼伈闁靛棗顦靛顕€宕滄担鍓叉毉闂傚倸鐗滃鈧紒妤€鑻埢浠嬪焺閸愨晝鐣抽柡澶嗘櫆閻熴儵銆冨鍕枖婵犲﹤妫庨崑?*闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯夸含椤忛亶鏌?*闂?
   * 3. **婵炴垶鎸哥粔鎾箖閸℃瑦鍠嗛柨鏃囧Г閸?*闂佹寧绋掗悺鐙tTestMode.None`闂佹寧绋戦悧鍛箔?`MorphCoverBridge` 闂佸憡鑹鹃張顒勵敄濞嗘挻鏅璺烘閸嬫捇寮悰鈥充壕?
   *    闂佽桨鐒﹀娆撴儑娴煎瓨鐓ｉ柣鎴灻慨顒勬倶閻愯尙绠扮紒鐘靛厴閺佸秴鐣濋崟顓炵闁荤姳闄嶉崐鏇㈠箠閳╁啰鈻旀い鎾跺У閻ｉ亶鎮归崶銊х畱缂佸彉鍗抽獮搴㈢節閸愵亝鎲欓柣鐘叉搐缁夎泛鈻撻幋婵愮叆婵﹩鍓欒婵炴垶鎸稿ù鐑藉磻閿濆绀勯悹鍥ㄥ絻瀵潡鏌涘顒€鏆為悽顖楀亾闂?
   *
   * ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ゅ枎閻︻垶鏌涢敂鍝勫缂佺粯鐗楃粙澶愵敂閸愵亞孝缂傚倸鍠氶崳顖滄濡句總tack`C 闂佹眹鍔岀€氼厼銆掗崼鏇炶Е閹煎瓨绻勯鍗炩槈閹垮啩绨绘い鎺嬪灮閳ь剚绋掗崝褏妲愬鑸靛殌閻忕偠鍋愰悷婵嬫煛閸曢潧鐏犻柨娑欐尵娴?
   *
   * 閻?**闂佺鍕闁绘牭缍佸畷锝夋晲閸涱垳鐛?*闂佹寧绋掔喊宥咃耿閹殿喕娌柛灞剧煯缁狀垰鈽夐幘绛归練妞ゎ偅顨堟禍鍛婃綇閵娤€锔剧磼閹邦収娈旂憸鐗堢洴瀹曘垽鎮㈤崫鍕寲闂佹寧绋戦悧鍛箔?`MorphCoverBridge` 闂佸憡鑹鹃惉鍏碱殽閸ヮ剙违濞达絽鎲￠崐閬嶆煕濞嗘瑧鍒扮紒?闂佺偨鍎查弻锟犲焵?
   *   闁诲海鎳撻崯顖溾偓鍨矌缁絽螖閳ь剝銇愬☉銏犻敜闁归偊鍘鹃崹?`.position()` 闂佽В鍋撻柟瀛樺笧缁夋挳鏌?*閻庤鐡曠亸顏堬綖閿曞倹鍎戦柣鏂挎啞缁ㄦ艾螖閻樿尙鐒烽柣锕€顦板?*闂佹眹鍔岀€氬摜妲愬鑸垫櫖閻忕偞鍎抽。鎻捗?`lyricMorph()` 婵炲瓨鍤庨崐鏇㈠吹椤撱垺鍎?
   *   缂備焦鍔栭〃鍛般亹濞戙垹閿ら柟閭﹀幘閸ㄥジ鏌涘▎妯虹仧濞存粍甯￠幆鍕偓娑櫭径宥囨喐?`.position()` 闂佹眹鍩勯悡澶屾?*闂佺绻堥崝鎴﹀箺婵傚憡鈷栭柤鎼佹涧鎼村﹦绱?*闂?
   * 閻?**闂婎偄娲ら幊姗€濡磋箛鏇熷磯闁绘梻鍎ょ徊鑽ゆ喐閼割剙鐏╃憸鏉款槹缁嬪鍩€椤掑倹灏庡瀣捣缁?*闂佹寧绋掗懝楣冩偩閻樿鎹堕柕濞垮妿缁犵懓鈽夐幙鍐ф捣妞?`scale + translate + clip` 闂佸憡鐟﹁摫鐎规洖寮跺濠氬炊閳哄倻鏆犻柣搴℃贡閹虫挸鈻嶉幒妤佺厒鐎光偓鐎ｎ剛顦?
   *   闂佽　鍋撻柟顖滃瀹曟娊鏌熺紒銏犲箺闁哄倷鐒﹂妵鍕垂椤愶綆妲┑鐐存儗閸犳牠鎯囬幍顔藉磯闁绘梻鍎ょ徊鑽ょ磽閸屾娅旂紒閬嶄憾楠炴劙宕掑顒傚帓闂?`Stack`闂佹寧绋戦悧鍡氥亹婢舵劕绠叉い顐幘椤撳搫顭块懜鐢靛缂佽鲸姘ㄦ禍鎼佸矗濡偐鐛?婵＄偑鍊楅弫璇差焽閹殿喚纾介柍鐟扮氨閸嬫挻鎷呴崫銉︻唸闂傚倸鐗滃鈧紒妤€顦辩槐?闂?
   *
   * 闂佸疇娉曟刊瀵哥箔?濠殿喗绻傞惌渚€鎯佸┑瀣畱閹煎瓨绻勯悿鍕煟?*婵炴垶鎸撮崑鎾斥槈閹垮啩绨婚柣鈯欏啠鏌﹂柍銉ュ暱琚?*闂佹寧绋戝濉媦ricsComponent` / `AmllLyricView` 婵炴垶鎸哥粔鍫曪綖椤愶附鏅璺虹墐閸?
   */
  // ⚠️ 读法提示：紧邻**上面**那段 JSDoc 属于下面那个 `LyricFloatLayer()`（本方法插在中间，
  //    只是为了让"小歌词的位置"排在"浮层盒模型"之前讲）；`MiniLyricLinesBlock()` 的说明从下一行开始 ↓
  /**
   * 封面页的小歌词块（**只属于 Swiper 第 0 页**）。
   *
   * ## 一、位置：不写任何定位算式，交给主轴排布
   * 它是 `metaRow` 里「歌名/歌手」那一列 `Column` 的**第 3 个子节点**，排在 `Text(歌名)`、`Text(歌手)`
   * 之后，于是主轴上自然得到：
   * ```
   *   小歌词顶边 ≡ 歌名行盒顶边 + title.h + 2 + singer.h = **歌手文字底边**
   *   x          ≡ 歌名/歌手文字左缘（同一个 Column；`metaRow` 的 `padding.left =
   *                lyricMetaLeftInset()` 已在这条链上，所以两边**同一个口径**，不需要再抄一遍 margin）
   * ```
   * 两个等式**不经过任何实测、也不经过 `estBoxHVp()` / `metaOffsetY()`** ⇒ 字号、行高、
   * 用户字体缩放怎么变都成立。这也正是前两轮两次错法的解药：
   *   ① 更早那版用 `.position({ x: 0, y: miniLyricTopY() })`（**窗口绝对 y**）⇒ 与歌名行的
   *      「居中盒 + offset」是两套坐标系，`estBoxHVp()` ≠ 窗口高就必然偏；
   *   ② 上一轮那版用 `.offset({ y: metaOffsetY() + 块高/2 })` 去补"居中盒把整组上抬 h/2"
   *      ⇒ 结论依赖"组高恰好 = 34 + 57"，任一子节点的高度/显隐一变（例如切到歌词页要藏起来）
   *      这个等式立刻失效。
   *
   * ## 二、只在封面页显示（治"划到歌词页出现两份歌词"）
   * 播放页上同时存在两处歌词渲染：
   *   · **歌词页那份** = Swiper 第 1 页里的 `LyricsComponent`（`buildControlStack()` 的
   *     `Swiper() { … 第 1 页 Column() { LyricsComponent({…}) } }`，本文件内）；
   *   · **本浮层这份** = 本 @Builder。
   * 上游口径：`playerPane` 的 Swiper **第 0 页是空壳**（`wujie.pa:189547-189573`，零子节点），
   * 歌词只出现在第 1 页的 `LyricsView`（`wujie.pa:189574-189659`）；而歌名行那个浮层
   * （`floatingMeta`）是**两页共用**的。⇒ 小歌词必须跟着"回到封面页"这件事消失。
   *
   * 判据只用本仓既有的量、不新造状态：`lyricMorphT`
   * （`syncLyricMorphToPage()` 维护：0 = 封面页 / 1 = 歌词页，拖动过程中由 `onContentDidScroll`
   * 连续写值），**与歌名行的位置用的是同一个源** ⇒ 两者不可能打架；本文件里同一个阈值
   * `0.001` 也已用在 `lyricMorphT > 0.001` 那处判定上。
   */
  @Builder
  private MiniLyricLinesBlock() {
    Column() {
      MiniLyricLinesComponent()
        .width(StyleConstants.FULL_WIDTH)
        // 淡入与歌名行同一个源（`pullChromeOpacity`，`wujie.pa:176459-176505`），再乘用户拍过的 0.55。
        .opacity(this.expandState.pullChromeOpacity() * PlaybackPage.MINI_LYRIC_OPACITY)
        .id(PlaybackPage.MINI_LYRIC_BOX_ID)
        .onAreaChange((): void => {
          // 只做诊断：`RzdBoxes` 的 `lyric=` 读这个 id 的矩形（判据见 `logLayoutBoxes()`）。
          this.logLayoutBoxes();
        })
    }
    .width(StyleConstants.FULL_WIDTH)
    // 高度钉死（57 = 2×26 + 行距 3 + 上边距 2）：它在"定高 34"的文字列里是**溢出**的兄弟；
    // 不钉的话块高会随风变动（字号/行高一变，歌名/歌手两行的排版跟着抖）。
    .height(PlaybackPage.MINI_LYRIC_BLOCK_H_VP)
    .justifyContent(FlexAlign.Start)
    // ⛔ 不再挂 `.translate({ y: metaRiseVp() })`：外层位移壳已经在做同一条位移，再挂一次就是**双倍**升入。
    //
    // 只属于封面页：见本 @Builder 的 JSDoc 第二节。`Visibility.None` = 不占布局 + 不绘制，
    // 它又只是"定高 34 的文字列"里的溢出兄弟 ⇒ 藏掉它不会让歌名行移动一个像素。
    .visibility((!this.isCollapsing() && this.lyricMorphT <= 0.001) ? Visibility.Visible : Visibility.None)
  }

  @Builder
  private LyricFloatLayer() {
    // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌?`floatingCover`闂佹寧绋戦¨鈧紒?*闁汇埄鍨遍幃鍌炲煘?+ 闂佸憡鐟﹁摫鐎规洘褰冮?*闂?
    //
    //   闂?闁汇埄鍨遍幃鍌炲煘濡ゅ懏鏅慨姗嗗墰濞堥亶姊婚崼娑樼仾婵?`playerPane` 闂備焦褰冩總鏃傜博鐎涙鈻旀い蹇撴噸閼割亪鏌涢敂鍝勫婵炲牊鍨归幉浼村幢濞嗘劗锛愰柣蹇曞仜閸嬪﹦妲愬┑瀣棃?`scale/translate` 闂侀潻璐熼崝瀣偖鏉堛劎鈻旀い蹇撴－娴煎倿鏌ｉ幇顒傜Ш婵☆偄娼￠獮鎾诲箳閹存柨浜剧痪顓㈩棑缁€?
    //      闂佸湱顣介崑鎾趁归悩顔煎姦闁?0 婵炴垶鎸哥粔鎾疮閳ь剟鏌ｉ姀锝庡殭闁汇劍绻堝Λ鍐綖椤斿墽顦╅梻渚囧弿缂嶄線宕冲畡閭﹀晠闁圭粯甯掗悘?`MusicPlayInfoBlock`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?**闂佺绻堥崝搴ㄥ煝婵傜鐭楁い蹇撴噺缁犳帒鈽夐幘顖氫壕婵炲濮惧Λ鍕儍濠靛顥?*闂?
    //   闂?闂佸憡鐟﹁摫鐎规洘褰冮锝堢疀閵壯呯崶闁汇埄鍨伴崯顐︽儑椤掑嫬鏄ラ柛婵嗗濞呮瑩鎮樿箛鎾存儓妞ゆ洦鍙冨畷?`playerCoverGeomRect()`闂?*缂備胶铏庨崹浼村吹閹寸偞濯撮柡鍥ㄇ氶崑鎾存媴妞嬪海鎲归梺鍝勮閸庡瓨淇婇銏″€?*闂佹寧绋戦¨鈧紒?
    //      闂佸憡鐟禍婵嗭耿?`scale/translate` 婵炴潙鍚嬬喊宥囦焊閹惧灈鍋?闂?`t = 0` 闂?*婵炶揪绲界粔鍫曟偪閸℃稒鍋ㄩ柛妤冨仧椤忔挳鎮橀悙鈺佷壕闂佸憡鍔曢崯鍧楁偩?*闂?
    //      婵炴垶鎸哥粔宕囨娴兼潙绀勯柧蹇曟嚀缁?闁诲海顢婂Λ鍕偓纭呮珪缁楃喎鈹戞繝鍕垫船婵炴垶鎸搁敃銉︽叏閵堝违濞达綁顥撻悷鎰版煙闊彃鍔欑紒鍫曨棑閹秆囧冀瑜滈崯宥夊箹?闂佹眹鍔岀€氼參顢楅幘顔藉仢妞ゆ牓鍊楃粈?026-10-15 闂備緡鍙忕徊楣冾敃閼测晙鐒婂〒姘ｅ亾婵炲吋婢橀埥澶愬醇濠靛嫪鏉梺姹囧妼鐎氼厼鈹冮埀顒勬煕閹烘洦鍟囩紒杈ㄥ哺婵?
    //   闂?**闂佽桨鐒﹀姗€顢楅悢鍝モ枖濠电姳鑳堕悷銏ゆ煛閳ь剟鎮烽弶娆炬瀫闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯兼暩閹肩厧霉閻樻彃娈╃紒杈ㄧ懄缁傛帞绱掑Ο鍝勵棈 `t`闂佹寧绋戞總鏃傜箔婢舵劕鐭?`t=0`闂?* 闂佺偨鍎查弻锟犲焵?闂佽浜介崝宀勵敋闁秵鏅柛锔芥倻kUI 闁汇埄鍨遍悺鏇綖婢跺本瀚氭い鎾寸箘閻ゅ懘鏌?
    //      `.scale` 缂傚倷鐒﹀ú婵囦繆椤撱垺鍊烽梺顐ｇ閸橆剟鐓崶褍鏆旈柍褜鍏涘?translate` 闂侀潻璐熼崝宥咃耿椤撶姷纾介柍鍝勫€归弶褰掓煟閵娿儱顏柛鈺傤殜瀹曟悂骞囬鐘茬伇缂備緡鍨伴…鐑藉闯閻戣棄绀夐柣娆忔噽缁€鍡涙煥?
    //        scale   = morph.size / base.size
    //        translate = morph.xy 闂?base.xy
    //        濠电偞鎸稿鍫曟偂鐎ｎ兛鐒婇柛婵嗗閸?= base.size 闁?scale = morph.size                      闂?
    //        濠电偞鎸稿鍫曟偂鐎ｎ偆鈻旀い鎾跺仧婵?= baseCenter + translate
    //                 = (base.xy + base.size/2) + morph.xy 闂?base.xy = morph.xy + morph.size/2
    //        闂?濠电偞鎸稿鍫曟偂鐎ｎ亶鍟呴柨鏃囨硶閻熸劙鎮?= morph.xy                                        闂?
    //        闁荤喐鐟ュΛ婊堬綖鎼淬劌鎹堕柛鈩冨嚬濞?= (morph.radius / scale) 闁?scale = morph.radius          闂?
    //      闂?**闁诲繐绻嬬欢姘焽娴兼潙鎹堕柕濞垮€栧畷鎻捗归敐鍡樼；缂佹柨顕弫顔款槾婵炲牊鍨块幏鍐偩鐏炴垝鍖栭梺闈涙缁€渚€濡甸崶鈺€鐒婇煫鍥ь儌閸嬫挻鎷呴崨濠傤洭闁荤喐鐟︾敮锟犲礂濡崵鈻旈幖绮光偓铏灳闂?`.width/.position(lyricFloatRect())` 闁诲海鎳撻懟顖炲矗韫囨稒鍎庣紒瀣閸?*
    //      闂佹寧绋戝濉╝se` 闂佸憡鐟禍婵單?闂佸憡鐟ラ崐浠嬪焵椤掆偓閸熶即鏌?闂佹寧绋戦懟顖炴偩閻樿鐭楅柡宥忓閻棗鈽夐弬璺ㄥ闁逞屽墮閵堟悂宕楀Ο鑽も枖鐎广儱鎳庨〃娑㈡煕濠靛棛肖缂侇喓鍔戝绋款煥閹邦喚顦?*闂佸憡鐟禍锝夈€呴敂閿亾閻熸澘鏆曠紒妤€顦扮粙?0**闂佹寧绋掔粙鏍崲閺嵮屾桨闁挎繂妫欑瑧闁诲海鎳撻崯顐ゆ崲閳ь剙顪冮妶鍫濆惞闁告垳绮欏畷娆撴偐鏉堚晝协闂佹眹鍔岀€氼剛鏁锕€鐐婇柣娆忔噽缁€鍡涙煏?
    //      闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃銉モ攦閳ь剟鎮归崶鈺佸幋闁靛棗閰ｉ獮宥団偓锝庡厴閳ь剚顭囬幏瀣Χ閸曨収浼囧┑鐐叉濡插嫮妲愰幍顔荤剨濞撴埃鍋撴繛鑲╁閵囧嫰鎮界粙澶哥凹閻庢鍠氭慨鎾Φ閸モ晙鐒婂〒姘ｅ亾婵炶偐澧楅幆鏃堝棘閸撗呮喛闂佽　鍋撻柣鐔告緲椤?*婵炴垶鎸撮崑鎾翠繆椤栨せ鍋撻懠顒変紘闂?*闂佹寧绋戦悧鎰偓姘ュ灲瀹曪絽螣閸︻厼鏅╅梺鎸庣☉閻線顢氶埡鍛強?`.translate`
    //         婵?`.scale` 闂佹眹鍔岀€氼剟藝閺屻儱瑙﹂柛顐犲劘閳ь剙瀛╅幆鏃囩疀鎼达絿鎲挎繛鎴炴尭閿曨亜顭囨导鏉戠；闁搞儺浜堕崯搴♀槈閹惧磭肖妞?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯ｉ幖浣歌埞妞ゆ牗鐟ч閬嶆⒒閸ワ絽浜鹃柣鐔告磻濞村洭鎯冮悢鐓庢瀬閻庨潧鎲￠悾閬嶆煕鐎ｎ亝绌挎い鏃€娲熼弫宥嗗緞閸艾浜?
    Stack({ alignContent: Alignment.TopStart }) {
      // 闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸闁硅埇鍔嶅▍婊堟煃閻戞ê濮€闁?闂佸疇妫勯幊澶娢?闂佸搫鐗滈崜娆撴儑娴兼潙绠ｉ柟閭﹀枤瑜板矂鏌熺喊妯轰壕婵炴挻纰嶇换鍡欑矉閸℃稒鍎?*婵炴垶鎸堕崐鏍ь焽椤栫偛閿ら柟閭﹀幘閸ㄨ偐绱掗婵愬殭濠⒀呭█楠?*闂?026-10-15 闁荤偞绋忛崕鎾敊閸ヮ剚鏅悘鐐舵琚熼梺褰掓涧椤戝懏鏅堕悩铏圭杸闁告盯鍋婇崵銏ゆ煥濞戞﹩妲撮柡鍛叀閸╋繝骞囬妸锔界彸闂佸磭鍎ら崝蹇涘疾閺屻儱鐓涢柟鑸妽濞呮粓鏌嶉悜妯哄闁哄懏鐓￠崺锟犲箛閵婏附鐝抽梺宕囧劋閸斿繘寮查弻銉ョ厸?
      //
      // 闂佸憡鎸哥粔浣冦亹?闂佸啿澧庢刊瀵告?*闂佸搫鐗滈崜娆撴儑閹殿喗鍋栨い鎰剁到閻︻垶鏌?濠电姴艌閳ь剙纾宀勬煕閹邦剚鍣规い鏃€鍔欏?婵?* 闂?闂備緡鍙忕徊濂告煂濠婂應鍋撻悷鑸粧閻庨潧鐭傞幆鍐礋椤愩垺鏆ラ柣搴ｆ嚀濠€鍗灻洪崨顓у晠闁挎棁娉曢悷鎰版偡?= 缂備焦鍔栭〃鍛般亹濞戙垹鍌ㄩ柣鏂挎惈娴?
      //   闂佹寧绋戝濉抣aybackPage.ets:3227` 闂備緡鍙忕徊鍊熴亹?闂佸搫鐗滈崜娆撴儑娴煎瓨鍎嶉柛鏇ㄥ亗缁狀垰鈽夐幘绛归練妞ゎ偅顨堟禍鍛婃綇閵娤€锔剧磼閹邦収娈旂憸鐗堢洴瀹曘垽鎮㈤崫鍕寲"闁荤姴娲ら顓炩枔閹寸姳鐒婇弶鍫涘妽绗戦柣搴ｆ嚀閸犳稓妲?
      //    闂佸吋婢橀懟顖炴偩?*闂佸憡鐟禍婊堫敋椤曗偓楠炲秶鈧綆鍋呯花姘舵煛閳ь剟顢涘☉妯间海缂?*闂佹寧绋戦ˇ顐﹀闯?`lyricMorph()` 婵炲瓨鍤庨崐鏇㈠吹椤撱垺鍎嶉柛鏇ㄥ幘瀹曞爼鏌涘▎娆戝埌婵炲吋顨婂浠嬪炊瑜嶇拋鎻捗?*闂佺儵鏅涢悺銊ф暜?*闂佸憡鍔栭悷銊ф崲?`.position()`闂?
      //   闂佸疇娉曟刊瀵哥箔?闂佺懓绠嶉崹娲垂濮樻墎鍋撶涵鍛棄闁?闂傚倸鐗勯崹鍝勵熆濮椻偓閹啴宕熼顐㈡櫛婵炴垶鎸风槐顔炬濡句敬ridCol` 闂佸憡鍔曢幊搴敊閹扮増鍎?/ 閻庡綊娼婚梽鍕偉?`Column`闂佹寧绋戦ˇ顖氼潩?*婵炴垶鎸哥粔鎾疮閳ь剟鏌熺€涙ê濮夐柣?*闂?
      //      闂婎偄娲ら幊姗€濡磋箛娑樼闁割偅绻傚▍銈夋煙閸濆嫷妲告い鏃€鐗楃粙澶屾嫚闊厾顔嗘繛鎴炴尭閿曘劑锝炲Δ鍛櫖闁秆冨殼layerExpandState.toHostPoint()` 闁诲繐绻楁ご绋课ｉ崨濠勨枖闁告繂瀚弳濠囨煕閹存繃顥滄い锔诲墴閹啴宕熼崜浣侯槴闂?
      //      闂佸憡鐔粻鎴﹀垂椤栨粈鐒婂〒姘ｅ亾婵為棿鍗冲顐ょ礄閻樼數歇闂佺顑呯换瀣博鐎涙鈻旀い蹇撴噽閸╁霉?闂佺偨鍎查弻锟犲焵?闁?`闂佺儵鏅╅崰妤呮偉閿濆鐓?闁诲海顢婂Λ鍕儓閸℃稒顥堥柕蹇婂墲缁惰尙绱撴担鍝勬瀺缂?闂佸搫鍊藉Λ鍕閹版澘鐐婇柛娆嶅劤閻熴垹螖閻樺弶婀伴柡?md` 闁? 闂?S3a闂?
      //
      // 闂佸憡鎸哥粔浣冦亹?闂佸啿鐏堝Σ鍕?*闂佸搫鐗滈崜娆撴儑娴兼潙瑙﹂悘鐐靛亾椤ρ囨偠濮樼厧浜滄い銊︾矒瀹曠兘濡搁妷銊ョ厒闂佸憡鐟﹂敋妞ゆ梹鍔欏畷鎶解€﹂幒鏃傤槱scale + translate + clip闂?*闂?
      //   闂?`.position({x, y})` 闂備焦褰冮惉鐓庘枔閹寸姷鐜绘俊銈傚亾鐟滅増鐩畷鎼佸箛椤撶姴鐏遍梺鍛婄懐娴滄粌锕?`p = 1`闂佹寧绋戦悧鍡涱敊閹版澘闂柕濠忛檮绗戦梺璇″幗鐢偤鎮洪幋锕€鐭楁俊顖濐嚙鎼村﹪鏌ㄥ☉姗嗘Ч婵?*婵炴垶鎸堕崕鏌ユ偋?*闂佽В鍋撻柦妯侯槹闊剛绱掗幇顓ф當鐟滅増鐩幆?(x, y)闂?
      //      閻熸粏鍩囬崹纭呫亹婢跺鈻旀い鎾卞妿缁€鍒?< 1闂佹寧绋戦ˇ顖炴偩閻樼粯鍎?*闁诲骸婀遍崑銈咁瀶?*缂備焦鍔栭〃鍛般亹濞戞瑦濯寸€广儱娲ㄩ弸鍌毭归崗闂翠孩妞ゎ偓濡囬埀顒€婀遍幊鎾斥枍閹烘鐭楁俊顖濐嚙鎼村﹪鏌熼崜韫捣闁炬柨顑夋俊?
      //   闂?**闂佽浜介崝宀勵敋闁秵鏅柛顐ｇ矌閻熸繈鏌￠崟闈涚仧闁告瑥锕幆鍐礋閸撲礁鑰块梺鍛婄懄钃辩€规洘鐓″畷銏ゆ偄閸濆嫪鍖栭梺鍛婄懄閻楁洟顢欓幇鏉块棷闁靛鍊涢崢顒勭叓閸パ冩灕缂?缂傚倷鐒﹀ú鎴︽嚈閹达絿鐤€闁告劦浜炵槐姘舵煛閳?闂?*闂?
      //        闁荤姳绀佹晶浠嬫偘閵夆晛鐭楅柨婵嗘噺缂嶅繘鏌?y闂佹寧绋戦懟顖烆敊閹版澘闂柕濞炬櫇瑜?`H`闂佹寧绋戦悧鍐╂櫠?闁诲海鎳撻妵妯尖偓闈涙湰椤ㄥ洤顫滈崼銏㈩槴闂佹寧绋戦悾鐠?= initScale + (1闂佹剚鍘芥慨鏄籭tScale)閻犺櫣妞俙闂侀潧妫斿姊?= initTranslateY閻?1闂佹剚鍘芥慨?`
      //        缂傚倷鐒﹀ú鎴︽嚈閹达絿鐤€闁告劦浜炵槐姘舵煛閳ь剟骞橀崨顖滅崶`y 闂?H/2 + (y 闂?H/2)閻犺櫣妞€`闂佹寧绋掔粙鎴﹀疮閳ь剚顨ラ悙鑼紞娴?`d` 闂?`y' = H/2 + (y 闂?H/2)s + d`
      //        婵炲濯寸徊浠嬪矗閸℃稑瀚夋い鎴ｆ硶濞夈垽鏌?`initTranslateY = barY 闂?scaledH閻?1闂佹剚鍘芥慨鏄籭tScale)/2`闂佹寧绋戝濉籧aledH = barH/initScale`闂?
      //        濡ょ姷鍋炲﹢褰掑箮?`t = p`闂侀潧妫斿姊?= H/2 闂?scaledH/2`闂?
      //            y' = k閻?1闂佹剚鍘芥慨? + y閻犺櫣妞€ = k(1闂佹剚鍘芥慨? + y閻犺櫣妞?  闂?  **`y' 闂?t 闁?y`**闂佹寧绋戦悧鍡椕哄鍕枖?`k` 婵?`y` 闂佸憡鑹鹃惌鍌炲闯閾忓湱妫憸瀣焵椤戞寧顦风紒妤佺墵瀹?t=1 闂佸搫鍟抽崺鏍ㄦ叏瀹勬壋妲堥柛顐墰缁€?
      //        閻?`p = 1`闂佹寧绋戦悧鎰板箚閵堝棙濯寸€广儱绻掔粈鍡涙煥濞戞瑧鎽' = y` 闂?**濠殿喗绻愮徊鎯ｉ崫銉﹀闁硅鍔﹂崥鈧梺?*
      //        閻?`p = 0.5`闂佹寧绋掗崺鍐╂櫠?`y/2`   闂?**闂佸憡鐟禍婵嗭耿娴ｇ儤濯奸柟瑙勫姦閸氣偓闂佺锕ㄩ崑鎰枔閹寸偟鈻旈柍褜鍓熷畷?*
      //        閻?`p = 0`闂佹寧绋掗崺鍐╂櫠?`0`        闂?闁荤姵鍔栧娆忥耿椤忓棌鍋撻崷顓熷殌婵炲懏甯楃粙澶嬬節閸涱垳褰?
      //      闂佹寧绋戦悧濠冧繆?`y = 250` 婵炲濯寸紞鈧紒缁橈耿瀵敻顢楁担鍦毣闂備緡鍙忕徊璺ㄥ垝瀹ュ洠鍋撻崷顓炰沪缂佷焦鎸冲畷娆撴偐鏉堚晝协 `initScale 闂?0.082 / scaledH 闂?683 / H 闂?925`闂?
      //        t=1 闂?250 闂佺繝鐒﹂幐鍫曞焵椤戣儻绶?0.5 闂?124闂侀潧妫旀潏?0 闂?闂? 闂佺偨鍎查弻锟犲焵?婵?`y' 闂?t閻犺櫣妞奰 闂佸憡淇洪褔骞冩惔銊︽櫖?
      //   闂?**闁哄鏅滈悷锕€危閸涘﹦鈻旈柍褜鍓熷?闂佽В鍋撻柟瀛樺笧缁夋挳鏌￠崘顓炵厫妞ゆ帗绮庡☉鐢割敊鐞涒€充壕濞达絾鐡曢崺宀勬煕濞嗘兎濂告嚈閹达箑纾?闂佹眹鍔岀€氼剝銇愬☉姗嗗殫?*闂佹寧绋戝濉晍dCoverRect` 闂?`base/tx/ty` 闂備焦褰冪换鎺戔枔閹寸姳鐒婇弶鍫涘妽绗戦柣搴ｆ嚀閸犳稓妲愬璺何?
      //   闂佸疇娉曟刊瀵哥箔?**2026-10-15 闂佸憡甯炵划顖炲礈閻楀牏鈻旂€广儱妫欓弳?*闂佹寧绋戦惉濂稿箖婵犲洦鍋ㄩ弶鍫涘妽绗戦梺琛″亾閻熸瑥瀚妴濠囨⒑椤旀寧顥夐柛鎴磿閹噣顢曢妶鍡楃劯闂佸搫鐗撶紓姘舵儊婢跺顕辨い蹇撴川缁犳牠鏌?
      //       閻?闂備緡鍋勫Λ妤勩亹婢舵劕绠查柕蹇曞У缁€鈧俊鐐€濆褔宕幘顔奸敜闁归偊鍘鹃崹?闂佺偨鍎查弻锟犲焵?闂佹椿浜為崰鎰攦閳ь剛绱撴担瑙勫鞍闁?闁诲繐绻嬬欢姘焽閹殿喗宕夐柟瀛樼箓閻撳倻鈧綊娼荤紓姘辩箔閸屾粍鍠?闂佹寧绋戦悧鎰帮綖?`morphBridging()` 闂備焦褰冮惌鍌炲磻閸涱厸鏋旂痪鏉款槺缁?
      //         `.scale()` 闂佹眹鍔岀€氼參鎮橀幋鐐村闁哄鍨圭粔濂告煛閸愨晜鏋勭紒妤€顦靛浼搭敍濞戞浜繛瀵稿О閸庢壆鎷归悢鍏煎剭闁告洦鍋掗崯鍥煕閿濆啫濡洪柤鍨灱缁犳盯宕樼捄銊ь槴闂?
      //       閻?闂佽桨鐒﹀娆撴儑娴兼潙绠规い鎺嗗亾闁搞値鍙€閵囨劙濮€閻樿尙绉柣搴℃贡閹虫挸鈻?闂佺偨鍎查弻锟犲焵?婵炴潙鍚嬮懝鎹愩亹婢舵劕绠?婵＄偑鍊楅弫璇差焽娴兼潙鎹堕柕濞у懐绀嗛梺闈涙缁€渚€鎯冨┑瀣棃妞ゎ偒鍘鹃悷婵堢磽?闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾閺夋埈鍎撶紒璇插暣閹啴宕熼鍛秵闂佽澹嗛崳锔炬濮樿泛违?
      //   闂佸疇娉曟刊瀵哥箔?**闂佸憡鑹炬總鏃傜博閹绢喖鍐€闁荤喓澧楃粈鍫ユ煟閵娿儱顏╃憸鎵枑缁嬪鍩€椤掍胶顩烽柤鎭掑劚椤忓爼鎮归幇顓犵畵闁告埊绱曠槐鎺曠疀閹剧鍚繝銏㈡嚀閸熷潡鎯?*闂佹寧绋掗悺鐙猲dex.ets` 闂?`MorphCoverClone()` 婵炴垶鏌ㄩ鍡樻櫠瀹ュ棛顩烽柕澶樼厛濞煎爼鏌熺喊鍗炲闁?
      //      闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滅痪鏉款槺缁€澶嬬箾婢跺牆濮傞柛锝嗘尦瀹曟ê鈻庨幋鐐垫殸濠殿喗绻愮徊鎯ｉ崨濠冧氦婵炲棗瀛╅钘壝瑰鍐惧劀缂?闂佹椿鍘搁弲娑㈡嚋娴兼潙纭€閻庢稒蓱绗戠紓浣瑰姈椤ㄥ懓銇愬☉銏犻敜闁归偊鍘鹃崹?闂?闂佸憡鐟禍婵嗭耿?p=1 闂佸綊娼х粔鍐差嚕濡ゅ懎鍐€闁稿繒鈷堥崝鈧紒?闂佹寧绋戦ˇ顓㈠焵?
      //   闂?缂傚倷鐒﹂幑渚€顢欓幋锔芥櫖?*闂佸綊娼ч鍡椻攦閳ь剟鏌￠埀顒勵敍濞嗘垹顔旈梺褰掓櫜閼冲爼鐛崶顒佸亹?*闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫮澧楅煬顒勬煟椤忓棗鏋戞繝褉鍋撴繛鎴炴尭閿曨亪鎮板▎鎰氦闁搞儺浜跺搴ㄦ煙閹殿喖鏋庣憸鐗堢叀楠炴帡濡烽妷銉хК闂佹寧绋戦¨鈧紒?
      //      闁诲海顢婂Λ鍕儓?闂傚倸鐗勯崹鍝勵熆濮椻偓閺屽洭鏁愰崟顓т紘闁哄鍎愰崰鏍€呰瀵顭ㄩ崱鈺傜煑婵犮垼娉涚粔鍫曞极閵堝瀚夋い鎺嗗亾闁活亙鍗抽弫宥囦沪閻ｅ瞼鐣辨俊?*闂佸憡鑹鹃張顒€顪?*闂佸憡鍔曢崯鍧楁偩閻愵剚浜ゆ繛鍡楁捣閻熷繘鏌℃径鍡忓亾閸愬樊鏋€闂佸湱绮崝鏍焵椤掆偓缁ㄨ偐绮婚悙鏉戠窞闁告洦鍘介崐鐐烘煥?*婵炴垶鎸哥粔鐑筋敊韫囨稑鐭楁い蹇撴噺閸庢柨鈽夐幘顖氫壕闂?*闂?
      //   婵犮垼娉涚粔鐢告偋閹惰棄宸濋柟瀛樺笚婵垽鏌ㄥ☉娆戞憿hdc shell hilog -x | Select-String 'RzdCoverRect'`
      //     闂?闂佹椿浜滈鍛存嚋娴兼潙鐭楁俊顖滎攰閸?`measured`闂佹寧绋戝绁匒reaChange 缂傚倷鐒﹂悷褍鈻撻幋鐘虫殰闁告劑鍔庡﹢鏉棵归敐鍛枌缂佽鲸纰嶇粙?`base+tx` 闂佹眹鍔岀€氼剙螣婵犲洦鏅?
      //        婵炴垶鎸哥花鑲╃箔閸岀偞顥堥柕蹇嬪€曟禍婵嗏槈閹炬剚妲兼い銏″灦閿涙劙宕熼鍌樺仦闂佹寧绋戝?1 闂佺儵鏅涢幗婊堟偤?/ p=0.5 闂佸憡鍨电换鎰暦?/ p=0 闁荤姵鍔楅ˉ鎰帮綖濡ゅ懏鏅璺侯煬閸ょ姷鈧數澧楅妵鐐电箔閸屾粈鐒婇弶鍫亽閸ゆ盯鏌￠崟顐ｅ攭缂佺粯鐗犲鍫曞灳閸愯尙绋夐悗鍨緲鐎氼垳鎹㈤弴銏犳嵍闁靛ě鍕闂佽桨绀侀悧鍕焵?
      //
      // 濠电姴艌閳ь剙纾宀勬倶閻愬弶鍣搁柤鍨灩閳ь剙婀遍幊鎾斥枍閹烘鏅慨姗嗗墰濞堥亶姊婚崼娑樼伄婵?*闁汇埄鍨伴崯顐︽儑椤掍焦濯寸€广儱娲ㄩ弸?*闂佹寧绋戦悧鍡氥亹婢舵劕绠叉い顐幘椤撳搫顭块懜鐢靛缂佽鲸姘ㄦ禍鍛婃綇閵娤€?闂佺硶鏅涢幖顐﹀闯椤栫偞鍎楅柍杞版祰閸?闂佹眹鍔岀€氼剟鎯囬搹顐も枖妞ゆ挻绻勭粔?
      // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弳浼存偣鐎ｎ亜鏆旈柍?*閻熸粍濯介褏鑺遍幎鑺ュ亗鐟滃酣骞嗘径鎰Е?*闂侀潧妫楃粙鍕濮樿埖鏅?
      //   闂佺娉涢敃銈夋儍濠靛顥堟い顐幘閻倝鏌?*闂佺硶鏅涢幖顐﹀闯?+ scale/translate**闂侀潧妫楃粔鐢稿极婵傜绠ｉ柟閭﹀幗閿熴儵鏌ｉ敐鍛劯闁稿鎳樺鑺ヮ槹鎼淬垻鏆犻梺?*缂備胶铏庨崹浼村吹閹寸偞濯撮柡鍥╁У缁绢垶鏌熼幁鎺戝姤闁诡垬鍊栭幏?*闂侀潧妫楃粔鏌ュ焵?
      //
      // ## 婵炴垶鎹佸銊у垝閸喓鈻曢柛顐秵濞诧綁鏌涘Ο鑲╁笡閻㈩垪鍋撻梻渚囧弿缁茶偐绮╃€电硶鍋?`scale/translate`
      //
      // 闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡楁捣椤忛亶鎮橀悙鎻掆偓鐟拔ｉ幖浣规櫖?
      // ```
      //   Image().width(coverLayerBase().size)                     闂?闂佺硶鏅涢幖顐﹀闯椤栨粈鐒婇柛婵嗗閸?
      //          .scale(闁诲骸婀遍崑鐐电矈鐎甸晲鐒婇柛婵嗗閸?/ 闂佺硶鏅涢幖顐﹀闯椤栨粈鐒婇柛婵嗗閸?                        闂?闁荤偞绋忛崕閬嶅春?闁诲骸婀遍崑鐐电矈鐎甸晲鐒婇柛婵嗗閸?
      //          .translate(闁诲骸婀遍崑鐐电矈鐎涙ɑ濯?闂?闂佺硶鏅涢幖顐﹀闯椤栨稒濯?                        闂?闁荤偞绋忛崕閬嶅春?闁诲骸婀遍崑鐐电矈鐎涙ɑ濯寸€广儱娲ㄩ弸?
      // ```
      // 婵炲瓨绮岀€涒晛危?*闁诲繐绻嬬欢姘焽娴兼潙瀚夐柍褜鍓涚槐鎺楀醇濠婂懐孝缂?= 闁诲骸婀遍崑鐐电矈鐎涙ɑ濯寸€广儱娲ㄩ弸?*闂佹寧绋戦惌渚€鍩€?闁诲骸婀遍崑鐐电矈鐎涙ɑ濯寸€广儱娲ㄩ弸?闂佸搫顦崕鎾吹?`onAreaChange` 婵炴垶鎸搁敃銉︽叏閵堝鍎?
      // `lyricFloatRect()`闂佹寧绋掗惄顖炲磻閸涱喚鈻旀い蹇撳閸嬫捇鎮℃惔銏ｅ惈闂佸搫鐗滈崗娑氬垝?*婵炴垶鎸哥粔纾嬨亹閺屻儱绠崇憸瀣焵椤戞寧顦风紒鈥冲暣瀵噣鎮╁畷鍥モ偓濠勭磼閸屾繂鍚归柛銈呴叄瀵晫绮欏▎鎯ф**闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弶鑺ョ箾?闁诲繐绻嬬欢姘焽娴兼潙纾婚煫鍥ф捣缁?闂?
      // 闂佸吋婢橀張顒勫垂濠婂牆绠板璺猴功閺嗗﹪鏌涚€ｎ偆鐓柟骞垮灪閹峰懘寮撮悢鍝勨叞濠殿喗绻愮紞渚€宕楀Ο璇差嚤婵ɑ鍓氶崬銊╂偡濞嗗繐鈧綊宕濋崨鏉戝嵆闁哄鍨堕埢?闂佺偨鍎查弻锟犲焵?闁?4/闁?5/闁?6 婵炴垶鎸搁ˇ浼搭敃婵傚憡鐒鹃柤鎭掑劤婢规棃鏌涢敂鍝勫缂佺粯鐗犲鍫曟晸閻樿櫕鍤戞繛鎴炴尭椤厾妲愬璺何?
      //
      // 闂佸搫鍟版慨鐑藉疾椤愶附鐒介柨婵嗙墢閻?*闂佸搫绉烽～澶婏耿閺夊簱鏌﹂柍鈺佸暞缁犳帡寮堕埡鍌滄噭婵炵⒈鍨堕弻?*闂佹寧绋掗悺鐚oatingCover` 闂佸搫瀚烽崹顖滅博鐎涙鈻?`Column(center)` 闂備焦褰冮惉鐓庘枔閹寸姳鐒婂〒姘ｅ亾婵為棿鍗抽弫?
      // 闁诲繐绻愰幖顐︻敋?`morph.edge`闂侀潧妫斿鎺旂礊閸涱垳纾?`morph.tyAt(t)`闂侀潧妫旂粈浣搞€掗崜褎鍠?`morph.radiusAt(t)`
      // 闂佺偨鍎查弻锟犲焵?**闂佺绻堥崝鎴﹀磿閹绢喖鍙婃い鏍ㄧ矌閺嗩剟鏌涢幋鐘插妺婵炶偐鏁婚幆?*闂佹寧绋戞總鏃傜箔婢舵劕钃熼柕澶堝€栧畷鎻捗归敐鍡樼濠碘槅鍙冮幃娆撴儌閸濄儳顦ーPlayerPage闁诲海鎳撻張顒勫汲椤ゆ杯闁诲氦顫夊銊┾€?md` 闁?闂佹寧绋戦ˇ顓㈠焵?
      //
      // 闂?闂佺粯绮嶅妯猴耿椤忓牊鍋傜憸搴ㄥ箚婢跺备鍋撻悷鏉挎灕缂?*闁诲繐绻愰幖顐︻敋?婵炶揪绲界粔鍫曟偪?闂侀潻绠戝Λ婊堬綖濡や胶鈻旈柍褜鍓欓銉р偓锝庝簻缁插潡鏌?`lyricFloatRect()`闂? `lyricMorph(t)`闂?*闂?
      //   婵炴垶鎸哥粔鎾疮閳ь剙鈽?`scale`闂侀潧妫斿鎺旂箔婢舵劕绀冪€广儱鎳庨～?`translate`闂侀潧妫旂换鏉?= 0`闂佹寧绋戦悧鍡涙儍濠靛顥堥柕蹇嬪€戦埀顒€顦靛Λ鍐ㄢ枎閹伴潧澹橀梺鎸庣☉椤︽澘顪?`lyricMorph(0)`
      //   闁诲繐绻楁ご绋课?`playerCoverGeomRect()` 闂備緡鍙忕徊鑲╃博鐎涙顩?*闂佸搫鍟版慨鐑藉疾椤愶附鍎嶉柛鏇ㄥ幘閺嗩剛鈧鍠栫换鎺斿垝閵娾晛鍑?* 闂?闂佽В鍋撻柟瀛樺笧缁夋挳鏌ｉ姀锝勫惈闁伙綀顕ч锝堢疀鎼达綆浼囧┑鐐叉閳ь剙纾弳鐗堟叏濠靛洨婀介柍?
      Column() {
        Image(this.currentCoverSource())
          // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀?2026-10-16闂佹寧绋戦悧蹇涘极閵堝绠ｇ€瑰嫭澹嗛弳浼存偣鐎ｎ亜鏆旈柍?*閻熸粍濯介褏鑺遍幎鑺ュ亗鐟滃酣骞嗘径鎰Е?*闂? 婵烇絽娴傞崰鏇犳偖闁秴绾ч柍銉ョ－閺夎姤绻涢弶鎴劀缂佽鲸宀搁弫?
          //   **闁诲繐绻愰幖顐︻敋?婵炶揪绲界粔鍫曟偪?闂侀潻绠戝Λ婊堬綖濡や胶鈻旈柍褜鍓欓銉р偓锝庝簻缁?`lyricMorph(t)`闂? 闂佸搫鍟版慨鐑藉疾?`CoverMorph` 闂佹眹鍔岀€氼垳娆㈤銏犵闁绘艾顕粈鍡涙煥?
          //   婵炴垶鎸哥粔瀛樼濞戞瑧顩烽悹浣哥－缁夊潡鏌涜閸旀牠鎮ラ敐鍥у缂備焦锚鎼村﹦绱?*闂佹寧绋戝濉﹐verLocalRect()` 闂佺粯绮嶅妯猴耿椤忓棔鐒婇弶鍫涘妽绗?`lyricFloatRect()` 闂佹眹鍔岀€氼喖煤閸ф鐒绘慨妯哄⒔缁€鍡涙煏?
          //
          //   闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹宕囩箔閸屾稓鈻旈柍褜鍓熼幃褔宕煎┑鍥惈闁哄鏅滈悷鈺呭闯閻戣棄绀夐柣妯挎缁犳牕鈽夐幘顖氫壕濠?闁诲繒鍋涚换鎰不閻戣棄閿ら柟閭﹀幘閸?闂?闁诲骸婀遍幊鎾斥枍閹烘瀚夋い鎺嗗亾婵犫偓閹绢喖閿ら柟閭﹀幘閸?闂?*闂備緡鍋勫Λ妤勩亹婢舵劕绠?*
          //     闂佹寧绋戦悧鍡樼閿濆洦濯?`.scale()` 缂傚倷鐒﹀ú鏍敊閹版澘闂柕濞垮€涢崢顒勭叓閸パ冩灕缂佽鲸宀搁弫宥呯暆閳ь剙锕㈤敓鐘插珘闁惧繐婀卞▔銏ゆ煛鐎ｎ偆鐭嬫俊?*闁诲繐绻嬬欢姘焽閻楀牜妲归柣鎰絻濮ｅ鎮橀悙鑼缂?*闂?
          //     闂佸搫鐗滈崗娑氬垝閵娧€鍋撻悽娈挎敯缂佺粯鐗犲鍫曞灳閸忓懏鎹ｉ柣?*闂佸搫鍟犻弲婊冿耿娓氣偓瀹曪絽顓奸崼銏☆潔**闂佹寧绋戝濉祇rphCoverRectAt()` 闂佹眹鍔岀€氼參寮悙鐑樼厒?+ 闂佸搫鐗滈崜娆撴儑閻楀牄浜滈柛顐ｆ礀閸?
          //     "闂佸疇娉曟刊瀵哥箔?2026-10-15 闂佸憡甯炵划顖炲礈閻楀牏鈻旂€广儱妫欓弳?闂備緡鍙忕徊鑲╃博閺夋垟鏋旂痪鏉款槺缁愭鏌曢崱妤冪劯闁逞屽墮濡銇愭径鎰?闂?闂佹椿浜為崰鎰攦閳ь剛绱撴担瑙勫鞍闁诲繐顦辨禍鍛婄瑹閳ь剙顭囬幍顔藉磯闁瑰瓨绻傞悡鍌溾偓褰掓交缂傛氨绮崒婊勫枂闁硅櫣鍋熺粈?
          //     闁荤姴娲ら悺銊ノ?`.scale()` 闂佹眹鍔岀€氼參鎮橀幋鐐村缂傚牏濮烽悷婵嬫煛閸曢潧鐏￠柛銊︾矋缁傛帡濡烽妶鍫㈩槹闂佹眹鍔岀€氼剟顢欓幇鏉块棷闁靛鍊涢崢顒勭叓閸パ冩殧闁逞屽墮缁嬪嫮妲愬璺虹劷?**閻庣懓鎲¤ぐ鍐偩椤掑嫬鏋侀悗娑櫳戠€电敻鏌?*闂?
          //     婵炴垶鎹佸銊у垝閸喓鈻曢柛顐ｇ箘缁夊ジ鏌￠崘銊ヮ暢婵炲牊鍨圭槐鎺楀箻鐠団€虫櫏闂?婵烇絽娲︾换鍐偓鍨閹娊骞嶉澶?闂佹寧绋掗懝楣冩偩閻樼粯鎯為柣锝呰嫰婵?闂佽В鍋撻柟瀛樺笧缁夋挳鏌￠崘顓炵厫妞ゆ帗绮庡☉鐢割敊鐞涒€充壕濞达絾鐡曢崺宀勬煕濞嗘兎濂告嚈閹达箑纾?闂?
          //     婵炶揪绲藉Λ妤呮儍濠靛顥堥柕蹇婂墲绗?*闁荤姾娅ｉ崰鎾愁焽閸愵亖鍋撻崷顓熷殌婵炲懏甯楃粙澶愬焵椤掑倹灏庡瀣捣缁?*闂佹眹鍔岀€氬摜妲愬▎鎴炲枂闁稿本绋戞俊铏叏濠垫挾鎮奸柍銉︼耿閺佸秵寰勫☉姘鳖槷闂佸吋婢橀惌鍌炲焵椤掆偓濡銇愭径鎰妞ゎ偒鍘剧粣妤呮煟閳轰胶鎽犻悽顖涙尦楠炲孩绻濋崒婊勬疁闂佺儵鎳囬弲娑㈠吹椤撶姳娌煫鍥ㄦ尵椤斿酣鏌?
          //   闂佸湱鍎ょ敮妤呮偂閿熺姴绀傞柟鎯板Г閺嗘盯鎮楀☉娆樻缂佽京娅梙dc shell hilog -x | Select-String 'RzdCoverLocal'`
          .width(this.coverLocalRect().size)
          .height(this.coverLocalRect().height)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.coverLocalRect().radius)
          .clip(true)
          // `.position()` 闂?*闂佺儵鏅濋…鍫ヮ敋椤曗偓閹儵宕滄担铏圭厑婵炲濮惧▔娑㈠船鐎电硶鍋撻悷鐗堣础婵?*闂佹眹鍔岀€氼喚鍒掓搴樺亾閻㈠灚鍤€闁伙絿鍋撻幏鍛吋韫囨洖鑰块梺鍝勭墱閸撴瑩鎯囬幍顔瑰亾閻熻埇浠掗悗闈涚焸閹啴宕熼銏℃殽闁诲海鎳撳﹢鍗灻洪崨顓у晠闁挎棁娉曢悷鎰版偡?
          // = 缂備焦鍔栭〃鍛般亹濞戙垹鍌ㄩ柣鏂挎惈娴狀垶鏌ㄥ☉妯煎濠⒀呭█楠炴捇骞囬妸锕€鏋涢梺鎸庣☉閻線锝為崱娑樺珘妞ゆ巻鍋撻柣顏嗗閵囧嫰宕奸弴鐐插Г闂佹寧绋戦ˇ顐﹀闯?缂備焦鍔栭〃鍛般亹濞戙垹閿ら柟閭﹀幘閸ㄥジ鏌涘▎妯虹仧濞存粍甯￠幆鍕偓娑櫭径宥夋煕閹邦厾鎳€闁?
          .position({ x: this.coverLocalRect().x, y: this.coverLocalRect().y })
          // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍛村箞閵娾晜鍋ㄩ柕濠忕畱閻撴洟鎮楅崷顓炰沪缂佷焦鎸虫俊?*闂佸憡鏌ｉ崝搴ㄥ极閻愵剛鈻旀い鎾噰閸嬫捇寮崜褏鐛ラ梺鍛婂灱濞咃綁鐛崶銊р枖闁靛牆瀚伴崵瀣倶韫囧海绐旀繛?*闂侀潧妫楃粙鍕濮樿埖鏅?*闁诲繐绻嬬欢姘焽閻楀牊浜ゆ繛鍡楃箳閻愬﹪鐓崶褎鍤囬柕鍡楃箻楠?
          //   `realCoverVisible()` 闂備緡鍙忕紞浣圭妤ｅ啯鈷?* 闂佺偨鍎查弻锟犲焵?闁诲海鎳撻崯鈺冪箔鐏炲墽鐝堕柛鎰皺濠€鎾煕韫囨搩鍎旀繛鍫熸礈娴狅箓宕掑鍕殸 `morphOverlayBridging()` 闂?
          //   **婵炴垶鎸堕崕鏌ユ偋閸涘﹦顩查柟鐑樻硻?*闂佹眹鍔岀€氼亞绮╃€电硶鍋撻悽鍨仧缂佽鲸鐟╁鐢割敆娴ｅ湱鈧喖霉?L2665 闂備緡鍙忕徊鍊熴亹閻愭祴鏋栭柕濞炬櫅濞呯偤鏌涢幇顓犳噮婵炲牊鍨规禍鍛婃綇閵娤€锕傚级閳哄倻鎳佹繛鍡愬灪缁傚秶鈧絽澧庣粈鍡涙煥?
          //     閻?閻熸粏鍩囬崹纭呫亹婢跺鈻旀い鎾卞妿缁€鍒瀖orphContainerActive()`闂佹寧绋掗鎬ERING/LEAVING/LANDING闂佹寧绋戦ˇ顐﹀闯?闂佸搫鐗滈崜娆戞?*婵炴垶鎸哥粔鍫曞极?*闂?
          //       闁诲繒鍋涚换瀣箔閸岀偞鐒介柨婵嗘噽閻愬﹪鏌ｉ姀鐘茶埞闁挎稒鎸炬禒锕傚磼濮橆剙鑴梻鍌氭噹濡鎯囨导瀛樻櫖闁秆冨殰orphCoverClone`闂佹寧绋戦ˇ顕€宕鍌涘仒妞ゎ厽甯為獮?
          //     閻?闂佽В鍋撻柟瀛樺笧缁夋挳鏌涘顒€鍤辩紒杈ㄧ崹tage = OPEN闂佹寧绋戦ˇ顐﹀闯?闂佸搫鐗滈崜娆戞?*闂?*闂佹寧绋戦懟顖炲储閻樼粯鈷曢柛鈩冾殘濠€鎾煕濮橆剚婀版俊鐐插€垮銊ф崉鏉炴壆鐭楅梺?
          //   闂佸疇娉曟刊瀵哥箔?闂佺懓鐡ㄩ崹鐢垫暜椤愶箑绾?*濠电姵娲栫换瀣姳閳╁啯浜ゆ繛鍡樻尫婢规洟姊?* 闂?閻熸粏鍩囬崹纭呫亹婢舵劕瀚夐柣鏂垮悑閿?闂佺绻愰澶娾枔閺囩姳娌柛宀€鍋涙禍婵堚偓娈垮枤婵炩偓妞ゃ儻绲块幃鏉跨暆閳ь剙鈻撻幋鐘辩剨濞撴埃鍋撴繛?婵?婵＄偑鍊楅弫璇差焽閻楀牊浜ゆ繛鍡楃箳閻愬﹪鏌﹂埀顒勫箣閹烘梻孝闂佹眹鍔岀€氼剟鎯冨┑瀣棃?
          //      **闂佸憡鑹鹃張顒€顪冮崒鐐叉嵍闁靛ě鍕瘞** 闂?闂佹椿娼块崝宥夊春濞戙垹绠ｆい蹇撳缁傚牓姊洪幓鎺旂伇婵炲牊鍨剁粙澶愬焵椤掆偓椤曪綁鎮╅幓鎺旓紮/婵炴垶鎸堕崐鏇犳閸撲椒鐒婂〒姘ｅ亾婵為棿鍗虫俊?
          //   闂佸疇娉曟刊瀵哥箔?闁哄鏅滈悷锕€顭囬鐐叉嵍?`MusicPlayInfoBlock`闂佹寧绋戦悧鍡涱敊閺冨倷娌?/ 闂傚倸鐗勯崹鍝勵熆濮椻偓閺屽洭鏁愰崟顔规嫛闂佽　鍋撴い鏍ュ€楃粈?*婵炴垶鎸撮崑鎾绘煟閳哄倹灏﹂柛蹇旓耿瀵?*
          //      闂佹寧绋戝﹢?57 / L510闂佹寧绋掗悺?opacity(this.expandState.realCoverVisible() ? 1 : 0)`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
          //      闂佸憡鐟禍婵嗭耿娓氣偓楠炲秶鈧綆鍋呯花姘跺级閳哄倻鎳佺紒鏃€鎸冲銊╊敍濠婂嫮鏆犲┑鐐存儗閸犳牠鎯囬弶娆剧叾闊洤娴烽崯?闂?闂佸憡鐟ラ悧鍛博鐎涙鐟归悗锝冨妷閸?*闂佸憡鑹炬總鏃傜博绾惧浜归柕蹇嬪灩绗?N 婵犮垼娉涚€氥劑鍩€椤戣法顦︾憸鎶婂洤缁╅梺顐ｇ〒閸熷﹤鈽夐幘顖氫壕婵?*闂侀潧妫楃粙鍕濞嗘垹绠?4 濠电偛妫屽Σ鍕濮樿泛违?
          //   闂佸疇娉曟刊瀵哥箔?婵炴垶鎸搁敃銉︽叏閵堝鐓㈤柍杞拌兌閹藉秹鏌ㄥ☉妯荤秮.id` / `onAreaChange`闂?*婵炴垶鎸哥粔纾嬨亹?opacity 閻熸粍婢樺畷顒勫箹?*闂佹寧绋戦惉濂稿矗鎼达絾鏆滈柟闂寸濞呫倗鈧數澧楅〃鍛村春?闂佺繝鐒﹂幐鍫曞焵?
          // ★ 2026-10-18（用户第九/十轮）：**只在"快照已经进手"之后**才把真封面藏掉。
          //   上一轮用 `!isClosing`（在拍快照**之前**就置真）⇒ 快照里没有封面 ⇒ "一关就封面消失"。
          .opacity(this.expandState.realCoverVisible() && !this.snapshotFlight ? 1 : 0)
          // 闂?婵炴垶鎸搁敃銉︽叏閵堝鐓㈤柍杞拌兌閹藉秹鏌熺喊鍗炲闁糕晛鏈璇测枎閹捐櫕顏為梺鎸庣☉閻楀﹤螞閵堝鍋╅悘鐐跺亹閻﹀秹鏌￠崟闈涚仴妞も晩鍋婇幆鍕冀瑜忓﹢鎾煠婵傚绨荤紒璁崇劍缁嬪绻濋崘銊愭捇鏌ㄥ☉娆戞憿floatingCover.onAreaChange 闂?publishMorphTargets`闂?
          .id(PLAYER_BIG_COVER_ID)
          .onAreaChange((_oldValue: Area, newValue: Area): void => {
            this.reportPlayerCoverFromOverlay(newValue);
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None)

        // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧蹇涘矗鎼淬劌绠规い鎺嶇劍閿熴儵鏌ｉ敐鍛効缂佽鲸宀搁弫?*婵炴垶鎸撮崑鎾翠繆椤栵絼娴锋い?*闂佹寧绋戞總鏃傜箔婢舵劕绀冪€广儱妫欑瑧闁诲繒鍋涢幊宥夋嚈閹寸姷鍗氶柡宥冨妼缁楁捇鏌?
        //   闁诲簼绲婚～澶愭偉?`PlayerPage闁诲海鎳撻張顒勫汲椤ゆ杯闁诲氦顫夊銊┾€?md` 闁?.1 `floatingMeta` + 闁?.2 `metaRow`闂?
        //     閻?闁诲繐绻愮换鎰版儍濠靛顥堥柕蹇曞У闊?*閻?*闂佹寧绋戦悧鍡楊潩閵娾晛鍙婃い鏍ㄧ懅閻熸劙姊婚崼娑樼伈闁稿鎳庨?`Image`闂佹寧绋戦惉濂稿极?`lyricFloatRect()` 闂佽В鍋撻柟瀛樺笧缁夋挳鏌涢幒鏂款暭闁烩剝娲滈幏鐘差吋婢跺牃鍋撴径宀€鍗氭い鏍ㄧ矊娴狀垶鏌ㄥ☉姗嗘缂?
        //     閻?濠殿喗绻傞懟顖炲箖?濠殿喗绻傞張顒佹櫠濠婂牆鎹堕柕濞垮劤閺?*闂佸憡鐟ラ悿鍥╃博閻旂厧违濞达綁鏅茬粻顖炴倵闂堟稓绉虹紓?*闂佹寧绋戝濉礶taRow` 闂備焦褰冮惌鍌炲磻閸涱喚鈻旈柍褜鍓熷畷姘旀担鍓?`layoutWeight(1)` +
        //       `alignItems(HorizontalAlign.Start)`闂佹寧绋戦¨鈧紒?
        //     閻?闂佸憡鐟ラ崢鏍疾閸洘鍋╂繛鍡樺灩閼稿爼鏌￠埀顒勫箚閻楀牜妫?闂佸搫娲﹀娆撍囬崸妤佹櫖闁割偆鍠愰敓銉╂煟閿濆懏婀版俊?`SymbolGlyph 闂佽　鍋撻柟顖滃椤ユ叢 + `SymbolGlyph 闂佸搫娲﹀娆撍囩缓娑㈡煥濞戞﹩妲堕柍?
        //   闂佸疇娉曟刊瀵哥箔?闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鏌?`textAlign(Center)` + 闂佽桨鐒﹀娆忣焽閳ユ剚娼╅柡澶嬪灴閹割剟鎮橀悙鍙夊櫢闁?闂?闁诲繐绻楁ご绋课ｉ幖浣瑰仺闁靛绠戦悡鏇㈡煙閹碱厺绨绘繛瀛橈耿閺?
        //      "濠电偞鐓＄粻鏍偂閸撲椒娌柛娑卞墲閸橆剙顭块崼鍡楀暟濞堥亶姊?/ 闂佸搫鍟版慨鐑藉疾椤愩倓鐒婇煫鍥ㄦ尵濞堥亶姊婚崼娑樼伈婵炵⒈鍓欓? 闂佹眹鍔岀€氫即宕戦崨鏉戠骇闁炽儴娅曢埢鏇犫偓娈垮枛閸婂爼鍩€?
        //   闂佸疇娉曟刊瀵哥箔?闁诲繐绻嬬欢姘焽閹殿喗濯奸柍琛″亾缂傚秴鎳橀幃?`padding.left` 闁荤偞绋忛崝蹇涘箵椤忓牊鏅? 闁诲繐绻嬬欢姘焽娴兼潙鐭楃€规洖娲ㄩ崰?+ 12闂佹寧绋戦¨鈧紒?
        //      婵炴垶鎸哥€涒晛螞閵堝鍋╃€光偓閸曨剚绁?`floatingCover`/`metaRow` 婵炴垶鎸堕崐鏇㈡儑閺夎鐔碱敂閸曨剙鈧姊洪幐搴ｆ噥缂傚秴鎳忓蹇涘箚瑜嶉悡鍌炴煟閵娿儱顏紒顔哄姂瀵顭ㄩ崨顖涙儯婵炲濮甸悘姘跺焵椤戣法顦﹂柣顭戝灡缁嬪鍩€椤掑倷娌柛灞厩氶崑?
        //
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮?`floatingMeta` 闂佹眹鍔岀€氼亞鎮潏鈺€娌柛灞句亢閸╁矂鏌?* 闂佺偨鍎查弻锟犲焵?婵炶揪绲界粔椋庢崲瀹ュ洨涓嶆俊銈呭暣閻涙捇鏌涘顒佹拱闁诲寒鍨堕弫?
        // ```
        //   婵犮垼鍩栭悧鏇㈡儑?Column().width('100%').height(overlayBaseH())
        //                .justifyContent(FlexAlign.Center)        闂?闂佸憡鐟禍锝囩矆鐎ｎ剚瀚?缂備焦姊归悧婊兠虹捄銊ゆ勃闁告侗鍓濋崢?
        //                .hitTestBehavior(HitTestMode.Transparent)
        //     闂佸憡鍔曢幊搴ㄦ儑?Column().width('100%').alignItems(HorizontalAlign.Start)
        //                  .offset({ y: metaOffsetYAt(swiperProgress) })   闂?闂佸憡鐟禍锝囩矆鐎ｎ剚瀚?闂佺儵鏅濋…鍫ヮ敋椤斿彞娌柛娑卞墲閸橆剟鏌ｉ妸銉ヮ仹缂傚秴鎳愮划?
        // ```
        // 闂佹寧绋戝澧倁jie.pa:195907-196008`闂佹寧绋戦ˇ顐﹀闯?闂佺懓鐡ㄩ崹鍐差煥閹达附鍋傜憸宥夊箖閹惧鈻旈柍褜鍓濋妵鎰板閵忕姌锕傛煙閽樺锛旂紒杈╁瀵板嫰寮借濠€瀵哥磽?*闂佺硶鏅涢幖顐﹀闯椤栫偞鍎?*闂佹寧绋戝濉璼tBoxHVp()`闂?
        //   婵?`overlayBaseH()` 闂佸憡鑹炬總鏃傜不閻斿吋鏅慨姗嗗墮鐠佹煡鏌ｉ～顒€濮傞柣?闂?闂佺鐭囬崘銊у幀闂佸憡鐗滅亸銊ф濮樿埖鏅悘鐐舵閺佸爼鎮橀悙鎻掆偓濠氬极?`.offset()` 闁荤姍鍌氬祮闁稿鎳樺?lerp闂?
        // 闂佸疇娉曟刊瀵哥箔?闂佸憡鍨规慨宕囩礊瀹ュ棛鈻斿┑鐘辫兌閻熴垹鈽夐幘绛规缂佹梹鎸抽幃褔宕奸姀锛勬殸 `.position({y: metaTopGeomY(...)})` **闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯兼暩閹肩厧霉?*
        //   闂佹寧绋戝濉礶taOffsetY()` 闂備焦褰冮懟顖炲礄閿涘嫮纾奸煫鍥ㄦ煥鎯?闁诲繒鍋涢幊宥夋嚈閹寸偞濯寸€广儱娲ㄩ弸?闂佸憡鍨电换鎴犳暜閳ь剙霉濠婂啯锛旂紒杈ㄥ哺閺佸秶浠﹂幆褍绨ラ梺姹囧妼鐎氼剝銇愯瀵?*缂傚倷鐒﹂幐濠氭倵椤栨稓鈻旈幖绮光偓宕囩▔閻?*闂?
        //   婵炲濮寸€涒晠顢楀┑鍥ㄥ鐎广儱娉﹂埡鍛強?闂佺儵鏅濋…鍫ヮ敋椤曗偓瀹曟椽宕崟顐ｇ彲闂佺儵鏅滅敮濠囨嚈閹达絿鐤€闁告劦浜濋悾閬嶆煕鐎ｎ亞绠虫禍?闂佹寧绋戦懟顖炲箯娴兼潙绫嶉柣妯虹仛濞呮洟鏌涘顒€顨欑紒鏂跨摠缁嬪顢旈崼婵囶仭缂備焦宕橀婊呮濠靛洨鈻旈悗锝傛櫇椤忚鲸鎱ㄥ┑鍕姤闁汇劎鍠栧畷锝夊磼濞嗘垹鎲归梺娲绘娇閸斿矂宕埀顒勫级閳哄倹鐓ュù鍏煎姍婵?
        Column() {
          Column() {
            Row() {
          Column() {
            Text(this.state.getCurrentSongItem()?.title ?? '', { controller: this.titleController })
              // 闂?缂備焦妫忛崹鎶藉磻閿濆棛鈻斿┑鐘插暙琚氶梺鎸庣☉閻楀棛鏁?`MusicPlayInfoBlock` 闂佹眹鍔岀€氼垱绂嶇€靛憡瀚婚柨婵嗙箳缁€鍡涙煃閵夛附鐓涢柍?闁?`publishMetaEndpoint`
              .id(PLAYER_META_TITLE_ID)
              .onAreaChange((): void => {
                this.publishMetaEndpoint(false);
              })
              .fontSize(this.metaTitleFp())
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.play_text_color'))
              .opacity(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width(StyleConstants.FULL_WIDTH)
            Text(this.state.getCurrentSongItem()?.singer ?? '', { controller: this.singerController })
              .id(PLAYER_META_SINGER_ID)
              .onAreaChange((): void => {
                this.publishMetaEndpoint(true);
              })
              .fontSize(this.metaArtistFp())
              .fontWeight(FontWeight.Regular)
              .fontColor($r('app.color.play_singer_color'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width(StyleConstants.FULL_WIDTH)
              .margin({ top: 2 })
            // ★★★ 2026-10-18（第五轮）：小歌词搬回"歌名行之下"，而且**只属于封面页**（见下）。
            //   位置 = 本 Column 的**第 3 个子节点**（主轴自然排在歌手文字之后）⇒
            //     小歌词顶边 ≡ 歌手文字底边 = 歌名行盒顶边 + title.h + 2 + singer.h
            //     x          ≡ 歌名/歌手文字左缘（**同一个 Column**：`metaRow` 的 `padding.left`
            //                  = `lyricMetaLeftInset()` 已经在这条链上生效，不需要再抄一遍 margin）
            //   两个等式都不经过实测、不经过 `estBoxHVp()`/`metaOffsetY()` ⇒ 完整推导见
            //   `MiniLyricLinesBlock()` 的 JSDoc。
            this.MiniLyricLinesBlock()
          }
          // ★ 定高容器（客户口径「让居中盒按容器高居中」）：文字列高度钉死 = 歌名行高 34。
          //   ① 小歌词是**溢出**的兄弟（34 的盒装不下 34+57），不参与这个 34 ⇒ 子节点个数/高度变化
          //      都不会再让整组被重新居中（上一轮"组高 91 被上抬 28.5vp"的坑从结构上消失）；
          //   ② 这个 34 与 `metaOffsetY()` 里减掉的 `centeredTop = (estBoxHVp() − 34)/2` 是同一个常量
          //      ⇒ 位移壳顶边 = `metaTopGeomY(t, 34)`，歌名行的 y 逐值不变。
          .height(PlaybackPage.LYRIC_META_ROW_H_VP)
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 闂?闂佸搫鍟版慨鐑藉疾?`metaRow` 闂佸憡鐟ラ崢鏍疾閸洘鐒介柨婵嗗閳峰牆鈽夐幙鍐х盎婵炲瓨锕㈠浠嬪炊妞嬪海顦ーPlayerPage闁诲海鎳撻張顒勫汲椤ゆ杯闁诲氦顫夊銊┾€?md` 闁?.2闂佹寧绋戦¨鈧紒?
          //   `SymbolGlyph 闂佽　鍋撻柟顖滃椤ユ叢 + `SymbolGlyph 闂佸搫娲﹀娆撍囩缓娑㈡煏?
          //   闂佽　鍋撻柟顖滃椤ユ垿鏌?`MusicStoreService`闂佹寧绋戦悧鍛箔?`MusicPlayInfoBlock` 闂佸憡鑹炬總鏃傜博鐎涙闄勬俊銈呭閸ゃ垽鏌涢幇顓犳嚂缂佽鲸宀搁弫?
          //   闂佸搫娲﹀娆撍囬崸妤€绠ラ柟鎯х－绾剧粯鎱ㄥ┑鍡樻拱婵炲弶鎮傞幊锝咁煥閸愩劎顦?闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊濂告煂?sheet 闂?`ControlAreaComponent` 闂佹椿婢€缁鳖喚妲?
          //   闂佺粯顭堥崺鏍焵椤戣法顦﹂柛鎴節楠炴捇骞囬鈧壕鎶芥煕閹烘柨顣兼繝鈧悧鍫涗簻缁炬澘顦辩粈鍒瀙layMenuOpen`闂佹寧绋戦¨鈧紒杈ㄧ箘閹插瓨绗熼埀顒勫磻閸涘瓨鐓傜€光偓閳ь剙鈻?`@Param`/`@Event` 闁荤姴娲ら悺銊ノｉ幋锕€违?
          SymbolGlyph(this.isCurrentFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(this.expandState.chromeFavSize())
            .fontColor([this.isCurrentFavorite ? $r('app.color.player_text_primary')
              : $r('app.color.play_text_color')])
            .margin({ top: 2 })
            .responseRegion({
              x: -10, y: -10,
              width: PlaybackPage.LYRIC_META_HIT_VP, height: PlaybackPage.LYRIC_META_HIT_VP
            })
            .onClick((): void => {
              this.toggleFavorite();
            })
          // ★★★ 2026-10-18（用户：「收藏旁边的歌曲菜单改成评论（已有实现）」）：
          //   这颗原来是**歌曲菜单**（`dot_grid_1x2_circle` → `playMenuOpen = true`）。
          //   现在改成**评论**：图标用底部那排评论按钮同一个 `sys.symbol.text_bubble_left_2`，
          //   点击只 bump 共享序号 `intent.commentRequestSeq`，由 `ControlAreaComponent` 的
          //   `@Monitor('intent.commentRequestSeq')` 打开它那个弹层的评论子页
          //   （**没有第二份面板**：一个组件只能挂一个 `bindSheet`）。
          //   歌曲菜单本身没丢：它搬到了右上角（`TopAreaComponent`，同样走共享序号）。
          SymbolGlyph($r('sys.symbol.text_bubble_left_2'))
            .fontSize(this.expandState.chromeFavSize())
            .fontColor([$r('app.color.play_text_color')])
            .margin({ top: 2, left: 14 })
            .responseRegion({
              x: -10, y: -10,
              width: PlaybackPage.LYRIC_META_HIT_VP, height: PlaybackPage.LYRIC_META_HIT_VP
            })
            .onClick((): void => {
              this.intent.commentRequestSeq = this.intent.commentRequestSeq + 1;
              Logger.info(PlaybackPage.logTag, `meta comment tap seq=${this.intent.commentRequestSeq}`);
            })
        }
        .width(StyleConstants.FULL_WIDTH)
        // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍛村箞閵娾晛鐐婇柣鎰皺缁夋椽鏌ㄥ☉姗嗘缂佽鲸澹嗛幃鏉跨暆閸曨厼钂?*闂婎偄娲ら幊姗€濡磋箛娑欏仺闁靛鍔屽▓浼存椤掑浜柛銈嗙矒閹偤宕奸弴鐘茶拫闁?*闂佹寧绋戦悧鍐╂櫠?4vp闂佹寧绋戦¨鈧紒?
        //   **婵炴垶鎸哥粔鐑藉礂?*闂?`this.lyricFloatRect().size` 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊濂告煂濠婂牆纾归柣鎾冲闊?`t = 0`闂佹寧绋戦悧鍡涙儍濠靛顥堥柕蹇嬪€戦埀顒€顦甸弫宥嗗緞鐎ｎ偒妲梺?
        //   **婵犮垹鐖㈤崘顏咁唸闂傚倸鐗勯崹鑲╃博閻斿吋鈷愰柛鏍电磿缁€?28vp闂?*闂佹寧绋戦惌鍌炲储閵堝棛鈻?`VerticalAlign.Center` 婵炴潙鍚嬬喊宥嗕繆閸涘﹦鈻旈柕鍫濈墱閺€浠嬫煛閸屾碍鎼愰柣鈯欏洤绠抽柕濞垮劚閻撳倿寮堕埡鍌滄噥缂佹柨顕弫顕€鏁傞悙顒傛殸婵炴垶鎼╅崣鍐ㄎ?
        //   闂?**闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏犵仛閻ｈ鲸鎱ㄥ┑鍡氬闁诡喗娲滈幃顕€顢曢姀銏㈢崲婵炴垶鎸搁鍡欐暜閸︻厾妫?164vp**闂佹寧绋戦悧鎰板箚閵堝绀嗛柡澶庢硶濞煎本顨ラ悙瀛樼缂併劍濞婇弻鍫ュΩ閿濆倸浜惧ù锝囶焾缁旈箖鏌涢敂鍝勫閻㈩垰鐖煎畷姘辨崉閸濆嫰娈繛鎴炴尭椤厾妲愬璺何?
        .height(PlaybackPage.LYRIC_META_ROW_H_VP)
        .alignItems(VerticalAlign.Center)
        .padding({
          left: this.lyricMetaLeftInset(),
          right: PlaybackPage.LYRIC_META_SIDE_VP
        })
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佺粯鎸嗛崟顒€鍓堕梺鍝勫暟婵兘寮查锔藉剭闁告洦浜炵粔瀵哥磼婢跺寒鍤欓柛娆愭礀椤曪綀绠涢弮鈧幏鍗灻?* 闂佺偨鍎查弻锟犲焵?闂佸憡甯炴慨鐢垫暜閳ь剟鏌￠崼顐㈠幐缂侇喓鍔戦幊娑㈩敂閸曨厽姣庨梺姹囧妼鐎氫即宕戦崨鏉戠濠电姴鍟拏瀣偓娈垮枛缁绘劙鎮哄▎鎾存櫖?
        //
        // 闂佸憡顭囬崰鎰焽閸偅浜ゆ繛鍡樻尭濞咃繝鏌￠崟闈涚伈缂?
        // ```
        //   y: lyricMetaMorphY(t) + t 闁?(lyricFloatRect().size 闂?LYRIC_META_ROW_H_VP) / 2
        // ```
        // 婵炴垶鎸堕崐鎾绘煂濠婂牊鈷掓い鏇楀亾妞わ絼绮欓弫宥夊醇閵夈儱骞嬮梺?闁?30/闁?31 闂備焦褰冮惉鑲╁垝閻楀牏顩查柛鈩冾殔濮ｅ顭跨捄鍝勵伒缂佽鲸宀搁弫?
        //   闂?`lyricMetaMorphY` 闂?`from` 缂備焦妫忛崹鎶藉磻閿濆鍋ㄩ柕濞у嫮鏆犻梺鍝勫閸ㄥ崬锕㈤悧鍫㈩浄闁瑰墽鎳撳▓浼存倵鐟欏嫭鐨戞繛?`LYRIC_META_GAP_VP = 10`
        //      闂佹寧绋戦悧鎾诲磻閸涱喚鈻旀い蹇撳閸╂姊洪幓鎺旂婵炲牊鍨甸埢鏃堝Ω閳轰焦鐝甸梺鐓庮殠娴滄粎鎹㈡笟鈧畷妯衡枎閹寸偟绁烽梺闈涙閺堫剙锕㈤悧鍫涗簻闁革富鍘界粣妤€霉閸忓吋绶查柣锝夌畺瀹曟劗娑垫搴ｎ槷闂傚倸鐗忛崑銈夊焵椤掆偓濡骞冨鍫濈９缂佹銆€閸嬫挸顓艰箛鏇狀槴闂?
        //      闂佸吋婢橀張顒€螞閵堝鍋?`fitPlayerOverlay` 闂?gap 闂?*缂佺虎鍙庨崜娑氭椤忓牊鍎?50** 闂佺偨鍎查弻锟犲焵?
        //      闁诲海鎳撻崯浼搭敄?6 婵炴垶鎼╂禍婊堟偪閸曨垰鐭?`chrome().metaGap` **闁荤偞鍑归崑鍌氣槈椤忓嫷鍤?*闂佹寧绋戝濉篹fitOverlay` 婵?6 婵炴垶鎼╂禍妤呭焵?
        //      `fitPlayerOverlay` 闂佸憡鐟禍婵嬪极?5 婵炴垶鎼╂禍椋庢濮樿泛鐒?闂備緡鍙忕徊濂告煂?10 闂佸搫瀚烽崹杈ㄤ繆?闁荤偞鍑归崑鍌氣槈椤忓嫷鍤曢柛鎰典簼閻ｉ亶鏌涘▎蹇撯偓褰掑汲?閻熸粎澧楅幐濠氬垂濮橆厾顩查柛鈩冪懄閸╁倿鏌涙繝鍕靛劆闁?
        //   闂?`to` 缂備焦妫忛崹鎶藉磻閿濆鍋ㄩ柕濞у嫮鏆犻梺?闁诲繐绻愮换鎰版儍濠靛顥堥柕蹇嬪€戦埀顒€锕ュ?闂佹寧绋戦懟顖炴儍椤栫偛绠?`metaTopFixLyric`闂?
        //      闂?`t 闁?(size 闂?rowH)/2` 闂備緡鍙忕徊濂告煂?闁诲繒鍋涢幊宥夋嚈閹寸姵鍋橀柕澶堝劙缂?闂佸憡鐟ラ悧濠偽ｉ幖浣稿珘妞ゆ垼娉曞▔銏ゆ煠婵傚绨婚柛銊╀憾閹啴宕熼褍鍓虫繛鎴炴尭椤︾敻濡村澶娢?
        // 闂?闂佺粯绮嶅妯猴耿椤忓牊鍎庨悗娑櫭径宥夋偣?*婵炴垶鎸撮崑鎾斥槈?*闂佸搫鐗嗛ˇ顖炲吹椤撶喎绶為柛鏇ㄥ幗閻ｉ亶鏌涢幋锝呅撻柡鍡欏枛閺佸秹宕搁崚纾倀aTopGeomY`闂佹寧绋戞總鏃傛偖鏉堚晝鍗氭い鏍ㄧ矊娴狀垶姊洪锝呭闁烩姍鍥х骇闁靛鍔屽▓?
        //   `CoverMorph.metaOffsetYAt` + `fitPlayerOverlay`闂佹寧绋戦¨鈧紒杈ㄧ箞瀵敻顢楅崘鐐杸婵炴垶鎸哥粔鎾疮閳ь剟鏌￠崼婵愭Х闁瑰箍鍨洪幏鍛村即閳ヨ櫕顔囩紓鍌氬€归悧鐘诲Υ瀹ュ违?
        //
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂佹寧绋掗惌顔剧礊閸涱垳鐭?*婵?`.position()` 闂佺懓澹婃禍婊堝春鐏炴儳绶為柡宓懏鍕鹃梻渚囧弿缁插ジ鏌?`Column` 闂?`.offset()`**
        //   闂? 闂佸搫鍟版慨鐑藉疾?`floatingMeta` 闂佹眹鍔岀€氼剟鎳滄导瀛樺亹閻犱礁婀辩粈澶愭偡濞嗗孩顦风紒妤€鍊垮Λ鍐閳ュ磭绁烽柡澶嗘櫆缁嬫帒顭囬悽鍛婂剭闁告洦鍨版禍婵嗏槈閹惧崬鈧洟鎯囨导瀛樻櫖濠㈣泛鐗冮崑?
        //   `metaOffsetY()` = `metaTopGeomY(t, rowH) 闂?(闂佺硶鏅涢幖顐﹀闯椤栫偞鍎庨柟鐑橆殘瑜?闂?rowH)/2`
        //   闂?婵炴垶鎸告鍝ユ暜椤愶箑绾ч柕澶嗘櫅娴滄繈鏌?`.position({ y: 闂?})` **闂備緡鍋呴崝鏇㈠磿濮樿鲸顫曢柣妯兼暩閹肩厧霉?*闂佹寧绋戦懟顖濄亹瑜旈獮鎴﹀閻樿尙绋夐悗鍨緲鐎氥劑鍩€?
        //   闂佸疇娉曟刊瀵哥箔?闂佸憡顭囬崰鎰焽?`.position` 闂備焦褰冮惌鍌炲磻閸涱厸鏋?缂備焦鍔栭〃鍛般亹?闂?婵＄偑鍊濆褔宕幘顔肩闁靛繈鍨婚弳顒勬煥濞戞ɑ缍乵etaTopLocalY`闂?闂佹眹鍔岀€氼參寮抽埀顒勬偣娓氬洤骞掔紒顔界洴閹偤鎳滈崹顐ょ暢闂佽桨绀侀悧鐐垫?
        //     `metaTopGeomY` 闂佹眹鍔岀€氼亞鎮潏銊р枖妞ゅ繐妫导鍌炴煟?*闂佸搫鐗滈崜姘焽閻㈠吀鐒婇弶鍫涘妽绗戦梺瑙ｅ亾闁芥ê顦遍弳浼存煙椤戣法顦﹂柛銈嗗灦閹?*闂佹寧绋戦悧鍡涱敊閹版澘闂柕濠忕細閼割亞绱掑☉姗嗘Ч婵＄偛鍊荤划璇参旈埀顒勫吹椤撱垹绾ч柕澹嫮鏆犻梺绋匡功閵嗗妲?
        //     闂?**閻庤鐡曠亸娆戝垝閿熺姴鍙婃い鏍亼閳ь剙顦靛畷姗€宕ㄩ鐔虹▌闂佸搫绉村ù鍕濠靛洨鈻旂€广儱鐗滈崯鍛存煕閹邦剛小缂?`1/morphScale`**闂佹寧绋戦悧鍛不缂佹顩查柛鈩冾殕閻ㄦ垵霉?闂佺绻愰悧鎾凰夐敐澶婄闁哄娉曞▓閬嶆⒒閸偅濞囬柍褜鍏涚粈渚€宕埀顒€鈽夐幘鎰佸剱婵?闂佹寧绋戦ˇ顓㈠焵?

        // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍛村箞閵娾晜鍋ㄩ柕濠忕畱閻撴洟鎮楅崷顓炰沪缂佷焦鎸虫俊?*闂佸憡鏌ｉ崝搴ㄥ极閻愵剛鈻旀い鎾噰閸嬫捇寮崜褏鐛ラ梺鍛婂灱濞咃綁鐛崶銊р枖闁靛牆瀚伴崵瀣叏濠靛棜瀚伴柟顔芥礀椤垻浠﹂幆褜鏉?*闂佹寧绋戦悧濠傦耿娴ｅ湱鈻旈柍褜鍓氱粙澶愵敂閸涱啩锔界箾閸繍鍎戦柡鍡忓亾闂佹眹鍔岀€氥劑鍩€?
        //   婵炲濮伴崕杈ㄦ櫠閻樿鐑樸偅閸愵亜寰撻梺娲绘娇閸斿骸鈻撻幋婵愭桨閻忕偠濮ら崐铏叏濠靛棙婀板褎绮嶉ˇ浼存倷閹绘帒姹查梺鎸庣☉椤︻參鍩€椤掆偓缁嬪嫮妲愬鑸垫櫖?
        //   **闁哄鏅滈悷銈囩博鐎靛憡鍋橀悘鐐舵閺傃囨煛婢跺牆鍔滄俊鍙夋倐瀹曟ê鈻庨幇闈涘Г闂?`.opacity(1)`**闂佹寧绋戦悧濠囧极閻愮儤鐓傚┑鐘插閸婄偤鏌ｉ姀锝夊摵婵?闁汇埄鍨遍幃鍌炲煘?闂?闂佽鍘界敮鎺曘亹閼碱剚鍠嗗〒姘功缁愭鎮樿箛搴ｇ獢婵炶偐澧楅妵鍕偨缁嬪じ绨兼繛瀵稿Ь婵倝鎮洪弴銏犺Е?
        //   闂佸憡顭囬崰鎰焽閻㈠憡鍋?`MusicPlayInfoBlock` 闂佹椿婢€缁鳖喚妲愬┑鍫氬亾閻熸澘鏆欓柛鎴斿墲缁傛帗鎯旈妸锝傚亾?0 缂備礁顦…宄扳枍?闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?闂備緡鍙忕徊濂告煂濠婂牊鍋犻柛鈩冪懄閺?*闂佸憡鐟禍婊堫敋椤曗偓濡啫鈻庨幇闈涘闂佽鍏涢悞锕傚垂濮樿京鍗?*闂?
        //   闁诲海鎳撻崯顖涗繆閸涘﹦鈻旈幖绮光偓鍐茶劘闂傚倸鎳庡Λ妤呮儑娴煎瓨鍎?*婵炲瓨绮嶇敮妤呭几婵傚憡鈷掗柕濞垮€楅閬嶆偣瑜旈弨杈ㄥ垔閸洖绠冲璺侯槺閸?*闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁俊顖滅帛閸╁倿姊婚崒娑欑稇闁挎稒鎸炬禒?`MorphMetaBridge`
        //   闂佹寧绋戦悧鍡楊潩閵娾晛鍙婃い鏍ㄧ矋閺嗗繘鏌熺€靛憡鐒挎い鏇楁櫊閹?婵炲濮伴崕杈ㄦ櫠閻樿鐑樸偅閸愵亜寰撻梺娲绘娇閸斿骸鈻撻幋婵愭桨閻忕偠濮ら崐铏叏濠靛棙婀板褎绮嶉ˇ浼存倷閹绘帒姹?闂佹寧绋戦ˇ顖氾耿椤忓牊鍋ㄥ┑鐘冲嚬濡囨偠濞戞ê顨欓柤鍨灴閹啴宕熼鍌涙啓闂佸憡鑹剧粙鍕濠靛鍤€閻忕偟鍋撻幏閬嶆偠?*闂佸憡鑹鹃張顒€顪冮崒鐐茬煑闁割偅绻傚鍨?*
        //   闂?**婵炴垶鎸堕崐鏇€冨鍐炬桨閻忕偠濮ら崐鎶芥煕濮橆剚婀版俊鐐插€垮畷鐑藉Ω閵夛妇鐨?*闂?
        //   闂?闂佺懓绠嶉崹娲垂濮樿泛绫嶉柣妯虹仛濞呮洟姊洪銊хМ濞存粓绠栧?`targetMetaOpacity()`闂佹寧绋戝濉抣ayerExpandState` L1325-1335闂佹寧绋戦¨鈧紒?
        //     閻?stage = OPEN 闂?**1**闂佹寧绋戦悧鎰板箚閵堝棙濯寸€广儱鎳忛崐鐢告煙椤撶喎绗掔憸鎷屽皺閹插瓨绗熸繝鍕槷闁荤喐娲栧Λ娑樏?闁诲繐绻嬬欢姘焽閻楀牄浜滈柣銏㈩焾娴滄繂霉閻樺搫袚闁烩剝娲熷畷?闂佹眹鍔岀€氼垱绂嶇€靛憡瀚?闂佺繝鐒﹂幖顐ゆ濮樿埖鏅?
        //     閻?閻熸粏鍩囬崹纭呫亹婢跺鈻旀い鎾寸箘閻燁剟鏌涜箛鎿冨剶婵炲牊娲滄禒锕傚磼濞戞ê顦茬紓浣哄Л濡插嫮妲愬淇秂taBridgeOwnsPaint()`闂佹寧绋戦ˇ顐﹀闯?**0**闂佹寧绋戦悧鍛潩閿曗偓铻為柟鐑樻⒒閼稿爼鏌涜箛鎿冨剶婵炲牊娲滄禒锕傚磼閿斿墽顦梺?
        //     閻?閻熸粏鍩囬崹纭呫亹婢跺鈻旀い鎾寸箘缁嬪鏌涜箛鎿冨剶婵炲牊娲滄禒锕傚磼濞戞碍鈷曢梺瑙勪航閸庢娊顢?闂?闂備緡鍋€閸嬫捇鏌?`pullChromeOpacity()` 闂備緡鍙忕徊鎯ь焽椤栨搴ㄥ灳閸愭彃姹查梺鍝勬穿鐏忔瑩宕垫惔銊ノ?
        //   闂佸疇娉曟刊瀵哥箔?`MusicPlayInfoBlock`闂佹寧绋戦悧鍡涱敊閺冨倷娌?/ 闂傚倸鐗勯崹鍝勵熆濮椻偓閺屽洭鏁愰崟顔规嫛闂佽　鍋撴い鏍ュ€楃粈?*婵炴垶鎸撮崑鎾绘煟閳轰緡鍤熼柡浣靛€濋幆鍐礋椤愶絿娈ら梺鍝勫閸ㄤ即鎮?*闂佹寧绋戝﹢?39 / L411 / L447闂?
        //      闂?闂佸憡鑹炬總鏃傜箔閸屾稓鈻旈柍褜鍓氬鍕礋椤忓棭浼囬梺鍝勭Т閸ゆ牜妲愬┑瀣煑闁割偆鍠愮瑧闂侀潧妫楅懟顖炲箖閹惧鈻旈柍褜鍓濋妵鎰板閵忕姌?N 婵犮垼娉涚€氥劑鍩€椤戣法顦︾憸鎶婂洤缁╅梺顐ｇ〒閸熷﹤鈽夐幘顖氫壕婵犮垼娉涚€氥劑鍩€椤掆偓缁夌數妲愰敓鐘茬濠㈣泛鏈悾閬嶆⒑椤撱劎瀵肩紒鏂跨摠瀵板嫰宕熼埞鎯т壕?
        .opacity(this.expandState.targetMetaOpacity())

        // ★★★ 2026-10-18（第五轮 · 照搬上游盒模型）：**小歌词块 = 歌名行的流式兄弟**，不再绝对定位。
        //
        //   上游 `floatingMeta` 的真实盒模型（`wujie.pa:195907-196014`；逐行还原见
        //   `_recover/logic-src/full/上游播放页歌词块全量.ets` §三）：
        //     Column()  .width('100%') .height(overlayBaseH() > 0 ? overlayBaseH() : '100%')
        //    │          .justifyContent(FlexAlign.Center)                  ← `wujie.pa:195907-195944`（居中盒）
        //    └ Column() .width('100%') .alignItems(HorizontalAlign.Start)
        //               .offset({ y: this.morph.metaOffsetYAt(this.swiperProgress) })
        //                                                                  ← `wujie.pa:195968-196014`（位移壳）
        //       └ metaRow()                                                ← `wujie.pa:171797-171846` / `194748-194831`
        //   ⇒ 「歌名行之下」唯一合法的位置 = **位移壳的下一个子节点**（跟在 `metaRow` 后面、走同一条流），
        //     既不需要也不允许第二套坐标系。
        //   本仓对应：居中盒 = 下面那个挂 `.height(estBoxHVp()).justifyContent(Center)` 的 Column；
        //   位移壳 = 正挂着 `.offset({ y: this.metaOffsetY() })` + `.translate({ metaRiseVp() })` 的这层。
        //
        //   ⛔ 旧实现在 `Swiper` 第 0 页用 `.position({ x: 0, y: this.miniLyricTopY() })`（**窗口绝对 y**）
        //      ⇒ 与歌名行的「居中盒 + offset」是**两套坐标系**，`estBoxHVp()` ≠ 窗口高时必然偏，
        //        调公式永远调不出来（用户实测三轮）。页 0 已恢复成上游的空壳（见那里的注释）。
        Column() {
          MiniLyricLinesComponent()
            .width(StyleConstants.FULL_WIDTH)
            // 左侧口径与歌名行**同源**：歌名行是 `.padding({ left: this.lyricMetaLeftInset(), … })`，
            // 这里是 `.margin({ left: … })`；两者同为 `width('100%')` 的兄弟节点 ⇒ padding ≡ margin。
            .margin({
              left: this.lyricMetaLeftInset(),
              right: PlaybackPage.LYRIC_META_SIDE_VP
            })
            // 淡入窗口与位移**与歌名行同一个源**：
            //   · 上游歌名行自己是 `.opacity(0.86)`（`wujie.pa:194948`）叠在 `pullChromeOpacity` 上；
            //   · 小歌词保留用户拍过的 0.55（`PlaybackPage.MINI_LYRIC_OPACITY`）。
            .opacity(this.expandState.pullChromeOpacity() * PlaybackPage.MINI_LYRIC_OPACITY)
            .translate({ y: this.expandState.metaRiseVp() })
            .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            // ⛔ 2026-10-18（第五轮）：`.id(MINI_LYRIC_BOX_ID)` 已移交真身（`MiniLyricLinesBlock()`）。
            //    本残页若留着同名 id，`RzdBoxes` 的 `lyric=` 会读到这个空盒（`getFrameNodeById` 取第一个）。
            .onAreaChange((): void => {
              // 只做诊断：`RzdBoxes` 的 `lyric=` 与 `RzdBranch` 的 `miniClear` 判据都读这个 id 的矩形。
              this.logLayoutBoxes();
            })
        }
        .width(StyleConstants.FULL_WIDTH)
        // ⛔ 上一轮这里写的是"高度钉死 57 + 用 offset 补回 h/2"——**这套补偿本轮已删**（见下面 `offset`）。
        //    下面这个 57 只是残页自身的尺寸，它整块是 `Visibility.None`，对布局零影响。
        .height(PlaybackPage.MINI_LYRIC_BLOCK_H_VP)
        .justifyContent(FlexAlign.Start)
        // ⛔⛔ 2026-10-18（第五轮）：**这一整块是旧实现的残页：代码保留，但永不参与布局、永不绘制。**
        //   为什么留而不删：本块中间那些中文注释是**双重编码乱码**，`edit` 的 `old_string` 逐字匹配不上
        //   （见 `全局记忆.md` 的条目：`grep` 能命中 ≠ 字面相等）。按"删代码、留注释、旁边加说明"的纪律处理。
        //   小歌词的真身已搬到 `MiniLyricLinesBlock()`（歌名/歌手那一列的流式兄弟）。
        //   `Visibility.None` 的语义 = **不占布局 + 不绘制** ⇒ 位移壳的子节点数回到 **1**
        //   （只剩 `.height(LYRIC_META_ROW_H_VP)` 的 metaRow），外面那个
        //   `justifyContent(Center)` 的居中盒因此按 **34** 居中，与 `metaOffsetY()` 里减掉的
        //   `centeredTop = (estBoxHVp() − 34)/2` 是同一个 34 ⇒ 歌名行的 y 与"没有小歌词之前"逐值相同。
        .visibility(Visibility.None)
        // 闂佸疇妫勯幊澶娢ｉ崟顖氱叀闁告侗浜濋～?2026-10-17闂?*闂佸憡甯炴慨鐢垫暜閳ь剟寮堕埡鍌滄噰闁革絿鍏橀弻鍥晲閸℃鎷梺鐓庮殠娴滅偟妲愰鍫熷剭?180vp 婵炶揪绲界粔鏈电昂** 闂佺偨鍎查弻锟犲焵?goal 缂?1 闂佸搫顧€缁辨洖鈻撻幋婵愭桨闁挎繂顦板銊╂偡閺囨氨鍔嶉柣顏冨嵆閺?
        //
        // 婵炴垶鎸搁敃锝囩博閹绢喗鍋嬮柛顐悼缁犲綊姊洪幓鎺撴拱婵?`.translate({ y: this.expandState.metaRiseVp() })`闂?
        // `metaRiseVp() = (1 闂?ramp01(p, 0.18, 0.62)) 闁?**RISE_VP(180)** / morphScale`
        // 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊濂告煂?**180 闂佸搫瀚烽崹鍗烇耿閻楀牏顩烽柟鍓ф嚀濞堜即鎮楃憴鍕闁逞屽墰椤戞洟鍩€椤戣法鍔嶉柣銉ユ嚇瀵灚寰勬径瀣簥婵炶揪绲惧ú鏍吹椤撶喎绶?*闂佹寧绋戝濉旾SE_VP` 闂佹眹鍔岀€氼參寮悙鐑樼厒濠电姴鎳庡▓鎵偓鍦焾瀹曨剟宕幘缁樺創闁?闁诲繒鍋涚换鎰不閻戣姤鐓?闂佹寧绋戦ˇ顓㈠焵?
        //
        // 闂佸搫鍟版慨鐑藉疾椤愶絾浜ゆ繛鍡楁捣椤忛亶鎮跺☉妯肩伇婵炲牊鍨堕幏鍛吋閸?*闂佸憡鐟禍婵嗭耿娴ｅ湱鈻旈柍褜鍓熷?*闂佹寧绋戦懟顖氼潩閵娾晛鍙婃い鏍ㄧ懅閻熸劙姊婚崼娑樼伈闁稿鎳樺?`.position()` 闂備焦褰冮惉鐓庘枔?
        // ```
        //   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
        // ```
        // 闂佹寧绋戝濉乷verMorph.ets:205-211`闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?**lerp 闂佸搫鐗滈崜婵嬫閳哄啩鐒婇弶鍫涘妽绗戦梻渚囧弿缁叉儳顭?婵＄偛顑囬崑妯肩箔閸岀偛绾?**闂?
        // t=0 闂?婵犮垹鐖㈤崘顏咁唸闂傚倸鐗勯崹鍦姳閾忣偅缍?+ 50"闂佹寧绋戦?1 闂?闁诲繐绻愮换鎰版儍濠靛顥堥柕蹇嬪灮瑜般劑鏌ｉ埡鍐瘈闁煎灚鍨肩粻?闂佹寧绋戝濉紀pYAtLyric + 28`闂?
        // 闁?`META_TOP_FIX_LYRIC_VP`闂佹寧绋戦¨鈧紒?*闂佺绻堥崝蹇涖€侀幋鐘电煓閻庯綆鍓氶弳?t 婵＄偟鎳撳畷顒佹叏?*闂佹寧绋戞總鏃傜箔婢舵劖顥嗛柍褜鍓涢幉鐗堟媴缁嬫寧娅冮梺鍛婄懅婵磭绮╅幘顔肩骇闁挎稑瀚畷鍫曟煕閹邦剚鍣哥紓宥呮噽缁柨效閸ワ絽浜?
        //
        // 闂?闂佸憡甯炴慨鐢垫暜閳ь剟鎮楅悷鏉挎殨缂佺媴缍佸畷銉︽償椤栨粎鐛?
        //   閻?闂佸搫鍊稿ú銈夋偤瑜庣粙澶嬫償濠靛ň鎷℃繛鎴炴惄娴滄粌霉濮椻偓瀵?*闂佸憡鑹鹃懟顖炈囬埡鍌涗氦婵炲棗娴烽閬嶆偠?* 闂?婵炴挻纰嶇换鍕礉?婵炴垶鎸撮崑鎾绘偣瑜忛崗姗€藟閿濆棛鈻斿┑鐘插暞闂?闂佹寧绋戦悧鍛礊閸涱垳纾?lerp 闂佸憡鑹鹃張顒傝姳椤曗偓閺佸秵寰勫☉姘€?
        //   閻?濠电儑绲洪埀顒€鍟垮鍐裁归悩鑼ｉ悗?`targetMetaOpacity()`闂佹寧绋戦悧鍡涘船閹绢喖瑙?`pullChromeOpacity` 闂?0.18闂?.62 缂備焦鍔栭〃鍛般亹濞戙垺鏅?
        //     闂備緡鍙忕徊鎯ｉ幖浣瑰仺闁靛绠戦悡鏇犫偓瑙勭摃鐏忔瑩鍨惧Ο鍏煎闁靛牆娲﹂悾?闂佹娊顤傚浣烘濮樿埖鏅?
        //   閻?婵炴垶鎸哥€涒晛螞閵堝鍋?*闂佸憡鐟禍婊兾?闁哄鏅滅粙鎴犫偓鐟板暱閳?**闂佹寧绋掔喊宥夊垂濠婂嫮顩锋い鎺戝€归弳?`lyricMorphT`闂佹寧绋戦張顒€螞閵堝鍋╃€光偓閳ь剟寮?`swiperProgress` 闂佺偨鍎查弻锟犲焵?
        //     闁哄鏅滈悷锕傤敆濠婂牆鍙婃い鏍ㄦ皑閻涳箓鏌″鍛窛妞ゆ垵娲畷妤咁敇閳藉棙鏂€ `metaD`闂佹寧绋戦悧鎰邦敇閻熼偊娼伴柨婵嗘噺閸婄敻鏌ㄥ☉姗嗘Ъ妞も晪绠撻弻宀冪疀閺囩喓鏆犳繛鎴炴尰缁繘濡堕崸妤€违?
        //
        // 闂佸疇娉曟刊瀵哥箔?`earlyRiseVp()` / `contentRiseVp()`闂佹寧绋戦悧鍡涙儍椤掆偓椤垹鐣濋崘顏呅撶紓?/ 闂佺鐭囬崘銊у幀闂佸憡鐗炲▍锝囧垝瀹ュ鏅?*闂佸搫鐗滈崜姘额敃閸忚偐鈻旂€广儱鎳庤**闂?
        //   goal 缂?1 闂佸搫顦埀顒€鍟垮☉褔鏌ｉ幇鎵冲亾濞戞艾鏅╅梺绋跨箰閸熲晜绌辨繝鍥х畳妞ゆ牗绻嶉弨浠嬫煥濞戞瑧娲撮柛瀣噺缁嬪濡堕崶鈺冪厑闂?闂佺鐭囬崘銊у幀闂佸憡鐗炲銊у垝閻樺磭鈻旈悗锝庝簻绾惧啿鈽夐幘绛规敾婵?闂佹寧绋戦惉濂稿极閵堝绠ｇ€瑰嫭婢橀崵鎺旂棯椤撗冩灕妞ゆ挸顭烽幆?
        //   闂?闁荤姴娲ら顓炩枔閹寸姳鐒婇弶鍫涘妽绗戦柣搴ｆ嚀閸熲晛顭ㄩ幋锔界劷闁挎繂鎷嬪▓浼存煛閸愩劎鍩ｆ俊顐ユ硶缁絽螖鐎ｎ剛顦ーpullChromeOpacity` 0.18闂?.62 / `pullBottomIn` 0.45闂?.00闂佹寧绋戦ˇ顓㈠焵?
        //   闁诲海鎳撻崯鈺侇煥閹达箑瑙﹂悘鐐插⒔婢瑰鏌涘▎鎴澬＄紒銊㈠墲缁嬪鍩€椤掑嫬绾?180vp 闂佺偨鍎查弻锟犲焵?闁荤喐娲戝鎺旂箔婢跺本鍟哄ù锝夘棑椤忛亶鎮硅閸㈡煡鐛幘璇茬濠㈣埖绋撶粈澶岀磼濞戞﹩妲肩紒缁樼墪閳诲酣妾辨い顐㈡喘楠炲洭鎮㈠畡鏉垮敤婵☆偓绲介悧鍡涘疮閳ь剟鎮楃憴鍕暡缂佽鲸鐟ч幉?闁?30闂佹寧绋戦ˇ顓㈠焵?
          }
          .width(StyleConstants.FULL_WIDTH)
          .alignItems(HorizontalAlign.Start)
          // ⛔ 上一轮这里写着"位移壳的内容高 = 歌名行(34) + 小歌词(57) ⇒ 整组被上抬 57/2 = 28.5vp，
          //    所以 offset 要 +57/2 补回来"——**该推导本轮作废**，保留一行记号只为不改动历史注释：
          //    它隐含"位移壳恰有 34 与 57 两个子节点"这个前提；本轮小歌词已搬进 metaRow 内部，
          //    旧块又被 `Visibility.None` 隐藏 ⇒ 位移壳只剩 1 个定高 34 的子节点，补偿项没有存在意义。
          // ★★ 2026-10-18（第五轮）：**补偿项 `+ MINI_LYRIC_BLOCK_H_VP / 2` 删掉**（上一轮那半高补丁作废）。
          //
          //   一行算式（只做代数相消，不含任何实测值、不含第二套坐标系）：
          //     位移壳顶边 = (estBoxHVp() − 34)/2 + metaOffsetY()
          //                = (estBoxHVp() − 34)/2 + [ metaTopGeomY(t, 34) − (estBoxHVp() − 34)/2 ]
          //                = metaTopGeomY(t, 34)                ← 歌名行顶边 = 与"加小歌词之前"逐值相同
          //     小歌词顶边 = 位移壳顶边 + title.h + 2 + singer.h  ← 同一条主轴上的第 3 个子节点
          //                = 歌手文字底边 = 歌名行盒顶边 + 歌名/歌手两行文字高
          //   ⇒ 等式里只剩"34"这一个常量，而它出现的两处（居中盒的子节点定高 / `metaOffsetY()` 的 rowH）
          //     就是同一个 `LYRIC_META_ROW_H_VP` ⇒ 换机型、换 `estBoxHVp()` 都不会再偏。
          .offset({ y: this.metaOffsetY() })
          // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁诡厹鍨归ˇ?濞寸姴绨肩粭鍛存閵忕姴纾冲☉鎾筹攻濞?** 闁炽儲鏌￠埀?闁活潿鍔嶉崺娑氣偓鍦仦缁?
          //   闁? 闁衡偓閸︻厽鐣卞☉鎾崇Т椤曨噣鏁嶇仦缁㈠妧閻㈩垰鎲￠悺鏇㈠箥鐎ｎ亞瀹夐悹鍥ュ劙缁姵绋夌€ｎ喗妗ㄩ柛鎴犲劋濞肩敻濡撮崒娆戠☉闁活亜顑囧﹢鍛村籍閻樺灚娅曢柕鍡楃▌缁?
          //   闁瑰瓨鍨崇粭鍌涚▔閳ь剟鎮ч崼婵嗘锭闁稿鐭花?闁告帩鍋勭敮鍥ㄦ交濞戞瑥浠橀柛鎺曟硾鐏?闁汇劌瀚伴幐鎼佸礆鐠佸湱绀夐柛妤€鐡ㄦ俊鍛婃交濞嗗海顏遍悶娑樼灱濞?*闁告娲ら崣鍡樻媴瀹ュ泦?*濞戞挶鍨虹敮鈧ù?
          //   闁?閻庣懓鍟╃划鐘电箔椤戣法顏遍悽顖嗗啯鐨戦梺钘夘槸濠€顏堟媰閻ｅ苯浠柕鍡曠瑜把囧及椤栨稖绐楅柛?闁?閻熸瑥鍊归崝鍛▔鎼淬垺锟ラ柣锝呰嫰閻ｎ剟宕楅妸銈囩憹闁告艾琚埀?
          //   闁哄啰濮烽弲顐︽焽閿濆嫮顏遍悶娑樻湰濡?*閻犺櫣鍠撳鍐礃閸涱収鍟囧☉鎾亾閻犙嗘腹缁姵绋夌€ｎ亞绐斿☉鎾筹躬椤?*闁汇劌瀚哥槐娆撳籍閸洘锛熺紒?`WIN_META 0.18闁?.62`闁?
          //   濞?`pullChromeOpacity` 闁告艾濂旂粩瀛樼▔椤忓嫬闅橀梻鍌濇彧缁辨繃绋夐妶鍫氬亾閸涱厽鍊遍悹褍鍢查幃鎾绘媰閺傘倗绀嗛柕?
          //   闁?闁活潿鍔屽ú鏍熼垾宕団偓鐑芥煂瀹€鈧獮鍥箣閹邦喗鐣?`metaRiseVp()`闁挎稑娼?1 闁?ramp01(p,0.18,0.62)) 閼?RISE_VP / scale`闁?
          //     闂傚牊鐟﹂娑㈠箑娴ｉ€涜埅 0闁挎稑顦埀顒€鍊搁悾鐘崇▔鎼存繄鐟愰梻鍫涘灮濞堟垿鏌﹂崘鎻掔厬闁哄嫷鍨悮杈ㄧ閺堢數鐨戦柨?*闁告娲ら崣?*闁哄嫷鍨卞鍌炴⒒缂堢姷鐟愰柣銊ュ缁?
          //     **闂佽棄鍟块崺?*闁告瑯浜滈崰鍛偓瑙勪亢閹倝鎮欓惂鍝ョ濞戞挸绉烽蹇涘箮婵犲懏鍎伴柣鎰嚀鐢洦娼诲☉娆忎粯闁告帟娉涚亸顖炲Υ?
          .translate({ y: this.expandState.metaRiseVp() })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(this.expandState.estBoxHVp())
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 闂佸疇妫勯幊澶娢?2026-10-15闂佹寧绋戦悧鍛村箞閵娾晜鏅鑸电〒缁愭寮堕埡鍌滄噰闁革絿鍏樺畷銏ゆ偄閸涘﹪妾烽梺?`HitTestMode.None` 闂佺偨鍎查弻锟犲焵?闂備緡鍙忕徊鎯?**闂佺厧顨庢禍婊呮崲娓氣偓瀹曨亞浠﹂悾灞炬啢闂佺厧鎼崐濠氬磻閿濆鐒鹃柟瀛樺笧閻熸繈鏌涘┑鍡櫺㈢紒銊ㄥ皺閹叉挳鏁傞懞銉ユ疂**"闂?
      //   婵炴潙鍚嬬喊宥嗕繆閹间焦鐒介柨婵嗗椤忛亶鎮跺☉妯垮鐟滄澘鎲＄粭鐔活槾婵?*闂婎偄娲ら崯顐︽嚋?/ 闂佸搫娲﹀娆撍囬幐搴ｂ枖闁靛牆瀚伴崵瀣煙缁嬫妯€闁瑰憡濞婇幆鍐礋椤撶偘鍖栭梺鍛婂灱椤斿﹦绮╃€靛憡灏庣€瑰嫮澧楅崐鏍煙?*闂佹寧绋戦悧鍡楊潩閵娾晛鍙婃い鏍ㄧ⊕閹烽亶鏌涜椤ㄥ懘宕规导鏉戠闁绘ê鐏氶悾閬嶆⒑椤撱劎瀵奸悶姘抽哺缁嬪顢旀惔锝囶槴闂?
      //   闂佸搫鍟版慨鐑藉疾椤愶絽绶為柡宓懏鍕鹃梺娲绘娇閸斿骸鈻撻幋锕€鍙?`HitTestMode.Transparent`闂佹寧绋戝濉甽oatingCover` / `floatingMeta` 闂?
      //   濠电姴艌閳ь剙纾宀勬倵閸︻厽鍤€婵炲懏甯￠弻鍫ユ嚍閵壪€锕傛倵閻熸澘鏋︾紒杈ㄥ哺閺?*缂備礁鐭佸▍锝呪枍瑜庡鍕礋椤撴稒鏅梻渚囧亜缁绘劙宕虹仦鍓р枖閻庯綆浜炲﹢鎾煏閸℃洜顦﹂柣鈩冪懇閹崇偤宕掑鍐у寲闂佺粯鎸嗛崘顏勭厬闂佸憡鐟崹鎶藉磻?* 闂?闁哄鏅滈悷鈺呭闯閻戣棄缁╅悷娆忓閻忓洭鏌涘顒€顨欑紒鏂跨摠缁嬪顢旈崒妤€浜?
      //   闂佸疇娉曟刊瀵哥箔?闁诲繐绻嬬欢姘焽娴煎瓨鐒介柨婵嗘噽閻愬﹪鏌涢妷锕€绀冮柛銈嗙矊椤斿繘宕ｅΟ鑲╃厳闂佺粯甯熼崺鏍?`None`闂佹寧绋戦悧鍛箔閸屾稓鈻旈柍褜鍓涙禒锕傚磼濠婂嫮鏆?`Column`闂佹寧绋戦¨鈧紒杈ㄧ箞楠炲秹鍩€椤掍胶顩烽柕澶堝劤閺嗗﹤鈽夐幘宕囆＄紒鍙樺嵆楠炴劙鍨鹃懠顒傂ゅ┑鐘诧攻閸ㄥ灚鎱ㄩ埡鍛?
      .hitTestBehavior(HitTestMode.Transparent)
    }
}

/*
 * 闂佸疇娉曟刊瀵哥箔?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柣鎰帨閸嬫挾浠﹂懖鈺婁紘闂傚倵鍋撴繝濠傚暙閻撳倿骞栫€涙ɑ纾搁柍褜鍓欑粔鎾儓瀹ュ拋鍤曢柍褜鍓熷畷婵嬪Ω瑜庨弳浼存煟閵娿儱顏╃€圭顭峰畷锝囨嫚瑜忕粈?026-09-22 / 09-25闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍褜鍓氶弻銊╁疮閳ь剟鏌涢弬璇插濠⒀勭矒瀹曟粌顓奸崨顓炲紬闁荤姴娲╅褔鎮鹃鍕?
 *
 * 缂備焦顨忛崗娑氱博閹绢喗鍋嬮柛顐墰缁€鍕偓鐟版啞瑜板啰鑺遍幆褜鍤曢柛鎰硶缁€鍡涙煟?path 闁荤喍妞掔粈浣圭珶閳ь剟鏌熺捄鐚存敾闁哄棴绲鹃妵鍕媴閸愮偓鈷栭梺鐟扮摠閸旀鍖栭悩铏闁绘娅曢拏瀣⒑椤撱劎瀵肩紒鐘靛仦瀵板嫯顦存繛鍫熷灩娴滄瓕绠涢弴鐘茬倞闂佸憡鐟辩徊浠嬪疮閳ь剟姊洪锝呭闁硅埖宀稿褰掑垂椤旇桨娴烽梺鎸庣☉婵傛梻鎮潏銊р枖?API 闂備緡鍠涘Λ鍕焽閺嶎厽鏅?
 *   1. `clipShape(new PathShape({ commands }))` 闂佺偨鍎查弻锟犲焵?闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柛顭戝亝濞堣鈽夐幙鍐х胺缂佹顦靛浼村礈瑜嬫禒娑㈡煥濞戞澧ｉ柕鍡楀暣閹櫕锛愭担鐣岊槹闂佺懓鐏氶幐椋庣箔婢跺鍤曢柍褜鍓熼弫宥嗗緞濞戞艾鑰?
 *   2. `clip(new Path({ commands }))` 闂佺偨鍎查弻锟犲焵?闂佺粯鍔楅幊鎾诲吹椤曗偓楠炴﹢顢橀悢鍛婃緬闂侀潻绲婚崝搴∶洪崸妤€绠抽柕澶堝劚楠炪垺鎱ㄥ┑鍥╂菇闁?
 *
 * 闂佺粯绮嶅妯猴耿椤忓懏浜ゆ繛鍡樺灥椤ｅジ鏌ㄥ☉妯煎妞ゆ洦鍣ｅ浠嬪炊閵婏讣楠忛梺浼欑到閻倿鎮￠懜鐢碘枙?`ExpandAnimation` + `CoverMorph`闂?*闂佸憡鐟崹鎶藉极?*闂佹寧绋戦¨鈧紒?
 *   1. **闂佽桨鐒﹂幐鎶藉Υ婢跺瞼纾介柍鍝勫€归弶?+ 缂備焦姊归悧婊兠虹捄銊﹀晳濞达絿顭堥ˉ鍛磼閹邦収娈旂憸?*闂佹寧绋掗悺鐚ight / scale / translate / clipShape / opacity`
 *      婵炲瓨绮嶉弻褔鏌屽鍛勃闁绘劗琛ラ崑鎾诡檪缂佽鲸绻嗛妵鎰板閵忕姌锕傛煕濞嗘ü绨介柡?*闂侀潻绠戝Λ婊堬綖濡ゅ懏鍎楅柍杞版祰閸?*闂佹寧绋戝濉昬ctShape`闂佹寧绋戞總鏃傜箔婢舵劕鍙?path闂佹寧绋戦ˇ顐﹀焵椤掍焦鐓涢柍?
 *      闁?`PlayerExpandState.applyMorphProgress`闂?
 *   2. **濠碘剝銇滈崕鑼暜鐎甸晲鐒婂〒姘ｅ亾婵?*闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁俊顖滅帛閿涘秹鏌￠崼銏犳瀻鐎规洜鍠栭幃顏堫敆閸屾稒姣庢繛鎴炴尨閸嬫挾鈧鍠氭慨鎾儍濠靛顥堟い顐枤缁€澶娒归悩鍙夊攭缂侇垳濮甸幏鍛存偐閾忣偉鎷柣蹇撶箣缁舵艾顭囬幍顔剧＜妞ゆ挾鍋涢悡鍌炴煙缂併垹骞楅柡鍌欑劍閵囧嫰妫冨☉姘唸闂?
 *      闂佹寧绋戦悧鎰帮綖?`MorphCoverBridge` / `PlayerExpandState.morphCoverBridge`闂佹寧绋戦ˇ顓㈠焵?
 *
 * 闁诲海鎳撻崯鏉库枔閹达箑鐐婃繛鎴烆殜閸ゅ鐓崶褎鍤€妞も晪绠撳鍫曞灳閸欏鍋ㄩ梺鎸庣☉閻楀繐顔忔潏銊р枖闁逞屽墯缁嬪顢旈崟顒傛婵炴潙鍚嬪畝鎼佸焵椤戣棄浜鹃梺鍛婄墬閻楁宕?婵帗绋掗崹鐢佃姳?+ 婵炴垶鎸搁鍡涘蓟閻旇櫣鐭氶柧蹇氼潐椤?+ 婵炴垶鎸撮崑鎾绘煕瑜庨〃澶屾崲鎼粹槅娼伴柨婵嗘閻撴瑧鎲?闂佹寧绋戦¨鈧紒?
 *   1. **闂佸湱铏庨崢浠嬪棘娴ｅ箍浜滈柛蹇撴憸閻熴垹螞閿濆棛澧甸柕鍡楊槼缁犳盯宕ㄥǎ顑藉亾韫囨稑鎹堕柕濞垮劜閸婂崬鈽夐幘顖氫壕濠碘槅鍋傜徊濠氾綖鐎ｎ喖鐐婇柣鎰靛墰閸╂劙姊?*闂佹寧绋掗懝楣冩嚋娴兼潙鐭楁俊顖滅帛閿涘秹鏌￠崼銏犳瀻鐟滄媽灏欓幉鎾幢濞嗘垵褰侀悷婊嗗焽閸ㄧ銇愯瀵灚寰勬惔锝囶暔婵炶揪绲挎慨闈涱焽椤栨粈鐒婂〒姘ｅ亾婵為棿鍗抽弻鍥晲閸曨厾鏉芥繝銏犵垻瀹ュ洨顦?
 *      闂佺绻戝﹢鍦礊閹达附鐒鹃柕濞垮劚閻庡鏌￠崟闈涚仸闁逞屽墮缁绘垵危閹达附鍎嶉柛鏇炲缁€澶愭偡閺囨氨绐旈柍褜鍓欑换鎰板吹椤撶喓鈻旈悗锝庡枟濡椼劑鏌ｉ妸銉ヮ伃妞も晝绮妵鍕礂閸濄儳鎲块柡澶嗘櫈濞撳湱绱炲鈧?闂佺偨鍎查弻锟犲焵?闂?`bindContentCover` 濠碘槅鍨崜婵嬪焵椤戞寧顦风紒妤€顦遍幃鏉跨暆鐎ｎ剛顦?
 *      濠碘槅鍨崜婵嬪焵椤戣法顦︽い鏃€鐗楃粙澶岀磼濡亶锕€鈽夐幘宕囆ч柍褜鍓欑换鎴澪ｉ幋锔藉剭闁告洦浜為閬嶆倶閻愭彃浜扮紒杈ㄧ箞楠炲孩绻濋崶鑸电婵＄偑鍊濆褔骞忛悧鍫熶氦闁炬艾鍊荤粙鎴︽煛婢跺棌鍋撻崘鎻掍紟闂佺儵鏅滈悧鏃傜礊閸ャ劎顩查柛鈩冨姀閸?
 *   2. **"闂備礁澧介崕銈咁嚕?闂佹眹鍔岀€氼喖煤娴兼潙鍐€闁搞儺鍓涜ぐ顖炲箹鏉堝墽鐣辩紒鐑╁亾婵＄偑鍊楃划顖毼ｉ幖浣哥畳闁瑰搫绉风粈瀣節婵為敮鍋撳畷鍥ㄧ秳闂佹眹鍔岀€氼剟顢欓弽銊р枖閻犲洤妯婇崯鍥煕閿濆啫濡奸柣銈呭闇夐悗锝庝簻濮ｅ鏌℃径鍫濆姢婵?*闂佹寧绋掔喊宥団偓鍨礋瀹曠兘濡搁…鎴炶晧閻熸粏鍩囬崹纭呫亹婢舵劖鍎嶉柛鏇ㄥ灠娴滄繈鎮橀悙鎻掆偓椋庣箔閸屾稑顕辨慨妯哄暱濞堜即鏌?
 *      闂佹寧绋戦悧鎾诲磻閸涱垯娌柛宀€鍋熻ぐ顖炲箹鏉堝墽鐣辨慨妯稿姂瀵即顢涘┑鎰挅闂佸憡鎼╂禍鐐烘偘閵夆晛鐭楅柨婵嗙箳缁€鍡涙煥濞戞鐒锋い?`PlayerExpandState.reportHost`闂?
 *   3. **闂佸憡鐟崹鐢革綖鐎ｎ喗鍎楅柍杞版祰閸╁矂鏌ｉ妸銉ヮ仼婵炲弶鎹囧鍫曟缂佹梻鍠栧畷銉╁礋椤斿吋顔囬梺鍦帛鐢帡鍩€?*闂佹寧绋戞總鏃傜箔?*婵炴垶鎸搁鍫㈢博閻旂儤鍟哄ù锝囨嚀缁插綊鏌涢幘宕囆ラ柛鎺撶⊕閹?*闂佹寧绋戦悧鎰寲閻樿櫕濯撮柣妯挎珪閽傚绱掗崒婵愬殭闁活偄妫濋悰顕€寮撮悙鍏镐孩闁哄鐗忛、濠勬崲閺囥垹瀚夊璺猴工濞堛倝鏌?vp闂?
 *      闁荤姾娅ｉ崰鎾愁焽閸愵亞妫柟绋跨岸閸嬫捁顦堕柧鏂款儔閹啴宕熼鐐枔闂佽桨绀侀悺銊╊敊瀹€鍕闁靛ě鍕瘞闁圭厧鐡ㄥú鐔煎磿閹绢喗鐒鹃柤鎭掑劜绗戠紓浣哥焷濞咃絽鈻撻幋锔芥櫖濠㈣埖绋撻獮銏犆归敐鍛ゆ禍? 闂佸憡鐟崹鐢革綖鐎ｎ亶鍟呴柨鏃囨硶閻熸劙鎮?闂?(闁汇埄鍨伴崯顐︽儑椤掑嫬鐒鹃柟鐑樺灥鐠佹煡鎮?/2闂?
 *      婵炴垶鎸哥粔鐑藉礂濮椻偓閹ゎ槼濠碉繝浜跺顕€鎮╅崹顐ｇ彧闂?闂佸憡甯楃换鍌烇綖閹邦厽濯寸€广儱娉?闁?(1-p)"闂佹寧绋戦悧蹇曠磽婢舵劕缁╅柛娆嶅劥閸橆剟鐓崶褍鏆炴俊鎻掓憸閳ь剙婀遍幊鎾斥枍閹烘挾鈻旀い鎾跺仧婵″洭鏌ㄥ☉妯垮闁绘牕鐖奸弻宀冪疀濮ｇ顦靛畷鎴炲緞濮濆苯骞€濠电偛鐗嗛崥鈧紒杈╁閵囧嫮鎹勯崫鍕様闁诲繒鍋涚换鎰不閻戣姤鏅璺虹墐閸?
 *   4. **闂侀潻绠戝Λ婊堬綖濡ゅ嫮鐤€闁告稒鐣埀顒€绻橀幃?`clipShape` 闁?*闂佹寧绋掗懝鎹愩亹瑜斿畷?`.borderRadius + .clip(true)` 闂佸搫鍟抽鎰?
 *      闁诲骸婀遍幊鎾斥枍閹烘鍤婃い蹇撴喘閻撯晜绻涚仦绋垮⒉婵犫偓娓氣偓閹虫浠﹂悙顒傚讲闂?闂?闂侀潻绠戝Λ婊堬綖濡や胶鈻旂€广儱瀚粙濠囨煟椤剙濡奸柛鈺佺灱閳ь剚绋掗崝妯讳繆椤撱垺鍊?闂?闂佸憡鍔曢幊搴敊閹邦喕娌柛灞剧懅椤忚鲸绻涢幖顓炴灈闁搞値鍙冨鍫曞Ψ閵夛妇娈ら梺鍛婄懄钃遍柡宀€鍠栧畷绋款渻鐏忔牕浜?
 *
 * 閻庤鐡曠亸娆戝垝閳╁啰鈹嶆繝闈涚墛濞堝矂鏌ｉ妸銉ヮ仹缂佹ぜ鍨婚幉鏌ュ礌閿涘嫮顦╅梻渚囧枦濡嫬锕?common/musicbasic闂佹寧绋戦¨鈧紒?
 *   - `PlayerExpandState`闂佹寧绋戦悧鍛偖鏉堚晝鍗氭い鏍ㄦ皑濞堥亶姊婚崼娑樼伄婵炲牊鍨圭划锝呂旈埀顒冦亹濞戙垺鍎楅柍杞版祰閸?+ 闂佺儵鏅犻弲鑼礊?+ 闁诲骸婀遍幊鎾斥枍閹烘洏浜归柕蹇曞Т缂嶄線鏌涢幋鐘残＄紓宥呯Ч閺佸秵寰勫☉姘€?
 *   - `MINI_BAR_COVER_ID` / `PLAYER_BIG_COVER_ID` 婵炴垶鎸堕崐鎾绘煂濠婂懐纾奸柛鏇ㄤ簼椤?id闂?
 *   - 闁哄鏅炲〒鍦礊濮椻偓瀵爼鍨惧畷鍥唸闂傚倸鐗滃鈧紒妤€鐭傞獮姗€顢橀悢鍛婃緬婵＄偑鍊濆褔濡甸崶鈺€鐒婂〒姘ｅ亾婵為棿鍗冲畷銉╁礋椤斿吋顔?`onAreaChange` 婵炴垶鎸搁敃銉︽叏閵堝洨鐜绘俊銈傚亾鐟滅増鐩幆宀勫煛娴ｈ棄鐓傞梺姹囧妼鐎氼垶宕楀鈧畷婵嗏槈閺嶃倕浜?
 */

/** Player content builder mounted by product shells as a full-screen overlay above the shell Stack. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  // **婵炴垶鎸哥粔鍫曪綖椤愩倐鍋撻悷閭︽Ц闁告瑥绻樺畷?*闂佹寧绋掑畝鎼佸箺闂堟侗鐓ラ柍銉ュ级閸炲绱撴担鍦噧闁挎稒鎸炬禒锕傚磼濠婂懓鍩楅梺姹囧妼鐎氼厾鎷犻悙鍏告勃闁稿本鍑归崯鍥煕閿濆海鍘滅紒杈ㄧ箖閹棃寮撮姀鐘插Г闂佷紮绲鹃悷褍鈻嶈閹?PlaybackPage 闂佸憡鍔曢幊姗€宕曢幘顔肩?
  // navigationBarBottomVp 闂佺厧顨庢禍婊呮崲娓氣偓瀹?padding闂侀潧妫楅崐绋匡耿椤忓懏浜ゆ繛鍡樻尭濞咃繝鏌?expandSafeArea / ignoreLayoutSafeArea
  // 婵炴潙鍚嬮懝楣冨箯閻楀牆绶為柡宓秶澶勯柣搴℃贡閹虫挸鈻嶉幒妤€绀冮柤纰卞墰瀹曟劙鏌ㄥ☉妯肩伇闁哄棌鍋撻梺璋庡棙顥夌€殿喕绮欓幊鎾朵沪閽樺绉繝銏犵垻娴ｆ彃浜?
}

/** Panel-style cover content (wide split layout) for product shells that opt into the panel layout. */
@Builder
export function PlaybackPagePanelCoverContent() {
  Column() {
    PlaybackPage({ panelLayout: true })
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
}
