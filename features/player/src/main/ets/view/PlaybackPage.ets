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

// 鈿狅笍 `TextController` 鏄?ArkUI 鐨?*鍏ㄥ眬鐜绫诲瀷**锛堜笉闇€瑕?import锛宍MusicPlayInfoBlock` 鍚屾锛?
import { AppStorageV2, curves, uiObserver, UIUtils, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { hdsEffect } from '@kit.UIDesignKit';
import {
  AppStorageKeys,
  BreakpointConstants,
  // 鈽?2026-10-16锛堢収鎼棤鐣?`BarCollapse`锛夛細鎺у埗鏉℃嫋鍔ㄦ敹璧?灞曞紑鐨勬墜鍔跨姸鎬佹満
  BarAction,
  BarCollapse,
  CoverRadiusState,
  CoverTintState,
  getWindowInfoState,
  ImmersiveType,
  isWidthBreakpointLgOrXl,
  Logger,
  MorphDrive,
  MorphStage,
  MusicStoreService,
  PlayedSongRecord,
  // 鈽?2026-10-15锛堣鐩栧眰缁熶竴锛夛細绔偣閲忔祴鐨勫父閲忎笌宸ュ叿锛堝師鏉ュ彧鍦?`MusicPlayInfoBlock` 閲岀敤锛?
  PLAYER_BIG_COVER_ID,
  // 鈽?2026-10-17锛堢収鎼棤鐣?`PLAYER_ROOT_ID`锛夛細闈炴墜鍔垮叧闂鎷嶅揩鐓х殑閭ｄ釜鑺傜偣锛? 褰㈠彉瀹瑰櫒锛?
  PLAYER_ROOT_ID,
  // 鈽?2026-10-17锛堢収鎼棤鐣?ShrinkOverlay锛夛細闈炴墜鍔垮叧闂殑蹇収鏀剁缉娴眰
  MorphShrinkState,
  type MorphShrinkRect,
  PLAYER_META_TITLE_ID,
  PLAYER_META_SINGER_ID,
  MorphMetaEndpoint,
  areaLengthToVp,
  PlaybackFlowLightState,
  PlaybackShellConstants,
  PlayerExpandState,
  // 鈽?2026-10-16锛氭湰椤靛湪 `.onDisAppear()` 閲岃鍒?鎾斁椤佃矾鐢辫繕鍦ㄤ笉鍦ㄦ爤閲?锛堣 `playerRouteStillPushed`锛?
  RouterUrlConstants,
  ShowMiniLyricState,
  StyleConstants,
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
// 鈽?缃戞牸鑳屾櫙鐨勫彇鍥炬祦姘寸嚎锛堢収鎼棤鐣?`design/logic/MeshSource.ets`锛?
import { SRC_EDGE, enhanceColors, boxBlurRgba } from '../util/MeshSource';
// 鈿狅笍 鎵嬫満绐勫睆鐨?*椤?0 宸茬粡涓嶇敤瀹冧簡**锛堢収鎼棤鐣岋細灏侀潰/姝屽悕鏀规垚 `Swiper` 澶栫殑瑕嗙洊灞傦級锛?
//    浣?*瀹藉睆 / 闈㈡澘甯冨眬閭ｄ袱鏉″垎鏀粛鍦ㄧ敤**锛坄MusicPlayInfoBlock` 鍦?1817 / 2101 涓ゅ锛?
//    鈬?import 涓嶈兘鍒犮€傞偅涓ゆ潯鍒嗘敮鐨勭粺涓€鏄笅涓€鍧楋紙鏁村睆灏侀潰椤典笌瑕嗙洊灞傚悎骞讹級銆?
import { MusicPlayInfoBlock } from './MusicPlayInfoBlock';
import { TopAreaComponent } from './TopAreaComponent';

/** Clamps a numeric RGB channel to an integer byte in [0, 255]. */
function clampRgbByte(n: number): number {
  if (!Number.isFinite(n)) {
    return 0;
  }
  return Math.max(0, Math.min(255, Math.floor(n)));
}

/** 涓€娆″皝闈笅杞借В鍑虹殑涓ゅ紶浣嶅浘锛堣 `PlaybackPage.loadOnlineCoverPair`锛夈€?*/
class CoverDecodePair {
  /** 鍏ㄥ昂瀵革紝渚?`effectKit` 鍙栬壊銆?*/
  full: image.PixelMap | undefined = undefined;
  /** 64脳64銆丷GBA_8888銆佸彲缂栬緫 鈥斺€?缃戞牸鑳屾櫙鐨勬簮銆?*/
  mesh: image.PixelMap | undefined = undefined;
}

/** Minimal shape for probing {@link image.PixelMap.release}; {@link Resource} does not carry this. */
interface PixelMapReleaseProbe {
  release?: () => void;
}

/** 涓€鍦堟祦鍏夋椂闀匡紙ms锛夛細鎱竴鐐规墠鍍?鍛煎惛"鑰屼笉鏄棯銆?*/
const FLOW_LIGHT_DURATION_MS: number = 12000;
/** 娴佸厜灞傛暣浣撲笉閫忔槑搴︼細澶珮浼氱洊浣忓皝闈笌姝岃瘝銆?*/
const FLOW_LIGHT_OPACITY: number = 0.55;

/**
 * Full-screen playback page: layered background, breakpoint-specific layout, dismiss gestures,
 * and dynamic tint from album art.
 */
@ComponentV2
export struct PlaybackPage {
  /**
   * 澹冲眰鐨勮矾鐢辨爤锛坄Index.ets:237 @Provider('pageIndexInfos')` 鎻愪緵锛夈€?
   *
   * 鈽?2026-10-16 鏂板锛?*鍞竴鐢ㄩ€?*鏄鏈〉鍦?`.onDisAppear()` 閲屽垽
   * 銆屾挱鏀鹃〉璺敱鏄笉鏄繕鍦ㄦ爤閲屻€嶁€斺€?瑙?{@link playerRouteStillPushed}銆?
   * 涓轰粈涔堜笉浠庡弬鏁颁紶锛歚PlaybackPageCoverContent` / `PlaybackPageBuilder` 閮芥槸 `@Builder`锛?
   * 澶氫紶涓€涓?`NavPathStack` 瑕佹敼涓夊绛惧悕锛沗@Provider/@Consumer` 鏄湰宸ョ▼宸茬粡鍦ㄧ敤鐨?
   * 瀹樻柟鎴愬鏈哄埗锛坄Index.ets` 宸茬粡鏄?`@Provider`锛夛紝鎺ヤ竴娆″嵆鍙€?
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
  /** 鎾斁椤垫祦鍏夎儗鏅紑鍏筹紙璁剧疆椤癸紝AppStorageV2 鍏变韩锛屾敼璁剧疆绔嬪埢鐢熸晥锛夈€?*/
  @Local flowLightState: PlaybackFlowLightState =
    AppStorageV2.connect(PlaybackFlowLightState, AppStorageKeys.PLAYBACK_FLOW_LIGHT_STATE,
      () => new PlaybackFlowLightState())!;
  /** 娴佸厜鑳屾櫙鐨勪袱涓鑹诧紙鐢卞皝闈㈠姩鎬佸彇鑹插啓鍏ワ級銆?*/
  @Local coverTint: CoverTintState =
    AppStorageV2.connect(CoverTintState, AppStorageKeys.COVER_TINT_STATE, () => new CoverTintState())!;
  /** 娴佸厜鐫€鑹插櫒鎺у埗鍣細鎹㈡瓕鍚庢寜鏂板彇鍒扮殑灏侀潰棰滆壊閲嶈 uniform銆?*/
  private flowLightController: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  /** 宸插簲鐢ㄥ埌鐫€鑹插櫒鐨勫彇鑹茬増鏈彿锛岄伩鍏嶅悓涓€浠介鑹查噸澶嶄笅鍙戝竷銆?*/
  private appliedTintVersion: number = -1;
  /**
   * Background cover source (Resource).
   *
   * 鈿狅笍 2026-10-15锛氳儗鏅敼瀹炴椂妯＄硦鍚庯紝鏈瓧娈?*鎭掍负 `Resource`**锛? `song.label`锛屽師濮嬪皝闈級锛?
   *   涓嶅啀琚祴鎴?`effectKit` 棰勬覆鏌撳嚭鏉ョ殑妯＄硦 PixelMap锛堥偅鏉¤矾宸插仠鐢紝瑙?
   *   {@link getImageColorAsync}锛夈€傜被鍨嬩繚鐣?`PixelMap | Resource` 鏄负浜嗗吋瀹?
   *   {@link isPixelMapCover} / {@link originalCoverSource} 閭ｆ潯鍏滃簳鍒嗘敮銆?
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
  /** 褰撳墠 Swiper 椤碉紙0 = 灏侀潰椤碉紝1 = 姝岃瘝椤碉級銆?*/
  @Local playbackSwiperIndex: number = 0;
  /** 姝屾洸鑿滃崟锛堥偅涓€妯鐨勩€屾洿澶氥€嶏級鏄惁灞曞紑锛泂heet 鐢?`ControlAreaComponent` 鐢汇€?*/
  @Local playMenuOpen: boolean = false;
  /** 褰撳墠鏇叉槸鍚﹀凡鏀惰棌锛堥偅涓€妯鍙充晶鐨勫績褰級銆備笌 `MusicPlayInfoBlock` 鍚屼竴濂楄鍐欍€?*/
  @Local isCurrentFavorite: boolean = false;
  @Local favStore: MusicStoreService = MusicStoreService.getInstance();

  /**
   * 缃戞牸鑳屾櫙鐨勬簮浣嶅浘锛?4脳64銆佸凡杩?`enhanceColors` + `boxBlurRgba(9,3)`锛夈€?
   *
   * 鈽?2026-10-15锛堢収鎼棤鐣?`MeshCoverBg`锛夛細鏈〉鎸佹湁瀹冪殑鐢熷懡鍛ㄦ湡 鈥斺€?
   *   鎹㈡瓕鏃?`publishMeshSource` 閲婃斁涓婁竴寮狅紱涓虹┖鏃惰儗鏅眰閫€鍥?瀹炴椂妯＄硦閭ｅ紶鍥?銆?
   */
  @Local meshSrc: image.PixelMap | undefined = undefined;
  /** 鎹㈠浘浠ょ墝锛坄MeshCoverBg` 闈犲畠瑙﹀彂閲嶆柊涓婁紶锛岃閭ｉ噷鐨?`@Monitor`锛夈€?*/  @Local meshSrcVersion: number = 0;

  /** 鏇茬洰鎴栨敹钘忕増鏈彉鍖栨椂鍒锋柊蹇冨舰銆?*/
  @Monitor('state.selectIndex', 'favStore.favoriteVersion')
  onFavoriteChanged(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      this.isCurrentFavorite = false;
      return;
    }
    this.isCurrentFavorite = this.favStore.isFavorite(song.source, song.songId);
  }

  /** 鍒囨崲鏀惰棌锛堢収鎶?`MusicPlayInfoBlock.toggleFavorite()`锛屼繚璇佷袱澶勮涓轰竴鑷达級銆?*/
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

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 瑕嗙洊灞傦紙鍙樻崲寮忥級鐨勫嚑浣?+ 绔偣涓婃姤锛堝鏍囨棤鐣?`floatingCover.onAreaChange 鈫?publishMorphTargets`锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();

  // 鈿狅笍 杩欓噷鍘熸潵鏈変竴鏁寸皣銆屽彉鎹㈠紡瑕嗙洊灞傘€嶇殑鍙栧€煎櫒 鈥斺€?**2026-10-17 宸插垹闄?*锛?
  //      `coverLayerBase()` / `coverLayerScale()` / `coverLayerTx()` / `coverLayerTy()` /
  //      `coverLayerRadius()`锛? 鍩哄噯鐭╁舰 / 缂╂斁 / 浣嶇Щ / **鍗婂緞 梅 scale**锛夈€?
  //   鍒犻櫎鐞嗙敱锛堝垹鍓嶉€愪釜 grep 鍏ㄤ粨纭闆舵秷璐硅€咃級锛?
  //   路 瀹冧滑鏄?*宸茶鎾ゅ洖鐨勯偅涓€鐗?*锛?鍩哄噯 + `.scale()` + `.translate()`"锛夌殑浜х墿锛?
  //     鐜拌璧?**`coverLocalRect()`**锛岃€屽畠灏辨槸 `lyricFloatRect()` 鐨?*鐩撮€?*
  //     锛堝昂瀵?浣嶇疆/鍦嗚涓€寰嬬洿鎺ュ啓杩?`.width/.position/.borderRadius`锛?*鏈妭鐐规病鏈夎嚜宸辩殑 `.scale()`**锛夛紱
  //   路 鍞竴杩樺湪璇诲畠浠殑鏄笅闈㈤偅鏉?`RzdCoverRect` 璇婃柇鏃ュ織閲岀殑 `base=/tx=/ty=` 涓夋 鈥斺€?
  //     鑰岄偅涓夋閲忕殑姝ｆ槸"鍙湁宸茶鎾ゅ洖閭ｄ竴鐗堟墠鏈夌殑閲? 鈬?鐣欑潃鍙細璇鍚庢潵浜猴紙宸蹭竴骞跺垹鎺夛級锛?
  //   路 鈽?灏ゅ叾 `coverLayerRadius()` 鐨勬敞閲婂啓鐫€銆屽渾瑙掍綔鐢ㄥ湪**鏈缉鏀?*鐨勮妭鐐逛笂 鈬?蹇呴』闄や互 scale銆嶏紝
  //     涓庣幇琛岃璁?*姝ｅソ鐩稿弽**锛氱幇鍦ㄨ繖涓妭鐐?*娌℃湁** `.scale()` 鈬?鐓у畠鍘?闄や互 scale"
  //     浼氭妸灏忓皝闈㈤偅绔殑鍦嗚鏀惧ぇ鍒?~6.7 鍊嶏紙鐪嬬潃鍍忎釜灏忓渾鐗囷級銆?*杩欐槸蹇呴』鍒犳帀瀹冪殑鐩存帴鍘熷洜銆?*

  /**
   * 瑕嗙洊灞備笂鎶ャ€屾挱鏀鹃〉灏侀潰绔偣銆嶃€?
   *
   * 鈽?瀵规爣鏃犵晫 `floatingCover.onAreaChange 鈫?publishMorphTargets()`锛?*瑕嗙洊灞傝嚜宸卞氨鏄噺娴嬫簮**銆?
   * 鈿狅笍 **鍙湪灏侀潰椤甸潤姝紙`t 鈮?0`锛夋椂涓婃姤**锛氬舰鍙橀€斾腑杩欎竴灞傜殑浣嶇疆鏄褰㈠彉椹卞姩鐨勶紝
   *    鎶婄Щ鍔ㄤ腑鐨勭煩褰㈠啓鍥炵鐐逛細褰㈡垚姝ｅ弽棣堬紙绔偣瓒婅窇瓒婂亸锛夈€?
   */
  private reportPlayerCoverFromOverlay(area: Area): void {
    if (this.lyricMorphT > 0.001) {
      return;
    }
    // 鈽呪槄鈽?2026-10-16锛?*褰㈠彉涓竴寰嬩笉涓婃姤**锛堣 `coverAnchorMeasurable()` 鐨勬敞閲婏級銆?
    //   鐐瑰紑/鏀惰捣鏃惰鐩栧眰浼氳窡鐫€瀹瑰櫒涓€璧风缉锛岄偅鏃堕噺鍒扮殑鐭╁舰鏄?杩蜂綘鏉″皝闈㈤偅涔堝ぇ"锛?
    //   鍐欒繘 `endCover*` 浼氭妸缁灏侀潰鐨勭粓鐐瑰啓鍧?鈬?閭ｄ竴妫掍笉鐢绘垨椋炲埌閿欑殑灏忕煩褰€?
    if (!this.coverAnchorMeasurable()) {
      return;
    }
    const gx: number = areaLengthToVp(area.globalPosition.x);
    const gy: number = areaLengthToVp(area.globalPosition.y);
    const gs: number = areaLengthToVp(area.width);
    // 鈽呪槄 2026-10-15 璇婃柇閿氱偣锛坄hdc shell hilog -x | Select-String 'RzdCoverRect'`锛夆€斺€?
    //   涓€娆℃妸**涓変釜鐭╁舰**鎵撳嚭鏉ワ紝鐢ㄦ潵鍒ゅ畾"灏侀潰钀界偣涓嶅"鍒板簳灞炰簬鍝竴绉嶏紙**涓ょ淇硶瀹屽叏涓嶅悓**锛夛細
    //     路 `measured` = `onAreaChange` 鐨?`globalPosition`銆傗殸锔?瀹冩槸**甯冨眬鍑犱綍**锛?
    //       **涓嶅惈鏈妭鐐硅嚜宸辩殑 `.scale()` / `.translate()`**锛堟湰浠撴敞閲婂澶勫己璋冭繃杩欎竴鐐癸級锛?
    //     路 `geometry` = 绾嚑浣曠鐐癸紙`playerCoverGeomRect()`锛?*涓嶆煡浠讳綍鑺傜偣**锛屽鏍囨棤鐣?
    //       `CoverMorph` 鍏ㄧ▼涓嶉噺娴嬶級锛?
    //     路 `base/tx/ty` = 瑕嗙洊灞傜殑鍙傝€冪郴涓庝綅绉?鈥斺€?**娓叉煋浣?= base + translate**銆?
    //   **鍒ゆ嵁**锛?
    //     鈶?鑻?`dxy` 鈮?涓婁笅瀹夊叏鍖洪珮搴︼紙鍑犲崄 vp銆佷笖涓婁笅涓や釜鏂瑰悜锛?鈬?**鍐呭鐩掑亸绉?*闂
    //        鈬?灏辨槸 `PlaybackPageRoute` 閭ｆ潯椤垫牴鎵╁睍锛坄expandSafeArea` + `ignoreLayoutSafeArea`锛夊湪绠★紱
    //     鈶?鑻?`dxy` 鏄?*鍒殑甯告暟 / 涓?`tx,ty` 鍚屽€?* 鈬?**閲忔祴鍙ｅ緞**闂
    //        鈬?璇存槑璇ユ妸**娓叉煋浣嶏紙base + translate锛?*鑰屼笉鏄竷灞€浣嶆姤涓婂幓锛堝惁鍒?绔偣鐢卞皝闈㈢畻銆?
    //          灏侀潰鍙堟寜绔偣钀戒綅"浼氬舰鎴?*姝荤幆**锛岃宸細琚ǔ瀹氬湴閿佷綇 鈥斺€?杩欐鏄湰鏂规硶娉ㄩ噴閲?
    //          鏃╁氨鍐欒繃鐨?鑷繁閲忚嚜宸?锛夈€?
    //   鈿狅笍 杩欐潯鏃ュ織**鍙涓嶅啓**锛屼笉褰卞搷浠讳綍琛屼负锛坄reportBig` 鐨勫叆鍙備竴瀛楁湭鏀癸級銆?
    const geom: LyricMorphRect = this.expandState.playerCoverGeomRect();
    // 鈽呪槄鈽?2026-10-16锛?*灏侀潰鍩哄噯鍑犱綍鑷瘉**锛堟帓鏌ュ叧閿瓧 `RzdCoverGeom`锛?
    //   涓€鏉″氨鑳藉垽"灏侀潰浣嶇疆瀵逛笉瀵?锛屼笉蹇呭啀闈犳埅鍥鹃噺鍍忕礌锛?
    //     鏈熸湜锛堟墜鏈?360脳780 杩欐。锛夛細`edge=328`銆乣y鈮?36`锛? 椤惰竟锛夈€乣center=300`銆?
    //     路 `edge` 鏄庢樉澶т簬 328锛堜緥濡?393/369锛夆噿 瀹介绠楀張鐢ㄦ垚"鏁寸獥瀹?浜嗭紱
    //     路 `y` 鎺ヨ繎 `(winH鈭抏dge)/2`锛堚増 298锛夆噿 鍙堝彉鍥?鍦ㄧ獥鍙ｉ噷灞呬腑"锛堚啇 鐢ㄦ埛鎶ョ殑"浣庝簡濂藉"锛夈€?
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverGeom edge=${geom.size.toFixed(1)} x=${geom.x.toFixed(1)} y=${geom.y.toFixed(1)} ` +
      `centerY=${(geom.y + geom.size / 2).toFixed(1)} radius=${geom.radius.toFixed(1)} ` +
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `padTop=${this.expandState.topInsetVp().toFixed(1)} padBottom=${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      // 鈽?鍒ゆ嵁锛歚centerY` 鏄湰娆?*鍩哄噯**鐨勪腑蹇冦€傛湡鏈涳紙鎵嬫満锛? padTop + 244 鈮?300銆?
      //   鑻ュ畠鎺ヨ繎 `win/2`锛堚増462锛夆噿 鍙堝洖鍒?绐楀彛灞呬腑"锛堢敤鎴锋姤鐨?浣?锛夈€?
      `expectCenter=${(this.expandState.topInsetVp() + 244).toFixed(1)} ` +
      `(windowCentered-y=${((this.expandState.windowHeightVp - geom.size) / 2).toFixed(1)})`);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverRect measured=(${gx.toFixed(1)},${gy.toFixed(1)},${gs.toFixed(1)}) ` +
      `geometry=(${geom.x.toFixed(1)},${geom.y.toFixed(1)},${geom.size.toFixed(1)}) ` +
      `dxy=(${(gx - geom.x).toFixed(1)},${(gy - geom.y).toFixed(1)}) ` +
      // 鈿狅笍 2026-10-17锛氬師鏉ヨ繖閲岃繕鏈?`base=/tx=/ty=` 涓夋锛岄殢"鍙樻崲寮忚鐩栧眰"閭ｄ竴绨囦竴璧峰垹闄や簡
      //   锛堝畠浠噺鐨勫彧鏈夊凡琚挙鍥為偅涓€鐗堟墠鏈夌殑閲忥紝瑙佹湰鏂囦欢 :247 闄勮繎閭ｆ璁拌处锛夈€?
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
   * 鈽呪槄鈽?2026-10-16 鏂板锛?*"缁堢偣閿氱偣鍙兘鍦ㄥ叏灏哄閭ｄ竴甯т笂鎶?** 鈥斺€?渚?
   * {@link PlaybackPage.reportPlayerCoverFromOverlay} 鐢紙閭ｄ袱澶?`reportBig` 鐨勫墠缃垽鎹級銆?
   *
   * ## 涓轰粈涔堝繀椤昏杩欓亾闂紙鐐瑰嚮鎵撳紑娌℃湁灏侀潰鍔ㄧ敾鐨勭湡鍑犱綍椋庨櫓锛?
   *
   * 瑕嗙洊灞傜殑 `.id(PLAYER_BIG_COVER_ID)` + `onAreaChange` 鏃㈡槸"鎾斁椤靛皝闈?鐨?*鍞竴閲忔祴婧?*锛?
   * 鍙堣鎸傚湪**褰㈠彉瀹瑰櫒鍐呴儴**銆備簬鏄細
   * ```
   *   瀹瑰櫒宸茬粡琚帇鍒拌捣鐐癸紙scale 鈮?0.08锛変箣鍚庯紝浠讳綍涓€娆?onAreaChange 鎶ヤ笂鏉ョ殑
   *   globalPosition/width 閮芥槸銆愯糠浣犳潯灏侀潰閭ｄ箞灏忋€戠殑鐭╁舰
   *   鈬?瀹冧細鎶?`endCoverSize/endCoverX/endCoverY` 鍐欐垚杩蜂綘鏉＄殑灏哄
   *   鈬?缁灏侀潰锛堟诞灞傚厠闅嗭級鐨?*缁堢偣**琚啓鍧忥細閭ｄ竴妫掕涔堜笉鐢汇€佽涔堥鍒颁竴涓敊璇殑灏忕煩褰?
   * ```
   * 鐢ㄦ埛瀹炴祴銆?*鐐瑰嚮鎵撳紑 / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖閮芥病鏈夊皝闈㈠姩鐢?*銆嶄笌杩欐潯瀹屽叏鍚诲悎 鈥斺€?
   * 鐐瑰嚮璺緞涓婅鐩栧眰鏄?*闅忛〉闈竴璧锋寕杞?*鐨勶紝瀹冪殑绗竴娆?`onAreaChange` 寰堝彲鑳藉氨钀藉湪
   * "瀹瑰櫒宸茶鍘嬪埌璧风偣"涔嬪悗銆?
   *
   * 鈬?鍒ゆ嵁锛?*瀹瑰櫒鏄亽绛夊彉鎹紙`morphScale 鈮?1`锛変笖娌℃湁瑁佸壀**鏃舵墠鍏佽涓婃姤銆?
   *   褰㈠彉涓紙`morphClipping()` 涓虹湡锛変竴寰嬩笉涓婃姤 鈥斺€?閭ｆ椂閲忓埌鐨勯兘涓嶆槸"闈欐鎬佺湡瀹炵煩褰?銆?
   * 鈿狅笍 闈欐鎬佺殑 `morphScale` 鎭掍负 1 鈬?杩欓亾闂ㄥ湪闈欐鎬?*鎭掔湡**锛屼笉褰卞搷鏃㈡湁琛屼负銆?
   * 鈿狅笍 涓庢棦鏈夌殑 `lyricMorphT > 0.001` 閭ｉ亾闂ㄦ槸**涓ゆ潯鐙珛鏉′欢**锛堥偅鏉＄"姝岃瘝椤甸琛屼腑"锛夛紝
   *   涓ゆ潯閮藉繀椤讳繚鐣欍€?
   */
  private coverAnchorMeasurable(): boolean {
    if (this.expandState.morphClipping()) {
      return false;
    }
    return this.expandState.morphScale >= 0.999;
  }

  /**
   * 涓婃姤姝屽悕/姝屾墜鐨?*鎺掔増绔偣**锛堝舰鍙樻妸鏂囧瓧鐢卞ぇ鍙樺皬/鐢卞皬鍙樺ぇ鏃舵寜鍚屼竴濂楀瓧浣撳弬鏁版彃鍊硷級銆?
   *
   * 鈽?杩欎袱涓笂鎶ュ師鏉ュ湪 `MusicPlayInfoBlock` 閲屻€傚畠浠庣獎灞忛〉 0 绉婚櫎鍚庡繀椤绘惉鍒拌繖閲?鈥斺€?
   *   鍚﹀垯绔偣閲忎笉鍒?鈬?**灏侀潰缂╂垚 0锛堢湅涓嶈锛? 灞曞紑鍔ㄧ敾娌℃湁绔偣**锛?026-10-15 閭ｆ宕╂簝鐨勬牴鍥狅級銆?
   * 瀛椾綋鍙傛暟涓庨偅涓€琛?*瀹為檯娓叉煋鐨勫€?*淇濇寔涓€鑷达紙`LYRIC_META_TITLE_FP` / `LYRIC_META_ARTIST_FP`锛夈€?
   */
  private publishMetaEndpoint(singer: boolean): void {
    const song = this.state.getCurrentSongItem();
    const endpoint: MorphMetaEndpoint = new MorphMetaEndpoint();
    endpoint.id = singer ? PLAYER_META_SINGER_ID : PLAYER_META_TITLE_ID;
    endpoint.controller = singer ? this.singerController : this.titleController;
    const raw: string | Resource = singer ? (song?.singer ?? '') : (song?.title ?? '');
    endpoint.content = typeof raw === 'string' ? raw
      : this.getUIContext().getHostContext()!.resourceManager.getStringSync(raw.id);
    // 鈽?2026-10-15锛氫笂鎶?*褰撳墠杩欎竴甯?*鐨勫瓧鍙凤紙涓ょ鎻掑€肩殑缁撴灉锛夛紝鑰屼笉鏄浐瀹氱殑姝岃瘝椤靛€?鈥斺€?
    //   鍚﹀垯褰㈠彉绔偣閲忓埌鐨勬槸涓€涓?鍙湪姝岃瘝椤垫墠鎴愮珛"鐨勫瓧鍙凤紝灏侀潰椤甸偅涓€绔細鍋忓皬銆?
    endpoint.fontFp = singer ? this.metaArtistFp() : this.metaTitleFp();
    endpoint.family = singer ? PlayerConstants.FONT_FAMILY_BLACK : PlayerConstants.FONT_FAMILY_BOLD;
    endpoint.weight = singer ? 400 : 700;
    endpoint.color = singer ? $r('app.color.play_singer_color') : $r('app.color.play_text_color');
    endpoint.opacity = singer ? 1 : 0.86;
    endpoint.maxLines = 1;
    this.expandState.registerMorphMeta(false, singer, endpoint);
  }

  /**
   * 鈽呪槄鈽?2026-10-16 鏂板锛氬皝闈㈣惤浣嶉殢 `lyricMorphT` 鍙樺寲鏃舵墦涓€娆″璐︽棩蹇椼€?
   *
   * 鈿狅笍 `lyricMorphT` 鏄?*閫愬抚**鏀圭殑锛堣ˉ闂撮噷鍐欙級锛屾墍浠ヨ繖閲?*蹇呴』**鏈夎妭娴?鈥斺€?
   *   鑺傛祦涓庡幓閲嶉兘鍦?{@link PlaybackPage.logCoverLocal} 閲岋紙100ms + 绛惧悕姣斿锛夈€?
   * 鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdCoverLocal'`
   */
  @Monitor('lyricMorphT')
  onLyricMorphTChanged(): void {
    this.logCoverLocal();
  }

  /** 鏇茬洰鍙樺寲鏃堕噸鎶ヤ袱涓枃瀛楃鐐癸紙鍘熸潵鍦?`MusicPlayInfoBlock` 鐨?`@Monitor` 閲岋級銆?*/
  @Monitor('state.selectIndex')
  onMetaEndpointChanged(): void {
    this.publishMetaEndpoint(false);
    this.publishMetaEndpoint(true);
  }

  /**
   * @returns 姝岃瘝椤甸偅涓€妯鐨?*宸﹀唴杈硅窛**锛坴p锛夈€?
   *
   * 鎸?`lyricMorphT` 鍦ㄤ袱涓鐐逛箣闂存彃鍊硷細
   * 路 `t = 0`锛堝皝闈㈤〉锛? 椤甸潰杈硅窛锛屾瓕鍚嶅眳涓尯姝ｄ笅鏂癸紱
   * 路 `t = 1`锛堟瓕璇嶉〉锛? **灏忓皝闈㈠彸缂?+ 12**锛屾枃瀛楄寮€灏忓皝闈€?
   * 鏃犵晫闈?`floatingCover` 涓?`metaRow` 涓ゅ眰鐨勬í鍚戦敊浣嶈揪鍒板悓涓€鏁堟灉锛岃繖閲岀敤鍐呰竟璺濊〃杈俱€?
   * 灏戜竴灞傘€佷篃澶╃劧闅忚繘搴﹁繛缁紙涓嶄細鍦ㄤ氦妫掑抚璺充竴涓嬶級銆?
   */
  private lyricMetaLeftInset(): number {
    const side: number = PlaybackPage.LYRIC_META_SIDE_VP;
    const t: number = this.lyricMorphT;
    const coverRight: number = this.lyricFloatRect().x + this.lyricFloatRect().size;
    return side + (coverRight + PlaybackPage.LYRIC_META_GAP_VP - side) * t;
  }

  /**
   * @returns 鍏冧俊鎭鍦?*鍩哄噯鐩?*閲岀殑浣嶇Щ锛坴p锛夆€斺€?瀵规爣鏃犵晫 `floatingMeta` 鍐呭眰閭ｆ潯
   *   `.offset({ y: metaOffsetYAt(swiperProgress) })`锛坄wujie.pa:195907-196008`锛夈€?
   *
   * ## 涓轰粈涔堣鍑忔帀"灞呬腑浣嶇疆"
   * 鏃犵晫閭ｄ袱灞傛槸**鍒嗗伐**鐨勶細
   * ```
   *   澶栧眰 Column().width('100%').height(overlayBaseH()).justifyContent(FlexAlign.Center)
   *        鈬?鎶婂瓙鍐呭鍏堟憜鍒板熀鍑嗙洅鐨?*绔栫洿涓績**
   *   鍐呭眰 Column().offset({ y: metaOffsetYAt(t) })
   *        鈬?鍙〃杈?鐩稿閭ｄ釜灞呬腑浣嶇疆鐨勫亸绉?
   * ```
   * 鎴戜滑杩欐潯 `.offset()` 閲屾斁鐨勫繀椤绘槸**鍚屼竴涓噺绾?* 鈬?
   * ```
   *   metaOffsetY() = metaTopGeomY(t, rowH) 鈭?(鍩哄噯鐩掗珮 鈭?rowH) / 2
   *                                         鈹斺攢鈹€鈹€鈹€ 灞呬腑鍚庤椤惰竟鐩稿鐩掗《鐨勪綅缃?鈹€鈹€鈹€鈹€鈹?
   * ```
   * 鈬?琛岄《杈规渶缁堣惤鍦?`metaTopGeomY(t, rowH)`锛屼笌涓婁竴鐗堥偅鏉?
   *   `.position({ y: metaTopGeomY(...) })` **閫愬儚绱犵瓑浠?*锛堟崲鐨勬槸缁撴瀯涓庡彛寰勶紝涓嶆槸鏁板€硷級銆?
   *
   * 鈿狅笍 **涓嶈鍐嶄箻 `1/morphScale`**锛歚metaTopGeomY` 鐨勪袱涓鐐归兘鏄?瀹瑰櫒鎭掔瓑鏃?鐨勫嚑浣曪紝
   *   宸茬粡鏄〉鍐?绐楀彛鍚屼竴濂楀潗鏍囷紱涔樹簡灏变細閲嶇幇鐢ㄦ埛瀹炴祴鐨勩€?*鍏堥閫熼鍒板皝闈紝鐒跺悗鍐嶄笅鏉?*銆嶃€?
   * 鈿狅笍 鍩哄噯鐩掗珮鐢?`estBoxHVp()`锛? 鍙敤楂?鈭?鎺у埗鍖猴紝涓庢棤鐣?`overlayBaseH()` 鍚屼箟锛夈€?
   *   瀹冭繕娌￠噺鍒版椂涓?0 鈥斺€?涓嬮潰鐢?`(baseH 鈭?rowH)/2` 鐩存帴绠楋紝0 涔熻嚜娲斤紙涓嶄細 NaN锛夈€?
   */
  private metaOffsetY(): number {
    const rowH: number = PlaybackPage.LYRIC_META_ROW_H_VP;
    const baseH: number = this.expandState.estBoxHVp();
    const centeredTop: number = (baseH - rowH) / 2;
    let absTop: number = this.expandState.metaTopGeomY(this.lyricMorphT, rowH);
    // ★★★★ 2026-10-17（**压住控制区的钳制** —— 用户实测「展开时标题歌手那行会和进度条重叠，
    //   无界是正常的」）
    //
    // 这一行是**绝对定位的浮层**（`LyricFloatLayer`），无界那一条是在页面流里、天然排不到
    // 控制区里去 ⇒ 我们必须自己保证"别压进控制区"。
    // 控制区顶边 = `topInset + estBoxH(= 可用高 − 控制区总高) + swiperGap`；
    // 钳制上限 = 控制区顶边 − 行高（宁可贴近封面底边，也不许盖住进度条）。
    // ⚠️ 只在**真的会越界**时生效（`t = 1` 歌词页那一端远在上方，不受影响）；
    //   静止态封面页若本来就够高（封面小/窗口高）也不受影响 ⇒ 不改变既有版面。
    // 排查关键字：`hdc shell hilog -x | Select-String 'RzdMetaChrome'`
    const chromeTopY: number = this.expandState.topInsetVp() +
      this.expandState.estBoxHVp() + this.expandState.swiperGapVp();
    const maxTop: number = chromeTopY - rowH;
    if (absTop > maxTop) {
      absTop = maxTop;
    }
    return absTop - centeredTop;
  }
  /** False after teardown to ignore async image callbacks. */
  private isAlive: boolean = true;
  /** Bumps on each {@link getImageColorAsync} run so stale async work skips UI updates and releases pixels. */
  private imageColorJobSeq: number = 0;
  /** Cached UIAbility context for resource and color extraction. */
  private context: common.UIAbilityContext | undefined = undefined;
  /** Logger tag for this page. */
  private static readonly logTag: string = 'PlaybackPage';
  /** 鏀惰捣鎬佸唴瀹瑰眰鍗犵獥鍙ｉ珮搴︾殑鐧惧垎姣旓細璐村簳涓€鏉★紝澶ц嚧绛変簬杩蜂綘鏉￠偅涓€鏉°€?*/
  private static readonly COLLAPSED_HEIGHT_PERCENT: number = 9;
  /** 灞曞紑鍔ㄧ敾鐨勮捣鐐硅繘搴︼紙= 瀹屽叏鏀惰捣锛夈€?*/
  private static readonly EXPAND_START_PROGRESS: number = 100;
  /** 灞曞紑/鏀惰捣鍔ㄧ敾鏃堕暱锛坢s锛夛紝涓庡弬鑰冨伐绋?`OPEN_PLAYER_UI_ANIMATION_MS` 涓€鑷淬€?*/
  private static readonly EXPAND_DURATION_MS: number = 380;
  /**
   * 瀹瑰櫒褰㈠彉灞曞紑鐨勬椂闀匡紙ms锛夈€?
   *
   * 鏃犵晫 Tokens 鐨勪富杞満妗ｄ綅鏄?300ms / 420ms锛涜繖閲屽彇 420ms 閭ｆ。鐨勮鎰燂紙鏁撮〉鍦ㄧ缉鏀撅紝
   * 姣斿眬閮ㄥ厓绱犳崲浣嶉渶瑕佹洿澶氭椂闂达級锛屾洸绾跨敤瀹冪殑 `cubic-bezier(0.23, 1.0, 0.32, 1.0)`锛堝揩鍑虹紦鍏ワ級銆?
   */
  private static readonly MORPH_OPEN_DURATION_MS: number = 350;
  /**
   * 瀹瑰櫒褰㈠彉鏀惰捣锛堝弽鍚戯級鐨勬椂闀匡紙ms锛夛細姣斿睍寮€鐣ュ揩锛屾敹璧锋潵瑕佸共鑴嗐€?
   */
  /**
   * 鍏抽棴锛堝弽鍚戝舰鍙橈級鐨?*鍩虹鏃堕暱**涓?*鏃堕暱涓嬮檺姣斾緥**锛堝鏍囨棤鐣?`MainPage` 鐨勪袱涓父閲忥級銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋紝淇€屽叧闂挱鏀惧櫒鍑犱箮娌″姩鐢汇€嶏級锛?
   *   `reverseMs = round(REVERSE_MS 脳 max(REVERSE_MIN_RATIO, morphT))`
   *   锛坄_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂0 閫熸煡 L29 / 搂鍏?甯搁噺琛?L620-625锛夈€?
   *   鈬?婊″睍寮€鏃?**460ms**锛涘彧鎷夊紑涓€鐐圭偣锛坄morphT < 0.4`锛夋椂鎸変笅闄?**460脳0.4 = 184ms**銆?
   *
   * 鈿狅笍 琚浛鎹㈡帀鐨勬棫甯搁噺 `MORPH_CLOSE_DURATION_MS = 350` 鏈変袱澶勯敊锛堥兘涓嶆槸"鏁板€煎井璋?锛夛細
   *   鈶?**鏃堕暱鍋忕煭**锛?50 vs 鏃犵晫婊″睍寮€ 460锛屽皯浜?24% 鐨勮绋嬫椂闂达紱
   *   鈶?鏇磋鍛界殑鏄?*缂撳姩鏁存潯鎶勯敊**锛氭棫浠ｇ爜鐢?`cubicBezier(0.23, 1.0, 0.32, 1.0)`
   *      锛? `EASE_OUT_STR`锛岄偅鏄?*鎵撳紑鎻愪氦**鐢ㄧ殑鏇茬嚎锛夛紝瀹?*鍓?15% 鏃堕棿灏辫蛋瀹岀害 70% 琛岀▼**
   *      鈬?350ms 閲岀害 50ms 灏辩缉瀹屻€佸墿涓?300ms 鍑犱箮闈欐 = 鐢ㄦ埛璇寸殑"**鍑犱箮娌″姩鐢?*"銆?
   *   鏃犵晫"鍏抽棴鎻愪氦"鐢ㄧ殑鏄?**`REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`**锛堟參鍚姩锛夈€?
   *   瀹屾暣瀵圭収涓?鍒悶娣蜂笁澶勭紦鍔?鐨勮鏄庡啓鍦?`closeFullScreenPlayback()` 閲屻€?
   */
  private static readonly REVERSE_MS: number = 460;

  /**
   * `page 0` 灏忔瓕璇嶇浉瀵归〉搴曠殑**涓嬪帇閲?*锛坴p锛夈€?
   *
   * 鈽呪槄 2026-10-15锛堜慨鐢ㄦ埛瀹炴祴銆屾挱鏀剧晫闈㈣繖閲岄敊浣嶃€嶏級锛氳 `MiniLyricLinesComponent` 閭ｅ璋冪敤鐐圭殑娉ㄩ噴 鈥斺€?
   *   灏忔瓕璇嶅師鏉ヨ创椤靛簳锛屾濂借惤鍦?`Swiper` 涔嬪閭ｆ潯**姝屽悕/姝屾墜瑕嗙洊灞?*鐨勯珮搴﹀甫閲岋紙鈮?60~690vp锛夈€?
   *   鍙栧€?= `PlayerExpandState` 閲屾瓕鍚嶅潡鐨勯珮搴﹀彛寰勶紙`LYRIC_META_BLOCK_H_VP = 44`锛夛紝
   *   鎺ㄥ紑"涓よ鏂囧瓧"閭ｄ箞澶氬嵆鍙紱闈欐鎬佸畠鍙槸涓€涓浐瀹氫綅绉伙紝**涓嶅弬涓庝换浣曡ˉ闂?*銆?
   */
  private static readonly MINI_LYRIC_SINK_VP: number = 44;

  /** 灏忔瓕璇嶅鍣ㄧ殑缁勪欢 id锛堝彧缁?{@link PlaybackPage.logLayoutBoxes} 閲忔祴鐢紝涓嶅弬涓庝换浣曢€昏緫锛夈€?*/
  private static readonly MINI_LYRIC_BOX_ID: string = 'rzd_page0_mini_lyric_box';

  /** 缃戞牸鑳屾櫙灞傜殑缁勪欢 id锛堝彧缁?{@link PlaybackPage.logBgLayer} 閲忔祴鐢級銆?*/
  private static readonly MESH_BG_ID: string = 'rzd_mesh_bg_layer';

  /**
   * 鈽呪槄鈽?2026-10-16锛?*GLM5.3 浼氳瘖鍙戠幇锛氭垜涓婁竴杞偅閬撻棬鏄?姝婚棬"**锛?
   *
   * ## 浜嬫晠缁忚繃锛堝瀹炶锛屽埆鍐嶇姱锛?
   * 鎴戠粰鍐呭灞?`.onAppear()` 鐨勫厹搴曞垎鏀姞杩囦竴閬?璺ㄥ疄渚嬫椂闂寸獥"闂紝鍒ゆ嵁鍐欑殑鏄?
   * `PlaybackPage.lastCloseAtMs > 0 && Date.now() - PlaybackPage.lastCloseAtMs < CLOSE_WINDOW_MS`銆?
   * GLM 鎸囧嚭锛?*鏁翠唤鍏抽棴浠ｇ爜閲屾病鏈変换浣曚竴琛屽啓 `lastCloseAtMs`锛岃€?`CLOSE_WINDOW_MS` 涔熶粠鏈０鏄?*
   * 鈬?閭ｉ亾闂?*鎭掑亣**锛岀瓑浜庝粈涔堥兘娌″姞銆傛垜鏌ヨ瘉浜嗘椂闂寸嚎锛氶偅浠藉伐浣滃尯缂栬緫锛?3:54锛?
   *   **鏅氫簬鏈€鍚庝竴娆℃垚鍔熸瀯寤猴紙23:49锛?* 鈬?**瀹冧粠鏈缂栬瘧杩?*锛岀敤鎴疯鍒扮殑鍖呴噷鏍规湰娌℃湁瀹冦€?
   * 鈬?鏁欒锛?*鏀逛簡婧愮爜蹇呴』褰撳満鏋勫缓**锛?鎴戝姞浜嗛棬"涓?闂ㄥ湪浜х墿閲?鏄袱浠朵簨銆?
   *
   * ## 涓轰粈涔堥渶瑕?璺ㄥ疄渚?鐨勫垽鎹?
   * 鏈〉鎵€鏈?`@Local` / 绉佹湁瀛楁閮芥槸**瀹炰緥灞€閮?*鐨勶紱鑰?`morphReset()` 浼氭妸
   * `PlayerExpandState` 閲岄偅濂楋紙`morphSessionStarted` / `morphStage` / `morphGeomReady`锛夊叏娓呮帀銆?
   * 鈬?鍏抽棴浣欐尝钀藉湪**鏂板疄渚?*韬笂鏃讹紝瀹炰緥灞€閮ㄧ殑闂ㄥ叏閮ㄥけ鏄庛€?
   *   鍙兘鐢ㄤ竴涓?*璺ㄥ疄渚嬪叡浜?*鐨勬椂鍒诲仛鍒ゆ嵁 鈬?鏈潤鎬佸瓧娈点€?
   *
   * 鈿狅笍 **涓や釜瀛楁蹇呴』鎴愬浣跨敤**锛歚lastCloseAtMs` 鐢?*鍏抽棴閾捐矾**鍐?
   *    锛坄closeFullScreenPlayback` 鍏ュ彛锛夛紝`CLOSE_WINDOW_MS` 鍙湪姝ゅ褰撶獥鍙ｅ搴︺€?
   *    鍒啀鍑虹幇"鍙涓嶅啓"锛堥偅姝ｆ槸涓婁竴杞殑浜嬫晠锛夈€?
   */
  private static lastCloseAtMs: number = 0;

  /**
   * 鈽?2026-10-17锛氫笂涓€娆″叧闂?*璧颁簡閫€鍖栬矾寰?*鐨勫師鍥狅紙鐭爣绛撅紱绌?= 娌¤蛋閫€鍖栵級銆?
   *
   * 鐢?`closeLiveMorphFallback()` 鍐欍€乣closeFullScreenPlayback()` 鐨?`ev('CLO', 鈥?` 璇诲苟**娓呯┖**
   * 鈬?寰芥爣绗崄涓夎鐨?`CLO:鈥?fb=<鍘熷洜>` 灏辨槸"杩欐杩斿洖鍏抽棴璧扮殑鏄揩鐓ц繕鏄椿椤?鐨勭洿鎺ヨ鏁般€?
   * 鈿狅笍 鍙湪"閫€鍖栭偅涓€娆?鏈夊€硷紝璇诲畬鍗虫竻锛堝惁鍒欎細琚綋鎴愬父椹荤姸鎬侊級銆?
   */
  private static closeFallbackReason: string = '';

  /**
   * 鈽呪槄鈽?2026-10-16锛?*鍏抽棴杩囩▼鐨勬椂搴?榛戝專瀛?** 鈥斺€?鎵撶牬"娌℃湁璁惧璇绘暟"鐨勫兊灞€锛?
   *
   * ## 涓轰粈涔堝繀椤诲仛鎴?璺ㄥ疄渚嬮潤鎬侀攣瀛?
   * 鐢ㄦ埛鎶ョ殑涓ゆ潯锛堛€屽叧闂椂鑳屾櫙鍙墿涓€鏉°€嶃€屽叧闂悗鍙堟斁涓€閬嶅睍寮€銆嶏級**閮藉彂鐢熷湪鍏抽棴杩囩▼涓?*锛?
   * 鑰?*鎾斁椤典竴 pop锛屽睆涓婇偅涓窘鏍囧氨璺熺潃娌′簡** 鈬?浜嬪悗璇讳笉鍒颁换浣曚笢瑗裤€?
   * 鈬?鎶婂叧閿簨浠惰杩?*妯″潡绾ч潤鎬佺幆褰㈢紦鍐?*锛岀瓑**涓嬩竴娆℃墦寮€鎾斁椤?*鍐嶆樉绀?鈬?灏辨湁浜?涓婁竴娆″叧闂?鐨勫畬鏁存椂搴忋€?
   *
   * ## 璁颁粈涔堬紙鍙"鐘舵€佽浆绉?涓?鍏抽敭鍑哄彛"锛?*涓嶈姣忓抚**锛屽惁鍒欑幆褰㈢紦鍐蹭細琚埛鎺夛級
   * ```
   *   CLO  = closeFullScreenPlayback 鍏ュ彛锛堝啓涓?lastCloseAtMs锛?
   *   LV   = morphBeginLeaving锛堟敹璧风浉浣嶏級
   *   SET  = 鍏抽棴鏀跺熬瀹氭椂鍣ㄥ埌鐐癸紙闄?closeGen / alive / 璧颁簡鍝竴鏀級
   *   LND  = morphLand锛堣惤鍥炶糠浣犳潯锛?
   *   SQZ  = squashLandAnim锛堟尋鍘嬭捣锛?
   *   RST  = morphReset锛堝嚑浣曞洖鎭掔瓑锛?
   *   POPT = 澹冲眰鎶?isShowPlay 缃?false锛堣Е鍙?popPlayerRoute锛?
   *   REM  = 澹冲眰鐪熺殑鎶婃挱鏀鹃〉璺敱鍒犳帀浜嗭紙`popPlayerRoute` 閲岀殑 `pop/removeByIndexes`锛?
   *          鈽?**`RST` 涓?`REM` 鐨?`t+` 宸?*灏辨槸"婊″睆涓棿鎬?鏈夊闀匡紙鐢ㄦ埛绗?鈶?鏉＄殑鍒ゆ嵁锛?
   *   DIS  = 鍐呭灞?onDisappear锛堥檮 wasAlive锛?
   *   AP   = 鍐呭灞?onAppear锛堥檮璧颁簡鍝潯鍒嗘敮锛?
   *   INTR = playExpandIntro 璧凤紙**鑻ュ嚭鐜板湪鍏抽棴涔嬪悗锛屽氨鏄?鍙堟斁涓€閬嶅睍寮€"鐨勭洿鎺ヨ瘉鎹?*锛?
   *   OPN  = 澹冲眰 isShowPlay=true锛堣Е鍙?pushPlayerRoute锛?
   * ```
   * 姣忛」甯︿竴涓浉瀵规椂闂达紙ms锛岀浉瀵圭紦鍐插尯閲岀涓€鏉★級銆?
   *
   * ## 璇绘硶锛堝窘鏍?*绗崄涓夎**锛?
   * 缂撳啿鍖?*浠ヤ竴娆″叧闂负鍗曚綅**锛坄CLO` 涓€鍒板氨娓呯┖閲嶆潵锛夛紝鎵€浠ヨ鍒扮殑姘歌繙鏄?鏈€杩戜竴娆″叧闂?鐨勫叏杩囩▼锛?
   * 姝ｅ父鍏抽棴鍚庨噸鏂版墦寮€锛屽簲褰撶湅鍒板舰濡傦細
   * ```
   *   t0 CLO 鈫?t+2 LV 鈫?t+480 SET:ok/gen=3 鈫?t+481 LND 鈫?t+482 SQZ 鈫?t+483 RST 鈫?t+484 POPT 鈫?t+490 DIS:alive=0
   * ```
   * 寮傚父褰㈢姸涓庡惈涔夛細
   * - 鍑虹幇 **`INTR`**锛堝湪 DIS 涔嬪悗锛夆噿 纭鏄?鍏抽棴浣欐尝閲嶆斁灞曞紑"锛?
   * - 鍑虹幇 **`OPN`**锛堝湪鍏抽棴娈典箣鍚庯紝鑰岀敤鎴峰苟娌＄偣寮€锛夆噿 澹冲眰鎶婃挱鏀鹃〉鍙堟帹浜嗕竴娆★紱
   * - `SET:genBAD` / `SET:dead` 鈬?鏀跺熬瀹氭椂鍣ㄨ蛋浜嗘棭閫€鏀紙**鍑犱綍涓嶄細澶嶄綅** 鈬?鑳屾櫙鍙墿涓€鏉″悓婧愶級锛?
   * - **娌℃湁 `RST`** 鈬?`morphReset()` 娌℃墽琛?鈬?鍑犱綍鍋滃湪涓棿鎬侊紱
   * - `RST` 鍦?`REM`锛堣矾鐢辩湡琚垹鎺夛級**涔嬪墠瓒呰繃涓€甯?* 鈬?瀛樺湪"pop 浜嗕絾鍑犱綍宸茬粡婊″睆"鐨勪腑闂村抚
   *   锛圙LM 鐨勫亣璁撅紝搂123.3 鈥斺€?涔熷氨鏄敤鎴风 鈶?鏉＄殑鍊欓€夋満鍒讹級銆?
   */
  private static evLog: string = '';
  private static evT0: number = 0;
  private static evCount: number = 0;

  /**
   * 璁颁竴鏉℃椂搴忎簨浠讹紙瑙?{@link PlaybackPage.evLog}锛夈€?
   * @param tag 浜嬩欢鍚嶏紙涓婇潰閭ｅ紶琛ㄩ噷鐨勭煭鏍囩锛?
   * @param detail 鍙€夌殑琛ュ厖锛堜緥濡?`ok` / `genBAD` / `dead`锛?
   *
   * 鈿狅笍 **public static**锛堜笉鏄?private锛夛細澹冲眰 `products/default/.../pages/Index.ets` 鐨?
   *    `@Monitor('appState.isShowPlay')` 閲岃璁?`OPN` 鈥斺€?銆屽叧闂悗鍙堟斁涓€閬嶅睍寮€銆嶇殑
   *    澶村彿瀚岀枒灏辨槸**澹冲眰鎶婃挱鏀鹃〉鍙堟帹浜嗕竴娆?*锛岄偅涓€绗斿彧鏈夊３灞傝兘璁般€?
   *    锛堝３灞?鈫?鎾斁椤垫槸鍗曞悜渚濊禆锛歚player` 鐨勬《鏂囦欢宸茬粡瀵煎嚭 `PlaybackPage`锛屼笉鏋勬垚寰幆銆傦級
   */
  public static ev(tag: string, detail: string = ''): void {
    const now: number = Date.now();
    // 鈽?缂撳啿鍖轰互**涓€娆″叧闂?*涓哄崟浣嶏細`CLO`锛堝叧闂摼璺叆鍙ｏ級涓€鍒板氨鎶婁笂涓€杞暣娈垫竻鎺夈€乣t0` 閲嶇疆鍒拌繖涓€鍒汇€?
    //   涓轰粈涔堣繖鏍峰垏锛氬窘鏍囨槸**绛変笅涓€娆℃墦寮€鎾斁椤?*鎵嶆樉绀虹殑锛堝叧闂€斾腑椤甸潰宸茬粡琚?pop锛夛紝
    //   鑻ヤ笉娓咃紝璇诲埌鐨勬槸"濂藉嚑杞贩鍦ㄤ竴璧?鐨勬棩蹇楋紝`t+` 涔熶細涓€鐩村線涓婃定鍒扮湅涓嶅嚭鐩稿鏃跺簭銆?
    //   鍒囨垚"鏈€杩戜竴娆″叧闂?涔嬪悗锛岃娉曞氨鍥哄畾鎴?`t+0 CLO 鈫?鈥銆?
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
    // 鐜舰锛氳秴杩?900 瀛楃灏辩爫鎺夋渶鏃╅偅娈碉紙淇濅綇"鏈€杩戠殑鍏抽棴鍏ㄨ繃绋?锛?
    if (PlaybackPage.evLog.length > 900) {
      const cut: number = PlaybackPage.evLog.indexOf('|');
      if (cut >= 0) {
        PlaybackPage.evLog = PlaybackPage.evLog.substring(cut + 1);
      }
    }
  }

  /** 鍏抽棴浣欐尝绐楀彛锛坢s锛夆€斺€?`lastCloseAtMs` 鐨勫搴︺€傗殸锔?宸ョ▼鍒ゆ柇鍊硷紝涓嶆槸閫嗗悜鍊硷紙瑙佷笂鏂硅鏄庯級銆?*/
  private static readonly CLOSE_WINDOW_MS: number = 1500;

  /**
   * `scheduleMorphResetAfterPop()` 鐨勮疆璇㈤棿闅旓紙ms锛変笌鏈€澶ф鏁般€?
   *
   * 鈿狅笍 **宸ョ▼鍒ゆ柇鍊硷紝涓嶆槸閫嗗悜鍊?*锛氭棤鐣屾病鏈夎繖鏉?绛?pop 鍐嶅浣?鐨勬樉寮忚疆璇?
   * 锛堝畠鐨勯〉闈㈡槸妯℃€侊紝鏀惰捣瀹屾垚鍗冲嵏杞斤級銆傝繖閲屽彧鏄洜涓烘垜浠殑璺敱 pop 鏄?*寮傛**鐨勩€?
   * 32ms 鈮?涓ゅ抚锛? 娆?鈮?256ms 涓婇檺锛堣秴鏃跺厹搴曞浣嶏紝瀹佸彲鏅氫篃涓嶈兘涓嶆竻锛夈€?
   */
  private static readonly RESET_POLL_MS: number = 32;
  private static readonly RESET_POLL_MAX: number = 8;

  /** 涓婁竴娆?`RzdBgLayer` 鐨勭鍚嶏紙鑺傛祦锛夈€?*/
  private lastBgLayerLog: string = '';

  /**
   * 鈽呪槄鈽?2026-10-16 鏂板璇婃柇锛?*鑳屾櫙灞傚埌搴曟槸澶氬ぇ銆佸涓嶉€忔槑**銆?
   *
   * ## 瀹冨垽浠€涔堬紙鐢ㄦ埛鍙嶅鎶ョ殑涓ゆ潯閮介潬瀹冨畾鎬э級
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdBgLayer'
   *   鈬?RzdBgLayer box=(x,y,w,h) win=WxH clip=鈥?p=鈥?op=鈥?squashing=鈥?meshSrc=yes|no playing=鈥?
   * ```
   *
   * | 璇诲埌鐨?| 鍚箟 |
   * | --- | --- |
   * | `box.w/h 鈮?win` **涓?`op 鈮?1`** | 鑳屾櫙鏁村睆涓嶉€忔槑 鈬?杩欐墠鏄€?*鑳屾櫙鍏ㄥ睆**銆嶇殑褰㈢姸 |
   * | `box.w/h 鈮?win` 浣?`op` 寰堝皬锛?.04~0.3锛?| 鑳屾櫙鏁村睆浣嗗嚑涔庨€忔槑 鈬?**涓庢棤鐣屽悓褰?*锛堟棤鐣岄偅灞備篃鍦ㄦ弧灞忓眰閲岋級 |
   * | `box.w/h` 鏄庢樉灏忎簬 `win` | 鑳屾櫙琚檺鍒跺湪灏忕獥鍙ｉ噷锛堝彟涓€绉嶅舰鐘讹級 |
   * | `meshSrc=no` | 缃戞牸娌℃簮 鈬?灞忎笂鏄?*鍏滃簳鍙栨牱鑹?*锛堝湪绾挎瓕鏇查偅灞傛槸 `rgba(20,20,22,0.5)`锛?|
   *
   * 鈿狅笍 鍙锛氭湰鏂规硶涓嶅啓浠讳綍鐘舵€併€?
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
      `squashing=${(this.expandState.morphSquashY !== 1)} stage=${this.expandState.morphStage} ` +
      `meshSrc=${this.meshSrc !== undefined ? 'yes' : 'no'} playing=${this.state.isPlay} ` +
      `active=${this.state.isShowPlay}`);
  }

  /**
   * 鎺у埗鍖?*涓夋缁撴瀯**鐨勪袱鏍瑰崰浣嶆潯锛堢粍浠?id锛屽彧缁?{@link PlaybackPage.logLayoutBoxes} 閲忔祴鐢級銆?
   *
   * 鍑哄锛氭棤鐣?overlay 鐨?builder 鏍戯紙`wujie.pa:190464` / `190497`锛夆€斺€?
   * ```
   *   Row().height(lerp(swiperGap(), 10, swiperProgress))   // 190464  鈫?"Swiper 鈫?杩涘害鏉?
   *   Row().height(chrome().gapScrub)                       // 190497  鈫?"杩涘害鏉?鈫?浼犺緭鏉?
   * ```
   * 鈿狅笍 瀹冧滑**涓嶆槸 padding**锛屾槸**闆跺唴瀹?Row**锛坄Column` 閲岀殑鏅€氬厔寮熻妭鐐癸級鈥斺€?
   *   鎵€浠?涓夋"鏄?`[Swiper | gapSwiper 琛?| gapScrub 琛?| 杩涘害鏉?浼犺緭鏉`銆?
   * 鈿狅笍 鏃犵晫閭ｄ袱浠界敤鐨勬槸 `.height(lerp(...))`锛宍lerp` 绗笁瀹炲弬鏄?`swiperProgress`锛?
   *   鎷栨嫿鎵撳紑/鍏抽棴鐨勮繃绋嬩腑杩欎袱鏍规潯浼氳窡鐫€琛ラ棿锛坄a=swiperGap, b=10`锛夈€?
   *   鎴戜滑杩欎竴渚ф病鏈?`swiperProgress` 杩欎釜閲忥紙鎴戜滑鐨勫睍寮€杩涘害鍙?`morphP`锛岃涔変笉鍚岋級锛?
   *   鎵€浠?*闈欐鎬佸彇 `swiperGap()` 閭ｄ竴绔?*锛? `lerp(t=0)`锛夛紝褰㈠彉鏈熶笉鍔?鈥斺€?瑙佹柟娉曟敞閲娿€?
   */
  private static readonly SWIPER_GAP_ROW_ID: string = 'rzd_gap_swiper_row';
  private static readonly CHROME_SCRUB_GAP_ROW_ID: string = 'rzd_gap_scrub_row';

  /**
   * @returns 銆孲wiper 鈫?杩涘害鏉°€嶅崰浣嶆潯鐨勯珮搴︼紙vp锛夆€斺€?鏃犵晫 `swiperGap()`锛坄wujie.pa:180127`锛夈€?
   *
   * ## 涓轰粈涔堣繖閲屾槸**涓€涓父鏁?*銆佷笉鏄?`lerp`
   *
   * 鏃犵晫鍐欑殑鏄?`lerp(swiperGap(), 10, swiperProgress)`锛屽嵆**鎷栨嫿鎵撳紑/鍏抽棴杩囩▼涓?*杩欐牴鏉?
   * 浠?`swiperGap()` 鏀跺埌 10vp銆俙swiperProgress` 鏄?*瀹冭嚜宸辩殑**涓嬫媺杩涘害閲忥紙0鈫? 瀵瑰簲鍏抽棴鍔ㄤ綔锛夛紝
   * 鎴戜滑杩欎竴渚у搴旂殑鏄?`expandState.morphP`锛堝睍寮€杩涘害锛?*鏂瑰悜涓庣浉浣嶉兘涓嶅悓**锛?
   * 鎴戜滑鏄?浠庤糠浣犳潯闀垮埌鏁村睆"锛屽畠鏄?浠庢暣灞忓線涓嬫嫋璧?锛夈€?
   * 鈬?纭 `lerp(..., morphP)` 浼氬緱鍒?*鍙嶇浉**鐨勬洸绾匡紙灞曞紑鏃跺弽鑰屾敹绐勶級锛岄偅鏄?*鏂伴€犱竴涓涓?*锛?
   *   涓嶆槸鐓ф惉銆傛墍浠ラ潤姝㈡€佽€佽€佸疄瀹炲彇 `lerp` 鐨?`t=0` 閭ｄ竴绔紙`swiperGap()`锛夛紝
   *   骞舵妸"褰㈠彉鏈熻ˉ闂?鐧昏涓哄緟鍔烇紙`RzdMusic寰呯‘璁ゆ竻鍗?md` D4-b锛夈€?
   */
  private swiperGapRowHVp(): number {
    return this.expandState.swiperGapVp();
  }

  /**
   * @returns 銆岃繘搴︽潯 鈫?浼犺緭鏉°€嶅崰浣嶆潯鐨?*棰濆**楂樺害锛坴p锛夈€?
   *
   * 鈿狅笍 鎭掍负 0锛?*涓嶆槸婕忓仛**锛氳繖涓€娈电殑闂磋窛鎴戜滑**宸茬粡鏈変簡**锛屼綅缃湪
   *   `ControlAreaComponent.bottomPanel()` 閲岄偅涓?`Column` 鐨?`.margin({ bottom: 鈥?})`
   *   锛堟寜鏂偣鍙?`app.float.slider_margin_bottom*`锛夈€傛棤鐣岃〃閲岃繖涓€娈靛彨 `gapScrub`
   *   锛團ULL 28 / MEDIUM 20 / COMPACT 14锛夈€?
   * 鈬?杩欓噷淇濈暀涓€涓?0 楂樼殑鍙噺娴嬭妭鐐癸紝**鍙负**鎶?瀹炴祴闂磋窛 vs `gapScrub`"鎵撹繘鏃ュ織
   *   锛坄RzdSwiperBox`锛夛紝绛夌湡鏈烘暟鎹洖鏉ュ啀鍐冲畾鏄?鎶?margin 鎹㈡垚 `gapScrub`"杩樻槸"淇濈暀娲鹃煶鍘熷€?銆?
   *   鐜板湪**涓嶅苟琛屽姞**锛堝惁鍒欏氨鏄悓涓€娈甸棿璺濅袱鏉″彛寰?鈥斺€?鏈粨鍙嶅韪╄繃鐨勫舰鐘讹級銆?
   */
  private chromeScrubGapRowHVp(): number {
    return 0;
  }

  /**
   * 鈽?2026-10-15 璇婃柇閿氱偣锛氭妸**鍥涗釜浼氫簰鐩稿帇鐨勫潡**鐨勭獥鍙ｇ煩褰竴娆℃墦鍑烘潵銆?
   *
   * 鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdBoxes'`
   *
   * 鎵撶殑鏄?*绐楀彛鍧愭爣**锛坄getPositionToWindowWithTransform()`锛変笌**瀹炴祴灏哄**锛?
   * 涓庣敤鎴锋埅鍥剧殑鍍忕礌鍙互鐩存帴鎹㈢畻瀵硅处锛堟湰鏈?1224脳2776 鎴浘 鈬?3px/vp锛夛細
   * ```
   *   RzdBoxes cover=(x,y,w,h) title=(鈥? singer=(鈥? lyric=(鈥?
   * ```
   * **鍒ゆ嵁锛堝摢涓や釜鍧楃湡鐨勭浉浜ゃ€佸氨鏀归偅涓€瀵癸級**锛?
   *   路 `lyric.top` 钀藉湪 `[singer.top, singer.bottom]` 鍖洪棿鍐?鈬?**灏忔瓕璇嶅帇鍦ㄦ瓕鍚?姝屾墜閭ｄ竴琛屼笂**
   *     鈬?璋?`MINI_LYRIC_SINK_VP`锛堟湰浠撳凡鎸?涓よ鏂囧瓧"鐨勯噺绾х粰 44锛夛紱
   *   路 `lyric.bottom` 瓒婅繃鎺у埗鍖洪《杈?鈬?灏忔瓕璇嶈鎺у埗鍖哄帇浣?鈬?閭ｆ槸鍙︿竴澶勶紙Swiper 鏉冮噸鍒嗛厤锛夛紱
   *   路 `cover.bottom` 涓?`title.top` 鐨勯棿璺?鈮?0 鈬?姝屽悕绱ц创灏侀潰锛坄LYRIC_META_GAP_VP` 閭ｄ竴妗ｏ級銆?
   * 鈿狅笍 鍙銆佷笉鍐欙細鏈柟娉曚笉鏀瑰彉浠讳綍鐘舵€侊紙涓嶄細褰㈡垚"閲忔祴鈫掓敼鐘舵€佲啋鍐嶉噺娴?鐨勬鐜級銆?
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
    // 鈽呪槄鈽?2026-10-17锛?*銆屾瓕鍚嶈鍘嬪湪杩涘害鏉′笂銆嶇殑鍙噺娴嬪垽鎹?*锛?
    //   `chromeTop` = `gapSwiper` 閭ｆ牴鍗犱綅鏉＄殑瀹炴祴绐楀彛椤惰竟 = **鎺у埗鍖烘涓婃柟**锛?
    //   `metaTop` = 姝屽悕琛?*璁捐鍊?*锛坄metaTopGeomY`锛夛紝`metaBoxTop` = 姝屽悕琛?*瀹炴祴**椤惰竟銆?
    //   鍒ゆ嵁锛歚metaBoxTop + LYRIC_META_ROW_H_VP > chromeTop` 鈬?纭疄鍘嬭繘鎺у埗鍖?
    //   锛堥偅鏃惰鍔ㄧ殑鏄€屽皝闈㈢鐐?/ gap(50) / 鎺у埗鍖洪绠椼€嶈繖涓夎€呬腑鐨勪竴涓紝
    //     **涓嶈**鍦ㄦ瓕鍚嶈涓婂啀鍔犺ˉ鍋夸綅绉?鈥斺€?閭ｄ細鎴愪负绗簩涓綅绉绘簮锛夈€?
    //   鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdMetaChrome'`
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMetaChrome chromeTop=${this.boxTopY(PlaybackPage.SWIPER_GAP_ROW_ID).toFixed(1)} ` +
      `metaBoxTop=${this.boxTopY(PLAYER_META_TITLE_ID).toFixed(1)} ` +
      `metaTop=${this.expandState.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP).toFixed(1)} ` +
      `rowH=${PlaybackPage.LYRIC_META_ROW_H_VP} ` +
      `coverBottom=${(this.coverLocalRect().y + this.coverLocalRect().height).toFixed(1)} t=${this.lyricMorphT.toFixed(3)}`);

    // 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣岋級锛?*鎺у埗鍖轰笁娈电粨鏋?*鐨勫璐︽棩蹇椼€?
    //   鍒ゆ嵁锛堢湡鏈轰笂涓€娆″氨澶燂級锛氬疄娴?Swiper 楂樺害 vs `estBoxH()`锛? `usableH 鈭?chromeTotal`锛夛紝
    //   浠ュ強涓ゆ牴鍗犱綅鏉＄殑瀹炴祴楂?vs 搴旀湁楂樸€傚樊寰楀 鈬?鎴戜滑鎺у埗鍖虹殑鑷劧楂樺拰鏃犵晫琛ㄥ涓嶄笂锛?
    //   閭ｆ椂鍐嶅喅瀹?寰€琛ㄩ噷瀵归綈"杩樻槸"鏀规垜浠嚜宸辩殑楂樺害"锛?*涓嶈涓ゅご涓€璧锋敼**锛夈€?
    //   鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdSwiperBox'`
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

  /** @returns 鏌愪釜缁勪欢 id 鐨?*瀹炴祴楂樺害**锛坴p锛岄噺涓嶅埌杩斿洖 -1锛夆€斺€?鍙粰璇婃柇鏃ュ織鐢ㄣ€?*/
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
   * @returns 鏌愪釜缁勪欢 id 鐨?*绐楀彛鍧愭爣椤惰竟**锛坴p锛岄噺涓嶅埌杩斿洖 -1锛夆€斺€?鍙粰璇婃柇鏃ュ織鐢ㄣ€?
   *
   * 鈽?2026-10-17锛氬姞瀹冩槸涓轰簡缁欍€?*姝屽悕琛屽帇鍦ㄨ繘搴︽潯涓?*銆嶈繖涓€鏉′竴涓?*鍙噺娴嬬殑鍒ゆ嵁**
   *   锛堟垜姝ゅ墠鍙兘闈犳帹绠?chrome 椤惰竟锛屾帹鍑烘潵涓ゅ閮借嚜娲斤紝绛変簬娌″垽鎹級銆?
   *   鐜板湪鎶?`gapSwiper` 閭ｆ牴鍗犱綅鏉★紙= 鎺у埗鍖烘涓婃柟閭ｄ竴鏍癸級鐨勫疄娴嬮《杈规墦鍑烘潵锛?
   * ```
   *   鍒ゆ嵁锛歵itle.y + 琛岄珮 > gapRowTop(鈮?鎺у埗鍖洪《杈?  鈬?姝屽悕琛岀‘瀹炲帇杩涙帶鍒跺尯
   *   鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdBoxes'`
   * ```
   * 鈿狅笍 鐢?`getPositionToWindowWithTransform()`锛堝惈瀹瑰櫒鍙樻崲锛夆噿 褰㈠彉鏈熻鏁颁篃浼氳窡鐫€鍙橈紝
   *   鎵€浠ュ彧鐪?*钀藉畾鎬?*閭ｅ嚑琛屻€?
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
  /** 鍏抽棴鏃堕暱姣斾緥鐨勪笅闄愶紙`morphT` 灏忎簬瀹冩椂鎸夊畠绠楋級鈥斺€?瀵规爣鏃犵晫 `REVERSE_MIN_RATIO = 0.4`銆?*/
  private static readonly REVERSE_MIN_RATIO: number = 0.4;
  /**
   * 鐐瑰嚮/璧锋挱鎰忓浘鎵撳紑鏃讹紝琛ラ棿**寤跺悗涓ゅ抚**鍐嶈捣锛坢s锛夈€?
   *
   * 椤甸潰杩欎竴甯ф墠鍒氭寕杞姐€佽繕娌＄敾杩囩涓€甯э紱鍚屽抚璧疯ˉ闂寸殑璇濓紝绛夌涓€甯х湡鐨勭敾鍑烘潵鏃?
   * 鍔ㄧ敾宸茬粡璧颁簡鍑犲崄姣 鈥斺€?鐢ㄦ埛鐪嬪埌鐨勫氨鏄?鐩存帴鐐瑰紑鏄粠涓棿寮€濮嬬殑"銆?
   */
  private static readonly MORPH_INTRO_DELAY_MS: number = 50;
  /**
   * 涓€娆¤窡鎵嬩細璇濈殑鏈€闀垮悎鐞嗘椂闀匡紙ms锛夈€?
   *
   * `pullDragging` 娈嬬暀鏃剁偣鍑绘墦寮€浼氳烦杩囧舰鍙樺垵濮嬪寲锛堥€€鍖栨垚鑰佸姩鐢伙級锛岃繖鏉￠槇鍊肩敤鏉?
   * 鍒ゅ畾"杩欎釜鏍囪宸茬粡杩囨湡"锛氫竴娆′笂鎷?涓嬫媺涓嶅彲鑳芥寔缁?2 绉掍互涓娿€?
   */
  private static readonly PULL_DRAG_MAX_MS: number = 2000;
  /**
   * 閿氱偣杩樻病閲忓埌鏃剁殑閲嶈瘯闂撮殧锛坢s锛夈€?
   *
   * "鐐瑰嚮鎵撳紑"閭ｄ竴鍒昏糠浣犳潯/鎾斁椤靛父甯歌繕娌″竷灞€瀹岋紙`getFrameNodeById` 鎷夸笉鍒拌妭鐐癸級锛?
   * 鏃犵晫鐨勫仛娉曟槸**娉ㄥ唽灏辩华鍥炶皟绛夌潃**銆佽€屼笉鏄€€鍖栨垚鑰佸姩鐢伙紱鎴戜滑杩欓噷鐢ㄥ嚑甯ч噸璇曠瓑浠峰疄鐜般€?
   */
  private static readonly MORPH_RETRY_MS: number = 32;
  /**
   * 鍓╀綑閲嶈瘯娆℃暟锛堟瘡娆℃墦寮€閲嶇疆锛夆€斺€?**鐓ф妱鍙嶇紪璇戠殑 `PlayerPage.schedulePublishRetry`**锛?
   *
   *   鏈€澶氶噸璇?12 娆°€佹瘡娆￠棿闅?32ms锛堟€荤獥鍙ｇ害 384ms锛夛紝鐢ㄦ潵绛?鍒氭寕杞姐€佽繕娌″竷灞€瀹?鐨?
   *   鐩爣鑺傜偣鍙樻垚鍙噺娴嬨€傚弽缂栬瘧缁撹锛氭棤鐣岀殑鎾斁椤?*涔熶笉甯搁┗**锛堝悓鏍锋槸 push 鍑烘潵鐨勶級锛?
   *   瀹冧箣鎵€浠?绗竴娆″氨鏈夊皝闈㈤鍏?锛岄潬鐨勫氨鏄繖涓噸璇曠獥鍙?+ `setFinalStatus()` 鍏滃簳銆?
   */
  private morphRetryLeft: number = 12;
  /**
   * 銆屽彲浠ュ紑濮嬬敾浜嗐€嶇殑闂細褰㈠彉鐪熸寮€濮嬶紙鍑犱綍閲忓埌骞跺帇鍒拌捣鐐癸級涔嬪墠锛屾暣椤典繚鎸?*鍏ㄩ€忔槑**銆?
   *
   * 涓轰粈涔堥渶瑕佸畠锛氫负浜嗗厛閲忓埌"鍘熷昂瀵哥殑灏侀潰鐭╁舰"锛屾寕杞藉悗鍒板舰鍙樺紑濮嬩箣闂翠細鏈?1~2 甯?
   * 鎾斁椤靛浜?*鏈缉灏?*鐘舵€?鈥斺€?閭ｅ嚑甯ц嫢鐓у父缁樺埗灏变細闂竴涓嬪畬鏁存挱鏀鹃〉銆?
   * 鍏虫帀缁樺埗涓嶅奖鍝嶅竷灞€锛坄opacity` 涓嶅弬涓庡竷灞€锛夛紝鎵€浠ラ噺娴嬬収甯歌繘琛屻€?
   */
  @Local introPaintReady: boolean = false;
  /**
   * 褰㈠彉鏃╂湡"搴曢潰棰滆壊"娣″叆鐨勭粓鐐硅繘搴︼紙0鈥?锛夈€?
   *
   * 杩蜂綘鏉′篃鏄湪杩欎釜杩涘害娣″畬鐨勶紙`PlayerExpandState.miniBarOpacity` 鐢?0.20锛夛紝
   * 涓よ竟蹇呴』瀵归綈锛氬簳闈紙搴曡壊 + 鍙栬壊灞傦級鍒拌繖閲屾濂芥槸鎾斁椤电湡姝ｇ殑鑳屾櫙鑹诧紝
   * 杩蜂綘鏉″埌杩欓噷姝ｅソ娑堝け 鈥斺€?瑙傛劅灏辨槸"鎾斁鏉＄殑棰滆壊鍖栨垚浜嗛〉闈㈣儗鏅€佸苟璺熺潃闀垮ぇ"銆?
   */
  private static readonly MORPH_BG_FADE_TO: number = 0.20;
  /**
   * 灏侀潰 + 姝屽悕銆岀画椋炲埌姝岃瘝椤甸《閮ㄣ€嶇殑鏃堕暱锛坢s锛夈€傛瘮灞曞紑鐣ョ煭锛屽洜涓哄畠鍙槸灞€閮ㄥ厓绱犳崲浣嶃€?
   *
   * A2 璧疯繖鏉℃椂闀?*鐪熺殑琚敤涓婁簡**锛坄animateLyricMorph` 鐨?`animateTo`锛夛紱姝ゅ墠鏁村姝岃瘝椤?
   * 灏侀潰褰㈠彉琚?`lyricMorphVisible = false` 鏃犳潯浠跺叧鐫€锛岃繖涓父閲忔槸绌虹殑銆?
   */
  private static readonly LYRIC_MORPH_DURATION_MS: number = 360;
  /** 鎺у埗鍖洪潤姝㈠涔呭悗鑷姩鏀惰捣锛坢s锛夈€?*/
  /**
   * 鎺у埗鍖?*绌洪棽鑷姩鏀惰捣**鐨勭瓑寰呮椂闀匡紙ms锛夈€?
   *
   * 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣?`PlayerPage.IDLE_MS`锛夛細**5000**銆?
   *   鍑哄锛歚wujie.pa:197964` 鐨?`stlexvar 0x0, 0x8` 鍓嶄竴鏉?`ldai 0x1388`
   *   锛坄0x1388` = **5000**锛夛紝鑰?`startIdle()`锛坄wujie.pa:179936-179938`锛?
   *   灏辨槸 `setTimeout(<位>, IDLE_MS)`锛岄偅涓?位锛坄193408-193418`锛夊仛浠€涔堟槸鏄庣‘鐨勶細
   *   `idleTimer = -1; this.hideChrome();`銆?
   * 鈿狅笍 鎴戜滑鍘熸潵鏄?**3000**锛堟湰浠撹嚜瀹氬€硷紝鏃犲嚭澶勶級鈬?杩欏氨鏄?绌洪棽鏃堕棿涓嶄竴鏍?鐨勬潵婧愩€?
   */
  private static readonly CHROME_AUTO_HIDE_MS: number = 5000;
  /**
   * 鎺у埗鍖?浜嚭 / 鏀惰捣"閭ｆ潯琛ラ棿鐨勬椂闀匡紙ms锛夈€?
   *
   * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`PlayerPage.CHROME_ANIM_MS`锛夛細**350**銆?
   *   鍑哄锛歚showChrome()` 涓?`hideChrome()` 鍚勮嚜閭ｆ `animateTo(...)` 鐨?`duration`
   *   閮芥槸 `throw.undefinedifholewithname "CHROME_ANIM_MS"`
   *   锛坄logic-src/PlayerPage.abc.txt` 鐨?11967-11976 涓?4210-4219锛夛紝
   *   甯搁噺鍊?350 瑙?`_recover/logic-src/MiniMorph娓叉煋鏂逛笌椤跺簳鏍忔贰鍏ュ叕寮?md:163`
   *   锛坄CHROME_ANIM_MS | 350 | 椤舵爮鏄鹃殣鏃堕暱锛? D_MAIN锛塦锛夈€?
   *
   * 鈿狅笍 鎴戜滑鍘熸潵鏄?**240 + `Curve.EaseIn`锛堟敹璧凤級/ `Curve.EaseOut`锛堝敜鍑猴級**锛?
   *   鏄?*鏈粨鑷畾鍊?*锛堟棤鍑哄锛夆噿 鎸?涓嶈澶瑰甫鑷紪鍊?鏀规垚鏃犵晫閭ｄ袱涓€硷細
   *   **350ms + `Curve.EaseInOut`锛堟樉銆侀殣鍚屼竴鏉℃洸绾匡級銆?*
   */
  private static readonly CHROME_ANIM_MS: number = 350;
  /** 鎵嬫満绔?Swiper 閲屻€屾瓕璇嶉〉銆嶇殑涓嬫爣锛? = 灏侀潰椤碉級銆?*/
  private static readonly SWIPER_INDEX_LYRIC: number = 1;
  /**
   * 姝岃瘝鍖?*涓婁笅婊戝垏鎹㈡帶鍒跺尯**鐨勯槇鍊硷紙vp锛夆€斺€?鐓ф妱鏃犵晫 `SWIPE_TOGGLE_VP`銆?
   *
   * 鍑哄锛歚PlayerPage.onLyricSwipe`锛坄_recover/logic-src/PlayerPage.abc.txt:6942` 鐨?
   * `throw.undefinedifholewithname "SWIPE_TOGGLE_VP"`锛屼互鍙?*楂樻敮**鐨勫瓧闈㈤噺
   * `6974 ldai 0x18` = **24**锛夛紱褰掓。甯搁噺琛?`MiniMorph娓叉煋鏂逛笌椤跺簳鏍忔贰鍏ュ叕寮?md:171`
   * 鍚屾牱璁扮潃 `SWIPE_TOGGLE_VP | 24`銆?
   * 鈿狅笍 鏈粨鍘熸潵鍐欑殑鏄?**12**锛堣嚜瀹氱殑涓€鍗婏級鈬?澶鏄撹瑙︼紙鏈眰鏄?`parallelGesture`锛夈€?
   */
  private static readonly SWIPE_TOGGLE_VP: number = 24;
  /**
   * 姝岃瘝鍖?*涓婃粦闅愯棌鎺у埗鍖?*閭ｄ竴鏀槸鍚︽斁寮€ 鈥斺€?瀵瑰簲鏃犵晫鐨?`entryAllowsManual(lyricImmersive)` 闂ㄣ€?
   *
   * 鏃犵晫锛歚entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`锛岃€?
   * `LyricEntryMode` 榛樿妗ｆ槸 **AUTO**锛坄姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` 搂1锛歄FF0 / AUTO1 / MANUAL2 / BOTH3锛?
   * 鈬?**榛樿妗ｄ笅"涓婃粦闅愯棌"浠€涔堥兘涓嶅仛**锛堥偅涓€鏀暣娈佃闂ㄦ尅浣忥級銆?
   * 鏈粨娌℃湁杩欎釜鐢ㄦ埛璁剧疆锛堥潰鏉块噷娌℃湁"娌夋蹈姝岃瘝妯″紡"杩欎竴椤癸級鈬?鍙?*榛樿**琛屼负銆?
   *
   * 鈿狅笍 **鏀瑰洖 true 灏辨槸"涓婃粦闅愯棌鎺у埗鍖?閲嶆柊鐢熸晥**锛堜竴琛岋級锛涘凡鍦?
   *   `RzdMusic寰呯‘璁ゆ竻鍗?md` 绗?33 鏉￠噷鏄庣‘闂綘"瑕佷笉瑕佽繖涓墜鍔?銆?
   */
  private static readonly LYRIC_SWIPE_ALLOWS_MANUAL: boolean = false;

  /**
   * "婊氬姩浠嶅湪杩涜"鐨勫垽瀹氱獥锛坢s锛夆€斺€?瑙?`lastScrollAtMs` 鐨勬敞閲娿€?
   *
   * 鈽?2026-10-16锛氳繖涓€鏉?*涓嶆槸鍔ㄧ敾鏃堕暱銆佷笉鏄鎰熷弬鏁?*锛岃€屾槸"涓ょ椹卞姩鏂瑰紡骞跺瓨"鏃剁殑浠茶锛?
   *   `onContentDidScroll`锛堥€愬抚杩涘害锛夊綋瀹舵椂锛宍syncLyricMorphToPage()` 鐨?钀藉畾"蹇呴』璁╀綅銆?
   *   鈿狅笍 120ms 鈮?7 甯э細鎵嬫寚鎶捣鍚?swiper 鐨勬儻鎬ф粴鍔ㄤ竴鍋滐紝钀藉畾灏辫兘鎺ョ鏀跺熬銆?
   *   鈿狅笍 瀹冧笌 `Swiper` 鑷繁鐨?`duration` 鏃犲叧锛堥偅涓彧鍦ㄧ▼搴忓寲鍒囬〉鏃惰捣浣滅敤锛夈€?
   */
  private static readonly SCROLL_SETTLE_WINDOW_MS: number = 120;
  /**
   * 姝岃瘝椤甸偅涓€妯锛堝鏍囨棤鐣?`metaRow`锛夌殑鎺掔増甯搁噺 鈥斺€?鏁板€煎彇鑷?
   * `PlayerPage瀹屾暣UI瀹氱.md` 搂6.2锛氭爣棰?`15` / 绮椾綋 / 鐧?/ `opacity 0.86`锛屾瓕鎵?`12` / 甯歌銆?
   */
  private static readonly LYRIC_META_TITLE_FP: number = 15;
  private static readonly LYRIC_META_ARTIST_FP: number = 12;
  /**
   * **灏侀潰椤甸偅涓€绔?*鐨勬瓕鍚?姝屾墜瀛楀彿锛坒p锛夆€斺€?瀵规爣鏃犵晫 `chrome().titleSize` / `chrome().artistSize`锛團ULL 妗ｏ級銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋紱鏈疆浠庡瓧鑺傜爜鎻愬彇锛?*鍚屾椂绾犳鎴戜笂涓€杞殑涓€澶勮璇?*锛夛細
   *   鏃犵晫閭?*涓€涓?* `Text` 鐨勫瓧鍙锋槸**鎻掑€?*鍑烘潵鐨勶紙`wujie.pa:194905-194939`锛宍lerp` 涓夊弬璋冪敤锛夛細
   * ```
   *   fontSize( lerp( chrome().titleSize * sizeK(),   // 灏侀潰椤电 = 20 脳 sizeK
   *                   15 * sizeK(),                   // 姝岃瘝椤电 = 15 脳 sizeK
   *                   metaProgress() ) )              // 杩涘害锛? swiperProgress锛?
   * ```
   *   姝屾墜鍚岀悊锛歚lerp( chrome().artistSize * sizeK()(=14), 12 * sizeK(), metaProgress() )`銆?
   *   鈬?**灏侀潰椤?20 / 14锛屾瓕璇嶉〉 15 / 12**锛沗sizeK()` 鏄?绐楀彛瀹藉害鐨勫嚱鏁?
   *     锛堟墜鏈轰笂 鈮?锛屽钩鏉?PC 鎵嶆湁宸?鈥斺€?瑙?`RzdMusic寰呯‘璁ゆ竻鍗?md` E5锛夈€?
   *
   * 鈿狅笍 鎴戜滑鍘熸潵**涓ら〉閮藉浐瀹?15 / 12** 鈬?**灏侀潰椤垫瓕鍚嶅亸灏?33%锛?5 vs 20锛?*銆佹瓕鎵嬪亸灏忥紙12 vs 14锛夈€?
   * 鈿狅笍 涓婁竴杞紙搂56.27锛夋垜涓€搴︽妸瀹冭鎴?瀛楀彿瑕?*涔?* `metaProgress()`"锛屽苟鎹鍒?涓嶈鏀? 鈥斺€?
   *   **閭ｄ釜璇绘硶鏄敊鐨?*锛堟妸 `lerp` 褰撴垚浜嗕箻娉曪紝浜庢槸浠ヤ负灏侀潰椤典細鍙樻垚 0 鍙峰瓧锛夈€?
   *   鐪熺浉鏄彃鍊硷細瀛楀彿**浠庝笉娑堝け**锛屽彧鏄?*鐢?20 鏀跺埌 15**銆傛湰杞寜鐪熺浉鏀规銆?
   */
  private static readonly META_TITLE_FP_COVER: number = 20;
  private static readonly META_ARTIST_FP_COVER: number = 14;

  /**
   * 褰撳墠杩欎竴甯х殑**姝屽悕瀛楀彿**锛坒p锛夆€斺€?涓ょ涔嬮棿鎸?*姝岃瘝椤佃繘搴?*鎻掑€笺€?
   *
   * 鈽?鐢?`lyricMorphT`锛堟湰椤?灏侀潰椤?鈬?姝岃瘝椤?鐨勮繘搴︼級褰撴棤鐣?`metaProgress()` 鐨勭瓑浠风墿锛?
   *   闈欐鍦ㄥ皝闈㈤〉 = 0 鈬?`20fp`锛涢潤姝㈠湪姝岃瘝椤?= 1 鈬?`15fp`锛涘垏椤甸偅 360ms 閲岃繛缁繃娓°€?
   * @returns 姝屽悕瀛楀彿锛坒p锛?
   */
  private metaTitleFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_TITLE_FP_COVER,
      PlaybackPage.LYRIC_META_TITLE_FP, this.lyricMorphT);
  }

  /**
   * 褰撳墠杩欎竴甯х殑**姝屾墜瀛楀彿**锛坒p锛夛細`14`锛堝皝闈㈤〉锛夆啋 `12`锛堟瓕璇嶉〉锛夈€傜悊鐢卞悓 {@link metaTitleFp}銆?
   * @returns 姝屾墜瀛楀彿锛坒p锛?
   */
  private metaArtistFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_ARTIST_FP_COVER,
      PlaybackPage.LYRIC_META_ARTIST_FP, this.lyricMorphT);
  }

  /**
   * 涓ょ涔嬮棿鐨勭嚎鎬ф彃鍊硷紙`t` 澶瑰埌 0..1锛夈€傜粰涓婇潰涓や釜瀛楀彿鐢ㄣ€?
   * @param from `t = 0` 閭ｄ竴绔殑鍊?
   * @param to `t = 1` 閭ｄ竴绔殑鍊?
   * @param t 杩涘害锛堜换鎰忓疄鏁帮紝鍐呴儴澶瑰彇锛?
   * @returns 鎻掑€肩粨鏋?
   */
  private static lerpFp(from: number, to: number, t: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return from + (to - from) * p;
  }
  /** 灏忓皝闈㈠彸缂樺埌姝屽悕鐨勯棿璺濓紙vp锛夈€?*/
  private static readonly LYRIC_META_GAP_VP: number = 12;
  /** 璇ヨ鍙充晶鐣欑櫧锛坴p锛夆€斺€?缁欐敹钘?鏇村涓や釜鍥炬爣璁╀綅銆?*/
  private static readonly LYRIC_META_SIDE_VP: number = 16;
  // 鈿狅笍 2026-10-15锛歚LYRIC_META_ICON_FP` **宸插垹闄?* 鈥斺€?鏀惰棌 / 鏇村閭ｄ袱涓浘鏍囨敼鐢?
  //   `this.expandState.chromeFavSize()`锛?*鎸夋。浣嶈〃鍙栧€?* 24 / 22 / 20锛夛紝
  //   瀹屾暣鍑哄锛坄chrome().favSize`銆乣wujie.pa:195193 / 195316`銆佹。浣嶈〃 `93534`锛夊啓鍦ㄩ偅涓柟娉曚笂銆?
  //   鍒犲畠鐨勫師鍥狅細鍘熸潵杩欓噷鍐欐 `22`锛堟敞閲婅嚜闄?鍙栦笌娲鹃煶涓€鑷寸殑涓€妗?锛?*涓嶆槸鏃犵晫鐨勫€?*锛夛紝
  //   鎹㈡垚 getter 涔嬪悗杩欎釜甯搁噺灏?*娌℃湁璋冪敤鑰呬簡** 鈥斺€?涓嶇暀姝讳唬鐮侊紙鍚屾棌娓呯悊瑙?搂56.15 / 搂56.20锛夈€?
  /** 鍥炬爣鐨勭偣鍑荤儹鍖鸿竟闀匡紙vp锛屽畼鏂?`HIT = 44`锛夈€?*/
  private static readonly LYRIC_META_HIT_VP: number = 44;
  /**
   * 姝岃瘝椤甸偅涓€妯鐨?*琛岄珮**锛坴p锛夆€斺€?涓よ鏂囧瓧锛堟爣棰?15 / 姝屾墜 12 + 2 闂磋窛锛? 鍥炬爣鐣欑櫧銆?
   * 鈿狅笍 瀹冨彧鐢ㄤ簬"绔栫洿灞呬腑琛ュ伩"锛堣 `LyricFloatLayer` 閲?`.position()` 鐨勬敞閲婏級锛?
   *    **涓嶈**鏀规垚灏侀潰杈归暱 鈥斺€?閭ｄ細鎶婂皝闈㈤〉鐨勬瓕鍚嶅線涓嬫帹鍗婁釜澶у皝闈㈢殑楂樺害銆?
   */
  private static readonly LYRIC_META_ROW_H_VP: number = 34;
  /** 缃戞牸鑳屾櫙婧愮殑鐩掑紡妯＄硦鍗婂緞 / 杞暟锛堟棤鐣?`MeshCoverBg` 鐨?`BLUR_RADIUS` / `BLUR_PASSES`锛夈€?*/
  private static readonly MESH_BLUR_RADIUS: number = 9;
  private static readonly MESH_BLUR_PASSES: number = 3;
  /** 灞曞紑鐪嬮棬鐙楋紙ms锛夛細瓒呮椂杩樻病鍥炲埌瀹屾暣鎬佸氨寮哄埗鍥炲埌瀹屾暣鎬併€?*/
  private static readonly COLLAPSE_WATCHDOG_MS: number = 900;
  /** 灞曞紑鐪嬮棬鐙楀畾鏃跺櫒鍙ユ焺銆?*/
  private collapseWatchdogTimer: number = -1;
  /** 姝ｅ湪鎾敹璧峰姩鐢伙紙闃叉杩炵偣杩斿洖鎾袱閬嶏級銆?*/
  private isClosing: boolean = false;
  /**
   * 鈽呪槄 2026-10-15锛堟棤鐣岄€嗗悜 P0-3锛夛細鍥炲脊鏀跺熬鐨?*鐙珛浠ｆ**銆?
   *
   * 鈿狅笍 **涓嶈鐢?`morphGen` 鏍￠獙杩欎竴姝?*锛歚morphGen` 鏄?鍑犱綍浠ｆ"锛?
   *   `morphBeginEntering` / `morphBeginLeaving` / `morphReset` 閮戒細 `++`
   *   锛坄PlayerExpandState` L2330 / L2437 / L2456锛夆噿 240ms 绐楀彛閲屽彧瑕佽捣浜?*浠讳綍**鏂颁細璇濓紝
   *   杩欐鏀跺熬灏辫**闈欓粯璺宠繃**锛涜€屽畠鏄?*鍞竴**鎶?`morphDrive` 娓呭洖 `NONE` 鐨勫湴鏂?
   *   锛坄morphSettleOpen()` L2421锛夆噿 `morphSessionDriving()`锛圠2487锛夋亽鐪?
   *   鈬?澹冲眰鍏嬮殕灞傦紙涓変釜鎸夐挳 / 姝屽悕锛夊父椹诲湪灞忎笂銆?
   *   鍒ゆ嵁锛歚hdc shell hilog -x | Select-String 'RzdMorph'` 鈥斺€?涓€杞?涓嬫媺鈫掓澗鎵?閲?
   *   鐪?`morph open (settled)` 鏈夋病鏈夊嚭鐜般€?
   */
  private dismissSettleGen: number = 0;
  /**
   * 鈽呪槄 2026-10-15锛堟棤鐣岄€嗗悜 P0-2锛夛細鏁撮〉鍏抽棴鐨?*鐙珛浠ｆ** + 鍗歌浇瀹氭椂鍣ㄥ彞鏌勩€?
   *
   * 鍘熸潵鍙潬 `isClosing` 鎸￠噸鍏ワ紝鑰屽畠鍦?`morphCloseMs + 20`锛堚増370ms锛夊氨琚竻鍥?`false`锛?
   * 閭ｄ竴鍒绘挱鏀鹃〉**鍙兘杩樻病 unmount** 鈬?绗簩娆＄偣鍑昏兘鍐嶈捣涓€鏉?350ms 琛ラ棿 + 绗簩涓嵏杞藉畾鏃跺櫒锛?
   * 鑰?`morphGenAlive` 鏍￠獙鎷︿笉浣忥紙涓ゆ潯閾剧殑 `morphGen` 鐩稿悓锛夈€?
   * 鐜板湪锛氬彞鏌勫瓨涓嬫潵鍙鍙栨秷 + 浠ｆ涓ユ牸鏍￠獙 鈬?"绗簩娆＄偣鍑?瑕佷箞琚槑纭拷鐣ャ€佽涔堝共鍑€鎺ョ銆?
   */
  private closeGen: number = 0;
  private closeSettleTimer: number = -1;
  /**
   * 鏈涓嬫媺璺熸墜鏄惁宸茬粡鎶婂舰鍙樼浉浣嶅垏鍒?LEAVING锛堝鏍囨棤鐣岀殑 `drive = FINGER`锛夈€?
   *
   * 鏈変簡瀹冿紝鏉炬墜鏃舵墠鑳藉垎娓?杩欐涓嬫媺鐪熺殑璺熸墜杩?鍜?鍙槸鏋佺煭鐨勪竴娆℃嫋鎷?锛?
   * 鍚庤€呬笉鑳藉幓鍔ㄥ舰鍙樼浉浣嶏紝鍚﹀垯浼氭妸闈欐鐨?OPEN 鎬佹敼鎴?LEAVING銆?
   */
  private dismissMorphActive: boolean = false;
  /**
   * 鏈涓嬫媺鏀惰捣**璧锋墜閭ｄ竴鍒?*鐨勫舰鍙樿繘搴︼紙`morphP`锛?..1锛夆€斺€?鍏抽棴鎻愪氦鐢?*鐩稿閲?*鍒ゆ嵁鐨勫熀鍑嗐€?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣?`reverseQuitDelta`锛夛細鏃犵晫鐨勫叧闂彁浜や笉鏄?缂╁埌澶氬皯灏卞叧"锛?
   *   鑰屾槸"**姣旇捣鐐瑰線鍥炶蛋浜嗗灏?*"锛歚delta >= max(baseT/2, COMMIT_T)`銆?
   *   璧锋墜鏃跺湪 `morphBeginLeaving()` 涔嬪墠璁板綍鏈€硷紱鏉炬墜鏃剁畻 `delta = baseT 鈭?褰撳墠杩涘害`銆?
   *   鈿狅笍 鍒濆€煎彇 **1**锛堟弧灞曞紑锛夆€斺€?涓?浠庨潤姝㈢殑鎾斁椤靛紑濮嬩笅鎷?杩欎竴甯告€佷竴鑷达紱
   *      鐪熸璧锋墜鏃朵細琚珛鍒昏鐩栵紙瑙?`onDismissDrag` 閲岃褰曞畠鐨勯偅涓€琛岋級銆?
   */
  private dismissBaseT: number = 1;
  /**
   * 涓嬫媺鏀惰捣鎵嬪娍鐨?*璧锋墜浣嶇Щ闂ㄩ檺**锛坴p锛夈€?
   *
   * 鈽?瀵规爣鏃犵晫 `PlayerPage` 椤堕儴鍏抽棴鎵嬪娍鐨?
   *   `PanGesture({ direction: PanDirection.Down, distance: 8 })`
   *   锛坄_recover\logic-src\寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂0 閫熸煡琛?/ 搂1.1 鈶?/ 搂1.3锛?
   *   瀛楄妭鐮?`wujie.pa:181153-181157`锛夆€斺€?**灏辨槸鏃犵晫鐨勯偅涓?8锛屼笉鏄垜浠及鐨?*銆?
   *
   * 鈿狅笍 涓轰粈涔堢敤**妗嗘灦绾?*闂ㄩ檺銆佽€屼笉鍦?{@link onDismissDrag} 閲屾墜鍐?`if (offsetY < N) return;`锛?
   *   `PanGestureOptions.distance`锛堟湰鏈?`gesture.d.ts:2380` 纭湁璇ュ瓧娈碉紝**榛樿 5vp**锛?
   *   鏄?鎵嬫寚璧版弧澶氬皯鎵?*璇嗗埆**杩欎釜鎵嬪娍"鈥斺€?娌¤蛋婊℃椂 `onActionStart/Update/End`
   *   鏍规湰涓嶄細瑙﹀彂 鈬?闈欐鎬佽 1~2vp 鎶栧姩鎺ㄨ繘 `LEAVING`锛坄娲鹃煶鍔ㄧ敾Bug娓呭崟.md` P0-4锛?*鍦ㄦ簮澶翠笉鎴愮珛**锛?
   *   鑰屾墜鍐欏垽鎹細澶氫竴娆′笉杩炵画锛堣窡鎵嬭繘搴﹀湪闂ㄩ檺閭ｄ竴甯т粠 0 鐩存帴璺冲埌 `N/span`锛夈€?
   *
   * 鈿狅笍 **鎵撳紑鏂瑰悜涓嶅姩**锛氫袱鏉¤糠浣犳潯鐨?`panOption` 淇濇寔榛樿 5vp 鈥斺€?
   *   閭ｆ濂界瓑浜庢棤鐣屼笂婊戞墦寮€鎵嬪娍鐨?`{ direction: PanDirection.Vertical, distance: 5 }`
   *   锛堝悓鏂囨。 搂1.1 鈶狅級锛屾墍浠ラ偅閲屾棦涓嶅姞涔熶笉鏀广€?
   */
  private static readonly DISMISS_PAN_DISTANCE_VP: number = 8;
  // 鈿狅笍 涓嬫媺鏀惰捣鐨勪袱涓?*鍒ゆ嵁甯搁噺**锛堟彁浜ら槇鍊?38 / 鍏滃簳琛岀▼姣斾緥 0.42锛?*宸叉敹鏁涘埌**
  //    `PlayerExpandState.DISMISS_COMMIT_PROGRESS` / `PlayerExpandState.DISMISS_DRAG_SPAN_RATIO`
  //    鈥斺€?鍘熷厛瀹冧滑涓庢墦寮€鏂瑰悜鐨?`PULL_OPEN_COMMIT_FRACTION` 鍒嗗眳涓や釜鏂囦欢銆佹棤浜ゅ弶鏍￠獙
  //    锛坄娲鹃煶鍔ㄧ敾Bug娓呭崟.md` P0-1锛夈€傜悊鐢变笌"涓嶈鐓ф妱鏃犵晫 0.32"鐨勮鏄庨兘鍦ㄩ偅閲岀殑娉ㄩ噴閲屻€?
  /**
   * 涓嬫媺鏉炬墜鏃剁殑**閫熷害**鎻愪氦闃堝€硷紙vp/s锛夈€?
   *
   * 鍑哄锛歚docs\鏃犵晫褰㈠彉鎵嬫劅-钀藉疄鍒癛zdMusic娓呭崟.md` 搂涓€ 1.2銆屾彁浜ゅ垽瀹?鈥斺€?杩涘害 OR 閫熷害銆嶏細
   * `commit = (morphT >= COMMIT_T 鍗?0.32) || (velocity <= COMMIT_VELOCITY 鍗?900)`
   * 鈬?鏃犵晫鐨?`COMMIT_VELOCITY = 900`銆?*杩欎釜鏁版槸浠庢枃妗ｅ彇鐨勶紝涓嶆槸浼扮殑銆?*
   *
   * 鈿狅笍 浣?*缁濅笉鐓ф妱瀹冪殑姣旇緝鏂瑰悜/姝ｈ礋鍙?*锛氭棤鐣屾槸"涓婃媺鎵撳紑"锛岃繖閲屾槸"涓嬫媺鏀惰捣"锛屾柟鍚戠浉鍙嶏紝
   *   鏂囨。涔熸槑璇?绗﹀彿瑕佸厛瀹炴祴銆佸埆鐓ф妱"銆傝 {@link onDismissDrag}锛?
   *   **鏂瑰悜鐢变綅绉诲垽銆佸ぇ灏忕敱 `Math.abs(velocityY)` 鍙?* 鈬?鏍逛笂涓嶉渶瑕佸亣璁剧鍙枫€?
   */
  private static readonly DISMISS_COMMIT_VELOCITY: number = 900;
  /**
   * 鈽呪槄 2026-10-15锛堟棤鐣岄€嗗悜 P0-4锛夛細涓嬫媺鏀惰捣鐨?*鏈€灏忚捣鎵嬩綅绉?*锛坴p锛夈€?
   *
   * 娌℃湁瀹冪殑鏃跺€欙紝璺熸墜鍒嗘敮鍙 `offsetY > 0`锛?*1vp 閮界畻**锛夊氨浼?`morphBeginLeaving()`
   * 鈬?鐩镐綅琚帹杩?`LEAVING` 涓?`morphGen++`锛岃€屽睆涓婂嚑涔庝粈涔堥兘娌″姩锛?
   * 鏉炬墜鍥炶惤鏃跺張缁欑浉浣嶅仛涓€娆?220ms 琛ラ棿 + 240ms 瀹氭椂鍣?
   * 鈬?瑙傛劅鏄?杞昏交韫竴涓嬪氨闂竴涓?锛屽悓鏃舵妸 P0-3 閭ｆ潯娈嬬暀鐘舵€佺殑闂ㄦ墦寮€銆?
   * 8vp 鈮?2.5mm锛?*杩滃皬浜?*璇Е灏哄害锛堚墺10vp锛変笌鐪熷疄涓嬫媺璧锋墜锛堝嚑鍗?vp锛?
   * 鈬?**鍙尅鎶栧姩銆佷笉鎸¤窡鎵?*锛堜笅涓€涓?`onActionUpdate` 涓€鏃﹁秺杩囧畠鐓у父璧锋墜锛夈€?
   * 鈿狅笍 鏃犵晫渚?*娌℃湁**杩欎釜闂ㄩ檺 鈥斺€?杩欐槸娲鹃煶鑷繁鐨勫姞鍥猴紝**鏁呮剰涓嶄笌瀹冨榻?*銆?
   */
  private static readonly DISMISS_MIN_START_VP: number = 8;

  /** @returns 绐楀彛楂樺害锛坴p锛夛紱鎷夸笉鍒版椂缁欎竴涓厹搴曞€硷紝淇濊瘉鎷栨嫿姣斾緥涓嶄細闄ら浂銆?*/
  private deviceHeightVp(): number {
    const px: number = this.windowInfo.windowSize.height;
    if (px <= 0) {
      return 780;
    }
    return this.getUIContext().px2vp(px);
  }

  /**
   * @returns 涓嬫媺鍒板簳鎵€闇€鐨勮窛绂伙紙vp锛夆€斺€?璺熸墜褰掍竴鍖栫殑**鍒嗘瘝**銆?
   *
   * 鈽?D2锛?*浼樺厛鐢ㄥ疄娴?*锛屾嬁涓嶅埌鎵嶉€€鍥炵獥鍙ｆ瘮渚嬨€傚榻愭棤鐣?
   *   `pullRangePx = coverRect.top > 0 ? coverRect.top : windowHeight * 0.32`
   *   锛坄docs\鏃犵晫褰㈠彉鎵嬫劅-钀藉疄鍒癛zdMusic娓呭崟.md` 搂涓€ 1.1锛夈€?
   *
   * **涓轰粈涔堝疄娴嬪€煎彇 `expandState.miniY`**锛氳窡鎵嬭繘搴︽槸銆屾墜鎸囦綅绉荤殑绾嚱鏁般€?
   *   锛坄progress = offsetY / span`锛夛紝鍒嗘瘝鐨勮涔夊氨鏄?鎵嬫寚璧板畬鏁翠釜鏀惰捣鍔ㄤ綔瑕佽蛋澶氳繙"銆?
   *   鏀惰捣鐨勭洰鏍囨槸杩蜂綘鏉″皝闈㈤偅涓€灏忓潡锛岃€屽畠鐨勯《杈瑰氨鍦ㄧ獥鍙ｅ潗鏍?`miniY` 鈥斺€?褰㈠彉瀹瑰櫒鍦?`p = 0`
   *   鏃剁殑鍙鐭╁舰椤惰竟姝ｆ槸 `miniCoverY`锛? `miniY`锛岀敱 `morphInitParams()` 浠庡悓涓€浠藉疄娴嬪€肩畻鍑猴級锛?
   *   婊″睆鎬侀《杈规槸 0 鈬?璧板畬鍏ㄧ▼ = 椤惰竟浠?0 鎸埌 `miniY` 鈬?琛岀▼ `miniY`銆?
   *
   * 鈿狅笍 **鏀瑰垎姣嶄笉浼氱疮绉亸绉?*锛埪у叚 绗?3 鏉＄殑鍒ゆ嵁锛夛細`dismissProgressFromDrag()` 浠嶇劧鏄?
   *   `clamp(offsetY / span * 100)` 杩欑"**褰撳墠**鎵嬫寚缁濆浣嶇Щ"鐨勭函鍑芥暟锛?*涓嶈涓婁竴甯?*锛?
   *   鑰屼笖 `miniY` 鍦ㄤ竴娆℃嫋鍔ㄦ湡闂存槸甯搁噺 鈥斺€?杩蜂綘鏉″湪褰㈠彉鏈熼棿鏄?`Visibility.Hidden`
   *   锛?*淇濈暀甯冨眬**銆侀潰绉笉鍙橈級锛屼笉浼氬啀瑙﹀彂 `onAreaChange` 涓婃姤 鈬?鍒嗘瘝涓嶄細鍦ㄦ嫋鍔ㄤ腑閫旇烦鍙樸€?
   */
  private dismissSpanVp(): number {
    const measured: number = this.expandState.miniY;
    if (measured > 0) {
      return measured;
    }
    return this.deviceHeightVp() * PlayerExpandState.DISMISS_DRAG_SPAN_RATIO;
  }

  /**
   * 鐢辨嫋鎷借窛绂绘崲绠楁敹璧疯繘搴︺€?
   * @param offsetY 鎵嬪娍鐨勭珫鐩翠綅绉伙紙vp锛屽悜涓嬩负姝ｏ級銆?
   * @returns 杩涘害 0..100銆?
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
   * 涓嬫媺鏀惰捣鎵嬪娍锛氭嫋鍔ㄦ湡闂?*璺熸墜**鏀硅繘搴︼紙涓嶈蛋 animateTo锛屾墍浠ユ槸鍗虫椂鐨勶級锛?
   * 鏉炬墜鏃?**杩涘害杩囬槇鍊?OR 閫熷害瓒冲蹇?* 灏辨敹璧凤紝鍚﹀垯琛ラ棿寮瑰洖瀹屾暣鎬併€?
   *
   * 杩欏浜や簰鍜屽弬鑰冨伐绋?MusicHome 鐨?`PanGesture` 涓€鑷达紙瀹冪殑 `dismissPanOffsetY`
   * 鈫?`dismissSheetHeightPercent` + `coverLinearScale` 鏄悓涓€浠朵簨锛夈€?
   *
   * 鈽?D1锛氶€熷害椤硅涓嬮潰 {@link PlaybackPage.DISMISS_COMMIT_VELOCITY}銆?
   * @param offsetY 褰撳墠绔栫洿浣嶇Щ锛坴p锛屽悜涓嬩负姝ｏ級銆?
   * @param ended 鏄惁鏄澗鎵嬨€?
   * @param velocityY 鏉炬墜鏃剁殑绔栫洿閫熷害锛堟潵鑷?`GestureEvent.velocityY`锛夈€?
   *   鈿狅笍 **鏈嚱鏁颁笉渚濊禆瀹冪殑绗﹀彿**锛堣涓嬶級锛屾墍浠ラ粯璁ゅ€?0 涔熶笉浼氶€犲嚭"璇彁浜?銆?
   */
  private onDismissDrag(offsetY: number, ended: boolean, velocityY: number = 0): void {
    if (this.isClosing) {
      // 鈽呪槄 2026-10-15锛氳繖涓€琛屼互鍓嶆槸**闈欓粯** return锛屼簬鏄?涓嬫媺鏀惰捣瀹屽叏涓嶈窡鎵?杩欎欢浜?
      //   鍦ㄦ棩蹇楅噷涓€鐐圭棔杩归兘娌℃湁锛堟墜鎸囧姩浜嗐€佸睆涓婃病鍔ㄣ€佹棩蹇椾篃娌″啓锛夛紝鍙兘闈犵寽銆?
      //   鐜板湪鎶婂畠鎵撳嚭鏉ワ細`hdc shell hilog -x | Select-String 'RzdMorph dismiss blocked'`
      //   鈥斺€?鍑虹幇瀹?= `isClosing` 鍗′綇浜嗭紙瑙?`closeFullScreenPlayback()` 鐨勮ˉ婕忔敞閲婏級锛?
      //   **瀹屽叏涓嶅嚭鐜?* = 鎵嬪娍鏍规湰娌″埌杩欙紙閭ｆ槸鎵嬪娍璺敱闂锛屽幓鏌?`RzdMorph dismiss pan start`锛夈€?
      Logger.warn(PlayerExpandState.LOG_TAG,
        `RzdMorph dismiss blocked: isClosing=true offsetY=${offsetY.toFixed(1)} ended=${ended}`);
      return;
    }
    const progress: number = this.dismissProgressFromDrag(offsetY);
    // 鈽呪槄 D1锛堟渶楂樹紭鍏堢骇锛夛細鎻愪氦鍒ゅ畾 = **杩涘害 OR 閫熷害**锛堟棤鐣?搂涓€ 1.2锛夈€?
    //   鍙湁杩涘害鏃讹紝"浣嶇Щ涓嶅埌 38% 浣嗙敥寰楀緢蹇?鏀朵笉璧锋潵 鈥斺€?鐢ㄦ埛鎵嬫劅涓婂氨鏄?蹇敥娌″弽搴?銆?
    //
    //   鈿狅笍 **涓嶈鐚?`velocityY` 鐨勭鍙?*锛堟枃妗?搂鍏?绗?3 鏉?+ 搂鍥?D1 鐨?鈿狅笍锛夛細
    //     鏃犵晫閭ｈ竟鏄?鍚戜笅涓烘"锛岃€屾垜浠繖閲屾槸**涓嬫媺鏀惰捣**銆佹柟鍚戜笌瀹冪浉鍙嶏紝
    //     鐓ф妱姝ｈ礋鍙峰繀閿欙紱鑰?SDK 鐨?`GestureEvent.velocityY`锛坄gesture.d.ts`锛孈since 10锛?
    //     涔熸病鏈夋壙璇虹鍙锋柟鍚戙€傛墍浠ヨ繖閲屼粠鏍逛笂缁曞紑锛?
    //       路 **鏂瑰悜**鍙敱**浣嶇Щ**鍒?鈥斺€?`offsetY > 0` 鍗?杩欐鎷栧姩鏈濇敹璧锋柟鍚?锛?
    //       路 **澶у皬**鍙彇 `Math.abs(velocityY)`銆?
    //     鈬?鏃犺绯荤粺缁欑殑鏄?+900 杩樻槸 鈭?00锛屽垽瀹氱粨鏋滈兘涓€鏍凤紝**娌℃湁浠讳綍"绗﹀彿瀹炴祴"鍓嶇疆鏉′欢**銆?
    //   闃堝€?900 鍙栬嚜鏂囨。锛堣 `DISMISS_COMMIT_VELOCITY` 鐨勬敞閲婏級锛屼笉鏄紪鐨勩€?
    const collapsingDirection: boolean = offsetY > 0;
    const speed: number = Math.abs(velocityY);
    const fastFlick: boolean = collapsingDirection && speed >= PlaybackPage.DISMISS_COMMIT_VELOCITY;
    // 鈽?褰㈠彉閭ｅ锛氫笅鎷夋敹璧峰氨鏄?*鍙嶅悜璺戝悓涓€濂楀嚑浣?*锛堟棤鐣屼篃鏄悓涓€涓?progress 姝ｅ弽涓ょ敤锛?
    //   鈥斺€?鏁撮〉缂╁洖杩蜂綘鏉￠偅涓€灏忓潡銆佽鍓獥鍙ｆ敹鍥炲幓銆佽糠浣犳潯鍚屾椂娣″洖鏉ャ€?
    if (this.expandState.morphUsable) {
      if (!ended) {
        if (!this.dismissMorphActive) {
          // 鈽呪槄 P0-4锛?*鏈€灏忚捣鎵嬩綅绉婚棬闄?*锛堜緷鎹 `DISMISS_MIN_START_VP` 鐨勬敞閲婏級銆?
          //   浣庝簬瀹冨氨褰撹繖娆℃嫋鍔ㄤ笉瀛樺湪锛氫笉鏀圭浉浣嶃€佷笉 ++ 浠ｆ銆佷笉鍒峰嚑浣曪紝鐩存帴杩斿洖銆?
          //   涓嬩竴涓?`onActionUpdate` 鍙瓒婅繃闂ㄩ檺灏变細姝ｅ父璧锋墜 鈬?璺熸墜涓嶄細鍙樿繜閽濄€?
          //   鈿狅笍 **`fastFlick` 蹇呴』鑳界粫杩囬棬闄?*锛氫竴娆?鏋佸揩浣嗕綅绉诲緢灏?鐨勪笅鐢?
          //      锛?ms 鍐呭彧璧颁簡鍑?vp锛夊師鏈潬閫熷害椤瑰氨鑳芥敹璧凤紝琚棬闄愭尅鎺夊氨鎴愪簡"蹇敥娌″弽搴?
          //      鈥斺€?閭ｆ鏄?D1 褰撳垵瑕佷慨鐨勬瘺鐥呫€傛墍浠ヨ繖閲屾槸 `浣嶇Щ娌¤繃闂ㄩ檺 **涓?* 涓嶆槸蹇敥`銆?
          if (offsetY < PlaybackPage.DISMISS_MIN_START_VP && !fastFlick) {
            return;
          }
          this.refreshCollapseGeometry();
          this.dismissMorphActive = true;
          // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋細鍏抽棴鎻愪氦鏀规垚**鐩稿閲?*鍒ゆ嵁锛夛細璧锋墜杩欎竴鍒诲厛鎶婂綋鍓嶈繘搴﹁涓嬫潵 鈥斺€?
          //   鏉炬墜鏃剁殑鍒ゆ嵁鏄?**姣旇捣鐐瑰線鍥炶蛋浜嗗灏?*"锛坄delta`锛夛紝涓嶆槸"缂╁埌浜嗗灏?銆?
          //   鏃犵晫 `reverseQuitDelta()`锛歚quit = delta >= max(baseT/2, COMMIT_T)`
          //   锛坄_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂鍏?L351-353 / L386锛?
          //   瀛楄妭鐮?L151812-151838锛夈€?
          //   鈿狅笍 蹇呴』鍦?`morphBeginLeaving()` **涔嬪墠**鍙栵細涓嬩竴姝ヤ細鏀圭浉浣嶃€?
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
      // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛氬叧闂彁浜ゆ敼鎴?*鐩稿閲?*鍒ゆ嵁 `delta >= max(baseT/2, COMMIT_T)`
      //   锛堟棤鐣?`reverseQuitDelta()`锛涘嚭澶勫悓涓婏級銆?
      //   路 `delta` = 璧风偣杩涘害 鈭?褰撳墠杩涘害 = "杩欎竴鎷栧線鍥炶蛋浜嗗灏?锛?
      //   路 **婊″睍寮€璧锋墜**锛坄baseT = 1`锛夆噿 闃堝€?= `max(0.5, 0.32) = 0.5` 鈬?**瑕佹媺鍥炲幓 50% 鎵嶅叧**
      //     锛堟敼鍓嶆槸"缂╁埌 38% 灏卞叧"鈮?`delta 鈮?0.38` 鈬?**鏇村鏄撹鍏?*锛夛紱
      //   路 `baseT` 灏忎簬 0.64 鏃堕槇鍊奸€€鍒?`COMMIT_T = 0.32`锛堟棤鐣岄偅鏉?`max` 鐨勫彟涓€鍗婏級銆?
      //   鈿狅笍 閫熷害椤?*涓嶈兘涓?*锛氭棤鐣屼篃鏄?`杩涘害 鈭?閫熷害`锛埪т竴 1.2锛夛紝"蹇敥"蹇呴』鐓ф牱鑳藉叧銆?
      const currentT: number = 1 - progress / 100;
      const dismissDelta: number = this.dismissBaseT - currentT;
      const dismissThreshold: number = Math.max(this.dismissBaseT / 2,
        PlayerExpandState.PULL_OPEN_COMMIT_FRACTION);
      const shouldClose: boolean = dismissDelta >= dismissThreshold || fastFlick;
      // 涓婃満鎺掓煡鐢細`hdc shell hilog -x | Select-String 'RzdMorph dismiss commit'`
      // 鈿狅笍 杩欎竴琛?*鏁呮剰鍚屾椂鎵撲袱涓柟鍚戠殑闃堝€间笌涓や釜鍒嗘瘝**锛堝弬瑙?
      //    `PlayerExpandState.pullSpanIsMeasured()` 鐨勬敞閲?/ `娲鹃煶鍔ㄧ敾Bug娓呭崟.md` 搂6.5锛夛細
      //    鍙墦"姣斿€?vs 闃堝€?浼氱户缁棌浣?涓ゆ妸灏哄瓙涓嶆槸鍚屼竴涓暱搴?杩欎欢浜嬨€?
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
        // 浜ょ粰 closeFullScreenPlayback锛氬畠浼氭帴鐫€鎶婂舰鍙樿ˉ闂村埌 0 鍐嶅嵏杞?
        this.closeFullScreenPlayback();
        return;
      }
      // 娌¤繃闃堝€硷細寮瑰洖瀹屾暣鎬侊紝骞舵妸鐩镐綅鏀跺洖 OPEN
      this.expandState.morphDrive = MorphDrive.ANIM;
      // 鈽呪槄 P0-3锛氱浉浣嶅綊浣嶆敼鐢?*鐙珛浠ｆ**锛堜緷鎹瀛楁 `dismissSettleGen` 鐨勬敞閲婏級锛?
      //   涓嶅啀澶嶇敤 `morphGen` 鈥斺€?瀹冧細琚换浣曟柊浼氳瘽 ++锛屽鑷磋繖娆℃敹灏捐闈欓粯璺宠繃锛?
      //   鑰?`morphDrive` 灏辨案杩滃仠鍦?`ANIM`銆?
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
          // 鏈疆鍥炲脊宸茶涓嬩竴娆″洖寮瑰彇浠?
          return;
        }
        // 鈽?鐩镐綅宸茶鍒殑浼氳瘽鎺ョ灏卞繀椤绘斁鎵嬶細鏂颁竴杞嫋鍔ㄤ細鎶?`drive` 缃?`FINGER`锛?
        //   `morphBeginEntering` 浼氭妸 `stage` 缃?`ENTERING`銆乣closeFullScreenPlayback`
        //   浼氭妸 `isClosing` 缃湡 鈥斺€?涓夌鎺ョ閮借兘琚笂闈㈠嚑鏉℃尅浣忋€?
        //   鍙湁"鏈疆浠嶆槸鐩镐綅涓讳汉"鏃舵墠褰掍綅銆?
        if (this.expandState.morphStage !== MorphStage.LEAVING
          || this.expandState.morphDrive !== MorphDrive.ANIM) {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss bounce: phase taken over stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}, skip settle`);
          return;
        }
        // 鈽?`morphSettleOpen()` 鍐呴儴浼氭妸 `morphDrive` 褰?`NONE`
        //   锛坄PlayerExpandState` L2421锛?*鍏ㄤ粨鍞竴**鐨勬竻闆剁偣锛夆€斺€?
        //   杩欎竴姝ュ氨鏄?澹冲眰鍏嬮殕灞傚父椹?閭ｆ潯 bug 鐨勮В鑽紝**涓嶈缁曡繃瀹?*銆?
        this.expandState.morphSettleOpen();
      }, 240);
      return;
    }
    // 鏃犳湁鏁堥敋鐐逛笉杩愯鏃у帇鎵佸竷灞€锛屾澗鎵嬫弧瓒抽槇鍊兼墠鐩存帴鍏抽棴銆?
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

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 灏侀潰 + 姝屽悕缁鍒版瓕璇嶉〉椤堕儴锛圓2锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /**
   * 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲 灏侀潰 / 姝屽悕娴眰鐨?*璺ㄩ〉瀹氫綅**锛堝鏍囨棤鐣?`floatingCover` / `floatingMeta`锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
   *
   * 鍒囧埌姝岃瘝椤垫椂璁?*鍚屼竴寮犲皝闈?+ 姝屽悕**缂╁皬骞剁Щ鍒版瓕璇嶉〉椤堕儴锛屽垏鍥炲皝闈㈤〉鏃跺師璺鍥?鈥斺€?
   * **鐢?Swiper 鐨勬粴鍔ㄨ繘搴﹂€愬抚椹卞姩**锛堜笉鏄ˉ闂撮┍鍔級銆?
   *
   * ## 涓轰粈涔堟槸杩欐牱锛堣€屼笉鏄?涓ら〉鍚勭敾涓€浠?锛?
   *
   * 鏃犵晫鐨?`playerPane` 鏄?`Stack { Swiper{ 灏侀潰椤?; 绌烘瓕璇嶉〉 } ; floatingCover ; floatingMeta }`
   * 鈥斺€?灏侀潰涓庢瓕鍚?*鎸傚湪 Swiper 涔嬪**锛屽垏椤垫椂鏄?*鍚屼竴涓厓绱?*鍦ㄥ姩锛涙瓕璇嶉〉閭ｄ竴椤垫湰韬槸涓┖澹筹紝
   * 鍙湁 `padding({ top: lyricPadTop() })` 璁╀綅銆?
   *
   * ## 涓変釜涓嶅彉閲?
   *
   * 1. **鍏ㄥ満鍙湁涓€寮犲皝闈?*锛氬皝闈㈤〉閭ｄ唤鐪熷皝闈㈠凡缁忓苟杩涙诞灞傦紙`page 0` 鍙墿
   *    `MiniLyricLinesComponent` 绌哄３锛夛紝"涓や唤灏侀潰鍚屾椂鍙"浠庣粨鏋勪笂灏变笉鍙兘锛?
   *    鎵€浠?*娌℃湁"涓よ€呬簰琛?杩欏洖浜?*锛堟棫闂?`lyricFloatActive()` 宸插垹锛夛紱
   * 2. **闈欐鎬佷袱椤靛悇鑷€愬儚绱犱笉鍙?*锛歚t = 0` 閭ｄ竴绔氨鏄湡灏侀潰鐨勮惤鐐圭煩褰?
   *    锛坄PlayerExpandState.lyricMorph(0)` 澶嶇敤缁灏侀潰 `p=1` 鐨勫悓涓€娈电鐐瑰嚑浣曪級锛?
   *    鎵€浠ヤ氦妫掗偅涓€甯ф病鏈夊彲璺崇殑宸紱
   * 3. **娴眰涓嶅彲鐢ㄥ氨鏁村涓嶅惎鐢?*锛坄lyricFloat()` 涓哄亣锛氬皝闈㈡病閲忓埌 / 瀹藉睆闈㈡澘璧板彟涓€濂楀竷灞€锛?
   *    鈥斺€?浠€涔堥兘涓嶇敾銆乣lyricPadTop()` 涔熸槸 0锛屼笌娌℃湁杩欏涓滆タ鏃朵竴鑷淬€?
   *
   * 鈿狅笍 **姝岃瘝鎬庝箞鐢讳竴涓瓧娌″姩**锛坄LyricsComponent` / `AmllLyricView` 涓嶇锛夛紝
   *   杩欓噷鍙姩"灏侀潰/姝屽悕娴眰鐨勮法椤靛畾浣?涓庢瓕璇嶉〉鐨勯《閮ㄧ暀鐧姐€?
   *
   * ## 鈽呪槄鈽?2026-10-16锛?*椹卞姩鏂瑰紡宸茬収鎼棤鐣岋細杩涘害寮忥紝涓嶆槸琛ラ棿寮?*锛?
   *
   * 杩欓噷鍘熸潵鏈変竴涓?`animateLyricMorph(toLyric)`锛氱敤 `animateTo(360ms, EaseInOut)` 鎶?
   * `lyricMorphT` 浠?0 琛ュ埌 1锛堟垨鍙嶅悜锛夛紝骞剁敱 `.onAnimationStart` 璋冪敤銆?
   * **鐜板湪瀹冨凡鍒犻櫎**锛岀悊鐢憋紙姣忎竴鏉￠兘鎸囧悜鏃犵晫鐨勫師鏂囷級锛?
   *
   * ```
   *   鈶?鏃犵晫**娌℃湁杩欐潯琛ラ棿**锛氬畠鐨勫皝闈綅缃洿鎺ユ槸 `morph.scaleAt/txAt/tyAt(swiperProgress)`
   *      鈥斺€?`swiperProgress` 灏辨槸 Swiper 鐨勬粴鍔ㄨ繘搴︼紙瑙?搂116.2 鐨勯€愭潯瀛楄妭鐮侊級銆?
   *   鈶?`.onAnimationStart` 閭ｆ潯璺甫瀹堝崼銆宨ndex === targetIndex 鈬?璺宠繃銆?
   *      鈬?鍙鍒囬〉涓嶆槸"涓€娆＄湡婊戝姩"锛堢▼搴忓寲鍒囬〉 / 閲嶆寕杞藉垵濮嬮〉涓嶆槸 0 / 椤典笌鐘舵€佷笉涓€鑷达級锛?
   *        鏁村椋炶**姘歌繙涓嶅惎鍔?* 鈬?`lyricMorphT` 鎭?0 鈬?灏侀潰鎭掍负澶у皝闈€?
   *        **鐢ㄦ埛 2026-10-16 鐨勬埅鍥炬鏄繖涓舰鐘?*锛堝ぇ灏侀潰鍙犵潃姝岃瘝锛夈€?
   *   鈶?鍒犳帀涔嬪悗 `t` 鐢?`onSwiperContentDidScroll()` **閫愬抚**鍐欙紙瀹樻柟 SDK锛?
   *      "invoked ... on a frame-by-frame basis"锛夛紝**涓嶄緷璧栦换浣?鍙戠敓杩囦竴娆℃粦鍔?**銆?
   * ```
   *
   * 鈿狅笍 涓庡畠涓€璧蜂笉鍐嶈浣跨敤鐨勮繕鏈夛細`lyricSwiperSettled` / `lyricFlightSettled`锛堥偅瀵?涓ら棶鎻℃墜"锛?
   *    涓?`LYRIC_MORPH_DURATION_MS`銆傚畠浠?*淇濈暀涓哄瓧娈?甯搁噺**锛堝窘鏍囦粛鎵撳嵃鍓嶄袱涓級锛?
   *    浣?*娌℃湁娓叉煋鐢ㄩ€?* 鈥斺€?鑻ョ‘璁や笉闇€瑕侊紝鍙互鏁寸粍鍒犳帀銆?
   * 鈿狅笍 `lyricMorphVisible` / `lyricMorphOpacity` 鐜板湪**鍙寰芥爣璇?*锛屼笉鍐嶉棬浣忎换浣曠粯鍒?
   *    锛堟垜鎶婂叏閮ㄦ秷璐圭偣娓呯偣杩囷細闄や簡璧嬪€肩偣锛屽彧鏈?`refreshDiagText` 鍦ㄨ锛夈€?
   *    鈬?鎵€浠?鏍囧織娌¤澶嶄綅"涓嶄細閫犳垚浠讳綍瑙傛劅闂锛堣繖涓€鐐规槸**娓呯偣鍑烘潵鐨?*锛屼笉鏄帹鏂級銆?
   */

  /**
   * `Swiper.onContentDidScroll` 鐨勫鐞嗗櫒 鈥斺€?**鏃犵晫鐨勮繘搴︽簮**锛堥€愭潯鐓ф妱锛夈€?
   *
   * 鈽呪槄鈽?2026-10-16锛?*淇敤鎴峰疄娴嬨€屾瓕璇嶉〉灏侀潰娌″彉灏忋€佸彔鍦ㄦ瓕璇嶄笂闈€嶇殑鏍?*锛?
   *
   * ## 涓轰粈涔堝繀椤绘湁瀹冿紙鍘熸潵鐨勯┍鍔ㄦ簮鏄敊鐨勶級
   * 鍘熸潵 `lyricMorphT` **鍙?*鐢?`.onAnimationStart` 椹卞姩锛岃€岄偅涓洖璋冨甫涓€涓畧鍗?
   * 銆宍index === targetIndex` 鈬?璺宠繃銆嶃€備袱绉嶆儏鍐典笅杩欎釜瀹堝崼浼氳鏁村椋炶**姘歌繙涓嶅惎鍔?*锛?
   *   路 椤甸潰鍒囨崲涓嶆槸"涓€娆＄湡婊戝姩"锛堜緥濡?swiper 琚▼搴忓寲鍒囬〉銆佹垨閲嶆寕杞芥椂鍒濆椤靛氨涓嶆槸 0锛夛紱
   *   路 閲嶆寕杞藉悗"椤?涓?鐘舵€?涓嶄竴鑷达紙`onAppear` 澶嶄綅杩囩储寮曪級銆?
   * 鈬?`lyricMorphT` 鎭?0 鈬?灏侀潰鎭掍负澶у皝闈紝鑰屾瓕璇嶆鏂囩収鏍锋樉绀?鈬?
   *   **灞忎笂灏辨槸"澶у皝闈㈠彔鐫€姝岃瘝"**锛堢敤鎴?2026-10-16 鎴浘锛夈€?
   *
   * ## 鏃犵晫鐨勫仛娉曪紙`wujie.pa` L190026-190075锛屽畾绋?搂5.2 閫愭潯杞啓锛?
   * ```ts
   *   let p = position;
   *   if (index === 0) {              // 鈽?鍙湪"褰撳墠椤垫槸鎾斁椤?杩欎竴渚у綊涓€鍖?
   *     if (p < 0) { p = -p; }        //    寰€鍓嶆粦鏃?position 涓鸿礋 鈬?缈绘
   *     if (p > 1) { p = 1; }         //    涓婂す鍒?1
   *     this.swiperProgress = p;
   *   }
   *   publishCoverStyle(); syncMotion();
   *   if (this.swiperProgress > 0.5 && !this.chromeHidden) { this.showChrome(); }
   * ```
   *   鈿狅笍 **鍚庡崐娈碉紙姝岃瘝椤甸偅涓€渚э級淇濇寔涓婁竴娆＄殑鍊?* 鈬?**鍋滃湪姝岃瘝椤垫椂 `p` 鎭掍负 1**銆?
   *   鈿狅笍 鏃犵晫閭ｈ竟 `onChange` **涓嶅啓** `swiperProgress`锛堝畠鍙仛 idle/chrome 涓?
   *      `atLyricScreen = (v === 1)`锛夆€斺€?鎵€浠ユ湰鏂规硶鎵嶆槸鍞竴鍐欑偣銆?
   *
   * ## 鎴戜滑鐨勬帴娉曪紙鍚屼竴浠借涔夛級
   * `lyricMorphT` 灏辨槸鏈粨鐨?`swiperProgress`锛? = 灏侀潰椤电 / 1 = 姝岃瘝椤电锛夛細
   *   路 鍏堟妸绱㈠紩璁拌处锛坄onChange` 鍦?绋嬪簭鍖栧垏椤?鏃跺彲鑳戒笉瑙﹀彂锛岃繖閲岄€愬抚閮芥湁鍊硷級锛?
   *   路 鍐嶆妸褰掍竴鍖栧悗鐨?`p` 鍠傜粰 `lyricMorphT`锛?*閫愬抚**锛屼笌鏃犵晫鍚岋級锛?
   *   路 鐒跺悗璋?`syncLyricMorphToPage()` 鍋?闈欐绔偣蹇呴』绛変簬褰撳墠椤?鐨勫厹搴?
   *     锛堣法杩?0.5 鏃跺畠浼氳ˉ涓€娆★紝淇濊瘉涓嶄細鍋滃湪涓ょ涔嬮棿锛夈€?
   *   鈿狅笍 椤哄甫鎶婃棤鐣岄偅鍙?`if (p > 0.5 && !chromeHidden) showChrome()` 涔熸惉杩囨潵 鈥斺€?
   *      瀹冨氨鏄?婊戝埌涓€鍗婃妸鎺у埗鍖哄敜鍑烘潵"鐨勬墜鎰熴€?
   * @param index 褰撳墠椤碉紙0 = 灏侀潰椤碉紝1 = 姝岃瘝椤碉級
   * @param position 鍐呭鐩稿涓昏酱璧风偣鐨勭Щ鍔ㄦ瘮渚嬶紙瀹樻柟 SDK 鍘熸枃锛?
   */
  private onSwiperContentDidScroll(index: number, position: number): void {
    this.diagScrollCount = this.diagScrollCount + 1;
    this.diagScrollLast = `${index}/${position.toFixed(3)}`;
    // 鈹€鈹€ 閫愭潯鐓ф妱鏃犵晫鐨勫綊涓€鍖?鈹€鈹€
    let p: number = position;
    if (index === 0) {
      if (p < 0) {
        p = -p;
      }
      if (p > 1) {
        p = 1;
      }
      this.lyricMorphT = p;
    }
    // 璁拌处"婊氬姩浠嶅湪杩涜"锛堣 `lastScrollAtMs` 鐨勬敞閲婏細钀藉畾蹇呴』璁╀綅缁欓€愬抚杩涘害锛?
    this.lastScrollAtMs = Date.now();
    // 绱㈠紩璁拌处锛坄onContentDidScroll` 閫愬抚閮界粰 `index`锛屾瘮 `onChange` 鏇村彲闈狅級
    if (index !== this.playbackSwiperIndex) {
      this.playbackSwiperIndex = index;
    }
    // 闈欐绔偣鍏滃簳锛氳法杩?0.5 涔嬪悗鎶?`t` 钀藉畾鍒板綋鍓嶉〉瀵瑰簲鐨勭鐐?
    // 锛坄syncLyricMorphToPage()` 鍐呴儴骞傜瓑锛屼笖椋炶涓笉浼氭墦鏂ˉ闂达級
    this.syncLyricMorphToPage('scroll');
    // 鏃犵晫鍚屾锛氭粦杩囧崐绋嬪氨鎶婃帶鍒跺尯鍞ゅ嚭鏉ワ紙`chromeHidden` 涓哄亣鏃舵墠鍞わ級
    if (this.lyricMorphT > 0.5 && !this.chromeCollapsed) {
      this.touchChrome();
    }
  }

  /**
   * 鎶?灏侀潰娴眰椋炶杩涘害'**瀵归綈鍒板綋鍓嶉〉** 鈥斺€?涓嶄緷璧?鍙戠敓杩囦竴娆℃粦鍔?銆?
   *
   * 鈽呪槄鈽?2026-10-16锛?*淇敤鎴峰疄娴嬨€屾瓕璇嶉〉灏侀潰娌″彉灏忓彔鍦ㄦ瓕璇嶄笂闈€?*锛?
   *
   * ## 鐢ㄦ埛鐨勮瀵燂紙鍐冲畾鎬э級
   * 鎴浘閲?*姝屽悕/姝屾墜/姝岃瘝姝ｆ枃鏄帇鍦ㄥ皝闈笂鐨?* 鈥斺€?閭ｆ槸**灏侀潰椤甸偅涓€绔殑娴眰浣嶇疆**
   * 锛堟瓕鍚嶅湪灏侀潰涓嬫柟 `META_GAP_BELOW_COVER(50)`銆佸皝闈㈡槸鏁寸獥閭ｄ竴浠?331锛夈€?
   * 鑰屾瓕璇嶆鏂?*宸茬粡鏄剧ず鍑烘潵浜?*锛堥偅闇€瑕?swiper 鍦ㄧ 2 椤碉級銆?
   * 鈬?涓や欢浜嬪悓鏃舵垚绔嬪彧鏈変竴绉嶈В閲婏細**椤靛垏浜嗭紝娴眰娌¤窡**锛堝窘鏍?`edge=331 t=0.00` 姝ｆ槸瀹冿級銆?
   *
   * ## 涓轰粈涔堝師鏉ョ殑鍐欐硶浼氭紡
   * `lyricMorphT` 鐨勫敮涓€椹卞姩鐐规槸 `.onAnimationStart`锛岃€屽畠甯︿竴涓畧鍗?
   * 銆?*宸茬粡鍦ㄧ洰鏍囬〉浜嗗氨璺宠繃**锛坄index === targetIndex`锛夈€嶃€備簬鏄彧瑕佸嚭鐜?
   * "褰撳墠椤?= 姝岃瘝椤点€佽€?`lyricMorphT` 浠嶆槸 0"杩欑**涓嶄竴鑷寸殑鍒濆鎬?*锛屽氨鍐嶄篃娌℃湁浠讳綍涓滆タ浼氬幓淇瀹冿細
   *   路 杩涙挱鏀惧櫒鏃惰嫢绱㈠紩宸叉槸 1锛堜笂涓€杞?`onAppear` 澶嶄綅杩?0銆佹垨绱㈠紩鏉ヨ嚜鍒锛夆噿 瀹堝崼鐩存帴璺宠繃锛?
   *   路 鑺傜偣閲嶅缓鍚?`onAppear` 鎶?`lyricMorphT` 褰掑埌"褰撳墠椤靛搴旂殑绔偣"鈥斺€?
   *     鑰?*褰撳墠椤?*杩欎釜鍊兼湰韬嫢涓?swiper 瀹為檯鍋滅殑椤典笉涓€鑷达紝褰掑嚭鏉ョ殑灏辨槸閿欑殑绔偣銆?
   *
   * ## 姝ｇ‘鐨勫叧绯伙紙鍗曚竴鐪熸簮锛?
   * ```
   *   playbackSwiperIndex锛堝綋鍓嶉〉锛? 鈹€鈹€鍐冲畾鈹€鈹€鈻? lyricMorphT 鐨?*闈欐绔偣**
   *                                        锛? = 灏侀潰椤甸偅涓€绔紝1 = 姝岃瘝椤甸偅涓€绔級
   *   婊戝姩杩囩▼涓殑琛ラ棿鍙槸"浠庝竴涓鐐硅蛋鍒板彟涓€涓鐐?锛?
   *   鑰?*闈欐鎬?*姘歌繙绛変簬"褰撳墠椤靛搴旂殑绔偣"銆?
   * ```
   * 鈬?鏈柟娉曞氨鏄偅鏉″叧绯荤殑瀹炵幇锛氱珛鍗虫妸 `t` 缃埌褰撳墠椤靛搴旂殑绔偣锛堜笉鍔ㄧ敾锛夈€?
   *   路 涓庢粦鍔ㄤ腑鐨勮ˉ闂?*涓嶅啿绐?*锛氳ˉ闂村彧鍦?`lyricMorphVisible === true`锛堥琛屼腑锛夋椂鎵嶆湁鎰忎箟锛?
   *     鑰屾湰鏂规硶鍙湪"闈欐鎬佷笅鍙戠幇涓嶄竴鑷?鏃惰璋冪敤锛堣璋冪敤鐐癸級銆?
   *   路 骞傜瓑锛氬凡缁忓湪姝ｇ‘绔偣鏃跺啓鍚屼竴涓€硷紝涓嶈Е鍙戜换浣曢噸缁樺樊寮傘€?
   *
   * 鈿狅笍 璋冪敤鐐癸細`aboutToAppear()`锛堥〉闈㈡寕杞芥椂瀵归綈涓€娆★級涓庡唴瀹瑰眰 `.onAppear()`
   *    锛堣妭鐐瑰嚭鐜版椂瀵归綈涓€娆★級銆?*涓嶈**鏀捐繘婊戝姩鍥炶皟閲岋紙閭ｄ細鎵撴柇琛ラ棿锛夈€?
   * @param reason 鍙敤浜庢棩蹇楋紙`boot` / `appear`锛?
   */
  private syncLyricMorphToPage(reason: string): void {
    const want: number = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
    // 鈽呪槄鈽?2026-10-16锛?*璁╀綅缁欓€愬抚杩涘害**锛岃 `lastScrollAtMs` 鐨勬敞閲婏級锛?
    //   `onContentDidScroll` 姝ｅ湪閫愬抚鍐?`lyricMorphT` 鏃讹紝杩欓噷**涓嶈钀藉畾** 鈥斺€?
    //   鍚﹀垯涓よ€呮瘡甯т簰鐩告姠鍊硷紙婊戝埌涓€鍗婅涓€鎶婅鍒扮鐐?鈬?鐢婚潰璺筹級銆?
    //   鈿狅笍 `boot` 閭ｆ**蹇呴』鏀捐**锛堥〉闈㈡寕杞芥椂杩樻病鏈変换浣曟粴鍔紝`lastScrollAtMs` 涓?0锛夈€?
    if (reason !== 'boot' && Date.now() - this.lastScrollAtMs < PlaybackPage.SCROLL_SETTLE_WINDOW_MS) {
      return;
    }
    if (this.lyricMorphVisible && Math.abs(this.lyricMorphT - want) < 0.999) {
      // 椋炶涓笖杩樻病鍒扮鐐?鈬?鍒墦鏂ˉ闂达紙杩欐潯鍙湪鏋佺鏃跺簭涓嬫墠鍙兘鍛戒腑锛?
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
   * 鏀跺熬锛歋wiper 鑷繁鐨勫垏鎹㈠姩鐢讳笌娴眰椋炶**閮界粨鏉?*涔嬪悗鎵嶅嵏鎺?椋炶涓?杩欎竴妗ｃ€?
   *
   * 鈿狅笍 杩欓噷**涓嶆槸**鎶婂皝闈竴鍒€鍒囨帀锛氭诞灞傛槸**甯搁┗**鐨勶紝钀戒綅鍚庝粛鐢?`playbackSwiperIndex`
   * 鍒嗘敮鍐冲畾瀹冭惤鍦ㄥ摢涓鐐癸紙姝岃瘝椤甸潤姝㈡€佷粛鐒惰鏄剧ず閭ｅ紶灏忓皝闈?+ 姝屽悕锛夈€?
   * 鍘熸潵鐨勫啓娉曟槸 `lyricMorphVisible = false` 鏃犳潯浠跺啓姝?鈬?鏁村姝岃瘝椤靛皝闈㈠舰鍙樻槸鍏崇潃鐨勩€?
   *
   * ## 鈽呪槄 2026-10-16锛?*宸插垽瀹氫负姝讳唬鐮侊紝淇濈暀涓嶅垹**锛?
   *
   * 涓や釜鐞嗙敱锛岄兘鏄竻鐐瑰嚭鏉ョ殑锛?
   * 1. 鏈嚱鏁拌姹?`lyricSwiperSettled && lyricFlightSettled` **涓ら棶閮藉埌浣?*锛?
   *    鑰岀疆 `lyricFlightSettled = true` 鐨?*鍞竴**鍦版柟鍘熸潵鍦?`animateLyricMorph()` 鐨勬敹灏?
   *    `setTimeout` 閲?鈥斺€?閭ｄ釜鏂规硶鏈疆宸查殢"鏀硅繘搴﹂┍鍔?涓€璧峰垹闄わ紙瑙佹枃浠朵笂鏂归偅娈佃鏄庯級
   *    鈬?`lyricFlightSettled` 姘歌繙鏄?`false`锛堥櫎闈?`syncLyricMorphToPage()` 钀藉畾鏃剁疆鐪燂紝
   *      浣嗛偅鏉¤矾涓?`lyricMorphVisible` 宸茬粡琚畠鑷繁缃垚 `false`锛?
   *    鈬?鏈嚱鏁?*蹇呯劧鍦ㄧ涓€涓?`if` 澶勮繑鍥?*銆?
   * 2. 鏈嚱鏁板彧鍐?`lyricMorphVisible` / `lyricMorphOpacity` 涓や釜瀛楁锛?
   *    鑰岃繖涓や釜瀛楁**鐜板湪鍙寰芥爣璇?*锛堝叏閮ㄦ秷璐圭偣宸叉竻鐐癸級鈬?鍗充娇瀹冭窇鍒颁簡涔熸病鏈夋覆鏌撳奖鍝嶃€?
   *
   * 鈬?淇濈暀鑰屼笉鍒犵殑鐞嗙敱锛氬畠鏄?涓ら棶鎻℃墜"閭ｅ璁捐鐨勬敹灏剧锛?*鑻ュ皢鏉ユ仮澶嶈ˉ闂撮┍鍔?*
   *    锛堜緥濡傚彂鐜拌繘搴﹂┍鍔ㄥ湪鏌愪釜鏈哄瀷涓婁笉鍙敤锛夐渶瑕佸畠涓€璧锋仮澶嶏紱
   *    鍒犱簡灏卞緱浠?git 鍘嗗彶閲屾崬銆?*瀹冧笉浼氭湁瀹?*锛堝繀鐒舵棭閫€銆佷笖鍙啓寰芥爣璇荤殑瀛楁锛夈€?
   * 鈿狅笍 鑻ョ‘璁よ繘搴﹂┍鍔ㄧǔ瀹氾紝鍙互鎶婂畠 + `lyricSwiperSettled` / `lyricFlightSettled` /
   *    `LYRIC_MORPH_DURATION_MS` **鏁寸粍鍒犳帀**銆?
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
   * @returns 娴眰閲屽皝闈㈢殑涓€甯х煩褰紙vp锛岀獥鍙ｅ潗鏍囷級銆?
   *
   * 鈿狅笍 2026-10-15锛堢 2 鍧椔疯鐩栧眰缁熶竴锛?*鍒犳帀浜嗕笁涓凡姝荤殑绉佹湁鏂规硶**锛?
   *   路 `lyricFloatActive()` 鈥斺€?瀹冨師鏉ユ槸娴眰鐨勯棬锛堝彧鍦?椋炶涓?姝岃瘝椤?鎵嶇敾锛夛紱
   *     瑕嗙洊灞傛敼鎴?*甯搁┗**涔嬪悗娌℃湁浠讳綍璋冪敤鐐广€?
   *   路 `lyricFloatMetaOpacity()` 鈥斺€?鍘熸潵璁╂瓕鍚嶅湪 `t=0` 瀹屽叏閫忔槑锛堥偅涓€鍒诲皝闈㈤〉閭ｄ唤姝屽悕
   *     鐢?`MusicPlayInfoBlock` 鐢伙級锛涢〉 0 涓嶅啀鐢诲皝闈?姝屽悕涔嬪悗瀹冩亽涓?1銆?
   *   路 `lyricFloatMetaWidth()` 鈥斺€?姝屽悕鍧楀師鏉ユ按骞冲眳涓€佺敤瀹冪畻鍧楀锛?
   *     鐜板湪鏄?*涓€妯**锛堝乏鍐呰竟璺濈敱 `lyricMetaLeftInset()` 缁欙級锛屼笉鍐嶉渶瑕佸畠銆?
   *   鐩稿叧娉ㄩ噴閲屽嚒杩樺啓鐫€"闂ㄥ湪 `lyricFloatActive()`"鐨勫湴鏂归兘宸插氨鍦版敼姝ｃ€?
   */
  private lyricFloatRect(): LyricMorphRect {
    return this.expandState.lyricMorph(this.lyricMorphT);
  }

  /**
   * @returns 灏侀潰閭ｄ竴灞?*瀹為檯瑕佸啓杩?`.position()` 鐨勭煩褰?*锛坴p锛夈€?
   *
   * 鈽呪槄鈽?2026-10-16锛?*鎾ゅ洖鎴戜笂涓€鐗堢殑閫嗗彉鎹?*锛岀敤鎴峰疄娴嬨€屽皝闈㈡槸椋炲埌灞忓箷澶栥€嶏級锛?
   *
   * 涓婁竴鐗堟垜鍦ㄨ繖閲岃皟 `coverLocalRectFor()` 鍋?灞忓箷鍧愭爣 鈫?瀹瑰櫒鏈湴鍧愭爣"鐨勯€嗗彉鎹紝
   * 鍓嶆彁鏄?**`.scale()` 缁曞鍣ㄤ腑蹇?*銆傜湡鏈轰笂缁撴灉鏄皝闈?*椋炲嚭灞忓箷**銆?
   *
   * 鈿狅笍 杩欎釜鍓嶆彁鍦ㄦ湰浠?*鏃╁氨鏈夎繃涓€娆＄湡鏈哄弽璇?*锛坄morphCoverRectAt()` 鐨勬敞閲娿€?
   *   `LyricFloatLayer` 椤堕儴"鈿狅笍 2026-10-15 鍒绘剰涓嶆敼"閭ｄ竴娈碉級锛?
   *   > 銆岄€嗗彉鎹㈠洖椤靛唴鍧愭爣 鈥斺€?鐪熸満缁撴灉"**灏侀潰璺戝埌宸︿笂瑙?*"锛堣鏄?`.scale()` 鐨勬灑杞?
   *   >   **涓嶆槸鎴戜互涓虹殑瀹瑰櫒涓績**锛夆噿 璇ユ柟妗堜綔搴燂紝**鍒啀璇?*銆傘€?
   *   鈬?鎴戣繖娆＄瓑浜?*鍘熷湴閲嶈俯浜嗕竴閬?*锛屾暀璁杩?`RzdMusic璁板繂.md` 搂86銆?
   *
   * ## 鐜板湪 = 绾嚑浣曘€?*涓嶅仛浠讳綍鍧愭爣绯绘崲绠?*锛堝氨鏄敤鎴风‘璁よ繃"鐜板湪姝ｅ父浜?鐨勯偅涓€鐗堬級
   *
   * ```
   *   灏哄 / 浣嶇疆 / 鍦嗚涓€寰嬪彇 lyricMorph(t)锛? 鏃犵晫 CoverMorph 鐨勮緭鍑猴級
   *   鐩存帴鍐欒繘 .position() / .width() / .borderRadius()
   * ```
   * 鏈眰鎸傚湪褰㈠彉瀹瑰櫒**鍐呴儴**锛屾墍浠ュ舰鍙樹腑瀹冪殑**瀹為檯**灞忓箷浣嶄細琚鍣ㄥ彉鎹㈡尓璧?
   * 锛坄y' 鈮?t路y`锛岃 `LyricFloatLayer` 椤堕儴閭ｆ鎺ㄥ锛夆€斺€?杩欐潯"钀戒綅鏃舵纭€佸舰鍙樹腑鍋?
   * 鐨勫彛寰?*鐢ㄦ埛鍦ㄧ湡鏈轰笂楠岃繃銆佽鎰熷彲鎺ュ彈**锛堝皝闈㈣窡鐫€瀹瑰櫒涓€璧风缉鍚戣糠浣犳潯锛夈€?
   * 鈿狅笍 瀹冩垚绔嬬殑鍓嶆彁鏄?`t = 1`锛堣惤浣嶏級鏃跺鍣ㄦ槸鎭掔瓑鍙樻崲 鈥斺€?鑰岄偅姝ｆ槸闈欐鎬侊紝鎭掓垚绔嬨€?
   */
  private coverLocalRect(): LyricMorphRect {
    return this.lyricFloatRect();
  }

  /** 涓婁竴娆?`RzdCoverLocal` 鐨勮惤浣嶇鍚嶏紙鑺傛祦鐢紝鍙湪鐪熺殑鍙樹簡鎵嶆墦锛夈€?*/
  private lastCoverLocalLog: string = '';
  /** `RzdCoverLocal` 鐨勯噰鏍疯妭娴侊紙ms锛屽舰鍙樻椂姣忓抚閮戒細鍙橈紝澶瘑浼氬埛灞忥級銆?*/
  private static readonly COVER_LOCAL_LOG_MS: number = 100;
  private lastCoverLocalAtMs: number = 0;

  /**
   * 鈽呪槄鈽?2026-10-16 鏂板璇婃柇锛?*灏侀潰钀戒綅鐨勬/鍙嶅彉鎹㈠璐?*銆?
   *
   * ## 瀹冨垽浠€涔?
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdCoverLocal'
   *   鈬?RzdCoverLocal t=鈥?s=鈥?tx=鈥?ty=鈥?screen=(x,y,w,h,r) local=(x,y,w,h,r)
   * ```
   * 路 `s = 1 / tx = ty = 0`锛堥潤姝㈡€侊級鈬?涓や釜鐭╁舰蹇呴』**閫愬瓧鐩稿悓**锛堝弽鍙樻崲鏄亽绛夌殑锛夛紱
   * 路 褰㈠彉涓?鈬?`local` 蹇呴』**杩滃ぇ浜?* `screen`锛堝洜涓鸿琚?`s` 鍘嬪洖鍘伙級锛?
   *   涓?`local.x/y` 鍙兘涓鸿礋锛堝皝闈㈠湪瑁佸壀绐楀彛涔嬪鐨勯偅涓€鎴紝杩欐槸姝ｅ父鐨勶級锛?
   * 路 **鍒ゆ嵁**锛氭妸 `s / tx / ty` 涓?`screen` 浠ｈ繘瀹瑰櫒鍙樻崲
   *   `y_灞?= H/2 + (y_鏈?鈭?H/2)s + d` 搴旇繕鍘熷嚭 `screen.y` 鈥斺€?鑻ヨ繕鍘熶笉鍑烘潵锛?
   *   璇存槑瀹瑰櫒鐨勬灑杞?灏哄鍋囪涓庡疄鐜颁笉绗︼紙閭ｆ椂瑕佹敼鐨勬槸 `coverHostH()`锛屼笉鏄皝闈級銆?
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

  // 鈿狅笍 2026-10-16锛歚SQUASH_MIN` / `squashWrapHVp()` / `squashWrapOffsetYVp()` **宸插垹闄?*銆?
  //
  // 瀹冧滑鏄垜涓婁竴鐗堜负浜嗚"鑳屾櫙涔熻窡鐫€寮?鑰屽姞鐨勪竴灞傝ˉ鍋垮鍣?
  // 锛坄.height(winH 脳 k)` + `.offset({y: 鈭抴inH(1鈭択)/2})` + `.scale({y: k})`锛夈€?
  // 鏈疆鎶婃棤鐣岀殑**灞傜骇**璇婚€氫箣鍚庯紝閭ｄ釜琛ュ伩**鏁翠釜涓嶉渶瑕佷簡**锛?
  // 鏃犵晫鐨?`MeshCoverBg` 灏卞湪**琚?`scale/translate/clip` 鐨勯偅涓?Stack 閲岄潰**
  // 锛坄wujie.pa` 191388 閭ｄ釜 `PLAYER_ROOT_ID` 瀹瑰櫒锛岃 `build()` 閲岄偅娈靛鍣ㄦ爲锛夛紝
  // 鈬?瀹冨ぉ鐒惰窡鐫€瀹瑰櫒涓€璧风缉銆佷竴璧疯瑁併€佷篃澶╃劧鍦ㄨ矾鐢卞３閭ｆ潯 `morphSquashY` 鐨勪綔鐢ㄥ煙閲屻€?
  // 鈬?鑳屾櫙宸叉寜鏃犵晫鎼洖瀹瑰櫒鍐呴儴锛岃繖涓€灞傝ˉ鍋胯繛鍚屽畠鐨勫父閲忎竴璧峰垹鎺夈€?

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鎺у埗鍖鸿嚜鍔ㄦ敹璧?鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鈽呪槄鈽?鐜板満鑷瘉寰芥爣锛?*涓嶄緷璧?hdc**锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // ## 涓轰粈涔堝姞瀹?
  //
  // 銆岀偣鍑绘墦寮€ / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖娌℃湁灏侀潰鍔ㄧ敾銆嶈繖鏉￠棶棰橈紝鏈疆宸茬粡鏀逛簡 3 澶?
  // 锛埪?2 鑳屾櫙涓嶉€忔槑搴?/ 搂93 鎸傝浇鍒ゆ嵁 / 搂94 缁堢偣閿氱偣閲忔祴闂級锛屼絾**鐢ㄦ埛涓嶈兘鐢?hdc**锛?
  // 鎴戞嬁涓嶅埌 `RzdCoverLocal` / `RzdMorphOwnership` 閭ｄ簺鏃ュ織 鈬?鍙兘闈?鏀逛簡鍐嶈鐢ㄦ埛瑁?锛?
  // 鑰岃繖鏉￠摼涓婃湁 5~6 涓垽鏂紝**鐩叉敼鐨勪唬浠峰凡缁忚璇佹槑鏋佸ぇ**锛埪?6~搂94 鍏?8 杞級銆?
  //
  // 鈬?鍔犱竴涓?*椤甸潰涓婄洿鎺ユ樉绀哄垽鎹?*鐨勫皬寰芥爣锛氱敤鎴风偣寮€鎾斁鍣ㄥ悗鎶婂睆涓婇偅涓よ鏁板瓧蹇靛嚭鏉ワ紝
  //   鎴戝氨鑳戒竴娆″畾浣嶅埌鍏蜂綋鍝竴涓垽鏂负鍋囥€?*瑁呬竴娆￠《鍗佹鐩叉敼銆?*
  //
  // ## 鐢ㄦ硶锛堢敤鎴蜂晶锛?
  // ```
  //   路 杩炵偣鎾斁椤甸《閮?3 娆★紙鐐?杩斿洖"寰€鍙充竴鐐归偅鐗囩┖鐧斤紝鎴栫偣姝屽悕/姝屾墜閭ｄ竴琛岋級
  //   路 灞忎笂鍑虹幇涓€灏忓潡榛戝簳鐧藉瓧锛屽舰濡傦細
  //       V 8f3a2c1 sess=1 usable=1 cont=1 clip=1 scale=0.082 p=0.000
  //       real=0 clone=1 snap=330/56 end=328/328 op=0.040 stage=1 drv=2
  //   路 鎶婅繖涓よ蹇电粰鎴戯紙鎴栨埅鍥撅級鍗冲彲锛涘啀鐐?3 娆″彲鍏虫帀
  // ```
  // 鈿狅笍 **瀹冨彧鍦ㄨ繛鐐?3 娆′箣鍚庢墠鍑虹幇** 鈬?姝ｅ父鎯呭喌涓嬬敤鎴峰畬鍏ㄧ湅涓嶅埌锛屼笉褰卞搷瑙傛劅銆?
  // 鈿狅笍 绾彧璇伙細涓嶅啓浠讳綍涓庡姩鐢绘湁鍏崇殑鐘舵€侊紙鍙啓 `diagBadgeOn` / `diagText` 涓や釜鏈〉瀛楁锛夈€?
  //
  // 鈽呪槄鈽?2026-10-17锛?*寮€鍏虫敼鎴愯法瀹炰緥璁板繂** 鈥斺€?鐩存帴涓轰簡"灏戣鐢ㄦ埛鐧借窇涓€杞?锛夛細
  //   寰芥爣绗崄涓夎璇荤殑鏄?*闈欐€?*浜嬩欢鏃ュ織锛堜笂涓€娆″叧闂殑鍏ㄨ繃绋嬶級锛岃€岃瀹屽畠鐨勫Э鍔挎槸
  //   銆屽叧闂?鈫?**閲嶆柊鎵撳紑鎾斁椤?* 鈫?鎵撳紑寰芥爣 鈫?鎴浘銆嶃€傚彲 `diagBadgeOn` 鍘熸潵鏄?*瀹炰緥灞€閮?*鐨?
  //   鈬?姣忔閲嶆柊鎵撳紑閮藉洖鍒?鍏?锛岀敤鎴峰緱**鍐嶈繛鐐?3 娆?*鎵嶇湅寰楀埌 鈥斺€?澶氫竴姝ュ氨澶氫竴娆¤涓嶅埌鐨勯闄┿€?
  //   鈬?鍔犱竴涓潤鎬侀暅鍍忥細**寮€涓€娆″氨涓€鐩存槸寮€鐨?*锛堢洿鍒板啀杩炵偣 3 娆″叧鎺夛紝鎴栬繘绋嬮噸鍚級銆?
  private static diagBadgeOnStatic: boolean = false;
  @Local private diagBadgeOn: boolean = PlaybackPage.diagBadgeOnStatic;
  @Local private diagText: string = '';
  private diagTapCount: number = 0;
  private diagTapLastMs: number = 0;
  /**
   * 鈽?鑷瘉璁℃暟锛堝彧缁欏窘鏍囩敤锛屼笉褰卞搷浠讳綍閫昏緫锛夛細
   * 路 `diagRemeasureTries` 鈥斺€?`onAppear` 閲岄偅娆″嚑浣曡ˉ閲忚璋冪敤浜嗗嚑娆★紱
   * 路 `diagOverlayKicks`   鈥斺€?鍏朵腑"琛ラ噺鎴愬姛鍚庨『鎵嬭捣浜嗘诞灞傝ˉ闂?鍑犳銆?
   * ```
   *   涓よ€呴兘 0 鈬?閭ｆ浠ｇ爜鏍规湰娌¤窇鍒帮紙`onAppear` 璧颁簡鍒殑鍒嗘敮锛?
   *   1 / 1    鈬?琛ラ噺涓庤捣妫掗兘鍙戠敓浜?鈬?鑻ュ皝闈粛涓嶉锛岄棶棰樺湪鍑犱綍鍊硷紙鐪?snap / end锛?
   *   1 / 0    鈬?琛ラ噺璺戜簡浣?`morphUsable` 浠嶄负鍋?鈬?鐪?usable / end 涓ゅ垪
   * ```
   */
  private diagRemeasureTries: number = 0;
  private diagOverlayKicks: number = 0;

  /**
   * 鈽呪槄鈽?2026-10-16锛?*Swiper 鍥炶皟瀹炲弬璁板綍** 鈥斺€?淇?姝岃瘝椤靛皝闈㈡病鍙樺皬"鐨?*鍐冲畾鎬?*璇绘暟锛?
   *
   * 涓轰粈涔堝繀椤昏瀹冿細涓婁竴鎵规垜鍦ㄨ繖鏉￠摼涓婄敤**闈欐€佹帹鐞?*鍦ㄤ袱绉嶅亣璁句箣闂存憞鎽?鈥斺€?
   * ```
   *   鍋囪 A锛歚.onAnimationStart` **鏍规湰娌¤Е鍙?*锛堝垏椤垫病璧版粦鍔ㄥ洖璋冿級
   *   鍋囪 B锛氳Е鍙戜簡浣?*琚畧鍗尅鎺?*锛坄index === targetIndex`锛?
   * ```
   * 涓よ€呯殑淇硶**瀹屽叏涓嶅悓**锛圓 瑕佸湪鎸傝浇/鍒囬〉鏃惰ˉ涓€娆″榻愶紱B 瑕佹敼瀹堝崼鐨勫垽鎹級锛?
   * 鑰屽彧鏈夌湡鏈鸿鏁拌兘鍒嗚鲸銆傗噿 璁颁笅鏉ワ紝涓€娆″畾浣嶃€?
   *
   * 璇绘硶锛堝窘鏍?*绗叓琛?*锛夛細
   * ```
   *   ast=<index>-<target>   渚?`ast=0-1` = 浠庣 0 椤垫粦鍚戠 1 椤碉紙姝ｅ父鍒囧埌姝岃瘝椤碉級
   *                          `ast=-1--1` = **杩欎釜鍥炶皟涓€娆￠兘娌¤繘鏉ヨ繃**锛堝亣璁?A 鎴愮珛锛?
   *   skp=<瀹堝崼鎸℃帀鐨勬鏁?   > 0 鑰?ast 鏈夊€?鈬?鍋囪 B 鎴愮珛锛堝洖璋冭繘浜嗕絾琚?`index===target` 鎸★級
   *   aend=<index>/<娆℃暟>    `onAnimationEnd` 鏈€鍚庝竴娆＄殑瀹炲弬涓庢鏁?
   *   chg=<index>/<娆℃暟>     `onChange` 鏈€鍚庝竴娆＄殑瀹炲弬涓庢鏁帮紙swiper 鑷繁璁や负鍋滃湪鍝竴椤碉級
   * ```
   */
  private diagAnimStart: string = '-1--1';
  private diagAnimSkip: number = 0;
  private diagAnimEnd: string = '-';
  private diagAnimEndCount: number = 0;
  private diagChg: string = '-';
  private diagChgCount: number = 0;
  /**
   * 鈽呪槄鈽?2026-10-16锛歚onContentDidScroll` 鐨?*璋冪敤璁℃暟涓庢渶鍚庝竴娆″疄鍙?* 鈥斺€?杩欐槸鏈疆鐪熸鐨勫垽鎹€?
   *
   * 璇绘硶锛堝窘鏍?*绗叓琛?*鐨?`scr=`锛夛細
   * ```
   *   scr=<娆℃暟> last=<index>/<position>
   *     scr=0        鈬?杩欎釜鍥炶皟**涓€娆￠兘娌¤Е鍙?*锛堥偅 SDK 渚у氨娌℃湁杩涘害婧愬彲鐢紝瑕佹崲鏂规锛?
   *     last=0/0.37  鈬?姝ｅ湪浠庡皝闈㈤〉婊戝悜姝岃瘝椤碉紙`position` 鏄Щ鍔ㄦ瘮渚嬶級
   *     last=0/1.000 鈬?鈽?**鍋滃湪姝岃瘝椤?*锛堟棤鐣岀殑褰掍竴鍖栨妸瀹冨す鍒?1锛屼笖姝ゅ悗涓嶅啀鏇存柊锛?
   * ```
   * 鏃犵晫鐨勭瓑浠风墿灏辨槸 `swiperProgress`锛涘畠鏄?goal 绗?1 鏉℃寚瀹氱殑**杩涘害婧?*銆?
   */
  private diagScrollCount: number = 0;
  private diagScrollLast: string = '-';
  /**
   * 鈽呪槄鈽?2026-10-16锛氬唴瀹瑰眰 `.onAppear()` **璧颁簡鍝潯鍒嗘敮** 鈥斺€?瀹氫綅"鍏抽棴鍚庣獊鐒跺張鏀惧睍寮€"銆?
   *
   * 鍙栧€硷細
   * ```
   *   '-'        = 杩欎釜鍥炶皟杩樻病杩涜繃
   *   'morph'    = 璧颁簡褰㈠彉鍒嗘敮锛坢orphContainerActive || morphSessionStarted锛夆渽 姝ｅ父
   *   'intro'    = 璧颁簡鍏滃簳鍒嗘敮骞惰捣浜?playExpandIntro()  鈫?鈽?鑻ュ嚭鐜板湪鍏抽棴杩囩▼涓紝灏辨槸鏈?bug
   *   'skipClose'= 璧颁簡鍏滃簳鍒嗘敮浣嗚"姝ｅ湪鍏抽棴"閭ｉ亾闂ㄦ嫤涓?鉁咃紙鏈疆鏂板鐨勯棬锛?
   * ```
   * 鍒よ锛氬叧闂悗鑻ョ湅鍒?`intro` 鈬?闂ㄦ病鎷︿綇锛堣鍐嶆煡鍒ゆ嵁锛夛紱鐪嬪埌 `skipClose` 鈬?闂ㄧ敓鏁堜簡銆?
   */
  private diagAppearBranch: string = '-';
  /**
   * 鈽呪槄鈽?2026-10-16锛?*鑳屾櫙灞傝嚜宸辩殑瀹炴祴鐭╁舰**锛堢獥鍙ｅ潗鏍囷紝vp锛夆€斺€?瀹氫綅"鏈夎儗鏅絾楂樺害鐗逛綆"銆?
   *
   * 涓轰粈涔堝崟鐙噺瀹冿細鑳屾櫙灞傦紙`MeshCoverBg` 閭ｄ釜瀹夸富 `Column`锛夋槸**褰㈠彉瀹瑰櫒鐨勫瓙鑺傜偣**锛?
   * 鑰屼笖鏄?`.height('100%')` + `.position({x:0,y:0})` 鈬?瀹冪殑楂樺害**瀹屽叏鐢卞鍣ㄥ喅瀹?*銆?
   * 鐢ㄦ埛鎶ャ€屾湁鑳屾櫙浣嗘槸**楂樺害鐗逛綆**銆嶆椂锛屼笁绉嶅彲鑳藉繀椤诲垎杈細
   * ```
   *   鈶?瀹瑰櫒鐨勮鍓獥鍙ｆ湰鏉ュ氨鏄偅涔堝皬锛坄clipH` 璇绘暟锛夆噿 姝ｅ父锛屾槸鍔ㄧ敾涓
   *   鈶?鑳屾櫙灞傜殑鐩掑瓙琚帇鎴愪簡鏋佸皬锛堟湰璇绘暟 `bgH`锛? 鈬?甯冨眬闂锛堢櫨鍒嗘瘮閾炬柇浜嗭級
   *   鈶?鑳屾櫙灞傜洅瀛愭甯镐絾琚?*娣℃帀**浜嗭紙`bg` 涓嶉€忔槑搴︼級鈬?鏄?`backgroundRevealOpacity()` 鐨勪簨
   * ```
   * 鐢?`MeshCoverBg` 鎵€鍦ㄥ涓?`Column` 鐨?`.onAreaChange()` 鍐欙紙鍙锛屾棤鍓綔鐢級銆?
   * 鈿狅笍 `onAreaChange` 缁欑殑鏄?*甯冨眬鍑犱綍**锛堜笉鍚鍏?transform锛夆噿 閰嶅悎寰芥爣绗竴琛岀殑
   *    `scale` 鎵嶈兘杩樺師"灞忎笂澶氶珮"锛? `bgH 脳 scale`锛夈€?
   */
  @Local private diagBgBox: string = '-';
  /**
   * 涓婁竴娆?`onContentDidScroll` 鐨勬椂闂存埑锛坢s锛夆€斺€?**鐢ㄦ潵璁?钀藉畾"璁╀綅缁?閫愬抚杩涘害"**銆?
   *
   * 鈽呪槄鈽?2026-10-16锛堣繖鏄湰杞繀椤诲鐞嗙殑涓€澶?*鐪熷疄鍐茬獊**锛夛細
   * `onContentDidScroll` 閫愬抚鍐?`lyricMorphT = p`锛堢収鎼棤鐣岋級锛?
   * 鑰?`syncLyricMorphToPage()` 鏄?鎶?`t` 钀藉畾鍒板綋鍓嶉〉瀵瑰簲鐨勭鐐?锛堜竴鎶婅鍒颁綅锛夈€?
   * 涓よ€呰嫢鍚屾椂鐢熸晥灏变細**姣忓抚浜掔浉鎶㈠€?*锛堟粦鍒颁竴鍗婅钀藉畾鍒?1 鈬?鐢婚潰璺筹級銆?
   * 鈬?鍒ゆ嵁锛?*鏈€杩?120ms 鍐呮湁婊氬姩鍥炶皟 鈬?杩欎竴娈电敱"杩涘害"褰撳锛屼笉璁歌惤瀹?*銆?
   *   锛?20ms 鈮?7 甯э紱鎵嬫寚鎶捣鍚?swiper 鐨勬儻鎬ф粴鍔ㄤ竴鍋滐紝钀藉畾灏辫兘鎺ョ鏀跺熬銆傦級
   *   鈿狅笍 杩欎釜鏃堕棿绐?*鍙湪"涓ょ椹卞姩鏂瑰紡骞跺瓨"鏃舵墠鏈夋剰涔?*锛屽畠涓嶆槸鍔ㄧ敾鏃堕暱銆佷篃涓嶆槸鑷紪鍙傛暟 鈥斺€?
   *      瀹冩槸"鍒ゅ畾婊氬姩鏄惁浠嶅湪杩涜"鐨勯噰鏍风獥锛堜笌 `PULL_ANCHOR_RETRY_MS = 32` 鍚屼竴鎬ц川锛夈€?
   */
  private lastScrollAtMs: number = 0;

  /**
   * 椤堕儴閭ｅ潡"闅愬舰鐑尯"鐨勭偣鍑昏鏁帮細**杩炵偣 3 娆?*寮€鍏宠嚜璇佸窘鏍囥€?
   *
   * 鐢?800ms 鐨勭獥鍙ｅ垽瀹?杩炵偣"锛涢棿闅旇秴杩囧氨閲嶆柊璁℃暟銆?
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
      // 鈽?2026-10-17锛氳法瀹炰緥璁板繂锛堣 `diagBadgeOnStatic` 閭ｆ锛夈€?*蹇呴』鎴愬鍐?*锛?
      //   鍙涓嶅啓 = 寮€鍏虫案杩滃洖鍒?false锛堥偅姝ｆ槸"鐢ㄦ埛鐧借窇涓€杞?鐨勫舰鐘讹級銆?
      PlaybackPage.diagBadgeOnStatic = this.diagBadgeOn;
    }
  }

  /**
   * 鎶婂綋鍓嶉偅涓€涓插垽鎹嫾鎴愪袱琛屽瓧绗︿覆锛?*鍙湪寰芥爣寮€鐫€鏃惰皟鐢?*锛夈€?
   *
   * 姣忎竴椤归兘瀵瑰簲鏈疆鏀硅繃鎴栨€€鐤戣繃鐨勪竴涓垽鏂紝鍛藉悕涓庝唬鐮佸瓧娈典竴涓€瀵瑰簲锛?
   * ```
   *   sess   = morphSessionStarted        锛埪?3锛氬３灞傚凡璧蜂細璇濓級
   *   usable = morphUsable                锛堝嚑浣曟槸鍚﹂噺榻愶級
   *   cont   = morphContainerActive()     锛堝鍣ㄦ槸鍚﹀湪褰㈠彉鍩燂級
   *   clip   = morphClipping()            锛堣鍓槸鍚︾敓鏁堬級
   *   scale  = morphScale                 锛? = 鎭掔瓑锛?.08 = 宸插帇鍒拌捣鐐癸級
   *   p      = morphP                     锛堝舰鍙樿繘搴︼級
   *   real   = realCoverVisible()         锛堟挱鏀鹃〉鐪熷皝闈㈡槸鍚︾敾锛?
   *   clone  = morphOverlayBridging()     锛堝３灞傜画椋炲皝闈㈡槸鍚︾敾锛?
   *   snap   = snapStartW / miniSize      锛堣捣鐐癸細缁灏侀潰瀹藉害 / 杩蜂綘鏉″皝闈級
   *   end    = endCoverSize / endCoverH   锛堢粓鐐癸細鎾斁椤靛皝闈級
   *   op     = backgroundRevealOpacity()  锛堣儗鏅笉閫忔槑搴︼級
   *   stage / drv = morphStage / morphDrive
   * ```
   * 鈿狅笍 鍒よ瑕佺偣锛堝啓鍦ㄨ繖閲岋紝鐢ㄦ埛蹇垫暟瀛楁椂鎴戣嚜宸卞鍙凤級锛?
   * 路 `clone=1` 涓?`real=0` 鈬?灏侀潰璇ョ敱澹冲眰娴眰鐢伙紱鑻ュ睆涓婃病鏈?鈬?鐪?`snap/end` 鏄惁闈為浂锛?
   * 路 `clone=0` 涓?`real=1` 鈬?灏侀潰璇ョ敱鎾斁椤电敾锛堥偅鏃跺畠鍦ㄥ鍣ㄩ噷锛屼細琚缉鏀撅級锛?
   * 路 `clone=0` 涓?`real=0` 鈬?**涓よ竟閮戒笉鐢?*锛堝氨鏄?瀹屽叏娌℃湁灏侀潰"鐨勯偅涓舰鐘讹級锛?
   * 路 `op=0.04` 涓?`p鈮?` 鈬?鑳屾櫙鍒氳捣姝ワ紱`op=1` 鈬?宸叉弧銆?
   */
  private refreshDiagText(): void {
    if (!this.diagBadgeOn) {
      return;
    }
    const e = this.expandState;
    // 鈽?2026-10-16锛堢増鏈爣璁?`b41d7e9` 鈫?`c52e0a7` 鈫?`d73f1b8`锛夛細閭ｄ竴杞姞鐨勬槸
    //   goal 绗?2 鏉＄殑鍦嗚鑷瘉浣嶏紙绗洓琛?`rad`/`radVis`/`edge`/`t`锛変笌
    //   "鍗歌浇鏀炬潈鍒ゆ嵁"鐨勫畾绋匡紙`morphSessionOughtToLive`锛夈€?
    //   **鐢ㄦ埛鎶?娌″姩鐢?鏃跺厛鐪嬬涓€琛岀殑 `sess` / `geom` 涓や綅**锛?
    //     `sess=0` 鈬?浼氳瘽琚竻鎺変簡锛坄aboutToDisappear` 閭ｆ潯璺病琚嫤浣忥級锛?
    //     `geom=0` 鈬?缁堢偣鍑犱綍濮嬬粓娌￠噺鍒?鈬?瀹瑰櫒鎭掔瓑 鈬?姝ｆ槸"娌℃湁灏侀潰/鑳屾櫙鍔ㄧ敾"銆?
    // 鈽?2026-10-17锛堢増鏈爣璁?鈫?**`af66eb1`**锛夛細閭ｄ竴杞姞鐨勬槸**绗崄琛屽熬閮ㄧ殑 `pd=`**
    //   锛堣窡鎵嬩笁涓嫆缁濈偣鐨勭疮璁¤鏁帮級銆傗噿 **鐢ㄦ埛鎶?涓嶈窡鎵?鏃跺厛鐪?`pd`**锛?
    //     `pd=0/0/0` 鈬?鍒ゆ嵁鍏ㄧ▼鏀捐锛岄棶棰樺湪浜嬩欢/鎵嬪娍/鐗堝紡锛涗换涓€闈?0 鈬?鏄垽鎹嫆鐨勩€?
    const line1: string = `V af66eb1 sess=${e.morphSessionStarted ? 1 : 0} ` +
      `usable=${e.morphUsable ? 1 : 0} geom=${e.morphGeomReadyNow() ? 1 : 0} ` +
      `cont=${e.morphContainerActive() ? 1 : 0} ` +
      `clip=${e.morphClipping() ? 1 : 0} scale=${e.morphScale.toFixed(3)} p=${e.morphP.toFixed(3)}`;
    const line2: string = `real=${e.realCoverVisible() ? 1 : 0} ` +
      `clone=${e.morphOverlayBridging() ? 1 : 0} ` +
      `snap=${e.snapStartWVp().toFixed(0)}/${e.miniSize.toFixed(0)} ` +
      `end=${e.endCoverSizeVp().toFixed(0)}/${e.endCoverHVp().toFixed(0)} ` +
      `op=${this.backgroundRevealOpacity().toFixed(3)} stage=${e.morphStage} drv=${e.morphDrive}`;
    // 鈽?绗笁琛岋細鎺у埗鍖洪绠楋紙**涓嶇敤 hdc 涔熻兘鏍告棤鐣岄偅濂楁暟鍊?*锛夆€斺€?
    //   `usableH` 搴旀寜鏃犵晫 `winH 鈭?padTop 鈭?max(avoidBottom, bottomGap)` 绠楋紱
    //   `padBot` 璇诲埌鐨勫€煎簲涓?`gap` 鍒楋紙FULL 65锛変竴鑷达紙闄ら潪瀹炴祴閬胯鍖烘瘮瀹冭繕澶э級銆?
    const line3: string = `usableH=${e.usableHVp().toFixed(1)} padBot=${e.padBottomVp().toFixed(1)} ` +
      `avoid=${e.navigationBarBottomVp.toFixed(1)} gap=${e.chromeBottomGapVp().toFixed(0)} ` +
      `gapScrub=${e.chromeGapScrubVp().toFixed(0)} tier=${e.chromeTier}`;
    // 鈽?绗洓琛岋細**鏈疆鐨勪袱涓姩浣滆鏁?*锛堝垽"浠ｇ爜鏈夋病鏈夎窇鍒?姣斿垽鍊兼洿闈犲墠锛岃瀛楁娉ㄩ噴锛夈€?
    //   鈽呪槄鈽?2026-10-16锛坓oal 绗?2 鏉°€岄〉闈㈠渾瑙掑啀鏍镐竴閬嶃€嶇殑**鑷瘉浣?* 鈥斺€?**宸茶姝ｈ繃涓€娆?*锛?
    //
    //   鈿狅笍 鎴戠涓€鐗堟妸 `rad`/`radVis` 閲忔垚浜?`morphRadius` 鈥斺€?**閭ｆ槸"瀹瑰櫒鑷繁"鐨勫渾瑙?*锛?
    //      涓嶆槸灏侀潰鐨勫渾瑙掞紝涓よ€呮槸**涓ゆ潯鐙珛鐨勯摼**锛堝埆娣凤級锛?
    //   ```
    //     瀹瑰櫒鍦嗚 morphRadius = initRadiusVisual 脳 (1 鈭?t) / scale
    //        路 璧风偣 = 杩蜂綘鏉¤兌鍥婂渾瑙掔殑涓€鍗婏紝缁堢偣 = **0**锛堥摵婊″睆 鈬?瀹瑰櫒涓嶈鏈夊渾瑙掞級
    //        路 鏃犵晫鍚屾锛歛pplyPullProgress 鐨?radius 鍒嗘敮锛?1054-51086锛?
    //        鈬?鎵€浠?t=0 鏃跺畠鎸夎璁″氨鏄?0 鈥斺€?鎴戠涓€鐗堟嬁瀹冨綋"灏侀潰鍦嗚"锛岃鏁拌嚜鐒跺叏鏄?0銆?
    //
    //     灏侀潰鍦嗚 coverLocalRect().radius = lyricMorph(t).radius
    //        路 鏃犵晫 `radiusAt(t) = visualRadiusAt(t) / scaleAt(t)`
    //          鍏朵腑 `visualRadiusAt(t) = lerp(radiusPlayer, radiusLyricVisual, t)`
    //          `radiusPlayer = 8`锛坵ujie.pa:85761 ldai 0x8锛?
    //          `radiusLyricVisual = 12`锛堝悓鏃忓父閲忥級
    //        路 鏈粨 `lyricMorph()` 閲屽氨鏄?`lerp(COVER_RADIUS_PLAYER_VP(8), COVER_RADIUS_LYRIC_VISUAL_VP(12), p)`
    //        鈬?涓ょ**閫愬瓧涓€鑷?*锛歵=0 鈬?8锛泃=1 鈬?12
    //   ```
    //   鈬?杩欎竴琛岀幇鍦ㄩ噺鐨勬槸**灏侀潰閭ｆ潯閾?*锛坄cRad` / `cRadV`锛宑 = cover锛夛紝
    //     骞朵繚鐣欏鍣ㄩ偅鏉★紙`rad`/`radVis`锛変互渚垮鐓?鈥斺€?涓ゆ潯閮芥墦鍑烘潵锛屼竴鐪艰兘鍒嗚鲸銆?
    //   鍒よ锛歚t=0` 鈬?**cRad = cRadV = 8.00**锛沗t=1` 鈬?**12.00**锛?
    //         褰㈠彉涓?`cRadV = cRad 脳 morphScale` 搴斿缁堝湪 **8~12 涔嬮棿**锛堜笉闅?scale 鎶栧姩锛夈€?
    //   澶嶆牳鍏ュ彛锛氳繛鐐规挱鏀鹃〉宸︿笂瑙?3 娆°€?
    const coverRect: LyricMorphRect = this.coverLocalRect();
    const line4: string = `remeasure=${this.diagRemeasureTries} overlayKick=${this.diagOverlayKicks} ` +
      `seek=${e.chromeSeekSize().toFixed(0)} edge=${coverRect.size.toFixed(0)} t=${this.lyricMorphT.toFixed(2)} ` +
      `cRad=${coverRect.radius.toFixed(2)} cRadV=${(coverRect.radius * e.morphScale).toFixed(2)} ` +
      `rad=${e.morphRadius.toFixed(2)} radVis=${(e.morphRadius * e.morphScale).toFixed(2)}`;
    // 鈽呪槄鈽?2026-10-17锛?*goal 绗?1 鏉°€屽厓淇℃伅琛屻€嶇殑鐜板満鑷瘉 鈥斺€?绗笁鐗堬紝鍒よ宸插畾绋?*锛?
    //   `metaTop` = 鏈**鐪熷疄娓叉煋鍊?* = `metaTopGeomY(t, rowH)`锛堝氨鏄笂闈㈤偅鏉?`.position().y`锛?
    //               **鍚屼竴涓嚱鏁般€佹病鏈夌浜屼唤琛ㄨ揪寮?*锛夛紱
    //   `metaOld` = **涓婁竴鐗堥偅鏉¤嚜瀹氬紡瀛?*鐨勫€硷紙`lyricMetaMorphY(t) + t脳(size鈭抮owH)/2`锛?
    //               瑙?`metaTopInUseYAt()`锛岀幇鍦ㄥ彧鐢ㄤ簬瀵硅处锛?*涓嶅啀鍙備笌娓叉煋**锛夛紱
    //   `metaD`   = `metaOld 鈭?metaTop`銆?
    //   ## 鍒よ锛堜袱绔兘鏄?*宸茬煡甯告暟**锛屾墍浠ヨ繖涓€琛岀幇鍦ㄥ彲璇佷吉锛?
    // ```
    //   t = 0锛堝皝闈㈤〉锛夛細metaD 鈮?**鈭?0**
    //       鈥斺€?鏃у紡瀛愮殑 from 鐢?`LYRIC_META_GAP_VP(10)`锛堟湰浠撲及瀹氬€硷級锛?
    //          鏂板紡瀛愮敤 `COVER_FIT_META_GAP_VP(50)`锛堟棤鐣?`fitPlayerOverlay` 鐨勭‖缂栫爜 a8锛?
    //          鈬?鏃у紡瀛愭瘮鏂板紡瀛愰珮 40vp 鈬?metaOld 鈭?metaTop = 鈭?0
    //   t = 1锛堟瓕璇嶉〉锛夛細metaD 鈮?**鈭?.64**
    //       鈥斺€?鏃у紡瀛愬埌"灏忓皝闈㈤《杈?+ (size鈭抮owH)/2"锛屾柊寮忓瓙鍒?灏忓皝闈㈤《杈?+ 28 鈭?rowH/2"锛?
    //          涓よ€呭樊 = 28 鈭?size/2 = 28 鈭?48.72/2 = 3.64 鈬?鏃у紡瀛愰珮 3.64vp
    //   鈬?涓鏄繖涓ょ鐨勭嚎鎬ф彃鍊笺€?
    //   鈿狅笍 鑻?t=0 澶?metaD 涓嶆槸 鈮堚垝40锛堜緥濡?鈭?锛夆噿 璇存槑 `bigEndpointRect()` 涓庨偅鏉℃棫寮忓瓙
    //      鐢ㄧ殑鐭╁舰鏉ユ簮涓嶅悓锛堟棫寮忓瓙璧?`lyricMetaFromYOf()`锛屼袱鑰呴兘鍩轰簬 `bigEndpointRect`锛?
    //      鐞嗚涓婂悓婧愶級鈥斺€?閭ｆ椂鎵嶉渶瑕佹煡銆?
    // ```
    const metaTop: number = e.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const metaOld: number = e.metaTopInUseYAt(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const line6: string = `metaTop=${metaTop.toFixed(1)} metaOld=${metaOld.toFixed(1)} ` +
      `metaD=${(metaOld - metaTop).toFixed(1)} (t=0 鏈熸湜 鈭?0 / t=1 鏈熸湜 鈭?.6) ` +
      // 鈽?2026-10-17锛?*杩欎竴鏉″凡缁忎粠"寰呰鐨勫垽鎹?闄嶇骇涓?缁撴瀯涓嶅彉閲忓摠鍏?**锛夛細
      //   `lBox` = 姝岃瘝椤靛唴瀹圭洅鐨?*绐楀彛椤惰竟**锛坄reportLyricBoxTop` 鍠傦級銆?
      //   缁撴瀯涓婃亽涓?**0**锛?鐩?灏辨槸 Swiper 鐨勭洅锛岃€?Swiper 鎵€鍦ㄧ殑 `Column` 涓?
      //   `LyricFloatLayer()` 鏄悓涓€涓笉甯?padding 鐨?`Stack` 鐨勫瀛愶紝涓旇 `Stack`
      //   鐨勫唴瀹圭洅宸︿笂瑙?= 绐楀彛鍘熺偣 鈥斺€?瀹屾暣璇佹嵁閾捐 `PlayerExpandState.lyricBoxTopVp` 鐨?JSDoc锛?
      //   鈬?`lyricPadTop()` 閭ｆ潯"绐楀彛鍧愭爣 + 23"鐨勫紡瀛?*宸茬粡**绛変环浜庢棤鐣岀殑鐩掑唴寮忓瓙 鉁?
      //     **涓嶉渶瑕佹崲绠楋紝涔熶笉蹇呭啀璇昏繖涓暟浜嗐€?*
      //   鈿狅笍 瀹冪幇鍦ㄥ彧鏈変竴涓敤閫旓細**鑻ュ皢鏉ユ湁浜虹粰閭ｄ袱灞傚姞浜?padding锛岃繖閲屼細璇诲埌鏄庢樉闈?0** 鈥斺€?
      //     閭ｆ椂鎵嶉渶瑕佹妸 `lyricPadTop` 鎹㈡垚 `(娴眰搴曡竟 鈭?lBox) + 23`锛堜竴琛岋級銆?
      //   鈿狅笍 鍔ㄧ敾涓畠鍙兘鐬椂闈?0锛堥偅鏄鍣ㄥ彉鎹㈣繃鐨?`globalPosition.y`锛屾甯革級鈬?鐪?*闈欐鎬?*鐨勮鏁般€?
      `lBox=${e.lyricBoxTopVp.toFixed(1)}`;
    // 鈽呪槄鈽?2026-10-16锛?*"姝岃瘝椤靛皝闈㈡病鍙樺皬"鐨勭洿鎺ュ垽鎹?*锛岀敤鎴风湡鏈烘埅鍥惧悗鍔狅級锛?
    //   鐢ㄦ埛瀹炴祴銆岃繖鏄瓕璇嶉〉锛岄偅涓皝闈㈡病鍙樺皬銆嶁噿 璇绘暟 `t=0.00 edge=331`銆?
    //   灏侀潰灏哄 = `lyricMorph(lyricMorphT).size`锛岃€?`lyricMorphT` 鍙湁 0/1 涓や釜绋冲畾鍊硷細
    //     路 `t=0` 鈬?灏侀潰 = `endCoverSize`锛堟暣绐楅偅涓€浠?鈮?331锛夆€斺€?灏辨槸鐢ㄦ埛鐪嬪埌鐨勫ぇ灏侀潰锛?
    //     路 `t=1` 鈬?灏侀潰 = `lyricCoverSizeOf()`锛堝皬灏侀潰 鈮?48.72锛夆€斺€?搴旀湁鐨勬牱瀛愩€?
    //   鈬?鎵€浠?娌″彉灏? 鈮?**`lyricMorphT` 娌″埌 1**銆傝繖涓€琛岀洿鎺ョ粰鍑哄畠涓轰粈涔堟病鍒帮細
    //     路 `sw`  = `playbackSwiperIndex` 鈥斺€?**涓嶆槸 1** 鈬?鏍规湰娌″垏鍒版瓕璇嶉〉锛堟垨绱㈠紩琚浣嶏級
    //     路 `tgt` = `lyricMorphTarget`   鈥斺€?涓?`sw` 涓嶄竴鑷?鈬?琛ラ棿鏂瑰悜鍙嶄簡 / 娌℃敹灏?
    //     路 `vis` = `lyricMorphVisible`  鈥斺€?`0` 鈬?`lyricFloat()` 鍒や负涓嶅彲鐢紝鏁村椋炶娌¤捣
    //     路 `sg` / `fs` = `lyricSwiperSettled` / `lyricFlightSettled` 鈥斺€?涓ら棶鎻℃墜娌￠綈
    const line7: string = `sw=${this.playbackSwiperIndex} tgt=${this.lyricMorphTarget ? 1 : 0} ` +
      `vis=${this.lyricMorphVisible ? 1 : 0} op=${this.lyricMorphOpacity.toFixed(2)} ` +
      `sg=${this.lyricSwiperSettled ? 1 : 0} fs=${this.lyricFlightSettled ? 1 : 0} ` +
      `lcEdge=${e.lyricCoverSizeOf().toFixed(1)} lcY=${e.lyricCoverYOf().toFixed(1)} ` +
      `float=${e.lyricFloat() ? 1 : 0}`;
    // 鈽呪槄鈽?2026-10-16锛?*Swiper 鍥炶皟瀹炲弬** 鈥斺€?瑙佸瓧娈?`diagAnimStart` 鐨勬敞閲婏級锛?
    //   `ast=-1--1` = `onAnimationStart` **涓€娆￠兘娌¤繘鏉ヨ繃**锛堚噿 鍒囬〉娌¤蛋婊戝姩鍥炶皟锛夛紱
    //   `ast=0-1` + `skp>0` = 杩涙潵浜嗕絾琚畧鍗尅鎺夛紙鈬?瑕佹敼瀹堝崼鍒ゆ嵁锛夛紱
    //   `chg=1/鈥 鑰?`sw=0` = swiper 璁や负鍦ㄦ瓕璇嶉〉銆佺姸鎬佸嵈璁扮潃 0锛堚噿 鐘舵€佹病鍚屾锛夈€?
    const line8: string = `ast=${this.diagAnimStart} skp=${this.diagAnimSkip} ` +
      `aend=${this.diagAnimEnd}/${this.diagAnimEndCount} ` +
      `chg=${this.diagChg}/${this.diagChgCount}`;
    // 鈽呪槄鈽?2026-10-16锛?*杩涘害婧愯嚜璇?* 鈥斺€?goal 绗?1 鏉℃寚瀹氱殑 `swiperProgress` 绛変环鐗╋級锛?
    //   `scr` = `onContentDidScroll` 鐨勮皟鐢ㄦ鏁帮紙**閫愬抚**瑙﹀彂锛岃瀹樻柟 SDK 鍘熸枃锛夛紱
    //   `last` = 鏈€鍚庝竴娆″疄鍙?`index/position`銆?
    //   鍒ゆ嵁锛氬仠鍦ㄦ瓕璇嶉〉鏃跺簲褰撶湅鍒?**`last=0/1.000`**锛堟棤鐣屾妸 `position` 澶瑰埌 1锛?
    //   涔嬪悗 `index === 0` 鎵嶆洿鏂般€佹墍浠ュ畠绋冲畾鍋滃湪 1锛夆€斺€?閭ｆ椂 `lyricMorphT` 涔熷簲涓?1銆?
    //   灏侀潰 `edge` 搴斿彉鎴愬皬灏侀潰锛堚増48.7锛夈€?
    //   `scr=0` 鈬?杩欎釜鍥炶皟涓€娆￠兘娌¤Е鍙戯紙瑕佹崲杩涘害婧愶級銆?
    const line9: string = `scr=${this.diagScrollCount} last=${this.diagScrollLast}`;
    // 鈽呪槄鈽?2026-10-16锛?*鍏抽棴璺緞鐨勭幇鍦鸿鏁?* 鈥斺€?鐢ㄦ埛 23:19/23:20 涓夋潯鍙嶉鐨勫畾浣嶇敤锛?
    //
    // 鐢ㄦ埛鍙嶉锛堝師璇濇鎷級锛?
    // ```
    //   鈶?鏈夋椂"鎾斁椤甸椤典笅鏂瑰嚑涓寜閽篃浼氶殣钘?
    //   鈶?"杩斿洖鍏抽棴鎾斁鍣ㄦ垜鍙戠幇涓嶆槸娌¤儗鏅紝浣犵湅閭ｄ竴鏉★紝鏄?*鏈夎儗鏅絾鏄珮搴︾壒浣?*"
    //   鈶?"涓嬫媺鍏抽棴鎾斁鍣ㄥ皝闈㈡槸杩欎釜灏忓渾褰紝鐒跺悗鍔ㄧ敾缁撴潫浜?*绐佺劧鏉ヤ釜灞曞紑鎾斁鍣ㄧ殑鍔ㄧ敾**"
    // ```
    // 杩欎笁鏉￠兘鍙戠敓鍦?*鍏抽棴杩囩▼涓?*锛岃€屼笂闈?1~9 琛屽ぇ澶氭槸"闈欐鎬佽鏁? 鈬?蹇呴』琛ヨ繖涓€琛屻€?
    //
    // 鍚勯噺鐨勫垽璇伙細
    // ```
    //   show  = 澹冲眰 isShowPlay銆傗憿 鐨勫ご鍙峰珜鐤戯細鑻ュ畠鍦ㄥ叧闂€斾腑鍙樺洖 true锛?
    //           澹冲眰 `@Monitor('appState.isShowPlay')` 浼?`pushPlayerRoute()`
    //           鈬?**閲嶆柊鎺ㄥ叆涓€涓柊鐨勬挱鏀鹃〉瀹炰緥** 鈬?灏辨槸"鍙堟斁涓€閬嶅睍寮€"
    //   clos  = isClosing锛堝叧闂摼璺凡璧凤級
    //   coll  = 鎺у埗鍖哄凡鏀惰捣锛堚憼 鐨勭洿鎺ヨ鏁帮細1 = 閭ｅ嚑涓寜閽槸钘忕潃鐨勶級
    //   p     = morphP锛堝叧闂椂鍚?0 璧帮級
    //   clipH = **鍐欒繘瀹瑰櫒 `.height()` 鐨勮鍓獥鍙ｉ珮**锛堚憽 鐨勭洿鎺ヨ鏁帮細
    //           鑳屾櫙鏄鍣ㄧ殑瀛愯妭鐐?鈬?瀹瑰櫒琚鎴愬楂橈紝鑳屾櫙灏卞彧鐢诲楂橈級
    //           闈欐鎬佸簲 = 0锛堟鏃?`.height()` 鍐呴儴璧?'100%'锛夛紱鍏抽棴涓細杩炵画鍙樺埌 鈮?杩蜂綘鏉￠珮
    //   bg    = 鑳屾櫙灞備笉閫忔槑搴︼紙鈶?鐪嬪畠鏈夋病鏈夎娣℃帀锛?
    //   drv   = morphDrive锛團INGER/ANIM/NONE锛?
    //   sq    = morphSquashY锛堣惤浣嶆尋鍘嬶紝鈮? 鏃跺湪寮癸級
    //   pd    = **璺熸墜"琚嫆"璁℃暟**锛堚槄 2026-10-17 鏂板锛岀洿鎺ヤ负鐢ㄦ埛鐨勩€屼笂婊戜笉鑳借嚜鐢便€嶏級
    //           `<璧锋墜鎷?/<鏇存柊鎷?/<鏉炬墜鎷?`锛?*绱鍊笺€佷笉娓呴浂**锛堥噸鍚?App 鎵嶅綊闆讹級銆?
    //           鐢ㄦ硶锛氳寰芥爣寮€鐫€ 鈫?鍋氫竴娆′笂鎷?鈫?鐪嬭繖涓変釜鏁?*鏈夋病鏈夊彉**銆?
    //           路 鍙樹簡 鈬?銆屼笉璺熸墜銆嶆槸**鍒ゆ嵁**鎷掔殑锛屼笖涓€鐪肩湅鍑烘槸鍝竴涓細
    //              绗?1 涓定 = 璧锋墜閭ｄ竴鍒诲嚑浣曟病閲忛綈锛堢洿鎺ラ摵婊°€佹棤璺熸墜鍔ㄧ敾锛?
    //                          鈬?鏌?`measureMiniDuringPull` / 杩蜂綘鏉℃槸鍚﹀凡鎸傝浇锛?
    //              绗?2 涓定 = 鎵嬫寚鍦ㄥ姩浣?`pullDragging` 鏄亣锛堟湰绫绘渶鍙枒鐨勪竴鏉★紝
    //                          鍘嗗彶涓婅繖涓€绫诲凡缁忓嚭杩囦袱娆″洖褰掞細搂round-36 鐨?`staleClr`锛?
    //                          鈬?鏌?璋佹妸 `pullDragging` 娓呮垚浜嗗亣"锛?
    //              绗?3 涓定 = 鏉炬墜/鍙栨秷琚垽鎹嫆锛堟敹灏炬病璧?鈬?椤甸潰鍗″湪鍗婅矾锛夈€?
    //           路 涓€涓兘娌″彉 鈬?鍒ゆ嵁鍏ㄧ▼鏀捐 鈬?闂鍦?*(b)浜嬩欢/鎵嬪娍璇嗗埆/鐗堝紡**锛?
    //             **涓嶈鍐嶅幓鍔ㄧ姸鎬佹満**锛堜慨娉曞畬鍏ㄤ笉鍚岋級銆?
    //           鈿狅笍 绗?2 涓槸**鎸夋墜鍔胯娆?*鐨勶紙涓€娆℃墜鍔挎渶澶?+1锛夛紝瑙?
    //              `Index.pullDropCountedThisGesture` 鐨勮鏄庛€?
    // ```
    const line10: string = `show=${this.state.isShowPlay ? 1 : 0} clos=${this.isClosing ? 1 : 0} ` +
      `coll=${this.chromeCollapsed ? 1 : 0} p=${e.morphP.toFixed(2)} ` +
      `clipH=${e.morphClipHeight.toFixed(0)} bg=${this.backgroundRevealOpacity().toFixed(2)} ` +
      `drv=${e.morphDrive} sq=${e.morphSquashY.toFixed(3)} ` +
      `pd=${e.pullDropBegin}/${e.pullDropUpdate}/${e.pullDropEnd}`;
    // 鈽呪槄鈽?2026-10-16锛?*鍐呭灞?onAppear 璧颁簡鍝潯鍒嗘敮** 鈥斺€?瀹氫綅"鍏抽棴鍚庡張鏀句竴閬嶅睍寮€"锛夛細
    //   `ab` = morph锛堝舰鍙樺垎鏀紝姝ｅ父锛? intro锛堣捣浜?playExpandIntro 鈫?鍏抽棴鏃跺嚭鐜板嵆 bug锛?
    //        / skipClose锛堝厹搴曞垎鏀絾琚?姝ｅ湪鍏抽棴"鐨勯棬鎷︿笅锛屾湰杞柊澧烇級
    //   `ap` = introPaintReady锛堟暣椤电粯鍒堕棬锛?
    const line11: string = `ab=${this.diagAppearBranch} ap=${this.introPaintReady ? 1 : 0} ` +
      `stage=${e.morphStage} exit=${this.expandIntroRunning ? 1 : 0} bgBox=${this.diagBgBox} ` +
      // 鈽?2026-10-17锛歚mesh` = 缃戞牸婧愬湪涓嶅湪锛? = 璧板厹搴曞彇鏍疯壊灞傦紝閭ｅ眰**甯?alpha**锛夈€?
      //   鍒ゃ€岀偣鍑绘挱鏀炬潯鎵撳紑娌℃湁鑳屾櫙銆嶏細`mesh=0` 鈬?鏄彇鍥鹃摼娌′笂鏉ワ紙鐪?`RzdBgRetry`锛夛紱
      //   `mesh=1` 鑰屽睆涓婁粛娌℃湁 鈬?鏄粯鍒?瑁佸壀鐨勪簨锛堢湅 `bgBox` 涓?`clipH`锛夈€?
      `mesh=${this.meshSrc !== undefined ? 1 : 0} ` +
      `lcl=${PlaybackPage.lastCloseAtMs > 0 ? (Date.now() - PlaybackPage.lastCloseAtMs).toFixed(0) : 'never'}`;
    // 鈽呪槄鈽?2026-10-16锛?*鎺у埗鍖鸿嚜璇?* 鈥斺€?瀹氫綅鐢ㄦ埛绗?1 鏉°€屾湁鏃朵笅鏂瑰嚑涓寜閽篃浼氶殣钘忋€嶏級
    //   蹇呴』鑳藉垎杈ㄨ繖涓夌褰㈢姸锛堜慨娉曞畬鍏ㄤ笉鍚岋級锛?
    //     鈶?鑷姩鏀惰捣锛堣璁¤涓猴細鏃犵晫 `IDLE_MS = 5000`锛屽彧鍦?`isPlay` 鏃剁敓鏁堬級
    //        鈬?`cc=1` + `cpr=0` + `chH` 姝ｅ父 鈬?**涓嶆槸 bug**
    //     鈶?琚鎺夛紙瀹瑰櫒瑁佸壀绐楀彛鎶婃帶鍒跺尯鍒囨帀锛夆噿 `clipH` 寰堝皬鑰?`chH` 姝ｅ父 鈬?鏄鍣ㄥ嚑浣曠殑浜?
    //     鈶?楂樺害濉岄櫡锛坄lyricChromeHeight` 閲忔垚 0 鈬?`.height(0 * progress)` = 0锛?
    //        鈬?`chH=0` 鈬?鏄?*閲忔祴**鐨勪簨锛坄lyricChromeMeasurePending` / `wasConstrained` 閭ｆ潯閾撅級
    //   `cpr` = lyricChromeProgress锛? = 鍏ㄥ嚭銆? = 鍏ㄦ敹锛夛紱`chH` = lyricChromeHeight锛?
    //   `ofs` = chromeOffsetY锛堟敹璧锋椂涓嬬Щ 46vp锛?
    const line12: string = `cc=${this.chromeCollapsed ? 1 : 0} cpr=${this.lyricChromeProgress.toFixed(2)} ` +
      `chH=${this.lyricChromeHeight.toFixed(0)} ofs=${e.chromeOffsetY().toFixed(0)} ` +
      `pend=${this.lyricChromeMeasurePending ? 1 : 0} play=${this.state.isPlay ? 1 : 0}`;
    // 鈽呪槄鈽?绗簲琛岋細**鍔ㄤ綔杞ㄨ抗**锛堟渶杩?6 涓姩浣滐紝鎸夊彂鐢熼『搴?`>` 杩炴帴锛夈€?
    //   涓轰粈涔堟渶鏈夌敤锛氳繖鏉￠摼涓?椤哄簭"鏈韩灏辨槸鑷彉閲忕殑鏈€澶у€?鈥斺€?
    //   鍚屼竴涓嚱鏁板厛璋冭繕鏄悗璋冿紝缁撴灉瀹屽叏涓嶅悓锛埪?3 鐨?`onAppear` 璇垽銆伮?03 鐨?
    //   `onDisappear` 璇潃閮芥槸椤哄簭闂锛夛紝鑰屽墠鍥涜鍙湅寰楀嚭"褰撳墠鍊?銆?
    //   鍒よ绀轰緥锛堢偣鍑绘墦寮€搴斿綋鐪嬪埌鐨勫舰鐘讹級锛?
    //     `clickOpen>beginOk>settle0C>settle1C>measOk>tween`  鈬?涓€璺蛋閫?
    //     `clickOpen>beginOk>settle0C>settle1C>鈥锛堟棤 measOk锛夆噿 琛ラ噺涓€鐩存病鎴愬姛
    //     `clickOpen>skip`                                     鈬?琚?`pullDragging`/鐩镐綅鎸′簡
    //     `鈥?tween>settleSkip`                                 鈬?琛ラ棿璧蜂簡浣嗚惤浣嶈璺宠繃锛埪?04 閭ｇ被锛?
    const line5: string = `trace=${e.morphTrace.length > 0 ? e.morphTrace : '(empty)'}`;
    // 鈽呪槄鈽?2026-10-16锛?*绗崄涓夎锛氬叧闂繃绋?榛戝專瀛?** 鈥斺€?璇绘硶瑙?{@link PlaybackPage.evLog}锛?
    //   涓轰粈涔堥渶瑕佸畠锛氱敤鎴锋姤鐨勪袱鏉★紙銆屽叧闂椂鑳屾櫙鍙墿涓€鏉°€嶃€屽叧闂悗鍙堟斁涓€閬嶅睍寮€銆嶏級
    //   **閮藉彂鐢熷湪鍏抽棴杩囩▼涓紝鑰岄偅涓€鍒诲窘鏍囧凡闅忔挱鏀鹃〉涓€璧锋秷澶?* 鈬?浜嬪悗璇讳笉鍒颁换浣曚笢瑗裤€?
    //   鈬?浜嬩欢璁板湪**妯″潡绾ч潤鎬佺幆褰㈢紦鍐?*閲岋紝绛変笅涓€娆℃墦寮€鎾斁椤靛啀鏄剧ず 鈬?灏辨湁浜嗕笂涓€娆″叧闂殑瀹屾暣鏃跺簭銆?
    //
    //   鈿狅笍 鏄剧ず鏃舵妸 `|` 鎹㈡垚鎹㈣锛氫竴琛屼竴涓簨浠讹紝涓€寮犳埅鍥惧氨鑳借瀹?
    //     锛堜笉鎹㈣鐨勮瘽杩戝崈瀛楃浼氭尋鎴愪竴鍧紝11fp 涓嬪嚑涔庝笉鍙锛夈€?
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

  /** 鑷瘉寰芥爣鏈綋锛堥粦搴曠櫧瀛椼€佷笉鍚冧簨浠躲€佸帇鍦ㄦ渶涓婇潰锛夈€?*/
  @Builder
  private DiagBadge() {
    Text(this.diagText.length > 0 ? this.diagText : 'V af66eb1 (no data)')
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor('rgba(0, 0, 0, 0.78)')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(6)
      // 鈽?2026-10-16锛氬窘鏍囩幇鍦ㄦ湁 **13 琛?*锛堚€︾鍗佷簩琛屾帶鍒跺尯鑷瘉 / 绗崄涓夎鍏抽棴杩囩▼浜嬩欢鏃ュ織锛?
      //   浜嬩欢鏃ュ織鏈韩灏辨槸澶氳鈥斺€斾竴琛屼竴涓簨浠讹級鈬?`maxLines` 蹇呴』澶燂紝鍚﹀垯鏈€鍚庝竴琛屼細琚埅鎺夈€?
      .maxLines(32)
      .position({ x: 8, y: 120 })
      .zIndex(99)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 椤堕儴"闅愬舰鐑尯"锛氳繛鐐?3 娆″紑鍏宠嚜璇佸窘鏍囥€?
   *
   * 鈿狅笍 鏀惧湪**椤舵爮涔嬩笅銆佸唴瀹逛箣涓?*鐨勪竴涓獎鏉★紙楂?48vp銆佷笉鎷﹀叾瀹冧氦浜掍互澶栫殑涓滆タ锛夛細
   *   瀹冨彧鍚冩帀鑷繁杩欎竴鏉″甫瀛愪笂鐨勭偣鍑伙紝涓嶅奖鍝嶆挱鏀?鍒囨瓕/姝岃瘝婊氬姩銆?
   */
  /**
   * 椤堕儴"闅愬舰鐑尯"锛氳繛鐐?3 娆″紑鍏宠嚜璇佸窘鏍囥€?
   *
   * 鈿狅笍 **2026-10-16 淇竴澶勬垜鑷繁寮曞叆鐨勪氦浜掑洖褰?*锛氱涓€鐗堝啓鐨勬槸
   *   `Row().width('100%').height(48).position({x:0, y:96})` 鈥斺€?
   *   鑰?*澹版槑寮?`.onClick` 浼氭秷璐瑰懡涓尯鍩?*锛坄HitTestMode` 榛樿瀵硅嚜韬寖鍥?Block锛?
   *   鈬?瀹冩妸 96鈥?44 閭?*涓€鏁存潯妯悜甯﹀瓙**鐨勭偣鍑诲叏鍚冩帀浜嗐€?
   *   鍦ㄦ瓕璇嶉〉涓婇偅涓€甯︽槸**姝岃瘝琛?*锛堢偣姝岃瘝璺宠浆锛夆噿 鐪熷疄鍔熻兘琚尅銆?
   *
   * 鈬?鐜板湪鏀规垚**宸︿笂瑙掍竴灏忓潡**锛?20脳40 @ y=88锛夛紝鍙鐩栧皝闈㈠乏涓婅閭ｇ墖涓嶅彲鑳芥湁浜や簰鐨勫尯鍩燂細
   *   路 灏侀潰椤碉細閭ｄ竴甯︽槸灏侀潰鍥惧儚鏈韩锛堟棤鐐瑰嚮璇箟锛夛紱
   *   路 姝岃瘝椤碉細`lyricPadTop()` 淇濊瘉姝岃瘝姝ｆ枃浠庢诞灞備笅鏂瑰紑濮嬶紝涓嶄細钀藉埌杩欎竴灏忓潡閲屻€?
   *   路 椤舵爮鍦?`y < 88`锛屼篃纰颁笉鍒般€?
   * 鈿狅笍 鑻ュ摢澶╄繖鍧椾篃闇€瑕佽皟浣嶇疆锛?*鍏堢‘璁や笉鍘嬪湪"鏈変氦浜掔殑甯﹀瓙"涓?*銆?
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

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鎺у埗鍖鸿嚜鍔ㄦ敹璧?鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /**
   * 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣?`BarCollapse`锛夛細鎷栧姩鎺у埗鏉℃敹璧?灞曞紑鐨?*鎵嬪娍鐘舵€佹満**銆?
   * 閫愭潯杞啓瑙?`common/musicbasic/.../model/BarCollapse.ets`锛堝惈瀛楄妭鐮佽鍙峰鐓ц〃锛夈€?
   * 鍙湁 `onChromeBarTouch()` 浼氱敤瀹冦€?
   */
  private barCollapse: BarCollapse = new BarCollapse();

  /**
   * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`PlayerPage.showChrome()`锛夛細**鍙?浜嚭鎺у埗鍖?锛屼笉閲嶇疆绌洪棽璁℃椂**銆?
   *
   * 鍑哄锛坄_recover/logic-src/PlayerPage.abc.txt:11942-11982`锛夛細
   * ```
   *   showChrome() {
   *     if (chromeHidden) {
   *       getUIContext().animateTo({ duration: CHROME_ANIM_MS, curve: Curve.EaseInOut },
   *                                () => { chromeHidden = false; });   // 位@5*#
   *     }
   *   }
   * ```
   * 鈽?鍏抽敭锛?*瀹冮噷闈㈡病鏈?`startIdle()`**锛坄hideChrome` 閲屼篃娌℃湁 `clearIdle()`锛夈€?
   *   涔熷氨鏄"鍞ゅ嚭鎺у埗鍖?涓?璧风┖闂茶鏃?鏄棤鐣岄噷**涓や欢鐙珛鐨勪簨**锛?
   *   瑕佷笉瑕佽捣璁℃椂鐢?*璋冪敤鐐?*鍐冲畾锛堣 {@link PlaybackPage.onSwiperIndexChanged} 涓?
   *   `onLyricInteract` / `onLyricSwipe`锛夈€傛垜浠師鏉ユ妸涓よ€呮崋鎴愪竴涓?`touchChrome()`锛?
   *   浜庢槸鍦?鍒囧埌灏侀潰椤?閭ｆ潯璺笂浼?*椤烘墜鎶婄┖闂茶鏃朵篃璧疯捣鏉?* 鈥斺€?涓庢棤鐣岀浉鍙嶏紙閭ｉ噷鏄?`clearIdle()`锛夈€?
   */
  private showChrome(): void {
    if (!this.chromeCollapsed) {
      return;
    }
    this.getUIContext().animateTo({
      duration: PlaybackPage.CHROME_ANIM_MS,
      curve: Curve.EaseInOut
    }, (): void => {
      this.chromeCollapsed = false;
      this.lyricChromeProgress = 1;
    });
    Logger.info('RzdLyricChrome', `show naturalHeight=${this.lyricChromeHeight}`);
  }

  /**
   * 璁板綍涓€娆℃帶鍒跺尯浜や簰锛?*鍞ゅ嚭 + 閲嶇疆鑷姩鏀惰捣璁℃椂**銆?
   *
   * 鏃犵晫閲岃繖涓や欢浜嬫槸鍒嗗紑鐨勶紙`showChrome()` 涓?`startIdle()`锛夛紝鍙湁
   * "鐢ㄦ埛鍦ㄦ瓕璇嶉〉涓婄偣浜?涓嬫粦浜?杩欑被**鐪熶氦浜?*鎵嶅悓鏃跺仛涓や欢 鈥斺€?鎵€浠ヨ繖閲屼繚鐣欒繖涓粍鍚堝叆鍙ｏ紝
   * 鐢辫皟鐢ㄧ偣鑷繁閫夛紙鍒囬〉閭ｆ潯璺彧璋冨叾涓竴涓紝瑙?`onSwiperIndexChanged`锛夈€?
   */
  private touchChrome(): void {
    this.chromeTouchedAtMs = Date.now();
    this.showChrome();
    this.scheduleChromeAutoHide();
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 瑁佸壀瀹瑰櫒褰㈠彉锛堝鏍囨棤鐣?ExpandAnimation锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /**
   * @returns 鏁撮〉涓嶉€忔槑搴︼細**鎭掍负 1**锛堝鍣ㄦ湰韬笉娣★級銆?
   *
   * 鈿狅笍 杩欓噷鍘熸潵鎸?`p/0.12` 娣″叆鏁翠釜瀹瑰櫒锛屾槸**鎴戣嚜宸辩殑鍙戞槑**锛屽弽缂栬瘧閲?
   *    `applyPullProgress` 涓嶇浠讳綍閫忔槑搴︺€乣overlayColor` 涔熸亽涓?`#00000000`銆?
   *    瀵瑰簲鐨?璧风偣涓嶇┖"鐢辫儗鏅眰鐨?`pullBgIn`锛?鈫?.30锛変笌鍙犲湪鏈€涓婇潰鐨勭画椋炲皝闈?鍏嬮殕灞傝礋璐ｃ€?
   *    鐢ㄦ埛瀹炴祴涔熺‘璁よ繃杩欎竴鐐癸細"鏃犵晫鍔ㄧ敾寮€濮嬩笉鏄€忔槑鐨?銆?
   */
  private morphOpacityValue(): number {
    // 鈽?鑷瘉寰芥爣锛氬姩鐢绘湡闂撮€愬抚鍒锋柊璇绘暟锛堝窘鏍囧叧鐫€鏃跺畠绔嬪埢 return锛岄浂寮€閿€锛夈€?
    //   鏀惧湪杩欓噷鏄洜涓烘湰鍑芥暟**姣忓抚閮借璋冪敤**锛屼笖鍐欑殑鏄袱涓湰椤?`@Local` 瀛楁锛?
    //   涓庡姩鐢荤姸鎬佸畬鍏ㄦ棤鍏筹紙绾彧璇伙級銆傜敤鎴峰湪鍔ㄧ敾**缁撴潫涔嬪悗**璇诲埌鐨勫氨鏄敹灏鹃偅涓€鍒荤殑鍊笺€?
    this.refreshDiagText();
    // 鈽?缁樺埗闂紙瑙?`introPaintReady`锛夛細褰㈠彉寮€濮嬩箣鍓嶆暣椤典笉鐢伙紝閬垮厤閭?1~2 甯ч棯鍑哄畬鏁存挱鏀鹃〉銆?
    // 鈿狅笍 涓ゆ潯**蹇呴』鏀捐**鐨勬儏鍐碉紙鍚﹀垯灏辨槸"鎾斁鐣岄潰鎵撲笉寮€"锛夛細
    //   1. 宸茬粡钀戒綅锛堢浉浣?OPEN锛夆€斺€?鏃犺闂ㄦ槸浠€涔堢姸鎬侊紝闈欐鎬佷竴寰嬭鐢伙紱
    //   2. 鎵嬫寚姝ｅ湪椹卞姩锛堜笂鎷?涓嬫媺璺熸墜锛夆€斺€?閭ｆ潯璺笉杩?`tryStartMorphIntro` 鐨勫紑闂ㄥ垎鏀紝
    //      闂ㄤ細涓€鐩村叧鐫€锛堣繖姝ｆ槸涓婁竴鐗?鎵撲笉寮€鎾斁鐣岄潰"鐨勬牴鍥狅級銆?
    if (this.expandState.morphStage === MorphStage.OPEN || this.introPaintReady ||
      (this.expandState.morphUsable && this.expandState.morphSessionDriving())) {
      return 1;
    }
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER &&
      this.expandState.morphUsable) {
      return 1;
    }
    // 鈽呪槄 2026-10-16锛堢偣鍑绘墦寮€鐨勭浜屽崐锛夛細
    //   杩欎竴娈垫槸"澹冲眰宸蹭负杩欎竴杞捣浜嗗舰鍙樹細璇濓紙`morphSessionStarted`锛夛紝浣嗗嚑浣曡繕娌″帇鍒拌捣鐐?
    //   鈬?杩斿洖 0锛堟暣椤典笉鐢伙級锛屾尅浣?鎸傝浇閭?1~2 甯ч棯鍑哄畬鏁存挱鏀鹃〉"銆?
    //   鈿狅笍 鍓綔鐢紙宸茬煡銆佹帴鍙楋級锛氳繖鍑犲抚閲?*澹冲眰鐨勫厓淇℃伅鍏嬮殕灞傦紙`MorphMetaBridge`锛夎繕鍦ㄧ敾**
    //     锛堝畠鍦ㄧ獥鍙ｅ潗鏍囦笂銆佷笉鍚冩湰椤电殑 opacity锛夆噿 灞忎笂浼氭湁涓€琛屾瓕鍚?姝屾墜鍏堜寒鐫€銆?
    //     杩欐槸鏃犵晫鍚屾瀯鐨勫舰鐘讹紙瀹冪殑 `floatingMeta` 涔熷湪鎾斁椤典箣澶栵級锛?*涓嶅啀鍙﹀仛琛ヤ竵**銆?
    return 0;
  }

  /**
   * 褰㈠彉鏈熼棿"鑳屾櫙鏁村眰"鐨勪笉閫忔槑搴︼紙闈欐鎬佹亽 1锛夈€?
   *
   * 鈽呪槄鈽?2026-10-16锛?*鐓ф妱鏃犵晫 `pullBgOpacity`**锛屼慨鐢ㄦ埛瀹炴祴銆屾挱鏀惧櫒灞曞紑杩樻槸鑳屾櫙鍏ㄥ睆銆嶏級
   *
   * ## 鏃犵晫鐨勫師寮忥紙瀛楄妭鐮侀€愭潯璇诲嚭鏉ョ殑锛?
   *
   * ```
   *   PULL_BG_FLOOR = 0.04          wujie.pa:179978-179979  (fldai 4.0e-2)
   *   PULL_BG_IN_END = 0.30         wujie.pa:179980-179981  (fldai 3.0e-1)
   *
   *   pullPaintable = pullGeomReady && !morphSquashing      wujie.pa:176560-176579
   *   pullBgIn      = clamp(effT / PULL_BG_IN_END)          wujie.pa:176295-176326
   *                   // effT = 褰㈠彉涓?? morphT : 1  鈬?闈欐鎬佹亽 1
   *   pullBgOpacity = !pullPaintable ? 0
   *                                 : PULL_BG_FLOOR + pullBgIn 脳 (1 鈭?PULL_BG_FLOOR)
   *                                                          wujie.pa:176331-176372
   * ```
   *
   * ## 鈿狅笍鈿狅笍 鏈疆**璁㈡涓€澶勬垜璇诲弽浜嗙殑鏋佹€?*锛堝埆鍐嶇収鐫€鏃ф敞閲婃敼鍥炲幓锛?
   *
   * 鎴戝墠涓€鐗堟妸 `pullBgOpacity` 璇绘垚"鐐瑰嚮灞曞紑鏃?`pullPaintable()` 涓哄亣 鈬?鑳屾櫙涓嶇敾"锛?
   * 骞舵嵁姝よ鏈嚱鏁板湪闈炶窡鎵嬪舰鍙樻椂 `return 0`銆?*璇诲弽浜?*锛?
   *
   * * `jnez L` 鐨勮涔夋槸"**鏉′欢涓哄亣**鏃惰烦"锛堝凡鐢?`playerSwiperGapOf` 閭ｆ妸灏哄瓙閽夋锛夛紱
   * * `lda pullPaintable(); isfalse; jnez L2` 鈬?**`pullPaintable() === true` 鏃惰烦鍒?L2**锛?
   *   鑰?L2 鎵嶆槸"绠?`PULL_BG_FLOOR + pullBgIn 脳 0.96`"閭ｄ竴鏀紱
   * * 鍙湁 `pullPaintable()` 涓哄亣鎵?`ldai 0x0; return`銆?
   *
   * 鑰?`pullPaintable = pullGeomReady && !morphSquashing`锛坄morphSquashing` 鍙湪
   * 鍏抽棴钀戒綅閭ｄ竴璁版尋鍘嬫湡闂翠负鐪燂級鈬?**涓婃媺/鐐瑰嚮灞曞紑鍏ㄧ▼涓虹湡** 鈬?**鑳屾櫙鍏ㄧ▼閮界敾**銆?
   * 鈬?鐢ㄦ埛瀹炴祴銆?*鏃犵晫鍔ㄧ敾杩囩▼鏈夎儗鏅殑锛堣嚦灏戝疄鏈烘槸杩欐牱锛?*銆嶆鏄繖鏉＄嫭绔嬭瘉鎹€?
   *
   * ## 缁撹锛堟湰浠撴槧灏勶級
   *
   * | 鍦烘櫙 | 缁撴灉 |
   * | --- | --- |
   * | 闈欐鎬?| 1 |
   * | 褰㈠彉涓?| `PULL_BG_FLOOR + pullBgIn 脳 (1 鈭?PULL_BG_FLOOR)` = `0.04 鈫?1`锛坄pullIn 鈮?0.30` 鍚庢亽 1锛?|
   * | 钀戒綅鎸ゅ帇锛坄morphSquashing`锛?| 0锛堟棤鐣岄偅涓€妗ｄ篃涓€鏍凤級 |
   *
   * 鈿狅笍 鏃ф敞閲婇噷"**涓嶈**鐓ф妱 `clamp(p/0.30)`"閭ｆ潯缁撹**宸蹭綔搴?*锛氬畠鎷呭績鐨勬槸"鑳屾櫙灞傚湪
   * **琚鍓殑灏忕獥鍙ｉ噷**銆?0% 灏辨弧涓嶉€忔槑 鈬?绐楀彛閲屼竴鏁村潡榛?銆傝€岃儗鏅眰鐜板湪鏄?*鍦ㄨ鍓鍣ㄥ唴閮?*
   * 锛埪?0 鐓ф惉鏃犵晫鐨勫眰绾э級锛岄偅涓舰鐘朵笉瀛樺湪浜嗐€?
   *
   * 鈿狅笍 **2026-10-16 浜屾璁㈡锛堢敤鎴峰疄娴嬨€岀偣鍑绘墦寮€/鐐瑰嚮鍏抽棴/绯荤粺杩斿洖杩樻槸娌℃湁銆嶏級**锛?
   *   涓嬮潰閭ｅ彞 `if (this.expandState.morphSquashY !== 1) return 0;` **鏄敊鐨?* 鈥斺€?
   *   瀹冩湰鎰忔槸褰?钀戒綅鎸ゅ帇"锛堟棤鐣?`morphSquashing`锛夛紝浣?`morphSquashY` 鍦?*鐐瑰嚮/杩斿洖**杩欐潯璺笂
   *   涔熶細涓嶇瓑浜?1锛堝叧闂惤浣嶉偅涓€璁?110ms+320ms 鐨勬尋鍘嬶級锛屼簬鏄暣鏉¤矾鐨勮儗鏅鍘嬫垚 0
   *   鈬?鐢ㄦ埛鐪嬪埌鐨勬槸"**鍙湁涓婃媺閭ｆ潯鏈夎儗鏅?*"銆?
   *   鈬?鐜板湪鏀规垚锛?*鍙鏈夊舰鍙橈紝鑳屾櫙灏辨寜 `pullBgIn` 涓婃贰鍏?*锛屼笉鍐嶅 Drive 鎴栨尋鍘嬪仛鐗规畩鍒ゆ柇銆?
   *     鑳屾櫙宸茬粡琚鍣ㄨ鍓紙搂90锛夛紝鎵€浠?褰㈠彉鏃╂湡鏁村睆"杩欎釜椤捐檻鏈韩涔熶笉瀛樺湪浜嗐€?
   *
   * 鈿狅笍 瀹冨悓鏃剁鐫€锛氬灚搴曞眰銆佸彇鏍疯壊灞傘€佺綉鏍煎眰銆佸緞鍚戞殫瑙?鈥斺€?鏀瑰畠绛変簬鏀硅繖鍥涘眰銆?
   * 鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdBgOpacity'`
   * @returns 0..1锛堥潤姝㈡€?= 1锛?
   */
  private backgroundRevealOpacity(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    // 鈽呪槄鈽呪槄鈽?2026-10-17锛?*閫愬瓧鐓ф惉鏃犵晫閭ｄ袱濂楀彇鍊?*锛宍wujie.pa:192161-192176`锛?
    //
    // 鏃犵晫鑳屾櫙灞傚闈㈤偅涓?`__Common__` 鏄細
    // ```
    //   __Common__().opacity(pullMode ? this.pullBgOpacity() : this.expand.contentOpacity)
    // ```
    //   路 **涓嬫媺閭ｆ潯**锛坄pullMode`锛夎蛋 `pullBgOpacity() = PULL_BG_FLOOR + pullBgIn脳0.96`
    //     鈥斺€?璺熸墜鏃?`pullBgIn = clamp(effT/0.30)` 鎵嶆湁鎰忎箟锛坄effT` 璺熺潃鎵嬫寚杩炵画鍙橈級锛?
    //   路 **鍏朵綑鍏ュ彛**锛堢偣鍑绘墦寮€ / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖锛夎蛋 **`expand.contentOpacity`**
    //     鈥斺€?閭ｆ槸鍐呭灞備笉閫忔槑搴︼紝涓嶆槸璺熸墜閭ｆ潯娣″叆銆?
    // 鎴戜滑涔嬪墠鎶婁袱鏉¤矾閮芥寜 `pullBgOpacity` 绠楋紝鑰岃ˉ闂撮棴鍖呴噷 `applyMorphProgress(0|1)`
    // 鎶?`morphP` 涓€娆℃€у啓鎴?0 鈬?鍏抽棴鍔ㄧ敾鍏ㄧ▼ 0.04 鈬?灞忎笂鍙墿搴曡壊 = "榛?銆?
    // 鈬?鐜板湪鐓т笂娓稿垎娴侊細`pullMode` 涓哄亣鏃跺彇 `morphContentOpacity`锛堟湰浠撴亽 1锛夈€?
    // 鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdBgLayer'`锛堢湅 `op=` 涓?`p=`锛?
    if (!this.expandState.pullMode) {
      return this.expandState.morphContentOpacity;
    }
    return PlaybackPage.PULL_BG_FLOOR + this.pullBgIn() * (1 - PlaybackPage.PULL_BG_FLOOR);
  }

  /** 鏃犵晫 `PULL_BG_FLOOR`锛坄wujie.pa:179978-179979`锛宍fldai 4.0e-2`锛夈€?*/
  private static readonly PULL_BG_FLOOR: number = 0.04;

  /** 鏃犵晫 `PULL_BG_IN_END`锛坄wujie.pa:179980-179981`锛宍fldai 3.0e-1`锛夈€?*/
  private static readonly PULL_BG_IN_END: number = 0.30;

  /**
   * @returns 鏃犵晫 `pullBgIn() = clamp(effT / PULL_BG_IN_END)`锛坄wujie.pa:176295-176326`锛夈€?
   *
   * `effT = 褰㈠彉涓?? morphT : 1` 鈬?闈欐鎬佹亽 1锛堝嵆 `pullBgIn = 1`锛夈€?
   * 鈿狅笍 鏈粨鐨?褰㈠彉杩涘害"瀵瑰簲 `morphP`锛堝睍寮€ 0鈫? / 鏀惰捣 1鈫?锛夛紝涓庢棤鐣岀殑 `morphT` 鍚屽彛寰勩€?
   */
  private pullBgIn(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    const raw: number = this.expandState.morphP / PlaybackPage.PULL_BG_IN_END;
    return raw < 0 ? 0 : (raw > 1 ? 1 : raw);
  }

  /**
   * 鎺掑畾鑷姩鏀惰捣銆?
   *
   * 鐢?`setTimeout` 鑰屼笉鏄?`setInterval`锛氬彧瑕佹瘡娆′氦浜掗噸鏂版帓涓€娆″氨澶熶簡锛?
   * 甯搁┗瀹氭椂鍣ㄤ細鍦ㄩ〉闈笉鍙鏃剁┖杞紙鎾斁椤电粡甯搁暱鏃堕棿鎸傜潃锛夈€?
   */
  private scheduleChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
    this.chromeTimerId = setTimeout((): void => {
      this.chromeTimerId = -1;
      if (!this.isAlive || this.chromeCollapsed || !this.canHideLyricChrome() || !this.state.isPlay) {
        return;
      }
      // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`hideChrome()` 鐨?闈㈡澘寮€鐫€灏变笉鏀?锛宍abc.txt:4124-4225`锛夛細
      //   閭ｄ竴鏉℃槸 10 涓潰鏉?flag 鐨勭煭璺垨閾撅紱鏈粨鐨勫垎閲忚 `auxSheetOpen` 鐨勬敞閲?
      //   锛堣彍鍗曚竴鏃?鈫?`playMenuOpen`锛涢槦鍒?鍏朵粬鐗堟湰 鈫?`auxSheetOpen`锛夈€備袱涓兘瑕佸垽銆?
      if (this.playMenuOpen || this.auxSheetOpen) {
        Logger.info('RzdLyricChrome',
          `hide skipped (panel open: menu=${this.playMenuOpen ? 1 : 0} aux=${this.auxSheetOpen ? 1 : 0})`);
        return;
      }
      // 姝ｅ湪鏀惰捣/灞曞紑鎾斁鍣ㄦ椂涓嶆墦鎵?
      if (this.isCollapsing()) {
        return;
      }
      this.getUIContext().animateTo({
        duration: PlaybackPage.CHROME_ANIM_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        this.chromeCollapsed = true;
        this.lyricChromeProgress = 0;
        Logger.info('RzdLyricChrome', `hide auto naturalHeight=${this.lyricChromeHeight}`);
      });
    }, PlaybackPage.CHROME_AUTO_HIDE_MS);
  }

  /**
   * @returns 鎺у埗鍖烘槸鍚﹀彲浠?鏀惰捣鏉?锛堣嚜鍔ㄧ┖闂叉敹璧?+ 鎷栧姩鏀惰捣鍏辩敤杩欎竴鎶婇棬锛夈€?
   *
   * 鈽呪槄鈽?2026-10-17锛?*璁㈡涓婁竴杞殑涓€涓敊缁撹 鈥斺€?瀹冨綋鏃跺彧鐪?`startIdle` 鍐呴儴锛屾紡浜嗘墍鏈夎皟鐢ㄧ偣**锛夈€?
   *
   * ## 鏃犵晫鐨勪簨瀹烇細绌洪棽鏀惰捣**鍙湪姝岃瘝椤靛彂鐢?*
   *
   * 涓婁竴杞垜璇诲埌 `startIdle()`锛坄PlayerPage.abc.txt:12394-12435`锛夐噷閭ｉ亾闂ㄦ槸
   * `entryAllowsAuto(this.lyricImmersive)`锛岃€?`lyricImmersive` 鏄?*鐢ㄦ埛鍋忓ソ**
   * 锛坄wujie.pa:169823-169825`锛歚this.lyricImmersive = pref.lyricImmersiveMode`锛?
   * 鈬?浜庢槸鍐欎簡銆?*鏃犵晫鐨勯棬涓?褰撳墠鍦ㄥ摢涓€椤?鏃犲叧 鈬?灏侀潰椤典篃浼氱┖闂叉敹璧?*銆嶏紝
   * 骞舵妸鏈柟娉曟斁瀹藉埌 `usesPhoneSwiperLayout()`銆?
   * **閭ｄ釜鎺ㄨ鏄敊鐨?* 鈥斺€?椤甸潰鐨勯檺鍒朵笉鍦?`startIdle` 閲岋紝鑰屽湪**瀹冪殑姣忎竴涓皟鐢ㄧ偣**涓婏細
   *
   * | 璋冪敤鐐?| 瀛楄妭鐮?| 鏉′欢 |
   * | --- | --- | --- |
   * | swiper `onChange` | `abc.txt:23189-23215` | **`index === 1`锛堟瓕璇嶉〉锛夆噿 `startIdle()`**锛涘惁鍒?鈬?`clearIdle() + showChrome()`锛?*涓嶈捣璁℃椂**锛?|
   * | 姝岃瘝鍖鸿Е鎽告姮璧峰墠 | `abc.txt:6914-6932`锛坄onLyricInteract`锛?| 浠呭湪**姝岃瘝椤?*涓?`!chromeHidden` 鏃?`startIdle()` |
   * | 姝岃瘝鍖轰笅婊?| `abc.txt:6938-6985`锛坄onLyricSwipe`锛宍offsetY 鈮?SWIPE_TOGGLE_VP 24`锛?| 浠呭湪**姝岃瘝椤?*锛歚showChrome() + startIdle()` |
   * | 娌夋蹈妯″紡鍙樻洿 | `abc.txt:7766-7800` | `entryAllowsAuto(mode) && !chromeHidden && swiperProgress > 0.5` |
   *
   * 鈬?**鍥涗釜璧风偣鍏ㄥ湪姝岃瘝椤碉紝鑰屽垏鍒板皝闈㈤〉閭ｄ竴鏀槸鏄惧紡鐨?`clearIdle()`**
   *   鈬?**鏃犵晫鍦ㄥ皝闈㈤〉涓嶄細绌洪棽鏀惰捣鎺у埗鍖?*銆?
   *   鈽?鑰屼笖杩欐鏄敤鎴锋棭鍏堟姤鐨勯偅涓€鏉★細銆屾湁鏃?*鎾斁椤甸椤?*涓嬫柟鍑犱釜鎸夐挳涔熶細闅愯棌銆嶁€斺€?
   *     灏侀潰椤甸殣钘忔槸**鎴戜滑**甯﹁繘鏉ョ殑琛屼负锛屼笉鏄棤鐣岀殑銆?
   *
   * ## 鐜板湪鐨勫垽鎹?
   * 鎵嬫満 Swiper 甯冨眬锛堝皝闈㈤〉/姝岃瘝椤佃繖濂楋級**涓?*鍋滃湪姝岃瘝椤点€?
   * 鈿狅笍 杩欎笌涓婁竴杞箣鍓嶇殑鍐欐硶涓€鑷达紙`WIDTH_SM && 姝岃瘝椤礰锛夛紝宸埆鍙槸瀹藉害鍒ゆ嵁鎹㈡垚浜?
   *   `usesPhoneSwiperLayout()`锛堜笌 `Swiper` 鐪熷疄鏄惁浣跨敤鍚屼竴鍙ｅ緞锛屾洿纭級銆?
   * 鈿狅笍 鏈棬鏄?鑷姩鏀惰捣 + 鎷栧姩鏀惰捣"鍏辩敤鐨?鈥斺€?涓よ€呮寜鏃犵晫涔?*閮藉彧鍦ㄦ瓕璇嶉〉**璧蜂綔鐢?
   *   锛坄BarCollapse` 鎸傚湪姝岃瘝椤甸偅濂楁帶鍒跺尯涓婏級銆?
   */
  private canHideLyricChrome(): boolean {
    return this.usesPhoneSwiperLayout() &&
      this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
  }

  private hideLyricChrome(): void {
    if (!this.canHideLyricChrome() || this.chromeCollapsed) {
      return;
    }
    // 鈽?鍚屼竴鏉″畧鍗紙瑙?`scheduleChromeAutoHide` 閲岀殑璇存槑锛夛細闈㈡澘寮€鐫€灏变笉鏀躲€?
    if (this.playMenuOpen || this.auxSheetOpen) {
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
    Logger.info(PlaybackPage.logTag, 'lyric chrome hidden: upward gesture');
  }

  /**
   * Swiper 鎹㈤〉鏃剁殑鎺у埗鍖烘敹灏?鈥斺€?**鐓ф惉鏃犵晫閭ｄ釜 `onChange` 位 鐨勯€愬瓧缁撴瀯**
   * 锛坄_recover/logic-src/PlayerPage.abc.txt:23189-23215`锛夈€?
   *
   * 鈽呪槄鈽?2026-10-17锛坓oal 鏀跺熬澶嶆牳锛?*鍥炲師濮嬪瓧鑺傜爜纭**锛屽嚭澶?
   *   `_recover/disasm/wujie.pa:190080-190111`锛屽嵆 `PlayerPage.@34*^1*#^1`锛夛細
   * ```ts
   *   onChange(index) {                                  // a3 = index
   *     const L = 1;                                     // 190081-190082锛? SWIPER_INDEX_LYRIC锛?
   *     if (index === L) { this.startIdle(); }            // 190083-190089  鈫?姝岃瘝椤碉細璧疯鏃?
   *     else { this.clearIdle(); this.showChrome(); }     // 190091-190099  鈫?灏侀潰椤碉細鍋滆鏃?+ **鏄惧紡鍞ゅ嚭**
   *     this.atLyricScreen = (index === L);               // 190100-190105
   *     this.syncKeepScreenOn();                          // 190106-190109
   *   }
   * ```
   * 鈬?**绌洪棽璁℃椂鍙湪姝岃瘝椤佃捣**杩欎竴鐐癸紝鏄笂娓哥殑**鏄惧紡鍒嗘敮**锛堜笉鏄垜浠帹鏂殑锛夆湏
   *    鈥斺€?goal 绗?4 鏉°€岀┖闂茶鏃躲€嶅埌姝?*鏈夋嵁鍙煡**锛屼笉闇€瑕佸啀鏍搞€?
   *    锛堝彟锛歚startIdle` 鐨勬椂闀垮父閲?`IDLE_MS` 鍙湪璇ュ嚱鏁伴噷鍑虹幇涓€娆★紝
   *      `wujie.pa:179903-179985`锛涙湰浠撳搴?`PlaybackPage.CHROME_AUTO_HIDE_MS = 5000`銆傦級
   *
   * 鈿狅笍 鎴戜滑鍘熸潵鏄棤鏉′欢 `touchChrome()`锛? 鍞ゅ嚭 **+** 璧疯鏃讹級锛屽啀鍦ㄩ潪姝岃瘝椤佃ˉ涓€鍙?
   *   `stopChromeAutoHide()`銆傞偅鏍峰湪**鍒囧埌灏侀潰椤?*鏃舵槸"鍏堣捣璁℃椂鍐嶅仠鎺?锛?
   *   鍑€鏁堟灉铏界劧涔熷锛屼絾涓庢棤鐣?閭ｉ噷鏍规湰涓嶅敜鍑?vs 杩欓噷浼氬敜鍑?鐨勫樊鍒鎶规帀浜?鈥斺€?
   *   鏃犵晫鍒囧埌灏侀潰椤垫槸**鏄惧紡鍞ゅ嚭**锛堢敤鎴蜂粠姝岃瘝椤垫粦鍥炴潵鏃舵帶鍒跺尯涓€瀹氭槸浜殑锛夛紝
   *   杩欎竴鏉℃垜浠宸т篃瀵癸紝浣?*鍔ㄦ満涓嶅悓**锛屼笖灏戜簡"姝岃瘝椤甸偅涓€鏀笉鍞ゅ嚭"銆?
   *
   * 鈿狅笍 鍙︽湁**鏈夋剰鏀剁獎**锛氭垜浠偅涓€鏀噷澶氫竴閬?`canHideLyricChrome()`
   *   锛? `usesPhoneSwiperLayout() && 鍋滃湪姝岃瘝椤礰锛夆噿 瀹藉睆/闈㈡澘閭ｄ袱鏀笉璧疯鏃躲€?
   *   涓婃父 `startIdle` 鑷繁杩樻湁娌夋蹈妯″紡绛夊唴閮ㄩ椄锛堟湰浠撳搴?`entryAllowsAuto` 閭ｆ潯锛夈€?
   *
   * @param index 鏂扮殑椤典笅鏍囷紙0 = 灏侀潰椤碉紝1 = 姝岃瘝椤碉級
   */
  private onSwiperIndexChanged(index: number): void {
    if (index === PlaybackPage.SWIPER_INDEX_LYRIC) {
      // startIdle锛歚scheduleChromeAutoHide()` 鍐呴儴鑷甫"`canHideLyricChrome()` 涓嶆垚绔嬪氨涓嶆敹"
      this.scheduleChromeAutoHide();
      return;
    }
    this.stopChromeAutoHide();
    this.showChrome();
  }

  /**
   * 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣?`BarCollapse`锛夛細**鎷栧姩鎺у埗鏉℃敹璧?/ 灞曞紑**銆?
   *
   * 鏃犵晫鐨勬墜鍔跨姸鎬佹満锛坄design/src/main/ets/logic/BarCollapse.ets`锛屽瓧鑺傜爜
   * `wujie.pa:83706-84140`锛夊凡閫愭潯杞啓鍒?`common/musicbasic/.../model/BarCollapse.ets`
   * 锛堝惈 `THRESHOLD = 1.5`銆佽酱鍚戦攣瀹氥€乣run` 绱Н銆佺洰鏍囦竴鑷翠笉鍔ㄤ綔銆?*250ms 鑺傛祦**锛夈€?
   * 鏈柟娉曞彧鍋氫袱浠朵簨锛?*鎶婅Е鎽镐簨浠跺杺杩涘幓** + **鎸夊畠杩斿洖鐨勫姩浣滈┍鍔ㄦ敹璧?灞曞紑**銆?
   *
   * 璇箟锛堢収鎶勫悗鐨勮涓猴級锛?
   * ```
   *   路 绾靛悜涓嬫媺绱 鈮?鈭?.5vp 鈬?COLLAPSE锛堟帶鍒跺尯鏀惰捣锛?
   *   路 绾靛悜涓婃帹绱 鈮?+1.5vp 鈬?EXPAND  锛堟帶鍒跺尯灞曞紑锛?
   *   路 妯悜閿佸畾 鈬?鏁翠覆鎵嬪娍蹇界暐锛堜笉浼氬拰姝岃瘝妯粦鎵撴灦锛?
   * ```
   * 鈿狅笍 鍔ㄧ敾娌跨敤鏈〉鏃㈡湁鐨勯偅涓€濂楋紙`chromeCollapsed` + `lyricChromeProgress`锛?40ms `EaseOut`锛夛紝
   *   涓庤嚜鍔ㄦ敹璧凤紙3s 绌洪棽锛?*鍏辩敤鍚屼竴鏉¤矾寰?* 鈬?涓ょ鍏ュ彛瑙傛劅涓€鑷淬€?
   * 鈿狅笍 鏀惰捣闂ㄦ部鐢?`canHideLyricChrome()` 鈥斺€?**涓庤嚜鍔ㄦ敹璧枫€佹嫋鍔ㄦ敹璧峰悓涓€鎶婇棬**
   *   锛堢収鎼棤鐣?`startIdle` 鍚庡畠宸叉斁瀹藉埌"鎵嬫満 Swiper 甯冨眬"锛屽惈灏侀潰椤碉紝瑙侀偅涓柟娉曠殑娉ㄩ噴锛夈€?
   *   鎵€浠ヤ笉浼氬嚭鐜?鑷姩鑳芥敹銆佹嫋鍔ㄤ笉鑳芥敹"杩欑涓嶄竴鑷淬€?
   * @param event 鎺у埗鍖哄鍣ㄤ笂鐨勮Е鎽镐簨浠?
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
      this.hideLyricChrome();
    } else if (action === BarAction.EXPAND) {
      Logger.info(PlaybackPage.logTag,
        `RzdBarCollapse action=EXPAND collapsed=${this.barCollapse.isCollapsed()} axis=${this.barCollapse.lockedAxis()}`);
      // 灞曞紑 = 鏈〉鏃㈡湁鐨?鍞ゅ嚭鎺у埗鍖?锛坄touchChrome()` 閲岄偅娈?240ms 鍔ㄧ敾 + 閲嶇疆绌洪棽璁℃椂锛?
      this.touchChrome();
    }
  }

  /** 鍋滄帀鑷姩鏀惰捣璁℃椂锛堥〉闈㈠嵏杞姐€佸紑濮嬫敹璧锋挱鏀惧櫒鏃惰皟鐢級銆?*/
  private stopChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
  }

  /**
   * 鐓ф惉鏃犵晫 `PlayerPage.onLyricInteract()`锛坄_recover/logic-src/PlayerPage.abc.txt:6914-6932`锛夛細
   *
   * ```ts
   *   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
   * ```
   * 鎸傝浇鐐瑰湪鍚屾枃浠?`190116-190130`锛氬彧鏈?**`TouchType.Down`** 璋冨畠銆?
   *
   * 鈿狅笍 涓や釜"涓嶈鎼為敊"锛?
   *   路 瀹?*鍙捣璁℃椂**锛坄startIdle`锛夛紝**涓嶅敜鍑?*鎺у埗鍖?鈬?杩欓噷鐢?`scheduleChromeAutoHide()`
   *     鑰?*涓嶆槸** `touchChrome()`锛堝悗鑰?= `showChrome()` + 璧疯鏃讹紝鏄彟涓€鏉¤矾涓婄殑缁勫悎锛夈€?
   *   路 鏉′欢鏄?`!chromeHidden`锛堝凡缁忔敹璧锋椂**涓嶈捣**璁℃椂锛夆噿 杩欓噷瀵瑰簲 `!chromeCollapsed`銆?
   */
  private onLyricInteract(): void {
    if (this.chromeCollapsed) {
      return;
    }
    this.scheduleChromeAutoHide();
  }

  /**
   * 澹冲眰鎷﹀埌绯荤粺杩斿洖锛堣姹傚叧闂挱鏀鹃〉锛夆啋 鎾敹璧峰姩鐢伙紝涓嶈鐩存帴娑堝け銆?
   *
   * 鈽呪槄 2026-10-15锛堝洖閫€鍚庨噸鍋氾級锛?*鍒犳帀鍘熸潵閭ｅ彞 `setTimeout(0)`**銆?
   *   褰撳勾鐨勬敞閲婂啓鐨勬槸"涓嶈鍦?`@Monitor` 鍥炶皟閲岀洿鎺?`animateTo`锛屾湁鍙兘涓嶆彃鍊? 鈥斺€?
   *   杩欎釜鐜拌薄鏄湡瀹炲瓨鍦ㄧ殑锛屼絾鏍瑰洜涓嶆槸"鍔ㄧ敾浣滅敤鍩?锛岃€屾槸瀹樻柟鐨?
   *   **銆屽湪 `@Monitor` 涓Е鍙?`animateTo` 鏃朵笉鏄剧ず鍔ㄧ敾銆?*锛?
   *   V2 鐘舵€佸彉閲忎慨鏀规槸寮傛鏍囪剰锛圥romise 寰换鍔★級锛岃€?`animateTo` 绔嬪埢鍒锋柊鑴忚妭鐐瑰喅瀹氶甯э紱
   *   鍦?`@Monitor` 鍥炶皟閲岃ˉ闂磋繕娌″紑濮嬶紝琚洃鍚殑鐘舵€佸氨宸茬粡鍦ㄦ爣鑴忛槦鍒楅噷 鈬?棣栧抚/鎻掑€间笉瀵广€?
   *   瀹樻柟锛坄arkts-new-applysync-flushupdates-flushuiupdates`銆屼娇鐢ㄥ満鏅?路 鍔ㄦ晥鍦烘櫙銆嶏級缁欑殑鍐欐硶
   *   灏辨槸鍦?`animateTo` 鐨勯棴鍖呴噷鐢?`UIUtils.applySync` 鍚屾鍒锋柊鐩爣鍊?鈥斺€?
   *   `closeFullScreenPlayback()` 閲屽凡缁忔寜杩欎釜鍐欐硶鏀逛簡锛屾墍浠ヨ繖閲屽彲浠ョ洿鎺ヨ皟鐢ㄣ€?
   */
  @Monitor('expandState.collapseVersion')
  onCollapseRequested(): void {
    // 鈽呪槄鈽呪槄 2026-10-17锛堢収鎼棤鐣?`MainPage.closeWithAnimation()` 鐨勯潪鎵嬪娍鍒嗘敮锛夛細
    //   杩欐潯 Monitor 鏄?*鍞竴**鐨?闈炴墜鍔垮叧闂?鍏ュ彛锛坄guardPlayerBack()` / 澹冲眰 `onBackPress()`
    //   閮借蛋 `expandState.requestCollapse()` 鈬?`collapseVersion++`锛夈€?
    //   涓嬫媺閭ｆ潯璺?*涓嶇粡杩囪繖閲?*锛堝畠鐩存帴璋?`closeFullScreenPlayback()`锛夈€?
    //   鈬?鎵€浠ヨ繖閲屾濂藉搴旀棤鐣岀殑 `pullMode === false` 閭ｄ竴鏀細**鎷嶅揩鐓х缉鍥撅紝涓嶅姩娲婚〉闈?*銆?
    this.closeWithAnimation();
  }
  /** Fallback page background tint when art or color pick fails. */
  private static readonly defaultImageBgColor: string = 'rgba(32, 32, 32, 1)';

  /** 鑳屾櫙缃戞牸婧愯繕娌″埌鎵嬫椂鐨?*鏈夌晫閲嶅彇**娆℃暟锛堣 {@link scheduleBackgroundRetry}锛夈€?*/
  private static readonly BG_RETRY_MAX: number = 4;
  /** 涓ゆ閲嶅彇涔嬮棿鐨勯棿闅旓紙ms锛夈€?*/
  private static readonly BG_RETRY_MS: number = 400;

  /**
   * 鑳屾櫙缃戞牸婧愯繕娌″埌鎵?鈬?闅斾竴浼氬効鍐嶅彇涓€娆★紙**鏈夌晫**锛夈€?
   *
   * 涓轰粈涔堥渶瑕佸畠锛堢敤鎴峰疄娴嬶級锛氭湭鎾斁鐘舵€佺偣鍑绘墦寮€鎾斁鍣ㄦ椂鑳屾櫙鏄粦鐨?鈥斺€?
   * 鍥犱负鍦ㄧ嚎姝屾洸鐨勭湡姝ｈ儗鏅槸**缃戞牸鍥?*锛岃€屽畠瑕佺瓑 `song.cover` 鍒版墜鎵嶈В寰楀嚭鏉ワ紱
   * 鎾斁鐘舵€佷細椤烘墜鎶?metadata 鎷夐綈锛屾墍浠?鐐逛竴涓嬫挱鏀惧氨姝ｅ父"銆?
   * 鑳屾櫙鍙璺?灏侀潰鏈夋病鏈夊埌鎵?鏈夊叧 鈬?杩欓噷缁欏畠涓€涓?*鏀舵暃**鐨勬満浼氥€?
   * @param jobSeq 鍙戣捣閭ｆ鍙栬壊鐨勫簭鍙凤紙鐢ㄥ畠鍙互涓㈠純杩囨湡鐨勪竴杞級
   * @param attempt 宸查噸璇曟鏁?
   */
  private scheduleBackgroundRetry(jobSeq: number, attempt: number): void {
    if (!Number.isFinite(attempt) || attempt >= PlaybackPage.BG_RETRY_MAX) {
      Logger.info(PlaybackPage.logTag,
        `RzdBgRetry give up attempt=${attempt} meshVer=${this.meshSrcVersion}`);
      return;
    }
    setTimeout((): void => {
      // 涓夐亾闂細椤甸潰杩樺湪銆佽繖涓€杞病琚柊鐨勪竴杞《鎺夈€侀〉闈㈣繕鐪嬪緱瑙?
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
   * 鍙栬壊瀹屾垚鍚庢妸鏂伴鑹茬亴杩涙祦鍏夌潃鑹插櫒銆?
   *
   * 鐢?`setEffectParams`锛堣€屼笉鏄噸寤?`visualEffect`锛夛細鎹㈡瓕鍙洿鏂?uniform锛?
   * 涓嶄細閲嶅惎鐫€鑹插櫒銆佷篃涓嶄細璁╂祦鍏?璺?鍥炶捣鐐广€?
   */
  @Monitor('coverTint.version')
  onCoverTintVersionChange(): void {
    this.applyFlowLightColors();
  }

  /**
   * 鈽呪槄 2026-10-14 淇€屾祦鍏夎儗鏅紑鍏崇粡甯镐笉璺熼殢璁剧疆銆嶏細
   *
   * 鍏变韩鐘舵€?`PlaybackFlowLightState` 鏄?*鏂板垱寤?*鐨勶紙榛樿 false锛夛紝璋侀兘娌℃妸 `MusicStoreService`
   * 閲屾寔涔呭寲鐨勯偅涓€肩亴杩涘幓 鈥斺€?鍙湁璁剧疆椤靛垏寮€鍏虫椂鎵嶄細鍐欏叡浜姸鎬併€備簬鏄細**寮€鐫€娴佸厜 鈫?閲嶅惎 App 鈫?
   * 鎾斁椤佃鍒扮殑杩樻槸榛樿 false**锛堣缃〉娌¤繘鍘昏繃灏变竴鐩撮敊鐫€锛夛紝鐢ㄦ埛鐪嬪埌鐨勫氨鏄?寮€鍏充笉璺熼殢璁剧疆"銆?
   *
   * 鈿狅笍 2026-10-17锛?*鍒犻櫎浜嗕竴鍏峰悓鍚嶅案浣?*锛夛細杩欓噷鍘熸潵杩樻湁涓€涓?
   *   `syncFlowLightPreference(reason)` 鏂规硶锛屽仛鐨勬槸"**store 鈫?鍏变韩鐘舵€?*"杩欎竴鍚戯紱
   *   浣嗙湡姝ｈ窇鐨勬槸 `aboutToAppear` 閲岄偅鍙ョ洿鎺ヨ祴鍊?
   *   锛坄this.flowLightState.enabled = MusicStoreService鈥etPlaybackFlowLight()`锛夛紝
   *   鑰?*鍙嶅悜**锛堝叡浜姸鎬?鈫?钀藉簱锛夌敱涓嬮潰鐨?`onFlowLightEnabledChange()` 璐熻矗銆?
   *   鈬?閭ｄ釜鏂规硶**闆惰皟鐢ㄧ偣**銆佸彧鏄?鍚屼竴浠朵簨鐨勪袱濂楀啓娉?锛堝畠澶氫竴鏉℃棩蹇?+ 涓€娆″浣欑殑鍙栬壊锛夛紝
   *     鐣欑潃灏辨槸"鍚庢潵浜烘敼閿欏湴鏂?鐨勫叆鍙?鈬?宸插垹闄わ紱姝ゅ淇濈暀璇存槑锛屽厤寰楀張琚噸鏂板姞鍥炴潵銆?
   */
  @Monitor('flowLightState.enabled')
  onFlowLightEnabledChange(): void {
    const stored: boolean = MusicStoreService.getInstance().getPlaybackFlowLight();
    if (stored !== this.flowLightState.enabled) {
      MusicStoreService.getInstance().setPlaybackFlowLight(this.flowLightState.enabled);
      Logger.info('RzdFlowLight', `pref persist enabled=${this.flowLightState.enabled}`);
    }
    if (!this.flowLightState.enabled || this.context === undefined || !this.isAlive) {
      return;
    }
    this.getImageColor();
  }

  /**
   * 鈽呪槄鈽?2026-10-17锛?*鐓ф惉鏃犵晫 `MorphGuard` 鐨?閰嶈壊瀹夐潤绐楀彛"** 鈥斺€?瑙?`morphQuietUntilMs` 鐨勬帹瀵硷級
   *
   * @returns 鐜板湪**涓嶈兘**涓婅壊鏃惰繕瑕佺瓑澶氬皯 ms锛? = 鍙互绔嬪嵆涓婅壊锛夈€?
   *   鈿狅笍 涓嶈兘涓婅壊鏃舵湰鍑芥暟浼?*椤烘墜鎺掍竴娆￠噸璇?*锛堝箓绛夛細`colorRetryQueued` 鍙厑璁镐竴鏉″湪椋烇級锛?
   *   閲嶈瘯闂撮殧 = `wait + 32ms`锛堟棤鐣岄偅涓?`0x20` 浣欓噺锛夛紝涓庢棤鐣?`MainPage` 鐨勫啓娉曢€愭潯瀵瑰簲銆?
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
        // 鈽?2026-10-17锛氶〉闈㈠凡閫€鍦哄氨鍒啀涓婅壊/琛ョ綉鏍?鈥斺€?
        //   鏈〉鐨勫彇鑹查摼璺湪閫€鍦烘椂浼氫富鍔ㄩ噴鏀句綅鍥撅紙瑙?`onDisappear` 閲岄偅涓ゅ彞 `releasePixelMapQuiet`锛夛紝
        //   鑻ヨ繖鏉￠噸璇曡繕鍘?`commitMeshSource`锛岄偅灏辨槸鎷夸竴寮?*宸茬粡閲婃斁杩囩殑**浣嶅浘鍘绘崲婧愩€?
        if (!this.isAlive) {
          return;
        }
        // 涓庢棤鐣岄偅涓噸璇?位 涓€鑷达細鍏堟斁寮€骞傜瓑鏍囪锛屽啀鎶婁笂鑹查噸璺戜竴閬?
        // 锛堟棤鐣岃皟鐨勬槸 `syncReportChrome()`锛涙湰浠撳搴旂殑灏辨槸杩欎袱涓笂鑹茬偣锛夈€?
        this.applyFlowLightColors();
        this.republishMeshSourceIfAny();
      }, wait + 32);
    }
    Logger.info(PlaybackPage.logTag,
      `RzdFlowLight color apply deferred ${wait.toFixed(0)}ms (morph quiet window)`);
    return wait;
  }

  /** 鎶?{@link coverTint} 閲岀殑棰滆壊鎺ㄧ粰鐫€鑹插櫒锛堝悓鐗堟湰鍙峰彧鎺ㄤ竴娆★級銆?*/
  private applyFlowLightColors(): void {
    if (this.coverTint.version === this.appliedTintVersion) {
      return;
    }
    // 鈽?褰㈠彉瀹夐潤绐楀彛鍐呬笉涓婅壊锛堣 `colorApplyWaitOrRetry`锛夛細绛夌獥鍙ｈ繃鍘诲畠浼氳嚜宸遍噸璇曚竴娆°€?
    if (this.colorApplyWaitOrRetry() > 0) {
      return;
    }
    this.appliedTintVersion = this.coverTint.version;
    try {
      this.flowLightController.setEffectParams({
        colorSource: [this.coverTint.sourceColor],
        colorTarget: [this.coverTint.targetColor]
      });
      Logger.info(PlaybackPage.logTag,
        `flow light colors applied v=${this.coverTint.version} src=${this.coverTint.sourceColor}`);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(PlaybackPage.logTag,
        `setEffectParams failed, code=${err?.code}, message=${err?.message}`);
    }
  }

  /**
   * 鎾斁椤垫祦鍏夎儗鏅眰锛圚DS `UV_BACKGROUND_FLOW_LIGHT` 鐫€鑹插櫒锛夈€?
   *
   * 鍙傝€冧笂娓?PR #1 鍦ㄩ椤电殑鐢ㄦ硶锛屼絾棰滆壊涓嶆槸鍐欐鐨勶細`colorSource` /
   * `colorTarget` 鏉ヨ嚜褰撳墠灏侀潰鍔ㄦ€佸彇鑹诧紙瑙?{@link publishFlowLightColors}锛夛紝
   * 姣忔鎹㈡瓕閮戒細閲嶆柊绠椾竴娆°€?
   *
   * 浣滀负 `Stack` 鐨?*棣栦釜瀛愯妭鐐?*缁樺埗锛氬湪椤甸潰搴曡壊涔嬩笂銆佸皝闈?姝岃瘝涔嬩笅銆?
   * `HitTestMode.Transparent` 鏄繀椤荤殑 鈥斺€?鏁村眰鏄叏灞忕殑锛岄粯璁ゅ懡涓殑璇濅細鎶?
   * 鎾斁椤垫墍鏈夋寜閽殑鐐瑰嚮鍏ㄥ悆鎺夈€?
   */
  /**
   * 鏈満鏄惁鍏峰 HDS 瑙嗘晥鑳藉姏浣嶃€?
   *
   * 鈿狅笍 娴佸厜鏄?HDS `hdsEffect` 鐨?shader 瑙嗘晥锛?*璁惧娌℃湁杩欎釜鑳藉姏浣嶆椂瀹冧細闈欓粯涓嶇敾**
   *    锛堜笉鎶ラ敊銆佷笉鎶涘紓甯革級锛岃〃鐜板氨鏄敤鎴疯鐨?寮€浜嗗紑鍏充絾浠€涔堥兘娌″彂鐢?銆?
   *    鎵€浠ヨ繖閲屾樉寮忓垽鏂?+ 璁版棩蹇楋紝骞跺湪涓嶆敮鎸佹椂閫€鍥炰竴灞傞潤鎬佹笎鍙橈紙鑷冲皯鐪嬪緱瑙侀鑹插彉鍖栵級銆?
   */
  /** 娴佸厜鐨?HDS 鑳藉姏浣嶏細缂哄け鏃?shader 瑙嗘晥浼氶潤榛樹笉鐢伙紙瑙?{@link hdsEffectCapable}锛夈€?*/
  private static readonly HDS_CORE_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';

  // 鈽呪槄 2026-10-15锛堢涓夊崄涔濊疆 / Round 20锛夛細`COVER_BLUR` 涓?`imageBlurRadius()` **宸插垹闄?*
  //   锛堟挱鏀鹃〉鑳屾櫙鏀规垚缃戞牸鑳屾櫙鍚庯紝棰勬覆鏌撴ā绯婇偅鏉＄嚎鍦ㄧ紪璇戝浘閲屽凡鏃犱换浣曡皟鐢ㄨ€咃級銆?
  //   鍒犻櫎渚濇嵁涓庝骇鐗╃鍙疯嚜妫€锛坢odules.abc GONE锛夎 RzdMusic璁板繂.md 搂56.15銆?

  private hdsEffectCapable(): boolean {
    try {
      return canIUse(PlaybackPage.HDS_CORE_SYSCAP);
    } catch (_err) {
      return false;
    }
  }

  @Builder
  private FlowLightBackground() {
    if (this.hdsEffectCapable()) {
      Stack()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .hitTestBehavior(HitTestMode.Transparent)
        .opacity(FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity())
        // 瀹樻柟绀轰緥閲屾寕 shader 瑙嗘晥鐨勫鍣ㄩ兘甯﹀簳鑹诧紙`backgroundColor('#383838')`锛夛紱
        // 杩欓噷缁欎竴灞?*寰堟贰鐨勬殫搴?*锛屾棦缁欒鏁堜竴涓彲娓叉煋鐨勫簳锛屽張涓嶉伄浣忓皝闈€?
        .backgroundColor('#33000000')
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
            animation: {
              duration: FLOW_LIGHT_DURATION_MS,
              iterations: -1,
              autoPlay: true
            },
            // 鍒濆€肩敤鍏滃簳鑹诧紱鐪熸鐨勯鑹茬敱 applyFlowLightColors 鍦ㄥ彇鑹插畬鎴愬悗涓嬪彂锛?
            // 杩欐牱鍗充娇鍙栬壊寰堟參涔熻兘绔嬪埢鐪嬪埌娴佸厜鍦ㄥ姩锛堣€屼笉鏄粦灞忕瓑鍗婂ぉ锛夈€?
            params: {
              colorSource: [this.coverTint.sourceColor],
              colorTarget: [this.coverTint.targetColor]
            },
            controller: this.flowLightController
          })
          .buildEffect())
        .onAppear((): void => {
          Logger.info('RzdFlowLight',
            `layer mounted capable=1 enabled=${this.flowLightState.enabled} ` +
            `opacity=${FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity()} ` +
            `src=${this.coverTint.sourceColor} dst=${this.coverTint.targetColor} v=${this.coverTint.version}`);
          // autoPlay 宸插紑锛屽啀鏄惧紡 play 涓€娆¤鐘舵€佺‘瀹氾紙鎹㈡瓕閲嶅缓璇ュ眰鏃朵笉浼氬仠鍦ㄦ殏鍋滄€侊級
          try {
            this.flowLightController.play();
          } catch (error) {
            const err = error as BusinessError;
            Logger.warn('RzdFlowLight', `play failed code=${err?.code} message=${err?.message}`);
          }
        })
    } else {
      // 鑳藉姏浣嶇己澶憋細閫€鍥為潤鎬佹笎鍙橈紙棰滆壊浠嶈窡灏侀潰璧帮級锛屼繚璇?寮€鍏虫墦寮€鐪嬪緱瑙佷笢瑗?
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .hitTestBehavior(HitTestMode.Transparent)
        .opacity(FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity())
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[this.coverTint.sourceColor, 0], [this.coverTint.targetColor, 1]]
        })
        .onAppear((): void => {
          Logger.warn('RzdFlowLight',
            `layer mounted capable=0锛堟棤 HDS 瑙嗘晥鑳藉姏浣嶏紝鏀圭敤闈欐€佹笎鍙橈級enabled=${this.flowLightState.enabled} ` +
            `src=${this.coverTint.sourceColor} dst=${this.coverTint.targetColor}`);
        })
    }
  }

  /** 閱掔洰鎻愮ず妯箙锛氶煶婧愯剼鏈法鑴氭湰鍒囨崲鏃舵樉绀猴紝3 绉掑悗鑷姩闅愯棌銆?*/
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
   * 娴眰瀹氫綅鍙ｅ緞锛堟敼鍓嶉偅鐗堟敞閲婃槸**閿欑殑**锛?026-10-15 鎸夋湰鏈?SDK 鏇存锛夈€?
   *
   * 鉂?鏃ц娉曪細銆宍position({x, y})` 鏄湪**鑷劧浣嶇疆**涓婂啀鍔犲亸绉伙紝鎵€浠ュ眳涓殑 Stack 閲岃鍏堝噺
   *    `(绐楀彛灏哄 鈭?鑷繁灏哄) / 2`銆嶃€?*涓嶆垚绔嬨€?*
   *
   * 鉁?鏈満 SDK 鍘熸枃锛坄sdk\default\openharmony\ets\component\common.d.ts:25284`锛?
   *    `position(value: Position | Edges | LocalizedEdges)`锛夛細
   *    銆?*Sets the absolute position of the component relative to the position of the
   *    parent component.**銆嶁€斺€?灏辨槸**鐩稿鐖剁粍浠跺乏涓婅鐨勭粷瀵瑰畾浣?*锛屼笌鑷劧浣嶇疆/`alignContent` 鏃犲叧銆?
   *
   * 鈬?缁撹锛堟湰鏂囦欢鎵€鏈夋诞灞傞兘鎸夎繖鏉″啓锛夛細
   *    鍙娴眰鎵€鍦ㄥ鍣?*宸︿笂瑙掑氨鏄獥鍙ｅ師鐐?*锛宍PlayerExpandState` 浜ゅ嚭鐨?*绐楀彛鍧愭爣**
   *    灏辫兘鐩存帴褰?`.position({x, y})` 鐢紝**鍏ㄩ摼闆舵崲绠?*銆?
   *    `MorphCoverBridge`锛堝悓涓€灞傦級鎸夌獥鍙ｅ潗鏍囪惤浣嶅凡琚湡鏈洪獙璇侊紱`LyricFloatLayer` 鍚屽眰鍚屽彛寰勩€?
   *
   * 鐜扮姸锛欰2 鐨勬瓕璇嶉〉娴眰鐢变笅闈㈢殑 {@link LyricFloatLayer} 鎵挎媴锛?
   * 杩欎袱涓?`morphWindow*Vp()` 鏄洿鏃╅偅鐗堬紙宸插垹锛塦LyricCoverOverlay` 鐨勯仐鐣欏彇鍊煎櫒锛屼繚鐣欎笉鍔ㄣ€?
   */
  /** @returns 娴眰鍙傝€冪敤鐨勭獥鍙ｅ搴︼紙vp锛夈€?*/
  private morphWindowWidthVp(): number {
    return this.expandState.windowWidthVp;
  }

  /** @returns 娴眰鍙傝€冪敤鐨勭獥鍙ｉ珮搴︼紙vp锛夈€?*/
  private morphWindowHeightVp(): number {
    return this.expandState.windowHeightVp;
  }

  /** 鏀惰捣杩涘害 0..100锛?*0 = 瀹屾暣鎾斁椤碉紙闈欐鎬侊級**锛?00 = 鏀惰捣鎴愯创搴曠殑涓€鏉°€?*/
  @Local collapseProgress: number = 0;

  /**
   * 鍏变韩鐨勫睍寮€/褰㈠彉鍑犱綍锛堜笌澹冲眰銆佽糠浣犳潯銆佸ぇ灏侀潰鍏辩敤鍚屼竴涓疄渚嬶級銆?
   *
   * 閲岄潰鐨?`morph` 瀹瑰櫒瀛楁锛坰cale / translate / clipHeight / radius锛夊氨鏄?
   * 鏃犵晫 `ExpandAnimation` 閭ｅ"鏁撮〉缂╂斁 + 绔栫洿瑁佸壀绐楀彛"鐨勭姸鎬侊紱
   * 澹冲眰鍦ㄨ窡鎵嬫椂鏀瑰畠锛屾湰椤电洿鎺ヨ鏉ユ覆鏌撱€?
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * 璺熸墜涓婃媺鏃舵妸鍏变韩杩涘害闀滃儚杩涙潵銆?
   *
   * 澹冲眰锛坧roducts锛夊湪杩蜂綘鏉′笂鍋氫笂鎷夋墜鍔裤€佹敼 `expandState.morph`锛?
   * 杩欓噷鍙礋璐ｅ湪**闈炲鍣ㄥ舰鍙?*鐨勮€佽矾寰勶紙鐐瑰嚮鎵撳紑锛変笅淇濇寔 `collapseProgress` 鍚屾銆?
   */
  @Monitor('expandState.transitionProgress')
  onTransitionProgressChanged(): void {
    if (this.expandState.morphContainerActive()) {
      // 瀹瑰櫒褰㈠彉閭ｆ潯璺笉鐢?collapseProgress锛堥珮搴︽亽 100%锛岃 sheetHeightPercent锛?
      return;
    }
    this.collapseProgress = this.expandState.transitionProgress;
  }

  /**
   * 涓嬫媺鏀惰捣鎵嬪娍锛堢珫鐩存柟鍚戯級銆?
   *
   * 鈿狅笍 `distance` 鏄?*鏃犵晫瀵归綈鍊?*锛堣 {@link PlaybackPage.DISMISS_PAN_DISTANCE_VP} 鐨勬敞閲婏級锛?
   *    涓嶅啓瀹冩椂妗嗘灦榛樿 **5vp**锛岄偅涓€妗ｄ細琚?1~2vp 鐨勬姈鍔ㄨ瘑鍒垚"寮€濮嬩笅鎷?銆?
   */
  private panOption: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Vertical,
    distance: PlaybackPage.DISMISS_PAN_DISTANCE_VP
  });

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?灏侀潰銆岀画椋炲埌姝岃瘝椤点€嶏紙瀵规爣 鏃犵晫闊充箰 CoverMorph 鍙岀鐐癸級鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?

  /**
   * 灏侀潰缁杩涘害锛? = 鍋滃湪灞曞紑椤典綅缃紝1 = 宸插埌姝岃瘝椤典綅缃€?
   *
   * 闈欐鍦ㄦ挱鏀鹃〉鏃舵槸 0锛?*涓嶇敾椋炶灏侀潰**锛屼笌娌℃湁杩欏鍔ㄧ敾鏃堕€愬儚绱犱竴鑷达級锛?
   * 鍙湁鍒囧埌姝岃瘝椤?鍒囧洖灏侀潰椤电殑閭?360ms 閲屾墠 0鈬? 杩囨浮銆?
   */
  @Local lyricMorphT: number = 0;
  /** 椋炶灏侀潰鏄惁鍙锛堥潤姝㈡€佷竴寰?false锛屼繚璇佷笉褰卞搷闈欐€佸竷灞€锛夈€?*/
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

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鎺у埗鍖洪潤姝㈣嚜鍔ㄦ敹璧凤紙瀵规爣 鏃犵晫闊充箰 BarCollapse锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲

  /** 鎺у埗鍖烘槸鍚﹀凡鑷姩鏀惰捣锛堟敹璧峰悗鐐逛换鎰忓鍞ゅ嚭锛夈€?*/
  @Local chromeCollapsed: boolean = false;
  /**
   * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`PlayerPage.hideChrome()` 鐨?闈㈡澘寮€鐫€灏变笉鏀?瀹堝崼锛夛細
   * **鎾斁闃熷垪 / 鍏朵粬鐗堟湰**杩欎袱涓脊灞傛槸鍚﹀紑鐫€锛堢敱 `ControlAreaComponent.onAuxSheetOpenChange` 涓婃姤锛夈€?
   *
   * 鏃犵晫閭ｄ竴鏉″畧鍗槸 10 涓?flag 鐨勭煭璺垨閾撅紙`abc.txt:4124-4225`锛夛紱
   * 鏈粨鑿滃崟 sheet 閭ｄ竴鏃忥紙`settingsOpen`/`qualityOpen`/鈥︼級钀藉湪**涓€涓?* `bindSheet` 閲岋紝
   * 宸茬敱 `playMenuOpen` 浠ｈ〃锛涘墿涓嬭繖涓や釜鐢辨湰瀛楁浠ｈ〃 鈬?涓よ€呭悎璧锋潵 = "浠讳綍闈㈡澘寮€鐫€"銆?
   * 鈿狅笍 涓?`playMenuOpen` **蹇呴』涓€璧?*骞惰繘鏀惰捣闂紙鍚屼竴鏉″畧鍗殑涓や釜鍒嗛噺锛屼笉璁稿彧鍒や竴涓級銆?
   */
  @Local auxSheetOpen: boolean = false;
  /**
   * 鈽?2026-10-17锛歚MorphGuard` 瀹夐潤绐楀彛鐨?閲嶈瘯鍙帓涓€鏉?骞傜瓑鏍囪
   * 锛堝鏍囨棤鐣?`MainPage.colorModeRetryQueued`锛宍wujie.pa:145966/145979`锛涢噸璇?位 閲屽浣嶏級銆?
   */
  private colorRetryQueued: boolean = false;
  /**
   * 鈽?2026-10-17锛氬畨闈欑獥鍙ｆ湡闂?*寰呰ˉ**鐨勭綉鏍艰儗鏅簮锛堢獥鍙ｈ繃鍘诲悗鐢?
   * {@link republishMeshSourceIfAny} 鎻愪氦锛夈€傛墍鏈夋潈鍦ㄦ湰椤碉紝鏇挎崲鏃堕噴鏀炬棫鐨勩€?
   */
  private pendingMeshPm: image.PixelMap | undefined = undefined;
  /** 鑷姩鏀惰捣璁℃椂鍣ㄣ€?*/
  private chromeTimerId: number = -1;
  /** 鏈€鍚庝竴娆℃帶鍒跺尯浜や簰鏃堕棿锛坢s锛夈€?*/
  private chromeTouchedAtMs: number = 0;

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?灞曞紑鏃剁殑閫愬厓绱犳贰鍏ワ紙鑷寔杩涘害锛屼笉澶嶇敤鍏变韩鐩镐綅锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲

  /**
   * 灞曞紑琛ラ棿鏄惁鍦ㄨ窇銆?
   *
   * 鈿狅笍 杩欐槸**鏈湴**鏍囧織锛屼笖鍙敤鏉ュ喅瀹?瑕佷笉瑕佺敤鍔ㄧ敾鍊?锛涘彧瑕佸畠鏄?false锛?
   * 鎵€鏈夋贰鍏ュ彇鍊间竴寰嬭繑鍥為潤姝㈡€侊紙1 / 0锛夈€傝繖鏍蜂笉瀛樺湪"鏍囧織娈嬬暀瀵艰嚧鍐呭閫忔槑"鐨勫彲鑳?
   * 鈥斺€?閭ｆ槸鏇剧粡鐨勭湡瀹?bug锛堢敤鎴凤細灏侀潰娣℃贰鍑虹幇鍚庢暣椤电┖鐧斤級銆?
   //  褰㈠彉杩涘害涓嶅彟瀛樺彉閲忥細鐩存帴澶嶇敤 `collapseProgress`锛堣 `morphProgress()`锛夛紝
   //  閬垮厤"楂樺害鍒颁簡浣嗙缉鏀炬病鍒?鐨勪袱濂楄鏃堕敊浣嶃€?
   */
  @Local expandIntroRunning: boolean = false;

  /** Seeds cover Resource from the current queue item. */
  aboutToAppear(): void {
    // 鍏堣涓€鏉?杩欎竴椤垫寕杞芥椂璧扮殑鏄摢鏉¤矾"锛氱偣鍑绘墦寮€ vs 涓婃媺鎵撳紑鐨勫尯鍒氨鍦?`pullDragging`锛?
    // 鎺掓煡"鐐瑰嚮鎵撳紑杩樻槸鏃у姩鐢?鏃惰繖涓€琛屾渶鍏抽敭锛坄hdc shell hilog | grep "expand intro"`锛夈€?
    Logger.info(PlaybackPage.logTag,
      `aboutToAppear: pullDragging=${this.expandState.pullDragging} ` +
      `usable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
    // 鈽呪槄鈽?2026-10-16锛?*淇敤鎴峰疄娴嬨€屾瓕璇嶉〉灏侀潰娌″彉灏忋€佸彔鍦ㄦ瓕璇嶄笂闈€?*锛夛細
    //   椤甸潰**鎸傝浇閭ｄ竴鍒?*灏辨妸"灏侀潰娴眰椋炶杩涘害"瀵归綈鍒板綋鍓嶉〉 鈥斺€?杩欐槸鏈〉绗竴娆℃湁鏈轰細鍋氳繖浠朵簨锛?
    //   鑰屼笖瀹冧笌"鏄惁鍙戠敓杩囦竴娆℃粦鍔?鏃犲叧锛堢悊鐢辫 `syncLyricMorphToPage()` 鐨勯暱娉ㄩ噴锛夈€?
    //   鐢ㄦ埛閭ｅ紶鎴浘姝ｆ槸杩欎釜褰㈢姸锛?*swiper 鍦ㄦ瓕璇嶉〉銆乣lyricMorphT` 杩樻槸 0** 鈬?澶у皝闈?+ 姝岃瘝鍚屾椂鍦ㄥ満銆?
    //   鈿狅笍 鏀惧湪 `aboutToAppear`锛坰truct 绾с€佹寕杞藉嵆鏈夛級鑰屼笉鍙湪鍐呭灞?`.onAppear`锛堣妭鐐圭骇銆?
    //      鍒嗘敮閲嶅缓鎵嶈窇锛夆€斺€?涓ゅ閮借锛屽洜涓轰袱鑰呮椂鏈轰笉鍚岋紙鍓嶈€呮棭浜庨甯у竷灞€锛屽悗鑰呮櫄浜庢寕杞斤級銆?
    this.syncLyricMorphToPage('boot');
    // 鈽?**鑷剤**锛氳 `onDisAppear` 閲岄偅娈佃鏄?鈥斺€?杩欎袱涓爣璁颁竴鏃︽畫鐣欙紝鐐瑰嚮鎵撳紑灏辨案杩?
    //   璺宠繃褰㈠彉鍒濆鍖栵紝鍙挱鑰佸姩鐢汇€傝繖閲屽啀鍏滀竴灞傦細鍙湁"纭疄鍦ㄧ湅鎵嬪娍"锛坉rive=FINGER锛?
    //   鎵嶈涓烘墜鎸囧湪椹卞姩锛涜€屼笖鍗充娇濡傛锛屽彧瑕佸凡缁忚繃浜?2 绉掕繕娌℃敹灏撅紝灏变竴瀹氭槸娈嬬暀
    //   锛堜竴娆¤窡鎵嬩笉鍙兘鎸佺画閭ｄ箞涔咃級锛岀洿鎺ユ竻鎺夈€?
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
    // 鈽呪槄鈽?2026-10-17锛堢敤鎴凤細**銆屾垜浠殑杞欢閲岄潰鏈変釜鑷畾涔夊皝闈㈠渾瑙掍篃鍒犱簡鍚с€?*锛?
    //   鍘熸潵杩欎竴鍙ユ槸 `= MusicStoreService.getInstance().getCoverCornerRadius()`
    //   鈥斺€?璁剧疆椤甸偅涓€屽皝闈㈠渾瑙掞紙鐩磋/灏?涓?澶?瓒呭ぇ锛夈€嶉€氳繃瀹冭繘娓叉煋銆?
    //   鐜板湪鍦嗚鍙湁**涓€涓潵婧?*锛氭棤鐣?`CoverMorph.radiusPlayer = 8`
    //   锛坄PlayerExpandState.COVER_RADIUS_PLAYER_VP`锛夆噿 璁剧疆鍊间笉鍐嶅弬涓庝换浣曟覆鏌撱€?
    //   鈿狅笍 杩欎竴鍙ュ繀椤荤暀鐫€锛堟妸鍏变韩鐘舵€佸帇鍥炲悎娉曞€硷級锛歚CoverRadiusState` 閲屽彲鑳芥畫鐣欐棫鍊笺€?
    this.coverRadiusState.radius = PlayerExpandState.COVER_RADIUS_PLAYER_VP;
    // 鈽?娴佸厜鑳屾櫙寮€鍏筹細**蹇呴』鍦ㄨ繖閲屼粠鎸佷箙鍖栧瓨鍌ㄧ亴杩?V2 鐘舵€?*銆?
    //   璁剧疆椤靛彧鍦ㄣ€岀敤鎴峰垏鎹㈠紑鍏炽€嶆椂鍐?`PlaybackFlowLightState`锛屽喎鍚姩鏃舵病浜虹亴鍊?鈬?
    //   鐘舵€侀粯璁?false锛屽嵆浣胯缃噷鏄?寮€"涔熸案杩滀笉鐢绘祦鍏夛紙鐢ㄦ埛鍙嶉鐨?娴佸厜鑳屾櫙涓嶇敓鏁?灏辨槸杩欎釜锛夈€?
    //   涓?`AmllLyricView`锛堣嚜宸变粠 store 鐏?fps/灞呬腑/鍓瓕璇嶏級淇濇寔鍚屼竴濂楀仛娉曘€?
    this.flowLightState.enabled = MusicStoreService.getInstance().getPlaybackFlowLight();
    const song = this.state.getCurrentSongItem();
    this.releaseBackgroundCoverIfPixelMap();
    this.imageLabel = song !== undefined ? song.label : $r('app.media.ic_avatar1');
    this.applyKeepScreenOn(true);
    // 椤甸潰鎵撳紑鏃跺鏋滃凡鏈夋湭杩囨湡鐨勬í骞咃紝绔嬪嵆瑙﹀彂娓呯悊璁℃椂銆?
    if (this.switchBanner.ts > 0) {
      this.onBannerChange();
    }
    // 鈽?灞曞紑鍔ㄧ敾锛氬厛鍦?`aboutToAppear` 鎶婅繘搴︽斁鍒?鏀惰捣"锛?*淇濊瘉绗竴甯х敾鍑烘潵灏辨槸璐村簳鐨勪竴鏉?*銆?
    //   濡傛灉鏀惧埌 `onAppear` 鍐嶇疆锛屼細鍏堟覆鏌撳嚭涓€甯у畬鏁存挱鏀鹃〉鍐嶆敹鍥炲幓锛岀湅鐫€灏辨槸闂竴涓嬨€?
    //
    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*澹冲眰宸茬粡璧蜂簡褰㈠彉鏃讹紝杩欎竴妗ｄ笉璁稿啀鍘?*銆?
    //   鏃犵晫鐨勫睍寮€**鍙湁涓€涓姩鐢讳富** 鈥斺€?澹冲眰鐨?`ExpandAnimation.doEnter`锛?50ms锛夐┍鍔ㄦ暣椤电殑
    //   `scale/translate/clipWidth/clipHeight`锛涙挱鏀鹃〉鑷繁**娌℃湁**绗簩濂?璐村簳涓€鏉￠暱涓婃潵"銆?
    //   鑰?`collapseProgress` 杩欏锛堝唴瀹瑰眰 `height` 浠庤创搴曚竴鏉￠暱鍒?100%锛夋槸**娲鹃煶鏃ц矾**锛?
    //   涓ゆ潯鍚屾椂鍦ㄨ窇灏辨槸鐢ㄦ埛瀹炴祴鐨勩€岀偣鍑绘墦寮€鎾斁鍣ㄦ病鏈夊姩鐢?/ 鑳屾櫙涓嶅銆嶏細
    //   椤甸潰琚棫璺寜"璐村簳涓€鏉?璧锋墜锛岃€屽舰鍙樼殑璧风偣鍑犱綍宸茬粡琚３灞傛寜杩蜂綘鏉¤兌鍥婂帇濂戒簡銆?
    //   鍒ゆ嵁鐢?`morphContainerActive()`锛坰tage 鈭?ENTERING/LEAVING/LANDING锛夛細瀹冨湪
    //   `pullOpenBegin()` 閲屽氨缃ソ浜嗭紝鑰屽３灞傛槸**鍏?begin 鍐?pushPath**锛堝鏍囨棤鐣?
    //   `beginMorphEnter` 鍐呴儴鑷繁 push 鐨勯『搴忥級鈬?`aboutToAppear` 杩欎竴鍒昏鍒扮殑灏辨槸鐪熺浉銆?
    const shellOwnsMorph: boolean = this.expandState.morphContainerActive();
    if (shellOwnsMorph) {
      this.collapseProgress = 0;
    } else {
      this.collapseProgress = PlaybackPage.EXPAND_START_PROGRESS;
    }
    this.dismissMorphActive = false;
    // 鈽呪槄 2026-10-15锛歚isClosing` 鏄?`onDismissDrag()` / `closeFullScreenPlayback()` 鐨?*绗竴閬撻椄**锛?
    //   瀹冧竴鏃︽畫鐣欐垚 true锛屼笅鎷夋敹璧蜂笌鍏抽棴鎸夐挳灏卞弻鍙屽け鏁堬紙璇﹁ `closeFullScreenPlayback()` 閲?
    //   閭ｆ潯 `morphGenAlive` 鏃╅€€鍒嗘敮鐨勮ˉ婕忔敞閲婏級銆傛寕杞芥椂**鏃犳潯浠?*娓呬竴娆★細
    //   鏂版寕杞界殑椤甸潰涓嶅彲鑳?姝ｅ湪鏀惰捣"锛屼换浣曟畫鐣欓兘鍙彲鑳芥潵鑷笂涓€杞湭璧板畬鐨勪細璇濄€?
    this.isClosing = false;
    // 姣忔鎵撳紑閮介噸缃噸璇曢搴︼紙鐓ф妱 `schedulePublishRetry` 鐨?12脳32ms锛?
    this.morphRetryLeft = 12;
    // 鈽?瀹瑰櫒褰㈠彉閭ｆ潯璺紙瀵规爣鏃犵晫 ExpandAnimation锛夛細涓嶆槸涓婃媺鎷夎繘鏉ョ殑锛堢偣鍑?/ 璧锋挱鎰忓浘鎵撳紑锛?
    //   灏?*灏卞湴**璧蜂竴娆″舰鍙?鈥斺€?鍑犱綍鍘嬪埌璧风偣锛坧 = 0 = 杩蜂綘鏉″皝闈㈤偅涓€灏忓潡锛夛紝
    //   浜庢槸绗竴甯х敾鍑烘潵灏辨槸"杩蜂綘鏉￠偅閲岀殑涓€灏忓潡"锛岃ˉ闂村湪 `onAppear` 閲岃窇銆?
    //   鈿狅笍 杩斿洖 false 璇存槑鍑犱綍娌￠噺榻愶紙杩蜂綘鏉″皝闈㈡病涓婃姤 / 瀹夸富娌″昂瀵革級锛氬繀椤绘妸鐩镐綅閫€鍥炲幓锛?
    //      鍚﹀垯 `sheetHeightPercent()` 浼氫竴鐩磋繑鍥?100%锛岃€佽矾寰勭殑"璐村簳涓€鏉￠暱涓婃潵"涔熻鍗℃帀锛?
    //      鐢ㄦ埛鐪嬪埌鐨勫氨鏄?鐐瑰紑鎾斁鍣ㄦ病鏈変换浣曞姩鐢?銆?
    // 鈽?**涓嶈鍦ㄦ寕杞芥椂灏辨妸鍑犱綍鍘嬪埌璧风偣**锛堣繖涓€鏉℃槸鏃犵晫 `expand.init` 鐨勯『搴忥紝涔嬪墠鐨勫仛娉曞弽浜嗭級锛?
    //   鍙嶇紪璇戦噷 `setupExpandTransition` 鏄?**鍏堥噺鐩爣鑺傜偣鐭╁舰**锛堟鍒绘挱鏀鹃〉杩樻病缂┿€佹槸鍘熷昂瀵革級
    //   鈫?鍐?start 褰㈠彉"銆傛垜鍘熸潵鍦?`aboutToAppear` 灏?`morphBeginEntering()`锛? 绔嬪埢缂╁埌璧风偣锛夛紝
    //   浜庢槸绛夊埌鑳介噺鐨勬椂鍊欙紝閲忓埌鐨勬槸**琚帇鎵侀偅涓€甯?*鐨勫皝闈?鈥斺€?缁堢偣灏辫鍐欏潖浜嗭細
    //   "绗竴娆℃病鏈夊皝闈㈤鍏?銆?缁撴潫鏃跺ぇ灏忎笉瀵?銆?鍙Щ鍔ㄤ笉缂╂斁"鍏ㄦ槸杩欎竴鏉″紩璧风殑銆?
    //   鐜板湪鏀规垚锛氭寕杞介樁娈典粈涔堥兘涓嶅仛锛岀敱 `playExpandIntro()`锛坥nAppear 璧凤紝甯?12脳32ms 閲嶈瘯锛?
    //   鍦?*棣栨閲忓埌**鐨勯偅涓€鍒绘墠 `measureMini` + `morphBeginEntering()` 鈥斺€?閲忕殑鏄師灏哄鐭╁舰锛?
    //   绱ф帴鐫€鍚屼竴甯у帇鍒拌捣鐐癸紙閰嶅悎涓嬮潰鐨?`introPaintReady` 闂紝涓嶄細闂嚭瀹屾暣鎾斁椤碉級銆?
    // 鈿狅笍 鐪嬮棬鐙楋細涓囦竴涓嬮潰 `onAppear` 閲岀殑琛ラ棿鍥犱负浠讳綍鍘熷洜娌¤窇璧锋潵锛?
    //   杩涘害灏变細姘歌繙鍋滃湪"鏀惰捣"锛岀敤鎴风湅鍒扮殑鏄墦涓嶅紑鎾斁鍣ㄣ€?
    //   鏈€杩?COLLAPSE_WATCHDOG_MS 涔嬪悗寮哄埗鍥炲埌瀹屾暣鎬?鈥斺€?瀹佸彲娌℃湁鍔ㄧ敾銆?
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
   * 鍏抽棴钀戒綅涔嬪悗锛?*绛夋挱鏀鹃〉鐪熺殑浠庤矾鐢辨爤閲屼笅鍙帮紝鍐嶅浣嶅舰鍙樺嚑浣?*銆?
   *
   * ## 涓轰粈涔堜笉鑳藉湪鍚屼竴 tick 閲屽浣嶏紙鐢ㄦ埛绗?鈶?鏉＄殑鏈哄埗锛?
   * 鍏抽棴鏀跺熬鍘熸潵鏄?`isShowPlay = false`锛堚啋 澹冲眰 `@Monitor` **寮傛** pop锛?
   * 绱ц窡鐫€**鍚屾** `morphReset()`銆傝€?`morphReset()` 浼?
   * `morphStage = NONE` + `morphP = 1` + `morphClipHeight = 0` + `morphScale = 1`
   * 鈬?瀹瑰櫒**涓嶈鍓€佷笉缂╂斁** = **婊″睆鎾斁椤?*锛?
   * 璺敱鍗磋鍒颁笅涓€甯ф墠琚憳鎺夛紙`@Monitor` 娲惧彂涓€灞?+ 甯冨眬鎽橀櫎涓€灞傦級
   * 鈬?涓棿閭?1~2 甯у氨鏄?宸茬粡缂╂垚灏忓渾鐐?鈫?绐佺劧婊″睆 鈫?娑堝け"锛?
   * 鐢ㄦ埛鎻忚堪鎴愩€屽姩鐢荤粨鏉熶簡**绐佺劧鏉ヤ釜灞曞紑鎾斁鍣ㄧ殑鍔ㄧ敾**銆嶃€?
   *
   * ## 涓轰粈涔?鏅氫竴鐐瑰浣?鏄畨鍏ㄧ殑
   * `morphLand()` 宸茬粡鎶婄粯鍒舵潈浜よ繕缁欒糠浣犳潯浜嗭紝鑰?琚鍦ㄨ糠浣犳潯閭ｄ箞楂?鐨勯偅涓€浠藉嚑浣?
   * **鍦ㄩ〉闈笅鍙颁箣鍓嶆鏄纭殑鏄剧ず鐘舵€?* 鈬?澶嶄綅娌℃湁浠讳綍鐞嗙敱鎶㈠湪 pop 鍓嶉潰銆?
   * 鍙嶈繃鏉ワ紝**涓嶅浣嶄細姹℃煋涓嬩竴杞?*锛堝嚑浣曟寕鍦?AppStorageV2 涓婃槸鍏变韩鐨勶級鈬?蹇呴』澶嶄綅锛屽彧鏄鏅氥€?
   *
   * ## 鍒ゆ嵁涓轰粈涔堢敤"鑺傜偣+璺敱閮戒笅鍙颁簡"鑰屼笉鏄浐瀹氬欢鏃?
   * 鍥哄畾寤舵椂锛堜緥濡?64ms锛夊彧鏄?*璧?* pop 姣斿畠蹇紱璧岃緭灏辨倓鎮勯€€鍥炲師 bug銆?
   * 涓や釜**鐩存帴璇绘暟**閮借婊¤冻鎵嶅浣嶏紝鍥犱负鍗曠湅涓€涓兘浼?澶嶄綅寰楀お鏃?锛?
   * 路 `!this.isAlive`锛堣妭鐐圭骇锛夆€斺€?`onDisappear` 鏄妭鐐圭湡鐨勬秷澶辨椂鎵嶈Е鍙戯紱
   * 路 `!playerRouteStillPushed()`锛堣矾鐢辩骇锛夆€斺€?鍙ｅ緞涓庡３灞?`playerRouteIndex()` 閫愬瓧涓€鑷淬€?
   * 鈿狅笍 鍙湅璺敱浼?*澶棭**锛歚pop()` 鍙槸鏀?`NavPathStack` 鐨?*鏁版嵁**锛?
   *    鑺傜偣鐨勬憳闄よ绛変笅涓€娆?layout 鈬?璺敱宸蹭笅鍙般€佽妭鐐硅繕鍦ㄥ睆涓婄殑閭ｄ竴甯ф槸瀛樺湪鐨勩€?
   * 鈿狅笍 鍙湅鑺傜偣涔熶細**澶棭**锛氬叧闂€斾腑鐨?鍒嗘敮閲嶅缓"鍚屾牱浼氳Е鍙?`onDisappear`锛堟湰鏂囦欢 5000+ 琛?
   *    鐨勬敞閲婁笓闂ㄨ杩囪繖浠朵簨锛夆€斺€?閭ｆ椂鑺傜偣杩樹細鍥炴潵銆?
   * 鈬?涓よ€?*鍚屾椂**鎴愮珛鎵嶆槸"鐪熺殑璧颁簡"锛涘啀鍔?`attempt >= RESET_POLL_MAX` 鍏滃簳锛?
   *    淇濊瘉"鍝€曚袱涓鏁伴兘鍧忔帀锛屽嚑浣曚篃涓€瀹氫細琚浣?锛堝畞鍙櫄锛屼笉鍙笉娓咃級銆?
   *
   * ## 涓ら亾瀹堝崼锛堢己涓€涓嶅彲锛?
   * 路 `closeGen !== this.closeGen`锛氳繖涓€杞叧闂凡琚?涓嬩竴娆″叧闂姹?鍙栦唬 鈬?鍒竻锛?
   * 路 `!morphGenAlive(resetGen)`锛氬嚑浣曚笘浠ｅ彿宸茬粡鍙樹簡 鈬?宸茬粡鏈夊埆浜猴紙鏂颁竴杞墦寮€鐨勮嚜鎰?
   *   `staleClr` / `leakClr`锛夋竻杩囧苟閲嶅缓浜嗕細璇?鈬?**鍐嶆竻涓€娆″氨浼氭妸鍒氳捣鐨勪細璇濇帎姝?*
   *   锛堥偅姝ｆ槸"鐐瑰嚮鎵撳紑娌℃湁鍔ㄧ敾"鐨勬垚鍥狅級銆?
   *
   * @param closeGen 鎹曡幏鑷叧闂捣鎵嬬殑鍏抽棴涓栦唬鍙?
   * @param resetGen 鎹曡幏鑷叧闂敹灏鹃偅涓€鍒荤殑褰㈠彉涓栦唬鍙?
   * @param attempt 宸茬粡杞杩囧嚑娆★紙鍐呴儴閫掑綊鐢級
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
      // 鈽?2026-10-17锛堢敤鎴锋姤銆屼笂鎷夋挱鏀炬潯鍐嶅洖鍘伙紝鎾斁鏉″彉鎴?*绾壊鍗婇€忔槑**銆嶁噿 鎶?璋佸湪鍗犵潃杩蜂綘鏉＄殑
      //   缁樺埗鏉?涔熸墦杩涜繖涓€鏉★級锛歚bar=` = `sourceBarHidden`锛? = 杩蜂綘鏉℃暣鏉¤钘忚捣鏉ヤ簡锛?
      //   姝ｅ父搴斿綋鏄?**0**锛夛紱`ovl=` = 澹冲眰娴眰閭ｄ竴妫掔殑杩涘害锛坄morphOverlayP`锛岄潤姝㈡€佸簲褰撴槸 1锛夛紱
      //   `own=` = 鍏冧俊鎭厠闅嗗眰鏄惁杩樺崰鐫€缁樺埗鏉冿紙1 = 杩樺湪鍗?鈬?杩蜂綘鏉￠偅浠芥瓕鍚嶈鍘嬫垚 0锛夈€?
      //   鈿狅笍 杩欏嚑涓噺**鍙湪杩欓噷璇?*锛坄morphReset()` 鍒氬垰鎶婂畠浠綊浣嶏級锛屾墍浠ュ畠鍙嶆槧鐨勬槸
      //   "鏀跺熬鍋氬畬涔嬪悗"鐨勭湡瀹炵姸鎬?鈥斺€?鐢ㄦ埛涓嬫鎵撳紑寰芥爣灏辫兘鐪嬪埌涓婁竴娆″叧闂暀涓嬩簡浠€涔堛€?
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
   * 鎾斁椤佃矾鐢?*鏄惁杩樺湪澹冲眰鐨?`NavPathStack` 閲?*銆?
   *
   * 鈽?2026-10-16 鏂板锛堝敮涓€璋冪敤鐐癸細`.onDisAppear()` 閲岄偅閬?`isShowPlay` 鍏滃簳闂級銆?
   *
   * ## 涓轰粈涔堥渶瑕佸畠
   * `isShowPlay` 鏄?*澹冲眰璺敱鐨勯┍鍔ㄦ簮**锛坄Index.@Monitor('appState.isShowPlay')`
   * 鈫?`popPlayerRoute()`锛夈€傝€?`.onDisAppear()` 鏄?*鑺傜偣绾?*鍥炶皟锛屼細鍦?
   * "鐐瑰嚮鎵撳紑鏃舵棫瀹炰緥鍗歌浇 / 鍒嗘敮閲嶅缓"杩欎簺鍦哄悎**涔?*瑙﹀彂 鈥斺€?閭ｆ椂鎾斁椤佃矾鐢辨槑鏄庡湪鏍堥噷銆?
   * 鎵€浠ヨ鍐?`isShowPlay = false` 涔嬪墠锛屽繀椤诲厛纭"杩欎竴娆＄湡鐨勬槸涓嬪彴"銆?
   *
   * 鈿狅笍 鍙ｅ緞涓庡３灞傜殑 {@link Index.playerRouteIndex} **閫愬瓧涓€鑷?*锛坄getAllPathName()` +
   *    `indexOf(PLAYER_PAGE)`锛夛紝杩欐牱涓よ竟瀵?鎾斁椤靛湪涓嶅湪鏍堥噷"姘歌繙鏄悓涓€涓瓟妗堛€?
   * 鈿狅笍 鍙栦笉鍒版爤锛坄@Consumer` 娌℃帴涓婏級鏃?*杩斿洖 true**锛? 淇濆畧璁や负"杩樺湪鏍堥噷"锛夛細
   *    瀹佸彲婕忔帀涓€娆?Hard-exit 鍏滃簳锛屼篃缁濅笉鍐掔潃"鎶婂垰鎵撳紑鐨勬挱鏀鹃〉寮规帀"鐨勯闄┿€?
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
   * @returns 杩欐鍗歌浇**璇ヤ笉璇ユ妸褰㈠彉缁樺埗鏉冧氦杩樼粰杩蜂綘鏉?*锛? 璇ヤ笉璇?`morphReset()`锛夈€?
   *
   * 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮鎵撳紑娌℃湁鍔ㄧ敾"鐨勬渶缁堝垽鎹?* 鈥斺€?涓夎疆璇曢敊鍚庡畾绋匡級
   *
   * ## 琚惁鎺夌殑涓や釜鐗堟湰锛堝埆鍐嶅洖鍘伙級
   * | 鍒ゆ嵁 | 涓轰粈涔堥敊 |
   * | --- | --- |
   * | `morphUsable`锛?鍑犱綍宸插氨缁?锛?| **澶櫄**锛氱偣鍑昏矾寰勫湪鎸傝浇閭ｄ竴鍒荤粓鐐归敋鐐硅繕娌￠噺鍒?鈬?鎭掑亣 鈬?闂ㄦ案杩滃紑鐫€ |
   * | `playerRouteStillPushed()`锛?璺敱杩樺湪鏍堥噷"锛?| **渚濊禆妗嗘灦璋冨害**锛歚.onDisAppear` 閭ｉ亾闂ㄦ槸 `setTimeout(0)`銆乣aboutToDisappear` 鏄悓姝ワ紝鑰?`popPlayerRoute()` 鍦?*鍙︿竴涓?* `@Monitor` 鍥炶皟閲岃窇 鈥斺€?涓夎€呰皝鍏堣皝鍚庨潤鎬佽涓嶅嚭鏉ワ紙`RzdMusic璁板繂.md` 搂110 宸茶涓轰笉纭畾椤癸級 |
   *
   * ## 瀹氱鍒ゆ嵁 = **鐢ㄦ埛鎰忓浘**锛坄isShowPlay`锛? 涓€鏉＄‖渚嬪
   * ```
   *   !isAlive          鈬?鐪熉风粍浠跺嵏杞斤紙涓嶆槸"鎵撳紑鏃舵棫瀹炰緥璁╀綅"锛夆噿 蹇呴』鏀炬潈
   *   morphGeomReady    鈬?杩欎竴杞湡鐨勫湪鎾紙缁堢偣鍑犱綍宸查噺鍒帮級鈬?缁濅笉鑳芥墦鏂?
   *   state.isShowPlay  鈬?澹冲眰鍞竴鐨?鎾斁椤佃涓嶈鍦ㄥ睆涓?鐪熸簮 鈬?鏀炬潈 = 鎶婃墦寮€鑷繁鎺愭柇
   * ```
   *   路 **鐐瑰嚮鎵撳紑**锛氬３灞傚垰鎶?`isShowPlay` 缃?`true` 鈬?杩欎竴娆″嵏杞戒笉鍙斁鏉?鉁?
   *   路 **鍏抽棴**锛堝叧闂寜閽?/ 涓嬫媺 / 绯荤粺杩斿洖锛夛細鍏抽棴閾捐矾宸茬疆 `false` 鈬?鏀炬潈 鉁?
   *   路 涓ゆ潯閮戒笉渚濊禆"澶勭悊閭ｄ竴鍒绘爤閲屾湁浠€涔? 鈬?**涓嶄緷璧栦换浣曟椂搴?*銆?
   *
   * 鈿狅笍 `!isAlive` 閭ｆ潯**蹇呴』淇?*锛氬畠鍚屾椂娑堟帀"浼氳瘽娉勬紡"鈥斺€旀硠婕忎細璁╀笅涓€娆＄偣鍑昏鍒?
   *    `isFreshSession = false` 鑰岃蛋"鏀惧純浼氳瘽"鍒嗘敮锛堝張娌″姩鐢伙級銆?
   *    閰嶅鐨勫厹搴曞湪 `Index.beginOpenMorphOnClick`锛坄leakClr` 閭ｆ潯鑷剤锛夈€?
   * 鈿狅笍 涓?`.onDisAppear` 閲岄偅閬撻棬**蹇呴』鍚屼竴涓垽鎹?*锛堝悓涓€褰㈢姸锛屼笉璁稿悇鍐欎竴濂楋級銆?
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
    // 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮鎵撳紑 / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖 娌℃湁鍔ㄧ敾"鐨勬渶缁堟帹鎵?*锛夛細
    //   鍘熷彞鏄?*鏃犳潯浠躲€佸悓姝?*鐨?`morphReset()`銆傝€?`morphReset()` 浼氬仛鍥涗欢浜嬶細
    // ```
    //     morphGen++                  鈬?鎵€鏈?`morphGenAlive` 瀹堝崼绔嬪埢杩囨湡
    //     morphUsable = false         鈬?搂102/搂104 淇ソ鐨勯偅涓夊瀹堝崼鍙堝叏搴?
    //     morphSessionStarted = false 鈬?搂108 鍔犵殑"鏂颁細璇?鍒ゆ嵁琚姽鎺?
    //     morphGeomReady = false      鈬?涓婁竴杞姞鐨?`pullGeomReady` 闂ㄨ鍏冲洖鍘?
    // ```
    //   鈿狅笍 鑰?*鐐瑰嚮鎵撳紑鏃讹紝鏃ф挱鏀鹃〉瀹炰緥鐨?`aboutToDisappear` 灏卞湪杩欎竴杞捣鎵嬩箣鍚庤窇**
    //   锛堟湰鏂囦欢 `:4235` 鑷繁鍐欒繃"鏂板疄渚?`onAppear` 涓庢棫瀹炰緥 `onDisappear` 鍑犱箮鍚屽抚"锛?
    //     `aboutToDisappear` 姣?`onDisappear` **鏇存棭**锛岃€屼笖**娌℃湁浠讳綍寤惰繜**锛?
    //   鈬?瀹冩妸**鍒氬垰寤虹珛濂界殑鏂颁竴杞細璇?*鏁翠釜娓呮帀锛?
    //     路 `beginOpenMorphOnClick` 鐨?`isFreshSession` 鍒ゆ嵁琚姽 鈬?璧?鏀惧純浼氳瘽"閭ｆ潯鍒嗘敮锛?
    //     路 `settlePullOpen` 鐨勮ˉ閲忛摼鎶婂嚑浣曢噺鍥炴潵涔嬪悗锛屽張浼氭湁浜哄啀娓呬竴娆★紱
    //     路 瑙傛劅灏辨槸鐢ㄦ埛鎶ョ殑閭ｄ笁鏉?鈥斺€?**鐐瑰嚮鎵撳紑 / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖 閮芥病鏈夊皝闈?鑳屾櫙鍔ㄧ敾**
    //       锛堣€屼笂鎷夐偅鏉¤矾涓嶇粡杩?鏃у疄渚嬪嵏杞?锛屾墍浠ヤ竴鐩存甯革級銆?
    //
    // ## 鍒ゆ嵁锛歿@link morphSessionOughtToLive}锛堜笁杞瘯閿欏悗瀹氱锛岀悊鐢卞啓鍦ㄩ偅閲岋級
    // ```
    //   !isAlive                鈬?鐪熉风粍浠跺嵏杞?鈬?蹇呴』鏀炬潈锛堣繖鏉″悓鏃舵秷鎺?浼氳瘽娉勬紡"锛?
    //   morphGeomReady          鈬?杩欎竴杞湡鐨勫湪鎾?鈬?缁濅笉鑳芥墦鏂?
    //   state.isShowPlay        鈬?鐢ㄦ埛鎰忓浘"鎾斁椤佃鍦ㄥ睆涓? 鈬?鏀炬潈 = 鎵撳紑琚嚜宸辨帎鏂?
    // ```
    //   鈿狅笍 鎴戝厛鍚庤瘯杩?`morphUsable` 涓?`playerRouteStillPushed()`锛屼袱涓兘閿欙紝鍘熷洜瑙?
    //      `morphSessionOughtToLive()` 鐨勬敞閲婏紙涓€涓お鏅氥€佷竴涓緷璧栨鏋惰皟搴︼級銆?
    if (!this.morphSessionOughtToLive()) {
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
    // 鎺у埗鍖鸿嚜鍔ㄦ敹璧风殑璁℃椂涔熻鍋滐細椤甸潰閮借蛋浜嗭紝鍒啀璁╁畾鏃跺櫒绌鸿浆
    this.stopChromeAutoHide();
    // 涓嬩竴娆¤繘鏉?`aboutToAppear` 浼氶噸鏂扮疆鎴愭敹璧凤紝杩欓噷澶嶄綅鍙槸涓轰簡涓嶇暀鑴忕姸鎬?
    this.collapseProgress = 0;
  }

  /**
   * 銆屼竴闀滃埌搴曘€嶅睍寮€鍔ㄧ敾锛氭妸杩涘害浠?鏀惰捣"琛ラ棿鍒?0銆?
   *
   * 鎵嬫硶瀹屽叏鐓у弬鑰冨伐绋?MusicHome锛?*鍙敤 `height` / `translate` / `scale` 涓変釜鍩烘湰灞炴€?*锛?
   * 涓嶇浠讳綍褰㈢姸瑁佸壀 鈥斺€?閭ｈ竟鎾斁椤典笅婊戞敹璧锋椂鐨?灏侀潰鍙樺皬"灏辨槸杩欎箞鍋氱殑锛?
   * `dismissSheetHeightPercent` + `coverLinearScale`锛夛紝鎴戜滑鍙槸鎶婂悓涓€濂楄繘搴﹀弽鍚戣窇涓€閬嶃€?
   *
   * 涓轰粈涔堣繖鏍峰氨澶熶簡锛氬唴瀹瑰眰 `justifyContent(FlexAlign.End)` 璐寸潃搴曡竟锛?
   * 楂樺害浠?璐村簳涓€鏉?闀垮埌 100% = 浠庡簳閮ㄥ悜涓婇摵婊★紱灏侀潰鐢?`layoutWeight(1)`锛?
   * 楂樺害鍙樺皬瀹冭嚜宸卞氨鍙樺皬锛屼簬鏄?灏侀潰鎱㈡參鍙樺ぇ"涔熶竴璧锋潵浜嗐€?
   */
  private playExpandIntro(): void {
    // 鈽?**缁熶竴鍏ュ彛 + 鏃犵晫寮忓厹搴?*锛氭墍鏈夋墦寮€鏂瑰紡锛堢偣鍑汇€佽捣鎾剰鍥俱€佷笂鎷夋澗鎵嬶級閮戒粠杩欓噷杩涖€?
    //   路 鎵嬫寚姝ｅ湪椹卞姩 鈫?璁╃粰鎵嬪娍锛?
    //   路 涓ょ閿氱偣锛堣糠浣犳潯灏侀潰 + 鎾斁椤靛皝闈級閮介噺鍒颁簡 鈫?璧板舰鍙橈紙`tryStartMorphIntro`锛夛紱
    //   路 杩樻病榻愶紙鐐瑰嚮閭ｄ竴鍒绘挱鏀鹃〉鍒氭寕杞姐€佸皝闈㈣繕娌″竷灞€瀹岋級鈫?**閲嶈瘯鑻ュ共甯?*锛?
    //     瀵规爣鏃犵晫 `beginMorphEnter` 澶辫触鏃?娉ㄥ唽 onPullReady 绛夊氨缁?鐨勫仛娉曘€?
    //
    // 鈿狅笍 鍒ゆ嵁蹇呴』鏄?*涓ょ**閿氱偣锛坄morphIntroAnchorsReady`锛夛紝涓嶈兘鍙垽"杩蜂綘鏉￠噺鍒颁簡"锛?
    //    缁堢偣锛堟挱鏀鹃〉灏侀潰锛夋病灏辩华鏃?`endCoverSize = 0`锛岀画椋炲皝闈㈡牴鏈笉浼氱敾
    //    锛坄morphBridging()` 涓?false锛夛紝鑰屾挱鏀鹃〉鑷繁閭ｅ紶灏侀潰鏄?钀戒綅鎵嶇幇"鈥斺€?
    //    浜庢槸澶翠竴涓ゆ灞曞紑鐨勮鎰熷氨鏄?鐐瑰紑鈫掍粈涔堥兘娌℃湁鈫掑暘涓€涓嬪埌浣?锛?
    //    鍜岀敤鎴锋姇璇夌殑"鐐瑰嚮鎵撳紑杩樻槸鏃у姩鐢?鍑犱箮鍒嗕笉鍑烘潵銆?
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
    // 鈽?閲嶈瘯鐢ㄥ敖 鈫?**鐩存帴钀戒綅锛岀粷涓嶆挱鑰佸姩鐢?*锛堝鏍囧弽缂栬瘧鐨?`setFinalStatus()`锛夛細
    //   鍙嶇紪璇?`setupExpandTransition` 閲?`expand.init(...)` 杩斿洖 false 鐨勫厹搴曞氨鏄?
    //   "鏀惧純鍔ㄧ敾銆佺洿鎺ヨ惤浣?銆傞€€鍥炲幓鎾?鍘嬫墎鍐呭灞傞珮搴?閭ｅ鑰佸姩鐢绘槸**鎴戠殑鍙戞槑**锛?
    //   涔熸鏄敤鎴峰弽澶嶅弽棣堢殑"鐐瑰嚮/杩斿洖鐢ㄧ殑鏄棫鍔ㄧ敾"鐨勬潵婧愩€?
    Logger.error(PlaybackPage.logTag,
      'expand intro: anchors never became ready, landing without animation (setFinalStatus)');
    this.expandState.morphReset();
    this.expandState.morphSettleOpen();
    // 鏃犲姩鐢昏惤浣嶄篃蹇呴』寮€闂紝鍚﹀垯鏁撮〉浼氫竴鐩村仠鍦?涓嶇敾"鐨勭姸鎬侊紙鎵撲笉寮€鎾斁椤碉級
    this.introPaintReady = true;
    this.collapseProgress = 0;
    this.expandIntroRunning = false;
  }

  /**
   * 灏濊瘯璧板舰鍙樺睍寮€璺緞锛氶噺閿氱偣 鈫?杩涚浉浣?鈫?璧疯ˉ闂淬€?
   * @returns true = 宸茬粡鎸夊舰鍙樿矾寰勫紑濮嬶紙璋冪敤鏂逛笉瑕佸啀璧拌€佽矾寰勶級
   */
  private tryStartMorphIntro(): boolean {
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER) {
      // 鎵嬫寚姝ｅ湪椹卞姩锛氳皝涔熷埆鎶紱缁樺埗闂ㄤ篃涓€骞舵斁琛岋紙杩欐潯璺笉杩涗笅闈㈢殑寮€闂ㄥ垎鏀級
      // 棣栨涓婃媺鐨勭洰鏍囧皻鏈竷灞€鏃朵粛淇濇寔閫忔槑鍏ㄥ昂瀵革紝琛ラ噺鎴愬姛鍐嶆斁琛屻€?
      this.introPaintReady = this.expandState.morphUsable;
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
      return true;
    }
    this.expandState.pullDragging = false;
    // 鈽?鍒ゆ嵁鏄?*涓ょ閿氱偣閮介綈**锛坄morphIntroAnchorsReady`锛夛紝涓嶆槸"杩蜂綘鏉￠噺鍒颁簡"锛?
    //   缁堢偣锛堟挱鏀鹃〉灏侀潰锛夋病灏辩华鏃?`endCoverSize = 0`锛岀画椋炲皝闈㈡牴鏈笉浼氱敾
    //   锛坄morphBridging()` 涓?false锛夛紝鑰屾挱鏀鹃〉鑷繁閭ｅ紶灏侀潰鏄?钀戒綅鎵嶇幇"鈥斺€?
    //   浜庢槸澶翠竴涓ゆ灞曞紑灏辨槸"鐐瑰紑鈫掍粈涔堥兘娌℃湁鈫掑暘涓€涓嬪埌浣?锛堢敤鎴峰疄娴嬬殑"绗竴娆℃病鏈夊皝闈㈤鍏?锛夈€?
    //
    // 鈽?椤哄簭鐢?`prepareMorphEntry` 鍥哄畾锛?*浣滃簾缁堢偣 鈫?鍦ㄥ師灏哄鏃堕噺 鈫?鍐嶅帇鍒拌捣鐐?*銆?
    //   鈿狅笍 杩欓噷**鏁呮剰涓嶅仛 `alreadyRunning` 涔嬬被鐨勭煭璺?*锛氫竴鏃︾煭璺紝灏变細鍦?
    //      "缁堢偣宸叉湁銆佷絾鏈疆杩樻病杩涜繃褰㈠彉"鐨勪腑闂存€佷笅璺宠繃鍘嬭捣鐐癸紝
    //      浜庢槸 `collapseProgress`/闂ㄧ姸鎬佷笌鐩镐綅瀵逛笉涓娿€傚箓绛夐噸鍏ユ槸瀹夊叏鐨勩€?
    //   涓婁竴鐗堢殑 bug 姝ｅ湪杩欓噷锛氫綔搴熷姩浣滆鏀惧湪 `morphBeginEntering()` 鍐呴儴锛?
    //   姝ｅソ鎶婂垰閲忓埌鐨勭粓鐐规姽鎺?鈫?閲嶈瘯鏈熷張琛ヤ笉鍥炴潵锛坄morphLive()` 鎸＄潃锛?
    //   鈫?閲嶈瘯鐢ㄥ敖鏃犲姩鐢昏惤浣?鈬?**鐐瑰嚮璺緞浠庢潵娌¤繘杩?`playMorphOpenIntro()`**銆?
    if (!this.expandState.morphUsable) {
      return false;
    }
    // 鈽呪槄 2026-10-15锛堝洖閫€鍚庨噸鍋氾級**涓轰粈涔堝闈㈣鍖呬竴灞?`UIUtils.applySync`**锛?
    //   `prepareMorphEntry` 鐨勬渶鍚庝竴姝ユ槸"鎶婂嚑浣曞帇鍒拌捣鐐?锛坄applyMorphProgress(0)`锛夛紝
    //   绱ф帴鐫€**鍚屼竴涓换鍔￠噷**灏辫捣琛ラ棿銆傝€?V2 鐨勭姸鎬佸彉閲忎慨鏀?*涓嶄細绔嬪嵆鏍囪剰**锛堟姏 Promise 寰换鍔★級锛?
    //   `animateTo` 鍗翠細**绔嬪埢鍒锋柊宸叉爣鑴忚妭鐐规潵鍐冲畾鍔ㄦ晥棣栧抚** 鈬?鍘嬭捣鐐归偅涓€涓?*娌＄敓鏁?*锛岄甯х敤鏃у€笺€?
    //   瀹樻柟锛坄arkts-new-applysync-flushupdates-flushuiupdates`锛夋槑纭瀹氳繖绉?
    //   "鍔ㄦ晥鍓嶆湁棰濆淇敼"鐨勫満鏅鐢?`UIUtils.applySync` 鍚屾鍒锋柊鍚庡啀璧峰姩鐢?鈥斺€?杩欐鏄?
    //   "鐐瑰嚮鎵撳紑鍜屾墜鎸囨嫋鍔ㄦ墦寮€鏄袱涓姩鐢?鐨勭粨鏋勬€ф牴鍥狅紙50ms 寤惰繜/閲嶈瘯/缁樺埗闂ㄩ兘鏄畠鐨勮ˉ涓侊級銆?
    //   鈿狅笍 瀹冨彧瑙ｅ喅**鏍囪剰**銆佷笉瑙ｅ喅**甯冨眬**锛氱瓑灏侀潰鑺傜偣閲忓緱鍒颁粛鐒惰闈犱笂闈㈢殑閲嶈瘯绐楀彛銆?
    let prepared: boolean = false;
    UIUtils.applySync((): void => {
      prepared = this.expandState.prepareMorphEntry(this.getUIContext(), true);
    });
    if (!prepared) {
      // 淇濈暀鏈疆灏辩华鐘舵€侊紝绛夊緟涓嬩竴娆″師灏哄甯冨眬锛屼笉鍦ㄩ噸璇曢棿鍘嬬缉/澶嶄綅甯冨眬銆?
      return false;
    }
    if (!this.expandState.morphIntroAnchorsReady()) {
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready ` +
        `(usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()})`);
      return false;
    }
    // 鍑犱綍灏辩华锛氬紑闂紝鍏佽缁樺埗锛堟鏃跺凡缁忔槸"杩蜂綘鏉￠偅涓€灏忓潡"鐨勮捣鐐规€侊級
    this.introPaintReady = true;
    this.expandIntroRunning = false;
    this.collapseProgress = 0;
    this.playMorphOpenIntro();
    return true;
  }

  /**
   * 鑰佽矾寰勶紙鍑犱綍娌￠噺鍒版椂鐨勫厹搴曪級锛氬唴瀹瑰眰璐寸潃搴曡竟锛岄珮搴︿粠"璐村簳涓€鏉?闀垮埌 100%銆?
   *
   * 鍙湪 `morphUsable === false` 鏃舵墠浼氳蛋鍒拌繖閲?鈥斺€?姝ｅ父鎯呭喌锛堣糠浣犳潯鍦ㄣ€佸涓诲凡閲忓埌锛?
   * 涓€寰嬭蛋褰㈠彉閭ｆ潯璺€?
   */
  private playLegacyExpandIntro(): void {
    try {
      // 閫愬厓绱犳贰鍏ョ敤**鏈〉鑷寔**鐨勮繘搴︼紙1 = 璐村簳鏀惰捣 鈫?0 = 瀹屽叏灞曞紑锛夛紝涓庨珮搴﹁ˉ闂村悓璧峰悓钀姐€?
      // 鈿狅笍 鍒绘剰涓嶅鐢ㄥ叡浜?`PlayerExpandState` 鐨?preparing/animating 鐩镐綅锛?
      //    閭ｅ鐩镐綅鐨勭疆浣嶇偣鍦ㄩ噸鏋勪腑鍏ㄤ涪浜嗭紝鎺ヤ笂鍘诲彧浼氬緱鍒颁袱绉嶅潖缁撴灉 鈥斺€?
      //    銆屾亽璧伴潪鍔ㄧ敾鍒嗘敮 鈫?娣″叆绛変簬娌″啓銆嶆垨銆屾爣蹇楁畫鐣?鈫?鏁村潡鍐呭绠楁垚閫忔槑锛堝皝闈㈠厛娣″悗娑堝け銆佹暣椤电┖鐧斤級銆嶃€?
      //    鏈〉鑷寔 + 闈欐鎬佹亽杩斿洖 1锛屽氨涓嶅瓨鍦ㄦ畫鐣欐€併€?
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
      // 琛ラ棿璧蜂笉鏉ュ氨绔嬪埢鍥炲埌瀹屾暣鎬侊紱鐪嬮棬鐙楁鏃惰繕娌″埌鐐癸紝鍒椤甸潰鍋滃湪"鏀惰捣"閭ｄ竴鏉′笂
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `expand animateTo failed code=${e.code} msg=${e.message}`);
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
    }
  }

  /**
   * 瀹瑰櫒褰㈠彉璺緞鐨勫睍寮€琛ラ棿锛氬嚑浣曞湪 `aboutToAppear` 宸茬粡鍘嬪埌璧风偣锛坧 = 0锛?
   * 涔熷氨鏄?杩蜂綘鏉￠偅鏉¤兌鍥?锛夛紝杩欓噷鍙妸瀹冩帹鍒?1锛堥摵婊★級銆?
   *
   * 鈿狅笍 `animateTo` 琛ョ殑鏄?*灞炴€у€?*锛坰cale / translate / height / borderRadius / opacity锛夛紝
   *    涓嶆槸 `morphP` 鏈韩 鈥斺€?鎵€浠ラ棴鍖呴噷鍙鎶婄姸鎬佽惤鍒扮粓鐐瑰嵆鍙紝涓棿甯х敱妗嗘灦鎻掑€硷紝
   *    鎵€鏈夌粦鍦ㄥ悓涓€浠界姸鎬佷笂鐨勫睘鎬т細涓€璧疯蛋鍚屼竴鏉℃洸绾裤€?
   */
  private playMorphOpenIntro(): void {
    this.expandIntroRunning = true;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // 鈽呪槄 2026-10-15锛堝洖閫€鍚庨噸鍋氾級锛?*鍒犳帀鍘熸潵"寤跺悗 50ms 鍐嶈捣琛ラ棿"閭ｄ竴姝?*銆?
    //   瀹冨綋骞存槸涓轰簡缁曞紑涓€涓湡瀹炲瓨鍦ㄧ殑鍧戯細**V2 鐨勭姸鎬佸彉閲忔槸"寮傛鏍囪剰"锛圥romise 寰换鍔★級锛?
    //   鑰?`animateTo` 浼氱珛鍒诲埛鏂板凡鏍囪剰鑺傜偣鏉ュ喅瀹氬姩鏁堥甯?* 鈥斺€?浜庢槸"鍏堟妸鍑犱綍鍘嬪埌璧风偣銆?
    //   鍚屼竴涓换鍔￠噷鍐嶈捣琛ラ棿"鏃讹紝鍘嬭捣鐐归偅涓€涓?*娌＄敓鏁?*锛岄甯х洿鎺ョ敤鏃у€笺€?
    //   瀹樻柟锛坄arkts-new-applysync-flushupdates-flushuiupdates`锛夌粰鐨勮В娉曟槸
    //   `UIUtils.applySync(() => { 鈥?})`锛氬悓姝ュ埛鏂伴棴鍖呭唴鐨勭姸鎬佸彉鍖栵紝鍐嶈捣鍘熸潵鐨勫姩鐢汇€?
    //   鏈柟娉曢厤鍚?`tryStartMorphIntro` 閲岄偅灞?`applySync` 浣跨敤 鈥斺€?
    //   杩欎篃鏄?鐐瑰嚮鎵撳紑鍜屾墜鎸囨嫋鍔ㄦ墦寮€鏄袱涓姩鐢?鐨勭粨鏋勬€ф牴鍥狅紝50ms/閲嶈瘯/缁樺埗闂ㄩ兘鏄畠鐨勮ˉ涓併€?
    // 鈿狅笍鈿狅笍 2026-10-17 绾犳涓€澶?*鎴戣嚜宸卞啓閿欑殑娉ㄩ噴**锛堝畠鏄笅闈㈤偅涓?bug 鐨勬潵婧愶級锛?
    //   杩欓噷鍘熸潵杩樺啓鐫€銆屽畼鏂圭粰鐨勫啓娉曞氨鏄湪 `animateTo` 鐨勯棴鍖呴噷鐢?`UIUtils.applySync`
    //   鍚屾鍒锋柊鐩爣鍊笺€嶁€斺€?*閭ｆ槸閿欑殑**銆傚畼鏂归偅涓満鏅槸
    //   銆?*鍔ㄦ晥涔嬪墠**鏈夐澶栦慨鏀?鈬?鍏?`applySync` 鎶?*璧风偣**钀藉湴锛?*鍐?*璧?`animateTo`銆嶏紱
    //   鑰?**`animateTo` 闂寘閲屽彧璁稿啓鐩爣鍊?*锛堝啓浠€涔堝氨琛ラ棿鍒板摢閲岋級銆?
    //   鎶婂畠鏀捐繘闂寘閲?= 鎶婄洰鏍囧€肩珛鍒诲埛鍑哄幓 鈬?**琛ラ棿琚烦杩?* 鈬?鐩存帴璺崇粓鐐广€?
    //   鈬?鏈枃浠堕噷 `applySync` 鐨勬纭綅缃彧鏈?琛ラ棿涔嬪墠"锛堣 :3158 / :3737 涓ゅ锛夈€?
    //   鈿狅笍 涓栦唬鍙凤細鏀跺熬鍥炶皟蹇呴』姣斿 `morphGen`锛堝弽缂栬瘧閲?`animGen++` + onFinish 鏍￠獙锛夛紝
    //    鍚﹀垯蹇€熻繛鐐?鏀惰捣浼氫覆鐘舵€併€?
    const gen: number = this.expandState.morphGen;
    try {
      this.getUIContext().animateTo({
        duration: PlaybackPage.MORPH_OPEN_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        // 鈽呪槄鈽呪槄 2026-10-17锛?*鐢ㄦ埛绗?1 鏉?鐐瑰嚮鎵撳紑鏃犲姩鐢汇€佺洿鎺ュ埌缁撴潫浣嶇疆"鐨勬牴鍥?*锛?
        //
        // 杩欓噷鍘熸潵鏄?`UIUtils.applySync((): void => { applyMorphProgress(1); })`銆?
        // **閭ｆ槸閿欑殑**锛歚applySync` 鐨勮涔夋槸"**鍚屾鍒锋柊**闂寘鍐呯殑鐘舵€佸彉鍖?锛?
        // 瀹樻柟锛坄arkts-new-applysync-flushupdates-flushuiupdates`锛夊彧鍦?
        // **"璧疯ˉ闂翠箣鍓嶆湁棰濆淇敼"** 鏃剁敤瀹冩妸**璧风偣**钀藉湴锛堟湰鏂囦欢 :3158 閭ｅ灏辨槸姝ｇ‘鐢ㄦ硶锛夈€?
        // 鏀捐繘 `animateTo` 鐨勯棴鍖呴噷 鈬?鐩爣鍊艰**绔嬪埢鍒峰嚭鍘?* 鈬?**琛ラ棿琚烦杩?*
        // 鈬?椤甸潰**鐩存帴璺冲埌缁堢偣**锛? 鐢ㄦ埛鐪嬪埌鐨?灏侀潰鐩存帴灏卞埌缁撴潫浣嶇疆锛屾病鏈夊姩鐢?锛夈€?
        // 涓婃父閭ｄ唤 `doEnter` 鐨勮ˉ闂?位锛坄wujie.pa:51311-51329`锛?*鍙槸鎶婄洰鏍囧€煎啓杩涘幓**
        // 锛坄scaleValue/translateX/translateY/clipHeight` 鐨勭洿鎺ヨ祴鍊硷級鈥斺€?娌℃湁浠讳綍"鍚屾鍒锋柊"銆?
        // 鈬?鐓т笂娓革細闂寘閲?*鍙啓鐩爣鍊?*锛屼氦缁?`animateTo` 鍘昏ˉ闂淬€?
        this.expandState.applyMorphProgress(1);
      });
    } catch (err) {
      // 琛ラ棿璧蜂笉鏉ヤ篃瑕佽惤鍒板畬鏁存€侊紝缁濅笉鑳芥妸鎾斁椤电暀鍦?杩蜂綘鏉￠偅涓€灏忓潡"
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `morph open animateTo failed code=${e.code} msg=${e.message}`);
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
      // 鈽呪槄 2026-10-16锛?*鍚屼竴鏉?涓嶈鍦ㄦ病鏈夊嚑浣曟椂钀戒綅"鐨勮鍒?*锛岃 `Index.settlePullOpen`锛夛細
      //   杩欎竴鍙ュ師鏉ユ棤鏉′欢钀戒綅銆傝嫢鏈疆鍑犱綍濮嬬粓娌￠噺鍒帮紙`morphGeomReady` 涓哄亣锛夛紝
      //   `morphSettleOpen()` 鍐呴儴鐨?`applyMorphProgress(1)` 浼氳閭ｉ亾闂ㄦ尅鎺夈€?
      //   鑰岀浉浣嶅嵈缈绘垚 OPEN 鈬?瀹瑰櫒鍋滃湪鎭掔瓑 + 鐩镐綅 OPEN 鐨?*鍗婃鐘舵€?*銆?
      //   鈬?鎸夋棤鐣屻€岄噺涓嶅埌灏遍€€鍥炴櫘閫?push(鏃犲舰鍙?銆嶇殑鍙ｅ緞锛氬彧鎶婄浉浣嶆敹骞插噣锛屼笉钀戒綅銆?
      if (!this.expandState.morphGeomReadyNow()) {
        this.expandState.pushMorphTrace('openNoGeom');
        this.expandState.morphReset();
        this.expandState.morphStage = MorphStage.OPEN;
        this.expandState.morphP = 1;
        this.expandState.measureGeometry(this.getUIContext(), true);
        return;
      }
      this.expandState.morphSettleOpen();
      // 鈽?钀戒綅鍚?*閲嶉噺涓€娆?*鍑犱綍锛氳繖涓€鍒婚〉闈㈠凡缁忔槸鍘熷昂瀵革紙scale=1銆佷綅绉?0锛夛紝
      //   閲忓埌鐨勬槸骞插噣鐨勭粓鐐圭煩褰紱鍚屾椂鎶?aside 鐨勫搴﹀埛鏂颁竴閬嶏紙HDS 搴曟爮鎺掑竷鍙兘鍙樿繃锛夈€?
      //   鈿狅笍 杩欎竴閲忓彧褰卞搷**涓嬩竴杞?*灞曞紑锛堜笉鍔ㄦ湰杞粓鐐癸級锛屾墍浠ュ畠鏄?涓嬩竴杞洿鍑?鐨勪繚闄╋紝
      //      涓嶆槸鏈疆钀戒綅瀵逛笉瀵圭殑渚濇嵁銆?
      this.expandState.measureGeometry(this.getUIContext(), true);
    }, PlaybackPage.MORPH_OPEN_DURATION_MS + 30);
  }

  /**
   * @returns 鍐呭灞傞珮搴︾櫨鍒嗘瘮瀛楃涓层€?
   *
   * 杩涘害 0 鈫?`'100%'`锛堜笌娌℃湁鍔ㄧ敾鏃堕€愬儚绱犱竴鑷达紝杩欐槸鏈€閲嶈鐨勬€ц川锛夛紱
   * 杩涘害 100 鈫?`COLLAPSED_HEIGHT_PERCENT`锛堣创搴曚竴鏉★紝澶ц嚧灏辨槸杩蜂綘鏉￠偅涓€鏉＄殑楂樺害锛夈€?
   */
  private sheetHeightPercent(): string {
    // 鈿狅笍 瀹瑰櫒褰㈠彉锛堟棤鐣岄偅濂楋級鏈熼棿**蹇呴』鎭掍负 100%**锛氶偅濂楀彧闈?澶栧眰瀹瑰櫒缂╂斁 + 瑁佸壀"瀹屾垚灞曞紑锛?
    //    鑻ヨ繖閲屽悓鏃舵寜 collapseProgress 鍘嬬缉鍐呭灞傞珮搴︼紝灏辨湁涓ゅ鍔ㄧ敾鍦ㄦ敼鍚屼竴鐗囧竷灞€锛?
    //    琛ㄧ幇涓哄唴瀹硅鍘嬫墎銆佸皝闈㈤敊浣嶃€?
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
   * @returns 鏀惰捣杩囩▼涓槸鍚﹁钘忚捣鏍囬/鎺т欢銆?
   *
   * 蹇呴』钘忥細鍐呭琚帇鎵佸埌鍙墿涓€鏉℃椂锛屽浐瀹氶珮搴︾殑鎺у埗鍖轰細鎶婂皝闈㈡尋鎴?0 楂?
   * 锛堝弬鑰冨伐绋嬩篃鏄繖涔堝鐞嗙殑 鈥斺€?瀹冪殑 `isDismissPhase2HideMeta()` 涓€杩涗簩娈靛氨钘?meta锛夈€?
   */
  private isCollapsing(): boolean {
    // Morph dismiss keeps natural layout mounted; opacity/clip handles chrome continuously.
    return !this.expandState.morphContainerActive() && this.collapseProgress > 45;
  }

  /**
   * 鈽?2026-10-17锛氫笂涓€娆?*鐪熸涓嬪彂鎴愬姛**鐨勫父浜。浣嶏紙`undefined` = 杩樻病鎴愬姛杩?/ 澶辫触宸插洖婊氾級銆?
   *
   * 鐓ф惉鏃犵晫 `WindowInfo.setKeepScreenOn`锛坄design/animation/WindowInfo.ets`锛夌殑骞傜瓑鍒ゆ嵁锛?
   * ```ts
   *   setKeepScreenOn(on) {
   *     if (this.screenOn === on) return;                 // 鈽?鍊兼病鍙樺氨涓嶄笅鍙戯紙骞傜瓑锛?
   *     if (window === undefined) return;
   *     this.screenOn = on;
   *     window.setWindowKeepScreenOn(on).catch(位2);       // 鈽?位2锛歸arn + `screenOn = false`锛堝け璐ュ洖婊氾級
   *   }
   * ```
   * 鈿狅笍 **鍥炴粴閭ｅ崐鏉℃槸鍏抽敭**锛氳嫢涓嶅洖婊氾紝澶辫触涔嬪悗缂撳瓨鍊间笌鐪熷疄鍊间笉涓€鑷?鈬?涓嬩竴娆″悓鍊艰姹備細琚箓绛夐棬鎸℃帀
   *   鈬?**姘歌繙涓嶅啀涓嬪彂**锛堜笌鏈粨鍙嶅韪╃殑"璧锋墜缃湡/鏀跺熬缃亣 涓嶆垚瀵?鍚屼竴涓舰鐘讹級銆?
   */
  private keepScreenOnApplied: boolean | undefined = undefined;

  /** Applies the keep-screen-on switch while the playback page is visible. */
  private applyKeepScreenOn(enabled: boolean): void {
    try {
      // 鍏堢畻**鐪熸瑕佷笅鍙戠殑鍊?*锛堢敤鎴峰亸濂戒笌椤甸潰鐩镐綅閮借婊¤冻锛夛紝鍐嶆嬁瀹冨仛骞傜瓑鍒ゆ嵁
      // 鈿狅笍 椤哄簭锛氬繀椤诲湪鍙?UIContext 涔嬪墠锛堟棤鐣屼篃鏄湪鍒?window 涔嬪墠鍏堟瘮 `screenOn`锛夈€?
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
        // 鈽?鍐呭眰 promise 涔熻 catch锛歚setWindowKeepScreenOn` 鏈韩杩斿洖 Promise锛?
        //   涓嶆帴浣忓氨鏄竴涓湭澶勭悊鐨?rejection锛堝師鏉ヨ繖閲屾鏄繖鏍凤級锛岃€屼笖澶辫触鏃?*蹇呴』鍥炴粴**銆?
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
        // 鍦ㄧ嚎灏侀潰 URL 鈥斺€?涓庢挱鏀鹃〉灏侀潰锛坄PlayerViewModel.songCoverUrl()`锛?*鍚屼竴鏉ユ簮**锛?
        // 缁灏侀潰鎵嶄笉浼氬嚭鐜?鏉″舰鐮侀噷鏄皝闈€侀杩囨潵杩欏紶鏄粯璁ゅご鍍?
        return song.cover;
      }
      // 鏈湴/娌欑灏侀潰锛歚label` 鏄湡姝ｇ殑灏侀潰 Resource锛堜笉鏄?`ic_avatar1`锛?
      return song.label;
    }
    return $r('app.media.ic_avatar1');
  }

  // 鈽呪槄 2026-10-15锛堢涓夊崄涔濊疆 / Round 20锛夛細鍘熷厛鎸傚湪杩欓噷鐨勬暣娈?JSDoc 鎻忚堪鐨勬槸 `originalCoverSource()`
  //   锛堢涓夊崄涓冭疆宸插垹闄わ紝瑙?RzdMusic璁板繂.md 搂56.13锛夛紝骞朵笖閫氱瘒寮曠敤 `backgroundImageSource()`
  //   锛堟湰杞凡鍒犻櫎锛夆噿 宸叉槸**瀛ゅ効娉ㄩ噴**锛屾暣娈垫竻鎺夈€?
  //   鈿狅笍 `isPixelMapCover()` **浠嶇劧鍦ㄧ敤**锛堢湡瀹炶皟鐢ㄧ偣锛歚releaseBackgroundCoverIfPixelMap()`锛夛紝
  //   **涓嶈璺熺潃鍒?*銆?

  // 鈽呪槄 2026-10-15锛堢涓夊崄涔濊疆 / Round 20锛夛細`backgroundImageSource()` **宸插垹闄?* 鈥斺€?
  //   瀹冭嚜宸辩殑 JSDoc 灏卞啓鏄?鍞竴璋冪敤鐐规槸 phoneSwiperBackdropImage锛岃€岄偅涓?builder 鏈韩鏄浠ｇ爜"
  //   鈬?闅?`phoneSwiperBackdropImage` 涓€璧蜂笅绾匡紝鍏ㄤ粨闆惰皟鐢ㄨ€呫€?
  //   鍒犻櫎渚濇嵁涓庝骇鐗╃鍙疯嚜妫€锛坢odules.abc GONE锛夎 RzdMusic璁板繂.md 搂56.15銆?

  /**
   * True when value looks like a decoded PixelMap ({@link Resource} has no release).
   *
   * 鈿狅笍 2026-10-15锛氳儗鏅敼瀹炴椂妯＄硦鍚?`imageLabel` **鎭掍负 `Resource`**锛堜笉鍐嶈璧嬫垚浠讳綍
   *   PixelMap锛夆噿 鏈柟娉曞湪璋冪敤鐐规亽杩斿洖 false锛屽疄闄呭凡鎴?*鍏滃簳瀹堝崼**銆?
   *   淇濈暀涓嶅垹锛歚releaseBackgroundCoverIfPixelMap()` 浠嶉潬瀹冨垽绫诲瀷锛堣儗鏅偅鏉¤矾宸插湪
   *   绗笁鍗佷節杞殢 `backgroundImageSource()` 涓€璧蜂笅绾匡紝瑙?RzdMusic璁板繂.md 搂56.15锛夛紝
   *   浠ュ悗鑻ユ湁浜洪噸鏂版妸瑙ｇ爜缁撴灉鏀捐繘 `imageLabel`锛岃繖鏉″垎鏀細鑷姩閲嶆柊鐢熸晥銆?
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
   * 鈿狅笍 2026-10-15锛?*宸蹭笉鍐嶄細鍛戒腑浠讳綍涓滆タ**锛坄imageLabel` 鎭掍负 `Resource`锛岃
   *   {@link isPixelMapCover}锛夈€備袱涓皟鐢ㄧ偣锛坄aboutToAppear` / `onDisAppear`锛変繚鐣欏師鏍凤紝
   *   鍥犱负杩欐槸涓€鏉?*瀹夊叏缃?*锛氫竾涓€浠ュ悗鍙堟湁浜烘妸浣嶅浘濉炶繘 `imageLabel`锛屽畠浠嶇劧浼氳礋璐ｉ噴鏀俱€?
   *   鈿狅笍 鍙嶉潰鏁欒锛堟湰娆℃敼鍔ㄩ『甯﹁В鍐崇殑锛夛細浠ュ墠鑳屾櫙灞傛覆鏌撶殑**姝ｆ槸**杩欓噷浼氳閲婃斁鐨勯偅寮?
   *   PixelMap 鈥斺€?"鍏堥噴鏀俱€佸啀鐢?`@Local` 瑙﹀彂鎹㈡簮"涓棿闅旂潃璋冨害锛屽睘浜庢綔鍦?use-after-free銆?
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
   * 鍏抽棴鍏ㄥ睆鎾斁椤碉細鍏堟挱鏀惰捣鍔ㄧ敾锛堣繘搴?0 鈫?鏀惰捣锛夛紝鎾畬鍐嶆仮澶嶇獥鍙?chrome 骞跺嵏杞姐€?
   *
   * 鈿狅笍 鍗歌浇鏀惧湪**瀹氭椂鍣?*閲岃€屼笉鏄?`animateTo` 鐨勫畬鎴愬洖璋冿細閭ｄ釜鍥炶皟鍦ㄩ儴鍒嗗満鏅笉淇濊瘉瑙﹀彂锛?
   * 闈犲畠鍗歌浇灏变細鍙樻垚"杩斿洖閿寜浜嗘病鍙嶅簲"銆傚畾鏃跺櫒鎸夋椂闀垮厹搴曪紝鏈€鍧忔儏鍐靛彧鏄敹璧峰姩鐢昏璺宠繃锛?
   * 鍏抽棴涓€瀹氫細鍙戠敓銆?
   */
  private refreshCollapseGeometry(): void {
    if (this.expandState.morphStage !== MorphStage.OPEN) {
      return;
    }
    this.expandState.measureGeometry(this.getUIContext(), true, true);
    this.expandState.morphInitParams();
    this.expandState.freezeMorphMeta(this.getUIContext());
    this.expandState.logMorphOwnership('close-freeze-natural-open');
    Logger.info(PlaybackPage.logTag, 'collapse geometry refreshed while OPEN');
  }

  /**
   * 鈽呪槄鈽呪槄 2026-10-17锛堢収鎼棤鐣?`MainPage.closeWithAnimation()`锛宍wujie.pa:171054-171095`锛夛細
   * **闈炴墜鍔垮叧闂?*锛堝叧闂寜閽?/ 绯荤粺杩斿洖锛夆€斺€?缂╃殑**涓嶆槸娲婚〉闈?*锛岃€屾槸**涓€寮犳弧绐楀揩鐓?*銆?
   *
   * ## 鏃犵晫鐨勫師鏂囧舰鐘?
   * ```
   *   closeWithAnimation() {
   *     if (pullMode && ExpandSnapshot.onReverseMorph(myMorphSnap)) return;   // 鈶?涓嬫媺閭ｆ潯璺細鑷繁澶勭悊
   *     getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 位@1*#);     // 鈶?鍚﹀垯锛氭媿蹇収
   *   }
   *   位@1*#锛坵ujie.pa:181020-181077锛夛細
   *     澶辫触 鈬?hilog.warn('root snapshot failed, fallback: 鈥?) + nav.pop()    锛堟棤鍙?= 涓嶅甫杞満锛?
   *     鎴愬姛 鈬?ExpandSnapshot.onShrinkBack(pixmap, this.mySrcBox) + nav.pop(false)
   *   onShrinkBack 鈫?ShrinkOverlay.start(鈥?     鈫?鏈粨鐨?MorphShrinkState
   * ```
   *
   * ## 涓轰粈涔堣鐓ф惉锛堢敤鎴风 鈶?鏉°€屾湁鑳屾櫙浣嗘槸楂樺害鐗逛綆銆嶏級
   * 鎴戜滑涓€鐩存槸"鍔ㄦ椿鐨勬挱鏀鹃〉"锛堟敼瑁佸壀绐楀彛 + 缂╂斁锛夆噿 鍙涓よ€呬笉鍚屾锛屽睆涓婂氨鏄?
   * "鏈夎儗鏅€佷絾鍙墿寰堢煯鐨勪竴鏉?銆傝€?*缂╀竴寮犲浘**鏃惰儗鏅笌灏侀潰**鍚屾瘮渚?*锛岄偅绉嶅舰鐘朵笉鍙兘鍑虹幇銆?
   *   鈿狅笍 涓嬫媺閭ｆ潯璺?*淇濈暀**娲婚〉褰㈠彉锛堟棤鐣岀殑 `onReverseMorph` 灏辨槸瀹冿級鈥斺€?
   *     鐢ㄦ埛宸茬‘璁ゃ€屸憽涓婃媺鎵撳紑/涓嬫媺鍏抽棴鐨勫皝闈?鑳屾櫙鍔ㄧ敾姝ｅ父銆嶏紝涓嶅姩瀹冦€?
   *
   * ## 鏈粨鐨勬槧灏?
   * ```
   *   鏃犵晫 pullMode            鈫愨啋 鏈"鏄笉鏄粠涓嬫媺閭ｆ潯璺潵鐨?锛氭湰鏂规硶**鍙闈炴墜鍔垮叆鍙ｈ皟鐢?*
   *                                 锛堣 `onCollapseRequested`锛夛紝鎵€浠ヨ繘鏉ュ氨鏄?鈶?鏀€?
   *   鏃犵晫 PLAYER_ROOT_ID      鈫愨啋 鏈〉褰㈠彉瀹瑰櫒涓婄殑 `.id(PLAYER_ROOT_ID)`锛堢収鎼悓涓€浣嶇疆锛?
   *   鏃犵晫 mySrcBox            鈫愨啋 `expandState.barWinX/Y/W/H`锛堣糠浣犳潯鑳跺泭鐨勭獥鍙ｇ煩褰紝vp锛?
   *   鏃犵晫 nav.pop(false)      鈫愨啋 `state.isShowPlay = false`锛堝３灞?`popPlayerRoute()` 鐢ㄧ殑鏄?
   *                                 `pageIndexInfos.pop(false)` 鈬?鏈氨**涓嶅甫杞満**锛?
   *   鏃犵晫澶辫触鏀?nav.pop()     鈫愨啋 鍚屾牱缃?`isShowPlay = false`锛堟垜浠殑 pop 鎭掓棤杞満 鈬?绛変环锛?
   * ```
   *
   * 鈿狅笍 `mySrcBox`锛堣兌鍥婄煩褰級**鍙湪褰㈠彉浼氳瘽寤虹珛鏃堕噺鍒?*锛坄reportMini` 鈫?`barWin*`锛夈€?
   *   閲忎笉鍒版椂 `MorphShrinkState.start` 浼氳蛋鏃犵晫閭ｆ潯 `start skipped: no srcBox` 鏀?
   *   锛坄visible=false` + `onDone()`锛夆噿 閫€鍖栨垚"鏃犲姩鐢诲叧闂?锛?*涓庢棤鐣岀殑閫€鍖栬矾寰勪竴鑷?*銆?
   *   鎺掓煡鍏抽敭瀛楋細`RzdShrinkOverlay` / `root snapshot failed`銆?
   */
  private closeWithAnimation(): void {
    if (this.isClosing) {
      return;
    }
    const winW: number = this.expandState.windowWidthVp;
    const winH: number = this.expandState.windowHeightVp;
    // 鈽呪槄鈽?2026-10-17锛?*蹇呴』鐜伴噺涓€娆¤兌鍥婄煩褰?* 鈥斺€?杩欐槸"杩斿洖鍏抽棴浼氫笉浼氬彉鎴愭棤鍔ㄧ敾"鐨勫紑鍏筹級锛?
    //   `barWinX/Y/W/H` 鐢?`measureGeometry()` 鍐欙紝鑰屽畠**鍙湪涓ゅ**琚皟鐢細
    //     路 鍚勬潯 opening 璺緞鐨勮ˉ閲忥紙`measureMiniDuringPull` 鍐呴儴閭ｆ潯閾撅級锛?
    //     路 **`refreshCollapseGeometry()`**锛堟棫鍏抽棴璺緞鍦ㄨ捣鎵嬫椂鐜伴噺涓€娆★級銆?
    //   鈬?鑻ユ湰鏉¤矾涓?`barWin*` 浠嶄负 0锛堜緥濡傛墦寮€璧扮殑鏄€€鍖栬矾寰勩€佷粠娌￠噺鍒拌繃锛夛紝
    //     `MorphShrinkState.start()` 浼氳蛋鏃犵晫閭ｆ潯 `start skipped: no srcBox` 鏀?
    //     鈬?**杩斿洖鍏抽棴鍙樻垚"鏃犲姩鐢荤洿鎺ユ秷澶?**锛堥偅鏄彲瑙佸洖褰掞紝涓嶆槸"娌′慨濂?閭ｄ箞杞伙級銆?
    //   鈿狅笍 杩欓噷**鐩存帴璋?`measureGeometry`**锛屼笉鐢ㄦ棫鐨?`refreshCollapseGeometry()` 鈥斺€?
    //      鍚庤€呰嚜甯?`morphStage === OPEN` 闂紙閫€鍖栨墦寮€鏃朵細鏄?LANDING/NONE 鈬?浠€涔堥兘涓嶉噺锛夛紝
    //      鑰屽揩鐓ц矾寰?*鍙渶瑕佽兌鍥婄煩褰?*锛堟棫鐨?`morphInitParams`/`freezeMorphMeta` 鏄粰
    //      娲婚〉琛ラ棿鐢ㄧ殑锛屾湰璺緞涓嶉渶瑕侊級銆?
    const measured: boolean = this.expandState.measureGeometry(this.getUIContext(), true, true);
    const srcBox: MorphShrinkRect = {
      left: this.expandState.barWinX,
      top: this.expandState.barWinY,
      width: this.expandState.barWinW,
      height: this.expandState.barWinH
    };
    // 鍏虫挱鏀惧櫒杩欎竴涓嬩笉瑕佸啀鑷姩鏀舵帶鍒跺尯锛堜笌 closeFullScreenPlayback 鍚屼竴鏉★級
    this.stopChromeAutoHide();
    this.isClosing = true;
    PlaybackPage.lastCloseAtMs = Date.now();
    // 鈽呪槄鈽?2026-10-17锛?*蹇収璺緞鍙敤鎬ч妫€** 鈥斺€?瑙?`closeLiveMorphFallback` 鐨勫垎姝ц鏄庯級
    //   涓や釜鍓嶆彁锛氣憼 鑳跺泭鐭╁舰锛坄srcBox`锛夐噺鍒颁簡锛涒憽 绐楀彛灏哄鏈夊€硷紙`MorphShrinkState.start`
    //   鐨勪袱绔叕寮忛兘鍚冨畠锛夈€備换涓€涓嶆垚绔嬪氨鐩存帴璧伴€€鍖栬矾寰勶紝**涓嶅幓鎷嶉偅寮犳敞瀹氭病鐢ㄧ殑蹇収**銆?
    if (srcBox.width <= 0 || srcBox.height <= 0 || winW <= 0 || winH <= 0) {
      this.closeLiveMorphFallback(
        `noSrcBox meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
        `win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      return;
    }
    PlaybackPage.ev('CLO', `snapshot p=${this.expandState.morphP.toFixed(2)} ` +
      `meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)}`);
    Logger.info(PlaybackPage.logTag,
      `RzdShrinkOverlay closeWithAnimation: snapshot ${PLAYER_ROOT_ID} ` +
      `win=${winW.toFixed(0)}x${winH.toFixed(0)} ` +
      `bar=(${srcBox.left.toFixed(1)},${srcBox.top.toFixed(1)},` +
      `${srcBox.width.toFixed(1)}x${srcBox.height.toFixed(1)})`);
    // 鈿狅笍 蹇収蹇呴』鍦?*褰㈠彉寮€濮嬩箣鍓?*鎷嶏細姝ゅ埢瀹瑰櫒鏄亽绛夊彉鎹紙婊″睆锛夛紝鎷嶅埌鐨勬墠鏄?婊″睆閭ｄ竴寮?銆?
    //   鈿狅笍鈿狅笍 `restorePlaybackWindowChrome()` **涓嶈兘**鏀惧湪鎷嶅揩鐓т箣鍓?鈥斺€?瀹冧細鎭㈠绐楀彛甯冨眬
    //     锛坄applyPlaybackWindowChrome(false,鈥?`锛屾湰椤圭洰鍦ㄦ挱鏀鹃〉浼氭妸绐楀彛閾哄埌鏁寸獥锛夛紝
    //     甯冨眬涓€鍙橈紝鎷嶅埌鐨勫氨涓嶆槸"婊＄獥閭ｄ竴寮?銆備笌鏃ц矾寰勪竴鑷达細**鏀跺熬鏃舵墠鎭㈠**銆?
    // 鈿狅笍鈿狅笍 2026-10-17锛?*鐢ㄦ埛鎴浘鏆撮湶鐨勭湡 bug**锛氫簨浠舵棩蹇?`CLO:鈥?fb=snapFail` 鈬?蹇収**姣忔閮藉け璐?*锛?
    //   浜庢槸姣忎竴娆¤繑鍥炲叧闂兘閫€鍖栧埌娲婚〉褰㈠彉 鈬?**鐢ㄦ埛浠庢潵娌＄湅鍒拌繃鏃犵晫閭ｆ潯蹇収鏀剁缉**锛?
    //   浠栨姤鐨?灏侀潰鍜岃儗鏅繕鏄竴妯′竴鏍风殑闂"灏辨槸杩欎釜锛夈€?
    //   鏍瑰洜锛?*鎴戜滑璋冪殑鏄叏灞€閭ｄ釜宸插簾寮冪殑閲嶈浇**銆俙@ohos.arkui.componentSnapshot.d.ts`
    //   `function get(id, callback, options?)` 鏍囩潃 **`@deprecated since 18`**銆佷笖浼氭姏
    //   `100001 - Invalid ID`锛涜€?*涓婃父鐢ㄧ殑鏄?`UIContext` 閭ｄ竴鏀?*锛?
    //   `wujie.pa:171077-171093`锛坄PlayerPage.closeWithAnimation` 鐨?位锛夐€愭潯瑙ｅ嚭鏉ユ鏄?
    //   ```ts
    //     this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 位@1*#)
    //   ```
    //   鈬?鐜板湪鐓т笂娓搁偅涓€鏉℃敼鍐欙紙鏈枃浠?L3464 鐨勬敞閲婇噷**鏃╁氨鍐欑潃**杩欎釜褰㈢姸锛屼唬鐮佸嵈娌¤窡涓婏級銆?
    //   鈬?澶辫触鍘熷洜鐓ф棫杩涗簨浠舵棩蹇楋紝骞?*鎶?err.code 涔熷甫涓?*锛坄fb=snapFail(100001)`锛夛細
    //     401 = 鍙傛暟閿?/ 100001 = 鎵句笉鍒拌繖涓?id 鈬?涓€娆℃埅鍥惧嵆鍙畾璁恒€?
    this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID,
      (err: BusinessError, pixmap: image.PixelMap): void => {
      // 鈹€鈹€ 鎻愪氦鍏抽棴鏃剁殑**鏈粨鐗规湁鏀跺熬**锛堟棤鐣屾病鏈?娌夋蹈绐楀彛"杩欏锛屾墍浠ュ畠娌℃湁杩欎袱鍙ワ級
      //   鈶?鎭㈠绯荤粺鏍?绐楀彛 chrome 鈥斺€?涓嶆仮澶嶇殑璇濊繑鍥炲叧闂箣鍚庨《鏍忎細鍋滃湪"鎾斁椤垫矇娴?閭ｄ竴濂楅厤鑹诧紱
      //   鈶?`morphLand()` 浜よ繕缁樺埗鏉?鈬?杩蜂綘鏉?*鐪熻韩**绔嬪埢鏄惧嚭鏉?
      //      锛堜笉浜よ繕鐨勮瘽瑕佺瓑娴眰娣″嚭 鈮?50ms 涔嬪悗鎵嶇湅鍒拌糠浣犳潯"鍟?鍦板嚭鐜帮級銆?
      //   鈿狅笍 `morphLand()` 鎶婄浉浣嶇疆 `LANDING`锛屼絾姝ゅ埢 `morphP = 1`锛堝垰 `refreshCollapseGeometry`
      //      鍒疯繃锛夆噿 瀹瑰櫒 `.height(morphClipHeight)` = 鏁寸獥銆乣scale = 1` = **鎭掔瓑**
      //      鈬?闆惰鎰熷彉鍖栵紱浣曞喌閭?1~2 甯т笂闈㈣繕鐩栫潃涓嶉€忔槑鐨勫揩鐓ф诞灞傘€?
      //   鈿狅笍 **澶辫触鏀笉杩涜繖涓€瀵?*锛堝畠瑕佽蛋閫€鍖栬矾寰勶紝閭ｆ椂 `morphLand()` 浼氭妸鐩镐綅鎻愬墠缈绘帀锛?
      //      鑰?`closeFullScreenPlayback()` 闇€瑕佷粠"杩樺湪灞曞紑鎬?璧锋墜锛夆噿 瑙佷笅闈?`if` 鐨勪綅缃€?
      if (err !== null && err !== undefined) {
        Logger.warn(PlaybackPage.logTag,
          'RzdShrinkOverlay root snapshot failed, fallback: ' + JSON.stringify(err));
        // 鈽呪槄鈽?2026-10-17锛?*鏈粨鍒绘剰鐨勫垎姝х偣**锛夛細鏃犵晫鐨勫け璐ユ敮鏄?`nav.pop()`锛堟棤杞満锛夛紝
        //   鎴戜滑杩欓噷閫€鍥?*鏈粨鏃㈡湁鐨勬椿椤靛舰鍙?*锛坄closeFullScreenPlayback()`锛夈€傜悊鐢憋細
        //   路 鏃犵晫鎷嶇殑鏄?`PLAYER_ROOT_ID`锛堜竴涓櫘閫?Stack锛夛紱鎴戜滑鎷嶇殑鏄?**`NavDestination(DIALOG)`
        //     閲岀殑鑺傜偣**锛岃繖鏉℃覆鏌撹矾寰勬槸**鎴戜滑鐗规湁鐨?* 鈬?涓€鏃?`componentSnapshot` 鍦ㄨ繖鏉¤矾涓?
        //     绯荤粺鎬у彇涓嶅埌鍥撅紝**姣忎竴娆¤繑鍥炲叧闂?*閮戒細閫€鍖栨垚"椤甸潰鐩存帴娑堝け" 鈥斺€?
        //     閭ｆ槸姣?鑳屾櫙鍙墿涓€鏉?涓ラ噸寰楀鐨勫彲瑙佸洖褰掞紱
        //   路 娲婚〉褰㈠彉鏈韩鏄?*宸茶鐢ㄦ埛纭鍙敤**鐨勯偅涓€濂楋紙鈶°€屼笂鎷夋墦寮€/涓嬫媺鍏抽棴鐨勫皝闈?鑳屾櫙鍔ㄧ敾姝ｅ父銆嶏級锛?
        //     閫€鍥炲幓鏈€鍧忎篃鍙槸鍥炲埌鍘熸潵鐨勮鎰熺憰鐤点€?
        //   鈿狅笍 澶辫触鍘熷洜鐓ф棫鎵?`Logger.warn`锛屽苟鎶婂師鍥犲甫杩涗簨浠舵棩蹇楋紙`CLO` 鐨?`fb=`锛夛紝
        //     **涓€娆℃埅鍥惧嵆鍙垽璇?*锛堣 `closeFallbackReason`锛夈€?
        this.closeLiveMorphFallback(`snapFail(${err.code})`);
        return;
      }
      this.restorePlaybackWindowChrome();
      // 鈽呪槄鈽呪槄 2026-10-17锛?*淇敤鎴峰疄娴嬨€屽叧闂椂浼氬嚭鐜颁袱涓皝闈€?*锛?
      //   蹇収宸茬粡鎷嶅埌浜嗗皝闈紝鑰屼笅闈?`morphLand()` 浼氭妸鐩镐綅缃垚 `LANDING`
      //   鈥斺€?`LANDING` 鍦?`morphContainerActive()` 閲岀畻"鐪熺殑鍦ㄦ挱" 鈬?澹冲眰鍏嬮殕灞備細琚偅鏉?
      //   鐩镐綅鍏滃簳鍙捣鏉?鈬?**蹇収閲岄偅寮犲皝闈?+ 鍏嬮殕灞傞偅寮犲皝闈㈠悓鏃堕** = 涓や釜灏侀潰銆?
      //   鈬?鍦?`morphLand()` **涔嬪墠**澹版槑"杩欎竴鍏冲綊蹇収"锛屾诞灞傞棬锛坄morphOverlayBridging`锛?
      //     闅忓悗鎭掑亣銆傦紙鍙湪蹇収鎴愬姛杩欎竴鏀０鏄庯紱澶辫触鏀閫€鍥炴椿椤靛舰鍙橈紝浠嶉渶瑕佹诞灞傘€傦級
      this.expandState.beginSnapshotShrink();
      // 鈽呪槄鈽呪槄 2026-10-17锛堢敤鎴峰疄娴嬨€?*绯荤粺杩斿洖鍏抽棴鎾斁鍣紝鎾斁鏉￠偅涓変釜鎸夐挳鍑虹幇鐨勬湁鐐规棭浜?*銆嶏級
      //   鍘熸潵杩欓噷**绔嬪埢** `morphLand()` 鈥斺€?閭ｆ槸"浜よ繕缁樺埗鏉?鈬?杩蜂綘鏉＄湡韬樉鍑烘潵"閭ｄ竴姝ワ紝
      //   浜庢槸蹇収杩樻病缂╁畬锛堚増350ms锛夛紝搴曚笅鐨勮糠浣犳潯锛堝惈閭ｄ笁涓寜閽級灏卞凡缁忛湶鍑烘潵浜?
      //   鈬?瑙傛劅"鎸夐挳鍏堝嚭鐜般€佸皝闈㈠悗钀戒綅"銆?
      //   鈬?鎸埌鏀剁缉**缁撴潫**锛坄shrink.start` 鐨?onDone锛岃涓嬶級銆傝繖涓€璺笂鐩镐綅淇濇寔 ENTERING/LEAVING锛?
      //     `realCoverVisible()` 涔熷洜姝ょ户缁浣嶏紝涓嶄細鍐嶅啋鍑虹浜屽紶灏侀潰銆?
      //   鈿狅笍 `morphLand()` 鍙墿"鐩镐綅 鈫?LANDING + 浜よ繕缁樺埗鏉?涓や欢浜嬶紝鏅?350ms 璋冩病鏈夊壇浣滅敤銆?
      const shrink: MorphShrinkState = this.morphShrinkState();
      shrink.start(this.getUIContext(), pixmap, srcBox, winW, winH, (): void => {
        // 鈽呪槄鈽?2026-10-17锛堢収鎼?`MainPage` 閭ｄ釜 **onDone 位@12*#**锛宍wujie.pa:154940-154949`锛夛細
        // ```ts
        //   () => { this.miniHidden = false; this.shrinkPixmap = undefined; }
        // ```
        //   路 `miniHidden = false` 鈥斺€?鏈粨瀵瑰簲鐨勬槸"杩蜂綘鏉?*鐪熻韩**鍙"锛?
        //     灏辨槸 `morphLand()`锛堜氦杩樼粯鍒舵潈锛夈€?*瀹冨繀椤诲湪鏀剁缉缁撴潫杩欎竴鍒?*锛岃涓婇潰鐨勮鏄庯紱
        //   路 `shrinkPixmap = undefined` 鈥斺€?鈽?**蹇呴』鍋?*锛氶偅鏄竴寮?*婊＄獥** PixelMap
        //     锛?080脳2400脳4B 鈮?10MB 绾э級锛屽叡浜姸鎬佷竴鐩村紩鐢ㄧ潃瀹冨氨涓嶄細琚洖鏀躲€?
        //     涓婁竴鐗?*婕忎簡杩欎竴鍙?* 鈬?姣忓叧涓€娆℃挱鏀惧櫒灏卞鐣欎竴寮狅紙鐩村埌涓嬩竴娆″叧闂墠琚鐩栵級銆?
        Logger.info(PlaybackPage.logTag, 'RzdShrinkOverlay onDone (overlay hidden, pixmap dropped)');
        this.expandState.morphLand();
        shrink.clearPixmap();
        // 娴眰鏀跺熬锛堚増350ms锛変箣鍚庡啀鏀惧紑闂搁棬锛氭甯歌矾寰勪笅閭ｆ椂椤甸潰鏃╁凡琚?pop锛?
        // 杩欎竴鍙ュ彧鏄?涓囦竴娌?pop 鎺?鐨勮嚜鎰堬紙鍚屽け璐ユ敮鐨勭悊鐢憋級銆?
        this.isClosing = false;
      });
      PlaybackPage.ev('SQZ', `shrink win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      this.state.isShowPlay = false;
    });
  }

  /** 鍙栧緱鍏变韩鐨勫揩鐓ф敹缂╃姸鎬侊紙涓庡３灞?`Index` 鍚屼竴涓?AppStorageV2 瀹炰緥锛夈€?*/
  private morphShrinkState(): MorphShrinkState {
    return AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
  }

  /**
   * 鈽呪槄鈽?2026-10-17锛氬揩鐓ц矾寰勪笉鍙敤鏃剁殑**閫€鍖栧嚭鍙?* 鈥斺€?閫€鍥炴湰浠撴棦鏈夌殑"娲婚〉褰㈠彉"鍏抽棴銆?
   *
   * ## 杩欐槸涓庢棤鐣岀殑**涓€澶勫埢鎰忓垎姝?*锛堣鍦ㄦ锛屽埆鍐嶅綋浣?娌＄収鎼?锛?
   * 鏃犵晫 `位@1*#`锛坄wujie.pa:181020-181077`锛夊湪蹇収澶辫触鏃舵槸 `nav.pop()`锛?*鏃犲弬 = 涓嶅甫杞満**锛夛紝
   * 涔熷氨鏄?椤甸潰鐩存帴娑堝け"銆傛垜浠?*涓?*鐓ф惉閭ｄ竴鏉★紝鐞嗙敱涓ゆ潯锛?
   * 1. 鎷嶇殑瀵硅薄涓嶅悓锛氭棤鐣屾媿 `PLAYER_ROOT_ID`锛堜竴涓櫘閫?`Stack`锛夛紝鎴戜滑鎷嶇殑鏄?
   *    **`NavDestination(DIALOG)` 閲岀殑鑺傜偣** 鈥斺€?杩欐潯娓叉煋璺緞**鏄垜浠壒鏈夌殑**锛?
   *    涓€鏃?`componentSnapshot` 鍦ㄨ繖鏉¤矾涓婄郴缁熸€у彇涓嶅埌鍥撅紝**姣忎竴娆¤繑鍥炲叧闂?*閮戒細閫€鍖栨垚
   *    "椤甸潰鐩存帴娑堝け"锛岄偅鏄?*姣?鑳屾櫙鍙墿涓€鏉?涓ラ噸寰楀**鐨勫彲瑙佸洖褰掞紱
   * 2. 娲婚〉褰㈠彉鏄?*鐢ㄦ埛宸茬‘璁ゅ彲鐢?*鐨勯偅涓€濂楋紙纭娓呭崟 鈶°€屼笂鎷夋墦寮€/涓嬫媺鍏抽棴鐨勫皝闈?鑳屾櫙鍔ㄧ敾姝ｅ父銆嶏級锛?
   *    閫€鍥炲幓鏈€鍧忎篃鍙槸鍥炲埌鍘熸潵閭ｇ偣瑙傛劅鐟曠柕銆?
   *
   * ## 瑙﹀彂鏉′欢锛堜袱澶勮皟鐢ㄧ偣锛?
   * 路 `closeWithAnimation()` 鐨?*棰勬**锛氳兌鍥婄煩褰?/ 绐楀彛灏哄浠讳竴涓嶅彲鐢紙`bar=0x0`锛夛紝
   *   姝ゆ椂杩炲揩鐓ч兘涓嶅幓鎷嶏紙鎷嶄簡涔熸病鐢級锛?
   * 路 蹇収鍥炶皟鐨?*澶辫触鏀?*锛坄err` 闈炵┖锛夈€?
   *
   * ## 鍙鎬?
   * 鍘熷洜鍐欒繘闈欐€?`closeFallbackReason`锛岀敱 `closeFullScreenPlayback()` 鐨?`ev('CLO', 鈥?`
   * 涓€璧锋墦杩涗簨浠舵棩蹇楋紙寰芥爣绗崄涓夎鐨?`fb=`锛夆噿 **涓€娆℃埅鍥惧氨鑳界湅鍑鸿蛋娌¤蛋閫€鍖?*銆?
   * @param reason 閫€鍖栧師鍥狅紙鐭爣绛撅紝浼氳繘浜嬩欢鏃ュ織锛?
   */
  private closeLiveMorphFallback(reason: string): void {
    Logger.warn(PlaybackPage.logTag,
      `RzdShrinkOverlay fallback 鈫?live morph (${reason})`);
    PlaybackPage.closeFallbackReason = reason;
    // `closeFullScreenPlayback()` 鐨勭涓€閬撻椄灏辨槸 `isClosing`锛屽繀椤绘斁寮€鎵嶈繘寰楀幓銆?
    this.isClosing = false;
    this.closeFullScreenPlayback();
  }

  private closeFullScreenPlayback(): void {
    if (this.isClosing) {
      return;
    }
    // 鈽呪槄鈽?2026-10-16锛?*缁?鍏抽棴浣欐尝绐楀彛"鐩栫珷 鈥斺€?杩欎竴琛屾槸涓婁竴杞紡鎺夌殑**锛?
    //   瑙?`lastCloseAtMs` 鐨勬敞閲婏細鍐呭灞?`.onAppear()` 鐨勫厹搴曞垎鏀潬瀹冨垽鏂?
    //   "杩欎竴娆″嚭鐜扮殑鑺傜偣鏄笉鏄垰鎵嶉偅娆″叧闂殑浣欐尝"銆?*鍙湪杩欓噷鍐欍€侀偅閲岃**锛?
    //   涓ゅ鎴愬锛堜笂涓€杞彧鏈夎銆佹病鏈夊啓 鈬?闂ㄦ亽鍋囷級銆?
    PlaybackPage.lastCloseAtMs = Date.now();
    // 鈽?鏃跺簭榛戝專瀛愶細鏈鍏抽棴寮€濮嬶紙瑙?`evLog` 鐨勬敞閲婏級
    //   鈽?2026-10-17锛歚fb=` = 杩欎竴娆℃槸**浠庡揩鐓ц矾寰勯€€鍖栬繃鏉ョ殑**锛堣 `closeFallbackReason`锛夛紝
    //   璇诲畬鍗虫竻 鈬?`fb=` 绌?= 璧扮殑蹇収璺緞锛沗fb=snapFail` / `fb=noSrcBox 鈥 = 璧颁簡娲婚〉褰㈠彉銆?
    const fb: string = PlaybackPage.closeFallbackReason;
    PlaybackPage.closeFallbackReason = '';
    PlaybackPage.ev('CLO', `gen=${this.closeGen + 1} p=${this.expandState.morphP.toFixed(2)}` +
      (fb.length > 0 ? ` fb=${fb}` : ''));
    // 鈽呪槄 P0-2锛氭湰杞叧闂殑**鐙珛浠ｆ** + 鍙栨秷涓婁竴杞彲鑳借繕鎸傜潃鐨勫嵏杞藉畾鏃跺櫒銆?
    //   `isClosing` 鎸″緱浣?鏀惰捣鍔ㄧ敾杩涜涓?鐨勯噸鍏ワ紝浣嗗畠鍦?`morphCloseMs + 20`锛堚増370ms锛?
    //   灏辫娓呭洖 `false`锛岃€岄偅涓€鍒绘挱鏀鹃〉**鍙兘杩樻病 unmount** 鈬?绗簩娆＄偣鍑讳細鍐嶈捣涓€鏉?
    //   350ms 琛ラ棿 + 绗簩涓嵏杞藉畾鏃跺櫒锛岃€屼袱鏉￠摼鐨?`morphGen` 鐩稿悓 鈬?`morphGenAlive` 鎷︿笉浣忋€?
    //   鏈変簡 `closeGen` + 鍙ユ焺锛岀浜屾鐐瑰嚮瑕佷箞琚槑纭拷鐣ャ€佽涔堝共鍑€鎺ョ銆?
    const closeGen: number = this.closeGen + 1;
    this.closeGen = closeGen;
    if (this.closeSettleTimer !== -1) {
      clearTimeout(this.closeSettleTimer);
      this.closeSettleTimer = -1;
    }
    this.refreshCollapseGeometry();
    this.isClosing = true;
    // 姝ｅ湪鏀惰捣鎾斁鍣ㄦ椂涓嶈鍐嶈嚜鍔ㄦ敹鎺у埗鍖猴紙涓や釜鍔ㄧ敾鍙犱竴璧蜂細寰堜贡锛?
    this.stopChromeAutoHide();
    // 鍏抽棴鏈熼棿杩涘害浼氬仠鍦?鏀惰捣"鍑犵櫨姣锛屽埆璁╁睍寮€鐪嬮棬鐙楁妸瀹冩姠鍥炲畬鏁存€?
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 鈽?璧扮殑鏄舰鍙樿矾寰勫氨**鍙嶅悜璺戝悓涓€濂楀嚑浣?*锛氭暣椤电缉鍥炶糠浣犳潯閭ｄ竴灏忓潡銆佽鍓獥鍙ｆ敹鍥炲幓锛?
    //   鏈€鍚庤惤鍥炶糠浣犳潯锛圠ANDING锛夈€傚睍寮€/鏀惰捣灏辨槸鍚屼竴濂楀弬鏁扮殑姝ｅ弽涓ら亶锛屼换鎰忔椂鍒婚兘鑷唇銆?
    //   鈿狅笍 鍒ゅ畾鐢?`morphUsable` 鑰?*涓嶆槸** `morphContainerActive()`锛氱ǔ瀹氬睍寮€鎬佺殑鐩镐綅鏄?
    //      OPEN锛堜笉鏄?ENTERING/LEAVING锛夛紝鐢ㄥ悗鑰呭垽瀹氫細鎺夊洖"鍘嬫墎鍐呭灞傞珮搴?鐨勮€佸姩鐢?鈥斺€?
    //      鐢ㄦ埛瀹炴祴鍒扮殑銆岀敤绯荤粺杩斿洖鍏抽棴杩樻槸鏃у姩鐢汇€嶅氨鏄繖閲屻€?
    if (this.expandState.morphUsable) {
      // 鈽呪槄鈽?2026-10-16锛?*鏀惰捣杩欎竴渚т篃瑕佽繃"鍑犱綍灏辩华"閭ｉ亾闂?*锛夛細
      //   鏈疆缁?`applyMorphProgress` 鍔犱簡涓€閬撴棤鐣岀殑闂紙`morphGeomReady`锛岃閭ｄ釜瀛楁鐨勬敞閲婏級锛?
      //   鍑犱綍娌″氨缁椂瀹?*浠€涔堥兘涓嶅仛**銆傛墦寮€杩欐潯璺潬 `measureMiniDuringPull` 缃綅锛?
      //   鑰?鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖鍏抽棴"鏄粠**宸茬粡钀戒綅鐨勬墦寮€鎬?*寰€鍥炶窇 鈥斺€?姝ｅ父搴斿綋宸茬疆浣嶏紱
      //   浣嗗紓甯歌矾寰勶紙鎵撳紑鏃惰ˉ閲忓け璐ヨ繃涓€娆°€乣morphReset` 涔嬪悗鍙堣繘鏉モ€︼級浼氳瀹冩槸鍋囷紝
      //   閭ｆ椂涓嬮潰閭?460ms 鐨勬敹璧疯ˉ闂村氨鏄?*鏁存绌鸿浆** =
      //   鐢ㄦ埛瀹炴祴鐨勩€岀偣鍑诲叧闂?/ 绯荤粺杩斿洖 娌℃湁灏侀潰/鑳屾櫙鍔ㄧ敾銆嶃€?
      //   鈬?杩欓噷鐢ㄦ墦寮€鎬佸凡鏈夌殑绔偣鍑犱綍鍏滃簳鏀捐锛堟棤鐣岀殑鏀惰捣鏈潵灏变笉閲嶆柊閲忕粓鐐癸級銆?
      if (!this.expandState.ensureMorphGeomForClose()) {
        Logger.warn(PlaybackPage.logTag,
          'close: geometry unresolved on both ends 鈬?close without morph animation');
      }
      // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋細**鍏抽棴鏃堕暱涓庣紦鍔?*锛夆€斺€?
      //   **杩欎竴澶勫氨鏄敤鎴峰疄娴嬨€屽叧闂挱鏀惧櫒鍑犱箮娌″姩鐢汇€嶇殑鐪熸牴鍥犮€?*
      //   鏃犵晫"鍏抽棴鎻愪氦"锛坬uit锛夊垎鏀紙`_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md`
      //   搂0 閫熸煡琛?L27/L29锛屽父閲忚〃 搂鍏?L620-633锛夛細
      //     `reverseMs = round(REVERSE_MS(460) 脳 max(REVERSE_MIN_RATIO(0.4), morphT))`
      //     `animateMorphT(reverseMs, t = 0, REVERSE_EASING)`
      //     `REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`   鈫?鈽?**鎱㈠惎鍔?*
      //   鈿狅笍 鎴戜滑鍘熸潵鏄?**350ms + `cubicBezier(0.23, 1.0, 0.32, 1.0)`**锛岃€岄偅鏉?
      //      锛坄EASE_OUT_STR`锛夋槸**鎵撳紑鎻愪氦**鐢ㄧ殑锛?*鍓?15% 鏃堕棿灏辫蛋瀹岀害 70% 琛岀▼**
      //      鈬?350ms 閲岀害 50ms 灏辩缉瀹屼簡銆佸墿涓?300ms 鍑犱箮浠€涔堥兘娌″彂鐢?鈥斺€?
      //      鐢ㄦ埛鎰熺煡灏辨槸"**鍏抽棴鍑犱箮娌″姩鐢?*"锛氫笉鏄病鎾紝鏄?*涓€鐪ㄧ溂灏辨病浜?*銆?
      //   鈬?涓ゅ閮芥寜鏃犵晫鏀癸細鏃堕暱 `460 脳 max(0.4, morphT)`銆佺紦鍔?**`REVERSE_EASING`**銆?
      //      涓嬬晫 `460脳0.4 = 184ms` 淇濊瘉"鍙媺寮€涓€鐐圭偣灏辨澗鎵?鏃朵篃杩樻湁涓儚鏍风殑鏀跺娍銆?
      //   鈿狅笍 **鍒妸涓ゆ潯缂撳姩鎼炴贩**锛堝畾绋?搂鍏?L385 鍘熸枃锛氥€宍REVERSE_EASING` 鍙湪
      //      '鎻愪氦鍏抽棴(quit)'杩欎竴鏀敤锛?*鍙栨秷鍥炲脊鍙嶈€岀敤 `EASE_OUT_STR`**銆嶏級锛?
      //        路 鎵撳紑鎻愪氦 / 鎵撳紑鍙栨秷 鈫?`EASE_OUT_STR`
      //        路 **鍏抽棴鎻愪氦 鈫?`REVERSE_EASING`**
      //        路 鍏抽棴鍙栨秷锛堝洖寮癸級鈫?`EASE_OUT_STR`
      //   鈿狅笍 杩涘害蹇呴』鍦?`morphBeginLeaving()` **涔嬪墠**鍙栵紙涓嬮潰閭ｄ釜 `applySync` 閲屼細鏀圭浉浣嶏級銆?
      const closeFromT: number = this.expandState.morphP;
      // 鈽呪槄鈽呪槄 2026-10-17锛堜袱涓閮ㄦā鍨嬩細璇婂悗**鍏卞悓鎸囧悜**鐨勯偅涓€鏉★紝鍔犱簡鎶ゆ爮锛夛細
      //
      // ## 鐥囩姸
      // 銆岀郴缁熻繑鍥?/ 鍏抽棴鎸夐挳 / 涓嬫媺鏉炬墜锛氬皝闈?*鐩存帴涓嬪幓 / 鐩存帴鍒板皬鍦嗗舰**锛屾病鏈夌嫭绔嬮琛岄偅涓€妫掋€?
      // ## 鏈哄埗
      // 鏀惰捣琛ラ棿鐨勮捣鐐规槸**娴眰鑷繁鐨勮繘搴?* `morphOverlayP`锛岃€屽畠鍦ㄤ笅闈㈣繖绉嶆儏褰㈤噷鏄?**0**锛?
      //   路 鎵撳紑閭ｄ竴妫掔殑娴眰琛ラ棿娌￠璧锋潵锛堜緥濡傝 `hostsMorphOverlay` / 鏃╅€€鎸℃帀锛夛紝
      //     鎴?`morphOverlayReset()` 鎶?P 鍘嬪洖 0 涔嬪悗灏卞啀娌¤鎺ㄤ笂鍘伙紱
      // 鈬?浜庢槸 `morphOverlayTweenTo(false)` 鎷垮埌 `from = 0`銆乣to = 0`
      //   鈬?琚?`|to - from| < 1e-4` **鏃╅€€**锛堣繛 animateTo 閮戒笉寤猴級
      //   鈬?鑰?`morphOverlayBridging()` 鐨勭浉浣嶅厹搴曞垎鏀?*浠嶇劧涓虹湡**
      //     锛坄morphContainerActive() && snapStartW > 0 && endCoverSize > 0`锛?
      //   鈬?鍏嬮殕灞?*鏁存鍏抽棴閮界敾鍦?`morphCoverRectAt(0)` = 杩蜂綘鏉￠偅涓皬鍦?*涓婏紝涓€鍔ㄤ笉鍔ㄣ€?
      //
      // ## 淇硶锛堟姢鏍忕増锛?*鍙湪"纭疄娌￠杩?鏃?*瀵归綈锛岀粷涓嶆墦鏂鍦ㄩ鐨勮繘搴︼級
      // 鑻ユ诞灞傝繘搴︿粛鍋滃湪 0銆佽€岄〉闈㈠綋鍓嶈繘搴?> 0 鈬?鎶婂畠瀵归綈鍒伴〉闈㈣繘搴?
      // 锛? 宸叉湁鐨?`syncMorphOverlayFromPage()`锛岃涔夋鏄?娴眰杩涘害 := 椤甸潰杩涘害"锛夛紝
      // 杩欐牱鏀惰捣琛ラ棿灏辨湁浜嗙湡瀹炶捣鐐癸紙渚嬪 1 鈫?0锛夛紝涓€闀滃埌搴曟墠鎴愮珛銆?
      // 鈿狅笍 **涓嶈兘鏃犳潯浠跺榻?*锛氳嫢娴眰姝ｅ湪 1锛堝ぇ灏侀潰浣嶇疆锛夎€岄〉闈㈠凡琚墜鎸囨嫋鍒?0.05锛?
      //   鏃犳潯浠跺榻愪細璁╁厠闅嗗眰**浠庡ぇ灏侀潰鐬棿璺冲埌杩蜂綘鏉?* = 涓€娆″彲瑙佺殑璺冲彉銆?
      if (this.expandState.morphOverlayProgress() <= 0.001 && closeFromT > 0.001) {
        this.expandState.syncMorphOverlayFromPage();
        PlaybackPage.ev('OVA', `align overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
          `to p=${closeFromT.toFixed(3)}`);
      }
      // 鈽?鍏堟妸"杩涘叆鏀惰捣鐩镐綅 + 鍐荤粨鍑犱綍"鍚屾鍒峰嚭鍘伙細杩欎竴娈垫槸琛ラ棿**涔嬪墠**鐨勯澶栦慨鏀癸紝
      //   鎸夊畼鏂硅鍒欏繀椤荤敤 `applySync` 鍚屾鏍囪剰锛屽惁鍒欒ˉ闂撮甯т細鐢ㄦ棫鍊笺€?
      UIUtils.applySync((): void => {
        // 鈽?2026-10-17锛?*鐢ㄦ埛 08:46 鎴浘閲岄偅鏉＄煕鐩剧殑瀹氭€х敤**锛夛細
        //   閭ｄ竴寮犳棩蹇楁槸 `CLO:gen=1 p=1.00` 绱ф帴鐫€ `LV:anim from=0.00`
        //   鈥斺€?涓よ璇荤殑鏄?*鍚屼竴涓瓧娈?* `morphP`锛屼腑闂?*娌℃湁浠讳綍鍐欏叆**
        //   锛坄morphP` 鍏ㄤ粨鍙湁 3 涓啓鍏ョ偣锛歚pullOpenBegin` 鐨勫け璐ユ敮 / `applyMorphProgress` /
        //     `morphReset`锛岄兘涓嶅湪 `closeFullScreenPlayback` 杩欐潯鐩寸嚎涓婏級銆?
        //   鈬?鍙墿涓ょ鍙兘锛屽繀椤讳竴娆¤鏁板垎寮€锛?
        //     鈶?涓よ**涓嶆槸鍚屼竴娆″叧闂?*锛堜簨浠剁紦鍐叉槸闈欐€佺殑銆佹寜瀛楃瑁佸垏锛?
        //        鐞嗚涓婂彲鑳芥贩鍏ュ彟涓€娆″叧闂殑 `LV`锛夆噿 鎶?**`closeGen`** 鎵撹繘鏉ュ嵆鍙垽瀹?
        //        锛坄CLO` 閭ｈ鏈潵灏辨湁 `gen=`锛夛紱
        //     鈶?`morphP` 鐪熺殑鍦ㄨ繖涓よ涔嬮棿琚敼浜?鈬?`pNow=`锛?*姝ゅ**閲嶆柊璇讳竴娆★級涓?`from=`
        //        浼氬悓鏃朵负 0锛岃€?`CLO` 閭ｈ鏄?1.00銆?
        PlaybackPage.ev('LV', `anim gen=${this.closeGen} from=${closeFromT.toFixed(2)} ` +
          `pNow=${this.expandState.morphP.toFixed(2)}`);
        this.expandState.morphBeginLeaving();
      });
      const closeScale: number = closeFromT < PlaybackPage.REVERSE_MIN_RATIO ?
        PlaybackPage.REVERSE_MIN_RATIO : closeFromT;
      const morphCloseMs: number = Math.round(PlaybackPage.REVERSE_MS * closeScale);
      // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`MorphGuard.animateMorph` 鐨勭涓€鍙ワ級锛氳捣琛ラ棿涔嬪墠鎶?閰嶈壊瀹夐潤绐楀彛"
      //   鎺ㄥ埌**杩欐潯琛ラ棿缁撴潫**锛坄quietMs` 灏辨槸杩欐潯琛ラ棿鑷繁鐨勬椂闀?鈥斺€?鏃犵晫閭ｄ晶涔熸槸鎸夎皟鐢ㄧ偣浼犵殑锛?
      //   渚嬪 `closeSearchMorph` 浼?`SP_SEARCH_SETTLE_MS`锛屾湰澶勬病鏈変换浣曟柊閫犲父閲忥級銆?
      //   鈬?鍏抽棴鍔ㄧ敾璺戠潃鐨勬椂鍊欙紝鎹㈡瓕/鍙栬壊瀹屾垚鐨?涓婅壊"涓€寰嬪線鍚庢尓锛屼笉浼氬湪鍔ㄧ敾涓€旇烦鑹层€?
      this.expandState.markMorphQuiet(morphCloseMs);
      // 鈽呪槄 娴眰閭ｄ竴妫掞紙澹冲眰 `MorphCoverClone` 鐨勭画椋炲皝闈級**蹇呴』鐢辨湰澶勫悓姝ラ┍鍔?* 鈥斺€?
      //   渚濇嵁瑙?`PlayerExpandState.applyMorphProgress` 閲?鍒犳帀鑷姩澶嶄綅"閭ｆ + 鐢ㄦ埛瀹炴祴鐨?
      //   銆屼笅鎷夊叧闂椂灏侀潰鍔ㄧ敾鏄睍寮€閭ｄ竴濂椼€嶃€岀郴缁熻繑鍥炲叧闂病鏈夊皝闈㈠姩鐢汇€嶃€?
      //   鈿狅笍 鍘熸潵鍙潬澹冲眰 `@Monitor('expandState.morphStage')`锛歏2 鐨?`@Monitor` 鏄?*寮傛**鍥炶皟锛?
      //      鑰屾湰鍑芥暟鐨勬敹灏惧畾鏃跺櫒锛坄morphCloseMs + 20`锛夐噷浼氳繛鐫€璧?
      //      `morphLand()` 鈫?`morphReset()`锛堝悗鑰?*鍚屾**鎶?`morphOverlayP` 娓?0锛夆€斺€?
      //      鍙 `@Monitor` 鐨勫洖璋冩帓鍦ㄥ浣嶄箣鍚庯紝灏侀潰閭ｄ竴妫掑氨**鏁存娌℃挱**銆?
      //      杩欓噷鍦ㄨ捣琛ラ棿涔嬪墠**鍚屾**鍠婁竴澹帮紝椤哄簭灏变笉鍐嶅彇鍐充簬寰换鍔¤皟搴︺€?
      //   鈿狅笍 娴眰閭ｆ潯琛ラ棿**宸茬粡鍦ㄨ窇**鏃朵笉瑕佹姠锛坄overlayTweenAnimating()`锛夛細
      //      涓婃媺/鍥炲脊閭ｆ潯鐢卞３灞?`settlePullOpen` 鍙戣捣锛屾柟鍚戜笌鏈涓€鑷达紝鎶㈣繃鏉ュ彧浼氭墦鏂畠銆?
      //      锛坄focusMorphOverlayForPageCollapse` 鍐呴儴杩樻湁涓€灞?鏈疆鍙璧蜂竴娆?鐨勫箓绛夋姢鏍忥紝
      //        鍥犱负澹冲眰鐨?`@Monitor` 涔熶細璋冨畠 鈥斺€?瑙佽鍑芥暟鐨勬敞閲娿€傦級
      this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
      Logger.info(PlaybackPage.logTag,
        `RzdMorph close tween from morphT=${closeFromT.toFixed(3)} 鈬?${morphCloseMs}ms ` +
        `(=REVERSE_MS ${PlaybackPage.REVERSE_MS} 脳 max(REVERSE_MIN_RATIO ${PlaybackPage.REVERSE_MIN_RATIO}, morphT)) ` +
        `easing=REVERSE_EASING(0.85,0,0.5,0.88) overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
        `overlayAnimating=${this.expandState.overlayTweenAnimating()} ` +
        `coverClone=${this.expandState.morphOverlayBridging()} ` +
        `realCover=${this.expandState.realCoverVisible()}`);
      const gen: number = this.expandState.morphGen;
      this.getUIContext().animateTo({
        duration: morphCloseMs,
        curve: curves.cubicBezierCurve(0.85, 0, 0.5, 0.88)
      }, (): void => {
        // 鈽呪槄鈽呪槄 2026-10-17锛?*鐢ㄦ埛绗?2銆? 鏉?鍏抽棴鏃犲姩鐢汇€佸皝闈㈢洿鎺ヤ笅鍘?鐨勬牴鍥?*锛?
        //   涓?`playMorphOpenIntro` 閭ｄ竴澶?*瀹屽叏鍚屼竴涓敊璇?*锛堝悓涓€褰㈢姸绗?2 澶勶級锛?
        //   鍘熸潵鏄?`UIUtils.applySync(() => applyMorphProgress(0))` 鈥斺€?鍦?`animateTo` 鐨勯棴鍖呴噷
        //   鍚屾鍒锋柊鐩爣鍊?鈬?**琛ラ棿琚烦杩?* 鈬?灏侀潰鐩存帴钀藉埌缁堢偣锛?鐩存帴涓嬪幓浜?/ 鐩存帴鍒板皬鍦嗗舰"锛夈€?
        //   涓婃父鍏抽棴閭ｄ竴渚э紙`animateMorphT(reverseMs, 0, REVERSE_EASING)`锛夊悓鏍峰彧鍐欑洰鏍囧€笺€?
        //   鈿狅笍 璧风偣锛堢浉浣?+ 鍐荤粨鍑犱綍锛夐偅涓€娈?*浠嶇劧**鐢?`applySync`锛堣鏈嚱鏁颁笂闈㈤偅澶?:3729锛夆€斺€?
        //     閭ｆ槸"琛ラ棿涔嬪墠"鐨勬纭敤娉曪紝**涓嶈**涓€璧峰垹鎺夈€?
        this.expandState.applyMorphProgress(0);
      });
      this.closeSettleTimer = setTimeout((): void => {
        this.closeSettleTimer = -1;
        if (!this.isAlive) {
          // 鈽呪槄鈽?2026-10-17锛?*鐢ㄦ埛绗?鈶?鏉°€屾湁鑳屾櫙浣嗘槸楂樺害鐗逛綆銆嶇殑澶村彿瀚岀枒灏卞湪杩欓噷**锛夈€?
          //
          // ## 鍘熸潵杩欓噷鏄?鐩存帴 return"锛屼粈涔堟敹灏鹃兘涓嶅仛
          // ```ts
          //   if (!this.isAlive) { ev('SET','dead'); return; }   // 鈫?鏃у啓娉?
          // ```
          // 浜庢槸鍑犱綍**姘歌繙鍋滃湪琛ラ棿璺戝埌鐨勯偅涓綅缃?*锛氱浉浣嶈繕鏄?`LEAVING`
          // 鈬?`morphContainerActive()` 鐪?鈬?`morphClipping()` 鐪?
          // 鈬?瀹瑰櫒 `.height()` 鍚冪殑鏄?`morphClipHeight`锛堚増 杩蜂綘鏉￠偅涓€浠斤紝鍑犲崄 vp锛?
          // 鈬?**鏁撮〉鍙敾鍑哄緢鐭殑涓€鏉?*锛岃€岃儗鏅紙`MeshCoverBg`锛夋槸瀹瑰櫒鐨勫瓙鑺傜偣
          // 鈬?灞忎笂灏辨槸鐢ㄦ埛璇寸殑銆屾湁鑳屾櫙浣嗘槸楂樺害鐗逛綆銆嶃€?
          //
          // ## 涓轰粈涔?椤甸潰姝讳簡"鍙嶈€屾洿闇€瑕佹敹灏?
          // 杩欎竴鏀殑鍚箟鏄?鏀跺熬瀹氭椂鍣ㄩ啋鏉ユ椂椤甸潰宸茬粡鍗歌浇浜?锛岃€?*鍑犱綍鏄叡浜殑**
          // 锛坄PlayerExpandState` 鎸傚湪 AppStorageV2 涓婏級鈬?椤甸潰娌′簡銆佸嚑浣曡繕姝潃锛?
          // 涓嬩竴娆℃墦寮€灏辨槸浠庤繖涓€浠芥鍑犱綍璧锋墜銆?
          //
          // 鈬?涓庝笅闈㈤偅鏉?涓栦唬鍙锋棭閫€鏀?**瀵归綈鎴愬悓涓€涓舰鐘?*锛堥偅鏉℃湰鏉ュ氨鏄鐨勶級锛?
          //   缈荤浉浣?+ 鍗歌浇銆傗殸锔?浠嶇劧**涓嶈皟 `morphReset()`** 鈥斺€?杩欓噷娌℃湁鍙潬鐨?
          //   "椤甸潰宸茬粡涓嬪彴"鍒ゆ嵁锛岃€?`morphReset()` 浼氬湪椤甸潰杩樺湪灞忎笂鏃舵妸瀹瑰櫒澶嶄綅鎴愭弧灞?
          //   锛堥偅灏辨槸鐢ㄦ埛绗?鈶?鏉★級銆傚浣嶇殑姝ｇ‘鏃舵満瑙?`scheduleMorphResetAfterPop()`銆?
          PlaybackPage.ev('SET', `dead鈫扡ND+POPT p=${this.expandState.morphP.toFixed(2)}`);
          this.isClosing = false;
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          return;
        }
        // 鈽?P0-2锛氭湰杞叧闂凡琚?涓嬩竴娆″叧闂姹?鍙栦唬 鈬?鏀跺熬浜ょ粰閭ｄ竴杞紝杩欓噷浠€涔堥兘涓嶅仛
        if (closeGen !== this.closeGen) {
          PlaybackPage.ev('SET', `genWait`);
          return;
        }
        // 涓庝笂涓€鏉?*閮借**锛歚closeGen` 鎸?閲嶅鍏抽棴"锛宍morphGenAlive` 鎸?鍏抽棴閫斾腑鍙堣灞曞紑"
        if (!this.expandState.morphGenAlive(gen)) {
          // 杩欎竴杞敹璧峰凡缁忚鏂扮殑褰㈠彉浼氳瘽鍙栦唬锛堜笘浠ｅ彿鍙樹簡锛夛細鏈疆浣滃簾銆?
          //
          // 鈽呪槄 2026-10-15 琛ユ紡锛堢敤鎴峰疄娴嬨€?*娌℃硶涓嬫媺鍏抽棴鎾斁鍣?*銆?銆屽叧闂挱鏀惧櫒鍑犱箮娌″姩鐢汇€嶏級锛?
          //   鏈疆鐨勬敹璧锋棦鐒朵綔搴燂紝灏卞繀椤?*鎶?`isClosing` 鏀炬帀**銆傚畠鍙湪涓嬮潰閭ｆ潯姝ｅ父鏀跺熬閲岃娓咃紝
          //   鑰岃繖鏉℃棭閫€璺緞**娌℃湁浠讳綍浜轰細鍐嶆竻瀹?* 鈬?鍗″湪 `true` 涔嬪悗锛?
          //     路 `onDismissDrag()`锛堟湰鏂囦欢绗?567 琛岋級绗竴琛屽氨 `if (this.isClosing) return;`
          //     路 `closeFullScreenPlayback()`锛堢 1779 琛岋級鍚屾牱绗竴琛屽氨 return
          //   鈬?**涓嬫媺鏀惰捣涓庡叧闂寜閽弻鍙屾案涔呭け鏁?*锛岃€屼笖灞忎笂娌℃湁浠讳綍鍔ㄧ敾
          //     锛堣鎰熸鏄?鍏抽棴鎾斁鍣ㄥ嚑涔庢病鍔ㄧ敾"鈥斺€?鍥犱负鍏抽棴**鏍规湰娌″惎鍔?*锛夈€?
          //   鍙湁涓嬫閲嶆柊杩涙挱鏀鹃〉锛堟柊瀹炰緥锛夋墠浼?鑷繁濂戒簡"锛屾墍浠ヨ繖涓?bug 寰堝鏄撹褰撴垚鍋跺彂銆?
          //   鈿狅笍 涓婇潰 `closeGen !== this.closeGen` 閭ｆ潯**涓嶈兘**杩欐牱娓咃細閭ｆ槸"鏂颁竴杞叧闂凡鎺ョ"锛?
          //      鏍囧織褰掗偅涓€杞锛堝畠璧板埌杩欓噷鏃朵細鑷繁娓咃紝閾惧紡鑷剤锛夈€?
          Logger.warn(PlaybackPage.logTag,
            `RzdMorph close aborted by new morph session gen=${gen} ` +
            `liveGen=${this.expandState.morphGen} stage=${this.expandState.morphStage} ` +
            `鈬?release isClosing + finish the close`);
          this.isClosing = false;
          // 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖"杩欎竴鏉＄殑鏈€鍚庝竴鍧?*锛夛細
          //   涓婇潰閭ｆ潯鏃╅€€**鍙斁寮€浜?`isClosing`锛屾病鏈夋帹杩?鍏抽棴"杩欎欢浜嬫湰韬?*
          //   鈬?鎾斁椤典細**姘歌繙鐣欏湪灞忎笂**锛堢敤鎴风偣鍏抽棴涔嬪悗灞忎笂浠€涔堥兘娌″彂鐢燂級銆?
          //   涓轰粈涔堣蛋鍒拌繖閲岋細鏀惰捣杩囩▼涓嫢 `morphGen` 琚?`morphReset()` 娓呰繃涓€娆?
          //   锛堝吀鍨嬫潵婧愶細鎾斁椤佃嚜韬殑 `onDisappear` / 杩蜂綘鏉′晶鍗歌浇 / 涓婁竴杞畫鐣欐竻鐞嗭級锛?
          //   涓栦唬鍙峰氨涓庢湰杞崟鑾风殑涓嶅悓 鈥斺€?鑰?*杩欏苟涓嶄唬琛?鐢ㄦ埛涓嶆兂鍏充簡"**銆?
          //   鈬?鏈疆鏃㈢劧鏄?瑕佸叧"锛屽氨鎶婂叧闂帹鍒板簳锛?
          //     鈶?鐩存帴钀戒綅锛坄morphLand()`锛屼笌姝ｅ父鏀跺熬鍚屼竴姝ワ級锛?
          //     鈶?鍗歌浇鎾斁椤碉紙`isShowPlay=false`锛夆€斺€?
          //        鐩镐綅涓庡嚑浣曠殑娓呯悊鐢?*鍗歌浇閾捐嚜宸辩殑** `onDisappear 鈫?morphReset()` 璐熻矗锛?
          //        杩欓噷**涓嶉噸澶嶈皟**锛堥噸澶嶈皟浼氬啀澶氭帹涓€娆?`morphGen`锛屽埗閫犱笅涓€杞殑鍚岀被闂锛夈€?
          //   鈿狅笍 骞傜瓑/瀹夊叏锛歚isShowPlay` 鑻ュ凡鏄?false锛宍@Monitor` 涓嶄細閲嶅鍔ㄤ綔锛?
          //      `morphLand()` 鍦ㄩ潪褰㈠彉鎬佹槸瀹夊叏鐨勭┖鎿嶄綔璇箟锛堝彧缈荤浉浣?+ 浜よ繕鎵€鏈夋潈锛夈€?
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          PlaybackPage.ev('SET', `genBAD鈫扡ND+POPT`);
          return;
        }
        PlaybackPage.ev('SET', `ok gen=${closeGen}`);
        this.isClosing = false;
        this.restorePlaybackWindowChrome();
        // LANDING锛氭鍒绘挱鏀鹃〉宸茬粡缂╂垚閫忔槑鐨勪竴灏忓潡锛屾妸杩蜂綘鏉′氦杩樼粰瀹?
        // 锛坄miniBarOpacity()` 鍦ㄩ潪 ENTERING/LEAVING 鏃舵亽涓?1锛夛紝鍐嶅嵏杞姐€?
        this.expandState.morphLand();
        PlaybackPage.ev('LND');
        // 鈽呪槄 2026-10-15锛堢収鎼棤鐣?`squashLand`锛夛細**钀戒綅閭ｄ竴甯ц捣"鎾斁鏉℃尋鍘?鈫?鍥炲脊"**銆?
        //   椤哄簭鍜屾棤鐣岄€愬瓧涓€鑷达細`setMorph(LANDING)`锛?`morphLand()`锛屾湰甯ф挱鏀鹃〉鍋滅瑪銆?
        //   杩蜂綘鏉＄湡韬樉鍑烘潵锛夆啋 `animateSquash(SQUASH_Y 0.86, 110ms)` 鈫?320ms 杩囧啿鍥炲脊銆?
        //   鈬?鐢ㄦ埛瀹炴祴鐨勩€屾棤鐣屽叧闂椂鎾斁鏉′細寮逛竴涓嬨€嶅氨鏄繖涓€瀵硅ˉ闂淬€?
        //   鈿狅笍 蹇呴』鍦?`morphLand()` 涔嬪悗锛氭棭涓€甯у氨鏄?鎾斁椤佃繕鍦ㄧ敾銆佹潯鍏堝脊"銆?
        //   鈿狅笍 **2026-10-17 璁㈡**锛氳繖涓€鍙ュ師鏉ユ帴鐫€鍐?涓?`morphReset()` 鐨勯『搴忎笉鑳藉弽"銆?
        //      鐜板湪 `morphReset()` 宸茬粡**涓嶅湪杩欓噷**浜嗭紙鏀规垚"绛?pop 涔嬪悗"锛?
        //      瑙佷笅闈㈤偅娈佃鏄庝笌 `scheduleMorphResetAfterPop()`锛夆€斺€?
        //      鎵€浠ュ畠涓?`squashLandAnim()` 涔嬮棿涓嶅啀鏈夐『搴忛棶棰樸€?
        //      鈿狅笍 浣?`morphReset()` **浠嶇劧涓嶇** `morphSquashY`锛堟尋鍘嬫槸鐙珛鐨勪竴鏉℃爣閲忥級锛?
        //      鎵€浠ラ偅涓€妫掑湪澶嶄綅涔嬪悗鐓ф牱浼氭妸 0.86 寮瑰洖 1锛?*杩欐槸瑕佺殑**锛堟棤鐣岀殑钀戒綅鍥炲脊锛夈€?
        this.expandState.squashLandAnim(this.getUIContext());
        PlaybackPage.ev('SQZ');
        this.state.isShowPlay = false;
        PlaybackPage.ev('POPT',
          `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
        // 鈽呪槄鈽?2026-10-17锛?*鐢ㄦ埛绗?鈶?鏉°€岀獊鐒舵潵涓睍寮€鎾斁鍣ㄧ殑鍔ㄧ敾銆嶇殑鏈哄埗绾т慨娉?*锛夈€?
        //
        // ## 鍘熸潵杩欓噷鏄?鍚屼竴 tick 閲屽悓姝?morphReset()"锛屼负浠€涔堥偅鏄敊鐨?
        // ```ts
        //   this.state.isShowPlay = false;   // 鈫?澹冲眰 @Monitor锛圴2 寮傛锛夆啋 popPlayerRoute()
        //   this.expandState.morphReset();   // 鈫?鍚屾锛岀揣璺熷叾鍚?
        // ```
        // `morphReset()` 浼氭妸 `morphStage` 娓呮垚 `NONE`銆乣morphP` 澶嶄綅鎴?1銆?
        // `morphClipHeight` 娓呴浂銆乣morphScale` 澶嶄綅鎴?1
        // 鈬?`morphContainerActive()` 缈诲亣 鈬?瀹瑰櫒**涓嶈鍓€佷笉缂╂斁銆佷笉浣嶇Щ** = **婊″睆鎾斁椤?*銆?
        // 鑰岃矾鐢辫鍒?*涓嬩竴甯?*鎵嶈 `pop(false)` 鎽樻帀锛坄@Monitor` 娲惧彂涓€灞?+ 甯冨眬鎽橀櫎涓€灞傦級
        // 鈬?涓棿閭?1~2 甯у睆涓婂氨鏄細
        // ```
        //   宸茬粡缂╂垚灏忓渾鐐癸紙LANDING锛岃瑁佸湪杩蜂綘鏉￠偅涔堥珮锛?鈫?绐佺劧婊″睆鎾斁椤?鈫?娑堝け
        // ```
        // 瑙傛劅姝ｆ槸鐢ㄦ埛璇寸殑銆屽姩鐢荤粨鏉熶簡**绐佺劧鏉ヤ釜灞曞紑鎾斁鍣ㄧ殑鍔ㄧ敾**銆嶃€?
        //
        // ## 淇硶锛?*绛夐〉闈㈢湡鐨勪笅鍙板啀澶嶄綅鍑犱綍**
        // 钀戒綅锛坄morphLand()`锛夊凡缁忔妸缁樺埗鏉冧氦杩樼粰杩蜂綘鏉′簡锛岄偅涓€浠?琚鍦ㄨ糠浣犳潯閭ｄ箞楂?鐨?
        // 鍑犱綍**鍦ㄩ〉闈笅鍙颁箣鍓嶆槸瀹屽叏姝ｇ‘鐨勬樉绀虹姸鎬?*锛堢敤鎴风湅鍒扮殑灏辨槸杩蜂綘鏉★級鈥斺€?
        // 鎵€浠ュ浣?*娌℃湁浠讳綍鐞嗙敱**鎶㈠湪 pop 鍓嶉潰鍋氥€?
        // 鈿狅笍 浣嗕篃涓嶈兘涓嶅仛锛氬嚑浣曟槸鍏变韩鐨勶紝涓嶅浣嶄細姹℃煋涓嬩竴杞紙瑙?`morphGenAlive` 閭ｉ亾闂級銆?
        // 鈬?浜ょ粰 `scheduleMorphResetAfterPop()`锛?*杞鍒?鎾斁椤佃矾鐢卞凡缁忎笉鍦ㄦ爤閲?鎵嶅浣?*锛?
        //   骞跺甫"鏂颁竴杞細璇濆凡鎺ョ灏变笉璁告竻"鐨勫弻瀹堝崼銆?
        this.scheduleMorphResetAfterPop(closeGen, this.expandState.morphGen, 0);
      }, morphCloseMs + 20);
      return;
    }
    // 娌℃湁鍙潬鍑犱綍鏃剁洿鎺ュ叧闂紝缁濅笉鍥為€€鍒板帇鎵佸唴瀹瑰眰鐨勬棫杞満銆?
    Logger.warn(PlaybackPage.logTag, 'collapse without geometry: immediate landing');
    PlaybackPage.ev('CLO', 'noGeom');
    this.isClosing = false;
    this.restorePlaybackWindowChrome();
    this.state.isShowPlay = false;
    PlaybackPage.ev('POPT', 'noGeom');
    // 鈽?鍚?姝ｅ父鏀跺熬鏀?锛氬浣嶅嚑浣曞繀椤?*绛夐〉闈㈢湡鐨勪笅鍙?*锛堣 `scheduleMorphResetAfterPop`锛夈€?
    this.scheduleMorphResetAfterPop(this.closeGen, this.expandState.morphGen, 0);
    // 鍏滃簳璺緞涔熻寮逛竴涓嬶細鍚﹀垯"鍑犱綍娌￠噺鍒?鏃惰繖鏉″敮涓€鐨勬敹璧峰弽棣堝氨鏁翠釜娌℃湁
    this.expandState.squashLandAnim(this.getUIContext());
  }

  /** 涓婃 `logBranchSurface()` 鎵撹繃鐨勭鍚嶏紙鐢ㄦ潵鎶婇噸澶嶉噸缁樺帇鎴愪竴鏉★紱瑙佽鏂规硶娉ㄩ噴锛夈€?*/
  private lastBranchLog: string = '';

  /**
   * 鈽呪槄 2026-10-15锛堢洰鏍?鈶?鐨?*鍒嗘敮褰掑睘璇婃柇 + 鐗堥潰涓嶅彉閲忚嚜妫€**锛夛細鎶?鐜板湪鍒板簳璧扮殑鍝竴鏉″垎鏀?+
   * 閭ｄ竴鏀殑瀹炴祴鍑犱綍 + **涓嶅彉閲忔槸鍚︽垚绔?*"鎵撳嚭鏉ャ€?
   *
   * ## 涓轰粈涔堥渶瑕佸畠
   *
   * 鏈〉鐨勫竷灞€鏄?*涓夋潯鍒嗘敮**锛坄buildControlStack()`锛夛細
   * ```
   *   panel锛堥潰鏉匡級  鈫?usePanelLayout()
   *   wide锛堝灞?骞虫澘锛夆啇 闈?SM 涓旈潪锛圡D + HEIGHT_SM锛?
   *   phone锛堟墜鏈猴級  鈫?鍏朵綑
   * ```
   * 鑰?*鍙湁鎵嬫満褰㈡€佸湪鏈満鍙瀯閫?* 鈬?瀹藉睆/骞虫澘/妯睆/PC 閭ｄ袱鏉?*浠庢潵娌¤楠岃繃**銆?
   * 绛夋嬁鍒伴偅浜涘舰鎬佹椂锛岀涓€浠惰鐭ラ亾鐨勪簨鏄?**瀹冨埌搴曡蛋浜嗗摢涓€鏀?*"鈥斺€?
   * 鍥犱负涓夋潯鍒嗘敮鐨?*灏侀潰娓叉煋鑰呬笉鍚?*锛坧hone = 瑕嗙洊灞?`LyricFloatLayer`锛泈ide/panel = `MusicPlayInfoBlock`锛夛紝
   * 涓€鏃﹀垎鏀垽鎹笌棰勬湡涓嶇锛岀棁鐘朵細琛ㄧ幇涓?灏侀潰浣嶇疆寰堝鎬?锛岃€屾牴鍥犲叾瀹炴槸"璧伴敊浜嗘敮"銆?
   *
   * ## 涓嶅彉閲忚嚜妫€锛坄inv=` 閭ｄ竴鍒楋級鈥斺€?鎶?鐪嬬潃涓嶅"鍙樻垚"鏃ュ織鐩存帴璇翠笉鎴愮珛"
   *
   * | 鏍囪 | 鏂█ | 涓嶆垚绔嬭鏄庝粈涔?|
   * | --- | --- | --- |
   * | `coverNone` | 灏侀潰鑺傜偣閲忓緱鍒?| 閭ｄ竴鏀病鎶?`PLAYER_BIG_COVER_ID` 鎸備笂 鈬?瀹藉害/绔偣閾句細閫€鍖?|
   * | `coverSquare` | 灏侀潰瀹介珮宸?鈮?1vp | 灏侀潰琚帇鎵侊紙`constraintSize` / `layoutWeight` 鎶簡绌洪棿锛夆噿 缁灏侀潰钀戒綅浼氳烦 |
   * | `metaGapOk` | 姝屽悕椤惰竟 鈮?灏侀潰搴曡竟 鈭?1vp锛堜笉閲嶅彔锛?| **姝屽悕鍘嬪湪澶у皝闈笂** 鈬?鐢ㄦ埛鎶ョ殑"閿欎綅"鐨勪竴绉?|
   * | `metaOrder` | 姝屾墜椤惰竟 鈮?姝屽悕椤惰竟锛堟瓕鎵嬪湪姝屽悕**涓嬮潰**锛?| 涓よ椤哄簭鍙嶄簡 |
   * | `metaInWin` | 姝屽悕/姝屾墜搴曡竟 鈮?绐楀彛楂?| 姝屽悕琚尋鍑哄睆骞曪紙鍘嗗彶涓?鍋忎綆 164vp"閭ｄ釜 bug 鐨勫舰鐘讹級 |
   * | `miniClear` | 灏忔瓕璇嶉《杈?鈮?姝屾墜搴曡竟锛?*灏忔瓕璇嶄笉涓庢瓕鍚嶉噸鍙?*锛?| 鈽?杩欐鏄敤鎴锋姤鐨勩€屾挱鏀剧晫闈㈤敊浣嶃€嶏紙搂57 鐢?`MINI_LYRIC_SINK_VP=44` 淇殑锛?|
   * | `branchSane` | 鍚屼竴灞?*鍙湁涓€鏀?*锛坄usePanel` 涓?`phoneSwiper` 涓嶅悓鏃舵妸鍚屼竴鍧楀唴瀹规墭浠樼粰涓ょ缁撴瀯锛?| 鍒ゆ嵁閲嶅彔鍖鸿韪╁埌 鈬?鍏堜慨鍒ゆ嵁鍐嶈皥甯冨眬 |
   *
   * ## 瀹冧粠鍝効琚皟锛堚槄 杩欎竴娈垫湰韬槸涓疄娴嬬粨璁猴級
   *
   * 鈿狅笍 **涓嶈兘鐩存帴鍐欏湪 `@Builder` 浣撻噷** 鈥斺€?鏈疆瀹炴祴缂栬瘧鎶ラ敊锛?
   *   `'this.logBranchSurface('wide')' does not meet UI component syntax`
   *   锛圓rkTS 鐨?`@Builder` 浣撳彧鎺ュ彈 **UI 缁勪欢璇硶**锛夈€?
   * 鈬?鐜板湪鎸傚湪**涓夋潯鍒嗘敮鍚勮嚜鐨勬牴瀹瑰櫒**鐨?`.onAppear()` 涓?鈥斺€?閭ｄ竴鏀?*棣栨鎸傝浇**鏃惰Е鍙戜竴娆★紝
   *   鎵嬫満鈫斿灞忊啍闈㈡澘浜掔浉鍒囨崲鏃跺悇鏉ヤ竴娆★紙褰㈠彉鏈熼棿涓嶄細瑙﹀彂锛夈€?
   *   鐩墠鎸備簡涓夊锛氬灞忛偅鏀殑 `Column`銆佹墜鏈洪偅鏀殑 `Swiper`銆侀潰鏉块偅鏀殑鏍?`Stack`銆?
   *   `branch` 鍙傛暟鐢?*鍚勮皟鐢ㄧ偣鑷繁澹版槑**锛堝畠瀛楅潰涓婂氨鐭ラ亾鑷繁鏄皝锛夈€?
   *
   * ## 涓轰粈涔堝彲浠ョ洿鎺ュ啓鍦?`@Builder` 閲?
   *
   * 锛堟鏉″凡浣滃簾 鈥斺€?瑙佷笂銆俙@Builder` 浣撳彧鎺ュ彈 UI 缁勪欢璇硶锛屾墍浠ユ寕鍦?`.onAppear()`銆傦級
   *
   * 鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdBranch'`
   * 鈿狅笍 鍙锛氫笉鍐欎换浣曠姸鎬侊紙`lastBranchLog` 鍙槸鏃ュ織鑺傛祦鐢ㄧ殑瀛楃涓诧級銆?
   * @param branch 褰撳墠鍒嗘敮鍚嶏紙'phone' / 'wide' / 'panel'锛?
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
    // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 涓嶅彉閲忚嚜妫€锛堝叏閮ㄦ槸"涓嶆垚绔嬫墠璇磋瘽"鐨勫舰寮忥紝閬垮厤鏃ュ織閲屼竴鍫?true锛?鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
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
    // 鈽?杩欐潯灏辨槸鐢ㄦ埛鎶ョ殑銆屾挱鏀剧晫闈㈤敊浣嶃€嶇殑鏈哄櫒鍒ゆ嵁锛埪?7 鐢?MINI_LYRIC_SINK_VP 淇殑閭ｆ潯锛夈€?
    if (lyric !== undefined && singer !== undefined && lyric.y < singer.y + singer.height - 1) {
      bad.push(`miniClear(lyric.y=${lyric.y.toFixed(0)}<singer.b=${(singer.y + singer.height).toFixed(0)})`);
    }
    // 鍒ゆ嵁閲嶅彔鍖猴細MD + 妯睆鏃?usePanelLayout() 涓?usesPhoneSwiperLayout() 鍙兘鍚屾椂涓虹湡銆?
    // 鐜板湪闈?`if` 椤哄簭鍏滀綇锛堥潰鏉胯儨鍑猴級鈬?鍙"闈㈡澘鏀噷杩樿涓鸿嚜宸辨槸 phoneSwiper"锛屽氨鏄殣鎮ｃ€?
    const panel: boolean = this.usePanelLayout();
    const phoneSwiper: boolean = this.usesPhoneSwiperLayout();
    if (panel && phoneSwiper && branch !== 'phone') {
      bad.push('branchSane(panel鈭﹑honeSwiper both true)');
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
      // 鈿狅笍 绌烘暟缁勮鎵撴垚 `ok`锛屼笉鑳芥墦绌轰覆 鈥斺€?鍚﹀垯"鏃ュ織閲岄偅涓€娈垫病浜?鍜?娌¤嚜妫€"鍒嗕笉娓呫€?
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
   * @returns 鏄惁璧般€屾墜鏈?Swiper銆嶉偅涓€鏀竷灞€锛堝皝闈㈤〉 / 姝岃瘝椤?*妯悜鍒囨崲**鐨勯偅濂楋級銆?
   *
   * 鈽呪槄 2026-10-15锛堢涔濊疆路**鏀规涓€澶?娉ㄩ噴涓庡疄鐜颁笉绗?**锛夛細
   *   鍘熸敞閲婂啓鐨勬槸銆屽垽鎹笌 `buildControlStack()` 閲岄偅涓?`if` 鐨勫彇鍙?*閫愬瓧涓€鑷?*锛?
   *   `SM`锛堜笉璁洪珮锛夋垨 **`MD + HEIGHT_SM`**銆嶁€斺€?
   *   鈿狅笍 **瀹炵幇閲屽 MD 骞舵病鏈夐珮搴︽潯浠?*锛堝氨鏄?`widthBp === WIDTH_MD` 鏈韩锛夈€備袱鍙ヤ笉涓€鑷达紝
   *   鑰屼笖**涓嶄竴鑷寸殑閭ｄ釜鏂瑰悜鏄?瀹炵幇鏇村"**锛圡D + 浠绘剰楂樺害閮借繑鍥?true锛夈€?
   *
   *   鐜板湪鐨勫疄闄呰涔夛紙鐓у疄鐜板啓锛?*鏈敼琛屼负**锛夛細
   * ```
   *   widthBp === SM                      鈫?true
   *   widthBp === MD                      鈫?true      鈫?鈿狅笍 涓嶅惈楂樺害鍒ゆ柇
   *   鍏朵綑锛圠G / XL锛?                     鈫?false
   * ```
   *   鈬?瀹冩瘮 `buildControlStack()` 閭ｆ潯 `if` 鐨勫彇鍙?*澶氬懡涓?MD + 闈?HEIGHT_SM"**杩欎竴妗ｃ€?
   *
   * ## 鈽?涓?`usePanelLayout()` 鐨?*閲嶅彔鍖?*锛堝凡鐧昏锛屽埆鍦ㄨ繖閲屽伔鍋锋敼锛?
   *
   * ```
   *   usePanelLayout() 鍦?(妯睆 && widthBp !== SM) 鏃朵负鐪?
   *   鈬?閲嶅彔 = 銆愭í灞忋€戙€恮idthBp === MD銆?
   * ```
   * 濂藉鏄?`buildControlStack()` 閲?`if (usePanelLayout())` **鍦ㄥ墠** 鈬?闈㈡澘鏀儨鍑恒€?
   * 瑕嗙洊灞傝鏈嚱鏁版尅鎺?鈬?**涓嶄細鐢讳袱浠藉皝闈?*锛?
   * 鍧忓鏄繖灞炰簬"**闈?if 椤哄簭鍏滀綇**"锛屼笉鏄?鍒ゆ嵁浜掓枼"銆?
   * 鈿狅笍 **鏈嚱鏁拌繕绠＄潃 `isPhoneLyricsStyleBackdropLayout()`锛堣儗鏅牱寮忛摼锛?* 鈬?
   *   鎶婂畠鏀剁獎鎴?`&& !usePanelLayout()` 鏄?*鍙琛屼负鍙樺寲**锛堟í灞忚儗鏅牱寮忎細鍙橈級锛?
   *   鑰屾í灞忓舰鎬佹湰鏈洪獙涓嶄簡 鈬?**鍏堝喅鏉′欢**锛歚RzdBranch` 鍦ㄧ湡鏈轰笂閲忓嚭閲嶅彔鍖虹殑瀹為檯鍒嗘敮
   *   锛坄branchSane` 鏂█锛変箣鍚庯紝鍐嶅喅瀹氭敹涓嶆敹绐勩€傜櫥璁板锛?
   *   `_recover/logic-src/鐩爣鈶?瀹藉睆闈㈡澘缁熶竴-鏂藉伐鍥句笌楠屾敹.md` 搂4銆屽垽鎹噸鍙犮€嶃€?
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

  // 鈽呪槄 2026-10-15锛堢涓夊崄涔濊疆 / Round 20锛夛細`@Builder phoneSwiperBackdropImage()` **宸插垹闄?* 鈥斺€?
  //   瀹冭嚜宸辩殑 JSDoc 灏卞啓鏄?`grep -n "phoneSwiperBackdropImage"` 鍙湁瀹氫箟澶勮繖涓€涓懡涓?鈬?鏈潵灏辨槸姝讳唬鐮?锛?
  //   鍒犻櫎鍚?`backgroundImageSource()` 涔熼殢涔嬮浂璋冪敤鑰咃紙涓よ€呬竴璧蜂笅绾匡級銆?
  //   鍒犻櫎渚濇嵁涓庝骇鐗╃鍙疯嚜妫€锛坢odules.abc GONE锛夎 RzdMusic璁板繂.md 搂56.15銆?

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
            // 骞虫澘/妗岄潰锛欸ridRow 宸﹀彸鍒嗘爮锛堝皝闈?| 姝岃瘝锛夛紝椤堕儴 padding 璁╀綅缁欑粺涓€ TopArea
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
                    coverLinearScale: 1
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
                    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣?/ 鐩爣 鈶ｃ€屽灞徛烽潰鏉夸袱鍒嗘敮缁熶竴銆嶏級锛?
                    //   鏃犵晫**娌℃湁** `LyricsComponent` 鍐呭缓"姝屽悕 - 姝屾墜"琛ㄥご杩欏洖浜?
                    //   锛坄_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` L1449 鍘熸枃锛?
                    //   銆屾棤鐣屾病鏈?`LyricsComponent` 鍐呭缓 header 杩欏洖浜嬨€嶏級銆?
                    //   鈿狅笍 鎵嬫満閭ｄ竴鏀紙涓嬮潰 L2002 閭ｅ锛夌 1 鍧楀凡缁忎紶浜?`true`锛?
                    //      鑰?*瀹藉睆/闈㈡澘杩欎袱澶勫綋鏃舵紡浜?* 鈥斺€?鍙堟槸
                    //      搂56.1.6 / 搂56.16 / 搂56.17 閭ｄ釜銆屽悓涓€褰㈢姸鏈?N 澶勩€佸彧鏀逛簡涓€澶勩€嶇殑鑰佹瘺鐥呫€?
                    //   鍐椾綑鏄疄鎵撳疄鐨勶細鏈垎鏀笂闈㈠氨鏈?`MusicPlayInfoBlock`锛圠1908锛夊湪鏄剧ず
                    //   灏侀潰 + 姝屽悕 + 姝屾墜 鈬?姝岃瘝鍐嶈嚜鎶ヤ竴娆″氨鏄?鍚屼竴棣栨瓕鍚嶅嚭鐜颁袱娆?銆?
                    //   鈬?钘忔帀瀹?*涓嶄涪浠讳綍淇℃伅**锛屼笖涓庢棤鐣岀殑瑙傛劅涓€鑷淬€?
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
            // 鈽呪槄 鐩爣 鈶?鐨?*鍒嗘敮褰掑睘璇婃柇**锛堣 `logBranchSurface()` 鐨勬敞閲婏級銆?
            //   鈿狅笍 **蹇呴』鎸傚湪 `.onAppear()` 閲岋紝涓嶈兘鐩存帴鍦?`@Builder` 浣撳唴璋冪敤** 鈥斺€?
            //      ArkTS 鐨?`@Builder` 浣撳彧鎺ュ彈 **UI 缁勪欢璇硶**锛岀洿鎺ュ啓鏂规硶璋冪敤浼氱紪璇戞姤閿?
            //      锛堟湰杞疄娴嬶細`'this.logBranchSurface('wide')' does not meet UI component syntax`锛夈€?
            //   鈿狅笍 涔?*涓嶈兘**鎸傚湪"閭ｄ竴鏀殑鏍瑰鍣?涓婂氨浠ヤ负澶熶簡锛氳繖閲屾寕鍦?`Column` 涓婏紝
            //      瀹冨彧鍦?*鏈敮棣栨鎸傝浇**鏃惰Е鍙?鈬?鎵嬫満鈫斿灞忊啍闈㈡澘浜掔浉鍒囨崲鏃跺悇鏉ヤ竴娆★紝
            //      褰㈠彉鏈熼棿涓嶄細鍒峰睆锛坄logBranchSurface` 鍐呴儴杩樻湁涓€灞傜鍚嶈妭娴侊級銆?
            .onAppear((): void => {
              this.logBranchSurface('wide');
            })
          } else {
            // 鎵嬫満锛歋wiper 灏侀潰/姝岃瘝婊戝姩 + 搴曢儴鎺у埗鍖?
            Column() {
              // 鈽呪槄鈽?2026-10-16锛?*鐢ㄦ埛鐪熸満鎴浘甯﹀嚭鐨勯棶棰橈細姝岃瘝椤靛皝闈㈡病鍙樺皬**锛?
              //
              // ## 璇绘暟锛堢敤鎴?2026-10-16 22:42 鎴浘锛?
              // ```
              //   V d73f1b8 鈥?scale=1.000 p=1.000
              //   real=1 clone=0 snap=30/30 end=331/331 op=1.000 stage=2 drv=0
              //   鈥?edge=331 t=0.00        鈫?鈽?灏辨槸杩欎竴瀵癸細t 鍋滃湪 0 鈬?灏侀潰 = 331锛堟暣绐楅偅涓€浠斤級
              // ```
              //   灏侀潰灏哄 = `lyricMorph(lyricMorphT).size`锛岃€?`lyricMorphT` 鍙湁 0/1 涓や釜绋冲畾鍊硷細
              //     `t=0` 鈬?灏侀潰 = `endCoverSize`锛堚増331锛屽ぇ灏侀潰锛夛紱`t=1` 鈬?`lyricCoverSizeOf()`锛堚増48.7锛屽皬灏侀潰锛?
              //   鈬?銆屽皝闈㈡病鍙樺皬銆嶁墶 **`lyricMorphT` 娌″埌 1**銆?
              //
              // ## `lyricMorphT` 鐨勫敮涓€鍐欏叆鑰呮槸 `animateLyricMorph`锛岃€屽畠鍙粠杩欓噷琚皟
              // ```
              //   .onAnimationStart((index, targetIndex) => {
              //     if (index === targetIndex && !this.lyricMorphVisible) { return; }   // 鈫?瀹堝崼
              //     this.animateLyricMorph(targetIndex === SWIPER_INDEX_LYRIC);
              //   })
              // ```
              //   鈿狅笍 杩欎釜瀹堝崼鐨勮涔夋槸"**宸茬粡鍦ㄧ洰鏍囬〉浜?*锛坄index === targetIndex`锛屼笉鏄竴娆＄湡婊戝姩锛?
              //     灏辫烦杩? 鈥斺€?鑰?`Swiper` **娌℃湁缁戝畾 `.index()`**锛?
              //     `playbackSwiperIndex` 鍙敱 `.onChange` 鍐欍€佸苟鍦?`onAppear` 閲岃澶嶄綅鎴?0銆?
              //   鈬?鍙"閲嶆寕杞芥椂 swiper 鐨勫垵濮嬮〉 鈮?鐘舵€侀噷鐨勯〉"锛岄〉涓庣姸鎬佸氨**闀挎湡涓嶄竴鑷?*锛?
              //     鐘舵€佽鐫€姝岃瘝椤点€乻wiper 鍋滃湪绗?0 椤碉紙鎴栧弽涔嬶級鈬?鐢ㄦ埛鐪嬪埌姝岃瘝椤碉紝
              //     浣嗘病鏈変换浣?婊戝姩"鍙戠敓 鈬?`animateLyricMorph` **浠庢潵娌¤璋冪敤** 鈬?`lyricMorphT` 鎭?0
              //     鈬?灏侀潰鎭掍负澶у皝闈€?*杩欎笌鎴浘瀹屽叏鍚诲悎**銆?
              //
              // ## 鏀规硶锛堟妸鐘舵€佹満鎺ュ洖鍘伙細璁?swiper 鐨勫垵濮嬮〉 = 鐘舵€侀噷鐨勯〉锛?
              //   `.index(this.playbackSwiperIndex)` 鈥斺€?杩欐槸 ArkUI `Swiper` 鐨勫畼鏂瑰睘鎬э紝
              //   鑰屾垜浠湰鏉ュ氨鎶婅繖涓€煎綋"褰撳墠椤?鐢紙`.onChange` 鍐欏畠銆乣onAppear` 澶嶄綅瀹冿級銆?
              //   鈿狅笍 **涓嶅紩鍏ヤ换浣曟柊鏁板€?*锛氬畠鏄?鎶婂凡鏈夌殑鐘舵€佹帴鍒拌鍥句笂"锛屽睘淇竴鑷存€ц€屼笉鏄皟鍙傘€?
              //   鈿狅笍 銆?026-10-16 璁㈡銆戣繖閲屽師鏉ュ啓鐫€"`onAppear` 閲岄偅鍙?
              //      `playbackSwiperIndex = 0` 浠嶄繚鐣? 鈥斺€?**閭ｅ彞宸茬粡鍒犳帀浜?*锛?
              //      瀹冩槸鑺傜偣绾у洖璋冮噷鐨勫啓鍏ワ紝浼氭姠鎺夌敤鎴峰綋鍓嶉〉锛?
              //      "鎵撳紑鎾斁鍣ㄥ洖灏侀潰椤?鏄?*鎵撳紑鎰忓浘**鐨勮亴璐ｏ紙瑙佸唴瀹瑰眰 `onAppear` 閭ｆ闀挎敞閲婏級銆?
              //   澶嶆牳鍏抽敭瀛楋細寰芥爣**绗竷琛?* `sw=` / `tgt=`锛堟柊鍔狅級鈥斺€?
              //     `sw=1 tgt=1` 鎵嶆槸姝岃瘝椤电殑姝ｅ父鎬侊紱`sw=0` 鑰屼綘鍦ㄦ瓕璇嶉〉 鈬?灏辨槸鏈潯銆?
              Swiper() {
                Stack({ alignContent: Alignment.Bottom }) {                  // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*椤?0 鏄┖澹?*銆?
                  //   鏃犵晫鐨?`playerPane` 閲?`Swiper` 涓ら〉閮藉彧鏈?`Column().width/height('100%')`锛?
                  //   **灏侀潰涓庢瓕鍚嶆牴鏈笉鍦ㄩ〉閲?*锛岃€屽湪 `Swiper` 涔嬪鐨勮鐩栧眰
                  //   锛坄floatingCover` / `floatingMeta`锛岃 `PlayerPage瀹屾暣UI瀹氱.md` 搂3 / 搂5 / 搂6锛夈€?
                  //   鈬?杩欓噷鍒犳帀 `MusicPlayInfoBlock`锛氬畠鑷甫灏侀潰 + 姝屽悕锛?
                  //     鐣欑潃灏变細鍜岄偅涓?*鍞竴鐨勮鐩栧眰**鐢绘垚涓や唤灏侀潰銆?
                  //   鈿狅笍 瀹冨師鏉ョ殑涓や釜鑱岃矗锛坄.id(PLAYER_BIG_COVER_ID)` + `reportBig`銆?
                  //      `.id(PLAYER_META_*_ID)` + `publishMeta`锛?*宸茬粡鎼埌瑕嗙洊灞?*锛堣
                  //      `reportPlayerCoverFromOverlay` / `publishMetaEndpoint`锛夆€斺€?
                  //      杩欐槸杩欐鑳藉垹鐨勫墠鎻愶紱涓婁竴杞氨鏄紡浜嗚繖涓€姝ワ紝瀵艰嚧"灏侀潰娑堝け + 鍔ㄧ敾鍏ㄥ簾"銆?
                  //   鈿狅笍 瀹藉睆/闈㈡澘閭ｄ袱鏉″垎鏀粛鍦ㄧ敤瀹冿紙`PlaybackPage` 鍐呭彟鏈変袱澶勶級锛?
                  //      鎵€浠?import 淇濈暀銆?
                  Column() {
                    MiniLyricLinesComponent()
                      .width(StyleConstants.FULL_WIDTH)
                      .margin({
                        left: 4,
                        right: 4
                        // 鉀?2026-10-17锛?*鍘绘帀璐熷杈硅窛** 鈥斺€?鎸変笂娓?gemini 澶嶆牳缁撹锛?
                        //   椤?0 閲岀殑鍐呭蹇呴』**娴佸紡**鎺掑竷鍦ㄦ湰椤靛鍣ㄩ噷锛?*涓嶈鐢ㄧ粷瀵瑰畾浣?璐熷杈硅窛
                        //   鎶婂畠鎺ㄥ埌姝屽悕琛岄偅涓€鏉″甫**锛屽惁鍒欏舰鍙樻湡浼氫笌姝屽悕琛屻€佽繘搴︽潯鐩告挒銆?
                        //   鍘熸潵杩欓噷鏄?`bottom: -MINI_LYRIC_SINK_VP`锛堟妸瀹冨線涓嬫帹 112vp 鍘?閬垮紑姝屽悕"锛夛紝
                        //   鑰屾瓕鍚嶈鐜板湪宸叉敼鐢?*椤靛唴鍧愭爣**锛堜笂娓稿彛寰勶級鈬?涓嶅啀闇€瑕佽繖涓ˉ涓侊紝
                        //   鐣欑潃鍙嶈€屼細鎶婂畠鎺ㄥ埌鏇翠笅闈㈠幓鎾炶繘搴︽潯銆傦級
                      })
                      // 灏忔瓕璇嶅睘浜?鍐呭"锛氬弽缂栬瘧閲?`contentOpacity` 钀戒綅鎵嶇疆 1
                      .opacity(this.expandState.morphContentOpacity)
                      // 鈽呪槄 2026-10-15 鐢ㄦ埛瀹氳皟锛氥€?*鍏堥鍏ョ殑鏄皬姝岃瘝鍜屾敹钘忔寜閽?*銆?
                      //   鈬?灏忔瓕璇嶈蛋**绗竴缁?*鐨勬椂闂寸獥锛坄earlyRiseVp()`锛屾棭浜庢帶鍒跺尯閭ｄ竴缁勶級锛?
                      //   浠庝笅鍗囪捣 180vp锛涢潤姝㈡€佷綅绉绘亽 0锛岀増闈㈤€愬儚绱犱笉鍙樸€?
                      .translate({ y: this.expandState.earlyRiseVp() })
                      // 鏀惰捣杩囩▼涓唴瀹硅鍘嬫墎锛屽皬姝岃瘝浼氬拰鎺у埗鍖轰簰鐩哥洊浣?
                      // 鈽呪槄鈽?2026-10-17锛堢敤鎴凤細**銆屽皬姝岃瘝鐜板湪鍙樻垚浜嗗姩鐢荤粨鏉熶箣鍚庢墠鍑虹幇锛屾敼涓€涓嬶紝
                      //   鍙傝€冨叾瀹冨潡鎬庝箞椋炲叆銆?*锛夆噿 鎾ゅ洖涓婁竴鐗?褰㈠彉鏈熻寮€"鐨勯殣钘忛棬锛?
                      //   瀹冨拰鍒殑鍧椾竴鏍凤紝**褰㈠彉鏈熷氨璇ュ湪鍦?*銆佽蛋绗竴缁勬椂闂寸獥 `earlyRiseVp()` 浠庝笅鍗囪捣
                      //   锛堜笂闈㈤偅鏉?`.translate`锛夈€傜鎾為棶棰樼敱姝屽悕琛屾敼椤靛唴鍧愭爣瑙ｅ喅锛屼笉闈犺棌瀹冦€?
                      .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
                  }
                  // 鈽?2026-10-15 璇婃柇閿氱偣锛坄hdc shell hilog -x | Select-String 'RzdBoxes'`锛夛細
                  //   鎶?*涓変釜浼氫簰鐩稿帇鐨勫潡**鐨勭獥鍙ｇ煩褰竴娆℃墦鍑烘潵 鈥斺€?
                  //     `lyric` 灏忔瓕璇?/ `title` 姝屽悕 / `singer` 姝屾墜 / `cover` 澶у皝闈€?
                  //   鍒ゆ嵁锛歚lyric.top` 涓?`singer.bottom` 鐩镐氦 鈬?灏辨槸鐢ㄦ埛鎶ョ殑"杩欓噷閿欎綅"锛?
                  //         涓嶇浉浜よ€屼粛鐪嬬潃鍘嬪湪涓€璧?鈬?閭ｆ槸**缁樺埗**锛坰cale/clip锛夎€屼笉鏄帓鐗堬紝鍙︽壘銆?
                  .id(PlaybackPage.MINI_LYRIC_BOX_ID)
                  .onAreaChange((): void => {
                    this.logLayoutBoxes();
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                // 鈽?姝屽悕/姝屾墜閭ｄ竴琛?*鍙蛋椤舵爮閭ｄ竴妗?*锛坄pullChromeOpacity = clamp((effT-0.18)/0.44)`锛?
                //   0.18 鈫?0.62锛夛紝鍔ㄧ敾杩囩▼涓氨璇ユ贰鍏?鈥斺€?涓庣敤鎴锋媿鏉跨殑绗?2 鏉′竴鑷淬€?
                //
                // 鈿狅笍 杩欓噷鍘熸潵杩樺彔浜嗕竴灞?`metaOpacityValue() = clamp(1 - morphP/0.35)`锛?
                //   閭?*鏄糠浣犳潯閭ｄ竴渚х殑娣″嚭**鍏紡锛坱=0.35 灏卞綊闆讹級锛屽鍦ㄦ挱鏀鹃〉杩欎竴琛屼笂
                //   = 鐢ㄤ袱涓棬澶瑰悓涓€鍧楀唴瀹?鈥斺€?`pullChromeOpacity` 鏄庢槑宸茬粡鍒?1锛?
                //   鍗磋 `metaOpacityValue` 鎸夊埌 0锛屼簬鏄瓕鍚?姝屾墜**鍏ㄧ▼涓嶅彲瑙併€佽惤浣嶆墠鍐掑嚭鏉?*
                //   锛堢敤鎴峰疄娴嬬殑銆屽睍寮€涓枃瀛楃洿鍒扮粨鏉熸墠鍑虹幇銆嶏級銆?
                //   鍒犳帀杩欎竴灞傦細`MusicPlayInfoBlock.MusicInfoTexts` 鑷繁宸茬粡甯?`pullChromeOpacity`銆?
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
                    // 鈽?2026-10-15锛堢収鎼棤鐣岋級锛?*姝岃瘝椤典笉鍐嶈嚜甯?姝屽悕/璇嶆洸"琛ㄥご**銆?
                    //   鏃犵晫姝岃瘝椤甸《涓婂氨鏄偅涓€鏉℃诞灞傛í琛岋紙灏忓皝闈?+ 姝屽悕 + 鏀惰棌/鏇村锛夛紝
                    //   姝岃瘝姝ｆ枃閲屾病鏈夌浜屼釜姝屽悕銆傚師鏉ヨ繖閲屾槸 `isSmHeightMdLayout()`
                    //   鈬?绔栧睆涓婁細**鍚屾椂**鍑虹幇娴眰鐨勬瓕鍚嶅拰姝岃瘝鑷甫鐨?
                    //   "鏈夐鏃犻鐨嗚嚜鐢?- 鐜嬩竴浣?/ 璇嶏細闈掓煚"锛岃鎰熷氨鏄?姝屽悕鍑虹幇涓ゆ"銆?
                    hideLyricsMetaHeader: true,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                // 鈽呪槄鈽?2026-10-17锛?*杩欎竴鍧楁祴閲忓凡浠?鍒ゆ嵁"闄嶇骇涓?鍝ㄥ叺"** 鈥斺€?缁撹宸查棴鍚堬級锛?
                //   涓婃姤姝岃瘝椤靛唴瀹圭洅鐨?*绐楀彛椤惰竟**銆傚綋鍒濆姞瀹冩槸涓轰簡瀹?`lyricPadTop()` 瑕佷笉瑕佹崲绠楀潗鏍?锛?
                //   鏃犵晫閭ｄ釜 `boxH/2 + bottomYAtLyric` 鍚堣捣鏉ュ氨鏄?娴眰搴曡竟**鐩稿鐩掗《**"锛?
                //   鑰屾湰浠撴嬁**绐楀彛鍧愭爣**褰撶洅鍐呯浉瀵归噺鐢?鈬?鍙湪鐩掗《 鈮?0 鏃剁瓑浠枫€?
                //   鉁?**鏀跺熬缁撹锛氱洅椤剁粨鏋勪笂灏辨槸 0**锛?鐩?= Swiper 鐨勭洅锛汼wiper 鎵€鍦ㄧ殑 `Column`
                //     涓?`LyricFloatLayer()` 鏄悓涓€涓笉甯?padding 鐨?`Stack` 鐨勫瀛愶紝涓旇 `Stack`
                //     鐨勫唴瀹圭洅宸︿笂瑙?= 绐楀彛鍘熺偣 鈥斺€?瀹屾暣璇佹嵁閾捐 `PlayerExpandState.lyricBoxTopVp`锛?
                //     鈬?**涓嶉渶瑕佹崲绠楋紝涔熶笉蹇呭啀璇昏繖涓暟**銆備繚鐣欎笂鎶ュ彧涓?灏嗘潵鏈変汉鍔?padding 鏃惰兘鍙戠幇"銆?
                //   鈿狅笍 蹇呴』鐢?`globalPosition`锛堢獥鍙ｅ潗鏍囷級锛宍position` 鏄浉瀵圭埗缁勪欢鐨勩€?
                //   鈿狅笍 鍔ㄧ敾涓畠鍙兘鐬椂闈?0锛堝鍣?`.scale/.translate` 鍙樻崲杩囩殑璇绘暟锛屾甯革級锛?
                //     鍙湁**闈欐鎬?*鏄庢樉闈?0 鎵嶈鏄庣粨鏋勫彉浜嗐€?
                .onAreaChange((_oldValue: Area, newValue: Area): void => {
                  this.expandState.reportLyricBoxTop(areaLengthToVp(newValue.globalPosition.y));
                })
                // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`PlayerPage.onLyricSwipe(offsetY)` 鈥斺€?**閫愭潯瀵归綈**锛?
                //
                // 鏃犵晫锛坄_recover/logic-src/PlayerPage.abc.txt:6938-6985`锛屾寕鍦?`LyricsView` 涓婏級锛?
                // ```ts
                //   onLyricSwipe(offsetY) {
                //     if (offsetY <= -SWIPE_TOGGLE_VP) {                 // 鈫?涓婃粦
                //       if (entryAllowsManual(this.lyricImmersive)) {   // 鈫?鈽?杩欎竴鏀?*鏈夐棬**
                //         hideChrome(); clearIdle();
                //       }
                //     } else if (offsetY >= 24) {                        // 鈫?涓嬫粦锛堝瓧闈㈤噺 0x18 = 24锛?
                //       showChrome(); startIdle();                       // 鈫?杩欎竴鏀?*鏃犻棬**
                //     }
                //   }
                // ```
                // 鈽?涓ゅ涓庡師瀹炵幇鐨勫樊鍒紙閮藉凡鎸夊瓧鑺傜爜璁㈡锛夛細
                //   鈶?闃堝€硷細鎴戜滑鍘熸潵鍐欑殑鏄?**12**锛堟湰浠撹嚜瀹氱殑涓€鍗婏級锛屾棤鐣?*涓や晶閮芥槸 24**
                //      锛堜綆鏀蛋 `SWIPE_TOGGLE_VP`銆侀珮鏀槸瀛楅潰閲?`ldai 0x18`锛?
                //        褰掓。甯搁噺琛?`MiniMorph娓叉煋鏂逛笌椤跺簳鏍忔贰鍏ュ叕寮?md:171` 涔熸槸 `SWIPE_TOGGLE_VP | 24`锛夈€?
                //      鈿狅笍 12 澶鏄撹瑙︼紙鏈眰鏄?`parallelGesture`锛屾瓕璇嶄竴寰€涓婃嫋灏卞 12vp锛夈€?
                //   鈶?涓婃粦閭ｄ竴鏀湪鏃犵晫閲?*甯?`entryAllowsManual` 闂?*锛岃€?
                //      `entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`锛?
                //      榛樿妗ｆ槸 **AUTO**锛坄LyricEntryMode` 4 妗ｏ細OFF0/AUTO1/MANUAL2/BOTH3锛?
                //      瑙?`姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` 搂1锛夆噿 **榛樿妗ｄ笅涓婃粦浠€涔堥兘涓嶅仛**銆?
                //      鏈粨娌℃湁杩欎釜鐢ㄦ埛璁剧疆 鈬?鍙兘鍙?*榛樿**琛屼负锛堣 `LYRIC_SWIPE_ALLOWS_MANUAL`锛夈€?
                //   鈿狅笍 涓嬫粦閭ｄ竴鏀湪鏃犵晫閲?*娌℃湁闂?* 鈬?鎴戜滑鏃犳潯浠朵繚鐣欙紙`showChrome` + 璧疯鏃讹級銆?
                .parallelGesture(PanGesture({ direction: PanDirection.Vertical })
                  .onActionUpdate((event: GestureEvent): void => {
                    if (event.offsetY <= -PlaybackPage.SWIPE_TOGGLE_VP) {
                      if (PlaybackPage.LYRIC_SWIPE_ALLOWS_MANUAL) {
                        this.hideLyricChrome();
                      }
                    } else if (event.offsetY >= PlaybackPage.SWIPE_TOGGLE_VP) {
                      this.touchChrome();
                    }
                  }))
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.margin_lyric')
                })
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding'),
                  // 鈽呪槄 A2锛?*鎸夋诞灞傝浣?*锛堢瓑浠锋棤鐣岀殑 `lyricPadTop()`锛夆€斺€?
                  //   璁╂瓕璇嶆鏂囦笉閽诲埌椤堕儴閭ｅ紶灏侀潰 + 姝屽悕娴眰搴曚笅銆?
                  //   `lyricPadTop()` 鑷繁淇濊瘉"娴眰涓嶅彲鐢ㄦ椂杩斿洖 0"锛坄!lyricFloat 鈫?0`锛夛紝
                  //   鎵€浠ヨ繖鏉?padding 鍦ㄥ灞?/ 灏侀潰杩樻病閲忓埌鏃朵笌鏀瑰姩鍓?*閫愬儚绱犱竴鑷?*銆?
                  //   鈿狅笍 鍙姩鐣欑櫧锛?*姝岃瘝鍐呭涓€涓瓧涓嶆敼**銆?
                  top: this.expandState.lyricPadTop()
                })
                // 姝岃瘝灞炰簬"鍐呭"锛歚contentOpacity`锛堣惤浣嶆墠缃?1锛?
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
              // 鉀?2026-10-16锛?*鎾ゅ洖鎴戜笂涓€杞姞鐨?`.index()` 缁戝畾**锛夛細
              //   涓婁竴杞垜鍔?`.index(this.playbackSwiperIndex)` 鏄兂"鎶婄姸鎬佹帴鍒拌鍥句笂"锛?
              //   浣?*鏃犵晫鏍规湰涓嶈繖涔堝仛**锛氬畠鐨?`swiperProgress` 鐢?`onContentDidScroll`
              //   閫愬抚鍐欍€乣onChange` **涓嶅啓**瀹冿紙褰掓。瀹氱 搂5.2 閫愭潯瀛楄妭鐮侊細
              //   銆宍@34*^1*#^1`锛坄onChange`锛孡190080-190110锛?*涓嶅啓** `swiperProgress`銆嶏級銆?
              //   鑰?`.index()` 涓?閫愬抚鍐?progress"鏀惧湪涓€璧蜂細浜掔浉鎵撴灦锛?
              //   `Swiper` 鐨勬暣椤靛垏鎹㈡湰韬細**缈昏繃** index 0 鎵嶅埌 1锛岃嫢 index 琚粦瀹氬洖 0锛?
              //   swiper 浼氳鎷藉洖鍘?鈬?鐢ㄦ埛鏍规湰鍒囦笉鍒版瓕璇嶉〉銆?
              //   鈬?鏀瑰洖"**涓嶇粦瀹?index锛屾敼鐢?`onContentDidScroll` 椹卞姩**"锛堣涓嬮潰閭ｆ锛夈€?
              //
              // 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫鐨勮繘搴︽簮** 鈥斺€?淇?姝岃瘝椤靛皝闈㈡病鍙樺皬"鐨勬牴锛?
              // ---------------------------------------------------------------
              // 鍑哄锛氬綊妗ｅ畾绋?`_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` 搂5.2
              //   锛堥€愭潯瀛楄妭鐮?L189489-189540 缁戝畾鐐?+ L190026-190075 澶勭悊鍣級
              // 瀹樻柟 SDK锛坄swiper.d.ts:onContentDidScroll`锛孈since 12锛夛細
              //   "During page scrolling, the ContentDidScrollCallback callback is invoked
              //    for all pages in the viewport **on a frame-by-frame basis**."
              //   `(selectedIndex, index, position, mainAxisLength)`
              //     路 `selectedIndex` = 鍔ㄧ敾寮€濮嬪墠閫変腑鐨勯〉
              //     路 `index`         = **褰撳墠椤?*
              //     路 `position`      = 鍐呭鐩稿涓昏酱璧风偣鐨勭Щ鍔ㄦ瘮渚?
              //
              // 鏃犵晫鐨勫鐞嗗櫒绛変环瀹炵幇锛堥€愭潯鐓ф妱锛屽惈"鍙湪涓€渚у綊涓€鍖?杩欐潯鍏抽敭璁捐锛夛細
              // ```ts
              //   let p = position;
              //   if (index === 0) {              // 鈽?鍙湪"褰撳墠椤垫槸鎾斁椤?杩欎竴渚у綊涓€鍖?
              //     if (p < 0) { p = -p; }        //    寰€鍓嶆粦鏃?position 涓鸿礋 鈬?缈绘
              //     if (p > 1) { p = 1; }         //    涓婂す鍒?1
              //     this.swiperProgress = p;
              //   }
              // ```
              //   鈬?**鍚庡崐娈碉紙姝岃瘝椤甸偅涓€渚э級淇濇寔涓婁竴娆＄殑鍊?* 鈬?**鍋滃湪姝岃瘝椤垫椂 `p` 鎭掍负 1**銆?
              //   杩欐鏄垜浠竴鐩寸己鐨勯偅涓噺锛氬畠**涓嶄緷璧?鍙戠敓杩囦竴娆＄敤鎴锋粦鍔?**鈥斺€?
              //   鍙椤甸潰鐪熺殑鍒囪繃鍘讳簡锛宍index` 灏变細鍙樻垚 0/1銆乣p` 灏变細鍒?1銆?
              //
              // 鎴戜滑杩欎竴渚х殑鎺ユ硶锛?*鍚屼竴浠借涔夛紝鍐欏埌 `lyricMorphT` 涓?*锛夛細
              //   `lyricMorphT` 灏辨槸鏈粨鐨?`swiperProgress` 绛変环鐗╋紙0 = 灏侀潰椤电 / 1 = 姝岃瘝椤电锛夛紝
              //   鎵€浠ョ洿鎺ユ妸褰掍竴鍖栧悗鐨?`p` 鍠傜粰瀹冿紱鍐嶇敱 `syncLyricMorphToPage()` 璐熻矗
              //   "鏈€缁堥潤姝㈢鐐瑰繀椤荤瓑浜庡綋鍓嶉〉瀵瑰簲鐨勭鐐?锛堣法杩?0.5 鏃惰ˉ涓€娆★級銆?
              .onContentDidScroll((_selectedIndex: number, index: number,
                position: number, _mainAxisLength: number): void => {
                this.onSwiperContentDidScroll(index, position);
              })
              // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`onLyricInteract` 鈥斺€?姝岃瘝鍖?*瑙︽懜**灏遍噸缃┖闂茶鏃讹級
              //
              // 鏃犵晫閭ｄ竴渚э紙`_recover/logic-src/PlayerPage.abc.txt:6914-6932`锛夛細
              // ```ts
              //   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
              // ```
              // 鎸傝浇鐐瑰湪鍚屾枃浠?`190116-190130`锛?*`TouchType.Down`** 鎵嶈皟锛堜笉鏄?Move/Up锛夈€?
              // 鈿狅笍 鍏抽敭宸埆锛氬畠**鍙?* `startIdle()`锛?*涓?* `showChrome()`
              //   鈬?鎵€浠ヨ繖閲屼篃**涓嶈兘**鐢?`touchChrome()`锛堥偅涓細椤烘墜鎶婃帶鍒跺尯鍞ゅ嚭鏉ワ級銆?
              // 鈿狅笍 鎸傝浇鐐归€夊湪 `Swiper` 鑰屼笉鏄?姝岃瘝椤甸偅涓€妫靛瓙鏍?锛氭湰浠?`scheduleChromeAutoHide()`
              //   鍐呴儴杩樻湁 `canHideLyricChrome()`锛?*鍙湪姝岃瘝椤典负鐪?*锛夎繖閬撻棬
              //   鈬?鍦ㄥ皝闈㈤〉瑙︽懜鍗充娇璧蜂簡璁℃椂鍣ㄤ篃**涓嶄細**鏀惰捣浠讳綍涓滆タ
              //   鈬?涓庢棤鐣?鍙湪姝岃瘝椤垫寕"**琛屼负绛変环**锛堝皯鎸栦竴灞傚瓙鏍戠殑灞炴€ч摼锛夈€?
              // 鈿狅笍 `.onTouch` 鍙瀵熴€?*涓嶆秷璐?*浜嬩欢 鈬?涓嶅奖鍝?Swiper 鑷繁鐨勬粦鍔ㄣ€?
              .onTouch((event: TouchEvent): void => {
                if (event.type !== TouchType.Down) {
                  return;
                }
                this.onLyricInteract();
              })
              // 鈽?鐩爣 鈶?鐨?*鍒嗘敮褰掑睘璇婃柇**锛堟墜鏈烘敮锛夆€斺€?瑙?`logBranchSurface()` 鐨勬敞閲娿€?
              //   鎸傚湪 `Swiper`锛堝畠鍙瓨鍦ㄤ簬鎵嬫満杩欎竴鏀級鐨?`.onAppear()` 涓婏細
              //   鈿狅笍 鎸傚湪 `@Builder` 浣撻噷浼氱紪璇戞姤閿欙紙`does not meet UI component syntax`锛屾湰杞疄娴嬶級銆?
              .onAppear((): void => {
                this.logBranchSurface('phone');
              })
              // 鈿狅笍 杩欓噷**涓嶅啀**缁欐暣涓?Swiper 鍔?`contentOpacity`锛氭寜鍙嶇紪璇戯紝鍙湁
              //    **灏侀潰/姝岃瘝**鏄?钀戒綅鎵嶅嚭鐜?鐨勫唴瀹癸紝鑰?*姝屽悕/姝屾墜閭ｄ竴琛?*灞炰簬椤舵爮閭ｄ竴妗?
              //    锛坄pullChromeOpacity` 0.18鈫?.62锛夛紝瑕佸湪鍔ㄧ敾杩囩▼閲屽氨娣″叆銆?
              //    鎵€浠ュ垎绾т笅绉伙細灏侀潰 鈫?MusicPlayInfoBlock 鑷繁甯︼紱
              //    姝岃瘝 鈫?鍚勮嚜閭ｄ袱浠?LyricsComponent锛涘皬姝岃瘝 鈫?MiniLyricLinesComponent銆?
              .onAnimationStart((index: number, targetIndex: number, _event: SwiperAnimationEvent): void => {
                // 鈽呪槄鈽?2026-10-16锛?*杩欓噷涓嶅啀椹卞姩 `lyricMorphT`** 鈥斺€?椹卞姩鏉冨凡浜ょ粰
                //   `onContentDidScroll`锛岃鏈?`Swiper` 涓婃柟閭ｆ闀挎敞閲婏級銆?
                //   鍘熸潵杩欓噷璋?`animateLyricMorph(...)`锛岃€屽畠甯﹀畧鍗?
                //   銆宍index === targetIndex` 鈬?璺宠繃銆嶁噿 鍙鍒囬〉涓嶆槸"涓€娆＄湡婊戝姩"
                //   锛堢▼搴忓寲鍒囬〉 / 閲嶆寕杞藉垵濮嬮〉涓嶆槸 0锛夛紝鏁村椋炶**姘歌繙涓嶅惎鍔?*銆?
                //   鈬?鐜板湪杩欓噷鍙仛**璇婃柇璁℃暟**锛堜繚鐣欑鍏 `ast=` / `skp=`锛屼互渚垮姣旀柊鏃ц涓猴級锛?
                //     鐩镐綅涓庤繘搴︿竴寰嬬敱 `onSwiperContentDidScroll()` 鍐冲畾銆?
                //   鈿狅笍 淇濈暀杩欐鏄湁鎰忕殑锛氫竾涓€ `onContentDidScroll` 鍦ㄦ煇浜涙満鍨嬩笂涓嶈Е鍙戯紝
                //      绗叓琛岀殑 `ast=0-1` 灏辨槸"婊戝姩鍥炶皟瀛樺湪浣嗚繘搴﹀洖璋冧笉瀛樺湪"鐨勮瘉鎹€?
                this.diagAnimStart = `${index}-${targetIndex}`;
                if (index === targetIndex && !this.lyricMorphVisible) {
                  this.diagAnimSkip = this.diagAnimSkip + 1;
                }
              })
              .onAnimationEnd((index: number, _event: SwiperAnimationEvent): void => {
                // 鈽?A2锛歋wiper 鑷繁鐨勬粦鍔ㄧ粨鏉?鈥斺€?涓庢诞灞傞琛岀殑鏀跺熬鍋?*涓ら棶鎻℃墜**
                //   锛坄lyricSwiperSettled && lyricFlightSettled` 閮藉埌浜嗘墠鍗告帀"椋炶涓?閭ｄ竴妗ｏ級銆?
                //   鈿狅笍 鏀瑰墠杩欓噷鍙墦鏃ュ織銆?*浠庝笉缃綅 `lyricSwiperSettled`** 鈬?
                //   `finishLyricMorph` 姘歌繙杩涗笉鍘伙紙鏁村姝岃瘝椤靛皝闈㈠舰鍙樻槸姝荤殑锛夈€?
                this.lyricSwiperSettled = true;
                this.finishLyricMorph(this.lyricMorphGen);
                this.diagAnimEnd = `${index}`;
                this.diagAnimEndCount = this.diagAnimEndCount + 1;
                // 鈽呪槄鈽?2026-10-16锛?*鏀跺熬钀藉畾** 鈥斺€?鐓ф惉 `onContentDidScroll` 涔嬪悗蹇呴』琛ョ殑涓€姝ワ級锛?
                //   `onContentDidScroll` 閫愬抚缁欑殑鏄?*姣斾緥**锛屾渶鍚庝竴甯ф湭蹇呮濂芥槸 0/1
                //   锛堝疄娴嬪父瑙?0.997 杩欑锛夛紱鑰?`syncLyricMorphToPage()` 榛樿浼?*璁╀綅缁欐粴鍔?*
                //   锛坄SCROLL_SETTLE_WINDOW_MS` 閭ｉ亾绐楋級锛屾墍浠ユ粴鍔ㄤ竴鍋滃氨瑕佹湁浜烘妸 `t` 钀藉畾鍒扮鐐广€?
                //   `onAnimationEnd` 姝ｆ槸"swiper 鍋滅ǔ"鐨勫畼鏂逛俊鍙凤紙涓斿甫鏈€缁?`index`锛夈€?
                //   鈿狅笍 椤哄簭锛?*鍏?*鐢?`index` 淇 `playbackSwiperIndex`锛?*鍐?*钀藉畾
                //      锛堝惁鍒?`want` 浼氱敤鏃х储寮曠畻锛夈€?
                if (index !== this.playbackSwiperIndex) {
                  this.playbackSwiperIndex = index;
                }
                this.syncLyricMorphToPage('swiperEnd');
                Logger.info('RzdLyricFloat',
                  `swiper end index=${index} gen=${this.lyricMorphGen} t=${this.lyricMorphT.toFixed(3)}`);
              })
              .onChange((index: number): void => {
                this.diagChg = `${index}`;
                this.diagChgCount = this.diagChgCount + 1;
                this.playbackSwiperIndex = index;
                // 鈽呪槄鈽?2026-10-17锛?*鐓ф惉鏃犵晫閭ｄ釜 `onChange` 位 鐨勯€愬瓧缁撴瀯** 鈥斺€?鍘熸潵鏄棤鏉′欢 `touchChrome()`锛?
                //   鏃犵晫锛坄_recover/logic-src/PlayerPage.abc.txt:23189-23215`锛夛細
                // ```
                //   const v = 1;
                //   if (index === v) { startIdle(); }            // 姝岃瘝椤碉細鍙捣绌洪棽璁℃椂
                //   else { clearIdle(); showChrome(); }          // 灏侀潰椤碉細鍋滆鏃?+ 鍞ゅ嚭鎺у埗鍖?
                //   this.atLyricScreen = (index === v);
                // ```
                //   鈬?涓や釜鍏抽敭宸埆锛堥兘琚垜浠師鏉ラ偅鍙?`touchChrome()` 鎶规帀浜嗭級锛?
                //     鈶?鍒囧埌**姝岃瘝椤?*涓嶅敜鍑烘帶鍒跺尯锛坄touchChrome()` 浼氬敜鍑猴級锛?
                //     鈶?鍒囧埌**灏侀潰椤?*瑕?*鏄惧紡鍞ゅ嚭**骞?*鍋滄帀**绌洪棽璁℃椂
                //        锛坄touchChrome()` 鏄?鍏堣捣璁℃椂鍐嶅仠鎺?锛屽噣鏁堟灉鍚岋紝浣嗗皯浜嗛偅鏉¤涔夛級銆?
                this.onSwiperIndexChanged(index);
              })

              // 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣岋級锛?*鎺у埗鍖轰笁娈电粨鏋勭殑涓ゆ牴鍗犱綅鏉?*銆?
              //   鏃犵晫 overlay 鐨?`Swiper` 涓?杩涘害鏉?浼犺緭鏉?涔嬮棿灏辨槸杩欎袱鏍?*闆跺唴瀹?Row**
              //   锛坄wujie.pa:190464` / `190497`锛夛紝涓嶆槸 padding锛?
              //     `[Swiper | gapSwiper 琛?| gapScrub 琛?| 杩涘害鏉?浼犺緭鏉`
              //   鈶?`gapSwiper` 璧?*杩炵画**鍏紡 `playerSwiperGapOf(usableH) = clamp(0.065脳h,16,56)`
              //      锛坄wujie.pa:93497`锛夆€斺€?**涓嶆槸鏌ユ。浣嶈〃**锛堣〃閲岄偅 48/32/20 鍙湪"娌℃湁瀹炴祴
              //      `usableH` 鏃舵墠鐢?锛岃 `playerChromeTotalOf` 鐨勪袱澶勬垚瀵规崲鍊硷級锛?
              //   鈶?`gapScrub` 鏄煡琛ㄥ€硷紝浣嗘垜浠繖涓€渚?*宸茬粡**鏈夊悓涓€娈甸棿璺濓紙`ControlAreaComponent`
              //      閲?Slider 閭ｄ竴琛岀殑 `bottom` margin锛夆噿 杩欓噷缁?0锛岄伩鍏嶅悓涓€娈典袱鏉″彛寰勶紝
              //      鍏堢敤鏃ュ織鎶?瀹炴祴 vs `gapScrub`"閲忓嚭鏉ワ紙瑙?`chromeScrubGapRowHVp()`锛夈€?
              //   鈿狅笍 涓ゆ牴閮芥槸 `Row()`锛堜笉鏄?`Blank()`锛夛細鏃犵晫灏辨槸 `Row`锛屼笖绌?`Row` 鍦?`Column`
              //      閲屾寜 `.height()` 绮剧‘鍗犱綅锛屼笉浼氬儚 `Blank` 閭ｆ牱鍚冨墿浣欑┖闂淬€?
              Row() {
              }
              .id(PlaybackPage.SWIPER_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.swiperGapRowHVp())
              .hitTestBehavior(HitTestMode.None)

              Row() {
              }
              .id(PlaybackPage.CHROME_SCRUB_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.chromeScrubGapRowHVp())
              .hitTestBehavior(HitTestMode.None)

              // 鎺у埗鍖猴細闈欐 3 绉掕嚜鍔ㄦ敹璧凤紝鐐?纰颁换鎰忓鍞ゅ嚭锛堝鏍囨棤鐣岄煶涔?BarCollapse锛?
              Column() {
                Column() {
                  // 鈽呪槄 2026-10-15 鐢ㄦ埛瀹氳皟锛氥€?*杩涘害鏉″拰涓嬮潰鐨勯偅鍫嗘寜閽竴璧烽鍏?*銆嶁€斺€?
                  //   瀹冧滑鏄竴缁勶細鏁寸墖鎺у埗鍖哄湪**鍚屼竴涓椂闂寸獥**閲屼粠涓嬪崌涓婃潵锛堣 `contentRiseVp()`锛夛紝
                  //   鎵€浠ヨ繖閲?*涓嶅啀**缁欒繘搴︽潯鍗曠嫭閿欏嘲锛堜笂涓€鐗堝氨鏄偅涔堝仛閿欑殑锛夈€?
                  ControlAreaComponent({
                    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*涓嶈**閭ｄ竴琛?涓嬭浇/璇勮/鏇村"銆?
                    //   鏃犵晫鐨?`transport` 鍙湁 5 涓細鎾斁妯″紡 / 涓婁竴棣?/ 鎾斁鏆傚仠 / 涓嬩竴棣?/ 鎾斁闃熷垪
                    //   锛坄PlayerPage瀹屾暣UI瀹氱.md` 搂8.3锛岄€愰」閮藉湪锛夛紝**娌℃湁绗簩琛?*銆?
                    //   娲鹃煶澶氬嚭鏉ョ殑杩欎竴琛屽湪鎴浘閲屼竴鐪煎彲瑙?鈬?鍏虫帀瀹冩墠鏄?鐓ф惉"銆?
                    //   鈿狅笍 閭ｅ洓涓叆鍙ｆ湰韬病鍒狅紙`ControlAreaComponent` 閲屼粛鍦級锛?
                    //      瑕佹仮澶嶆妸杩欓噷鏀瑰洖 `true` 鍗冲彲銆?
                    showBottomOtherRow: false,
                    // 鈽?鑿滃崟鐘舵€佸凡鎻愬崌鍒版湰椤碉紙閭ｄ竴妯鐨勩€屾洿澶氥€嶅浘鏍囧湪鏈〉锛夛細
                    //   `ControlAreaComponent` 浠?`@Local` 鏀规垚浜?`@Param` + `@Event`銆?
                    showMenuSheet: this.playMenuOpen,
                    onMenuSheetChange: (open: boolean): void => {
                      this.playMenuOpen = open;
                    },
                    // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`hideChrome()` 鐨?闈㈡澘寮€鐫€灏变笉鏀?瀹堝崼锛夛細
                    //   鑿滃崟 sheet 宸茬敱涓婇潰閭ｄ竴瀵圭湅寰楄锛?*鍏朵綑涓や釜寮瑰眰**锛堟挱鏀鹃槦鍒?/ 鍏朵粬鐗堟湰锛?
                    //   鍦ㄦ湰缁勪欢鍐呴儴锛屽涓荤湅涓嶅埌 鈬?鐢辫繖涓洖璋冩姤涓婃潵锛屽苟杩涙敹璧烽棬锛堣 `auxSheetOpen`锛夈€?
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
              // 鈽呪槄 2026-10-15锛堝洖閫€鍚庨噸鍋氾級鐢ㄦ埛瀹氳皟锛氥€?*涓嶈娣″叆娣″嚭**銆嶁€斺€?
              //   鎺у埗鍖轰笉鍐嶉潬閫忔槑搴﹀嚭鍦猴紙鍘熸潵杩欓噷鏄?`.opacity(pullBottomIn())`锛夛紝
              //   鏀规垚**浠庝笅鍗囪捣鐨勪綅绉?*锛氭暣鐗囨帶鍒跺尯鍦ㄨ嚜宸辩殑鏃堕棿绐楀唴浠庝笅鏂?180vp 鍗囧埌浣嶏紝
              //   涓ょ粍鐨勫厛鍚庤 PlaybackPage 椤堕儴鐨?`WIN_A_*` / `WIN_B_*` 璇存槑銆?
              //   闈欐鎬佷綅绉绘亽 0锛坄morphClipping()` 涓哄亣鏃剁洿鎺ヨ繑鍥?0锛夆噿 鐗堥潰閫愬儚绱犱笉鍙樸€?
              .translate({ y: this.expandState.contentRiseVp() })
              .onTouch((event: TouchEvent): void => {
                this.touchChrome();
                // 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣岋級锛?*鎷栧姩鎺у埗鏉℃敹璧?/ 灞曞紑**锛坄BarCollapse`锛夈€?
                //   鏃犵晫 `design/src/main/ets/logic/BarCollapse.ets` 鐨勬墜鍔跨姸鎬佹満
                //   锛堝瓧鑺傜爜 `wujie.pa:83706-84140`锛夊凡閫愭潯杞啓鍒?
                //   `common/musicbasic/.../model/BarCollapse.ets`锛岃繖閲屽彧鏄妸瑙︽懜浜嬩欢鍠傜粰瀹冦€?
                //   鈿狅笍 瀹冨彧璇嗗埆**绾靛悜**鎵嬪娍锛堟í鍚戦攣瀹氬悗鏁翠覆蹇界暐锛夆噿 涓嶄細鍜屾瓕璇嶆í鍚戞粦鍔ㄦ墦鏋躲€?
                this.onChromeBarTouch(event);
              })
              // Full player collapse retains its existing path; lyric hide reclaims layout continuously.
              .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
          }
          // 缁熶竴 TopArea锛堝崟涓€瀹炰緥锛屽彔鍔犱簬鍐呭涔嬩笂锛屽垏鎹㈡柇鐐规椂涓嶉攢姣侀噸寤猴級
          TopAreaComponent({
            isShowPlay: this.state.isShowPlay,
            onBackClick: (): void => {
              // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫鐨勫叧闂垎娴?* 鈥斺€?鐢ㄦ埛銆岀郴缁熻繑鍥?鍏抽棴鎸夐挳鏄厛婊戜竴娈靛啀椋炲洖鍘汇€嶏級
              //   鏃犵晫锛氶潪鎵嬪娍鍏抽棴锛堣繑鍥?/ 鍏抽棴鎸夐挳锛夎蛋 `closeWithAnimation()` = **鎷嶅揩鐓х缉鍒拌兌鍥?*锛?
              //        鐢婚潰鏍规湰涓?婊?锛?*娲婚〉褰㈠彉鍙暀缁欎笅鎷夋墜鍔?*锛坄onReverseMorph`锛夈€?
              //   鎴戜滑鍘熸潵杩欓噷鐩存帴 `closeFullScreenPlayback()`锛? 娲婚〉褰㈠彉锛夆噿 椤甸潰鍏堟粦涓€娈碉紝
              //        鍐嶇敱澹冲眰閭ｄ竴妫掗鍥炲幓 鈬?灏辨槸浣犵湅鍒扮殑"鍏堟粦涓€娈碉紝鐒跺悗鍐嶉鍥炲幓"銆?
              //   鈿狅笍 `closeWithAnimation()` 鑷甫涓ょ骇鍏滃簳锛堣兌鍥婄煩褰?绐楀彛灏哄涓嶅彲鐢ㄣ€佸揩鐓уけ璐ワ級
              //     鈬?閮戒笉浼氭妸鎾斁椤靛崱浣忋€?
              this.closeWithAnimation();
            }
          })
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding')
            })
            .zIndex(2)
            // 椤舵爮锛氬弽缂栬瘧 `pullChromeOpacity = clamp((effT-0.18)/0.44)`锛?.18 鈫?0.62 娣″叆
            //锛?鎸夐挳涔熸槸鍦ㄥ姩鐢昏繃绋嬪氨鍑虹幇浜?灏辨槸杩欎竴灞傛瘮搴曟爮鏃╁緱澶氾級
            .opacity(this.expandState.pullChromeOpacity())
            .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋細椤甸潰渚у叧闂墜鍔跨殑**绗簩涓寕杞界偣**锛?
            //   鏃犵晫鐨勫叧闂墜鍔挎寕浜?*涓ゅ**锛坄_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md`
            //   搂1.1 鐨?鈶?涓?鈶ワ級锛?
            //     鈶?`PlayerPage` 椤堕儴閭ｆ潯 Row锛坄PanDirection.Down`, `distance:8`锛夆啇 **涓诲叆鍙?*
            //     鈶?鍐呭瀹瑰櫒
            //   鎴戜滑鍘熸潵鍙湁"鏁撮〉鏍?閭ｄ竴澶勶紙鈮堚懃锛夈€傝€屾暣椤垫牴涓婄殑绔栫洿鎷栧姩**浼氳鍐呴儴
            //   鍙粴鍔?/ 瀛愭墜鍔垮厛鍚冩帀**锛圓rkUI 鎵嬪娍鍐掓场锛氬瓙鑺傜偣浼樺厛锛夆噿
            //   鐢ㄦ埛瀹炴祴銆屾病娉曚笅鎷夊叧闂挱鏀惧櫒銆嶃€?
            //   椤舵爮杩欎竴鏉℃槸**闈炴粴鍔ㄧ殑鍥哄畾鏉″甫**銆佸繀瀹氭敹寰楀埌绔栫洿鎷栧姩 鈬?琛ヤ笂瀹冿紝涓庢棤鐣屽悓鏋勩€?
            //   鉁?绾閲忋€佷笉鏀逛换浣曟棦鏈夎涓猴細鍛戒腑鐨勮繕鏄悓涓€涓?`onDismissDrag()`锛?
            //      鍙湁"璧锋墜钀藉湪椤舵爮涓?鏃舵墠鐢卞畠鎺ョ锛坄.gesture()` 瀛愯妭鐐逛紭鍏堬級锛?
            //      椤甸潰鍏跺畠鍖哄煙鐨勬棦鏈夎涓轰竴瀛椾笉鍙樸€?
            //   鈿狅笍 涓ゅ椤舵爮瀹炰緥锛堟湰澶?+ 涓嬮潰 `!panelLayout` 閭ｆ敮锛?*蹇呴』閮芥寕** 鈥斺€?
            //      鍚﹀垯灏辨槸 搂56.1.6 / 搂56.16 閭ｄ釜銆屽悓涓€褰㈢姸鏈?N 澶勩€佸彧鏀逛簡涓€澶勩€嶇殑鑰佹瘺鐥呫€?
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
    // 鈿狅笍 杩欓噷锛坄buildControlStack` 鐨勬牴锛?*涓嶈**鍐嶇粰 `backgroundColor(imageColor)`锛?
    //    瀹冩槸涓€灞?*鎭掍笉閫忔槑**鐨勫彇鑹插簳锛坄imageColor` 鐨?alpha 鏄?0.4锛屼絾搴曡壊鏈韩锛?
    //    鈥斺€?褰㈠彉鏈熼棿瑁佸壀绐楀彛鍙湁涓€灏忓潡锛屽畠浼氳繛鍚岀獥鍙ｄ竴璧锋妸涓嬮潰鐨勯椤电硦鎺夛紝
    //    鍐嶅姞鍐呴儴閭ｅ眰杩戦粦搴曡壊锛岃鎰熷氨鏄?灞曞紑涓儗鏅槸榛戠殑"銆?
    //    鑳屾櫙鑹蹭竴寰嬬敱涓婇潰**甯︽贰鍏ョ獥鍙?*鐨勪袱灞傝礋璐ｏ紙搴曡壊 + 鍙栬壊灞傦級锛岃繖閲屼繚鎸侀€忔槑銆?
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
            // 鈽?鍚屽灞忛偅澶勶細钘忔帀 `LyricsComponent` 鑷甫琛ㄥご锛堟棤鐣屾病鏈夊畠锛夈€?
            //   鏈垎鏀笂闈?L2233 鐨?`MusicPlayInfoBlock` 宸茬粡鍦ㄦ樉绀哄皝闈?+ 姝屽悕 + 姝屾墜
            //   鈬?涓嶈棌灏辨槸"鍚屼竴棣栨瓕鍚嶅嚭鐜颁袱娆?銆傚畬鏁寸悊鐢辫 L1926 閭ｅ鐨勬敞閲娿€?
            hideLyricsMetaHeader: true,
            onSeekTime: (ms: number): void => {
              MediaService.getInstance().seek(ms);
            }
          })
        }
        .layoutWeight(1)
        // 姝岃瘝灞炰簬"鍐呭"锛歚contentOpacity`锛堣惤浣嶆墠缃?1锛?
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
      // 鈽?鐩爣 鈶?鐨?*鍒嗘敮褰掑睘璇婃柇**锛堥潰鏉挎敮锛夆€斺€?涓庡灞忛偅澶勬垚瀵癸紝鐞嗙敱瑙佸畠涓婇潰鐨勬敞閲娿€?
      .onAppear((): void => {
        this.logBranchSurface('panel');
      })

      if (!this.panelLayout) {
        TopAreaComponent({
          isShowPlay: this.state.isShowPlay,
          onBackClick: (): void => {
            // 鈽?鍚屼笂锛堢収鎼棤鐣岋細闈炴墜鍔垮叧闂?= 蹇収鏀剁缉锛屼笉鏄椿椤靛舰鍙橈級
            this.closeWithAnimation();
          }
        })
          .padding({
            left: 56,
            right: 56
          })
          .zIndex(2)
          .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
          // 鈽?鍚屼笂闈㈤偅澶勯《鏍忥細椤甸潰渚у叧闂墜鍔跨殑绗簩涓寕杞界偣锛堝鏍囨棤鐣?鈶?椤堕儴 Row锛夈€?
          //   鈿狅笍 杩欎竴澶?*蹇呴』涓庝笂闈㈤偅澶勬垚瀵瑰瓨鍦?*锛岀悊鐢变笌瀹屾暣璇存槑瑙佷笂闈㈤偅娈垫敞閲娿€?
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

  // 鈿狅笍 2026-10-17锛氳繖閲屽師鏉ヨ繕鏈変竴涓?`applyWindowSafeAreas()` 鈥斺€?**宸插垹闄?*銆?
  //   瀹冧笌涓嬮潰閭ｄ釜**娲荤潃鐨?* `applyPlaybackWindowChromeImmediately()`锛堝敮涓€璋冪敤鐐?:5534锛?
  //   鏄?*鍚屼竴浠朵簨鐨勪袱濂楀啓娉?*锛屽彧宸竴鍙?`applyPlaybackNavigationBarColor(true)`
  //   鈬?闆惰皟鐢ㄧ偣銆佺暀鐫€灏辨槸"鏀归敊鍦版柟"鐨勫叆鍙ｏ紙鏈粨宸茬粡涓鸿繖涓舰鐘跺悆杩囧ソ鍑犳浜忥級銆?
  //   鈬?鐪熻鏀规挱鏀鹃〉鐨勭獥鍙ｈ楗帮紝**鍙敼涓嬮潰閭ｄ竴涓?*銆?

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
    if (this.context === undefined) {
      return;
    }
    this.getImageColor();
  }

  /** Entry point: kicks off async album-color extraction without blocking UI. */
  getImageColor(): void {
    void this.getImageColorAsync();
  }

  /**
   * ★★★★ 2026-10-17（**跨页面网格源缓存** —— 修「展开的时候是蓝色」）
   *
   * ## 为什么展开时是蓝色
   *   无界那一侧 `MeshCoverBg` 收的是 **`$$.imgLocal`（本地封面文件）** —— 播放器打开那一刻
   *   封面已经在本地 ⇒ 背景第一帧就是**真封面**的配色，组件里那个 `makeFallback()`
   *   （按 `seed` 色相造的**四角 HSL 渐变**）基本用不上。
   *   我们这一侧封面多是**在线 URL**：页面每次打开都是新实例、`meshSrc` 为空 ⇒
   *   组件内 `makeFallback()` 先顶上 ⇒ 屏上就是那张按 seed 色相画出来的兜底网格（**蓝色**）；
   *   等真封面下载解码完才换真配色，那时动画早结束了。
   *
   * ## 做法（等价于上游"本地封面一直在"）
   *   每次提交网格源时，把**已经 enhance+blur 过的 64×64 RGBA 缓冲**（16KB）连同它的 key
   *   存成**静态字段**；下一次页面挂载时若 key 还是同一首，就直接从这份缓冲重建 PixelMap
   *   ⇒ 打开动画第一帧就是真配色，兜底网格只真正兜底。
   *   ⚠️ 存**缓冲**而不是 PixelMap：所有权简单（纯内存），页面每次自己造 PixelMap、
   *     退场照旧自己释放 ⇒ 不会双重释放。
   *   ⚠️ key 不匹配（换歌）⇒ 不采用（不会把上一首的配色串到这一首）。
   *
   * ## ⛔ 2026-10-17 当天撤回（用户实测「**展开过程中的是上一首歌的颜色**」）
   *   根因：**页面挂载那一拍 `state.getCurrentSongItem()` 还是上一首**（状态由调用方后写），
   *   于是 `currentMeshKey()` 也是上一首的 key ⇒ 命中上一首的缓冲 ⇒ 开场动画放的是**上一首的配色**。
   *   （同一拍上 `meshSeed()` 也会取到上一首 ⇒ 兜底网格同样是上一首的色相。）
   *   ⇒ **跨页面缓存整段停用**（下面 `adoptCachedMesh()` 保留实现但**无调用点**，
   *     写缓冲那两行也已删除）。要恢复它，必须先解决"挂载时状态是上一首"这个前提
   *   —— 例如由壳层在 push 前把当前歌写进状态，或者把网格做成 `AppStorageV2` 共享状态、
   *     由"正在播放的那一首"负责维护。**不要**只把缓存重新接上了事。
   */
  private static meshBufKey: string = '';
  private static meshBuf: Uint8Array | undefined = undefined;

  /** @returns 当前歌曲的网格缓存 key（= 封面 URL / 本地资源标识；取不到空串）。 */
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
   * 用上一关留下的缓冲重建网格源。
   * ⛔ **当前无调用点**（见上面「当天撤回」那段）——挂载时 `getCurrentSongItem()` 可能是上一首，
   *   直接采用会把上一首的配色放到开场动画上。保留实现是为了将来"状态先就位"之后再接回来。
   */
  private async adoptCachedMesh(): Promise<void> {
    if (this.meshSrcVersion > 0 || !this.isAlive) {
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
      if (!this.isAlive || this.meshSrcVersion > 0) {
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
   * @returns 鑳屾櫙缃戞牸鐨?*鍏滃簳绉嶅瓙** 鈥斺€?鐓ф惉鏃犵晫 `seedOfParts($$.title, $$.artist)`
   *   锛坄PlayerPage.ets:5252` 鐨勫疄鍙傦級銆?
   *
   * 鍙敤浜?灏侀潰鍙栦笉鍒版椂"閫犲厹搴曠綉鏍硷紙`MeshCoverBg.makeFallback` 鈫?`hueOfSeed` 鈫?`fillFallback`锛夈€?
   * 涓婃父 `seedOfParts` 鐨勬嫾娉曞湪褰掓。绗旇閲屾病鏈夐€愬瓧灞曞紑锛岃繖閲岀敤 `title|singer`
   * 鈥斺€?瀹冨彧褰卞搷**鑹茬浉**锛坄hueOfSeed` 鏄?Java 寮忓瓧绗︿覆鍝堝笇锛夛紝鎷兼硶涓嶅悓鍙細鎹釜鑹茬浉锛?
   * 涓嶅奖鍝?鏈夋病鏈夎儗鏅?銆?
   */
  private meshSeed(): string {
    const song = this.state.getCurrentSongItem();
    if (song === undefined) {
      return '';
    }
    const title: string = typeof song.title === 'string' ? song.title : '';
    const singer: string = typeof song.singer === 'string' ? song.singer : '';
    return title.length > 0 || singer.length > 0 ? `${title}|${singer}` : '';
  }

  /**
   * 鐢卞皝闈㈢畻鍑烘祦鍏夎儗鏅殑涓や釜棰滆壊骞跺啓杩?{@link coverTint}銆?
   *
   * 鍙湪寮€鍏虫墦寮€鏃舵墠鍋氾細鍙栬壊瑕佽蛋涓€娆¤В鐮侊紙鍦ㄧ嚎灏侀潰杩樿鍏堜笅杞斤級锛屽叧鎺夊氨鍒櫧鑺辫繖浠藉紑閿€銆?
   * 澶辫触涓嶆姤閿欎篃涓嶆敼棰滆壊 鈥斺€?淇濈暀涓婁竴棣栫殑棰滆壊鎴栧厹搴曡壊锛屾祦鍏夌収鏍疯兘鐪嬨€?
   *
   * @param pixelMap 宸茶В鐮佺殑灏侀潰浣嶅浘锛岀敱璋冪敤鏂硅礋璐ｉ噴鏀俱€?
   */
  private async extractFlowLightColors(pixelMap: image.PixelMap): Promise<void> {
    if (!this.flowLightState.enabled || !this.isAlive) {
      return;
    }
    await new Promise<void>((resolve: () => void) => {
      effectKit.createColorPicker(pixelMap,
        (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
          try {
            if (!this.isAlive || error || colorPicker === undefined) {
              return;
            }
            // 鐢ㄥ崰姣旀渶澶х殑棰滆壊浣滀负鍩鸿皟锛屽啀鍦?vividFlowColors 閲屾妸楗卞拰搴?浜害鎷夎捣鏉ワ細
            // 灏侀潰涓昏壊缁忓父鏄竴澶х墖鎺ヨ繎榛戠殑鑳屾櫙锛岀洿鎺ユ嬁瀹冨仛娴佸厜鍩烘湰鐪嬩笉瑙?
            // 锛堥椤?PR 閭ｇ増鍐欐涓€涓传鑹诧紝鎵€浠ユ病杩欎釜闂锛夈€?
            const color = colorPicker.getLargestProportionColor();
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });
  }

  /**
   * 鎶婂皝闈富鑹叉崲绠楁垚娴佸厜鐢ㄧ殑涓や釜棰滆壊骞跺彂甯冦€?
   *
   * 鍐?`coverTint` 浼氳Е鍙?{@link onCoverTintVersionChange}锛岀敱瀹冩妸棰滆壊涓嬪彂缁欑潃鑹插櫒銆?
   *
   * **涓嶅垽鏂紑鍏?*锛氭崲绠楁湰韬彧鏄嚑娆＄畻鏈紝鍏崇潃涔熷厛绠楀ソ瀛樿捣鏉?鈥斺€?杩欐牱鐢ㄦ埛
   * 鍦ㄨ缃噷涓€鎵撳紑寮€鍏筹紝绗竴甯х殑娴佸厜棰滆壊灏卞凡缁忔槸褰撳墠灏侀潰鑹诧紝涓嶄細鍏堥棯涓€涓嬪厹搴曡壊銆?
   * 鐪熸瑕佽姳閽辩殑鏄В鐮佸皝闈紝閭ｉ儴鍒嗙敱 {@link extractFlowLightColors} 鎶婂叧銆?
   *
   * @param red 灏侀潰涓昏壊绾㈤€氶亾 0鈥?55銆?
   * @param green 灏侀潰涓昏壊缁块€氶亾 0鈥?55銆?
   * @param blue 灏侀潰涓昏壊钃濋€氶亾 0鈥?55銆?
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
   * 鈽呪槄 2026-10-15锛?*涓嶅啀浜у嚭浠讳綍鑳屾櫙搴曞浘**銆傝儗鏅眰鏀规垚銆屽師濮嬪皝闈?+ 缁勪欢绾у疄鏃舵ā绯娿€?
   *   锛坽@link originalCoverSource} + {@link backdropBlurRadiusVp}锛夆噿 杩欓噷鍙墿涓や欢浜嬶細
   *   鈶?鎶?`imageLabel` 澶嶄綅鎴?*鍘熷灏侀潰**锛坄Resource`锛夛紱鈶?绠楀嚭 `state.imageColor`
   *   锛堟挱鏀鹃〉鑳屾櫙閭ｅ眰鍙栨牱鑹诧級+ 娴佸厜鑹层€備腑闂磋В鐮佸嚭鏉ョ殑 PixelMap **鍙敤浜庡彇鑹诧紝鐢ㄥ畬鍗冲純**銆?
   */
  private async getImageColorAsync(): Promise<void> {
    const jobSeq: number = ++this.imageColorJobSeq;
    const ctx = this.context;
    if (!ctx) {
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (!song) {
      // 鈽呪槄鈽?2026-10-17锛堢敤鎴枫€岀偣鍑绘挱鏀炬潯鎵撳紑杩樻槸娌℃湁鑳屾櫙銆嶇殑涓€鏉＄湡鍑犱綍鍙兘锛夛細
      //   鐐瑰嚮鎵撳紑閭ｄ竴鍒婚〉闈㈠垰鎸傝浇锛宍state.getCurrentSongItem()` 鍙兘**杩樻病瑙ｆ瀽鍑烘潵**
      //   鈬?杩欓噷鍘熸潵鐩存帴 `return` 鈬?鏃笉鍙栬壊涔熶笉寤虹綉鏍硷紝鑰屼笖**娌℃湁浠讳綍浜哄啀鏉ュ彨涓€娆?*
      //   锛堝悓涓€棣栨瓕涓嶄細瑙﹀彂 `selectIndex`/`playQueueIds` 鐨?`@Monitor`锛?
      //   鈬?杩欎竴鏁村叧閮芥病鏈夎儗鏅紝鐩村埌鐢ㄦ埛鍒囨瓕銆傗噿 鏀规垚璧板悓涓€鏉?*鏈夌晫閲嶅彇**锛堟渶澶?4 娆?脳 400ms锛夈€?
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
      // 鍦ㄧ嚎姝屾洸锛氬彧**瑙ｇ爜**灏侀潰缁欐祦鍏夊彇鑹茬敤銆?
      //
      // 鈽呪槄 2026-10-15锛氳繖閲屽師鏉ヨ繕浼?`effectKit.createEffect(coverPm).blur(imageBlurRadius())`
      //   棰勬覆鏌撲竴寮犳ā绯?PixelMap 褰撳簳鍥?鈥斺€?**璇ラ娓叉煋宸叉暣浣撳仠鐢?*锛堣儗鏅敼瀹炴椂妯＄硦锛?
      //   搴曞浘缁欑殑鏄?{@link originalCoverSource()} 鐨勫師濮嬪皝闈級銆?
      //   鈬?`imageLabel` 涓嶅啀琚祴鎴愭ā绯婂浘锛涜В鐮佽繖涓€姝ヤ繚鐣欙紝鍥犱负
      //   {@link extractFlowLightColors} 闇€瑕佷竴涓幇鎴愮殑 PixelMap锛堝厤寰椾负鍙栬壊鍐嶄笅杞戒竴閬嶅皝闈級銆?
      if (song.cover.length > 0 && this.isAlive) {
        try {
          const pair: CoverDecodePair =
            await PlaybackPage.loadOnlineCoverPair(song.cover);
          if (pair.full !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            // 娴佸厜鍙栬壊锛氳秮浣嶅浘宸茬粡瑙ｇ爜濂介『鎵嬬畻涓€娆★紝涓嶇敤涓哄畠鍐嶄笅杞戒竴閬嶅皝闈?
            await this.extractFlowLightColors(pair.full);
          }
          // 鈽呪槄 2026-10-15锛氱綉鏍艰儗鏅殑婧愶紙64脳64锛夊湪鍚屼竴娆′笅杞介噷鍑猴紝浜ょ粰鑳屾櫙灞?
          if (pair.mesh !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            this.publishMeshSource(pair.mesh);
          } else {
            this.releasePixelMapQuiet(pair.mesh);
          }
          this.releasePixelMapQuiet(pair.full);
        } catch (_err) {
          // 鍙栬壊澶辫触涓嶅奖鍝嶆挱鏀撅細鑳屾櫙璧板疄鏃舵ā绯婏紝涓嶅啀闇€瑕佽繖寮犻娓叉煋鍥?
        }
      }
      // 鈽呪槄鈽?2026-10-17锛堢敤鎴枫€屾湭鎾斁鐘舵€佺偣鍑绘墦寮€鎾斁鍣?鈫?鑳屾櫙鏄粦鐨勶紱鐐逛竴涓嬫挱鏀惧氨姝ｅ父銆嶏級
      //
      // ## 鏈哄埗锛堣浠ｇ爜鍗冲緱锛屼笉鏄寽锛?
      // ```
      //   鍦ㄧ嚎姝屾洸鐨勮儗鏅?*涓嶆槸鍙栬壊灞?*锛堥偅涓€灞傛槸鍐欐鐨勮繎榛?rgba(20,20,22,0.5)锛夛紝
      //   鐪熸鐨勮儗鏅槸**缃戞牸鍥?*锛坄publishMeshSource(pair.mesh)`锛夛紝鑰屽畠鍙湪
      //   `song.cover.length > 0` 鏃舵墠浼氳瑙ｅ嚭鏉ャ€?
      //   鏈挱鏀炬椂灏侀潰 URL 鍙兘杩樻病鍒版墜锛坢etadata 鏈?resolve锛夆噿 鏃㈡病缃戞牸涔熸病鍙栬壊
      //   鈬?灞忎笂灏辨槸閭ｅ眰杩戦粦搴?= 鐢ㄦ埛鐪嬪埌鐨?鑳屾櫙鏄粦鐨?銆?
      //   涓€鐐规挱鏀?鈬?灏侀潰 metadata 鍒颁綅 鈬?`onCurrentTrackForBackground` 鍐嶈窇涓€娆?鈬?姝ｅ父銆?
      // ```
      // ## 澶勭疆锛?*涓嶅彂鏄庝换浣曡瑙夊€?*锛屽彧璁╁畠鑷繁鏀舵暃锛?
      //   鑳屾櫙鍙璺?灏侀潰鏈夋病鏈夊埌鎵?鏈夊叧銆?*涓庢挱鏀剧姸鎬佹棤鍏?*
      //   鈬?灏侀潰杩樻病鍒版墜鏃讹紝**鏈夌晫鍦?*闅斾竴浼氬効鍐嶅彇涓€娆★紙鏈€澶?`BG_RETRY_MAX` 娆★紝
      //     姣忔閮借杩?`isAlive` + `jobSeq` 杩欎袱閬撻棬锛夈€?
      //   鈿狅笍 涓嶈兘鏃犻檺閲嶈瘯锛氬皝闈㈢‘瀹炰笉瀛樺湪锛堟湰鍦版棤鍥?鎺ュ彛姘镐箙澶辫触锛夋椂瑕佸仠鎵嬨€?
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
    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣?`decodeCover`锛夛細鍚屼竴娆¤В鐮?*椤烘墜鍐嶅嚭涓€寮?64脳64**锛?
    //   瀹冩墠鏄綉鏍艰儗鏅殑婧愶紙鏃犵晫 `SRC_EDGE = 64`锛夈€傚湪 64脳64 涓婂仛 `enhanceColors`
    //   + `boxBlurRgba(9, 3)`锛屽啀琚?`drawPixelMapMesh` **鏀惧ぇ閾烘弧鏁村睆** 鈬?
    //   瑙傛劅鏄?澶ц壊鍧楁祦鍔?锛屼笌"鍏ㄥ垎杈ㄧ巼鐓х墖 + 楂樻柉妯＄硦"鏄袱绉嶄笢瑗裤€?
    let meshPm: image.PixelMap | undefined = undefined;
    const imageSource = image.createImageSource(mediaData.buffer as ArrayBuffer);
    try {
      pixelMap = await imageSource.createPixelMap();
      // 鈽呪槄 2026-10-15锛氱綉鏍兼簮**鍗曠嫭涓€涓?try** 鈥斺€?瀹冨け璐?*涓嶈兘**鎶?鍙栬壊"閭ｆ潯璺竴璧?abort銆?
      //   鍘熸潵鏄窡涓昏В鐮佸悓涓€涓?`try`锛岃€岄偅涓?`catch` 浼?`return`锛堝苟鍐欓粯璁ゅ簳鑹诧級
      //   鈬?64脳64 閭ｄ竴姝ヤ竾涓€澶辫触锛岃繛 `state.imageColor`锛堣儗鏅彇鏍疯壊锛夐兘浼氫竴璧蜂涪銆?
      //   缃戞牸婧愭嬁涓嶅埌鍙細閫€鍥?瀹炴椂妯＄硦搴曞浘"锛屾槸**鍙檷绾?*鐨勶紝涓嶈鎷栧灝鍙栬壊銆?
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
            // 鍚屼竴娆″彇鑹茬殑缁撴灉椤哄甫绠楁祦鍏夎壊锛岀渷鎺夊啀寤轰竴涓?ColorPicker 鐨勫紑閿€
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

    // 鈽呪槄 2026-10-15锛氳繖閲屽師鏉ユ槸銆宍effectKit.blur(imageBlurRadius())` 棰勬覆鏌撲竴寮犳ā绯?PixelMap
    //   璧嬬粰 `imageLabel` 褰撹儗鏅簳鍥俱€嶃€傝儗鏅敼鎴愬疄鏃舵ā绯婂悗**杩欐潯璺凡鏁翠綋鍋滅敤** 鈥斺€?
    //   `imageLabel` 淇濇寔涓?`song.label`锛?*鍘熷灏侀潰 Resource**锛夛紝
    //   鐢?{@link originalCoverSource} 浜ょ粰鑳屾櫙灞?+ 缁勪欢绾?`.blur()` 鍘诲疄鏃舵ā绯娿€?
    //   瑙ｇ爜鍑烘潵鐨?PixelMap 鍙湇鍔′簬涓婇潰閭ｆ鍙栬壊锛岀敤瀹屽嵆寮冦€?
    //   鈿狅笍 椤哄甫瑙ｆ帀涓€涓殣鎮ｏ細浠ュ墠琚噴鏀剧殑姝ｆ槸"姝ｅ湪褰撳簳鍥炬覆鏌撶殑閭ｅ紶 PixelMap"
    //      锛堜笅娆℃崲姝?椤甸潰鍗歌浇鏃?`releaseBackgroundCoverIfPixelMap()` 浼氶噴鏀惧畠锛夛紝
    //      鐜板湪 `imageLabel` 鎭掍负 Resource 鈬?**鑳屾櫙灞備笉鍐嶆寔鏈変换浣曚細琚噴鏀剧殑浣嶅浘**銆?
    // 鈽呪槄 2026-10-15锛氭湰鍦?鍐呯疆灏侀潰鐨?64脳64 缃戞牸婧愪篃浜ゅ嚭鍘伙紙鑳屾櫙灞傜敤锛夛紝
    //    瀹冪殑鐢熷懡鍛ㄦ湡鏀圭敱 `meshSrc` 鎸佹湁锛堟崲姝屾椂閲婃斁涓婁竴寮狅紝瑙?`publishMeshSource`锛夈€?
    this.publishMeshSource(meshPm);
    this.releasePixelMapQuiet(pixelMap);
  }

  /**
   * 鎶婂皝闈綅鍥惧仛鎴?*缃戞牸鑳屾櫙鐨勬簮**骞朵氦缁欒儗鏅眰銆?
   *
   * 鐓ф惉鏃犵晫鐨勫彇鍥惧彛寰勶紙`鎾斁椤佃儗鏅?MeshGradient涓嶮eshSource瀹氱.md` 搂0 / 搂4锛夛細
   * ```
   * 64脳64 RGBA_8888锛堝彲缂栬緫锛?
   *   鈫?enhanceColors(u8)                              浣庡姣?/ 楂橀ケ鍜?/ 鍋忔殫锛堝綋鑳屾櫙涓嶆姠鍓嶆櫙锛?
   *   鈫?boxBlurRgba(u8, 64, 64, 9, 3)                  鐩掑紡妯＄硦锛屾棤 gamma
   *   鈫?鍥炲啓 PixelMap锛屼氦缁?MeshCoverBg锛堢綉鏍兼斁澶ч摵婊★級
   * ```
   * 鈿狅笍 `enhanceColors` 閲岀殑 `0.4` 涓?`脳5` 鏄?*閰嶅鐨勪竴瀵?*锛屽埆鍙敼涓€涓紙浼氳繃鏇濇垨鍙戠伆锛夈€?
   * 鈿狅笍 鏂版棫浜ゆ浛椤哄簭锛?*鍏堥噴鏀句笂涓€寮犮€佸啀璧嬪€煎苟 `++meshSrcVersion`** 鈥斺€?
   *    `MeshCoverBg` 鐨?`@Monitor` 鐩戝惉鐨勬槸**鐗堟湰鍙?*锛坄PixelMap` 鍘熷湴鏀瑰唴瀹逛笉浼氳Е鍙戝埛鏂帮級銆?
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
      // ⛔ 2026-10-17：**不写跨页面缓冲**（见 `adoptCachedMesh` 上面那段"当天撤回"）
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag, `mesh source build failed code=${e?.code}, message=${e?.message}`);
      this.releasePixelMapQuiet(pm);
      return;
    }
    const old: image.PixelMap | undefined = this.meshSrc;
    // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`MorphGuard` 鐨?閰嶈壊瀹夐潤绐楀彛"锛夛細褰㈠彉琛ラ棿璺戠潃鐨勬椂鍊?*涓嶆崲鑳屾櫙**
    //   锛堟崲鑳屾櫙 = 鏁村眰缃戞牸閲嶇敾锛岃鎰熷氨鏄?鍔ㄧ敾涓€旇儗鏅壊璺充竴涓?锛夈€傜獥鍙ｈ繃鍘诲悗鑷姩琛ヤ笂鏈€鍚庝竴娆°€?
    // 鈽呪槄鈽呪槄 2026-10-17锛?*绗竴寮犳簮缁濅笉璁歌杩欓亾绐楀彛鎺ㄨ繜** 鈥斺€?淇敤鎴峰疄娴嬨€岀偣鍑绘墦寮€娌℃湁鑳屾櫙銆嶏級
    //   `old === undefined` 琛ㄧず褰撳墠**鏍规湰娌℃湁缃戞牸婧?*锛堢偣鍑绘墦寮€閭ｄ竴鍒婚〉闈㈠垰鎸傝浇銆佹鍦ㄨВ鐮侊級銆?
    //   杩欑鏃跺€欏啀"绛夊畨闈欑獥鍙ｈ繃鍘?灏卞彧鍓╁厹搴曞彇鏍疯壊锛堝甫 alpha 鈬?鍗婇€忔槑锛夆噿 鐢ㄦ埛鐪嬪埌鐨勬槸
    //   娌℃湁鑳屾櫙銆傗噿 绗竴寮犳簮**绔嬪埢鎻愪氦**锛涘彧鏈?鏇挎崲宸叉湁婧?鎵嶈蛋绐楀彛锛堥偅鎵嶆槸"鍔ㄧ敾涓€旇烦鑹?鐨勫満鏅級銆?
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
   * 鎶婄綉鏍兼簮鐪熸鎸備笂鍘伙紙{@link publishMeshSource} 鐨?鎻愪氦"閭ｅ崐锛夈€?
   * @param pm 鏂扮殑缃戞牸婧愶紙鎵€鏈夋潈杞Щ缁欐湰椤碉級
   * @param old 琚浛鎹㈡帀鐨勬棫婧愶紙闈炵┖鍒欓噴鏀撅級
   */
  private commitMeshSource(pm: image.PixelMap, old: image.PixelMap | undefined): void {
    this.meshSrc = pm;
    this.meshSrcVersion = this.meshSrcVersion + 1;
    if (old !== undefined && old !== pm) {
      this.releasePixelMapQuiet(old);
    }
  }

  /**
   * 瀹夐潤绐楀彛杩囧幓鍚庤ˉ涓婃渶鍚庝竴娆＄綉鏍兼簮 鈥斺€?涓庢棤鐣岄偅涓噸璇?位锛坄wujie.pa:157930-157939`锛?
   * 璋?`syncReportChrome()` 鏄悓涓€浠朵簨锛?*绐楀彛涓€杩囧氨鎶婃渶鏂伴厤鑹茶ˉ涓婂幓**銆?
   * 娌℃湁寰呰ˉ鐨勬簮鏃舵槸绌烘搷浣溿€?
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
   * 涓€娆′笅杞借В鍑虹殑涓ゅ紶浣嶅浘锛氬叏灏哄锛堟祦鍏夊彇鑹茬敤锛? **64脳64 缃戞牸婧?*锛堣儗鏅敤锛夈€?
   *
   * 鈽?2026-10-15锛堢収鎼棤鐣岀殑鍙栧浘鍙ｅ緞锛夛細鎶?64脳64 閭ｄ竴寮犳斁鍦?*鍚屼竴娆¤В鐮?*閲屽嚭锛?
   *   涓嶅繀涓鸿儗鏅啀涓嬭浇涓€閬嶅皝闈€俙desiredSize` + `editable` 鏄繀椤荤殑 鈥斺€?
   *   缃戞牸婧愯鍦?64脳64 涓婂師鍦板仛 `enhanceColors` / `boxBlurRgba`锛堣 `publishMeshSource`锛夈€?
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
   * @returns 褰㈠彉瀹瑰櫒鐨?*楂樺害**锛氬舰鍙樻湡闂存槸"绔栫洿瑁佸壀绐楀彛"锛堝彧闇插嚭涓婇潰杩欎竴鏉★級锛?
   *          鍏朵綑鏃堕棿鎭掍负 `'100%'`锛? 涓庢病鏈夎繖濂楀姩鐢绘椂閫愬儚绱犱竴鑷达級銆?
   *
   * 鈿狅笍 闈欐鎬?*蹇呴』**缁?`'100%'` 鑰屼笉鏄换浣曠畻鍑烘潵鐨勬暟瀛楋細涔嬪墠鐢ㄥ疄娴嬬殑
   *    `contentHeightVp` 褰撻潤姝㈤珮搴︼紝鑰屼笂鎶ユ簮鎭板ソ鏄?*杩欏眰鑷繁琚鍓椂鐨勯珮搴?*锛?
   *    涓€娆′笂鎷変箣鍚庤繖涓€煎氨琚啓鎴?~360vp锛屼簬鏄瘡娆℃墦寮€鎾斁椤靛簳閮ㄩ兘缂轰竴鍧?
   *    锛堢敤鎴峰疄娴嬪弽棣堬級銆傜櫨鍒嗘瘮楂樺害鐢辩埗瀹瑰櫒锛堟弧灞忓涓伙級鍐冲畾锛屼笉鍙兘绠楅敊銆?
   */
  /**
   * @returns 褰㈠彉瀹瑰櫒鐨?*楂樺害**锛? 绔栫洿瑁佸壀绐楀彛锛夛細闈欐鎬?`'100%'`锛堢瓑浠蜂簬涓嶈鍓級銆?
   *
   * 涓嶅彉閲忥細瑁佸壀楂樺害 = 鍙楂樺害 / 缂╂斁 鈬?灞忎笂閭ｅ潡鍙鐭╁舰閲?*姝ｅソ**鏄暣椤碉紝
   * 鏃㈡病鏈夌暀鐧斤紙绗洓鐗?榛戠獥鍙ｏ紝涓棿涓€涓皬鎾斁椤?灏辨槸鐣欑櫧锛夛紝涔熸病鏈夎鍒囥€?
   * 鈿狅笍 闈欐鎬佸繀椤荤粰 `'100%'` 鑰屼笉鏄换浣曠畻鍑烘潵鐨勬暟瀛楋細鐧惧垎姣旂敱婊″睆瀹夸富鍐冲畾锛?
   *    涓嶄細琚煇娆″舰鍙樼殑涓棿鎬佸啓鑴忥紙"搴曢儴缂轰竴鍧?灏辨槸杩欎箞鏉ョ殑锛夈€?
   */
  private morphClipHeight(): Length {
    if (!this.expandState.morphClipping()) {
      // 鈿狅笍鈿狅笍 2026-10-17锛?*鐢ㄦ埛绗?1/2 鏉?琛ラ棿娌℃湁鍔ㄧ敾"鐨勫€欓€夋満鍒?*锛夛細
      //   杩欓噷鍘熸潵**鏃犳潯浠惰繑鍥?`'100%'`锛堝瓧绗︿覆锛?*锛岃€屽舰鍙樻湡杩斿洖鐨勬槸**鏁板瓧**
      //   鈬?`.height()` 杩欎釜灞炴€у湪**瀛楃涓?鈬?鏁板瓧涔嬮棿鍒囨崲绫诲瀷**锛?
      //     ArkUI **鏃犳硶鍦ㄤ袱绉嶇被鍨嬩箣闂存彃鍊?* 鈬?琛ラ棿涓€璧锋墜灏?*鐩存帴璺冲埌缁堢偣**
      //     锛堣鎰?= "灏侀潰鐩存帴灏卞埌缁撴潫浣嶇疆 / 鐩存帴涓嬪幓锛屾病鏈夊姩鐢?锛夈€?
      //   鈽?涓轰粈涔?鎵嬫寚璺熸墜閭ｆ潯鏄ソ鐨?锛氶偅鏉¤矾姣忎竴甯ч兘鍦ㄥ啓**鏁板瓧**锛屽叏绋嬪悓绫诲瀷 鉁?
      //   鈽?涓轰粈涔堣 return 鏁板瓧鑰屼笉鏄繚鐣?'100%'锛氶潤姝㈡€侀偅鏉℃敞閲婃媴蹇冪殑鏄?
      //     "**閲忓嚭鏉ョ殑鍐呭楂樺害**浼氳鏌愭褰㈠彉鍐欒剰"锛?搴曢儴缂轰竴鍧?锛夛紝
      //     鑰?*绐楀彛楂樺害**鏄?`reportWindow` 缁欑殑鏉冨▉鍊笺€佷笉鍙備笌褰㈠彉 鈬?娌℃湁閭ｄ釜椋庨櫓銆?
      //   鈿狅笍 瀹瑰櫒鐖剁骇鏄弧灞忓涓?鈬?鏁板€间笂 `winHVp` 灏辩瓑浜?`'100%'`銆?
      //     绐楀彛灏哄杩樻病涓婃姤鏃讹紙鏋佹棭鏈燂級鎵嶉€€鍥炲瓧绗︿覆 鈥斺€?閭ｆ槸鍞竴鐨勪竴娆＄被鍨嬪垏鎹紝
      //     涓斿彂鐢熷湪鏈〉鍒氭寕杞姐€佽繕娌℃湁浠讳綍琛ラ棿鐨勬椂鍊欍€?
      const h: number = this.expandState.windowHeightVp;
      return h > 0 ? h : '100%';
    }
    return Math.max(1, this.expandState.morphClipHeight);
  }

  /** Root: 鏁撮〉缂╂斁 + 绔栫洿瑁佸壀绐楀彛锛堝彲瑙嗙煩褰㈤噷姝ｅソ鏄暣椤碉級+ 妗ユ帴灏侀潰銆?*/
  build() {
    // 鈽?绗簲鐗堬細**鏁撮〉缂╂斁 + 绔栫洿瑁佸壀绐楀彛**銆?
    //   鍙鐭╁舰浠?*杩蜂綘鏉￠偅鏉¤兌鍥?*闀垮埌鏁村睆锛?鏁翠釜鎾斁鏉″欢浼搁摵寮€"锛夛紝
    //   涓嬭竟鍦ㄥ墠 25% 灏辫创鍒板涓诲簳杈癸紙鍚﹀垯搴曢儴閭ｅ嚑鍗?vp 鏁存鍔ㄧ敾閮界┖鐫€锛夛紱
    //   鍐呭灞傞珮搴?= 瑁佸壀楂樺害 = 鍙楂樺害 / 缂╂斁锛屾墍浠ュ彲瑙嗙煩褰㈤噷**姘歌繙濉弧鏁撮〉**锛?
    //   娌℃湁鐣欑櫧銆佷篃涓嶄細琚锛涘唴瀹瑰眰绛夊彲瑙嗙煩褰㈠楂樻瘮鎺ヨ繎椤甸潰鏃舵墠娴幇锛?
    //   閬垮厤涓鐪嬪埌涓€寮犺鍘嬫墎鐨勯〉闈紙閭ｆ鏄?浠庝腑闂村紑濮嬨€佺湅涓嶅嚭灞曞紑杩囩▼"鐨勬潵婧愶級銆?
    //   灏侀潰鐢辩画椋炲皝闈㈠崟鐙画椋烇紝**p = 1 鎵嶈惤浣?*锛?026-10-15 璧烽偅涓€妫掔敾鍦?*澹冲眰娴眰**
    //   `Index.MorphCoverClone()` 閲岋紱PC 澹冲眰浠嶅湪鏈〉鐨?`MorphCoverBridge`锛夈€?
    Stack({ alignContent: Alignment.TopStart }) {
      // 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣岋級锛?*鑳屾櫙鏁村眰鎼埌褰㈠彉瀹瑰櫒涔嬪**銆?
      //   鏃犵晫鐨?`MeshCoverBg` 鍦?`playerPane` **涔嬪**锛堜笌瀹冨悓绾э級鈬?瀹冧笉鍙備笌鎾斁椤电殑
      //   `scale / clip` 鈬?瑙傛劅鏄€?*鍐呭椋炰笂鏉ャ€佽儗鏅笉鍔?*銆嶃€?
      //   鎴戜滑鍘熸潵鎶婂畠鏀惧湪褰㈠彉瀹瑰櫒**鍐呴儴** 鈬?璺熺潃琚瓑姣斿帇鍒扮害 34% 鍐嶆斁澶э紝
      //   鐢ㄦ埛瀹炴祴灏辨槸銆?*鍍忓帇缂╃殑鑳屾櫙閾哄紑**銆嶃€?
      //   鈿狅笍 鎼嚭鏉ュ悗瀹?*涓嶅啀琚鍓獥鍙ｈ**锛堟暣灞忓彲瑙侊級锛屾墍浠ュ舰鍙樻湡鐨勫彲瑙佽寖鍥撮潬
      //     `backgroundRevealOpacity()`锛? 鏃犵晫 `pullBgIn`锛?鈫?.30 娣″叆锛夌 鈥斺€?涓庢棤鐣屽悓鍙ｅ緞銆?
      //   鈿狅笍 鍏滃簳灞傚幓鎺変簡 `borderRadius(this.expandState.morphRadius)`锛氭暣灞忓眰涓嶉渶瑕佸渾瑙掋€?
      // 鈽呪槄鈽?2026-10-16锛堜慨鐢ㄦ埛瀹炴祴銆?*鍏抽棴鎾斁鍣ㄥ彧鏈夊唴瀹逛細寮癸紝鑳屾櫙杩樻槸涓嶄細寮?*銆嶏級锛?
      //   鎶婅儗鏅暣灞傚杩涗竴涓?*涓庡唴瀹瑰悓涓€鏉℃尋鍘?*鐨勫鍣ㄩ噷銆?
      //
      // ## 鍘熸潵涓轰粈涔堜笉寮?
      //
      // 鍏虫挱鏀惧櫒鏃堕偅涓€璁?寮?鏄?`morphSquashY`锛堢珫鍚戝帇鎵侊級椹卞姩鐨勶紝瀹冩寕鍦?*璺敱澹?*
      //   锛坄PlaybackPageRoute.ets` 鐨?`.scale({y: morphSquashY})`锛変笌杩蜂綘鏉′笂銆?
      //   鑰屼笂涓€鎵规垜鎶婅儗鏅?*鎼嚭浜嗗舰鍙樺鍣?*銆佹寕鍒版湰椤垫牴 `Stack` 鈥斺€?鏍?`Stack` **涓嶅湪璺敱澹抽偅涓?
      //   scale 鐨勪綔鐢ㄥ煙閲?*锛堣矾鐢卞３鐨?scale 鍙帇瀹冭嚜宸遍偅妫靛瓙鏍戦噷鐨勪笢瑗匡級鈬?鍐呭寮广€佽儗鏅汗涓濅笉鍔ㄣ€?
      //
      // ## 鐜板湪鎬庝箞寮癸紙涓斿舰鐘舵纭級
      //
      // 澶栭潰濂椾竴灞傚鍣紝缁欏畠 `.height(H 脳 k)` + `.offset({y: 鈭扝(1鈭択)/2})` + `.scale({y: k})`锛?
      // 浣垮畠鐨?*瑙嗚鐭╁舰鎭掔瓑浜?`0 鈥?H路k虏`**銆佷笖**缁曠獥鍙ｄ腑蹇?*鍘嬫墎锛?
      // ```
      //   甯冨眬鐭╁舰 y 鈭?[鈭扝(1鈭択)/2 , 鈭扝(1鈭択)/2 + Hk]
      //   锛坄.offset` 鍙尓缁樺埗鐩掞紝`Alignment.TopStart` 涓嬫湭鍋忕Щ鏃跺簲涓?[0, Hk]
      //     鈬?鍑忓幓 H(1鈭択)/2 寰楀埌涓婇潰杩欎釜鍖洪棿锛?
      //   甯冨眬涓績 y_c = (鈭扝(1鈭択)/2 + (鈭扝(1鈭択)/2 + Hk))/2 = H(2k鈭?)/2 = Hk 鈭?H/2
      //   `.scale` 缁?*鑷韩涓績**缂╂斁 鈬?涓績涓嶅姩銆侀珮搴?脳k
      //   瑙嗚楂樺害 = Hk虏 銆佽瑙変腑蹇?= Hk 鈭?H/2
      //   鈬?瑙嗚 top = (Hk 鈭?H/2) 鈭?Hk虏/2 = H(2k 鈭?1 鈭?k虏)/2 = 鈭扝(1鈭択)虏/2
      //   鈬?瑙嗚 bottom = 瑙嗚 top + Hk虏 = H(2k 鈭?1 + k虏)/2 = H(1+k)虏/2 鈭?H
      // ```
      // **涓ょ閮戒弗鏍兼纭?*锛歚k = 1` 鈬?`[0, H]`锛? 鏁村睆锛岄€愬儚绱犵瓑浠凤級锛?
      // `k = SQUASH_Y` 鈬?瑙嗚鐭╁舰鎭板ソ鏄?缁曠獥鍙ｄ腑蹇冩妸婊″睆鍘嬪埌 k"鐨勭粨鏋滐細
      //   `(H 鈭?Hk)/2 = H(1鈭択)/2`鈥︹€?浠ｅ叆 `k` 鍖栫畝寰?`瑙嗚 top = H(1鈭択)虏/2`锛?
      //   鑰?缁曚腑蹇冨帇鍒?k"鐨?top 鏄?`H(1鈭択)/2` 鈬?涓よ€呭湪 `k = 1` 涓?`k 鈫?0` 澶勪竴鑷淬€?
      //   涓棿鎬佹渶澶氬樊 `H(1鈭択)(k)/2`銆?
      //   鈿狅笍 **杩欐槸鏈鍞竴涓€澶?杩戜技"**锛屽瀹炵櫥璁帮細闈欐鎬侊紙`k = 1`锛?*閫愬儚绱犱笉鍙?*鏄孩绾匡紝
      //     褰㈠彉涓棿鎬侀偅鍑?vp 鐨勫亸宸涓婃満鐪?鈥斺€?鑻ョ湡鏈轰笂"鍘嬬缉鏃惰儗鏅笂涓嬮湶杈?锛?
      //     灏辨妸 `.scale` 鎹㈡垚 `.scale({centerY: '50%'})` 涔嬪鐨勫彟涓€鏉¤矾锛堢敤涓ゅ眰瑁佸壀琛ュ伩锛夛紝
      //     閭ｆ椂鍐嶆敼锛?*涓嶈鐜板湪鍑寽鍔犲父鏁?*銆?
      // 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫鐨勫眰绾?*锛氳儗鏅洖鍒板舰鍙樺鍣?*鍐呴儴**锛?
      //
      // ## 鎴戜箣鍓嶉敊鍦ㄥ摢锛堣繛閿欎笁杞紝鐢ㄦ埛鍥涙瀹炴祴鎵撳洖锛?
      //
      // 鎴戜竴鐩翠互涓烘棤鐣岀殑 `MeshCoverBg` 鍦?`playerPane` **涔嬪**锛屼簬鏄妸瀹冩惉鍒版湰椤垫牴 `Stack`
      // 鈬?瀹?*浠庣涓€甯у氨鏁村睆**銆佽€屼笖**瑁佷笉鍒?*銆傜敤鎴峰疄娴嬨€?*鎾斁鍣ㄥ睍寮€杩樻槸鑳屾櫙鍏ㄥ睆**銆嶃€?
      //
      // 鏈疆鎶婃棤鐣岀殑**瀹瑰櫒鏍?*涓€璺閫氫簡锛坄wujie.pa`锛夛細
      // ```
      //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   鈫?鏍?Stack
      //   @36***# (191388)  Stack(TopStart)
      //                       .scale({x: expand.scaleValue, y: 鈥)      191400-191415
      //                       .translate({x: expand.translateX, 鈥)     191416-191431
      //                       .width(expand.clipWidth)                  191432-191441
      //                       .height(expand.clipHeight)                191442-191451
      //                       .borderRadius(expand.radius)              191452-191461
      //                       .clip(true)                               191462-191469
      //                       .id(PLAYER_ROOT_ID)                       191470-191478
      //                     鈹溾攢 If (191716 @36***#^4 鈫?@36***^4*#/^1)
      //                     鈹?   鈹斺攢 Column (191756 @36***#^5)
      //                     鈹?        鈹溾攢 If (191972 @36***#^7 鈫?@36***^7*#)  = **playerPane**锛圧ow锛?
      //                     鈹?        鈹斺攢 If 鈫?**MeshCoverBg**              192105 / 192191
      //                     鈹斺攢 鈥?
      // ```
      // 鈬?**`MeshCoverBg` 鍦?`PLAYER_ROOT_ID` 閭ｄ釜 Stack 鐨勯噷闈?*
      //   鈬?瀹?*璺熺潃瀹瑰櫒涓€璧?scale銆佷竴璧疯 clip**銆?
      //   杩欏氨鏄?灞曞紑鏃惰儗鏅笉浼氭暣灞忋€佽€屾槸浠庡皬绐楀彛閲岄暱鍑烘潵"鐨勬満鍒躲€?
      //
      // 鈿狅笍 鎴戜笂涓€鐗堥偅鍙?鏃犵晫鐨?MeshCoverBg 鍦?playerPane 涔嬪锛堜笌瀹冨悓绾э級"**鏄敊鐨?*锛?
      //   鏉ユ簮鏄彧鐪嬩簡鐗囨銆佹病鎶?`PLAYER_ROOT_ID` 閭ｄ釜 Stack 鐨?*闂悎鑼冨洿**璇诲嚭鏉ャ€?
      //   锛坄RzdMusic璁板繂.md` 搂56.50 閲屼篃鏄繖涔堝啓鐨?鈥斺€?涓€骞朵綔搴熴€傦級
      //
      // ## 鎼洖鍘讳箣鍚庡悓鏃惰В鍐崇殑涓や欢浜?
      //
      // 1. **灞曞紑涓嶅啀"鑳屾櫙鍏ㄥ睆"**锛氬舰鍙樻湡瀹瑰櫒鍙湁杩蜂綘鏉￠偅涔堝ぇ 鈬?鑳屾櫙涔熷彧鍦ㄩ偅涓€灏忓潡閲岋紝
      //    闅忓鍣ㄩ暱澶ц€岄摵寮€锛堣繖鎵嶆槸"椋炰笂鏉?鐨勮鎰燂級锛?
      // 2. **鍏抽棴鏃惰儗鏅窡鐫€涓€璧峰帇**锛氬鍣ㄦ湰鏉ュ氨鍦ㄨ矾鐢卞３閭ｆ潯 `morphSquashY` 鐨勪綔鐢ㄥ煙閲?
      //    锛坄PlaybackPageRoute.ets` 鐨?`.scale({y})` 鍘嬫暣涓挱鏀鹃〉锛夆噿 **涓嶅啀闇€瑕佹垜涓婁竴鐗?
      //    鍔犵殑閭ｄ釜 `.scale + height + offset` 琛ュ伩瀹瑰櫒**锛堝凡鍒犻櫎锛岃 `squashWrapHVp` 鐨勫垹闄よ褰曪級銆?
      Column() {
        // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫鐨勭涓夊眰褰㈢姸**锛氬唴灞?`Stack` 涔熷繀椤绘槸 `TopStart`锛?
        //   鏃犵晫閭ｉ噷鏄竴鍙?`Column锛堝 100% + winHVp + padTop/padBottom锛塦 鐩存帴鍧愬湪
        //   `Stack(TopStart)` 閲?鈥斺€?**娴佸紡瀛愯妭鐐?*銆佸浐瀹氱獥鍙ｉ珮銆傛垜浠繖灞傚師鏉ユ槸榛樿
        //   锛坄Center`锛? 瀹夸富 `.position(0,0)`锛屼笌涓婃父涓嶆槸鍚屼竴涓舰鐘躲€?
        //   鈬?鏀规垚 `TopStart`锛屽涓荤殑鍥哄畾灏哄鎵嶆湁鎰忎箟锛堟病鏈夊畠锛屽浐瀹氶珮鐨勫瀛愪細琚眳涓尓璧帮級銆?
        Stack({ alignContent: Alignment.TopStart }) {
          // 鈽?鑳屾櫙 = **鍗婇€忔槑 鈫?涓嶉€忔槑**锛氬簳鑹蹭笌鍙栬壊灞備竴璧疯蛋鍙嶇紪璇戠殑
          //   `pullBgIn = clamp(effT / 0.30)`锛? 鈫?0.30 娣″叆锛夈€?
          // 鈿狅笍 涓婇潰閭ｄ袱鍙ワ紙"搴曡壊涓庡彇鑹插眰涓€璧疯蛋 `pullBgIn`"锛夆槄 **宸蹭綔搴?*锛?
          //   鑷?2026-10-15 璧凤紝閭ｄ袱灞?*鏁村睆绾壊灞傚凡缁忔暣灞傚垹闄?*锛堜笅闈㈠氨鏄垹闄ゅ悗鐨勭幇鍦猴級銆?
          //
          // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*鏃犵晫娌℃湁绾壊鍨簳锛岀綉鏍兼湰韬氨鏄簳**銆?
          //   渚濇嵁 `_recover/logic-src/鏃犵晫vs娲鹃煶-宸紓鍒嗘瀽.md` L303-304锛?
          //     鈶?銆宍Column().backgroundColor('#1c1c1e').opacity(...)` 杩戦粦鍨簳灞傘€嶁啋 鏃犵晫渚?**鏃?*锛?
          //     鈶?銆宍Column().backgroundColor(state.imageColor)` 灏侀潰鍙栨牱鑹插眰銆嶁啋 **娌℃湁瀵瑰簲鐗?*銆?
          //   涓ゅ眰閮芥槸娲鹃煶鏃ц矾锛涘畠浠彔鍦ㄧ綉鏍间箣涓嬶紝鍙細璁?灞曞紑寮€濮嬮偅涓€鍒?澶氬嚭涓€鍧楃伆鏆楃僵瀛?
          //   锛堣 `backgroundRevealOpacity()` 鐨勬敞閲婏級銆?
          //
          //   鈽?閭ｅ眰"闈欐鎬佷笉閫忔槑搴?鐜板湪鎼埌浜?*璺敱澹?*涓婏紙杩欐槸鏃犵晫鐨勪綅缃細
          //     `wujie.pa:190867-190884` 鐨?`.backgroundColor(pullMode && effT()>=1 ?
          //     PULL_REST_BG : expand.overlayColor)`锛夛紝钀界偣瑙?
          //     `PlaybackPageRoute.ets` 鐨?`PlaybackPageRouteShell`锛?
          //       路 褰㈠彉鏈熼€忔槑 鈬?绐楀彛澶栭€忓嚭棣栭〉涓庤糠浣犳潯锛堝舰鍙樼殑鍓嶆彁锛夛紱
          //       路 闈欐鎬佷笉閫忔槑 鈬?鎾斁椤佃嚜宸辩殑搴曪紝椤哄甫鐩栦綇鐘舵€佹爮涓庡簳閮ㄩ偅涓ゆ潯
          //         锛堢敤鎴峰疄娴嬨€屽唴瀹规病寤朵几杩涚姸鎬佹爮銆嶃€屽簳閮ㄤ竴鏉＄┖鐧芥紡鍑哄悗闈㈠唴瀹广€嶏級銆?
          //     鈬?鎵€浠?*椤甸潰鍐呬笉鍐嶉渶瑕?*浠讳綍鏁村睆绾壊灞傦紝鍒犳帀瀹冧笉浼氬嚭鐜?鑳屾櫙绌轰竴鍧?銆?
          //
          //   鈿狅笍 涓嬮潰缃戞牸閭ｅ眰鐨?`backgroundRevealOpacity()` **淇濈暀**锛氬畠灏辨槸鏃犵晫鐨?`pullBgIn`
          //      锛堣捣鐐?0銆佽窡鐫€褰㈠彉杩涘害鍒?1锛夛紝闈欐鎬佹亽涓?1銆?

          // 鈿狅笍 绱ч殢鍏跺悗鐨勯偅娈?瀹炴椂妯＄硦搴曞浘"璇存硶鈽?**涔熷凡浣滃簾**锛氶偅寮?`Image(灏侀潰).blur(11)`
          //   宸叉暣灞傚垹闄?鈥斺€?瀹冨師鍏堝彧浣?缃戞牸婧愮己甯椂鐨勫厹搴?锛岃€屽厹搴曠幇鍦ㄦ敼鎴愪簡**绾彇鏍疯壊**
          //   锛堣涓嬮潰 `else` 鍒嗘敮锛夈€傚垹瀹冪殑鍘熷洜锛氬畠绛変簬**鍦ㄧ綉鏍间箣澶栧張鐢讳簡涓€寮犲皝闈?*锛?
          //   鎹㈡潵鐢ㄦ埛瀹炴祴鐨勩€岄偅涓袱寮犲皝闈㈠彧浼氬湪鍔ㄧ敾杩囩▼涓嚭鐜般€嶃€?
          //   鈬?`backdropBlurRadiusVp()` / `LIVE_BACKDROP_BLUR_VP` / `originalCoverSource()`
          //     鐜板湪**宸叉棤璋冪敤鑰?*锛堢暀鍦ㄦ枃浠堕噷鏄负浜嗕笉鐗靛姩 `isPixelMapCover` 閭ｆ潯绫诲瀷鍒嗘敮锛?
          //     瀹冧滑鐨勬暣浣撴竻鐞嗗綊鍏?鍒犳淳闊抽仐鐣?閭ｄ竴鍧楋紝瑙?`RzdMusic璁板繂.md` 搂56.6锛夈€?
          // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛氳儗鏅簳搴ф崲鎴?**缃戞牸褰㈠彉鑳屾櫙**锛坄MeshCoverBg`锛夈€?
          //   瑙勬牸锛歚_recover/logic-src/鎾斁椤佃儗鏅?MeshGradient涓嶮eshSource瀹氱.md`
          //   锛坄MESH_SUB=4`銆乣SRC_EDGE=64`銆乣boxBlur(9,3)`銆乣displaySync` 20fps銆侀椄闂?= `playing && active`锛夈€?
          //   瀹冭嚜甯?*寰勫悜鏆楄**锛坄scrim` 榛樿 true锛夛紝鎵€浠ヤ笅闈㈤偅灞傜嫭绔嬬殑 `radialGradient`
          //   鍦ㄧ綉鏍肩敓鏁堟椂蹇呴』鍏虫帀锛屽惁鍒欎細鍙犱袱浠芥殫瑙掋€?
          //   鈿狅笍 缃戞牸婧愯繕娌″缓濂斤紙鎹㈡瓕閭ｄ竴鐬級鏃?*閫€鍥炲疄鏃舵ā绯婇偅寮犲浘**锛屼笉浼氬嚭鐜?鑳屾櫙绌轰竴鍧?銆?
          // 娴佸厜鑳屾櫙锛堣缃」寮€鍏筹級锛氬繀椤诲湪鍐呭灞備箣鍓嶇粯鍒讹紝鍚﹀垯浼氱洊浣忓皝闈㈠拰姝岃瘝
          if (this.flowLightState.enabled) {
            this.FlowLightBackground()
          }

          // 鈽呪槄 2026-10-15锛?*寰勫悜鏆楄**锛坄鏃犵晫vs娲鹃煶-宸紓鍒嗘瀽.md` 搂3.4銆屽榻愬缓璁?路 鈶?鍙姞寰勫悜鏆楄銆嶏級銆?
          //   杩欎竴鏉℃槸閭ｄ唤鏂囨。缁欑殑**鏈€灏忚矾绾?*锛氱函澹版槑寮忋€侀浂鏂颁緷璧栥€佺珛鍒诲彲鎰?
          //   鈥斺€?涓?缃戞牸娴佸姩鑳屾櫙"锛坄MeshCoverBg`锛歚NodeContainer` + 鑷畾涔?`RenderNode.drawPixelMapMesh`
          //   + `displaySync` 閫愬抚椤剁偣锛岃 `鎾斁椤佃儗鏅?MeshGradient涓嶮eshSource瀹氱.md` 搂4锛?*鍒嗗紑**锛?
          //   閭ｅ鏈疆**涓嶅仛**锛岃繖閲屽彧鍙犱竴灞傚緞鍚戝帇鏆椼€?
          //
          //   閫愰」鏁板€奸兘鍙栬嚜鏂囨。锛坄[鍗曟簮]`锛屽嚭澶勫啓鏄庝互渚垮鏍革級锛?
          //   `鏃犵晫vs娲鹃煶-宸紓鍒嗘瀽.md` 搂3.4 缁勪欢鏍戞湯琛屼笌銆屸懀銆嶉偅涓€娈?鈥斺€?鏃犵晫
          //   `MeshCoverBg` 鐨?`Stack` **鏈€涓婇潰**灏辨槸杩欎竴灞?`Column().radialGradient(...)`锛?
          //   鑰屾垜浠殑 `Stack` 閲?鍐呭灞?锛坄buildControlStack`锛変篃鏄渶鍚庣敾鐨勩€?
          //   鈬?涓轰簡涓嶅悆鍒板唴瀹瑰眰锛岃繖閲屾斁鍦?*灏侀潰搴曞浘灞備箣鍚?* 鈥斺€?瀹冨湪鏍堥噷鐨勭粯鍒朵綅缃?
          //      涓庢棤鐣?鍘嬪湪鏁翠釜鑳屾櫙涔嬩笂銆佸唴瀹逛箣涓?鐨勮涔夌瓑浠凤紙鏃犵晫閭ｄ竴灞備箣涓嬫槸缃戞牸鑳屾櫙锛?
          //      鎴戜滑鐨勫唴瀹瑰眰鏄?*涓嶉€忔槑**鐨勭嫭绔嬪眰锛屼笉鍙楀畠褰卞搷锛夈€?
          //   路 `center: ['50%', '50%']` 鈥斺€?鍦嗗績鍦ㄦ涓紙鏂囨。鍚屽锛夛紱
          //   路 `radius: '70%'` 鈥斺€?鏂囨。鍚屽锛涘畼鏂?`ts-universal-attributes-gradient-color`
          //     锛?026-10-15 鍙栫殑鍘熸枃锛夛細銆屽緞鍚戞笎鍙樼殑鍗婂緞锛宯umber 绫诲瀷鏃跺崟浣嶄负 vp锛?
          //     璁剧疆鐨勫€间负 undefined 鏃剁郴缁熸寜缁勪欢灏哄鑷姩绠椼€嶁噿 杩欓噷缁?*鐧惧垎姣斿瓧绗︿覆**锛?
          //     闅忓鍣紙= 鏁村睆锛夎蛋锛屼笉鏄浐瀹?vp锛?
          //   路 `colors: [['#26000000', 0], ['#26000000', 0.45], ['#66000000', 1]]`
          //     鈥斺€?鏂囨。 搂3.4 甯搁噺琛細`SCRIM_CENTER = "#26000000"`锛埼扁増15%锛夈€?
          //     `SCRIM_EDGE = "#66000000"`锛埼?40%锛夛紝涓績鑹蹭竴鐩撮摵鍒板崐寰勭殑 45% 鎵嶅紑濮嬪帇鏆楋紱
          //     锛堝疄鐜伴噷鍐欐垚绛夊€肩殑鍗佸叚杩涘埗瀛楅潰閲?`0x26/0x66`锛屼笌鍚屾枃浠跺叾浣欐笎鍙?搴曡壊鍐欐硶涓€鑷淬€傦級
          //   路 鑹叉爣鐨勭浜屼釜鍏冪礌鏄?*姣斾緥 [0,1.0]**锛屼笉鏄?vp 鈥斺€?杩欎笁澶?0 / 0.45 / 1 鏈潵灏辨槸
          //     姣斾緥鍐欐硶锛堝悓 搂71.1 閭ｆ潯鍗曚綅鍧戯紱瀹樻柟鍘熸枃銆屽彇鍊艰寖鍥翠负 [0, 1.0]銆嶏級銆?
          //
          //   鈿狅笍 涓庢棤鐣岀殑涓€澶?*宸茬煡宸埆**锛氭棤鐣岄偅涓€灞傛槸**鎭掑紑**锛堝彧鐢?`scrim` 甯冨皵闂ㄦ帶锛夛紝
          //      鎴戜滑杩欓噷鍦?*褰㈠彉/杞満鏈熼棿鍏虫帀**锛堝鐢?`backgroundRevealOpacity()` 鍚屾鐨?
          //      `morphContainerActive()` 鍒ゆ嵁锛夆€斺€?鍚﹀垯褰㈠彉涓偅涓 scale+clip 鐨勫皬绐楀彛閲?
          //      浼氬涓€灞傚帇鏆楋紝涓?鍗婇€忔槑 鈫?涓嶉€忔槑"閭ｆ潯鏃㈡湁鍙ｅ緞鎵撴灦銆?
          //      瑙傛劅鏄惁瑕佹敼鎴愭亽寮€锛?*鍙兘涓婃満鐪?*锛堣鏈疆鎶ュ憡鐨?鍙兘涓婃満纭"娓呭崟锛夈€?
          // 鈽?缃戞牸鑳屾櫙鑷甫鏆楄 鈬?鍙湁**閫€鍥炴ā绯婂簳鍥?*閭ｆ潯璺墠闇€瑕佽繖涓€灞?
          //   锛堝惁鍒欎細鍙犱袱浠芥殫瑙掞紝涓績琚帇涓ら亶锛夈€?
          if (this.meshSrc === undefined) {
            Column()
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .radialGradient({
                center: ['50%', '50%'],
                radius: '70%',
                colors: [[0x26000000, 0.0], [0x26000000, 0.45], [0x66000000, 1.0]]
              })
              // 鈽呪槄鈽?2026-10-17锛堢敤鎴凤細銆屼笂鎷夋墦寮€鏈夎儗鏅紝**鐐瑰嚮灞曞紑 / 鍏抽棴 / 绯荤粺杩斿洖娌℃湁鑳屾櫙**銆嶏級
              //
              // ## 鏈哄埗锛堣浠ｇ爜 + 涓や釜璇绘暟鍗冲緱锛?
              // ```
              //   缃戞牸灞傛槸 `if (meshSrc === undefined) { 鍏滃簳 } else { MeshCoverBg(...) }`
              //   鐐瑰嚮灞曞紑 / 鍏抽棴鍙戠敓寰楁棭锛屾鏃?`song.cover` 杩樻病鍒版墜 鈬?meshSrc === undefined
              //   鈬?缃戞牸涓嶆寕杞斤紱鑰屽厹搴曡繖涓ゅ眰鐨勬殫瑙掑眰鍘熸潵鍐欑潃
              //        .opacity(morphContainerActive() ? 0 : 1)
              //     鈬?**褰㈠彉鏈熸濂芥妸瀹冨叧鎺?* 鈬?灞忎笂鍙墿杩戦粦鍙栨牱鑹?= "娌℃湁鑳屾櫙"
              //   涓婃媺鎵撳紑鎬绘槸鍙戠敓鍦ㄥ皝闈㈠姞杞藉畬涔嬪悗 鈬?缃戞牸鍦?鈬?姝ｅ父 鉁?
              // ```
              // ## 鏀规硶
              //   鍏滃簳灞傜殑鏆楄**涓嶈鍦ㄥ舰鍙樻湡娑堝け** 鈥斺€?瀹冩鍒绘槸**鍞竴鐨勮儗鏅?*銆?
              //   锛堢綉鏍煎瓨鍦ㄦ椂杩欐潯鍒嗘敮鏍规湰涓嶈繘锛屾墍浠ヤ笉浼氬拰缃戞牸鑷甫鐨勬殫瑙掑彔涓や唤銆傦級
              .opacity(1)
              .hitTestBehavior(HitTestMode.None)
          }

          // 灏侀潰缁娴眰锛氬す鍦ㄨ儗鏅笌鍐呭涔嬮棿锛屽垏椤甸偅 0.36 绉掗噷椤舵浛涓ゅ紶闈欐€佸皝闈?
          // No cover overlay: the lyric page has no matching image destination.

          // 鈽呪槄 2026-10-15 鐢ㄦ埛瀹炴祴涓ゆ潯锛岃繖涓€澶勬槸鍏卞悓鐨勬牴锛?
          //   銆?*灏忔瓕璇嶆槸浠庢垜灏侀潰鑳屽悗鍑虹幇**锛屼笉鏄粠涓嬫柟椋炰笂鏉ャ€?銆岃繘搴︽潯浼氳鎸′綇锛堝儚鏄皝闈㈡尅鐨勶級銆?
          //   鈬?缁灏侀潰鍘熸潵鐢诲湪**鏁撮〉鍐呭涔嬩笂**锛堟牴 Stack 鐨勬渶鍚庝竴涓瀛愶級锛屼簬鏄?
          //     路 浠庝笅鍗囪捣鐨?*灏忔瓕璇?*鍏堣瀹冩尅鐫€ 鈬?鐪嬭捣鏉ユ槸"浠庡皝闈㈣儗鍚庡啋鍑烘潵"锛?
          //     路 鍚屾牱浠庝笅鍗囪捣鐨?*鎺у埗鍖?*锛堣繘搴︽潯+鎸夐挳锛変篃浼氳瀹冨帇浣忋€?
          //   鐜板湪鎶婂畠鎸埌**鍐呭灞備箣鍓?*锛氬舰鍙樻湡闂存挱鏀鹃〉鑷繁閭ｅ紶鐪熷皝闈㈡槸闅愯棌鐨?
          //   锛坄realCoverVisible()` 涓哄亣 鈬?灏侀潰妲戒綅鏄┖鐨勩€侀€忔槑鐨勶級锛屾墍浠ョ画椋炲皝闈㈢収鏍烽€忓緱鍑烘潵銆?
          //   浣嶇疆涓庡ぇ灏忎竴妯′竴鏍凤紙瀹冩湰鏉ュ氨鏄寜"杩蜂綘鏉″皝闈?鈫?鎾斁椤靛皝闈?鎻掑€肩敾鐨勶級锛?
          //   鑰?*鎵€鏈夊崌涓婃潵鐨勫唴瀹归兘鍦ㄥ畠涔嬩笂** 鈬?涓ょ粍椋炲叆閮借兘琚湅瑙侊紝涔熶笉鍐嶄簰鐩搁伄鎸?鈥斺€?
          //   杩欐槸缁撴瀯涓婄殑淇濊瘉锛屼笌"閲忓緱鍑嗕笉鍑?鏃犲叧銆?
          //   鈿狅笍 涓嶈鍐嶆尓鍥炲幓锛埪?7 閭ｆ"鐪嬩笉瑙?鏄垜鍚屼竴杞姞鐨?`barOpacity` 鎶婅糠浣犳潯鐪熻韩涔熻棌浜嗛€犳垚鐨勶紝
          //      閭ｄ釜闂ㄥ凡缁忓垹闄わ紱鏈妭杩欑増娌℃湁瀹冿級銆?
          // 鈽呪槄 2026-10-15锛堝３灞傛诞灞傞偅涓€杞級锛?*鎾斁椤典笉鍐嶇敾杩欏紶缁灏侀潰** 鈥斺€?
          //   `hostsMorphOverlay()` 涓虹湡锛堟墜鏈?骞虫澘褰㈡€侊級鏃讹紝閭ｄ竴妫掑凡缁?*鎼埌澹冲眰娴眰**
          //   锛坄products/default/src/main/ets/pages/Index.ets` 鐨?`MorphCoverClone()`锛夛紝
          //   骞朵笖鐢?*瀹冭嚜宸辩殑杩涘害** `morphOverlayP` 椹卞姩锛?60ms锛?
          //   `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)`锛夈€?
          //   鐣欏湪鎾斁椤甸噷鐢荤殑閭ｄ竴鐗堟湁涓€涓粨鏋勬€ф瘺鐥咃細瀹冨湪杩欎釜**琚?scale+translate 鍙樻崲杩囥€?
          //   杩樺甫 `.clip()` 涓庡姩鎬?`.height(morphClipHeight())` 鐨勫鍣?*閲岋紝鐭╁舰鍗存槸绐楀彛鍧愭爣
          //   鈬?鍙湁 p=1锛堟亽绛夊彉鎹級鎵嶄弗鏍兼纭紝涓€斿彧鑳?杩戜技"锛屽巻鍙蹭笂鍙嶅鍑?鍓嶅崐娈电湅涓嶈 /
          //   琚埆鐨勪笢瑗挎尅浣?銆傛诞灞傞偅浠戒笉鍦ㄨ繖涓鍣ㄩ噷锛屾病鏈夎繖涓棶棰樸€?
          //   鈿狅笍 鍒ゆ柇鏉′欢涓嶆槸"p 鍒版病鍒?锛岃€屾槸**瀹夸富鏈夋病鏈夋帴绠?*锛堣 `hostsMorphOverlay()`锛夛細
          //     PC 澹冲眰锛坄products/pc`锛夎繕娌℃帴杩欎唤娴眰锛岄偅杈?*缁х画鐢辨挱鏀鹃〉鑷繁鐢?*
          //     鈥斺€?鍚﹀垯浼氬嚭鐜?涓よ竟閮戒笉鐢?鐨?*鏃犲皝闈?*绌烘。銆?
          //   鈿狅笍 鎾斁椤佃嚜宸遍偅寮?*鐪熷皝闈?*鍦ㄥ舰鍙樻湡闂翠粛鐒朵笉鐢伙紙`realCoverVisible()` 閭ｆ妸闂ㄦ病鍔級锛?
          //     鍚﹀垯浼氬嚭鐜颁袱涓皝闈紱涓よ€呬弗鏍间簰琛ャ€?
          if (this.expandState.morphBridging() && !this.expandState.hostsMorphOverlay()) {
            this.MorphCoverBridge()
          }

          // 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫鐨勫眰绾?*锛氳儗鏅湪褰㈠彉瀹瑰櫒**鍐呴儴**锛?
          //
          // ## 鎴戜箣鍓嶉敊鍦ㄥ摢锛堣繛閿欎笁杞紝鐢ㄦ埛鍥涙瀹炴祴鎵撳洖銆屾挱鏀惧櫒灞曞紑杩樻槸鑳屾櫙鍏ㄥ睆銆嶏級
          //
          // 鎴戜竴鐩翠互涓烘棤鐣岀殑 `MeshCoverBg` 鍦?`playerPane` **涔嬪**锛屼簬鏄妸瀹冩惉鍒版湰椤垫牴
          // `Stack` 鈬?瀹?*浠庣涓€甯у氨鏁村睆**銆佽€屼笖**瑁佷笉鍒?*銆?
          //
          // 鏈疆鎶婃棤鐣岀殑**瀹瑰櫒鏍?*涓€璺閫氫簡锛坄wujie.pa`锛夛細
          // ```
          //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   鈫?鏍?Stack
          //   @36***# (191388)  Stack(TopStart)
          //                       .scale({x: expand.scaleValue, y: 鈥)      191400-191415
          //                       .translate({x: expand.translateX, 鈥)     191416-191431
          //                       .width(expand.clipWidth)                  191432-191441
          //                       .height(expand.clipHeight)                191442-191451
          //                       .borderRadius(expand.radius)              191452-191461
          //                       .clip(true)                               191462-191469
          //                       .id(PLAYER_ROOT_ID)                       191470-191478
          //                     鈹溾攢 If (191716 @36***#^4)
          //                     鈹?   鈹斺攢 Column (191756 @36***#^5)  鈫?婊＄獥瀹?+ winHVp + padTop/padBottom
          //                     鈹?        鈹溾攢 If (191972 @36***#^7 鈫?@36***^7*#) = **playerPane**锛圧ow锛?
          //                     鈹?        鈹斺攢 If 鈫?**MeshCoverBg**             192105 / 192191
          //                     鈹斺攢 鈥?
          // ```
          // 鈬?**`MeshCoverBg` 鍦?`PLAYER_ROOT_ID` 閭ｄ釜 Stack 鐨勯噷闈?* 鈬?瀹?*璺熺潃瀹瑰櫒涓€璧?
          //   `scale`銆佷竴璧疯 `clip`**銆傝繖鎵嶆槸"灞曞紑鏃惰儗鏅笉浼氭暣灞忋€佽€屾槸浠庡皬绐楀彛閲岄暱鍑烘潵"鐨勬満鍒躲€?
          //
          // 鈿狅笍 鎴戞鍓嶉偅鍙?鏃犵晫鐨?`MeshCoverBg` 鍦?`playerPane` 涔嬪锛堜笌瀹冨悓绾э級"**鏄敊鐨?* 鈥斺€?
          //   鏉ユ簮鏄彧鐪嬩簡鐗囨銆佹病鎶?`PLAYER_ROOT_ID` 閭ｄ釜 Stack 鐨?*闂悎鑼冨洿**璇诲嚭鏉ャ€?
          //   锛堝巻鍙叉敞閲婇噷鍑¤繖涔堝啓鐨勪竴骞朵綔搴熴€傦級
          //
          // ## 鏀惧湪瀹瑰櫒閲屽悓鏃惰В鍐充袱浠朵簨
          //
          // 1. **灞曞紑涓嶅啀"鑳屾櫙鍏ㄥ睆"**锛氬舰鍙樻湡瀹瑰櫒鍙湁杩蜂綘鏉￠偅涔堝ぇ 鈬?鑳屾櫙涔熷彧鍦ㄩ偅涓€灏忓潡閲岋紝
          //    闅忓鍣ㄩ暱澶ц€岄摵寮€锛?
          // 2. **鍏抽棴鏃惰儗鏅窡鐫€涓€璧峰帇**锛氬鍣ㄦ湰鏉ュ氨鍦ㄨ矾鐢卞３閭ｆ潯 `morphSquashY` 鐨勪綔鐢ㄥ煙閲?
          //    鈬?涓嶅啀闇€瑕佹垜涓婁竴鐗堝姞鐨?`.scale + height + offset` 琛ュ伩瀹瑰櫒锛堝凡鍒狅級銆?
          //
          // 鈿狅笍 浣嶇疆锛氬鍣?`Column` 鐨?*绗竴涓瀛?*锛堣儗鏅湪涓嬨€佸唴瀹瑰湪涓婏級锛?
          //   `.position({x:0,y:0})` 瑕嗙洊鏁翠釜瀹瑰櫒 鈬?涓嶅弬涓庣旱鍚戞帓甯冿紙鍚﹀垯浼氭妸鍐呭鎸や笅鍘伙級銆?
          Column() {
            // 鈽呪槄鈽呪槄 2026-10-17锛?*缃戞牸灞傚父椹伙紝涓嶅啀鐢?`if` 鍦ㄥ舰鍙樹腑閫旀寕杞?* 鈥斺€?
            //   淇敤鎴峰疄娴嬨€岀偣鍑绘墦寮€锛氬姩鐢昏繃绋嬫病鑳屾櫙銆佸姩鐢荤粨鏉熷氨鏈夈€嶏級
            //
            // ## 涓轰粈涔?鏉′欢鎸傝浇"浼氭紡鎺夋暣娈靛姩鐢?
            //   鐐瑰嚮鎵撳紑鏃堕〉闈㈠垰鎸傝浇銆乣meshSrc` 杩樻槸 undefined 鈬?`if` 璧板厹搴曞垎鏀紱
            //   绛夌綉鏍兼簮鍒版墜锛堝嚑鍗亊鍑犵櫨 ms 鍚庯級`if` 鎵嶇炕鐪?鈬?**`MeshCoverBg` 鍦ㄥ舰鍙樿繘琛屽埌涓€鍗婃椂
            //   鎵嶇涓€娆℃寕杞?*銆傝€?`NodeContainer` + `RenderNode` 鍦ㄧ鍏堟琚?`animateTo`
            //   琛ラ棿锛坄height`/`clip` 姣忓抚鍦ㄥ彉锛夌殑鏈熼棿棣栨鎸傝浇鏃讹紝鑷粯鍐呭瑕佺瓑琛ラ棿鏀跺熬銆?
            //   鏁存５鏍戝己鍒烽偅涓€甯ф墠琚悎鎴愬嚭鏉ワ紙澶栭儴澶嶆牳 `gemini-4-argon-thinking` 绗?1 鏉★細
            //   "鍚?`NodeContainer` 鐨勮妭鐐瑰湪琛ラ棿鏈熼棿涓嶈鍔ㄦ€佹敼 `height`/閲嶅害 `clip`锛?
            //    鍚﹀垯鍙兘鏁村潡涓嶅弬涓庡悎鎴?锛夆噿 灞忎笂鏁存鍔ㄧ敾閮芥槸绌虹殑銆?
            //   鈬?鐜板湪**甯搁┗**锛氫粠椤甸潰鎸傝浇閭ｄ竴鍒诲氨瀛樺湪锛堝舰鍙樺紑濮嬩箣鍓嶏級锛屽彧鏈?`src` 鍦ㄥ彉銆?
            //     鏄鹃殣/娣″叆浠嶇劧鍙敱 `backgroundRevealOpacity()` 绠°€?
            //   鈿狅笍 鍏滃簳鐨?鍙栨牱鑹?涓嶅啀鏄竴灞傚厔寮熻妭鐐癸紙`Column` 閲屼袱涓?100% 瀛╁瓙浼氱旱鍚戞帓寮€锛夛紝
            //     瀹冪殑鑱岃矗宸茬粡鐢?*瀹夸富鑷繁鐨?`.backgroundColor`**锛堜笉閫忔槑搴曞骇锛夋壙鎷呫€?
            MeshCoverBg({
              src: this.meshSrc,
              srcVersion: this.meshSrcVersion,
              // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`seed: seedOfParts($$.title, $$.artist)`锛夛細
              //   鍙栦笉鍒板皝闈㈡椂缁勪欢鍐呯敤杩欎釜绉嶅瓙閫犲厹搴曠綉鏍硷紙`fillFallback` 鍥涜 HSL 娓愬彉锛夈€?
              seed: this.meshSeed(),
              playing: this.state.isPlay,
              active: this.state.isShowPlay,
              // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫鍘熸枃**锛歚entryFade: !pullMode || effT() >= 1`锛?
              //   `wujie.pa:192183-192320` 鐨勫疄鍙傞€愬瓧灏辨槸杩欎釜琛ㄨ揪寮忋€傝涔夛細
              //     路 涓嶆槸涓嬫媺閭ｆ潯锛堢偣鍑绘墦寮€ / 鍏抽棴 / 绯荤粺杩斿洖锛夆噿 **涓嶆贰鍏?*锛堢珛鍒诲彲瑙侊級锛?
              //     路 涓嬫媺閭ｆ潯锛氬彧鏈夊舰鍙樿蛋瀹岋紙`effT() >= 1`锛夋墠涓嶅啀娣″叆銆?
              entryFade: !this.expandState.pullMode || this.expandState.effT() >= 1,
              // 鉀?2026-10-17锛?*閫€鍥?0 = 鐢诲竷璺熺潃瀹夸富瀹炴祴灏哄** 鈥斺€?鐢ㄦ埛瀹炴祴鐨勫洖褰掞級
              //   涓婁竴鐗堜紶 `windowHeightVp` 鎯虫妸鐢诲竷閽変綇锛堟不"鍘嬫墎鈫掓媺浼?锛夛紝
              //   缁撴灉鐢ㄦ埛鎶ャ€?*鐐瑰嚮鎾斁鍔ㄧ敾杩囩▼杩樻槸娌¤儗鏅?*锛屽姩鐢荤粨鏉熷悗鎵嶆湁銆嶏細
              //   `fixedHVp > 0` 鏃?`RenderNode.frame` **姣斿畠鎵€鍦ㄧ殑閭ｄ釜鐩掑瓙楂?*锛?
              //   鑰屽舰鍙樻湡閭ｄ釜鐩掑瓙灏辨槸瑁佸壀绐楀彛锛堝嚑鍗亊鍑犵櫨 vp锛夆噿 瓒呭嚭鐖剁洅鐨勭粯鍒惰鏁村潡鍓旈櫎
              //   鈬?**褰㈠彉鏈熶粈涔堥兘涓嶇敾**锛涜惤浣嶅悗涓よ€呯浉绛?鈬?鍙堟甯搞€?
              //   鈬?鍙鎬т紭鍏堬細浼?0锛岃鐢诲竷姘歌繙绛変簬瀹夸富鐩掑瓙锛? 涓€鐩磋兘鐢诲嚭鏉ワ級銆?
              //   鈿狅笍 浠ｄ环鏄舰鍙樻湡缃戞牸浼氶殢瑁佸壀绐楀彛涓€璧峰帇/鎷夛紙鐢ㄦ埛鏃╁墠鎶辨€ㄨ繃鐨勯偅鏉★級銆?
              //     瑕佸悓鏃舵弧瓒?鐢诲緱鍑?+"涓嶅帇鎵?锛屽緱鎹㈠埆鐨勬満鍒讹紙渚嬪鎶婅儗鏅Щ鍒拌挋鐗堜箣澶栫敱澹冲眰瑁佸壀锛夛紝
              //     涓嶈鍐嶇敤"鐢诲竷姣旂洅瀛愬ぇ"杩欑鍐欐硶銆?
              fixedHVp: 0
            })
              .id(PlaybackPage.MESH_BG_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .opacity(this.backgroundRevealOpacity())
              .hitTestBehavior(HitTestMode.None)
              .onAreaChange((): void => {
                this.logBgLayer();
              })
          }
          // 鈽呪槄鈽呪槄 2026-10-17锛?*鑳屾櫙瀹夸富涓€寰?100%锛?鍥哄畾灏哄"鍙粰缃戞牸鐢诲竷锛屼笉缁欏竷灞€**锛?
          //
          // ## 涓婁竴鐗堥敊鍦ㄥ摢锛堢敤鎴峰疄娴嬶細**鑳屾櫙瀹屽叏涓嶈浜?*锛岄潤姝㈡€佷篃娌℃湁锛?
          //   涓婁竴鐗堟妸**瀹夸富**鐨勯珮搴︿粠 `'100%'` 鏀规垚鍥哄畾 `windowHeightVp`銆傚涓绘槸
          //   `.position({x:0,y:0})` 鐨勭粷瀵瑰畾浣嶅瓙鑺傜偣锛岃€岀埗瀹瑰櫒楂?= `morphClipHeight()`锛?
          //   涓€涓瘮瑁佸壀绐楀彛澶х殑鍥哄畾灏哄鐩掑瓙鍙備笌鐖剁害鏉?瑁佸壀閾惧悗锛屾暣灞傚氨**涓嶅啀琚粯鍒?*
          //   锛圙emini-4-Argon 澶嶆牳鍚岀粨璁猴細Stack 瀛愯妭鐐硅秴鍑鸿 `.clip(true)` 鐨勭埗鐩掓椂锛?
          //   娓叉煋绠＄嚎浼氭暣鍧楀墧闄わ紱瑙﹀彂杩囦竴娆′箣鍚?*闈欐鎬佷篃涓嶄細鑷繁鍥炴潵**锛夈€?
          //   鉀?**涓嶈**鍐嶆妸瀹夸富鐨勫昂瀵告崲鎴愬浐瀹氭暟 鈥斺€?瀹冨繀椤荤敱鐖剁骇 100% 鎾戝紑銆?
          //
          // ## 鐪熸瑕佷慨鐨勬槸"缃戞牸姣忔閲嶆帓"锛? 鍘嬫墎鈫掓媺浼革級锛岄偅浠朵簨鍙戠敓鍦?*鐢诲竷**涓?
          //   `NodeContainer.onAreaChange 鈫?controller.resize(w,h) 鈫?field.update(w,h)`
          //   鈬?璋佺殑鐩掑瓙鍦ㄥ彉锛岀綉鏍煎氨鎸夎皝鐨勬瘮渚嬮噸寤洪《鐐瑰苟閲嶉噰鏍枫€?
          //   鈿狅笍 **2026-10-17 鐜扮姸锛歚fixedHVp` 宸查€€鍥?0**锛堢敾甯冭窡鐫€瀹夸富鐩掑瓙锛夈€?
          //     鏇捐瘯杩囨妸瀹冮拤鎴?`windowHeightVp` 娌?鍘嬫墎"锛屼絾**鐢诲竷姣旂洅瀛愬ぇ 鈬?鏁村潡鍓旈櫎**
          //     鈬?褰㈠彉鏈熶粈涔堥兘涓嶇敾锛堢敤鎴峰疄娴嬩袱娆★級銆傚彲瑙佹€т紭鍏堬紝鍘嬫墎閭ｆ潯鍏堢暀鐫€銆?
          //     瑕佸悓鏃舵弧瓒筹紝寰楁妸鑳屾櫙**绉诲嚭褰㈠彉瀹瑰櫒**锛堝閮ㄥ鏍稿缓璁殑鏂规 A锛氳儗鏅眰涓庡鍣ㄥ悓绾с€?
          //     鑷繁鐢?`clip` + `scale/translate` 璺熼殢锛夛紝涓嶆槸璋冨昂瀵歌兘瑙ｅ喅鐨勩€?
          .width(StyleConstants.FULL_WIDTH)
          // 鈽呪槄鈽呪槄鈽?2026-10-17锛?*鐓ф惉鏃犵晫锛氬涓荤殑灏哄鏄竴涓浐瀹氭暟 `winHVp`锛屼笖鏄祦寮忓瓙鑺傜偣**锛?
          //
          // 鏃犵晫鐨勫鍣ㄦ爲锛坄wujie.pa:191756`锛岄€愯鏍歌繃锛夛細
          // ```
          //   Stack(TopStart) .scale .translate .width('100%') .height(clipHeight) .clip(true)
          //     鈹斺攢 Column  瀹?100% + **height(winHVp 鍥哄畾鏁?** + padTop/padBottom     鈫?娴佸紡瀛╁瓙锛屾棤 .position
          //          鈹溾攢 playerPane
          //          鈹斺攢 MeshCoverBg
          // ```
          // 鈬?涓や釜瑕佺偣锛堟垜浠箣鍓嶄袱鏉￠兘閿欙級锛?
          //   鈶?**鑳屾櫙瀹夸富鐨勯珮搴︽槸鍥哄畾绐楀彛楂?*锛屼笉璺?`clipHeight` 璧?鈬?`NodeContainer` 鐨?
          //      `onAreaChange` **鍙Е鍙戜竴娆?*锛宍RenderNode.frame` 灏哄**鎭掑畾** 鈬?鑷粯鍐呭涓嶄細
          //      姣忓抚琚噸寤?澶辨晥銆傛垜浠師鏉ュ啓 `'100%'` = 璺熺潃瑁佸壀绐楀彛姣忓抚鍙?鈬?姣忓抚 `resize()`
          //      鈬?缃戞牸姣忓抚閲嶆柊閲囨牱/閲嶅缓锛屽舰鍙樻湡骞茶剢浠€涔堥兘涓嶅墿 鈬?鐢ㄦ埛鐪嬪埌鐨?鍏ㄧ▼榛?銆?
          //   鈶?瀹冩槸**娴佸紡瀛愯妭鐐?*锛堟病鏈?`.position`锛夛紝闈犵埗 `Stack(TopStart)` 璐村乏涓婅銆?
          //      鎴戜滑鍘熸潵鐢?`.position(0,0)` 鐨勭粷瀵瑰畾浣?鈬?閰嶅悎"瓒呭嚭琚?clip 鐨勭埗鐩?浼氳鏁村潡鍓旈櫎
          //      锛埪?59 閭ｆ"鑳屾櫙瀹屽叏涓嶈"灏辨槸杩欐潯锛夈€?
          //   鈿狅笍 闈欐鎬侊細瀹瑰櫒楂?= 绐楀彛楂?鈬?鍥哄畾楂樹笌 `'100%'` **瀹屽叏绛変环** 鈬?閫愬儚绱犱笉鍙樸€?
          .height(this.expandState.windowHeightVp)
          // 鈽呪槄鈽呪槄 2026-10-17锛?*涓嶉€忔槑搴曞骇** 鈥斺€?缃戞牸涓囦竴娌＄敾鍑烘潵锛屼篃涓嶄細闇插嚭棣栭〉/杩蜂綘鏉★級
          //   鐢?`defaultImageBgColor`锛坄rgba(32,32,32,1)`锛屾湰椤靛師鏈夌殑"杩樻病鏈夊彇鑹叉椂鐨勫簳鑹?锛夈€?
          //   鈿狅笍 涓嶈兘鍔犳垚"绗簩涓瓙鑺傜偣"鈥斺€?瀹夸富鏄鍣紝涓や釜 100% 瀛╁瓙浼氱旱鍚戞帓寮€銆?
          .backgroundColor(PlaybackPage.defaultImageBgColor)
          .hitTestBehavior(HitTestMode.None)
          // 鉀?2026-10-17锛?*涓嶄箻鍙嶇缉鏀?* 鈥斺€?渚濇嵁鏄敤鎴风粰鐨勬棤鐣屼腑娈垫埅鍥撅級
          //   鏃犵晫涓鎴浘鏄剧ず锛?*缃戞牸鏄摵婊℃暣寮犲崱鐗囩殑**锛堟牸瀛愰殢鍗＄墖涓€璧疯鍘?灞曞紑锛?
          //   鈬?鑳屾櫙璺熺潃瀹瑰櫒缂╂斁鏈韩鏄鐨勶紝鍙嶇缉鏀句細璁╁睆涓婂彧鍓╀竴寮犳弧灏哄缃戞牸鐨?*涓€鍧楀垏鐗?*銆?
          //   锛堝巻鍙查偅涓よ稛鍙嶇缉鏀鹃兘宸叉挙鍥烇紝`bgInverseScale()` 涔熷凡鍒犻櫎銆傦級
          // 鈽呪槄鈽?2026-10-16锛?*鑳屾櫙灞傝嚜璇?* 鈥斺€?瑙?`diagBgBox` 鐨勬敞閲婏級锛?
          //   閲忕殑鏄?*鏈眰锛堣儗鏅涓伙級**鐨勫竷灞€鐭╁舰銆傜敤鎴锋姤"鏈夎儗鏅絾楂樺害鐗逛綆"鏃讹細
          //     路 `bgH` 寰堝皬鑰?`clipH` 涔熷皬 鈬?姝ｅ父锛堝姩鐢讳腑娈碉紝瀹瑰櫒灏卞彧鏈夐偅涔堝ぇ锛?
          //     路 `bgH` 寰堝皬鑰?`clipH` 涓嶅皬 鈬?**鐧惧垎姣旈摼鏂簡**锛堣儗鏅病閾烘弧瀹瑰櫒锛?
          //     路 `bgH` 姝ｅ父 鈬?闂鍦?*涓嶉€忔槑搴?*锛堢湅 `bg`锛夋垨**缁樺埗**锛堜笉鏄竷灞€锛?
          .onAreaChange((_oldArea: Area, area: Area): void => {
            const w: number = areaLengthToVp(area.width);
            const h: number = areaLengthToVp(area.height);
            this.diagBgBox = `${w.toFixed(0)}x${h.toFixed(0)}`;
          })

          // 鈽?鍐呭灞傦細灏哄鎭掍负 100%锛? 瑁佸壀绐楀彛 = 鍙鐭╁舰 / 缂╂斁锛夛紝鎵€浠ユ案杩滃～婊″彲瑙嗙煩褰?
          Column() {        Column() {
              this.buildControlStack()
            }
            // 鈽?鑰佽矾寰勶紙鍑犱綍娌￠噺鍒版椂鐨勫厹搴曪級锛氬唴瀹瑰眰璐寸潃搴曡竟锛岄珮搴︿粠"璐村簳涓€鏉?闀垮埌 100%
            .height(this.sheetHeightPercent())
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.End)
          .clip(true)
          // 鈿狅笍 杩欓噷**涓嶅啀**缁欐暣灞傚姞閫忔槑搴?搴曡壊锛氶€忔槑搴﹀凡鎸夊弽缂栬瘧鎷嗘垚涓夊眰绐楀彛
          //   锛堣儗鏅?`pullBgIn` / 椤舵爮 `pullChromeOpacity` / 搴曟爮 `pullBottomIn`锛夛紝
          //   搴曡壊鐢卞舰鍙樺鍣ㄩ噷閭ｄ釜鍙栬壊灞傝礋璐ｏ紝鍚﹀垯闈欐鎬佷細灏戜竴灞傞鑹层€?
          // 鈿狅笍 涓婃媺鎵撳紑**涓嶅湪杩欓噷鍋?*锛氬畠蹇呴』鎸傚湪澹冲眰锛坧roducts锛夈€?
          //    鎾斁椤靛湪 `isShowPlay=false` 鏃惰繕娌℃寕杞斤紝椤甸潰鏀朵笉鍒版墜鎸囦簨浠躲€?
          //    鑱岃矗鍒掑垎锛?*涓婃媺=澹冲眰/杩蜂綘鏉★紙鈫?morphP 0鈫?锛夛紝涓嬫媺鏀惰捣=鏈〉锛堚啋 morphP 1鈫?锛?*銆?
          //
          // 鈿狅笍 杩欓噷**浠€涔堥兘涓嶄笂鎶?*锛堟棦涓嶄笂鎶ュ昂瀵革紝涔熶笉鍐嶄笂鎶ュ師鐐癸級銆?
          //    鏈眰灏辨槸鎵嬫満渚х殑 `MORPH_HOST_ID`锛岃€屽畠鐨勯珮搴︽槸**瑁佸壀绐楀彛楂樺害**
          //    锛堝舰鍙樻湡闂?~60vp 鈫?婊″睆锛夛紝`globalPosition` 涔熻窡鐫€ translate 璧?鈥斺€?
          //    鎷垮畠褰?閾烘弧鐩爣"灏辨槸绗簲娆¤嚜鍣紙涓€鍧楅粦搴?+ 鎾斁椤靛睍涓嶅紑锛夛紝
          //    鎷垮畠褰?鍧愭爣鍘熺偣"灏辨槸璁╁師鐐硅拷鐫€鑷繁鐨勪腑闂存€佽窇锛堣捣鐐?鍏嬮殕灞傛暣浣撻敊浣嶏級銆?
          //    **鍧愭爣鍙ｅ緞鍏ㄩ摼缁熶竴绐楀彛鍧愭爣**锛堥噺娴嬫湰鏉ュ氨鏄獥鍙ｅ潗鏍囷紝鍏嬮殕灞傜殑
          //    `.position()` 涔熻惤鍦ㄦ弧灞?Stack 涓婏紝鍚屽彛寰勶級锛屾墍浠ユ牴鏈笉闇€瑕佸師鐐规崲绠椼€?
          //    褰㈠彉灏哄鐨勫敮涓€鏉冨▉鏄３灞傛寜 `windowSize` 涓婃姤鐨?`reportWindow`銆?
          .onAppear(() => {
            this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            this.isAlive = true;
            this.getImageColor();
            this.applyPlaybackWindowChromeImmediately();
            // 椤甸潰棣栨鍑虹幇鏃跺悓姝ヤ竴娆″紑鍏崇姸鎬侊紙璁剧疆椤靛彲鑳藉垰鏀硅繃锛?
            this.applyFlowLightColors();
            // 鈽呪槄鈽?2026-10-16锛?*鍒犳帀 `playbackSwiperIndex = 0`锛涚储寮曞綊"鎵撳紑鎰忓浘"绠?*锛?
            //
            // ## 鍘熸潵閭ｅ彞涓轰粈涔堟湁瀹?
            //   瀹冩槸**鑺傜偣绾у洖璋?*锛堟湰 `Column` 鐨?`.onAppear`锛屽垎鏀噸寤轰篃浼氳窇锛夐噷鐨勫啓鍏ワ紝
            //   鑰?`playbackSwiperIndex` 鏄?Swiper 褰撳墠椤?鐨勫敮涓€鐘舵€侊紝涓旂幇鍦?
            //   **缁戝埌浜?`Swiper.index()`**锛堣 `Swiper()` 涓婃柟閭ｆ闀挎敞閲婏級銆?
            //   涓よ€呮斁涓€璧峰氨鏄繖涓舰鐘讹細
            // ```
            //   鐢ㄦ埛浠庡簳閮ㄧ姸鎬佹爮"姝ｅ湪鎾斁"杩涙挱鏀惧櫒 鈫?鎵撳紑鎰忓浘鎶婄储寮曠疆 0锛堣璁″姝わ紝瑙?
            //     PlaybackIntentShell锛夆啋 鐢ㄦ埛婊戝埌姝岃瘝椤碉紙绱㈠紩 = 1锛宍lyricMorphT` = 1锛?
            //   鏌愪釜鑺傜偣閲嶅缓 鈬?鏈?`onAppear` 鍙堣窇涓€娆?鈬?绱㈠紩琚啓鍥?0
            //   鈬?`Swiper` 璺冲洖灏侀潰椤?+ `lyricMorphT` 涓庢柊椤典笉涓€鑷?
            //   鈬?瑙傛劅锛?*鍦ㄦ瓕璇嶉〉锛屽皝闈㈠嵈涓嶅彉灏?*锛堢敤鎴?2026-10-16 鐪熸満鎴浘瀹炴祴锛?
            // ```
            //   鈿狅笍 鑰屼笖杩欎釜"澶嶄綅"瀵?*鍐峰惎鍔ㄩ偅鏉¤矾鏈潵灏卞浣?*锛氭墦寮€鎾斁鍣ㄦ椂
            //      `PlaybackIntentShell` / `ProductViewModel` 閭ｄ竴鏉″凡缁忔妸绱㈠紩缃?0 浜?
            //      锛堝畠鏄?鎵撳紑鎰忓浘"鐨勪竴閮ㄥ垎锛夈€傝妭鐐圭骇鍥炶皟鍐嶆姠涓€娆″彧浼氭妸鐢ㄦ埛**褰撳墠椤?*鎵撴帀銆?
            //
            // ## 鐜板湪鐨勫垎宸ワ紙鍗曚竴鐪熸簮锛屽埆鍐嶆贩鍚堬級
            //   路 **鎵撳紑鎾斁鍣?* 鈬?鐢辨墦寮€鎰忓浘缃?`playbackSwiperIndex = 0`锛堟湰椤典笉鍙備笌锛夛紱
            //   路 **鐢ㄦ埛婊戝姩**   鈬?`.onChange` 鍐欑储寮?+ `.onAnimationStart` 椹卞姩 `lyricMorphT`锛?
            //   路 **鑺傜偣鍑虹幇**   鈬?鍙悓姝?鏈〉鑷繁鐨勮瑙夌姸鎬?锛?*涓嶇鐢ㄦ埛鍦ㄥ摢涓€椤?*銆?
            //
            // ## 涓?灏侀潰缁"閭ｄ竴瀵圭殑鍏崇郴锛堣繖閲岀殑澶嶄綅**蹇呴』鐣?*锛?
            //   涓嬮潰涓ゅ彞鏄?*鏈〉鑷繁鐨勬淳鐢熺姸鎬?*锛屼笉鏄?鐢ㄦ埛鍦ㄥ摢涓€椤?锛?
            //   `lyricMorphT` / `lyricMorphVisible` 鎻忚堪鐨勬槸"灏侀潰椋炶鍔ㄧ敾杩涜鍒板摢"锛?
            //   鑺傜偣閲嶅缓鍚庡繀椤诲洖鍒伴潤姝㈡€侊紙鍚﹀垯浼氬仠鍦ㄤ竴涓ˉ闂翠腑闂存€侊級銆?
            //   鈿狅笍 浣?*绱㈠紩涓?1 鏃朵笉鑳界洸鐩妸 `lyricMorphT` 褰?0** 鈥斺€?閭ｄ細璁?鍦ㄦ瓕璇嶉〉"杩欎竴甯?
            //      鐨勫皝闈㈠彉鍥炲ぇ灏侀潰锛堟鏄湰娆¤淇殑鐜拌薄锛夈€傗噿 鎸夌储寮曞喅瀹氶潤姝㈡€侊細
            // ```ts
            //   this.lyricMorphT = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
            // ```
            //   鍗?闈欐鎬?= 褰撳墠椤靛搴旂殑绔偣"锛岃繖涔熸槸 `lyricMorphT` 涓や釜绋冲畾鍊肩殑瀹氫箟銆?
            //   鈽?2026-10-16锛堢浜岀増锛夛細杩欓噷鍘熸潵鏄竴鍙ュ唴鑱斾笁鍏冦€傜幇鍦ㄦ敹鏁涜繘
            //     `syncLyricMorphToPage()` 鈥斺€?鍥犱负**鍚屼竴涓榻愬姩浣滃湪鎸傝浇鏃朵篃瑕佸仛涓€娆?*
            //     锛坄aboutToAppear`锛夛紝涓ゅ蹇呴』鍚屼竴鍙ｅ緞锛堣閭ｄ釜鏂规硶鐨勬敞閲婏級銆?
            this.syncLyricMorphToPage('appear');
            // 鈿狅笍 杩欎竴鍙?*蹇呴』鐣欏湪澶栭潰**锛歚syncLyricMorphToPage()` 鍦?宸茬粡瀵归綈"鏃朵細**鏃╅€€**锛?
            //   鑰?鑺傜偣閲嶅缓鍚庝笉璁稿仠鍦ㄨˉ闂翠腑闂存€?杩欐潯瑕佹眰姣忔 `onAppear` 閮借婊¤冻銆?
            this.lyricMorphVisible = false;
            // 鎺у埗鍖猴細杩涙潵鍏堝敜鍑猴紝3 绉掓病鍔ㄨ嚜鍔ㄦ敹璧?
            this.chromeCollapsed = false;
            this.touchChrome();
            // 鈽?2026-10-15 璇婃柇锛氳惤浣嶄箣鍚庡啀閲忎竴娆″洓涓潡鐨勭獥鍙ｇ煩褰紙瑙?`logLayoutBoxes()`锛夈€?
            //   480ms 鍙?灞曞紑琛ラ棿锛堟渶闀?560ms 鐨勬诞灞傞偅鏉?+ 20ms 鏀跺熬锛夊熀鏈蛋瀹?鐨勯噺绾э紱
            //   鎺掓煡鍏抽敭瀛?`RzdBoxes`銆傗殸锔?鍙锛屼笉褰卞搷浠讳綍鐘舵€併€?
            setTimeout((): void => {
              if (this.isAlive) {
                this.logLayoutBoxes();
                // 鈽?鐩爣 鈶?鐨?S1 姝ヨ嚜璇侊紙鎺掓煡鍏抽敭瀛?`RzdSizeTier`锛夛細
                //   鏍稿 `sizeScaleOf` / `topPageSideOf` 鍦?*鎵嬫満妗?*涓婃槸鍚︽伆濂界瓑浜庢垜浠?
                //   宸茬粡鍦ㄧ敤鐨勫浐瀹氬€硷紙`sizeK = 1` / `side = 16`锛夆€斺€?鏈熸湜 `fixedOk=true`銆?
                this.expandState.logSizeTier(this.breakpointEnv.widthBreakpoint);
                // 鈽?鐩爣 鈶?鐨?S2 姝ヨ嚜璇侊紙鎺掓煡鍏抽敭瀛?`RzdWideCols`锛夛細
                //   鎶婂灞?/ 闈㈡澘涓ゆ。鐨?*鍗犳瘮涓庝袱鏍忓搴?*鎵撳嚭鏉ワ紙鎵嬫満涓婂畠浠笉鍙備笌甯冨眬锛?
                //   鍙槸鎶婃暟绠楀嚭鏉ュ鏌ワ級銆傞棿璺濓紙gutter/space锛?*涓嶅湪鍏朵腑** 鈥斺€?瑙?S2 鐨勬敞閲娿€?
                this.expandState.logWideColumns(this.breakpointEnv.widthBreakpoint, this.usePanelLayout(),
                  this.getUIContext());
              }
            }, 480);
            // 鈿狅笍 涓婃媺鎵撳紑鏃惰繘搴﹀凡缁忓湪鎷栧姩涓蛋浜嗕竴閮ㄥ垎锛岃繖閲屼笉鑳介噸缃紱
            //    鐐瑰嚮/璧锋挱鎰忓浘鎵撳紑鏃惰繘搴︽槸 0锛堣 aboutToAppear锛夈€?
            this.collapseProgress = 0;
            // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*褰㈠彉浼氳瘽褰掑３灞傛椂锛屾湰椤典笉璧蜂换浣曞睍寮€琛ラ棿**銆?
            //   鏃犵晫閭ｈ竟鎾斁椤佃嚜宸变笉鎾睍寮€ 鈥斺€?瀹冨彧鏄澹冲眰鐨?`ExpandAnimation`
            //   鎸?`scale/translate/clip` 鎺ㄧ潃鍙橈紝琛ラ棿鍦ㄥ３灞傦紙`settlePullOpen`锛夈€?
            //   鏈〉姝ゅ埢鍙仛涓€浠朵簨锛?*鎶婄粯鍒堕棬鎵撳紑**锛堝嚑浣曞凡缁忔槸澹冲眰鍘嬪ソ鐨勮捣鐐癸級銆?
            //   鈿狅笍 杩欓噷**涓嶈**鍐嶆棤鏉′欢璋?`playExpandIntro()`锛氬畠浼氳蛋 `tryStartMorphIntro()`锛?
            //      鑰岄偅鏉¤矾瑕?閲忓埌缁堢偣閿氱偣"鎵嶈偗璧疯ˉ闂淬€侀噺涓嶅埌灏遍€€鍖栨垚
            //      `playLegacyExpandIntro()`锛堣创搴曚竴鏉￠暱涓婃潵 = 娲鹃煶鏃у姩鐢伙級
            //      鈬?鍚屼竴涓叆鍙ｆ湁鏃舵槸鏂板姩鐢汇€佹湁鏃舵槸鏃у姩鐢伙紝姝ｆ槸銆屾柊鏃ф墦鏋躲€嶇殑褰㈢姸銆?
            //
            // 鈽呪槄鈽?2026-10-16锛?*鐐瑰嚮鎵撳紑娌℃湁灏侀潰/鑳屾櫙鍔ㄧ敾鐨勭湡鏍瑰洜**锛夛細
            //   鍒ゆ嵁鍘熸潵鍙湁 `morphContainerActive()`锛?*鐐瑰嚮璺緞鍦ㄦ寕杞介偅涓€鍒诲畠杩樻槸鍋?*锛?
            //   ```
            //     鐐瑰嚮锛氬３灞?beginOpenMorphOnClick 鈫?pullOpenBegin
            //            鈫?prepareMorphEntry 鍙戠幇"鎾斁椤佃繕娌℃寕杞姐€佸皝闈㈤噺涓嶅埌"
            //            鈫?璧?!ready 鍒嗘敮锛歮orphStage = ENTERING銆乵orphDrive = FINGER
            //            鈫?浣嗭紙鍚屼笂锛?*morphUsable = false銆乵orphP = 0** 鈬?morphContainerActive() 涓哄亣
            //            鈫?pushPlayerRoute 鈫?鏈〉 onAppear 鈬?鎺夎繘 else 鍒嗘敮 鈬?**鎾淳闊虫棫鍔ㄧ敾**锛?
            //     涓婃媺锛氬３灞?onPullOpenStart 鈫?pullOpenBegin锛?*鍦ㄩ〉闈㈡寕杞戒箣鍓?*灏?
            //            morphBeginEntering()锛堥偅鏃惰糠浣犳潯閲忓緱鍒帮級鈬?鎸傝浇鏃?stage = ENTERING 鈬?璧板鍒嗘敮
            //   ```
            //   鈬?琛ヤ竴鏉″垽鎹細**澹冲眰宸茬粡涓鸿繖涓€杞捣杩囧舰鍙樹細璇?*锛坄morphSessionStarted`
            //     鐢?`prepareMorphEntry` 绗竴姝ョ疆浣嶏紝涓夋潯鍏ュ彛閮戒細缁忚繃瀹冿級銆?
            //     瀹冩垚绔?鈬?杩欎竴椤电殑绗竴甯у氨璇?涓嶇敾"锛堢瓑澹冲眰鎶婂嚑浣曞帇鍒拌捣鐐癸級锛?
            //     鑰屼笉鏄嚜宸卞紑濮嬫挱閭ｅ `collapseProgress` 鏃у姩鐢汇€?
            if (this.expandState.morphContainerActive() || this.expandState.morphSessionStarted) {
              this.diagAppearBranch = 'morph';
              this.introPaintReady = true;
              this.expandIntroRunning = false;
              // 鈽呪槄 2026-10-16锛堢偣鍑昏矾寰勭殑**鍑犱綍琛ラ噺**锛夛細
              //   鐐瑰嚮鎵撳紑鏃?`pullOpenBegin` 鏄湪"鎾斁椤佃繕娌℃寕杞?閭ｄ竴鍒昏窇鐨?鈬?瀹冨緢鍙兘
              //   鎷夸笉鍒扮粓鐐归敋鐐癸紙鎾斁椤靛皝闈㈣妭鐐硅繕涓嶅瓨鍦級鈬?`morphUsable = false`銆?
              //   澹冲眰閭ｈ竟鏈?12脳32ms 鐨勮ˉ閲忕獥鍙ｏ紙`schedulePullAnchorRemeasure`锛夛紝
              //   浣嗛偅鏄?*澹冲眰**鐨勮妭濂忥紱鏈〉鎸傝浇閭ｄ竴鍒绘槸"灏侀潰鑺傜偣**鍒氬垰瀛樺湪**"鐨?*鏈€鏃?*鏃舵満锛?
              //   鍦ㄨ繖閲岃ˉ閲忎竴娆★紝姣旂瓑澹冲眰涓嬩竴鎷嶏紙鏈€澶?32ms 涔嬪悗锛夋洿鍑嗐€?
              //   鈿狅笍 涓夋璧帮紝缂轰竴姝ュ氨浼?琛ラ噺鎴愬姛浣嗙浉浣嶈繕鍋滃湪鏃ф€?锛?
              //     鈶?`prepareMorphEntry` 鈥斺€?閲忓嚑浣?+ `morphInitParams` + 鍘嬪埌璧风偣锛?
              //     鈶?`morphBeginEntering` 宸茬粡鐢卞畠鍐呴儴璋冭繃锛坮eady 鏃讹級锛?
              //     鈶?琛ラ噺鎴愬姛鍚?*蹇呴』**鎶婃诞灞傞偅涓€妫掔殑琛ラ棿涔熻捣璧锋潵锛堝惁鍒欏皝闈粛鐒朵笉椋烇級銆?
              setTimeout((): void => {
                if (!this.isAlive || this.isClosing) {
                  return;
                }
                this.diagRemeasureTries = this.diagRemeasureTries + 1;
                // 鈽呪槄鈽?2026-10-16锛?*鍚屼竴褰㈢姸鐨勭 3 澶?*锛氬張鏄?绠楀嚭鏉ヤ簡"褰撴垚"閲忓埌浜?锛夛細
                //   杩欏彞鍘熸潵鏄?`if (morphUsable) { return; }` 鈥斺€?鑰?`morphUsable` 鏄?
                //   `morphInitParams()` 鐨勭粨璁猴細**鍙 barW/boxW 閲忓埌浜嗗畠灏变负鐪?*锛?
                //   **鏍规湰涓嶇缁堢偣閿氱偣鏈夋病鏈?*銆備簬鏄偣鍑绘墦寮€杩欐潯璺笂锛?
                // ```
                //   pullOpenBegin 鈫?morphInitParams() 鎴愬姛锛堣糠浣犳潯鏈夊嚑浣曪級鈬?morphUsable = true
                //   鎸傝浇 鈫?杩欓噷璇诲埌 morphUsable === true 鈬?**鐩存帴 return**
                //        鈬?鏈〉杩欐"鏈€鏃╃殑琛ラ噺鏃舵満"琚櫧鐧戒涪鎺?
                // ```
                //   鑰岀粓鐐归敋鐐瑰湪**鏈〉鎸傝浇涔嬪墠**鏄粷瀵归噺涓嶅埌鐨勶紙鑺傜偣杩樹笉瀛樺湪锛?
                //   鈬?灏卞彧鍓╁３灞傞偅鏉?12脳32ms 鍏滃簳锛屼袱鏉″苟琛岀殑琛ラ噺**涓€鏉￠兘娌¤窇**銆?
                //   鈬?鍒ゆ嵁鎹㈡垚 {@link PlayerExpandState.morphGeomReadyNow}锛? 鏃犵晫 `pullGeomReady`锛?
                //     鍙湁鐪熺殑閲忓埌缁堢偣閭ｄ竴鎷嶆墠涓虹湡锛夈€?*鏈〉鎸傝浇杩欎竴鍒绘鏄?缁堢偣鑺傜偣鍒氬瓨鍦?鐨勬渶鏃╂椂鏈?*銆?
                //   鈿狅笍 涓?`morphUsable` 鐨勫垎宸ヨ閭ｄ釜瀛楁鐨勬敞閲婏紝鍒啀娣风敤銆?
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
              // 鍏滃簳锛氬舰鍙樻病璧锋潵锛堝嚑浣曟病閲忛綈鐨勯€€鍖栬矾寰勶級浠嶆棫璧拌€侀偅濂楋紝鍒椤甸潰鎵撲笉寮€銆?
              //
              // 鈽呪槄鈽?2026-10-16锛?*淇敤鎴峰疄娴嬨€屼笅鎷夊叧闂悗锛屽姩鐢荤粨鏉熶簡绐佺劧鍙堟斁涓€閬嶅睍寮€銆?*锛?
              //
              // ## 杩欐潯鍒嗘敮涓轰粈涔堜細鍦?鍏抽棴"鏃惰璧板埌
              // 鏈?`.onAppear()` 鏄?*鑺傜偣绾?*鍥炶皟 鈥斺€?瀹冧細鍦?*鍒嗘敮閲嶅缓**鏃朵篃瑙﹀彂锛?
              // 涓嶅彧鏄?椤甸潰琚墦寮€"閭ｄ竴娆°€傝€屽叧闂摼璺噷 `morphReset()` 浼氭妸
              // `morphSessionStarted` 娓呭洖 false锛坄morphStage` 鍙樻垚 NONE锛夆噿
              // 涓婇潰閭ｄ釜 `if` 鐨勪袱涓垽鎹?*鍚屾椂鍙樺亣** 鈬?钀藉埌杩欓噷 鈬?**閲嶆斁涓€閬嶅睍寮€鍔ㄧ敾**銆?
              //
              // ## 鍒ゆ嵁锛堜笁閬擄紝**绗笁鏉℃槸璺ㄥ疄渚嬬殑**锛?
              //   鈶?`isClosing` 鐢卞叧闂摼璺疆鐪燂紙`closeFullScreenPlayback()` 棣栭儴锛夛紱
              //   鈶?`morphStage === LANDING` 鈥斺€?`morphLand()` **鍙湪鍏抽棴璺緞**琚皟
              //      锛堝叏宸ョ▼娓呯偣锛歚PlaybackPage` 涓ゅ + `Index:1088`锛夆噿 鏄?宸蹭氦杩樿糠浣犳潯"鐨勭浉浣嶏紱
              //   鈶?鈽?`lastCloseAtMs` 鏃堕棿绐?鈥斺€?**璺ㄥ疄渚?*鍏变韩锛堣閭ｄ釜闈欐€佸瓧娈电殑娉ㄩ噴锛夈€?
              //      鈿狅笍 鈶犫憽 閮芥槸**瀹炰緥灞€閮?*鐨勶細鏂板疄渚嬬殑 `aboutToAppear` 浼氭妸 `isClosing`
              //         **鏃犳潯浠舵竻鍥?false**锛宍morphReset()` 鍙堟妸 `morphStage` 褰?NONE
              //         鈬?鍏抽棴浣欐尝钀藉湪鏂板疄渚嬩笂鏃?*涓ゆ潯鍏ㄧ瀻** 鈬?蹇呴』闈?鈶€?
              //      鈿狅笍 鈶?鐨勫啓鐐?*鍙湁** `closeFullScreenPlayback()` 棣栭儴涓€澶勶紙涓ゅ鎴愬锛?
              //         涓婁竴杞氨鏄紡浜嗛偅涓啓鐐广€侀棬鎭掑亣 鈬?鐧芥敼涓€杞級銆?
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
                // 鈽?闄?涓嶆挱鍔ㄧ敾"涔嬪杩樺繀椤?*鎶婂嚑浣曡惤瀹?*锛?
                //   鍚﹀垯瀹瑰櫒鍙兘鍋滃湪琚腑鏂殑涓棿 scale锛堢敤鎴锋姤鐨?鑳屾櫙鍙墿涓€鏉?鍚屾簮锛夈€?
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
            // 鈽呪槄 2026-10-16锛?*鍏堝彇"鍗歌浇閭ｄ竴鍒?鐨?isAlive 蹇収**銆?
            //   涓嬮潰閭ｈ浼氭妸 `isAlive` 鍚屾缃?false锛岃€屾湰鍥炶皟閲岀殑鍒ゆ嵁鏄?*寤舵椂涓€鎷?*璺戠殑 鈥斺€?
            //   鐩存帴璇诲瓧娈电殑璇濇案杩滆鍒?false 鈬?鍒ゆ嵁閲?`!isAlive` 閭ｆ潯鎭掔湡
            //   鈬?寤舵椂閭ｉ亾闂ㄧ瓑浜庢病鍔狅紙杩欐鏄笂涓€鐗?`morphUsable` 閭ｉ亾闂ㄧ殑鍚岀被閿欒锛?
            //     **鍒ゆ嵁璇诲埌鐨勬槸"琚嚜宸辨敼杩囦箣鍚?鐨勫€?*锛夈€?
            const wasAlive: boolean = this.isAlive;
            this.isAlive = false;
            PlaybackPage.ev('DIS', `wasAlive=${wasAlive ? 1 : 0} show=${this.state.isShowPlay ? 1 : 0}`);
            // 鈽呪槄鈽?2026-10-16锛?*鍒犳帀杩欓噷閭ｅ彞鍚屾鐨?`state.isShowPlay = false`**锛夛細
            //   鍘熸潵杩欓噷鍐欑潃 `this.state.isShowPlay = false;`銆傚畠鏄竴涓?*鑺傜偣绾?*鍥炶皟閲岀殑鍐欏叆锛?
            //   鑰?`isShowPlay` 鏄?*澹冲眰璺敱鐨勯┍鍔ㄦ簮**锛坄Index.@Monitor('appState.isShowPlay')`
            //   鈫?`popPlayerRoute()`锛夈€備袱鑰呮惌鍦ㄤ竴璧风殑鍚庢灉鏄繖涓舰鐘讹細
            // ```
            //   鐐瑰嚮鎵撳紑锛氬３灞傛妸 isShowPlay 缃?true 鈬?鎺ㄥ叆鎾斁椤佃矾鐢?
            //   鍚屼竴甯?涓嬩竴甯э紝**鏃ф挱鏀鹃〉瀹炰緥**锛堟垨鍒嗘敮閲嶅缓鐨勯偅涓妭鐐癸級瑙﹀彂 onDisAppear
            //   鈬?瀹冩妸 isShowPlay 鍐欏洖 false
            //   鈬?澹冲眰绔嬪埢 popPlayerRoute() 鈬?**鍒氭墦寮€鐨勬挱鏀鹃〉琚脊鎺?/ 鍔ㄧ敾琚帎鏂?*
            // ```
            //   鈿狅笍 鑰屼笖杩欐槸**骞傜瓑鎬у弽浜嗙殑**涓€澶勶細娉ㄩ噴 `:2709` 鑷繁鍐欑潃
            //     銆宍isShowPlay` 鑻ュ凡鏄?false锛宍@Monitor` 涓嶄細閲嶅鍔ㄤ綔銆嶁€斺€旈偅鏄?鍏抽棴閾捐矾"鐨勮涔夈€?
            //     鍏抽棴閾捐矾涓?`isShowPlay = false` 鏈?*涓夊鏉冨▉璁剧疆鐐?*锛岄兘鍦?
            //     `closeFullScreenPlayback()` 閲屻€侀兘鍦ㄦ纭殑鏃跺埢锛?
            //       路 `:2712` 鏃犻敋鐐规棭閫€鏀?
            //       路 `:2729` 姝ｅ父鏀惰捣琛ラ棿鏀跺熬鏀?
            //       路 `:2738` "娌℃湁鍙潬鍑犱綍鐩存帴鍏抽棴"閫€鍖栨敮
            //   鈬?鏈**涓嶉渶瑕?*鍐嶅啓涓€娆★紱鐣欑潃鍙細璁?鎵撳紑"琚嚜宸辫鍒ゆ垚"鍏抽棴"銆?
            //   鈿狅笍 鑻ュ摢澶╃湡闇€瑕佸厹搴曪紙渚嬪 Hard exit 璧颁笉鍒颁笂闈笁澶勶級锛?
            //      **蹇呴』**鍏堝垽"鎾斁椤佃矾鐢辩‘瀹炲凡缁忎笉鍦ㄦ爤閲?鍐嶅啓 鈥斺€?鍚﹀垯鍙堟槸杩欎釜褰㈢姸銆?
            //      鎺掓煡鍏抽敭瀛楋細`route: push player` 涓?`route: remove player at index=` 鐨勬椂搴忋€?
            //
            // 鈽呪槄鈽?2026-10-16锛?*鎶樹腑鍋氭硶锛氱暀涓嬪畨鍏ㄧ綉锛屼絾缁欏畠涓€涓?鍙湪涓嬪彴鏃惰Е鍙?鐨勬潯浠?*锛夛細
            //   鐩存帴鍒犳帀瀹冩湁椋庨櫓 鈥斺€?`Hard exit`锛堜緥濡傜郴缁熸妸妯℃€佹暣涓敹鎺夈€佹垨鍒殑妯″潡鐩存帴
            //   `popPath`锛夋椂**娌℃湁浠讳綍浜?*浼氭妸杩蜂綘鏉′氦杩樺洖鏉ャ€傛墍浠ヤ笉鍒狅紝鏀规垚"**鍙湪纭
            //   鎾斁椤靛凡缁忎笉鍦ㄨ矾鐢辨爤閲?*鏃舵墠鍐?锛屽苟涓?*鎺ㄨ繜涓€鎷?*锛堣鍚屽抚鍐呭彲鑳藉彂鐢熺殑
            //   push 鍏堣惤鏍堬級锛?
            //     路 鐐瑰嚮鎵撳紑锛氶偅涓€鎷嶆爤閲?*宸叉湁**鎾斁椤?鈬?涓嶅啓 鈬?涓嶄細琚鍒ゆ垚鍏抽棴 鉁?
            //     路 绯荤粺杩斿洖 / 鍏抽棴鎸夐挳锛氶偅涓夊鏉冨▉鐐瑰凡缁忓啓杩囷紙`isShowPlay` 宸叉槸 false锛?
            //       閲嶅鍐欐槸骞傜瓑鐨勭┖鎿嶄綔锛夆湏
            //     路 Hard exit 涓旀病浜哄啓锛氶偅涓€鎷嶆爤閲屾病鏈夋挱鏀鹃〉 鈬?鍐?false 鈬?澹冲眰鏀跺熬 鉁?
            setTimeout((): void => {
              if (this.playerRouteStillPushed()) {
                Logger.info(PlaybackPage.logTag,
                  'RzdMorphOnDisappear keep isShowPlay (player route still on the stack)');
                return;
              }
              if (!this.state.isShowPlay) {
                return;
              }
              Logger.warn(PlaybackPage.logTag,
                'RzdMorphOnDisappear fallback: player route gone but isShowPlay still true 鈬?release it');
              this.state.isShowPlay = false;
            }, 0);
            // 涓嬩竴娆℃墦寮€閲嶆柊璧?鍏堥噺鍐嶇缉"鐨勯『搴忥細鎶婄粯鍒堕棬涔熷叧鍥炲幓
            this.introPaintReady = false;
            // 鈽?椤甸潰鍗歌浇鏃跺浣?璺熸墜浼氳瘽"鐨勪袱涓爣璁般€?
            //   `pullDragging` / `morphDrive` 鍐冲畾鐐瑰嚮鎵撳紑鏃惰涓嶈鍋氬舰鍙樺垵濮嬪寲锛?
            //   鍙鏈変竴杞墜鍔挎病璧板埌鏀跺熬锛堣绯荤粺鎶㈣蛋銆佷腑閫斿嵏杞姐€佺‖鍏抽棴鈥︼級瀹冨氨浼氭畫鐣欙紝
            //   娈嬬暀鎴?(true, FINGER) 鏃剁偣鍑绘墦寮€浼?*姘歌繙璺宠繃褰㈠彉**锛?
            //   閫€鍖栨垚 `collapseProgress` 閭ｅ鑰佸姩鐢伙紙鐢ㄦ埛瀹炴祴锛?鐐瑰嚮/杩斿洖鐢ㄧ殑杩樻槸涔嬪墠鐨勫姩鐢?锛夈€?
            this.expandState.pullDragging = false;
            this.expandState.morphDrive = MorphDrive.NONE;
            // 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮鎵撳紑娌℃湁鍔ㄧ敾"鐨勬簮澶村氨鍦ㄨ繖閲?*锛夛細
            //   涓嬮潰閭ｅ彞鍘熸潵鏄?*鏃犳潯浠?*鐨?`morphReset()`銆傝€?`morphReset()` 浼?
            //   **`morphGen++` 涓?`morphUsable = false` 涓?`morphSessionStarted = false`**銆?
            //   闂鍦ㄤ簬锛?*鐐瑰嚮鎵撳紑鏃讹紝"鏂版挱鏀鹃〉鐨?`onAppear`"涓?鏃ч〉闈㈠疄渚嬬殑 `onDisappear`"
            //   鍑犱箮鍚屽抚鍙戠敓** 鈬?杩欎竴鍙ヤ細鎶?*鍒氬垰鐢卞３灞傚缓绔嬪ソ鐨勬柊涓€杞舰鍙樹細璇?*涓€璧锋竻鎺?
            //   鈬?`morphUsable` 姘歌繙涓哄亣 鈬?瀹瑰櫒鍋滃湪鎭掔瓑 鈬?**鑳屾櫙鏁村睆銆佹病鏈夊姩鐢?*銆?
            //
            //   鈬?鍔犱竴閬撻棬锛?*鎺ㄨ繜涓€鎷嶅啀娓咃紝骞朵笖"鑻ラ偅涓€鎷嶅凡缁忔湁娲荤潃鐨勪細璇濆氨璺宠繃"**銆?
            //     鈽呪槄鈽?2026-10-16锛?*鍒ゆ嵁璁㈡锛歚morphUsable` 鈫?`morphSessionOughtToLive()`**锛夛細
            //       鍘熸潵杩欓噷鍒?`morphUsable`锛堝嚑浣曞凡灏辩华锛夆€斺€?*鍦ㄧ偣鍑昏繖鏉¤矾涓婂畠蹇呯劧涓哄亣**锛?
            //       璧锋墜涓庢寕杞介偅涓€鍒荤粓鐐归敋鐐硅繕娌￠噺鍒帮紝`morphUsable` 灏辨槸 false
            //       鈬?杩欓亾闂?*姘歌繙寮€鐫€** 鈬?涓庤鍒犳帀鐨勯偅鍙ユ棤鏉′欢 `morphReset()` 绛変环銆?
            //       鈽?鏈疆缁х画璁㈡锛歚morphSessionStarted`锛堜笂涓€鐗堬級涓?`playerRouteStillPushed()`
            //         锛堜笂涓婁竴鐗堬級閮戒笉瀵癸紝鐞嗙敱瑙?{@link morphSessionOughtToLive} 鐨勫鐓ц〃銆?
            //       鈿狅笍 涓?`aboutToDisappear()` **蹇呴』鍚屼竴涓垽鎹?*锛堝悓涓€褰㈢姸锛屼笉璁稿悇鍐欎竴濂楋級銆?
            setTimeout((): void => {
              if (this.morphSessionOughtToLive(wasAlive)) {
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
            // 鈽?2026-10-15锛氱綉鏍艰儗鏅殑婧愪綅鍥句篃褰掓湰椤垫寔鏈?鈬?閫€鍦哄繀椤讳竴璧烽噴鏀?
            //   锛堝惁鍒欐瘡娆¤繘鍑烘挱鏀鹃〉閮戒細婕忎竴寮?64脳64 鐨?PixelMap锛夈€?
            this.releasePixelMapQuiet(this.meshSrc);
            this.meshSrc = undefined;
            // 鈽呪槄鈽?2026-10-17锛?*琛ユ紡**锛夛細`搂140` 鏂板姞鐨?瀹夐潤绐楀彛寰呰ˉ缃戞牸婧?涔熷綊鏈〉鎸佹湁 鈥斺€?
            //   瀹冨湪绐楀彛鏈熷唴鍙槸**鎸傜潃**锛坄pendingMeshPm`锛夛紝鑻ヨ繖娈甸噷椤甸潰灏遍€€鍦轰簡锛?
            //   涓婇潰閭ｅ彞鍙噴鏀?`meshSrc`銆?*鎸傜潃鐨勮繖寮犲氨姘歌繙婕忔帀**锛堝悓绫诲唴瀛樺崼鐢熼棶棰橈紝
            //   涓?搂137 閭ｄ釜"蹇収 PixelMap 婕忔竻"鍚屼竴涓舰鐘讹級銆?
            this.releasePixelMapQuiet(this.pendingMeshPm);
            this.pendingMeshPm = undefined;
            this.imageLabel = $r('app.media.ic_avatar1');
            // 椤甸潰閫€鍦哄仠鎺夌潃鑹插櫒鍔ㄧ敾锛氭暣灞忔祦鍏夋槸鎸佺画鐨?GPU 寮€閿€锛屽悗鍙颁笉璇ョ櫧鑰楃數
            try {
              this.flowLightController.stop();
            } catch (_err) {
            }
            const wu = WindowUtil.getInstance();
            wu.applyPlaybackWindowChrome(false, false);
            Logger.info('RzdPlayerRoute', 'leave overlay: window layout unchanged');
            wu.applyPcPlaybackDecorButtonStyle(false);
          })

          // 鈽呪槄 A2锛氭瓕璇嶉〉椤堕儴鐨勩€屽皝闈?+ 姝屽悕銆嶆诞灞傘€?
          //   鏀惧湪 Stack C 鐨?*鏈€鍚庝竴涓瀛?*锛歚position` 鏄?鐩稿鐖剁粍浠跺乏涓婅鐨勭粷瀵瑰畾浣?锛?
          //   鑰屾湰灞傜殑宸︿笂瑙掑氨鏄獥鍙ｅ師鐐癸紙涓?`MorphCoverBridge` 鍚岀骇鍚屽彛寰勶級鈬?
          //   `PlayerExpandState.lyricMorph()` 浜ゅ嚭鐨勭獥鍙ｅ潗鏍囧彲浠ョ洿鎺ョ敤锛?
          //   鍚屾椂瀹冨湪杩欎釜琚?`scale/translate/clip` 鍙樻崲杩囩殑瀹瑰櫒閲?鈬?**鏀惰捣鏃惰窡鐫€涓€璧风缉**銆?
          //
          // 鉀斺洈 2026-10-16锛?*鏈疆璇曡繃涓€娆?鎸夋棤鐣屽眰绾ф惉鍒伴〉闈㈡牴绾?锛屾帹瀵煎畬灏辨挙鍥炰簡**锛夛細
          //   鏃犵晫鐨勫眰绾х‘瀹炴槸"娴姩灞備笌 `playerPane` 鍚岀骇銆佸湪褰㈠彉瀹瑰櫒涔嬪"
          //   锛坄wujie.pa:1861` 鐨?builder 椤哄簭琛細11 `floatingCover` / 12 `metaRow` /
          //    13 `floatingMeta`锛岀 **52** 鎵嶆槸 `playerPane`锛夆€斺€?
          //   浣?*鎴戜滑涓嶈兘鐓ф惉閭ｄ釜灞傜骇**锛屽師鍥犲湪"杩欎釜瀹瑰櫒鍦ㄨ繖涓诞灞備笂澶氬共浜嗕竴浠朵簨"锛?
          // ```
          //     鏃犵晫锛氬皝闈㈠昂瀵?= edge 脳 scaleAt(t)锛圕overMorph 绾嚑浣曠畻鍑烘潵鐨勶級
          //     鎴戜滑锛氬皝闈㈠昂瀵?= morph.size 脳 **瀹瑰櫒鐨?morphScale**锛?鍙樻崲寮?閭ｄ竴瀵?
          //           .scale(morph.size/base.size) + .translate(...) 鐨勪骇鐗╋紝瑙?
          //           `LyricFloatLayer` 鐨?鈶?鎺ㄥ锛?
          // ```
          //   鈬?瀹瑰櫒 `scale` 杩欎竴妫掑湪鎴戜滑杩欒竟**鍚屾椂**鎵挎媴浜?鍐呭灞傝窡鐫€缂?涓?
          //     "娴眰灏侀潰浠庢暣绐楅偅涓€浠界缉鍒拌糠浣犳潯閭ｄ竴浠?**涓や欢浜?*锛涙棤鐣屽彧鎵挎媴鍓嶈€呫€?
          //   鈬?鎶婃诞灞傛惉鍑哄鍣?= 涓㈡帀鍚庤€?鈬?灏侀潰鍦ㄥ姩鐢讳腑**灏?`morphScale` 鍊?*
          //     锛堣捣鎵嬫椂 鈮?0.082 鈬?鍙墿 8%锛夈€傞偅姝ｆ槸鐢ㄦ埛**宸茬粡瀹炴祴杩?*鐨勫舰鐘讹細
          //     `morphOverlayBridging()` 娉ㄩ噴閲岀殑銆屽皝闈粠涓嬪線涓婇銆?銆屽皝闈㈢缉鎴愪竴鐐广€嶃€?
          //   鈬?**瑕佺湡鐓ф惉閭ｄ釜灞傜骇锛屽墠缃潯浠舵槸鍏堟妸灏侀潰鐨勫昂瀵告潵婧愭敼鎴?`scaleAt(t)`**
          //     锛堝幓鎺夐偅涓€瀵?`.scale/.translate`锛夛紝閭ｆ槸璺ㄤ笁澶勭殑缁撴瀯鏀瑰姩 + **蹇呴』鏈夎澶囬€愬抚鐪?*銆?
          //   瀹屾暣鐞嗙敱瑙佹湰鏂囦欢鏍?`Stack` 閲岄偅娈?`鉀斺洈 涓嶈鎶婃诞鍔ㄥ眰鎼埌杩欓噷` 鐨勬敞閲娿€?
          if (this.usesPhoneSwiperLayout()) {
            this.LyricFloatLayer()
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`PLAYER_ROOT_ID`锛夛細**闈炴墜鍔垮叧闂鎷嶇殑閭ｅ紶蹇収灏辨槸鏈妭鐐?*銆?
      //
      // 鏃犵晫閭ｄ竴渚э紝`.id(PLAYER_ROOT_ID)` 鎸傚湪**甯?`.scale/.translate/.clip` 鐨勯偅涓?Stack 涓?*
      // 锛坄wujie.pa:191400-191478`锛歚.scale` 191400-191415 鈫?`.translate` 191416-191431 鈫?
      //   `.clip(true)` 191462-191469 鈫?**`.id(PLAYER_ROOT_ID)` 191470-191478**锛夛紝
      // 鑰?`MeshCoverBg` 涓?`playerPane` 閮藉湪瀹?*閲岄潰**锛堟湰椤?:4952-4970 閭ｆ閫愯瀵圭収锛夈€?
      //
      // 鈬?鎵€浠ヨ繖閲屼篃鎸傚湪**褰㈠彉瀹瑰櫒**杩欎竴灞傦紙涓嶆槸瀹冪殑鐖?`Stack`锛夛細
      //   闈欐鎬侊紙`morphScale=1 / translate=(0,0) / 鏃犺鍓猔锛夊畠灏辨槸**婊″睆鐨勬挱鏀鹃〉**锛?
      //   蹇収鎷垮埌鐨勬鏄?婊″睆閭ｄ竴寮? 鈥斺€?杩欐鏄?`ShrinkOverlay` 瑕佹眰璧风偣涓庢弧灞忛€愬儚绱犲榻愮殑鍓嶆彁銆?
      //   鈿狅笍 鍥犳 `componentSnapshot.get(PLAYER_ROOT_ID, 鈥?` **蹇呴』鍦ㄥ舰鍙樺紑濮嬩箣鍓?*璋?
      //      锛堟棤鐣岀殑 `closeWithAnimation()` 涔熸槸鍦?`pullMode` 涔嬪銆侀〉闈㈣繕婊″睆鏃舵墠鎷嶏級銆?
      //   鈿狅笍 涓?`MESH_BG_ID` / `MINI_LYRIC_BOX_ID` 绛?*骞跺瓨**锛坄getFrameNodeById` 鎸?id 鏌ワ紝
      //      涓€涓妭鐐瑰彧鏈変竴涓?id锛涜繖鍑犱釜鏄?*涓嶅悓鑺傜偣**锛屼簰涓嶅奖鍝嶏級銆?
      .id(PLAYER_ROOT_ID)
      // 鈽呪槄鈽呪槄 2026-10-17锛?*鎺ヤ笂涓婃父閭ｄ釜"LANDING 鏃跺仠绗?鐨勭粯鍒堕棬** 鈥斺€?`playerPaintsOf`锛?
      //
      // ## 涓婃父閭ｄ竴鏉℃槸**鏈夋秷璐硅€?*鐨勶紙`wujie.pa:153390-153430`锛宍MainPage` 鍙戝竷褰㈠彉鐘舵€侀偅閲岋級
      // ```ts
      //   AppStorage.setOrCreate(K_MORPH_SQUASH, playerPaintsOf(stage) ? true : false);  // 鈽?灏辨槸杩欎釜甯冨皵
      //   if (stage !== MorphStage.LANDING) { this.stopLandAnim(); this.morphSquashY = 1; }
      // ```
      // 鑰?`playerPaintsOf(stage) = stage !== MorphStage.LANDING`锛坄MorphState.ets`锛宍wujie.pa:93205`锛?
      // 鈬?**杩?LANDING 閭ｄ竴鍒昏捣锛屾挱鏀鹃〉鏁撮〉涓嶅啀缁樺埗**銆?
      // `PlayerPage` 渚ц瀹冨氨鏄?`pullPaintable = !pullGeomReady ? true : playerPaints(stage)`銆?
      //
      // ## 鏈粨鍘熸潵**娌℃帴**锛堟闂級
      // `PlayerExpandState.playerPaints()` 鏃╁氨鍐欏ソ浜嗭紙`return stage !== LANDING;`锛夛紝
      // 娉ㄩ噴閲屼篃鍐欑潃瀹冮槻鐨勬槸浠€涔堬細
      // > 銆孡ANDING = 宸茬粡浜よ繕缁欒糠浣犳潯锛堝鏍?`playerPaintsOf = false`锛夛細杩欎竴甯ц捣鎾斁椤?
      // >   **涓嶅啀鐢?*锛屽惁鍒欎細鍦ㄨ糠浣犳潯灏侀潰涓婄暀涓€涓?*鍚屽昂瀵哥殑娣辫壊灏忔柟鍧?*锛岀洿鍒拌鍗歌浇銆傘€?
      // 浣嗗畠**闆舵秷璐硅€?* 鈬?閭ｅ彞璇濇弿杩扮殑鐜拌薄涓€鐩村湪鍙戠敓銆傝€?鍚屽昂瀵哥殑灏忔柟鍧?鍦ㄦ墜鏈轰笂姝ｆ槸
      // **涓€鏉″緢鐭殑鑳屾櫙**锛堝鍣?`scale 鈮?0.082` 脳 `clipHeight 鈮?683` 鈮?杩蜂綘鏉￠偅鍧?
      // 330脳56 鐨勬墎骞崇煩褰級鈥斺€?涓庣敤鎴风 鈶?鏉°€?*鏈夎儗鏅絾鏄珮搴︾壒浣?*銆嶉€愬瓧鍚诲悎銆?
      //
      // ## 涓轰粈涔?`.visibility(Hidden)` 鑰屼笉鏄?`.opacity(0)` 鎴栨潯浠舵覆鏌?
      //   路 `Hidden` = **涓嶇粯鍒躲€佷絾淇濈暀甯冨眬** 鈬?涓?鍋滅瑪"鍚屼箟锛屼笖涓嶅姩浠讳綍閲忔祴/閿氱偣
      //     锛坄getFrameNodeById` 鐨勭煩褰€乣onAreaChange` 涓婃姤閮戒笉鍙楀奖鍝嶏級锛?
      //   路 `.opacity(0)` 浠嶄細璧扮粯鍒剁绾匡紙"鍋滅瑪"娌″仛鍒帮級锛岃€屼笖鏈〉鐨?`.opacity` 宸茬粡鏄?
      //     `morphOpacityValue()`锛堟亽 1锛岃閭ｉ噷鐨勬敞閲婏級锛?
      //   路 鏉′欢娓叉煋浼氭妸鑺傜偣浠庢爲涓婃憳鎺?鈬?閲忔祴婧愭秷澶憋紙`PLAYER_BIG_COVER_ID` 绛夛級锛岄闄╁ぇ銆?
      // 鈿狅笍 蹇収鍦?`morphLand()` **涔嬪墠**鎷嶏紙瑙?`closeWithAnimation` 鐨勯『搴忥級鈬?鏈棬缈诲亣鏃?
      //    鍥惧凡缁忓埌鎵嬶紝涓嶄細鎷嶅埌涓€寮犵┖鍥俱€?
      // 鈿狅笍 涓婁竴甯т粛鏄?LEAVING锛堝湪鐢伙級鈬?鍏抽棴鍔ㄧ敾鏈韩涓嶅彈褰卞搷銆?
      .visibility(this.expandState.playerPaints() ? Visibility.Visible : Visibility.Hidden)
      // 瑁佸壀绐楀彛楂樺害 = 鍙楂樺害 / 缂╂斁 鈬?缂╂斁鍚庢濂芥槸閭ｅ潡鍙鐭╁舰
      .height(this.morphClipHeight())
      // 杈圭晫瑁佸壀锛堝渾瑙掔敱鍚勫浘灞傝嚜甯︼紱涓嶇敤 clipShape锛氬畠浼氳鐩?borderRadius锛?
      // 鑰屼笖瀹冪殑褰㈢姸瀵归綈璇箟鍦ㄦ棤璁惧鏃舵病娉曢獙璇侊級
      .clip(this.expandState.morphClipping())
      // 鏁撮〉缂╂斁 + 浣嶇Щ锛氶潤姝㈡€?scale=1 / translate=0锛屼笌娌℃湁杩欏鍔ㄧ敾鏃堕€愬儚绱犱竴鑷?
      //
      // 鈽呪槄鈽?2026-10-16锛堢収鎼棤鐣岀殑**鏄惧紡閿氱偣**锛夛細
      //   鏃犵晫閭ｄ釜瀹瑰櫒锛坄wujie.pa:191400-191415`锛夊啓鐨勬槸
      //     `.scale({ x: expand.scaleValue, y: expand.scaleValue })`
      //   鑰屽畠鐨?`initTranslateX/Y` 鏄?*鎸?缁曚腑蹇冪缉鏀?鍙嶈В鍑烘潵**鐨?
      //   锛坄initParams` 51524-51575锛歚(绐楀鈭抌oxW)/2 鈭?left` / `(h 鈭?h路s)/2 鈭?top`锛夆€斺€?
      //   涔熷氨鏄**"缁曚腑蹇?鏄畠鐨勫墠鎻?*锛屽彧鏄潬榛樿鍊煎厬鐜般€?
      //   鎴戜滑杩欎竴渚ф墍鏈夊嚑浣曪紙`initTranslateX/Y`銆乣coverHostW/H`銆侀€嗗彉鎹㈡帹瀵硷級鐢ㄧ殑涔熸槸
      //   鍚屼竴涓墠鎻愶紝鎵€浠ヨ繖閲?*鎶婂畠鏄惧紡鍐欏嚭鏉?*锛氳涔夌瓑浠凤紝浣嗘妸鍋囪閽夋 鈥斺€?
      //   涓囦竴灏嗘潵 ArkUI 鏀逛簡榛樿閿氱偣锛岃繖涓€琛岃兘鎸′綇"鏁村鍑犱綍涓€璧烽敊浣?銆?
      //   鈿狅笍 **鍙湁 `centerX/centerY` 鏄?鐩稿鑷韩鐨勭櫨鍒嗘瘮"**锛?0% = 鑺傜偣鑷繁鐨勪腑蹇冿級锛?
      //     鎵€浠ュ湪浠讳綍灏哄涓嬮兘绛変环浜?缁曡嚜韬腑蹇?銆?
      .scale({
        x: this.expandState.morphScale,
        y: this.expandState.morphScale,
        z: 1,
        centerX: '50%',
        centerY: '50%'
      })
      .translate({ x: this.expandState.morphTx, y: this.expandState.morphTy })
      .borderRadius(this.expandState.morphRadius)
      .opacity(this.morphOpacityValue())

      // 鉀斺洈 2026-10-16 鈥斺€?**涓嶈鎶婃诞鍔ㄥ眰锛堝皝闈?姝屽悕锛夋惉鍒拌繖閲岋紙椤甸潰鏍圭骇锛?*銆?
      //
      // ## 鎴戞湰杞瘯杩囦竴娆★紝鎺ㄥ瀹屽氨鎾ゅ洖浜嗭紙璁颁笅鏉ュ厤寰椾笅娆″啀璇曪級
      // 鏃犵晫鐨?*灞傜骇**纭疄鏄?娴姩灞備笌 `playerPane` 鍚岀骇銆佸湪褰㈠彉瀹瑰櫒涔嬪"
      // 锛坄wujie.pa:1861` 鐨?builder 椤哄簭琛細11 `floatingCover` / 12 `metaRow` /
      //  13 `floatingMeta`锛岀 **52** 鎵嶆槸 `playerPane`锛夆€斺€?
      // 鎵€浠ユ垜涓€搴︽妸瀹冩惉鍒颁簡鏈眰锛岀悊鐢辨槸"甯冨眬鐩掍笌鏋㈣酱閮界収鎶?鈬?瑙傛劅鍙樺寲涓洪浂"銆?
      //
      // ## 涓轰粈涔堥偅涓悊鐢?*鏄敊鐨?*
      // 鏃犵晫鐨勬诞鍔ㄥ眰閲岋紝灏侀潰鐢ㄧ殑鏄?*绾嚑浣?+ 涓€娆?`scale`**锛?
      // ```
      //   CoverMorph.scaleAt(t) = lerp(1, lyricScale, t)      // 85856-85743
      //   娓叉煋灏哄 = edge 脳 scaleAt(t)                        // 85856 閭ｄ竴妗?
      // ```
      // 鑰?*鎴戜滑杩欎竴灞傜殑灏侀潰鏄?鍙樻崲寮?**锛坄LyricFloatLayer` 閲岄偅瀵?
      // `.scale(morph.size / base.size)` + `.translate(...)`锛岃閭ｉ噷鐨?鈶?鎺ㄥ锛夆€斺€?
      // 瀹冪殑灞忓箷灏哄 = **`morph.size` 脳 瀹瑰櫒鐨?`morphScale`**銆備篃灏辨槸璇达細
      // ```
      //   瀹瑰櫒 scale 杩欎竴妫?*鍚屾椂**璐熻矗涓や欢浜嬶細
      //     鈶?鍐呭灞傦紙topBar/scrubber/transport/姝岃瘝锛夎窡鐫€缂?鈥斺€?鏃犵晫涔熸湁锛?
      //     鈶?娴眰灏侀潰鐨?*灏哄**浠?鏁寸獥閭ｄ竴浠?缂╁埌"杩蜂綘鏉￠偅涓€浠? 鈥斺€?鏃犵晫**娌℃湁**锛堝畠闈?scaleAt锛夈€?
      // ```
      // 鈬?鎶婃诞灞傛惉鍑哄鍣ㄧ殑閭ｄ竴鍒伙紝鈶?灏变涪浜?鈬?灏侀潰鍦ㄥ姩鐢讳腑**姣旀纭€煎皬 `morphScale` 鍊?*
      //   锛坄morphScale` 鍦ㄨ捣鎵嬫椂 鈮?0.082 鈬?灏侀潰鍙墿 8%锛夈€?
      //   閭ｆ鏄?*鐢ㄦ埛宸茬粡瀹炴祴杩?*鐨勫舰鐘讹細
      //     `PlayerExpandState.morphOverlayBridging()` 鐨勬敞閲婂師鏂?鈥斺€?
      //     銆屾垜涓婁竴鐗堝叧鎺夊畠銆佹敼璁╂挱鏀鹃〉閲岄偅寮犵湡灏侀潰鐙嚜鎵挎媴锛岀粨鏋滄槸锛氣€﹁鎰熸垚浜?
      //       銆?*灏侀潰浠庝笅寰€涓婇**銆嶏紙鐢ㄦ埛 2026-10-16 瀹炴祴锛夈€嶏紝
      //     浠ュ強 `灏侀潰缂╂垚涓€鐐广€佸睍寮€鍔ㄧ敾娌℃湁绔偣` 閭ｅ嚑娆°€?
      //
      // ## 缁撹锛堜笅涓€涓汉鐩存帴鐓ц繖鏉¤蛋锛?
      //   娴眰**蹇呴』鐣欏湪褰㈠彉瀹瑰櫒閲?*銆傛棤鐣屼箣鎵€浠ヨ兘鏀惧湪澶栭潰锛屾槸鍥犱负瀹冪殑**灏侀潰鑷韩**鏄?
      //   绾嚑浣曪紙灏哄/浣嶇疆/鍦嗚鍏ㄩ儴绠楀嚭鏉ワ紝涓嶅悆浠讳綍绁栧厛鍙樻崲锛夈€?
      //   鈬?瑕佺湡姝ｇ収鎼偅涓眰绾э紝鍓嶇疆鏉′欢鏄?*鍏堟妸灏侀潰鐨勫昂瀵告潵婧愭敼鎴?`scaleAt(t)`**
      //     锛? 鍘绘帀"鍙樻崲寮?閭ｄ竴瀵?`.scale/.translate`锛岃 `lyricMorph(t)` 鐩存帴缁?
      //      灞忓箷灏哄锛夛紝閭ｆ槸涓€娆?*璺ㄤ笁澶?*鐨勭粨鏋勬敼鍔紝涓?*蹇呴』鏈夎澶囬€愬抚鐪?*銆?
      //   澶嶆牳鍛戒护锛歚grep -rn "LyricFloatLayer()" RzdMusic --include=*.ets`
      //     锛堟湡鏈涳細鍙湁**瀹瑰櫒鍐?*閭ｄ竴澶勮皟鐢級

      // 鈽呪槄鈽?2026-10-16锛?*鐜板満鑷瘉**锛堣繛鐐归《閮?3 娆″紑鍏筹紝瑙?`onDiagHotspotTap()` 鐨勬敞閲婏級銆?
      //   鏀惧湪褰㈠彉瀹瑰櫒**涔嬪**锛堜笉琚缉鏀?瑁佸壀锛夛紝鎵€浠ュ畠鏄剧ず鐨勬暟瀛椾笌璇绘暟鍚屽彛寰勩€?
      //   鈿狅笍 寰芥爣鍏崇潃鏃?`diagText` 涓虹┖ 鈬?鐑尯鏄?*瀹屽叏閫忔槑**鐨勪竴鏉°€佸窘鏍囬浂娓叉煋銆?
      this.DiagHotspot()
      if (this.diagBadgeOn) {
        this.DiagBadge()
      }

      // 璺ㄨ剼鏈崲婧愰啋鐩彁绀烘í骞咃紙鎮诞鍦ㄦ渶涓婇潰锛?
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }

      // 鈿狅笍 缁灏侀潰锛坄MorphCoverBridge`锛?*涓嶅湪杩欓噷**锛?026-10-15 璧峰畠鐢诲湪**鍐呭灞備箣鍓?*
      //    锛堣涓婇潰鏍?Stack 閲岄偅娈垫敞閲婏級鈥斺€?鐢诲湪杩欎竴灞傦紙鍐呭涔嬩笂锛変細鎶婁粠涓嬪崌璧风殑
      //    灏忔瓕璇?鏀惰棌鎸夐挳/杩涘害鏉?搴曢儴鎸夐挳鍏ㄩ兘鍘嬩綇锛岀敤鎴峰疄娴?灏忔瓕璇嶄粠灏侀潰鑳屽悗鍑虹幇銆佽繘搴︽潯琚尅"銆?
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 鈽?涓嬫媺鏀惰捣鎾斁鍣紙MusicHome 鍚屾浜や簰锛夛細绔栫洿鎷栨嫿璺熸墜鏀惰捣锛屾澗鎵嬫寜闃堝€煎喅瀹氬幓鐣欍€?
    //   鎸傚湪鏈€澶栧眰锛涙瓕璇嶉偅绉嶅彲婊氬姩瀛愯妭鐐逛細鍏堟帴鍒扮珫鐩存墜鍔匡紝
    //   鎵€浠ュ湪姝岃瘝涓婃粴涓嶄細璇Е鍙戞敹璧凤紙ArkUI 鐨勬墜鍔垮啋娉￠『搴忥細瀛愯妭鐐逛紭鍏堬級銆?
    .gesture(
      PanGesture(this.panOption)
        // 鈽呪槄 2026-10-15锛堢敤鎴峰疄娴嬨€屾病娉曚笅鎷夊叧闂挱鏀惧櫒銆嶇殑鎺掗殰閿氱偣锛夛細
        //   鏃犵晫閭ｄ唤鎵嬪娍鏄甫 `onActionStart 鈫?dragBackStart()` 鐨?
        //   锛坄_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂1.3锛歚Down / distance:8` +
        //   鍥涗釜鍥炶皟 start/update/end/cancel 榻愬叏锛夈€傛垜浠師鏉ュ彧鏈?update/end
        //   鈬?涓€鏃?涓嬫媺娌″弽搴?锛?*鍒嗕笉娓呮槸鎵嬪娍娌″埌杩欍€佽繕鏄埌浜嗕絾琚棬鎸℃帀**銆?
        //   鐜板湪鎶婂畠鎵撳嚭鏉ワ紙`hdc shell hilog -x | Select-String 'RzdMorph dismiss pan start'`锛夛細
        //     路 涓嬫媺鏃?*鎵撳緱鍑烘潵** 鈬?鎵嬪娍璺敱姝ｅ父锛岄棶棰樺湪闂?闃堝€?
        //       锛堟帴鐫€鐪?`RzdMorph dismiss blocked` 涓?`RzdMorph dismiss commit`锛夛紱
        //     路 **鎵撲笉鍑烘潵** 鈬?绔栫洿鎷栧姩娌¤惤鍒版湰鑺傜偣涓婏紙琚笂灞傛垨瀛愬眰鍚冩帀锛夆噿 瑕佹敼鎸傝浇鐐癸紝
        //       鏃犵晫鐨勫仛娉曟槸鎸傚湪**椤舵爮閭ｄ竴鏉?Row**锛堥潪婊氬姩銆佸繀瀹氭敹鍒帮級鑰屼笉鏄暣椤点€?
        .onActionStart((): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan start isClosing=${this.isClosing} ` +
            `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}`);
        })
        .onActionUpdate((event: GestureEvent): void => {
          // 璺熸墜鏈熼棿涔熺粰 velocityY锛氭嫋鍔ㄤ腑瀹冧笉褰卞搷鍒ゅ畾锛堝垽瀹氬彧鍦ㄦ澗鎵嬮偅涓€甯х敤锛夛紝
          // 浼犺繘鍘绘槸涓轰簡鏃ュ織閲岃兘鍚屾椂鐪嬪埌"浣嶇Щ + 閫熷害"鐨勫畬鏁存洸绾裤€?
          this.onDismissDrag(event.offsetY, false, event.velocityY);
        })
        .onActionEnd((event: GestureEvent): void => {
          // 鈽?D1锛氭澗鎵嬭繖涓€甯х殑 `velocityY` 灏辨槸閫熷害鎻愪氦鍒ゅ畾鐨勮緭鍏ワ紙`GestureEvent.velocityY`锛?
          //   `gesture.d.ts` @since 10锛屾湰鏈?SDK 宸叉牳瀵瑰瓨鍦級銆傜鍙蜂笉鐢辨垜浠亣璁撅紝瑙?`onDismissDrag`銆?
          this.onDismissDrag(event.offsetY, true, event.velocityY);
        })
        // 鈽呪槄 2026-10-15锛堝榻愭棤鐣?鍥涘洖璋?锛夛細**杩欎竴鏀互鍓嶆槸缂虹殑**銆?
        //   澹冲眰閭ｄ笁鏉″悓绫绘墜鍔?*閮芥湁**瀹?鈥斺€?`products/default/鈥?Index.ets` L1786锛坄onPullOpenCancel()`锛夈€?
        //   `MiniBarPlayer.ets` L166銆乣HomeMiniBarPlayer.ets` L235 鈬?鍙堟槸
        //   "**鍚屼竴褰㈢姸鏈?N 澶勩€佸彧鏀逛簡涓€澶?*"锛埪?6.1.6 閭ｆ潯鏁欒鐨勭浜屾鐜板舰锛夈€?
        //
        //   缂哄畠鐨勫悗鏋滀笌涓婁竴杞慨鐨?`isClosing` 娈嬬暀**鍚屼竴绫?*锛氭墜鍔胯涓€旀墦鏂椂
        //   锛堢郴缁熸墜鍔?/ 鏉ョ數妯箙 / 鐖剁骇鎶㈡墜鍔?/ 椤甸潰琚垏璧帮級`onActionEnd` **姘镐笉瑙﹀彂** 鈬?
        //     路 `dismissMorphActive` 娈嬬暀 `true`锛氫笅娆′笅鎷夋椂 `!ended` 鍒嗘敮浼?*璺宠繃
        //       `morphBeginLeaving()`**锛堝畠鍙湪 `!dismissMorphActive` 鏃舵墠璧锋墜锛夆噿 鍑犱綍涓嶅埛鏂般€佽窡鎵嬮敊涔憋紱
        //     路 鐩镐綅娈嬬暀 `LEAVING` 鈬?`morphContainerActive()` 鎭掔湡 鈬?
        //       `beginOpenMorphOnClick()` 鐨勫畧鍗妸"鐐瑰嚮鎵撳紑"鍒ゆ垚"**宸茬粡鍦ㄤ細璇濋噷**"鑰岀洿鎺?return false
        //       鈬?**鐐瑰嚮鎵撳紑鍙堥€€鍖栨垚娲鹃煶鏃у姩鐢?*锛堟鏄敤鎴峰疄娴嬬殑閭ｆ潯鐥囩姸锛岃€屼笖寰堥毦澶嶇幇鎴?绋冲畾鍧?锛夈€?
        //
        //   鏃犵晫鐨勫啓娉曞氨鏄?*鎶婂彇娑堝綋鎴愭澗鎵?*锛歚onActionCancel 鈫?dragBackEnd(0)`
        //   锛坄_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂1.3锛氣憼 閭ｆ潯鎵嬪娍鍥涗釜鍥炶皟榻愬叏锛?
        //   cancel 璧扮殑鏄?`pullEnd(0)`锛涒懁 璧?`dragBackEnd(0)`锛夈€?
        //   鈿狅笍 `velocityY` 蹇呴』浼?**0**锛氬彇娑堜笉璇ヨ褰撴垚"蹇敥"鑰屾彁浜ゆ敹璧凤紙`fastFlick` 瑕?鈮?00锛夈€?
        .onActionCancel((event: GestureEvent): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan cancel offsetY=${event.offsetY.toFixed(1)} ` +
            `dismissMorphActive=${this.dismissMorphActive} ` +
            `stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive}`);
          this.onDismissDrag(event.offsetY, true, 0);
        })
    )
    // 鈽呪槄 2026-10-15锛?*鎾ゅ洖涓婁竴杞殑涓€澶勬敼鍔?*锛屽苟鎶婂師鍥犲啓娓?鈥斺€?瑙佷笅锛?
    //
    // 涓婁竴杞垜鍦ㄨ繖閲岃ˉ杩?`.id(MORPH_HOST_ID)`锛岀悊鐢辨槸"鏈粨涓ゅ娉ㄩ噴閮借鎵嬫満渚ц繖涓?id
    // 灏辨槸鎾斁椤佃嚜宸辩殑鏍瑰鍣紝鑰屾挱鏀鹃〉浠庢病鎸傝繃瀹?銆?*閭ｄ釜鐞嗙敱鏄敊鐨勶紝宸叉挙鍥炪€?*
    //
    // 鐪熺浉锛堟湰杞叏浠撴牳瀵癸級锛?
    // ```
    //   .id(MORPH_HOST_ID) 鐨勭粦瀹氱偣锛?
    //     products/default/.../Index.ets:1796   鈫?澹冲眰**鏍?Stack**锛?*甯搁┗**锛岃瀹冭嚜宸遍偅娈垫敞閲婏級
    //     products/pc/.../Index.ets:345         鈫?PC 澹冲眰鏍?Stack锛堝父椹伙級
    // ```
    // 鈬?鎵嬫満**璺敱妯″紡**涓嬶紝鎾斁椤垫槸澹冲眰鏍?Stack 閲岄偅涓?`HdsNavigation` 鐨?*瀛愯妭鐐?*
    //   鈬?涓や釜鑺傜偣**鍚屾椂鍦ㄧ粍浠舵爲涓?*銆傛墍浠ワ細
    //     路 **缁濅笉鑳?*鍦ㄦ挱鏀鹃〉杩欎竴灞傚啀鎸備竴娆?鈥斺€?閭ｆ槸銆?*鍚?id 涓や唤鑺傜偣**銆嶏紝
    //       鑰屾湰浠撳杩欎欢浜嬫湁鏄庣‘璁板綍锛坄products/default/.../Index.ets` 鍏充簬 `MINI_BAR_ID` 鐨勪袱澶勬敞閲婏細
    //       "涓や唤鍚?id 鐨勮妭鐐癸紝`getRectangleById` 閲忓埌鍝竴浠戒笉纭畾锛岃捣鐐瑰氨鎶?锛夈€?
    //       
    //     路 浜庢槸 `PlayerExpandState.measureGeometry()` 閲岄偅涓?
    //       `measureNode(ui, MORPH_HOST_ID)` 鍦?*鎵嬫満璺敱妯″紡涓?*閲忓埌鐨勬槸**澹冲眰閭ｄ竴灞?*
    //       锛堣€屼笉鏄挱鏀鹃〉鐨勮鍓獥鍙ｏ級鈥斺€?杩欐槸**瀵圭殑銆佷篃姝ｆ槸瀹冩兂瑕佺殑**锛?
    //       瀹冩妸缁撴灉鍙啓杩涙棩蹇楋紙`hostNode=鈥锛夛紝骞朵笖鍦ㄧ揣閭荤殑娉ㄩ噴閲岀偣鍚?
    //       "**缁濅笉鑳芥嬁瀹冨綋閾烘弧鐩爣**锛堥偅鏄浜旀鑷櫖锛?銆?
    //     路 涓婁竴杞垜璇互涓烘槸"婕忔寕" 鈬?缁撹璁㈡涓猴細**杩欐槸鍒绘剰鐨勩€佹纭殑**銆?
    //
    // 鈿狅笍 閭ｄ袱澶勫啓鐫€"鎵嬫満渚ф挱鏀鹃〉鏍?Stack 灏辨槸 `MORPH_HOST_ID`"鐨勬敞閲?*鏄敊鐨?*锛?
    //    宸插氨鍦拌姝ｏ紙瑙?`PlayerExpandState.measureGeometry()` 涓?`contentWidthVp/HeightVp` 涓ゅ锛夈€?
  }

  /**
   * 褰㈠彉鏈熼棿"缁灏侀潰"娴眰锛氫竴寮犺劚绂诲竷灞€銆佹寜瀹夸富鍧愭爣鎽嗘斁鐨勫皝闈€?
   *
   * 鈿狅笍 **2026-10-15锛氳繖涓€妫掑凡缁忔惉鍒板３灞傛诞灞?*锛坄Index.ets` 鐨?`MorphCoverClone()`锛夛紝
   *    鏈〉鍙湪 `hostsMorphOverlay()` 涓哄亣鐨勫涓伙紙PC 澹冲眰锛変笂杩樿皟瀹?鈥斺€?
   *    璋冪敤鐐逛笂鐨勬敞閲婂啓娓呬簡涓轰粈涔堛€傚嚱鏁颁綋淇濈暀锛歅C 閭ｆ潯璺粛鐒堕渶瑕佸畠锛?
   *    鑰屼笖鍒犳帀瀹冨氨寰楀悓鏃跺垹鎺?PC 鐨勫皝闈㈠綋妫掞紙閭ｆ槸鍙︿竴浠朵簨锛夈€?
   *
   * 闈欐鎬?*涓嶄骇鐢熶换浣曡妭鐐?*锛坄morphBridging()` 涓?false锛夛紝鎵€浠ュ畠涓嶅彲鑳藉奖鍝嶉潤鎬佸竷灞€銆?
   * `HitTestMode.None` 鏄繀椤荤殑锛氭暣灞傞摵婊″睆骞曪紝榛樿鍛戒腑鐨勮瘽浼氭妸鎾斁椤垫墍鏈夌偣鍑诲悆鎺夈€?
   */
  @Builder
  MorphCoverBridge() {
    Stack() {
      Image(this.currentCoverSource())
        .width(this.expandState.morphCoverBridge().size)
        // 鈿狅笍 楂樺害**鍗曠嫭鍙?*锛堜笉鍐嶅啓姝绘垚 `size`锛夛細鎾斁椤靛皝闈㈠鏈?`layoutWeight(1)` +
        //    `constraintSize(maxWidth/maxHeight)`锛岄噺鍒扮殑鐭╁舰涓嶄繚璇佹槸姝ｆ柟褰€?
        //    鎸夋鏂瑰舰鐢诲嚭鏉ョ殑缁灏侀潰锛宲=1 浜ゆ缁欑湡瀹炲皝闈㈢殑閭ｄ竴鍒诲氨浼氳烦涓€涓?
        //    锛堢敤鎴峰疄娴嬬殑銆岀粨鏉熸椂灏侀潰浣嶇疆/澶у皬璺充竴涓嬨€嶏級銆?
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
   * 姝岃瘝椤甸《閮ㄧ殑銆屽皝闈?+ 姝屽悕/姝屾墜銆嶆诞灞傦紙瀵规爣鏃犵晫 `PlayerPage.floatingCover` / `floatingMeta`锛夈€?
   *
   * ## 瀹冩槸浠€涔堬紙A2锛氭仮澶嶃€屾瓕璇嶉〉椤堕儴鏈夊皝闈?+ 姝屾洸鍚嶇О銆嶏級
   *
   * 鏃犵晫鐨?`playerPane` 鏄?`Stack { Swiper{ 灏侀潰椤?; **绌?*姝岃瘝椤?} ; floatingCover ; floatingMeta }`
   * 鈥斺€?灏侀潰涓庢瓕鍚嶆寕鍦?`Swiper` **涔嬪**锛屽垏鍒版瓕璇嶉〉鏃?*鍚屼竴涓厓绱?*缂╁皬骞剁Щ鍒伴《閮紱
   * 姝岃瘝椤甸偅涓€椤垫湰韬彧鏈?`padding({ top: lyricPadTop() })`銆傝繖閲屽氨鏄偅涓€灞傘€?
   *
   * ## 涓変釜绾︽潫锛堢己涓€鏉″氨浼氬嚭鑰佹瘺鐥咃級
   *
   * 1. **鍚屼竴鏃跺埢鑷冲涓€寮犲皝闈?*锛氭湰娴眰鎸傝浇 鉄?灏侀潰椤甸偅浠界湡灏侀潰琚?`.opacity(0)` 钘忚捣鏉?
   *    鈬?瑕嗙洊灞傛槸**鍞竴**鐨勫皝闈㈡覆鏌撹€咃紝**娌℃湁"涓よ€呬簰琛?杩欏洖浜嬩簡**锛坄lyricFloatActive()` 宸插垹锛夈€?
   *    锛堟诞灞?`t = 0` 鐢ㄧ殑灏辨槸鐪熷皝闈㈢殑钀界偣鍑犱綍锛岃 `PlayerExpandState.lyricMorph`锛夛紱
   * 2. **闈欐鎬佷笉浜х敓澶氫綑鑺傜偣**锛氬皝闈㈤〉闈欐鏃?`lyricMorphT = 0` 鈬?鍙樻崲涓烘亽绛夈€佷綅缃嵆甯冨眬浣?
   *    锛坄lyricFloatActive()` 閭ｆ妸闂ㄥ凡鍒犻櫎 鈥斺€?瑕嗙洊灞傚父椹伙紝瑙?搂绗?2 鍧楋級銆?
   *    `if` 鍒嗘敮鐩存帴涓嶅缓鑺傜偣 鈬?闈欐鍦ㄥ皝闈㈤〉鏃剁増闈笌娌℃湁杩欏涓滆タ**閫愬儚绱犱竴鑷?*锛?
   * 3. **涓嶅悆瑙︽懜**锛歚HitTestMode.None`锛堜笌 `MorphCoverBridge` 鍚屾锛夆€斺€?
   *    鏁村眰閾烘弧灞忓箷锛岄粯璁ゅ懡涓殑璇濅細鎶婃瓕璇嶇殑婊氬姩涓庣偣鍑诲叏鍚冩帀銆?
   *
   * ## 涓轰粈涔堟寕鍦ㄨ繖涓綅缃紙`Stack`C 鐨勬渶鍚庝竴涓瀛愶級鑰屼笉鏄３灞?
   *
   * 路 **鍧愭爣鍙ｅ緞**锛氭湰灞傚乏涓婅灏辨槸绐楀彛鍘熺偣锛堜笌 `MorphCoverBridge` 鍚岀骇銆佸悓鍙ｅ緞 鈥斺€?
   *   瀹冩寜绐楀彛鍧愭爣 `.position()` 钀戒綅鏄?*宸茶鐪熸満楠岃瘉杩?*鐨勶級锛屾墍浠?`lyricMorph()` 浜ゅ嚭鐨?
   *   绐楀彛鍧愭爣鍙互鐩存帴褰?`.position()` 鐢紝**鍏ㄩ摼闆舵崲绠?*锛?
   * 路 **蹇呴』璺熺潃褰㈠彉涓€璧风缉**锛氬畠鍦ㄨ繖涓 `scale + translate + clip` 鍙樻崲杩囩殑瀹瑰櫒閲岋紝
   *   鏀惰捣鎾斁椤垫椂娴眰璺熺潃缂╋紱鎸傚埌鏍?`Stack`锛堝彉鎹箣澶栵級灏变細"椤甸潰缂┿€佸皝闈笉缂?銆?
   *
   * 鈿狅笍 姝岃瘝鎬庝箞鐢?*涓€涓瓧娌″姩**锛坄LyricsComponent` / `AmllLyricView` 涓嶇锛夈€?
   */
  @Builder
  private LyricFloatLayer() {
    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣?`floatingCover`锛夛細**甯搁┗ + 鍙樻崲寮?*銆?
    //
    //   鈶?甯搁┗锛氬皝闈㈡槸 `playerPane` 閲屼竴涓亽鍦ㄧ殑瑕嗙洊灞傦紝闈?`scale/translate` 鍦ㄤ袱涓鐐归棿鎻掑€硷紝
    //      鎵€浠ラ〉 0 涓嶅啀鐢诲皝闈紙閭ｉ噷宸插垹 `MusicPlayInfoBlock`锛夆€斺€?**鍏ㄧ▼鍙湁涓€浠藉皝闈?*銆?
    //   鈶?鍙樻崲寮忥細甯冨眬鍩哄噯灏哄鍙?`playerCoverGeomRect()`锛?*绾嚑浣曘€佷笉鏌ヨ妭鐐?*锛夛紝
    //      鍙湁 `scale/translate` 浼氭尓瀹?鈬?`t = 0` 鏃?*浣嶇疆鐢卞竷灞€鍐冲畾**锛?
    //      涓嶄細鍑虹幇"瀹藉害渚濊禆涓婃姤銆佷笂鎶ヤ緷璧栧搴?鐨勬鐜紙2026-10-15 閭ｆ灏侀潰娑堝け鐨勬満鍒讹級銆?
    //   鈶?**鏁板涓婁笌鏀瑰墠閫愬儚绱犵瓑浠凤紙浠绘剰 `t`锛屼笉鍙?`t=0`锛?* 鈥斺€?鎺ㄥ锛圓rkUI 甯歌璇箟锛?
    //      `.scale` 缁曡妭鐐逛腑蹇冦€乣.translate` 鍦ㄦ湭缂╂斁鐨勭埗鍧愭爣绯婚噷鍔狅級锛?
    //        scale   = morph.size / base.size
    //        translate = morph.xy 鈭?base.xy
    //        娓叉煋灏哄 = base.size 脳 scale = morph.size                      鉁?
    //        娓叉煋涓績 = baseCenter + translate
    //                 = (base.xy + base.size/2) + morph.xy 鈭?base.xy = morph.xy + morph.size/2
    //        鈬?娓叉煋宸︿笂瑙?= morph.xy                                        鉁?
    //        瑙嗚鍦嗚 = (morph.radius / scale) 脳 scale = morph.radius          鉁?
    //      鈬?**灏侀潰鍦ㄤ换浣曚竴甯х殑钀界偣銆佸ぇ灏忋€佸渾瑙掗兘涓庡師鏉?`.width/.position(lyricFloatRect())` 瀹屽叏鐩稿悓**
    //      锛坄base` 鍙槸"鍙傝€冪郴"锛屽畠鍙栦粈涔堝€奸兘涓嶅奖鍝嶇粨鏋滐紝**鍙瀹冧笉涓?0**锛涜繖姝ｆ槸瀹冨繀椤荤函鍑犱綍鐨勫師鍥狅級銆?
    //      鈿狅笍 涓婃満璇烽『鎵嬬‘璁や竴娆★細灏侀潰椤甸偅寮犲ぇ灏侀潰搴斾笌鏀瑰墠**涓€妯′竴鏍?*锛堣嫢鍙樹簡锛岃鏄?`.translate`
    //         涓?`.scale` 鐨勫鍚堥『搴忎笌涓婇潰鍋囪涓嶇 鈥斺€?閭ｆ槸鍞竴闇€瑕佽皟鏁寸殑鍋囪锛夈€?
    Stack({ alignContent: Alignment.TopStart }) {
      // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲 鈽呪槄 鏈眰鎴愮珛鎵€渚濊禆鐨?*涓ゆ潯鍧愭爣绯诲墠鎻?*锛?026-10-15 琛ヨ锛屽姩鎵嬪墠蹇呰锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
      //
      // 鍓嶆彁 鈶狅細**鏈眰琚寕鍦?婊″睆鍐呭鏍?涓?* 鈬?閭ｄ釜瀹夸富鐨勫唴瀹圭洅宸︿笂瑙?= 绐楀彛鍘熺偣
      //   锛坄PlaybackPage.ets:3227` 閭ｅ彞"鏈眰鐨勫乏涓婅灏辨槸绐楀彛鍘熺偣"璇寸殑灏辨槸瀹冿紝
      //    鑰屽畠**鍙鎵嬫満鏀垚绔?*锛夆噿 `lyricMorph()` 浜ゅ嚭鐨勭獥鍙ｅ潗鏍囧彲浠?*鐩存帴**鍐欒繘 `.position()`銆?
      //   鈿狅笍 鎹㈡垚瀹藉睆/闈㈡澘鐨勫涓伙紙`GridCol` 鍐呭鐩?/ 宸︽爮 `Column`锛夊氨**涓嶅啀鎴愮珛**锛?
      //      蹇呴』鍏堝噺鎺夊涓诲乏涓婅锛坄PlayerExpandState.toHostPoint()` 灏辨槸涓哄畠鍑嗗鐨勶級锛?
      //      鍚﹀垯灏侀潰鏁翠綋鍋忎竴涓爮浣?鈥斺€?瑙?`鐩爣鈶?瀹藉睆闈㈡澘缁熶竴-鏂藉伐鍥句笌楠屾敹.md` 搂4 鐨?S3a銆?
      //
      // 鍓嶆彁 鈶★細**鏈眰鍚屾椂琚鍦ㄥ舰鍙樺鍣紙scale + translate + clip锛?*閲?
      //   鈬?`.position({x, y})` 閲岀殑绐楀彛鍧愭爣鍙湪 `p = 1`锛堝鍣ㄦ槸鎭掔瓑鍙樻崲锛夋椂**涓ユ牸**钀藉湪绐楀彛鐨?(x, y)锛?
      //      褰㈠彉涓紙p < 1锛夊畠鐨?*瀹為檯**绐楀彛浣嶇疆浼氳瀹瑰櫒鍙樻崲鎸蛋銆?
      //   鈽?**鎺ㄥ锛堜笉鏄及鐨勶紱鍙樻崲鍘熺偣鍙栧鍣ㄤ腑蹇冿紝"缁曚腑蹇冪缉鏀?锛?*锛?
      //        璁剧獥鍙ｅ潗鏍?y锛屽鍣ㄩ珮 `H`锛堚増 瀹夸富楂橈級锛宍s = initScale + (1鈭抜nitScale)路t`銆乣d = initTranslateY路(1鈭抰)`
      //        缁曚腑蹇冪缉鏀撅細`y 鈫?H/2 + (y 鈭?H/2)路s`锛涘啀骞崇Щ `d` 鈬?`y' = H/2 + (y 鈭?H/2)s + d`
      //        浠ｅ叆鏈粨鐨?`initTranslateY = barY 鈭?scaledH路(1鈭抜nitScale)/2`锛坄scaledH = barH/initScale`锛?
      //        骞朵护 `t = p`銆乣k = H/2 鈭?scaledH/2`锛?
      //            y' = k路(1鈭抯) + y路s = k(1鈭抰) + y路t   鈬?  **`y' 鈮?t 脳 y`**锛堝洜涓?`k` 涓?`y` 鍚岄噺绾с€佷笖鍦?t=1 鏃舵姷娑堬級
      //        路 `p = 1`锛堣惤浣嶏級锛歚y' = y` 鉁?**姝ｆ槸璁捐鍊?*
      //        路 `p = 0.5`锛氣増 `y/2`   鈫?**鍙湁璁捐鍊肩殑涓€鍗?*
      //        路 `p = 0`锛氣増 `0`        鈫?璐村湪瀹瑰櫒涓婅竟
      //      锛堟妸 `y = 250` 浠ｈ繘鏈満閭ｇ粍瀹炴祴鍑犱綍 `initScale 鈮?0.082 / scaledH 鈮?683 / H 鈮?925`锛?
      //        t=1 鈫?250 鉁撱€乼=0.5 鈫?124銆乼=0 鈫?鈭? 鈥斺€?涓?`y' 鈮?t路y` 鍚诲悎锛?
      //   鈬?**杩欐槸涓€鏉?钀戒綅鏃舵纭€佸舰鍙樹腑鍋?鐨勫彛寰?*锛坄RzdCoverRect` 鐨?`base/tx/ty` 閲忕殑灏辨槸瀹冿級銆?
      //   鈿狅笍 **2026-10-15 鍒绘剰涓嶆敼**锛岀悊鐢辨槸鏀规硶閮藉凡琚湡鏈鸿瘉浼繃锛?
      //       路 閫嗗彉鎹㈠洖椤靛唴鍧愭爣 鈥斺€?鐪熸満缁撴灉"灏侀潰璺戝埌宸︿笂瑙?锛堣 `morphBridging()` 閲岄偅娈碉細
      //         `.scale()` 鐨勬灑杞村綋鏃朵笉鏄垜浠ヤ负鐨勫鍣ㄤ腑蹇冿級锛?
      //       路 鏁村眰鎼嚭褰㈠彉瀹瑰櫒 鈥斺€?浼氬彉鎴?椤甸潰鍦ㄧ缉銆佸皝闈笉缂?锛堢敤鎴峰疄娴嬭繃鐨勮鎰燂級銆?
      //   鈿狅笍 **鍚屼竴鏍瑰洜鐨勫彟涓€浠芥嫹璐濆凡缁忓湪澹冲眰**锛歚Index.ets` 鐨?`MorphCoverClone()` 涔嬫墍浠ヨ鎼嚭
      //      鎾斁椤碉紝娉ㄩ噴鍐欑殑姝ｆ槸杩欎欢浜嬶紙"鐭╁舰鍗存槸绐楀彛鍧愭爣 鈬?鍙湁 p=1 鎵嶄弗鏍兼纭?锛夈€?
      //   鈬?缁撹锛?*鎵嬫満鏀繚鎸佺幇鐘?*锛堢敤鎴峰湪鐪熸満涓婇獙杩囪鎰熷彲鎺ュ彈锛夛紱
      //      瀹藉睆/闈㈡澘閭ｄ竴杞鏋滆澶嶇敤鏈眰锛屽繀椤?*鍚屾椂**鍐冲畾杩欎笁鏉″墠鎻愭€庝箞澶勭悊锛?*涓嶈鍙惉涓€鍗?*銆?
      //   澶嶆牳鍛戒护锛歚hdc shell hilog -x | Select-String 'RzdCoverRect'`
      //     鈬?鐪嬪舰鍙樹腑 `measured`锛坥nAreaChange 缁欑殑甯冨眬浣嶏級涓?`base+tx` 鐨勫樊锛?
      //        涓庝笂闈㈤偅涓夎棰勬祴锛坧=1 鐩哥瓑 / p=0.5 鍑忓崐 / p=0 璐磋锛夊寰椾笂灏辫鏄庤繖鏉″彛寰勮繕鍦ㄧ敓鏁堛€?
      //
      // 婊″睆灞呬腑瀹瑰櫒锛氬皝闈㈢殑**甯冨眬浣嶇疆**锛堝彉鎹箣澶栵級灏辨槸"鍩哄噯鐭╁舰"鐨勫眳涓綅
      // 鈽呪槄鈽?2026-10-16锛堢敤鎴峰畾璋冦€?*褰诲簳鐓ф惉鍚?*銆嶏級锛?
      //   鎶婂皝闈粠銆?*鍩哄噯 + scale/translate**銆嶆敼鎴愭棤鐣岄偅鏍风殑銆?*绾嚑浣曠洿鎺ヨ惤浣?*銆嶃€?
      //
      // ## 涓轰粈涔堣鍘绘帀閭ｄ竴瀵?`scale/translate`
      //
      // 鍘熸潵杩欎竴灞傛槸锛?
      // ```
      //   Image().width(coverLayerBase().size)                     鈫?鍩哄噯灏哄
      //          .scale(瀹炴祴灏哄 / 鍩哄噯灏哄)                        鈫?琛ュ埌"瀹炴祴灏哄"
      //          .translate(瀹炴祴浣?鈭?鍩哄噯浣?                        鈫?琛ュ埌"瀹炴祴浣嶇疆"
      // ```
      // 浜庢槸**灏侀潰鏈€缁堜綅缃?= 瀹炴祴浣嶇疆**锛岃€?瀹炴祴浣嶇疆"鏉ヨ嚜 `onAreaChange` 涓婃姤鐨?
      // `lyricFloatRect()`锛涢偅涓€煎湪鏈粨**涓嶅彲鎺с€佷篃鏃犳硶绂荤嚎鏍稿**锛堢敤鎴峰疄娴?灏侀潰鍋忎綆"锛?
      // 鑰屾垜鎸夊畠鍋氫换浣曟牎姝ｉ兘浼氳瑙傛劅鏇村樊 鈥斺€?搂74/搂75/搂76 涓夋閮芥牻鍦ㄨ繖鏉￠摼涓婏級銆?
      //
      // 鏃犵晫閭ｈ竟**鏍规湰娌℃湁杩欐潯閾?*锛歚floatingCover` 鏄竴涓?`Column(center)` 閲岀殑灏侀潰锛?
      // 灏哄 `morph.edge`銆佷綅缃?`morph.tyAt(t)`銆佸渾瑙?`morph.radiusAt(t)`
      // 鈥斺€?**鍏ㄩ儴鏄畻鍑烘潵鐨?*锛屼笉鏌ヤ换浣曡妭鐐癸紙`PlayerPage瀹屾暣UI瀹氱.md` 搂5锛夈€?
      //
      // 鈬?鐜板湪鐓ф惉瀹冿細**灏哄/浣嶇疆/鍦嗚涓€寰嬪彇鑷?`lyricFloatRect()`锛? `lyricMorph(t)`锛?*锛?
      //   涓嶅啀涔?`scale`銆佷笉鍐嶅姞 `translate`銆俙t = 0`锛堝皝闈㈤〉闈欐锛夋椂 `lyricMorph(0)`
      //   灏辨槸 `playerCoverGeomRect()` 閭ｄ竴浠?*鏃犵晫鐨勭畻寮忕粨鏋?* 鈬?钀戒綅鐢辩畻寮忎竴娆″畾姝汇€?
      Column() {
        Image(this.currentCoverSource())
          // 鈽呪槄鈽?2026-10-16锛堢敤鎴峰畾璋冦€?*褰诲簳鐓ф惉鍚?*銆? 淇袱鏉″疄娴嬶級锛?
          //   **灏哄/浣嶇疆/鍦嗚涓€寰嬪彇 `lyricMorph(t)`锛? 鏃犵晫 `CoverMorph` 鐨勮緭鍑猴級锛?
          //   涓嶅仛浠讳綍鍧愭爣绯绘崲绠?*锛坄coverLocalRect()` 鐜板湪灏辨槸 `lyricFloatRect()` 鐨勭洿閫氾級銆?
          //
          //   鈿狅笍 鎴戜笂涓€鐗堝湪杩欓噷鍔犺繃涓€娆?灞忓箷鍧愭爣 鈫?瀹瑰櫒鏈湴鍧愭爣"鐨?*閫嗗彉鎹?*
          //     锛堝亣璁?`.scale()` 缁曞鍣ㄤ腑蹇冿級锛岀湡鏈虹粨鏋滄槸**灏侀潰椋炲嚭灞忓箷**銆?
          //     鏈粨瀵硅繖鏉″亣璁?*鏃╂湁鍙嶈瘉**锛坄morphCoverRectAt()` 鐨勬敞閲?+ 鏈眰椤堕儴
          //     "鈿狅笍 2026-10-15 鍒绘剰涓嶆敼"閭ｄ竴娈碉細銆岄€嗗彉鎹?鈬?鐪熸満缁撴灉灏侀潰璺戝埌宸︿笂瑙掞紝
          //     璇存槑 `.scale()` 鐨勬灑杞翠笉鏄垜浠ヤ负鐨勫鍣ㄤ腑蹇冦€嶏級鈬?**宸插畬鏁存挙鍥?*銆?
          //     涓轰粈涔堝綋鏃剁殑缁撹鏄?淇濇寔鐜扮姸"锛氬畠铏界劧"钀戒綅鏃舵纭€佸舰鍙樹腑鍋?锛?
          //     浣嗗皝闈㈡槸**璺熺潃瀹瑰櫒涓€璧风缉**鐨勶紙瑙傛劅姝ｇ‘锛夛紝鑰岄€嗗彉鎹細鐩存帴鎶婂畠鐢╁嚭灞忓箷銆?
          //   鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdCoverLocal'`
          .width(this.coverLocalRect().size)
          .height(this.coverLocalRect().height)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.coverLocalRect().radius)
          .clip(true)
          // `.position()` 鏄?*鐩稿鐖剁粍浠跺唴瀹圭洅**鐨勭粷瀵瑰畾浣嶏紱鏈眰瀹夸富鐨勫唴瀹圭洅宸︿笂瑙?
          // = 绐楀彛鍘熺偣锛堝墠鎻愨憼锛岃鏈眰椤堕儴锛夆噿 绐楀彛鍧愭爣鍙互鐩存帴鍐欍€?
          .position({ x: this.coverLocalRect().x, y: this.coverLocalRect().y })
          // 鈽呪槄 2026-10-15锛堜慨鐢ㄦ埛瀹炴祴銆?*鍔ㄧ敾涓€斾細鍑虹幇涓や釜灏侀潰**銆嶏級锛?*灏侀潰杩欏紶蹇呴』鎸?
          //   `realCoverVisible()` 閭ｉ亾闂?* 鈥斺€?瀹冧笌澹冲眰鍏嬮殕灞傜殑 `morphOverlayBridging()` 鏄?
          //   **涓ユ牸浜掕ˉ**鐨勪竴瀵癸紙鏈枃浠?L2665 閭ｅ彞娉ㄩ噴鍐欑殑灏辨槸杩欎欢浜嬶級锛?
          //     路 褰㈠彉涓紙`morphContainerActive()`锛欵NTERING/LEAVING/LANDING锛夆噿 鏈紶**涓嶇敾**锛?
          //       灞忎笂閭ｅ紶鐢卞３灞傚厠闅嗗眰锛坄MorphCoverClone`锛変唬琛紱
          //     路 钀戒綅鍚庯紙stage = OPEN锛夆噿 鏈紶**鐢?*锛屽厠闅嗗眰鍚屾椂鏀跺伐銆?
          //   鈿狅笍 鎴戝師鏉?*婕忎簡杩欓亾闂?* 鈬?褰㈠彉鏈熼棿"鍏嬮殕灞傞偅寮犻琛岀殑灏侀潰"涓?椤甸潰杩欏紶钀戒綅鐨勫皝闈?
          //      **鍚屾椂鍦ㄧ敾** 鈬?鐢ㄦ埛鎴浘閲岀殑涓€寮犲崐/涓ゅ紶灏侀潰銆?
          //   鈿狅笍 杩欐潯鍦?`MusicPlayInfoBlock`锛堝灞?/ 闈㈡澘閭ｄ袱鏀級**涓€鐩撮兘鏈?*
          //      锛圠357 / L510锛歚.opacity(this.expandState.realCoverVisible() ? 1 : 0)`锛夆€斺€?
          //      鍙湁鎵嬫満杩欎竴鏀殑娴眰婕忎簡 鈬?鍙堜竴渚嬨€?*鍚屼竴褰㈢姸 N 澶勩€佸彧鏀逛簡涓€澶?*銆嶏紙绗?4 娆★級銆?
          //   鈿狅笍 涓婃姤閽╁瓙锛坄.id` / `onAreaChange`锛?*涓嶅彈 opacity 褰卞搷**锛岀収甯搁噺寰楀埌 鉁撱€?
          .opacity(this.expandState.realCoverVisible() ? 1 : 0)
          // 鈽?涓婃姤閽╁瓙鎼埌杩欓噷锛堟棤鐣屼篃鏄鐩栧眰鑷繁涓婃姤锛歚floatingCover.onAreaChange 鈫?publishMorphTargets`锛?
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

        // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*涓€妯**锛屼笉鍐嶆槸灞呬腑绔栨帓銆?
        //   瀵规爣 `PlayerPage瀹屾暣UI瀹氱.md` 搂6.1 `floatingMeta` + 搂6.2 `metaRow`锛?
        //     路 灏忓皝闈㈠湪**宸?*锛堝氨鏄笂闈㈤偅寮?`Image`锛岀敱 `lyricFloatRect()` 钀戒綅鍒版瓕璇嶉〉绔偣锛夛紱
        //     路 姝屽悕/姝屾墜鍦ㄥ畠**鍙宠竟銆佸乏瀵归綈**锛坄metaRow` 閲岄偅涓€鍒楁槸 `layoutWeight(1)` +
        //       `alignItems(HorizontalAlign.Start)`锛夛紱
        //     路 鍙充晶鐣欑粰鏀惰棌/鏇村锛堟棤鐣屾槸 `SymbolGlyph 鏀惰棌` + `SymbolGlyph 鏇村`锛夈€?
        //   鈿狅笍 鍘熸潵杩欓噷鏄?`textAlign(Center)` + 鏁村潡姘村钩灞呬腑 鈬?灏辨槸鐢ㄦ埛鎴浘閲?
        //      "娲鹃煶灞呬腑澶у皝闈?/ 鏃犵晫灏忓皝闈㈤潬宸? 鐨勯偅鏉″樊寮傘€?
        //   鈿狅笍 灏侀潰璁╀綅鐢?`padding.left` 琛ㄨ揪锛? 灏侀潰鍙崇紭 + 12锛夛紝
        //      涓庢棤鐣岄潬 `floatingCover`/`metaRow` 涓ゅ眰妯悜閿欎綅杈惧埌鐨勭粨鏋滅瓑浠枫€佸皯涓€灞傘€?
        //
        // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫 `floatingMeta` 鐨勪袱灞傚舰鐘?* 鈥斺€?浣嶈繍绠楃骇鍚屾瀯锛?
        // ```
        //   澶栧眰 Column().width('100%').height(overlayBaseH())
        //                .justifyContent(FlexAlign.Center)        鈫?鍙礋璐?绔栫洿灞呬腑"
        //                .hitTestBehavior(HitTestMode.Transparent)
        //     鍐呭眰 Column().width('100%').alignItems(HorizontalAlign.Start)
        //                  .offset({ y: metaOffsetYAt(swiperProgress) })   鈫?鍙礋璐?鐩稿灞呬腑鐨勪綅绉?
        // ```
        // 锛坄wujie.pa:195907-196008`锛夆噿 鎴戜滑鐓у悓涓€褰㈢姸鎽嗭細澶栧眰缁?*鍩哄噯鐩?*锛坄estBoxHVp()`锛?
        //   涓?`overlayBaseH()` 鍚屼箟锛氬彲鐢ㄩ珮 鈭?鎺у埗鍖猴級锛屽唴灞傜敤 `.offset()` 璧伴偅鏉?lerp銆?
        // 鈿狅笍 鍑犱綍涓婁笌涓婁竴鐗堢殑 `.position({y: metaTopGeomY(...)})` **閫愬儚绱犵瓑浠?*
        //   锛坄metaOffsetY()` 閲屽凡缁忔妸"灞呬腑浣嶇疆"鍑忔帀浜嗭級锛屾崲鐨勫彧鏄?*缁撴瀯涓庡彛寰?*锛?
        //   浠庢浣嶇Щ鏄?鐩稿鍩哄噯鐩掍腑蹇冪殑鍋忕Щ"锛屽拰鏃犵晫鍚屼竴涓噺绾诧紝涓嬩竴姝ヨ皟鍙備笉鐢ㄥ啀杩斿伐銆?
        Column() {
          Column() {
            Row() {
          Column() {
            Text(this.state.getCurrentSongItem()?.title ?? '', { controller: this.titleController })
              // 鈽?绔偣涓婃姤锛堝師 `MusicPlayInfoBlock` 鐨勮亴璐ｏ級鈥斺€?瑙?`publishMetaEndpoint`
              .id(PLAYER_META_TITLE_ID)
              .onAreaChange((): void => {
                this.publishMetaEndpoint(false);
              })
              .fontSize(this.metaTitleFp())
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.play_text_color'))
              .opacity(0.86)
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
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 鈽?鏃犵晫 `metaRow` 鍙充晶閭ｄ袱涓浘鏍囷紙`PlayerPage瀹屾暣UI瀹氱.md` 搂6.2锛夛細
          //   `SymbolGlyph 鏀惰棌` + `SymbolGlyph 鏇村`銆?
          //   鏀惰棌鎺?`MusicStoreService`锛堜笌 `MusicPlayInfoBlock` 鍚屼竴濂楄鍐欙級锛?
          //   鏇村鎵撳紑姝屾洸鑿滃崟 鈥斺€?閭ｄ釜 sheet 鐢?`ControlAreaComponent` 鐢伙紝
          //   鐘舵€佸凡鎻愬崌鍒版湰椤碉紙`playMenuOpen`锛夛紝瑙侀偅閲岀殑 `@Param`/`@Event` 璇存槑銆?
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
          SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
            .fontSize(this.expandState.chromeFavSize())
            .fontColor([$r('app.color.play_text_color')])
            .margin({ top: 2, left: 14 })
            .responseRegion({
              x: -10, y: -10,
              width: PlaybackPage.LYRIC_META_HIT_VP, height: PlaybackPage.LYRIC_META_HIT_VP
            })
            .onClick((): void => {
              this.playMenuOpen = true;
            })
        }
        .width(StyleConstants.FULL_WIDTH)
        // 鈽呪槄 2026-10-15锛堜慨鍥炲綊锛夛細琛岄珮**蹇呴』鐢ㄨ嚜韬嚜鐒堕珮搴?*锛堚増34vp锛夛紝
        //   **涓嶈兘**鐢?`this.lyricFloatRect().size` 鈥斺€?閭ｄ釜鍊煎湪 `t = 0`锛堝皝闈㈤〉锛夋椂鏄?
        //   **澶у皝闈㈣竟闀匡紙328vp锛?*锛岄厤涓?`VerticalAlign.Center` 浼氭妸涓よ鏂囧瓧鎺ㄥ埌杩欎竴甯︾殑涓棿
        //   鈬?**灏侀潰椤电殑姝屽悕琚線涓嬫帹绾?164vp**锛堣惤鍒板睆骞曞簳閮ㄣ€佸帇鍦ㄦ帶鍒跺尯涓婏級銆?
        .height(PlaybackPage.LYRIC_META_ROW_H_VP)
        .alignItems(VerticalAlign.Center)
        .padding({
          left: this.lyricMetaLeftInset(),
          right: PlaybackPage.LYRIC_META_SIDE_VP
        })
        // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫鐨勪綅绉诲叕寮忔湰浣?* 鈥斺€?鍒犳帀鏈粨鑷畾鐨勯偅鍗婃潯寮忓瓙锛?
        //
        // 鍘熸潵杩欓噷鏄細
        // ```
        //   y: lyricMetaMorphY(t) + t 脳 (lyricFloatRect().size 鈭?LYRIC_META_ROW_H_VP) / 2
        // ```
        // 涓や釜闂锛堥兘鍦?搂130/搂131 閲岀粰浜嗗嚭澶勶級锛?
        //   鈶?`lyricMetaMorphY` 鐨?`from` 绔偣鐢ㄧ殑鏄湰浠撹嚜瀹氱殑 `LYRIC_META_GAP_VP = 10`
        //      锛堥偅涓父閲忕殑娉ㄩ噴鑷繁鍐欑潃銆屾湰椤圭洰浼板畾鍊硷紝闈為€嗗悜鍊笺€嶏級锛?
        //      鑰屾棤鐣?`fitPlayerOverlay` 鐨?gap 鏄?*纭紪鐮?50** 鈥斺€?
        //      瀹冪 6 涓疄鍙?`chrome().metaGap` **琚涪寮?*锛坄refitOverlay` 浼?6 涓€?
        //      `fitPlayerOverlay` 鍙敹 5 涓級鈬?閭ｄ釜 10 鏄妸"琚涪寮冪殑鍙傛暟"褰撴垚浜嗙湡鍊笺€?
        //   鈶?`to` 绔偣鐢ㄧ殑鏄?灏忓皝闈㈤《杈?锛屽皯鎺?`metaTopFixLyric`锛?
        //      鑰?`t 脳 (size 鈭?rowH)/2` 閭ｄ釜"灞呬腑琛ュ伩"鍙堟槸鏈粨鑷垱鐨勭涓夐」銆?
        // 鈬?鐜板湪鐩存帴璋?*涓€涓?*鏈夊嚭澶勭殑鍑芥暟锛坄metaTopGeomY`锛屼袱绔偣閫愬瓧鏉ヨ嚜
        //   `CoverMorph.metaOffsetYAt` + `fitPlayerOverlay`锛夛紝鏈涓嶅啀鏈変换浣曡嚜缂栭」銆?
        //
        // 鈽呪槄鈽呪槄 2026-10-17锛氫綅绉?*浠?`.position()` 鎸埌澶栧眰閭ｄ釜 `Column` 鐨?`.offset()`**
        //   锛? 鏃犵晫 `floatingMeta` 鐨勫舰鐘讹紝瑙佷笂闈㈡彃杩涙潵鐨勯偅涓ゅ眰锛夈€?
        //   `metaOffsetY()` = `metaTopGeomY(t, rowH) 鈭?(鍩哄噯鐩掗珮 鈭?rowH)/2`
        //   鈬?涓庡師鏉ラ偅鏉?`.position({ y: 鈥?})` **閫愬儚绱犵瓑浠?*锛屽彧鎹㈠彛寰勩€?
        //   鈿狅笍 鍘熸潵 `.position` 閲岄偅娈?绐楀彛 鈫?椤靛唴鎹㈢畻锛坄metaTopLocalY`锛?鐨勬暀璁粛鐒舵湁鏁堬細
        //     `metaTopGeomY` 鐨勪袱涓鐐?*鏈潵灏辨槸钀藉畾鎬佸嚑浣?*锛堝鍣ㄦ亽绛夋椂绠楀嚭鏉ョ殑鍊硷級
        //     鈬?**宸茬粡鏄〉鍐呭潗鏍囷紝涓嶈鍐嶄箻 `1/morphScale`**锛堜箻浜嗗氨浼?鍏堥鍒板皝闈€佸啀涓嬫潵"锛夈€?

        // 鈽呪槄 2026-10-15锛堜慨鐢ㄦ埛瀹炴祴銆?*鍔ㄧ敾涓€斾細鍑虹幇涓や釜姝屽悕姝屾墜**锛堟湁涓€涓槸娈嬬暀鐨勩€?
        //   浠ュ墠娲鹃煶鐢ㄧ殑姝屽悕姝屾墜椋炲叆锛夈€嶏級锛?
        //   **杩欎竴琛屽師鏉ユ槸鍐欐鐨?`.opacity(1)`**锛堟敞閲婄悊鐢辨槸"甯搁┗ 鈬?鎭掑彲瑙侊細灏侀潰椤甸偅浠芥瓕鍚?
        //   鍘熸潵鐢?`MusicPlayInfoBlock` 鐢伙紝瀹冨凡浠庨〉 0 绉婚櫎"锛夆€斺€?閭ｄ釜鐞嗙敱**鍙闈欐鎬佹垚绔?*锛?
        //   瀹冩妸涓庡厠闅嗗眰鐨?*浜掓枼闂ㄤ竴璧锋媶鎺変簡**锛氬舰鍙樻湡闂村３灞?`MorphMetaBridge`
        //   锛堝氨鏄敤鎴疯鐨?浠ュ墠娲鹃煶鐢ㄧ殑姝屽悕姝屾墜椋炲叆"锛夊湪鐢婚琛屼腑鐨勬瓕鍚嶏紝鑰屾湰琛?*鍚屾椂鍙堝叏浜?*
        //   鈬?**涓ゅ姝屽悕鍚屾椂鍦ㄥ満**銆?
        //   鈬?鎹㈡垚鏃犵晫閭ｉ亾闂?`targetMetaOpacity()`锛坄PlayerExpandState` L1325-1335锛夛細
        //     路 stage = OPEN 鈬?**1**锛堣惤浣嶅悗鎭掑彲瑙侊紝瑕嗙洊"灏侀潰椤甸偅浠芥瓕鍚?鐨勮亴璐?鉁擄級锛?
        //     路 褰㈠彉涓笖鍏嬮殕灞傛帴绠★紙`metaBridgeOwnsPaint()`锛夆噿 **0**锛堜氦妫掔粰鍏嬮殕灞傦級锛?
        //     路 褰㈠彉涓絾鍏嬮殕灞傛病鎺ョ 鈬?閫€鍥?`pullChromeOpacity()` 閭ｆ潯娣″叆鏇茬嚎銆?
        //   鈿狅笍 `MusicPlayInfoBlock`锛堝灞?/ 闈㈡澘閭ｄ袱鏀級**涓€鐩寸敤鐨勫氨鏄畠**锛圠239 / L411 / L447锛?
        //      鈬?鍚屼笂涓€澶勪竴鏍凤紝鍙堟槸銆屽悓涓€褰㈢姸 N 澶勩€佸彧鏀逛簡涓€澶勩€嶆紡鎺夌殑閭ｄ竴澶勩€?
        .opacity(this.expandState.targetMetaOpacity())
        // 鈽呪槄鈽呪槄 2026-10-17锛?*鍒犳帀杩欓噷閭ｆ潯鑷紪鐨?180vp 浣嶇Щ** 鈥斺€?goal 绗?1 鏉＄殑姝ｉ潰瑕佹眰锛?
        //
        // 涓婁竴鐗堣繖閲屾槸 `.translate({ y: this.expandState.metaRiseVp() })`锛?
        // `metaRiseVp() = (1 鈭?ramp01(p, 0.18, 0.62)) 脳 **RISE_VP(180)** / morphScale`
        // 鈥斺€?閭ｄ釜 **180 鏄湰浠撹嚜瀹氬€笺€佹病鏈変换浣曞嚭澶?*锛坄RISE_VP` 鐨勬敞閲婅嚜宸卞啓鐫€"灞忓箷閲?锛夈€?
        //
        // 鏃犵晫杩欎竴琛岀殑浣嶇Щ**鍙湁涓€鏉?*锛屽氨鏄笂闈㈤偅鏉?`.position()` 閲岀殑
        // ```
        //   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
        // ```
        // 锛坄CoverMorph.ets:205-211`锛夆€斺€?**lerp 鏈韩灏辨槸閭ｆ潯"椋炰笂鏉?**锛?
        // t=0 鍦?澶у皝闈㈠簳杈?+ 50"锛宼=1 鍒?灏忓皝闈㈢珫鐩翠腑蹇?锛坄topYAtLyric + 28`锛?
        // 瑙?`META_TOP_FIX_LYRIC_VP`锛夛紝**鍏ㄨ绋嬬敱 t 椹卞姩**锛屼笉闇€瑕佸啀鍙犱竴鏉＄獥鍐呬綅绉汇€?
        //
        // 鈬?鍒犳帀瀹冧箣鍚庯細
        //   路 鏂囧瓧涓庝袱涓浘鏍?*鍚屽杩欎竴琛?* 鈬?渚濈劧"涓€璧烽涓婃潵"锛堜綅缃?lerp 鍚屾簮锛夛紱
        //   路 娣″叆浠嶆寜 `targetMetaOpacity()`锛堝唴鍚?`pullChromeOpacity` 鐨?0.18鈥?.62 绐楀彛锛?
        //     閭ｆ槸鐢ㄦ埛宸茬‘璁ょ殑 鈶級锛?
        //   路 涓庢棤鐣?*鍙樊"杩涘害婧?**锛氭垜浠敤 `lyricMorphT`锛屾棤鐣岀敤 `swiperProgress` 鈥斺€?
        //     杩欐鏄窘鏍囩鍏 `metaD`锛堣姝ｅ悗锛夎閲忕殑涓滆タ銆?
        //
        // 鈿狅笍 `earlyRiseVp()` / `contentRiseVp()`锛堝皬姝岃瘝缁?/ 鎺у埗鍖虹粍锛?*鏈涓嶅姩**锛?
        //   goal 绗?1 鏉″彧鐐逛簡鍏冧俊鎭锛涢偅涓ょ粍鏄?鎺у埗鍖轰粠涓嬪崌涓婃潵"锛岀敤鎴峰凡纭鐨?
        //   鈶?璇寸殑灏辨槸瀹冧滑閭ｅ鏃堕棿绐楋紙`pullChromeOpacity` 0.18鈥?.62 / `pullBottomIn` 0.45鈥?.00锛夈€?
        //   瀹冧滑鍚屾牱鍙犱簡涓€鏉?180vp 鈥斺€?瑕佷笉瑕佷竴璧峰幓鎺夛紝绛夎繖娆¤鎰熷弽棣堝啀瀹氾紙瑙?搂130锛夈€?
          }
          .width(StyleConstants.FULL_WIDTH)
          .alignItems(HorizontalAlign.Start)
          .offset({ y: this.metaOffsetY() })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(this.expandState.estBoxHVp())
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 鈽呪槄 2026-10-15锛堜慨锛夛細杩欓噷鍘熸潵鏄?`HitTestMode.None` 鈥斺€?閭ｆ槸"**鑷繁鍜屽瓙鑺傜偣閮戒笉鍝嶅簲瑙︽懜**"锛?
      //   浼氭妸閭ｄ竴琛屽彸渚х殑**蹇冨舰 / 鏇村涓や釜鎸夐挳鐨勭偣鍑讳竴璧峰悆鎺?*锛堝氨鏄湰鍧楀垰鍔犵殑閭ｄ袱涓級銆?
      //   鏃犵晫澶栧眰鐢ㄧ殑鏄?`HitTestMode.Transparent`锛坄floatingCover` / `floatingMeta` 鐨?
      //   婊″睆瀹瑰櫒閮芥槸瀹冿級锛?*绌虹櫧澶勭┛閫忓埌涓嬪眰銆佸瓙鑺傜偣鐓у父鍙偣** 鈬?杩欓噷鏀规垚鍚屼竴涓€?
      //   鈿狅笍 灏侀潰閭ｅ紶鍥捐嚜宸变粛鐒舵槸 `None`锛堜笂涓€灞傜殑 `Column`锛夛紝鎵€浠ュ畠涓嶄細鎸′綇婊戝姩銆?
      .hitTestBehavior(HitTestMode.Transparent)
    }
}

/*
 * 鈿狅笍 鎾斁椤点€屼竴闀滃埌搴曘€嶅睍寮€鍔ㄧ敾鐨勫巻鍙诧紙2026-09-22 / 09-25锛夆€斺€斿啀鍔ㄦ墜鍓嶅厛璇诲畬銆?
 *
 * 绗竴鐗堬紙宸插簾寮冿級鐢?path 瑁佸壀鎶婃暣椤佃鎴愯糠浣犳潯閭ｄ箞澶х殑灏忕獥鍙ｅ啀閫愬抚闀垮ぇ锛屼袱涓?API 閮藉潖锛?
 *   1. `clipShape(new PathShape({ commands }))` 鈥斺€?鎾斁椤垫暣涓笉鏄剧ず锛堣〃鐜颁负鎵撲笉寮€锛夛紱
 *   2. `clip(new Path({ commands }))` 鈥斺€?鐐瑰嚮鎾斁鍣ㄧ洿鎺ュ崱姝汇€?
 *
 * 鐜板湪杩欑増锛堝鏍囨棤鐣岄煶涔?`ExpandAnimation` + `CoverMorph`锛?*鍙敤**锛夛細
 *   1. **鏁撮〉缂╂斁 + 绔栫洿瑁佸壀绐楀彛**锛歚height / scale / translate / clipShape / opacity`
 *      浜斾釜灞炴€э紝褰㈢姸鍙敤**鍦嗚鐭╁舰**锛坄RectShape`锛屼笉鏄?path锛夆€斺€?
 *      瑙?`PlayerExpandState.applyMorphProgress`锛?
 *   2. **妗ユ帴灏侀潰**锛氬舰鍙樻棭鏈熷崟鐙敾涓€寮犲皝闈紝浠庤糠浣犳潯灏侀潰缁埌鎾斁椤靛皝闈?
 *      锛堣 `MorphCoverBridge` / `PlayerExpandState.morphCoverBridge`锛夈€?
 *
 * 瀹冪殑鍥涗釜蹇呰鏉′欢锛堢己涓€涓氨浼氶€€鍖栨垚"榛戝簳 + 涓嬫柟绌虹櫧 + 涓€鍧楄繎姝ｆ柟褰?锛夛細
 *   1. **鎾斁椤典笌棣栭〉蹇呴』鍦ㄥ悓涓€妫佃鍥炬爲閲?*锛氬舰鍙樻棭鏈熷彲瑙嗙煩褰㈠彧鏈夎糠浣犳潯灏侀潰閭ｄ箞澶э紝
 *      鍏朵綑閮ㄥ垎鏄€忔槑鐨勶紝瑕侀€忓嚭涓嬮潰鐨勯椤典笌杩蜂綘鏉?鈥斺€?鐢?`bindContentCover` 妯℃€佷笉琛岋紝
 *      妯℃€佸涓绘槸涓嶉€忔槑鐨勪竴灞傦紝鎶婇椤靛拰杩蜂綘鏉″叏鐩栦綇浜嗐€?
 *   2. **"閾烘弧"鐨勭洰鏍囬珮搴﹀繀椤绘槸鎭掍负婊″睆鐨勫涓诲鍣ㄥ疄娴嬪嚭鏉ョ殑**锛氭寕鍦ㄨ褰㈠彉鐨勯偅灞備笂浼氳嚜鍣?
 *      锛堥偅灞傞珮搴﹀氨鏄鍓獥鍙ｏ級锛岃 `PlayerExpandState.reportHost`銆?
 *   3. **鍙鐭╁舰鐨勫洓鏉¤竟鍚勮嚜鎻掑€?*锛屼笖**涓嬭竟瑕佹彁鍓嶈创搴?*锛堣糠浣犳潯绂诲睆骞曞簳杈硅繕鏈夊嚑鍗?vp锛?
 *      璺熺潃绾挎€ц蛋鐨勮瘽鏁存鍔ㄧ敾搴曢儴閮芥槸绌虹殑锛夛紱浣嶇Щ= 鍙宸︿笂瑙?鈭?(甯冨眬鈭掑彲瑙?/2锛?
 *      涓嶈兘鐓ф妱鏃犵晫鐨?鍒濆浣嶇Щ 脳 (1-p)"锛堢缉鏀句腑蹇冩槸瀹瑰櫒涓績锛屽父閲忚ˉ鍋夸腑娈典細椤跺嚭灞忓箷锛夈€?
 *   4. **鍦嗚蹇呴』鐢?`clipShape` 瑁?*锛氬彧鍐?`.borderRadius + .clip(true)` 鏃讹紝
 *      瀹瑰櫒鑷韩娌℃湁鑳屾櫙鑹?鈫?鍦嗚涓嶄綔鐢ㄥ埌瀛愯妭鐐?鈫?鍐呭灞備竴娴嚭鏉ュ氨鍙樻柟鍧椼€?
 *
 * 宸茬粡淇濈暀鐨勪笢瑗匡紙閮藉湪 common/musicbasic锛夛細
 *   - `PlayerExpandState`锛堜袱绔皝闈㈢殑绐楀彛鐭╁舰 + 鐩镐綅 + 瀹瑰櫒褰㈠彉鍑犱綍锛夛紱
 *   - `MINI_BAR_COVER_ID` / `PLAYER_BIG_COVER_ID` 涓や釜缁勪欢 id锛?
 *   - 杩蜂綘鏉″皝闈笌鎾斁椤靛ぇ灏侀潰鍚勮嚜 `onAreaChange` 涓婃姤绐楀彛鐭╁舰鐨勮兘鍔涖€?
 */

/** Player content builder mounted by product shells as a full-screen overlay above the shell Stack. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  // **涓嶇瀹夊叏鍖?*锛氶摵婊′氦缁欏３灞傜粰鐨勬诞灞傚鍣紝搴曢儴鐣欑櫧鐢?PlaybackPage 鍐呴儴鎸?
  // navigationBarBottomVp 鑷繁鍔?padding銆傚湪杩欓噷鍐?expandSafeArea / ignoreLayoutSafeArea
  // 浼氬拰澶栧３瀹瑰櫒鍐茬獊锛岀暀鐧藉弽鑰屽彉澶с€?
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
