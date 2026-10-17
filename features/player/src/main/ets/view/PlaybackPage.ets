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

// 閳跨媴绗?`TextController` 閺?ArkUI 閻?*閸忋劌鐪悳顖氼暔缁鐎?*閿涘牅绗夐棁鈧憰?import閿涘畭MusicPlayInfoBlock` 閸氬本顑欓敍?
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
  // 閳?2026-10-16閿涘牏鍙庨幖顒佹￥閻?`BarCollapse`閿涘绱伴幒褍鍩楅弶鈩冨珛閸斻劍鏁圭挧?鐏炴洖绱戦惃鍕閸旇法濮搁幀浣规簚
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
  // 閳?2026-10-15閿涘牐顩惄鏍х湴缂佺喍绔撮敍澶涚窗缁旑垳鍋ｉ柌蹇旂ゴ閻ㄥ嫬鐖堕柌蹇庣瑢瀹搞儱鍙块敍鍫濆斧閺夈儱褰ч崷?`MusicPlayInfoBlock` 闁插瞼鏁ら敍?
  PLAYER_BIG_COVER_ID,
  // 閳?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`PLAYER_ROOT_ID`閿涘绱伴棃鐐村閸斿灝鍙ч梻顓☆洣閹峰秴鎻╅悡褏娈戦柇锝勯嚋閼哄倻鍋ｉ敍? 瑜般垹褰夌€圭懓娅掗敍?
  PLAYER_ROOT_ID,
  // 閳?2026-10-17閿涘牏鍙庨幖顒佹￥閻?ShrinkOverlay閿涘绱伴棃鐐村閸斿灝鍙ч梻顓犳畱韫囶偆鍙庨弨鍓佺級濞搭喖鐪?
  MorphShrinkState,
  type MorphShrinkRect,
  PLAYER_META_TITLE_ID,
  PLAYER_META_SINGER_ID,
  MorphMetaEndpoint,
  areaLengthToVp,
  PlaybackFlowLightState,
  PlaybackShellConstants,
  PlayerExpandState,
  // 閳?2026-10-16閿涙碍婀版い闈涙躬 `.onDisAppear()` 闁插矁顩﹂崚?閹绢厽鏂佹い浣冪熅閻㈣精绻曢崷銊ょ瑝閸︺劍鐖ら柌?閿涘牐顫?`playerRouteStillPushed`閿?
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
// 閳?缂冩垶鐗搁懗灞炬珯閻ㄥ嫬褰囬崶鐐ウ濮樺鍤庨敍鍫㈠弾閹碱剚妫ら悾?`design/logic/MeshSource.ets`閿?
import { SRC_EDGE, enhanceColors, boxBlurRgba } from '../util/MeshSource';
// 閳跨媴绗?閹靛婧€缁愬嫬鐫嗛惃?*妞?0 瀹歌尙绮℃稉宥囨暏鐎瑰啩绨?*閿涘牏鍙庨幖顒佹￥閻ｅ矉绱扮亸渚€娼?濮濆苯鎮曢弨瑙勫灇 `Swiper` 婢舵牜娈戠憰鍡欐磰鐏炲偊绱氶敍?
//    娴?*鐎硅棄鐫?/ 闂堛垺婢樼敮鍐ㄧ湰闁絼琚遍弶鈥冲瀻閺€顖欑矝閸︺劎鏁?*閿涘潉MusicPlayInfoBlock` 閸?1817 / 2101 娑撱倕顦╅敍?
//    閳?import 娑撳秷鍏橀崚鐘偓鍌炲亝娑撱倖娼崚鍡樻暜閻ㄥ嫮绮烘稉鈧弰顖欑瑓娑撯偓閸ф绱欓弫鏉戠潌鐏忎線娼版い鍏哥瑢鐟曞棛娲婄仦鍌氭値楠炶绱氶妴?
import { MusicPlayInfoBlock } from './MusicPlayInfoBlock';
import { TopAreaComponent } from './TopAreaComponent';

/** Clamps a numeric RGB channel to an integer byte in [0, 255]. */
function clampRgbByte(n: number): number {
  if (!Number.isFinite(n)) {
    return 0;
  }
  return Math.max(0, Math.min(255, Math.floor(n)));
}

/** 娑撯偓濞嗏€崇殱闂堫澀绗呮潪鍊熜掗崙铏规畱娑撱倕绱舵担宥呮禈閿涘牐顫?`PlaybackPage.loadOnlineCoverPair`閿涘鈧?*/
class CoverDecodePair {
  /** 閸忋劌鏄傜€甸潻绱濇笟?`effectKit` 閸欐牞澹婇妴?*/
  full: image.PixelMap | undefined = undefined;
  /** 64鑴?4閵嗕阜GBA_8888閵嗕礁褰茬紓鏍帆 閳ユ柡鈧?缂冩垶鐗搁懗灞炬珯閻ㄥ嫭绨妴?*/
  mesh: image.PixelMap | undefined = undefined;
}

/** Minimal shape for probing {@link image.PixelMap.release}; {@link Resource} does not carry this. */
interface PixelMapReleaseProbe {
  release?: () => void;
}

/** 娑撯偓閸﹀牊绁﹂崗澶嬫闂€鍖＄礄ms閿涘绱伴幈顫閻愯澧犻崓?閸涚厧鎯?閼板奔绗夐弰顖炴／閵?*/
const FLOW_LIGHT_DURATION_MS: number = 12000;
/** 濞翠礁鍘滅仦鍌涙殻娴ｆ挷绗夐柅蹇旀鎼达讣绱版径顏堢彯娴兼氨娲婃担蹇撶殱闂堫澀绗屽宀冪槤閵?*/
const FLOW_LIGHT_OPACITY: number = 0.55;

/**
 * Full-screen playback page: layered background, breakpoint-specific layout, dismiss gestures,
 * and dynamic tint from album art.
 */
@ComponentV2
export struct PlaybackPage {
  /**
   * 婢瑰啿鐪伴惃鍕熅閻㈣鲸鐖ら敍鍧処ndex.ets:237 @Provider('pageIndexInfos')` 閹绘劒绶甸敍澶堚偓?
   *
   * 閳?2026-10-16 閺傛澘顤冮敍?*閸烆垯绔撮悽銊┾偓?*閺勵垵顔€閺堫剟銆夐崷?`.onDisAppear()` 闁插苯鍨?
   * 閵嗗本鎸遍弨楣冦€夌捄顖滄暠閺勵垯绗夐弰顖濈箷閸︺劍鐖ら柌灞烩偓宥佲偓鏂衡偓?鐟?{@link playerRouteStillPushed}閵?
   * 娑撹桨绮堟稊鍫滅瑝娴犲骸寮弫棰佺炊閿涙瓪PlaybackPageCoverContent` / `PlaybackPageBuilder` 闁姤妲?`@Builder`閿?
   * 婢舵矮绱舵稉鈧稉?`NavPathStack` 鐟曚焦鏁兼稉澶婎槱缁涙儳鎮曢敍娌桜Provider/@Consumer` 閺勵垱婀板銉р柤瀹歌尙绮￠崷銊ф暏閻?
   * 鐎规ɑ鏌熼幋鎰嚠閺堝搫鍩楅敍鍧処ndex.ets` 瀹歌尙绮￠弰?`@Provider`閿涘绱濋幒銉ょ濞嗏€冲祮閸欘垬鈧?
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
  /** 閹绢厽鏂佹い鍨ウ閸忓鍎楅弲顖氱磻閸忕绱欑拋鍓х枂妞ょ櫢绱滱ppStorageV2 閸忓彉闊╅敍灞炬暭鐠佸墽鐤嗙粩瀣煝閻㈢喐鏅ラ敍澶堚偓?*/
  @Local flowLightState: PlaybackFlowLightState =
    AppStorageV2.connect(PlaybackFlowLightState, AppStorageKeys.PLAYBACK_FLOW_LIGHT_STATE,
      () => new PlaybackFlowLightState())!;
  /** 濞翠礁鍘滈懗灞炬珯閻ㄥ嫪琚辨稉顏堫杹閼硅绱欓悽鍗炵殱闂堛垹濮╅幀浣稿絿閼规彃鍟撻崗銉礆閵?*/
  @Local coverTint: CoverTintState =
    AppStorageV2.connect(CoverTintState, AppStorageKeys.COVER_TINT_STATE, () => new CoverTintState())!;
  /** 濞翠礁鍘滈惈鈧懝鎻掓珤閹貉冨煑閸ｎ煉绱伴幑銏＄摃閸氬孩瀵滈弬鏉垮絿閸掓壆娈戠亸渚€娼版０婊嗗闁插秷顔?uniform閵?*/
  private flowLightController: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  /** 瀹告彃绨查悽銊ュ煂閻偓閼规彃娅掗惃鍕絿閼硅尙澧楅張顒€褰块敍宀勪缉閸忓秴鎮撴稉鈧禒浠嬵杹閼规煡鍣告径宥勭瑓閸欐垵绔烽妴?*/
  private appliedTintVersion: number = -1;
  /**
   * Background cover source (Resource).
   *
   * 閳跨媴绗?2026-10-15閿涙俺鍎楅弲顖涙暭鐎圭偞妞傚Ο锛勭ˇ閸氬函绱濋張顒€鐡у▓?*閹帊璐?`Resource`**閿? `song.label`閿涘苯甯慨瀣殱闂堫澁绱氶敍?
   *   娑撳秴鍟€鐞氼偉绁撮幋?`effectKit` 妫板嫭瑕嗛弻鎾冲毉閺夈儳娈戝Ο锛勭ˇ PixelMap閿涘牓鍋呴弶陇鐭惧鎻掍粻閻㈩煉绱濈憴?
   *   {@link getImageColorAsync}閿涘鈧倻琚崹瀣╃箽閻?`PixelMap | Resource` 閺勵垯璐熸禍鍡楀悑鐎?
   *   {@link isPixelMapCover} / {@link originalCoverSource} 闁絾娼崗婊冪俺閸掑棙鏁妴?
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
  /** 瑜版挸澧?Swiper 妞ょ绱? = 鐏忎線娼版い纰夌礉1 = 濮濆矁鐦濇い纰夌礆閵?*/
  @Local playbackSwiperIndex: number = 0;
  /** 濮濆本娲搁懣婊冨礋閿涘牓鍋呮稉鈧Ο顏囶攽閻ㄥ嫨鈧本娲挎径姘モ偓宥忕礆閺勵垰鎯佺仦鏇炵磻閿涙硞heet 閻?`ControlAreaComponent` 閻㈡眹鈧?*/
  @Local playMenuOpen: boolean = false;
  /** 瑜版挸澧犻弴鍙夋Ц閸氾箑鍑￠弨鎯版閿涘牓鍋呮稉鈧Ο顏囶攽閸欏厖鏅堕惃鍕妇瑜邦澁绱氶妴鍌欑瑢 `MusicPlayInfoBlock` 閸氬奔绔存總妤勵嚢閸愭瑣鈧?*/
  @Local isCurrentFavorite: boolean = false;
  @Local favStore: MusicStoreService = MusicStoreService.getInstance();

  /**
   * 缂冩垶鐗搁懗灞炬珯閻ㄥ嫭绨担宥呮禈閿?4鑴?4閵嗕礁鍑℃潻?`enhanceColors` + `boxBlurRgba(9,3)`閿涘鈧?
   *
   * 閳?2026-10-15閿涘牏鍙庨幖顒佹￥閻?`MeshCoverBg`閿涘绱伴張顒勩€夐幐浣规箒鐎瑰啰娈戦悽鐔锋嚒閸涖劍婀?閳ユ柡鈧?
   *   閹广垺鐡曢弮?`publishMeshSource` 闁插﹥鏂佹稉濠佺瀵媴绱辨稉铏光敄閺冩儼鍎楅弲顖氱湴闁偓閸?鐎圭偞妞傚Ο锛勭ˇ闁絽绱堕崶?閵?
   */
  @Local meshSrc: image.PixelMap | undefined = undefined;
  /** 閹广垹娴樻禒銈囧閿涘潉MeshCoverBg` 闂堢姴鐣犵憴锕€褰傞柌宥嗘煀娑撳﹣绱堕敍宀冾潌闁綁鍣烽惃?`@Monitor`閿涘鈧?*/  @Local meshSrcVersion: number = 0;
  /**
   * 鈽呪槄鈽呪槄 2026-10-17锛?*淇€屽睍寮€杩囩▼涓槸涓婁竴棣栨瓕鐨勯鑹层€?*锛?
   *
   * `coverTint` 鏄?*璺ㄩ〉闈㈠叡浜?*鐨勶紙`AppStorageV2` 鐨?`CoverTintState`锛夛紝瀹冨彧鍦?
   * `extractFlowLightColors()` 鎴愬姛涔嬪悗鎵嶈鏀规垚褰撳墠杩欎竴棣栫殑棰滆壊銆備簬鏄?*鏂版寕杞?*鐨勬挱鏀鹃〉鍦?
   * 鍙栬壊瀹屾垚涔嬪墠锛宍FlowLightBackground()` 鐢荤殑浠嶇劧鏄?*涓婁竴棣?*鐨勯鑹?
   * 鈥斺€?鑰屽畠鏄竴灞傞摵婊℃暣灞忕殑鐫€鑹插櫒/娓愬彉灞傦紝缃戞牸杩樻病鍒颁綅鏃跺畠灏辨槸"鑳屾櫙"
   * 鈬?鐢ㄦ埛鐪嬪埌鐨勫氨鏄€屽睍寮€杩囩▼涓槸涓婁竴棣栨瓕鐨勯鑹层€嶃€?
   *
   * 鈬?鏈瓧娈?= "**褰撳墠杩欎竴棣?*鐨勯鑹插凡缁忎笅鍙戣繃浜?锛?
   *   路 鎸傝浇鏃剁疆鍋囷紙椤甸潰姣忔鎵撳紑閮芥槸鏂板疄渚嬶級锛?
   *   路 `applyFlowLightColors()` 鐪熸涓嬪彂鏃剁疆鐪燂紱
   *   路 `FlowLightBackground()` 鍙湪瀹冧负鐪熸椂鎵嶆寕杞?鈬?灞忓箷姘歌繙涓嶄細鍑虹幇涓婁竴棣栫殑棰滆壊銆?
   * 鈿狅笍 鐪熺綉鏍硷紙`MeshCoverBg`锛変笌瀹冩棤鍏筹細缃戞牸鏈夎嚜宸辩殑 `src`/鍏滃簳缃戞牸锛屼笉渚濊禆鏈瓧娈点€?
   */
  @Local tintReady: boolean = false;
  /**
   * 鈽呪槄鈽?2026-10-17锛?*鎺у埗鍖虹湡瀹炰笂娌?*锛坴p锛岀獥鍙ｅ潗鏍囷級鈥斺€?鐢?`SWIPER_GAP_ROW_ID` 閭ｆ牴鍗犱綅鏉＄殑
   * `.onAreaChange` 鍐欙紙鍙閲忔祴锛屾棤鍓綔鐢級銆俙metaOffsetY()` 鐢ㄥ畠鍋?鍒帇杩涙帶鍒跺尯"鐨勯挸鍒躲€?
   * 鈿狅笍 鍒濆€?-1 = 杩樻病閲忓埌锛涢偅鏃剁敤鎺ㄧ畻鍊煎厹搴曘€傞噺鍒颁箣鍚庝細瑙﹀彂涓€娆￠噸寤猴紝閽冲埗闅忓嵆鐢熸晥銆?
   */
  @Local chromeTopMeasured: number = -1;

  /** 閺囪尙娲伴幋鏍ㄦ暪閽樺繒澧楅張顒€褰夐崠鏍ㄦ閸掗攱鏌婅箛鍐ㄨ埌閵?*/
  @Monitor('state.selectIndex', 'favStore.favoriteVersion')
  onFavoriteChanged(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      this.isCurrentFavorite = false;
      return;
    }
    this.isCurrentFavorite = this.favStore.isFavorite(song.source, song.songId);
  }

  /** 閸掑洦宕查弨鎯版閿涘牏鍙庨幎?`MusicPlayInfoBlock.toggleFavorite()`閿涘奔绻氱拠浣疯⒈婢跺嫯顢戞稉杞扮閼疯揪绱氶妴?*/
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

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 鐟曞棛娲婄仦鍌︾礄閸欐ɑ宕插蹇ョ礆閻ㄥ嫬鍤戞担?+ 缁旑垳鍋ｆ稉濠冨Г閿涘牆顕弽鍥ㄦ￥閻?`floatingCover.onAreaChange 閳?publishMorphTargets`閿涘鏀㈤埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧?

  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();

  // 閳跨媴绗?鏉╂瑩鍣烽崢鐔告降閺堝绔撮弫瀵哥殻閵嗗苯褰夐幑銏犵础鐟曞棛娲婄仦鍌樷偓宥囨畱閸欐牕鈧厧娅?閳ユ柡鈧?**2026-10-17 瀹告彃鍨归梽?*閿?
  //      `coverLayerBase()` / `coverLayerScale()` / `coverLayerTx()` / `coverLayerTy()` /
  //      `coverLayerRadius()`閿? 閸╁搫鍣惌鈺佽埌 / 缂傗晜鏂?/ 娴ｅ秶些 / **閸楀﹤绶?姊?scale**閿涘鈧?
  //   閸掔娀娅庨悶鍡欐暠閿涘牆鍨归崜宥夆偓鎰嚋 grep 閸忋劋绮ㄧ涵顔款吇闂嗚埖绉风拹纭呪偓鍜冪礆閿?
  //   璺?鐎瑰啩婊戦弰?*瀹歌尪顫﹂幘銈呮礀閻ㄥ嫰鍋呮稉鈧悧?*閿?閸╁搫鍣?+ `.scale()` + `.translate()`"閿涘娈戞禍褏澧块敍?
  //     閻滄媽顢戠挧?**`coverLocalRect()`**閿涘矁鈧苯鐣犵亸杈ㄦЦ `lyricFloatRect()` 閻?*閻╂挳鈧?*
  //     閿涘牆鏄傜€?娴ｅ秶鐤?閸﹀棜顫楁稉鈧瀣纯閹恒儱鍟撴潻?`.width/.position/.borderRadius`閿?*閺堫剝濡悙瑙勭梾閺堝鍤滃杈╂畱 `.scale()`**閿涘绱?
  //   璺?閸烆垯绔存潻妯烘躬鐠囪鐣犳禒顒傛畱閺勵垯绗呴棃銏ゅ亝閺?`RzdCoverRect` 鐠囧﹥鏌囬弮銉ョ箶闁插瞼娈?`base=/tx=/ty=` 娑撳顔?閳ユ柡鈧?
  //     閼板矂鍋呮稉澶嬵唽闁插繒娈戝锝嗘Ц"閸欘亝婀佸鑼额潶閹俱倕娲栭柇锝勭閻楀牊澧犻張澶屾畱闁? 閳?閻ｆ瑧娼冮崣顏冪窗鐠囶垰顕遍崥搴㈡降娴滅尨绱欏韫楠炶泛鍨归幒澶涚礆閿?
  //   璺?閳?鐏忋倕鍙?`coverLayerRadius()` 閻ㄥ嫭鏁為柌濠傚晸閻偓閵嗗苯娓剧憴鎺嶇稊閻劌婀?*閺堫亞缂夐弨?*閻ㄥ嫯濡悙閫涚瑐 閳?韫囧懘銆忛梽銈勪簰 scale閵嗗稄绱?
  //     娑撳海骞囩悰宀冾啎鐠?*濮濓絽銈介惄绋垮冀**閿涙氨骞囬崷銊ㄧ箹娑擃亣濡悙?*濞屸剝婀?* `.scale()` 閳?閻撗冪暊閸?闂勩倓浜?scale"
  //     娴兼碍濡哥亸蹇撶殱闂堛垽鍋呯粩顖滄畱閸﹀棜顫楅弨鎯с亣閸?~6.7 閸婂稄绱欓惇瀣絻閸嶅繋閲滅亸蹇撴妇閻楀浄绱氶妴?*鏉╂瑦妲歌箛鍛淬€忛崚鐘冲竴鐎瑰啰娈戦惄瀛樺复閸樼喎娲滈妴?*

  /**
   * 鐟曞棛娲婄仦鍌欑瑐閹躲儯鈧本鎸遍弨楣冦€夌亸渚€娼扮粩顖滃仯閵嗗秲鈧?
   *
   * 閳?鐎佃鐖ｉ弮鐘垫櫕 `floatingCover.onAreaChange 閳?publishMorphTargets()`閿?*鐟曞棛娲婄仦鍌濆殰瀹稿崬姘ㄩ弰顖炲櫤濞村绨?*閵?
   * 閳跨媴绗?**閸欘亜婀亸渚€娼版い鐢告饯濮濐澁绱檂t 閳?0`閿涘妞傛稉濠冨Г**閿涙艾鑸伴崣姗€鈧柧鑵戞潻娆庣鐏炲倻娈戞担宥囩枂閺勵垵顫﹁ぐ銏犲綁妞瑰崬濮╅惃鍕剁礉
   *    閹跺﹦些閸斻劋鑵戦惃鍕叐瑜般垹鍟撻崶鐐殿伂閻愰€涚窗瑜般垺鍨氬锝呭冀妫ｅ牞绱欑粩顖滃仯鐡掑﹨绐囩搾濠備焊閿涘鈧?
   */
  private reportPlayerCoverFromOverlay(area: Area): void {
    if (this.lyricMorphT > 0.001) {
      return;
    }
    // 閳藉應妲勯埥?2026-10-16閿?*瑜般垹褰夋稉顓濈瀵板绗夋稉濠冨Г**閿涘牐顫?`coverAnchorMeasurable()` 閻ㄥ嫭鏁為柌濠忕礆閵?
    //   閻愮懓绱?閺€鎯版崳閺冩儼顩惄鏍х湴娴兼俺绐￠惈鈧€圭懓娅掓稉鈧挧椋庣級閿涘矂鍋呴弮鍫曞櫤閸掓壆娈戦惌鈺佽埌閺?鏉╄渹缍橀弶鈥崇殱闂堛垽鍋呮稊鍫濄亣"閿?
    //   閸愭瑨绻?`endCover*` 娴兼碍濡哥紒顓㈩棧鐏忎線娼伴惃鍕矒閻愮懓鍟撻崸?閳?闁絼绔村Λ鎺嶇瑝閻㈢粯鍨ㄦ鐐插煂闁挎瑧娈戠亸蹇曠叐瑜邦潿鈧?
    if (!this.coverAnchorMeasurable()) {
      return;
    }
    const gx: number = areaLengthToVp(area.globalPosition.x);
    const gy: number = areaLengthToVp(area.globalPosition.y);
    const gs: number = areaLengthToVp(area.width);
    // 閳藉應妲?2026-10-15 鐠囧﹥鏌囬柨姘卞仯閿涘潉hdc shell hilog -x | Select-String 'RzdCoverRect'`閿涘鈧柡鈧?
    //   娑撯偓濞嗏剝濡?*娑撳閲滈惌鈺佽埌**閹垫挸鍤弶銉礉閻劍娼甸崚銈呯暰"鐏忎線娼伴拃鐣屽仯娑撳秴顕?閸掓澘绨崇仦鐐扮艾閸濐亙绔寸粔宥忕礄**娑撱倗顫掓穱顔界《鐎瑰苯鍙忔稉宥呮倱**閿涘绱?
    //     璺?`measured` = `onAreaChange` 閻?`globalPosition`閵嗗倵娈搁敂?鐎瑰啯妲?*鐢啫鐪崙鐘辩秿**閿?
    //       **娑撳秴鎯堥張顒冨Ν閻愮鍤滃杈╂畱 `.scale()` / `.translate()`**閿涘牊婀版禒鎾存暈闁插﹤顦挎径鍕繁鐠嬪啳绻冩潻娆庣閻愮櫢绱氶敍?
    //     璺?`geometry` = 缁绢垰鍤戞担鏇狀伂閻愮櫢绱檂playerCoverGeomRect()`閿?*娑撳秵鐓℃禒璁崇秿閼哄倻鍋?*閿涘苯顕弽鍥ㄦ￥閻?
    //       `CoverMorph` 閸忋劎鈻兼稉宥夊櫤濞村绱氶敍?
    //     璺?`base/tx/ty` = 鐟曞棛娲婄仦鍌滄畱閸欏倽鈧啰閮存稉搴濈秴缁?閳ユ柡鈧?**濞撳弶鐓嬫担?= base + translate**閵?
    //   **閸掋倖宓?*閿?
    //     閳?閼?`dxy` 閳?娑撳﹣绗呯€瑰鍙忛崠娲彯鎼达讣绱欓崙鐘插磩 vp閵嗕椒绗栨稉濠佺瑓娑撱倓閲滈弬鐟版倻閿?閳?**閸愬懎顔愰惄鎺戜焊缁?*闂傤噣顣?
    //        閳?鐏忚鲸妲?`PlaybackPageRoute` 闁絾娼い鍨壌閹碘晛鐫嶉敍鍧別xpandSafeArea` + `ignoreLayoutSafeArea`閿涘婀粻鈽呯幢
    //     閳?閼?`dxy` 閺?*閸掝偆娈戠敮鍛婃殶 / 娑?`tx,ty` 閸氬苯鈧?* 閳?**闁插繑绁撮崣锝呯窞**闂傤噣顣?
    //        閳?鐠囧瓨妲戠拠銉﹀Ω**濞撳弶鐓嬫担宥忕礄base + translate閿?*閼板奔绗夐弰顖氱鐏炩偓娴ｅ秵濮ゆ稉濠傚箵閿涘牆鎯侀崚?缁旑垳鍋ｉ悽鍗炵殱闂堛垻鐣婚妴?
    //          鐏忎線娼伴崣鍫熷瘻缁旑垳鍋ｉ拃鎴掔秴"娴兼艾鑸伴幋?*濮濊崵骞?*閿涘矁顕ゅ顔荤窗鐞氼偆菙鐎规艾婀撮柨浣风秶 閳ユ柡鈧?鏉╂瑦顒滈弰顖涙拱閺傝纭跺▔銊╁櫞闁?
    //          閺冣晛姘ㄩ崘娆掔箖閻?閼奉亜绻侀柌蹇氬殰瀹?閿涘鈧?
    //   閳跨媴绗?鏉╂瑦娼弮銉ョ箶**閸欘亣顕版稉宥呭晸**閿涘奔绗夎ぐ鍗炴惙娴犺缍嶇悰灞艰礋閿涘潉reportBig` 閻ㄥ嫬鍙嗛崣鍌欑鐎涙婀弨鐧哥礆閵?
    const geom: LyricMorphRect = this.expandState.playerCoverGeomRect();
    // 閳藉應妲勯埥?2026-10-16閿?*鐏忎線娼伴崺鍝勫櫙閸戠姳缍嶉懛顏囩槈**閿涘牊甯撻弻銉ュ彠闁款喖鐡?`RzdCoverGeom`閿?
    //   娑撯偓閺夆€虫皑閼宠棄鍨?鐏忎線娼版担宥囩枂鐎甸€涚瑝鐎?閿涘奔绗夎箛鍛晙闂堢姵鍩呴崶楣冨櫤閸嶅繒绀岄敍?
    //     閺堢喐婀滈敍鍫熷閺?360鑴?80 鏉╂瑦銆傞敍澶涚窗`edge=328`閵嗕梗y閳?36`閿? 妞ゆ儼绔熼敍澶堚偓涔enter=300`閵?
    //     璺?`edge` 閺勫孩妯夋径褌绨?328閿涘牅绶ユ俊?393/369閿涘鍣?鐎逛粙顣╃粻妤€寮甸悽銊﹀灇"閺佸鐛ョ€?娴滃棴绱?
    //     璺?`y` 閹恒儴绻?`(winH閳姀dge)/2`閿涘牃澧?298閿涘鍣?閸欏牆褰夐崶?閸︺劎鐛ラ崣锝夊櫡鐏炲懍鑵?閿涘牃鍟?閻劍鍩涢幎銉ф畱"娴ｅ簼绨℃總钘夘樋"閿涘鈧?
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverGeom edge=${geom.size.toFixed(1)} x=${geom.x.toFixed(1)} y=${geom.y.toFixed(1)} ` +
      `centerY=${(geom.y + geom.size / 2).toFixed(1)} radius=${geom.radius.toFixed(1)} ` +
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `padTop=${this.expandState.topInsetVp().toFixed(1)} padBottom=${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      // 閳?閸掋倖宓侀敍姝歝enterY` 閺勵垱婀板▎?*閸╁搫鍣?*閻ㄥ嫪鑵戣箛鍐︹偓鍌涙埂閺堟冻绱欓幍瀣簚閿? padTop + 244 閳?300閵?
      //   閼汇儱鐣犻幒銉ㄧ箮 `win/2`閿涘牃澧?62閿涘鍣?閸欏牆娲栭崚?缁愭褰涚仦鍛厬"閿涘牏鏁ら幋閿嬪Г閻?娴?閿涘鈧?
      `expectCenter=${(this.expandState.topInsetVp() + 244).toFixed(1)} ` +
      `(windowCentered-y=${((this.expandState.windowHeightVp - geom.size) / 2).toFixed(1)})`);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverRect measured=(${gx.toFixed(1)},${gy.toFixed(1)},${gs.toFixed(1)}) ` +
      `geometry=(${geom.x.toFixed(1)},${geom.y.toFixed(1)},${geom.size.toFixed(1)}) ` +
      `dxy=(${(gx - geom.x).toFixed(1)},${(gy - geom.y).toFixed(1)}) ` +
      // 閳跨媴绗?2026-10-17閿涙艾甯弶銉ㄧ箹闁插矁绻曢張?`base=/tx=/ty=` 娑撳顔岄敍宀勬"閸欐ɑ宕插蹇氼洬閻╂牕鐪?闁絼绔寸花鍥︾鐠у嘲鍨归梽銈勭啊
      //   閿涘牆鐣犳禒顒勫櫤閻ㄥ嫬褰ч張澶婂嚒鐞氼偅鎸欓崶鐐哄亝娑撯偓閻楀牊澧犻張澶屾畱闁插骏绱濈憴浣规拱閺傚洣娆?:247 闂勫嫯绻庨柇锝嗩唽鐠佹媽澶勯敍澶堚偓?
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
   * 閳藉應妲勯埥?2026-10-16 閺傛澘顤冮敍?*"缂佸牏鍋ｉ柨姘卞仯閸欘亣鍏橀崷銊ュ弿鐏忓搫顕柇锝勭鐢傜瑐閹?** 閳ユ柡鈧?娓?
   * {@link PlaybackPage.reportPlayerCoverFromOverlay} 閻㈩煉绱欓柇锝勮⒈婢?`reportBig` 閻ㄥ嫬澧犵純顔煎灲閹诡噯绱氶妴?
   *
   * ## 娑撹桨绮堟稊鍫濈箑妞ゆ槒顩︽潻娆撲壕闂傤煉绱欓悙鐟板毊閹垫挸绱戝▽鈩冩箒鐏忎線娼伴崝銊ф暰閻ㄥ嫮婀￠崙鐘辩秿妞嬪酣娅撻敍?
   *
   * 鐟曞棛娲婄仦鍌滄畱 `.id(PLAYER_BIG_COVER_ID)` + `onAreaChange` 閺冦垺妲?閹绢厽鏂佹い闈涚殱闂?閻?*閸烆垯绔撮柌蹇旂ゴ濠?*閿?
   * 閸欏牐顫﹂幐鍌氭躬**瑜般垹褰夌€圭懓娅掗崘鍛村劥**閵嗗倷绨弰顖ょ窗
   * ```
   *   鐎圭懓娅掑鑼病鐞氼偄甯囬崚鎷屾崳閻愮櫢绱檚cale 閳?0.08閿涘绠ｉ崥搴礉娴犺缍嶆稉鈧▎?onAreaChange 閹躲儰绗傞弶銉ф畱
   *   globalPosition/width 闁姤妲搁妴鎰碃娴ｇ姵娼亸渚€娼伴柇锝勭疄鐏忓繈鈧垹娈戦惌鈺佽埌
   *   閳?鐎瑰啩绱伴幎?`endCoverSize/endCoverX/endCoverY` 閸愭瑦鍨氭潻铚傜稑閺夛紕娈戠亸鍝勵嚟
   *   閳?缂侇參顥ｇ亸渚€娼伴敍鍫熻癁鐏炲倸鍘犻梾鍡礆閻?*缂佸牏鍋?*鐞氼偄鍟撻崸蹇ョ窗闁絼绔村Λ鎺曨洣娑斿牅绗夐悽姹団偓浣筋洣娑斿牓顥ｉ崚棰佺娑擃亪鏁婄拠顖滄畱鐏忓繒鐓╄ぐ?
   * ```
   * 閻劍鍩涚€圭偞绁撮妴?*閻愮懓鍤幍鎾崇磻 / 閻愮懓鍤崗鎶芥４ / 缁崵绮烘潻鏂挎礀闁姤鐥呴張澶婄殱闂堛垹濮╅悽?*閵嗗秳绗屾潻娆愭蒋鐎瑰苯鍙忛崥璇叉値 閳ユ柡鈧?
   * 閻愮懓鍤捄顖氱窞娑撳﹨顩惄鏍х湴閺?*闂呭繘銆夐棃顫鐠ч攱瀵曟潪?*閻ㄥ嫸绱濈€瑰啰娈戠粭顑跨濞?`onAreaChange` 瀵板牆褰查懗钘夋皑閽€钘夋躬
   * "鐎圭懓娅掑鑼额潶閸樺鍩岀挧椋庡仯"娑斿鎮楅妴?
   *
   * 閳?閸掋倖宓侀敍?*鐎圭懓娅掗弰顖涗航缁涘褰夐幑顫礄`morphScale 閳?1`閿涘绗栧▽鈩冩箒鐟佷礁澹€**閺冭埖澧犻崗浣筋啅娑撳﹥濮ら妴?
   *   瑜般垹褰夋稉顓ㄧ礄`morphClipping()` 娑撹櫣婀￠敍澶夌瀵板绗夋稉濠冨Г 閳ユ柡鈧?闁絾妞傞柌蹇撳煂閻ㄥ嫰鍏樻稉宥嗘Ц"闂堟瑦顒涢幀浣烘埂鐎圭偟鐓╄ぐ?閵?
   * 閳跨媴绗?闂堟瑦顒涢幀浣烘畱 `morphScale` 閹帊璐?1 閳?鏉╂瑩浜鹃梻銊ユ躬闂堟瑦顒涢幀?*閹帞婀?*閿涘奔绗夎ぐ鍗炴惙閺冦垺婀佺悰灞艰礋閵?
   * 閳跨媴绗?娑撳孩妫﹂張澶屾畱 `lyricMorphT > 0.001` 闁綁浜鹃梻銊︽Ц**娑撱倖娼悪顒傜彌閺夆€叉**閿涘牓鍋呴弶锛勵吀"濮濆矁鐦濇い鐢割棧鐞涘奔鑵?閿涘绱?
   *   娑撱倖娼柈钘夌箑妞よ绻氶悾娆嶁偓?
   */
  private coverAnchorMeasurable(): boolean {
    if (this.expandState.morphClipping()) {
      return false;
    }
    return this.expandState.morphScale >= 0.999;
  }

  /**
   * 娑撳﹥濮ゅ灞芥倳/濮濆本澧滈惃?*閹烘帞澧楃粩顖滃仯**閿涘牆鑸伴崣妯诲Ω閺傚洤鐡ч悽鍗炪亣閸欐ê鐨?閻㈠崬鐨崣妯恒亣閺冭埖瀵滈崥灞肩婵傛鐡ф担鎾冲棘閺佺増褰冮崐纭风礆閵?
   *
   * 閳?鏉╂瑤琚辨稉顏冪瑐閹躲儱甯弶銉ユ躬 `MusicPlayInfoBlock` 闁插被鈧倸鐣犳禒搴ｇ崕鐏炲繘銆?0 缁夊娅庨崥搴＄箑妞ょ粯鎯夐崚鎷岀箹闁?閳ユ柡鈧?
   *   閸氾箑鍨粩顖滃仯闁插繋绗夐崚?閳?**鐏忎線娼扮紓鈺傚灇 0閿涘牏婀呮稉宥堫潌閿? 鐏炴洖绱戦崝銊ф暰濞屸剝婀佺粩顖滃仯**閿?026-10-15 闁絾顐煎畷鈺傜皾閻ㄥ嫭鐗撮崶鐙呯礆閵?
   * 鐎涙ぞ缍嬮崣鍌涙殶娑撳酣鍋呮稉鈧悰?*鐎圭偤妾〒鍙夌厠閻ㄥ嫬鈧?*娣囨繃瀵旀稉鈧懛杈剧礄`LYRIC_META_TITLE_FP` / `LYRIC_META_ARTIST_FP`閿涘鈧?
   */
  private publishMetaEndpoint(singer: boolean): void {
    const song = this.state.getCurrentSongItem();
    const endpoint: MorphMetaEndpoint = new MorphMetaEndpoint();
    endpoint.id = singer ? PLAYER_META_SINGER_ID : PLAYER_META_TITLE_ID;
    endpoint.controller = singer ? this.singerController : this.titleController;
    const raw: string | Resource = singer ? (song?.singer ?? '') : (song?.title ?? '');
    endpoint.content = typeof raw === 'string' ? raw
      : this.getUIContext().getHostContext()!.resourceManager.getStringSync(raw.id);
    // 閳?2026-10-15閿涙矮绗傞幎?*瑜版挸澧犳潻娆庣鐢?*閻ㄥ嫬鐡ч崣鍑ょ礄娑撱倗顏幓鎺戔偓鑲╂畱缂佹挻鐏夐敍澶涚礉閼板奔绗夐弰顖氭祼鐎规氨娈戝宀冪槤妞ら潧鈧?閳ユ柡鈧?
    //   閸氾箑鍨ぐ銏犲綁缁旑垳鍋ｉ柌蹇撳煂閻ㄥ嫭妲告稉鈧稉?閸欘亜婀宀冪槤妞ゅ灚澧犻幋鎰彌"閻ㄥ嫬鐡ч崣鍑ょ礉鐏忎線娼版い鐢稿亝娑撯偓缁旑垯绱伴崑蹇撶毈閵?
    endpoint.fontFp = singer ? this.metaArtistFp() : this.metaTitleFp();
    endpoint.family = singer ? PlayerConstants.FONT_FAMILY_BLACK : PlayerConstants.FONT_FAMILY_BOLD;
    endpoint.weight = singer ? 400 : 700;
    endpoint.color = singer ? $r('app.color.play_singer_color') : $r('app.color.play_text_color');
    endpoint.opacity = singer ? 1 : 0.86;
    endpoint.maxLines = 1;
    this.expandState.registerMorphMeta(false, singer, endpoint);
  }

  /**
   * 閳藉應妲勯埥?2026-10-16 閺傛澘顤冮敍姘殱闂堛垼鎯ゆ担宥夋 `lyricMorphT` 閸欐ê瀵查弮鑸靛ⅵ娑撯偓濞嗏€愁嚠鐠愶附妫╄箛妞尖偓?
   *
   * 閳跨媴绗?`lyricMorphT` 閺?*闁劕鎶?*閺€鍦畱閿涘牐藟闂傛挳鍣烽崘娆欑礆閿涘本澧嶆禒銉ㄧ箹闁?*韫囧懘銆?*閺堝濡ù?閳ユ柡鈧?
   *   閼哄倹绁︽稉搴″箵闁插秹鍏橀崷?{@link PlaybackPage.logCoverLocal} 闁插矉绱?00ms + 缁涙儳鎮曞В鏂款嚠閿涘鈧?
   * 閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdCoverLocal'`
   */
  @Monitor('lyricMorphT')
  onLyricMorphTChanged(): void {
    this.logCoverLocal();
  }

  /** 閺囪尙娲伴崣妯哄閺冨爼鍣搁幎銉よ⒈娑擃亝鏋冪€涙顏悙鐧哥礄閸樼喐娼甸崷?`MusicPlayInfoBlock` 閻?`@Monitor` 闁插矉绱氶妴?*/
  @Monitor('state.selectIndex')
  onMetaEndpointChanged(): void {
    this.publishMetaEndpoint(false);
    this.publishMetaEndpoint(true);
  }

  /**
   * @returns 濮濆矁鐦濇い鐢稿亝娑撯偓濡亣顢戦惃?*瀹革箑鍞存潏纭呯獩**閿涘澊p閿涘鈧?
   *
   * 閹?`lyricMorphT` 閸︺劋琚辨稉顏嗩伂閻愰€涚闂傚瓨褰冮崐纭风窗
   * 璺?`t = 0`閿涘牆鐨濋棃銏ゃ€夐敍? 妞ょ敻娼版潏纭呯獩閿涘本鐡曢崥宥呯湷娑擃厼灏锝勭瑓閺傜櫢绱?
   * 璺?`t = 1`閿涘牊鐡曠拠宥夈€夐敍? **鐏忓繐鐨濋棃銏犲礁缂?+ 12**閿涘本鏋冪€涙顔€瀵偓鐏忓繐鐨濋棃顫偓?
   * 閺冪姷鏅棃?`floatingCover` 娑?`metaRow` 娑撱倕鐪伴惃鍕崥鎴︽晩娴ｅ秷鎻崚鏉挎倱娑撯偓閺佸牊鐏夐敍宀冪箹闁插瞼鏁ら崘鍛扮珶鐠烘繆銆冩潏淇扁偓?
   * 鐏忔垳绔寸仦鍌樷偓浣风瘍婢垛晝鍔ч梾蹇氱箻鎼达箒绻涚紒顓ㄧ礄娑撳秳绱伴崷銊ゆ唉濡帒鎶氱捄鍏呯娑撳绱氶妴?
   */
  private lyricMetaLeftInset(): number {
    const side: number = PlaybackPage.LYRIC_META_SIDE_VP;
    const t: number = this.lyricMorphT;
    const coverRight: number = this.lyricFloatRect().x + this.lyricFloatRect().size;
    return side + (coverRight + PlaybackPage.LYRIC_META_GAP_VP - side) * t;
  }

  /**
   * @returns 閸忓啩淇婇幁顖濐攽閸?*閸╁搫鍣惄?*闁插瞼娈戞担宥囆╅敍鍧磒閿涘鈧柡鈧?鐎佃鐖ｉ弮鐘垫櫕 `floatingMeta` 閸愬懎鐪伴柇锝嗘蒋
   *   `.offset({ y: metaOffsetYAt(swiperProgress) })`閿涘潉wujie.pa:195907-196008`閿涘鈧?
   *
   * ## 娑撹桨绮堟稊鍫ｎ洣閸戝繑甯€"鐏炲懍鑵戞担宥囩枂"
   * 閺冪姷鏅柇锝勮⒈鐏炲倹妲?*閸掑棗浼?*閻ㄥ嫸绱?
   * ```
   *   婢舵牕鐪?Column().width('100%').height(overlayBaseH()).justifyContent(FlexAlign.Center)
   *        閳?閹跺﹤鐡欓崘鍛啇閸忓牊鎲滈崚鏉跨唨閸戝棛娲呴惃?*缁旀牜娲挎稉顓炵妇**
   *   閸愬懎鐪?Column().offset({ y: metaOffsetYAt(t) })
   *        閳?閸欘亣銆冩潏?閻╃顕柇锝勯嚋鐏炲懍鑵戞担宥囩枂閻ㄥ嫬浜哥粔?
   * ```
   * 閹存垳婊戞潻娆愭蒋 `.offset()` 闁插本鏂侀惃鍕箑妞ょ粯妲?*閸氬奔绔存稉顏堝櫤缁?* 閳?
   * ```
   *   metaOffsetY() = metaTopGeomY(t, rowH) 閳?(閸╁搫鍣惄鎺楃彯 閳?rowH) / 2
   *                                         閳规柡鏀㈤埞鈧埞鈧埞鈧?鐏炲懍鑵戦崥搴ゎ攽妞ゆ儼绔熼惄绋款嚠閻╂帡銆婇惃鍕秴缂?閳光偓閳光偓閳光偓閳光偓閳?
   * ```
   * 閳?鐞涘矂銆婃潏瑙勬付缂佸牐鎯ら崷?`metaTopGeomY(t, rowH)`閿涘奔绗屾稉濠佺閻楀牓鍋呴弶?
   *   `.position({ y: metaTopGeomY(...) })` **闁劕鍎氱槐鐘电搼娴?*閿涘牊宕查惃鍕Ц缂佹挻鐎稉搴″經瀵板嫸绱濇稉宥嗘Ц閺佹澘鈧》绱氶妴?
   *
   * 閳跨媴绗?**娑撳秷顔忛崘宥勭 `1/morphScale`**閿涙瓪metaTopGeomY` 閻ㄥ嫪琚辨稉顏嗩伂閻愬綊鍏橀弰?鐎圭懓娅掗幁鎺旂搼閺?閻ㄥ嫬鍤戞担鏇礉
   *   瀹歌尙绮￠弰顖炪€夐崘?缁愭褰涢崥灞肩婵傛娼楅弽鍥风幢娑旀ü绨＄亸鍙樼窗闁插秶骞囬悽銊﹀煕鐎圭偞绁撮惃鍕┾偓?*閸忓牓顥ｉ柅鐔碱棧閸掓澘鐨濋棃顫礉閻掕泛鎮楅崘宥勭瑓閺?*閵嗗秲鈧?
   * 閳跨媴绗?閸╁搫鍣惄鎺楃彯閻?`estBoxHVp()`閿? 閸欘垳鏁ゆ?閳?閹貉冨煑閸栫尨绱濇稉搴㈡￥閻?`overlayBaseH()` 閸氬奔绠熼敍澶堚偓?
   *   鐎瑰啳绻曞▽锟犲櫤閸掔増妞傛稉?0 閳ユ柡鈧?娑撳娼伴悽?`(baseH 閳?rowH)/2` 閻╁瓨甯寸粻妤嬬礉0 娑旂喕鍤滃ú鏂ょ礄娑撳秳绱?NaN閿涘鈧?
   */
  private metaOffsetY(): number {
    const rowH: number = PlaybackPage.LYRIC_META_ROW_H_VP;
    const baseH: number = this.expandState.estBoxHVp();
    const centeredTop: number = (baseH - rowH) / 2;
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф棤鐣岋細浣嶇Щ鍙湁涓€鏉?`metaOffsetYAt(t)`锛屾病鏈変换浣曢挸鍒?*锛?
    //
    // 鏈疆鎶婁笂娓搁偅涓夊眰鍏ㄩ儴浠庡瓧鑺傜爜閲屽彇浜嗗嚭鏉ワ紝閫愭潯瀵归綈锛?
    // ```
    //   floatingMeta锛圠171797-171846锛屽睘鎬?L195907-196008锛?
    //     Column().width('100%').height(this.overlayBaseH())
    //             .justifyContent(FlexAlign.Center).hitTestBehavior(Transparent)
    //       Column().width('100%').alignItems(Start)
    //               .offset({ y: this.morph.metaOffsetYAt(this.swiperProgress) })
    //         metaRow()
    //   overlayBaseH()锛圥layerPage锛? swiperBoxH > 0 ? swiperBoxH
    //                                : (!chromeHidden && swiperProgress <= 0.001 ? 0 : estBoxH())
    //   metaOffsetYAt(t)锛圕overMorph锛? lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
    // ```
    // 鈬?涓婃父**娌℃湁浠讳綍"鍒帇杩涙帶鍒跺尯"鐨勯挸鍒?*锛氫綅缃畬鍏ㄧ敱閭ｄ竴鏉?lerp + 灞呬腑鐩掑喅瀹氥€?
    //   鎴戝墠鍑犵増鍔犵殑閽冲埗锛堝拰鐢ㄥ疄娴?chromeTop 鐨勭増鏈級閮芥槸**鎴戣嚜鍒涚殑**锛?
    //   鐢ㄦ埛瀹炴祴銆屾敼寰椾笉瀵癸紝姣斾箣鍓嶈繕宸€嶁€斺€旀挙鍥烇紝鎭㈠绾嚑浣曘€?
    //   鈿狅笍 瑙夊緱"鍘嬩綇杩涘害鏉?鏃讹紝瑕佸姩鐨勬槸**灏侀潰绔偣 / gap(50) / 鎺у埗鍖洪绠?*杩欎笁鑰呬箣涓€锛?
    //     涓嶆槸鍦ㄦ瓕鍚嶈涓婂姞绗簩涓綅绉绘簮銆?
    const absTop: number = this.expandState.metaTopGeomY(this.lyricMorphT, rowH);
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
  /** 閺€鎯版崳閹礁鍞寸€圭懓鐪伴崡鐘电崶閸欙綁鐝惔锔炬畱閻ф儳鍨庡В鏃撶窗鐠愭潙绨虫稉鈧弶鈽呯礉婢堆嗗毀缁涘绨潻铚傜稑閺夛繝鍋呮稉鈧弶掳鈧?*/
  private static readonly COLLAPSED_HEIGHT_PERCENT: number = 9;
  /** 鐏炴洖绱戦崝銊ф暰閻ㄥ嫯鎹ｉ悙纭呯箻鎼达讣绱? 鐎瑰苯鍙忛弨鎯版崳閿涘鈧?*/
  private static readonly EXPAND_START_PROGRESS: number = 100;
  /** 鐏炴洖绱?閺€鎯版崳閸斻劎鏁鹃弮鍫曟毐閿涘潰s閿涘绱濇稉搴″棘閼板啫浼愮粙?`OPEN_PLAYER_UI_ANIMATION_MS` 娑撯偓閼锋番鈧?*/
  private static readonly EXPAND_DURATION_MS: number = 380;
  /**
   * 鐎圭懓娅掕ぐ銏犲綁鐏炴洖绱戦惃鍕闂€鍖＄礄ms閿涘鈧?
   *
   * 閺冪姷鏅?Tokens 閻ㄥ嫪瀵屾潪顒€婧€濡楋絼缍呴弰?300ms / 420ms閿涙稖绻栭柌灞藉絿 420ms 闁絾銆傞惃鍕潎閹扮噦绱欓弫鎾€夐崷銊х級閺€鎾呯礉
   * 濮ｆ柨鐪柈銊ュ帗缁辩姵宕叉担宥夋付鐟曚焦娲挎径姘闂傝揪绱氶敍灞炬锤缁捐法鏁ょ€瑰啰娈?`cubic-bezier(0.23, 1.0, 0.32, 1.0)`閿涘牆鎻╅崙铏圭处閸忋儻绱氶妴?
   */
  private static readonly MORPH_OPEN_DURATION_MS: number = 350;
  /**
   * 鐎圭懓娅掕ぐ銏犲綁閺€鎯版崳閿涘牆寮介崥鎴礆閻ㄥ嫭妞傞梹鍖＄礄ms閿涘绱板В鏂跨潔瀵偓閻ｃ儱鎻╅敍灞炬暪鐠ч攱娼电憰浣稿叡閼村棎鈧?
   */
  /**
   * 閸忔娊妫撮敍鍫濆冀閸氭垵鑸伴崣姗堢礆閻?*閸╄櫣顢呴弮鍫曟毐**娑?*閺冨爼鏆辨稉瀣濮ｆ柧绶?*閿涘牆顕弽鍥ㄦ￥閻?`MainPage` 閻ㄥ嫪琚辨稉顏勭埗闁插骏绱氶妴?
   *
   * 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱濇穱顔衡偓灞藉彠闂傤厽鎸遍弨鎯ф珤閸戠姳绠▽鈥冲З閻㈡眹鈧稄绱氶敍?
   *   `reverseMs = round(REVERSE_MS 鑴?max(REVERSE_MIN_RATIO, morphT))`
   *   閿涘潉_recover/logic-src/瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md` 鎼? 闁喐鐓?L29 / 鎼傞崗?鐢悂鍣虹悰?L620-625閿涘鈧?
   *   閳?濠娾€崇潔瀵偓閺?**460ms**閿涙稑褰ч幏澶婄磻娑撯偓閻愬湱鍋ｉ敍鍧刴orphT < 0.4`閿涘妞傞幐澶夌瑓闂?**460鑴?.4 = 184ms**閵?
   *
   * 閳跨媴绗?鐞氼偅娴涢幑銏″竴閻ㄥ嫭妫敮鎼佸櫤 `MORPH_CLOSE_DURATION_MS = 350` 閺堝琚辨径鍕晩閿涘牓鍏樻稉宥嗘Ц"閺佹澘鈧厧浜曠拫?閿涘绱?
   *   閳?**閺冨爼鏆遍崑蹇曠叚**閿?50 vs 閺冪姷鏅鈥崇潔瀵偓 460閿涘苯鐨禍?24% 閻ㄥ嫯顢戠粙瀣闂傝揪绱?
   *   閳?閺囩顩﹂崨鐣屾畱閺?*缂傛挸濮╅弫瀛樻蒋閹跺嫰鏁?*閿涙碍妫禒锝囩垳閻?`cubicBezier(0.23, 1.0, 0.32, 1.0)`
   *      閿? `EASE_OUT_STR`閿涘矂鍋呴弰?*閹垫挸绱戦幓鎰唉**閻劎娈戦弴鑼殠閿涘绱濈€?*閸?15% 閺冨爼妫跨亸杈泲鐎瑰瞼瀹?70% 鐞涘瞼鈻?*
   *      閳?350ms 闁插瞼瀹?50ms 鐏忚京缂夌€瑰被鈧礁澧挎稉?300ms 閸戠姳绠棃娆愵剾 = 閻劍鍩涚拠瀵告畱"**閸戠姳绠▽鈥冲З閻?*"閵?
   *   閺冪姷鏅?閸忔娊妫撮幓鎰唉"閻劎娈戦弰?**`REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`**閿涘牊鍙冮崥顖氬З閿涘鈧?
   *   鐎瑰本鏆ｇ€靛湱鍙庢稉?閸掝偅鎮跺ǎ铚傜瑏婢跺嫮绱﹂崝?閻ㄥ嫯顕╅弰搴″晸閸?`closeFullScreenPlayback()` 闁插被鈧?
   */
  private static readonly REVERSE_MS: number = 460;

  /**
   * `page 0` 鐏忓繑鐡曠拠宥囨祲鐎靛綊銆夋惔鏇犳畱**娑撳甯囬柌?*閿涘澊p閿涘鈧?
   *
   * 閳藉應妲?2026-10-15閿涘牅鎱ㄩ悽銊﹀煕鐎圭偞绁撮妴灞炬尡閺€鍓ф櫕闂堛垼绻栭柌宀勬晩娴ｅ秲鈧稄绱氶敍姘愁潌 `MiniLyricLinesComponent` 闁絽顦╃拫鍐暏閻愬湱娈戝▔銊╁櫞 閳ユ柡鈧?
   *   鐏忓繑鐡曠拠宥呭斧閺夈儴鍒涙い闈涚俺閿涘本顒滄總鍊熸儰閸?`Swiper` 娑斿顦婚柇锝嗘蒋**濮濆苯鎮?濮濆本澧滅憰鍡欐磰鐏?*閻ㄥ嫰鐝惔锕€鐢柌宀嬬礄閳?60~690vp閿涘鈧?
   *   閸欐牕鈧?= `PlayerExpandState` 闁插本鐡曢崥宥呮健閻ㄥ嫰鐝惔锕€褰涘鍕剁礄`LYRIC_META_BLOCK_H_VP = 44`閿涘绱?
   *   閹恒劌绱?娑撱倛顢戦弬鍥х摟"闁絼绠炴径姘祮閸欘垽绱遍棃娆愵剾閹礁鐣犻崣顏呮Ц娑撯偓娑擃亜娴愮€规矮缍呯粔浼欑礉**娑撳秴寮稉搴濇崲娴ｆ洝藟闂?*閵?
   */
  private static readonly MINI_LYRIC_SINK_VP: number = 44;

  /** 鐏忓繑鐡曠拠宥咁啇閸ｃ劎娈戠紒鍕 id閿涘牆褰х紒?{@link PlaybackPage.logLayoutBoxes} 闁插繑绁撮悽顭掔礉娑撳秴寮稉搴濇崲娴ｆ洟鈧槒绶敍澶堚偓?*/
  private static readonly MINI_LYRIC_BOX_ID: string = 'rzd_page0_mini_lyric_box';

  /** 缂冩垶鐗搁懗灞炬珯鐏炲倻娈戠紒鍕 id閿涘牆褰х紒?{@link PlaybackPage.logBgLayer} 闁插繑绁撮悽顭掔礆閵?*/
  private static readonly MESH_BG_ID: string = 'rzd_mesh_bg_layer';

  /**
   * 閳藉應妲勯埥?2026-10-16閿?*GLM5.3 娴兼俺鐦栭崣鎴犲箛閿涙碍鍨滄稉濠佺鏉烆噣鍋呴柆鎾绘，閺?濮濆妫?**閿?
   *
   * ## 娴滃鏅犵紒蹇氱箖閿涘牆顩х€圭偠顔囬敍灞藉焼閸愬秶濮遍敍?
   * 閹存垹绮伴崘鍛啇鐏?`.onAppear()` 閻ㄥ嫬鍘规惔鏇炲瀻閺€顖氬鏉╁洣绔撮柆?鐠恒劌鐤勬笟瀣闂傚鐛?闂傤煉绱濋崚銈嗗祦閸愭瑧娈戦弰?
   * `PlaybackPage.lastCloseAtMs > 0 && Date.now() - PlaybackPage.lastCloseAtMs < CLOSE_WINDOW_MS`閵?
   * GLM 閹稿洤鍤敍?*閺佺繝鍞ら崗鎶芥４娴狅絿鐖滈柌灞剧梾閺堝鎹㈡担鏇氱鐞涘苯鍟?`lastCloseAtMs`閿涘矁鈧?`CLOSE_WINDOW_MS` 娑旂喍绮犻張顏勶紣閺?*
   * 閳?闁綁浜鹃梻?*閹帒浜?*閿涘瞼鐡戞禍搴濈矆娑斿牓鍏樺▽鈥冲閵嗗倹鍨滈弻銉ㄧ槈娴滃棙妞傞梻瀵稿殠閿涙岸鍋呮禒钘変紣娴ｆ粌灏紓鏍帆閿?3:54閿?
   *   **閺呮矮绨張鈧崥搴濈濞嗏剝鍨氶崝鐔哥€鐚寸礄23:49閿?* 閳?**鐎瑰啩绮犻張顏囶潶缂傛牞鐦ф潻?*閿涘瞼鏁ら幋鐤棅閸掓壆娈戦崠鍛村櫡閺嶈婀板▽鈩冩箒鐎瑰啨鈧?
   * 閳?閺佹瑨顔勯敍?*閺€閫涚啊濠ф劗鐖滆箛鍛淬€忚ぐ鎾虫簚閺嬪嫬缂?*閿?閹存垵濮炴禍鍡涙，"娑?闂傘劌婀禍褏澧块柌?閺勵垯琚辨禒鏈电皑閵?
   *
   * ## 娑撹桨绮堟稊鍫ユ付鐟?鐠恒劌鐤勬笟?閻ㄥ嫬鍨介幑?
   * 閺堫剟銆夐幍鈧張?`@Local` / 缁変焦婀佺€涙顔岄柈鑺ユЦ**鐎圭偘绶ョ仦鈧柈?*閻ㄥ嫸绱遍懓?`morphReset()` 娴兼碍濡?
   * `PlayerExpandState` 闁插矂鍋呮總妤嬬礄`morphSessionStarted` / `morphStage` / `morphGeomReady`閿涘鍙忓〒鍛竴閵?
   * 閳?閸忔娊妫存担娆愬皾閽€钘夋躬**閺傛澘鐤勬笟?*闊偂绗傞弮璁圭礉鐎圭偘绶ョ仦鈧柈銊ф畱闂傘劌鍙忛柈銊ャ亼閺勫簺鈧?
   *   閸欘亣鍏橀悽銊ょ娑?*鐠恒劌鐤勬笟瀣彙娴?*閻ㄥ嫭妞傞崚璇蹭粵閸掋倖宓?閳?閺堫剟娼ら幀浣哥摟濞堢偣鈧?
   *
   * 閳跨媴绗?**娑撱倓閲滅€涙顔岃箛鍛淬€忛幋鎰嚠娴ｈ法鏁?*閿涙瓪lastCloseAtMs` 閻?*閸忔娊妫撮柧鎹愮熅**閸?
   *    閿涘潉closeFullScreenPlayback` 閸忋儱褰涢敍澶涚礉`CLOSE_WINDOW_MS` 閸欘亜婀銈咁槱瑜版挾鐛ラ崣锝咁啍鎼达负鈧?
   *    閸掝偄鍟€閸戣櫣骞?閸欘亣顕版稉宥呭晸"閿涘牓鍋呭锝嗘Ц娑撳﹣绔存潪顔炬畱娴滃鏅犻敍澶堚偓?
   */
  private static lastCloseAtMs: number = 0;

  /**
   * 閳?2026-10-17閿涙矮绗傛稉鈧▎鈥冲彠闂?*鐠ч绨￠柅鈧崠鏍熅瀵?*閻ㄥ嫬甯崶鐙呯礄閻厽鐖ｇ粵鎾呯幢缁?= 濞屄よ泲闁偓閸栨牭绱氶妴?
   *
   * 閻?`closeLiveMorphFallback()` 閸愭瑣鈧梗closeFullScreenPlayback()` 閻?`ev('CLO', 閳?` 鐠囪鑻?*濞撳懐鈹?*
   * 閳?瀵拌姤鐖ｇ粭顒€宕勬稉澶庮攽閻?`CLO:閳?fb=<閸樼喎娲?` 鐏忚鲸妲?鏉╂瑦顐兼潻鏂挎礀閸忔娊妫寸挧鎵畱閺勵垰鎻╅悡褑绻曢弰顖涙た妞?閻ㄥ嫮娲块幒銉嚢閺佽埇鈧?
   * 閳跨媴绗?閸欘亜婀?闁偓閸栨牠鍋呮稉鈧▎?閺堝鈧》绱濈拠璇茬暚閸楄櫕绔婚敍鍫濇儊閸掓瑤绱扮悮顐㈢秼閹存劕鐖舵す鑽ゅЦ閹緤绱氶妴?
   */
  private static closeFallbackReason: string = '';

  /**
   * 閳藉應妲勯埥?2026-10-16閿?*閸忔娊妫存潻鍥┾柤閻ㄥ嫭妞傛惔?姒涙垵灏堢€?** 閳ユ柡鈧?閹垫挾鐗?濞屸剝婀佺拋鎯ь槵鐠囩粯鏆?閻ㄥ嫬鍏婄仦鈧敍?
   *
   * ## 娑撹桨绮堟稊鍫濈箑妞よ浠涢幋?鐠恒劌鐤勬笟瀣饯閹線鏀ｇ€?
   * 閻劍鍩涢幎銉ф畱娑撱倖娼敍鍫涒偓灞藉彠闂傤厽妞傞懗灞炬珯閸欘亜澧挎稉鈧弶掳鈧秲鈧苯鍙ч梻顓炴倵閸欏牊鏂佹稉鈧柆宥呯潔瀵偓閵嗗稄绱?*闁棄褰傞悽鐔锋躬閸忔娊妫存潻鍥┾柤娑?*閿?
   * 閼?*閹绢厽鏂佹い鍏哥 pop閿涘苯鐫嗘稉濠囧亝娑擃亜绐橀弽鍥ф皑鐠虹喓娼冨▽鈥茬啊** 閳?娴滃鎮楃拠璁崇瑝閸掗鎹㈡担鏇氱鐟楄￥鈧?
   * 閳?閹跺﹤鍙ч柨顔荤皑娴犳儼顔囨潻?*濡€虫健缁狙囨饯閹胶骞嗚ぐ銏㈢处閸?*閿涘瞼鐡?*娑撳绔村▎鈩冨ⅵ瀵偓閹绢厽鏂佹い?*閸愬秵妯夌粈?閳?鐏忚鲸婀佹禍?娑撳﹣绔村▎鈥冲彠闂?閻ㄥ嫬鐣弫瀛樻鎼村繈鈧?
   *
   * ## 鐠侀绮堟稊鍫礄閸欘亣顔?閻樿埖鈧浇娴嗙粔?娑?閸忔娊鏁崙鍝勫經"閿?*娑撳秷顔囧В蹇撴姎**閿涘苯鎯侀崚娆戝箚瑜般垻绱﹂崘韫窗鐞氼偄鍩涢幒澶涚礆
   * ```
   *   CLO  = closeFullScreenPlayback 閸忋儱褰涢敍鍫濆晸娑?lastCloseAtMs閿?
   *   LV   = morphBeginLeaving閿涘牊鏁圭挧椋庢祲娴ｅ稄绱?
   *   SET  = 閸忔娊妫撮弨璺虹啲鐎规碍妞傞崳銊ュ煂閻愮櫢绱欓梽?closeGen / alive / 鐠ч绨￠崫顏冪閺€顖ょ礆
   *   LND  = morphLand閿涘牐鎯ら崶鐐剁碃娴ｇ姵娼敍?
   *   SQZ  = squashLandAnim閿涘牊灏嬮崢瀣崳閿?
   *   RST  = morphReset閿涘牆鍤戞担鏇炴礀閹帞鐡戦敍?
   *   POPT = 婢瑰啿鐪伴幎?isShowPlay 缂?false閿涘牐袝閸?popPlayerRoute閿?
   *   REM  = 婢瑰啿鐪伴惇鐔烘畱閹跺﹥鎸遍弨楣冦€夌捄顖滄暠閸掔姵甯€娴滃棴绱檂popPlayerRoute` 闁插瞼娈?`pop/removeByIndexes`閿?
   *          閳?**`RST` 娑?`REM` 閻?`t+` 瀹?*鐏忚鲸妲?濠娾€崇潌娑擃參妫块幀?閺堝顦块梹鍖＄礄閻劍鍩涚粭?閳?閺夛紕娈戦崚銈嗗祦閿?
   *   DIS  = 閸愬懎顔愮仦?onDisappear閿涘牓妾?wasAlive閿?
   *   AP   = 閸愬懎顔愮仦?onAppear閿涘牓妾挧棰佺啊閸濐亝娼崚鍡樻暜閿?
   *   INTR = playExpandIntro 鐠у嚖绱?*閼汇儱鍤悳鏉挎躬閸忔娊妫存稊瀣倵閿涘苯姘ㄩ弰?閸欏牊鏂佹稉鈧柆宥呯潔瀵偓"閻ㄥ嫮娲块幒銉ㄧ槈閹?*閿?
   *   OPN  = 婢瑰啿鐪?isShowPlay=true閿涘牐袝閸?pushPlayerRoute閿?
   * ```
   * 濮ｅ繘銆嶇敮锔跨娑擃亞娴夌€佃妞傞梻杈剧礄ms閿涘瞼娴夌€靛湱绱﹂崘鎻掑隘闁插瞼顑囨稉鈧弶鈽呯礆閵?
   *
   * ## 鐠囩粯纭堕敍鍫濈獦閺?*缁楊剙宕勬稉澶庮攽**閿?
   * 缂傛挸鍟块崠?*娴犮儰绔村▎鈥冲彠闂傤厺璐熼崡鏇氱秴**閿涘潉CLO` 娑撯偓閸掓澘姘ㄥ〒鍛敄闁插秵娼甸敍澶涚礉閹碘偓娴犮儴顕伴崚鎵畱濮樻瓕绻欓弰?閺堚偓鏉╂垳绔村▎鈥冲彠闂?閻ㄥ嫬鍙忔潻鍥┾柤閿?
   * 濮濓絽鐖堕崗鎶芥４閸氬酣鍣搁弬鐗堝ⅵ瀵偓閿涘苯绨茶ぐ鎾舵箙閸掓澘鑸版俊鍌︾窗
   * ```
   *   t0 CLO 閳?t+2 LV 閳?t+480 SET:ok/gen=3 閳?t+481 LND 閳?t+482 SQZ 閳?t+483 RST 閳?t+484 POPT 閳?t+490 DIS:alive=0
   * ```
   * 瀵倸鐖惰ぐ銏㈠Ц娑撳骸鎯堟稊澶涚窗
   * - 閸戣櫣骞?**`INTR`**閿涘牆婀?DIS 娑斿鎮楅敍澶嗗櫩 绾喛顓婚弰?閸忔娊妫存担娆愬皾闁插秵鏂佺仦鏇炵磻"閿?
   * - 閸戣櫣骞?**`OPN`**閿涘牆婀崗鎶芥４濞堝吀绠ｉ崥搴礉閼板瞼鏁ら幋宄拌嫙濞岋紕鍋ｅ鈧敍澶嗗櫩 婢瑰啿鐪伴幎濠冩尡閺€楣冦€夐崣鍫熷腹娴滃棔绔村▎鈽呯幢
   * - `SET:genBAD` / `SET:dead` 閳?閺€璺虹啲鐎规碍妞傞崳銊ㄨ泲娴滃棙妫柅鈧弨顖ょ礄**閸戠姳缍嶆稉宥勭窗婢跺秳缍?* 閳?閼冲本娅欓崣顏勫⒖娑撯偓閺夆€虫倱濠ф劧绱氶敍?
   * - **濞屸剝婀?`RST`** 閳?`morphReset()` 濞屸剝澧界悰?閳?閸戠姳缍嶉崑婊冩躬娑擃參妫块幀渚婄幢
   * - `RST` 閸?`REM`閿涘牐鐭鹃悽杈╂埂鐞氼偄鍨归幒澶涚礆**娑斿澧犵搾鍛扮箖娑撯偓鐢?* 閳?鐎涙ê婀?pop 娴滃棔绲鹃崙鐘辩秿瀹歌尙绮″鈥崇潌"閻ㄥ嫪鑵戦梻鏉戞姎
   *   閿涘湙LM 閻ㄥ嫬浜ｇ拋鎾呯礉鎼?23.3 閳ユ柡鈧?娑旂喎姘ㄩ弰顖滄暏閹撮顑?閳?閺夛紕娈戦崐娆撯偓澶嬫簚閸掕绱氶妴?
   */
  private static evLog: string = '';
  private static evT0: number = 0;
  private static evCount: number = 0;

  /**
   * 鐠侀绔撮弶鈩冩鎼村繋绨ㄦ禒璁圭礄鐟?{@link PlaybackPage.evLog}閿涘鈧?
   * @param tag 娴滃娆㈤崥宥忕礄娑撳﹪娼伴柇锝呯炊鐞涖劑鍣烽惃鍕叚閺嶅洨顒烽敍?
   * @param detail 閸欘垶鈧娈戠悰銉ュ帠閿涘牅绶ユ俊?`ok` / `genBAD` / `dead`閿?
   *
   * 閳跨媴绗?**public static**閿涘牅绗夐弰?private閿涘绱版竟鍐茬湴 `products/default/.../pages/Index.ets` 閻?
   *    `@Monitor('appState.isShowPlay')` 闁插矁顩︾拋?`OPN` 閳ユ柡鈧?閵嗗苯鍙ч梻顓炴倵閸欏牊鏂佹稉鈧柆宥呯潔瀵偓閵嗗秶娈?
   *    婢舵潙褰跨€氬瞼鏋掔亸杈ㄦЦ**婢瑰啿鐪伴幎濠冩尡閺€楣冦€夐崣鍫熷腹娴滃棔绔村▎?*閿涘矂鍋呮稉鈧粭鏂垮涧閺堝锛撶仦鍌濆厴鐠佽埇鈧?
   *    閿涘牆锛撶仦?閳?閹绢厽鏂佹い鍨Ц閸楁洖鎮滄笟婵婄閿涙瓪player` 閻ㄥ嫭銆婇弬鍥︽瀹歌尙绮＄€电厧鍤?`PlaybackPage`閿涘奔绗夐弸鍕灇瀵邦亞骞嗛妴鍌︾礆
   */
  public static ev(tag: string, detail: string = ''): void {
    const now: number = Date.now();
    // 閳?缂傛挸鍟块崠杞颁簰**娑撯偓濞嗏€冲彠闂?*娑撳搫宕熸担宥忕窗`CLO`閿涘牆鍙ч梻顓㈡懠鐠侯垰鍙嗛崣锝忕礆娑撯偓閸掓澘姘ㄩ幎濠佺瑐娑撯偓鏉烆喗鏆ｅ▓鍨閹哄鈧梗t0` 闁插秶鐤嗛崚鎷岀箹娑撯偓閸掓眹鈧?
    //   娑撹桨绮堟稊鍫ｇ箹閺嶅嘲鍨忛敍姘獦閺嶅洦妲?*缁涘绗呮稉鈧▎鈩冨ⅵ瀵偓閹绢厽鏂佹い?*閹靛秵妯夌粈铏规畱閿涘牆鍙ч梻顓⑩偓鏂捐厬妞ょ敻娼板鑼病鐞?pop閿涘绱?
    //   閼汇儰绗夊〒鍜冪礉鐠囪鍩岄惃鍕Ц"婵傝棄鍤戞潪顔借穿閸︺劋绔寸挧?閻ㄥ嫭妫╄箛妤嬬礉`t+` 娑旂喍绱版稉鈧惄鏉戠窔娑撳﹥瀹氶崚鎵箙娑撳秴鍤惄绋款嚠閺冭泛绨妴?
    //   閸掑洦鍨?閺堚偓鏉╂垳绔村▎鈥冲彠闂?娑斿鎮楅敍宀冾嚢濞夋洖姘ㄩ崶鍝勭暰閹?`t+0 CLO 閳?閳ヮ泦閵?
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
    // 閻滎垰鑸伴敍姘崇Т鏉?900 鐎涙顑佺亸杈╃埆閹哄娓堕弮鈺呭亝濞堢绱欐穱婵呯秶"閺堚偓鏉╂垹娈戦崗鎶芥４閸忋劏绻冪粙?閿?
    if (PlaybackPage.evLog.length > 900) {
      const cut: number = PlaybackPage.evLog.indexOf('|');
      if (cut >= 0) {
        PlaybackPage.evLog = PlaybackPage.evLog.substring(cut + 1);
      }
    }
  }

  /** 閸忔娊妫存担娆愬皾缁愭褰涢敍鍧閿涘鈧柡鈧?`lastCloseAtMs` 閻ㄥ嫬顔旀惔锔衡偓鍌楁閿?瀹搞儳鈻奸崚銈嗘焽閸婄》绱濇稉宥嗘Ц闁棗鎮滈崐纭风礄鐟欎椒绗傞弬纭咁嚛閺勫函绱氶妴?*/
  private static readonly CLOSE_WINDOW_MS: number = 1500;

  /**
   * `scheduleMorphResetAfterPop()` 閻ㄥ嫯鐤嗙拠銏ゆ？闂呮棑绱檓s閿涘绗岄張鈧径褎顐奸弫鑸偓?
   *
   * 閳跨媴绗?**瀹搞儳鈻奸崚銈嗘焽閸婄》绱濇稉宥嗘Ц闁棗鎮滈崐?*閿涙碍妫ら悾灞剧梾閺堝绻栭弶?缁?pop 閸愬秴顦叉担?閻ㄥ嫭妯夊蹇氱枂鐠?
   * 閿涘牆鐣犻惃鍕€夐棃銏℃Ц濡剝鈧緤绱濋弨鎯版崳鐎瑰本鍨氶崡鍐插祻鏉炴枻绱氶妴鍌濈箹闁插苯褰ч弰顖氭礈娑撶儤鍨滄禒顒傛畱鐠侯垳鏁?pop 閺?*瀵倹顒?*閻ㄥ嫨鈧?
   * 32ms 閳?娑撱倕鎶氶敍? 濞?閳?256ms 娑撳﹪妾洪敍鍫ｇТ閺冭泛鍘规惔鏇烆槻娴ｅ稄绱濈€逛礁褰查弲姘瘍娑撳秷鍏樻稉宥嗙閿涘鈧?
   */
  private static readonly RESET_POLL_MS: number = 32;
  private static readonly RESET_POLL_MAX: number = 8;

  /** 娑撳﹣绔村▎?`RzdBgLayer` 閻ㄥ嫮顒烽崥宥忕礄閼哄倹绁﹂敍澶堚偓?*/
  private lastBgLayerLog: string = '';

  /**
   * 閳藉應妲勯埥?2026-10-16 閺傛澘顤冪拠濠冩焽閿?*閼冲本娅欑仦鍌氬煂鎼存洘妲告径姘亣閵嗕礁顦挎稉宥夆偓蹇旀**閵?
   *
   * ## 鐎瑰啫鍨芥禒鈧稊鍫礄閻劍鍩涢崣宥咁槻閹躲儳娈戞稉銈嗘蒋闁粙娼€瑰啫鐣鹃幀褝绱?
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdBgLayer'
   *   閳?RzdBgLayer box=(x,y,w,h) win=WxH clip=閳?p=閳?op=閳?squashing=閳?meshSrc=yes|no playing=閳?
   * ```
   *
   * | 鐠囪鍩岄惃?| 閸氼偂绠?|
   * | --- | --- |
   * | `box.w/h 閳?win` **娑?`op 閳?1`** | 閼冲本娅欓弫鏉戠潌娑撳秹鈧繑妲?閳?鏉╂瑦澧犻弰顖樷偓?*閼冲本娅欓崗銊ョ潌**閵嗗秶娈戣ぐ銏㈠Ц |
   * | `box.w/h 閳?win` 娴?`op` 瀵板牆鐨敍?.04~0.3閿?| 閼冲本娅欓弫鏉戠潌娴ｅ棗鍤戞稊搴ㄢ偓蹇旀 閳?**娑撳孩妫ら悾灞芥倱瑜?*閿涘牊妫ら悾宀勫亝鐏炲倷绡冮崷銊﹀姬鐏炲繐鐪伴柌宀嬬礆 |
   * | `box.w/h` 閺勫孩妯夌亸蹇庣艾 `win` | 閼冲本娅欑悮顐︽閸掕泛婀亸蹇曠崶閸欙綁鍣烽敍鍫濆綗娑撯偓缁夊秴鑸伴悩璁圭礆 |
   * | `meshSrc=no` | 缂冩垶鐗稿▽鈩冪爱 閳?鐏炲繋绗傞弰?*閸忔粌绨抽崣鏍ㄧ壉閼?*閿涘牆婀痪鎸庣摃閺囨煡鍋呯仦鍌涙Ц `rgba(20,20,22,0.5)`閿?|
   *
   * 閳跨媴绗?閸欘亣顕伴敍姘拱閺傝纭舵稉宥呭晸娴犺缍嶉悩鑸碘偓浣碘偓?
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
   * 閹貉冨煑閸?*娑撳顔岀紒鎾寸€?*閻ㄥ嫪琚遍弽鐟板窗娴ｅ秵娼敍鍫㈢矋娴?id閿涘苯褰х紒?{@link PlaybackPage.logLayoutBoxes} 闁插繑绁撮悽顭掔礆閵?
   *
   * 閸戝搫顦╅敍姘￥閻?overlay 閻?builder 閺嶆埊绱檂wujie.pa:190464` / `190497`閿涘鈧柡鈧?
   * ```
   *   Row().height(lerp(swiperGap(), 10, swiperProgress))   // 190464  閳?"Swiper 閳?鏉╂稑瀹抽弶?
   *   Row().height(chrome().gapScrub)                       // 190497  閳?"鏉╂稑瀹抽弶?閳?娴肩姾绶弶?
   * ```
   * 閳跨媴绗?鐎瑰啩婊?*娑撳秵妲?padding**閿涘本妲?*闂嗚泛鍞寸€?Row**閿涘潉Column` 闁插瞼娈戦弲顕€鈧艾鍘斿鐔诲Ν閻愮櫢绱氶垾鏂衡偓?
   *   閹碘偓娴?娑撳顔?閺?`[Swiper | gapSwiper 鐞?| gapScrub 鐞?| 鏉╂稑瀹抽弶?娴肩姾绶弶顡閵?
   * 閳跨媴绗?閺冪姷鏅柇锝勮⒈娴犵晫鏁ら惃鍕Ц `.height(lerp(...))`閿涘畭lerp` 缁楊兛绗佺€圭偛寮弰?`swiperProgress`閿?
   *   閹锋牗瀚块幍鎾崇磻/閸忔娊妫撮惃鍕箖缁嬪鑵戞潻娆庤⒈閺嶈娼导姘崇閻偓鐞涖儵妫块敍鍧刟=swiperGap, b=10`閿涘鈧?
   *   閹存垳婊戞潻娆庣娓氀勭梾閺?`swiperProgress` 鏉╂瑤閲滈柌蹇ョ礄閹存垳婊戦惃鍕潔瀵偓鏉╂稑瀹抽崣?`morphP`閿涘矁顕㈡稊澶夌瑝閸氬矉绱氶敍?
   *   閹碘偓娴?*闂堟瑦顒涢幀浣稿絿 `swiperGap()` 闁絼绔寸粩?*閿? `lerp(t=0)`閿涘绱濊ぐ銏犲綁閺堢喍绗夐崝?閳ユ柡鈧?鐟欎焦鏌熷▔鏇熸暈闁插鈧?
   */
  private static readonly SWIPER_GAP_ROW_ID: string = 'rzd_gap_swiper_row';
  private static readonly CHROME_SCRUB_GAP_ROW_ID: string = 'rzd_gap_scrub_row';

  /**
   * @returns 閵嗗wiper 閳?鏉╂稑瀹抽弶掳鈧秴宕版担宥嗘蒋閻ㄥ嫰鐝惔锔肩礄vp閿涘鈧柡鈧?閺冪姷鏅?`swiperGap()`閿涘潉wujie.pa:180127`閿涘鈧?
   *
   * ## 娑撹桨绮堟稊鍫ｇ箹闁插本妲?*娑撯偓娑擃亜鐖堕弫?*閵嗕椒绗夐弰?`lerp`
   *
   * 閺冪姷鏅崘娆戞畱閺?`lerp(swiperGap(), 10, swiperProgress)`閿涘苯宓?*閹锋牗瀚块幍鎾崇磻/閸忔娊妫存潻鍥┾柤娑?*鏉╂瑦鐗撮弶?
   * 娴?`swiperGap()` 閺€璺哄煂 10vp閵嗕繖swiperProgress` 閺?*鐎瑰啳鍤滃杈╂畱**娑撳濯烘潻娑樺闁插骏绱?閳? 鐎电懓绨查崗鎶芥４閸斻劋缍旈敍澶涚礉
   * 閹存垳婊戞潻娆庣娓氀冾嚠鎼存梻娈戦弰?`expandState.morphP`閿涘牆鐫嶅鈧潻娑樺閿?*閺傜懓鎮滄稉搴ｆ祲娴ｅ秹鍏樻稉宥呮倱**閿?
   * 閹存垳婊戦弰?娴犲氦绯犳担鐘虫蒋闂€鍨煂閺佹潙鐫?閿涘苯鐣犻弰?娴犲孩鏆ｇ仦蹇撶窔娑撳瀚嬬挧?閿涘鈧?
   * 閳?绾剙顨?`lerp(..., morphP)` 娴兼艾绶遍崚?*閸欏秶娴?*閻ㄥ嫭娲哥痪鍖＄礄鐏炴洖绱戦弮璺哄冀閼板本鏁圭粣鍕剁礆閿涘矂鍋呴弰?*閺備即鈧姳绔存稉顏囶攽娑?*閿?
   *   娑撳秵妲搁悡褎鎯夐妴鍌涘娴犮儵娼ゅ銏♀偓浣解偓浣解偓浣哥杽鐎圭偛褰?`lerp` 閻?`t=0` 闁絼绔寸粩顖ょ礄`swiperGap()`閿涘绱?
   *   楠炶埖濡?瑜般垹褰夐張鐔凰夐梻?閻ф槒顔囨稉鍝勭窡閸旂儑绱檂RzdMusic瀵板懐鈥樼拋銈嗙閸?md` D4-b閿涘鈧?
   */
  private swiperGapRowHVp(): number {
    return this.expandState.swiperGapVp();
  }

  /**
   * @returns 閵嗗矁绻樻惔锔芥蒋 閳?娴肩姾绶弶掳鈧秴宕版担宥嗘蒋閻?*妫版繂顦?*妤傛ê瀹抽敍鍧磒閿涘鈧?
   *
   * 閳跨媴绗?閹帊璐?0閿?*娑撳秵妲稿蹇撲粵**閿涙俺绻栨稉鈧▓鐢垫畱闂傜绐涢幋鎴滄粦**瀹歌尙绮￠張澶夌啊**閿涘奔缍呯純顔兼躬
   *   `ControlAreaComponent.bottomPanel()` 闁插矂鍋呮稉?`Column` 閻?`.margin({ bottom: 閳?})`
   *   閿涘牊瀵滈弬顓犲仯閸?`app.float.slider_margin_bottom*`閿涘鈧倹妫ら悾宀冦€冮柌宀冪箹娑撯偓濞堥潧褰?`gapScrub`
   *   閿涘湗ULL 28 / MEDIUM 20 / COMPACT 14閿涘鈧?
   * 閳?鏉╂瑩鍣锋穱婵堟殌娑撯偓娑?0 妤傛娈戦崣顖炲櫤濞村濡悙鐧哥礉**閸欘亙璐?*閹?鐎圭偞绁撮梻纾嬬獩 vs `gapScrub`"閹垫捁绻橀弮銉ョ箶
   *   閿涘潉RzdSwiperBox`閿涘绱濈粵澶屾埂閺堢儤鏆熼幑顔兼礀閺夈儱鍟€閸愬啿鐣鹃弰?閹?margin 閹广垺鍨?`gapScrub`"鏉╂ɑ妲?娣囨繄鏆€濞查箖鐓堕崢鐔封偓?閵?
   *   閻滄澘婀?*娑撳秴鑻熺悰灞藉**閿涘牆鎯侀崚娆忔皑閺勵垰鎮撴稉鈧▓鐢告？鐠烘繀琚遍弶鈥冲經瀵?閳ユ柡鈧?閺堫兛绮ㄩ崣宥咁槻闊晞绻冮惃鍕埌閻樿绱氶妴?
   */
  private chromeScrubGapRowHVp(): number {
    return 0;
  }

  /**
   * 閳?2026-10-15 鐠囧﹥鏌囬柨姘卞仯閿涙碍濡?*閸ユ稐閲滄导姘鞍閻╃甯囬惃鍕健**閻ㄥ嫮鐛ラ崣锝囩叐瑜邦澀绔村▎鈩冨ⅵ閸戠儤娼甸妴?
   *
   * 閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdBoxes'`
   *
   * 閹垫挾娈戦弰?*缁愭褰涢崸鎰垼**閿涘潉getPositionToWindowWithTransform()`閿涘绗?*鐎圭偞绁寸亸鍝勵嚟**閿?
   * 娑撳海鏁ら幋閿嬪焻閸ュ墽娈戦崓蹇曠閸欘垯浜掗惄瀛樺复閹广垻鐣荤€电澶勯敍鍫熸拱閺?1224鑴?776 閹搭亜娴?閳?3px/vp閿涘绱?
   * ```
   *   RzdBoxes cover=(x,y,w,h) title=(閳? singer=(閳? lyric=(閳?
   * ```
   * **閸掋倖宓侀敍鍫濇憿娑撱倓閲滈崸妤冩埂閻ㄥ嫮娴夋禍銈冣偓浣告皑閺€褰掑亝娑撯偓鐎电櫢绱?*閿?
   *   璺?`lyric.top` 閽€钘夋躬 `[singer.top, singer.bottom]` 閸栨椽妫块崘?閳?**鐏忓繑鐡曠拠宥呭竾閸︺劍鐡曢崥?濮濆本澧滈柇锝勭鐞涘奔绗?*
   *     閳?鐠?`MINI_LYRIC_SINK_VP`閿涘牊婀版禒鎾冲嚒閹?娑撱倛顢戦弬鍥х摟"閻ㄥ嫰鍣虹痪褏绮?44閿涘绱?
   *   璺?`lyric.bottom` 鐡掑﹨绻冮幒褍鍩楅崠娲€婃潏?閳?鐏忓繑鐡曠拠宥堫潶閹貉冨煑閸栧搫甯囨担?閳?闁絾妲搁崣锔跨婢跺嫸绱橲wiper 閺夊啴鍣搁崚鍡涘帳閿涘绱?
   *   璺?`cover.bottom` 娑?`title.top` 閻ㄥ嫰妫跨捄?閳?0 閳?濮濆苯鎮曠槐褑鍒涚亸渚€娼伴敍鍧凩YRIC_META_GAP_VP` 闁絼绔村锝忕礆閵?
   * 閳跨媴绗?閸欘亣顕伴妴浣风瑝閸愭瑱绱伴張顒佹煙濞夋洑绗夐弨鐟板綁娴犺缍嶉悩鑸碘偓渚婄礄娑撳秳绱拌ぐ銏″灇"闁插繑绁撮埆鎺撴暭閻樿埖鈧讲鍟嬮崘宥夊櫤濞?閻ㄥ嫭顒撮悳顖ょ礆閵?
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
    // 閳藉應妲勯埥?2026-10-17閿?*閵嗗本鐡曢崥宥堫攽閸樺婀潻娑樺閺夆€茬瑐閵嗗秶娈戦崣顖炲櫤濞村鍨介幑?*閿?
    //   `chromeTop` = `gapSwiper` 闁絾鐗撮崡鐘辩秴閺夛紕娈戠€圭偞绁寸粣妤€褰涙い鎯扮珶 = **閹貉冨煑閸栫儤顒滄稉濠冩煙**閿?
    //   `metaTop` = 濮濆苯鎮曠悰?*鐠佹崘顓搁崐?*閿涘潉metaTopGeomY`閿涘绱漙metaBoxTop` = 濮濆苯鎮曠悰?*鐎圭偞绁?*妞ゆ儼绔熼妴?
    //   閸掋倖宓侀敍姝歮etaBoxTop + LYRIC_META_ROW_H_VP > chromeTop` 閳?绾喖鐤勯崢瀣箻閹貉冨煑閸?
    //   閿涘牓鍋呴弮鎯邦嚉閸斻劎娈戦弰顖樷偓灞界殱闂堛垻顏悙?/ gap(50) / 閹貉冨煑閸栨椽顣╃粻妞尖偓宥堢箹娑撳鈧懍鑵戦惃鍕娑擃亷绱?
    //     **娑撳秷顩?*閸︺劍鐡曢崥宥堫攽娑撳﹤鍟€閸旂姾藟閸嬪じ缍呯粔?閳ユ柡鈧?闁絼绱伴幋鎰礋缁楊兛绨╂稉顏冪秴缁夌粯绨敍澶堚偓?
    //   閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdMetaChrome'`
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMetaChrome chromeTop=${this.boxTopY(PlaybackPage.SWIPER_GAP_ROW_ID).toFixed(1)} ` +
      `metaBoxTop=${this.boxTopY(PLAYER_META_TITLE_ID).toFixed(1)} ` +
      `metaTop=${this.expandState.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP).toFixed(1)} ` +
      `rowH=${PlaybackPage.LYRIC_META_ROW_H_VP} ` +
      `coverBottom=${(this.coverLocalRect().y + this.coverLocalRect().height).toFixed(1)} t=${this.lyricMorphT.toFixed(3)}`);

    // 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*閹貉冨煑閸栬桨绗佸▓鐢电波閺?*閻ㄥ嫬顕拹锔芥）韫囨ぜ鈧?
    //   閸掋倖宓侀敍鍫㈡埂閺堣桨绗傛稉鈧▎鈥虫皑婢剁噦绱氶敍姘杽濞?Swiper 妤傛ê瀹?vs `estBoxH()`閿? `usableH 閳?chromeTotal`閿涘绱?
    //   娴犮儱寮锋稉銈嗙壌閸楃姳缍呴弶锛勬畱鐎圭偞绁存?vs 鎼存梹婀佹妯糕偓鍌氭▕瀵版顦?閳?閹存垳婊戦幒褍鍩楅崠铏规畱閼奉亞鍔ф妯烘嫲閺冪姷鏅悰銊ヮ嚠娑撳秳绗傞敍?
    //   闁絾妞傞崘宥呭枀鐎?瀵扳偓鐞涖劑鍣风€靛綊缍?鏉╂ɑ妲?閺€瑙勫灉娴狀剝鍤滃杈╂畱妤傛ê瀹?閿?*娑撳秷顩︽稉銈呫仈娑撯偓鐠ч攱鏁?*閿涘鈧?
    //   閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdSwiperBox'`
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

  /** @returns 閺屾劒閲滅紒鍕 id 閻?*鐎圭偞绁存妯哄**閿涘澊p閿涘矂鍣烘稉宥呭煂鏉╂柨娲?-1閿涘鈧柡鈧?閸欘亞绮扮拠濠冩焽閺冦儱绻旈悽銊ｂ偓?*/
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
   * @returns 閺屾劒閲滅紒鍕 id 閻?*缁愭褰涢崸鎰垼妞ゆ儼绔?*閿涘澊p閿涘矂鍣烘稉宥呭煂鏉╂柨娲?-1閿涘鈧柡鈧?閸欘亞绮扮拠濠冩焽閺冦儱绻旈悽銊ｂ偓?
   *
   * 閳?2026-10-17閿涙艾濮炵€瑰啯妲告稉杞扮啊缂佹瑣鈧?*濮濆苯鎮曠悰灞藉竾閸︺劏绻樻惔锔芥蒋娑?*閵嗗秷绻栨稉鈧弶鈥茬娑?*閸欘垶鍣哄ù瀣畱閸掋倖宓?*
   *   閿涘牊鍨滃銈呭閸欘亣鍏橀棃鐘冲腹缁?chrome 妞ゆ儼绔熼敍灞惧腹閸戠儤娼垫稉銈咁殰闁€熷殰濞叉枻绱濈粵澶夌艾濞屸€冲灲閹诡噯绱氶妴?
   *   閻滄澘婀幎?`gapSwiper` 闁絾鐗撮崡鐘辩秴閺夆槄绱? 閹貉冨煑閸栫儤顒滄稉濠冩煙闁絼绔撮弽鐧哥礆閻ㄥ嫬鐤勫ù瀣€婃潏瑙勫ⅵ閸戠儤娼甸敍?
   * ```
   *   閸掋倖宓侀敍姝礽tle.y + 鐞涘矂鐝?> gapRowTop(閳?閹貉冨煑閸栨椽銆婃潏?  閳?濮濆苯鎮曠悰宀€鈥樼€圭偛甯囨潻娑欏付閸掕泛灏?
   *   閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdBoxes'`
   * ```
   * 閳跨媴绗?閻?`getPositionToWindowWithTransform()`閿涘牆鎯堢€圭懓娅掗崣妯诲床閿涘鍣?瑜般垹褰夐張鐔活嚢閺侀绡冩导姘崇閻偓閸欐﹫绱?
   *   閹碘偓娴犮儱褰ч惇?*閽€钘夌暰閹?*闁絽鍤戠悰灞烩偓?
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
  /** 閸忔娊妫撮弮鍫曟毐濮ｆ柧绶ラ惃鍕瑓闂勬劧绱檂morphT` 鐏忓繋绨€瑰啯妞傞幐澶婄暊缁犳绱氶垾鏂衡偓?鐎佃鐖ｉ弮鐘垫櫕 `REVERSE_MIN_RATIO = 0.4`閵?*/
  private static readonly REVERSE_MIN_RATIO: number = 0.4;
  /**
   * 閻愮懓鍤?鐠ч攱鎸遍幇蹇撴禈閹垫挸绱戦弮璁圭礉鐞涖儵妫?*瀵よ泛鎮楁稉銈呮姎**閸愬秷鎹ｉ敍鍧閿涘鈧?
   *
   * 妞ょ敻娼版潻娆庣鐢勫閸掓碍瀵曟潪濮愨偓浣界箷濞岋紕鏁炬潻鍥╊儑娑撯偓鐢嶇幢閸氬苯鎶氱挧鐤夐梻瀵告畱鐠囨繐绱濈粵澶岊儑娑撯偓鐢呮埂閻ㄥ嫮鏁鹃崙鐑樻降閺?
   * 閸斻劎鏁惧鑼病鐠ч绨￠崙鐘插磩濮ｎ偆顫?閳ユ柡鈧?閻劍鍩涢惇瀣煂閻ㄥ嫬姘ㄩ弰?閻╁瓨甯撮悙鐟扮磻閺勵垯绮犳稉顓㈡？瀵偓婵娈?閵?
   */
  private static readonly MORPH_INTRO_DELAY_MS: number = 50;
  /**
   * 娑撯偓濞喡ょ閹靛绱扮拠婵堟畱閺堚偓闂€鍨値閻炲棙妞傞梹鍖＄礄ms閿涘鈧?
   *
   * `pullDragging` 濞堝鏆€閺冨墎鍋ｉ崙缁樺ⅵ瀵偓娴兼俺鐑︽潻鍥ц埌閸欐ê鍨垫慨瀣閿涘牓鈧偓閸栨牗鍨氶懓浣稿З閻紮绱氶敍宀冪箹閺夛繝妲囬崐鑲╂暏閺?
   * 閸掋倕鐣?鏉╂瑤閲滈弽鍥唶瀹歌尙绮℃潻鍥ㄦ埂"閿涙矮绔村▎鈥茬瑐閹?娑撳濯烘稉宥呭讲閼宠姤瀵旂紒?2 缁夋帊浜掓稉濞库偓?
   */
  private static readonly PULL_DRAG_MAX_MS: number = 2000;
  /**
   * 闁挎氨鍋ｆ潻妯荤梾闁插繐鍩岄弮鍓佹畱闁插秷鐦梻鎾閿涘潰s閿涘鈧?
   *
   * "閻愮懓鍤幍鎾崇磻"闁絼绔撮崚鏄忕碃娴ｇ姵娼?閹绢厽鏂佹い闈涚埗鐢瓕绻曞▽鈥崇鐏炩偓鐎瑰矉绱檂getFrameNodeById` 閹峰じ绗夐崚鎷屽Ν閻愮櫢绱氶敍?
   * 閺冪姷鏅惃鍕粵濞夋洘妲?*濞夈劌鍞界亸杈╁崕閸ョ偠鐨熺粵澶屾絻**閵嗕浇鈧奔绗夐弰顖炩偓鈧崠鏍ㄥ灇閼颁礁濮╅悽浼欑幢閹存垳婊戞潻娆撳櫡閻劌鍤戠敮褔鍣哥拠鏇犵搼娴犲嘲鐤勯悳鑸偓?
   */
  private static readonly MORPH_RETRY_MS: number = 32;
  /**
   * 閸撯晙缍戦柌宥堢槸濞嗏剝鏆熼敍鍫熺槨濞嗏剝澧﹀鈧柌宥囩枂閿涘鈧柡鈧?**閻撗勫Ρ閸欏秶绱拠鎴犳畱 `PlayerPage.schedulePublishRetry`**閿?
   *
   *   閺堚偓婢舵岸鍣哥拠?12 濞喡扳偓浣圭槨濞嗭繝妫块梾?32ms閿涘牊鈧崵鐛ラ崣锝囧 384ms閿涘绱濋悽銊︽降缁?閸掓碍瀵曟潪濮愨偓浣界箷濞屸€崇鐏炩偓鐎?閻?
   *   閻╊喗鐖ｉ懞鍌滃仯閸欐ɑ鍨氶崣顖炲櫤濞村鈧倸寮界紓鏍槯缂佹捁顔戦敍姘￥閻ｅ瞼娈戦幘顓熸杹妞?*娑旂喍绗夌敮鎼佲敆**閿涘牆鎮撻弽閿嬫Ц push 閸戠儤娼甸惃鍕剁礆閿?
   *   鐎瑰啩绠ｉ幍鈧禒?缁楊兛绔村▎鈥虫皑閺堝鐨濋棃銏ゎ棧閸?閿涘矂娼惃鍕皑閺勵垵绻栨稉顏堝櫢鐠囨洜鐛ラ崣?+ `setFinalStatus()` 閸忔粌绨抽妴?
   */
  private morphRetryLeft: number = 12;
  /**
   * 閵嗗苯褰叉禒銉ョ磻婵鏁炬禍鍡愨偓宥囨畱闂傤煉绱拌ぐ銏犲綁閻喐顒滃鈧慨瀣剁礄閸戠姳缍嶉柌蹇撳煂楠炶泛甯囬崚鎷屾崳閻愮櫢绱氭稊瀣閿涘本鏆ｆい鍏哥箽閹?*閸忋劑鈧繑妲?*閵?
   *
   * 娑撹桨绮堟稊鍫ユ付鐟曚礁鐣犻敍姘礋娴滃棗鍘涢柌蹇撳煂"閸樼喎鏄傜€靛摜娈戠亸渚€娼伴惌鈺佽埌"閿涘本瀵曟潪钘夋倵閸掓澘鑸伴崣妯虹磻婵绠ｉ梻缈犵窗閺?1~2 鐢?
   * 閹绢厽鏂佹い闈涱槱娴?*閺堫亞缂夌亸?*閻樿埖鈧?閳ユ柡鈧?闁絽鍤戠敮褑瀚㈤悡褍鐖剁紒妯哄煑鐏忓彉绱伴梻顏冪娑撳鐣弫瀛樻尡閺€楣冦€夐妴?
   * 閸忚櫕甯€缂佹ê鍩楁稉宥呭閸濆秴绔风仦鈧敍鍧刼pacity` 娑撳秴寮稉搴＄鐏炩偓閿涘绱濋幍鈧禒銉╁櫤濞村鍙庣敮姝岀箻鐞涘被鈧?
   */
  @Local introPaintReady: boolean = false;
  /**
   * 瑜般垹褰夐弮鈺傛埂"鎼存洟娼版０婊嗗"濞ｂ€冲弳閻ㄥ嫮绮撻悙纭呯箻鎼达讣绱?閳?閿涘鈧?
   *
   * 鏉╄渹缍橀弶鈥茬瘍閺勵垰婀潻娆庨嚋鏉╂稑瀹冲ǎ鈥崇暚閻ㄥ嫸绱檂PlayerExpandState.miniBarOpacity` 閻?0.20閿涘绱?
   * 娑撱倛绔熻箛鍛淬€忕€靛綊缍堥敍姘俺闂堫澁绱欐惔鏇″ + 閸欐牞澹婄仦鍌︾礆閸掓媽绻栭柌灞绢劀婵傝姤妲搁幘顓熸杹妞ょ數婀″锝囨畱閼冲本娅欓懝璇х礉
   * 鏉╄渹缍橀弶鈥冲煂鏉╂瑩鍣峰锝呫偨濞戝牆銇?閳ユ柡鈧?鐟欏倹鍔呯亸杈ㄦЦ"閹绢厽鏂侀弶锛勬畱妫版粏澹婇崠鏍ㄥ灇娴滃棝銆夐棃銏ｅ剹閺咁垬鈧礁鑻熺捄鐔烘絻闂€鍨亣"閵?
   */
  private static readonly MORPH_BG_FADE_TO: number = 0.20;
  /**
   * 鐏忎線娼?+ 濮濆苯鎮曢妴宀€鐢绘鐐插煂濮濆矁鐦濇い鐢搞€婇柈銊ｂ偓宥囨畱閺冨爼鏆遍敍鍧閿涘鈧倹鐦仦鏇炵磻閻ｃ儳鐓敍灞芥礈娑撳搫鐣犻崣顏呮Ц鐏炩偓闁劌鍘撶槐鐘冲床娴ｅ秲鈧?
   *
   * A2 鐠х柉绻栭弶鈩冩闂€?*閻喓娈戠悮顐ゆ暏娑撳﹣绨?*閿涘潉animateLyricMorph` 閻?`animateTo`閿涘绱卞銈呭閺佹潙顨滃宀冪槤妞?
   * 鐏忎線娼拌ぐ銏犲綁鐞?`lyricMorphVisible = false` 閺冪姵娼禒璺哄彠閻偓閿涘矁绻栨稉顏勭埗闁插繑妲哥粚铏规畱閵?
   */
  private static readonly LYRIC_MORPH_DURATION_MS: number = 360;
  /** 閹貉冨煑閸栨椽娼ゅ銏狀樋娑斿懎鎮楅懛顏勫З閺€鎯版崳閿涘潰s閿涘鈧?*/
  /**
   * 閹貉冨煑閸?*缁屾椽妫介懛顏勫З閺€鎯版崳**閻ㄥ嫮鐡戝鍛闂€鍖＄礄ms閿涘鈧?
   *
   * 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻?`PlayerPage.IDLE_MS`閿涘绱?*5000**閵?
   *   閸戝搫顦╅敍姝歸ujie.pa:197964` 閻?`stlexvar 0x0, 0x8` 閸撳秳绔撮弶?`ldai 0x1388`
   *   閿涘潉0x1388` = **5000**閿涘绱濋懓?`startIdle()`閿涘潉wujie.pa:179936-179938`閿?
   *   鐏忚鲸妲?`setTimeout(<浣?, IDLE_MS)`閿涘矂鍋呮稉?浣嶉敍鍧?93408-193418`閿涘浠涙禒鈧稊鍫熸Ц閺勫海鈥橀惃鍕剁窗
   *   `idleTimer = -1; this.hideChrome();`閵?
   * 閳跨媴绗?閹存垳婊戦崢鐔告降閺?**3000**閿涘牊婀版禒鎾瑰殰鐎规艾鈧》绱濋弮鐘插毉婢跺嫸绱氶埇?鏉╂瑥姘ㄩ弰?缁屾椽妫介弮鍫曟？娑撳秳绔撮弽?閻ㄥ嫭娼靛┃鎰┾偓?
   */
  private static readonly CHROME_AUTO_HIDE_MS: number = 5000;
  /**
   * 閹貉冨煑閸?娴滎喖鍤?/ 閺€鎯版崳"闁絾娼悰銉╂？閻ㄥ嫭妞傞梹鍖＄礄ms閿涘鈧?
   *
   * 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`PlayerPage.CHROME_ANIM_MS`閿涘绱?*350**閵?
   *   閸戝搫顦╅敍姝歴howChrome()` 娑?`hideChrome()` 閸氬嫯鍤滈柇锝嗩偧 `animateTo(...)` 閻?`duration`
   *   闁姤妲?`throw.undefinedifholewithname "CHROME_ANIM_MS"`
   *   閿涘潉logic-src/PlayerPage.abc.txt` 閻?11967-11976 娑?4210-4219閿涘绱?
   *   鐢悂鍣洪崐?350 鐟?`_recover/logic-src/MiniMorph濞撳弶鐓嬮弬閫涚瑢妞よ泛绨抽弽蹇旇窗閸忋儱鍙曞?md:163`
   *   閿涘潉CHROME_ANIM_MS | 350 | 妞よ埖鐖弰楣冩閺冨爼鏆遍敍? D_MAIN閿涘ˇ閿涘鈧?
   *
   * 閳跨媴绗?閹存垳婊戦崢鐔告降閺?**240 + `Curve.EaseIn`閿涘牊鏁圭挧鍑ょ礆/ `Curve.EaseOut`閿涘牆鏁滈崙鐚寸礆**閿?
   *   閺?*閺堫兛绮ㄩ懛顏勭暰閸?*閿涘牊妫ら崙鍝勵槱閿涘鍣?閹?娑撳秷顔忔径鐟扮敨閼奉亞绱崐?閺€瑙勫灇閺冪姷鏅柇锝勮⒈娑擃亜鈧》绱?
   *   **350ms + `Curve.EaseInOut`閿涘牊妯夐妴渚€娈ｉ崥灞肩閺夆剝娲哥痪鍖＄礆閵?*
   */
  private static readonly CHROME_ANIM_MS: number = 350;
  /** 閹靛婧€缁?Swiper 闁插被鈧本鐡曠拠宥夈€夐妴宥囨畱娑撳鐖ｉ敍? = 鐏忎線娼版い纰夌礆閵?*/
  private static readonly SWIPER_INDEX_LYRIC: number = 1;
  /**
   * 濮濆矁鐦濋崠?*娑撳﹣绗呭鎴濆瀼閹广垺甯堕崚璺哄隘**閻ㄥ嫰妲囬崐纭风礄vp閿涘鈧柡鈧?閻撗勫Ρ閺冪姷鏅?`SWIPE_TOGGLE_VP`閵?
   *
   * 閸戝搫顦╅敍姝歅layerPage.onLyricSwipe`閿涘潉_recover/logic-src/PlayerPage.abc.txt:6942` 閻?
   * `throw.undefinedifholewithname "SWIPE_TOGGLE_VP"`閿涘奔浜掗崣?*妤傛ɑ鏁?*閻ㄥ嫬鐡ч棃銏ゅ櫤
   * `6974 ldai 0x18` = **24**閿涘绱辫ぐ鎺撱€傜敮鎼佸櫤鐞?`MiniMorph濞撳弶鐓嬮弬閫涚瑢妞よ泛绨抽弽蹇旇窗閸忋儱鍙曞?md:171`
   * 閸氬本鐗辩拋鎵絻 `SWIPE_TOGGLE_VP | 24`閵?
   * 閳跨媴绗?閺堫兛绮ㄩ崢鐔告降閸愭瑧娈戦弰?**12**閿涘牐鍤滅€规氨娈戞稉鈧崡濠忕礆閳?婢额亜顔愰弰鎾诡嚖鐟欙讣绱欓張顒€鐪伴弰?`parallelGesture`閿涘鈧?
   */
  private static readonly SWIPE_TOGGLE_VP: number = 24;
  /**
   * 濮濆矁鐦濋崠?*娑撳﹥绮﹂梾鎰閹貉冨煑閸?*闁絼绔撮弨顖涙Ц閸氾附鏂佸鈧?閳ユ柡鈧?鐎电懓绨查弮鐘垫櫕閻?`entryAllowsManual(lyricImmersive)` 闂傘劊鈧?
   *
   * 閺冪姷鏅敍姝歟ntryAllowsManual(mode) = mode === MANUAL || mode === BOTH`閿涘矁鈧?
   * `LyricEntryMode` 姒涙顓诲锝嗘Ц **AUTO**閿涘潉濮濆矁鐦濇い鍨癁鐏炲倸鐨濋棃顫瑢濮濆苯鎮曠€规氨顭?md` 鎼?閿涙瓌FF0 / AUTO1 / MANUAL2 / BOTH3閿?
   * 閳?**姒涙顓诲锝勭瑓"娑撳﹥绮﹂梾鎰"娴犫偓娑斿牓鍏樻稉宥呬粵**閿涘牓鍋呮稉鈧弨顖涙殻濞堜絻顫﹂梻銊﹀皡娴ｅ骏绱氶妴?
   * 閺堫兛绮ㄥ▽鈩冩箒鏉╂瑤閲滈悽銊﹀煕鐠佸墽鐤嗛敍鍫ユ桨閺夊潡鍣峰▽鈩冩箒"濞屽韫堝宀冪槤濡€崇础"鏉╂瑤绔存い鐧哥礆閳?閸?*姒涙顓?*鐞涘奔璐熼妴?
   *
   * 閳跨媴绗?**閺€鐟版礀 true 鐏忚鲸妲?娑撳﹥绮﹂梾鎰閹貉冨煑閸?闁插秵鏌婇悽鐔告櫏**閿涘牅绔寸悰宀嬬礆閿涙稑鍑￠崷?
   *   `RzdMusic瀵板懐鈥樼拋銈嗙閸?md` 缁?33 閺夛繝鍣烽弰搴ｂ€橀梻顔荤稑"鐟曚椒绗夌憰浣界箹娑擃亝澧滈崝?閵?
   */
  private static readonly LYRIC_SWIPE_ALLOWS_MANUAL: boolean = false;

  /**
   * "濠婃艾濮╂禒宥呮躬鏉╂稖顢?閻ㄥ嫬鍨界€规氨鐛ラ敍鍧閿涘鈧柡鈧?鐟?`lastScrollAtMs` 閻ㄥ嫭鏁為柌濞库偓?
   *
   * 閳?2026-10-16閿涙俺绻栨稉鈧弶?*娑撳秵妲搁崝銊ф暰閺冨爼鏆遍妴浣风瑝閺勵垵顫囬幇鐔峰棘閺?*閿涘矁鈧本妲?娑撱倗顫掓す鍗炲З閺傜懓绱￠獮璺虹摠"閺冨墎娈戞禒鑼额梿閿?
   *   `onContentDidScroll`閿涘牓鈧劕鎶氭潻娑樺閿涘缍嬬€硅埖妞傞敍瀹峴yncLyricMorphToPage()` 閻?閽€钘夌暰"韫囧懘銆忕拋鈺€缍呴妴?
   *   閳跨媴绗?120ms 閳?7 鐢嶇窗閹靛瀵氶幎顒冩崳閸?swiper 閻ㄥ嫭鍎婚幀褎绮撮崝銊ょ閸嬫粣绱濋拃钘夌暰鐏忚精鍏橀幒銉ь吀閺€璺虹啲閵?
   *   閳跨媴绗?鐎瑰啩绗?`Swiper` 閼奉亜绻侀惃?`duration` 閺冪姴鍙ч敍鍫ュ亝娑擃亜褰ч崷銊р柤鎼村繐瀵查崚鍥€夐弮鎯版崳娴ｆ粎鏁ら敍澶堚偓?
   */
  private static readonly SCROLL_SETTLE_WINDOW_MS: number = 120;
  /**
   * 濮濆矁鐦濇い鐢稿亝娑撯偓濡亣顢戦敍鍫濐嚠閺嶅洦妫ら悾?`metaRow`閿涘娈戦幒鎺斿鐢悂鍣?閳ユ柡鈧?閺佹澘鈧厧褰囬懛?
   * `PlayerPage鐎瑰本鏆I鐎规氨顭?md` 鎼?.2閿涙碍鐖ｆ０?`15` / 缁ぞ缍?/ 閻?/ `opacity 0.86`閿涘本鐡曢幍?`12` / 鐢瓕顫夐妴?
   */
  private static readonly LYRIC_META_TITLE_FP: number = 15;
  private static readonly LYRIC_META_ARTIST_FP: number = 12;
  /**
   * **鐏忎線娼版い鐢稿亝娑撯偓缁?*閻ㄥ嫭鐡曢崥?濮濆本澧滅€涙褰块敍鍧抪閿涘鈧柡鈧?鐎佃鐖ｉ弮鐘垫櫕 `chrome().titleSize` / `chrome().artistSize`閿涘湗ULL 濡楋綇绱氶妴?
   *
   * 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱遍張顒冪枂娴犲骸鐡ч懞鍌滅垳閹绘劕褰囬敍?*閸氬本妞傜痪鐘愁劀閹存垳绗傛稉鈧潪顔炬畱娑撯偓婢跺嫯顕ょ拠?*閿涘绱?
   *   閺冪姷鏅柇?*娑撯偓娑?* `Text` 閻ㄥ嫬鐡ч崣閿嬫Ц**閹绘帒鈧?*閸戠儤娼甸惃鍕剁礄`wujie.pa:194905-194939`閿涘畭lerp` 娑撳寮拫鍐暏閿涘绱?
   * ```
   *   fontSize( lerp( chrome().titleSize * sizeK(),   // 鐏忎線娼版い鐢殿伂 = 20 鑴?sizeK
   *                   15 * sizeK(),                   // 濮濆矁鐦濇い鐢殿伂 = 15 鑴?sizeK
   *                   metaProgress() ) )              // 鏉╂稑瀹抽敍? swiperProgress閿?
   * ```
   *   濮濆本澧滈崥宀€鎮婇敍姝歭erp( chrome().artistSize * sizeK()(=14), 12 * sizeK(), metaProgress() )`閵?
   *   閳?**鐏忎線娼版い?20 / 14閿涘本鐡曠拠宥夈€?15 / 12**閿涙矖sizeK()` 閺?缁愭褰涚€硅棄瀹抽惃鍕毐閺?
   *     閿涘牊澧滈張杞扮瑐 閳?閿涘苯閽╅弶?PC 閹靛秵婀佸?閳ユ柡鈧?鐟?`RzdMusic瀵板懐鈥樼拋銈嗙閸?md` E5閿涘鈧?
   *
   * 閳跨媴绗?閹存垳婊戦崢鐔告降**娑撱倝銆夐柈钘夋祼鐎?15 / 12** 閳?**鐏忎線娼版い鍨摃閸氬秴浜哥亸?33%閿?5 vs 20閿?*閵嗕焦鐡曢幍瀣焊鐏忓骏绱?2 vs 14閿涘鈧?
   * 閳跨媴绗?娑撳﹣绔存潪顕嗙礄鎼?6.27閿涘鍨滄稉鈧惔锔藉Ω鐎瑰啳顕伴幋?鐎涙褰跨憰?*娑?* `metaProgress()`"閿涘苯鑻熼幑顔筋劃閸?娑撳秷顔忛弨? 閳ユ柡鈧?
   *   **闁絼閲滅拠缁樼《閺勵垶鏁婇惃?*閿涘牊濡?`lerp` 瑜版挻鍨氭禍鍡曠濞夋洩绱濇禍搴㈡Ц娴犮儰璐熺亸渚€娼版い鍏哥窗閸欐ɑ鍨?0 閸欏嘲鐡ч敍澶堚偓?
   *   閻喓娴夐弰顖涘絻閸婄》绱扮€涙褰?*娴犲簼绗夊☉鍫濄亼**閿涘苯褰ч弰?*閻?20 閺€璺哄煂 15**閵嗗倹婀版潪顔藉瘻閻喓娴夐弨瑙勵劀閵?
   */
  private static readonly META_TITLE_FP_COVER: number = 20;
  private static readonly META_ARTIST_FP_COVER: number = 14;

  /**
   * 瑜版挸澧犳潻娆庣鐢呮畱**濮濆苯鎮曠€涙褰?*閿涘潚p閿涘鈧柡鈧?娑撱倗顏稊瀣？閹?*濮濆矁鐦濇い浣冪箻鎼?*閹绘帒鈧鈧?
   *
   * 閳?閻?`lyricMorphT`閿涘牊婀版い?鐏忎線娼版い?閳?濮濆矁鐦濇い?閻ㄥ嫯绻樻惔锔肩礆瑜版挻妫ら悾?`metaProgress()` 閻ㄥ嫮鐡戞禒椋庡⒖閿?
   *   闂堟瑦顒涢崷銊ョ殱闂堛垽銆?= 0 閳?`20fp`閿涙盯娼ゅ銏犳躬濮濆矁鐦濇い?= 1 閳?`15fp`閿涙稑鍨忔い鐢稿亝 360ms 闁插矁绻涚紒顓＄箖濞撀扳偓?
   * @returns 濮濆苯鎮曠€涙褰块敍鍧抪閿?
   */
  private metaTitleFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_TITLE_FP_COVER,
      PlaybackPage.LYRIC_META_TITLE_FP, this.lyricMorphT);
  }

  /**
   * 瑜版挸澧犳潻娆庣鐢呮畱**濮濆本澧滅€涙褰?*閿涘潚p閿涘绱癭14`閿涘牆鐨濋棃銏ゃ€夐敍澶嗗晪 `12`閿涘牊鐡曠拠宥夈€夐敍澶堚偓鍌滄倞閻㈠崬鎮?{@link metaTitleFp}閵?
   * @returns 濮濆本澧滅€涙褰块敍鍧抪閿?
   */
  private metaArtistFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_ARTIST_FP_COVER,
      PlaybackPage.LYRIC_META_ARTIST_FP, this.lyricMorphT);
  }

  /**
   * 娑撱倗顏稊瀣？閻ㄥ嫮鍤庨幀褎褰冮崐纭风礄`t` 婢剁懓鍩?0..1閿涘鈧倻绮版稉濠囨桨娑撱倓閲滅€涙褰块悽銊ｂ偓?
   * @param from `t = 0` 闁絼绔寸粩顖滄畱閸?
   * @param to `t = 1` 闁絼绔寸粩顖滄畱閸?
   * @param t 鏉╂稑瀹抽敍鍫滄崲閹板繐鐤勯弫甯礉閸愬懘鍎存径鐟板絿閿?
   * @returns 閹绘帒鈧偐绮ㄩ弸?
   */
  private static lerpFp(from: number, to: number, t: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return from + (to - from) * p;
  }
  /** 鐏忓繐鐨濋棃銏犲礁缂傛ê鍩屽灞芥倳閻ㄥ嫰妫跨捄婵撶礄vp閿涘鈧?*/
  private static readonly LYRIC_META_GAP_VP: number = 12;
  /** 鐠囥儴顢戦崣鍏呮櫠閻ｆ瑧娅ч敍鍧磒閿涘鈧柡鈧?缂佹瑦鏁归挊?閺囨潙顦挎稉銈勯嚋閸ョ偓鐖ｇ拋鈺€缍呴妴?*/
  private static readonly LYRIC_META_SIDE_VP: number = 16;
  // 閳跨媴绗?2026-10-15閿涙瓪LYRIC_META_ICON_FP` **瀹告彃鍨归梽?* 閳ユ柡鈧?閺€鎯版 / 閺囨潙顦块柇锝勮⒈娑擃亜娴橀弽鍥ㄦ暭閻?
  //   `this.expandState.chromeFavSize()`閿?*閹稿銆傛担宥堛€冮崣鏍р偓?* 24 / 22 / 20閿涘绱?
  //   鐎瑰本鏆ｉ崙鍝勵槱閿涘潉chrome().favSize`閵嗕梗wujie.pa:195193 / 195316`閵嗕焦銆傛担宥堛€?`93534`閿涘鍟撻崷銊╁亝娑擃亝鏌熷▔鏇氱瑐閵?
  //   閸掔姴鐣犻惃鍕斧閸ョ媴绱伴崢鐔告降鏉╂瑩鍣烽崘娆愵劥 `22`閿涘牊鏁為柌濠呭殰闂?閸欐牔绗屽ú楣冪叾娑撯偓閼峰娈戞稉鈧?閿?*娑撳秵妲搁弮鐘垫櫕閻ㄥ嫬鈧?*閿涘绱?
  //   閹广垺鍨?getter 娑斿鎮楁潻娆庨嚋鐢悂鍣虹亸?*濞屸剝婀佺拫鍐暏閼板懍绨?* 閳ユ柡鈧?娑撳秶鏆€濮濊鍞惍渚婄礄閸氬本妫屽〒鍛倞鐟?鎼?6.15 / 鎼?6.20閿涘鈧?
  /** 閸ョ偓鐖ｉ惃鍕仯閸戣崵鍎归崠楦跨珶闂€鍖＄礄vp閿涘苯鐣奸弬?`HIT = 44`閿涘鈧?*/
  private static readonly LYRIC_META_HIT_VP: number = 44;
  /**
   * 濮濆矁鐦濇い鐢稿亝娑撯偓濡亣顢戦惃?*鐞涘矂鐝?*閿涘澊p閿涘鈧柡鈧?娑撱倛顢戦弬鍥х摟閿涘牊鐖ｆ０?15 / 濮濆本澧?12 + 2 闂傜绐涢敍? 閸ョ偓鐖ｉ悾娆戞閵?
   * 閳跨媴绗?鐎瑰啫褰ч悽銊ょ艾"缁旀牜娲跨仦鍛厬鐞涖儱浼?閿涘牐顫?`LyricFloatLayer` 闁?`.position()` 閻ㄥ嫭鏁為柌濠忕礆閿?
   *    **娑撳秷顩?*閺€瑙勫灇鐏忎線娼版潏褰掓毐 閳ユ柡鈧?闁絼绱伴幎濠傜殱闂堛垽銆夐惃鍕摃閸氬秴绶氭稉瀣腹閸楀﹣閲滄径褍鐨濋棃銏㈡畱妤傛ê瀹抽妴?
   */
  private static readonly LYRIC_META_ROW_H_VP: number = 34;
  /** 缂冩垶鐗搁懗灞炬珯濠ф劗娈戦惄鎺戠础濡紕纭﹂崡濠傜窞 / 鏉烆喗鏆熼敍鍫熸￥閻?`MeshCoverBg` 閻?`BLUR_RADIUS` / `BLUR_PASSES`閿涘鈧?*/
  private static readonly MESH_BLUR_RADIUS: number = 9;
  private static readonly MESH_BLUR_PASSES: number = 3;
  /** 鐏炴洖绱戦惇瀣，閻欐绱檓s閿涘绱扮搾鍛鏉╂ɑ鐥呴崶鐐插煂鐎瑰本鏆ｉ幀浣告皑瀵搫鍩楅崶鐐插煂鐎瑰本鏆ｉ幀浣碘偓?*/
  private static readonly COLLAPSE_WATCHDOG_MS: number = 900;
  /** 鐏炴洖绱戦惇瀣，閻欐鐣鹃弮璺烘珤閸欍儲鐒洪妴?*/
  private collapseWatchdogTimer: number = -1;
  /** 濮濓絽婀幘顓熸暪鐠у嘲濮╅悽浼欑礄闂冨弶顒涙潻鐐靛仯鏉╂柨娲栭幘顓濊⒈闁稄绱氶妴?*/
  private isClosing: boolean = false;
  /**
   * 閳藉應妲?2026-10-15閿涘牊妫ら悾宀勨偓鍡楁倻 P0-3閿涘绱伴崶鐐茶剨閺€璺虹啲閻?*閻欘剛鐝涙禒锝嗩偧**閵?
   *
   * 閳跨媴绗?**娑撳秷顩﹂悽?`morphGen` 閺嶏繝鐛欐潻娆庣濮?*閿涙瓪morphGen` 閺?閸戠姳缍嶆禒锝嗩偧"閿?
   *   `morphBeginEntering` / `morphBeginLeaving` / `morphReset` 闁垝绱?`++`
   *   閿涘潉PlayerExpandState` L2330 / L2437 / L2456閿涘鍣?240ms 缁愭褰涢柌灞藉涧鐟曚浇鎹ｆ禍?*娴犺缍?*閺傞绱扮拠婵撶礉
   *   鏉╂瑦顐奸弨璺虹啲鐏忚精顫?*闂堟瑩绮捄瀹犵箖**閿涙稖鈧苯鐣犻弰?*閸烆垯绔?*閹?`morphDrive` 濞撳懎娲?`NONE` 閻ㄥ嫬婀撮弬?
   *   閿涘潉morphSettleOpen()` L2421閿涘鍣?`morphSessionDriving()`閿涘湢2487閿涘浜介惇?
   *   閳?婢瑰啿鐪伴崗瀣畷鐏炲偊绱欐稉澶夐嚋閹稿鎸?/ 濮濆苯鎮曢敍澶婄埗妞硅婀仦蹇庣瑐閵?
   *   閸掋倖宓侀敍姝歨dc shell hilog -x | Select-String 'RzdMorph'` 閳ユ柡鈧?娑撯偓鏉?娑撳濯洪埆鎺撴緱閹?闁?
   *   閻?`morph open (settled)` 閺堝鐥呴張澶婂毉閻滆埇鈧?
   */
  private dismissSettleGen: number = 0;
  /**
   * 閳藉應妲?2026-10-15閿涘牊妫ら悾宀勨偓鍡楁倻 P0-2閿涘绱伴弫鎾€夐崗鎶芥４閻?*閻欘剛鐝涙禒锝嗩偧** + 閸楁瓕娴囩€规碍妞傞崳銊ュ綖閺屽嫨鈧?
   *
   * 閸樼喐娼甸崣顏堟浆 `isClosing` 閹革繝鍣搁崗銉礉閼板苯鐣犻崷?`morphCloseMs + 20`閿涘牃澧?70ms閿涘姘ㄧ悮顐ｇ閸?`false`閿?
   * 闁絼绔撮崚缁樻尡閺€楣冦€?*閸欘垵鍏樻潻妯荤梾 unmount** 閳?缁楊兛绨╁▎锛勫仯閸戞槒鍏橀崘宥堟崳娑撯偓閺?350ms 鐞涖儵妫?+ 缁楊兛绨╂稉顏勫祻鏉炶棄鐣鹃弮璺烘珤閿?
   * 閼?`morphGenAlive` 閺嶏繝鐛欓幏锔跨瑝娴ｅ骏绱欐稉銈嗘蒋闁惧墽娈?`morphGen` 閻╃鎮撻敍澶堚偓?
   * 閻滄澘婀敍姘綖閺屽嫬鐡ㄦ稉瀣降閸欘垵顫﹂崣鏍ㄧХ + 娴狅絾顐兼稉銉︾壐閺嶏繝鐛?閳?"缁楊兛绨╁▎锛勫仯閸?鐟曚椒绠炵悮顐ｆ绾喖鎷烽悾銉ｂ偓浣筋洣娑斿牆鍏遍崙鈧幒銉ь吀閵?
   */
  private closeGen: number = 0;
  private closeSettleTimer: number = -1;
  /**
   * 閺堫剚顐兼稉瀣鐠虹喐澧滈弰顖氭儊瀹歌尙绮￠幎濠傝埌閸欐娴夋担宥呭瀼閸?LEAVING閿涘牆顕弽鍥ㄦ￥閻ｅ瞼娈?`drive = FINGER`閿涘鈧?
   *
   * 閺堝绨＄€瑰喛绱濋弶鐐閺冭埖澧犻懗钘夊瀻濞?鏉╂瑦顐兼稉瀣閻喓娈戠捄鐔稿鏉?閸?閸欘亝妲搁弸浣虹叚閻ㄥ嫪绔村▎鈩冨珛閹?閿?
   * 閸氬氦鈧懍绗夐懗钘夊箵閸斻劌鑸伴崣妯兼祲娴ｅ稄绱濋崥锕€鍨导姘Ω闂堟瑦顒涢惃?OPEN 閹焦鏁奸幋?LEAVING閵?
   */
  private dismissMorphActive: boolean = false;
  /**
   * 閺堫剚顐兼稉瀣閺€鎯版崳**鐠ч攱澧滈柇锝勭閸?*閻ㄥ嫬鑸伴崣妯跨箻鎼达讣绱檂morphP`閿?..1閿涘鈧柡鈧?閸忔娊妫撮幓鎰唉閻?*閻╃顕柌?*閸掋倖宓侀惃鍕唨閸戝棎鈧?
   *
   * 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻?`reverseQuitDelta`閿涘绱伴弮鐘垫櫕閻ㄥ嫬鍙ч梻顓熷絹娴溿倓绗夐弰?缂傗晛鍩屾径姘毌鐏忓崬鍙?閿?
   *   閼板本妲?**濮ｆ棁鎹ｉ悙鐟扮窔閸ョ偠铔嬫禍鍡楊樋鐏?*"閿涙瓪delta >= max(baseT/2, COMMIT_T)`閵?
   *   鐠ч攱澧滈弮璺烘躬 `morphBeginLeaving()` 娑斿澧犵拋鏉跨秿閺堫剙鈧》绱遍弶鐐閺冨墎鐣?`delta = baseT 閳?瑜版挸澧犳潻娑樺`閵?
   *   閳跨媴绗?閸掓繂鈧厧褰?**1**閿涘牊寮х仦鏇炵磻閿涘鈧柡鈧?娑?娴犲酣娼ゅ銏㈡畱閹绢厽鏂佹い闈涚磻婵绗呴幏?鏉╂瑤绔寸敮鍛娾偓浣风閼疯揪绱?
   *      閻喐顒滅挧閿嬪閺冩湹绱扮悮顐ょ彌閸掓槒顩惄鏍电礄鐟?`onDismissDrag` 闁插矁顔囪ぐ鏇炵暊閻ㄥ嫰鍋呮稉鈧悰宀嬬礆閵?
   */
  private dismissBaseT: number = 1;
  /**
   * 娑撳濯洪弨鎯版崳閹靛濞嶉惃?*鐠ч攱澧滄担宥囆╅梻銊╂**閿涘澊p閿涘鈧?
   *
   * 閳?鐎佃鐖ｉ弮鐘垫櫕 `PlayerPage` 妞ゅ爼鍎撮崗鎶芥４閹靛濞嶉惃?
   *   `PanGesture({ direction: PanDirection.Down, distance: 8 })`
   *   閿涘潉_recover\logic-src\瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md` 鎼? 闁喐鐓＄悰?/ 鎼?.1 閳?/ 鎼?.3閿?
   *   鐎涙濡惍?`wujie.pa:181153-181157`閿涘鈧柡鈧?**鐏忚鲸妲搁弮鐘垫櫕閻ㄥ嫰鍋呮稉?8閿涘奔绗夐弰顖涘灉娴狀兛鍙婇惃?*閵?
   *
   * 閳跨媴绗?娑撹桨绮堟稊鍫㈡暏**濡楀棙鐏︾痪?*闂傘劑妾洪妴浣解偓灞肩瑝閸?{@link onDismissDrag} 闁插本澧滈崘?`if (offsetY < N) return;`閿?
   *   `PanGestureOptions.distance`閿涘牊婀伴張?`gesture.d.ts:2380` 绾喗婀佺拠銉ョ摟濞堢绱?*姒涙顓?5vp**閿?
   *   閺?閹靛瀵氱挧鐗堝姬婢舵艾鐨幍?*鐠囧棗鍩?*鏉╂瑤閲滈幍瀣◢"閳ユ柡鈧?濞屄よ泲濠娾剝妞?`onActionStart/Update/End`
   *   閺嶈婀版稉宥勭窗鐟欙箑褰?閳?闂堟瑦顒涢幀浣筋潶 1~2vp 閹舵牕濮╅幒銊ㄧ箻 `LEAVING`閿涘潉濞查箖鐓堕崝銊ф暰Bug濞撳懎宕?md` P0-4閿?*閸︺劍绨径缈犵瑝閹存劗鐝?*閿?
   *   閼板本澧滈崘娆忓灲閹诡喕绱版径姘濞嗏€茬瑝鏉╃偟鐢婚敍鍫ｇ閹靛绻樻惔锕€婀梻銊╂闁絼绔寸敮褌绮?0 閻╁瓨甯寸捄鍐插煂 `N/span`閿涘鈧?
   *
   * 閳跨媴绗?**閹垫挸绱戦弬鐟版倻娑撳秴濮?*閿涙矮琚遍弶陇绯犳担鐘虫蒋閻?`panOption` 娣囨繃瀵旀妯款吇 5vp 閳ユ柡鈧?
   *   闁絾顒滄總鐣岀搼娴滃孩妫ら悾灞肩瑐濠婃垶澧﹀鈧幍瀣◢閻?`{ direction: PanDirection.Vertical, distance: 5 }`
   *   閿涘牆鎮撻弬鍥ㄣ€?鎼?.1 閳剁媴绱氶敍灞惧娴犮儵鍋呴柌灞炬＆娑撳秴濮炴稊鐔剁瑝閺€骞库偓?
   */
  private static readonly DISMISS_PAN_DISTANCE_VP: number = 8;
  // 閳跨媴绗?娑撳濯洪弨鎯版崳閻ㄥ嫪琚辨稉?*閸掋倖宓佺敮鎼佸櫤**閿涘牊褰佹禍銈夋閸?38 / 閸忔粌绨崇悰宀€鈻煎В鏂剧伐 0.42閿?*瀹稿弶鏁归弫娑樺煂**
  //    `PlayerExpandState.DISMISS_COMMIT_PROGRESS` / `PlayerExpandState.DISMISS_DRAG_SPAN_RATIO`
  //    閳ユ柡鈧?閸樼喎鍘涚€瑰啩婊戞稉搴㈠ⅵ瀵偓閺傜懓鎮滈惃?`PULL_OPEN_COMMIT_FRACTION` 閸掑棗鐪虫稉銈勯嚋閺傚洣娆㈤妴浣规￥娴溿倕寮堕弽锟犵崣
  //    閿涘潉濞查箖鐓堕崝銊ф暰Bug濞撳懎宕?md` P0-1閿涘鈧倻鎮婇悽鍙樼瑢"娑撳秷顔忛悡褎濡遍弮鐘垫櫕 0.32"閻ㄥ嫯顕╅弰搴ㄥ厴閸︺劑鍋呴柌宀€娈戝▔銊╁櫞闁插被鈧?
  /**
   * 娑撳濯洪弶鐐閺冨墎娈?*闁喎瀹?*閹绘劒姘﹂梼鍫濃偓纭风礄vp/s閿涘鈧?
   *
   * 閸戝搫顦╅敍姝歞ocs\閺冪姷鏅ぐ銏犲綁閹靛鍔?閽€钘夌杽閸掔櫅zdMusic濞撳懎宕?md` 鎼傛稉鈧?1.2閵嗗本褰佹禍銈呭灲鐎?閳ユ柡鈧?鏉╂稑瀹?OR 闁喎瀹抽妴宥忕窗
   * `commit = (morphT >= COMMIT_T 閸?0.32) || (velocity <= COMMIT_VELOCITY 閸?900)`
   * 閳?閺冪姷鏅惃?`COMMIT_VELOCITY = 900`閵?*鏉╂瑤閲滈弫鐗堟Ц娴犲孩鏋冨锝呭絿閻ㄥ嫸绱濇稉宥嗘Ц娴兼壆娈戦妴?*
   *
   * 閳跨媴绗?娴?*缂佹繀绗夐悡褎濡辩€瑰啰娈戝В鏃囩窛閺傜懓鎮?濮濓綀绀嬮崣?*閿涙碍妫ら悾灞炬Ц"娑撳﹥濯洪幍鎾崇磻"閿涘矁绻栭柌灞炬Ц"娑撳濯洪弨鎯版崳"閿涘本鏌熼崥鎴犳祲閸欏稄绱?
   *   閺傚洦銆傛稊鐔告鐠?缁楋箑褰跨憰浣稿帥鐎圭偞绁撮妴浣稿焼閻撗勫Ρ"閵嗗倽顫?{@link onDismissDrag}閿?
   *   **閺傜懓鎮滈悽鍙樼秴缁夎鍨介妴浣搞亣鐏忓繒鏁?`Math.abs(velocityY)` 閸?* 閳?閺嶉€涚瑐娑撳秹娓剁憰浣镐海鐠佸墽顑侀崣鏋偓?
   */
  private static readonly DISMISS_COMMIT_VELOCITY: number = 900;
  /**
   * 閳藉應妲?2026-10-15閿涘牊妫ら悾宀勨偓鍡楁倻 P0-4閿涘绱版稉瀣閺€鎯版崳閻?*閺堚偓鐏忓繗鎹ｉ幍瀣╃秴缁?*閿涘澊p閿涘鈧?
   *
   * 濞屸剝婀佺€瑰啰娈戦弮璺衡偓娆欑礉鐠虹喐澧滈崚鍡樻暜閸欘亣顩?`offsetY > 0`閿?*1vp 闁晫鐣?*閿涘姘ㄦ导?`morphBeginLeaving()`
   * 閳?閻╅晲缍呯悮顐ｅ腹鏉?`LEAVING` 娑?`morphGen++`閿涘矁鈧苯鐫嗘稉濠傚殤娑斿簼绮堟稊鍫ュ厴濞屸€冲З閿?
   * 閺夌偓澧滈崶鐐舵儰閺冭泛寮电紒娆戞祲娴ｅ秴浠涙稉鈧▎?220ms 鐞涖儵妫?+ 240ms 鐎规碍妞傞崳?
   * 閳?鐟欏倹鍔呴弰?鏉炴槒浜ら煫顓濈娑撳姘ㄩ梻顏冪娑?閿涘苯鎮撻弮鑸靛Ω P0-3 闁絾娼▓瀣殌閻樿埖鈧胶娈戦梻銊﹀ⅵ瀵偓閵?
   * 8vp 閳?2.5mm閿?*鏉╂粌鐨禍?*鐠囶垵袝鐏忓搫瀹抽敍鍫氬⒑10vp閿涘绗岄惇鐔风杽娑撳濯虹挧閿嬪閿涘牆鍤戦崡?vp閿?
   * 閳?**閸欘亝灏呴幎鏍уЗ閵嗕椒绗夐幐陇绐￠幍?*閿涘牅绗呮稉鈧稉?`onActionUpdate` 娑撯偓閺冿箒绉烘潻鍥х暊閻撗冪埗鐠ч攱澧滈敍澶堚偓?
   * 閳跨媴绗?閺冪姷鏅笟?*濞屸剝婀?*鏉╂瑤閲滈梻銊╂ 閳ユ柡鈧?鏉╂瑦妲稿ú楣冪叾閼奉亜绻侀惃鍕閸ョ尨绱?*閺佸懏鍓版稉宥勭瑢鐎瑰啫顕?*閵?
   */
  private static readonly DISMISS_MIN_START_VP: number = 8;

  /** @returns 缁愭褰涙妯哄閿涘澊p閿涘绱遍幏澶哥瑝閸掔増妞傜紒娆庣娑擃亜鍘规惔鏇炩偓纭风礉娣囨繆鐦夐幏鏍ㄥ濮ｆ柧绶ユ稉宥勭窗闂勩倝娴傞妴?*/
  private deviceHeightVp(): number {
    const px: number = this.windowInfo.windowSize.height;
    if (px <= 0) {
      return 780;
    }
    return this.getUIContext().px2vp(px);
  }

  /**
   * @returns 娑撳濯洪崚鏉跨俺閹碘偓闂団偓閻ㄥ嫯绐涚粋浼欑礄vp閿涘鈧柡鈧?鐠虹喐澧滆ぐ鎺嶇閸栨牜娈?*閸掑棙鐦?*閵?
   *
   * 閳?D2閿?*娴兼ê鍘涢悽銊ョ杽濞?*閿涘本瀣佹稉宥呭煂閹靛秹鈧偓閸ョ偟鐛ラ崣锝嗙槷娓氬鈧倸顕鎰￥閻?
   *   `pullRangePx = coverRect.top > 0 ? coverRect.top : windowHeight * 0.32`
   *   閿涘潉docs\閺冪姷鏅ぐ銏犲綁閹靛鍔?閽€钘夌杽閸掔櫅zdMusic濞撳懎宕?md` 鎼傛稉鈧?1.1閿涘鈧?
   *
   * **娑撹桨绮堟稊鍫濈杽濞村鈧厧褰?`expandState.miniY`**閿涙俺绐￠幍瀣箻鎼达附妲搁妴灞惧閹稿洣缍呯粔鑽ゆ畱缁绢垰鍤遍弫鑸偓?
   *   閿涘潉progress = offsetY / span`閿涘绱濋崚鍡樼槤閻ㄥ嫯顕㈡稊澶婃皑閺?閹靛瀵氱挧鏉跨暚閺佺繝閲滈弨鎯版崳閸斻劋缍旂憰浣借泲婢舵俺绻?閵?
   *   閺€鎯版崳閻ㄥ嫮娲伴弽鍥ㄦЦ鏉╄渹缍橀弶鈥崇殱闂堛垽鍋呮稉鈧亸蹇撴健閿涘矁鈧苯鐣犻惃鍕€婃潏鐟版皑閸︺劎鐛ラ崣锝呮綏閺?`miniY` 閳ユ柡鈧?瑜般垹褰夌€圭懓娅掗崷?`p = 0`
   *   閺冨墎娈戦崣顖濐潒閻晛鑸版い鎯扮珶濮濓絾妲?`miniCoverY`閿? `miniY`閿涘瞼鏁?`morphInitParams()` 娴犲骸鎮撴稉鈧禒钘夌杽濞村鈧偐鐣婚崙鐚寸礆閿?
   *   濠娾€崇潌閹線銆婃潏瑙勬Ц 0 閳?鐠ф澘鐣崗銊р柤 = 妞ゆ儼绔熸禒?0 閹割亜鍩?`miniY` 閳?鐞涘瞼鈻?`miniY`閵?
   *
   * 閳跨媴绗?**閺€鐟板瀻濮ｅ秳绗夋导姘辩柈缁夘垰浜哥粔?*閿涘煪褍鍙?缁?3 閺夛紕娈戦崚銈嗗祦閿涘绱癭dismissProgressFromDrag()` 娴犲秶鍔ч弰?
   *   `clamp(offsetY / span * 100)` 鏉╂瑧顫?**瑜版挸澧?*閹靛瀵氱紒婵嗩嚠娴ｅ秶些"閻ㄥ嫮鍑介崙鑺ユ殶閿?*娑撳秷顕版稉濠佺鐢?*閿?
   *   閼板奔绗?`miniY` 閸︺劋绔村▎鈩冨珛閸斻劍婀￠梻瀛樻Ц鐢悂鍣?閳ユ柡鈧?鏉╄渹缍橀弶鈥虫躬瑜般垹褰夐張鐔兼？閺?`Visibility.Hidden`
   *   閿?*娣囨繄鏆€鐢啫鐪?*閵嗕線娼扮粔顖欑瑝閸欐﹫绱氶敍灞肩瑝娴兼艾鍟€鐟欙箑褰?`onAreaChange` 娑撳﹥濮?閳?閸掑棙鐦濇稉宥勭窗閸︺劍瀚嬮崝銊よ厬闁棁鐑﹂崣妯糕偓?
   */
  private dismissSpanVp(): number {
    const measured: number = this.expandState.miniY;
    if (measured > 0) {
      return measured;
    }
    return this.deviceHeightVp() * PlayerExpandState.DISMISS_DRAG_SPAN_RATIO;
  }

  /**
   * 閻㈣鲸瀚嬮幏鍊熺獩缁傜粯宕茬粻妤佹暪鐠х柉绻樻惔锔衡偓?
   * @param offsetY 閹靛濞嶉惃鍕彨閻╃繝缍呯粔浼欑礄vp閿涘苯鎮滄稉瀣╄礋濮濓綇绱氶妴?
   * @returns 鏉╂稑瀹?0..100閵?
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
   * 娑撳濯洪弨鎯版崳閹靛濞嶉敍姘珛閸斻劍婀￠梻?*鐠虹喐澧?*閺€纭呯箻鎼达讣绱欐稉宥堣泲 animateTo閿涘本澧嶆禒銉︽Ц閸楄櫕妞傞惃鍕剁礆閿?
   * 閺夌偓澧滈弮?**鏉╂稑瀹虫潻鍥閸?OR 闁喎瀹崇搾鍐差檮韫?* 鐏忚鲸鏁圭挧鍑ょ礉閸氾箑鍨悰銉╂？瀵懓娲栫€瑰本鏆ｉ幀浣碘偓?
   *
   * 鏉╂瑥顨滄禍銈勭鞍閸滃苯寮懓鍐ㄤ紣缁?MusicHome 閻?`PanGesture` 娑撯偓閼疯揪绱欑€瑰啰娈?`dismissPanOffsetY`
   * 閳?`dismissSheetHeightPercent` + `coverLinearScale` 閺勵垰鎮撴稉鈧禒鏈电皑閿涘鈧?
   *
   * 閳?D1閿涙岸鈧喎瀹虫い纭咁潌娑撳娼?{@link PlaybackPage.DISMISS_COMMIT_VELOCITY}閵?
   * @param offsetY 瑜版挸澧犵粩鏍纯娴ｅ秶些閿涘澊p閿涘苯鎮滄稉瀣╄礋濮濓綇绱氶妴?
   * @param ended 閺勵垰鎯侀弰顖涙緱閹靛鈧?
   * @param velocityY 閺夌偓澧滈弮鍓佹畱缁旀牜娲块柅鐔峰閿涘牊娼甸懛?`GestureEvent.velocityY`閿涘鈧?
   *   閳跨媴绗?**閺堫剙鍤遍弫棰佺瑝娓氭繆绂嗙€瑰啰娈戠粭锕€褰?*閿涘牐顫嗘稉瀣剁礆閿涘本澧嶆禒銉╃帛鐠併倕鈧?0 娑旂喍绗夋导姘垛偓鐘插毉"鐠囶垱褰佹禍?閵?
   */
  private onDismissDrag(offsetY: number, ended: boolean, velocityY: number = 0): void {
    if (this.isClosing) {
      // 閳藉應妲?2026-10-15閿涙俺绻栨稉鈧悰灞间簰閸撳秵妲?*闂堟瑩绮?* return閿涘奔绨弰?娑撳濯洪弨鎯版崳鐎瑰苯鍙忔稉宥堢閹?鏉╂瑤娆㈡禍?
      //   閸︺劍妫╄箛妤呭櫡娑撯偓閻愬湱妫旀潻褰掑厴濞屸剝婀侀敍鍫熷閹稿洤濮╂禍鍡愨偓浣哥潌娑撳﹥鐥呴崝銊ｂ偓浣规）韫囨ぞ绡冨▽鈥冲晸閿涘绱濋崣顏囧厴闂堢姷瀵介妴?
      //   閻滄澘婀幎濠傜暊閹垫挸鍤弶銉窗`hdc shell hilog -x | Select-String 'RzdMorph dismiss blocked'`
      //   閳ユ柡鈧?閸戣櫣骞囩€?= `isClosing` 閸椻€茬秶娴滃棴绱欑憴?`closeFullScreenPlayback()` 閻ㄥ嫯藟濠曞繑鏁為柌濠忕礆閿?
      //   **鐎瑰苯鍙忔稉宥呭毉閻?* = 閹靛濞嶉弽瑙勬拱濞屸€冲煂鏉╂瑱绱欓柇锝嗘Ц閹靛濞嶇捄顖滄暠闂傤噣顣介敍灞藉箵閺?`RzdMorph dismiss pan start`閿涘鈧?
      Logger.warn(PlayerExpandState.LOG_TAG,
        `RzdMorph dismiss blocked: isClosing=true offsetY=${offsetY.toFixed(1)} ended=${ended}`);
      return;
    }
    const progress: number = this.dismissProgressFromDrag(offsetY);
    // 閳藉應妲?D1閿涘牊娓舵妯圭喘閸忓牏楠囬敍澶涚窗閹绘劒姘﹂崚銈呯暰 = **鏉╂稑瀹?OR 闁喎瀹?*閿涘牊妫ら悾?鎼傛稉鈧?1.2閿涘鈧?
    //   閸欘亝婀佹潻娑樺閺冭绱?娴ｅ秶些娑撳秴鍩?38% 娴ｅ棛鏁ュ妤€绶㈣箛?閺€鏈电瑝鐠ч攱娼?閳ユ柡鈧?閻劍鍩涢幍瀣妳娑撳﹤姘ㄩ弰?韫囶偆鏁ュ▽鈥冲冀鎼?閵?
    //
    //   閳跨媴绗?**娑撳秷顔忛悮?`velocityY` 閻ㄥ嫮顑侀崣?*閿涘牊鏋冨?鎼傞崗?缁?3 閺?+ 鎼傞崶?D1 閻?閳跨媴绗嶉敍澶涚窗
    //     閺冪姷鏅柇锝堢珶閺?閸氭垳绗呮稉鐑橆劀"閿涘矁鈧本鍨滄禒顒冪箹闁插本妲?*娑撳濯洪弨鎯版崳**閵嗕焦鏌熼崥鎴滅瑢鐎瑰啰娴夐崣宥忕礉
    //     閻撗勫Ρ濮濓綀绀嬮崣宄扮箑闁挎瑱绱遍懓?SDK 閻?`GestureEvent.velocityY`閿涘潉gesture.d.ts`閿涘瓐since 10閿?
    //     娑旂喐鐥呴張澶嬪鐠囪櫣顑侀崣閿嬫煙閸氭垯鈧倹澧嶆禒銉ㄧ箹闁插奔绮犻弽閫涚瑐缂佹洖绱戦敍?
    //       璺?**閺傜懓鎮?*閸欘亞鏁?*娴ｅ秶些**閸?閳ユ柡鈧?`offsetY > 0` 閸?鏉╂瑦顐奸幏鏍уЗ閺堟繃鏁圭挧閿嬫煙閸?閿?
    //       璺?**婢堆冪毈**閸欘亜褰?`Math.abs(velocityY)`閵?
    //     閳?閺冪姾顔戠化鑽ょ埠缂佹瑧娈戦弰?+900 鏉╂ɑ妲?閳?00閿涘苯鍨界€规氨绮ㄩ弸婊堝厴娑撯偓閺嶅嚖绱?*濞屸剝婀佹禒璁崇秿"缁楋箑褰跨€圭偞绁?閸撳秶鐤嗛弶鈥叉**閵?
    //   闂冨牆鈧?900 閸欐牞鍤滈弬鍥ㄣ€傞敍鍫ｎ潌 `DISMISS_COMMIT_VELOCITY` 閻ㄥ嫭鏁為柌濠忕礆閿涘奔绗夐弰顖滅椽閻ㄥ嫨鈧?
    const collapsingDirection: boolean = offsetY > 0;
    const speed: number = Math.abs(velocityY);
    const fastFlick: boolean = collapsingDirection && speed >= PlaybackPage.DISMISS_COMMIT_VELOCITY;
    // 閳?瑜般垹褰夐柇锝咁殰閿涙矮绗呴幏澶嬫暪鐠у嘲姘ㄩ弰?*閸欏秴鎮滅捄鎴濇倱娑撯偓婵傛鍤戞担?*閿涘牊妫ら悾灞肩瘍閺勵垰鎮撴稉鈧稉?progress 濮濓絽寮芥稉銈囨暏閿?
    //   閳ユ柡鈧?閺佹挳銆夌紓鈺佹礀鏉╄渹缍橀弶锟犲亝娑撯偓鐏忓繐娼￠妴浣筋梿閸擃亞鐛ラ崣锝嗘暪閸ョ偛骞撻妴浣界碃娴ｇ姵娼崥灞炬濞ｂ€虫礀閺夈儯鈧?
    if (this.expandState.morphUsable) {
      if (!ended) {
        if (!this.dismissMorphActive) {
          // 閳藉應妲?P0-4閿?*閺堚偓鐏忓繗鎹ｉ幍瀣╃秴缁夊妫梽?*閿涘牅绶烽幑顔款潌 `DISMISS_MIN_START_VP` 閻ㄥ嫭鏁為柌濠忕礆閵?
          //   娴ｅ簼绨€瑰啫姘ㄨぐ鎾圭箹濞嗏剝瀚嬮崝銊ょ瑝鐎涙ê婀敍姘瑝閺€鍦祲娴ｅ秲鈧椒绗?++ 娴狅絾顐奸妴浣风瑝閸掑嘲鍤戞担鏇礉閻╁瓨甯存潻鏂挎礀閵?
          //   娑撳绔存稉?`onActionUpdate` 閸欘亣顩︾搾濠呯箖闂傘劑妾虹亸鍙樼窗濮濓絽鐖剁挧閿嬪 閳?鐠虹喐澧滄稉宥勭窗閸欐绻滈柦婵勨偓?
          //   閳跨媴绗?**`fastFlick` 韫囧懘銆忛懗鐣岀搏鏉╁洭妫梽?*閿涙矮绔村▎?閺嬩礁鎻╂担鍡曠秴缁夎绶㈢亸?閻ㄥ嫪绗呴悽?
          //      閿?ms 閸愬懎褰х挧棰佺啊閸?vp閿涘甯張顒勬浆闁喎瀹虫い鐟版皑閼宠姤鏁圭挧鍑ょ礉鐞氼偊妫梽鎰皡閹哄姘ㄩ幋鎰啊"韫囶偆鏁ュ▽鈥冲冀鎼?
          //      閳ユ柡鈧?闁絾顒滈弰?D1 瑜版挸鍨电憰浣锋叏閻ㄥ嫭鐦洪惀鍛偓鍌涘娴犮儴绻栭柌灞炬Ц `娴ｅ秶些濞屄ょ箖闂傘劑妾?**娑?* 娑撳秵妲歌箛顐ゆ暐`閵?
          if (offsetY < PlaybackPage.DISMISS_MIN_START_VP && !fastFlick) {
            return;
          }
          this.refreshCollapseGeometry();
          this.dismissMorphActive = true;
          // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱伴崗鎶芥４閹绘劒姘﹂弨瑙勫灇**閻╃顕柌?*閸掋倖宓侀敍澶涚窗鐠ч攱澧滄潻娆庣閸掕鍘涢幎濠傜秼閸撳秷绻樻惔锕侇唶娑撳娼?閳ユ柡鈧?
          //   閺夌偓澧滈弮鍓佹畱閸掋倖宓侀弰?**濮ｆ棁鎹ｉ悙鐟扮窔閸ョ偠铔嬫禍鍡楊樋鐏?*"閿涘潉delta`閿涘绱濇稉宥嗘Ц"缂傗晛鍩屾禍鍡楊樋鐏?閵?
          //   閺冪姷鏅?`reverseQuitDelta()`閿涙瓪quit = delta >= max(baseT/2, COMMIT_T)`
          //   閿涘潉_recover/logic-src/瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md` 鎼傞崗?L351-353 / L386閿?
          //   鐎涙濡惍?L151812-151838閿涘鈧?
          //   閳跨媴绗?韫囧懘銆忛崷?`morphBeginLeaving()` **娑斿澧?*閸欐牭绱版稉瀣╃濮濄儰绱伴弨鍦祲娴ｅ秲鈧?
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
      // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍姘彠闂傤厽褰佹禍銈嗘暭閹?*閻╃顕柌?*閸掋倖宓?`delta >= max(baseT/2, COMMIT_T)`
      //   閿涘牊妫ら悾?`reverseQuitDelta()`閿涙稑鍤径鍕倱娑撳绱氶妴?
      //   璺?`delta` = 鐠ч鍋ｆ潻娑樺 閳?瑜版挸澧犳潻娑樺 = "鏉╂瑤绔撮幏鏍х窔閸ョ偠铔嬫禍鍡楊樋鐏?閿?
      //   璺?**濠娾€崇潔瀵偓鐠ч攱澧?*閿涘潉baseT = 1`閿涘鍣?闂冨牆鈧?= `max(0.5, 0.32) = 0.5` 閳?**鐟曚焦濯洪崶鐐插箵 50% 閹靛秴鍙?*
      //     閿涘牊鏁奸崜宥嗘Ц"缂傗晛鍩?38% 鐏忓崬鍙?閳?`delta 閳?0.38` 閳?**閺囨潙顔愰弰鎾诡嚖閸?*閿涘绱?
      //   璺?`baseT` 鐏忓繋绨?0.64 閺冨爼妲囬崐濂糕偓鈧崚?`COMMIT_T = 0.32`閿涘牊妫ら悾宀勫亝閺?`max` 閻ㄥ嫬褰熸稉鈧崡濠忕礆閵?
      //   閳跨媴绗?闁喎瀹虫い?*娑撳秷鍏樻稉?*閿涙碍妫ら悾灞肩瘍閺?`鏉╂稑瀹?閳?闁喎瀹砢閿涘煪褌绔?1.2閿涘绱?韫囶偆鏁?韫囧懘銆忛悡褎鐗遍懗钘夊彠閵?
      const currentT: number = 1 - progress / 100;
      const dismissDelta: number = this.dismissBaseT - currentT;
      const dismissThreshold: number = Math.max(this.dismissBaseT / 2,
        PlayerExpandState.PULL_OPEN_COMMIT_FRACTION);
      const shouldClose: boolean = dismissDelta >= dismissThreshold || fastFlick;
      // 娑撳﹥婧€閹烘帗鐓￠悽顭掔窗`hdc shell hilog -x | Select-String 'RzdMorph dismiss commit'`
      // 閳跨媴绗?鏉╂瑤绔寸悰?*閺佸懏鍓伴崥灞炬閹垫挷琚辨稉顏呮煙閸氭垹娈戦梼鍫濃偓闂寸瑢娑撱倓閲滈崚鍡樼槤**閿涘牆寮憴?
      //    `PlayerExpandState.pullSpanIsMeasured()` 閻ㄥ嫭鏁為柌?/ `濞查箖鐓堕崝銊ф暰Bug濞撳懎宕?md` 鎼?.5閿涘绱?
      //    閸欘亝澧?濮ｆ柨鈧?vs 闂冨牆鈧?娴兼氨鎴风紒顓℃娴?娑撱倖濡哥亸鍝勭摍娑撳秵妲搁崥灞肩娑擃亪鏆辨惔?鏉╂瑤娆㈡禍瀣ㄢ偓?
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
        // 娴溿倗绮?closeFullScreenPlayback閿涙艾鐣犳导姘复閻偓閹跺﹤鑸伴崣妯克夐梻鏉戝煂 0 閸愬秴宓忔潪?
        this.closeFullScreenPlayback();
        return;
      }
      // 濞屄ょ箖闂冨牆鈧》绱板鐟版礀鐎瑰本鏆ｉ幀渚婄礉楠炶埖濡搁惄闀愮秴閺€璺烘礀 OPEN
      this.expandState.morphDrive = MorphDrive.ANIM;
      // 閳藉應妲?P0-3閿涙氨娴夋担宥呯秺娴ｅ秵鏁奸悽?*閻欘剛鐝涙禒锝嗩偧**閿涘牅绶烽幑顔款潌鐎涙顔?`dismissSettleGen` 閻ㄥ嫭鏁為柌濠忕礆閿?
      //   娑撳秴鍟€婢跺秶鏁?`morphGen` 閳ユ柡鈧?鐎瑰啩绱扮悮顐℃崲娴ｆ洘鏌婃导姘崇樈 ++閿涘苯顕遍懛纾嬬箹濞嗏剝鏁圭亸鎹愵潶闂堟瑩绮捄瀹犵箖閿?
      //   閼?`morphDrive` 鐏忚鲸妗堟潻婊冧粻閸?`ANIM`閵?
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
          // 閺堫剝鐤嗛崶鐐茶剨瀹歌尪顫︽稉瀣╃濞嗏€虫礀瀵懓褰囨禒?
          return;
        }
        // 閳?閻╅晲缍呭鑼额潶閸掝偆娈戞导姘崇樈閹恒儳顓哥亸鍗炵箑妞ょ粯鏂侀幍瀣剁窗閺傞绔存潪顔藉珛閸斻劋绱伴幎?`drive` 缂?`FINGER`閿?
        //   `morphBeginEntering` 娴兼碍濡?`stage` 缂?`ENTERING`閵嗕梗closeFullScreenPlayback`
        //   娴兼碍濡?`isClosing` 缂冾喚婀?閳ユ柡鈧?娑撳顫掗幒銉ь吀闁€熷厴鐞氼偂绗傞棃銏犲殤閺夆剝灏呮担蹇嬧偓?
        //   閸欘亝婀?閺堫剝鐤嗘禒宥嗘Ц閻╅晲缍呮稉璁虫眽"閺冭埖澧犺ぐ鎺嶇秴閵?
        if (this.expandState.morphStage !== MorphStage.LEAVING
          || this.expandState.morphDrive !== MorphDrive.ANIM) {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss bounce: phase taken over stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}, skip settle`);
          return;
        }
        // 閳?`morphSettleOpen()` 閸愬懘鍎存导姘Ω `morphDrive` 瑜?`NONE`
        //   閿涘潉PlayerExpandState` L2421閿?*閸忋劋绮ㄩ崬顖欑**閻ㄥ嫭绔婚梿鍓佸仯閿涘鈧柡鈧?
        //   鏉╂瑤绔村銉ユ皑閺?婢瑰啿鐪伴崗瀣畷鐏炲倸鐖舵す?闁絾娼?bug 閻ㄥ嫯袙閼筋垽绱?*娑撳秷顩︾紒鏇＄箖鐎?*閵?
        this.expandState.morphSettleOpen();
      }, 240);
      return;
    }
    // 閺冪姵婀侀弫鍫ユ晪閻愰€涚瑝鏉╂劘顢戦弮褍甯囬幍浣哥鐏炩偓閿涘本婢楅幍瀣姬鐡掓娊妲囬崐鍏煎閻╁瓨甯撮崗鎶芥４閵?
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

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 鐏忎線娼?+ 濮濆苯鎮曠紒顓㈩棧閸掔増鐡曠拠宥夈€夋い鍫曞劥閿涘湏2閿涘鏀㈤埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧?

  /**
   * 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?鐏忎線娼?/ 濮濆苯鎮曞ù顔肩湴閻?*鐠恒劑銆夌€规矮缍?*閿涘牆顕弽鍥ㄦ￥閻?`floatingCover` / `floatingMeta`閿涘鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
   *
   * 閸掑洤鍩屽宀冪槤妞ゅ灚妞傜拋?*閸氬奔绔村鐘茬殱闂?+ 濮濆苯鎮?*缂傗晛鐨獮鍓佇╅崚鐗堢摃鐠囧秹銆夋い鍫曞劥閿涘苯鍨忛崶鐐茬殱闂堛垽銆夐弮璺哄斧鐠侯垶顥ｉ崶?閳ユ柡鈧?
   * **閻?Swiper 閻ㄥ嫭绮撮崝銊ㄧ箻鎼达箓鈧劕鎶氭す鍗炲З**閿涘牅绗夐弰顖澦夐梻鎾攳閸旑煉绱氶妴?
   *
   * ## 娑撹桨绮堟稊鍫熸Ц鏉╂瑦鐗遍敍鍫ｂ偓灞肩瑝閺?娑撱倝銆夐崥鍕暰娑撯偓娴?閿?
   *
   * 閺冪姷鏅惃?`playerPane` 閺?`Stack { Swiper{ 鐏忎線娼版い?; 缁岀儤鐡曠拠宥夈€?} ; floatingCover ; floatingMeta }`
   * 閳ユ柡鈧?鐏忎線娼版稉搴㈢摃閸?*閹稿倸婀?Swiper 娑斿顦?*閿涘苯鍨忔い鍨閺?*閸氬奔绔存稉顏勫帗缁?*閸︺劌濮╅敍娑欑摃鐠囧秹銆夐柇锝勭妞ゅ灚婀伴煬顐ｆЦ娑擃亞鈹栨竟绛圭礉
   * 閸欘亝婀?`padding({ top: lyricPadTop() })` 鐠佲晙缍呴妴?
   *
   * ## 娑撳閲滄稉宥呭綁闁?
   *
   * 1. **閸忋劌婧€閸欘亝婀佹稉鈧鐘茬殱闂?*閿涙艾鐨濋棃銏ゃ€夐柇锝勫敜閻喎鐨濋棃銏犲嚒缂佸繐鑻熸潻娑欒癁鐏炲偊绱檂page 0` 閸欘亜澧?
   *    `MiniLyricLinesComponent` 缁屽搫锛撻敍澶涚礉"娑撱倓鍞ょ亸渚€娼伴崥灞炬閸欘垵顫?娴犲海绮ㄩ弸鍕瑐鐏忓彉绗夐崣顖濆厴閿?
   *    閹碘偓娴?*濞屸剝婀?娑撱倛鈧懍绨扮悰?鏉╂瑥娲栨禍?*閿涘牊妫梻?`lyricFloatActive()` 瀹告彃鍨归敍澶涚幢
   * 2. **闂堟瑦顒涢幀浣疯⒈妞ら潧鎮囬懛顏堚偓鎰剼缁辩姳绗夐崣?*閿涙瓪t = 0` 闁絼绔寸粩顖氭皑閺勵垳婀＄亸渚€娼伴惃鍕儰閻愬湱鐓╄ぐ?
   *    閿涘潉PlayerExpandState.lyricMorph(0)` 婢跺秶鏁ょ紒顓㈩棧鐏忎線娼?`p=1` 閻ㄥ嫬鎮撴稉鈧▓鐢殿伂閻愮懓鍤戞担鏇礆閿?
   *    閹碘偓娴犮儰姘﹀Λ鎺楀亝娑撯偓鐢勭梾閺堝褰茬捄宕囨畱瀹割噯绱?
   * 3. **濞搭喖鐪版稉宥呭讲閻劌姘ㄩ弫鏉戭殰娑撳秴鎯庨悽?*閿涘潉lyricFloat()` 娑撳搫浜ｉ敍姘殱闂堛垺鐥呴柌蹇撳煂 / 鐎硅棄鐫嗛棃銏℃緲鐠ф澘褰熸稉鈧總妤€绔风仦鈧敍?
   *    閳ユ柡鈧?娴犫偓娑斿牓鍏樻稉宥囨暰閵嗕梗lyricPadTop()` 娑旂喐妲?0閿涘奔绗屽▽鈩冩箒鏉╂瑥顨滄稉婊嗐偪閺冩湹绔撮懛娣偓?
   *
   * 閳跨媴绗?**濮濆矁鐦濋幀搴濈疄閻㈣绔存稉顏勭摟濞屸€冲З**閿涘潉LyricsComponent` / `AmllLyricView` 娑撳秶顫敍澶涚礉
   *   鏉╂瑩鍣烽崣顏勫З"鐏忎線娼?濮濆苯鎮曞ù顔肩湴閻ㄥ嫯娉曟い闈涚暰娴?娑撳孩鐡曠拠宥夈€夐惃鍕€婇柈銊ф殌閻у鈧?
   *
   * ## 閳藉應妲勯埥?2026-10-16閿?*妞瑰崬濮╅弬鐟扮础瀹歌尙鍙庨幖顒佹￥閻ｅ矉绱版潻娑樺瀵骏绱濇稉宥嗘Ц鐞涖儵妫垮?*閿?
   *
   * 鏉╂瑩鍣烽崢鐔告降閺堝绔存稉?`animateLyricMorph(toLyric)`閿涙氨鏁?`animateTo(360ms, EaseInOut)` 閹?
   * `lyricMorphT` 娴?0 鐞涖儱鍩?1閿涘牊鍨ㄩ崣宥呮倻閿涘绱濋獮鍓佹暠 `.onAnimationStart` 鐠嬪啰鏁ら妴?
   * **閻滄澘婀€瑰啫鍑￠崚鐘绘珟**閿涘瞼鎮婇悽鎲嬬礄濮ｅ繋绔撮弶锟犲厴閹稿洤鎮滈弮鐘垫櫕閻ㄥ嫬甯弬鍥风礆閿?
   *
   * ```
   *   閳?閺冪姷鏅?*濞屸剝婀佹潻娆愭蒋鐞涖儵妫?*閿涙艾鐣犻惃鍕殱闂堫澀缍呯純顔炬纯閹恒儲妲?`morph.scaleAt/txAt/tyAt(swiperProgress)`
   *      閳ユ柡鈧?`swiperProgress` 鐏忚鲸妲?Swiper 閻ㄥ嫭绮撮崝銊ㄧ箻鎼达讣绱欑憴?鎼?16.2 閻ㄥ嫰鈧劖娼€涙濡惍渚婄礆閵?
   *   閳?`.onAnimationStart` 闁絾娼捄顖氱敨鐎瑰牆宕奸妴瀹╪dex === targetIndex 閳?鐠哄疇绻冮妴?
   *      閳?閸欘亣顩﹂崚鍥€夋稉宥嗘Ц"娑撯偓濞嗭紕婀″鎴濆З"閿涘牏鈻兼惔蹇撳閸掑洭銆?/ 闁插秵瀵曟潪钘夊灥婵銆夋稉宥嗘Ц 0 / 妞ゅ吀绗岄悩鑸碘偓浣风瑝娑撯偓閼疯揪绱氶敍?
   *        閺佹潙顨滄鐐额攽**濮樻瓕绻欐稉宥呮儙閸?* 閳?`lyricMorphT` 閹?0 閳?鐏忎線娼伴幁鎺嶈礋婢堆冪殱闂堫潿鈧?
   *        **閻劍鍩?2026-10-16 閻ㄥ嫭鍩呴崶鐐劀閺勵垵绻栨稉顏勮埌閻?*閿涘牆銇囩亸渚€娼伴崣鐘垫絻濮濆矁鐦濋敍澶堚偓?
   *   閳?閸掔姵甯€娑斿鎮?`t` 閻?`onSwiperContentDidScroll()` **闁劕鎶?*閸愭瑱绱欑€规ɑ鏌?SDK閿?
   *      "invoked ... on a frame-by-frame basis"閿涘绱?*娑撳秳绶风挧鏍︽崲娴?閸欐垹鏁撴潻鍥︾濞嗏剝绮﹂崝?**閵?
   * ```
   *
   * 閳跨媴绗?娑撳骸鐣犳稉鈧挧铚傜瑝閸愬秷顫︽担璺ㄦ暏閻ㄥ嫯绻曢張澶涚窗`lyricSwiperSettled` / `lyricFlightSettled`閿涘牓鍋呯€?娑撱倝妫堕幓鈩冨"閿?
   *    娑?`LYRIC_MORPH_DURATION_MS`閵嗗倸鐣犳禒?*娣囨繄鏆€娑撳搫鐡у▓?鐢悂鍣?*閿涘牆绐橀弽鍥︾矝閹垫挸宓冮崜宥勮⒈娑擃亷绱氶敍?
   *    娴?*濞屸剝婀佸〒鍙夌厠閻劑鈧?* 閳ユ柡鈧?閼汇儳鈥樼拋銈勭瑝闂団偓鐟曚緤绱濋崣顖欎簰閺佸绮嶉崚鐘冲竴閵?
   * 閳跨媴绗?`lyricMorphVisible` / `lyricMorphOpacity` 閻滄澘婀?*閸欘亣顫﹀鑺ョ垼鐠?*閿涘奔绗夐崘宥夋，娴ｅ繋鎹㈡担鏇犵帛閸?
   *    閿涘牊鍨滈幎濠傚弿闁劍绉风拹鍦仯濞撳懐鍋ｆ潻鍥风窗闂勩倓绨＄挧瀣偓鑲╁仯閿涘苯褰ч張?`refreshDiagText` 閸︺劏顕伴敍澶堚偓?
   *    閳?閹碘偓娴?閺嶅洤绻斿▽陇顫︽径宥勭秴"娑撳秳绱伴柅鐘冲灇娴犺缍嶇憴鍌涘妳闂傤噣顣介敍鍫ｇ箹娑撯偓閻愯妲?*濞撳懐鍋ｉ崙鐑樻降閻?*閿涘奔绗夐弰顖涘腹閺傤叏绱氶妴?
   */

  /**
   * `Swiper.onContentDidScroll` 閻ㄥ嫬顦╅悶鍡楁珤 閳ユ柡鈧?**閺冪姷鏅惃鍕箻鎼达附绨?*閿涘牓鈧劖娼悡褎濡遍敍澶堚偓?
   *
   * 閳藉應妲勯埥?2026-10-16閿?*娣囶喚鏁ら幋宄扮杽濞村鈧本鐡曠拠宥夈€夌亸渚€娼板▽鈥冲綁鐏忓繈鈧礁褰旈崷銊︾摃鐠囧秳绗傞棃顫偓宥囨畱閺?*閿?
   *
   * ## 娑撹桨绮堟稊鍫濈箑妞ょ粯婀佺€瑰喛绱欓崢鐔告降閻ㄥ嫰鈹嶉崝銊︾爱閺勵垶鏁婇惃鍕剁礆
   * 閸樼喐娼?`lyricMorphT` **閸?*閻?`.onAnimationStart` 妞瑰崬濮╅敍宀冣偓宀勫亝娑擃亜娲栫拫鍐ㄧ敨娑撯偓娑擃亜鐣ч崡?
   * 閵嗗畭index === targetIndex` 閳?鐠哄疇绻冮妴宥冣偓鍌欒⒈缁夊秵鍎忛崘鍏哥瑓鏉╂瑤閲滅€瑰牆宕兼导姘愁唨閺佹潙顨滄鐐额攽**濮樻瓕绻欐稉宥呮儙閸?*閿?
   *   璺?妞ょ敻娼伴崚鍥ㄥ床娑撳秵妲?娑撯偓濞嗭紕婀″鎴濆З"閿涘牅绶ユ俊?swiper 鐞氼偆鈻兼惔蹇撳閸掑洭銆夐妴浣瑰灗闁插秵瀵曟潪鑺ユ閸掓繂顫愭い闈涙皑娑撳秵妲?0閿涘绱?
   *   璺?闁插秵瀵曟潪钘夋倵"妞?娑?閻樿埖鈧?娑撳秳绔撮懛杈剧礄`onAppear` 婢跺秳缍呮潻鍥╁偍瀵洩绱氶妴?
   * 閳?`lyricMorphT` 閹?0 閳?鐏忎線娼伴幁鎺嶈礋婢堆冪殱闂堫澁绱濋懓灞剧摃鐠囧秵顒滈弬鍥╁弾閺嶉攱妯夌粈?閳?
   *   **鐏炲繋绗傜亸杈ㄦЦ"婢堆冪殱闂堛垹褰旈惈鈧宀冪槤"**閿涘牏鏁ら幋?2026-10-16 閹搭亜娴橀敍澶堚偓?
   *
   * ## 閺冪姷鏅惃鍕粵濞夋洩绱檂wujie.pa` L190026-190075閿涘苯鐣剧粙?鎼?.2 闁劖娼潪顒€鍟撻敍?
   * ```ts
   *   let p = position;
   *   if (index === 0) {              // 閳?閸欘亜婀?瑜版挸澧犳い鍨Ц閹绢厽鏂佹い?鏉╂瑤绔存笟褍缍婃稉鈧崠?
   *     if (p < 0) { p = -p; }        //    瀵扳偓閸撳秵绮﹂弮?position 娑撻缚绀?閳?缂堢粯顒?
   *     if (p > 1) { p = 1; }         //    娑撳﹤銇欓崚?1
   *     this.swiperProgress = p;
   *   }
   *   publishCoverStyle(); syncMotion();
   *   if (this.swiperProgress > 0.5 && !this.chromeHidden) { this.showChrome(); }
   * ```
   *   閳跨媴绗?**閸氬骸宕愬▓纰夌礄濮濆矁鐦濇い鐢稿亝娑撯偓娓氀嶇礆娣囨繃瀵旀稉濠佺濞嗭紕娈戦崐?* 閳?**閸嬫粌婀宀冪槤妞ゅ灚妞?`p` 閹帊璐?1**閵?
   *   閳跨媴绗?閺冪姷鏅柇锝堢珶 `onChange` **娑撳秴鍟?* `swiperProgress`閿涘牆鐣犻崣顏勪粵 idle/chrome 娑?
   *      `atLyricScreen = (v === 1)`閿涘鈧柡鈧?閹碘偓娴犮儲婀伴弬瑙勭《閹靛秵妲搁崬顖欑閸愭瑧鍋ｉ妴?
   *
   * ## 閹存垳婊戦惃鍕复濞夋洩绱欓崥灞肩娴犲€燁嚔娑斿绱?
   * `lyricMorphT` 鐏忚鲸妲搁張顑跨波閻?`swiperProgress`閿? = 鐏忎線娼版い鐢殿伂 / 1 = 濮濆矁鐦濇い鐢殿伂閿涘绱?
   *   璺?閸忓牊濡哥槐銏犵穿鐠佹媽澶勯敍鍧刼nChange` 閸?缁嬪绨崠鏍у瀼妞?閺冭泛褰查懗鎴掔瑝鐟欙箑褰傞敍宀冪箹闁插矂鈧劕鎶氶柈鑺ユ箒閸婄》绱氶敍?
   *   璺?閸愬秵濡歌ぐ鎺嶇閸栨牕鎮楅惃?`p` 閸犲倻绮?`lyricMorphT`閿?*闁劕鎶?*閿涘奔绗岄弮鐘垫櫕閸氬矉绱氶敍?
   *   璺?閻掕泛鎮楃拫?`syncLyricMorphToPage()` 閸?闂堟瑦顒涚粩顖滃仯韫囧懘銆忕粵澶夌艾瑜版挸澧犳い?閻ㄥ嫬鍘规惔?
   *     閿涘牐娉曟潻?0.5 閺冭泛鐣犳导姘乘夋稉鈧▎鈽呯礉娣囨繆鐦夋稉宥勭窗閸嬫粌婀稉銈囶伂娑斿妫块敍澶堚偓?
   *   閳跨媴绗?妞ゅ搫鐢幎濠冩￥閻ｅ矂鍋呴崣?`if (p > 0.5 && !chromeHidden) showChrome()` 娑旂喐鎯夋潻鍥ㄦ降 閳ユ柡鈧?
   *      鐎瑰啫姘ㄩ弰?濠婃垵鍩屾稉鈧崡濠冨Ω閹貉冨煑閸栧搫鏁滈崙鐑樻降"閻ㄥ嫭澧滈幇鐔粹偓?
   * @param index 瑜版挸澧犳い纰夌礄0 = 鐏忎線娼版い纰夌礉1 = 濮濆矁鐦濇い纰夌礆
   * @param position 閸愬懎顔愰惄绋款嚠娑撴槒閰辩挧椋庡仯閻ㄥ嫮些閸斻劍鐦笟瀣剁礄鐎规ɑ鏌?SDK 閸樼喐鏋冮敍?
   */
  private onSwiperContentDidScroll(index: number, position: number): void {
    this.diagScrollCount = this.diagScrollCount + 1;
    this.diagScrollLast = `${index}/${position.toFixed(3)}`;
    // 閳光偓閳光偓 闁劖娼悡褎濡遍弮鐘垫櫕閻ㄥ嫬缍婃稉鈧崠?閳光偓閳光偓
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
    // 鐠佹媽澶?濠婃艾濮╂禒宥呮躬鏉╂稖顢?閿涘牐顫?`lastScrollAtMs` 閻ㄥ嫭鏁為柌濠忕窗閽€钘夌暰韫囧懘銆忕拋鈺€缍呯紒娆撯偓鎰姎鏉╂稑瀹抽敍?
    this.lastScrollAtMs = Date.now();
    // 缁便垹绱╃拋鎷屽閿涘潉onContentDidScroll` 闁劕鎶氶柈鐣岀舶 `index`閿涘本鐦?`onChange` 閺囨潙褰查棃鐙呯礆
    if (index !== this.playbackSwiperIndex) {
      this.playbackSwiperIndex = index;
    }
    // 闂堟瑦顒涚粩顖滃仯閸忔粌绨抽敍姘虫硶鏉?0.5 娑斿鎮楅幎?`t` 閽€钘夌暰閸掓澘缍嬮崜宥夈€夌€电懓绨查惃鍕伂閻?
    // 閿涘潉syncLyricMorphToPage()` 閸愬懘鍎撮獮鍌滅搼閿涘奔绗栨鐐额攽娑擃厺绗夋导姘ⅵ閺傤叀藟闂傝揪绱?
    this.syncLyricMorphToPage('scroll');
    // 閺冪姷鏅崥灞绢儥閿涙碍绮︽潻鍥у磹缁嬪姘ㄩ幎濠冨付閸掕泛灏崬銈呭毉閺夈儻绱檂chromeHidden` 娑撳搫浜ｉ弮鑸靛閸炪倧绱?
    if (this.lyricMorphT > 0.5 && !this.chromeCollapsed) {
      this.touchChrome();
    }
  }

  /**
   * 閹?鐏忎線娼板ù顔肩湴妞嬬偠顢戞潻娑樺'**鐎靛綊缍堥崚鏉跨秼閸撳秹銆?* 閳ユ柡鈧?娑撳秳绶风挧?閸欐垹鏁撴潻鍥︾濞嗏剝绮﹂崝?閵?
   *
   * 閳藉應妲勯埥?2026-10-16閿?*娣囶喚鏁ら幋宄扮杽濞村鈧本鐡曠拠宥夈€夌亸渚€娼板▽鈥冲綁鐏忓繐褰旈崷銊︾摃鐠囧秳绗傞棃顫偓?*閿?
   *
   * ## 閻劍鍩涢惃鍕潎鐎电噦绱欓崘鍐茬暰閹嶇礆
   * 閹搭亜娴橀柌?*濮濆苯鎮?濮濆本澧?濮濆矁鐦濆锝嗘瀮閺勵垰甯囬崷銊ョ殱闂堫澀绗傞惃?* 閳ユ柡鈧?闁絾妲?*鐏忎線娼版い鐢稿亝娑撯偓缁旑垳娈戝ù顔肩湴娴ｅ秶鐤?*
   * 閿涘牊鐡曢崥宥呮躬鐏忎線娼版稉瀣煙 `META_GAP_BELOW_COVER(50)`閵嗕礁鐨濋棃銏℃Ц閺佸鐛ラ柇锝勭娴?331閿涘鈧?
   * 閼板本鐡曠拠宥嗩劀閺?*瀹歌尙绮￠弰鍓с仛閸戠儤娼垫禍?*閿涘牓鍋呴棁鈧憰?swiper 閸︺劎顑?2 妞ょ绱氶妴?
   * 閳?娑撱倓娆㈡禍瀣倱閺冭埖鍨氱粩瀣涧閺堝绔寸粔宥埿掗柌濠忕窗**妞ら潧鍨忔禍鍡礉濞搭喖鐪板▽陇绐?*閿涘牆绐橀弽?`edge=331 t=0.00` 濮濓絾妲哥€瑰喛绱氶妴?
   *
   * ## 娑撹桨绮堟稊鍫濆斧閺夈儳娈戦崘娆愮《娴兼碍绱?
   * `lyricMorphT` 閻ㄥ嫬鏁稉鈧す鍗炲З閻愯妲?`.onAnimationStart`閿涘矁鈧苯鐣犵敮锔跨娑擃亜鐣ч崡?
   * 閵?*瀹歌尙绮￠崷銊ф窗閺嶅洭銆夋禍鍡楁皑鐠哄疇绻?*閿涘潉index === targetIndex`閿涘鈧秲鈧倷绨弰顖氬涧鐟曚礁鍤悳?
   * "瑜版挸澧犳い?= 濮濆矁鐦濇い鐐光偓浣解偓?`lyricMorphT` 娴犲秵妲?0"鏉╂瑧顫?*娑撳秳绔撮懛瀵告畱閸掓繂顫愰幀?*閿涘苯姘ㄩ崘宥勭瘍濞屸剝婀佹禒璁崇秿娑撴粏銈挎导姘箵娣囶喗顒滅€瑰喛绱?
   *   璺?鏉╂稒鎸遍弨鎯ф珤閺冩儼瀚㈢槐銏犵穿瀹稿弶妲?1閿涘牅绗傛稉鈧潪?`onAppear` 婢跺秳缍呮潻?0閵嗕焦鍨ㄧ槐銏犵穿閺夈儴鍤滈崚顐㈩槱閿涘鍣?鐎瑰牆宕奸惄瀛樺复鐠哄疇绻冮敍?
   *   璺?閼哄倻鍋ｉ柌宥呯紦閸?`onAppear` 閹?`lyricMorphT` 瑜版帒鍩?瑜版挸澧犳い闈涱嚠鎼存梻娈戠粩顖滃仯"閳ユ柡鈧?
   *     閼?*瑜版挸澧犳い?*鏉╂瑤閲滈崐鍏兼拱闊偉瀚㈡稉?swiper 鐎圭偤妾崑婊呮畱妞ゅ吀绗夋稉鈧懛杈剧礉瑜版帒鍤弶銉ф畱鐏忚鲸妲搁柨娆戞畱缁旑垳鍋ｉ妴?
   *
   * ## 濮濓絿鈥橀惃鍕彠缁紮绱欓崡鏇氱閻喐绨敍?
   * ```
   *   playbackSwiperIndex閿涘牆缍嬮崜宥夈€夐敍? 閳光偓閳光偓閸愬啿鐣鹃埞鈧埞鈧埢? lyricMorphT 閻?*闂堟瑦顒涚粩顖滃仯**
   *                                        閿? = 鐏忎線娼版い鐢稿亝娑撯偓缁旑垽绱? = 濮濆矁鐦濇い鐢稿亝娑撯偓缁旑垽绱?
   *   濠婃垵濮╂潻鍥┾柤娑擃厾娈戠悰銉╂？閸欘亝妲?娴犲簼绔存稉顏嗩伂閻愮铔嬮崚鏉垮綗娑撯偓娑擃亞顏悙?閿?
   *   閼?*闂堟瑦顒涢幀?*濮樻瓕绻欑粵澶夌艾"瑜版挸澧犳い闈涱嚠鎼存梻娈戠粩顖滃仯"閵?
   * ```
   * 閳?閺堫剚鏌熷▔鏇炴皑閺勵垶鍋呴弶鈥冲彠缁崵娈戠€圭偟骞囬敍姘辩彌閸楄櫕濡?`t` 缂冾喖鍩岃ぐ鎾冲妞ら潧顕惔鏃傛畱缁旑垳鍋ｉ敍鍫滅瑝閸斻劎鏁鹃敍澶堚偓?
   *   璺?娑撳孩绮﹂崝銊よ厬閻ㄥ嫯藟闂?*娑撳秴鍟跨粣?*閿涙俺藟闂傛潙褰ч崷?`lyricMorphVisible === true`閿涘牓顥ｇ悰灞艰厬閿涘妞傞幍宥嗘箒閹板繋绠熼敍?
   *     閼板本婀伴弬瑙勭《閸欘亜婀?闂堟瑦顒涢幀浣风瑓閸欐垹骞囨稉宥勭閼?閺冩儼顫︾拫鍐暏閿涘牐顫嗙拫鍐暏閻愮櫢绱氶妴?
   *   璺?楠炲倻鐡戦敍姘嚒缂佸繐婀锝団€樼粩顖滃仯閺冭泛鍟撻崥灞肩娑擃亜鈧》绱濇稉宥埿曢崣鎴滄崲娴ｆ洟鍣哥紒妯烘▕瀵倶鈧?
   *
   * 閳跨媴绗?鐠嬪啰鏁ら悙鐧哥窗`aboutToAppear()`閿涘牓銆夐棃銏″瘯鏉炶姤妞傜€靛綊缍堟稉鈧▎鈽呯礆娑撳骸鍞寸€圭懓鐪?`.onAppear()`
   *    閿涘牐濡悙鐟板毉閻滅増妞傜€靛綊缍堟稉鈧▎鈽呯礆閵?*娑撳秷顩?*閺€鎹愮箻濠婃垵濮╅崶鐐剁殶闁插矉绱欓柇锝勭窗閹垫挻鏌囩悰銉╂？閿涘鈧?
   * @param reason 閸欘亞鏁ゆ禍搴㈡）韫囨绱檂boot` / `appear`閿?
   */
  private syncLyricMorphToPage(reason: string): void {
    const want: number = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
    // 閳藉應妲勯埥?2026-10-16閿?*鐠佲晙缍呯紒娆撯偓鎰姎鏉╂稑瀹?*閿涘矁顫?`lastScrollAtMs` 閻ㄥ嫭鏁為柌濠忕礆閿?
    //   `onContentDidScroll` 濮濓絽婀柅鎰姎閸?`lyricMorphT` 閺冭绱濇潻娆撳櫡**娑撳秷顔忛拃钘夌暰** 閳ユ柡鈧?
    //   閸氾箑鍨稉銈堚偓鍛槨鐢傜鞍閻╁憡濮犻崐纭风礄濠婃垵鍩屾稉鈧崡濠咁潶娑撯偓閹跺﹨顔曢崚鎵伂閻?閳?閻㈠娼扮捄绛圭礆閵?
    //   閳跨媴绗?`boot` 闁絾顐?*韫囧懘銆忛弨鎹愵攽**閿涘牓銆夐棃銏″瘯鏉炶姤妞傛潻妯荤梾閺堝鎹㈡担鏇熺泊閸旑煉绱漙lastScrollAtMs` 娑?0閿涘鈧?
    if (reason !== 'boot' && Date.now() - this.lastScrollAtMs < PlaybackPage.SCROLL_SETTLE_WINDOW_MS) {
      return;
    }
    if (this.lyricMorphVisible && Math.abs(this.lyricMorphT - want) < 0.999) {
      // 妞嬬偠顢戞稉顓濈瑬鏉╂ɑ鐥呴崚鎵伂閻?閳?閸掝偅澧﹂弬顓∷夐梻杈剧礄鏉╂瑦娼崣顏勬躬閺嬩胶顏弮璺虹碍娑撳澧犻崣顖濆厴閸涙垝鑵戦敍?
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
   * 閺€璺虹啲閿涙瓔wiper 閼奉亜绻侀惃鍕瀼閹广垹濮╅悽璁崇瑢濞搭喖鐪版鐐额攽**闁晫绮ㄩ弶?*娑斿鎮楅幍宥呭祻閹?妞嬬偠顢戞稉?鏉╂瑤绔村锝冣偓?
   *
   * 閳跨媴绗?鏉╂瑩鍣?*娑撳秵妲?*閹跺﹤鐨濋棃顫閸掆偓閸掑洦甯€閿涙碍璇炵仦鍌涙Ц**鐢悂鈹?*閻ㄥ嫸绱濋拃鎴掔秴閸氬簼绮涢悽?`playbackSwiperIndex`
   * 閸掑棙鏁崘鍐茬暰鐎瑰啳鎯ら崷銊ユ憿娑擃亞顏悙鐧哥礄濮濆矁鐦濇い鐢告饯濮濄垺鈧椒绮涢悞鎯邦洣閺勫墽銇氶柇锝呯炊鐏忓繐鐨濋棃?+ 濮濆苯鎮曢敍澶堚偓?
   * 閸樼喐娼甸惃鍕晸濞夋洘妲?`lyricMorphVisible = false` 閺冪姵娼禒璺哄晸濮?閳?閺佹潙顨滃宀冪槤妞ら潧鐨濋棃銏犺埌閸欐ɑ妲搁崗宕囨絻閻ㄥ嫨鈧?
   *
   * ## 閳藉應妲?2026-10-16閿?*瀹告彃鍨界€规矮璐熷璁冲敩閻緤绱濇穱婵堟殌娑撳秴鍨?*閿?
   *
   * 娑撱倓閲滈悶鍡欐暠閿涘矂鍏橀弰顖涚閻愮懓鍤弶銉ф畱閿?
   * 1. 閺堫剙鍤遍弫鎷岊洣濮?`lyricSwiperSettled && lyricFlightSettled` **娑撱倝妫堕柈钘夊煂娴?*閿?
   *    閼板瞼鐤?`lyricFlightSettled = true` 閻?*閸烆垯绔?*閸︾増鏌熼崢鐔告降閸?`animateLyricMorph()` 閻ㄥ嫭鏁圭亸?
   *    `setTimeout` 闁?閳ユ柡鈧?闁絼閲滈弬瑙勭《閺堫剝鐤嗗鏌ユ"閺€纭呯箻鎼达箓鈹嶉崝?娑撯偓鐠у嘲鍨归梽銈忕礄鐟欎焦鏋冩禒鏈电瑐閺傚綊鍋呭▓浣冾嚛閺勫函绱?
   *    閳?`lyricFlightSettled` 濮樻瓕绻欓弰?`false`閿涘牓娅庨棃?`syncLyricMorphToPage()` 閽€钘夌暰閺冨墎鐤嗛惇鐕傜礉
   *      娴ｅ棝鍋呴弶陇鐭炬稉?`lyricMorphVisible` 瀹歌尙绮＄悮顐㈢暊閼奉亜绻佺純顔藉灇 `false`閿?
   *    閳?閺堫剙鍤遍弫?*韫囧懐鍔ч崷銊ь儑娑撯偓娑?`if` 婢跺嫯绻戦崶?*閵?
   * 2. 閺堫剙鍤遍弫鏉垮涧閸?`lyricMorphVisible` / `lyricMorphOpacity` 娑撱倓閲滅€涙顔岄敍?
   *    閼板矁绻栨稉銈勯嚋鐎涙顔?*閻滄澘婀崣顏囶潶瀵拌姤鐖ｇ拠?*閿涘牆鍙忛柈銊︾Х鐠愬湱鍋ｅ鍙夌閻愮櫢绱氶埇?閸楀厖濞囩€瑰啳绐囬崚棰佺啊娑旂喐鐥呴張澶嬭閺屾挸濂栭崫宥冣偓?
   *
   * 閳?娣囨繄鏆€閼板奔绗夐崚鐘垫畱閻炲棛鏁遍敍姘暊閺?娑撱倝妫堕幓鈩冨"闁絽顨滅拋鎹愵吀閻ㄥ嫭鏁圭亸鍓ь伂閿?*閼汇儱鐨㈤弶銉︿划婢跺秷藟闂傛挳鈹嶉崝?*
   *    閿涘牅绶ユ俊鍌氬絺閻滄媽绻樻惔锕傗攳閸斻劌婀弻鎰嚋閺堝搫鐎锋稉濠佺瑝閸欘垳鏁ら敍澶愭付鐟曚礁鐣犳稉鈧挧閿嬩划婢跺稄绱?
   *    閸掔姳绨＄亸鍗炵繁娴?git 閸樺棗褰堕柌灞惧船閵?*鐎瑰啩绗夋导姘箒鐎?*閿涘牆绻€閻掕埖妫柅鈧妴浣风瑬閸欘亜鍟撳鑺ョ垼鐠囪崵娈戠€涙顔岄敍澶堚偓?
   * 閳跨媴绗?閼汇儳鈥樼拋銈堢箻鎼达箓鈹嶉崝銊旂€规熬绱濋崣顖欎簰閹跺﹤鐣?+ `lyricSwiperSettled` / `lyricFlightSettled` /
   *    `LYRIC_MORPH_DURATION_MS` **閺佸绮嶉崚鐘冲竴**閵?
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
   * @returns 濞搭喖鐪伴柌灞界殱闂堛垻娈戞稉鈧敮褏鐓╄ぐ顫礄vp閿涘瞼鐛ラ崣锝呮綏閺嶅浄绱氶妴?
   *
   * 閳跨媴绗?2026-10-15閿涘牏顑?2 閸ф鐤洬閻╂牕鐪扮紒鐔剁閿?*閸掔姵甯€娴滃棔绗佹稉顏勫嚒濮濊崵娈戠粔浣规箒閺傝纭?*閿?
   *   璺?`lyricFloatActive()` 閳ユ柡鈧?鐎瑰啫甯弶銉︽Ц濞搭喖鐪伴惃鍕，閿涘牆褰ч崷?妞嬬偠顢戞稉?濮濆矁鐦濇い?閹靛秶鏁鹃敍澶涚幢
   *     鐟曞棛娲婄仦鍌涙暭閹?*鐢悂鈹?*娑斿鎮楀▽鈩冩箒娴犺缍嶇拫鍐暏閻愬箍鈧?
   *   璺?`lyricFloatMetaOpacity()` 閳ユ柡鈧?閸樼喐娼电拋鈺傜摃閸氬秴婀?`t=0` 鐎瑰苯鍙忛柅蹇旀閿涘牓鍋呮稉鈧崚璇茬殱闂堛垽銆夐柇锝勫敜濮濆苯鎮?
   *     閻?`MusicPlayInfoBlock` 閻紮绱氶敍娑€?0 娑撳秴鍟€閻㈣鐨濋棃?濮濆苯鎮曟稊瀣倵鐎瑰啯浜芥稉?1閵?
   *   璺?`lyricFloatMetaWidth()` 閳ユ柡鈧?濮濆苯鎮曢崸妤€甯弶銉︽寜楠炲啿鐪虫稉顓溾偓浣烘暏鐎瑰啰鐣婚崸妤€顔旈敍?
   *     閻滄澘婀弰?*娑撯偓濡亣顢?*閿涘牆涔忛崘鍛扮珶鐠烘繄鏁?`lyricMetaLeftInset()` 缂佹瑱绱氶敍灞肩瑝閸愬秹娓剁憰浣哥暊閵?
   *   閻╃鍙у▔銊╁櫞闁插苯鍤掓潻妯哄晸閻偓"闂傘劌婀?`lyricFloatActive()`"閻ㄥ嫬婀撮弬褰掑厴瀹告彃姘ㄩ崷鐗堟暭濮濓絻鈧?
   */
  private lyricFloatRect(): LyricMorphRect {
    return this.expandState.lyricMorph(this.lyricMorphT);
  }

  /**
   * @returns 鐏忎線娼伴柇锝勭鐏?*鐎圭偤妾憰浣稿晸鏉?`.position()` 閻ㄥ嫮鐓╄ぐ?*閿涘澊p閿涘鈧?
   *
   * 閳藉應妲勯埥?2026-10-16閿?*閹俱倕娲栭幋鎴滅瑐娑撯偓閻楀牏娈戦柅鍡楀綁閹?*閿涘瞼鏁ら幋宄扮杽濞村鈧苯鐨濋棃銏℃Ц妞嬬偛鍩岀仦蹇撶婢舵牓鈧稄绱氶敍?
   *
   * 娑撳﹣绔撮悧鍫熷灉閸︺劏绻栭柌宀冪殶 `coverLocalRectFor()` 閸?鐏炲繐绠烽崸鎰垼 閳?鐎圭懓娅掗張顒€婀撮崸鎰垼"閻ㄥ嫰鈧棗褰夐幑顫礉
   * 閸撳秵褰侀弰?**`.scale()` 缂佹洖顔愰崳銊よ厬韫?*閵嗗倻婀￠張杞扮瑐缂佹挻鐏夐弰顖氱殱闂?*妞嬬偛鍤仦蹇撶**閵?
   *
   * 閳跨媴绗?鏉╂瑤閲滈崜宥嗗絹閸︺劍婀版禒?*閺冣晛姘ㄩ張澶庣箖娑撯偓濞嗭紕婀￠張鍝勫冀鐠?*閿涘潉morphCoverRectAt()` 閻ㄥ嫭鏁為柌濞库偓?
   *   `LyricFloatLayer` 妞ゅ爼鍎?閳跨媴绗?2026-10-15 閸掔粯鍓版稉宥嗘暭"闁絼绔村▓纰夌礆閿?
   *   > 閵嗗矂鈧棗褰夐幑銏犳礀妞ら潧鍞撮崸鎰垼 閳ユ柡鈧?閻喐婧€缂佹挻鐏?**鐏忎線娼扮捄鎴濆煂瀹革缚绗傜憴?*"閿涘牐顕╅弰?`.scale()` 閻ㄥ嫭鐏戞潪?
   *   >   **娑撳秵妲搁幋鎴滀簰娑撹櫣娈戠€圭懓娅掓稉顓炵妇**閿涘鍣?鐠囥儲鏌熷鍫滅稊鎼寸噦绱?*閸掝偄鍟€鐠?*閵嗗倶鈧?
   *   閳?閹存垼绻栧▎锛勭搼娴?*閸樼喎婀撮柌宥堜刊娴滃棔绔撮柆?*閿涘本鏆€鐠侇叀顔囨潻?`RzdMusic鐠佹澘绻?md` 鎼?6閵?
   *
   * ## 閻滄澘婀?= 缁绢垰鍤戞担鏇樷偓?*娑撳秴浠涙禒璁崇秿閸ф劖鐖ｇ化缁樺床缁?*閿涘牆姘ㄩ弰顖滄暏閹撮鈥樼拋銈堢箖"閻滄澘婀锝呯埗娴?閻ㄥ嫰鍋呮稉鈧悧鍫礆
   *
   * ```
   *   鐏忓搫顕?/ 娴ｅ秶鐤?/ 閸﹀棜顫楁稉鈧瀣絿 lyricMorph(t)閿? 閺冪姷鏅?CoverMorph 閻ㄥ嫯绶崙鐚寸礆
   *   閻╁瓨甯撮崘娆掔箻 .position() / .width() / .borderRadius()
   * ```
   * 閺堫剙鐪伴幐鍌氭躬瑜般垹褰夌€圭懓娅?*閸愬懘鍎?*閿涘本澧嶆禒銉ヨ埌閸欐ü鑵戠€瑰啰娈?*鐎圭偤妾?*鐏炲繐绠锋担宥勭窗鐞氼偄顔愰崳銊ュ綁閹广垺灏撶挧?
   * 閿涘潉y' 閳?t璺痽`閿涘矁顫?`LyricFloatLayer` 妞ゅ爼鍎撮柇锝嗩唽閹恒劌顕遍敍澶嗏偓鏂衡偓?鏉╂瑦娼?閽€鎴掔秴閺冭埖顒滅涵顔衡偓浣歌埌閸欐ü鑵戦崑?
   * 閻ㄥ嫬褰涘?*閻劍鍩涢崷銊ф埂閺堣桨绗傛宀冪箖閵嗕浇顫囬幇鐔峰讲閹恒儱褰?*閿涘牆鐨濋棃銏ｇ閻偓鐎圭懓娅掓稉鈧挧椋庣級閸氭垼绯犳担鐘虫蒋閿涘鈧?
   * 閳跨媴绗?鐎瑰啯鍨氱粩瀣畱閸撳秵褰侀弰?`t = 1`閿涘牐鎯ゆ担宥忕礆閺冭泛顔愰崳銊︽Ц閹帞鐡戦崣妯诲床 閳ユ柡鈧?閼板矂鍋呭锝嗘Ц闂堟瑦顒涢幀渚婄礉閹帗鍨氱粩瀣ㄢ偓?
   */
  private coverLocalRect(): LyricMorphRect {
    return this.lyricFloatRect();
  }

  /** 娑撳﹣绔村▎?`RzdCoverLocal` 閻ㄥ嫯鎯ゆ担宥囶劮閸氬稄绱欓懞鍌涚ウ閻㈩煉绱濋崣顏勬躬閻喓娈戦崣妯圭啊閹靛秵澧﹂敍澶堚偓?*/
  private lastCoverLocalLog: string = '';
  /** `RzdCoverLocal` 閻ㄥ嫰鍣伴弽鐤Ν濞翠緤绱檓s閿涘苯鑸伴崣妯绘濮ｅ繐鎶氶柈鎴掔窗閸欐﹫绱濇径顏勭槕娴兼艾鍩涚仦蹇ョ礆閵?*/
  private static readonly COVER_LOCAL_LOG_MS: number = 100;
  private lastCoverLocalAtMs: number = 0;

  /**
   * 閳藉應妲勯埥?2026-10-16 閺傛澘顤冪拠濠冩焽閿?*鐏忎線娼伴拃鎴掔秴閻ㄥ嫭顒?閸欏秴褰夐幑銏狀嚠鐠?*閵?
   *
   * ## 鐎瑰啫鍨芥禒鈧稊?
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdCoverLocal'
   *   閳?RzdCoverLocal t=閳?s=閳?tx=閳?ty=閳?screen=(x,y,w,h,r) local=(x,y,w,h,r)
   * ```
   * 璺?`s = 1 / tx = ty = 0`閿涘牓娼ゅ銏♀偓渚婄礆閳?娑撱倓閲滈惌鈺佽埌韫囧懘銆?*闁劕鐡ч惄绋挎倱**閿涘牆寮介崣妯诲床閺勵垱浜界粵澶屾畱閿涘绱?
   * 璺?瑜般垹褰夋稉?閳?`local` 韫囧懘銆?*鏉╂粌銇囨禍?* `screen`閿涘牆娲滄稉楦款洣鐞?`s` 閸樺娲栭崢浼欑礆閿?
   *   娑?`local.x/y` 閸欘垵鍏樻稉楦跨閿涘牆鐨濋棃銏犳躬鐟佷礁澹€缁愭褰涙稊瀣樆閻ㄥ嫰鍋呮稉鈧幋顏庣礉鏉╂瑦妲稿锝呯埗閻ㄥ嫸绱氶敍?
   * 璺?**閸掋倖宓?*閿涙碍濡?`s / tx / ty` 娑?`screen` 娴狅綀绻樼€圭懓娅掗崣妯诲床
   *   `y_鐏?= H/2 + (y_閺?閳?H/2)s + d` 鎼存棁绻曢崢鐔峰毉 `screen.y` 閳ユ柡鈧?閼汇儴绻曢崢鐔剁瑝閸戠儤娼甸敍?
   *   鐠囧瓨妲戠€圭懓娅掗惃鍕亼鏉?鐏忓搫顕崑鍥啎娑撳骸鐤勯悳棰佺瑝缁楋讣绱欓柇锝嗘鐟曚焦鏁奸惃鍕Ц `coverHostH()`閿涘奔绗夐弰顖氱殱闂堫澁绱氶妴?
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

  // 閳跨媴绗?2026-10-16閿涙瓪SQUASH_MIN` / `squashWrapHVp()` / `squashWrapOffsetYVp()` **瀹告彃鍨归梽?*閵?
  //
  // 鐎瑰啩婊戦弰顖涘灉娑撳﹣绔撮悧鍫滆礋娴滃棜顔€"閼冲本娅欐稊鐔荤閻偓瀵?閼板苯濮為惃鍕鐏炲倽藟閸嬪灝顔愰崳?
  // 閿涘潉.height(winH 鑴?k)` + `.offset({y: 閳姶inH(1閳姙)/2})` + `.scale({y: k})`閿涘鈧?
  // 閺堫剝鐤嗛幎濠冩￥閻ｅ瞼娈?*鐏炲倻楠?*鐠囧鈧矮绠ｉ崥搴礉闁絼閲滅悰銉ヤ缉**閺佺繝閲滄稉宥夋付鐟曚椒绨?*閿?
  // 閺冪姷鏅惃?`MeshCoverBg` 鐏忓崬婀?*鐞?`scale/translate/clip` 閻ㄥ嫰鍋呮稉?Stack 闁插矂娼?*
  // 閿涘潉wujie.pa` 191388 闁絼閲?`PLAYER_ROOT_ID` 鐎圭懓娅掗敍宀冾潌 `build()` 闁插矂鍋呭▓闈涱啇閸ｃ劍鐖查敍澶涚礉
  // 閳?鐎瑰啫銇夐悞鎯扮閻偓鐎圭懓娅掓稉鈧挧椋庣級閵嗕椒绔寸挧鐤潶鐟佷降鈧椒绡冩径鈺冨姧閸︺劏鐭鹃悽鍗烇紦闁絾娼?`morphSquashY` 閻ㄥ嫪缍旈悽銊ョ厵闁插被鈧?
  // 閳?閼冲本娅欏鍙夊瘻閺冪姷鏅幖顒€娲栫€圭懓娅掗崘鍛村劥閿涘矁绻栨稉鈧仦鍌澦夐崑鑳箾閸氬苯鐣犻惃鍕埗闁插繋绔寸挧宄板灩閹哄鈧?

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 閹貉冨煑閸栭缚鍤滈崝銊︽暪鐠?閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?閳藉應妲勯埥?閻滄澘婧€閼奉亣鐦夊鑺ョ垼閿?*娑撳秳绶风挧?hdc**閿涘鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜
  //
  // ## 娑撹桨绮堟稊鍫濆鐎?
  //
  // 閵嗗瞼鍋ｉ崙缁樺ⅵ瀵偓 / 閻愮懓鍤崗鎶芥４ / 缁崵绮烘潻鏂挎礀濞屸剝婀佺亸渚€娼伴崝銊ф暰閵嗗秷绻栭弶锟犳６妫版﹫绱濋張顒冪枂瀹歌尙绮￠弨閫涚啊 3 婢?
  // 閿涘煪?2 閼冲本娅欐稉宥夆偓蹇旀鎼?/ 鎼?3 閹稿倽娴囬崚銈嗗祦 / 鎼?4 缂佸牏鍋ｉ柨姘卞仯闁插繑绁撮梻顭掔礆閿涘奔绲?*閻劍鍩涙稉宥堝厴閻?hdc**閿?
  // 閹存垶瀣佹稉宥呭煂 `RzdCoverLocal` / `RzdMorphOwnership` 闁絼绨洪弮銉ョ箶 閳?閸欘亣鍏橀棃?閺€閫涚啊閸愬秷顔€閻劍鍩涚憗?閿?
  // 閼板矁绻栭弶锟犳懠娑撳﹥婀?5~6 娑擃亜鍨介弬顓ㄧ礉**閻╁弶鏁奸惃鍕敩娴犲嘲鍑＄紒蹇氼潶鐠囦焦妲戦弸浣搞亣**閿涘煪?6~鎼?4 閸?8 鏉烆噯绱氶妴?
  //
  // 閳?閸旂姳绔存稉?*妞ょ敻娼版稉濠勬纯閹恒儲妯夌粈鍝勫灲閹?*閻ㄥ嫬鐨鑺ョ垼閿涙氨鏁ら幋椋庡仯瀵偓閹绢厽鏂侀崳銊ユ倵閹跺﹤鐫嗘稉濠囧亝娑撱倛顢戦弫鏉跨摟韫囬潧鍤弶銉礉
  //   閹存垵姘ㄩ懗鎴掔濞嗏€崇暰娴ｅ秴鍩岄崗铚傜秼閸濐亙绔存稉顏勫灲閺傤厺璐熼崑鍥モ偓?*鐟佸懍绔村▎锟犮€婇崡浣诡偧閻╁弶鏁奸妴?*
  //
  // ## 閻劍纭堕敍鍫㈡暏閹磋渹鏅堕敍?
  // ```
  //   璺?鏉╃偟鍋ｉ幘顓熸杹妞ょ敻銆婇柈?3 濞嗏槄绱欓悙?鏉╂柨娲?瀵扳偓閸欏厖绔撮悙褰掑亝閻楀洨鈹栭惂鏂ょ礉閹存牜鍋ｅ灞芥倳/濮濆本澧滈柇锝勭鐞涘矉绱?
  //   璺?鐏炲繋绗傞崙铏瑰箛娑撯偓鐏忓繐娼℃鎴濈俺閻ц棄鐡ч敍灞借埌婵″偊绱?
  //       V 8f3a2c1 sess=1 usable=1 cont=1 clip=1 scale=0.082 p=0.000
  //       real=0 clone=1 snap=330/56 end=328/328 op=0.040 stage=1 drv=2
  //   璺?閹跺﹨绻栨稉銈堫攽韫囩數绮伴幋鎴礄閹存牗鍩呴崶鎾呯礆閸楀啿褰查敍娑樺晙閻?3 濞嗏€冲讲閸忚櫕甯€
  // ```
  // 閳跨媴绗?**鐎瑰啫褰ч崷銊ㄧ箾閻?3 濞嗏€茬閸氬孩澧犻崙铏瑰箛** 閳?濮濓絽鐖堕幆鍛枌娑撳鏁ら幋宄扮暚閸忋劎婀呮稉宥呭煂閿涘奔绗夎ぐ鍗炴惙鐟欏倹鍔呴妴?
  // 閳跨媴绗?缁绢垰褰х拠浼欑窗娑撳秴鍟撴禒璁崇秿娑撳骸濮╅悽缁樻箒閸忓磭娈戦悩鑸碘偓渚婄礄閸欘亜鍟?`diagBadgeOn` / `diagText` 娑撱倓閲滈張顒勩€夌€涙顔岄敍澶堚偓?
  //
  // 閳藉應妲勯埥?2026-10-17閿?*瀵偓閸忚櫕鏁奸幋鎰硶鐎圭偘绶ョ拋鏉跨箓** 閳ユ柡鈧?閻╁瓨甯存稉杞扮啊"鐏忔垼顔€閻劍鍩涢惂鍊熺獓娑撯偓鏉?閿涘绱?
  //   瀵拌姤鐖ｇ粭顒€宕勬稉澶庮攽鐠囪崵娈戦弰?*闂堟瑦鈧?*娴滃娆㈤弮銉ョ箶閿涘牅绗傛稉鈧▎鈥冲彠闂傤厾娈戦崗銊ㄧ箖缁嬪绱氶敍宀冣偓宀冾嚢鐎瑰苯鐣犻惃鍕崝鎸庢Ц
  //   閵嗗苯鍙ч梻?閳?**闁插秵鏌婇幍鎾崇磻閹绢厽鏂佹い?* 閳?閹垫挸绱戝鑺ョ垼 閳?閹搭亜娴橀妴宥冣偓鍌氬讲 `diagBadgeOn` 閸樼喐娼甸弰?*鐎圭偘绶ョ仦鈧柈?*閻?
  //   閳?濮ｅ繑顐奸柌宥嗘煀閹垫挸绱戦柈钘夋礀閸?閸?閿涘瞼鏁ら幋宄扮繁**閸愬秷绻涢悙?3 濞?*閹靛秶婀呭妤€鍩?閳ユ柡鈧?婢舵矮绔村銉ユ皑婢舵矮绔村▎陇顕版稉宥呭煂閻ㄥ嫰顥撻梽鈹库偓?
  //   閳?閸旂姳绔存稉顏堟饯閹線鏆呴崓蹇ョ窗**瀵偓娑撯偓濞嗏€虫皑娑撯偓閻╁瓨妲稿鈧惃?*閿涘牏娲块崚鏉垮晙鏉╃偟鍋?3 濞嗏€冲彠閹哄绱濋幋鏍箻缁嬪鍣搁崥顖ょ礆閵?
  private static diagBadgeOnStatic: boolean = false;
  @Local private diagBadgeOn: boolean = PlaybackPage.diagBadgeOnStatic;
  @Local private diagText: string = '';
  private diagTapCount: number = 0;
  private diagTapLastMs: number = 0;
  /**
   * 閳?閼奉亣鐦夌拋鈩冩殶閿涘牆褰х紒娆忕獦閺嶅洨鏁ら敍灞肩瑝瑜板崬鎼锋禒璁崇秿闁槒绶敍澶涚窗
   * 璺?`diagRemeasureTries` 閳ユ柡鈧?`onAppear` 闁插矂鍋呭▎鈥冲殤娴ｆ洝藟闁插繗顫︾拫鍐暏娴滃棗鍤戝▎鈽呯幢
   * 璺?`diagOverlayKicks`   閳ユ柡鈧?閸忔湹鑵?鐞涖儵鍣洪幋鎰閸氬酣銆庨幍瀣崳娴滃棙璇炵仦鍌澦夐梻?閸戠姵顐奸妴?
   * ```
   *   娑撱倛鈧懘鍏?0 閳?闁絾顔屾禒锝囩垳閺嶈婀板▽陇绐囬崚甯礄`onAppear` 鐠ч绨￠崚顐ゆ畱閸掑棙鏁敍?
   *   1 / 1    閳?鐞涖儵鍣烘稉搴ゆ崳濡帡鍏橀崣鎴犳晸娴?閳?閼汇儱鐨濋棃顫矝娑撳秹顥ｉ敍宀勬６妫版ê婀崙鐘辩秿閸婄》绱欓惇?snap / end閿?
   *   1 / 0    閳?鐞涖儵鍣虹捄鎴滅啊娴?`morphUsable` 娴犲秳璐熼崑?閳?閻?usable / end 娑撱倕鍨?
   * ```
   */
  private diagRemeasureTries: number = 0;
  private diagOverlayKicks: number = 0;

  /**
   * 閳藉應妲勯埥?2026-10-16閿?*Swiper 閸ョ偠鐨熺€圭偛寮拋鏉跨秿** 閳ユ柡鈧?娣?濮濆矁鐦濇い闈涚殱闂堛垺鐥呴崣妯虹毈"閻?*閸愬啿鐣鹃幀?*鐠囩粯鏆熼敍?
   *
   * 娑撹桨绮堟稊鍫濈箑妞ゆ槒顔囩€瑰喛绱版稉濠佺閹佃鍨滈崷銊ㄧ箹閺夛繝鎽兼稉濠勬暏**闂堟瑦鈧焦甯归悶?*閸︺劋琚辩粔宥呬海鐠佸彞绠ｉ梻瀛樻啚閹?閳ユ柡鈧?
   * ```
   *   閸嬪洩顔?A閿涙瓪.onAnimationStart` **閺嶈婀板▽陇袝閸?*閿涘牆鍨忔い鍨梾鐠х増绮﹂崝銊ユ礀鐠嬪喛绱?
   *   閸嬪洩顔?B閿涙俺袝閸欐垳绨℃担?*鐞氼偄鐣ч崡顐ｅ皡閹?*閿涘潉index === targetIndex`閿?
   * ```
   * 娑撱倛鈧懐娈戞穱顔界《**鐎瑰苯鍙忔稉宥呮倱**閿涘湏 鐟曚礁婀幐鍌濇祰/閸掑洭銆夐弮鎯八夋稉鈧▎鈥愁嚠姒绘劧绱盉 鐟曚焦鏁肩€瑰牆宕奸惃鍕灲閹诡噯绱氶敍?
   * 閼板苯褰ч張澶屾埂閺堥缚顕伴弫鎷屽厴閸掑棜椴搁妴鍌楀櫩 鐠侀绗呴弶銉礉娑撯偓濞嗏€崇暰娴ｅ秲鈧?
   *
   * 鐠囩粯纭堕敍鍫濈獦閺?*缁楊剙鍙撶悰?*閿涘绱?
   * ```
   *   ast=<index>-<target>   娓?`ast=0-1` = 娴犲海顑?0 妞ゅ灚绮﹂崥鎴狀儑 1 妞ょ绱欏锝呯埗閸掑洤鍩屽宀冪槤妞ょ绱?
   *                          `ast=-1--1` = **鏉╂瑤閲滈崶鐐剁殶娑撯偓濞嗭繝鍏樺▽陇绻橀弶銉ㄧ箖**閿涘牆浜ｇ拋?A 閹存劗鐝涢敍?
   *   skp=<鐎瑰牆宕奸幐鈩冨竴閻ㄥ嫭顐奸弫?   > 0 閼?ast 閺堝鈧?閳?閸嬪洩顔?B 閹存劗鐝涢敍鍫濇礀鐠嬪啳绻樻禍鍡曠稻鐞?`index===target` 閹糕槄绱?
   *   aend=<index>/<濞嗏剝鏆?    `onAnimationEnd` 閺堚偓閸氬簼绔村▎锛勬畱鐎圭偛寮稉搴㈩偧閺?
   *   chg=<index>/<濞嗏剝鏆?     `onChange` 閺堚偓閸氬簼绔村▎锛勬畱鐎圭偛寮稉搴㈩偧閺佸府绱檚wiper 閼奉亜绻佺拋銈勮礋閸嬫粌婀崫顏冪妞ょ绱?
   * ```
   */
  private diagAnimStart: string = '-1--1';
  private diagAnimSkip: number = 0;
  private diagAnimEnd: string = '-';
  private diagAnimEndCount: number = 0;
  private diagChg: string = '-';
  private diagChgCount: number = 0;
  /**
   * 閳藉應妲勯埥?2026-10-16閿涙瓪onContentDidScroll` 閻?*鐠嬪啰鏁ょ拋鈩冩殶娑撳孩娓堕崥搴濈濞嗏€崇杽閸?* 閳ユ柡鈧?鏉╂瑦妲搁張顒冪枂閻喐顒滈惃鍕灲閹诡喓鈧?
   *
   * 鐠囩粯纭堕敍鍫濈獦閺?*缁楊剙鍙撶悰?*閻?`scr=`閿涘绱?
   * ```
   *   scr=<濞嗏剝鏆? last=<index>/<position>
   *     scr=0        閳?鏉╂瑤閲滈崶鐐剁殶**娑撯偓濞嗭繝鍏樺▽陇袝閸?*閿涘牓鍋?SDK 娓氀冩皑濞屸剝婀佹潻娑樺濠ф劕褰查悽顭掔礉鐟曚焦宕查弬瑙勵攳閿?
   *     last=0/0.37  閳?濮濓絽婀禒搴＄殱闂堛垽銆夊鎴濇倻濮濆矁鐦濇い纰夌礄`position` 閺勵垳些閸斻劍鐦笟瀣剁礆
   *     last=0/1.000 閳?閳?**閸嬫粌婀宀冪槤妞?*閿涘牊妫ら悾宀€娈戣ぐ鎺嶇閸栨牗濡哥€瑰啫銇欓崚?1閿涘奔绗栧銈呮倵娑撳秴鍟€閺囧瓨鏌婇敍?
   * ```
   * 閺冪姷鏅惃鍕搼娴犻澧跨亸杈ㄦЦ `swiperProgress`閿涙稑鐣犻弰?goal 缁?1 閺夆剝瀵氱€规氨娈?*鏉╂稑瀹冲┃?*閵?
   */
  private diagScrollCount: number = 0;
  private diagScrollLast: string = '-';
  /**
   * 閳藉應妲勯埥?2026-10-16閿涙艾鍞寸€圭懓鐪?`.onAppear()` **鐠ч绨￠崫顏呮蒋閸掑棙鏁?* 閳ユ柡鈧?鐎规矮缍?閸忔娊妫撮崥搴ｇ崐閻掕泛寮甸弨鎯х潔瀵偓"閵?
   *
   * 閸欐牕鈧》绱?
   * ```
   *   '-'        = 鏉╂瑤閲滈崶鐐剁殶鏉╂ɑ鐥呮潻娑滅箖
   *   'morph'    = 鐠ч绨¤ぐ銏犲綁閸掑棙鏁敍鍧rphContainerActive || morphSessionStarted閿涘娓?濮濓絽鐖?
   *   'intro'    = 鐠ч绨￠崗婊冪俺閸掑棙鏁獮鎯版崳娴?playExpandIntro()  閳?閳?閼汇儱鍤悳鏉挎躬閸忔娊妫存潻鍥┾柤娑擃叏绱濈亸杈ㄦЦ閺?bug
   *   'skipClose'= 鐠ч绨￠崗婊冪俺閸掑棙鏁担鍡氼潶"濮濓絽婀崗鎶芥４"闁綁浜鹃梻銊﹀娑?閴佸拑绱欓張顒冪枂閺傛澘顤冮惃鍕，閿?
   * ```
   * 閸掋倛顕伴敍姘彠闂傤厼鎮楅懟銉ф箙閸?`intro` 閳?闂傘劍鐥呴幏锔跨秶閿涘牐顩﹂崘宥嗙叀閸掋倖宓侀敍澶涚幢閻鍩?`skipClose` 閳?闂傘劎鏁撻弫鍫滅啊閵?
   */
  private diagAppearBranch: string = '-';
  /**
   * 閳藉應妲勯埥?2026-10-16閿?*閼冲本娅欑仦鍌濆殰瀹歌京娈戠€圭偞绁撮惌鈺佽埌**閿涘牏鐛ラ崣锝呮綏閺嶅浄绱漹p閿涘鈧柡鈧?鐎规矮缍?閺堝鍎楅弲顖欑稻妤傛ê瀹抽悧閫涚秵"閵?
   *
   * 娑撹桨绮堟稊鍫濆礋閻欘剟鍣虹€瑰喛绱伴懗灞炬珯鐏炲偊绱檂MeshCoverBg` 闁絼閲滅€瑰じ瀵?`Column`閿涘妲?*瑜般垹褰夌€圭懓娅掗惃鍕摍閼哄倻鍋?*閿?
   * 閼板奔绗栭弰?`.height('100%')` + `.position({x:0,y:0})` 閳?鐎瑰啰娈戞妯哄**鐎瑰苯鍙忛悽鍗烆啇閸ｃ劌鍠呯€?*閵?
   * 閻劍鍩涢幎銉ｂ偓灞炬箒閼冲本娅欐担鍡樻Ц**妤傛ê瀹抽悧閫涚秵**閵嗗秵妞傞敍灞肩瑏缁夊秴褰查懗钘夌箑妞よ鍨庢潏顭掔窗
   * ```
   *   閳?鐎圭懓娅掗惃鍕梿閸擃亞鐛ラ崣锝嗘拱閺夈儱姘ㄩ弰顖炲亝娑斿牆鐨敍鍧刢lipH` 鐠囩粯鏆熼敍澶嗗櫩 濮濓絽鐖堕敍灞炬Ц閸斻劎鏁炬稉顓燁唽
   *   閳?閼冲本娅欑仦鍌滄畱閻╂帒鐡欑悮顐㈠竾閹存劒绨￠弸浣哥毈閿涘牊婀扮拠缁樻殶 `bgH`閿? 閳?鐢啫鐪梻顕€顣介敍鍫㈡閸掑棙鐦柧鐐焽娴滃棴绱?
   *   閳?閼冲本娅欑仦鍌滄磪鐎涙劖顒滅敮闀愮稻鐞?*濞ｂ剝甯€**娴滃棴绱檂bg` 娑撳秹鈧繑妲戞惔锔肩礆閳?閺?`backgroundRevealOpacity()` 閻ㄥ嫪绨?
   * ```
   * 閻?`MeshCoverBg` 閹碘偓閸︺劌顔栨稉?`Column` 閻?`.onAreaChange()` 閸愭瑱绱欓崣顏囶嚢閿涘本妫ら崜顖欑稊閻㈩煉绱氶妴?
   * 閳跨媴绗?`onAreaChange` 缂佹瑧娈戦弰?*鐢啫鐪崙鐘辩秿**閿涘牅绗夐崥顐ゎ殯閸?transform閿涘鍣?闁板秴鎮庡鑺ョ垼缁楊兛绔寸悰宀€娈?
   *    `scale` 閹靛秷鍏樻潻妯哄斧"鐏炲繋绗傛径姘剁彯"閿? `bgH 鑴?scale`閿涘鈧?
   */
  @Local private diagBgBox: string = '-';
  /**
   * 娑撳﹣绔村▎?`onContentDidScroll` 閻ㄥ嫭妞傞梻瀛樺煈閿涘潰s閿涘鈧柡鈧?**閻劍娼电拋?閽€钘夌暰"鐠佲晙缍呯紒?闁劕鎶氭潻娑樺"**閵?
   *
   * 閳藉應妲勯埥?2026-10-16閿涘牐绻栭弰顖涙拱鏉烆喖绻€妞よ顦╅悶鍡欐畱娑撯偓婢?*閻喎鐤勯崘鑼崐**閿涘绱?
   * `onContentDidScroll` 闁劕鎶氶崘?`lyricMorphT = p`閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?
   * 閼?`syncLyricMorphToPage()` 閺?閹?`t` 閽€钘夌暰閸掓澘缍嬮崜宥夈€夌€电懓绨查惃鍕伂閻?閿涘牅绔撮幎濠咁啎閸掗缍呴敍澶堚偓?
   * 娑撱倛鈧懓瀚㈤崥灞炬閻㈢喐鏅ョ亸鍙樼窗**濮ｅ繐鎶氭禍鎺旀祲閹躲垹鈧?*閿涘牊绮﹂崚棰佺閸楀﹨顫﹂拃钘夌暰閸?1 閳?閻㈠娼扮捄绛圭礆閵?
   * 閳?閸掋倖宓侀敍?*閺堚偓鏉?120ms 閸愬懏婀佸姘З閸ョ偠鐨?閳?鏉╂瑤绔村▓鐢垫暠"鏉╂稑瀹?瑜版挸顔嶉敍灞肩瑝鐠佹瓕鎯ょ€?*閵?
   *   閿?20ms 閳?7 鐢嶇幢閹靛瀵氶幎顒冩崳閸?swiper 閻ㄥ嫭鍎婚幀褎绮撮崝銊ょ閸嬫粣绱濋拃钘夌暰鐏忚精鍏橀幒銉ь吀閺€璺虹啲閵嗗偊绱?
   *   閳跨媴绗?鏉╂瑤閲滈弮鍫曟？缁?*閸欘亜婀?娑撱倗顫掓す鍗炲З閺傜懓绱￠獮璺虹摠"閺冭埖澧犻張澶嬪壈娑?*閿涘苯鐣犳稉宥嗘Ц閸斻劎鏁鹃弮鍫曟毐閵嗕椒绡冩稉宥嗘Ц閼奉亞绱崣鍌涙殶 閳ユ柡鈧?
   *      鐎瑰啯妲?閸掋倕鐣惧姘З閺勵垰鎯佹禒宥呮躬鏉╂稖顢?閻ㄥ嫰鍣伴弽椋庣崶閿涘牅绗?`PULL_ANCHOR_RETRY_MS = 32` 閸氬奔绔撮幀褑宸濋敍澶堚偓?
   */
  private lastScrollAtMs: number = 0;

  /**
   * 妞ゅ爼鍎撮柇锝呮健"闂呮劕鑸伴悜顓炲隘"閻ㄥ嫮鍋ｉ崙鏄忣吀閺佸府绱?*鏉╃偟鍋?3 濞?*瀵偓閸忓疇鍤滅拠浣哥獦閺嶅洢鈧?
   *
   * 閻?800ms 閻ㄥ嫮鐛ラ崣锝呭灲鐎?鏉╃偟鍋?閿涙盯妫块梾鏃囩Т鏉╁洤姘ㄩ柌宥嗘煀鐠佲剝鏆熼妴?
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
      // 閳?2026-10-17閿涙俺娉曠€圭偘绶ョ拋鏉跨箓閿涘牐顫?`diagBadgeOnStatic` 闁絾顔岄敍澶堚偓?*韫囧懘銆忛幋鎰嚠閸?*閿?
      //   閸欘亣顕版稉宥呭晸 = 瀵偓閸忚櫕妗堟潻婊冩礀閸?false閿涘牓鍋呭锝嗘Ц"閻劍鍩涢惂鍊熺獓娑撯偓鏉?閻ㄥ嫬鑸伴悩璁圭礆閵?
      PlaybackPage.diagBadgeOnStatic = this.diagBadgeOn;
    }
  }

  /**
   * 閹跺﹤缍嬮崜宥夊亝娑撯偓娑撴彃鍨介幑顔藉閹存劒琚辩悰灞界摟缁楋缚瑕嗛敍?*閸欘亜婀鑺ョ垼瀵偓閻偓閺冩儼鐨熼悽?*閿涘鈧?
   *
   * 濮ｅ繋绔存い褰掑厴鐎电懓绨查張顒冪枂閺€纭呯箖閹存牗鈧偓閻ゆ垼绻冮惃鍕娑擃亜鍨介弬顓ㄧ礉閸涜棄鎮曟稉搴濆敩閻礁鐡у▓鍏哥娑撯偓鐎电懓绨查敍?
   * ```
   *   sess   = morphSessionStarted        閿涘煪?3閿涙艾锛撶仦鍌氬嚒鐠ц渹绱扮拠婵撶礆
   *   usable = morphUsable                閿涘牆鍤戞担鏇熸Ц閸氾箓鍣烘鎰剁礆
   *   cont   = morphContainerActive()     閿涘牆顔愰崳銊︽Ц閸氾箑婀ぐ銏犲綁閸╃噦绱?
   *   clip   = morphClipping()            閿涘牐顥嗛崜顏呮Ц閸氾妇鏁撻弫鍫礆
   *   scale  = morphScale                 閿? = 閹帞鐡戦敍?.08 = 瀹告彃甯囬崚鎷屾崳閻愮櫢绱?
   *   p      = morphP                     閿涘牆鑸伴崣妯跨箻鎼达讣绱?
   *   real   = realCoverVisible()         閿涘牊鎸遍弨楣冦€夐惇鐔风殱闂堛垺妲搁崥锔炬暰閿?
   *   clone  = morphOverlayBridging()     閿涘牆锛撶仦鍌滅敾妞嬬偛鐨濋棃銏℃Ц閸氾妇鏁鹃敍?
   *   snap   = snapStartW / miniSize      閿涘牐鎹ｉ悙鐧哥窗缂侇參顥ｇ亸渚€娼扮€硅棄瀹?/ 鏉╄渹缍橀弶鈥崇殱闂堫澁绱?
   *   end    = endCoverSize / endCoverH   閿涘牏绮撻悙鐧哥窗閹绢厽鏂佹い闈涚殱闂堫澁绱?
   *   op     = backgroundRevealOpacity()  閿涘牐鍎楅弲顖欑瑝闁繑妲戞惔锔肩礆
   *   stage / drv = morphStage / morphDrive
   * ```
   * 閳跨媴绗?閸掋倛顕扮憰浣哄仯閿涘牆鍟撻崷銊ㄧ箹闁插矉绱濋悽銊﹀煕韫囧灚鏆熺€涙妞傞幋鎴ｅ殰瀹稿崬顕崣鍑ょ礆閿?
   * 璺?`clone=1` 娑?`real=0` 閳?鐏忎線娼扮拠銉ф暠婢瑰啿鐪板ù顔肩湴閻紮绱遍懟銉ョ潌娑撳﹥鐥呴張?閳?閻?`snap/end` 閺勵垰鎯侀棃鐐烘祩閿?
   * 璺?`clone=0` 娑?`real=1` 閳?鐏忎線娼扮拠銉ф暠閹绢厽鏂佹い鐢垫暰閿涘牓鍋呴弮璺虹暊閸︺劌顔愰崳銊╁櫡閿涘奔绱扮悮顐ょ級閺€鎾呯礆閿?
   * 璺?`clone=0` 娑?`real=0` 閳?**娑撱倛绔熼柈鎴掔瑝閻?*閿涘牆姘ㄩ弰?鐎瑰苯鍙忓▽鈩冩箒鐏忎線娼?閻ㄥ嫰鍋呮稉顏勮埌閻樿绱氶敍?
   * 璺?`op=0.04` 娑?`p閳?` 閳?閼冲本娅欓崚姘虫崳濮濄儻绱盽op=1` 閳?瀹稿弶寮ч妴?
   */
  private refreshDiagText(): void {
    if (!this.diagBadgeOn) {
      return;
    }
    const e = this.expandState;
    // 閳?2026-10-16閿涘牏澧楅張顒佺垼鐠?`b41d7e9` 閳?`c52e0a7` 閳?`d73f1b8`閿涘绱伴柇锝勭鏉烆喖濮為惃鍕Ц
    //   goal 缁?2 閺夛紕娈戦崷鍡氼潡閼奉亣鐦夋担宥忕礄缁楊剙娲撶悰?`rad`/`radVis`/`edge`/`t`閿涘绗?
    //   "閸楁瓕娴囬弨鐐綀閸掋倖宓?閻ㄥ嫬鐣剧粙鍖＄礄`morphSessionOughtToLive`閿涘鈧?
    //   **閻劍鍩涢幎?濞屸€冲З閻?閺冭泛鍘涢惇瀣儑娑撯偓鐞涘瞼娈?`sess` / `geom` 娑撱倓缍?*閿?
    //     `sess=0` 閳?娴兼俺鐦界悮顐ｇ閹哄绨￠敍鍧刟boutToDisappear` 闁絾娼捄顖涚梾鐞氼偅瀚ゆ担蹇ョ礆閿?
    //     `geom=0` 閳?缂佸牏鍋ｉ崙鐘辩秿婵绮撳▽锟犲櫤閸?閳?鐎圭懓娅掗幁鎺旂搼 閳?濮濓絾妲?濞屸剝婀佺亸渚€娼?閼冲本娅欓崝銊ф暰"閵?
    // 閳?2026-10-17閿涘牏澧楅張顒佺垼鐠?閳?**`af66eb1`**閿涘绱伴柇锝勭鏉烆喖濮為惃鍕Ц**缁楊剙宕勭悰灞界啲闁劎娈?`pd=`**
    //   閿涘牐绐￠幍瀣╃瑏娑擃亝瀚嗙紒婵堝仯閻ㄥ嫮鐤拋陇顓搁弫甯礆閵嗗倵鍣?**閻劍鍩涢幎?娑撳秷绐￠幍?閺冭泛鍘涢惇?`pd`**閿?
    //     `pd=0/0/0` 閳?閸掋倖宓侀崗銊р柤閺€鎹愵攽閿涘矂妫舵０妯烘躬娴滃娆?閹靛濞?閻楀牆绱￠敍娑楁崲娑撯偓闂?0 閳?閺勵垰鍨介幑顔藉珕閻ㄥ嫨鈧?
    const line1: string = `V af66eb1 sess=${e.morphSessionStarted ? 1 : 0} ` +
      `usable=${e.morphUsable ? 1 : 0} geom=${e.morphGeomReadyNow() ? 1 : 0} ` +
      `cont=${e.morphContainerActive() ? 1 : 0} ` +
      `clip=${e.morphClipping() ? 1 : 0} scale=${e.morphScale.toFixed(3)} p=${e.morphP.toFixed(3)}`;
    const line2: string = `real=${e.realCoverVisible() ? 1 : 0} ` +
      `clone=${e.morphOverlayBridging() ? 1 : 0} ` +
      `snap=${e.snapStartWVp().toFixed(0)}/${e.miniSize.toFixed(0)} ` +
      `end=${e.endCoverSizeVp().toFixed(0)}/${e.endCoverHVp().toFixed(0)} ` +
      `op=${this.backgroundRevealOpacity().toFixed(3)} stage=${e.morphStage} drv=${e.morphDrive}`;
    // 閳?缁楊兛绗佺悰宀嬬窗閹貉冨煑閸栨椽顣╃粻妤嬬礄**娑撳秶鏁?hdc 娑旂喕鍏橀弽鍛婃￥閻ｅ矂鍋呮總妤佹殶閸?*閿涘鈧柡鈧?
    //   `usableH` 鎼存梹瀵滈弮鐘垫櫕 `winH 閳?padTop 閳?max(avoidBottom, bottomGap)` 缁犳绱?
    //   `padBot` 鐠囪鍩岄惃鍕偓鐓庣安娑?`gap` 閸掓绱橣ULL 65閿涘绔撮懛杈剧礄闂勩倝娼€圭偞绁撮柆鑳唨閸栫儤鐦€瑰啳绻曟径褝绱氶妴?
    const line3: string = `usableH=${e.usableHVp().toFixed(1)} padBot=${e.padBottomVp().toFixed(1)} ` +
      `avoid=${e.navigationBarBottomVp.toFixed(1)} gap=${e.chromeBottomGapVp().toFixed(0)} ` +
      `gapScrub=${e.chromeGapScrubVp().toFixed(0)} tier=${e.chromeTier}`;
    // 閳?缁楊剙娲撶悰宀嬬窗**閺堫剝鐤嗛惃鍕⒈娑擃亜濮╂担婊嗩吀閺?*閿涘牆鍨?娴狅絿鐖滈張澶嬬梾閺堝绐囬崚?濮ｆ柨鍨介崐鍏兼纯闂堢姴澧犻敍宀冾潌鐎涙顔屽▔銊╁櫞閿涘鈧?
    //   閳藉應妲勯埥?2026-10-16閿涘潛oal 缁?2 閺壜扳偓宀勩€夐棃銏犳妇鐟欐帒鍟€閺嶉晲绔撮柆宥冣偓宥囨畱**閼奉亣鐦夋担?* 閳ユ柡鈧?**瀹歌尪顓瑰锝堢箖娑撯偓濞?*閿?
    //
    //   閳跨媴绗?閹存垹顑囨稉鈧悧鍫熷Ω `rad`/`radVis` 闁插繑鍨氭禍?`morphRadius` 閳ユ柡鈧?**闁絾妲?鐎圭懓娅掗懛顏勭箒"閻ㄥ嫬娓剧憴?*閿?
    //      娑撳秵妲哥亸渚€娼伴惃鍕妇鐟欐帪绱濇稉銈堚偓鍛Ц**娑撱倖娼悪顒傜彌閻ㄥ嫰鎽?*閿涘牆鍩嗗ǎ鍑ょ礆閿?
    //   ```
    //     鐎圭懓娅掗崷鍡氼潡 morphRadius = initRadiusVisual 鑴?(1 閳?t) / scale
    //        璺?鐠ч鍋?= 鏉╄渹缍橀弶陇鍏岄崶濠傛妇鐟欐帞娈戞稉鈧崡濠忕礉缂佸牏鍋?= **0**閿涘牓鎽靛鈥崇潌 閳?鐎圭懓娅掓稉宥堫嚉閺堝娓剧憴鎺炵礆
    //        璺?閺冪姷鏅崥灞绢儥閿涙瓫pplyPullProgress 閻?radius 閸掑棙鏁敍?1054-51086閿?
    //        閳?閹碘偓娴?t=0 閺冭泛鐣犻幐澶庮啎鐠佲€虫皑閺?0 閳ユ柡鈧?閹存垹顑囨稉鈧悧鍫熷瑏鐎瑰啫缍?鐏忎線娼伴崷鍡氼潡"閿涘矁顕伴弫鎷屽殰閻掕泛鍙忛弰?0閵?
    //
    //     鐏忎線娼伴崷鍡氼潡 coverLocalRect().radius = lyricMorph(t).radius
    //        璺?閺冪姷鏅?`radiusAt(t) = visualRadiusAt(t) / scaleAt(t)`
    //          閸忔湹鑵?`visualRadiusAt(t) = lerp(radiusPlayer, radiusLyricVisual, t)`
    //          `radiusPlayer = 8`閿涘澋ujie.pa:85761 ldai 0x8閿?
    //          `radiusLyricVisual = 12`閿涘牆鎮撻弮蹇撶埗闁插骏绱?
    //        璺?閺堫兛绮?`lyricMorph()` 闁插苯姘ㄩ弰?`lerp(COVER_RADIUS_PLAYER_VP(8), COVER_RADIUS_LYRIC_VISUAL_VP(12), p)`
    //        閳?娑撱倗顏?*闁劕鐡ф稉鈧懛?*閿涙=0 閳?8閿涙硟=1 閳?12
    //   ```
    //   閳?鏉╂瑤绔寸悰宀€骞囬崷銊╁櫤閻ㄥ嫭妲?*鐏忎線娼伴柇锝嗘蒋闁?*閿涘潉cRad` / `cRadV`閿涘畱 = cover閿涘绱?
    //     楠炴湹绻氶悾娆忣啇閸ｃ劑鍋呴弶鈽呯礄`rad`/`radVis`閿涘浜掓笟鍨嚠閻?閳ユ柡鈧?娑撱倖娼柈鑺ュⅵ閸戠儤娼甸敍灞肩閻壈鍏橀崚鍡氶哺閵?
    //   閸掋倛顕伴敍姝歵=0` 閳?**cRad = cRadV = 8.00**閿涙矖t=1` 閳?**12.00**閿?
    //         瑜般垹褰夋稉?`cRadV = cRad 鑴?morphScale` 鎼存柨顫愮紒鍫濇躬 **8~12 娑斿妫?*閿涘牅绗夐梾?scale 閹舵牕濮╅敍澶堚偓?
    //   婢跺秵鐗抽崗銉ュ經閿涙俺绻涢悙瑙勬尡閺€楣冦€夊锔跨瑐鐟?3 濞喡扳偓?
    const coverRect: LyricMorphRect = this.coverLocalRect();
    const line4: string = `remeasure=${this.diagRemeasureTries} overlayKick=${this.diagOverlayKicks} ` +
      `seek=${e.chromeSeekSize().toFixed(0)} edge=${coverRect.size.toFixed(0)} t=${this.lyricMorphT.toFixed(2)} ` +
      `cRad=${coverRect.radius.toFixed(2)} cRadV=${(coverRect.radius * e.morphScale).toFixed(2)} ` +
      `rad=${e.morphRadius.toFixed(2)} radVis=${(e.morphRadius * e.morphScale).toFixed(2)}`;
    // 閳藉應妲勯埥?2026-10-17閿?*goal 缁?1 閺壜扳偓灞藉帗娣団剝浼呯悰灞烩偓宥囨畱閻滄澘婧€閼奉亣鐦?閳ユ柡鈧?缁楊兛绗侀悧鍫礉閸掋倛顕板鎻掔暰缁?*閿?
    //   `metaTop` = 閺堫剝顢?*閻喎鐤勫〒鍙夌厠閸?* = `metaTopGeomY(t, rowH)`閿涘牆姘ㄩ弰顖欑瑐闂堛垽鍋呴弶?`.position().y`閿?
    //               **閸氬奔绔存稉顏勫毐閺佽埇鈧焦鐥呴張澶岊儑娴滃奔鍞ょ悰銊ㄦ彧瀵?*閿涘绱?
    //   `metaOld` = **娑撳﹣绔撮悧鍫ュ亝閺壜ゅ殰鐎规艾绱＄€?*閻ㄥ嫬鈧》绱檂lyricMetaMorphY(t) + t鑴?size閳姰owH)/2`閿?
    //               鐟?`metaTopInUseYAt()`閿涘瞼骞囬崷銊ュ涧閻劋绨€电澶勯敍?*娑撳秴鍟€閸欏倷绗屽〒鍙夌厠**閿涘绱?
    //   `metaD`   = `metaOld 閳?metaTop`閵?
    //   ## 閸掋倛顕伴敍鍫滆⒈缁旑垶鍏橀弰?*瀹歌尙鐓＄敮鍛婃殶**閿涘本澧嶆禒銉ㄧ箹娑撯偓鐞涘瞼骞囬崷銊ュ讲鐠囦椒鍚夐敍?
    // ```
    //   t = 0閿涘牆鐨濋棃銏ゃ€夐敍澶涚窗metaD 閳?**閳?0**
    //       閳ユ柡鈧?閺冄冪础鐎涙劗娈?from 閻?`LYRIC_META_GAP_VP(10)`閿涘牊婀版禒鎾插強鐎规艾鈧》绱氶敍?
    //          閺傛澘绱＄€涙劗鏁?`COVER_FIT_META_GAP_VP(50)`閿涘牊妫ら悾?`fitPlayerOverlay` 閻ㄥ嫮鈥栫紓鏍垳 a8閿?
    //          閳?閺冄冪础鐎涙劖鐦弬鏉跨础鐎涙劙鐝?40vp 閳?metaOld 閳?metaTop = 閳?0
    //   t = 1閿涘牊鐡曠拠宥夈€夐敍澶涚窗metaD 閳?**閳?.64**
    //       閳ユ柡鈧?閺冄冪础鐎涙劕鍩?鐏忓繐鐨濋棃銏ゃ€婃潏?+ (size閳姰owH)/2"閿涘本鏌婂蹇撶摍閸?鐏忓繐鐨濋棃銏ゃ€婃潏?+ 28 閳?rowH/2"閿?
    //          娑撱倛鈧懎妯?= 28 閳?size/2 = 28 閳?48.72/2 = 3.64 閳?閺冄冪础鐎涙劙鐝?3.64vp
    //   閳?娑擃厽顔岄弰顖濈箹娑撱倗顏惃鍕殠閹勫絻閸婄鈧?
    //   閳跨媴绗?閼?t=0 婢?metaD 娑撳秵妲?閳牃鍨?0閿涘牅绶ユ俊?閳?閿涘鍣?鐠囧瓨妲?`bigEndpointRect()` 娑撳酣鍋呴弶鈩冩＋瀵繐鐡?
    //      閻劎娈戦惌鈺佽埌閺夈儲绨稉宥呮倱閿涘牊妫蹇撶摍鐠?`lyricMetaFromYOf()`閿涘奔琚遍懓鍛村厴閸╄桨绨?`bigEndpointRect`閿?
    //      閻炲棜顔戞稉濠傛倱濠ф劧绱氶垾鏂衡偓?闁絾妞傞幍宥夋付鐟曚焦鐓￠妴?
    // ```
    const metaTop: number = e.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const metaOld: number = e.metaTopInUseYAt(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const line6: string = `metaTop=${metaTop.toFixed(1)} metaOld=${metaOld.toFixed(1)} ` +
      `metaD=${(metaOld - metaTop).toFixed(1)} (t=0 閺堢喐婀?閳?0 / t=1 閺堢喐婀?閳?.6) ` +
      // 閳?2026-10-17閿?*鏉╂瑤绔撮弶鈥冲嚒缂佸繋绮?瀵板懓顕伴惃鍕灲閹?闂勫秶楠囨稉?缂佹挻鐎稉宥呭綁闁插繐鎽犻崗?**閿涘绱?
      //   `lBox` = 濮濆矁鐦濇い闈涘敶鐎瑰湱娲呴惃?*缁愭褰涙い鎯扮珶**閿涘潉reportLyricBoxTop` 閸犲偊绱氶妴?
      //   缂佹挻鐎稉濠冧航娑?**0**閿?閻?鐏忚鲸妲?Swiper 閻ㄥ嫮娲呴敍宀冣偓?Swiper 閹碘偓閸︺劎娈?`Column` 娑?
      //   `LyricFloatLayer()` 閺勵垰鎮撴稉鈧稉顏冪瑝鐢?padding 閻?`Stack` 閻ㄥ嫬顒㈢€涙劧绱濇稉鏃囶嚉 `Stack`
      //   閻ㄥ嫬鍞寸€瑰湱娲呭锔跨瑐鐟?= 缁愭褰涢崢鐔哄仯 閳ユ柡鈧?鐎瑰本鏆ｇ拠浣瑰祦闁炬崘顫?`PlayerExpandState.lyricBoxTopVp` 閻?JSDoc閿?
      //   閳?`lyricPadTop()` 闁絾娼?缁愭褰涢崸鎰垼 + 23"閻ㄥ嫬绱＄€?*瀹歌尙绮?*缁涘鐜禍搴㈡￥閻ｅ瞼娈戦惄鎺戝敶瀵繐鐡?閴?
      //     **娑撳秹娓剁憰浣瑰床缁犳绱濇稊鐔剁瑝韫囧懎鍟€鐠囨槒绻栨稉顏呮殶娴滃棎鈧?*
      //   閳跨媴绗?鐎瑰啰骞囬崷銊ュ涧閺堝绔存稉顏嗘暏闁棑绱?*閼汇儱鐨㈤弶銉︽箒娴滆櫣绮伴柇锝勮⒈鐏炲倸濮炴禍?padding閿涘矁绻栭柌灞肩窗鐠囪鍩岄弰搴㈡▔闂?0** 閳ユ柡鈧?
      //     闁絾妞傞幍宥夋付鐟曚焦濡?`lyricPadTop` 閹广垺鍨?`(濞搭喖鐪版惔鏇＄珶 閳?lBox) + 23`閿涘牅绔寸悰宀嬬礆閵?
      //   閳跨媴绗?閸斻劎鏁炬稉顓炵暊閸欘垵鍏橀惉顒佹闂?0閿涘牓鍋呴弰顖氼啇閸ｃ劌褰夐幑銏ｇ箖閻?`globalPosition.y`閿涘本顒滅敮闈╃礆閳?閻?*闂堟瑦顒涢幀?*閻ㄥ嫯顕伴弫鑸偓?
      `lBox=${e.lyricBoxTopVp.toFixed(1)}`;
    // 閳藉應妲勯埥?2026-10-16閿?*"濮濆矁鐦濇い闈涚殱闂堛垺鐥呴崣妯虹毈"閻ㄥ嫮娲块幒銉ュ灲閹?*閿涘瞼鏁ら幋椋庢埂閺堢儤鍩呴崶鎯ф倵閸旂媴绱氶敍?
    //   閻劍鍩涚€圭偞绁撮妴宀冪箹閺勵垱鐡曠拠宥夈€夐敍宀勫亝娑擃亜鐨濋棃銏＄梾閸欐ê鐨妴宥佸櫩 鐠囩粯鏆?`t=0.00 edge=331`閵?
    //   鐏忎線娼扮亸鍝勵嚟 = `lyricMorph(lyricMorphT).size`閿涘矁鈧?`lyricMorphT` 閸欘亝婀?0/1 娑撱倓閲滅粙鍐茬暰閸婄》绱?
    //     璺?`t=0` 閳?鐏忎線娼?= `endCoverSize`閿涘牊鏆ｇ粣妤呭亝娑撯偓娴?閳?331閿涘鈧柡鈧?鐏忚鲸妲搁悽銊﹀煕閻鍩岄惃鍕亣鐏忎線娼伴敍?
    //     璺?`t=1` 閳?鐏忎線娼?= `lyricCoverSizeOf()`閿涘牆鐨亸渚€娼?閳?48.72閿涘鈧柡鈧?鎼存梹婀侀惃鍕壉鐎涙劑鈧?
    //   閳?閹碘偓娴?濞屸€冲綁鐏? 閳?**`lyricMorphT` 濞屸€冲煂 1**閵嗗倽绻栨稉鈧悰宀€娲块幒銉х舶閸戝搫鐣犳稉杞扮矆娑斿牊鐥呴崚甯窗
    //     璺?`sw`  = `playbackSwiperIndex` 閳ユ柡鈧?**娑撳秵妲?1** 閳?閺嶈婀板▽鈥冲瀼閸掔増鐡曠拠宥夈€夐敍鍫熷灗缁便垹绱╃悮顐㈩槻娴ｅ稄绱?
    //     璺?`tgt` = `lyricMorphTarget`   閳ユ柡鈧?娑?`sw` 娑撳秳绔撮懛?閳?鐞涖儵妫块弬鐟版倻閸欏秳绨?/ 濞屸剝鏁圭亸?
    //     璺?`vis` = `lyricMorphVisible`  閳ユ柡鈧?`0` 閳?`lyricFloat()` 閸掋倓璐熸稉宥呭讲閻㈩煉绱濋弫鏉戭殰妞嬬偠顢戝▽陇鎹?
    //     璺?`sg` / `fs` = `lyricSwiperSettled` / `lyricFlightSettled` 閳ユ柡鈧?娑撱倝妫堕幓鈩冨濞岋繝缍?
    const line7: string = `sw=${this.playbackSwiperIndex} tgt=${this.lyricMorphTarget ? 1 : 0} ` +
      `vis=${this.lyricMorphVisible ? 1 : 0} op=${this.lyricMorphOpacity.toFixed(2)} ` +
      `sg=${this.lyricSwiperSettled ? 1 : 0} fs=${this.lyricFlightSettled ? 1 : 0} ` +
      `lcEdge=${e.lyricCoverSizeOf().toFixed(1)} lcY=${e.lyricCoverYOf().toFixed(1)} ` +
      `float=${e.lyricFloat() ? 1 : 0}`;
    // 閳藉應妲勯埥?2026-10-16閿?*Swiper 閸ョ偠鐨熺€圭偛寮?* 閳ユ柡鈧?鐟欎礁鐡у▓?`diagAnimStart` 閻ㄥ嫭鏁為柌濠忕礆閿?
    //   `ast=-1--1` = `onAnimationStart` **娑撯偓濞嗭繝鍏樺▽陇绻橀弶銉ㄧ箖**閿涘牃鍣?閸掑洭銆夊▽陇铔嬪鎴濆З閸ョ偠鐨熼敍澶涚幢
    //   `ast=0-1` + `skp>0` = 鏉╂稒娼垫禍鍡曠稻鐞氼偄鐣ч崡顐ｅ皡閹哄绱欓埇?鐟曚焦鏁肩€瑰牆宕奸崚銈嗗祦閿涘绱?
    //   `chg=1/閳ヮ泦 閼?`sw=0` = swiper 鐠併倓璐熼崷銊︾摃鐠囧秹銆夐妴浣哄Ц閹礁宓堢拋鎵絻 0閿涘牃鍣?閻樿埖鈧焦鐥呴崥灞绢劄閿涘鈧?
    const line8: string = `ast=${this.diagAnimStart} skp=${this.diagAnimSkip} ` +
      `aend=${this.diagAnimEnd}/${this.diagAnimEndCount} ` +
      `chg=${this.diagChg}/${this.diagChgCount}`;
    // 閳藉應妲勯埥?2026-10-16閿?*鏉╂稑瀹冲┃鎰殰鐠?* 閳ユ柡鈧?goal 缁?1 閺夆剝瀵氱€规氨娈?`swiperProgress` 缁涘鐜悧鈺嬬礆閿?
    //   `scr` = `onContentDidScroll` 閻ㄥ嫯鐨熼悽銊︻偧閺佸府绱?*闁劕鎶?*鐟欙箑褰傞敍宀冾潌鐎规ɑ鏌?SDK 閸樼喐鏋冮敍澶涚幢
    //   `last` = 閺堚偓閸氬簼绔村▎鈥崇杽閸?`index/position`閵?
    //   閸掋倖宓侀敍姘粻閸︺劍鐡曠拠宥夈€夐弮璺虹安瑜版挾婀呴崚?**`last=0/1.000`**閿涘牊妫ら悾灞惧Ω `position` 婢剁懓鍩?1閿?
    //   娑斿鎮?`index === 0` 閹靛秵娲块弬鑸偓浣瑰娴犮儱鐣犵粙鍐茬暰閸嬫粌婀?1閿涘鈧柡鈧?闁絾妞?`lyricMorphT` 娑旂喎绨叉稉?1閵?
    //   鐏忎線娼?`edge` 鎼存柨褰夐幋鎰毈鐏忎線娼伴敍鍫氬48.7閿涘鈧?
    //   `scr=0` 閳?鏉╂瑤閲滈崶鐐剁殶娑撯偓濞嗭繝鍏樺▽陇袝閸欐埊绱欑憰浣瑰床鏉╂稑瀹冲┃鎰剁礆閵?
    const line9: string = `scr=${this.diagScrollCount} last=${this.diagScrollLast}`;
    // 閳藉應妲勯埥?2026-10-16閿?*閸忔娊妫寸捄顖氱窞閻ㄥ嫮骞囬崷楦款嚢閺?* 閳ユ柡鈧?閻劍鍩?23:19/23:20 娑撳娼崣宥夘洯閻ㄥ嫬鐣炬担宥囨暏閿?
    //
    // 閻劍鍩涢崣宥夘洯閿涘牆甯拠婵囶洤閹奉剨绱氶敍?
    // ```
    //   閳?閺堝妞?閹绢厽鏂佹い鐢割浕妞ゅ吀绗呴弬鐟板殤娑擃亝瀵滈柦顔荤瘍娴兼岸娈ｉ挊?
    //   閳?"鏉╂柨娲栭崗鎶芥４閹绢厽鏂侀崳銊﹀灉閸欐垹骞囨稉宥嗘Ц濞屄ゅ剹閺咁垽绱濇担鐘垫箙闁絼绔撮弶鈽呯礉閺?*閺堝鍎楅弲顖欑稻閺勵垶鐝惔锔惧娴?*"
    //   閳?"娑撳濯洪崗鎶芥４閹绢厽鏂侀崳銊ョ殱闂堛垺妲告潻娆庨嚋鐏忓繐娓捐ぐ顫礉閻掕泛鎮楅崝銊ф暰缂佹挻娼禍?*缁愪胶鍔ч弶銉ら嚋鐏炴洖绱戦幘顓熸杹閸ｃ劎娈戦崝銊ф暰**"
    // ```
    // 鏉╂瑤绗侀弶锟犲厴閸欐垹鏁撻崷?*閸忔娊妫存潻鍥┾柤娑?*閿涘矁鈧奔绗傞棃?1~9 鐞涘苯銇囨径姘Ц"闂堟瑦顒涢幀浣筋嚢閺? 閳?韫囧懘銆忕悰銉ㄧ箹娑撯偓鐞涘被鈧?
    //
    // 閸氬嫰鍣洪惃鍕灲鐠囦紮绱?
    // ```
    //   show  = 婢瑰啿鐪?isShowPlay閵嗗倵鎲?閻ㄥ嫬銇旈崣宄扮彍閻ゆ埊绱伴懟銉ョ暊閸︺劌鍙ч梻顓⑩偓鏂捐厬閸欐ê娲?true閿?
    //           婢瑰啿鐪?`@Monitor('appState.isShowPlay')` 娴?`pushPlayerRoute()`
    //           閳?**闁插秵鏌婇幒銊ュ弳娑撯偓娑擃亝鏌婇惃鍕尡閺€楣冦€夌€圭偘绶?* 閳?鐏忚鲸妲?閸欏牊鏂佹稉鈧柆宥呯潔瀵偓"
    //   clos  = isClosing閿涘牆鍙ч梻顓㈡懠鐠侯垰鍑＄挧鍑ょ礆
    //   coll  = 閹貉冨煑閸栧搫鍑￠弨鎯版崳閿涘牃鎲?閻ㄥ嫮娲块幒銉嚢閺佸府绱? = 闁絽鍤戞稉顏呭瘻闁筋喗妲搁挊蹇曟絻閻ㄥ嫸绱?
    //   p     = morphP閿涘牆鍙ч梻顓熸閸?0 鐠у府绱?
    //   clipH = **閸愭瑨绻樼€圭懓娅?`.height()` 閻ㄥ嫯顥嗛崜顏嗙崶閸欙綁鐝?*閿涘牃鎲?閻ㄥ嫮娲块幒銉嚢閺佸府绱?
    //           閼冲本娅欓弰顖氼啇閸ｃ劎娈戠€涙劘濡悙?閳?鐎圭懓娅掔悮顐ヮ梿閹存劕顦挎姗堢礉閼冲本娅欑亸鍗炲涧閻㈣顦挎姗堢礆
    //           闂堟瑦顒涢幀浣哥安 = 0閿涘牊顒濋弮?`.height()` 閸愬懘鍎寸挧?'100%'閿涘绱遍崗鎶芥４娑擃厺绱版潻鐐电敾閸欐ê鍩?閳?鏉╄渹缍橀弶锟犵彯
    //   bg    = 閼冲本娅欑仦鍌欑瑝闁繑妲戞惔锔肩礄閳?閻鐣犻張澶嬬梾閺堝顫﹀ǎ鈩冨竴閿?
    //   drv   = morphDrive閿涘湗INGER/ANIM/NONE閿?
    //   sq    = morphSquashY閿涘牐鎯ゆ担宥嗗皨閸樺绱濋埉? 閺冭泛婀鐧哥礆
    //   pd    = **鐠虹喐澧?鐞氼偅瀚?鐠佲剝鏆?*閿涘牃妲?2026-10-17 閺傛澘顤冮敍宀€娲块幒銉よ礋閻劍鍩涢惃鍕┾偓灞肩瑐濠婃垳绗夐懗鍊熷殰閻究鈧稄绱?
    //           `<鐠ч攱澧滈幏?/<閺囧瓨鏌婇幏?/<閺夌偓澧滈幏?`閿?*缁鳖垵顓搁崐绗衡偓浣风瑝濞撳懘娴?*閿涘牓鍣搁崥?App 閹靛秴缍婇梿璁圭礆閵?
    //           閻劍纭堕敍姘愁唨瀵拌姤鐖ｅ鈧惈鈧?閳?閸嬫矮绔村▎鈥茬瑐閹?閳?閻绻栨稉澶夐嚋閺?*閺堝鐥呴張澶婂綁**閵?
    //           璺?閸欐ü绨?閳?閵嗗奔绗夌捄鐔稿閵嗗秵妲?*閸掋倖宓?*閹锋帞娈戦敍灞肩瑬娑撯偓閻偐婀呴崙鐑樻Ц閸濐亙绔存稉顏庣窗
    //              缁?1 娑擃亝瀹?= 鐠ч攱澧滈柇锝勭閸掕鍤戞担鏇熺梾闁插繘缍堥敍鍫㈡纯閹恒儵鎽靛掳鈧焦妫ょ捄鐔稿閸斻劎鏁鹃敍?
    //                          閳?閺?`measureMiniDuringPull` / 鏉╄渹缍橀弶鈩冩Ц閸氾箑鍑￠幐鍌濇祰閿?
    //              缁?2 娑擃亝瀹?= 閹靛瀵氶崷銊ュЗ娴?`pullDragging` 閺勵垰浜ｉ敍鍫熸拱缁粯娓堕崣顖滄瀿閻ㄥ嫪绔撮弶鈽呯礉
    //                          閸樺棗褰舵稉濠呯箹娑撯偓缁鍑＄紒蹇撳毉鏉╁洣琚卞▎鈥虫礀瑜版帪绱版悅round-36 閻?`staleClr`閿?
    //                          閳?閺?鐠嬩焦濡?`pullDragging` 濞撳懏鍨氭禍鍡椾海"閿?
    //              缁?3 娑擃亝瀹?= 閺夌偓澧?閸欐牗绉风悮顐㈠灲閹诡喗瀚嗛敍鍫熸暪鐏忕偓鐥呯挧?閳?妞ょ敻娼伴崡鈥虫躬閸楀﹨鐭鹃敍澶堚偓?
    //           璺?娑撯偓娑擃亪鍏樺▽鈥冲綁 閳?閸掋倖宓侀崗銊р柤閺€鎹愵攽 閳?闂傤噣顣介崷?*(b)娴滃娆?閹靛濞嶇拠鍡楀焼/閻楀牆绱?*閿?
    //             **娑撳秷顩﹂崘宥呭箵閸斻劎濮搁幀浣规簚**閿涘牅鎱ㄥ▔鏇炵暚閸忋劋绗夐崥宀嬬礆閵?
    //           閳跨媴绗?缁?2 娑擃亝妲?*閹稿澧滈崝鑳吀濞?*閻ㄥ嫸绱欐稉鈧▎鈩冨閸旀寧娓舵径?+1閿涘绱濈憴?
    //              `Index.pullDropCountedThisGesture` 閻ㄥ嫯顕╅弰搴涒偓?
    // ```
    const line10: string = `show=${this.state.isShowPlay ? 1 : 0} clos=${this.isClosing ? 1 : 0} ` +
      `coll=${this.chromeCollapsed ? 1 : 0} p=${e.morphP.toFixed(2)} ` +
      `clipH=${e.morphClipHeight.toFixed(0)} bg=${this.backgroundRevealOpacity().toFixed(2)} ` +
      `drv=${e.morphDrive} sq=${e.morphSquashY.toFixed(3)} ` +
      `pd=${e.pullDropBegin}/${e.pullDropUpdate}/${e.pullDropEnd}`;
    // 閳藉應妲勯埥?2026-10-16閿?*閸愬懎顔愮仦?onAppear 鐠ч绨￠崫顏呮蒋閸掑棙鏁?* 閳ユ柡鈧?鐎规矮缍?閸忔娊妫撮崥搴″嫉閺€鍙ョ闁秴鐫嶅鈧?閿涘绱?
    //   `ab` = morph閿涘牆鑸伴崣妯哄瀻閺€顖ょ礉濮濓絽鐖堕敍? intro閿涘牐鎹ｆ禍?playExpandIntro 閳?閸忔娊妫撮弮璺哄毉閻滄澘宓?bug閿?
    //        / skipClose閿涘牆鍘规惔鏇炲瀻閺€顖欑稻鐞?濮濓絽婀崗鎶芥４"閻ㄥ嫰妫幏锔跨瑓閿涘本婀版潪顔芥煀婢х儑绱?
    //   `ap` = introPaintReady閿涘牊鏆ｆい鐢电帛閸掑爼妫敍?
    const line11: string = `ab=${this.diagAppearBranch} ap=${this.introPaintReady ? 1 : 0} ` +
      `stage=${e.morphStage} exit=${this.expandIntroRunning ? 1 : 0} bgBox=${this.diagBgBox} ` +
      // 閳?2026-10-17閿涙瓪mesh` = 缂冩垶鐗稿┃鎰躬娑撳秴婀敍? = 鐠ф澘鍘规惔鏇炲絿閺嶇柉澹婄仦鍌︾礉闁絽鐪?*鐢?alpha**閿涘鈧?
      //   閸掋們鈧瞼鍋ｉ崙缁樻尡閺€鐐蒋閹垫挸绱戝▽鈩冩箒閼冲本娅欓妴宥忕窗`mesh=0` 閳?閺勵垰褰囬崶楣冩懠濞屸€茬瑐閺夈儻绱欓惇?`RzdBgRetry`閿涘绱?
      //   `mesh=1` 閼板苯鐫嗘稉濠佺矝濞屸剝婀?閳?閺勵垳绮崚?鐟佷礁澹€閻ㄥ嫪绨ㄩ敍鍫㈡箙 `bgBox` 娑?`clipH`閿涘鈧?
      `mesh=${this.meshSrc !== undefined ? 1 : 0} ` +
      `lcl=${PlaybackPage.lastCloseAtMs > 0 ? (Date.now() - PlaybackPage.lastCloseAtMs).toFixed(0) : 'never'}`;
    // 閳藉應妲勯埥?2026-10-16閿?*閹貉冨煑閸栭缚鍤滅拠?* 閳ユ柡鈧?鐎规矮缍呴悽銊﹀煕缁?1 閺壜扳偓灞炬箒閺冩湹绗呴弬鐟板殤娑擃亝瀵滈柦顔荤瘍娴兼岸娈ｉ挊蹇嬧偓宥忕礆
    //   韫囧懘銆忛懗钘夊瀻鏉堛劏绻栨稉澶岊潚瑜般垻濮搁敍鍫滄叏濞夋洖鐣崗銊ょ瑝閸氬矉绱氶敍?
    //     閳?閼奉亜濮╅弨鎯版崳閿涘牐顔曠拋陇顢戞稉鐚寸窗閺冪姷鏅?`IDLE_MS = 5000`閿涘苯褰ч崷?`isPlay` 閺冨墎鏁撻弫鍫礆
    //        閳?`cc=1` + `cpr=0` + `chH` 濮濓絽鐖?閳?**娑撳秵妲?bug**
    //     閳?鐞氼偉顥嗛幒澶涚礄鐎圭懓娅掔憗浣稿缁愭褰涢幎濠冨付閸掕泛灏崚鍥ㄥ竴閿涘鍣?`clipH` 瀵板牆鐨懓?`chH` 濮濓絽鐖?閳?閺勵垰顔愰崳銊ュ殤娴ｆ洜娈戞禍?
    //     閳?妤傛ê瀹虫繅宀勬閿涘潉lyricChromeHeight` 闁插繑鍨?0 閳?`.height(0 * progress)` = 0閿?
    //        閳?`chH=0` 閳?閺?*闁插繑绁?*閻ㄥ嫪绨ㄩ敍鍧刲yricChromeMeasurePending` / `wasConstrained` 闁絾娼柧鎾呯礆
    //   `cpr` = lyricChromeProgress閿? = 閸忋劌鍤妴? = 閸忋劍鏁归敍澶涚幢`chH` = lyricChromeHeight閿?
    //   `ofs` = chromeOffsetY閿涘牊鏁圭挧閿嬫娑撳些 46vp閿?
    const line12: string = `cc=${this.chromeCollapsed ? 1 : 0} cpr=${this.lyricChromeProgress.toFixed(2)} ` +
      `chH=${this.lyricChromeHeight.toFixed(0)} ofs=${e.chromeOffsetY().toFixed(0)} ` +
      `pend=${this.lyricChromeMeasurePending ? 1 : 0} play=${this.state.isPlay ? 1 : 0}`;
    // 閳藉應妲勯埥?缁楊兛绨茬悰宀嬬窗**閸斻劋缍旀潪銊ㄦ姉**閿涘牊娓舵潻?6 娑擃亜濮╂担婊愮礉閹稿褰傞悽鐔笺€庢惔?`>` 鏉╃偞甯撮敍澶堚偓?
    //   娑撹桨绮堟稊鍫熸付閺堝鏁ら敍姘崇箹閺夛繝鎽兼稉?妞ゅ搫绨?閺堫剝闊╃亸杈ㄦЦ閼奉亜褰夐柌蹇曟畱閺堚偓婢堆冣偓?閳ユ柡鈧?
    //   閸氬奔绔存稉顏勫毐閺佹澘鍘涚拫鍐箷閺勵垰鎮楃拫鍐跨礉缂佹挻鐏夌€瑰苯鍙忔稉宥呮倱閿涘煪?3 閻?`onAppear` 鐠囶垰鍨介妴浼?03 閻?
    //   `onDisappear` 鐠囶垱娼冮柈鑺ユЦ妞ゅ搫绨梻顕€顣介敍澶涚礉閼板苯澧犻崶娑滎攽閸欘亞婀呭妤€鍤?瑜版挸澧犻崐?閵?
    //   閸掋倛顕扮粈杞扮伐閿涘牏鍋ｉ崙缁樺ⅵ瀵偓鎼存柨缍嬮惇瀣煂閻ㄥ嫬鑸伴悩璁圭礆閿?
    //     `clickOpen>beginOk>settle0C>settle1C>measOk>tween`  閳?娑撯偓鐠侯垵铔嬮柅?
    //     `clickOpen>beginOk>settle0C>settle1C>閳ヮ泦閿涘牊妫?measOk閿涘鍣?鐞涖儵鍣烘稉鈧惄瀛樼梾閹存劕濮?
    //     `clickOpen>skip`                                     閳?鐞?`pullDragging`/閻╅晲缍呴幐鈥茬啊
    //     `閳?tween>settleSkip`                                 閳?鐞涖儵妫跨挧铚傜啊娴ｅ棜鎯ゆ担宥堫潶鐠哄疇绻冮敍鍩?04 闁絿琚敍?
    const line5: string = `trace=${e.morphTrace.length > 0 ? e.morphTrace : '(empty)'}`;
    // 閳藉應妲勯埥?2026-10-16閿?*缁楊剙宕勬稉澶庮攽閿涙艾鍙ч梻顓＄箖缁?姒涙垵灏堢€?** 閳ユ柡鈧?鐠囩粯纭剁憴?{@link PlaybackPage.evLog}閿?
    //   娑撹桨绮堟稊鍫ユ付鐟曚礁鐣犻敍姘辨暏閹撮攱濮ら惃鍕⒈閺夆槄绱欓妴灞藉彠闂傤厽妞傞懗灞炬珯閸欘亜澧挎稉鈧弶掳鈧秲鈧苯鍙ч梻顓炴倵閸欏牊鏂佹稉鈧柆宥呯潔瀵偓閵嗗稄绱?
    //   **闁棄褰傞悽鐔锋躬閸忔娊妫存潻鍥┾柤娑擃叏绱濋懓宀勫亝娑撯偓閸掕绐橀弽鍥у嚒闂呭繑鎸遍弨楣冦€夋稉鈧挧閿嬬Х婢?* 閳?娴滃鎮楃拠璁崇瑝閸掗鎹㈡担鏇氱鐟楄￥鈧?
    //   閳?娴滃娆㈢拋鏉挎躬**濡€虫健缁狙囨饯閹胶骞嗚ぐ銏㈢处閸?*闁插矉绱濈粵澶夌瑓娑撯偓濞嗏剝澧﹀鈧幘顓熸杹妞ら潧鍟€閺勫墽銇?閳?鐏忚鲸婀佹禍鍡曠瑐娑撯偓濞嗏€冲彠闂傤厾娈戠€瑰本鏆ｉ弮璺虹碍閵?
    //
    //   閳跨媴绗?閺勫墽銇氶弮鑸靛Ω `|` 閹广垺鍨氶幑銏ｎ攽閿涙矮绔寸悰灞肩娑擃亙绨ㄦ禒璁圭礉娑撯偓瀵姵鍩呴崶鎯ф皑閼冲€燁嚢鐎?
    //     閿涘牅绗夐幑銏ｎ攽閻ㄥ嫯鐦芥潻鎴濆磮鐎涙顑佹导姘皨閹存劒绔撮崸顭掔礉11fp 娑撳鍤戞稊搴濈瑝閸欘垵顕伴敍澶堚偓?
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

  /** 閼奉亣鐦夊鑺ョ垼閺堫兛缍嬮敍鍫ョ拨鎼存洜娅х€涙ぜ鈧椒绗夐崥鍐х皑娴犺翰鈧礁甯囬崷銊︽付娑撳﹪娼伴敍澶堚偓?*/
  @Builder
  private DiagBadge() {
    Text(this.diagText.length > 0 ? this.diagText : 'V af66eb1 (no data)')
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor('rgba(0, 0, 0, 0.78)')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(6)
      // 閳?2026-10-16閿涙艾绐橀弽鍥╁箛閸︺劍婀?**13 鐞?*閿涘牃鈧妇顑囬崡浣风癌鐞涘本甯堕崚璺哄隘閼奉亣鐦?/ 缁楊剙宕勬稉澶庮攽閸忔娊妫存潻鍥┾柤娴滃娆㈤弮銉ョ箶閿?
      //   娴滃娆㈤弮銉ョ箶閺堫剝闊╃亸杈ㄦЦ婢舵俺顢戦垾鏂衡偓鏂剧鐞涘奔绔存稉顏冪皑娴犺绱氶埇?`maxLines` 韫囧懘銆忔径鐕傜礉閸氾箑鍨張鈧崥搴濈鐞涘奔绱扮悮顐ｅ焻閹哄鈧?
      .maxLines(32)
      .position({ x: 8, y: 120 })
      .zIndex(99)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 妞ゅ爼鍎?闂呮劕鑸伴悜顓炲隘"閿涙俺绻涢悙?3 濞嗏€崇磻閸忓疇鍤滅拠浣哥獦閺嶅洢鈧?
   *
   * 閳跨媴绗?閺€鎯ф躬**妞よ埖鐖稊瀣╃瑓閵嗕礁鍞寸€归€涚娑?*閻ㄥ嫪绔存稉顏嗙崕閺夆槄绱欐?48vp閵嗕椒绗夐幏锕€鍙剧€瑰啩姘︽禍鎺嶄簰婢舵牜娈戞稉婊嗐偪閿涘绱?
   *   鐎瑰啫褰ч崥鍐╁竴閼奉亜绻佹潻娆庣閺夆€崇敨鐎涙劒绗傞惃鍕仯閸戜紮绱濇稉宥呭閸濆秵鎸遍弨?閸掑洦鐡?濮濆矁鐦濆姘З閵?
   */
  /**
   * 妞ゅ爼鍎?闂呮劕鑸伴悜顓炲隘"閿涙俺绻涢悙?3 濞嗏€崇磻閸忓疇鍤滅拠浣哥獦閺嶅洢鈧?
   *
   * 閳跨媴绗?**2026-10-16 娣囶喕绔存径鍕灉閼奉亜绻佸鏇炲弳閻ㄥ嫪姘︽禍鎺戞礀瑜?*閿涙氨顑囨稉鈧悧鍫濆晸閻ㄥ嫭妲?
   *   `Row().width('100%').height(48).position({x:0, y:96})` 閳ユ柡鈧?
   *   閼?*婢圭増妲戝?`.onClick` 娴兼碍绉风拹鐟版嚒娑擃厼灏崺?*閿涘潉HitTestMode` 姒涙顓荤€电鍤滈煬顐ュ瘱閸?Block閿?
   *   閳?鐎瑰啯濡?96閳?44 闁?*娑撯偓閺佸瓨娼Ο顏勬倻鐢箑鐡?*閻ㄥ嫮鍋ｉ崙璇插弿閸氬啯甯€娴滃棎鈧?
   *   閸︺劍鐡曠拠宥夈€夋稉濠囧亝娑撯偓鐢附妲?*濮濆矁鐦濈悰?*閿涘牏鍋ｅ宀冪槤鐠哄疇娴嗛敍澶嗗櫩 閻喎鐤勯崝鐔诲厴鐞氼偅灏呴妴?
   *
   * 閳?閻滄澘婀弨瑙勫灇**瀹革缚绗傜憴鎺嶇鐏忓繐娼?*閿?20鑴?0 @ y=88閿涘绱濋崣顏囶洬閻╂牕鐨濋棃銏犱箯娑撳﹨顫楅柇锝囧娑撳秴褰查懗鑺ユ箒娴溿倓绨伴惃鍕隘閸╃噦绱?
   *   璺?鐏忎線娼版い纰夌窗闁絼绔寸敮锔芥Ц鐏忎線娼伴崶鎯у剼閺堫剝闊╅敍鍫熸￥閻愮懓鍤拠顓濈疅閿涘绱?
   *   璺?濮濆矁鐦濇い纰夌窗`lyricPadTop()` 娣囨繆鐦夊宀冪槤濮濓絾鏋冩禒搴㈣癁鐏炲倷绗呴弬鐟扮磻婵绱濇稉宥勭窗閽€钘夊煂鏉╂瑤绔寸亸蹇撴健闁插被鈧?
   *   璺?妞よ埖鐖崷?`y < 88`閿涘奔绡冪喊棰佺瑝閸掕埇鈧?
   * 閳跨媴绗?閼汇儱鎽㈡径鈺勭箹閸фぞ绡冮棁鈧憰浣界殶娴ｅ秶鐤嗛敍?*閸忓牏鈥樼拋銈勭瑝閸樺婀?閺堝姘︽禍鎺旀畱鐢箑鐡?娑?*閵?
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

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 閹貉冨煑閸栭缚鍤滈崝銊︽暪鐠?閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓

  /**
   * 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻?`BarCollapse`閿涘绱伴幏鏍уЗ閹貉冨煑閺夆剝鏁圭挧?鐏炴洖绱戦惃?*閹靛濞嶉悩鑸碘偓浣规簚**閵?
   * 闁劖娼潪顒€鍟撶憴?`common/musicbasic/.../model/BarCollapse.ets`閿涘牆鎯堢€涙濡惍浣筋攽閸欏嘲顕悡褑銆冮敍澶堚偓?
   * 閸欘亝婀?`onChromeBarTouch()` 娴兼氨鏁ょ€瑰啨鈧?
   */
  private barCollapse: BarCollapse = new BarCollapse();

  /**
   * 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`PlayerPage.showChrome()`閿涘绱?*閸?娴滎喖鍤幒褍鍩楅崠?閿涘奔绗夐柌宥囩枂缁屾椽妫界拋鈩冩**閵?
   *
   * 閸戝搫顦╅敍鍧刜recover/logic-src/PlayerPage.abc.txt:11942-11982`閿涘绱?
   * ```
   *   showChrome() {
   *     if (chromeHidden) {
   *       getUIContext().animateTo({ duration: CHROME_ANIM_MS, curve: Curve.EaseInOut },
   *                                () => { chromeHidden = false; });   // 浣岪5*#
   *     }
   *   }
   * ```
   * 閳?閸忔娊鏁敍?*鐎瑰啴鍣烽棃銏＄梾閺?`startIdle()`**閿涘潉hideChrome` 闁插奔绡冨▽鈩冩箒 `clearIdle()`閿涘鈧?
   *   娑旂喎姘ㄩ弰顖濐嚛"閸炪倕鍤幒褍鍩楅崠?娑?鐠ч鈹栭梻鑼额吀閺?閺勵垱妫ら悾宀勫櫡**娑撱倓娆㈤悪顒傜彌閻ㄥ嫪绨?*閿?
   *   鐟曚椒绗夌憰浣芥崳鐠佲剝妞傞悽?*鐠嬪啰鏁ら悙?*閸愬啿鐣鹃敍鍫ｎ潌 {@link PlaybackPage.onSwiperIndexChanged} 娑?
   *   `onLyricInteract` / `onLyricSwipe`閿涘鈧倹鍨滄禒顒€甯弶銉﹀Ω娑撱倛鈧懏宕嬮幋鎰娑?`touchChrome()`閿?
   *   娴滃孩妲搁崷?閸掑洤鍩岀亸渚€娼版い?闁絾娼捄顖欑瑐娴?*妞ょ儤澧滈幎濠勨敄闂傝尪顓搁弮鏈电瘍鐠х柉鎹ｉ弶?* 閳ユ柡鈧?娑撳孩妫ら悾宀€娴夐崣宥忕礄闁綁鍣烽弰?`clearIdle()`閿涘鈧?
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
   * 鐠佹澘缍嶆稉鈧▎鈩冨付閸掕泛灏禍銈勭鞍閿?*閸炪倕鍤?+ 闁插秶鐤嗛懛顏勫З閺€鎯版崳鐠佲剝妞?*閵?
   *
   * 閺冪姷鏅柌宀冪箹娑撱倓娆㈡禍瀣Ц閸掑棗绱戦惃鍕剁礄`showChrome()` 娑?`startIdle()`閿涘绱濋崣顏呮箒
   * "閻劍鍩涢崷銊︾摃鐠囧秹銆夋稉濠勫仯娴?娑撳绮︽禍?鏉╂瑧琚?*閻喍姘︽禍?*閹靛秴鎮撻弮璺轰粵娑撱倓娆?閳ユ柡鈧?閹碘偓娴犮儴绻栭柌灞肩箽閻ｆ瑨绻栨稉顏嗙矋閸氬牆鍙嗛崣锝忕礉
   * 閻㈣精鐨熼悽銊у仯閼奉亜绻侀柅澶涚礄閸掑洭銆夐柇锝嗘蒋鐠侯垰褰х拫鍐ㄥ従娑擃厺绔存稉顏庣礉鐟?`onSwiperIndexChanged`閿涘鈧?
   */
  private touchChrome(): void {
    this.chromeTouchedAtMs = Date.now();
    this.showChrome();
    this.scheduleChromeAutoHide();
  }

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 鐟佷礁澹€鐎圭懓娅掕ぐ銏犲綁閿涘牆顕弽鍥ㄦ￥閻?ExpandAnimation閿涘鏀㈤埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧?

  /**
   * @returns 閺佹挳銆夋稉宥夆偓蹇旀鎼达讣绱?*閹帊璐?1**閿涘牆顔愰崳銊︽拱闊偂绗夊ǎ鈽呯礆閵?
   *
   * 閳跨媴绗?鏉╂瑩鍣烽崢鐔告降閹?`p/0.12` 濞ｂ€冲弳閺佺繝閲滅€圭懓娅掗敍灞炬Ц**閹存垼鍤滃杈╂畱閸欐垶妲?*閿涘苯寮界紓鏍槯闁?
   *    `applyPullProgress` 娑撳秶顫禒璁崇秿闁繑妲戞惔锔衡偓涔verlayColor` 娑旂喐浜芥稉?`#00000000`閵?
   *    鐎电懓绨查惃?鐠ч鍋ｆ稉宥団敄"閻㈣精鍎楅弲顖氱湴閻?`pullBgIn`閿?閳?.30閿涘绗岄崣鐘叉躬閺堚偓娑撳﹪娼伴惃鍕敾妞嬬偛鐨濋棃?閸忓娈曠仦鍌濈鐠愶絻鈧?
   *    閻劍鍩涚€圭偞绁存稊鐔衡€樼拋銈堢箖鏉╂瑤绔撮悙鐧哥窗"閺冪姷鏅崝銊ф暰瀵偓婵绗夐弰顖炩偓蹇旀閻?閵?
   */
  private morphOpacityValue(): number {
    // 閳?閼奉亣鐦夊鑺ョ垼閿涙艾濮╅悽缁樻埂闂傛挳鈧劕鎶氶崚閿嬫煀鐠囩粯鏆熼敍鍫濈獦閺嶅洤鍙ч惈鈧弮璺虹暊缁斿鍩?return閿涘矂娴傚鈧柨鈧敍澶堚偓?
    //   閺€鎯ф躬鏉╂瑩鍣烽弰顖氭礈娑撶儤婀伴崙鑺ユ殶**濮ｅ繐鎶氶柈鍊燁潶鐠嬪啰鏁?*閿涘奔绗栭崘娆戞畱閺勵垯琚辨稉顏呮拱妞?`@Local` 鐎涙顔岄敍?
    //   娑撳骸濮╅悽鑽ゅЦ閹礁鐣崗銊︽￥閸忕绱欑痪顖氬涧鐠囦紮绱氶妴鍌滄暏閹村嘲婀崝銊ф暰**缂佹挻娼稊瀣倵**鐠囪鍩岄惃鍕皑閺勵垱鏁圭亸楣冨亝娑撯偓閸掕崵娈戦崐绗衡偓?
    this.refreshDiagText();
    // 閳?缂佹ê鍩楅梻顭掔礄鐟?`introPaintReady`閿涘绱拌ぐ銏犲綁瀵偓婵绠ｉ崜宥嗘殻妞ゅ吀绗夐悽浼欑礉闁灝鍘ら柇?1~2 鐢囨／閸戝搫鐣弫瀛樻尡閺€楣冦€夐妴?
    // 閳跨媴绗?娑撱倖娼?*韫囧懘銆忛弨鎹愵攽**閻ㄥ嫭鍎忛崘纰夌礄閸氾箑鍨亸杈ㄦЦ"閹绢厽鏂侀悾宀勬桨閹垫挷绗夊鈧?閿涘绱?
    //   1. 瀹歌尙绮￠拃鎴掔秴閿涘牏娴夋担?OPEN閿涘鈧柡鈧?閺冪姾顔戦梻銊︽Ц娴犫偓娑斿牏濮搁幀渚婄礉闂堟瑦顒涢幀浣风瀵板顩﹂悽浼欑幢
    //   2. 閹靛瀵氬锝呮躬妞瑰崬濮╅敍鍫滅瑐閹?娑撳濯虹捄鐔稿閿涘鈧柡鈧?闁絾娼捄顖欑瑝鏉?`tryStartMorphIntro` 閻ㄥ嫬绱戦梻銊ュ瀻閺€顖ょ礉
    //      闂傘劋绱版稉鈧惄鏉戝彠閻偓閿涘牐绻栧锝嗘Ц娑撳﹣绔撮悧?閹垫挷绗夊鈧幘顓熸杹閻ｅ矂娼?閻ㄥ嫭鐗撮崶鐙呯礆閵?
    if (this.expandState.morphStage === MorphStage.OPEN || this.introPaintReady ||
      (this.expandState.morphUsable && this.expandState.morphSessionDriving())) {
      return 1;
    }
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER &&
      this.expandState.morphUsable) {
      return 1;
    }
    // 閳藉應妲?2026-10-16閿涘牏鍋ｉ崙缁樺ⅵ瀵偓閻ㄥ嫮顑囨禍灞藉磹閿涘绱?
    //   鏉╂瑤绔村▓鍨Ц"婢瑰啿鐪板韫礋鏉╂瑤绔存潪顔挎崳娴滃棗鑸伴崣妯圭窗鐠囨繐绱檂morphSessionStarted`閿涘绱濇担鍡楀殤娴ｆ洝绻曞▽鈥冲竾閸掓媽鎹ｉ悙?
    //   閳?鏉╂柨娲?0閿涘牊鏆ｆい鍏哥瑝閻紮绱氶敍灞惧皡娴?閹稿倽娴囬柇?1~2 鐢囨／閸戝搫鐣弫瀛樻尡閺€楣冦€?閵?
    //   閳跨媴绗?閸擃垯缍旈悽顭掔礄瀹歌尙鐓￠妴浣瑰复閸欐绱氶敍姘崇箹閸戠姴鎶氶柌?*婢瑰啿鐪伴惃鍕帗娣団剝浼呴崗瀣畷鐏炲偊绱檂MorphMetaBridge`閿涘绻曢崷銊ф暰**
    //     閿涘牆鐣犻崷銊х崶閸欙絽娼楅弽鍥︾瑐閵嗕椒绗夐崥鍐╂拱妞ょ數娈?opacity閿涘鍣?鐏炲繋绗傛导姘箒娑撯偓鐞涘本鐡曢崥?濮濆本澧滈崗鍫滃瘨閻偓閵?
    //     鏉╂瑦妲搁弮鐘垫櫕閸氬本鐎惃鍕埌閻樿绱欑€瑰啰娈?`floatingMeta` 娑旂喎婀幘顓熸杹妞ゅ吀绠ｆ径鏍电礆閿?*娑撳秴鍟€閸欙箑浠涚悰銉ょ**閵?
    return 0;
  }

  /**
   * 瑜般垹褰夐張鐔兼？"閼冲本娅欓弫鏉戠湴"閻ㄥ嫪绗夐柅蹇旀鎼达讣绱欓棃娆愵剾閹焦浜?1閿涘鈧?
   *
   * 閳藉應妲勯埥?2026-10-16閿?*閻撗勫Ρ閺冪姷鏅?`pullBgOpacity`**閿涘奔鎱ㄩ悽銊﹀煕鐎圭偞绁撮妴灞炬尡閺€鎯ф珤鐏炴洖绱戞潻妯绘Ц閼冲本娅欓崗銊ョ潌閵嗗稄绱?
   *
   * ## 閺冪姷鏅惃鍕斧瀵骏绱欑€涙濡惍渚€鈧劖娼拠璇插毉閺夈儳娈戦敍?
   *
   * ```
   *   PULL_BG_FLOOR = 0.04          wujie.pa:179978-179979  (fldai 4.0e-2)
   *   PULL_BG_IN_END = 0.30         wujie.pa:179980-179981  (fldai 3.0e-1)
   *
   *   pullPaintable = pullGeomReady && !morphSquashing      wujie.pa:176560-176579
   *   pullBgIn      = clamp(effT / PULL_BG_IN_END)          wujie.pa:176295-176326
   *                   // effT = 瑜般垹褰夋稉?? morphT : 1  閳?闂堟瑦顒涢幀浣逛航 1
   *   pullBgOpacity = !pullPaintable ? 0
   *                                 : PULL_BG_FLOOR + pullBgIn 鑴?(1 閳?PULL_BG_FLOOR)
   *                                                          wujie.pa:176331-176372
   * ```
   *
   * ## 閳跨媴绗嶉埧鐙呯瑣 閺堫剝鐤?*鐠併垺顒滄稉鈧径鍕灉鐠囪寮芥禍鍡欐畱閺嬩焦鈧?*閿涘牆鍩嗛崘宥囧弾閻偓閺冄勬暈闁插﹥鏁奸崶鐐插箵閿?
   *
   * 閹存垵澧犳稉鈧悧鍫熷Ω `pullBgOpacity` 鐠囩粯鍨?閻愮懓鍤仦鏇炵磻閺?`pullPaintable()` 娑撳搫浜?閳?閼冲本娅欐稉宥囨暰"閿?
   * 楠炶埖宓佸銈堫唨閺堫剙鍤遍弫鏉挎躬闂堢偠绐￠幍瀣埌閸欐ɑ妞?`return 0`閵?*鐠囪寮芥禍?*閿?
   *
   * * `jnez L` 閻ㄥ嫯顕㈡稊澶嬫Ц"**閺夆€叉娑撳搫浜?*閺冩儼鐑?閿涘牆鍑￠悽?`playerSwiperGapOf` 闁絾濡哥亸鍝勭摍闁藉顒撮敍澶涚幢
   * * `lda pullPaintable(); isfalse; jnez L2` 閳?**`pullPaintable() === true` 閺冩儼鐑﹂崚?L2**閿?
   *   閼?L2 閹靛秵妲?缁?`PULL_BG_FLOOR + pullBgIn 鑴?0.96`"闁絼绔撮弨顖ょ幢
   * * 閸欘亝婀?`pullPaintable()` 娑撳搫浜ｉ幍?`ldai 0x0; return`閵?
   *
   * 閼?`pullPaintable = pullGeomReady && !morphSquashing`閿涘潉morphSquashing` 閸欘亜婀?
   * 閸忔娊妫撮拃鎴掔秴闁絼绔寸拋鐗堝皨閸樺婀￠梻缈犺礋閻噦绱氶埇?**娑撳﹥濯?閻愮懓鍤仦鏇炵磻閸忋劎鈻兼稉铏规埂** 閳?**閼冲本娅欓崗銊р柤闁晫鏁?*閵?
   * 閳?閻劍鍩涚€圭偞绁撮妴?*閺冪姷鏅崝銊ф暰鏉╁洨鈻奸張澶庡剹閺咁垳娈戦敍鍫ｅ殾鐏忔垵鐤勯張鐑樻Ц鏉╂瑦鐗遍敍?*閵嗗秵顒滈弰顖濈箹閺夛紕瀚粩瀣槈閹诡喓鈧?
   *
   * ## 缂佹捁顔戦敍鍫熸拱娴犳挻妲х亸鍕剁礆
   *
   * | 閸︾儤娅?| 缂佹挻鐏?|
   * | --- | --- |
   * | 闂堟瑦顒涢幀?| 1 |
   * | 瑜般垹褰夋稉?| `PULL_BG_FLOOR + pullBgIn 鑴?(1 閳?PULL_BG_FLOOR)` = `0.04 閳?1`閿涘潉pullIn 閳?0.30` 閸氬孩浜?1閿?|
   * | 閽€鎴掔秴閹搞倕甯囬敍鍧刴orphSquashing`閿?| 0閿涘牊妫ら悾宀勫亝娑撯偓濡楋絼绡冩稉鈧弽鍑ょ礆 |
   *
   * 閳跨媴绗?閺冄勬暈闁插﹪鍣?**娑撳秷顩?*閻撗勫Ρ `clamp(p/0.30)`"闁絾娼紒鎾诡啈**瀹歌弓缍旀惔?*閿涙艾鐣犻幏鍛妇閻ㄥ嫭妲?閼冲本娅欑仦鍌氭躬
   * **鐞氼偉顥嗛崜顏嗘畱鐏忓繒鐛ラ崣锝夊櫡**閵?0% 鐏忚鲸寮ф稉宥夆偓蹇旀 閳?缁愭褰涢柌灞肩閺佹潙娼℃?閵嗗倽鈧矁鍎楅弲顖氱湴閻滄澘婀弰?*閸︺劏顥嗛崜顏勵啇閸ｃ劌鍞撮柈?*
   * 閿涘煪?0 閻撗勬儔閺冪姷鏅惃鍕湴缁狙嶇礆閿涘矂鍋呮稉顏勮埌閻樻湹绗夌€涙ê婀禍鍡愨偓?
   *
   * 閳跨媴绗?**2026-10-16 娴滃本顐肩拋銏☆劀閿涘牏鏁ら幋宄扮杽濞村鈧瞼鍋ｉ崙缁樺ⅵ瀵偓/閻愮懓鍤崗鎶芥４/缁崵绮烘潻鏂挎礀鏉╂ɑ妲稿▽鈩冩箒閵嗗稄绱?*閿?
   *   娑撳娼伴柇锝呭綖 `if (this.expandState.morphSquashY !== 1) return 0;` **閺勵垶鏁婇惃?* 閳ユ柡鈧?
   *   鐎瑰啯婀伴幇蹇旀Ц瑜?閽€鎴掔秴閹搞倕甯?閿涘牊妫ら悾?`morphSquashing`閿涘绱濇担?`morphSquashY` 閸?*閻愮懓鍤?鏉╂柨娲?*鏉╂瑦娼捄顖欑瑐
   *   娑旂喍绱版稉宥囩搼娴?1閿涘牆鍙ч梻顓℃儰娴ｅ秹鍋呮稉鈧拋?110ms+320ms 閻ㄥ嫭灏嬮崢瀣剁礆閿涘奔绨弰顖涙殻閺壜ょ熅閻ㄥ嫯鍎楅弲顖濐潶閸樺鍨?0
   *   閳?閻劍鍩涢惇瀣煂閻ㄥ嫭妲?**閸欘亝婀佹稉濠冨闁絾娼張澶庡剹閺?*"閵?
   *   閳?閻滄澘婀弨瑙勫灇閿?*閸欘亣顩﹂張澶婅埌閸欐﹫绱濋懗灞炬珯鐏忚鲸瀵?`pullBgIn` 娑撳﹥璐伴崗?*閿涘奔绗夐崘宥咁嚠 Drive 閹存牗灏嬮崢瀣粵閻楄鐣╅崚銈嗘焽閵?
   *     閼冲本娅欏鑼病鐞氼偄顔愰崳銊梿閸擃亷绱欐悅90閿涘绱濋幍鈧禒?瑜般垹褰夐弮鈺傛埂閺佹潙鐫?鏉╂瑤閲滄い鎹愭閺堫剝闊╂稊鐔剁瑝鐎涙ê婀禍鍡愨偓?
   *
   * 閳跨媴绗?鐎瑰啫鎮撻弮鍓侇吀閻偓閿涙艾鐏氭惔鏇炵湴閵嗕礁褰囬弽鐤鐏炲倶鈧胶缍夐弽鐓庣湴閵嗕礁绶為崥鎴炴鐟?閳ユ柡鈧?閺€鐟扮暊缁涘绨弨纭呯箹閸ユ稑鐪伴妴?
   * 閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdBgOpacity'`
   * @returns 0..1閿涘牓娼ゅ銏♀偓?= 1閿?
   */
  private backgroundRevealOpacity(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    // 2026-10-17: single upstream formula only (PULL_BG_FLOOR + pullBgIn * (1 - FLOOR));
    // the pullMode / morphDrive split was MY invention and made the first frame fully opaque.
    // It works on the tween path because the tween now writes ONLY morphP (see applyMorphProgress);
    // @Monitor('morphP') recomputes geometry every frame, so pullBgIn animates 0 -> 1 over 30%.
    return PlaybackPage.PULL_BG_FLOOR + this.pullBgIn() * (1 - PlaybackPage.PULL_BG_FLOOR);
  }

  /** 閺冪姷鏅?`PULL_BG_FLOOR`閿涘潉wujie.pa:179978-179979`閿涘畭fldai 4.0e-2`閿涘鈧?*/
  private static readonly PULL_BG_FLOOR: number = 0.04;

  /** 閺冪姷鏅?`PULL_BG_IN_END`閿涘潉wujie.pa:179980-179981`閿涘畭fldai 3.0e-1`閿涘鈧?*/
  private static readonly PULL_BG_IN_END: number = 0.30;

  /**
   * @returns 閺冪姷鏅?`pullBgIn() = clamp(effT / PULL_BG_IN_END)`閿涘潉wujie.pa:176295-176326`閿涘鈧?
   *
   * `effT = 瑜般垹褰夋稉?? morphT : 1` 閳?闂堟瑦顒涢幀浣逛航 1閿涘牆宓?`pullBgIn = 1`閿涘鈧?
   * 閳跨媴绗?閺堫兛绮ㄩ惃?瑜般垹褰夋潻娑樺"鐎电懓绨?`morphP`閿涘牆鐫嶅鈧?0閳? / 閺€鎯版崳 1閳?閿涘绱濇稉搴㈡￥閻ｅ瞼娈?`morphT` 閸氬苯褰涘鍕┾偓?
   */
  private pullBgIn(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    const raw: number = this.expandState.morphP / PlaybackPage.PULL_BG_IN_END;
    return raw < 0 ? 0 : (raw > 1 ? 1 : raw);
  }

  /**
   * 閹烘帒鐣鹃懛顏勫З閺€鎯版崳閵?
   *
   * 閻?`setTimeout` 閼板奔绗夐弰?`setInterval`閿涙艾褰х憰浣圭槨濞嗏€叉唉娴滄帡鍣搁弬鐗堝笓娑撯偓濞嗏€虫皑婢剁喍绨￠敍?
   * 鐢悂鈹楃€规碍妞傞崳銊ょ窗閸︺劑銆夐棃顫瑝閸欘垵顫嗛弮鍓佲敄鏉烆剨绱欓幘顓熸杹妞ょ數绮＄敮鎼佹毐閺冨爼妫块幐鍌滄絻閿涘鈧?
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
      // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`hideChrome()` 閻?闂堛垺婢樺鈧惈鈧亸鍙樼瑝閺€?閿涘畭abc.txt:4124-4225`閿涘绱?
      //   闁絼绔撮弶鈩冩Ц 10 娑擃亪娼伴弶?flag 閻ㄥ嫮鐓捄顖涘灗闁炬拝绱遍張顑跨波閻ㄥ嫬鍨庨柌蹇氼潌 `auxSheetOpen` 閻ㄥ嫭鏁為柌?
      //   閿涘牐褰嶉崡鏇氱閺?閳?`playMenuOpen`閿涙盯妲﹂崚?閸忔湹绮悧鍫熸拱 閳?`auxSheetOpen`閿涘鈧倷琚辨稉顏堝厴鐟曚礁鍨介妴?
      if (this.playMenuOpen || this.auxSheetOpen) {
        Logger.info('RzdLyricChrome',
          `hide skipped (panel open: menu=${this.playMenuOpen ? 1 : 0} aux=${this.auxSheetOpen ? 1 : 0})`);
        return;
      }
      // 濮濓絽婀弨鎯版崳/鐏炴洖绱戦幘顓熸杹閸ｃ劍妞傛稉宥嗗ⅵ閹?
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
   * @returns 閹貉冨煑閸栫儤妲搁崥锕€褰叉禒?閺€鎯版崳閺?閿涘牐鍤滈崝銊р敄闂傚弶鏁圭挧?+ 閹锋牕濮╅弨鎯版崳閸忚京鏁ゆ潻娆庣閹跺﹪妫敍澶堚偓?
   *
   * 閳藉應妲勯埥?2026-10-17閿?*鐠併垺顒滄稉濠佺鏉烆喚娈戞稉鈧稉顏堟晩缂佹捁顔?閳ユ柡鈧?鐎瑰啫缍嬮弮璺哄涧閻?`startIdle` 閸愬懘鍎撮敍灞剧础娴滃棙澧嶉張澶庣殶閻劎鍋?*閿涘鈧?
   *
   * ## 閺冪姷鏅惃鍕皑鐎圭儑绱扮粚娲＝閺€鎯版崳**閸欘亜婀宀冪槤妞ら潧褰傞悽?*
   *
   * 娑撳﹣绔存潪顔藉灉鐠囪鍩?`startIdle()`閿涘潉PlayerPage.abc.txt:12394-12435`閿涘鍣烽柇锝変壕闂傘劍妲?
   * `entryAllowsAuto(this.lyricImmersive)`閿涘矁鈧?`lyricImmersive` 閺?*閻劍鍩涢崑蹇撱偨**
   * 閿涘潉wujie.pa:169823-169825`閿涙瓪this.lyricImmersive = pref.lyricImmersiveMode`閿?
   * 閳?娴滃孩妲搁崘娆庣啊閵?*閺冪姷鏅惃鍕，娑?瑜版挸澧犻崷銊ユ憿娑撯偓妞?閺冪姴鍙?閳?鐏忎線娼版い鍏哥瘍娴兼氨鈹栭梻鍙夋暪鐠?*閵嗗稄绱?
   * 楠炶埖濡搁張顒佹煙濞夋洘鏂佺€硅棄鍩?`usesPhoneSwiperLayout()`閵?
   * **闁絼閲滈幒銊啈閺勵垶鏁婇惃?* 閳ユ柡鈧?妞ょ敻娼伴惃鍕閸掓湹绗夐崷?`startIdle` 闁插矉绱濋懓灞芥躬**鐎瑰啰娈戝В蹇庣娑擃亣鐨熼悽銊у仯**娑撳绱?
   *
   * | 鐠嬪啰鏁ら悙?| 鐎涙濡惍?| 閺夆€叉 |
   * | --- | --- | --- |
   * | swiper `onChange` | `abc.txt:23189-23215` | **`index === 1`閿涘牊鐡曠拠宥夈€夐敍澶嗗櫩 `startIdle()`**閿涙稑鎯侀崚?閳?`clearIdle() + showChrome()`閿?*娑撳秷鎹ｇ拋鈩冩**閿?|
   * | 濮濆矁鐦濋崠楦啃曢幗鍛婂М鐠у嘲澧?| `abc.txt:6914-6932`閿涘潉onLyricInteract`閿?| 娴犲懎婀?*濮濆矁鐦濇い?*娑?`!chromeHidden` 閺?`startIdle()` |
   * | 濮濆矁鐦濋崠杞扮瑓濠?| `abc.txt:6938-6985`閿涘潉onLyricSwipe`閿涘畭offsetY 閳?SWIPE_TOGGLE_VP 24`閿?| 娴犲懎婀?*濮濆矁鐦濇い?*閿涙瓪showChrome() + startIdle()` |
   * | 濞屽韫堝Ο鈥崇础閸欐ɑ娲?| `abc.txt:7766-7800` | `entryAllowsAuto(mode) && !chromeHidden && swiperProgress > 0.5` |
   *
   * 閳?**閸ユ稐閲滅挧椋庡仯閸忋劌婀宀冪槤妞ょ绱濋懓灞藉瀼閸掓澘鐨濋棃銏ゃ€夐柇锝勭閺€顖涙Ц閺勬儳绱￠惃?`clearIdle()`**
   *   閳?**閺冪姷鏅崷銊ョ殱闂堛垽銆夋稉宥勭窗缁屾椽妫介弨鎯版崳閹貉冨煑閸?*閵?
   *   閳?閼板奔绗栨潻娆愵劀閺勵垳鏁ら幋閿嬫－閸忓牊濮ら惃鍕亝娑撯偓閺夆槄绱伴妴灞炬箒閺?*閹绢厽鏂佹い鐢割浕妞?*娑撳鏌熼崙鐘遍嚋閹稿鎸虫稊鐔剁窗闂呮劘妫岄妴宥佲偓鏂衡偓?
   *     鐏忎線娼版い鐢告閽樺繑妲?*閹存垳婊?*鐢箒绻橀弶銉ф畱鐞涘奔璐熼敍灞肩瑝閺勵垱妫ら悾宀€娈戦妴?
   *
   * ## 閻滄澘婀惃鍕灲閹?
   * 閹靛婧€ Swiper 鐢啫鐪敍鍫濈殱闂堛垽銆?濮濆矁鐦濇い浣冪箹婵傛绱?*娑?*閸嬫粌婀宀冪槤妞ょ偣鈧?
   * 閳跨媴绗?鏉╂瑤绗屾稉濠佺鏉烆喕绠ｉ崜宥囨畱閸愭瑦纭舵稉鈧懛杈剧礄`WIDTH_SM && 濮濆矁鐦濇い绀伴敍澶涚礉瀹割喖鍩嗛崣顏呮Ц鐎硅棄瀹抽崚銈嗗祦閹广垺鍨氭禍?
   *   `usesPhoneSwiperLayout()`閿涘牅绗?`Swiper` 閻喎鐤勯弰顖氭儊娴ｈ法鏁ら崥灞肩閸欙絽绶為敍灞炬纯绾剨绱氶妴?
   * 閳跨媴绗?閺堫剟妫弰?閼奉亜濮╅弨鎯版崳 + 閹锋牕濮╅弨鎯版崳"閸忚京鏁ら惃?閳ユ柡鈧?娑撱倛鈧懏瀵滈弮鐘垫櫕娑?*闁棄褰ч崷銊︾摃鐠囧秹銆?*鐠ц渹缍旈悽?
   *   閿涘潉BarCollapse` 閹稿倸婀宀冪槤妞ょ敻鍋呮總妤佸付閸掕泛灏稉濠忕礆閵?
   */
  private canHideLyricChrome(): boolean {
    return this.usesPhoneSwiperLayout() &&
      this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
  }

  private hideLyricChrome(): void {
    if (!this.canHideLyricChrome() || this.chromeCollapsed) {
      return;
    }
    // 閳?閸氬奔绔撮弶鈥崇暓閸楊偓绱欑憴?`scheduleChromeAutoHide` 闁插瞼娈戠拠瀛樻閿涘绱伴棃銏℃緲瀵偓閻偓鐏忓彉绗夐弨韬测偓?
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
   * Swiper 閹广垽銆夐弮鍓佹畱閹貉冨煑閸栫儤鏁圭亸?閳ユ柡鈧?**閻撗勬儔閺冪姷鏅柇锝勯嚋 `onChange` 浣?閻ㄥ嫰鈧劕鐡х紒鎾寸€?*
   * 閿涘潉_recover/logic-src/PlayerPage.abc.txt:23189-23215`閿涘鈧?
   *
   * 閳藉應妲勯埥?2026-10-17閿涘潛oal 閺€璺虹啲婢跺秵鐗抽敍?*閸ョ偛甯慨瀣摟閼哄倻鐖滅涵顔款吇**閿涘苯鍤径?
   *   `_recover/disasm/wujie.pa:190080-190111`閿涘苯宓?`PlayerPage.@34*^1*#^1`閿涘绱?
   * ```ts
   *   onChange(index) {                                  // a3 = index
   *     const L = 1;                                     // 190081-190082閿? SWIPER_INDEX_LYRIC閿?
   *     if (index === L) { this.startIdle(); }            // 190083-190089  閳?濮濆矁鐦濇い纰夌窗鐠х柉顓搁弮?
   *     else { this.clearIdle(); this.showChrome(); }     // 190091-190099  閳?鐏忎線娼版い纰夌窗閸嬫粏顓搁弮?+ **閺勬儳绱￠崬銈呭毉**
   *     this.atLyricScreen = (index === L);               // 190100-190105
   *     this.syncKeepScreenOn();                          // 190106-190109
   *   }
   * ```
   * 閳?**缁屾椽妫界拋鈩冩閸欘亜婀宀冪槤妞や絻鎹?*鏉╂瑤绔撮悙鐧哥礉閺勵垯绗傚〒鍝ユ畱**閺勬儳绱￠崚鍡樻暜**閿涘牅绗夐弰顖涘灉娴狀剚甯归弬顓犳畱閿涘婀?
   *    閳ユ柡鈧?goal 缁?4 閺壜扳偓宀€鈹栭梻鑼额吀閺冭翰鈧秴鍩屽?*閺堝宓侀崣顖涚叀**閿涘奔绗夐棁鈧憰浣稿晙閺嶆悶鈧?
   *    閿涘牆褰熼敍姝歴tartIdle` 閻ㄥ嫭妞傞梹鍨埗闁?`IDLE_MS` 閸欘亜婀拠銉ュ毐閺佷即鍣烽崙铏瑰箛娑撯偓濞嗏槄绱?
   *      `wujie.pa:179903-179985`閿涙稒婀版禒鎾愁嚠鎼?`PlaybackPage.CHROME_AUTO_HIDE_MS = 5000`閵嗗偊绱?
   *
   * 閳跨媴绗?閹存垳婊戦崢鐔告降閺勵垱妫ら弶鈥叉 `touchChrome()`閿? 閸炪倕鍤?**+** 鐠х柉顓搁弮璁圭礆閿涘苯鍟€閸︺劑娼宀冪槤妞や絻藟娑撯偓閸?
   *   `stopChromeAutoHide()`閵嗗倿鍋呴弽宄版躬**閸掑洤鍩岀亸渚€娼版い?*閺冭埖妲?閸忓牐鎹ｇ拋鈩冩閸愬秴浠犻幒?閿?
   *   閸戔偓閺佸牊鐏夐搹鐣屽姧娑旂喎顕敍灞肩稻娑撳孩妫ら悾?闁綁鍣烽弽瑙勬拱娑撳秴鏁滈崙?vs 鏉╂瑩鍣锋导姘暅閸?閻ㄥ嫬妯婇崚顐ヮ潶閹惰甯€娴?閳ユ柡鈧?
   *   閺冪姷鏅崚鍥у煂鐏忎線娼版い鍨Ц**閺勬儳绱￠崬銈呭毉**閿涘牏鏁ら幋铚傜矤濮濆矁鐦濇い鍨拨閸ョ偞娼甸弮鑸靛付閸掕泛灏稉鈧€规碍妲告禍顔炬畱閿涘绱?
   *   鏉╂瑤绔撮弶鈩冨灉娴狀剛顫褌绡冪€电櫢绱濇担?*閸斻劍婧€娑撳秴鎮?*閿涘奔绗栫亸鎴滅啊"濮濆矁鐦濇い鐢稿亝娑撯偓閺€顖欑瑝閸炪倕鍤?閵?
   *
   * 閳跨媴绗?閸欙附婀?*閺堝鍓伴弨鍓佺崕**閿涙碍鍨滄禒顒勫亝娑撯偓閺€顖炲櫡婢舵矮绔撮柆?`canHideLyricChrome()`
   *   閿? `usesPhoneSwiperLayout() && 閸嬫粌婀宀冪槤妞ょぐ閿涘鍣?鐎硅棄鐫?闂堛垺婢橀柇锝勮⒈閺€顖欑瑝鐠х柉顓搁弮韬测偓?
   *   娑撳﹥鐖?`startIdle` 閼奉亜绻佹潻妯绘箒濞屽韫堝Ο鈥崇础缁涘鍞撮柈銊╂閿涘牊婀版禒鎾愁嚠鎼?`entryAllowsAuto` 闁絾娼敍澶堚偓?
   *
   * @param index 閺傛壆娈戞い鍏哥瑓閺嶅浄绱? = 鐏忎線娼版い纰夌礉1 = 濮濆矁鐦濇い纰夌礆
   */
  private onSwiperIndexChanged(index: number): void {
    if (index === PlaybackPage.SWIPER_INDEX_LYRIC) {
      // startIdle閿涙瓪scheduleChromeAutoHide()` 閸愬懘鍎撮懛顏勭敨"`canHideLyricChrome()` 娑撳秵鍨氱粩瀣皑娑撳秵鏁?
      this.scheduleChromeAutoHide();
      return;
    }
    this.stopChromeAutoHide();
    this.showChrome();
  }

  /**
   * 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻?`BarCollapse`閿涘绱?*閹锋牕濮╅幒褍鍩楅弶鈩冩暪鐠?/ 鐏炴洖绱?*閵?
   *
   * 閺冪姷鏅惃鍕閸旇法濮搁幀浣规簚閿涘潉design/src/main/ets/logic/BarCollapse.ets`閿涘苯鐡ч懞鍌滅垳
   * `wujie.pa:83706-84140`閿涘鍑￠柅鎰蒋鏉烆剙鍟撻崚?`common/musicbasic/.../model/BarCollapse.ets`
   * 閿涘牆鎯?`THRESHOLD = 1.5`閵嗕浇閰遍崥鎴︽敚鐎规哎鈧梗run` 缁鳖垳袧閵嗕胶娲伴弽鍥︾閼风繝绗夐崝銊ょ稊閵?*250ms 閼哄倹绁?*閿涘鈧?
   * 閺堫剚鏌熷▔鏇炲涧閸嬫矮琚辨禒鏈电皑閿?*閹跺﹨袝閹介晲绨ㄦ禒璺烘澓鏉╂稑骞?* + **閹稿鐣犳潻鏂挎礀閻ㄥ嫬濮╂担婊堚攳閸斻劍鏁圭挧?鐏炴洖绱?*閵?
   *
   * 鐠囶厺绠熼敍鍫㈠弾閹跺嫬鎮楅惃鍕攽娑撶尨绱氶敍?
   * ```
   *   璺?缁鹃潧鎮滄稉瀣缁鳖垵顓?閳?閳?.5vp 閳?COLLAPSE閿涘牊甯堕崚璺哄隘閺€鎯版崳閿?
   *   璺?缁鹃潧鎮滄稉濠冨腹缁鳖垵顓?閳?+1.5vp 閳?EXPAND  閿涘牊甯堕崚璺哄隘鐏炴洖绱戦敍?
   *   璺?濡亜鎮滈柨浣哥暰 閳?閺佺繝瑕嗛幍瀣◢韫囩晫鏆愰敍鍫滅瑝娴兼艾鎷板宀冪槤濡亝绮﹂幍鎾寸仸閿?
   * ```
   * 閳跨媴绗?閸斻劎鏁惧▽璺ㄦ暏閺堫剟銆夐弮銏℃箒閻ㄥ嫰鍋呮稉鈧總妤嬬礄`chromeCollapsed` + `lyricChromeProgress`閿?40ms `EaseOut`閿涘绱?
   *   娑撳氦鍤滈崝銊︽暪鐠у嚖绱?s 缁屾椽妫介敍?*閸忚京鏁ら崥灞肩閺壜ょ熅瀵?* 閳?娑撱倗顫掗崗銉ュ經鐟欏倹鍔呮稉鈧懛娣偓?
   * 閳跨媴绗?閺€鎯版崳闂傘劍閮ㄩ悽?`canHideLyricChrome()` 閳ユ柡鈧?**娑撳氦鍤滈崝銊︽暪鐠ф灚鈧焦瀚嬮崝銊︽暪鐠у嘲鎮撴稉鈧幎濠囨，**
   *   閿涘牏鍙庨幖顒佹￥閻?`startIdle` 閸氬骸鐣犲鍙夋杹鐎硅棄鍩?閹靛婧€ Swiper 鐢啫鐪?閿涘苯鎯堢亸渚€娼版い纰夌礉鐟欎線鍋呮稉顏呮煙濞夋洜娈戝▔銊╁櫞閿涘鈧?
   *   閹碘偓娴犮儰绗夋导姘毉閻?閼奉亜濮╅懗鑺ユ暪閵嗕焦瀚嬮崝銊ょ瑝閼宠姤鏁?鏉╂瑧顫掓稉宥勭閼锋番鈧?
   * @param event 閹貉冨煑閸栧搫顔愰崳銊ょ瑐閻ㄥ嫯袝閹介晲绨ㄦ禒?
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
      // 鐏炴洖绱?= 閺堫剟銆夐弮銏℃箒閻?閸炪倕鍤幒褍鍩楅崠?閿涘潉touchChrome()` 闁插矂鍋呭▓?240ms 閸斻劎鏁?+ 闁插秶鐤嗙粚娲＝鐠佲剝妞傞敍?
      this.touchChrome();
    }
  }

  /** 閸嬫粍甯€閼奉亜濮╅弨鎯版崳鐠佲剝妞傞敍鍫ャ€夐棃銏犲祻鏉炲鈧礁绱戞慨瀣暪鐠ч攱鎸遍弨鎯ф珤閺冩儼鐨熼悽顭掔礆閵?*/
  private stopChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
  }

  /**
   * 閻撗勬儔閺冪姷鏅?`PlayerPage.onLyricInteract()`閿涘潉_recover/logic-src/PlayerPage.abc.txt:6914-6932`閿涘绱?
   *
   * ```ts
   *   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
   * ```
   * 閹稿倽娴囬悙鐟版躬閸氬本鏋冩禒?`190116-190130`閿涙艾褰ч張?**`TouchType.Down`** 鐠嬪啫鐣犻妴?
   *
   * 閳跨媴绗?娑撱倓閲?娑撳秷顩﹂幖鐐烘晩"閿?
   *   璺?鐎?*閸欘亣鎹ｇ拋鈩冩**閿涘潉startIdle`閿涘绱?*娑撳秴鏁滈崙?*閹貉冨煑閸?閳?鏉╂瑩鍣烽悽?`scheduleChromeAutoHide()`
   *     閼?*娑撳秵妲?* `touchChrome()`閿涘牆鎮楅懓?= `showChrome()` + 鐠х柉顓搁弮璁圭礉閺勵垰褰熸稉鈧弶陇鐭炬稉濠勬畱缂佸嫬鎮庨敍澶堚偓?
   *   璺?閺夆€叉閺?`!chromeHidden`閿涘牆鍑＄紒蹇旀暪鐠ч攱妞?*娑撳秷鎹?*鐠佲剝妞傞敍澶嗗櫩 鏉╂瑩鍣风€电懓绨?`!chromeCollapsed`閵?
   */
  private onLyricInteract(): void {
    if (this.chromeCollapsed) {
      return;
    }
    this.scheduleChromeAutoHide();
  }

  /**
   * 婢瑰啿鐪伴幏锕€鍩岀化鑽ょ埠鏉╂柨娲栭敍鍫ｎ洣濮瑰倸鍙ч梻顓熸尡閺€楣冦€夐敍澶嗗晪 閹绢厽鏁圭挧宄板З閻紮绱濇稉宥堫洣閻╁瓨甯村☉鍫濄亼閵?
   *
   * 閳藉應妲?2026-10-15閿涘牆娲栭柅鈧崥搴ㄥ櫢閸嬫熬绱氶敍?*閸掔姵甯€閸樼喐娼甸柇锝呭綖 `setTimeout(0)`**閵?
   *   瑜版挸鍕鹃惃鍕暈闁插﹤鍟撻惃鍕Ц"娑撳秷顩﹂崷?`@Monitor` 閸ョ偠鐨熼柌宀€娲块幒?`animateTo`閿涘本婀侀崣顖濆厴娑撳秵褰冮崐? 閳ユ柡鈧?
   *   鏉╂瑤閲滈悳鎷岃杽閺勵垳婀＄€圭偛鐡ㄩ崷銊ф畱閿涘奔绲鹃弽鐟版礈娑撳秵妲?閸斻劎鏁炬担婊呮暏閸?閿涘矁鈧本妲哥€规ɑ鏌熼惃?
   *   **閵嗗苯婀?`@Monitor` 娑擃叀袝閸?`animateTo` 閺冩湹绗夐弰鍓с仛閸斻劎鏁鹃妴?*閿?
   *   V2 閻樿埖鈧礁褰夐柌蹇庢叏閺€瑙勬Ц瀵倹顒為弽鍥壈閿涘湧romise 瀵邦喕鎹㈤崝鈽呯礆閿涘矁鈧?`animateTo` 缁斿鍩㈤崚閿嬫煀閼村繗濡悙鐟板枀鐎规岸顩荤敮褝绱?
   *   閸?`@Monitor` 閸ョ偠鐨熼柌宀兯夐梻纾嬬箷濞屸€崇磻婵绱濈悮顐ゆ磧閸氼剛娈戦悩鑸碘偓浣告皑瀹歌尙绮￠崷銊︾垼閼村繘妲﹂崚妤呭櫡 閳?妫ｆ牕鎶?閹绘帒鈧棿绗夌€靛箍鈧?
   *   鐎规ɑ鏌熼敍鍧刟rkts-new-applysync-flushupdates-flushuiupdates`閵嗗奔濞囬悽銊ユ簚閺?璺?閸斻劍鏅ラ崷鐑樻珯閵嗗稄绱氱紒娆戞畱閸愭瑦纭?
   *   鐏忚鲸妲搁崷?`animateTo` 閻ㄥ嫰妫撮崠鍛村櫡閻?`UIUtils.applySync` 閸氬本顒為崚閿嬫煀閻╊喗鐖ｉ崐?閳ユ柡鈧?
   *   `closeFullScreenPlayback()` 闁插苯鍑＄紒蹇斿瘻鏉╂瑤閲滈崘娆愮《閺€閫涚啊閿涘本澧嶆禒銉ㄧ箹闁插苯褰叉禒銉ф纯閹恒儴鐨熼悽銊ｂ偓?
   */
  @Monitor('expandState.collapseVersion')
  onCollapseRequested(): void {
    // 閳藉應妲勯埥鍛 2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MainPage.closeWithAnimation()` 閻ㄥ嫰娼幍瀣◢閸掑棙鏁敍澶涚窗
    //   鏉╂瑦娼?Monitor 閺?*閸烆垯绔?*閻?闂堢偞澧滈崝鍨彠闂?閸忋儱褰涢敍鍧刧uardPlayerBack()` / 婢瑰啿鐪?`onBackPress()`
    //   闁€熻泲 `expandState.requestCollapse()` 閳?`collapseVersion++`閿涘鈧?
    //   娑撳濯洪柇锝嗘蒋鐠?*娑撳秶绮℃潻鍥箹闁?*閿涘牆鐣犻惄瀛樺复鐠?`closeFullScreenPlayback()`閿涘鈧?
    //   閳?閹碘偓娴犮儴绻栭柌灞绢劀婵傝棄顕惔鏃€妫ら悾宀€娈?`pullMode === false` 闁絼绔撮弨顖ょ窗**閹峰秴鎻╅悡褏缂夐崶鎾呯礉娑撳秴濮╁ú濠氥€夐棃?*閵?
    this.closeWithAnimation();
  }
  /** Fallback page background tint when art or color pick fails. */
  private static readonly defaultImageBgColor: string = 'rgba(32, 32, 32, 1)';

  /** 閼冲本娅欑純鎴炵壐濠ф劘绻曞▽鈥冲煂閹靛妞傞惃?*閺堝鏅柌宥呭絿**濞嗏剝鏆熼敍鍫ｎ潌 {@link scheduleBackgroundRetry}閿涘鈧?*/
  private static readonly BG_RETRY_MAX: number = 4;
  /** 娑撱倖顐奸柌宥呭絿娑斿妫块惃鍕？闂呮棑绱檓s閿涘鈧?*/
  private static readonly BG_RETRY_MS: number = 400;

  /**
   * 閼冲本娅欑純鎴炵壐濠ф劘绻曞▽鈥冲煂閹?閳?闂呮柧绔存导姘姽閸愬秴褰囨稉鈧▎鈽呯礄**閺堝鏅?*閿涘鈧?
   *
   * 娑撹桨绮堟稊鍫ユ付鐟曚礁鐣犻敍鍫㈡暏閹村嘲鐤勫ù瀣剁礆閿涙碍婀幘顓熸杹閻樿埖鈧胶鍋ｉ崙缁樺ⅵ瀵偓閹绢厽鏂侀崳銊︽閼冲本娅欓弰顖炵拨閻?閳ユ柡鈧?
   * 閸ョ姳璐熼崷銊у殠濮濆本娲搁惃鍕埂濮濓綀鍎楅弲顖涙Ц**缂冩垶鐗搁崶?*閿涘矁鈧苯鐣犵憰浣虹搼 `song.cover` 閸掔増澧滈幍宥埿掑妤€鍤弶銉幢
   * 閹绢厽鏂侀悩鑸碘偓浣风窗妞ょ儤澧滈幎?metadata 閹峰缍堥敍灞惧娴?閻愰€涚娑撳鎸遍弨鎯ф皑濮濓絽鐖?閵?
   * 閼冲本娅欓崣顏囶嚉鐠?鐏忎線娼伴張澶嬬梾閺堝鍩岄幍?閺堝鍙?閳?鏉╂瑩鍣风紒娆忕暊娑撯偓娑?*閺€鑸垫殐**閻ㄥ嫭婧€娴兼哎鈧?
   * @param jobSeq 閸欐垼鎹ｉ柇锝嗩偧閸欐牞澹婇惃鍕碍閸欏嚖绱欓悽銊ョ暊閸欘垯浜掓稉銏犵磾鏉╁洦婀￠惃鍕鏉烆噯绱?
   * @param attempt 瀹告煡鍣哥拠鏇燁偧閺?
   */
  private scheduleBackgroundRetry(jobSeq: number, attempt: number): void {
    if (!Number.isFinite(attempt) || attempt >= PlaybackPage.BG_RETRY_MAX) {
      Logger.info(PlaybackPage.logTag,
        `RzdBgRetry give up attempt=${attempt} meshVer=${this.meshSrcVersion}`);
      return;
    }
    setTimeout((): void => {
      // 娑撳浜鹃梻顭掔窗妞ょ敻娼版潻妯烘躬閵嗕浇绻栨稉鈧潪顔界梾鐞氼偅鏌婇惃鍕鏉烆噣銆婇幒澶堚偓渚€銆夐棃銏ｇ箷閻绶辩憴?
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
   * 閸欐牞澹婄€瑰本鍨氶崥搴㈠Ω閺備即顤侀懝鑼捍鏉╂稒绁﹂崗澶屾絻閼规彃娅掗妴?
   *
   * 閻?`setEffectParams`閿涘牐鈧奔绗夐弰顖炲櫢瀵?`visualEffect`閿涘绱伴幑銏＄摃閸欘亝娲块弬?uniform閿?
   * 娑撳秳绱伴柌宥呮儙閻偓閼规彃娅掗妴浣风瘍娑撳秳绱扮拋鈺傜ウ閸?鐠?閸ョ偠鎹ｉ悙骞库偓?
   */
  @Monitor('coverTint.version')
  onCoverTintVersionChange(): void {
    this.applyFlowLightColors();
  }

  /**
   * 閳藉應妲?2026-10-14 娣囶喓鈧本绁﹂崗澶庡剹閺咁垰绱戦崗宕囩病鐢晲绗夌捄鐔兼鐠佸墽鐤嗛妴宥忕窗
   *
   * 閸忓彉闊╅悩鑸碘偓?`PlaybackFlowLightState` 閺?*閺傛澘鍨卞?*閻ㄥ嫸绱欐妯款吇 false閿涘绱濈拫渚€鍏樺▽鈩冨Ω `MusicStoreService`
   * 闁插本瀵旀稊鍛閻ㄥ嫰鍋呮稉顏勨偓鑲╀捍鏉╂稑骞?閳ユ柡鈧?閸欘亝婀佺拋鍓х枂妞ら潧鍨忓鈧崗铏閹靛秳绱伴崘娆忓彙娴滎偆濮搁幀浣碘偓鍌欑艾閺勵垽绱?*瀵偓閻偓濞翠礁鍘?閳?闁插秴鎯?App 閳?
   * 閹绢厽鏂佹い浣冾嚢閸掓壆娈戞潻妯绘Ц姒涙顓?false**閿涘牐顔曠純顕€銆夊▽陇绻橀崢鏄忕箖鐏忓彉绔撮惄鎾晩閻偓閿涘绱濋悽銊﹀煕閻鍩岄惃鍕皑閺?瀵偓閸忓厖绗夌捄鐔兼鐠佸墽鐤?閵?
   *
   * 閳跨媴绗?2026-10-17閿?*閸掔娀娅庢禍鍡曠閸忓嘲鎮撻崥宥呮娴?*閿涘绱版潻娆撳櫡閸樼喐娼垫潻妯绘箒娑撯偓娑?
   *   `syncFlowLightPreference(reason)` 閺傝纭堕敍灞戒粵閻ㄥ嫭妲?**store 閳?閸忓彉闊╅悩鑸碘偓?*"鏉╂瑤绔撮崥鎴幢
   *   娴ｅ棛婀″锝堢獓閻ㄥ嫭妲?`aboutToAppear` 闁插矂鍋呴崣銉ф纯閹恒儴绁撮崐?
   *   閿涘潉this.flowLightState.enabled = MusicStoreService閳ヮ泹etPlaybackFlowLight()`閿涘绱?
   *   閼?*閸欏秴鎮?*閿涘牆鍙℃禍顐ゅЦ閹?閳?閽€钘夌氨閿涘鏁辨稉瀣桨閻?`onFlowLightEnabledChange()` 鐠愮喕鐭楅妴?
   *   閳?闁絼閲滈弬瑙勭《**闂嗘儼鐨熼悽銊у仯**閵嗕礁褰ч弰?閸氬奔绔存禒鏈电皑閻ㄥ嫪琚辨總妤€鍟撳▔?閿涘牆鐣犳径姘閺夆剝妫╄箛?+ 娑撯偓濞嗏€愁樋娴ｆ瑧娈戦崣鏍閿涘绱?
   *     閻ｆ瑧娼冪亸杈ㄦЦ"閸氬孩娼垫禍鐑樻暭闁挎瑥婀撮弬?閻ㄥ嫬鍙嗛崣?閳?瀹告彃鍨归梽銈忕幢濮濄倕顦╂穱婵堟殌鐠囧瓨妲戦敍灞藉帳瀵版寮电悮顐﹀櫢閺傛澘濮為崶鐐存降閵?
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
   * 閳藉應妲勯埥?2026-10-17閿?*閻撗勬儔閺冪姷鏅?`MorphGuard` 閻?闁板秷澹婄€瑰娼ょ粣妤€褰?** 閳ユ柡鈧?鐟?`morphQuietUntilMs` 閻ㄥ嫭甯圭€电》绱?
   *
   * @returns 閻滄澘婀?*娑撳秷鍏?*娑撳﹨澹婇弮鎯扮箷鐟曚胶鐡戞径姘毌 ms閿? = 閸欘垯浜掔粩瀣祮娑撳﹨澹婇敍澶堚偓?
   *   閳跨媴绗?娑撳秷鍏樻稉濠呭閺冭埖婀伴崙鑺ユ殶娴?*妞ょ儤澧滈幒鎺嶇濞嗭繝鍣哥拠?*閿涘牆绠撶粵澶涚窗`colorRetryQueued` 閸欘亜鍘戠拋闀愮閺夆€虫躬妞嬬儑绱氶敍?
   *   闁插秷鐦梻鎾 = `wait + 32ms`閿涘牊妫ら悾宀勫亝娑?`0x20` 娴ｆ瑩鍣洪敍澶涚礉娑撳孩妫ら悾?`MainPage` 閻ㄥ嫬鍟撳▔鏇⑩偓鎰蒋鐎电懓绨查妴?
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
        // 閳?2026-10-17閿涙岸銆夐棃銏犲嚒闁偓閸﹀搫姘ㄩ崚顐㈠晙娑撳﹨澹?鐞涖儳缍夐弽?閳ユ柡鈧?
        //   閺堫剟銆夐惃鍕絿閼规煡鎽肩捄顖氭躬闁偓閸︾儤妞傛导姘瘜閸斻劑鍣撮弨鍙ョ秴閸ユ拝绱欑憴?`onDisappear` 闁插矂鍋呮稉銈呭綖 `releasePixelMapQuiet`閿涘绱?
        //   閼汇儴绻栭弶锟犲櫢鐠囨洝绻曢崢?`commitMeshSource`閿涘矂鍋呯亸杈ㄦЦ閹峰じ绔村?*瀹歌尙绮￠柌濠冩杹鏉╁洨娈?*娴ｅ秴娴橀崢缁樺床濠ф劑鈧?
        if (!this.isAlive) {
          return;
        }
        // 娑撳孩妫ら悾宀勫亝娑擃亪鍣哥拠?浣?娑撯偓閼疯揪绱伴崗鍫熸杹瀵偓楠炲倻鐡戦弽鍥唶閿涘苯鍟€閹跺﹣绗傞懝鏌ュ櫢鐠烘垳绔撮柆?
        // 閿涘牊妫ら悾宀冪殶閻ㄥ嫭妲?`syncReportChrome()`閿涙稒婀版禒鎾愁嚠鎼存梻娈戠亸杈ㄦЦ鏉╂瑤琚辨稉顏冪瑐閼硅尙鍋ｉ敍澶堚偓?
        this.applyFlowLightColors();
        this.republishMeshSourceIfAny();
      }, wait + 32);
    }
    Logger.info(PlaybackPage.logTag,
      `RzdFlowLight color apply deferred ${wait.toFixed(0)}ms (morph quiet window)`);
    return wait;
  }

  /** 閹?{@link coverTint} 闁插瞼娈戞０婊嗗閹恒劎绮伴惈鈧懝鎻掓珤閿涘牆鎮撻悧鍫熸拱閸欏嘲褰ч幒銊ょ濞嗏槄绱氶妴?*/
  private applyFlowLightColors(): void {
    if (this.coverTint.version === this.appliedTintVersion) {
      return;
    }
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鍙湁"褰撳墠杩欎竴棣栫畻鍑烘柊棰滆壊"鎵嶇畻 ready**锛?
    //   `coverTint` 鏄法椤甸潰鍏变韩鐨勶細鎸傝浇閭ｄ竴鍒诲畠鐨?`version` 宸茬粡鏄?*涓婁竴棣?*鐣欎笅鐨勫€笺€?
    //   鈬?`aboutToAppear` 閲屾妸 `appliedTintVersion` 鍒濆鍖栦负褰撳墠杩欎釜 version锛? 瑙嗕负"宸叉秷鍖?锛夛紝
    //     浜庢槸杩欓噷鍙湁**version 鍙堣鎺ㄩ珮**锛? `extractFlowLightColors` 涓哄綋鍓嶆瓕鍐欎簡鏂拌壊锛夋墠璧板埌涓嬮潰銆?
    this.tintReady = true;
    // 閳?瑜般垹褰夌€瑰娼ょ粣妤€褰涢崘鍛瑝娑撳﹨澹婇敍鍫ｎ潌 `colorApplyWaitOrRetry`閿涘绱扮粵澶岀崶閸欙綀绻冮崢璇茬暊娴兼俺鍤滃閬嶅櫢鐠囨洑绔村▎掳鈧?
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
   * 閹绢厽鏂佹い鍨ウ閸忓鍎楅弲顖氱湴閿涘湚DS `UV_BACKGROUND_FLOW_LIGHT` 閻偓閼规彃娅掗敍澶堚偓?
   *
   * 閸欏倽鈧啩绗傚〒?PR #1 閸︺劑顩绘い鐢垫畱閻劍纭堕敍灞肩稻妫版粏澹婃稉宥嗘Ц閸愭瑦顒撮惃鍕剁窗`colorSource` /
   * `colorTarget` 閺夈儴鍤滆ぐ鎾冲鐏忎線娼伴崝銊︹偓浣稿絿閼硅绱欑憴?{@link publishFlowLightColors}閿涘绱?
   * 濮ｅ繑顐奸幑銏＄摃闁垝绱伴柌宥嗘煀缁犳ぞ绔村▎掳鈧?
   *
   * 娴ｆ粈璐?`Stack` 閻?*妫ｆ牔閲滅€涙劘濡悙?*缂佹ê鍩楅敍姘躬妞ょ敻娼版惔鏇″娑斿绗傞妴浣哥殱闂?濮濆矁鐦濇稊瀣╃瑓閵?
   * `HitTestMode.Transparent` 閺勵垰绻€妞よ崵娈?閳ユ柡鈧?閺佹潙鐪伴弰顖氬弿鐏炲繒娈戦敍宀勭帛鐠併倕鎳℃稉顓犳畱鐠囨繀绱伴幎?
   * 閹绢厽鏂佹い鍨閺堝瀵滈柦顔炬畱閻愮懓鍤崗銊ユ倖閹哄鈧?
   */
  /**
   * 閺堫剚婧€閺勵垰鎯侀崗宄邦槵 HDS 鐟欏棙鏅ラ懗钘夊娴ｅ秲鈧?
   *
   * 閳跨媴绗?濞翠礁鍘滈弰?HDS `hdsEffect` 閻?shader 鐟欏棙鏅ラ敍?*鐠佹儳顦▽鈩冩箒鏉╂瑤閲滈懗钘夊娴ｅ秵妞傜€瑰啩绱伴棃娆撶帛娑撳秶鏁?*
   *    閿涘牅绗夐幎銉╂晩閵嗕椒绗夐幎娑樼磽鐢潻绱氶敍宀冦€冮悳鏉挎皑閺勵垳鏁ら幋鐤嚛閻?瀵偓娴滃棗绱戦崗鍏呯稻娴犫偓娑斿牓鍏樺▽鈥冲絺閻?閵?
   *    閹碘偓娴犮儴绻栭柌灞炬▔瀵繐鍨介弬?+ 鐠佺増妫╄箛妤嬬礉楠炶泛婀稉宥嗘暜閹镐焦妞傞柅鈧崶鐐扮鐏炲倿娼ら幀浣圭瑤閸欐﹫绱欓懛鍐茬毌閻绶辩憴渚€顤侀懝鎻掑綁閸栨牭绱氶妴?
   */
  /** 濞翠礁鍘滈惃?HDS 閼宠棄濮忔担宥忕窗缂傚搫銇戦弮?shader 鐟欏棙鏅ユ导姘舵饯姒涙ü绗夐悽浼欑礄鐟?{@link hdsEffectCapable}閿涘鈧?*/
  private static readonly HDS_CORE_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';

  // 閳藉應妲?2026-10-15閿涘牏顑囨稉澶婂磩娑旀繆鐤?/ Round 20閿涘绱癭COVER_BLUR` 娑?`imageBlurRadius()` **瀹告彃鍨归梽?*
  //   閿涘牊鎸遍弨楣冦€夐懗灞炬珯閺€瑙勫灇缂冩垶鐗搁懗灞炬珯閸氬函绱濇０鍕閺屾挻膩缁﹪鍋呴弶锛勫殠閸︺劎绱拠鎴濇禈闁插苯鍑￠弮鐘辨崲娴ｆ洝鐨熼悽銊ㄢ偓鍜冪礆閵?
  //   閸掔娀娅庢笟婵囧祦娑撳簼楠囬悧鈺冾儊閸欑柉鍤滃Λ鈧敍鍧dules.abc GONE閿涘顫?RzdMusic鐠佹澘绻?md 鎼?6.15閵?

  private hdsEffectCapable(): boolean {
    try {
      return canIUse(PlaybackPage.HDS_CORE_SYSCAP);
    } catch (_err) {
      return false;
    }
  }

  @Builder
  private FlowLightBackground() {    if (this.hdsEffectCapable()) {
      Stack()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .hitTestBehavior(HitTestMode.Transparent)
        .opacity(FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity())
        // 鐎规ɑ鏌熺粈杞扮伐闁插本瀵?shader 鐟欏棙鏅ラ惃鍕啇閸ｃ劑鍏樼敮锕€绨抽懝璇х礄`backgroundColor('#383838')`閿涘绱?
        // 鏉╂瑩鍣风紒娆庣鐏?*瀵板牊璐伴惃鍕鎼?*閿涘本妫︾紒娆掝潒閺佸牅绔存稉顏勫讲濞撳弶鐓嬮惃鍕俺閿涘苯寮垫稉宥変紕娴ｅ繐鐨濋棃顫偓?
        .backgroundColor('#33000000')
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
            animation: {
              duration: FLOW_LIGHT_DURATION_MS,
              iterations: -1,
              autoPlay: true
            },
            // 閸掓繂鈧偐鏁ら崗婊冪俺閼硅绱遍惇鐔割劀閻ㄥ嫰顤侀懝鑼暠 applyFlowLightColors 閸︺劌褰囬懝鎻掔暚閹存劕鎮楁稉瀣絺閿?
            // 鏉╂瑦鐗遍崡鍏呭▏閸欐牞澹婂鍫熷弮娑旂喕鍏樼粩瀣煝閻鍩屽ù浣稿帨閸︺劌濮╅敍鍫ｂ偓灞肩瑝閺勵垶绮︾仦蹇曠搼閸楀﹤銇夐敍澶堚偓?
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
          // autoPlay 瀹告彃绱戦敍灞藉晙閺勬儳绱?play 娑撯偓濞喡ゎ唨閻樿埖鈧胶鈥樼€规熬绱欓幑銏＄摃闁插秴缂撶拠銉ョ湴閺冩湹绗夋导姘粻閸︺劍娈忛崑婊勨偓渚婄礆
          try {
            this.flowLightController.play();
          } catch (error) {
            const err = error as BusinessError;
            Logger.warn('RzdFlowLight', `play failed code=${err?.code} message=${err?.message}`);
          }
        })
    } else {
      // 閼宠棄濮忔担宥囧繁婢舵唻绱伴柅鈧崶鐐烘饯閹焦绗庨崣姗堢礄妫版粏澹婃禒宥堢鐏忎線娼扮挧甯礆閿涘奔绻氱拠?瀵偓閸忚櫕澧﹀鈧惇瀣繁鐟欎椒绗㈢憲?
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
            `layer mounted capable=0閿涘牊妫?HDS 鐟欏棙鏅ラ懗钘夊娴ｅ稄绱濋弨鍦暏闂堟瑦鈧焦绗庨崣姗堢礆enabled=${this.flowLightState.enabled} ` +
            `src=${this.coverTint.sourceColor} dst=${this.coverTint.targetColor}`);
        })
    }
  }

  /** 闁辨帞娲伴幓鎰仛濡亜绠欓敍姘剁叾濠ф劘鍓奸張顒冩硶閼存碍婀伴崚鍥ㄥ床閺冭埖妯夌粈鐚寸礉3 缁夋帒鎮楅懛顏勫З闂呮劘妫岄妴?*/
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
   * 濞搭喖鐪扮€规矮缍呴崣锝呯窞閿涘牊鏁奸崜宥夊亝閻楀牊鏁為柌濠冩Ц**闁挎瑧娈?*閿?026-10-15 閹稿婀伴張?SDK 閺囧瓨顒滈敍澶堚偓?
   *
   * 閴?閺冄嗩嚛濞夋洩绱伴妴瀹峱osition({x, y})` 閺勵垰婀?*閼奉亞鍔ф担宥囩枂**娑撳﹤鍟€閸旂姴浜哥粔浼欑礉閹碘偓娴犮儱鐪虫稉顓犳畱 Stack 闁插矁顩﹂崗鍫濆櫤
   *    `(缁愭褰涚亸鍝勵嚟 閳?閼奉亜绻佺亸鍝勵嚟) / 2`閵嗗秲鈧?*娑撳秵鍨氱粩瀣ㄢ偓?*
   *
   * 閴?閺堫剚婧€ SDK 閸樼喐鏋冮敍鍧剆dk\default\openharmony\ets\component\common.d.ts:25284`閿?
   *    `position(value: Position | Edges | LocalizedEdges)`閿涘绱?
   *    閵?*Sets the absolute position of the component relative to the position of the
   *    parent component.**閵嗗秮鈧柡鈧?鐏忚鲸妲?*閻╃顕悥鍓佺矋娴犺泛涔忔稉濠咁潡閻ㄥ嫮绮风€电懓鐣炬担?*閿涘奔绗岄懛顏嗗姧娴ｅ秶鐤?`alignContent` 閺冪姴鍙ч妴?
   *
   * 閳?缂佹捁顔戦敍鍫熸拱閺傚洣娆㈤幍鈧張澶嬭癁鐏炲倿鍏橀幐澶庣箹閺夆€冲晸閿涘绱?
   *    閸欘亣顩﹀ù顔肩湴閹碘偓閸︺劌顔愰崳?*瀹革缚绗傜憴鎺戞皑閺勵垳鐛ラ崣锝呭斧閻?*閿涘畭PlayerExpandState` 娴溿倕鍤惃?*缁愭褰涢崸鎰垼**
   *    鐏忚精鍏橀惄瀛樺复瑜?`.position({x, y})` 閻㈩煉绱?*閸忋劑鎽奸梿鑸靛床缁?*閵?
   *    `MorphCoverBridge`閿涘牆鎮撴稉鈧仦鍌︾礆閹稿鐛ラ崣锝呮綏閺嶅洩鎯ゆ担宥呭嚒鐞氼偆婀￠張娲崣鐠囦緤绱盽LyricFloatLayer` 閸氬苯鐪伴崥灞藉經瀵板嫨鈧?
   *
   * 閻滄壆濮搁敍娆? 閻ㄥ嫭鐡曠拠宥夈€夊ù顔肩湴閻㈠彉绗呴棃銏㈡畱 {@link LyricFloatLayer} 閹垫寧濯撮敍?
   * 鏉╂瑤琚辨稉?`morphWindow*Vp()` 閺勵垱娲块弮鈺呭亝閻楀牞绱欏鎻掑灩閿涘ˇLyricCoverOverlay` 閻ㄥ嫰浠愰悾娆忓絿閸婄厧娅掗敍灞肩箽閻ｆ瑤绗夐崝銊ｂ偓?
   */
  /** @returns 濞搭喖鐪伴崣鍌濃偓鍐暏閻ㄥ嫮鐛ラ崣锝咁啍鎼达讣绱檝p閿涘鈧?*/
  private morphWindowWidthVp(): number {
    return this.expandState.windowWidthVp;
  }

  /** @returns 濞搭喖鐪伴崣鍌濃偓鍐暏閻ㄥ嫮鐛ラ崣锝夌彯鎼达讣绱檝p閿涘鈧?*/
  private morphWindowHeightVp(): number {
    return this.expandState.windowHeightVp;
  }

  /** 閺€鎯版崳鏉╂稑瀹?0..100閿?*0 = 鐎瑰本鏆ｉ幘顓熸杹妞ょ绱欓棃娆愵剾閹緤绱?*閿?00 = 閺€鎯版崳閹存劘鍒涙惔鏇犳畱娑撯偓閺壜扳偓?*/
  @Local collapseProgress: number = 0;

  /**
   * 閸忓彉闊╅惃鍕潔瀵偓/瑜般垹褰夐崙鐘辩秿閿涘牅绗屾竟鍐茬湴閵嗕浇绯犳担鐘虫蒋閵嗕礁銇囩亸渚€娼伴崗杈╂暏閸氬奔绔存稉顏勭杽娓氬绱氶妴?
   *
   * 闁插矂娼伴惃?`morph` 鐎圭懓娅掔€涙顔岄敍鍧癱ale / translate / clipHeight / radius閿涘姘ㄩ弰?
   * 閺冪姷鏅?`ExpandAnimation` 闁絽顨?閺佹挳銆夌紓鈺傛杹 + 缁旀牜娲跨憗浣稿缁愭褰?閻ㄥ嫮濮搁幀渚婄幢
   * 婢瑰啿鐪伴崷銊ㄧ閹靛妞傞弨鐟扮暊閿涘本婀版い鐢垫纯閹恒儴顕伴弶銉﹁閺屾挶鈧?
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * 鐠虹喐澧滄稉濠冨閺冭埖濡搁崗鍙橀煩鏉╂稑瀹抽梹婊冨剼鏉╂稒娼甸妴?
   *
   * 婢瑰啿鐪伴敍鍧oducts閿涘婀潻铚傜稑閺夆€茬瑐閸嬫矮绗傞幏澶嬪閸旇￥鈧焦鏁?`expandState.morph`閿?
   * 鏉╂瑩鍣烽崣顏囩鐠愶絽婀?*闂堢偛顔愰崳銊ヨ埌閸?*閻ㄥ嫯鈧浇鐭惧鍕剁礄閻愮懓鍤幍鎾崇磻閿涘绗呮穱婵囧瘮 `collapseProgress` 閸氬本顒為妴?
   */
  @Monitor('expandState.transitionProgress')
  onTransitionProgressChanged(): void {
    if (this.expandState.morphContainerActive()) {
      // 鐎圭懓娅掕ぐ銏犲綁闁絾娼捄顖欑瑝閻?collapseProgress閿涘牓鐝惔锔戒航 100%閿涘矁顫?sheetHeightPercent閿?
      return;
    }
    this.collapseProgress = this.expandState.transitionProgress;
  }

  /**
   * 娑撳濯洪弨鎯版崳閹靛濞嶉敍鍫㈢彨閻╁瓨鏌熼崥鎴礆閵?
   *
   * 閳跨媴绗?`distance` 閺?*閺冪姷鏅€靛綊缍堥崐?*閿涘牐顫?{@link PlaybackPage.DISMISS_PAN_DISTANCE_VP} 閻ㄥ嫭鏁為柌濠忕礆閿?
   *    娑撳秴鍟撶€瑰啯妞傚鍡樼仸姒涙顓?**5vp**閿涘矂鍋呮稉鈧锝勭窗鐞?1~2vp 閻ㄥ嫭濮堥崝銊ㄧ槕閸掝偅鍨?瀵偓婵绗呴幏?閵?
   */
  private panOption: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Vertical,
    distance: PlaybackPage.DISMISS_PAN_DISTANCE_VP
  });

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?鐏忎線娼伴妴宀€鐢绘鐐插煂濮濆矁鐦濇い鐐光偓宥忕礄鐎佃鐖?閺冪姷鏅棅鍏呯 CoverMorph 閸欏瞼顏悙鐧哥礆閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?

  /**
   * 鐏忎線娼扮紒顓㈩棧鏉╂稑瀹抽敍? = 閸嬫粌婀仦鏇炵磻妞ゅ吀缍呯純顕嗙礉1 = 瀹告彃鍩屽宀冪槤妞ゅ吀缍呯純顔衡偓?
   *
   * 闂堟瑦顒涢崷銊︽尡閺€楣冦€夐弮鑸垫Ц 0閿?*娑撳秶鏁炬鐐额攽鐏忎線娼?*閿涘奔绗屽▽鈩冩箒鏉╂瑥顨滈崝銊ф暰閺冨爼鈧劕鍎氱槐鐘辩閼疯揪绱氶敍?
   * 閸欘亝婀侀崚鍥у煂濮濆矁鐦濇い?閸掑洤娲栫亸渚€娼版い鐢垫畱闁?360ms 闁插本澧?0閳? 鏉╁洦娴妴?
   */
  @Local lyricMorphT: number = 0;
  /** 妞嬬偠顢戠亸渚€娼伴弰顖氭儊閸欘垵顫嗛敍鍫ユ饯濮濄垺鈧椒绔村?false閿涘奔绻氱拠浣风瑝瑜板崬鎼烽棃娆愨偓浣哥鐏炩偓閿涘鈧?*/
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

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?閹貉冨煑閸栨椽娼ゅ銏ｅ殰閸斻劍鏁圭挧鍑ょ礄鐎佃鐖?閺冪姷鏅棅鍏呯 BarCollapse閿涘鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜

  /** 閹貉冨煑閸栫儤妲搁崥锕€鍑￠懛顏勫З閺€鎯版崳閿涘牊鏁圭挧宄版倵閻愰€涙崲閹板繐顦╅崬銈呭毉閿涘鈧?*/
  @Local chromeCollapsed: boolean = false;
  /**
   * 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`PlayerPage.hideChrome()` 閻?闂堛垺婢樺鈧惈鈧亸鍙樼瑝閺€?鐎瑰牆宕奸敍澶涚窗
   * **閹绢厽鏂侀梼鐔峰灙 / 閸忔湹绮悧鍫熸拱**鏉╂瑤琚辨稉顏勮剨鐏炲倹妲搁崥锕€绱戦惈鈧敍鍫㈡暠 `ControlAreaComponent.onAuxSheetOpenChange` 娑撳﹥濮ら敍澶堚偓?
   *
   * 閺冪姷鏅柇锝勭閺夆€崇暓閸楊偅妲?10 娑?flag 閻ㄥ嫮鐓捄顖涘灗闁炬拝绱檂abc.txt:4124-4225`閿涘绱?
   * 閺堫兛绮ㄩ懣婊冨礋 sheet 闁絼绔撮弮蹇ョ礄`settingsOpen`/`qualityOpen`/閳ワ讣绱氶拃钘夋躬**娑撯偓娑?* `bindSheet` 闁插矉绱?
   * 瀹歌尙鏁?`playMenuOpen` 娴狅綀銆冮敍娑樺⒖娑撳绻栨稉銈勯嚋閻㈣鲸婀扮€涙顔屾禒锝堛€?閳?娑撱倛鈧懎鎮庣挧閿嬫降 = "娴犺缍嶉棃銏℃緲瀵偓閻偓"閵?
   * 閳跨媴绗?娑?`playMenuOpen` **韫囧懘銆忔稉鈧挧?*楠炴儼绻橀弨鎯版崳闂傤煉绱欓崥灞肩閺夆€崇暓閸楊偆娈戞稉銈勯嚋閸掑棝鍣洪敍灞肩瑝鐠佺褰ч崚銈勭娑擃亷绱氶妴?
   */
  @Local auxSheetOpen: boolean = false;
  /**
   * 閳?2026-10-17閿涙瓪MorphGuard` 鐎瑰娼ょ粣妤€褰涢惃?闁插秷鐦崣顏呭笓娑撯偓閺?楠炲倻鐡戦弽鍥唶
   * 閿涘牆顕弽鍥ㄦ￥閻?`MainPage.colorModeRetryQueued`閿涘畭wujie.pa:145966/145979`閿涙盯鍣哥拠?浣?闁插苯顦叉担宥忕礆閵?
   */
  private colorRetryQueued: boolean = false;
  /**
   * 閳?2026-10-17閿涙艾鐣ㄩ棃娆戠崶閸欙絾婀￠梻?*瀵板懓藟**閻ㄥ嫮缍夐弽鑹板剹閺咁垱绨敍鍫㈢崶閸欙綀绻冮崢璇叉倵閻?
   * {@link republishMeshSourceIfAny} 閹绘劒姘﹂敍澶堚偓鍌涘閺堝娼堥崷銊︽拱妞ょ绱濋弴鎸庡床閺冨爼鍣撮弨鐐＋閻ㄥ嫨鈧?
   */
  private pendingMeshPm: image.PixelMap | undefined = undefined;
  /** 閼奉亜濮╅弨鎯版崳鐠佲剝妞傞崳銊ｂ偓?*/
  private chromeTimerId: number = -1;
  /** 閺堚偓閸氬簼绔村▎鈩冨付閸掕泛灏禍銈勭鞍閺冨爼妫块敍鍧閿涘鈧?*/
  private chromeTouchedAtMs: number = 0;

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?鐏炴洖绱戦弮鍓佹畱闁劕鍘撶槐鐘宠窗閸忋儻绱欓懛顏呭瘮鏉╂稑瀹抽敍灞肩瑝婢跺秶鏁ら崗鍙橀煩閻╅晲缍呴敍澶嗘櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?

  /**
   * 鐏炴洖绱戠悰銉╂？閺勵垰鎯侀崷銊ㄧ獓閵?
   *
   * 閳跨媴绗?鏉╂瑦妲?*閺堫剙婀?*閺嶅洤绻旈敍灞肩瑬閸欘亞鏁ら弶銉ュ枀鐎?鐟曚椒绗夌憰浣烘暏閸斻劎鏁鹃崐?閿涙稑褰х憰浣哥暊閺?false閿?
   * 閹碘偓閺堝璐伴崗銉ュ絿閸婇棿绔村瀣箲閸ョ偤娼ゅ銏♀偓渚婄礄1 / 0閿涘鈧倽绻栭弽铚傜瑝鐎涙ê婀?閺嶅洤绻斿▓瀣殌鐎佃壈鍤ч崘鍛啇闁繑妲?閻ㄥ嫬褰查懗?
   * 閳ユ柡鈧?闁絾妲搁弴鍓х病閻ㄥ嫮婀＄€?bug閿涘牏鏁ら幋鍑ょ窗鐏忎線娼板ǎ鈩冭窗閸戣櫣骞囬崥搴㈡殻妞ょ數鈹栭惂鏂ょ礆閵?
   //  瑜般垹褰夋潻娑樺娑撳秴褰熺€涙ê褰夐柌蹇ョ窗閻╁瓨甯存径宥囨暏 `collapseProgress`閿涘牐顫?`morphProgress()`閿涘绱?
   //  闁灝鍘?妤傛ê瀹抽崚棰佺啊娴ｅ棛缂夐弨鐐梾閸?閻ㄥ嫪琚辨總妤勵吀閺冨爼鏁婃担宥冣偓?
   */
  @Local expandIntroRunning: boolean = false;

  /** Seeds cover Resource from the current queue item. */
  aboutToAppear(): void {
    // 閸忓牐顔囨稉鈧弶?鏉╂瑤绔存い鍨瘯鏉炶姤妞傜挧鎵畱閺勵垰鎽㈤弶陇鐭?閿涙氨鍋ｉ崙缁樺ⅵ瀵偓 vs 娑撳﹥濯洪幍鎾崇磻閻ㄥ嫬灏崚顐㈡皑閸?`pullDragging`閿?
    // 閹烘帗鐓?閻愮懓鍤幍鎾崇磻鏉╂ɑ妲搁弮褍濮╅悽?閺冩儼绻栨稉鈧悰灞炬付閸忔娊鏁敍鍧刪dc shell hilog | grep "expand intro"`閿涘鈧?
    Logger.info(PlaybackPage.logTag,
      `aboutToAppear: pullDragging=${this.expandState.pullDragging} ` +
      `usable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
    // 閳藉應妲勯埥?2026-10-16閿?*娣囶喚鏁ら幋宄扮杽濞村鈧本鐡曠拠宥夈€夌亸渚€娼板▽鈥冲綁鐏忓繈鈧礁褰旈崷銊︾摃鐠囧秳绗傞棃顫偓?*閿涘绱?
    //   妞ょ敻娼?*閹稿倽娴囬柇锝勭閸?*鐏忚鲸濡?鐏忎線娼板ù顔肩湴妞嬬偠顢戞潻娑樺"鐎靛綊缍堥崚鏉跨秼閸撳秹銆?閳ユ柡鈧?鏉╂瑦妲搁張顒勩€夌粭顑跨濞嗏剝婀侀張杞扮窗閸嬫俺绻栨禒鏈电皑閿?
    //   閼板奔绗栫€瑰啩绗?閺勵垰鎯侀崣鎴犳晸鏉╁洣绔村▎鈩冪拨閸?閺冪姴鍙ч敍鍫㈡倞閻㈣精顫?`syncLyricMorphToPage()` 閻ㄥ嫰鏆卞▔銊╁櫞閿涘鈧?
    //   閻劍鍩涢柇锝呯炊閹搭亜娴樺锝嗘Ц鏉╂瑤閲滆ぐ銏㈠Ц閿?*swiper 閸︺劍鐡曠拠宥夈€夐妴涔yricMorphT` 鏉╂ɑ妲?0** 閳?婢堆冪殱闂?+ 濮濆矁鐦濋崥灞炬閸︺劌婧€閵?
    //   閳跨媴绗?閺€鎯ф躬 `aboutToAppear`閿涘澃truct 缁狙佲偓浣瑰瘯鏉炶棄宓嗛張澶涚礆閼板奔绗夐崣顏勬躬閸愬懎顔愮仦?`.onAppear`閿涘牐濡悙鍦獓閵?
    //      閸掑棙鏁柌宥呯紦閹靛秷绐囬敍澶嗏偓鏂衡偓?娑撱倕顦╅柈鍊燁洣閿涘苯娲滄稉杞拌⒈閼板懏妞傞張杞扮瑝閸氬矉绱欓崜宥堚偓鍛－娴滃酣顩荤敮褍绔风仦鈧敍灞芥倵閼板懏娅勬禍搴㈠瘯鏉炴枻绱氶妴?
    this.syncLyricMorphToPage('boot');
    // 閳?**閼奉亝鍓?*閿涙俺顫?`onDisAppear` 闁插矂鍋呭▓浣冾嚛閺?閳ユ柡鈧?鏉╂瑤琚辨稉顏呯垼鐠侀绔撮弮锔界暙閻ｆ瑱绱濋悙鐟板毊閹垫挸绱戠亸杈ㄦ鏉?
    //   鐠哄疇绻冭ぐ銏犲綁閸掓繂顫愰崠鏍电礉閸欘亝鎸遍懓浣稿З閻㈡眹鈧倽绻栭柌灞藉晙閸忔粈绔寸仦鍌︾窗閸欘亝婀?绾喖鐤勯崷銊ф箙閹靛濞?閿涘潐rive=FINGER閿?
    //   閹靛秷顓绘稉鐑樺閹稿洤婀す鍗炲З閿涙稖鈧奔绗栭崡鍏呭▏婵″倹顒濋敍灞藉涧鐟曚礁鍑＄紒蹇氱箖娴?2 缁夋帟绻曞▽鈩冩暪鐏忔拝绱濈亸鍙樼鐎规碍妲稿▓瀣殌
    //   閿涘牅绔村▎陇绐￠幍瀣╃瑝閸欘垵鍏橀幐浣虹敾闁絼绠炴稊鍜冪礆閿涘瞼娲块幒銉︾閹哄鈧?
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
    // 閳藉應妲勯埥?2026-10-17閿涘牏鏁ら幋鍑ょ窗**閵嗗本鍨滄禒顒傛畱鏉烆垯娆㈤柌宀勬桨閺堝閲滈懛顏勭暰娑斿鐨濋棃銏犳妇鐟欐帊绡冮崚鐘辩啊閸氀佲偓?*閿?
    //   閸樼喐娼垫潻娆庣閸欍儲妲?`= MusicStoreService.getInstance().getCoverCornerRadius()`
    //   閳ユ柡鈧?鐠佸墽鐤嗘い鐢稿亝娑擃亗鈧苯鐨濋棃銏犳妇鐟欐帪绱欓惄纾嬵潡/鐏?娑?婢?鐡掑懎銇囬敍澶堚偓宥夆偓姘崇箖鐎瑰啳绻樺〒鍙夌厠閵?
    //   閻滄澘婀崷鍡氼潡閸欘亝婀?*娑撯偓娑擃亝娼靛┃?*閿涙碍妫ら悾?`CoverMorph.radiusPlayer = 8`
    //   閿涘潉PlayerExpandState.COVER_RADIUS_PLAYER_VP`閿涘鍣?鐠佸墽鐤嗛崐闂寸瑝閸愬秴寮稉搴濇崲娴ｆ洘瑕嗛弻鎾扁偓?
    //   閳跨媴绗?鏉╂瑤绔撮崣銉ョ箑妞よ崵鏆€閻偓閿涘牊濡搁崗鍙橀煩閻樿埖鈧礁甯囬崶鐐叉値濞夋洖鈧》绱氶敍姝欳overRadiusState` 闁插苯褰查懗鑺ョ暙閻ｆ瑦妫崐绗衡偓?
    this.coverRadiusState.radius = PlayerExpandState.COVER_RADIUS_PLAYER_VP;
    // 閳?濞翠礁鍘滈懗灞炬珯瀵偓閸忕绱?*韫囧懘銆忛崷銊ㄧ箹闁插奔绮犻幐浣风畽閸栨牕鐡ㄩ崒銊т捍鏉?V2 閻樿埖鈧?*閵?
    //   鐠佸墽鐤嗘い闈涘涧閸︺劊鈧瞼鏁ら幋宄板瀼閹广垹绱戦崗鐐解偓宥嗘閸?`PlaybackFlowLightState`閿涘苯鍠庨崥顖氬З閺冭埖鐥呮禍铏逛捍閸?閳?
    //   閻樿埖鈧線绮拋?false閿涘苯宓嗘担鑳啎缂冾噣鍣烽弰?瀵偓"娑旂喐妗堟潻婊€绗夐悽缁樼ウ閸忓绱欓悽銊﹀煕閸欏秹顩惃?濞翠礁鍘滈懗灞炬珯娑撳秶鏁撻弫?鐏忚鲸妲告潻娆庨嚋閿涘鈧?
    //   娑?`AmllLyricView`閿涘牐鍤滃鍙樼矤 store 閻?fps/鐏炲懍鑵?閸擃垱鐡曠拠宥忕礆娣囨繃瀵旈崥灞肩婵傛浠涘▔鏇樷偓?
    this.flowLightState.enabled = MusicStoreService.getInstance().getPlaybackFlowLight();
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鎶?涓婁竴棣栫暀涓嬬殑娴佸厜鐫€鑹?瑙嗕负宸叉秷鍖?* 鈥斺€?淇€屽睍寮€杩樻槸涓婁竴棣栫殑棰滆壊銆嶏級
    //   `coverTint` 鏄?`AppStorageV2` 鍏变韩鐘舵€侊細鎸傝浇閭ｄ竴鍒诲畠鐨?`version` 宸茬粡鏄?*涓婁竴棣?*鐣欎笅鐨勩€?
    //   鑰屾湰椤?`appliedTintVersion` 鍒濆€兼槸 -1 鈬?`@Monitor('coverTint.version')` 涓€涓婃潵灏卞懡涓?
    //   鈬?`applyFlowLightColors()` 鎶?*涓婁竴棣?*鐨勯鑹蹭笅鍙戠粰鐫€鑹插櫒銆佸苟鎶?`tintReady` 缃湡
    //   鈬?閭ｉ亾"绛夊綋鍓嶈繖棣栫殑棰滆壊"鐨勯棬褰撳満琚粫杩囷紙涓婁竴鐗堝氨璐ュ湪杩欓噷锛夈€?
    //   鈬?鎸傝浇鏃?*鍏堝榻?*锛氭妸褰撳墠 version 璁版垚"宸叉秷鍖?锛宍tintReady` 淇濇寔鍋囷紱
    //     涔嬪悗鍙湁 `extractFlowLightColors()` 涓?*褰撳墠杩欎竴棣?*鍐欏嚭鏂拌壊锛坴ersion 鍐嶈鎺ㄩ珮锛?
    //     鎵嶄細鐪熸涓嬪彂骞舵斁琛岄偅涓€灞傘€?
    this.appliedTintVersion = this.coverTint.version;
    this.tintReady = false;
    const song = this.state.getCurrentSongItem();
    this.releaseBackgroundCoverIfPixelMap();
    this.imageLabel = song !== undefined ? song.label : $r('app.media.ic_avatar1');
    this.applyKeepScreenOn(true);
    // 妞ょ敻娼伴幍鎾崇磻閺冭泛顩ч弸婊冨嚒閺堝婀潻鍥ㄦ埂閻ㄥ嫭铆楠炲拑绱濈粩瀣祮鐟欙箑褰傚〒鍛倞鐠佲剝妞傞妴?
    if (this.switchBanner.ts > 0) {
      this.onBannerChange();
    }
    // 閳?鐏炴洖绱戦崝銊ф暰閿涙艾鍘涢崷?`aboutToAppear` 閹跺﹨绻樻惔锔芥杹閸?閺€鎯版崳"閿?*娣囨繆鐦夌粭顑跨鐢呮暰閸戠儤娼电亸杈ㄦЦ鐠愭潙绨抽惃鍕閺?*閵?
    //   婵″倹鐏夐弨鎯у煂 `onAppear` 閸愬秶鐤嗛敍灞肩窗閸忓牊瑕嗛弻鎾冲毉娑撯偓鐢冪暚閺佸瓨鎸遍弨楣冦€夐崘宥嗘暪閸ョ偛骞撻敍宀€婀呴惈鈧亸杈ㄦЦ闂傤亙绔存稉瀣ㄢ偓?
    //
    // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*婢瑰啿鐪板鑼病鐠ц渹绨¤ぐ銏犲綁閺冭绱濇潻娆庣濡楋絼绗夌拋绋垮晙閸?*閵?
    //   閺冪姷鏅惃鍕潔瀵偓**閸欘亝婀佹稉鈧稉顏勫З閻㈣瀵?* 閳ユ柡鈧?婢瑰啿鐪伴惃?`ExpandAnimation.doEnter`閿?50ms閿涘鈹嶉崝銊︽殻妞ょ數娈?
    //   `scale/translate/clipWidth/clipHeight`閿涙稒鎸遍弨楣冦€夐懛顏勭箒**濞屸剝婀?*缁楊兛绨╂總?鐠愭潙绨虫稉鈧弶锟犳毐娑撳﹥娼?閵?
    //   閼?`collapseProgress` 鏉╂瑥顨滈敍鍫濆敶鐎圭懓鐪?`height` 娴犲氦鍒涙惔鏇氱閺夛繝鏆遍崚?100%閿涘妲?*濞查箖鐓堕弮褑鐭?*閿?
    //   娑撱倖娼崥灞炬閸︺劏绐囩亸杈ㄦЦ閻劍鍩涚€圭偞绁撮惃鍕┾偓宀€鍋ｉ崙缁樺ⅵ瀵偓閹绢厽鏂侀崳銊︾梾閺堝濮╅悽?/ 閼冲本娅欐稉宥咁嚠閵嗗稄绱?
    //   妞ょ敻娼扮悮顐ｆ＋鐠侯垱瀵?鐠愭潙绨虫稉鈧弶?鐠ч攱澧滈敍宀冣偓灞借埌閸欐娈戠挧椋庡仯閸戠姳缍嶅鑼病鐞氼偄锛撶仦鍌涘瘻鏉╄渹缍橀弶陇鍏岄崶濠傚竾婵傛垝绨￠妴?
    //   閸掋倖宓侀悽?`morphContainerActive()`閿涘澃tage 閳?ENTERING/LEAVING/LANDING閿涘绱扮€瑰啫婀?
    //   `pullOpenBegin()` 闁插苯姘ㄧ純顔笺偨娴滃棴绱濋懓灞斤紦鐏炲倹妲?*閸?begin 閸?pushPath**閿涘牆顕弽鍥ㄦ￥閻?
    //   `beginMorphEnter` 閸愬懘鍎撮懛顏勭箒 push 閻ㄥ嫰銆庢惔蹇ョ礆閳?`aboutToAppear` 鏉╂瑤绔撮崚鏄忣嚢閸掓壆娈戠亸杈ㄦЦ閻喓娴夐妴?
    const shellOwnsMorph: boolean = this.expandState.morphContainerActive();
    if (shellOwnsMorph) {
      this.collapseProgress = 0;
    } else {
      this.collapseProgress = PlaybackPage.EXPAND_START_PROGRESS;
    }
    this.dismissMorphActive = false;
    // 閳藉應妲?2026-10-15閿涙瓪isClosing` 閺?`onDismissDrag()` / `closeFullScreenPlayback()` 閻?*缁楊兛绔撮柆鎾绘**閿?
    //   鐎瑰啩绔撮弮锔界暙閻ｆ瑦鍨?true閿涘奔绗呴幏澶嬫暪鐠ц渹绗岄崗鎶芥４閹稿鎸崇亸鍗炲蓟閸欏苯銇戦弫鍫礄鐠囷箒顫?`closeFullScreenPlayback()` 闁?
    //   闁絾娼?`morphGenAlive` 閺冣晠鈧偓閸掑棙鏁惃鍕夊蹇旀暈闁插绱氶妴鍌涘瘯鏉炶姤妞?*閺冪姵娼禒?*濞撳懍绔村▎鈽呯窗
    //   閺傜増瀵曟潪鐣屾畱妞ょ敻娼版稉宥呭讲閼?濮濓絽婀弨鎯版崳"閿涘奔鎹㈡担鏇熺暙閻ｆ瑩鍏橀崣顏勫讲閼宠姤娼甸懛顏冪瑐娑撯偓鏉烆喗婀挧鏉跨暚閻ㄥ嫪绱扮拠婵勨偓?
    this.isClosing = false;
    // 濮ｅ繑顐奸幍鎾崇磻闁粙鍣哥純顕€鍣哥拠鏇㈩杺鎼达讣绱欓悡褎濡?`schedulePublishRetry` 閻?12鑴?2ms閿?
    this.morphRetryLeft = 12;
    // 閳?鐎圭懓娅掕ぐ銏犲綁闁絾娼捄顖ょ礄鐎佃鐖ｉ弮鐘垫櫕 ExpandAnimation閿涘绱版稉宥嗘Ц娑撳﹥濯洪幏澶庣箻閺夈儳娈戦敍鍫㈠仯閸?/ 鐠ч攱鎸遍幇蹇撴禈閹垫挸绱戦敍?
    //   鐏?*鐏忓崬婀?*鐠ц渹绔村▎鈥宠埌閸?閳ユ柡鈧?閸戠姳缍嶉崢瀣煂鐠ч鍋ｉ敍鍧?= 0 = 鏉╄渹缍橀弶鈥崇殱闂堛垽鍋呮稉鈧亸蹇撴健閿涘绱?
    //   娴滃孩妲哥粭顑跨鐢呮暰閸戠儤娼电亸杈ㄦЦ"鏉╄渹缍橀弶锟犲亝闁插瞼娈戞稉鈧亸蹇撴健"閿涘矁藟闂傛潙婀?`onAppear` 闁插矁绐囬妴?
    //   閳跨媴绗?鏉╂柨娲?false 鐠囧瓨妲戦崙鐘辩秿濞岋繝鍣烘鎰剁礄鏉╄渹缍橀弶鈥崇殱闂堛垺鐥呮稉濠冨Г / 鐎瑰じ瀵屽▽鈥虫槀鐎甸潻绱氶敍姘箑妞ょ粯濡搁惄闀愮秴闁偓閸ョ偛骞撻敍?
    //      閸氾箑鍨?`sheetHeightPercent()` 娴兼矮绔撮惄纾嬬箲閸?100%閿涘矁鈧浇鐭惧鍕畱"鐠愭潙绨虫稉鈧弶锟犳毐娑撳﹥娼?娑旂喕顫﹂崡鈩冨竴閿?
    //      閻劍鍩涢惇瀣煂閻ㄥ嫬姘ㄩ弰?閻愮懓绱戦幘顓熸杹閸ｃ劍鐥呴張澶夋崲娴ｆ洖濮╅悽?閵?
    // 閳?**娑撳秷顩﹂崷銊﹀瘯鏉炶姤妞傜亸杈ㄥΩ閸戠姳缍嶉崢瀣煂鐠ч鍋?*閿涘牐绻栨稉鈧弶鈩冩Ц閺冪姷鏅?`expand.init` 閻ㄥ嫰銆庢惔蹇ョ礉娑斿澧犻惃鍕粵濞夋洖寮芥禍鍡礆閿?
    //   閸欏秶绱拠鎴﹀櫡 `setupExpandTransition` 閺?**閸忓牓鍣洪惄顔界垼閼哄倻鍋ｉ惌鈺佽埌**閿涘牊顒濋崚缁樻尡閺€楣冦€夋潻妯荤梾缂傗斂鈧焦妲搁崢鐔锋槀鐎甸潻绱?
    //   閳?閸?start 瑜般垹褰?閵嗗倹鍨滈崢鐔告降閸?`aboutToAppear` 鐏?`morphBeginEntering()`閿? 缁斿鍩㈢紓鈺佸煂鐠ч鍋ｉ敍澶涚礉
    //   娴滃孩妲哥粵澶婂煂閼充粙鍣洪惃鍕閸婃瑱绱濋柌蹇撳煂閻ㄥ嫭妲?*鐞氼偄甯囬幍渚€鍋呮稉鈧敮?*閻ㄥ嫬鐨濋棃?閳ユ柡鈧?缂佸牏鍋ｇ亸杈潶閸愭瑥娼栨禍鍡窗
    //   "缁楊兛绔村▎鈩冪梾閺堝鐨濋棃銏ゎ棧閸?閵?缂佹挻娼弮璺恒亣鐏忓繋绗夌€?閵?閸欘亞些閸斻劋绗夌紓鈺傛杹"閸忋劍妲告潻娆庣閺夆€崇穿鐠ч娈戦妴?
    //   閻滄澘婀弨瑙勫灇閿涙碍瀵曟潪浠嬫▉濞堝吀绮堟稊鍫ュ厴娑撳秴浠涢敍宀€鏁?`playExpandIntro()`閿涘潵nAppear 鐠у嚖绱濈敮?12鑴?2ms 闁插秷鐦敍?
    //   閸?*妫ｆ牗顐奸柌蹇撳煂**閻ㄥ嫰鍋呮稉鈧崚缁樺 `measureMini` + `morphBeginEntering()` 閳ユ柡鈧?闁插繒娈戦弰顖氬斧鐏忓搫顕惌鈺佽埌閿?
    //   缁毖勫复閻偓閸氬奔绔寸敮褍甯囬崚鎷屾崳閻愮櫢绱欓柊宥呮値娑撳娼伴惃?`introPaintReady` 闂傤煉绱濇稉宥勭窗闂傤亜鍤€瑰本鏆ｉ幘顓熸杹妞ょ绱氶妴?
    // 閳跨媴绗?閻妫悪妤嬬窗娑撳洣绔存稉瀣桨 `onAppear` 闁插瞼娈戠悰銉╂？閸ョ姳璐熸禒璁崇秿閸樼喎娲滃▽陇绐囩挧閿嬫降閿?
    //   鏉╂稑瀹崇亸鍙樼窗濮樻瓕绻欓崑婊冩躬"閺€鎯版崳"閿涘瞼鏁ら幋椋庢箙閸掓壆娈戦弰顖涘ⅵ娑撳秴绱戦幘顓熸杹閸ｃ劊鈧?
    //   閺堚偓鏉?COLLAPSE_WATCHDOG_MS 娑斿鎮楀鍝勫煑閸ョ偛鍩岀€瑰本鏆ｉ幀?閳ユ柡鈧?鐎逛礁褰插▽鈩冩箒閸斻劎鏁鹃妴?
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
   * 閸忔娊妫撮拃鎴掔秴娑斿鎮楅敍?*缁涘鎸遍弨楣冦€夐惇鐔烘畱娴犲氦鐭鹃悽杈ㄧ垽闁插奔绗呴崣甯礉閸愬秴顦叉担宥呰埌閸欐ê鍤戞担?*閵?
   *
   * ## 娑撹桨绮堟稊鍫滅瑝閼宠棄婀崥灞肩 tick 闁插苯顦叉担宥忕礄閻劍鍩涚粭?閳?閺夛紕娈戦張鍝勫煑閿?
   * 閸忔娊妫撮弨璺虹啲閸樼喐娼甸弰?`isShowPlay = false`閿涘牃鍟?婢瑰啿鐪?`@Monitor` **瀵倹顒?* pop閿?
   * 缁毖嗙閻偓**閸氬本顒?* `morphReset()`閵嗗倽鈧?`morphReset()` 娴?
   * `morphStage = NONE` + `morphP = 1` + `morphClipHeight = 0` + `morphScale = 1`
   * 閳?鐎圭懓娅?*娑撳秷顥嗛崜顏傗偓浣风瑝缂傗晜鏂?* = **濠娾€崇潌閹绢厽鏂佹い?*閿?
   * 鐠侯垳鏁遍崡纾嬵洣閸掗绗呮稉鈧敮褎澧犵悮顐ｆ喅閹哄绱檂@Monitor` 濞叉儳褰傛稉鈧仦?+ 鐢啫鐪幗姗€娅庢稉鈧仦鍌︾礆
   * 閳?娑擃參妫块柇?1~2 鐢冩皑閺?瀹歌尙绮＄紓鈺傚灇鐏忓繐娓鹃悙?閳?缁愪胶鍔у鈥崇潌 閳?濞戝牆銇?閿?
   * 閻劍鍩涢幓蹇氬牚閹存劑鈧苯濮╅悽鑽ょ波閺夌喍绨?*缁愪胶鍔ч弶銉ら嚋鐏炴洖绱戦幘顓熸杹閸ｃ劎娈戦崝銊ф暰**閵嗗秲鈧?
   *
   * ## 娑撹桨绮堟稊?閺呮矮绔撮悙鐟邦槻娴?閺勵垰鐣ㄩ崗銊ф畱
   * `morphLand()` 瀹歌尙绮￠幎濠勭帛閸掕埖娼堟禍銈堢箷缂佹瑨绯犳担鐘虫蒋娴滃棴绱濋懓?鐞氼偉顥嗛崷銊ㄧ碃娴ｇ姵娼柇锝勭疄妤?閻ㄥ嫰鍋呮稉鈧禒钘夊殤娴?
   * **閸︺劑銆夐棃顫瑓閸欓绠ｉ崜宥嗩劀閺勵垱顒滅涵顔炬畱閺勫墽銇氶悩鑸碘偓?* 閳?婢跺秳缍呭▽鈩冩箒娴犺缍嶉悶鍡欐暠閹躲垹婀?pop 閸撳秹娼伴妴?
   * 閸欏秷绻冮弶銉礉**娑撳秴顦叉担宥勭窗濮光剝鐓嬫稉瀣╃鏉?*閿涘牆鍤戞担鏇熷瘯閸?AppStorageV2 娑撳﹥妲搁崗鍙橀煩閻ㄥ嫸绱氶埇?韫囧懘銆忔径宥勭秴閿涘苯褰ч弰顖濐洣閺呮哎鈧?
   *
   * ## 閸掋倖宓佹稉杞扮矆娑斿牏鏁?閼哄倻鍋?鐠侯垳鏁遍柈鎴掔瑓閸欓绨?閼板奔绗夐弰顖氭祼鐎规艾娆㈤弮?
   * 閸ュ搫鐣惧鑸垫閿涘牅绶ユ俊?64ms閿涘褰ч弰?*鐠?* pop 濮ｆ柨鐣犺箛顐幢鐠у矁绶亸杈ㄥ€撻幃鍕偓鈧崶鐐插斧 bug閵?
   * 娑撱倓閲?*閻╁瓨甯寸拠缁樻殶**闁€燁洣濠娐ゅ喕閹靛秴顦叉担宥忕礉閸ョ姳璐熼崡鏇犳箙娑撯偓娑擃亪鍏樻导?婢跺秳缍呭妤€銇婇弮?閿?
   * 璺?`!this.isAlive`閿涘牐濡悙鍦獓閿涘鈧柡鈧?`onDisappear` 閺勵垵濡悙鍦埂閻ㄥ嫭绉锋径杈ㄦ閹靛秷袝閸欐埊绱?
   * 璺?`!playerRouteStillPushed()`閿涘牐鐭鹃悽杈╅獓閿涘鈧柡鈧?閸欙絽绶炴稉搴★紦鐏?`playerRouteIndex()` 闁劕鐡ф稉鈧懛娣偓?
   * 閳跨媴绗?閸欘亞婀呯捄顖滄暠娴?*婢额亝妫?*閿涙瓪pop()` 閸欘亝妲搁弨?`NavPathStack` 閻?*閺佺増宓?*閿?
   *    閼哄倻鍋ｉ惃鍕喅闂勩倛顩︾粵澶夌瑓娑撯偓濞?layout 閳?鐠侯垳鏁卞韫瑓閸欒埇鈧浇濡悙纭呯箷閸︺劌鐫嗘稉濠勬畱闁絼绔寸敮褎妲哥€涙ê婀惃鍕┾偓?
   * 閳跨媴绗?閸欘亞婀呴懞鍌滃仯娑旂喍绱?*婢额亝妫?*閿涙艾鍙ч梻顓⑩偓鏂捐厬閻?閸掑棙鏁柌宥呯紦"閸氬本鐗辨导姘承曢崣?`onDisappear`閿涘牊婀伴弬鍥︽ 5000+ 鐞?
   *    閻ㄥ嫭鏁為柌濠佺瑩闂傘劏顔夋潻鍥箹娴犳湹绨ㄩ敍澶嗏偓鏂衡偓?闁絾妞傞懞鍌滃仯鏉╂ü绱伴崶鐐存降閵?
   * 閳?娑撱倛鈧?*閸氬本妞?*閹存劗鐝涢幍宥嗘Ц"閻喓娈戠挧棰佺啊"閿涙稑鍟€閸?`attempt >= RESET_POLL_MAX` 閸忔粌绨抽敍?
   *    娣囨繆鐦?閸濐亝鈧洑琚辨稉顏囶嚢閺佷即鍏橀崸蹇斿竴閿涘苯鍤戞担鏇氱瘍娑撯偓鐎规矮绱扮悮顐㈩槻娴?閿涘牆鐣為崣顖涙珓閿涘奔绗夐崣顖欑瑝濞撳拑绱氶妴?
   *
   * ## 娑撱倝浜剧€瑰牆宕奸敍鍫㈠繁娑撯偓娑撳秴褰查敍?
   * 璺?`closeGen !== this.closeGen`閿涙俺绻栨稉鈧潪顔煎彠闂傤厼鍑＄悮?娑撳绔村▎鈥冲彠闂傤叀顕Ч?閸欐牔鍞?閳?閸掝偅绔婚敍?
   * 璺?`!morphGenAlive(resetGen)`閿涙艾鍤戞担鏇氱瑯娴狅絽褰垮鑼病閸欐ü绨?閳?瀹歌尙绮￠張澶婂焼娴滅尨绱欓弬棰佺鏉烆喗澧﹀鈧惃鍕殰閹?
   *   `staleClr` / `leakClr`閿涘绔绘潻鍥ц嫙闁插秴缂撴禍鍡曠窗鐠?閳?**閸愬秵绔绘稉鈧▎鈥虫皑娴兼碍濡搁崚姘虫崳閻ㄥ嫪绱扮拠婵囧笌濮?*
   *   閿涘牓鍋呭锝嗘Ц"閻愮懓鍤幍鎾崇磻濞屸剝婀侀崝銊ф暰"閻ㄥ嫭鍨氶崶鐙呯礆閵?
   *
   * @param closeGen 閹规洝骞忛懛顏勫彠闂傤叀鎹ｉ幍瀣畱閸忔娊妫存稉鏍﹀敩閸?
   * @param resetGen 閹规洝骞忛懛顏勫彠闂傤厽鏁圭亸楣冨亝娑撯偓閸掕崵娈戣ぐ銏犲綁娑撴牔鍞崣?
   * @param attempt 瀹歌尙绮℃潪顔款嚄鏉╁洤鍤戝▎鈽呯礄閸愬懘鍎撮柅鎺戠秺閻㈩煉绱?
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
      // 閳?2026-10-17閿涘牏鏁ら幋閿嬪Г閵嗗奔绗傞幏澶嬫尡閺€鐐蒋閸愬秴娲栭崢浼欑礉閹绢厽鏂侀弶鈥冲綁閹?*缁绢垵澹婇崡濠団偓蹇旀**閵嗗秮鍣?閹?鐠嬩礁婀崡鐘垫絻鏉╄渹缍橀弶锛勬畱
      //   缂佹ê鍩楅弶?娑旂喐澧︽潻娑滅箹娑撯偓閺夆槄绱氶敍姝歜ar=` = `sourceBarHidden`閿? = 鏉╄渹缍橀弶鈩冩殻閺壜ゎ潶閽樺繗鎹ｉ弶銉ょ啊閿?
      //   濮濓絽鐖舵惔鏂跨秼閺?**0**閿涘绱盽ovl=` = 婢瑰啿鐪板ù顔肩湴闁絼绔村Λ鎺旀畱鏉╂稑瀹抽敍鍧刴orphOverlayP`閿涘矂娼ゅ銏♀偓浣哥安瑜版挻妲?1閿涘绱?
      //   `own=` = 閸忓啩淇婇幁顖氬帬闂呭棗鐪伴弰顖氭儊鏉╂ê宕伴惈鈧紒妯哄煑閺夊喛绱? = 鏉╂ê婀崡?閳?鏉╄渹缍橀弶锟犲亝娴犺姤鐡曢崥宥堫潶閸樺鍨?0閿涘鈧?
      //   閳跨媴绗?鏉╂瑥鍤戞稉顏堝櫤**閸欘亜婀潻娆撳櫡鐠?*閿涘潉morphReset()` 閸掓艾鍨伴幎濠傜暊娴狀剙缍婃担宥忕礆閿涘本澧嶆禒銉ョ暊閸欏秵妲ч惃鍕Ц
      //   "閺€璺虹啲閸嬫艾鐣稊瀣倵"閻ㄥ嫮婀＄€圭偟濮搁幀?閳ユ柡鈧?閻劍鍩涙稉瀣偧閹垫挸绱戝鑺ョ垼鐏忚精鍏橀惇瀣煂娑撳﹣绔村▎鈥冲彠闂傤厾鏆€娑撳绨℃禒鈧稊鍫涒偓?
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
   * 閹绢厽鏂佹い浣冪熅閻?*閺勵垰鎯佹潻妯烘躬婢瑰啿鐪伴惃?`NavPathStack` 闁?*閵?
   *
   * 閳?2026-10-16 閺傛澘顤冮敍鍫濇暜娑撯偓鐠嬪啰鏁ら悙鐧哥窗`.onDisAppear()` 闁插矂鍋呴柆?`isShowPlay` 閸忔粌绨抽梻顭掔礆閵?
   *
   * ## 娑撹桨绮堟稊鍫ユ付鐟曚礁鐣?
   * `isShowPlay` 閺?*婢瑰啿鐪扮捄顖滄暠閻ㄥ嫰鈹嶉崝銊︾爱**閿涘潉Index.@Monitor('appState.isShowPlay')`
   * 閳?`popPlayerRoute()`閿涘鈧倽鈧?`.onDisAppear()` 閺?*閼哄倻鍋ｇ痪?*閸ョ偠鐨熼敍灞肩窗閸?
   * "閻愮懓鍤幍鎾崇磻閺冭埖妫€圭偘绶ラ崡姝屾祰 / 閸掑棙鏁柌宥呯紦"鏉╂瑤绨洪崷鍝勬値**娑?*鐟欙箑褰?閳ユ柡鈧?闁絾妞傞幘顓熸杹妞や絻鐭鹃悽杈ㄦ閺勫骸婀弽鍫ュ櫡閵?
   * 閹碘偓娴犮儴顩﹂崘?`isShowPlay = false` 娑斿澧犻敍灞界箑妞よ鍘涚涵顔款吇"鏉╂瑤绔村▎锛勬埂閻ㄥ嫭妲告稉瀣酱"閵?
   *
   * 閳跨媴绗?閸欙絽绶炴稉搴★紦鐏炲倻娈?{@link Index.playerRouteIndex} **闁劕鐡ф稉鈧懛?*閿涘潉getAllPathName()` +
   *    `indexOf(PLAYER_PAGE)`閿涘绱濇潻娆愮壉娑撱倛绔熺€?閹绢厽鏂佹い闈涙躬娑撳秴婀弽鍫ュ櫡"濮樻瓕绻欓弰顖氭倱娑撯偓娑擃亞鐡熷鍫涒偓?
   * 閳跨媴绗?閸欐牔绗夐崚鐗堢垽閿涘潉@Consumer` 濞屸剝甯存稉濠忕礆閺?*鏉╂柨娲?true**閿? 娣囨繂鐣х拋銈勮礋"鏉╂ê婀弽鍫ュ櫡"閿涘绱?
   *    鐎逛礁褰插蹇斿竴娑撯偓濞?Hard-exit 閸忔粌绨抽敍灞肩瘍缂佹繀绗夐崘鎺旀絻"閹跺﹤鍨伴幍鎾崇磻閻ㄥ嫭鎸遍弨楣冦€夊瑙勫竴"閻ㄥ嫰顥撻梽鈹库偓?
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
   * @returns 鏉╂瑦顐奸崡姝屾祰**鐠囥儰绗夌拠銉﹀Ω瑜般垹褰夌紒妯哄煑閺夊啩姘︽潻妯肩舶鏉╄渹缍橀弶?*閿? 鐠囥儰绗夌拠?`morphReset()`閿涘鈧?
   *
   * 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤幍鎾崇磻濞屸剝婀侀崝銊ф暰"閻ㄥ嫭娓剁紒鍫濆灲閹?* 閳ユ柡鈧?娑撳鐤嗙拠鏇㈡晩閸氬骸鐣剧粙鍖＄礆
   *
   * ## 鐞氼偄鎯侀幒澶屾畱娑撱倓閲滈悧鍫熸拱閿涘牆鍩嗛崘宥呮礀閸樹紮绱?
   * | 閸掋倖宓?| 娑撹桨绮堟稊鍫ユ晩 |
   * | --- | --- |
   * | `morphUsable`閿?閸戠姳缍嶅鎻掓皑缂?閿?| **婢额亝娅?*閿涙氨鍋ｉ崙鏄忕熅瀵板嫬婀幐鍌濇祰闁絼绔撮崚鑽ょ矒閻愬綊鏁嬮悙纭呯箷濞岋繝鍣洪崚?閳?閹帒浜?閳?闂傘劍妗堟潻婊冪磻閻偓 |
   * | `playerRouteStillPushed()`閿?鐠侯垳鏁辨潻妯烘躬閺嶅牓鍣?閿?| **娓氭繆绂嗗鍡樼仸鐠嬪啫瀹?*閿涙瓪.onDisAppear` 闁綁浜鹃梻銊︽Ц `setTimeout(0)`閵嗕梗aboutToDisappear` 閺勵垰鎮撳銉礉閼?`popPlayerRoute()` 閸?*閸欙缚绔存稉?* `@Monitor` 閸ョ偠鐨熼柌宀冪獓 閳ユ柡鈧?娑撳鈧懓鐨濋崗鍫ｇ殱閸氬酣娼ら幀浣筋嚢娑撳秴鍤弶銉礄`RzdMusic鐠佹澘绻?md` 鎼?10 瀹歌尪顔囨稉杞扮瑝绾喖鐣炬い鐧哥礆 |
   *
   * ## 鐎规氨顭堥崚銈嗗祦 = **閻劍鍩涢幇蹇撴禈**閿涘潉isShowPlay`閿? 娑撯偓閺夛紕鈥栨笟瀣樆
   * ```
   *   !isAlive          閳?閻唹椋庣矋娴犺泛宓忔潪鏂ょ礄娑撳秵妲?閹垫挸绱戦弮鑸垫＋鐎圭偘绶ョ拋鈺€缍?閿涘鍣?韫囧懘銆忛弨鐐綀
   *   morphGeomReady    閳?鏉╂瑤绔存潪顔炬埂閻ㄥ嫬婀幘顓ㄧ礄缂佸牏鍋ｉ崙鐘辩秿瀹告煡鍣洪崚甯礆閳?缂佹繀绗夐懗鑺ュⅵ閺?
   *   state.isShowPlay  閳?婢瑰啿鐪伴崬顖欑閻?閹绢厽鏂佹い浣冾嚉娑撳秷顕氶崷銊ョ潌娑?閻喐绨?閳?閺€鐐綀 = 閹跺﹥澧﹀鈧懛顏勭箒閹烘劖鏌?
   * ```
   *   璺?**閻愮懓鍤幍鎾崇磻**閿涙艾锛撶仦鍌氬灠閹?`isShowPlay` 缂?`true` 閳?鏉╂瑤绔村▎鈥冲祻鏉炴垝绗夐崣顐ｆ杹閺?閴?
   *   璺?**閸忔娊妫?*閿涘牆鍙ч梻顓熷瘻闁?/ 娑撳濯?/ 缁崵绮烘潻鏂挎礀閿涘绱伴崗鎶芥４闁炬崘鐭惧鑼枂 `false` 閳?閺€鐐綀 閴?
   *   璺?娑撱倖娼柈鎴掔瑝娓氭繆绂?婢跺嫮鎮婇柇锝勭閸掔粯鐖ら柌灞炬箒娴犫偓娑? 閳?**娑撳秳绶风挧鏍︽崲娴ｆ洘妞傛惔?*閵?
   *
   * 閳跨媴绗?`!isAlive` 闁絾娼?*韫囧懘銆忔穱?*閿涙艾鐣犻崥灞炬濞戝牊甯€"娴兼俺鐦藉▔鍕础"閳ユ柡鈧梹纭犲蹇庣窗鐠佲晙绗呮稉鈧▎锛勫仯閸戞槒顕伴崚?
   *    `isFreshSession = false` 閼板矁铔?閺€鎯х磾娴兼俺鐦?閸掑棙鏁敍鍫濆嫉濞屸€冲З閻紮绱氶妴?
   *    闁板秴顨滈惃鍕幑鎼存洖婀?`Index.beginOpenMorphOnClick`閿涘潉leakClr` 闁絾娼懛顏呭墹閿涘鈧?
   * 閳跨媴绗?娑?`.onDisAppear` 闁插矂鍋呴柆鎾绘，**韫囧懘銆忛崥灞肩娑擃亜鍨介幑?*閿涘牆鎮撴稉鈧ぐ銏㈠Ц閿涘奔绗夌拋绋挎倗閸愭瑤绔存總妤嬬礆閵?
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
    // 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤幍鎾崇磻 / 閻愮懓鍤崗鎶芥４ / 缁崵绮烘潻鏂挎礀 濞屸剝婀侀崝銊ф暰"閻ㄥ嫭娓剁紒鍫熷腹閹?*閿涘绱?
    //   閸樼喎褰為弰?*閺冪姵娼禒韬测偓浣告倱濮?*閻?`morphReset()`閵嗗倽鈧?`morphReset()` 娴兼艾浠涢崶娑楁娴滃绱?
    // ```
    //     morphGen++                  閳?閹碘偓閺?`morphGenAlive` 鐎瑰牆宕肩粩瀣煝鏉╁洦婀?
    //     morphUsable = false         閳?鎼?02/鎼?04 娣囶喖銈介惃鍕亝娑撳顦╃€瑰牆宕奸崣鍫濆弿鎼?
    //     morphSessionStarted = false 閳?鎼?08 閸旂姷娈?閺傞绱扮拠?閸掋倖宓佺悮顐ｅЫ閹?
    //     morphGeomReady = false      閳?娑撳﹣绔存潪顔煎閻?`pullGeomReady` 闂傘劏顫﹂崗鍐叉礀閸?
    // ```
    //   閳跨媴绗?閼?*閻愮懓鍤幍鎾崇磻閺冭绱濋弮褎鎸遍弨楣冦€夌€圭偘绶ラ惃?`aboutToDisappear` 鐏忓崬婀潻娆庣鏉烆喛鎹ｉ幍瀣╃閸氬氦绐?*
    //   閿涘牊婀伴弬鍥︽ `:4235` 閼奉亜绻侀崘娆掔箖"閺傛澘鐤勬笟?`onAppear` 娑撳孩妫€圭偘绶?`onDisappear` 閸戠姳绠崥灞芥姎"閿?
    //     `aboutToDisappear` 濮?`onDisappear` **閺囧瓨妫?*閿涘矁鈧奔绗?*濞屸剝婀佹禒璁崇秿瀵ゆ儼绻?*閿?
    //   閳?鐎瑰啯濡?*閸掓艾鍨板铏圭彌婵傜晫娈戦弬棰佺鏉烆喕绱扮拠?*閺佺繝閲滃〒鍛竴閿?
    //     璺?`beginOpenMorphOnClick` 閻?`isFreshSession` 閸掋倖宓佺悮顐ｅЫ 閳?鐠?閺€鎯х磾娴兼俺鐦?闁絾娼崚鍡樻暜閿?
    //     璺?`settlePullOpen` 閻ㄥ嫯藟闁插繘鎽奸幎濠傚殤娴ｆ洟鍣洪崶鐐存降娑斿鎮楅敍灞藉嫉娴兼碍婀佹禍鍝勫晙濞撳懍绔村▎鈽呯幢
    //     璺?鐟欏倹鍔呯亸杈ㄦЦ閻劍鍩涢幎銉ф畱闁絼绗侀弶?閳ユ柡鈧?**閻愮懓鍤幍鎾崇磻 / 閻愮懓鍤崗鎶芥４ / 缁崵绮烘潻鏂挎礀 闁姤鐥呴張澶婄殱闂?閼冲本娅欓崝銊ф暰**
    //       閿涘牐鈧奔绗傞幏澶愬亝閺壜ょ熅娑撳秶绮℃潻?閺冄冪杽娓氬宓忔潪?閿涘本澧嶆禒銉ょ閻╁瓨顒滅敮闈╃礆閵?
    //
    // ## 閸掋倖宓侀敍姝緻link morphSessionOughtToLive}閿涘牅绗佹潪顔跨槸闁挎瑥鎮楃€规氨顭堥敍宀€鎮婇悽鍗炲晸閸︺劑鍋呴柌宀嬬礆
    // ```
    //   !isAlive                閳?閻唹椋庣矋娴犺泛宓忔潪?閳?韫囧懘銆忛弨鐐綀閿涘牐绻栭弶鈥虫倱閺冭埖绉烽幒?娴兼俺鐦藉▔鍕础"閿?
    //   morphGeomReady          閳?鏉╂瑤绔存潪顔炬埂閻ㄥ嫬婀幘?閳?缂佹繀绗夐懗鑺ュⅵ閺?
    //   state.isShowPlay        閳?閻劍鍩涢幇蹇撴禈"閹绢厽鏂佹い浣冾嚉閸︺劌鐫嗘稉? 閳?閺€鐐綀 = 閹垫挸绱戠悮顐ュ殰瀹歌鲸甯庨弬?
    // ```
    //   閳跨媴绗?閹存垵鍘涢崥搴ょ槸鏉?`morphUsable` 娑?`playerRouteStillPushed()`閿涘奔琚辨稉顏堝厴闁挎瑱绱濋崢鐔锋礈鐟?
    //      `morphSessionOughtToLive()` 閻ㄥ嫭鏁為柌濠忕礄娑撯偓娑擃亜銇婇弲姘モ偓浣风娑擃亙绶风挧鏍攱閺嬫儼鐨熸惔锔肩礆閵?
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
    // 閹貉冨煑閸栭缚鍤滈崝銊︽暪鐠ч娈戠拋鈩冩娑旂喕顩﹂崑婊愮窗妞ょ敻娼伴柈鍊熻泲娴滃棴绱濋崚顐㈠晙鐠佲晛鐣鹃弮璺烘珤缁岄缚娴?
    this.stopChromeAutoHide();
    // 娑撳绔村▎陇绻橀弶?`aboutToAppear` 娴兼岸鍣搁弬鎵枂閹存劖鏁圭挧鍑ょ礉鏉╂瑩鍣锋径宥勭秴閸欘亝妲告稉杞扮啊娑撳秶鏆€閼村繒濮搁幀?
    this.collapseProgress = 0;
  }

  /**
   * 閵嗗奔绔撮梹婊冨煂鎼存洏鈧秴鐫嶅鈧崝銊ф暰閿涙碍濡告潻娑樺娴?閺€鎯版崳"鐞涖儵妫块崚?0閵?
   *
   * 閹靛纭剁€瑰苯鍙忛悡褍寮懓鍐ㄤ紣缁?MusicHome閿?*閸欘亞鏁?`height` / `translate` / `scale` 娑撳閲滈崺鐑樻拱鐏炵偞鈧?*閿?
   * 娑撳秶顫禒璁崇秿瑜般垻濮哥憗浣稿 閳ユ柡鈧?闁綀绔熼幘顓熸杹妞ゅ吀绗呭鎴炴暪鐠ч攱妞傞惃?鐏忎線娼伴崣妯虹毈"鐏忚鲸妲告潻娆庣疄閸嬫氨娈戦敍?
   * `dismissSheetHeightPercent` + `coverLinearScale`閿涘绱濋幋鎴滄粦閸欘亝妲搁幎濠傛倱娑撯偓婵傛绻樻惔锕€寮介崥鎴ｇ獓娑撯偓闁秲鈧?
   *
   * 娑撹桨绮堟稊鍫ｇ箹閺嶅嘲姘ㄦ径鐔剁啊閿涙艾鍞寸€圭懓鐪?`justifyContent(FlexAlign.End)` 鐠愬娼冩惔鏇＄珶閿?
   * 妤傛ê瀹虫禒?鐠愭潙绨虫稉鈧弶?闂€鍨煂 100% = 娴犲骸绨抽柈銊ユ倻娑撳﹪鎽靛鈽呯幢鐏忎線娼伴悽?`layoutWeight(1)`閿?
   * 妤傛ê瀹抽崣妯虹毈鐎瑰啳鍤滃鍗炴皑閸欐ê鐨敍灞肩艾閺?鐏忎線娼伴幈銏″弮閸欐ê銇?娑旂喍绔寸挧閿嬫降娴滃棎鈧?
   */
  private playExpandIntro(): void {
    // 閳?**缂佺喍绔撮崗銉ュ經 + 閺冪姷鏅蹇撳幑鎼?*閿涙碍澧嶉張澶嬪ⅵ瀵偓閺傜懓绱￠敍鍫㈠仯閸戞眹鈧浇鎹ｉ幘顓熷壈閸ヤ勘鈧椒绗傞幏澶嬫緱閹靛绱氶柈鎴掔矤鏉╂瑩鍣锋潻娑栤偓?
    //   璺?閹靛瀵氬锝呮躬妞瑰崬濮?閳?鐠佲晝绮伴幍瀣◢閿?
    //   璺?娑撱倗顏柨姘卞仯閿涘牐绯犳担鐘虫蒋鐏忎線娼?+ 閹绢厽鏂佹い闈涚殱闂堫澁绱氶柈浠嬪櫤閸掗绨?閳?鐠ф澘鑸伴崣姗堢礄`tryStartMorphIntro`閿涘绱?
    //   璺?鏉╂ɑ鐥呮鎰剁礄閻愮懓鍤柇锝勭閸掔粯鎸遍弨楣冦€夐崚姘瘯鏉炲鈧礁鐨濋棃銏ｇ箷濞屸€崇鐏炩偓鐎瑰矉绱氶埆?**闁插秷鐦懟銉ュ叡鐢?*閿?
    //     鐎佃鐖ｉ弮鐘垫櫕 `beginMorphEnter` 婢惰精瑙﹂弮?濞夈劌鍞?onPullReady 缁涘姘ㄧ紒?閻ㄥ嫬浠涘▔鏇樷偓?
    //
    // 閳跨媴绗?閸掋倖宓佽箛鍛淬€忛弰?*娑撱倗顏?*闁挎氨鍋ｉ敍鍧刴orphIntroAnchorsReady`閿涘绱濇稉宥堝厴閸欘亜鍨?鏉╄渹缍橀弶锟犲櫤閸掗绨?閿?
    //    缂佸牏鍋ｉ敍鍫熸尡閺€楣冦€夌亸渚€娼伴敍澶嬬梾鐏忚京鍗庨弮?`endCoverSize = 0`閿涘瞼鐢绘鐐茬殱闂堛垺鐗撮張顑跨瑝娴兼氨鏁?
    //    閿涘潉morphBridging()` 娑?false閿涘绱濋懓灞炬尡閺€楣冦€夐懛顏勭箒闁絽绱剁亸渚€娼伴弰?閽€鎴掔秴閹靛秶骞?閳ユ柡鈧?
    //    娴滃孩妲告径缈犵娑撱倖顐肩仦鏇炵磻閻ㄥ嫯顫囬幇鐔锋皑閺?閻愮懓绱戦埆鎺嶇矆娑斿牓鍏樺▽鈩冩箒閳帒鏆樻稉鈧稉瀣煂娴?閿?
    //    閸滃瞼鏁ら幋閿嬪鐠囧娈?閻愮懓鍤幍鎾崇磻鏉╂ɑ妲搁弮褍濮╅悽?閸戠姳绠崚鍡曠瑝閸戠儤娼甸妴?
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
    // 閳?闁插秷鐦悽銊ユ晼 閳?**閻╁瓨甯撮拃鎴掔秴閿涘瞼绮锋稉宥嗘尡閼颁礁濮╅悽?*閿涘牆顕弽鍥у冀缂傛牞鐦ч惃?`setFinalStatus()`閿涘绱?
    //   閸欏秶绱拠?`setupExpandTransition` 闁?`expand.init(...)` 鏉╂柨娲?false 閻ㄥ嫬鍘规惔鏇炴皑閺?
    //   "閺€鎯х磾閸斻劎鏁鹃妴浣烘纯閹恒儴鎯ゆ担?閵嗗倿鈧偓閸ョ偛骞撻幘?閸樺澧庨崘鍛啇鐏炲倿鐝惔?闁絽顨滈懓浣稿З閻㈢粯妲?*閹存垹娈戦崣鎴炴**閿?
    //   娑旂喐顒滈弰顖滄暏閹村嘲寮芥径宥呭冀妫ｅ牏娈?閻愮懓鍤?鏉╂柨娲栭悽銊ф畱閺勵垱妫崝銊ф暰"閻ㄥ嫭娼靛┃鎰┾偓?
    Logger.error(PlaybackPage.logTag,
      'expand intro: anchors never became ready, landing without animation (setFinalStatus)');
    this.expandState.morphReset();
    this.expandState.morphSettleOpen();
    // 閺冪姴濮╅悽鏄忔儰娴ｅ秳绡冭箛鍛淬€忓鈧梻顭掔礉閸氾箑鍨弫鎾€夋导姘閻╂潙浠犻崷?娑撳秶鏁?閻ㄥ嫮濮搁幀渚婄礄閹垫挷绗夊鈧幘顓熸杹妞ょ绱?
    this.introPaintReady = true;
    this.collapseProgress = 0;
    this.expandIntroRunning = false;
  }

  /**
   * 鐏忔繆鐦挧鏉胯埌閸欐ê鐫嶅鈧捄顖氱窞閿涙岸鍣洪柨姘卞仯 閳?鏉╂稓娴夋担?閳?鐠х柉藟闂傛番鈧?
   * @returns true = 瀹歌尙绮￠幐澶婅埌閸欐鐭惧鍕磻婵绱欑拫鍐暏閺傞€涚瑝鐟曚礁鍟€鐠ф媽鈧浇鐭惧鍕剁礆
   */
  private tryStartMorphIntro(): boolean {
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER) {
      // 閹靛瀵氬锝呮躬妞瑰崬濮╅敍姘崇殱娑旂喎鍩嗛幎顫幢缂佹ê鍩楅梻銊ょ瘍娑撯偓楠炶埖鏂佺悰宀嬬礄鏉╂瑦娼捄顖欑瑝鏉╂稐绗呴棃銏㈡畱瀵偓闂傘劌鍨庨弨顖ょ礆
      // 妫ｆ牗顐兼稉濠冨閻ㄥ嫮娲伴弽鍥х毣閺堫亜绔风仦鈧弮鏈电矝娣囨繃瀵旈柅蹇旀閸忋劌鏄傜€甸潻绱濈悰銉╁櫤閹存劕濮涢崘宥嗘杹鐞涘被鈧?
      this.introPaintReady = this.expandState.morphUsable;
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
      return true;
    }
    this.expandState.pullDragging = false;
    // 閳?閸掋倖宓侀弰?*娑撱倗顏柨姘卞仯闁粙缍?*閿涘潉morphIntroAnchorsReady`閿涘绱濇稉宥嗘Ц"鏉╄渹缍橀弶锟犲櫤閸掗绨?閿?
    //   缂佸牏鍋ｉ敍鍫熸尡閺€楣冦€夌亸渚€娼伴敍澶嬬梾鐏忚京鍗庨弮?`endCoverSize = 0`閿涘瞼鐢绘鐐茬殱闂堛垺鐗撮張顑跨瑝娴兼氨鏁?
    //   閿涘潉morphBridging()` 娑?false閿涘绱濋懓灞炬尡閺€楣冦€夐懛顏勭箒闁絽绱剁亸渚€娼伴弰?閽€鎴掔秴閹靛秶骞?閳ユ柡鈧?
    //   娴滃孩妲告径缈犵娑撱倖顐肩仦鏇炵磻鐏忚鲸妲?閻愮懓绱戦埆鎺嶇矆娑斿牓鍏樺▽鈩冩箒閳帒鏆樻稉鈧稉瀣煂娴?閿涘牏鏁ら幋宄扮杽濞村娈?缁楊兛绔村▎鈩冪梾閺堝鐨濋棃銏ゎ棧閸?閿涘鈧?
    //
    // 閳?妞ゅ搫绨悽?`prepareMorphEntry` 閸ュ搫鐣鹃敍?*娴ｆ粌绨剧紒鍫㈠仯 閳?閸︺劌甯亸鍝勵嚟閺冨爼鍣?閳?閸愬秴甯囬崚鎷屾崳閻?*閵?
    //   閳跨媴绗?鏉╂瑩鍣?*閺佸懏鍓版稉宥呬粵 `alreadyRunning` 娑斿琚惃鍕叚鐠?*閿涙矮绔撮弮锔剧叚鐠侯垽绱濈亸鍙樼窗閸?
    //      "缂佸牏鍋ｅ鍙夋箒閵嗕椒绲鹃張顒冪枂鏉╂ɑ鐥呮潻娑滅箖瑜般垹褰?閻ㄥ嫪鑵戦梻瀛樷偓浣风瑓鐠哄疇绻冮崢瀣崳閻愮櫢绱?
    //      娴滃孩妲?`collapseProgress`/闂傘劎濮搁幀浣风瑢閻╅晲缍呯€甸€涚瑝娑撳鈧倸绠撶粵澶愬櫢閸忋儲妲哥€瑰鍙忛惃鍕┾偓?
    //   娑撳﹣绔撮悧鍫㈡畱 bug 濮濓絽婀潻娆撳櫡閿涙矮缍旀惔鐔峰З娴ｆ粏顫﹂弨鎯ф躬 `morphBeginEntering()` 閸愬懘鍎撮敍?
    //   濮濓絽銈介幎濠傚灠闁插繐鍩岄惃鍕矒閻愯濮介幒?閳?闁插秷鐦張鐔峰嫉鐞涖儰绗夐崶鐐存降閿涘潉morphLive()` 閹革紕娼冮敍?
    //   閳?闁插秷鐦悽銊ユ晼閺冪姴濮╅悽鏄忔儰娴?閳?**閻愮懓鍤捄顖氱窞娴犲孩娼靛▽陇绻樻潻?`playMorphOpenIntro()`**閵?
    if (!this.expandState.morphUsable) {
      return false;
    }
    // 閳藉應妲?2026-10-15閿涘牆娲栭柅鈧崥搴ㄥ櫢閸嬫熬绱?*娑撹桨绮堟稊鍫濐樆闂堛垼顩﹂崠鍛鐏?`UIUtils.applySync`**閿?
    //   `prepareMorphEntry` 閻ㄥ嫭娓堕崥搴濈濮濄儲妲?閹跺﹤鍤戞担鏇炲竾閸掓媽鎹ｉ悙?閿涘潉applyMorphProgress(0)`閿涘绱?
    //   缁毖勫复閻偓**閸氬奔绔存稉顏冩崲閸旓繝鍣?*鐏忚精鎹ｇ悰銉╂？閵嗗倽鈧?V2 閻ㄥ嫮濮搁幀浣稿綁闁插繋鎱ㄩ弨?*娑撳秳绱扮粩瀣祮閺嶅洩鍓?*閿涘牊濮?Promise 瀵邦喕鎹㈤崝鈽呯礆閿?
    //   `animateTo` 閸楃繝绱?*缁斿鍩㈤崚閿嬫煀瀹稿弶鐖ｉ懘蹇氬Ν閻愯娼甸崘鍐茬暰閸斻劍鏅ユ＃鏍ф姎** 閳?閸樺鎹ｉ悙褰掑亝娑撯偓娑?*濞岋紕鏁撻弫?*閿涘矂顩荤敮褏鏁ら弮褍鈧鈧?
    //   鐎规ɑ鏌熼敍鍧刟rkts-new-applysync-flushupdates-flushuiupdates`閿涘妲戠涵顔款潐鐎规俺绻栫粔?
    //   "閸斻劍鏅ラ崜宥嗘箒妫版繂顦绘穱顔芥暭"閻ㄥ嫬婧€閺咁垵顩﹂悽?`UIUtils.applySync` 閸氬本顒為崚閿嬫煀閸氬骸鍟€鐠у嘲濮╅悽?閳ユ柡鈧?鏉╂瑦顒滈弰?
    //   "閻愮懓鍤幍鎾崇磻閸滃本澧滈幐鍥ㄥ珛閸斻劍澧﹀鈧弰顖欒⒈娑擃亜濮╅悽?閻ㄥ嫮绮ㄩ弸鍕偓褎鐗撮崶鐙呯礄50ms 瀵ゆ儼绻?闁插秷鐦?缂佹ê鍩楅梻銊╁厴閺勵垰鐣犻惃鍕夋稉渚婄礆閵?
    //   閳跨媴绗?鐎瑰啫褰х憴锝呭枀**閺嶅洩鍓?*閵嗕椒绗夌憴锝呭枀**鐢啫鐪?*閿涙氨鐡戠亸渚€娼伴懞鍌滃仯闁插繐绶遍崚棰佺矝閻掓儼顩﹂棃鐘辩瑐闂堛垻娈戦柌宥堢槸缁愭褰涢妴?
    let prepared: boolean = false;
    UIUtils.applySync((): void => {
      prepared = this.expandState.prepareMorphEntry(this.getUIContext(), true);
    });
    if (!prepared) {
      // 娣囨繄鏆€閺堫剝鐤嗙亸杈╁崕閻樿埖鈧緤绱濈粵澶婄窡娑撳绔村▎鈥冲斧鐏忓搫顕敮鍐ㄧ湰閿涘奔绗夐崷銊╁櫢鐠囨洟妫块崢瀣級/婢跺秳缍呯敮鍐ㄧ湰閵?
      return false;
    }
    if (!this.expandState.morphIntroAnchorsReady()) {
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready ` +
        `(usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()})`);
      return false;
    }
    // 閸戠姳缍嶇亸杈╁崕閿涙艾绱戦梻顭掔礉閸忎浇顔忕紒妯哄煑閿涘牊顒濋弮璺哄嚒缂佸繑妲?鏉╄渹缍橀弶锟犲亝娑撯偓鐏忓繐娼?閻ㄥ嫯鎹ｉ悙瑙勨偓渚婄礆
    this.introPaintReady = true;
    this.expandIntroRunning = false;
    this.collapseProgress = 0;
    this.playMorphOpenIntro();
    return true;
  }

  /**
   * 閼颁浇鐭惧鍕剁礄閸戠姳缍嶅▽锟犲櫤閸掔増妞傞惃鍕幑鎼存洩绱氶敍姘敶鐎圭懓鐪扮拹瀵告絻鎼存洝绔熼敍宀勭彯鎼达缚绮?鐠愭潙绨虫稉鈧弶?闂€鍨煂 100%閵?
   *
   * 閸欘亜婀?`morphUsable === false` 閺冭埖澧犳导姘宠泲閸掓媽绻栭柌?閳ユ柡鈧?濮濓絽鐖堕幆鍛枌閿涘牐绯犳担鐘虫蒋閸︺劊鈧礁顔栨稉璇插嚒闁插繐鍩岄敍?
   * 娑撯偓瀵板铔嬭ぐ銏犲綁闁絾娼捄顖樷偓?
   */
  private playLegacyExpandIntro(): void {
    try {
      // 闁劕鍘撶槐鐘宠窗閸忋儳鏁?*閺堫剟銆夐懛顏呭瘮**閻ㄥ嫯绻樻惔锔肩礄1 = 鐠愭潙绨抽弨鎯版崳 閳?0 = 鐎瑰苯鍙忕仦鏇炵磻閿涘绱濇稉搴ㄧ彯鎼达箒藟闂傛潙鎮撶挧宄版倱閽€濮愨偓?
      // 閳跨媴绗?閸掔粯鍓版稉宥咁槻閻劌鍙℃禍?`PlayerExpandState` 閻?preparing/animating 閻╅晲缍呴敍?
      //    闁絽顨滈惄闀愮秴閻ㄥ嫮鐤嗘担宥囧仯閸︺劑鍣搁弸鍕厬閸忋劋娑禍鍡礉閹恒儰绗傞崢璇插涧娴兼艾绶遍崚棰佽⒈缁夊秴娼栫紒鎾寸亯 閳ユ柡鈧?
      //    閵嗗本浜界挧浼存姜閸斻劎鏁鹃崚鍡樻暜 閳?濞ｂ€冲弳缁涘绨▽鈥冲晸閵嗗秵鍨ㄩ妴灞剧垼韫囨鐣悾?閳?閺佹潙娼￠崘鍛啇缁犳鍨氶柅蹇旀閿涘牆鐨濋棃銏犲帥濞ｂ€虫倵濞戝牆銇戦妴浣规殻妞ょ數鈹栭惂鏂ょ礆閵嗗秲鈧?
      //    閺堫剟銆夐懛顏呭瘮 + 闂堟瑦顒涢幀浣逛航鏉╂柨娲?1閿涘苯姘ㄦ稉宥呯摠閸︺劍鐣悾娆愨偓浣碘偓?
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
      // 鐞涖儵妫跨挧铚傜瑝閺夈儱姘ㄧ粩瀣煝閸ョ偛鍩岀€瑰本鏆ｉ幀渚婄幢閻妫悪妤侇劃閺冩儼绻曞▽鈥冲煂閻愮櫢绱濋崚顐ヮ唨妞ょ敻娼伴崑婊冩躬"閺€鎯版崳"闁絼绔撮弶鈥茬瑐
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `expand animateTo failed code=${e.code} msg=${e.message}`);
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
    }
  }

  /**
   * 鐎圭懓娅掕ぐ銏犲綁鐠侯垰绶為惃鍕潔瀵偓鐞涖儵妫块敍姘殤娴ｆ洖婀?`aboutToAppear` 瀹歌尙绮￠崢瀣煂鐠ч鍋ｉ敍鍧?= 0閿?
   * 娑旂喎姘ㄩ弰?鏉╄渹缍橀弶锟犲亝閺壜ゅ厡閸?閿涘绱濇潻娆撳櫡閸欘亝濡哥€瑰啯甯归崚?1閿涘牓鎽靛鈽呯礆閵?
   *
   * 閳跨媴绗?`animateTo` 鐞涖儳娈戦弰?*鐏炵偞鈧冣偓?*閿涘澃cale / translate / height / borderRadius / opacity閿涘绱?
   *    娑撳秵妲?`morphP` 閺堫剝闊?閳ユ柡鈧?閹碘偓娴犮儵妫撮崠鍛村櫡閸欘亣顩﹂幎濠勫Ц閹浇鎯ら崚鎵矒閻愮懓宓嗛崣顖ょ礉娑擃參妫跨敮褏鏁卞鍡樼仸閹绘帒鈧》绱?
   *    閹碘偓閺堝绮﹂崷銊ユ倱娑撯偓娴犵晫濮搁幀浣风瑐閻ㄥ嫬鐫橀幀褌绱版稉鈧挧鐤泲閸氬奔绔撮弶鈩冩锤缁捐￥鈧?
   */
  private playMorphOpenIntro(): void {
    this.expandIntroRunning = true;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // 閳藉應妲?2026-10-15閿涘牆娲栭柅鈧崥搴ㄥ櫢閸嬫熬绱氶敍?*閸掔姵甯€閸樼喐娼?瀵よ泛鎮?50ms 閸愬秷鎹ｇ悰銉╂？"闁絼绔村?*閵?
    //   鐎瑰啫缍嬮獮瀛樻Ц娑撹桨绨＄紒鏇炵磻娑撯偓娑擃亞婀＄€圭偛鐡ㄩ崷銊ф畱閸ф埊绱?*V2 閻ㄥ嫮濮搁幀浣稿綁闁插繑妲?瀵倹顒為弽鍥壈"閿涘湧romise 瀵邦喕鎹㈤崝鈽呯礆閿?
    //   閼?`animateTo` 娴兼氨鐝涢崚璇插煕閺傛澘鍑￠弽鍥壈閼哄倻鍋ｉ弶銉ュ枀鐎规艾濮╅弫鍫ヮ浕鐢?* 閳ユ柡鈧?娴滃孩妲?閸忓牊濡搁崙鐘辩秿閸樺鍩岀挧椋庡仯閵?
    //   閸氬奔绔存稉顏冩崲閸旓繝鍣烽崘宥堟崳鐞涖儵妫?閺冭绱濋崢瀣崳閻愬綊鍋呮稉鈧稉?*濞岋紕鏁撻弫?*閿涘矂顩荤敮褏娲块幒銉ф暏閺冄冣偓绗衡偓?
    //   鐎规ɑ鏌熼敍鍧刟rkts-new-applysync-flushupdates-flushuiupdates`閿涘绮伴惃鍕掑▔鏇熸Ц
    //   `UIUtils.applySync(() => { 閳?})`閿涙艾鎮撳銉ュ煕閺備即妫撮崠鍛敶閻ㄥ嫮濮搁幀浣稿綁閸栨牭绱濋崘宥堟崳閸樼喐娼甸惃鍕З閻㈡眹鈧?
    //   閺堫剚鏌熷▔鏇㈠帳閸?`tryStartMorphIntro` 闁插矂鍋呯仦?`applySync` 娴ｈ法鏁?閳ユ柡鈧?
    //   鏉╂瑤绡冮弰?閻愮懓鍤幍鎾崇磻閸滃本澧滈幐鍥ㄥ珛閸斻劍澧﹀鈧弰顖欒⒈娑擃亜濮╅悽?閻ㄥ嫮绮ㄩ弸鍕偓褎鐗撮崶鐙呯礉50ms/闁插秷鐦?缂佹ê鍩楅梻銊╁厴閺勵垰鐣犻惃鍕夋稉浣碘偓?
    // 閳跨媴绗嶉埧鐙呯瑣 2026-10-17 缁剧姵顒滄稉鈧径?*閹存垼鍤滃鍗炲晸闁挎瑧娈戝▔銊╁櫞**閿涘牆鐣犻弰顖欑瑓闂堛垽鍋呮稉?bug 閻ㄥ嫭娼靛┃鎰剁礆閿?
    //   鏉╂瑩鍣烽崢鐔告降鏉╂ê鍟撻惈鈧妴灞界暭閺傚湱绮伴惃鍕晸濞夋洖姘ㄩ弰顖氭躬 `animateTo` 閻ㄥ嫰妫撮崠鍛村櫡閻?`UIUtils.applySync`
    //   閸氬本顒為崚閿嬫煀閻╊喗鐖ｉ崐绗衡偓宥佲偓鏂衡偓?*闁絾妲搁柨娆戞畱**閵嗗倸鐣奸弬褰掑亝娑擃亜婧€閺咁垱妲?
    //   閵?*閸斻劍鏅ユ稊瀣**閺堝顤傛径鏍︽叏閺€?閳?閸?`applySync` 閹?*鐠ч鍋?*閽€钘夋勾閿?*閸?*鐠?`animateTo`閵嗗稄绱?
    //   閼?**`animateTo` 闂傤厼瀵橀柌灞藉涧鐠佺鍟撻惄顔界垼閸?*閿涘牆鍟撴禒鈧稊鍫濇皑鐞涖儵妫块崚鏉挎憿闁插矉绱氶妴?
    //   閹跺﹤鐣犻弨鎹愮箻闂傤厼瀵橀柌?= 閹跺﹦娲伴弽鍥р偓鑲╃彌閸掕鍩涢崙鍝勫箵 閳?**鐞涖儵妫跨悮顐ョ儲鏉?* 閳?閻╁瓨甯寸捄宕囩矒閻愬箍鈧?
    //   閳?閺堫剚鏋冩禒鍫曞櫡 `applySync` 閻ㄥ嫭顒滅涵顔荤秴缂冾喖褰ч張?鐞涖儵妫挎稊瀣"閿涘牐顫?:3158 / :3737 娑撱倕顦╅敍澶堚偓?
    //   閳跨媴绗?娑撴牔鍞崣鍑ょ窗閺€璺虹啲閸ョ偠鐨熻箛鍛淬€忓В鏂款嚠 `morphGen`閿涘牆寮界紓鏍槯闁?`animGen++` + onFinish 閺嶏繝鐛欓敍澶涚礉
    //    閸氾箑鍨箛顐︹偓鐔荤箾閻?閺€鎯版崳娴兼矮瑕嗛悩鑸碘偓浣碘偓?
    const gen: number = this.expandState.morphGen;
    try {
      this.getUIContext().animateTo({
        duration: PlaybackPage.MORPH_OPEN_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        // 閳藉應妲勯埥鍛 2026-10-17閿?*閻劍鍩涚粭?1 閺?閻愮懓鍤幍鎾崇磻閺冪姴濮╅悽姹団偓浣烘纯閹恒儱鍩岀紒鎾存将娴ｅ秶鐤?閻ㄥ嫭鐗撮崶?*閿?
        //
        // 鈽呪槄鈽呪槄 2026-10-17锛?*闂寘閲屽彧鍐?`morphP` 杩欎竴涓噺** 鈥斺€?鐓ф惉鏃犵晫"涓€涓?morphT 椹卞姩涓€鍒?锛?
        //   鍘熸潵鍐?`applyMorphProgress(1)`锛氬畠浼?*涓€娆℃€?*鎶?`morphP` 杩炲悓鍑犱綍鍏ㄥ啓鎴愮粓鐐癸紝
        //   浜庢槸鎵€鏈?鎸?`morphP` 鍙栧€?鐨勬淳鐢熼噺锛堣儗鏅?`pullBgIn`銆佸悇娈垫贰鍏ョ獥鍙ｏ級鍦ㄨ捣鎵嬮偅涓€甯?
        //   灏辫烦鍒颁簡缁堢偣 鈬?鐢ㄦ埛瀹炴祴鐨勩€?*涓€寮€灏辨槸鑳屾櫙鑹?/ 璧峰涓嶆槸姝ｅ父棰滆壊**銆嶃€?
        //   鐜板湪鍙啓 `morphP`锛岀敱 `PlayerExpandState.@Monitor('morphP')` 閫愬抚閲嶇畻鍑犱綍涓庢淳鐢熼噺
        //   鈥斺€?涓庝笂娓告瘡甯?`applyPullProgress(effT())` 鍚屾瀯銆?
        this.expandState.morphP = 1;
      });
    } catch (err) {
      // 鐞涖儵妫跨挧铚傜瑝閺夈儰绡冪憰浣芥儰閸掓澘鐣弫瀛樷偓渚婄礉缂佹繀绗夐懗鑺ュΩ閹绢厽鏂佹い鐢垫殌閸?鏉╄渹缍橀弶锟犲亝娑撯偓鐏忓繐娼?
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
      // 閳藉應妲?2026-10-16閿?*閸氬奔绔撮弶?娑撳秷顩﹂崷銊︾梾閺堝鍤戞担鏇熸閽€鎴掔秴"閻ㄥ嫯顫夐崚?*閿涘矁顫?`Index.settlePullOpen`閿涘绱?
      //   鏉╂瑤绔撮崣銉ュ斧閺夈儲妫ら弶鈥叉閽€鎴掔秴閵嗗倽瀚㈤張顒冪枂閸戠姳缍嶆慨瀣矒濞岋繝鍣洪崚甯礄`morphGeomReady` 娑撳搫浜ｉ敍澶涚礉
      //   `morphSettleOpen()` 閸愬懘鍎撮惃?`applyMorphProgress(1)` 娴兼俺顫﹂柇锝変壕闂傘劍灏呴幒澶堚偓?
      //   閼板瞼娴夋担宥呭祱缂堢粯鍨?OPEN 閳?鐎圭懓娅掗崑婊冩躬閹帞鐡?+ 閻╅晲缍?OPEN 閻?*閸楀﹥顒撮悩鑸碘偓?*閵?
      //   閳?閹稿妫ら悾灞烩偓宀勫櫤娑撳秴鍩岀亸閬嶁偓鈧崶鐐存珮闁?push(閺冪姴鑸伴崣?閵嗗秶娈戦崣锝呯窞閿涙艾褰ч幎濠勬祲娴ｅ秵鏁归獮鎻掑櫍閿涘奔绗夐拃鎴掔秴閵?
      if (!this.expandState.morphGeomReadyNow()) {
        this.expandState.pushMorphTrace('openNoGeom');
        this.expandState.morphReset();
        this.expandState.morphStage = MorphStage.OPEN;
        this.expandState.morphP = 1;
        this.expandState.measureGeometry(this.getUIContext(), true);
        return;
      }
      this.expandState.morphSettleOpen();
      // 閳?閽€鎴掔秴閸?*闁插秹鍣烘稉鈧▎?*閸戠姳缍嶉敍姘崇箹娑撯偓閸掑銆夐棃銏犲嚒缂佸繑妲搁崢鐔锋槀鐎甸潻绱檚cale=1閵嗕椒缍呯粔?0閿涘绱?
      //   闁插繐鍩岄惃鍕Ц楠炴彃鍣ｉ惃鍕矒閻愬湱鐓╄ぐ顫幢閸氬本妞傞幎?aside 閻ㄥ嫬顔旀惔锕€鍩涢弬棰佺闁稄绱橦DS 鎼存洘鐖幒鎺戠閸欘垵鍏橀崣妯跨箖閿涘鈧?
      //   閳跨媴绗?鏉╂瑤绔撮柌蹇撳涧瑜板崬鎼?*娑撳绔存潪?*鐏炴洖绱戦敍鍫滅瑝閸斻劍婀版潪顔剧矒閻愮櫢绱氶敍灞惧娴犮儱鐣犻弰?娑撳绔存潪顔芥纯閸?閻ㄥ嫪绻氶梽鈺嬬礉
      //      娑撳秵妲搁張顒冪枂閽€鎴掔秴鐎甸€涚瑝鐎靛湱娈戞笟婵囧祦閵?
      this.expandState.measureGeometry(this.getUIContext(), true);
    }, PlaybackPage.MORPH_OPEN_DURATION_MS + 30);
  }

  /**
   * @returns 閸愬懎顔愮仦鍌炵彯鎼达妇娅ㄩ崚鍡樼槷鐎涙顑佹稉灞傗偓?
   *
   * 鏉╂稑瀹?0 閳?`'100%'`閿涘牅绗屽▽鈩冩箒閸斻劎鏁鹃弮鍫曗偓鎰剼缁辩姳绔撮懛杈剧礉鏉╂瑦妲搁張鈧柌宥堫洣閻ㄥ嫭鈧嗗窛閿涘绱?
   * 鏉╂稑瀹?100 閳?`COLLAPSED_HEIGHT_PERCENT`閿涘牐鍒涙惔鏇氱閺夆槄绱濇径褑鍤х亸杈ㄦЦ鏉╄渹缍橀弶锟犲亝娑撯偓閺夛紕娈戞妯哄閿涘鈧?
   */
  private sheetHeightPercent(): string {
    // 閳跨媴绗?鐎圭懓娅掕ぐ銏犲綁閿涘牊妫ら悾宀勫亝婵傛绱氶張鐔兼？**韫囧懘銆忛幁鎺嶈礋 100%**閿涙岸鍋呮總妤€褰ч棃?婢舵牕鐪扮€圭懓娅掔紓鈺傛杹 + 鐟佷礁澹€"鐎瑰本鍨氱仦鏇炵磻閿?
    //    閼汇儴绻栭柌灞芥倱閺冭埖瀵?collapseProgress 閸樺缂夐崘鍛啇鐏炲倿鐝惔锔肩礉鐏忚鲸婀佹稉銈咁殰閸斻劎鏁鹃崷銊︽暭閸氬奔绔撮悧鍥х鐏炩偓閿?
    //    鐞涖劎骞囨稉鍝勫敶鐎圭顫﹂崢瀣閵嗕礁鐨濋棃銏ゆ晩娴ｅ秲鈧?
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
   * @returns 閺€鎯版崳鏉╁洨鈻兼稉顓熸Ц閸氾箒顩﹂挊蹇氭崳閺嶅洭顣?閹貉傛閵?
   *
   * 韫囧懘銆忛挊蹇ョ窗閸愬懎顔愮悮顐㈠竾閹典礁鍩岄崣顏勫⒖娑撯偓閺夆剝妞傞敍灞芥祼鐎规岸鐝惔锔炬畱閹貉冨煑閸栬桨绱伴幎濠傜殱闂堛垺灏嬮幋?0 妤?
   * 閿涘牆寮懓鍐ㄤ紣缁嬪绡冮弰顖濈箹娑斿牆顦╅悶鍡欐畱 閳ユ柡鈧?鐎瑰啰娈?`isDismissPhase2HideMeta()` 娑撯偓鏉╂稐绨╁▓闈涙皑閽?meta閿涘鈧?
   */
  private isCollapsing(): boolean {
    // Morph dismiss keeps natural layout mounted; opacity/clip handles chrome continuously.
    return !this.expandState.morphContainerActive() && this.collapseProgress > 45;
  }

  /**
   * 閳?2026-10-17閿涙矮绗傛稉鈧▎?*閻喐顒滄稉瀣絺閹存劕濮?*閻ㄥ嫬鐖舵禍顔姐€傛担宥忕礄`undefined` = 鏉╂ɑ鐥呴幋鎰鏉?/ 婢惰精瑙﹀鎻掓礀濠婃熬绱氶妴?
   *
   * 閻撗勬儔閺冪姷鏅?`WindowInfo.setKeepScreenOn`閿涘潉design/animation/WindowInfo.ets`閿涘娈戦獮鍌滅搼閸掋倖宓侀敍?
   * ```ts
   *   setKeepScreenOn(on) {
   *     if (this.screenOn === on) return;                 // 閳?閸婂吋鐥呴崣妯烘皑娑撳秳绗呴崣鎴礄楠炲倻鐡戦敍?
   *     if (window === undefined) return;
   *     this.screenOn = on;
   *     window.setWindowKeepScreenOn(on).catch(浣?);       // 閳?浣?閿涙arn + `screenOn = false`閿涘牆銇戠拹銉ユ礀濠婃熬绱?
   *   }
   * ```
   * 閳跨媴绗?**閸ョ偞绮撮柇锝呭磹閺夆剝妲搁崗鎶芥暛**閿涙俺瀚㈡稉宥呮礀濠婃熬绱濇径杈Е娑斿鎮楃紓鎾崇摠閸婇棿绗岄惇鐔风杽閸婇棿绗夋稉鈧懛?閳?娑撳绔村▎鈥虫倱閸婅壈顕Ч鍌欑窗鐞氼偄绠撶粵澶愭，閹糕剝甯€
   *   閳?**濮樻瓕绻欐稉宥呭晙娑撳褰?*閿涘牅绗岄張顑跨波閸欏秴顦查煪鈺冩畱"鐠ч攱澧滅純顔炬埂/閺€璺虹啲缂冾喖浜?娑撳秵鍨氱€?閸氬奔绔存稉顏勮埌閻樿绱氶妴?
   */
  private keepScreenOnApplied: boolean | undefined = undefined;

  /** Applies the keep-screen-on switch while the playback page is visible. */
  private applyKeepScreenOn(enabled: boolean): void {
    try {
      // 閸忓牏鐣?*閻喐顒滅憰浣风瑓閸欐垹娈戦崐?*閿涘牏鏁ら幋宄颁焊婵傛垝绗屾い鐢告桨閻╅晲缍呴柈鍊燁洣濠娐ゅ喕閿涘绱濋崘宥嗗瑏鐎瑰啫浠涢獮鍌滅搼閸掋倖宓?
      // 閳跨媴绗?妞ゅ搫绨敍姘箑妞よ婀崣?UIContext 娑斿澧犻敍鍫熸￥閻ｅ奔绡冮弰顖氭躬閸?window 娑斿澧犻崗鍫熺槷 `screenOn`閿涘鈧?
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
        // 閳?閸愬懎鐪?promise 娑旂喕顩?catch閿涙瓪setWindowKeepScreenOn` 閺堫剝闊╂潻鏂挎礀 Promise閿?
        //   娑撳秵甯存担蹇撴皑閺勵垯绔存稉顏呮弓婢跺嫮鎮婇惃?rejection閿涘牆甯弶銉ㄧ箹闁插本顒滈弰顖濈箹閺嶅嚖绱氶敍宀冣偓灞肩瑬婢惰精瑙﹂弮?*韫囧懘銆忛崶鐐寸泊**閵?
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
        // 閸︺劎鍤庣亸渚€娼?URL 閳ユ柡鈧?娑撳孩鎸遍弨楣冦€夌亸渚€娼伴敍鍧凱layerViewModel.songCoverUrl()`閿?*閸氬奔绔撮弶銉︾爱**閿?
        // 缂侇參顥ｇ亸渚€娼伴幍宥勭瑝娴兼艾鍤悳?閺夆€宠埌閻線鍣烽弰顖氱殱闂堫潿鈧線顥ｆ潻鍥ㄦ降鏉╂瑥绱堕弰顖炵帛鐠併倕銇旈崓?
        return song.cover;
      }
      // 閺堫剙婀?濞屾瑧顔堢亸渚€娼伴敍姝歭abel` 閺勵垳婀″锝囨畱鐏忎線娼?Resource閿涘牅绗夐弰?`ic_avatar1`閿?
      return song.label;
    }
    return $r('app.media.ic_avatar1');
  }

  // 閳藉應妲?2026-10-15閿涘牏顑囨稉澶婂磩娑旀繆鐤?/ Round 20閿涘绱伴崢鐔峰帥閹稿倸婀潻娆撳櫡閻ㄥ嫭鏆ｅ▓?JSDoc 閹诲繗鍫惃鍕Ц `originalCoverSource()`
  //   閿涘牏顑囨稉澶婂磩娑撳啳鐤嗗鎻掑灩闂勩倧绱濈憴?RzdMusic鐠佹澘绻?md 鎼?6.13閿涘绱濋獮鏈电瑬闁氨鐦掑鏇犳暏 `backgroundImageSource()`
  //   閿涘牊婀版潪顔煎嚒閸掔娀娅庨敍澶嗗櫩 瀹稿弶妲?*鐎涖倕鍔瑰▔銊╁櫞**閿涘本鏆ｅ▓鍨閹哄鈧?
  //   閳跨媴绗?`isPixelMapCover()` **娴犲秶鍔ч崷銊ф暏**閿涘牏婀＄€圭偠鐨熼悽銊у仯閿涙瓪releaseBackgroundCoverIfPixelMap()`閿涘绱?
  //   **娑撳秷顩︾捄鐔烘絻閸?*閵?

  // 閳藉應妲?2026-10-15閿涘牏顑囨稉澶婂磩娑旀繆鐤?/ Round 20閿涘绱癭backgroundImageSource()` **瀹告彃鍨归梽?* 閳ユ柡鈧?
  //   鐎瑰啳鍤滃杈╂畱 JSDoc 鐏忓崬鍟撻弰?閸烆垯绔寸拫鍐暏閻愯妲?phoneSwiperBackdropImage閿涘矁鈧矂鍋呮稉?builder 閺堫剝闊╅弰顖涱劥娴狅絿鐖?
  //   閳?闂?`phoneSwiperBackdropImage` 娑撯偓鐠ц渹绗呯痪鍖＄礉閸忋劋绮ㄩ梿鎯扮殶閻劏鈧懌鈧?
  //   閸掔娀娅庢笟婵囧祦娑撳簼楠囬悧鈺冾儊閸欑柉鍤滃Λ鈧敍鍧dules.abc GONE閿涘顫?RzdMusic鐠佹澘绻?md 鎼?6.15閵?

  /**
   * True when value looks like a decoded PixelMap ({@link Resource} has no release).
   *
   * 閳跨媴绗?2026-10-15閿涙俺鍎楅弲顖涙暭鐎圭偞妞傚Ο锛勭ˇ閸?`imageLabel` **閹帊璐?`Resource`**閿涘牅绗夐崘宥堫潶鐠у鍨氭禒璁崇秿
   *   PixelMap閿涘鍣?閺堫剚鏌熷▔鏇炴躬鐠嬪啰鏁ら悙瑙勪航鏉╂柨娲?false閿涘苯鐤勯梽鍛嚒閹?*閸忔粌绨崇€瑰牆宕?*閵?
   *   娣囨繄鏆€娑撳秴鍨归敍姝歳eleaseBackgroundCoverIfPixelMap()` 娴犲秹娼€瑰啫鍨界猾璇茬€烽敍鍫ｅ剹閺咁垶鍋呴弶陇鐭惧鎻掓躬
   *   缁楊兛绗侀崡浣风瘈鏉烆噣娈?`backgroundImageSource()` 娑撯偓鐠ц渹绗呯痪鍖＄礉鐟?RzdMusic鐠佹澘绻?md 鎼?6.15閿涘绱?
   *   娴犮儱鎮楅懟銉︽箒娴滄椽鍣搁弬鐗堝Ω鐟欙絿鐖滅紒鎾寸亯閺€鎹愮箻 `imageLabel`閿涘矁绻栭弶鈥冲瀻閺€顖欑窗閼奉亜濮╅柌宥嗘煀閻㈢喐鏅ラ妴?
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
   * 閳跨媴绗?2026-10-15閿?*瀹歌弓绗夐崘宥勭窗閸涙垝鑵戞禒璁崇秿娑撴粏銈?*閿涘潉imageLabel` 閹帊璐?`Resource`閿涘矁顫?
   *   {@link isPixelMapCover}閿涘鈧倷琚辨稉顏囩殶閻劎鍋ｉ敍鍧刟boutToAppear` / `onDisAppear`閿涘绻氶悾娆忓斧閺嶅嚖绱?
   *   閸ョ姳璐熸潻娆愭Ц娑撯偓閺?*鐎瑰鍙忕純?*閿涙矮绔炬稉鈧禒銉ユ倵閸欏牊婀佹禍鐑樺Ω娴ｅ秴娴樻繅鐐剁箻 `imageLabel`閿涘苯鐣犳禒宥囧姧娴兼俺绀嬬拹锝夊櫞閺€淇扁偓?
   *   閳跨媴绗?閸欏秹娼伴弫娆掝唲閿涘牊婀板▎鈩冩暭閸斻劑銆庣敮锕佇掗崘宕囨畱閿涘绱版禒銉ュ閼冲本娅欑仦鍌涜閺屾挾娈?*濮濓絾妲?*鏉╂瑩鍣锋导姘愁潶闁插﹥鏂侀惃鍕亝瀵?
   *   PixelMap 閳ユ柡鈧?"閸忓牓鍣撮弨淇扁偓浣稿晙閻?`@Local` 鐟欙箑褰傞幑銏＄爱"娑擃參妫块梾鏃傛絻鐠嬪啫瀹抽敍灞界潣娴滃孩缍旈崷?use-after-free閵?
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
   * 閸忔娊妫撮崗銊ョ潌閹绢厽鏂佹い纰夌窗閸忓牊鎸遍弨鎯版崳閸斻劎鏁鹃敍鍫ｇ箻鎼?0 閳?閺€鎯版崳閿涘绱濋幘顓炵暚閸愬秵浠径宥囩崶閸?chrome 楠炶泛宓忔潪濮愨偓?
   *
   * 閳跨媴绗?閸楁瓕娴囬弨鎯ф躬**鐎规碍妞傞崳?*闁插矁鈧奔绗夐弰?`animateTo` 閻ㄥ嫬鐣幋鎰礀鐠嬪喛绱伴柇锝勯嚋閸ョ偠鐨熼崷銊╁劥閸掑棗婧€閺咁垯绗夋穱婵婄槈鐟欙箑褰傞敍?
   * 闂堢姴鐣犻崡姝屾祰鐏忓彉绱伴崣妯诲灇"鏉╂柨娲栭柨顔藉瘻娴滃棙鐥呴崣宥呯安"閵嗗倸鐣鹃弮璺烘珤閹稿妞傞梹鍨幑鎼存洩绱濋張鈧崸蹇斿剰閸愰潧褰ч弰顖涙暪鐠у嘲濮╅悽鏄忣潶鐠哄疇绻冮敍?
   * 閸忔娊妫存稉鈧€规矮绱伴崣鎴犳晸閵?
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
   * 閳藉應妲勯埥鍛 2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MainPage.closeWithAnimation()`閿涘畭wujie.pa:171054-171095`閿涘绱?
   * **闂堢偞澧滈崝鍨彠闂?*閿涘牆鍙ч梻顓熷瘻闁?/ 缁崵绮烘潻鏂挎礀閿涘鈧柡鈧?缂傗晝娈?*娑撳秵妲稿ú濠氥€夐棃?*閿涘矁鈧本妲?*娑撯偓瀵姵寮х粣妤€鎻╅悡?*閵?
   *
   * ## 閺冪姷鏅惃鍕斧閺傚洤鑸伴悩?
   * ```
   *   closeWithAnimation() {
   *     if (pullMode && ExpandSnapshot.onReverseMorph(myMorphSnap)) return;   // 閳?娑撳濯洪柇锝嗘蒋鐠侯垽绱伴懛顏勭箒婢跺嫮鎮?
   *     getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 浣岪1*#);     // 閳?閸氾箑鍨敍姘韫囶偆鍙?
   *   }
   *   浣岪1*#閿涘澋ujie.pa:181020-181077閿涘绱?
   *     婢惰精瑙?閳?hilog.warn('root snapshot failed, fallback: 閳?) + nav.pop()    閿涘牊妫ら崣?= 娑撳秴鐢潪顒€婧€閿?
   *     閹存劕濮?閳?ExpandSnapshot.onShrinkBack(pixmap, this.mySrcBox) + nav.pop(false)
   *   onShrinkBack 閳?ShrinkOverlay.start(閳?     閳?閺堫兛绮ㄩ惃?MorphShrinkState
   * ```
   *
   * ## 娑撹桨绮堟稊鍫ｎ洣閻撗勬儔閿涘牏鏁ら幋椋庮儑 閳?閺壜扳偓灞炬箒閼冲本娅欐担鍡樻Ц妤傛ê瀹抽悧閫涚秵閵嗗稄绱?
   * 閹存垳婊戞稉鈧惄瀛樻Ц"閸斻劍妞块惃鍕尡閺€楣冦€?閿涘牊鏁肩憗浣稿缁愭褰?+ 缂傗晜鏂侀敍澶嗗櫩 閸欘亣顩︽稉銈堚偓鍛瑝閸氬本顒為敍灞界潌娑撳﹤姘ㄩ弰?
   * "閺堝鍎楅弲顖樷偓浣风稻閸欘亜澧垮鍫㈢叝閻ㄥ嫪绔撮弶?閵嗗倽鈧?*缂傗晙绔村鐘叉禈**閺冩儼鍎楅弲顖欑瑢鐏忎線娼?*閸氬本鐦笟?*閿涘矂鍋呯粔宥呰埌閻樻湹绗夐崣顖濆厴閸戣櫣骞囬妴?
   *   閳跨媴绗?娑撳濯洪柇锝嗘蒋鐠?*娣囨繄鏆€**濞插銆夎ぐ銏犲綁閿涘牊妫ら悾宀€娈?`onReverseMorph` 鐏忚鲸妲哥€瑰喛绱氶垾鏂衡偓?
   *     閻劍鍩涘鑼€樼拋銈冣偓灞告喗娑撳﹥濯洪幍鎾崇磻/娑撳濯洪崗鎶芥４閻ㄥ嫬鐨濋棃?閼冲本娅欓崝銊ф暰濮濓絽鐖堕妴宥忕礉娑撳秴濮╃€瑰啨鈧?
   *
   * ## 閺堫兛绮ㄩ惃鍕Ё鐏?
   * ```
   *   閺冪姷鏅?pullMode            閳劏鍟?閺堫剙顦?閺勵垯绗夐弰顖欑矤娑撳濯洪柇锝嗘蒋鐠侯垱娼甸惃?閿涙碍婀伴弬瑙勭《**閸欘亣顫﹂棃鐐村閸斿灝鍙嗛崣锝堢殶閻?*
   *                                 閿涘牐顫?`onCollapseRequested`閿涘绱濋幍鈧禒銉ㄧ箻閺夈儱姘ㄩ弰?閳?閺€顖樷偓?
   *   閺冪姷鏅?PLAYER_ROOT_ID      閳劏鍟?閺堫剟銆夎ぐ銏犲綁鐎圭懓娅掓稉濠勬畱 `.id(PLAYER_ROOT_ID)`閿涘牏鍙庨幖顒€鎮撴稉鈧担宥囩枂閿?
   *   閺冪姷鏅?mySrcBox            閳劏鍟?`expandState.barWinX/Y/W/H`閿涘牐绯犳担鐘虫蒋閼宠泛娉惃鍕崶閸欙絿鐓╄ぐ顫礉vp閿?
   *   閺冪姷鏅?nav.pop(false)      閳劏鍟?`state.isShowPlay = false`閿涘牆锛撶仦?`popPlayerRoute()` 閻劎娈戦弰?
   *                                 `pageIndexInfos.pop(false)` 閳?閺堫剙姘?*娑撳秴鐢潪顒€婧€**閿?
   *   閺冪姷鏅径杈Е閺€?nav.pop()     閳劏鍟?閸氬本鐗辩純?`isShowPlay = false`閿涘牊鍨滄禒顒傛畱 pop 閹帗妫ゆ潪顒€婧€ 閳?缁涘鐜敍?
   * ```
   *
   * 閳跨媴绗?`mySrcBox`閿涘牐鍏岄崶濠勭叐瑜邦澁绱?*閸欘亜婀ぐ銏犲綁娴兼俺鐦藉铏圭彌閺冨爼鍣洪崚?*閿涘潉reportMini` 閳?`barWin*`閿涘鈧?
   *   闁插繋绗夐崚鐗堟 `MorphShrinkState.start` 娴兼俺铔嬮弮鐘垫櫕闁絾娼?`start skipped: no srcBox` 閺€?
   *   閿涘潉visible=false` + `onDone()`閿涘鍣?闁偓閸栨牗鍨?閺冪姴濮╅悽璇插彠闂?閿?*娑撳孩妫ら悾宀€娈戦柅鈧崠鏍熅瀵板嫪绔撮懛?*閵?
   *   閹烘帗鐓￠崗鎶芥暛鐎涙绱癭RzdShrinkOverlay` / `root snapshot failed`閵?
   */
  private closeWithAnimation(): void {
    if (this.isClosing) {
      return;
    }
    const winW: number = this.expandState.windowWidthVp;
    const winH: number = this.expandState.windowHeightVp;
    // 閳藉應妲勯埥?2026-10-17閿?*韫囧懘銆忛悳浼村櫤娑撯偓濞喡ゅ厡閸ュ﹦鐓╄ぐ?* 閳ユ柡鈧?鏉╂瑦妲?鏉╂柨娲栭崗鎶芥４娴兼矮绗夋导姘綁閹存劖妫ら崝銊ф暰"閻ㄥ嫬绱戦崗绛圭礆閿?
    //   `barWinX/Y/W/H` 閻?`measureGeometry()` 閸愭瑱绱濋懓灞界暊**閸欘亜婀稉銈咁槱**鐞氼偉鐨熼悽顭掔窗
    //     璺?閸氬嫭娼?opening 鐠侯垰绶為惃鍕夐柌蹇ョ礄`measureMiniDuringPull` 閸愬懘鍎撮柇锝嗘蒋闁炬拝绱氶敍?
    //     璺?**`refreshCollapseGeometry()`**閿涘牊妫崗鎶芥４鐠侯垰绶為崷銊ㄦ崳閹靛妞傞悳浼村櫤娑撯偓濞嗏槄绱氶妴?
    //   閳?閼汇儲婀伴弶陇鐭炬稉?`barWin*` 娴犲秳璐?0閿涘牅绶ユ俊鍌涘ⅵ瀵偓鐠ф壆娈戦弰顖炩偓鈧崠鏍熅瀵板嫨鈧椒绮犲▽锟犲櫤閸掓媽绻冮敍澶涚礉
    //     `MorphShrinkState.start()` 娴兼俺铔嬮弮鐘垫櫕闁絾娼?`start skipped: no srcBox` 閺€?
    //     閳?**鏉╂柨娲栭崗鎶芥４閸欐ɑ鍨?閺冪姴濮╅悽鑽ゆ纯閹恒儲绉锋径?**閿涘牓鍋呴弰顖氬讲鐟欎礁娲栬ぐ鎺炵礉娑撳秵妲?濞屸€叉叏婵?闁絼绠炴潪浼欑礆閵?
    //   閳跨媴绗?鏉╂瑩鍣?*閻╁瓨甯寸拫?`measureGeometry`**閿涘奔绗夐悽銊︽＋閻?`refreshCollapseGeometry()` 閳ユ柡鈧?
    //      閸氬氦鈧懓鍤滅敮?`morphStage === OPEN` 闂傤煉绱欓柅鈧崠鏍ㄥⅵ瀵偓閺冩湹绱伴弰?LANDING/NONE 閳?娴犫偓娑斿牓鍏樻稉宥夊櫤閿涘绱?
    //      閼板苯鎻╅悡褑鐭惧?*閸欘亪娓剁憰浣藉厡閸ュ﹦鐓╄ぐ?*閿涘牊妫惃?`morphInitParams`/`freezeMorphMeta` 閺勵垳绮?
    //      濞插銆夌悰銉╂？閻劎娈戦敍灞炬拱鐠侯垰绶炴稉宥夋付鐟曚緤绱氶妴?
    const measured: boolean = this.expandState.measureGeometry(this.getUIContext(), true, true);
    const srcBox: MorphShrinkRect = {
      left: this.expandState.barWinX,
      top: this.expandState.barWinY,
      width: this.expandState.barWinW,
      height: this.expandState.barWinH
    };
    // 閸忚櫕鎸遍弨鎯ф珤鏉╂瑤绔存稉瀣╃瑝鐟曚礁鍟€閼奉亜濮╅弨鑸靛付閸掕泛灏敍鍫滅瑢 closeFullScreenPlayback 閸氬奔绔撮弶鈽呯礆
    this.stopChromeAutoHide();
    this.isClosing = true;
    PlaybackPage.lastCloseAtMs = Date.now();
    // 閳藉應妲勯埥?2026-10-17閿?*韫囶偆鍙庣捄顖氱窞閸欘垳鏁ら幀褔顣╁Λ鈧?* 閳ユ柡鈧?鐟?`closeLiveMorphFallback` 閻ㄥ嫬鍨庡褑顕╅弰搴礆
    //   娑撱倓閲滈崜宥嗗絹閿涙埃鎲?閼宠泛娉惌鈺佽埌閿涘潉srcBox`閿涘鍣洪崚棰佺啊閿涙稈鎲?缁愭褰涚亸鍝勵嚟閺堝鈧》绱檂MorphShrinkState.start`
    //   閻ㄥ嫪琚辩粩顖氬彆瀵繘鍏橀崥鍐ㄧ暊閿涘鈧倷鎹㈡稉鈧稉宥嗗灇缁斿姘ㄩ惄瀛樺复鐠т即鈧偓閸栨牞鐭惧鍕剁礉**娑撳秴骞撻幏宥夊亝瀵姵鏁炵€规碍鐥呴悽銊ф畱韫囶偆鍙?*閵?
    if (srcBox.width <= 0 || srcBox.height <= 0 || winW <= 0 || winH <= 0) {
      this.closeLiveMorphFallback(
        `noSrcBox meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
        `win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      return;
    }
    PlaybackPage.ev('CLO', `snapshot p=${this.expandState.morphP.toFixed(2)} ` +
      `meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
      // ★ 2026-10-17（"有时候两个封面"要能一次判读）：把"谁在画封面"三个量记进事件日志。
      //   `rc` = 播放页真封面在画、`oc` = 壳层克隆层在画、`ss` = 这一关归快照。
      //   快照成功的正常态应当是 `rc=1 oc=0 ss=1`；若出现 `oc=1` ⇒ 快照门被绕过了。
      `rc=${this.expandState.realCoverVisible() ? 1 : 0} ` +
      `oc=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
      `ss=${this.expandState.snapshotShrinkOwnedFlag() ? 1 : 0} ` +
      `tint=${this.tintReady ? 1 : 0}`);
    Logger.info(PlaybackPage.logTag,
      `RzdShrinkOverlay closeWithAnimation: snapshot ${PLAYER_ROOT_ID} ` +
      `win=${winW.toFixed(0)}x${winH.toFixed(0)} ` +
      `bar=(${srcBox.left.toFixed(1)},${srcBox.top.toFixed(1)},` +
      `${srcBox.width.toFixed(1)}x${srcBox.height.toFixed(1)})`);
    // 閳跨媴绗?韫囶偆鍙庤箛鍛淬€忛崷?*瑜般垹褰夊鈧慨瀣╃閸?*閹峰稄绱板銈呭煝鐎圭懓娅掗弰顖涗航缁涘褰夐幑顫礄濠娾€崇潌閿涘绱濋幏宥呭煂閻ㄥ嫭澧犻弰?濠娾€崇潌闁絼绔村?閵?
    //   閳跨媴绗嶉埧鐙呯瑣 `restorePlaybackWindowChrome()` **娑撳秷鍏?*閺€鎯ф躬閹峰秴鎻╅悡褌绠ｉ崜?閳ユ柡鈧?鐎瑰啩绱伴幁銏狀槻缁愭褰涚敮鍐ㄧ湰
    //     閿涘潉applyPlaybackWindowChrome(false,閳?`閿涘本婀版い鍦窗閸︺劍鎸遍弨楣冦€夋导姘Ω缁愭褰涢柧鍝勫煂閺佸鐛ラ敍澶涚礉
    //     鐢啫鐪稉鈧崣姗堢礉閹峰秴鍩岄惃鍕皑娑撳秵妲?濠婏紕鐛ラ柇锝勭瀵?閵嗗倷绗岄弮褑鐭惧鍕閼疯揪绱?*閺€璺虹啲閺冭埖澧犻幁銏狀槻**閵?
    // 閳跨媴绗嶉埧鐙呯瑣 2026-10-17閿?*閻劍鍩涢幋顏勬禈閺嗘挳婀堕惃鍕埂 bug**閿涙矮绨ㄦ禒鑸垫）韫?`CLO:閳?fb=snapFail` 閳?韫囶偆鍙?*濮ｅ繑顐奸柈钘夈亼鐠?*閿?
    //   娴滃孩妲稿В蹇庣濞喡ょ箲閸ョ偛鍙ч梻顓㈠厴闁偓閸栨牕鍩屽ú濠氥€夎ぐ銏犲綁 閳?**閻劍鍩涙禒搴㈡降濞岋紕婀呴崚鎷岀箖閺冪姷鏅柇锝嗘蒋韫囶偆鍙庨弨鍓佺級**閿?
    //   娴犳牗濮ら惃?鐏忎線娼伴崪宀冨剹閺咁垵绻曢弰顖欑濡€茬閺嶉娈戦梻顕€顣?鐏忚鲸妲告潻娆庨嚋閿涘鈧?
    //   閺嶇懓娲滈敍?*閹存垳婊戠拫鍐畱閺勵垰鍙忕仦鈧柇锝勯嚋瀹告彃绨惧鍐畱闁插秷娴?*閵嗕繖@ohos.arkui.componentSnapshot.d.ts`
    //   `function get(id, callback, options?)` 閺嶅洨娼?**`@deprecated since 18`**閵嗕椒绗栨导姘
    //   `100001 - Invalid ID`閿涙稖鈧?*娑撳﹥鐖堕悽銊ф畱閺?`UIContext` 闁絼绔撮弨?*閿?
    //   `wujie.pa:171077-171093`閿涘潉PlayerPage.closeWithAnimation` 閻?浣嶉敍澶愨偓鎰蒋鐟欙絽鍤弶銉︻劀閺?
    //   ```ts
    //     this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 浣岪1*#)
    //   ```
    //   閳?閻滄澘婀悡褌绗傚〒鎼佸亝娑撯偓閺夆剝鏁奸崘娆欑礄閺堫剚鏋冩禒?L3464 閻ㄥ嫭鏁為柌濠囧櫡**閺冣晛姘ㄩ崘娆戞絻**鏉╂瑤閲滆ぐ銏㈠Ц閿涘奔鍞惍浣稿祱濞屄ょ娑撳绱氶妴?
    //   閳?婢惰精瑙﹂崢鐔锋礈閻撗勬＋鏉╂稐绨ㄦ禒鑸垫）韫囨绱濋獮?*閹?err.code 娑旂喎鐢稉?*閿涘潉fb=snapFail(100001)`閿涘绱?
    //     401 = 閸欏倹鏆熼柨?/ 100001 = 閹靛彞绗夐崚鎷岀箹娑?id 閳?娑撯偓濞嗏剝鍩呴崶鎯у祮閸欘垰鐣剧拋鎭掆偓?
    this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID,
      (err: BusinessError, pixmap: image.PixelMap): void => {
      // 閳光偓閳光偓 閹绘劒姘﹂崗鎶芥４閺冨墎娈?*閺堫兛绮ㄩ悧瑙勬箒閺€璺虹啲**閿涘牊妫ら悾灞剧梾閺?濞屽韫堢粣妤€褰?鏉╂瑥顨滈敍灞惧娴犮儱鐣犲▽鈩冩箒鏉╂瑤琚遍崣銉礆
      //   閳?閹垹顦茬化鑽ょ埠閺?缁愭褰?chrome 閳ユ柡鈧?娑撳秵浠径宥囨畱鐠囨繆绻戦崶鐐插彠闂傤厺绠ｉ崥搴ㄣ€婇弽蹇庣窗閸嬫粌婀?閹绢厽鏂佹い鍨焽濞?闁絼绔存總妤呭帳閼硅绱?
      //   閳?`morphLand()` 娴溿倛绻曠紒妯哄煑閺?閳?鏉╄渹缍橀弶?*閻喕闊?*缁斿鍩㈤弰鎯у毉閺?
      //      閿涘牅绗夋禍銈堢箷閻ㄥ嫯鐦界憰浣虹搼濞搭喖鐪板ǎ鈥冲毉 閳?50ms 娑斿鎮楅幍宥囨箙閸掓媽绯犳担鐘虫蒋"閸?閸︽澘鍤悳甯礆閵?
      //   閳跨媴绗?`morphLand()` 閹跺﹦娴夋担宥囩枂 `LANDING`閿涘奔绲惧銈呭煝 `morphP = 1`閿涘牆鍨?`refreshCollapseGeometry`
      //      閸掔柉绻冮敍澶嗗櫩 鐎圭懓娅?`.height(morphClipHeight)` = 閺佸鐛ラ妴涔cale = 1` = **閹帞鐡?*
      //      閳?闂嗘儼顫囬幇鐔峰綁閸栨牭绱辨担鏇炲枌闁?1~2 鐢傜瑐闂堛垼绻曢惄鏍絻娑撳秹鈧繑妲戦惃鍕彥閻撗勮癁鐏炲倶鈧?
      //   閳跨媴绗?**婢惰精瑙﹂弨顖欑瑝鏉╂稖绻栨稉鈧€?*閿涘牆鐣犵憰浣借泲闁偓閸栨牞鐭惧鍕剁礉闁絾妞?`morphLand()` 娴兼碍濡搁惄闀愮秴閹绘劕澧犵紙缁樺竴閿?
      //      閼?`closeFullScreenPlayback()` 闂団偓鐟曚椒绮?鏉╂ê婀仦鏇炵磻閹?鐠ч攱澧滈敍澶嗗櫩 鐟欎椒绗呴棃?`if` 閻ㄥ嫪缍呯純顔衡偓?
      if (err !== null && err !== undefined) {
        Logger.warn(PlaybackPage.logTag,
          'RzdShrinkOverlay root snapshot failed, fallback: ' + JSON.stringify(err));
        // 閳藉應妲勯埥?2026-10-17閿?*閺堫兛绮ㄩ崚缁樺壈閻ㄥ嫬鍨庡褏鍋?*閿涘绱伴弮鐘垫櫕閻ㄥ嫬銇戠拹銉︽暜閺?`nav.pop()`閿涘牊妫ゆ潪顒€婧€閿涘绱?
        //   閹存垳婊戞潻娆撳櫡闁偓閸?*閺堫兛绮ㄩ弮銏℃箒閻ㄥ嫭妞挎い闈涜埌閸?*閿涘潉closeFullScreenPlayback()`閿涘鈧倻鎮婇悽鎲嬬窗
        //   璺?閺冪姷鏅幏宥囨畱閺?`PLAYER_ROOT_ID`閿涘牅绔存稉顏呮珮闁?Stack閿涘绱遍幋鎴滄粦閹峰秶娈戦弰?**`NavDestination(DIALOG)`
        //     闁插瞼娈戦懞鍌滃仯**閿涘矁绻栭弶鈩冭閺屾捁鐭惧鍕Ц**閹存垳婊戦悧瑙勬箒閻?* 閳?娑撯偓閺?`componentSnapshot` 閸︺劏绻栭弶陇鐭炬稉?
        //     缁崵绮洪幀褍褰囨稉宥呭煂閸ユ拝绱?*濮ｅ繋绔村▎陇绻戦崶鐐插彠闂?*闁垝绱伴柅鈧崠鏍ㄥ灇"妞ょ敻娼伴惄瀛樺复濞戝牆銇? 閳ユ柡鈧?
        //     闁絾妲稿В?閼冲本娅欓崣顏勫⒖娑撯偓閺?娑撱儵鍣稿妤€顦块惃鍕讲鐟欎礁娲栬ぐ鎺炵幢
        //   璺?濞插銆夎ぐ銏犲綁閺堫剝闊╅弰?*瀹歌尪顫﹂悽銊﹀煕绾喛顓婚崣顖滄暏**閻ㄥ嫰鍋呮稉鈧總妤嬬礄閳堵扳偓灞肩瑐閹峰澧﹀鈧?娑撳濯洪崗鎶芥４閻ㄥ嫬鐨濋棃?閼冲本娅欓崝銊ф暰濮濓絽鐖堕妴宥忕礆閿?
        //     闁偓閸ョ偛骞撻張鈧崸蹇庣瘍閸欘亝妲搁崶鐐插煂閸樼喐娼甸惃鍕潎閹扮喓鎲伴悿鐐光偓?
        //   閳跨媴绗?婢惰精瑙﹂崢鐔锋礈閻撗勬＋閹?`Logger.warn`閿涘苯鑻熼幎濠傚斧閸ョ姴鐢潻娑楃皑娴犺埖妫╄箛妤嬬礄`CLO` 閻?`fb=`閿涘绱?
        //     **娑撯偓濞嗏剝鍩呴崶鎯у祮閸欘垰鍨界拠?*閿涘牐顫?`closeFallbackReason`閿涘鈧?
        this.closeLiveMorphFallback(`snapFail(${err.code})`);
        return;
      }
      this.restorePlaybackWindowChrome();
      // 閳藉應妲勯埥鍛 2026-10-17閿?*娣囶喚鏁ら幋宄扮杽濞村鈧苯鍙ч梻顓熸娴兼艾鍤悳棰佽⒈娑擃亜鐨濋棃顫偓?*閿?
      //   韫囶偆鍙庡鑼病閹峰秴鍩屾禍鍡楃殱闂堫澁绱濋懓灞肩瑓闂?`morphLand()` 娴兼碍濡搁惄闀愮秴缂冾喗鍨?`LANDING`
      //   閳ユ柡鈧?`LANDING` 閸?`morphContainerActive()` 闁插瞼鐣?閻喓娈戦崷銊︽尡" 閳?婢瑰啿鐪伴崗瀣畷鐏炲倷绱扮悮顐﹀亝閺?
      //   閻╅晲缍呴崗婊冪俺閸欘偉鎹ｉ弶?閳?**韫囶偆鍙庨柌宀勫亝瀵姴鐨濋棃?+ 閸忓娈曠仦鍌炲亝瀵姴鐨濋棃銏犳倱閺冨爼顥?* = 娑撱倓閲滅亸渚€娼伴妴?
      //   閳?閸?`morphLand()` **娑斿澧?*婢圭増妲?鏉╂瑤绔撮崗鍐茬秺韫囶偆鍙?閿涘本璇炵仦鍌炴，閿涘潉morphOverlayBridging`閿?
      //     闂呭繐鎮楅幁鎺戜海閵嗗偊绱欓崣顏勬躬韫囶偆鍙庨幋鎰鏉╂瑤绔撮弨顖氾紣閺勫函绱辨径杈Е閺€顖濐洣闁偓閸ョ偞妞挎い闈涜埌閸欐﹫绱濇禒宥夋付鐟曚焦璇炵仦鍌樷偓鍌︾礆
      this.expandState.beginSnapshotShrink();
      // 閳藉應妲勯埥鍛 2026-10-17閿涘牏鏁ら幋宄扮杽濞村鈧?*缁崵绮烘潻鏂挎礀閸忔娊妫撮幘顓熸杹閸ｎ煉绱濋幘顓熸杹閺夛繝鍋呮稉澶夐嚋閹稿鎸抽崙铏瑰箛閻ㄥ嫭婀侀悙瑙勬－娴?*閵嗗稄绱?
      //   閸樼喐娼垫潻娆撳櫡**缁斿鍩?* `morphLand()` 閳ユ柡鈧?闁絾妲?娴溿倛绻曠紒妯哄煑閺?閳?鏉╄渹缍橀弶锛勬埂闊偅妯夐崙鐑樻降"闁絼绔村銉礉
      //   娴滃孩妲歌箛顐ゅ弾鏉╂ɑ鐥呯紓鈺佺暚閿涘牃澧?50ms閿涘绱濇惔鏇氱瑓閻ㄥ嫯绯犳担鐘虫蒋閿涘牆鎯堥柇锝勭瑏娑擃亝瀵滈柦顕嗙礆鐏忓崬鍑＄紒蹇涙苟閸戠儤娼垫禍?
      //   閳?鐟欏倹鍔?閹稿鎸抽崗鍫濆毉閻滆埇鈧礁鐨濋棃銏犳倵閽€鎴掔秴"閵?
      //   閳?閹割亜鍩岄弨鍓佺級**缂佹挻娼?*閿涘潉shrink.start` 閻?onDone閿涘矁顫嗘稉瀣剁礆閵嗗倽绻栨稉鈧捄顖欑瑐閻╅晲缍呮穱婵囧瘮 ENTERING/LEAVING閿?
      //     `realCoverVisible()` 娑旂喎娲滃銈囨埛缂侇叀顔€娴ｅ稄绱濇稉宥勭窗閸愬秴鍟嬮崙铏诡儑娴滃苯绱剁亸渚€娼伴妴?
      //   閳跨媴绗?`morphLand()` 閸欘亜澧?閻╅晲缍?閳?LANDING + 娴溿倛绻曠紒妯哄煑閺?娑撱倓娆㈡禍瀣剁礉閺?350ms 鐠嬪啯鐥呴張澶婂娴ｆ粎鏁ら妴?
      const shrink: MorphShrinkState = this.morphShrinkState();
      shrink.start(this.getUIContext(), pixmap, srcBox, winW, winH, (): void => {
        // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖?`MainPage` 闁絼閲?**onDone 浣岪12*#**閿涘畭wujie.pa:154940-154949`閿涘绱?
        // ```ts
        //   () => { this.miniHidden = false; this.shrinkPixmap = undefined; }
        // ```
        //   璺?`miniHidden = false` 閳ユ柡鈧?閺堫兛绮ㄧ€电懓绨查惃鍕Ц"鏉╄渹缍橀弶?*閻喕闊?*閸欘垵顫?閿?
        //     鐏忚鲸妲?`morphLand()`閿涘牅姘︽潻妯肩帛閸掕埖娼堥敍澶堚偓?*鐎瑰啫绻€妞よ婀弨鍓佺級缂佹挻娼潻娆庣閸?*閿涘矁顫嗘稉濠囨桨閻ㄥ嫯顕╅弰搴幢
        //   璺?`shrinkPixmap = undefined` 閳ユ柡鈧?閳?**韫囧懘銆忛崑?*閿涙岸鍋呴弰顖欑瀵?*濠婏紕鐛?* PixelMap
        //     閿?080鑴?400鑴?B 閳?10MB 缁狙嶇礆閿涘苯鍙℃禍顐ゅЦ閹椒绔撮惄鏉戠穿閻劎娼冪€瑰啫姘ㄦ稉宥勭窗鐞氼偄娲栭弨韬测偓?
        //     娑撳﹣绔撮悧?*濠曞繋绨℃潻娆庣閸?* 閳?濮ｅ繐鍙ф稉鈧▎鈩冩尡閺€鎯ф珤鐏忓崬顦块悾娆庣瀵媴绱欓惄鏉戝煂娑撳绔村▎鈥冲彠闂傤厽澧犵悮顐ヮ洬閻╂牭绱氶妴?
        Logger.info(PlaybackPage.logTag, 'RzdShrinkOverlay onDone (overlay hidden, pixmap dropped)');
        // 鉀?2026-10-17锛?*涓嶅啀鍦ㄨ繖閲?`morphLand()`** 鈥斺€?淇敤鎴峰疄娴?
        //   銆岀敤绯荤粺杩斿洖鍏抽棴锛屽姩鐢荤粨鏉熺殑鏃跺€欒儗鏅仠鍦ㄦ湰鏉ョ殑棰滆壊锛岀劧鍚?*绐佺劧鍙樻垚鐏拌壊**銆嶏級
        //   鍘熷洜锛歚morphLand()` 鎶婄浉浣嶇疆鎴?`LANDING` 鈬?`morphContainerActive()` 浠嶄负鐪?
        //   鈬?褰㈠彉瀹瑰櫒缁х画琚?`morphClipHeight()` 瑁佹垚涓€鏉°€乣MeshCoverBg` 閭ｄ竴灞傝窡鐫€琚鎺?閲嶅缓
        //   鈬?闇插嚭瀹夸富鐨勪笉閫忔槑搴曞骇鑹诧紙`defaultImageBgColor` = 娣辩伆锛? 鐢ㄦ埛鐪嬪埌鐨?绐佺劧鍙樼伆"銆?
        //   涓婃父閭ｄ釜 `onDone 位`锛坄wujie.pa:154940-154949`锛夊彧鍋氫袱浠朵簨锛?
        //   `miniHidden = false` + `shrinkPixmap = undefined` 鈥斺€?**娌℃湁**"鎶婃椿椤靛浣?杩欎竴姝ワ紝
        //   鍥犱负瀹冪殑椤甸潰鍦ㄥ揩鐓ц捣鏉ョ殑鍚屼竴鍒诲氨宸茬粡 pop 鎺変簡銆?
        //   鈬?杩欓噷鍚屾牱鍙竻 pixmap锛涚浉浣?鍑犱綍鐨勫浣嶄氦缁?`onDisappear 鈫?morphReset()`
        //     锛堥偅鏄細璇濆敮涓€鐨勫浣嶇偣锛岃 `morphReset` 鐨勬敞閲婏級銆?
        shrink.clearPixmap();
        // 濞搭喖鐪伴弨璺虹啲閿涘牃澧?50ms閿涘绠ｉ崥搴″晙閺€鎯х磻闂傛悂妫敍姘劀鐢瓕鐭惧鍕瑓闁絾妞傛い鐢告桨閺冣晛鍑＄悮?pop閿?
        // 鏉╂瑤绔撮崣銉ュ涧閺?娑撳洣绔村▽?pop 閹?閻ㄥ嫯鍤滈幇鍫礄閸氬苯銇戠拹銉︽暜閻ㄥ嫮鎮婇悽鎲嬬礆閵?
        this.isClosing = false;
      });
      PlaybackPage.ev('SQZ', `shrink win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      this.state.isShowPlay = false;
    });
  }

  /** 閸欐牕绶遍崗鍙橀煩閻ㄥ嫬鎻╅悡褎鏁圭紓鈺冨Ц閹緤绱欐稉搴★紦鐏?`Index` 閸氬奔绔存稉?AppStorageV2 鐎圭偘绶ラ敍澶堚偓?*/
  private morphShrinkState(): MorphShrinkState {
    return AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
  }

  /**
   * 閳藉應妲勯埥?2026-10-17閿涙艾鎻╅悡褑鐭惧鍕瑝閸欘垳鏁ら弮鍓佹畱**闁偓閸栨牕鍤崣?* 閳ユ柡鈧?闁偓閸ョ偞婀版禒鎾存＆閺堝娈?濞插銆夎ぐ銏犲綁"閸忔娊妫撮妴?
   *
   * ## 鏉╂瑦妲告稉搴㈡￥閻ｅ瞼娈?*娑撯偓婢跺嫬鍩㈤幇蹇撳瀻濮?*閿涘牐顔囬崷銊︻攳閿涘苯鍩嗛崘宥呯秼娴?濞岋紕鍙庨幖?閿?
   * 閺冪姷鏅?`浣岪1*#`閿涘潉wujie.pa:181020-181077`閿涘婀箛顐ゅ弾婢惰精瑙﹂弮鑸垫Ц `nav.pop()`閿?*閺冪姴寮?= 娑撳秴鐢潪顒€婧€**閿涘绱?
   * 娑旂喎姘ㄩ弰?妞ょ敻娼伴惄瀛樺复濞戝牆銇?閵嗗倹鍨滄禒?*娑?*閻撗勬儔闁絼绔撮弶鈽呯礉閻炲棛鏁辨稉銈嗘蒋閿?
   * 1. 閹峰秶娈戠€电钖勬稉宥呮倱閿涙碍妫ら悾灞惧 `PLAYER_ROOT_ID`閿涘牅绔存稉顏呮珮闁?`Stack`閿涘绱濋幋鎴滄粦閹峰秶娈戦弰?
   *    **`NavDestination(DIALOG)` 闁插瞼娈戦懞鍌滃仯** 閳ユ柡鈧?鏉╂瑦娼〒鍙夌厠鐠侯垰绶?*閺勵垱鍨滄禒顒傚閺堝娈?*閿?
   *    娑撯偓閺?`componentSnapshot` 閸︺劏绻栭弶陇鐭炬稉濠勯兇缂佺喐鈧冨絿娑撳秴鍩岄崶鎾呯礉**濮ｅ繋绔村▎陇绻戦崶鐐插彠闂?*闁垝绱伴柅鈧崠鏍ㄥ灇
   *    "妞ょ敻娼伴惄瀛樺复濞戝牆銇?閿涘矂鍋呴弰?*濮?閼冲本娅欓崣顏勫⒖娑撯偓閺?娑撱儵鍣稿妤€顦?*閻ㄥ嫬褰茬憴浣告礀瑜版帪绱?
   * 2. 濞插銆夎ぐ銏犲綁閺?*閻劍鍩涘鑼€樼拋銈呭讲閻?*閻ㄥ嫰鍋呮稉鈧總妤嬬礄绾喛顓诲〒鍛礋 閳堵扳偓灞肩瑐閹峰澧﹀鈧?娑撳濯洪崗鎶芥４閻ㄥ嫬鐨濋棃?閼冲本娅欓崝銊ф暰濮濓絽鐖堕妴宥忕礆閿?
   *    闁偓閸ョ偛骞撻張鈧崸蹇庣瘍閸欘亝妲搁崶鐐插煂閸樼喐娼甸柇锝囧仯鐟欏倹鍔呴悷鏇犳煏閵?
   *
   * ## 鐟欙箑褰傞弶鈥叉閿涘牅琚辨径鍕殶閻劎鍋ｉ敍?
   * 璺?`closeWithAnimation()` 閻?*妫板嫭顥?*閿涙俺鍏岄崶濠勭叐瑜?/ 缁愭褰涚亸鍝勵嚟娴犺绔存稉宥呭讲閻㈩煉绱檂bar=0x0`閿涘绱?
   *   濮濄倖妞傛潻鐐叉彥閻撗囧厴娑撳秴骞撻幏宥忕礄閹峰秳绨℃稊鐔哥梾閻㈩煉绱氶敍?
   * 璺?韫囶偆鍙庨崶鐐剁殶閻?*婢惰精瑙﹂弨?*閿涘潉err` 闂堢偟鈹栭敍澶堚偓?
   *
   * ## 閸欘垵顕伴幀?
   * 閸樼喎娲滈崘娆掔箻闂堟瑦鈧?`closeFallbackReason`閿涘瞼鏁?`closeFullScreenPlayback()` 閻?`ev('CLO', 閳?`
   * 娑撯偓鐠ч攱澧︽潻娑楃皑娴犺埖妫╄箛妤嬬礄瀵拌姤鐖ｇ粭顒€宕勬稉澶庮攽閻?`fb=`閿涘鍣?**娑撯偓濞嗏剝鍩呴崶鎯ф皑閼崇晫婀呴崙楦胯泲濞屄よ泲闁偓閸?*閵?
   * @param reason 闁偓閸栨牕甯崶鐙呯礄閻厽鐖ｇ粵鎾呯礉娴兼俺绻樻禍瀣╂閺冦儱绻旈敍?
   */
  private closeLiveMorphFallback(reason: string): void {
    Logger.warn(PlaybackPage.logTag,
      `RzdShrinkOverlay fallback 閳?live morph (${reason})`);
    PlaybackPage.closeFallbackReason = reason;
    // `closeFullScreenPlayback()` 閻ㄥ嫮顑囨稉鈧柆鎾绘鐏忚鲸妲?`isClosing`閿涘苯绻€妞ょ粯鏂佸鈧幍宥堢箻瀵版骞撻妴?
    this.isClosing = false;
    this.closeFullScreenPlayback();
  }

  private closeFullScreenPlayback(): void {
    if (this.isClosing) {
      return;
    }
    // 閳藉應妲勯埥?2026-10-16閿?*缂?閸忔娊妫存担娆愬皾缁愭褰?閻╂牜鐝?閳ユ柡鈧?鏉╂瑤绔寸悰灞炬Ц娑撳﹣绔存潪顔界础閹哄娈?*閿?
    //   鐟?`lastCloseAtMs` 閻ㄥ嫭鏁為柌濠忕窗閸愬懎顔愮仦?`.onAppear()` 閻ㄥ嫬鍘规惔鏇炲瀻閺€顖炴浆鐎瑰啫鍨介弬?
    //   "鏉╂瑤绔村▎鈥冲毉閻滄壆娈戦懞鍌滃仯閺勵垯绗夐弰顖氬灠閹靛秹鍋呭▎鈥冲彠闂傤厾娈戞担娆愬皾"閵?*閸欘亜婀潻娆撳櫡閸愭瑣鈧線鍋呴柌宀冾嚢**閿?
    //   娑撱倕顦╅幋鎰嚠閿涘牅绗傛稉鈧潪顔煎涧閺堝顕伴妴浣圭梾閺堝鍟?閳?闂傘劍浜介崑鍥风礆閵?
    PlaybackPage.lastCloseAtMs = Date.now();
    // 閳?閺冭泛绨鎴濆皥鐎涙劧绱伴張顒侇偧閸忔娊妫村鈧慨瀣剁礄鐟?`evLog` 閻ㄥ嫭鏁為柌濠忕礆
    //   閳?2026-10-17閿涙瓪fb=` = 鏉╂瑤绔村▎鈩冩Ц**娴犲骸鎻╅悡褑鐭惧鍕偓鈧崠鏍箖閺夈儳娈?*閿涘牐顫?`closeFallbackReason`閿涘绱?
    //   鐠囪鐣崡铏 閳?`fb=` 缁?= 鐠ф壆娈戣箛顐ゅ弾鐠侯垰绶為敍娌梖b=snapFail` / `fb=noSrcBox 閳ヮ泦 = 鐠ч绨″ú濠氥€夎ぐ銏犲綁閵?
    const fb: string = PlaybackPage.closeFallbackReason;
    PlaybackPage.closeFallbackReason = '';
    PlaybackPage.ev('CLO', `gen=${this.closeGen + 1} p=${this.expandState.morphP.toFixed(2)}` +
      (fb.length > 0 ? ` fb=${fb}` : ''));
    // 閳藉應妲?P0-2閿涙碍婀版潪顔煎彠闂傤厾娈?*閻欘剛鐝涙禒锝嗩偧** + 閸欐牗绉锋稉濠佺鏉烆喖褰查懗鍊熺箷閹稿倻娼冮惃鍕祻鏉炶棄鐣鹃弮璺烘珤閵?
    //   `isClosing` 閹糕€崇繁娴?閺€鎯版崳閸斻劎鏁炬潻娑滎攽娑?閻ㄥ嫰鍣搁崗銉礉娴ｅ棗鐣犻崷?`morphCloseMs + 20`閿涘牃澧?70ms閿?
    //   鐏忚精顫﹀〒鍛礀 `false`閿涘矁鈧矂鍋呮稉鈧崚缁樻尡閺€楣冦€?*閸欘垵鍏樻潻妯荤梾 unmount** 閳?缁楊兛绨╁▎锛勫仯閸戣绱伴崘宥堟崳娑撯偓閺?
    //   350ms 鐞涖儵妫?+ 缁楊兛绨╂稉顏勫祻鏉炶棄鐣鹃弮璺烘珤閿涘矁鈧奔琚遍弶锟犳懠閻?`morphGen` 閻╃鎮?閳?`morphGenAlive` 閹凤缚绗夋担蹇嬧偓?
    //   閺堝绨?`closeGen` + 閸欍儲鐒洪敍宀€顑囨禍灞绢偧閻愮懓鍤憰浣风疄鐞氼偅妲戠涵顔兼嫹閻ｃ儯鈧浇顩︽稊鍫濆叡閸戔偓閹恒儳顓搁妴?
    const closeGen: number = this.closeGen + 1;
    this.closeGen = closeGen;
    if (this.closeSettleTimer !== -1) {
      clearTimeout(this.closeSettleTimer);
      this.closeSettleTimer = -1;
    }
    this.refreshCollapseGeometry();
    this.isClosing = true;
    // 濮濓絽婀弨鎯版崳閹绢厽鏂侀崳銊︽娑撳秷顩﹂崘宥堝殰閸斻劍鏁归幒褍鍩楅崠鐚寸礄娑撱倓閲滈崝銊ф暰閸欑姳绔寸挧铚傜窗瀵板牅璐￠敍?
    this.stopChromeAutoHide();
    // 閸忔娊妫撮張鐔兼？鏉╂稑瀹虫导姘粻閸?閺€鎯版崳"閸戠姷娅ㄥВ顐ゎ潡閿涘苯鍩嗙拋鈺佺潔瀵偓閻妫悪妤佸Ω鐎瑰啯濮犻崶鐐茬暚閺佸瓨鈧?
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 閳?鐠ф壆娈戦弰顖氳埌閸欐鐭惧鍕皑**閸欏秴鎮滅捄鎴濇倱娑撯偓婵傛鍤戞担?*閿涙碍鏆ｆい鐢电級閸ョ偠绯犳担鐘虫蒋闁絼绔寸亸蹇撴健閵嗕浇顥嗛崜顏嗙崶閸欙絾鏁归崶鐐插箵閿?
    //   閺堚偓閸氬氦鎯ら崶鐐剁碃娴ｇ姵娼敍鍦燗NDING閿涘鈧倸鐫嶅鈧?閺€鎯版崳鐏忚鲸妲搁崥灞肩婵傛寮弫鎵畱濮濓絽寮芥稉銈変憾閿涘奔鎹㈤幇蹇旀閸掑鍏橀懛顏呭攪閵?
    //   閳跨媴绗?閸掋倕鐣鹃悽?`morphUsable` 閼?*娑撳秵妲?* `morphContainerActive()`閿涙氨菙鐎规艾鐫嶅鈧幀浣烘畱閻╅晲缍呴弰?
    //      OPEN閿涘牅绗夐弰?ENTERING/LEAVING閿涘绱濋悽銊ユ倵閼板懎鍨界€规矮绱伴幒澶婃礀"閸樺澧庨崘鍛啇鐏炲倿鐝惔?閻ㄥ嫯鈧礁濮╅悽?閳ユ柡鈧?
    //      閻劍鍩涚€圭偞绁撮崚鎵畱閵嗗瞼鏁ょ化鑽ょ埠鏉╂柨娲栭崗鎶芥４鏉╂ɑ妲搁弮褍濮╅悽姹団偓宥呮皑閺勵垵绻栭柌灞烩偓?
    if (this.expandState.morphUsable) {
      // 閳藉應妲勯埥?2026-10-16閿?*閺€鎯版崳鏉╂瑤绔存笟褌绡冪憰浣界箖"閸戠姳缍嶇亸杈╁崕"闁綁浜鹃梻?*閿涘绱?
      //   閺堫剝鐤嗙紒?`applyMorphProgress` 閸旂姳绨℃稉鈧柆鎾存￥閻ｅ瞼娈戦梻顭掔礄`morphGeomReady`閿涘矁顫嗛柇锝勯嚋鐎涙顔岄惃鍕暈闁插绱氶敍?
      //   閸戠姳缍嶅▽鈥虫皑缂侇亝妞傜€?*娴犫偓娑斿牓鍏樻稉宥呬粵**閵嗗倹澧﹀鈧潻娆愭蒋鐠侯垶娼?`measureMiniDuringPull` 缂冾喕缍呴敍?
      //   閼?閻愮懓鍤崗鎶芥４ / 缁崵绮烘潻鏂挎礀閸忔娊妫?閺勵垯绮?*瀹歌尙绮￠拃鎴掔秴閻ㄥ嫭澧﹀鈧幀?*瀵扳偓閸ョ偠绐?閳ユ柡鈧?濮濓絽鐖舵惔鏂跨秼瀹歌尙鐤嗘担宥忕幢
      //   娴ｅ棗绱撶敮姝岀熅瀵板嫸绱欓幍鎾崇磻閺冩儼藟闁插繐銇戠拹銉ㄧ箖娑撯偓濞喡扳偓涔orphReset` 娑斿鎮楅崣鍫ｇ箻閺夈儮鈧讣绱氭导姘愁唨鐎瑰啯妲搁崑鍥风礉
      //   闁絾妞傛稉瀣桨闁?460ms 閻ㄥ嫭鏁圭挧鐤夐梻鏉戞皑閺?*閺佸瓨顔岀粚楦挎祮** =
      //   閻劍鍩涚€圭偞绁撮惃鍕┾偓宀€鍋ｉ崙璇插彠闂?/ 缁崵绮烘潻鏂挎礀 濞屸剝婀佺亸渚€娼?閼冲本娅欓崝銊ф暰閵嗗秲鈧?
      //   閳?鏉╂瑩鍣烽悽銊﹀ⅵ瀵偓閹礁鍑￠張澶屾畱缁旑垳鍋ｉ崙鐘辩秿閸忔粌绨抽弨鎹愵攽閿涘牊妫ら悾宀€娈戦弨鎯版崳閺堫剚娼电亸鍙樼瑝闁插秵鏌婇柌蹇曠矒閻愮櫢绱氶妴?
      if (!this.expandState.ensureMorphGeomForClose()) {
        Logger.warn(PlaybackPage.logTag,
          'close: geometry unresolved on both ends 閳?close without morph animation');
      }
      // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱?*閸忔娊妫撮弮鍫曟毐娑撳海绱﹂崝?*閿涘鈧柡鈧?
      //   **鏉╂瑤绔存径鍕皑閺勵垳鏁ら幋宄扮杽濞村鈧苯鍙ч梻顓熸尡閺€鎯ф珤閸戠姳绠▽鈥冲З閻㈡眹鈧秶娈戦惇鐔哥壌閸ョ姰鈧?*
      //   閺冪姷鏅?閸忔娊妫撮幓鎰唉"閿涘潿uit閿涘鍨庨弨顖ょ礄`_recover/logic-src/瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md`
      //   鎼? 闁喐鐓＄悰?L27/L29閿涘苯鐖堕柌蹇氥€?鎼傞崗?L620-633閿涘绱?
      //     `reverseMs = round(REVERSE_MS(460) 鑴?max(REVERSE_MIN_RATIO(0.4), morphT))`
      //     `animateMorphT(reverseMs, t = 0, REVERSE_EASING)`
      //     `REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`   閳?閳?**閹便垹鎯庨崝?*
      //   閳跨媴绗?閹存垳婊戦崢鐔告降閺?**350ms + `cubicBezier(0.23, 1.0, 0.32, 1.0)`**閿涘矁鈧矂鍋呴弶?
      //      閿涘潉EASE_OUT_STR`閿涘妲?*閹垫挸绱戦幓鎰唉**閻劎娈戦敍?*閸?15% 閺冨爼妫跨亸杈泲鐎瑰瞼瀹?70% 鐞涘瞼鈻?*
      //      閳?350ms 闁插瞼瀹?50ms 鐏忚京缂夌€瑰奔绨￠妴浣稿⒖娑?300ms 閸戠姳绠禒鈧稊鍫ュ厴濞屸€冲絺閻?閳ユ柡鈧?
      //      閻劍鍩涢幇鐔虹叀鐏忚鲸妲?**閸忔娊妫撮崙鐘辩濞屸€冲З閻?*"閿涙矮绗夐弰顖涚梾閹绢叏绱濋弰?*娑撯偓閻劎婧傜亸杈ㄧ梾娴?*閵?
      //   閳?娑撱倕顦╅柈鑺ュ瘻閺冪姷鏅弨鐧哥窗閺冨爼鏆?`460 鑴?max(0.4, morphT)`閵嗕胶绱﹂崝?**`REVERSE_EASING`**閵?
      //      娑撳鏅?`460鑴?.4 = 184ms` 娣囨繆鐦?閸欘亝濯哄鈧稉鈧悙鍦仯鐏忚鲸婢楅幍?閺冩湹绡冩潻妯绘箒娑擃亜鍎氶弽椋庢畱閺€璺哄◢閵?
      //   閳跨媴绗?**閸掝偅濡告稉銈嗘蒋缂傛挸濮╅幖鐐磋穿**閿涘牆鐣剧粙?鎼傞崗?L385 閸樼喐鏋冮敍姘モ偓瀹峈EVERSE_EASING` 閸欘亜婀?
      //      '閹绘劒姘﹂崗鎶芥４(quit)'鏉╂瑤绔撮弨顖滄暏閿?*閸欐牗绉烽崶鐐茶剨閸欏秷鈧瞼鏁?`EASE_OUT_STR`**閵嗗稄绱氶敍?
      //        璺?閹垫挸绱戦幓鎰唉 / 閹垫挸绱戦崣鏍ㄧХ 閳?`EASE_OUT_STR`
      //        璺?**閸忔娊妫撮幓鎰唉 閳?`REVERSE_EASING`**
      //        璺?閸忔娊妫撮崣鏍ㄧХ閿涘牆娲栧鐧哥礆閳?`EASE_OUT_STR`
      //   閳跨媴绗?鏉╂稑瀹宠箛鍛淬€忛崷?`morphBeginLeaving()` **娑斿澧?*閸欐牭绱欐稉瀣桨闁絼閲?`applySync` 闁插奔绱伴弨鍦祲娴ｅ稄绱氶妴?
      const closeFromT: number = this.expandState.morphP;
      // 閳藉應妲勯埥鍛 2026-10-17閿涘牅琚辨稉顏勵樆闁劍膩閸ㄥ绱扮拠濠傛倵**閸忓崬鎮撻幐鍥ф倻**閻ㄥ嫰鍋呮稉鈧弶鈽呯礉閸旂姳绨￠幎銈嗙埉閿涘绱?
      //
      // ## 閻ュ洨濮?
      // 閵嗗瞼閮寸紒鐔荤箲閸?/ 閸忔娊妫撮幐澶愭尦 / 娑撳濯洪弶鐐閿涙艾鐨濋棃?*閻╁瓨甯存稉瀣箵 / 閻╁瓨甯撮崚鏉跨毈閸﹀棗鑸?*閿涘本鐥呴張澶屽缁斿顥ｇ悰宀勫亝娑撯偓濡帇鈧?
      // ## 閺堝搫鍩?
      // 閺€鎯版崳鐞涖儵妫块惃鍕崳閻愯妲?*濞搭喖鐪伴懛顏勭箒閻ㄥ嫯绻樻惔?* `morphOverlayP`閿涘矁鈧苯鐣犻崷銊ょ瑓闂堛垼绻栫粔宥嗗剰瑜般垽鍣烽弰?**0**閿?
      //   璺?閹垫挸绱戦柇锝勭濡帞娈戝ù顔肩湴鐞涖儵妫垮▽锟狀棧鐠ч攱娼甸敍鍫滅伐婵″倽顫?`hostsMorphOverlay` / 閺冣晠鈧偓閹糕剝甯€閿涘绱?
      //     閹?`morphOverlayReset()` 閹?P 閸樺娲?0 娑斿鎮楃亸鍗炲晙濞屄ゎ潶閹恒劋绗傞崢浼欑幢
      // 閳?娴滃孩妲?`morphOverlayTweenTo(false)` 閹峰灝鍩?`from = 0`閵嗕梗to = 0`
      //   閳?鐞?`|to - from| < 1e-4` **閺冣晠鈧偓**閿涘牐绻?animateTo 闁垝绗夊鐚寸礆
      //   閳?閼?`morphOverlayBridging()` 閻ㄥ嫮娴夋担宥呭幑鎼存洖鍨庨弨?*娴犲秶鍔ф稉铏规埂**
      //     閿涘潉morphContainerActive() && snapStartW > 0 && endCoverSize > 0`閿?
      //   閳?閸忓娈曠仦?*閺佸瓨顔岄崗鎶芥４闁晫鏁鹃崷?`morphCoverRectAt(0)` = 鏉╄渹缍橀弶锟犲亝娑擃亜鐨崷?*娑撳绱濇稉鈧崝銊ょ瑝閸斻劊鈧?
      //
      // ## 娣囶喗纭堕敍鍫熷Б閺嶅繒澧楅敍?*閸欘亜婀?绾喖鐤勫▽锟狀棧鏉?閺?*鐎靛綊缍堥敍宀€绮锋稉宥嗗ⅵ閺傤厽顒滈崷銊╊棧閻ㄥ嫯绻樻惔锔肩礆
      // 閼汇儲璇炵仦鍌濈箻鎼达缚绮涢崑婊冩躬 0閵嗕浇鈧矂銆夐棃銏犵秼閸撳秷绻樻惔?> 0 閳?閹跺﹤鐣犵€靛綊缍堥崚浼淬€夐棃銏ｇ箻鎼?
      // 閿? 瀹稿弶婀侀惃?`syncMorphOverlayFromPage()`閿涘矁顕㈡稊澶嬵劀閺?濞搭喖鐪版潻娑樺 := 妞ょ敻娼版潻娑樺"閿涘绱?
      // 鏉╂瑦鐗遍弨鎯版崳鐞涖儵妫跨亸杈ㄦ箒娴滃棛婀＄€圭偠鎹ｉ悙鐧哥礄娓氬顩?1 閳?0閿涘绱濇稉鈧梹婊冨煂鎼存洘澧犻幋鎰彌閵?
      // 閳跨媴绗?**娑撳秷鍏橀弮鐘虫蒋娴犺泛顕?*閿涙俺瀚㈠ù顔肩湴濮濓絽婀?1閿涘牆銇囩亸渚€娼版担宥囩枂閿涘鈧矂銆夐棃銏犲嚒鐞氼偅澧滈幐鍥ㄥ珛閸?0.05閿?
      //   閺冪姵娼禒璺侯嚠姒绘劒绱扮拋鈺佸帬闂呭棗鐪?*娴犲骸銇囩亸渚€娼伴惉顒勬？鐠哄啿鍩屾潻铚傜稑閺?* = 娑撯偓濞嗏€冲讲鐟欎胶娈戠捄鍐插綁閵?
      if (this.expandState.morphOverlayProgress() <= 0.001 && closeFromT > 0.001) {
        this.expandState.syncMorphOverlayFromPage();
        PlaybackPage.ev('OVA', `align overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
          `to p=${closeFromT.toFixed(3)}`);
      }
      // 閳?閸忓牊濡?鏉╂稑鍙嗛弨鎯版崳閻╅晲缍?+ 閸愯崵绮ㄩ崙鐘辩秿"閸氬本顒為崚宄板毉閸樹紮绱版潻娆庣濞堝灚妲哥悰銉╂？**娑斿澧?*閻ㄥ嫰顤傛径鏍︽叏閺€鐧哥礉
      //   閹稿鐣奸弬纭咁潐閸掓瑥绻€妞よ崵鏁?`applySync` 閸氬本顒為弽鍥壈閿涘苯鎯侀崚娆捤夐梻鎾浕鐢傜窗閻劍妫崐绗衡偓?
      UIUtils.applySync((): void => {
        // 閳?2026-10-17閿?*閻劍鍩?08:46 閹搭亜娴橀柌宀勫亝閺夛紕鐓曢惄鍓ф畱鐎规碍鈧呮暏**閿涘绱?
        //   闁絼绔村鐘虫）韫囨妲?`CLO:gen=1 p=1.00` 缁毖勫复閻偓 `LV:anim from=0.00`
        //   閳ユ柡鈧?娑撱倛顢戠拠鑽ゆ畱閺?*閸氬奔绔存稉顏勭摟濞?* `morphP`閿涘奔鑵戦梻?*濞屸剝婀佹禒璁崇秿閸愭瑥鍙?*
        //   閿涘潉morphP` 閸忋劋绮ㄩ崣顏呮箒 3 娑擃亜鍟撻崗銉у仯閿涙瓪pullOpenBegin` 閻ㄥ嫬銇戠拹銉︽暜 / `applyMorphProgress` /
        //     `morphReset`閿涘矂鍏樻稉宥呮躬 `closeFullScreenPlayback` 鏉╂瑦娼惄瀵稿殠娑撳绱氶妴?
        //   閳?閸欘亜澧挎稉銈囶潚閸欘垵鍏橀敍灞界箑妞よ绔村▎陇顕伴弫鏉垮瀻瀵偓閿?
        //     閳?娑撱倛顢?*娑撳秵妲搁崥灞肩濞嗏€冲彠闂?*閿涘牅绨ㄦ禒鍓佺处閸愬弶妲搁棃娆愨偓浣烘畱閵嗕焦瀵滅€涙顑佺憗浣稿瀼閿?
        //        閻炲棜顔戞稉濠傚讲閼宠姤璐╅崗銉ュ綗娑撯偓濞嗏€冲彠闂傤厾娈?`LV`閿涘鍣?閹?**`closeGen`** 閹垫捁绻橀弶銉ュ祮閸欘垰鍨界€?
        //        閿涘潉CLO` 闁綀顢戦張顒佹降鐏忚鲸婀?`gen=`閿涘绱?
        //     閳?`morphP` 閻喓娈戦崷銊ㄧ箹娑撱倛顢戞稊瀣？鐞氼偅鏁兼禍?閳?`pNow=`閿?*濮濄倕顦?*闁插秵鏌婄拠璁崇濞嗏槄绱氭稉?`from=`
        //        娴兼艾鎮撻弮鏈佃礋 0閿涘矁鈧?`CLO` 闁綀顢戦弰?1.00閵?
        PlaybackPage.ev('LV', `anim gen=${this.closeGen} from=${closeFromT.toFixed(2)} ` +
          `pNow=${this.expandState.morphP.toFixed(2)}`);
        this.expandState.morphBeginLeaving();
      });
      const closeScale: number = closeFromT < PlaybackPage.REVERSE_MIN_RATIO ?
        PlaybackPage.REVERSE_MIN_RATIO : closeFromT;
      const morphCloseMs: number = Math.round(PlaybackPage.REVERSE_MS * closeScale);
      // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MorphGuard.animateMorph` 閻ㄥ嫮顑囨稉鈧崣銉礆閿涙俺鎹ｇ悰銉╂？娑斿澧犻幎?闁板秷澹婄€瑰娼ょ粣妤€褰?
      //   閹恒劌鍩?*鏉╂瑦娼悰銉╂？缂佹挻娼?*閿涘潉quietMs` 鐏忚鲸妲告潻娆愭蒋鐞涖儵妫块懛顏勭箒閻ㄥ嫭妞傞梹?閳ユ柡鈧?閺冪姷鏅柇锝勬櫠娑旂喐妲搁幐澶庣殶閻劎鍋ｆ导鐘垫畱閿?
      //   娓氬顩?`closeSearchMorph` 娴?`SP_SEARCH_SETTLE_MS`閿涘本婀版径鍕梾閺堝鎹㈡担鏇熸煀闁姴鐖堕柌蹇ョ礆閵?
      //   閳?閸忔娊妫撮崝銊ф暰鐠烘垹娼冮惃鍕閸婃瑱绱濋幑銏＄摃/閸欐牞澹婄€瑰本鍨氶惃?娑撳﹨澹?娑撯偓瀵板绶氶崥搴㈠皳閿涘奔绗夋导姘躬閸斻劎鏁炬稉顓⑩偓鏃囩儲閼瑰眰鈧?
      this.expandState.markMorphQuiet(morphCloseMs);
      // 閳藉應妲?濞搭喖鐪伴柇锝勭濡帪绱欐竟鍐茬湴 `MorphCoverClone` 閻ㄥ嫮鐢绘鐐茬殱闂堫澁绱?*韫囧懘銆忛悽杈ㄦ拱婢跺嫬鎮撳銉┾攳閸?* 閳ユ柡鈧?
      //   娓氭繃宓佺憴?`PlayerExpandState.applyMorphProgress` 闁?閸掔姵甯€閼奉亜濮╂径宥勭秴"闁絾顔?+ 閻劍鍩涚€圭偞绁撮惃?
      //   閵嗗奔绗呴幏澶婂彠闂傤厽妞傜亸渚€娼伴崝銊ф暰閺勵垰鐫嶅鈧柇锝勭婵傛ぜ鈧秲鈧瞼閮寸紒鐔荤箲閸ョ偛鍙ч梻顓熺梾閺堝鐨濋棃銏犲З閻㈡眹鈧秲鈧?
      //   閳跨媴绗?閸樼喐娼甸崣顏堟浆婢瑰啿鐪?`@Monitor('expandState.morphStage')`閿涙瓘2 閻?`@Monitor` 閺?*瀵倹顒?*閸ョ偠鐨熼敍?
      //      閼板本婀伴崙鑺ユ殶閻ㄥ嫭鏁圭亸鎯х暰閺冭泛娅掗敍鍧刴orphCloseMs + 20`閿涘鍣锋导姘崇箾閻偓鐠?
      //      `morphLand()` 閳?`morphReset()`閿涘牆鎮楅懓?*閸氬本顒?*閹?`morphOverlayP` 濞?0閿涘鈧柡鈧?
      //      閸欘亣顩?`@Monitor` 閻ㄥ嫬娲栫拫鍐╁笓閸︺劌顦叉担宥勭閸氬函绱濈亸渚€娼伴柇锝勭濡帒姘?*閺佸瓨顔屽▽鈩冩尡**閵?
      //      鏉╂瑩鍣烽崷銊ㄦ崳鐞涖儵妫挎稊瀣**閸氬本顒?*閸犲﹣绔存竟甯礉妞ゅ搫绨亸鍙樼瑝閸愬秴褰囬崘鍏呯艾瀵邦喕鎹㈤崝陇鐨熸惔锔衡偓?
      //   閳跨媴绗?濞搭喖鐪伴柇锝嗘蒋鐞涖儵妫?*瀹歌尙绮￠崷銊ㄧ獓**閺冩湹绗夌憰浣瑰閿涘潉overlayTweenAnimating()`閿涘绱?
      //      娑撳﹥濯?閸ョ偛鑴婇柇锝嗘蒋閻㈠崬锛撶仦?`settlePullOpen` 閸欐垼鎹ｉ敍灞炬煙閸氭垳绗岄張顒侇偧娑撯偓閼疯揪绱濋幎銏ｇ箖閺夈儱褰ф导姘ⅵ閺傤厼鐣犻妴?
      //      閿涘潉focusMorphOverlayForPageCollapse` 閸愬懘鍎存潻妯绘箒娑撯偓鐏?閺堫剝鐤嗛崣顏囶啅鐠ц渹绔村▎?閻ㄥ嫬绠撶粵澶嬪Б閺嶅骏绱?
      //        閸ョ姳璐熸竟鍐茬湴閻?`@Monitor` 娑旂喍绱扮拫鍐ㄧ暊 閳ユ柡鈧?鐟欎浇顕氶崙鑺ユ殶閻ㄥ嫭鏁為柌濞库偓鍌︾礆
      this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
      Logger.info(PlaybackPage.logTag,
        `RzdMorph close tween from morphT=${closeFromT.toFixed(3)} 閳?${morphCloseMs}ms ` +
        `(=REVERSE_MS ${PlaybackPage.REVERSE_MS} 鑴?max(REVERSE_MIN_RATIO ${PlaybackPage.REVERSE_MIN_RATIO}, morphT)) ` +
        `easing=REVERSE_EASING(0.85,0,0.5,0.88) overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
        `overlayAnimating=${this.expandState.overlayTweenAnimating()} ` +
        `coverClone=${this.expandState.morphOverlayBridging()} ` +
        `realCover=${this.expandState.realCoverVisible()}`);
      const gen: number = this.expandState.morphGen;
      this.getUIContext().animateTo({
        duration: morphCloseMs,
        curve: curves.cubicBezierCurve(0.85, 0, 0.5, 0.88)
      }, (): void => {
        // 閳藉應妲勯埥鍛 2026-10-17閿?*閻劍鍩涚粭?2閵? 閺?閸忔娊妫撮弮鐘插З閻㈡眹鈧礁鐨濋棃銏㈡纯閹恒儰绗呴崢?閻ㄥ嫭鐗撮崶?*閿?
        //   娑?`playMorphOpenIntro` 闁絼绔存径?*鐎瑰苯鍙忛崥灞肩娑擃亪鏁婄拠?*閿涘牆鎮撴稉鈧ぐ銏㈠Ц缁?2 婢跺嫸绱氶敍?
        //   閸樼喐娼甸弰?`UIUtils.applySync(() => applyMorphProgress(0))` 閳ユ柡鈧?閸?`animateTo` 閻ㄥ嫰妫撮崠鍛村櫡
        //   閸氬本顒為崚閿嬫煀閻╊喗鐖ｉ崐?閳?**鐞涖儵妫跨悮顐ョ儲鏉?* 閳?鐏忎線娼伴惄瀛樺复閽€钘夊煂缂佸牏鍋ｉ敍?閻╁瓨甯存稉瀣箵娴?/ 閻╁瓨甯撮崚鏉跨毈閸﹀棗鑸?閿涘鈧?
        //   娑撳﹥鐖堕崗鎶芥４闁絼绔存笟褝绱檂animateMorphT(reverseMs, 0, REVERSE_EASING)`閿涘鎮撻弽宄板涧閸愭瑧娲伴弽鍥р偓绗衡偓?
        //   閳跨媴绗?鐠ч鍋ｉ敍鍫㈡祲娴?+ 閸愯崵绮ㄩ崙鐘辩秿閿涘鍋呮稉鈧▓?*娴犲秶鍔?*閻?`applySync`閿涘牐顫嗛張顒€鍤遍弫棰佺瑐闂堛垽鍋呮径?:3729閿涘鈧柡鈧?
        //     闁絾妲?鐞涖儵妫挎稊瀣"閻ㄥ嫭顒滅涵顔炬暏濞夋洩绱?*娑撳秷顩?*娑撯偓鐠у嘲鍨归幒澶堚偓?
        // 鈽呪槄鈽呪槄 2026-10-17锛堜笌鎵撳紑閭ｄ竴渚у悓涓€鏉★細**闂寘閲屽彧鍐?`morphP`**锛?
        //   `applyMorphProgress(0)` 浼氫竴娆℃€ф妸鍑犱綍+娲剧敓閲忓啓鎴愮粓鐐?鈬?鑳屾櫙 `pullBgIn` 璧锋墜灏?0
        //   鈬?鍏抽棴璺笂"鍙墿搴曞骇鑹?锛屾鏄敤鎴峰疄娴嬬殑銆屽叧闂椂鑳屾櫙鍙橀粦銆嶃€?
        //   鐜板湪鍙啓鐩爣鍊硷紝`@Monitor('morphP')` 閫愬抚閲嶇畻 鈬?鑳屾櫙娌?`pullBgIn` 骞虫粦娣″嚭銆?
        this.expandState.morphP = 0;
      });
      this.closeSettleTimer = setTimeout((): void => {
        this.closeSettleTimer = -1;
        if (!this.isAlive) {
          // 閳藉應妲勯埥?2026-10-17閿?*閻劍鍩涚粭?閳?閺壜扳偓灞炬箒閼冲本娅欐担鍡樻Ц妤傛ê瀹抽悧閫涚秵閵嗗秶娈戞径鏉戝娇鐎氬瞼鏋掔亸鍗炴躬鏉╂瑩鍣?*閿涘鈧?
          //
          // ## 閸樼喐娼垫潻娆撳櫡閺?閻╁瓨甯?return"閿涘奔绮堟稊鍫熸暪鐏忛箖鍏樻稉宥呬粵
          // ```ts
          //   if (!this.isAlive) { ev('SET','dead'); return; }   // 閳?閺冄冨晸濞?
          // ```
          // 娴滃孩妲搁崙鐘辩秿**濮樻瓕绻欓崑婊冩躬鐞涖儵妫跨捄鎴濆煂閻ㄥ嫰鍋呮稉顏冪秴缂?*閿涙氨娴夋担宥堢箷閺?`LEAVING`
          // 閳?`morphContainerActive()` 閻?閳?`morphClipping()` 閻?
          // 閳?鐎圭懓娅?`.height()` 閸氬啰娈戦弰?`morphClipHeight`閿涘牃澧?鏉╄渹缍橀弶锟犲亝娑撯偓娴犳枻绱濋崙鐘插磩 vp閿?
          // 閳?**閺佹挳銆夐崣顏嗘暰閸戝搫绶㈤惌顔炬畱娑撯偓閺?*閿涘矁鈧矁鍎楅弲顖ょ礄`MeshCoverBg`閿涘妲哥€圭懓娅掗惃鍕摍閼哄倻鍋?
          // 閳?鐏炲繋绗傜亸杈ㄦЦ閻劍鍩涚拠瀵告畱閵嗗本婀侀懗灞炬珯娴ｅ棙妲告妯哄閻楅€涚秵閵嗗秲鈧?
          //
          // ## 娑撹桨绮堟稊?妞ょ敻娼板璁崇啊"閸欏秷鈧本娲块棁鈧憰浣规暪鐏?
          // 鏉╂瑤绔撮弨顖滄畱閸氼偂绠熼弰?閺€璺虹啲鐎规碍妞傞崳銊╁晪閺夈儲妞傛い鐢告桨瀹歌尙绮￠崡姝屾祰娴?閿涘矁鈧?*閸戠姳缍嶉弰顖氬彙娴滎偆娈?*
          // 閿涘潉PlayerExpandState` 閹稿倸婀?AppStorageV2 娑撳绱氶埇?妞ょ敻娼板▽鈥茬啊閵嗕礁鍤戞担鏇＄箷濮濐亞娼冮敍?
          // 娑撳绔村▎鈩冨ⅵ瀵偓鐏忚鲸妲告禒搴ょ箹娑撯偓娴犺姤顒ｉ崙鐘辩秿鐠ч攱澧滈妴?
          //
          // 閳?娑撳簼绗呴棃銏ゅ亝閺?娑撴牔鍞崣閿嬫－闁偓閺€?**鐎靛綊缍堥幋鎰倱娑撯偓娑擃亜鑸伴悩?*閿涘牓鍋呴弶鈩冩拱閺夈儱姘ㄩ弰顖氼嚠閻ㄥ嫸绱氶敍?
          //   缂堣崵娴夋担?+ 閸楁瓕娴囬妴鍌楁閿?娴犲秶鍔?*娑撳秷鐨?`morphReset()`** 閳ユ柡鈧?鏉╂瑩鍣峰▽鈩冩箒閸欘垶娼惃?
          //   "妞ょ敻娼板鑼病娑撳褰?閸掋倖宓侀敍宀冣偓?`morphReset()` 娴兼艾婀い鐢告桨鏉╂ê婀仦蹇庣瑐閺冭埖濡哥€圭懓娅掓径宥勭秴閹存劖寮х仦?
          //   閿涘牓鍋呯亸杈ㄦЦ閻劍鍩涚粭?閳?閺夆槄绱氶妴鍌氼槻娴ｅ秶娈戝锝団€橀弮鑸垫簚鐟?`scheduleMorphResetAfterPop()`閵?
          PlaybackPage.ev('SET', `dead閳墶ND+POPT p=${this.expandState.morphP.toFixed(2)}`);
          this.isClosing = false;
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          return;
        }
        // 閳?P0-2閿涙碍婀版潪顔煎彠闂傤厼鍑＄悮?娑撳绔村▎鈥冲彠闂傤叀顕Ч?閸欐牔鍞?閳?閺€璺虹啲娴溿倗绮伴柇锝勭鏉烆噯绱濇潻娆撳櫡娴犫偓娑斿牓鍏樻稉宥呬粵
        if (closeGen !== this.closeGen) {
          PlaybackPage.ev('SET', `genWait`);
          return;
        }
        // 娑撳簼绗傛稉鈧弶?*闁€燁洣**閿涙瓪closeGen` 閹?闁插秴顦查崗鎶芥４"閿涘畭morphGenAlive` 閹?閸忔娊妫撮柅鏂捐厬閸欏牐顫︾仦鏇炵磻"
        if (!this.expandState.morphGenAlive(gen)) {
          // 鏉╂瑤绔存潪顔芥暪鐠у嘲鍑＄紒蹇氼潶閺傛壆娈戣ぐ銏犲綁娴兼俺鐦介崣鏍﹀敩閿涘牅绗樻禒锝呭娇閸欐ü绨￠敍澶涚窗閺堫剝鐤嗘担婊冪熬閵?
          //
          // 閳藉應妲?2026-10-15 鐞涖儲绱￠敍鍫㈡暏閹村嘲鐤勫ù瀣ㄢ偓?*濞屸剝纭舵稉瀣閸忔娊妫撮幘顓熸杹閸?*閵?閵嗗苯鍙ч梻顓熸尡閺€鎯ф珤閸戠姳绠▽鈥冲З閻㈡眹鈧稄绱氶敍?
          //   閺堫剝鐤嗛惃鍕暪鐠ч攱妫﹂悞鏈电稊鎼寸噦绱濈亸鍗炵箑妞?*閹?`isClosing` 閺€鐐竴**閵嗗倸鐣犻崣顏勬躬娑撳娼伴柇锝嗘蒋濮濓絽鐖堕弨璺虹啲闁插矁顫﹀〒鍜冪礉
          //   閼板矁绻栭弶鈩冩－闁偓鐠侯垰绶?*濞屸剝婀佹禒璁崇秿娴滆桨绱伴崘宥嗙鐎?* 閳?閸椻€虫躬 `true` 娑斿鎮楅敍?
          //     璺?`onDismissDrag()`閿涘牊婀伴弬鍥︽缁?567 鐞涘矉绱氱粭顑跨鐞涘苯姘?`if (this.isClosing) return;`
          //     璺?`closeFullScreenPlayback()`閿涘牏顑?1779 鐞涘矉绱氶崥灞剧壉缁楊兛绔寸悰灞芥皑 return
          //   閳?**娑撳濯洪弨鎯版崳娑撳骸鍙ч梻顓熷瘻闁筋喖寮婚崣灞炬娑斿懎銇戦弫?*閿涘矁鈧奔绗栫仦蹇庣瑐濞屸剝婀佹禒璁崇秿閸斻劎鏁?
          //     閿涘牐顫囬幇鐔割劀閺?閸忔娊妫撮幘顓熸杹閸ｃ劌鍤戞稊搴㈢梾閸斻劎鏁?閳ユ柡鈧?閸ョ姳璐熼崗鎶芥４**閺嶈婀板▽鈥虫儙閸?*閿涘鈧?
          //   閸欘亝婀佹稉瀣偧闁插秵鏌婃潻娑欐尡閺€楣冦€夐敍鍫熸煀鐎圭偘绶ラ敍澶嬪娴?閼奉亜绻佹總鎴掔啊"閿涘本澧嶆禒銉ㄧ箹娑?bug 瀵板牆顔愰弰鎾诡潶瑜版挻鍨氶崑璺哄絺閵?
          //   閳跨媴绗?娑撳﹪娼?`closeGen !== this.closeGen` 闁絾娼?*娑撳秷鍏?*鏉╂瑦鐗卞〒鍜冪窗闁絾妲?閺傞绔存潪顔煎彠闂傤厼鍑￠幒銉ь吀"閿?
          //      閺嶅洤绻旇ぐ鎺楀亝娑撯偓鏉烆喚顓搁敍鍫濈暊鐠ф澘鍩屾潻娆撳櫡閺冩湹绱伴懛顏勭箒濞撳拑绱濋柧鎯х础閼奉亝鍓ら敍澶堚偓?
          Logger.warn(PlaybackPage.logTag,
            `RzdMorph close aborted by new morph session gen=${gen} ` +
            `liveGen=${this.expandState.morphGen} stage=${this.expandState.morphStage} ` +
            `閳?release isClosing + finish the close`);
          this.isClosing = false;
          // 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤崗鎶芥４ / 缁崵绮烘潻鏂挎礀"鏉╂瑤绔撮弶锛勬畱閺堚偓閸氬簼绔撮崸?*閿涘绱?
          //   娑撳﹪娼伴柇锝嗘蒋閺冣晠鈧偓**閸欘亝鏂佸鈧禍?`isClosing`閿涘本鐥呴張澶嬪腹鏉?閸忔娊妫?鏉╂瑤娆㈡禍瀣拱闊?*
          //   閳?閹绢厽鏂佹い鍏哥窗**濮樻瓕绻欓悾娆忔躬鐏炲繋绗?*閿涘牏鏁ら幋椋庡仯閸忔娊妫存稊瀣倵鐏炲繋绗傛禒鈧稊鍫ュ厴濞屸€冲絺閻㈢噦绱氶妴?
          //   娑撹桨绮堟稊鍫ｈ泲閸掓媽绻栭柌宀嬬窗閺€鎯版崳鏉╁洨鈻兼稉顓″ `morphGen` 鐞?`morphReset()` 濞撳懓绻冩稉鈧▎?
          //   閿涘牆鍚€閸ㄥ娼靛┃鎰剁窗閹绢厽鏂佹い浣冨殰闊偆娈?`onDisappear` / 鏉╄渹缍橀弶鈥叉櫠閸楁瓕娴?/ 娑撳﹣绔存潪顔界暙閻ｆ瑦绔婚悶鍡礆閿?
          //   娑撴牔鍞崣宄版皑娑撳孩婀版潪顔藉礋閼鹃娈戞稉宥呮倱 閳ユ柡鈧?閼?*鏉╂瑥鑻熸稉宥勫敩鐞?閻劍鍩涙稉宥嗗厒閸忓厖绨?**閵?
          //   閳?閺堫剝鐤嗛弮銏㈠姧閺?鐟曚礁鍙?閿涘苯姘ㄩ幎濠傚彠闂傤厽甯归崚鏉跨俺閿?
          //     閳?閻╁瓨甯撮拃鎴掔秴閿涘潉morphLand()`閿涘奔绗屽锝呯埗閺€璺虹啲閸氬奔绔村銉礆閿?
          //     閳?閸楁瓕娴囬幘顓熸杹妞ょ绱檂isShowPlay=false`閿涘鈧柡鈧?
          //        閻╅晲缍呮稉搴″殤娴ｆ洜娈戝〒鍛倞閻?*閸楁瓕娴囬柧鎹愬殰瀹歌京娈?* `onDisappear 閳?morphReset()` 鐠愮喕鐭楅敍?
          //        鏉╂瑩鍣?*娑撳秹鍣告径宥堢殶**閿涘牓鍣告径宥堢殶娴兼艾鍟€婢舵碍甯规稉鈧▎?`morphGen`閿涘苯鍩楅柅鐘辩瑓娑撯偓鏉烆喚娈戦崥宀€琚梻顕€顣介敍澶堚偓?
          //   閳跨媴绗?楠炲倻鐡?鐎瑰鍙忛敍姝歩sShowPlay` 閼汇儱鍑￠弰?false閿涘畭@Monitor` 娑撳秳绱伴柌宥咁槻閸斻劋缍旈敍?
          //      `morphLand()` 閸︺劑娼ぐ銏犲綁閹焦妲哥€瑰鍙忛惃鍕敄閹垮秳缍旂拠顓濈疅閿涘牆褰х紙鑽ゆ祲娴?+ 娴溿倛绻曢幍鈧張澶嬫綀閿涘鈧?
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          PlaybackPage.ev('SET', `genBAD閳墶ND+POPT`);
          return;
        }
        PlaybackPage.ev('SET', `ok gen=${closeGen}`);
        this.isClosing = false;
        this.restorePlaybackWindowChrome();
        // LANDING閿涙碍顒濋崚缁樻尡閺€楣冦€夊鑼病缂傗晜鍨氶柅蹇旀閻ㄥ嫪绔寸亸蹇撴健閿涘本濡告潻铚傜稑閺夆€叉唉鏉╂绮扮€?
        // 閿涘潉miniBarOpacity()` 閸︺劑娼?ENTERING/LEAVING 閺冭埖浜芥稉?1閿涘绱濋崘宥呭祻鏉炲鈧?
        this.expandState.morphLand();
        PlaybackPage.ev('LND');
        // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻?`squashLand`閿涘绱?*閽€鎴掔秴闁絼绔寸敮褑鎹?閹绢厽鏂侀弶鈩冨皨閸?閳?閸ョ偛鑴?**閵?
        //   妞ゅ搫绨崪灞炬￥閻ｅ矂鈧劕鐡ф稉鈧懛杈剧窗`setMorph(LANDING)`閿?`morphLand()`閿涘本婀扮敮褎鎸遍弨楣冦€夐崑婊呯應閵?
        //   鏉╄渹缍橀弶锛勬埂闊偅妯夐崙鐑樻降閿涘鍟?`animateSquash(SQUASH_Y 0.86, 110ms)` 閳?320ms 鏉╁洤鍟块崶鐐茶剨閵?
        //   閳?閻劍鍩涚€圭偞绁撮惃鍕┾偓灞炬￥閻ｅ苯鍙ч梻顓熸閹绢厽鏂侀弶鈥茬窗瀵€涚娑撳鈧秴姘ㄩ弰顖濈箹娑撯偓鐎电藟闂傛番鈧?
        //   閳跨媴绗?韫囧懘銆忛崷?`morphLand()` 娑斿鎮楅敍姘－娑撯偓鐢冩皑閺?閹绢厽鏂佹い浣冪箷閸︺劎鏁鹃妴浣规蒋閸忓牆鑴?閵?
        //   閳跨媴绗?**2026-10-17 鐠併垺顒?*閿涙俺绻栨稉鈧崣銉ュ斧閺夈儲甯撮惈鈧崘?娑?`morphReset()` 閻ㄥ嫰銆庢惔蹇庣瑝閼宠棄寮?閵?
        //      閻滄澘婀?`morphReset()` 瀹歌尙绮?*娑撳秴婀潻娆撳櫡**娴滃棴绱欓弨瑙勫灇"缁?pop 娑斿鎮?閿?
        //      鐟欎椒绗呴棃銏ゅ亝濞堜絻顕╅弰搴濈瑢 `scheduleMorphResetAfterPop()`閿涘鈧柡鈧?
        //      閹碘偓娴犮儱鐣犳稉?`squashLandAnim()` 娑斿妫挎稉宥呭晙閺堝銆庢惔蹇涙６妫版ǜ鈧?
        //      閳跨媴绗?娴?`morphReset()` **娴犲秶鍔ф稉宥囶潾** `morphSquashY`閿涘牊灏嬮崢瀣Ц閻欘剛鐝涢惃鍕閺夆剝鐖ｉ柌蹇ョ礆閿?
        //      閹碘偓娴犮儵鍋呮稉鈧Λ鎺戞躬婢跺秳缍呮稊瀣倵閻撗勭壉娴兼碍濡?0.86 瀵懓娲?1閿?*鏉╂瑦妲哥憰浣烘畱**閿涘牊妫ら悾宀€娈戦拃鎴掔秴閸ョ偛鑴婇敍澶堚偓?
        this.expandState.squashLandAnim(this.getUIContext());
        PlaybackPage.ev('SQZ');
        this.state.isShowPlay = false;
        PlaybackPage.ev('POPT',
          `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
        // 閳藉應妲勯埥?2026-10-17閿?*閻劍鍩涚粭?閳?閺壜扳偓宀€鐛婇悞鑸垫降娑擃亜鐫嶅鈧幘顓熸杹閸ｃ劎娈戦崝銊ф暰閵嗗秶娈戦張鍝勫煑缁狙傛叏濞?*閿涘鈧?
        //
        // ## 閸樼喐娼垫潻娆撳櫡閺?閸氬奔绔?tick 闁插苯鎮撳?morphReset()"閿涘奔璐熸禒鈧稊鍫ュ亝閺勵垶鏁婇惃?
        // ```ts
        //   this.state.isShowPlay = false;   // 閳?婢瑰啿鐪?@Monitor閿涘湸2 瀵倹顒為敍澶嗗晪 popPlayerRoute()
        //   this.expandState.morphReset();   // 閳?閸氬本顒為敍宀€鎻ｇ捄鐔峰従閸?
        // ```
        // `morphReset()` 娴兼碍濡?`morphStage` 濞撳懏鍨?`NONE`閵嗕梗morphP` 婢跺秳缍呴幋?1閵?
        // `morphClipHeight` 濞撳懘娴傞妴涔orphScale` 婢跺秳缍呴幋?1
        // 閳?`morphContainerActive()` 缂堣浜?閳?鐎圭懓娅?*娑撳秷顥嗛崜顏傗偓浣风瑝缂傗晜鏂侀妴浣风瑝娴ｅ秶些** = **濠娾€崇潌閹绢厽鏂佹い?*閵?
        // 閼板矁鐭鹃悽杈洣閸?*娑撳绔寸敮?*閹靛秷顫?`pop(false)` 閹芥ɑ甯€閿涘潉@Monitor` 濞叉儳褰傛稉鈧仦?+ 鐢啫鐪幗姗€娅庢稉鈧仦鍌︾礆
        // 閳?娑擃參妫块柇?1~2 鐢冪潌娑撳﹤姘ㄩ弰顖ょ窗
        // ```
        //   瀹歌尙绮＄紓鈺傚灇鐏忓繐娓鹃悙鐧哥礄LANDING閿涘矁顫︾憗浣告躬鏉╄渹缍橀弶锟犲亝娑斿牓鐝敍?閳?缁愪胶鍔у鈥崇潌閹绢厽鏂佹い?閳?濞戝牆銇?
        // ```
        // 鐟欏倹鍔呭锝嗘Ц閻劍鍩涚拠瀵告畱閵嗗苯濮╅悽鑽ょ波閺夌喍绨?*缁愪胶鍔ч弶銉ら嚋鐏炴洖绱戦幘顓熸杹閸ｃ劎娈戦崝銊ф暰**閵嗗秲鈧?
        //
        // ## 娣囶喗纭堕敍?*缁涘銆夐棃銏㈡埂閻ㄥ嫪绗呴崣鏉垮晙婢跺秳缍呴崙鐘辩秿**
        // 閽€鎴掔秴閿涘潉morphLand()`閿涘鍑＄紒蹇斿Ω缂佹ê鍩楅弶鍐ф唉鏉╂绮版潻铚傜稑閺夆€茬啊閿涘矂鍋呮稉鈧禒?鐞氼偉顥嗛崷銊ㄧ碃娴ｇ姵娼柇锝勭疄妤?閻?
        // 閸戠姳缍?*閸︺劑銆夐棃顫瑓閸欓绠ｉ崜宥嗘Ц鐎瑰苯鍙忓锝団€橀惃鍕▔缁€铏瑰Ц閹?*閿涘牏鏁ら幋椋庢箙閸掓壆娈戠亸杈ㄦЦ鏉╄渹缍橀弶鈽呯礆閳ユ柡鈧?
        // 閹碘偓娴犮儱顦叉担?*濞屸剝婀佹禒璁崇秿閻炲棛鏁?*閹躲垹婀?pop 閸撳秹娼伴崑姘モ偓?
        // 閳跨媴绗?娴ｅ棔绡冩稉宥堝厴娑撳秴浠涢敍姘殤娴ｆ洘妲搁崗鍙橀煩閻ㄥ嫸绱濇稉宥咁槻娴ｅ秳绱板Ч鈩冪厠娑撳绔存潪顕嗙礄鐟?`morphGenAlive` 闁綁浜鹃梻顭掔礆閵?
        // 閳?娴溿倗绮?`scheduleMorphResetAfterPop()`閿?*鏉烆喛顕楅崚?閹绢厽鏂佹い浣冪熅閻㈠崬鍑＄紒蹇庣瑝閸︺劍鐖ら柌?閹靛秴顦叉担?*閿?
        //   楠炶泛鐢?閺傞绔存潪顔荤窗鐠囨繂鍑￠幒銉ь吀鐏忓彉绗夌拋鍛婄"閻ㄥ嫬寮荤€瑰牆宕奸妴?
        this.scheduleMorphResetAfterPop(closeGen, this.expandState.morphGen, 0);
      }, morphCloseMs + 20);
      return;
    }
    // 濞屸剝婀侀崣顖炴浆閸戠姳缍嶉弮鍓佹纯閹恒儱鍙ч梻顓ㄧ礉缂佹繀绗夐崶鐐衡偓鈧崚鏉垮竾閹典礁鍞寸€圭懓鐪伴惃鍕＋鏉烆剙婧€閵?
    Logger.warn(PlaybackPage.logTag, 'collapse without geometry: immediate landing');
    PlaybackPage.ev('CLO', 'noGeom');
    this.isClosing = false;
    this.restorePlaybackWindowChrome();
    this.state.isShowPlay = false;
    PlaybackPage.ev('POPT', 'noGeom');
    // 閳?閸?濮濓絽鐖堕弨璺虹啲閺€?閿涙艾顦叉担宥呭殤娴ｆ洖绻€妞?*缁涘銆夐棃銏㈡埂閻ㄥ嫪绗呴崣?*閿涘牐顫?`scheduleMorphResetAfterPop`閿涘鈧?
    this.scheduleMorphResetAfterPop(this.closeGen, this.expandState.morphGen, 0);
    // 閸忔粌绨崇捄顖氱窞娑旂喕顩﹀閫涚娑撳绱伴崥锕€鍨?閸戠姳缍嶅▽锟犲櫤閸?閺冩儼绻栭弶鈥虫暜娑撯偓閻ㄥ嫭鏁圭挧宄板冀妫ｅ牆姘ㄩ弫缈犻嚋濞屸剝婀?
    this.expandState.squashLandAnim(this.getUIContext());
  }

  /** 娑撳﹥顐?`logBranchSurface()` 閹垫捁绻冮惃鍕劮閸氬稄绱欓悽銊︽降閹跺﹪鍣告径宥夊櫢缂佹ê甯囬幋鎰閺夆槄绱辩憴浣筋嚉閺傝纭跺▔銊╁櫞閿涘鈧?*/
  private lastBranchLog: string = '';

  /**
   * 閳藉應妲?2026-10-15閿涘牏娲伴弽?閳?閻?*閸掑棙鏁ぐ鎺戠潣鐠囧﹥鏌?+ 閻楀牓娼版稉宥呭綁闁插繗鍤滃Λ鈧?*閿涘绱伴幎?閻滄澘婀崚鏉跨俺鐠ф壆娈戦崫顏冪閺夆€冲瀻閺€?+
   * 闁絼绔撮弨顖滄畱鐎圭偞绁撮崙鐘辩秿 + **娑撳秴褰夐柌蹇旀Ц閸氾附鍨氱粩?*"閹垫挸鍤弶銉ｂ偓?
   *
   * ## 娑撹桨绮堟稊鍫ユ付鐟曚礁鐣?
   *
   * 閺堫剟銆夐惃鍕鐏炩偓閺?*娑撳娼崚鍡樻暜**閿涘潉buildControlStack()`閿涘绱?
   * ```
   *   panel閿涘牓娼伴弶鍖＄礆  閳?usePanelLayout()
   *   wide閿涘牆顔旂仦?楠炶櫕婢橀敍澶嗗晣 闂?SM 娑撴棃娼敍鍦 + HEIGHT_SM閿?
   *   phone閿涘牊澧滈張鐚寸礆  閳?閸忔湹缍?
   * ```
   * 閼?*閸欘亝婀侀幍瀣簚瑜般垺鈧礁婀張顒佹簚閸欘垱鐎柅?* 閳?鐎硅棄鐫?楠炶櫕婢?濡亜鐫?PC 闁絼琚遍弶?*娴犲孩娼靛▽陇顫︽宀冪箖**閵?
   * 缁涘瀣侀崚浼村亝娴滄稑鑸伴幀浣规閿涘瞼顑囨稉鈧禒鎯邦洣閻儵浜鹃惃鍕皑閺?**鐎瑰啫鍩屾惔鏇¤泲娴滃棗鎽㈡稉鈧弨?*"閳ユ柡鈧?
   * 閸ョ姳璐熸稉澶嬫蒋閸掑棙鏁惃?*鐏忎線娼板〒鍙夌厠閼板懍绗夐崥?*閿涘潷hone = 鐟曞棛娲婄仦?`LyricFloatLayer`閿涙硤ide/panel = `MusicPlayInfoBlock`閿涘绱?
   * 娑撯偓閺冿箑鍨庨弨顖氬灲閹诡喕绗屾０鍕埂娑撳秶顑侀敍宀€妫侀悩鏈电窗鐞涖劎骞囨稉?鐏忎線娼版担宥囩枂瀵板牆顨岄幀?閿涘矁鈧本鐗撮崶鐘插従鐎圭偞妲?鐠т即鏁婃禍鍡樻暜"閵?
   *
   * ## 娑撳秴褰夐柌蹇氬殰濡偓閿涘潉inv=` 闁絼绔撮崚妤嬬礆閳ユ柡鈧?閹?閻娼冩稉宥咁嚠"閸欐ɑ鍨?閺冦儱绻旈惄瀛樺复鐠囩繝绗夐幋鎰彌"
   *
   * | 閺嶅洩顔?| 閺傤叀鈻?| 娑撳秵鍨氱粩瀣嚛閺勫簼绮堟稊?|
   * | --- | --- | --- |
   * | `coverNone` | 鐏忎線娼伴懞鍌滃仯闁插繐绶遍崚?| 闁絼绔撮弨顖涚梾閹?`PLAYER_BIG_COVER_ID` 閹稿倷绗?閳?鐎硅棄瀹?缁旑垳鍋ｉ柧鍙ョ窗闁偓閸?|
   * | `coverSquare` | 鐏忎線娼扮€逛粙鐝?閳?1vp | 鐏忎線娼扮悮顐㈠竾閹典緤绱檂constraintSize` / `layoutWeight` 閹额澀绨＄粚娲？閿涘鍣?缂侇參顥ｇ亸渚€娼伴拃鎴掔秴娴兼俺鐑?|
   * | `metaGapOk` | 濮濆苯鎮曟い鎯扮珶 閳?鐏忎線娼版惔鏇＄珶 閳?1vp閿涘牅绗夐柌宥呭綌閿?| **濮濆苯鎮曢崢瀣躬婢堆冪殱闂堫澀绗?* 閳?閻劍鍩涢幎銉ф畱"闁挎瑤缍?閻ㄥ嫪绔寸粔?|
   * | `metaOrder` | 濮濆本澧滄い鎯扮珶 閳?濮濆苯鎮曟い鎯扮珶閿涘牊鐡曢幍瀣躬濮濆苯鎮?*娑撳娼?*閿?| 娑撱倛顢戞い鍝勭碍閸欏秳绨?|
   * | `metaInWin` | 濮濆苯鎮?濮濆本澧滄惔鏇＄珶 閳?缁愭褰涙?| 濮濆苯鎮曠悮顐ｅ皨閸戝搫鐫嗛獮鏇礄閸樺棗褰舵稉?閸嬪繋缍?164vp"闁絼閲?bug 閻ㄥ嫬鑸伴悩璁圭礆 |
   * | `miniClear` | 鐏忓繑鐡曠拠宥夈€婃潏?閳?濮濆本澧滄惔鏇＄珶閿?*鐏忓繑鐡曠拠宥勭瑝娑撳孩鐡曢崥宥夊櫢閸?*閿?| 閳?鏉╂瑦顒滈弰顖滄暏閹撮攱濮ら惃鍕┾偓灞炬尡閺€鍓ф櫕闂堛垽鏁婃担宥冣偓宥忕礄鎼?7 閻?`MINI_LYRIC_SINK_VP=44` 娣囶喚娈戦敍?|
   * | `branchSane` | 閸氬奔绔寸仦?*閸欘亝婀佹稉鈧弨?*閿涘潉usePanel` 娑?`phoneSwiper` 娑撳秴鎮撻弮鑸靛Ω閸氬奔绔撮崸妤€鍞寸€硅澧禒妯肩舶娑撱倗顫掔紒鎾寸€敍?| 閸掋倖宓侀柌宥呭綌閸栭缚顫﹂煪鈺佸煂 閳?閸忓牅鎱ㄩ崚銈嗗祦閸愬秷鐨ョ敮鍐ㄧ湰 |
   *
   * ## 鐎瑰啩绮犻崫顏勫姽鐞氼偉鐨熼敍鍫氭 鏉╂瑤绔村▓鍨拱闊偅妲告稉顏勭杽濞村绮ㄧ拋鐚寸礆
   *
   * 閳跨媴绗?**娑撳秷鍏橀惄瀛樺复閸愭瑥婀?`@Builder` 娴ｆ捇鍣?* 閳ユ柡鈧?閺堫剝鐤嗙€圭偞绁寸紓鏍槯閹躲儵鏁婇敍?
   *   `'this.logBranchSurface('wide')' does not meet UI component syntax`
   *   閿涘湏rkTS 閻?`@Builder` 娴ｆ挸褰ч幒銉ュ綀 **UI 缂佸嫪娆㈢拠顓熺《**閿涘鈧?
   * 閳?閻滄澘婀幐鍌氭躬**娑撳娼崚鍡樻暜閸氬嫯鍤滈惃鍕壌鐎圭懓娅?*閻?`.onAppear()` 娑?閳ユ柡鈧?闁絼绔撮弨?*妫ｆ牗顐奸幐鍌濇祰**閺冩儼袝閸欐垳绔村▎鈽呯礉
   *   閹靛婧€閳柨顔旂仦蹇婂晬闂堛垺婢樻禍鎺旀祲閸掑洦宕查弮璺烘倗閺夈儰绔村▎鈽呯礄瑜般垹褰夐張鐔兼？娑撳秳绱扮憴锕€褰傞敍澶堚偓?
   *   閻╊喖澧犻幐鍌欑啊娑撳顦╅敍姘啍鐏炲繘鍋呴弨顖滄畱 `Column`閵嗕焦澧滈張娲亝閺€顖滄畱 `Swiper`閵嗕線娼伴弶鍧楀亝閺€顖滄畱閺?`Stack`閵?
   *   `branch` 閸欏倹鏆熼悽?*閸氬嫯鐨熼悽銊у仯閼奉亜绻佹竟鐗堟**閿涘牆鐣犵€涙娼版稉濠傛皑閻儵浜鹃懛顏勭箒閺勵垵鐨濋敍澶堚偓?
   *
   * ## 娑撹桨绮堟稊鍫濆讲娴犮儳娲块幒銉ュ晸閸?`@Builder` 闁?
   *
   * 閿涘牊顒濋弶鈥冲嚒娴ｆ粌绨?閳ユ柡鈧?鐟欎椒绗傞妴淇橜Builder` 娴ｆ挸褰ч幒銉ュ綀 UI 缂佸嫪娆㈢拠顓熺《閿涘本澧嶆禒銉﹀瘯閸?`.onAppear()`閵嗗偊绱?
   *
   * 閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdBranch'`
   * 閳跨媴绗?閸欘亣顕伴敍姘瑝閸愭瑤鎹㈡担鏇犲Ц閹緤绱檂lastBranchLog` 閸欘亝妲搁弮銉ョ箶閼哄倹绁﹂悽銊ф畱鐎涙顑佹稉璇х礆閵?
   * @param branch 瑜版挸澧犻崚鍡樻暜閸氬稄绱?phone' / 'wide' / 'panel'閿?
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
    // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 娑撳秴褰夐柌蹇氬殰濡偓閿涘牆鍙忛柈銊︽Ц"娑撳秵鍨氱粩瀣鐠囩鐦?閻ㄥ嫬鑸板蹇ョ礉闁灝鍘ら弮銉ョ箶闁插奔绔撮崼?true閿?閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
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
    // 閳?鏉╂瑦娼亸杈ㄦЦ閻劍鍩涢幎銉ф畱閵嗗本鎸遍弨鍓ф櫕闂堛垽鏁婃担宥冣偓宥囨畱閺堝搫娅掗崚銈嗗祦閿涘煪?7 閻?MINI_LYRIC_SINK_VP 娣囶喚娈戦柇锝嗘蒋閿涘鈧?
    if (lyric !== undefined && singer !== undefined && lyric.y < singer.y + singer.height - 1) {
      bad.push(`miniClear(lyric.y=${lyric.y.toFixed(0)}<singer.b=${(singer.y + singer.height).toFixed(0)})`);
    }
    // 閸掋倖宓侀柌宥呭綌閸栫尨绱癕D + 濡亜鐫嗛弮?usePanelLayout() 娑?usesPhoneSwiperLayout() 閸欘垵鍏橀崥灞炬娑撹櫣婀￠妴?
    // 閻滄澘婀棃?`if` 妞ゅ搫绨崗婊€缍囬敍鍫ユ桨閺夎儻鍎ㄩ崙鐚寸礆閳?閸欘亣顩?闂堛垺婢橀弨顖炲櫡鏉╂顓绘稉楦垮殰瀹歌鲸妲?phoneSwiper"閿涘苯姘ㄩ弰顖炴閹絻鈧?
    const panel: boolean = this.usePanelLayout();
    const phoneSwiper: boolean = this.usesPhoneSwiperLayout();
    if (panel && phoneSwiper && branch !== 'phone') {
      bad.push('branchSane(panel閳箲honeSwiper both true)');
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
      // 閳跨媴绗?缁岀儤鏆熺紒鍕洣閹垫挻鍨?`ok`閿涘奔绗夐懗鑺ュⅵ缁岃桨瑕?閳ユ柡鈧?閸氾箑鍨?閺冦儱绻旈柌宀勫亝娑撯偓濞堝灚鐥呮禍?閸?濞屄ゅ殰濡偓"閸掑棔绗夊〒鍛偓?
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
   * @returns 閺勵垰鎯佺挧鑸偓灞惧閺?Swiper閵嗗秹鍋呮稉鈧弨顖氱鐏炩偓閿涘牆鐨濋棃銏ゃ€?/ 濮濆矁鐦濇い?*濡亜鎮滈崚鍥ㄥ床**閻ㄥ嫰鍋呮總妤嬬礆閵?
   *
   * 閳藉應妲?2026-10-15閿涘牏顑囨稊婵婄枂璺?*閺€瑙勵劀娑撯偓婢?濞夈劑鍣存稉搴＄杽閻滈绗夌粭?**閿涘绱?
   *   閸樼喐鏁為柌濠傚晸閻ㄥ嫭妲搁妴灞藉灲閹诡喕绗?`buildControlStack()` 闁插矂鍋呮稉?`if` 閻ㄥ嫬褰囬崣?*闁劕鐡ф稉鈧懛?*閿?
   *   `SM`閿涘牅绗夌拋娲彯閿涘鍨?**`MD + HEIGHT_SM`**閵嗗秮鈧柡鈧?
   *   閳跨媴绗?**鐎圭偟骞囬柌灞筋嚠 MD 楠炶埖鐥呴張澶愮彯鎼达附娼禒?*閿涘牆姘ㄩ弰?`widthBp === WIDTH_MD` 閺堫剝闊╅敍澶堚偓鍌欒⒈閸欍儰绗夋稉鈧懛杈剧礉
   *   閼板奔绗?*娑撳秳绔撮懛瀵告畱闁絼閲滈弬鐟版倻閺?鐎圭偟骞囬弴鏉戭啍"**閿涘湣D + 娴犵粯鍓版妯哄闁€熺箲閸?true閿涘鈧?
   *
   *   閻滄澘婀惃鍕杽闂勫懓顕㈡稊澶涚礄閻撗冪杽閻滄澘鍟撻敍?*閺堫亝鏁肩悰灞艰礋**閿涘绱?
   * ```
   *   widthBp === SM                      閳?true
   *   widthBp === MD                      閳?true      閳?閳跨媴绗?娑撳秴鎯堟妯哄閸掋倖鏌?
   *   閸忔湹缍戦敍鍦燝 / XL閿?                     閳?false
   * ```
   *   閳?鐎瑰啯鐦?`buildControlStack()` 闁絾娼?`if` 閻ㄥ嫬褰囬崣?*婢舵艾鎳℃稉?MD + 闂?HEIGHT_SM"**鏉╂瑤绔村锝冣偓?
   *
   * ## 閳?娑?`usePanelLayout()` 閻?*闁插秴褰旈崠?*閿涘牆鍑￠惂鏄忣唶閿涘苯鍩嗛崷銊ㄧ箹闁插苯浼旈崑閿嬫暭閿?
   *
   * ```
   *   usePanelLayout() 閸?(濡亜鐫?&& widthBp !== SM) 閺冩湹璐熼惇?
   *   閳?闁插秴褰?= 閵嗘劖铆鐏炲繈鈧垯鈧伄idthBp === MD閵?
   * ```
   * 婵傝棄顦╅弰?`buildControlStack()` 闁?`if (usePanelLayout())` **閸︺劌澧?* 閳?闂堛垺婢橀弨顖濆劏閸戞亽鈧?
   * 鐟曞棛娲婄仦鍌濐潶閺堫剙鍤遍弫鐗堝皡閹?閳?**娑撳秳绱伴悽璁宠⒈娴犺棄鐨濋棃?*閿?
   * 閸у繐顦╅弰顖濈箹鐏炵偘绨?**闂?if 妞ゅ搫绨崗婊€缍?*"閿涘奔绗夐弰?閸掋倖宓佹禍鎺撴灱"閵?
   * 閳跨媴绗?**閺堫剙鍤遍弫鎷岀箷缁狅紕娼?`isPhoneLyricsStyleBackdropLayout()`閿涘牐鍎楅弲顖涚壉瀵繘鎽奸敍?* 閳?
   *   閹跺﹤鐣犻弨鍓佺崕閹?`&& !usePanelLayout()` 閺?*閸欘垵顫嗙悰灞艰礋閸欐ê瀵?*閿涘牊铆鐏炲繗鍎楅弲顖涚壉瀵繋绱伴崣姗堢礆閿?
   *   閼板本铆鐏炲繐鑸伴幀浣规拱閺堟椽鐛欐稉宥勭啊 閳?**閸忓牆鍠呴弶鈥叉**閿涙瓪RzdBranch` 閸︺劎婀￠張杞扮瑐闁插繐鍤柌宥呭綌閸栬櫣娈戠€圭偤妾崚鍡樻暜
   *   閿涘潉branchSane` 閺傤叀鈻堥敍澶夌閸氬函绱濋崘宥呭枀鐎规碍鏁规稉宥嗘暪缁愬嫨鈧倻娅ョ拋鏉款槱閿?
   *   `_recover/logic-src/閻╊喗鐖ｉ埗?鐎硅棄鐫嗛棃銏℃緲缂佺喍绔?閺傝棄浼愰崶鍙ョ瑢妤犲本鏁?md` 鎼?閵嗗苯鍨介幑顕€鍣搁崣鐘偓宥冣偓?
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

  // 閳藉應妲?2026-10-15閿涘牏顑囨稉澶婂磩娑旀繆鐤?/ Round 20閿涘绱癭@Builder phoneSwiperBackdropImage()` **瀹告彃鍨归梽?* 閳ユ柡鈧?
  //   鐎瑰啳鍤滃杈╂畱 JSDoc 鐏忓崬鍟撻弰?`grep -n "phoneSwiperBackdropImage"` 閸欘亝婀佺€规矮绠熸径鍕箹娑撯偓娑擃亜鎳℃稉?閳?閺堫剚娼电亸杈ㄦЦ濮濊鍞惍?閿?
  //   閸掔娀娅庨崥?`backgroundImageSource()` 娑旂喖娈㈡稊瀣祩鐠嬪啰鏁ら懓鍜冪礄娑撱倛鈧懍绔寸挧铚傜瑓缁惧尅绱氶妴?
  //   閸掔娀娅庢笟婵囧祦娑撳簼楠囬悧鈺冾儊閸欑柉鍤滃Λ鈧敍鍧dules.abc GONE閿涘顫?RzdMusic鐠佹澘绻?md 鎼?6.15閵?

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
            // 楠炶櫕婢?濡楀矂娼伴敍娆竢idRow 瀹革箑褰搁崚鍡樼埉閿涘牆鐨濋棃?| 濮濆矁鐦濋敍澶涚礉妞ゅ爼鍎?padding 鐠佲晙缍呯紒娆戠埠娑撯偓 TopArea
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
                    // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻?/ 閻╊喗鐖?閳讹絻鈧苯顔旂仦寰涚兘娼伴弶澶歌⒈閸掑棙鏁紒鐔剁閵嗗稄绱氶敍?
                    //   閺冪姷鏅?*濞屸剝婀?* `LyricsComponent` 閸愬懎缂?濮濆苯鎮?- 濮濆本澧?鐞涖劌銇旀潻娆忔礀娴?
                    //   閿涘潉_recover/logic-src/濮濆矁鐦濇い鍨癁鐏炲倸鐨濋棃顫瑢濮濆苯鎮曠€规氨顭?md` L1449 閸樼喐鏋冮敍?
                    //   閵嗗本妫ら悾灞剧梾閺?`LyricsComponent` 閸愬懎缂?header 鏉╂瑥娲栨禍瀣ㄢ偓宥忕礆閵?
                    //   閳跨媴绗?閹靛婧€闁絼绔撮弨顖ょ礄娑撳娼?L2002 闁絽顦╅敍澶岊儑 1 閸ф鍑＄紒蹇庣炊娴?`true`閿?
                    //      閼?*鐎硅棄鐫?闂堛垺婢樻潻娆庤⒈婢跺嫬缍嬮弮鑸电础娴?* 閳ユ柡鈧?閸欏牊妲?
                    //      鎼?6.1.6 / 鎼?6.16 / 鎼?6.17 闁絼閲滈妴灞芥倱娑撯偓瑜般垻濮搁張?N 婢跺嫨鈧礁褰ч弨閫涚啊娑撯偓婢跺嫨鈧秶娈戦懓浣圭樅閻ュ懌鈧?
                    //   閸愭ぞ缍戦弰顖氱杽閹垫挸鐤勯惃鍕剁窗閺堫剙鍨庨弨顖欑瑐闂堛垹姘ㄩ張?`MusicPlayInfoBlock`閿涘湢1908閿涘婀弰鍓с仛
                    //   鐏忎線娼?+ 濮濆苯鎮?+ 濮濆本澧?閳?濮濆矁鐦濋崘宥堝殰閹躲儰绔村▎鈥虫皑閺?閸氬奔绔存＃鏍ㄧ摃閸氬秴鍤悳棰佽⒈濞?閵?
                    //   閳?閽樺繑甯€鐎?*娑撳秳娑禒璁崇秿娣団剝浼?*閿涘奔绗栨稉搴㈡￥閻ｅ瞼娈戠憴鍌涘妳娑撯偓閼锋番鈧?
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
            // 閳藉應妲?閻╊喗鐖?閳?閻?*閸掑棙鏁ぐ鎺戠潣鐠囧﹥鏌?*閿涘牐顫?`logBranchSurface()` 閻ㄥ嫭鏁為柌濠忕礆閵?
            //   閳跨媴绗?**韫囧懘銆忛幐鍌氭躬 `.onAppear()` 闁插矉绱濇稉宥堝厴閻╁瓨甯撮崷?`@Builder` 娴ｆ挸鍞寸拫鍐暏** 閳ユ柡鈧?
            //      ArkTS 閻?`@Builder` 娴ｆ挸褰ч幒銉ュ綀 **UI 缂佸嫪娆㈢拠顓熺《**閿涘瞼娲块幒銉ュ晸閺傝纭剁拫鍐暏娴兼氨绱拠鎴炲Г闁?
            //      閿涘牊婀版潪顔肩杽濞村绱癭'this.logBranchSurface('wide')' does not meet UI component syntax`閿涘鈧?
            //   閳跨媴绗?娑?*娑撳秷鍏?*閹稿倸婀?闁絼绔撮弨顖滄畱閺嶇懓顔愰崳?娑撳﹤姘ㄦ禒銉よ礋婢剁喍绨￠敍姘崇箹闁插本瀵曢崷?`Column` 娑撳绱?
            //      鐎瑰啫褰ч崷?*閺堫剚鏁＃鏍偧閹稿倽娴?*閺冩儼袝閸?閳?閹靛婧€閳柨顔旂仦蹇婂晬闂堛垺婢樻禍鎺旀祲閸掑洦宕查弮璺烘倗閺夈儰绔村▎鈽呯礉
            //      瑜般垹褰夐張鐔兼？娑撳秳绱伴崚宄扮潌閿涘潉logBranchSurface` 閸愬懘鍎存潻妯绘箒娑撯偓鐏炲倻顒烽崥宥堝Ν濞翠緤绱氶妴?
            .onAppear((): void => {
              this.logBranchSurface('wide');
            })
          } else {
            // 閹靛婧€閿涙瓔wiper 鐏忎線娼?濮濆矁鐦濆鎴濆З + 鎼存洟鍎撮幒褍鍩楅崠?
            Column() {
              // 閳藉應妲勯埥?2026-10-16閿?*閻劍鍩涢惇鐔告簚閹搭亜娴樼敮锕€鍤惃鍕６妫版﹫绱板宀冪槤妞ら潧鐨濋棃銏＄梾閸欐ê鐨?*閿?
              //
              // ## 鐠囩粯鏆熼敍鍫㈡暏閹?2026-10-16 22:42 閹搭亜娴橀敍?
              // ```
              //   V d73f1b8 閳?scale=1.000 p=1.000
              //   real=1 clone=0 snap=30/30 end=331/331 op=1.000 stage=2 drv=0
              //   閳?edge=331 t=0.00        閳?閳?鐏忚鲸妲告潻娆庣鐎电櫢绱皌 閸嬫粌婀?0 閳?鐏忎線娼?= 331閿涘牊鏆ｇ粣妤呭亝娑撯偓娴犳枻绱?
              // ```
              //   鐏忎線娼扮亸鍝勵嚟 = `lyricMorph(lyricMorphT).size`閿涘矁鈧?`lyricMorphT` 閸欘亝婀?0/1 娑撱倓閲滅粙鍐茬暰閸婄》绱?
              //     `t=0` 閳?鐏忎線娼?= `endCoverSize`閿涘牃澧?31閿涘苯銇囩亸渚€娼伴敍澶涚幢`t=1` 閳?`lyricCoverSizeOf()`閿涘牃澧?8.7閿涘苯鐨亸渚€娼伴敍?
              //   閳?閵嗗苯鐨濋棃銏＄梾閸欐ê鐨妴宥佸⒍ **`lyricMorphT` 濞屸€冲煂 1**閵?
              //
              // ## `lyricMorphT` 閻ㄥ嫬鏁稉鈧崘娆忓弳閼板懏妲?`animateLyricMorph`閿涘矁鈧苯鐣犻崣顏冪矤鏉╂瑩鍣风悮顐ョ殶
              // ```
              //   .onAnimationStart((index, targetIndex) => {
              //     if (index === targetIndex && !this.lyricMorphVisible) { return; }   // 閳?鐎瑰牆宕?
              //     this.animateLyricMorph(targetIndex === SWIPER_INDEX_LYRIC);
              //   })
              // ```
              //   閳跨媴绗?鏉╂瑤閲滅€瑰牆宕奸惃鍕嚔娑斿妲?**瀹歌尙绮￠崷銊ф窗閺嶅洭銆夋禍?*閿涘潉index === targetIndex`閿涘奔绗夐弰顖欑濞嗭紕婀″鎴濆З閿?
              //     鐏忚精鐑︽潻? 閳ユ柡鈧?閼?`Swiper` **濞屸剝婀佺紒鎴濈暰 `.index()`**閿?
              //     `playbackSwiperIndex` 閸欘亞鏁?`.onChange` 閸愭瑣鈧礁鑻熼崷?`onAppear` 闁插矁顫︽径宥勭秴閹?0閵?
              //   閳?閸欘亣顩?闁插秵瀵曟潪鑺ユ swiper 閻ㄥ嫬鍨垫慨瀣€?閳?閻樿埖鈧線鍣烽惃鍕€?閿涘矂銆夋稉搴ｅЦ閹礁姘?*闂€鎸庢埂娑撳秳绔撮懛?*閿?
              //     閻樿埖鈧浇顔囬惈鈧宀冪槤妞ょ偣鈧够wiper 閸嬫粌婀粭?0 妞ょ绱欓幋鏍у冀娑斿绱氶埇?閻劍鍩涢惇瀣煂濮濆矁鐦濇い纰夌礉
              //     娴ｅ棙鐥呴張澶夋崲娴?濠婃垵濮?閸欐垹鏁?閳?`animateLyricMorph` **娴犲孩娼靛▽陇顫︾拫鍐暏** 閳?`lyricMorphT` 閹?0
              //     閳?鐏忎線娼伴幁鎺嶈礋婢堆冪殱闂堫潿鈧?*鏉╂瑤绗岄幋顏勬禈鐎瑰苯鍙忛崥璇叉値**閵?
              //
              // ## 閺€瑙勭《閿涘牊濡搁悩鑸碘偓浣规簚閹恒儱娲栭崢浼欑窗鐠?swiper 閻ㄥ嫬鍨垫慨瀣€?= 閻樿埖鈧線鍣烽惃鍕€夐敍?
              //   `.index(this.playbackSwiperIndex)` 閳ユ柡鈧?鏉╂瑦妲?ArkUI `Swiper` 閻ㄥ嫬鐣奸弬鐟扮潣閹嶇礉
              //   閼板本鍨滄禒顒佹拱閺夈儱姘ㄩ幎濠呯箹娑擃亜鈧厧缍?瑜版挸澧犳い?閻㈩煉绱檂.onChange` 閸愭瑥鐣犻妴涔nAppear` 婢跺秳缍呯€瑰喛绱氶妴?
              //   閳跨媴绗?**娑撳秴绱╅崗銉ゆ崲娴ｆ洘鏌婇弫鏉库偓?*閿涙艾鐣犻弰?閹跺﹤鍑￠張澶屾畱閻樿埖鈧焦甯撮崚鎷岊潒閸ュ彞绗?閿涘苯鐫樻穱顔荤閼峰瓨鈧嗏偓灞肩瑝閺勵垵鐨熼崣鍌樷偓?
              //   閳跨媴绗?閵?026-10-16 鐠併垺顒滈妴鎴ｇ箹闁插苯甯弶銉ュ晸閻偓"`onAppear` 闁插矂鍋呴崣?
              //      `playbackSwiperIndex = 0` 娴犲秳绻氶悾? 閳ユ柡鈧?**闁絽褰炲鑼病閸掔姵甯€娴?*閿?
              //      鐎瑰啯妲搁懞鍌滃仯缁狙冩礀鐠嬪啴鍣烽惃鍕晸閸忋儻绱濇导姘閹哄鏁ら幋宄扮秼閸撳秹銆夐敍?
              //      "閹垫挸绱戦幘顓熸杹閸ｃ劌娲栫亸渚€娼版い?閺?*閹垫挸绱戦幇蹇撴禈**閻ㄥ嫯浜寸拹锝忕礄鐟欎礁鍞寸€圭懓鐪?`onAppear` 闁絾顔岄梹鎸庢暈闁插绱氶妴?
              //   婢跺秵鐗抽崗鎶芥暛鐎涙绱板鑺ョ垼**缁楊兛绔风悰?* `sw=` / `tgt=`閿涘牊鏌婇崝鐙呯礆閳ユ柡鈧?
              //     `sw=1 tgt=1` 閹靛秵妲稿宀冪槤妞ょ數娈戝锝呯埗閹緤绱盽sw=0` 閼板奔缍橀崷銊︾摃鐠囧秹銆?閳?鐏忚鲸妲搁張顒佹蒋閵?
              Swiper() {
                Stack({ alignContent: Alignment.Bottom }) {                  // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*妞?0 閺勵垳鈹栨竟?*閵?
                  //   閺冪姷鏅惃?`playerPane` 闁?`Swiper` 娑撱倝銆夐柈钘夊涧閺?`Column().width/height('100%')`閿?
                  //   **鐏忎線娼版稉搴㈢摃閸氬秵鐗撮張顑跨瑝閸︺劑銆夐柌?*閿涘矁鈧苯婀?`Swiper` 娑斿顦婚惃鍕洬閻╂牕鐪?
                  //   閿涘潉floatingCover` / `floatingMeta`閿涘矁顫?`PlayerPage鐎瑰本鏆I鐎规氨顭?md` 鎼? / 鎼? / 鎼?閿涘鈧?
                  //   閳?鏉╂瑩鍣烽崚鐘冲竴 `MusicPlayInfoBlock`閿涙艾鐣犻懛顏勭敨鐏忎線娼?+ 濮濆苯鎮曢敍?
                  //     閻ｆ瑧娼冪亸鍙樼窗閸滃矂鍋呮稉?*閸烆垯绔撮惃鍕洬閻╂牕鐪?*閻㈢粯鍨氭稉銈勫敜鐏忎線娼伴妴?
                  //   閳跨媴绗?鐎瑰啫甯弶銉ф畱娑撱倓閲滈懕宀冪煑閿涘潉.id(PLAYER_BIG_COVER_ID)` + `reportBig`閵?
                  //      `.id(PLAYER_META_*_ID)` + `publishMeta`閿?*瀹歌尙绮￠幖顒€鍩岀憰鍡欐磰鐏?*閿涘牐顫?
                  //      `reportPlayerCoverFromOverlay` / `publishMetaEndpoint`閿涘鈧柡鈧?
                  //      鏉╂瑦妲告潻娆愵偧閼宠棄鍨归惃鍕閹绘劧绱辨稉濠佺鏉烆喖姘ㄩ弰顖涚础娴滃棜绻栨稉鈧銉礉鐎佃壈鍤?鐏忎線娼板☉鍫濄亼 + 閸斻劎鏁鹃崗銊ョ熬"閵?
                  //   閳跨媴绗?鐎硅棄鐫?闂堛垺婢橀柇锝勮⒈閺夆€冲瀻閺€顖欑矝閸︺劎鏁ょ€瑰喛绱檂PlaybackPage` 閸愬懎褰熼張澶夎⒈婢跺嫸绱氶敍?
                  //      閹碘偓娴?import 娣囨繄鏆€閵?
                  Column() {
                    MiniLyricLinesComponent()
                      .width(StyleConstants.FULL_WIDTH)
                      .margin({
                        left: 4,
                        right: 4
                        // 閴€?2026-10-17閿?*閸樼粯甯€鐠愮喎顦绘潏纭呯獩** 閳ユ柡鈧?閹稿绗傚〒?gemini 婢跺秵鐗崇紒鎾诡啈閿?
                        //   妞?0 闁插瞼娈戦崘鍛啇韫囧懘銆?*濞翠礁绱?*閹烘帒绔烽崷銊︽拱妞ら潧顔愰崳銊╁櫡閿?*娑撳秷顔忛悽銊х卜鐎电懓鐣炬担?鐠愮喎顦绘潏纭呯獩
                        //   閹跺﹤鐣犻幒銊ュ煂濮濆苯鎮曠悰宀勫亝娑撯偓閺夆€崇敨**閿涘苯鎯侀崚娆忚埌閸欐ɑ婀℃导姘瑢濮濆苯鎮曠悰灞烩偓浣界箻鎼达附娼惄鍛婃寬閵?
                        //   閸樼喐娼垫潻娆撳櫡閺?`bottom: -MINI_LYRIC_SINK_VP`閿涘牊濡哥€瑰啫绶氭稉瀣腹 112vp 閸?闁灝绱戝灞芥倳"閿涘绱?
                        //   閼板本鐡曢崥宥堫攽閻滄澘婀鍙夋暭閻?*妞ら潧鍞撮崸鎰垼**閿涘牅绗傚〒绋垮經瀵板嫸绱氶埇?娑撳秴鍟€闂団偓鐟曚浇绻栨稉顏囁夋稉渚婄礉
                        //   閻ｆ瑧娼冮崣宥堚偓灞肩窗閹跺﹤鐣犻幒銊ュ煂閺囩繝绗呴棃銏犲箵閹剧偠绻樻惔锔芥蒋閵嗗偊绱?
                      })
                      // 鐏忓繑鐡曠拠宥呯潣娴?閸愬懎顔?閿涙艾寮界紓鏍槯闁?`contentOpacity` 閽€鎴掔秴閹靛秶鐤?1
                      .opacity(this.expandState.morphContentOpacity)
                      // 閳藉應妲?2026-10-15 閻劍鍩涚€规俺鐨熼敍姘モ偓?*閸忓牓顥ｉ崗銉ф畱閺勵垰鐨宀冪槤閸滃本鏁归挊蹇斿瘻闁?*閵?
                      //   閳?鐏忓繑鐡曠拠宥堣泲**缁楊兛绔寸紒?*閻ㄥ嫭妞傞梻瀵哥崶閿涘潉earlyRiseVp()`閿涘本妫禍搴㈠付閸掕泛灏柇锝勭缂佸嫸绱氶敍?
                      //   娴犲簼绗呴崡鍥崳 180vp閿涙盯娼ゅ銏♀偓浣风秴缁夌粯浜?0閿涘瞼澧楅棃銏も偓鎰剼缁辩姳绗夐崣妯糕偓?
                      .translate({ y: this.expandState.contentRiseVp() })
                      // 閺€鎯版崳鏉╁洨鈻兼稉顓炲敶鐎圭顫﹂崢瀣閿涘苯鐨宀冪槤娴兼艾鎷伴幒褍鍩楅崠杞扮鞍閻╁摜娲婃担?
                      // 閳藉應妲勯埥?2026-10-17閿涘牏鏁ら幋鍑ょ窗**閵嗗苯鐨宀冪槤閻滄澘婀崣妯诲灇娴滃棗濮╅悽鑽ょ波閺夌喍绠ｉ崥搴㈠閸戣櫣骞囬敍灞炬暭娑撯偓娑撳绱?
                      //   閸欏倽鈧啫鍙剧€瑰啫娼￠幀搴濈疄妞嬬偛鍙嗛妴?*閿涘鍣?閹俱倕娲栨稉濠佺閻?瑜般垹褰夐張鐔活唨瀵偓"閻ㄥ嫰娈ｉ挊蹇涙，閿?
                      //   鐎瑰啫鎷伴崚顐ゆ畱閸фぞ绔撮弽鍑ょ礉**瑜般垹褰夐張鐔锋皑鐠囥儱婀崷?*閵嗕浇铔嬬粭顑跨缂佸嫭妞傞梻瀵哥崶 `earlyRiseVp()` 娴犲簼绗呴崡鍥崳
                      //   閿涘牅绗傞棃銏ゅ亝閺?`.translate`閿涘鈧倻顫幘鐐烘６妫版鏁卞灞芥倳鐞涘本鏁兼い闈涘敶閸ф劖鐖ｇ憴锝呭枀閿涘奔绗夐棃鐘烘鐎瑰啨鈧?
                      .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
                  }
                  // 閳?2026-10-15 鐠囧﹥鏌囬柨姘卞仯閿涘潉hdc shell hilog -x | Select-String 'RzdBoxes'`閿涘绱?
                  //   閹?*娑撳閲滄导姘鞍閻╃甯囬惃鍕健**閻ㄥ嫮鐛ラ崣锝囩叐瑜邦澀绔村▎鈩冨ⅵ閸戠儤娼?閳ユ柡鈧?
                  //     `lyric` 鐏忓繑鐡曠拠?/ `title` 濮濆苯鎮?/ `singer` 濮濆本澧?/ `cover` 婢堆冪殱闂堫潿鈧?
                  //   閸掋倖宓侀敍姝歭yric.top` 娑?`singer.bottom` 閻╅晲姘?閳?鐏忚鲸妲搁悽銊﹀煕閹躲儳娈?鏉╂瑩鍣烽柨娆庣秴"閿?
                  //         娑撳秶娴夋禍銈堚偓灞肩矝閻娼冮崢瀣躬娑撯偓鐠?閳?闁絾妲?*缂佹ê鍩?*閿涘澃cale/clip閿涘鈧奔绗夐弰顖涘笓閻楀牞绱濋崣锔藉閵?
                  .id(PlaybackPage.MINI_LYRIC_BOX_ID)
                  .onAreaChange((): void => {
                    this.logLayoutBoxes();
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                // 閳?濮濆苯鎮?濮濆本澧滈柇锝勭鐞?*閸欘亣铔嬫い鑸电埉闁絼绔村?*閿涘潉pullChromeOpacity = clamp((effT-0.18)/0.44)`閿?
                //   0.18 閳?0.62閿涘绱濋崝銊ф暰鏉╁洨鈻兼稉顓炴皑鐠囥儲璐伴崗?閳ユ柡鈧?娑撳海鏁ら幋閿嬪閺夎法娈戠粭?2 閺夆€茬閼锋番鈧?
                //
                // 閳跨媴绗?鏉╂瑩鍣烽崢鐔告降鏉╂ê褰旀禍鍡曠鐏?`metaOpacityValue() = clamp(1 - morphP/0.35)`閿?
                //   闁?*閺勵垵绯犳担鐘虫蒋闁絼绔存笟褏娈戝ǎ鈥冲毉**閸忣剙绱￠敍鍧?0.35 鐏忓崬缍婇梿璁圭礆閿涘苯顨滈崷銊︽尡閺€楣冦€夋潻娆庣鐞涘奔绗?
                //   = 閻劋琚辨稉顏堟，婢剁懓鎮撴稉鈧崸妤€鍞寸€?閳ユ柡鈧?`pullChromeOpacity` 閺勫孩妲戝鑼病閸?1閿?
                //   閸楃顫?`metaOpacityValue` 閹稿鍩?0閿涘奔绨弰顖涚摃閸?濮濆本澧?*閸忋劎鈻兼稉宥呭讲鐟欎降鈧浇鎯ゆ担宥嗗閸愭帒鍤弶?*
                //   閿涘牏鏁ら幋宄扮杽濞村娈戦妴灞界潔瀵偓娑擃厽鏋冪€涙娲块崚鎵波閺夌喐澧犻崙铏瑰箛閵嗗稄绱氶妴?
                //   閸掔姵甯€鏉╂瑤绔寸仦鍌︾窗`MusicPlayInfoBlock.MusicInfoTexts` 閼奉亜绻佸鑼病鐢?`pullChromeOpacity`閵?
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
                    // 閳?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*濮濆矁鐦濇い鍏哥瑝閸愬秷鍤滅敮?濮濆苯鎮?鐠囧秵娲?鐞涖劌銇?*閵?
                    //   閺冪姷鏅宀冪槤妞ょ敻銆婃稉濠傛皑閺勵垶鍋呮稉鈧弶鈩冭癁鐏炲倹铆鐞涘矉绱欑亸蹇撶殱闂?+ 濮濆苯鎮?+ 閺€鎯版/閺囨潙顦块敍澶涚礉
                    //   濮濆矁鐦濆锝嗘瀮闁插本鐥呴張澶岊儑娴滃奔閲滃灞芥倳閵嗗倸甯弶銉ㄧ箹闁插本妲?`isSmHeightMdLayout()`
                    //   閳?缁旀牕鐫嗘稉濠佺窗**閸氬本妞?*閸戣櫣骞囧ù顔肩湴閻ㄥ嫭鐡曢崥宥呮嫲濮濆矁鐦濋懛顏勭敨閻?
                    //   "閺堝顥撻弮鐘活棑閻ㄥ棜鍤滈悽?- 閻滃绔存担?/ 鐠囧稄绱伴棃鎺撶厷"閿涘矁顫囬幇鐔锋皑閺?濮濆苯鎮曢崙铏瑰箛娑撱倖顐?閵?
                    hideLyricsMetaHeader: true,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                // 閳藉應妲勯埥?2026-10-17閿?*鏉╂瑤绔撮崸妤佺ゴ闁插繐鍑℃禒?閸掋倖宓?闂勫秶楠囨稉?閸濄劌鍙?** 閳ユ柡鈧?缂佹捁顔戝鏌ユ４閸氬牞绱氶敍?
                //   娑撳﹥濮ゅ宀冪槤妞ら潧鍞寸€瑰湱娲呴惃?*缁愭褰涙い鎯扮珶**閵嗗倸缍嬮崚婵嗗鐎瑰啯妲告稉杞扮啊鐎?`lyricPadTop()` 鐟曚椒绗夌憰浣瑰床缁犳娼楅弽?閿?
                //   閺冪姷鏅柇锝勯嚋 `boxH/2 + bottomYAtLyric` 閸氬牐鎹ｉ弶銉ユ皑閺?濞搭喖鐪版惔鏇＄珶**閻╃顕惄鎺椼€?*"閿?
                //   閼板本婀版禒鎾村瑏**缁愭褰涢崸鎰垼**瑜版挾娲呴崘鍛祲鐎靛綊鍣洪悽?閳?閸欘亜婀惄鎺椼€?閳?0 閺冨墎鐡戞禒鏋偓?
                //   閴?**閺€璺虹啲缂佹捁顔戦敍姘辨磪妞ゅ墎绮ㄩ弸鍕瑐鐏忚鲸妲?0**閿?閻?= Swiper 閻ㄥ嫮娲呴敍姹紈iper 閹碘偓閸︺劎娈?`Column`
                //     娑?`LyricFloatLayer()` 閺勵垰鎮撴稉鈧稉顏冪瑝鐢?padding 閻?`Stack` 閻ㄥ嫬顒㈢€涙劧绱濇稉鏃囶嚉 `Stack`
                //     閻ㄥ嫬鍞寸€瑰湱娲呭锔跨瑐鐟?= 缁愭褰涢崢鐔哄仯 閳ユ柡鈧?鐎瑰本鏆ｇ拠浣瑰祦闁炬崘顫?`PlayerExpandState.lyricBoxTopVp`閿?
                //     閳?**娑撳秹娓剁憰浣瑰床缁犳绱濇稊鐔剁瑝韫囧懎鍟€鐠囨槒绻栨稉顏呮殶**閵嗗倷绻氶悾娆庣瑐閹躲儱褰ф稉?鐏忓棙娼甸張澶夋眽閸?padding 閺冩儼鍏橀崣鎴犲箛"閵?
                //   閳跨媴绗?韫囧懘銆忛悽?`globalPosition`閿涘牏鐛ラ崣锝呮綏閺嶅浄绱氶敍瀹峱osition` 閺勵垳娴夌€靛湱鍩楃紒鍕閻ㄥ嫨鈧?
                //   閳跨媴绗?閸斻劎鏁炬稉顓炵暊閸欘垵鍏橀惉顒佹闂?0閿涘牆顔愰崳?`.scale/.translate` 閸欐ɑ宕叉潻鍥╂畱鐠囩粯鏆熼敍灞绢劀鐢潻绱氶敍?
                //     閸欘亝婀?*闂堟瑦顒涢幀?*閺勫孩妯夐棃?0 閹靛秷顕╅弰搴ｇ波閺嬪嫬褰夋禍鍡愨偓?
                .onAreaChange((_oldValue: Area, newValue: Area): void => {
                  this.expandState.reportLyricBoxTop(areaLengthToVp(newValue.globalPosition.y));
                })
                // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`PlayerPage.onLyricSwipe(offsetY)` 閳ユ柡鈧?**闁劖娼€靛綊缍?*閿?
                //
                // 閺冪姷鏅敍鍧刜recover/logic-src/PlayerPage.abc.txt:6938-6985`閿涘本瀵曢崷?`LyricsView` 娑撳绱氶敍?
                // ```ts
                //   onLyricSwipe(offsetY) {
                //     if (offsetY <= -SWIPE_TOGGLE_VP) {                 // 閳?娑撳﹥绮?
                //       if (entryAllowsManual(this.lyricImmersive)) {   // 閳?閳?鏉╂瑤绔撮弨?*閺堝妫?*
                //         hideChrome(); clearIdle();
                //       }
                //     } else if (offsetY >= 24) {                        // 閳?娑撳绮﹂敍鍫濈摟闂堛垽鍣?0x18 = 24閿?
                //       showChrome(); startIdle();                       // 閳?鏉╂瑤绔撮弨?*閺冪娀妫?*
                //     }
                //   }
                // ```
                // 閳?娑撱倕顦╂稉搴″斧鐎圭偟骞囬惃鍕▕閸掝偓绱欓柈钘夊嚒閹稿鐡ч懞鍌滅垳鐠併垺顒滈敍澶涚窗
                //   閳?闂冨牆鈧》绱伴幋鎴滄粦閸樼喐娼甸崘娆戞畱閺?**12**閿涘牊婀版禒鎾瑰殰鐎规氨娈戞稉鈧崡濠忕礆閿涘本妫ら悾?*娑撱倓鏅堕柈鑺ユЦ 24**
                //      閿涘牅缍嗛弨顖濊泲 `SWIPE_TOGGLE_VP`閵嗕線鐝弨顖涙Ц鐎涙娼伴柌?`ldai 0x18`閿?
                //        瑜版帗銆傜敮鎼佸櫤鐞?`MiniMorph濞撳弶鐓嬮弬閫涚瑢妞よ泛绨抽弽蹇旇窗閸忋儱鍙曞?md:171` 娑旂喐妲?`SWIPE_TOGGLE_VP | 24`閿涘鈧?
                //      閳跨媴绗?12 婢额亜顔愰弰鎾诡嚖鐟欙讣绱欓張顒€鐪伴弰?`parallelGesture`閿涘本鐡曠拠宥勭瀵扳偓娑撳﹥瀚嬬亸鍗烆檮 12vp閿涘鈧?
                //   閳?娑撳﹥绮﹂柇锝勭閺€顖氭躬閺冪姷鏅柌?*鐢?`entryAllowsManual` 闂?*閿涘矁鈧?
                //      `entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`閿?
                //      姒涙顓诲锝嗘Ц **AUTO**閿涘潉LyricEntryMode` 4 濡楋綇绱癘FF0/AUTO1/MANUAL2/BOTH3閿?
                //      鐟?`濮濆矁鐦濇い鍨癁鐏炲倸鐨濋棃顫瑢濮濆苯鎮曠€规氨顭?md` 鎼?閿涘鍣?**姒涙顓诲锝勭瑓娑撳﹥绮︽禒鈧稊鍫ュ厴娑撳秴浠?*閵?
                //      閺堫兛绮ㄥ▽鈩冩箒鏉╂瑤閲滈悽銊﹀煕鐠佸墽鐤?閳?閸欘亣鍏橀崣?*姒涙顓?*鐞涘奔璐熼敍鍫ｎ潌 `LYRIC_SWIPE_ALLOWS_MANUAL`閿涘鈧?
                //   閳跨媴绗?娑撳绮﹂柇锝勭閺€顖氭躬閺冪姷鏅柌?*濞屸剝婀侀梻?* 閳?閹存垳婊戦弮鐘虫蒋娴犳湹绻氶悾娆欑礄`showChrome` + 鐠х柉顓搁弮璁圭礆閵?
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
                  // 閳藉應妲?A2閿?*閹稿璇炵仦鍌濐唨娴?*閿涘牏鐡戞禒閿嬫￥閻ｅ瞼娈?`lyricPadTop()`閿涘鈧柡鈧?
                  //   鐠佲晜鐡曠拠宥嗩劀閺傚洣绗夐柦璇插煂妞ゅ爼鍎撮柇锝呯炊鐏忎線娼?+ 濮濆苯鎮曞ù顔肩湴鎼存洑绗呴妴?
                  //   `lyricPadTop()` 閼奉亜绻佹穱婵婄槈"濞搭喖鐪版稉宥呭讲閻劍妞傛潻鏂挎礀 0"閿涘潉!lyricFloat 閳?0`閿涘绱?
                  //   閹碘偓娴犮儴绻栭弶?padding 閸︺劌顔旂仦?/ 鐏忎線娼版潻妯荤梾闁插繐鍩岄弮鏈电瑢閺€鐟板З閸?*闁劕鍎氱槐鐘辩閼?*閵?
                  //   閳跨媴绗?閸欘亜濮╅悾娆戞閿?*濮濆矁鐦濋崘鍛啇娑撯偓娑擃亜鐡ф稉宥嗘暭**閵?
                  top: this.expandState.lyricPadTop()
                })
                // 濮濆矁鐦濈仦鐐扮艾"閸愬懎顔?閿涙瓪contentOpacity`閿涘牐鎯ゆ担宥嗗缂?1閿?
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
              // 閴€?2026-10-16閿?*閹俱倕娲栭幋鎴滅瑐娑撯偓鏉烆喖濮為惃?`.index()` 缂佹垵鐣?*閿涘绱?
              //   娑撳﹣绔存潪顔藉灉閸?`.index(this.playbackSwiperIndex)` 閺勵垱鍏?閹跺﹦濮搁幀浣瑰复閸掓媽顫嬮崶鍙ョ瑐"閿?
              //   娴?*閺冪姷鏅弽瑙勬拱娑撳秷绻栨稊鍫濅粵**閿涙艾鐣犻惃?`swiperProgress` 閻?`onContentDidScroll`
              //   闁劕鎶氶崘娆嶁偓涔nChange` **娑撳秴鍟?*鐎瑰喛绱欒ぐ鎺撱€傜€规氨顭?鎼?.2 闁劖娼€涙濡惍渚婄窗
              //   閵嗗畭@34*^1*#^1`閿涘潉onChange`閿涘190080-190110閿?*娑撳秴鍟?* `swiperProgress`閵嗗稄绱氶妴?
              //   閼?`.index()` 娑?闁劕鎶氶崘?progress"閺€鎯ф躬娑撯偓鐠ц渹绱版禍鎺旀祲閹垫挻鐏﹂敍?
              //   `Swiper` 閻ㄥ嫭鏆ｆい闈涘瀼閹广垺婀伴煬顐＄窗**缂堟槒绻?* index 0 閹靛秴鍩?1閿涘矁瀚?index 鐞氼偆绮︾€规艾娲?0閿?
              //   swiper 娴兼俺顫﹂幏钘夋礀閸?閳?閻劍鍩涢弽瑙勬拱閸掑洣绗夐崚鐗堢摃鐠囧秹銆夐妴?
              //   閳?閺€鐟版礀"**娑撳秶绮︾€?index閿涘本鏁奸悽?`onContentDidScroll` 妞瑰崬濮?*"閿涘牐顫嗘稉瀣桨闁絾顔岄敍澶堚偓?
              //
              // 閳藉應妲勯埥?2026-10-16閿?*閻撗勬儔閺冪姷鏅惃鍕箻鎼达附绨?* 閳ユ柡鈧?娣?濮濆矁鐦濇い闈涚殱闂堛垺鐥呴崣妯虹毈"閻ㄥ嫭鐗撮敍?
              // ---------------------------------------------------------------
              // 閸戝搫顦╅敍姘秺濡楋絽鐣剧粙?`_recover/logic-src/濮濆矁鐦濇い鍨癁鐏炲倸鐨濋棃顫瑢濮濆苯鎮曠€规氨顭?md` 鎼?.2
              //   閿涘牓鈧劖娼€涙濡惍?L189489-189540 缂佹垵鐣鹃悙?+ L190026-190075 婢跺嫮鎮婇崳顭掔礆
              // 鐎规ɑ鏌?SDK閿涘潉swiper.d.ts:onContentDidScroll`閿涘瓐since 12閿涘绱?
              //   "During page scrolling, the ContentDidScrollCallback callback is invoked
              //    for all pages in the viewport **on a frame-by-frame basis**."
              //   `(selectedIndex, index, position, mainAxisLength)`
              //     璺?`selectedIndex` = 閸斻劎鏁惧鈧慨瀣闁鑵戦惃鍕€?
              //     璺?`index`         = **瑜版挸澧犳い?*
              //     璺?`position`      = 閸愬懎顔愰惄绋款嚠娑撴槒閰辩挧椋庡仯閻ㄥ嫮些閸斻劍鐦笟?
              //
              // 閺冪姷鏅惃鍕槱閻炲棗娅掔粵澶夌幆鐎圭偟骞囬敍鍫モ偓鎰蒋閻撗勫Ρ閿涘苯鎯?閸欘亜婀稉鈧笟褍缍婃稉鈧崠?鏉╂瑦娼崗鎶芥暛鐠佹崘顓搁敍澶涚窗
              // ```ts
              //   let p = position;
              //   if (index === 0) {              // 閳?閸欘亜婀?瑜版挸澧犳い鍨Ц閹绢厽鏂佹い?鏉╂瑤绔存笟褍缍婃稉鈧崠?
              //     if (p < 0) { p = -p; }        //    瀵扳偓閸撳秵绮﹂弮?position 娑撻缚绀?閳?缂堢粯顒?
              //     if (p > 1) { p = 1; }         //    娑撳﹤銇欓崚?1
              //     this.swiperProgress = p;
              //   }
              // ```
              //   閳?**閸氬骸宕愬▓纰夌礄濮濆矁鐦濇い鐢稿亝娑撯偓娓氀嶇礆娣囨繃瀵旀稉濠佺濞嗭紕娈戦崐?* 閳?**閸嬫粌婀宀冪槤妞ゅ灚妞?`p` 閹帊璐?1**閵?
              //   鏉╂瑦顒滈弰顖涘灉娴狀兛绔撮惄瀵稿繁閻ㄥ嫰鍋呮稉顏堝櫤閿涙艾鐣?*娑撳秳绶风挧?閸欐垹鏁撴潻鍥︾濞嗭紕鏁ら幋閿嬬拨閸?**閳ユ柡鈧?
              //   閸欘亣顩︽い鐢告桨閻喓娈戦崚鍥箖閸樿绨￠敍瀹峣ndex` 鐏忓彉绱伴崣妯诲灇 0/1閵嗕梗p` 鐏忓彉绱伴崚?1閵?
              //
              // 閹存垳婊戞潻娆庣娓氀呮畱閹恒儲纭堕敍?*閸氬奔绔存禒鍊燁嚔娑斿绱濋崘娆忓煂 `lyricMorphT` 娑?*閿涘绱?
              //   `lyricMorphT` 鐏忚鲸妲搁張顑跨波閻?`swiperProgress` 缁涘鐜悧鈺嬬礄0 = 鐏忎線娼版い鐢殿伂 / 1 = 濮濆矁鐦濇い鐢殿伂閿涘绱?
              //   閹碘偓娴犮儳娲块幒銉﹀Ω瑜版帊绔撮崠鏍ф倵閻?`p` 閸犲倻绮扮€瑰喛绱遍崘宥囨暠 `syncLyricMorphToPage()` 鐠愮喕鐭?
              //   "閺堚偓缂佸牓娼ゅ銏㈩伂閻愮懓绻€妞よ崵鐡戞禍搴＄秼閸撳秹銆夌€电懓绨查惃鍕伂閻?閿涘牐娉曟潻?0.5 閺冩儼藟娑撯偓濞嗏槄绱氶妴?
              .onContentDidScroll((_selectedIndex: number, index: number,
                position: number, _mainAxisLength: number): void => {
                this.onSwiperContentDidScroll(index, position);
              })
              // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`onLyricInteract` 閳ユ柡鈧?濮濆矁鐦濋崠?*鐟欙附鎳?*鐏忛亶鍣哥純顔锯敄闂傝尪顓搁弮璁圭礆
              //
              // 閺冪姷鏅柇锝勭娓氀嶇礄`_recover/logic-src/PlayerPage.abc.txt:6914-6932`閿涘绱?
              // ```ts
              //   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
              // ```
              // 閹稿倽娴囬悙鐟版躬閸氬本鏋冩禒?`190116-190130`閿?*`TouchType.Down`** 閹靛秷鐨熼敍鍫滅瑝閺?Move/Up閿涘鈧?
              // 閳跨媴绗?閸忔娊鏁顔煎焼閿涙艾鐣?*閸?* `startIdle()`閿?*娑?* `showChrome()`
              //   閳?閹碘偓娴犮儴绻栭柌灞肩瘍**娑撳秷鍏?*閻?`touchChrome()`閿涘牓鍋呮稉顏冪窗妞ょ儤澧滈幎濠冨付閸掕泛灏崬銈呭毉閺夈儻绱氶妴?
              // 閳跨媴绗?閹稿倽娴囬悙褰掆偓澶婃躬 `Swiper` 閼板奔绗夐弰?濮濆矁鐦濇い鐢稿亝娑撯偓濡潧鐡欓弽?閿涙碍婀版禒?`scheduleChromeAutoHide()`
              //   閸愬懘鍎存潻妯绘箒 `canHideLyricChrome()`閿?*閸欘亜婀宀冪槤妞ゅ吀璐熼惇?*閿涘绻栭柆鎾绘，
              //   閳?閸︺劌鐨濋棃銏ゃ€夌憴锔芥嚋閸楀厖濞囩挧铚傜啊鐠佲剝妞傞崳銊ょ瘍**娑撳秳绱?*閺€鎯版崳娴犺缍嶆稉婊嗐偪
              //   閳?娑撳孩妫ら悾?閸欘亜婀宀冪槤妞ゅ灚瀵?**鐞涘奔璐熺粵澶夌幆**閿涘牆鐨幐鏍︾鐏炲倸鐡欓弽鎴犳畱鐏炵偞鈧囨懠閿涘鈧?
              // 閳跨媴绗?`.onTouch` 閸欘亣顫囩€电喆鈧?*娑撳秵绉风拹?*娴滃娆?閳?娑撳秴濂栭崫?Swiper 閼奉亜绻侀惃鍕拨閸斻劊鈧?
              .onTouch((event: TouchEvent): void => {
                if (event.type !== TouchType.Down) {
                  return;
                }
                this.onLyricInteract();
              })
              // 閳?閻╊喗鐖?閳?閻?*閸掑棙鏁ぐ鎺戠潣鐠囧﹥鏌?*閿涘牊澧滈張鐑樻暜閿涘鈧柡鈧?鐟?`logBranchSurface()` 閻ㄥ嫭鏁為柌濞库偓?
              //   閹稿倸婀?`Swiper`閿涘牆鐣犻崣顏勭摠閸︺劋绨幍瀣簚鏉╂瑤绔撮弨顖ょ礆閻?`.onAppear()` 娑撳绱?
              //   閳跨媴绗?閹稿倸婀?`@Builder` 娴ｆ捇鍣锋导姘辩椽鐠囨垶濮ら柨娆欑礄`does not meet UI component syntax`閿涘本婀版潪顔肩杽濞村绱氶妴?
              .onAppear((): void => {
                this.logBranchSurface('phone');
              })
              // 閳跨媴绗?鏉╂瑩鍣?*娑撳秴鍟€**缂佹瑦鏆ｆ稉?Swiper 閸?`contentOpacity`閿涙碍瀵滈崣宥囩椽鐠囨埊绱濋崣顏呮箒
              //    **鐏忎線娼?濮濆矁鐦?*閺?閽€鎴掔秴閹靛秴鍤悳?閻ㄥ嫬鍞寸€圭櫢绱濋懓?*濮濆苯鎮?濮濆本澧滈柇锝勭鐞?*鐏炵偘绨い鑸电埉闁絼绔村?
              //    閿涘潉pullChromeOpacity` 0.18閳?.62閿涘绱濈憰浣告躬閸斻劎鏁炬潻鍥┾柤闁插苯姘ㄥǎ鈥冲弳閵?
              //    閹碘偓娴犮儱鍨庣痪褌绗呯粔浼欑窗鐏忎線娼?閳?MusicPlayInfoBlock 閼奉亜绻佺敮锔肩幢
              //    濮濆矁鐦?閳?閸氬嫯鍤滈柇锝勮⒈娴?LyricsComponent閿涙稑鐨宀冪槤 閳?MiniLyricLinesComponent閵?
              .onAnimationStart((index: number, targetIndex: number, _event: SwiperAnimationEvent): void => {
                // 閳藉應妲勯埥?2026-10-16閿?*鏉╂瑩鍣锋稉宥呭晙妞瑰崬濮?`lyricMorphT`** 閳ユ柡鈧?妞瑰崬濮╅弶鍐ㄥ嚒娴溿倗绮?
                //   `onContentDidScroll`閿涘矁顫嗛張?`Swiper` 娑撳﹥鏌熼柇锝嗩唽闂€鎸庢暈闁插绱氶妴?
                //   閸樼喐娼垫潻娆撳櫡鐠?`animateLyricMorph(...)`閿涘矁鈧苯鐣犵敮锕€鐣ч崡?
                //   閵嗗畭index === targetIndex` 閳?鐠哄疇绻冮妴宥佸櫩 閸欘亣顩﹂崚鍥€夋稉宥嗘Ц"娑撯偓濞嗭紕婀″鎴濆З"
                //   閿涘牏鈻兼惔蹇撳閸掑洭銆?/ 闁插秵瀵曟潪钘夊灥婵銆夋稉宥嗘Ц 0閿涘绱濋弫鏉戭殰妞嬬偠顢?*濮樻瓕绻欐稉宥呮儙閸?*閵?
                //   閳?閻滄澘婀潻娆撳櫡閸欘亜浠?*鐠囧﹥鏌囩拋鈩冩殶**閿涘牅绻氶悾娆戭儑閸忣偉顢?`ast=` / `skp=`閿涘奔浜掓笟鍨嚠濮ｆ梹鏌婇弮褑顢戞稉鐚寸礆閿?
                //     閻╅晲缍呮稉搴ょ箻鎼达缚绔村瀣暠 `onSwiperContentDidScroll()` 閸愬啿鐣鹃妴?
                //   閳跨媴绗?娣囨繄鏆€鏉╂瑦顔岄弰顖涙箒閹板繒娈戦敍姘娑撯偓 `onContentDidScroll` 閸︺劍鐓囨禍娑欐簚閸ㄥ绗傛稉宥埿曢崣鎴礉
                //      缁楊剙鍙撶悰宀€娈?`ast=0-1` 鐏忚鲸妲?濠婃垵濮╅崶鐐剁殶鐎涙ê婀担鍡氱箻鎼达箑娲栫拫鍐х瑝鐎涙ê婀?閻ㄥ嫯鐦夐幑顔衡偓?
                this.diagAnimStart = `${index}-${targetIndex}`;
                if (index === targetIndex && !this.lyricMorphVisible) {
                  this.diagAnimSkip = this.diagAnimSkip + 1;
                }
              })
              .onAnimationEnd((index: number, _event: SwiperAnimationEvent): void => {
                // 閳?A2閿涙瓔wiper 閼奉亜绻侀惃鍕拨閸斻劎绮ㄩ弶?閳ユ柡鈧?娑撳孩璇炵仦鍌烆棧鐞涘瞼娈戦弨璺虹啲閸?*娑撱倝妫堕幓鈩冨**
                //   閿涘潉lyricSwiperSettled && lyricFlightSettled` 闁棄鍩屾禍鍡樺閸楀憡甯€"妞嬬偠顢戞稉?闁絼绔村锝忕礆閵?
                //   閳跨媴绗?閺€鐟板鏉╂瑩鍣烽崣顏呭ⅵ閺冦儱绻旈妴?*娴犲簼绗夌純顔荤秴 `lyricSwiperSettled`** 閳?
                //   `finishLyricMorph` 濮樻瓕绻欐潻娑楃瑝閸樹紮绱欓弫鏉戭殰濮濆矁鐦濇い闈涚殱闂堛垹鑸伴崣妯绘Ц濮濊崵娈戦敍澶堚偓?
                this.lyricSwiperSettled = true;
                this.finishLyricMorph(this.lyricMorphGen);
                this.diagAnimEnd = `${index}`;
                this.diagAnimEndCount = this.diagAnimEndCount + 1;
                // 閳藉應妲勯埥?2026-10-16閿?*閺€璺虹啲閽€钘夌暰** 閳ユ柡鈧?閻撗勬儔 `onContentDidScroll` 娑斿鎮楄箛鍛淬€忕悰銉ф畱娑撯偓濮濄儻绱氶敍?
                //   `onContentDidScroll` 闁劕鎶氱紒娆戞畱閺?*濮ｆ柧绶?*閿涘本娓堕崥搴濈鐢勬弓韫囧懏顒滄總鑺ユЦ 0/1
                //   閿涘牆鐤勫ù瀣埗鐟?0.997 鏉╂瑧顫掗敍澶涚幢閼?`syncLyricMorphToPage()` 姒涙顓绘导?*鐠佲晙缍呯紒娆愮泊閸?*
                //   閿涘潉SCROLL_SETTLE_WINDOW_MS` 闁綁浜剧粣妤嬬礆閿涘本澧嶆禒銉︾泊閸斻劋绔撮崑婊冩皑鐟曚焦婀佹禍鐑樺Ω `t` 閽€钘夌暰閸掓壆顏悙骞库偓?
                //   `onAnimationEnd` 濮濓絾妲?swiper 閸嬫粎菙"閻ㄥ嫬鐣奸弬閫涗繆閸欏嚖绱欐稉鏂跨敨閺堚偓缂?`index`閿涘鈧?
                //   閳跨媴绗?妞ゅ搫绨敍?*閸?*閻?`index` 娣囶喗顒?`playbackSwiperIndex`閿?*閸?*閽€钘夌暰
                //      閿涘牆鎯侀崚?`want` 娴兼氨鏁ら弮褏鍌ㄥ鏇犵暬閿涘鈧?
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
                // 閳藉應妲勯埥?2026-10-17閿?*閻撗勬儔閺冪姷鏅柇锝勯嚋 `onChange` 浣?閻ㄥ嫰鈧劕鐡х紒鎾寸€?* 閳ユ柡鈧?閸樼喐娼甸弰顖涙￥閺夆€叉 `touchChrome()`閿?
                //   閺冪姷鏅敍鍧刜recover/logic-src/PlayerPage.abc.txt:23189-23215`閿涘绱?
                // ```
                //   const v = 1;
                //   if (index === v) { startIdle(); }            // 濮濆矁鐦濇い纰夌窗閸欘亣鎹ｇ粚娲＝鐠佲剝妞?
                //   else { clearIdle(); showChrome(); }          // 鐏忎線娼版い纰夌窗閸嬫粏顓搁弮?+ 閸炪倕鍤幒褍鍩楅崠?
                //   this.atLyricScreen = (index === v);
                // ```
                //   閳?娑撱倓閲滈崗鎶芥暛瀹割喖鍩嗛敍鍫ュ厴鐞氼偅鍨滄禒顒€甯弶銉╁亝閸?`touchChrome()` 閹惰甯€娴滃棴绱氶敍?
                //     閳?閸掑洤鍩?*濮濆矁鐦濇い?*娑撳秴鏁滈崙鐑樺付閸掕泛灏敍鍧則ouchChrome()` 娴兼艾鏁滈崙鐚寸礆閿?
                //     閳?閸掑洤鍩?*鐏忎線娼版い?*鐟?*閺勬儳绱￠崬銈呭毉**楠?*閸嬫粍甯€**缁屾椽妫界拋鈩冩
                //        閿涘潉touchChrome()` 閺?閸忓牐鎹ｇ拋鈩冩閸愬秴浠犻幒?閿涘苯鍣ｉ弫鍫熺亯閸氬矉绱濇担鍡楃毌娴滃棝鍋呴弶陇顕㈡稊澶涚礆閵?
                this.onSwiperIndexChanged(index);
              })

              // 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*閹貉冨煑閸栬桨绗佸▓鐢电波閺嬪嫮娈戞稉銈嗙壌閸楃姳缍呴弶?*閵?
              //   閺冪姷鏅?overlay 閻?`Swiper` 娑?鏉╂稑瀹抽弶?娴肩姾绶弶?娑斿妫跨亸杈ㄦЦ鏉╂瑤琚遍弽?*闂嗚泛鍞寸€?Row**
              //   閿涘潉wujie.pa:190464` / `190497`閿涘绱濇稉宥嗘Ц padding閿?
              //     `[Swiper | gapSwiper 鐞?| gapScrub 鐞?| 鏉╂稑瀹抽弶?娴肩姾绶弶顡
              //   閳?`gapSwiper` 鐠?*鏉╃偟鐢?*閸忣剙绱?`playerSwiperGapOf(usableH) = clamp(0.065鑴砲,16,56)`
              //      閿涘潉wujie.pa:93497`閿涘鈧柡鈧?**娑撳秵妲搁弻銉︺€傛担宥堛€?*閿涘牐銆冮柌宀勫亝 48/32/20 閸欘亜婀?濞屸剝婀佺€圭偞绁?
              //      `usableH` 閺冭埖澧犻悽?閿涘矁顫?`playerChromeTotalOf` 閻ㄥ嫪琚辨径鍕灇鐎佃宕查崐纭风礆閿?
              //   閳?`gapScrub` 閺勵垱鐓＄悰銊モ偓纭风礉娴ｅ棙鍨滄禒顒冪箹娑撯偓娓?*瀹歌尙绮?*閺堝鎮撴稉鈧▓鐢告？鐠烘繐绱檂ControlAreaComponent`
              //      闁?Slider 闁絼绔寸悰宀€娈?`bottom` margin閿涘鍣?鏉╂瑩鍣风紒?0閿涘矂浼╅崗宥呮倱娑撯偓濞堝吀琚遍弶鈥冲經瀵板嫸绱?
              //      閸忓牏鏁ら弮銉ョ箶閹?鐎圭偞绁?vs `gapScrub`"闁插繐鍤弶銉礄鐟?`chromeScrubGapRowHVp()`閿涘鈧?
              //   閳跨媴绗?娑撱倖鐗撮柈鑺ユЦ `Row()`閿涘牅绗夐弰?`Blank()`閿涘绱伴弮鐘垫櫕鐏忚鲸妲?`Row`閿涘奔绗栫粚?`Row` 閸?`Column`
              //      闁插本瀵?`.height()` 缁墽鈥橀崡鐘辩秴閿涘奔绗夋导姘剼 `Blank` 闁絾鐗遍崥鍐ㄥ⒖娴ｆ瑧鈹栭梻娣偓?
              Row() {
              }
              .id(PlaybackPage.SWIPER_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.swiperGapRowHVp())
              .hitTestBehavior(HitTestMode.None)
              // 鈽呪槄鈽?2026-10-17锛?*鎶婃帶鍒跺尯鐨勭湡瀹炰笂娌块噺涓嬫潵** 鈥斺€?鏍囬琛岄挸鍒惰鐢ㄥ畠锛?
              //   杩欎竴鏍瑰氨鏄?鎺у埗鍖烘涓婃柟"鐨勫崰浣嶆潯 鈬?瀹冪殑绐楀彛椤惰竟 = 鎺у埗鍖轰笂娌裤€?
              //   鈿狅笍 蹇呴』鍐欒繘 `@Trace`/`@Local`锛氶噺鍒颁箣鍚庤**瑙﹀彂涓€娆￠噸寤?*锛?
              //     鍚﹀垯 `metaOffsetY()` 閲岄偅娆￠挸鍒剁敤鐨勬槸"杩樻病閲忓埌"鐨勫厹搴曟帹绠楀€?鈬?褰㈠悓娌″仛
              //     锛堣繖姝ｆ槸涓婁竴鐗?閽冲埗娌＄敓鏁?鐨勫師鍥狅級銆?
              .onAreaChange((_oldArea: Area, area: Area): void => {
                const y: number = areaLengthToVp(area.globalPosition.y);
                if (Math.abs(y - this.chromeTopMeasured) > 0.5) {
                  this.chromeTopMeasured = y;
                }
              })

              Row() {
              }
              .id(PlaybackPage.CHROME_SCRUB_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.chromeScrubGapRowHVp())
              .hitTestBehavior(HitTestMode.None)

              // 閹貉冨煑閸栫尨绱伴棃娆愵剾 3 缁夋帟鍤滈崝銊︽暪鐠у嚖绱濋悙?绾伴鎹㈤幇蹇擃槱閸炪倕鍤敍鍫濐嚠閺嶅洦妫ら悾宀勭叾娑?BarCollapse閿?
              Column() {
                Column() {
                  // 閳藉應妲?2026-10-15 閻劍鍩涚€规俺鐨熼敍姘モ偓?*鏉╂稑瀹抽弶鈥虫嫲娑撳娼伴惃鍕亝閸棙瀵滈柦顔荤鐠х兘顥ｉ崗?*閵嗗秮鈧柡鈧?
                  //   鐎瑰啩婊戦弰顖欑缂佸嫸绱伴弫瀵稿閹貉冨煑閸栧搫婀?*閸氬奔绔存稉顏呮闂傚鐛?*闁插奔绮犳稉瀣磳娑撳﹥娼甸敍鍫ｎ潌 `contentRiseVp()`閿涘绱?
                  //   閹碘偓娴犮儴绻栭柌?*娑撳秴鍟€**缂佹瑨绻樻惔锔芥蒋閸楁洜瀚柨娆忓槻閿涘牅绗傛稉鈧悧鍫濇皑閺勵垶鍋呮稊鍫濅粵闁挎瑧娈戦敍澶堚偓?
                  ControlAreaComponent({
                    // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*娑撳秷顩?*闁絼绔寸悰?娑撳娴?鐠囧嫯顔?閺囨潙顦?閵?
                    //   閺冪姷鏅惃?`transport` 閸欘亝婀?5 娑擃亷绱伴幘顓熸杹濡€崇础 / 娑撳﹣绔存＃?/ 閹绢厽鏂侀弳鍌氫粻 / 娑撳绔存＃?/ 閹绢厽鏂侀梼鐔峰灙
                    //   閿涘潉PlayerPage鐎瑰本鏆I鐎规氨顭?md` 鎼?.3閿涘矂鈧劙銆嶉柈钘夋躬閿涘绱?*濞屸剝婀佺粭顑跨癌鐞?*閵?
                    //   濞查箖鐓舵径姘毉閺夈儳娈戞潻娆庣鐞涘苯婀幋顏勬禈闁插奔绔撮惇鐓庡讲鐟?閳?閸忚櫕甯€鐎瑰啯澧犻弰?閻撗勬儔"閵?
                    //   閳跨媴绗?闁絽娲撴稉顏勫弳閸欙絾婀伴煬顐ｇ梾閸掔媴绱檂ControlAreaComponent` 闁插奔绮涢崷顭掔礆閿?
                    //      鐟曚焦浠径宥嗗Ω鏉╂瑩鍣烽弨鐟版礀 `true` 閸楀啿褰查妴?
                    showBottomOtherRow: false,
                    // 閳?閼挎粌宕熼悩鑸碘偓浣稿嚒閹绘劕宕岄崚鐗堟拱妞ょ绱欓柇锝勭濡亣顢戦惃鍕┾偓灞炬纯婢舵哎鈧秴娴橀弽鍥ф躬閺堫剟銆夐敍澶涚窗
                    //   `ControlAreaComponent` 娴?`@Local` 閺€瑙勫灇娴?`@Param` + `@Event`閵?
                    showMenuSheet: this.playMenuOpen,
                    onMenuSheetChange: (open: boolean): void => {
                      this.playMenuOpen = open;
                    },
                    // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`hideChrome()` 閻?闂堛垺婢樺鈧惈鈧亸鍙樼瑝閺€?鐎瑰牆宕奸敍澶涚窗
                    //   閼挎粌宕?sheet 瀹歌尙鏁辨稉濠囨桨闁絼绔寸€靛湱婀呭妤勵潌閿?*閸忔湹缍戞稉銈勯嚋瀵懓鐪?*閿涘牊鎸遍弨楣冩Е閸?/ 閸忔湹绮悧鍫熸拱閿?
                    //   閸︺劍婀扮紒鍕閸愬懘鍎撮敍灞筋問娑撹崵婀呮稉宥呭煂 閳?閻㈣精绻栨稉顏勬礀鐠嬪啯濮ゆ稉濠冩降閿涘苯鑻熸潻娑欐暪鐠х兘妫敍鍫ｎ潌 `auxSheetOpen`閿涘鈧?
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
              // 閳藉應妲?2026-10-15閿涘牆娲栭柅鈧崥搴ㄥ櫢閸嬫熬绱氶悽銊﹀煕鐎规俺鐨熼敍姘モ偓?*娑撳秷顩﹀ǎ鈥冲弳濞ｂ€冲毉**閵嗗秮鈧柡鈧?
              //   閹貉冨煑閸栬桨绗夐崘宥夋浆闁繑妲戞惔锕€鍤崷鐚寸礄閸樼喐娼垫潻娆撳櫡閺?`.opacity(pullBottomIn())`閿涘绱?
              //   閺€瑙勫灇**娴犲簼绗呴崡鍥崳閻ㄥ嫪缍呯粔?*閿涙碍鏆ｉ悧鍥ㄥ付閸掕泛灏崷銊ㄥ殰瀹歌京娈戦弮鍫曟？缁愭鍞存禒搴濈瑓閺?180vp 閸楀洤鍩屾担宥忕礉
              //   娑撱倗绮嶉惃鍕帥閸氬氦顫?PlaybackPage 妞ゅ爼鍎撮惃?`WIN_A_*` / `WIN_B_*` 鐠囧瓨妲戦妴?
              //   闂堟瑦顒涢幀浣风秴缁夌粯浜?0閿涘潉morphClipping()` 娑撳搫浜ｉ弮鍓佹纯閹恒儴绻戦崶?0閿涘鍣?閻楀牓娼伴柅鎰剼缁辩姳绗夐崣妯糕偓?
              .translate({ y: this.expandState.contentRiseVp() })
              .onTouch((event: TouchEvent): void => {
                this.touchChrome();
                // 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*閹锋牕濮╅幒褍鍩楅弶鈩冩暪鐠?/ 鐏炴洖绱?*閿涘潉BarCollapse`閿涘鈧?
                //   閺冪姷鏅?`design/src/main/ets/logic/BarCollapse.ets` 閻ㄥ嫭澧滈崝璺ㄥЦ閹焦婧€
                //   閿涘牆鐡ч懞鍌滅垳 `wujie.pa:83706-84140`閿涘鍑￠柅鎰蒋鏉烆剙鍟撻崚?
                //   `common/musicbasic/.../model/BarCollapse.ets`閿涘矁绻栭柌灞藉涧閺勵垱濡哥憴锔芥嚋娴滃娆㈤崰鍌滅舶鐎瑰啨鈧?
                //   閳跨媴绗?鐎瑰啫褰х拠鍡楀焼**缁鹃潧鎮?*閹靛濞嶉敍鍫熋崥鎴︽敚鐎规艾鎮楅弫缈犺韫囩晫鏆愰敍澶嗗櫩 娑撳秳绱伴崪灞剧摃鐠囧秵铆閸氭垶绮﹂崝銊﹀ⅵ閺嬭翰鈧?
                this.onChromeBarTouch(event);
              })
              // Full player collapse retains its existing path; lyric hide reclaims layout continuously.
              .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
          }
          // 缂佺喍绔?TopArea閿涘牆宕熸稉鈧€圭偘绶ラ敍灞藉綌閸旂姳绨崘鍛啇娑斿绗傞敍灞藉瀼閹广垺鏌囬悙瑙勬娑撳秹鏀㈠В渚€鍣稿鐚寸礆
          TopAreaComponent({
            isShowPlay: this.state.isShowPlay,
            onBackClick: (): void => {
              // 閳藉應妲勯埥鍛 2026-10-17閿?*閻撗勬儔閺冪姷鏅惃鍕彠闂傤厼鍨庡ù?* 閳ユ柡鈧?閻劍鍩涢妴宀€閮寸紒鐔荤箲閸?閸忔娊妫撮幐澶愭尦閺勵垰鍘涘鎴滅濞堥潧鍟€妞嬬偛娲栭崢姹団偓宥忕礆
              //   閺冪姷鏅敍姘舵姜閹靛濞嶉崗鎶芥４閿涘牐绻戦崶?/ 閸忔娊妫撮幐澶愭尦閿涘铔?`closeWithAnimation()` = **閹峰秴鎻╅悡褏缂夐崚鎷屽厡閸?*閿?
              //        閻㈠娼伴弽瑙勬拱娑?濠?閿?*濞插銆夎ぐ銏犲綁閸欘亞鏆€缂佹瑤绗呴幏澶嬪閸?*閿涘潉onReverseMorph`閿涘鈧?
              //   閹存垳婊戦崢鐔告降鏉╂瑩鍣烽惄瀛樺复 `closeFullScreenPlayback()`閿? 濞插銆夎ぐ銏犲綁閿涘鍣?妞ょ敻娼伴崗鍫熺拨娑撯偓濞堢绱?
              //        閸愬秶鏁辨竟鍐茬湴闁絼绔村Λ鎺楊棧閸ョ偛骞?閳?鐏忚鲸妲告担鐘垫箙閸掓壆娈?閸忓牊绮︽稉鈧▓纰夌礉閻掕泛鎮楅崘宥夘棧閸ョ偛骞?閵?
              //   閳跨媴绗?`closeWithAnimation()` 閼奉亜鐢稉銈囬獓閸忔粌绨抽敍鍫ｅ厡閸ュ﹦鐓╄ぐ?缁愭褰涚亸鍝勵嚟娑撳秴褰查悽銊ｂ偓浣告彥閻撗冦亼鐠愩儻绱?
              //     閳?闁垝绗夋导姘Ω閹绢厽鏂佹い闈涘幢娴ｅ繈鈧?
              this.closeWithAnimation();
            }
          })
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding')
            })
            .zIndex(2)
            // 妞よ埖鐖敍姘冀缂傛牞鐦?`pullChromeOpacity = clamp((effT-0.18)/0.44)`閿?.18 閳?0.62 濞ｂ€冲弳
            //閿?閹稿鎸虫稊鐔告Ц閸︺劌濮╅悽鏄忕箖缁嬪姘ㄩ崙铏瑰箛娴?鐏忚鲸妲告潻娆庣鐏炲倹鐦惔鏇熺埉閺冣晛绶辨径姘剧礆
            .opacity(this.expandState.pullChromeOpacity())
            .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱版い鐢告桨娓氀冨彠闂傤厽澧滈崝璺ㄦ畱**缁楊兛绨╂稉顏呭瘯鏉炵晫鍋?*閿?
            //   閺冪姷鏅惃鍕彠闂傤厽澧滈崝鎸庡瘯娴?*娑撱倕顦?*閿涘潉_recover/logic-src/瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md`
            //   鎼?.1 閻?閳?娑?閳躲儻绱氶敍?
            //     閳?`PlayerPage` 妞ゅ爼鍎撮柇锝嗘蒋 Row閿涘潉PanDirection.Down`, `distance:8`閿涘鍟?**娑撹鍙嗛崣?*
            //     閳?閸愬懎顔愮€圭懓娅?
            //   閹存垳婊戦崢鐔告降閸欘亝婀?閺佹挳銆夐弽?闁絼绔存径鍕剁礄閳牃鎳冮敍澶堚偓鍌濃偓灞炬殻妞ゅ灚鐗存稉濠勬畱缁旀牜娲块幏鏍уЗ**娴兼俺顫﹂崘鍛村劥
            //   閸欘垱绮撮崝?/ 鐎涙劖澧滈崝鍨帥閸氬啯甯€**閿涘湏rkUI 閹靛濞嶉崘鎺撳満閿涙艾鐡欓懞鍌滃仯娴兼ê鍘涢敍澶嗗櫩
            //   閻劍鍩涚€圭偞绁撮妴灞剧梾濞夋洑绗呴幏澶婂彠闂傤厽鎸遍弨鎯ф珤閵嗗秲鈧?
            //   妞よ埖鐖潻娆庣閺夆剝妲?*闂堢偞绮撮崝銊ф畱閸ュ搫鐣鹃弶鈥崇敨**閵嗕礁绻€鐎规碍鏁瑰妤€鍩岀粩鏍纯閹锋牕濮?閳?鐞涖儰绗傜€瑰喛绱濇稉搴㈡￥閻ｅ苯鎮撻弸鍕┾偓?
            //   閴?缁绢垰顤冮柌蹇嬧偓浣风瑝閺€閫涙崲娴ｆ洘妫﹂張澶庮攽娑撶尨绱伴崨鎴掕厬閻ㄥ嫯绻曢弰顖氭倱娑撯偓娑?`onDismissDrag()`閿?
            //      閸欘亝婀?鐠ч攱澧滈拃钘夋躬妞よ埖鐖稉?閺冭埖澧犻悽鍗炵暊閹恒儳顓搁敍鍧?gesture()` 鐎涙劘濡悙閫涚喘閸忓牞绱氶敍?
            //      妞ょ敻娼伴崗璺虹暊閸栧搫鐓欓惃鍕＆閺堝顢戞稉杞扮鐎涙ぞ绗夐崣妯糕偓?
            //   閳跨媴绗?娑撱倕顦╂い鑸电埉鐎圭偘绶ラ敍鍫熸拱婢?+ 娑撳娼?`!panelLayout` 闁絾鏁敍?*韫囧懘銆忛柈鑺ュ瘯** 閳ユ柡鈧?
            //      閸氾箑鍨亸杈ㄦЦ 鎼?6.1.6 / 鎼?6.16 闁絼閲滈妴灞芥倱娑撯偓瑜般垻濮搁張?N 婢跺嫨鈧礁褰ч弨閫涚啊娑撯偓婢跺嫨鈧秶娈戦懓浣圭樅閻ュ懌鈧?
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
    // 閳跨媴绗?鏉╂瑩鍣烽敍鍧刡uildControlStack` 閻ㄥ嫭鐗撮敍?*娑撳秷顩?*閸愬秶绮?`backgroundColor(imageColor)`閿?
    //    鐎瑰啯妲告稉鈧仦?*閹帊绗夐柅蹇旀**閻ㄥ嫬褰囬懝鎻掔俺閿涘潉imageColor` 閻?alpha 閺?0.4閿涘奔绲炬惔鏇″閺堫剝闊╅敍?
    //    閳ユ柡鈧?瑜般垹褰夐張鐔兼？鐟佷礁澹€缁愭褰涢崣顏呮箒娑撯偓鐏忓繐娼￠敍灞界暊娴兼俺绻涢崥宀€鐛ラ崣锝勭鐠ч攱濡告稉瀣桨閻ㄥ嫰顩绘い鐢电ˇ閹哄绱?
    //    閸愬秴濮為崘鍛村劥闁絽鐪版潻鎴︾拨鎼存洝澹婇敍宀冾潎閹扮喎姘ㄩ弰?鐏炴洖绱戞稉顓″剹閺咁垱妲告鎴犳畱"閵?
    //    閼冲本娅欓懝韫瀵板鏁辨稉濠囨桨**鐢附璐伴崗銉х崶閸?*閻ㄥ嫪琚辩仦鍌濈鐠愶綇绱欐惔鏇″ + 閸欐牞澹婄仦鍌︾礆閿涘矁绻栭柌灞肩箽閹镐線鈧繑妲戦妴?
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
            // 閳?閸氬苯顔旂仦蹇涘亝婢跺嫸绱伴挊蹇斿竴 `LyricsComponent` 閼奉亜鐢悰銊ャ仈閿涘牊妫ら悾灞剧梾閺堝鐣犻敍澶堚偓?
            //   閺堫剙鍨庨弨顖欑瑐闂?L2233 閻?`MusicPlayInfoBlock` 瀹歌尙绮￠崷銊︽▔缁€鍝勭殱闂?+ 濮濆苯鎮?+ 濮濆本澧?
            //   閳?娑撳秷妫岀亸杈ㄦЦ"閸氬奔绔存＃鏍ㄧ摃閸氬秴鍤悳棰佽⒈濞?閵嗗倸鐣弫瀵告倞閻㈣精顫?L1926 闁絽顦╅惃鍕暈闁插鈧?
            hideLyricsMetaHeader: true,
            onSeekTime: (ms: number): void => {
              MediaService.getInstance().seek(ms);
            }
          })
        }
        .layoutWeight(1)
        // 濮濆矁鐦濈仦鐐扮艾"閸愬懎顔?閿涙瓪contentOpacity`閿涘牐鎯ゆ担宥嗗缂?1閿?
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
      // 閳?閻╊喗鐖?閳?閻?*閸掑棙鏁ぐ鎺戠潣鐠囧﹥鏌?*閿涘牓娼伴弶鎸庢暜閿涘鈧柡鈧?娑撳骸顔旂仦蹇涘亝婢跺嫭鍨氱€电櫢绱濋悶鍡欐暠鐟欎礁鐣犳稉濠囨桨閻ㄥ嫭鏁為柌濞库偓?
      .onAppear((): void => {
        this.logBranchSurface('panel');
      })

      if (!this.panelLayout) {
        TopAreaComponent({
          isShowPlay: this.state.isShowPlay,
          onBackClick: (): void => {
            // 閳?閸氬奔绗傞敍鍫㈠弾閹碱剚妫ら悾宀嬬窗闂堢偞澧滈崝鍨彠闂?= 韫囶偆鍙庨弨鍓佺級閿涘奔绗夐弰顖涙た妞ら潧鑸伴崣姗堢礆
            this.closeWithAnimation();
          }
        })
          .padding({
            left: 56,
            right: 56
          })
          .zIndex(2)
          .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
          // 閳?閸氬奔绗傞棃銏ゅ亝婢跺嫰銆婇弽蹇ョ窗妞ょ敻娼版笟褍鍙ч梻顓熷閸旇法娈戠粭顑跨癌娑擃亝瀵曟潪鐣屽仯閿涘牆顕弽鍥ㄦ￥閻?閳?妞ゅ爼鍎?Row閿涘鈧?
          //   閳跨媴绗?鏉╂瑤绔存径?*韫囧懘銆忔稉搴濈瑐闂堛垽鍋呮径鍕灇鐎电懓鐡ㄩ崷?*閿涘瞼鎮婇悽鍙樼瑢鐎瑰本鏆ｇ拠瀛樻鐟欎椒绗傞棃銏ゅ亝濞堝灚鏁為柌濞库偓?
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

  // 閳跨媴绗?2026-10-17閿涙俺绻栭柌灞藉斧閺夈儴绻曢張澶夌娑?`applyWindowSafeAreas()` 閳ユ柡鈧?**瀹告彃鍨归梽?*閵?
  //   鐎瑰啩绗屾稉瀣桨闁絼閲?*濞茶崵娼冮惃?* `applyPlaybackWindowChromeImmediately()`閿涘牆鏁稉鈧拫鍐暏閻?:5534閿?
  //   閺?*閸氬奔绔存禒鏈电皑閻ㄥ嫪琚辨總妤€鍟撳▔?*閿涘苯褰у顔荤閸?`applyPlaybackNavigationBarColor(true)`
  //   閳?闂嗘儼鐨熼悽銊у仯閵嗕胶鏆€閻偓鐏忚鲸妲?閺€褰掓晩閸︾増鏌?閻ㄥ嫬鍙嗛崣锝忕礄閺堫兛绮ㄥ鑼病娑撻缚绻栨稉顏勮埌閻樿泛鎮嗘潻鍥с偨閸戠姵顐兼禍蹇ョ礆閵?
  //   閳?閻喕顩﹂弨瑙勬尡閺€楣冦€夐惃鍕崶閸欙綀顥婃甯礉**閸欘亝鏁兼稉瀣桨闁絼绔存稉?*閵?

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
   * 鈽呪槄鈽呪槄 2026-10-17锛?*璺ㄩ〉闈㈢綉鏍兼簮缂撳瓨** 鈥斺€?淇€屽睍寮€鐨勬椂鍊欐槸钃濊壊銆嶏級
   *
   * ## 涓轰粈涔堝睍寮€鏃舵槸钃濊壊
   *   鏃犵晫閭ｄ竴渚?`MeshCoverBg` 鏀剁殑鏄?**`$$.imgLocal`锛堟湰鍦板皝闈㈡枃浠讹級** 鈥斺€?鎾斁鍣ㄦ墦寮€閭ｄ竴鍒?
   *   灏侀潰宸茬粡鍦ㄦ湰鍦?鈬?鑳屾櫙绗竴甯у氨鏄?*鐪熷皝闈?*鐨勯厤鑹诧紝缁勪欢閲岄偅涓?`makeFallback()`
   *   锛堟寜 `seed` 鑹茬浉閫犵殑**鍥涜 HSL 娓愬彉**锛夊熀鏈敤涓嶄笂銆?
   *   鎴戜滑杩欎竴渚у皝闈㈠鏄?*鍦ㄧ嚎 URL**锛氶〉闈㈡瘡娆℃墦寮€閮芥槸鏂板疄渚嬨€乣meshSrc` 涓虹┖ 鈬?
   *   缁勪欢鍐?`makeFallback()` 鍏堥《涓?鈬?灞忎笂灏辨槸閭ｅ紶鎸?seed 鑹茬浉鐢诲嚭鏉ョ殑鍏滃簳缃戞牸锛?*钃濊壊**锛夛紱
   *   绛夌湡灏侀潰涓嬭浇瑙ｇ爜瀹屾墠鎹㈢湡閰嶈壊锛岄偅鏃跺姩鐢绘棭缁撴潫浜嗐€?
   *
   * ## 鍋氭硶锛堢瓑浠蜂簬涓婃父"鏈湴灏侀潰涓€鐩村湪"锛?
   *   姣忔鎻愪氦缃戞牸婧愭椂锛屾妸**宸茬粡 enhance+blur 杩囩殑 64脳64 RGBA 缂撳啿**锛?6KB锛夎繛鍚屽畠鐨?key
   *   瀛樻垚**闈欐€佸瓧娈?*锛涗笅涓€娆￠〉闈㈡寕杞芥椂鑻?key 杩樻槸鍚屼竴棣栵紝灏辩洿鎺ヤ粠杩欎唤缂撳啿閲嶅缓 PixelMap
   *   鈬?鎵撳紑鍔ㄧ敾绗竴甯у氨鏄湡閰嶈壊锛屽厹搴曠綉鏍煎彧鐪熸鍏滃簳銆?
   *   鈿狅笍 瀛?*缂撳啿**鑰屼笉鏄?PixelMap锛氭墍鏈夋潈绠€鍗曪紙绾唴瀛橈級锛岄〉闈㈡瘡娆¤嚜宸遍€?PixelMap銆?
   *     閫€鍦虹収鏃ц嚜宸遍噴鏀?鈬?涓嶄細鍙岄噸閲婃斁銆?
   *   鈿狅笍 key 涓嶅尮閰嶏紙鎹㈡瓕锛夆噿 涓嶉噰鐢紙涓嶄細鎶婁笂涓€棣栫殑閰嶈壊涓插埌杩欎竴棣栵級銆?
   *
   * ## 鉀?2026-10-17 褰撳ぉ鎾ゅ洖锛堢敤鎴峰疄娴嬨€?*灞曞紑杩囩▼涓殑鏄笂涓€棣栨瓕鐨勯鑹?*銆嶏級
   *   鏍瑰洜锛?*椤甸潰鎸傝浇閭ｄ竴鎷?`state.getCurrentSongItem()` 杩樻槸涓婁竴棣?*锛堢姸鎬佺敱璋冪敤鏂瑰悗鍐欙級锛?
   *   浜庢槸 `currentMeshKey()` 涔熸槸涓婁竴棣栫殑 key 鈬?鍛戒腑涓婁竴棣栫殑缂撳啿 鈬?寮€鍦哄姩鐢绘斁鐨勬槸**涓婁竴棣栫殑閰嶈壊**銆?
   *   锛堝悓涓€鎷嶄笂 `meshSeed()` 涔熶細鍙栧埌涓婁竴棣?鈬?鍏滃簳缃戞牸鍚屾牱鏄笂涓€棣栫殑鑹茬浉銆傦級
   *   鈬?**璺ㄩ〉闈㈢紦瀛樻暣娈靛仠鐢?*锛堜笅闈?`adoptCachedMesh()` 淇濈暀瀹炵幇浣?*鏃犺皟鐢ㄧ偣**锛?
   *     鍐欑紦鍐查偅涓よ涔熷凡鍒犻櫎锛夈€傝鎭㈠瀹冿紝蹇呴』鍏堣В鍐?鎸傝浇鏃剁姸鎬佹槸涓婁竴棣?杩欎釜鍓嶆彁
   *   鈥斺€?渚嬪鐢卞３灞傚湪 push 鍓嶆妸褰撳墠姝屽啓杩涚姸鎬侊紝鎴栬€呮妸缃戞牸鍋氭垚 `AppStorageV2` 鍏变韩鐘舵€併€?
   *     鐢?姝ｅ湪鎾斁鐨勯偅涓€棣?璐熻矗缁存姢銆?*涓嶈**鍙妸缂撳瓨閲嶆柊鎺ヤ笂浜嗕簨銆?
   */
  private static meshBufKey: string = '';
  private static meshBuf: Uint8Array | undefined = undefined;

  /** @returns 褰撳墠姝屾洸鐨勭綉鏍肩紦瀛?key锛? 灏侀潰 URL / 鏈湴璧勬簮鏍囪瘑锛涘彇涓嶅埌绌轰覆锛夈€?*/
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
   * 鐢ㄤ笂涓€鍏崇暀涓嬬殑缂撳啿閲嶅缓缃戞牸婧愩€?
   * 鉀?**褰撳墠鏃犺皟鐢ㄧ偣**锛堣涓婇潰銆屽綋澶╂挙鍥炪€嶉偅娈碉級鈥斺€旀寕杞芥椂 `getCurrentSongItem()` 鍙兘鏄笂涓€棣栵紝
   *   鐩存帴閲囩敤浼氭妸涓婁竴棣栫殑閰嶈壊鏀惧埌寮€鍦哄姩鐢讳笂銆備繚鐣欏疄鐜版槸涓轰簡灏嗘潵"鐘舵€佸厛灏变綅"涔嬪悗鍐嶆帴鍥炴潵銆?
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
   * @returns 閼冲本娅欑純鎴炵壐閻?*閸忔粌绨崇粔宥呯摍** 閳ユ柡鈧?閻撗勬儔閺冪姷鏅?`seedOfParts($$.title, $$.artist)`
   *   閿涘潉PlayerPage.ets:5252` 閻ㄥ嫬鐤勯崣鍌︾礆閵?
   *
   * 閸欘亞鏁ゆ禍?鐏忎線娼伴崣鏍︾瑝閸掔増妞?闁姴鍘规惔鏇犵秹閺嶇》绱檂MeshCoverBg.makeFallback` 閳?`hueOfSeed` 閳?`fillFallback`閿涘鈧?
   * 娑撳﹥鐖?`seedOfParts` 閻ㄥ嫭瀚惧▔鏇炴躬瑜版帗銆傜粭鏃囶唶闁插本鐥呴張澶愨偓鎰摟鐏炴洖绱戦敍宀冪箹闁插瞼鏁?`title|singer`
   * 閳ユ柡鈧?鐎瑰啫褰цぐ鍗炴惙**閼硅尙娴?*閿涘潉hueOfSeed` 閺?Java 瀵繐鐡х粭锔胯閸濆牆绗囬敍澶涚礉閹峰吋纭舵稉宥呮倱閸欘亙绱伴幑顫嚋閼硅尙娴夐敍?
   * 娑撳秴濂栭崫?閺堝鐥呴張澶庡剹閺?閵?
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
   * 閻㈠崬鐨濋棃銏㈢暬閸戠儤绁﹂崗澶庡剹閺咁垳娈戞稉銈勯嚋妫版粏澹婇獮璺哄晸鏉?{@link coverTint}閵?
   *
   * 閸欘亜婀鈧崗铏ⅵ瀵偓閺冭埖澧犻崑姘剧窗閸欐牞澹婄憰浣借泲娑撯偓濞喡ば掗惍渚婄礄閸︺劎鍤庣亸渚€娼版潻妯款洣閸忓牅绗呮潪鏂ょ礆閿涘苯鍙ч幒澶婃皑閸掝偆娅ч懞杈箹娴犺棄绱戦柨鈧妴?
   * 婢惰精瑙︽稉宥嗗Г闁挎瑤绡冩稉宥嗘暭妫版粏澹?閳ユ柡鈧?娣囨繄鏆€娑撳﹣绔存＃鏍畱妫版粏澹婇幋鏍у幑鎼存洝澹婇敍灞剧ウ閸忓鍙庨弽鐤厴閻鈧?
   *
   * @param pixelMap 瀹歌尪袙閻胶娈戠亸渚€娼版担宥呮禈閿涘瞼鏁辩拫鍐暏閺傜绀嬬拹锝夊櫞閺€淇扁偓?
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
            // 閻劌宕板В鏃€娓舵径褏娈戞０婊嗗娴ｆ粈璐熼崺楦跨殶閿涘苯鍟€閸?vividFlowColors 闁插本濡告鍗炴嫲鎼?娴滎喖瀹抽幏澶庢崳閺夈儻绱?
            // 鐏忎線娼版稉鏄忓缂佸繐鐖堕弰顖欑婢堆呭閹恒儴绻庢鎴犳畱閼冲本娅欓敍宀€娲块幒銉﹀瑏鐎瑰啫浠涘ù浣稿帨閸╃儤婀伴惇瀣╃瑝鐟?
            // 閿涘牓顩绘い?PR 闁絿澧楅崘娆愵劥娑撯偓娑擃亞浼犻懝璇х礉閹碘偓娴犮儲鐥呮潻娆庨嚋闂傤噣顣介敍澶堚偓?
            const color = colorPicker.getLargestProportionColor();
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });
  }

  /**
   * 閹跺﹤鐨濋棃顫瘜閼瑰弶宕茬粻妤佸灇濞翠礁鍘滈悽銊ф畱娑撱倓閲滄０婊嗗楠炶泛褰傜敮鍐︹偓?
   *
   * 閸?`coverTint` 娴兼俺袝閸?{@link onCoverTintVersionChange}閿涘瞼鏁辩€瑰啯濡告０婊嗗娑撳褰傜紒娆戞絻閼规彃娅掗妴?
   *
   * **娑撳秴鍨介弬顓炵磻閸?*閿涙碍宕茬粻妤佹拱闊偄褰ч弰顖氬殤濞嗭紕鐣婚張顖ょ礉閸忓磭娼冩稊鐔峰帥缁犳銈界€涙鎹ｉ弶?閳ユ柡鈧?鏉╂瑦鐗遍悽銊﹀煕
   * 閸︺劏顔曠純顕€鍣锋稉鈧幍鎾崇磻瀵偓閸忕绱濈粭顑跨鐢呮畱濞翠礁鍘滄０婊嗗鐏忓崬鍑＄紒蹇旀Ц瑜版挸澧犵亸渚€娼伴懝璇х礉娑撳秳绱伴崗鍫ユ／娑撯偓娑撳鍘规惔鏇″閵?
   * 閻喐顒滅憰浣藉С闁借京娈戦弰顖澬掗惍浣哥殱闂堫澁绱濋柇锝夊劥閸掑棛鏁?{@link extractFlowLightColors} 閹跺﹤鍙ч妴?
   *
   * @param red 鐏忎線娼版稉鏄忓缁俱垽鈧岸浜?0閳?55閵?
   * @param green 鐏忎線娼版稉鏄忓缂佸潡鈧岸浜?0閳?55閵?
   * @param blue 鐏忎線娼版稉鏄忓閽冩繈鈧岸浜?0閳?55閵?
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
   * 閳藉應妲?2026-10-15閿?*娑撳秴鍟€娴溠冨毉娴犺缍嶉懗灞炬珯鎼存洖娴?*閵嗗倽鍎楅弲顖氱湴閺€瑙勫灇閵嗗苯甯慨瀣殱闂?+ 缂佸嫪娆㈢痪褍鐤勯弮鑸的佺化濞库偓?
   *   閿涘澖@link originalCoverSource} + {@link backdropBlurRadiusVp}閿涘鍣?鏉╂瑩鍣烽崣顏勫⒖娑撱倓娆㈡禍瀣剁窗
   *   閳?閹?`imageLabel` 婢跺秳缍呴幋?*閸樼喎顫愮亸渚€娼?*閿涘潉Resource`閿涘绱遍埗?缁犳鍤?`state.imageColor`
   *   閿涘牊鎸遍弨楣冦€夐懗灞炬珯闁絽鐪伴崣鏍ㄧ壉閼硅绱? 濞翠礁鍘滈懝灞傗偓鍌欒厬闂傜袙閻礁鍤弶銉ф畱 PixelMap **閸欘亞鏁ゆ禍搴″絿閼硅绱濋悽銊ョ暚閸楀啿绱?*閵?
   */
  private async getImageColorAsync(): Promise<void> {
    const jobSeq: number = ++this.imageColorJobSeq;
    const ctx = this.context;
    if (!ctx) {
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (!song) {
      // 閳藉應妲勯埥?2026-10-17閿涘牏鏁ら幋鏋偓宀€鍋ｉ崙缁樻尡閺€鐐蒋閹垫挸绱戞潻妯绘Ц濞屸剝婀侀懗灞炬珯閵嗗秶娈戞稉鈧弶锛勬埂閸戠姳缍嶉崣顖濆厴閿涘绱?
      //   閻愮懓鍤幍鎾崇磻闁絼绔撮崚濠氥€夐棃銏犲灠閹稿倽娴囬敍瀹峴tate.getCurrentSongItem()` 閸欘垵鍏?*鏉╂ɑ鐥呯憴锝嗙€介崙鐑樻降**
      //   閳?鏉╂瑩鍣烽崢鐔告降閻╁瓨甯?`return` 閳?閺冾澀绗夐崣鏍娑旂喍绗夊铏圭秹閺嶇》绱濋懓灞肩瑬**濞屸剝婀佹禒璁崇秿娴滃搫鍟€閺夈儱褰ㄦ稉鈧▎?*
      //   閿涘牆鎮撴稉鈧＃鏍ㄧ摃娑撳秳绱扮憴锕€褰?`selectIndex`/`playQueueIds` 閻?`@Monitor`閿?
      //   閳?鏉╂瑤绔撮弫鏉戝彠闁姤鐥呴張澶庡剹閺咁垽绱濋惄鏉戝煂閻劍鍩涢崚鍥ㄧ摃閵嗗倵鍣?閺€瑙勫灇鐠ф澘鎮撴稉鈧弶?*閺堝鏅柌宥呭絿**閿涘牊娓舵径?4 濞?鑴?400ms閿涘鈧?
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
      // 閸︺劎鍤庡灞炬锤閿涙艾褰?*鐟欙絿鐖?*鐏忎線娼扮紒娆愮ウ閸忓褰囬懝鑼暏閵?
      //
      // 閳藉應妲?2026-10-15閿涙俺绻栭柌灞藉斧閺夈儴绻曟导?`effectKit.createEffect(coverPm).blur(imageBlurRadius())`
      //   妫板嫭瑕嗛弻鎾茬瀵姵膩缁?PixelMap 瑜版挸绨抽崶?閳ユ柡鈧?**鐠囥儵顣╁〒鍙夌厠瀹稿弶鏆ｆ担鎾充粻閻?*閿涘牐鍎楅弲顖涙暭鐎圭偞妞傚Ο锛勭ˇ閿?
      //   鎼存洖娴樼紒娆戞畱閺?{@link originalCoverSource()} 閻ㄥ嫬甯慨瀣殱闂堫澁绱氶妴?
      //   閳?`imageLabel` 娑撳秴鍟€鐞氼偉绁撮幋鎰佺化濠傛禈閿涙稖袙閻浇绻栨稉鈧銉ょ箽閻ｆ瑱绱濋崶鐘辫礋
      //   {@link extractFlowLightColors} 闂団偓鐟曚椒绔存稉顏嗗箛閹存劗娈?PixelMap閿涘牆鍘ゅ妞捐礋閸欐牞澹婇崘宥勭瑓鏉炴垝绔撮柆宥呯殱闂堫澁绱氶妴?
      if (song.cover.length > 0 && this.isAlive) {
        try {
          const pair: CoverDecodePair =
            await PlaybackPage.loadOnlineCoverPair(song.cover);
          if (pair.full !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            // 濞翠礁鍘滈崣鏍閿涙俺绉担宥呮禈瀹歌尙绮＄憴锝囩垳婵備粙銆庨幍瀣暬娑撯偓濞嗏槄绱濇稉宥囨暏娑撳搫鐣犻崘宥勭瑓鏉炴垝绔撮柆宥呯殱闂?
            await this.extractFlowLightColors(pair.full);
          }
          // 閳藉應妲?2026-10-15閿涙氨缍夐弽鑹板剹閺咁垳娈戝┃鎰剁礄64鑴?4閿涘婀崥灞肩濞嗏€茬瑓鏉炰粙鍣烽崙鐚寸礉娴溿倗绮伴懗灞炬珯鐏?
          if (pair.mesh !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            this.publishMeshSource(pair.mesh);
          } else {
            this.releasePixelMapQuiet(pair.mesh);
          }
          this.releasePixelMapQuiet(pair.full);
        } catch (_err) {
          // 閸欐牞澹婃径杈Е娑撳秴濂栭崫宥嗘尡閺€鎾呯窗閼冲本娅欑挧鏉跨杽閺冭埖膩缁绱濇稉宥呭晙闂団偓鐟曚浇绻栧鐘活暕濞撳弶鐓嬮崶?
        }
      }
      // 閳藉應妲勯埥?2026-10-17閿涘牏鏁ら幋鏋偓灞炬弓閹绢厽鏂侀悩鑸碘偓浣哄仯閸戠粯澧﹀鈧幘顓熸杹閸?閳?閼冲本娅欓弰顖炵拨閻ㄥ嫸绱遍悙閫涚娑撳鎸遍弨鎯ф皑濮濓絽鐖堕妴宥忕礆
      //
      // ## 閺堝搫鍩楅敍鍫ｎ嚢娴狅絿鐖滈崡鍐茬繁閿涘奔绗夐弰顖滃閿?
      // ```
      //   閸︺劎鍤庡灞炬锤閻ㄥ嫯鍎楅弲?*娑撳秵妲搁崣鏍鐏?*閿涘牓鍋呮稉鈧仦鍌涙Ц閸愭瑦顒撮惃鍕箮姒?rgba(20,20,22,0.5)閿涘绱?
      //   閻喐顒滈惃鍕剹閺咁垱妲?*缂冩垶鐗搁崶?*閿涘潉publishMeshSource(pair.mesh)`閿涘绱濋懓灞界暊閸欘亜婀?
      //   `song.cover.length > 0` 閺冭埖澧犳导姘愁潶鐟欙絽鍤弶銉ｂ偓?
      //   閺堫亝鎸遍弨鐐鐏忎線娼?URL 閸欘垵鍏樻潻妯荤梾閸掔増澧滈敍鍧tadata 閺?resolve閿涘鍣?閺冦垺鐥呯純鎴炵壐娑旂喐鐥呴崣鏍
      //   閳?鐏炲繋绗傜亸杈ㄦЦ闁絽鐪版潻鎴︾拨鎼?= 閻劍鍩涢惇瀣煂閻?閼冲本娅欓弰顖炵拨閻?閵?
      //   娑撯偓閻愯鎸遍弨?閳?鐏忎線娼?metadata 閸掗缍?閳?`onCurrentTrackForBackground` 閸愬秷绐囨稉鈧▎?閳?濮濓絽鐖堕妴?
      // ```
      // ## 婢跺嫮鐤嗛敍?*娑撳秴褰傞弰搴濇崲娴ｆ洝顫嬬憴澶娾偓?*閿涘苯褰х拋鈺佺暊閼奉亜绻侀弨鑸垫殐閿?
      //   閼冲本娅欓崣顏囶嚉鐠?鐏忎線娼伴張澶嬬梾閺堝鍩岄幍?閺堝鍙ч妴?*娑撳孩鎸遍弨鍓уЦ閹焦妫ら崗?*
      //   閳?鐏忎線娼版潻妯荤梾閸掔増澧滈弮璁圭礉**閺堝鏅崷?*闂呮柧绔存导姘姽閸愬秴褰囨稉鈧▎鈽呯礄閺堚偓婢?`BG_RETRY_MAX` 濞嗏槄绱?
      //     濮ｅ繑顐奸柈鍊燁洣鏉?`isAlive` + `jobSeq` 鏉╂瑤琚遍柆鎾绘，閿涘鈧?
      //   閳跨媴绗?娑撳秷鍏橀弮鐘绘闁插秷鐦敍姘殱闂堛垻鈥樼€圭偘绗夌€涙ê婀敍鍫熸拱閸︾増妫ら崶?閹恒儱褰涘闀愮畽婢惰精瑙﹂敍澶嬫鐟曚礁浠犻幍瀣ㄢ偓?
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
    // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻?`decodeCover`閿涘绱伴崥灞肩濞喡ば掗惍?*妞ょ儤澧滈崘宥呭毉娑撯偓瀵?64鑴?4**閿?
    //   鐎瑰啯澧犻弰顖滅秹閺嶈壈鍎楅弲顖滄畱濠ф劧绱欓弮鐘垫櫕 `SRC_EDGE = 64`閿涘鈧倸婀?64鑴?4 娑撳﹤浠?`enhanceColors`
    //   + `boxBlurRgba(9, 3)`閿涘苯鍟€鐞?`drawPixelMapMesh` **閺€鎯с亣闁剧儤寮ч弫鏉戠潌** 閳?
    //   鐟欏倹鍔呴弰?婢堆嗗閸ф绁﹂崝?閿涘奔绗?閸忋劌鍨庢潏銊у芳閻撗呭 + 妤傛ɑ鏌夊Ο锛勭ˇ"閺勵垯琚辩粔宥勭鐟楄￥鈧?
    let meshPm: image.PixelMap | undefined = undefined;
    const imageSource = image.createImageSource(mediaData.buffer as ArrayBuffer);
    try {
      pixelMap = await imageSource.createPixelMap();
      // 閳藉應妲?2026-10-15閿涙氨缍夐弽鍏肩爱**閸楁洜瀚稉鈧稉?try** 閳ユ柡鈧?鐎瑰啫銇戠拹?*娑撳秷鍏?*閹?閸欐牞澹?闁絾娼捄顖欑鐠?abort閵?
      //   閸樼喐娼甸弰顖濈娑撴槒袙閻礁鎮撴稉鈧稉?`try`閿涘矁鈧矂鍋呮稉?`catch` 娴?`return`閿涘牆鑻熼崘娆撶帛鐠併倕绨抽懝璇х礆
      //   閳?64鑴?4 闁絼绔村銉ょ娑撯偓婢惰精瑙﹂敍宀冪箾 `state.imageColor`閿涘牐鍎楅弲顖氬絿閺嶇柉澹婇敍澶愬厴娴兼矮绔寸挧铚傛丢閵?
      //   缂冩垶鐗稿┃鎰瑏娑撳秴鍩岄崣顏冪窗闁偓閸?鐎圭偞妞傚Ο锛勭ˇ鎼存洖娴?閿涘本妲?*閸欘垶妾风痪?*閻ㄥ嫸绱濇稉宥堫嚉閹锋牕鐏濋崣鏍閵?
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
            // 閸氬奔绔村▎鈥冲絿閼硅尙娈戠紒鎾寸亯妞ゅ搫鐢粻妤佺ウ閸忓澹婇敍宀€娓烽幒澶婂晙瀵よ桨绔存稉?ColorPicker 閻ㄥ嫬绱戦柨鈧?
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

    // 閳藉應妲?2026-10-15閿涙俺绻栭柌灞藉斧閺夈儲妲搁妴瀹峞ffectKit.blur(imageBlurRadius())` 妫板嫭瑕嗛弻鎾茬瀵姵膩缁?PixelMap
    //   鐠у绮?`imageLabel` 瑜版捁鍎楅弲顖氱俺閸ヤ勘鈧秲鈧倽鍎楅弲顖涙暭閹存劕鐤勯弮鑸的佺化濠傛倵**鏉╂瑦娼捄顖氬嚒閺佺繝缍嬮崑婊呮暏** 閳ユ柡鈧?
    //   `imageLabel` 娣囨繃瀵旀稉?`song.label`閿?*閸樼喎顫愮亸渚€娼?Resource**閿涘绱?
    //   閻?{@link originalCoverSource} 娴溿倗绮伴懗灞炬珯鐏?+ 缂佸嫪娆㈢痪?`.blur()` 閸樿鐤勯弮鑸的佺化濞库偓?
    //   鐟欙絿鐖滈崙鐑樻降閻?PixelMap 閸欘亝婀囬崝鈥茬艾娑撳﹪娼伴柇锝嗩偧閸欐牞澹婇敍宀€鏁ょ€瑰苯宓嗗鍐︹偓?
    //   閳跨媴绗?妞ゅ搫鐢憴锝嗗竴娑撯偓娑擃亪娈ｉ幃锝忕窗娴犮儱澧犵悮顐﹀櫞閺€鍓ф畱濮濓絾妲?濮濓絽婀ぐ鎾崇俺閸ョ偓瑕嗛弻鎾舵畱闁絽绱?PixelMap"
    //      閿涘牅绗呭▎鈩冨床濮?妞ょ敻娼伴崡姝屾祰閺?`releaseBackgroundCoverIfPixelMap()` 娴兼岸鍣撮弨鎯х暊閿涘绱?
    //      閻滄澘婀?`imageLabel` 閹帊璐?Resource 閳?**閼冲本娅欑仦鍌欑瑝閸愬秵瀵旈張澶夋崲娴ｆ洑绱扮悮顐﹀櫞閺€鍓ф畱娴ｅ秴娴?*閵?
    // 閳藉應妲?2026-10-15閿涙碍婀伴崷?閸愬懐鐤嗙亸渚€娼伴惃?64鑴?4 缂冩垶鐗稿┃鎰瘍娴溿倕鍤崢浼欑礄閼冲本娅欑仦鍌滄暏閿涘绱?
    //    鐎瑰啰娈戦悽鐔锋嚒閸涖劍婀￠弨鍦暠 `meshSrc` 閹镐焦婀侀敍鍫熷床濮濆本妞傞柌濠冩杹娑撳﹣绔村鐙呯礉鐟?`publishMeshSource`閿涘鈧?
    this.publishMeshSource(meshPm);
    this.releasePixelMapQuiet(pixelMap);
  }

  /**
   * 閹跺﹤鐨濋棃顫秴閸ユ儳浠涢幋?*缂冩垶鐗搁懗灞炬珯閻ㄥ嫭绨?*楠炴湹姘︾紒娆掑剹閺咁垰鐪伴妴?
   *
   * 閻撗勬儔閺冪姷鏅惃鍕絿閸ユ儳褰涘鍕剁礄`閹绢厽鏂佹い浣冨剹閺?MeshGradient娑撳懂eshSource鐎规氨顭?md` 鎼? / 鎼?閿涘绱?
   * ```
   * 64鑴?4 RGBA_8888閿涘牆褰茬紓鏍帆閿?
   *   閳?enhanceColors(u8)                              娴ｅ骸顕В?/ 妤傛﹢銈遍崪?/ 閸嬪繑娈敍鍫濈秼閼冲本娅欐稉宥嗗閸撳秵娅欓敍?
   *   閳?boxBlurRgba(u8, 64, 64, 9, 3)                  閻╂帒绱″Ο锛勭ˇ閿涘本妫?gamma
   *   閳?閸ョ偛鍟?PixelMap閿涘奔姘︾紒?MeshCoverBg閿涘牏缍夐弽鍏兼杹婢堆囨懙濠娾槄绱?
   * ```
   * 閳跨媴绗?`enhanceColors` 闁插瞼娈?`0.4` 娑?`鑴?` 閺?*闁板秴顨滈惃鍕鐎?*閿涘苯鍩嗛崣顏呮暭娑撯偓娑擃亷绱欐导姘崇箖閺囨繃鍨ㄩ崣鎴犱紗閿涘鈧?
   * 閳跨媴绗?閺傜増妫禍銈嗘禌妞ゅ搫绨敍?*閸忓牓鍣撮弨鍙ョ瑐娑撯偓瀵姰鈧礁鍟€鐠у鈧厧鑻?`++meshSrcVersion`** 閳ユ柡鈧?
   *    `MeshCoverBg` 閻?`@Monitor` 閻╂垵鎯夐惃鍕Ц**閻楀牊婀伴崣?*閿涘潉PixelMap` 閸樼喎婀撮弨鐟板敶鐎归€涚瑝娴兼俺袝閸欐垵鍩涢弬甯礆閵?
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
      // 鉀?2026-10-17锛?*涓嶅啓璺ㄩ〉闈㈢紦鍐?*锛堣 `adoptCachedMesh` 涓婇潰閭ｆ"褰撳ぉ鎾ゅ洖"锛?
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag, `mesh source build failed code=${e?.code}, message=${e?.message}`);
      this.releasePixelMapQuiet(pm);
      return;
    }
    const old: image.PixelMap | undefined = this.meshSrc;
    // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MorphGuard` 閻?闁板秷澹婄€瑰娼ょ粣妤€褰?閿涘绱拌ぐ銏犲綁鐞涖儵妫跨捄鎴犳絻閻ㄥ嫭妞傞崐?*娑撳秵宕查懗灞炬珯**
    //   閿涘牊宕查懗灞炬珯 = 閺佹潙鐪扮純鎴炵壐闁插秶鏁鹃敍宀冾潎閹扮喎姘ㄩ弰?閸斻劎鏁炬稉顓⑩偓鏃囧剹閺咁垵澹婄捄鍏呯娑?閿涘鈧倻鐛ラ崣锝堢箖閸樿鎮楅懛顏勫З鐞涖儰绗傞張鈧崥搴濈濞喡扳偓?
    // 閳藉應妲勯埥鍛 2026-10-17閿?*缁楊兛绔村鐘崇爱缂佹繀绗夌拋姝岊潶鏉╂瑩浜剧粣妤€褰涢幒銊ㄧ箿** 閳ユ柡鈧?娣囶喚鏁ら幋宄扮杽濞村鈧瞼鍋ｉ崙缁樺ⅵ瀵偓濞屸剝婀侀懗灞炬珯閵嗗稄绱?
    //   `old === undefined` 鐞涖劎銇氳ぐ鎾冲**閺嶈婀板▽鈩冩箒缂冩垶鐗稿┃?*閿涘牏鍋ｉ崙缁樺ⅵ瀵偓闁絼绔撮崚濠氥€夐棃銏犲灠閹稿倽娴囬妴浣诡劀閸︺劏袙閻緤绱氶妴?
    //   鏉╂瑧顫掗弮璺衡偓娆忓晙"缁涘鐣ㄩ棃娆戠崶閸欙綀绻冮崢?鐏忓崬褰ч崜鈺佸幑鎼存洖褰囬弽鐤閿涘牆鐢?alpha 閳?閸楀﹪鈧繑妲戦敍澶嗗櫩 閻劍鍩涢惇瀣煂閻ㄥ嫭妲?
    //   濞屸剝婀侀懗灞炬珯閵嗗倵鍣?缁楊兛绔村鐘崇爱**缁斿鍩㈤幓鎰唉**閿涙稑褰ч張?閺囨寧宕插鍙夋箒濠?閹靛秷铔嬬粣妤€褰涢敍鍫ュ亝閹靛秵妲?閸斻劎鏁炬稉顓⑩偓鏃囩儲閼?閻ㄥ嫬婧€閺咁垽绱氶妴?
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
   * 閹跺﹦缍夐弽鍏肩爱閻喐顒滈幐鍌欑瑐閸樹紮绱檣@link publishMeshSource} 閻?閹绘劒姘?闁絽宕愰敍澶堚偓?
   * @param pm 閺傛壆娈戠純鎴炵壐濠ф劧绱欓幍鈧張澶嬫綀鏉烆剛些缂佹瑦婀版い纰夌礆
   * @param old 鐞氼偅娴涢幑銏″竴閻ㄥ嫭妫┃鎰剁礄闂堢偟鈹栭崚娆撳櫞閺€鎾呯礆
   */
  private commitMeshSource(pm: image.PixelMap, old: image.PixelMap | undefined): void {
    this.meshSrc = pm;
    this.meshSrcVersion = this.meshSrcVersion + 1;
    if (old !== undefined && old !== pm) {
      this.releasePixelMapQuiet(old);
    }
  }

  /**
   * 鐎瑰娼ょ粣妤€褰涙潻鍥у箵閸氬氦藟娑撳﹥娓堕崥搴濈濞嗭紕缍夐弽鍏肩爱 閳ユ柡鈧?娑撳孩妫ら悾宀勫亝娑擃亪鍣哥拠?浣嶉敍鍧剋ujie.pa:157930-157939`閿?
   * 鐠?`syncReportChrome()` 閺勵垰鎮撴稉鈧禒鏈电皑閿?*缁愭褰涙稉鈧潻鍥ф皑閹跺﹥娓堕弬浼村帳閼硅尪藟娑撳﹤骞?*閵?
   * 濞屸剝婀佸鍛八夐惃鍕爱閺冭埖妲哥粚鐑樻惙娴ｆ嚎鈧?
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
   * 娑撯偓濞嗏€茬瑓鏉炲€熜掗崙铏规畱娑撱倕绱舵担宥呮禈閿涙艾鍙忕亸鍝勵嚟閿涘牊绁﹂崗澶婂絿閼硅尙鏁ら敍? **64鑴?4 缂冩垶鐗稿┃?*閿涘牐鍎楅弲顖滄暏閿涘鈧?
   *
   * 閳?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ瞼娈戦崣鏍ф禈閸欙絽绶為敍澶涚窗閹?64鑴?4 闁絼绔村鐘虫杹閸?*閸氬奔绔村▎陇袙閻?*闁插苯鍤敍?
   *   娑撳秴绻€娑撻缚鍎楅弲顖氬晙娑撳娴囨稉鈧柆宥呯殱闂堫潿鈧繖desiredSize` + `editable` 閺勵垰绻€妞よ崵娈?閳ユ柡鈧?
   *   缂冩垶鐗稿┃鎰洣閸?64鑴?4 娑撳﹤甯崷鏉夸粵 `enhanceColors` / `boxBlurRgba`閿涘牐顫?`publishMeshSource`閿涘鈧?
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
   * @returns 瑜般垹褰夌€圭懓娅掗惃?*妤傛ê瀹?*閿涙艾鑸伴崣妯绘埂闂傚瓨妲?缁旀牜娲跨憗浣稿缁愭褰?閿涘牆褰ч棁鎻掑毉娑撳﹪娼版潻娆庣閺夆槄绱氶敍?
   *          閸忔湹缍戦弮鍫曟？閹帊璐?`'100%'`閿? 娑撳孩鐥呴張澶庣箹婵傛濮╅悽缁樻闁劕鍎氱槐鐘辩閼疯揪绱氶妴?
   *
   * 閳跨媴绗?闂堟瑦顒涢幀?*韫囧懘銆?*缂?`'100%'` 閼板奔绗夐弰顖欐崲娴ｆ洜鐣婚崙鐑樻降閻ㄥ嫭鏆熺€涙绱版稊瀣閻劌鐤勫ù瀣畱
   *    `contentHeightVp` 瑜版捇娼ゅ銏ょ彯鎼达讣绱濋懓灞肩瑐閹躲儲绨幁鏉裤偨閺?*鏉╂瑥鐪伴懛顏勭箒鐞氼偉顥嗛崜顏呮閻ㄥ嫰鐝惔?*閿?
   *    娑撯偓濞嗏€茬瑐閹峰绠ｉ崥搴ょ箹娑擃亜鈧厧姘ㄧ悮顐㈠晸閹?~360vp閿涘奔绨弰顖涚槨濞嗏剝澧﹀鈧幘顓熸杹妞ら潧绨抽柈銊╁厴缂傝桨绔撮崸?
   *    閿涘牏鏁ら幋宄扮杽濞村寮芥＃鍫礆閵嗗倻娅ㄩ崚鍡樼槷妤傛ê瀹抽悽杈╁煑鐎圭懓娅掗敍鍫熷姬鐏炲繐顔栨稉浼欑礆閸愬啿鐣鹃敍灞肩瑝閸欘垵鍏樼粻妤呮晩閵?
   */
  /**
   * @returns 瑜般垹褰夌€圭懓娅掗惃?*妤傛ê瀹?*閿? 缁旀牜娲跨憗浣稿缁愭褰涢敍澶涚窗闂堟瑦顒涢幀?`'100%'`閿涘牏鐡戞禒铚傜艾娑撳秷顥嗛崜顏庣礆閵?
   *
   * 娑撳秴褰夐柌蹇ョ窗鐟佷礁澹€妤傛ê瀹?= 閸欘垵顫嬫妯哄 / 缂傗晜鏂?閳?鐏炲繋绗傞柇锝呮健閸欘垵顫嬮惌鈺佽埌闁?*濮濓絽銈?*閺勵垱鏆ｆい纰夌礉
   * 閺冦垺鐥呴張澶屾殌閻ф枻绱欑粭顒€娲撻悧?姒涙垹鐛ラ崣锝忕礉娑擃參妫挎稉鈧稉顏勭毈閹绢厽鏂佹い?鐏忚鲸妲搁悾娆戞閿涘绱濇稊鐔哥梾閺堝顥嗛崚鍥モ偓?
   * 閳跨媴绗?闂堟瑦顒涢幀浣哥箑妞よ崵绮?`'100%'` 閼板奔绗夐弰顖欐崲娴ｆ洜鐣婚崙鐑樻降閻ㄥ嫭鏆熺€涙绱伴惂鎯у瀻濮ｆ梻鏁卞鈥崇潌鐎瑰じ瀵岄崘鍐茬暰閿?
   *    娑撳秳绱扮悮顐ｇ厙濞嗏€宠埌閸欐娈戞稉顓㈡？閹礁鍟撻懘蹇ョ礄"鎼存洟鍎寸紓杞扮閸?鐏忚鲸妲告潻娆庣疄閺夈儳娈戦敍澶堚偓?
   */
  private morphClipHeight(): Length {
    if (!this.expandState.morphClipping()) {
      // 閳跨媴绗嶉埧鐙呯瑣 2026-10-17閿?*閻劍鍩涚粭?1/2 閺?鐞涖儵妫垮▽鈩冩箒閸斻劎鏁?閻ㄥ嫬鈧瑩鈧婧€閸?*閿涘绱?
      //   鏉╂瑩鍣烽崢鐔告降**閺冪姵娼禒鎯扮箲閸?`'100%'`閿涘牆鐡х粭锔胯閿?*閿涘矁鈧苯鑸伴崣妯绘埂鏉╂柨娲栭惃鍕Ц**閺佹澘鐡?*
      //   閳?`.height()` 鏉╂瑤閲滅仦鐐粹偓褍婀?*鐎涙顑佹稉?閳?閺佹澘鐡ф稊瀣？閸掑洦宕茬猾璇茬€?*閿?
      //     ArkUI **閺冪姵纭堕崷銊よ⒈缁夊秶琚崹瀣╃闂傚瓨褰冮崐?* 閳?鐞涖儵妫挎稉鈧挧閿嬪鐏?*閻╁瓨甯寸捄鍐插煂缂佸牏鍋?*
      //     閿涘牐顫囬幇?= "鐏忎線娼伴惄瀛樺复鐏忓崬鍩岀紒鎾存将娴ｅ秶鐤?/ 閻╁瓨甯存稉瀣箵閿涘本鐥呴張澶婂З閻?閿涘鈧?
      //   閳?娑撹桨绮堟稊?閹靛瀵氱捄鐔稿闁絾娼弰顖氥偨閻?閿涙岸鍋呴弶陇鐭惧В蹇庣鐢囧厴閸︺劌鍟?*閺佹澘鐡?*閿涘苯鍙忕粙瀣倱缁鐎?閴?
      //   閳?娑撹桨绮堟稊鍫ｎ洣 return 閺佹澘鐡ч懓灞肩瑝閺勵垯绻氶悾?'100%'閿涙岸娼ゅ銏♀偓渚€鍋呴弶鈩冩暈闁插﹥濯磋箛鍐畱閺?
      //     "**闁插繐鍤弶銉ф畱閸愬懎顔愭妯哄**娴兼俺顫﹂弻鎰偧瑜般垹褰夐崘娆掑壈"閿?鎼存洟鍎寸紓杞扮閸?閿涘绱?
      //     閼?*缁愭褰涙妯哄**閺?`reportWindow` 缂佹瑧娈戦弶鍐ㄢ枆閸婄鈧椒绗夐崣鍌欑瑢瑜般垹褰?閳?濞屸剝婀侀柇锝勯嚋妞嬪酣娅撻妴?
      //   閳跨媴绗?鐎圭懓娅掗悥鍓侀獓閺勵垱寮х仦蹇擃問娑?閳?閺佹澘鈧棿绗?`winHVp` 鐏忚京鐡戞禍?`'100%'`閵?
      //     缁愭褰涚亸鍝勵嚟鏉╂ɑ鐥呮稉濠冨Г閺冭绱欓弸浣规－閺堢噦绱氶幍宥夆偓鈧崶鐐茬摟缁楋缚瑕?閳ユ柡鈧?闁絾妲搁崬顖欑閻ㄥ嫪绔村▎锛勮閸ㄥ鍨忛幑顫礉
      //     娑撴柨褰傞悽鐔锋躬閺堫剟銆夐崚姘瘯鏉炲鈧浇绻曞▽鈩冩箒娴犺缍嶇悰銉╂？閻ㄥ嫭妞傞崐娆嶁偓?
      const h: number = this.expandState.windowHeightVp;
      return h > 0 ? h : '100%';
    }
    return Math.max(1, this.expandState.morphClipHeight);
  }

  /** Root: 閺佹挳銆夌紓鈺傛杹 + 缁旀牜娲跨憗浣稿缁愭褰涢敍鍫濆讲鐟欏棛鐓╄ぐ銏ゅ櫡濮濓絽銈介弰顖涙殻妞ょ绱? 濡椼儲甯寸亸渚€娼伴妴?*/
  build() {
    // 閳?缁楊兛绨查悧鍫窗**閺佹挳銆夌紓鈺傛杹 + 缁旀牜娲跨憗浣稿缁愭褰?*閵?
    //   閸欘垵顫嬮惌鈺佽埌娴?*鏉╄渹缍橀弶锟犲亝閺壜ゅ厡閸?*闂€鍨煂閺佹潙鐫嗛敍?閺佺繝閲滈幘顓熸杹閺夆€虫娴兼悂鎽靛鈧?閿涘绱?
    //   娑撳绔熼崷銊ュ 25% 鐏忚精鍒涢崚鏉款問娑撹绨虫潏鐧哥礄閸氾箑鍨惔鏇㈠劥闁絽鍤戦崡?vp 閺佸瓨顔岄崝銊ф暰闁晫鈹栭惈鈧敍澶涚幢
    //   閸愬懎顔愮仦鍌炵彯鎼?= 鐟佷礁澹€妤傛ê瀹?= 閸欘垵顫嬫妯哄 / 缂傗晜鏂侀敍灞惧娴犮儱褰茬憴鍡欑叐瑜般垽鍣?*濮樻瓕绻欐繅顐ｅ姬閺佹挳銆?*閿?
    //   濞屸剝婀侀悾娆戞閵嗕椒绡冩稉宥勭窗鐞氼偉顥嗛敍娑樺敶鐎圭懓鐪扮粵澶婂讲鐟欏棛鐓╄ぐ銏狀啍妤傛ɑ鐦幒銉ㄧ箮妞ょ敻娼伴弮鑸靛濞搭喚骞囬敍?
    //   闁灝鍘ゆ稉顓燁唽閻鍩屾稉鈧鐘侯潶閸樺澧庨惃鍕€夐棃顫礄闁絾顒滈弰?娴犲簼鑵戦梻鏉戠磻婵鈧胶婀呮稉宥呭毉鐏炴洖绱戞潻鍥┾柤"閻ㄥ嫭娼靛┃鎰剁礆閵?
    //   鐏忎線娼伴悽杈╃敾妞嬬偛鐨濋棃銏犲礋閻欘剛鐢绘鐑囩礉**p = 1 閹靛秷鎯ゆ担?*閿?026-10-15 鐠х兘鍋呮稉鈧Λ鎺旀暰閸?*婢瑰啿鐪板ù顔肩湴**
    //   `Index.MorphCoverClone()` 闁插矉绱盤C 婢瑰啿鐪版禒宥呮躬閺堫剟銆夐惃?`MorphCoverBridge`閿涘鈧?
    Stack({ alignContent: Alignment.TopStart }) {
      // 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*閼冲本娅欓弫鏉戠湴閹碱剙鍩岃ぐ銏犲綁鐎圭懓娅掓稊瀣樆**閵?
      //   閺冪姷鏅惃?`MeshCoverBg` 閸?`playerPane` **娑斿顦?*閿涘牅绗岀€瑰啫鎮撶痪褝绱氶埇?鐎瑰啩绗夐崣鍌欑瑢閹绢厽鏂佹い鐢垫畱
      //   `scale / clip` 閳?鐟欏倹鍔呴弰顖樷偓?*閸愬懎顔愭鐐扮瑐閺夈儯鈧浇鍎楅弲顖欑瑝閸?*閵嗗秲鈧?
      //   閹存垳婊戦崢鐔告降閹跺﹤鐣犻弨鎯ф躬瑜般垹褰夌€圭懓娅?*閸愬懘鍎?* 閳?鐠虹喓娼冪悮顐ょ搼濮ｆ柨甯囬崚鎵 34% 閸愬秵鏂佹径褝绱?
      //   閻劍鍩涚€圭偞绁寸亸杈ㄦЦ閵?*閸嶅繐甯囩紓鈺冩畱閼冲本娅欓柧鍝勭磻**閵嗗秲鈧?
      //   閳跨媴绗?閹碱剙鍤弶銉ユ倵鐎?*娑撳秴鍟€鐞氼偉顥嗛崜顏嗙崶閸欙綀顥?*閿涘牊鏆ｇ仦蹇撳讲鐟欎緤绱氶敍灞惧娴犮儱鑸伴崣妯绘埂閻ㄥ嫬褰茬憴浣藉瘱閸ユ挳娼?
      //     `backgroundRevealOpacity()`閿? 閺冪姷鏅?`pullBgIn`閿?閳?.30 濞ｂ€冲弳閿涘顓?閳ユ柡鈧?娑撳孩妫ら悾灞芥倱閸欙絽绶為妴?
      //   閳跨媴绗?閸忔粌绨崇仦鍌氬箵閹哄绨?`borderRadius(this.expandState.morphRadius)`閿涙碍鏆ｇ仦蹇撶湴娑撳秹娓剁憰浣告妇鐟欐帇鈧?
      // 閳藉應妲勯埥?2026-10-16閿涘牅鎱ㄩ悽銊﹀煕鐎圭偞绁撮妴?*閸忔娊妫撮幘顓熸杹閸ｃ劌褰ч張澶婂敶鐎归€涚窗瀵櫢绱濋懗灞炬珯鏉╂ɑ妲告稉宥勭窗瀵?*閵嗗稄绱氶敍?
      //   閹跺﹨鍎楅弲顖涙殻鐏炲倸顨滄潻娑楃娑?*娑撳骸鍞寸€圭懓鎮撴稉鈧弶鈩冨皨閸?*閻ㄥ嫬顔愰崳銊╁櫡閵?
      //
      // ## 閸樼喐娼垫稉杞扮矆娑斿牅绗夊?
      //
      // 閸忚櫕鎸遍弨鎯ф珤閺冨爼鍋呮稉鈧拋?瀵?閺?`morphSquashY`閿涘牏鐝崥鎴濆竾閹典緤绱氭す鍗炲З閻ㄥ嫸绱濈€瑰啯瀵曢崷?*鐠侯垳鏁辨竟?*
      //   閿涘潉PlaybackPageRoute.ets` 閻?`.scale({y: morphSquashY})`閿涘绗屾潻铚傜稑閺夆€茬瑐閵?
      //   閼板奔绗傛稉鈧幍瑙勫灉閹跺﹨鍎楅弲?*閹碱剙鍤禍鍡楄埌閸欐ê顔愰崳?*閵嗕焦瀵曢崚鐗堟拱妞ゅ灚鐗?`Stack` 閳ユ柡鈧?閺?`Stack` **娑撳秴婀捄顖滄暠婢规娊鍋呮稉?
      //   scale 閻ㄥ嫪缍旈悽銊ョ厵闁?*閿涘牐鐭鹃悽鍗烇紦閻?scale 閸欘亜甯囩€瑰啳鍤滃閬嶅亝濡潧鐡欓弽鎴﹀櫡閻ㄥ嫪绗㈢憲鍖＄礆閳?閸愬懎顔愬骞库偓浣藉剹閺咁垳姹楁稉婵呯瑝閸斻劊鈧?
      //
      // ## 閻滄澘婀幀搴濈疄瀵櫢绱欐稉鏂胯埌閻樿埖顒滅涵顕嗙礆
      //
      // 婢舵牠娼版總妞剧鐏炲倸顔愰崳顭掔礉缂佹瑥鐣?`.height(H 鑴?k)` + `.offset({y: 閳墲(1閳姙)/2})` + `.scale({y: k})`閿?
      // 娴ｅ灝鐣犻惃?*鐟欏棜顫庨惌鈺佽埌閹帞鐡戞禍?`0 閳?H璺痥铏廯**閵嗕椒绗?*缂佹洜鐛ラ崣锝勮厬韫?*閸樺澧庨敍?
      // ```
      //   鐢啫鐪惌鈺佽埌 y 閳?[閳墲(1閳姙)/2 , 閳墲(1閳姙)/2 + Hk]
      //   閿涘潉.offset` 閸欘亝灏撶紒妯哄煑閻╂帪绱漙Alignment.TopStart` 娑撳婀崑蹇曅╅弮璺虹安娑?[0, Hk]
      //     閳?閸戝繐骞?H(1閳姙)/2 瀵版鍩屾稉濠囨桨鏉╂瑤閲滈崠娲？閿?
      //   鐢啫鐪稉顓炵妇 y_c = (閳墲(1閳姙)/2 + (閳墲(1閳姙)/2 + Hk))/2 = H(2k閳?)/2 = Hk 閳?H/2
      //   `.scale` 缂?*閼奉亣闊╂稉顓炵妇**缂傗晜鏂?閳?娑擃厼绺炬稉宥呭З閵嗕線鐝惔?鑴砶
      //   鐟欏棜顫庢妯哄 = Hk铏?閵嗕浇顫嬬憴澶夎厬韫?= Hk 閳?H/2
      //   閳?鐟欏棜顫?top = (Hk 閳?H/2) 閳?Hk铏?2 = H(2k 閳?1 閳?k铏?/2 = 閳墲(1閳姙)铏?2
      //   閳?鐟欏棜顫?bottom = 鐟欏棜顫?top + Hk铏?= H(2k 閳?1 + k铏?/2 = H(1+k)铏?2 閳?H
      // ```
      // **娑撱倗顏柈鎴掑紬閺嶅吋顒滅涵?*閿涙瓪k = 1` 閳?`[0, H]`閿? 閺佹潙鐫嗛敍宀勨偓鎰剼缁辩姷鐡戞禒鍑ょ礆閿?
      // `k = SQUASH_Y` 閳?鐟欏棜顫庨惌鈺佽埌閹澘銈介弰?缂佹洜鐛ラ崣锝勮厬韫囧啯濡稿鈥崇潌閸樺鍩?k"閻ㄥ嫮绮ㄩ弸婊愮窗
      //   `(H 閳?Hk)/2 = H(1閳姙)/2`閳ワ腹鈧?娴狅絽鍙?`k` 閸栨牜鐣濆?`鐟欏棜顫?top = H(1閳姙)铏?2`閿?
      //   閼?缂佹洑鑵戣箛鍐ㄥ竾閸?k"閻?top 閺?`H(1閳姙)/2` 閳?娑撱倛鈧懎婀?`k = 1` 娑?`k 閳?0` 婢跺嫪绔撮懛娣偓?
      //   娑擃參妫块幀浣规付婢舵艾妯?`H(1閳姙)(k)/2`閵?
      //   閳跨媴绗?**鏉╂瑦妲搁張顒侇偧閸烆垯绔存稉鈧径?鏉╂垳鎶€"**閿涘苯顩х€圭偟娅ョ拋甯窗闂堟瑦顒涢幀渚婄礄`k = 1`閿?*闁劕鍎氱槐鐘辩瑝閸?*閺勵垳瀛╃痪鍖＄礉
      //     瑜般垹褰夋稉顓㈡？閹線鍋呴崙?vp 閻ㄥ嫬浜稿顔款洣娑撳﹥婧€閻?閳ユ柡鈧?閼汇儳婀￠張杞扮瑐"閸樺缂夐弮鎯板剹閺咁垯绗傛稉瀣苟鏉?閿?
      //     鐏忚鲸濡?`.scale` 閹广垺鍨?`.scale({centerY: '50%'})` 娑斿顦婚惃鍕綗娑撯偓閺壜ょ熅閿涘牏鏁ゆ稉銈呯湴鐟佷礁澹€鐞涖儱浼╅敍澶涚礉
      //     闁絾妞傞崘宥嗘暭閿?*娑撳秷顩﹂悳鏉挎躬閸戭厾瀵介崝鐘茬埗閺?*閵?
      // 閳藉應妲勯埥?2026-10-16閿?*閻撗勬儔閺冪姷鏅惃鍕湴缁?*閿涙俺鍎楅弲顖氭礀閸掓澘鑸伴崣妯侯啇閸?*閸愬懘鍎?*閿?
      //
      // ## 閹存垳绠ｉ崜宥夋晩閸︺劌鎽㈤敍鍫ｇ箾闁挎瑤绗佹潪顕嗙礉閻劍鍩涢崶娑欘偧鐎圭偞绁撮幍鎾虫礀閿?
      //
      // 閹存垳绔撮惄缈犱簰娑撶儤妫ら悾宀€娈?`MeshCoverBg` 閸?`playerPane` **娑斿顦?*閿涘奔绨弰顖涘Ω鐎瑰啯鎯夐崚鐗堟拱妞ゅ灚鐗?`Stack`
      // 閳?鐎?*娴犲海顑囨稉鈧敮褍姘ㄩ弫鏉戠潌**閵嗕浇鈧奔绗?*鐟佷椒绗夐崚?*閵嗗倻鏁ら幋宄扮杽濞村鈧?*閹绢厽鏂侀崳銊ョ潔瀵偓鏉╂ɑ妲搁懗灞炬珯閸忋劌鐫?*閵嗗秲鈧?
      //
      // 閺堫剝鐤嗛幎濠冩￥閻ｅ瞼娈?*鐎圭懓娅掗弽?*娑撯偓鐠侯垵顕伴柅姘啊閿涘潉wujie.pa`閿涘绱?
      // ```
      //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   閳?閺?Stack
      //   @36***# (191388)  Stack(TopStart)
      //                       .scale({x: expand.scaleValue, y: 閳ヮ洠)      191400-191415
      //                       .translate({x: expand.translateX, 閳ヮ洠)     191416-191431
      //                       .width(expand.clipWidth)                  191432-191441
      //                       .height(expand.clipHeight)                191442-191451
      //                       .borderRadius(expand.radius)              191452-191461
      //                       .clip(true)                               191462-191469
      //                       .id(PLAYER_ROOT_ID)                       191470-191478
      //                     閳规壕鏀?If (191716 @36***#^4 閳?@36***^4*#/^1)
      //                     閳?   閳规柡鏀?Column (191756 @36***#^5)
      //                     閳?        閳规壕鏀?If (191972 @36***#^7 閳?@36***^7*#)  = **playerPane**閿涘湩ow閿?
      //                     閳?        閳规柡鏀?If 閳?**MeshCoverBg**              192105 / 192191
      //                     閳规柡鏀?閳?
      // ```
      // 閳?**`MeshCoverBg` 閸?`PLAYER_ROOT_ID` 闁絼閲?Stack 閻ㄥ嫰鍣烽棃?*
      //   閳?鐎?*鐠虹喓娼冪€圭懓娅掓稉鈧挧?scale閵嗕椒绔寸挧鐤潶 clip**閵?
      //   鏉╂瑥姘ㄩ弰?鐏炴洖绱戦弮鎯板剹閺咁垯绗夋导姘殻鐏炲繈鈧浇鈧本妲告禒搴＄毈缁愭褰涢柌宀勬毐閸戠儤娼?閻ㄥ嫭婧€閸掕翰鈧?
      //
      // 閳跨媴绗?閹存垳绗傛稉鈧悧鍫ュ亝閸?閺冪姷鏅惃?MeshCoverBg 閸?playerPane 娑斿顦婚敍鍫滅瑢鐎瑰啫鎮撶痪褝绱?**閺勵垶鏁婇惃?*閿?
      //   閺夈儲绨弰顖氬涧閻绨￠悧鍥唽閵嗕焦鐥呴幎?`PLAYER_ROOT_ID` 闁絼閲?Stack 閻?*闂傤厼鎮庨懠鍐ㄦ纯**鐠囪鍤弶銉ｂ偓?
      //   閿涘潉RzdMusic鐠佹澘绻?md` 鎼?6.50 闁插奔绡冮弰顖濈箹娑斿牆鍟撻惃?閳ユ柡鈧?娑撯偓楠炴湹缍旀惔鐔粹偓鍌︾礆
      //
      // ## 閹碱剙娲栭崢璁崇閸氬骸鎮撻弮鎯靶掗崘宕囨畱娑撱倓娆㈡禍?
      //
      // 1. **鐏炴洖绱戞稉宥呭晙"閼冲本娅欓崗銊ョ潌"**閿涙艾鑸伴崣妯绘埂鐎圭懓娅掗崣顏呮箒鏉╄渹缍橀弶锟犲亝娑斿牆銇?閳?閼冲本娅欐稊鐔峰涧閸︺劑鍋呮稉鈧亸蹇撴健闁插矉绱?
      //    闂呭繐顔愰崳銊╂毐婢堆嗏偓宀勬懙瀵偓閿涘牐绻栭幍宥嗘Ц"妞嬬偘绗傞弶?閻ㄥ嫯顫囬幇鐕傜礆閿?
      // 2. **閸忔娊妫撮弮鎯板剹閺咁垵绐￠惈鈧稉鈧挧宄板竾**閿涙艾顔愰崳銊︽拱閺夈儱姘ㄩ崷銊ㄧ熅閻㈠崬锛撻柇锝嗘蒋 `morphSquashY` 閻ㄥ嫪缍旈悽銊ョ厵闁?
      //    閿涘潉PlaybackPageRoute.ets` 閻?`.scale({y})` 閸樺鏆ｆ稉顏呮尡閺€楣冦€夐敍澶嗗櫩 **娑撳秴鍟€闂団偓鐟曚焦鍨滄稉濠佺閻?
      //    閸旂姷娈戦柇锝勯嚋 `.scale + height + offset` 鐞涖儱浼╃€圭懓娅?*閿涘牆鍑￠崚鐘绘珟閿涘矁顫?`squashWrapHVp` 閻ㄥ嫬鍨归梽銈堫唶瑜版洩绱氶妴?
      Column() {
        // 閳藉應妲勯埥鍛 2026-10-17閿?*閻撗勬儔閺冪姷鏅惃鍕儑娑撳鐪拌ぐ銏㈠Ц**閿涙艾鍞寸仦?`Stack` 娑旂喎绻€妞ょ粯妲?`TopStart`閿?
        //   閺冪姷鏅柇锝夊櫡閺勵垯绔撮崣?`Column閿涘牆顔?100% + winHVp + padTop/padBottom閿涘ˇ 閻╁瓨甯撮崸鎰躬
        //   `Stack(TopStart)` 闁?閳ユ柡鈧?**濞翠礁绱＄€涙劘濡悙?*閵嗕礁娴愮€规氨鐛ラ崣锝夌彯閵嗗倹鍨滄禒顒冪箹鐏炲倸甯弶銉︽Ц姒涙顓?
        //   閿涘潉Center`閿? 鐎瑰じ瀵?`.position(0,0)`閿涘奔绗屾稉濠冪埗娑撳秵妲搁崥灞肩娑擃亜鑸伴悩韬测偓?
        //   閳?閺€瑙勫灇 `TopStart`閿涘苯顔栨稉鑽ゆ畱閸ュ搫鐣剧亸鍝勵嚟閹靛秵婀侀幇蹇庣疅閿涘牊鐥呴張澶婄暊閿涘苯娴愮€规岸鐝惃鍕劉鐎涙劒绱扮悮顐㈢湷娑擃厽灏撶挧甯礆閵?
        Stack({ alignContent: Alignment.TopStart }) {
          // 閳?閼冲本娅?= **閸楀﹪鈧繑妲?閳?娑撳秹鈧繑妲?*閿涙艾绨抽懝韫瑢閸欐牞澹婄仦鍌欑鐠х柉铔嬮崣宥囩椽鐠囨垹娈?
          //   `pullBgIn = clamp(effT / 0.30)`閿? 閳?0.30 濞ｂ€冲弳閿涘鈧?
          // 閳跨媴绗?娑撳﹪娼伴柇锝勮⒈閸欍儻绱?鎼存洝澹婃稉搴″絿閼规彃鐪版稉鈧挧鐤泲 `pullBgIn`"閿涘妲?**瀹歌弓缍旀惔?*閿?
          //   閼?2026-10-15 鐠у嚖绱濋柇锝勮⒈鐏?*閺佹潙鐫嗙痪顖濆鐏炲倸鍑＄紒蹇旀殻鐏炲倸鍨归梽?*閿涘牅绗呴棃銏犳皑閺勵垰鍨归梽銈呮倵閻ㄥ嫮骞囬崷鐚寸礆閵?
          //
          // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*閺冪姷鏅▽鈩冩箒缁绢垵澹婇崹顐㈢俺閿涘瞼缍夐弽鍏兼拱闊偄姘ㄩ弰顖氱俺**閵?
          //   娓氭繃宓?`_recover/logic-src/閺冪姷鏅玽s濞查箖鐓?瀹割喖绱撻崚鍡樼€?md` L303-304閿?
          //     閳?閵嗗畭Column().backgroundColor('#1c1c1e').opacity(...)` 鏉╂垿绮﹂崹顐㈢俺鐏炲倶鈧秮鍟?閺冪姷鏅笟?**閺?*閿?
          //     閳?閵嗗畭Column().backgroundColor(state.imageColor)` 鐏忎線娼伴崣鏍ㄧ壉閼规彃鐪伴妴宥佸晪 **濞屸剝婀佺€电懓绨查悧?*閵?
          //   娑撱倕鐪伴柈鑺ユЦ濞查箖鐓堕弮褑鐭鹃敍娑樼暊娴狀剙褰旈崷銊х秹閺嶉棿绠ｆ稉瀣剁礉閸欘亙绱扮拋?鐏炴洖绱戝鈧慨瀣亝娑撯偓閸?婢舵艾鍤稉鈧崸妤冧紗閺嗘鍍电€?
          //   閿涘牐顫?`backgroundRevealOpacity()` 閻ㄥ嫭鏁為柌濠忕礆閵?
          //
          //   閳?闁絽鐪?闂堟瑦顒涢幀浣风瑝闁繑妲戞惔?閻滄澘婀幖顒€鍩屾禍?*鐠侯垳鏁辨竟?*娑撳绱欐潻娆愭Ц閺冪姷鏅惃鍕秴缂冾噯绱?
          //     `wujie.pa:190867-190884` 閻?`.backgroundColor(pullMode && effT()>=1 ?
          //     PULL_REST_BG : expand.overlayColor)`閿涘绱濋拃鐣屽仯鐟?
          //     `PlaybackPageRoute.ets` 閻?`PlaybackPageRouteShell`閿?
          //       璺?瑜般垹褰夐張鐔尖偓蹇旀 閳?缁愭褰涙径鏍偓蹇撳毉妫ｆ牠銆夋稉搴ょ碃娴ｇ姵娼敍鍫濊埌閸欐娈戦崜宥嗗絹閿涘绱?
          //       璺?闂堟瑦顒涢幀浣风瑝闁繑妲?閳?閹绢厽鏂佹い浣冨殰瀹歌京娈戞惔鏇礉妞ゅ搫鐢惄鏍︾秶閻樿埖鈧焦鐖稉搴＄俺闁劑鍋呮稉銈嗘蒋
          //         閿涘牏鏁ら幋宄扮杽濞村鈧苯鍞寸€硅鐥呭鏈靛嚑鏉╂稓濮搁幀浣圭埉閵嗗秲鈧苯绨抽柈銊ょ閺夛紕鈹栭惂鑺ョ础閸戝搫鎮楅棃銏犲敶鐎瑰箍鈧稄绱氶妴?
          //     閳?閹碘偓娴?*妞ょ敻娼伴崘鍛瑝閸愬秹娓剁憰?*娴犺缍嶉弫鏉戠潌缁绢垵澹婄仦鍌︾礉閸掔姵甯€鐎瑰啩绗夋导姘毉閻?閼冲本娅欑粚杞扮閸?閵?
          //
          //   閳跨媴绗?娑撳娼扮純鎴炵壐闁絽鐪伴惃?`backgroundRevealOpacity()` **娣囨繄鏆€**閿涙艾鐣犵亸杈ㄦЦ閺冪姷鏅惃?`pullBgIn`
          //      閿涘牐鎹ｉ悙?0閵嗕浇绐￠惈鈧ぐ銏犲綁鏉╂稑瀹抽崚?1閿涘绱濋棃娆愵剾閹焦浜芥稉?1閵?

          // 閳跨媴绗?缁毖囨閸忚泛鎮楅惃鍕亝濞?鐎圭偞妞傚Ο锛勭ˇ鎼存洖娴?鐠囧瓨纭堕埥?**娑旂喎鍑℃担婊冪熬**閿涙岸鍋呭?`Image(鐏忎線娼?.blur(11)`
          //   瀹稿弶鏆ｇ仦鍌氬灩闂?閳ユ柡鈧?鐎瑰啫甯崗鍫濆涧娴?缂冩垶鐗稿┃鎰繁鐢厽妞傞惃鍕幑鎼?閿涘矁鈧苯鍘规惔鏇犲箛閸︺劍鏁奸幋鎰啊**缁绢垰褰囬弽鐤**
          //   閿涘牐顫嗘稉瀣桨 `else` 閸掑棙鏁敍澶堚偓鍌氬灩鐎瑰啰娈戦崢鐔锋礈閿涙艾鐣犵粵澶夌艾**閸︺劎缍夐弽闂寸婢舵牕寮甸悽璁崇啊娑撯偓瀵姴鐨濋棃?*閿?
          //   閹广垺娼甸悽銊﹀煕鐎圭偞绁撮惃鍕┾偓宀勫亝娑擃亙琚卞鐘茬殱闂堛垹褰ф导姘躬閸斻劎鏁炬潻鍥┾柤娑擃厼鍤悳鑸偓宥冣偓?
          //   閳?`backdropBlurRadiusVp()` / `LIVE_BACKDROP_BLUR_VP` / `originalCoverSource()`
          //     閻滄澘婀?*瀹稿弶妫ょ拫鍐暏閼?*閿涘牏鏆€閸︺劍鏋冩禒鍫曞櫡閺勵垯璐熸禍鍡曠瑝閻楅潧濮?`isPixelMapCover` 闁絾娼猾璇茬€烽崚鍡樻暜閿?
          //     鐎瑰啩婊戦惃鍕殻娴ｆ挻绔婚悶鍡楃秺閸?閸掔姵娣抽棅鎶戒粣閻?闁絼绔撮崸妤嬬礉鐟?`RzdMusic鐠佹澘绻?md` 鎼?6.6閿涘鈧?
          // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍姘冲剹閺咁垰绨虫惔褎宕查幋?**缂冩垶鐗歌ぐ銏犲綁閼冲本娅?*閿涘潉MeshCoverBg`閿涘鈧?
          //   鐟欏嫭鐗搁敍姝歘recover/logic-src/閹绢厽鏂佹い浣冨剹閺?MeshGradient娑撳懂eshSource鐎规氨顭?md`
          //   閿涘潉MESH_SUB=4`閵嗕梗SRC_EDGE=64`閵嗕梗boxBlur(9,3)`閵嗕梗displaySync` 20fps閵嗕線妞勯梻?= `playing && active`閿涘鈧?
          //   鐎瑰啳鍤滅敮?*瀵板嫬鎮滈弳妤勵潡**閿涘潉scrim` 姒涙顓?true閿涘绱濋幍鈧禒銉ょ瑓闂堛垽鍋呯仦鍌滃缁斿娈?`radialGradient`
          //   閸︺劎缍夐弽鑲╂晸閺佸牊妞傝箛鍛淬€忛崗铏竴閿涘苯鎯侀崚娆庣窗閸欑姳琚辨禒鑺ユ鐟欐帇鈧?
          //   閳跨媴绗?缂冩垶鐗稿┃鎰箷濞屸€崇紦婵傛枻绱欓幑銏＄摃闁絼绔撮惉顒婄礆閺?*闁偓閸ョ偛鐤勯弮鑸的佺化濠囧亝瀵姴娴?*閿涘奔绗夋导姘毉閻?閼冲本娅欑粚杞扮閸?閵?
          // 濞翠礁鍘滈懗灞炬珯閿涘牐顔曠純顕€銆嶅鈧崗绛圭礆閿涙艾绻€妞よ婀崘鍛啇鐏炲倷绠ｉ崜宥囩帛閸掕绱濋崥锕€鍨导姘辨磰娴ｅ繐鐨濋棃銏犳嫲濮濆矁鐦?
          if (this.flowLightState.enabled && this.tintReady) {
            this.FlowLightBackground()
          }

          // 閳藉應妲?2026-10-15閿?*瀵板嫬鎮滈弳妤勵潡**閿涘潉閺冪姷鏅玽s濞查箖鐓?瀹割喖绱撻崚鍡樼€?md` 鎼?.4閵嗗苯顕鎰紦鐠?璺?閳?閸欘亜濮炲鍕倻閺嗘顫楅妴宥忕礆閵?
          //   鏉╂瑤绔撮弶鈩冩Ц闁絼鍞ら弬鍥ㄣ€傜紒娆戞畱**閺堚偓鐏忓繗鐭剧痪?*閿涙氨鍑芥竟鐗堟瀵繈鈧線娴傞弬棰佺贩鐠ф牓鈧胶鐝涢崚璇插讲閹?
          //   閳ユ柡鈧?娑?缂冩垶鐗稿ù浣稿З閼冲本娅?閿涘潉MeshCoverBg`閿涙瓪NodeContainer` + 閼奉亜鐣炬稊?`RenderNode.drawPixelMapMesh`
          //   + `displaySync` 闁劕鎶氭い鍓佸仯閿涘矁顫?`閹绢厽鏂佹い浣冨剹閺?MeshGradient娑撳懂eshSource鐎规氨顭?md` 鎼?閿?*閸掑棗绱?*閿?
          //   闁絽顨滈張顒冪枂**娑撳秴浠?*閿涘矁绻栭柌灞藉涧閸欑姳绔寸仦鍌氱窞閸氭垵甯囬弳妞尖偓?
          //
          //   闁劙銆嶉弫鏉库偓濂稿厴閸欐牞鍤滈弬鍥ㄣ€傞敍鍧刐閸楁洘绨甝`閿涘苯鍤径鍕晸閺勫簼浜掓笟鍨槻閺嶉潻绱氶敍?
          //   `閺冪姷鏅玽s濞查箖鐓?瀹割喖绱撻崚鍡樼€?md` 鎼?.4 缂佸嫪娆㈤弽鎴炴汞鐞涘奔绗岄妴灞告噣閵嗗秹鍋呮稉鈧▓?閳ユ柡鈧?閺冪姷鏅?
          //   `MeshCoverBg` 閻?`Stack` **閺堚偓娑撳﹪娼?*鐏忚鲸妲告潻娆庣鐏?`Column().radialGradient(...)`閿?
          //   閼板本鍨滄禒顒傛畱 `Stack` 闁?閸愬懎顔愮仦?閿涘潉buildControlStack`閿涘绡冮弰顖涙付閸氬海鏁鹃惃鍕┾偓?
          //   閳?娑撹桨绨℃稉宥呮倖閸掓澘鍞寸€圭懓鐪伴敍宀冪箹闁插本鏂侀崷?*鐏忎線娼版惔鏇炴禈鐏炲倷绠ｉ崥?* 閳ユ柡鈧?鐎瑰啫婀弽鍫ュ櫡閻ㄥ嫮绮崚鏈电秴缂?
          //      娑撳孩妫ら悾?閸樺婀弫缈犻嚋閼冲本娅欐稊瀣╃瑐閵嗕礁鍞寸€归€涚娑?閻ㄥ嫯顕㈡稊澶岀搼娴犲嚖绱欓弮鐘垫櫕闁絼绔寸仦鍌欑娑撳妲哥純鎴炵壐閼冲本娅欓敍?
          //      閹存垳婊戦惃鍕敶鐎圭懓鐪伴弰?*娑撳秹鈧繑妲?*閻ㄥ嫮瀚粩瀣湴閿涘奔绗夐崣妤€鐣犺ぐ鍗炴惙閿涘鈧?
          //   璺?`center: ['50%', '50%']` 閳ユ柡鈧?閸﹀棗绺鹃崷銊︻劀娑擃叏绱欓弬鍥ㄣ€傞崥灞筋槱閿涘绱?
          //   璺?`radius: '70%'` 閳ユ柡鈧?閺傚洦銆傞崥灞筋槱閿涙稑鐣奸弬?`ts-universal-attributes-gradient-color`
          //     閿?026-10-15 閸欐牜娈戦崢鐔告瀮閿涘绱伴妴灞界窞閸氭垶绗庨崣妯兼畱閸楀﹤绶為敍瀹痷mber 缁鐎烽弮璺哄礋娴ｅ秳璐?vp閿?
          //     鐠佸墽鐤嗛惃鍕偓闂磋礋 undefined 閺冨墎閮寸紒鐔稿瘻缂佸嫪娆㈢亸鍝勵嚟閼奉亜濮╃粻妞尖偓宥佸櫩 鏉╂瑩鍣风紒?*閻ф儳鍨庡В鏂跨摟缁楋缚瑕?*閿?
          //     闂呭繐顔愰崳顭掔礄= 閺佹潙鐫嗛敍澶庤泲閿涘奔绗夐弰顖氭祼鐎?vp閿?
          //   璺?`colors: [['#26000000', 0], ['#26000000', 0.45], ['#66000000', 1]]`
          //     閳ユ柡鈧?閺傚洦銆?鎼?.4 鐢悂鍣虹悰顭掔窗`SCRIM_CENTER = "#26000000"`閿涘熂鎵佸15%閿涘鈧?
          //     `SCRIM_EDGE = "#66000000"`閿涘熂?40%閿涘绱濇稉顓炵妇閼硅弓绔撮惄鎾懙閸掓澘宕愬鍕畱 45% 閹靛秴绱戞慨瀣竾閺嗘绱?
          //     閿涘牆鐤勯悳浼村櫡閸愭瑦鍨氱粵澶娾偓鑲╂畱閸椾礁鍙氭潻娑樺煑鐎涙娼伴柌?`0x26/0x66`閿涘奔绗岄崥灞炬瀮娴犺泛鍙炬担娆愮瑤閸?鎼存洝澹婇崘娆愮《娑撯偓閼锋番鈧偊绱?
          //   璺?閼瑰弶鐖ｉ惃鍕儑娴滃奔閲滈崗鍐閺?*濮ｆ柧绶?[0,1.0]**閿涘奔绗夐弰?vp 閳ユ柡鈧?鏉╂瑤绗佹径?0 / 0.45 / 1 閺堫剚娼电亸杈ㄦЦ
          //     濮ｆ柧绶ラ崘娆愮《閿涘牆鎮?鎼?1.1 闁絾娼崡鏇氱秴閸ф埊绱辩€规ɑ鏌熼崢鐔告瀮閵嗗苯褰囬崐鑹板瘱閸ョ繝璐?[0, 1.0]閵嗗稄绱氶妴?
          //
          //   閳跨媴绗?娑撳孩妫ら悾宀€娈戞稉鈧径?*瀹歌尙鐓″顔煎焼**閿涙碍妫ら悾宀勫亝娑撯偓鐏炲倹妲?*閹帒绱?*閿涘牆褰ч悽?`scrim` 鐢啫鐨甸梻銊﹀付閿涘绱?
          //      閹存垳婊戞潻娆撳櫡閸?*瑜般垹褰?鏉烆剙婧€閺堢喖妫块崗铏竴**閿涘牆顦查悽?`backgroundRevealOpacity()` 閸氬本顑欓惃?
          //      `morphContainerActive()` 閸掋倖宓侀敍澶嗏偓鏂衡偓?閸氾箑鍨ぐ銏犲綁娑擃參鍋呮稉顏囶潶 scale+clip 閻ㄥ嫬鐨粣妤€褰涢柌?
          //      娴兼艾顦挎稉鈧仦鍌氬竾閺嗘绱濇稉?閸楀﹪鈧繑妲?閳?娑撳秹鈧繑妲?闁絾娼弮銏℃箒閸欙絽绶為幍鎾寸仸閵?
          //      鐟欏倹鍔呴弰顖氭儊鐟曚焦鏁奸幋鎰航瀵偓閿?*閸欘亣鍏樻稉濠冩簚閻?*閿涘牐顫嗛張顒冪枂閹躲儱鎲￠惃?閸欘亣鍏樻稉濠冩簚绾喛顓?濞撳懎宕熼敍澶堚偓?
          // 閳?缂冩垶鐗搁懗灞炬珯閼奉亜鐢弳妤勵潡 閳?閸欘亝婀?*闁偓閸ョ偞膩缁﹤绨抽崶?*闁絾娼捄顖涘闂団偓鐟曚浇绻栨稉鈧仦?
          //   閿涘牆鎯侀崚娆庣窗閸欑姳琚辨禒鑺ユ鐟欐帪绱濇稉顓炵妇鐞氼偄甯囨稉銈変憾閿涘鈧?
          if (this.meshSrc === undefined) {
            Column()
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .radialGradient({
                center: ['50%', '50%'],
                radius: '70%',
                colors: [[0x26000000, 0.0], [0x26000000, 0.45], [0x66000000, 1.0]]
              })
              // 閳藉應妲勯埥?2026-10-17閿涘牏鏁ら幋鍑ょ窗閵嗗奔绗傞幏澶嬪ⅵ瀵偓閺堝鍎楅弲顖ょ礉**閻愮懓鍤仦鏇炵磻 / 閸忔娊妫?/ 缁崵绮烘潻鏂挎礀濞屸剝婀侀懗灞炬珯**閵嗗稄绱?
              //
              // ## 閺堝搫鍩楅敍鍫ｎ嚢娴狅絿鐖?+ 娑撱倓閲滅拠缁樻殶閸楀啿绶遍敍?
              // ```
              //   缂冩垶鐗哥仦鍌涙Ц `if (meshSrc === undefined) { 閸忔粌绨?} else { MeshCoverBg(...) }`
              //   閻愮懓鍤仦鏇炵磻 / 閸忔娊妫撮崣鎴犳晸瀵版妫敍灞绢劃閺?`song.cover` 鏉╂ɑ鐥呴崚鐗堝 閳?meshSrc === undefined
              //   閳?缂冩垶鐗告稉宥嗗瘯鏉炴枻绱遍懓灞藉幑鎼存洝绻栨稉銈呯湴閻ㄥ嫭娈憴鎺戠湴閸樼喐娼甸崘娆戞絻
              //        .opacity(morphContainerActive() ? 0 : 1)
              //     閳?**瑜般垹褰夐張鐔割劀婵傝姤濡哥€瑰啫鍙ч幒?* 閳?鐏炲繋绗傞崣顏勫⒖鏉╂垿绮﹂崣鏍ㄧ壉閼?= "濞屸剝婀侀懗灞炬珯"
              //   娑撳﹥濯洪幍鎾崇磻閹粯妲搁崣鎴犳晸閸︺劌鐨濋棃銏犲鏉炶棄鐣稊瀣倵 閳?缂冩垶鐗搁崷?閳?濮濓絽鐖?閴?
              // ```
              // ## 閺€瑙勭《
              //   閸忔粌绨崇仦鍌滄畱閺嗘顫?*娑撳秷顔忛崷銊ヨ埌閸欐ɑ婀″☉鍫濄亼** 閳ユ柡鈧?鐎瑰啯顒濋崚缁樻Ц**閸烆垯绔撮惃鍕剹閺?*閵?
              //   閿涘牏缍夐弽鐓庣摠閸︺劍妞傛潻娆愭蒋閸掑棙鏁弽瑙勬拱娑撳秷绻橀敍灞惧娴犮儰绗夋导姘嫲缂冩垶鐗搁懛顏勭敨閻ㄥ嫭娈憴鎺戝綌娑撱倓鍞ら妴鍌︾礆
              .opacity(1)
              .hitTestBehavior(HitTestMode.None)
          }

          // 鐏忎線娼扮紒顓㈩棧濞搭喖鐪伴敍姘仚閸︺劏鍎楅弲顖欑瑢閸愬懎顔愭稊瀣？閿涘苯鍨忔い鐢稿亝 0.36 缁夋帡鍣锋い鑸垫禌娑撱倕绱堕棃娆愨偓浣哥殱闂?
          // No cover overlay: the lyric page has no matching image destination.

          // 閳藉應妲?2026-10-15 閻劍鍩涚€圭偞绁存稉銈嗘蒋閿涘矁绻栨稉鈧径鍕Ц閸忓崬鎮撻惃鍕壌閿?
          //   閵?*鐏忓繑鐡曠拠宥嗘Ц娴犲孩鍨滅亸渚€娼伴懗灞芥倵閸戣櫣骞?*閿涘奔绗夐弰顖欑矤娑撳鏌熸鐐扮瑐閺夈儯鈧?閵嗗矁绻樻惔锔芥蒋娴兼俺顫﹂幐鈥茬秶閿涘牆鍎氶弰顖氱殱闂堛垺灏呴惃鍕剁礆閵?
          //   閳?缂侇參顥ｇ亸渚€娼伴崢鐔告降閻㈣婀?*閺佹挳銆夐崘鍛啇娑斿绗?*閿涘牊鐗?Stack 閻ㄥ嫭娓堕崥搴濈娑擃亜顒㈢€涙劧绱氶敍灞肩艾閺?
          //     璺?娴犲簼绗呴崡鍥崳閻?*鐏忓繑鐡曠拠?*閸忓牐顫︾€瑰啯灏呴惈鈧?閳?閻鎹ｉ弶銉︽Ц"娴犲骸鐨濋棃銏ｅ剹閸氬骸鍟嬮崙鐑樻降"閿?
          //     璺?閸氬本鐗辨禒搴濈瑓閸楀洩鎹ｉ惃?*閹貉冨煑閸?*閿涘牐绻樻惔锔芥蒋+閹稿鎸抽敍澶夌瘍娴兼俺顫︾€瑰啫甯囨担蹇嬧偓?
          //   閻滄澘婀幎濠傜暊閹割亜鍩?*閸愬懎顔愮仦鍌欑閸?*閿涙艾鑸伴崣妯绘埂闂傚瓨鎸遍弨楣冦€夐懛顏勭箒闁絽绱堕惇鐔风殱闂堛垺妲搁梾鎰閻?
          //   閿涘潉realCoverVisible()` 娑撳搫浜?閳?鐏忎線娼板Σ鎴掔秴閺勵垳鈹栭惃鍕┾偓渚€鈧繑妲戦惃鍕剁礆閿涘本澧嶆禒銉х敾妞嬬偛鐨濋棃銏㈠弾閺嶇兘鈧繐绶遍崙鐑樻降閵?
          //   娴ｅ秶鐤嗘稉搴°亣鐏忓繋绔村Ο鈥茬閺嶅嚖绱欑€瑰啯婀伴弶銉ユ皑閺勵垱瀵?鏉╄渹缍橀弶鈥崇殱闂?閳?閹绢厽鏂佹い闈涚殱闂?閹绘帒鈧偐鏁鹃惃鍕剁礆閿?
          //   閼?*閹碘偓閺堝宕屾稉濠冩降閻ㄥ嫬鍞寸€瑰綊鍏橀崷銊ョ暊娑斿绗?* 閳?娑撱倗绮嶆鐐插弳闁€熷厴鐞氼偆婀呯憴渚婄礉娑旂喍绗夐崘宥勭鞍閻╂悂浼勯幐?閳ユ柡鈧?
          //   鏉╂瑦妲哥紒鎾寸€稉濠勬畱娣囨繆鐦夐敍灞肩瑢"闁插繐绶遍崙鍡曠瑝閸?閺冪姴鍙ч妴?
          //   閳跨媴绗?娑撳秷顩﹂崘宥嗗皳閸ョ偛骞撻敍鍩?7 闁絾顐?閻绗夌憴?閺勵垱鍨滈崥灞肩鏉烆喖濮為惃?`barOpacity` 閹跺﹨绯犳担鐘虫蒋閻喕闊╂稊鐔绘娴滃棝鈧姵鍨氶惃鍕剁礉
          //      闁絼閲滈梻銊ュ嚒缂佸繐鍨归梽銈忕幢閺堫剝濡潻娆戝濞屸剝婀佺€瑰喛绱氶妴?
          // 閳藉應妲?2026-10-15閿涘牆锛撶仦鍌涜癁鐏炲倿鍋呮稉鈧潪顕嗙礆閿?*閹绢厽鏂佹い鍏哥瑝閸愬秶鏁炬潻娆忕炊缂侇參顥ｇ亸渚€娼?* 閳ユ柡鈧?
          //   `hostsMorphOverlay()` 娑撹櫣婀￠敍鍫熷閺?楠炶櫕婢樿ぐ銏♀偓渚婄礆閺冭绱濋柇锝勭濡帒鍑＄紒?*閹碱剙鍩屾竟鍐茬湴濞搭喖鐪?*
          //   閿涘潉products/default/src/main/ets/pages/Index.ets` 閻?`MorphCoverClone()`閿涘绱?
          //   楠炴湹绗栭悽?*鐎瑰啳鍤滃杈╂畱鏉╂稑瀹?* `morphOverlayP` 妞瑰崬濮╅敍?60ms閿?
          //   `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)`閿涘鈧?
          //   閻ｆ瑥婀幘顓熸杹妞ょ敻鍣烽悽鑽ゆ畱闁絼绔撮悧鍫熸箒娑撯偓娑擃亞绮ㄩ弸鍕偓褎鐦洪惀鍜冪窗鐎瑰啫婀潻娆庨嚋**鐞?scale+translate 閸欐ɑ宕叉潻鍥モ偓?
          //   鏉╂ê鐢?`.clip()` 娑撳骸濮╅幀?`.height(morphClipHeight())` 閻ㄥ嫬顔愰崳?*闁插矉绱濋惌鈺佽埌閸楀瓨妲哥粣妤€褰涢崸鎰垼
          //   閳?閸欘亝婀?p=1閿涘牊浜界粵澶婂綁閹诡澁绱氶幍宥勫紬閺嶅吋顒滅涵顕嗙礉娑擃參鈧柨褰ч懗?鏉╂垳鎶€"閿涘苯宸婚崣韫瑐閸欏秴顦查崙?閸撳秴宕愬▓鐢垫箙娑撳秷顫?/
          //   鐞氼偄鍩嗛惃鍕鐟楁寧灏呮担?閵嗗倹璇炵仦鍌炲亝娴犳垝绗夐崷銊ㄧ箹娑擃亜顔愰崳銊╁櫡閿涘本鐥呴張澶庣箹娑擃亪妫舵０妯糕偓?
          //   閳跨媴绗?閸掋倖鏌囬弶鈥叉娑撳秵妲?p 閸掔増鐥呴崚?閿涘矁鈧本妲?*鐎瑰じ瀵岄張澶嬬梾閺堝甯寸粻?*閿涘牐顫?`hostsMorphOverlay()`閿涘绱?
          //     PC 婢瑰啿鐪伴敍鍧刾roducts/pc`閿涘绻曞▽鈩冨复鏉╂瑤鍞ゅù顔肩湴閿涘矂鍋呮潏?*缂佈呯敾閻㈣鲸鎸遍弨楣冦€夐懛顏勭箒閻?*
          //     閳ユ柡鈧?閸氾箑鍨导姘毉閻?娑撱倛绔熼柈鎴掔瑝閻?閻?*閺冪姴鐨濋棃?*缁岀儤銆傞妴?
          //   閳跨媴绗?閹绢厽鏂佹い浣冨殰瀹搁亶鍋呭?*閻喎鐨濋棃?*閸︺劌鑸伴崣妯绘埂闂傜繝绮涢悞鏈电瑝閻紮绱檂realCoverVisible()` 闁絾濡搁梻銊︾梾閸旑煉绱氶敍?
          //     閸氾箑鍨导姘毉閻滈琚辨稉顏勭殱闂堫澁绱辨稉銈堚偓鍛紬閺嶉棿绨扮悰銉ｂ偓?
          if (this.expandState.morphBridging() && !this.expandState.hostsMorphOverlay()) {
            this.MorphCoverBridge()
          }

          // 閳藉應妲勯埥?2026-10-16閿?*閻撗勬儔閺冪姷鏅惃鍕湴缁?*閿涙俺鍎楅弲顖氭躬瑜般垹褰夌€圭懓娅?*閸愬懘鍎?*閿?
          //
          // ## 閹存垳绠ｉ崜宥夋晩閸︺劌鎽㈤敍鍫ｇ箾闁挎瑤绗佹潪顕嗙礉閻劍鍩涢崶娑欘偧鐎圭偞绁撮幍鎾虫礀閵嗗本鎸遍弨鎯ф珤鐏炴洖绱戞潻妯绘Ц閼冲本娅欓崗銊ョ潌閵嗗稄绱?
          //
          // 閹存垳绔撮惄缈犱簰娑撶儤妫ら悾宀€娈?`MeshCoverBg` 閸?`playerPane` **娑斿顦?*閿涘奔绨弰顖涘Ω鐎瑰啯鎯夐崚鐗堟拱妞ゅ灚鐗?
          // `Stack` 閳?鐎?*娴犲海顑囨稉鈧敮褍姘ㄩ弫鏉戠潌**閵嗕浇鈧奔绗?*鐟佷椒绗夐崚?*閵?
          //
          // 閺堫剝鐤嗛幎濠冩￥閻ｅ瞼娈?*鐎圭懓娅掗弽?*娑撯偓鐠侯垵顕伴柅姘啊閿涘潉wujie.pa`閿涘绱?
          // ```
          //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   閳?閺?Stack
          //   @36***# (191388)  Stack(TopStart)
          //                       .scale({x: expand.scaleValue, y: 閳ヮ洠)      191400-191415
          //                       .translate({x: expand.translateX, 閳ヮ洠)     191416-191431
          //                       .width(expand.clipWidth)                  191432-191441
          //                       .height(expand.clipHeight)                191442-191451
          //                       .borderRadius(expand.radius)              191452-191461
          //                       .clip(true)                               191462-191469
          //                       .id(PLAYER_ROOT_ID)                       191470-191478
          //                     閳规壕鏀?If (191716 @36***#^4)
          //                     閳?   閳规柡鏀?Column (191756 @36***#^5)  閳?濠婏紕鐛ョ€?+ winHVp + padTop/padBottom
          //                     閳?        閳规壕鏀?If (191972 @36***#^7 閳?@36***^7*#) = **playerPane**閿涘湩ow閿?
          //                     閳?        閳规柡鏀?If 閳?**MeshCoverBg**             192105 / 192191
          //                     閳规柡鏀?閳?
          // ```
          // 閳?**`MeshCoverBg` 閸?`PLAYER_ROOT_ID` 闁絼閲?Stack 閻ㄥ嫰鍣烽棃?* 閳?鐎?*鐠虹喓娼冪€圭懓娅掓稉鈧挧?
          //   `scale`閵嗕椒绔寸挧鐤潶 `clip`**閵嗗倽绻栭幍宥嗘Ц"鐏炴洖绱戦弮鎯板剹閺咁垯绗夋导姘殻鐏炲繈鈧浇鈧本妲告禒搴＄毈缁愭褰涢柌宀勬毐閸戠儤娼?閻ㄥ嫭婧€閸掕翰鈧?
          //
          // 閳跨媴绗?閹存垶顒濋崜宥夊亝閸?閺冪姷鏅惃?`MeshCoverBg` 閸?`playerPane` 娑斿顦婚敍鍫滅瑢鐎瑰啫鎮撶痪褝绱?**閺勵垶鏁婇惃?* 閳ユ柡鈧?
          //   閺夈儲绨弰顖氬涧閻绨￠悧鍥唽閵嗕焦鐥呴幎?`PLAYER_ROOT_ID` 闁絼閲?Stack 閻?*闂傤厼鎮庨懠鍐ㄦ纯**鐠囪鍤弶銉ｂ偓?
          //   閿涘牆宸婚崣鍙夋暈闁插﹪鍣烽崙陇绻栨稊鍫濆晸閻ㄥ嫪绔撮獮鏈电稊鎼寸喆鈧偊绱?
          //
          // ## 閺€鎯ф躬鐎圭懓娅掗柌灞芥倱閺冩儼袙閸愬厖琚辨禒鏈电皑
          //
          // 1. **鐏炴洖绱戞稉宥呭晙"閼冲本娅欓崗銊ョ潌"**閿涙艾鑸伴崣妯绘埂鐎圭懓娅掗崣顏呮箒鏉╄渹缍橀弶锟犲亝娑斿牆銇?閳?閼冲本娅欐稊鐔峰涧閸︺劑鍋呮稉鈧亸蹇撴健闁插矉绱?
          //    闂呭繐顔愰崳銊╂毐婢堆嗏偓宀勬懙瀵偓閿?
          // 2. **閸忔娊妫撮弮鎯板剹閺咁垵绐￠惈鈧稉鈧挧宄板竾**閿涙艾顔愰崳銊︽拱閺夈儱姘ㄩ崷銊ㄧ熅閻㈠崬锛撻柇锝嗘蒋 `morphSquashY` 閻ㄥ嫪缍旈悽銊ョ厵闁?
          //    閳?娑撳秴鍟€闂団偓鐟曚焦鍨滄稉濠佺閻楀牆濮為惃?`.scale + height + offset` 鐞涖儱浼╃€圭懓娅掗敍鍫濆嚒閸掔媴绱氶妴?
          //
          // 閳跨媴绗?娴ｅ秶鐤嗛敍姘啇閸?`Column` 閻?*缁楊兛绔存稉顏勵劉鐎?*閿涘牐鍎楅弲顖氭躬娑撳鈧礁鍞寸€圭懓婀稉濠忕礆閿?
          //   `.position({x:0,y:0})` 鐟曞棛娲婇弫缈犻嚋鐎圭懓娅?閳?娑撳秴寮稉搴ｆ棻閸氭垶甯撶敮鍐跨礄閸氾箑鍨导姘Ω閸愬懎顔愰幐銈勭瑓閸樹紮绱氶妴?
          Column() {
            // 閳藉應妲勯埥鍛 2026-10-17閿?*缂冩垶鐗哥仦鍌氱埗妞逛紮绱濇稉宥呭晙閻?`if` 閸︺劌鑸伴崣妯硅厬闁梹瀵曟潪?* 閳ユ柡鈧?
            //   娣囶喚鏁ら幋宄扮杽濞村鈧瞼鍋ｉ崙缁樺ⅵ瀵偓閿涙艾濮╅悽鏄忕箖缁嬪鐥呴懗灞炬珯閵嗕礁濮╅悽鑽ょ波閺夌喎姘ㄩ張澶堚偓宥忕礆
            //
            // ## 娑撹桨绮堟稊?閺夆€叉閹稿倽娴?娴兼碍绱￠幒澶嬫殻濞堥潧濮╅悽?
            //   閻愮懓鍤幍鎾崇磻閺冨爼銆夐棃銏犲灠閹稿倽娴囬妴涔eshSrc` 鏉╂ɑ妲?undefined 閳?`if` 鐠ф澘鍘规惔鏇炲瀻閺€顖ょ幢
            //   缁涘缍夐弽鍏肩爱閸掔増澧滈敍鍫濆殤閸椾簥閸戠姷娅?ms 閸氬函绱歚if` 閹靛秶鐐曢惇?閳?**`MeshCoverBg` 閸︺劌鑸伴崣妯跨箻鐞涘苯鍩屾稉鈧崡濠冩
            //   閹靛秶顑囨稉鈧▎鈩冨瘯鏉?*閵嗗倽鈧?`NodeContainer` + `RenderNode` 閸︺劎顨涢崗鍫燁劀鐞?`animateTo`
            //   鐞涖儵妫块敍鍧刪eight`/`clip` 濮ｅ繐鎶氶崷銊ュ綁閿涘娈戦張鐔兼？妫ｆ牗顐奸幐鍌濇祰閺冭绱濋懛顏嗙帛閸愬懎顔愮憰浣虹搼鐞涖儵妫块弨璺虹啲閵?
            //   閺佸瓨锛曢弽鎴濆繁閸掔兘鍋呮稉鈧敮褎澧犵悮顐㈡値閹存劕鍤弶銉礄婢舵牠鍎存径宥嗙壋 `gemini-4-argon-thinking` 缁?1 閺夆槄绱?
            //   "閸?`NodeContainer` 閻ㄥ嫯濡悙鐟版躬鐞涖儵妫块張鐔兼？娑撳秷顩﹂崝銊︹偓浣规暭 `height`/闁插秴瀹?`clip`閿?
            //    閸氾箑鍨崣顖濆厴閺佹潙娼℃稉宥呭棘娑撳骸鎮庨幋?閿涘鍣?鐏炲繋绗傞弫瀛橆唽閸斻劎鏁鹃柈鑺ユЦ缁岃櫣娈戦妴?
            //   閳?閻滄澘婀?*鐢悂鈹?*閿涙矮绮犳い鐢告桨閹稿倽娴囬柇锝勭閸掕姘ㄧ€涙ê婀敍鍫濊埌閸欐ê绱戞慨瀣╃閸撳稄绱氶敍灞藉涧閺?`src` 閸︺劌褰夐妴?
            //     閺勯箖娈?濞ｂ€冲弳娴犲秶鍔ч崣顏嗘暠 `backgroundRevealOpacity()` 缁犅扳偓?
            //   閳跨媴绗?閸忔粌绨抽惃?閸欐牗鐗遍懝?娑撳秴鍟€閺勵垯绔寸仦鍌氬帞瀵喕濡悙鐧哥礄`Column` 闁插奔琚辨稉?100% 鐎涒晛鐡欐导姘辨棻閸氭垶甯撳鈧敍澶涚礉
            //     鐎瑰啰娈戦懕宀冪煑瀹歌尙绮￠悽?*鐎瑰じ瀵岄懛顏勭箒閻?`.backgroundColor`**閿涘牅绗夐柅蹇旀鎼存洖楠囬敍澶嬪閹峰懌鈧?
            MeshCoverBg({
              src: this.meshSrc,
              srcVersion: this.meshSrcVersion,
              // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`seed: seedOfParts($$.title, $$.artist)`閿涘绱?
              //   閸欐牔绗夐崚鏉跨殱闂堛垺妞傜紒鍕閸愬懐鏁ゆ潻娆庨嚋缁夊秴鐡欓柅鐘插幑鎼存洜缍夐弽纭风礄`fillFallback` 閸ユ稖顫?HSL 濞撴劕褰夐敍澶堚偓?
              seed: this.meshSeed(),
              playing: this.state.isPlay,
              active: this.state.isShowPlay,
              // 閳藉應妲勯埥鍛 2026-10-17閿?*閻撗勬儔閺冪姷鏅崢鐔告瀮**閿涙瓪entryFade: !pullMode || effT() >= 1`閿?
              //   `wujie.pa:192183-192320` 閻ㄥ嫬鐤勯崣鍌炩偓鎰摟鐏忚鲸妲告潻娆庨嚋鐞涖劏鎻蹇嬧偓鍌濐嚔娑斿绱?
              //     璺?娑撳秵妲告稉瀣闁絾娼敍鍫㈠仯閸戠粯澧﹀鈧?/ 閸忔娊妫?/ 缁崵绮烘潻鏂挎礀閿涘鍣?**娑撳秵璐伴崗?*閿涘牏鐝涢崚璇插讲鐟欎緤绱氶敍?
              //     璺?娑撳濯洪柇锝嗘蒋閿涙艾褰ч張澶婅埌閸欐铔嬬€瑰矉绱檂effT() >= 1`閿涘澧犳稉宥呭晙濞ｂ€冲弳閵?
              entryFade: !this.expandState.pullMode || this.expandState.effT() >= 1,
              // 閴€?2026-10-17閿?*闁偓閸?0 = 閻㈣绔风捄鐔烘絻鐎瑰じ瀵岀€圭偞绁寸亸鍝勵嚟** 閳ユ柡鈧?閻劍鍩涚€圭偞绁撮惃鍕礀瑜版帪绱?
              //   娑撳﹣绔撮悧鍫滅炊 `windowHeightVp` 閹櫕濡搁悽璇茬闁藉缍囬敍鍫熶笉"閸樺澧庨埆鎺撳娴?閿涘绱?
              //   缂佹挻鐏夐悽銊﹀煕閹躲儯鈧?*閻愮懓鍤幘顓熸杹閸斻劎鏁炬潻鍥┾柤鏉╂ɑ妲稿▽陇鍎楅弲?*閿涘苯濮╅悽鑽ょ波閺夌喎鎮楅幍宥嗘箒閵嗗稄绱?
              //   `fixedHVp > 0` 閺?`RenderNode.frame` **濮ｆ柨鐣犻幍鈧崷銊ф畱闁絼閲滈惄鎺戠摍妤?*閿?
              //   閼板苯鑸伴崣妯绘埂闁絼閲滈惄鎺戠摍鐏忚鲸妲哥憗浣稿缁愭褰涢敍鍫濆殤閸椾簥閸戠姷娅?vp閿涘鍣?鐡掑懎鍤悥鍓佹磪閻ㄥ嫮绮崚鎯邦潶閺佹潙娼￠崜鏃堟珟
              //   閳?**瑜般垹褰夐張鐔剁矆娑斿牓鍏樻稉宥囨暰**閿涙稖鎯ゆ担宥呮倵娑撱倛鈧懐娴夌粵?閳?閸欏牊顒滅敮鎼炩偓?
              //   閳?閸欘垵顫嗛幀褌绱崗鍫窗娴?0閿涘矁顔€閻㈣绔峰姝岀箼缁涘绨€瑰じ瀵岄惄鎺戠摍閿? 娑撯偓閻╃鍏橀悽璇插毉閺夈儻绱氶妴?
              //   閳跨媴绗?娴狅絼鐜弰顖氳埌閸欐ɑ婀＄純鎴炵壐娴兼岸娈㈢憗浣稿缁愭褰涙稉鈧挧宄板竾/閹峰绱欓悽銊﹀煕閺冣晛澧犻幎杈ㄢ偓銊ㄧ箖閻ㄥ嫰鍋呴弶鈽呯礆閵?
              //     鐟曚礁鎮撻弮鑸靛姬鐡?閻㈣绶遍崙?+"娑撳秴甯囬幍?閿涘苯绶遍幑銏犲焼閻ㄥ嫭婧€閸掕绱欐笟瀣洤閹跺﹨鍎楅弲顖溞╅崚鎷屾寢閻楀牅绠ｆ径鏍暠婢瑰啿鐪扮憗浣稿閿涘绱?
              //     娑撳秷顩﹂崘宥囨暏"閻㈣绔峰В鏃傛磪鐎涙劕銇?鏉╂瑧顫掗崘娆愮《閵?
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
          // 閳藉應妲勯埥鍛 2026-10-17閿?*閼冲本娅欑€瑰じ瀵屾稉鈧?100%閿?閸ュ搫鐣剧亸鍝勵嚟"閸欘亞绮扮純鎴炵壐閻㈣绔烽敍灞肩瑝缂佹瑥绔风仦鈧?*閿?
          //
          // ## 娑撳﹣绔撮悧鍫ユ晩閸︺劌鎽㈤敍鍫㈡暏閹村嘲鐤勫ù瀣剁窗**閼冲本娅欑€瑰苯鍙忔稉宥堫潌娴?*閿涘矂娼ゅ銏♀偓浣风瘍濞屸剝婀侀敍?
          //   娑撳﹣绔撮悧鍫熷Ω**鐎瑰じ瀵?*閻ㄥ嫰鐝惔锔跨矤 `'100%'` 閺€瑙勫灇閸ュ搫鐣?`windowHeightVp`閵嗗倸顔栨稉缁樻Ц
          //   `.position({x:0,y:0})` 閻ㄥ嫮绮风€电懓鐣炬担宥呯摍閼哄倻鍋ｉ敍宀冣偓宀€鍩楃€圭懓娅掓?= `morphClipHeight()`閿?
          //   娑撯偓娑擃亝鐦憗浣稿缁愭褰涙径褏娈戦崶鍝勭暰鐏忓搫顕惄鎺戠摍閸欏倷绗岄悥鍓佸閺?鐟佷礁澹€闁炬儳鎮楅敍灞炬殻鐏炲倸姘?*娑撳秴鍟€鐞氼偆绮崚?*
          //   閿涘湙emini-4-Argon 婢跺秵鐗抽崥宀€绮ㄧ拋鐚寸窗Stack 鐎涙劘濡悙纭呯Т閸戦缚顫?`.clip(true)` 閻ㄥ嫮鍩楅惄鎺撴閿?
          //   濞撳弶鐓嬬粻锛勫殠娴兼碍鏆ｉ崸妤€澧ч梽銈忕幢鐟欙箑褰傛潻鍥︾濞嗏€茬閸?*闂堟瑦顒涢幀浣风瘍娑撳秳绱伴懛顏勭箒閸ョ偞娼?*閿涘鈧?
          //   閴€?**娑撳秷顩?*閸愬秵濡哥€瑰じ瀵岄惃鍕槀鐎靛憡宕查幋鎰祼鐎规碍鏆?閳ユ柡鈧?鐎瑰啫绻€妞よ崵鏁遍悥鍓侀獓 100% 閹炬垵绱戦妴?
          //
          // ## 閻喐顒滅憰浣锋叏閻ㄥ嫭妲?缂冩垶鐗稿В蹇旑偧闁插秵甯?閿? 閸樺澧庨埆鎺撳娴奸潻绱氶敍宀勫亝娴犳湹绨ㄩ崣鎴犳晸閸?*閻㈣绔?*娑?
          //   `NodeContainer.onAreaChange 閳?controller.resize(w,h) 閳?field.update(w,h)`
          //   閳?鐠嬩胶娈戦惄鎺戠摍閸︺劌褰夐敍宀€缍夐弽鐓庢皑閹稿鐨濋惃鍕槷娓氬鍣稿娲€婇悙鐟拌嫙闁插秹鍣伴弽鏋偓?
          //   閳跨媴绗?**2026-10-17 閻滄壆濮搁敍姝歠ixedHVp` 瀹告煡鈧偓閸?0**閿涘牏鏁剧敮鍐閻偓鐎瑰じ瀵岄惄鎺戠摍閿涘鈧?
          //     閺囨崘鐦潻鍥ㄥΩ鐎瑰啴鎷ら幋?`windowHeightVp` 濞?閸樺澧?閿涘奔绲?*閻㈣绔峰В鏃傛磪鐎涙劕銇?閳?閺佹潙娼￠崜鏃堟珟**
          //     閳?瑜般垹褰夐張鐔剁矆娑斿牓鍏樻稉宥囨暰閿涘牏鏁ら幋宄扮杽濞村琚卞▎鈽呯礆閵嗗倸褰茬憴浣光偓褌绱崗鍫礉閸樺澧庨柇锝嗘蒋閸忓牏鏆€閻偓閵?
          //     鐟曚礁鎮撻弮鑸靛姬鐡掔绱濆妤佸Ω閼冲本娅?*缁夎鍤ぐ銏犲綁鐎圭懓娅?*閿涘牆顦婚柈銊ヮ槻閺嶇缂撶拋顔炬畱閺傝顢?A閿涙俺鍎楅弲顖氱湴娑撳骸顔愰崳銊ユ倱缁狙佲偓?
          //     閼奉亜绻侀悽?`clip` + `scale/translate` 鐠虹喖娈㈤敍澶涚礉娑撳秵妲哥拫鍐ㄦ槀鐎垫瓕鍏樼憴锝呭枀閻ㄥ嫨鈧?
          .width(StyleConstants.FULL_WIDTH)
          // 閳藉應妲勯埥鍛閳?2026-10-17閿?*閻撗勬儔閺冪姷鏅敍姘問娑撹崵娈戠亸鍝勵嚟閺勵垯绔存稉顏勬祼鐎规碍鏆?`winHVp`閿涘奔绗栭弰顖涚ウ瀵繐鐡欓懞鍌滃仯**閿?
          //
          // 閺冪姷鏅惃鍕啇閸ｃ劍鐖查敍鍧剋ujie.pa:191756`閿涘矂鈧劘顢戦弽姝岀箖閿涘绱?
          // ```
          //   Stack(TopStart) .scale .translate .width('100%') .height(clipHeight) .clip(true)
          //     閳规柡鏀?Column  鐎?100% + **height(winHVp 閸ュ搫鐣鹃弫?** + padTop/padBottom     閳?濞翠礁绱＄€涒晛鐡欓敍灞炬￥ .position
          //          閳规壕鏀?playerPane
          //          閳规柡鏀?MeshCoverBg
          // ```
          // 閳?娑撱倓閲滅憰浣哄仯閿涘牊鍨滄禒顑跨閸撳秳琚遍弶锟犲厴闁挎瑱绱氶敍?
          //   閳?**閼冲本娅欑€瑰じ瀵岄惃鍕彯鎼达附妲搁崶鍝勭暰缁愭褰涙?*閿涘奔绗夌捄?`clipHeight` 鐠?閳?`NodeContainer` 閻?
          //      `onAreaChange` **閸欘亣袝閸欐垳绔村▎?*閿涘畭RenderNode.frame` 鐏忓搫顕?*閹帒鐣?* 閳?閼奉亞绮崘鍛啇娑撳秳绱?
          //      濮ｅ繐鎶氱悮顐﹀櫢瀵?婢惰鲸鏅ラ妴鍌涘灉娴狀剙甯弶銉ュ晸 `'100%'` = 鐠虹喓娼冪憗浣稿缁愭褰涘В蹇撴姎閸?閳?濮ｅ繐鎶?`resize()`
          //      閳?缂冩垶鐗稿В蹇撴姎闁插秵鏌婇柌鍥ㄧ壉/闁插秴缂撻敍灞借埌閸欐ɑ婀￠獮鑼跺墷娴犫偓娑斿牓鍏樻稉宥呭⒖ 閳?閻劍鍩涢惇瀣煂閻?閸忋劎鈻兼?閵?
          //   閳?鐎瑰啯妲?*濞翠礁绱＄€涙劘濡悙?*閿涘牊鐥呴張?`.position`閿涘绱濋棃鐘靛煑 `Stack(TopStart)` 鐠愭潙涔忔稉濠咁潡閵?
          //      閹存垳婊戦崢鐔告降閻?`.position(0,0)` 閻ㄥ嫮绮风€电懓鐣炬担?閳?闁板秴鎮?鐡掑懎鍤悮?clip 閻ㄥ嫮鍩楅惄?娴兼俺顫﹂弫鏉戞健閸撴棃娅?
          //      閿涘煪?59 闁絾顐?閼冲本娅欑€瑰苯鍙忔稉宥堫潌"鐏忚鲸妲告潻娆愭蒋閿涘鈧?
          //   閳跨媴绗?闂堟瑦顒涢幀渚婄窗鐎圭懓娅掓?= 缁愭褰涙?閳?閸ュ搫鐣炬妯圭瑢 `'100%'` **鐎瑰苯鍙忕粵澶夌幆** 閳?闁劕鍎氱槐鐘辩瑝閸欐ǜ鈧?
          .height(this.expandState.windowHeightVp)
          // 閳藉應妲勯埥鍛 2026-10-17閿?*娑撳秹鈧繑妲戞惔鏇為獓** 閳ユ柡鈧?缂冩垶鐗告稉鍥︾濞岋紕鏁鹃崙鐑樻降閿涘奔绡冩稉宥勭窗闂囨彃鍤＃鏍€?鏉╄渹缍橀弶鈽呯礆
          //   閻?`defaultImageBgColor`閿涘潉rgba(32,32,32,1)`閿涘本婀版い闈涘斧閺堝娈?鏉╂ɑ鐥呴張澶婂絿閼瑰弶妞傞惃鍕俺閼?閿涘鈧?
          //   閳跨媴绗?娑撳秷鍏橀崝鐘冲灇"缁楊兛绨╂稉顏勭摍閼哄倻鍋?閳ユ柡鈧?鐎瑰じ瀵岄弰顖氼啇閸ｎ煉绱濇稉銈勯嚋 100% 鐎涒晛鐡欐导姘辨棻閸氭垶甯撳鈧妴?
          .backgroundColor(PlaybackPage.defaultImageBgColor)
          .hitTestBehavior(HitTestMode.None)
          // 閴€?2026-10-17閿?*娑撳秳绠婚崣宥囩級閺€?* 閳ユ柡鈧?娓氭繃宓侀弰顖滄暏閹撮绮伴惃鍕￥閻ｅ奔鑵戝▓鍨焻閸ユ拝绱?
          //   閺冪姷鏅稉顓燁唽閹搭亜娴橀弰鍓с仛閿?*缂冩垶鐗搁弰顖炴懙濠娾剝鏆ｅ鐘插幢閻楀洨娈?*閿涘牊鐗哥€涙劙娈㈤崡锛勫娑撯偓鐠х柉顫﹂崢?鐏炴洖绱戦敍?
          //   閳?閼冲本娅欑捄鐔烘絻鐎圭懓娅掔紓鈺傛杹閺堫剝闊╅弰顖氼嚠閻ㄥ嫸绱濋崣宥囩級閺€鍙ョ窗鐠佲晛鐫嗘稉濠傚涧閸撯晙绔村鐘冲姬鐏忓搫顕純鎴炵壐閻?*娑撯偓閸ф鍨忛悧?*閵?
          //   閿涘牆宸婚崣鏌ュ亝娑撱倛绋涢崣宥囩級閺€楣冨厴瀹稿弶鎸欓崶鐑囩礉`bgInverseScale()` 娑旂喎鍑￠崚鐘绘珟閵嗗偊绱?
          // 閳藉應妲勯埥?2026-10-16閿?*閼冲本娅欑仦鍌濆殰鐠?* 閳ユ柡鈧?鐟?`diagBgBox` 閻ㄥ嫭鏁為柌濠忕礆閿?
          //   闁插繒娈戦弰?*閺堫剙鐪伴敍鍫ｅ剹閺咁垰顔栨稉浼欑礆**閻ㄥ嫬绔风仦鈧惌鈺佽埌閵嗗倻鏁ら幋閿嬪Г"閺堝鍎楅弲顖欑稻妤傛ê瀹抽悧閫涚秵"閺冭绱?
          //     璺?`bgH` 瀵板牆鐨懓?`clipH` 娑旂喎鐨?閳?濮濓絽鐖堕敍鍫濆З閻㈣鑵戝▓纰夌礉鐎圭懓娅掔亸鍗炲涧閺堝鍋呮稊鍫濄亣閿?
          //     璺?`bgH` 瀵板牆鐨懓?`clipH` 娑撳秴鐨?閳?**閻ф儳鍨庡В鏃堟懠閺傤厺绨?*閿涘牐鍎楅弲顖涚梾闁剧儤寮х€圭懓娅掗敍?
          //     璺?`bgH` 濮濓絽鐖?閳?闂傤噣顣介崷?*娑撳秹鈧繑妲戞惔?*閿涘牏婀?`bg`閿涘鍨?*缂佹ê鍩?*閿涘牅绗夐弰顖氱鐏炩偓閿?
          .onAreaChange((_oldArea: Area, area: Area): void => {
            const w: number = areaLengthToVp(area.width);
            const h: number = areaLengthToVp(area.height);
            this.diagBgBox = `${w.toFixed(0)}x${h.toFixed(0)}`;
          })

          // 閳?閸愬懎顔愮仦鍌︾窗鐏忓搫顕幁鎺嶈礋 100%閿? 鐟佷礁澹€缁愭褰?= 閸欘垵顫嬮惌鈺佽埌 / 缂傗晜鏂侀敍澶涚礉閹碘偓娴犮儲妗堟潻婊冿綖濠娾€冲讲鐟欏棛鐓╄ぐ?
          Column() {        Column() {
              this.buildControlStack()
            }
            // 閳?閼颁浇鐭惧鍕剁礄閸戠姳缍嶅▽锟犲櫤閸掔増妞傞惃鍕幑鎼存洩绱氶敍姘敶鐎圭懓鐪扮拹瀵告絻鎼存洝绔熼敍宀勭彯鎼达缚绮?鐠愭潙绨虫稉鈧弶?闂€鍨煂 100%
            .height(this.sheetHeightPercent())
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.End)
          .clip(true)
          // 閳跨媴绗?鏉╂瑩鍣?*娑撳秴鍟€**缂佹瑦鏆ｇ仦鍌氬闁繑妲戞惔?鎼存洝澹婇敍姘垛偓蹇旀鎼达箑鍑￠幐澶婂冀缂傛牞鐦ч幏鍡樺灇娑撳鐪扮粣妤€褰?
          //   閿涘牐鍎楅弲?`pullBgIn` / 妞よ埖鐖?`pullChromeOpacity` / 鎼存洘鐖?`pullBottomIn`閿涘绱?
          //   鎼存洝澹婇悽鍗炶埌閸欐ê顔愰崳銊╁櫡闁絼閲滈崣鏍鐏炲倽绀嬬拹锝忕礉閸氾箑鍨棃娆愵剾閹椒绱扮亸鎴滅鐏炲倿顤侀懝灞傗偓?
          // 閳跨媴绗?娑撳﹥濯洪幍鎾崇磻**娑撳秴婀潻娆撳櫡閸?*閿涙艾鐣犺箛鍛淬€忛幐鍌氭躬婢瑰啿鐪伴敍鍧oducts閿涘鈧?
          //    閹绢厽鏂佹い闈涙躬 `isShowPlay=false` 閺冩儼绻曞▽鈩冨瘯鏉炴枻绱濇い鐢告桨閺€鏈电瑝閸掔増澧滈幐鍥︾皑娴犺翰鈧?
          //    閼卞矁鐭楅崚鎺戝瀻閿?*娑撳﹥濯?婢瑰啿鐪?鏉╄渹缍橀弶鈽呯礄閳?morphP 0閳?閿涘绱濇稉瀣閺€鎯版崳=閺堫剟銆夐敍鍫氬晪 morphP 1閳?閿?*閵?
          //
          // 閳跨媴绗?鏉╂瑩鍣?*娴犫偓娑斿牓鍏樻稉宥勭瑐閹?*閿涘牊妫︽稉宥勭瑐閹躲儱鏄傜€甸潻绱濇稊鐔剁瑝閸愬秳绗傞幎銉ュ斧閻愮櫢绱氶妴?
          //    閺堫剙鐪扮亸杈ㄦЦ閹靛婧€娓氀呮畱 `MORPH_HOST_ID`閿涘矁鈧苯鐣犻惃鍕彯鎼达附妲?*鐟佷礁澹€缁愭褰涙妯哄**
          //    閿涘牆鑸伴崣妯绘埂闂?~60vp 閳?濠娾€崇潌閿涘绱漙globalPosition` 娑旂喕绐￠惈鈧?translate 鐠?閳ユ柡鈧?
          //    閹峰灝鐣犺ぐ?闁剧儤寮ч惄顔界垼"鐏忚鲸妲哥粭顑跨安濞喡ゅ殰閸ｎ剨绱欐稉鈧崸妤呯拨鎼?+ 閹绢厽鏂佹い闈涚潔娑撳秴绱戦敍澶涚礉
          //    閹峰灝鐣犺ぐ?閸ф劖鐖ｉ崢鐔哄仯"鐏忚鲸妲哥拋鈺佸斧閻愮鎷烽惈鈧懛顏勭箒閻ㄥ嫪鑵戦梻瀛樷偓浣界獓閿涘牐鎹ｉ悙?閸忓娈曠仦鍌涙殻娴ｆ捇鏁婃担宥忕礆閵?
          //    **閸ф劖鐖ｉ崣锝呯窞閸忋劑鎽肩紒鐔剁缁愭褰涢崸鎰垼**閿涘牓鍣哄ù瀣拱閺夈儱姘ㄩ弰顖滅崶閸欙絽娼楅弽鍥风礉閸忓娈曠仦鍌滄畱
          //    `.position()` 娑旂喕鎯ら崷銊﹀姬鐏?Stack 娑撳绱濋崥灞藉經瀵板嫸绱氶敍灞惧娴犮儲鐗撮張顑跨瑝闂団偓鐟曚礁甯悙瑙勫床缁犳ぜ鈧?
          //    瑜般垹褰夌亸鍝勵嚟閻ㄥ嫬鏁稉鈧弶鍐ㄢ枆閺勵垰锛撶仦鍌涘瘻 `windowSize` 娑撳﹥濮ら惃?`reportWindow`閵?
          .onAppear(() => {
            this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            this.isAlive = true;
            this.getImageColor();
            this.applyPlaybackWindowChromeImmediately();
            // 妞ょ敻娼版＃鏍偧閸戣櫣骞囬弮璺烘倱濮濄儰绔村▎鈥崇磻閸忓磭濮搁幀渚婄礄鐠佸墽鐤嗘い闈涘讲閼宠棄鍨伴弨纭呯箖閿?
            this.applyFlowLightColors();
            // 閳藉應妲勯埥?2026-10-16閿?*閸掔姵甯€ `playbackSwiperIndex = 0`閿涙稓鍌ㄥ鏇炵秺"閹垫挸绱戦幇蹇撴禈"缁?*閿?
            //
            // ## 閸樼喐娼甸柇锝呭綖娑撹桨绮堟稊鍫熸箒鐎?
            //   鐎瑰啯妲?*閼哄倻鍋ｇ痪褍娲栫拫?*閿涘牊婀?`Column` 閻?`.onAppear`閿涘苯鍨庨弨顖炲櫢瀵よ桨绡冩导姘崇獓閿涘鍣烽惃鍕晸閸忋儻绱?
            //   閼?`playbackSwiperIndex` 閺?Swiper 瑜版挸澧犳い?閻ㄥ嫬鏁稉鈧悩鑸碘偓渚婄礉娑撴梻骞囬崷?
            //   **缂佹垵鍩屾禍?`Swiper.index()`**閿涘牐顫?`Swiper()` 娑撳﹥鏌熼柇锝嗩唽闂€鎸庢暈闁插绱氶妴?
            //   娑撱倛鈧懏鏂佹稉鈧挧宄版皑閺勵垵绻栨稉顏勮埌閻樿绱?
            // ```
            //   閻劍鍩涙禒搴＄俺闁劎濮搁幀浣圭埉"濮濓絽婀幘顓熸杹"鏉╂稒鎸遍弨鎯ф珤 閳?閹垫挸绱戦幇蹇撴禈閹跺﹦鍌ㄥ鏇犵枂 0閿涘牐顔曠拋鈥愁洤濮濄倧绱濈憴?
            //     PlaybackIntentShell閿涘鍟?閻劍鍩涘鎴濆煂濮濆矁鐦濇い纰夌礄缁便垹绱?= 1閿涘畭lyricMorphT` = 1閿?
            //   閺屾劒閲滈懞鍌滃仯闁插秴缂?閳?閺?`onAppear` 閸欏牐绐囨稉鈧▎?閳?缁便垹绱╃悮顐㈠晸閸?0
            //   閳?`Swiper` 鐠哄啿娲栫亸渚€娼版い?+ `lyricMorphT` 娑撳孩鏌婃い鍏哥瑝娑撯偓閼?
            //   閳?鐟欏倹鍔呴敍?*閸︺劍鐡曠拠宥夈€夐敍灞界殱闂堛垹宓堟稉宥呭綁鐏?*閿涘牏鏁ら幋?2026-10-16 閻喐婧€閹搭亜娴樼€圭偞绁撮敍?
            // ```
            //   閳跨媴绗?閼板奔绗栨潻娆庨嚋"婢跺秳缍?鐎?*閸愬嘲鎯庨崝銊╁亝閺壜ょ熅閺堫剚娼电亸鍗烆樋娴?*閿涙碍澧﹀鈧幘顓熸杹閸ｃ劍妞?
            //      `PlaybackIntentShell` / `ProductViewModel` 闁絼绔撮弶鈥冲嚒缂佸繑濡哥槐銏犵穿缂?0 娴?
            //      閿涘牆鐣犻弰?閹垫挸绱戦幇蹇撴禈"閻ㄥ嫪绔撮柈銊ュ瀻閿涘鈧倽濡悙鍦獓閸ョ偠鐨熼崘宥嗗娑撯偓濞嗏€冲涧娴兼碍濡搁悽銊﹀煕**瑜版挸澧犳い?*閹垫挻甯€閵?
            //
            // ## 閻滄澘婀惃鍕瀻瀹搞儻绱欓崡鏇氱閻喐绨敍灞藉焼閸愬秵璐╅崥鍫礆
            //   璺?**閹垫挸绱戦幘顓熸杹閸?* 閳?閻㈣鲸澧﹀鈧幇蹇撴禈缂?`playbackSwiperIndex = 0`閿涘牊婀版い鍏哥瑝閸欏倷绗岄敍澶涚幢
            //   璺?**閻劍鍩涘鎴濆З**   閳?`.onChange` 閸愭瑧鍌ㄥ?+ `.onAnimationStart` 妞瑰崬濮?`lyricMorphT`閿?
            //   璺?**閼哄倻鍋ｉ崙铏瑰箛**   閳?閸欘亜鎮撳?閺堫剟銆夐懛顏勭箒閻ㄥ嫯顫嬬憴澶屽Ц閹?閿?*娑撳秶顫悽銊﹀煕閸︺劌鎽㈡稉鈧い?*閵?
            //
            // ## 娑?鐏忎線娼扮紒顓㈩棧"闁絼绔寸€靛湱娈戦崗宕囬兇閿涘牐绻栭柌宀€娈戞径宥勭秴**韫囧懘銆忛悾?*閿?
            //   娑撳娼版稉銈呭綖閺?*閺堫剟銆夐懛顏勭箒閻ㄥ嫭娣抽悽鐔哄Ц閹?*閿涘奔绗夐弰?閻劍鍩涢崷銊ユ憿娑撯偓妞?閿?
            //   `lyricMorphT` / `lyricMorphVisible` 閹诲繗鍫惃鍕Ц"鐏忎線娼版鐐额攽閸斻劎鏁炬潻娑滎攽閸掓澘鎽?閿?
            //   閼哄倻鍋ｉ柌宥呯紦閸氬骸绻€妞よ娲栭崚浼存饯濮濄垺鈧緤绱欓崥锕€鍨导姘粻閸︺劋绔存稉顏囁夐梻缈犺厬闂傚瓨鈧緤绱氶妴?
            //   閳跨媴绗?娴?*缁便垹绱╂稉?1 閺冩湹绗夐懗鐣屾锤閻╊喗濡?`lyricMorphT` 瑜?0** 閳ユ柡鈧?闁絼绱扮拋?閸︺劍鐡曠拠宥夈€?鏉╂瑤绔寸敮?
            //      閻ㄥ嫬鐨濋棃銏犲綁閸ョ偛銇囩亸渚€娼伴敍鍫燁劀閺勵垱婀板▎陇顩︽穱顔炬畱閻滄媽钖勯敍澶堚偓鍌楀櫩 閹稿鍌ㄥ鏇炲枀鐎规岸娼ゅ銏♀偓渚婄窗
            // ```ts
            //   this.lyricMorphT = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
            // ```
            //   閸?闂堟瑦顒涢幀?= 瑜版挸澧犳い闈涱嚠鎼存梻娈戠粩顖滃仯"閿涘矁绻栨稊鐔告Ц `lyricMorphT` 娑撱倓閲滅粙鍐茬暰閸婅偐娈戠€规矮绠熼妴?
            //   閳?2026-10-16閿涘牏顑囨禍宀€澧楅敍澶涚窗鏉╂瑩鍣烽崢鐔告降閺勵垯绔撮崣銉ュ敶閼辨柧绗侀崗鍐︹偓鍌滃箛閸︺劍鏁归弫娑滅箻
            //     `syncLyricMorphToPage()` 閳ユ柡鈧?閸ョ姳璐?*閸氬奔绔存稉顏勵嚠姒绘劕濮╂担婊冩躬閹稿倽娴囬弮鏈电瘍鐟曚礁浠涙稉鈧▎?*
            //     閿涘潉aboutToAppear`閿涘绱濇稉銈咁槱韫囧懘銆忛崥灞肩閸欙絽绶為敍鍫ｎ潌闁絼閲滈弬瑙勭《閻ㄥ嫭鏁為柌濠忕礆閵?
            this.syncLyricMorphToPage('appear');
            // 閳跨媴绗?鏉╂瑤绔撮崣?*韫囧懘銆忛悾娆忔躬婢舵牠娼?*閿涙瓪syncLyricMorphToPage()` 閸?瀹歌尙绮＄€靛綊缍?閺冩湹绱?*閺冣晠鈧偓**閿?
            //   閼?閼哄倻鍋ｉ柌宥呯紦閸氬簼绗夌拋绋夸粻閸︺劏藟闂傜繝鑵戦梻瀛樷偓?鏉╂瑦娼憰浣圭湴濮ｅ繑顐?`onAppear` 闁€燁洣濠娐ゅ喕閵?
            this.lyricMorphVisible = false;
            // 閹貉冨煑閸栫尨绱版潻娑欐降閸忓牆鏁滈崙鐚寸礉3 缁夋帗鐥呴崝銊ㄥ殰閸斻劍鏁圭挧?
            this.chromeCollapsed = false;
            this.touchChrome();
            // 閳?2026-10-15 鐠囧﹥鏌囬敍姘虫儰娴ｅ秳绠ｉ崥搴″晙闁插繋绔村▎鈥虫磽娑擃亜娼￠惃鍕崶閸欙絿鐓╄ぐ顫礄鐟?`logLayoutBoxes()`閿涘鈧?
            //   480ms 閸?鐏炴洖绱戠悰銉╂？閿涘牊娓堕梹?560ms 閻ㄥ嫭璇炵仦鍌炲亝閺?+ 20ms 閺€璺虹啲閿涘鐔€閺堫剝铔嬬€?閻ㄥ嫰鍣虹痪褝绱?
            //   閹烘帗鐓￠崗鎶芥暛鐎?`RzdBoxes`閵嗗倵娈搁敂?閸欘亣顕伴敍灞肩瑝瑜板崬鎼锋禒璁崇秿閻樿埖鈧降鈧?
            setTimeout((): void => {
              if (this.isAlive) {
                this.logLayoutBoxes();
                // 閳?閻╊喗鐖?閳?閻?S1 濮濄儴鍤滅拠渚婄礄閹烘帗鐓￠崗鎶芥暛鐎?`RzdSizeTier`閿涘绱?
                //   閺嶇顕?`sizeScaleOf` / `topPageSideOf` 閸?*閹靛婧€濡?*娑撳﹥妲搁崥锔戒紗婵傜晫鐡戞禍搴㈠灉娴?
                //   瀹歌尙绮￠崷銊ф暏閻ㄥ嫬娴愮€规艾鈧》绱檂sizeK = 1` / `side = 16`閿涘鈧柡鈧?閺堢喐婀?`fixedOk=true`閵?
                this.expandState.logSizeTier(this.breakpointEnv.widthBreakpoint);
                // 閳?閻╊喗鐖?閳?閻?S2 濮濄儴鍤滅拠渚婄礄閹烘帗鐓￠崗鎶芥暛鐎?`RzdWideCols`閿涘绱?
                //   閹跺﹤顔旂仦?/ 闂堛垺婢樻稉銈嗐€傞惃?*閸楃姵鐦稉搴濊⒈閺嶅繐顔旀惔?*閹垫挸鍤弶銉礄閹靛婧€娑撳﹤鐣犳禒顑跨瑝閸欏倷绗岀敮鍐ㄧ湰閿?
                //   閸欘亝妲搁幎濠冩殶缁犳鍤弶銉ヮ槵閺屻儻绱氶妴鍌炴？鐠烘繐绱檊utter/space閿?*娑撳秴婀崗鏈佃厬** 閳ユ柡鈧?鐟?S2 閻ㄥ嫭鏁為柌濞库偓?
                this.expandState.logWideColumns(this.breakpointEnv.widthBreakpoint, this.usePanelLayout(),
                  this.getUIContext());
              }
            }, 480);
            // 閳跨媴绗?娑撳﹥濯洪幍鎾崇磻閺冩儼绻樻惔锕€鍑＄紒蹇撴躬閹锋牕濮╂稉顓¤泲娴滃棔绔撮柈銊ュ瀻閿涘矁绻栭柌灞肩瑝閼充粙鍣哥純顕嗙幢
            //    閻愮懓鍤?鐠ч攱鎸遍幇蹇撴禈閹垫挸绱戦弮鎯扮箻鎼达附妲?0閿涘牐顫?aboutToAppear閿涘鈧?
            this.collapseProgress = 0;
            // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*瑜般垹褰夋导姘崇樈瑜版帒锛撶仦鍌涙閿涘本婀版い鍏哥瑝鐠ц渹鎹㈡担鏇炵潔瀵偓鐞涖儵妫?*閵?
            //   閺冪姷鏅柇锝堢珶閹绢厽鏂佹い浣冨殰瀹稿彉绗夐幘顓炵潔瀵偓 閳ユ柡鈧?鐎瑰啫褰ч弰顖濐潶婢瑰啿鐪伴惃?`ExpandAnimation`
            //   閹?`scale/translate/clip` 閹恒劎娼冮崣姗堢礉鐞涖儵妫块崷銊ワ紦鐏炲偊绱檂settlePullOpen`閿涘鈧?
            //   閺堫剟銆夊銈呭煝閸欘亜浠涙稉鈧禒鏈电皑閿?*閹跺﹦绮崚鍫曟，閹垫挸绱?*閿涘牆鍤戞担鏇炲嚒缂佸繑妲告竟鍐茬湴閸樺銈介惃鍕崳閻愮櫢绱氶妴?
            //   閳跨媴绗?鏉╂瑩鍣?*娑撳秷顔?*閸愬秵妫ら弶鈥叉鐠?`playExpandIntro()`閿涙艾鐣犳导姘宠泲 `tryStartMorphIntro()`閿?
            //      閼板矂鍋呴弶陇鐭剧憰?闁插繐鍩岀紒鍫㈠仯闁挎氨鍋?閹靛秷鍋楃挧鐤夐梻娣偓渚€鍣烘稉宥呭煂鐏忛亶鈧偓閸栨牗鍨?
            //      `playLegacyExpandIntro()`閿涘牐鍒涙惔鏇氱閺夛繝鏆辨稉濠冩降 = 濞查箖鐓堕弮褍濮╅悽浼欑礆
            //      閳?閸氬奔绔存稉顏勫弳閸欙絾婀侀弮鑸垫Ц閺傛澘濮╅悽姹団偓浣规箒閺冭埖妲搁弮褍濮╅悽浼欑礉濮濓絾妲搁妴灞炬煀閺冄勫ⅵ閺嬭翰鈧秶娈戣ぐ銏㈠Ц閵?
            //
            // 閳藉應妲勯埥?2026-10-16閿?*閻愮懓鍤幍鎾崇磻濞屸剝婀佺亸渚€娼?閼冲本娅欓崝銊ф暰閻ㄥ嫮婀￠弽鐟版礈**閿涘绱?
            //   閸掋倖宓侀崢鐔告降閸欘亝婀?`morphContainerActive()`閿?*閻愮懓鍤捄顖氱窞閸︺劍瀵曟潪浠嬪亝娑撯偓閸掕鐣犳潻妯绘Ц閸?*閿?
            //   ```
            //     閻愮懓鍤敍姘紦鐏?beginOpenMorphOnClick 閳?pullOpenBegin
            //            閳?prepareMorphEntry 閸欐垹骞?閹绢厽鏂佹い浣冪箷濞屸剝瀵曟潪濮愨偓浣哥殱闂堛垽鍣烘稉宥呭煂"
            //            閳?鐠?!ready 閸掑棙鏁敍姝畂rphStage = ENTERING閵嗕沟orphDrive = FINGER
            //            閳?娴ｅ棴绱欓崥灞肩瑐閿?*morphUsable = false閵嗕沟orphP = 0** 閳?morphContainerActive() 娑撳搫浜?
            //            閳?pushPlayerRoute 閳?閺堫剟銆?onAppear 閳?閹哄绻?else 閸掑棙鏁?閳?**閹绢厽娣抽棅铏＋閸斻劎鏁?*閿?
            //     娑撳﹥濯洪敍姘紦鐏?onPullOpenStart 閳?pullOpenBegin閿?*閸︺劑銆夐棃銏″瘯鏉炴垝绠ｉ崜?*鐏?
            //            morphBeginEntering()閿涘牓鍋呴弮鎯扮碃娴ｇ姵娼柌蹇撶繁閸掑府绱氶埇?閹稿倽娴囬弮?stage = ENTERING 閳?鐠ф澘顕崚鍡樻暜
            //   ```
            //   閳?鐞涖儰绔撮弶鈥冲灲閹诡噯绱?*婢瑰啿鐪板鑼病娑撻缚绻栨稉鈧潪顔挎崳鏉╁洤鑸伴崣妯圭窗鐠?*閿涘潉morphSessionStarted`
            //     閻?`prepareMorphEntry` 缁楊兛绔村銉х枂娴ｅ稄绱濇稉澶嬫蒋閸忋儱褰涢柈鎴掔窗缂佸繗绻冪€瑰喛绱氶妴?
            //     鐎瑰啯鍨氱粩?閳?鏉╂瑤绔存い鐢垫畱缁楊兛绔寸敮褍姘ㄧ拠?娑撳秶鏁?閿涘牏鐡戞竟鍐茬湴閹跺﹤鍤戞担鏇炲竾閸掓媽鎹ｉ悙鐧哥礆閿?
            //     閼板奔绗夐弰顖濆殰瀹稿崬绱戞慨瀣尡闁絽顨?`collapseProgress` 閺冄冨З閻㈡眹鈧?
            if (this.expandState.morphContainerActive() || this.expandState.morphSessionStarted) {
              this.diagAppearBranch = 'morph';
              this.introPaintReady = true;
              this.expandIntroRunning = false;
              // 閳藉應妲?2026-10-16閿涘牏鍋ｉ崙鏄忕熅瀵板嫮娈?*閸戠姳缍嶇悰銉╁櫤**閿涘绱?
              //   閻愮懓鍤幍鎾崇磻閺?`pullOpenBegin` 閺勵垰婀?閹绢厽鏂佹い浣冪箷濞屸剝瀵曟潪?闁絼绔撮崚鏄忕獓閻?閳?鐎瑰啫绶㈤崣顖濆厴
              //   閹峰じ绗夐崚鎵矒閻愬綊鏁嬮悙鐧哥礄閹绢厽鏂佹い闈涚殱闂堛垼濡悙纭呯箷娑撳秴鐡ㄩ崷顭掔礆閳?`morphUsable = false`閵?
              //   婢瑰啿鐪伴柇锝堢珶閺?12鑴?2ms 閻ㄥ嫯藟闁插繒鐛ラ崣锝忕礄`schedulePullAnchorRemeasure`閿涘绱?
              //   娴ｅ棝鍋呴弰?*婢瑰啿鐪?*閻ㄥ嫯濡總蹇ョ幢閺堫剟銆夐幐鍌濇祰闁絼绔撮崚缁樻Ц"鐏忎線娼伴懞鍌滃仯**閸掓艾鍨扮€涙ê婀?*"閻?*閺堚偓閺?*閺冭埖婧€閿?
              //   閸︺劏绻栭柌宀兯夐柌蹇庣濞嗏槄绱濆В鏃傜搼婢瑰啿鐪版稉瀣╃閹峰稄绱欓張鈧径?32ms 娑斿鎮楅敍澶嬫纯閸戝棎鈧?
              //   閳跨媴绗?娑撳顒炵挧甯礉缂傝桨绔村銉ユ皑娴?鐞涖儵鍣洪幋鎰娴ｅ棛娴夋担宥堢箷閸嬫粌婀弮褎鈧?閿?
              //     閳?`prepareMorphEntry` 閳ユ柡鈧?闁插繐鍤戞担?+ `morphInitParams` + 閸樺鍩岀挧椋庡仯閿?
              //     閳?`morphBeginEntering` 瀹歌尙绮￠悽鍗炵暊閸愬懘鍎寸拫鍐箖閿涘澁eady 閺冭绱氶敍?
              //     閳?鐞涖儵鍣洪幋鎰閸?*韫囧懘銆?*閹跺﹥璇炵仦鍌炲亝娑撯偓濡帞娈戠悰銉╂？娑旂喕鎹ｇ挧閿嬫降閿涘牆鎯侀崚娆忕殱闂堫澀绮涢悞鏈电瑝妞嬬儑绱氶妴?
              setTimeout((): void => {
                if (!this.isAlive || this.isClosing) {
                  return;
                }
                this.diagRemeasureTries = this.diagRemeasureTries + 1;
                // 閳藉應妲勯埥?2026-10-16閿?*閸氬奔绔磋ぐ銏㈠Ц閻ㄥ嫮顑?3 婢?*閿涙艾寮甸弰?缁犳鍤弶銉ょ啊"瑜版挻鍨?闁插繐鍩屾禍?閿涘绱?
                //   鏉╂瑥褰為崢鐔告降閺?`if (morphUsable) { return; }` 閳ユ柡鈧?閼?`morphUsable` 閺?
                //   `morphInitParams()` 閻ㄥ嫮绮ㄧ拋鐚寸窗**閸欘亣顩?barW/boxW 闁插繐鍩屾禍鍡楃暊鐏忓彉璐熼惇?*閿?
                //   **閺嶈婀版稉宥囶吀缂佸牏鍋ｉ柨姘卞仯閺堝鐥呴張?*閵嗗倷绨弰顖滃仯閸戠粯澧﹀鈧潻娆愭蒋鐠侯垯绗傞敍?
                // ```
                //   pullOpenBegin 閳?morphInitParams() 閹存劕濮涢敍鍫ｇ碃娴ｇ姵娼張澶婂殤娴ｆ洩绱氶埇?morphUsable = true
                //   閹稿倽娴?閳?鏉╂瑩鍣风拠璇插煂 morphUsable === true 閳?**閻╁瓨甯?return**
                //        閳?閺堫剟銆夋潻娆愵偧"閺堚偓閺冣晝娈戠悰銉╁櫤閺冭埖婧€"鐞氼偆娅ч惂鎴掓丢閹?
                // ```
                //   閼板瞼绮撻悙褰掓晪閻愮懓婀?*閺堫剟銆夐幐鍌濇祰娑斿澧?*閺勵垳绮风€靛綊鍣烘稉宥呭煂閻ㄥ嫸绱欓懞鍌滃仯鏉╂ü绗夌€涙ê婀敍?
                //   閳?鐏忓崬褰ч崜鈺侊紦鐏炲倿鍋呴弶?12鑴?2ms 閸忔粌绨抽敍灞艰⒈閺夆€宠嫙鐞涘瞼娈戠悰銉╁櫤**娑撯偓閺夛繝鍏樺▽陇绐?*閵?
                //   閳?閸掋倖宓侀幑銏″灇 {@link PlayerExpandState.morphGeomReadyNow}閿? 閺冪姷鏅?`pullGeomReady`閿?
                //     閸欘亝婀侀惇鐔烘畱闁插繐鍩岀紒鍫㈠仯闁絼绔撮幏宥嗗娑撹櫣婀￠敍澶堚偓?*閺堫剟銆夐幐鍌濇祰鏉╂瑤绔撮崚缁橆劀閺?缂佸牏鍋ｉ懞鍌滃仯閸掓艾鐡ㄩ崷?閻ㄥ嫭娓堕弮鈺傛閺?*閵?
                //   閳跨媴绗?娑?`morphUsable` 閻ㄥ嫬鍨庡銉潌闁絼閲滅€涙顔岄惃鍕暈闁插绱濋崚顐㈠晙濞ｉ鏁ら妴?
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
              // 閸忔粌绨抽敍姘埌閸欐ɑ鐥呯挧閿嬫降閿涘牆鍤戞担鏇熺梾闁插繘缍堥惃鍕偓鈧崠鏍熅瀵板嫸绱氭禒宥嗘＋鐠ф媽鈧線鍋呮總妤嬬礉閸掝偉顔€妞ょ敻娼伴幍鎾茬瑝瀵偓閵?
              //
              // 閳藉應妲勯埥?2026-10-16閿?*娣囶喚鏁ら幋宄扮杽濞村鈧奔绗呴幏澶婂彠闂傤厼鎮楅敍灞藉З閻㈣崵绮ㄩ弶鐔剁啊缁愪胶鍔ч崣鍫熸杹娑撯偓闁秴鐫嶅鈧妴?*閿?
              //
              // ## 鏉╂瑦娼崚鍡樻暜娑撹桨绮堟稊鍫滅窗閸?閸忔娊妫?閺冩儼顫︾挧鏉垮煂
              // 閺?`.onAppear()` 閺?*閼哄倻鍋ｇ痪?*閸ョ偠鐨?閳ユ柡鈧?鐎瑰啩绱伴崷?*閸掑棙鏁柌宥呯紦**閺冩湹绡冪憴锕€褰傞敍?
              // 娑撳秴褰ч弰?妞ょ敻娼扮悮顐ｅⅵ瀵偓"闁絼绔村▎掳鈧倽鈧苯鍙ч梻顓㈡懠鐠侯垶鍣?`morphReset()` 娴兼碍濡?
              // `morphSessionStarted` 濞撳懎娲?false閿涘潉morphStage` 閸欐ɑ鍨?NONE閿涘鍣?
              // 娑撳﹪娼伴柇锝勯嚋 `if` 閻ㄥ嫪琚辨稉顏勫灲閹?*閸氬本妞傞崣妯轰海** 閳?閽€钘夊煂鏉╂瑩鍣?閳?**闁插秵鏂佹稉鈧柆宥呯潔瀵偓閸斻劎鏁?*閵?
              //
              // ## 閸掋倖宓侀敍鍫滅瑏闁搫绱?*缁楊兛绗侀弶鈩冩Ц鐠恒劌鐤勬笟瀣畱**閿?
              //   閳?`isClosing` 閻㈠崬鍙ч梻顓㈡懠鐠侯垳鐤嗛惇鐕傜礄`closeFullScreenPlayback()` 妫ｆ牠鍎撮敍澶涚幢
              //   閳?`morphStage === LANDING` 閳ユ柡鈧?`morphLand()` **閸欘亜婀崗鎶芥４鐠侯垰绶?*鐞氼偉鐨?
              //      閿涘牆鍙忓銉р柤濞撳懐鍋ｉ敍姝歅laybackPage` 娑撱倕顦?+ `Index:1088`閿涘鍣?閺?瀹歌弓姘︽潻妯跨碃娴ｇ姵娼?閻ㄥ嫮娴夋担宥忕幢
              //   閳?閳?`lastCloseAtMs` 閺冨爼妫跨粣?閳ユ柡鈧?**鐠恒劌鐤勬笟?*閸忓彉闊╅敍鍫ｎ潌闁絼閲滈棃娆愨偓浣哥摟濞堢數娈戝▔銊╁櫞閿涘鈧?
              //      閳跨媴绗?閳剁姭鎲?闁姤妲?*鐎圭偘绶ョ仦鈧柈?*閻ㄥ嫸绱伴弬鏉跨杽娓氬娈?`aboutToAppear` 娴兼碍濡?`isClosing`
              //         **閺冪姵娼禒鑸电閸?false**閿涘畭morphReset()` 閸欏牊濡?`morphStage` 瑜?NONE
              //         閳?閸忔娊妫存担娆愬皾閽€钘夋躬閺傛澘鐤勬笟瀣╃瑐閺?*娑撱倖娼崗銊х€?* 閳?韫囧懘銆忛棃?閳额潿鈧?
              //      閳跨媴绗?閳?閻ㄥ嫬鍟撻悙?*閸欘亝婀?* `closeFullScreenPlayback()` 妫ｆ牠鍎存稉鈧径鍕剁礄娑撱倕顦╅幋鎰嚠閿?
              //         娑撳﹣绔存潪顔兼皑閺勵垱绱℃禍鍡涘亝娑擃亜鍟撻悙骞库偓渚€妫幁鎺戜海 閳?閻ц姤鏁兼稉鈧潪顕嗙礆閵?
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
                // 閳?闂?娑撳秵鎸遍崝銊ф暰"娑斿顦绘潻妯虹箑妞?*閹跺﹤鍤戞担鏇℃儰鐎?*閿?
                //   閸氾箑鍨€圭懓娅掗崣顖濆厴閸嬫粌婀悮顐¤厬閺傤厾娈戞稉顓㈡？ scale閿涘牏鏁ら幋閿嬪Г閻?閼冲本娅欓崣顏勫⒖娑撯偓閺?閸氬本绨敍澶堚偓?
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
            // 閳藉應妲?2026-10-16閿?*閸忓牆褰?閸楁瓕娴囬柇锝勭閸?閻?isAlive 韫囶偆鍙?*閵?
            //   娑撳娼伴柇锝堫攽娴兼碍濡?`isAlive` 閸氬本顒炵純?false閿涘矁鈧本婀伴崶鐐剁殶闁插瞼娈戦崚銈嗗祦閺?*瀵よ埖妞傛稉鈧幏?*鐠烘垹娈?閳ユ柡鈧?
            //   閻╁瓨甯寸拠璇茬摟濞堢數娈戠拠婵囨鏉╂粏顕伴崚?false 閳?閸掋倖宓侀柌?`!isAlive` 闁絾娼幁鎺旀埂
            //   閳?瀵よ埖妞傞柇锝変壕闂傘劎鐡戞禍搴㈢梾閸旂媴绱欐潻娆愵劀閺勵垯绗傛稉鈧悧?`morphUsable` 闁綁浜鹃梻銊ф畱閸氬瞼琚柨娆掝嚖閿?
            //     **閸掋倖宓佺拠璇插煂閻ㄥ嫭妲?鐞氼偉鍤滃杈ㄦ暭鏉╁洣绠ｉ崥?閻ㄥ嫬鈧?*閿涘鈧?
            const wasAlive: boolean = this.isAlive;
            this.isAlive = false;
            PlaybackPage.ev('DIS', `wasAlive=${wasAlive ? 1 : 0} show=${this.state.isShowPlay ? 1 : 0}`);
            // 閳藉應妲勯埥?2026-10-16閿?*閸掔姵甯€鏉╂瑩鍣烽柇锝呭綖閸氬本顒為惃?`state.isShowPlay = false`**閿涘绱?
            //   閸樼喐娼垫潻娆撳櫡閸愭瑧娼?`this.state.isShowPlay = false;`閵嗗倸鐣犻弰顖欑娑?*閼哄倻鍋ｇ痪?*閸ョ偠鐨熼柌宀€娈戦崘娆忓弳閿?
            //   閼?`isShowPlay` 閺?*婢瑰啿鐪扮捄顖滄暠閻ㄥ嫰鈹嶉崝銊︾爱**閿涘潉Index.@Monitor('appState.isShowPlay')`
            //   閳?`popPlayerRoute()`閿涘鈧倷琚遍懓鍛儗閸︺劋绔寸挧椋庢畱閸氬孩鐏夐弰顖濈箹娑擃亜鑸伴悩璁圭窗
            // ```
            //   閻愮懓鍤幍鎾崇磻閿涙艾锛撶仦鍌涘Ω isShowPlay 缂?true 閳?閹恒劌鍙嗛幘顓熸杹妞や絻鐭鹃悽?
            //   閸氬奔绔寸敮?娑撳绔寸敮褝绱?*閺冄勬尡閺€楣冦€夌€圭偘绶?*閿涘牊鍨ㄩ崚鍡樻暜闁插秴缂撻惃鍕亝娑擃亣濡悙鐧哥礆鐟欙箑褰?onDisAppear
            //   閳?鐎瑰啯濡?isShowPlay 閸愭瑥娲?false
            //   閳?婢瑰啿鐪扮粩瀣煝 popPlayerRoute() 閳?**閸掓碍澧﹀鈧惃鍕尡閺€楣冦€夌悮顐㈣剨閹?/ 閸斻劎鏁剧悮顐ｅ笌閺?*
            // ```
            //   閳跨媴绗?閼板奔绗栨潻娆愭Ц**楠炲倻鐡戦幀褍寮芥禍鍡欐畱**娑撯偓婢跺嫸绱板▔銊╁櫞 `:2709` 閼奉亜绻侀崘娆戞絻
            //     閵嗗畭isShowPlay` 閼汇儱鍑￠弰?false閿涘畭@Monitor` 娑撳秳绱伴柌宥咁槻閸斻劋缍旈妴宥佲偓鏂衡偓鏃堝亝閺?閸忔娊妫撮柧鎹愮熅"閻ㄥ嫯顕㈡稊澶堚偓?
            //     閸忔娊妫撮柧鎹愮熅娑?`isShowPlay = false` 閺?*娑撳顦╅弶鍐ㄢ枆鐠佸墽鐤嗛悙?*閿涘矂鍏橀崷?
            //     `closeFullScreenPlayback()` 闁插被鈧線鍏橀崷銊︻劀绾喚娈戦弮璺哄煝閿?
            //       璺?`:2712` 閺冪娀鏁嬮悙瑙勬－闁偓閺€?
            //       璺?`:2729` 濮濓絽鐖堕弨鎯版崳鐞涖儵妫块弨璺虹啲閺€?
            //       璺?`:2738` "濞屸剝婀侀崣顖炴浆閸戠姳缍嶉惄瀛樺复閸忔娊妫?闁偓閸栨牗鏁?
            //   閳?閺堫剙顦?*娑撳秹娓剁憰?*閸愬秴鍟撴稉鈧▎鈽呯幢閻ｆ瑧娼冮崣顏冪窗鐠?閹垫挸绱?鐞氼偉鍤滃杈嚖閸掋倖鍨?閸忔娊妫?閵?
            //   閳跨媴绗?閼汇儱鎽㈡径鈺冩埂闂団偓鐟曚礁鍘规惔鏇礄娓氬顩?Hard exit 鐠ч绗夐崚棰佺瑐闂堫澀绗佹径鍕剁礆閿?
            //      **韫囧懘銆?*閸忓牆鍨?閹绢厽鏂佹い浣冪熅閻㈣京鈥樼€圭偛鍑＄紒蹇庣瑝閸︺劍鐖ら柌?閸愬秴鍟?閳ユ柡鈧?閸氾箑鍨崣鍫熸Ц鏉╂瑤閲滆ぐ銏㈠Ц閵?
            //      閹烘帗鐓￠崗鎶芥暛鐎涙绱癭route: push player` 娑?`route: remove player at index=` 閻ㄥ嫭妞傛惔蹇嬧偓?
            //
            // 閳藉應妲勯埥?2026-10-16閿?*閹舵ü鑵戦崑姘《閿涙氨鏆€娑撳鐣ㄩ崗銊х秹閿涘奔绲剧紒娆忕暊娑撯偓娑?閸欘亜婀稉瀣酱閺冩儼袝閸?閻ㄥ嫭娼禒?*閿涘绱?
            //   閻╁瓨甯撮崚鐘冲竴鐎瑰啯婀佹搴ㄦ珦 閳ユ柡鈧?`Hard exit`閿涘牅绶ユ俊鍌滈兇缂佺喐濡稿Ο鈩冣偓浣规殻娑擃亝鏁归幒澶堚偓浣瑰灗閸掝偆娈戝Ο鈥虫健閻╁瓨甯?
            //   `popPath`閿涘妞?*濞屸剝婀佹禒璁崇秿娴?*娴兼碍濡告潻铚傜稑閺夆€叉唉鏉╂ê娲栭弶銉ｂ偓鍌涘娴犮儰绗夐崚鐙呯礉閺€瑙勫灇"**閸欘亜婀涵顔款吇
            //   閹绢厽鏂佹い闈涘嚒缂佸繋绗夐崷銊ㄧ熅閻㈣鲸鐖ら柌?*閺冭埖澧犻崘?閿涘苯鑻熸稉?*閹恒劏绻滄稉鈧幏?*閿涘牐顔€閸氬苯鎶氶崘鍛讲閼宠棄褰傞悽鐔烘畱
            //   push 閸忓牐鎯ら弽鍫礆閿?
            //     璺?閻愮懓鍤幍鎾崇磻閿涙岸鍋呮稉鈧幏宥嗙垽闁?*瀹稿弶婀?*閹绢厽鏂佹い?閳?娑撳秴鍟?閳?娑撳秳绱扮悮顐ヮ嚖閸掋倖鍨氶崗鎶芥４ 閴?
            //     璺?缁崵绮烘潻鏂挎礀 / 閸忔娊妫撮幐澶愭尦閿涙岸鍋呮稉澶婎槱閺夊啫鈻夐悙鐟板嚒缂佸繐鍟撴潻鍥风礄`isShowPlay` 瀹稿弶妲?false閿?
            //       闁插秴顦查崘娆愭Ц楠炲倻鐡戦惃鍕敄閹垮秳缍旈敍澶嗘箯
            //     璺?Hard exit 娑撴梹鐥呮禍鍝勫晸閿涙岸鍋呮稉鈧幏宥嗙垽闁插本鐥呴張澶嬫尡閺€楣冦€?閳?閸?false 閳?婢瑰啿鐪伴弨璺虹啲 閴?
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
                'RzdMorphOnDisappear fallback: player route gone but isShowPlay still true 閳?release it');
              this.state.isShowPlay = false;
            }, 0);
            // 娑撳绔村▎鈩冨ⅵ瀵偓闁插秵鏌婄挧?閸忓牓鍣洪崘宥囩級"閻ㄥ嫰銆庢惔蹇ョ窗閹跺﹦绮崚鍫曟，娑旂喎鍙ч崶鐐插箵
            this.introPaintReady = false;
            // 閳?妞ょ敻娼伴崡姝屾祰閺冭泛顦叉担?鐠虹喐澧滄导姘崇樈"閻ㄥ嫪琚辨稉顏呯垼鐠佽埇鈧?
            //   `pullDragging` / `morphDrive` 閸愬啿鐣鹃悙鐟板毊閹垫挸绱戦弮鎯邦洣娑撳秷顩﹂崑姘埌閸欐ê鍨垫慨瀣閿?
            //   閸欘亣顩﹂張澶夌鏉烆喗澧滈崝鎸庣梾鐠ф澘鍩岄弨璺虹啲閿涘牐顫︾化鑽ょ埠閹躲垼铔嬮妴浣疯厬闁柨宓忔潪濮愨偓浣衡€栭崗鎶芥４閳ワ讣绱氱€瑰啫姘ㄦ导姘暙閻ｆ瑱绱?
            //   濞堝鏆€閹?(true, FINGER) 閺冨墎鍋ｉ崙缁樺ⅵ瀵偓娴?*濮樻瓕绻欑捄瀹犵箖瑜般垹褰?*閿?
            //   闁偓閸栨牗鍨?`collapseProgress` 闁絽顨滈懓浣稿З閻紮绱欓悽銊﹀煕鐎圭偞绁撮敍?閻愮懓鍤?鏉╂柨娲栭悽銊ф畱鏉╂ɑ妲告稊瀣閻ㄥ嫬濮╅悽?閿涘鈧?
            this.expandState.pullDragging = false;
            this.expandState.morphDrive = MorphDrive.NONE;
            // 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤幍鎾崇磻濞屸剝婀侀崝銊ф暰"閻ㄥ嫭绨径鏉戞皑閸︺劏绻栭柌?*閿涘绱?
            //   娑撳娼伴柇锝呭綖閸樼喐娼甸弰?*閺冪姵娼禒?*閻?`morphReset()`閵嗗倽鈧?`morphReset()` 娴?
            //   **`morphGen++` 娑?`morphUsable = false` 娑?`morphSessionStarted = false`**閵?
            //   闂傤噣顣介崷銊ょ艾閿?*閻愮懓鍤幍鎾崇磻閺冭绱?閺傜増鎸遍弨楣冦€夐惃?`onAppear`"娑?閺冄囥€夐棃銏犵杽娓氬娈?`onDisappear`"
            //   閸戠姳绠崥灞芥姎閸欐垹鏁?* 閳?鏉╂瑤绔撮崣銉ょ窗閹?*閸掓艾鍨伴悽鍗烇紦鐏炲倸缂撶粩瀣偨閻ㄥ嫭鏌婃稉鈧潪顔艰埌閸欐ü绱扮拠?*娑撯偓鐠ч攱绔婚幒?
            //   閳?`morphUsable` 濮樻瓕绻欐稉鍝勪海 閳?鐎圭懓娅掗崑婊冩躬閹帞鐡?閳?**閼冲本娅欓弫鏉戠潌閵嗕焦鐥呴張澶婂З閻?*閵?
            //
            //   閳?閸旂姳绔撮柆鎾绘，閿?*閹恒劏绻滄稉鈧幏宥呭晙濞撳拑绱濋獮鏈电瑬"閼汇儵鍋呮稉鈧幏宥呭嚒缂佸繑婀佸ú鑽ゆ絻閻ㄥ嫪绱扮拠婵嗘皑鐠哄疇绻?**閵?
            //     閳藉應妲勯埥?2026-10-16閿?*閸掋倖宓佺拋銏☆劀閿涙瓪morphUsable` 閳?`morphSessionOughtToLive()`**閿涘绱?
            //       閸樼喐娼垫潻娆撳櫡閸?`morphUsable`閿涘牆鍤戞担鏇炲嚒鐏忚京鍗庨敍澶嗏偓鏂衡偓?*閸︺劎鍋ｉ崙鏄忕箹閺壜ょ熅娑撳﹤鐣犺箛鍛姧娑撳搫浜?*閿?
            //       鐠ч攱澧滄稉搴㈠瘯鏉炰粙鍋呮稉鈧崚鑽ょ矒閻愬綊鏁嬮悙纭呯箷濞岋繝鍣洪崚甯礉`morphUsable` 鐏忚鲸妲?false
            //       閳?鏉╂瑩浜鹃梻?*濮樻瓕绻欏鈧惈鈧?* 閳?娑撳氦顫﹂崚鐘冲竴閻ㄥ嫰鍋呴崣銉︽￥閺夆€叉 `morphReset()` 缁涘鐜妴?
            //       閳?閺堫剝鐤嗙紒褏鐢荤拋銏☆劀閿涙瓪morphSessionStarted`閿涘牅绗傛稉鈧悧鍫礆娑?`playerRouteStillPushed()`
            //         閿涘牅绗傛稉濠佺閻楀牞绱氶柈鎴掔瑝鐎电櫢绱濋悶鍡欐暠鐟?{@link morphSessionOughtToLive} 閻ㄥ嫬顕悡褑銆冮妴?
            //       閳跨媴绗?娑?`aboutToDisappear()` **韫囧懘銆忛崥灞肩娑擃亜鍨介幑?*閿涘牆鎮撴稉鈧ぐ銏㈠Ц閿涘奔绗夌拋绋挎倗閸愭瑤绔存總妤嬬礆閵?
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
            // 閳?2026-10-15閿涙氨缍夐弽鑹板剹閺咁垳娈戝┃鎰秴閸ュ彞绡冭ぐ鎺撴拱妞ゅ灚瀵旈張?閳?闁偓閸﹀搫绻€妞よ绔寸挧鐑藉櫞閺€?
            //   閿涘牆鎯侀崚娆愮槨濞喡ょ箻閸戠儤鎸遍弨楣冦€夐柈鎴掔窗濠曞繋绔村?64鑴?4 閻?PixelMap閿涘鈧?
            this.releasePixelMapQuiet(this.meshSrc);
            this.meshSrc = undefined;
            // 閳藉應妲勯埥?2026-10-17閿?*鐞涖儲绱?*閿涘绱癭鎼?40` 閺傛澘濮為惃?鐎瑰娼ょ粣妤€褰涘鍛八夌純鎴炵壐濠?娑旂喎缍婇張顒勩€夐幐浣规箒 閳ユ柡鈧?
            //   鐎瑰啫婀粣妤€褰涢張鐔峰敶閸欘亝妲?*閹稿倻娼?*閿涘潉pendingMeshPm`閿涘绱濋懟銉ㄧ箹濞堢敻鍣锋い鐢告桨鐏忛亶鈧偓閸﹁桨绨￠敍?
            //   娑撳﹪娼伴柇锝呭綖閸欘亪鍣撮弨?`meshSrc`閵?*閹稿倻娼冮惃鍕箹瀵姴姘ㄥ姝岀箼濠曞繑甯€**閿涘牆鎮撶猾璇插敶鐎涙ê宕奸悽鐔兼６妫版﹫绱?
            //   娑?鎼?37 闁絼閲?韫囶偆鍙?PixelMap 濠曞繑绔?閸氬奔绔存稉顏勮埌閻樿绱氶妴?
            this.releasePixelMapQuiet(this.pendingMeshPm);
            this.pendingMeshPm = undefined;
            this.imageLabel = $r('app.media.ic_avatar1');
            // 妞ょ敻娼伴柅鈧崷鍝勪粻閹哄娼冮懝鎻掓珤閸斻劎鏁鹃敍姘殻鐏炲繑绁﹂崗澶嬫Ц閹镐胶鐢婚惃?GPU 瀵偓闁库偓閿涘苯鎮楅崣棰佺瑝鐠囥儳娅ч懓妤冩暩
            try {
              this.flowLightController.stop();
            } catch (_err) {
            }
            const wu = WindowUtil.getInstance();
            wu.applyPlaybackWindowChrome(false, false);
            Logger.info('RzdPlayerRoute', 'leave overlay: window layout unchanged');
            wu.applyPcPlaybackDecorButtonStyle(false);
          })

          // 閳藉應妲?A2閿涙碍鐡曠拠宥夈€夋い鍫曞劥閻ㄥ嫨鈧苯鐨濋棃?+ 濮濆苯鎮曢妴宥嗚癁鐏炲倶鈧?
          //   閺€鎯ф躬 Stack C 閻?*閺堚偓閸氬簼绔存稉顏勵劉鐎?*閿涙瓪position` 閺?閻╃顕悥鍓佺矋娴犺泛涔忔稉濠咁潡閻ㄥ嫮绮风€电懓鐣炬担?閿?
          //   閼板本婀扮仦鍌滄畱瀹革缚绗傜憴鎺戞皑閺勵垳鐛ラ崣锝呭斧閻愮櫢绱欐稉?`MorphCoverBridge` 閸氬瞼楠囬崥灞藉經瀵板嫸绱氶埇?
          //   `PlayerExpandState.lyricMorph()` 娴溿倕鍤惃鍕崶閸欙絽娼楅弽鍥у讲娴犮儳娲块幒銉ф暏閿?
          //   閸氬本妞傜€瑰啫婀潻娆庨嚋鐞?`scale/translate/clip` 閸欐ɑ宕叉潻鍥╂畱鐎圭懓娅掗柌?閳?**閺€鎯版崳閺冩儼绐￠惈鈧稉鈧挧椋庣級**閵?
          //
          // 閴€鏂烘磮 2026-10-16閿?*閺堫剝鐤嗙拠鏇＄箖娑撯偓濞?閹稿妫ら悾灞界湴缁狙勬儔閸掍即銆夐棃銏＄壌缁?閿涘本甯圭€电厧鐣亸杈ㄦ寵閸ョ偘绨?*閿涘绱?
          //   閺冪姷鏅惃鍕湴缁狙呪€樼€圭偞妲?濞搭喖濮╃仦鍌欑瑢 `playerPane` 閸氬瞼楠囬妴浣告躬瑜般垹褰夌€圭懓娅掓稊瀣樆"
          //   閿涘潉wujie.pa:1861` 閻?builder 妞ゅ搫绨悰顭掔窗11 `floatingCover` / 12 `metaRow` /
          //    13 `floatingMeta`閿涘瞼顑?**52** 閹靛秵妲?`playerPane`閿涘鈧柡鈧?
          //   娴?*閹存垳婊戞稉宥堝厴閻撗勬儔闁絼閲滅仦鍌滈獓**閿涘苯甯崶鐘叉躬"鏉╂瑤閲滅€圭懓娅掗崷銊ㄧ箹娑擃亝璇炵仦鍌欑瑐婢舵艾鍏辨禍鍡曠娴犳湹绨?閿?
          // ```
          //     閺冪姷鏅敍姘殱闂堛垹鏄傜€?= edge 鑴?scaleAt(t)閿涘湑overMorph 缁绢垰鍤戞担鏇犵暬閸戠儤娼甸惃鍕剁礆
          //     閹存垳婊戦敍姘殱闂堛垹鏄傜€?= morph.size 鑴?**鐎圭懓娅掗惃?morphScale**閿?閸欐ɑ宕插?闁絼绔寸€?
          //           .scale(morph.size/base.size) + .translate(...) 閻ㄥ嫪楠囬悧鈺嬬礉鐟?
          //           `LyricFloatLayer` 閻?閳?閹恒劌顕遍敍?
          // ```
          //   閳?鐎圭懓娅?`scale` 鏉╂瑤绔村Λ鎺戞躬閹存垳婊戞潻娆掔珶**閸氬本妞?*閹垫寧濯存禍?閸愬懎顔愮仦鍌濈閻偓缂?娑?
          //     "濞搭喖鐪扮亸渚€娼版禒搴㈡殻缁愭鍋呮稉鈧禒鐣岀級閸掓媽绯犳担鐘虫蒋闁絼绔存禒?**娑撱倓娆㈡禍?*閿涙稒妫ら悾灞藉涧閹垫寧濯撮崜宥堚偓鍛偓?
          //   閳?閹跺﹥璇炵仦鍌涙儔閸戝搫顔愰崳?= 娑撱垺甯€閸氬氦鈧?閳?鐏忎線娼伴崷銊ュЗ閻㈣鑵?*鐏?`morphScale` 閸?*
          //     閿涘牐鎹ｉ幍瀣 閳?0.082 閳?閸欘亜澧?8%閿涘鈧倿鍋呭锝嗘Ц閻劍鍩?*瀹歌尙绮＄€圭偞绁存潻?*閻ㄥ嫬鑸伴悩璁圭窗
          //     `morphOverlayBridging()` 濞夈劑鍣撮柌宀€娈戦妴灞界殱闂堫澀绮犳稉瀣窔娑撳﹪顥ｉ妴?閵嗗苯鐨濋棃銏㈢級閹存劒绔撮悙骞库偓宥冣偓?
          //   閳?**鐟曚胶婀￠悡褎鎯夐柇锝勯嚋鐏炲倻楠囬敍灞藉缂冾喗娼禒鑸垫Ц閸忓牊濡哥亸渚€娼伴惃鍕槀鐎靛憡娼靛┃鎰暭閹?`scaleAt(t)`**
          //     閿涘牆骞撻幒澶愬亝娑撯偓鐎?`.scale/.translate`閿涘绱濋柇锝嗘Ц鐠恒劋绗佹径鍕畱缂佹挻鐎弨鐟板З + **韫囧懘銆忛張澶庮啎婢跺洭鈧劕鎶氶惇?*閵?
          //   鐎瑰本鏆ｉ悶鍡欐暠鐟欎焦婀伴弬鍥︽閺?`Stack` 闁插矂鍋呭▓?`閴€鏂烘磮 娑撳秷顩﹂幎濠冭癁閸斻劌鐪伴幖顒€鍩屾潻娆撳櫡` 閻ㄥ嫭鏁為柌濞库偓?
          if (this.usesPhoneSwiperLayout()) {
            this.LyricFloatLayer()
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`PLAYER_ROOT_ID`閿涘绱?*闂堢偞澧滈崝鍨彠闂傤叀顩﹂幏宥囨畱闁絽绱惰箛顐ゅ弾鐏忚鲸妲搁張顒冨Ν閻?*閵?
      //
      // 閺冪姷鏅柇锝勭娓氀嶇礉`.id(PLAYER_ROOT_ID)` 閹稿倸婀?*鐢?`.scale/.translate/.clip` 閻ㄥ嫰鍋呮稉?Stack 娑?*
      // 閿涘潉wujie.pa:191400-191478`閿涙瓪.scale` 191400-191415 閳?`.translate` 191416-191431 閳?
      //   `.clip(true)` 191462-191469 閳?**`.id(PLAYER_ROOT_ID)` 191470-191478**閿涘绱?
      // 閼?`MeshCoverBg` 娑?`playerPane` 闁棄婀€?*闁插矂娼?*閿涘牊婀版い?:4952-4970 闁絾顔岄柅鎰攽鐎靛湱鍙庨敍澶堚偓?
      //
      // 閳?閹碘偓娴犮儴绻栭柌灞肩瘍閹稿倸婀?*瑜般垹褰夌€圭懓娅?*鏉╂瑤绔寸仦鍌︾礄娑撳秵妲哥€瑰啰娈戦悥?`Stack`閿涘绱?
      //   闂堟瑦顒涢幀渚婄礄`morphScale=1 / translate=(0,0) / 閺冪姾顥嗛崜鐚旈敍澶婄暊鐏忚鲸妲?*濠娾€崇潌閻ㄥ嫭鎸遍弨楣冦€?*閿?
      //   韫囶偆鍙庨幏鍨煂閻ㄥ嫭顒滈弰?濠娾€崇潌闁絼绔村? 閳ユ柡鈧?鏉╂瑦顒滈弰?`ShrinkOverlay` 鐟曚焦鐪扮挧椋庡仯娑撳孩寮х仦蹇涒偓鎰剼缁辩姴顕鎰畱閸撳秵褰侀妴?
      //   閳跨媴绗?閸ョ姵顒?`componentSnapshot.get(PLAYER_ROOT_ID, 閳?` **韫囧懘銆忛崷銊ヨ埌閸欐ê绱戞慨瀣╃閸?*鐠?
      //      閿涘牊妫ら悾宀€娈?`closeWithAnimation()` 娑旂喐妲搁崷?`pullMode` 娑斿顦婚妴渚€銆夐棃銏ｇ箷濠娾€崇潌閺冭埖澧犻幏宥忕礆閵?
      //   閳跨媴绗?娑?`MESH_BG_ID` / `MINI_LYRIC_BOX_ID` 缁?*楠炶泛鐡?*閿涘潉getFrameNodeById` 閹?id 閺屻儻绱?
      //      娑撯偓娑擃亣濡悙鐟板涧閺堝绔存稉?id閿涙稖绻栭崙鐘遍嚋閺?*娑撳秴鎮撻懞鍌滃仯**閿涘奔绨版稉宥呭閸濆稄绱氶妴?
      .id(PLAYER_ROOT_ID)
      // 閳藉應妲勯埥鍛 2026-10-17閿?*閹恒儰绗傛稉濠冪埗闁絼閲?LANDING 閺冭泛浠犵粭?閻ㄥ嫮绮崚鍫曟，** 閳ユ柡鈧?`playerPaintsOf`閿?
      //
      // ## 娑撳﹥鐖堕柇锝勭閺夆剝妲?*閺堝绉风拹纭呪偓?*閻ㄥ嫸绱檂wujie.pa:153390-153430`閿涘畭MainPage` 閸欐垵绔疯ぐ銏犲綁閻樿埖鈧線鍋呴柌宀嬬礆
      // ```ts
      //   AppStorage.setOrCreate(K_MORPH_SQUASH, playerPaintsOf(stage) ? true : false);  // 閳?鐏忚鲸妲告潻娆庨嚋鐢啫鐨?
      //   if (stage !== MorphStage.LANDING) { this.stopLandAnim(); this.morphSquashY = 1; }
      // ```
      // 閼?`playerPaintsOf(stage) = stage !== MorphStage.LANDING`閿涘潉MorphState.ets`閿涘畭wujie.pa:93205`閿?
      // 閳?**鏉?LANDING 闁絼绔撮崚鏄忔崳閿涘本鎸遍弨楣冦€夐弫鎾€夋稉宥呭晙缂佹ê鍩?*閵?
      // `PlayerPage` 娓氀嗩嚢鐎瑰啫姘ㄩ弰?`pullPaintable = !pullGeomReady ? true : playerPaints(stage)`閵?
      //
      // ## 閺堫兛绮ㄩ崢鐔告降**濞屸剝甯?*閿涘牊顒撮梻顭掔礆
      // `PlayerExpandState.playerPaints()` 閺冣晛姘ㄩ崘娆忋偨娴滃棴绱檂return stage !== LANDING;`閿涘绱?
      // 濞夈劑鍣撮柌灞肩瘍閸愭瑧娼冪€瑰啴妲婚惃鍕Ц娴犫偓娑斿牞绱?
      // > 閵嗗ANDING = 瀹歌尙绮℃禍銈堢箷缂佹瑨绯犳担鐘虫蒋閿涘牆顕弽?`playerPaintsOf = false`閿涘绱版潻娆庣鐢嗘崳閹绢厽鏂佹い?
      // >   **娑撳秴鍟€閻?*閿涘苯鎯侀崚娆庣窗閸︺劏绯犳担鐘虫蒋鐏忎線娼版稉濠勬殌娑撯偓娑?*閸氬苯鏄傜€靛摜娈戝ǎ杈鐏忓繑鏌熼崸?*閿涘瞼娲块崚鎷岊潶閸楁瓕娴囬妴鍌樷偓?
      // 娴ｅ棗鐣?*闂嗚埖绉风拹纭呪偓?* 閳?闁絽褰炵拠婵囧伎鏉╂壆娈戦悳鎷岃杽娑撯偓閻╂潙婀崣鎴犳晸閵嗗倽鈧?閸氬苯鏄傜€靛摜娈戠亸蹇旀煙閸?閸︺劍澧滈張杞扮瑐濮濓絾妲?
      // **娑撯偓閺夆€崇发閻喚娈戦懗灞炬珯**閿涘牆顔愰崳?`scale 閳?0.082` 鑴?`clipHeight 閳?683` 閳?鏉╄渹缍橀弶锟犲亝閸?
      // 330鑴?6 閻ㄥ嫭澧庨獮宕囩叐瑜邦澁绱氶垾鏂衡偓?娑撳海鏁ら幋椋庮儑 閳?閺壜扳偓?*閺堝鍎楅弲顖欑稻閺勵垶鐝惔锔惧娴?*閵嗗秹鈧劕鐡ч崥璇叉値閵?
      //
      // ## 娑撹桨绮堟稊?`.visibility(Hidden)` 閼板奔绗夐弰?`.opacity(0)` 閹存牗娼禒鑸佃閺?
      //   璺?`Hidden` = **娑撳秶绮崚韬测偓浣风稻娣囨繄鏆€鐢啫鐪?* 閳?娑?閸嬫粎鐟?閸氬奔绠熼敍灞肩瑬娑撳秴濮╂禒璁崇秿闁插繑绁?闁挎氨鍋?
      //     閿涘潉getFrameNodeById` 閻ㄥ嫮鐓╄ぐ顫偓涔nAreaChange` 娑撳﹥濮ら柈鎴掔瑝閸欐濂栭崫宥忕礆閿?
      //   璺?`.opacity(0)` 娴犲秳绱扮挧鎵帛閸掑墎顓哥痪鍖＄礄"閸嬫粎鐟?濞屸€充粵閸掑府绱氶敍宀冣偓灞肩瑬閺堫剟銆夐惃?`.opacity` 瀹歌尙绮￠弰?
      //     `morphOpacityValue()`閿涘牊浜?1閿涘矁顫嗛柇锝夊櫡閻ㄥ嫭鏁為柌濠忕礆閿?
      //   璺?閺夆€叉濞撳弶鐓嬫导姘Ω閼哄倻鍋ｆ禒搴㈢埐娑撳﹥鎲抽幒?閳?闁插繑绁村┃鎰Х婢舵唻绱檂PLAYER_BIG_COVER_ID` 缁涘绱氶敍宀勵棑闂勨晛銇囬妴?
      // 閳跨媴绗?韫囶偆鍙庨崷?`morphLand()` **娑斿澧?*閹峰稄绱欑憴?`closeWithAnimation` 閻ㄥ嫰銆庢惔蹇ョ礆閳?閺堫剟妫紙璇蹭海閺?
      //    閸ユ儳鍑＄紒蹇撳煂閹靛绱濇稉宥勭窗閹峰秴鍩屾稉鈧鐘碘敄閸ヤ勘鈧?
      // 閳跨媴绗?娑撳﹣绔寸敮褌绮涢弰?LEAVING閿涘牆婀悽浼欑礆閳?閸忔娊妫撮崝銊ф暰閺堫剝闊╂稉宥呭綀瑜板崬鎼烽妴?
      .visibility(this.expandState.playerPaints() ? Visibility.Visible : Visibility.Hidden)
      // 鐟佷礁澹€缁愭褰涙妯哄 = 閸欘垵顫嬫妯哄 / 缂傗晜鏂?閳?缂傗晜鏂侀崥搴㈩劀婵傝姤妲搁柇锝呮健閸欘垵顫嬮惌鈺佽埌
      .height(this.morphClipHeight())
      // 鏉堝湱鏅憗浣稿閿涘牆娓剧憴鎺旀暠閸氬嫬娴樼仦鍌濆殰鐢讣绱辨稉宥囨暏 clipShape閿涙艾鐣犳导姘愁洬閻?borderRadius閿?
      // 閼板奔绗栫€瑰啰娈戣ぐ銏㈠Ц鐎靛綊缍堢拠顓濈疅閸︺劍妫ょ拋鎯ь槵閺冭埖鐥呭▔鏇㈢崣鐠囦緤绱?
      .clip(this.expandState.morphClipping())
      // 閺佹挳銆夌紓鈺傛杹 + 娴ｅ秶些閿涙岸娼ゅ銏♀偓?scale=1 / translate=0閿涘奔绗屽▽鈩冩箒鏉╂瑥顨滈崝銊ф暰閺冨爼鈧劕鍎氱槐鐘辩閼?
      //
      // 閳藉應妲勯埥?2026-10-16閿涘牏鍙庨幖顒佹￥閻ｅ瞼娈?*閺勬儳绱￠柨姘卞仯**閿涘绱?
      //   閺冪姷鏅柇锝勯嚋鐎圭懓娅掗敍鍧剋ujie.pa:191400-191415`閿涘鍟撻惃鍕Ц
      //     `.scale({ x: expand.scaleValue, y: expand.scaleValue })`
      //   閼板苯鐣犻惃?`initTranslateX/Y` 閺?*閹?缂佹洑鑵戣箛鍐級閺€?閸欏秷袙閸戠儤娼?*閻?
      //   閿涘潉initParams` 51524-51575閿涙瓪(缁愭顔旈埈鎶宱xW)/2 閳?left` / `(h 閳?h璺痵)/2 閳?top`閿涘鈧柡鈧?
      //   娑旂喎姘ㄩ弰顖濐嚛**"缂佹洑鑵戣箛?閺勵垰鐣犻惃鍕閹?*閿涘苯褰ч弰顖炴浆姒涙顓婚崐鐓庡幀閻滆埇鈧?
      //   閹存垳婊戞潻娆庣娓氀勫閺堝鍤戞担鏇礄`initTranslateX/Y`閵嗕梗coverHostW/H`閵嗕線鈧棗褰夐幑銏″腹鐎电》绱氶悽銊ф畱娑旂喐妲?
      //   閸氬奔绔存稉顏勫閹绘劧绱濋幍鈧禒銉ㄧ箹闁?*閹跺﹤鐣犻弰鎯х础閸愭瑥鍤弶?*閿涙俺顕㈡稊澶岀搼娴犲嚖绱濇担鍡樺Ω閸嬪洩顔曢柦澶嬵劥 閳ユ柡鈧?
      //   娑撳洣绔寸亸鍡樻降 ArkUI 閺€閫涚啊姒涙顓婚柨姘卞仯閿涘矁绻栨稉鈧悰宀冨厴閹糕€茬秶"閺佹潙顨滈崙鐘辩秿娑撯偓鐠х兘鏁婃担?閵?
      //   閳跨媴绗?**閸欘亝婀?`centerX/centerY` 閺?閻╃顕懛顏囬煩閻ㄥ嫮娅ㄩ崚鍡樼槷"**閿?0% = 閼哄倻鍋ｉ懛顏勭箒閻ㄥ嫪鑵戣箛鍐跨礆閿?
      //     閹碘偓娴犮儱婀禒璁崇秿鐏忓搫顕稉瀣厴缁涘鐜禍?缂佹洝鍤滈煬顐¤厬韫?閵?
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

      // 閴€鏂烘磮 2026-10-16 閳ユ柡鈧?**娑撳秷顩﹂幎濠冭癁閸斻劌鐪伴敍鍫濈殱闂?濮濆苯鎮曢敍澶嬫儔閸掓媽绻栭柌宀嬬礄妞ょ敻娼伴弽鍦獓閿?*閵?
      //
      // ## 閹存垶婀版潪顔跨槸鏉╁洣绔村▎鈽呯礉閹恒劌顕辩€瑰苯姘ㄩ幘銈呮礀娴滃棴绱欑拋棰佺瑓閺夈儱鍘ゅ妞剧瑓濞嗏€冲晙鐠囨洩绱?
      // 閺冪姷鏅惃?*鐏炲倻楠?*绾喖鐤勯弰?濞搭喖濮╃仦鍌欑瑢 `playerPane` 閸氬瞼楠囬妴浣告躬瑜般垹褰夌€圭懓娅掓稊瀣樆"
      // 閿涘潉wujie.pa:1861` 閻?builder 妞ゅ搫绨悰顭掔窗11 `floatingCover` / 12 `metaRow` /
      //  13 `floatingMeta`閿涘瞼顑?**52** 閹靛秵妲?`playerPane`閿涘鈧柡鈧?
      // 閹碘偓娴犮儲鍨滄稉鈧惔锔藉Ω鐎瑰啯鎯夐崚棰佺啊閺堫剙鐪伴敍宀€鎮婇悽杈ㄦЦ"鐢啫鐪惄鎺嶇瑢閺嬨垼閰遍柈鐣屽弾閹?閳?鐟欏倹鍔呴崣妯哄娑撴椽娴?閵?
      //
      // ## 娑撹桨绮堟稊鍫ュ亝娑擃亞鎮婇悽?*閺勵垶鏁婇惃?*
      // 閺冪姷鏅惃鍕癁閸斻劌鐪伴柌宀嬬礉鐏忎線娼伴悽銊ф畱閺?*缁绢垰鍤戞担?+ 娑撯偓濞?`scale`**閿?
      // ```
      //   CoverMorph.scaleAt(t) = lerp(1, lyricScale, t)      // 85856-85743
      //   濞撳弶鐓嬬亸鍝勵嚟 = edge 鑴?scaleAt(t)                        // 85856 闁絼绔村?
      // ```
      // 閼?*閹存垳婊戞潻娆庣鐏炲倻娈戠亸渚€娼伴弰?閸欐ɑ宕插?**閿涘潉LyricFloatLayer` 闁插矂鍋呯€?
      // `.scale(morph.size / base.size)` + `.translate(...)`閿涘矁顫嗛柇锝夊櫡閻?閳?閹恒劌顕遍敍澶嗏偓鏂衡偓?
      // 鐎瑰啰娈戠仦蹇撶鐏忓搫顕?= **`morph.size` 鑴?鐎圭懓娅掗惃?`morphScale`**閵嗗倷绡冪亸杈ㄦЦ鐠囪揪绱?
      // ```
      //   鐎圭懓娅?scale 鏉╂瑤绔村Λ?*閸氬本妞?*鐠愮喕鐭楁稉銈勬娴滃绱?
      //     閳?閸愬懎顔愮仦鍌︾礄topBar/scrubber/transport/濮濆矁鐦濋敍澶庣閻偓缂?閳ユ柡鈧?閺冪姷鏅稊鐔告箒閿?
      //     閳?濞搭喖鐪扮亸渚€娼伴惃?*鐏忓搫顕?*娴?閺佸鐛ラ柇锝勭娴?缂傗晛鍩?鏉╄渹缍橀弶锟犲亝娑撯偓娴? 閳ユ柡鈧?閺冪姷鏅?*濞屸剝婀?*閿涘牆鐣犻棃?scaleAt閿涘鈧?
      // ```
      // 閳?閹跺﹥璇炵仦鍌涙儔閸戝搫顔愰崳銊ф畱闁絼绔撮崚浼欑礉閳?鐏忓彉娑禍?閳?鐏忎線娼伴崷銊ュЗ閻㈣鑵?*濮ｆ梹顒滅涵顔尖偓鐓庣毈 `morphScale` 閸?*
      //   閿涘潉morphScale` 閸︺劏鎹ｉ幍瀣 閳?0.082 閳?鐏忎線娼伴崣顏勫⒖ 8%閿涘鈧?
      //   闁絾顒滈弰?*閻劍鍩涘鑼病鐎圭偞绁存潻?*閻ㄥ嫬鑸伴悩璁圭窗
      //     `PlayerExpandState.morphOverlayBridging()` 閻ㄥ嫭鏁為柌濠傚斧閺?閳ユ柡鈧?
      //     閵嗗本鍨滄稉濠佺閻楀牆鍙ч幒澶婄暊閵嗕焦鏁肩拋鈺傛尡閺€楣冦€夐柌宀勫亝瀵姷婀＄亸渚€娼伴悪顒冨殰閹垫寧濯撮敍宀€绮ㄩ弸婊勬Ц閿涙埃鈧箒顫囬幇鐔稿灇娴?
      //       閵?*鐏忎線娼版禒搴濈瑓瀵扳偓娑撳﹪顥?*閵嗗稄绱欓悽銊﹀煕 2026-10-16 鐎圭偞绁撮敍澶堚偓宥忕礉
      //     娴犮儱寮?`鐏忎線娼扮紓鈺傚灇娑撯偓閻愬箍鈧礁鐫嶅鈧崝銊ф暰濞屸剝婀佺粩顖滃仯` 闁絽鍤戝▎掳鈧?
      //
      // ## 缂佹捁顔戦敍鍫滅瑓娑撯偓娑擃亙姹夐惄瀛樺复閻撗嗙箹閺壜よ泲閿?
      //   濞搭喖鐪?*韫囧懘銆忛悾娆忔躬瑜般垹褰夌€圭懓娅掗柌?*閵嗗倹妫ら悾灞肩閹碘偓娴犮儴鍏橀弨鎯ф躬婢舵牠娼伴敍灞炬Ц閸ョ姳璐熺€瑰啰娈?*鐏忎線娼伴懛顏囬煩**閺?
      //   缁绢垰鍤戞担鏇礄鐏忓搫顕?娴ｅ秶鐤?閸﹀棜顫楅崗銊╁劥缁犳鍤弶銉礉娑撳秴鎮嗘禒璁崇秿缁佹牕鍘涢崣妯诲床閿涘鈧?
      //   閳?鐟曚胶婀″锝囧弾閹碱剟鍋呮稉顏勭湴缁狙嶇礉閸撳秶鐤嗛弶鈥叉閺?*閸忓牊濡哥亸渚€娼伴惃鍕槀鐎靛憡娼靛┃鎰暭閹?`scaleAt(t)`**
      //     閿? 閸樼粯甯€"閸欐ɑ宕插?闁絼绔寸€?`.scale/.translate`閿涘矁顔€ `lyricMorph(t)` 閻╁瓨甯寸紒?
      //      鐏炲繐绠风亸鍝勵嚟閿涘绱濋柇锝嗘Ц娑撯偓濞?*鐠恒劋绗佹径?*閻ㄥ嫮绮ㄩ弸鍕暭閸旑煉绱濇稉?*韫囧懘銆忛張澶庮啎婢跺洭鈧劕鎶氶惇?*閵?
      //   婢跺秵鐗抽崨鎴掓姢閿涙瓪grep -rn "LyricFloatLayer()" RzdMusic --include=*.ets`
      //     閿涘牊婀￠張娑崇窗閸欘亝婀?*鐎圭懓娅掗崘?*闁絼绔存径鍕殶閻㈩煉绱?

      // 閳藉應妲勯埥?2026-10-16閿?*閻滄澘婧€閼奉亣鐦?*閿涘牐绻涢悙褰掋€婇柈?3 濞嗏€崇磻閸忕绱濈憴?`onDiagHotspotTap()` 閻ㄥ嫭鏁為柌濠忕礆閵?
      //   閺€鎯ф躬瑜般垹褰夌€圭懓娅?*娑斿顦?*閿涘牅绗夌悮顐ょ級閺€?鐟佷礁澹€閿涘绱濋幍鈧禒銉ョ暊閺勫墽銇氶惃鍕殶鐎涙ぞ绗岀拠缁樻殶閸氬苯褰涘鍕┾偓?
      //   閳跨媴绗?瀵拌姤鐖ｉ崗宕囨絻閺?`diagText` 娑撹櫣鈹?閳?閻戭厼灏弰?*鐎瑰苯鍙忛柅蹇旀**閻ㄥ嫪绔撮弶掳鈧礁绐橀弽鍥祩濞撳弶鐓嬮妴?
      this.DiagHotspot()
      if (this.diagBadgeOn) {
        this.DiagBadge()
      }

      // 鐠恒劏鍓奸張顒佸床濠ф劙鍟嬮惄顔藉絹缁€鐑樏獮鍜冪礄閹剚璇為崷銊︽付娑撳﹪娼伴敍?
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }

      // 閳跨媴绗?缂侇參顥ｇ亸渚€娼伴敍鍧凪orphCoverBridge`閿?*娑撳秴婀潻娆撳櫡**閿?026-10-15 鐠у嘲鐣犻悽璇叉躬**閸愬懎顔愮仦鍌欑閸?*
      //    閿涘牐顫嗘稉濠囨桨閺?Stack 闁插矂鍋呭▓鍨暈闁插绱氶垾鏂衡偓?閻㈣婀潻娆庣鐏炲偊绱欓崘鍛啇娑斿绗傞敍澶夌窗閹跺﹣绮犳稉瀣磳鐠ч娈?
      //    鐏忓繑鐡曠拠?閺€鎯版閹稿鎸?鏉╂稑瀹抽弶?鎼存洟鍎撮幐澶愭尦閸忋劑鍏橀崢瀣╃秶閿涘瞼鏁ら幋宄扮杽濞?鐏忓繑鐡曠拠宥勭矤鐏忎線娼伴懗灞芥倵閸戣櫣骞囬妴浣界箻鎼达附娼悮顐ｅ皡"閵?
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 閳?娑撳濯洪弨鎯版崳閹绢厽鏂侀崳顭掔礄MusicHome 閸氬本顑欐禍銈勭鞍閿涘绱扮粩鏍纯閹锋牗瀚跨捄鐔稿閺€鎯版崳閿涘本婢楅幍瀣瘻闂冨牆鈧厧鍠呯€规艾骞撻悾娆嶁偓?
    //   閹稿倸婀張鈧径鏍х湴閿涙稒鐡曠拠宥夊亝缁夊秴褰插姘З鐎涙劘濡悙閫涚窗閸忓牊甯撮崚鎵彨閻╁瓨澧滈崝鍖＄礉
    //   閹碘偓娴犮儱婀宀冪槤娑撳﹥绮存稉宥勭窗鐠囶垵袝閸欐垶鏁圭挧鍑ょ礄ArkUI 閻ㄥ嫭澧滈崝鍨晪濞夛繝銆庢惔蹇ョ窗鐎涙劘濡悙閫涚喘閸忓牞绱氶妴?
    .gesture(
      PanGesture(this.panOption)
        // 閳藉應妲?2026-10-15閿涘牏鏁ら幋宄扮杽濞村鈧本鐥呭▔鏇氱瑓閹峰鍙ч梻顓熸尡閺€鎯ф珤閵嗗秶娈戦幒鎺楁闁挎氨鍋ｉ敍澶涚窗
        //   閺冪姷鏅柇锝勫敜閹靛濞嶉弰顖氱敨 `onActionStart 閳?dragBackStart()` 閻?
        //   閿涘潉_recover/logic-src/瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md` 鎼?.3閿涙瓪Down / distance:8` +
        //   閸ユ稐閲滈崶鐐剁殶 start/update/end/cancel 姒绘劕鍙忛敍澶堚偓鍌涘灉娴狀剙甯弶銉ュ涧閺?update/end
        //   閳?娑撯偓閺?娑撳濯哄▽鈥冲冀鎼?閿?*閸掑棔绗夊〒鍛Ц閹靛濞嶅▽鈥冲煂鏉╂瑣鈧浇绻曢弰顖氬煂娴滃棔绲剧悮顐︽，閹糕剝甯€**閵?
        //   閻滄澘婀幎濠傜暊閹垫挸鍤弶銉礄`hdc shell hilog -x | Select-String 'RzdMorph dismiss pan start'`閿涘绱?
        //     璺?娑撳濯洪弮?*閹垫挸绶遍崙鐑樻降** 閳?閹靛濞嶇捄顖滄暠濮濓絽鐖堕敍宀勬６妫版ê婀梻?闂冨牆鈧?
        //       閿涘牊甯撮惈鈧惇?`RzdMorph dismiss blocked` 娑?`RzdMorph dismiss commit`閿涘绱?
        //     璺?**閹垫挷绗夐崙鐑樻降** 閳?缁旀牜娲块幏鏍уЗ濞屄ゆ儰閸掔増婀伴懞鍌滃仯娑撳绱欑悮顐＄瑐鐏炲倹鍨ㄧ€涙劕鐪伴崥鍐╁竴閿涘鍣?鐟曚焦鏁奸幐鍌濇祰閻愮櫢绱?
        //       閺冪姷鏅惃鍕粵濞夋洘妲搁幐鍌氭躬**妞よ埖鐖柇锝勭閺?Row**閿涘牓娼姘З閵嗕礁绻€鐎规碍鏁归崚甯礆閼板奔绗夐弰顖涙殻妞ょ偣鈧?
        .onActionStart((): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan start isClosing=${this.isClosing} ` +
            `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}`);
        })
        .onActionUpdate((event: GestureEvent): void => {
          // 鐠虹喐澧滈張鐔兼？娑旂喓绮?velocityY閿涙碍瀚嬮崝銊よ厬鐎瑰啩绗夎ぐ鍗炴惙閸掋倕鐣鹃敍鍫濆灲鐎规艾褰ч崷銊︽緱閹靛鍋呮稉鈧敮褏鏁ら敍澶涚礉
          // 娴肩姾绻橀崢缁樻Ц娑撹桨绨￠弮銉ョ箶闁插矁鍏橀崥灞炬閻鍩?娴ｅ秶些 + 闁喎瀹?閻ㄥ嫬鐣弫瀛樻锤缁捐￥鈧?
          this.onDismissDrag(event.offsetY, false, event.velocityY);
        })
        .onActionEnd((event: GestureEvent): void => {
          // 閳?D1閿涙碍婢楅幍瀣箹娑撯偓鐢呮畱 `velocityY` 鐏忚鲸妲搁柅鐔峰閹绘劒姘﹂崚銈呯暰閻ㄥ嫯绶崗銉礄`GestureEvent.velocityY`閿?
          //   `gesture.d.ts` @since 10閿涘本婀伴張?SDK 瀹稿弶鐗崇€电懓鐡ㄩ崷顭掔礆閵嗗倻顑侀崣铚傜瑝閻㈣鲸鍨滄禒顒€浜ｇ拋鎾呯礉鐟?`onDismissDrag`閵?
          this.onDismissDrag(event.offsetY, true, event.velocityY);
        })
        // 閳藉應妲?2026-10-15閿涘牆顕鎰￥閻?閸ユ稑娲栫拫?閿涘绱?*鏉╂瑤绔撮弨顖欎簰閸撳秵妲哥紓铏规畱**閵?
        //   婢瑰啿鐪伴柇锝勭瑏閺夆€虫倱缁粯澧滈崝?*闁姤婀?*鐎?閳ユ柡鈧?`products/default/閳?Index.ets` L1786閿涘潉onPullOpenCancel()`閿涘鈧?
        //   `MiniBarPlayer.ets` L166閵嗕梗HomeMiniBarPlayer.ets` L235 閳?閸欏牊妲?
        //   "**閸氬奔绔磋ぐ銏㈠Ц閺?N 婢跺嫨鈧礁褰ч弨閫涚啊娑撯偓婢?*"閿涘煪?6.1.6 闁絾娼弫娆掝唲閻ㄥ嫮顑囨禍灞绢偧閻滄澘鑸伴敍澶堚偓?
        //
        //   缂傚搫鐣犻惃鍕倵閺嬫粈绗屾稉濠佺鏉烆喕鎱ㄩ惃?`isClosing` 濞堝鏆€**閸氬奔绔寸猾?*閿涙碍澧滈崝鑳潶娑擃參鈧梹澧﹂弬顓熸
        //   閿涘牏閮寸紒鐔稿閸?/ 閺夈儳鏁稿Ο顏勭畽 / 閻栧墎楠囬幎銏″閸?/ 妞ょ敻娼扮悮顐㈠瀼鐠у府绱歚onActionEnd` **濮橀晲绗夌憴锕€褰?* 閳?
        //     璺?`dismissMorphActive` 濞堝鏆€ `true`閿涙矮绗呭▎鈥茬瑓閹峰妞?`!ended` 閸掑棙鏁导?*鐠哄疇绻?
        //       `morphBeginLeaving()`**閿涘牆鐣犻崣顏勬躬 `!dismissMorphActive` 閺冭埖澧犵挧閿嬪閿涘鍣?閸戠姳缍嶆稉宥呭煕閺傝埇鈧浇绐￠幍瀣晩娑旀唻绱?
        //     璺?閻╅晲缍呭▓瀣殌 `LEAVING` 閳?`morphContainerActive()` 閹帞婀?閳?
        //       `beginOpenMorphOnClick()` 閻ㄥ嫬鐣ч崡顐ｅΩ"閻愮懓鍤幍鎾崇磻"閸掋倖鍨?**瀹歌尙绮￠崷銊ょ窗鐠囨繈鍣?*"閼板瞼娲块幒?return false
        //       閳?**閻愮懓鍤幍鎾崇磻閸欏牓鈧偓閸栨牗鍨氬ú楣冪叾閺冄冨З閻?*閿涘牊顒滈弰顖滄暏閹村嘲鐤勫ù瀣畱闁絾娼惀鍥╁Ц閿涘矁鈧奔绗栧鍫ユ婢跺秶骞囬幋?缁嬪啿鐣鹃崸?閿涘鈧?
        //
        //   閺冪姷鏅惃鍕晸濞夋洖姘ㄩ弰?*閹跺﹤褰囧☉鍫濈秼閹存劖婢楅幍?*閿涙瓪onActionCancel 閳?dragBackEnd(0)`
        //   閿涘潉_recover/logic-src/瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md` 鎼?.3閿涙埃鎲?闁絾娼幍瀣◢閸ユ稐閲滈崶鐐剁殶姒绘劕鍙忛敍?
        //   cancel 鐠ф壆娈戦弰?`pullEnd(0)`閿涙稈鎳?鐠?`dragBackEnd(0)`閿涘鈧?
        //   閳跨媴绗?`velocityY` 韫囧懘銆忔导?**0**閿涙艾褰囧☉鍫滅瑝鐠囥儴顫﹁ぐ鎾村灇"韫囶偆鏁?閼板本褰佹禍銈嗘暪鐠у嚖绱檂fastFlick` 鐟?閳?00閿涘鈧?
        .onActionCancel((event: GestureEvent): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan cancel offsetY=${event.offsetY.toFixed(1)} ` +
            `dismissMorphActive=${this.dismissMorphActive} ` +
            `stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive}`);
          this.onDismissDrag(event.offsetY, true, 0);
        })
    )
    // 閳藉應妲?2026-10-15閿?*閹俱倕娲栨稉濠佺鏉烆喚娈戞稉鈧径鍕暭閸?*閿涘苯鑻熼幎濠傚斧閸ョ姴鍟撳〒?閳ユ柡鈧?鐟欎椒绗呴敍?
    //
    // 娑撳﹣绔存潪顔藉灉閸︺劏绻栭柌宀兯夋潻?`.id(MORPH_HOST_ID)`閿涘瞼鎮婇悽杈ㄦЦ"閺堫兛绮ㄦ稉銈咁槱濞夈劑鍣撮柈鍊燁嚛閹靛婧€娓氀嗙箹娑?id
    // 鐏忚鲸妲搁幘顓熸杹妞や絻鍤滃杈╂畱閺嶇懓顔愰崳顭掔礉閼板本鎸遍弨楣冦€夋禒搴㈢梾閹稿倽绻冪€?閵?*闁絼閲滈悶鍡欐暠閺勵垶鏁婇惃鍕剁礉瀹稿弶鎸欓崶鐐偓?*
    //
    // 閻喓娴夐敍鍫熸拱鏉烆喖鍙忔禒鎾寸壋鐎电櫢绱氶敍?
    // ```
    //   .id(MORPH_HOST_ID) 閻ㄥ嫮绮︾€规氨鍋ｉ敍?
    //     products/default/.../Index.ets:1796   閳?婢瑰啿鐪?*閺?Stack**閿?*鐢悂鈹?*閿涘矁顫嗙€瑰啳鍤滃閬嶅亝濞堝灚鏁為柌濠忕礆
    //     products/pc/.../Index.ets:345         閳?PC 婢瑰啿鐪伴弽?Stack閿涘牆鐖舵す浼欑礆
    // ```
    // 閳?閹靛婧€**鐠侯垳鏁卞Ο鈥崇础**娑撳绱濋幘顓熸杹妞ゅ灚妲告竟鍐茬湴閺?Stack 闁插矂鍋呮稉?`HdsNavigation` 閻?*鐎涙劘濡悙?*
    //   閳?娑撱倓閲滈懞鍌滃仯**閸氬本妞傞崷銊х矋娴犺埖鐖叉稉?*閵嗗倹澧嶆禒銉窗
    //     璺?**缂佹繀绗夐懗?*閸︺劍鎸遍弨楣冦€夋潻娆庣鐏炲倸鍟€閹稿倷绔村▎?閳ユ柡鈧?闁絾妲搁妴?*閸?id 娑撱倓鍞ら懞鍌滃仯**閵嗗稄绱?
    //       閼板本婀版禒鎾愁嚠鏉╂瑤娆㈡禍瀣箒閺勫海鈥樼拋鏉跨秿閿涘潉products/default/.../Index.ets` 閸忓厖绨?`MINI_BAR_ID` 閻ㄥ嫪琚辨径鍕暈闁插绱?
    //       "娑撱倓鍞ら崥?id 閻ㄥ嫯濡悙鐧哥礉`getRectangleById` 闁插繐鍩岄崫顏冪娴犳垝绗夌涵顔肩暰閿涘矁鎹ｉ悙鐟版皑閹?閿涘鈧?
    //       
    //     璺?娴滃孩妲?`PlayerExpandState.measureGeometry()` 闁插矂鍋呮稉?
    //       `measureNode(ui, MORPH_HOST_ID)` 閸?*閹靛婧€鐠侯垳鏁卞Ο鈥崇础娑?*闁插繐鍩岄惃鍕Ц**婢瑰啿鐪伴柇锝勭鐏?*
    //       閿涘牐鈧奔绗夐弰顖涙尡閺€楣冦€夐惃鍕梿閸擃亞鐛ラ崣锝忕礆閳ユ柡鈧?鏉╂瑦妲?*鐎靛湱娈戦妴浣风瘍濮濓絾妲哥€瑰啯鍏傜憰浣烘畱**閿?
    //       鐎瑰啯濡哥紒鎾寸亯閸欘亜鍟撴潻娑欐）韫囨绱檂hostNode=閳ヮ泦閿涘绱濋獮鏈电瑬閸︺劎鎻ｉ柇鑽ゆ畱濞夈劑鍣撮柌宀€鍋ｉ崥?
    //       "**缂佹繀绗夐懗鑺ュ瑏鐎瑰啫缍嬮柧鐑樺姬閻╊喗鐖?*閿涘牓鍋呴弰顖滎儑娴滄梹顐奸懛顏勬珫閿?閵?
    //     璺?娑撳﹣绔存潪顔藉灉鐠囶垯浜掓稉鐑樻Ц"濠曞繑瀵? 閳?缂佹捁顔戠拋銏☆劀娑撶尨绱?*鏉╂瑦妲搁崚缁樺壈閻ㄥ嫨鈧焦顒滅涵顔炬畱**閵?
    //
    // 閳跨媴绗?闁絼琚辨径鍕晸閻偓"閹靛婧€娓氀勬尡閺€楣冦€夐弽?Stack 鐏忚鲸妲?`MORPH_HOST_ID`"閻ㄥ嫭鏁為柌?*閺勵垶鏁婇惃?*閿?
    //    瀹告彃姘ㄩ崷鎷岊吂濮濓綇绱欑憴?`PlayerExpandState.measureGeometry()` 娑?`contentWidthVp/HeightVp` 娑撱倕顦╅敍澶堚偓?
  }

  /**
   * 瑜般垹褰夐張鐔兼？"缂侇參顥ｇ亸渚€娼?濞搭喖鐪伴敍姘瀵姾鍔氱粋璇茬鐏炩偓閵嗕焦瀵滅€瑰じ瀵岄崸鎰垼閹藉棙鏂侀惃鍕殱闂堫潿鈧?
   *
   * 閳跨媴绗?**2026-10-15閿涙俺绻栨稉鈧Λ鎺戝嚒缂佸繑鎯夐崚鏉匡紦鐏炲倹璇炵仦?*閿涘潉Index.ets` 閻?`MorphCoverClone()`閿涘绱?
   *    閺堫剟銆夐崣顏勬躬 `hostsMorphOverlay()` 娑撳搫浜ｉ惃鍕問娑撲紮绱橮C 婢瑰啿鐪伴敍澶夌瑐鏉╂鐨熺€?閳ユ柡鈧?
   *    鐠嬪啰鏁ら悙閫涚瑐閻ㄥ嫭鏁為柌濠傚晸濞撳懍绨℃稉杞扮矆娑斿牄鈧倸鍤遍弫棰佺秼娣囨繄鏆€閿涙瓍C 闁絾娼捄顖欑矝閻掑爼娓剁憰浣哥暊閿?
   *    閼板奔绗栭崚鐘冲竴鐎瑰啫姘ㄥ妤€鎮撻弮璺哄灩閹?PC 閻ㄥ嫬鐨濋棃銏犵秼濡帪绱欓柇锝嗘Ц閸欙缚绔存禒鏈电皑閿涘鈧?
   *
   * 闂堟瑦顒涢幀?*娑撳秳楠囬悽鐔舵崲娴ｆ洝濡悙?*閿涘潉morphBridging()` 娑?false閿涘绱濋幍鈧禒銉ョ暊娑撳秴褰查懗钘夊閸濆秹娼ら幀浣哥鐏炩偓閵?
   * `HitTestMode.None` 閺勵垰绻€妞よ崵娈戦敍姘殻鐏炲倿鎽靛鈥崇潌楠炴洩绱濇妯款吇閸涙垝鑵戦惃鍕樈娴兼碍濡搁幘顓熸杹妞ゅ灚澧嶉張澶屽仯閸戣鎮嗛幒澶堚偓?
   */
  @Builder
  MorphCoverBridge() {
    Stack() {
      Image(this.currentCoverSource())
        .width(this.expandState.morphCoverBridge().size)
        // 閳跨媴绗?妤傛ê瀹?*閸楁洜瀚崣?*閿涘牅绗夐崘宥呭晸濮濈粯鍨?`size`閿涘绱伴幘顓熸杹妞ら潧鐨濋棃銏狀樆閺?`layoutWeight(1)` +
        //    `constraintSize(maxWidth/maxHeight)`閿涘矂鍣洪崚鎵畱閻晛鑸版稉宥勭箽鐠囦焦妲稿锝嗘煙瑜邦潿鈧?
        //    閹稿顒滈弬鐟拌埌閻㈣鍤弶銉ф畱缂侇參顥ｇ亸渚€娼伴敍瀹?1 娴溿倖顥楃紒娆戞埂鐎圭偛鐨濋棃銏㈡畱闁絼绔撮崚璇叉皑娴兼俺鐑︽稉鈧稉?
        //    閿涘牏鏁ら幋宄扮杽濞村娈戦妴宀€绮ㄩ弶鐔告鐏忎線娼版担宥囩枂/婢堆冪毈鐠哄厖绔存稉瀣ㄢ偓宥忕礆閵?
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
   * 濮濆矁鐦濇い鐢搞€婇柈銊ф畱閵嗗苯鐨濋棃?+ 濮濆苯鎮?濮濆本澧滈妴宥嗚癁鐏炲偊绱欑€佃鐖ｉ弮鐘垫櫕 `PlayerPage.floatingCover` / `floatingMeta`閿涘鈧?
   *
   * ## 鐎瑰啯妲告禒鈧稊鍫礄A2閿涙碍浠径宥冣偓灞剧摃鐠囧秹銆夋い鍫曞劥閺堝鐨濋棃?+ 濮濆本娲搁崥宥囆為妴宥忕礆
   *
   * 閺冪姷鏅惃?`playerPane` 閺?`Stack { Swiper{ 鐏忎線娼版い?; **缁?*濮濆矁鐦濇い?} ; floatingCover ; floatingMeta }`
   * 閳ユ柡鈧?鐏忎線娼版稉搴㈢摃閸氬秵瀵曢崷?`Swiper` **娑斿顦?*閿涘苯鍨忛崚鐗堢摃鐠囧秹銆夐弮?*閸氬奔绔存稉顏勫帗缁?*缂傗晛鐨獮鍓佇╅崚浼淬€婇柈顭掔幢
   * 濮濆矁鐦濇い鐢稿亝娑撯偓妞ゅ灚婀伴煬顐㈠涧閺?`padding({ top: lyricPadTop() })`閵嗗倽绻栭柌灞芥皑閺勵垶鍋呮稉鈧仦鍌樷偓?
   *
   * ## 娑撳閲滅痪锔芥将閿涘牏宸辨稉鈧弶鈥虫皑娴兼艾鍤懓浣圭樅閻ュ拑绱?
   *
   * 1. **閸氬奔绔撮弮璺哄煝閼峰啿顦挎稉鈧鐘茬殱闂?*閿涙碍婀板ù顔肩湴閹稿倽娴?閴?鐏忎線娼版い鐢稿亝娴犵晫婀＄亸渚€娼扮悮?`.opacity(0)` 閽樺繗鎹ｉ弶?
   *    閳?鐟曞棛娲婄仦鍌涙Ц**閸烆垯绔?*閻ㄥ嫬鐨濋棃銏¤閺屾捁鈧拑绱?*濞屸剝婀?娑撱倛鈧懍绨扮悰?鏉╂瑥娲栨禍瀣╃啊**閿涘潉lyricFloatActive()` 瀹告彃鍨归敍澶堚偓?
   *    閿涘牊璇炵仦?`t = 0` 閻劎娈戠亸杈ㄦЦ閻喎鐨濋棃銏㈡畱閽€鐣屽仯閸戠姳缍嶉敍宀冾潌 `PlayerExpandState.lyricMorph`閿涘绱?
   * 2. **闂堟瑦顒涢幀浣风瑝娴溠呮晸婢舵矮缍戦懞鍌滃仯**閿涙艾鐨濋棃銏ゃ€夐棃娆愵剾閺?`lyricMorphT = 0` 閳?閸欐ɑ宕叉稉鐑樹航缁涘鈧椒缍呯純顔煎祮鐢啫鐪担?
   *    閿涘潉lyricFloatActive()` 闁絾濡搁梻銊ュ嚒閸掔娀娅?閳ユ柡鈧?鐟曞棛娲婄仦鍌氱埗妞逛紮绱濈憴?鎼傜粭?2 閸ф绱氶妴?
   *    `if` 閸掑棙鏁惄瀛樺复娑撳秴缂撻懞鍌滃仯 閳?闂堟瑦顒涢崷銊ョ殱闂堛垽銆夐弮鍓佸闂堫澀绗屽▽鈩冩箒鏉╂瑥顨滄稉婊嗐偪**闁劕鍎氱槐鐘辩閼?*閿?
   * 3. **娑撳秴鎮嗙憴锔芥嚋**閿涙瓪HitTestMode.None`閿涘牅绗?`MorphCoverBridge` 閸氬本顑欓敍澶嗏偓鏂衡偓?
   *    閺佹潙鐪伴柧鐑樺姬鐏炲繐绠烽敍宀勭帛鐠併倕鎳℃稉顓犳畱鐠囨繀绱伴幎濠冪摃鐠囧秶娈戝姘З娑撳海鍋ｉ崙璇插弿閸氬啯甯€閵?
   *
   * ## 娑撹桨绮堟稊鍫熷瘯閸︺劏绻栨稉顏冪秴缂冾噯绱檂Stack`C 閻ㄥ嫭娓堕崥搴濈娑擃亜顒㈢€涙劧绱氶懓灞肩瑝閺勵垰锛撶仦?
   *
   * 璺?**閸ф劖鐖ｉ崣锝呯窞**閿涙碍婀扮仦鍌氫箯娑撳﹨顫楃亸杈ㄦЦ缁愭褰涢崢鐔哄仯閿涘牅绗?`MorphCoverBridge` 閸氬瞼楠囬妴浣告倱閸欙絽绶?閳ユ柡鈧?
   *   鐎瑰啯瀵滅粣妤€褰涢崸鎰垼 `.position()` 閽€鎴掔秴閺?*瀹歌尪顫﹂惇鐔告簚妤犲矁鐦夋潻?*閻ㄥ嫸绱氶敍灞惧娴?`lyricMorph()` 娴溿倕鍤惃?
   *   缁愭褰涢崸鎰垼閸欘垯浜掗惄瀛樺复瑜?`.position()` 閻㈩煉绱?*閸忋劑鎽奸梿鑸靛床缁?*閿?
   * 璺?**韫囧懘銆忕捄鐔烘絻瑜般垹褰夋稉鈧挧椋庣級**閿涙艾鐣犻崷銊ㄧ箹娑擃亣顫?`scale + translate + clip` 閸欐ɑ宕叉潻鍥╂畱鐎圭懓娅掗柌宀嬬礉
   *   閺€鎯版崳閹绢厽鏂佹い鍨濞搭喖鐪扮捄鐔烘絻缂傗晪绱遍幐鍌氬煂閺?`Stack`閿涘牆褰夐幑顫婢舵牭绱氱亸鍙樼窗"妞ょ敻娼扮紓鈹库偓浣哥殱闂堫澀绗夌紓?閵?
   *
   * 閳跨媴绗?濮濆矁鐦濋幀搴濈疄閻?*娑撯偓娑擃亜鐡у▽鈥冲З**閿涘潉LyricsComponent` / `AmllLyricView` 娑撳秶顫敍澶堚偓?
   */
  @Builder
  private LyricFloatLayer() {
    // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻?`floatingCover`閿涘绱?*鐢悂鈹?+ 閸欐ɑ宕插?*閵?
    //
    //   閳?鐢悂鈹楅敍姘殱闂堛垺妲?`playerPane` 闁插奔绔存稉顏呬航閸︺劎娈戠憰鍡欐磰鐏炲偊绱濋棃?`scale/translate` 閸︺劋琚辨稉顏嗩伂閻愬綊妫块幓鎺戔偓纭风礉
    //      閹碘偓娴犮儵銆?0 娑撳秴鍟€閻㈣鐨濋棃顫礄闁綁鍣峰鎻掑灩 `MusicPlayInfoBlock`閿涘鈧柡鈧?**閸忋劎鈻奸崣顏呮箒娑撯偓娴犺棄鐨濋棃?*閵?
    //   閳?閸欐ɑ宕插蹇ョ窗鐢啫鐪崺鍝勫櫙鐏忓搫顕崣?`playerCoverGeomRect()`閿?*缁绢垰鍤戞担鏇樷偓浣风瑝閺屻儴濡悙?*閿涘绱?
    //      閸欘亝婀?`scale/translate` 娴兼碍灏撶€?閳?`t = 0` 閺?*娴ｅ秶鐤嗛悽鍗炵鐏炩偓閸愬啿鐣?*閿?
    //      娑撳秳绱伴崙铏瑰箛"鐎硅棄瀹虫笟婵婄娑撳﹥濮ら妴浣风瑐閹躲儰绶风挧鏍ь啍鎼?閻ㄥ嫭顒撮悳顖ょ礄2026-10-15 闁絾顐肩亸渚€娼板☉鍫濄亼閻ㄥ嫭婧€閸掕绱氶妴?
    //   閳?**閺佹澘顒熸稉濠佺瑢閺€鐟板闁劕鍎氱槐鐘电搼娴犲嚖绱欐禒缁樺壈 `t`閿涘奔绗夐崣?`t=0`閿?* 閳ユ柡鈧?閹恒劌顕遍敍鍦搑kUI 鐢瓕顫夌拠顓濈疅閿?
    //      `.scale` 缂佹洝濡悙閫涜厬韫囧啨鈧梗.translate` 閸︺劍婀紓鈺傛杹閻ㄥ嫮鍩楅崸鎰垼缁鍣烽崝鐙呯礆閿?
    //        scale   = morph.size / base.size
    //        translate = morph.xy 閳?base.xy
    //        濞撳弶鐓嬬亸鍝勵嚟 = base.size 鑴?scale = morph.size                      閴?
    //        濞撳弶鐓嬫稉顓炵妇 = baseCenter + translate
    //                 = (base.xy + base.size/2) + morph.xy 閳?base.xy = morph.xy + morph.size/2
    //        閳?濞撳弶鐓嬪锔跨瑐鐟?= morph.xy                                        閴?
    //        鐟欏棜顫庨崷鍡氼潡 = (morph.radius / scale) 鑴?scale = morph.radius          閴?
    //      閳?**鐏忎線娼伴崷銊ゆ崲娴ｆ洑绔寸敮褏娈戦拃鐣屽仯閵嗕礁銇囩亸蹇嬧偓浣告妇鐟欐帡鍏樻稉搴″斧閺?`.width/.position(lyricFloatRect())` 鐎瑰苯鍙忛惄绋挎倱**
    //      閿涘潉base` 閸欘亝妲?閸欏倽鈧啰閮?閿涘苯鐣犻崣鏍︾矆娑斿牆鈧ジ鍏樻稉宥呭閸濆秶绮ㄩ弸婊愮礉**閸欘亣顩︾€瑰啩绗夋稉?0**閿涙稖绻栧锝嗘Ц鐎瑰啫绻€妞よ崵鍑介崙鐘辩秿閻ㄥ嫬甯崶鐙呯礆閵?
    //      閳跨媴绗?娑撳﹥婧€鐠囩兘銆庨幍瀣€樼拋銈勭濞嗏槄绱扮亸渚€娼版い鐢稿亝瀵姴銇囩亸渚€娼版惔鏂剧瑢閺€鐟板**娑撯偓濡€茬閺?*閿涘牐瀚㈤崣妯圭啊閿涘矁顕╅弰?`.translate`
    //         娑?`.scale` 閻ㄥ嫬顦查崥鍫ャ€庢惔蹇庣瑢娑撳﹪娼伴崑鍥啎娑撳秶顑?閳ユ柡鈧?闁絾妲搁崬顖欑闂団偓鐟曚浇鐨熼弫瀵告畱閸嬪洩顔曢敍澶堚偓?
    Stack({ alignContent: Alignment.TopStart }) {
      // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?閳藉應妲?閺堫剙鐪伴幋鎰彌閹碘偓娓氭繆绂嗛惃?*娑撱倖娼崸鎰垼缁澧犻幓?*閿?026-10-15 鐞涖儴顔囬敍灞藉З閹靛澧犺箛鍛邦嚢閿涘鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
      //
      // 閸撳秵褰?閳剁媴绱?*閺堫剙鐪扮悮顐ｅ瘯閸?濠娾€崇潌閸愬懎顔愰弽?娑?* 閳?闁絼閲滅€瑰じ瀵岄惃鍕敶鐎瑰湱娲呭锔跨瑐鐟?= 缁愭褰涢崢鐔哄仯
      //   閿涘潉PlaybackPage.ets:3227` 闁絽褰?閺堫剙鐪伴惃鍕箯娑撳﹨顫楃亸杈ㄦЦ缁愭褰涢崢鐔哄仯"鐠囧娈戠亸杈ㄦЦ鐎瑰喛绱?
      //    閼板苯鐣?*閸欘亜顕幍瀣簚閺€顖涘灇缁?*閿涘鍣?`lyricMorph()` 娴溿倕鍤惃鍕崶閸欙絽娼楅弽鍥у讲娴?*閻╁瓨甯?*閸愭瑨绻?`.position()`閵?
      //   閳跨媴绗?閹广垺鍨氱€硅棄鐫?闂堛垺婢橀惃鍕問娑撲紮绱檂GridCol` 閸愬懎顔愰惄?/ 瀹革附鐖?`Column`閿涘姘?*娑撳秴鍟€閹存劗鐝?*閿?
      //      韫囧懘銆忛崗鍫濆櫤閹哄顔栨稉璇蹭箯娑撳﹨顫楅敍鍧凱layerExpandState.toHostPoint()` 鐏忚鲸妲告稉鍝勭暊閸戝棗顦惃鍕剁礆閿?
      //      閸氾箑鍨亸渚€娼伴弫缈犵秼閸嬪繋绔存稉顏呯埉娴?閳ユ柡鈧?鐟?`閻╊喗鐖ｉ埗?鐎硅棄鐫嗛棃銏℃緲缂佺喍绔?閺傝棄浼愰崶鍙ョ瑢妤犲本鏁?md` 鎼? 閻?S3a閵?
      //
      // 閸撳秵褰?閳垛槄绱?*閺堫剙鐪伴崥灞炬鐞氼偄顨滈崷銊ヨ埌閸欐ê顔愰崳顭掔礄scale + translate + clip閿?*闁?
      //   閳?`.position({x, y})` 闁插瞼娈戠粣妤€褰涢崸鎰垼閸欘亜婀?`p = 1`閿涘牆顔愰崳銊︽Ц閹帞鐡戦崣妯诲床閿涘妞?*娑撱儲鐗?*閽€钘夋躬缁愭褰涢惃?(x, y)閿?
      //      瑜般垹褰夋稉顓ㄧ礄p < 1閿涘鐣犻惃?*鐎圭偤妾?*缁愭褰涙担宥囩枂娴兼俺顫︾€圭懓娅掗崣妯诲床閹割亣铔嬮妴?
      //   閳?**閹恒劌顕遍敍鍫滅瑝閺勵垯鍙婇惃鍕剁幢閸欐ɑ宕查崢鐔哄仯閸欐牕顔愰崳銊よ厬韫囧喛绱?缂佹洑鑵戣箛鍐級閺€?閿?*閿?
      //        鐠佸墽鐛ラ崣锝呮綏閺?y閿涘苯顔愰崳銊╃彯 `H`閿涘牃澧?鐎瑰じ瀵屾姗堢礆閿涘畭s = initScale + (1閳姕nitScale)璺痶`閵嗕梗d = initTranslateY璺?1閳姲)`
      //        缂佹洑鑵戣箛鍐級閺€鎾呯窗`y 閳?H/2 + (y 閳?H/2)璺痵`閿涙稑鍟€楠炲磭些 `d` 閳?`y' = H/2 + (y 閳?H/2)s + d`
      //        娴狅絽鍙嗛張顑跨波閻?`initTranslateY = barY 閳?scaledH璺?1閳姕nitScale)/2`閿涘潉scaledH = barH/initScale`閿?
      //        楠炴湹鎶?`t = p`閵嗕梗k = H/2 閳?scaledH/2`閿?
      //            y' = k璺?1閳姱) + y璺痵 = k(1閳姲) + y璺痶   閳?  **`y' 閳?t 鑴?y`**閿涘牆娲滄稉?`k` 娑?`y` 閸氬矂鍣虹痪褋鈧椒绗栭崷?t=1 閺冭埖濮峰☉鍫礆
      //        璺?`p = 1`閿涘牐鎯ゆ担宥忕礆閿涙瓪y' = y` 閴?**濮濓絾妲哥拋鎹愵吀閸?*
      //        璺?`p = 0.5`閿涙埃澧?`y/2`   閳?**閸欘亝婀佺拋鎹愵吀閸婅偐娈戞稉鈧崡?*
      //        璺?`p = 0`閿涙埃澧?`0`        閳?鐠愭潙婀€圭懓娅掓稉濠呯珶
      //      閿涘牊濡?`y = 250` 娴狅綀绻橀張顒佹簚闁絿绮嶇€圭偞绁撮崙鐘辩秿 `initScale 閳?0.082 / scaledH 閳?683 / H 閳?925`閿?
      //        t=1 閳?250 閴佹挶鈧辜=0.5 閳?124閵嗕辜=0 閳?閳? 閳ユ柡鈧?娑?`y' 閳?t璺痽` 閸氳鎮庨敍?
      //   閳?**鏉╂瑦妲告稉鈧弶?閽€鎴掔秴閺冭埖顒滅涵顔衡偓浣歌埌閸欐ü鑵戦崑?閻ㄥ嫬褰涘?*閿涘潉RzdCoverRect` 閻?`base/tx/ty` 闁插繒娈戠亸杈ㄦЦ鐎瑰喛绱氶妴?
      //   閳跨媴绗?**2026-10-15 閸掔粯鍓版稉宥嗘暭**閿涘瞼鎮婇悽杈ㄦЦ閺€瑙勭《闁棄鍑＄悮顐ゆ埂閺堥缚鐦夋导顏囩箖閿?
      //       璺?闁棗褰夐幑銏犳礀妞ら潧鍞撮崸鎰垼 閳ユ柡鈧?閻喐婧€缂佹挻鐏?鐏忎線娼扮捄鎴濆煂瀹革缚绗傜憴?閿涘牐顫?`morphBridging()` 闁插矂鍋呭▓纰夌窗
      //         `.scale()` 閻ㄥ嫭鐏戞潪鏉戠秼閺冩湹绗夐弰顖涘灉娴犮儰璐熼惃鍕啇閸ｃ劋鑵戣箛鍐跨礆閿?
      //       璺?閺佹潙鐪伴幖顒€鍤ぐ銏犲綁鐎圭懓娅?閳ユ柡鈧?娴兼艾褰夐幋?妞ょ敻娼伴崷銊х級閵嗕礁鐨濋棃顫瑝缂?閿涘牏鏁ら幋宄扮杽濞村绻冮惃鍕潎閹扮噦绱氶妴?
      //   閳跨媴绗?**閸氬奔绔撮弽鐟版礈閻ㄥ嫬褰熸稉鈧禒鑺ュ鐠愭繂鍑＄紒蹇撴躬婢瑰啿鐪?*閿涙瓪Index.ets` 閻?`MorphCoverClone()` 娑斿澧嶆禒銉潶閹碱剙鍤?
      //      閹绢厽鏂佹い纰夌礉濞夈劑鍣撮崘娆戞畱濮濓絾妲告潻娆庢娴滃绱?閻晛鑸伴崡瀛樻Ц缁愭褰涢崸鎰垼 閳?閸欘亝婀?p=1 閹靛秳寮楅弽鍏碱劀绾?閿涘鈧?
      //   閳?缂佹捁顔戦敍?*閹靛婧€閺€顖欑箽閹镐胶骞囬悩?*閿涘牏鏁ら幋宄版躬閻喐婧€娑撳﹪鐛欐潻鍥潎閹扮喎褰查幒銉ュ綀閿涘绱?
      //      鐎硅棄鐫?闂堛垺婢橀柇锝勭鏉烆喖顩ч弸婊嗩洣婢跺秶鏁ら張顒€鐪伴敍灞界箑妞?*閸氬本妞?*閸愬啿鐣炬潻娆庣瑏閺夆€冲閹绘劖鈧簼绠炴径鍕倞閿?*娑撳秷顔忛崣顏呮儔娑撯偓閸?*閵?
      //   婢跺秵鐗抽崨鎴掓姢閿涙瓪hdc shell hilog -x | Select-String 'RzdCoverRect'`
      //     閳?閻鑸伴崣妯硅厬 `measured`閿涘潵nAreaChange 缂佹瑧娈戠敮鍐ㄧ湰娴ｅ稄绱氭稉?`base+tx` 閻ㄥ嫬妯婇敍?
      //        娑撳簼绗傞棃銏ゅ亝娑撳顢戞０鍕ゴ閿涘潷=1 閻╁摜鐡?/ p=0.5 閸戝繐宕?/ p=0 鐠愮顫楅敍澶婎嚠瀵版ぞ绗傜亸杈嚛閺勫氦绻栭弶鈥冲經瀵板嫯绻曢崷銊ф晸閺佸牄鈧?
      //
      // 濠娾€崇潌鐏炲懍鑵戠€圭懓娅掗敍姘殱闂堛垻娈?*鐢啫鐪担宥囩枂**閿涘牆褰夐幑顫婢舵牭绱氱亸杈ㄦЦ"閸╁搫鍣惌鈺佽埌"閻ㄥ嫬鐪虫稉顓濈秴
      // 閳藉應妲勯埥?2026-10-16閿涘牏鏁ら幋宄扮暰鐠嬪啨鈧?*瑜拌绨抽悡褎鎯夐崥?*閵嗗稄绱氶敍?
      //   閹跺﹤鐨濋棃顫矤閵?*閸╁搫鍣?+ scale/translate**閵嗗秵鏁奸幋鎰￥閻ｅ矂鍋呴弽椋庢畱閵?*缁绢垰鍤戞担鏇犳纯閹恒儴鎯ゆ担?*閵嗗秲鈧?
      //
      // ## 娑撹桨绮堟稊鍫ｎ洣閸樼粯甯€闁絼绔寸€?`scale/translate`
      //
      // 閸樼喐娼垫潻娆庣鐏炲倹妲搁敍?
      // ```
      //   Image().width(coverLayerBase().size)                     閳?閸╁搫鍣亸鍝勵嚟
      //          .scale(鐎圭偞绁寸亸鍝勵嚟 / 閸╁搫鍣亸鍝勵嚟)                        閳?鐞涖儱鍩?鐎圭偞绁寸亸鍝勵嚟"
      //          .translate(鐎圭偞绁存担?閳?閸╁搫鍣担?                        閳?鐞涖儱鍩?鐎圭偞绁存担宥囩枂"
      // ```
      // 娴滃孩妲?*鐏忎線娼伴張鈧紒鍫滅秴缂?= 鐎圭偞绁存担宥囩枂**閿涘矁鈧?鐎圭偞绁存担宥囩枂"閺夈儴鍤?`onAreaChange` 娑撳﹥濮ら惃?
      // `lyricFloatRect()`閿涙盯鍋呮稉顏勨偓鐓庢躬閺堫兛绮?*娑撳秴褰查幒褋鈧椒绡冮弮鐘崇《缁傝崵鍤庨弽绋款嚠**閿涘牏鏁ら幋宄扮杽濞?鐏忎線娼伴崑蹇庣秵"閿?
      // 閼板本鍨滈幐澶婄暊閸嬫矮鎹㈡担鏇熺墡濮濓綁鍏樻导姘愁唨鐟欏倹鍔呴弴鏉戞▕ 閳ユ柡鈧?鎼?4/鎼?5/鎼?6 娑撳顐奸柈鑺ョ壔閸︺劏绻栭弶锟犳懠娑撳绱氶妴?
      //
      // 閺冪姷鏅柇锝堢珶**閺嶈婀板▽鈩冩箒鏉╂瑦娼柧?*閿涙瓪floatingCover` 閺勵垯绔存稉?`Column(center)` 闁插瞼娈戠亸渚€娼伴敍?
      // 鐏忓搫顕?`morph.edge`閵嗕椒缍呯純?`morph.tyAt(t)`閵嗕礁娓剧憴?`morph.radiusAt(t)`
      // 閳ユ柡鈧?**閸忋劑鍎撮弰顖滅暬閸戠儤娼甸惃?*閿涘奔绗夐弻銉ゆ崲娴ｆ洝濡悙鐧哥礄`PlayerPage鐎瑰本鏆I鐎规氨顭?md` 鎼?閿涘鈧?
      //
      // 閳?閻滄澘婀悡褎鎯夌€瑰喛绱?*鐏忓搫顕?娴ｅ秶鐤?閸﹀棜顫楁稉鈧瀣絿閼?`lyricFloatRect()`閿? `lyricMorph(t)`閿?*閿?
      //   娑撳秴鍟€娑?`scale`閵嗕椒绗夐崘宥呭 `translate`閵嗕繖t = 0`閿涘牆鐨濋棃銏ゃ€夐棃娆愵剾閿涘妞?`lyricMorph(0)`
      //   鐏忚鲸妲?`playerCoverGeomRect()` 闁絼绔存禒?*閺冪姷鏅惃鍕暬瀵繒绮ㄩ弸?* 閳?閽€鎴掔秴閻㈣京鐣诲蹇庣濞嗏€崇暰濮濇眹鈧?
      Column() {
        Image(this.currentCoverSource())
          // 閳藉應妲勯埥?2026-10-16閿涘牏鏁ら幋宄扮暰鐠嬪啨鈧?*瑜拌绨抽悡褎鎯夐崥?*閵? 娣囶喕琚遍弶鈥崇杽濞村绱氶敍?
          //   **鐏忓搫顕?娴ｅ秶鐤?閸﹀棜顫楁稉鈧瀣絿 `lyricMorph(t)`閿? 閺冪姷鏅?`CoverMorph` 閻ㄥ嫯绶崙鐚寸礆閿?
          //   娑撳秴浠涙禒璁崇秿閸ф劖鐖ｇ化缁樺床缁?*閿涘潉coverLocalRect()` 閻滄澘婀亸杈ㄦЦ `lyricFloatRect()` 閻ㄥ嫮娲块柅姘剧礆閵?
          //
          //   閳跨媴绗?閹存垳绗傛稉鈧悧鍫濇躬鏉╂瑩鍣烽崝鐘虹箖娑撯偓濞?鐏炲繐绠烽崸鎰垼 閳?鐎圭懓娅掗張顒€婀撮崸鎰垼"閻?*闁棗褰夐幑?*
          //     閿涘牆浜ｇ拋?`.scale()` 缂佹洖顔愰崳銊よ厬韫囧喛绱氶敍宀€婀￠張铏圭波閺嬫粍妲?*鐏忎線娼版鐐插毉鐏炲繐绠?*閵?
          //     閺堫兛绮ㄧ€电绻栭弶鈥充海鐠?*閺冣晜婀侀崣宥堢槈**閿涘潉morphCoverRectAt()` 閻ㄥ嫭鏁為柌?+ 閺堫剙鐪版い鍫曞劥
          //     "閳跨媴绗?2026-10-15 閸掔粯鍓版稉宥嗘暭"闁絼绔村▓纰夌窗閵嗗矂鈧棗褰夐幑?閳?閻喐婧€缂佹挻鐏夌亸渚€娼扮捄鎴濆煂瀹革缚绗傜憴鎺炵礉
          //     鐠囧瓨妲?`.scale()` 閻ㄥ嫭鐏戞潪缈犵瑝閺勵垱鍨滄禒銉よ礋閻ㄥ嫬顔愰崳銊よ厬韫囧啨鈧稄绱氶埇?**瀹告彃鐣弫瀛樻寵閸?*閵?
          //     娑撹桨绮堟稊鍫濈秼閺冨墎娈戠紒鎾诡啈閺?娣囨繃瀵旈悳鎵Ц"閿涙艾鐣犻搹鐣屽姧"閽€鎴掔秴閺冭埖顒滅涵顔衡偓浣歌埌閸欐ü鑵戦崑?閿?
          //     娴ｅ棗鐨濋棃銏℃Ц**鐠虹喓娼冪€圭懓娅掓稉鈧挧椋庣級**閻ㄥ嫸绱欑憴鍌涘妳濮濓絿鈥橀敍澶涚礉閼板矂鈧棗褰夐幑顫窗閻╁瓨甯撮幎濠傜暊閻⑩晛鍤仦蹇撶閵?
          //   閹烘帗鐓￠崗鎶芥暛鐎涙绱癭hdc shell hilog -x | Select-String 'RzdCoverLocal'`
          .width(this.coverLocalRect().size)
          .height(this.coverLocalRect().height)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.coverLocalRect().radius)
          .clip(true)
          // `.position()` 閺?*閻╃顕悥鍓佺矋娴犺泛鍞寸€瑰湱娲?*閻ㄥ嫮绮风€电懓鐣炬担宥忕幢閺堫剙鐪扮€瑰じ瀵岄惃鍕敶鐎瑰湱娲呭锔跨瑐鐟?
          // = 缁愭褰涢崢鐔哄仯閿涘牆澧犻幓鎰ㄦ喖閿涘矁顫嗛張顒€鐪版い鍫曞劥閿涘鍣?缁愭褰涢崸鎰垼閸欘垯浜掗惄瀛樺复閸愭瑣鈧?
          .position({ x: this.coverLocalRect().x, y: this.coverLocalRect().y })
          // 閳藉應妲?2026-10-15閿涘牅鎱ㄩ悽銊﹀煕鐎圭偞绁撮妴?*閸斻劎鏁炬稉顓⑩偓鏂剧窗閸戣櫣骞囨稉銈勯嚋鐏忎線娼?*閵嗗稄绱氶敍?*鐏忎線娼版潻娆忕炊韫囧懘銆忛幐?
          //   `realCoverVisible()` 闁綁浜鹃梻?* 閳ユ柡鈧?鐎瑰啩绗屾竟鍐茬湴閸忓娈曠仦鍌滄畱 `morphOverlayBridging()` 閺?
          //   **娑撱儲鐗告禍鎺曀?*閻ㄥ嫪绔寸€电櫢绱欓張顒佹瀮娴?L2665 闁絽褰炲▔銊╁櫞閸愭瑧娈戠亸杈ㄦЦ鏉╂瑤娆㈡禍瀣剁礆閿?
          //     璺?瑜般垹褰夋稉顓ㄧ礄`morphContainerActive()`閿涙NTERING/LEAVING/LANDING閿涘鍣?閺堫剙绱?*娑撳秶鏁?*閿?
          //       鐏炲繋绗傞柇锝呯炊閻㈠崬锛撶仦鍌氬帬闂呭棗鐪伴敍鍧凪orphCoverClone`閿涘鍞悰顭掔幢
          //     璺?閽€鎴掔秴閸氬函绱檚tage = OPEN閿涘鍣?閺堫剙绱?*閻?*閿涘苯鍘犻梾鍡楃湴閸氬本妞傞弨璺轰紣閵?
          //   閳跨媴绗?閹存垵甯弶?*濠曞繋绨℃潻娆撲壕闂?* 閳?瑜般垹褰夐張鐔兼？"閸忓娈曠仦鍌炲亝瀵娀顥ｇ悰宀€娈戠亸渚€娼?娑?妞ょ敻娼版潻娆忕炊閽€鎴掔秴閻ㄥ嫬鐨濋棃?
          //      **閸氬本妞傞崷銊ф暰** 閳?閻劍鍩涢幋顏勬禈闁插瞼娈戞稉鈧鐘插磹/娑撱倕绱剁亸渚€娼伴妴?
          //   閳跨媴绗?鏉╂瑦娼崷?`MusicPlayInfoBlock`閿涘牆顔旂仦?/ 闂堛垺婢橀柇锝勮⒈閺€顖ょ礆**娑撯偓閻╂挳鍏橀張?*
          //      閿涘湢357 / L510閿涙瓪.opacity(this.expandState.realCoverVisible() ? 1 : 0)`閿涘鈧柡鈧?
          //      閸欘亝婀侀幍瀣簚鏉╂瑤绔撮弨顖滄畱濞搭喖鐪板蹇庣啊 閳?閸欏牅绔存笟瀣ㄢ偓?*閸氬奔绔磋ぐ銏㈠Ц N 婢跺嫨鈧礁褰ч弨閫涚啊娑撯偓婢?*閵嗗稄绱欑粭?4 濞嗏槄绱氶妴?
          //   閳跨媴绗?娑撳﹥濮ら柦鈺佺摍閿涘潉.id` / `onAreaChange`閿?*娑撳秴褰?opacity 瑜板崬鎼?*閿涘瞼鍙庣敮鎼佸櫤瀵版鍩?閴佹挶鈧?
          .opacity(this.expandState.realCoverVisible() ? 1 : 0)
          // 閳?娑撳﹥濮ら柦鈺佺摍閹碱剙鍩屾潻娆撳櫡閿涘牊妫ら悾灞肩瘍閺勵垵顩惄鏍х湴閼奉亜绻佹稉濠冨Г閿涙瓪floatingCover.onAreaChange 閳?publishMorphTargets`閿?
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

        // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*娑撯偓濡亣顢?*閿涘奔绗夐崘宥嗘Ц鐏炲懍鑵戠粩鏍ㄥ笓閵?
        //   鐎佃鐖?`PlayerPage鐎瑰本鏆I鐎规氨顭?md` 鎼?.1 `floatingMeta` + 鎼?.2 `metaRow`閿?
        //     璺?鐏忓繐鐨濋棃銏犳躬**瀹?*閿涘牆姘ㄩ弰顖欑瑐闂堛垽鍋呭?`Image`閿涘瞼鏁?`lyricFloatRect()` 閽€鎴掔秴閸掔増鐡曠拠宥夈€夌粩顖滃仯閿涘绱?
        //     璺?濮濆苯鎮?濮濆本澧滈崷銊ョ暊**閸欏疇绔熼妴浣镐箯鐎靛綊缍?*閿涘潉metaRow` 闁插矂鍋呮稉鈧崚妤佹Ц `layoutWeight(1)` +
        //       `alignItems(HorizontalAlign.Start)`閿涘绱?
        //     璺?閸欏厖鏅堕悾娆戠舶閺€鎯版/閺囨潙顦块敍鍫熸￥閻ｅ本妲?`SymbolGlyph 閺€鎯版` + `SymbolGlyph 閺囨潙顦縛閿涘鈧?
        //   閳跨媴绗?閸樼喐娼垫潻娆撳櫡閺?`textAlign(Center)` + 閺佹潙娼″鏉戦挬鐏炲懍鑵?閳?鐏忚鲸妲搁悽銊﹀煕閹搭亜娴橀柌?
        //      "濞查箖鐓剁仦鍛厬婢堆冪殱闂?/ 閺冪姷鏅亸蹇撶殱闂堛垽娼? 閻ㄥ嫰鍋呴弶鈥虫▕瀵倶鈧?
        //   閳跨媴绗?鐏忎線娼扮拋鈺€缍呴悽?`padding.left` 鐞涖劏鎻敍? 鐏忎線娼伴崣宕囩喘 + 12閿涘绱?
        //      娑撳孩妫ら悾宀勬浆 `floatingCover`/`metaRow` 娑撱倕鐪板Ο顏勬倻闁挎瑤缍呮潏鎯у煂閻ㄥ嫮绮ㄩ弸婊呯搼娴犳灚鈧礁鐨稉鈧仦鍌樷偓?
        //
        // 閳藉應妲勯埥鍛 2026-10-17閿?*閻撗勬儔閺冪姷鏅?`floatingMeta` 閻ㄥ嫪琚辩仦鍌氳埌閻?* 閳ユ柡鈧?娴ｅ秷绻嶇粻妤冮獓閸氬本鐎敍?
        // ```
        //   婢舵牕鐪?Column().width('100%').height(overlayBaseH())
        //                .justifyContent(FlexAlign.Center)        閳?閸欘亣绀嬬拹?缁旀牜娲跨仦鍛厬"
        //                .hitTestBehavior(HitTestMode.Transparent)
        //     閸愬懎鐪?Column().width('100%').alignItems(HorizontalAlign.Start)
        //                  .offset({ y: metaOffsetYAt(swiperProgress) })   閳?閸欘亣绀嬬拹?閻╃顕仦鍛厬閻ㄥ嫪缍呯粔?
        // ```
        // 閿涘潉wujie.pa:195907-196008`閿涘鍣?閹存垳婊戦悡褍鎮撴稉鈧ぐ銏㈠Ц閹藉棴绱版径鏍х湴缂?*閸╁搫鍣惄?*閿涘潉estBoxHVp()`閿?
        //   娑?`overlayBaseH()` 閸氬奔绠熼敍姘讲閻劑鐝?閳?閹貉冨煑閸栫尨绱氶敍灞藉敶鐏炲倻鏁?`.offset()` 鐠т即鍋呴弶?lerp閵?
        // 閳跨媴绗?閸戠姳缍嶆稉濠佺瑢娑撳﹣绔撮悧鍫㈡畱 `.position({y: metaTopGeomY(...)})` **闁劕鍎氱槐鐘电搼娴?*
        //   閿涘潉metaOffsetY()` 闁插苯鍑＄紒蹇斿Ω"鐏炲懍鑵戞担宥囩枂"閸戝繑甯€娴滃棴绱氶敍灞惧床閻ㄥ嫬褰ч弰?*缂佹挻鐎稉搴″經瀵?*閿?
        //   娴犲孩顒濇担宥囆╅弰?閻╃顕崺鍝勫櫙閻╂帊鑵戣箛鍐畱閸嬪繒些"閿涘苯鎷伴弮鐘垫櫕閸氬奔绔存稉顏堝櫤缁捐绱濇稉瀣╃濮濄儴鐨熼崣鍌欑瑝閻劌鍟€鏉╂柨浼愰妴?
        Column() {
          Column() {
            Row() {
          Column() {
            Text(this.state.getCurrentSongItem()?.title ?? '', { controller: this.titleController })
              // 閳?缁旑垳鍋ｆ稉濠冨Г閿涘牆甯?`MusicPlayInfoBlock` 閻ㄥ嫯浜寸拹锝忕礆閳ユ柡鈧?鐟?`publishMetaEndpoint`
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
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 閳?閺冪姷鏅?`metaRow` 閸欏厖鏅堕柇锝勮⒈娑擃亜娴橀弽鍥风礄`PlayerPage鐎瑰本鏆I鐎规氨顭?md` 鎼?.2閿涘绱?
          //   `SymbolGlyph 閺€鎯版` + `SymbolGlyph 閺囨潙顦縛閵?
          //   閺€鎯版閹?`MusicStoreService`閿涘牅绗?`MusicPlayInfoBlock` 閸氬奔绔存總妤勵嚢閸愭瑱绱氶敍?
          //   閺囨潙顦块幍鎾崇磻濮濆本娲搁懣婊冨礋 閳ユ柡鈧?闁絼閲?sheet 閻?`ControlAreaComponent` 閻紮绱?
          //   閻樿埖鈧礁鍑￠幓鎰磳閸掔増婀版い纰夌礄`playMenuOpen`閿涘绱濈憴渚€鍋呴柌宀€娈?`@Param`/`@Event` 鐠囧瓨妲戦妴?
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
        // 閳藉應妲?2026-10-15閿涘牅鎱ㄩ崶鐐茬秺閿涘绱扮悰宀勭彯**韫囧懘銆忛悽銊ㄥ殰闊偉鍤滈悞鍫曠彯鎼?*閿涘牃澧?4vp閿涘绱?
        //   **娑撳秷鍏?*閻?`this.lyricFloatRect().size` 閳ユ柡鈧?闁絼閲滈崐鐓庢躬 `t = 0`閿涘牆鐨濋棃銏ゃ€夐敍澶嬫閺?
        //   **婢堆冪殱闂堛垼绔熼梹鍖＄礄328vp閿?*閿涘矂鍘ゆ稉?`VerticalAlign.Center` 娴兼碍濡告稉銈堫攽閺傚洤鐡ч幒銊ュ煂鏉╂瑤绔寸敮锔炬畱娑擃參妫?
        //   閳?**鐏忎線娼版い鐢垫畱濮濆苯鎮曠悮顐㈢窔娑撳甯圭痪?164vp**閿涘牐鎯ら崚鏉跨潌楠炴洖绨抽柈銊ｂ偓浣稿竾閸︺劍甯堕崚璺哄隘娑撳绱氶妴?
        .height(PlaybackPage.LYRIC_META_ROW_H_VP)
        .alignItems(VerticalAlign.Center)
        .padding({
          left: this.lyricMetaLeftInset(),
          right: PlaybackPage.LYRIC_META_SIDE_VP
        })
        // 閳藉應妲勯埥鍛 2026-10-17閿?*閻撗勬儔閺冪姷鏅惃鍕秴缁夎鍙曞蹇旀拱娴?* 閳ユ柡鈧?閸掔姵甯€閺堫兛绮ㄩ懛顏勭暰閻ㄥ嫰鍋呴崡濠冩蒋瀵繐鐡欓敍?
        //
        // 閸樼喐娼垫潻娆撳櫡閺勵垽绱?
        // ```
        //   y: lyricMetaMorphY(t) + t 鑴?(lyricFloatRect().size 閳?LYRIC_META_ROW_H_VP) / 2
        // ```
        // 娑撱倓閲滈梻顕€顣介敍鍫ュ厴閸?鎼?30/鎼?31 闁插瞼绮版禍鍡楀毉婢跺嫸绱氶敍?
        //   閳?`lyricMetaMorphY` 閻?`from` 缁旑垳鍋ｉ悽銊ф畱閺勵垱婀版禒鎾瑰殰鐎规氨娈?`LYRIC_META_GAP_VP = 10`
        //      閿涘牓鍋呮稉顏勭埗闁插繒娈戝▔銊╁櫞閼奉亜绻侀崘娆戞絻閵嗗本婀版い鍦窗娴兼澘鐣鹃崐纭风礉闂堢偤鈧棗鎮滈崐绗衡偓宥忕礆閿?
        //      閼板本妫ら悾?`fitPlayerOverlay` 閻?gap 閺?*绾剛绱惍?50** 閳ユ柡鈧?
        //      鐎瑰啰顑?6 娑擃亜鐤勯崣?`chrome().metaGap` **鐞氼偂娑?*閿涘潉refitOverlay` 娴?6 娑擃亗鈧?
        //      `fitPlayerOverlay` 閸欘亝鏁?5 娑擃亷绱氶埇?闁絼閲?10 閺勵垱濡?鐞氼偂娑鍐畱閸欏倹鏆?瑜版挻鍨氭禍鍡欐埂閸婄鈧?
        //   閳?`to` 缁旑垳鍋ｉ悽銊ф畱閺?鐏忓繐鐨濋棃銏ゃ€婃潏?閿涘苯鐨幒?`metaTopFixLyric`閿?
        //      閼?`t 鑴?(size 閳?rowH)/2` 闁絼閲?鐏炲懍鑵戠悰銉ヤ缉"閸欏牊妲搁張顑跨波閼奉亜鍨遍惃鍕儑娑撳銆嶉妴?
        // 閳?閻滄澘婀惄瀛樺复鐠?*娑撯偓娑?*閺堝鍤径鍕畱閸戣姤鏆熼敍鍧刴etaTopGeomY`閿涘奔琚辩粩顖滃仯闁劕鐡ч弶銉ㄥ殰
        //   `CoverMorph.metaOffsetYAt` + `fitPlayerOverlay`閿涘绱濋張顒冾攽娑撳秴鍟€閺堝鎹㈡担鏇″殰缂傛牠銆嶉妴?
        //
        // 閳藉應妲勯埥鍛 2026-10-17閿涙矮缍呯粔?*娴?`.position()` 閹割亜鍩屾径鏍х湴闁絼閲?`Column` 閻?`.offset()`**
        //   閿? 閺冪姷鏅?`floatingMeta` 閻ㄥ嫬鑸伴悩璁圭礉鐟欎椒绗傞棃銏″絻鏉╂稒娼甸惃鍕亝娑撱倕鐪伴敍澶堚偓?
        //   `metaOffsetY()` = `metaTopGeomY(t, rowH) 閳?(閸╁搫鍣惄鎺楃彯 閳?rowH)/2`
        //   閳?娑撳骸甯弶銉╁亝閺?`.position({ y: 閳?})` **闁劕鍎氱槐鐘电搼娴?*閿涘苯褰ч幑銏犲經瀵板嫨鈧?
        //   閳跨媴绗?閸樼喐娼?`.position` 闁插矂鍋呭▓?缁愭褰?閳?妞ら潧鍞撮幑銏㈢暬閿涘潉metaTopLocalY`閿?閻ㄥ嫭鏆€鐠侇厺绮涢悞鑸垫箒閺佸牞绱?
        //     `metaTopGeomY` 閻ㄥ嫪琚辨稉顏嗩伂閻?*閺堫剚娼电亸杈ㄦЦ閽€钘夌暰閹礁鍤戞担?*閿涘牆顔愰崳銊︿航缁涘妞傜粻妤€鍤弶銉ф畱閸婄》绱?
        //     閳?**瀹歌尙绮￠弰顖炪€夐崘鍛綏閺嶅浄绱濇稉宥堫啅閸愬秳绠?`1/morphScale`**閿涘牅绠绘禍鍡楁皑娴?閸忓牓顥ｉ崚鏉跨殱闂堫潿鈧礁鍟€娑撳娼?閿涘鈧?

        // 閳藉應妲?2026-10-15閿涘牅鎱ㄩ悽銊﹀煕鐎圭偞绁撮妴?*閸斻劎鏁炬稉顓⑩偓鏂剧窗閸戣櫣骞囨稉銈勯嚋濮濆苯鎮曞灞惧**閿涘牊婀佹稉鈧稉顏呮Ц濞堝鏆€閻ㄥ嫨鈧?
        //   娴犮儱澧犲ú楣冪叾閻劎娈戝灞芥倳濮濆本澧滄鐐插弳閿涘鈧稄绱氶敍?
        //   **鏉╂瑤绔寸悰灞藉斧閺夈儲妲搁崘娆愵劥閻?`.opacity(1)`**閿涘牊鏁為柌濠勬倞閻㈣鲸妲?鐢悂鈹?閳?閹帒褰茬憴渚婄窗鐏忎線娼版い鐢稿亝娴犺姤鐡曢崥?
        //   閸樼喐娼甸悽?`MusicPlayInfoBlock` 閻紮绱濈€瑰啫鍑℃禒搴ㄣ€?0 缁夊娅?閿涘鈧柡鈧?闁絼閲滈悶鍡欐暠**閸欘亜顕棃娆愵剾閹焦鍨氱粩?*閿?
        //   鐎瑰啯濡告稉搴″帬闂呭棗鐪伴惃?*娴滄帗鏋奸梻銊ょ鐠ч攱濯堕幒澶夌啊**閿涙艾鑸伴崣妯绘埂闂傛潙锛撶仦?`MorphMetaBridge`
        //   閿涘牆姘ㄩ弰顖滄暏閹寸柉顕╅惃?娴犮儱澧犲ú楣冪叾閻劎娈戝灞芥倳濮濆本澧滄鐐插弳"閿涘婀悽濠氼棧鐞涘奔鑵戦惃鍕摃閸氬稄绱濋懓灞炬拱鐞?*閸氬本妞傞崣鍫濆弿娴?*
        //   閳?**娑撱倕顨滃灞芥倳閸氬本妞傞崷銊ユ簚**閵?
        //   閳?閹广垺鍨氶弮鐘垫櫕闁綁浜鹃梻?`targetMetaOpacity()`閿涘潉PlayerExpandState` L1325-1335閿涘绱?
        //     璺?stage = OPEN 閳?**1**閿涘牐鎯ゆ担宥呮倵閹帒褰茬憴渚婄礉鐟曞棛娲?鐏忎線娼版い鐢稿亝娴犺姤鐡曢崥?閻ㄥ嫯浜寸拹?閴佹搫绱氶敍?
        //     璺?瑜般垹褰夋稉顓濈瑬閸忓娈曠仦鍌涘复缁犫槄绱檂metaBridgeOwnsPaint()`閿涘鍣?**0**閿涘牅姘﹀Λ鎺旂舶閸忓娈曠仦鍌︾礆閿?
        //     璺?瑜般垹褰夋稉顓濈稻閸忓娈曠仦鍌涚梾閹恒儳顓?閳?闁偓閸?`pullChromeOpacity()` 闁絾娼ǎ鈥冲弳閺囪尙鍤庨妴?
        //   閳跨媴绗?`MusicPlayInfoBlock`閿涘牆顔旂仦?/ 闂堛垺婢橀柇锝勮⒈閺€顖ょ礆**娑撯偓閻╁鏁ら惃鍕皑閺勵垰鐣?*閿涘湢239 / L411 / L447閿?
        //      閳?閸氬奔绗傛稉鈧径鍕閺嶅嚖绱濋崣鍫熸Ц閵嗗苯鎮撴稉鈧ぐ銏㈠Ц N 婢跺嫨鈧礁褰ч弨閫涚啊娑撯偓婢跺嫨鈧秵绱￠幒澶屾畱闁絼绔存径鍕┾偓?
        .opacity(this.expandState.targetMetaOpacity())
        // 閳藉應妲勯埥鍛 2026-10-17閿?*閸掔姵甯€鏉╂瑩鍣烽柇锝嗘蒋閼奉亞绱惃?180vp 娴ｅ秶些** 閳ユ柡鈧?goal 缁?1 閺夛紕娈戝锝夋桨鐟曚焦鐪伴敍?
        //
        // 娑撳﹣绔撮悧鍫ｇ箹闁插本妲?`.translate({ y: this.expandState.metaRiseVp() })`閿?
        // `metaRiseVp() = (1 閳?ramp01(p, 0.18, 0.62)) 鑴?**RISE_VP(180)** / morphScale`
        // 閳ユ柡鈧?闁絼閲?**180 閺勵垱婀版禒鎾瑰殰鐎规艾鈧鈧焦鐥呴張澶夋崲娴ｆ洖鍤径?*閿涘潉RISE_VP` 閻ㄥ嫭鏁為柌濠呭殰瀹稿崬鍟撻惈鈧?鐏炲繐绠烽柌?閿涘鈧?
        //
        // 閺冪姷鏅潻娆庣鐞涘瞼娈戞担宥囆?*閸欘亝婀佹稉鈧弶?*閿涘苯姘ㄩ弰顖欑瑐闂堛垽鍋呴弶?`.position()` 闁插瞼娈?
        // ```
        //   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
        // ```
        // 閿涘潉CoverMorph.ets:205-211`閿涘鈧柡鈧?**lerp 閺堫剝闊╃亸杈ㄦЦ闁絾娼?妞嬬偘绗傞弶?**閿?
        // t=0 閸?婢堆冪殱闂堛垹绨虫潏?+ 50"閿涘=1 閸?鐏忓繐鐨濋棃銏㈢彨閻╃繝鑵戣箛?閿涘潉topYAtLyric + 28`閿?
        // 鐟?`META_TOP_FIX_LYRIC_VP`閿涘绱?*閸忋劏顢戠粙瀣暠 t 妞瑰崬濮?*閿涘奔绗夐棁鈧憰浣稿晙閸欑姳绔撮弶锛勭崶閸愬懍缍呯粔姹団偓?
        //
        // 閳?閸掔姵甯€鐎瑰啩绠ｉ崥搴窗
        //   璺?閺傚洤鐡ф稉搴濊⒈娑擃亜娴橀弽?*閸氬苯顦╂潻娆庣鐞?* 閳?娓氭繄鍔?娑撯偓鐠х兘顥ｆ稉濠冩降"閿涘牅缍呯純?lerp 閸氬本绨敍澶涚幢
        //   璺?濞ｂ€冲弳娴犲秵瀵?`targetMetaOpacity()`閿涘牆鍞撮崥?`pullChromeOpacity` 閻?0.18閳?.62 缁愭褰涢敍?
        //     闁絾妲搁悽銊﹀煕瀹歌尙鈥樼拋銈囨畱 閳额澁绱氶敍?
        //   璺?娑撳孩妫ら悾?*閸欘亜妯?鏉╂稑瀹冲┃?**閿涙碍鍨滄禒顒傛暏 `lyricMorphT`閿涘本妫ら悾宀€鏁?`swiperProgress` 閳ユ柡鈧?
        //     鏉╂瑦顒滈弰顖氱獦閺嶅洨顑囬崗顓☆攽 `metaD`閿涘牐顓瑰锝呮倵閿涘顩﹂柌蹇曟畱娑撴粏銈块妴?
        //
        // 閳跨媴绗?`earlyRiseVp()` / `contentRiseVp()`閿涘牆鐨宀冪槤缂?/ 閹貉冨煑閸栬櫣绮嶉敍?*閺堫剚顐兼稉宥呭З**閿?
        //   goal 缁?1 閺夆€冲涧閻愰€涚啊閸忓啩淇婇幁顖濐攽閿涙盯鍋呮稉銈囩矋閺?閹貉冨煑閸栬桨绮犳稉瀣磳娑撳﹥娼?閿涘瞼鏁ら幋宄板嚒绾喛顓婚惃?
        //   閳?鐠囧娈戠亸杈ㄦЦ鐎瑰啩婊戦柇锝咁殰閺冨爼妫跨粣妤嬬礄`pullChromeOpacity` 0.18閳?.62 / `pullBottomIn` 0.45閳?.00閿涘鈧?
        //   鐎瑰啩婊戦崥灞剧壉閸欑姳绨℃稉鈧弶?180vp 閳ユ柡鈧?鐟曚椒绗夌憰浣风鐠у嘲骞撻幒澶涚礉缁涘绻栧▎陇顫囬幇鐔峰冀妫ｅ牆鍟€鐎规熬绱欑憴?鎼?30閿涘鈧?
          }
          .width(StyleConstants.FULL_WIDTH)
          .alignItems(HorizontalAlign.Start)
          .offset({ y: this.metaOffsetY() })
          // 鈽呪槄鈽呪槄 2026-10-17锛?*鎭㈠"浠庝笅闈㈠崌涓婃潵"** 鈥斺€?鐢ㄦ埛瀹炴祴
          //   銆? 鏀圭殑涓嶅锛屾甯告瓕鎵嬪簲璇ヤ粠涓嬮潰鍑烘潵銆備綘鐪嬬湅鏃犵晫銆嶏級
          //   鎴戜笂涓€鐗堝彧鍋氫簡"鍒帇杩涙帶鍒跺尯"鐨勯挸鍒讹紝鍗存妸杩欎竴琛岀殑**鍗囧叆浣嶇Щ**涓㈡帀浜?
          //   鈬?瀹冧粠绗竴甯у氨閽夊湪钀界偣銆佸彧鏄贰鍏?鈬?瑙傛劅涓庢棤鐣屽畬鍏ㄤ笉鍚屻€?
          //   鏃犵晫閭ｄ竴琛屾槸**璺熺潃鍐呭涓€璧蜂粠涓嬪線涓婇**鐨勶紙鏃堕棿绐?`WIN_META 0.18鈫?.62`锛?
          //   涓?`pullChromeOpacity` 鍚屼竴涓尯闂达紝涓よ€呭悓璧峰悓钀斤級銆?
          //   鈬?鐢ㄥ洖妯″瀷閲岀幇鎴愮殑 `metaRiseVp()`锛坄(1 鈭?ramp01(p,0.18,0.62)) 脳 RISE_VP / scale`锛?
          //     闈欐鎬佹亽 0锛夈€傚畠涓庝笂闈㈢殑閽冲埗鏄袱浠朵簨锛?*鍗囧叆**鏄椂闂翠笂鐨勶紝
          //     **閽冲埗**鍙喅瀹氳惤鐐癸紝涓嶈鎶婅惤鐐瑰帇杩涙帶鍒跺尯銆?
          .translate({ y: this.expandState.metaRiseVp() })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(this.expandState.estBoxHVp())
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 閳藉應妲?2026-10-15閿涘牅鎱ㄩ敍澶涚窗鏉╂瑩鍣烽崢鐔告降閺?`HitTestMode.None` 閳ユ柡鈧?闁絾妲?**閼奉亜绻侀崪灞界摍閼哄倻鍋ｉ柈鎴掔瑝閸濆秴绨茬憴锔芥嚋**"閿?
      //   娴兼碍濡搁柇锝勭鐞涘苯褰告笟褏娈?*韫囧啫鑸?/ 閺囨潙顦挎稉銈勯嚋閹稿鎸抽惃鍕仯閸戣绔寸挧宄版倖閹?*閿涘牆姘ㄩ弰顖涙拱閸ф鍨伴崝鐘垫畱闁絼琚辨稉顏庣礆閵?
      //   閺冪姷鏅径鏍х湴閻劎娈戦弰?`HitTestMode.Transparent`閿涘潉floatingCover` / `floatingMeta` 閻?
      //   濠娾€崇潌鐎圭懓娅掗柈鑺ユЦ鐎瑰喛绱氶敍?*缁岃櫣娅ф径鍕敍闁繐鍩屾稉瀣湴閵嗕礁鐡欓懞鍌滃仯閻撗冪埗閸欘垳鍋?* 閳?鏉╂瑩鍣烽弨瑙勫灇閸氬奔绔存稉顏傗偓?
      //   閳跨媴绗?鐏忎線娼伴柇锝呯炊閸ユ崘鍤滃鍙樼矝閻掕埖妲?`None`閿涘牅绗傛稉鈧仦鍌滄畱 `Column`閿涘绱濋幍鈧禒銉ョ暊娑撳秳绱伴幐鈥茬秶濠婃垵濮╅妴?
      .hitTestBehavior(HitTestMode.Transparent)
    }
}

/*
 * 閳跨媴绗?閹绢厽鏂佹い鐐光偓灞肩闂€婊冨煂鎼存洏鈧秴鐫嶅鈧崝銊ф暰閻ㄥ嫬宸婚崣璇х礄2026-09-22 / 09-25閿涘鈧柡鈧柨鍟€閸斻劍澧滈崜宥呭帥鐠囪鐣妴?
 *
 * 缁楊兛绔撮悧鍫礄瀹告彃绨惧鍐跨礆閻?path 鐟佷礁澹€閹跺﹥鏆ｆい浣冾梿閹存劘绯犳担鐘虫蒋闁絼绠炴径褏娈戠亸蹇曠崶閸欙絽鍟€闁劕鎶氶梹鍨亣閿涘奔琚辨稉?API 闁棄娼栭敍?
 *   1. `clipShape(new PathShape({ commands }))` 閳ユ柡鈧?閹绢厽鏂佹い鍨殻娑擃亙绗夐弰鍓с仛閿涘牐銆冮悳棰佽礋閹垫挷绗夊鈧敍澶涚幢
 *   2. `clip(new Path({ commands }))` 閳ユ柡鈧?閻愮懓鍤幘顓熸杹閸ｃ劎娲块幒銉ュ幢濮濇眹鈧?
 *
 * 閻滄澘婀潻娆戝閿涘牆顕弽鍥ㄦ￥閻ｅ矂鐓舵稊?`ExpandAnimation` + `CoverMorph`閿?*閸欘垳鏁?*閿涘绱?
 *   1. **閺佹挳銆夌紓鈺傛杹 + 缁旀牜娲跨憗浣稿缁愭褰?*閿涙瓪height / scale / translate / clipShape / opacity`
 *      娴滄柧閲滅仦鐐粹偓褝绱濊ぐ銏㈠Ц閸欘亞鏁?*閸﹀棜顫楅惌鈺佽埌**閿涘潉RectShape`閿涘奔绗夐弰?path閿涘鈧柡鈧?
 *      鐟?`PlayerExpandState.applyMorphProgress`閿?
 *   2. **濡椼儲甯寸亸渚€娼?*閿涙艾鑸伴崣妯绘－閺堢喎宕熼悪顒傛暰娑撯偓瀵姴鐨濋棃顫礉娴犲氦绯犳担鐘虫蒋鐏忎線娼扮紒顓炲煂閹绢厽鏂佹い闈涚殱闂?
 *      閿涘牐顫?`MorphCoverBridge` / `PlayerExpandState.morphCoverBridge`閿涘鈧?
 *
 * 鐎瑰啰娈戦崶娑楅嚋韫囧懓顩﹂弶鈥叉閿涘牏宸辨稉鈧稉顏勬皑娴兼岸鈧偓閸栨牗鍨?姒涙垵绨?+ 娑撳鏌熺粚铏规 + 娑撯偓閸ф绻庡锝嗘煙瑜?閿涘绱?
 *   1. **閹绢厽鏂佹い鍏哥瑢妫ｆ牠銆夎箛鍛淬€忛崷銊ユ倱娑撯偓濡絻顫嬮崶鐐埐闁?*閿涙艾鑸伴崣妯绘－閺堢喎褰茬憴鍡欑叐瑜般垹褰ч張澶庣碃娴ｇ姵娼亸渚€娼伴柇锝勭疄婢堆嶇礉
 *      閸忔湹缍戦柈銊ュ瀻閺勵垶鈧繑妲戦惃鍕剁礉鐟曚線鈧繐鍤稉瀣桨閻ㄥ嫰顩绘い鍏哥瑢鏉╄渹缍橀弶?閳ユ柡鈧?閻?`bindContentCover` 濡剝鈧椒绗夌悰宀嬬礉
 *      濡剝鈧礁顔栨稉缁樻Ц娑撳秹鈧繑妲戦惃鍕鐏炲偊绱濋幎濠囶浕妞ら潧鎷版潻铚傜稑閺夆€冲弿閻╂牔缍囨禍鍡愨偓?
 *   2. **"闁剧儤寮?閻ㄥ嫮娲伴弽鍥彯鎼达箑绻€妞ょ粯妲搁幁鎺嶈礋濠娾€崇潌閻ㄥ嫬顔栨稉璇差啇閸ｃ劌鐤勫ù瀣毉閺夈儳娈?*閿涙碍瀵曢崷銊潶瑜般垹褰夐惃鍕亝鐏炲倷绗傛导姘冲殰閸?
 *      閿涘牓鍋呯仦鍌炵彯鎼达箑姘ㄩ弰顖濐梿閸擃亞鐛ラ崣锝忕礆閿涘矁顫?`PlayerExpandState.reportHost`閵?
 *   3. **閸欘垵顫嬮惌鈺佽埌閻ㄥ嫬娲撻弶陇绔熼崥鍕殰閹绘帒鈧?*閿涘奔绗?*娑撳绔熺憰浣瑰絹閸撳秷鍒涙惔?*閿涘牐绯犳担鐘虫蒋缁傝鐫嗛獮鏇炵俺鏉堢绻曢張澶婂殤閸?vp閿?
 *      鐠虹喓娼冪痪鎸庘偓褑铔嬮惃鍕樈閺佸瓨顔岄崝銊ф暰鎼存洟鍎撮柈鑺ユЦ缁岃櫣娈戦敍澶涚幢娴ｅ秶些= 閸欘垵顫嬪锔跨瑐鐟?閳?(鐢啫鐪埈鎺戝讲鐟?/2閿?
 *      娑撳秷鍏橀悡褎濡遍弮鐘垫櫕閻?閸掓繂顫愭担宥囆?鑴?(1-p)"閿涘牏缂夐弨鍙ヨ厬韫囧啯妲哥€圭懓娅掓稉顓炵妇閿涘苯鐖堕柌蹇毸夐崑澶歌厬濞堝吀绱版い璺哄毉鐏炲繐绠烽敍澶堚偓?
 *   4. **閸﹀棜顫楄箛鍛淬€忛悽?`clipShape` 鐟?*閿涙艾褰ч崘?`.borderRadius + .clip(true)` 閺冭绱?
 *      鐎圭懓娅掗懛顏囬煩濞屸剝婀侀懗灞炬珯閼?閳?閸﹀棜顫楁稉宥勭稊閻劌鍩岀€涙劘濡悙?閳?閸愬懎顔愮仦鍌欑濞搭喖鍤弶銉ユ皑閸欐ɑ鏌熼崸妞尖偓?
 *
 * 瀹歌尙绮℃穱婵堟殌閻ㄥ嫪绗㈢憲鍖＄礄闁棄婀?common/musicbasic閿涘绱?
 *   - `PlayerExpandState`閿涘牅琚辩粩顖氱殱闂堛垻娈戠粣妤€褰涢惌鈺佽埌 + 閻╅晲缍?+ 鐎圭懓娅掕ぐ銏犲綁閸戠姳缍嶉敍澶涚幢
 *   - `MINI_BAR_COVER_ID` / `PLAYER_BIG_COVER_ID` 娑撱倓閲滅紒鍕 id閿?
 *   - 鏉╄渹缍橀弶鈥崇殱闂堫澀绗岄幘顓熸杹妞ら潧銇囩亸渚€娼伴崥鍕殰 `onAreaChange` 娑撳﹥濮ょ粣妤€褰涢惌鈺佽埌閻ㄥ嫯鍏橀崝娑栤偓?
 */

/** Player content builder mounted by product shells as a full-screen overlay above the shell Stack. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  // **娑撳秶顫€瑰鍙忛崠?*閿涙岸鎽靛鈥叉唉缂佹瑥锛撶仦鍌滅舶閻ㄥ嫭璇炵仦鍌氼啇閸ｎ煉绱濇惔鏇㈠劥閻ｆ瑧娅ч悽?PlaybackPage 閸愬懘鍎撮幐?
  // navigationBarBottomVp 閼奉亜绻侀崝?padding閵嗗倸婀潻娆撳櫡閸?expandSafeArea / ignoreLayoutSafeArea
  // 娴兼艾鎷版径鏍э紦鐎圭懓娅掗崘鑼崐閿涘瞼鏆€閻ц棄寮介懓灞藉綁婢堆佲偓?
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
