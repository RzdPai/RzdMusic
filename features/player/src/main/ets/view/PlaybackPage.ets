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

// 闁宠法濯寸粭?`TextController` 闁?ArkUI 闁?*闁稿繈鍔岄惇顒勬偝椤栨凹鏆旂紒顐ヮ嚙閻?*闁挎稑鐗呯粭澶愭閳ь剛鎲?import闁挎稑鐣璏usicPlayInfoBlock` 闁告艾鏈娆撴晬?
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
  // 闁?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`BarCollapse`闁挎稑顧€缁变即骞掕閸╂寮堕埄鍐ㄧ彌闁告柣鍔嶉弫鍦導?閻忕偞娲栫槐鎴︽儍閸曨剙顤侀柛鏃囨硶婵悂骞€娴ｈ绨?
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
  // 闁?2026-10-15闁挎稑鐗愰々顐︽儎閺嵮呮勾缂備胶鍠嶇粩鎾晬婢舵稓绐楃紒鏃戝灣閸嬶綁鏌岃箛鏃傘偞闁汇劌瀚悥鍫曟煂韫囧海鐟㈢€规悶鍎遍崣鍧楁晬閸繂鏂ч柡澶堝劚瑜把囧捶?`MusicPlayInfoBlock` 闂佹彃鐬奸弫銈夋晬?
  PLAYER_BIG_COVER_ID,
  // 闁?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`PLAYER_ROOT_ID`闁挎稑顧€缁变即妫冮悙鏉戭杹闁告柨鐏濋崣褔姊婚鈽嗘矗闁瑰嘲绉撮幓鈺呮偂瑜忓▓鎴︽焽閿濆嫰鍤嬮柤鍝勫€婚崑锝夋晬? 鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞呮帡鏁?
  PLAYER_ROOT_ID,
  // 闁?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?ShrinkOverlay闁挎稑顧€缁变即妫冮悙鏉戭杹闁告柨鐏濋崣褔姊婚鐘崇暠闊浂鍋嗛崣搴ㄥ绩閸撲胶绱氭繛鎼枛閻?
  MorphShrinkState,
  type MorphShrinkRect,
  PLAYER_META_TITLE_ID,
  PLAYER_META_SINGER_ID,
  MorphMetaEndpoint,
  areaLengthToVp,
  PlaybackFlowLightState,
  PlaybackShellConstants,
  PlayerExpandState,
  // 闁?2026-10-16闁挎稒纰嶅﹢鐗堛亜闂堟稒韬?`.onDisAppear()` 闂佹彃鐭侀々锕傚礆?闁圭虎鍘介弬浣广亜娴ｅ啰鐔呴柣銏ｇ簿缁绘洟宕烽妸銈囩憹闁革负鍔嶉悥銈夋煂?闁挎稑鐗愰～?`playerRouteStillPushed`闁?
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
// 闁?缂傚啯鍨堕悧鎼佹嚄鐏炵偓鐝柣銊ュ瑜板洭宕堕悙顒傘偊婵ê顕崵搴ㄦ晬閸垹寮鹃柟纰卞墯濡倝鎮?`design/logic/MeshSource.ets`闁?
import { SRC_EDGE, enhanceColors, boxBlurRgba } from '../util/MeshSource';
// 闁宠法濯寸粭?闁归潧顑嗗┃鈧紒鎰閻棝鎯?*濡?0 鐎规瓕灏欑划鈩冪▔瀹ュ洦鏆忛悗鐟板暕缁?*闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨壆浜告笟鈧?婵繂鑻幃鏇㈠绩鐟欏嫬鐏?`Swiper` 濠㈣埖鐗滃▓鎴犳啺閸℃瑦纾伴悘鐐插亰缁辨岸鏁?
//    濞?*閻庣妫勯惈?/ 闂傚牄鍨哄妯兼暜閸愩劎婀伴梺顓ㄧ导鐞氶亶寮堕垾鍐茬€婚柡鈧娆戠煗闁革负鍔庨弫?*闁挎稑娼塎usicPlayInfoBlock` 闁?1817 / 2101 濞戞挶鍊曢ˇ鈺呮晬?
//    闁?import 濞戞挸绉烽崗姗€宕氶悩顔瑰亾閸岀偛浜濆☉鎾卞€栧顖炲礆閸℃ɑ鏆滈柣銊ュ缁儤绋夐埀顒勫及椤栨瑧鐟撳☉鎾亾闁秆勵殣缁辨瑩寮弶鎴犳綄閻忓繋绶氬鐗堛亜閸忓摜鐟㈤悷鏇炴濞插﹦浠﹂崒姘€ゆ鐐额啇缁辨岸濡?
import { MusicPlayInfoBlock } from './MusicPlayInfoBlock';
import { TopAreaComponent } from './TopAreaComponent';

/** Clamps a numeric RGB channel to an integer byte in [0, 255]. */
function clampRgbByte(n: number): number {
  if (!Number.isFinite(n)) {
    return 0;
  }
  return Math.max(0, Math.min(255, Math.floor(n)));
}

/** 濞戞挴鍋撴繛鍡忊偓宕囨闂傚牜婢€缁楀懏娼崐鐔滄帡宕欓搹瑙勭暠濞戞挶鍊曠槐鑸垫媴瀹ュ懏绂堥柨娑樼墣椤?`PlaybackPage.loadOnlineCoverPair`闁挎稑顦埀?*/
class CoverDecodePair {
  /** 闁稿繈鍔岄弰鍌溾偓鐢告交缁辨繃绗?`effectKit` 闁告瑦鐗炴竟濠囧Υ?*/
  full: image.PixelMap | undefined = undefined;
  /** 64閼?4闁靛棔闃淕BA_8888闁靛棔绀佽ぐ鑼磽閺嶎剛甯?闁炽儲鏌￠埀?缂傚啯鍨堕悧鎼佹嚄鐏炵偓鐝柣銊ュ缁噣濡?*/
  mesh: image.PixelMap | undefined = undefined;
}

/** Minimal shape for probing {@link image.PixelMap.release}; {@link Resource} does not carry this. */
interface PixelMapReleaseProbe {
  release?: () => void;
}

/** 濞戞挴鍋撻柛锕€鐗婄粊锕傚礂婢跺顦ч梻鈧崠锛勭ms闁挎稑顧€缁变即骞堥～顓狀伇闁绘劘顫夋晶鐘诲磽?闁告稓鍘ч幆?闁兼澘濂旂粭澶愬及椤栫偞锛忛柕?*/
const FLOW_LIGHT_DURATION_MS: number = 12000;
/** 婵炵繝绀侀崢婊呬沪閸屾稒娈诲ù锝嗘尫缁楀鏌呰箛鏃€顫栭幖杈捐缁辩増寰勯鍫㈠蒋濞村吋姘ㄥú濠冩媴韫囨挾娈遍梻鍫線缁楀苯顫㈠畝鍐Г闁?*/
const FLOW_LIGHT_OPACITY: number = 0.55;

/**
 * Full-screen playback page: layered background, breakpoint-specific layout, dismiss gestures,
 * and dynamic tint from album art.
 */
@ComponentV2
export struct PlaybackPage {
  /**
   * 濠㈢懓鍟块惇浼存儍閸曨喚鐔呴柣銏ｉ哺閻栥倝鏁嶉崸鍑dex.ets:237 @Provider('pageIndexInfos')` 闁圭粯鍔掔欢鐢告晬婢跺牃鍋?
   *
   * 闁?2026-10-16 闁哄倹婢橀·鍐晬?*闁哥儐鍨粩鎾偨閵娾斁鍋?*闁哄嫷鍨甸鈧柡鍫墴閵嗗宕?`.onDisAppear()` 闂佹彃鑻崹?
   * 闁靛棗鏈幐閬嶅绩妤ｅ啨鈧鎹勯婊勬殸闁哄嫷鍨粭澶愬及椤栨繄绠烽柛锔哄妽閻栥倝鏌岀仦鐑╁亾瀹ヤ讲鍋撻弬琛″亾?閻?{@link playerRouteStillPushed}闁?
   * 濞戞捁妗ㄧ划鍫熺▕閸粎鐟濆ù鐘查瀵剟寮０浣虹倞闁挎稒鐡狿laybackPageCoverContent` / `PlaybackPageBuilder` 闂侇喛濮ゅΣ?`@Builder`闁?
   * 濠㈣埖鐭槐鑸电▔閳ь剚绋?`NavPathStack` 閻熸洑鐒﹂弫鍏肩▔婢跺妲辩紒娑欏劤閹洟鏁嶅▽妗淧rovider/@Consumer` 闁哄嫷鍨卞﹢鏉款啅閵壯€鏌ょ€规瓕灏欑划锟犲捶閵娧勬殢闁?
   * 閻庤蓱閺岀喖骞嬮幇顒夊殸闁哄牆鎼崺妤呮晬閸у嚘ndex.ets` 鐎规瓕灏欑划锟犲及?`@Provider`闁挎稑顧€缁辨繈骞掗妷銈囶伇婵炲棌鈧啿绁柛娆樺灛閳?
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
  /** 闁圭虎鍘介弬浣广亜閸偆銈﹂柛蹇擃槼閸庢寮查姘辩；闁稿繒顒茬槐娆戞媼閸撗呮瀭濡炪倗娅㈢槐婊眕pStorageV2 闁稿繐褰夐棅鈺呮晬鐏炵偓鏆悹浣稿⒔閻ゅ棛绮╃€ｎ亜鐓濋柣銏㈠枑閺呫儵鏁嶆径鍫氬亾?*/
  @Local flowLightState: PlaybackFlowLightState =
    AppStorageV2.connect(PlaybackFlowLightState, AppStorageKeys.PLAYBACK_FLOW_LIGHT_STATE,
      () => new PlaybackFlowLightState())!;
  /** 婵炵繝绀侀崢婊堟嚄鐏炵偓鐝柣銊ュ鐞氳鲸绋夐鍫澒闁肩顕滅槐娆撴偨閸楃偟娈遍梻鍫涘灩婵晠骞€娴ｇ绲块柤瑙勫絻閸熸捇宕楅妷顖滅闁?*/
  @Local coverTint: CoverTintState =
    AppStorageV2.connect(CoverTintState, AppStorageKeys.COVER_TINT_STATE, () => new CoverTintState())!;
  /** 婵炵繝绀侀崢婊堟儓閳ь剟鎳濋幓鎺撶彜闁硅矇鍐ㄧ厬闁革綆鐓夌槐浼村箲閵忥紕鎽冮柛姘鐎垫粓寮弶鍨悼闁告帗澹嗗▓鎴犱焊娓氣偓濞肩増锛愬鍡楊棌闂佹彃绉烽?uniform闁?*/
  private flowLightController: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  /** 鐎瑰憡褰冪花鏌ユ偨閵娿儱鐓傞柣顐熷亾闁艰褰冨▍鎺楁儍閸曨偄绲块柤纭呭皺婢ф寮甸鈧ぐ鍧楁晬瀹€鍕級闁稿繐绉撮幃鎾寸▔閳ь剚绂掓禒瀣垫澒闁艰鐓￠崳鍛婂緞瀹ュ嫮鐟撻柛娆愬灥缁旂兘濡?*/
  private appliedTintVersion: number = -1;
  /**
   * Background cover source (Resource).
   *
   * 闁宠法濯寸粭?2026-10-15闁挎稒淇洪崕妤呭疾椤栨稒鏆悗鍦仦濡炲倸螣閿涘嫮藝闁告艾鍑界槐婵嬪嫉椤掆偓閻⊙冣枔?*闁诡厽甯婄拹?`Resource`**闁? `song.label`闁挎稑鑻敮顐ｆ叏鐎ｎ亞娈遍梻鍫緛缁辨岸鏁?
   *   濞戞挸绉撮崯鈧悶姘煎亯缁佹挳骞?`effectKit` 濡澘瀚憰鍡涘蓟閹惧啿姣夐柡澶堝劤濞堟垵螣閿涘嫮藝 PixelMap闁挎稑鐗撻崑鍛村级闄囬惌鎯ь啅閹绘帊绮婚柣銏╃厜缁辨繄鎲?
   *   {@link getImageColorAsync}闁挎稑顦埀顒€鍊荤悮顐﹀垂鐎ｂ晝绠介柣?`PixelMap | Resource` 闁哄嫷鍨拹鐔哥閸℃鎮戦悗?
   *   {@link isPixelMapCover} / {@link originalCoverSource} 闂侇叏绲惧顖炲礂濠婂啰淇洪柛鎺戞閺侇噣濡?
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
  /** 鐟滅増鎸告晶?Swiper 濡炪倗顣槐? = 閻忓繋绶氬鐗堛亜绾板绀? = 婵繂鐭侀惁婵囥亜绾板绀嗛柕?*/
  @Local playbackSwiperIndex: number = 0;
  /** 婵繂鏈ú鎼佹嚕濠婂啫绀嬮柨娑樼墦閸嬪懏绋夐埀顒€螣椤忓浂鏀介柣銊ュ閳ь剙鏈ú鎸庡緞濮樸儮鍋撳蹇曠闁哄嫷鍨伴幆浣轰沪閺囩偟纾婚柨娑欑heet 闁?`ControlAreaComponent` 闁汇垺鐪归埀?*/
  @Local playMenuOpen: boolean = false;
  /** 鐟滅増鎸告晶鐘诲即閸欏笑闁告熬绠戦崙锟犲绩閹増顥戦柨娑樼墦閸嬪懏绋夐埀顒€螣椤忓浂鏀介柛娆忓帠閺呭爼鎯冮崟顐ゅ鐟滈偊婢佺槐姘跺Υ閸屾瑧鐟?`MusicPlayInfoBlock` 闁告艾濂旂粩瀛樼附濡ゅ嫷鍤㈤柛鎰懀閳?*/
  @Local isCurrentFavorite: boolean = false;
  @Local favStore: MusicStoreService = MusicStoreService.getInstance();

  /**
   * 缂傚啯鍨堕悧鎼佹嚄鐏炵偓鐝柣銊ュ缁喗鎷呭鍛闁?4閼?4闁靛棔绀侀崙鈩冩交?`enhanceColors` + `boxBlurRgba(9,3)`闁挎稑顦埀?
   *
   * 闁?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`MeshCoverBg`闁挎稑顧€缁变即寮甸鍕┾偓澶愬箰娴ｈ绠掗悗鐟板暟濞堟垿鎮介悢閿嬪殥闁告稏鍔嶅﹢?闁炽儲鏌￠埀?
   *   闁瑰箍鍨洪悺鏇㈠籍?`publishMeshSource` 闂佹彃锕ラ弬浣圭▔婵犱胶顏辩€殿喚濯寸槐杈ㄧ▔閾忓厜鏁勯柡鍐╁劶閸庢寮查姘辨勾闂侇偀鍋撻柛?閻庡湱鍋炲鍌毼熼敍鍕囬梺顓ㄧ到缁卞爼宕?闁?
   */
  @Local meshSrc: image.PixelMap | undefined = undefined;
  /** 闁瑰箍鍨瑰ù妯荤閵堝洤顤傞柨娑樻綁MeshCoverBg` 闂傚牏濮撮悾鐘垫喆閿曗偓瑜板倿鏌屽鍡樼厐濞戞挸锕ｇ槐鍫曟晬瀹€鍐炬綄闂侇叏缍侀崳鐑芥儍?`@Monitor`闁挎稑顦埀?*/  @Local meshSrcVersion: number = 0;
  /**
   * 閳藉應妲勯埥鍛 2026-10-17閿?*娣囶喓鈧苯鐫嶅鈧潻鍥┾柤娑擃厽妲告稉濠佺妫ｆ牗鐡曢惃鍕杹閼瑰眰鈧?*閿?
   *
   * `coverTint` 閺?*鐠恒劑銆夐棃銏犲彙娴?*閻ㄥ嫸绱檂AppStorageV2` 閻?`CoverTintState`閿涘绱濈€瑰啫褰ч崷?
   * `extractFlowLightColors()` 閹存劕濮涙稊瀣倵閹靛秷顫﹂弨瑙勫灇瑜版挸澧犳潻娆庣妫ｆ牜娈戞０婊嗗閵嗗倷绨弰?*閺傜増瀵曟潪?*閻ㄥ嫭鎸遍弨楣冦€夐崷?
   * 閸欐牞澹婄€瑰本鍨氭稊瀣閿涘畭FlowLightBackground()` 閻㈣崵娈戞禒宥囧姧閺?*娑撳﹣绔存＃?*閻ㄥ嫰顤侀懝?
   * 閳ユ柡鈧?閼板苯鐣犻弰顖欑鐏炲倿鎽靛鈩冩殻鐏炲繒娈戦惈鈧懝鎻掓珤/濞撴劕褰夌仦鍌︾礉缂冩垶鐗告潻妯荤梾閸掗缍呴弮璺虹暊鐏忚鲸妲?閼冲本娅?
   * 閳?閻劍鍩涢惇瀣煂閻ㄥ嫬姘ㄩ弰顖樷偓灞界潔瀵偓鏉╁洨鈻兼稉顓熸Ц娑撳﹣绔存＃鏍ㄧ摃閻ㄥ嫰顤侀懝灞傗偓宥冣偓?
   *
   * 閳?閺堫剙鐡у▓?= "**瑜版挸澧犳潻娆庣妫?*閻ㄥ嫰顤侀懝鎻掑嚒缂佸繋绗呴崣鎴ｇ箖娴?閿?
   *   璺?閹稿倽娴囬弮鍓佺枂閸嬪浄绱欐い鐢告桨濮ｅ繑顐奸幍鎾崇磻闁姤妲搁弬鏉跨杽娓氬绱氶敍?
   *   璺?`applyFlowLightColors()` 閻喐顒滄稉瀣絺閺冨墎鐤嗛惇鐕傜幢
   *   璺?`FlowLightBackground()` 閸欘亜婀€瑰啩璐熼惇鐔告閹靛秵瀵曟潪?閳?鐏炲繐绠峰姝岀箼娑撳秳绱伴崙铏瑰箛娑撳﹣绔存＃鏍畱妫版粏澹婇妴?
   * 閳跨媴绗?閻喓缍夐弽纭风礄`MeshCoverBg`閿涘绗岀€瑰啯妫ら崗绛圭窗缂冩垶鐗搁張澶庡殰瀹歌京娈?`src`/閸忔粌绨崇純鎴炵壐閿涘奔绗夋笟婵婄閺堫剙鐡у▓鐐光偓?
   */
  @Local tintReady: boolean = false;
  /**
   * 閳藉應妲勯埥?2026-10-17閿?*閹貉冨煑閸栬櫣婀＄€圭偘绗傚▽?*閿涘澊p閿涘瞼鐛ラ崣锝呮綏閺嶅浄绱氶垾鏂衡偓?閻?`SWIPER_GAP_ROW_ID` 闁絾鐗撮崡鐘辩秴閺夛紕娈?
   * `.onAreaChange` 閸愭瑱绱欓崣顏囶嚢闁插繑绁撮敍灞炬￥閸擃垯缍旈悽顭掔礆閵嗕繖metaOffsetY()` 閻劌鐣犻崑?閸掝偄甯囨潻娑欏付閸掕泛灏?閻ㄥ嫰鎸搁崚韬测偓?
   * 閳跨媴绗?閸掓繂鈧?-1 = 鏉╂ɑ鐥呴柌蹇撳煂閿涙盯鍋呴弮鍓佹暏閹恒劎鐣婚崐鐓庡幑鎼存洏鈧倿鍣洪崚棰佺閸氬簼绱扮憴锕€褰傛稉鈧▎锟犲櫢瀵ょ尨绱濋柦鍐插煑闂呭繐宓嗛悽鐔告櫏閵?
   */
  @Local chromeTopMeasured: number = -1;

  /** 闁哄洩灏欏ú浼村箣閺嶃劍鏆柦妯虹箳婢ф寮甸鈧ぐ澶愬礌閺嶃劍顦ч柛鎺楁敱閺屽﹨绠涢崘銊ㄥ煂闁?*/
  @Monitor('state.selectIndex', 'favStore.favoriteVersion')
  onFavoriteChanged(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      this.isCurrentFavorite = false;
      return;
    }
    this.isCurrentFavorite = this.favStore.isFavorite(song.source, song.songId);
  }

  /** 闁告帒娲﹀畷鏌ュ绩閹増顥戦柨娑樼墢閸欏酣骞?`MusicPlayInfoBlock.toggleFavorite()`闁挎稑濂旂换姘辨嫚娴ｇ柉鈷堝璺哄椤㈡垶绋夋潪鎵伇闁肩柉鎻槐姘跺Υ?*/
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

  // 闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?閻熸洖妫涘ú濠勪沪閸岋妇绀勯柛娆惿戝畷鎻掝嚕韫囥儳绀嗛柣銊ュ閸ゆ垶鎷?+ 缂佹棏鍨抽崑锝嗙▔婵犲啫袚闁挎稑鐗嗛顕€寮介崶銊︼骏闁?`floatingCover.onAreaChange 闁?publishMorphTargets`闁挎稑顦弨銏ゅ煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀?

  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();

  // 闁宠法濯寸粭?閺夆晜鐟╅崳鐑藉储閻斿憡闄嶉柡鍫濐槷缁旀挳寮€靛摜娈婚柕鍡楄嫰瑜板骞戦姀鐘电閻熸洖妫涘ú濠勪沪閸屾ǚ鍋撳鍥ㄧ暠闁告瑦鐗曢埀顒傚帶濞?闁炽儲鏌￠埀?**2026-10-17 鐎瑰憡褰冮崹褰掓⒔?*闁?
  //      `coverLayerBase()` / `coverLayerScale()` / `coverLayerTx()` / `coverLayerTy()` /
  //      `coverLayerRadius()`闁? 闁糕晛鎼崳顖炴儗閳轰浇鍩?/ 缂傚倵鏅滈弬?/ 濞达絽绉朵簺 / **闁告锕ょ欢?濮?scale**闁挎稑顦埀?
  //   闁告帞濞€濞呭酣鎮堕崱娆愭殸闁挎稑鐗嗛崹褰掑礈瀹ュ鍋撻幇顏堝殝 grep 闁稿繈鍔嬬划銊ф兜椤旀鍚囬梻鍡氬煐缁夐鎷圭涵鍛亾閸滃啰绀嗛柨?
  //   鐠?閻庣懓鍟╁鎴﹀及?*鐎规瓕灏～锕傚箻閵堝懏绀€闁汇劌瀚伴崑鍛▔閳ь剟鎮?*闁?闁糕晛鎼崳?+ `.scale()` + `.translate()`"闁挎稑顦卞▓鎴炵瑜忔晶鍧楁晬?
  //     闁绘粍濯介、鎴犳導?**`coverLocalRect()`**闁挎稑鐭侀埀顒€鑻悾鐘典焊鏉堛劍笑 `lyricFloatRect()` 闁?*闁烩晜鎸抽埀?*
  //     闁挎稑鐗嗛弰鍌溾偓?濞达絽绉堕悿?闁革箑妫滈～妤佺▔閳ь剙顕ョ€ｎ剚绾柟鎭掑劚閸熸挻娼?`.width/.position/.borderRadius`闁?*闁哄牜鍓濇俊顓㈡倷鐟欏嫮姊鹃柡鍫濐槼閸ゆ粌顔忔潏鈺傜暠 `.scale()`**闁挎稑顧€缁?
  //   鐠?闁哥儐鍨粩瀛樻交濡儤韬悹鍥嚙閻ｇ姵绂掗鍌涚暠闁哄嫷鍨粭鍛存閵忋倕浜濋柡?`RzdCoverRect` 閻犲洤锕ラ弻鍥籍閵夈儳绠堕梺鎻掔灱濞?`base=/tx=/ty=` 濞戞挸顦伴?闁炽儲鏌￠埀?
  //     闁兼澘鐭傞崑鍛▔婢跺鍞介梺鎻掔箳濞堟垵顫㈤敐鍡樞?闁告瑯浜濆﹢浣割啅閼奸娼堕柟淇卞€曞ú鏍焽閿濆嫮顏遍柣妤€鐗婃晶鐘诲嫉婢跺本鐣遍梺? 闁?闁伙絾鐟у鍐矗椤忓啰绐楅悹鍥跺灠椤曢亶宕ユ惔銏￠檷濞存粎灏ㄧ槐娆忣啅闊厾顏辨鐐舵硾閸ㄥ綊骞掓径娑氱闁?
  //   鐠?闁?閻忓繈鍊曢崣?`coverLayerRadius()` 闁汇劌瀚弫鐐烘煂婵犲倸鏅搁柣顐熷亾闁靛棗鑻〒鍓ф喆閹哄秶绋婇柣顫妼濠€?*闁哄牜浜炵紓澶愬绩?*闁汇劌瀚俊顓㈡倷闁稓鐟?闁?闊洤鎳橀妴蹇涙⒔閵堝嫪绨?scale闁靛棗绋勭槐?
  //     濞戞挸娴烽獮鍥╂偘瀹€鍐惧晭閻?*婵繐绲介妶浠嬫儎缁嬪灝鍐€**闁挎稒姘ㄩ獮鍥捶閵娿劎绠瑰☉鎿冧海婵☆參鎮?*婵炲备鍓濆﹢?* `.scale()` 闁?闁绘挆鍐殜闁?闂傚嫨鍊撴禍?scale"
  //     濞村吋纰嶆俊鍝ヤ焊韫囨挾娈遍梻鍫涘灲閸嬪懐绮╅婊勭暠闁革箑妫滈～妤呭绩閹佷海闁?~6.7 闁稿﹤绋勭槐娆撴儑鐎ｎ剚绲婚柛宥呯箣闁叉粎浜歌箛鎾村闁绘娴勭槐姘跺Υ?*閺夆晜鐟﹀Σ姝岀疀閸涙番鈧繘宕氶悩鍐茬閻庣懓鍟板▓鎴︽儎鐎涙ê澶嶉柛妯煎枎濞叉粓濡?*

  /**
   * 閻熸洖妫涘ú濠勪沪閸屾瑧鐟愰柟韬插劘閳ь剙鏈幐閬嶅绩妤ｅ啨鈧浜告笟鈧鎵博椤栨粌浠柕鍡楃Р閳?
   *
   * 闁?閻庝絻顫夐悥锝夊籍閻樺灚娅?`floatingCover.onAreaChange 闁?publishMorphTargets()`闁?*閻熸洖妫涘ú濠勪沪閸屾繂娈扮€圭宕銊╁及椤栫偛娅ゆ繛鏉戭儐缁?*闁?
   * 闁宠法濯寸粭?**闁告瑯浜滃﹢顏嗕焊娓氣偓濞肩増銇勯悽鍛婇ク婵繍婢佺槐妾倀 闁?0`闁挎稑顦板鍌涚▔婵犲啫袚**闁挎稒鑹鹃懜浼村矗濮椻偓閳ь剚鏌ч懙鎴炴交濞嗗海顏遍悘鐐插€诲▓鎴炴媴瀹ュ洨鏋傞柡鍕靛灥椤箒銇愰姀鐘茬秮濡炵懓宕慨鈺呮儍閸曞墎绀?
   *    闁硅泛锕︿簺闁告柣鍔嬮懙鎴︽儍閸曨厾鍙愮憸鑸灩閸熸捇宕堕悙娈夸紓闁绘劙鈧稓绐楃憸鑸灪閸ㄦ艾顫㈤敐鍛唨濡絽鐗炵槐娆戠博椤栨粌浠悺鎺戯龚缁愬洨鎼炬繝鍌欑剨闁挎稑顦埀?
   */
  private reportPlayerCoverFromOverlay(area: Area): void {
    if (this.lyricMorphT > 0.001) {
      return;
    }
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*鐟滆埇鍨硅ぐ澶嬬▔椤撴繄顏辩€垫澘顑勭粭澶嬬▔婵犲啫袚**闁挎稑鐗愰～?`coverAnchorMeasurable()` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柕?
    //   闁绘劗鎳撶槐?闁衡偓閹増宕抽柡鍐╁劶椤╊偊鎯勯弽褏婀村ù鍏间亢缁愶繝鎯堥埀顒傗偓鍦嚀濞呮帗绋夐埀顒傛導妞嬪海绱氶柨娑樼焸閸嬪懘寮崼鏇炴闁告帗澹嗗▓鎴︽儗閳轰浇鍩岄柡?閺夆晞娓圭紞姗€寮堕垾宕囨闂傚牄鍨介崑鍛▕閸縿浜?闁?
    //   闁告劖鐟ㄧ换?`endCover*` 濞村吋纰嶆俊鍝ョ磼椤撱埄妫ч悘蹇庣窔濞间即鎯冮崟顓犵煉闁绘劗鎳撻崯鎾诲锤?闁?闂侇叏绲肩粩鏉懳涢幒宥囩憹闁汇垻绮崹銊︻槹閻愭彃鐓傞梺鎸庣懅濞堟垹浜歌箛鏇犲彁鐟滈偊娼块埀?
    if (!this.coverAnchorMeasurable()) {
      return;
    }
    const gx: number = areaLengthToVp(area.globalPosition.x);
    const gy: number = areaLengthToVp(area.globalPosition.y);
    const gs: number = areaLengthToVp(area.width);
    // 闁宠棄鎳夊Σ?2026-10-15 閻犲洤锕ラ弻鍥煥濮樺崬浠柨娑樻綁hdc shell hilog -x | Select-String 'RzdCoverRect'`闁挎稑顦埀顒佹煛閳?
    //   濞戞挴鍋撴繛鍡忓墲婵?*濞戞挸顦柌婊堟儗閳轰浇鍩?*闁瑰灚鎸搁崵顓㈠级閵夘垳绀夐柣顫妽濞肩敻宕氶妶鍛毎"閻忓繋绶氬浼存媰閻ｅ苯浠☉鎾崇Т椤?闁告帗婢樼花宕囦沪閻愭壆鑹鹃柛婵愪簷缁斿绮斿蹇曠**濞戞挶鍊楅～鎺撶┍椤旂晫銆婇悗鐟拌嫰閸欏繑绋夊鍛€?*闁挎稑顧€缁?
    //     鐠?`measured` = `onAreaChange` 闁?`globalPosition`闁靛棗鍊靛▓鎼佹晜?閻庣懓鍟Σ?*閻㈩垰鍟惇顒勫礄閻樿京绉?*闁?
    //       **濞戞挸绉撮幆鍫ュ嫉椤掑啫螡闁绘劗顢婇崵婊冾啅鏉堚晜鐣?`.scale()` / `.translate()`**闁挎稑鐗婂﹢鐗堢閹惧瓨鏆堥梺鎻掞工椤︽寧寰勯崟顐㈢箒閻犲鍟崇换鍐╂交濞嗗海顏遍柣鎰缁辨岸鏁?
    //     鐠?`geometry` = 缂佺虎鍨伴崵鎴炴媴閺囩媭浼傞柣鎰缁辨獋playerCoverGeomRect()`闁?*濞戞挸绉甸悡鈩冪鐠佸磭绉块柤鍝勫€婚崑?*闁挎稑鑻顕€寮介崶銊︼骏闁?
    //       `CoverMorph` 闁稿繈鍔庨埢鍏肩▔瀹ュ娅ゆ繛鏉戭儜缁辨岸鏁?
    //     鐠?`base/tx/ty` = 閻熸洖妫涘ú濠勪沪閸屾粍鐣遍柛娆忓€介埀顒€鍟伴柈瀛樼▔鎼存繄绉寸紒?闁炽儲鏌￠埀?**婵炴挸寮堕悡瀣媴?= base + translate**闁?
    //   **闁告帇鍊栧畵?*闁?
    //     闁?闁?`dxy` 闁?濞戞挸锕ｇ粭鍛偓鐟邦槸閸欏繘宕犲ú顏嗗蒋閹艰揪璁ｇ槐娆撳礄閻樻彃纾?vp闁靛棔妞掔粭鏍ㄧ▔婵犱胶鐟撳☉鎾卞€撻柌婊堝棘閻熺増鍊婚柨?闁?**闁告劕鎳庨鎰版儎閹烘垳鐒婄紒?*闂傚偆鍣ｉ。?
    //        闁?閻忓繗椴稿Σ?`PlaybackPageRoute` 闂侇叏绲惧顖涖亜閸偆澹岄柟纰樻櫅閻秹鏁嶉崸鍒pandSafeArea` + `ignoreLayoutSafeArea`闁挎稑顦﹢顏嗙不閳藉懐骞?
    //     闁?闁?`dxy` 闁?*闁告帩鍋嗗▓鎴犳暜閸涘﹥娈?/ 濞?`tx,ty` 闁告艾鑻埀?* 闁?**闂佹彃绻戠粊鎾矗閿濆懐绐?*闂傚偆鍣ｉ。?
    //        闁?閻犲洤鐡ㄥΣ鎴犳嫚閵夛箑惟**婵炴挸寮堕悡瀣媴瀹ュ繒绀刡ase + translate闁?*闁兼澘濂旂粭澶愬及椤栨氨顏撮悘鐐╁亾濞达絽绉垫慨銈嗙▔婵犲倸绠甸柨娑樼墕閹線宕?缂佹棏鍨抽崑锝夋偨閸楃偟娈遍梻鍫涘灮閻ｅ濡?
    //          閻忓繋绶氬浼村矗閸喎鐦荤紒鏃戝灣閸嬶綁鎷冮幋鎺旂Т"濞村吋鑹鹃懜浼村箣?*婵繆宕甸獮?*闁挎稑鐭侀銈咁啅椤旇崵绐楅悶姘煎亞鑿欓悗瑙勮壘濠€鎾煥娴ｉ绉?闁炽儲鏌￠埀?閺夆晜鐟﹂婊堝及椤栨稒鎷遍柡鍌濐潐绾泛鈻旈妸鈺佹珵闂?
    //          闁哄啠鏅涘銊╁礃濞嗘帞绠栭柣?闁煎浜滅换渚€鏌岃箛姘鐎?闁挎稑顦埀?
    //   闁宠法濯寸粭?閺夆晜鐟﹀顖炲籍閵夈儳绠?*闁告瑯浜ｉ鐗堢▔瀹ュ懎鏅?*闁挎稑濂旂粭澶庛亹閸楃偞鎯欏ù鐘侯唺缂嶅秶鎮扮仦鑹扮闁挎稑娼塺eportBig` 闁汇劌瀚崣鍡涘矗閸屾瑧顏遍悗娑欘殕濠€顓㈠绩閻у摜绀嗛柕?
    const geom: LyricMorphRect = this.expandState.playerCoverGeomRect();
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*閻忓繋绶氬浼村春閸濆嫬娅欓柛鎴犲С缂嶅秹鎳涢鍥╂**闁挎稑鐗婄敮鎾诲蓟閵夈儱褰犻梺娆惧枛閻?`RzdCoverGeom`闁?
    //   濞戞挴鍋撻柡澶嗏偓铏殤闁煎疇妫勯崹?閻忓繋绶氬鐗堟媴瀹ュ洨鏋傞悗鐢糕偓娑氱憹閻?闁挎稑濂旂粭澶庣疀閸涱厼鏅欓梻鍫㈠У閸╁懘宕舵ィ鍐ㄦ闁稿秴绻掔粈宀勬晬?
    //     闁哄牏鍠愬﹢婊堟晬閸喎顤侀柡?360閼?80 閺夆晜鐟﹂妴鍌炴晬婢舵稓绐梎edge=328`闁靛棔姊梱闁?36`闁? 濡炪倖鍎肩粩鐔兼晬婢跺牃鍋撴稊顤〆nter=300`闁?
    //     鐠?`edge` 闁哄嫬瀛╁Ο澶嬪緞瑜岀花?328闁挎稑鐗呯欢銉︿繆?393/369闁挎稑顦崳?閻庨€涚矙椤ｂ晝绮诲Δ鈧鐢告偨閵婏箑鐏?闁轰礁顕悰銉р偓?濞存粌妫寸槐?
    //     鐠?`y` 闁规亽鍎寸换?`(winH闁愁厽濮€dge)/2`闁挎稑鐗冩晶?298闁挎稑顦崳?闁告瑥鐗嗚ぐ澶愬炊?闁革负鍔庨悰銉╁矗閿濆娅￠悘鐐叉噸閼?闁挎稑鐗冮崯?闁活潿鍔嶉崺娑㈠箮閵壯勭暠"濞达絽绨肩花鈩冪附閽樺妯?闁挎稑顦埀?
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverGeom edge=${geom.size.toFixed(1)} x=${geom.x.toFixed(1)} y=${geom.y.toFixed(1)} ` +
      `centerY=${(geom.y + geom.size / 2).toFixed(1)} radius=${geom.radius.toFixed(1)} ` +
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `padTop=${this.expandState.topInsetVp().toFixed(1)} padBottom=${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      // 闁?闁告帇鍊栧畵渚€鏁嶅姝漞nterY` 闁哄嫷鍨卞﹢鏉库枎?*闁糕晛鎼崳?*闁汇劌瀚懙鎴ｇ疀閸愶腹鍋撻崒娑欏焸闁哄牊鍐荤槐娆撳箥鐎ｎ偅绨氶柨? padTop + 244 闁?300闁?
      //   闁兼眹鍎遍悾鐘诲箳閵夈劎绠?`win/2`闁挎稑鐗冩晶?62闁挎稑顦崳?闁告瑥鐗嗗ú鏍礆?缂佹劖顨呰ぐ娑氫沪閸涱剝鍘?闁挎稑鐗忛弫銈夊箣闁垮袚闁?濞?闁挎稑顦埀?
      `expectCenter=${(this.expandState.topInsetVp() + 244).toFixed(1)} ` +
      `(windowCentered-y=${((this.expandState.windowHeightVp - geom.size) / 2).toFixed(1)})`);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverRect measured=(${gx.toFixed(1)},${gy.toFixed(1)},${gs.toFixed(1)}) ` +
      `geometry=(${geom.x.toFixed(1)},${geom.y.toFixed(1)},${geom.size.toFixed(1)}) ` +
      `dxy=(${(gx - geom.x).toFixed(1)},${(gy - geom.y).toFixed(1)}) ` +
      // 闁宠法濯寸粭?2026-10-17闁挎稒鑹剧敮顐﹀级閵夈劎绠归梺鎻掔焷缁绘洟寮?`base=/tx=/ty=` 濞戞挸顦伴宀勬晬瀹€鍕吂"闁告瑦蓱瀹曟彃顕ｈ箛姘兼船闁烩晜鐗曢惇?闂侇叏绲肩粩瀵歌姳閸ワ妇顏遍悹褍鍢查崹褰掓⒔閵堝嫮鍟?
      //   闁挎稑鐗嗛悾鐘崇椤掑嫬娅ら柣銊ュ瑜把囧嫉婢跺﹤鍤掗悶姘煎亝閹告瑩宕堕悙鍝勪簼濞戞挴鍋撻柣妤€鐗婃晶鐘诲嫉婢跺本鐣遍梺鎻掗獜缁辨繄鎲存担瑙勬嫳闁哄倸娲ｅ▎?:247 闂傚嫬瀚换搴ㄦ焽閿濆棭鍞介悹浣瑰婢跺嫰鏁嶆径鍫氬亾?
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
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16 闁哄倹婢橀·鍐晬?*"缂備礁鐗忛崑锝夋煥濮樺崬浠柛娆樹海閸忔﹢宕烽妸銉ュ伎閻忓繐鎼顓㈡焽閿濆嫮顏遍悽顖嗗倻鐟愰柟?** 闁炽儲鏌￠埀?濞?
   * {@link PlaybackPage.reportPlayerCoverFromOverlay} 闁汇埄鐓夌槐娆撴焽閿濆嫯鈷堝?`reportBig` 闁汇劌瀚晶鐘电磾椤旂厧鐏查柟璇″櫙缁辨岸濡?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸繄绠戝銈嗘椤╋附娼诲▎鎾插闂傚偆鐓夌槐娆撴倷閻熸澘姣婇柟鍨尭缁辨垵鈻介埄鍐╃畳閻忓繋绶氬浼村礉閵娧勬毎闁汇劌瀚﹢锟犲礄閻樿京绉垮瀣叄濞呮捇鏁?
   *
   * 閻熸洖妫涘ú濠勪沪閸屾粍鐣?`.id(PLAYER_BIG_COVER_ID)` + `onAreaChange` 闁哄啨鍨哄Σ?闁圭虎鍘介弬浣广亜闂堟稓娈遍梻?闁?*闁哥儐鍨粩鎾煂韫囨梻銈存繝?*闁?
   * 闁告瑥鐗愰～锕傚箰閸屾碍韬?*鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞呮帡宕橀崨鏉戝姤**闁靛棗鍊风花顒勫及椤栥倗绐?
   * ```
   *   閻庡湱鎳撳▍鎺戭啅閼碱剛鐥呴悶姘煎亜鐢洭宕氶幏灞惧闯闁绘劗娅㈢槐妾歝ale 闁?0.08闁挎稑顦粻锝夊触鎼搭垳绀夊ù鐘侯唺缂嶅秵绋夐埀顒€鈻?onAreaChange 闁硅翰鍎扮粭鍌炲级閵壯勭暠
   *   globalPosition/width 闂侇喛濮ゅΣ鎼佸Υ閹邦垳纰冨ù锝囧У濞碱垳浜告笟鈧浼存焽閿濆嫮鐤勯悘蹇撶箞閳ь剚鍨瑰▓鎴︽儗閳轰浇鍩?
   *   闁?閻庣懓鍟╃槐浼村箮?`endCoverSize/endCoverX/endCoverY` 闁告劖鐟﹂崹姘交閾氬倻绋戦柡澶涚磿濞堟垹浜搁崫鍕靛殶
   *   闁?缂備緡鍙冮ˉ锝囦焊娓氣偓濞间即鏁嶉崼鐔荤檨閻忕偛鍊搁崢鐘绘⒕閸☆厾绀嗛柣?*缂備礁鐗忛崑?*閻炴凹鍋勯崯鎾诲锤韫囥儳绐楅梺顓ㄧ导缁旀潙螞閹烘洦娲ｅ☉鏂跨墔缁楀鎮藉Ч鍥ｅ亾娴ｇ瓔娲ｅ☉鏂跨墦椤ワ綁宕氭０浣侯伇濞戞搩浜弫濠勬嫚椤栨粍鐣遍悘蹇撶箳閻撯晞銇?
   * ```
   * 闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳濡?*闁绘劗鎳撻崵顕€骞嶉幘宕囩； / 闁绘劗鎳撻崵顕€宕楅幎鑺ワ紨 / 缂侇垵宕电划鐑樻交閺傛寧绀€闂侇喛濮ら惀鍛村嫉婢跺﹦娈遍梻鍫涘灩婵晠鎮?*闁靛棗绉崇粭灞炬交濞嗘劖钂嬮悗鐟拌嫰閸欏繘宕ョ拠鍙夊€?闁炽儲鏌￠埀?
   * 闁绘劗鎳撻崵顔炬崉椤栨氨绐炲☉鎾筹龚椤╊偊鎯勯弽褏婀撮柡?*闂傚懎绻橀妴澶愭椤厾顏遍悹褔鏀辩€垫洘娼?*闁汇劌瀚哥槐婵堚偓鐟板暟濞堟垹绮璺伇婵?`onAreaChange` 鐎垫澘鐗嗚ぐ鏌ユ嚄閽樺鐨戦柦鈧挊澶嬭含
   * "閻庡湱鎳撳▍鎺戭啅閼奸娼堕柛妯侯儏閸╁瞼鎸ф搴′化"濞戞柨顑呴幃妤呭Υ?
   *
   * 闁?闁告帇鍊栧畵渚€鏁?*閻庡湱鎳撳▍鎺楀及椤栨稐鑸紒娑橆槸瑜板骞戦～顔剧`morphScale 闁?1`闁挎稑顦粭鏍р柦閳╁啯绠掗悷浣风婢光偓**闁哄啳鍩栨晶鐘诲礂娴ｇ瓔鍟呭☉鎾筹攻婵倝濡?
   *   鐟滆埇鍨硅ぐ澶嬬▔椤撱劎绀刞morphClipping()` 濞戞捁娅ｅ﹢锟犳晬婢跺顏辩€垫澘顑勭粭澶嬬▔婵犲啫袚 闁炽儲鏌￠埀?闂侇叏绲惧鍌炴煂韫囨挸鐓傞柣銊ュ閸忔ɑ绋夊鍡樞?闂傚牊鐟﹂娑㈠箑娴ｇ儤鍩傞悗鍦仧閻撯晞銇?闁?
   * 闁宠法濯寸粭?闂傚牊鐟﹂娑㈠箑娴ｇ儤鐣?`morphScale` 闁诡厽甯婄拹?1 闁?閺夆晜鐟╂禍楣冩⒒閵娿儲韬梻鍫熺懄椤掓盯骞€?*闁诡厽甯炲﹢?*闁挎稑濂旂粭澶庛亹閸楃偞鎯欓柡鍐﹀灪濠€浣烘偘鐏炶壈绀嬮柕?
   * 闁宠法濯寸粭?濞戞挸瀛╁Λ锕傚嫉婢跺本鐣?`lyricMorphT > 0.001` 闂侇叏缍佹禍楣冩⒒閵婏附笑**濞戞挶鍊栧顖炴偑椤掑倻褰岄柡澶嗏偓鍙夘偨**闁挎稑鐗撻崑鍛村级閿涘嫷鍚€"婵繂鐭侀惁婵囥亜閻㈠壊妫ч悶娑樺閼?闁挎稑顧€缁?
   *   濞戞挶鍊栧顖炴焾閽樺绠戝銈堫唺缁绘岸鎮惧▎宥佸亾?
   */
  private coverAnchorMeasurable(): boolean {
    if (this.expandState.morphClipping()) {
      return false;
    }
    return this.expandState.morphScale >= 0.999;
  }

  /**
   * 濞戞挸锕ユ慨銈咁潰鐏炶姤鍊?婵繂鏈晶婊堟儍?*闁圭儤甯炴晶妤冪博椤栨粌浠?*闁挎稑鐗嗛懜浼村矗濡惟闁哄倸娲ら悺褔鎮介崡鐐海闁告瑦锚閻?闁汇垹宕惃顒勫矗濡亽浜ｉ柡鍐煐鐎垫粓宕ョ仦鑲╊伇濠靛倹顨呴悺褎鎷呴幘鍐叉闁轰胶澧楄ぐ鍐磹绾绀嗛柕?
   *
   * 闁?閺夆晜鐟ょ悮杈ㄧ▔椤忓啰鐟愰柟韬插劚鐢偊寮堕妷銉﹁含 `MusicPlayInfoBlock` 闂佹彃琚埀顒€鍊搁悾鐘崇鎼达絿宕曢悘鐐茬箻閵?0 缂佸顭峰▍搴ㄥ触鎼达紕绠戝銈囩帛閹宕氶幏宀€绠归梺?闁炽儲鏌￠埀?
   *   闁告熬绠戦崹顖滅博椤栨粌浠梺鎻掔箣缁楀宕?闁?**閻忓繋绶氬鎵磽閳哄倸鐏?0闁挎稑鐗忓﹢鍛▔瀹ュ牜娼岄柨? 閻忕偞娲栫槐鎴﹀礉閵娧勬毎婵炲备鍓濆﹢浣虹博椤栨粌浠?*闁?026-10-15 闂侇叏绲鹃鐓庣暦閳哄倻鐨鹃柣銊ュ閻楁挳宕堕悪鍛闁?
   * 閻庢稒銇炵紞瀣矗閸屾稒娈跺☉鎾抽叄閸嬪懏绋夐埀顒傛偘?*閻庡湱鍋ゅ顖氥€掗崣澶屽帬闁汇劌瀚埀?*濞ｅ洦绻冪€垫梹绋夐埀顒勬嚊鏉堝墽绀刞LYRIC_META_TITLE_FP` / `LYRIC_META_ARTIST_FP`闁挎稑顦埀?
   */
  private publishMetaEndpoint(singer: boolean): void {
    const song = this.state.getCurrentSongItem();
    const endpoint: MorphMetaEndpoint = new MorphMetaEndpoint();
    endpoint.id = singer ? PLAYER_META_SINGER_ID : PLAYER_META_TITLE_ID;
    endpoint.controller = singer ? this.singerController : this.titleController;
    const raw: string | Resource = singer ? (song?.singer ?? '') : (song?.title ?? '');
    endpoint.content = typeof raw === 'string' ? raw
      : this.getUIContext().getHostContext()!.resourceManager.getStringSync(raw.id);
    // 闁?2026-10-15闁挎稒鐭粭鍌炲箮?*鐟滅増鎸告晶鐘虫交濞嗗海顏遍悽?*闁汇劌瀚悺褔宕ｉ崙銈囩濞戞挶鍊楅顒勫箵閹烘垟鍋撻懖鈺傜暠缂備焦鎸婚悘澶愭晬婢舵稓绀夐柤鏉垮缁楀寮伴姘ゼ閻庤姘ㄥ▓鎴濐潰瀹€鍐Г濡炪倝娼ч埀?闁炽儲鏌￠埀?
    //   闁告熬绠戦崹顖濄亹閵忕姴缍佺紒鏃戝灣閸嬶綁鏌岃箛鎾崇厒闁汇劌瀚Σ鍛婄▔閳ь剚绋?闁告瑯浜滃﹢顏勵潰瀹€鍐Г濡炪倕鐏氭晶鐘诲箣閹邦喚褰?闁汇劌瀚悺褔宕ｉ崙銈囩閻忓繋绶氬鐗堛亜閻㈢浜濆☉鎾亾缂佹棏鍨槐浼村磻韫囨挾姣堥柕?
    endpoint.fontFp = singer ? this.metaArtistFp() : this.metaTitleFp();
    endpoint.family = singer ? PlayerConstants.FONT_FAMILY_BLACK : PlayerConstants.FONT_FAMILY_BOLD;
    endpoint.weight = singer ? 400 : 700;
    endpoint.color = singer ? $r('app.color.play_singer_color') : $r('app.color.play_text_color');
    endpoint.opacity = singer ? 1 : 0.86;
    endpoint.maxLines = 1;
    this.expandState.registerMorphMeta(false, singer, endpoint);
  }

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16 闁哄倹婢橀·鍐晬濮橆剛娈遍梻鍫涘灱閹倖鎷呭澶嬵吂 `lyricMorphT` 闁告瑦锚鐎垫煡寮懜闈涒叺濞戞挴鍋撴繛鍡忊偓鎰佸殸閻犳劧闄勫Λ鈺勭疀濡炲皷鍋?
   *
   * 闁宠法濯寸粭?`lyricMorphT` 闁?*闂侇偅鍔曢幎?*闁衡偓閸︻厽鐣遍柨娑樼墣钘熼梻鍌涙尦閸ｇ兘宕樺▎娆戠闁挎稑鏈晶宥嗙閵夈劎绠归梺?*闊洤鎳橀妴?*闁哄牆顦虫俊顓灻?闁炽儲鏌￠埀?
   *   闁煎搫鍊圭粊锔界▔鎼粹€崇闂佹彃绉归崗姗€宕?{@link PlaybackPage.logCoverLocal} 闂佹彃鐭夌槐?00ms + 缂佹稒鍎抽幃鏇炐掗弬娆惧殸闁挎稑顦埀?
   * 闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdCoverLocal'`
   */
  @Monitor('lyricMorphT')
  onLyricMorphTChanged(): void {
    this.logCoverLocal();
  }

  /** 闁哄洩灏欏ú浼村矗濡搫顕ч柡鍐ㄧ埣閸ｆ悂骞庨妷銈堚拡濞戞搩浜濋弸鍐偓娑欘殘椤忣剟鎮欓惂鍝ョ闁告鍠愬鐢稿捶?`MusicPlayInfoBlock` 闁?`@Monitor` 闂佹彃鐭夌槐姘跺Υ?*/
  @Monitor('state.selectIndex')
  onMetaEndpointChanged(): void {
    this.publishMetaEndpoint(false);
    this.publishMetaEndpoint(true);
  }

  /**
   * @returns 婵繂鐭侀惁婵囥亜閻㈢浜濆☉鎾亾婵☆垼浜ｉ、鎴︽儍?*鐎归潻绠戦崬瀛樻綇绾懐鐛?*闁挎稑婢妏闁挎稑顦埀?
   *
   * 闁?`lyricMorphT` 闁革负鍔嬬悮杈ㄧ▔椤忓棭浼傞柣鎰扳偓娑氼吅闂傚倸鐡ㄨぐ鍐磹绾绐?
   * 鐠?`t = 0`闁挎稑鐗嗛惃婵嬫閵忋們鈧鏁? 濡炪倗鏁诲鐗堟綇绾懐鐛╅柨娑樻湰閻℃洟宕ュ鍛狗濞戞搩鍘肩亸顖氼潰閿濆嫮鐟撻柡鍌滄缁?
   * 鐠?`t = 1`闁挎稑鐗婇悺鏇犳嫚瀹ュ鈧鏁? **閻忓繐绻愰惃婵嬫閵忕姴绀佺紓?+ 12**闁挎稑鏈弸鍐偓娑欘殙椤斺偓鐎殿喒鍋撻悘蹇撶箰閻ㄦ繈妫冮～顑藉亾?
   * 闁哄啰濮烽弲顐︽?`floatingCover` 濞?`metaRow` 濞戞挶鍊曢惇浼存儍閸曨優顓㈠触閹达附鏅╁ù锝呯Х閹活亪宕氶弶鎸庡€卞☉鎾亾闁轰礁鐗婇悘澶愭晬瀹€鍐闂佹彃鐬奸弫銈夊礃閸涙壆鐝堕悹鐑樼箚閵嗗啯娼忔穱鎵佸亾?
   * 閻忓繑鍨崇粩瀵镐沪閸屾ǚ鍋撴担椋庣槏濠㈠灈鏅濋崝褔姊捐箛姘辩閹艰揪绠掔换娑氱磼椤撱劎绀勫☉鎾崇С缁变即宕烽妸銈嗗攭婵☆偅甯掗幎姘辨崉閸忓懐顏卞☉鎾愁儜缁辨岸濡?
   */
  private lyricMetaLeftInset(): number {
    const side: number = PlaybackPage.LYRIC_META_SIDE_VP;
    const t: number = this.lyricMorphT;
    const coverRight: number = this.lyricFloatRect().x + this.lyricFloatRect().size;
    return side + (coverRight + PlaybackPage.LYRIC_META_GAP_VP - side) * t;
  }

  /**
   * @returns 闁稿繐鍟╂穱濠囧箒椤栨繍鏀介柛?*闁糕晛鎼崳顖炴儎?*闂佹彃鐬煎▓鎴炴媴瀹ュ泦鈺呮晬閸х闁挎稑顦埀顒佹煛閳?閻庝絻顫夐悥锝夊籍閻樺灚娅?`floatingMeta` 闁告劕鎳庨惇浼存焽閿濆棙钂?
   *   `.offset({ y: metaOffsetYAt(swiperProgress) })`闁挎稑娼墂ujie.pa:195907-196008`闁挎稑顦埀?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸綆娲ｉ柛鎴濈箲鐢偓"閻忕偛鎳嶉懙鎴炴媴瀹ュ洨鏋?
   * 闁哄啰濮烽弲顐︽焽閿濆嫯鈷堥悘鐐插€瑰Σ?*闁告帒妫楁导?*闁汇劌瀚哥槐?
   * ```
   *   濠㈣埖鐗曢惇?Column().width('100%').height(overlayBaseH()).justifyContent(FlexAlign.Center)
   *        闁?闁硅泛锕ら悺娆撳礃閸涱収鍟囬柛蹇撶墛閹叉粓宕氶弶璺ㄥ敤闁告垵妫涘ú鍛存儍?*缂佹梹鐗滃ú鎸庣▔椤撶偟濡?*
   *   闁告劕鎳庨惇?Column().offset({ y: metaOffsetYAt(t) })
   *        闁?闁告瑯浜ｉ妴鍐╂綇?闁烩晝顭堥顕€鏌囬敐鍕殝閻忕偛鎳嶉懙鎴炴媴瀹ュ洨鏋傞柣銊ュ娴滃摜绮?
   * ```
   * 闁瑰瓨鍨冲鎴炴交濞嗘劖钂?`.offset()` 闂佹彃鏈弬渚€鎯冮崟顐ょ畱濡炪倗绮Σ?*闁告艾濂旂粩瀛樼▔椤忓牆娅ょ紒?* 闁?
   * ```
   *   metaOffsetY() = metaTopGeomY(t, rowH) 闁?(闁糕晛鎼崳顖炴儎閹烘褰?闁?rowH) / 2
   *                                         闁宠鏌￠弨銏ゅ煘閳ь剟鍩為埀顒勫煘閳?閻忕偛鎳嶉懙鎴﹀触鎼淬値鏀藉銈嗗劶缁旂喖鎯勭粙娆惧殸闁烩晜甯￠妴濠囨儍閸曨亞绉寸紓?闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁?
   * ```
   * 闁?閻炴稑鐭傞妴濠冩綇鐟欏嫭浠樼紓浣哥墣閹倝宕?`metaTopGeomY(t, rowH)`闁挎稑濂旂粭灞剧▔婵犱胶顏遍柣妤€鐗撻崑鍛村级?
   *   `.position({ y: metaTopGeomY(...) })` **闂侇偅鍔曢崕姘辨閻樼數鎼煎ù?*闁挎稑鐗婂畷鏌ユ儍閸曨剚笑缂備焦鎸婚悗顖涚▔鎼粹€崇稉鐎垫澘瀚哥槐婵囩▔瀹ュ棙笑闁轰焦婢橀埀顒傘€嬬槐姘跺Υ?
   *
   * 闁宠法濯寸粭?**濞戞挸绉烽蹇涘礃瀹ュ嫮顔?`1/morphScale`**闁挎稒鐡猰etaTopGeomY` 闁汇劌瀚悮杈ㄧ▔椤忓棭浼傞柣鎰秺閸忔﹢寮?閻庡湱鎳撳▍鎺楀箒閹烘梻鎼奸柡?闁汇劌瀚崵鎴炴媴閺囶亞绀?
   *   鐎规瓕灏欑划锟犲及椤栫偑鈧宕?缂佹劖顨呰ぐ娑㈠触鐏炶偐顏卞┑鍌涱殔濞兼寮介崶椋庡耿濞戞梹眉缁紕浜搁崣妯肩獥闂佹彃绉堕獮鍥偨閵婏箑鐓曢悗鍦仦缁佹挳鎯冮崟鈹惧亾?*闁稿繐鐗撻ˉ锝夋焻閻旂⒈妫ч柛鎺撴緲閻ㄦ繈妫冮～顔剧闁绘帟娉涢幃妤呭礃瀹ュ嫮鐟撻柡?*闁靛棗绉查埀?
   * 闁宠法濯寸粭?闁糕晛鎼崳顖炴儎閹烘褰柣?`estBoxHVp()`闁? 闁告瑯鍨抽弫銈嗩殗?闁?闁硅矇鍐ㄧ厬闁告牜灏ㄧ槐婵囩▔鎼淬垺锟ラ柣?`overlayBaseH()` 闁告艾濂旂粻鐔兼晬婢跺牃鍋?
   *   閻庣懓鍟崇换鏇炩柦閿熺姴娅ら柛鎺斿濡炲倹绋?0 闁炽儲鏌￠埀?濞戞挸顑夊浼存偨?`(baseH 闁?rowH)/2` 闁烩晛鐡ㄧ敮瀵哥不濡ゅ绀? 濞戞梻鍠曢崵婊兠洪弬銈囩濞戞挸绉崇槐?NaN闁挎稑顦埀?
   */
  private metaOffsetY(): number {
    const rowH: number = PlaybackPage.LYRIC_META_ROW_H_VP;
    const baseH: number = this.expandState.estBoxHVp();
    const centeredTop: number = (baseH - rowH) / 2;
    // 閳藉應妲勯埥鍛 2026-10-17閿?*閻撗勬￥閻ｅ矉绱版担宥囆╅崣顏呮箒娑撯偓閺?`metaOffsetYAt(t)`閿涘本鐥呴張澶夋崲娴ｆ洟鎸搁崚?*閿?
    //
    // 閺堫剝鐤嗛幎濠佺瑐濞撴悂鍋呮稉澶婄湴閸忋劑鍎存禒搴＄摟閼哄倻鐖滈柌灞藉絿娴滃棗鍤弶銉礉闁劖娼€靛綊缍堥敍?
    // ```
    //   floatingMeta閿涘湢171797-171846閿涘苯鐫橀幀?L195907-196008閿?
    //     Column().width('100%').height(this.overlayBaseH())
    //             .justifyContent(FlexAlign.Center).hitTestBehavior(Transparent)
    //       Column().width('100%').alignItems(Start)
    //               .offset({ y: this.morph.metaOffsetYAt(this.swiperProgress) })
    //         metaRow()
    //   overlayBaseH()閿涘湧layerPage閿? swiperBoxH > 0 ? swiperBoxH
    //                                : (!chromeHidden && swiperProgress <= 0.001 ? 0 : estBoxH())
    //   metaOffsetYAt(t)閿涘湑overMorph閿? lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
    // ```
    // 閳?娑撳﹥鐖?*濞屸剝婀佹禒璁崇秿"閸掝偄甯囨潻娑欏付閸掕泛灏?閻ㄥ嫰鎸搁崚?*閿涙矮缍呯純顔肩暚閸忋劎鏁遍柇锝勭閺?lerp + 鐏炲懍鑵戦惄鎺戝枀鐎规哎鈧?
    //   閹存垵澧犻崙鐘靛閸旂姷娈戦柦鍐插煑閿涘牆鎷伴悽銊ョ杽濞?chromeTop 閻ㄥ嫮澧楅張顒婄礆闁姤妲?*閹存垼鍤滈崚娑氭畱**閿?
    //   閻劍鍩涚€圭偞绁撮妴灞炬暭瀵版ぞ绗夌€电櫢绱濆В鏂剧閸撳秷绻曞顔衡偓宥佲偓鏂衡偓鏃€鎸欓崶鐑囩礉閹垹顦茬痪顖氬殤娴ｆ洏鈧?
    //   閳跨媴绗?鐟欏绶?閸樺缍囨潻娑樺閺?閺冭绱濈憰浣稿З閻ㄥ嫭妲?*鐏忎線娼扮粩顖滃仯 / gap(50) / 閹貉冨煑閸栨椽顣╃粻?*鏉╂瑤绗侀懓鍛娑撯偓閿?
    //     娑撳秵妲搁崷銊︾摃閸氬秷顢戞稉濠傚缁楊兛绨╂稉顏冪秴缁夌粯绨妴?
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
  /** 闁衡偓閹増宕抽柟顑跨閸炲鈧湱鎳撻惇浼村础閻樼數宕堕柛娆欑秮閻濐喗鎯旈敂鐐暠闁谎勫劤閸ㄥ骸袙閺冩挾绐楅悹鎰綑缁ㄨ櫕绋夐埀顒勫级閳藉懐绀夊鍫嗗棗姣€缂佹稑顦花顒佹交閾氬倻绋戦柡澶涚節閸嬪懏绋夐埀顒勫级鎺抽埀?*/
  private static readonly COLLAPSED_HEIGHT_PERCENT: number = 9;
  /** 閻忕偞娲栫槐鎴﹀礉閵娧勬毎闁汇劌瀚幑锝夋倷绾懐绠婚幖杈捐缁? 閻庣懓鑻崣蹇涘绩閹増宕抽柨娑橆槶閳?*/
  private static readonly EXPAND_START_PROGRESS: number = 100;
  /** 閻忕偞娲栫槐?闁衡偓閹増宕抽柛鏂诲妿閺侀箖寮崼鏇熸瘣闁挎稑娼皊闁挎稑顧€缁辨繃绋夋惔鈥虫闁兼澘鍟导鎰矙?`OPEN_PLAYER_UI_ANIMATION_MS` 濞戞挴鍋撻柤閿嬬暘閳?*/
  private static readonly EXPAND_DURATION_MS: number = 380;
  /**
   * 閻庡湱鎳撳▍鎺曘亹閵忕姴缍侀悘鐐存礀缁辨垿鎯冮崟顒侇槯闂傗偓閸栵紕绀刴s闁挎稑顦埀?
   *
   * 闁哄啰濮烽弲?Tokens 闁汇劌瀚€靛本娼鈧┃鈧俊妤嬬导缂嶅懘寮?300ms / 420ms闁挎稒绋栫换鏍煂鐏炶棄绲?420ms 闂侇叏绲鹃妴鍌炴儍閸曨噮娼庨柟鎵櫐缁辨瑩寮幘顔衡偓澶愬捶閵娧呯礆闁衡偓閹惧懐绀?
   * 婵絾鏌ㄩ惇顒勬焾閵娿儱甯楃紒杈╁У瀹曞弶鎷呭澶嬩粯閻熸洑鐒﹀ú鎸庡緞濮橆厽顦ч梻鍌濇彧缁辨岸鏁嶇仦鐐敜缂佹崘娉曢弫銈団偓鐟板暟濞?`cubic-bezier(0.23, 1.0, 0.32, 1.0)`闁挎稑鐗嗛幓鈺呭礄閾忓湱澶勯柛蹇嬪劵缁辨岸濡?
   */
  private static readonly MORPH_OPEN_DURATION_MS: number = 350;
  /**
   * 閻庡湱鎳撳▍鎺曘亹閵忕姴缍侀柡鈧幆鐗堝闯闁挎稑鐗嗗浠嬪触閹搭垳绀嗛柣銊ュ濡炲倿姊归崠锛勭ms闁挎稑顧€缁辨澘袙閺傝法娼旂€殿喒鍋撻柣锝冨劚閹烩晠鏁嶇仦鐐毆閻犙囨敱濞肩數鎲版担绋垮彙闁兼潙妫庨埀?
   */
  /**
   * 闁稿繑濞婂Λ鎾晬閸繂鍐€闁告碍鍨甸懜浼村矗濮楀牏绀嗛柣?*闁糕晞娅ｉ、鍛村籍閸洘姣?*濞?*闁哄啫鐖奸弳杈ㄧ▔鐎ｎ喗顎欐慨锝嗘煣缁?*闁挎稑鐗嗛顕€寮介崶銊︼骏闁?`MainPage` 闁汇劌瀚悮杈ㄧ▔椤忓嫮鍩楅梺鎻掗獜缁辨岸濡?
   *
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨繃绌遍琛″亾鐏炶棄褰犻梻鍌ゅ幗閹搁亶寮ㄩ幆褎鐝ら柛鎴犲С缁狀喖鈻介垾鍐残楅柣銏＄湽閳ь剙绋勭槐姘舵晬?
   *   `reverseMs = round(REVERSE_MS 閼?max(REVERSE_MIN_RATIO, morphT))`
   *   闁挎稑娼塤recover/logic-src/鐎殿喒鍋撻柛蹇氭珪閹搁亶寮ㄩ幆褎鐝?闁归潧顑呮繛宥囨崉椤栨氨绐為悗瑙勬皑椤?md` 閹? 闂侇偆鍠愰悡?L29 / 閹煎倿宕?閻㈩垱鎮傞崳铏规偘?L620-625闁挎稑顦埀?
   *   闁?婵犲ň鈧磭娼旂€殿喒鍋撻柡?**460ms**闁挎稒绋戣ぐ褔骞忔径濠勭；濞戞挴鍋撻柣鎰贡閸嬶綁鏁嶉崸鍒磑rphT < 0.4`闁挎稑顦板鍌炲箰婢跺鐟撻梻?**460閼?.4 = 184ms**闁?
   *
   * 闁宠法濯寸粭?閻炴凹鍋呭ù娑㈠箲閵忊€崇闁汇劌瀚Λ顐ゆ暜閹间礁娅?`MORPH_CLOSE_DURATION_MS = 350` 闁哄牆顦悮杈ㄥ緞閸曨垱鏅╅柨娑樼墦閸忔ɑ绋夊鍡樞?闁轰焦婢橀埀顒傚帶娴滄洜鎷?闁挎稑顧€缁?
   *   闁?**闁哄啫鐖奸弳閬嶅磻韫囨洜鍙?*闁?50 vs 闁哄啰濮烽弲顐㈩煥閳ュ磭娼旂€殿喒鍋?460闁挎稑鑻惃顖涚?24% 闁汇劌瀚、鎴犵矙鐎ｎ偅顦ч梻鍌濇彧缁?
   *   闁?闁哄洨顥愰々锕傚川閻ｅ本鐣遍柡?*缂傚倹鎸告慨鈺呭极鐎涙ɑ钂嬮柟璺哄閺?*闁挎稒纰嶅Λ顐ｇ閿濆洨鍨抽柣?`cubicBezier(0.23, 1.0, 0.32, 1.0)`
   *      闁? `EASE_OUT_STR`闁挎稑鐭傞崑鍛村及?*闁瑰灚鎸哥槐鎴﹀箵閹邦亝鍞?*闁活潿鍔庡▓鎴﹀即閼碱剙娈犻柨娑橆檧缁辨繄鈧?*闁?15% 闁哄啫鐖煎Λ璺ㄤ焊鏉堫偉娉查悗鐟扮灱鐎?70% 閻炴稑鐬奸埢?*
   *      闁?350ms 闂佹彃鐬肩€?50ms 閻忓繗浜紓澶屸偓鐟拌閳ь兛绀佹晶鎸庣▔?300ms 闁告垹濮崇粻顕€妫冨▎鎰靛壘 = 闁活潿鍔嶉崺娑氭嫚鐎靛憡鐣?**闁告垹濮崇粻顔尖柦閳ュ啿袟闁?*"闁?
   *   闁哄啰濮烽弲?闁稿繑濞婂Λ鎾箵閹邦亝鍞?闁活潿鍔庡▓鎴﹀及?**`REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`**闁挎稑鐗婇崣鍐触椤栨艾袟闁挎稑顦埀?
   *   閻庣懓鏈弳锝団偓闈涙贡閸欏孩绋?闁告帩鍋呴幃璺呵庨摎鍌滅憦濠㈣泛瀚槐锕傚礉?闁汇劌瀚鈺呭及鎼粹€虫櫢闁?`closeFullScreenPlayback()` 闂佹彃琚埀?
   */
  private static readonly REVERSE_MS: number = 460;

  /**
   * `page 0` 閻忓繐绻戦悺鏇犳嫚瀹ュ洦绁查悗闈涚秺閵嗗鎯旈弴鐘崇暠**濞戞挸顑呯敮鍥煂?*闁挎稑婢妏闁挎稑顦埀?
   *
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗呴幈銊╂偨閵婏箑鐓曢悗鍦仦缁佹挳濡寸仦鐐啊闁衡偓閸撗勬珪闂傚牄鍨肩换鏍煂瀹€鍕櫓濞达絽绉查埀顒€绋勭槐姘舵晬濮樻剚娼?`MiniLyricLinesComponent` 闂侇叏绲介ˇ鈺冩嫬閸愵亝鏆忛柣鎰贡濞堟垵鈻旈妸鈺佹珵 闁炽儲鏌￠埀?
   *   閻忓繐绻戦悺鏇犳嫚瀹ュ懎鏂ч柡澶堝劥閸掓稒銇勯棃娑氫亢闁挎稑鏈婊勭附閸婄喐鍎伴柛?`Swiper` 濞戞柨顑呴ˇ濠氭焽閿濆棙钂?*婵繂鑻幃?婵繂鏈晶婊呮啺閸℃瑦纾伴悘?*闁汇劌瀚伴悵顔芥償閿曗偓閻㈩偊鏌屽畝瀣闁?60~690vp闁挎稑顦埀?
   *   闁告瑦鐗曢埀?= `PlayerExpandState` 闂佹彃鏈悺鏇㈠触瀹ュ懏鍋ラ柣銊ュ閻濐喗鎯旈敃鈧ぐ娑橆嚗閸曞墎绀刞LYRIC_META_BLOCK_H_VP = 44`闁挎稑顧€缁?
   *   闁规亽鍔岀槐?濞戞挶鍊涢、鎴﹀棘閸パ呮憻"闂侇叏绲肩粻鐐村緞濮橆剙绁柛娆樺灲缁遍亶妫冨▎鎰靛壘闁诡兛绀侀悾鐘诲矗椤忓懏笑濞戞挴鍋撳☉鎿冧簻濞存劗鈧鐭紞鍛矓娴兼瑧绀?*濞戞挸绉村顒佺▔鎼存繃宕插ù锝嗘礉钘熼梻?*闁?
   */
  private static readonly MINI_LYRIC_SINK_VP: number = 44;

  /** 閻忓繐绻戦悺鏇犳嫚瀹ュ拋鍟囬柛锝冨妿濞堟垹绱掗崟顏咁偨 id闁挎稑鐗嗚ぐ褏绱?{@link PlaybackPage.logLayoutBoxes} 闂佹彃绻戠粊鎾偨椤帞绀夊☉鎾崇Т瀵剚绋夋惔婵囧床濞达絾娲熼埀顒佹缁额偊鏁嶆径鍫氬亾?*/
  private static readonly MINI_LYRIC_BOX_ID: string = 'rzd_page0_mini_lyric_box';

  /** 缂傚啯鍨堕悧鎼佹嚄鐏炵偓鐝悘鐐插€诲▓鎴犵磼閸曨亝顐?id闁挎稑鐗嗚ぐ褏绱?{@link PlaybackPage.logBgLayer} 闂佹彃绻戠粊鎾偨椤帞绀嗛柕?*/
  private static readonly MESH_BG_ID: string = 'rzd_mesh_bg_layer';

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*GLM5.3 濞村吋淇洪惁鏍矗閹寸姴绠涢柨娑欑閸ㄦ粍绋夋繝浣侯伇閺夌儐鍣ｉ崑鍛存焼閹剧粯锛岄柡?婵繂顭峰Λ?**闁?
   *
   * ## 濞存粌顑嗛弲鐘电磼韫囨氨绠栭柨娑樼墕椤┭呪偓鍦仩椤斿洭鏁嶇仦钘夌劶闁告劕绉舵慨閬嶆晬?
   * 闁瑰瓨鍨圭划浼村礃閸涱収鍟囬悘?`.onAppear()` 闁汇劌瀚崢瑙勬償閺囩偛鐎婚柡鈧姘潱閺夆晛娲ｇ粩鎾焼?閻犳亽鍔岄悿鍕瑹鐎ｎ偅顦ч梻鍌氼嚟閻?闂傚偆鐓夌槐婵嬪礆閵堝棗绁﹂柛鎰懅濞堟垿寮?
   * `PlaybackPage.lastCloseAtMs > 0 && Date.now() - PlaybackPage.lastCloseAtMs < CLOSE_WINDOW_MS`闁?
   * GLM 闁圭娲ら崵顓㈡晬?*闁轰胶绻濋崬銈夊礂閹惰姤锛斿ù鐙呯悼閻栨粓鏌岀仦鍓ф⒕闁哄牆顦幑銏℃媴閺囨氨顏遍悶娑樿嫰閸?`lastCloseAtMs`闁挎稑鐭侀埀?`CLOSE_WINDOW_MS` 濞戞梻鍠嶇划鐘诲嫉椤忓嫸绱ｉ柡?*
   * 闁?闂侇叏缍佹禍楣冩⒒?*闁诡厽甯掓禍?*闁挎稑鐬奸悺鎴炵鎼存繄鐭嗗☉鏂跨墦閸忔ê鈻介垾鍐差潱闁靛棗鍊归崹婊堝蓟閵夈劎妲堝ù婊冩濡炲倿姊荤€电娈犻柨娑欏哺閸嬪懏绂掗挊澶夌矗濞达絾绮岀亸顖滅磽閺嶎剛甯嗛柨?3:54闁?
   *   **闁哄懏鐭花顒勫嫉閳ь剟宕ユ惔婵堫伇婵炲棌鍓濋崹姘跺礉閻斿摜鈧垰顕欓悮瀵哥23:49闁?* 闁?**閻庣懓鍟╃划鐘诲嫉椤忓浂娼剁紓鍌涚墳閻ρ勬交?*闁挎稑鐬奸弫銈夊箣閻ゎ垼妫呴柛鎺撳濞堟垿宕犻崨鏉戞闁哄秷顫夊﹢鏉库柦閳╁啯绠掗悗鐟板暔閳?
   * 闁?闁轰焦鐟ㄩ鍕晬?*闁衡偓闁稓鍟婃繝褎鍔楅悥婊嗙疀閸涙番鈧繗銇愰幘铏皻闁哄瀚紓?*闁?闁瑰瓨鍨垫慨鐐寸閸℃稒锛?濞?闂傚倶鍔屽﹢顏呯瑜忔晶鍧楁煂?闁哄嫷鍨悮杈ㄧ閺堢數鐨戦柕?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸儲浠橀悷?閻犳亽鍔岄悿鍕瑹?闁汇劌瀚崹浠嬪箲?
   * 闁哄牜鍓熼妴澶愬箥閳ь剟寮?`@Local` / 缂佸鐒﹀﹢浣衡偓娑欘殕椤斿矂鏌堥懞銉π?*閻庡湱鍋樼欢銉т沪閳ь剟鏌?*闁汇劌瀚哥槐閬嶆嚀?`morphReset()` 濞村吋纰嶆俊?
   * `PlayerExpandState` 闂佹彃鐭傞崑鍛附濡ゅ绀刞morphSessionStarted` / `morphStage` / `morphGeomReady`闁挎稑顦崣蹇撱€掗崨顔肩闁?
   * 闁?闁稿繑濞婂Λ瀛樻媴濞嗘劕鐨鹃柦鈧挊澶嬭含**闁哄倹婢橀悿鍕瑹?*闂婎剦鍋傜粭鍌炲籍鐠佸湱绀夐悗鍦仒缁躲儳浠﹂埀顒勬焾閵娧勭暠闂傚倶鍔岄崣蹇涙焾閵娿儯浜奸柡鍕昂閳?
   *   闁告瑯浜ｉ崗姗€鎮介妸銈囶伇濞?*閻犳亽鍔岄悿鍕瑹鐎ｎ亜褰欏ù?*闁汇劌瀚鍌炲礆鐠囪弓绮甸柛鎺嬪€栧畵?闁?闁哄牜鍓熷銈夊箑娴ｅ摜鎽熸繛鍫㈠仯閳?
   *
   * 闁宠法濯寸粭?**濞戞挶鍊撻柌婊呪偓娑欘殕椤斿矁绠涢崨娣偓蹇涘箣閹邦剦鍤犲ù锝堟硶閺?*闁挎稒鐡猯astCloseAtMs` 闁?*闁稿繑濞婂Λ鎾煣閹规劗鐔?*闁?
   *    闁挎稑娼塩loseFullScreenPlayback` 闁稿繈鍎辫ぐ娑㈡晬婢舵稓绀塦CLOSE_WINDOW_MS` 闁告瑯浜滃﹢顏勵潰閵堝拋妲辩憸鐗堟尵閻涖儵宕ｉ敐鍜佸晬閹艰揪璐熼埀?
   *    闁告帩鍋勯崯鈧柛鎴ｆ楠?闁告瑯浜ｉ鐗堢▔瀹ュ懎鏅?闁挎稑鐗撻崑鍛潰閿濆棙笑濞戞挸锕ｇ粩瀛樻姜椤旂偓鐣卞ù婊冾儐閺呯娀鏁嶆径鍫氬亾?
   */
  private static lastCloseAtMs: number = 0;

  /**
   * 闁?2026-10-17闁挎稒鐭粭鍌涚▔閳ь剙鈻庨垾鍐插綘闂?*閻犙囶暒缁繝鏌呴埀顒勫礌閺嶎剛鐔呯€?*闁汇劌瀚敮顐﹀炊閻欏懐绀勯柣顓у幗閻栵絿绮甸幘鍛耿缂?= 婵炲眲銈堟巢闂侇偀鍋撻柛鏍ㄧ壄缁辨岸濡?
   *
   * 闁?`closeLiveMorphFallback()` 闁告劖鐟ｉ埀顑挎closeFullScreenPlayback()` 闁?`ev('CLO', 闁?` 閻犲洩顕ч懟?*婵炴挸鎳愰埞?*
   * 闁?鐎垫媽濮ら悥锝囩箔椤掆偓瀹曞嫭绋夋径搴斀闁?`CLO:闁?fb=<闁告鍠庡ú?` 閻忓繗椴稿Σ?閺夆晜鐟﹂鍏兼交閺傛寧绀€闁稿繑濞婂Λ瀵告導閹殿喗鐣遍柡鍕靛灠閹烩晠鎮¤缁绘洟寮伴娑欍仧濡?闁汇劌瀚ú鍧楀箳閵夘煈鍤㈤柡浣藉焽閳?
   * 闁宠法濯寸粭?闁告瑯浜滃﹢?闂侇偀鍋撻柛鏍ㄧ墵閸嬪懏绋夐埀顒€鈻?闁哄牆顦埀顒傘€嬬槐婵堟嫚鐠囪尙鏆氶柛妤勬珪缁斿鏁嶉崼婵囧剨闁告帗鐟ょ槐鎵偖椤愩垻绉奸柟瀛樺姇閻栬埖銇欓懡銈呅﹂柟顑跨筏缁辨岸濡?
   */
  private static closeFallbackReason: string = '';

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁稿繑濞婂Λ瀛樻交閸モ斁鏌ら柣銊ュ濡炲倹鎯?濮掓稒鍨电亸鍫⑩偓?** 闁炽儲鏌￠埀?闁瑰灚鎸鹃悧?婵炲备鍓濆﹢浣烘媼閹屾У閻犲洨绮弳?闁汇劌瀚崗濠勪沪閳ь剟鏁?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸繄绠戝銈堫嚙娴犳盯骞?閻犳亽鍔岄悿鍕瑹鐎ｎ喗楗柟顑跨窔閺€锝団偓?
   * 闁活潿鍔嶉崺娑㈠箮閵壯勭暠濞戞挶鍊栧顖炴晬閸稈鍋撶仦钘夊綘闂傚偆鍘藉鍌炴嚄鐏炵偓鐝柛娆樹簻婢ф寧绋夐埀顒勫级鎺抽埀顒€绉查埀顒€鑻崣褔姊婚鐐村€甸柛娆忕墛閺備焦绋夐埀顒勬焼瀹ュ懐娼旂€殿喒鍋撻柕鍡楃▌缁?*闂侇喛妫勮ぐ鍌炴偨閻旈攱韬柛蹇斿▕濡瓨娼婚崶鈹炬煠濞?*闁?
   * 闁?*闁圭虎鍘介弬浣广亜閸忓摜顏?pop闁挎稑鑻惈鍡樼▔婵犲洤浜濆☉鎿冧簻缁愭﹢寮介崶褎鐨戦悹铏瑰枔濞煎啫鈻介垾鑼晩** 闁?濞存粌顑呴幃妤冩嫚鐠佸磭鐟濋柛鎺楊暒閹广垺鎷呴弴姘鳖偨閻熸锟ラ埀?
   * 闁?闁硅泛锕ら崣褔鏌ㄩ鑽ょ殤濞寸姵鍎奸鍥ㄦ交?*婵☆垪鈧櫕鍋ョ紒鐙欏洦楗柟顑胯兌楠炲棜銇愰姀銏㈠闁?*闁挎稑鐬奸悺?*濞戞挸顑勭粩鏉戔枎閳╁啫鈪电€殿喒鍋撻柟缁㈠幗閺備焦銇?*闁告劕绉靛Ο澶岀矆?闁?閻忓繗椴稿﹢浣圭?濞戞挸锕ｇ粩鏉戔枎閳ュ啿褰犻梻?闁汇劌瀚悾顒勫极鐎涙ɑ顦ч幖鏉戠箞閳?
   *
   * ## 閻犱線顣︾划鍫熺▕閸剛绀勯柛娆樹海椤?闁绘鍩栭埀顑挎祰濞村棛绮?濞?闁稿繑濞婇弫顓㈠礄閸濆嫬缍?闁?*濞戞挸绉烽鍥掕箛鎾村**闁挎稑鑻幆渚€宕氬▎鎴濈畾鐟滆埇鍨荤槐锕傚礃闊厾绐楅悶姘煎亜閸╂盯骞掓径娑氱
   * ```
   *   CLO  = closeFullScreenPlayback 闁稿繈鍎辫ぐ娑㈡晬閸繂鏅稿☉?lastCloseAtMs闁?
   *   LV   = morphBeginLeaving闁挎稑鐗婇弫鍦導妞嬪孩绁插ù锝呯▌缁?
   *   SET  = 闁稿繑濞婂Λ鎾绩鐠鸿櫣鍟查悗瑙勭濡炲倿宕抽妸銉ョ厒闁绘劗娅㈢槐娆撴⒔?closeGen / alive / 閻犙囶暒缁繝宕鍐伇闁衡偓椤栥倗绀?
   *   LND  = morphLand闁挎稑鐗愰幆銈夊炊閻愬墎纰冨ù锝囧У濞碱垶鏁?
   *   SQZ  = squashLandAnim闁挎稑鐗婄亸瀣储鐎ｎ厽宕抽柨?
   *   RST  = morphReset闁挎稑鐗嗛崵鎴炴媴閺囩偞绀€闁诡厽甯為悺鎴︽晬?
   *   POPT = 濠㈢懓鍟块惇浼村箮?isShowPlay 缂?false闁挎稑鐗愯闁?popPlayerRoute闁?
   *   REM  = 濠㈢懓鍟块惇浼存儑閻旂儤鐣遍柟璺猴攻閹搁亶寮ㄦィ鍐︹偓澶屾崉椤栨粍鏆犻柛鎺斿У鐢偓濞存粌妫寸槐妾俻opPlayerRoute` 闂佹彃鐬煎▓?`pop/removeByIndexes`闁?
   *          闁?**`RST` 濞?`REM` 闁?`t+` 鐎?*閻忓繗椴稿Σ?婵犲ň鈧磭娼屽☉鎿冨弮濡潡骞€?闁哄牆顦ˇ鍧楁⒐閸栵紕绀勯柣顫妽閸╂稓绮?闁?闁哄绱曞▓鎴﹀礆閵堝棗绁﹂柨?
   *   DIS  = 闁告劕鎳庨鎰沪?onDisappear闁挎稑鐗撳?wasAlive闁?
   *   AP   = 闁告劕鎳庨鎰沪?onAppear闁挎稑鐗撳顔炬導妫颁胶鍟婇柛婵愪簼濞碱垶宕氶崱妯绘殰闁?
   *   INTR = playExpandIntro 閻犙冨殩缁?*闁兼眹鍎遍崵顓㈡偝閺夋寧韬柛蹇斿▕濡瓨绋婄€ｎ亝鍊甸柨娑樿嫰濮樸劑寮?闁告瑥鐗婇弬浣圭▔閳ь剟鏌嗗鍛綌鐎殿喒鍋?闁汇劌瀚ú鍧楀箳閵夈劎妲堥柟?*闁?
   *   OPN  = 濠㈢懓鍟块惇?isShowPlay=true闁挎稑鐗愯闁?pushPlayerRoute闁?
   * ```
   * 婵絽绻橀妴宥囨暜閿旇法顏卞☉鎿冧簽濞村鈧絻顫夊鍌炴⒒鏉堝墽绀刴s闁挎稑鐬煎ù澶屸偓闈涙贡缁憋箓宕橀幓鎺戦殬闂佹彃鐬奸鍥ㄧ▔閳ь剟寮堕埥鍛闁?
   *
   * ## 閻犲洨绮涵鍫曟晬閸繄鐛﹂柡?*缂佹鍓欏畷鍕▔婢跺寒鏀?*闁?
   * 缂傚倹鎸搁崯鍧楀礌?*濞寸姰鍎扮粩鏉戔枎閳ュ啿褰犻梻鍌ゅ幒鐠愮喖宕￠弴姘辩Т**闁挎稑娼塁LO` 濞戞挴鍋撻柛鎺撴緲濮樸劌銆掗崨顖楁晞闂佹彃绉靛鐢告晬婢舵稓绀夐柟纰樺亾濞寸姰鍎撮浼村礆閹殿喗鐣辨慨妯荤摃缁绘瑩寮?闁哄牃鍋撻弶鈺傚灣缁旀潙鈻庨垾鍐插綘闂?闁汇劌瀚崣蹇旀交閸モ斁鏌ら柨?
   * 婵繐绲介悥鍫曞礂閹惰姤锛旈柛姘叄閸ｆ悂寮悧鍫濃叺鐎殿喒鍋撻柨娑樿嫰缁ㄨ尪銇愰幘鑸电畽闁告帗婢橀懜鐗堜繆閸岋妇绐?
   * ```
   *   t0 CLO 闁?t+2 LV 闁?t+480 SET:ok/gen=3 闁?t+481 LND 闁?t+482 SQZ 闁?t+483 RST 闁?t+484 POPT 闁?t+490 DIS:alive=0
   * ```
   * 鐎殿喖鍊搁悥鎯般亹閵忋垹笑濞戞挸楠搁幆鍫熺▕婢舵稓绐?
   * - 闁告垼娅ｉ獮?**`INTR`**闁挎稑鐗嗗﹢?DIS 濞戞柨顑呴幃妤呮晬婢跺棗娅?缁绢収鍠涢濠氬及?闁稿繑濞婂Λ瀛樻媴濞嗘劕鐨鹃梺鎻掔У閺備胶浠﹂弴鐐电；"闁?
   * - 闁告垼娅ｉ獮?**`OPN`**闁挎稑鐗嗗﹢顏堝礂閹惰姤锛旀繛鍫濆悁缁狅綁宕ユ惔顖滅闁兼澘鐬奸弫銈夊箣瀹勬媽瀚欐繛宀嬬磿閸嬶絽顕ｉ埀顒勬晬婢跺棗娅?濠㈢懓鍟块惇浼村箮婵犲啯灏￠柡鈧ィ鍐︹偓澶愬矗閸喎鑵瑰ù婊冩缁旀潙鈻庨埥鍛耿
   * - `SET:genBAD` / `SET:dead` 闁?闁衡偓鐠鸿櫣鍟查悗瑙勭濡炲倿宕抽妸銊ㄦ巢濞存粌妫欏Λ顓㈡焻閳ь剟寮ㄩ銈囩**闁告垹濮崇紞宥嗙▔瀹ュ嫮绐楀璺虹С缂?* 闁?闁煎啿鏈▍娆撳矗椤忓嫬鈷栧☉鎾亾闁哄鈧櫕鍊辨繝褎鍔х槐姘舵晬?
   * - **婵炲备鍓濆﹢?`RST`** 闁?`morphReset()` 婵炲备鍓濇晶鐣屾偘?闁?闁告垹濮崇紞宥夊磻濠婂啯韬☉鎿冨弮濡潡骞€娓氬﹦骞?
   * - `RST` 闁?`REM`闁挎稑鐗愰惌楣冩偨鏉堚晜鍩傞悶姘煎亜閸ㄥ綊骞掓径娑氱**濞戞柨顑呮晶鐘垫惥閸涙壆绠栧☉鎾亾閻?* 闁?閻庢稒锚濠€?pop 濞存粌妫旂徊楣冨礄閻樿京绉跨€规瓕灏欑划鈥愁煥閳ュ磭娼?闁汇劌瀚懙鎴︽⒒閺夋垶濮?
   *   闁挎稑婀橪M 闁汇劌瀚禍锝囨媼閹惧懐绀夐幖?23.3 闁炽儲鏌￠埀?濞戞梻鍠庡銊╁及椤栨粍鏆忛柟鎾棑椤?闁?闁哄绱曞▓鎴﹀磹濞嗘挴鍋撴径瀣皻闁告帟顔愮槐姘跺Υ?
   */
  private static evLog: string = '';
  private static evT0: number = 0;
  private static evCount: number = 0;

  /**
   * 閻犱線顣︾粩鎾级閳╁啯顦ч幖鏉戠箣缁ㄣ劍绂掔拋鍦閻?{@link PlaybackPage.evLog}闁挎稑顦埀?
   * @param tag 濞存粌顑勫▎銏ゅ触瀹ュ繒绀勫☉鎾筹躬濞间即鏌囬敐鍛倞閻炴稏鍔戦崳鐑芥儍閸曨厾鍙氶柡宥呮川椤掔兘鏁?
   * @param detail 闁告瑯鍨堕埀顒€顦卞▓鎴犳偘閵夈儱甯犻柨娑樼墔缁躲儲淇?`ok` / `genBAD` / `dead`闁?
   *
   * 闁宠法濯寸粭?**public static**闁挎稑鐗呯粭澶愬及?private闁挎稑顧€缁辩増绔熼崘鑼勾 `products/default/.../pages/Index.ets` 闁?
   *    `@Monitor('appState.isShowPlay')` 闂佹彃鐭侀々锔炬媼?`OPN` 闁炽儲鏌￠埀?闁靛棗鑻崣褔姊婚鐐村€甸柛娆忕墛閺備焦绋夐埀顒勬焼瀹ュ懐娼旂€殿喒鍋撻柕鍡楃Ф濞?
   *    濠㈣埖娼欒ぐ璺ㄢ偓姘灱閺嬫帞浜告潏銊π?*濠㈢懓鍟块惇浼村箮婵犲啯灏￠柡鈧ィ鍐︹偓澶愬矗閸喎鑵瑰ù婊冩缁旀潙鈻?*闁挎稑鐭傞崑鍛▔閳ь剛绮弬鍨锭闁哄牆顦敍鎾朵沪閸屾繂鍘撮悹浣藉焽閳?
   *    闁挎稑鐗嗛敍鎾朵沪?闁?闁圭虎鍘介弬浣广亜閸偅笑闁告娲栭幃婊勭瑹濠靛﹦顩柨娑欑摢player` 闁汇劌瀚妴濠囧棘閸ワ附顐界€规瓕灏欑划锛勨偓鐢靛帶閸?`PlaybackPage`闁挎稑濂旂粭澶愬几閸曨剙鐏囩€甸偊浜為獮鍡涘Υ閸岋妇绀?
   */
  public static ev(tag: string, detail: string = ''): void {
    const now: number = Date.now();
    // 闁?缂傚倹鎸搁崯鍧楀礌鏉為绨?*濞戞挴鍋撴繛鍡忊偓鍐插綘闂?*濞戞挸鎼畷鐔告媴瀹ュ繒绐梎CLO`闁挎稑鐗嗛崣褔姊婚銏℃嚑閻犱警鍨伴崣鍡涘矗閿濆繒绀嗗☉鎾亾闁告帗婢樺銊╁箮婵犱胶鐟愬☉鎾亾閺夌儐鍠楅弳锝呪枔閸偆顏搁柟鍝勵槶閳ь兛姊梩0` 闂佹彃绉堕悿鍡涘礆閹峰瞼绠瑰☉鎾亾闁告帗鐪归埀?
    //   濞戞捁妗ㄧ划鍫熺▕閸絿绠归柡宥呭槻閸ㄥ繘鏁嶅顒傜崷闁哄秴娲﹀Σ?*缂佹稑顦粭鍛▔閳ь剙鈻庨埄鍐ㄢ叺鐎殿喒鍋撻柟缁㈠幗閺備焦銇?*闁归潧绉靛Ο澶岀矆閾忚鐣遍柨娑樼墕閸櫻囨⒒椤撯懇鍋撻弬鎹愬幀濡炪倗鏁诲鏉款啅閼碱剛鐥呴悶?pop闁挎稑顧€缁?
    //   闁兼眹鍎扮粭澶娿€掗崪鍐閻犲洩顕ч崺宀勬儍閸曨剚笑"濠靛倽妫勯崵鎴炴姜椤斿€熺┛闁革负鍔嬬粩瀵告導?闁汇劌瀚Λ鈺勭疀濡ゅ绀塦t+` 濞戞梻鍠嶇槐鐗堢▔閳ь剟鎯勯弶鎴犵獢濞戞挸锕ョ€规岸宕氶幍顔界畽濞戞挸绉撮崵顓㈡儎缁嬫鍤犻柡鍐硾缁參濡?
    //   闁告帒娲﹂崹?闁哄牃鍋撻弶鈺傚灣缁旀潙鈻庨垾鍐插綘闂?濞戞柨顑呴幃妤呮晬瀹€鍐惧殺婵炲娲栧銊╁炊閸濆嫮鏆伴柟?`t+0 CLO 闁?闁炽儺娉﹂柕?
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
    // 闁绘粠鍨伴懜浼存晬濮樺磭孝閺?900 閻庢稒顨堥浣轰焊鏉堚晝鍩嗛柟鍝勵槹濞撳爼寮埡鍛簼婵炲牏顣槐娆愮┍濠靛懐绉?闁哄牃鍋撻弶鈺傚灩濞堟垿宕楅幎鑺ワ紨闁稿繈鍔忕换鍐矙?闁?
    if (PlaybackPage.evLog.length > 900) {
      const cut: number = PlaybackPage.evLog.indexOf('|');
      if (cut >= 0) {
        PlaybackPage.evLog = PlaybackPage.evLog.substring(cut + 1);
      }
    }
  }

  /** 闁稿繑濞婂Λ瀛樻媴濞嗘劕鐨剧紒鎰殔瑜版盯鏁嶉崸顣欓柨娑橆槴閳ь剚鏌￠埀?`lastCloseAtMs` 闁汇劌瀚鏃€鎯旈敂琛″亾閸屾顔忛柨?鐎规悶鍎抽埢濂稿礆閵堝棙鐒介柛濠勩€嬬槐婵囩▔瀹ュ棙笑闂侇偄妫楅幃婊堝磹绾绀勯悷娆庢缁楀倿寮涵鍜佸殯闁哄嫬鍑界槐姘跺Υ?*/
  private static readonly CLOSE_WINDOW_MS: number = 1500;

  /**
   * `scheduleMorphResetAfterPop()` 闁汇劌瀚悿鍡欐嫚閵忋倖锛熼梻鍛缁辨獡s闁挎稑顦粭宀勫嫉閳ь剚寰勮椤愬ジ寮懜顑藉亾?
   *
   * 闁宠法濯寸粭?**鐎规悶鍎抽埢濂稿礆閵堝棙鐒介柛濠勩€嬬槐婵囩▔瀹ュ棙笑闂侇偄妫楅幃婊堝磹?*闁挎稒纰嶅Λ銈夋偩鐏炲墽姊鹃柡鍫濐槼缁绘牠寮?缂?pop 闁告劕绉撮ˇ鍙夋媴?闁汇劌瀚Ο澶婎嚕韫囨氨鏋傞悹?
   * 闁挎稑鐗嗛悾鐘绘儍閸曨垬鈧妫冮姀鈩冃︽俊顖楀墲閳ь兛绶ょ槐婵嬪绩閹増宕抽悗鐟版湰閸ㄦ岸宕￠崘鎻掔セ閺夌偞鏋荤槐姘跺Υ閸屾繄绠归梺鎻掕嫰瑜把囧及椤栨碍绀堝☉鎾跺劋閸ㄦ粍绂掗鍌涚暠閻犱警鍨抽弫?pop 闁?*鐎殿喖鍊归?*闁汇劌瀚ㄩ埀?
   * 32ms 闁?濞戞挶鍊曢幎姘舵晬? 婵?闁?256ms 濞戞挸锕娲晬閸絿孝闁哄啳娉涢崢瑙勬償閺囩儐妲诲ù锝呯▌缁辨繄鈧€涚瑜版煡寮插顐ょ槏濞戞挸绉烽崗妯荤▔瀹ュ棛顏搁柨娑橆槶閳?
   */
  private static readonly RESET_POLL_MS: number = 32;
  private static readonly RESET_POLL_MAX: number = 8;

  /** 濞戞挸锕ｇ粩鏉戔枎?`RzdBgLayer` 闁汇劌瀚鐑藉触瀹ュ繒绀勯柤鍝勫€圭粊锕傛晬婢跺牃鍋?*/
  private lastBgLayerLog: string = '';

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16 闁哄倹婢橀·鍐嫚婵犲啯鐒介柨?*闁煎啿鏈▍娆戜沪閸屾艾鐓傞幖瀛樻礃濡插憡寰勫顑句海闁靛棔绀侀ˇ鎸庣▔瀹ュ鍋撹箛鏃€顫?*闁?
   *
   * ## 閻庣懓鍟崹鑺ョ閳ь剚绋婇崼顒傜闁活潿鍔嶉崺娑㈠矗瀹ュ拋妲婚柟韬插劤濞堟垶绋夐妶鍡樿拫闂侇喕绮欏顒傗偓鐟板暙閻ｉ箖骞€瑜濈槐?
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdBgLayer'
   *   闁?RzdBgLayer box=(x,y,w,h) win=WxH clip=闁?p=闁?op=闁?squashing=闁?meshSrc=yes|no playing=闁?
   * ```
   *
   * | 閻犲洩顕ч崺宀勬儍?| 闁告凹鍋傜粻?|
   * | --- | --- |
   * | `box.w/h 闁?win` **濞?`op 闁?1`** | 闁煎啿鏈▍娆撳极閺夋垹娼屽☉鎾崇Ч閳ь剙绻戝Σ?闁?閺夆晜鐟︽晶鐘诲及椤栨ǚ鍋?*闁煎啿鏈▍娆撳礂閵娿儳娼?*闁靛棗绉跺▓鎴ｃ亹閵忋垹笑 |
   * | `box.w/h 闁?win` 濞?`op` 鐎垫澘鐗嗛惃顒勬晬?.04~0.3闁?| 闁煎啿鏈▍娆撳极閺夋垹娼屽ù锝呮閸ゆ垶绋婃惔銊㈠亾韫囨梹顫?闁?**濞戞挸瀛╁Λ銈夋偩鐏炶姤鍊辩憸?*闁挎稑鐗婂Λ銈夋偩瀹€鍕簼閻忕偛鍊风弧鍐捶閵婏箑濮悘鐐茬箰閻即鏌屽畝瀣 |
   * | `box.w/h` 闁哄嫬瀛╁Ο澶屼焊韫囧海鑹?`win` | 闁煎啿鏈▍娆戞偖椤愶附顎欓柛鎺曟硾濠€顏嗕焊韫囨洜宕堕柛娆欑秮閸ｇ兘鏁嶉崼婵嗙稐濞戞挴鍋撶紒澶婄Т閼镐即鎮╃拋鍦 |
   * | `meshSrc=no` | 缂傚啯鍨堕悧绋库柦閳╁啰鐖?闁?閻忕偛绻嬬粭鍌炲及?*闁稿繑绮岀花鎶藉矗閺嶃劎澹夐柤?*闁挎稑鐗嗗﹢顏嗙棯閹稿海鎽冮柡鍥ㄧ叀閸嬪懐浠﹂崒娑櫺?`rgba(20,20,22,0.5)`闁?|
   *
   * 闁宠法濯寸粭?闁告瑯浜ｉ浼存晬濮橆厽鎷遍柡鍌濐潐绾埖绋夊鍛櫢濞寸姾顔婄紞宥夋偐閼哥鍋撴担纰樺亾?
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
   * 闁硅矇鍐ㄧ厬闁?*濞戞挸顦伴宀€绱掗幘瀵糕偓?*闁汇劌瀚悮閬嶅冀閻熸澘绐楀ù锝呯У濞碱垶鏁嶉崼銏㈢煁濞?id闁挎稑鑻ぐ褏绱?{@link PlaybackPage.logLayoutBoxes} 闂佹彃绻戠粊鎾偨椤帞绀嗛柕?
   *
   * 闁告垵鎼ˇ鈺呮晬濮橆厽锟ラ柣?overlay 闁?builder 闁哄秵鍩婄槐妾倃ujie.pa:190464` / `190497`闁挎稑顦埀顒佹煛閳?
   * ```
   *   Row().height(lerp(swiperGap(), 10, swiperProgress))   // 190464  闁?"Swiper 闁?閺夆晜绋戠€规娊寮?
   *   Row().height(chrome().gapScrub)                       // 190497  闁?"閺夆晜绋戠€规娊寮?闁?濞磋偐濮剧欢顓㈠级?
   * ```
   * 闁宠法濯寸粭?閻庣懓鍟╁?*濞戞挸绉靛Σ?padding**闁挎稑鏈Σ?*闂傚棜娉涢崬瀵糕偓?Row**闁挎稑娼塁olumn` 闂佹彃鐬煎▓鎴﹀疾椤曗偓閳ь剚鑹鹃崢鏂款嚕閻旇螡闁绘劗娅㈢槐姘跺灳閺傝　鍋?
   *   闁圭鍋撳ù?濞戞挸顦伴?闁?`[Swiper | gapSwiper 閻?| gapScrub 閻?| 閺夆晜绋戠€规娊寮?濞磋偐濮剧欢顓㈠级椤☆枽闁?
   * 闁宠法濯寸粭?闁哄啰濮烽弲顐︽焽閿濆嫯鈷堝ù鐘垫櫕閺併倝鎯冮崟顒佇?`.height(lerp(...))`闁挎稑鐣璴erp` 缂佹鍏涚粭浣衡偓鍦仜瀵剟寮?`swiperProgress`闁?
   *   闁归攱鐗楃€氬潡骞嶉幘宕囩；/闁稿繑濞婂Λ鎾儍閸曨喚绠栫紒瀣儎閼垫垶娼诲▎搴も拡闁哄秷顫夊顖涘濮樺磭顎€闁活偀鍋撻悶娑栧劦濡潡鏁嶉崸鍒?swiperGap, b=10`闁挎稑顦埀?
   *   闁瑰瓨鍨冲鎴炴交濞嗗海顏卞〒姘€鍕⒕闁?`swiperProgress` 閺夆晜鐟ら柌婊堟煂韫囥儳绀勯柟瀛樺灣濠婃垿鎯冮崟顐ゆ綌鐎殿喒鍋撻弶鈺傜☉鐎规娊宕?`morphP`闁挎稑鐭侀銏＄▕婢跺鐟濋柛姘焿缁辨岸鏁?
   *   闁圭鍋撳ù?*闂傚牊鐟﹂娑㈠箑娴ｇ绲?`swiperGap()` 闂侇叏绲肩粩瀵哥博?*闁? `lerp(t=0)`闁挎稑顧€缁辨繆銇愰姀鐘茬秮闁哄牏鍠嶇粭澶愬礉?闁炽儲鏌￠埀?閻熸瑤鐒﹂弻鐔封枖閺囩喐鏆堥梺鎻掝焾閳?
   */
  private static readonly SWIPER_GAP_ROW_ID: string = 'rzd_gap_swiper_row';
  private static readonly CHROME_SCRUB_GAP_ROW_ID: string = 'rzd_gap_scrub_row';

  /**
   * @returns 闁靛棗顒玾iper 闁?閺夆晜绋戠€规娊寮舵幊閳ь剙绉村畷鐗堟媴瀹ュ棙钂嬮柣銊ュ閻濐喗鎯旈敂鑲╃vp闁挎稑顦埀顒佹煛閳?闁哄啰濮烽弲?`swiperGap()`闁挎稑娼墂ujie.pa:180127`闁挎稑顦埀?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸絿绠归梺鎻掓湰濡?*濞戞挴鍋撳☉鎿冧簻閻栧爼寮?*闁靛棔妞掔粭澶愬及?`lerp`
   *
   * 闁哄啰濮烽弲顐﹀礃濞嗘垶鐣遍柡?`lerp(swiperGap(), 10, swiperProgress)`闁挎稑鑻畵?*闁归攱鐗楃€氬潡骞嶉幘宕囩；/闁稿繑濞婂Λ瀛樻交閸モ斁鏌ゅ☉?*閺夆晜鐟﹂悧鎾级?
   * 濞?`swiperGap()` 闁衡偓鐠哄搫鐓?10vp闁靛棔绻杝wiperProgress` 闁?*閻庣懓鍟抽崵婊冾啅鏉堚晜鐣?*濞戞挸顑嗘刊鐑樻交濞戞ê顔婇梺鎻掗獜缁?闁? 閻庣數鎳撶花鏌ュ礂閹惰姤锛旈柛鏂诲妺缂嶆棃鏁嶆径娑氱
   * 闁瑰瓨鍨冲鎴炴交濞嗗海顏卞〒姘€鍐惧殸閹煎瓨姊诲▓鎴﹀及?`expandState.morphP`闁挎稑鐗嗛惈宥咁嚕閳ь剚娼诲☉妯侯唺闁?*闁哄倻鎳撻幃婊勭▔鎼达絾绁插ù锝呯Ч閸忔ɑ绋夊鍛€?*闁?
   * 闁瑰瓨鍨冲鎴﹀及?濞寸姴姘︾化鐘虫媴閻樿櫕钂嬮梻鈧崹顔肩厒闁轰焦娼欓惈?闁挎稑鑻悾鐘诲及?濞寸姴瀛╅弳锝囦沪韫囨挾绐斿☉鎾愁儐鐎氬鎸?闁挎稑顦埀?
   * 闁?缁绢収鍓欓〃?`lerp(..., morphP)` 濞村吋鑹剧欢閬嶅礆?*闁告瑥绉跺ù?*闁汇劌瀚ú鍝ョ棯閸栵紕绀勯悘鐐存礀缁辨垿寮捄鍝勫唨闁兼澘鏈弫鍦玻閸曞墎绀嗛柨娑樼焸閸嬪懘寮?*闁哄倷鍗抽埀顒傚С缁斿瓨绋夐鍥舵斀濞?*闁?
   *   濞戞挸绉靛Σ鎼佹偂瑜庨幆澶愬Υ閸屾稑顣插ù鐘劦濞笺倕顫㈤姀鈾€鍋撴担瑙ｅ亾娴ｈВ鍋撴担鍝ユ澖閻庡湱鍋涜ぐ?`lerp` 闁?`t=0` 闂侇叏绲肩粩瀵哥博椤栥倗绀刞swiperGap()`闁挎稑顧€缁?
   *   妤犵偠鍩栨俊?鐟滆埇鍨硅ぐ澶愬嫉閻斿嚢澶愭⒒?闁谎勬椤斿洦绋夐崫鍕闁告梻鍎戠槐妾俁zdMusic鐎垫澘鎳愰垾妯兼媼閵堝棛顏搁柛?md` D4-b闁挎稑顦埀?
   */
  private swiperGapRowHVp(): number {
    return this.expandState.swiperGapVp();
  }

  /**
   * @returns 闁靛棗鐭佺换妯绘償閿旇姤钂?闁?濞磋偐濮剧欢顓㈠级鎺抽埀顒€绉村畷鐗堟媴瀹ュ棙钂嬮柣?*濡増绻傞ˇ?*濡ゅ倹锚鐎规娊鏁嶉崸纾掗柨娑橆槶閳?
   *
   * 闁宠法濯寸粭?闁诡厽甯婄拹?0闁?*濞戞挸绉靛Σ绋款煶韫囨挷绮?*闁挎稒淇虹换鏍ㄧ▔閳ь剙鈻撻悽鍨暠闂傚倻顥愮粣娑㈠箣閹存粍绮?*鐎规瓕灏欑划锟犲嫉婢跺鍟?*闁挎稑濂旂紞鍛磾椤斿吋韬?
   *   `ControlAreaComponent.bottomPanel()` 闂佹彃鐭傞崑鍛▔?`Column` 闁?`.margin({ bottom: 闁?})`
   *   闁挎稑鐗婄€垫粓寮鐘蹭化闁?`app.float.slider_margin_bottom*`闁挎稑顦埀顒€鍊瑰Λ銈夋偩瀹€鍐︹偓鍐煂瀹€鍐濞戞挴鍋撴繛鍫ユ涧瑜?`gapScrub`
   *   闁挎稑婀桿LL 28 / MEDIUM 20 / COMPACT 14闁挎稑顦埀?
   * 闁?閺夆晜鐟╅崳閿嬬┍濠靛牊娈屽☉鎾亾濞?0 濡ゅ倹顭囧▓鎴﹀矗椤栫偛娅ゆ繛鏉戭儓婵☆參鎮欓惂鍝ョ**闁告瑯浜欑拹?*闁?閻庡湱鍋炵粊鎾⒒绾惧鐛?vs `gapScrub`"闁瑰灚鎹佺换姗€寮妷銉х
   *   闁挎稑娼塕zdSwiperBox`闁挎稑顧€缁辨繄绮垫径灞惧焸闁哄牏鍎ら弳鐔煎箲椤斿吋绀€闁哄鍎遍崯鈧柛鎰暱閻ｉ箖寮?闁?margin 闁瑰箍鍨洪崹?`gapScrub`"閺夆晜蓱濡?濞ｅ洦绻勯弳鈧繛鏌ョ畺閻撳爼宕㈤悢灏佸亾?闁?
   *   闁绘粍婢樺﹢?*濞戞挸绉撮懟鐔烘偘鐏炶棄顫?*闁挎稑鐗嗛幆渚€宕氬▎蹇旂殤闁哄嫷鍨伴幃鎾寸▔閳ь剙鈻撻悽鍛婏紵閻犵儤绻€鐞氶亶寮堕垾鍐茬稉鐎?闁炽儲鏌￠埀?闁哄牜鍏涚划銊╁矗瀹ュ拋妲婚棅顏佹櫈缁诲啴鎯冮崟顐ュ煂闁绘顔愮槐姘跺Υ?
   */
  private chromeScrubGapRowHVp(): number {
    return 0;
  }

  /**
   * 闁?2026-10-15 閻犲洤锕ラ弻鍥煥濮樺崬浠柨娑欑婵?*闁搞儲绋愰柌婊勫濮橆偆闉嶉柣鈺冾焾鐢洭鎯冮崟顐ｅ仴**闁汇劌瀚悰銉╁矗閿濆洨鍙愮憸閭︽線缁旀潙鈻庨埄鍐ㄢ叺闁告垹鍎ゅ鐢稿Υ?
   *
   * 闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdBoxes'`
   *
   * 闁瑰灚鎸惧▓鎴﹀及?*缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨?*闁挎稑娼塯etPositionToWindowWithTransform()`闁挎稑顦粭?*閻庡湱鍋炵粊瀵镐焊閸濆嫷鍤?*闁?
   * 濞戞挸娴烽弫銈夊箣闁垮鐒婚柛銉ュ⒔濞堟垿宕撹箛鏇狀槺闁告瑯鍨禍鎺楁儎鐎涙ê澶嶉柟骞垮灮閻ｈ崵鈧數顢婃径鍕晬閸喐鎷遍柡?1224閼?776 闁规惌浜滃ù?闁?3px/vp闁挎稑顧€缁?
   * ```
   *   RzdBoxes cover=(x,y,w,h) title=(闁? singer=(闁? lyric=(闁?
   * ```
   * **闁告帇鍊栧畵渚€鏁嶉崼婵囨喛濞戞挶鍊撻柌婊堝锤濡ゅ啯鍩傞柣銊ュ濞村绂嶉妶鍐ｅ亾娴ｅ憡鐨戦柡鈧ぐ鎺戜簼濞戞挴鍋撻悗鐢垫缁?*闁?
   *   鐠?`lyric.top` 闁解偓閽樺韬?`[singer.top, singer.bottom]` 闁告牗妞藉Λ鍧楀礃?闁?**閻忓繐绻戦悺鏇犳嫚瀹ュ懎绔鹃柛锔哄妽閻℃洟宕?婵繂鏈晶婊堟焽閿濆嫮顏遍悶娑樺缁?*
   *     闁?閻?`MINI_LYRIC_SINK_VP`闁挎稑鐗婂﹢鐗堢閹惧啿鍤掗柟?濞戞挶鍊涢、鎴﹀棘閸パ呮憻"闁汇劌瀚伴崳铏圭棯瑜忕划?44闁挎稑顧€缁?
   *   鐠?`lyric.bottom` 閻℃帒锕ㄧ换鍐箳瑜嶉崺妤呭礌濞差亗鈧﹥娼?闁?閻忓繐绻戦悺鏇犳嫚瀹ュ牜娼堕柟璨夊啫鐓戦柛鏍ф惈鐢洦鎷?闁?闂侇叏绲惧Σ鎼佸矗閿旇法顏卞璺哄缁辨┎wiper 闁哄鍟撮崳鎼佸礆閸℃稑甯抽柨娑橆檧缁?
   *   鐠?`cover.bottom` 濞?`title.top` 闁汇劌瀚板Λ璺ㄦ崉?闁?0 闁?婵繂鑻幃鏇犳瑜戦崚娑氫焊娓氣偓濞间即鏁嶉崸鍑℡RIC_META_GAP_VP` 闂侇叏绲肩粩鏉戭浖閿濆繒绀嗛柕?
   * 闁宠法濯寸粭?闁告瑯浜ｉ浼村Υ娴ｉ鐟濋柛鎰懕缁变即寮甸浣圭厵婵炲娲戠粭澶愬绩閻熸澘缍佸ù鐘侯唺缂嶅秹鎮╅懜纰樺亾娓氬﹦绀勫☉鎾崇С缁辨媽銇愰姀鈥崇亣"闂佹彃绻戠粊鎾焼閹烘挻鏆柣妯垮煐閳ь兛璁查崯瀣礃瀹ュ娅ゆ繛?闁汇劌瀚鎾偝椤栥倗绀嗛柕?
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
    // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁靛棗鏈悺鏇㈠触瀹ュ牜鏀介柛妯侯儏濠€顏呮交濞戞ê顔婇柡澶嗏偓鑼憪闁靛棗绉跺▓鎴﹀矗椤栫偛娅ゆ繛鏉戭儏閸ㄤ粙骞?*闁?
    //   `chromeTop` = `gapSwiper` 闂侇叏绲鹃悧鎾础閻樿京绉撮柡澶涚磿濞堟垹鈧湱鍋炵粊瀵哥玻濡も偓瑜版稒銇勯幆鎵彾 = **闁硅矇鍐ㄧ厬闁告牜鍎ら婊勭▔婵犲啯鐓?*闁?
    //   `metaTop` = 婵繂鑻幃鏇犳偘?*閻犱焦宕橀鎼佸磹?*闁挎稑娼塵etaTopGeomY`闁挎稑顧€缁辨紮metaBoxTop` = 婵繂鑻幃鏇犳偘?*閻庡湱鍋炵粊?*濡炪倖鍎肩粩鐔煎Υ?
    //   闁告帇鍊栧畵渚€鏁嶅姝甧taBoxTop + LYRIC_META_ROW_H_VP > chromeTop` 闁?缁绢収鍠栭悿鍕储鐎ｎ厾绠婚柟璨夊啫鐓戦柛?
    //   闁挎稑鐗撻崑鍛村籍閹偊鍤夐柛鏂诲妿濞堟垿寮伴妯峰亾鐏炵晫娈遍梻鍫涘灮椤忣剟鎮?/ gap(50) / 闁硅矇鍐ㄧ厬闁告牗妞介。鈺冪不濡炲皷鍋撳鍫㈢濞戞挸顦抽埀顒€鎳嶉懙鎴︽儍閸曨亞顏卞☉鎿冧悍缁?
    //     **濞戞挸绉烽々?*闁革负鍔嶉悺鏇㈠触瀹ュ牜鏀藉☉鎾筹工閸熲偓闁告梻濮捐棢闁稿銇樼紞鍛矓?闁炽儲鏌￠埀?闂侇叏绲肩槐浼村箣閹邦亣绀嬬紒妤婂厸缁ㄢ晜绋夐鍐Т缂佸绮花顕€鏁嶆径鍫氬亾?
    //   闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdMetaChrome'`
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMetaChrome chromeTop=${this.boxTopY(PlaybackPage.SWIPER_GAP_ROW_ID).toFixed(1)} ` +
      `metaBoxTop=${this.boxTopY(PLAYER_META_TITLE_ID).toFixed(1)} ` +
      `metaTop=${this.expandState.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP).toFixed(1)} ` +
      `rowH=${PlaybackPage.LYRIC_META_ROW_H_VP} ` +
      `coverBottom=${(this.coverLocalRect().y + this.coverLocalRect().height).toFixed(1)} t=${this.lyricMorphT.toFixed(3)}`);

    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*闁硅矇鍐ㄧ厬闁告牞妗ㄧ粭浣糕枔閻㈢數娉㈤柡?*闁汇劌瀚顔炬嫻閿旇姤锛夐煫鍥ㄣ仠閳?
    //   闁告帇鍊栧畵渚€鏁嶉崼銏″焸闁哄牐妗ㄧ粭鍌涚▔閳ь剙鈻庨垾铏殤濠㈠墎鍣︾槐姘舵晬濮橆剛鏉芥繛?Swiper 濡ゅ倹锚鐎?vs `estBoxH()`闁? `usableH 闁?chromeTotal`闁挎稑顧€缁?
    //   濞寸姰鍎卞閿嬬▔閵堝棛澹岄柛妤冨С缂嶅懘寮堕敍鍕暠閻庡湱鍋炵粊瀛橆殗?vs 閹煎瓨姊瑰﹢浣诡殗濡硶鍋撻崒姘枙鐎电増顨呴ˇ?闁?闁瑰瓨鍨冲鎴﹀箳瑜嶉崺妤呭礌閾忚鐣遍柤濂変簽閸斞勵殗濡儤瀚查柡鍐Х閺咁偆鎮伴妸銉殸濞戞挸绉崇粭鍌炴晬?
    //   闂侇叏绲惧鍌炲礃瀹ュ懎鏋€閻?鐎垫壋鍋撻悶娑栧姂閸ｉ鈧潧缍婄紞?閺夆晜蓱濡?闁衡偓鐟欏嫬鐏夊ù鐙€鍓濋崵婊冾啅鏉堚晜鐣卞Δ鍌浢€?闁?*濞戞挸绉烽々锔界▔閵堝懌浠堝☉鎾亾閻犙囨敱閺?*闁挎稑顦埀?
    //   闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdSwiperBox'`
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

  /** @returns 闁哄本鍔掗柌婊呯磼閸曨亝顐?id 闁?*閻庡湱鍋炵粊瀛橆殗濡搫顔?*闁挎稑婢妏闁挎稑鐭傞崳鐑樼▔瀹ュ懎鐓傞弶鈺傛煥濞?-1闁挎稑顦埀顒佹煛閳?闁告瑯浜炵划鎵嫚婵犲啯鐒介柡鍐﹀劚缁绘棃鎮介妸锝傚亾?*/
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
   * @returns 闁哄本鍔掗柌婊呯磼閸曨亝顐?id 闁?*缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨煎銈嗗劶缁?*闁挎稑婢妏闁挎稑鐭傞崳鐑樼▔瀹ュ懎鐓傞弶鈺傛煥濞?-1闁挎稑顦埀顒佹煛閳?闁告瑯浜炵划鎵嫚婵犲啯鐒介柡鍐﹀劚缁绘棃鎮介妸锝傚亾?
   *
   * 闁?2026-10-17闁挎稒鑹炬慨鐐碘偓鐟板暞濡插憡绋夋潪鎵晩缂備焦鐟ｉ埀?*婵繂鑻幃鏇犳偘鐏炶棄绔鹃柛锔哄姀缁绘ɑ鎯旈敂鑺ヨ拫濞?*闁靛棗绉风换鏍ㄧ▔閳ь剟寮堕垾鑼伇濞?*闁告瑯鍨堕崳鍝劽圭€ｎ剚鐣遍柛鎺嬪€栧畵?*
   *   闁挎稑鐗婇崹婊冾潰閵堝懎顤呴柛娆樹海閸忔﹢妫冮悩鍐茶吂缂?chrome 濡炪倖鍎肩粩鐔兼晬鐏炴儳鑵归柛鎴犲劋濞煎灚绋夐妶鍜佹闂侇喖鈧喎娈版繛鍙夋灮缁辨繄绮垫径澶岃壘婵炲备鈧啿鐏查柟璇″櫙缁辨岸濡?
   *   闁绘粍婢樺﹢顏堝箮?`gapSwiper` 闂侇叏绲鹃悧鎾础閻樿京绉撮柡澶嗘缁? 闁硅矇鍐ㄧ厬闁告牜鍎ら婊勭▔婵犲啯鐓欓梺顓ㄧ导缁旀挳寮介惂鍝ョ闁汇劌瀚悿鍕圭€ｎ喓鈧﹥娼忕憴鍕叺闁告垹鍎ゅ鐢告晬?
   * ```
   *   闁告帇鍊栧畵渚€鏁嶅绀絫le.y + 閻炴稑鐭傞悵?> gapRowTop(闁?闁硅矇鍐ㄧ厬闁告牗妞介妴濠冩綇?  闁?婵繂鑻幃鏇犳偘瀹€鈧垾妯尖偓鍦仜鐢洦娼诲☉娆忎粯闁告帟娉涚亸?
   *   闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdBoxes'`
   * ```
   * 闁宠法濯寸粭?闁?`getPositionToWindowWithTransform()`闁挎稑鐗嗛幆鍫⑩偓鍦嚀濞呮帡宕ｅΟ璇插簥闁挎稑顦崳?鐟滆埇鍨硅ぐ澶愬嫉閻旀椿鍤㈤柡渚€顣︾弧鍐╁濮樺磭顎€闁活偀鍋撻柛娆愶公缁?
   *   闁圭鍋撳ù鐘劚瑜把囨儑?*闁解偓閽樺鏆伴柟?*闂侇叏绲介崵鎴犳偘鐏炵儵鍋?
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
  /** 闁稿繑濞婂Λ鎾籍閸洘姣愭慨锝嗘煣缁躲儵鎯冮崟顏嗙憮闂傚嫭鍔х槐妾俶orphT` 閻忓繐绻嬬花顒傗偓鐟板暞濡炲倿骞愭径濠勬殜缂佺姵顨愮槐姘跺灳閺傝　鍋?閻庝絻顫夐悥锝夊籍閻樺灚娅?`REVERSE_MIN_RATIO = 0.4`闁?*/
  private static readonly REVERSE_MIN_RATIO: number = 0.4;
  /**
   * 闁绘劗鎳撻崵?閻犙囨敱閹搁亶骞囪箛鎾寸闁瑰灚鎸哥槐鎴﹀籍鐠佸湱绀夐悶娑栧劦濡?*鐎点倛娉涢幃妤佺▔閵堝懏濮?*闁告劕绉烽幑锝夋晬閸ь暀闁挎稑顦埀?
   *
   * 濡炪倗鏁诲鐗堟交濞嗗海顏遍悽顖嗗嫬顤呴柛鎺撶鐎垫洘娼慨鎰ㄥ亾娴ｇ晫绠锋繛宀嬬磿閺佺偓娼婚崶鈺婂剳濞戞挴鍋撻悽顖嗗秶骞㈤柛姘嫰閹舵氨鎸ч悿顖€澶愭⒒鐎靛憡鐣遍悹鍥ㄧ箰缁辨繄绮垫径宀婂剳濞戞挴鍋撻悽顖嗗懏鍩傞柣銊ュ閺侀箖宕欓悜妯婚檷闁?
   * 闁告柣鍔庨弫鎯ь啅閼碱剛鐥呴悹褔顣︾花锟犲礄閻樻彃纾╂慨锝庡亞椤?闁炽儲鏌￠埀?闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣銊ュ濮樸劑寮?闁烩晛鐡ㄧ敮鎾倷閻熸壆纾婚柡鍕靛灟缁姵绋夐銏★紵鐎殿喒鍋撳┑顔碱儑濞?闁?
   */
  private static readonly MORPH_INTRO_DELAY_MS: number = 50;
  /**
   * 濞戞挴鍋撴繛鍠°倗顎€闁归潧顑勭槐鎵嫚濠靛牊鐣遍柡鍫氬亾闂傗偓閸喗鍊ら柣鐐叉濡炲倿姊归崠锛勭ms闁挎稑顦埀?
   *
   * `pullDragging` 婵炲牆顑囬弳鈧柡鍐ㄥ閸嬶綁宕欑紒妯衡叺鐎殿喒鍋撳ù鍏间亢閻戯附娼婚崶褑鍩岄柛娆惷崹鍨叏鐎ｎ亜顕ч柨娑樼墦閳ь兘鍋撻柛鏍ㄧ墬閸ㄦ岸鎳撴担绋啃楅柣顫串缁辨岸鏁嶅畝鍐闁哄绻濆Σ鍥磹閼测晜鏆忛柡?
   * 闁告帇鍊曢悾?閺夆晜鐟ら柌婊堝冀閸ヮ亶鍞剁€规瓕灏欑划鈩冩交閸ャ劍鍩?闁挎稒鐭粩鏉戔枎閳ヨ尙鐟愰柟?濞戞挸顑嗘刊鐑樼▔瀹ュ懎璁查柤瀹犲Г鐎垫梻绱?2 缂佸甯婃禍鎺撶▔婵炲簱鍋?
   */
  private static readonly PULL_DRAG_MAX_MS: number = 2000;
  /**
   * 闂佹寧姘ㄩ崑锝嗘交濡崵姊鹃梺鎻掔箰閸╁矂寮崜浣圭暠闂佹彃绉烽惁顖炴⒒閹绢喗顓鹃柨娑樻桨s闁挎稑顦埀?
   *
   * "闁绘劗鎳撻崵顕€骞嶉幘宕囩；"闂侇叏绲肩粩鎾礆閺勫繒纰冨ù锝囧У濞?闁圭虎鍘介弬浣广亜闂堟稓鍩楅悽顖涚摃缁绘洖鈻介垾宕囶伌閻忕偐鍋撻悗鐟扮焿缁辨獋getFrameNodeById` 闁瑰嘲銇樼粭澶愬礆閹峰苯螡闁绘劗娅㈢槐姘舵晬?
   * 闁哄啰濮烽弲顐︽儍閸曨偂绮垫繛澶嬫礃濡?*婵炲鍔岄崬鐣屼焊鏉堚晛宕曢柛銉у仩閻ㄧ喓绮垫径灞剧祷**闁靛棔娴囬埀顒€濂旂粭澶愬及椤栫偐鍋撻埀顒勫礌閺嶃劌鐏囬柤棰佺婵晠鎮芥导娆戝耿闁瑰瓨鍨冲鎴炴交濞嗘挸娅￠柣顫妼閸ゆ垹鏁閸ｅ摜鎷犻弴鐘垫惣濞寸姴鍢查悿鍕偝閼割兘鍋?
   */
  private static readonly MORPH_RETRY_MS: number = 32;
  /**
   * 闁告挴鏅欑紞鎴︽煂瀹ュ牏妲告繛鍡忓墲閺嗙喖鏁嶉崼鐔烘Ж婵炲棌鍓濇晶锕€顕ｉ埀顒勬煂瀹ュ洨鏋傞柨娑橆槴閳ь剚鏌￠埀?**闁绘挆鍕￠柛娆忕Ф缁鳖亞鎷犻幋鐘崇暠 `PlayerPage.schedulePublishRetry`**闁?
   *
   *   闁哄牃鍋撳鑸靛哺閸ｅ摜鎷?12 婵炲枴鎵冲亾娴ｅ湱妲ㄦ繛鍡節濡潡姊?32ms闁挎稑鐗婇埀顒冨吹閻涖儵宕ｉ敐鍥ь唺 384ms闁挎稑顧€缁辨繈鎮介妸锔介檷缂?闁告帗纰嶇€垫洘娼慨鎰ㄥ亾娴ｇ晫绠锋繛灞糕偓宕囶伌閻忕偐鍋撻悗?闁?
   *   闁烩晩鍠楅悥锝夋嚍閸屾粌浠柛娆惿戦崹姘跺矗椤栫偛娅ゆ繛鏉戭儍閳ь剙鍊稿鐣岀磽閺嶎剛妲紓浣规崄椤旀垿鏁嶅顓燂骏闁伙絽鐬煎▓鎴﹀箻椤撶喐鏉瑰?*濞戞梻鍠嶇粭澶屾暜閹间讲鏁?*闁挎稑鐗嗛幃鎾诲冀闁垮笑 push 闁告垹鍎ゅ鐢告儍閸曞墎绀嗛柨?
   *   閻庣懓鍟╃粻锝夊箥閳ь剚绂?缂佹鍏涚粩鏉戔枎閳ヨ櫕鐨戦柡鍫濐槸閻ㄦ繈妫冮姀銈庢＇闁?闁挎稑鐭傚顒勬儍閸曨偅鐨戦柡鍕靛灥缁绘牗绋夐鍫濇閻犲洦娲滈悰銉╁矗?+ `setFinalStatus()` 闁稿繑绮岀花鎶藉Υ?
   */
  private morphRetryLeft: number = 12;
  /**
   * 闁靛棗鑻ぐ鍙夌閵夈儳纾诲┑顔碱儑閺佺偓绂嶉崱鎰ㄥ亾瀹ュ洦鐣遍梻鍌ょ厜缁辨媽銇愰姀鐘茬秮闁活亞鍠愰婊冾嚕閳ь剚鎱ㄧ€ｅ墎绀勯柛鎴犲С缂嶅秹鏌岃箛鎾崇厒妤犵偠娉涚敮鍥礆閹峰本宕抽柣鎰缁辨碍绋婄€ｎ亜顤呴柨娑樻湰閺嗭絾銇勯崗鍝ョ闁?*闁稿繈鍔戦埀顒€绻戝Σ?*闁?
   *
   * 濞戞捁妗ㄧ划鍫熺▕閸儲浠橀悷鏇氱閻ｇ娀鏁嶅顐ョ濞存粌妫楅崢娑㈡煂韫囨挸鐓?闁告鍠庨弰鍌溾偓闈涙憸濞堟垹浜告笟鈧浼存儗閳轰浇鍩?闁挎稑鏈€垫洘娼挊澶嬪€甸柛鎺撴緲閼镐即宕ｅΟ铏圭；濠殿喖顑勭粻锝夋⒒缂堢姷绐楅柡?1~2 閻?
   * 闁圭虎鍘介弬浣广亜闂堟侗妲卞ù?*闁哄牜浜炵紓澶屼焊?*闁绘鍩栭埀?闁炽儲鏌￠埀?闂侇叏绲介崵鎴犳暜瑜戠€氥垽鎮¤閻栧墎绱掑Ο鍝勭厬閻忓繐褰夌槐浼存⒒椤忓啰顏卞☉鎾愁儏閻ｎ剟寮€涙ɑ灏￠柡鈧ィ鍐︹偓澶愬Υ?
   * 闁稿繗娅曠敮鈧紓浣姑崺妤佺▔瀹ュ懎顨涢柛婵嗙Т缁旈浠﹂埀顒勬晬閸у埣pacity` 濞戞挸绉村顒佺▔鎼达紕顏撮悘鐐╁亾闁挎稑顧€缁辨繈骞嶉埀顒佺閵夆晛娅ゆ繛鏉戭儑閸欏海鏁宀€绠婚悶娑樿閳?
   */
  @Local introPaintReady: boolean = false;
  /**
   * 鐟滆埇鍨硅ぐ澶愬籍閳哄倹鍩?閹煎瓨娲熷鐗堬紣濠婂棗顥?婵烇絺鈧啿寮抽柣銊ュ缁捇鎮欑涵鍛閹艰揪璁ｇ槐?闁?闁挎稑顦埀?
   *
   * 閺夆晞娓圭紞姗€寮堕垾鑼槏闁哄嫷鍨板﹢顏呮交濞嗗酣鍤嬮弶鈺傜☉鐎瑰啿菐閳ュ磭鏆氶柣銊ュ缁辨獋PlayerExpandState.miniBarOpacity` 闁?0.20闁挎稑顧€缁?
   * 濞戞挶鍊涚粩鐔荤疀閸涙番鈧繒鈧潧缍婄紞鍫ユ晬濮橆剛淇洪梻鍫緛缁辨瑦鎯旈弴鈥愁棌 + 闁告瑦鐗炴竟濠勪沪閸岋妇绀嗛柛鎺撳缁绘牠鏌岀仦缁㈠妧濠靛倽濮ゅΣ鎼佸箻椤撶喐鏉瑰銈囨暩濠€鈥愁潰閿濆洦鐣遍柤鍐叉湰濞呮瑩鎳濈拠褏绀?
   * 閺夆晞娓圭紞姗€寮堕垾鍐茬厒閺夆晜鐟╅崳宄邦潰閿濆懌鍋ㄦ繛鎴濈墕閵?闁炽儲鏌￠埀?閻熸瑥鍊归崝鍛焊鏉堛劍笑"闁圭虎鍘介弬渚€寮堕敍鍕暠濡増绮忔竟濠囧礌閺嶃劌鐏囧ù婊冩閵嗗妫冮姀锝呭壒闁哄拋鍨埀顑跨閼荤喓鎹勯悢鐑樼祷闂傗偓閸喓浜?闁?
   */
  private static readonly MORPH_BG_FADE_TO: number = 0.20;
  /**
   * 閻忓繋绶氬?+ 婵繂鑻幃鏇㈠Υ瀹€鈧悽缁橆槹閻愭彃鐓傛慨婵嗙焷閻︽繃銇勯悽鎼炩偓濠囨焾閵婏絺鍋撳鍥ㄧ暠闁哄啫鐖奸弳閬嶆晬閸ь暀闁挎稑顦埀顒€鍊归惁顔句沪閺囩偟纾婚柣锝冨劤閻擃參鏁嶇仦鑺ョ濞戞挸鎼悾鐘诲矗椤忓懏笑閻忕偐鍋撻梺顔哄妼閸樻挾妲愰悩鍐插簥濞达絽绉查埀?
   *
   * A2 閻犙呮焿缁绘牠寮堕埄鍐╊槯闂傗偓?*闁活亞鍠撳▓鎴犳偖椤愩倖鏆忓☉鎾筹梗缁?*闁挎稑娼塧nimateLyricMorph` 闁?`animateTo`闁挎稑顧€缁卞崬顫㈤妶鍛枀闁轰焦娼欓〃婊冾潰瀹€鍐Г濡?
   * 閻忓繋绶氬鎷屻亹閵忕姴缍侀悶?`lyricMorphVisible = false` 闁哄啰濮靛顖涚鐠哄搫褰犻柣顐熷亾闁挎稑鐭佺换鏍ㄧ▔椤忓嫮鍩楅梺鎻掔箲濡插摜绮氶搹瑙勭暠闁?
   */
  private static readonly LYRIC_MORPH_DURATION_MS: number = 360;
  /** 闁硅矇鍐ㄧ厬闁告牗妞藉銈咁潰閵忕媭妯嬪☉鏂挎噹閹鎳涢鍕楅柡鈧幆鐗堝闯闁挎稑娼皊闁挎稑顦埀?*/
  /**
   * 闁硅矇鍐ㄧ厬闁?*缂佸本妞藉Λ浠嬫嚊椤忓嫬袟闁衡偓閹増宕?*闁汇劌瀚悺鎴濐嚗閸涱喗顦ч梻鈧崠锛勭ms闁挎稑顦埀?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`PlayerPage.IDLE_MS`闁挎稑顧€缁?*5000**闁?
   *   闁告垵鎼ˇ鈺呮晬濮濇ujie.pa:197964` 闁?`stlexvar 0x0, 0x8` 闁告挸绉崇粩鎾级?`ldai 0x1388`
   *   闁挎稑娼?x1388` = **5000**闁挎稑顧€缁辨繈鎳?`startIdle()`闁挎稑娼墂ujie.pa:179936-179938`闁?
   *   閻忓繗椴稿Σ?`setTimeout(<娴?, IDLE_MS)`闁挎稑鐭傞崑鍛▔?娴ｅ秹鏁嶉崸?93408-193418`闁挎稑顦禒娑欑閳ь剚绋婇崼鐔感﹂柡鍕捣閳ユ﹢鎯冮崟鍓佺獥
   *   `idleTimer = -1; this.hideChrome();`闁?
   * 闁宠法濯寸粭?闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉柡?**3000**闁挎稑鐗婂﹢鐗堢閹剧懓娈伴悗瑙勮壘閳ь剛銆嬬槐婵嬪籍閻樻彃姣夊璺哄缁辨岸鍩?閺夆晜鐟ュ銊╁及?缂佸本妞藉Λ浠嬪籍閸洘锛熷☉鎾崇С缁旀挳寮?闁汇劌瀚闈涒攦閹扳斁鍋?
   */
  private static readonly CHROME_AUTO_HIDE_MS: number = 5000;
  /**
   * 闁硅矇鍐ㄧ厬闁?濞存粠鍠栭崵?/ 闁衡偓閹増宕?闂侇叏绲惧顖滄偘閵夆晜锛熼柣銊ュ濡炲倿姊归崠锛勭ms闁挎稑顦埀?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`PlayerPage.CHROME_ANIM_MS`闁挎稑顧€缁?*350**闁?
   *   闁告垵鎼ˇ鈺呮晬濮濇howChrome()` 濞?`hideChrome()` 闁告艾瀚崵婊堟焽閿濆棭鍋?`animateTo(...)` 闁?`duration`
   *   闂侇喛濮ゅΣ?`throw.undefinedifholewithname "CHROME_ANIM_MS"`
   *   闁挎稑娼塴ogic-src/PlayerPage.abc.txt` 闁?11967-11976 濞?4210-4219闁挎稑顧€缁?
   *   閻㈩垱鎮傞崳娲磹?350 閻?`_recover/logic-src/MiniMorph婵炴挸寮堕悡瀣棘闁稓鐟㈠銈堟硾缁ㄦ娊寮借箛鏃囩獥闁稿繈鍎遍崣鏇烆嚕?md:163`
   *   闁挎稑娼塁HROME_ANIM_MS | 350 | 濡炪倛鍩栭悥顕€寮版ィ鍐╊吅闁哄啫鐖奸弳閬嶆晬? D_MAIN闁挎稑藝闁挎稑顦埀?
   *
   * 闁宠法濯寸粭?闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉柡?**240 + `Curve.EaseIn`闁挎稑鐗婇弫鍦導閸戙倗绀? `Curve.EaseOut`闁挎稑鐗嗛弫婊堝礄閻氬绀?*闁?
   *   闁?*闁哄牜鍏涚划銊╂嚊椤忓嫮鏆伴柛?*闁挎稑鐗婂Λ銈夊礄閸濆嫷妲遍柨娑橆槴閸?闁?濞戞挸绉烽蹇斿緞閻熸壆鏁ㄩ柤濂変簽缁鳖亪宕?闁衡偓鐟欏嫬鐏囬柡鍐Х閺咁偊鏌囬敐鍕拡濞戞搩浜滈埀顒傘€嬬槐?
   *   **350ms + `Curve.EaseInOut`闁挎稑鐗婂Ο澶愬Υ娓氣偓濞堬綁宕ョ仦鑲╊伇闁哄鍓濆ú鍝ョ棯閸栵紕绀嗛柕?*
   */
  private static readonly CHROME_ANIM_MS: number = 350;
  /** 闁归潧顑嗗┃鈧紒?Swiper 闂佹彃琚埀顒€鏈悺鏇犳嫚瀹ュ鈧濡村鍥ㄧ暠濞戞挸顑嗛悥锝夋晬? = 閻忓繋绶氬鐗堛亜绾板绀嗛柕?*/
  private static readonly SWIPER_INDEX_LYRIC: number = 1;
  /**
   * 婵繂鐭侀惁婵嬪礌?*濞戞挸锕ｇ粭鍛煥閹存繂鐎奸柟骞垮灪鐢爼宕氱捄鍝勯殬**闁汇劌瀚板Σ鍥磹绾绀剉p闁挎稑顦埀顒佹煛閳?闁绘挆鍕￠柡鍐Х閺?`SWIPE_TOGGLE_VP`闁?
   *
   * 闁告垵鎼ˇ鈺呮晬濮濇瓍layerPage.onLyricSwipe`闁挎稑娼塤recover/logic-src/PlayerPage.abc.txt:6942` 闁?
   * `throw.undefinedifholewithname "SWIPE_TOGGLE_VP"`闁挎稑濂旀禍鎺楀矗?*濡ゅ倹蓱閺?*闁汇劌瀚悺褔妫冮姀銈呮
   * `6974 ldai 0x18` = **24**闁挎稑顧€缁辫精銇愰幒鎾扁偓鍌滄暜閹间礁娅ら悶?`MiniMorph婵炴挸寮堕悡瀣棘闁稓鐟㈠銈堟硾缁ㄦ娊寮借箛鏃囩獥闁稿繈鍎遍崣鏇烆嚕?md:171`
   * 闁告艾鏈悧杈╂媼閹殿喗绲?`SWIPE_TOGGLE_VP | 24`闁?
   * 闁宠法濯寸粭?闁哄牜鍏涚划銊╁储閻斿憡闄嶉柛鎰懅濞堟垿寮?**12**闁挎稑鐗愰崵婊呪偓瑙勬皑濞堟垶绋夐埀顒勫础婵犲繒绀嗛柍?濠㈤浜滈鎰板及閹捐鍤栭悷娆欒缁辨瑩寮甸鈧惇浼村及?`parallelGesture`闁挎稑顦埀?
   */
  private static readonly SWIPE_TOGGLE_VP: number = 24;
  /**
   * 婵繂鐭侀惁婵嬪礌?*濞戞挸锕ョ划锕傛⒕閹邦垱顥戦柟璨夊啫鐓戦柛?*闂侇叏绲肩粩鎾绩椤栨稒笑闁告熬闄勯弬浣割嚕閳?闁炽儲鏌￠埀?閻庣數鎳撶花鏌ュ籍閻樺灚娅曢柣?`entryAllowsManual(lyricImmersive)` 闂傚倶鍔婇埀?
   *
   * 闁哄啰濮烽弲顐︽晬濮濇瓱ntryAllowsManual(mode) = mode === MANUAL || mode === BOTH`闁挎稑鐭侀埀?
   * `LyricEntryMode` 濮掓稒顭堥璇差浖閿濆棙笑 **AUTO**闁挎稑娼夋慨婵嗙焷閻︽繃銇勯崹顐ョ檨閻忕偛鍊搁惃婵嬫椤厾鐟㈡慨婵嗚嫰閹洜鈧姘ㄩ…?md` 閹?闁挎稒鐡孎F0 / AUTO1 / MANUAL2 / BOTH3闁?
   * 闁?**濮掓稒顭堥璇差浖閿濆嫮鐟?濞戞挸锕ョ划锕傛⒕閹邦垱顥?濞寸姭鍋撳☉鏂跨墦閸忔ɑ绋夊鍛驳**闁挎稑鐗撻崑鍛▔閳ь剟寮ㄩ娑欐婵炲牅绲婚～锕傛⒒閵婏箑鐨″ù锝呴獜缁辨岸濡?
   * 闁哄牜鍏涚划銊モ柦閳╁啯绠掗弶鈺傜懁闁叉粓鎮介妸锕€鐓曢悹浣稿⒔閻ゅ棝鏁嶉崼銉︽〃闁哄娼￠崳宄扳柦閳╁啯绠?婵炲苯顦伴煫鍫濐潰瀹€鍐Г婵☆垪鈧磭纭€"閺夆晜鐟ょ粩瀛樸亜閻у摜绀嗛柍?闁?*濮掓稒顭堥?*閻炴稑濂旂拹鐔煎Υ?
   *
   * 闁宠法濯寸粭?**闁衡偓閻熺増绀€ true 閻忓繗椴稿Σ?濞戞挸锕ョ划锕傛⒕閹邦垱顥戦柟璨夊啫鐓戦柛?闂佹彃绉甸弻濠囨偨閻斿憡娅?*闁挎稑鐗呯粩瀵告偘瀹€瀣闁挎稒绋戦崙锟犲捶?
   *   `RzdMusic鐎垫澘鎳愰垾妯兼媼閵堝棛顏搁柛?md` 缂?33 闁哄绻濋崳鐑藉及鎼达絺鈧﹢姊婚鑽ょ☉"閻熸洑妞掔粭澶屾啺娴ｇ晫绠瑰☉鎿冧簼婢ф粓宕?闁?
   */
  private static readonly LYRIC_SWIPE_ALLOWS_MANUAL: boolean = false;

  /**
   * "婵犲﹥鑹炬慨鈺傜瀹ュ懏韬弶鈺傜椤?闁汇劌瀚崹鐣屸偓瑙勬皑閻涖儵鏁嶉崸顣欓柨娑橆槴閳ь剚鏌￠埀?閻?`lastScrollAtMs` 闁汇劌瀚弫鐐烘煂婵炲簱鍋?
   *
   * 闁?2026-10-16闁挎稒淇虹换鏍ㄧ▔閳ь剟寮?*濞戞挸绉靛Σ鎼佸礉閵娧勬毎闁哄啫鐖奸弳閬嶅Υ娴ｉ鐟濋柡鍕靛灥椤洭骞囬悢宄版闁?*闁挎稑鐭侀埀顒€鏈Σ?濞戞挶鍊楅～鎺撱仚閸楃偛袟闁哄倻鎳撶槐锟犵嵁鐠鸿櫣鎽?闁哄啫澧庡▓鎴炵閼奸姊块柨?
   *   `onContentDidScroll`闁挎稑鐗撻埀顒佸姇閹舵碍娼诲☉妯侯唺闁挎稑顦紞瀣偓纭呭煐濡炲倿鏁嶇€瑰炒yncLyricMorphToPage()` 闁?闁解偓閽樺鏆?闊洤鎳橀妴蹇曟媼閳衡偓缂嶅懘濡?
   *   闁宠法濯寸粭?120ms 闁?7 閻㈩垎宥囩獥闁归潧顑嗙€垫岸骞庨鍐╁闯闁?swiper 闁汇劌瀚崕濠氬箑瑜庣划鎾礉閵娿倗顏遍柛瀣玻缁辨繈鎷冮挊澶屾毎閻忓繗绮鹃崗姗€骞掗妷褜鍚€闁衡偓鐠鸿櫣鍟查柕?
   *   闁宠法濯寸粭?閻庣懓鍟╃粭?`Swiper` 闁煎浜滅换渚€鎯?`duration` 闁哄啰濮撮崣褔鏁嶉崼銉ヤ簼濞戞搩浜滆ぐ褔宕烽妸褉鏌ら幖鏉戠箰鐎垫煡宕氶崶顑锯偓澶愬籍閹増宕冲ù锝嗙矌閺併倝鏁嶆径鍫氬亾?
   */
  private static readonly SCROLL_SETTLE_WINDOW_MS: number = 120;
  /**
   * 婵繂鐭侀惁婵囥亜閻㈢浜濆☉鎾亾婵☆垼浜ｉ、鎴︽晬閸繍鍤犻柡宥呮处濡倝鎮?`metaRow`闁挎稑顦卞▓鎴﹀箳閹烘柨顣奸悽顖涙倐閸?闁炽儲鏌￠埀?闁轰焦婢橀埀顒傚帶瑜板洭鎳?
   * `PlayerPage閻庣懓鏈弳顤汭閻庤姘ㄩ…?md` 閹?.2闁挎稒纰嶉悥锝嗭紣?`15` / 缂侇喗銇炵紞?/ 闁?/ `opacity 0.86`闁挎稑鏈悺鏇㈠箥?`12` / 閻㈩垱鐡曢～澶愬Υ?
   */
  private static readonly LYRIC_META_TITLE_FP: number = 15;
  private static readonly LYRIC_META_ARTIST_FP: number = 12;
  /**
   * **閻忓繋绶氬鐗堛亜閻㈢浜濆☉鎾亾缂?*闁汇劌瀚悺鏇㈠触?婵繂鏈晶婊呪偓娑欘殔瑜板潡鏁嶉崸鎶柨娑橆槴閳ь剚鏌￠埀?閻庝絻顫夐悥锝夊籍閻樺灚娅?`chrome().titleSize` / `chrome().artistSize`闁挎稑婀桿LL 婵℃缍囩槐姘跺Υ?
   *
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁遍亶寮甸鍐瀭濞寸姴楠搁悺褔鎳為崒婊呭灣闁圭粯鍔曡ぐ鍥晬?*闁告艾鏈鍌滅棯閻樻剚鍔€闁瑰瓨鍨崇粭鍌涚▔閳ь剚娼鐐暠濞戞挴鍋撳璺哄椤曘倗鎷?*闁挎稑顧€缁?
   *   闁哄啰濮烽弲顐︽焽?*濞戞挴鍋撳☉?* `Text` 闁汇劌瀚悺褔宕ｉ柨瀣?*闁圭粯甯掗埀?*闁告垹鍎ゅ鐢告儍閸曞墎绀刞wujie.pa:194905-194939`闁挎稑鐣璴erp` 濞戞挸顦顒傛嫬閸愵亝鏆忛柨娑橆檧缁?
   * ```
   *   fontSize( lerp( chrome().titleSize * sizeK(),   // 閻忓繋绶氬鐗堛亜閻㈡浼?= 20 閼?sizeK
   *                   15 * sizeK(),                   // 婵繂鐭侀惁婵囥亜閻㈡浼?= 15 閼?sizeK
   *                   metaProgress() ) )              // 閺夆晜绋戠€规娊鏁? swiperProgress闁?
   * ```
   *   婵繂鏈晶婊堝触瀹€鈧幃濠囨晬濮濇erp( chrome().artistSize * sizeK()(=14), 12 * sizeK(), metaProgress() )`闁?
   *   闁?**閻忓繋绶氬鐗堛亜?20 / 14闁挎稑鏈悺鏇犳嫚瀹ュ鈧?15 / 12**闁挎稒鐭杝izeK()` 闁?缂佹劖顨呰ぐ娑氣偓纭呮鐎规娊鎯冮崟顐㈡瘣闁?
   *     闁挎稑鐗婃晶婊堝嫉鏉炴壆鐟?闁?闁挎稑鑻柦鈺呭级?PC 闁归潧绉靛﹢浣割啅?闁炽儲鏌￠埀?閻?`RzdMusic鐎垫澘鎳愰垾妯兼媼閵堝棛顏搁柛?md` E5闁挎稑顦埀?
   *
   * 闁宠法濯寸粭?闁瑰瓨鍨冲鎴﹀储閻斿憡闄?*濞戞挶鍊濋妴澶愭焾閽樺绁奸悗?15 / 12** 闁?**閻忓繋绶氬鐗堛亜閸偆鎽冮柛姘Т娴滃摜浜?33%闁?5 vs 20闁?*闁靛棔鐒﹂悺鏇㈠箥鐎ｎ亙鐒婇悘蹇撻獜缁?2 vs 14闁挎稑顦埀?
   * 闁宠法濯寸粭?濞戞挸锕ｇ粩瀛樻姜椤曞棛绀勯幖?6.27闁挎稑顦伴崹婊勭▔閳ь剚鎯旈敂钘壩╅悗鐟板暢椤曚即骞?閻庢稒顨呰ぐ璺ㄦ啺?*濞?* `metaProgress()`"闁挎稑鑻懟鐔煎箲椤旂瓔鍔冮柛?濞戞挸绉烽蹇涘绩? 闁炽儲鏌￠埀?
   *   **闂侇叏绲奸柌婊呮嫚缂佹銆婇柡鍕靛灦閺佸﹪鎯?*闁挎稑鐗婃俊?`lerp` 鐟滅増鎸婚崹姘閸℃洜顔掓繛澶嬫穿缁辨繃绂嶆惔銏⌒﹀ù鐘劙鐠愮喓浜告笟鈧鐗堛亜閸忓摜绐楅柛娆惿戦崹?0 闁告瑥鍢查悺褔鏁嶆径鍫氬亾?
   *   闁活亞鍠撳ù澶愬及椤栨稑绲婚柛濠勩€嬬槐鎵偓娑欘殔瑜?*濞寸姴绨肩粭澶娾槈閸縿浜?*闁挎稑鑻ぐ褔寮?*闁?20 闁衡偓鐠哄搫鐓?15**闁靛棗鍊瑰﹢鐗堟姜椤旇棄鐦婚柣顏嗗枔濞村寮ㄧ憴鍕靛妧闁?
   */
  private static readonly META_TITLE_FP_COVER: number = 20;
  private static readonly META_ARTIST_FP_COVER: number = 14;

  /**
   * 鐟滅増鎸告晶鐘虫交濞嗗海顏遍悽顖嗗懏鐣?*婵繂鑻幃鏇犫偓娑欘殔瑜?*闁挎稑娼歱闁挎稑顦埀顒佹煛閳?濞戞挶鍊楅顒佺▕鐎ｎ喗锛熼柟?*婵繂鐭侀惁婵囥亜娴ｅ啰绠婚幖?*闁圭粯甯掗埀顒傤儠閳?
   *
   * 闁?闁?`lyricMorphT`闁挎稑鐗婂﹢鐗堛亜?閻忓繋绶氬鐗堛亜?闁?婵繂鐭侀惁婵囥亜?闁汇劌瀚换妯绘償閿旇偐绀嗙憸鐗堟尰濡倝鎮?`metaProgress()` 闁汇劌瀚悺鎴炵妞嬪骸鈷栭柨?
   *   闂傚牊鐟﹂娑㈠捶閵娿儳娈遍梻鍫涘灲閵?= 0 闁?`20fp`闁挎稒鐩銈咁潰閵忕姵韬慨婵嗙焷閻︽繃銇?= 1 闁?`15fp`闁挎稒绋戦崹蹇斻亜閻㈢浜?360ms 闂佹彃鐭佺换娑氱磼椤擄紕绠栨繛鎾€鎵冲亾?
   * @returns 婵繂鑻幃鏇犫偓娑欘殔瑜板潡鏁嶉崸鎶柨?
   */
  private metaTitleFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_TITLE_FP_COVER,
      PlaybackPage.LYRIC_META_TITLE_FP, this.lyricMorphT);
  }

  /**
   * 鐟滅増鎸告晶鐘虫交濞嗗海顏遍悽顖嗗懏鐣?*婵繂鏈晶婊呪偓娑欘殔瑜?*闁挎稑娼歱闁挎稑顧€缁辩櫗14`闁挎稑鐗嗛惃婵嬫閵忋們鈧鏁嶆径鍡楁櫔 `12`闁挎稑鐗婇悺鏇犳嫚瀹ュ鈧鏁嶆径鍫氬亾閸屾粍鍊為柣銏犲船閹?{@link metaTitleFp}闁?
   * @returns 婵繂鏈晶婊呪偓娑欘殔瑜板潡鏁嶉崸鎶柨?
   */
  private metaArtistFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_ARTIST_FP_COVER,
      PlaybackPage.LYRIC_META_ARTIST_FP, this.lyricMorphT);
  }

  /**
   * 濞戞挶鍊楅顒佺▕鐎ｎ喗锛熼柣銊ュ閸ゅ酣骞€瑜庤ぐ鍐磹绾绀刞t` 濠㈠墎鎳撻崺?0..1闁挎稑顦埀顒€鍊荤划鐗堢▔婵犲洦妗ㄥ☉鎾卞€撻柌婊呪偓娑欘殔瑜板潡鎮介妸锝傚亾?
   * @param from `t = 0` 闂侇叏绲肩粩瀵哥博椤栨粍鐣遍柛?
   * @param to `t = 1` 闂侇叏绲肩粩瀵哥博椤栨粍鐣遍柛?
   * @param t 閺夆晜绋戠€规娊鏁嶉崼婊勫床闁规澘绻愰悿鍕极鐢喚绀夐柛鎰嚇閸庡瓨寰勯悷鏉跨悼闁?
   * @returns 闁圭粯甯掗埀顒冨亹缁劑寮?
   */
  private static lerpFp(from: number, to: number, t: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return from + (to - from) * p;
  }
  /** 閻忓繐绻愰惃婵嬫閵忕姴绀佺紓鍌浢崺灞筋潰鐏炶姤鍊抽柣銊ュ濡法鎹勫┑鎾剁vp闁挎稑顦埀?*/
  private static readonly LYRIC_META_GAP_VP: number = 12;
  /** 閻犲洢鍎撮、鎴﹀矗閸忓懏娅犻柣锝嗙懅濞呇囨晬閸х闁挎稑顦埀顒佹煛閳?缂備焦鐟﹂弫褰掓寠?闁哄洦娼欓ˇ鎸庣▔閵堝嫰鍤嬮柛銉у亾閻栵絿鎷嬮埡鈧紞鍛村Υ?*/
  private static readonly LYRIC_META_SIDE_VP: number = 16;
  // 闁宠法濯寸粭?2026-10-15闁挎稒鐡狶YRIC_META_ICON_FP` **鐎瑰憡褰冮崹褰掓⒔?* 闁炽儲鏌￠埀?闁衡偓閹増顥?/ 闁哄洦娼欓ˇ鍧楁焽閿濆嫯鈷堝☉鎿冧簻濞存﹢寮介崶銊︽毉闁?
  //   `this.expandState.chromeFavSize()`闁?*闁圭顦伴妴鍌涙媴瀹ュ牄鈧啴宕ｉ弽褉鍋?* 24 / 22 / 20闁挎稑顧€缁?
  //   閻庣懓鏈弳锝夊礄閸濆嫷妲遍柨娑樻綁chrome().favSize`闁靛棔姊梬ujie.pa:195193 / 195316`闁靛棔鐒﹂妴鍌涙媴瀹ュ牄鈧?`93534`闁挎稑顦崯鎾诲捶閵娾晛浜濆☉鎿冧簼閺岀喎鈻旈弴姘辩憪闁?
  //   闁告帞濮撮悾鐘绘儍閸曨偄鏂ч柛銉у缁变即宕㈤悢鍛婇檷閺夆晜鐟╅崳鐑藉礃濞嗘劦鍔?`22`闁挎稑鐗婇弫鐐烘煂婵犲懎娈伴梻?闁告瑦鐗旂粭灞矫烘ィ鍐従濞戞挴鍋撻柤宄邦嚟濞堟垶绋夐埀顒€顩?闁?*濞戞挸绉靛Σ鎼佸籍閻樺灚娅曢柣銊ュ閳?*闁挎稑顧€缁?
  //   闁瑰箍鍨洪崹?getter 濞戞柨顑呴幃妤佹交濞嗗酣鍤嬮悽顖涙倐閸ｈ櫣浜?*婵炲备鍓濆﹢浣烘嫬閸愵亝鏆忛柤鏉挎噸缁?* 闁炽儲鏌￠埀?濞戞挸绉堕弳鈧慨婵婎唺閸烆剟鎯嶆笟濠勭闁告艾鏈Λ灞姐€掗崨顖涘€為悷?閹?6.15 / 閹?6.20闁挎稑顦埀?
  /** 闁搞儳鍋撻悥锝夋儍閸曨厼浠柛鎴ｅ吹閸庡綊宕犳ウ璺ㄧ彾闂傗偓閸栵紕绀剉p闁挎稑鑻悾濂稿棘?`HIT = 44`闁挎稑顦埀?*/
  private static readonly LYRIC_META_HIT_VP: number = 44;
  /**
   * 婵繂鐭侀惁婵囥亜閻㈢浜濆☉鎾亾婵☆垼浜ｉ、鎴︽儍?*閻炴稑鐭傞悵?*闁挎稑婢妏闁挎稑顦埀顒佹煛閳?濞戞挶鍊涢、鎴﹀棘閸パ呮憻闁挎稑鐗婇悥锝嗭紣?15 / 婵繂鏈晶?12 + 2 闂傚倻顥愮粣娑㈡晬? 闁搞儳鍋撻悥锝夋偩濞嗘垶顏ら柕?
   * 闁宠法濯寸粭?閻庣懓鍟ぐ褔鎮介妸銈囪壘"缂佹梹鐗滃ú璺ㄤ沪閸涱剝鍘悶娑栧劚娴?闁挎稑鐗愰～?`LyricFloatLayer` 闂?`.position()` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柨?
   *    **濞戞挸绉烽々?*闁衡偓鐟欏嫬鐏囬悘蹇庣窔濞肩増娼忚ぐ鎺撴瘣 闁炽儲鏌￠埀?闂侇叏绲肩槐浼村箮婵犲倻娈遍梻鍫涘灲閵嗗鎯冮崟顒傛憙闁告艾绉寸欢姘▔鐎ｎ偄鑵归柛妤€锕ｉ柌婊勫緞瑜嶉惃婵嬫閵忋垺鐣卞Δ鍌浢€规娊濡?
   */
  private static readonly LYRIC_META_ROW_H_VP: number = 34;
  /** 缂傚啯鍨堕悧鎼佹嚄鐏炵偓鐝繝褎鍔楀▓鎴︽儎閹烘垹纭€婵☆垽绱曠涵锕傚础婵犲倻绐?/ 閺夌儐鍠楅弳鐔兼晬閸喐锟ラ柣?`MeshCoverBg` 闁?`BLUR_RADIUS` / `BLUR_PASSES`闁挎稑顦埀?*/
  private static readonly MESH_BLUR_RADIUS: number = 9;
  private static readonly MESH_BLUR_PASSES: number = 3;
  /** 閻忕偞娲栫槐鎴︽儑鐎ｎ喗锛岄柣娆愵殣缁辨獡s闁挎稑顧€缁辨壆鎼鹃崨顔筋槯閺夆晜蓱閻ュ懘宕堕悙鎻掔厒閻庣懓鏈弳锝夊箑娴ｅ憡鐨戠€殿喖鎼崺妤呭炊閻愭彃鐓傞悗鐟版湰閺嗭綁骞€娴ｇ鍋?*/
  private static readonly COLLAPSE_WATCHDOG_MS: number = 900;
  /** 閻忕偞娲栫槐鎴︽儑鐎ｎ喗锛岄柣娆愵殔閻ｉ箖寮捄鐑樼彜闁告瑣鍎查悞娲Υ?*/
  private collapseWatchdogTimer: number = -1;
  /** 婵繐绲藉﹢顏堝箻椤撶喐鏆悹褍鍢叉慨鈺呮偨娴兼瑧绀勯梻鍐ㄥ级椤掓稒娼婚悙闈涗化閺夆晜鏌ㄥú鏍箻椤撴繆鈷堥梺顒€绋勭槐姘跺Υ?*/
  private isClosing: boolean = false;
  /**
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗婂Λ銈夋偩瀹€鍕ㄥ亾閸℃鍊?P0-3闁挎稑顧€缁变即宕堕悙鑼跺墾闁衡偓鐠鸿櫣鍟查柣?*闁绘瑯鍓涢悵娑欑閿濆棭鍋?*闁?
   *
   * 闁宠法濯寸粭?**濞戞挸绉烽々锕傛偨?`morphGen` 闁哄稄绻濋悰娆愭交濞嗗海顏辨慨?*闁挎稒鐡猰orphGen` 闁?闁告垹濮崇紞宥嗙閿濆棭鍋?闁?
   *   `morphBeginEntering` / `morphBeginLeaving` / `morphReset` 闂侇喗鍨濈槐?`++`
   *   闁挎稑娼塒layerExpandState` L2330 / L2437 / L2456闁挎稑顦崳?240ms 缂佹劖顨呰ぐ娑㈡煂鐏炶棄娑ч悷鏇氭祰閹癸絾绂?*濞寸姾顔婄紞?*闁哄倿顣︾槐鎵嫚濠垫挾绀?
   *   閺夆晜鐟﹂濂稿绩鐠鸿櫣鍟查悘蹇氱簿椤?*闂傚牊鐟╃划顖滄崉鐎圭姷绠?*闁挎稒绋栭埀顒€鑻悾鐘诲及?*闁哥儐鍨粩?*闁?`morphDrive` 婵炴挸鎳庡ú?`NONE` 闁汇劌瀚﹢鎾棘?
   *   闁挎稑娼塵orphSettleOpen()` L2421闁挎稑顦崳?`morphSessionDriving()`闁挎稑婀?487闁挎稑顦版禍浠嬫儑?
   *   闁?濠㈢懓鍟块惇浼村礂鐎ｎ喗鐣烽悘鐐插亰缁辨瑦绋夋径澶愬殝闁圭顦甸幐?/ 婵繂鑻幃鏇㈡晬婢跺﹦鍩楀纭咁嚙濠€顏嗕沪韫囧海鐟愰柕?
   *   闁告帇鍊栧畵渚€鏁嶅姝╠c shell hilog -x | Select-String 'RzdMorph'` 闁炽儲鏌￠埀?濞戞挴鍋撻弶?濞戞挸顑嗘刊娲焼閹烘挻绶遍柟?闂?
   *   闁?`morph open (settled)` 闁哄牆顦伴惀鍛村嫉婢跺﹤姣夐柣婊嗗焽閳?
   */
  private dismissSettleGen: number = 0;
  /**
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗婂Λ銈夋偩瀹€鍕ㄥ亾閸℃鍊?P0-2闁挎稑顧€缁变即寮幘顔衡偓澶愬礂閹惰姤锛旈柣?*闁绘瑯鍓涢悵娑欑閿濆棭鍋?* + 闁告鐡曞ù鍥┾偓瑙勭濡炲倿宕抽妸銉ョ稏闁哄苯瀚ㄩ埀?
   *
   * 闁告鍠愬鐢稿矗椤忓牊娴?`isClosing` 闁归潻绻濋崳鎼佸礂閵夘垳绀夐柤鏉胯嫰閻ｇ娀宕?`morphCloseMs + 20`闁挎稑鐗冩晶?70ms闁挎稑顦銊ф偖椤愶絿顏搁柛?`false`闁?
   * 闂侇叏绲肩粩鎾礆缂佹ɑ灏￠柡鈧ィ鍐︹偓?*闁告瑯鍨甸崗妯绘交濡崵姊?unmount** 闁?缂佹鍏涚花鈺佲枎閿涘嫬浠柛鎴炴閸忔﹢宕樺鍫熷闯濞戞挴鍋撻柡?350ms 閻炴稏鍎靛Λ?+ 缂佹鍏涚花鈺傜▔椤忓嫬绁婚弶鐐舵閻ｉ箖寮捄鐑樼彜闁?
   * 闁?`morphGenAlive` 闁哄稄绻濋悰娆撳箯閿旇法鐟濆ù锝呴獜缁辨瑦绋夐妶鍡樿拫闂佹儳澧藉▓?`morphGen` 闁烩晝顭堥幃鎾绘晬婢跺牃鍋?
   * 闁绘粍婢樺﹢顏堟晬濮橆剙缍栭柡灞藉閻°劍绋夌€ｎ偅闄嶉柛娆樺灥椤箓宕ｉ弽銊?+ 濞寸媴绲鹃鍏肩▔閵夛妇澹愰柡宥忕節閻?闁?"缂佹鍏涚花鈺佲枎閿涘嫬浠柛?閻熸洑妞掔粻鐐垫偖椤愶絾顫栫痪顓у枛閹风兘鎮鹃妷锝傚亾娴ｇ瓔娲ｅ☉鏂跨墕閸忛亶宕欓埀顒勫箳閵壯屽悁闁?
   */
  private closeGen: number = 0;
  private closeSettleTimer: number = -1;
  /**
   * 闁哄牜鍓氶鍏肩▔鐎ｎ偄顎欓悹铏瑰枑婢ф粓寮伴姘剨鐎规瓕灏欑划锟犲箮婵犲倽鍩岄柛娆愵焽濞村鎷呭鍛€奸柛?LEAVING闁挎稑鐗嗛顕€寮介崶銊︼骏闁伙絽鐬煎▓?`drive = FINGER`闁挎稑顦埀?
   *
   * 闁哄牆顦花锛勨偓鐟板枦缁辨繈寮堕悙顒€顤侀柡鍐煐婢х娀鎳楅挊澶婄€绘繛?閺夆晜鐟﹂鍏肩▔鐎ｎ偄顎欓柣顏嗗枔濞堟垹鎹勯悢绋款杹閺?闁?闁告瑯浜濆Σ鎼佸几娴ｈ櫣鍙氶柣銊ュ缁旀潙鈻庨埄鍐ㄧ彌闁?闁?
   * 闁告艾姘﹂埀顒€鎳嶇粭澶愭嚄閽樺绠甸柛鏂诲妼閼镐即宕ｅΟ鍏肩ゲ濞达絽绋勭槐婵嬪触閿曗偓閸垱瀵煎顓炍╅梻鍫熺懄椤掓盯鎯?OPEN 闁诡兛鐒﹂弫濂稿箣?LEAVING闁?
   */
  private dismissMorphActive: boolean = false;
  /**
   * 闁哄牜鍓氶鍏肩▔鐎ｎ偄顎欓柡鈧幆鐗堝闯**閻犙囨敱婢ф粓鏌囬敐鍕伇闁?*闁汇劌瀚懜浼村矗濡法绠婚幖杈捐缁辨獋morphP`闁?..1闁挎稑顦埀顒佹煛閳?闁稿繑濞婂Λ鎾箵閹邦亝鍞夐柣?*闁烩晝顭堥顕€鏌?*闁告帇鍊栧畵渚€鎯冮崟顐ゅ敤闁告垵妫庨埀?
   *
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`reverseQuitDelta`闁挎稑顧€缁变即寮悩鍨珪闁汇劌瀚崣褔姊婚鐔风倒濞存嚎鍊撶粭澶愬及?缂傚倵鏅涢崺灞惧緞濮橆剛姣岄悘蹇撳船閸?闁?
   *   闁兼澘鏈Σ?**婵絾妫侀幑锝夋倷閻熸壆绐旈柛銉у仩閾斿绂嶉崱妤婃▼閻?*"闁挎稒鐡猟elta >= max(baseT/2, COMMIT_T)`闁?
   *   閻犙囨敱婢ф粓寮捄鐑樿含 `morphBeginLeaving()` 濞戞柨顑呮晶鐘垫媼閺夎法绉块柡鍫墮閳ь剛銆嬬槐閬嶅级閻愵剙顤侀柡鍐ㄥ閻?`delta = baseT 闁?鐟滅増鎸告晶鐘虫交濞戞ê顔奰闁?
   *   闁宠法濯寸粭?闁告帗绻傞埀顒傚帶瑜?**1**闁挎稑鐗婂褏浠﹂弴鐐电；闁挎稑顦埀顒佹煛閳?濞?濞寸姴閰ｅ銈咁潰閵忋垺鐣遍柟缁㈠幗閺備焦銇勯棃娑氱；濠殿喖顑勭粭鍛村箯?閺夆晜鐟ょ粩瀵告暜閸涘ň鍋撴担椋庮伇闁肩柉鎻槐?
   *      闁活亞鍠愰婊呮導闁垮顤侀柡鍐╂构缁辨壆鎮銈囧綄闁告帗妲掗々顐︽儎閺嶇數绀勯悷?`onDismissDrag` 闂佹彃鐭侀鍥亹閺囩偟鏆婇柣銊ュ閸嬪懏绋夐埀顒傛偘瀹€瀣闁?
   */
  private dismissBaseT: number = 1;
  /**
   * 濞戞挸顑嗘刊娲绩閹増宕抽柟闈涱儏婵炲秹鎯?*閻犙囨敱婢ф粍鎷呭鍥嗏晠姊婚妸鈺傤€?*闁挎稑婢妏闁挎稑顦埀?
   *
   * 闁?閻庝絻顫夐悥锝夊籍閻樺灚娅?`PlayerPage` 濡炪倕鐖奸崕鎾礂閹惰姤锛旈柟闈涱儏婵炲秹鎯?
   *   `PanGesture({ direction: PanDirection.Down, distance: 8 })`
   *   闁挎稑娼塤recover\logic-src\鐎殿喒鍋撻柛蹇氭珪閹搁亶寮ㄩ幆褎鐝?闁归潧顑呮繛宥囨崉椤栨氨绐為悗瑙勬皑椤?md` 閹? 闂侇偆鍠愰悡锛勬偘?/ 閹?.1 闁?/ 閹?.3闁?
   *   閻庢稒顨夋俊顓㈡儘?`wujie.pa:181153-181157`闁挎稑顦埀顒佹煛閳?**閻忓繗椴稿Σ鎼佸籍閻樺灚娅曢柣銊ュ閸嬪懏绋?8闁挎稑濂旂粭澶愬及椤栨稑鐏夊ù鐙€鍏涢崣濠囨儍?*闁?
   *
   * 闁宠法濯寸粭?濞戞捁妗ㄧ划鍫熺▕閸垺鏆?*婵℃妫欓悘锔剧棯?*闂傚倶鍔戝娲Υ娴ｈВ鍋撶仦鑲╃憹闁?{@link onDismissDrag} 闂佹彃鏈晶婊堝礃?`if (offsetY < N) return;`闁?
   *   `PanGestureOptions.distance`闁挎稑鐗婂﹢浼村嫉?`gesture.d.ts:2380` 缁绢収鍠楀﹢浣烘嫚閵夈儳鎽熸繛鍫㈩暜缁?*濮掓稒顭堥?5vp**闁?
   *   闁?闁归潧顑嗙€垫氨鎸ч悧鍫濆К濠㈣埖鑹鹃惃顖炲箥?*閻犲洤妫楅崺?*閺夆晜鐟ら柌婊堝箥鐎ｎ亜鈼?闁炽儲鏌￠埀?婵炲眲銈堟巢婵犲ň鍓濆?`onActionStart/Update/End`
   *   闁哄秷顫夊﹢鐗堢▔瀹ュ嫮绐楅悷娆欑畱瑜?闁?闂傚牊鐟﹂娑㈠箑娴ｇ瓔娼?1~2vp 闁硅埖鐗曟慨鈺呭箳閵娿劎绠?`LEAVING`闁挎稑娼夋繛鏌ョ畺閻撳爼宕濋妸褎鏆癇ug婵炴挸鎳庡畷?md` P0-4闁?*闁革负鍔嶇花顔藉緞缂堢姷鐟濋柟瀛樺姉閻?*闁?
   *   闁兼澘鏈晶婊堝礃濞嗗繐鐏查柟璇″枙缁辩増寰勫顐ゎ伇婵炲棌鈧尙鐟濋弶鈺冨仧閻㈠鏁嶉崼锝囶€€闁归潧顑堢换妯绘償閿曗偓濠€顏堟⒒閵娾晜顎欓梺顓ㄧ导缁斿鏁缁?0 闁烩晛鐡ㄧ敮瀵告崉閸愭彃鐓?`N/span`闁挎稑顦埀?
   *
   * 闁宠法濯寸粭?**闁瑰灚鎸哥槐鎴﹀棘閻熺増鍊诲☉鎾崇Т婵?*闁挎稒鐭悮閬嶅级闄囩化鐘虫媴閻樿櫕钂嬮柣?`panOption` 濞ｅ洦绻冪€垫梹顪€濡鍚?5vp 闁炽儲鏌￠埀?
   *   闂侇叏绲鹃婊勭附閻ｅ瞼鎼煎ù婊冨濡倝鎮剧仦鑲╃憪婵犲﹥鍨舵晶锕€顕ｉ埀顒勫箥鐎ｎ亜鈼㈤柣?`{ direction: PanDirection.Vertical, distance: 5 }`
   *   闁挎稑鐗嗛幃鎾诲棘閸ャ劊鈧?閹?.1 闁冲墎濯寸槐姘舵晬鐏炴儳顣插ù鐘劦閸嬪懘鏌岀仦鐐紗濞戞挸绉存慨鐐寸▕閻斿墎鐟濋柡鈧獮搴撳亾?
   */
  private static readonly DISMISS_PAN_DISTANCE_VP: number = 8;
  // 闁宠法濯寸粭?濞戞挸顑嗘刊娲绩閹増宕抽柣銊ュ鐞氳鲸绋?*闁告帇鍊栧畵浣烘暜閹间礁娅?*闁挎稑鐗婅ぐ浣圭閵堝顫岄柛?38 / 闁稿繑绮岀花宕囨偘瀹€鈧埢鐓幮掗弬鍓т紣 0.42闁?*鐎圭寮堕弫褰掑极濞戞ê鐓?*
  //    `PlayerExpandState.DISMISS_COMMIT_PROGRESS` / `PlayerExpandState.DISMISS_DRAG_SPAN_RATIO`
  //    闁炽儲鏌￠埀?闁告鍠庨崢娑氣偓鐟板暕濠婃垶绋夋惔銏犫叺鐎殿喒鍋撻柡鍌滄嚀閹粓鎯?`PULL_OPEN_COMMIT_FRACTION` 闁告帒妫楅惇铏▔閵堝嫰鍤嬮柡鍌氭矗濞嗐垽濡存担瑙勶骏濞存嚎鍊曞鍫曞冀閿熺姷宕?
  //    闁挎稑娼夋繛鏌ョ畺閻撳爼宕濋妸褎鏆癇ug婵炴挸鎳庡畷?md` P0-1闁挎稑顦埀顒€鍊婚幃濠囨偨閸欐鐟?濞戞挸绉烽蹇涙偂瑜庢俊閬嶅籍閻樺灚娅?0.32"闁汇劌瀚鈺呭及鎼淬劌鍘撮柛锔哄姂閸嬪懘鏌屽畝鈧▓鎴濃枖閵娾晛娅為梺鎻掕閳?
  /**
   * 濞戞挸顑嗘刊娲级閻愵剙顤侀柡鍐ㄥ濞?*闂侇偆鍠庣€?*闁圭粯鍔掑锕傛⒓閸績鍋撶涵椋庣vp/s闁挎稑顦埀?
   *
   * 闁告垵鎼ˇ鈺呮晬濮濇瓰ocs\闁哄啰濮烽弲顐ャ亹閵忕姴缍侀柟闈涱儐閸?闁解偓閽樺鏉介柛鎺旀珔zdMusic婵炴挸鎳庡畷?md` 閹煎倹绋夐埀?1.2闁靛棗鏈ぐ浣圭閵堝懎鐏查悗?闁炽儲鏌￠埀?閺夆晜绋戠€?OR 闂侇偆鍠庣€规娊濡村蹇曠獥
   * `commit = (morphT >= COMMIT_T 闁?0.32) || (velocity <= COMMIT_VELOCITY 闁?900)`
   * 闁?闁哄啰濮烽弲顐︽儍?`COMMIT_VELOCITY = 900`闁?*閺夆晜鐟ら柌婊堝极閻楀牊笑濞寸姴瀛╅弸鍐浖閿濆懎绲块柣銊ュ缁辨繃绋夊鍡樞﹀ù鍏煎濞堟垿濡?*
   *
   * 闁宠法濯寸粭?濞?*缂備焦绻€缁楀鎮¤婵¤京鈧懓鍟板▓鎴澬掗弮鍥╃獩闁哄倻鎳撻幃?婵繐缍€缁€瀣矗?*闁挎稒纰嶅Λ銈夋偩鐏炵偓笑"濞戞挸锕ユ刊娲箥閹惧磭纾?闁挎稑鐭佺换鏍煂鐏炵偓笑"濞戞挸顑嗘刊娲绩閹増宕?闁挎稑鏈弻鐔煎触閹寸姵绁查柛娆忕▌缁?
   *   闁哄倸娲﹂妴鍌涚▕閻斿憡顫栭悹?缂佹绠戣ぐ璺ㄦ啺娴ｇ甯ラ悗鍦仦缁佹挳濡存担绋跨劶闁绘挆鍕?闁靛棗鍊介～?{@link onDismissDrag}闁?
   *   **闁哄倻鎳撻幃婊堟偨閸欐绉寸紒澶庮嚙閸ㄤ粙濡存担鎼炰海閻忓繐绻掗弫?`Math.abs(velocityY)` 闁?* 闁?闁哄秹鈧稓鐟愬☉鎾崇Ч濞撳墎鎲版担闀愭捣閻犱礁澧介渚€宕ｉ弸顐熷亾?
   */
  private static readonly DISMISS_COMMIT_VELOCITY: number = 900;
  /**
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗婂Λ銈夋偩瀹€鍕ㄥ亾閸℃鍊?P0-4闁挎稑顧€缁辩増绋夌€ｎ偄顎欓柡鈧幆鐗堝闯闁?*闁哄牃鍋撻悘蹇撶箺閹癸綁骞嶇€ｂ晝绉寸紒?*闁挎稑婢妏闁挎稑顦埀?
   *
   * 婵炲备鍓濆﹢浣衡偓鐟板暟濞堟垿寮捄琛″亾濞嗘瑧绀夐悹铏瑰枑婢ф粓宕氶崱妯绘殰闁告瑯浜ｉ々?`offsetY > 0`闁?*1vp 闂侇喚鏅悾?*闁挎稑顦銊﹀?`morphBeginLeaving()`
   * 闁?闁烩晠鏅茬紞鍛偖椤愶絽鑵归弶?`LEAVING` 濞?`morphGen++`闁挎稑鐭侀埀顒€鑻惈鍡樼▔婵犲倸娈ゅ☉鏂跨凹缁牊绋婇崼銉ュ幋婵炲备鈧啿袟闁?
   * 闁哄鍋撴晶婊堝炊閻愯埖鍎伴柡鍐硾瀵數绱掑▎鎴炵ゲ濞达絽绉存禒娑欑▔閳ь剙鈻?220ms 閻炴稏鍎靛Λ?+ 240ms 閻庤纰嶅鍌炲闯?
   * 闁?閻熸瑥鍊归崝鍛村及?閺夌偞妲掓禍銈夌叓椤撴繄顏卞☉鎾愁儏濮樸劑姊婚鍐伇濞?闁挎稑鑻幃鎾诲籍閼搁潧惟 P0-3 闂侇叏绲惧顖氣枔鐎ｎ剚娈岄柣妯垮煐閳ь兛鑳跺▓鎴︽⒒閵婏箑鈪电€殿喒鍋撻柕?
   * 8vp 闁?2.5mm闁?*閺夆晜绮岄惃顒佺?*閻犲浂鍨佃閻忓繐鎼€规娊鏁嶉崼姘拺10vp闁挎稑顦粭宀勬儑閻旈鏉藉☉鎾愁儐婵櫣鎸ч柨瀣杹闁挎稑鐗嗛崵鎴﹀础?vp闁?
   * 闁?**闁告瑯浜濈亸鍛村箮閺嵮冃楅柕鍡曟缁楀骞愰檱缁愶繝骞?*闁挎稑鐗呯粭鍛▔閳ь剚绋?`onActionUpdate` 濞戞挴鍋撻柡鍐跨畳缁夌儤娼婚崶褏鏆婇柣鎾楀啰鍩楅悹褔鏀辨晶婊堟晬婢跺牃鍋?
   * 闁宠法濯寸粭?闁哄啰濮烽弲顐ｇ瑹?*婵炲备鍓濆﹢?*閺夆晜鐟ら柌婊堟⒒閵娾晜顎?闁炽儲鏌￠埀?閺夆晜鐟﹀Σ绋棵烘ィ鍐従闁煎浜滅换渚€鎯冮崟顐㈩潱闁搞儳灏ㄧ槐?*闁轰礁鎳忛崜鐗堢▔瀹ュ嫮鐟㈤悗鐟板暙椤曨喗顬?*闁?
   */
  private static readonly DISMISS_MIN_START_VP: number = 8;

  /** @returns 缂佹劖顨呰ぐ娑欘殗濡搫顔婇柨娑樻緤p闁挎稑顧€缁遍亶骞忔径鍝ョ憹闁告帞澧楀鍌滅磼濞嗗海顏卞☉鎿冧簻閸樿鎯旈弴鐐╁亾绾绀夊ǎ鍥ㄧ箚閻﹀骞忛弽銊ヮ伡婵絾鏌х欢銉︾▔瀹ュ嫮绐楅梻鍕╁€濆ù鍌炲Υ?*/
  private deviceHeightVp(): number {
    const px: number = this.windowInfo.windowSize.height;
    if (px <= 0) {
      return 780;
    }
    return this.getUIContext().px2vp(px);
  }

  /**
   * @returns 濞戞挸顑嗘刊娲礆閺夎法淇洪柟纰樺亾闂傚洠鍋撻柣銊ュ缁愭稓绮嬫导娆戠vp闁挎稑顦埀顒佹煛閳?閻犺櫣鍠愭晶婊嗐亹閹哄秶顏遍柛鏍ㄧ墱濞?*闁告帒妫欓惁?*闁?
   *
   * 闁?D2闁?*濞村吋锚閸樻盯鎮介妸銉ф澖婵?*闁挎稑鏈€ｄ焦绋夊鍛厒闁归潧绉归埀顑藉亾闁搞儳鍋熼悰銉╁矗閿濆棛妲峰〒姘儍閳ь剙鍊搁顔筋瀲閹邦厽锟ラ柣?
   *   `pullRangePx = coverRect.top > 0 ? coverRect.top : windowHeight * 0.32`
   *   闁挎稑娼塪ocs\闁哄啰濮烽弲顐ャ亹閵忕姴缍侀柟闈涱儐閸?闁解偓閽樺鏉介柛鎺旀珔zdMusic婵炴挸鎳庡畷?md` 閹煎倹绋夐埀?1.1闁挎稑顦埀?
   *
   * **濞戞捁妗ㄧ划鍫熺▕閸繄鏉芥繛鏉戭儏閳ь剛鍘цぐ?`expandState.miniY`**闁挎稒淇虹粣锟犲箥鐎ｎ厾绠婚幖杈鹃檮濡叉悂濡寸仦鎯ь杹闁圭娲ｇ紞鍛矓閼姐倖鐣辩紒缁㈠灠閸ら亶寮懜顑藉亾?
   *   闁挎稑娼塸rogress = offsetY / span`闁挎稑顧€缁辨繈宕氶崱妯兼Г闁汇劌瀚銏＄▕婢跺﹥鐨戦柡?闁归潧顑嗙€垫氨鎸ч弶璺ㄦ殮闁轰胶绻濋柌婊堝绩閹増宕抽柛鏂诲妺缂嶆梻鎲版担鍊熸巢濠㈣埖淇虹换?闁?
   *   闁衡偓閹増宕抽柣銊ュ濞蹭即寮介崶銊π﹂弶鈺勬腹缂嶆﹢寮堕垾宕囨闂傚牄鍨介崑鍛▔閳ь剛浜歌箛鎾村仴闁挎稑鐭侀埀顒€鑻悾鐘绘儍閸曨垬鈧﹥娼忛悷鐗堢殤闁革负鍔庨悰銉╁矗閿濆懏缍忛柡?`miniY` 闁炽儲鏌￠埀?鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞呮帡宕?`p = 0`
   *   闁哄啫澧庡▓鎴﹀矗椤栨繍娼掗柣顓涙櫅閼哥増銇勯幆鎵彾婵繐绲惧Σ?`miniCoverY`闁? `miniY`闁挎稑鐬奸弫?`morphInitParams()` 濞寸姴楠搁幃鎾寸▔閳ь剚绂掗挊澶屾澖婵炴潙顑呴埀顒冨亹閻ｅ宕欓悮瀵哥闁?
   *   婵犲ň鈧磭娼岄柟顑跨窔閵嗗﹥娼忕憴鍕?0 闁?閻犙勬緲閻ｎ剟宕楅妸褉鏌?= 濡炪倖鍎肩粩鐔哥?0 闁瑰壊浜滈崺?`miniY` 闁?閻炴稑鐬奸埢?`miniY`闁?
   *
   * 闁宠法濯寸粭?**闁衡偓閻熸澘鐎绘慨锝呯С缁楀瀵煎杈╂焾缂佸鍨版禍鍝ョ矓?*闁挎稑鐓閸?缂?3 闁哄绱曞▓鎴﹀礆閵堝棗绁﹂柨娑橆檧缁辩櫗dismissProgressFromDrag()` 濞寸姴绉堕崝褔寮?
   *   `clamp(offsetY / span * 100)` 閺夆晜鐟ч～?**鐟滅増鎸告晶?*闁归潧顑嗙€垫氨绱掑┑鍡╁殸濞达絽绉朵簺"闁汇劌瀚崙浠嬪礄閼恒儲娈堕柨?*濞戞挸绉烽鐗堢▔婵犱胶顏遍悽?*闁?
   *   闁兼澘濂旂粭?`miniY` 闁革负鍔嬬粩鏉戔枎閳╁啫鐝涢柛鏂诲妽濠€锟犳⒒鐎涙ɑ笑閻㈩垱鎮傞崳?闁炽儲鏌￠埀?閺夆晞娓圭紞姗€寮堕垾铏含鐟滆埇鍨硅ぐ澶愬嫉閻斿吋锛熼柡?`Visibility.Hidden`
   *   闁?*濞ｅ洦绻勯弳鈧悽顖氬暙閻?*闁靛棔绶氬鎵矓椤栨瑧鐟濋柛娆愶公缁辨岸鏁嶇仦鑲╃憹濞村吋鑹鹃崯鈧悷娆欑畱瑜?`onAreaChange` 濞戞挸锕ユ慨?闁?闁告帒妫欓惁婵囩▔瀹ュ嫮绐楅柛锔哄妽鐎氬宕濋妸銈堝幀闂侇偅妫侀悜锕傚矗濡硶鍋?
   */
  private dismissSpanVp(): number {
    const measured: number = this.expandState.miniY;
    if (measured > 0) {
      return measured;
    }
    return this.deviceHeightVp() * PlayerExpandState.DISMISS_DRAG_SPAN_RATIO;
  }

  /**
   * 闁汇垼椴哥€氬骞忛崐鐔虹崺缂佸倻绮畷鑼不濡や焦鏆悹褏鏌夌换妯绘償閿旇　鍋?
   * @param offsetY 闁归潧顑呮繛宥夋儍閸曨厾褰ㄩ柣鈺冪節缂嶅懐绮旀导娆戠vp闁挎稑鑻幃婊勭▔鐎ｂ晞绀嬫慨婵撶秶缁辨岸濡?
   * @returns 閺夆晜绋戠€?0..100闁?
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
   * 濞戞挸顑嗘刊娲绩閹増宕抽柟闈涱儏婵炲秹鏁嶅顓炵彌闁告柣鍔嶅﹢锟犳⒒?*閻犺櫣鍠愭晶?*闁衡偓绾懐绠婚幖杈捐缁辨瑦绋夊鍫ｆ巢 animateTo闁挎稑鏈晶宥嗙閵夛附笑闁告娅曞鍌炴儍閸曞墎绀嗛柨?
   * 闁哄鍋撴晶婊堝籍?**閺夆晜绋戠€硅櫕娼婚崶顒侇潓闁?OR 闂侇偆鍠庣€瑰磭鎼鹃崘宸闊?* 閻忓繗椴搁弫鍦導閸戙倗绀夐柛姘剧畱閸垳鎮伴妷鈺傦紵鐎殿喚鎳撳ú鏍偓鐟版湰閺嗭綁骞€娴ｇ鍋?
   *
   * 閺夆晜鐟ラ〃婊勭閵堝嫮闉嶉柛婊冭嫰瀵剟鎳撻崘銊ょ矗缂?MusicHome 闁?`PanGesture` 濞戞挴鍋撻柤鐤彧缁辨瑧鈧懓鍟板▓?`dismissPanOffsetY`
   * 闁?`dismissSheetHeightPercent` + `coverLinearScale` 闁哄嫷鍨伴幃鎾寸▔閳ь剚绂掗張鐢电殤闁挎稑顦埀?
   *
   * 闁?D1闁挎稒宀搁埀顒傚枎鐎硅櫕銇勭涵鍜佹綄濞戞挸顑夊?{@link PlaybackPage.DISMISS_COMMIT_VELOCITY}闁?
   * @param offsetY 鐟滅増鎸告晶鐘电博閺嶎偅绾ù锝呯Ф浜涢柨娑樻緤p闁挎稑鑻幃婊勭▔鐎ｂ晞绀嬫慨婵撶秶缁辨岸濡?
   * @param ended 闁哄嫷鍨伴幆渚€寮伴娑欑繁闁归潧顑冮埀?
   * @param velocityY 闁哄鍋撴晶婊堝籍閸撲焦鐣辩紒鏃€鐗滃ú鍧楁焻閻斿嘲顔婇柨娑樼墛濞肩敻鎳?`GestureEvent.velocityY`闁挎稑顦埀?
   *   闁宠法濯寸粭?**闁哄牜鍓欓崵閬嶅极妫颁胶鐟濆〒姘箚缁傚棛鈧懓鍟板▓鎴犵箔閿曗偓瑜?*闁挎稑鐗愰～鍡樼▔鐎ｅ墎绀嗛柨娑樻湰婢у秵绂掗妷鈺冨笡閻犱降鍊曢埀?0 濞戞梻鍠嶇粭澶嬪濮樺灈鍋撻悩鎻掓瘔"閻犲浂鍨辫ぐ浣圭?闁?
   */
  private onDismissDrag(offsetY: number, ended: boolean, velocityY: number = 0): void {
    if (this.isClosing) {
      // 闁宠棄鎳夊Σ?2026-10-15闁挎稒淇虹换鏍ㄧ▔閳ь剛鎮扮仦闂寸鞍闁告挸绉靛Σ?*闂傚牊鐟╃划?* return闁挎稑濂旂花顒勫及?濞戞挸顑嗘刊娲绩閹増宕抽悗鐟拌嫰閸欏繑绋夊鍫㈩€€闁?閺夆晜鐟ゅ▎銏＄?
      //   闁革负鍔嶅Λ鈺勭疀濡ゅ懎娅″☉鎾亾闁绘劕婀卞Λ鏃€娼昏ぐ鎺戝幋婵炲备鍓濆﹢渚€鏁嶉崼鐔奉杹闁圭娲ゆ慨鈺傜閸℃劏鍋撴担鍝ユ綄濞戞挸锕ラ惀鍛村礉閵婏絺鍋撴担瑙勶級闊洦銇炵弧鍐ㄢ柦閳ュ啿鏅搁柨娑橆檧缁辨繈宕ｉ鍥у幋闂傚牏濮风€典粙濡?
      //   闁绘粍婢樺﹢顏堝箮婵犲倻鏆婇柟鍨尭閸ゎ參寮堕妷顖滅獥`hdc shell hilog -x | Select-String 'RzdMorph dismiss blocked'`
      //   闁炽儲鏌￠埀?闁告垼娅ｉ獮鍥┾偓?= `isClosing` 闁告せ鈧尙绉跺ù婊冩４缁辨瑧鎲?`closeFullScreenPlayback()` 闁汇劌瀚棢婵犳洖绻戦弫鐐烘煂婵犲繒绀嗛柨?
      //   **閻庣懓鑻崣蹇旂▔瀹ュ懎姣夐柣?* = 闁归潧顑呮繛宥夊冀鐟欏嫭鎷辨繛灞糕偓鍐茬厒閺夆晜鐟辩槐娆撴焽閿濆棙笑闁归潧顑呮繛宥囨崉椤栨粍鏆犻梻鍌ゅ櫍椤ｄ粙鏁嶇仦钘夌闁?`RzdMorph dismiss pan start`闁挎稑顦埀?
      Logger.warn(PlayerExpandState.LOG_TAG,
        `RzdMorph dismiss blocked: isClosing=true offsetY=${offsetY.toFixed(1)} ended=${ended}`);
      return;
    }
    const progress: number = this.dismissProgressFromDrag(offsetY);
    // 闁宠棄鎳夊Σ?D1闁挎稑鐗婂〒鑸殿殗濡湱鍠橀柛蹇撶墢妤犲洭鏁嶆径娑氱獥闁圭粯鍔掑锕傚礆閵堝懐鏆?= **閺夆晜绋戠€?OR 闂侇偆鍠庣€?*闁挎稑鐗婂Λ銈夋偩?閹煎倹绋夐埀?1.2闁挎稑顦埀?
    //   闁告瑯浜濆﹢浣规交濞戞ê顔婇柡鍐啇缁?濞达絽绉朵簺濞戞挸绉撮崺?38% 濞达絽妫涢弫銉ヮ嚗濡も偓缁躲垼绠?闁衡偓閺堢數鐟濋悹褔鏀卞?闁炽儲鏌￠埀?闁活潿鍔嶉崺娑㈠箥鐎ｎ偄濡冲☉鎾筹工濮樸劑寮?闊浂鍋嗛弫銉モ柦閳ュ啿鍐€閹?闁?
    //
    //   闁宠法濯寸粭?**濞戞挸绉烽蹇涙偖?`velocityY` 闁汇劌瀚渚€宕?*闁挎稑鐗婇弸鍐浖?閹煎倿宕?缂?3 闁?+ 閹煎倿宕?D1 闁?闁宠法濯寸粭宥夋晬婢舵稓绐?
    //     闁哄啰濮烽弲顐︽焽閿濆牏鐝堕柡?闁告碍鍨崇粭鍛▔閻戞﹩鍔€"闁挎稑鐭侀埀顒€鏈崹婊勭椤掑啰绠归梺鎻掓湰濡?*濞戞挸顑嗘刊娲绩閹増宕?*闁靛棔鐒﹂弻鐔煎触閹存粎鐟㈤悗鐟板暟濞村宕ｅ蹇曠
    //     闁绘挆鍕℃慨婵撶秬缁€瀣矗瀹勬壆绠戦梺鎸庣懕缁遍亶鎳?SDK 闁?`GestureEvent.velocityY`闁挎稑娼塯esture.d.ts`闁挎稑鐡恠ince 10闁?
    //     濞戞梻鍠愰惀鍛村嫉婢跺顥為悹鍥椤戜線宕ｉ柨瀣厵闁告碍鍨埀顒€鍊规晶宥嗙閵夈劎绠归梺鎻掑缁娀寮介柅娑氱憪缂備焦娲栫槐鎴︽晬?
    //       鐠?**闁哄倻鎳撻幃?*闁告瑯浜為弫?*濞达絽绉朵簺**闁?闁炽儲鏌￠埀?`offsetY > 0` 闁?閺夆晜鐟﹂濂稿箯閺嵮冃楅柡鍫熺箖閺佸湱鎸ч柨瀣厵闁?闁?
    //       鐠?**濠㈠爢鍐瘓**闁告瑯浜滆ぐ?`Math.abs(velocityY)`闁?
    //     闁?闁哄啰濮鹃鎴犲寲閼姐倗鍩犵紓浣圭懅濞堟垿寮?+900 閺夆晜蓱濡?闁?00闁挎稑鑻崹鐣屸偓瑙勬皑缁劑寮稿鍫濆幋濞戞挴鍋撻柡宥呭殩缁?*婵炲备鍓濆﹢浣圭鐠佸磭绉?缂佹绠戣ぐ璺ㄢ偓鍦仦缁?闁告挸绉堕悿鍡涘级閳ュ弶顐?*闁?
    //   闂傚啫鐗嗛埀?900 闁告瑦鐗為崵婊堝棘閸ャ劊鈧倿鏁嶉崼锝庢綄 `DISMISS_COMMIT_VELOCITY` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柨娑樺缁楀寮伴婊呮そ闁汇劌瀚ㄩ埀?
    const collapsingDirection: boolean = offsetY > 0;
    const speed: number = Math.abs(velocityY);
    const fastFlick: boolean = collapsingDirection && speed >= PlaybackPage.DISMISS_COMMIT_VELOCITY;
    // 闁?鐟滆埇鍨硅ぐ澶愭焽閿濆拋娈伴柨娑欑煯缁楀懘骞忔径瀣毆閻犙冨槻濮樸劑寮?*闁告瑥绉撮幃婊呮崉閹存繃鍊卞☉鎾亾濠靛倹顨呴崵鎴炴媴?*闁挎稑鐗婂Λ銈夋偩鐏炶偐鐦嶉柡鍕靛灠閹挻绋夐埀顒佺▔?progress 婵繐绲藉鑺ョ▔閵堝洦鏆忛柨?
    //   闁炽儲鏌￠埀?闁轰焦鎸抽妴澶岀磽閳轰焦绀€閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞挴鍋撻悘蹇撶箰濞硷繝濡存担绛嬫⒖闁告搩浜為悰銉╁矗閿濆棙鏆柛銉у仜楠炴捇濡存担鐣岀濞达絿濮靛顖炲触鐏炵偓顦ф繛锝傗偓铏闁哄鍎埀?
    if (this.expandState.morphUsable) {
      if (!ended) {
        if (!this.dismissMorphActive) {
          // 闁宠棄鎳夊Σ?P0-4闁?*闁哄牃鍋撻悘蹇撶箺閹癸綁骞嶇€ｂ晝绉寸紒澶婎煼濡剟姊?*闁挎稑鐗呯欢鐑藉箲椤旀娼?`DISMISS_MIN_START_VP` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柕?
          //   濞达絽绨肩花顒傗偓鐟板暙濮樸劏銇愰幘鍦婵炲棌鍓濈€氬宕濋妸銈囩憹閻庢稒锚濠€顏堟晬濮橆偆鐟濋柡鈧崷顓熺ゲ濞达絽绉查埀顑挎缁?++ 濞寸媴绲鹃濂稿Υ娴ｉ鐟濋柛鎺戝槻閸ゆ垶鎷呴弴顏嗙闁烩晛鐡ㄧ敮瀛樻交閺傛寧绀€闁?
          //   濞戞挸顑勭粩瀛樼▔?`onActionUpdate` 闁告瑯浜ｉ々锔炬惥婵犲懐绠栭梻鍌樺姂濡捐櫣浜搁崣妯肩獥婵繐绲介悥鍓佹導闁垮顤?闁?閻犺櫣鍠愭晶婊勭▔瀹ュ嫮绐楅柛娆愵焾缁绘粓鏌﹀┑鍕ㄥ亾?
          //   闁宠法濯寸粭?**`fastFlick` 闊洤鎳橀妴蹇涙嚄閻ｅ瞼鎼忛弶鈺佹喘濡剟姊?*闁挎稒鐭粩鏉戔枎?闁哄绀侀幓鈺傛媴閸℃洜绉寸紒澶庮嚙缁躲垻浜?闁汇劌瀚粭鍛存偨?
          //      闁?ms 闁告劕鎳庤ぐ褏鎸ф０浣哄晩闁?vp闁挎稑顦敮顐﹀嫉椤掑嫭娴嗛梺顐ゅ枎鐎硅櫕銇勯悷鐗堢殤闁煎疇濮ら弫鍦導閸戙倗绀夐悶姘煎亰濡剟姊介幇顓炵殹闁瑰搫顦銊╁箣閹邦亞鍟?闊浂鍋嗛弫銉モ柦閳ュ啿鍐€閹?
          //      闁炽儲鏌￠埀?闂侇叏绲鹃婊堝及?D1 鐟滅増鎸搁崹鐢垫啺娴ｉ攱鍙忛柣銊ュ閻︽椽鎯€閸涱偀鍋撻崒娑橆暡濞寸姰鍎寸换鏍煂鐏炵偓笑 `濞达絽绉朵簺婵炲眲銈囩畺闂傚倶鍔戝?**濞?* 濞戞挸绉靛Σ姝岀疀椤愩倖鏆恅闁?
          if (offsetY < PlaybackPage.DISMISS_MIN_START_VP && !fastFlick) {
            return;
          }
          this.refreshCollapseGeometry();
          this.dismissMorphActive = true;
          // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁变即宕楅幎鑺ワ紨闁圭粯鍔掑锕傚绩鐟欏嫬鐏?*闁烩晝顭堥顕€鏌?*闁告帇鍊栧畵渚€鏁嶆径娑氱獥閻犙囨敱婢ф粍娼诲▎搴ｎ伇闁告帟顕ч崢娑㈠箮婵犲倻绉奸柛鎾崇Х缁绘ɑ鎯旈敃渚囧敹濞戞挸顑嗗?闁炽儲鏌￠埀?
          //   闁哄鍋撴晶婊堝籍閸撲焦鐣遍柛鎺嬪€栧畵渚€寮?**婵絾妫侀幑锝夋倷閻熸壆绐旈柛銉у仩閾斿绂嶉崱妤婃▼閻?*"闁挎稑娼塪elta`闁挎稑顧€缁辨繃绋夊鍡樞?缂傚倵鏅涢崺灞剧閸℃妯嬮悘?闁?
          //   闁哄啰濮烽弲?`reverseQuitDelta()`闁挎稒鐡猶uit = delta >= max(baseT/2, COMMIT_T)`
          //   闁挎稑娼塤recover/logic-src/鐎殿喒鍋撻柛蹇氭珪閹搁亶寮ㄩ幆褎鐝?闁归潧顑呮繛宥囨崉椤栨氨绐為悗瑙勬皑椤?md` 閹煎倿宕?L351-353 / L386闁?
          //   閻庢稒顨夋俊顓㈡儘?L151812-151838闁挎稑顦埀?
          //   闁宠法濯寸粭?闊洤鎳橀妴蹇涘捶?`morphBeginLeaving()` **濞戞柨顑呮晶?*闁告瑦鐗槐鐗堢▔鐎ｂ晝顏辨慨婵勫劙缁变即寮ㄩ崷顓熺ゲ濞达絽绉查埀?
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
      // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁嶅顒€褰犻梻鍌ゅ幗瑜颁焦绂嶉妶鍡樻毉闁?*闁烩晝顭堥顕€鏌?*闁告帇鍊栧畵?`delta >= max(baseT/2, COMMIT_T)`
      //   闁挎稑鐗婂Λ銈夋偩?`reverseQuitDelta()`闁挎稒绋戦崵顓熷緞閸曨偅鍊卞☉鎾愁煭缁辨岸濡?
      //   鐠?`delta` = 閻犙囶棑閸嬶絾娼诲☉妯侯唺 闁?鐟滅増鎸告晶鐘虫交濞戞ê顔?= "閺夆晜鐟ょ粩鎾箯閺嵮呯獢闁搞儳鍋犻摂瀣閸℃妯嬮悘?闁?
      //   鐠?**婵犲ň鈧磭娼旂€殿喒鍋撻悹褔鏀辨晶?*闁挎稑娼塨aseT = 1`闁挎稑顦崳?闂傚啫鐗嗛埀?= `max(0.5, 0.32) = 0.5` 闁?**閻熸洑鐒︽刊娲炊閻愭彃绠?50% 闁归潧绉撮崣?*
      //     闁挎稑鐗婇弫濂稿礈瀹ュ棙笑"缂傚倵鏅涢崺?38% 閻忓繐宕崣?闁?`delta 闁?0.38` 闁?**闁哄洦娼欓鎰板及閹捐鍤栭柛?*闁挎稑顧€缁?
      //   鐠?`baseT` 閻忓繐绻嬬花?0.64 闁哄啫鐖煎Σ鍥磹婵傜硶鍋撻埀顒勫礆?`COMMIT_T = 0.32`闁挎稑鐗婂Λ銈夋偩瀹€鍕簼闁?`max` 闁汇劌瀚ぐ鐔哥▔閳ь剟宕℃繝蹇曠闁?
      //   闁宠法濯寸粭?闂侇偆鍠庣€硅櫕銇?*濞戞挸绉烽崗妯荤▔?*闁挎稒纰嶅Λ銈夋偩鐏炶偐鐦嶉柡?`閺夆晜绋戠€?闁?闂侇偆鍠庣€圭牏闁挎稑鐓缁?1.2闁挎稑顧€缁?闊浂鍋嗛弫?闊洤鎳橀妴蹇涙偂瑜庨悧閬嶆嚄閽樺褰犻柕?
      const currentT: number = 1 - progress / 100;
      const dismissDelta: number = this.dismissBaseT - currentT;
      const dismissThreshold: number = Math.max(this.dismissBaseT / 2,
        PlayerExpandState.PULL_OPEN_COMMIT_FRACTION);
      const shouldClose: boolean = dismissDelta >= dismissThreshold || fastFlick;
      // 濞戞挸锕ュ┃鈧柟鐑樺笚閻擄繝鎮介…鎺旂獥`hdc shell hilog -x | Select-String 'RzdMorph dismiss commit'`
      // 闁宠法濯寸粭?閺夆晜鐟ょ粩瀵告偘?*闁轰礁鎳忛崜浼村触鐏炵偓顦ч柟鍨尫鐞氳鲸绋夐鍛厵闁告碍鍨瑰▓鎴︽⒓閸績鍋撻梻瀵哥憿濞戞挶鍊撻柌婊堝礆閸℃妲?*闁挎稑鐗嗗顒傛喆?
      //    `PlayerExpandState.pullSpanIsMeasured()` 闁汇劌瀚弫鐐烘煂?/ `婵炴煡绠栭悡鍫曞礉閵娧勬毎Bug婵炴挸鎳庡畷?md` 閹?.5闁挎稑顧€缁?
      //    闁告瑯浜濇晶?婵絾鏌ㄩ埀?vs 闂傚啫鐗嗛埀?濞村吋姘ㄩ幋椋庣磼椤撯剝顥戝ù?濞戞挶鍊栨俊鍝ヤ焊閸濆嫮鎽嶅☉鎾崇У濡叉悂宕ョ仦鑲╊伇濞戞搩浜弳杈ㄦ償?閺夆晜鐟ゅ▎銏＄鐎ｃ劉鍋?
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
        // 濞存嚎鍊楃划?closeFullScreenPlayback闁挎稒鑹鹃悾鐘冲濮橆厼澶嶉柣顐熷亾闁硅泛锕ら懜浼村矗濡厠澶愭⒒閺夋垵鐓?0 闁告劕绉村畵蹇旀姜?
        this.closeFullScreenPlayback();
        return;
      }
      // 婵炲眲銈囩畺闂傚啫鐗嗛埀顒傘€嬬槐鏉款嚕閻熺増绀€閻庣懓鏈弳锝夊箑娓氬﹦绀夋鐐跺煐婵℃悂鎯勯梹鎰Т闁衡偓鐠虹儤绀€ OPEN
      this.expandState.morphDrive = MorphDrive.ANIM;
      // 闁宠棄鎳夊Σ?P0-3闁挎稒姘ㄥù澶嬫媴瀹ュ懐绉哄ù锝呯У閺佸ジ鎮?*闁绘瑯鍓涢悵娑欑閿濆棭鍋?*闁挎稑鐗呯欢鐑藉箲椤旀娼岄悗娑欘殕椤?`dismissSettleGen` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柨?
      //   濞戞挸绉撮崯鈧璺虹Ф閺?`morphGen` 闁炽儲鏌￠埀?閻庣懓鍟╃槐鎵偖椤愨剝宕插ù锝嗘礃閺屽﹥瀵煎宕囨▓ ++闁挎稑鑻閬嶆嚊绾惧绠规繛鍡忓墲閺佸湱浜搁幑鎰垫蕉闂傚牊鐟╃划顖滄崉鐎圭姷绠栭柨?
      //   闁?`morphDrive` 閻忓繗椴稿鍫熸交濠婂啩绮婚柛?`ANIM`闁?
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
          // 闁哄牜鍓濋悿鍡涘炊閻愯尪鍓ㄧ€规瓕灏～锔界▔鐎ｂ晝顏辨繛鍡忊偓铏鐎殿喚鎳撹ぐ鍥ㄧ?
          return;
        }
        // 闁?闁烩晠鏅茬紞鍛啅閼奸娼堕柛鎺濆亞濞堟垶瀵煎宕囨▓闁规亽鍎抽鍝ヤ焊閸楃偟绠戝銈囩帛閺備線骞嶇€ｅ墎绐楅柡鍌烆暒缁斿瓨娼钘夌彌闁告柣鍔嬬槐浼村箮?`drive` 缂?`FINGER`闁?
        //   `morphBeginEntering` 濞村吋纰嶆俊?`stage` 缂?`ENTERING`闁靛棔姊梒loseFullScreenPlayback`
        //   濞村吋纰嶆俊?`isClosing` 缂傚喚鍠氬﹢?闁炽儲鏌￠埀?濞戞挸顦遍～鎺楀箳閵壯屽悁闂侇喖鈧喎鍘撮悶姘煎亗缁楀倿妫冮姀鐘叉闁哄鍓濈亸鍛媴韫囧鍋?
        //   闁告瑯浜濆﹢?闁哄牜鍓濋悿鍡樼瀹ュ棙笑闁烩晠鏅茬紞鍛▔鐠佽櫕鐪?闁哄啳鍩栨晶鐘恒亹閹哄秶绉撮柕?
        if (this.expandState.morphStage !== MorphStage.LEAVING
          || this.expandState.morphDrive !== MorphDrive.ANIM) {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss bounce: phase taken over stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}, skip settle`);
          return;
        }
        // 闁?`morphSettleOpen()` 闁告劕鎳橀崕瀛樺濮橆厼惟 `morphDrive` 鐟?`NONE`
        //   闁挎稑娼塒layerExpandState` L2421闁?*闁稿繈鍔嬬划銊╁船椤栨瑧顏?*闁汇劌瀚粩濠氭⒖閸撲礁浠柨娑橆槴閳ь剚鏌￠埀?
        //   閺夆晜鐟ょ粩鏉戭潰閵夈儲鐨戦柡?濠㈢懓鍟块惇浼村礂鐎ｎ喗鐣烽悘鐐插€搁悥鑸点仚?闂侇叏绲惧?bug 闁汇劌瀚闁肩瓔鍨界槐?*濞戞挸绉烽々锔剧磼閺囷紕绠栭悗?*闁?
        this.expandState.morphSettleOpen();
      }, 240);
      return;
    }
    // 闁哄啰濮靛﹢渚€寮崼銉︽櫔闁绘劙鈧稓鐟濋弶鈺傚姌椤㈡垿寮鐢洭骞嶆担鍝ヮ伌閻忕偐鍋撻柨娑樻湰濠㈡骞嶇€ｎ偄濮悺鎺撳▕濡插洭宕愰崗鐓庮枀闁烩晛鐡ㄧ敮鎾礂閹惰姤锛旈柕?
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

  // 闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?閻忓繋绶氬?+ 婵繂鑻幃鏇犵磼椤撱埄妫ч柛鎺斿閻℃洜鎷犲澶堚偓澶嬨亜閸洖鍔ラ柨娑樻箯2闁挎稑顦弨銏ゅ煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀?

  /**
   * 闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺?閻忓繋绶氬?/ 婵繂鑻幃鏇灻归鑲╂勾闁?*閻犳亽鍔戦妴澶屸偓瑙勭煯缂?*闁挎稑鐗嗛顕€寮介崶銊︼骏闁?`floatingCover` / `floatingMeta`闁挎稑顦弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩?
   *
   * 闁告帒娲ら崺灞筋潰瀹€鍐Г濡炪倕鐏氬鍌滄媼?*闁告艾濂旂粩鏉戭嚕閻樿尙娈遍梻?+ 婵繂鑻幃?*缂傚倵鏅涢惃顒勭嵁閸撲絿鈺呭礆閻楀牏鎽冮悹鍥хЧ閵嗗銇勯崼鏇炲姤闁挎稑鑻崹蹇涘炊閻愯尙娈遍梻鍫涘灲閵嗗寮捄鍝勬枾閻犱警鍨堕ˉ锝夊炊?闁炽儲鏌￠埀?
   * **闁?Swiper 闁汇劌瀚划鎾礉閵娿劎绠婚幖杈剧畵閳ь剚鍔曢幎姘仚閸楃偛袟**闁挎稑鐗呯粭澶愬及椤栨睛澶愭⒒閹绢喒鏀抽柛鏃戠厜缁辨岸濡?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸喐笑閺夆晜鐟﹂悧閬嶆晬閸絺鍋撶仦鑲╃憹闁?濞戞挶鍊濋妴澶愬触閸曨厽鏆板☉鎾亾濞?闁?
   *
   * 闁哄啰濮烽弲顐︽儍?`playerPane` 闁?`Stack { Swiper{ 閻忓繋绶氬鐗堛亜?; 缂佸瞼鍎ら悺鏇犳嫚瀹ュ鈧?} ; floatingCover ; floatingMeta }`
   * 闁炽儲鏌￠埀?閻忓繋绶氬鐗堢▔鎼淬垻鎽冮柛?*闁圭鍊稿﹢?Swiper 濞戞柨顑呴ˇ?*闁挎稑鑻崹蹇斻亜閸偅顦ч柡?*闁告艾濂旂粩瀛樼▔椤忓嫬甯楃紒?*闁革负鍔屾慨鈺呮晬濞戞瑧鎽冮悹鍥хЧ閵嗗鏌囬敐鍕伇濡炪倕鐏氬﹢浼寸叕椤愶絾笑濞戞搩浜為埞鏍ㄧ珶缁涘湱绀?
   * 闁告瑯浜濆﹢?`padding({ top: lyricPadTop() })` 閻犱讲鏅欑紞鍛村Υ?
   *
   * ## 濞戞挸顦柌婊勭▔瀹ュ懎缍侀梺?
   *
   * 1. **闁稿繈鍔屽┃鈧柛娆樹簼濠€浣圭▔閳ь剙顕ｉ悩鑼闂?*闁挎稒鑹鹃惃婵嬫閵忋們鈧鏌囬敐鍕暅闁活亞鍠庨惃婵嬫閵忕姴鍤掔紓浣哥箰閼荤喐娼诲☉娆掔檨閻忕偛鍋婄槐妾俻age 0` 闁告瑯浜滄晶?
   *    `MiniLyricLinesComponent` 缂佸苯鎼敍鎾绘晬婢舵稓绀?濞戞挶鍊撻崬銈囦焊娓氣偓濞间即宕ョ仦鐐槯闁告瑯鍨甸～?濞寸姴娴风划銊╁几閸曨亞鐟愰悘蹇撳綁缁楀宕ｉ婵嗗幋闁?
   *    闁圭鍋撳ù?*婵炲备鍓濆﹢?濞戞挶鍊涢埀顒€鎳嶇花鎵偘?閺夆晜鐟ュú鏍ㄧ?*闁挎稑鐗婂Λ顐︽⒒?`lyricFloatActive()` 鐎瑰憡褰冮崹褰掓晬婢舵稓骞?
   * 2. **闂傚牊鐟﹂娑㈠箑娴ｇ柉鈷堝銈夋涧閹洭鎳涢鍫氬亾閹邦剙鍓肩紒杈╁С缁楀宕?*闁挎稒鐡猼 = 0` 闂侇叏绲肩粩瀵哥博椤栨碍鐨戦柡鍕靛灣濠€锛勪焊娓氣偓濞间即鎯冮崟顔藉劙闁绘劕婀遍悡鈺勩亹?
   *    闁挎稑娼塒layerExpandState.lyricMorph(0)` 濠㈣泛绉堕弫銈囩磼椤撱埄妫ч悘蹇庣窔濞?`p=1` 闁汇劌瀚幃鎾寸▔閳ь剙鈻撻悽娈夸紓闁绘劗鎳撻崵鎴炴媴閺囶亞绀嗛柨?
   *    闁圭鍋撳ù鐘劙濮橈箑螞閹烘浜濆☉鎾亾閻㈩垎鍕⒕闁哄牆顦ぐ鑼崉瀹曞洦鐣辩€瑰壊鍣槐?
   * 3. **婵炴惌鍠栭惇鐗堢▔瀹ュ懎璁查柣顫妼濮樸劑寮弶鎴濞戞挸绉撮幆搴ㄦ偨?*闁挎稑娼塴yricFloat()` 濞戞挸鎼禍锝夋晬濮橆剛娈遍梻鍫涘灪閻ュ懘鏌岃箛鎾崇厒 / 閻庣妫勯惈鍡涙閵忊剝绶查悹褎婢樿ぐ鐔哥▔閳ь剚绺藉Δ鈧粩椋庝沪閳ь剟鏁?
   *    闁炽儲鏌￠埀?濞寸姭鍋撳☉鏂跨墦閸忔ɑ绋夊鍥ㄦ毎闁靛棔姊條yricPadTop()` 濞戞梻鍠愬Σ?0闁挎稑濂旂粭灞解柦閳╁啯绠掗弶鈺傜懃椤ㄦ粍绋夊鍡愬仾闁哄啯婀圭粩鎾嚊濞ｎ兘鍋?
   *
   * 闁宠法濯寸粭?**婵繂鐭侀惁婵嬪箑鎼存繄鐤勯柣銏ｎ唺缁斿瓨绋夐鍕憻婵炲备鈧啿袟**闁挎稑娼塋yricsComponent` / `AmllLyricView` 濞戞挸绉堕～顐︽晬婢舵稓绀?
   *   閺夆晜鐟╅崳鐑藉矗椤忓嫬袟"閻忓繋绶氬?婵繂鑻幃鏇灻归鑲╂勾闁汇劌瀚▔鏇熴亜闂堟稓鏆板ù?濞戞挸瀛╅悺鏇犳嫚瀹ュ鈧鎯冮崟顖樷偓濠囨焾閵娧勬畬闁谎冾潟閳?
   *
   * ## 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*濡炵懓宕慨鈺呭棘閻熸壆纭€鐎规瓕灏欓崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辩増娼诲☉妯侯唺鐎殿喖楠忕槐婵囩▔瀹ュ棙笑閻炴稏鍎靛Λ鍨嚕?*闁?
   *
   * 閺夆晜鐟╅崳鐑藉储閻斿憡闄嶉柡鍫濐槷缁斿瓨绋?`animateLyricMorph(toLyric)`闁挎稒姘ㄩ弫?`animateTo(360ms, EaseInOut)` 闁?
   * `lyricMorphT` 濞?0 閻炴稏鍎遍崺?1闁挎稑鐗婇崹銊╁矗瀹ュ懏鍊婚柨娑橆檧缁辨繈鐛崜浣规殸 `.onAnimationStart` 閻犲鍟伴弫銈夊Υ?
   * **闁绘粍婢樺﹢顏嗏偓鐟板暙閸戯繝宕氶悩缁樼彑**闁挎稑鐬奸幃濠囨偨閹插绀勬慨锝呯箣缁旀挳寮堕敓鐘插幋闁圭娲ら幃婊堝籍閻樺灚娅曢柣銊ュ鐢偊寮崶椋庣闁?
   *
   * ```
   *   闁?闁哄啰濮烽弲?*婵炲备鍓濆﹢浣规交濞嗘劖钂嬮悶娑栧劦濡?*闁挎稒鑹鹃悾鐘绘儍閸曨偆娈遍梻鍫線缂嶅懐绱旈鐐函闁规亽鍎插Σ?`morph.scaleAt/txAt/tyAt(swiperProgress)`
   *      闁炽儲鏌￠埀?`swiperProgress` 閻忓繗椴稿Σ?Swiper 闁汇劌瀚划鎾礉閵娿劎绠婚幖杈捐缁辨瑧鎲?閹?16.2 闁汇劌瀚伴埀顒佸姈濞碱垳鈧稒顨夋俊顓㈡儘娓氬﹦绀嗛柕?
   *   闁?`.onAnimationStart` 闂侇叏绲惧顖滄崉椤栨氨鏁ㄩ悗鐟扮墕瀹曞ジ濡寸€光暘dex === targetIndex 闁?閻犲搫鐤囩换鍐Υ?
   *      闁?闁告瑯浜ｉ々锕傚礆閸ヮ兙鈧绋夊鍡樞?濞戞挴鍋撴繛鍡磿濠€鈥愁煥閹存繂袟"闁挎稑鐗忛埢鍏兼償韫囨挸顕ч柛鎺戞喘閵?/ 闂佹彃绉电€垫洘娼挊澶婄仴濠殿喖顑夐妴澶嬬▔瀹ュ棙笑 0 / 濡炪倕鍚€缁楀矂鎮╅懜纰樺亾娴ｉ鐟濆☉鎾亾闁肩柉鎻槐姘舵晬?
   *        闁轰焦娼欓〃婊勵槹閻愰鏀?*婵ɑ鐡曠换娆愮▔瀹ュ懏鍎欓柛?* 闁?`lyricMorphT` 闁?0 闁?閻忓繋绶氬浼村箒閹哄秷绀嬪鍫嗗啰娈遍梻鍫娇閳?
   *        **闁活潿鍔嶉崺?2026-10-16 闁汇劌瀚崺鍛村炊閻愵剦鍔€闁哄嫷鍨电换鏍ㄧ▔椤忓嫯鍩岄柣?*闁挎稑鐗嗛妵鍥╀焊娓氣偓濞间即宕ｉ悩鍨祷婵繂鐭侀惁婵嬫晬婢跺牃鍋?
   *   闁?闁告帞濮电敮鈧☉鏂款儏閹?`t` 闁?`onSwiperContentDidScroll()` **闂侇偅鍔曢幎?*闁告劖鐟辩槐娆戔偓瑙勆戦弻?SDK闁?
   *      "invoked ... on a frame-by-frame basis"闁挎稑顧€缁?*濞戞挸绉崇欢椋庢導閺嶏附宕插ù?闁告瑦鍨归弫鎾存交閸ワ妇顏辨繛鍡忓墲缁箓宕?**闁?
   * ```
   *
   * 闁宠法濯寸粭?濞戞挸楠搁悾鐘崇▔閳ь剛鎸ч摎鍌滅憹闁告劕绉烽～锔芥媴鐠恒劍鏆忛柣銊ュ缁绘洟寮垫径娑氱獥`lyricSwiperSettled` / `lyricFlightSettled`闁挎稑鐗撻崑鍛偓?濞戞挶鍊濆Λ鍫曞箵閳╁啫顤?闁?
   *    濞?`LYRIC_MORPH_DURATION_MS`闁靛棗鍊搁悾鐘崇?*濞ｅ洦绻勯弳鈧☉鎾虫惈閻⊙冣枔?閻㈩垱鎮傞崳?*闁挎稑鐗嗙粣姗€寮介崶锔剧煗闁瑰灚鎸稿畵鍐礈瀹ュ嫯鈷堝☉鎿冧悍缁辨岸鏁?
   *    濞?*婵炲备鍓濆﹢浣搞€掗崣澶屽帬闁活潿鍔戦埀?* 闁炽儲鏌￠埀?闁兼眹鍎抽垾妯兼媼閵堝嫮鐟濋梻鍥ｅ亾閻熸洑绶ょ槐婵嬪矗椤栨瑤绨伴柡浣割嚟缁秹宕氶悩鍐茬闁?
   * 闁宠法濯寸粭?`lyricMorphVisible` / `lyricMorphOpacity` 闁绘粍婢樺﹢?*闁告瑯浜ｉ～锕€顕ラ懞銉у灱閻?*闁挎稑濂旂粭澶愬礃瀹ュ锛屽ù锝呯箣閹广垺鎷呴弴鐘靛笡闁?
   *    闁挎稑鐗婇崹婊堝箮婵犲倸寮块梺顔哄妽缁夐鎷归崷顓炰化婵炴挸鎳愰崑锝嗘交閸ラ绐楅梻鍕╁€撶花锛勬導鐎ｎ亖鍋撻懖鈺佷化闁挎稑鑻ぐ褔寮?`refreshDiagText` 闁革负鍔忛浼存晬婢跺牃鍋?
   *    闁?闁圭鍋撳ù?闁哄秴娲ょ换鏂库柦闄囬～锔藉緞瀹ュ嫮绉?濞戞挸绉崇槐浼存焻閻樺啿鐏囧ù鐘侯唺缂嶅秶鎲撮崒娑樺Τ闂傚偆鍣ｉ。浠嬫晬閸絿绠瑰☉鎾亾闁绘劘顫夊Σ?*婵炴挸鎳愰崑锝夊礄閻戞ɑ闄嶉柣?*闁挎稑濂旂粭澶愬及椤栨稑鑵归柡鍌ゅ弿缁辨岸濡?
   */

  /**
   * `Swiper.onContentDidScroll` 闁汇劌瀚ˇ鈺呮偠閸℃鐝?闁炽儲鏌￠埀?**闁哄啰濮烽弲顐︽儍閸曨喚绠婚幖杈鹃檮缁?*闁挎稑鐗撻埀顒佸姈濞碱垶鎮¤婵￠亶鏁嶆径鍫氬亾?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*濞ｅ浂鍠氶弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鏈悺鏇犳嫚瀹ュ鈧浜告笟鈧鏉库柦閳ュ啿缍侀悘蹇撶箞閳ь兛绀佽ぐ鏃堝捶閵婏妇鎽冮悹鍥хС缁楀倿妫冮～顑藉亾瀹ュ洦鐣遍柡?*闁?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸繄绠戝銈囩帛濠€浣衡偓鐟板枦缁辨瑩宕㈤悢鍛婇檷闁汇劌瀚伴埞宥夊礉閵婏妇鐖遍柡鍕靛灦閺佸﹪鎯冮崟鍓佺
   * 闁告鍠愬?`lyricMorphT` **闁?*闁?`.onAnimationStart` 濡炵懓宕慨鈺呮晬瀹€鍐ｅ亾瀹€鍕簼濞戞搩浜滃ú鏍嫬閸愩劎鏁ㄥ☉鎾亾濞戞搩浜滈悾褔宕?
   * 闁靛棗鐣璱ndex === targetIndex` 闁?閻犲搫鐤囩换鍐Υ瀹ュ啠鍋撻崒娆掆拡缂佸绉甸崕蹇涘礃閸忓摜鐟撻弶鈺傜懁闁叉粎鈧懓鐗嗗畷鍏煎濮樻剚鍞ㄩ柡浣规綑椤ㄦ粍顦伴悙棰濇斀**婵ɑ鐡曠换娆愮▔瀹ュ懏鍎欓柛?*闁?
   *   鐠?濡炪倗鏁诲浼村礆閸ャ劌搴婂☉鎾崇У濡?濞戞挴鍋撴繛鍡磿濠€鈥愁煥閹存繂袟"闁挎稑鐗呯欢銉︿繆?swiper 閻炴凹鍋嗛埢鍏兼償韫囨挸顕ч柛鎺戞喘閵嗗濡存担鐟扮仐闂佹彃绉电€垫洘娼懞銉︻槯闁告帗绻傞～鎰亜闂堟稒鐨戝☉鎾崇У濡?0闁挎稑顧€缁?
   *   鐠?闂佹彃绉电€垫洘娼挊澶嬪€?濡?濞?闁绘鍩栭埀?濞戞挸绉崇粩鎾嚊鏉堝墽绀刞onAppear` 濠㈣泛绉崇紞鍛交閸モ晛鍋嶇€殿喗娲╃槐姘跺Υ?
   * 闁?`lyricMorphT` 闁?0 闁?閻忓繋绶氬浼村箒閹哄秷绀嬪鍫嗗啰娈遍梻鍫緛缁辨繈鎳撶仦鍓ф憙閻犲洤绉甸婊堝棘閸モ晛寮鹃柡宥夋敱濡绮?闁?
   *   **閻忕偛绻嬬粭鍌滀焊鏉堛劍笑"濠㈠爢鍐闂傚牄鍨硅ぐ鏃堟儓閳ь剙顫㈠畝鍐Г"**闁挎稑鐗忛弫銈夊箣?2026-10-16 闁规惌浜滃ù姗€鏁嶆径鍫氬亾?
   *
   * ## 闁哄啰濮烽弲顐︽儍閸曨偂绮垫繛澶嬫穿缁辨獋wujie.pa` L190026-190075闁挎稑鑻悾鍓х矙?閹?.2 闂侇偅鍔栧顖涙姜椤掆偓閸熸捇鏁?
   * ```ts
   *   let p = position;
   *   if (index === 0) {              // 闁?闁告瑯浜滃﹢?鐟滅増鎸告晶鐘炽亜閸偅笑闁圭虎鍘介弬浣广亜?閺夆晜鐟ょ粩瀛樼瑹瑜嶇紞濠冪▔閳ь剟宕?
   *     if (p < 0) { p = -p; }        //    鐎垫壋鍋撻柛鎾崇У缁箓寮?position 濞戞捇缂氱粈?闁?缂傚牏绮?
   *     if (p > 1) { p = 1; }         //    濞戞挸锕ら妵娆撳礆?1
   *     this.swiperProgress = p;
   *   }
   *   publishCoverStyle(); syncMotion();
   *   if (this.swiperProgress > 0.5 && !this.chromeHidden) { this.showChrome(); }
   * ```
   *   闁宠法濯寸粭?**闁告艾楠稿畷鎰枔绾板绀勬慨婵嗙焷閻︽繃銇勯悽绋夸簼濞戞挴鍋撳〒姘€宥囩濞ｅ洦绻冪€垫梹绋夋繝浣侯伇婵炲棴绱曞▓鎴﹀磹?* 闁?**闁稿绮屽﹢顏勵潰瀹€鍐Г濡炪倕鐏氬?`p` 闁诡厽甯婄拹?1**闁?
   *   闁宠法濯寸粭?闁哄啰濮烽弲顐︽焽閿濆牏鐝?`onChange` **濞戞挸绉撮崯?* `swiperProgress`闁挎稑鐗嗛悾鐘诲矗椤忓嫪绮?idle/chrome 濞?
   *      `atLyricScreen = (v === 1)`闁挎稑顦埀顒佹煛閳?闁圭鍋撳ù鐘劜濠€浼村棘鐟欏嫮銆婇柟闈涚У濡叉悂宕娆戭伇闁告劖鐟ч崑锝夊Υ?
   *
   * ## 闁瑰瓨鍨冲鎴︽儍閸曨剙澶嶆繛澶嬫穿缁辨瑩宕ョ仦鑲╊伇濞寸姴鈧噥鍤斿☉鏂款檧缁?
   * `lyricMorphT` 閻忓繗椴稿Σ鎼佸嫉椤戣法娉㈤柣?`swiperProgress`闁? = 閻忓繋绶氬鐗堛亜閻㈡浼?/ 1 = 婵繂鐭侀惁婵囥亜閻㈡浼傞柨娑橆檧缁?
   *   鐠?闁稿繐鐗婃俊鍝ユ閵忕姷绌块悹浣瑰婢跺嫰鏁嶉崸鍒糿Change` 闁?缂佸顑呯花顓㈠礌閺嵮冪€煎?闁哄啳娉涜ぐ鏌ユ嚄閹存帞鐟濋悷娆欑畱瑜板倿鏁嶅畝鍐闂佹彃鐭傞埀顒佸姇閹舵岸鏌堥懞銉︾畳闁稿﹦銆嬬槐姘舵晬?
   *   鐠?闁告劕绉垫俊姝屻亹閹哄秶顏遍柛鏍ㄧ墪閹鎯?`p` 闁哥姴鍊荤划?`lyricMorphT`闁?*闂侇偅鍔曢幎?*闁挎稑濂旂粭宀勫籍閻樺灚娅曢柛姘焿缁辨岸鏁?
   *   鐠?闁绘帟娉涢幃妤冩嫬?`syncLyricMorphToPage()` 闁?闂傚牊鐟﹂娑氱博椤栨粌浠煫鍥ф嚇閵嗗繒绮垫径澶岃壘鐟滅増鎸告晶鐘炽亜?闁汇劌瀚崢瑙勬償?
   *     闁挎稑鐗愬▔鏇熸交?0.5 闁哄啳娉涢悾鐘冲濮樹箻澶嬬▔閳ь剙鈻庨埥鍛濞ｅ洦绻嗛惁澶嬬▔瀹ュ嫮绐楅柛瀣矊濠€顏呯▔閵堝浂浼傚☉鏂款儔濡潡鏁嶆径鍫氬亾?
   *   闁宠法濯寸粭?濡炪倕鎼悽顐﹀箮婵犲啯锟ラ柣锝呯焸閸嬪懘宕?`if (p > 0.5 && !chromeHidden) showChrome()` 濞戞梻鍠愰幆澶嬫交閸ャ劍闄?闁炽儲鏌￠埀?
   *      閻庣懓鍟銊╁及?婵犲﹥鍨甸崺灞剧▔閳ь剟宕℃繝鍐ㄎ╅柟璨夊啫鐓戦柛鏍ф惈閺佹粓宕欓悜妯婚檷"闁汇劌瀚晶婊堝箛閻旂补鍋?
   * @param index 鐟滅増鎸告晶鐘炽亜绾板绀? = 閻忓繋绶氬鐗堛亜绾板绀? = 婵繂鐭侀惁婵囥亜绾板绀?
   * @param position 闁告劕鎳庨鎰版儎缁嬫鍤犲☉鎾存闁拌京鎸ф搴′化闁汇劌瀚簺闁告柣鍔嶉惁顔界瑹鐎ｅ墎绀勯悗瑙勆戦弻?SDK 闁告鍠愰弸鍐晬?
   */
  private onSwiperContentDidScroll(index: number, position: number): void {
    this.diagScrollCount = this.diagScrollCount + 1;
    this.diagScrollLast = `${index}/${position.toFixed(3)}`;
    // 闁冲厜鍋撻柍鍏夊亾 闂侇偅鍔栧顖炴偂瑜庢俊閬嶅籍閻樺灚娅曢柣銊ュ缂嶅﹥绋夐埀顒勫礌?闁冲厜鍋撻柍鍏夊亾
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
    // 閻犱焦濯芥径?婵犲﹥鑹炬慨鈺傜瀹ュ懏韬弶鈺傜椤?闁挎稑鐗愰～?`lastScrollAtMs` 闁汇劌瀚弫鐐烘煂婵犲繒绐楅柦鈧挊澶屾毎闊洤鎳橀妴蹇曟媼閳衡偓缂嶅懐绱掑▎鎾亾閹邦剚濮庨弶鈺傜☉鐎规娊鏁?
    this.lastScrollAtMs = Date.now();
    // 缂佷究鍨圭槐鈺冩媼閹峰苯顦╅柨娑樻綁onContentDidScroll` 闂侇偅鍔曢幎姘舵焾閻ｅ瞼鑸?`index`闁挎稑鏈惁?`onChange` 闁哄洦娼欒ぐ鏌ユ閻欏懐绀?
    if (index !== this.playbackSwiperIndex) {
      this.playbackSwiperIndex = index;
    }
    // 闂傚牊鐟﹂娑氱博椤栨粌浠柛蹇旂矊缁ㄦ娊鏁嶅铏《閺?0.5 濞戞柨顑呴幃妤呭箮?`t` 闁解偓閽樺鏆伴柛鎺撴緲缂嶅宕滃澶堚偓澶屸偓鐢垫嚀缁ㄦ煡鎯冮崟顓т紓闁?
    // 闁挎稑娼塻yncLyricMorphToPage()` 闁告劕鎳橀崕鎾嵁閸屾粎鎼奸柨娑樺缁楁牗顦伴悙棰濇斀濞戞搩鍘虹粭澶嬪濮橆厼鈪甸柡鍌ゅ弨钘熼梻鍌濇彧缁?
    this.syncLyricMorphToPage('scroll');
    // 闁哄啰濮烽弲顐﹀触鐏炵虎鍎ラ柨娑欑缁附娼婚崶褍纾圭紒瀣儏濮樸劑骞庢繝鍐ㄤ粯闁告帟娉涚亸顖炲船閵堝懎姣夐柡澶堝劵缁辨獋chromeHidden` 濞戞挸鎼禍锝夊籍閼搁潧顤呴柛鐐€х槐?
    if (this.lyricMorphT > 0.5 && !this.chromeCollapsed) {
      this.touchChrome();
    }
  }

  /**
   * 闁?閻忓繋绶氬鏉棵归鑲╂勾濡炲鍋犻、鎴炴交濞戞ê顔?**閻庨潧缍婄紞鍫ュ礆閺夎法绉奸柛鎾崇Ч閵?* 闁炽儲鏌￠埀?濞戞挸绉崇欢椋庢導?闁告瑦鍨归弫鎾存交閸ワ妇顏辨繛鍡忓墲缁箓宕?闁?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*濞ｅ浂鍠氶弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鏈悺鏇犳嫚瀹ュ鈧浜告笟鈧鏉库柦閳ュ啿缍侀悘蹇撶箰瑜版棃宕烽妸锔炬憙閻犲洤绉崇粭鍌炴椤兘鍋?*闁?
   *
   * ## 闁活潿鍔嶉崺娑㈡儍閸曨噮娼庨悗鐢靛櫐缁辨瑩宕橀崘鑼毎闁诡儸宥囩
   * 闁规惌浜滃ù姗€鏌?*婵繂鑻幃?婵繂鏈晶?婵繂鐭侀惁婵嗩潰閿濆棙鐎柡鍕靛灠鐢洭宕烽妸銉ф闂傚牜婢€缁楀倿鎯?* 闁炽儲鏌￠埀?闂侇叏绲惧Σ?*閻忓繋绶氬鐗堛亜閻㈢浜濆☉鎾亾缂佹棏鍨冲▓鎴澝归鑲╂勾濞达絽绉堕悿?*
   * 闁挎稑鐗婇悺鏇㈠触瀹ュ懏韬悘蹇庣窔濞肩増绋夌€ｎ偅鐓?`META_GAP_BELOW_COVER(50)`闁靛棔绀侀惃婵嬫閵忊剝笑闁轰礁顕悰銉╂焽閿濆嫮顏卞ù?331闁挎稑顦埀?
   * 闁兼澘鏈悺鏇犳嫚瀹ュ棭鍔€闁?*鐎规瓕灏欑划锟犲及閸撗佷粵闁告垹鍎ゅ鍨?*闁挎稑鐗撻崑鍛存閳ь剛鎲?swiper 闁革负鍔庨?2 濡炪倗顣槐姘跺Υ?
   * 闁?濞戞挶鍊撳▎銏＄鐎ｎ亝鍊遍柡鍐煐閸ㄦ氨绮╃€ｎ亜娑ч柡鍫濐槷缁斿绮斿鍩挎帡鏌屾繝蹇曠獥**濡炪倝娼ч崹蹇旂閸☆厾绀夋繛鎼枛閻澘鈻介檱缁?*闁挎稑鐗嗙粣姗€寮?`edge=331 t=0.00` 婵繐绲惧Σ鍝モ偓鐟板枦缁辨岸濡?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸繂鏂ч柡澶堝劤濞堟垿宕樺▎鎰€婂ù鍏肩缁?
   * `lyricMorphT` 闁汇劌瀚弫顔界▔閳ь剚銇欓崡鐐残楅柣鎰潐濡?`.onAnimationStart`闁挎稑鐭侀埀顒€鑻悾鐘垫暜閿旇法顏卞☉鎿冧簻閻Ｑ囧础?
   * 闁?*鐎规瓕灏欑划锟犲捶閵娧勭獥闁哄秴娲妴澶嬬閸℃鐨戦悹鍝勭枃缁?*闁挎稑娼塱ndex === targetIndex`闁挎稑顦埀顒€绉查埀顒€鍊风花顒勫及椤栨艾娑ч悷鏇氱閸ゎ參鎮?
   * "鐟滅増鎸告晶鐘炽亜?= 婵繂鐭侀惁婵囥亜閻愬厜鍋撴担瑙ｅ亾?`lyricMorphT` 濞寸姴绉靛Σ?0"閺夆晜鐟ч～?*濞戞挸绉崇粩鎾嚊鐎靛憡鐣遍柛鎺撶箓椤劙骞€?*闁挎稑鑻銊╁礃瀹ュ嫮鐦嶆繛灞稿墲濠€浣圭鐠佸磭绉垮☉鎾寸矎閵堟寧瀵煎顒€绠靛ǎ鍥跺枟椤掓粎鈧懓鍠涚槐?
   *   鐠?閺夆晜绋掗幐閬嶅绩閹勭彜闁哄啯鍎肩€氥垻妲愰姀鐘电┛鐎圭寮跺Σ?1闁挎稑鐗呯粭鍌涚▔閳ь剚娼?`onAppear` 濠㈣泛绉崇紞鍛交?0闁靛棔鐒﹂崹銊ф閵忕姷绌块柡澶堝劥閸ゆ粓宕氶銏╂П闁挎稑顦崳?閻庣懓鐗嗗畷濂告儎鐎涙ê澶嶉悹鍝勭枃缁诲啴鏁?
   *   鐠?闁煎搫鍊婚崑锝夋煂瀹ュ懐绱﹂柛?`onAppear` 闁?`lyricMorphT` 鐟滅増甯掗崺?鐟滅増鎸告晶鐘炽亜闂堟侗鍤犻幖瀛樻⒒濞堟垹绮╅婊冧化"闁炽儲鏌￠埀?
   *     闁?*鐟滅増鎸告晶鐘炽亜?*閺夆晜鐟ら柌婊堝磹閸忓吋鎷遍棅顒夊亯鐎氥垺绋?swiper 閻庡湱鍋ゅ顖炲磻濠婂懏鐣卞銈呭悁缁楀绋夐埀顒勬嚊鏉堝墽绀夌憸鐗堝笒閸ゎ參寮堕妷褎鐣遍悘蹇氶哺濡叉悂鏌ㄥ▎鎴炵暠缂佹棏鍨抽崑锝夊Υ?
   *
   * ## 婵繐绲块垾姗€鎯冮崟顐㈠綘缂侇垯绱槐娆撳础閺囨氨顏遍柣顏嗗枑缁噣鏁?
   * ```
   *   playbackSwiperIndex闁挎稑鐗嗙紞瀣礈瀹ュ鈧鏁? 闁冲厜鍋撻柍鍏夊亾闁告劕鍟块悾楣冨煘閳ь剟鍩為埀顒勫煝? lyricMorphT 闁?*闂傚牊鐟﹂娑氱博椤栨粌浠?*
   *                                        闁? = 閻忓繋绶氬鐗堛亜閻㈢浜濆☉鎾亾缂佹棏鍨界槐? = 婵繂鐭侀惁婵囥亜閻㈢浜濆☉鎾亾缂佹棏鍨界槐?
   *   婵犲﹥鍨垫慨鈺傛交閸モ斁鏌ゅ☉鎿冨幘濞堟垹鎮伴妷鈺傦紵闁告瑯浜濆Σ?濞寸姴绨肩粩瀛樼▔椤忓棭浼傞柣鎰攰閾斿宕氶弶鍨稐濞戞挴鍋撳☉鎿冧簽椤忣剟鎮?闁?
   *   闁?*闂傚牊鐟﹂娑㈠箑?*婵ɑ鐡曠换娆戠驳婢跺鑹?鐟滅増鎸告晶鐘炽亜闂堟侗鍤犻幖瀛樻⒒濞堟垹绮╅婊冧化"闁?
   * ```
   * 闁?闁哄牜鍓氶弻鐔封枖閺囩偞鐨戦柡鍕靛灦閸嬪懘寮堕垾鍐插綘缂侇垵宕靛▓鎴犫偓鍦仧楠炲洭鏁嶅杈╁綄闁告娅曟俊?`t` 缂傚喚鍠栭崺宀冦亹閹惧啿顤呭銈夋涧椤曨喗鎯旈弮鍌涚暠缂佹棏鍨抽崑锝夋晬閸粎鐟濋柛鏂诲妿閺侀箖鏁嶆径鍫氬亾?
   *   鐠?濞戞挸瀛╃划锕傚礉閵娿倛鍘柣銊ュ钘熼梻?*濞戞挸绉撮崯璺ㄧ玻?*闁挎稒淇鸿棢闂傚倹娼欒ぐ褔宕?`lyricMorphVisible === true`闁挎稑鐗撻ˉ锝囨偘鐏炶壈鍘柨娑橆槹濡炲倿骞嶅鍡樼畳闁规澘绻嬬粻鐔兼晬?
   *     闁兼澘鏈﹢浼村棘鐟欏嫮銆婇柛娆樹簻濠€?闂傚牊鐟﹂娑㈠箑娴ｉ鐟撻柛娆愬灩楠炲洦绋夊鍕伇闁?闁哄啯鍎奸～锔炬嫬閸愵亝鏆忛柨娑樼墣椤棛鎷崘顏呮殢闁绘劗娅㈢槐姘跺Υ?
   *   鐠?妤犵偛鍊婚悺鎴︽晬濮橆剙鍤掔紓浣哥箰濠€顏勵潰閿濆洠鈧绮╅婊冧化闁哄啳娉涢崯鎾诲触鐏炶偐顏卞☉鎿冧簻閳ь剛銆嬬槐婵囩▔瀹ュ熆鏇㈠矗閹存粍宕插ù锝嗘礋閸ｅ摜绱掑Ο鐑樷枙鐎殿喖鍊堕埀?
   *
   * 闁宠法濯寸粭?閻犲鍟伴弫銈夋倷閻у摜绐梎aboutToAppear()`闁挎稑鐗撻妴澶愭閵忊€崇槸閺夌偠濮ゅ鍌溾偓闈涚秺缂嶅牊绋夐埀顒€鈻庨埥鍛濞戞挸楠搁崬瀵糕偓鍦嚀閻?`.onAppear()`
   *    闁挎稑鐗愭俊顓㈡倷閻熸澘姣夐柣婊呭濡炲倻鈧潧缍婄紞鍫熺▔閳ь剙鈻庨埥鍛闁?*濞戞挸绉烽々?*闁衡偓閹规劗绠绘繝濠冨灥婵晠宕堕悙鍓佹闂佹彃鐭夌槐娆撴焽閿濆嫮绐楅柟鍨尰閺屽洨鎮伴妷鈺傦紵闁挎稑顦埀?
   * @param reason 闁告瑯浜為弫銈嗙鎼淬垺锛夐煫鍥殣缁辨獋boot` / `appear`闁?
   */
  private syncLyricMorphToPage(reason: string): void {
    const want: number = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*閻犱讲鏅欑紞鍛磼濞嗘挴鍋撻幇顒佸閺夆晜绋戠€?*闁挎稑鐭侀～?`lastScrollAtMs` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柨?
    //   `onContentDidScroll` 婵繐绲藉﹢顏堟焻閹邦剚濮庨柛?`lyricMorphT` 闁哄啳顔愮槐婵囨交濞嗘挸娅?*濞戞挸绉烽蹇涙媰閽樺鏆?* 闁炽儲鏌￠埀?
    //   闁告熬绠戦崹顖涚▔閵堝牃鍋撻崨顔炬Ж閻㈩垎鍌滈瀺闁烩晛鎲℃慨鐘诲磹绾绀勬繝濠冨灥閸╁本绋夐埀顒勫础婵犲拋娼跺☉鎾亾闁硅泛锕ㄩ鏇㈠礆閹殿噮浼傞柣?闁?闁汇垹顭峰鎵崉缁涘湱绀嗛柕?
    //   闁宠法濯寸粭?`boot` 闂侇叏绲鹃?*闊洤鎳橀妴蹇涘绩閹规劦鏀?*闁挎稑鐗撻妴澶愭閵忊€崇槸閺夌偠濮ゅ鍌涙交濡崵姊鹃柡鍫濐槷閹广垺鎷呴弴鐔烘硦闁告棏鐓夌槐婕檒astScrollAtMs` 濞?0闁挎稑顦埀?
    if (reason !== 'boot' && Date.now() - this.lastScrollAtMs < PlaybackPage.SCROLL_SETTLE_WINDOW_MS) {
      return;
    }
    if (this.lyricMorphVisible && Math.abs(this.lyricMorphT - want) < 0.999) {
      // 濡炲鍋犻、鎴炵▔椤撴繄鐟弶鈺偵戦惀鍛村礆閹殿噮浼傞柣?闁?闁告帩鍋呮晶锕傚棘椤撯埛澶愭⒒鏉堝墽绀勯弶鈺傜懄濞碱垶宕ｉ鍕含闁哄鑳堕顒勫籍鐠鸿櫣纰嶅☉鎾愁儐婢х娀宕ｉ婵嗗幋闁告稒鍨濋懙鎴︽晬?
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
   * 闁衡偓鐠鸿櫣鍟查柨娑欑摂wiper 闁煎浜滅换渚€鎯冮崟顐㈢€奸柟骞垮灩婵晠鎮界拋宕囩憿婵炴惌鍠栭惇鐗堫槹閻愰鏀?*闂侇喚鏅划銊╁级?*濞戞柨顑呴幃妤呭箥瀹ュ懎绁婚柟?濡炲鍋犻、鎴炵▔?閺夆晜鐟ょ粩鏉戭浖閿濆啠鍋?
   *
   * 闁宠法濯寸粭?閺夆晜鐟╅崳?*濞戞挸绉靛Σ?*闁硅泛锕ら惃婵嬫椤厾顏遍柛鎺嗗亾闁告帒娲︾敮鈧柨娑欑鐠囩偟浠﹂崒娑櫺?*閻㈩垱鎮傞埞?*闁汇劌瀚哥槐婵嬫媰閹存帞绉撮柛姘凹缁盯鎮?`playbackSwiperIndex`
   * 闁告帒妫欓弫顕€宕橀崘鑼毎閻庣懓鍟抽幆銈夊捶閵娿儲鎲垮☉鎿冧簽椤忣剟鎮欓惂鍝ョ婵繂鐭侀惁婵囥亜閻㈠憡楗慨婵勫灪閳ь兛妞掔划娑㈡倿閹偊娲ｉ柡鍕⒔閵囨岸鏌囬敐鍛倞閻忓繐绻愰惃婵嬫?+ 婵繂鑻幃鏇㈡晬婢跺牃鍋?
   * 闁告鍠愬鐢告儍閸曨偄鏅告繛澶嬫礃濡?`lyricMorphVisible = false` 闁哄啰濮靛顖涚鐠哄搫鏅告慨?闁?闁轰焦娼欓〃婊冾潰瀹€鍐Г濡炪倝娼ч惃婵嬫閵忕姾鍩岄柛娆惿戝Σ鎼佸礂瀹曞洦绲婚柣銊ュ閳?
   *
   * ## 闁宠棄鎳夊Σ?2026-10-16闁?*鐎瑰憡褰冮崹鐣屸偓瑙勭煯鐠愮喎顫㈢拋鍐叉暕闁活喕绶ょ槐婵囩┍濠靛牊娈屽☉鎾崇Т閸?*闁?
   *
   * 濞戞挶鍊撻柌婊堟偠閸℃瑦鏆犻柨娑樼焸閸忔﹢寮伴娑氼伕闁绘劗鎳撻崵顓㈠级閵壯勭暠闁?
   * 1. 闁哄牜鍓欓崵閬嶅极閹峰矈娲ｆ慨?`lyricSwiperSettled && lyricFlightSettled` **濞戞挶鍊濆Λ鍫曟焾閽樺鐓傚ù?*闁?
   *    闁兼澘鐬奸悿?`lyricFlightSettled = true` 闁?*闁哥儐鍨粩?*闁革妇澧楅弻鐔煎储閻斿憡闄嶉柛?`animateLyricMorph()` 闁汇劌瀚弫鍦焊?
   *    `setTimeout` 闂?闁炽儲鏌￠埀?闂侇叏绲奸柌婊堝棘鐟欏嫮銆婇柡鍫墲閻ゅ棗顔忛弻銉︻吂"闁衡偓绾懐绠婚幖杈剧畵閳瑰秹宕?濞戞挴鍋撻悹褍鍢查崹褰掓⒔閵堝繒绀勯悷娆庣劍閺嬪啯绂掗張鐢电憪闁哄倸缍婇崑鍛枔娴ｅ喚鍤涢柡鍕嚱缁?
   *    闁?`lyricFlightSettled` 婵ɑ鐡曠换娆撳及?`false`闁挎稑鐗撳▍搴ㄦ?`syncLyricMorphToPage()` 闁解偓閽樺鏆伴柡鍐ㄥ閻ゅ棝鎯囬悤鍌滅
   *      濞达絽妫濋崑鍛村级闄囬惌鐐▔?`lyricMorphVisible` 鐎规瓕灏欑划锛勬偖椤愩垻鏆婇柤濂変簻缁讳胶绱旈钘夌亣 `false`闁?
   *    闁?闁哄牜鍓欓崵閬嶅极?*闊洤鎳愰崝褔宕烽妸褜鍎戝☉鎾亾濞?`if` 濠㈣泛瀚换鎴﹀炊?*闁?
   * 2. 闁哄牜鍓欓崵閬嶅极閺夊灝娑ч柛?`lyricMorphVisible` / `lyricMorphOpacity` 濞戞挶鍊撻柌婊呪偓娑欘殕椤斿矂鏁?
   *    闁兼澘鐭佺换鏍ㄧ▔閵堝嫰鍤嬮悗娑欘殕椤?*闁绘粍婢樺﹢顏堝矗椤忓浂娼剁€垫媽濮ら悥锝囨嫚?*闁挎稑鐗嗛崣蹇涙焾閵婏妇啸閻犳劕婀遍崑锝咁啅閸欏顏搁柣鎰缁辨岸鍩?闁告鍘栨繛鍥┾偓鐟板暢缁愬洭宕氭０浣哄晩濞戞梻鍠愰惀鍛村嫉婢跺顩柡灞炬尭婵傛牠宕鍐ｅ亾?
   *
   * 闁?濞ｅ洦绻勯弳鈧柤鏉垮缁楀宕氶悩鍨暠闁荤偛妫涢弫閬嶆晬濮橆剛鏆婇柡?濞戞挶鍊濆Λ鍫曞箵閳╁啫顤?闂侇叏绲介〃婊呮媼閹规劦鍚€闁汇劌瀚弫鍦焊閸撗屼紓闁?*闁兼眹鍎遍惃銏ゅ级閵夛缚鍒掑璺虹Х钘熼梻鍌涙尦閳瑰秹宕?*
   *    闁挎稑鐗呯欢銉︿繆閸屾艾绲洪柣婊勫缁绘ɑ鎯旈敃鍌楁敵闁告柣鍔屽﹢顏堝蓟閹邦亪鍤嬮柡鍫濇惈閻庨攱绋夋繝浣虹憹闁告瑯鍨抽弫銈夋晬婢舵劖浠橀悷鏇氱閻ｇ姵绋夐埀顒傛導闁垮鍒掑璺虹▌缁?
   *    闁告帞濮崇花锛勪焊閸楃偟绻佸ù?git 闁告ê妫楄ぐ鍫曟煂鐏炴儳鑸归柕?*閻庣懓鍟╃粭澶嬪濮橆厽绠掗悗?*闁挎稑鐗嗙换鈧柣鎺曞煐濡參鏌呴埀顒勫Υ娴ｉ鐟柛娆樹簻閸熸挸顕ラ懞銉у灱閻犲洩宕靛▓鎴犫偓娑欘殕椤斿矂鏁嶆径鍫氬亾?
   * 闁宠法濯寸粭?闁兼眹鍎抽垾妯兼媼閵堝牏绠婚幖杈剧畵閳瑰秹宕濋妸顬ユ梻鈧鐔槐婵嬪矗椤栨瑤绨伴柟璺猴工閻?+ `lyricSwiperSettled` / `lyricFlightSettled` /
   *    `LYRIC_MORPH_DURATION_MS` **闁轰礁顕划宥夊礆閻樺啿绔?*闁?
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
   * @returns 婵炴惌鍠栭惇浼存煂鐏炵晫娈遍梻鍫涘灮濞堟垶绋夐埀顒傛暜瑜忛悡鈺勩亹椤喚绀剉p闁挎稑鐬奸悰銉╁矗閿濆懏缍忛柡宥呮祫缁辨岸濡?
   *
   * 闁宠法濯寸粭?2026-10-15闁挎稑鐗忛?2 闁秆勵樄閻ゎ垼娲柣鈺傜墪閻壆绱掗悢鍓侇伇闁?*闁告帞濮电敮鈧ù婊冩缁椾焦绋夐鍕殥婵繆宕靛▓鎴犵矓娴ｈ绠掗柡鍌濐潐绾?*闁?
   *   鐠?`lyricFloatActive()` 闁炽儲鏌￠埀?閻庣懓鍟敮顐﹀级閵夛附笑婵炴惌鍠栭惇浼存儍閸曨垱锛岄柨娑樼墕瑜把囧捶?濡炲鍋犻、鎴炵▔?婵繂鐭侀惁婵囥亜?闁归潧绉堕弫楣冩晬婢舵稓骞?
   *     閻熸洖妫涘ú濠勪沪閸屾稒鏆柟?*閻㈩垱鎮傞埞?*濞戞柨顑呴幃妤€鈻介埄鍐╃畳濞寸姾顔婄紞宥囨嫬閸愵亝鏆忛柣鎰畭閳?
   *   鐠?`lyricFloatMetaOpacity()` 闁炽儲鏌￠埀?闁告鍠愬鐢垫媼閳哄倻鎽冮柛姘Т濠€?`t=0` 閻庣懓鑻崣蹇涙焻韫囨梹顫栭柨娑樼墦閸嬪懏绋夐埀顒勫礆鐠囪尙娈遍梻鍫涘灲閵嗗鏌囬敐鍕暅婵繂鑻幃?
   *     闁?`MusicPlayInfoBlock` 闁活澀绱槐姘舵晬濞戭潿鈧?0 濞戞挸绉撮崯鈧柣銏ｎ嚙閻ㄦ繈妫?婵繂鑻幃鏇熺▕鐎ｎ亝鍊甸悗鐟板暞娴滆姤绋?1闁?
   *   鐠?`lyricFloatMetaWidth()` 闁炽儲鏌￠埀?婵繂鑻幃鏇㈠锤濡も偓鐢偊寮堕妷锔藉瘻妤犵偛鍟块惇铏▔椤撴壕鍋撴担鐑樻殢閻庣懓鍟伴悾濠氬锤濡も偓椤旀棃鏁?
   *     闁绘粍婢樺﹢顏堝及?*濞戞挴鍋撴俊顖ｄ海椤?*闁挎稑鐗嗘稊蹇涘礃閸涙壆鐝堕悹鐑樼箘閺?`lyricMetaLeftInset()` 缂備焦鐟辩槐姘舵晬鐏炶偐鐟濋柛鎰Ч濞撳墎鎲版担鍝ユ殜闁?
   *   闁烩晝顭堥崣褍鈻旈妸鈺佹珵闂佹彃鑻崵鎺撴交濡搫鏅搁柣顐熷亾"闂傚倶鍔屽﹢?`lyricFloatActive()`"闁汇劌瀚﹢鎾棘瑜版帒鍘寸€瑰憡褰冨銊╁捶閻楀牊鏆慨婵撶祷閳?
   */
  private lyricFloatRect(): LyricMorphRect {
    return this.expandState.lyricMorph(this.lyricMorphT);
  }

  /**
   * @returns 閻忓繋绶氬浼存焽閿濆嫮顏遍悘?*閻庡湱鍋ゅ顖滄啺娴ｇ鏅搁弶?`.position()` 闁汇劌瀚悡鈺勩亹?*闁挎稑婢妏闁挎稑顦埀?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁逛勘鍊曞ú鏍箣閹存粎鐟愬☉鎾亾闁绘鐗忓▓鎴︽焻閸℃缍侀柟?*闁挎稑鐬奸弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鑻惃婵嬫閵忊剝笑濡炲鍋涢崺宀€浠﹁箛鎾额啂濠㈣埖鐗撻埀顒€绋勭槐姘舵晬?
   *
   * 濞戞挸锕ｇ粩鎾偋閸喎鐏夐柛锔哄姀缁绘牠鏌屽畝鍐 `coverLocalRectFor()` 闁?閻忕偛绻愮粻鐑藉锤閹邦厾鍨?闁?閻庡湱鎳撳▍鎺楀嫉椤掆偓濠€鎾锤閹邦厾鍨?闁汇劌瀚伴埀顒€妫楄ぐ澶愬箲椤喚绀?
   * 闁告挸绉佃ぐ渚€寮?**`.scale()` 缂備焦娲栭鎰板闯閵娿倛鍘煫?*闁靛棗鍊诲﹢锟犲嫉鏉炴壆鐟愮紓浣规尰閻忓寮伴姘辨闂?*濡炲鍋涢崵顓犱沪韫囨挾顔?*闁?
   *
   * 闁宠法濯寸粭?閺夆晜鐟ら柌婊堝礈瀹ュ棗绲归柛锔哄妽濠€鐗堢?*闁哄啠鏅涘銊╁嫉婢跺海绠栧☉鎾亾婵炲棴绱曞﹢锟犲嫉閸濆嫬鍐€閻?*闁挎稑娼塵orphCoverRectAt()` 闁汇劌瀚弫鐐烘煂婵炲簱鍋?
   *   `LyricFloatLayer` 濡炪倕鐖奸崕?闁宠法濯寸粭?2026-10-15 闁告帞绮崜鐗堢▔瀹ュ棙鏆?闂侇叏绲肩粩鏉戔枔绾板绀嗛柨?
   *   > 闁靛棗鐭傞埀顒€妫楄ぐ澶愬箲閵忕姵绀€濡炪倝娼ч崬鎾锤閹邦厾鍨?闁炽儲鏌￠埀?闁活亞鍠愬┃鈧紓浣规尰閻?**閻忓繋绶氬鎵崉閹存繂鐓傜€归潻缂氱粭鍌滄喆?*"闁挎稑鐗愰鈺呭及?`.scale()` 闁汇劌瀚悘鎴炴姜?
   *   >   **濞戞挸绉靛Σ鎼佸箣閹存粈绨板☉鎾规濞堟垹鈧湱鎳撳▍鎺撶▔椤撶偟濡?*闁挎稑顦崳?閻犲洢鍎查弻鐔奉浖閸粎绋婇幖瀵稿櫐缁?*闁告帩鍋勯崯鈧悹?*闁靛棗鍊堕埀?
   *   闁?闁瑰瓨鍨肩换鏍р枎閿涘嫮鎼煎ù?*闁告鍠庡﹢鎾煂瀹ュ牅鍒婂ù婊冩缁旀挳鏌?*闁挎稑鏈弳鈧悹渚囧弨椤斿洦娼?`RzdMusic閻犱焦婢樼换?md` 閹?6闁?
   *
   * ## 闁绘粍婢樺﹢?= 缂佺虎鍨伴崵鎴炴媴閺囨ǚ鍋?*濞戞挸绉存禒娑欑鐠佸磭绉块柛褎鍔栭悥锝囧寲缂佹ê搴婄紒?*闁挎稑鐗嗗銊╁及椤栨粍鏆忛柟鎾棑閳ユ鎷嬮妶鍫㈢畺"闁绘粍婢樺﹢顏勵潰閿濆懐鍩楀ù?闁汇劌瀚伴崑鍛▔閳ь剟鎮ч崼顒傜
   *
   * ```
   *   閻忓繐鎼?/ 濞达絽绉堕悿?/ 闁革箑妫滈～妤佺▔閳ь剙顕ョ€ｎ亜绲?lyricMorph(t)闁? 闁哄啰濮烽弲?CoverMorph 闁汇劌瀚欢顓㈠礄閻氬绀?
   *   闁烩晛鐡ㄧ敮鎾礃濞嗘帞绠?.position() / .width() / .borderRadius()
   * ```
   * 闁哄牜鍓欓惇浼村箰閸屾碍韬憸鑸灩瑜板鈧湱鎳撳▍?*闁告劕鎳橀崕?*闁挎稑鏈晶宥嗙閵夈儴鍩岄柛娆惷奸懙鎴犫偓鐟板暟濞?*閻庡湱鍋ゅ?*閻忕偛绻愮粻閿嬫媴瀹ュ嫮绐楅悶姘煎亜椤旀劙宕抽妸銉ョ秮闁瑰箍鍨虹亸鎾舵導?
   * 闁挎稑娼墆' 闁?t鐠虹椊`闁挎稑鐭侀～?`LyricFloatLayer` 濡炪倕鐖奸崕鎾焽閿濆棭鍞介柟鎭掑妼椤曢亶鏁嶆径鍡忓亾閺傝　鍋?閺夆晜鐟﹀?闁解偓閹存帞绉撮柡鍐煐椤掓粎娑甸琛″亾娴ｆ瓕鍩岄柛娆惷奸懙鎴﹀磻?
   * 闁汇劌瀚ぐ娑橆嚗?*闁活潿鍔嶉崺娑㈠捶閵娧勫焸闁哄牐妗ㄧ粭鍌涱殽瀹€鍐畺闁靛棔娴囬～鍥箛閻斿嘲璁查柟鎭掑劚瑜?*闁挎稑鐗嗛惃婵嬫閵忥絿顎€闁活偀鍋撻悗鍦嚀濞呮帗绋夐埀顒傛導妞嬪海绱氶柛姘灱缁姵鎷呴悩铏拫闁挎稑顦埀?
   * 闁宠法濯寸粭?閻庣懓鍟崹姘辩博鐎ｎ剚鐣遍柛鎾崇У瑜颁線寮?`t = 1`闁挎稑鐗愰幆銈嗘媴瀹ュ繒绀嗛柡鍐硾椤旀劙宕抽妸锔叫﹂柟顓熷笧閻℃垿宕ｅΟ璇插簥 闁炽儲鏌￠埀?闁兼澘鐭傞崑鍛潰閿濆棙笑闂傚牊鐟﹂娑㈠箑娓氬﹦绀夐柟顓熷笚閸ㄦ氨绮╃€ｃ劉鍋?
   */
  private coverLocalRect(): LyricMorphRect {
    return this.lyricFloatRect();
  }

  /** 濞戞挸锕ｇ粩鏉戔枎?`RzdCoverLocal` 闁汇劌瀚幆銈嗘媴瀹ュ浂鍔柛姘▌缁辨瑩鎳為崒娑氥偊闁汇埄鐓夌槐婵嬪矗椤忓嫭韬柣顏嗗枔濞堟垿宕ｅΟ鍦晩闁归潧绉垫晶锕傛晬婢跺牃鍋?*/
  private lastCoverLocalLog: string = '';
  /** `RzdCoverLocal` 闁汇劌瀚伴崳浼村冀閻ゎ垰螡婵炵繝绶ょ槐妾搒闁挎稑鑻懜浼村矗濡粯顦ф慨锝呯箰閹舵岸鏌堥幋鎺旂獥闁告瑦锕槐婵囧緞椤忓嫮妲曞ù鍏艰壘閸╂稓浠﹁箛銉х闁?*/
  private static readonly COVER_LOCAL_LOG_MS: number = 100;
  private lastCoverLocalAtMs: number = 0;

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16 闁哄倹婢橀·鍐嫚婵犲啯鐒介柨?*閻忓繋绶氬浼存媰閹存帞绉撮柣銊ュ椤?闁告瑥绉磋ぐ澶愬箲閵忕媭鍤犻悹?*闁?
   *
   * ## 閻庣懓鍟崹鑺ョ閳ь剚绋?
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdCoverLocal'
   *   闁?RzdCoverLocal t=闁?s=闁?tx=闁?ty=闁?screen=(x,y,w,h,r) local=(x,y,w,h,r)
   * ```
   * 鐠?`s = 1 / tx = ty = 0`闁挎稑鐗撳銈咁潰閵忊檧鍋撴笟濠勭闁?濞戞挶鍊撻柌婊堟儗閳轰浇鍩岄煫鍥ф嚇閵?*闂侇偅鍔曢悺褔鎯勭粙鎸庡€?*闁挎稑鐗嗗浠嬪矗濡搴婇柡鍕靛灡娴滅晫绮垫径灞剧暠闁挎稑顧€缁?
   * 鐠?鐟滆埇鍨硅ぐ澶嬬▔?闁?`local` 闊洤鎳橀妴?*閺夆晜绮岄妵鍥ㄧ?* `screen`闁挎稑鐗嗗ú婊勭▔妤︽娲ｉ悶?`s` 闁告ê顑呭ú鏍储娴兼瑧绀嗛柨?
   *   濞?`local.x/y` 闁告瑯鍨甸崗妯荤▔妤﹁法顦伴柨娑樼墕閻ㄦ繈妫冮姀鐘宠含閻熶椒绀佹竟鈧紒鎰殔瑜版稒绋婄€ｎ亶妯嗛柣銊ュ閸嬪懏绋夐埀顒勫箣椤忓海绀夐弶鈺傜懄濡茬顫㈤敐鍛煑闁汇劌瀚哥槐姘舵晬?
   * 鐠?**闁告帇鍊栧畵?*闁挎稒纰嶆俊?`s / tx / ty` 濞?`screen` 濞寸媴缍€缁绘鈧湱鎳撳▍鎺楀矗濡搴?
   *   `y_閻?= H/2 + (y_闁?闁?H/2)s + d` 閹煎瓨妫佺换鏇㈠储閻斿嘲姣?`screen.y` 闁炽儲鏌￠埀?闁兼眹鍎寸换鏇㈠储閻斿墎鐟濋柛鎴犲劋濞肩敻鏁?
   *   閻犲洤鐡ㄥΣ鎴犫偓鍦嚀濞呮帡鎯冮崟顒備杭閺?閻忓繐鎼顓㈠磻閸ヮ亶鍟庡☉鎾抽閻ゅ嫰鎮虫０浣虹憹缂佹璁ｇ槐娆撴焽閿濆棙顦ч悷鏇氱劍閺佸ジ鎯冮崟顒佇?`coverHostH()`闁挎稑濂旂粭澶愬及椤栨氨娈遍梻鍫緛缁辨岸濡?
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

  // 闁宠法濯寸粭?2026-10-16闁挎稒鐡猄QUASH_MIN` / `squashWrapHVp()` / `squashWrapOffsetYVp()` **鐎瑰憡褰冮崹褰掓⒔?*闁?
  //
  // 閻庣懓鍟╁鎴﹀及椤栨稑鐏夊☉鎾筹梗缁旀挳鎮ч崼婊嗙濞存粌妫滈鈧?闁煎啿鏈▍娆愮▕閻旇崵顎€闁活偀鍋撶€?闁兼澘鑻慨鐐烘儍閸曨亞顏遍悘鐐插€借棢闁稿鐏濋鎰板闯?
  // 闁挎稑娼?height(winH 閼?k)` + `.offset({y: 闁愁厽濮秈nH(1闁愁厽濮?/2})` + `.scale({y: k})`闁挎稑顦埀?
  // 闁哄牜鍓濋悿鍡涘箮婵犲啯锟ラ柣锝呯灱濞?*閻忕偛鍊绘?*閻犲洤顭烽埀顒佺煯缁狅綁宕ユ惔顖滅闂侇叏绲奸柌婊呮偘閵夈儰缂?*闁轰胶绻濋柌婊勭▔瀹ュ浠橀悷鏇氭缁?*闁?
  // 闁哄啰濮烽弲顐︽儍?`MeshCoverBg` 閻忓繐宕﹢?*閻?`scale/translate/clip` 闁汇劌瀚伴崑鍛▔?Stack 闂佹彃鐭傚?*
  // 闁挎稑娼墂ujie.pa` 191388 闂侇叏绲奸柌?`PLAYER_ROOT_ID` 閻庡湱鎳撳▍鎺楁晬瀹€鍐炬綄 `build()` 闂佹彃鐭傞崑鍛枔闂堟侗鍟囬柛锝冨妽閻栨煡鏁嶆径娑氱
  // 闁?閻庣懓鍟妵澶愭倿閹壆顎€闁活偀鍋撻悗鍦嚀濞呮帗绋夐埀顒傛導妞嬪海绱氶柕鍡曟缁斿鎸ч悿顖ｆ蕉閻熶椒闄嶉埀顑挎缁″啯寰勯埡鍐ㄥЁ闁革负鍔忛惌楣冩偨閸楃儑绱﹂梺顓ㄧ稻濞?`morphSquashY` 闁汇劌瀚紞鏃堟偨閵娿儳鍘甸梺鎻掕閳?
  // 闁?闁煎啿鏈▍娆忣啅閸欏鐦婚柡鍐Х閺咁偊骞栭鈧ú鏍偓鍦嚀濞呮帡宕橀崨鏉戝姤闁挎稑鐭佺换鏍ㄧ▔閳ь剛浠﹂崒婢﹀宕戦懗顖滅闁告艾鑻悾鐘绘儍閸曨偆鍩楅梺鎻掔箣缁斿鎸у畡鏉跨仼闁瑰搫顦埀?

  // 闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?闁硅矇鍐ㄧ厬闁告牠缂氶崵婊堝礉閵婏附鏆悹?闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?

  // 闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩?闁宠棄鎳夊Σ鍕煡?闁绘粍婢樺┃鈧柤濂変海閻﹀顕ラ懞銉у灱闁?*濞戞挸绉崇欢椋庢導?hdc**闁挎稑顦弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳
  //
  // ## 濞戞捁妗ㄧ划鍫熺▕閸繂顫ｉ悗?
  //
  // 闁靛棗鐬奸崑锝夊礄缂佹ê鈪电€殿喒鍋?/ 闁绘劗鎳撻崵顕€宕楅幎鑺ワ紨 / 缂侇垵宕电划鐑樻交閺傛寧绀€婵炲备鍓濆﹢浣轰焊娓氣偓濞间即宕濋妸褎鏆伴柕鍡楃Х缁绘牠寮堕敓鐘筹紪濡増锕槐婵嬪嫉椤掑啰鏋傜€规瓕灏欑划锟犲绩闁稓鍟?3 濠?
  // 闁挎稑鐓?2 闁煎啿鏈▍娆愮▔瀹ュ鍋撹箛鏃€顫栭幖?/ 閹?3 闁圭鍊藉ù鍥礆閵堝棗绁?/ 閹?4 缂備礁鐗忛崑锝夋煥濮樺崬浠梺鎻掔箲缁佹挳姊婚…鎺旂闁挎稑濂旂徊?*闁活潿鍔嶉崺娑欑▔瀹ュ牆鍘撮柣?hdc**闁?
  // 闁瑰瓨鍨剁€ｄ焦绋夊鍛厒 `RzdCoverLocal` / `RzdMorphOwnership` 闂侇叏绲肩花娲籍閵夈儳绠?闁?闁告瑯浜ｉ崗姗€妫?闁衡偓闁稓鍟婇柛鎰Х椤斺偓闁活潿鍔嶉崺娑氭啑?闁?
  // 闁兼澘鐭佺换鏍级閿熺姵鎳犲☉鎾筹攻濠€?5~6 濞戞搩浜滈崹浠嬪棘椤撱劎绀?*闁烩晛寮堕弫濂告儍閸曨亜鏁╁ù鐘插槻閸戯紕绱掕箛姘兼蕉閻犲洣鐒﹀Σ鎴﹀几娴ｆ悶浜?*闁挎稑鐓?6~閹?4 闁?8 閺夌儐鍣槐姘跺Υ?
  //
  // 闁?闁告梻濮崇粩瀛樼▔?*濡炪倗鏁诲鐗堢▔婵犲嫭绾柟鎭掑劜濡绮堥崫鍕伈闁?*闁汇劌瀚惃顒€顕ラ懞銉у灱闁挎稒姘ㄩ弫銈夊箣妞嬪骸浠€殿喒鍋撻柟缁㈠幗閺備線宕抽妸銉﹀€甸柟璺猴工閻棙绋夋繝鍥т簼濞戞挶鍊涢、鎴﹀极閺夎法鎽熼煫鍥涧閸ゎ參寮堕妷顖滅
  //   闁瑰瓨鍨靛銊╂嚄閹存帞顏辨繛鍡忊偓宕囨毎濞达絽绉撮崺宀勫礂閾氬倻绉奸柛婵愪簷缁斿瓨绋夐鍕伈闁哄偆鍘虹拹鐔煎磻閸ャ儮鍋?*閻熶礁鎳嶇粩鏉戔枎閿熺姰鈧﹪宕℃担璇″仹闁烩晛寮堕弫濂稿Υ?*
  //
  // ## 闁活潿鍔嶇涵鍫曟晬閸垺鏆忛柟纾嬫腹閺呭爼鏁?
  // ```
  //   鐠?閺夆晝鍋熼崑锝夊箻椤撶喐鏉瑰銈囨暬閵嗗﹪鏌?3 婵炲棌妲勭槐娆撴倷?閺夆晜鏌ㄥú?鐎垫壋鍋撻柛娆忓帠缁旀挳鎮欒ぐ鎺戜簼闁绘娲ㄩ埞鏍儌閺傘倗绀夐柟瀛樼墱閸嬶絽顫㈢仦鑺ュ€?婵繂鏈晶婊堟焽閿濆嫮顏遍悶娑樼焿缁?
  //   鐠?閻忕偛绻嬬粭鍌炲礄閾忕懓绠涘☉鎾亾閻忓繐绻愬鈩冾渶閹存繄淇洪柣褑妫勯悺褔鏁嶇仦鍊熷煂濠碘€冲亰缁?
  //       V 8f3a2c1 sess=1 usable=1 cont=1 clip=1 scale=0.082 p=0.000
  //       real=0 clone=1 snap=330/56 end=328/328 op=0.040 stage=1 drv=2
  //   鐠?闁硅泛锕ㄧ换鏍ㄧ▔閵堝牜鏀介煫鍥╂暩缁即骞嬮幋顖滅闁瑰瓨鐗楅崺鍛村炊閹惧懐绀嗛柛妤€鍟胯ぐ鏌ユ晬濞戞ê鏅欓柣?3 婵炲棌鈧啿璁查柛蹇氭珪鐢偓
  // ```
  // 闁宠法濯寸粭?**閻庣懓鍟ぐ褔宕烽妸銊х闁?3 婵炲棌鈧尙顓洪柛姘婢х娀宕欓搹鐟扮疀** 闁?婵繐绲介悥鍫曞箚閸涱厼鏋屽☉鎾愁儑閺併倝骞嬪畡鎵殮闁稿繈鍔庡﹢鍛▔瀹ュ懎鐓傞柨娑樺缁楀銇愰崡鐐存儥閻熸瑥鍊归崝鍛村Υ?
  // 闁宠法濯寸粭?缂佺虎鍨拌ぐ褏鎷犳导娆戠獥濞戞挸绉撮崯鎾寸鐠佸磭绉垮☉鎾抽婵晠鎮界紒妯荤畳闁稿繐纾▓鎴︽偐閼哥鍋撴笟濠勭闁告瑯浜滈崯?`diagBadgeOn` / `diagText` 濞戞挶鍊撻柌婊堝嫉椤掑嫨鈧鈧稒顨嗛宀勬晬婢跺牃鍋?
  //
  // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*鐎殿喒鍋撻柛蹇氭珪閺佸ジ骞嬮幇顖涚《閻庡湱鍋樼欢銉ф媼閺夎法绠?* 闁炽儲鏌￠埀?闁烩晛鐡ㄧ敮瀛樼▔鏉炴壆鍟?閻忓繑鍨奸鈧柣顫妽閸╂盯鎯傞崐鐔虹崜濞戞挴鍋撻弶?闁挎稑顧€缁?
  //   鐎垫媽濮ら悥锝囩箔椤掆偓瀹曞嫭绋夋径搴斀閻犲洩宕靛▓鎴﹀及?*闂傚牊鐟﹂埀?*濞存粌顑勫▎銏ゅ籍閵夈儳绠堕柨娑樼墔缁楀倹绋夐埀顒€鈻庨垾鍐插綘闂傚偆鍘惧▓鎴﹀礂閵娿劎绠栫紒瀣儜缁辨岸鏁嶅畝鍐ｅ亾瀹€鍐惧殺閻庣懓鑻悾鐘绘儍閸曨倣顓㈠礉閹稿孩笑
  //   闁靛棗鑻崣褔姊?闁?**闂佹彃绉甸弻濠囧箥閹惧磭纾婚柟缁㈠幗閺備焦銇?* 闁?闁瑰灚鎸哥槐鎴濐嚗閼恒儳鍨?闁?闁规惌浜滃ù姗€濡村鍐ｅ亾閸屾艾璁?`diagBadgeOn` 闁告鍠愬鐢稿及?*閻庡湱鍋樼欢銉т沪閳ь剟鏌?*闁?
  //   闁?婵絽绻戦濂告煂瀹ュ棙鐓€闁瑰灚鎸哥槐鎴︽焾閽樺绀€闁?闁?闁挎稑鐬奸弫銈夊箣瀹勬壆绻?*闁告劕绉风换娑㈡倷?3 婵?*闁归潧绉跺﹢鍛嚗濡も偓閸?闁炽儲鏌￠埀?濠㈣埖鐭粩鏉戭潰閵夈儲鐨戝鑸电煯缁旀潙鈻庨檱椤曠増绋夊鍛厒闁汇劌瀚伴ˉ鎾绘⒔閳瑰簱鍋?
  //   闁?闁告梻濮崇粩瀛樼▔椤忓牊楗柟顑跨窔閺嗗懘宕撹箛銉х獥**鐎殿喒鍋撳☉鎾亾婵炲棌鈧櫕鐨戝☉鎾亾闁烩晛鐡ㄥΣ绋款嚕閳ь剟鎯?*闁挎稑鐗忓ú鍧楀礆閺夊灝鏅欓弶鈺冨仧閸?3 婵炲棌鈧啿褰犻柟鍝勵檧缁辨繈骞嬮弽顒傜缂佸顑夐崳鎼佸触椤栥倗绀嗛柕?
  private static diagBadgeOnStatic: boolean = false;
  @Local private diagBadgeOn: boolean = PlaybackPage.diagBadgeOnStatic;
  @Local private diagText: string = '';
  private diagTapCount: number = 0;
  private diagTapLastMs: number = 0;
  /**
   * 闁?闁煎浜ｉ惁澶屾媼閳╁啯娈堕柨娑樼墕瑜把呯磼濞嗗繒鐛﹂柡宥呮川閺併倝鏁嶇仦鑲╃憹鐟滄澘宕幖閿嬬鐠佸磭绉块梺顐ｆ缁额偊鏁嶆径娑氱獥
   * 鐠?`diagRemeasureTries` 闁炽儲鏌￠埀?`onAppear` 闂佹彃鐭傞崑鍛枎閳ュ啿娈ゅù锝嗘礉钘熼梺鎻掔箺椤妇鎷崘顏呮殢濞存粌妫楅崵鎴濃枎閳藉懐骞?
   * 鐠?`diagOverlayKicks`   闁炽儲鏌￠埀?闁稿繑婀归懙?閻炴稏鍎甸崳娲箣閹邦剙顫犻柛姘叄閵嗗酣骞嶇€ｎ厽宕冲ù婊冩鐠囩偟浠﹂崒婢﹀姊?闁告垹濮甸濂稿Υ?
   * ```
   *   濞戞挶鍊涢埀顒€鎳橀崗?0 闁?闂侇叏绲鹃灞剧閿濆洨鍨抽柡宥堫潐濠€鏉库柦闄囩粣鍥礆鐢喚绀刞onAppear` 閻犙囶暒缁繝宕氶銈嗙暠闁告帒妫欓弫顕€鏁?
   *   1 / 1    闁?閻炴稏鍎甸崳鐑樼▔鎼淬倖宕虫俊顐ｅ浮閸忔﹢宕ｉ幋鐘虫櫢濞?闁?闁兼眹鍎遍惃婵嬫椤厾鐭濆☉鎾崇Ч椤ワ綁鏁嶅畝鍕紪濡増锚濠€顏堝礄閻樿京绉块柛濠勩€嬬槐娆撴儑?snap / end闁?
   *   1 / 0    闁?閻炴稏鍎甸崳铏规崉閹存粎鍟婂ù?`morphUsable` 濞寸姴绉崇拹鐔煎磻?闁?闁?usable / end 濞戞挶鍊曢崹?
   * ```
   */
  private diagRemeasureTries: number = 0;
  private diagOverlayKicks: number = 0;

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*Swiper 闁搞儳鍋犻惃鐔衡偓鍦仜瀵剛鎷嬮弶璺ㄧЭ** 闁炽儲鏌￠埀?濞?婵繂鐭侀惁婵囥亜闂堟稓娈遍梻鍫涘灪閻ュ懘宕ｅΟ铏规瘓"闁?*闁告劕鍟块悾楣冨箑?*閻犲洨绮弳鐔兼晬?
   *
   * 濞戞捁妗ㄧ划鍫熺▕閸繄绠戝銈嗘椤斿洨鈧懓鍠涚槐鐗堢▔婵犱胶顏遍柟浣冾潐閸ㄦ粓宕烽妸銊х闁哄绻濋幗鍏肩▔婵犲嫭鏆?*闂傚牊鐟﹂埀顑跨劍鐢綊鎮?*闁革负鍔嬬悮杈╃矓瀹ュ懍娴烽悹浣稿綖缁狅綁姊荤€涙ɑ鍟氶柟?闁炽儲鏌￠埀?
   * ```
   *   闁稿娲╅?A闁挎稒鐡?onAnimationStart` **闁哄秷顫夊﹢鏉库柦闄囪闁?*闁挎稑鐗嗛崹蹇斻亜閸偆姊鹃悹褏澧楃划锕傚礉閵娿儲绀€閻犲鍠涚槐?
   *   闁稿娲╅?B闁挎稒淇鸿闁告瑦鍨崇花鈩冩媴?*閻炴凹鍋勯悾褔宕￠锝呯殹闁?*闁挎稑娼塱ndex === targetIndex`闁?
   * ```
   * 濞戞挶鍊涢埀顒€鎳愬▓鎴炵┍椤旂晫銆?*閻庣懓鑻崣蹇旂▔瀹ュ懏鍊?*闁挎稑婀?閻熸洑绀佸﹢顏堝箰閸屾繃绁?闁告帒娲妴澶愬籍閹叓澶嬬▔閳ь剙鈻庨垾鎰佸殸濮掔粯鍔х槐鐩?閻熸洑鐒﹂弫鑲┾偓鐟扮墕瀹曞ジ鎯冮崟顐㈢伈闁硅鍣槐姘舵晬?
   * 闁兼澘鑻ぐ褔寮垫径灞惧焸闁哄牓缂氶浼村极閹峰苯鍘撮柛鎺戞妞存悂濡撮崒妤€娅?閻犱線顣︾粭鍛村级閵夘垳绀夊☉鎾亾婵炲棌鈧磭鏆板ù锝呯Р閳?
   *
   * 閻犲洨绮涵鍫曟晬閸繄鐛﹂柡?*缂佹鍓欓崣鎾舵偘?*闁挎稑顧€缁?
   * ```
   *   ast=<index>-<target>   濞?`ast=0-1` = 濞寸姴娴烽?0 濡炪倕鐏氱划锕傚触閹寸媭鍎?1 濡炪倗顣槐娆忣潰閿濆懐鍩楅柛鎺戞搐閸╁苯顫㈠畝鍐Г濡炪倗顣槐?
   *                          `ast=-1--1` = **閺夆晜鐟ら柌婊堝炊閻愬墎娈跺☉鎾亾婵炲棴绻濋崗妯衡柦闄囩换姗€寮堕妷銊х畺**闁挎稑鐗嗘禍锝囨媼?A 闁瑰瓨鍔楅悵娑㈡晬?
   *   skp=<閻庣懓鐗嗗畷濂稿箰閳╁啫绔撮柣銊ュ椤愬ジ寮?   > 0 闁?ast 闁哄牆顦埀?闁?闁稿娲╅?B 闁瑰瓨鍔楅悵娑㈡晬閸繃绀€閻犲鍟崇换妯荤閸℃洜绋婚悶?`index===target` 闁圭硶妲勭槐?
   *   aend=<index>/<婵炲棌鍓濋弳?    `onAnimationEnd` 闁哄牃鍋撻柛姘凹缁旀潙鈻庨敍鍕暠閻庡湱鍋涘顒佺▔鎼淬埄鍋ч柡?
   *   chg=<index>/<婵炲棌鍓濋弳?     `onChange` 闁哄牃鍋撻柛姘凹缁旀潙鈻庨敍鍕暠閻庡湱鍋涘顒佺▔鎼淬埄鍋ч柡浣稿簻缁辨獨wiper 闁煎浜滅换浣烘媼閵堝嫯绀嬮柛瀣矊濠€顏堝传椤忓啰顏卞銈囶暜缁?
   * ```
   */
  private diagAnimStart: string = '-1--1';
  private diagAnimSkip: number = 0;
  private diagAnimEnd: string = '-';
  private diagAnimEndCount: number = 0;
  private diagChg: string = '-';
  private diagChgCount: number = 0;
  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稒鐡猳nContentDidScroll` 闁?*閻犲鍟伴弫銈囨媼閳╁啯娈跺☉鎾冲濞撳爼宕ユ惔婵堫伇婵炲棌鈧磭鏉介柛?* 闁炽儲鏌￠埀?閺夆晜鐟﹀Σ鎼佸嫉椤掑啰鏋傞柣顏嗗枑椤掓粓鎯冮崟顐㈢伈闁硅鍠撻埀?
   *
   * 閻犲洨绮涵鍫曟晬閸繄鐛﹂柡?*缂佹鍓欓崣鎾舵偘?*闁?`scr=`闁挎稑顧€缁?
   * ```
   *   scr=<婵炲棌鍓濋弳? last=<index>/<position>
   *     scr=0        闁?閺夆晜鐟ら柌婊堝炊閻愬墎娈?*濞戞挴鍋撴繛鍡節閸忔ê鈻介檱琚濋柛?*闁挎稑鐗撻崑?SDK 濞撴皜鍐╃殤婵炲备鍓濆﹢浣规交濞戞ê顔婃繝褎鍔曡ぐ鏌ユ偨椤帞绀夐悷鏇氱劍瀹曟煡寮憴鍕垫敵闁?
   *     last=0/0.37  闁?婵繐绲藉﹢顏呯鎼达紕娈遍梻鍫涘灲閵嗗顭ㄩ幋婵囧€绘慨婵嗙焷閻︽繃銇勭喊澶岀`position` 闁哄嫷鍨充簺闁告柣鍔嶉惁顔界瑹鐎ｅ墎绀?
   *     last=0/1.000 闁?闁?**闁稿绮屽﹢顏勵潰瀹€鍐Г濡?*闁挎稑鐗婂Λ銈夋偩瀹€鈧▓鎴ｃ亹閹哄秶顏遍柛鏍ㄧ墬婵″摜鈧懓鍟妵娆撳礆?1闁挎稑濂旂粭鏍ь潰閵堝懏鍊靛☉鎾崇Т閸熲偓闁哄洤鐡ㄩ弻濠囨晬?
   * ```
   * 闁哄啰濮烽弲顐︽儍閸曨厾鎼煎ù鐘活棑婢ц法浜告潏銊π?`swiperProgress`闁挎稒绋戦悾鐘诲及?goal 缂?1 闁哄鍓濈€垫氨鈧姘ㄥ▓?*閺夆晜绋戠€瑰啿鈹?*闁?
   */
  private diagScrollCount: number = 0;
  private diagScrollLast: string = '-';
  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稒鑹鹃崬瀵糕偓鍦嚀閻?`.onAppear()` **閻犙囶暒缁繝宕鍛拫闁告帒妫欓弫?* 闁炽儲鏌￠埀?閻庤鐭紞?闁稿繑濞婂Λ鎾触鎼达絿宕愰柣鎺曟硾瀵敻寮ㄩ幆褏娼旂€殿喒鍋?闁?
   *
   * 闁告瑦鐗曢埀顒傘€嬬槐?
   * ```
   *   '-'        = 閺夆晜鐟ら柌婊堝炊閻愬墎娈堕弶鈺偵戦惀鍛交濞戞粎绠?
   *   'morph'    = 閻犙囶暒缁ゃ亹閵忕姴缍侀柛鎺戞閺侇噣鏁嶉崸顣時phContainerActive || morphSessionStarted闁挎稑顦〒?婵繐绲介悥?
   *   'intro'    = 閻犙囶暒缁繝宕楀鍐亢闁告帒妫欓弫顕€鐛幆鐗堝闯濞?playExpandIntro()  闁?闁?闁兼眹鍎遍崵顓㈡偝閺夋寧韬柛蹇斿▕濡瓨娼婚崶鈹炬煠濞戞搩鍙忕槐婵堜焊鏉堛劍笑闁?bug
   *   'skipClose'= 閻犙囶暒缁繝宕楀鍐亢闁告帒妫欓弫顔芥媴閸℃凹娼?婵繐绲藉﹢顏堝礂閹惰姤锛?闂侇叏缍佹禍楣冩⒒閵婏箑顏″☉?闁翠礁鎷戠槐娆撳嫉椤掑啰鏋傞柡鍌涙緲椤ゅ啴鎯冮崟顖涳紝闁?
   * ```
   * 闁告帇鍊涢浼存晬濮橆剙褰犻梻鍌ゅ幖閹鎳熼妷褎绠欓柛?`intro` 闁?闂傚倶鍔嶉惀鍛村箯閿旇法绉堕柨娑樼墣椤╋箓宕樺鍡欏弨闁告帇鍊栧畵渚€鏁嶆径娑氬耿闁活亜顑呴崺?`skipClose` 闁?闂傚倶鍔庨弫鎾诲极閸粎鍟婇柕?
   */
  private diagAppearBranch: string = '-';
  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁煎啿鏈▍娆戜沪閸屾繂娈扮€规瓕浜▓鎴犫偓鍦仦缁佹挳鎯岄埡浣藉煂**闁挎稑鐗忛悰銉╁矗閿濆懏缍忛柡宥呮祫缁辨脊p闁挎稑顦埀顒佹煛閳?閻庤鐭紞?闁哄牆顦抽崕妤呭疾椤栨瑧绋诲Δ鍌浢€规娊鎮ч柅娑氱У"闁?
   *
   * 濞戞捁妗ㄧ划鍫熺▕閸繂绀嬮柣娆樺墴閸ｈ櫣鈧懓鍠涚槐浼存嚄鐏炵偓鐝悘鐐插亰缁辨獋MeshCoverBg` 闂侇叏绲奸柌婊呪偓鐟般仒鐎?`Column`闁挎稑顦板Σ?*鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞呮帡鎯冮崟顐ゆ憤闁煎搫鍊婚崑?*闁?
   * 闁兼澘濂旂粭鏍及?`.height('100%')` + `.position({x:0,y:0})` 闁?閻庣懓鍟板▓鎴烆殗濡搫顔?*閻庣懓鑻崣蹇涙偨閸楃儐鍟囬柛锝冨妼閸犲懐鈧?*闁?
   * 闁活潿鍔嶉崺娑㈠箮閵夛絺鍋撶仦鐐畳闁煎啿鏈▍娆愭媴閸℃ɑ笑**濡ゅ倹锚鐎规娊鎮ч柅娑氱У**闁靛棗绉靛鍌炴晬鐏炶偐鐟忕紒澶婄Т瑜版煡鎳楅挊澶岀畱濡炪倛顕ч崹搴㈡綇椤帞绐?
   * ```
   *   闁?閻庡湱鎳撳▍鎺楁儍閸曨噮姊块柛鎿冧簽閻涖儵宕ｉ敐鍡樻嫳闁哄鍎卞銊╁及椤栫偛浜濆☉鏂跨墕閻剟鏁嶉崸鍒ipH` 閻犲洨绮弳鐔兼晬婢跺棗娅?婵繐绲介悥鍫曟晬鐏炵偓笑闁告柣鍔庨弫鐐▔椤撶噥鍞?
   *   闁?闁煎啿鏈▍娆戜沪閸屾粍鐣遍柣鈺傚笒閻℃瑧鎮銏犵闁瑰瓨鍔掔花锟犲几娴ｅ摜姣堥柨娑樼墛濠€鎵嫚缂佹ɑ娈?`bgH`闁? 闁?閻㈩垰鍟惇顒勬⒒椤曗偓椤ｄ粙鏁嶉崼銏☆仴闁告帒妫欓惁顕€鏌ч悙顒佺劷濞存粌妫寸槐?
   *   闁?闁煎啿鏈▍娆戜沪閸屾粍纾悗娑欏姈椤掓粎鏁梹鎰ɑ閻?*婵烇絺鍓濈敮鈧?*濞存粌妫寸槐妾俠g` 濞戞挸绉归埀顒€绻戝Σ鎴炴償閿旇偐绀嗛柍?闁?`backgroundRevealOpacity()` 闁汇劌瀚花?
   * ```
   * 闁?`MeshCoverBg` 闁圭鍋撻柛锔哄妼椤旀牗绋?`Column` 闁?`.onAreaChange()` 闁告劖鐟辩槐娆撳矗椤忓浂鍤㈤柨娑樻湰濡倝宕滈娆戠▕闁汇埄鐓夌槐姘跺Υ?
   * 闁宠法濯寸粭?`onAreaChange` 缂備焦鐟у▓鎴﹀及?*閻㈩垰鍟惇顒勫礄閻樿京绉?*闁挎稑鐗呯粭澶愬触椤愩値娈柛?transform闁挎稑顦崳?闂佹澘绉撮幃搴☆嚗閼恒儳鍨肩紒妤婂厸缁斿鎮板畝鈧▓?
   *    `scale` 闁归潧绉烽崗妯绘交濡搫鏂?閻忕偛绻嬬粭鍌涘緞濮樺墎褰?闁? `bgH 閼?scale`闁挎稑顦埀?
   */
  @Local private diagBgBox: string = '-';
  /**
   * 濞戞挸锕ｇ粩鏉戔枎?`onContentDidScroll` 闁汇劌瀚鍌炴⒒鐎涙ê鐓堥柨娑樻桨s闁挎稑顦埀顒佹煛閳?**闁活潿鍔嶅鐢垫媼?闁解偓閽樺鏆?閻犱讲鏅欑紞鍛磼?闂侇偅鍔曢幎姘交濞戞ê顔?**闁?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗愮换鏍及椤栨稒鎷遍弶鐑嗗枛缁烩偓濡炪倛顕чˇ鈺呮偠閸℃瑦鐣卞☉鎾亾濠?*闁活亞鍠庨悿鍕礃閼碱剛宕?*闁挎稑顧€缁?
   * `onContentDidScroll` 闂侇偅鍔曢幎姘跺礃?`lyricMorphT = p`闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?
   * 闁?`syncLyricMorphToPage()` 闁?闁?`t` 闁解偓閽樺鏆伴柛鎺撴緲缂嶅宕滃澶堚偓澶屸偓鐢垫嚀缁ㄦ煡鎯冮崟顓т紓闁?闁挎稑鐗呯粩鎾箮婵犲拋鍟庨柛鎺楊暒缂嶅懘鏁嶆径鍫氬亾?
   * 濞戞挶鍊涢埀顒€鎳撶€氥垽宕ョ仦鐐槯闁汇垻鍠愰弲銉т焊閸欐绐?*婵絽绻愰幎姘閹烘梹绁查柟韬插灩閳?*闁挎稑鐗婄划锕傚礆妫颁胶顏遍柛妤€锕ㄩ～锕傛媰閽樺鏆伴柛?1 闁?闁汇垹顭峰鎵崉缁涘湱绀嗛柕?
   * 闁?闁告帇鍊栧畵渚€鏁?*闁哄牃鍋撻弶?120ms 闁告劕鎳忓﹢浣割煥濮橆剙袟闁搞儳鍋犻惃?闁?閺夆晜鐟ょ粩鏉戔枔閻㈠灚鏆?閺夆晜绋戠€?鐟滅増鎸搁宥夋晬鐏炶偐鐟濋悹浣圭摃閹倗鈧?*闁?
   *   闁?20ms 闁?7 閻㈩垎宥囧耿闁归潧顑嗙€垫岸骞庨鍐╁闯闁?swiper 闁汇劌瀚崕濠氬箑瑜庣划鎾礉閵娿倗顏遍柛瀣玻缁辨繈鎷冮挊澶屾毎閻忓繗绮鹃崗姗€骞掗妷褜鍚€闁衡偓鐠鸿櫣鍟查柕鍡楀亰缁?
   *   闁宠法濯寸粭?閺夆晜鐟ら柌婊堝籍閸洘锛熺紒?*闁告瑯浜滃﹢?濞戞挶鍊楅～鎺撱仚閸楃偛袟闁哄倻鎳撶槐锟犵嵁鐠鸿櫣鎽?闁哄啳鍩栨晶鐘诲嫉婢跺澹堝☉?*闁挎稑鑻悾鐘崇▔瀹ュ棙笑闁告柣鍔庨弫楣冨籍閸洘姣愰柕鍡曟缁″啯绋夊鍡樞﹂柤濂変簽缁鳖亪宕ｉ崒娑欐 闁炽儲鏌￠埀?
   *      閻庣懓鍟Σ?闁告帇鍊曢悾鎯ь煥濮橆剙袟闁哄嫷鍨伴幆浣圭瀹ュ懏韬弶鈺傜椤?闁汇劌瀚伴崳浼村冀妞嬪海宕堕柨娑樼墔缁?`PULL_ANCHOR_RETRY_MS = 32` 闁告艾濂旂粩鎾箑瑜戝婵嬫晬婢跺牃鍋?
   */
  private lastScrollAtMs: number = 0;

  /**
   * 濡炪倕鐖奸崕鎾焽閿濆懏鍋?闂傚懏鍔曢懜浼存倻椤撶偛闅?闁汇劌瀚崑锝夊礄閺勫浚鍚€闁轰礁搴滅槐?*閺夆晝鍋熼崑?3 婵?*鐎殿喒鍋撻柛蹇撶枃閸ゆ粎鎷犳担鍝ョ崷闁哄秴娲㈤埀?
   *
   * 闁?800ms 闁汇劌瀚悰銉╁矗閿濆懎鐏查悗?閺夆晝鍋熼崑?闁挎稒鐩Λ鍧楁⒕閺冨洨孝閺夆晛娲ゅ銊╂煂瀹ュ棙鐓€閻犱讲鍓濋弳鐔煎Υ?
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
      // 闁?2026-10-17闁挎稒淇哄▔鏇犫偓鍦仒缁躲儳鎷嬮弶璺ㄧ畵闁挎稑鐗愰～?`diagBadgeOnStatic` 闂侇叏绲鹃宀勬晬婢跺牃鍋?*闊洤鎳橀妴蹇涘箣閹邦剦鍤犻柛?*闁?
      //   闁告瑯浜ｉ鐗堢▔瀹ュ懎鏅?= 鐎殿喒鍋撻柛蹇氭珪濡楀牊娼诲鍐╃闁?false闁挎稑鐗撻崑鍛潰閿濆棙笑"闁活潿鍔嶉崺娑㈡儌閸婄喓鐛撳☉鎾亾閺?闁汇劌瀚懜浼存偐鐠佸湱绀嗛柕?
      PlaybackPage.diagBadgeOnStatic = this.diagBadgeOn;
    }
  }

  /**
   * 闁硅泛锕ょ紞瀣礈瀹ュ浜濆☉鎾亾濞戞挻褰冮崹浠嬪箲椤旇棄顏婚柟瀛樺姃鐞氳京鎮扮仦鐣屾憻缂佹缂氱憰鍡涙晬?*闁告瑯浜滃﹢顏勵嚗閼恒儳鍨肩€殿喒鍋撻柣顐熷亾闁哄啯鍎奸惃鐔兼偨?*闁挎稑顦埀?
   *
   * 婵絽绻嬬粩瀛樸亜瑜版帒鍘撮悗鐢垫嚀缁ㄦ煡寮甸鍐瀭闁衡偓绾懐绠栭柟瀛樼墬閳ь兘鍋撻柣銈嗗灱缁诲啴鎯冮崟顏嗩伇濞戞搩浜滈崹浠嬪棘椤撱劎绀夐柛娑滄閹洘绋夋惔婵嗘暕闁活喕绀侀悺褍鈻撻崗鍝ヮ伇濞戞挴鍋撻悗鐢垫嚀缁ㄦ煡鏁?
   * ```
   *   sess   = morphSessionStarted        闁挎稑鐓?3闁挎稒鑹鹃敍鎾朵沪閸屾艾鍤掗悹褑娓圭槐鎵嫚濠垫挾绀?
   *   usable = morphUsable                闁挎稑鐗嗛崵鎴炴媴閺囩喐笑闁告熬绠撻崳鐑橆瀲閹板墎绀?
   *   cont   = morphContainerActive()     闁挎稑鐗嗛鎰板闯閵婏附笑闁告熬绠戝﹢顏囥亹閵忕姴缍侀柛鈺冨櫐缁?
   *   clip   = morphClipping()            闁挎稑鐗愰ˉ鍡涘礈椤忓懏笑闁告熬濡囬弫鎾诲极閸剛绀?
   *   scale  = morphScale                 闁? = 闁诡厽甯為悺鎴︽晬?.08 = 鐎瑰憡褰冪敮鍥礆閹峰本宕抽柣鎰缁?
   *   p      = morphP                     闁挎稑鐗嗛懜浼村矗濡法绠婚幖杈捐缁?
   *   real   = realCoverVisible()         闁挎稑鐗婇幐閬嶅绩妤ｅ啨鈧鎯囬悢椋庢闂傚牄鍨哄Σ鎼佸触閿旂偓鏆伴柨?
   *   clone  = morphOverlayBridging()     闁挎稑鐗嗛敍鎾朵沪閸屾粎鏁惧瀣仜閻ㄦ繈妫冮姀鈩冃﹂柛姘惧閺侀箖鏁?
   *   snap   = snapStartW / miniSize      闁挎稑鐗愰幑锝夋倷閻у摜绐楃紓渚囧弮椤ワ絿浜告笟鈧鎵偓纭呮鐎?/ 閺夆晞娓圭紞姗€寮堕垾宕囨闂傚牜婢佺槐?
   *   end    = endCoverSize / endCoverH   闁挎稑鐗忕划鎾绘倷閻у摜绐楅柟缁㈠幗閺備焦銇勯棃娑氭闂傚牜婢佺槐?
   *   op     = backgroundRevealOpacity()  闁挎稑鐗愰崕妤呭疾椤栨瑧鐟濋梺顐㈢箲濡叉垶鎯旈敂鑲╃
   *   stage / drv = morphStage / morphDrive
   * ```
   * 闁宠法濯寸粭?闁告帇鍊涢鎵啺娴ｅ搫浠柨娑樼墕閸熸捇宕烽妸銊х闂佹彃鐭夌槐婵嬫偨閵婏箑鐓曢煫鍥х仛閺嗙喓鈧稒顨嗗鍌炲箣閹达絽娈扮€圭宕顕€宕ｉ崙銈囩闁?
   * 鐠?`clone=1` 濞?`real=0` 闁?閻忓繋绶氬鎵嫚閵壯勬殸濠㈢懓鍟块惇鏉棵归鑲╂勾闁活澀绱槐閬嶆嚐閵夈儳娼屽☉鎾筹攻閻ュ懘寮?闁?闁?`snap/end` 闁哄嫷鍨伴幆渚€妫冮悙鐑樼ォ闁?
   * 鐠?`clone=0` 濞?`real=1` 闁?閻忓繋绶氬鎵嫚閵壯勬殸闁圭虎鍘介弬浣广亜閻㈠灚鏆伴柨娑樼墦閸嬪懘寮捄铏规殜闁革负鍔岄鎰板闯閵娾晛娅￠柨娑樺缁辨壆鎮銈囩礆闁衡偓閹惧懐绀嗛柨?
   * 鐠?`clone=0` 濞?`real=0` 闁?**濞戞挶鍊涚粩鐔兼焾閹存帞鐟濋柣?*闁挎稑鐗嗗銊╁及?閻庣懓鑻崣蹇撯柦閳╁啯绠掗悘蹇庣窔濞?闁汇劌瀚伴崑鍛▔椤忓嫯鍩岄柣妯款啇缁辨岸鏁?
   * 鐠?`op=0.04` 濞?`p闁?` 闁?闁煎啿鏈▍娆撳礆濮樿櫕宕虫慨婵勫劵缁辩浗op=1` 闁?鐎圭寮跺褔濡?
   */
  private refreshDiagText(): void {
    if (!this.diagBadgeOn) {
      return;
    }
    const e = this.expandState;
    // 闁?2026-10-16闁挎稑鐗忔晶妤呭嫉椤掍胶鍨奸悹?`b41d7e9` 闁?`c52e0a7` 闁?`d73f1b8`闁挎稑顧€缁变即鏌囬敐鍕伇閺夌儐鍠栨慨鐐烘儍閸曨剚笑
    //   goal 缂?2 闁哄绱曞▓鎴﹀捶閸℃凹娼￠柤濂変海閻﹀鎷呭蹇曠缂佹鍓欏ú鎾舵偘?`rad`/`radVis`/`edge`/`t`闁挎稑顦粭?
    //   "闁告鐡曞ù鍥绩閻愵剚缍€闁告帇鍊栧畵?闁汇劌瀚悾鍓х矙閸栵紕绀刞morphSessionOughtToLive`闁挎稑顦埀?
    //   **闁活潿鍔嶉崺娑㈠箮?婵炲备鈧啿袟闁?闁哄啳娉涢崢娑㈡儑鐎ｎ剦鍎戝☉鎾亾閻炴稑鐬煎▓?`sess` / `geom` 濞戞挶鍊撶紞?*闁?
    //     `sess=0` 闁?濞村吋淇洪惁鐣屾偖椤愶絿顏搁柟鍝勵槷缁繝鏁嶉崸鍒焍outToDisappear` 闂侇叏绲惧顖滄崉椤栨稓姊鹃悶姘煎亝鐎氥倖鎷呰箛銉х闁?
    //     `geom=0` 闁?缂備礁鐗忛崑锝夊礄閻樿京绉垮┑顔碱儑缁挸鈻介敓鐘叉闁?闁?閻庡湱鎳撳▍鎺楀箒閹烘梻鎼?闁?婵繐绲惧Σ?婵炲备鍓濆﹢浣轰焊娓氣偓濞?闁煎啿鏈▍娆撳礉閵娧勬毎"闁?
    // 闁?2026-10-17闁挎稑鐗忔晶妤呭嫉椤掍胶鍨奸悹?闁?**`af66eb1`**闁挎稑顧€缁变即鏌囬敐鍕伇閺夌儐鍠栨慨鐐烘儍閸曨剚笑**缂佹鍓欏畷鍕偘鐏炵晫鍟查梺顔哄妿濞?`pd=`**
    //   闁挎稑鐗愮粣锟犲箥鐎ｂ晝鐟忓☉鎿冧簼鐎氬棛绱掑┑鍫濅化闁汇劌瀚悿顔炬媼闄囬鎼佸极鐢喚绀嗛柕鍡楀€甸崳?**闁活潿鍔嶉崺娑㈠箮?濞戞挸绉风粣锟犲箥?闁哄啳娉涢崢娑㈡儑?`pd`**闁?
    //     `pd=0/0/0` 闁?闁告帇鍊栧畵渚€宕楅妸褉鏌ら柡鈧幑鎰垫斀闁挎稑鐭傚Λ鑸碉紣濡儤韬ù婊冾儎濞?闁归潧顑呮繛?闁绘鐗嗙槐锟犳晬濞戞宕插☉鎾亾闂?0 闁?闁哄嫷鍨伴崹浠嬪箲椤旇棄鐝曢柣銊ュ閳?
    const line1: string = `V af66eb1 sess=${e.morphSessionStarted ? 1 : 0} ` +
      `usable=${e.morphUsable ? 1 : 0} geom=${e.morphGeomReadyNow() ? 1 : 0} ` +
      `cont=${e.morphContainerActive() ? 1 : 0} ` +
      `clip=${e.morphClipping() ? 1 : 0} scale=${e.morphScale.toFixed(3)} p=${e.morphP.toFixed(3)}`;
    const line2: string = `real=${e.realCoverVisible() ? 1 : 0} ` +
      `clone=${e.morphOverlayBridging() ? 1 : 0} ` +
      `snap=${e.snapStartWVp().toFixed(0)}/${e.miniSize.toFixed(0)} ` +
      `end=${e.endCoverSizeVp().toFixed(0)}/${e.endCoverHVp().toFixed(0)} ` +
      `op=${this.backgroundRevealOpacity().toFixed(3)} stage=${e.morphStage} drv=${e.morphDrive}`;
    // 闁?缂佹鍏涚粭浣烘偘瀹€瀣獥闁硅矇鍐ㄧ厬闁告牗妞介。鈺冪不濡ゅ绀?*濞戞挸绉堕弫?hdc 濞戞梻鍠曢崗姗€寮介崨濠冿骏闁伙絽鐭傞崑鍛附濡や焦娈堕柛?*闁挎稑顦埀顒佹煛閳?
    //   `usableH` 閹煎瓨姊圭€垫粓寮悩鍨珪 `winH 闁?padTop 闁?max(avoidBottom, bottomGap)` 缂佺姵顨愮槐?
    //   `padBot` 閻犲洩顕ч崺宀勬儍閸曨偀鍋撻悡搴ｅ畨濞?`gap` 闁告帗顨愮槐姗LL 65闁挎稑顦粩鎾嚊鏉堝墽绀勯梻鍕╁€濆顏嗏偓鍦仦缁佹挳鏌嗛懗顖ｅ敤闁告牜鍎ら惁顔锯偓鐟板暢缁绘洘寰勮缁辨岸濡?
    const line3: string = `usableH=${e.usableHVp().toFixed(1)} padBot=${e.padBottomVp().toFixed(1)} ` +
      `avoid=${e.navigationBarBottomVp.toFixed(1)} gap=${e.chromeBottomGapVp().toFixed(0)} ` +
      `gapScrub=${e.chromeGapScrubVp().toFixed(0)} tier=${e.chromeTier}`;
    // 闁?缂佹鍓欏ú鎾舵偘瀹€瀣獥**闁哄牜鍓濋悿鍡涙儍閸曨亣鈷堝☉鎿冧簻婵晜鎷呭鍡╁悁闁?*闁挎稑鐗嗛崹?濞寸媴绲块悥婊堝嫉婢跺姊鹃柡鍫濐槼缁愬洭宕?婵絾鏌ㄩ崹浠嬪磹閸忓吋绾梻鍫㈠Т婢х娀鏁嶅畝鍐炬綄閻庢稒顨嗛灞解枖閵娾晛娅為柨娑橆槶閳?
    //   闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑娼沷al 缂?2 闁哄鎵冲亾瀹€鍕┾偓澶愭閵忕姵濡囬悷娆愬笒閸熲偓闁哄秹鏅茬粩鎾焼瀹ュ啠鍋撳鍥ㄧ暠**闁煎浜ｉ惁澶嬫媴?* 闁炽儲鏌￠埀?**鐎规瓕灏鐟邦潰閿濆牏绠栧☉鎾亾婵?*闁?
    //
    //   闁宠法濯寸粭?闁瑰瓨鍨归鍥ㄧ▔閳ь剟鎮ч崼鐔肺?`rad`/`radVis` 闂佹彃绻戦崹姘?`morphRadius` 闁炽儲鏌￠埀?**闂侇叏绲惧Σ?閻庡湱鎳撳▍鎺楁嚊椤忓嫮绠?闁汇劌瀚〒鍓ф喆?*闁?
    //      濞戞挸绉靛Σ鍝ヤ焊娓氣偓濞间即鎯冮崟顐ｅ閻熸瑦甯槐婵囩▔閵堝牃鍋撻崨顔叫?*濞戞挶鍊栧顖炴偑椤掑倻褰岄柣銊ュ閹?*闁挎稑鐗嗛崺鍡椙庨崙銈囩闁?
    //   ```
    //     閻庡湱鎳撳▍鎺楀捶閸℃凹娼?morphRadius = initRadiusVisual 閼?(1 闁?t) / scale
    //        鐠?閻犙囶棑閸?= 閺夆晞娓圭紞姗€寮堕檱閸忓矂宕舵繝鍌涘閻熸瑦甯炲▓鎴炵▔閳ь剟宕℃繝蹇曠缂備礁鐗忛崑?= **0**闁挎稑鐗撻幗闈涱煥閳ュ磭娼?闁?閻庡湱鎳撳▍鎺撶▔瀹ュ牜鍤夐柡鍫濐槸濞撳墽鎲撮幒鐐电
    //        鐠?闁哄啰濮烽弲顐﹀触鐏炵虎鍎ラ柨娑欑摣pplyPullProgress 闁?radius 闁告帒妫欓弫顕€鏁?1054-51086闁?
    //        闁?闁圭鍋撳ù?t=0 闁哄啳娉涢悾鐘诲箰婢跺寒鍟庨悹浣测偓铏殤闁?0 闁炽儲鏌￠埀?闁瑰瓨鍨归鍥ㄧ▔閳ь剟鎮ч崼鐔风憦閻庣懓鍟紞?閻忓繋绶氬浼村捶閸℃凹娼?闁挎稑鐭侀浼村极閹峰苯娈伴柣鎺曟硾閸欏繘寮?0闁?
    //
    //     閻忓繋绶氬浼村捶閸℃凹娼?coverLocalRect().radius = lyricMorph(t).radius
    //        鐠?闁哄啰濮烽弲?`radiusAt(t) = visualRadiusAt(t) / scaleAt(t)`
    //          闁稿繑婀归懙?`visualRadiusAt(t) = lerp(radiusPlayer, radiusLyricVisual, t)`
    //          `radiusPlayer = 8`闁挎稑婢媢jie.pa:85761 ldai 0x8闁?
    //          `radiusLyricVisual = 12`闁挎稑鐗嗛幃鎾诲籍韫囨挾鍩楅梺鎻掗獜缁?
    //        鐠?闁哄牜鍏涚划?`lyricMorph()` 闂佹彃鑻銊╁及?`lerp(COVER_RADIUS_PLAYER_VP(8), COVER_RADIUS_LYRIC_VISUAL_VP(12), p)`
    //        闁?濞戞挶鍊楅?*闂侇偅鍔曢悺褎绋夐埀顒勬嚊?*闁挎稒顒?0 闁?8闁挎稒纭?1 闁?12
    //   ```
    //   闁?閺夆晜鐟ょ粩瀵告偘瀹€鈧獮鍥捶閵娾晛娅ら柣銊ュ濡?*閻忓繋绶氬浼存焽閿濆棙钂嬮梺?*闁挎稑娼塩Rad` / `cRadV`闁挎稑鐣?= cover闁挎稑顧€缁?
    //     妤犵偞婀圭换姘舵偩濞嗗浚鍟囬柛锝冨姂閸嬪懘寮堕埥鍛`rad`/`radVis`闁挎稑顦禍鎺撶瑹閸噮鍤犻柣?闁炽儲鏌￠埀?濞戞挶鍊栧顖炴焾閼恒儱鈪甸柛鎴犲劋濞肩敻鏁嶇仦鑲╊伇闁活亣澹堥崗姗€宕氶崱姘跺摵闁?
    //   闁告帇鍊涢浼存晬濮濇=0` 闁?**cRad = cRadV = 8.00**闁挎稒鐭杢=1` 闁?**12.00**闁?
    //         鐟滆埇鍨硅ぐ澶嬬▔?`cRadV = cRad 閼?morphScale` 閹煎瓨鏌ㄩ～鎰磼閸繃韬?**8~12 濞戞柨顑夊Λ?*闁挎稑鐗呯粭澶愭⒕?scale 闁硅埖鐗曟慨鈺呮晬婢跺牃鍋?
    //   濠㈣泛绉甸悧鎶藉礂閵夈儱缍撻柨娑欎亢缁绘盯鎮欑憴鍕啊闁衡偓妤ｅ啨鈧顔忛敂璺ㄧ憪閻?3 婵炲枴鎵冲亾?
    const coverRect: LyricMorphRect = this.coverLocalRect();
    const line4: string = `remeasure=${this.diagRemeasureTries} overlayKick=${this.diagOverlayKicks} ` +
      `seek=${e.chromeSeekSize().toFixed(0)} edge=${coverRect.size.toFixed(0)} t=${this.lyricMorphT.toFixed(2)} ` +
      `cRad=${coverRect.radius.toFixed(2)} cRadV=${(coverRect.radius * e.morphScale).toFixed(2)} ` +
      `rad=${e.morphRadius.toFixed(2)} radVis=${(e.morphRadius * e.morphScale).toFixed(2)}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*goal 缂?1 闁哄鎵冲亾鐏炶棄甯楀ǎ鍥ｅ墲娴煎懐鎮扮仦鐑╁亾瀹ュ洦鐣遍柣婊勬緲濠р偓闁煎浜ｉ惁?闁炽儲鏌￠埀?缂佹鍏涚粭渚€鎮ч崼顒傜闁告帇鍊涢鏉款啅閹绘帞鏆扮紒?*闁?
    //   `metaTop` = 闁哄牜鍓濋、?*闁活亞鍠庨悿鍕€掗崣澶屽帬闁?* = `metaTopGeomY(t, rowH)`闁挎稑鐗嗗銊╁及椤栨瑧鐟愰梻鍫涘灲閸嬪懘寮?`.position().y`闁?
    //               **闁告艾濂旂粩瀛樼▔椤忓嫬姣愰柡浣藉焽閳ь兛鐒﹂惀鍛村嫉婢跺矈鍎戝ù婊冨閸炪倗鎮伴妸銊﹀涧鐎?*闁挎稑顧€缁?
    //   `metaOld` = **濞戞挸锕ｇ粩鎾偋閸儱浜濋柡澹溿倕娈伴悗瑙勮壘缁憋紕鈧?*闁汇劌瀚埀顒傘€嬬槐妾俵yricMetaMorphY(t) + t閼?size闁愁厽濮皁wH)/2`闁?
    //               閻?`metaTopInUseYAt()`闁挎稑鐬奸獮鍥捶閵娿儱娑ч柣顫妺缁剛鈧數顢婃径鍕晬?*濞戞挸绉撮崯鈧柛娆忓€风粭灞姐€掗崣澶屽帬**闁挎稑顧€缁?
    //   `metaD`   = `metaOld 闁?metaTop`闁?
    //   ## 闁告帇鍊涢浼存晬閸粏鈷堢紒鏃戝灦閸忔﹢寮?*鐎规瓕灏欓悡锛勬暜閸涘﹥娈?*闁挎稑鏈晶宥嗙閵夈劎绠瑰☉鎾亾閻炴稑鐬奸獮鍥捶閵娿儱璁查悹鍥︽閸氬鏁?
    // ```
    //   t = 0闁挎稑鐗嗛惃婵嬫閵忋們鈧鏁嶆径娑氱獥metaD 闁?**闁?0**
    //       闁炽儲鏌￠埀?闁哄唲鍐閻庢稒鍔楀▓?from 闁?`LYRIC_META_GAP_VP(10)`闁挎稑鐗婂﹢鐗堢閹炬彃寮烽悗瑙勮壘閳ь剛銆嬬槐姘舵晬?
    //          闁哄倹婢樼槐锛勨偓娑欏姉閺?`COVER_FIT_META_GAP_VP(50)`闁挎稑鐗婂Λ銈夋偩?`fitPlayerOverlay` 闁汇劌瀚垾鏍磽閺嶎偆鍨?a8闁?
    //          闁?闁哄唲鍐閻庢稒鍔栭惁顕€寮弶璺ㄧ閻庢稒鍔欓悵?40vp 闁?metaOld 闁?metaTop = 闁?0
    //   t = 1闁挎稑鐗婇悺鏇犳嫚瀹ュ鈧鏁嶆径娑氱獥metaD 闁?**闁?.64**
    //       闁炽儲鏌￠埀?闁哄唲鍐閻庢稒鍔曢崺?閻忓繐绻愰惃婵嬫閵忋們鈧﹥娼?+ (size闁愁厽濮皁wH)/2"闁挎稑鏈弻濠傤嚕韫囨挾鎽嶉柛?閻忓繐绻愰惃婵嬫閵忋們鈧﹥娼?+ 28 闁?rowH/2"闁?
    //          濞戞挶鍊涢埀顒€鎳庡Ο?= 28 闁?size/2 = 28 闁?48.72/2 = 3.64 闁?闁哄唲鍐閻庢稒鍔欓悵?3.64vp
    //   闁?濞戞搩鍘介宀勫及椤栨繄绠瑰☉鎾卞€楅顒勬儍閸曨厼娈犻柟顑嫬绲婚柛濠勵儠閳?
    //   闁宠法濯寸粭?闁?t=0 濠?metaD 濞戞挸绉靛Σ?闁愁喖鐗冮崹?0闁挎稑鐗呯欢銉︿繆?闁?闁挎稑顦崳?閻犲洤鐡ㄥΣ?`bigEndpointRect()` 濞戞挸閰ｉ崑鍛村级閳╁啯锛嬬€殿喖绻愰悺?
    //      闁活潿鍔庡▓鎴︽儗閳轰浇鍩岄柡澶堝劜缁喗绋夊鍛€遍柨娑樼墛濡偄顕ｈ箛鎾舵憤閻?`lyricMetaFromYOf()`闁挎稑濂旂悮閬嶆嚀閸涙潙鍘撮柛鈺勬〃缁?`bigEndpointRect`闁?
    //      闁荤偛妫滈鎴炵▔婵犲倹鍊辨繝褎鍔х槐姘跺灳閺傝　鍋?闂侇叏绲惧鍌炲箥瀹ュ浠橀悷鏇氱劍閻擄繝濡?
    // ```
    const metaTop: number = e.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const metaOld: number = e.metaTopInUseYAt(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const line6: string = `metaTop=${metaTop.toFixed(1)} metaOld=${metaOld.toFixed(1)} ` +
      `metaD=${(metaOld - metaTop).toFixed(1)} (t=0 闁哄牏鍠愬﹢?闁?0 / t=1 闁哄牏鍠愬﹢?闁?.6) ` +
      // 闁?2026-10-17闁?*閺夆晜鐟ょ粩鎾级閳ュ啿鍤掔紓浣哥箣缁?鐎垫澘鎳撻浼存儍閸曨偄鐏查柟?闂傚嫬绉舵鍥ㄧ▔?缂備焦鎸婚悗顖涚▔瀹ュ懎缍侀梺鎻掔箰閹界娀宕?**闁挎稑顧€缁?
      //   `lBox` = 婵繂鐭侀惁婵囥亜闂堟稑鏁堕悗鐟版贡濞插懘鎯?*缂佹劖顨呰ぐ娑欍亜閹壆鐝?*闁挎稑娼塺eportLyricBoxTop` 闁哥姴鍋婄槐姘跺Υ?
      //   缂備焦鎸婚悗顖涚▔婵犲啩鑸☉?**0**闁?闁?閻忓繗椴稿Σ?Swiper 闁汇劌瀚ú鍛存晬瀹€鍐ｅ亾?Swiper 闁圭鍋撻柛锔哄妿濞?`Column` 濞?
      //   `LyricFloatLayer()` 闁哄嫷鍨伴幃鎾寸▔閳ь剚绋夐鍐憹閻?padding 闁?`Stack` 闁汇劌瀚銏⑩偓娑欏姧缁辨繃绋夐弮鍥跺殙 `Stack`
      //   闁汇劌瀚崬瀵糕偓鐟版贡濞插懎顔忛敂璺ㄧ憪閻?= 缂佹劖顨呰ぐ娑㈠储閻斿搫浠?闁炽儲鏌￠埀?閻庣懓鏈弳锝囨嫚娴ｇ懓绁﹂梺鐐礃椤?`PlayerExpandState.lyricBoxTopVp` 闁?JSDoc闁?
      //   闁?`lyricPadTop()` 闂侇叏绲惧?缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨?+ 23"闁汇劌瀚槐锛勨偓?*鐎规瓕灏欑划?*缂佹稑顦悳顖涚鎼淬垺锟ラ柣锝呯灱濞堟垿鎯勯幒鎴濇暥鐎殿喖绻愰悺?闁?
      //     **濞戞挸绉瑰〒鍓佹啺娴ｇ懓搴婄紒鐘愁殣缁辨繃绋婇悢鍓佺憹闊洤鎳庨崯鈧悹鍥ㄦ缁绘牗绋夐鍛濞存粌妫庨埀?*
      //   闁宠法濯寸粭?閻庣懓鍟伴獮鍥捶閵娿儱娑ч柡鍫濐槷缁斿瓨绋夐鍡樻殢闂侇偅妫戠槐?*闁兼眹鍎遍惃銏ゅ级閵夛附绠掑ù婊嗘缁即鏌囬敐鍕拡閻忕偛鍊告慨鐐寸?padding闁挎稑鐭佺换鏍煂鐏炶偐绐楅悹鍥嚙閸╁矂寮版惔銏♀枖闂?0** 闁炽儲鏌￠埀?
      //     闂侇叏绲惧鍌炲箥瀹ュ浠橀悷鏇氱劍婵?`lyricPadTop` 闁瑰箍鍨洪崹?`(婵炴惌鍠栭惇鐗堟償閺囷紕鐝?闁?lBox) + 23`闁挎稑鐗呯粩瀵告偘瀹€瀣闁?
      //   闁宠法濯寸粭?闁告柣鍔庨弫鐐▔椤撶偟鏆婇柛娆樺灥閸忔﹢鎯夐浣诡槯闂?0闁挎稑鐗撻崑鍛村及椤栨凹鍟囬柛锝冨妼瑜板骞戦姀锝囩畺闁?`globalPosition.y`闁挎稑鏈婊呮暜闂堚晝绀嗛柍?闁?*闂傚牊鐟﹂娑㈠箑?*闁汇劌瀚浼村极閼割兘鍋?
      `lBox=${e.lyricBoxTopVp.toFixed(1)}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*"婵繂鐭侀惁婵囥亜闂堟稓娈遍梻鍫涘灪閻ュ懘宕ｅΟ铏规瘓"闁汇劌瀚ú鍧楀箳閵夈儱鐏查柟?*闁挎稑鐬奸弫銈夊箣妞嬪孩鍩傞柡鍫㈠劋閸╁懘宕堕幆褎鍊甸柛鏃傚缁辨岸鏁?
    //   闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳濡村畝鍐闁哄嫷鍨遍悺鏇犳嫚瀹ュ鈧鏁嶅畝鍕簼濞戞搩浜滈惃婵嬫閵忥紕姊鹃柛娆惷惃顒勫Υ瀹ヤ礁娅?閻犲洨绮弳?`t=0.00 edge=331`闁?
    //   閻忓繋绶氬鎵焊閸濆嫷鍤?= `lyricMorph(lyricMorphT).size`闁挎稑鐭侀埀?`lyricMorphT` 闁告瑯浜濆﹢?0/1 濞戞挶鍊撻柌婊呯矙閸愯尙鏆伴柛濠勩€嬬槐?
    //     鐠?`t=0` 闁?閻忓繋绶氬?= `endCoverSize`闁挎稑鐗婇弳锝囩玻濡ゅ懎浜濆☉鎾亾濞?闁?331闁挎稑顦埀顒佹煛閳?閻忓繗椴稿Σ鎼佹偨閵婏箑鐓曢柣顏勵儏閸╁矂鎯冮崟顐犱海閻忓繋绶氬浼存晬?
    //     鐠?`t=1` 闁?閻忓繋绶氬?= `lyricCoverSizeOf()`闁挎稑鐗嗛惃顒備焊娓氣偓濞?闁?48.72闁挎稑顦埀顒佹煛閳?閹煎瓨姊瑰﹢渚€鎯冮崟顒傚閻庢稒鍔戦埀?
    //   闁?闁圭鍋撳ù?婵炲备鈧啿缍侀悘? 闁?**`lyricMorphT` 婵炲备鈧啿鐓?1**闁靛棗鍊界换鏍ㄧ▔閳ь剛鎮板畝鈧ú鍧楀箳閵壯呰埗闁告垵鎼悾鐘崇▔鏉炴壆鐭嗗☉鏂跨墛閻ュ懘宕氱敮顔剧獥
    //     鐠?`sw`  = `playbackSwiperIndex` 闁炽儲鏌￠埀?**濞戞挸绉靛Σ?1** 闁?闁哄秷顫夊﹢鏉库柦閳ュ啿鐎奸柛鎺斿閻℃洜鎷犲澶堚偓澶愭晬閸喎鐏楃紒渚垮灩缁扁晝鎮銏╂Щ濞达絽绋勭槐?
    //     鐠?`tgt` = `lyricMorphTarget`   闁炽儲鏌￠埀?濞?`sw` 濞戞挸绉崇粩鎾嚊?闁?閻炴稏鍎靛Λ鍧楀棘閻熺増鍊婚柛娆忕С缁?/ 婵炲备鍓濋弫鍦焊?
    //     鐠?`vis` = `lyricMorphVisible`  闁炽儲鏌￠埀?`0` 闁?`lyricFloat()` 闁告帇鍊撶拹鐔哥▔瀹ュ懎璁查柣銏╃厜缁辨繈寮弶鎴濡炲鍋犻、鎴濃柦闄囬幑?
    //     鐠?`sg` / `fs` = `lyricSwiperSettled` / `lyricFlightSettled` 闁炽儲鏌￠埀?濞戞挶鍊濆Λ鍫曞箵閳╁啫顤佹繛宀嬬節缂?
    const line7: string = `sw=${this.playbackSwiperIndex} tgt=${this.lyricMorphTarget ? 1 : 0} ` +
      `vis=${this.lyricMorphVisible ? 1 : 0} op=${this.lyricMorphOpacity.toFixed(2)} ` +
      `sg=${this.lyricSwiperSettled ? 1 : 0} fs=${this.lyricFlightSettled ? 1 : 0} ` +
      `lcEdge=${e.lyricCoverSizeOf().toFixed(1)} lcY=${e.lyricCoverYOf().toFixed(1)} ` +
      `float=${e.lyricFloat() ? 1 : 0}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*Swiper 闁搞儳鍋犻惃鐔衡偓鍦仜瀵?* 闁炽儲鏌￠埀?閻熸瑤绀侀悺褍鈻?`diagAnimStart` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柨?
    //   `ast=-1--1` = `onAnimationStart` **濞戞挴鍋撴繛鍡節閸忔ê鈻介檱缁绘﹢寮堕妷銊х畺**闁挎稑鐗冮崳?闁告帒娲妴澶娾柦闄囬摂瀣煥閹存繂袟闁搞儳鍋犻惃鐔兼晬婢舵稓骞?
    //   `ast=0-1` + `skp>0` = 閺夆晜绋掑鍨閸℃洜绋婚悶姘煎亜閻Ｑ囧础椤愶絽鐨￠柟鍝勵檧缁辨瑩鍩?閻熸洑鐒﹂弫鑲┾偓鐟扮墕瀹曞ジ宕氶妶鍡楃ウ闁挎稑顧€缁?
    //   `chg=1/闁炽儺娉?闁?`sw=0` = swiper 閻犱降鍊撶拹鐔煎捶閵婏妇鎽冮悹鍥хЧ閵嗗濡存担鍝勑﹂柟顑跨瀹撳牏鎷嬮幍顔界祷 0闁挎稑鐗冮崳?闁绘鍩栭埀顑跨劍閻ュ懘宕ョ仦缁㈠妱闁挎稑顦埀?
    const line8: string = `ast=${this.diagAnimStart} skp=${this.diagAnimSkip} ` +
      `aend=${this.diagAnimEnd}/${this.diagAnimEndCount} ` +
      `chg=${this.diagChg}/${this.diagChgCount}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*閺夆晜绋戠€瑰啿鈹冮幇顖氭閻?* 闁炽儲鏌￠埀?goal 缂?1 闁哄鍓濈€垫氨鈧姘ㄥ▓?`swiperProgress` 缂佹稑顦悳顖炴偋閳哄绀嗛柨?
    //   `scr` = `onContentDidScroll` 闁汇劌瀚惃鐔兼偨閵婏富鍋ч柡浣稿簻缁?*闂侇偅鍔曢幎?*閻熸瑱绠戣ぐ鍌炴晬瀹€鍐炬綄閻庤蓱閺?SDK 闁告鍠愰弸鍐晬婢舵稓骞?
    //   `last` = 闁哄牃鍋撻柛姘凹缁旀潙鈻庨垾宕囨澖闁?`index/position`闁?
    //   闁告帇鍊栧畵渚€鏁嶅顑跨不闁革负鍔嶉悺鏇犳嫚瀹ュ鈧寮捄铏瑰畨鐟滅増鎸惧﹢鍛村礆?**`last=0/1.000`**闁挎稑鐗婂Λ銈夋偩鐏炴儳惟 `position` 濠㈠墎鎳撻崺?1闁?
    //   濞戞柨顑呴幃?`index === 0` 闁归潧绉靛ú鍧楀棘閼割兘鍋撴担鐟邦暡濞寸姰鍎遍悾鐘电矙閸愯尙鏆伴柛瀣矊濠€?1闁挎稑顦埀顒佹煛閳?闂侇叏绲惧?`lyricMorphT` 濞戞梻鍠庣花鍙夌▔?1闁?
    //   閻忓繋绶氬?`edge` 閹煎瓨鏌ㄨぐ澶愬箣閹邦剛姣堥悘蹇庣窔濞间即鏁嶉崼姘暭48.7闁挎稑顦埀?
    //   `scr=0` 闁?閺夆晜鐟ら柌婊堝炊閻愬墎娈跺☉鎾亾婵炲棴绻濋崗妯衡柦闄囪闁告瑦鍩婄槐娆戞啺娴ｇ懓搴婇弶鈺傜☉鐎瑰啿鈹冮幇鍓佺闁?
    const line9: string = `scr=${this.diagScrollCount} last=${this.diagScrollLast}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁稿繑濞婂Λ瀵告崉椤栨氨绐為柣銊ュ楠炲洭宕锋ウ娆惧殺闁?* 闁炽儲鏌￠埀?闁活潿鍔嶉崺?23:19/23:20 濞戞挸顦板顖炲矗瀹ュ娲柣銊ュ閻ｇ偓鎷呭鍥ㄦ殢闁?
    //
    // 闁活潿鍔嶉崺娑㈠矗瀹ュ娲柨娑樼墕鐢偆鎷犲┑鍥舵搐闁瑰鍓ㄧ槐姘舵晬?
    // ```
    //   闁?闁哄牆顦板?闁圭虎鍘介弬浣广亜閻㈠壊娴曞銈呭悁缁楀懘寮悷鏉挎濞戞搩浜濈€垫粓鏌﹂鑽ょ槏濞村吋宀稿▓锝夋寠?
    //   闁?"閺夆晜鏌ㄥú鏍礂閹惰姤锛旈柟缁㈠幗閺備線宕抽妸锕€鐏夐柛娆愬灩楠炲洦绋夊鍡樞︽繛灞勩倕鍓归柡鍜佸灲缁辨繃鎷呴悩鍨畽闂侇叏绲肩粩鎾级閳藉懐绀夐柡?*闁哄牆顦抽崕妤呭疾椤栨瑧绋婚柡鍕靛灦閻濐喗鎯旈敂鎯ь棗濞?*"
    //   闁?"濞戞挸顑嗘刊娲礂閹惰姤锛旈柟缁㈠幗閺備線宕抽妸銉ф闂傚牄鍨哄Σ鍛婃交濞嗗酣鍤嬮悘蹇撶箰濞撴崘銇愰～顔剧闁绘帟娉涢幃妤呭礉閵娧勬毎缂備焦鎸诲顐ｇ?*缂佹劒鑳堕崝褔寮堕妷銈夊殝閻忕偞娲栫槐鎴﹀箻椤撶喐鏉归柛锝冨妿濞堟垿宕濋妸褎鏆?*"
    // ```
    // 閺夆晜鐟ょ粭渚€寮堕敓鐘插幋闁告瑦鍨归弫鎾诲捶?*闁稿繑濞婂Λ瀛樻交閸モ斁鏌ゅ☉?*闁挎稑鐭侀埀顒€濂旂粭鍌炴?1~9 閻炴稑鑻妵鍥ㄥ緞濮橆厽笑"闂傚牊鐟﹂娑㈠箑娴ｇ瓔鍤㈤柡? 闁?闊洤鎳橀妴蹇曟偘閵夈劎绠瑰☉鎾亾閻炴稑琚埀?
    //
    // 闁告艾瀚伴崳娲儍閸曨偄鐏查悹鍥︾串缁?
    // ```
    //   show  = 濠㈢懓鍟块惇?isShowPlay闁靛棗鍊甸幉?闁汇劌瀚妵鏃堝矗瀹勬壆褰嶉柣銈嗗煀缁变即鎳熼妷銉ф殜闁革负鍔岄崣褔姊婚鈶╁亾閺傛崘鍘柛娆惷ú?true闁?
    //           濠㈢懓鍟块惇?`@Monitor('appState.isShowPlay')` 濞?`pushPlayerRoute()`
    //           闁?**闂佹彃绉甸弻濠囧箳閵娿儱寮冲☉鎾亾濞戞搩浜濋弻濠囨儍閸曨剚灏￠柡鈧ィ鍐︹偓澶屸偓鍦仒缁?* 闁?閻忓繗椴稿Σ?闁告瑥鐗婇弬浣圭▔閳ь剟鏌嗗鍛綌鐎殿喒鍋?
    //   clos  = isClosing闁挎稑鐗嗛崣褔姊婚銏℃嚑閻犱警鍨伴崙锛勬導閸戙倗绀?
    //   coll  = 闁硅矇鍐ㄧ厬闁告牕鎼崙锟犲绩閹増宕抽柨娑樼墐閹?闁汇劌瀚ú鍧楀箳閵夘煈鍤㈤柡浣稿簻缁? = 闂侇叏绲介崵鎴炵▔椤忓懎鐦婚梺绛嬪枟濡叉悂鎸婅箛鏇熺祷闁汇劌瀚哥槐?
    //   p     = morphP闁挎稑鐗嗛崣褔姊婚鐔割槯闁?0 閻犙冨簻缁?
    //   clipH = **闁告劖鐟ㄧ换妯尖偓鍦嚀濞?`.height()` 闁汇劌瀚ˉ鍡涘礈椤忓棛宕堕柛娆欑秮閻?*闁挎稑鐗冮幉?闁汇劌瀚ú鍧楀箳閵夘煈鍤㈤柡浣稿簻缁?
    //           闁煎啿鏈▍娆撳及椤栨凹鍟囬柛锝冨妿濞堟垹鈧稒鍔樻俊顓㈡倷?闁?閻庡湱鎳撳▍鎺旀偖椤愩儺姊块柟瀛樺姇椤︽寧顨囧鍫㈢闁煎啿鏈▍娆戜焊閸楃偛娑ч柣銏ｎ嚙椤︽寧顨囧鍫㈢
    //           闂傚牊鐟﹂娑㈠箑娴ｅ摜瀹?= 0闁挎稑鐗婇婵嬪籍?`.height()` 闁告劕鎳橀崕瀵告導?'100%'闁挎稑顧€缁遍亶宕楅幎鑺ワ紨濞戞搩鍘虹槐鐗堟交閻愮數鏁鹃柛娆惷崺?闁?閺夆晞娓圭紞姗€寮堕敓鐘靛蒋
    //   bg    = 闁煎啿鏈▍娆戜沪閸屾瑧鐟濋梺顐㈢箲濡叉垶鎯旈敂鑲╃闁?闁活亜顑呴悾鐘诲嫉婢跺姊鹃柡鍫濐槼椤箑菐閳╁啫绔撮柨?
    //   drv   = morphDrive闁挎稑婀桰NGER/ANIM/NONE闁?
    //   sq    = morphSquashY闁挎稑鐗愰幆銈嗘媴瀹ュ棗鐨ㄩ柛妯侯儜缁辨繈鍩? 闁哄啳娉涘﹢顏勵嚕閻у摜绀?
    //   pd    = **閻犺櫣鍠愭晶?閻炴凹鍋呯€?閻犱讲鍓濋弳?*闁挎稑鐗冨Σ?2026-10-17 闁哄倹婢橀·鍐晬瀹€鈧ú鍧楀箳閵夈倛绀嬮柣顫妽閸╂盯鎯冮崟鈹惧亾鐏炶偐鐟愭繝濠冨灣缁楀鎳楅崐鐔锋闁活澀绌堕埀顒€绋勭槐?
    //           `<閻犙囨敱婢ф粓骞?/<闁哄洤鐡ㄩ弻濠囧箯?/<闁哄鍋撴晶婊堝箯?`闁?*缂侀硸鍨甸鎼佸磹缁楄　鍋撴担椋庣憹婵炴挸鎳樺ù?*闁挎稑鐗撻崳鎼佸触?App 闁归潧绉寸紞濠囨⒖鐠佸湱绀嗛柕?
    //           闁活潿鍔嶇涵鍫曟晬濮樻剚鍞ㄧ€垫媽濮ら悥锝咁嚕閳ь剟鎯堥埀?闁?闁稿鐭粩鏉戔枎閳ヨ尙鐟愰柟?闁?闁活亜顑堢换鏍ㄧ▔婢跺鍤嬮柡?*闁哄牆顦伴惀鍛村嫉婢跺﹤缍?*闁?
    //           鐠?闁告瑦眉缁?闁?闁靛棗濂旂粭澶屾崉閻旂顤侀柕鍡楃У濡?*闁告帇鍊栧畵?*闁归攱甯炲▓鎴︽晬鐏炶偐鐟☉鎾亾闁活亣鍋愬﹢鍛村礄閻戞ɑ笑闁告繍浜欑粩瀛樼▔椤忓海绐?
    //              缂?1 濞戞搩浜濈€?= 閻犙囨敱婢ф粓鏌囬敐鍕伇闁告帟顕ч崵鎴炴媴閺囩喓姊鹃梺鎻掔箻缂嶅牓鏁嶉崼銏＄函闁规亽鍎甸幗闈涱煥鎺抽埀顑跨劍濡倗鎹勯悢绋款杹闁告柣鍔庨弫楣冩晬?
    //                          闁?闁?`measureMiniDuringPull` / 閺夆晞娓圭紞姗€寮堕埄鍐┬﹂柛姘剧畱閸戯繝骞愰崒婵囩グ闁?
    //              缂?2 濞戞搩浜濈€?= 闁归潧顑嗙€垫岸宕烽妸銉バ楀ù?`pullDragging` 闁哄嫷鍨版禍锝夋晬閸喐鎷辩紒顐ょ帛濞撳爼宕ｉ婊勭€块柣銊ュ缁旀挳寮堕埥鍛
    //                          闁告ê妫楄ぐ鑸电▔婵犲懐绠瑰☉鎾亾缂侇偉顕ч崙锛勭磼韫囨挸姣夐弶鈺佹矗鐞氬崬鈻庨垾铏鐟滅増甯槐鐗堟倕round-36 闁?`staleClr`闁?
    //                          闁?闁?閻犲鐒︽俊?`pullDragging` 婵炴挸鎳忛崹姘閸℃ぞ娴?闁?
    //              缂?3 濞戞搩浜濈€?= 闁哄鍋撴晶?闁告瑦鐗楃粔椋庢偖椤愩垹鐏查柟璇″枟鐎氬棝鏁嶉崼鐔告毆閻忓繒鍋撻惀鍛導?闁?濡炪倗鏁诲浼村础閳ヨ櫕韬柛妤€锕ㄩ惌楣冩晬婢跺牃鍋?
    //           鐠?濞戞挴鍋撳☉鎿冧邯閸忔ê鈻介垾鍐茬秮 闁?闁告帇鍊栧畵渚€宕楅妸褉鏌ら柡鈧幑鎰垫斀 闁?闂傚偆鍣ｉ。浠嬪捶?*(b)濞存粌顑勫▎?闁归潧顑呮繛宥囨嫚閸℃鐒?闁绘鐗嗙槐?*闁?
    //             **濞戞挸绉烽々锕傚礃瀹ュ懎绠甸柛鏂诲妿婵悂骞€娴ｈ绨?*闁挎稑鐗呴幈銊モ枖閺囩偟鏆氶柛蹇嬪妺缁楀宕ュ畝瀣闁?
    //           闁宠法濯寸粭?缂?2 濞戞搩浜濆Σ?*闁圭顦版晶婊堝礉閼愁垼鍚€婵?*闁汇劌瀚哥槐娆愮▔閳ь剙鈻庨埄鍐杹闁告梹瀵у〒鑸靛緞?+1闁挎稑顧€缁辨繄鎲?
    //              `Index.pullDropCountedThisGesture` 闁汇劌瀚鈺呭及鎼存稈鍋?
    // ```
    const line10: string = `show=${this.state.isShowPlay ? 1 : 0} clos=${this.isClosing ? 1 : 0} ` +
      `coll=${this.chromeCollapsed ? 1 : 0} p=${e.morphP.toFixed(2)} ` +
      `clipH=${e.morphClipHeight.toFixed(0)} bg=${this.backgroundRevealOpacity().toFixed(2)} ` +
      `drv=${e.morphDrive} sq=${e.morphSquashY.toFixed(3)} ` +
      `pd=${e.pullDropBegin}/${e.pullDropUpdate}/${e.pullDropEnd}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁告劕鎳庨鎰沪?onAppear 閻犙囶暒缁繝宕鍛拫闁告帒妫欓弫?* 闁炽儲鏌￠埀?閻庤鐭紞?闁稿繑濞婂Λ鎾触鎼粹€冲珘闁衡偓閸欍儳顏遍梺顒€绉撮惈宥咁嚕閳?闁挎稑顧€缁?
    //   `ab` = morph闁挎稑鐗嗛懜浼村矗濡搫鐎婚柡鈧銈囩婵繐绲介悥鍫曟晬? intro闁挎稑鐗愰幑锝嗙?playExpandIntro 闁?闁稿繑濞婂Λ鎾籍鐠哄搫姣夐柣婊勬緲瀹?bug闁?
    //        / skipClose闁挎稑鐗嗛崢瑙勬償閺囩偛鐎婚柡鈧娆戠ɑ閻?婵繐绲藉﹢顏堝礂閹惰姤锛?闁汇劌瀚板Λ顒勫箯閿旇法鐟撻柨娑樻湰濠€鐗堟姜椤旇姤鐓€濠⒀呭剳缁?
    //   `ap` = introPaintReady闁挎稑鐗婇弳锝嗐亜閻㈢數甯涢柛鎺戠埣濡剟鏁?
    const line11: string = `ab=${this.diagAppearBranch} ap=${this.introPaintReady ? 1 : 0} ` +
      `stage=${e.morphStage} exit=${this.expandIntroRunning ? 1 : 0} bgBox=${this.diagBgBox} ` +
      // 闁?2026-10-17闁挎稒鐡猰esh` = 缂傚啯鍨堕悧绋库攦閹邦剚韬☉鎾崇Т濠€顏堟晬? = 閻犙勬緲閸樿鎯旈弴鐐茬悼闁哄秶鏌夋竟濠勪沪閸岋妇绀夐梺顓ㄧ到閻?*閻?alpha**闁挎稑顦埀?
      //   闁告帇鍊戦埀顒€鐬奸崑锝夊礄缂佹ɑ灏￠柡鈧悙顒佽拫闁瑰灚鎸哥槐鎴濃柦閳╁啯绠掗柤鍐叉湰濞呮瑩濡村蹇曠獥`mesh=0` 闁?闁哄嫷鍨拌ぐ鍥炊妤ｅ啯鎳犳繛灞糕偓鑼憪闁哄鍎荤槐娆撴儑?`RzdBgRetry`闁挎稑顧€缁?
      //   `mesh=1` 闁兼澘鑻惈鍡樼▔婵犱胶鐭濇繛灞稿墲濠€?闁?闁哄嫷鍨崇划顖炲礆?閻熶椒绀佹竟鈧柣銊ュ缁ㄣ劑鏁嶉崼銏＄畽 `bgBox` 濞?`clipH`闁挎稑顦埀?
      `mesh=${this.meshSrc !== undefined ? 1 : 0} ` +
      `lcl=${PlaybackPage.lastCloseAtMs > 0 ? (Date.now() - PlaybackPage.lastCloseAtMs).toFixed(0) : 'never'}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁硅矇鍐ㄧ厬闁告牠缂氶崵婊呮嫚?* 闁炽儲鏌￠埀?閻庤鐭紞鍛存偨閵婏箑鐓曠紒?1 闁哄鎵冲亾鐏炵偓绠掗柡鍐╂构缁楀懘寮悷鏉挎濞戞搩浜濈€垫粓鏌﹂鑽ょ槏濞村吋宀稿▓锝夋寠韫囧鍋撳蹇曠
    //   闊洤鎳橀妴蹇涙嚄閽樺鐎婚弶鍫涘姀缁绘牗绋夋径宀婃綒鐟滆埇鍨绘慨鎼佹晬閸粍鍙忔繛澶嬫礀閻ｎ剟宕楅妸銈囩憹闁告艾鐭夌槐姘舵晬?
    //     闁?闁煎浜滄慨鈺呭绩閹増宕抽柨娑樼墣椤旀洜鎷嬮檱椤㈡垶绋夐悮瀵哥獥闁哄啰濮烽弲?`IDLE_MS = 5000`闁挎稑鑻ぐ褔宕?`isPlay` 闁哄啫澧庨弫鎾诲极閸剛绀?
    //        闁?`cc=1` + `cpr=0` + `chH` 婵繐绲介悥?闁?**濞戞挸绉靛Σ?bug**
    //     闁?閻炴凹鍋夐ˉ鍡涘箳婢舵稓绀勯悗鍦嚀濞呮帞鎲楁担绋款梾缂佹劖顨呰ぐ娑㈠箮婵犲啫浠橀柛鎺曟硾鐏忣垶宕氶崶銊ョ闁挎稑顦崳?`clipH` 鐎垫澘鐗嗛惃顒勬嚀?`chH` 婵繐绲介悥?闁?闁哄嫷鍨伴鎰板闯閵娿儱娈ゅù锝嗘礈濞堟垶绂?
    //     闁?濡ゅ倹锚鐎硅櫕绻呭畝鍕仦闁挎稑娼塴yricChromeHeight` 闂佹彃绻戦崹?0 闁?`.height(0 * progress)` = 0闁?
    //        闁?`chH=0` 闁?闁?*闂佹彃绻戠粊?*闁汇劌瀚花銊╂晬閸у埐yricChromeMeasurePending` / `wasConstrained` 闂侇叏绲惧顖炴煣閹惧懐绀?
    //   `cpr` = lyricChromeProgress闁? = 闁稿繈鍔岄崵顓㈠Υ? = 闁稿繈鍔嶉弫褰掓晬婢舵稓骞chH` = lyricChromeHeight闁?
    //   `ofs` = chromeOffsetY闁挎稑鐗婇弫鍦導闁垮顦у☉鎾愁儑浜?46vp闁?
    const line12: string = `cc=${this.chromeCollapsed ? 1 : 0} cpr=${this.lyricChromeProgress.toFixed(2)} ` +
      `chH=${this.lyricChromeHeight.toFixed(0)} ofs=${e.chromeOffsetY().toFixed(0)} ` +
      `pend=${this.lyricChromeMeasurePending ? 1 : 0} play=${this.state.isPlay ? 1 : 0}`;
    // 闁宠棄鎳夊Σ鍕煡?缂佹鍏涚花鑼偘瀹€瀣獥**闁告柣鍔嬬紞鏃€娼妸銊﹀**闁挎稑鐗婂〒鑸垫交?6 濞戞搩浜滄慨鈺傛媴濠婃劗绀夐柟绋款槸瑜板倿鎮介悢绗衡偓搴㈡償?`>` 閺夆晝鍋炵敮鎾晬婢跺牃鍋?
    //   濞戞捁妗ㄧ划鍫熺▕閸喐浠橀柡鍫濐槺閺併倝鏁嶅宕囩闁哄绻濋幗鍏肩▔?濡炪倕鎼花?闁哄牜鍓濋棅鈺冧焊鏉堛劍笑闁煎浜滆ぐ澶愭煂韫囨洘鐣遍柡鍫氬亾濠㈠爢鍐ｅ亾?闁炽儲鏌￠埀?
    //   闁告艾濂旂粩瀛樼▔椤忓嫬姣愰柡浣规緲閸樻稓鎷崘顓犵闁哄嫷鍨伴幃妤冩嫬閸愯法绀夌紓浣规尰閻忓鈧懓鑻崣蹇旂▔瀹ュ懏鍊遍柨娑樼叒?3 闁?`onAppear` 閻犲浂鍨伴崹浠嬪Υ娴?03 闁?
    //   `onDisappear` 閻犲浂鍨卞鍐焾閼恒儲笑濡炪倕鎼花顓㈡⒒椤曗偓椤ｄ粙鏁嶆径娑氱闁兼澘鑻晶鐘诲炊濞戞粠鏀介柛娆樹簽濠€鍛嚗濡も偓閸?鐟滅増鎸告晶鐘诲磹?闁?
    //   闁告帇鍊涢鎵矆鏉炴壆浼愰柨娑樼墢閸嬶綁宕欑紒妯衡叺鐎殿喒鍋撻幖瀛樻煥缂嶅鎯囩€ｎ亜鐓傞柣銊ュ閼镐即鎮╃拋鍦闁?
    //     `clickOpen>beginOk>settle0C>settle1C>measOk>tween`  闁?濞戞挴鍋撻悹渚灥閾斿鏌?
    //     `clickOpen>beginOk>settle0C>settle1C>闁炽儺娉﹂柨娑樼墛濡?measOk闁挎稑顦崳?閻炴稏鍎甸崳鐑樼▔閳ь剟鎯勭€涙姊鹃柟瀛樺姇婵?
    //     `clickOpen>skip`                                     闁?閻?`pullDragging`/闁烩晠鏅茬紞鍛村箰閳ヨ尙鍟?
    //     `闁?tween>settleSkip`                                 闁?閻炴稏鍎靛Λ璺ㄦ導閾氬倻鍟婂ù锝呮閹倖鎷呭鍫蕉閻犲搫鐤囩换鍐晬閸?04 闂侇叏绲跨悮顐︽晬?
    const line5: string = `trace=${e.morphTrace.length > 0 ? e.morphTrace : '(empty)'}`;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*缂佹鍓欏畷鍕▔婢跺寒鏀介柨娑欒壘閸櫻囨⒒椤擄紕绠栫紒?濮掓稒鍨电亸鍫⑩偓?** 闁炽儲鏌￠埀?閻犲洨绮涵鍓佹喆?{@link PlaybackPage.evLog}闁?
    //   濞戞捁妗ㄧ划鍫熺▕閸儲浠橀悷鏇氱閻ｇ娀鏁嶅杈ㄦ殢闁规挳鏀辨慨銈夋儍閸曨亣鈷堥柡澶嗘缁辨瑩濡寸仦钘夊綘闂傚偆鍘藉鍌炴嚄鐏炵偓鐝柛娆樹簻婢ф寧绋夐埀顒勫级鎺抽埀顒€绉查埀顒€鑻崣褔姊婚鐐村€甸柛娆忕墛閺備焦绋夐埀顒勬焼瀹ュ懐娼旂€殿喒鍋撻柕鍡楃▌缁?
    //   **闂侇喛妫勮ぐ鍌炴偨閻旈攱韬柛蹇斿▕濡瓨娼婚崶鈹炬煠濞戞搩鍙忕槐婵嬫嚀瀹€鍕簼濞戞挴鍋撻柛鎺曨嚙缁愭﹢寮介崶褍鍤掗梻鍛箲閹搁亶寮ㄦィ鍐︹偓澶嬬▔閳ь剛鎸ч柨瀣ュ?* 闁?濞存粌顑呴幃妤冩嫚鐠佸磭鐟濋柛鎺楊暒閹广垺鎷呴弴姘鳖偨閻熸锟ラ埀?
    //   闁?濞存粌顑勫▎銏㈡媼閺夋寧韬?*婵☆垪鈧櫕鍋ョ紒鐙欏洦楗柟顑胯兌楠炲棜銇愰姀銏㈠闁?*闂佹彃鐭夌槐婵堢驳婢跺鐟撳☉鎾亾婵炲棌鍓濇晶锕€顕ｉ埀顒勫箻椤撶喐鏉瑰銈夋涧閸熲偓闁哄嫬澧介妵?闁?閻忓繗椴稿﹢浣圭閸℃洜鐟愬☉鎾亾婵炲棌鈧啿褰犻梻鍌ゅ幘濞堟垹鈧懓鏈弳锝夊籍鐠鸿櫣纰嶉柕?
    //
    //   闁宠法濯寸粭?闁哄嫬澧介妵姘跺籍閼搁潧惟 `|` 闁瑰箍鍨洪崹姘跺箲閵忥綆鏀介柨娑欑煯缁斿鎮扮仦鑲╊伇濞戞搩浜欑花銊︾鐠佸湱绀夊☉鎾亾鐎殿喚濮甸崺鍛村炊閹勭殤闁煎啿鈧噥鍤㈤悗?
    //     闁挎稑鐗呯粭澶愬箲閵忥綆鏀介柣銊ュ閻﹁姤娼婚幋婵嗙．閻庢稒顨堥浣瑰濮橆厼鐨ㄩ柟瀛樺姃缁旀挳宕搁…鎺旂11fp 濞戞挸顑呴崵鎴炵▕鎼存繄鐟濋柛娆樺灥椤曚即鏁嶆径鍫氬亾?
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

  /** 闁煎浜ｉ惁澶婎嚗閼恒儳鍨奸柡鍫厸缂嶅鏁嶉崼銉ф嫧閹煎瓨娲滃▍褏鈧稒銇滈埀顑挎缁楀宕ラ崘褏鐨戝ù鐘虹堪閳ь兛绀佺敮鍥捶閵婏附浠樺☉鎾筹躬濞间即鏁嶆径鍫氬亾?*/
  @Builder
  private DiagBadge() {
    Text(this.diagText.length > 0 ? this.diagText : 'V af66eb1 (no data)')
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor('rgba(0, 0, 0, 0.78)')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(6)
      // 闁?2026-10-16闁挎稒鑹剧粣姗€寮介崶鈺佺疀闁革负鍔嶅﹢?**13 閻?*闁挎稑鐗冮埀顒婂椤戝洭宕℃担椋庣檶閻炴稑鏈敮鍫曞礆鐠哄搫闅橀柤濂変海閻?/ 缂佹鍓欏畷鍕▔婢跺寒鏀介柛蹇斿▕濡瓨娼婚崶鈹炬煠濞存粌顑勫▎銏ゅ籍閵夈儳绠堕柨?
      //   濞存粌顑勫▎銏ゅ籍閵夈儳绠堕柡鍫墲闂娾晝浜告潏銊π﹀鑸典亢椤㈡垿鍨鹃弬琛″亾閺傚墽顏遍悶娑樺缁斿瓨绋夐鍐殤濞寸姾顔愮槐姘跺焽?`maxLines` 闊洤鎳橀妴蹇斿緞閻曞倻绀夐柛姘剧畱閸垶寮甸埀顒勫触鎼存繄顏遍悶娑樺缁辨壆鎮锝呯劵闁瑰搫顦埀?
      .maxLines(32)
      .position({ x: 8, y: 120 })
      .zIndex(99)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 濡炪倕鐖奸崕?闂傚懏鍔曢懜浼存倻椤撶偛闅?闁挎稒淇虹换娑㈡倷?3 婵炲棌鈧磭纾婚柛蹇撶枃閸ゆ粎鎷犳担鍝ョ崷闁哄秴娲㈤埀?
   *
   * 闁宠法濯寸粭?闁衡偓閹勮含**濡炪倛鍩栭悥顔界▕鐎ｂ晝鐟撻柕鍡曠閸炲鈧綊鈧稓顓哄☉?*闁汇劌瀚粩瀛樼▔椤忓棛宕曢柡澶嗘缁辨瑦顨?48vp闁靛棔妞掔粭澶愬箯閿曗偓閸欏墽鈧懓鍟╁锔界閹哄秳绨板鑸电墱濞堟垶绋夊鍡愬仾闁挎稑顧€缁?
   *   閻庣懓鍟ぐ褔宕ラ崘鈺佺闁煎浜滅换浣规交濞嗗海顏遍柡澶嗏偓宕囨暔閻庢稒鍔掔粭鍌炴儍閸曨厼浠柛鎴滅串缁辨繃绋夊鍛殯闁告繂绉甸幐閬嶅绩?闁告帒娲﹂悺?婵繂鐭侀惁婵嗩煥濮橆剙袟闁?
   */
  /**
   * 濡炪倕鐖奸崕?闂傚懏鍔曢懜浼存倻椤撶偛闅?闁挎稒淇虹换娑㈡倷?3 婵炲棌鈧磭纾婚柛蹇撶枃閸ゆ粎鎷犳担鍝ョ崷闁哄秴娲㈤埀?
   *
   * 闁宠法濯寸粭?**2026-10-16 濞ｅ浂鍠曠粩瀛樺緞閸曨剙鐏夐柤濂変簻缁讳礁顕ｉ弴鐐插汲闁汇劌瀚锔界閹烘垶绀€鐟?*闁挎稒姘ㄩ鍥ㄧ▔閳ь剟鎮ч崼婵嗘櫢闁汇劌瀚Σ?
   *   `Row().width('100%').height(48).position({x:0, y:96})` 闁炽儲鏌￠埀?
   *   闁?*濠㈠湱澧楀Σ鎴濐嚕?`.onClick` 濞村吋纰嶇粔椋庢嫻閻熺増鍤掑☉鎿冨幖鐏忣垶宕?*闁挎稑娼塇itTestMode` 濮掓稒顭堥鑽も偓鐢殿攰閸ゆ粓鐓銉ョ槺闁?Block闁?
   *   闁?閻庣懓鍟俊?96闁?44 闂?*濞戞挴鍋撻柡浣哥摠濞碱垰螣椤忓嫭鍊婚悽顖ょ畱閻?*闁汇劌瀚崑锝夊礄鐠囨彃寮块柛姘暞鐢偓濞存粌妫庨埀?
   *   闁革负鍔嶉悺鏇犳嫚瀹ュ鈧绋夋繝鍥т簼濞戞挴鍋撻悽顖ら檮濡?*婵繂鐭侀惁婵堟偘?*闁挎稑鐗忛崑锝咁潰瀹€鍐Г閻犲搫鐤囧ù鍡涙晬婢跺棗娅?闁活亞鍠庨悿鍕礉閻旇鍘撮悶姘煎亝鐏忓懘濡?
   *
   * 闁?闁绘粍婢樺﹢顏堝绩鐟欏嫬鐏?*鐎归潻缂氱粭鍌滄喆閹哄秶顏遍悘蹇撶箰濞?*闁?20閼?0 @ y=88闁挎稑顧€缁辨繈宕ｉ鍥舵船闁烩晜鐗曢惃婵嬫閵忕姳绠☉鎾筹龚椤鏌囬敐鍥ь暬濞戞挸绉磋ぐ鏌ユ嚄閼恒儲绠掑ù婧垮€撶花浼存儍閸曨偄闅橀柛鈺冨櫐缁?
   *   鐠?閻忓繋绶氬鐗堛亜绾板绐楅梺顓ㄧ导缁斿鏁敂鑺バ﹂悘蹇庣窔濞间即宕堕幆褍鍓奸柡鍫墲闂娾晠鏁嶉崼鐔革骏闁绘劗鎳撻崵顔炬嫚椤撴繄鐤呴柨娑橆檧缁?
   *   鐠?婵繂鐭侀惁婵囥亜绾板绐梎lyricPadTop()` 濞ｅ洦绻嗛惁澶婎潰瀹€鍐Г婵繐绲鹃弸鍐╃鎼淬垼鐧侀悘鐐插€风粭鍛村棘閻熸壆纾诲┑顔碱儜缁辨繃绋夊鍕獥闁解偓閽樺鐓傞弶鈺傜懁缁斿浜歌箛鎾村仴闂佹彃琚埀?
   *   鐠?濡炪倛鍩栭悥顕€宕?`y < 88`闁挎稑濂旂弧鍐枈妫颁胶鐟濋柛鎺曞焽閳?
   * 闁宠法濯寸粭?闁兼眹鍎遍幗銏″緞閳哄嫮绠归柛褎銇炵弧鍐閳ь剛鎲版担鐣屾濞达絽绉堕悿鍡涙晬?*闁稿繐鐗忛垾妯兼媼閵堝嫮鐟濋柛妯侯儏濠€?闁哄牆顦锔界閹烘梹鐣遍悽顖ょ畱閻?濞?*闁?
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

  // 闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?闁硅矇鍐ㄧ厬闁告牠缂氶崵婊堝礉閵婏附鏆悹?闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`BarCollapse`闁挎稑顧€缁变即骞忛弽褍袟闁硅矇鍐ㄧ厬闁哄鍓濋弫鍦導?閻忕偞娲栫槐鎴︽儍?*闁归潧顑呮繛宥夋偐閼哥鍋撴担瑙勭皻**闁?
   * 闂侇偅鍔栧顖涙姜椤掆偓閸熸挾鎲?`common/musicbasic/.../model/BarCollapse.ets`闁挎稑鐗嗛幆鍫⑩偓娑欘殙婵☆參鎯嶆担绛嬫斀闁告瑥鍢查顕€鎮¤閵嗗啴鏁嶆径鍫氬亾?
   * 闁告瑯浜濆﹢?`onChromeBarTouch()` 濞村吋姘ㄩ弫銈団偓鐟板暔閳?
   */
  private barCollapse: BarCollapse = new BarCollapse();

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`PlayerPage.showChrome()`闁挎稑顧€缁?*闁?濞存粠鍠栭崵顓㈠箳瑜嶉崺妤呭礌?闁挎稑濂旂粭澶愭煂瀹ュ洨鏋傜紒灞炬そ濡晫鎷嬮埄鍐╊槯**闁?
   *
   * 闁告垵鎼ˇ鈺呮晬閸у垳recover/logic-src/PlayerPage.abc.txt:11942-11982`闁挎稑顧€缁?
   * ```
   *   showChrome() {
   *     if (chromeHidden) {
   *       getUIContext().animateTo({ duration: CHROME_ANIM_MS, curve: Curve.EaseInOut },
   *                                () => { chromeHidden = false; });   // 娴ｅ勃5*#
   *     }
   *   }
   * ```
   * 闁?闁稿繑濞婇弫顓㈡晬?*閻庣懓鍟撮崳鐑芥閵忥紕姊鹃柡?`startIdle()`**闁挎稑娼塰ideChrome` 闂佹彃濂旂弧鍐ㄢ柦閳╁啯绠?`clearIdle()`闁挎稑顦埀?
   *   濞戞梻鍠庡銊╁及椤栨繍鍤?闁哥偑鍊曢崵顓㈠箳瑜嶉崺妤呭礌?濞?閻犙囶棑閳规牠姊婚懠棰濆悁闁?闁哄嫷鍨卞Λ銈夋偩瀹€鍕**濞戞挶鍊撳▎銏ゆ偑椤掑倻褰岄柣銊ュ缁?*闁?
   *   閻熸洑妞掔粭澶屾啺娴ｈ姤宕抽悹浣插墲濡炲倿鎮?*閻犲鍟伴弫銈夋倷?*闁告劕鍟块悾楣冩晬閸綆娼?{@link PlaybackPage.onSwiperIndexChanged} 濞?
   *   `onLyricInteract` / `onLyricSwipe`闁挎稑顦埀顒€鍊归崹婊勭椤掆偓鐢偊寮堕妷锕€惟濞戞挶鍊涢埀顒€鎳忓畷瀣箣閹邦亞顏卞☉?`touchChrome()`闁?
   *   濞存粌瀛╁Σ鎼佸捶?闁告帒娲ら崺宀€浜告笟鈧鐗堛亜?闂侇叏绲惧顖滄崉椤栨瑧鐟愬ù?*濡炪倗鍎ゆ晶婊堝箮婵犲嫧鏁勯梻鍌濆蔼椤撴悂寮張鐢电槏閻犙呮焿閹癸綁寮?* 闁炽儲鏌￠埀?濞戞挸瀛╁Λ銈夋偩瀹€鈧ù澶愬矗瀹ュ繒绀勯梺顓ㄧ秮閸ｇ兘寮?`clearIdle()`闁挎稑顦埀?
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
   * 閻犱焦婢樼紞宥嗙▔閳ь剙鈻庨埄鍐ㄤ粯闁告帟娉涚亸顖涚閵堝嫮闉嶉柨?*闁哥偑鍊曢崵?+ 闂佹彃绉堕悿鍡涙嚊椤忓嫬袟闁衡偓閹増宕抽悹浣插墲濡?*闁?
   *
   * 闁哄啰濮烽弲顐︽煂瀹€鍐濞戞挶鍊撳▎銏＄鐎ｎ偅笑闁告帒妫楃槐鎴︽儍閸曞墎绀刞showChrome()` 濞?`startIdle()`闁挎稑顧€缁辨繈宕ｉ鍛畳
   * "闁活潿鍔嶉崺娑㈠捶閵婏妇鎽冮悹鍥хЧ閵嗗绋夋繝鍕化濞?濞戞挸顑嗙划锔界?閺夆晜鐟х悮?*闁活亞鍠嶅锔界?*闁归潧绉撮幃鎾诲籍鐠鸿桨绮靛☉鎾卞€撳▎?闁炽儲鏌￠埀?闁圭鍋撳ù鐘劥缁绘牠鏌岀仦鑲╃闁伙絾鐟ㄧ换鏍ㄧ▔椤忓棛鐭嬮柛姘墕閸欏棝宕ｉ敐蹇曠
   * 闁汇垼绮鹃惃鐔兼偨閵娧冧化闁煎浜滅换渚€鏌呮径娑氱闁告帒娲妴澶愭焽閿濆棙钂嬮悹渚灠瑜把呮嫬閸愩劌寰撳☉鎿冨幒缁斿瓨绋夐搴ｇ閻?`onSwiperIndexChanged`闁挎稑顦埀?
   */
  private touchChrome(): void {
    this.chromeTouchedAtMs = Date.now();
    this.showChrome();
    this.scheduleChromeAutoHide();
  }

  // 闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?閻熶椒绀佹竟鈧悗鍦嚀濞呮帟銇愰姀鐘茬秮闁挎稑鐗嗛顕€寮介崶銊︼骏闁?ExpandAnimation闁挎稑顦弨銏ゅ煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀顒勫煘閳ь剟鍩為埀?

  /**
   * @returns 闁轰焦鎸抽妴澶嬬▔瀹ュ鍋撹箛鏃€顫栭幖杈捐缁?*闁诡厽甯婄拹?1**闁挎稑鐗嗛鎰板闯閵婏附鎷遍棅顒夊亗缁楀菐閳藉懐绀嗛柕?
   *
   * 闁宠法濯寸粭?閺夆晜鐟╅崳鐑藉储閻斿憡闄嶉柟?`p/0.12` 婵烇絺鈧啿寮抽柡浣虹節闁叉粎鈧湱鎳撳▍鎺楁晬鐏炵偓笑**闁瑰瓨鍨奸崵婊冾啅鏉堚晜鐣遍柛娆愬灦濡?*闁挎稑鑻鐣岀磽閺嶎剛妲梺?
   *    `applyPullProgress` 濞戞挸绉堕～顐ｇ鐠佸磭绉块梺顐㈢箲濡叉垶鎯旈敂琛″亾娑旑柕verlayColor` 濞戞梻鍠愭禍鑺ョ▔?`#00000000`闁?
   *    閻庣數鎳撶花鏌ユ儍?閻犙囶棑閸嬶絾绋夊鍥ｆ晞"闁汇垼绮鹃崕妤呭疾椤栨氨婀撮柣?`pullBgIn`闁?闁?.30闁挎稑顦粭宀勫矗閻樺弶韬柡鍫氬亾濞戞挸锕浼存儍閸曨厾鏁惧瀣仜閻ㄦ繈妫?闁稿繐顑夊▓鏇犱沪閸屾繄顦伴悹鎰剁祷閳?
   *    闁活潿鍔嶉崺娑氣偓鍦仦缁佸瓨绋婇悢琛♀偓妯兼媼閵堝牏绠栭弶鈺傜懁缁旀挳鎮欓惂鍝ョ獥"闁哄啰濮烽弲顐﹀礉閵娧勬毎鐎殿喒鍋撳┑顔碱儎缁楀寮伴鐐╁亾韫囨梹顫栭柣?闁?
   */
  private morphOpacityValue(): number {
    // 闁?闁煎浜ｉ惁澶婎嚗閼恒儳鍨奸柨娑欒壘婵晠鎮界紒妯诲焸闂傚倹鎸抽埀顒佸姇閹舵岸宕氶柨瀣厐閻犲洨绮弳鐔兼晬閸繄鐛﹂柡宥呮搐閸櫻囨儓閳ь剟寮捄铏规殜缂佹柨顑呴崺?return闁挎稑鐭傚ù鍌氼嚕閳ь剟鏌ㄩ埀顒勬晬婢跺牃鍋?
    //   闁衡偓閹勮含閺夆晜鐟╅崳鐑藉及椤栨碍绀堝☉鎾跺劋濠€浼村礄閼恒儲娈?*婵絽绻愰幎姘舵焾閸婄噥娼堕悹瀣暟閺?*闁挎稑濂旂粭鏍礃濞嗘垶鐣遍柡鍕靛灟鐞氳鲸绋夐鍛嫳濡?`@Local` 閻庢稒顨嗛宀勬晬?
    //   濞戞挸楠告慨鈺呮偨閼姐倕笑闁诡兛绀侀悾顒勫礂閵婏附锟ラ柛蹇曨劜缁辨瑧鐥姘锭閻犲洣绱槐姘跺Υ閸屾粍鏆忛柟鏉戝槻濠€顏堝礉閵娧勬毎**缂備焦鎸诲顐ｇ▕鐎ｎ亝鍊?*閻犲洩顕ч崺宀勬儍閸曨偅鐨戦柡鍕靛灡閺佸湱浜告ィ鍐ㄤ簼濞戞挴鍋撻柛鎺曞吹濞堟垿宕愮粭琛″亾?
    this.refreshDiagText();
    // 闁?缂備焦锚閸╂姊婚…鎺旂閻?`introPaintReady`闁挎稑顧€缁辨媽銇愰姀鐘茬秮鐎殿喒鍋撳┑顔碱儎缁狅綁宕滃鍡樻濡炪倕鍚€缁楀鎮芥导娆戠闂侇剙鐏濋崢銈夋焽?1~2 閻㈩垎鍥紡闁告垵鎼悾顒勫极鐎涙ɑ灏￠柡鈧ィ鍐︹偓澶愬Υ?
    // 闁宠法濯寸粭?濞戞挶鍊栧?*闊洤鎳橀妴蹇涘绩閹规劦鏀?*闁汇劌瀚崕蹇涘礃绾板绀勯柛姘剧畱閸垳浜告潏銊π?闁圭虎鍘介弬渚€鎮惧畝鍕〃闁瑰灚鎸风粭澶婎嚕閳?闁挎稑顧€缁?
    //   1. 鐎规瓕灏欑划锟犳媰閹存帞绉撮柨娑樼墢濞村鎷?OPEN闁挎稑顦埀顒佹煛閳?闁哄啰濮鹃鎴︽⒒閵婏附笑濞寸姭鍋撳☉鏂跨墢婵悂骞€娓氬﹦绀夐梻鍫熺懄椤掓盯骞€娴ｉ顏辩€垫澘顑堥々锕傛偨娴兼瑧骞?
    //   2. 闁归潧顑嗙€垫艾顫㈤敐鍛含濡炵懓宕慨鈺呮晬閸粎鐟愰柟?濞戞挸顑嗘刊铏规崉閻旂顤侀柨娑橆槴閳ь剚鏌￠埀?闂侇叏绲惧顖滄崉椤栨瑧鐟濋弶?`tryStartMorphIntro` 闁汇劌瀚槐鎴︽⒒閵娿儱鐎婚柡鈧銈囩
    //      闂傚倶鍔嬬槐鐗堢▔閳ь剟鎯勯弶鎴濆綘闁活偀鍋撻柨娑樼墣缁绘牕顫㈤敐鍡樞﹀☉鎾筹梗缁旀挳鎮?闁瑰灚鎸风粭澶婎嚕閳ь剟骞橀鐔告澒闁伙絽鐭傚?闁汇劌瀚悧鎾炊閻欏懐绀嗛柕?
    if (this.expandState.morphStage === MorphStage.OPEN || this.introPaintReady ||
      (this.expandState.morphUsable && this.expandState.morphSessionDriving())) {
      return 1;
    }
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER &&
      this.expandState.morphUsable) {
      return 1;
    }
    // 闁宠棄鎳夊Σ?2026-10-16闁挎稑鐗忛崑锝夊礄缂佹ê鈪电€殿喒鍋撻柣銊ュ椤戝洦绂嶇仦钘夌９闁挎稑顧€缁?
    //   閺夆晜鐟ょ粩鏉戔枔閸偅笑"濠㈢懓鍟块惇鏉款啅闊叀绀嬮弶鈺傜懁缁斿瓨娼鎸庡闯濞存粌妫楅懜浼村矗濡湱绐楅悹鍥ㄧ箰缁辨獋morphSessionStarted`闁挎稑顧€缁辨繃鎷呴崱妤€娈ゅù锝嗘礉缁绘洖鈻介垾鍐茬闁告帗濯介幑锝夋倷?
    //   闁?閺夆晜鏌ㄥú?0闁挎稑鐗婇弳锝嗐亜閸忓摜鐟濋柣顫串缁辨岸鏁嶇仦鎯х殹濞?闁圭鍊藉ù鍥焽?1~2 閻㈩垎鍥紡闁告垵鎼悾顒勫极鐎涙ɑ灏￠柡鈧ィ鍐︹偓?闁?
    //   闁宠法濯寸粭?闁告搩鍨紞鏃堟偨椤帞绀勭€规瓕灏欓悡锟犲Υ娴ｇ懓澶嶉柛娆愵殣缁辨岸鏁嶅宕囩闁告垹濮撮幎姘舵煂?*濠㈢懓鍟块惇浼存儍閸曨偄甯楀ǎ鍥ｅ墲娴煎懘宕楃€ｎ喗鐣烽悘鐐插亰缁辨獋MorphMetaBridge`闁挎稑顦崇换鏇㈠捶閵娧勬毎**
    //     闁挎稑鐗嗛悾鐘诲捶閵娧呭炊闁告瑱绲藉妤呭冀閸ワ妇鐟愰柕鍡曟缁楀宕ラ崘鈺傛嫳濡炪倗鏁稿▓?opacity闁挎稑顦崳?閻忕偛绻嬬粭鍌涘濮橆厽绠掑☉鎾亾閻炴稑鏈悺鏇㈠触?婵繂鏈晶婊堝礂閸粌鐦ㄩ柣顐熷亾闁?
    //     閺夆晜鐟﹀Σ鎼佸籍閻樺灚娅曢柛姘湰閻庮垶鎯冮崟顐ュ煂闁绘顔愮槐娆戔偓鐟板暟濞?`floatingMeta` 濞戞梻鍠庡﹢顏堝箻椤撶喐鏉瑰銈呭悁缁狅絾寰勯弽鐢电闁?*濞戞挸绉撮崯鈧柛娆欑畱娴犳稓鎮伴妷銈囶伈**闁?
    return 0;
  }

  /**
   * 鐟滆埇鍨硅ぐ澶愬嫉閻斿吋锛?闁煎啿鏈▍娆撳极閺夋垹婀?闁汇劌瀚粭澶愭焻韫囨梹顫栭幖杈捐缁辨瑩妫冨▎鎰靛壘闁诡兛鐒︽禍?1闁挎稑顦埀?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁绘挆鍕￠柡鍐Х閺?`pullBgOpacity`**闁挎稑濂旈幈銊╂偨閵婏箑鐓曢悗鍦仦缁佹挳濡寸仦鐐啊闁衡偓閹勭彜閻忕偞娲栫槐鎴炴交濡粯笑闁煎啿鏈▍娆撳礂閵娿儳娼岄柕鍡楃▌缁?
   *
   * ## 闁哄啰濮烽弲顐︽儍閸曨偄鏂х€殿喖楠忕槐娆戔偓娑欘殙婵☆參鎯嶆笟鈧埀顒佸姈濞碱垳鎷犵拠鎻掓瘔闁哄鍎冲▓鎴︽晬?
   *
   * ```
   *   PULL_BG_FLOOR = 0.04          wujie.pa:179978-179979  (fldai 4.0e-2)
   *   PULL_BG_IN_END = 0.30         wujie.pa:179980-179981  (fldai 3.0e-1)
   *
   *   pullPaintable = pullGeomReady && !morphSquashing      wujie.pa:176560-176579
   *   pullBgIn      = clamp(effT / PULL_BG_IN_END)          wujie.pa:176295-176326
   *                   // effT = 鐟滆埇鍨硅ぐ澶嬬▔?? morphT : 1  闁?闂傚牊鐟﹂娑㈠箑娴ｉ€涜埅 1
   *   pullBgOpacity = !pullPaintable ? 0
   *                                 : PULL_BG_FLOOR + pullBgIn 閼?(1 闁?PULL_BG_FLOOR)
   *                                                          wujie.pa:176331-176372
   * ```
   *
   * ## 闁宠法濯寸粭宥夊煣閻欏懐鐟?闁哄牜鍓濋悿?*閻犱降鍨洪婊勭▔閳ь剚寰勯崟顒€鐏夐悹鍥嚙瀵姤绂嶉崱娆愮暠闁哄鐒﹂埀?*闁挎稑鐗嗛崺鍡涘礃瀹ュ洤寮鹃柣顐熷亾闁哄唲鍕殘闂佹彃锕ラ弫濂稿炊閻愭彃绠甸柨?
   *
   * 闁瑰瓨鍨垫晶鐘崇▔閳ь剟鎮ч崼鐔肺?`pullBgOpacity` 閻犲洨绮崹?闁绘劗鎳撻崵顔句沪閺囩偟纾婚柡?`pullPaintable()` 濞戞挸鎼禍?闁?闁煎啿鏈▍娆愮▔瀹ュ洦鏆?闁?
   * 妤犵偠鍩栧畵浣割潰閵堝牜鍞ㄩ柡鍫墮閸ら亶寮弶鎸庤含闂傚牏鍋犵粣锟犲箥鐎ｎ亣鍩岄柛娆惿戝?`return 0`闁?*閻犲洩顕у鑺ョ?*闁?
   *
   * * `jnez L` 闁汇劌瀚銏＄▕婢跺笑"**闁哄鈧弶顐藉☉鎾虫惈娴?*闁哄啯鍎奸悜?闁挎稑鐗嗛崙锟犳偨?`playerSwiperGapOf` 闂侇叏绲炬俊鍝ヤ焊閸濆嫮鎽嶉梺钘夘槹椤掓挳鏁嶆径娑氬耿
   * * `lda pullPaintable(); isfalse; jnez L2` 闁?**`pullPaintable() === true` 闁哄啯鍎奸悜锕傚礆?L2**闁?
   *   闁?L2 闁归潧绉靛Σ?缂?`PULL_BG_FLOOR + pullBgIn 閼?0.96`"闂侇叏绲肩粩鎾绩椤栥倗骞?
   * * 闁告瑯浜濆﹢?`pullPaintable()` 濞戞挸鎼禍锝夊箥?`ldai 0x0; return`闁?
   *
   * 闁?`pullPaintable = pullGeomReady && !morphSquashing`闁挎稑娼塵orphSquashing` 闁告瑯浜滃﹢?
   * 闁稿繑濞婂Λ鎾媰閹存帞绉撮梺顓ㄧ导缁斿鎷嬮悧鍫濈毃闁告ê顑嗗﹢锟犳⒒缂堢姾绀嬮柣顏嗗櫐缁辨岸鍩?**濞戞挸锕ユ刊?闁绘劗鎳撻崵顔句沪閺囩偟纾婚柛蹇嬪妿閳诲吋绋夐搹瑙勫焸** 闁?**闁煎啿鏈▍娆撳礂閵娧€鏌ら梺顔炬櫕閺?*闁?
   * 闁?闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳濡?*闁哄啰濮烽弲顐﹀礉閵娧勬毎閺夆晛娲ㄩ埢濂稿嫉婢跺骸鍓归柡鍜佸灣濞堟垿鏁嶉崼锝呮閻忓繑鍨甸悿鍕嫉閻戞ɑ笑閺夆晜鐟﹂悧閬嶆晬?*闁靛棗绉甸婊堝及椤栨繄绠归柡澶涚磿鐎氼厾绮╃€ｎ厾妲堥柟璇″枔閳?
   *
   * ## 缂備焦鎹侀鎴︽晬閸喐鎷卞ù鐘虫尰濡惭呬焊閸曞墎绀?
   *
   * | 闁革妇鍎ゅ▍?| 缂備焦鎸婚悘?|
   * | --- | --- |
   * | 闂傚牊鐟﹂娑㈠箑?| 1 |
   * | 鐟滆埇鍨硅ぐ澶嬬▔?| `PULL_BG_FLOOR + pullBgIn 閼?(1 闁?PULL_BG_FLOOR)` = `0.04 闁?1`闁挎稑娼塸ullIn 闁?0.30` 闁告艾瀛╂禍?1闁?|
   * | 闁解偓閹存帞绉撮柟鎼炲€曠敮鍥晬閸у埓orphSquashing`闁?| 0闁挎稑鐗婂Λ銈夋偩瀹€鍕簼濞戞挴鍋撴俊妤嬬导缁″啯绋夐埀顒勫冀閸戙倗绀?|
   *
   * 闁宠法濯寸粭?闁哄唲鍕殘闂佹彃锕崳?**濞戞挸绉烽々?*闁绘挆鍕?`clamp(p/0.30)`"闂侇叏绲惧顖滅磼閹捐鍟?*鐎规瓕寮撶紞鏃€鎯?*闁挎稒鑹鹃悾鐘诲箯閸涱厾濡囬柣銊ュ濡?闁煎啿鏈▍娆戜沪閸屾碍韬?
   * **閻炴凹鍋夐ˉ鍡涘礈椤忓棙鐣遍悘蹇撶箳閻涖儵宕ｉ敐澶婃**闁?0% 閻忓繗椴稿褎绋夊澶嗗亾韫囨梹顫?闁?缂佹劖顨呰ぐ娑㈡煂鐏炶偐顏遍柡浣规綑濞尖剝顪€?闁靛棗鍊介埀顒€鐭侀崕妤呭疾椤栨氨婀撮柣婊勬緲濠€顏堝及?*闁革负鍔忛ˉ鍡涘礈椤忓嫷鍟囬柛锝冨妼閸炴挳鏌?*
   * 闁挎稑鐓?0 闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨偆婀寸紒鐙欏秶绀嗛柨娑樼焸閸嬪懏绋夐鍕煂闁绘ɑ婀圭粭澶屸偓娑櫭﹢顏呯閸℃劏鍋?
   *
   * 闁宠法濯寸粭?**2026-10-16 濞存粌鏈鑲╂媼閵忊槅鍔€闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鐬奸崑锝夊礄缂佹ê鈪电€殿喒鍋?闁绘劗鎳撻崵顕€宕楅幎鑺ワ紨/缂侇垵宕电划鐑樻交閺傛寧绀€閺夆晜蓱濡茬鈻介埄鍐╃畳闁靛棗绋勭槐?*闁?
   *   濞戞挸顑夊浼存焽閿濆懎缍?`if (this.expandState.morphSquashY !== 1) return 0;` **闁哄嫷鍨堕弫濠囨儍?* 闁炽儲鏌￠埀?
   *   閻庣懓鍟﹢浼村箛韫囨梹笑鐟?闁解偓閹存帞绉撮柟鎼炲€曠敮?闁挎稑鐗婂Λ銈夋偩?`morphSquashing`闁挎稑顧€缁辨繃鎷?`morphSquashY` 闁?*闁绘劗鎳撻崵?閺夆晜鏌ㄥú?*閺夆晜鐟﹀顖滄崉椤栨瑧鐟?
   *   濞戞梻鍠嶇槐鐗堢▔瀹ュ洨鎼煎ù?1闁挎稑鐗嗛崣褔姊婚鈩冨劙濞达絽绉归崑鍛▔閳ь剛鎷?110ms+320ms 闁汇劌瀚亸瀣储鐎ｅ墎绀嗛柨娑樺缁剟寮伴娑欐闁哄銈囩唴闁汇劌瀚崕妤呭疾椤栨繍娼堕柛妯侯儐閸?0
   *   闁?闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣銊ュ濡?**闁告瑯浜濆﹢浣圭▔婵犲啫顎欓梺顓ㄧ稻濞碱垶寮垫径搴″壒闁?*"闁?
   *   闁?闁绘粍婢樺﹢顏堝绩鐟欏嫬鐏囬柨?*闁告瑯浜ｉ々锕傚嫉婢跺﹨鍩岄柛娆愶公缁辨繈鎳楃仦鐐彲閻忓繗椴哥€?`pullBgIn` 濞戞挸锕ョ拹浼村礂?*闁挎稑濂旂粭澶愬礃瀹ュ拋鍤?Drive 闁瑰瓨鐗楃亸瀣储鐎ｎ亙绮甸柣妤勵潐閻ｂ晠宕氶妶鍡樼劷闁?
   *     闁煎啿鏈▍娆忣啅閼碱剛鐥呴悶姘煎亜椤旀劙宕抽妸顭戞⒖闁告搩浜风槐娆愭倕90闁挎稑顧€缁辨繈骞嶉埀顒佺?鐟滆埇鍨硅ぐ澶愬籍閳哄倹鍩傞柡浣规綑閻?閺夆晜鐟ら柌婊勩亜閹规劖顎氶柡鍫墲闂娾晜绋婇悢鍓佺憹閻庢稒锚濠€顏呯閸℃劏鍋?
   *
   * 闁宠法濯寸粭?閻庣懓鍟幃鎾诲籍閸撲緡鍚€闁活偀鍋撻柨娑欒壘閻忔碍鎯旈弴鐐垫勾闁靛棔绀佽ぐ鍥冀閻ゎ垰顥忛悘鐐插€堕埀顑胯兌缂嶅寮介悡搴ｆ勾闁靛棔绀佺欢鐐哄触閹寸偞顔傞悷?闁炽儲鏌￠埀?闁衡偓閻熸壆鏆婄紒娑橆槷缁剟寮ㄧ涵鍛闁搞儲绋戦惇浼村Υ?
   * 闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdBgOpacity'`
   * @returns 0..1闁挎稑鐗撳銈咁潰閵忊檧鍋?= 1闁?
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

  /** 闁哄啰濮烽弲?`PULL_BG_FLOOR`闁挎稑娼墂ujie.pa:179978-179979`闁挎稑鐣璮ldai 4.0e-2`闁挎稑顦埀?*/
  private static readonly PULL_BG_FLOOR: number = 0.04;

  /** 闁哄啰濮烽弲?`PULL_BG_IN_END`闁挎稑娼墂ujie.pa:179980-179981`闁挎稑鐣璮ldai 3.0e-1`闁挎稑顦埀?*/
  private static readonly PULL_BG_IN_END: number = 0.30;

  /**
   * @returns 闁哄啰濮烽弲?`pullBgIn() = clamp(effT / PULL_BG_IN_END)`闁挎稑娼墂ujie.pa:176295-176326`闁挎稑顦埀?
   *
   * `effT = 鐟滆埇鍨硅ぐ澶嬬▔?? morphT : 1` 闁?闂傚牊鐟﹂娑㈠箑娴ｉ€涜埅 1闁挎稑鐗嗗畵?`pullBgIn = 1`闁挎稑顦埀?
   * 闁宠法濯寸粭?闁哄牜鍏涚划銊╂儍?鐟滆埇鍨硅ぐ澶嬫交濞戞ê顔?閻庣數鎳撶花?`morphP`闁挎稑鐗嗛惈宥咁嚕閳?0闁? / 闁衡偓閹増宕?1闁?闁挎稑顧€缁辨繃绋夋惔銏★骏闁伙絽鐬煎▓?`morphT` 闁告艾鑻ぐ娑橆嚗閸曗斁鍋?
   */
  private pullBgIn(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    const raw: number = this.expandState.morphP / PlaybackPage.PULL_BG_IN_END;
    return raw < 0 ? 0 : (raw > 1 ? 1 : raw);
  }

  /**
   * 闁圭儤甯掗悾楣冩嚊椤忓嫬袟闁衡偓閹増宕抽柕?
   *
   * 闁?`setTimeout` 闁兼澘濂旂粭澶愬及?`setInterval`闁挎稒鑹捐ぐ褏鎲版担鍦Ж婵炲棌鈧弶鍞夊ù婊勫浮閸ｆ悂寮悧鍫濈瑩濞戞挴鍋撴繛鍡忊偓铏殤濠㈠墎鍠嶇花锟犳晬?
   * 閻㈩垱鎮傞埞妤冣偓瑙勭濡炲倿宕抽妸銈囩獥闁革负鍔戦妴澶愭椤厾鐟濋柛娆樺灥椤棝寮崜浣叉晞閺夌儐鍓ㄧ槐娆撳箻椤撶喐鏉瑰銈囨暩缁紕鏁幖浣规瘣闁哄啫鐖煎Λ鍧楀箰閸屾粍绲婚柨娑橆槶閳?
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
      // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`hideChrome()` 闁?闂傚牄鍨哄妯侯嚕閳ь剟鎯堥埀顒備焊閸欐鐟濋柡鈧?闁挎稑鐣璦bc.txt:4124-4225`闁挎稑顧€缁?
      //   闂侇叏绲肩粩鎾级閳╁啯笑 10 濞戞搩浜浼村级?flag 闁汇劌瀚悡顓犳崉椤栨稑鐏楅梺鐐嫕缁遍亶寮甸璺ㄦ尝闁汇劌瀚崹搴ㄦ煂韫囨凹娼?`auxSheetOpen` 闁汇劌瀚弫鐐烘煂?
      //   闁挎稑鐗愯ぐ宥夊础閺囨氨顏遍柡?闁?`playMenuOpen`闁挎稒鐩Σ锕傚礆?闁稿繑婀圭划顒勬偋閸喐鎷?闁?`auxSheetOpen`闁挎稑顦埀顒€鍊风悮杈ㄧ▔椤忓牆鍘撮悷鏇氱閸ㄤ粙濡?
      if (this.playMenuOpen || this.auxSheetOpen) {
        Logger.info('RzdLyricChrome',
          `hide skipped (panel open: menu=${this.playMenuOpen ? 1 : 0} aux=${this.auxSheetOpen ? 1 : 0})`);
        return;
      }
      // 婵繐绲藉﹢顏堝绩閹増宕?閻忕偞娲栫槐鎴﹀箻椤撶喐鏉归柛锝冨妽濡炲倹绋夊鍡椻叺闁?
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
   * @returns 闁硅矇鍐ㄧ厬闁告牜鍎ゅΣ鎼佸触閿曗偓瑜板弶绂?闁衡偓閹増宕抽柡?闁挎稑鐗愰崵婊堝礉閵娧€鏁勯梻鍌氬级閺佸湱鎸?+ 闁归攱鐗曟慨鈺呭绩閹増宕抽柛蹇氫含閺併倖娼诲▎搴ｎ伇闁硅泛锕Λ顒勬晬婢跺牃鍋?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*閻犱降鍨洪婊勭▔婵犱胶顏遍弶鐑嗗枤濞堟垶绋夐埀顒佺▔椤忓牊鏅╃紓浣规崄椤?闁炽儲鏌￠埀?閻庣懓鍟紞瀣籍鐠哄搫娑ч柣?`startIdle` 闁告劕鎳橀崕鎾晬鐏炲墽纭€濞存粌妫欐晶宥夊嫉婢跺海娈堕柣顫妿閸?*闁挎稑顦埀?
   *
   * ## 闁哄啰濮烽弲顐︽儍閸曨亞鐨戦悗鍦剳缁辨壆绮氬ú顏咃紳闁衡偓閹増宕?*闁告瑯浜滃﹢顏勵潰瀹€鍐Г濡炪倝娼цぐ鍌炴偨?*
   *
   * 濞戞挸锕ｇ粩瀛樻姜椤旇棄鐏夐悹鍥嚙閸?`startIdle()`闁挎稑娼塒layerPage.abc.txt:12394-12435`闁挎稑顦甸崳鐑芥焽閿濆澹曢梻鍌樺妽濡?
   * `entryAllowsAuto(this.lyricImmersive)`闁挎稑鐭侀埀?`lyricImmersive` 闁?*闁活潿鍔嶉崺娑㈠磻韫囨挶鍋?*
   * 闁挎稑娼墂ujie.pa:169823-169825`闁挎稒鐡猼his.lyricImmersive = pref.lyricImmersiveMode`闁?
   * 闁?濞存粌瀛╁Σ鎼佸礃濞嗗海鍟婇柕?*闁哄啰濮烽弲顐︽儍閸曨垱锛屽☉?鐟滅増鎸告晶鐘诲捶閵娿儲鎲垮☉鎾亾濡?闁哄啰濮撮崣?闁?閻忓繋绶氬鐗堛亜閸忓摜鐦嶅ù鍏兼皑閳规牠姊婚崣澶嬫毆閻?*闁靛棗绋勭槐?
   * 妤犵偠鍩栨俊鎼佸嫉椤掍焦鐓欐繛澶嬫礃閺備胶鈧妫勯崺?`usesPhoneSwiperLayout()`闁?
   * **闂侇叏绲奸柌婊堝箳閵婎煈鍟堥柡鍕靛灦閺佸﹪鎯?* 闁炽儲鏌￠埀?濡炪倗鏁诲浼存儍閸曨垱顎欓柛鎺撴构缁楀宕?`startIdle` 闂佹彃鐭夌槐婵嬫嚀鐏炶姤韬?*閻庣懓鍟板▓鎴澬掕箛搴ｎ伇濞戞搩浜ｉ惃鐔兼偨閵娧冧化**濞戞挸顭槐?
   *
   * | 閻犲鍟伴弫銈夋倷?| 閻庢稒顨夋俊顓㈡儘?| 闁哄鈧弶顐?|
   * | --- | --- | --- |
   * | swiper `onChange` | `abc.txt:23189-23215` | **`index === 1`闁挎稑鐗婇悺鏇犳嫚瀹ュ鈧鏁嶆径鍡楁 `startIdle()`**闁挎稒绋戦幆渚€宕?闁?`clearIdle() + showChrome()`闁?*濞戞挸绉烽幑锝囨媼閳╁啯顦?*闁?|
   * | 婵繂鐭侀惁婵嬪礌妤﹀晝鏇㈠箺閸涘﹤袦閻犙冨槻婢?| `abc.txt:6914-6932`闁挎稑娼塷nLyricInteract`闁?| 濞寸姴鎳庡﹢?*婵繂鐭侀惁婵囥亜?*濞?`!chromeHidden` 闁?`startIdle()` |
   * | 婵繂鐭侀惁婵嬪礌鏉炴壆鐟撴繝?| `abc.txt:6938-6985`闁挎稑娼塷nLyricSwipe`闁挎稑鐣璷ffsetY 闁?SWIPE_TOGGLE_VP 24`闁?| 濞寸姴鎳庡﹢?*婵繂鐭侀惁婵囥亜?*闁挎稒鐡猻howChrome() + startIdle()` |
   * | 婵炲苯顦伴煫鍫澪熼垾宕囩闁告瑦蓱濞?| `abc.txt:7766-7800` | `entryAllowsAuto(mode) && !chromeHidden && swiperProgress > 0.5` |
   *
   * 闁?**闁搞儲绋愰柌婊呮導妞嬪骸浠柛蹇嬪妼濠€顏勵潰瀹€鍐Г濡炪倗顣槐婵嬫嚀鐏炶棄鐎奸柛鎺撴緲閻ㄦ繈妫冮姀銈冣偓澶愭焽閿濆嫮顏遍柡鈧娑櫺﹂柡鍕劤缁憋繝鎯?`clearIdle()`**
   *   闁?**闁哄啰濮烽弲顐﹀捶閵娿儳娈遍梻鍫涘灲閵嗗绋夊鍕獥缂佸本妞藉Λ浠嬪绩閹増宕抽柟璨夊啫鐓戦柛?*闁?
   *   闁?闁兼澘濂旂粭鏍ㄦ交濞嗘劦鍔€闁哄嫷鍨抽弫銈夊箣闁垮锛嶉柛蹇撶墛婵倝鎯冮崟顖氫簼濞戞挴鍋撻柡澶嗘缁变即濡寸仦鐐畳闁?*闁圭虎鍘介弬浣广亜閻㈠壊娴曞?*濞戞挸顑嗛弻鐔煎礄閻橀亶鍤嬮柟绋款樀閹歌櫕绋婇悢鍓佺獥闂傚懏鍔樺Λ宀勫Υ瀹ヤ讲鍋撻弬琛″亾?
   *     閻忓繋绶氬鐗堛亜閻㈠憡顓洪柦妯虹箲濡?*闁瑰瓨鍨冲?*閻㈩垽绠掔换姗€寮堕妷褎鐣遍悶娑樺鐠愮喖鏁嶇仦鑲╃憹闁哄嫷鍨卞Λ銈夋偩瀹€鈧▓鎴﹀Υ?
   *
   * ## 闁绘粍婢樺﹢顏堟儍閸曨偄鐏查柟?
   * 闁归潧顑嗗┃鈧?Swiper 閻㈩垰鍟惇顒勬晬閸繄娈遍梻鍫涘灲閵?婵繂鐭侀惁婵囥亜娴ｅ啰绠瑰┑鍌涱殣缁?*濞?*闁稿绮屽﹢顏勵潰瀹€鍐Г濡炪倗鍋ｉ埀?
   * 闁宠法濯寸粭?閺夆晜鐟ょ粭灞剧▔婵犱胶顏遍弶鐑嗗枙缁狅綁宕滃鍥ㄧ暠闁告劖鐟︾涵鑸电▔閳ь剟鎳涙潏鍓х`WIDTH_SM && 婵繂鐭侀惁婵囥亜缁€浼存晬婢舵稓绀夌€瑰壊鍠栭崺鍡涘矗椤忓懏笑閻庣妫勭€规娊宕氶妶鍡楃ウ闁瑰箍鍨洪崹姘?
   *   `usesPhoneSwiperLayout()`闁挎稑鐗呯粭?`Swiper` 闁活亞鍠庨悿鍕及椤栨碍鍎婂ù锝堟硶閺併倝宕ョ仦鑲╊伇闁告瑱绲界欢鐐烘晬鐏炵偓绾痪顓у墾缁辨岸濡?
   * 闁宠法濯寸粭?闁哄牜鍓熷Λ顒勫及?闁煎浜滄慨鈺呭绩閹増宕?+ 闁归攱鐗曟慨鈺呭绩閹増宕?闁稿繗浜弫銈夋儍?闁炽儲鏌￠埀?濞戞挶鍊涢埀顒€鎳忕€垫粓寮悩鍨珪濞?*闂侇喛妫勮ぐ褔宕烽妸锔炬憙閻犲洤绉归妴?*閻犙嗘腹缂嶆棃鎮?
   *   闁挎稑娼塀arCollapse` 闁圭鍊稿﹢顏勵潰瀹€鍐Г濡炪倗鏁婚崑鍛附濡や礁浠橀柛鎺曟硾鐏忣垱绋夋繝蹇曠闁?
   */
  private canHideLyricChrome(): boolean {
    return this.usesPhoneSwiperLayout() &&
      this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
  }

  private hideLyricChrome(): void {
    if (!this.canHideLyricChrome() || this.chromeCollapsed) {
      return;
    }
    // 闁?闁告艾濂旂粩鎾级閳ュ磭鏆撻柛妤婂亾缁辨瑧鎲?`scheduleChromeAutoHide` 闂佹彃鐬煎▓鎴犳嫚鐎涙ɑ顫栭柨娑橆檧缁变即妫冮姀鈩冪凡鐎殿喒鍋撻柣顐熷亾閻忓繐褰夌粭澶愬绩闊祴鍋?
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
   * Swiper 闁瑰箍鍨介妴澶愬籍閸撲焦鐣遍柟璨夊啫鐓戦柛鏍劋閺佸湱浜?闁炽儲鏌￠埀?**闁绘挆鍕剶闁哄啰濮烽弲顐︽焽閿濆嫰鍤?`onChange` 娴?闁汇劌瀚伴埀顒佸姇閻⊙呯磼閹惧鈧?*
   * 闁挎稑娼塤recover/logic-src/PlayerPage.abc.txt:23189-23215`闁挎稑顦埀?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑娼沷al 闁衡偓鐠鸿櫣鍟插璺虹У閻楁娊鏁?*闁搞儳鍋涚敮顐ｆ叏鐎ｎ亞鎽熼柤鍝勫€婚悥婊呮兜椤旀鍚?*闁挎稑鑻崵顓熷緞?
   *   `_recover/disasm/wujie.pa:190080-190111`闁挎稑鑻畵?`PlayerPage.@34*^1*#^1`闁挎稑顧€缁?
   * ```ts
   *   onChange(index) {                                  // a3 = index
   *     const L = 1;                                     // 190081-190082闁? SWIPER_INDEX_LYRIC闁?
   *     if (index === L) { this.startIdle(); }            // 190083-190089  闁?婵繂鐭侀惁婵囥亜绾板绐楅悹褏鏌夐鎼佸籍?
   *     else { this.clearIdle(); this.showChrome(); }     // 190091-190099  闁?閻忓繋绶氬鐗堛亜绾板绐楅柛瀣矎椤撴悂寮?+ **闁哄嫭鍎崇槐锟犲船閵堝懎姣?*
   *     this.atLyricScreen = (index === L);               // 190100-190105
   *     this.syncKeepScreenOn();                          // 190106-190109
   *   }
   * ```
   * 闁?**缂佸本妞藉Λ鐣屾媼閳╁啯顦ч柛娆樹簻濠€顏勵潰瀹€鍐Г濡炪倓绲婚幑?*閺夆晜鐟ょ粩鎾倷閻у摜绀夐柡鍕靛灟缁楀倸銆掗崫銉︾暠**闁哄嫭鍎崇槐锟犲礆閸℃ɑ鏆?*闁挎稑鐗呯粭澶愬及椤栨稑鐏夊ù鐙€鍓氱敮褰掑棘椤撶姵鐣遍柨娑橆槴濠€?
   *    闁炽儲鏌￠埀?goal 缂?4 闁哄鎵冲亾瀹€鈧埞鏍⒒閼奸鍚€闁哄啳缈伴埀顒€绉撮崺灞筋潰?*闁哄牆顦板畵渚€宕ｉ娑氬弨**闁挎稑濂旂粭澶愭閳ь剛鎲版担绋挎櫃闁哄秵鎮堕埀?
   *    闁挎稑鐗嗚ぐ鐔兼晬濮濇tartIdle` 闁汇劌瀚鍌炴⒐閸喚鍩楅梺?`IDLE_MS` 闁告瑯浜滃﹢顏嗘嫚閵夈儱姣愰柡浣峰嵆閸ｇ兘宕欓搹鐟扮疀濞戞挴鍋撴繛鍡忔缁?
   *      `wujie.pa:179903-179985`闁挎稒绋掑﹢鐗堢閹炬剚鍤犻幖?`PlaybackPage.CHROME_AUTO_HIDE_MS = 5000`闁靛棗鍋婄槐?
   *
   * 闁宠法濯寸粭?闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉柡鍕靛灡濡倝寮堕垾鍙夘偨 `touchChrome()`闁? 闁哥偑鍊曢崵?**+** 閻犙呮焿椤撴悂寮拋鍦闁挎稑鑻崯鈧柛锔哄姂濞碱亜顫㈠畝鍐Г濡炪倓绲昏棢濞戞挴鍋撻柛?
   *   `stopChromeAutoHide()`闁靛棗鍊块崑鍛村冀瀹勭増韬?*闁告帒娲ら崺宀€浜告笟鈧鐗堛亜?*闁哄啳鍩栧Σ?闁稿繐鐗愰幑锝囨媼閳╁啯顦ч柛鎰Т娴犵娀骞?闁?
   *   闁告垟鍋撻柡浣哥墛閻忓鎼归悾灞藉Ё濞戞梻鍠庨顕€鏁嶇仦鑲╃ɑ濞戞挸瀛╁Λ銈夋偩?闂侇叏缍侀崳鐑藉冀鐟欏嫭鎷卞☉鎾崇Т閺佹粓宕?vs 閺夆晜鐟╅崳閿嬪濮橆剚鏆呴柛?闁汇劌瀚Ο濠囧礆椤愩儺娼堕柟鎯邦潐鐢偓濞?闁炽儲鏌￠埀?
   *   闁哄啰濮烽弲顐﹀礆閸パ冪厒閻忓繋绶氬鐗堛亜閸偅笑**闁哄嫭鍎崇槐锟犲船閵堝懎姣?*闁挎稑鐗忛弫銈夊箣閾氬倻鐭ゆ慨婵嗙焷閻︽繃銇勯崹顐ゆ嫧闁搞儳鍋炲鐢稿籍閼搁潧浠橀柛鎺曟硾鐏忣垱绋夐埀顒傗偓瑙勭濡插憡绂嶉鐐暠闁挎稑顧€缁?
   *   閺夆晜鐟ょ粩鎾级閳╁啫鐏夊ù鐙€鍓涢～顐㈩啅瑜岀弧鍐偓鐢垫缁辨繃鎷?*闁告柣鍔嶅┃鈧☉鎾崇Т閹?*闁挎稑濂旂粭鏍焊閹存粎鍟?婵繂鐭侀惁婵囥亜閻㈢浜濆☉鎾亾闁衡偓椤栨瑧鐟濋柛鐐€曢崵?闁?
   *
   * 闁宠法濯寸粭?闁告瑱闄勫﹢?*闁哄牆顦伴崜浼村绩閸撲胶宕?*闁挎稒纰嶉崹婊勭椤掑嫬浜濆☉鎾亾闁衡偓椤栫偛娅″鑸电煯缁旀挳鏌?`canHideLyricChrome()`
   *   闁? `usesPhoneSwiperLayout() && 闁稿绮屽﹢顏勵潰瀹€鍐Г濡炪倗銇愰柨娑橆槴閸?閻庣妫勯惈?闂傚牄鍨哄姗€鏌囬敐鍕拡闁衡偓椤栨瑧鐟濋悹褏鏌夐鎼佸籍闊祴鍋?
   *   濞戞挸锕ラ悥?`startIdle` 闁煎浜滅换浣规交濡粯绠掓繛灞筋槹闊牆螣閳ュ磭纭€缂佹稑顦崬鎾焾閵娾晜顦╅柨娑樼墛濠€鐗堢閹炬剚鍤犻幖?`entryAllowsAuto` 闂侇叏绲惧顖炴晬婢跺牃鍋?
   *
   * @param index 闁哄倹澹嗗▓鎴炪亜閸忓摜鐟撻柡宥呮祫缁? = 閻忓繋绶氬鐗堛亜绾板绀? = 婵繂鐭侀惁婵囥亜绾板绀?
   */
  private onSwiperIndexChanged(index: number): void {
    if (index === PlaybackPage.SWIPER_INDEX_LYRIC) {
      // startIdle闁挎稒鐡猻cheduleChromeAutoHide()` 闁告劕鎳橀崕鎾嚊椤忓嫮鏁?`canHideLyricChrome()` 濞戞挸绉甸崹姘辩博鐎ｎ亝鐨戝☉鎾崇У閺?
      this.scheduleChromeAutoHide();
      return;
    }
    this.stopChromeAutoHide();
    this.showChrome();
  }

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`BarCollapse`闁挎稑顧€缁?*闁归攱鐗曟慨鈺呭箳瑜嶉崺妤呭级閳╁啯鏆悹?/ 閻忕偞娲栫槐?*闁?
   *
   * 闁哄啰濮烽弲顐︽儍閸曨剙顤侀柛鏃囨硶婵悂骞€娴ｈ绨氶柨娑樻綁design/src/main/ets/logic/BarCollapse.ets`闁挎稑鑻悺褔鎳為崒婊呭灣
   * `wujie.pa:83706-84140`闁挎稑顦崙锟犳焻閹邦厽钂嬮弶鐑嗗墮閸熸捇宕?`common/musicbasic/.../model/BarCollapse.ets`
   * 闁挎稑鐗嗛幆?`THRESHOLD = 1.5`闁靛棔娴囬柊閬嶅触閹达附鏁氶悗瑙勫搸閳ь兛姊梤un` 缂侀硸鍨宠ⅶ闁靛棔鑳跺ú浼村冀閸ワ妇顏遍柤椋庣節缁楀宕濋妸銈囩▕闁?*250ms 闁煎搫鍊圭粊?*闁挎稑顦埀?
   * 闁哄牜鍓氶弻鐔封枖閺囩偛娑ч柛瀣煯鐞氳鲸绂掗張鐢电殤闁?*闁硅泛锕ㄨ闁逛粙鏅茬花銊︾鐠虹儤婢撻弶鈺傜☉楠?* + **闁圭顦悾鐘虫交閺傛寧绀€闁汇劌瀚慨鈺傛媴濠婂牃鏀抽柛鏂诲妽閺佸湱鎸?閻忕偞娲栫槐?*闁?
   *
   * 閻犲浂鍘虹粻鐔兼晬閸垹寮鹃柟璺哄閹鎯冮崟顕呮斀濞戞挾灏ㄧ槐姘舵晬?
   * ```
   *   鐠?缂侀箖娼ч幃婊勭▔鐎ｎ偄顎欑紒槌栧灥椤?闁?闁?.5vp 闁?COLLAPSE闁挎稑鐗婄敮鍫曞礆鐠哄搫闅橀柡鈧幆鐗堝闯闁?
   *   鐠?缂侀箖娼ч幃婊勭▔婵犲啫鑵圭紒槌栧灥椤?闁?+1.5vp 闁?EXPAND  闁挎稑鐗婄敮鍫曞礆鐠哄搫闅橀悘鐐存礀缁辨垿鏁?
   *   鐠?婵☆垼浜滈幃婊堟煥娴ｅ摜鏆?闁?闁轰胶绻濈憰鍡涘箥鐎ｎ亜鈼㈤煫鍥╂櫕閺嗘劙鏁嶉崼婊呯憹濞村吋鑹鹃幏鏉款潰瀹€鍐Г婵☆垼浜濈划锕傚箥閹惧浠搁柨?
   * ```
   * 闁宠法濯寸粭?闁告柣鍔庨弫鎯р柦鐠恒劍鏆忛柡鍫墴閵嗗寮姀鈩冪畳闁汇劌瀚伴崑鍛▔閳ь剚绺藉Δ瀣`chromeCollapsed` + `lyricChromeProgress`闁?40ms `EaseOut`闁挎稑顧€缁?
   *   濞戞挸姘﹂崵婊堝礉閵婏附鏆悹褍鍤栫槐?s 缂佸本妞藉Λ浠嬫晬?*闁稿繗浜弫銈夊触鐏炶偐顏遍柡澹溿倗鐔呯€?* 闁?濞戞挶鍊楅～鎺楀礂閵夈儱缍撻悷娆忓€归崝鍛▔閳ь剟鎳涘ǎ顑藉亾?
   * 闁宠法濯寸粭?闁衡偓閹増宕抽梻鍌樺妽闁劑鎮?`canHideLyricChrome()` 闁炽儲鏌￠埀?**濞戞挸姘﹂崵婊堝礉閵婏附鏆悹褎鐏氶埀顑跨劍鐎氬宕濋妸锔芥毆閻犙冨槻閹挻绋夐埀顒勫箮婵犲洦锛?*
   *   闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`startIdle` 闁告艾楠搁悾鐘差啅閸欏鏉归悗纭呮閸?闁归潧顑嗗┃鈧?Swiper 閻㈩垰鍟惇?闁挎稑鑻幆鍫焊娓氣偓濞肩増銇勭喊澶岀閻熸瑤绶氶崑鍛▔椤忓懏鐓欐繛澶嬫礈濞堟垵鈻旈妸鈺佹珵闁挎稑顦埀?
   *   闁圭鍋撳ù鐘劙缁楀瀵煎顒€姣夐柣?闁煎浜滄慨鈺呮嚄閼恒儲鏆柕鍡曠劍鐎氬宕濋妸銈囩憹闁煎疇濮ら弫?閺夆晜鐟ч～鎺撶▔瀹ュ嫮顏遍柤閿嬬暘閳?
   * @param event 闁硅矇鍐ㄧ厬闁告牕鎼鎰板闯閵娿倗鐟愰柣銊ュ琚濋柟浠嬫櫜缁ㄣ劍绂?
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
      // 閻忕偞娲栫槐?= 闁哄牜鍓熼妴澶愬籍閵忊剝绠掗柣?闁哥偑鍊曢崵顓㈠箳瑜嶉崺妤呭礌?闁挎稑娼塼ouchChrome()` 闂佹彃鐭傞崑鍛枔?240ms 闁告柣鍔庨弫?+ 闂佹彃绉堕悿鍡欑矚濞差亝锛濋悹浣插墲濡炲倿鏁?
      this.touchChrome();
    }
  }

  /** 闁稿绮嶇敮鈧柤濂変簻婵晠寮ㄩ幆鐗堝闯閻犱讲鍓濆鍌炴晬閸儯鈧妫冮姀鐘茬セ閺夌偛顫曢埀顑跨缁辨垶鎱ㄧ€ｎ偅鏆悹褔鏀遍幐閬嶅绩閹勭彜闁哄啯鍎奸惃鐔兼偨椤帞绀嗛柕?*/
  private stopChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
  }

  /**
   * 闁绘挆鍕剶闁哄啰濮烽弲?`PlayerPage.onLyricInteract()`闁挎稑娼塤recover/logic-src/PlayerPage.abc.txt:6914-6932`闁挎稑顧€缁?
   *
   * ```ts
   *   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
   * ```
   * 闁圭鍊藉ù鍥倷閻熺増韬柛姘湰閺嬪啯绂?`190116-190130`闁挎稒鑹捐ぐ褔寮?**`TouchType.Down`** 閻犲鍟悾鐘诲Υ?
   *
   * 闁宠法濯寸粭?濞戞挶鍊撻柌?濞戞挸绉烽々锕傚箹閻愮儤鏅?闁?
   *   鐠?閻?*闁告瑯浜ｉ幑锝囨媼閳╁啯顦?*闁挎稑娼塻tartIdle`闁挎稑顧€缁?*濞戞挸绉撮弫婊堝礄?*闁硅矇鍐ㄧ厬闁?闁?閺夆晜鐟╅崳鐑芥偨?`scheduleChromeAutoHide()`
   *     闁?*濞戞挸绉靛Σ?* `touchChrome()`闁挎稑鐗嗛幃妤呮嚀?= `showChrome()` + 閻犙呮焿椤撴悂寮拋鍦闁哄嫷鍨拌ぐ鐔哥▔閳ь剟寮堕檱閻偓绋夋繝鍕暠缂備礁瀚幃搴ㄦ晬婢跺牃鍋?
   *   鐠?闁哄鈧弶顐介柡?`!chromeHidden`闁挎稑鐗嗛崙锛勭磼韫囨梹鏆悹褔鏀卞?*濞戞挸绉烽幑?*閻犱讲鍓濆鍌炴晬婢跺棗娅?閺夆晜鐟╅崳椋庘偓鐢垫嚀缁?`!chromeCollapsed`闁?
   */
  private onLyricInteract(): void {
    if (this.chromeCollapsed) {
      return;
    }
    this.scheduleChromeAutoHide();
  }

  /**
   * 濠㈢懓鍟块惇浼村箯閿曗偓閸╁瞼鍖栭懡銈囧煚閺夆晜鏌ㄥú鏍晬閸綆娲ｆ慨鐟板€搁崣褔姊婚鐔稿啊闁衡偓妤ｅ啨鈧鏁嶆径鍡楁櫔 闁圭虎鍘介弫鍦導瀹勬澘袟闁活澀绱槐婵囩▔瀹ュ牜娲ｉ柣鈺佺摠鐢潙鈽夐崼婵勪杭闁?
   *
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗嗗ú鏍焻閳ь剟宕ユ惔銊ユ闁稿鐔槐姘舵晬?*闁告帞濮电敮鈧柛妯煎枑濞肩敻鏌囬敐鍛稏 `setTimeout(0)`**闁?
   *   鐟滅増鎸搁崟楣冩儍閸曨剚鏆堥梺鎻掞工閸熸捇鎯冮崟顒佇?濞戞挸绉烽々锕傚捶?`@Monitor` 闁搞儳鍋犻惃鐔兼煂瀹€鈧ú鍧楀箳?`animateTo`闁挎稑鏈﹢渚€宕ｉ婵嗗幋濞戞挸绉佃ぐ鍐磹? 闁炽儲鏌￠埀?
   *   閺夆晜鐟ら柌婊堟偝閹峰矁鏉介柡鍕靛灣濠€锛勨偓鍦仜閻°劑宕烽妸褎鐣遍柨娑樺缁查箖寮介悷鐗堢濞戞挸绉靛Σ?闁告柣鍔庨弫鐐媴濠婂懏鏆忛柛?闁挎稑鐭侀埀顒€鏈Σ鍝モ偓瑙勆戦弻鐔兼儍?
   *   **闁靛棗鑻﹢?`@Monitor` 濞戞搩鍙€琚濋柛?`animateTo` 闁哄啯婀圭粭澶愬及閸撗佷粵闁告柣鍔庨弫楣冨Υ?*闁?
   *   V2 闁绘鍩栭埀顑跨瑜板鏌岃箛搴㈠弿闁衡偓鐟欏嫭笑鐎殿喖鍊归鐐哄冀閸ヮ亜澹堥柨娑樻恭romise 鐎甸偊鍠曢幑銏ゅ礉閳藉懐绀嗛柨娑樼焷閳?`animateTo` 缂佹柨顑呴崺銏ゅ礆闁垮鐓€闁兼潙绻楁俊顓㈡倷閻熸澘鏋€閻庤宀搁々鑽ゆ暜瑜濈槐?
   *   闁?`@Monitor` 闁搞儳鍋犻惃鐔兼煂瀹€鍏姊荤壕瀣婵炲备鈧磭纾诲┑顔碱儜缁辨繄鎮銈嗙＇闁告凹鍓涘▓鎴︽偐閼哥鍋撴担鍛婄殤鐎规瓕灏欑划锟犲捶閵婏妇鍨奸柤鏉戠箻濡诧箓宕氬Δ鍛 闁?濡絾鐗曢幎?闁圭粯甯掗埀顒勬？缁楀鈧潧绠嶉埀?
   *   閻庤蓱閺岀喖鏁嶉崸鍒焤kts-new-applysync-flushupdates-flushuiupdates`闁靛棗濂旀繛鍥偨閵娿儲绨氶柡?鐠?闁告柣鍔嶉弲銉╁捶閻戞ɑ鐝柕鍡楃▌缁辨氨绱掑▎鎴炵暠闁告劖鐟︾涵?
   *   閻忓繗椴稿Σ鎼佸捶?`animateTo` 闁汇劌瀚板Λ鎾礌閸涙潙娅￠柣?`UIUtils.applySync` 闁告艾鏈鐐哄礆闁垮鐓€闁烩晩鍠楅悥锝夊磹?闁炽儲鏌￠埀?
   *   `closeFullScreenPlayback()` 闂佹彃鑻崙锛勭磼韫囨柨鐦婚弶鈺傜懁闁叉粓宕樺▎鎰€婇柡鈧柅娑氬晩闁挎稑鏈晶宥嗙閵夈劎绠归梺鎻掕嫰瑜板弶绂掗妷褎绾柟鎭掑劥閻ㄧ喖鎮介妸锝傚亾?
   */
  @Monitor('expandState.collapseVersion')
  onCollapseRequested(): void {
    // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`MainPage.closeWithAnimation()` 闁汇劌瀚板顏堝箥鐎ｎ亜鈼㈤柛鎺戞閺侇噣鏁嶆径娑氱獥
    //   閺夆晜鐟﹀?Monitor 闁?*闁哥儐鍨粩?*闁?闂傚牏鍋炴晶婊堝礉閸喖褰犻梻?闁稿繈鍎辫ぐ娑㈡晬閸у埀uardPlayerBack()` / 濠㈢懓鍟块惇?`onBackPress()`
    //   闂侇喖鈧喕娉?`expandState.requestCollapse()` 闁?`collapseVersion++`闁挎稑顦埀?
    //   濞戞挸顑嗘刊娲焽閿濆棙钂嬮悹?*濞戞挸绉剁划鈩冩交閸ヮ亞绠归梺?*闁挎稑鐗嗛悾鐘绘儎鐎涙ê澶嶉悹?`closeFullScreenPlayback()`闁挎稑顦埀?
    //   闁?闁圭鍋撳ù鐘劥缁绘牠鏌岀仦缁㈠妧濠靛倽妫勯顔芥償閺冣偓濡倝鎮惧畝鈧▓?`pullMode === false` 闂侇叏绲肩粩鎾绩椤栥倗绐?*闁瑰嘲绉撮幓鈺呮偂瑜忕紓澶愬炊閹惧懐绀夊☉鎾崇Т婵晛煤婵犳哎鈧妫?*闁?
    this.closeWithAnimation();
  }
  /** Fallback page background tint when art or color pick fails. */
  private static readonly defaultImageBgColor: string = 'rgba(32, 32, 32, 1)';

  /** 闁煎啿鏈▍娆戠磾閹寸偟澹愭繝褎鍔樼换鏇炩柦閳ュ啿鐓傞柟闈涱儐濡炲倿鎯?*闁哄牆顦遍弲顐︽煂瀹ュ懎绲?*婵炲棌鍓濋弳鐔兼晬閸綆娼?{@link scheduleBackgroundRetry}闁挎稑顦埀?*/
  private static readonly BG_RETRY_MAX: number = 4;
  /** 濞戞挶鍊栭濂告煂瀹ュ懎绲垮☉鏂款儔濡潡鎯冮崟顖涳紵闂傚懏妫戠槐妾搒闁挎稑顦埀?*/
  private static readonly BG_RETRY_MS: number = 400;

  /**
   * 闁煎啿鏈▍娆戠磾閹寸偟澹愭繝褎鍔樼换鏇炩柦閳ュ啿鐓傞柟?闁?闂傚懏鏌х粩瀛樺濮橆剙濮介柛鎰Т瑜板洦绋夐埀顒€鈻庨埥鍛**闁哄牆顦遍弲?*闁挎稑顦埀?
   *
   * 濞戞捁妗ㄧ划鍫熺▕閸儲浠橀悷鏇氱閻ｇ娀鏁嶉崼銏℃殢闁规潙鍢查悿鍕圭€ｅ墎绀嗛柨娑欑濠€顓㈠箻椤撶喐鏉归柣妯垮煐閳ь兛鑳堕崑锝夊礄缂佹ê鈪电€殿喒鍋撻柟缁㈠幗閺備線宕抽妸锔筋槯闁煎啿鏈▍娆撳及椤栫偟鎷ㄩ柣?闁炽儲鏌￠埀?
   * 闁搞儳濮崇拹鐔煎捶閵娧冩疇婵繂鏈ú鎼佹儍閸曨厽鍩傛慨婵撶秬閸庢寮查娑櫺?*缂傚啯鍨堕悧鎼佸炊?*闁挎稑鐭侀埀顒€鑻悾鐘垫啺娴ｈ櫣鎼?`song.cover` 闁告帞澧楁晶婊堝箥瀹ュ熆鎺戭嚗濡も偓閸ゎ參寮堕妷顖滃耿
   * 闁圭虎鍘介弬渚€鎮╅懜纰樺亾娴ｉ绐楀銈囧劋婢ф粓骞?metadata 闁瑰嘲顦电紞鍫ユ晬鐏炴儳顣插ù?闁绘劙鈧稓顏卞☉鎾愁儐閹搁亶寮ㄩ幆褎鐨戞慨婵撶到閻?闁?
   * 闁煎啿鏈▍娆撳矗椤忓浂鍤夐悹?閻忓繋绶氬浼村嫉婢跺姊鹃柡鍫濐槸閸╁矂骞?闁哄牆顦崣?闁?閺夆晜鐟╅崳椋庣磼濞嗗繒鏆婂☉鎾亾濞?*闁衡偓閼稿灚娈?*闁汇劌瀚┃鈧ù鍏煎搸閳?
   * @param jobSeq 闁告瑦鍨奸幑锝夋焽閿濆棭鍋ч柛娆愮墳婢瑰﹪鎯冮崟顐ょ闁告瑥鍤栫槐娆撴偨閵娿儳鏆婇柛娆樺灟娴滄帗绋夐姀鐘电＞閺夆晛娲﹀﹢锟犳儍閸曨亞顏遍弶鐑嗗櫙缁?
   * @param attempt 鐎瑰憡鐓￠崳鍝ユ嫚閺囩噥鍋ч柡?
   */
  private scheduleBackgroundRetry(jobSeq: number, attempt: number): void {
    if (!Number.isFinite(attempt) || attempt >= PlaybackPage.BG_RETRY_MAX) {
      Logger.info(PlaybackPage.logTag,
        `RzdBgRetry give up attempt=${attempt} meshVer=${this.meshSrcVersion}`);
      return;
    }
    setTimeout((): void => {
      // 濞戞挸顦垫禍楣冩⒒椤帞绐楀銈囨暬濞肩増娼诲Ο鐑樿含闁靛棔娴囩换鏍ㄧ▔閳ь剚娼鐣屾⒕閻炴凹鍋呴弻濠囨儍閸曨亞顏遍弶鐑嗗櫍閵嗗﹪骞掓径鍫氬亾娓氣偓閵嗗妫冮姀锝囩闁活亜顑呯欢杈╂喆?
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
   * 闁告瑦鐗炴竟濠勨偓鐟版湰閸ㄦ岸宕ユ惔銏犖╅柡鍌欏嵆椤や線鎳濋懠顑挎崓閺夆晜绋掔粊锕傚礂婢跺本绲婚柤瑙勫絻濞呮帡濡?
   *
   * 闁?`setEffectParams`闁挎稑鐗愰埀顒€濂旂粭澶愬及椤栫偛娅㈢€?`visualEffect`闁挎稑顧€缁变即骞戦姀锛勬憙闁告瑯浜濆ú鍧楀棘?uniform闁?
   * 濞戞挸绉崇槐浼存煂瀹ュ懏鍎欓柣顐熷亾闁艰褰冨▍鎺楀Υ娴ｉ鐦嶅☉鎾崇С缁辨壆鎷嬮埡鍌溿偊闁?閻?闁搞儳鍋犻幑锝夋倷楠炲簱鍋?
   */
  @Monitor('coverTint.version')
  onCoverTintVersionChange(): void {
    this.applyFlowLightColors();
  }

  /**
   * 闁宠棄鎳夊Σ?2026-10-14 濞ｅ浂鍠撻埀顒€鏈粊锕傚礂婢跺骸鍓归柡鍜佸灠缁辨垿宕楀畷鍥╃梾閻㈩垶鏅茬粭澶屾崉閻斿吋顓归悹浣稿⒔閻ゅ棝濡村蹇曠獥
   *
   * 闁稿繐褰夐棅鈺呮偐閼哥鍋?`PlaybackFlowLightState` 闁?*闁哄倹婢橀崹鍗烆嚈?*闁汇劌瀚哥槐娆愵渶濡鍚?false闁挎稑顧€缁辨繄鎷笟鈧崗妯衡柦閳╁啫惟 `MusicStoreService`
   * 闂佹彃鏈€垫梹绋婇崨顓烆嚙闁汇劌瀚伴崑鍛▔椤忓嫧鍋撻懖鈺€鎹嶉弶鈺傜☉楠?闁炽儲鏌￠埀?闁告瑯浜濆﹢浣烘媼閸撗呮瀭濡炪倝娼ч崹蹇擃嚕閳ь剟宕楅搹顐ｎ槯闁归潧绉崇槐浼村礃濞嗗繐褰欏ù婊庡亞婵悂骞€娴ｇ鍋撻崒娆戣壘闁哄嫷鍨界槐?*鐎殿喒鍋撻柣顐熷亾婵炵繝绀侀崢?闁?闂佹彃绉撮幆?App 闁?
   * 闁圭虎鍘介弬浣广亜娴ｅ喚鍤㈤柛鎺撳濞堟垶娼诲Ο缁樞﹀娑欘焾椤?false**闁挎稑鐗愰鏇犵磾椤曗偓閵嗗鈻介檱缁绘﹢宕㈤弰蹇曠畺閻忓繐褰夌粩鎾儎閹绢喗鏅╅柣顐熷亾闁挎稑顧€缁辨繈鎮介妸锕€鐓曢柣顏勵儏閸╁矂鎯冮崟顐ｇ殤闁?鐎殿喒鍋撻柛蹇撳帠缁楀鎹勯悢鍏碱吂閻犱礁澧介悿?闁?
   *
   * 闁宠法濯寸粭?2026-10-17闁?*闁告帞濞€濞呭孩绂嶉崱鏇狀伇闁稿繐鍢查幃鎾诲触瀹ュ懏顢嶅ù?*闁挎稑顧€缁辩増娼诲▎鎾虫闁告鍠愬鍨交濡粯绠掑☉鎾亾濞?
   *   `syncFlowLightPreference(reason)` 闁哄倽顫夌涵鍫曟晬鐏炴垝绮甸柣銊ュ濡?**store 闁?闁稿繐褰夐棅鈺呮偐閼哥鍋?*"閺夆晜鐟ょ粩鎾触閹搭垳骞?
   *   濞达絽妫涘﹢鈥愁潰閿濆牏鐛撻柣銊ュ濡?`aboutToAppear` 闂佹彃鐭傞崑鍛村矗閵壯勭函闁规亽鍎寸粊鎾磹?
   *   闁挎稑娼塼his.flowLightState.enabled = MusicStoreService闁炽儺娉筫tPlaybackFlowLight()`闁挎稑顧€缁?
   *   闁?*闁告瑥绉撮幃?*闁挎稑鐗嗛崣鈩冪椤愩倕笑闁?闁?闁解偓閽樺姘ㄩ柨娑橆槺閺佽鲸绋夌€ｎ喗妗ㄩ柣?`onFlowLightEnabledChange()` 閻犳劗鍠曢惌妤呭Υ?
   *   闁?闂侇叏绲奸柌婊堝棘鐟欏嫮銆?*闂傚棙鍎奸惃鐔兼偨閵娧冧化**闁靛棔绀佽ぐ褔寮?闁告艾濂旂粩瀛樼閺堢數鐨戦柣銊ュ鐞氳鲸绺藉Δ鈧崯鎾斥枖?闁挎稑鐗嗛悾鐘冲緞濮橆偆顏遍柡澶嗗墲濡晞绠?+ 濞戞挴鍋撴繛鍡忊偓鎰佹▼濞达絾鐟у▓鎴﹀矗閺嶎剙顥忛柨娑橆檧缁?
   *     闁伙絾鐟у鍐焊鏉堛劍笑"闁告艾瀛╁鍨閻戞ɑ鏆梺鎸庣懃濠€鎾棘?闁汇劌瀚崣鍡涘矗?闁?鐎瑰憡褰冮崹褰掓⒔閵堝繒骞㈡慨婵勫€曢ˇ鈺傜┍濠靛牊娈岄悹鍥х摠濡叉垿鏁嶇仦钘夊赋鐎电増顨呭鐢垫偖椤愶箑娅㈤柡鍌涙緲婵偤宕堕悙瀛橀檷闁?
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
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲?`MorphGuard` 闁?闂佹澘绉锋竟濠勨偓鐟邦樀濞笺倗绮ｅΔ鈧ぐ?** 闁炽儲鏌￠埀?閻?`morphQuietUntilMs` 闁汇劌瀚敮鍦偓鐢点€嬬槐?
   *
   * @returns 闁绘粍婢樺﹢?*濞戞挸绉烽崗?*濞戞挸锕ㄦ竟濠囧籍閹壆绠烽悷鏇氳兌閻℃垶寰勫顒傛瘜 ms闁? = 闁告瑯鍨禍鎺旂博鐎ｎ亜绁☉鎾筹龚婢瑰﹪鏁嶆径鍫氬亾?
   *   闁宠法濯寸粭?濞戞挸绉烽崗妯荤▔婵犲懎顥忛柡鍐煐濠€浼村礄閼恒儲娈跺ù?*濡炪倗鍎ゆ晶婊堝箳閹哄秶顏辨繛鍡節閸ｅ摜鎷?*闁挎稑鐗嗙粻鎾剁驳婢舵稓绐梎colorRetryQueued` 闁告瑯浜滈崢鎴犳媼闂€鎰伇闁哄鈧櫕韬瀣剳缁辨岸鏁?
   *   闂佹彃绉烽惁顖炴⒒閹绢喗顓?= `wait + 32ms`闁挎稑鐗婂Λ銈夋偩瀹€鍕簼濞?`0x20` 濞达絾鐟╅崳娲晬婢舵稓绀夊☉鎾冲濡倝鎮?`MainPage` 闁汇劌瀚崯鎾斥枖閺団懇鍋撻幇顓熻拫閻庣數鎳撶花鏌ュΥ?
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
        // 闁?2026-10-17闁挎稒宀搁妴澶愭閵忕姴鍤掗梺顐熷亾闁革箑鎼銊╁礆椤愩垹鏅欏☉鎾筹龚婢?閻炴稏鍎崇紞澶愬冀?闁炽儲鏌￠埀?
        //   闁哄牜鍓熼妴澶愭儍閸曨偄绲块柤瑙勭叀閹借偐鎹勯姘含闂侇偀鍋撻柛锔惧劋濡炲倹瀵煎顐㈢槣闁告柣鍔戦崳鎾绩閸欍儳绉撮柛銉︽嫕缁辨瑧鎲?`onDisappear` 闂佹彃鐭傞崑鍛▔閵堝懎缍?`releasePixelMapQuiet`闁挎稑顧€缁?
        //   闁兼眹鍎寸换鏍级閿熺姴娅㈤悹鍥ㄦ礉缁绘洟宕?`commitMeshSource`闁挎稑鐭傞崑鍛焊鏉堛劍笑闁瑰嘲銇樼粩鏉戭嚕?*鐎规瓕灏欑划锟犳煂婵犲啯鏉归弶鈺佹川濞?*濞达絽绉村ù姗€宕㈢紒妯哄簥婵犙勫姂閳?
        if (!this.isAlive) {
          return;
        }
        // 濞戞挸瀛╁Λ銈夋偩瀹€鍕簼濞戞搩浜崳鍝ユ嫚?娴?濞戞挴鍋撻柤鐤彧缁变即宕楅崼鐔告澒鐎殿喒鍋撴鐐插€婚悺鎴﹀冀閸ヮ亶鍞堕柨娑樿嫰閸熲偓闁硅泛锕ｇ粭鍌炴嚌閺屻儱娅㈤悹鐑樺灣缁旀挳鏌?
        // 闁挎稑鐗婂Λ銈夋偩瀹€鍐闁汇劌瀚Σ?`syncReportChrome()`闁挎稒绋掑﹢鐗堢閹炬剚鍤犻幖瀛樻⒒濞堟垹浜告潏銊π﹂弶鈺傜懁鐞氳鲸绋夐鍐憪闁肩灏欓崑锝夋晬婢跺牃鍋?
        this.applyFlowLightColors();
        this.republishMeshSourceIfAny();
      }, wait + 32);
    }
    Logger.info(PlaybackPage.logTag,
      `RzdFlowLight color apply deferred ${wait.toFixed(0)}ms (morph quiet window)`);
    return wait;
  }

  /** 闁?{@link coverTint} 闂佹彃鐬煎▓鎴烇紣濠婂棗顥忛柟鎭掑妿缁即鎯堥埀顒勬嚌閹绘帗鐝ら柨娑樼墕閹捇鎮ч崼鐔告嫳闁告瑥鍢茶ぐ褔骞掗妸銈囶伇婵炲棌妲勭槐姘跺Υ?*/
  private applyFlowLightColors(): void {
    if (this.coverTint.version === this.appliedTintVersion) {
      return;
    }
    // 閳藉應妲勯埥鍛 2026-10-17閿?*閸欘亝婀?瑜版挸澧犳潻娆庣妫ｆ牜鐣婚崙鐑樻煀妫版粏澹?閹靛秶鐣?ready**閿?
    //   `coverTint` 閺勵垵娉曟い鐢告桨閸忓彉闊╅惃鍕剁窗閹稿倽娴囬柇锝勭閸掕鐣犻惃?`version` 瀹歌尙绮￠弰?*娑撳﹣绔存＃?*閻ｆ瑤绗呴惃鍕偓绗衡偓?
    //   閳?`aboutToAppear` 闁插本濡?`appliedTintVersion` 閸掓繂顫愰崠鏍﹁礋瑜版挸澧犳潻娆庨嚋 version閿? 鐟欏棔璐?瀹稿弶绉烽崠?閿涘绱?
    //     娴滃孩妲告潻娆撳櫡閸欘亝婀?*version 閸欏牐顫﹂幒銊╃彯**閿? `extractFlowLightColors` 娑撳搫缍嬮崜宥嗙摃閸愭瑤绨￠弬鎷屽閿涘澧犵挧鏉垮煂娑撳娼伴妴?
    this.tintReady = true;
    // 闁?鐟滆埇鍨硅ぐ澶屸偓鐟邦樀濞笺倗绮ｅΔ鈧ぐ娑㈠礃閸涱剛鐟濆☉鎾筹龚婢瑰﹪鏁嶉崼锝庢綄 `colorApplyWaitOrRetry`闁挎稑顧€缁辨壆绮垫径宀€宕堕柛娆欑秬缁诲啴宕㈢拠鑼殜濞村吋淇洪崵婊冾啅闁秴娅㈤悹鍥ㄦ磻缁旀潙鈻庢幊閳?
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
   * 闁圭虎鍘介弬浣广亜閸偆銈﹂柛蹇擃槼閸庢寮查姘辨勾闁挎稑婀欴S `UV_BACKGROUND_FLOW_LIGHT` 闁活偀鍋撻柤瑙勫絻濞呮帡鏁嶆径鍫氬亾?
   *
   * 闁告瑥鍊介埀顒€鍟╃粭鍌氥€?PR #1 闁革负鍔戦々缁樸亜閻㈠灚鐣遍柣顫妽绾爼鏁嶇仦鑲╃ɑ濡増绮忔竟濠冪▔瀹ュ棙笑闁告劖鐟﹂鎾儍閸曞墎绐梎colorSource` /
   * `colorTarget` 闁哄鍎撮崵婊嗐亹閹惧啿顤呴悘蹇庣窔濞间即宕濋妸锔瑰亾娴ｇ绲块柤纭咁嚋缁辨瑧鎲?{@link publishFlowLightColors}闁挎稑顧€缁?
   * 婵絽绻戦濂稿箲閵忥紕鎽冮梺顔藉灊缁变即鏌屽鍡樼厐缂佺姵銇炵粩鏉戔枎鎺抽埀?
   *
   * 濞达絾绮堢拹?`Stack` 闁?*濡絾鐗旈柌婊呪偓娑欏姌婵☆參鎮?*缂備焦锚閸╂鏁嶅顒佽含濡炪倗鏁诲鐗堟償閺団€愁棌濞戞柨顑勭粭鍌炲Υ娴ｅ摜娈遍梻?婵繂鐭侀惁婵囩▕鐎ｂ晝鐟撻柕?
   * `HitTestMode.Transparent` 闁哄嫷鍨扮换鈧銈堝吹濞?闁炽儲鏌￠埀?闁轰焦娼欓惇浼村及椤栨艾寮块悘鐐茬箳濞堟垿鏁嶅畝鍕笡閻犱降鍊曢幊鈩冪▔椤撶姵鐣遍悹鍥ㄧ箑缁变即骞?
   * 闁圭虎鍘介弬浣广亜閸偄顣查柡鍫濐槹鐎垫粓鏌﹂鐐暠闁绘劗鎳撻崵顕€宕楅妸銉﹀€栭柟鍝勵槶閳?
   */
  /**
   * 闁哄牜鍓氬┃鈧柡鍕靛灠閹線宕楀畡閭︽У HDS 閻熸瑥妫欓弲銉╂嚄閽樺顫斿ù锝呯Р閳?
   *
   * 闁宠法濯寸粭?婵炵繝绀侀崢婊堝及?HDS `hdsEffect` 闁?shader 閻熸瑥妫欓弲銉╂晬?*閻犱焦鍎抽ˇ顒€鈻介埄鍐╃畳閺夆晜鐟ら柌婊堟嚄閽樺顫斿ù锝呯У濡炲倻鈧懓鍟╃槐浼存濞嗘挾甯涘☉鎾崇Ф閺?*
   *    闁挎稑鐗呯粭澶愬箮閵夆晜鏅╅柕鍡曟缁楀骞庡☉妯肩＝閻㈩垶娼荤槐姘舵晬瀹€鍐︹偓鍐偝閺夋寧鐨戦柡鍕靛灣閺併倝骞嬮悿顖ｅ殯闁?鐎殿喒鍋撳ù婊冩缁辨垿宕楅崗鍛ɑ濞寸姭鍋撳☉鏂跨墦閸忔ê鈻介垾鍐茬岛闁?闁?
   *    闁圭鍋撳ù鐘劥缁绘牠鏌岀仦鐐枖鐎殿喖绻愰崹浠嬪棘?+ 閻犱胶澧楀Λ鈺勭疀濡ゅ绀夋鐐舵硾濠€顏呯▔瀹ュ棙鏆滈柟闀愮劍濡炲倿鏌呴埀顒勫炊閻愭壆顏遍悘鐐插€垮銈夊箑娴ｅ湱鐟ら柛娆愶公缁辨瑩鎳涢崘鑼瘜闁活亜顑呯欢杈╂喆娓氣偓椤や線鎳濋幓鎺戠秮闁告牗鐗槐姘跺Υ?
   */
  /** 婵炵繝绀侀崢婊堟儍?HDS 闁煎疇妫勬慨蹇旀媴瀹ュ繒绐楃紓鍌氭惈閵囨垿寮?shader 閻熸瑥妫欓弲銉﹀濮樿埖楗娑櫭肩粭澶愭偨娴兼瑧绀勯悷?{@link hdsEffectCapable}闁挎稑顦埀?*/
  private static readonly HDS_CORE_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';

  // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛鍥ㄧ▔婢跺﹤纾╁☉鏃€绻嗛悿?/ Round 20闁挎稑顧€缁辩櫗COVER_BLUR` 濞?`imageBlurRadius()` **鐎瑰憡褰冮崹褰掓⒔?*
  //   闁挎稑鐗婇幐閬嶅绩妤ｅ啨鈧鎳楃仦鐐彲闁衡偓鐟欏嫬鐏囩紓鍐╁灦閻楁悂鎳楃仦鐐彲闁告艾鍑界槐婵囷紣閸曨剝顩柡灞炬尰鑶╃紒顖氾躬閸嬪懘寮堕敍鍕疇闁革负鍔庣槐顏嗘嫚閹存繃绂堥梺鎻掕嫰閸戯繝寮悩杈ㄥ床濞达絾娲濋惃鐔兼偨閵娿劉鍋撻崪鍐闁?
  //   闁告帞濞€濞呭孩绗熷┑鍥хウ濞戞挸绨兼鍥偋閳哄喚鍎婇柛娆戞焿閸ゆ粌螞閳ь剟鏁嶉崸顣昫ules.abc GONE闁挎稑顦抽～?RzdMusic閻犱焦婢樼换?md 閹?6.15闁?

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
        // 閻庤蓱閺岀喓绮堟潪鎵紣闂佹彃鏈€?shader 閻熸瑥妫欓弲銉╂儍閸曨偒鍟囬柛锝冨姂閸忔鏁敃鈧花鎶芥嚌鐠囇呯`backgroundColor('#383838')`闁挎稑顧€缁?
        // 閺夆晜鐟╅崳椋庣磼濞嗗海顏遍悘?*鐎垫澘鐗婄拹浼存儍閸曨剚顔傞幖?*闁挎稑鏈Λ锔剧磼濞嗘帩娼掗柡浣哥墔缁斿瓨绋夐鍕婵炴挸寮堕悡瀣儍閸曨偆淇洪柨娑樿嫰瀵灚绋夊澶夌磿濞达絽绻愰惃婵嬫椤兘鍋?
        .backgroundColor('#33000000')
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
            animation: {
              duration: FLOW_LIGHT_DURATION_MS,
              iterations: -1,
              autoPlay: true
            },
            // 闁告帗绻傞埀顒冨亹閺併倝宕楀鍐亢闁肩顕滅槐閬嶆儑閻斿壊鍔€闁汇劌瀚伴·渚€鎳濋懠顒佹殸 applyFlowLightColors 闁革负鍔岃ぐ鍥嚌閹绘帞鏆氶柟瀛樺姇閹绋夌€ｎ亜绲洪柨?
            // 閺夆晜鐟﹂悧閬嶅础閸忓懎鈻忛柛娆愮墳婢瑰﹤顕ラ崼鐔峰籍濞戞梻鍠曢崗妯肩博鐎ｎ亜鐓濋柣顏勵儏閸╁苯霉娴ｇ甯ㄩ柛锔哄妼婵晠鏁嶉崼锝傚亾鐏炶偐鐟濋柡鍕靛灦缁妇浠﹁箛鏇犳惣闁告锕ら妵澶愭晬婢跺牃鍋?
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
          // autoPlay 鐎瑰憡褰冪槐鎴︽晬鐏炶棄鏅欓柡鍕劤缁?play 濞戞挴鍋撴繛鍠°値鍞ㄩ柣妯垮煐閳ь兛鑳堕垾妯尖偓瑙勭啲缁辨瑩骞戦姀锛勬憙闂佹彃绉寸紓鎾舵嫚閵夈儳婀撮柡鍐╂构缁楀瀵煎顑跨不闁革负鍔嶅▓蹇涘磻濠婂嫧鍋撴笟濠勭
          try {
            this.flowLightController.play();
          } catch (error) {
            const err = error as BusinessError;
            Logger.warn('RzdFlowLight', `play failed code=${err?.code} message=${err?.message}`);
          }
        })
    } else {
      // 闁煎疇妫勬慨蹇旀媴瀹ュ洤绻佸鑸靛敾缁变即鏌呴埀顒勫炊閻愮儤楗柟顑跨劍缁楀酣宕ｅ鍫㈢濡増绮忔竟濠冪瀹ュ牏顎€閻忓繋绶氬鎵導鐢喚绀嗛柨娑樺缁绘氨鎷?鐎殿喒鍋撻柛蹇氭珪婢э箑顕ｉ埀顒勬儑鐎ｎ亞绻侀悷娆庢缁椼垻鎲?
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
            `layer mounted capable=0闁挎稑鐗婂Λ?HDS 閻熸瑥妫欓弲銉╂嚄閽樺顫斿ù锝呯▌缁辨繈寮ㄩ崷顓熸殢闂傚牊鐟﹂埀顑跨劍缁楀酣宕ｅ鍫㈢enabled=${this.flowLightState.enabled} ` +
            `src=${this.coverTint.sourceColor} dst=${this.coverTint.targetColor}`);
        })
    }
  }

  /** 闂佽鲸甯炲ú浼村箵閹邦喓浠涙俊顖ｄ簻缁犳瑩鏁嶅鍓佸従婵犙勫姌閸撳ジ寮甸鍐╃《闁煎瓨纰嶅﹢浼村礆閸ャ劌搴婇柡鍐煐濡绮堥悮瀵哥3 缂佸甯掗幃妤呮嚊椤忓嫬袟闂傚懏鍔樺Λ宀勫Υ?*/
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
   * 婵炴惌鍠栭惇鎵偓瑙勭煯缂嶅懘宕ｉ敐鍛獮闁挎稑鐗婇弫濂稿礈瀹ュ浜濋柣妤€鐗婇弫鐐烘煂婵犲啯笑**闂佹寧鐟у▓?*闁?026-10-15 闁圭顦板﹢浼村嫉?SDK 闁哄洤鐡ㄩ婊堟晬婢跺牃鍋?
   *
   * 闁?闁哄唲鍡╁殯婵炲娲╃槐浼村Υ鐎瑰潮osition({x, y})` 闁哄嫷鍨板﹢?*闁煎浜為崝褎鎷呭鍥╂瀭**濞戞挸锕ら崯鈧柛鏃傚Т娴滃摜绮旀导娆戠闁圭鍋撳ù鐘劚閻櫕绋夐鐘崇暠 Stack 闂佹彃鐭侀々锕傚礂閸繂娅?
   *    `(缂佹劖顨呰ぐ娑氫焊閸濆嫷鍤?闁?闁煎浜滅换浣轰焊閸濆嫷鍤? / 2`闁靛棗绉查埀?*濞戞挸绉甸崹姘辩博鐎ｃ劉鍋?*
   *
   * 闁?闁哄牜鍓氬┃鈧?SDK 闁告鍠愰弸鍐晬閸у墕dk\default\openharmony\ets\component\common.d.ts:25284`闁?
   *    `position(value: Position | Edges | LocalizedEdges)`闁挎稑顧€缁?
   *    闁?*Sets the absolute position of the component relative to the position of the
   *    parent component.**闁靛棗绉埀顒佹煛閳?閻忓繗椴稿Σ?*闁烩晝顭堥顕€鎮ラ崜浣虹煁濞寸姾娉涙稊蹇旂▔婵犲拋娼￠柣銊ュ缁鈧數鎳撻悾鐐媴?*闁挎稑濂旂粭宀勬嚊椤忓棗濮уù锝呯Ф閻?`alignContent` 闁哄啰濮撮崣褔濡?
   *
   * 闁?缂備焦鎹侀鎴︽晬閸喐鎷遍柡鍌氭矗濞嗐垽骞嶉埀顒勫嫉婢跺鐧侀悘鐐插€块崗姗€骞愭径搴ｇ闁哄鈧啿鏅搁柨娑橆檧缁?
   *    闁告瑯浜ｉ々锕€霉椤旇偐婀撮柟纰樺亾闁革负鍔岄鎰板闯?*鐎归潻缂氱粭鍌滄喆閹烘垶鐨戦柡鍕靛灣閻涖儵宕ｉ敐鍛枾闁?*闁挎稑鐣璓layerExpandState` 濞存嚎鍊曢崵顓㈡儍?*缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨?*
   *    閻忓繗绮鹃崗姗€鎯勭€涙ê澶嶇憸?`.position({x, y})` 闁汇埄鐓夌槐?*闁稿繈鍔戦幗濂告⒖閼搁潧搴婄紒?*闁?
   *    `MorphCoverBridge`闁挎稑鐗嗛幃鎾寸▔閳ь剛浠﹂崒锔剧闁圭顦遍悰銉╁矗閿濆懏缍忛柡宥呮穿閹倖鎷呭鍛殥閻炴凹鍋嗗﹢锟犲嫉濞差亞宕ｉ悹鍥︾筏缁辩浗LyricFloatLayer` 闁告艾鑻惇浼村触鐏炶棄缍撶€垫澘瀚ㄩ埀?
   *
   * 闁绘粍澹嗘慨鎼佹晬濞? 闁汇劌瀚悺鏇犳嫚瀹ュ鈧霉椤旇偐婀撮柣銏犲綁缁楀懘妫冮姀銏＄暠 {@link LyricFloatLayer} 闁瑰灚瀵ф刊鎾晬?
   * 閺夆晜鐟ょ悮杈ㄧ▔?`morphWindow*Vp()` 闁哄嫷鍨卞ú鍧楀籍閳哄懎浜濋柣妤€鐗炵槐娆忣啅閹绘帒鐏╅柨娑標嘗yricCoverOverlay` 闁汇劌瀚版禒鎰版偩濞嗗繐绲块柛濠勫帶濞呮帡鏁嶇仦鑲╃闁伙絾鐟ょ粭澶愬礉閵婏絺鍋?
   */
  /** @returns 婵炴惌鍠栭惇浼村矗閸屾績鍋撻崘顏呮殢闁汇劌瀚悰銉╁矗閿濆拋鍟嶉幖杈捐缁辨獫p闁挎稑顦埀?*/
  private morphWindowWidthVp(): number {
    return this.expandState.windowWidthVp;
  }

  /** @returns 婵炴惌鍠栭惇浼村矗閸屾績鍋撻崘顏呮殢闁汇劌瀚悰銉╁矗閿濆褰幖杈捐缁辨獫p闁挎稑顦埀?*/
  private morphWindowHeightVp(): number {
    return this.expandState.windowHeightVp;
  }

  /** 闁衡偓閹増宕抽弶鈺傜☉鐎?0..100闁?*0 = 閻庣懓鏈弳锝夊箻椤撶喐鏉瑰銈囶暜缁辨瑩妫冨▎鎰靛壘闁诡兛绶ょ槐?*闁?00 = 闁衡偓閹増宕抽柟瀛樺姌閸掓稒鎯旈弴鐘崇暠濞戞挴鍋撻柡澹滄壋鍋?*/
  @Local collapseProgress: number = 0;

  /**
   * 闁稿繐褰夐棅鈺呮儍閸曨偆娼旂€殿喒鍋?鐟滆埇鍨硅ぐ澶愬礄閻樿京绉块柨娑樼墔缁楀本绔熼崘鑼勾闁靛棔娴囩化鐘虫媴閻樿櫕钂嬮柕鍡曠閵囧洨浜告笟鈧浼村礂鏉堚晜鏆忛柛姘缁斿瓨绋夐鍕澖濞撴艾顑戠槐姘跺Υ?
   *
   * 闂佹彃鐭傚浼存儍?`morph` 閻庡湱鎳撳▍鎺斺偓娑欘殕椤斿矂鏁嶉崸鐧盿le / translate / clipHeight / radius闁挎稑顦銊╁及?
   * 闁哄啰濮烽弲?`ExpandAnimation` 闂侇叏绲介〃?闁轰焦鎸抽妴澶岀磽閳哄倹鏉?+ 缂佹梹鐗滃ú璺ㄦ啑娴ｇ顥呯紒鎰殔瑜?闁汇劌瀚慨鎼佸箑娓氬﹦骞?
   * 濠㈢懓鍟块惇浼村捶閵娿劎顎€闁归潧顑嗗鍌炲绩閻熸壆鏆婇柨娑樻湰濠€鐗堛亜閻㈠灚绾柟鎭掑劥椤曚即寮堕妷锕侇洬闁哄本鎸堕埀?
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * 閻犺櫣鍠愭晶婊勭▔婵犲啫顎欓柡鍐煐婵℃悂宕楅崣姗€鐓╅弶鈺傜☉鐎规娊姊瑰鍐ㄥ壖閺夆晜绋掑鐢稿Υ?
   *
   * 濠㈢懓鍟块惇浼存晬閸ь湼oducts闁挎稑顦﹢顏呮交閾氬倻绋戦柡澶嗏偓鑼憪闁稿鐭粭鍌炲箯婢跺顤侀柛鏃囷骏閳ь兛鐒﹂弫?`expandState.morph`闁?
   * 閺夆晜鐟╅崳鐑藉矗椤忓洨顦伴悹鎰剁到濠€?*闂傚牏鍋涢鎰板闯閵娿儴鍩岄柛?*闁汇劌瀚埀顑挎祰閻儳顕ラ崟鍓佺闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁挎稑顦粭鍛┍濠靛洤鐦?`collapseProgress` 闁告艾鏈鐐哄Υ?
   */
  @Monitor('expandState.transitionProgress')
  onTransitionProgressChanged(): void {
    if (this.expandState.morphContainerActive()) {
      // 閻庡湱鎳撳▍鎺曘亹閵忕姴缍侀梺顓ㄧ稻濞碱垳鎹勯娆戠憹闁?collapseProgress闁挎稑鐗撻悵顔芥償閿旀垝鑸?100%闁挎稑鐭侀～?sheetHeightPercent闁?
      return;
    }
    this.collapseProgress = this.expandState.transitionProgress;
  }

  /**
   * 濞戞挸顑嗘刊娲绩閹増宕抽柟闈涱儏婵炲秹鏁嶉崼銏㈠建闁烩晛鐡ㄩ弻鐔煎触閹搭垳绀嗛柕?
   *
   * 闁宠法濯寸粭?`distance` 闁?*闁哄啰濮烽弲顐も偓闈涚秺缂嶅牓宕?*闁挎稑鐗愰～?{@link PlaybackPage.DISMISS_PAN_DISTANCE_VP} 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柨?
   *    濞戞挸绉撮崯鎾垛偓鐟板暞濡炲倸顩奸崱妯间桓濮掓稒顭堥?**5vp**闁挎稑鐭傞崑鍛▔閳ь剙顩奸敐鍕獥閻?1~2vp 闁汇劌瀚慨鍫ュ礉閵娿劎妲曢柛鎺濆亝閸?鐎殿喒鍋撳┑顔碱儎缁楀懘骞?闁?
   */
  private panOption: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Vertical,
    distance: PlaybackPage.DISMISS_PAN_DISTANCE_VP
  });

  // 闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛?閻忓繋绶氬浼村Υ瀹€鈧悽缁橆槹閻愭彃鐓傛慨婵嗙焷閻︽繃銇勯悙鍏夊亾瀹ュ繒绀勯悗浣冾潐閻?闁哄啰濮烽弲顐︽閸忓懐顔?CoverMorph 闁告瑥鐬奸顒勬倷閻у摜绀嗛柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩?

  /**
   * 閻忓繋绶氬鎵磼椤撱埄妫ч弶鈺傜☉鐎规娊鏁? = 闁稿绮屽﹢顏嗕沪閺囩偟纾诲銈呭悁缂嶅懐绱旈鍡欑1 = 鐎瑰憡褰冮崺灞筋潰瀹€鍐Г濡炪倕鍚€缂嶅懐绱旈琛″亾?
   *
   * 闂傚牊鐟﹂娑㈠捶閵婏附灏￠柡鈧ィ鍐︹偓澶愬籍閼稿灚笑 0闁?*濞戞挸绉堕弫鐐槹閻愰鏀介悘蹇庣窔濞?*闁挎稑濂旂粭灞解柦閳╁啯绠掗弶鈺傜懃椤ㄦ粓宕濋妸褎鏆伴柡鍐ㄧ埣閳ь剚鍔曢崕姘辨閻樿京顏遍柤鐤彧缁辨岸鏁?
   * 闁告瑯浜濆﹢渚€宕氶崶褍鐓傛慨婵嗙焷閻︽繃銇?闁告帒娲ゅú鏍焊娓氣偓濞肩増銇勯悽鍨暠闂?360ms 闂佹彃鏈晶?0闁? 閺夆晛娲﹀ù顕€濡?
   */
  @Local lyricMorphT: number = 0;
  /** 濡炲鍋犻、鎴犱焊娓氣偓濞间即寮伴姘剨闁告瑯鍨甸～鍡涙晬閸儲楗慨婵勫灪閳ь兛妞掔粩鏉戭嚗?false闁挎稑濂旂换姘辨嫚娴ｉ鐟濈憸鏉垮船閹肩兘妫冨▎鎰ㄥ亾娴ｅ摜顏撮悘鐐╁亾闁挎稑顦埀?*/
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

  // 闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛?闁硅矇鍐ㄧ厬闁告牗妞藉銈咁潰閵忥絽娈伴柛鏂诲妽閺佸湱鎸ч崙銈囩閻庝絻顫夐悥?闁哄啰濮烽弲顐︽閸忓懐顔?BarCollapse闁挎稑顦弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅?

  /** 闁硅矇鍐ㄧ厬闁告牜鍎ゅΣ鎼佸触閿曗偓閸戯繝鎳涢鍕楅柡鈧幆鐗堝闯闁挎稑鐗婇弫鍦導瀹勭増鍊甸柣鎰扳偓娑欏床闁规澘绻愰ˇ鈺呭船閵堝懎姣夐柨娑橆槶閳?*/
  @Local chromeCollapsed: boolean = false;
  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`PlayerPage.hideChrome()` 闁?闂傚牄鍨哄妯侯嚕閳ь剟鎯堥埀顒備焊閸欐鐟濋柡鈧?閻庣懓鐗嗗畷濂告晬婢舵稓绐?
   * **闁圭虎鍘介弬渚€姊奸悢宄扮仚 / 闁稿繑婀圭划顒勬偋閸喐鎷?*閺夆晜鐟ょ悮杈ㄧ▔椤忓嫯鍓ㄩ悘鐐插€瑰Σ鎼佸触閿曗偓缁辨垿鎯堥埀顒勬晬閸垺鏆?`ControlAreaComponent.onAuxSheetOpenChange` 濞戞挸锕ユ慨銈夋晬婢跺牃鍋?
   *
   * 闁哄啰濮烽弲顐︽焽閿濆嫮顏遍柡澶嗏偓宕囨殦闁告鍋呭Σ?10 濞?flag 闁汇劌瀚悡顓犳崉椤栨稑鐏楅梺鐐嫕缁辨獋abc.txt:4124-4225`闁挎稑顧€缁?
   * 闁哄牜鍏涚划銊╂嚕濠婂啫绀?sheet 闂侇叏绲肩粩鎾籍韫囥儳绀刞settingsOpen`/`qualityOpen`/闁炽儻璁ｇ槐姘舵媰閽樺韬?*濞戞挴鍋撳☉?* `bindSheet` 闂佹彃鐭夌槐?
   * 鐎规瓕灏欓弫?`playMenuOpen` 濞寸媴缍€閵嗗啴鏁嶅☉妯衡挅濞戞挸顑堢换鏍ㄧ▔閵堝嫰鍤嬮柣銏ｉ哺濠€鎵偓娑欘殕椤斿本绂掗敐鍫涒偓?闁?濞戞挶鍊涢埀顒€鎳庨幃搴ｆ導闁垮闄?= "濞寸姾顔婄紞宥夋閵忊剝绶茬€殿喒鍋撻柣顐熷亾"闁?
   * 闁宠法濯寸粭?濞?`playMenuOpen` **闊洤鎳橀妴蹇旂▔閳ь剛鎸?*妤犵偞鍎肩换姗€寮ㄩ幆鐗堝闯闂傚偆鐓夌槐娆撳触鐏炶偐顏遍柡澶嗏偓宕囨殦闁告鍋嗗▓鎴炵▔閵堝嫰鍤嬮柛鎺戞閸ｆ椽鏁嶇仦鑲╃憹閻犱胶顭堣ぐ褔宕氶妶鍕伇濞戞搩浜风槐姘跺Υ?
   */
  @Local auxSheetOpen: boolean = false;
  /**
   * 闁?2026-10-17闁挎稒鐡狹orphGuard` 閻庣懓顦靛銈囩玻濡も偓瑜版盯鎯?闂佹彃绉烽惁顖炲矗椤忓懎绗撳☉鎾亾闁?妤犵偛鍊婚悺鎴﹀冀閸ヮ亶鍞?
   * 闁挎稑鐗嗛顕€寮介崶銊︼骏闁?`MainPage.colorModeRetryQueued`闁挎稑鐣瓀ujie.pa:145966/145979`闁挎稒鐩崳鍝ユ嫚?娴?闂佹彃鑻ˇ鍙夋媴瀹ュ繒绀嗛柕?
   */
  private colorRetryQueued: boolean = false;
  /**
   * 闁?2026-10-17闁挎稒鑹鹃悾銊╂濞嗘垹宕堕柛娆欑稻濠€锟犳⒒?*鐎垫澘鎳撹棢**闁汇劌瀚紞澶愬冀閼规澘鍓归柡鍜佸灡缁噣鏁嶉崼銏㈠炊闁告瑱缍€缁诲啴宕㈢拠鍙夊€甸柣?
   * {@link republishMeshSourceIfAny} 闁圭粯鍔掑锕傛晬婢跺牃鍋撻崒娑橆暡闁哄牆顦板鍫ュ捶閵婏附鎷卞銈囶暜缁辨繈寮撮幐搴″簥闁哄啫鐖奸崳鎾绩閻愵剚锛嬮柣銊ュ閳?
   */
  private pendingMeshPm: image.PixelMap | undefined = undefined;
  /** 闁煎浜滄慨鈺呭绩閹増宕抽悹浣插墲濡炲倿宕抽妸锝傚亾?*/
  private chromeTimerId: number = -1;
  /** 闁哄牃鍋撻柛姘凹缁旀潙鈻庨埄鍐ㄤ粯闁告帟娉涚亸顖涚閵堝嫮闉嶉柡鍐ㄧ埣濡潡鏁嶉崸顣欓柨娑橆槶閳?*/
  private chromeTouchedAtMs: number = 0;

  // 闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛?閻忕偞娲栫槐鎴﹀籍閸撲焦鐣遍梺顐ｅ姇閸樻挾妲愰悩瀹犵獥闁稿繈鍎荤槐娆撴嚊椤忓懎鐦弶鈺傜☉鐎规娊鏁嶇仦鑲╃憹濠㈣泛绉堕弫銈夊礂閸欐﹢鐓╅柣鈺呮櫜缂嶅懘鏁嶆径鍡樻珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲?

  /**
   * 閻忕偞娲栫槐鎴犳偘閵夆晜锛熼柡鍕靛灠閹線宕烽妸銊х崜闁?
   *
   * 闁宠法濯寸粭?閺夆晜鐟﹀Σ?*闁哄牜鍓欏﹢?*闁哄秴娲ょ换鏃堟晬鐏炶偐鐟柛娆樹簽閺併倝寮堕妷銉ユ瀫閻?閻熸洑妞掔粭澶屾啺娴ｇ儤鏆忛柛鏂诲妿閺侀箖宕?闁挎稒绋戣ぐ褏鎲版担鍝ユ殜闁?false闁?
   * 闁圭鍋撻柡鍫濐槹鐠愪即宕楅妷銉ョ悼闁稿﹪妫跨粩鏉戭嚗鐎ｎ厾绠查柛銉у仱濞笺倕顫㈤姀鈾€鍋撴笟濠勭1 / 0闁挎稑顦埀顒€鍊界换鏍冀閾氬倻鐟濋悗娑櫭﹢?闁哄秴娲ょ换鏂库枔鐎ｎ剚娈岄悗浣冨閸ぱ囧礃閸涱収鍟囬梺顐㈢箲濡?闁汇劌瀚ぐ鏌ユ嚄?
   * 闁炽儲鏌￠埀?闂侇叏绲惧Σ鎼佸即閸撗呯梾闁汇劌瀚﹢锛勨偓?bug闁挎稑鐗忛弫銈夊箣閸戙倗绐楅悘蹇庣窔濞兼澘菐閳╁啳绐楅柛鎴ｆ楠炲洭宕ユ惔銏℃濡炪倗鏁搁埞鏍儌閺傘倗绀嗛柕?
   //  鐟滆埇鍨硅ぐ澶嬫交濞戞ê顔婂☉鎾崇Т瑜扮喓鈧稒锚瑜板鏌岃箛銉х獥闁烩晛鐡ㄧ敮瀛樺緞瀹ュ洦鏆?`collapseProgress`闁挎稑鐗愰～?`morphProgress()`闁挎稑顧€缁?
   //  闂侇剙鐏濋崢?濡ゅ倹锚鐎规娊宕氭０浣哄晩濞达絽妫涚紓澶愬绩閻愵剛姊鹃柛?闁汇劌瀚悮杈ㄧ附濡ゅ嫷鍚€闁哄啫鐖奸弫濠冩媴瀹ュ啠鍋?
   */
  @Local expandIntroRunning: boolean = false;

  /** Seeds cover Resource from the current queue item. */
  aboutToAppear(): void {
    // 闁稿繐鐗愰鍥ㄧ▔閳ь剟寮?閺夆晜鐟ょ粩瀛樸亜閸偄鐦弶鐐跺Г濡炲倻鎸ч幍顔界暠闁哄嫷鍨伴幗銏ゅ级闄囬惌?闁挎稒姘ㄩ崑锝夊礄缂佹ê鈪电€殿喒鍋?vs 濞戞挸锕ユ刊娲箥閹惧磭纾婚柣銊ュ鐏忣垶宕氶銏＄殤闁?`pullDragging`闁?
    // 闁圭儤甯楅悡?闁绘劗鎳撻崵顕€骞嶉幘宕囩；閺夆晜蓱濡叉悂寮婵晠鎮?闁哄啯鍎肩换鏍ㄧ▔閳ь剛鎮扮仦鐐粯闁稿繑濞婇弫顓㈡晬閸у埅dc shell hilog | grep "expand intro"`闁挎稑顦埀?
    Logger.info(PlaybackPage.logTag,
      `aboutToAppear: pullDragging=${this.expandState.pullDragging} ` +
      `usable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*濞ｅ浂鍠氶弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鏈悺鏇犳嫚瀹ュ鈧浜告笟鈧鏉库柦閳ュ啿缍侀悘蹇撶箞閳ь兛绀佽ぐ鏃堝捶閵婏妇鎽冮悹鍥хС缁楀倿妫冮～顑藉亾?*闁挎稑顧€缁?
    //   濡炪倗鏁诲?*闁圭鍊藉ù鍥焽閿濆嫮顏遍柛?*閻忓繗椴告俊?閻忓繋绶氬鏉棵归鑲╂勾濡炲鍋犻、鎴炴交濞戞ê顔?閻庨潧缍婄紞鍫ュ礆閺夎法绉奸柛鎾崇Ч閵?闁炽儲鏌￠埀?閺夆晜鐟﹀Σ鎼佸嫉椤掑嫨鈧绮璺伇婵炲棌鍓濆﹢渚€寮垫潪鎵獥闁稿淇虹换鏍ㄧ閺堢數鐨戦柨?
    //   闁兼澘濂旂粭鏍偓鐟板暕缁?闁哄嫷鍨伴幆渚€宕ｉ幋鐘虫櫢閺夆晛娲ｇ粩鏉戔枎閳╁啰鎷ㄩ柛?闁哄啰濮撮崣褔鏁嶉崼銏″€為柣銏ｇ簿椤?`syncLyricMorphToPage()` 闁汇劌瀚伴弳鍗炩枖閵娾晛娅為柨娑橆槶閳?
    //   闁活潿鍔嶉崺娑㈡焽閿濆懐鐐婇柟鎼簻濞存ê顫㈤敐鍡樞﹂弶鈺傜懁闁叉粏銇愰姀銏犘﹂柨?*swiper 闁革负鍔嶉悺鏇犳嫚瀹ュ鈧濡存稊顤瞴ricMorphT` 閺夆晜蓱濡?0** 闁?濠㈠爢鍐闂?+ 婵繂鐭侀惁婵嬪触鐏炵偓顦ч柛锔哄妼濠р偓闁?
    //   闁宠法濯寸粭?闁衡偓閹勮含 `aboutToAppear`闁挎稑婢僼ruct 缂佺嫏浣插亾娴ｇ懓鐦弶鐐舵瀹撳棝寮垫径娑氱闁兼澘濂旂粭澶愬矗椤忓嫭韬柛鎰噹椤旀劗浠?`.onAppear`闁挎稑鐗愭俊顓㈡倷閸︻參鐛撻柕?
    //      闁告帒妫欓弫顕€鏌屽鍛处闁归潧绉风粣鍥晬婢跺棌鍋撻弬琛″亾?濞戞挶鍊曢ˇ鈺呮焾閸婄噥娲ｉ柨娑樿嫰濞叉粍绋夋潪鎷屸拡闁兼澘鎳忓鍌炲嫉鏉炴壆鐟濋柛姘焿缁辨瑩宕滃鍫氬亾閸涱喗锛嶅ù婊冮叄椤╄崵鏁缁旈浠﹂埀顒勬晬鐏炶姤鍊甸柤鏉挎噺濞呭嫭绂嶆惔銏犵槸閺夌偞鏋荤槐姘跺Υ?
    this.syncLyricMorphToPage('boot');
    // 闁?**闁煎浜濋崜?*闁挎稒淇洪～?`onDisAppear` 闂佹彃鐭傞崑鍛枔娴ｅ喚鍤涢柡?闁炽儲鏌￠埀?閺夆晜鐟ょ悮杈ㄧ▔椤忓懐鍨奸悹渚€顣︾粩鎾籍閿旂晫鏆欓柣锝嗙懕缁辨繈鎮欓悷鏉挎瘖闁瑰灚鎸哥槐鎴犱焊鏉堛劍顢嶉弶?
    //   閻犲搫鐤囩换鍐亹閵忕姴缍侀柛鎺撶箓椤劙宕犻弽鐢电闁告瑯浜濋幐閬嶆嚀娴ｇ袟闁汇垺鐪归埀顒€鍊界换鏍煂鐏炶棄鏅欓柛蹇旂矆缁斿浠﹂崒锔剧獥闁告瑯浜濆﹢?缁绢収鍠栭悿鍕捶閵娧勭畽闁归潧顑呮繛?闁挎稑娼恟ive=FINGER闁?
    //   闁归潧绉烽缁樼▔閻戞ê顤侀柟绋挎搐濠€顏呫仚閸楃偛袟闁挎稒绋栭埀顒€濂旂粭鏍础閸忓懎鈻忓┑鈥冲€归婵嬫晬鐏炶棄娑ч悷鏇氱閸戯紕绱掕箛姘辩畺濞?2 缂佸甯熺换鏇炩柦閳╁啯鏆悘蹇旀嫕缁辨繄浜搁崣妯碱伇閻庤纰嶅Σ绋库枔鐎ｎ剚娈?
    //   闁挎稑鐗呯粩鏉戔枎闄囩粣锟犲箥鐎ｂ晝鐟濋柛娆樺灥閸忔﹢骞愭担铏规暰闂侇叏绲肩粻鐐寸▕閸滃啰绀嗛柨娑樼灱濞插潡骞掗妷锔绢伕闁瑰搫顦埀?
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
    // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛弫銈夊箣閸戙倗绐?*闁靛棗鏈崹婊勭椤掑倹鐣遍弶鐑嗗灟濞嗐垽鏌屽畝鍕〃闁哄牆顦柌婊堟嚊椤忓嫮鏆板☉鏂款槸閻ㄦ繈妫冮姀鐘冲閻熸瑦甯婄弧鍐礆閻樿京鍟婇柛姘€浣插亾?*闁?
    //   闁告鍠愬鍨交濞嗗海顏遍柛娆嶅劜濡?`= MusicStoreService.getInstance().getCoverCornerRadius()`
    //   闁炽儲鏌￠埀?閻犱礁澧介悿鍡樸亜閻㈢浜濆☉鎿冧簵閳ь剙鑻惃婵嬫閵忕姵濡囬悷娆愬釜缁辨瑩鎯勭壕瀣垫健/閻?濞?濠?閻℃帒鎳庨妵鍥晬婢跺牃鍋撳澶嗗亾濮樺磭绠栭悗鐟板暢缁绘ê銆掗崣澶屽帬闁?
    //   闁绘粍婢樺﹢顏堝捶閸℃凹娼￠柛娆樹簼濠€?*濞戞挴鍋撳☉鎿冧簼濞奸潧鈹?*闁挎稒纰嶅Λ銈夋偩?`CoverMorph.radiusPlayer = 8`
    //   闁挎稑娼塒layerExpandState.COVER_RADIUS_PLAYER_VP`闁挎稑顦崳?閻犱礁澧介悿鍡涘磹闂傚鐟濋柛鎰Т瀵剚绋夋惔婵囧床濞达絾娲樼憰鍡涘蓟閹炬墎鍋?
    //   闁宠法濯寸粭?閺夆晜鐟ょ粩鎾矗閵夈儳绠戝銈堝吹閺嗏偓闁活偀鍋撻柨娑樼墛婵℃悂宕楅崣姗€鐓╅柣妯垮煐閳ь兛绀佺敮鍥炊閻愬弶鍊ゆ繛澶嬫礀閳ь剛銆嬬槐姘舵晬濮濇overRadiusState` 闂佹彃鑻ぐ鏌ユ嚄閼恒儳鏆欓柣锝嗙懄濡偊宕愮粭琛″亾?
    this.coverRadiusState.radius = PlayerExpandState.COVER_RADIUS_PLAYER_VP;
    // 闁?婵炵繝绀侀崢婊堟嚄鐏炵偓鐝€殿喒鍋撻柛蹇曨劜缁?*闊洤鎳橀妴蹇涘捶閵娿劎绠归梺鎻掑缁娀骞愭担椋庣暯闁告牗鐗曢悺銊╁磼閵娧傛崓閺?V2 闁绘鍩栭埀?*闁?
    //   閻犱礁澧介悿鍡樸亜闂堟稑娑ч柛锔哄妸閳ь剙鐬奸弫銈夊箣瀹勬澘鐎奸柟骞垮灩缁辨垿宕楅悙瑙ｅ亾瀹ュ棙顦ч柛?`PlaybackFlowLightState`闁挎稑鑻崰搴ㄥ触椤栨艾袟闁哄啳鍩栭惀鍛閾忛€涙崓闁?闁?
    //   闁绘鍩栭埀顑跨窔缁垳鎷?false闁挎稑鑻畵鍡樻媴閼愁垼鍟庣紓鍐惧櫍閸ｇ兘寮?鐎殿喒鍋?濞戞梻鍠愬鍫熸交濠娾偓缁楀鎮界紒妯笺偊闁稿繐顧€缁辨瑩鎮介妸锕€鐓曢柛娆忕Ч椤╊參鎯?婵炵繝绀侀崢婊堟嚄鐏炵偓鐝☉鎾崇Ф閺佹捇寮?閻忓繗椴稿Σ鍛婃交濞嗗酣鍤嬮柨娑橆槶閳?
    //   濞?`AmllLyricView`闁挎稑鐗愰崵婊冾啅閸欐鐭?store 闁?fps/閻忕偛鎳嶉懙?闁告搩鍨遍悺鏇犳嫚瀹ュ繒绀嗗ǎ鍥ㄧ箖鐎垫棃宕ョ仦鑲╊伇濠靛倹顨呮禒娑樷枖閺囨ǚ鍋?
    this.flowLightState.enabled = MusicStoreService.getInstance().getPlaybackFlowLight();
    // 閳藉應妲勯埥鍛 2026-10-17閿?*閹?娑撳﹣绔存＃鏍殌娑撳娈戝ù浣稿帨閻偓閼?鐟欏棔璐熷鍙夌Х閸?* 閳ユ柡鈧?娣囶喓鈧苯鐫嶅鈧潻妯绘Ц娑撳﹣绔存＃鏍畱妫版粏澹婇妴宥忕礆
    //   `coverTint` 閺?`AppStorageV2` 閸忓彉闊╅悩鑸碘偓渚婄窗閹稿倽娴囬柇锝勭閸掕鐣犻惃?`version` 瀹歌尙绮￠弰?*娑撳﹣绔存＃?*閻ｆ瑤绗呴惃鍕┾偓?
    //   閼板本婀版い?`appliedTintVersion` 閸掓繂鈧吋妲?-1 閳?`@Monitor('coverTint.version')` 娑撯偓娑撳﹥娼电亸鍗炴嚒娑?
    //   閳?`applyFlowLightColors()` 閹?*娑撳﹣绔存＃?*閻ㄥ嫰顤侀懝韫瑓閸欐垹绮伴惈鈧懝鎻掓珤閵嗕礁鑻熼幎?`tintReady` 缂冾喚婀?
    //   閳?闁綁浜?缁涘缍嬮崜宥堢箹妫ｆ牜娈戞０婊嗗"閻ㄥ嫰妫ぐ鎾虫簚鐞氼偆绮潻鍥风礄娑撳﹣绔撮悧鍫濇皑鐠愩儱婀潻娆撳櫡閿涘鈧?
    //   閳?閹稿倽娴囬弮?*閸忓牆顕?*閿涙碍濡歌ぐ鎾冲 version 鐠佺増鍨?瀹稿弶绉烽崠?閿涘畭tintReady` 娣囨繃瀵旈崑鍥风幢
    //     娑斿鎮楅崣顏呮箒 `extractFlowLightColors()` 娑?*瑜版挸澧犳潻娆庣妫?*閸愭瑥鍤弬鎷屽閿涘澊ersion 閸愬秷顫﹂幒銊╃彯閿?
    //     閹靛秳绱伴惇鐔割劀娑撳褰傞獮鑸垫杹鐞涘矂鍋呮稉鈧仦鍌樷偓?
    this.appliedTintVersion = this.coverTint.version;
    this.tintReady = false;
    const song = this.state.getCurrentSongItem();
    this.releaseBackgroundCoverIfPixelMap();
    this.imageLabel = song !== undefined ? song.label : $r('app.media.ic_avatar1');
    this.applyKeepScreenOn(true);
    // 濡炪倗鏁诲浼村箥閹惧磭纾婚柡鍐硾椤┭囧几濠婂啫鍤掗柡鍫濐槹濠€顓熸交閸ャ劍鍩傞柣銊ュ閾嗘鐐叉嫅缁辨繄绮╃€ｎ亜绁悷娆欑畱瑜板倸銆掗崨顖涘€為悹浣插墲濡炲倿濡?
    if (this.switchBanner.ts > 0) {
      this.onBannerChange();
    }
    // 闁?閻忕偞娲栫槐鎴﹀礉閵娧勬毎闁挎稒鑹鹃崢娑㈠捶?`aboutToAppear` 闁硅泛锕ㄧ换妯绘償閿旇姤鏉归柛?闁衡偓閹増宕?闁?*濞ｅ洦绻嗛惁澶岀箔椤戣法顏遍悽顖嗗懏鏆伴柛鎴犲劋濞肩數浜告潏銊π﹂悹鎰綑缁ㄦ娊鎯冮崟顏嗩伇闁?*闁?
    //   濠碘€冲€归悘澶愬绩閹冪厒 `onAppear` 闁告劕绉堕悿鍡涙晬鐏炶偐绐楅柛蹇撶墛鐟曞棝寮婚幘鍐叉瘔濞戞挴鍋撻悽顖嗗啰鏆氶柡浣哥摠閹搁亶寮ㄦィ鍐︹偓澶愬礃瀹ュ棙鏆柛銉у仜楠炴捇鏁嶅畝鈧﹢鍛存儓閳ь剛浜告潏銊π﹂梻鍌や簷缁斿瓨绋夌€ｃ劉鍋?
    //
    // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*濠㈢懓鍟块惇鏉款啅閼碱剛鐥呴悹褑娓圭花陇銇愰姀鐘茬秮闁哄啳顔愮槐婵囨交濞嗗海顏辨俊妤嬬导缁楀鎷嬬粙鍨櫃闁?*闁?
    //   闁哄啰濮烽弲顐︽儍閸曨偆娼旂€殿喒鍋?*闁告瑯浜濆﹢浣圭▔閳ь剚绋夐鍕楅柣銏ｎ唺鐎?* 闁炽儲鏌￠埀?濠㈢懓鍟块惇浼存儍?`ExpandAnimation.doEnter`闁?50ms闁挎稑顦甸埞宥夊礉閵婏附娈诲銈囨暩濞?
    //   `scale/translate/clipWidth/clipHeight`闁挎稒绋掗幐閬嶅绩妤ｅ啨鈧鎳涢鍕畳**婵炲备鍓濆﹢?*缂佹鍏涚花鈺傜附?閻犳劖娼欑花铏▔閳ь剟寮堕敓鐘虫瘣濞戞挸锕ュ?闁?
    //   闁?`collapseProgress` 閺夆晜鐟ラ〃婊堟晬閸繂鏁堕悗鍦嚀閻?`height` 濞寸姴姘﹂崚娑欐償閺囨氨顏遍柡澶涚節閺嗛亶宕?100%闁挎稑顦板Σ?*婵炴煡绠栭悡鍫曞籍瑜戦惌?*闁?
    //   濞戞挶鍊栧顖炲触鐏炵偓顦ч柛锔哄姀缁愬洨浜告潏銊π﹂柣顫妽閸╂稓鈧湱鍋炵粊鎾儍閸曗斁鍋撳畝鈧崑锝夊礄缂佹ê鈪电€殿喒鍋撻柟缁㈠幗閺備線宕抽妸锔炬⒕闁哄牆顦慨鈺呮偨?/ 闁煎啿鏈▍娆愮▔瀹ュ拋鍤犻柕鍡楃▌缁?
    //   濡炪倗鏁诲鎵偖椤愶絾锛嬮悹渚灡鐎?閻犳劖娼欑花铏▔閳ь剟寮?閻犙囨敱婢ф粓鏁嶅畝鍐ｅ亾鐏炲€熷煂闁告瑦顭囧▓鎴犳導妞嬪骸浠柛鎴犲С缂嶅秴顔忛懠顒傜梾閻炴凹鍋勯敍鎾朵沪閸屾稑鐦婚弶鈺勬腹缂嶆﹢寮堕檱閸忓矂宕舵繝鍌氱濠靛倹鍨濈花锟犲Υ?
    //   闁告帇鍊栧畵渚€鎮?`morphContainerActive()`闁挎稑婢僼age 闁?ENTERING/LEAVING/LANDING闁挎稑顧€缁辨壆鈧懓鍟﹢?
    //   `pullOpenBegin()` 闂佹彃鑻銊х磾椤旂鍋ㄥù婊冩４缁辨繈鎳撶仦鏂ょ处閻忕偛鍊瑰Σ?*闁?begin 闁?pushPath**闁挎稑鐗嗛顕€寮介崶銊︼骏闁?
    //   `beginMorphEnter` 闁告劕鎳橀崕鎾嚊椤忓嫮绠?push 闁汇劌瀚伴妴搴㈡償韫囥儳绀嗛柍?`aboutToAppear` 閺夆晜鐟ょ粩鎾礆閺勫浚鍤㈤柛鎺撳濞堟垹浜告潏銊π﹂柣顏嗗枔濞村濡?
    const shellOwnsMorph: boolean = this.expandState.morphContainerActive();
    if (shellOwnsMorph) {
      this.collapseProgress = 0;
    } else {
      this.collapseProgress = PlaybackPage.EXPAND_START_PROGRESS;
    }
    this.dismissMorphActive = false;
    // 闁宠棄鎳夊Σ?2026-10-15闁挎稒鐡猧sClosing` 闁?`onDismissDrag()` / `closeFullScreenPlayback()` 闁?*缂佹鍏涚粩鎾焼閹剧粯顦?*闁?
    //   閻庣懓鍟╃粩鎾籍閿旂晫鏆欓柣锝嗙懄閸?true闁挎稑濂旂粭鍛村箯婢跺鏆悹褑娓圭粭宀勫礂閹惰姤锛旈柟绋款樀閹稿磭浜搁崡鐐茶摕闁告瑥鑻妵鎴﹀极閸剛绀勯悹鍥风畳椤?`closeFullScreenPlayback()` 闂?
    //   闂侇叏绲惧?`morphGenAlive` 闁哄啠鏅犻埀顑藉亾闁告帒妫欓弫顕€鎯冮崟顔㈠顭宠箛鏃€鏆堥梺鎻掝煭缁辨岸濡撮崒娑樼槸閺夌偠濮ゅ?*闁哄啰濮靛顖涚?*婵炴挸鎳嶇粩鏉戔枎閳藉懐绐?
    //   闁哄倻澧楃€垫洘娼悾灞剧暠濡炪倗鏁诲鐗堢▔瀹ュ懎璁查柤?婵繐绲藉﹢顏堝绩閹増宕?闁挎稑濂旈幑銏℃媴閺囩喓鏆欓柣锝嗙懇閸忔﹢宕ｉ鍕闁煎疇濮ゅ鐢告嚊椤忓啰鐟愬☉鎾亾閺夌儐鍠楀﹢顓犳導閺夎法鏆氶柣銊ュ缁辨壆鎷犲┑鍕ㄥ亾?
    this.isClosing = false;
    // 婵絽绻戦濂稿箥閹惧磭纾婚梺顔荤矙閸ｅ摜绱旈鈧崳鍝ユ嫚閺囥埄鏉洪幖杈捐缁辨瑩鎮¤婵?`schedulePublishRetry` 闁?12閼?2ms闁?
    this.morphRetryLeft = 12;
    // 闁?閻庡湱鎳撳▍鎺曘亹閵忕姴缍侀梺顓ㄧ稻濞碱垳鎹勯銈囩閻庝絻顫夐悥锝夊籍閻樺灚娅?ExpandAnimation闁挎稑顧€缁辩増绋夊鍡樞﹀☉鎾筹攻婵椽骞忔径搴ｇ闁哄鍎冲▓鎴︽晬閸垹浠柛?/ 閻犙囨敱閹搁亶骞囪箛鎾寸闁瑰灚鎸哥槐鎴︽晬?
    //   閻?*閻忓繐宕﹢?*閻犙嗘腹缁旀潙鈻庨垾瀹犲煂闁?闁炽儲鏌￠埀?闁告垹濮崇紞宥夊储鐎ｎ亜鐓傞悹褔顥撻崑锝夋晬閸?= 0 = 閺夆晞娓圭紞姗€寮堕垾宕囨闂傚牄鍨介崑鍛▔閳ь剛浜歌箛鎾村仴闁挎稑顧€缁?
    //   濞存粌瀛╁Σ鍝ョ箔椤戣法顏遍悽顖嗗懏鏆伴柛鎴犲劋濞肩數浜告潏銊π?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼闂佹彃鐬煎▓鎴炵▔閳ь剛浜歌箛鎾村仴"闁挎稑鐭佽棢闂傚倹娼欏﹢?`onAppear` 闂佹彃鐭佺粣鍥Υ?
    //   闁宠法濯寸粭?閺夆晜鏌ㄥú?false 閻犲洤鐡ㄥΣ鎴﹀礄閻樿京绉挎繛宀嬬節閸ｇ儤顬囬幇鍓佺閺夆晞娓圭紞姗€寮堕垾宕囨闂傚牄鍨洪惀鍛▔婵犲啫袚 / 閻庣懓銇樼€靛苯鈻介垾铏閻庣敻娼荤槐姘舵晬濮橆剛绠戝銈囩帛婵℃悂鎯勯梹鎰Т闂侇偀鍋撻柛銉у仜楠炴捇鏁?
    //      闁告熬绠戦崹?`sheetHeightPercent()` 濞村吋鐭粩鎾儎绾惧绠查柛?100%闁挎稑鐭侀埀顑挎祰閻儳顕ラ崟顓熺暠"閻犳劖娼欑花铏▔閳ь剟寮堕敓鐘虫瘣濞戞挸锕ュ?濞戞梻鍠曢～锕傚础閳╁啫绔撮柨?
    //      闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣銊ュ濮樸劑寮?闁绘劗鎳撶槐鎴﹀箻椤撶喐鏉归柛锝冨妽閻ュ懘寮垫径澶嬪床濞达絾娲栨慨鈺呮偨?闁?
    // 闁?**濞戞挸绉烽々锕傚捶閵婏箑鐦弶鐐跺Г濡炲倻浜告潏銊ノ╅柛鎴犲С缂嶅秹宕㈢€ｎ亜鐓傞悹褔顥撻崑?*闁挎稑鐗愮换鏍ㄧ▔閳ь剟寮堕埄鍐┬﹂柡鍐Х閺?`expand.init` 闁汇劌瀚伴妴搴㈡償韫囥儳绀夊☉鏂款儏婢х娀鎯冮崟顐＄驳婵炲娲栧鑺ョ閸☆厾绀嗛柨?
    //   闁告瑥绉剁槐顏嗘嫚閹达箑娅?`setupExpandTransition` 闁?**闁稿繐鐗撻崳娲儎椤旂晫鍨奸柤鍝勫€婚崑锝夋儗閳轰浇鍩?*闁挎稑鐗婇婵嬪礆缂佹ɑ灏￠柡鈧ィ鍐︹偓澶嬫交濡崵姊剧紓鍌楁杺閳ь兛鐒﹀Σ鎼佸储閻旈攱妲€閻庣敻娼荤槐?
    //   闁?闁?start 鐟滆埇鍨硅ぐ?闁靛棗鍊归崹婊堝储閻斿憡闄嶉柛?`aboutToAppear` 閻?`morphBeginEntering()`闁? 缂佹柨顑呴崺銏㈢磽閳轰礁鐓傞悹褔顥撻崑锝夋晬婢舵稓绀?
    //   濞存粌瀛╁Σ鍝ョ驳婢跺﹤鐓傞柤鍏呯矙閸ｆ椽鎯冮崟顒侇槯闁稿﹥鐟辩槐婵嬫煂韫囨挸鐓傞柣銊ュ濡?*閻炴凹鍋勭敮鍥箥娓氣偓閸嬪懏绋夐埀顒傛暜?*闁汇劌瀚惃婵嬫?闁炽儲鏌￠埀?缂備礁鐗忛崑锝囦焊鏉堫偒娼堕柛鎰懃濞兼牗绂嶉崱顓犵獥
    //   "缂佹鍏涚粩鏉戔枎閳╁啰姊鹃柡鍫濐槸閻ㄦ繈妫冮姀銈庢＇闁?闁?缂備焦鎸诲顐﹀籍鐠烘亽浜ｉ悘蹇撶箣缁楀鈧?闁?闁告瑯浜炰簺闁告柣鍔嬬粭澶岀磽閳哄倹鏉?闁稿繈鍔嶅Σ鍛婃交濞嗗海顏遍柡澶嗏偓宕囩┛閻犙囶棑濞堟垿濡?
    //   闁绘粍婢樺﹢顏堝绩鐟欏嫬鐏囬柨娑欑鐎垫洘娼禒瀣枆婵炲牆鍚€缁牊绋婇崼銉ュ幋濞戞挸绉存禒娑㈡晬瀹€鈧弫?`playExpandIntro()`闁挎稑娼祅Appear 閻犙冨殩缁辨繄鏁?12閼?2ms 闂佹彃绉烽惁顖炴晬?
    //   闁?*濡絾鐗楅濂告煂韫囨挸鐓?*闁汇劌瀚伴崑鍛▔閳ь剟宕氱紒妯侯枀 `measureMini` + `morphBeginEntering()` 闁炽儲鏌￠埀?闂佹彃绻掑▓鎴﹀及椤栨艾鏂ч悘蹇撴惈椤曨參鎯岄埡浣藉煂闁?
    //   缂佹瘱鍕闁活偀鍋撻柛姘缁斿鏁鐢洭宕氶幏灞惧闯闁绘劗娅㈢槐娆撴煀瀹ュ懏鍊ゅ☉鎾愁儔濞间即鎯?`introPaintReady` 闂傚偆鐓夌槐婵囩▔瀹ュ嫮绐楅梻鍌や簻閸ゎ厾鈧懓鏈弳锝夊箻椤撶喐鏉瑰銈囶暜缁辨岸濡?
    // 闁宠法濯寸粭?闁活亜顑夊Λ顒勬偑濡ゅ绐楀☉鎾虫矗缁斿瓨绋夌€ｎ喗妗?`onAppear` 闂佹彃鐬煎▓鎴犳偘閵夆晜锛熼柛銉уС鐠愮喐绂掔拋宕囩Э闁告鍠庡ú婊冣柦闄囩粣鍥╂導闁垮闄嶉柨?
    //   閺夆晜绋戠€瑰磭浜搁崣妯肩獥婵ɑ鐡曠换娆撳磻濠婂啯韬?闁衡偓閹増宕?闁挎稑鐬奸弫銈夊箣妞嬪孩绠欓柛鎺撳濞堟垿寮伴娑樷叺濞戞挸绉寸槐鎴﹀箻椤撶喐鏉归柛锝冨妸閳?
    //   闁哄牃鍋撻弶?COLLAPSE_WATCHDOG_MS 濞戞柨顑呴幃妤€顕ｉ崫鍕厬闁搞儳鍋涢崺宀€鈧懓鏈弳锝夊箑?闁炽儲鏌￠埀?閻庨€涚瑜版彃鈻介埄鍐╃畳闁告柣鍔庨弫楣冨Υ?
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
   * 闁稿繑濞婂Λ鎾媰閹存帞绉村☉鏂款儏閹鏁?*缂佹稑顦伴幐閬嶅绩妤ｅ啨鈧鎯囬悢鐑樼暠濞寸姴姘﹂惌楣冩偨鏉堛劎鍨介梺鎻掑缁楀懘宕ｇ敮顔剧闁告劕绉撮ˇ鍙夋媴瀹ュ懓鍩岄柛娆惷崵鎴炴媴?*闁?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸粎鐟濋柤瀹犳濠€顏堝触鐏炶偐顏?tick 闂佹彃鑻ˇ鍙夋媴瀹ュ繒绀勯柣顫妽閸╂稓绮?闁?闁哄绱曞▓鎴﹀嫉閸濆嫬鐓戦柨?
   * 闁稿繑濞婂Λ鎾绩鐠鸿櫣鍟查柛妯煎枑濞肩敻寮?`isShowPlay = false`闁挎稑鐗冮崯?濠㈢懓鍟块惇?`@Monitor` **鐎殿喖鍊归?* pop闁?
   * 缂佹瘱鍡欘€€闁活偀鍋?*闁告艾鏈?* `morphReset()`闁靛棗鍊介埀?`morphReset()` 濞?
   * `morphStage = NONE` + `morphP = 1` + `morphClipHeight = 0` + `morphScale = 1`
   * 闁?閻庡湱鎳撳▍?*濞戞挸绉烽ˉ鍡涘礈椤忓倵鍋撴担椋庣憹缂傚倵鏅滈弬?* = **婵犲ň鈧磭娼岄柟缁㈠幗閺備焦銇?*闁?
   * 閻犱警鍨抽弫閬嶅础绾惧娲ｉ柛鎺楊暒缁楀懏绋夐埀顒傛暜瑜庢晶鐘垫偖椤愶絾鍠呴柟鍝勵檧缁辨獋@Monitor` 婵炲弶鍎宠ぐ鍌涚▔閳ь剛浠?+ 閻㈩垰鍟惇顒勫箺濮椻偓濞呭孩绋夐埀顒備沪閸岋妇绀?
   * 闁?濞戞搩鍙冨Λ鍧楁焽?1~2 閻㈩垎鍐╃殤闁?鐎规瓕灏欑划锛勭磽閳哄倸鐏囬悘蹇撶箰濞撻箖鎮?闁?缂佹劒鑳堕崝褍顭ㄩ垾宕囨綄 闁?婵炴垵鐗嗛妵?闁?
   * 闁活潿鍔嶉崺娑㈠箵韫囨艾鐗氶柟瀛樺姂閳ь剙鑻慨鈺呮偨閼姐倗娉㈤柡澶屽枍缁?*缂佹劒鑳堕崝褔寮堕妷銈夊殝閻忕偞娲栫槐鎴﹀箻椤撶喐鏉归柛锝冨妿濞堟垿宕濋妸褎鏆?*闁靛棗绉查埀?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕?闁哄懏鐭粩鎾倷閻熼偊妲诲ù?闁哄嫷鍨伴悾銊╁礂閵娧勭暠
   * `morphLand()` 鐎规瓕灏欑划锟犲箮婵犲嫮甯涢柛鎺曞煐濞煎牊绂嶉妶鍫㈢缂備焦鐟ㄧ化鐘虫媴閻樿櫕钂嬪ù婊冩４缁辨繈鎳?閻炴凹鍋夐ˉ鍡涘捶閵娿劎纰冨ù锝囧У濞碱垶鏌囬敐鍕杽濡?闁汇劌瀚伴崑鍛▔閳ь剚绂掗挊澶婃濞?
   * **闁革负鍔戦妴澶愭椤厾鐟撻柛娆擃暒缁狅綁宕滃鍡╁妧闁哄嫷鍨遍婊呮兜椤旂偓鐣遍柡鍕⒔閵囨岸鎮╅懜纰樺亾?* 闁?濠㈣泛绉崇紞鍛柦閳╁啯绠掑ù鐘侯唺缂嶅秹鎮堕崱娆愭殸闁硅翰鍨瑰﹢?pop 闁告挸绉瑰浼村Υ?
   * 闁告瑥绉风换鍐级閵夘垳绀?*濞戞挸绉撮ˇ鍙夋媴瀹ュ嫮绐楁慨鍏夊墲閻撳绋夌€ｂ晝顏遍弶?*闁挎稑鐗嗛崵鎴炴媴閺囩喎鐦柛?AppStorageV2 濞戞挸锕ュΣ鎼佸礂閸欐﹢鐓╅柣銊ュ缁辨岸鍩?闊洤鎳橀妴蹇斿緞瀹ュ嫮绉撮柨娑樿嫰瑜把囧及椤栨繍娲ｉ柡鍛搸閳?
   *
   * ## 闁告帇鍊栧畵浣圭▔鏉炴壆鐭嗗☉鏂跨墢閺?闁煎搫鍊婚崑?閻犱警鍨抽弫閬嶆焾閹存帞鐟撻柛娆擃暒缁?闁兼澘濂旂粭澶愬及椤栨碍绁奸悗瑙勮壘濞嗐垽寮?
   * 闁搞儱鎼悾鎯ь嚈閼稿灚顦ч柨娑樼墔缁躲儲淇?64ms闁挎稑顦ぐ褔寮?*閻?* pop 婵絾鏌ㄩ悾鐘虹疀椤愵剛骞㈤悹褍鐭佺欢顓犱焊鏉堛劌鈧捇骞冮崟顖楀亾閳ь剟宕堕悙鎻掓枾 bug闁?
   * 濞戞挶鍊撻柌?*闁烩晛鐡ㄧ敮瀵告嫚缂佹ɑ娈?*闂侇喖鈧噥娲ｆ繝濞愩倕鍠曢柟闈涚Т椤﹀弶鎷呭蹇曠闁搞儳濮崇拹鐔煎础閺囩姵绠欏☉鎾亾濞戞搩浜崗妯诲?濠㈣泛绉崇紞鍛嚗濡も偓閵囧﹪寮?闁?
   * 鐠?`!this.isAlive`闁挎稑鐗愭俊顓㈡倷閸︻參鐛撻柨娑橆槴閳ь剚鏌￠埀?`onDisappear` 闁哄嫷鍨垫俊顓㈡倷閸︻厽鍩傞柣銊ュ缁夐攱寰勬潏銊︻槯闁归潧绉疯闁告瑦鍩婄槐?
   * 鐠?`!playerRouteStillPushed()`闁挎稑鐗愰惌楣冩偨鏉堚晠鐛撻柨娑橆槴閳ь剚鏌￠埀?闁告瑱绲界欢鐐寸▔鎼粹槄绱﹂悘?`playerRouteIndex()` 闂侇偅鍔曢悺褎绋夐埀顒勬嚊濞ｎ兘鍋?
   * 闁宠法濯寸粭?闁告瑯浜炲﹢鍛崉椤栨粍鏆犲ù?*濠㈤浜濆Λ?*闁挎稒鐡猵op()` 闁告瑯浜濆Σ鎼佸绩?`NavPathStack` 闁?*闁轰胶澧楀畵?*闁?
   *    闁煎搫鍊婚崑锝夋儍閸曨剚鍠呴梻鍕╁€涢々锔剧驳婢跺鐟撳☉鎾亾婵?layout 闁?閻犱警鍨抽弫鍗烆啅闊厾鐟撻柛娆掑焽閳ь兛娴囨俊顓㈡倷绾懐绠烽柛锔哄妼閻棙绋夋繝鍕暠闂侇叏绲肩粩瀵告暜瑜庡Σ鍝モ偓娑櫭﹢顏堟儍閸曗斁鍋?
   * 闁宠法濯寸粭?闁告瑯浜炲﹢鍛存嚍閸屾粌浠☉鏃傚枍缁?*濠㈤浜濆Λ?*闁挎稒鑹鹃崣褔姊婚鈶╁亾閺傛崘鍘柣?闁告帒妫欓弫顕€鏌屽鍛处"闁告艾鏈悧杈ㄥ濮樻壙鏇㈠矗?`onDisappear`闁挎稑鐗婂﹢浼村棘閸ワ附顐?5000+ 閻?
   *    闁汇劌瀚弫鐐烘煂婵犱胶鐟╅梻鍌樺姀椤斿娼婚崶顏嗙濞寸姵婀圭花銊╂晬婢跺棌鍋撻弬琛″亾?闂侇叏绲惧鍌炴嚍閸屾粌浠弶鈺偯肩槐浼村炊閻愬瓨闄嶉柕?
   * 闁?濞戞挶鍊涢埀?*闁告艾鏈?*闁瑰瓨鍔楅悵娑㈠箥瀹ュ棙笑"闁活亞鍠撳▓鎴犳導妫颁胶鍟?闁挎稒绋戦崯鈧柛?`attempt >= RESET_POLL_MAX` 闁稿繑绮岀花鎶芥晬?
   *    濞ｅ洦绻嗛惁?闁告繍浜濋埀顒佹磻鐞氳鲸绋夐鍥跺殺闁轰椒鍗抽崗姗€宕歌箛鏂跨闁挎稑鑻崵鎴炴媴閺囨氨鐦嶅☉鎾亾閻庤鐭槐鎵偖椤愩埄妲诲ù?闁挎稑鐗嗛悾鐐哄矗椤栨稒鐝撻柨娑樺缁楀宕ｉ娆戠憹婵炴挸鎷戠槐姘跺Υ?
   *
   * ## 濞戞挶鍊濇禍鍓р偓鐟扮墕瀹曞ジ鏁嶉崼銏犵箒濞戞挴鍋撳☉鎾崇Т瑜版煡鏁?
   * 鐠?`closeGen !== this.closeGen`闁挎稒淇虹换鏍ㄧ▔閳ь剚娼鐓庡綘闂傚偆鍘奸崙锛勬偖?濞戞挸顑勭粩鏉戔枎閳ュ啿褰犻梻鍌ゅ弨椤曨剙效?闁告瑦鐗旈崬?闁?闁告帩鍋呯粩濠氭晬?
   * 鐠?`!morphGenAlive(resetGen)`闁挎稒鑹鹃崵鎴炴媴閺囨氨鐟ù鐙呯到瑜板灝顔忛懠顒傜梾闁告瑦眉缁?闁?鐎规瓕灏欑划锟犲嫉婢跺﹤鐒煎ù婊呭皑缁辨瑩寮０浣侯伇閺夌儐鍠楁晶锕€顕ｉ埀顒勬儍閸曨喖娈伴柟?
   *   `staleClr` / `leakClr`闁挎稑顦扮粩缁樻交閸パ嗗珯闂佹彃绉寸紓鎾寸閸℃洜绐楅悹?闁?**闁告劕绉电粩缁樼▔閳ь剙鈻庨垾铏殤濞村吋纰嶆俊鎼佸礆濮樿櫕宕抽柣銊ュ缁辨壆鎷犲┑鍥х瑢婵?*
   *   闁挎稑鐗撻崑鍛潰閿濆棙笑"闁绘劗鎳撻崵顕€骞嶉幘宕囩；婵炲备鍓濆﹢渚€宕濋妸褎鏆?闁汇劌瀚崹姘跺炊閻欏懐绀嗛柕?
   *
   * @param closeGen 闁硅娲濋獮蹇涙嚊椤忓嫬褰犻梻鍌ゅ弨閹癸綁骞嶇€ｎ剚鐣遍柛蹇斿▕濡瓨绋夐弽锕€鏁╅柛?
   * @param resetGen 闁硅娲濋獮蹇涙嚊椤忓嫬褰犻梻鍌ゅ幗閺佸湱浜告ィ鍐ㄤ簼濞戞挴鍋撻柛鎺曞吹濞堟垼銇愰姀鐘茬秮濞戞挻鐗旈崬顒勫矗?
   * @param attempt 鐎规瓕灏欑划鈩冩姜椤旀鍤勯弶鈺佹搐閸ゆ垵鈻庨埥鍛闁告劕鎳橀崕鎾焻閹烘垹绉洪柣銏╃厜缁?
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
      // 闁?2026-10-17闁挎稑鐗忛弫銈夊箣闁垮袚闁靛棗濂旂粭鍌炲箯婢跺灏￠柡鈧悙顒佽拫闁告劕绉村ú鏍储娴兼瑧绀夐柟缁㈠幗閺備線寮堕垾鍐茬秮闁?*缂佺虎鍨垫竟濠囧础婵犲洠鍋撹箛鏃€顫?*闁靛棗绉崳?闁?閻犲绀佸﹢顏堝础閻樺灚绲婚弶鈺勬腹缂嶆﹢寮堕敍鍕暠
      //   缂備焦锚閸╂寮?濞戞梻鍠愭晶锔芥交濞戞粎绠瑰☉鎾亾闁哄妲勭槐姘舵晬濮濇瓬ar=` = `sourceBarHidden`闁? = 閺夆晞娓圭紞姗€寮堕埄鍐╂闁哄銈庢蕉闁芥ê绻楅幑锝夊级閵夈倗鍟婇柨?
      //   婵繐绲介悥鑸垫償閺傝法绉奸柡?**0**闁挎稑顧€缁辩浗ovl=` = 濠㈢懓鍟块惇鏉棵归鑲╂勾闂侇叏绲肩粩鏉懳涢幒鏃€鐣遍弶鈺傜☉鐎规娊鏁嶉崸鍒磑rphOverlayP`闁挎稑鐭傚銈咁潰閵忊檧鍋撴担鍝ュ畨鐟滅増鎸诲Σ?1闁挎稑顧€缁?
      //   `own=` = 闁稿繐鍟╂穱濠囧箒椤栨艾甯梻鍛閻即寮伴姘剨閺夆晜锚瀹曚即鎯堥埀顒傜磼濡搫鐓戦柡澶婂枦缁? = 閺夆晜锚濠€顏堝础?闁?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞寸姾濮ら悺鏇㈠触瀹ュ牜娼堕柛妯侯儐閸?0闁挎稑顦埀?
      //   闁宠法濯寸粭?閺夆晜鐟ラ崵鎴炵▔椤忓牆娅?*闁告瑯浜滃﹢顏呮交濞嗘挸娅￠悹?*闁挎稑娼塵orphReset()` 闁告帗鑹鹃崹浼村箮婵犲倻鏆婂ù鐙€鍓欑紞濠冩媴瀹ュ繒绀嗛柨娑樻湰婢у秵绂掗妷銉ф殜闁告瑥绉靛Σ褔鎯冮崟顒佇?
      //   "闁衡偓鐠鸿櫣鍟查柛瀣壘閻ｎ剚绋婄€ｎ亝鍊?闁汇劌瀚﹢锛勨偓鍦仧婵悂骞€?闁炽儲鏌￠埀?闁活潿鍔嶉崺娑欑▔鐎ｎ偒鍋ч柟鍨尭缁辨垵顕ラ懞銉у灱閻忓繗绮鹃崗姗€鎯囩€ｎ亜鐓傚☉鎾筹梗缁旀潙鈻庨垾鍐插綘闂傚偆鍘鹃弳鈧☉鎾愁儎缁ㄢ剝绂掗埀顒佺▕閸稈鍋?
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
   * 闁圭虎鍘介弬浣广亜娴ｅ啰鐔呴柣?*闁哄嫷鍨伴幆浣规交濡儤韬鐟板暱閻即鎯?`NavPathStack` 闂?*闁?
   *
   * 闁?2026-10-16 闁哄倹婢橀·鍐晬閸繃鏆滃☉鎾亾閻犲鍟伴弫銈夋倷閻у摜绐梎.onDisAppear()` 闂佹彃鐭傞崑鍛存焼?`isShowPlay` 闁稿繑绮岀花鎶芥⒒椤帞绀嗛柕?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸儲浠橀悷鏇氱閻?
   * `isShowPlay` 闁?*濠㈢懓鍟块惇鎵崉椤栨粍鏆犻柣銊ュ閳瑰秹宕濋妸锔剧埍**闁挎稑娼塈ndex.@Monitor('appState.isShowPlay')`
   * 闁?`popPlayerRoute()`闁挎稑顦埀顒€鍊介埀?`.onDisAppear()` 闁?*闁煎搫鍊婚崑锝囩棯?*闁搞儳鍋犻惃鐔兼晬鐏炶偐绐楅柛?
   * "闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁哄啳鍩栧Λ顐も偓鍦仒缁躲儵宕″灞剧グ / 闁告帒妫欓弫顕€鏌屽鍛处"閺夆晜鐟ょ花娲捶閸濆嫭鍊?*濞?*閻熸瑱绠戣ぐ?闁炽儲鏌￠埀?闂侇叏绲惧鍌炲箻椤撶喐鏉瑰銈勭祷閻箖鎮芥潏銊︻潠闁哄嫬楠稿﹢顏堝冀閸儱娅￠柕?
   * 闁圭鍋撳ù鐘劥椤╋箓宕?`isShowPlay = false` 濞戞柨顑呮晶鐘绘晬鐏炵晫绠戝銈堫嚙閸樻稓娑甸娆惧悋"閺夆晜鐟ょ粩鏉戔枎閿涘嫭鍩傞柣銊ュ濡插憡绋夌€ｎ亜閰?闁?
   *
   * 闁宠法濯寸粭?闁告瑱绲界欢鐐寸▔鎼粹槄绱﹂悘鐐插€诲▓?{@link Index.playerRouteIndex} **闂侇偅鍔曢悺褎绋夐埀顒勬嚊?*闁挎稑娼塯etAllPathName()` +
   *    `indexOf(PLAYER_PAGE)`闁挎稑顧€缁辨繃娼诲▎鎰濞戞挶鍊涚粩鐔衡偓?闁圭虎鍘介弬浣广亜闂堟稒韬☉鎾崇Т濠€顏堝冀閸儱娅?婵ɑ鐡曠换娆撳及椤栨碍鍊卞☉鎾亾濞戞搩浜為悺鐔奉浖閸稈鍋?
   * 闁宠法濯寸粭?闁告瑦鐗旂粭澶愬礆閻楀牏鍨介柨娑樻綁@Consumer` 婵炲备鍓濈敮瀛樼▔婵犲繒绀嗛柡?*閺夆晜鏌ㄥú?true**闁? 濞ｅ洦绻傞悾褏鎷嬮妶鍕"閺夆晜锚濠€顏堝冀閸儱娅?闁挎稑顧€缁?
   *    閻庨€涚瑜版彃顭宠箛鏂跨濞戞挴鍋撴繛?Hard-exit 闁稿繑绮岀花鎶芥晬鐏炶偐鐦嶇紓浣圭箑缁楀宕橀幒鏃€绲?闁硅泛锕ら崹浼村箥閹惧磭纾婚柣銊ュ閹搁亶寮ㄦィ鍐︹偓澶婎嚕鐟欏嫬绔?闁汇劌瀚伴ˉ鎾绘⒔閳瑰簱鍋?
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
   * @returns 閺夆晜鐟﹂濂稿础濮濆本绁?*閻犲洢鍎扮粭澶屾嫚閵夛箑惟鐟滆埇鍨硅ぐ澶岀磼濡搫鐓戦柡澶婂暕濮橈附娼诲Ο鑲╄埗閺夆晞娓圭紞姗€寮?*闁? 閻犲洢鍎扮粭澶屾嫚?`morphReset()`闁挎稑顦埀?
   *
   * 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*"闁绘劗鎳撻崵顕€骞嶉幘宕囩；婵炲备鍓濆﹢渚€宕濋妸褎鏆?闁汇劌瀚〒鍓佺磼閸繂鐏查柟?* 闁炽儲鏌￠埀?濞戞挸顦抽悿鍡欐嫚閺囥垺鏅╅柛姘閻ｅ墽绮欓崠锛勭
   *
   * ## 閻炴凹鍋勯幆渚€骞掓径灞剧暠濞戞挶鍊撻柌婊堟偋閸喐鎷遍柨娑樼墕閸╁棝宕樺鍛闁告ü绱槐?
   * | 闁告帇鍊栧畵?| 濞戞捁妗ㄧ划鍫熺▕閸儲鏅?|
   * | --- | --- |
   * | `morphUsable`闁?闁告垹濮崇紞宥咁啅閹绘帗鐨戠紓?闁?| **濠㈤浜濆▍?*闁挎稒姘ㄩ崑锝夊礄閺勫繒鐔呯€垫澘瀚﹢顏堝箰閸屾繃绁伴梺顓ㄧ导缁旀挳宕氶懡銈囩煉闁绘劕缍婇弫瀣倷绾懐绠锋繛宀嬬節閸ｆ椽宕?闁?闁诡厽甯掓禍?闁?闂傚倶鍔嶅鍫熸交濠婂啰纾婚柣顐熷亾 |
   * | `playerRouteStillPushed()`闁?閻犱警鍨抽弫杈ㄦ交濡儤韬柡宥呯墦閸?闁?| **濞撴碍绻嗙粋鍡楊浖閸℃浠搁悹瀣暙鐎?*闁挎稒鐡?onDisAppear` 闂侇叏缍佹禍楣冩⒒閵婏附笑 `setTimeout(0)`闁靛棔姊梐boutToDisappear` 闁哄嫷鍨伴幃鎾愁潰閵夘垳绀夐柤?`popPlayerRoute()` 闁?*闁告瑱缂氱粩瀛樼▔?* `@Monitor` 闁搞儳鍋犻惃鐔兼煂瀹€鍐崜 闁炽儲鏌￠埀?濞戞挸顦抽埀顒€鎳撻惃婵嬪礂閸絿娈遍柛姘叄濞笺倝骞€娴ｇ瓔鍤㈠☉鎾崇Т閸ゎ參寮堕妷顖滅`RzdMusic閻犱焦婢樼换?md` 閹?10 鐎规瓕灏鍥ㄧ▔鏉炴壆鐟濈痪顓у枛閻ｇ偓銇勯惂鍝ョ |
   *
   * ## 閻庤姘ㄩ…鍫ュ礆閵堝棗绁?= **闁活潿鍔嶉崺娑㈠箛韫囨挻绂?*闁挎稑娼塱sShowPlay`闁? 濞戞挴鍋撻柡澶涚磿閳ユ牗绗熺€ｎ亶妯?
   * ```
   *   !isAlive          闁?闁活亞鍞规搴ｇ煁濞寸姾娉涘畵蹇旀姜閺傘倗绀勫☉鎾崇У濡?闁瑰灚鎸哥槐鎴﹀籍閼稿灚锛嬮悗鍦仒缁躲儳鎷嬮埡鈧紞?闁挎稑顦崳?闊洤鎳橀妴蹇涘绩閻愵剚缍€
   *   morphGeomReady    闁?閺夆晜鐟ょ粩瀛樻姜椤旂偓鍩傞柣銊ュ濠€顏堝箻椤撱劎绀勭紓浣哥墢閸嬶綁宕欓悩杈╃Э鐎瑰憡鐓￠崳娲礆鐢喚绀嗛柍?缂備焦绻€缁楀鎳楅懞銉モ叺闁?
   *   state.isShowPlay  闁?濠㈢懓鍟块惇浼村船椤栨瑧顏遍柣?闁圭虎鍘介弬浣广亜娴ｅ喚鍤夊☉鎾崇Х椤曟岸宕烽妸銉ф綄濞?闁活亞鍠愮花?闁?闁衡偓閻愵剚缍€ = 闁硅泛锕ユ晶锕€顕ｉ埀顒勬嚊椤忓嫮绠掗柟鐑樺姈閺?
   * ```
   *   鐠?**闁绘劗鎳撻崵顕€骞嶉幘宕囩；**闁挎稒鑹鹃敍鎾朵沪閸屾艾鐏犻柟?`isShowPlay` 缂?`true` 闁?閺夆晜鐟ょ粩鏉戔枎閳ュ啿绁婚弶鐐村灊缁楀宕ｉ锝嗘澒闁?闁?
   *   鐠?**闁稿繑濞婂Λ?*闁挎稑鐗嗛崣褔姊婚鐔风樆闂?/ 濞戞挸顑嗘刊?/ 缂侇垵宕电划鐑樻交閺傛寧绀€闁挎稑顧€缁变即宕楅幎鑺ワ紨闂佺偓宕橀惌鎯ь啅閼碱剛鏋?`false` 闁?闁衡偓閻愵剚缍€ 闁?
   *   鐠?濞戞挶鍊栧顖炴焾閹存帞鐟濆〒姘箚缁?濠㈣泛瀚幃濠囨焽閿濆嫮顏遍柛鎺旂帛閻栥倝鏌岀仦鐐畳濞寸姭鍋撳☉? 闁?**濞戞挸绉崇欢椋庢導閺嶏附宕插ù锝嗘礃濡炲倹鎯?*闁?
   *
   * 闁宠法濯寸粭?`!isAlive` 闂侇叏绲惧?*闊洤鎳橀妴蹇旂┍?*闁挎稒鑹鹃悾鐘诲触鐏炵偓顦ф繛鎴濈墛鐢偓"濞村吋淇洪惁钘夆枖閸曨剛纭€"闁炽儲鏌￠埀顒佹⒐绾姴顭宠箛搴ｇ獥閻犱讲鏅欑粭鍛▔閳ь剙鈻庨敍鍕化闁告垶妲掗浼村礆?
   *    `isFreshSession = false` 闁兼澘鐭侀摂?闁衡偓閹呯＞濞村吋淇洪惁?闁告帒妫欓弫顕€鏁嶉崼婵嗗珘婵炲备鈧啿袟闁活澀绱槐姘跺Υ?
   *    闂佹澘绉撮〃婊堟儍閸曨偄骞戦幖瀛樻礀濠€?`Index.beginOpenMorphOnClick`闁挎稑娼塴eakClr` 闂侇叏绲惧顖炴嚊椤忓懎澧归柨娑橆槶閳?
   * 闁宠法濯寸粭?濞?`.onDisAppear` 闂佹彃鐭傞崑鍛存焼閹剧粯锛?*闊洤鎳橀妴蹇涘触鐏炶偐顏卞☉鎿冧簻閸ㄤ粙骞?*闁挎稑鐗嗛幃鎾寸▔閳ь剝銇愰姀銏犘﹂柨娑樺缁楀鎷嬬粙鎸庡€楅柛鎰懁缁斿瓨绺藉Δ瀣闁?
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
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*"闁绘劗鎳撻崵顕€骞嶉幘宕囩； / 闁绘劗鎳撻崵顕€宕楅幎鑺ワ紨 / 缂侇垵宕电划鐑樻交閺傛寧绀€ 婵炲备鍓濆﹢渚€宕濋妸褎鏆?闁汇劌瀚〒鍓佺磼閸喎鑵归柟?*闁挎稑顧€缁?
    //   闁告鍠庤ぐ鐐哄及?*闁哄啰濮靛顖涚闊祴鍋撴担鍛婂€辨慨?*闁?`morphReset()`闁靛棗鍊介埀?`morphReset()` 濞村吋鑹炬禒娑㈠炊濞戞顐藉ù婊冾儜缁?
    // ```
    //     morphGen++                  闁?闁圭鍋撻柡?`morphGenAlive` 閻庣懓鐗嗗畷鑲╃博鐎ｎ亜鐓濋弶鈺佹处濠€?
    //     morphUsable = false         闁?閹?02/閹?04 濞ｅ浂鍠栭妶浠嬫儍閸曨垰浜濆☉鎾愁槸椤︹晝鈧懓鐗嗗畷濂稿矗閸繂寮块幖?
    //     morphSessionStarted = false 闁?閹?08 闁告梻濮峰▓?闁哄倿顣︾槐鎵嫚?闁告帇鍊栧畵浣烘偖椤愶絽蝎闁?
    //     morphGeomReady = false      闁?濞戞挸锕ｇ粩瀛樻姜椤旂厧顫ｉ柣?`pullGeomReady` 闂傚倶鍔忛～锕傚礂閸愬弶绀€闁?
    // ```
    //   闁宠法濯寸粭?闁?*闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁哄啳顔愮槐婵嬪籍瑜庨幐閬嶅绩妤ｅ啨鈧鈧湱鍋樼欢銉╂儍?`aboutToDisappear` 閻忓繐宕﹢顏呮交濞嗗海顏遍弶鐑嗗枦閹癸綁骞嶇€ｂ晝顓洪柛姘唉缁?*
    //   闁挎稑鐗婂﹢浼村棘閸ワ附顐?`:4235` 闁煎浜滅换渚€宕樺▎鎺旂畺"闁哄倹婢橀悿鍕瑹?`onAppear` 濞戞挸瀛╁Λ顐も偓鍦仒缁?`onDisappear` 闁告垹濮崇粻顕€宕ョ仦鑺ュ"闁?
    //     `aboutToDisappear` 婵?`onDisappear` **闁哄洤鐡ㄥΛ?*闁挎稑鐭侀埀顒€濂旂粭?*婵炲备鍓濆﹢浣圭鐠佸磭绉跨€点倖鍎肩换?*闁?
    //   闁?閻庣懓鍟俊?*闁告帗鑹鹃崹鏉款嚈閾忓湱褰屽┑鍌滄櫕濞堟垿寮０浣侯伇閺夌儐鍠曠槐鎵嫚?*闁轰胶绻濋柌婊冦€掗崨顔肩闁?
    //     鐠?`beginOpenMorphOnClick` 闁?`isFreshSession` 闁告帇鍊栧畵浣烘偖椤愶絽蝎 闁?閻?闁衡偓閹呯＞濞村吋淇洪惁?闂侇叏绲惧顖炲礆閸℃ɑ鏆滈柨?
    //     鐠?`settlePullOpen` 闁汇劌瀚棢闂佹彃绻橀幗濂稿箮婵犲倸娈ゅù锝嗘礋閸ｆ椽宕堕悙瀛橀檷濞戞柨顑呴幃妤呮晬鐏炶棄瀚夊ù鍏肩濠€浣圭閸濆嫬鏅欐繛鎾虫噸缁旀潙鈻庨埥鍛耿
    //     鐠?閻熸瑥鍊归崝鍛焊鏉堛劍笑闁活潿鍔嶉崺娑㈠箮閵壯勭暠闂侇叏绲肩粭渚€寮?闁炽儲鏌￠埀?**闁绘劗鎳撻崵顕€骞嶉幘宕囩； / 闁绘劗鎳撻崵顕€宕楅幎鑺ワ紨 / 缂侇垵宕电划鐑樻交閺傛寧绀€ 闂侇喛濮ら惀鍛村嫉婢跺﹦娈遍梻?闁煎啿鏈▍娆撳礉閵娧勬毎**
    //       闁挎稑鐗愰埀顒€濂旂粭鍌炲箯婢舵劕浜濋柡澹溿倗鐔呭☉鎾崇Ф缁剝娼?闁哄唲鍐澖濞撴艾顑呭畵蹇旀姜?闁挎稑鏈晶宥嗙閵夈倗顏遍柣鈺佺摠椤掓粎鏁棃鈺冪闁?
    //
    // ## 闁告帇鍊栧畵渚€鏁嶅绶籰ink morphSessionOughtToLive}闁挎稑鐗呯粭浣规姜椤旇法妲搁梺鎸庣懃閹鈧姘ㄩ…鍫ユ晬瀹€鈧幃濠囨偨閸楃偛鏅搁柛锔哄姂閸嬪懘鏌屽畝瀣
    // ```
    //   !isAlive                闁?闁活亞鍞规搴ｇ煁濞寸姾娉涘畵蹇旀姜?闁?闊洤鎳橀妴蹇涘绩閻愵剚缍€闁挎稑鐗愮换鏍级閳ヨ櫕鍊遍柡鍐煐缁夌兘骞?濞村吋淇洪惁钘夆枖閸曨剛纭€"闁?
    //   morphGeomReady          闁?閺夆晜鐟ょ粩瀛樻姜椤旂偓鍩傞柣銊ュ濠€顏堝箻?闁?缂備焦绻€缁楀鎳楅懞銉モ叺闁?
    //   state.isShowPlay        闁?闁活潿鍔嶉崺娑㈠箛韫囨挻绂?闁圭虎鍘介弬浣广亜娴ｅ喚鍤夐柛锔哄妼閻棙绋? 闁?闁衡偓閻愵剚缍€ = 闁瑰灚鎸哥槐鎴犳偖椤愩儱娈扮€规瓕椴哥敮搴ㄥ棘?
    // ```
    //   闁宠法濯寸粭?闁瑰瓨鍨甸崢娑㈠触鎼淬倗妲搁弶?`morphUsable` 濞?`playerRouteStillPushed()`闁挎稑濂旂悮杈ㄧ▔椤忓牆鍘撮梺鎸庣懕缁辨繈宕㈤悢閿嬬閻?
    //      `morphSessionOughtToLive()` 闁汇劌瀚弫鐐烘煂婵犲繒绀勫☉鎾亾濞戞搩浜滈妵濠囧疾濮樸儮鍋撴担椋庮伇濞戞搩浜欑欢椋庢導閺嶎煈鏀遍柡瀣劶閻ㄧ喐鎯旈敂鑲╃闁?
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
    // 闁硅矇鍐ㄧ厬闁告牠缂氶崵婊堝礉閵婏附鏆悹褔顥撳▓鎴犳媼閳╁啯顦у☉鏃傚枙椤╋箓宕戝鎰獥濡炪倗鏁诲浼存焾閸婄喕娉插ù婊冩４缁辨繈宕氶銏犳櫃閻犱讲鏅涢悾楣冨籍鐠虹儤鐝ょ紒宀勭細濞?
    this.stopChromeAutoHide();
    // 濞戞挸顑勭粩鏉戔枎闄囩换姗€寮?`aboutToAppear` 濞村吋宀搁崳鎼佸棘閹殿喚鏋傞柟瀛樺姈閺佸湱鎸ч崙銈囩閺夆晜鐟╅崳閿嬪緞瀹ュ嫮绉撮柛娆樹簼濡插憡绋夋潪鎵晩濞戞挸绉堕弳鈧柤鏉戠箳婵悂骞€?
    this.collapseProgress = 0;
  }

  /**
   * 闁靛棗濂旂粩鎾⒐濠婂啫鐓傞幖瀛樻磸閳ь剙绉撮惈宥咁嚕閳ь剟宕濋妸褎鏆伴柨娑欑婵″憡娼诲☉妯侯唺濞?闁衡偓閹増宕?閻炴稏鍎靛Λ鍧楀礆?0闁?
   *
   * 闁归潧顑嗙涵鍓佲偓鐟拌嫰閸欏繘鎮¤瀵剟鎳撻崘銊ょ矗缂?MusicHome闁?*闁告瑯浜為弫?`height` / `translate` / `scale` 濞戞挸顦柌婊堝春閻戞ɑ鎷遍悘鐐靛仦閳?*闁?
   * 濞戞挸绉堕～顐ｇ鐠佸磭绉跨憸鑸灮婵摜鎲楁担绋款梾 闁炽儲鏌￠埀?闂侇叏缍€缁旂喖骞橀鐔告澒濡炪倕鍚€缁楀懎顭ㄩ幋鐐存毆閻犙囨敱濡炲倿鎯?閻忓繋绶氬浼村矗濡櫣姣?閻忓繗椴稿Σ鍛婃交濞嗗海鐤勯柛瀣皑濞堟垿鏁?
   * `dismissSheetHeightPercent` + `coverLinearScale`闁挎稑顧€缁辨繈骞嬮幋婊勭拨闁告瑯浜濆Σ鎼佸箮婵犲倹鍊卞☉鎾亾濠靛倹顨夌换妯绘償閿曗偓瀵粙宕ラ幋锝囩崜濞戞挴鍋撻梺顒€绉查埀?
   *
   * 濞戞捁妗ㄧ划鍫熺▕閸絿绠归柡宥呭槻濮樸劍寰勯悢鍓佸晩闁挎稒鑹鹃崬瀵糕偓鍦嚀閻?`justifyContent(FlexAlign.End)` 閻犳劕顕鍐╂償閺囷紕鐝堕柨?
   * 濡ゅ倹锚鐎硅櫕绂?閻犳劖娼欑花铏▔閳ь剟寮?闂傗偓閸喖鐓?100% = 濞寸姴楠哥花鎶芥焾閵娿儲鍊诲☉鎾筹躬閹介潧顭ㄩ埥鍛耿閻忓繋绶氬浼存偨?`layoutWeight(1)`闁?
   * 濡ゅ倹锚鐎规娊宕ｅΟ铏规瘓閻庣懓鍟抽崵婊冾啅閸楃偞鐨戦柛娆惷惃顒勬晬鐏炶偐鑹鹃柡?閻忓繋绶氬浼村箞閵忊€冲籍闁告瑦锚閵?濞戞梻鍠嶇粩瀵告導闁垮闄嶅ù婊冩閳?
   */
  private playExpandIntro(): void {
    // 闁?**缂備胶鍠嶇粩鎾礂閵夈儱缍?+ 闁哄啰濮烽弲顐㈩嚕韫囨挸骞戦幖?*闁挎稒纰嶆晶宥夊嫉婢跺鈪电€殿喒鍋撻柡鍌滄嚀缁憋繝鏁嶉崼銏犱化闁告垶鐪归埀顑挎祰閹癸綁骞橀鐔峰闁搞儰鍕橀埀顑挎缁楀倿骞忔径瀣繁闁归潧顑戠槐姘舵焾閹存帞鐭ら弶鈺傜懇閸ｉ攱娼诲☉鏍ゅ亾?
    //   鐠?闁归潧顑嗙€垫艾顫㈤敐鍛含濡炵懓宕慨?闁?閻犱讲鏅濈划浼村箥鐎ｎ亜鈼㈤柨?
    //   鐠?濞戞挶鍊楅顒勬煥濮樺崬浠柨娑樼墣缁姵鎷呴悩铏拫閻忓繋绶氬?+ 闁圭虎鍘介弬浣广亜闂堟稓娈遍梻鍫緛缁辨岸鏌堟禒瀣闁告帡顣︾花?闁?閻犙勬緲閼镐即宕ｅ鍫㈢`tryStartMorphIntro`闁挎稑顧€缁?
    //   鐠?閺夆晜蓱閻ュ懏顬囬幇鍓佺闁绘劗鎳撻崵顕€鏌囬敐鍕伇闁告帞绮幐閬嶅绩妤ｅ啨鈧宕氬顓炵槸閺夌偛顫曢埀顑跨閻ㄦ繈妫冮姀锝囩婵炲备鈧磭顏撮悘鐐╁亾閻庣懓鐭夌槐姘跺焼?**闂佹彃绉烽惁顖炴嚐閵夈儱鍙￠悽?*闁?
    //     閻庝絻顫夐悥锝夊籍閻樺灚娅?`beginMorphEnter` 濠㈡儼绮剧憴锕傚籍?婵炲鍔岄崬?onPullReady 缂佹稑顦銊х磼?闁汇劌瀚禒娑樷枖閺囨ǚ鍋?
    //
    // 闁宠法濯寸粭?闁告帇鍊栧畵浣界疀閸涙番鈧繘寮?*濞戞挶鍊楅?*闂佹寧姘ㄩ崑锝夋晬閸у埓orphIntroAnchorsReady`闁挎稑顧€缁辨繃绋夊鍫濆幋闁告瑯浜滈崹?閺夆晞娓圭紞姗€寮堕敓鐘叉闁告帡顣︾花?闁?
    //    缂備礁鐗忛崑锝夋晬閸喐灏￠柡鈧ィ鍐︹偓澶屼焊娓氣偓濞间即鏁嶆径瀣⒕閻忓繗浜崡搴ㄥ籍?`endCoverSize = 0`闁挎稑鐬奸悽缁橆槹閻愯尙娈遍梻鍫涘灪閻楁挳寮甸璺ㄧ憹濞村吋姘ㄩ弫?
    //    闁挎稑娼塵orphBridging()` 濞?false闁挎稑顧€缁辨繈鎳撶仦鐐啊闁衡偓妤ｅ啨鈧鎳涢鍕畳闂侇叏绲界槐鍓佷焊娓氣偓濞间即寮?闁解偓閹存帞绉撮柟闈涚Ф楠?闁炽儲鏌￠埀?
    //    濞存粌瀛╁Σ鍛婂緞缂堢姷顏卞☉鎾卞€栭鑲╀沪閺囩偟纾婚柣銊ュ椤洭骞囬悢閿嬬殤闁?闁绘劗鎳撶槐鎴﹀焼閹哄秶鐭嗗☉鏂跨墦閸忔ê鈻介埄鍐╃畳闁愁偅甯掗弳妯荤▔閳ь剚绋夌€ｎ亜鐓傚ù?闁?
    //    闁告粌鐬奸弫銈夊箣闁垮顫岄悹鍥ь槺濞?闁绘劗鎳撻崵顕€骞嶉幘宕囩；閺夆晜蓱濡叉悂寮婵晠鎮?闁告垹濮崇粻顕€宕氶崱鏇犵憹闁告垹鍎ゅ鐢稿Υ?
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
    // 闁?闂佹彃绉烽惁顖炴偨閵娿儲鏅?闁?**闁烩晛鐡ㄧ敮鎾媰閹存帞绉撮柨娑樼灱缁攱绋夊鍡樺啊闁奸绀佹慨鈺呮偨?*闁挎稑鐗嗛顕€寮介崶褍鍐€缂傚倹鐗為惁褔鎯?`setFinalStatus()`闁挎稑顧€缁?
    //   闁告瑥绉剁槐顏嗘嫚?`setupExpandTransition` 闂?`expand.init(...)` 閺夆晜鏌ㄥú?false 闁汇劌瀚崢瑙勬償閺囩偞鐨戦柡?
    //   "闁衡偓閹呯＞闁告柣鍔庨弫楣冨Υ娴ｇ儤绾柟鎭掑劥閹倖鎷?闁靛棗鍊块埀顑藉亾闁搞儳鍋涢獮鎾诲箻?闁告ê顑嗘晶搴ㄥ礃閸涱収鍟囬悘鐐插€块悵顔芥償?闂侇叏绲介〃婊堟嚀娴ｇ袟闁汇垻绮Σ?*闁瑰瓨鍨瑰▓鎴﹀矗閹寸偞顫?*闁?
    //   濞戞梻鍠愰婊堝及椤栨粍鏆忛柟鏉戝槻瀵姤寰勫鍛唨濡絽鐗忓▓?闁绘劗鎳撻崵?閺夆晜鏌ㄥú鏍偨閵娧勭暠闁哄嫷鍨卞Λ顐﹀礉閵娧勬毎"闁汇劌瀚闈涒攦閹扳斁鍋?
    Logger.error(PlaybackPage.logTag,
      'expand intro: anchors never became ready, landing without animation (setFinalStatus)');
    this.expandState.morphReset();
    this.expandState.morphSettleOpen();
    // 闁哄啰濮存慨鈺呮偨閺勫繑鍎板ù锝呯С缁″啳绠涢崨娣偓蹇擃嚕閳ь剟姊婚…鎺旂闁告熬绠戦崹顖炲极閹绢喓鈧瀵煎顐ゎ伇闁烩晜娼欐禒鐘诲捶?濞戞挸绉堕弫?闁汇劌瀚慨鎼佸箑娓氬﹦绀勯柟鍨尫缁楀顕ｉ埀顒勫箻椤撶喐鏉瑰銈囶暜缁?
    this.introPaintReady = true;
    this.collapseProgress = 0;
    this.expandIntroRunning = false;
  }

  /**
   * 閻忓繑绻嗛惁顖滄導閺夎儻鍩岄柛娆惷惈宥咁嚕閳ь剛鎹勯姘辩獮闁挎稒宀搁崳娲煥濮樺崬浠?闁?閺夆晜绋撳ù澶嬫媴?闁?閻犙呮焿钘熼梻鍌涚暘閳?
   * @returns true = 鐎规瓕灏欑划锟犲箰婢跺﹨鍩岄柛娆愵焾閻儳顕ラ崟顐ょ；濠殿喖顑戠槐娆戞嫬閸愵亝鏆忛柡鍌炩偓娑氱憹閻熸洑绀侀崯鈧悹褎濯介埀顑挎祰閻儳顕ラ崟鍓佺
   */
  private tryStartMorphIntro(): boolean {
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER) {
      // 闁归潧顑嗙€垫艾顫㈤敐鍛含濡炵懓宕慨鈺呮晬濮樺磭娈卞☉鏃傚枎閸╁棝骞庨～顔惧耿缂備焦锚閸╂姊婚妸銈囩槏濞戞挴鍋撴鐐跺煐閺備胶鎮板畝瀣閺夆晜鐟﹀顖滄崉椤栨瑧鐟濋弶鈺傜◥缁楀懘妫冮姀銏＄暠鐎殿喒鍋撻梻鍌樺妼閸ㄥ酣寮ㄩ銈囩
      // 濡絾鐗楅鍏肩▔婵犲啫顎欓柣銊ュ濞蹭即寮介崶褏姣ｉ柡鍫簻缁旈浠﹂埀顒勫籍閺堢數鐭濆ǎ鍥ㄧ箖鐎垫棃鏌呰箛鏃€顫栭柛蹇嬪妼閺勫倻鈧敻娼荤槐婵堟偘閵夆晛娅ら柟瀛樺姇婵盯宕樺鍡樻澒閻炴稑琚埀?
      this.introPaintReady = this.expandState.morphUsable;
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
      return true;
    }
    this.expandState.pullDragging = false;
    // 闁?闁告帇鍊栧畵渚€寮?*濞戞挶鍊楅顒勬煥濮樺崬浠梺顔荤矙缂?*闁挎稑娼塵orphIntroAnchorsReady`闁挎稑顧€缁辨繃绋夊鍡樞?閺夆晞娓圭紞姗€寮堕敓鐘叉闁告帡顣︾花?闁?
    //   缂備礁鐗忛崑锝夋晬閸喐灏￠柡鈧ィ鍐︹偓澶屼焊娓氣偓濞间即鏁嶆径瀣⒕閻忓繗浜崡搴ㄥ籍?`endCoverSize = 0`闁挎稑鐬奸悽缁橆槹閻愯尙娈遍梻鍫涘灪閻楁挳寮甸璺ㄧ憹濞村吋姘ㄩ弫?
    //   闁挎稑娼塵orphBridging()` 濞?false闁挎稑顧€缁辨繈鎳撶仦鐐啊闁衡偓妤ｅ啨鈧鎳涢鍕畳闂侇叏绲界槐鍓佷焊娓氣偓濞间即寮?闁解偓閹存帞绉撮柟闈涚Ф楠?闁炽儲鏌￠埀?
    //   濞存粌瀛╁Σ鍛婂緞缂堢姷顏卞☉鎾卞€栭鑲╀沪閺囩偟纾婚悘蹇氶哺濡?闁绘劗鎳撶槐鎴﹀焼閹哄秶鐭嗗☉鏂跨墦閸忔ê鈻介埄鍐╃畳闁愁偅甯掗弳妯荤▔閳ь剚绋夌€ｎ亜鐓傚ù?闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儑濞?缂佹鍏涚粩鏉戔枎閳╁啰姊鹃柡鍫濐槸閻ㄦ繈妫冮姀銈庢＇闁?闁挎稑顦埀?
    //
    // 闁?濡炪倕鎼花顓㈡偨?`prepareMorphEntry` 闁搞儱鎼悾楣冩晬?*濞达絾绮岀花鍓х磼閸垹浠?闁?闁革负鍔岀敮顐や焊閸濆嫷鍤熼柡鍐ㄧ埣閸?闁?闁告劕绉寸敮鍥礆閹峰本宕抽柣?*闁?
    //   闁宠法濯寸粭?閺夆晜鐟╅崳?*闁轰礁鎳忛崜鐗堢▔瀹ュ懍绮?`alreadyRunning` 濞戞柨顑囩悮顐︽儍閸曨厾鍙氶悹?*闁挎稒鐭粩鎾籍閿斿墽鍙氶悹渚灲缁辨繄浜搁崣妯肩獥闁?
    //      "缂備礁鐗忛崑锝咁啅閸欏绠掗柕鍡曟缁查箖寮甸鍐瀭閺夆晜蓱閻ュ懏娼诲☉婊呯畺鐟滆埇鍨硅ぐ?闁汇劌瀚懙鎴︽⒒鐎涙ǚ鍋撴担椋庣憮閻犲搫鐤囩换鍐储鐎ｎ厽宕抽柣鎰缁?
    //      濞存粌瀛╁Σ?`collapseProgress`/闂傚倶鍔庢慨鎼佸箑娴ｉ鐟㈤柣鈺呮櫜缂嶅懐鈧敻鈧稓鐟濆☉鎾愁焾閳ь剙鍊哥粻鎾剁驳婢舵劕娅㈤柛蹇嬪劜濡插摜鈧懓顦崣蹇涙儍閸曗斁鍋?
    //   濞戞挸锕ｇ粩鎾偋閸垺鐣?bug 婵繐绲藉﹢顏呮交濞嗘挸娅￠柨娑欑煯缂嶆梹鎯旈悢宄靶楀ù锝嗙矎椤箓寮ㄩ幆褎韬?`morphBeginEntering()` 闁告劕鎳橀崕鎾晬?
    //   婵繐绲介妶浠嬪箮婵犲倸鐏犻梺鎻掔箰閸╁矂鎯冮崟顓犵煉闁绘劘顫夋慨浠嬪箳?闁?闂佹彃绉烽惁顖炲嫉閻斿嘲瀚夐悶娑栧劙缁楀宕堕悙瀛橀檷闁挎稑娼塵orphLive()` 闁归潻绱曞鍐晬?
    //   闁?闂佹彃绉烽惁顖炴偨閵娿儲鏅奸柡鍐Т婵晠鎮介弰蹇斿劙濞?闁?**闁绘劗鎳撻崵顔炬崉椤栨氨绐炲ù鐘插濞奸潧鈻介檱缁绘ɑ娼?`playMorphOpenIntro()`**闁?
    if (!this.expandState.morphUsable) {
      return false;
    }
    // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗嗗ú鏍焻閳ь剟宕ユ惔銊ユ闁稿鐔槐?*濞戞捁妗ㄧ划鍫熺▕閸繍妯嗛梻鍫涘灱椤╋箓宕犻崨顒傤伇閻?`UIUtils.applySync`**闁?
    //   `prepareMorphEntry` 闁汇劌瀚〒鍫曞触鎼存繄顏辨慨婵勫劜濡?闁硅泛锕ら崵鎴炴媴閺囩偛绔鹃柛鎺撳閹癸綁鎮?闁挎稑娼塧pplyMorphProgress(0)`闁挎稑顧€缁?
    //   缂佹瘱鍕闁活偀鍋?*闁告艾濂旂粩瀛樼▔椤忓啯宕查柛鏃撶節閸?*閻忓繗绮鹃幑锝囨偘閵夆晜锛熼柕鍡楀€介埀?V2 闁汇劌瀚慨鎼佸箑娴ｇ缍侀梺鎻掔箣閹便劑寮?*濞戞挸绉崇槐鎵博鐎ｎ亜绁柡宥呮穿閸?*闁挎稑鐗婃慨?Promise 鐎甸偊鍠曢幑銏ゅ礉閳藉懐绀嗛柨?
    //   `animateTo` 闁告绻濈槐?*缂佹柨顑呴崺銏ゅ礆闁垮鐓€鐎圭寮堕悥锝夋嚇韫囨艾螡闁绘劘顫夊鐢稿礃閸愯尙鏆伴柛鏂诲妽閺呫儲锛冮弽褎濮?* 闁?闁告ê顑堥幑锝夋倷瑜版帒浜濆☉鎾亾濞?*婵炲矉绱曢弫鎾诲极?*闁挎稑鐭傞々鑽ゆ暜瑜忛弫銈夊籍瑜嶉埀顒傤儠閳?
    //   閻庤蓱閺岀喖鏁嶉崸鍒焤kts-new-applysync-flushupdates-flushuiupdates`闁挎稑顦板Σ鎴犳兜椤旀娼愰悗瑙勪亢缁绘牜绮?
    //   "闁告柣鍔嶉弲銉╁礈瀹ュ棙绠掑Λ鐗堢箓椤︾粯绌遍鑺ユ毉"闁汇劌瀚┃鈧柡鍜佸灥椤╋箓鎮?`UIUtils.applySync` 闁告艾鏈鐐哄礆闁垮鐓€闁告艾楠搁崯鈧悹褍鍢叉慨鈺呮偨?闁炽儲鏌￠埀?閺夆晜鐟﹂婊堝及?
    //   "闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁告粌鏈晶婊堝箰閸ャ劌鐝涢柛鏂诲妽婢э箑顕ｉ埀顒勫及椤栨瑨鈷堝☉鎿冧簻婵晠鎮?闁汇劌瀚划銊╁几閸曨兘鍋撹閻楁挳宕堕悪鍛50ms 鐎点倖鍎肩换?闂佹彃绉烽惁?缂備焦锚閸╂姊婚妸鈺佸幋闁哄嫷鍨伴悾鐘绘儍閸曨啟澶嬬▔娓氬﹦绀嗛柕?
    //   闁宠法濯寸粭?閻庣懓鍟ぐ褏鎲撮敐鍛瀫**闁哄秴娲╅崜?*闁靛棔妞掔粭澶屾喆閿濆懎鏋€**閻㈩垰鍟惇?*闁挎稒姘ㄩ悺鎴犱焊娓氣偓濞间即鎳為崒婊冧化闂佹彃绻愮欢閬嶅礆妫颁胶鐭濋柣鎺撳劶椤╋箓妫冮悩杈╃憪闂傚牄鍨诲▓鎴︽煂瀹ュ牏妲哥紒鎰殔瑜版盯濡?
    let prepared: boolean = false;
    UIUtils.applySync((): void => {
      prepared = this.expandState.prepareMorphEntry(this.getUIContext(), true);
    });
    if (!prepared) {
      // 濞ｅ洦绻勯弳鈧柡鍫墲閻ゅ棛浜告潏鈺佸磿闁绘鍩栭埀顑跨筏缁辨繄绮垫径濠勭濞戞挸顑勭粩鏉戔枎閳ュ啿鏂ч悘蹇撴惈椤曨厾鏁崘銊ф拱闁挎稑濂旂粭澶愬捶閵娾晛娅㈤悹鍥ㄦ礋濡潡宕㈢€ｎ剛绱?濠㈣泛绉崇紞鍛暜閸愩劎婀伴柕?
      return false;
    }
    if (!this.expandState.morphIntroAnchorsReady()) {
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready ` +
        `(usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()})`);
      return false;
    }
    // 闁告垹濮崇紞宥囦焊鏉堚晛宕曢柨娑欒壘缁辨垿姊婚…鎺旂闁稿繋娴囬蹇曠磼濡搫鐓戦柨娑樼墛椤掓繈寮捄鍝勫殥缂備礁绻戝Σ?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞挴鍋撻悘蹇撶箰濞?闁汇劌瀚幑锝夋倷鐟欏嫧鍋撴笟濠勭
    this.introPaintReady = true;
    this.expandIntroRunning = false;
    this.collapseProgress = 0;
    this.playMorphOpenIntro();
    return true;
  }

  /**
   * 闁奸娴囬惌鎯ь嚗閸曞墎绀勯柛鎴犲С缂嶅秴鈻介敓鐘叉闁告帞澧楀鍌炴儍閸曨偄骞戦幖瀛樻穿缁辨岸鏁嶅顒€鏁堕悗鍦嚀閻壆鎷圭€靛憡绲婚幖瀛樻礉缁旂喖鏁嶅畝鍕蒋閹艰揪缂氱划?閻犳劖娼欑花铏▔閳ь剟寮?闂傗偓閸喖鐓?100%闁?
   *
   * 闁告瑯浜滃﹢?`morphUsable === false` 闁哄啳鍩栨晶鐘冲濮樺疇娉查柛鎺撳缁绘牠鏌?闁炽儲鏌￠埀?婵繐绲介悥鍫曞箚閸涱厼鏋岄柨娑樼墣缁姵鎷呴悩铏拫闁革负鍔婇埀顑跨椤旀牗绋夌拠鎻掑殥闂佹彃绻愰崺宀勬晬?
   * 濞戞挴鍋撶€垫澘顑堥摂瀣亹閵忕姴缍侀梺顓ㄧ稻濞碱垳鎹勯妯峰亾?
   */
  private playLegacyExpandIntro(): void {
    try {
      // 闂侇偅鍔曢崢鎾舵閻樺疇绐楅柛蹇嬪劤閺?*闁哄牜鍓熼妴澶愭嚊椤忓懎鐦?*闁汇劌瀚换妯绘償閿旇偐绀? = 閻犳劖娼欑花鎶藉绩閹増宕?闁?0 = 閻庣懓鑻崣蹇曚沪閺囩偟纾婚柨娑橆檧缁辨繃绋夋惔銊у蒋閹艰揪绠掕棢闂傚倹娼欓幃鎾舵導瀹勭増鍊遍柦鈧慨鎰ㄥ亾?
      // 闁宠法濯寸粭?闁告帞绮崜鐗堢▔瀹ュ拋妲婚柣顫妼閸欌剝绂?`PlayerExpandState` 闁?preparing/animating 闁烩晠鏅茬紞鍛存晬?
      //    闂侇叏绲介〃婊堟儎闂€鎰Т闁汇劌瀚悿鍡樻媴瀹ュ洤浠柛锔哄姂閸ｆ悂寮搁崟顏囧幀闁稿繈鍔嬪☉顏呯閸☆厾绀夐柟鎭掑劙缁楀倿宕㈢拠鎻掓锭濞村吋鑹剧欢閬嶅礆妫颁浇鈷堢紒澶婄Т濞兼牜绱掗幘瀵镐函 闁炽儲鏌￠埀?
      //    闁靛棗鏈禍鐣屾導娴煎瓨濮滈柛鏂诲妿閺侀箖宕氶崱妯绘殰 闁?婵烇絺鈧啿寮崇紒娑橆槷缁剙鈻介垾鍐叉櫢闁靛棗绉甸崹銊╁Υ鐏炲墽鍨奸煫鍥殕閻ｎ偊鎮?闁?闁轰焦娼欏锟犲礃閸涱収鍟囩紒鐘愁殕閸ㄦ岸鏌呰箛鏃€顫栭柨娑樼墕閻ㄦ繈妫冮姀鐘插弗婵烇絺鈧櫕鍊垫繛鎴濈墕閵囨垿濡存担瑙勬濡炪倗鏁搁埞鏍儌閺傘倗绀嗛柕鍡楃Р閳?
      //    闁哄牜鍓熼妴澶愭嚊椤忓懎鐦?+ 闂傚牊鐟﹂娑㈠箑娴ｉ€涜埅閺夆晜鏌ㄥú?1闁挎稑鑻銊︾▔瀹ュ懐鎽犻柛锔哄妽閻ｎ偊鎮惧▎鎰ㄥ亾娴ｇ鍋?
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
      // 閻炴稏鍎靛Λ璺ㄦ導閾氬倻鐟濋柡澶堝劚濮樸劎绮╃€ｎ亜鐓濋柛銉у仜閸╁瞼鈧懓鏈弳锝夊箑娓氬﹦骞㈤柣顏勵儔濡剟鎮Δ渚囧妰闁哄啯鍎肩换鏇炩柦閳ュ啿鐓傞柣鎰缁辨繈宕氶銉敤濡炪倗鏁诲浼村磻濠婂啯韬?闁衡偓閹増宕?闂侇叏绲肩粩鎾级閳ヨ尙鐟?
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `expand animateTo failed code=${e.code} msg=${e.message}`);
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
    }
  }

  /**
   * 閻庡湱鎳撳▍鎺曘亹閵忕姴缍侀悹渚灠缁剁偤鎯冮崟顐ゆ綌鐎殿喒鍋撻悶娑栧劦濡潡鏁嶅顒€娈ゅù锝嗘礀濠€?`aboutToAppear` 鐎规瓕灏欑划锟犲储鐎ｎ亜鐓傞悹褔顥撻崑锝夋晬閸?= 0闁?
   * 濞戞梻鍠庡銊╁及?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼闁哄銈呭帯闁?闁挎稑顧€缁辨繃娼诲▎鎾虫闁告瑯浜濇俊鍝モ偓鐟板暞鐢綊宕?1闁挎稑鐗撻幗闈涱煥閳藉懐绀嗛柕?
   *
   * 闁宠法濯寸粭?`animateTo` 閻炴稏鍎冲▓鎴﹀及?*閻忕偟鍋為埀顑啠鍋?*闁挎稑婢僣ale / translate / height / borderRadius / opacity闁挎稑顧€缁?
   *    濞戞挸绉靛Σ?`morphP` 闁哄牜鍓濋棅?闁炽儲鏌￠埀?闁圭鍋撳ù鐘劦濡挳宕犻崨鏉戞闁告瑯浜ｉ々锕傚箮婵犲嫬笑闁诡兛娴囬幆銈夊礆閹殿喚鐭掗柣鎰嚀瀹撳棝宕ｉ銈囩濞戞搩鍙冨Λ璺ㄦ暜瑜忛弫鍗烆浖閸℃浠搁柟缁樺笒閳ь剛銆嬬槐?
   *    闁圭鍋撻柡鍫濐槺缁箓宕烽妸銉﹀€卞☉鎾亾濞寸姷鏅慨鎼佸箑娴ｉ鐟愰柣銊ュ閻﹢骞€瑜岀槐鐗堢▔閳ь剛鎸ч悿顖濇巢闁告艾濂旂粩鎾级閳╁啯閿ょ紒鎹愶骏閳?
   */
  private playMorphOpenIntro(): void {
    this.expandIntroRunning = true;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗嗗ú鏍焻閳ь剟宕ユ惔銊ユ闁稿鐔槐姘舵晬?*闁告帞濮电敮鈧柛妯煎枑濞?鐎点倛娉涢幃?50ms 闁告劕绉烽幑锝囨偘閵夆晜锛?闂侇叏绲肩粩鏉戭潰?*闁?
    //   閻庣懓鍟紞瀣嵁鐎涙ɑ笑濞戞捁妗ㄧ花锛勭磼閺囩偟纾诲☉鎾亾濞戞搩浜炲﹢锛勨偓鍦仜閻°劑宕烽妸褎鐣遍柛褎鍩婄槐?*V2 闁汇劌瀚慨鎼佸箑娴ｇ缍侀梺鎻掔箲濡?鐎殿喖鍊归鐐哄冀閸ヮ亜澹?闁挎稑婀omise 鐎甸偊鍠曢幑銏ゅ礉閳藉懐绀嗛柨?
    //   闁?`animateTo` 濞村吋姘ㄩ悵娑㈠礆鐠囨彃鐓曢柡鍌涙緲閸戯繝寮介崶顏勫闁煎搫鍊婚崑锝夊级閵夈儱鏋€閻庤鑹炬慨鈺呭极閸儺娴曢悽?* 闁炽儲鏌￠埀?濞存粌瀛╁Σ?闁稿繐鐗婃俊鎼佸礄閻樿京绉块柛妯侯儏閸╁瞼鎸ф搴′化闁?
    //   闁告艾濂旂粩瀛樼▔椤忓啯宕查柛鏃撶節閸ｇ兘宕樺鍫熷闯閻炴稏鍎靛Λ?闁哄啳顔愮槐婵嬪储鐎ｎ厽宕抽柣鎰秺閸嬪懏绋夐埀顒佺▔?*婵炲矉绱曢弫鎾诲极?*闁挎稑鐭傞々鑽ゆ暜瑜忓ú鍧楀箳閵壯勬殢闁哄唲鍐ｅ亾缁楄　鍋?
    //   閻庤蓱閺岀喖鏁嶉崸鍒焤kts-new-applysync-flushupdates-flushuiupdates`闁挎稑顦辩划浼存儍閸曨啩鎺戔枖閺囩喐笑
    //   `UIUtils.applySync(() => { 闁?})`闁挎稒鑹鹃幃鎾愁潰閵夈儱鐓曢柡鍌欏嵆濡挳宕犻崨顓炴暥闁汇劌瀚慨鎼佸箑娴ｇ缍侀柛鏍ㄧ壄缁辨繈宕樺鍫熷闯闁告鍠愬鐢告儍閸曨偄袟闁汇垺鐪归埀?
    //   闁哄牜鍓氶弻鐔封枖閺囥垹甯抽柛?`tryStartMorphIntro` 闂佹彃鐭傞崑鍛沪?`applySync` 濞达綀娉曢弫?闁炽儲鏌￠埀?
    //   閺夆晜鐟ょ弧鍐及?闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁告粌鏈晶婊堝箰閸ャ劌鐝涢柛鏂诲妽婢э箑顕ｉ埀顒勫及椤栨瑨鈷堝☉鎿冧簻婵晠鎮?闁汇劌瀚划銊╁几閸曨兘鍋撹閻楁挳宕堕悪鍛50ms/闂佹彃绉烽惁?缂備焦锚閸╂姊婚妸鈺佸幋闁哄嫷鍨伴悾鐘绘儍閸曨啟澶嬬▔娴ｇ鍋?
    // 闁宠法濯寸粭宥夊煣閻欏懐鐟?2026-10-17 缂佸墽濮甸婊勭▔閳ь剚寰?*闁瑰瓨鍨奸崵婊冾啅閸楃偛鏅搁梺鎸庣懅濞堟垵鈻旈妸鈺佹珵**闁挎稑鐗嗛悾鐘诲及椤栨瑧鐟撻梻鍫涘灲閸嬪懏绋?bug 闁汇劌瀚闈涒攦閹板墎绀嗛柨?
    //   閺夆晜鐟╅崳鐑藉储閻斿憡闄嶉弶鈺偯崯鎾绘儓閳ь剟濡寸仦鐣屾毉闁哄倸婀辩划浼存儍閸曨偄鏅告繛澶嬫礀濮樸劑寮伴姘含 `animateTo` 闁汇劌瀚板Λ鎾礌閸涙潙娅￠柣?`UIUtils.applySync`
    //   闁告艾鏈鐐哄礆闁垮鐓€闁烩晩鍠楅悥锝夊磹缁楄　鍋撳浣插亾閺傝　鍋?*闂侇叏绲惧Σ鎼佹煥濞嗘垶鐣?*闁靛棗鍊搁悾濂稿棘瑜版帒浜濆☉鎿冧簻濠р偓闁哄拋鍨卞Σ?
    //   闁?*闁告柣鍔嶉弲銉︾▕鐎ｎ亜顤?*闁哄牆顦甸·鍌涘緞閺嶏附鍙忛柡鈧?闁?闁?`applySync` 闁?*閻犙囶棑閸?*闁解偓閽樺鍕鹃柨?*闁?*閻?`animateTo`闁靛棗绋勭槐?
    //   闁?**`animateTo` 闂傚偆鍘肩€垫﹢鏌岀仦钘夋锭閻犱胶顭堥崯鎾绘儎椤旂晫鍨奸柛?*闁挎稑鐗嗛崯鎾寸閳ь剚绋婇崼婵囩殤閻炴稏鍎靛Λ鍧楀礆閺夋寧鎲块梺鎻掔焿缁辨岸濡?
    //   闁硅泛锕ら悾鐘诲绩閹规劗绠婚梻鍌ゅ幖鐎垫﹢鏌?= 闁硅泛锕﹀ú浼村冀閸パ€鍋撻懖鈺冨綄闁告帟顕ч崺娑㈠礄閸濆嫬绠?闁?**閻炴稏鍎靛Λ璺ㄦ偖椤愩儳鍎查弶?* 闁?闁烩晛鐡ㄧ敮瀵告崉瀹曞洨鐭掗柣鎰畭閳?
    //   闁?闁哄牜鍓氶弸鍐╃閸洖娅?`applySync` 闁汇劌瀚婊呮兜椤旇崵绉寸紓鍐惧枛瑜把囧嫉?閻炴稏鍎靛Λ鎸庣▕鐎ｎ亜顤?闁挎稑鐗愰～?:3158 / :3737 濞戞挶鍊曢ˇ鈺呮晬婢跺牃鍋?
    //   闁宠法濯寸粭?濞戞挻鐗旈崬顒勫矗閸戙倗绐楅柡鈧捄铏瑰暡闁搞儳鍋犻惃鐔荤疀閸涙番鈧繐袙閺傛鍤?`morphGen`闁挎稑鐗嗗鐣岀磽閺嶎剛妲梺?`animGen++` + onFinish 闁哄稄绻濋悰娆撴晬婢舵稓绀?
    //    闁告熬绠戦崹顖濈疀椤愶腹鍋撻悢鑽ょ闁?闁衡偓閹増宕冲ù鍏肩煯鐟曞棝鎮╅懜纰樺亾娴ｇ鍋?
    const gen: number = this.expandState.morphGen;
    try {
      this.getUIContext().animateTo({
        duration: PlaybackPage.MORPH_OPEN_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁活潿鍔嶉崺娑氱箔?1 闁?闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁哄啰濮存慨鈺呮偨濮瑰洠鍋撴担鐑樼函闁规亽鍎遍崺宀€绱掗幘瀛樺皢濞达絽绉堕悿?闁汇劌瀚悧鎾炊?*闁?
        //
        // 閳藉應妲勯埥鍛 2026-10-17閿?*闂傤厼瀵橀柌灞藉涧閸?`morphP` 鏉╂瑤绔存稉顏堝櫤** 閳ユ柡鈧?閻撗勬儔閺冪姷鏅?娑撯偓娑?morphT 妞瑰崬濮╂稉鈧崚?閿?
        //   閸樼喐娼甸崘?`applyMorphProgress(1)`閿涙艾鐣犳导?*娑撯偓濞嗏剝鈧?*閹?`morphP` 鏉╃偛鎮撻崙鐘辩秿閸忋劌鍟撻幋鎰矒閻愮櫢绱?
        //   娴滃孩妲搁幍鈧張?閹?`morphP` 閸欐牕鈧?閻ㄥ嫭娣抽悽鐔煎櫤閿涘牐鍎楅弲?`pullBgIn`閵嗕礁鎮囧▓鍨窗閸忋儳鐛ラ崣锝忕礆閸︺劏鎹ｉ幍瀣亝娑撯偓鐢?
        //   鐏忚精鐑﹂崚棰佺啊缂佸牏鍋?閳?閻劍鍩涚€圭偞绁撮惃鍕┾偓?*娑撯偓瀵偓鐏忚鲸妲搁懗灞炬珯閼?/ 鐠у嘲顫愭稉宥嗘Ц濮濓絽鐖舵０婊嗗**閵嗗秲鈧?
        //   閻滄澘婀崣顏勫晸 `morphP`閿涘瞼鏁?`PlayerExpandState.@Monitor('morphP')` 闁劕鎶氶柌宥囩暬閸戠姳缍嶆稉搴㈡烦閻㈢喖鍣?
        //   閳ユ柡鈧?娑撳簼绗傚〒鍛婄槨鐢?`applyPullProgress(effT())` 閸氬本鐎妴?
        this.expandState.morphP = 1;
      });
    } catch (err) {
      // 閻炴稏鍎靛Λ璺ㄦ導閾氬倻鐟濋柡澶堝劙缁″啰鎲版担鑺ュ劙闁告帗婢橀悾顒勫极鐎涙ǚ鍋撴笟濠勭缂備焦绻€缁楀鎳楅懞銉ノ╅柟缁㈠幗閺備焦銇勯悽鍨畬闁?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞挴鍋撻悘蹇撶箰濞?
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
      // 闁宠棄鎳夊Σ?2026-10-16闁?*闁告艾濂旂粩鎾级?濞戞挸绉烽々锕傚捶閵婏妇姊鹃柡鍫濐槸閸ゆ垶鎷呴弴鐔割槯闁解偓閹存帞绉?闁汇劌瀚～澶愬礆?*闁挎稑鐭侀～?`Index.settlePullOpen`闁挎稑顧€缁?
      //   閺夆晜鐟ょ粩鎾矗閵夈儱鏂ч柡澶堝劜濡倝寮堕垾鍙夘偨闁解偓閹存帞绉撮柕鍡楀€界€氥垽寮甸鍐瀭闁告垹濮崇紞宥嗘叏鐎ｎ剛鐭掓繛宀嬬節閸ｆ椽宕氱敮顔剧`morphGeomReady` 濞戞挸鎼禍锝夋晬婢舵稓绀?
      //   `morphSettleOpen()` 闁告劕鎳橀崕鎾儍?`applyMorphProgress(1)` 濞村吋淇洪～锕傛焽閿濆澹曢梻鍌樺妽鐏忓懘骞掓径鍫氬亾?
      //   闁兼澘鐬煎ù澶嬫媴瀹ュ懎绁辩紓鍫㈢帛閸?OPEN 闁?閻庡湱鎳撳▍鎺楀磻濠婂啯韬柟顓熷笧閻?+ 闁烩晠鏅茬紞?OPEN 闁?*闁告锕ラ鎾偐閼哥鍋?*闁?
      //   闁?闁圭顦板Λ銈夋偩鐏炵儵鍋撳畝鍕濞戞挸绉撮崺宀€浜搁柆宥佸亾閳ь剟宕堕悙瀛樼彯闂?push(闁哄啰濮撮懜浼村矗?闁靛棗绉跺▓鎴﹀矗閿濆懐绐為柨娑欒壘瑜把囧箮婵犲嫭绁插ù锝呯У閺佸綊鐛幓鎺戞珝闁挎稑濂旂粭澶愭媰閹存帞绉撮柕?
      if (!this.expandState.morphGeomReadyNow()) {
        this.expandState.pushMorphTrace('openNoGeom');
        this.expandState.morphReset();
        this.expandState.morphStage = MorphStage.OPEN;
        this.expandState.morphP = 1;
        this.expandState.measureGeometry(this.getUIContext(), true);
        return;
      }
      this.expandState.morphSettleOpen();
      // 闁?闁解偓閹存帞绉撮柛?*闂佹彃绉归崳鐑樼▔閳ь剙鈻?*闁告垹濮崇紞宥夋晬濮樺磭绠瑰☉鎾亾闁告帒顭烽妴澶愭閵忕姴鍤掔紓浣哥箲濡叉悂宕㈤悢閿嬫閻庣敻娼荤槐妾歝ale=1闁靛棔妞掔紞鍛矓?0闁挎稑顧€缁?
      //   闂佹彃绻愰崺宀勬儍閸曨剚笑妤犵偞褰冮崳锝夋儍閸曨厾鐭掗柣鎰贡閻撯晞銇愰～顔惧耿闁告艾鏈鍌炲箮?aside 闁汇劌瀚鏃€鎯旈敃鈧崺娑㈠棘妫颁胶顏遍梺顒€绋勭槐姗S 閹煎瓨娲橀悥顕€骞掗幒鎴狀伌闁告瑯鍨甸崗姗€宕ｅΟ璺ㄧ畺闁挎稑顦埀?
      //   闁宠法濯寸粭?閺夆晜鐟ょ粩鎾煂韫囨挸娑х憸鏉垮船閹?*濞戞挸顑勭粩瀛樻姜?*閻忕偞娲栫槐鎴︽晬閸粎鐟濋柛鏂诲妽濠€鐗堟姜椤斿墽鐭掗柣鎰缁辨岸鏁嶇仦鎯ь暡濞寸姰鍎遍悾鐘诲及?濞戞挸顑勭粩瀛樻姜椤旇姤绾柛?闁汇劌瀚换姘舵⒔閳哄绀?
      //      濞戞挸绉靛Σ鎼佸嫉椤掑啰鏋傞柦鈧幋鎺旂Т閻庣敻鈧稓鐟濋悗闈涙贡濞堟垶绗熷┑鍥хウ闁?
      this.expandState.measureGeometry(this.getUIContext(), true);
    }, PlaybackPage.MORPH_OPEN_DURATION_MS + 30);
  }

  /**
   * @returns 闁告劕鎳庨鎰沪閸岀偟褰幖杈惧濞呫劑宕氶崱妯兼Х閻庢稒顨堥浣圭▔鐏炲倵鍋?
   *
   * 閺夆晜绋戠€?0 闁?`'100%'`闁挎稑鐗呯粭灞解柦閳╁啯绠掗柛鏂诲妿閺侀箖寮崼鏇楀亾閹邦剙鍓肩紒杈╁С缁旀挳鎳涙潏鍓х閺夆晜鐟﹀Σ鎼佸嫉閳ь剟鏌屽鍫矗闁汇劌瀚埀顑棗绐涢柨娑橆檧缁?
   * 閺夆晜绋戠€?100 闁?`COLLAPSED_HEIGHT_PERCENT`闁挎稑鐗愰崚娑欐償閺囨氨顏遍柡澶嗘缁辨繃寰勮閸ぱ呬焊鏉堛劍笑閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞挴鍋撻柡澶涚磿濞堟垶顨囧Ο鍝勵唺闁挎稑顦埀?
   */
  private sheetHeightPercent(): string {
    // 闁宠法濯寸粭?閻庡湱鎳撳▍鎺曘亹閵忕姴缍侀柨娑樼墛濡倝鎮惧畝鍕簼濠靛倹顨愮槐姘跺嫉閻斿吋锛?*闊洤鎳橀妴蹇涘箒閹哄秷绀?100%**闁挎稒宀搁崑鍛附濡も偓瑜把囨?濠㈣埖鐗曢惇鎵偓鍦嚀濞呮帞绱撻埡鍌涙澒 + 閻熶椒绀佹竟鈧?閻庣懓鏈崹姘变沪閺囩偟纾婚柨?
    //    闁兼眹鍎寸换鏍煂鐏炶姤鍊遍柡鍐煐鐎?collapseProgress 闁告ê顑囩紓澶愬礃閸涱収鍟囬悘鐐插€块悵顔芥償閿旇偐绀夐悘蹇氶哺濠€浣圭▔閵堝拋娈伴柛鏂诲妿閺侀箖宕烽妸锔芥毉闁告艾濂旂粩鎾偋閸パ咁伌閻忕偐鍋撻柨?
    //    閻炴稏鍔庨獮鍥ㄧ▔閸濆嫬鏁堕悗鍦攰椤箓宕㈢€ｎ偄顣抽柕鍡曠閻ㄦ繈妫冮姀銈嗘櫓濞达絽绉查埀?
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
   * @returns 闁衡偓閹増宕抽弶鈺佹川閳诲吋绋夐鐔感﹂柛姘剧畳椤╋箓鎸婅箛姘闯闁哄秴娲。?闁硅矇鍌涱偨闁?
   *
   * 闊洤鎳橀妴蹇涙寠韫囥儳绐楅柛鎰噹椤旀劗鎮銏犵闁瑰吀绀侀崺宀勫矗椤忓嫬鈷栧☉鎾亾闁哄鍓濆鍌炴晬鐏炶姤绁奸悗瑙勫哺閻濐喗鎯旈敂鐐暠闁硅矇鍐ㄧ厬闁告牞妗ㄧ槐浼村箮婵犲倻娈遍梻鍫涘灪鐏忓骞?0 濡?
   * 闁挎稑鐗嗗顒勬嚀閸愩劋绱ｇ紒瀣儎缁″啴寮伴婵堢濞戞柨鐗嗛ˇ鈺呮偠閸℃瑦鐣?闁炽儲鏌￠埀?閻庣懓鍟板▓?`isDismissPhase2HideMeta()` 濞戞挴鍋撻弶鈺傜◥缁ㄢ晛鈻撻棃娑欑殤闁?meta闁挎稑顦埀?
   */
  private isCollapsing(): boolean {
    // Morph dismiss keeps natural layout mounted; opacity/clip handles chrome continuously.
    return !this.expandState.morphContainerActive() && this.collapseProgress > 45;
  }

  /**
   * 闁?2026-10-17闁挎稒鐭粭鍌涚▔閳ь剙鈻?*闁活亞鍠愰婊勭▔鐎ｎ亜绲洪柟瀛樺姇婵?*闁汇劌瀚悥鑸电椤斿鈧倹鎷呭蹇曠`undefined` = 閺夆晜蓱閻ュ懘骞嬮幇顒€顫犻弶?/ 濠㈡儼绮剧憴锕€顔忛幓鎺撶婵犲﹥鐔槐姘跺Υ?
   *
   * 闁绘挆鍕剶闁哄啰濮烽弲?`WindowInfo.setKeepScreenOn`闁挎稑娼塪esign/animation/WindowInfo.ets`闁挎稑顦卞▓鎴︾嵁閸屾粎鎼奸柛鎺嬪€栧畵渚€鏁?
   * ```ts
   *   setKeepScreenOn(on) {
   *     if (this.screenOn === on) return;                 // 闁?闁稿﹤鍚嬮惀鍛村矗濡儤鐨戝☉鎾崇С缁楀懘宕ｉ幋顖滅妤犵偛鍊婚悺鎴︽晬?
   *     if (window === undefined) return;
   *     this.screenOn = on;
   *     window.setWindowKeepScreenOn(on).catch(娴?);       // 闁?娴?闁挎稒顒盿rn + `screenOn = false`闁挎稑鐗嗛妵鎴犳嫻閵夈儲绀€婵犲﹥鐔槐?
   *   }
   * ```
   * 闁宠法濯寸粭?**闁搞儳鍋炵划鎾焽閿濆懎纾归柡澶嗗墲濡叉悂宕楅幎鑺ユ殯**闁挎稒淇虹€氥垺绋夊鍛婵犲﹥鐔槐婵囧緞鏉堫偉袝濞戞柨顑呴幃妤冪磽閹惧磭鎽犻柛濠囨？缁楀矂鎯囬悢椋庢澖闁稿﹪妫跨粭澶嬬▔閳ь剟鎳?闁?濞戞挸顑勭粩鏉戔枎閳ヨ櫕鍊遍柛濠呭椤曨剙效閸屾瑧绐楅悶姘煎亜缁犳挾绮垫径鎰紝闁圭硶鍓濈敮鈧?
   *   闁?**婵ɑ鐡曠换娆愮▔瀹ュ懎鏅欏☉鎾愁儏瑜?*闁挎稑鐗呯粭宀勫嫉椤戣法娉㈤柛娆忕Т椤︽煡鐓埡鍐╃暠"閻犙囨敱婢ф粎绱旈鐐焸/闁衡偓鐠鸿櫣鍟茬紓鍐惧枛娴?濞戞挸绉甸崹姘扁偓?闁告艾濂旂粩瀛樼▔椤忓嫯鍩岄柣妯款啇缁辨岸濡?
   */
  private keepScreenOnApplied: boolean | undefined = undefined;

  /** Applies the keep-screen-on switch while the playback page is visible. */
  private applyKeepScreenOn(enabled: boolean): void {
    try {
      // 闁稿繐鐗忛悾?*闁活亞鍠愰婊呮啺娴ｉ鐟撻柛娆愬灩濞堟垿宕?*闁挎稑鐗忛弫銈夊箣瀹勯鐒婂┑鍌涘灊缁楀本銇勯悽鍛婃〃闁烩晠鏅茬紞鍛存焾閸婄噥娲ｆ繝濞愩倕鍠曢柨娑橆檧缁辨繈宕樺鍡楃憦閻庣懓鍟禒娑㈢嵁閸屾粎鎼奸柛鎺嬪€栧畵?
      // 闁宠法濯寸粭?濡炪倕鎼花顓㈡晬濮橆剛绠戝銈堫嚙濠€顏堝矗?UIContext 濞戞柨顑呮晶鐘绘晬閸喐锟ラ柣锝呭缁″啴寮伴姘含闁?window 濞戞柨顑呮晶鐘诲礂閸喓妲?`screenOn`闁挎稑顦埀?
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
        // 闁?闁告劕鎳庨惇?promise 濞戞梻鍠曢々?catch闁挎稒鐡猻etWindowKeepScreenOn` 闁哄牜鍓濋棅鈺傛交閺傛寧绀€ Promise闁?
        //   濞戞挸绉电敮瀛樻媴韫囨挻鐨戦柡鍕靛灟缁斿瓨绋夐鍛紦濠㈣泛瀚幃濠囨儍?rejection闁挎稑鐗嗙敮顐﹀级閵夈劎绠归梺鎻掓湰椤掓粓寮伴婵堢闁哄秴鍤栫槐姘舵晬瀹€鍐ｅ亾鐏炶偐鐟鎯扮簿鐟欙箓寮?*闊洤鎳橀妴蹇涘炊閻愬娉?*闁?
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
        // 闁革负鍔庨崵搴ｄ焊娓氣偓濞?URL 闁炽儲鏌￠埀?濞戞挸瀛╅幐閬嶅绩妤ｅ啨鈧浜告笟鈧浼存晬閸у嚤layerViewModel.songCoverUrl()`闁?*闁告艾濂旂粩鎾级閵夛妇鐖?*闁?
        // 缂備緡鍙冮ˉ锝囦焊娓氣偓濞间即骞嶅鍕憹濞村吋鑹鹃崵顓㈡偝?闁哄鈧疇鍩岄柣顔荤窔閸ｇ兘寮伴姘辨闂傚牜娼块埀顑跨窔椤ワ絾娼婚崶銊﹂檷閺夆晜鐟ョ槐鍫曞及椤栫偟甯涢悹浣靛€曢妵鏃堝磽?
        return song.cover;
      }
      // 闁哄牜鍓欏﹢?婵炲本鐟ч鍫焊娓氣偓濞间即鏁嶅姝璦bel` 闁哄嫷鍨冲﹢鈥愁潰閿濆洦鐣遍悘蹇庣窔濞?Resource闁挎稑鐗呯粭澶愬及?`ic_avatar1`闁?
      return song.label;
    }
    return $r('app.media.ic_avatar1');
  }

  // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛鍥ㄧ▔婢跺﹤纾╁☉鏃€绻嗛悿?/ Round 20闁挎稑顧€缁变即宕㈤悢宄板弗闁圭鍊稿﹢顏呮交濞嗘挸娅￠柣銊ュ閺嗭絽鈻?JSDoc 闁硅绻楅崼顏堟儍閸曨剚笑 `originalCoverSource()`
  //   闁挎稑鐗忛鍥ㄧ▔婢跺﹤纾╁☉鎾冲暢閻ゅ棗顔忛幓鎺戠仼闂傚嫨鍊х槐婵堟喆?RzdMusic閻犱焦婢樼换?md 閹?6.13闁挎稑顧€缁辨繈鐛張鐢电懍闂侇偅姘ㄩ惁鎺戭嚕閺囩姵鏆?`backgroundImageSource()`
  //   闁挎稑鐗婂﹢鐗堟姜椤旂厧鍤掗柛鎺斿█濞呭酣鏁嶆径鍡楁 鐎圭寮跺Σ?*閻庢稏鍊曢崝鐟扳枖閵娾晛娅?*闁挎稑鏈弳锝呪枔閸偆顏搁柟鍝勵槶閳?
  //   闁宠法濯寸粭?`isPixelMapCover()` **濞寸姴绉堕崝褔宕烽妸褎鏆?*闁挎稑鐗忓﹢锛勨偓鍦仩閻ㄧ喖鎮介妸褍浠柨娑欑摢releaseBackgroundCoverIfPixelMap()`闁挎稑顧€缁?
  //   **濞戞挸绉烽々锔炬崉閻旂儤绲婚柛?*闁?

  // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛鍥ㄧ▔婢跺﹤纾╁☉鏃€绻嗛悿?/ Round 20闁挎稑顧€缁辩櫗backgroundImageSource()` **鐎瑰憡褰冮崹褰掓⒔?* 闁炽儲鏌￠埀?
  //   閻庣懓鍟抽崵婊冾啅鏉堚晜鐣?JSDoc 閻忓繐宕崯鎾诲及?闁哥儐鍨粩瀵告嫬閸愵亝鏆忛柣鎰潐濡?phoneSwiperBackdropImage闁挎稑鐭侀埀顒€鐭傞崑鍛▔?builder 闁哄牜鍓濋棅鈺呭及椤栨侗鍔ュù鐙呯悼閻?
  //   闁?闂?`phoneSwiperBackdropImage` 濞戞挴鍋撻悹褑娓圭粭鍛棯閸栵紕绀夐柛蹇嬪妺缁劑姊块幆鎵闁活潿鍔忛埀顒€鎳岄埀?
  //   闁告帞濞€濞呭孩绗熷┑鍥хウ濞戞挸绨兼鍥偋閳哄喚鍎婇柛娆戞焿閸ゆ粌螞閳ь剟鏁嶉崸顣昫ules.abc GONE闁挎稑顦抽～?RzdMusic閻犱焦婢樼换?md 閹?6.15闁?

  /**
   * True when value looks like a decoded PixelMap ({@link Resource} has no release).
   *
   * 闁宠法濯寸粭?2026-10-15闁挎稒淇洪崕妤呭疾椤栨稒鏆悗鍦仦濡炲倸螣閿涘嫮藝闁?`imageLabel` **闁诡厽甯婄拹?`Resource`**闁挎稑鐗呯粭澶愬礃瀹ュ牜娼堕悹褍顑嗛崹姘鐠佸磭绉?
   *   PixelMap闁挎稑顦崳?闁哄牜鍓氶弻鐔封枖閺囩偞韬悹瀣暟閺併倝鎮欑憴鍕埅閺夆晜鏌ㄥú?false闁挎稑鑻悿鍕⒔閸涱厼鍤掗柟?*闁稿繑绮岀花宕団偓鐟扮墕瀹?*闁?
   *   濞ｅ洦绻勯弳鈧☉鎾崇Т閸ㄥ綊鏁嶅姝砮leaseBackgroundCoverIfPixelMap()` 濞寸姴绉瑰顒傗偓鐟板暙閸ㄧ晫鐚剧拠鑼偓鐑芥晬閸絽鍓归柡鍜佸灦閸嬪懘寮堕檱閻儳顔忛幓鎺撹含
   *   缂佹鍏涚粭渚€宕℃担椋庣槇閺夌儐鍣ｅ▓?`backgroundImageSource()` 濞戞挴鍋撻悹褑娓圭粭鍛棯閸栵紕绀夐悷?RzdMusic閻犱焦婢樼换?md 閹?6.15闁挎稑顧€缁?
   *   濞寸姰鍎遍幃妤呮嚐閵夛附绠掑ù婊勬そ閸ｆ悂寮悧鍫澪╅悷娆欑悼閻栨粎绱掗幘瀵镐函闁衡偓閹规劗绠?`imageLabel`闁挎稑鐭佺换鏍级閳ュ啿鐎婚柡鈧娆戠獥闁煎浜滄慨鈺呮煂瀹ュ棙鐓€闁汇垻鍠愰弲銉╁Υ?
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
   * 闁宠法濯寸粭?2026-10-15闁?*鐎规瓕寮撶粭澶愬礃瀹ュ嫮绐楅柛娑欏灊閼垫垶绂掔拋宕囩Э濞戞挻绮忛妶?*闁挎稑娼塱mageLabel` 闁诡厽甯婄拹?`Resource`闁挎稑鐭侀～?
   *   {@link isPixelMapCover}闁挎稑顦埀顒€鍊风悮杈ㄧ▔椤忓洨娈堕柣顫妿閸嬶綁鏁嶉崸鍒焍outToAppear` / `onDisAppear`闁挎稑顦换姘舵偩濞嗗繐鏂ч柡宥呭殩缁?
   *   闁搞儳濮崇拹鐔告交濞嗘劖笑濞戞挴鍋撻柡?*閻庣懓顦崣蹇曠磾?*闁挎稒鐭粩鐐▔閳ь剚绂掗妷銉﹀€甸柛娆忕墛濠€浣圭閻戞ê惟濞达絽绉村ù妯荤箙閻愬墎绠?`imageLabel`闁挎稑鑻悾鐘崇瀹ュ洤濮уù鍏间亢缁€瀣嫻閿濆娅為柡鈧穱鎵佸亾?
   *   闁宠法濯寸粭?闁告瑥绉瑰浼村极濞嗘帩鍞查柨娑樼墛濠€鏉库枎閳╁啯鏆柛鏂诲姂閵嗗海鏁敃浣囨帡宕樺畷鍥ㄧ暠闁挎稑顧€缁辩増绂掗妷銉ヮ枀闁煎啿鏈▍娆戜沪閸屾稖顩柡灞炬尵濞?*婵繐绲惧Σ?*閺夆晜鐟╅崳閿嬪濮樻剚娼堕梺鎻掞攻閺備線鎯冮崟顖氫簼鐎?
   *   PixelMap 闁炽儲鏌￠埀?"闁稿繐鐗撻崳鎾绩娣囨墎鍋撴担绋挎櫃闁?`@Local` 閻熸瑱绠戣ぐ鍌炲箲閵忥紕鐖?濞戞搩鍙冨Λ鍧楁⒕閺冨倹绲婚悹瀣暙鐎规娊鏁嶇仦鐣屾剑濞存粌瀛╃紞鏃堝捶?use-after-free闁?
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
   * 闁稿繑濞婂Λ鎾礂閵娿儳娼岄柟缁㈠幗閺備焦銇勭喊澶岀獥闁稿繐鐗婇幐閬嶅绩閹増宕抽柛鏂诲妿閺侀箖鏁嶉崼锝囩閹?0 闁?闁衡偓閹増宕抽柨娑橆檧缁辨繈骞橀鐐垫殮闁告劕绉垫禒顔藉緞瀹ュ洨宕堕柛?chrome 妤犵偠娉涘畵蹇旀姜婵劏鍋?
   *
   * 闁宠法濯寸粭?闁告鐡曞ù鍥绩閹勮含**閻庤纰嶅鍌炲闯?*闂佹彃鐭侀埀顒€濂旂粭澶愬及?`animateTo` 闁汇劌瀚悾顒勫箣閹邦剚绀€閻犲鍠涚槐浼存焽閿濆嫰鍤嬮柛銉у仩閻ㄧ喖宕烽妸鈺佸姤闁告帒妫楀┃鈧柡鍜佸灟缁楀绌卞┑濠勬閻熸瑱绠戣ぐ鍌炴晬?
   * 闂傚牏濮撮悾鐘诲础濮濆本绁伴悘蹇撳綁缁变即宕ｅΟ璇茬亣"閺夆晜鏌ㄥú鏍煥椤旇棄鐦诲ù婊冩閻ュ懘宕ｅ鍛畨"闁靛棗鍊搁悾楣冨籍鐠虹儤鐝ら柟绋款槹濡炲倿姊归崹顔煎箲閹煎瓨娲╃槐婵嬪嫉閳ь剟宕歌箛鏂垮壈闁告劙娼цぐ褔寮伴娑欐毆閻犙冨槻婵晠鎮介弰蹇ｆ蕉閻犲搫鐤囩换鍐晬?
   * 闁稿繑濞婂Λ瀛樼▔閳ь剛鈧鐭槐浼村矗閹寸姵鏅搁柕?
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
   * 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`MainPage.closeWithAnimation()`闁挎稑鐣瓀ujie.pa:171054-171095`闁挎稑顧€缁?
   * **闂傚牏鍋炴晶婊堝礉閸喖褰犻梻?*闁挎稑鐗嗛崣褔姊婚鐔风樆闂?/ 缂侇垵宕电划鐑樻交閺傛寧绀€闁挎稑顦埀顒佹煛閳?缂傚倵鏅濆▓?*濞戞挸绉靛Σ绋棵烘繝姘モ偓澶愭?*闁挎稑鐭侀埀顒€鏈Σ?*濞戞挴鍋撶€殿喚濮靛褏绮ｅΔ鈧幓鈺呮偂?*闁?
   *
   * ## 闁哄啰濮烽弲顐︽儍閸曨偄鏂ч柡鍌氭搐閼镐即鎮?
   * ```
   *   closeWithAnimation() {
   *     if (pullMode && ExpandSnapshot.onReverseMorph(myMorphSnap)) return;   // 闁?濞戞挸顑嗘刊娲焽閿濆棙钂嬮悹渚灲缁变即鎳涢鍕畳濠㈣泛瀚幃?
   *     getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 娴ｅ勃1*#);     // 闁?闁告熬绠戦崹顖炴晬濮橆厼顎為煫鍥跺亞閸?
   *   }
   *   娴ｅ勃1*#闁挎稑婢媢jie.pa:181020-181077闁挎稑顧€缁?
   *     濠㈡儼绮剧憴?闁?hilog.warn('root snapshot failed, fallback: 闁?) + nav.pop()    闁挎稑鐗婂Λ銈夊矗?= 濞戞挸绉撮悽顐ｆ姜椤掆偓濠р偓闁?
   *     闁瑰瓨鍔曟慨?闁?ExpandSnapshot.onShrinkBack(pixmap, this.mySrcBox) + nav.pop(false)
   *   onShrinkBack 闁?ShrinkOverlay.start(闁?     闁?闁哄牜鍏涚划銊╂儍?MorphShrinkState
   * ```
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸綆娲ｉ柣鎾楀嫭鍎旈柨娑樼墢閺併倝骞嬫搴剳 闁?闁哄鎵冲亾鐏炵偓绠掗柤鍐叉湰濞呮瑦鎷呴崱妯恍﹀Δ鍌浢€规娊鎮ч柅娑氱У闁靛棗绋勭槐?
   * 闁瑰瓨鍨冲鎴炵▔閳ь剟鎯勭€涙ɑ笑"闁告柣鍔嶅鍧楁儍閸曨剚灏￠柡鈧ィ鍐︹偓?闁挎稑鐗婇弫鑲╂啑娴ｇ顥呯紒鎰殔瑜?+ 缂傚倵鏅滈弬渚€鏁嶆径鍡楁 闁告瑯浜ｉ々锔界▔閵堝牃鍋撻崨顒傜憹闁告艾鏈鐐烘晬鐏炵晫娼屽☉鎾筹工濮樸劑寮?
   * "闁哄牆顦抽崕妤呭疾椤栨ǚ鍋撴担椋庣ɑ闁告瑯浜滄晶鍨嚗閸垻鍙濋柣銊ュ缁旀挳寮?闁靛棗鍊介埀?*缂傚倵鏅欑粩鏉戭嚕閻樺弶绂?*闁哄啯鍎奸崕妤呭疾椤栨瑧鐟㈤悘蹇庣窔濞?*闁告艾鏈惁顔界瑹?*闁挎稑鐭傞崑鍛矓瀹ュ懓鍩岄柣妯绘构缁楀宕ｉ婵嗗幋闁告垼娅ｉ獮鍥Υ?
   *   闁宠法濯寸粭?濞戞挸顑嗘刊娲焽閿濆棙钂嬮悹?*濞ｅ洦绻勯弳鈧?*婵炴彃顭烽妴澶庛亹閵忕姴缍侀柨娑樼墛濡倝鎮惧畝鈧▓?`onReverseMorph` 閻忓繗椴稿Σ鍝モ偓鐟板枦缁辨岸鍨鹃弬琛″亾?
   *     闁活潿鍔嶉崺娑橆啅閼碱兘鈧鎷嬮妶鍐ｅ亾鐏炲憡鍠楀☉鎾筹攻婵椽骞嶉幘宕囩；/濞戞挸顑嗘刊娲礂閹惰姤锛旈柣銊ュ閻ㄦ繈妫?闁煎啿鏈▍娆撳礉閵娧勬毎婵繐绲介悥鍫曞Υ瀹ュ繒绀夊☉鎾崇Т婵晝鈧懓鍟ㄩ埀?
   *
   * ## 闁哄牜鍏涚划銊╂儍閸曨剚衼閻?
   * ```
   *   闁哄啰濮烽弲?pullMode            闁愁偅鍔忛崯?闁哄牜鍓欓ˇ?闁哄嫷鍨粭澶愬及椤栨瑧鐭ゅ☉鎾愁儐婵椽鏌囬敐鍡樿拫閻犱警鍨卞鐢告儍?闁挎稒纰嶅﹢浼村棘鐟欏嫮銆?*闁告瑯浜ｉ～锕傛閻愭潙顤侀柛鏂跨仢閸欏棝宕ｉ敐鍫㈡闁?*
   *                                 闁挎稑鐗愰～?`onCollapseRequested`闁挎稑顧€缁辨繈骞嶉埀顒佺閵夈劎绠婚柡澶堝劚濮樸劑寮?闁?闁衡偓椤栨ǚ鍋?
   *   闁哄啰濮烽弲?PLAYER_ROOT_ID      闁愁偅鍔忛崯?闁哄牜鍓熼妴澶庛亹閵忕姴缍侀悗鍦嚀濞呮帗绋夋繝鍕暠 `.id(PLAYER_ROOT_ID)`闁挎稑鐗忛崣搴ㄥ箹椤掆偓閹挻绋夐埀顒佹媴瀹ュ洨鏋傞柨?
   *   闁哄啰濮烽弲?mySrcBox            闁愁偅鍔忛崯?`expandState.barWinX/Y/W/H`闁挎稑鐗愮化鐘虫媴閻樿櫕钂嬮柤瀹犳硾濞夘參鎯冮崟顓犲炊闁告瑱绲块悡鈺勩亹椤喚绀塿p闁?
   *   闁哄啰濮烽弲?nav.pop(false)      闁愁偅鍔忛崯?`state.isShowPlay = false`闁挎稑鐗嗛敍鎾朵沪?`popPlayerRoute()` 闁活潿鍔庡▓鎴﹀及?
   *                                 `pageIndexInfos.pop(false)` 闁?闁哄牜鍓欏?*濞戞挸绉撮悽顐ｆ姜椤掆偓濠р偓**闁?
   *   闁哄啰濮烽弲顐ｅ緞鏉堫偉袝闁衡偓?nav.pop()     闁愁偅鍔忛崯?闁告艾鏈悧杈╃磾?`isShowPlay = false`闁挎稑鐗婇崹婊勭椤掑倹鐣?pop 闁诡厽甯楀Λ銈嗘姜椤掆偓濠р偓 闁?缂佹稑顦悳顖炴晬?
   * ```
   *
   * 闁宠法濯寸粭?`mySrcBox`闁挎稑鐗愰崗宀勫炊婵犲嫮鍙愮憸閭︽緛缁?*闁告瑯浜滃﹢顏囥亹閵忕姴缍佸ù鍏间亢閻﹁棄顕欓搹鍦綄闁哄啫鐖奸崳娲礆?*闁挎稑娼塺eportMini` 闁?`barWin*`闁挎稑顦埀?
   *   闂佹彃绻嬬粭澶愬礆閻楀牊顦?`MorphShrinkState.start` 濞村吋淇洪摂瀣籍閻樺灚娅曢梺顓ㄧ稻濞?`start skipped: no srcBox` 闁衡偓?
   *   闁挎稑娼塿isible=false` + `onDone()`闁挎稑顦崳?闂侇偀鍋撻柛鏍ㄧ墬閸?闁哄啰濮存慨鈺呮偨鐠囨彃褰犻梻?闁?*濞戞挸瀛╁Λ銈夋偩瀹€鈧▓鎴︽焻閳ь剟宕犻弽顒傜唴鐎垫澘瀚粩鎾嚊?*闁?
   *   闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗RzdShrinkOverlay` / `root snapshot failed`闁?
   */
  private closeWithAnimation(): void {
    if (this.isClosing) {
      return;
    }
    const winW: number = this.expandState.windowWidthVp;
    const winH: number = this.expandState.windowHeightVp;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闊洤鎳橀妴蹇涙偝娴兼潙娅ゅ☉鎾亾婵炲枴銈呭帯闁搞儱锕﹂悡鈺勩亹?* 闁炽儲鏌￠埀?閺夆晜鐟﹀Σ?閺夆晜鏌ㄥú鏍礂閹惰姤锛斿ù鍏肩煯缁楀瀵煎顒€缍侀柟瀛樺姈濡倝宕濋妸褎鏆?闁汇劌瀚槐鎴﹀礂缁涘湱绀嗛柨?
    //   `barWinX/Y/W/H` 闁?`measureGeometry()` 闁告劖鐟辩槐婵嬫嚀鐏炵晫鏆?*闁告瑯浜滃﹢顏呯▔閵堝拋妲?*閻炴凹鍋夐惃鐔兼偨椤帞绐?
    //     鐠?闁告艾瀚?opening 閻犱警鍨扮欢鐐烘儍閸曨啟澶愭煂韫囥儳绀刞measureMiniDuringPull` 闁告劕鎳橀崕鎾焽閿濆棙钂嬮梺鐐嫕缁辨岸鏁?
    //     鐠?**`refreshCollapseGeometry()`**闁挎稑鐗婂Λ顐﹀礂閹惰姤锛旈悹渚灠缁剁偤宕烽妸銊﹀闯闁归潧顑嗗鍌炴偝娴兼潙娅ゅ☉鎾亾婵炲棌妲勭槐姘跺Υ?
    //   闁?闁兼眹鍎插﹢浼村级闄囬惌鐐▔?`barWin*` 濞寸姴绉崇拹?0闁挎稑鐗呯欢銉︿繆閸屾稑鈪电€殿喒鍋撻悹褎澹嗗▓鎴﹀及椤栫偐鍋撻埀顒勫礌閺嶎剛鐔呯€垫澘瀚ㄩ埀顑挎缁姴鈻介敓鐘叉闁告帗濯界换鍐晬婢舵稓绀?
    //     `MorphShrinkState.start()` 濞村吋淇洪摂瀣籍閻樺灚娅曢梺顓ㄧ稻濞?`start skipped: no srcBox` 闁衡偓?
    //     闁?**閺夆晜鏌ㄥú鏍礂閹惰姤锛旈柛娆惿戦崹?闁哄啰濮存慨鈺呮偨閼姐倖绾柟鎭掑劜缁夐攱寰?**闁挎稑鐗撻崑鍛村及椤栨艾璁查悷娆庣濞叉牞銇愰幒鐐电濞戞挸绉靛Σ?婵炲备鈧弶鍙忓┑?闂侇叏绲肩粻鐐存姜娴兼瑧绀嗛柕?
    //   闁宠法濯寸粭?閺夆晜鐟╅崳?*闁烩晛鐡ㄧ敮瀵告嫬?`measureGeometry`**闁挎稑濂旂粭澶愭偨閵婏附锛嬮柣?`refreshCollapseGeometry()` 闁炽儲鏌￠埀?
    //      闁告艾姘﹂埀顒€鎳撻崵婊呮暜?`morphStage === OPEN` 闂傚偆鐓夌槐娆撴焻閳ь剟宕犻弽銊モ叺鐎殿喒鍋撻柡鍐╂构缁变即寮?LANDING/NONE 闁?濞寸姭鍋撳☉鏂跨墦閸忔ɑ绋夊澶婃闁挎稑顧€缁?
    //      闁兼澘鑻幓鈺呮偂瑜戦惌鎯ь嚗?*闁告瑯浜〒鍓佹啺娴ｈ棄鍘￠柛銉ワ功閻撯晞銇?*闁挎稑鐗婂Λ顐︽儍?`morphInitParams`/`freezeMorphMeta` 闁哄嫷鍨崇划?
    //      婵炴彃顭烽妴澶屾偘閵夆晜锛熼柣顫妿濞堟垿鏁嶇仦鐐嫳閻犱警鍨扮欢鐐寸▔瀹ュ浠橀悷鏇氱筏缁辨岸濡?
    const measured: boolean = this.expandState.measureGeometry(this.getUIContext(), true, true);
    const srcBox: MorphShrinkRect = {
      left: this.expandState.barWinX,
      top: this.expandState.barWinY,
      width: this.expandState.barWinW,
      height: this.expandState.barWinH
    };
    // 闁稿繗娅曢幐閬嶅绩閹勭彜閺夆晜鐟ょ粩瀛樼▔鐎ｂ晝鐟濋悷鏇氱閸熲偓闁煎浜滄慨鈺呭绩閼搁潧浠橀柛鎺曟硾鐏忣垶鏁嶉崼婊呯憿 closeFullScreenPlayback 闁告艾濂旂粩鎾级閳藉懐绀?
    this.stopChromeAutoHide();
    this.isClosing = true;
    PlaybackPage.lastCloseAtMs = Date.now();
    // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闊浂鍋嗛崣搴ｆ崉椤栨氨绐為柛娆樺灣閺併倝骞€瑜旈。鈺佄涢埀?* 闁炽儲鏌￠埀?閻?`closeLiveMorphFallback` 闁汇劌瀚崹搴☆潰瑜戦鈺呭及鎼搭垳绀?
    //   濞戞挶鍊撻柌婊堝礈瀹ュ棗绲归柨娑欏焹閹?闁煎疇娉涘▔顓㈡儗閳轰浇鍩岄柨娑樻綁srcBox`闁挎稑顦甸崳娲礆妫颁胶鍟婇柨娑欑▓閹?缂佹劖顨呰ぐ娑氫焊閸濆嫷鍤熼柡鍫濐槸閳ь剛銆嬬槐妾侻orphShrinkState.start`
    //   闁汇劌瀚悮杈╃博椤栨艾褰嗙€殿喖绻橀崗姗€宕ラ崘銊ф殜闁挎稑顦埀顒€鍊烽幑銏＄▔閳ь剚绋夊鍡楃亣缂佹柨顑呭銊╂儎鐎涙ê澶嶉悹褌鍗抽埀顑藉亾闁告牗鐗為惌鎯ь嚗閸曞墎绀?*濞戞挸绉撮獮鎾诲箯瀹ュ浜濈€殿喚濮甸弫鐐碘偓瑙勭閻ュ懘鎮介妸褎鐣遍煫鍥跺亞閸?*闁?
    if (srcBox.width <= 0 || srcBox.height <= 0 || winW <= 0 || winH <= 0) {
      this.closeLiveMorphFallback(
        `noSrcBox meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
        `win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      return;
    }
    PlaybackPage.ev('CLO', `snapshot p=${this.expandState.morphP.toFixed(2)} ` +
      `meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
      // 鈽?2026-10-17锛?鏈夋椂鍊欎袱涓皝闈?瑕佽兘涓€娆″垽璇伙級锛氭妸"璋佸湪鐢诲皝闈?涓変釜閲忚杩涗簨浠舵棩蹇椼€?
      //   `rc` = 鎾斁椤电湡灏侀潰鍦ㄧ敾銆乣oc` = 澹冲眰鍏嬮殕灞傚湪鐢汇€乣ss` = 杩欎竴鍏冲綊蹇収銆?
      //   蹇収鎴愬姛鐨勬甯告€佸簲褰撴槸 `rc=1 oc=0 ss=1`锛涜嫢鍑虹幇 `oc=1` 鈬?蹇収闂ㄨ缁曡繃浜嗐€?
      `rc=${this.expandState.realCoverVisible() ? 1 : 0} ` +
      `oc=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
      `ss=${this.expandState.snapshotShrinkOwnedFlag() ? 1 : 0} ` +
      `tint=${this.tintReady ? 1 : 0}`);
    Logger.info(PlaybackPage.logTag,
      `RzdShrinkOverlay closeWithAnimation: snapshot ${PLAYER_ROOT_ID} ` +
      `win=${winW.toFixed(0)}x${winH.toFixed(0)} ` +
      `bar=(${srcBox.left.toFixed(1)},${srcBox.top.toFixed(1)},` +
      `${srcBox.width.toFixed(1)}x${srcBox.height.toFixed(1)})`);
    // 闁宠法濯寸粭?闊浂鍋嗛崣搴ょ疀閸涙番鈧繘宕?*鐟滆埇鍨硅ぐ澶婎嚕閳ь剚鎱ㄧ€ｂ晝顓洪柛?*闁瑰嘲绋勭槐鏉款潰閵堝懎鐓濋悗鍦嚀濞呮帡寮伴娑楄埅缂佹稑顦ぐ澶愬箲椤喚绀勬繝濞锯偓宕囨綄闁挎稑顧€缁辨繈骞忓鍛厒闁汇劌瀚晶鐘诲及?婵犲ň鈧磭娼岄梺顓ㄧ导缁旀潙顕?闁?
    //   闁宠法濯寸粭宥夊煣閻欏懐鐟?`restorePlaybackWindowChrome()` **濞戞挸绉烽崗?*闁衡偓閹勮含闁瑰嘲绉撮幓鈺呮偂瑜岀粻锝夊礈?闁炽儲鏌￠埀?閻庣懓鍟╃槐浼村箒閵忕媭妲荤紒鎰殔瑜版稓鏁崘銊ф拱
    //     闁挎稑娼塧pplyPlaybackWindowChrome(false,闁?`闁挎稑鏈﹢鐗堛亜閸︻厽绐楅柛锔哄妽閹搁亶寮ㄦィ鍐︹偓澶嬪濮橆厼惟缂佹劖顨呰ぐ娑㈡煣閸濆嫬鐓傞柡浣割嚟閻涖儵鏁嶆径娑氱
    //     閻㈩垰鍟惇顒佺▔閳ь剟宕ｅ鍫㈢闁瑰嘲绉撮崺宀勬儍閸曨偅鐨戝☉鎾崇У濡?婵犲绱曢悰銉╂焽閿濆嫮顏辩€?闁靛棗鍊风粭宀勫籍瑜戦惌鎯ь嚗閸曨亞顏遍柤鐤彧缁?*闁衡偓鐠鸿櫣鍟查柡鍐煐婢х娀骞侀姀鐙€妲?*闁?
    // 闁宠法濯寸粭宥夊煣閻欏懐鐟?2026-10-17闁?*闁活潿鍔嶉崺娑㈠箣椤忓嫭绂堥柡鍡樻尦濠€鍫曟儍閸曨厽鍩?bug**闁挎稒鐭花銊︾閼稿灚锛夐煫?`CLO:闁?fb=snapFail` 闁?闊浂鍋嗛崣?*婵絽绻戦濂告焾閽樺浜奸悹?*闁?
    //   濞存粌瀛╁Σ绋啃掕箛搴ｎ伇婵炲枴銈囩闁搞儳鍋涢崣褔姊婚銏犲幋闂侇偀鍋撻柛鏍ㄧ墪閸╁苯煤婵犳哎鈧銇愰姀鐘茬秮 闁?**闁活潿鍔嶉崺娑欑鎼淬垺闄嶆繛宀嬬磿濠€鍛村礆閹峰瞼绠栭柡鍐Х閺咁偊鏌囬敐鍡樿拫闊浂鍋嗛崣搴ㄥ绩閸撲胶绱?*闁?
    //   濞寸姵鐗楁慨銈夋儍?閻忓繋绶氬浼村椽瀹€鍐ㄥ壒闁哄拋鍨电换鏇㈠及椤栨瑧顏辨俊顖椻偓鑼伇闁哄秹顥撳▓鎴︽⒒椤曗偓椤?閻忓繗椴稿Σ鍛婃交濞嗗酣鍤嬮柨娑橆槶閳?
    //   闁哄秶鎳撳ú婊堟晬?*闁瑰瓨鍨冲鎴犳嫬閸愵亝鐣遍柡鍕靛灠閸欏繒浠﹂埀顒勬焽閿濆嫰鍤嬬€瑰憡褰冪花鎯ь嚕閸愵亝鐣遍梺鎻掔Х濞?*闁靛棔绻朄ohos.arkui.componentSnapshot.d.ts`
    //   `function get(id, callback, options?)` 闁哄秴娲ㄥ?**`@deprecated since 18`**闁靛棔妞掔粭鏍ㄥ濮橆厼顫?
    //   `100001 - Invalid ID`闁挎稒绋栭埀?*濞戞挸锕ラ悥鍫曟偨閵娧勭暠闁?`UIContext` 闂侇叏绲肩粩鎾绩?*闁?
    //   `wujie.pa:171077-171093`闁挎稑娼塒layerPage.closeWithAnimation` 闁?娴ｅ秹鏁嶆径鎰ㄥ亾閹邦厽钂嬮悷娆欑到閸ゎ參寮堕妷锔诲妧闁?
    //   ```ts
    //     this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, 娴ｅ勃1*#)
    //   ```
    //   闁?闁绘粍婢樺﹢顏堟偂瑜岀粭鍌氥€掗幖浣镐簼濞戞挴鍋撻柡澶嗗墲閺佸ジ宕樺▎娆戠闁哄牜鍓氶弸鍐╃?L3464 闁汇劌瀚弫鐐烘煂婵犲洤娅?*闁哄啠鏅涘銊╁礃濞嗘垶绲?*閺夆晜鐟ら柌婊嗐亹閵忋垹笑闁挎稑濂旈崬顒勬儘娴ｇ绁辨繛灞勩倗顎€濞戞挸顭槐姘跺Υ?
    //   闁?濠㈡儼绮剧憴锕傚储閻旈攱绀堥柣鎾楀嫭锛嬮弶鈺傜◥缁ㄣ劍绂掗懜鍨級闊洦顨愮槐婵嬬嵁?*闁?err.code 濞戞梻鍠庨悽顐ｇ▔?*闁挎稑娼塮b=snapFail(100001)`闁挎稑顧€缁?
    //     401 = 闁告瑥鍊归弳鐔兼煥?/ 100001 = 闁归潧褰炵粭澶愬礆閹峰瞼绠瑰☉?id 闁?濞戞挴鍋撴繛鍡忓墲閸╁懘宕堕幆褍绁柛娆樺灠閻ｅ墽鎷嬮幁鎺嗗亾?
    this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID,
      (err: BusinessError, pixmap: image.PixelMap): void => {
      // 闁冲厜鍋撻柍鍏夊亾 闁圭粯鍔掑锕傚礂閹惰姤锛旈柡鍐ㄥ濞?*闁哄牜鍏涚划銊╂偋鐟欏嫭绠掗柡鈧捄铏瑰暡**闁挎稑鐗婂Λ銈夋偩鐏炲墽姊鹃柡?婵炲苯顦伴煫鍫㈢玻濡も偓瑜?閺夆晜鐟ラ〃婊堟晬鐏炴儳顣插ù鐘劚閻ｇ姴鈻介埄鍐╃畳閺夆晜鐟ょ悮閬嶅矗閵夘垳绀?
      //   闁?闁诡厹鍨归ˇ鑼寲閼姐倗鍩犻柡?缂佹劖顨呰ぐ?chrome 闁炽儲鏌￠埀?濞戞挸绉垫禒顔藉緞瀹ュ洦鐣遍悹鍥ㄧ箚缁绘垿宕堕悙鎻掑綘闂傚偆鍘虹粻锝夊触鎼淬劊鈧﹪寮借箛搴ｇ獥闁稿绮屽﹢?闁圭虎鍘介弬浣广亜閸偆鐒芥繛?闂侇叏绲肩粩瀛樼附濡ゅ懎甯抽柤纭咁嚋缁?
      //   闁?`morphLand()` 濞存嚎鍊涚换鏇犵磼濡搫鐓戦柡?闁?閺夆晞娓圭紞姗€寮?*闁活亞鍠曢棅?*缂佹柨顑呴崺銏ゅ及閹冩瘔闁?
      //      闁挎稑鐗呯粭澶嬬閵堝牏绠烽柣銊ュ閻︾晫鎲版担铏规惣婵炴惌鍠栭惇鏉壳庨垾鍐叉瘔 闁?50ms 濞戞柨顑呴幃妤呭箥瀹ュ洦绠欓柛鎺撳缁姵鎷呴悩铏拫"闁?闁革附婢橀崵顓㈡偝鐢喚绀嗛柕?
      //   闁宠法濯寸粭?`morphLand()` 闁硅泛锕﹀ù澶嬫媴瀹ュ洨鏋?`LANDING`闁挎稑濂旂徊鎯ь潰閵堝懎鐓?`morphP = 1`闁挎稑鐗嗛崹?`refreshCollapseGeometry`
      //      闁告帞鏌夌换鍐晬婢跺棗娅?閻庡湱鎳撳▍?`.height(morphClipHeight)` = 闁轰礁顕悰銉╁Υ娑旑柟cale = 1` = **闁诡厽甯為悺?*
      //      闁?闂傚棙鍎奸～鍥箛閻斿嘲缍侀柛鏍ㄧ壄缁辫鲸鎷呴弴鐐叉瀸闂?1~2 閻㈩垎鍌滅憪闂傚牄鍨肩换鏇㈡儎閺嶎偅绲诲☉鎾崇Ч閳ь剙绻戝Σ鎴︽儍閸曨偅褰ラ柣鎾楀嫯鐧侀悘鐐插€堕埀?
      //   闁宠法濯寸粭?**濠㈡儼绮剧憴锕傚绩椤栨瑧鐟濋弶鈺傜缁绘牗绋夐埀顒傗偓?*闁挎稑鐗嗛悾鐘垫啺娴ｅ€熸巢闂侇偀鍋撻柛鏍ㄧ墳閻儳顕ラ崟鍓佺闂侇叏绲惧?`morphLand()` 濞村吋纰嶆俊鎼佹儎闂€鎰Т闁圭粯鍔曟晶鐘电礄缂佹ê绔撮柨?
      //      闁?`closeFullScreenPlayback()` 闂傚洠鍋撻悷鏇氭缁?閺夆晜锚濠€顏嗕沪閺囩偟纾婚柟?閻犙囨敱婢ф粓鏁嶆径鍡楁 閻熸瑤妞掔粭鍛存?`if` 闁汇劌瀚紞鍛磾椤旇　鍋?
      if (err !== null && err !== undefined) {
        Logger.warn(PlaybackPage.logTag,
          'RzdShrinkOverlay root snapshot failed, fallback: ' + JSON.stringify(err));
        // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁哄牜鍏涚划銊╁礆缂佹ê澹堥柣銊ュ閸ㄥ骸顫㈣閸?*闁挎稑顧€缁变即寮悩鍨珪闁汇劌瀚妵鎴犳嫻閵夛附鏆滈柡?`nav.pop()`闁挎稑鐗婂Λ銈嗘姜椤掆偓濠р偓闁挎稑顧€缁?
        //   闁瑰瓨鍨冲鎴炴交濞嗘挸娅￠梺顐熷亾闁?*闁哄牜鍏涚划銊╁籍閵忊剝绠掗柣銊ュ濡炴寧銇勯棃娑滃煂闁?*闁挎稑娼塩loseFullScreenPlayback()`闁挎稑顦埀顒€鍊婚幃濠囨偨閹插绐?
        //   鐠?闁哄啰濮烽弲顐﹀箯瀹ュ洦鐣遍柡?`PLAYER_ROOT_ID`闁挎稑鐗呯粩瀛樼▔椤忓懏鐝梺?Stack闁挎稑顧€缁遍亶骞嬮幋婊勭拨闁瑰嘲绉跺▓鎴﹀及?**`NavDestination(DIALOG)`
        //     闂佹彃鐬煎▓鎴︽嚍閸屾粌浠?*闁挎稑鐭佺换鏍级閳╁啳顩柡灞炬崄閻儳顕ラ崟顒佇?*闁瑰瓨鍨冲鎴︽偋鐟欏嫭绠掗柣?* 闁?濞戞挴鍋撻柡?`componentSnapshot` 闁革负鍔忕换鏍级闄囬惌鐐▔?
        //     缂侇垵宕电划娲箑瑜嶈ぐ鍥ㄧ▔瀹ュ懎鐓傞柛銉︽嫕缁?*婵絽绻嬬粩鏉戔枎闄囩换鎴﹀炊閻愭彃褰犻梻?*闂侇喗鍨濈槐浼存焻閳ь剟宕犻弽銊ョ亣"濡炪倗鏁诲浼存儎鐎涙ê澶嶆繛鎴濈墕閵? 闁炽儲鏌￠埀?
        //     闂侇叏绲惧Σ绋啃?闁煎啿鏈▍娆撳矗椤忓嫬鈷栧☉鎾亾闁?濞戞挶鍎甸崳绋款嚗濡も偓椤﹀潡鎯冮崟顐㈣閻熸瑤绀佸ú鏍亹閹虹偟骞?
        //   鐠?婵炴彃顭烽妴澶庛亹閵忕姴缍侀柡鍫墲闂娾晠寮?*鐎规瓕灏～锕傛偨閵婏箑鐓曠痪顓у枦椤撳宕ｉ婊勬殢**闁汇劌瀚伴崑鍛▔閳ь剚绺藉Δ瀣闁冲牭鎵冲亾鐏炶偐鐟愰柟宄邦槹婢э箑顕ｉ埀?濞戞挸顑嗘刊娲礂閹惰姤锛旈柣銊ュ閻ㄦ繈妫?闁煎啿鏈▍娆撳礉閵娧勬毎婵繐绲介悥鍫曞Υ瀹ュ繒绀嗛柨?
        //     闂侇偀鍋撻柛銉у仜楠炴捇寮甸埀顒勫锤韫囧海鐦嶉柛娆樹簼濡叉悂宕堕悙鎻掔厒闁告鍠愬鐢告儍閸曨噮娼庨柟鎵枔閹蹭即鎮块悙鍏夊亾?
        //   闁宠法濯寸粭?濠㈡儼绮剧憴锕傚储閻旈攱绀堥柣鎾楀嫭锛嬮柟?`Logger.warn`闁挎稑鑻懟鐔煎箮婵犲倸鏂ч柛銉уТ閻㈩偅娼诲☉妤冪殤濞寸姾鍩栧Λ鈺勭疀濡ゅ绀刞CLO` 闁?`fb=`闁挎稑顧€缁?
        //     **濞戞挴鍋撴繛鍡忓墲閸╁懘宕堕幆褍绁柛娆樺灠閸ㄧ晫鎷?*闁挎稑鐗愰～?`closeFallbackReason`闁挎稑顦埀?
        this.closeLiveMorphFallback(`snapFail(${err.code})`);
        return;
      }
      this.restorePlaybackWindowChrome();
      // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*濞ｅ浂鍠氶弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鑻崣褔姊婚鐔割槯濞村吋鑹鹃崵顓㈡偝妫颁浇鈷堝☉鎿冧簻閻ㄦ繈妫冮～顑藉亾?*闁?
      //   闊浂鍋嗛崣搴☆啅閼碱剛鐥呴柟宄扮Т閸╁本绂嶉崱妤冩闂傚牜婢佺槐婵嬫嚀鐏炶偐鐟撻梻?`morphLand()` 濞村吋纰嶆俊鎼佹儎闂€鎰Т缂傚喚鍠楅崹?`LANDING`
      //   闁炽儲鏌￠埀?`LANDING` 闁?`morphContainerActive()` 闂佹彃鐬奸悾?闁活亞鍠撳▓鎴﹀捶閵婏附灏? 闁?濠㈢懓鍟块惇浼村礂鐎ｎ喗鐣烽悘鐐插€风槐鎵偖椤愶箑浜濋柡?
      //   闁烩晠鏅茬紞鍛村礂濠婂啰淇洪柛娆樺亯閹癸綁寮?闁?**闊浂鍋嗛崣搴ㄦ煂瀹€鍕簼鐎殿喚濮撮惃婵嬫?+ 闁稿繐顑夊▓鏇犱沪閸岀偛浜濈€殿喚濮撮惃婵嬫閵忕姵鍊遍柡鍐ㄧ埣椤?* = 濞戞挶鍊撻柌婊呬焊娓氣偓濞间即濡?
      //   闁?闁?`morphLand()` **濞戞柨顑呮晶?*濠㈠湱澧楀Σ?閺夆晜鐟ょ粩鎾礂閸愯尙绉洪煫鍥跺亞閸?闁挎稑鏈拠鐐典沪閸岀偞锛岄柨娑樻綁morphOverlayBridging`闁?
      //     闂傚懎绻愰幃妤呭箒閹烘垳娴烽柕鍡楀亰缁辨瑩宕ｉ鍕含闊浂鍋嗛崣搴ㄥ箣閹邦剙顫犻弶鈺傜懁缁旀挳寮ㄩ姘剧矗闁哄嫬鍑界槐杈ㄥ緞鏉堫偉袝闁衡偓椤栨繍娲ｉ梺顐熷亾闁搞儳鍋炲鎸庛亜闂堟稖鍩岄柛娆愶公缁辨繃绂掑澶嬩粯閻熸洑鐒︾拠鐐典沪閸屾ǚ鍋撻崒锔剧
      this.expandState.beginSnapshotShrink();
      // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳?*缂侇垵宕电划鐑樻交閺傛寧绀€闁稿繑濞婂Λ鎾箻椤撶喐鏉归柛锝庣厜缁辨繈骞橀鐔告澒闁哄绻濋崑鍛▔婢跺鍤嬮柟绋款樀閹告娊宕欓搹鐟扮疀闁汇劌瀚﹢渚€鎮欑憴鍕紞濞?*闁靛棗绋勭槐?
      //   闁告鍠愬鍨交濞嗘挸娅?*缂佹柨顑呴崺?* `morphLand()` 闁炽儲鏌￠埀?闂侇叏绲惧Σ?濞存嚎鍊涚换鏇犵磼濡搫鐓戦柡?闁?閺夆晞娓圭紞姗€寮堕敍鍕焸闂婎剦鍋呭Ο澶愬礄閻戞ɑ闄?闂侇叏绲肩粩鏉戭潰閵夘垳绀?
      //   濞存粌瀛╁Σ姝岀疀椤愩倕寮鹃弶鈺偵戦惀鍛磽閳轰胶鏆氶柨娑樼墐婢?50ms闁挎稑顧€缁辨繃鎯旈弴姘辩憮闁汇劌瀚化鐘虫媴閻樿櫕钂嬮柨娑樼墕閹牓鏌囬敐鍕憦濞戞搩浜濈€垫粓鏌﹂鍡欑閻忓繐宕崙锛勭磼韫囨稒鑻熼柛鎴犲劋濞煎灚绂?
      //   闁?閻熸瑥鍊归崝?闁圭顦甸幐鎶藉礂閸繂姣夐柣婊嗗焽閳ь兛绀侀惃婵嬫閵忕姵鍊甸柦鈧幋鎺旂Т"闁?
      //   闁?闁瑰壊浜滈崺宀勫绩閸撲胶绱?*缂備焦鎸诲?*闁挎稑娼塻hrink.start` 闁?onDone闁挎稑鐭侀～鍡樼▔鐎ｅ墎绀嗛柕鍡楀€界换鏍ㄧ▔閳ь剛鎹勯娆戠憪闁烩晠鏅茬紞鍛┍濠靛洤鐦?ENTERING/LEAVING闁?
      //     `realCoverVisible()` 濞戞梻鍠庡ú婊冾潰閵堝洦鍩涚紓渚囧弨椤斺偓濞达絽绋勭槐婵囩▔瀹ュ嫮绐楅柛鎰Т閸熷宕欓搹璇″剳濞存粌鑻槐鍓佷焊娓氣偓濞间即濡?
      //   闁宠法濯寸粭?`morphLand()` 闁告瑯浜滄晶?闁烩晠鏅茬紞?闁?LANDING + 濞存嚎鍊涚换鏇犵磼濡搫鐓戦柡?濞戞挶鍊撳▎銏＄鐎ｅ墎绀夐柡?350ms 閻犲鍟惀鍛村嫉婢跺﹤顥屽ù锝嗙矌閺併倝濡?
      const shrink: MorphShrinkState = this.morphShrinkState();
      shrink.start(this.getUIContext(), pixmap, srcBox, winW, winH, (): void => {
        // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹?`MainPage` 闂侇叏绲奸柌?**onDone 娴ｅ勃12*#**闁挎稑鐣瓀ujie.pa:154940-154949`闁挎稑顧€缁?
        // ```ts
        //   () => { this.miniHidden = false; this.shrinkPixmap = undefined; }
        // ```
        //   鐠?`miniHidden = false` 闁炽儲鏌￠埀?闁哄牜鍏涚划銊р偓鐢垫嚀缁ㄦ煡鎯冮崟顒佇?閺夆晞娓圭紞姗€寮?*闁活亞鍠曢棅?*闁告瑯鍨甸～?闁?
        //     閻忓繗椴稿Σ?`morphLand()`闁挎稑鐗呭锔芥交濡偐甯涢柛鎺曞煐濞煎牓鏁嶆径鍫氬亾?*閻庣懓鍟换鈧銈堫嚙濠€顏堝绩閸撲胶绱氱紓浣规尰濞碱偅娼诲▎搴ｎ伇闁?*闁挎稑鐭侀～鍡樼▔婵犲洦妗ㄩ柣銊ュ椤曗晠寮版惔顖滃耿
        //   鐠?`shrinkPixmap = undefined` 闁炽儲鏌￠埀?闁?**闊洤鎳橀妴蹇涘磻?*闁挎稒宀搁崑鍛村及椤栨瑧顏辩€?*婵犲绱曢悰?* PixelMap
        //     闁?080閼?400閼?B 闁?10MB 缂佺嫏宥囩闁挎稑鑻崣鈩冪椤愩倕笑闁诡兛妞掔粩鎾儎閺夋垹绌块柣顫妿濞煎啰鈧懓鍟銊︾▔瀹ュ嫮绐楅悶姘煎亜濞叉牠寮ㄩ煬娴嬪亾?
        //     濞戞挸锕ｇ粩鎾偋?*婵犳洖绻嬬花鈩冩交濞嗗海顏遍柛?* 闁?婵絽绻愰崣褎绋夐埀顒€鈻庨埄鍐╁啊闁衡偓閹勭彜閻忓繐宕ˇ鍧楁偩濞嗗海顏辩€殿喚濯寸槐娆撴儎閺夋垵鐓傚☉鎾愁儎缁旀潙鈻庨垾鍐插綘闂傚偆鍘芥晶鐘垫偖椤愩儺娲柣鈺傜壄缁辨岸濡?
        Logger.info(PlaybackPage.logTag, 'RzdShrinkOverlay onDone (overlay hidden, pixmap dropped)');
        // 閴€?2026-10-17閿?*娑撳秴鍟€閸︺劏绻栭柌?`morphLand()`** 閳ユ柡鈧?娣囶喚鏁ら幋宄扮杽濞?
        //   閵嗗瞼鏁ょ化鑽ょ埠鏉╂柨娲栭崗鎶芥４閿涘苯濮╅悽鑽ょ波閺夌喓娈戦弮璺衡偓娆掑剹閺咁垰浠犻崷銊︽拱閺夈儳娈戞０婊嗗閿涘瞼鍔ч崥?*缁愪胶鍔ч崣妯诲灇閻忔媽澹?*閵嗗稄绱?
        //   閸樼喎娲滈敍姝歮orphLand()` 閹跺﹦娴夋担宥囩枂閹?`LANDING` 閳?`morphContainerActive()` 娴犲秳璐熼惇?
        //   閳?瑜般垹褰夌€圭懓娅掔紒褏鐢荤悮?`morphClipHeight()` 鐟佷焦鍨氭稉鈧弶掳鈧梗MeshCoverBg` 闁絼绔寸仦鍌濈閻偓鐞氼偉顥嗛幒?闁插秴缂?
        //   閳?闂囨彃鍤€瑰じ瀵岄惃鍕瑝闁繑妲戞惔鏇為獓閼硅绱檂defaultImageBgColor` = 濞ｈ京浼嗛敍? 閻劍鍩涢惇瀣煂閻?缁愪胶鍔ч崣妯间紗"閵?
        //   娑撳﹥鐖堕柇锝勯嚋 `onDone 浣峘閿涘潉wujie.pa:154940-154949`閿涘褰ч崑姘⒈娴犳湹绨ㄩ敍?
        //   `miniHidden = false` + `shrinkPixmap = undefined` 閳ユ柡鈧?**濞屸剝婀?*"閹跺﹥妞挎い闈涱槻娴?鏉╂瑤绔村銉礉
        //   閸ョ姳璐熺€瑰啰娈戞い鐢告桨閸︺劌鎻╅悡褑鎹ｉ弶銉ф畱閸氬奔绔撮崚璇叉皑瀹歌尙绮?pop 閹哄绨￠妴?
        //   閳?鏉╂瑩鍣烽崥灞剧壉閸欘亝绔?pixmap閿涙稓娴夋担?閸戠姳缍嶉惃鍕槻娴ｅ秳姘︾紒?`onDisappear 閳?morphReset()`
        //     閿涘牓鍋呴弰顖欑窗鐠囨繂鏁稉鈧惃鍕槻娴ｅ秶鍋ｉ敍宀冾潌 `morphReset` 閻ㄥ嫭鏁為柌濠忕礆閵?
        shrink.clearPixmap();
        // 婵炴惌鍠栭惇浼村绩鐠鸿櫣鍟查柨娑樼墐婢?50ms闁挎稑顦粻锝夊触鎼粹€虫櫃闁衡偓閹呯；闂傚倹鎮傚Λ顒勬晬濮橆収鍔€閻㈩垱鐡曢惌鎯ь嚗閸曨亞鐟撻梺顓ㄧ稻濡炲倹銇勯悽鍛婃〃闁哄啠鏅涢崙锛勬偖?pop闁?
        // 閺夆晜鐟ょ粩鎾矗閵夈儱娑ч柡?濞戞挸娲ｇ粩鏉戔柦?pop 闁?闁汇劌瀚崵婊堝箛閸剛绀勯柛姘嫰閵囨垹鎷归妷锔芥殰闁汇劌瀚幃濠囨偨閹插绀嗛柕?
        this.isClosing = false;
      });
      PlaybackPage.ev('SQZ', `shrink win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      this.state.isShowPlay = false;
      // ★★★★ 2026-10-17（修「系统返回关闭时左下循环 / 右下歌曲列表两颗按钮消失」）
      //   那两颗 `SymbolGlyph` 不是被裁、也不是换了分支 —— 它们**没进这张快照**。
      //   官方 `componentSnapshot` 文档对第三个参数原话：「设置是否强制系统在截图前等待所有绘制指令
      //   执行完毕…该选项可尽可能确保截图内容是最新的状态，**应尽量开启**」，并写明「如果在组件触发
      //   更新的同时调用截图，更新的渲染内容不会被截取到」。本方法在拍图**之前**刚标脏渲染树
      //   （`measureGeometry` / 事件日志）⇒ 符号字形来不及画进图，`Image` 那几颗却已在图里
      //   ⇒ 只剩 prev/play/next。给快照开 `waitUntilRenderFinished`（options 必须在第三位）。
    }, { waitUntilRenderFinished: true });
  }

  /** 闁告瑦鐗曠欢閬嶅礂閸欐﹢鐓╅柣銊ュ閹烩晠鎮¤閺佸湱绱撻埡鍐ㄐ﹂柟顑跨筏缁辨瑦绋夋惔鈽呯处閻?`Index` 闁告艾濂旂粩瀛樼▔?AppStorageV2 閻庡湱鍋樼欢銉╂晬婢跺牃鍋?*/
  private morphShrinkState(): MorphShrinkState {
    return AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
  }

  /**
   * 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稒鑹鹃幓鈺呮偂瑜戦惌鎯ь嚗閸曨亞鐟濋柛娆樺灣閺併倝寮崜浣圭暠**闂侇偀鍋撻柛鏍ㄧ墪閸ゎ參宕?* 闁炽儲鏌￠埀?闂侇偀鍋撻柛銉у仦濠€鐗堢閹惧瓨锛嗛柡鍫濐槺濞?婵炴彃顭烽妴澶庛亹閵忕姴缍?闁稿繑濞婂Λ鎾Υ?
   *
   * ## 閺夆晜鐟﹀Σ鍛婄▔鎼淬垺锟ラ柣锝呯灱濞?*濞戞挴鍋撳璺哄閸┿垽骞囪箛鎾崇€绘慨?*闁挎稑鐗愰鍥捶閵婏富鏀抽柨娑樿嫰閸╁棝宕樺鍛Ъ濞?婵炲矉绱曢崣搴ㄥ箹?闁?
   * 闁哄啰濮烽弲?`娴ｅ勃1*#`闁挎稑娼墂ujie.pa:181020-181077`闁挎稑顦﹢顏囩疀椤愩倕寮惧鎯扮簿鐟欙箓寮懜鍨?`nav.pop()`闁?*闁哄啰濮村?= 濞戞挸绉撮悽顐ｆ姜椤掆偓濠р偓**闁挎稑顧€缁?
   * 濞戞梻鍠庡銊╁及?濡炪倗鏁诲浼存儎鐎涙ê澶嶆繛鎴濈墕閵?闁靛棗鍊归崹婊勭?*濞?*闁绘挆鍕剶闂侇叏绲肩粩鎾级閳藉懐绀夐柣鐐叉閺佽鲸绋夐妶鍡樿拫闁?
   * 1. 闁瑰嘲绉跺▓鎴犫偓鐢殿攰閽栧嫭绋夊鍛€遍柨娑欑濡倝鎮剧仦鎯ь€?`PLAYER_ROOT_ID`闁挎稑鐗呯粩瀛樼▔椤忓懏鐝梺?`Stack`闁挎稑顧€缁辨繈骞嬮幋婊勭拨闁瑰嘲绉跺▓鎴﹀及?
   *    **`NavDestination(DIALOG)` 闂佹彃鐬煎▓鎴︽嚍閸屾粌浠?* 闁炽儲鏌￠埀?閺夆晜鐟﹀顖氥€掗崣澶屽帬閻犱警鍨扮欢?*闁哄嫷鍨遍崹婊勭椤掑倸顥楅柡鍫濐槺濞?*闁?
   *    濞戞挴鍋撻柡?`componentSnapshot` 闁革负鍔忕换鏍级闄囬惌鐐▔婵犲嫰鍏囩紓浣哄枑閳ь儸鍐ㄧ悼濞戞挸绉撮崺宀勫炊閹惧懐绀?*婵絽绻嬬粩鏉戔枎闄囩换鎴﹀炊閻愭彃褰犻梻?*闂侇喗鍨濈槐浼存焻閳ь剟宕犻弽銊ョ亣
   *    "濡炪倗鏁诲浼存儎鐎涙ê澶嶆繛鎴濈墕閵?闁挎稑鐭傞崑鍛村及?*婵?闁煎啿鏈▍娆撳矗椤忓嫬鈷栧☉鎾亾闁?濞戞挶鍎甸崳绋款嚗濡も偓椤?*闁汇劌瀚ぐ鑼喆娴ｅ憡绀€鐟滅増甯槐?
   * 2. 婵炴彃顭烽妴澶庛亹閵忕姴缍侀柡?*闁活潿鍔嶉崺娑橆啅閼碱兘鈧鎷嬮妶鍛闁?*闁汇劌瀚伴崑鍛▔閳ь剚绺藉Δ瀣缁绢収鍠涢璇层€掗崨顓炵 闁冲牭鎵冲亾鐏炶偐鐟愰柟宄邦槹婢э箑顕ｉ埀?濞戞挸顑嗘刊娲礂閹惰姤锛旈柣銊ュ閻ㄦ繈妫?闁煎啿鏈▍娆撳礉閵娧勬毎婵繐绲介悥鍫曞Υ瀹ュ繒绀嗛柨?
   *    闂侇偀鍋撻柛銉у仜楠炴捇寮甸埀顒勫锤韫囧海鐦嶉柛娆樹簼濡叉悂宕堕悙鎻掔厒闁告鍠愬鐢告焽閿濆洤浠悷娆忓€归崝鍛存偡閺囩姵鐓忛柕?
   *
   * ## 閻熸瑱绠戣ぐ鍌炲级閳ュ弶顐介柨娑樼墔鐞氳鲸寰勯崟顔炬闁活潿鍔庨崑锝夋晬?
   * 鐠?`closeWithAnimation()` 闁?*濡澘瀚ˉ?*闁挎稒淇洪崗宀勫炊婵犲嫮鍙愮憸?/ 缂佹劖顨呰ぐ娑氫焊閸濆嫷鍤熷ù鐘侯唺缁斿瓨绋夊鍛闁汇埄鐓夌槐妾俠ar=0x0`闁挎稑顧€缁?
   *   婵縿鍊栧鍌涙交閻愬弶褰ラ柣鎾楀洤鍘村☉鎾崇Т楠炴捇骞忓蹇曠闁瑰嘲绉崇花鈩冪▕閻斿摜姊鹃柣銏╃厜缁辨岸鏁?
   * 鐠?闊浂鍋嗛崣搴ㄥ炊閻愬墎娈堕柣?*濠㈡儼绮剧憴锕傚绩?*闁挎稑娼塭rr` 闂傚牏鍋熼埞鏍晬婢跺牃鍋?
   *
   * ## 闁告瑯鍨甸浼村箑?
   * 闁告鍠庡ú婊堝礃濞嗘帞绠婚梻鍫熺懄閳?`closeFallbackReason`闁挎稑鐬奸弫?`closeFullScreenPlayback()` 闁?`ev('CLO', 闁?`
   * 濞戞挴鍋撻悹褔鏀辨晶锔芥交濞戞鐨戝ù鐘哄煐濡晞绠涘Δ瀣鐎垫媽濮ら悥锝囩箔椤掆偓瀹曞嫭绋夋径搴斀闁?`fb=`闁挎稑顦崳?**濞戞挴鍋撴繛鍡忓墲閸╁懘宕堕幆褎鐨戦柤宕囨櫕濠€鍛村礄妤﹁儻娉叉繛灞勩倛娉查梺顐熷亾闁?*闁?
   * @param reason 闂侇偀鍋撻柛鏍ㄧ墪鐢偊宕堕悪鍛闁活収鍘介悥锝囩驳閹惧懐绀夊ù鍏间亢缁绘ɑ绂嶇€ｂ晜顐介柡鍐﹀劚缁绘棃鏁?
   */
  private closeLiveMorphFallback(reason: string): void {
    Logger.warn(PlaybackPage.logTag,
      `RzdShrinkOverlay fallback 闁?live morph (${reason})`);
    PlaybackPage.closeFallbackReason = reason;
    // `closeFullScreenPlayback()` 闁汇劌瀚鍥ㄧ▔閳ь剟鏌嗛幘缁橆槱閻忓繗椴稿Σ?`isClosing`闁挎稑鑻换鈧銈囩帛閺備礁顕ｉ埀顒勫箥瀹ュ牏绠荤€电増顨呴獮鎾诲Υ?
    this.isClosing = false;
    this.closeFullScreenPlayback();
  }

  private closeFullScreenPlayback(): void {
    if (this.isClosing) {
      return;
    }
    // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*缂?闁稿繑濞婂Λ瀛樻媴濞嗘劕鐨剧紒鎰殔瑜?闁烩晜鐗滈悵?闁炽儲鏌￠埀?閺夆晜鐟ょ粩瀵告偘鐏炵偓笑濞戞挸锕ｇ粩瀛樻姜椤旂晫纭€闁瑰搫顦卞▓?*闁?
    //   閻?`lastCloseAtMs` 闁汇劌瀚弫鐐烘煂婵犲繒绐楅柛鎰噹椤旀劗浠?`.onAppear()` 闁汇劌瀚崢瑙勬償閺囩偛鐎婚柡鈧鐐存祮閻庣懓鍟崹浠嬪棘?
    //   "閺夆晜鐟ょ粩鏉戔枎閳ュ啿姣夐柣婊勫濞堟垿鎳為崒婊冧化闁哄嫷鍨粭澶愬及椤栨艾鐏犻柟闈涚Ч閸嬪懎鈻庨垾鍐插綘闂傚偆鍘惧▓鎴炴媴濞嗘劕鐨?闁?*闁告瑯浜滃﹢顏呮交濞嗘挸娅￠柛鎰懀閳ь兛绶氶崑鍛存煂瀹€鍐惧殺**闁?
    //   濞戞挶鍊曢ˇ鈺呭箣閹邦剦鍤犻柨娑樼墔缁楀倹绋夐埀顒佹姜椤旂厧娑ч柡鍫濐槼椤曚即濡存担鍦⒕闁哄牆顦崯?闁?闂傚倶鍔嶆禍浠嬪磻閸ラ绀嗛柕?
    PlaybackPage.lastCloseAtMs = Date.now();
    // 闁?闁哄啳娉涚花顓燁渶閹存繂鐨ラ悗娑欏姧缁变即寮甸渚囧仹闁稿繑濞婂Λ鏉戭嚕閳ь剚鎱ㄧ€ｅ墎绀勯悷?`evLog` 闁汇劌瀚弫鐐烘煂婵犲繒绀?
    //   闁?2026-10-17闁挎稒鐡猣b=` = 閺夆晜鐟ょ粩鏉戔枎閳╁啯笑**濞寸姴楠搁幓鈺呮偂瑜戦惌鎯ь嚗閸曨垪鍋撻埀顒勫礌閺嶎剛绠栭柡澶堝劤濞?*闁挎稑鐗愰～?`closeFallbackReason`闁挎稑顧€缁?
    //   閻犲洩顕ч悾顒勫础閾忣偆顏?闁?`fb=` 缂?= 閻犙勫濞堟垼绠涢銈呭季閻犱警鍨扮欢鐐烘晬濞屾b=snapFail` / `fb=noSrcBox 闁炽儺娉?= 閻犙囶暒缁ㄢ€趁烘繝姘モ偓澶庛亹閵忕姴缍侀柕?
    const fb: string = PlaybackPage.closeFallbackReason;
    PlaybackPage.closeFallbackReason = '';
    PlaybackPage.ev('CLO', `gen=${this.closeGen + 1} p=${this.expandState.morphP.toFixed(2)}` +
      (fb.length > 0 ? ` fb=${fb}` : ''));
    // 闁宠棄鎳夊Σ?P0-2闁挎稒纰嶅﹢鐗堟姜椤旂厧褰犻梻鍌ゅ幘濞?*闁绘瑯鍓涢悵娑欑閿濆棭鍋?* + 闁告瑦鐗楃粔閿嬬▔婵犱胶顏遍弶鐑嗗枛瑜版煡鎳楅崐鐔虹闁圭鍊诲鍐儍閸曨偄绁婚弶鐐舵閻ｉ箖寮捄鐑樼彜闁?
    //   `isClosing` 闁圭硶鈧磭绻佸ù?闁衡偓閹増宕抽柛鏂诲妿閺佺偓娼诲☉婊庢斀濞?闁汇劌瀚伴崳鎼佸礂閵夘垳绀夊ù锝呮閻ｇ娀宕?`morphCloseMs + 20`闁挎稑鐗冩晶?70ms闁?
    //   閻忓繗绮鹃～锕€銆掗崨顓熺 `false`闁挎稑鐭侀埀顒€鐭傞崑鍛▔閳ь剟宕氱紒妯诲啊闁衡偓妤ｅ啨鈧?*闁告瑯鍨甸崗妯绘交濡崵姊?unmount** 闁?缂佹鍏涚花鈺佲枎閿涘嫬浠柛鎴ｎ唺缁变即宕樺鍫熷闯濞戞挴鍋撻柡?
    //   350ms 閻炴稏鍎靛Λ?+ 缂佹鍏涚花鈺傜▔椤忓嫬绁婚弶鐐舵閻ｉ箖寮捄鐑樼彜闁挎稑鐭侀埀顒€濂旂悮閬嶅级閿熺姵鎳犻柣?`morphGen` 闁烩晝顭堥幃?闁?`morphGenAlive` 闁瑰嚖缂氱粭澶嬫媴韫囧鍋?
    //   闁哄牆顦花?`closeGen` + 闁告瑣鍎查悞娲晬瀹€鈧鍥ㄧ鐏炵虎鍋ч柣鎰嚀閸ゎ喚鎲版担椋庣杽閻炴凹鍋呭Σ鎴犳兜椤斿吋瀚归柣锝冨劘閳ь兛娴囬々锔界▕閸繂鍙￠柛鎴斿亾闁规亽鍎抽鎼佸Υ?
    const closeGen: number = this.closeGen + 1;
    this.closeGen = closeGen;
    if (this.closeSettleTimer !== -1) {
      clearTimeout(this.closeSettleTimer);
      this.closeSettleTimer = -1;
    }
    this.refreshCollapseGeometry();
    this.isClosing = true;
    // 婵繐绲藉﹢顏堝绩閹増宕抽柟缁㈠幗閺備線宕抽妸锔筋槯濞戞挸绉烽々锕傚礃瀹ュ牆娈伴柛鏂诲妽閺佸綊骞掕閸╂宕犻悮瀵哥濞戞挶鍊撻柌婊堝礉閵娧勬毎闁告瑧濮崇粩瀵告導閾氬倻绐楃€垫澘鐗呯拹锟犳晬?
    this.stopChromeAutoHide();
    // 闁稿繑濞婂Λ鎾嫉閻斿吋锛熼弶鈺傜☉鐎硅櫕瀵煎顑跨不闁?闁衡偓閹増宕?闁告垹濮峰▍銊バ掗銈庢健闁挎稑鑻崺鍡欐媼閳轰胶娼旂€殿喒鍋撻柣顏勵儔濡剟鎮Δ浣肝╅悗鐟板暞婵娀宕堕悙鑼殮闁轰礁鐡ㄩ埀?
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 闁?閻犙勫濞堟垿寮伴姘冲煂闁告瑦顭堥惌鎯ь嚗閸曨偅鐨?*闁告瑥绉撮幃婊呮崉閹存繃鍊卞☉鎾亾濠靛倹顨呴崵鎴炴媴?*闁挎稒纰嶉弳锝嗐亜閻㈢數绱氶柛銉у仩缁姵鎷呴悩铏拫闂侇叏绲肩粩瀵镐焊韫囨挻鍋ラ柕鍡曟祰椤ュ棝宕滈鍡欏炊闁告瑱绲鹃弫褰掑炊閻愭彃绠甸柨?
    //   闁哄牃鍋撻柛姘唉閹倝宕堕悙鍓佺濞达絿濮靛顖炴晬閸︾嚄NDING闁挎稑顦埀顒€鍊搁惈宥咁嚕閳?闁衡偓閹増宕抽悘蹇氶哺濡叉悂宕ョ仦鑲╊伇濠靛倹顨呭顒勫极閹殿喗鐣辨慨婵撶到瀵姤绋夐妶澶夋喚闁挎稑濂旈幑銏ゅ箛韫囨梹顦ч柛鎺戭煼閸忔﹢鎳涢鍛敧闁?
    //   闁宠法濯寸粭?闁告帇鍊曢悾楣冩偨?`morphUsable` 闁?*濞戞挸绉靛Σ?* `morphContainerActive()`闁挎稒姘ㄨ彊閻庤鑹鹃惈宥咁嚕閳ь剟骞€娴ｇ儤鐣遍柣鈺呮櫜缂嶅懘寮?
    //      OPEN闁挎稑鐗呯粭澶愬及?ENTERING/LEAVING闁挎稑顧€缁辨繈鎮介妸銉﹀€甸柤鏉挎噹閸ㄧ晫鈧鐭槐浼村箳婢跺﹥绀€"闁告ê顑嗘晶搴ㄥ礃閸涱収鍟囬悘鐐插€块悵顔芥償?闁汇劌瀚埀顑跨婵晠鎮?闁炽儲鏌￠埀?
    //      闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳宕氶幍顔界暠闁靛棗鐬奸弫銈囧寲閼姐倗鍩犻弶鈺傛煥濞叉牠宕楅幎鑺ワ紨閺夆晜蓱濡叉悂寮婵晠鎮藉Ч鍥ｅ亾瀹ュ懏鐨戦柡鍕靛灥缁绘牠鏌岀仦鐑╁亾?
    if (this.expandState.morphUsable) {
      // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁衡偓閹増宕抽弶鈺傜懁缁斿瓨绗熻缁″啰鎲版担鐣岀畺"闁告垹濮崇紞宥囦焊鏉堚晛宕?闂侇叏缍佹禍楣冩⒒?*闁挎稑顧€缁?
      //   闁哄牜鍓濋悿鍡欑磼?`applyMorphProgress` 闁告梻濮崇花鈩冪▔閳ь剟鏌嗛幘瀛橈骏闁伙絽鐬煎▓鎴︽⒒椤帞绀刞morphGeomReady`闁挎稑鐭侀～鍡涙焽閿濆嫰鍤嬮悗娑欘殕椤斿矂鎯冮崟顒佹殘闂佹彃顭槐姘舵晬?
      //   闁告垹濮崇紞宥呪柦閳ヨ櫕鐨戠紓渚囦簼濡炲倻鈧?*濞寸姭鍋撳☉鏂跨墦閸忔ɑ绋夊鍛驳**闁靛棗鍊规晶锕€顕ｉ埀顒佹交濞嗘劖钂嬮悹渚灦濞?`measureMiniDuringPull` 缂傚喚鍠曠紞鍛存晬?
      //   闁?闁绘劗鎳撻崵顕€宕楅幎鑺ワ紨 / 缂侇垵宕电划鐑樻交閺傛寧绀€闁稿繑濞婂Λ?闁哄嫷鍨划?*鐎规瓕灏欑划锟犳媰閹存帞绉撮柣銊ュ婢э箑顕ｉ埀顒勫箑?*鐎垫壋鍋撻柛銉у仩缁?闁炽儲鏌￠埀?婵繐绲介悥鑸垫償閺傝法绉肩€规瓕灏欓悿鍡樻媴瀹ュ繒骞?
      //   濞达絽妫楃槐鎾舵暜濮濆瞼鐔呯€垫澘瀚哥槐娆撳箥閹惧磭纾婚柡鍐╁劶钘熼梺鎻掔箰閵囨垹鎷归妷銊х畺濞戞挴鍋撴繛鍠℃壋鍋撴稊顤硂rphReset` 濞戞柨顑呴幃妤呭矗閸絿绠婚柡澶堝劗閳ь剨璁ｇ槐姘濮樻剚鍞ㄩ悗鐟板暞濡叉悂宕戦崶椋庣
      //   闂侇叏绲惧鍌涚▔鐎ｎ喗妗ㄩ梺?460ms 闁汇劌瀚弫鍦導閻ゎ垁澶愭⒒閺夋垶鐨戦柡?*闁轰礁鐡ㄩ宀€绮氭ウ鎸庣ギ** =
      //   闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳鎯冮崟鈹惧亾瀹€鈧崑锝夊礄鐠囨彃褰犻梻?/ 缂侇垵宕电划鐑樻交閺傛寧绀€ 婵炲备鍓濆﹢浣轰焊娓氣偓濞?闁煎啿鏈▍娆撳礉閵娧勬毎闁靛棗绉查埀?
      //   闁?閺夆晜鐟╅崳鐑芥偨閵婏箑鈪电€殿喒鍋撻柟顑跨閸戯繝寮垫径灞剧暠缂佹棏鍨抽崑锝夊礄閻樿京绉块柛蹇旂矊缁ㄦ娊寮ㄩ幑鎰垫斀闁挎稑鐗婂Λ銈夋偩瀹€鈧▓鎴﹀绩閹増宕抽柡鍫墯濞肩數浜搁崣妯肩憹闂佹彃绉甸弻濠囨煂韫囨洜鐭掗柣鎰缁辨岸濡?
      if (!this.expandState.ensureMorphGeomForClose()) {
        Logger.warn(PlaybackPage.logTag,
          'close: geometry unresolved on both ends 闁?close without morph animation');
      }
      // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁?*闁稿繑濞婂Λ鎾籍閸洘姣愬☉鎾虫捣缁憋箓宕?*闁挎稑顦埀顒佹煛閳?
      //   **閺夆晜鐟ょ粩瀛樺緞閸曨偅鐨戦柡鍕靛灣閺併倝骞嬪畡鎵澖婵炴潙顑冮埀顒€鑻崣褔姊婚鐔稿啊闁衡偓閹勭彜闁告垹濮崇粻顔尖柦閳ュ啿袟闁汇垺鐪归埀顒€绉跺▓鎴︽儑閻斿摜澹岄柛銉уО閳?*
      //   闁哄啰濮烽弲?闁稿繑濞婂Λ鎾箵閹邦亝鍞?闁挎稑娼縰it闁挎稑顦崹搴ㄥ绩椤栥倗绀刞_recover/logic-src/鐎殿喒鍋撻柛蹇氭珪閹搁亶寮ㄩ幆褎鐝?闁归潧顑呮繛宥囨崉椤栨氨绐為悗瑙勬皑椤?md`
      //   閹? 闂侇偆鍠愰悡锛勬偘?L27/L29闁挎稑鑻悥鍫曟煂韫囨哎鈧?閹煎倿宕?L620-633闁挎稑顧€缁?
      //     `reverseMs = round(REVERSE_MS(460) 閼?max(REVERSE_MIN_RATIO(0.4), morphT))`
      //     `animateMorphT(reverseMs, t = 0, REVERSE_EASING)`
      //     `REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`   闁?闁?**闁逛究鍨归幆搴ㄥ礉?*
      //   闁宠法濯寸粭?闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉柡?**350ms + `cubicBezier(0.23, 1.0, 0.32, 1.0)`**闁挎稑鐭侀埀顒€鐭傞崑鍛村级?
      //      闁挎稑娼塃ASE_OUT_STR`闁挎稑顦板Σ?*闁瑰灚鎸哥槐鎴﹀箵閹邦亝鍞?*闁活潿鍔庡▓鎴︽晬?*闁?15% 闁哄啫鐖煎Λ璺ㄤ焊鏉堫偉娉查悗鐟扮灱鐎?70% 閻炴稑鐬奸埢?*
      //      闁?350ms 闂佹彃鐬肩€?50ms 閻忓繗浜紓澶屸偓鐟板缁繝濡存担绋库挅濞?300ms 闁告垹濮崇粻顔界閳ь剚绋婇崼銉ュ幋婵炲备鈧啿绲洪柣?闁炽儲鏌￠埀?
      //      闁活潿鍔嶉崺娑㈠箛閻旇櫣鍙€閻忓繗椴稿Σ?**闁稿繑濞婂Λ鎾礄閻樿京顔呮繛灞糕偓鍐残楅柣?*"闁挎稒鐭粭澶愬及椤栨稓姊鹃柟缁㈠弿缁辨繈寮?*濞戞挴鍋撻柣顏傚妿濠у倻浜告潏銊ф⒕濞?*闁?
      //   闁?濞戞挶鍊曢ˇ鈺呮焾閼恒儱鐦婚柡鍐Х閺咁偊寮ㄩ惂鍝ョ獥闁哄啫鐖奸弳?`460 閼?max(0.4, morphT)`闁靛棔鑳剁槐锕傚礉?**`REVERSE_EASING`**闁?
      //      濞戞挸顑囬弲?`460閼?.4 = 184ms` 濞ｅ洦绻嗛惁?闁告瑯浜濇刊鍝勵嚕閳ь剚绋夐埀顒勬倷閸︻厼浠悘蹇氶哺濠㈡骞?闁哄啯婀圭弧鍐╂交濡粯绠掑☉鎿冧簻閸庢岸寮芥搴㈢暠闁衡偓鐠哄搫鈼㈤柕?
      //   闁宠法濯寸粭?**闁告帩鍋呮俊鍛婄▔閵堝棙钂嬬紓鍌涙尭婵晠骞栭悙纾嬬┛**闁挎稑鐗嗛悾鍓х矙?閹煎倿宕?L385 闁告鍠愰弸鍐晬濮樸儮鍋撶€瑰硤EVERSE_EASING` 闁告瑯浜滃﹢?
      //      '闁圭粯鍔掑锕傚礂閹惰姤锛?quit)'閺夆晜鐟ょ粩鎾绩椤栨粍鏆忛柨?*闁告瑦鐗楃粔鐑藉炊閻愯尪鍓ㄩ柛娆忕Х閳ь剙鐬奸弫?`EASE_OUT_STR`**闁靛棗绋勭槐姘舵晬?
      //        鐠?闁瑰灚鎸哥槐鎴﹀箵閹邦亝鍞?/ 闁瑰灚鎸哥槐鎴﹀矗閺嶃劎啸 闁?`EASE_OUT_STR`
      //        鐠?**闁稿繑濞婂Λ鎾箵閹邦亝鍞?闁?`REVERSE_EASING`**
      //        鐠?闁稿繑濞婂Λ鎾矗閺嶃劎啸闁挎稑鐗嗗ú鏍ь嚕閻у摜绀嗛柍?`EASE_OUT_STR`
      //   闁宠法濯寸粭?閺夆晜绋戠€瑰疇绠涢崨娣偓蹇涘捶?`morphBeginLeaving()` **濞戞柨顑呮晶?*闁告瑦鐗槐娆愮▔鐎ｎ喗妗ㄩ梺顓ㄧ导闁?`applySync` 闂佹彃濂旂槐浼村绩閸︻厽绁插ù锝呯▌缁辨岸濡?
      const closeFromT: number = this.expandState.morphP;
      // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁挎稑鐗呯悮杈ㄧ▔椤忓嫷妯嗛梺顔哄妽鑶╅柛銊ヮ儎缁辨壆鎷犳繝鍌涘€?*闁稿繐宕幃鎾诲箰閸パ勫€?*闁汇劌瀚伴崑鍛▔閳ь剟寮堕埥鍛闁告梻濮崇花锟犲箮閵堝棛鍩夐柨娑橆檧缁?
      //
      // ## 闁汇儱娲ㄦ慨?
      // 闁靛棗鐬奸柈瀵哥磼閻旇崵绠查柛?/ 闁稿繑濞婂Λ鎾箰婢舵劖灏?/ 濞戞挸顑嗘刊娲级閻愵剙顤侀柨娑欒壘閻ㄦ繈妫?*闁烩晛鐡ㄧ敮瀛樼▔鐎ｎ亜绠?/ 闁烩晛鐡ㄧ敮鎾礆閺夎法姣堥柛锕€妫楅懜?*闁挎稑鏈惀鍛村嫉婢跺苯顏紒鏂款儔椤ワ絿鎮板畝鍕簼濞戞挴鍋撴俊顐ｅ竾閳?
      // ## 闁哄牆鎼崺?
      // 闁衡偓閹増宕抽悶娑栧劦濡潡鎯冮崟顔藉闯闁绘劘顫夊Σ?*婵炴惌鍠栭惇浼存嚊椤忓嫮绠掗柣銊ュ缁绘ɑ鎯?* `morphOverlayP`闁挎稑鐭侀埀顒€鑻悾鐘诲捶閵娿倗鐟撻梻鍫涘灱缁绘牜绮斿鍡楀壈鐟滆埇鍨介崳鐑藉及?**0**闁?
      //   鐠?闁瑰灚鎸哥槐鎴︽焽閿濆嫮顏辨俊顐ｅ笧濞堟垵霉椤旇偐婀撮悶娑栧劦濡灝鈻介敓鐙€妫ч悹褔鏀卞鐢告晬閸粎浼愬┑鈥冲€介～?`hostsMorphOverlay` / 闁哄啠鏅犻埀顑藉亾闁圭硶鍓濈敮鈧柨娑橆檧缁?
      //     闁?`morphOverlayReset()` 闁?P 闁告ê顑呭ú?0 濞戞柨顑呴幃妤冧焊閸楃偛鏅欐繛灞勩値娼堕柟鎭掑妺缁楀倿宕㈡导娆戝耿
      // 闁?濞存粌瀛╁Σ?`morphOverlayTweenTo(false)` 闁瑰嘲鐏濋崺?`from = 0`闁靛棔姊梩o = 0`
      //   闁?閻?`|to - from| < 1e-4` **闁哄啠鏅犻埀顑藉亾**闁挎稑鐗愮换?animateTo 闂侇喗鍨濈粭澶婎嚈閻氬绀?
      //   闁?闁?`morphOverlayBridging()` 闁汇劌瀚ù澶嬫媴瀹ュ懎骞戦幖瀛樻礀閸ㄥ酣寮?*濞寸姴绉堕崝褎绋夐搹瑙勫焸**
      //     闁挎稑娼塵orphContainerActive() && snapStartW > 0 && endCoverSize > 0`闁?
      //   闁?闁稿繐顑夊▓鏇犱沪?*闁轰礁鐡ㄩ宀勫礂閹惰姤锛旈梺顔炬櫕閺侀箖宕?`morphCoverRectAt(0)` = 閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞搩浜滈惃顒勫捶?*濞戞挸顭槐婵囩▔閳ь剟宕濋妸銈囩憹闁告柣鍔婇埀?
      //
      // ## 濞ｅ浂鍠楃涵鍫曟晬閸喎袘闁哄秴绻掓晶妤呮晬?*闁告瑯浜滃﹢?缁绢収鍠栭悿鍕柦閿熺媭妫ч弶?闁?*閻庨潧缍婄紞鍫ユ晬瀹€鈧划閿嬬▔瀹ュ棗鈪甸柡鍌ゅ幗椤掓粓宕烽妸鈺婃＇闁汇劌瀚换妯绘償閿旇偐绀?
      // 闁兼眹鍎茬拠鐐典沪閸屾繄绠婚幖杈剧細缁盯宕戝鍐╄含 0闁靛棔娴囬埀顒€鐭傞妴澶愭閵忕姷绉奸柛鎾崇Х缁绘ɑ鎯?> 0 闁?闁硅泛锕ら悾鐘碘偓闈涚秺缂嶅牓宕氭导娣偓澶愭閵忥絿绠婚幖?
      // 闁? 鐎圭寮跺﹢渚€鎯?`syncMorphOverlayFromPage()`闁挎稑鐭侀銏＄▕婢跺鍔€闁?婵炴惌鍠栭惇鐗堟交濞戞ê顔?:= 濡炪倗鏁诲鐗堟交濞戞ê顔?闁挎稑顧€缁?
      // 閺夆晜鐟﹂悧閬嶅绩閹増宕抽悶娑栧劦濡法浜告潏銊︾畳濞存粌妫涘﹢锛勨偓鍦仩閹癸綁鎮欓惂鍝ョ濞撴艾顑呴々?1 闁?0闁挎稑顧€缁辨繃绋夐埀顒勬⒐濠婂啫鐓傞幖瀛樻礃婢х娀骞嬮幇顔惧綄闁?
      // 闁宠法濯寸粭?**濞戞挸绉烽崗姗€寮悩铏拫濞寸姾娉涢顔筋瀲?*闁挎稒淇虹€氥垹霉椤旇偐婀存慨婵撶到濠€?1闁挎稑鐗嗛妵鍥╀焊娓氣偓濞肩増鎷呭鍥╂瀭闁挎稑顦抽埀顒€鐭傞妴澶愭閵忕姴鍤掗悶姘煎亝婢ф粓骞愰崶銊ョ彌闁?0.05闁?
      //   闁哄啰濮靛顖涚鐠轰警鍤犲缁樺姃缁辨壆鎷嬮埡浣稿脯闂傚懎妫楅惇?*濞寸姴楠搁妵鍥╀焊娓氣偓濞间即鎯夐鍕紵閻犲搫鍟块崺灞炬交閾氬倻绋戦柡?* = 濞戞挴鍋撴繛鍡忊偓鍐茶閻熸瑤鑳跺▓鎴犳崉閸愭彃缍侀柕?
      if (this.expandState.morphOverlayProgress() <= 0.001 && closeFromT > 0.001) {
        this.expandState.syncMorphOverlayFromPage();
        PlaybackPage.ev('OVA', `align overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
          `to p=${closeFromT.toFixed(3)}`);
      }
      // 闁?闁稿繐鐗婃俊?閺夆晜绋戦崣鍡涘绩閹増宕抽柣鈺呮櫜缂?+ 闁告劘宕电划銊╁礄閻樿京绉?闁告艾鏈鐐哄礆瀹勬澘姣夐柛妯圭串缁辩増娼诲▎搴ｎ伇婵炲牆鐏氬Σ鍝ユ偘閵夆晜锛?*濞戞柨顑呮晶?*闁汇劌瀚伴·鍌涘緞閺嶏附鍙忛柡鈧惂鍝ョ
      //   闁圭顦悾濂稿棘绾拋娼愰柛鎺撶懃缁烩偓濡炪倛宕甸弫?`applySync` 闁告艾鏈鐐哄冀閸ヮ亜澹堥柨娑樿嫰閹線宕氬▎鎹ゅ姊婚幘顕呮禃閻㈩垎鍌滅獥闁活潿鍔嶅Λ顐﹀磹缁楄　鍋?
      UIUtils.applySync((): void => {
        // 闁?2026-10-17闁?*闁活潿鍔嶉崺?08:46 闁规惌浜滃ù姗€鏌屽畝鍕簼闁哄绱曢悡鏇㈡儎閸撗勭暠閻庤纰嶉埀顑懏鏆?*闁挎稑顧€缁?
        //   闂侇叏绲肩粩鏉戭嚕閻樿櫕锛夐煫鍥殕濡?`CLO:gen=1 p=1.00` 缂佹瘱鍕闁活偀鍋?`LV:anim from=0.00`
        //   闁炽儲鏌￠埀?濞戞挶鍊涢、鎴犳嫚閼姐倖鐣遍柡?*闁告艾濂旂粩瀛樼▔椤忓嫮鎽熸繛?* `morphP`闁挎稑濂旈懙鎴︽⒒?*婵炲备鍓濆﹢浣圭鐠佸磭绉块柛鎰懃閸?*
        //   闁挎稑娼塵orphP` 闁稿繈鍔嬬划銊╁矗椤忓懏绠?3 濞戞搩浜滈崯鎾诲礂閵壯冧化闁挎稒鐡猵ullOpenBegin` 闁汇劌瀚妵鎴犳嫻閵夛附鏆?/ `applyMorphProgress` /
        //     `morphReset`闁挎稑鐭傞崗妯荤▔瀹ュ懏韬?`closeFullScreenPlayback` 閺夆晜鐟﹀顖炴儎鐎电娈犲☉鎾愁煭缁辨岸濡?
        //   闁?闁告瑯浜滄晶鎸庣▔閵堝浂娼氶柛娆樺灥閸忔﹢鏁嶇仦鐣岀畱濡炪倛顔婄粩鏉戔枎闄囬浼村极閺夊灝鐎荤€殿喒鍋撻柨?
        //     闁?濞戞挶鍊涢、?*濞戞挸绉靛Σ鎼佸触鐏炶偐顏辨繛鍡忊偓鍐插綘闂?*闁挎稑鐗呯花銊︾閸撲胶澶勯柛鎰级濡叉悂妫冨▎鎰ㄥ亾娴ｇ儤鐣遍柕鍡曠劍鐎垫粎鈧稒顨堥浣烘啑娴ｇ鐎奸柨?
        //        闁荤偛妫滈鎴炵▔婵犲倸璁查柤瀹犲Г鐠愨晠宕楅妷銉ョ稐濞戞挴鍋撴繛鍡忊偓鍐插綘闂傚偆鍘惧▓?`LV`闁挎稑顦崳?闁?**`closeGen`** 闁瑰灚鎹佺换姗€寮堕妷銉ョギ闁告瑯鍨伴崹鐣屸偓?
        //        闁挎稑娼塁LO` 闂侇叏缍€椤㈡垿寮甸浣归檷閻忓繗椴稿﹢?`gen=`闁挎稑顧€缁?
        //     闁?`morphP` 闁活亞鍠撳▓鎴﹀捶閵娿劎绠瑰☉鎾卞€涢、鎴炵▕鐎ｎ喗锛熼悶姘煎亝閺佸吋绂?闁?`pNow=`闁?*婵縿鍊曢ˇ?*闂佹彃绉甸弻濠勬嫚鐠佸磭顏辨繛鍡忔缁辨碍绋?`from=`
        //        濞村吋鑹鹃幃鎾诲籍閺堜絻绀?0闁挎稑鐭侀埀?`CLO` 闂侇叏缍€椤㈡垿寮?1.00闁?
        PlaybackPage.ev('LV', `anim gen=${this.closeGen} from=${closeFromT.toFixed(2)} ` +
          `pNow=${this.expandState.morphP.toFixed(2)}`);
        this.expandState.morphBeginLeaving();
      });
      const closeScale: number = closeFromT < PlaybackPage.REVERSE_MIN_RATIO ?
        PlaybackPage.REVERSE_MIN_RATIO : closeFromT;
      const morphCloseMs: number = Math.round(PlaybackPage.REVERSE_MS * closeScale);
      // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`MorphGuard.animateMorph` 闁汇劌瀚鍥ㄧ▔閳ь剟宕ｉ妷顖滅闁挎稒淇洪幑锝囨偘閵夆晜锛熷☉鏂款儏婢х娀骞?闂佹澘绉锋竟濠勨偓鐟邦樀濞笺倗绮ｅΔ鈧ぐ?
      //   闁规亽鍔岄崺?*閺夆晜鐟﹀顖滄偘閵夆晜锛熺紓浣规尰濞?*闁挎稑娼塹uietMs` 閻忓繗椴稿Σ鍛婃交濞嗘劖钂嬮悶娑栧劦濡潡鎳涢鍕畳闁汇劌瀚鍌炴⒐?闁炽儲鏌￠埀?闁哄啰濮烽弲顐︽焽閿濆嫭娅犲☉鏃傚枑濡叉悂骞愭径搴ｆ闁活潿鍔庨崑锝嗗閻樺灚鐣遍柨?
      //   濞撴艾顑呴々?`closeSearchMorph` 濞?`SP_SEARCH_SETTLE_MS`闁挎稑鏈﹢鐗堝緞閸曨剛姊鹃柡鍫濐槷閹广垺鎷呴弴鐔哥厐闂侇偆濮撮悥鍫曟煂韫囥儳绀嗛柕?
      //   闁?闁稿繑濞婂Λ鎾礉閵娧勬毎閻犵儤鍨瑰鍐儍閸曨剚顦ч柛濠冪懕缁辨繈骞戦姀锛勬憙/闁告瑦鐗炴竟濠勨偓鐟版湰閸ㄦ岸鎯?濞戞挸锕ㄦ竟?濞戞挴鍋撶€垫澘顑呯欢姘跺触鎼淬垹鐨抽柨娑樺缁楀瀵煎顒佽含闁告柣鍔庨弫鐐▔椤撯懇鍋撻弮鍥╁劜闁肩懓鐪伴埀?
      this.expandState.markMorphQuiet(morphCloseMs);
      // 闁宠棄鎳夊Σ?婵炴惌鍠栭惇浼存焽閿濆嫮顏辨俊顐ｅ釜缁辨瑦绔熼崘鑼勾 `MorphCoverClone` 闁汇劌瀚悽缁橆槹閻愯尙娈遍梻鍫緛缁?*闊洤鎳橀妴蹇涙偨鏉堛劍鎷卞璺哄閹挸顫㈤妷鈹炬敵闁?* 闁炽儲鏌￠埀?
      //   濞撴碍绻冨畵浣烘喆?`PlayerExpandState.applyMorphProgress` 闂?闁告帞濮电敮鈧柤濂変簻婵晜寰勫鍕Т"闂侇叏绲鹃?+ 闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳鎯?
      //   闁靛棗濂旂粭鍛村箯婢跺﹤褰犻梻鍌ゅ幗濡炲倻浜告笟鈧浼村礉閵娧勬毎闁哄嫷鍨伴惈宥咁嚕閳ь剟鏌囬敐鍕伇濠靛倹銇滈埀顒€绉查埀顒€鐬奸柈瀵哥磼閻旇崵绠查柛銉у仜閸櫻囨⒒椤撶喓姊鹃柡鍫濐槸閻ㄦ繈妫冮姀鐘残楅柣銏＄湽閳ь剙绉查埀?
      //   闁宠法濯寸粭?闁告鍠愬鐢稿矗椤忓牊娴嗗鐟板暱閻?`@Monitor('expandState.morphStage')`闁挎稒鐡? 闁?`@Monitor` 闁?*鐎殿喖鍊归?*闁搞儳鍋犻惃鐔兼晬?
      //      闁兼澘鏈﹢浼村礄閼恒儲娈堕柣銊ュ閺佸湱浜搁幆褏鏆伴柡鍐硾濞呮帡鏁嶉崸鍒磑rphCloseMs + 20`闁挎稑顦甸崳閿嬪濮樺磭绠鹃柣顐熷亾閻?
      //      `morphLand()` 闁?`morphReset()`闁挎稑鐗嗛幃妤呮嚀?*闁告艾鏈?*闁?`morphOverlayP` 婵?0闁挎稑顦埀顒佹煛閳?
      //      闁告瑯浜ｉ々?`@Monitor` 闁汇劌瀚ú鏍嫬閸愨晛绗撻柛锔哄妼椤﹀弶鎷呭鍕吅闁告艾鍑界槐婵堜焊娓氣偓濞间即鏌囬敐鍕伇婵☆偅甯掑?*闁轰礁鐡ㄩ灞解柦閳╁啯灏?*闁?
      //      閺夆晜鐟╅崳鐑藉捶閵娿劍宕抽悶娑栧劦濡寧绋婄€ｎ亜顤?*闁告艾鏈?*闁哥姴锕ｇ粩瀛樼珶鐢喚绀夊銈呮惈缁厾浜搁崣妯肩憹闁告劕绉磋ぐ鍥礃閸忓懐鑹剧€甸偊鍠曢幑銏ゅ礉闄囬惃鐔告償閿旇　鍋?
      //   闁宠法濯寸粭?婵炴惌鍠栭惇浼存焽閿濆棙钂嬮悶娑栧劦濡?*鐎规瓕灏欑划锟犲捶閵娿劎鐛?*闁哄啯婀圭粭澶屾啺娴ｇ懓顫ラ柨娑樻綁overlayTweenAnimating()`闁挎稑顧€缁?
      //      濞戞挸锕ユ刊?闁搞儳鍋涢懘濠囨焽閿濆棙钂嬮柣銏犲船閿涙挾浠?`settlePullOpen` 闁告瑦鍨奸幑锝夋晬鐏炵偓鐓欓柛姘灣缁楀矂寮甸渚囧仹濞戞挴鍋撻柤鐤彧缁辨繈骞庨姀锝囩畺闁哄鍎辫ぐ褎瀵煎顓炩叺闁哄偆鍘奸悾鐘诲Υ?
      //      闁挎稑娼塮ocusMorphOverlayForPageCollapse` 闁告劕鎳橀崕瀛樻交濡粯绠掑☉鎾亾閻?闁哄牜鍓濋悿鍡涘矗椤忓浂鍟呴悹褑娓圭粩鏉戔枎?闁汇劌瀚粻鎾剁驳婢跺袘闁哄秴楠忕槐?
      //        闁搞儳濮崇拹鐔哥珶閸愯尙婀撮柣?`@Monitor` 濞戞梻鍠嶇槐鎵嫬閸愩劎鏆?闁炽儲鏌￠埀?閻熸瑤娴囬姘跺礄閼恒儲娈堕柣銊ュ閺佺偤鏌屾繛搴撳亾閸岋妇绀?
      this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
      Logger.info(PlaybackPage.logTag,
        `RzdMorph close tween from morphT=${closeFromT.toFixed(3)} 闁?${morphCloseMs}ms ` +
        `(=REVERSE_MS ${PlaybackPage.REVERSE_MS} 閼?max(REVERSE_MIN_RATIO ${PlaybackPage.REVERSE_MIN_RATIO}, morphT)) ` +
        `easing=REVERSE_EASING(0.85,0,0.5,0.88) overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
        `overlayAnimating=${this.expandState.overlayTweenAnimating()} ` +
        `coverClone=${this.expandState.morphOverlayBridging()} ` +
        `realCover=${this.expandState.realCoverVisible()}`);
      const gen: number = this.expandState.morphGen;
      this.getUIContext().animateTo({
        duration: morphCloseMs,
        curve: curves.cubicBezierCurve(0.85, 0, 0.5, 0.88)
      }, (): void => {
        // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁活潿鍔嶉崺娑氱箔?2闁? 闁?闁稿繑濞婂Λ鎾籍閻樻彃袟闁汇垺鐪归埀顑跨閻ㄦ繈妫冮姀銏＄函闁规亽鍎扮粭鍛村储?闁汇劌瀚悧鎾炊?*闁?
        //   濞?`playMorphOpenIntro` 闂侇叏绲肩粩瀛樺緞?*閻庣懓鑻崣蹇涘触鐏炶偐顏卞☉鎿冧邯閺佸﹦鎷?*闁挎稑鐗嗛幃鎾寸▔閳ь剝銇愰姀銏犘︾紒?2 濠㈣泛瀚哥槐姘舵晬?
        //   闁告鍠愬鐢稿及?`UIUtils.applySync(() => applyMorphProgress(0))` 闁炽儲鏌￠埀?闁?`animateTo` 闁汇劌瀚板Λ鎾礌閸涙潙娅?
        //   闁告艾鏈鐐哄礆闁垮鐓€闁烩晩鍠楅悥锝夊磹?闁?**閻炴稏鍎靛Λ璺ㄦ偖椤愩儳鍎查弶?* 闁?閻忓繋绶氬浼存儎鐎涙ê澶嶉柦鈧挊澶婄厒缂備礁鐗忛崑锝夋晬?闁烩晛鐡ㄧ敮瀛樼▔鐎ｎ亜绠靛ù?/ 闁烩晛鐡ㄧ敮鎾礆閺夎法姣堥柛锕€妫楅懜?闁挎稑顦埀?
        //   濞戞挸锕ラ悥鍫曞礂閹惰姤锛旈梺顓ㄧ导缁斿瓨绗熻缁辨獋animateMorphT(reverseMs, 0, REVERSE_EASING)`闁挎稑顦幃鎾诲冀瀹勬澘娑ч柛鎰懅濞蹭即寮介崶褉鍋撶粭琛″亾?
        //   闁宠法濯寸粭?閻犙囶棑閸嬶綁鏁嶉崼銏＄ゲ濞?+ 闁告劘宕电划銊╁礄閻樿京绉块柨娑橆樀閸嬪懏绋夐埀顒€鈻?*濞寸姴绉堕崝?*闁?`applySync`闁挎稑鐗愰～鍡涘嫉椤掆偓閸ら亶寮０浣虹憪闂傚牄鍨介崑鍛緞?:3729闁挎稑顦埀顒佹煛閳?
        //     闂侇叏绲惧Σ?閻炴稏鍎靛Λ鎸庣▕鐎ｎ亜顤?闁汇劌瀚婊呮兜椤旂偓鏆忔繛澶嬫穿缁?*濞戞挸绉烽々?*濞戞挴鍋撻悹褍鍢查崹褰掑箳婢跺牃鍋?
        // 閳藉應妲勯埥鍛 2026-10-17閿涘牅绗岄幍鎾崇磻闁絼绔存笟褍鎮撴稉鈧弶鈽呯窗**闂傤厼瀵橀柌灞藉涧閸?`morphP`**閿?
        //   `applyMorphProgress(0)` 娴兼矮绔村▎鈩冣偓褎濡搁崙鐘辩秿+濞插墽鏁撻柌蹇撳晸閹存劗绮撻悙?閳?閼冲本娅?`pullBgIn` 鐠ч攱澧滅亸?0
        //   閳?閸忔娊妫寸捄顖欑瑐"閸欘亜澧挎惔鏇為獓閼?閿涘本顒滈弰顖滄暏閹村嘲鐤勫ù瀣畱閵嗗苯鍙ч梻顓熸閼冲本娅欓崣姗€绮﹂妴宥冣偓?
        //   閻滄澘婀崣顏勫晸閻╊喗鐖ｉ崐纭风礉`@Monitor('morphP')` 闁劕鎶氶柌宥囩暬 閳?閼冲本娅欏▽?`pullBgIn` 楠炶櫕绮﹀ǎ鈥冲毉閵?
        this.expandState.morphP = 0;
      });
      this.closeSettleTimer = setTimeout((): void => {
        this.closeSettleTimer = -1;
        if (!this.isAlive) {
          // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁活潿鍔嶉崺娑氱箔?闁?闁哄鎵冲亾鐏炵偓绠掗柤鍐叉湰濞呮瑦鎷呴崱妯恍﹀Δ鍌浢€规娊鎮ч柅娑氱У闁靛棗绉跺▓鎴炲緞閺夋垵濞囬悗姘灱閺嬫帞浜搁崡鐐磋含閺夆晜鐟╅崳?*闁挎稑顦埀?
          //
          // ## 闁告鍠愬鍨交濞嗘挸娅￠柡?闁烩晛鐡ㄧ敮?return"闁挎稑濂旂划鍫熺▕閸喐鏆悘蹇涚畺閸忔ɑ绋夊鍛驳
          // ```ts
          //   if (!this.isAlive) { ev('SET','dead'); return; }   // 闁?闁哄唲鍐ㄦ櫢婵?
          // ```
          // 濞存粌瀛╁Σ鎼佸礄閻樿京绉?*婵ɑ鐡曠换娆撳磻濠婂啯韬悶娑栧劦濡法鎹勯幋婵嗙厒闁汇劌瀚伴崑鍛▔椤忓啰绉寸紓?*闁挎稒姘ㄥù澶嬫媴瀹ュ牏绠烽柡?`LEAVING`
          // 闁?`morphContainerActive()` 闁?闁?`morphClipping()` 闁?
          // 闁?閻庡湱鎳撳▍?`.height()` 闁告艾鍟板▓鎴﹀及?`morphClipHeight`闁挎稑鐗冩晶?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞挴鍋撳ù鐘虫灮缁辨繈宕欓悩鎻掔） vp闁?
          // 闁?**闁轰焦鎸抽妴澶愬矗椤忓棙鏆伴柛鎴濇惈缁躲垽鎯岄鐐暠濞戞挴鍋撻柡?*闁挎稑鐭侀埀顒€鐭侀崕妤呭疾椤栥倗绀刞MeshCoverBg`闁挎稑顦板Σ鍝モ偓鍦嚀濞呮帡鎯冮崟顐ゆ憤闁煎搫鍊婚崑?
          // 闁?閻忕偛绻嬬粭鍌滀焊鏉堛劍笑闁活潿鍔嶉崺娑氭嫚鐎靛憡鐣遍柕鍡楁湰濠€渚€鎳楃仦鐐彲濞达絽妫欏Σ鍛婎殗濡搫顔婇柣妤呪偓娑氱У闁靛棗绉查埀?
          //
          // ## 濞戞捁妗ㄧ划鍫熺▕?濡炪倗鏁诲鏉款潰鐠佸磭鍟?闁告瑥绉烽埀顒€鏈ú鍧楁閳ь剛鎲版担瑙勬毆閻?
          // 閺夆晜鐟ょ粩鎾绩椤栨粍鐣遍柛姘煎亗缁犵喖寮?闁衡偓鐠鸿櫣鍟查悗瑙勭濡炲倿宕抽妸鈺佹櫔闁哄鍎插鍌涖亜閻㈠憡妗ㄧ€规瓕灏欑划锟犲础濮濆本绁板ù?闁挎稑鐭侀埀?*闁告垹濮崇紞宥夊及椤栨艾褰欏ù婊庡亞濞?*
          // 闁挎稑娼塒layerExpandState` 闁圭鍊稿﹢?AppStorageV2 濞戞挸顭槐姘跺焽?濡炪倗鏁诲鏉库柦閳ヨ尙鍟婇柕鍡曠閸ゆ垶鎷呴弴锛勭婵繍浜炲鍐晬?
          // 濞戞挸顑勭粩鏉戔枎閳╁啫鈪电€殿喒鍋撻悘蹇氶哺濡插憡绂掓惔銈囩濞戞挴鍋撳ù鐘哄Г椤掞綁宕欓悩杈╃Э閻犙囨敱婢ф粓濡?
          //
          // 闁?濞戞挸绨肩粭鍛存閵忋倕浜濋柡?濞戞挻鐗旈崬顒勫矗闁垮锛嶉梺顐熷亾闁衡偓?**閻庨潧缍婄紞鍫ュ箣閹邦剚鍊卞☉鎾亾濞戞搩浜滈懜浼存偐?*闁挎稑鐗撻崑鍛村级閳╁啯鎷遍柡澶堝劚濮樸劑寮伴姘煎殸闁汇劌瀚哥槐姘舵晬?
          //   缂傚牐宕靛ù澶嬫媴?+ 闁告鐡曞ù鍥Υ閸屾顔忛柨?濞寸姴绉堕崝?*濞戞挸绉烽惃?`morphReset()`** 闁炽儲鏌￠埀?閺夆晜鐟╅崳宄扳柦閳╁啯绠掗柛娆樺灦濞碱剟鎯?
          //   "濡炪倗鏁诲鏉款啅閼碱剛鐥呭☉鎾愁儏瑜?闁告帇鍊栧畵渚€鏁嶅畝鍐ｅ亾?`morphReset()` 濞村吋鑹惧﹢顏呫亜閻㈠憡妗ㄩ弶鈺偯﹢顏嗕沪韫囧海鐟愰柡鍐煐婵″摜鈧湱鎳撳▍鎺撳緞瀹ュ嫮绉撮柟瀛樺姈瀵呬沪?
          //   闁挎稑鐗撻崑鍛焊鏉堛劍笑闁活潿鍔嶉崺娑氱箔?闁?闁哄妲勭槐姘跺Υ閸屾凹妲诲ù锝呯Ф濞堟垵顫㈤敐鍥ｂ偓姗€寮懜鍨皻閻?`scheduleMorphResetAfterPop()`闁?
          PlaybackPage.ev('SET', `dead闁愁偅澧禢D+POPT p=${this.expandState.morphP.toFixed(2)}`);
          this.isClosing = false;
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          return;
        }
        // 闁?P0-2闁挎稒纰嶅﹢鐗堟姜椤旂厧褰犻梻鍌ゅ幖閸戯紕鎮?濞戞挸顑勭粩鏉戔枎閳ュ啿褰犻梻鍌ゅ弨椤曨剙效?闁告瑦鐗旈崬?闁?闁衡偓鐠鸿櫣鍟插ù婧垮€楃划浼存焽閿濆嫮顏遍弶鐑嗗櫙缁辨繃娼诲▎鎾虫濞寸姭鍋撳☉鏂跨墦閸忔ɑ绋夊鍛驳
        if (closeGen !== this.closeGen) {
          PlaybackPage.ev('SET', `genWait`);
          return;
        }
        // 濞戞挸绨肩粭鍌涚▔閳ь剟寮?*闂侇喖鈧噥娲?*闁挎稒鐡猚loseGen` 闁?闂佹彃绉撮ˇ鏌ュ礂閹惰姤锛?闁挎稑鐣璵orphGenAlive` 闁?闁稿繑濞婂Λ鎾焻閺傛崘鍘柛娆忕墣椤妇浠﹂弴鐐电；"
        if (!this.expandState.morphGenAlive(gen)) {
          // 閺夆晜鐟ょ粩瀛樻姜椤旇姤鏆悹褍鍢查崙锛勭磼韫囨凹娼堕柡鍌涘濞堟垼銇愰姀鐘茬秮濞村吋淇洪惁浠嬪矗閺嶏箑鏁╅柨娑樼墔缁楁ɑ绂掗敐鍛▏闁告瑦眉缁繝鏁嶆径娑氱獥闁哄牜鍓濋悿鍡樻媴濠婂啰鐔柕?
          //
          // 闁宠棄鎳夊Σ?2026-10-15 閻炴稏鍎茬槐锟犳晬閸垺鏆忛柟鏉戝槻閻ゅ嫬霉鐎ｃ劉鍋?*婵炲备鍓濈涵鑸电▔鐎ｎ偄顎欓柛蹇斿▕濡挳骞橀鐔告澒闁?*闁?闁靛棗鑻崣褔姊婚鐔稿啊闁衡偓閹勭彜闁告垹濮崇粻顔尖柦閳ュ啿袟闁汇垺鐪归埀顒€绋勭槐姘舵晬?
          //   闁哄牜鍓濋悿鍡涙儍閸曨剚鏆悹褔鏀卞Λ锕傛倿閺堢數绋婇幖瀵稿櫐缁辨繄浜搁崡鐐电畱濡?*闁?`isClosing` 闁衡偓閻愵剙绔?*闁靛棗鍊搁悾鐘诲矗椤忓嫭韬☉鎾愁儔濞间即鏌囬敐鍡樿拫婵繐绲介悥鍫曞绩鐠鸿櫣鍟查梺鎻掔焷椤箑銆掗崪鍐
          //   闁兼澘鐭佺换鏍级閳╁啯锛嶉梺顐熷亾閻犱警鍨扮欢?*婵炲备鍓濆﹢浣圭鐠佸磭绉垮ù婊嗘〃缁变即宕樺鍡欘伕閻?* 闁?闁告せ鈧櫕韬?`true` 濞戞柨顑呴幃妤呮晬?
          //     鐠?`onDismissDrag()`闁挎稑鐗婂﹢浼村棘閸ワ附顐界紒?567 閻炴稑鐭夌槐姘辩箔椤戣法顏遍悶娑樿嫰濮?`if (this.isClosing) return;`
          //     鐠?`closeFullScreenPlayback()`闁挎稑鐗忛?1779 閻炴稑鐭夌槐姘跺触鐏炲墽澹夌紒妤婂厸缁斿鎮扮仦鑺ョ殤 return
          //   闁?**濞戞挸顑嗘刊娲绩閹増宕冲☉鎾抽閸櫻囨⒒椤撶喎鐦婚梺绛嬪枛瀵宕ｇ仦鐐攳濞戞柨鎳庨妵鎴﹀极?*闁挎稑鐭侀埀顒€濂旂粭鏍沪韫囧海鐟愭繛灞稿墲濠€浣圭鐠佸磭绉块柛鏂诲妿閺?
          //     闁挎稑鐗愰～鍥箛閻斿壊鍔€闁?闁稿繑濞婂Λ鎾箻椤撶喐鏉归柛锝冨妼閸ゆ垶绋婃惔銏㈡⒕闁告柣鍔庨弫?闁炽儲鏌￠埀?闁搞儳濮崇拹鐔煎礂閹惰姤锛?*闁哄秷顫夊﹢鏉库柦閳ヨ櫕鍎欓柛?*闁挎稑顦埀?
          //   闁告瑯浜濆﹢浣圭▔鐎ｎ偒鍋ч梺鎻掔У閺屽﹥娼诲☉娆愬啊闁衡偓妤ｅ啨鈧鏁嶉崼鐔哥厐閻庡湱鍋樼欢銉╂晬婢跺顤呭ù?闁煎浜滅换浣圭附閹存帞鍟?闁挎稑鏈晶宥嗙閵夈劎绠瑰☉?bug 鐎垫澘鐗嗛鎰板及閹捐娼剁憸鐗堟尰閸ㄦ岸宕戠捄鍝勭岛闁?
          //   闁宠法濯寸粭?濞戞挸锕?`closeGen !== this.closeGen` 闂侇叏绲惧?*濞戞挸绉烽崗?*閺夆晜鐟﹂悧鍗炪€掗崪鍐獥闂侇叏绲惧Σ?闁哄倿顣︾粩瀛樻姜椤旂厧褰犻梻鍌ゅ幖閸戯繝骞掗妷褜鍚€"闁?
          //      闁哄秴娲ょ换鏃囥亹閹烘浜濆☉鎾亾閺夌儐鍠氶鎼佹晬閸繄鏆婇悹褎婢橀崺灞炬交濞嗘挸娅￠柡鍐╂构缁变即鎳涢鍕畳婵炴挸鎷戠槐婵嬫煣閹呯闁煎浜濋崜銈夋晬婢跺牃鍋?
          Logger.warn(PlaybackPage.logTag,
            `RzdMorph close aborted by new morph session gen=${gen} ` +
            `liveGen=${this.expandState.morphGen} stage=${this.expandState.morphStage} ` +
            `闁?release isClosing + finish the close`);
          this.isClosing = false;
          // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*"闁绘劗鎳撻崵顕€宕楅幎鑺ワ紨 / 缂侇垵宕电划鐑樻交閺傛寧绀€"閺夆晜鐟ょ粩鎾级閿涘嫭鐣遍柡鍫氬亾闁告艾绨肩粩鎾锤?*闁挎稑顧€缁?
          //   濞戞挸锕浼存焽閿濆棙钂嬮柡鍐ｆ櫊閳ь兘鍋?*闁告瑯浜濋弬浣割嚕閳ь剚绂?`isClosing`闁挎稑鏈惀鍛村嫉婢跺鑵归弶?闁稿繑濞婂Λ?閺夆晜鐟ゅ▎銏＄鐎ｎ偅鎷遍棅?*
          //   闁?闁圭虎鍘介弬浣广亜閸忓摜绐?*婵ɑ鐡曠换娆撴偩濞嗗繑韬悘鐐茬箣缁?*闁挎稑鐗忛弫銈夊箣妞嬪骸浠柛蹇斿▕濡瓨绋婄€ｎ亝鍊甸悘鐐茬箣缁楀倹绂掗埀顒佺▕閸儱鍘存繛灞糕偓鍐茬岛闁汇垻鍣︾槐姘跺Υ?
          //   濞戞捁妗ㄧ划鍫熺▕閸綀娉查柛鎺撳缁绘牠鏌屽畝瀣獥闁衡偓閹増宕抽弶鈺佹川閳诲吋绋夐鈥愁仧 `morphGen` 閻?`morphReset()` 婵炴挸鎳撶换鍐╃▔閳ь剙鈻?
          //   闁挎稑鐗嗛崥鈧柛銊ヮ儐濞奸潧鈹冮幇鍓佺獥闁圭虎鍘介弬浣广亜娴ｅ啫娈伴棅顒夊亞濞?`onDisappear` / 閺夆晞娓圭紞姗€寮堕垾鍙夋珷闁告鐡曞ù?/ 濞戞挸锕ｇ粩瀛樻姜椤旂晫鏆欓柣锝嗙懄缁斿鎮堕崱顓犵闁?
          //   濞戞挻鐗旈崬顒勫矗瀹勭増鐨戝☉鎾冲濠€鐗堟姜椤旇棄绀嬮柤楣冾棑濞堟垶绋夊鍛€?闁炽儲鏌￠埀?闁?*閺夆晜鐟ラ懟鐔哥▔瀹ュ嫬鏁╅悶?闁活潿鍔嶉崺娑欑▔瀹ュ棗鍘掗柛蹇撳帠缁?**闁?
          //   闁?闁哄牜鍓濋悿鍡涘籍閵忋垹濮ч柡?閻熸洑绀侀崣?闁挎稑鑻銊╁箮婵犲倸褰犻梻鍌ゅ幗鐢綊宕氶弶璺ㄤ亢闁?
          //     闁?闁烩晛鐡ㄧ敮鎾媰閹存帞绉撮柨娑樻綁morphLand()`闁挎稑濂旂粭灞筋潰閿濆懐鍩楅柡鈧捄铏瑰暡闁告艾濂旂粩鏉戭潰閵夘垳绀嗛柨?
          //     闁?闁告鐡曞ù鍥箻椤撶喐鏉瑰銈囶暜缁辨獋isShowPlay=false`闁挎稑顦埀顒佹煛閳?
          //        闁烩晠鏅茬紞鍛▔鎼粹€虫濞达絾娲滃▓鎴濄€掗崨顖涘€為柣?*闁告鐡曞ù鍥煣閹规劕娈扮€规瓕浜▓?* `onDisappear 闁?morphReset()` 閻犳劗鍠曢惌妤呮晬?
          //        閺夆晜鐟╅崳?*濞戞挸绉归崳鍛婂緞瀹ュ牏娈?*闁挎稑鐗撻崳鍛婂緞瀹ュ牏娈跺ù鍏艰壘閸熲偓濠㈣埖纰嶇敮瑙勭▔閳ь剙鈻?`morphGen`闁挎稑鑻崺妤呮焻閻樿京鐟撳☉鎾亾閺夌儐鍠氬▓鎴﹀触瀹€鈧悮顐︽⒒椤曗偓椤ｄ粙鏁嶆径鍫氬亾?
          //   闁宠法濯寸粭?妤犵偛鍊婚悺?閻庣懓顦崣蹇涙晬濮濇sShowPlay` 闁兼眹鍎遍崙锟犲及?false闁挎稑鐣瑻Monitor` 濞戞挸绉崇槐浼存煂瀹ュ拋妲婚柛鏂诲妺缂嶆棃鏁?
          //      `morphLand()` 闁革负鍔戝顏囥亹閵忕姴缍侀柟顑跨劍濡插摜鈧懓顦崣蹇涙儍閸曨厸鏁勯柟鍨С缂嶆梻鎷犻婵堢枀闁挎稑鐗嗚ぐ褏绱欓懡銈嗙ゲ濞?+ 濞存嚎鍊涚换鏇㈠箥閳ь剟寮垫径瀣秬闁挎稑顦埀?
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          PlaybackPage.ev('SET', `genBAD闁愁偅澧禢D+POPT`);
          return;
        }
        PlaybackPage.ev('SET', `ok gen=${closeGen}`);
        this.isClosing = false;
        this.restorePlaybackWindowChrome();
        // LANDING闁挎稒纰嶉婵嬪礆缂佹ɑ灏￠柡鈧ィ鍐︹偓澶婎啅閼碱剛鐥呯紓鍌楁櫆閸ㄦ岸鏌呰箛鏃€顫栭柣銊ュ缁斿浜歌箛鎾村仴闁挎稑鏈俊鍛婃交閾氬倻绋戦柡澶嗏偓鍙夊攭閺夆晜顭囩划鎵偓?
        // 闁挎稑娼塵iniBarOpacity()` 闁革负鍔戝?ENTERING/LEAVING 闁哄啳鍩栨禍鑺ョ▔?1闁挎稑顧€缁辨繈宕樺鍛セ閺夌偛顫曢埀?
        this.expandState.morphLand();
        PlaybackPage.ev('LND');
        // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`squashLand`闁挎稑顧€缁?*闁解偓閹存帞绉撮梺顓ㄧ导缁斿鏁閹?闁圭虎鍘介弬渚€寮堕埄鍐ㄧ毃闁?闁?闁搞儳鍋涢懘?**闁?
        //   濡炪倕鎼花顓㈠椽鐏炵偓锟ラ柣锝呯焸閳ь剚鍔曢悺褎绋夐埀顒勬嚊鏉堝墽绐梎setMorph(LANDING)`闁?`morphLand()`闁挎稑鏈﹢鎵暜瑜庨幐閬嶅绩妤ｅ啨鈧宕戝鍛噳闁?
        //   閺夆晞娓圭紞姗€寮堕敍鍕焸闂婎剦鍋呭Ο澶愬礄閻戞ɑ闄嶉柨娑橆槴閸?`animateSquash(SQUASH_Y 0.86, 110ms)` 闁?320ms 閺夆晛娲ら崯鍧楀炊閻愯尪鍓ㄩ柕?
        //   闁?闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳鎯冮崟鈹惧亾鐏炵偓锟ラ柣锝呰嫰閸櫻囨⒒椤撶喐顦ч柟缁㈠幗閺備線寮堕垾鑼獥鐎殿噣鈧稓顏卞☉鎾愁儍閳ь剙绉村銊╁及椤栨繄绠瑰☉鎾亾閻庣數顢婅棢闂傚倹鐣埀?
        //   闁宠法濯寸粭?闊洤鎳橀妴蹇涘捶?`morphLand()` 濞戞柨顑呴幃妤呮晬濮橆厽锛嶅☉鎾亾閻㈩垎鍐╃殤闁?闁圭虎鍘介弬浣广亜娴ｅ啰绠烽柛锔哄妿閺侀箖濡存担瑙勮拫闁稿繐鐗嗛懘?闁?
        //   闁宠法濯寸粭?**2026-10-17 閻犱降鍨洪?*闁挎稒淇虹换鏍ㄧ▔閳ь剟宕ｉ妷銉ユ枾闁哄鍎茬敮鎾儓閳ь剟宕?濞?`morphReset()` 闁汇劌瀚伴妴搴㈡償韫囧海鐟濋柤瀹犳瀵?闁?
        //      闁绘粍婢樺﹢?`morphReset()` 鐎规瓕灏欑划?*濞戞挸绉村﹢顏呮交濞嗘挸娅?*濞存粌妫寸槐娆撳绩鐟欏嫬鐏?缂?pop 濞戞柨顑呴幃?闁?
        //      閻熸瑤妞掔粭鍛存閵忋倕浜濇繛鍫滅祷椤曗晠寮版惔婵堢憿 `scheduleMorphResetAfterPop()`闁挎稑顦埀顒佹煛閳?
        //      闁圭鍋撳ù鐘劚閻ｇ姵绋?`squashLandAnim()` 濞戞柨顑夊Λ鎸庣▔瀹ュ懎鏅欓柡鍫濐樀閵嗗孩鎯旇箛娑欙紪濡増菧閳?
        //      闁宠法濯寸粭?濞?`morphReset()` **濞寸姴绉堕崝褎绋夊鍥舵骄** `morphSquashY`闁挎稑鐗婄亸瀣储鐎ｎ偅笑闁绘瑯鍓涢悵娑㈡儍閸曨亞顏遍柡澶嗗墲閻栵綁鏌岃箛銉х闁?
        //      闁圭鍋撳ù鐘劦閸嬪懏绋夐埀顒€螞閹烘垶韬璺虹С缂嶅懏绋婄€ｎ亝鍊甸柣鎾楀嫮澹夊ù鍏肩婵?0.86 鐎殿喚鎳撳ú?1闁?*閺夆晜鐟﹀Σ鍝ユ啺娴ｇ儤鐣?*闁挎稑鐗婂Λ銈夋偩瀹€鈧▓鎴︽媰閹存帞绉撮柛銉у仜閼村﹪鏁嶆径鍫氬亾?
        this.expandState.squashLandAnim(this.getUIContext());
        PlaybackPage.ev('SQZ');
        this.state.isShowPlay = false;
        PlaybackPage.ev('POPT',
          `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
        // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁活潿鍔嶉崺娑氱箔?闁?闁哄鎵冲亾瀹€鈧悰濠囨倿閼稿灚闄嶅☉鎿冧簻閻秴顕ｉ埀顒勫箻椤撶喐鏉归柛锝冨妿濞堟垿宕濋妸褎鏆伴柕鍡楃Ф濞堟垿寮甸崫鍕厬缂佺嫏鍌涘弿婵?*闁挎稑顦埀?
        //
        // ## 闁告鍠愬鍨交濞嗘挸娅￠柡?闁告艾濂旂粩?tick 闂佹彃鑻幃鎾愁潰?morphReset()"闁挎稑濂旂拹鐔哥閳ь剚绋婇崼銉ヤ簼闁哄嫷鍨堕弫濠囨儍?
        // ```ts
        //   this.state.isShowPlay = false;   // 闁?濠㈢懓鍟块惇?@Monitor闁挎稑婀? 鐎殿喖鍊归鐐烘晬婢跺棗鏅?popPlayerRoute()
        //   this.expandState.morphReset();   // 闁?闁告艾鏈鐐烘晬瀹€鈧幓锝囨崉閻斿嘲寰撻柛?
        // ```
        // `morphReset()` 濞村吋纰嶆俊?`morphStage` 婵炴挸鎳忛崹?`NONE`闁靛棔姊梞orphP` 濠㈣泛绉崇紞鍛村箣?1闁?
        // `morphClipHeight` 婵炴挸鎳樺ù鍌炲Υ娑旑柍orphScale` 濠㈣泛绉崇紞鍛村箣?1
        // 闁?`morphContainerActive()` 缂傚牐顕ф禍?闁?閻庡湱鎳撳▍?*濞戞挸绉烽ˉ鍡涘礈椤忓倵鍋撴担椋庣憹缂傚倵鏅滈弬渚€濡存担椋庣憹濞达絽绉朵簺** = **婵犲ň鈧磭娼岄柟缁㈠幗閺備焦銇?*闁?
        // 闁兼澘鐭侀惌楣冩偨鏉堫偒娲ｉ柛?*濞戞挸顑勭粩瀵告暜?*闁归潧绉烽～?`pop(false)` 闁硅姤蓱鐢偓闁挎稑娼堾Monitor` 婵炲弶鍎宠ぐ鍌涚▔閳ь剛浠?+ 閻㈩垰鍟惇顒勫箺濮椻偓濞呭孩绋夐埀顒備沪閸岋妇绀?
        // 闁?濞戞搩鍙冨Λ鍧楁焽?1~2 閻㈩垎鍐綄濞戞挸锕ゅ銊╁及椤栥倗绐?
        // ```
        //   鐎规瓕灏欑划锛勭磽閳哄倸鐏囬悘蹇撶箰濞撻箖鎮欓惂鍝ョLANDING闁挎稑鐭侀～锔炬啑娴ｅ憡韬弶鈺勬腹缂嶆﹢寮堕敓鐘蹭簼濞戞柨鐗撻悵顕€鏁?闁?缂佹劒鑳堕崝褍顭ㄩ垾宕囨綄闁圭虎鍘介弬浣广亜?闁?婵炴垵鐗嗛妵?
        // ```
        // 閻熸瑥鍊归崝鍛潰閿濆棙笑闁活潿鍔嶉崺娑氭嫚鐎靛憡鐣遍柕鍡楄嫰婵晠鎮介懡銈囨尝闁哄鍠嶇花?*缂佹劒鑳堕崝褔寮堕妷銈夊殝閻忕偞娲栫槐鎴﹀箻椤撶喐鏉归柛锝冨妿濞堟垿宕濋妸褎鏆?*闁靛棗绉查埀?
        //
        // ## 濞ｅ浂鍠楃涵鍫曟晬?*缂佹稑顦甸妴澶愭閵忋垺鍩傞柣銊ュ缁楀懘宕ｉ弶鍨櫃濠㈣泛绉崇紞鍛村礄閻樿京绉?*
        // 闁解偓閹存帞绉撮柨娑樻綁morphLand()`闁挎稑顦崙锛勭磼韫囨柨惟缂備焦锚閸╂寮堕崘褎鍞夐弶鈺傤焽缁増娼婚摎鍌滅☉闁哄鈧尙鍟婇柨娑樼焸閸嬪懏绋夐埀顒佺?閻炴凹鍋夐ˉ鍡涘捶閵娿劎纰冨ù锝囧У濞碱垶鏌囬敐鍕杽濡?闁?
        // 闁告垹濮崇紞?*闁革负鍔戦妴澶愭椤厾鐟撻柛娆擃暒缁狅綁宕滃鍡樞﹂悗鐟拌嫰閸欏繐顫㈤敐鍥ｂ偓姗€鎯冮崟顒佲枖缂佲偓閾忕懓笑闁?*闁挎稑鐗忛弫銈夊箣妞嬪孩绠欓柛鎺撳濞堟垹浜告潏銊π﹂弶鈺勬腹缂嶆﹢寮堕埥鍛闁炽儲鏌￠埀?
        // 闁圭鍋撳ù鐘劚椤﹀弶鎷?*婵炲备鍓濆﹢浣圭鐠佸磭绉块柣鐐叉閺?*闁硅翰鍨瑰﹢?pop 闁告挸绉瑰浼村磻濮樸儮鍋?
        // 闁宠法濯寸粭?濞达絽妫旂弧鍐╃▔瀹ュ牆鍘村☉鎾崇Т娴犳盯鏁嶅顒€娈ゅù锝嗘礃濡叉悂宕楅崣姗€鐓╅柣銊ュ缁辨繃绋夊鍜佹Щ濞达絽绉崇槐鏉啃ч埄鍐帬濞戞挸顑勭粩瀛樻姜椤曞棛绀勯悷?`morphGenAlive` 闂侇叏缍佹禍楣冩⒒椤帞绀嗛柕?
        // 闁?濞存嚎鍊楃划?`scheduleMorphResetAfterPop()`闁?*閺夌儐鍠涢妤呭礆?闁圭虎鍘介弬浣广亜娴ｅ啰鐔呴柣銏犲船閸戯紕绱掕箛搴ｇ憹闁革负鍔嶉悥銈夋煂?闁归潧绉撮ˇ鍙夋媴?*闁?
        //   妤犵偠娉涢悽?闁哄倿顣︾粩瀛樻姜椤旇崵绐楅悹鍥ㄧ箓閸戯繝骞掗妷褜鍚€閻忓繐褰夌粭澶屾媼閸涘﹦顏?闁汇劌瀚鑽も偓鐟扮墕瀹曞ジ濡?
        this.scheduleMorphResetAfterPop(closeGen, this.expandState.morphGen, 0);
      }, morphCloseMs + 20);
      return;
    }
    // 婵炲备鍓濆﹢渚€宕ｉ鐐存祮闁告垹濮崇紞宥夊籍閸撲焦绾柟鎭掑劚閸櫻囨⒒椤撱劎绀夌紓浣圭箑缁楀宕堕悙琛″亾閳ь剟宕氶弶鍨闁瑰吀绀侀崬瀵糕偓鍦嚀閻即鎯冮崟顒侊紜閺夌儐鍓欏┃鈧柕?
    Logger.warn(PlaybackPage.logTag, 'collapse without geometry: immediate landing');
    PlaybackPage.ev('CLO', 'noGeom');
    this.isClosing = false;
    this.restorePlaybackWindowChrome();
    this.state.isShowPlay = false;
    PlaybackPage.ev('POPT', 'noGeom');
    // 闁?闁?婵繐绲介悥鍫曞绩鐠鸿櫣鍟查柡鈧?闁挎稒鑹鹃ˇ鍙夋媴瀹ュ懎娈ゅù锝嗘礀缁烩偓濡?*缂佹稑顦甸妴澶愭閵忋垺鍩傞柣銊ュ缁楀懘宕?*闁挎稑鐗愰～?`scheduleMorphResetAfterPop`闁挎稑顦埀?
    this.scheduleMorphResetAfterPop(this.closeGen, this.expandState.morphGen, 0);
    // 闁稿繑绮岀花宕囨崉椤栨氨绐炲☉鏃傚枙椤╋箑顕ｉ柅娑氼伇濞戞挸顑戠槐浼村触閿曗偓閸?闁告垹濮崇紞宥呪柦閿熺姴娅ら柛?闁哄啯鍎肩换鏍级閳ヨ櫕鏆滃☉鎾亾闁汇劌瀚弫鍦導瀹勬澘鍐€濡絽鐗嗗銊╁极缂堢娀鍤嬫繛灞稿墲濠€?
    this.expandState.squashLandAnim(this.getUIContext());
  }

  /** 濞戞挸锕ラ?`logBranchSurface()` 闁瑰灚鎹佺换鍐儍閸曨収鍔柛姘▌缁辨瑩鎮介妸锔介檷闁硅泛锕崳鍛婂緞瀹ュ娅㈢紓浣姑敮鍥箣閹邦亞顏遍柡澶嗘缁辫京鎲存担绛嬪殙闁哄倽顫夌涵璺衡枖閵娾晛娅為柨娑橆槶閳?*/
  private lastBranchLog: string = '';

  /**
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忓ú浼村冀?闁?闁?*闁告帒妫欓弫顔裤亹閹烘垹娼ｉ悹鍥э攻閺?+ 闁绘鐗撳鐗堢▔瀹ュ懎缍侀梺鎻掔箺閸ゆ粌螞閳?*闁挎稑顧€缁变即骞?闁绘粍婢樺﹢顏堝礆閺夎法淇洪悹褎澹嗗▓鎴﹀传椤忓啰顏遍柡澶嗏偓鍐茬€婚柡鈧?+
   * 闂侇叏绲肩粩鎾绩椤栨粍鐣遍悗鍦仦缁佹挳宕欓悩杈╃Э + **濞戞挸绉磋ぐ澶愭煂韫囨梹笑闁告熬闄勯崹姘辩博?*"闁瑰灚鎸搁崵顓㈠级閵夛絺鍋?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸儲浠橀悷鏇氱閻?
   *
   * 闁哄牜鍓熼妴澶愭儍閸曨偆顏撮悘鐐╁亾闁?*濞戞挸顦板顖炲礆閸℃ɑ鏆?*闁挎稑娼塨uildControlStack()`闁挎稑顧€缁?
   * ```
   *   panel闁挎稑鐗撳浼村级閸栵紕绀? 闁?usePanelLayout()
   *   wide闁挎稑鐗嗛鏃備沪?妤犵偠娅曞姗€鏁嶆径鍡楁櫍 闂?SM 濞戞挻妫冨顏堟晬閸︻搳 + HEIGHT_SM闁?
   *   phone闁挎稑鐗婃晶婊堝嫉閻氬绀? 闁?闁稿繑婀圭紞?
   * ```
   * 闁?*闁告瑯浜濆﹢渚€骞嶇€ｎ偅绨氱憸鑸灪閳ь兛绀佸﹢顏堝嫉椤掍焦绨氶柛娆樺灡閻庮垶鏌?* 闁?閻庣妫勯惈?妤犵偠娅曞?婵☆垼浜滈惈?PC 闂侇叏绲肩悮閬嶅级?*濞寸姴瀛╁闈涒柦闄囬～锔筋殽瀹€鍐畺**闁?
   * 缂佹稑顦扮€ｄ線宕氭导鏉戜簼濞存粍绋戦懜浼村箑娴ｈ顦ч柨娑樼灱椤戝洦绋夐埀顒佺閹偊娲ｉ柣顓滃劦娴滈箖鎯冮崟顏嗙殤闁?**閻庣懓鍟崺灞炬償閺嚶ゆ巢濞存粌妫楅幗銏＄▔閳ь剟寮?*"闁炽儲鏌￠埀?
   * 闁搞儳濮崇拹鐔哥▔婢跺钂嬮柛鎺戞閺侇噣鎯?*閻忓繋绶氬鏉裤€掗崣澶屽帬闁兼澘鎳嶇粭澶愬触?*闁挎稑娼穐one = 閻熸洖妫涘ú濠勪沪?`LyricFloatLayer`闁挎稒纭de/panel = `MusicPlayInfoBlock`闁挎稑顧€缁?
   * 濞戞挴鍋撻柡鍐跨畱閸ㄥ酣寮ㄩ姘伈闁硅鍠曠粭灞撅紣閸曨剚鍩傚☉鎾崇Ф椤戜線鏁嶅畝鈧Λ渚€鎮╅張鐢电獥閻炴稏鍔庨獮鍥ㄧ▔?閻忓繋绶氬鐗堟媴瀹ュ洨鏋傜€垫澘鐗嗛〃宀勫箑?闁挎稑鐭侀埀顒€鏈悧鎾炊閻樻彃寰撻悗鍦仦濡?閻犙傚嵆閺佸﹥绂嶉崱妯绘殰"闁?
   *
   * ## 濞戞挸绉磋ぐ澶愭煂韫囨艾娈版俊顐熷亾闁挎稑娼塱nv=` 闂侇叏绲肩粩鎾礆濡ゅ绀嗛柍銉︽煛閳?闁?闁活亜顑囧鍐╃▔瀹ュ拋鍤?闁告瑦蓱閸?闁哄啨鍎辩换鏃堟儎鐎涙ê澶嶉悹鍥╃節缁楀骞嬮幇顔惧綄"
   *
   * | 闁哄秴娲╅?| 闁哄偆鍙€閳?| 濞戞挸绉甸崹姘辩博鐎ｎ収鍤涢柡鍕凹缁牊绋?|
   * | --- | --- | --- |
   * | `coverNone` | 閻忓繋绶氬浼存嚍閸屾粌浠梺鎻掔箰缁堕亶宕?| 闂侇叏绲肩粩鎾绩椤栨稓姊鹃柟?`PLAYER_BIG_COVER_ID` 闁圭鍊风粭?闁?閻庣妫勭€?缂佹棏鍨抽崑锝夋煣閸欍儳绐楅梺顐熷亾闁?|
   * | `coverSquare` | 閻忓繋绶氬鎵偓閫涚矙閻濐喖顔?闁?1vp | 閻忓繋绶氬鎵偖椤愩垹绔鹃柟鍏哥筏缁辨獋constraintSize` / `layoutWeight` 闁归婢€缁紕绮氬ú顏咃紵闁挎稑顦崳?缂備緡鍙冮ˉ锝囦焊娓氣偓濞间即鎷冮幋鎺旂Т濞村吋淇洪悜?|
   * | `metaGapOk` | 婵繂鑻幃鏇熴亜閹壆鐝?闁?閻忓繋绶氬鐗堟償閺囷紕鐝?闁?1vp闁挎稑鐗呯粭澶愭煂瀹ュ懎缍岄柨?| **婵繂鑻幃鏇㈠储鐎ｎ亝韬鍫嗗啰娈遍梻鍫線缁?* 闁?闁活潿鍔嶉崺娑㈠箮閵壯勭暠"闂佹寧鐟ょ紞?闁汇劌瀚粩瀵哥矓?|
   * | `metaOrder` | 婵繂鏈晶婊勩亜閹壆鐝?闁?婵繂鑻幃鏇熴亜閹壆鐝堕柨娑樼墛閻℃洟骞嶇€ｎ亝韬慨婵嗚嫰閹?*濞戞挸顑夊?*闁?| 濞戞挶鍊涢、鎴炪亜閸濆嫮纰嶉柛娆忕С缁?|
   * | `metaInWin` | 婵繂鑻幃?婵繂鏈晶婊勬償閺囷紕鐝?闁?缂佹劖顨呰ぐ娑欘殗?| 婵繂鑻幃鏇犳偖椤愶絽鐨ㄩ柛鎴濇惈閻棝鐛弴顏嗙闁告ê妫楄ぐ鑸电▔?闁稿绻嬬紞?164vp"闂侇叏绲奸柌?bug 闁汇劌瀚懜浼存偐鐠佸湱绀?|
   * | `miniClear` | 閻忓繐绻戦悺鏇犳嫚瀹ュ鈧﹥娼?闁?婵繂鏈晶婊勬償閺囷紕鐝堕柨?*閻忓繐绻戦悺鏇犳嫚瀹ュ嫮鐟濆☉鎾冲閻℃洟宕ュ澶婃闁?*闁?| 闁?閺夆晜鐟﹂婊堝及椤栨粍鏆忛柟鎾敱婵倝鎯冮崟鈹惧亾鐏炵偓灏￠柡鈧崜褎娅曢梻鍫涘灲閺佸﹥鎷呭鍐ｅ亾瀹ュ繒绀勯幖?7 闁?`MINI_LYRIC_SINK_VP=44` 濞ｅ浂鍠氬▓鎴︽晬?|
   * | `branchSane` | 闁告艾濂旂粩瀵镐沪?*闁告瑯浜濆﹢浣圭▔閳ь剟寮?*闁挎稑娼塽sePanel` 濞?`phoneSwiper` 濞戞挸绉撮幃鎾诲籍閼搁潧惟闁告艾濂旂粩鎾锤濡も偓閸炲鈧顫夋晶顓熺濡偐鑸跺☉鎾卞€楅～鎺旂磼閹惧鈧垶鏁?| 闁告帇鍊栧畵渚€鏌屽鍛秾闁告牠缂氶～锕傜叒閳轰礁鐓?闁?闁稿繐鐗呴幈銊╁礆閵堝棗绁﹂柛鎰Х閻ㄣ儳鏁崘銊ф拱 |
   *
   * ## 閻庣懓鍟╃划鐘诲传椤忓嫬濮介悶姘煎亯閻ㄧ喖鏁嶉崼姘潐 閺夆晜鐟ょ粩鏉戔枔閸偅鎷遍棅顒夊亝濡插憡绋夐鍕澖婵炴潙顑囩划銊ф媼閻氬绀?
   *
   * 闁宠法濯寸粭?**濞戞挸绉烽崗姗€鎯勭€涙ê澶嶉柛鎰懃濠€?`@Builder` 濞达絾鎹囬崳?* 闁炽儲鏌￠埀?闁哄牜鍓濋悿鍡欌偓鍦仦缁佸绱撻弽顒傛Н闁硅翰鍎甸弫濠囨晬?
   *   `'this.logBranchSurface('wide')' does not meet UI component syntax`
   *   闁挎稑婀弐kTS 闁?`@Builder` 濞达絾鎸歌ぐ褔骞掗妷銉ョ秬 **UI 缂備礁瀚▎銏㈡嫚椤撶喓銆?*闁挎稑顦埀?
   * 闁?闁绘粍婢樺﹢顏堝箰閸屾碍韬?*濞戞挸顦板顖炲礆閸℃ɑ鏆滈柛姘閸ゆ粓鎯冮崟顒傚閻庡湱鎳撳▍?*闁?`.onAppear()` 濞?闁炽儲鏌￠埀?闂侇叏绲肩粩鎾绩?*濡絾鐗楅濂稿箰閸屾繃绁?*闁哄啯鍎艰闁告瑦鍨崇粩鏉戔枎閳藉懐绀?
   *   闁归潧顑嗗┃鈧柍顐ｆ煥椤旀梻浠﹁箛濠傛櫖闂傚牄鍨哄妯荤閹烘梹绁查柛鎺戞处瀹曟煡寮捄鐑樺€楅柡澶堝劙缁旀潙鈻庨埥鍛鐟滆埇鍨硅ぐ澶愬嫉閻斿吋锛熷☉鎾崇С缁辨壆鎲撮敃鈧ぐ鍌炴晬婢跺牃鍋?
   *   闁烩晩鍠栨晶鐘诲箰閸屾瑧鍟婂☉鎾愁槸椤︹晠鏁嶅顒夊晬閻忕偛绻橀崑鍛村绩椤栨粍鐣?`Column`闁靛棔鐒︽晶婊堝嫉濞差亜浜濋柡鈧婊勭暠 `Swiper`闁靛棔绶氬浼村级閸ф浜濋柡鈧婊勭暠闁?`Stack`闁?
   *   `branch` 闁告瑥鍊归弳鐔兼偨?*闁告艾瀚惃鐔兼偨閵娧冧化闁煎浜滅换浣圭珶閻楀牊顫?*闁挎稑鐗嗛悾鐘碘偓娑欘殜濞肩増绋夋繝鍌涚殤闁活厹鍎垫禍楣冩嚊椤忓嫮绠掗柡鍕靛灥閻ㄦ繈鏁嶆径鍫氬亾?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸繂璁插ù鐘劤濞插潡骞掗妷銉ユ櫢闁?`@Builder` 闂?
   *
   * 闁挎稑鐗婇婵嬪级閳ュ啿鍤掑ù锝嗙矊缁?闁炽儲鏌￠埀?閻熸瑤妞掔粭鍌炲Υ娣囨Builder` 濞达絾鎸歌ぐ褔骞掗妷銉ョ秬 UI 缂備礁瀚▎銏㈡嫚椤撶喓銆婇柨娑樻湰婢у秵绂掗妷锕€鐦柛?`.onAppear()`闁靛棗鍋婄槐?
   *
   * 闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdBranch'`
   * 闁宠法濯寸粭?闁告瑯浜ｉ浼存晬濮橆偆鐟濋柛鎰懁閹广垺鎷呴弴鐘残﹂柟顑跨筏缁辨獋lastBranchLog` 闁告瑯浜濆Σ鎼佸籍閵夈儳绠堕柤鍝勫€圭粊锕傛偨閵娧勭暠閻庢稒顨堥浣圭▔鐠囇呯闁?
   * @param branch 鐟滅増鎸告晶鐘诲礆閸℃ɑ鏆滈柛姘▌缁?phone' / 'wide' / 'panel'闁?
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
    // 闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?濞戞挸绉磋ぐ澶愭煂韫囨艾娈版俊顐熷亾闁挎稑鐗嗛崣蹇涙焾閵婏附笑"濞戞挸绉甸崹姘辩博鐎ｎ偄顤呴悹鍥╊棎閻?闁汇劌瀚懜鏉款嚕韫囥儳绀夐梺顒€鐏濋崢銈夊籍閵夈儳绠堕梺鎻掑缁旀挳宕?true闁?闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋撻柍鍏夊亾闁冲厜鍋?
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
    // 闁?閺夆晜鐟﹀顖滀焊鏉堛劍笑闁活潿鍔嶉崺娑㈠箮閵壯勭暠闁靛棗鏈幐閬嶅绩閸撗勬珪闂傚牄鍨介弫濠冩媴瀹ュ啠鍋撳鍥ㄧ暠闁哄牆鎼▍鎺楀礆閵堝棗绁﹂柨娑樼叒?7 闁?MINI_LYRIC_SINK_VP 濞ｅ浂鍠氬▓鎴︽焽閿濆棙钂嬮柨娑橆槶閳?
    if (lyric !== undefined && singer !== undefined && lyric.y < singer.y + singer.height - 1) {
      bad.push(`miniClear(lyric.y=${lyric.y.toFixed(0)}<singer.b=${(singer.y + singer.height).toFixed(0)})`);
    }
    // 闁告帇鍊栧畵渚€鏌屽鍛秾闁告牜灏ㄧ槐鐧旸 + 婵☆垼浜滈惈鍡涘籍?usePanelLayout() 濞?usesPhoneSwiperLayout() 闁告瑯鍨甸崗姗€宕ョ仦鐐槯濞戞捁娅ｅ﹢锟犲Υ?
    // 闁绘粍婢樺﹢顏堟?`if` 濡炪倕鎼花顓㈠礂濠娾偓缂嶅洭鏁嶉崼銉︽〃闁哄鍎婚崕銊╁礄閻氬绀嗛柍?闁告瑯浜ｉ々?闂傚牄鍨哄姗€寮ㄩ鐐叉閺夆晜顭堥缁樼▔妤﹀灝娈扮€规瓕椴稿Σ?phoneSwiper"闁挎稑鑻銊╁及椤栫偞顓洪柟顕嗙祷閳?
    const panel: boolean = this.usePanelLayout();
    const phoneSwiper: boolean = this.usesPhoneSwiperLayout();
    if (panel && phoneSwiper && branch !== 'phone') {
      bad.push('branchSane(panel闁愁叏绠瞙oneSwiper both true)');
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
      // 闁宠法濯寸粭?缂佸瞼鍎ら弳鐔虹磼閸曨噮娲ｉ柟鍨尰閸?`ok`闁挎稑濂旂粭澶愭嚄閼恒儱鈪电紒宀冩〃鐟?闁炽儲鏌￠埀?闁告熬绠戦崹?闁哄啨鍎辩换鏃堟煂瀹€鍕簼濞戞挴鍋撴繛鍫濈仛閻ュ懏绂?闁?婵炲眲銈呮婵☆偀鍋?闁告帒妫旂粭澶娿€掗崨顐熷亾?
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
   * @returns 闁哄嫷鍨伴幆浣烘導閼割兘鍋撶仦鎯ь杹闁?Swiper闁靛棗绉归崑鍛▔閳ь剟寮ㄩ姘鳖伌閻忕偐鍋撻柨娑樼墕閻ㄦ繈妫冮姀銈冣偓?/ 婵繂鐭侀惁婵囥亜?*婵☆垼浜滈幃婊堝礆閸ャ劌搴?*闁汇劌瀚伴崑鍛附濡ゅ绀嗛柕?
   *
   * 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛鍥ㄧ▕濠靛﹦鏋傜捄?*闁衡偓鐟欏嫷鍔€濞戞挴鍋撳?婵炲鍔戦崳瀛樼▔鎼达紕鏉介柣婊堫暒缁楀绮?**闁挎稑顧€缁?
   *   闁告鍠愰弫鐐烘煂婵犲倸鏅搁柣銊ュ濡叉悂濡寸仦钘夌伈闁硅鍠曠粭?`buildControlStack()` 闂佹彃鐭傞崑鍛▔?`if` 闁汇劌瀚ぐ鍥矗?*闂侇偅鍔曢悺褎绋夐埀顒勬嚊?*闁?
   *   `SM`闁挎稑鐗呯粭澶屾媼濞差亞褰柨娑橆槹閸?**`MD + HEIGHT_SM`**闁靛棗绉埀顒佹煛閳?
   *   闁宠法濯寸粭?**閻庡湱鍋熼獮鍥煂鐏炵瓔鍤?MD 妤犵偠鍩栭惀鍛村嫉婢舵劗褰幖杈鹃檮濞碱垱绂?*闁挎稑鐗嗗銊╁及?`widthBp === WIDTH_MD` 闁哄牜鍓濋棅鈺呮晬婢跺牃鍋撻崒娆掆拡闁告瑣鍎扮粭澶嬬▔閳ь剟鎳涙潏鍓х
   *   闁兼澘濂旂粭?*濞戞挸绉崇粩鎾嚊鐎靛憡鐣遍梺顓ㄧ导闁叉粓寮悷鐗堝€婚柡?閻庡湱鍋熼獮鍥即閺夋埈鍟?**闁挎稑婀 + 濞寸姷绮崜鐗堫殗濡搫顔婇梺顔尖偓鐔虹闁?true闁挎稑顦埀?
   *
   *   闁绘粍婢樺﹢顏堟儍閸曨偆鏉介梻鍕嚀椤曘垺绋婃径娑氱闁绘挆鍐澖闁绘粍婢橀崯鎾绘晬?*闁哄牜浜濋弫鑲╂偘鐏炶壈绀?*闁挎稑顧€缁?
   * ```
   *   widthBp === SM                      闁?true
   *   widthBp === MD                      闁?true      闁?闁宠法濯寸粭?濞戞挸绉撮幆鍫燁殗濡搫顔婇柛鎺嬪€栭弻?
   *   闁稿繑婀圭紞鎴︽晬閸︾嚌 / XL闁?                     闁?false
   * ```
   *   闁?閻庣懓鍟惁?`buildControlStack()` 闂侇叏绲惧?`if` 闁汇劌瀚ぐ鍥矗?*濠㈣埖鑹鹃幊鈩冪▔?MD + 闂?HEIGHT_SM"**閺夆晜鐟ょ粩鏉戭浖閿濆啠鍋?
   *
   * ## 闁?濞?`usePanelLayout()` 闁?*闂佹彃绉磋ぐ鏃堝礌?*闁挎稑鐗嗛崙锟犳儌閺勫浚鍞堕柨娑樿嫰閸╁棝宕烽妸銊х闂佹彃鑻导鏃堝磻闁垮鏆柨?
   *
   * ```
   *   usePanelLayout() 闁?(婵☆垼浜滈惈?&& widthBp !== SM) 闁哄啯婀圭拹鐔兼儑?
   *   闁?闂佹彃绉磋ぐ?= 闁靛棙鍔栭搯閻忕偛绻堥埀顒佸灟閳ь剚浼刬dthBp === MD闁?
   * ```
   * 濠靛倽妫勯ˇ鈺呭及?`buildControlStack()` 闂?`if (usePanelLayout())` **闁革负鍔屾晶?* 闁?闂傚牄鍨哄姗€寮ㄩ婵嗗姀闁告垶浜介埀?
   * 閻熸洖妫涘ú濠勪沪閸屾繍娼堕柡鍫墮閸ら亶寮悧鍫濈殹闁?闁?**濞戞挸绉崇槐浼存偨鐠佸疇鈷堝ù鐘烘閻ㄦ繈妫?*闁?
   * 闁秆冪箰椤︹晠寮伴婵堢閻忕偟鍋樼花?**闂?if 濡炪倕鎼花顓㈠礂濠娾偓缂?*"闁挎稑濂旂粭澶愬及?闁告帇鍊栧畵浣圭閹烘挻鐏?闁?
   * 闁宠法濯寸粭?**闁哄牜鍓欓崵閬嶅极閹峰瞼绠风紒鐙呯磿濞?`isPhoneLyricsStyleBackdropLayout()`闁挎稑鐗愰崕妤呭疾椤栨稓澹夌€殿喖绻橀幗濂告晬?* 闁?
   *   闁硅泛锕ら悾鐘诲绩閸撲胶宕曢柟?`&& !usePanelLayout()` 闁?*闁告瑯鍨甸～鍡欐偘鐏炶壈绀嬮柛娆惷€?*闁挎稑鐗婇搯閻忕偛绻楅崕妤呭疾椤栨稓澹夌€殿喖绻嬬槐浼村矗濮楀牏绀嗛柨?
   *   闁兼澘鏈搯閻忕偛绻愰懜浼村箑娴ｈ鎷遍柡鍫熸そ閻涙瑦绋夊鍕晩 闁?**闁稿繐鐗嗛崰鍛村级閳ュ弶顐?*闁挎稒鐡猂zdBranch` 闁革负鍔庡﹢锟犲嫉鏉炴壆鐟愰梺鎻掔箰閸ゎ參鏌屽鍛秾闁告牞娅ｅ▓鎴犫偓鍦仱濡绢垶宕氶崱妯绘殰
   *   闁挎稑娼塨ranchSane` 闁哄偆鍙€閳诲牓鏁嶆径澶岊吅闁告艾鍑界槐婵嬪礃瀹ュ懎鏋€閻庤纰嶉弫瑙勭▔瀹ュ棙鏆紒鎰閳ь剙鍊诲▍銉ф媼閺夋妲遍柨?
   *   `_recover/logic-src/闁烩晩鍠楅悥锝夊煑?閻庣妫勯惈鍡涙閵忊剝绶茬紓浣哄枍缁?闁哄倽妫勬导鎰板炊閸欍儳鐟㈠Δ鐘叉湰閺?md` 閹?闁靛棗鑻崹浠嬪箲椤曗偓閸ｆ悂宕ｉ悩顔瑰亾瀹ュ啠鍋?
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

  // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛鍥ㄧ▔婢跺﹤纾╁☉鏃€绻嗛悿?/ Round 20闁挎稑顧€缁辩櫗@Builder phoneSwiperBackdropImage()` **鐎瑰憡褰冮崹褰掓⒔?* 闁炽儲鏌￠埀?
  //   閻庣懓鍟抽崵婊冾啅鏉堚晜鐣?JSDoc 閻忓繐宕崯鎾诲及?`grep -n "phoneSwiperBackdropImage"` 闁告瑯浜濆﹢浣衡偓瑙勭煯缁犵喐寰勯崟顔剧濞戞挴鍋撳☉鎿冧簻閹斥剝绋?闁?闁哄牜鍓氬鐢典焊鏉堛劍笑婵繆顔婇崬顒勬儘?闁?
  //   闁告帞濞€濞呭酣宕?`backgroundImageSource()` 濞戞梻鍠栧▓銏＄▕鐎ｎ喗绁╅悹瀣暟閺併倝鎳撻崪鍐濞戞挶鍊涢埀顒€鎳嶇粩瀵告導閾氬倻鐟撶紒鎯у皡缁辨岸濡?
  //   闁告帞濞€濞呭孩绗熷┑鍥хウ濞戞挸绨兼鍥偋閳哄喚鍎婇柛娆戞焿閸ゆ粌螞閳ь剟鏁嶉崸顣昫ules.abc GONE闁挎稑顦抽～?RzdMusic閻犱焦婢樼换?md 閹?6.15闁?

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
            // 妤犵偠娅曞?婵℃鐭傚浼存晬濞嗙idRow 鐎归潻绠戣ぐ鎼佸礆閸℃鍩夐柨娑樼墕閻ㄦ繈妫?| 婵繂鐭侀惁婵嬫晬婢舵稓绀夊銈呯埣閸?padding 閻犱讲鏅欑紞鍛磼濞嗘垹鍩犲☉鎾亾 TopArea
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
                    // 2026-10-17：`showControlArea` 默认 true 且全仓从未传过 false ⇒ 封面页里会**再画一份**
                    // 控制区（Slider + 5 颗传输键 + 4 颗图标行），与底部共享那一份重叠。用户报的"第二个控制区"就是它。
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
                    // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?/ 闁烩晩鍠楅悥?闁宠绲婚埀顒€鑻鏃備沪瀵版稓鍏樺浼村级婢舵瓕鈷堥柛鎺戞閺侇喚绱掗悢鍓侇伇闁靛棗绋勭槐姘舵晬?
                    //   闁哄啰濮烽弲?*婵炲备鍓濆﹢?* `LyricsComponent` 闁告劕鎳庣紓?婵繂鑻幃?- 婵繂鏈晶?閻炴稏鍔岄妵鏃€娼诲▎蹇旂濞?
                    //   闁挎稑娼塤recover/logic-src/婵繂鐭侀惁婵囥亜閸偉鐧侀悘鐐插€搁惃婵嬫椤厾鐟㈡慨婵嗚嫰閹洜鈧姘ㄩ…?md` L1449 闁告鍠愰弸鍐晬?
                    //   闁靛棗鏈Λ銈夋偩鐏炲墽姊鹃柡?`LyricsComponent` 闁告劕鎳庣紓?header 閺夆晜鐟ュú鏍ㄧ鐎ｃ劉鍋撳蹇曠闁?
                    //   闁宠法濯寸粭?闁归潧顑嗗┃鈧梺顓ㄧ导缁旀挳寮ㄩ銈囩濞戞挸顑夊?L2002 闂侇叏绲介ˇ鈺呮晬婢跺矈鍎?1 闁秆勵殔閸戯紕绱掕箛搴ｇ倞濞?`true`闁?
                    //      闁?*閻庣妫勯惈?闂傚牄鍨哄妯绘交濞嗗氦鈷堝璺哄缂嶅寮懜鐢电濞?* 闁炽儲鏌￠埀?闁告瑥鐗婂Σ?
                    //      閹?6.1.6 / 閹?6.16 / 閹?6.17 闂侇叏绲奸柌婊堝Υ鐏炶姤鍊卞☉鎾亾鐟滆埇鍨绘慨鎼佸嫉?N 濠㈣泛瀚ㄩ埀顑跨瑜把囧绩闁稓鍟婂☉鎾亾濠㈣泛瀚ㄩ埀顒€绉跺▓鎴︽嚀娴ｅ湱妯呴柣銉ユ噷閳?
                    //   闁告劖銇炵紞鎴﹀及椤栨氨鏉介柟鍨尭閻ゅ嫰鎯冮崟鍓佺獥闁哄牜鍓欓崹搴ㄥ绩椤栨瑧鐟愰梻鍫涘灩濮樸劑寮?`MusicPlayInfoBlock`闁挎稑婀?908闁挎稑顦﹢顏堝及閸撗佷粵
                    //   閻忓繋绶氬?+ 婵繂鑻幃?+ 婵繂鏈晶?闁?婵繂鐭侀惁婵嬪礃瀹ュ牆娈伴柟韬插劙缁旀潙鈻庨垾铏殤闁?闁告艾濂旂粩瀛橈純閺嶃劎鎽冮柛姘Т閸ゎ參鎮虫０浣解拡婵?闁?
                    //   闁?闁芥ê绻戠敮鈧悗?*濞戞挸绉冲☉顏呯鐠佸磭绉垮ǎ鍥ｅ墲娴?*闁挎稑濂旂粭鏍ㄧ▔鎼淬垺锟ラ柣锝呯灱濞堟垹鎲撮崒娑樺Τ濞戞挴鍋撻柤閿嬬暘閳?
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
            // 闁宠棄鎳夊Σ?闁烩晩鍠楅悥?闁?闁?*闁告帒妫欓弫顔裤亹閹烘垹娼ｉ悹鍥э攻閺?*闁挎稑鐗愰～?`logBranchSurface()` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柕?
            //   闁宠法濯寸粭?**闊洤鎳橀妴蹇涘箰閸屾碍韬?`.onAppear()` 闂佹彃鐭夌槐婵囩▔瀹ュ牆鍘撮柣鈺佺摠鐢挳宕?`@Builder` 濞达絾鎸搁崬瀵告嫬閸愵亝鏆?* 闁炽儲鏌￠埀?
            //      ArkTS 闁?`@Builder` 濞达絾鎸歌ぐ褔骞掗妷銉ョ秬 **UI 缂備礁瀚▎銏㈡嫚椤撶喓銆?*闁挎稑鐬煎ú鍧楀箳閵夈儱鏅搁柡鍌濐潐绾墎鎷崘顏呮殢濞村吋姘ㄧ槐顏嗘嫚閹寸偛袚闂?
            //      闁挎稑鐗婂﹢鐗堟姜椤旇偐鏉芥繛鏉戭儜缁辩櫗'this.logBranchSurface('wide')' does not meet UI component syntax`闁挎稑顦埀?
            //   闁宠法濯寸粭?濞?*濞戞挸绉烽崗?*闁圭鍊稿﹢?闂侇叏绲肩粩鎾绩椤栨粍鐣遍柡宥囨嚀椤旀劙宕?濞戞挸锕ゅ銊︾閵夈倛绀嬪鍓佸枍缁繝鏁嶅宕囩闂佹彃鏈€垫洟宕?`Column` 濞戞挸顭槐?
            //      閻庣懓鍟ぐ褔宕?*闁哄牜鍓氶弫顔斤純閺嶎煈鍋ч柟绋垮€藉ù?*闁哄啯鍎艰闁?闁?闁归潧顑嗗┃鈧柍顐ｆ煥椤旀梻浠﹁箛濠傛櫖闂傚牄鍨哄妯荤閹烘梹绁查柛鎺戞处瀹曟煡寮捄鐑樺€楅柡澶堝劙缁旀潙鈻庨埥鍛
            //      鐟滆埇鍨硅ぐ澶愬嫉閻斿吋锛熷☉鎾崇С缁变即宕氬畡鎵綄闁挎稑娼塴ogBranchSurface` 闁告劕鎳橀崕瀛樻交濡粯绠掑☉鎾亾閻忕偛鍊婚鐑藉触瀹ュ牆螡婵炵繝绶ょ槐姘跺Υ?
            .onAppear((): void => {
              this.logBranchSurface('wide');
            })
          } else {
            // 闁归潧顑嗗┃鈧柨娑欑摂wiper 閻忓繋绶氬?婵繂鐭侀惁婵嗩煥閹存繂袟 + 閹煎瓨娲熼崕鎾箳瑜嶉崺妤呭礌?
            Column() {
              // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁活潿鍔嶉崺娑㈡儑閻斿憡绨氶柟鎼簻濞存鏁敃鈧崵顓㈡儍閸曨垱锛栧Λ鐗堬公缁辨澘顫㈠畝鍐Г濡炪倝娼ч惃婵嬫閵忥紕姊鹃柛娆惷惃?*闁?
              //
              // ## 閻犲洨绮弳鐔兼晬閸垺鏆忛柟?2026-10-16 22:42 闁规惌浜滃ù姗€鏁?
              // ```
              //   V d73f1b8 闁?scale=1.000 p=1.000
              //   real=1 clone=0 snap=30/30 end=331/331 op=1.000 stage=2 drv=0
              //   闁?edge=331 t=0.00        闁?闁?閻忓繗椴稿Σ鍛婃交濞嗗海顏遍悗鐢垫缁辩殞 闁稿绮屽﹢?0 闁?閻忓繋绶氬?= 331闁挎稑鐗婇弳锝囩玻濡ゅ懎浜濆☉鎾亾濞寸姵鏋荤槐?
              // ```
              //   閻忓繋绶氬鎵焊閸濆嫷鍤?= `lyricMorph(lyricMorphT).size`闁挎稑鐭侀埀?`lyricMorphT` 闁告瑯浜濆﹢?0/1 濞戞挶鍊撻柌婊呯矙閸愯尙鏆伴柛濠勩€嬬槐?
              //     `t=0` 闁?閻忓繋绶氬?= `endCoverSize`闁挎稑鐗冩晶?31闁挎稑鑻妵鍥╀焊娓氣偓濞间即鏁嶆径娑氬耿`t=1` 闁?`lyricCoverSizeOf()`闁挎稑鐗冩晶?8.7闁挎稑鑻惃顒備焊娓氣偓濞间即鏁?
              //   闁?闁靛棗鑻惃婵嬫閵忥紕姊鹃柛娆惷惃顒勫Υ瀹ヤ礁鈷?**`lyricMorphT` 婵炲备鈧啿鐓?1**闁?
              //
              // ## `lyricMorphT` 闁汇劌瀚弫顔界▔閳ь剟宕樺▎蹇撳汲闁兼澘鎳忓Σ?`animateLyricMorph`闁挎稑鐭侀埀顒€鑻悾鐘诲矗椤忓啰鐭ら弶鈺傜懇閸ｉ鎮銉ф
              // ```
              //   .onAnimationStart((index, targetIndex) => {
              //     if (index === targetIndex && !this.lyricMorphVisible) { return; }   // 闁?閻庣懓鐗嗗畷?
              //     this.animateLyricMorph(targetIndex === SWIPER_INDEX_LYRIC);
              //   })
              // ```
              //   闁宠法濯寸粭?閺夆晜鐟ら柌婊呪偓鐟扮墕瀹曞ジ鎯冮崟顕呭殧濞戞柨顦板Σ?**鐎规瓕灏欑划锟犲捶閵娧勭獥闁哄秴娲妴澶嬬?*闁挎稑娼塱ndex === targetIndex`闁挎稑濂旂粭澶愬及椤栨瑧顏辨繛鍡磿濠€鈥愁煥閹存繂袟闁?
              //     閻忓繗绮鹃悜锔芥交? 闁炽儲鏌￠埀?闁?`Swiper` **婵炲备鍓濆﹢浣虹磼閹存繄鏆?`.index()`**闁?
              //     `playbackSwiperIndex` 闁告瑯浜為弫?`.onChange` 闁告劖鐟ｉ埀顑跨閼荤喖宕?`onAppear` 闂佹彃鐭侀～锔藉緞瀹ュ嫮绉撮柟?0闁?
              //   闁?闁告瑯浜ｉ々?闂佹彃绉电€垫洘娼懞銉︻槯 swiper 闁汇劌瀚崹鍨叏鐎ｎ喓鈧?闁?闁绘鍩栭埀顑跨窔閸ｇ兘鎯冮崟顖樷偓?闁挎稑鐭傞妴澶嬬▔鎼达絽笑闁诡兛绀佸?*闂傗偓閹稿孩鍩傚☉鎾崇С缁旀挳鎳?*闁?
              //     闁绘鍩栭埀顑挎祰椤斿洭鎯堥埀顒€顫㈠畝鍐Г濡炪倗鍋ｉ埀顑垮wiper 闁稿绮屽﹢顏嗙箔?0 濡炪倗顣槐娆撳箣閺嵮冨唨濞戞柨顑戠槐姘跺焽?闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傛慨婵嗙焷閻︽繃銇勭喊澶岀
              //     濞达絽妫欓惀鍛村嫉婢跺宕插ù?婵犲﹥鍨垫慨?闁告瑦鍨归弫?闁?`animateLyricMorph` **濞寸姴瀛╁闈涒柦闄囬～锔炬嫬閸愵亝鏆?* 闁?`lyricMorphT` 闁?0
              //     闁?閻忓繋绶氬浼村箒閹哄秷绀嬪鍫嗗啰娈遍梻鍫娇閳?*閺夆晜鐟ょ粭宀勫箣椤忓嫭绂堥悗鐟拌嫰閸欏繘宕ョ拠鍙夊€?*闁?
              //
              // ## 闁衡偓鐟欏嫮銆婇柨娑樼墛婵℃悂鎮╅懜纰樺亾娴ｈ绨氶柟鎭掑劚濞叉牠宕㈡导娆戠獥閻?swiper 闁汇劌瀚崹鍨叏鐎ｎ喓鈧?= 闁绘鍩栭埀顑跨窔閸ｇ兘鎯冮崟顖樷偓澶愭晬?
              //   `.index(this.playbackSwiperIndex)` 闁炽儲鏌￠埀?閺夆晜鐟﹀Σ?ArkUI `Swiper` 闁汇劌瀚悾濂稿棘閻熸壆娼ｉ柟顑秶绀?
              //   闁兼澘鏈崹婊勭椤掍焦鎷遍柡澶堝劚濮樸劑骞庢繝鍛濞戞搩浜滈埀顒傚帶缂?鐟滅増鎸告晶鐘炽亜?闁汇埄鐓夌槐妾?onChange` 闁告劖鐟ラ悾鐘诲Υ娑旑柕nAppear` 濠㈣泛绉崇紞鍛偓鐟板枦缁辨岸濡?
              //   闁宠法濯寸粭?**濞戞挸绉寸槐鈺呭礂閵夈倖宕插ù锝嗘礃閺屽﹪寮弶搴撳亾?*闁挎稒鑹鹃悾鐘诲及?闁硅泛锕ら崙锟犲嫉婢跺本鐣遍柣妯垮煐閳ь兛鐒︾敮鎾礆閹峰矈娼掗柛銉ュ綖缁?闁挎稑鑻惈妯荤┍椤旇崵顏遍柤宄扮摠閳ь儸鍡忓亾鐏炶偐鐟濋柡鍕靛灥閻ㄧ喖宕ｉ崒妯峰亾?
              //   闁宠法濯寸粭?闁?026-10-16 閻犱降鍨洪婊堝Υ閹达絿绠归梺鎻掕嫰鐢偊寮堕妷銉ユ櫢闁活偀鍋?`onAppear` 闂佹彃鐭傞崑鍛村矗?
              //      `playbackSwiperIndex = 0` 濞寸姴绉崇换姘舵偩? 闁炽儲鏌￠埀?**闂侇叏绲借ぐ鐐差啅閼碱剛鐥呴柛鎺斿У鐢偓濞?*闁?
              //      閻庣懓鍟Σ鎼佹嚍閸屾粌浠紒鐙欏啯绀€閻犲鍟撮崳鐑芥儍閸曨偄鏅搁柛蹇嬪劵缁辨繃瀵煎顓烆潵闁瑰搫顦遍弫銈夊箣瀹勬壆绉奸柛鎾崇Ч閵嗗鏁?
              //      "闁瑰灚鎸哥槐鎴﹀箻椤撶喐鏉归柛锝冨妼濞叉牜浜告笟鈧鐗堛亜?闁?*闁瑰灚鎸哥槐鎴﹀箛韫囨挻绂?*闁汇劌瀚禍瀵告嫻閿濆繒绀勯悷娆庣閸炲鈧湱鎳撻惇?`onAppear` 闂侇叏绲鹃宀勬⒐閹稿孩鏆堥梺鎻掝煭缁辨岸濡?
              //   濠㈣泛绉甸悧鎶藉礂閹惰姤鏆涢悗娑欘殣缁辨澘顕ラ懞銉у灱**缂佹鍏涚粩椋庢偘?* `sw=` / `tgt=`闁挎稑鐗婇弻濠囧礉閻欏懐绀嗛柍銉︽煛閳?
              //     `sw=1 tgt=1` 闁归潧绉靛Σ绋款潰瀹€鍐Г濡炪倗鏁稿▓鎴濐潰閿濆懐鍩楅柟顑跨筏缁辩浗sw=0` 闁兼澘濂旂紞姗€宕烽妸锔炬憙閻犲洤绉归妴?闁?閻忓繗椴稿Σ鎼佸嫉椤掍焦钂嬮柕?
              Swiper() {
                Stack({ alignContent: Alignment.Bottom }) {                  // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*濡?0 闁哄嫷鍨抽埞鏍ㄧ珶?*闁?
                  //   闁哄啰濮烽弲顐︽儍?`playerPane` 闂?`Swiper` 濞戞挶鍊濋妴澶愭焾閽樺娑ч柡?`Column().width/height('100%')`闁?
                  //   **閻忓繋绶氬鐗堢▔鎼淬垻鎽冮柛姘У閻楁挳寮甸璺ㄧ憹闁革负鍔戦妴澶愭煂?*闁挎稑鐭侀埀顒€鑻﹢?`Swiper` 濞戞柨顑呴ˇ濠氭儍閸曨噮娲柣鈺傜墪閻?
                  //   闁挎稑娼塮loatingCover` / `floatingMeta`闁挎稑鐭侀～?`PlayerPage閻庣懓鏈弳顤汭閻庤姘ㄩ…?md` 閹? / 閹? / 閹?闁挎稑顦埀?
                  //   闁?閺夆晜鐟╅崳鐑藉礆閻樺啿绔?`MusicPlayInfoBlock`闁挎稒鑹鹃悾鐘绘嚊椤忓嫮鏁ㄩ悘蹇庣窔濞?+ 婵繂鑻幃鏇㈡晬?
                  //     闁伙絾鐟у鍐焊閸欐绐楅柛婊冪焸閸嬪懏绋?*闁哥儐鍨粩鎾儍閸曨噮娲柣鈺傜墪閻?*闁汇垻绮崹姘▔閵堝嫬鏁滈悘蹇庣窔濞间即濡?
                  //   闁宠法濯寸粭?閻庣懓鍟敮顐﹀级閵壯勭暠濞戞挶鍊撻柌婊堟嚂瀹€鍐厬闁挎稑娼?id(PLAYER_BIG_COVER_ID)` + `reportBig`闁?
                  //      `.id(PLAYER_META_*_ID)` + `publishMeta`闁?*鐎规瓕灏欑划锟犲箹椤掆偓閸╁瞼鎲伴崱娆愮０閻?*闁挎稑鐗愰～?
                  //      `reportPlayerCoverFromOverlay` / `publishMetaEndpoint`闁挎稑顦埀顒佹煛閳?
                  //      閺夆晜鐟﹀Σ鍛婃交濞嗘劦鍋ч柤瀹犳閸ㄥ綊鎯冮崟顐㈩枀闁圭粯鍔х槐杈ㄧ▔婵犱胶顏遍弶鐑嗗枛濮樸劑寮伴娑氱濞存粌妫滅换鏍ㄧ▔閳ь剙顫㈤妷顖滅閻庝絻澹堥崵?閻忓繋绶氬鏉库槈閸縿浜?+ 闁告柣鍔庨弫楣冨礂閵娿儳鐔?闁?
                  //   闁宠法濯寸粭?閻庣妫勯惈?闂傚牄鍨哄姗€鏌囬敐鍕拡闁哄鈧啿鐎婚柡鈧娆戠煗闁革负鍔庨弫銈団偓鐟板枦缁辨獋PlaybackPage` 闁告劕鎳庤ぐ鐔煎嫉婢跺鈷堝璺哄缁辨岸鏁?
                  //      闁圭鍋撳ù?import 濞ｅ洦绻勯弳鈧柕?
                  Column() {
                    MiniLyricLinesComponent()
                      .width(StyleConstants.FULL_WIDTH)
                      .margin({
                        left: 4,
                        right: 4,
                        // 鈽呪槄鈽呪槄 2026-10-17锛堢敤鎴凤細銆?*灏忔瓕璇嶆斁涓嬮潰**銆? 鎴浘閲屽畠鍘嬪湪姝屽悕琛屼笂锛?
                        //   瀹冩墍鍦ㄧ殑椤?0 `Stack` 鏄?`alignContent: Bottom` 鈬?杩欎竴鍧楃殑涓嬭竟**璐寸潃
                        //   swiper 鐩掑簳杈?*锛岃€屾瓕鍚嶈姝ｅソ涔熷湪閭ｄ竴鏉″甫涓?鈬?蹇呯劧閲嶅彔銆?
                        //   鈬?缁欎竴涓?*鍚戜笂鎶?*鐨勪笅杈硅窛锛屾妸鏁村潡鎶埌"姝屽悕琛屼笅娌?鈫?杩涘害鏉′笂娌?涔嬮棿銆?
                        //   鈿狅笍 56 鏄鐗堝彇鍊硷紙鈮?涓よ姝岃瘝鐨勯珮搴?+ 涓€鐐瑰懠鍚革級锛涙寜鎴浘寰皟灏辨敼杩欎竴涓暟銆?
                        bottom: 0
                      })
                        // 闁粹偓?2026-10-17闁?*闁告绮敮鈧悹鎰枎椤︾粯娼忕涵鍛崺** 闁炽儲鏌￠埀?闁圭顦粭鍌氥€?gemini 濠㈣泛绉甸悧宕囩磼閹捐鍟堥柨?
                        //   濡?0 闂佹彃鐬煎▓鎴﹀礃閸涱収鍟囬煫鍥ф嚇閵?*婵炵繝绀佺槐?*闁圭儤甯掔粩鐑藉捶閵婏附鎷卞銈夋涧椤旀劙宕抽妸鈺佹闁?*濞戞挸绉烽蹇涙偨閵娧呭崪閻庣數鎳撻悾鐐媴?閻犳劗鍠庨ˇ缁樻綇绾懐鐛?
                        //   闁硅泛锕ら悾鐘诲箳閵娿儱鐓傛慨婵嗚嫰閹洜鎮板畝鍕簼濞戞挴鍋撻柡澶嗏偓宕囨暔**闁挎稑鑻幆渚€宕氬▎蹇氬煂闁告瑦蓱濠€鈩冨濮橆偆鐟㈡慨婵嗚嫰閹洜鎮扮仦鐑╁亾娴ｇ晫绠婚幖杈鹃檮濞碱垶鎯勯崨濠冨闁?
                        //   闁告鍠愬鍨交濞嗘挸娅￠柡?`bottom: -MINI_LYRIC_SINK_VP`闁挎稑鐗婃俊鍝モ偓鐟板暙缁舵碍绋夌€ｎ偄鑵?112vp 闁?闂侇剙鐏濈槐鎴濐潰鐏炶姤鍊?闁挎稑顧€缁?
                        //   闁兼澘鏈悺鏇㈠触瀹ュ牜鏀介柣婊勬緲濠€顏勵啅閸欏鏆柣?*濡炪倝娼ч崬鎾锤閹邦厾鍨?*闁挎稑鐗呯粭鍌氥€掔粙鍨稉鐎垫澘瀚哥槐姘跺焽?濞戞挸绉撮崯鈧梻鍥ｅ亾閻熸洑娴囩换鏍ㄧ▔椤忓泚澶嬬▔娓氬﹦绀?
                        //   闁伙絾鐟у鍐矗瀹ュ牃鍋撶仦鑲╃獥闁硅泛锕ら悾鐘诲箳閵娿儱鐓傞柡鍥╃節缁楀懘妫冮姀鐘茬闁瑰墽鍋犵换妯绘償閿旇姤钂嬮柕鍡楀亰缁?
                      // 閻忓繐绻戦悺鏇犳嫚瀹ュ懐娼ｅù?闁告劕鎳庨?闁挎稒鑹惧鐣岀磽閺嶎剛妲梺?`contentOpacity` 闁解偓閹存帞绉撮柟闈涚Ф閻?1
                      .opacity(this.expandState.morphContentOpacity)
                      // 闁宠棄鎳夊Σ?2026-10-15 闁活潿鍔嶉崺娑氣偓瑙勪亢閻ㄧ喖鏁嶅銉㈠亾?*闁稿繐鐗撻ˉ锝夊礂閵壯勭暠闁哄嫷鍨伴惃顒€顫㈠畝鍐Г闁告粌鏈弫褰掓寠韫囨柨鐦婚梺?*闁?
                      //   闁?閻忓繐绻戦悺鏇犳嫚瀹ュ牐娉?*缂佹鍏涚粩瀵哥磼?*闁汇劌瀚鍌炴⒒鐎靛摜宕堕柨娑樻綁earlyRiseVp()`闁挎稑鏈Λ顓熺鎼淬垹浠橀柛鎺曟硾鐏忣垶鏌囬敐鍕伇缂備礁瀚哥槐姘舵晬?
                      //   濞寸姴绨肩粭鍛村础閸ヮ亝宕?180vp闁挎稒鐩銈咁潰閵忊檧鍋撴担椋庣Т缂佸绮禍?0闁挎稑鐬兼晶妤呮閵忋倐鍋撻幇顒€鍓肩紒杈╁С缁楀宕ｅΟ绯曞亾?
                      .translate({ y: this.expandState.contentRiseVp() })
                      // 闁衡偓閹増宕抽弶鈺佹川閳诲吋绋夐鐐叉暥閻庡湱顢婇～锕傚储鐎ｎ偄顣抽柨娑樿嫰閻剙顫㈠畝鍐Г濞村吋鑹鹃幏浼村箳瑜嶉崺妤呭礌鏉炴壆闉嶉柣鈺佹憸濞插﹥鎷?
                      // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛弫銈夊箣閸戙倗绐?*闁靛棗鑻惃顒€顫㈠畝鍐Г闁绘粍婢樺﹢顏堝矗濡鐏囧ù婊冩婵晠鎮介懡銈囨尝闁哄鍠嶇粻锝夊触鎼淬垹顤呴柛鎴ｆ楠炲洭鏁嶇仦鐐毉濞戞挴鍋撳☉鎾愁儜缁?
                      //   闁告瑥鍊介埀顒€鍟崣鍓р偓鐟板暙濞硷繝骞€鎼存繄鐤勫瀣仜閸欏棝濡?*闁挎稑顦崳?闁逛勘鍊曞ú鏍ㄧ▔婵犱胶顏遍柣?鐟滆埇鍨硅ぐ澶愬嫉閻旀椿鍞ㄧ€殿喒鍋?闁汇劌瀚板▓锝夋寠韫囨稒锛岄柨?
                      //   閻庣懓鍟幏浼村礆椤愩倖鐣遍柛褎銇炵粩鎾冀閸戙倗绀?*鐟滆埇鍨硅ぐ澶愬嫉閻旈攱鐨戦悹鍥ュ劚濠€顏堝捶?*闁靛棔娴囬摂瀣箔椤戣法顏辩紓浣稿濡炲倿姊荤€靛摜宕?`earlyRiseVp()` 濞寸姴绨肩粭鍛村础閸ヮ亝宕?
                      //   闁挎稑鐗呯粭鍌炴閵忋倕浜濋柡?`.translate`闁挎稑顦埀顒€鍊婚～顐﹀箻閻愮儤锛栧Λ鐗堫焽閺佸崬顫㈢仦鑺ュ€抽悶娑樻湰閺佸吋銇勯棃娑樻暥闁秆勫姈閻栵絿鎲撮敐鍛瀫闁挎稑濂旂粭澶愭閻樼儤顥戦悗鐟板暔閳?
                      .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
                  }
                  // 闁?2026-10-15 閻犲洤锕ラ弻鍥煥濮樺崬浠柨娑樻綁hdc shell hilog -x | Select-String 'RzdBoxes'`闁挎稑顧€缁?
                  //   闁?*濞戞挸顦柌婊勫濮橆偆闉嶉柣鈺冾焾鐢洭鎯冮崟顐ｅ仴**闁汇劌瀚悰銉╁矗閿濆洨鍙愮憸閭︽線缁旀潙鈻庨埄鍐ㄢ叺闁告垹鍎ゅ?闁炽儲鏌￠埀?
                  //     `lyric` 閻忓繐绻戦悺鏇犳嫚?/ `title` 婵繂鑻幃?/ `singer` 婵繂鏈晶?/ `cover` 濠㈠爢鍐闂傚牜娼块埀?
                  //   闁告帇鍊栧畵渚€鏁嶅姝瓂ric.top` 濞?`singer.bottom` 闁烩晠鏅插?闁?閻忓繗椴稿Σ鎼佹偨閵婏箑鐓曢柟韬插劤濞?閺夆晜鐟╅崳鐑芥煥濞嗗海绉?闁?
                  //         濞戞挸绉跺ù澶嬬閵堝牃鍋撶仦鑲╃煗闁活亜顑囧鍐储鐎ｎ亝韬☉鎾亾閻?闁?闂侇叏绲惧Σ?*缂備焦锚閸?*闁挎稑婢僣ale/clip闁挎稑顦抽埀顒€濂旂粭澶愬及椤栨稑绗撻柣妤€鐗炵槐婵嬪矗閿旇棄顥濋柕?
                  .id(PlaybackPage.MINI_LYRIC_BOX_ID)
                  .onAreaChange((): void => {
                    this.logLayoutBoxes();
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                // 闁?婵繂鑻幃?婵繂鏈晶婊堟焽閿濆嫮顏遍悶?*闁告瑯浜ｉ摂瀣亜閼哥數鍩夐梺顓ㄧ导缁旀潙顩?*闁挎稑娼塸ullChromeOpacity = clamp((effT-0.18)/0.44)`闁?
                //   0.18 闁?0.62闁挎稑顧€缁辨繈宕濋妸褎鏆伴弶鈺佹川閳诲吋绋夐鐐寸殤閻犲洢鍎茬拹浼村礂?闁炽儲鏌￠埀?濞戞挸娴烽弫銈夊箣闁垮顎為柡澶庢硶濞堟垹绮?2 闁哄鈧尙顏遍柤閿嬬暘閳?
                //
                // 闁宠法濯寸粭?閺夆晜鐟╅崳鐑藉储閻斿憡闄嶉弶鈺偯ぐ鏃€绂嶉崱鏇狀伇閻?`metaOpacityValue() = clamp(1 - morphP/0.35)`闁?
                //   闂?*闁哄嫷鍨电化鐘虫媴閻樿櫕钂嬮梺顓ㄧ导缁斿瓨绗熻濞堟垵菐閳ュ啿姣?*闁稿浚鍓欑槐锟犳晬閸?0.35 閻忓繐宕紞濠囨⒖鐠佸湱绀嗛柨娑樿嫰椤ㄦ粓宕烽妸锔藉啊闁衡偓妤ｅ啨鈧娼诲▎搴ｎ伇閻炴稑濂旂粭?
                //   = 闁活潿鍔嬬悮杈ㄧ▔椤忓牊锛屽鍓佹嚀閹挻绋夐埀顒勫锤濡も偓閸炲鈧?闁炽儲鏌￠埀?`pullChromeOpacity` 闁哄嫬瀛╁Σ鎴濐啅閼碱剛鐥呴柛?1闁?
                //   闁告顥愰～?`metaOpacityValue` 闁圭顦崺?0闁挎稑濂旂花顒勫及椤栨稓鎽冮柛?婵繂鏈晶?*闁稿繈鍔庨埢鍏肩▔瀹ュ懎璁查悷娆庨檷閳ь兛娴囬幆銈嗘媴瀹ュ棗顤呴柛鎰笒閸ゎ參寮?*
                //   闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儑濞堟垿濡寸仦鐣屾綌鐎殿喒鍋撳☉鎿冨幗閺嬪啰鈧稒顨堝ú鍧楀礆閹殿喚娉㈤柡澶屽枑婢х娀宕欓搹鐟扮疀闁靛棗绋勭槐姘跺Υ?
                //   闁告帞濮电敮鈧弶鈺傜懁缁斿浠﹂崒锔剧獥`MusicPlayInfoBlock.MusicInfoTexts` 闁煎浜滅换浣割啅閼碱剛鐥呴悽?`pullChromeOpacity`闁?
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
                    // 闁?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*婵繂鐭侀惁婵囥亜閸忓摜鐟濋柛鎰Х閸ゆ粎鏁?婵繂鑻幃?閻犲洤绉靛ú?閻炴稏鍔岄妵?*闁?
                    //   闁哄啰濮烽弲顐㈩潰瀹€鍐Г濡炪倗鏁婚妴濠冪▔婵犲倹鐨戦柡鍕靛灦閸嬪懏绋夐埀顒勫级閳╁啳鐧侀悘鐐插€归搯閻炴稑鐭夌槐娆戜焊韫囨挾娈遍梻?+ 婵繂鑻幃?+ 闁衡偓閹増顥?闁哄洦娼欓ˇ鍧楁晬婢舵稓绀?
                    //   婵繂鐭侀惁婵嗩潰閿濆棙鐎梺鎻掓湰閻ュ懘寮垫径宀婂剳濞存粌濂旈柌婊冾潰鐏炶姤鍊抽柕鍡楀€哥敮顐﹀级閵夈劎绠归梺鎻掓湰濡?`isSmHeightMdLayout()`
                    //   闁?缂佹梹鐗曢惈鍡樼▔婵犱胶绐?*闁告艾鏈?*闁告垼娅ｉ獮鍥归鑲╂勾闁汇劌瀚悺鏇㈠触瀹ュ懏瀚叉慨婵嗙焷閻︽繈鎳涢鍕暔闁?
                    //   "闁哄牆顦甸ˉ鎾诲籍閻樻椿妫戦柣銊ユ閸ゆ粓鎮?- 闁绘粌顑勭粩瀛樻媴?/ 閻犲洤绋勭槐浼存閹烘挾鍘?闁挎稑鐭侀～鍥箛閻旈攱鐨戦柡?婵繂鑻幃鏇㈠礄閾忕懓绠涘☉鎾卞€栭?闁?
                    hideLyricsMetaHeader: true,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*閺夆晜鐟ょ粩鎾锤濡や胶銈撮梺鎻掔箰閸戔剝绂?闁告帇鍊栧畵?闂傚嫬绉舵鍥ㄧ▔?闁告縿鍔岄崣?** 闁炽儲鏌￠埀?缂備焦鎹侀鎴濐啅閺屻儲锛旈柛姘墳缁辨岸鏁?
                //   濞戞挸锕ユ慨銈咁潰瀹€鍐Г濡炪倝娼ч崬瀵糕偓鐟版贡濞插懘鎯?*缂佹劖顨呰ぐ娑欍亜閹壆鐝?*闁靛棗鍊哥紞瀣礆濠靛棗顫ｉ悗鐟板暞濡插憡绋夋潪鎵晩閻?`lyricPadTop()` 閻熸洑妞掔粭澶屾啺娴ｇ懓搴婄紒鐘愁殔濞兼寮?闁?
                //   闁哄啰濮烽弲顐︽焽閿濆嫰鍤?`boxH/2 + bottomYAtLyric` 闁告艾鐗愰幑锝夊级閵夈儲鐨戦柡?婵炴惌鍠栭惇鐗堟償閺囷紕鐝?*闁烩晝顭堥顕€鎯勯幒妞尖偓?*"闁?
                //   闁兼澘鏈﹢鐗堢閹炬潙鐟?*缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨?*鐟滅増鎸惧ú鍛村礃閸涱垱绁查悗闈涚秺閸ｆ椽鎮?闁?闁告瑯浜滃﹢顏堟儎閹烘ぜ鈧?闁?0 闁哄啫澧庨悺鎴炵閺嬵偀鍋?
                //   闁?**闁衡偓鐠鸿櫣鍟茬紓浣规崄椤旀垿鏁嶅杈ㄧ＊濡炪倕澧庣划銊╁几閸曨亞鐟愰悘蹇氶哺濡?0**闁?闁?= Swiper 闁汇劌瀚ú鍛存晬濮圭磮iper 闁圭鍋撻柛锔哄妿濞?`Column`
                //     濞?`LyricFloatLayer()` 闁哄嫷鍨伴幃鎾寸▔閳ь剚绋夐鍐憹閻?padding 闁?`Stack` 闁汇劌瀚銏⑩偓娑欏姧缁辨繃绋夐弮鍥跺殙 `Stack`
                //     闁汇劌瀚崬瀵糕偓鐟版贡濞插懎顔忛敂璺ㄧ憪閻?= 缂佹劖顨呰ぐ娑㈠储閻斿搫浠?闁炽儲鏌￠埀?閻庣懓鏈弳锝囨嫚娴ｇ懓绁﹂梺鐐礃椤?`PlayerExpandState.lyricBoxTopVp`闁?
                //     闁?**濞戞挸绉瑰〒鍓佹啺娴ｇ懓搴婄紒鐘愁殣缁辨繃绋婇悢鍓佺憹闊洤鎳庨崯鈧悹鍥ㄦ缁绘牗绋夐鍛**闁靛棗鍊风换姘舵偩濞嗗海鐟愰柟韬插劚瑜把勭▔?閻忓繐妫欏鐢稿嫉婢跺鐪介柛?padding 闁哄啯鍎奸崗姗€宕ｉ幋鐘茬疀"闁?
                //   闁宠法濯寸粭?闊洤鎳橀妴蹇涙偨?`globalPosition`闁挎稑鐗忛悰銉╁矗閿濆懏缍忛柡宥呮祫缁辨岸鏁嶇€瑰潮osition` 闁哄嫷鍨冲ù澶屸偓闈涙贡閸╂绱掗崟顏咁偨闁汇劌瀚ㄩ埀?
                //   闁宠法濯寸粭?闁告柣鍔庨弫鐐▔椤撶偟鏆婇柛娆樺灥閸忔﹢鎯夐浣诡槯闂?0闁挎稑鐗嗛鎰板闯?`.scale/.translate` 闁告瑦蓱瀹曞弶娼婚崶鈺傜暠閻犲洨绮弳鐔兼晬鐏炵虎鍔€閻㈩垶娼荤槐姘舵晬?
                //     闁告瑯浜濆﹢?*闂傚牊鐟﹂娑㈠箑?*闁哄嫬瀛╁Ο澶愭?0 闁归潧绉烽鈺呭及鎼达絿娉㈤柡瀣瑜板绂嶉崱鎰ㄥ亾?
                .onAreaChange((_oldValue: Area, newValue: Area): void => {
                  this.expandState.reportLyricBoxTop(areaLengthToVp(newValue.globalPosition.y));
                })
                // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`PlayerPage.onLyricSwipe(offsetY)` 闁炽儲鏌￠埀?**闂侇偅鍔栧顖溾偓闈涚秺缂?*闁?
                //
                // 闁哄啰濮烽弲顐︽晬閸у垳recover/logic-src/PlayerPage.abc.txt:6938-6985`闁挎稑鏈€垫洟宕?`LyricsView` 濞戞挸顭槐姘舵晬?
                // ```ts
                //   onLyricSwipe(offsetY) {
                //     if (offsetY <= -SWIPE_TOGGLE_VP) {                 // 闁?濞戞挸锕ョ划?
                //       if (entryAllowsManual(this.lyricImmersive)) {   // 闁?闁?閺夆晜鐟ょ粩鎾绩?*闁哄牆顦靛Λ?*
                //         hideChrome(); clearIdle();
                //       }
                //     } else if (offsetY >= 24) {                        // 闁?濞戞挸顑嗙划锕傛晬閸繄鎽熼梻鍫涘灲閸?0x18 = 24闁?
                //       showChrome(); startIdle();                       // 闁?閺夆晜鐟ょ粩鎾绩?*闁哄啰濞€濡?*
                //     }
                //   }
                // ```
                // 闁?濞戞挶鍊曢ˇ鈺傜▔鎼粹€虫枾閻庡湱鍋熼獮鍥儍閸曨偅鈻曢柛鎺濆亾缁辨瑩鏌堥挊澶婂殥闁圭顦悺褔鎳為崒婊呭灣閻犱降鍨洪婊堟晬婢舵稓绐?
                //   闁?闂傚啫鐗嗛埀顒傘€嬬槐浼村箣閹存粍绮﹂柛妯煎枑濞肩敻宕樺▎鎴炵暠闁?**12**闁挎稑鐗婂﹢鐗堢閹剧懓娈伴悗瑙勬皑濞堟垶绋夐埀顒勫础婵犲繒绀嗛柨娑樻湰濡倝鎮?*濞戞挶鍊撻弲鍫曟焾閼恒儲笑 24**
                //      闁挎稑鐗呯紞鍡涘绩椤栨繆娉?`SWIPE_TOGGLE_VP`闁靛棔绶氶悵顕€寮ㄩ娑櫺﹂悗娑欘殜濞间即鏌?`ldai 0x18`闁?
                //        鐟滅増甯楅妴鍌滄暜閹间礁娅ら悶?`MiniMorph婵炴挸寮堕悡瀣棘闁稓鐟㈠銈堟硾缁ㄦ娊寮借箛鏃囩獥闁稿繈鍎遍崣鏇烆嚕?md:171` 濞戞梻鍠愬Σ?`SWIPE_TOGGLE_VP | 24`闁挎稑顦埀?
                //      闁宠法濯寸粭?12 濠㈤浜滈鎰板及閹捐鍤栭悷娆欒缁辨瑩寮甸鈧惇浼村及?`parallelGesture`闁挎稑鏈悺鏇犳嫚瀹ュ嫮顏辩€垫壋鍋撳☉鎾筹攻鐎氬浜搁崡鐑嗘 12vp闁挎稑顦埀?
                //   闁?濞戞挸锕ョ划锕傛焽閿濆嫮顏遍柡鈧姘含闁哄啰濮烽弲顐︽煂?*閻?`entryAllowsManual` 闂?*闁挎稑鐭侀埀?
                //      `entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`闁?
                //      濮掓稒顭堥璇差浖閿濆棙笑 **AUTO**闁挎稑娼塋yricEntryMode` 4 婵℃缍囩槐鐧楩F0/AUTO1/MANUAL2/BOTH3闁?
                //      閻?`婵繂鐭侀惁婵囥亜閸偉鐧侀悘鐐插€搁惃婵嬫椤厾鐟㈡慨婵嗚嫰閹洜鈧姘ㄩ…?md` 閹?闁挎稑顦崳?**濮掓稒顭堥璇差浖閿濆嫮鐟撳☉鎾筹攻缁附绂掗埀顒佺▕閸儱鍘村☉鎾崇Т娴?*闁?
                //      闁哄牜鍏涚划銊モ柦閳╁啯绠掗弶鈺傜懁闁叉粓鎮介妸锕€鐓曢悹浣稿⒔閻?闁?闁告瑯浜ｉ崗姗€宕?*濮掓稒顭堥?*閻炴稑濂旂拹鐔兼晬閸綆娼?`LYRIC_SWIPE_ALLOWS_MANUAL`闁挎稑顦埀?
                //   闁宠法濯寸粭?濞戞挸顑嗙划锕傛焽閿濆嫮顏遍柡鈧姘含闁哄啰濮烽弲顐︽煂?*婵炲备鍓濆﹢渚€姊?* 闁?闁瑰瓨鍨冲鎴﹀籍閻樿櫕钂嬪ù鐘虫构缁绘岸鎮惧▎娆戠`showChrome` + 閻犙呮焿椤撴悂寮拋鍦闁?
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
                  // 闁宠棄鎳夊Σ?A2闁?*闁圭顦扮拠鐐典沪閸屾繍鍞ㄥù?*闁挎稑鐗忛悺鎴炵闁垮锟ラ柣锝呯灱濞?`lyricPadTop()`闁挎稑顦埀顒佹煛閳?
                  //   閻犱讲鏅滈悺鏇犳嫚瀹ュ棭鍔€闁哄倸娲ｇ粭澶愭煢鐠囨彃鐓傚銈呯埣閸庢挳鏌囬敐鍛倞閻忓繋绶氬?+ 婵繂鑻幃鏇灻归鑲╂勾閹煎瓨娲戠粭鍛村Υ?
                  //   `lyricPadTop()` 闁煎浜滅换浣圭┍濠靛﹦妲?婵炴惌鍠栭惇鐗堢▔瀹ュ懎璁查柣顫妽濡炲倹娼婚弬鎸庣 0"闁挎稑娼?lyricFloat 闁?0`闁挎稑顧€缁?
                  //   闁圭鍋撳ù鐘劥缁绘牠寮?padding 闁革负鍔岄鏃備沪?/ 閻忓繋绶氬鐗堟交濡崵姊鹃梺鎻掔箰閸╁矂寮張鐢电憿闁衡偓閻熸澘袟闁?*闂侇偅鍔曢崕姘辨閻樿京顏遍柤?*闁?
                  //   闁宠法濯寸粭?闁告瑯浜滄慨鈺呮偩濞嗘垶顏ら柨?*婵繂鐭侀惁婵嬪礃閸涱収鍟囧☉鎾亾濞戞搩浜滈悺褎绋夊鍡樻毉**闁?
                  top: this.expandState.lyricPadTop()
                })
                // 婵繂鐭侀惁婵堜沪閻愭壆鑹?闁告劕鎳庨?闁挎稒鐡猚ontentOpacity`闁挎稑鐗愰幆銈嗘媴瀹ュ棗顤呯紓?1闁?
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
              // 闁粹偓?2026-10-16闁?*闁逛勘鍊曞ú鏍箣閹存粎鐟愬☉鎾亾閺夌儐鍠栨慨鐐烘儍?`.index()` 缂備焦鍨甸悾?*闁挎稑顧€缁?
              //   濞戞挸锕ｇ粩瀛樻姜椤旇棄鐏夐柛?`.index(this.playbackSwiperIndex)` 闁哄嫷鍨遍崗?闁硅泛锕︽慨鎼佸箑娴ｇ懓澶嶉柛鎺撳椤宕堕崣銉х憪"闁?
              //   濞?*闁哄啰濮烽弲顐﹀冀鐟欏嫭鎷卞☉鎾崇Х缁绘牗绋婇崼婵呯驳**闁挎稒鑹鹃悾鐘绘儍?`swiperProgress` 闁?`onContentDidScroll`
              //   闂侇偅鍔曢幎姘跺礃濞嗗秮鍋撴稊顤祅Change` **濞戞挸绉撮崯?*閻庣懓鍠涚槐娆掋亹閹烘挶鈧倻鈧姘ㄩ…?閹?.2 闂侇偅鍔栧顖溾偓娑欘殙婵☆參鎯嶆笟濠勭獥
              //   闁靛棗鐣瑻34*^1*#^1`闁挎稑娼塷nChange`闁挎稑顒?90080-190110闁?*濞戞挸绉撮崯?* `swiperProgress`闁靛棗绋勭槐姘跺Υ?
              //   闁?`.index()` 濞?闂侇偅鍔曢幎姘跺礃?progress"闁衡偓閹勮含濞戞挴鍋撻悹褑娓圭槐鐗堢閹烘梹绁查柟鍨尰閻忥箓鏁?
              //   `Swiper` 闁汇劌瀚弳锝嗐亜闂堟稑鐎奸柟骞垮灪濠€浼寸叕椤愶紕绐?*缂傚牊妲掔换?* index 0 闁归潧绉撮崺?1闁挎稑鐭佺€?index 閻炴凹鍋嗙划锔锯偓瑙勮壘濞?0闁?
              //   swiper 濞村吋淇洪～锕傚箯閽樺绀€闁?闁?闁活潿鍔嶉崺娑㈠冀鐟欏嫭鎷遍柛鎺戞矗缁楀宕氶悧鍫㈡憙閻犲洤绉归妴澶愬Υ?
              //   闁?闁衡偓閻熺増绀€"**濞戞挸绉剁划锔锯偓?index闁挎稑鏈弫濂告偨?`onContentDidScroll` 濡炵懓宕慨?*"闁挎稑鐗愰～鍡樼▔鐎ｎ喗妗ㄩ梺顓ㄧ稻椤斿矂鏁嶆径鍫氬亾?
              //
              // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨喚绠婚幖杈鹃檮缁?* 闁炽儲鏌￠埀?濞?婵繂鐭侀惁婵囥亜闂堟稓娈遍梻鍫涘灪閻ュ懘宕ｅΟ铏规瘓"闁汇劌瀚悧鎾晬?
              // ---------------------------------------------------------------
              // 闁告垵鎼ˇ鈺呮晬濮橆剛绉烘俊妤嬬到閻ｅ墽绮?`_recover/logic-src/婵繂鐭侀惁婵囥亜閸偉鐧侀悘鐐插€搁惃婵嬫椤厾鐟㈡慨婵嗚嫰閹洜鈧姘ㄩ…?md` 閹?.2
              //   闁挎稑鐗撻埀顒佸姈濞碱垳鈧稒顨夋俊顓㈡儘?L189489-189540 缂備焦鍨甸悾楣冩倷?+ L190026-190075 濠㈣泛瀚幃濠囧闯椤帞绀?
              // 閻庤蓱閺?SDK闁挎稑娼塻wiper.d.ts:onContentDidScroll`闁挎稑鐡恠ince 12闁挎稑顧€缁?
              //   "During page scrolling, the ContentDidScrollCallback callback is invoked
              //    for all pages in the viewport **on a frame-by-frame basis**."
              //   `(selectedIndex, index, position, mainAxisLength)`
              //     鐠?`selectedIndex` = 闁告柣鍔庨弫鎯ь嚕閳ь剚鎱ㄧ€ｎ亜顤呴梺顐㈩槷閼垫垿鎯冮崟顖樷偓?
              //     鐠?`index`         = **鐟滅増鎸告晶鐘炽亜?*
              //     鐠?`position`      = 闁告劕鎳庨鎰版儎缁嬫鍤犲☉鎾存闁拌京鎸ф搴′化闁汇劌瀚簺闁告柣鍔嶉惁顔界瑹?
              //
              // 闁哄啰濮烽弲顐︽儍閸曨偒妲遍柣鐐叉濞呮帞绮垫径澶屽箚閻庡湱鍋熼獮鍥晬閸儮鍋撻幇顓熻拫闁绘挆鍕￠柨娑樿嫰閹?闁告瑯浜滃﹢顏呯▔閳ь剚绗熻缂嶅﹥绋夐埀顒勫礌?閺夆晜鐟﹀顖炲礂閹惰姤鏆涢悹浣瑰礃椤撴悂鏁嶆径娑氱獥
              // ```ts
              //   let p = position;
              //   if (index === 0) {              // 闁?闁告瑯浜滃﹢?鐟滅増鎸告晶鐘炽亜閸偅笑闁圭虎鍘介弬浣广亜?閺夆晜鐟ょ粩瀛樼瑹瑜嶇紞濠冪▔閳ь剟宕?
              //     if (p < 0) { p = -p; }        //    鐎垫壋鍋撻柛鎾崇У缁箓寮?position 濞戞捇缂氱粈?闁?缂傚牏绮?
              //     if (p > 1) { p = 1; }         //    濞戞挸锕ら妵娆撳礆?1
              //     this.swiperProgress = p;
              //   }
              // ```
              //   闁?**闁告艾楠稿畷鎰枔绾板绀勬慨婵嗙焷閻︽繃銇勯悽绋夸簼濞戞挴鍋撳〒姘€宥囩濞ｅ洦绻冪€垫梹绋夋繝浣侯伇婵炲棴绱曞▓鎴﹀磹?* 闁?**闁稿绮屽﹢顏勵潰瀹€鍐Г濡炪倕鐏氬?`p` 闁诡厽甯婄拹?1**闁?
              //   閺夆晜鐟﹂婊堝及椤栨稑鐏夊ù鐙€鍏涚粩鎾儎鐎电绻侀柣銊ュ閸嬪懏绋夐鍫濇闁挎稒鑹鹃悾?*濞戞挸绉崇欢椋庢導?闁告瑦鍨归弫鎾存交閸ワ妇顏辨繛鍡磿閺併倝骞嬮柨瀣嫧闁?**闁炽儲鏌￠埀?
              //   闁告瑯浜ｉ々锔姐亜閻㈠憡妗ㄩ柣顏嗗枔濞堟垿宕氶崶顏嗙畺闁告顔婄花锟犳晬鐎瑰常ndex` 閻忓繐褰夌槐浼村矗濡鐏?0/1闁靛棔姊梡` 閻忓繐褰夌槐浼村礆?1闁?
              //
              // 闁瑰瓨鍨冲鎴炴交濞嗗海顏卞〒姘€鍛暠闁规亽鍎茬涵鍫曟晬?*闁告艾濂旂粩瀛樼閸婄噥鍤斿☉鏂款檧缁辨繈宕樺▎蹇撶厒 `lyricMorphT` 濞?*闁挎稑顧€缁?
              //   `lyricMorphT` 閻忓繗椴稿Σ鎼佸嫉椤戣法娉㈤柣?`swiperProgress` 缂佹稑顦悳顖炴偋閳哄绀? = 閻忓繋绶氬鐗堛亜閻㈡浼?/ 1 = 婵繂鐭侀惁婵囥亜閻㈡浼傞柨娑橆檧缁?
              //   闁圭鍋撳ù鐘劤濞插潡骞掗妷锕€惟鐟滅増甯婄粩鎾礌閺嵮勫€甸柣?`p` 闁哥姴鍊荤划鎵偓鐟板枦缁遍亶宕樺鍥ㄦ殸 `syncLyricMorphToPage()` 閻犳劗鍠曢惌?
              //   "闁哄牃鍋撶紓浣哥墦濞笺倕顫㈤姀銏╀紓闁绘劗鎳撶换鈧銈堝吹閻℃垶绂嶆惔锛勭Ъ闁告挸绉归妴澶屸偓鐢垫嚀缁ㄦ煡鎯冮崟顓т紓闁?闁挎稑鐗愬▔鏇熸交?0.5 闁哄啯鍎艰棢濞戞挴鍋撴繛鍡忔缁辨岸濡?
              .onContentDidScroll((_selectedIndex: number, index: number,
                position: number, _mainAxisLength: number): void => {
                this.onSwiperContentDidScroll(index, position);
              })
              // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`onLyricInteract` 闁炽儲鏌￠埀?婵繂鐭侀惁婵嬪礌?*閻熸瑱闄勯幊?*閻忓繘浜堕崳鍝ョ磾椤旈敮鏁勯梻鍌濆蔼椤撴悂寮拋鍦
              //
              // 闁哄啰濮烽弲顐︽焽閿濆嫮顏卞〒姘€宥囩`_recover/logic-src/PlayerPage.abc.txt:6914-6932`闁挎稑顧€缁?
              // ```ts
              //   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
              // ```
              // 闁圭鍊藉ù鍥倷閻熺増韬柛姘湰閺嬪啯绂?`190116-190130`闁?*`TouchType.Down`** 闁归潧绉烽惃鐔兼晬閸粎鐟濋柡?Move/Up闁挎稑顦埀?
              // 闁宠法濯寸粭?闁稿繑濞婇弫顓烆啅椤旂厧鐒奸柨娑欒壘閻?*闁?* `startIdle()`闁?*濞?* `showChrome()`
              //   闁?闁圭鍋撳ù鐘劥缁绘牠鏌岀仦鑲╃槏**濞戞挸绉烽崗?*闁?`touchChrome()`闁挎稑鐗撻崑鍛▔椤忓啰绐楀銈囧劋婢ф粓骞庢繝鍐ㄤ粯闁告帟娉涚亸顖炲船閵堝懎姣夐柡澶堝劵缁辨岸濡?
              // 闁宠法濯寸粭?闁圭鍊藉ù鍥倷瑜版巻鍋撴径濠冭含 `Swiper` 闁兼澘濂旂粭澶愬及?婵繂鐭侀惁婵囥亜閻㈢浜濆☉鎾亾婵☆偊娼ч悺娆撳冀?闁挎稒纰嶅﹢鐗堢?`scheduleChromeAutoHide()`
              //   闁告劕鎳橀崕瀛樻交濡粯绠?`canHideLyricChrome()`闁?*闁告瑯浜滃﹢顏勵潰瀹€鍐Г濡炪倕鍚€鐠愮喖鎯?*闁挎稑顦崇换鏍焼閹剧粯锛?
              //   闁?闁革负鍔岄惃婵嬫閵忋們鈧鎲撮敂鑺ュ殝闁告鍘栨繛鍥╂導閾氬倻鍟婇悹浣插墲濡炲倿宕抽妸銈囩槏**濞戞挸绉崇槐?*闁衡偓閹増宕冲ù鐘侯唺缂嶅秵绋夊鍡愬仾
              //   闁?濞戞挸瀛╁Λ銈夋偩?闁告瑯浜滃﹢顏勵潰瀹€鍐Г濡炪倕鐏氱€?**閻炴稑濂旂拹鐔虹驳婢跺骞?*闁挎稑鐗嗛惃顖炲箰閺嶏妇顏遍悘鐐插€搁悺娆撳冀閹寸姵鐣遍悘鐐靛仦閳ь儸鍥ㄦ嚑闁挎稑顦埀?
              // 闁宠法濯寸粭?`.onTouch` 闁告瑯浜ｉ～鍥┾偓鐢靛枂閳?*濞戞挸绉电粔椋庢嫻?*濞存粌顑勫▎?闁?濞戞挸绉存總鏍传?Swiper 闁煎浜滅换渚€鎯冮崟顒傛嫧闁告柣鍔婇埀?
              .onTouch((event: TouchEvent): void => {
                if (event.type !== TouchType.Down) {
                  return;
                }
                this.onLyricInteract();
              })
              // 闁?闁烩晩鍠楅悥?闁?闁?*闁告帒妫欓弫顔裤亹閹烘垹娼ｉ悹鍥э攻閺?*闁挎稑鐗婃晶婊堝嫉閻戞ɑ鏆滈柨娑橆槴閳ь剚鏌￠埀?閻?`logBranchSurface()` 闁汇劌瀚弫鐐烘煂婵炲簱鍋?
              //   闁圭鍊稿﹢?`Swiper`闁挎稑鐗嗛悾鐘诲矗椤忓嫮鎽犻柛锔哄妺缁剟骞嶇€ｎ偅绨氶弶鈺傜懁缁旀挳寮ㄩ銈囩闁?`.onAppear()` 濞戞挸顭槐?
              //   闁宠法濯寸粭?闁圭鍊稿﹢?`@Builder` 濞达絾鎹囬崳閿嬪濮樿京妞介悹鍥ㄥ灦婵倝鏌ㄥ▎娆戠`does not meet UI component syntax`闁挎稑鏈﹢鐗堟姜椤旇偐鏉芥繛鏉戭儜缁辨岸濡?
              .onAppear((): void => {
                this.logBranchSurface('phone');
              })
              // 闁宠法濯寸粭?閺夆晜鐟╅崳?*濞戞挸绉撮崯鈧?*缂備焦鐟﹂弳锝嗙▔?Swiper 闁?`contentOpacity`闁挎稒纰嶇€垫粓宕ｅ鍥╂そ閻犲洦鍩婄槐婵嬪矗椤忓懏绠?
              //    **閻忓繋绶氬?婵繂鐭侀惁?*闁?闁解偓閹存帞绉撮柟闈涚Т閸ゎ參鎮?闁汇劌瀚崬瀵糕偓鍦缁辨繈鎳?*婵繂鑻幃?婵繂鏈晶婊堟焽閿濆嫮顏遍悶?*閻忕偟鍋樼花顒併亜閼哥數鍩夐梺顓ㄧ导缁旀潙顩?
              //    闁挎稑娼塸ullChromeOpacity` 0.18闁?.62闁挎稑顧€缁辨繄鎲版担鍛婅含闁告柣鍔庨弫鐐交閸モ斁鏌ら梺鎻掕嫰濮樸劌菐閳ュ啿寮抽柕?
              //    闁圭鍋撳ù鐘劚閸ㄥ海鐥缁楀懐绮旀导娆戠獥閻忓繋绶氬?闁?MusicPlayInfoBlock 闁煎浜滅换浣烘暜閿旇偐骞?
              //    婵繂鐭侀惁?闁?闁告艾瀚崵婊堟焽閿濆嫯鈷堝ù?LyricsComponent闁挎稒绋戦惃顒€顫㈠畝鍐Г 闁?MiniLyricLinesComponent闁?
              .onAnimationStart((index: number, targetIndex: number, _event: SwiperAnimationEvent): void => {
                // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*閺夆晜鐟╅崳閿嬬▔瀹ュ懎鏅欏鐟板船婵?`lyricMorphT`** 闁炽儲鏌￠埀?濡炵懓宕慨鈺呭级閸愩劌鍤掑ù婧垮€楃划?
                //   `onContentDidScroll`闁挎稑鐭侀～鍡涘嫉?`Swiper` 濞戞挸锕ラ弻鐔兼焽閿濆棭鍞介梻鈧幐搴㈡殘闂佹彃顭槐姘跺Υ?
                //   闁告鍠愬鍨交濞嗘挸娅￠悹?`animateLyricMorph(...)`闁挎稑鐭侀埀顒€鑻悾鐘垫暜閿曗偓閻Ｑ囧础?
                //   闁靛棗鐣璱ndex === targetIndex` 闁?閻犲搫鐤囩换鍐Υ瀹ヤ礁娅?闁告瑯浜ｉ々锕傚礆閸ヮ兙鈧绋夊鍡樞?濞戞挴鍋撴繛鍡磿濠€鈥愁煥閹存繂袟"
                //   闁挎稑鐗忛埢鍏兼償韫囨挸顕ч柛鎺戞喘閵?/ 闂佹彃绉电€垫洘娼挊澶婄仴濠殿喖顑夐妴澶嬬▔瀹ュ棙笑 0闁挎稑顧€缁辨繈寮弶鎴濡炲鍋犻、?*婵ɑ鐡曠换娆愮▔瀹ュ懏鍎欓柛?*闁?
                //   闁?闁绘粍婢樺﹢顏呮交濞嗘挸娅￠柛娆樹簻娴?*閻犲洤锕ラ弻鍥╂媼閳╁啯娈?*闁挎稑鐗呯换姘舵偩濞嗘埈鍎戦柛蹇ｅ亯椤?`ast=` / `skp=`闁挎稑濂旀禍鎺撶瑹閸噮鍤犳慨锝嗘⒐閺屽﹪寮椤㈡垶绋夐悮瀵哥闁?
                //     闁烩晠鏅茬紞鍛▔鎼淬倗绠婚幖杈剧細缁旀潙顕ョ€ｎ剚鏆?`onSwiperContentDidScroll()` 闁告劕鍟块悾楣冨Υ?
                //   闁宠法濯寸粭?濞ｅ洦绻勯弳鈧弶鈺傜懄椤斿矂寮伴娑欑畳闁规澘绻掑▓鎴︽晬濮橆偆顏诲☉鎾亾 `onContentDidScroll` 闁革负鍔嶉悡鍥ㄧ濞戞瑦绨氶柛銊ヮ儎缁楀倹绋夊鍩挎洟宕ｉ幋顖滅
                //      缂佹鍓欓崣鎾舵偘瀹€鈧▓?`ast=0-1` 閻忓繗椴稿Σ?婵犲﹥鍨垫慨鈺呭炊閻愬墎娈堕悗娑櫭﹢顏呮媴閸℃氨绠婚幖杈剧畱濞叉牜鎷崘褏鐟濋悗娑櫭﹢?闁汇劌瀚惁澶愬箲椤旇　鍋?
                this.diagAnimStart = `${index}-${targetIndex}`;
                if (index === targetIndex && !this.lyricMorphVisible) {
                  this.diagAnimSkip = this.diagAnimSkip + 1;
                }
              })
              .onAnimationEnd((index: number, _event: SwiperAnimationEvent): void => {
                // 闁?A2闁挎稒鐡攚iper 闁煎浜滅换渚€鎯冮崟顒傛嫧闁告柣鍔庣划銊╁级?闁炽儲鏌￠埀?濞戞挸瀛╃拠鐐典沪閸岀儐妫ч悶娑樼灱濞堟垿寮ㄧ捄铏瑰暡闁?*濞戞挶鍊濆Λ鍫曞箵閳╁啫顤?*
                //   闁挎稑娼塴yricSwiperSettled && lyricFlightSettled` 闂侇喛妫勯崺灞剧閸℃ê顤呴柛妤€鎲＄敮鈧?濡炲鍋犻、鎴炵▔?闂侇叏绲肩粩鏉戭浖閿濆繒绀嗛柕?
                //   闁宠法濯寸粭?闁衡偓閻熸澘顤呴弶鈺傜懇閸ｇ兘宕ｉ鍛叺闁哄啨鍎辩换鏃堝Υ?*濞寸姴绨肩粭澶岀磾椤旇崵绉?`lyricSwiperSettled`** 闁?
                //   `finishLyricMorph` 婵ɑ鐡曠换娆愭交濞戞鐟濋柛妯圭串缁辨瑩寮弶鎴婵繂鐭侀惁婵囥亜闂堟稓娈遍梻鍫涘灩閼镐即宕ｅΟ缁樞︽慨婵婂吹濞堟垿鏁嶆径鍫氬亾?
                this.lyricSwiperSettled = true;
                this.finishLyricMorph(this.lyricMorphGen);
                this.diagAnimEnd = `${index}`;
                this.diagAnimEndCount = this.diagAnimEndCount + 1;
                // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁衡偓鐠鸿櫣鍟查柦鈧挊澶屾毎** 闁炽儲鏌￠埀?闁绘挆鍕剶 `onContentDidScroll` 濞戞柨顑呴幃妤勭疀閸涙番鈧繒鎮伴妷褎鐣卞☉鎾亾婵縿鍎荤槐姘舵晬?
                //   `onContentDidScroll` 闂侇偅鍔曢幎姘辩磼濞嗘垶鐣遍柡?*婵絾鏌х欢?*闁挎稑鏈〒鍫曞触鎼存繄顏遍悽顖嗗嫭寮撻煫鍥ф噺椤掓粍绺介懞銉π?0/1
                //   闁挎稑鐗嗛悿鍕圭€ｎ亞鍩楅悷?0.997 閺夆晜鐟ч～鎺楁晬婢舵稓骞㈤柤?`syncLyricMorphToPage()` 濮掓稒顭堥缁樺?*閻犱讲鏅欑紞鍛磼濞嗘劗娉婇柛?*
                //   闁挎稑娼塖CROLL_SETTLE_WINDOW_MS` 闂侇叏缍佹禍鍓х玻濡ゅ绀嗛柨娑樻湰婢у秵绂掗妷锔炬硦闁告柣鍔嬬粩鎾磻濠婂啯鐨戦悷鏇氱劍濠€浣圭閻戞ê惟 `t` 闁解偓閽樺鏆伴柛鎺撳椤忣剟鎮欓獮搴撳亾?
                //   `onAnimationEnd` 婵繐绲惧Σ?swiper 闁稿绮庤彊"闁汇劌瀚悾濂稿棘闁稐绻嗛柛娆忓殩缁辨瑦绋夐弬璺ㄦ暔闁哄牃鍋撶紓?`index`闁挎稑顦埀?
                //   闁宠法濯寸粭?濡炪倕鎼花顓㈡晬?*闁?*闁?`index` 濞ｅ浂鍠楅?`playbackSwiperIndex`闁?*闁?*闁解偓閽樺鏆?
                //      闁挎稑鐗嗛幆渚€宕?`want` 濞村吋姘ㄩ弫銈夊籍瑜忛崒銊ヮ嚕閺囩姷鏆柨娑橆槶閳?
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
                // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽焽閿濆嫰鍤?`onChange` 娴?闁汇劌瀚伴埀顒佸姇閻⊙呯磼閹惧鈧?* 闁炽儲鏌￠埀?闁告鍠愬鐢稿及椤栨稒锟ラ柡澶嗏偓鍙夘偨 `touchChrome()`闁?
                //   闁哄啰濮烽弲顐︽晬閸у垳recover/logic-src/PlayerPage.abc.txt:23189-23215`闁挎稑顧€缁?
                // ```
                //   const v = 1;
                //   if (index === v) { startIdle(); }            // 婵繂鐭侀惁婵囥亜绾板绐楅柛娆樹海閹癸絿绮氬ú顏咃紳閻犱讲鍓濆?
                //   else { clearIdle(); showChrome(); }          // 閻忓繋绶氬鐗堛亜绾板绐楅柛瀣矎椤撴悂寮?+ 闁哥偑鍊曢崵顓㈠箳瑜嶉崺妤呭礌?
                //   this.atLyricScreen = (index === v);
                // ```
                //   闁?濞戞挶鍊撻柌婊堝礂閹惰姤鏆涚€瑰壊鍠栭崺鍡涙晬閸儱鍘撮悶姘煎亝閸ㄦ粍绂掗鈧敮顐﹀级閵夆晛浜濋柛?`touchChrome()` 闁规儼顫夌敮鈧ù婊冩４缁辨岸鏁?
                //     闁?闁告帒娲ら崺?*婵繂鐭侀惁婵囥亜?*濞戞挸绉撮弫婊堝礄閻戞ê浠橀柛鎺曟硾鐏忣垶鏁嶉崸鍓噊uchChrome()` 濞村吋鑹鹃弫婊堝礄閻氬绀嗛柨?
                //     闁?闁告帒娲ら崺?*閻忓繋绶氬鐗堛亜?*閻?*闁哄嫭鍎崇槐锟犲船閵堝懎姣?*妤?*闁稿绮嶇敮鈧?*缂佸本妞藉Λ鐣屾媼閳╁啯顦?
                //        闁挎稑娼塼ouchChrome()` 闁?闁稿繐鐗愰幑锝囨媼閳╁啯顦ч柛鎰Т娴犵娀骞?闁挎稑鑻崳锝夊极閸喓浜柛姘焿缁辨繃鎷呴崱妤冩瘜濞存粌妫濋崑鍛村级闄囬銏＄▕婢舵稓绀嗛柕?
                this.onSwiperIndexChanged(index);
              })

              // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*闁硅矇鍐ㄧ厬闁告牞妗ㄧ粭浣糕枔閻㈢數娉㈤柡瀣濞堟垶绋夐妶鍡欏闁告濮崇紞鍛村级?*闁?
              //   闁哄啰濮烽弲?overlay 闁?`Swiper` 濞?閺夆晜绋戠€规娊寮?濞磋偐濮剧欢顓㈠级?濞戞柨顑夊Λ璺ㄤ焊鏉堛劍笑閺夆晜鐟ょ悮閬嶅冀?*闂傚棜娉涢崬瀵糕偓?Row**
              //   闁挎稑娼墂ujie.pa:190464` / `190497`闁挎稑顧€缁辨繃绋夊鍡樞?padding闁?
              //     `[Swiper | gapSwiper 閻?| gapScrub 閻?| 閺夆晜绋戠€规娊寮?濞磋偐濮剧欢顓㈠级椤☆枽
              //   闁?`gapSwiper` 閻?*閺夆晝鍋熼悽?*闁稿浚鍓欑槐?`playerSwiperGapOf(usableH) = clamp(0.065閼寸牪,16,56)`
              //      闁挎稑娼墂ujie.pa:93497`闁挎稑顦埀顒佹煛閳?**濞戞挸绉靛Σ鎼佸蓟閵夛负鈧倹鎷呭鍫涒偓?*闁挎稑鐗愰妴鍐煂瀹€鍕簼 48/32/20 闁告瑯浜滃﹢?婵炲备鍓濆﹢浣衡偓鍦仦缁?
              //      `usableH` 闁哄啳鍩栨晶鐘绘偨?闁挎稑鐭侀～?`playerChromeTotalOf` 闁汇劌瀚悮杈ㄥ緞閸曨剙鐏囬悗浣冾潐瀹曟煡宕愮涵椋庣闁?
              //   闁?`gapScrub` 闁哄嫷鍨遍悡锛勬偘閵娿儮鍋撶涵椋庣濞达絽妫欓崹婊勭椤掑啰绠瑰☉鎾亾濞?*鐎规瓕灏欑划?*闁哄牆顦幃鎾寸▔閳ь剙鈻撻悽鍛婏紵閻犵儤绻愮槐妾侰ontrolAreaComponent`
              //      闂?Slider 闂侇叏绲肩粩瀵告偘瀹€鈧▓?`bottom` margin闁挎稑顦崳?閺夆晜鐟╅崳椋庣磼?0闁挎稑鐭傛导鈺呭礂瀹ュ懏鍊卞☉鎾亾婵炲牆鍚€鐞氶亶寮堕垾鍐茬稉鐎垫澘瀚哥槐?
              //      闁稿繐鐗忛弫銈夊籍閵夈儳绠堕柟?閻庡湱鍋炵粊?vs `gapScrub`"闂佹彃绻愰崵顓㈠级閵夘垳绀勯悷?`chromeScrubGapRowHVp()`闁挎稑顦埀?
              //   闁宠法濯寸粭?濞戞挶鍊栭悧鎾焾閼恒儲笑 `Row()`闁挎稑鐗呯粭澶愬及?`Blank()`闁挎稑顧€缁变即寮悩鍨珪閻忓繗椴稿Σ?`Row`闁挎稑濂旂粭鏍矚?`Row` 闁?`Column`
              //      闂佹彃鏈€?`.height()` 缂侇喖澧介垾姗€宕￠悩杈╃Т闁挎稑濂旂粭澶嬪濮橆剙鍓?`Blank` 闂侇叏绲鹃悧閬嶅触閸愩劌鈷栧ù锝嗙懅閳规牠姊诲ǎ顑藉亾?
              Row() {
              }
              .id(PlaybackPage.SWIPER_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.swiperGapRowHVp())
              .hitTestBehavior(HitTestMode.None)
              // 閳藉應妲勯埥?2026-10-17閿?*閹跺﹥甯堕崚璺哄隘閻ㄥ嫮婀＄€圭偘绗傚▽鍧楀櫤娑撳娼?* 閳ユ柡鈧?閺嶅洭顣界悰宀勬尭閸掓儼顩﹂悽銊ョ暊閿?
              //   鏉╂瑤绔撮弽鐟版皑閺?閹貉冨煑閸栫儤顒滄稉濠冩煙"閻ㄥ嫬宕版担宥嗘蒋 閳?鐎瑰啰娈戠粣妤€褰涙い鎯扮珶 = 閹貉冨煑閸栬桨绗傚▽瑁も偓?
              //   閳跨媴绗?韫囧懘銆忛崘娆掔箻 `@Trace`/`@Local`閿涙岸鍣洪崚棰佺閸氬氦顩?*鐟欙箑褰傛稉鈧▎锟犲櫢瀵?*閿?
              //     閸氾箑鍨?`metaOffsetY()` 闁插矂鍋呭▎锟犳尭閸掑墎鏁ら惃鍕Ц"鏉╂ɑ鐥呴柌蹇撳煂"閻ㄥ嫬鍘规惔鏇熷腹缁犳鈧?閳?瑜般垹鎮撳▽鈥充粵
              //     閿涘牐绻栧锝嗘Ц娑撳﹣绔撮悧?闁藉啿鍩楀▽锛勬晸閺?閻ㄥ嫬甯崶鐙呯礆閵?
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

              // 闁硅矇鍐ㄧ厬闁告牜灏ㄧ槐浼存濞嗘劦鍓?3 缂佸甯熼崵婊堝礉閵婏附鏆悹褍鍤栫槐婵嬫倷?缁句即顣﹂幑銏ゅ箛韫囨搩妲遍柛鐐€曢崵顓㈡晬閸繍鍤犻柡宥呮处濡倝鎮惧畝鍕従濞?BarCollapse闁?
              Column() {
                Column() {
                  // 闁宠棄鎳夊Σ?2026-10-15 闁活潿鍔嶉崺娑氣偓瑙勪亢閻ㄧ喖鏁嶅銉㈠亾?*閺夆晜绋戠€规娊寮堕垾铏濞戞挸顑夊浼存儍閸曨垰浜濋柛顐㈡鐎垫粓鏌﹂鑽ゎ伇閻犙呭厴椤ワ綁宕?*闁靛棗绉埀顒佹煛閳?
                  //   閻庣懓鍟╁鎴﹀及椤栨瑧顏辩紓浣稿缁变即寮€电顣婚柟璨夊啫鐓戦柛鏍ф惈濠€?*闁告艾濂旂粩瀛樼▔椤忓懏顦ч梻鍌氼嚟閻?*闂佹彃濂旂划鐘崇▔鐎ｎ亜纾冲☉鎾筹攻濞肩敻鏁嶉崼锝庢綄 `contentRiseVp()`闁挎稑顧€缁?
                  //   闁圭鍋撳ù鐘劥缁绘牠鏌?*濞戞挸绉撮崯鈧?*缂備焦鐟ㄧ换妯绘償閿旇姤钂嬮柛妤佹礈鐎氼參鏌ㄥ▎蹇撴Щ闁挎稑鐗呯粭鍌涚▔閳ь剟鎮ч崼婵囩殤闁哄嫷鍨堕崑鍛▕閸繀绮甸梺鎸庣懅濞堟垿鏁嶆径鍫氬亾?
                  ControlAreaComponent({
                    // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*濞戞挸绉烽々?*闂侇叏绲肩粩瀵告偘?濞戞挸顑堝ù?閻犲洤瀚?闁哄洦娼欓ˇ?闁?
                    //   闁哄啰濮烽弲顐︽儍?`transport` 闁告瑯浜濆﹢?5 濞戞搩浜风槐浼村箻椤撶喐鏉规俊顖椻偓宕囩 / 濞戞挸锕ｇ粩瀛橈純?/ 闁圭虎鍘介弬渚€寮抽崒姘不 / 濞戞挸顑勭粩瀛橈純?/ 闁圭虎鍘介弬渚€姊奸悢宄扮仚
                    //   闁挎稑娼塒layerPage閻庣懓鏈弳顤汭閻庤姘ㄩ…?md` 閹?.3闁挎稑鐭傞埀顒佸姍閵嗗秹鏌堥挊澶嬭含闁挎稑顧€缁?*婵炲备鍓濆﹢浣虹箔椤戣法鐧岄悶?*闁?
                    //   婵炴煡绠栭悡鑸靛緞濮橆剙姣夐柡澶堝劤濞堟垶娼诲▎搴ｎ伇閻炴稑鑻﹢顏堝箣椤忓嫭绂堥梺鎻掑缁旀挳鎯囬悡搴¤閻?闁?闁稿繗娅曠敮鈧悗鐟板暞婢х娀寮?闁绘挆鍕剶"闁?
                    //   闁宠法濯寸粭?闂侇叏绲藉ú鎾寸▔椤忓嫬寮抽柛娆欑稻濠€浼寸叕椤愶絿姊鹃柛鎺斿缁辨獋ControlAreaComponent` 闂佹彃濂旂划娑㈠捶椤帞绀嗛柨?
                    //      閻熸洑鐒︽禒顔藉緞瀹ュ棗惟閺夆晜鐟╅崳鐑藉绩閻熺増绀€ `true` 闁告鍟胯ぐ鏌ュΥ?
                    showBottomOtherRow: false,
                    // 闁?闁兼寧绮屽畷鐔兼偐閼哥鍋撴担绋垮殥闁圭粯鍔曞畷宀勫礆閻楀牊鎷卞銈囶暜缁辨瑩鏌囬敐鍕伇婵☆垼浜ｉ、鎴︽儍閸曗斁鍋撶仦鐐函濠㈣埖鍝庨埀顒€绉村ù姗€寮介崶褎韬柡鍫墴閵嗗鏁嶆径娑氱獥
                    //   `ControlAreaComponent` 濞?`@Local` 闁衡偓鐟欏嫬鐏囧ù?`@Param` + `@Event`闁?
                    showMenuSheet: this.playMenuOpen,
                    onMenuSheetChange: (open: boolean): void => {
                      this.playMenuOpen = open;
                    },
                    // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`hideChrome()` 闁?闂傚牄鍨哄妯侯嚕閳ь剟鎯堥埀顒備焊閸欐鐟濋柡鈧?閻庣懓鐗嗗畷濂告晬婢舵稓绐?
                    //   闁兼寧绮屽畷?sheet 鐎规瓕灏欓弫杈ㄧ▔婵犲洦妗ㄩ梺顓ㄧ导缁斿鈧潧婀卞﹢鍛嚗濡ゅ嫷娼岄柨?*闁稿繑婀圭紞鎴炵▔閵堝嫰鍤嬬€殿喚鎳撻惇?*闁挎稑鐗婇幐閬嶅绩妤ｅ啯袝闁?/ 闁稿繑婀圭划顒勬偋閸喐鎷遍柨?
                    //   闁革负鍔嶅﹢鎵磼閸曨亝顐介柛鎰嚇閸庢挳鏁嶇仦绛嬪晱濞戞捁宕靛﹢鍛▔瀹ュ懎鐓?闁?闁汇垼绮剧换鏍ㄧ▔椤忓嫭绀€閻犲鍟慨銈嗙▔婵犲啯闄嶉柨娑樿嫰閼荤喐娼诲☉娆愭毆閻犙呭厴濡剟鏁嶉崼锝庢綄 `auxSheetOpen`闁挎稑顦埀?
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
              // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗嗗ú鏍焻閳ь剟宕ユ惔銊ユ闁稿鐔槐姘舵偨閵婏箑鐓曢悗瑙勪亢閻ㄧ喖鏁嶅銉㈠亾?*濞戞挸绉烽々锕€菐閳ュ啿寮虫繛锝傗偓鍐叉瘔**闁靛棗绉埀顒佹煛閳?
              //   闁硅矇鍐ㄧ厬闁告牞妗ㄧ粭澶愬礃瀹ュ娴嗛梺顐㈢箲濡叉垶鎯旈敃鈧崵顓㈠捶閻氬绀勯柛妯煎枑濞煎灚娼诲▎鎾虫闁?`.opacity(pullBottomIn())`闁挎稑顧€缁?
              //   闁衡偓鐟欏嫬鐏?*濞寸姴绨肩粭鍛村础閸ヮ亝宕抽柣銊ュ缂嶅懐绮?*闁挎稒纰嶉弳锝夋偋閸ャ劌浠橀柛鎺曟硾鐏忣垶宕烽妸銊ユ鐎规瓕浜▓鎴﹀籍閸洘锛熺紒鎰殔閸炲瓨绂掓惔婵堢憮闁?180vp 闁告娲ら崺灞炬媴瀹ュ繒绀?
              //   濞戞挶鍊楃划宥夋儍閸曨偄甯ラ柛姘唉椤?PlaybackPage 濡炪倕鐖奸崕鎾儍?`WIN_A_*` / `WIN_B_*` 閻犲洤鐡ㄥΣ鎴﹀Υ?
              //   闂傚牊鐟﹂娑㈠箑娴ｉ绉寸紒澶岀帛娴?0闁挎稑娼塵orphClipping()` 濞戞挸鎼禍锝夊籍閸撲焦绾柟鎭掑劥缁绘垿宕?0闁挎稑顦崳?闁绘鐗撳浼存焻閹邦剙鍓肩紒杈╁С缁楀宕ｅΟ绯曞亾?
              .translate({ y: this.expandState.contentRiseVp() })
              .onTouch((event: TouchEvent): void => {
                this.touchChrome();
                // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*闁归攱鐗曟慨鈺呭箳瑜嶉崺妤呭级閳╁啯鏆悹?/ 閻忕偞娲栫槐?*闁挎稑娼塀arCollapse`闁挎稑顦埀?
                //   闁哄啰濮烽弲?`design/src/main/ets/logic/BarCollapse.ets` 闁汇劌瀚晶婊堝礉鐠恒劌笑闁诡兛鐒﹀┃鈧?
                //   闁挎稑鐗嗛悺褔鎳為崒婊呭灣 `wujie.pa:83706-84140`闁挎稑顦崙锟犳焻閹邦厽钂嬮弶鐑嗗墮閸熸捇宕?
                //   `common/musicbasic/.../model/BarCollapse.ets`闁挎稑鐭佺换鏍煂鐏炶棄娑ч柡鍕靛灡婵″摜鎲撮敂鑺ュ殝濞存粌顑勫▎銏ゅ窗閸屾粎鑸堕悗鐟板暔閳?
                //   闁宠法濯寸粭?閻庣懓鍟ぐ褏鎷犻崱妤€鐒?*缂侀箖娼ч幃?*闁归潧顑呮繛宥夋晬閸唻顓㈠触閹达附鏁氶悗瑙勮壘閹寮紙鐘侯洬闊洨鏅弳鎰版晬婢跺棗娅?濞戞挸绉崇槐浼村椽鐏炲墽鎽冮悹鍥хУ閾嗛柛姘灦缁箓宕濋妸锕€鈪甸柡瀣堪閳?
                this.onChromeBarTouch(event);
              })
              // Full player collapse retains its existing path; lyric hide reclaims layout continuously.
              .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
          }
          // 缂備胶鍠嶇粩?TopArea闁挎稑鐗嗗畷鐔哥▔閳ь剛鈧湱鍋樼欢銉╂晬鐏炶棄缍岄柛鏃傚С缁剟宕橀崨顓у晣濞戞柨顑勭粭鍌炴晬鐏炶棄鐎奸柟骞垮灪閺屽洭鎮欑憴鍕槯濞戞挸绉归弨銏犘掓笟鈧崳绋款嚈閻氬绀?
          TopAreaComponent({
            isShowPlay: this.state.isShowPlay,
            onBackClick: (): void => {
              // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨偄褰犻梻鍌ゅ幖閸ㄥ骸霉?* 闁炽儲鏌￠埀?闁活潿鍔嶉崺娑㈠Υ瀹€鈧柈瀵哥磼閻旇崵绠查柛?闁稿繑濞婂Λ鎾箰婢舵劖灏﹂柡鍕靛灠閸樻稑顭ㄩ幋婊咁伇婵炲牓娼ч崯鈧瀣仜濞叉牠宕㈠Ч鍥ｅ亾瀹ュ繒绀?
              //   闁哄啰濮烽弲顐︽晬濮樿埖濮滈柟闈涱儏婵炲秹宕楅幎鑺ワ紨闁挎稑鐗愮换鎴﹀炊?/ 闁稿繑濞婂Λ鎾箰婢舵劖灏﹂柨娑橆槼閾?`closeWithAnimation()` = **闁瑰嘲绉撮幓鈺呮偂瑜忕紓澶愬礆閹峰苯鍘￠柛?*闁?
              //        闁汇垹顭峰浼村冀鐟欏嫭鎷卞☉?婵?闁?*婵炴彃顭烽妴澶庛亹閵忕姴缍侀柛娆樹簽閺嗏偓缂備焦鐟ょ粭鍛村箯婢跺顤侀柛?*闁挎稑娼塷nReverseMorph`闁挎稑顦埀?
              //   闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉弶鈺傜懇閸ｇ兘鎯勭€涙ê澶?`closeFullScreenPlayback()`闁? 婵炴彃顭烽妴澶庛亹閵忕姴缍侀柨娑橆槴閸?濡炪倗鏁诲浼村礂閸喓鎷ㄥ☉鎾亾婵炲牏顣槐?
              //        闁告劕绉堕弫杈ㄧ珶閸愯尙婀撮梺顓ㄧ导缁旀潙螞閹烘妫ч柛銉у仜楠?闁?閻忓繗椴稿Σ鍛婃媴閻樺灚绠欓柛鎺撳濞?闁稿繐鐗婄划锔界▔閳ь剙鈻撶喊澶岀闁绘帟娉涢幃妤呭礃瀹ュ妫ч柛銉у仜楠?闁?
              //   闁宠法濯寸粭?`closeWithAnimation()` 闁煎浜滈悽顐ｇ▔閵堝洭鐛撻柛蹇旂矊缁ㄦ娊鏁嶉崼锝呭帯闁搞儱锕﹂悡鈺勩亹?缂佹劖顨呰ぐ娑氫焊閸濆嫷鍤熷☉鎾崇Т瑜版煡鎮介妸锝傚亾娴ｅ憡褰ラ柣鎾楀啨浜奸悹鎰╁劵缁?
              //     闁?闂侇喗鍨濈粭澶嬪濮橆厼惟闁圭虎鍘介弬浣广亜闂堟稑骞㈠ù锝呯箞閳?
              this.closeWithAnimation();
            }
          })
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding')
            })
            .zIndex(2)
            // 濡炪倛鍩栭悥顕€鏁嶅顒€鍐€缂傚倹鐗為惁?`pullChromeOpacity = clamp((effT-0.18)/0.44)`闁?.18 闁?0.62 婵烇絺鈧啿寮?
            //闁?闁圭顦甸幐铏▕閻斿憡笑闁革负鍔屾慨鈺呮偨閺勫繒绠栫紒瀣儏濮樸劑宕欓搹鐟扮疀濞?閻忓繗椴稿Σ鍛婃交濞嗗海顏遍悘鐐插€归惁顔芥償閺囩喓鍩夐柡鍐ｆ櫅缁惰鲸寰勫鍓х
            .opacity(this.expandState.pullChromeOpacity())
            .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辩増銇勯悽鍛婃〃濞撴皜鍐ㄥ綘闂傚偆鍘芥晶婊堝礉鐠恒劍鐣?*缂佹鍏涚花鈺傜▔椤忓懎鐦弶鐐垫櫕閸?*闁?
            //   闁哄啰濮烽弲顐︽儍閸曨偄褰犻梻鍌ゅ幗婢ф粓宕濋幐搴＄槸濞?*濞戞挶鍊曢ˇ?*闁挎稑娼塤recover/logic-src/鐎殿喒鍋撻柛蹇氭珪閹搁亶寮ㄩ幆褎鐝?闁归潧顑呮繛宥囨崉椤栨氨绐為悗瑙勬皑椤?md`
            //   閹?.1 闁?闁?濞?闁宠翰鍎荤槐姘舵晬?
            //     闁?`PlayerPage` 濡炪倕鐖奸崕鎾焽閿濆棙钂?Row闁挎稑娼塒anDirection.Down`, `distance:8`闁挎稑顦崯?**濞戞捁顕ч崣鍡涘矗?*
            //     闁?闁告劕鎳庨鎰偓鍦嚀濞?
            //   闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉柛娆樹簼濠€?闁轰焦鎸抽妴澶愬冀?闂侇叏绲肩粩瀛樺緞閸曞墎绀勯柍顔肩墐閹冲啴鏁嶆径鍫氬亾閸屾績鍋撶仦鐐濡炪倕鐏氶悧瀛樼▔婵犲嫭鐣辩紒鏃€鐗滃ú鍧楀箯閺嵮冃?*濞村吋淇洪～锕傚礃閸涙潙鍔?
            //   闁告瑯鍨辩划鎾礉?/ 閻庢稒鍔栨晶婊堝礉閸喖甯ラ柛姘暞鐢偓**闁挎稑婀弐kUI 闁归潧顑呮繛宥夊礃閹烘挸婧€闁挎稒鑹鹃悺娆撴嚍閸屾粌浠ù鍏济崢娑㈡晬婢跺棗娅?
            //   闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳濡寸仦鍓ф⒕婵炲娲戠粭鍛村箯婢跺﹤褰犻梻鍌ゅ幗閹搁亶寮ㄩ幆褎鐝ら柕鍡楃Р閳?
            //   濡炪倛鍩栭悥顔芥交濞嗗海顏遍柡澶嗗墲濡?*闂傚牏鍋炵划鎾礉閵娧勭暠闁搞儱鎼悾楣冨级閳ュ磭鏁?*闁靛棔绀佺换鈧悗瑙勭閺佺懓顕ュΔ鈧崺宀€绮╅弽顐ｇ函闁归攱鐗曟慨?闁?閻炴稏鍎扮粭鍌溾偓鐟板枦缁辨繃绋夋惔銏★骏闁伙絽鑻幃鎾诲几閸曗斁鍋?
            //   闁?缂佺虎鍨伴·鍐煂韫囧鍋撴担椋庣憹闁衡偓闁稒宕插ù锝嗘礃濡箓寮垫径搴斀濞戞挾灏ㄧ槐浼村川閹存帟鍘柣銊ュ缁绘洟寮伴姘€卞☉鎾亾濞?`onDismissDrag()`闁?
            //      闁告瑯浜濆﹢?閻犙囨敱婢ф粓鎷冮挊澶嬭含濡炪倛鍩栭悥顔界▔?闁哄啳鍩栨晶鐘绘偨閸楃偟鏆婇柟鎭掑劤椤撴悂鏁嶉崸?gesture()` 閻庢稒鍔樻俊顓㈡倷闁稓鍠橀柛蹇撶墳缁辨岸鏁?
            //      濡炪倗鏁诲浼村礂鐠鸿櫣鏆婇柛鏍ф惈閻撴瑩鎯冮崟顒侊紗闁哄牆顦抽、鎴炵▔鏉炴壆顏遍悗娑欍仦缁楀宕ｅΟ绯曞亾?
            //   闁宠法濯寸粭?濞戞挶鍊曢ˇ鈺傘亜閼哥數鍩夐悗鍦仒缁躲儵鏁嶉崼鐔告嫳濠?+ 濞戞挸顑夊?`!panelLayout` 闂侇叏绲鹃弫顕€鏁?*闊洤鎳橀妴蹇涙焾閼恒儱鐦?* 闁炽儲鏌￠埀?
            //      闁告熬绠戦崹顖滀焊鏉堛劍笑 閹?6.1.6 / 閹?6.16 闂侇叏绲奸柌婊堝Υ鐏炶姤鍊卞☉鎾亾鐟滆埇鍨绘慨鎼佸嫉?N 濠㈣泛瀚ㄩ埀顑跨瑜把囧绩闁稓鍟婂☉鎾亾濠㈣泛瀚ㄩ埀顒€绉跺▓鎴︽嚀娴ｅ湱妯呴柣銉ユ噷閳?
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
    // 闁宠法濯寸粭?閺夆晜鐟╅崳鐑芥晬閸у垺uildControlStack` 闁汇劌瀚悧鎾晬?*濞戞挸绉烽々?*闁告劕绉剁划?`backgroundColor(imageColor)`闁?
    //    閻庣懓鍟Σ鍛婄▔閳ь剛浠?*闁诡厽甯婄粭澶愭焻韫囨梹顫?*闁汇劌瀚ぐ鍥嚌閹绘帞淇洪柨娑樻綁imageColor` 闁?alpha 闁?0.4闁挎稑濂旂徊鐐償閺団€愁棌闁哄牜鍓濋棅鈺呮晬?
    //    闁炽儲鏌￠埀?鐟滆埇鍨硅ぐ澶愬嫉閻斿吋锛熼悷浣风婢光偓缂佹劖顨呰ぐ娑㈠矗椤忓懏绠掑☉鎾亾閻忓繐绻愬锟犳晬鐏炵晫鏆婂ù鍏间亢缁绘盯宕ュ畝鈧悰銉╁矗閿濆嫮顏遍悹褔鏀辨俊鍛婄▔鐎ｎ喗妗ㄩ柣銊ュ椤╃粯銇勯悽鐢邓囬柟鍝勵檧缁?
    //    闁告劕绉存慨鐐哄礃閸涙潙鍔ラ梺顓ㄧ到閻増娼婚幋锔炬嫧閹煎瓨娲濇竟濠囨晬瀹€鍐炬綆闁规壆鍠庡銊╁及?閻忕偞娲栫槐鎴炵▔椤撯€冲壒闁哄拋鍨卞Σ鍛婎渶閹寸姵鐣?闁?
    //    闁煎啿鏈▍娆撴嚌闊厾顏辩€垫澘顑囬弫杈ㄧ▔婵犲洦妗?*閻㈩垽闄勭拹浼村礂閵壯呭炊闁?*闁汇劌瀚悮杈╀沪閸屾繄顦伴悹鎰剁秶缁辨瑦鎯旈弴鈥愁棌 + 闁告瑦鐗炴竟濠勪沪閸岋妇绀嗛柨娑樼焷缁绘牠鏌岀仦鑲╃闁归晲绶氶埀顒€绻戝Σ鎴﹀Υ?
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
            // 闁?闁告艾鑻鏃備沪韫囨稑浜濆璺哄缁变即鎸婅箛鏂跨 `LyricsComponent` 闁煎浜滈悽顐ゆ偘閵娿儯浠堥柨娑樼墛濡倝鎮剧仦鍓ф⒕闁哄牆顦悾鐘绘晬婢跺牃鍋?
            //   闁哄牜鍓欓崹搴ㄥ绩椤栨瑧鐟愰梻?L2233 闁?`MusicPlayInfoBlock` 鐎规瓕灏欑划锟犲捶閵婏附鈻旂紒鈧崫鍕闂?+ 婵繂鑻幃?+ 婵繂鏈晶?
            //   闁?濞戞挸绉峰Λ宀€浜告潏銊π?闁告艾濂旂粩瀛橈純閺嶃劎鎽冮柛姘Т閸ゎ參鎮虫０浣解拡婵?闁靛棗鍊搁悾顒勫极鐎靛憡鍊為柣銏ｇ簿椤?L1926 闂侇叏绲介ˇ鈺呮儍閸曨剚鏆堥梺鎻掝焾閳?
            hideLyricsMetaHeader: true,
            onSeekTime: (ms: number): void => {
              MediaService.getInstance().seek(ms);
            }
          })
        }
        .layoutWeight(1)
        // 婵繂鐭侀惁婵堜沪閻愭壆鑹?闁告劕鎳庨?闁挎稒鐡猚ontentOpacity`闁挎稑鐗愰幆銈嗘媴瀹ュ棗顤呯紓?1闁?
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
      // 闁?闁烩晩鍠楅悥?闁?闁?*闁告帒妫欓弫顔裤亹閹烘垹娼ｉ悹鍥э攻閺?*闁挎稑鐗撳浼村级閹稿孩鏆滈柨娑橆槴閳ь剚鏌￠埀?濞戞挸楠搁鏃備沪韫囨稑浜濆璺哄閸ㄦ氨鈧數娅㈢槐婵嬫偠閸℃瑦鏆犻悷娆庣閻ｇ姵绋夋繝鍥ㄦ〃闁汇劌瀚弫鐐烘煂婵炲簱鍋?
      .onAppear((): void => {
        this.logBranchSurface('panel');
      })

      if (!this.panelLayout) {
        TopAreaComponent({
          isShowPlay: this.state.isShowPlay,
          onBackClick: (): void => {
            // 闁?闁告艾濂旂粭鍌炴晬閸垹寮鹃柟纰卞墯濡倝鎮惧畝瀣獥闂傚牏鍋炴晶婊堝礉閸喖褰犻梻?= 闊浂鍋嗛崣搴ㄥ绩閸撲胶绱氶柨娑樺缁楀寮伴娑欍仧濡炪倝娼ч懜浼村矗濮楀牏绀?
            this.closeWithAnimation();
          }
        })
          .padding({
            left: 56,
            right: 56
          })
          .zIndex(2)
          .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
          // 闁?闁告艾濂旂粭鍌炴閵忋倕浜濆璺哄閵嗗﹪寮借箛銉х獥濡炪倗鏁诲鐗堢瑹瑜嶉崣褔姊婚鐔奉杹闁告棁娉曞▓鎴犵箔椤戣法鐧屽☉鎿冧簼鐎垫洘娼悾灞戒化闁挎稑鐗嗛顕€寮介崶銊︼骏闁?闁?濡炪倕鐖奸崕?Row闁挎稑顦埀?
          //   闁宠法濯寸粭?閺夆晜鐟ょ粩瀛樺緞?*闊洤鎳橀妴蹇旂▔鎼存繄鐟愰梻鍫涘灲閸嬪懏寰勯崟顒€鐏囬悗鐢垫嚀閻°劑宕?*闁挎稑鐬奸幃濠囨偨閸欐鐟㈤悗鐟版湰閺嗭絿鎷犵€涙ɑ顫栭悷娆庢缁楀倿妫冮姀銈呬簼婵炲牆鐏氶弫鐐烘煂婵炲簱鍋?
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

  // 闁宠法濯寸粭?2026-10-17闁挎稒淇虹换鏍煂鐏炶棄鏂ч柡澶堝劥缁绘洟寮垫径澶岊伇濞?`applyWindowSafeAreas()` 闁炽儲鏌￠埀?**鐎瑰憡褰冮崹褰掓⒔?*闁?
  //   閻庣懓鍟╃粭灞剧▔鐎ｎ喗妗ㄩ梺顓ㄧ导闁?*婵炶尪宕靛鍐儍?* `applyPlaybackWindowChromeImmediately()`闁挎稑鐗嗛弫顔界▔閳ь剛鎷崘顏呮殢闁?:5534闁?
  //   闁?*闁告艾濂旂粩瀛樼閺堢數鐨戦柣銊ュ鐞氳鲸绺藉Δ鈧崯鎾斥枖?*闁挎稑鑻ぐ褍顔忛鑽ゎ伇闁?`applyPlaybackNavigationBarColor(true)`
  //   闁?闂傚棙鍎奸惃鐔兼偨閵娧冧化闁靛棔鑳堕弳鈧柣顐熷亾閻忓繗椴稿Σ?闁衡偓瑜版帗鏅╅柛锔惧閺?闁汇劌瀚崣鍡涘矗閿濆繒绀勯柡鍫厸缁劌顔忛懠顒傜梾濞戞捇缂氱换鏍ㄧ▔椤忓嫯鍩岄柣妯挎硾閹棙娼婚崶褋鍋ㄩ柛鎴犲У椤愬吋绂嶈箛銉х闁?
  //   闁?闁活亞鍠曢々锕傚绩鐟欏嫭灏￠柡鈧ィ鍐︹偓澶愭儍閸曨厾宕堕柛娆欑秬椤ュ﹥顨滅敮顔剧**闁告瑯浜濋弫鍏肩▔鐎ｎ喗妗ㄩ梺顓ㄧ导缁斿瓨绋?*闁?

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
   * 閳藉應妲勯埥鍛 2026-10-17閿?*鐠恒劑銆夐棃銏㈢秹閺嶅吋绨紓鎾崇摠** 閳ユ柡鈧?娣囶喓鈧苯鐫嶅鈧惃鍕閸婃瑦妲搁拑婵婂閵嗗稄绱?
   *
   * ## 娑撹桨绮堟稊鍫濈潔瀵偓閺冭埖妲搁拑婵婂
   *   閺冪姷鏅柇锝勭娓?`MeshCoverBg` 閺€鍓佹畱閺?**`$$.imgLocal`閿涘牊婀伴崷鏉跨殱闂堛垺鏋冩禒璁圭礆** 閳ユ柡鈧?閹绢厽鏂侀崳銊﹀ⅵ瀵偓闁絼绔撮崚?
   *   鐏忎線娼板鑼病閸︺劍婀伴崷?閳?閼冲本娅欑粭顑跨鐢冩皑閺?*閻喎鐨濋棃?*閻ㄥ嫰鍘ら懝璇х礉缂佸嫪娆㈤柌宀勫亝娑?`makeFallback()`
   *   閿涘牊瀵?`seed` 閼硅尙娴夐柅鐘垫畱**閸ユ稖顫?HSL 濞撴劕褰?*閿涘鐔€閺堫剛鏁ゆ稉宥勭瑐閵?
   *   閹存垳婊戞潻娆庣娓氀冪殱闂堛垹顦块弰?*閸︺劎鍤?URL**閿涙岸銆夐棃銏＄槨濞嗏剝澧﹀鈧柈鑺ユЦ閺傛澘鐤勬笟瀣ㄢ偓涔eshSrc` 娑撹櫣鈹?閳?
   *   缂佸嫪娆㈤崘?`makeFallback()` 閸忓牓銆婃稉?閳?鐏炲繋绗傜亸杈ㄦЦ闁絽绱堕幐?seed 閼硅尙娴夐悽璇插毉閺夈儳娈戦崗婊冪俺缂冩垶鐗搁敍?*閽冩繆澹?*閿涘绱?
   *   缁涘婀＄亸渚€娼版稉瀣祰鐟欙絿鐖滅€瑰本澧犻幑銏㈡埂闁板秷澹婇敍宀勫亝閺冭泛濮╅悽缁樻－缂佹挻娼禍鍡愨偓?
   *
   * ## 閸嬫碍纭堕敍鍫㈢搼娴犺渹绨稉濠冪埗"閺堫剙婀寸亸渚€娼版稉鈧惄鏉戞躬"閿?
   *   濮ｅ繑顐奸幓鎰唉缂冩垶鐗稿┃鎰閿涘本濡?*瀹歌尙绮?enhance+blur 鏉╁洨娈?64鑴?4 RGBA 缂傛挸鍟?*閿?6KB閿涘绻涢崥灞界暊閻?key
   *   鐎涙ɑ鍨?*闂堟瑦鈧礁鐡у▓?*閿涙稐绗呮稉鈧▎锟犮€夐棃銏″瘯鏉炶姤妞傞懟?key 鏉╂ɑ妲搁崥灞肩妫ｆ牭绱濈亸杈╂纯閹恒儰绮犳潻娆庡敜缂傛挸鍟块柌宥呯紦 PixelMap
   *   閳?閹垫挸绱戦崝銊ф暰缁楊兛绔寸敮褍姘ㄩ弰顖滄埂闁板秷澹婇敍灞藉幑鎼存洜缍夐弽鐓庡涧閻喐顒滈崗婊冪俺閵?
   *   閳跨媴绗?鐎?*缂傛挸鍟?*閼板奔绗夐弰?PixelMap閿涙碍澧嶉張澶嬫綀缁犫偓閸楁洩绱欑痪顖氬敶鐎涙﹫绱氶敍宀勩€夐棃銏＄槨濞喡ゅ殰瀹搁亶鈧?PixelMap閵?
   *     闁偓閸﹁櫣鍙庨弮褑鍤滃閬嶅櫞閺€?閳?娑撳秳绱伴崣宀勫櫢闁插﹥鏂侀妴?
   *   閳跨媴绗?key 娑撳秴灏柊宥忕礄閹广垺鐡曢敍澶嗗櫩 娑撳秹鍣伴悽顭掔礄娑撳秳绱伴幎濠佺瑐娑撯偓妫ｆ牜娈戦柊宥堝娑撴彃鍩屾潻娆庣妫ｆ牭绱氶妴?
   *
   * ## 閴€?2026-10-17 瑜版挸銇夐幘銈呮礀閿涘牏鏁ら幋宄扮杽濞村鈧?*鐏炴洖绱戞潻鍥┾柤娑擃厾娈戦弰顖欑瑐娑撯偓妫ｆ牗鐡曢惃鍕杹閼?*閵嗗稄绱?
   *   閺嶇懓娲滈敍?*妞ょ敻娼伴幐鍌濇祰闁絼绔撮幏?`state.getCurrentSongItem()` 鏉╂ɑ妲告稉濠佺妫?*閿涘牏濮搁幀浣烘暠鐠嬪啰鏁ら弬鐟版倵閸愭瑱绱氶敍?
   *   娴滃孩妲?`currentMeshKey()` 娑旂喐妲告稉濠佺妫ｆ牜娈?key 閳?閸涙垝鑵戞稉濠佺妫ｆ牜娈戠紓鎾冲暱 閳?瀵偓閸﹀搫濮╅悽缁樻杹閻ㄥ嫭妲?*娑撳﹣绔存＃鏍畱闁板秷澹?*閵?
   *   閿涘牆鎮撴稉鈧幏宥勭瑐 `meshSeed()` 娑旂喍绱伴崣鏍у煂娑撳﹣绔存＃?閳?閸忔粌绨崇純鎴炵壐閸氬本鐗遍弰顖欑瑐娑撯偓妫ｆ牜娈戦懝鑼祲閵嗗偊绱?
   *   閳?**鐠恒劑銆夐棃銏㈢处鐎涙ɑ鏆ｅ▓闈涗粻閻?*閿涘牅绗呴棃?`adoptCachedMesh()` 娣囨繄鏆€鐎圭偟骞囨担?*閺冪姾鐨熼悽銊у仯**閿?
   *     閸愭瑧绱﹂崘鏌ュ亝娑撱倛顢戞稊鐔峰嚒閸掔娀娅庨敍澶堚偓鍌濐洣閹垹顦茬€瑰喛绱濊箛鍛淬€忛崗鍫Ｐ掗崘?閹稿倽娴囬弮鍓佸Ц閹焦妲告稉濠佺妫?鏉╂瑤閲滈崜宥嗗絹
   *   閳ユ柡鈧?娓氬顩ч悽鍗烇紦鐏炲倸婀?push 閸撳秵濡歌ぐ鎾冲濮濆苯鍟撴潻娑氬Ц閹緤绱濋幋鏍偓鍛Ω缂冩垶鐗搁崑姘灇 `AppStorageV2` 閸忓彉闊╅悩鑸碘偓浣碘偓?
   *     閻?濮濓絽婀幘顓熸杹閻ㄥ嫰鍋呮稉鈧＃?鐠愮喕鐭楃紒瀛樺Б閵?*娑撳秷顩?*閸欘亝濡哥紓鎾崇摠闁插秵鏌婇幒銉ょ瑐娴滃棔绨ㄩ妴?
   */
  private static meshBufKey: string = '';
  private static meshBuf: Uint8Array | undefined = undefined;

  /** @returns 瑜版挸澧犲灞炬锤閻ㄥ嫮缍夐弽鑲╃处鐎?key閿? 鐏忎線娼?URL / 閺堫剙婀寸挧鍕爱閺嶅洩鐦戦敍娑樺絿娑撳秴鍩岀粚杞拌閿涘鈧?*/
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
   * 閻劋绗傛稉鈧崗宕囨殌娑撳娈戠紓鎾冲暱闁插秴缂撶純鎴炵壐濠ф劑鈧?
   * 閴€?**瑜版挸澧犻弮鐘虹殶閻劎鍋?*閿涘牐顫嗘稉濠囨桨閵嗗苯缍嬫径鈺傛寵閸ョ偑鈧秹鍋呭▓纰夌礆閳ユ柡鈧梹瀵曟潪鑺ユ `getCurrentSongItem()` 閸欘垵鍏橀弰顖欑瑐娑撯偓妫ｆ牭绱?
   *   閻╁瓨甯撮柌鍥╂暏娴兼碍濡告稉濠佺妫ｆ牜娈戦柊宥堝閺€鎯у煂瀵偓閸﹀搫濮╅悽璁崇瑐閵嗗倷绻氶悾娆忕杽閻滅増妲告稉杞扮啊鐏忓棙娼?閻樿埖鈧礁鍘涚亸鍙樼秴"娑斿鎮楅崘宥嗗复閸ョ偞娼甸妴?
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
   * @returns 闁煎啿鏈▍娆戠磾閹寸偟澹愰柣?*闁稿繑绮岀花宕囩矓瀹ュ懐鎽?* 闁炽儲鏌￠埀?闁绘挆鍕剶闁哄啰濮烽弲?`seedOfParts($$.title, $$.artist)`
   *   闁挎稑娼塒layerPage.ets:5252` 闁汇劌瀚悿鍕矗閸岋妇绀嗛柕?
   *
   * 闁告瑯浜為弫銈嗙?閻忓繋绶氬浼村矗閺嶏妇鐟濋柛鎺斿濡?闂侇偆濮撮崢瑙勬償閺囩姷绉归柡宥囥€嬬槐妾侻eshCoverBg.makeFallback` 闁?`hueOfSeed` 闁?`fillFallback`闁挎稑顦埀?
   * 濞戞挸锕ラ悥?`seedOfParts` 闁汇劌瀚€氭儳鈻旈弴鐐磋含鐟滅増甯楅妴鍌滅箔閺冨浂鍞堕梺鎻掓湰閻ュ懘寮垫径鎰ㄥ亾閹邦剛鎽熼悘鐐存礀缁辨垿鏁嶅畝鍐闂佹彃鐬奸弫?`title|singer`
   * 闁炽儲鏌￠埀?閻庣懓鍟ぐ褑銇愰崡鐐存儥**闁肩灏欏ù?*闁挎稑娼塰ueOfSeed` 闁?Java 鐎殿喖绻愰悺褏绮敂鑳洬闁告繂鐗嗙粭鍥晬婢舵稓绀夐柟宄板悑绾埖绋夊鍛€遍柛娆樹簷缁变即骞戦～顓㈠殝闁肩灏欏ù澶愭晬?
   * 濞戞挸绉存總鏍传?闁哄牆顦伴惀鍛村嫉婢跺骸鍓归柡?闁?
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
   * 闁汇垹宕惃婵嬫閵忋垻鏆柛鎴犲劋缁侊箓宕楁径搴″壒闁哄拋鍨冲▓鎴炵▔閵堝嫰鍤嬪Λ鐗堢矎婢瑰﹪鐛捄鍝勬櫢閺?{@link coverTint}闁?
   *
   * 闁告瑯浜滃﹢顏勵嚕閳ь剟宕楅搹顐⑩叺鐎殿喒鍋撻柡鍐煐婢х娀宕戝鍓х獥闁告瑦鐗炴竟濠勬啺娴ｅ€熸巢濞戞挴鍋撴繛鍠°伆鎺楁儘娓氬﹦绀勯柛锔哄妿閸ゅ海浜告笟鈧鐗堟交濡娲ｉ柛蹇撶墔缁楀懏娼弬銈囩闁挎稑鑻崣褔骞掓径濠冪殤闁告帩鍋嗗▍褔鎳炴潏顐ょ濞寸姾妫勭槐鎴︽煥閳ь剟濡?
   * 濠㈡儼绮剧憴锔界▔瀹ュ棗袚闂佹寧鐟ょ弧鍐╃▔瀹ュ棙鏆Λ鐗堢矎婢?闁炽儲鏌￠埀?濞ｅ洦绻勯弳鈧☉鎾筹梗缁斿瓨锛冮弽顐ｇ暠濡増绮忔竟濠囧箣閺嵮冨箲閹煎瓨娲濇竟濠囨晬鐏炲墽銈﹂柛蹇擃槺閸欏酣寮介悿顖氬幋闁活亜顑冮埀?
   *
   * @param pixelMap 鐎规瓕灏闁活喕鑳跺▓鎴犱焊娓氣偓濞肩増鎷呭鍛闁挎稑鐬奸弫杈╂嫬閸愵亝鏆忛柡鍌滎攰缁€瀣嫻閿濆娅為柡鈧穱鎵佸亾?
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
            // 闁活潿鍔屽畷鏉啃掗弮鈧〒鑸靛緞瑜忓▓鎴烇紣濠婂棗顥忓ù锝嗙矆鐠愮喖宕烘ウ璺ㄦ闁挎稑鑻崯鈧柛?vividFlowColors 闂佹彃鏈俊鍛婎殰閸楃偞瀚查幖?濞存粠鍠栫€规娊骞忔径搴㈠闯闁哄鍎荤槐?
            // 閻忓繋绶氬鐗堢▔閺勫繐顥忕紓浣哥箰閻栧爼寮伴娆戭伇濠㈠爢鍛暬闁规亽鍎寸换搴㈩渶閹寸姵鐣遍柤鍐叉湰濞呮瑩鏁嶅畝鈧ú鍧楀箳閵夛箑鐟忛悗鐟板暙娴犳稑霉娴ｇ甯ㄩ柛鈺冨劋濠€浼存儑鐎ｂ晝鐟濋悷?
            // 闁挎稑鐗撻々缁樸亜?PR 闂侇叏绲挎晶妤呭礃濞嗘劦鍔ュ☉鎾亾濞戞搩浜炴导鐘绘嚌鐠囇呯闁圭鍋撳ù鐘劜閻ュ懏娼诲▎搴ㄥ殝闂傚偆鍣ｉ。浠嬫晬婢跺牃鍋?
            const color = colorPicker.getLargestProportionColor();
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });
  }

  /**
   * 闁硅泛锕ら惃婵嬫椤厼鐦滈柤鐟板级瀹曡尙绮诲Δ浣哥亣婵炵繝绀侀崢婊堟偨閵娧勭暠濞戞挶鍊撻柌婊勶紣濠婂棗顥忔鐐舵硾瑜板倻鏁崘锔瑰亾?
   *
   * 闁?`coverTint` 濞村吋淇鸿闁?{@link onCoverTintVersionChange}闁挎稑鐬奸弫杈┾偓鐟板暞婵″憡锛愬鍡楊棌濞戞挸顑呰ぐ鍌滅磼濞嗘垶绲婚柤瑙勫絻濞呮帡濡?
   *
   * **濞戞挸绉撮崹浠嬪棘椤撶偟纾婚柛?*闁挎稒纰嶅畷鑼不濡や焦鎷遍棅顒夊亜瑜把囧及椤栨艾娈ゆ繛鍡磿閻ｅ寮甸銈囩闁稿繐纾鍐╃▕閻斿嘲甯ョ紒鐘愁殔閵堢晫鈧稒顭堥幑锝夊级?闁炽儲鏌￠埀?閺夆晜鐟﹂悧閬嶆偨閵婏箑鐓?
   * 闁革负鍔忛鏇犵磾椤曗偓閸ｉ攱绋夐埀顒勫箥閹惧磭纾荤€殿喒鍋撻柛蹇曨劜缁辨繄绮璺伇閻㈩垎鍛暠婵炵繝绀侀崢婊勶紣濠婂棗顥忛悘蹇撳船閸戯紕绱掕箛鏃€笑鐟滅増鎸告晶鐘典焊娓氣偓濞间即鎳濈拠褏绀夊☉鎾崇С缁变即宕楅崼銉︼紡濞戞挴鍋撳☉鎾愁儏閸樿鎯旈弴鈥愁棌闁?
   * 闁活亞鍠愰婊呮啺娴ｈ棄小闂佸€熶含濞堟垿寮伴婢帡鎯嶆担鍝ユ闂傚牜婢佺槐婵嬫焽閿濆鍔ラ柛鎺戞閺?{@link extractFlowLightColors} 闁硅泛锕ら崣褔濡?
   *
   * @param red 閻忓繋绶氬鐗堢▔閺勫繐顥忕紒淇卞灲閳ь剚宀告禍?0闁?55闁?
   * @param green 閻忓繋绶氬鐗堢▔閺勫繐顥忕紓浣告健閳ь剚宀告禍?0闁?55闁?
   * @param blue 閻忓繋绶氬鐗堢▔閺勫繐顥忛柦鍐╃箞閳ь剚宀告禍?0闁?55闁?
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
   * 闁宠棄鎳夊Σ?2026-10-15闁?*濞戞挸绉撮崯鈧ù婧犲啫姣夊ù鐘侯唺缂嶅秹鎳楃仦鐐彲閹煎瓨娲栧ù?*闁靛棗鍊介崕妤呭疾椤栨氨婀撮柡鈧憴鍕亣闁靛棗鑻敮顐ｆ叏鐎ｎ亞娈遍梻?+ 缂備礁瀚▎銏㈢棯瑜嶉悿鍕籍閼哥殑浣哄寲婵炲簱鍋?
   *   闁挎稑婢朄link originalCoverSource} + {@link backdropBlurRadiusVp}闁挎稑顦崳?閺夆晜鐟╅崳鐑藉矗椤忓嫬鈷栧☉鎾卞€撳▎銏＄鐎ｅ墎绐?
   *   闁?闁?`imageLabel` 濠㈣泛绉崇紞鍛村箣?*闁告鍠庨～鎰焊娓氣偓濞?*闁挎稑娼塕esource`闁挎稑顧€缁遍亶鍩?缂佺姵顨呴崵?`state.imageColor`
   *   闁挎稑鐗婇幐閬嶅绩妤ｅ啨鈧鎳楃仦鐐彲闂侇叏绲介惇浼村矗閺嶃劎澹夐柤纭咁嚋缁? 婵炵繝绀侀崢婊堟嚌鐏炲倵鍋撻崒娆掑幀闂傚倻顥愯闁活喕绀侀崵顓㈠级閵壯勭暠 PixelMap **闁告瑯浜為弫銈嗙鎼粹€崇悼闁肩顕滅槐婵嬫偨閵娿儳鏆氶柛妤€鍟跨槐?*闁?
   */
  private async getImageColorAsync(): Promise<void> {
    const jobSeq: number = ++this.imageColorJobSeq;
    const ctx = this.context;
    if (!ctx) {
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (!song) {
      // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛弫銈夊箣閺嬵偀鍋撳畝鈧崑锝夊礄缂佹ɑ灏￠柡鈧悙顒佽拫闁瑰灚鎸哥槐鎴炴交濡粯笑婵炲备鍓濆﹢渚€鎳楃仦鐐彲闁靛棗绉跺▓鎴炵▔閳ь剟寮堕敍鍕焸闁告垹濮崇紞宥夊矗椤栨繂鍘撮柨娑橆檧缁?
      //   闁绘劗鎳撻崵顕€骞嶉幘宕囩；闂侇叏绲肩粩鎾礆婵犳哎鈧妫冮姀鐘茬仩闁圭鍊藉ù鍥晬鐎瑰炒tate.getCurrentSongItem()` 闁告瑯鍨甸崗?*閺夆晜蓱閻ュ懐鎲撮敐鍡欌偓浠嬪礄閻戞ɑ闄?*
      //   闁?閺夆晜鐟╅崳鐑藉储閻斿憡闄嶉柣鈺佺摠鐢?`return` 闁?闁哄喚婢€缁楀宕ｉ弽顒€顥忓☉鏃傚枍缁楀顕欓搹鍦Ч闁哄秶銆嬬槐婵嬫嚀鐏炶偐鐟?*婵炲备鍓濆﹢浣圭鐠佸磭绉垮ù婊冩惈閸熲偓闁哄鍎辫ぐ銊︾▔閳ь剙鈻?*
      //   闁挎稑鐗嗛幃鎾寸▔閳ь剚锛冮弽銊ф憙濞戞挸绉崇槐鎵喆閿曗偓瑜?`selectIndex`/`playQueueIds` 闁?`@Monitor`闁?
      //   闁?閺夆晜鐟ょ粩鎾极閺夋垵褰犻梺顔垮Г閻ュ懘寮垫径搴″壒闁哄拋鍨界槐婵嬫儎閺夋垵鐓傞柣顫妽閸╂盯宕氶崶銊ф憙闁靛棗鍊甸崳?闁衡偓鐟欏嫬鐏囬悹褎婢橀幃鎾寸▔閳ь剟寮?*闁哄牆顦遍弲顐︽煂瀹ュ懎绲?*闁挎稑鐗婂〒鑸靛緞?4 婵?閼?400ms闁挎稑顦埀?
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
      // 闁革负鍔庨崵搴☆潰鐏炵偓閿ら柨娑欒壘瑜?*閻熸瑱绲块悥?*閻忓繋绶氬鎵磼濞嗘劗銈﹂柛蹇擃槸瑜板洭鎳濋懠顒佹殢闁?
      //
      // 闁宠棄鎳夊Σ?2026-10-15闁挎稒淇虹换鏍煂鐏炶棄鏂ч柡澶堝劥缁绘洘瀵?`effectKit.createEffect(coverPm).blur(imageBlurRadius())`
      //   濡澘瀚憰鍡涘蓟閹捐尙顏辩€殿喚濮佃啯缂?PixelMap 鐟滅増鎸哥花鎶藉炊?闁炽儲鏌￠埀?**閻犲洢鍎甸。鈺併€掗崣澶屽帬鐎圭寮堕弳锝嗘媴閹惧厖绮婚柣?*闁挎稑鐗愰崕妤呭疾椤栨稒鏆悗鍦仦濡炲倸螣閿涘嫮藝闁?
      //   閹煎瓨娲栧ù妯肩磼濞嗘垶鐣遍柡?{@link originalCoverSource()} 闁汇劌瀚敮顐ｆ叏鐎ｎ亞娈遍梻鍫緛缁辨岸濡?
      //   闁?`imageLabel` 濞戞挸绉撮崯鈧悶姘煎亯缁佹挳骞嬮幇顒戒胶鍖栨繝鍌涚闁挎稒绋栬闁活喕娴囩换鏍ㄧ▔閳ь剙顫㈤妷銈囩闁伙絾鐟辩槐婵嬪炊閻樿精绀?
      //   {@link extractFlowLightColors} 闂傚洠鍋撻悷鏇氭缁斿瓨绋夐鍡楃疀闁瑰瓨鍔楀▓?PixelMap闁挎稑鐗嗛崢銈咁嚗濡炴崘绀嬮柛娆愮墳婢瑰﹪宕樺鍕憮閺夌偞鍨濈粩鎾焼瀹ュ懐娈遍梻鍫緛缁辨岸濡?
      if (song.cover.length > 0 && this.isAlive) {
        try {
          const pair: CoverDecodePair =
            await PlaybackPage.loadOnlineCoverPair(song.cover);
          if (pair.full !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            // 婵炵繝绀侀崢婊堝矗閺嶎剙顥忛柨娑欎亢缁夘喗鎷呭鍛鐎规瓕灏欑划锛勬喆閿濆洨鍨冲┑鍌欑矙閵嗗酣骞嶇€ｎ剛鏆☉鎾亾婵炲棌妲勭槐婵囩▔瀹ュ洦鏆忓☉鎾虫惈閻ｇ娀宕樺鍕憮閺夌偞鍨濈粩鎾焼瀹ュ懐娈遍梻?
            await this.extractFlowLightColors(pair.full);
          }
          // 闁宠棄鎳夊Σ?2026-10-15闁挎稒姘ㄧ紞澶愬冀閼规澘鍓归柡鍜佸灣濞堟垵鈹冮幇鍓佺64閼?4闁挎稑顦﹢顏堝触鐏炶偐顏辨繛鍡忊偓鑼憮閺夌偘绮欓崳鐑藉礄閻氬绀夊ù婧垮€楃划浼存嚄鐏炵偓鐝悘?
          if (pair.mesh !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            this.publishMeshSource(pair.mesh);
          } else {
            this.releasePixelMapQuiet(pair.mesh);
          }
          this.releasePixelMapQuiet(pair.full);
        } catch (_err) {
          // 闁告瑦鐗炴竟濠冨緞鏉堫偉袝濞戞挸绉存總鏍传瀹ュ棙灏￠柡鈧幘鍛獥闁煎啿鏈▍娆戞導閺夎法鏉介柡鍐煐鑶╃紒顖氼煭缁辨繃绋夊鍛櫃闂傚洠鍋撻悷鏇氭祰缁绘牕顕ｉ悩娲绘殨婵炴挸寮堕悡瀣炊?
        }
      }
      // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛弫銈夊箣閺嬵偀鍋撶仦鐐紦闁圭虎鍘介弬渚€鎮╅懜纰樺亾娴ｅ搫浠柛鎴犵帛婢э箑顕ｉ埀顒勫箻椤撶喐鏉归柛?闁?闁煎啿鏈▍娆撳及椤栫偟鎷ㄩ柣銊ュ缁遍亶鎮欓柅娑氼伇濞戞挸顑嗛幐閬嶅绩閹勭殤婵繐绲介悥鍫曞Υ瀹ュ繒绀?
      //
      // ## 闁哄牆鎼崺妤呮晬閸綆鍤㈠ù鐙呯悼閻栨粓宕￠崘鑼箒闁挎稑濂旂粭澶愬及椤栨粌顕查柨?
      // ```
      //   闁革负鍔庨崵搴☆潰鐏炵偓閿ら柣銊ュ閸庢寮?*濞戞挸绉靛Σ鎼佸矗閺嶎剙顥忛悘?*闁挎稑鐗撻崑鍛▔閳ь剛浠﹂崒娑櫺﹂柛鎰懄椤掓挳鎯冮崟顔剧濮?rgba(20,20,22,0.5)闁挎稑顧€缁?
      //   闁活亞鍠愰婊堟儍閸曨喖鍓归柡鍜佸灡濡?*缂傚啯鍨堕悧鎼佸炊?*闁挎稑娼塸ublishMeshSource(pair.mesh)`闁挎稑顧€缁辨繈鎳撶仦鐣屾殜闁告瑯浜滃﹢?
      //   `song.cover.length > 0` 闁哄啳鍩栨晶鐘冲濮樻剚娼堕悷娆欑到閸ゎ參寮堕妷锝傚亾?
      //   闁哄牜浜濋幐閬嶅绩閻愵剚顦ч悘蹇庣窔濞?URL 闁告瑯鍨甸崗妯绘交濡崵姊鹃柛鎺斿婢ф粓鏁嶉崸顣媡adata 闁?resolve闁挎稑顦崳?闁哄啨鍨洪惀鍛磾閹寸偟澹愬☉鏃傚枑閻ュ懘宕ｉ弽顒€顥?
      //   闁?閻忕偛绻嬬粭鍌滀焊鏉堛劍笑闂侇叏绲介惇鐗堟交閹达妇鎷ㄩ幖?= 闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣?闁煎啿鏈▍娆撳及椤栫偟鎷ㄩ柣?闁?
      //   濞戞挴鍋撻柣鎰潐閹搁亶寮?闁?閻忓繋绶氬?metadata 闁告帡顣︾紞?闁?`onCurrentTrackForBackground` 闁告劕绉风粣鍥ㄧ▔閳ь剙鈻?闁?婵繐绲介悥鍫曞Υ?
      // ```
      // ## 濠㈣泛瀚悿鍡涙晬?*濞戞挸绉磋ぐ鍌炲及鎼存繃宕插ù锝嗘礉椤鎲存径濞惧亾?*闁挎稑鑻ぐ褏鎷嬮埡浣烘殜闁煎浜滅换渚€寮ㄩ懜鍨異闁?
      //   闁煎啿鏈▍娆撳矗椤忓浂鍤夐悹?閻忓繋绶氬浼村嫉婢跺姊鹃柡鍫濐槸閸╁矂骞?闁哄牆顦崣褔濡?*濞戞挸瀛╅幐閬嶅绩閸撗冃﹂柟顑跨劍濡倝宕?*
      //   闁?閻忓繋绶氬鐗堟交濡崵姊鹃柛鎺斿婢ф粓寮拋鍦**闁哄牆顦遍弲顐﹀捶?*闂傚懏鏌х粩瀛樺濮橆剙濮介柛鎰Т瑜板洦绋夐埀顒€鈻庨埥鍛闁哄牃鍋撳?`BG_RETRY_MAX` 婵炲棌妲勭槐?
      //     婵絽绻戦濂告焾閸婄噥娲ｉ弶?`isAlive` + `jobSeq` 閺夆晜鐟ょ悮閬嶆焼閹剧粯锛岄柨娑橆槶閳?
      //   闁宠法濯寸粭?濞戞挸绉烽崗姗€寮悩缁橆€欓梺鎻掔Х閻︻垶鏁嶅顒傛闂傚牄鍨婚垾妯尖偓鍦仒缁楀鈧稒锚濠€顏堟晬閸喐鎷遍柛锔惧濡倝宕?闁规亽鍎辫ぐ娑橆潩闂€鎰暯濠㈡儼绮剧憴锕傛晬婢跺顦ч悷鏇氱娴犵娀骞嶇€ｃ劉鍋?
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
    // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`decodeCover`闁挎稑顧€缁变即宕ョ仦鑲╊伇婵炲枴銇版帡鎯?*濡炪倗鍎ゆ晶婊堝礃瀹ュ懎姣夊☉鎾亾鐎?64閼?4**闁?
    //   閻庣懓鍟晶鐘诲及椤栨粎绉归柡宥堝閸庢寮查婊勭暠婵犙勫姧缁辨瑩寮悩鍨珪 `SRC_EDGE = 64`闁挎稑顦埀顒€鍊稿﹢?64閼?4 濞戞挸锕ゆ禒?`enhanceColors`
    //   + `boxBlurRgba(9, 3)`闁挎稑鑻崯鈧悶?`drawPixelMapMesh` **闁衡偓閹佷海闂佸墽鍎ゅ褔寮弶鎴犳綄** 闁?
    //   閻熸瑥鍊归崝鍛村及?濠㈠爢鍡楊棌闁秆勵殕缁侊箓宕?闁挎稑濂旂粭?闁稿繈鍔岄崹搴㈡綇閵娧冭姵闁绘挆鍛暬 + 濡ゅ倹蓱閺屽螣閿涘嫮藝"闁哄嫷鍨悮杈╃矓瀹ュ嫮顐介悷妤勶骏閳?
    let meshPm: image.PixelMap | undefined = undefined;
    const imageSource = image.createImageSource(mediaData.buffer as ArrayBuffer);
    try {
      pixelMap = await imageSource.createPixelMap();
      // 闁宠棄鎳夊Σ?2026-10-15闁挎稒姘ㄧ紞澶愬冀閸忚偐鐖?*闁告娲滅€氼厽绋夐埀顒佺▔?try** 闁炽儲鏌￠埀?閻庣懓鍟妵鎴犳嫻?*濞戞挸绉烽崗?*闁?闁告瑦鐗炴竟?闂侇叏绲惧顖滄崉椤栨瑧顏遍悹?abort闁?
      //   闁告鍠愬鐢稿及椤栨繄顎€濞戞挻妲掕闁活喕绀侀幃鎾寸▔閳ь剚绋?`try`闁挎稑鐭侀埀顒€鐭傞崑鍛▔?`catch` 濞?`return`闁挎稑鐗嗛懟鐔煎礃濞嗘挾甯涢悹浣靛€曠花鎶芥嚌鐠囇呯
      //   闁?64閼?4 闂侇叏绲肩粩鏉戭潰閵夈倗顏诲☉鎾亾濠㈡儼绮剧憴锕傛晬瀹€鍐 `state.imageColor`闁挎稑鐗愰崕妤呭疾椤栨艾绲块柡宥囨焿婢瑰﹪鏁嶆径鎰幋濞村吋鐭粩瀵告導閾氬倹涓㈤柕?
      //   缂傚啯鍨堕悧绋库攦閹邦厼鐟忓☉鎾崇Т閸╁矂宕ｉ鍐獥闂侇偀鍋撻柛?閻庡湱鍋炲鍌毼熼敍鍕囬幖瀛樻礀濞?闁挎稑鏈Σ?*闁告瑯鍨跺椋庣棯?*闁汇劌瀚哥槐婵囩▔瀹ュ牜鍤夐柟閿嬬墪閻忔繈宕ｉ弽顒€顥忛柕?
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
            // 闁告艾濂旂粩鏉戔枎閳ュ啿绲块柤纭呭皺濞堟垹绱掗幘瀵镐函濡炪倕鎼悽顐ょ不濡や胶銈﹂柛蹇擃槼婢瑰﹪鏁嶅畝鈧〒鐑藉箳婢跺﹤鏅欑€点倛妗ㄧ粩瀛樼▔?ColorPicker 闁汇劌瀚槐鎴︽煥閳?
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

    // 闁宠棄鎳夊Σ?2026-10-15闁挎稒淇虹换鏍煂鐏炶棄鏂ч柡澶堝劜濡叉悂濡寸€瑰碁ffectKit.blur(imageBlurRadius())` 濡澘瀚憰鍡涘蓟閹捐尙顏辩€殿喚濮佃啯缂?PixelMap
    //   閻犙冾儑缁?`imageLabel` 鐟滅増鎹侀崕妤呭疾椤栨氨淇洪柛銉ゅ嫎閳ь剙绉查埀顒€鍊介崕妤呭疾椤栨稒鏆柟瀛樺姇閻ゅ嫰寮懜鐨勪胶鍖栨繝鍌涘€?*閺夆晜鐟﹀顖滄崉椤栨艾鍤掗柡浣虹節缂嶅宕戝鍛殢** 闁炽儲鏌￠埀?
    //   `imageLabel` 濞ｅ洦绻冪€垫梹绋?`song.label`闁?*闁告鍠庨～鎰焊娓氣偓濞?Resource**闁挎稑顧€缁?
    //   闁?{@link originalCoverSource} 濞存嚎鍊楃划浼存嚄鐏炵偓鐝悘?+ 缂備礁瀚▎銏㈢棯?`.blur()` 闁告顕ч悿鍕籍閼哥殑浣哄寲婵炲簱鍋?
    //   閻熸瑱绲块悥婊堝礄閻戞ɑ闄嶉柣?PixelMap 闁告瑯浜濆﹢鍥礉閳ヨ尙鑹惧☉鎾筹躬濞间即鏌囬敐鍡╁仹闁告瑦鐗炴竟濠囨晬瀹€鈧弫銈団偓鐟拌嫰瀹撳棗顕ｉ崘锔瑰亾?
    //   闁宠法濯寸粭?濡炪倕鎼悽顐ゆ喆閿濆棗绔村☉鎾亾濞戞搩浜▓锝夊箖閿濆繒绐楀ù鐘劚婢х姷鎮锕€娅為柡鈧崜褎鐣辨慨婵撶稻濡?婵繐绲藉﹢顏囥亹閹惧磭淇洪柛銉у亾鐟曞棝寮婚幘鑸电暠闂侇叏绲界槐?PixelMap"
    //      闁挎稑鐗呯粭鍛枎閳╁啫搴婃慨?濡炪倗鏁诲浼村础濮濆本绁伴柡?`releaseBackgroundCoverIfPixelMap()` 濞村吋宀搁崳鎾绩閹呮殜闁挎稑顧€缁?
    //      闁绘粍婢樺﹢?`imageLabel` 闁诡厽甯婄拹?Resource 闁?**闁煎啿鏈▍娆戜沪閸屾瑧鐟濋柛鎰У鐎垫棃寮垫径澶嬪床濞达絾娲戠槐鎵偖椤愶箑娅為柡鈧崜褎鐣卞ù锝呯Т濞?*闁?
    // 闁宠棄鎳夊Σ?2026-10-15闁挎稒纰嶅﹢浼村捶?闁告劕鎳愰悿鍡欎焊娓氣偓濞间即鎯?64閼?4 缂傚啯鍨堕悧绋库攦閹邦亞鐦嶅ù婧垮€曢崵顓㈠储娴兼瑧绀勯柤鍐叉湰濞呮瑧浠﹂崒婊勬殢闁挎稑顧€缁?
    //    閻庣懓鍟板▓鎴︽偨閻旈攱鍤掗柛娑栧妽濠€锟犲绩閸︻厽鏆?`meshSrc` 闁归晲鐒﹀﹢渚€鏁嶉崼鐔峰簥婵繂鏈鍌炴煂婵犲啯鏉瑰☉鎾筹梗缁旀潙顕ｉ悪鍛閻?`publishMeshSource`闁挎稑顦埀?
    this.publishMeshSource(meshPm);
    this.releasePixelMapQuiet(pixelMap);
  }

  /**
   * 闁硅泛锕ら惃婵嬫椤厾绉撮柛銉﹀劤娴犳盯骞?*缂傚啯鍨堕悧鎼佹嚄鐏炵偓鐝柣銊ュ缁?*妤犵偞婀瑰锔剧磼濞嗘帒鍓归柡鍜佸灠閻即濡?
   *
   * 闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨偄绲块柛銉﹀劤瑜版稑顕ラ崟鍓佺`闁圭虎鍘介弬浣广亜娴ｅ啫鍓归柡?MeshGradient濞戞挸鎳俥shSource閻庤姘ㄩ…?md` 閹? / 閹?闁挎稑顧€缁?
   * ```
   * 64閼?4 RGBA_8888闁挎稑鐗嗚ぐ鑼磽閺嶎剛甯嗛柨?
   *   闁?enhanceColors(u8)                              濞达絽楠搁顔夹?/ 濡ゅ倹锕㈤妶閬嶅椽?/ 闁稿绻戝▓顐︽晬閸繄绉奸柤鍐叉湰濞呮瑦绋夊鍡楊潵闁告挸绉靛▍娆撴晬?
   *   闁?boxBlurRgba(u8, 64, 64, 9, 3)                  闁烩晜甯掔槐鈥澄熼敍鍕囬柨娑樻湰濡?gamma
   *   闁?闁搞儳鍋涢崯?PixelMap闁挎稑濂斿锔剧磼?MeshCoverBg闁挎稑鐗忕紞澶愬冀閸忓吋鏉瑰鍫嗗洦鎳欐繝濞炬缁?
   * ```
   * 闁宠法濯寸粭?`enhanceColors` 闂佹彃鐬煎▓?`0.4` 濞?`閼?` 闁?*闂佹澘绉撮〃婊堟儍閸曨亞顏遍悗?*闁挎稑鑻崺鍡涘矗椤忓懏鏆☉鎾亾濞戞搩浜风槐娆愬濮樺磭绠栭柡鍥ㄧ箖閸ㄣ劑宕ｉ幋鐘辩礂闁挎稑顦埀?
   * 闁宠法濯寸粭?闁哄倻澧楀Λ顐ｇ閵堝棙绂屽銈呮惈缁參鏁?*闁稿繐鐗撻崳鎾绩閸欍儳鐟愬☉鎾亾鐎殿喚濮伴埀顑跨閸熲偓閻犙冾儏閳ь剛鍘ч懟?`++meshSrcVersion`** 闁炽儲鏌￠埀?
   *    `MeshCoverBg` 闁?`@Monitor` 闁烩晜鍨甸幆澶愭儍閸曨剚笑**闁绘鐗婂﹢浼村矗?*闁挎稑娼塒ixelMap` 闁告鍠庡﹢鎾绩閻熸澘鏁堕悗褰掆偓娑氱憹濞村吋淇鸿闁告瑦鍨甸崺娑㈠棘鐢喚绀嗛柕?
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
      // 閴€?2026-10-17閿?*娑撳秴鍟撶捄銊┿€夐棃銏㈢处閸?*閿涘牐顫?`adoptCachedMesh` 娑撳﹪娼伴柇锝嗩唽"瑜版挸銇夐幘銈呮礀"閿?
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag, `mesh source build failed code=${e?.code}, message=${e?.message}`);
      this.releasePixelMapQuiet(pm);
      return;
    }
    const old: image.PixelMap | undefined = this.meshSrc;
    // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`MorphGuard` 闁?闂佹澘绉锋竟濠勨偓鐟邦樀濞笺倗绮ｅΔ鈧ぐ?闁挎稑顧€缁辨媽銇愰姀鐘茬秮閻炴稏鍎靛Λ璺ㄦ崉閹寸姵绲婚柣銊ュ濡炲倿宕?*濞戞挸绉靛畷鏌ユ嚄鐏炵偓鐝?*
    //   闁挎稑鐗婂畷鏌ユ嚄鐏炵偓鐝?= 闁轰焦娼欓惇鎵磾閹寸偟澹愰梺鎻掔Ф閺侀箖鏁嶅畝鍐炬綆闁规壆鍠庡銊╁及?闁告柣鍔庨弫鐐▔椤撯懇鍋撻弮鍥у壒闁哄拋鍨垫竟濠勬崉閸忓懐顏卞☉?闁挎稑顦埀顒€鍊婚悰銉╁矗閿濆牏绠栭柛妯款嚙閹鎳涢鍕楅悶娑栧劙缁楀倿寮甸埀顒勫触鎼存繄顏辨繛鍠℃壋鍋?
    // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*缂佹鍏涚粩鏉戭嚕閻樺磭鐖辩紓浣圭箑缁楀鎷嬪宀婃蕉閺夆晜鐟╂禍鍓х玻濡も偓瑜版盯骞掗妸銊х** 闁炽儲鏌￠埀?濞ｅ浂鍠氶弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鐬奸崑锝夊礄缂佹ê鈪电€殿喒鍋撴繛灞稿墲濠€渚€鎳楃仦鐐彲闁靛棗绋勭槐?
    //   `old === undefined` 閻炴稏鍔庨妵姘炽亹閹惧啿顤?*闁哄秷顫夊﹢鏉库柦閳╁啯绠掔紓鍐╁灦閻楃鈹?*闁挎稑鐗忛崑锝夊礄缂佹ê鈪电€殿喒鍋撻梺顓ㄧ导缁旀挳宕氭繝姘モ偓澶愭閵忕姴鐏犻柟绋垮€藉ù鍥Υ娴ｈ鍔€闁革负鍔忚闁活喕绶ょ槐姘跺Υ?
    //   閺夆晜鐟ч～鎺楀籍鐠鸿　鍋撳▎蹇撴櫃"缂佹稑顦悾銊╂濞嗘垹宕堕柛娆欑秬缁诲啴宕?閻忓繐宕ぐ褔宕滈埡浣稿箲閹煎瓨娲栬ぐ鍥冀閻ゎ垰顥忛柨娑樼墕閻?alpha 闁?闁告锕埀顒€绻戝Σ鎴︽晬婢跺棗娅?闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣銊ュ濡?
    //   婵炲备鍓濆﹢渚€鎳楃仦鐐彲闁靛棗鍊甸崳?缂佹鍏涚粩鏉戭嚕閻樺磭鐖?*缂佹柨顑呴崺銏ゅ箵閹邦亝鍞?*闁挎稒绋戣ぐ褔寮?闁哄洦瀵у畷鎻掝啅閸欏绠掓繝?闁归潧绉烽摂瀣玻濡も偓瑜版盯鏁嶉崼銉ヤ簼闁归潧绉靛Σ?闁告柣鍔庨弫鐐▔椤撯懇鍋撻弮鍥╁劜闁?闁汇劌瀚┃鈧柡鍜佸灲缁辨岸濡?
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
   * 闁硅泛锕︾紞澶愬冀閸忚偐鐖遍柣顏嗗枑椤掓粓骞愰崒娆戠憪闁告ü绱槐妾link publishMeshSource} 闁?闁圭粯鍔掑?闂侇叏绲藉畷鎰版晬婢跺牃鍋?
   * @param pm 闁哄倹澹嗗▓鎴犵磾閹寸偟澹愭繝褎鍔х槐娆撳箥閳ь剟寮垫径瀣秬閺夌儐鍓涗簺缂備焦鐟﹀﹢鐗堛亜绾板绀?
   * @param old 閻炴凹鍋呭ù娑㈠箲閵忊€崇闁汇劌瀚Λ顐⑩攦閹板墎绀勯梻鍫㈠仧閳规牠宕氬▎鎾虫珵闁衡偓閹惧懐绀?
   */
  private commitMeshSource(pm: image.PixelMap, old: image.PixelMap | undefined): void {
    this.meshSrc = pm;
    this.meshSrcVersion = this.meshSrcVersion + 1;
    if (old !== undefined && old !== pm) {
      this.releasePixelMapQuiet(old);
    }
  }

  /**
   * 閻庣懓顦靛銈囩玻濡も偓瑜版稒娼婚崶褍绠甸柛姘唉钘熷☉鎾筹攻濞撳爼宕ユ惔婵堫伇婵炲棴绱曠紞澶愬冀閸忚偐鐖?闁炽儲鏌￠埀?濞戞挸瀛╁Λ銈夋偩瀹€鍕簼濞戞搩浜崳鍝ユ嫚?娴ｅ秹鏁嶉崸鍓媢jie.pa:157930-157939`闁?
   * 閻?`syncReportChrome()` 闁哄嫷鍨伴幃鎾寸▔閳ь剚绂掗張鐢电殤闁?*缂佹劖顨呰ぐ娑欑▔閳ь剚娼婚崶褎鐨戦柟璺猴攻濞撳爼寮导鏉戝赋闁肩灏棢濞戞挸锕ら獮?*闁?
   * 婵炲备鍓濆﹢浣割嚗閸涘叓澶愭儍閸曨剛鐖遍柡鍐煐濡插摜绮氶悜妯绘儥濞达絾鍤庨埀?
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
   * 濞戞挴鍋撴繛鍡忊偓鑼憮閺夌偛鈧啘鎺楀礄閾忚鐣卞☉鎾卞€曠槐鑸垫媴瀹ュ懏绂堥柨娑欒壘閸欏繒浜搁崫鍕靛殶闁挎稑鐗婄粊锕傚礂婢跺﹤绲块柤纭呭皺閺併倝鏁? **64閼?4 缂傚啯鍨堕悧绋库攦?*闁挎稑鐗愰崕妤呭疾椤栨粍鏆忛柨娑橆槶閳?
   *
   * 闁?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯灱濞堟垿宕ｉ弽褎绂堥柛娆欑到缁剁偤鏁嶆径娑氱獥闁?64閼?4 闂侇叏绲肩粩鏉戭嚕閻樿櫕鏉归柛?*闁告艾濂旂粩鏉戔枎闄囪闁?*闂佹彃鑻崵顓㈡晬?
   *   濞戞挸绉寸换鈧☉鎾荤細閸庢寮查姘櫃濞戞挸顑堝ù鍥ㄧ▔閳ь剟鏌嗗鍛闂傚牜娼块埀顑跨箹desiredSize` + `editable` 闁哄嫷鍨扮换鈧銈堝吹濞?闁炽儲鏌￠埀?
   *   缂傚啯鍨堕悧绋库攦閹邦垼娲ｉ柛?64閼?4 濞戞挸锕ょ敮顐﹀捶閺夊じ绮?`enhanceColors` / `boxBlurRgba`闁挎稑鐗愰～?`publishMeshSource`闁挎稑顦埀?
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
   * @returns 鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞呮帡鎯?*濡ゅ倹锚鐎?*闁挎稒鑹鹃懜浼村矗濡粯鍩傞梻鍌氱摠濡?缂佹梹鐗滃ú璺ㄦ啑娴ｇ顥呯紒鎰殔瑜?闁挎稑鐗嗚ぐ褔妫侀幓鎺戞瘔濞戞挸锕鐗堟交濞嗗海顏遍柡澶嗘缁辨岸鏁?
   *          闁稿繑婀圭紞鎴﹀籍閸洘锛熼柟顓熷笂鐠?`'100%'`闁? 濞戞挸瀛╅惀鍛村嫉婢跺海绠瑰┑鍌涱殔婵晠鎮界紒妯活槯闂侇偅鍔曢崕姘辨閻樿京顏遍柤鐤彧缁辨岸濡?
   *
   * 闁宠法濯寸粭?闂傚牊鐟﹂娑㈠箑?*闊洤鎳橀妴?*缂?`'100%'` 闁兼澘濂旂粭澶愬及椤栨瑦宕插ù锝嗘礈閻ｅ宕欓悜妯婚檷闁汇劌瀚弳鐔衡偓娑欘殣缁辩増绋婄€ｎ亜顤呴柣顫妼閻ゅ嫬霉鐎ｎ剚鐣?
   *    `contentHeightVp` 鐟滅増鎹囧銈咁潰閵忋倗褰幖杈捐缁辨繈鎳撶仦鑲╃憪闁硅翰鍎茬花顕€骞侀弶瑁ゅ仺闁?*閺夆晜鐟ラ惇浼存嚊椤忓嫮绠掗悶姘煎亯椤ュ棝宕滈鍛槯闁汇劌瀚伴悵顔芥償?*闁?
   *    濞戞挴鍋撴繛鍡忊偓鑼憪闁瑰嘲顦粻锝夊触鎼淬倗绠瑰☉鎿冧簻閳ь剛鍘у銊ф偖椤愩垹鏅搁柟?~360vp闁挎稑濂旂花顒勫及椤栨稓妲ㄦ繛鍡忓墲婢э箑顕ｉ埀顒勫箻椤撶喐鏉瑰銈夋涧缁ㄦ娊鏌堥妸鈺佸幋缂傚倽妗ㄧ粩鎾锤?
   *    闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儏瀵姤锛冮崼顒傜闁靛棗鍊诲▍銊╁礆閸℃妲峰Δ鍌浢€规娊鎮芥潏鈺佺厬閻庡湱鎳撳▍鎺楁晬閸喎濮悘鐐茬箰椤旀牗绋夋导娆戠闁告劕鍟块悾楣冩晬鐏炶偐鐟濋柛娆樺灥閸忔绮诲Δ鍛櫓闁?
   */
  /**
   * @returns 鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞呮帡鎯?*濡ゅ倹锚鐎?*闁? 缂佹梹鐗滃ú璺ㄦ啑娴ｇ顥呯紒鎰殔瑜版盯鏁嶆径娑氱獥闂傚牊鐟﹂娑㈠箑?`'100%'`闁挎稑鐗忛悺鎴炵閾氬倻鑹惧☉鎾崇Х椤ュ棝宕滈搴ｇ闁?
   *
   * 濞戞挸绉磋ぐ澶愭煂韫囥儳绐楅悷浣风婢光偓濡ゅ倹锚鐎?= 闁告瑯鍨甸～瀣殗濡搫顔?/ 缂傚倵鏅滈弬?闁?閻忕偛绻嬬粭鍌炴焽閿濆懏鍋ラ柛娆樺灥椤鎯岄埡浣藉煂闂?*婵繐绲介妶?*闁哄嫷鍨遍弳锝嗐亜绾板绀?
   * 闁哄啨鍨洪惀鍛村嫉婢跺本娈岄柣褎鏋荤槐娆戠箔椤掆偓濞叉捇鎮?濮掓稒鍨归悰銉╁矗閿濆繒绀夊☉鎿冨弮濡寧绋夐埀顒佺▔椤忓嫮姣堥柟缁㈠幗閺備焦銇?閻忓繗椴稿Σ鎼佹偩濞嗘垶顏ら柨娑橆檧缁辨繃绋婇悢鍝ユ⒕闁哄牆顦抽ˉ鍡涘礆閸ャ儮鍋?
   * 闁宠法濯寸粭?闂傚牊鐟﹂娑㈠箑娴ｅ摜绠戝銈堝吹缁?`'100%'` 闁兼澘濂旂粭澶愬及椤栨瑦宕插ù锝嗘礈閻ｅ宕欓悜妯婚檷闁汇劌瀚弳鐔衡偓娑欘殣缁变即鎯傞幆褍鐎绘慨锝嗘⒒閺佸崬顭ㄩ垾宕囨綄閻庣懓銇樼€靛矂宕橀崘鑼毎闁?
   *    濞戞挸绉崇槐鎵偖椤愶絿鍘欐繛鍡忊偓瀹犲煂闁告瑦顭囧▓鎴炵▔椤撱垺锛熼柟顑跨閸熸捇鎳樿箛銉х"閹煎瓨娲熼崕瀵哥磽鏉炴壆顏遍柛?閻忓繗椴稿Σ鍛婃交濞嗗海鐤勯柡澶堝劤濞堟垿鏁嶆径鍫氬亾?
   */
  private morphClipHeight(): Length {
    if (!this.expandState.morphClipping()) {
      // 闁宠法濯寸粭宥夊煣閻欏懐鐟?2026-10-17闁?*闁活潿鍔嶉崺娑氱箔?1/2 闁?閻炴稏鍎靛Λ鍨柦閳╁啯绠掗柛鏂诲妿閺?闁汇劌瀚埀顒佺懇閳ь剙顦板┃鈧柛?*闁挎稑顧€缁?
      //   閺夆晜鐟╅崳鐑藉储閻斿憡闄?*闁哄啰濮靛顖涚閹壆绠查柛?`'100%'`闁挎稑鐗嗛悺褏绮敂鑳洬闁?*闁挎稑鐭侀埀顒€鑻懜浼村矗濡粯鍩傞弶鈺傛煥濞叉牠鎯冮崟顒佇?*闁轰焦婢橀悺?*
      //   闁?`.height()` 閺夆晜鐟ら柌婊呬沪閻愮补鍋撹濠€?*閻庢稒顨堥浣圭▔?闁?闁轰焦婢橀悺褎绋婄€ｎ喗锛熼柛鎺戞处瀹曡尙鐚剧拠鑼偓?*闁?
      //     ArkUI **闁哄啰濮电涵鍫曞捶閵娿倛鈷堢紒澶婄Ф鐞氼偊宕圭€ｂ晝顓洪梻鍌氱摠瑜板啴宕?* 闁?閻炴稏鍎靛Λ鎸庣▔閳ь剛鎸ч柨瀣杹閻?*闁烩晛鐡ㄧ敮瀵告崉閸愭彃鐓傜紓浣哥墢閸?*
      //     闁挎稑鐗愰～鍥箛?= "閻忓繋绶氬浼存儎鐎涙ê澶嶉悘蹇撳船閸╁瞼绱掗幘瀛樺皢濞达絽绉堕悿?/ 闁烩晛鐡ㄧ敮瀛樼▔鐎ｎ亜绠甸柨娑樻湰閻ュ懘寮垫径濠傂楅柣?闁挎稑顦埀?
      //   闁?濞戞捁妗ㄧ划鍫熺▕?闁归潧顑嗙€垫氨鎹勯悢绋款杹闂侇叏绲惧顖炲及椤栨哎鍋ㄩ柣?闁挎稒宀搁崑鍛村级闄囬惌鎯掕箛搴ｎ伇閻㈩垎鍥у幋闁革负鍔岄崯?*闁轰焦婢橀悺?*闁挎稑鑻崣蹇曠矙鐎ｎ亝鍊辩紒顐ヮ嚙閻?闁?
      //   闁?濞戞捁妗ㄧ划鍫熺▕閸綆娲?return 闁轰焦婢橀悺褔鎳撶仦鑲╃憹闁哄嫷鍨换姘舵偩?'100%'闁挎稒宀稿銈咁潰閵忊檧鍋撴笟鈧崑鍛村级閳╁啯鏆堥梺鎻掞攻婵绠涢崘顏呯暠闁?
      //     "**闂佹彃绻愰崵顓㈠级閵壯勭暠闁告劕鎳庨鎰殗濡搫顔?*濞村吋淇洪～锕傚蓟閹邦収鍋х憸鑸灩瑜板宕樺▎鎺戝"闁?閹煎瓨娲熼崕瀵哥磽鏉炴壆顏遍柛?闁挎稑顧€缁?
      //     闁?*缂佹劖顨呰ぐ娑欘殗濡搫顔?*闁?`reportWindow` 缂備焦鐟у▓鎴﹀级閸愩劉鏋嗛柛濠勵儠閳ь兛妞掔粭澶愬矗閸屾瑧鐟㈢憸鑸灩瑜?闁?婵炲备鍓濆﹢渚€鏌囬敐鍕殝濡炲閰ｅ▍鎾诲Υ?
      //   闁宠法濯寸粭?閻庡湱鎳撳▍鎺楁偉閸撲線鐛撻柡鍕靛灡瀵呬沪韫囨搩鍟忓☉?闁?闁轰焦婢橀埀顒勬？缁?`winHVp` 閻忓繗浜悺鎴炵?`'100%'`闁?
      //     缂佹劖顨呰ぐ娑氫焊閸濆嫷鍤熼弶鈺偵戦惀鍛▔婵犲啫袚闁哄啳顔愮槐娆撳几娴ｈ锛嶉柡鍫㈠櫐缁辨岸骞嶅澶嗗亾閳ь剟宕堕悙鑼憻缂佹缂氱憰?闁炽儲鏌￠埀?闂侇叏绲惧Σ鎼佸船椤栨瑧顏遍柣銊ュ缁旀潙鈻庨敍鍕潶闁搞劌顑呴崹蹇涘箲椤喚绀?
      //     濞戞挻鏌ㄨぐ鍌炴偨閻旈攱韬柡鍫墴閵嗗宕氬顓炵槸閺夌偛顫曢埀顑挎祰缁绘洖鈻介埄鍐╃畳濞寸姾顔婄紞宥囨偘閵夆晜锛熼柣銊ュ濡炲倿宕愬▎宥佸亾?
      const h: number = this.expandState.windowHeightVp;
      return h > 0 ? h : '100%';
    }
    return Math.max(1, this.expandState.morphClipHeight);
  }

  /** Root: 闁轰焦鎸抽妴澶岀磽閳哄倹鏉?+ 缂佹梹鐗滃ú璺ㄦ啑娴ｇ顥呯紒鎰殔瑜版盯鏁嶉崼婵嗚閻熸瑥妫涢悡鈺勩亹閵忋倕娅℃慨婵撶到閵堜粙寮伴娑欐濡炪倗顣槐? 婵℃ぜ鍎茬敮瀵镐焊娓氣偓濞间即濡?*/
  build() {
    // 闁?缂佹鍏涚花鏌ユ偋閸剛绐?*闁轰焦鎸抽妴澶岀磽閳哄倹鏉?+ 缂佹梹鐗滃ú璺ㄦ啑娴ｇ顥呯紒鎰殔瑜?*闁?
    //   闁告瑯鍨甸～瀣儗閳轰浇鍩屽ù?*閺夆晞娓圭紞姗€寮堕敓鐘蹭簼闁哄銈呭帯闁?*闂傗偓閸喖鐓傞柡浣规綑閻棝鏁?闁轰胶绻濋柌婊堝箻椤撶喐鏉归柡澶嗏偓铏偨濞村吋鎮傞幗闈涱嚕閳?闁挎稑顧€缁?
    //   濞戞挸顑堢粩鐔煎捶閵娿儱顤?25% 閻忓繗绮鹃崚娑㈠礆閺夋鍟忓☉鎾诡嚙缁ㄨ櫕娼忛惂鍝ョ闁告熬绠戦崹顖涙償閺囥垹鍔ラ梺顓ㄧ到閸ゆ垿宕?vp 闁轰礁鐡ㄩ宀勫礉閵娧勬毎闂侇喚鏅埞鏍儓閳ь剟鏁嶆径娑氬耿
    //   闁告劕鎳庨鎰沪閸岀偟褰幖?= 閻熶椒绀佹竟鈧Δ鍌浢€?= 闁告瑯鍨甸～瀣殗濡搫顔?/ 缂傚倵鏅滈弬渚€鏁嶇仦鎯ь暡濞寸姰鍎辫ぐ鑼喆閸℃瑧鍙愮憸鑸灲閸?*婵ɑ鐡曠换娆愮箙椤愶絽濮柡浣规尦閵?*闁?
    //   婵炲备鍓濆﹢渚€鎮惧▎鎴烆仱闁靛棔妞掔弧鍐╃▔瀹ュ嫮绐楅悶姘煎亯椤ュ棝鏁嶅☉妯烘暥閻庡湱鎳撻惇鎵驳婢跺﹤璁查悷娆忔閻撯晞銇愰姀鐙€鍟嶅Δ鍌浬戦惁顕€骞掗妷銊х濡炪倗鏁诲浼村籍閼搁潧顤呮繛鎼枤楠炲洭鏁?
    //   闂侇剙鐏濋崢銈嗙▔椤撶噥鍞介柣顏勵儏閸╁本绋夐埀顒€顕ｉ悩渚蕉闁告ê顑嗘晶搴ㄦ儍閸曨垬鈧妫冮～顔剧闂侇叏绲鹃婊堝及?濞寸姴绨奸懙鎴︽⒒閺夋垹纾诲┑顔碱儍閳ь兛鑳跺﹢鍛▔瀹ュ懎姣夐悘鐐存礀缁辨垶娼婚崶鈹炬煠"闁汇劌瀚闈涒攦閹板墎绀嗛柕?
    //   閻忓繋绶氬浼存偨鏉堚晝鏁惧瀣仜閻ㄦ繈妫冮姀鐘茬闁绘瑯鍓涢悽缁橆槹閻戝洨绀?*p = 1 闁归潧绉烽幆銈嗘媴?*闁?026-10-15 閻犙呭厴閸嬪懏绋夐埀顒€螞閹烘梹鏆伴柛?*濠㈢懓鍟块惇鏉棵归鑲╂勾**
    //   `Index.MorphCoverClone()` 闂佹彃鐭夌槐鐩 濠㈢懓鍟块惇鐗堢瀹ュ懏韬柡鍫墴閵嗗鎯?`MorphCoverBridge`闁挎稑顦埀?
    Stack({ alignContent: Alignment.TopStart }) {
      // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*闁煎啿鏈▍娆撳极閺夋垹婀撮柟纰卞墮閸╁矁銇愰姀鐘茬秮閻庡湱鎳撳▍鎺撶▕鐎ｎ亶妯?*闁?
      //   闁哄啰濮烽弲顐︽儍?`MeshCoverBg` 闁?`playerPane` **濞戞柨顑呴ˇ?*闁挎稑鐗呯粭宀€鈧懓鍟幃鎾剁棯瑜濈槐姘跺焽?閻庣懓鍟╃粭澶愬矗閸屾瑧鐟㈤柟缁㈠幗閺備焦銇勯悽鍨暠
      //   `scale / clip` 闁?閻熸瑥鍊归崝鍛村及椤栨ǚ鍋?*闁告劕鎳庨鎰槹閻愭壆鐟愰柡澶堝劘閳ь兛娴囬崕妤呭疾椤栨瑧鐟濋柛?*闁靛棗绉查埀?
      //   闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉柟璺猴工閻ｇ娀寮ㄩ幆褎韬憸鑸灩瑜板鈧湱鎳撳▍?*闁告劕鎳橀崕?* 闁?閻犺櫣鍠撳鍐偖椤愩倗鎼兼慨锝嗘煥鐢洭宕氶幍顔碱唺 34% 闁告劕绉甸弬浣瑰緞瑜濈槐?
      //   闁活潿鍔嶉崺娑氣偓鍦仦缁佸浜告潏銊π﹂柕?*闁稿秴绻愮敮鍥╃磽閳哄啯鐣遍柤鍐叉湰濞呮瑩鏌ч崫鍕；**闁靛棗绉查埀?
      //   闁宠法濯寸粭?闁圭⒈鍓欓崵顓㈠级閵夈儲鍊甸悗?*濞戞挸绉撮崯鈧悶姘煎亯椤ュ棝宕滈鍡欏炊闁告瑱缍€椤?*闁挎稑鐗婇弳锝囦沪韫囨挸璁查悷娆庣筏缁辨岸鏁嶇仦鎯ь暡濞寸姰鍎遍懜浼村矗濡粯鍩傞柣銊ュ瑜拌尙鎲存担钘夌槺闁搞儲鎸冲?
      //     `backgroundRevealOpacity()`闁? 闁哄啰濮烽弲?`pullBgIn`闁?闁?.30 婵烇絺鈧啿寮抽柨娑橆槺椤?闁炽儲鏌￠埀?濞戞挸瀛╁Λ銈夋偩鐏炶姤鍊遍柛娆欑到缁剁偤濡?
      //   闁宠法濯寸粭?闁稿繑绮岀花宕囦沪閸屾艾绠甸柟鍝勵槷缁?`borderRadius(this.expandState.morphRadius)`闁挎稒纰嶉弳锝囦沪韫囨挾婀村☉鎾崇Ч濞撳墎鎲版担鍛婂閻熸瑦甯囬埀?
      // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗呴幈銊╂偨閵婏箑鐓曢悗鍦仦缁佹挳濡?*闁稿繑濞婂Λ鎾箻椤撶喐鏉归柛锝冨妼瑜把囧嫉婢跺﹤鏁堕悗褰掆偓娑氱獥鐎殿喚娅㈢槐婵嬫嚄鐏炵偓鐝弶鈺偵戝Σ鍛婄▔瀹ュ嫮绐楃€?*闁靛棗绋勭槐姘舵晬?
      //   闁硅泛锕ㄩ崕妤呭疾椤栨稒娈婚悘鐐插€搁〃婊勬交濞戞顏卞☉?*濞戞挸楠搁崬瀵糕偓鍦嚀閹挻绋夐埀顒勫级閳╁啫鐨ㄩ柛?*闁汇劌瀚鎰板闯閵娾晛娅￠柕?
      //
      // ## 闁告鍠愬鍨▔鏉炴壆鐭嗗☉鏂跨墔缁楀顕?
      //
      // 闁稿繗娅曢幐閬嶅绩閹勭彜闁哄啫鐖奸崑鍛▔閳ь剛鎷?鐎?闁?`morphSquashY`闁挎稑鐗忛悵顐﹀触閹存繂绔鹃柟鍏哥筏缁辨碍銇欓崡鐐残楅柣銊ュ缁辨繄鈧懓鍟€垫洟宕?*閻犱警鍨抽弫杈ㄧ珶?*
      //   闁挎稑娼塒laybackPageRoute.ets` 闁?`.scale({y: morphSquashY})`闁挎稑顦粭灞炬交閾氬倻绋戦柡澶嗏偓鑼憪闁?
      //   闁兼澘濂旂粭鍌涚▔閳ь剟骞嶇憴鍕亯闁硅泛锕ㄩ崕妤呭疾?*闁圭⒈鍓欓崵顓熺閸℃鍩岄柛娆惷鎰板闯?*闁靛棔鐒︾€垫洟宕氶悧鍫熸嫳濡炪倕鐏氶悧?`Stack` 闁炽儲鏌￠埀?闁?`Stack` **濞戞挸绉村﹢顏嗘崉椤栨粍鏆犲瑙勫▕閸嬪懏绋?
      //   scale 闁汇劌瀚紞鏃堟偨閵娿儳鍘甸梺?*闁挎稑鐗愰惌楣冩偨閸楃儑绱﹂柣?scale 闁告瑯浜滅敮鍥┾偓鐟板暢閸ゆ粌顔忛柆宥呬簼婵☆偊娼ч悺娆撳冀閹达箑娅￠柣銊ュ缁椼垻鎲查崠锛勭闁?闁告劕鎳庨鎰嚕楠炲簱鍋撴担钘夊壒闁哄拋鍨冲Ч妤佺▔濠靛懐鐟濋柛鏂诲妸閳?
      //
      // ## 闁绘粍婢樺﹢顏堝箑鎼存繄鐤勭€殿喚娅㈢槐娆愮▔閺傝儻鍩岄柣妯垮煐椤掓粎娑甸鍡欑
      //
      // 濠㈣埖鐗犲鐗堢附濡炲墽顏遍悘鐐插€搁鎰板闯椤帞绀夌紓浣圭懃閻?`.height(H 閼?k)` + `.offset({y: 闁愁厽澧?1闁愁厽濮?/2})` + `.scale({y: k})`闁?
      // 濞达絽鐏濋悾鐘绘儍?*閻熸瑥妫滈～搴ㄦ儗閳轰浇鍩岄柟顓熷笧閻℃垶绂?`0 闁?H鐠虹棩閾忓化**闁靛棔妞掔粭?*缂備焦娲滈悰銉╁矗閿濆嫯鍘煫?*闁告ê顑嗘晶搴ㄦ晬?
      // ```
      //   閻㈩垰鍟惇顒勬儗閳轰浇鍩?y 闁?[闁愁厽澧?1闁愁厽濮?/2 , 闁愁厽澧?1闁愁厽濮?/2 + Hk]
      //   闁挎稑娼?offset` 闁告瑯浜濈亸鎾剁磼濡搫鐓戦柣鈺傚釜缁辨紮Alignment.TopStart` 濞戞挸顑嗗﹢顓㈠磻韫囨泤鈺呭籍鐠鸿櫣瀹夊☉?[0, Hk]
      //     闁?闁告垵绻愰獮?H(1闁愁厽濮?/2 鐎电増顨呴崺灞剧▔婵犲洦妗ㄩ弶鈺傜懁闁叉粓宕犲ú顏咃紵闁?
      //   閻㈩垰鍟惇顒佺▔椤撶偟濡?y_c = (闁愁厽澧?1闁愁厽濮?/2 + (闁愁厽澧?1闁愁厽濮?/2 + Hk))/2 = H(2k闁?)/2 = Hk 闁?H/2
      //   `.scale` 缂?*闁煎浜ｉ棅鈺傜▔椤撶偟濡?*缂傚倵鏅滈弬?闁?濞戞搩鍘肩缓鐐▔瀹ュ懎袟闁靛棔绶氶悵顔芥償?閼寸牰
      //   閻熸瑥妫滈～搴㈩殗濡搫顔?= Hk閾?闁靛棔娴囬～瀣喆婢跺鍘煫?= Hk 闁?H/2
      //   闁?閻熸瑥妫滈～?top = (Hk 闁?H/2) 闁?Hk閾?2 = H(2k 闁?1 闁?k閾?/2 = 闁愁厽澧?1闁愁厽濮?閾?2
      //   闁?閻熸瑥妫滈～?bottom = 閻熸瑥妫滈～?top + Hk閾?= H(2k 闁?1 + k閾?/2 = H(1+k)閾?2 闁?H
      // ```
      // **濞戞挶鍊楅顒勬焾閹存帒绱柡宥呭悑椤掓粎娑?*闁挎稒鐡猭 = 1` 闁?`[0, H]`闁? 闁轰焦娼欓惈鍡涙晬瀹€鍕ㄥ亾閹邦剙鍓肩紒杈╁Х閻℃垶绂掗崙銈囩闁?
      // `k = SQUASH_Y` 闁?閻熸瑥妫滈～搴ㄦ儗閳轰浇鍩岄柟顓熸緲閵堜粙寮?缂備焦娲滈悰銉╁矗閿濆嫯鍘煫鍥у暞婵＄顭ㄩ垾宕囨綄闁告ê顑呴崺?k"闁汇劌瀚划銊╁几濠婃劗绐?
      //   `(H 闁?Hk)/2 = H(1闁愁厽濮?/2`闁炽儻鑵归埀?濞寸媴绲介崣?`k` 闁告牗鐗滈悾婵嗩嚗?`閻熸瑥妫滈～?top = H(1闁愁厽濮?閾?2`闁?
      //   闁?缂備焦娲戦懙鎴ｇ疀閸愩劌绔鹃柛?k"闁?top 闁?`H(1闁愁厽濮?/2` 闁?濞戞挶鍊涢埀顒€鎳庡﹢?`k = 1` 濞?`k 闁?0` 濠㈣泛瀚粩鎾嚊濞ｎ兘鍋?
      //   濞戞搩鍙冨Λ鍧楀箑娴ｈ浠樺鑸佃壘濡?`H(1闁愁厽濮?(k)/2`闁?
      //   闁宠法濯寸粭?**閺夆晜鐟﹀Σ鎼佸嫉椤掍緡鍋ч柛鐑嗗灟缁斿瓨绋夐埀顒佸緞?閺夆晜鍨抽幎鈧?**闁挎稑鑻々褏鈧湱鍋熷▍銉ф媼鐢喚绐楅梻鍫熺懄椤掓盯骞€娓氬﹦绀刞k = 1`闁?*闂侇偅鍔曢崕姘辨閻樿京鐟濋柛?*闁哄嫷鍨崇€涒晝鐥崠锛勭
      //     鐟滆埇鍨硅ぐ澶嬬▔椤撱垺锛熼柟顑跨窔閸嬪懘宕?vp 闁汇劌瀚禍绋款啅椤旀娲ｅ☉鎾筹攻濠р偓闁?闁炽儲鏌￠埀?闁兼眹鍎冲﹢锟犲嫉鏉炴壆鐟?闁告ê顑囩紓澶愬籍閹澘鍓归柡鍜佸灟缁楀倹绋夌€ｎ喗鑻熼弶?闁?
      //     閻忓繗椴告俊?`.scale` 闁瑰箍鍨洪崹?`.scale({centerY: '50%'})` 濞戞柨顑呴ˇ濠氭儍閸曨偄缍楀☉鎾亾闁哄銈囩唴闁挎稑鐗忛弫銈嗙▔閵堝懐婀撮悷浣风婢光偓閻炴稏鍎辨导鈺呮晬婢舵稓绀?
      //     闂侇叏绲惧鍌炲礃瀹ュ棙鏆柨?*濞戞挸绉烽々锕傛偝閺夋寧韬柛鎴幘鐎典粙宕濋悩鑼煑闁?*闁?
      // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨偆婀寸紒?*闁挎稒淇洪崕妤呭疾椤栨碍绀€闁告帗婢橀懜浼村矗濡警鍟囬柛?*闁告劕鎳橀崕?*闁?
      //
      // ## 闁瑰瓨鍨崇粻锝夊礈瀹ュ鏅╅柛锔哄妼閹姐垽鏁嶉崼锝囩闂佹寧鐟ょ粭浣规姜椤曞棛绀夐柣顫妽閸╂盯宕跺☉娆樺仹閻庡湱鍋炵粊鎾箥閹捐櫕绀€闁?
      //
      // 闁瑰瓨鍨崇粩鎾儎缂堢姳绨板☉鎾跺劋濡倝鎮惧畝鈧▓?`MeshCoverBg` 闁?`playerPane` **濞戞柨顑呴ˇ?*闁挎稑濂旂花顒勫及椤栨稑惟閻庣懓鍟幆澶愬礆閻楀牊鎷卞銈呯仛閻?`Stack`
      // 闁?閻?*濞寸姴娴烽鍥ㄧ▔閳ь剛鏁濮樸劑寮弶鎴犳綄**闁靛棔娴囬埀顒€濂旂粭?*閻熶椒妞掔粭澶愬礆?*闁靛棗鍊婚弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳?*闁圭虎鍘介弬渚€宕抽妸銉ф綌鐎殿喒鍋撻弶鈺偵戝Σ鎼佹嚄鐏炵偓鐝柛蹇嬪妼閻?*闁靛棗绉查埀?
      //
      // 闁哄牜鍓濋悿鍡涘箮婵犲啯锟ラ柣锝呯灱濞?*閻庡湱鎳撳▍鎺楀冀?*濞戞挴鍋撻悹渚灥椤曚即鏌呭顐ゅ晩闁挎稑娼墂ujie.pa`闁挎稑顧€缁?
      // ```
      //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   闁?闁?Stack
      //   @36***# (191388)  Stack(TopStart)
      //                       .scale({x: expand.scaleValue, y: 闁炽儺娲?      191400-191415
      //                       .translate({x: expand.translateX, 闁炽儺娲?     191416-191431
      //                       .width(expand.clipWidth)                  191432-191441
      //                       .height(expand.clipHeight)                191442-191451
      //                       .borderRadius(expand.radius)              191452-191461
      //                       .clip(true)                               191462-191469
      //                       .id(PLAYER_ROOT_ID)                       191470-191478
      //                     闁宠澹曢弨?If (191716 @36***#^4 闁?@36***^4*#/^1)
      //                     闁?   闁宠鏌￠弨?Column (191756 @36***#^5)
      //                     闁?        闁宠澹曢弨?If (191972 @36***#^7 闁?@36***^7*#)  = **playerPane**闁挎稑婀﹐w闁?
      //                     闁?        闁宠鏌￠弨?If 闁?**MeshCoverBg**              192105 / 192191
      //                     闁宠鏌￠弨?闁?
      // ```
      // 闁?**`MeshCoverBg` 闁?`PLAYER_ROOT_ID` 闂侇叏绲奸柌?Stack 闁汇劌瀚伴崳鐑芥?*
      //   闁?閻?*閻犺櫣鍠撳鍐偓鍦嚀濞呮帗绋夐埀顒傛導?scale闁靛棔妞掔粩瀵告導閻ゎ垼娼?clip**闁?
      //   閺夆晜鐟ュ銊╁及?閻忕偞娲栫槐鎴﹀籍閹澘鍓归柡鍜佸灟缁楀瀵煎顓熸閻忕偛绻堥埀顑挎祰閳ь剙鏈Σ鍛婄鎼达紕姣堢紒鎰殔瑜版盯鏌屽畝鍕瘣闁告垹鍎ゅ?闁汇劌瀚┃鈧柛鎺曠堪閳?
      //
      // 闁宠法濯寸粭?闁瑰瓨鍨崇粭鍌涚▔閳ь剟鎮ч崼銉ヤ簼闁?闁哄啰濮烽弲顐︽儍?MeshCoverBg 闁?playerPane 濞戞柨顑呴ˇ濠氭晬閸粎鐟㈤悗鐟板暙閹挾鐥缁?**闁哄嫷鍨堕弫濠囨儍?*闁?
      //   闁哄鍎茬花顕€寮伴姘锭闁活亜顑勭花锟犳偋閸ヮ煈鍞介柕鍡曠劍閻ュ懘骞?`PLAYER_ROOT_ID` 闂侇叏绲奸柌?Stack 闁?*闂傚偆鍘奸幃搴ㄦ嚑閸愩劍绾?*閻犲洩顕ч崵顓㈠级閵夛絺鍋?
      //   闁挎稑娼塕zdMusic閻犱焦婢樼换?md` 閹?6.50 闂佹彃濂旂弧鍐及椤栨繄绠瑰☉鏂跨墕閸熸捇鎯?闁炽儲鏌￠埀?濞戞挴鍋撴鐐存构缂嶆梹鎯旈悢绮瑰亾閸岋妇绀?
      //
      // ## 闁圭⒈鍓欏ú鏍储鐠佸磭顓洪柛姘閹捇寮幆闈舵帡宕樺畷鍥ㄧ暠濞戞挶鍊撳▎銏＄?
      //
      // 1. **閻忕偞娲栫槐鎴炵▔瀹ュ懎鏅?闁煎啿鏈▍娆撳礂閵娿儳娼?**闁挎稒鑹鹃懜浼村矗濡粯鍩傞悗鍦嚀濞呮帡宕ｉ鍛畳閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞柨鐗嗛妵?闁?闁煎啿鏈▍娆愮▕閻斿嘲娑ч柛锔哄姂閸嬪懏绋夐埀顒備焊韫囨挻鍋ラ梺鎻掔焿缁?
      //    闂傚懎绻愰鎰板闯閵娾晜姣愬鍫嗗棌鍋撳畝鍕嚈鐎殿喒鍋撻柨娑樼墣缁绘牠骞嶅鍡樞?濡炲鍋樼粭鍌炲级?闁汇劌瀚～鍥箛閻曞倻绀嗛柨?
      // 2. **闁稿繑濞婂Λ鎾籍閹澘鍓归柡鍜佸灥缁愶繝鎯堥埀顒佺▔閳ь剛鎸у畡鏉跨**闁挎稒鑹鹃鎰板闯閵婏附鎷遍柡澶堝劚濮樸劑宕烽妸銊х唴闁汇垹宕敍鎾绘焽閿濆棙钂?`morphSquashY` 闁汇劌瀚紞鏃堟偨閵娿儳鍘甸梺?
      //    闁挎稑娼塒laybackPageRoute.ets` 闁?`.scale({y})` 闁告ê顑嗛弳锝嗙▔椤忓懏灏￠柡鈧ィ鍐︹偓澶愭晬婢跺棗娅?**濞戞挸绉撮崯鈧梻鍥ｅ亾閻熸洑鐒﹂崹婊勭▔婵犱胶顏遍柣?
      //    闁告梻濮峰▓鎴︽焽閿濆嫰鍤?`.scale + height + offset` 閻炴稏鍎辨导鈺冣偓鍦嚀濞?*闁挎稑鐗嗛崙锟犲礆閻樼粯鐝熼柨娑樼焷椤?`squashWrapHVp` 闁汇劌瀚崹褰掓⒔閵堝牜鍞剁憸鐗堟穿缁辨岸濡?
      Column() {
        // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨収鍎戝☉鎾愁槸閻媽銇愰姀銏犘?*闁挎稒鑹鹃崬瀵镐沪?`Stack` 濞戞梻鍠庣换鈧銈囩帛濡?`TopStart`闁?
        //   闁哄啰濮烽弲顐︽焽閿濆娅￠柡鍕靛灟缁旀挳宕?`Column闁挎稑鐗嗛?100% + winHVp + padTop/padBottom闁挎稑藝 闁烩晛鐡ㄧ敮鎾锤閹邦剚韬?
        //   `Stack(TopStart)` 闂?闁炽儲鏌￠埀?**婵炵繝绀佺槐锛勨偓娑欏姌婵☆參鎮?*闁靛棔绀佸ù鎰偓瑙勬皑閻涖儵宕ｉ敐澶屽蒋闁靛棗鍊归崹婊勭椤掑啰绠归悘鐐插€哥敮顐﹀级閵夛附笑濮掓稒顭堥?
        //   闁挎稑娼塁enter`闁? 閻庣懓銇樼€?`.position(0,0)`闁挎稑濂旂粭灞剧▔婵犲啰鍩楀☉鎾崇У濡叉悂宕ョ仦鑲╊伇濞戞搩浜滈懜浼存偐闊祴鍋?
        //   闁?闁衡偓鐟欏嫬鐏?`TopStart`闁挎稑鑻鏍ㄧ▔閼姐倖鐣遍柛銉ユ惈閻ｅ墽浜搁崫鍕靛殶闁归潧绉靛﹢渚€骞囪箛搴ｇ枀闁挎稑鐗婇惀鍛村嫉婢跺﹦鏆婇柨娑樿嫰濞存劗鈧宀搁悵顕€鎯冮崟顐妷閻庢稒鍔掔槐鎵偖椤愩垻婀峰☉鎿冨幗鐏忔挾鎸х敮顔剧闁?
        Stack({ alignContent: Alignment.TopStart }) {
          // 闁?闁煎啿鏈▍?= **闁告锕埀顒€绻戝Σ?闁?濞戞挸绉归埀顒€绻戝Σ?*闁挎稒鑹剧花鎶芥嚌闊厾鐟㈤柛娆愮墳婢瑰﹦浠﹂崒娆戭伇閻犙呮焿閾斿宕ｅ鍥╂そ閻犲洦鍨瑰▓?
          //   `pullBgIn = clamp(effT / 0.30)`闁? 闁?0.30 婵烇絺鈧啿寮抽柨娑橆槶閳?
          // 闁宠法濯寸粭?濞戞挸锕浼存焽閿濆嫯鈷堥柛娆嶅劵缁?閹煎瓨娲濇竟濠冪▔鎼粹€崇悼闁艰褰冮惇鐗堢▔閳ь剛鎸ч悿顖濇巢 `pullBgIn`"闁挎稑顦Σ?**鐎规瓕寮撶紞鏃€鎯?*闁?
          //   闁?2026-10-15 閻犙冨殩缁辨繈鏌囬敐鍕拡閻?*闁轰焦娼欓惈鍡欑棯椤栨繂顥忛悘鐐插€搁崙锛勭磼韫囨梹娈婚悘鐐插€搁崹褰掓⒔?*闁挎稑鐗呯粭鍛存閵忕姵鐨戦柡鍕靛灠閸ㄥ綊姊介妶鍛€甸柣銊ュ楠炲洭宕烽悮瀵哥闁?
          //
          // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*闁哄啰濮烽弲顐⑩柦閳╁啯绠掔紒缁㈠灥婢瑰﹪宕归銏亢闁挎稑鐬肩紞澶愬冀閸忓吋鎷遍棅顒夊亜濮樸劑寮伴姘变亢**闁?
          //   濞撴碍绻冨畵?`_recover/logic-src/闁哄啰濮烽弲鐜絪婵炴煡绠栭悡?鐎瑰壊鍠栫槐鎾诲礆閸℃鈧?md` L303-304闁?
          //     闁?闁靛棗鐣瑿olumn().backgroundColor('#1c1c1e').opacity(...)` 閺夆晜鍨跨划锕傚垂椤愩垻淇洪悘鐐插€堕埀顒€绉崯?闁哄啰濮烽弲顐ｇ瑹?**闁?*闁?
          //     闁?闁靛棗鐣瑿olumn().backgroundColor(state.imageColor)` 閻忓繋绶氬浼村矗閺嶃劎澹夐柤瑙勫絻閻即濡村浣告櫔 **婵炲备鍓濆﹢浣衡偓鐢垫嚀缁ㄦ煡鎮?*闁?
          //   濞戞挶鍊曢惇浼存焾閼恒儲笑婵炴煡绠栭悡鍫曞籍瑜戦惌楣冩晬濞戞鏆婂ù鐙€鍓欒ぐ鏃堝捶閵娧呯Ч闁哄秹妫跨粻锝嗙▔鐎ｅ墎绀夐柛娆樹簷缁辨壆鎷?閻忕偞娲栫槐鎴濐嚕閳ь剚鎱ㄧ€ｎ喖浜濆☉鎾亾闁?濠㈣埖鑹鹃崵顓熺▔閳ь剟宕稿Δ鍐х礂闁哄棙顨堥崓鐢碘偓?
          //   闁挎稑鐗愰～?`backgroundRevealOpacity()` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柕?
          //
          //   闁?闂侇叏绲介惇?闂傚牊鐟﹂娑㈠箑娴ｉ鐟濋梺顐㈢箲濡叉垶鎯?闁绘粍婢樺﹢顏堝箹椤掆偓閸╁本绂?*閻犱警鍨抽弫杈ㄧ珶?*濞戞挸顭槐娆愭交濞嗘劖笑闁哄啰濮烽弲顐︽儍閸曨亞绉寸紓鍐惧櫙缁?
          //     `wujie.pa:190867-190884` 闁?`.backgroundColor(pullMode && effT()>=1 ?
          //     PULL_REST_BG : expand.overlayColor)`闁挎稑顧€缁辨繈鎷冮悾灞戒化閻?
          //     `PlaybackPageRoute.ets` 闁?`PlaybackPageRouteShell`闁?
          //       鐠?鐟滆埇鍨硅ぐ澶愬嫉閻斿皷鍋撹箛鏃€顫?闁?缂佹劖顨呰ぐ娑欏緞閺嶎厸鍋撹箛鎾虫瘔濡絾鐗犻妴澶嬬▔鎼淬倗纰冨ù锝囧У濞碱垶鏁嶉崼婵婂煂闁告瑦顭囧▓鎴﹀礈瀹ュ棗绲归柨娑橆檧缁?
          //       鐠?闂傚牊鐟﹂娑㈠箑娴ｉ鐟濋梺顐㈢箲濡?闁?闁圭虎鍘介弬浣广亜娴ｅ啫娈扮€规瓕浜▓鎴炴償閺囶亞绀夊銈呮惈閻㈩偊鎯勯弽锔剧Ф闁绘鍩栭埀顑跨劍閻栴喗绋夋惔锛勪亢闂侇喓鍔戦崑鍛▔閵堝棙钂?
          //         闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鑻崬瀵糕偓纭咁潐閻ュ懎顕欓張闈涘殤閺夆晜绋撴慨鎼佸箑娴ｅ湱鍩夐柕鍡楃Р閳ь剙鑻花鎶芥焾閵娿倗顏遍柡澶涚磿閳规牠鎯傞懞銉х闁告垵鎼幃妤呮閵忕姴鏁堕悗鐟扮畭閳ь剙绋勭槐姘跺Υ?
          //     闁?闁圭鍋撳ù?*濡炪倗鏁诲浼村礃閸涱剛鐟濋柛鎰Ч濞撳墎鎲?*濞寸姾顔婄紞宥夊极閺夋垹娼岀紒缁㈠灥婢瑰﹦浠﹂崒锔剧闁告帞濮电敮鈧悗鐟板暕缁楀瀵煎顒€姣夐柣?闁煎啿鏈▍娆戠矚鏉炴壆顏遍柛?闁?
          //
          //   闁宠法濯寸粭?濞戞挸顑夊鎵磾閹寸偟澹愰梺顓ㄧ到閻即鎯?`backgroundRevealOpacity()` **濞ｅ洦绻勯弳鈧?*闁挎稒鑹鹃悾鐘典焊鏉堛劍笑闁哄啰濮烽弲顐︽儍?`pullBgIn`
          //      闁挎稑鐗愰幑锝夋倷?0闁靛棔娴囩粣锟犳儓閳ь剝銇愰姀鐘茬秮閺夆晜绋戠€规娊宕?1闁挎稑顧€缁辨繈妫冨▎鎰靛壘闁诡兛鐒︽禍鑺ョ▔?1闁?

          // 闁宠法濯寸粭?缂佹瘱鍥吂闁稿繗娉涢幃妤呮儍閸曨垰浜濇繛?閻庡湱鍋炲鍌毼熼敍鍕囬幖瀛樻礀濞?閻犲洤鐡ㄧ涵鍫曞煡?**濞戞梻鍠庨崙鈩冩媴濠婂啰鐔?*闁挎稒宀搁崑鍛嚕?`Image(閻忓繋绶氬?.blur(11)`
          //   鐎圭寮堕弳锝囦沪閸屾艾鐏╅梻?闁炽儲鏌￠埀?閻庣懓鍟敮顐﹀礂閸繂娑уù?缂傚啯鍨堕悧绋库攦閹邦喖绻侀悽顖ｅ幗濡炲倿鎯冮崟顐㈠箲閹?闁挎稑鐭侀埀顒€鑻崢瑙勬償閺囩姴绠涢柛锔哄妽閺佸ジ骞嬮幇顏嗗晩**缂佺虎鍨拌ぐ鍥冀閻ゎ垰顥?*
          //   闁挎稑鐗愰～鍡樼▔鐎ｎ喗妗?`else` 闁告帒妫欓弫顕€鏁嶆径鍫氬亾閸屾艾鐏╅悗鐟板暟濞堟垿宕㈤悢閿嬬闁挎稒鑹鹃悾鐘电驳婢跺鑹?*闁革负鍔庣紞澶愬冀闂傚顓哄鑸电墪瀵敻鎮界拋宕囧晩濞戞挴鍋撶€殿喚濮撮惃婵嬫?*闁?
          //   闁瑰箍鍨哄鐢告偨閵婏箑鐓曢悗鍦仦缁佹挳鎯冮崟鈹惧亾瀹€鍕簼濞戞搩浜欑悮鍗烆嚕閻樿尙娈遍梻鍫涘灩瑜把勫濮橆剚韬柛鏂诲妿閺佺偓娼婚崶鈹炬煠濞戞搩鍘奸崵顓㈡偝閼割兘鍋撳鍐ｅ亾?
          //   闁?`backdropBlurRadiusVp()` / `LIVE_BACKDROP_BLUR_VP` / `originalCoverSource()`
          //     闁绘粍婢樺﹢?*鐎圭寮跺Λ銈囨嫬閸愵亝鏆忛柤?*闁挎稑鐗忛弳鈧柛锔哄妽閺嬪啯绂掗崼鏇炴闁哄嫷鍨拹鐔哥閸℃洜鐟濋柣妤呮涧婵?`isPixelMapCover` 闂侇叏绲惧顖滅尵鐠囪尙鈧兘宕氶崱妯绘殰闁?
          //     閻庣懓鍟╁鎴︽儍閸曨剚娈诲ù锝嗘尰缁斿鎮堕崱妤冪Ш闁?闁告帞濮靛ǎ鎶芥閹舵垝绮ｉ柣?闂侇叏绲肩粩鎾锤濡ゅ绀夐悷?`RzdMusic閻犱焦婢樼换?md` 閹?6.6闁挎稑顦埀?
          // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁嶅鍐插壒闁哄拋鍨扮花铏償瑜庡畷鏌ュ箣?**缂傚啯鍨堕悧姝屻亹閵忕姴缍侀柤鍐叉湰濞?*闁挎稑娼塎eshCoverBg`闁挎稑顦埀?
          //   閻熸瑥瀚悧鎼佹晬濮濇瓨recover/logic-src/闁圭虎鍘介弬浣广亜娴ｅ啫鍓归柡?MeshGradient濞戞挸鎳俥shSource閻庤姘ㄩ…?md`
          //   闁挎稑娼塎ESH_SUB=4`闁靛棔姊桽RC_EDGE=64`闁靛棔姊梑oxBlur(9,3)`闁靛棔姊梔isplaySync` 20fps闁靛棔绶氬鍕⒒?= `playing && active`闁挎稑顦埀?
          //   閻庣懓鍟抽崵婊呮暜?*鐎垫澘瀚幃婊堝汲濡ゅ嫷娼?*闁挎稑娼塻crim` 濮掓稒顭堥?true闁挎稑顧€缁辨繈骞嶉埀顒佺閵夈倗鐟撻梻鍫涘灲閸嬪懐浠﹂崒婊冾仾缂佹柨顑囧▓?`radialGradient`
          //   闁革负鍔庣紞澶愬冀閼测晜鏅搁柡浣哥墛濡炲倽绠涢崨娣偓蹇涘礂閾忣偄绔撮柨娑樿嫰閹線宕氬▎搴ｇ獥闁告瑧濮崇悮杈ㄧ閼恒儲顔傞悷娆愬竾閳?
          //   闁宠法濯寸粭?缂傚啯鍨堕悧绋库攦閹邦垳绠锋繛灞糕偓宕囩处濠靛倹鏋荤槐娆撳箲閵忥紕鎽冮梺顓ㄧ导缁旀挳鎯夐濠勭闁?*闂侇偀鍋撻柛銉у仜閻ゅ嫰寮懜鐨勪胶鍖栨繝鍥т簼鐎殿喚濮村ù?*闁挎稑濂旂粭澶嬪濮橆剙姣夐柣?闁煎啿鏈▍娆戠矚鏉炴壆顏遍柛?闁?
          // 婵炵繝绀侀崢婊堟嚄鐏炵偓鐝柨娑樼墣椤旀洜绱旈鈧妴宥咁嚕閳ь剟宕楃粵鍦闁挎稒鑹剧换鈧銈堫嚙濠€顏堝礃閸涱収鍟囬悘鐐插€风粻锝夊礈瀹ュ洨甯涢柛鎺曨啇缁辨繈宕ラ敃鈧崹顖涘濮樿鲸纾板ù锝呯箰閻ㄦ繈妫冮姀鐘冲婵繂鐭侀惁?
          if (this.flowLightState.enabled && this.tintReady) {
            this.FlowLightBackground()
          }

          // 闁宠棄鎳夊Σ?2026-10-15闁?*鐎垫澘瀚幃婊堝汲濡ゅ嫷娼?*闁挎稑娼夐柡鍐Х閺呯幗s婵炴煡绠栭悡?鐎瑰壊鍠栫槐鎾诲礆閸℃鈧?md` 閹?.4闁靛棗鑻顔筋瀲閹邦剛绱﹂悹?鐠?闁?闁告瑯浜滄慨鐐差嚗閸曨偅鍊婚柡鍡橆殙椤濡村蹇曠闁?
          //   閺夆晜鐟ょ粩鎾级閳╁啯笑闂侇叏绲奸崬銈夊棘閸ャ劊鈧倻绱掑▎鎴炵暠**闁哄牃鍋撻悘蹇撶箺閻墽鐥?*闁挎稒姘ㄩ崙鑺ョ珶閻楀牊顫栫€殿喖绻堥埀顑跨窔濞村倿寮０浣鸿穿閻犙勭墦閳ь兛鑳堕悵娑㈠礆鐠囨彃璁查柟?
          //   闁炽儲鏌￠埀?濞?缂傚啯鍨堕悧绋棵规担绋啃楅柤鍐叉湰濞?闁挎稑娼塎eshCoverBg`闁挎稒鐡狽odeContainer` + 闁煎浜滈悾鐐▕?`RenderNode.drawPixelMapMesh`
          //   + `displaySync` 闂侇偅鍔曢幎姘亜閸撲礁浠柨娑樼焷椤?`闁圭虎鍘介弬浣广亜娴ｅ啫鍓归柡?MeshGradient濞戞挸鎳俥shSource閻庤姘ㄩ…?md` 閹?闁?*闁告帒妫楃槐?*闁?
          //   闂侇叏绲介〃婊堝嫉椤掑啰鏋?*濞戞挸绉存禒?*闁挎稑鐭佺换鏍煂鐏炶棄娑ч柛娆戝С缁斿浠﹂崒姘辩獮闁告碍鍨电敮鍥汲濡炲皷鍋?
          //
          //   闂侇偅鍔欓妴宥夊极閺夊簱鍋撴總绋垮幋闁告瑦鐗為崵婊堝棘閸ャ劊鈧倿鏁嶉崸鍒愰柛妤佹礃缁ㄧ敐`闁挎稑鑻崵顓熷緞閸曨偄鏅搁柡鍕凹娴滄帗绗熼崹顕呮Щ闁哄秹娼荤槐姘舵晬?
          //   `闁哄啰濮烽弲鐜絪婵炴煡绠栭悡?鐎瑰壊鍠栫槐鎾诲礆閸℃鈧?md` 閹?.4 缂備礁瀚▎銏ゅ冀閹寸偞姹為悶娑樺缁楀矂濡寸仦鍛婂櫍闁靛棗绉归崑鍛▔閳ь剙鈻?闁炽儲鏌￠埀?闁哄啰濮烽弲?
          //   `MeshCoverBg` 闁?`Stack` **闁哄牃鍋撳☉鎾筹躬濞?*閻忓繗椴稿Σ鍛婃交濞嗗海顏遍悘?`Column().radialGradient(...)`闁?
          //   闁兼澘鏈崹婊勭椤掑倹鐣?`Stack` 闂?闁告劕鎳庨鎰沪?闁挎稑娼塨uildControlStack`闁挎稑顦弧鍐及椤栨稒浠橀柛姘捣閺侀箖鎯冮崟鈹惧亾?
          //   闁?濞戞捁妗ㄧ花鈩冪▔瀹ュ懏鍊栭柛鎺撴緲閸炲鈧湱鎳撻惇浼存晬瀹€鍐闂佹彃鏈弬渚€宕?*閻忓繋绶氬鐗堟償閺囩偞绂堥悘鐐插€风粻锝夊触?* 闁炽儲鏌￠埀?閻庣懓鍟﹢顏堝冀閸儱娅￠柣銊ュ缁垶宕氶張鐢电Т缂?
          //      濞戞挸瀛╁Λ銈夋偩?闁告ê顑呭﹢顏堝极缂堢娀鍤嬮柤鍐叉湰濞呮瑦绋婄€ｂ晝鐟愰柕鍡曠閸炲鈧綊鈧稓顓哄☉?闁汇劌瀚銏＄▕婢跺瞼鎼煎ù鐘插殩缁辨瑩寮悩鍨珪闂侇叏绲肩粩瀵镐沪閸屾瑧顓哄☉鎾愁儐濡插摜绱旈幋鐐靛闁煎啿鏈▍娆撴晬?
          //      闁瑰瓨鍨冲鎴︽儍閸曨偄鏁堕悗鍦嚀閻即寮?*濞戞挸绉归埀顒€绻戝Σ?*闁汇劌瀚€氼厾绮╃€ｎ亞婀撮柨娑樺缁楀宕ｅΔ鈧悾鐘恒亹閸楃偞鎯欓柨娑橆槶閳?
          //   鐠?`center: ['50%', '50%']` 闁炽儲鏌￠埀?闁革箑妫楃缓楣冨捶閵婏富鍔€濞戞搩鍙忕槐娆撳棘閸ャ劊鈧倿宕ョ仦绛嬫П闁挎稑顧€缁?
          //   鐠?`radius: '70%'` 闁炽儲鏌￠埀?闁哄倸娲﹂妴鍌炲触鐏炵瓔妲遍柨娑欑☉閻ｅジ寮?`ts-universal-attributes-gradient-color`
          //     闁?026-10-15 闁告瑦鐗滃▓鎴﹀储閻斿憡鐎柨娑橆檧缁变即濡寸仦鐣岀獮闁告碍鍨剁粭搴ㄥ矗濡吋鐣遍柛妤€锕ょ欢鐐烘晬鐎圭椃mber 缂侇偉顕ч悗鐑藉籍鐠哄搫绀嬪ù锝呯С鐠?vp闁?
          //     閻犱礁澧介悿鍡涙儍閸曨偀鍋撻梻纾嬬 undefined 闁哄啫澧庨柈瀵哥磼閻旂鐦荤紓浣稿濞嗐垻浜搁崫鍕靛殶闁煎浜滄慨鈺冪不濡炲皷鍋撳浣告 閺夆晜鐟╅崳椋庣磼?*闁谎勫劤閸ㄥ骸袙閺傝法鎽熺紒妤嬬細鐟?*闁?
          //     闂傚懎绻愰鎰板闯椤帞绀? 闁轰焦娼欓惈鍡涙晬婢跺氦娉查柨娑樺缁楀寮伴姘ゼ閻?vp闁?
          //   鐠?`colors: [['#26000000', 0], ['#26000000', 0.45], ['#66000000', 1]]`
          //     闁炽儲鏌￠埀?闁哄倸娲﹂妴?閹?.4 閻㈩垱鎮傞崳铏规偘椤帞绐梎SCRIM_CENTER = "#26000000"`闁挎稑鐔傞幍浣割暭15%闁挎稑顦埀?
          //     `SCRIM_EDGE = "#66000000"`闁挎稑鐔?40%闁挎稑顧€缁辨繃绋夐鐐靛闁肩寮撶粩鎾儎閹绢喗鎳欓柛鎺撴緲瀹曟劕顕ラ崟顓熺暠 45% 闁归潧绉寸槐鎴炴叏鐎ｎ亜绔鹃柡鍡橆殣缁?
          //     闁挎稑鐗嗛悿鍕偝娴兼潙娅￠柛鎰懄閸ㄦ氨绮垫径濞惧亾閼测晜鐣遍柛妞剧閸欐碍娼诲☉妯虹厬閻庢稒顨婂浼存煂?`0x26/0x66`闁挎稑濂旂粭宀勫触鐏炵偓鐎ù鐘烘硾閸欑偓鎷呭▎鎰懁闁?閹煎瓨娲濇竟濠囧礃濞嗘劗銆婂☉鎾亾闁奸攱鐣埀顒€鍋婄槐?
          //   鐠?闁肩懓寮堕悥锝夋儍閸曨収鍎戝ù婊冨闁叉粓宕楅崘顏嗩槺闁?*婵絾鏌х欢?[0,1.0]**闁挎稑濂旂粭澶愬及?vp 闁炽儲鏌￠埀?閺夆晜鐟ょ粭浣瑰緞?0 / 0.45 / 1 闁哄牜鍓氬鐢典焊鏉堛劍笑
          //     婵絾鏌х欢銉╁礃濞嗘劗銆婇柨娑樼墕閹?閹?1.1 闂侇叏绲惧顖炲础閺囨氨绉撮柛褎鍩婄槐杈┾偓瑙勆戦弻鐔煎储閻斿憡鐎柕鍡楄嫰瑜板洭宕愰懝鏉跨槺闁搞儳绻濈拹?[0, 1.0]闁靛棗绋勭槐姘跺Υ?
          //
          //   闁宠法濯寸粭?濞戞挸瀛╁Λ銈夋偩瀹€鈧▓鎴炵▔閳ь剚寰?*鐎规瓕灏欓悡鈥愁啅椤旂厧鐒?*闁挎稒纰嶅Λ銈夋偩瀹€鍕簼濞戞挴鍋撻悘鐐插€瑰Σ?*闁诡厽甯掔槐?*闁挎稑鐗嗚ぐ褔鎮?`scrim` 閻㈩垰鍟惃鐢告⒒閵婏箑浠橀柨娑橆檧缁?
          //      闁瑰瓨鍨冲鎴炴交濞嗘挸娅￠柛?*鐟滆埇鍨硅ぐ?閺夌儐鍓欏┃鈧柡鍫㈠枛濡潡宕楅搹顐㈢**闁挎稑鐗嗛ˇ鏌ユ偨?`backgroundRevealOpacity()` 闁告艾鏈娆撴儍?
          //      `morphContainerActive()` 闁告帇鍊栧畵渚€鏁嶆径鍡忓亾閺傝　鍋?闁告熬绠戦崹顖濄亹閵忕姴缍佸☉鎿冨弮閸嬪懏绋夐鍥舵蕉 scale+clip 闁汇劌瀚惃顒傜玻濡も偓瑜版盯鏌?
          //      濞村吋鑹鹃ˇ鎸庣▔閳ь剛浠﹂崒姘闁哄棙顨愮槐婵囩▔?闁告锕埀顒€绻戝Σ?闁?濞戞挸绉归埀顒€绻戝Σ?闂侇叏绲惧顖炲籍閵忊剝绠掗柛娆欑到缁剁偤骞嶉幘瀵镐桓闁?
          //      閻熸瑥鍊归崝鍛村及椤栨碍鍎婇悷鏇氱劍閺佸ジ骞嬮幇顓濊埅鐎殿喒鍋撻柨?*闁告瑯浜ｉ崗妯荤▔婵犲啯绨氶柣?*闁挎稑鐗愰～鍡涘嫉椤掑啰鏋傞柟韬插劚閹诧繝鎯?闁告瑯浜ｉ崗妯荤▔婵犲啯绨氱痪顓у枦椤?婵炴挸鎳庡畷鐔兼晬婢跺牃鍋?
          // 闁?缂傚啯鍨堕悧鎼佹嚄鐏炵偓鐝柤濂変簻閻㈩偊寮冲Δ鍕垫健 闁?闁告瑯浜濆﹢?*闂侇偀鍋撻柛銉у仦鑶╃紒顖氾工缁ㄦ娊宕?*闂侇叏绲惧顖滄崉椤栨稑顤呴梻鍥ｅ亾閻熸洑娴囩换鏍ㄧ▔閳ь剛浠?
          //   闁挎稑鐗嗛幆渚€宕氬▎搴ｇ獥闁告瑧濮崇悮杈ㄧ閼恒儲顔傞悷娆愬釜缁辨繃绋夐鐐靛閻炴凹鍋勭敮鍥ㄧ▔閵堝鎲鹃柨娑橆槶閳?
          if (this.meshSrc === undefined) {
            Column()
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .radialGradient({
                center: ['50%', '50%'],
                radius: '70%',
                colors: [[0x26000000, 0.0], [0x26000000, 0.45], [0x66000000, 1.0]]
              })
              // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛弫銈夊箣閸戙倗绐楅柕鍡楀缁楀倿骞忔径瀣叺鐎殿喒鍋撻柡鍫濐槼閸庢寮查銈囩**闁绘劗鎳撻崵顔句沪閺囩偟纾?/ 闁稿繑濞婂Λ?/ 缂侇垵宕电划鐑樻交閺傛寧绀€婵炲备鍓濆﹢渚€鎳楃仦鐐彲**闁靛棗绋勭槐?
              //
              // ## 闁哄牆鎼崺妤呮晬閸綆鍤㈠ù鐙呯悼閻?+ 濞戞挶鍊撻柌婊呮嫚缂佹ɑ娈堕柛妤€鍟跨欢閬嶆晬?
              // ```
              //   缂傚啯鍨堕悧鍝ヤ沪閸屾稒笑 `if (meshSrc === undefined) { 闁稿繑绮岀花?} else { MeshCoverBg(...) }`
              //   闁绘劗鎳撻崵顔句沪閺囩偟纾?/ 闁稿繑濞婂Λ鎾矗閹寸姵鏅哥€电増顨嗗Λ顓㈡晬鐏炵虎鍔冮柡?`song.cover` 閺夆晜蓱閻ュ懘宕氶悧鍫濐杹 闁?meshSrc === undefined
              //   闁?缂傚啯鍨堕悧鍛婄▔瀹ュ棗鐦弶鐐存灮缁遍亶鎳撶仦钘夊箲閹煎瓨娲濈换鏍ㄧ▔閵堝懐婀撮柣銊ュ濞堫偆鎲撮幒鎴犳勾闁告鍠愬鐢稿礃濞嗘垶绲?
              //        .opacity(morphContainerActive() ? 0 : 1)
              //     闁?**鐟滆埇鍨硅ぐ澶愬嫉閻斿壊鍔€濠靛倽濮ゆ俊鍝モ偓鐟板暙閸櫻囧箳?* 闁?閻忕偛绻嬬粭鍌炲矗椤忓嫬鈷栭弶鈺傚灴缁箓宕ｉ弽銊у闁?= "婵炲备鍓濆﹢渚€鎳楃仦鐐彲"
              //   濞戞挸锕ユ刊娲箥閹惧磭纾婚柟顒傜帛濡叉悂宕ｉ幋鐘虫櫢闁革负鍔岄惃婵嬫閵忕姴顫ｉ弶鐐舵閻ｎ剚绋婄€ｎ亝鍊?闁?缂傚啯鍨堕悧鎼佸捶?闁?婵繐绲介悥?闁?
              // ```
              // ## 闁衡偓鐟欏嫮銆?
              //   闁稿繑绮岀花宕囦沪閸屾粍鐣遍柡鍡橆殙椤?*濞戞挸绉烽蹇涘捶閵娿儴鍩岄柛娆惿戝﹢鈥斥槈閸縿浜?* 闁炽儲鏌￠埀?閻庣懓鍟婵嬪礆缂佹ɑ笑**闁哥儐鍨粩鎾儍閸曨喖鍓归柡?*闁?
              //   闁挎稑鐗忕紞澶愬冀閻撳海鎽犻柛锔哄妽濡炲倹娼诲▎鎰拫闁告帒妫欓弫顕€寮界憴鍕嫳濞戞挸绉风换姗€鏁嶇仦鎯ь暡濞寸姰鍎扮粭澶嬪濮橆剚瀚茬紓鍐╁灦閻楁悂鎳涢鍕暔闁汇劌瀚▓顐ゆ喆閹烘垵缍屽☉鎾卞€撻崬銈夊Υ閸岋妇绀?
              .opacity(1)
              .hitTestBehavior(HitTestMode.None)
          }

          // 閻忓繋绶氬鎵磼椤撱埄妫ф繛鎼枛閻即鏁嶅顑句粴闁革负鍔忛崕妤呭疾椤栨瑧鐟㈤柛鎰噹椤旀劖绋婄€ｎ喗锛熼柨娑樿嫰閸ㄥ繑銇勯悽绋夸簼 0.36 缂佸甯￠崳閿嬨亜閼稿灚绂屽☉鎾卞€曠槐鍫曟濞嗘劏鍋撴担鍝ユ闂?
          // No cover overlay: the lyric page has no matching image destination.

          // 闁宠棄鎳夊Σ?2026-10-15 闁活潿鍔嶉崺娑氣偓鍦仦缁佸瓨绋夐妶鍡樿拫闁挎稑鐭佺换鏍ㄧ▔閳ь剚寰勯崟顒佇﹂柛蹇撳船閹捇鎯冮崟顒傚闁?
          //   闁?*閻忓繐绻戦悺鏇犳嫚瀹ュ棙笑濞寸姴瀛╅崹婊呬焊娓氣偓濞间即鎳楃仦鑺ュ€甸柛鎴ｆ楠?*闁挎稑濂旂粭澶愬及椤栨瑧鐭ゅ☉鎾愁儐閺岀喐顦伴悙鎵憪闁哄鍎埀?闁靛棗鐭佺换妯绘償閿旇姤钂嬪ù鍏间亢椤箓骞愰垾鑼Ф闁挎稑鐗嗛崕姘跺及椤栨氨娈遍梻鍫涘灪鐏忓懘鎯冮崟鍓佺闁?
          //   闁?缂備緡鍙冮ˉ锝囦焊娓氣偓濞间即宕㈤悢鍛婇檷闁汇垼顕у﹢?*闁轰焦鎸抽妴澶愬礃閸涱収鍟囧☉鏂款儎缁?*闁挎稑鐗婇悧?Stack 闁汇劌瀚〒鍫曞触鎼存繄顏卞☉鎿冧簻椤掋垻鈧稒鍔х槐姘舵晬鐏炶偐鑹鹃柡?
          //     鐠?濞寸姴绨肩粭鍛村础閸ヮ亝宕抽柣?*閻忓繐绻戦悺鏇犳嫚?*闁稿繐鐗愰～锔锯偓鐟板暞鐏忓懘鎯堥埀?闁?闁活亜顑堥幑锝夊级閵夛附笑"濞寸姴楠搁惃婵嬫閵忥絽鍓归柛姘閸熷宕欓悜妯婚檷"闁?
          //     鐠?闁告艾鏈悧杈ㄧ鎼存繄鐟撻柛妤€娲╅幑锝夋儍?*闁硅矇鍐ㄧ厬闁?*闁挎稑鐗愮换妯绘償閿旇姤钂?闁圭顦甸幐鎶芥晬婢跺鐦嶅ù鍏间亢椤妇鈧懓鍟敮鍥ㄦ媴韫囧鍋?
          //   闁绘粍婢樺﹢顏堝箮婵犲倻鏆婇柟鍓蹭簻閸?*闁告劕鎳庨鎰沪閸屾瑧顓洪柛?*闁挎稒鑹鹃懜浼村矗濡粯鍩傞梻鍌氱摠閹搁亶寮ㄦィ鍐︹偓澶愭嚊椤忓嫮绠掗梺顓ㄧ到缁卞爼鎯囬悢椋庢闂傚牄鍨哄Σ鎼佹⒕閹邦垱顥戦柣?
          //   闁挎稑娼塺ealCoverVisible()` 濞戞挸鎼禍?闁?閻忓繋绶氬鏉课ｉ幋鎺旂Т闁哄嫷鍨抽埞鏍儍閸曗斁鍋撴笟鈧埀顒€绻戝Σ鎴︽儍閸曞墎绀嗛柨娑樻湰婢у秵绂掗妷褏鏁惧瀣仜閻ㄦ繈妫冮姀銏犲季闁哄秶鍏橀埀顒€绻愮欢閬嶅礄閻戞ɑ闄嶉柕?
          //   濞达絽绉堕悿鍡樼▔鎼绰颁海閻忓繐绻嬬粩鏉懳熼垾鑼伇闁哄秴鍤栫槐娆戔偓鐟板暞濠€浼村级閵夈儲鐨戦柡鍕靛灡鐎?閺夆晞娓圭紞姗€寮堕垾宕囨闂?闁?闁圭虎鍘介弬浣广亜闂堟稓娈遍梻?闁圭粯甯掗埀顒冨亹閺侀箖鎯冮崟鍓佺闁?
          //   闁?*闁圭鍋撻柡鍫濐槸瀹曞本绋夋繝鍐╅檷闁汇劌瀚崬瀵糕偓鐟扮秺閸忔﹢宕烽妸銉ф殜濞戞柨顑勭粭?* 闁?濞戞挶鍊楃划宥嗩槹閻愭彃寮抽梺顔尖偓鐔峰幋閻炴凹鍋嗗﹢鍛喆娓氬﹦绀夊☉鏃傚枍缁楀宕樺鍕瀺闁烩晜鎮傛导鍕箰?闁炽儲鏌￠埀?
          //   閺夆晜鐟﹀Σ鍝ョ磼閹惧鈧垱绋夋繝鍕暠濞ｅ洦绻嗛惁澶愭晬鐏炶偐鐟?闂佹彃绻愮欢閬嶅礄閸℃洜鐟濋柛?闁哄啰濮撮崣褔濡?
          //   闁宠法濯寸粭?濞戞挸绉烽々锕傚礃瀹ュ棗鐨抽柛銉у仜楠炴捇鏁嶉崺?7 闂侇叏绲鹃?闁活亜顑勭粭澶屾喆?闁哄嫷鍨遍崹婊堝触鐏炶偐顏遍弶鐑嗗枛婵偤鎯?`barOpacity` 闁硅泛锕ㄧ化鐘虫媴閻樿櫕钂嬮柣顏嗗枙闂娾晜绋婇悢缁橆棏濞存粌妫濋埀顒傚У閸ㄦ岸鎯冮崟鍓佺
          //      闂侇叏绲奸柌婊堟⒒閵娿儱鍤掔紓浣哥箰閸ㄥ綊姊介妶蹇曞耿闁哄牜鍓濇俊顓熸交濞嗘垵顣兼繛灞稿墲濠€浣衡偓鐟板枦缁辨岸濡?
          // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗嗛敍鎾朵沪閸屾稖鐧侀悘鐐插€块崑鍛▔閳ь剚娼鍡欑闁?*闁圭虎鍘介弬浣广亜閸忓摜鐟濋柛鎰Ф閺佺偓娼诲▎蹇曠倞缂備緡鍙冮ˉ锝囦焊娓氣偓濞?* 闁炽儲鏌￠埀?
          //   `hostsMorphOverlay()` 濞戞捁娅ｅ﹢锟犳晬閸喎顤侀柡?妤犵偠娅曞妯裤亹閵忊檧鍋撴笟濠勭闁哄啳顔愮槐婵嬫焽閿濆嫮顏辨俊顐ｅ笒閸戯紕绱?*闁圭⒈鍓欓崺灞剧珶閸愯尙婀存繛鎼枛閻?*
          //   闁挎稑娼塸roducts/default/src/main/ets/pages/Index.ets` 闁?`MorphCoverClone()`闁挎稑顧€缁?
          //   妤犵偞婀圭粭鏍偨?*閻庣懓鍟抽崵婊冾啅鏉堚晜鐣遍弶鈺傜☉鐎?* `morphOverlayP` 濡炵懓宕慨鈺呮晬?60ms闁?
          //   `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)`闁挎稑顦埀?
          //   闁伙絾鐟ュ﹢顏堝箻椤撶喐鏉瑰銈囨暬閸ｇ兘鎮介懡銈嗙暠闂侇叏绲肩粩鎾偋閸喐绠掑☉鎾亾濞戞搩浜炵划銊╁几閸曨兘鍋撹閻︽椽鎯€閸滃啰绐楅悗鐟板暙濠€顏呮交濞嗗酣鍤?*閻?scale+translate 闁告瑦蓱瀹曞弶娼婚崶銉㈠亾?
          //   閺夆晜锚閻?`.clip()` 濞戞挸楠告慨鈺呭箑?`.height(morphClipHeight())` 闁汇劌瀚鎰板闯?*闂佹彃鐭夌槐婵嬫儗閳轰浇鍩岄柛妤€鐡ㄥΣ鍝ョ玻濡も偓瑜版盯宕搁幇顓犲灱
          //   闁?闁告瑯浜濆﹢?p=1闁挎稑鐗婃禍鐣岀驳婢跺﹤缍侀柟璇℃緛缁辨岸骞嶅鍕船闁哄秴鍚嬮婊呮兜椤曞棛绀夊☉鎿冨弮閳ь剚鏌ㄨぐ褔鎳?閺夆晜鍨抽幎鈧?闁挎稑鑻濠氬矗闊厾鐟愰柛娆忕Т椤︽煡宕?闁告挸绉村畷鎰枔閻㈠灚绠欏☉鎾崇Х椤?/
          //   閻炴凹鍋勯崺鍡涙儍閸曨亞顐介悷妤佸鐏忓懏鎷?闁靛棗鍊圭拠鐐典沪閸岀偛浜濆ù鐘冲灊缁楀宕烽妸銊х濞戞搩浜滈鎰板闯閵娾晛娅￠柨娑樻湰閻ュ懘寮垫径搴ｇ濞戞搩浜Λ鑸碉紣濡硶鍋?
          //   闁宠法濯寸粭?闁告帇鍊栭弻鍥级閳ュ弶顐藉☉鎾崇У濡?p 闁告帞澧楅惀鍛村礆?闁挎稑鐭侀埀顒€鏈Σ?*閻庣懓銇樼€靛矂寮垫径瀣⒕闁哄牆顦扮敮瀵哥不?*闁挎稑鐗愰～?`hostsMorphOverlay()`闁挎稑顧€缁?
          //     PC 濠㈢懓鍟块惇浼存晬閸у埦roducts/pc`闁挎稑顦崇换鏇炩柦閳╁啫澶嶉弶鈺傜懁閸炪倕霉椤旇偐婀撮柨娑樼焸閸嬪懏娼?*缂備綀鍛暰闁汇垼椴搁幐閬嶅绩妤ｅ啨鈧鎳涢鍕畳闁?*
          //     闁炽儲鏌￠埀?闁告熬绠戦崹顖涘濮橆剙姣夐柣?濞戞挶鍊涚粩鐔兼焾閹存帞鐟濋柣?闁?*闁哄啰濮撮惃婵嬫?*缂佸瞼鍎ら妴鍌炲Υ?
          //   闁宠法濯寸粭?闁圭虎鍘介弬浣广亜娴ｅ啫娈扮€规悂浜堕崑鍛嚕?*闁活亞鍠庨惃婵嬫?*闁革负鍔岄懜浼村矗濡粯鍩傞梻鍌滅節缁盯鎮為張鐢电憹闁活澀绱槐妾俽ealCoverVisible()` 闂侇叏绲炬俊鎼佹⒒閵婏妇姊鹃柛鏃戠厜缁辨岸鏁?
          //     闁告熬绠戦崹顖涘濮橆剙姣夐柣婊堫暒鐞氳鲸绋夐鍕闂傚牜婢佺槐杈ㄧ▔閵堝牃鍋撻崨顒€绱柡宥夋？缁ㄦ壆鎮伴妷锝傚亾?
          if (this.expandState.morphBridging() && !this.expandState.hostsMorphOverlay()) {
            this.MorphCoverBridge()
          }

          // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨偆婀寸紒?*闁挎稒淇洪崕妤呭疾椤栨碍韬憸鑸灩瑜板鈧湱鎳撳▍?*闁告劕鎳橀崕?*闁?
          //
          // ## 闁瑰瓨鍨崇粻锝夊礈瀹ュ鏅╅柛锔哄妼閹姐垽鏁嶉崼锝囩闂佹寧鐟ょ粭浣规姜椤曞棛绀夐柣顫妽閸╂盯宕跺☉娆樺仹閻庡湱鍋炵粊鎾箥閹捐櫕绀€闁靛棗鏈幐閬嶅绩閹勭彜閻忕偞娲栫槐鎴炴交濡粯笑闁煎啿鏈▍娆撳礂閵娿儳娼岄柕鍡楃▌缁?
          //
          // 闁瑰瓨鍨崇粩鎾儎缂堢姳绨板☉鎾跺劋濡倝鎮惧畝鈧▓?`MeshCoverBg` 闁?`playerPane` **濞戞柨顑呴ˇ?*闁挎稑濂旂花顒勫及椤栨稑惟閻庣懓鍟幆澶愬礆閻楀牊鎷卞銈呯仛閻?
          // `Stack` 闁?閻?*濞寸姴娴烽鍥ㄧ▔閳ь剛鏁濮樸劑寮弶鎴犳綄**闁靛棔娴囬埀顒€濂旂粭?*閻熶椒妞掔粭澶愬礆?*闁?
          //
          // 闁哄牜鍓濋悿鍡涘箮婵犲啯锟ラ柣锝呯灱濞?*閻庡湱鎳撳▍鎺楀冀?*濞戞挴鍋撻悹渚灥椤曚即鏌呭顐ゅ晩闁挎稑娼墂ujie.pa`闁挎稑顧€缁?
          // ```
          //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   闁?闁?Stack
          //   @36***# (191388)  Stack(TopStart)
          //                       .scale({x: expand.scaleValue, y: 闁炽儺娲?      191400-191415
          //                       .translate({x: expand.translateX, 闁炽儺娲?     191416-191431
          //                       .width(expand.clipWidth)                  191432-191441
          //                       .height(expand.clipHeight)                191442-191451
          //                       .borderRadius(expand.radius)              191452-191461
          //                       .clip(true)                               191462-191469
          //                       .id(PLAYER_ROOT_ID)                       191470-191478
          //                     闁宠澹曢弨?If (191716 @36***#^4)
          //                     闁?   闁宠鏌￠弨?Column (191756 @36***#^5)  闁?婵犲绱曢悰銉р偓?+ winHVp + padTop/padBottom
          //                     闁?        闁宠澹曢弨?If (191972 @36***#^7 闁?@36***^7*#) = **playerPane**闁挎稑婀﹐w闁?
          //                     闁?        闁宠鏌￠弨?If 闁?**MeshCoverBg**             192105 / 192191
          //                     闁宠鏌￠弨?闁?
          // ```
          // 闁?**`MeshCoverBg` 闁?`PLAYER_ROOT_ID` 闂侇叏绲奸柌?Stack 闁汇劌瀚伴崳鐑芥?* 闁?閻?*閻犺櫣鍠撳鍐偓鍦嚀濞呮帗绋夐埀顒傛導?
          //   `scale`闁靛棔妞掔粩瀵告導閻ゎ垼娼?`clip`**闁靛棗鍊界换鏍箥瀹ュ棙笑"閻忕偞娲栫槐鎴﹀籍閹澘鍓归柡鍜佸灟缁楀瀵煎顓熸閻忕偛绻堥埀顑挎祰閳ь剙鏈Σ鍛婄鎼达紕姣堢紒鎰殔瑜版盯鏌屽畝鍕瘣闁告垹鍎ゅ?闁汇劌瀚┃鈧柛鎺曠堪閳?
          //
          // 闁宠法濯寸粭?闁瑰瓨鍨堕婵嬪礈瀹ュ浜濋柛?闁哄啰濮烽弲顐︽儍?`MeshCoverBg` 闁?`playerPane` 濞戞柨顑呴ˇ濠氭晬閸粎鐟㈤悗鐟板暙閹挾鐥缁?**闁哄嫷鍨堕弫濠囨儍?* 闁炽儲鏌￠埀?
          //   闁哄鍎茬花顕€寮伴姘锭闁活亜顑勭花锟犳偋閸ヮ煈鍞介柕鍡曠劍閻ュ懘骞?`PLAYER_ROOT_ID` 闂侇叏绲奸柌?Stack 闁?*闂傚偆鍘奸幃搴ㄦ嚑閸愩劍绾?*閻犲洩顕ч崵顓㈠级閵夛絺鍋?
          //   闁挎稑鐗嗗濠氬矗閸欏鏆堥梺鎻掞躬閸ｇ兘宕欓檱缁绘牗绋婇崼婵嗘櫢闁汇劌瀚粩鎾嵁閺堢數绋婇幖瀵稿枂閳ь剙鍋婄槐?
          //
          // ## 闁衡偓閹勮含閻庡湱鎳撳▍鎺楁煂鐏炶姤鍊遍柡鍐╁劶琚欓柛鎰帠鐞氳鲸绂掗張鐢电殤
          //
          // 1. **閻忕偞娲栫槐鎴炵▔瀹ュ懎鏅?闁煎啿鏈▍娆撳礂閵娿儳娼?**闁挎稒鑹鹃懜浼村矗濡粯鍩傞悗鍦嚀濞呮帡宕ｉ鍛畳閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞柨鐗嗛妵?闁?闁煎啿鏈▍娆愮▕閻斿嘲娑ч柛锔哄姂閸嬪懏绋夐埀顒備焊韫囨挻鍋ラ梺鎻掔焿缁?
          //    闂傚懎绻愰鎰板闯閵娾晜姣愬鍫嗗棌鍋撳畝鍕嚈鐎殿喒鍋撻柨?
          // 2. **闁稿繑濞婂Λ鎾籍閹澘鍓归柡鍜佸灥缁愶繝鎯堥埀顒佺▔閳ь剛鎸у畡鏉跨**闁挎稒鑹鹃鎰板闯閵婏附鎷遍柡澶堝劚濮樸劑宕烽妸銊х唴闁汇垹宕敍鎾绘焽閿濆棙钂?`morphSquashY` 闁汇劌瀚紞鏃堟偨閵娿儳鍘甸梺?
          //    闁?濞戞挸绉撮崯鈧梻鍥ｅ亾閻熸洑鐒﹂崹婊勭▔婵犱胶顏遍柣妤€鐗嗘慨鐐烘儍?`.scale + height + offset` 閻炴稏鍎辨导鈺冣偓鍦嚀濞呮帡鏁嶉崼婵嗗殥闁告帞濯寸槐姘跺Υ?
          //
          // 闁宠法濯寸粭?濞达絽绉堕悿鍡涙晬濮橆剦鍟囬柛?`Column` 闁?*缂佹鍏涚粩瀛樼▔椤忓嫷鍔夐悗?*闁挎稑鐗愰崕妤呭疾椤栨碍韬☉鎾愁儍閳ь兛绀侀崬瀵糕偓鍦嚀濠€顏呯▔婵犲繒绀嗛柨?
          //   `.position({x:0,y:0})` 閻熸洖妫涘ú濠囧极缂堢娀鍤嬮悗鍦嚀濞?闁?濞戞挸绉村顒佺▔鎼达絾妫婚柛姘灦鐢挾鏁崘璺ㄧ闁告熬绠戦崹顖涘濮橆厼惟闁告劕鎳庨鎰板箰閵堝嫮鐟撻柛妯圭串缁辨岸濡?
          Column() {
            // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*缂傚啯鍨堕悧鍝ヤ沪閸屾氨鍩楀閫涚串缁辨繃绋夊鍛櫃闁?`if` 闁革负鍔岄懜浼村矗濡鍘梺顐ｆ⒐鐎垫洘娼?* 闁炽儲鏌￠埀?
            //   濞ｅ浂鍠氶弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鐬奸崑锝夊礄缂佹ê鈪电€殿喒鍋撻柨娑欒壘婵晠鎮介弰蹇曠畺缂佸顑嗛惀鍛存嚄鐏炵偓鐝柕鍡曠婵晠鎮介懡銈囨尝闁哄鍠庡銊╁嫉婢跺牃鍋撳蹇曠
            //
            // ## 濞戞捁妗ㄧ划鍫熺▕?闁哄鈧弶顐介柟绋垮€藉ù?濞村吋纰嶇槐锟犲箳婢跺娈绘繛鍫ユ涧婵晠鎮?
            //   闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁哄啫鐖奸妴澶愭閵忕姴鐏犻柟绋垮€藉ù鍥Υ娑旑柍eshSrc` 閺夆晜蓱濡?undefined 闁?`if` 閻犙勬緲閸樿鎯旈弴鐐茬€婚柡鈧銈囧耿
            //   缂佹稑顦辩紞澶愬冀閸忚偐鐖遍柛鎺斿婢ф粓鏁嶉崼婵嗘闁告ぞ绨ラ柛鎴犲Х濞?ms 闁告艾鍑界槐姝歩f` 闁归潧绉堕悙鏇㈡儑?闁?**`MeshCoverBg` 闁革负鍔岄懜浼村矗濡法绠婚悶娑樿嫰閸╁本绋夐埀顒勫础婵犲啯顦?
            //   闁归潧绉堕鍥ㄧ▔閳ь剙鈻庨埄鍐ㄧ槸閺?*闁靛棗鍊介埀?`NodeContainer` + `RenderNode` 闁革负鍔庨〃娑㈠礂閸噥鍔€閻?`animateTo`
            //   閻炴稏鍎靛Λ鍧楁晬閸у埅eight`/`clip` 婵絽绻愰幎姘跺捶閵娿儱缍侀柨娑橆槺濞堟垿寮甸悢鍏硷紵濡絾鐗楅濂稿箰閸屾繃绁伴柡鍐啇缁辨繈鎳涢鍡欏笡闁告劕鎳庨鎰啺娴ｈ櫣鎼奸悶娑栧劦濡潡寮ㄧ捄铏瑰暡闁?
            //   闁轰礁鐡ㄩ敍鏇㈠冀閹存繂绻侀柛鎺斿厴閸嬪懏绋夐埀顒傛暜瑜庢晶鐘垫偖椤愩垺鍊ら柟瀛樺姇閸ゎ參寮堕妷顖滅濠㈣埖鐗犻崕瀛樺緞瀹ュ棛澹?`gemini-4-argon-thinking` 缂?1 闁哄妲勭槐?
            //   "闁?`NodeContainer` 闁汇劌瀚俊顓㈡倷閻熺増韬悶娑栧劦濡潡寮甸悢鍏硷紵濞戞挸绉烽々锕傚礉閵婏腹鍋撴担瑙勬毉 `height`/闂佹彃绉寸€?`clip`闁?
            //    闁告熬绠戦崹顖炲矗椤栨繂鍘撮柡浣规綑濞尖剝绋夊鍛濞戞挸楠搁幃搴ㄥ箣?闁挎稑顦崳?閻忕偛绻嬬粭鍌炲极鐎涙﹩鍞介柛鏂诲妿閺侀箖鏌堥懞銉π︾紒宀冩濞堟垿濡?
            //   闁?闁绘粍婢樺﹢?*閻㈩垱鎮傞埞?*闁挎稒鐭划鐘炽亜閻㈠憡妗ㄩ柟绋垮€藉ù鍥焽閿濆嫮顏遍柛鎺曨嚙濮樸劎鈧稒锚濠€顏堟晬閸繆鍩岄柛娆惷槐鎴炴叏鐎ｂ晝顓洪柛鎾崇▌缁辨岸鏁嶇仦钘夋锭闁?`src` 闁革负鍔岃ぐ澶愬Υ?
            //     闁哄嫰绠栧▓?婵烇絺鈧啿寮冲ù鐘茬Ф閸斞囧矗椤忓棙鏆?`backgroundRevealOpacity()` 缂佺妳鎵冲亾?
            //   闁宠法濯寸粭?闁稿繑绮岀花鎶芥儍?闁告瑦鐗楅悧閬嶆嚌?濞戞挸绉撮崯鈧柡鍕靛灟缁斿浠﹂崒姘笧鐎殿喚鍠曟俊顓㈡倷閻у摜绀刞Column` 闂佹彃濂旂悮杈ㄧ▔?100% 閻庢稈鏅涢悺娆愬濮樿鲸妫婚柛姘灦鐢挸顕ｉ埀顒勬晬婢舵稓绀?
            //     閻庣懓鍟板▓鎴︽嚂瀹€鍐厬鐎规瓕灏欑划锟犳偨?*閻庣懓銇樼€靛矂鎳涢鍕畳闁?`.backgroundColor`**闁挎稑鐗呯粭澶愭焻韫囨梹顫栭幖瀛樻礀妤犲洭鏁嶆径瀣棡闁瑰嘲鎳岄埀?
            MeshCoverBg({
              src: this.meshSrc,
              srcVersion: this.meshSrcVersion,
              // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`seed: seedOfParts($$.title, $$.artist)`闁挎稑顧€缁?
              //   闁告瑦鐗旂粭澶愬礆閺夎法娈遍梻鍫涘灪濡炲倻绱掗崟顏咁偨闁告劕鎳愰弫銈嗘交濞嗗酣鍤嬬紒澶婄Т閻℃瑩鏌呴悩鎻掑箲閹煎瓨娲滅紞澶愬冀绾绀刞fillFallback` 闁搞儲绋栭～?HSL 婵炴挻鍔曡ぐ澶愭晬婢跺牃鍋?
              seed: this.meshSeed(),
              playing: this.state.isPlay,
              active: this.state.isShowPlay,
              // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲顐﹀储閻斿憡鐎?*闁挎稒鐡猠ntryFade: !pullMode || effT() >= 1`闁?
              //   `wujie.pa:192183-192320` 闁汇劌瀚悿鍕矗閸岀偐鍋撻幇顒傛憻閻忓繗椴稿Σ鍛婃交濞嗗酣鍤嬮悶娑栧姀閹活亜顕ｈ箛瀣у亾閸屾繍鍤斿☉鏂款檧缁?
              //     鐠?濞戞挸绉靛Σ鍛婄▔鐎ｎ偄顎欓梺顓ㄧ稻濞碱垶鏁嶉崼銏犱化闁告垹绮晶锕€顕ｉ埀?/ 闁稿繑濞婂Λ?/ 缂侇垵宕电划鐑樻交閺傛寧绀€闁挎稑顦崳?**濞戞挸绉电拹浼村礂?*闁挎稑鐗忛悵娑㈠礆鐠囨彃璁查悷娆庣筏缁辨岸鏁?
              //     鐠?濞戞挸顑嗘刊娲焽閿濆棙钂嬮柨娑欒壘瑜把囧嫉婢跺﹨鍩岄柛娆愵焾閾斿鈧懓鐭夌槐妾俥ffT() >= 1`闁挎稑顦版晶鐘崇▔瀹ュ懎鏅欐繛锝傗偓鍐插汲闁?
              entryFade: !this.expandState.pullMode || this.expandState.effT() >= 1,
              // 闁粹偓?2026-10-17闁?*闂侇偀鍋撻柛?0 = 闁汇垼顕х粩椋庢崉閻旂儤绲婚悗鐟般仒鐎靛瞼鈧湱鍋炵粊瀵镐焊閸濆嫷鍤?* 闁炽儲鏌￠埀?闁活潿鍔嶉崺娑氣偓鍦仦缁佹挳鎯冮崟顐ｇ鐟滅増甯槐?
              //   濞戞挸锕ｇ粩鎾偋閸粎鐐?`windowHeightVp` 闁诡垵娅曟俊鎼佹偨鐠囪尙顏撮梺钘夘槷缂嶅洭鏁嶉崼鐔剁瑝"闁告ê顑嗘晶搴ㄥ焼閹烘挸顎欏ù?闁挎稑顧€缁?
              //   缂備焦鎸婚悘澶愭偨閵婏箑鐓曢柟韬插劘閳?*闁绘劗鎳撻崵顕€骞橀鐔告澒闁告柣鍔庨弫鐐交閸モ斁鏌ら弶鈺偵戝Σ绋库柦闄囬崕妤呭疾?*闁挎稑鑻慨鈺呮偨閼姐倗娉㈤柡澶屽枎閹骞嶅鍡樼畳闁靛棗绋勭槐?
              //   `fixedHVp > 0` 闁?`RenderNode.frame` **婵絾鏌ㄩ悾鐘诲箥閳ь剟宕烽妸褎鐣遍梺顓ㄧ导闁叉粓鎯勯幒鎴犳憤濡?*闁?
              //   闁兼澘鑻懜浼村矗濡粯鍩傞梺顓ㄧ导闁叉粓鎯勯幒鎴犳憤閻忓繗椴稿Σ鍝ユ啑娴ｇ顥呯紒鎰殔瑜版盯鏁嶉崼婵嗘闁告ぞ绨ラ柛鎴犲Х濞?vp闁挎稑顦崳?閻℃帒鎳庨崵顓㈡偉閸撲焦纾柣銊ュ缁垶宕氶幆閭︽蕉闁轰焦娼欏锟犲礈閺冨牊鐝?
              //   闁?**鐟滆埇鍨硅ぐ澶愬嫉閻斿墎鐭嗗☉鏂跨墦閸忔ɑ绋夊鍥ㄦ毎**闁挎稒绋栭幆銈嗘媴瀹ュ懏鍊靛☉鎾卞€涢埀顒€鎳愬ù澶岀驳?闁?闁告瑥鐗婇婊呮暜閹肩偐鍋?
              //   闁?闁告瑯鍨甸～鍡涘箑瑜岀槐顓㈠礂閸剛绐楀ù?0闁挎稑鐭侀鈧柣銏ｎ嚙缁斿嘲顫濆宀€绠肩紒娑橆槷缁剛鈧懓銇樼€靛矂鎯勯幒鎴犳憤闁? 濞戞挴鍋撻柣鈺冾棎閸忔﹢鎮界拠鎻掓瘔闁哄鍎荤槐姘跺Υ?
              //   闁宠法濯寸粭?濞寸媴绲奸悳顖炲及椤栨俺鍩岄柛娆惿戝﹢锛勭磾閹寸偟澹愬ù鍏煎哺濞堛垻鎲楁担绋款梾缂佹劖顨呰ぐ娑欑▔閳ь剛鎸у畡鏉跨/闁瑰嘲顧€缁辨瑩鎮介妸锕€鐓曢柡鍐ｆ櫅婢х娀骞庢潏銊㈠亾閵娿劎绠栭柣銊ュ閸嬪懘寮堕埥鍛闁?
              //     閻熸洑绀侀幃鎾诲籍閼搁潧濮悺?闁汇垼顕х欢閬嶅礄?+"濞戞挸绉寸敮鍥箥?闁挎稑鑻欢閬嶅箲閵忕姴鐒奸柣銊ュ濠р偓闁告帟顔愮槐娆愮瑹鐎ｎ亶娲ら柟璺猴龚閸庢寮查婧炩晠宕氶幏灞惧闁绘鐗呯粻锝嗗緞閺嶎偅鏆犲鐟板暱閻壆鎲楁担绋款梾闁挎稑顧€缁?
              //     濞戞挸绉烽々锕傚礃瀹ュ洦鏆?闁汇垼顕х粩宄靶掗弮鍌涚＊閻庢稒鍔曢妵?閺夆晜鐟ч～鎺楀礃濞嗘劗銆婇柕?
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
          // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁煎啿鏈▍娆戔偓鐟般仒鐎靛本绋夐埀顒€顕?100%闁?闁搞儱鎼悾鍓т焊閸濆嫷鍤?闁告瑯浜炵划鎵磾閹寸偟澹愰柣銏ｎ嚙缁旂兘鏁嶇仦鑲╃憹缂備焦鐟ョ粩椋庝沪閳?*闁?
          //
          // ## 濞戞挸锕ｇ粩鎾偋閸儲鏅╅柛锔哄妼閹姐垽鏁嶉崼銏℃殢闁规潙鍢查悿鍕圭€ｅ墎绐?*闁煎啿鏈▍娆戔偓鐟拌嫰閸欏繑绋夊鍫綄濞?*闁挎稑鐭傚銈咁潰閵忊檧鍋撴担椋庣槏婵炲备鍓濆﹢渚€鏁?
          //   濞戞挸锕ｇ粩鎾偋閸喎惟**閻庣懓銇樼€?*闁汇劌瀚伴悵顔芥償閿旇法鐭?`'100%'` 闁衡偓鐟欏嫬鐏囬柛銉ユ惈閻?`windowHeightVp`闁靛棗鍊搁鏍ㄧ▔缂佹ɑ笑
          //   `.position({x:0,y:0})` 闁汇劌瀚划椋庘偓鐢垫嚀閻ｇ偓鎷呭鍛憤闁煎搫鍊婚崑锝夋晬瀹€鍐ｅ亾瀹€鈧崺妤冣偓鍦嚀濞呮帗顨?= `morphClipHeight()`闁?
          //   濞戞挴鍋撳☉鎿冧簼閻︻喚鎲楁担绋款梾缂佹劖顨呰ぐ娑欏緞瑜忓▓鎴﹀炊閸濆嫮鏆伴悘蹇撴惈椤曨參鎯勯幒鎴犳憤闁告瑥鍊风粭宀勬偉閸撲礁顔婇柡?閻熶椒绀佹竟鈧梺鐐劤閹鏁嶇仦鐐閻忕偛鍊稿?*濞戞挸绉撮崯鈧悶姘煎亞缁垶宕?*
          //   闁挎稑婀檈mini-4-Argon 濠㈣泛绉甸悧鎶藉触瀹€鈧划銊ф媼閻氬绐桽tack 閻庢稒鍔樻俊顓㈡倷绾懐孝闁告垿缂氶～?`.clip(true)` 闁汇劌瀚崺妤呮儎閹烘挻顦ч柨?
          //   婵炴挸寮堕悡瀣不閿涘嫬娈犲ù鍏肩閺嗭綁宕稿Δ鈧晶褔姊介妶蹇曞耿閻熸瑱绠戣ぐ鍌涙交閸ワ妇顏辨繛鍡忊偓鑼吅闁?*闂傚牊鐟﹂娑㈠箑娴ｉ鐦嶅☉鎾崇С缁变即鎳涢鍕畳闁搞儳鍋炲?*闁挎稑顦埀?
          //   闁粹偓?**濞戞挸绉烽々?*闁告劕绉垫俊鍝モ偓鐟般仒鐎靛矂鎯冮崟顐ｆ閻庨潧鎲″畷鏌ュ箣閹邦剚绁奸悗瑙勭閺?闁炽儲鏌￠埀?閻庣懓鍟换鈧銈堝吹閺侀亶鎮ラ崜渚€鐛?100% 闁圭偓鍨电槐鎴﹀Υ?
          //
          // ## 闁活亞鍠愰婊呮啺娴ｉ攱鍙忛柣銊ュ濡?缂傚啯鍨堕悧绋啃掕箛鏃戝仹闂佹彃绉电敮?闁? 闁告ê顑嗘晶搴ㄥ焼閹烘挸顎欏ù濂告交缁辨岸鏁嶅畝鍕簼濞寸姵婀圭花銊╁矗閹寸姵鏅搁柛?*闁汇垼顕х粩?*濞?
          //   `NodeContainer.onAreaChange 闁?controller.resize(w,h) 闁?field.update(w,h)`
          //   闁?閻犲鑳跺▓鎴︽儎閹烘垹鎽嶉柛锔哄妼瑜板鏁嶅畝鈧紞澶愬冀閻撳孩鐨戦柟绋款槼閻ㄦ繈鎯冮崟顒傛Х濞撴艾顑夐崳绋款嚈濞差亗鈧﹪鎮欓悷鎷屽珯闂佹彃绉归崳浼村冀閺嬵偀鍋?
          //   闁宠法濯寸粭?**2026-10-17 闁绘粍澹嗘慨鎼佹晬濮濇瓲ixedHVp` 鐎瑰憡鐓￠埀顑藉亾闁?0**闁挎稑鐗忛弫鍓ф暜閸愵厾顎€闁活偀鍋撻悗鐟般仒鐎靛矂鎯勯幒鎴犳憤闁挎稑顦埀?
          //     闁哄洦宕橀惁顖涙交閸ャ劌惟閻庣懓鍟撮幏銈夊箣?`windowHeightVp` 婵?闁告ê顑嗘晶?闁挎稑濂旂徊?*闁汇垼顕х粩宄靶掗弮鍌涚＊閻庢稒鍔曢妵?闁?闁轰焦娼欏锟犲礈閺冨牊鐝?*
          //     闁?鐟滆埇鍨硅ぐ澶愬嫉閻斿墎鐭嗗☉鏂跨墦閸忔ɑ绋夊鍥ㄦ毎闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儎鐞氬崬鈻庨埥鍛闁靛棗鍊歌ぐ鑼喆娴ｅ厜鍋撹缁鳖參宕楅崼顒傜闁告ê顑嗘晶搴ㄦ焽閿濆棙钂嬮柛蹇撶墢閺嗏偓闁活偀鍋撻柕?
          //     閻熸洑绀侀幃鎾诲籍閼搁潧濮悺鎺旑劜缁辨繂顕ュΔ浣肝╅柤鍐叉湰濞?*缂佸顕ч崵顓°亹閵忕姴缍侀悗鍦嚀濞?*闁挎稑鐗嗛ˇ濠氭焾閵娿儺妲婚柡宥囶焾缂傛挾鎷嬮鐐暠闁哄倽顫夐、?A闁挎稒淇洪崕妤呭疾椤栨氨婀村☉鎾抽椤旀劙宕抽妸銉﹀€辩紒鐙欎讲鍋?
          //     闁煎浜滅换渚€鎮?`clip` + `scale/translate` 閻犺櫣鍠栧▓銏ゆ晬婢舵稓绀夊☉鎾崇У濡插摜鎷崘銊︽閻庡灚鐡曢崗妯兼喆閿濆懎鏋€闁汇劌瀚ㄩ埀?
          .width(StyleConstants.FULL_WIDTH)
          // 闁宠棄鎳夊Σ鍕煡閸涱亝顫夐柍?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽晬濮橆剦鍟忓☉鎾瑰吹濞堟垹浜搁崫鍕靛殶闁哄嫷鍨粩瀛樼▔椤忓嫭绁奸悗瑙勭閺?`winHVp`闁挎稑濂旂粭鏍及椤栨稓銈︾€殿喖绻愰悺娆撴嚍閸屾粌浠?*闁?
          //
          // 闁哄啰濮烽弲顐︽儍閸曨偒鍟囬柛锝冨妽閻栨煡鏁嶉崸鍓媢jie.pa:191756`闁挎稑鐭傞埀顒佸姌椤㈡垿寮藉宀€绠栭柨娑橆檧缁?
          // ```
          //   Stack(TopStart) .scale .translate .width('100%') .height(clipHeight) .clip(true)
          //     闁宠鏌￠弨?Column  閻?100% + **height(winHVp 闁搞儱鎼悾楣冨极?** + padTop/padBottom     闁?婵炵繝绀佺槐锛勨偓娑掓櫅閻℃瑩鏁嶇仦鐐骏 .position
          //          闁宠澹曢弨?playerPane
          //          闁宠鏌￠弨?MeshCoverBg
          // ```
          // 闁?濞戞挶鍊撻柌婊呮啺娴ｅ搫浠柨娑樼墛閸ㄦ粍绂掗璺吅闁告挸绉崇悮閬嶅级閿熺姴鍘撮梺鎸庣懕缁辨岸鏁?
          //   闁?**闁煎啿鏈▍娆戔偓鐟般仒鐎靛矂鎯冮崟顖滃蒋閹艰揪闄勫Σ鎼佸炊閸濆嫮鏆扮紒鎰殔瑜版稒顨?*闁挎稑濂旂粭澶屾崉?`clipHeight` 閻?闁?`NodeContainer` 闁?
          //      `onAreaChange` **闁告瑯浜ｈ闁告瑦鍨崇粩鏉戔枎?*闁挎稑鐣璕enderNode.frame` 閻忓繐鎼?*闁诡厽甯掗悾?* 闁?闁煎浜炵划顖炲礃閸涱収鍟囧☉鎾崇С缁?
          //      婵絽绻愰幎姘辨偖椤愶箑娅㈢€?濠㈡儼椴搁弲銉╁Υ閸屾稑鐏夊ù鐙€鍓欑敮顐﹀级閵夈儱鏅?`'100%'` = 閻犺櫣鍠撳鍐啑娴ｇ顥呯紒鎰殔瑜版稑袙韫囨挻濮庨柛?闁?婵絽绻愰幎?`resize()`
          //      闁?缂傚啯鍨堕悧绋啃掕箛鎾村闂佹彃绉甸弻濠囨煂閸ャ劎澹?闂佹彃绉寸紓鎾绘晬鐏炲€熷煂闁告瑦蓱濠€锟犵嵁閼艰泛澧峰ù鐘亾濞戞柨鐗撻崗妯荤▔瀹ュ懎鈷?闁?闁活潿鍔嶉崺娑㈡儑鐎ｎ亜鐓傞柣?闁稿繈鍔庨埢鍏碱渶?闁?
          //   闁?閻庣懓鍟Σ?*婵炵繝绀佺槐锛勨偓娑欏姌婵☆參鎮?*闁挎稑鐗婇惀鍛村嫉?`.position`闁挎稑顧€缁辨繈妫冮悩闈涚厬 `Stack(TopStart)` 閻犳劖娼欐稊蹇旂▔婵犲拋娼￠柕?
          //      闁瑰瓨鍨冲鎴﹀储閻斿憡闄嶉柣?`.position(0,0)` 闁汇劌瀚划椋庘偓鐢垫嚀閻ｇ偓鎷?闁?闂佹澘绉撮幃?閻℃帒鎳庨崵顓犳偖?clip 闁汇劌瀚崺妤呮儎?濞村吋淇洪～锕傚极閺夋垶鍋ラ柛鎾存濞?
          //      闁挎稑鐓?59 闂侇叏绲鹃?闁煎啿鏈▍娆戔偓鐟拌嫰閸欏繑绋夊鍫綄"閻忓繗椴稿Σ鍛婃交濞嗘劖钂嬮柨娑橆槶閳?
          //   闁宠法濯寸粭?闂傚牊鐟﹂娑㈠箑娓氬﹦绐楅悗鍦嚀濞呮帗顨?= 缂佹劖顨呰ぐ娑欘殗?闁?闁搞儱鎼悾鐐殗濡湱鐟?`'100%'` **閻庣懓鑻崣蹇曠驳婢跺骞?* 闁?闂侇偅鍔曢崕姘辨閻樿京鐟濋柛娆惽滈埀?
          .height(this.expandState.windowHeightVp)
          // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*濞戞挸绉归埀顒€绻戝Σ鎴炴償閺囩偤鐛?* 闁炽儲鏌￠埀?缂傚啯鍨堕悧鍛婄▔閸ワ妇顏辨繛宀嬬磿閺侀箖宕欓悜妯婚檷闁挎稑濂旂弧鍐╃▔瀹ュ嫮绐楅梻鍥ㄥ絻閸ゎ厽锛冮弽顓溾偓?閺夆晞娓圭紞姗€寮堕埥鍛
          //   闁?`defaultImageBgColor`闁挎稑娼塺gba(32,32,32,1)`闁挎稑鏈﹢鐗堛亜闂堟稑鏂ч柡鍫濐槺濞?閺夆晜蓱閻ュ懘寮垫径濠傜悼闁肩懓寮跺鍌炴儍閸曨偆淇洪柤?闁挎稑顦埀?
          //   闁宠法濯寸粭?濞戞挸绉烽崗姗€宕濋悩鍐茬亣"缂佹鍏涚花鈺傜▔椤忓嫮鎽嶉柤鍝勫€婚崑?闁炽儲鏌￠埀?閻庣懓銇樼€靛矂寮伴姘煎晣闁革綆鐓夌槐婵囩▔閵堝嫰鍤?100% 閻庢稈鏅涢悺娆愬濮樿鲸妫婚柛姘灦鐢挸顕ｉ埀顒勫Υ?
          .backgroundColor(PlaybackPage.defaultImageBgColor)
          .hitTestBehavior(HitTestMode.None)
          // 闁粹偓?2026-10-17闁?*濞戞挸绉崇粻濠氬矗瀹ュ洨绱氶柡鈧?* 闁炽儲鏌￠埀?濞撴碍绻冨畵渚€寮伴婊勬殢闁规挳顥撶划浼存儍閸曨剚锟ラ柣锝呭閼垫垵鈻撻崹顐㈢劵闁搞儲鎷濈槐?
          //   闁哄啰濮烽弲顐ｇ▔椤撶噥鍞介柟鎼簻濞存﹢寮伴崜褋浠涢柨?*缂傚啯鍨堕悧鎼佸及椤栫偞鎳欐繝濞惧墲閺嗭絽顕ｉ悩鎻掑耿闁绘娲ㄥ▓?*闁挎稑鐗婇悧鍝モ偓娑欏姍濞堛垽宕￠敍鍕暬濞戞挴鍋撻悹褏鏌夐～锕傚储?閻忕偞娲栫槐鎴︽晬?
          //   闁?闁煎啿鏈▍娆戞崉閻旂儤绲婚悗鍦嚀濞呮帞绱撻埡鍌涙澒闁哄牜鍓濋棅鈺呭及椤栨凹鍤犻柣銊ュ缁辨繈宕ｅ鍥╃礆闁衡偓閸欍儳绐楅悹浣叉櫅閻棙绋夋繝鍌氭锭闁告挴鏅欑粩鏉戭嚕閻樺啿濮悘蹇撴惈椤曨厾绱旈幋鐐靛闁?*濞戞挴鍋撻柛褎顨呴崹蹇涙偋?*闁?
          //   闁挎稑鐗嗗濠氬矗閺屻儱浜濆☉鎾卞€涚粙娑㈠矗瀹ュ洨绱氶柡鈧ィ鍐ㄥ幋鐎圭寮堕幐娆撳炊閻戝洨绀塦bgInverseScale()` 濞戞梻鍠庨崙锟犲礆閻樼粯鐝熼柕鍡楀亰缁?
          // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁煎啿鏈▍娆戜沪閸屾繂娈伴悹?* 闁炽儲鏌￠埀?閻?`diagBgBox` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柨?
          //   闂佹彃绻掑▓鎴﹀及?*闁哄牜鍓欓惇浼存晬閸絽鍓归柡鍜佸灠椤旀牗绋夋导娆戠**闁汇劌瀚粩椋庝沪閳ь剟鎯岄埡浣藉煂闁靛棗鍊婚弫銈夊箣闁垮袚"闁哄牆顦抽崕妤呭疾椤栨瑧绋诲Δ鍌浢€规娊鎮ч柅娑氱У"闁哄啳顔愮槐?
          //     鐠?`bgH` 鐎垫澘鐗嗛惃顒勬嚀?`clipH` 濞戞梻鍠庨惃?闁?婵繐绲介悥鍫曟晬閸繂袟闁汇垼顔婇懙鎴濃枔绾板绀夐悗鍦嚀濞呮帞浜搁崡鐐叉锭闁哄牆顦甸崑鍛▕閸縿浜ｉ柨?
          //     鐠?`bgH` 鐎垫澘鐗嗛惃顒勬嚀?`clipH` 濞戞挸绉撮惃?闁?**闁谎勫劤閸ㄥ骸袙閺冨牊鎳犻柡鍌ゅ幒缁?*闁挎稑鐗愰崕妤呭疾椤栨稓姊鹃梺鍓у劋瀵呪偓鍦嚀濞呮帡鏁?
          //     鐠?`bgH` 婵繐绲介悥?闁?闂傚偆鍣ｉ。浠嬪捶?*濞戞挸绉归埀顒€绻戝Σ鎴炴償?*闁挎稑鐗忓﹢?`bg`闁挎稑顦伴崹?*缂備焦锚閸?*闁挎稑鐗呯粭澶愬及椤栨氨顏撮悘鐐╁亾闁?
          .onAreaChange((_oldArea: Area, area: Area): void => {
            const w: number = areaLengthToVp(area.width);
            const h: number = areaLengthToVp(area.height);
            this.diagBgBox = `${w.toFixed(0)}x${h.toFixed(0)}`;
          })

          // 闁?闁告劕鎳庨鎰沪閸岋妇绐楅悘蹇撴惈椤曨參骞侀幒宥堢 100%闁? 閻熶椒绀佹竟鈧紒鎰殔瑜?= 闁告瑯鍨甸～瀣儗閳轰浇鍩?/ 缂傚倵鏅滈弬渚€鏁嶆径娑氱闁圭鍋撳ù鐘劜濡楀牊娼诲鍐跨稏婵犲ň鈧啿璁查悷娆忔閻撯晞銇?
          Column() {        Column() {
              this.buildControlStack()
            }
            // 闁?闁奸娴囬惌鎯ь嚗閸曞墎绀勯柛鎴犲С缂嶅秴鈻介敓鐘叉闁告帞澧楀鍌炴儍閸曨偄骞戦幖瀛樻穿缁辨岸鏁嶅顒€鏁堕悗鍦嚀閻壆鎷圭€靛憡绲婚幖瀛樻礉缁旂喖鏁嶅畝鍕蒋閹艰揪缂氱划?閻犳劖娼欑花铏▔閳ь剟寮?闂傗偓閸喖鐓?100%
            .height(this.sheetHeightPercent())
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.End)
          .clip(true)
          // 闁宠法濯寸粭?閺夆晜鐟╅崳?*濞戞挸绉撮崯鈧?*缂備焦鐟﹂弳锝囦沪閸屾艾顫ｉ梺顐㈢箲濡叉垶鎯?閹煎瓨娲濇竟濠囨晬濮樺灈鍋撹箛鏃€顫栭幖杈剧畱閸戯繝骞愭径濠傚唨缂傚倹鐗為惁褔骞忛崱妯虹亣濞戞挸顦惇鎵玻濡も偓瑜?
          //   闁挎稑鐗愰崕妤呭疾?`pullBgIn` / 濡炪倛鍩栭悥?`pullChromeOpacity` / 閹煎瓨娲橀悥?`pullBottomIn`闁挎稑顧€缁?
          //   閹煎瓨娲濇竟濠囨偨閸楃偠鍩岄柛娆惷鎰板闯閵娾晛娅￠梺顓ㄧ导闁叉粓宕ｉ弽顒€顥忛悘鐐插€界粈瀣嫻閿濆繒绀夐柛姘剧畱閸垶妫冨▎鎰靛壘闁诡兛妞掔槐鎵焊閹存粎顏遍悘鐐插€块·渚€鎳濈仦鍌楀亾?
          // 闁宠法濯寸粭?濞戞挸锕ユ刊娲箥閹惧磭纾?*濞戞挸绉村﹢顏呮交濞嗘挸娅￠柛?*闁挎稒鑹鹃悾鐘虹疀閸涙番鈧繘骞愰崒姘含濠㈢懓鍟块惇浼存晬閸ь湼oducts闁挎稑顦埀?
          //    闁圭虎鍘介弬浣广亜闂堟稒韬?`isShowPlay=false` 闁哄啯鍎肩换鏇炩柦閳╁啫鐦弶鐐存灮缁辨繃銇勯悽鍛婃〃闁衡偓閺堢數鐟濋柛鎺斿婢ф粓骞愰崶锔剧殤濞寸姾缈伴埀?
          //    闁煎崬鐭侀惌妤呭礆閹烘垵鐎婚柨?*濞戞挸锕ユ刊?濠㈢懓鍟块惇?閺夆晞娓圭紞姗€寮堕埥鍛闁?morphP 0闁?闁挎稑顧€缁辨繃绋夌€ｎ偄顎欓柡鈧幆鐗堝闯=闁哄牜鍓熼妴澶愭晬閸艾鏅?morphP 1闁?闁?*闁?
          //
          // 闁宠法濯寸粭?閺夆晜鐟╅崳?*濞寸姭鍋撳☉鏂跨墦閸忔ɑ绋夊鍕憪闁?*闁挎稑鐗婂Λ锔界▔瀹ュ嫮鐟愰柟韬插劚閺勫倻鈧敻娼荤槐婵囩▕閻斿墎鐟濋柛鎰С缁楀倿骞庨妷銉ユ枾闁绘劗娅㈢槐姘跺Υ?
          //    闁哄牜鍓欓惇鎵焊鏉堛劍笑闁归潧顑嗗┃鈧〒姘€鍛暠 `MORPH_HOST_ID`闁挎稑鐭侀埀顒€鑻悾鐘绘儍閸曨垳褰幖杈鹃檮濡?*閻熶椒绀佹竟鈧紒鎰殔瑜版稒顨囧Ο鍝勵唺**
          //    闁挎稑鐗嗛懜浼村矗濡粯鍩傞梻?~60vp 闁?婵犲ň鈧磭娼岄柨娑橆檧缁辨紮globalPosition` 濞戞梻鍠曠粣锟犳儓閳?translate 閻?闁炽儲鏌￠埀?
          //    闁瑰嘲鐏濋悾鐘恒亹?闂佸墽鍎ゅ褔鎯勯鐣屽灱"閻忓繗椴稿Σ鍝ョ箔椤戣法瀹夋繛鍠°倕娈伴柛锝庡墾缁辨瑦绋夐埀顒勫锤濡ゅ懐鎷ㄩ幖?+ 闁圭虎鍘介弬浣广亜闂堟稓娼斿☉鎾崇Т缁辨垿鏁嶆径娑氱
          //    闁瑰嘲鐏濋悾鐘恒亹?闁秆勫姈閻栵綁宕㈤悢鍝勪化"閻忓繗椴稿Σ鍝ユ媼閳轰礁鏂ч柣鎰攰閹风兘鎯堥埀顒勬嚊椤忓嫮绠掗柣銊ュ閼垫垿姊荤€涙ǚ鍋撴担鐣岀崜闁挎稑鐗愰幑锝夋倷?闁稿繐顑夊▓鏇犱沪閸屾稒娈诲ù锝嗘崌閺佸﹥鎷呭蹇曠闁?
          //    **闁秆勫姈閻栵綁宕ｉ敐鍛獮闁稿繈鍔戦幗鑲╃磼閻斿墎顏辩紒鎰殔瑜版盯宕搁幇顓犲灱**闁挎稑鐗撻崳鍝劽圭€ｎ偅鎷遍柡澶堝劚濮樸劑寮伴婊呭炊闁告瑱绲藉妤呭冀閸ラ绀夐柛蹇擃儔濞堟洜浠﹂崒婊勭暠
          //    `.position()` 濞戞梻鍠曢幆銈夊捶閵婏箑濮悘?Stack 濞戞挸顭槐婵嬪触鐏炶棄缍撶€垫澘瀚哥槐姘舵晬鐏炴儳顣插ù鐘劜閻楁挳寮甸璺ㄧ憹闂傚洠鍋撻悷鏇氱鐢偊鎮欑憴鍕簥缂佺姵銇滈埀?
          //    鐟滆埇鍨硅ぐ澶屼焊閸濆嫷鍤熼柣銊ュ閺侇喗绋夐埀顒勫级閸愩劉鏋嗛柡鍕靛灠閿涙挾浠﹂崒娑樼樆 `windowSize` 濞戞挸锕ユ慨銈夋儍?`reportWindow`闁?
          .onAppear(() => {
            this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            this.isAlive = true;
            this.getImageColor();
            this.applyPlaybackWindowChromeImmediately();
            // 濡炪倗鏁诲鐗堬純閺嶎煈鍋ч柛鎴ｆ楠炲洭寮捄鐑樺€辨慨婵勫劙缁旀潙鈻庨垾宕囩；闁稿繐纾慨鎼佸箑娓氬﹦绀勯悹浣稿⒔閻ゅ棙銇勯棃娑樿闁煎疇妫勯崹浼村绩绾懐绠栭柨?
            this.applyFlowLightColors();
            // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁告帞濮电敮鈧?`playbackSwiperIndex = 0`闁挎稒绋撻崒銊ヮ嚕閺囩偟绉?闁瑰灚鎸哥槐鎴﹀箛韫囨挻绂?缂?*闁?
            //
            // ## 闁告鍠愬鐢告焽閿濆懎缍栧☉鎾规〃缁牊绋婇崼鐔哥畳閻?
            //   閻庣懓鍟Σ?*闁煎搫鍊婚崑锝囩棯瑜嶅ú鏍嫬?*闁挎稑鐗婂﹢?`Column` 闁?`.onAppear`闁挎稑鑻崹搴ㄥ绩椤栫偛娅㈢€点倛妗ㄧ弧鍐╁濮樺磭鐛撻柨娑橆樀閸ｇ兘鎯冮崟顐㈡櫢闁稿繈鍎荤槐?
            //   闁?`playbackSwiperIndex` 闁?Swiper 鐟滅増鎸告晶鐘炽亜?闁汇劌瀚弫顔界▔閳ь剟鎮╅懜纰樺亾娓氬﹦绀夊☉鎾存⒒楠炲洭宕?
            //   **缂備焦鍨甸崺灞剧?`Swiper.index()`**闁挎稑鐗愰～?`Swiper()` 濞戞挸锕ラ弻鐔兼焽閿濆棭鍞介梻鈧幐搴㈡殘闂佹彃顭槐姘跺Υ?
            //   濞戞挶鍊涢埀顒€鎳忛弬浣圭▔閳ь剛鎸у畡鐗堢殤闁哄嫷鍨电换鏍ㄧ▔椤忓嫯鍩岄柣妯款啇缁?
            // ```
            //   闁活潿鍔嶉崺娑欑鎼达紕淇洪梺顔哄妿婵悂骞€娴ｅ湱鍩?婵繐绲藉﹢顏堝箻椤撶喐鏉?閺夆晜绋掗幐閬嶅绩閹勭彜 闁?闁瑰灚鎸哥槐鎴﹀箛韫囨挻绂堥柟璺猴功閸屻劌顕ｉ弴鐘垫瀭 0闁挎稑鐗愰鏇犳媼閳ユ剚娲ゆ慨婵勫€х槐婵堟喆?
            //     PlaybackIntentShell闁挎稑顦崯?闁活潿鍔嶉崺娑橆煥閹存繂鐓傛慨婵嗙焷閻︽繃銇勭喊澶岀缂佷究鍨圭槐?= 1闁挎稑鐣璴yricMorphT` = 1闁?
            //   闁哄本鍔掗柌婊堟嚍閸屾粌浠梺鎻掔Т缂?闁?闁?`onAppear` 闁告瑥鐗愮粣鍥ㄧ▔閳ь剙鈻?闁?缂佷究鍨圭槐鈺冩偖椤愩垹鏅搁柛?0
            //   闁?`Swiper` 閻犲搫鍟垮ú鏍焊娓氣偓濞肩増銇?+ `lyricMorphT` 濞戞挸瀛╅弻濠冦亜閸忓摜鐟濆☉鎾亾闁?
            //   闁?閻熸瑥鍊归崝鍛存晬?*闁革负鍔嶉悺鏇犳嫚瀹ュ鈧鏁嶇仦鐣屾闂傚牄鍨瑰畵鍫熺▔瀹ュ懎缍侀悘?*闁挎稑鐗忛弫銈夊箣?2026-10-16 闁活亞鍠愬┃鈧柟鎼簻濞存鈧湱鍋炵粊鎾晬?
            // ```
            //   闁宠法濯寸粭?闁兼澘濂旂粭鏍ㄦ交濞嗗酣鍤?濠㈣泛绉崇紞?閻?*闁告劕鍢查幆搴ㄥ礉閵娾晛浜濋柡澹溿倗鐔呴柡鍫墯濞肩數浜搁崡鐑嗘▼濞?*闁挎稒纰嶆晶锕€顕ｉ埀顒勫箻椤撶喐鏉归柛锝冨妽濡?
            //      `PlaybackIntentShell` / `ProductViewModel` 闂侇叏绲肩粩鎾级閳ュ啿鍤掔紓浣哥箲婵″摜妲愰姀鐘电┛缂?0 濞?
            //      闁挎稑鐗嗛悾鐘诲及?闁瑰灚鎸哥槐鎴﹀箛韫囨挻绂?闁汇劌瀚粩鎾焾閵娿儱鐎婚柨娑橆槶閳ь剙鍊芥俊顓㈡倷閸︻參鐛撻柛銉у仩閻ㄧ喖宕樺鍡楊潵濞戞挴鍋撴繛鍡忊偓鍐叉锭濞村吋纰嶆俊鎼佹偨閵婏箑鐓?*鐟滅増鎸告晶鐘炽亜?*闁瑰灚鎸荤敮鈧柕?
            //
            // ## 闁绘粍婢樺﹢顏堟儍閸曨偄鐎荤€规悶鍎荤槐娆撳础閺囨氨顏遍柣顏嗗枑缁噣鏁嶇仦钘夌劶闁告劕绉电拹鈺呭触閸剛绀?
            //   鐠?**闁瑰灚鎸哥槐鎴﹀箻椤撶喐鏉归柛?* 闁?闁汇垼椴告晶锕€顕ｉ埀顒勫箛韫囨挻绂堢紓?`playbackSwiperIndex = 0`闁挎稑鐗婂﹢鐗堛亜閸忓摜鐟濋柛娆忓€风粭宀勬晬婢舵稓骞?
            //   鐠?**闁活潿鍔嶉崺娑橆煥閹存繂袟**   闁?`.onChange` 闁告劖鐟ч崒銊ヮ嚕?+ `.onAnimationStart` 濡炵懓宕慨?`lyricMorphT`闁?
            //   鐠?**闁煎搫鍊婚崑锝夊礄閾忕懓绠?*   闁?闁告瑯浜滈幃鎾愁潰?闁哄牜鍓熼妴澶愭嚊椤忓嫮绠掗柣銊ュ椤鎲存径灞叫﹂柟?闁?*濞戞挸绉堕～顐︽偨閵婏箑鐓曢柛锔哄妼閹姐垺绋夐埀顒併亜?*闁?
            //
            // ## 濞?閻忓繋绶氬鎵磼椤撱埄妫?闂侇叏绲肩粩瀵糕偓闈涙贡濞堟垿宕楀畷鍥厙闁挎稑鐗愮换鏍煂瀹€鈧▓鎴炲緞瀹ュ嫮绉?*闊洤鎳橀妴蹇涙偩?*闁?
            //   濞戞挸顑夊鐗堢▔閵堝懎缍栭柡?*闁哄牜鍓熼妴澶愭嚊椤忓嫮绠掗柣銊ュ濞ｆ娊鎮介悢鍝勑﹂柟?*闁挎稑濂旂粭澶愬及?闁活潿鍔嶉崺娑㈠捶閵娿儲鎲垮☉鎾亾濡?闁?
            //   `lyricMorphT` / `lyricMorphVisible` 闁硅绻楅崼顏堟儍閸曨剚笑"閻忓繋绶氬鐗堫槹閻愰鏀介柛鏂诲妿閺佺偓娼诲☉婊庢斀闁告帗婢橀幗?闁?
            //   闁煎搫鍊婚崑锝夋煂瀹ュ懐绱﹂柛姘缁烩偓濡炪倛顕уú鏍礆娴煎瓨楗慨婵勫灪閳ь兛绶ょ槐娆撳触閿曗偓閸垱瀵煎顑跨不闁革负鍔嬬粩瀛樼▔椤忓泚澶愭⒒缂堢姾鍘梻鍌氱摠閳ь兛绶ょ槐姘跺Υ?
            //   闁宠法濯寸粭?濞?*缂佷究鍨圭槐鈺傜▔?1 闁哄啯婀圭粭澶愭嚄閻ｅ本閿ら柣鈺婂枟婵?`lyricMorphT` 鐟?0** 闁炽儲鏌￠埀?闂侇叏绲肩槐鎵媼?闁革负鍔嶉悺鏇犳嫚瀹ュ鈧?閺夆晜鐟ょ粩瀵告暜?
            //      闁汇劌瀚惃婵嬫閵忕姴缍侀柛銉у仜閵囧洨浜告笟鈧浼存晬閸噥鍔€闁哄嫷鍨卞﹢鏉库枎闄囬々锔界┍椤旂偓鐣遍柣婊勫閽栧嫰鏁嶆径鍫氬亾閸屾娅?闁圭顦遍崒銊ヮ嚕閺囩偛鏋€閻庤宀稿銈咁潰閵忊檧鍋撴笟濠勭獥
            // ```ts
            //   this.lyricMorphT = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
            // ```
            //   闁?闂傚牊鐟﹂娑㈠箑?= 鐟滅増鎸告晶鐘炽亜闂堟侗鍤犻幖瀛樻⒒濞堟垹绮╅婊冧化"闁挎稑鐭佺换鏍ㄧ▕閻斿憡笑 `lyricMorphT` 濞戞挶鍊撻柌婊呯矙閸愯尙鏆伴柛濠呭亹濞堟垹鈧鐭粻鐔煎Υ?
            //   闁?2026-10-16闁挎稑鐗忛鍥ㄧ瀹€鈧晶妤呮晬婢舵稓绐楅弶鈺傜懇閸ｇ兘宕㈤悢鍛婇檷闁哄嫷鍨粩鎾矗閵夈儱鏁堕柤杈ㄦ煣缁椾線宕楅崘锔瑰亾閸屾粌绠涢柛锔哄妽閺佸綊寮☉婊呯
            //     `syncLyricMorphToPage()` 闁炽儲鏌￠埀?闁搞儳濮崇拹?*闁告艾濂旂粩瀛樼▔椤忓嫷鍤犲缁樺姇婵晜鎷呭鍐╄含闁圭鍊藉ù鍥籍閺堢數鐦嶉悷鏇氱娴犳稒绋夐埀顒€鈻?*
            //     闁挎稑娼塧boutToAppear`闁挎稑顧€缁辨繃绋夐妶鍜佹П闊洤鎳橀妴蹇涘触鐏炶偐顏遍柛娆欑到缁剁偤鏁嶉崼锝庢綄闂侇叏绲奸柌婊堝棘鐟欏嫮銆婇柣銊ュ閺佺偤鏌屾繝蹇曠闁?
            this.syncLyricMorphToPage('appear');
            // 闁宠法濯寸粭?閺夆晜鐟ょ粩鎾矗?*闊洤鎳橀妴蹇涙偩濞嗗繑韬鑸电墵濞?*闁挎稒鐡猻yncLyricMorphToPage()` 闁?鐎规瓕灏欑划锛勨偓闈涚秺缂?闁哄啯婀圭槐?*闁哄啠鏅犻埀顑藉亾**闁?
            //   闁?闁煎搫鍊婚崑锝夋煂瀹ュ懐绱﹂柛姘凹缁楀鎷嬬粙澶哥不闁革负鍔忚棢闂傚倻绻濋懙鎴︽⒒鐎涙ǚ鍋?閺夆晜鐟﹀顖滄啺娴ｅ湱婀存慨锝呯箲椤?`onAppear` 闂侇喖鈧噥娲ｆ繝濞愩倕鍠曢柕?
            this.lyricMorphVisible = false;
            // 闁硅矇鍐ㄧ厬闁告牜灏ㄧ槐鐗堟交濞戞瑦闄嶉柛蹇撶墕閺佹粓宕欓悮瀵哥3 缂佸甯楅惀鍛村礉閵娿劌娈伴柛鏂诲妽閺佸湱鎸?
            this.chromeCollapsed = false;
            this.touchChrome();
            // 闁?2026-10-15 閻犲洤锕ラ弻鍥晬濮樿櫕鍎板ù锝呯С缁狅綁宕ユ惔鈥虫櫃闂佹彃绻嬬粩鏉戔枎閳ヨ櫕纾藉☉鎿冧簻濞硷繝鎯冮崟顓犲炊闁告瑱绲块悡鈺勩亹椤喚绀勯悷?`logLayoutBoxes()`闁挎稑顦埀?
            //   480ms 闁?閻忕偞娲栫槐鎴犳偘閵夆晜锛熼柨娑樼墛濞撳爼姊?560ms 闁汇劌瀚拠鐐典沪閸岀偛浜濋柡?+ 20ms 闁衡偓鐠鸿櫣鍟查柨娑橆槸閻斺偓闁哄牜鍓濋摂瀣偓?闁汇劌瀚伴崳铏圭棯瑜濈槐?
            //   闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗?`RzdBoxes`闁靛棗鍊靛▓鎼佹晜?闁告瑯浜ｉ浼存晬鐏炶偐鐟濈憸鏉垮船閹奸攱绂掔拋宕囩Э闁绘鍩栭埀顑块檷閳?
            setTimeout((): void => {
              if (this.isAlive) {
                this.logLayoutBoxes();
                // 闁?闁烩晩鍠楅悥?闁?闁?S1 婵縿鍎撮崵婊呮嫚娓氬﹦绀勯柟鐑樺笚閻擄繝宕楅幎鑺ユ殯閻?`RzdSizeTier`闁挎稑顧€缁?
                //   闁哄秶顭堥?`sizeScaleOf` / `topPageSideOf` 闁?*闁归潧顑嗗┃鈧俊?*濞戞挸锕ュΣ鎼佸触閿旀垝绱楀┑鍌滄櫕閻℃垶绂嶆惔銏犵亯濞?
                //   鐎规瓕灏欑划锟犲捶閵娧勬殢闁汇劌瀚ù鎰偓瑙勮壘閳ь剛銆嬬槐妾俿izeK = 1` / `side = 16`闁挎稑顦埀顒佹煛閳?闁哄牏鍠愬﹢?`fixedOk=true`闁?
                this.expandState.logSizeTier(this.breakpointEnv.widthBreakpoint);
                // 闁?闁烩晩鍠楅悥?闁?闁?S2 婵縿鍎撮崵婊呮嫚娓氬﹦绀勯柟鐑樺笚閻擄繝宕楅幎鑺ユ殯閻?`RzdWideCols`闁挎稑顧€缁?
                //   闁硅泛锕ら鏃備沪?/ 闂傚牄鍨哄妯荤▔閵堝棎鈧倿鎯?*闁告濮甸惁顔界▔鎼存繆鈷堥柡宥呯箰椤旀梹鎯?*闁瑰灚鎸搁崵顓㈠级閵夘垳绀勯柟闈涱儐濠р偓濞戞挸锕ら悾鐘崇椤戣法鐟濋柛娆忓€风粭宀€鏁崘銊ф拱闁?
                //   闁告瑯浜濆Σ鎼佸箮婵犲啯娈剁紒鐘愁殔閸ゎ參寮堕妷銉У闁哄被鍎荤槐姘跺Υ閸岀偞锛熼悹鐑樼箰缁辨獖utter/space闁?*濞戞挸绉村﹢顏堝礂閺堜絻鍘?* 闁炽儲鏌￠埀?閻?S2 闁汇劌瀚弫鐐烘煂婵炲簱鍋?
                this.expandState.logWideColumns(this.breakpointEnv.widthBreakpoint, this.usePanelLayout(),
                  this.getUIContext());
              }
            }, 480);
            // 闁宠法濯寸粭?濞戞挸锕ユ刊娲箥閹惧磭纾婚柡鍐╁劶缁绘ɑ鎯旈敃鈧崙锛勭磼韫囨挻韬柟閿嬬墪婵晜绋夐陇娉插ù婊冩缁旀挳鏌堥妸銉ョ€婚柨娑樼焷缁绘牠鏌岀仦鑲╃憹闁煎厖绮欓崳鍝ョ磾椤曞棛骞?
            //    闁绘劗鎳撻崵?閻犙囨敱閹搁亶骞囪箛鎾寸闁瑰灚鎸哥槐鎴﹀籍閹壆绠婚幖杈鹃檮濡?0闁挎稑鐗愰～?aboutToAppear闁挎稑顦埀?
            this.collapseProgress = 0;
            // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*鐟滆埇鍨硅ぐ澶嬪濮樺磭妯堢憸鐗堝笒閿涙挾浠﹂崒娑欘槯闁挎稑鏈﹢鐗堛亜閸忓摜鐟濋悹褑娓归幑銏℃媴閺囩偟娼旂€殿喒鍋撻悶娑栧劦濡?*闁?
            //   闁哄啰濮烽弲顐︽焽閿濆牏鐝堕柟缁㈠幗閺備焦銇勬担鍐ㄦ鐎圭褰夌粭澶愬箻椤撶偟娼旂€殿喒鍋?闁炽儲鏌￠埀?閻庣懓鍟ぐ褔寮伴婵愭蕉濠㈢懓鍟块惇浼存儍?`ExpandAnimation`
            //   闁?`scale/translate/clip` 闁规亽鍔庡鍐矗濮楀牏绀夐悶娑栧劦濡潡宕烽妸銉处閻忕偛鍋婄槐妾俿ettlePullOpen`闁挎稑顦埀?
            //   闁哄牜鍓熼妴澶婎潰閵堝懎鐓濋柛娆樹簻娴犳稒绋夐埀顒佺閺堢數鐨戦柨?*闁硅泛锕︾划顖炲礆閸洘锛岄柟鍨尭缁?*闁挎稑鐗嗛崵鎴炴媴閺囩偛鍤掔紓浣哥箲濡插憡绔熼崘鑼勾闁告ê顑呴妶浠嬫儍閸曨喗宕抽柣鎰缁辨岸濡?
            //   闁宠法濯寸粭?閺夆晜鐟╅崳?*濞戞挸绉烽?*闁告劕绉靛Λ銈夊级閳ュ弶顐介悹?`playExpandIntro()`闁挎稒鑹鹃悾鐘冲濮樺疇娉?`tryStartMorphIntro()`闁?
            //      闁兼澘鐭傞崑鍛村级闄囬惌鍓ф啺?闂佹彃绻愰崺宀€绱掗崼銏犱化闂佹寧姘ㄩ崑?闁归潧绉烽崑妤冩導閻ゎ垁澶愭⒒濞ｎ兘鍋撴笟鈧崳鐑樼▔瀹ュ懎鐓傞悘蹇涗憾閳ь兘鍋撻柛鏍ㄧ墬閸?
            //      `playLegacyExpandIntro()`闁挎稑鐗愰崚娑欐償閺囨氨顏遍柡澶涚節閺嗚鲸绋夋繝鍐╅檷 = 婵炴煡绠栭悡鍫曞籍瑜嶆慨鈺呮偨娴兼瑧绀?
            //      闁?闁告艾濂旂粩瀛樼▔椤忓嫬寮抽柛娆欑稻濠€渚€寮懜鍨﹂柡鍌涙緲婵晠鎮藉Ч鍥ｅ亾娴ｈ绠掗柡鍐煐濡叉悂寮婵晠鎮芥导娆戠婵繐绲惧Σ鎼佸Υ鐏炵偓鐓€闁哄唲鍕叺闁哄缈伴埀顒€绉跺▓鎴ｃ亹閵忋垹笑闁?
            //
            // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁绘劗鎳撻崵顕€骞嶉幘宕囩；婵炲备鍓濆﹢浣轰焊娓氣偓濞?闁煎啿鏈▍娆撳礉閵娧勬毎闁汇劌瀚﹢锟犲冀閻熺増绀?*闁挎稑顧€缁?
            //   闁告帇鍊栧畵渚€宕㈤悢鍛婇檷闁告瑯浜濆﹢?`morphContainerActive()`闁?*闁绘劗鎳撻崵顔炬崉椤栨氨绐為柛锔哄妽鐎垫洘娼禒瀣簼濞戞挴鍋撻柛鎺曨嚙閻ｇ姵娼诲Ο缁樞﹂柛?*闁?
            //   ```
            //     闁绘劗鎳撻崵顕€鏁嶅顒婄处閻?beginOpenMorphOnClick 闁?pullOpenBegin
            //            闁?prepareMorphEntry 闁告瑦鍨归獮?闁圭虎鍘介弬浣广亜娴ｅ啰绠锋繛灞稿墲鐎垫洘娼慨鎰ㄥ亾娴ｅ摜娈遍梻鍫涘灲閸ｇ儤绋夊鍛厒"
            //            闁?閻?!ready 闁告帒妫欓弫顕€鏁嶅鐣俽phStage = ENTERING闁靛棔娌無rphDrive = FINGER
            //            闁?濞达絽妫寸槐娆撳触鐏炶偐鐟愰柨?*morphUsable = false闁靛棔娌無rphP = 0** 闁?morphContainerActive() 濞戞挸鎼禍?
            //            闁?pushPlayerRoute 闁?闁哄牜鍓熼妴?onAppear 闁?闁瑰搫顦崇换?else 闁告帒妫欓弫?闁?**闁圭虎鍘藉ǎ鎶芥閾忣偅锛嬮柛鏂诲妿閺?*闁?
            //     濞戞挸锕ユ刊娲晬濮橆剨绱﹂悘?onPullOpenStart 闁?pullOpenBegin闁?*闁革负鍔戦妴澶愭閵忊€崇槸閺夌偞鍨濈粻锝夊礈?*閻?
            //            morphBeginEntering()闁挎稑鐗撻崑鍛村籍閹壆纰冨ù锝囧У濞碱垶鏌岃箛鎾剁箒闁告帒搴滅槐姘跺焽?闁圭鍊藉ù鍥籍?stage = ENTERING 闁?閻犙勬緲椤曨噣宕氶崱妯绘殰
            //   ```
            //   闁?閻炴稏鍎扮粩鎾级閳ュ啿鐏查柟璇″櫙缁?*濠㈢懓鍟块惇鏉款啅閼碱剛鐥呭☉鎾荤細缁绘牗绋夐埀顒佹姜椤旀寧宕抽弶鈺佹搐閼镐即宕ｅΟ鍦獥閻?*闁挎稑娼塵orphSessionStarted`
            //     闁?`prepareMorphEntry` 缂佹鍏涚粩鏉戭潰閵壯呮瀭濞达絽绋勭槐婵囩▔婢跺钂嬮柛蹇嬪劚瑜版盯鏌堥幋鎺旂獥缂備礁绻楃换鍐偓鐟板枦缁辨岸濡?
            //     閻庣懓鍟崹姘辩博?闁?閺夆晜鐟ょ粩瀛樸亜閻㈠灚鐣辩紒妤婂厸缁斿鏁濮樸劎鎷?濞戞挸绉堕弫?闁挎稑鐗忛悺鎴炵珶閸愯尙婀撮柟璺猴工閸ゆ垶鎷呴弴鐐茬闁告帗濯介幑锝夋倷閻у摜绀嗛柨?
            //     闁兼澘濂旂粭澶愬及椤栨繂娈扮€圭宕槐鎴炴叏鐎ｎ偅灏￠梺顓ㄧ到椤?`collapseProgress` 闁哄唲鍐ㄐ楅柣銏＄湽閳?
            if (this.expandState.morphContainerActive() || this.expandState.morphSessionStarted) {
              this.diagAppearBranch = 'morph';
              this.introPaintReady = true;
              this.expandIntroRunning = false;
              // 闁宠棄鎳夊Σ?2026-10-16闁挎稑鐗忛崑锝夊礄閺勫繒鐔呯€垫澘瀚▓?*闁告垹濮崇紞宥囨偘閵夆晛娅?*闁挎稑顧€缁?
              //   闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁?`pullOpenBegin` 闁哄嫷鍨板﹢?闁圭虎鍘介弬浣广亜娴ｅ啰绠锋繛灞稿墲鐎垫洘娼?闂侇叏绲肩粩鎾礆閺勫繒鐛撻柣?闁?閻庣懓鍟欢銏ゅ矗椤栨繂鍘?
              //   闁瑰嘲銇樼粭澶愬礆閹殿喚鐭掗柣鎰秺閺佸鎮欓惂鍝ョ闁圭虎鍘介弬浣广亜闂堟稓娈遍梻鍫涘灱婵☆參鎮欑涵鍛濞戞挸绉撮悺銊╁捶椤帞绀嗛柍?`morphUsable = false`闁?
              //   濠㈢懓鍟块惇浼存焽閿濆牏鐝堕柡?12閼?2ms 闁汇劌瀚棢闂佹彃绻掗悰銉╁矗閿濆繒绀刞schedulePullAnchorRemeasure`闁挎稑顧€缁?
              //   濞达絽妫濋崑鍛村及?*濠㈢懓鍟块惇?*闁汇劌瀚俊顓熺附韫囥儳骞㈤柡鍫墴閵嗗骞愰崒婵囩グ闂侇叏绲肩粩鎾礆缂佹ɑ笑"閻忓繋绶氬浼存嚍閸屾粌浠?*闁告帗鑹鹃崹鎵偓娑櫭﹢?*"闁?*闁哄牃鍋撻柡?*闁哄啳鍩栧┃鈧柨?
              //   闁革负鍔忕换鏍煂瀹€鍏鏌岃箛搴ｎ伇婵炲棌妲勭槐婵喰掗弮鍌滄惣濠㈢懓鍟块惇鐗堢▔鐎ｂ晝顏遍柟宄扮▌缁辨瑩寮甸埀顒佸緞?32ms 濞戞柨顑呴幃妤呮晬婢跺绾柛鎴濇閳?
              //   闁宠法濯寸粭?濞戞挸顦伴鐐垫導鐢喚绀夌紓鍌濇〃缁旀潙顫㈤妷銉︾殤濞?閻炴稏鍎甸崳娲箣閹邦剙顫犲ù锝呮濞村鎷呭鍫㈢闁稿绮屽﹢顏堝籍瑜庨埀?闁?
              //     闁?`prepareMorphEntry` 闁炽儲鏌￠埀?闂佹彃绻愰崵鎴炴媴?+ `morphInitParams` + 闁告ê顑呴崺宀€鎸ф搴′化闁?
              //     闁?`morphBeginEntering` 鐎规瓕灏欑划锟犳偨閸楃偟鏆婇柛鎰嚇閸庡鎷崘顓犵畺闁挎稑婢乪ady 闁哄啳顔愮槐姘舵晬?
              //     闁?閻炴稏鍎甸崳娲箣閹邦剙顫犻柛?*闊洤鎳橀妴?*闁硅泛锕ョ拠鐐典沪閸岀偛浜濆☉鎾亾婵☆偅甯炲▓鎴犳偘閵夆晜锛熷☉鏃傚枙閹癸絿鎸ч柨瀣檷闁挎稑鐗嗛幆渚€宕氬▎蹇曟闂傚牜婢€缁盯鎮為張鐢电憹濡炲鍎戠槐姘跺Υ?
              setTimeout((): void => {
                if (!this.isAlive || this.isClosing) {
                  return;
                }
                this.diagRemeasureTries = this.diagRemeasureTries + 1;
                // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁告艾濂旂粩纾嬨亹閵忋垹笑闁汇劌瀚?3 濠?*闁挎稒鑹惧鐢稿及?缂佺姵顨呴崵顓㈠级閵夈倗鍟?鐟滅増鎸婚崹?闂佹彃绻愰崺灞剧?闁挎稑顧€缁?
                //   閺夆晜鐟ヨぐ鐐哄储閻斿憡闄嶉柡?`if (morphUsable) { return; }` 闁炽儲鏌￠埀?闁?`morphUsable` 闁?
                //   `morphInitParams()` 闁汇劌瀚划銊ф媼閻氬绐?*闁告瑯浜ｉ々?barW/boxW 闂佹彃绻愰崺灞剧閸℃鏆婇悘蹇撳綁鐠愮喖鎯?*闁?
                //   **闁哄秷顫夊﹢鐗堢▔瀹ュ浂鍚€缂備礁鐗忛崑锝夋煥濮樺崬浠柡鍫濐槹閻ュ懘寮?*闁靛棗鍊风花顒勫及椤栨粌浠柛鎴犵帛婢э箑顕ｉ埀顒佹交濞嗘劖钂嬮悹渚灟缁楀倿鏁?
                // ```
                //   pullOpenBegin 闁?morphInitParams() 闁瑰瓨鍔曟慨娑㈡晬閸絿纰冨ù锝囧У濞碱垶寮垫径濠傛濞达絾娲╃槐姘跺焽?morphUsable = true
                //   闁圭鍊藉ù?闁?閺夆晜鐟╅崳椋庢嫚鐠囨彃鐓?morphUsable === true 闁?**闁烩晛鐡ㄧ敮?return**
                //        闁?闁哄牜鍓熼妴澶嬫交濞嗘劦鍋?闁哄牃鍋撻柡鍐ｆ櫇濞堟垹鎮伴妷鈺佹闁哄啳鍩栧┃鈧?閻炴凹鍋嗗▍褔鎯傞幋鎺撲涪闁?
                // ```
                //   闁兼澘鐬肩划鎾绘倷瑜版帗鏅柣鎰嚀濠€?*闁哄牜鍓熼妴澶愬箰閸屾繃绁板☉鏂款儏婢?*闁哄嫷鍨崇划椋庘偓闈涚秺閸ｇ儤绋夊鍛厒闁汇劌瀚哥槐娆撴嚍閸屾粌浠弶鈺偯肩粭澶屸偓娑櫭﹢顏堟晬?
                //   闁?閻忓繐宕ぐ褔宕滈埡渚婄处閻忕偛鍊块崑鍛村级?12閼?2ms 闁稿繑绮岀花鎶芥晬鐏炶壈鈷堥柡澶嗏偓瀹犲珯閻炴稑鐬煎▓鎴犳偘閵夆晛娅?*濞戞挴鍋撻柡澶涚節閸忔ê鈻介檱缁?*闁?
                //   闁?闁告帇鍊栧畵渚€骞戦姀鈥崇亣 {@link PlayerExpandState.morphGeomReadyNow}闁? 闁哄啰濮烽弲?`pullGeomReady`闁?
                //     闁告瑯浜濆﹢渚€鎯囬悢鐑樼暠闂佹彃绻愰崺宀€绱掗崼銏犱化闂侇叏绲肩粩鎾箯瀹ュ棗顤呭☉鎾规濠€锟犳晬婢跺牃鍋?*闁哄牜鍓熼妴澶愬箰閸屾繃绁伴弶鈺傜懁缁旀挳宕氱紒姗嗗妧闁?缂備礁鐗忛崑锝夋嚍閸屾粌浠柛鎺撹壘閻°劑宕?闁汇劌瀚〒鍫曞籍閳哄倹顦ч柡?*闁?
                //   闁宠法濯寸粭?濞?`morphUsable` 闁汇劌瀚崹搴☆啅閵夘煈娼岄梺顓ㄧ导闁叉粎鈧稒顨嗛宀勬儍閸曨剚鏆堥梺鎻掝煭缁辨繈宕氶銏犳櫃婵烇綁顥撻弫銈夊Υ?
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
              // 闁稿繑绮岀花鎶芥晬濮橆剝鍩岄柛娆惿戦惀鍛導闁垮闄嶉柨娑樼墕閸ゆ垶鎷呴弴鐔烘⒕闂佹彃绻樼紞鍫ユ儍閸曨垪鍋撻埀顒勫礌閺嶎剛鐔呯€垫澘瀚哥槐姘瀹ュ棙锛嬮悹褎濯介埀顑跨窔閸嬪懏绺藉Δ瀣闁告帩鍋夐鈧銈囨暬濞间即骞嶉幘鑼憹鐎殿喒鍋撻柕?
              //
              // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*濞ｅ浂鍠氶弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙濂旂粭鍛村箯婢跺﹤褰犻梻鍌ゅ幖閹鏁嶇仦钘壭楅柣銏ｅ吹缁劑寮堕悢鍓佸晩缂佹劒鑳堕崝褔宕ｉ崼鐔告澒濞戞挴鍋撻梺顒€绉撮惈宥咁嚕閳ь剟濡?*闁?
              //
              // ## 閺夆晜鐟﹀顖炲礆閸℃ɑ鏆滃☉鎾规〃缁牊绋婇崼婊呯獥闁?闁稿繑濞婂Λ?闁哄啯鍎奸～锔炬導閺夊灝鐓?
              // 闁?`.onAppear()` 闁?*闁煎搫鍊婚崑锝囩棯?*闁搞儳鍋犻惃?闁炽儲鏌￠埀?閻庣懓鍟╃槐浼村捶?*闁告帒妫欓弫顕€鏌屽鍛处**闁哄啯婀圭弧鍐喆閿曗偓瑜板倿鏁?
              // 濞戞挸绉磋ぐ褔寮?濡炪倗鏁诲鎵偖椤愶絽鈪电€殿喒鍋?闂侇叏绲肩粩鏉戔枎鎺抽埀顒€鍊介埀顒€鑻崣褔姊婚銏℃嚑閻犱警鍨堕崳?`morphReset()` 濞村吋纰嶆俊?
              // `morphSessionStarted` 婵炴挸鎳庡ú?false闁挎稑娼塵orphStage` 闁告瑦蓱閸?NONE闁挎稑顦崳?
              // 濞戞挸锕浼存焽閿濆嫰鍤?`if` 闁汇劌瀚悮杈ㄧ▔椤忓嫬鐏查柟?*闁告艾鏈鍌炲矗濡桨娴?* 闁?闁解偓閽樺鐓傞弶鈺傜懇閸?闁?**闂佹彃绉甸弬浣圭▔閳ь剟鏌嗗鍛綌鐎殿喒鍋撻柛鏂诲妿閺?*闁?
              //
              // ## 闁告帇鍊栧畵渚€鏁嶉崼婊呯憦闂侇剚鎼槐?*缂佹鍏涚粭渚€寮堕埄鍐┬﹂悹鎭掑妼閻ゅ嫭绗熺€ｎ剚鐣?*闁?
              //   闁?`isClosing` 闁汇垹宕崣褔姊婚銏℃嚑閻犱警鍨抽悿鍡涙儑閻曞倻绀刞closeFullScreenPlayback()` 濡絾鐗犻崕鎾晬婢舵稓骞?
              //   闁?`morphStage === LANDING` 闁炽儲鏌￠埀?`morphLand()` **闁告瑯浜滃﹢顏堝礂閹惰姤锛旈悹渚灠缁?*閻炴凹鍋夐惃?
              //      闁挎稑鐗嗛崣蹇擃啅閵壯€鏌ゆ繛鎾虫噽閸嬶綁鏁嶅姝卨aybackPage` 濞戞挶鍊曢ˇ?+ `Index:1088`闁挎稑顦崳?闁?鐎规瓕寮撳锔芥交濡法纰冨ù锝囧У濞?闁汇劌瀚ù澶嬫媴瀹ュ繒骞?
              //   闁?闁?`lastCloseAtMs` 闁哄啫鐖煎Λ璺ㄧ玻?闁炽儲鏌￠埀?**閻犳亽鍔岄悿鍕瑹?*闁稿繐褰夐棅鈺呮晬閸綆娼岄梺顓ㄧ导闁叉粓妫冨▎鎰ㄥ亾娴ｅ摜鎽熸繛鍫㈡暩濞堟垵鈻旈妸鈺佹珵闁挎稑顦埀?
              //      闁宠法濯寸粭?闁冲墎濮幉?闂侇喛濮ゅΣ?*閻庡湱鍋樼欢銉т沪閳ь剟鏌?*闁汇劌瀚哥槐浼村棘閺夎法鏉藉〒姘儑濞?`aboutToAppear` 濞村吋纰嶆俊?`isClosing`
              //         **闁哄啰濮靛顖涚閼哥數顏搁柛?false**闁挎稑鐣璵orphReset()` 闁告瑥鐗婃俊?`morphStage` 鐟?NONE
              //         闁?闁稿繑濞婂Λ瀛樻媴濞嗘劕鐨鹃柦鈧挊澶嬭含闁哄倹婢橀悿鍕瑹鐎ｂ晝鐟愰柡?*濞戞挶鍊栧顖炲礂閵娧呪偓?* 闁?闊洤鎳橀妴蹇涙?闁抽娼块埀?
              //      闁宠法濯寸粭?闁?闁汇劌瀚崯鎾绘倷?*闁告瑯浜濆﹢?* `closeFullScreenPlayback()` 濡絾鐗犻崕瀛樼▔閳ь剚寰勯崟鍓佺濞戞挶鍊曢ˇ鈺呭箣閹邦剦鍤犻柨?
              //         濞戞挸锕ｇ粩瀛樻姜椤斿吋鐨戦柡鍕靛灡缁扁剝绂嶉崱娑樹簼濞戞搩浜滈崯鎾绘倷楠炲簱鍋撴笟鈧Λ顒勫箒閹烘垳娴?闁?闁谎嗗Г閺佸吋绋夐埀顒佹姜椤曞棛绀嗛柕?
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
                // 闁?闂?濞戞挸绉甸幐閬嶅礉閵娧勬毎"濞戞柨顑呴ˇ缁樻交濡櫣绠戝?*闁硅泛锕ら崵鎴炴媴閺団剝鍎伴悗?*闁?
                //   闁告熬绠戦崹顖溾偓鍦嚀濞呮帡宕ｉ婵嗗幋闁稿绮屽﹢顏嗘偖椤惵ゅ幀闁哄偆鍘惧▓鎴炵▔椤撱垺锛?scale闁挎稑鐗忛弫銈夊箣闁垮袚闁?闁煎啿鏈▍娆撳矗椤忓嫬鈷栧☉鎾亾闁?闁告艾鏈花顕€鏁嶆径鍫氬亾?
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
            // 闁宠棄鎳夊Σ?2026-10-16闁?*闁稿繐鐗嗚ぐ?闁告鐡曞ù鍥焽閿濆嫮顏遍柛?闁?isAlive 闊浂鍋嗛崣?*闁?
            //   濞戞挸顑夊浼存焽閿濆牜鏀藉ù鍏肩婵?`isAlive` 闁告艾鏈鐐电磾?false闁挎稑鐭侀埀顒€鏈﹢浼村炊閻愬墎娈堕梺鎻掔灱濞堟垿宕氶妶鍡楃ウ闁?*鐎点倛鍩栧鍌涚▔閳ь剟骞?*閻犵儤鍨瑰▓?闁炽儲鏌￠埀?
            //   闁烩晛鐡ㄧ敮瀵告嫚鐠囪尙鎽熸繛鍫㈡暩濞堟垹鎷犲┑鍥攳閺夆晜绮忛浼村礆?false 闁?闁告帇鍊栧畵渚€鏌?`!isAlive` 闂侇叏绲惧顖炲箒閹烘梹鍩?
            //   闁?鐎点倛鍩栧鍌炴焽閿濆澹曢梻鍌樺妿閻℃垶绂嶆惔銏㈡⒕闁告梻濯寸槐娆愭交濞嗘劦鍔€闁哄嫷鍨粭鍌涚▔閳ь剟鎮?`morphUsable` 闂侇叏缍佹禍楣冩⒒閵娧勭暠闁告艾鐬肩悮顐︽煥濞嗘帩鍤栭柨?
            //     **闁告帇鍊栧畵浣烘嫚鐠囨彃鐓傞柣銊ュ濡?閻炴凹鍋夐崵婊冾啅鏉堛劍鏆弶鈺佹矗缁狅綁宕?闁汇劌瀚埀?*闁挎稑顦埀?
            const wasAlive: boolean = this.isAlive;
            this.isAlive = false;
            PlaybackPage.ev('DIS', `wasAlive=${wasAlive ? 1 : 0} show=${this.state.isShowPlay ? 1 : 0}`);
            // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁告帞濮电敮鈧弶鈺傜懇閸ｇ兘鏌囬敐鍛稏闁告艾鏈鐐烘儍?`state.isShowPlay = false`**闁挎稑顧€缁?
            //   闁告鍠愬鍨交濞嗘挸娅￠柛鎰懅濞?`this.state.isShowPlay = false;`闁靛棗鍊搁悾鐘诲及椤栨瑧顏卞☉?*闁煎搫鍊婚崑锝囩棯?*闁搞儳鍋犻惃鐔兼煂瀹€鈧▓鎴﹀礃濞嗗繐寮抽柨?
            //   闁?`isShowPlay` 闁?*濠㈢懓鍟块惇鎵崉椤栨粍鏆犻柣銊ュ閳瑰秹宕濋妸锔剧埍**闁挎稑娼塈ndex.@Monitor('appState.isShowPlay')`
            //   闁?`popPlayerRoute()`闁挎稑顦埀顒€鍊风悮閬嶆嚀閸涱喗鍎楅柛锔哄妺缁斿鎸ф搴㈢暠闁告艾瀛╅悘澶愬及椤栨繄绠瑰☉鎿冧簻閼镐即鎮╃拋鍦獥
            // ```
            //   闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁挎稒鑹鹃敍鎾朵沪閸屾稑惟 isShowPlay 缂?true 闁?闁规亽鍔岄崣鍡涘箻椤撶喐鏉瑰銈勭祷閻箖鎮?
            //   闁告艾濂旂粩瀵告暜?濞戞挸顑勭粩瀵告暜瑜濈槐?*闁哄唲鍕啊闁衡偓妤ｅ啨鈧鈧湱鍋樼欢?*闁挎稑鐗婇崹銊╁礆閸℃ɑ鏆滈梺鎻掔Т缂傛捇鎯冮崟顖氫簼濞戞搩浜ｆ俊顓㈡倷閻у摜绀嗛悷娆欑畱瑜?onDisAppear
            //   闁?閻庣懓鍟俊?isShowPlay 闁告劖鐟ュú?false
            //   闁?濠㈢懓鍟块惇鎵博鐎ｎ亜鐓?popPlayerRoute() 闁?**闁告帗纰嶆晶锕€顕ｉ埀顒勬儍閸曨剚灏￠柡鈧ィ鍐︹偓澶屾偖椤愩垼鍓ㄩ柟?/ 闁告柣鍔庨弫鍓ф偖椤愶絽绗岄柡?*
            // ```
            //   闁宠法濯寸粭?闁兼澘濂旂粭鏍ㄦ交濞嗘劖笑**妤犵偛鍊婚悺鎴﹀箑瑜嶅鑺ョ閸℃瑦鐣?*濞戞挴鍋撳璺哄缁辨澘鈻旈妸鈺佹珵 `:2709` 闁煎浜滅换渚€宕樺▎鎴炵祷
            //     闁靛棗鐣璱sShowPlay` 闁兼眹鍎遍崙锟犲及?false闁挎稑鐣瑻Monitor` 濞戞挸绉崇槐浼存煂瀹ュ拋妲婚柛鏂诲妺缂嶆棃濡村浣插亾閺傝　鍋撻弮鍫濅簼闁?闁稿繑濞婂Λ鎾煣閹规劗鐔?闁汇劌瀚銏＄▕婢跺牃鍋?
            //     闁稿繑濞婂Λ鎾煣閹规劗鐔呭☉?`isShowPlay = false` 闁?*濞戞挸顦ˇ鈺呭级閸愩劉鏋嗛悹浣稿⒔閻ゅ棝鎮?*闁挎稑鐭傞崗姗€宕?
            //     `closeFullScreenPlayback()` 闂佹彃琚埀顑跨窔閸忔﹢宕烽妸锔诲妧缁绢収鍠氬▓鎴﹀籍鐠哄搫鐓濋柨?
            //       鐠?`:2712` 闁哄啰濞€閺佸鎮欑憴鍕紞闂侇偀鍋撻柡鈧?
            //       鐠?`:2729` 婵繐绲介悥鍫曞绩閹増宕抽悶娑栧劦濡潡寮ㄧ捄铏瑰暡闁衡偓?
            //       鐠?`:2738` "婵炲备鍓濆﹢渚€宕ｉ鐐存祮闁告垹濮崇紞宥夋儎鐎涙ê澶嶉柛蹇斿▕濡?闂侇偀鍋撻柛鏍ㄧ墬閺?
            //   闁?闁哄牜鍓欓ˇ?*濞戞挸绉瑰〒鍓佹啺?*闁告劕绉撮崯鎾寸▔閳ь剙鈻庨埥鍛耿闁伙絾鐟у鍐矗椤忓啰绐楅悹?闁瑰灚鎸哥槐?閻炴凹鍋夐崵婊冾啅鏉堫偒鍤栭柛鎺嬪€栭崹?闁稿繑濞婂Λ?闁?
            //   闁宠法濯寸粭?闁兼眹鍎遍幗銏″緞閳哄啯鍩傞梻鍥ｅ亾閻熸洑绀侀崢瑙勬償閺囶亞绀勫〒姘儏椤?Hard exit 閻犙囶暒缁楀宕氭０浣虹憪闂傚牜婢€缁椾焦寰勯崟鍓佺闁?
            //      **闊洤鎳橀妴?*闁稿繐鐗嗛崹?闁圭虎鍘介弬浣广亜娴ｅ啰鐔呴柣銏ｄ含閳ユ鈧湱鍋涢崙锛勭磼韫囧海鐟濋柛锔哄妽閻栥倝鏌?闁告劕绉撮崯?闁炽儲鏌￠埀?闁告熬绠戦崹顖炲矗閸喐笑閺夆晜鐟ら柌婊嗐亹閵忋垹笑闁?
            //      闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗route: push player` 濞?`route: remove player at index=` 闁汇劌瀚鍌涙償韫囧鍋?
            //
            // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁硅埖眉閼垫垿宕戝顓犮€婇柨娑欐皑閺嗏偓濞戞挸顑呴悾銊╁礂閵娧呯Ч闁挎稑濂旂徊鍓х磼濞嗗繒鏆婂☉鎾亾濞?闁告瑯浜滃﹢顏呯▔鐎ｎ亜閰遍柡鍐╁劶琚濋柛?闁汇劌瀚顖涚?*闁挎稑顧€缁?
            //   闁烩晛鐡ㄧ敮鎾礆閻樺啿绔撮悗鐟板暞濠€浣诡槹鎼淬劍鐝?闁炽儲鏌￠埀?`Hard exit`闁挎稑鐗呯欢銉︿繆閸屾粓鍏囩紓浣哄枑婵＄螣閳╁啠鍋撴担瑙勬濞戞搩浜濋弫褰掑箳婢跺牃鍋撴担鐟扮仐闁告帩鍋嗗▓鎴澪熼垾铏仴闁烩晛鐡ㄧ敮?
            //   `popPath`闁挎稑顦板?*婵炲备鍓濆﹢浣圭鐠佸磭绉垮ù?*濞村吋纰嶆俊鍛婃交閾氬倻绋戦柡澶嗏偓鍙夊攭閺夆晜锚濞叉牠寮堕妷锝傚亾閸屾稑顣插ù鐘劙缁楀宕氶悪鍛闁衡偓鐟欏嫬鐏?**闁告瑯浜滃﹢顏嗘兜椤旀鍚?
            //   闁圭虎鍘介弬浣广亜闂堟稑鍤掔紓浣哥箣缁楀宕烽妸銊х唴闁汇垼椴搁悥銈夋煂?*闁哄啳鍩栨晶鐘诲礃?闁挎稑鑻懟鐔哥▔?*闁规亽鍔忕换婊勭▔閳ь剟骞?*闁挎稑鐗愰鈧柛姘嫰閹舵岸宕橀崨顓炶闁煎疇妫勮ぐ鍌炴偨閻旂儤鐣?
            //   push 闁稿繐鐗愰幆銈夊冀閸剛绀嗛柨?
            //     鐠?闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁挎稒宀搁崑鍛▔閳ь剟骞忓鍡欏灲闂?*鐎圭寮跺﹢?*闁圭虎鍘介弬浣广亜?闁?濞戞挸绉撮崯?闁?濞戞挸绉崇槐鎵偖椤愩儺鍤栭柛鎺嬪€栭崹姘跺礂閹惰姤锛?闁?
            //     鐠?缂侇垵宕电划鐑樻交閺傛寧绀€ / 闁稿繑濞婂Λ鎾箰婢舵劖灏﹂柨娑欏哺閸嬪懏绋夋径濠庢П闁哄鍟埢澶愭倷閻熸澘鍤掔紓浣哥箰閸熸挻娼婚崶椋庣`isShowPlay` 鐎圭寮跺Σ?false闁?
            //       闂佹彃绉撮ˇ鏌ュ礃濞嗘劖笑妤犵偛鍊婚悺鎴︽儍閸曨厸鏁勯柟鍨С缂嶆棃鏁嶆径鍡樼
            //     鐠?Hard exit 濞戞挻姊归惀鍛閸濆嫬鏅搁柨娑欏哺閸嬪懏绋夐埀顒勫箯瀹ュ棛鍨介梺鎻掓湰閻ュ懘寮垫径瀣啊闁衡偓妤ｅ啨鈧?闁?闁?false 闁?濠㈢懓鍟块惇浼村绩鐠鸿櫣鍟?闁?
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
                'RzdMorphOnDisappear fallback: player route gone but isShowPlay still true 闁?release it');
              this.state.isShowPlay = false;
            }, 0);
            // 濞戞挸顑勭粩鏉戔枎閳╁啫鈪电€殿喒鍋撻梺鎻掔У閺屽﹦鎸?闁稿繐鐗撻崳娲礃瀹ュ洨绱?闁汇劌瀚伴妴搴㈡償韫囥儳绐楅柟璺猴功缁垶宕氶崼鏇燂紝濞戞梻鍠庨崣褔宕堕悙鎻掔
            this.introPaintReady = false;
            // 闁?濡炪倗鏁诲浼村础濮濆本绁伴柡鍐硾椤﹀弶鎷?閻犺櫣鍠愭晶婊勫濮樺磭妯?闁汇劌瀚悮杈ㄧ▔椤忓懐鍨奸悹浣藉焽閳?
            //   `pullDragging` / `morphDrive` 闁告劕鍟块悾楣冩倷閻熸澘姣婇柟鍨尭缁辨垿寮幆閭︽矗濞戞挸绉烽々锕傚磻濮橆剝鍩岄柛娆惷崹鍨叏鐎ｎ亜顕ч柨?
            //   闁告瑯浜ｉ々锕傚嫉婢跺顏遍弶鐑嗗枟婢ф粓宕濋幐搴ｆ⒕閻犙勬緲閸╁矂寮ㄧ捄铏瑰暡闁挎稑鐗愰～锔惧寲閼姐倗鍩犻柟韬插灱閾斿濡存担鐤幀闂侇偅鏌ㄥ畵蹇旀姜婵劏鍋撴担琛♀偓鏍礂閹惰姤锛旈柍銉缁辨氨鈧懓鍟銊﹀濮橆厾鏆欓柣锝嗙懕缁?
            //   婵炲牆顑囬弳鈧柟?(true, FINGER) 闁哄啫澧庨崑锝夊礄缂佹ê鈪电€殿喒鍋撳ù?*婵ɑ鐡曠换娆戞崉鐎圭姷绠栫憸鑸灩瑜?*闁?
            //   闂侇偀鍋撻柛鏍ㄧ墬閸?`collapseProgress` 闂侇叏绲介〃婊堟嚀娴ｇ袟闁活澀绱槐娆撴偨閵婏箑鐓曢悗鍦仦缁佹挳鏁?闁绘劗鎳撻崵?閺夆晜鏌ㄥú鏍偨閵娧勭暠閺夆晜蓱濡插憡绋婄€ｎ亜顤呴柣銊ュ婵晠鎮?闁挎稑顦埀?
            this.expandState.pullDragging = false;
            this.expandState.morphDrive = MorphDrive.NONE;
            // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*"闁绘劗鎳撻崵顕€骞嶉幘宕囩；婵炲备鍓濆﹢渚€宕濋妸褎鏆?闁汇劌瀚花顔藉緞閺夋垶鐨戦柛锔哄姀缁绘牠鏌?*闁挎稑顧€缁?
            //   濞戞挸顑夊浼存焽閿濆懎缍栭柛妯煎枑濞肩敻寮?*闁哄啰濮靛顖涚?*闁?`morphReset()`闁靛棗鍊介埀?`morphReset()` 濞?
            //   **`morphGen++` 濞?`morphUsable = false` 濞?`morphSessionStarted = false`**闁?
            //   闂傚偆鍣ｉ。浠嬪捶閵娿倗鑹鹃柨?*闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁哄啳顔愮槐?闁哄倻澧楅幐閬嶅绩妤ｅ啨鈧鎯?`onAppear`"濞?闁哄唲鍥モ偓澶愭閵忕姷鏉藉〒姘儑濞?`onDisappear`"
            //   闁告垹濮崇粻顕€宕ョ仦鑺ュ闁告瑦鍨归弫?* 闁?閺夆晜鐟ょ粩鎾矗閵夈倗绐楅柟?*闁告帗鑹鹃崹浼存偨閸楃儑绱﹂悘鐐插€哥紓鎾剁博鐎ｎ亗鍋ㄩ柣銊ュ閺屽﹥绋夐埀顒佹姜椤旇壈鍩岄柛娆惷肩槐鎵嫚?*濞戞挴鍋撻悹褔鏀辩粩濠氬箳?
            //   闁?`morphUsable` 婵ɑ鐡曠换娆愮▔閸濆嫪娴?闁?閻庡湱鎳撳▍鎺楀磻濠婂啯韬柟顓熷笧閻?闁?**闁煎啿鏈▍娆撳极閺夋垹娼岄柕鍡曠劍閻ュ懘寮垫径濠傂楅柣?*闁?
            //
            //   闁?闁告梻濮崇粩鎾焼閹剧粯锛岄柨?*闁规亽鍔忕换婊勭▔閳ь剟骞忓鍛櫃婵炴挸鎷戠槐婵嬬嵁閺堢數鐟?闁兼眹鍎甸崑鍛▔閳ь剟骞忓鍛殥缂備礁绻戝﹢浣该洪懡銈嗙祷闁汇劌瀚槐鎵嫚濠靛棙鐨戦悹鍝勭枃缁?**闁?
            //     闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁告帇鍊栧畵浣烘媼閵忊槅鍔€闁挎稒鐡猰orphUsable` 闁?`morphSessionOughtToLive()`**闁挎稑顧€缁?
            //       闁告鍠愬鍨交濞嗘挸娅￠柛?`morphUsable`闁挎稑鐗嗛崵鎴炴媴閺囩偛鍤掗悘蹇氫含閸楀酣鏁嶆径鍡忓亾閺傝　鍋?*闁革负鍔庨崑锝夊礄閺勫繒绠归柡澹溿倗鐔呭☉鎾筹工閻ｇ姾绠涢崨顖氬Ё濞戞挸鎼禍?*闁?
            //       閻犙囨敱婢ф粍绋夋惔銏犵槸閺夌偘绮欓崑鍛▔閳ь剟宕氶懡銈囩煉闁绘劕缍婇弫瀣倷绾懐绠锋繛宀嬬節閸ｆ椽宕氱敮顔剧`morphUsable` 閻忓繗椴稿Σ?false
            //       闁?閺夆晜鐟╂禍楣冩⒒?*婵ɑ鐡曠换娆忣嚕閳ь剟鎯堥埀?* 闁?濞戞挸姘﹂～锕傚礆閻樺啿绔撮柣銊ュ閸嬪懘宕ｉ妷锔斤骏闁哄鈧弶顐?`morphReset()` 缂佹稑顦悳顖炲Υ?
            //       闁?闁哄牜鍓濋悿鍡欑磼瑜忛悽鑽ゆ媼閵忊槅鍔€闁挎稒鐡猰orphSessionStarted`闁挎稑鐗呯粭鍌涚▔閳ь剟鎮ч崼顒傜濞?`playerRouteStillPushed()`
            //         闁挎稑鐗呯粭鍌涚▔婵犱胶顏遍柣妤€鐗炵槐姘舵焾閹存帞鐟濋悗鐢垫缁辨繈鎮堕崱娆愭殸閻?{@link morphSessionOughtToLive} 闁汇劌瀚顕€鎮¤閵嗗啴濡?
            //       闁宠法濯寸粭?濞?`aboutToDisappear()` **闊洤鎳橀妴蹇涘触鐏炶偐顏卞☉鎿冧簻閸ㄤ粙骞?*闁挎稑鐗嗛幃鎾寸▔閳ь剝銇愰姀銏犘﹂柨娑樺缁楀鎷嬬粙鎸庡€楅柛鎰懁缁斿瓨绺藉Δ瀣闁?
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
            // 闁?2026-10-15闁挎稒姘ㄧ紞澶愬冀閼规澘鍓归柡鍜佸灣濞堟垵鈹冮幇顏嗙Т闁搞儱褰炵弧鍐亹閹烘挻鎷卞銈呯仛鐎垫棃寮?闁?闂侇偀鍋撻柛锕€鎼换鈧銈堫唺缁斿鎸ч悜钘夋珵闁衡偓?
            //   闁挎稑鐗嗛幆渚€宕氬▎鎰Ж婵炲枴銈囩闁告垹鍎ら幐閬嶅绩妤ｅ啨鈧鏌堥幋鎺旂獥婵犳洖绻嬬粩鏉戭嚕?64閼?4 闁?PixelMap闁挎稑顦埀?
            this.releasePixelMapQuiet(this.meshSrc);
            this.meshSrc = undefined;
            // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁?*閻炴稏鍎茬槐?*闁挎稑顧€缁辩櫗閹?40` 闁哄倹婢樻慨鐐烘儍?閻庣懓顦靛銈囩玻濡も偓瑜版稑顕ラ崨鍏绱旈幋鐐靛婵?濞戞梻鍠庣紞濠囧嫉椤掑嫨鈧骞愭担瑙勭畳 闁炽儲鏌￠埀?
            //   閻庣懓鍟﹢顏嗙玻濡も偓瑜版盯寮甸悢宄版暥闁告瑯浜濆Σ?*闁圭鍊诲?*闁挎稑娼塸endingMeshPm`闁挎稑顧€缁辨繈鎳熼妷銊х婵炲牏鏁婚崳閿嬨亜閻㈠憡妗ㄩ悘蹇涗憾閳ь兘鍋撻柛锕佹〃缁繝鏁?
            //   濞戞挸锕浼存焽閿濆懎缍栭柛娆樹邯閸ｆ挳寮?`meshSrc`闁?*闁圭鍊诲鍐儍閸曨喚绠圭€殿喚濮村銊ヮ潩濮濆瞼绠兼繝鏇炵箲鐢偓**闁挎稑鐗嗛幃鎾剁尵鐠囨彃鏁堕悗娑櫭畷濂告偨閻斿吋锛栧Λ鐗堬公缁?
            //   濞?閹?37 闂侇叏绲奸柌?闊浂鍋嗛崣?PixelMap 婵犳洖绻戠粩?闁告艾濂旂粩瀛樼▔椤忓嫯鍩岄柣妯款啇缁辨岸濡?
            this.releasePixelMapQuiet(this.pendingMeshPm);
            this.pendingMeshPm = undefined;
            this.imageLabel = $r('app.media.ic_avatar1');
            // 濡炪倗鏁诲浼存焻閳ь剟宕烽崫鍕不闁瑰搫顦卞鍐嚌閹绘帗鐝ら柛鏂诲妿閺侀箖鏁嶅顓熸閻忕偛绻戠粊锕傚礂婢跺笑闁归晲鑳堕悽濠氭儍?GPU 鐎殿喒鍋撻梺搴撳亾闁挎稑鑻幃妤呭矗妫颁胶鐟濋悹鍥ュ劤濞呇囨嚀濡ゅ啯鏆?
            try {
              this.flowLightController.stop();
            } catch (_err) {
            }
            const wu = WindowUtil.getInstance();
            wu.applyPlaybackWindowChrome(false, false);
            Logger.info('RzdPlayerRoute', 'leave overlay: window layout unchanged');
            wu.applyPcPlaybackDecorButtonStyle(false);
          })

          // 闁宠棄鎳夊Σ?A2闁挎稒纰嶉悺鏇犳嫚瀹ュ鈧銇勯崼鏇炲姤闁汇劌瀚ㄩ埀顒€鑻惃婵嬫?+ 婵繂鑻幃鏇㈠Υ瀹ュ棜鐧侀悘鐐插€堕埀?
          //   闁衡偓閹勮含 Stack C 闁?*闁哄牃鍋撻柛姘凹缁斿瓨绋夐鍕靛妷閻?*闁挎稒鐡猵osition` 闁?闁烩晝顭堥顕€鎮ラ崜浣虹煁濞寸姾娉涙稊蹇旂▔婵犲拋娼￠柣銊ュ缁鈧數鎳撻悾鐐媴?闁?
          //   闁兼澘鏈﹢鎵沪閸屾粍鐣辩€归潻缂氱粭鍌滄喆閹烘垶鐨戦柡鍕靛灣閻涖儵宕ｉ敐鍛枾闁绘劗娅㈢槐娆愮▔?`MorphCoverBridge` 闁告艾鐬兼鍥触鐏炶棄缍撶€垫澘瀚哥槐姘跺焽?
          //   `PlayerExpandState.lyricMorph()` 濞存嚎鍊曢崵顓㈡儍閸曨厾宕堕柛娆欑到濞兼寮介崶褍璁插ù鐘劤濞插潡骞掗妷褎鏆忛柨?
          //   闁告艾鏈鍌溾偓鐟板暙濠€顏呮交濞嗗酣鍤嬮悶?`scale/translate/clip` 闁告瑦蓱瀹曞弶娼婚崶鈺傜暠閻庡湱鎳撳▍鎺楁煂?闁?**闁衡偓閹増宕抽柡鍐╁劶缁愶繝鎯堥埀顒佺▔閳ь剛鎸ф搴ｇ礆**闁?
          //
          // 闁粹偓閺傜儤纾?2026-10-16闁?*闁哄牜鍓濋悿鍡欐嫚閺囷紕绠栧☉鎾亾婵?闁圭顦板Λ銈夋偩鐏炵晫婀寸紒鐙欏嫭鍎旈柛鎺嶅嵆閵嗗妫冮姀锛勫缂?闁挎稑鏈敮鍦偓鐢靛帶閻ｎ剛浜告潏銊﹀闁搞儳鍋樼花?*闁挎稑顧€缁?
          //   闁哄啰濮烽弲顐︽儍閸曨偆婀寸紒鐙欏應鈧鈧湱鍋炲Σ?婵炴惌鍠栨慨鈺冧沪閸屾瑧鐟?`playerPane` 闁告艾鐬兼鍥Υ娴ｅ憡韬憸鑸灩瑜板鈧湱鎳撳▍鎺撶▕鐎ｎ亶妯?
          //   闁挎稑娼墂ujie.pa:1861` 闁?builder 濡炪倕鎼花顓犳偘椤帞绐?1 `floatingCover` / 12 `metaRow` /
          //    13 `floatingMeta`闁挎稑鐬奸?**52** 闁归潧绉靛Σ?`playerPane`闁挎稑顦埀顒佹煛閳?
          //   濞?*闁瑰瓨鍨冲鎴炵▔瀹ュ牆鍘撮柣鎾楀嫭鍎旈梺顓ㄧ导闁叉粎浠﹂崒婊堢崜**闁挎稑鑻敮顐﹀炊閻樺弶韬?閺夆晜鐟ら柌婊呪偓鍦嚀濞呮帡宕烽妸銊х濞戞搩浜濈拠鐐典沪閸屾瑧鐟愬鑸佃壘閸忚鲸绂嶉崱鏇狀伇濞寸姵婀圭花?闁?
          // ```
          //     闁哄啰濮烽弲顐︽晬濮橆剛娈遍梻鍫涘灩閺勫倻鈧?= edge 閼?scaleAt(t)闁挎稑婀憃verMorph 缂佺虎鍨伴崵鎴炴媴閺囩姷鏆柛鎴犲劋濞肩敻鎯冮崟鍓佺
          //     闁瑰瓨鍨冲鎴︽晬濮橆剛娈遍梻鍫涘灩閺勫倻鈧?= morph.size 閼?**閻庡湱鎳撳▍鎺楁儍?morphScale**闁?闁告瑦蓱瀹曟彃顕?闂侇叏绲肩粩瀵糕偓?
          //           .scale(morph.size/base.size) + .translate(...) 闁汇劌瀚鍥偋閳哄绀夐悷?
          //           `LyricFloatLayer` 闁?闁?闁规亽鍔岄閬嶆晬?
          // ```
          //   闁?閻庡湱鎳撳▍?`scale` 閺夆晜鐟ょ粩鏉懳涢幒鎴炶含闁瑰瓨鍨冲鎴炴交濞嗘帞鐝?*闁告艾鏈?*闁瑰灚瀵ф刊瀛樼?闁告劕鎳庨鎰沪閸屾繄顎€闁活偀鍋撶紓?濞?
          //     "婵炴惌鍠栭惇鎵焊娓氣偓濞肩増绂掓惔銏℃缂佹劖顨婇崑鍛▔閳ь剚绂掗悾宀€绱氶柛鎺撳缁姵鎷呴悩铏拫闂侇叏绲肩粩瀛樼?**濞戞挶鍊撳▎銏＄?*闁挎稒绋掑Λ銈夋偩鐏炶棄娑ч柟鍨婵挳宕滃鍫氬亾閸涱偀鍋?
          //   闁?闁硅泛锕ョ拠鐐典沪閸屾稒鍎旈柛鎴濇惈椤旀劙宕?= 濞戞挶鍨虹敮鈧柛姘唉閳?闁?閻忓繋绶氬浼村捶閵娿儱袟闁汇垼顔婇懙?*閻?`morphScale` 闁?*
          //     闁挎稑鐗愰幑锝夊箥鐎ｎ偅顦?闁?0.082 闁?闁告瑯浜滄晶?8%闁挎稑顦埀顒€鍊块崑鍛潰閿濆棙笑闁活潿鍔嶉崺?*鐎规瓕灏欑划锛勨偓鍦仦缁佸瓨娼?*闁汇劌瀚懜浼存偐鐠佸湱绐?
          //     `morphOverlayBridging()` 婵炲鍔戦崳鎾煂瀹€鈧▓鎴﹀Υ鐏炵晫娈遍梻鍫線缁姵绋夌€ｎ亞绐斿☉鎾筹躬椤ワ綁濡?闁靛棗鑻惃婵嬫閵忋垻绱氶柟瀛樺姃缁旀挳鎮欓獮搴撳亾瀹ュ啠鍋?
          //   闁?**閻熸洑鑳跺﹢锟犳偂瑜庨幆澶愭焽閿濆嫰鍤嬮悘鐐插€绘鍥晬鐏炶棄顤呯紓鍐惧枟濞碱垱绂掗懜鍨﹂柛蹇撶墛婵″摜浜告笟鈧浼存儍閸曨偅妲€閻庨潧鎲″闈涒攦閹邦厽鏆柟?`scaleAt(t)`**
          //     闁挎稑鐗嗛獮鎾诲箳婢舵劕浜濆☉鎾亾閻?`.scale/.translate`闁挎稑顧€缁辨繈鏌囬敐鍡樞﹂悹鎭掑妺缁椾焦寰勯崟顓熺暠缂備焦鎸婚悗顖炲绩閻熸澘袟 + **闊洤鎳橀妴蹇涘嫉婢跺寒鍟庡璺烘喘閳ь剚鍔曢幎姘舵儑?*闁?
          //   閻庣懓鏈弳锝夋偠閸℃瑦鏆犻悷娆庣劍濠€浼村棘閸ワ附顐介柡?`Stack` 闂佹彃鐭傞崑鍛枔?`闁粹偓閺傜儤纾?濞戞挸绉烽々锕傚箮婵犲啳鐧侀柛鏂诲妼閻即骞栭鈧崺灞炬交濞嗘挸娅 闁汇劌瀚弫鐐烘煂婵炲簱鍋?
          if (this.usesPhoneSwiperLayout()) {
            this.LyricFloatLayer()
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      // 闁宠棄鎳夊Σ鍕煡?2026-10-17闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`PLAYER_ROOT_ID`闁挎稑顧€缁?*闂傚牏鍋炴晶婊堝礉閸喖褰犻梻鍌ゅ弨椤╋箓骞忓鍥ㄧ暠闂侇叏绲界槐鎯扮疀椤愩倕寮鹃悘蹇氶哺濡叉悂寮甸鍐ㄎ濋柣?*闁?
      //
      // 闁哄啰濮烽弲顐︽焽閿濆嫮顏卞〒姘€宥囩`.id(PLAYER_ROOT_ID)` 闁圭鍊稿﹢?*閻?`.scale/.translate/.clip` 闁汇劌瀚伴崑鍛▔?Stack 濞?*
      // 闁挎稑娼墂ujie.pa:191400-191478`闁挎稒鐡?scale` 191400-191415 闁?`.translate` 191416-191431 闁?
      //   `.clip(true)` 191462-191469 闁?**`.id(PLAYER_ROOT_ID)` 191470-191478**闁挎稑顧€缁?
      // 闁?`MeshCoverBg` 濞?`playerPane` 闂侇喛妫勫﹢顏嗏偓?*闂佹彃鐭傚?*闁挎稑鐗婂﹢鐗堛亜?:4952-4970 闂侇叏绲鹃宀勬焻閹邦垼鏀介悗闈涙贡閸欏酣鏁嶆径鍫氬亾?
      //
      // 闁?闁圭鍋撳ù鐘劥缁绘牠鏌岀仦鑲╃槏闁圭鍊稿﹢?*鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞?*閺夆晜鐟ょ粩瀵镐沪閸岋妇绀勫☉鎾崇У濡插摜鈧懓鍟板▓鎴︽偉?`Stack`闁挎稑顧€缁?
      //   闂傚牊鐟﹂娑㈠箑娓氬﹦绀刞morphScale=1 / translate=(0,0) / 闁哄啰濮鹃ˉ鍡涘礈閻氭棃鏁嶆径濠勬殜閻忓繗椴稿Σ?*婵犲ň鈧磭娼岄柣銊ュ閹搁亶寮ㄦィ鍐︹偓?*闁?
      //   闊浂鍋嗛崣搴ㄥ箯閸喖鐓傞柣銊ュ椤掓粓寮?婵犲ň鈧磭娼岄梺顓ㄧ导缁旀潙顕? 闁炽儲鏌￠埀?閺夆晜鐟﹂婊堝及?`ShrinkOverlay` 閻熸洑鐒﹂惇鎵導妞嬪骸浠☉鎾冲瀵呬沪韫囨稈鍋撻幇顒€鍓肩紒杈╁Т椤曨喗顬囬幇顔界暠闁告挸绉佃ぐ渚€濡?
      //   闁宠法濯寸粭?闁搞儳濮甸?`componentSnapshot.get(PLAYER_ROOT_ID, 闁?` **闊洤鎳橀妴蹇涘捶閵娿儴鍩岄柛娆惷槐鎴炴叏鐎ｂ晝顓洪柛?*閻?
      //      闁挎稑鐗婂Λ銈夋偩瀹€鈧▓?`closeWithAnimation()` 濞戞梻鍠愬Σ鎼佸捶?`pullMode` 濞戞柨顑呴ˇ濠氬Υ娓氣偓閵嗗妫冮姀锝囩婵犲ň鈧磭娼岄柡鍐煐婢х娀骞忓蹇曠闁?
      //   闁宠法濯寸粭?濞?`MESH_BG_ID` / `MINI_LYRIC_BOX_ID` 缂?*妤犵偠娉涢悺?*闁挎稑娼塯etFrameNodeById` 闁?id 闁哄被鍎荤槐?
      //      濞戞挴鍋撳☉鎿冧海婵☆參鎮欓悷鏉挎锭闁哄牆顦粩瀛樼▔?id闁挎稒绋栫换鏍礄閻橀亶鍤嬮柡?*濞戞挸绉撮幃鎾绘嚍閸屾粌浠?*闁挎稑濂旂花鐗堢▔瀹ュ懎顨涢柛婵嗙▌缁辨岸濡?
      .id(PLAYER_ROOT_ID)
      // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁规亽鍎扮粭鍌涚▔婵犲啰鍩楅梺顓ㄧ导闁?LANDING 闁哄啳娉涙禒鐘电箔?闁汇劌瀚划顖炲礆閸洘锛?* 闁炽儲鏌￠埀?`playerPaintsOf`闁?
      //
      // ## 濞戞挸锕ラ悥鍫曟焽閿濆嫮顏遍柡澶嗗墲濡?*闁哄牆顦扮粔椋庢嫻绾應鍋?*闁汇劌瀚哥槐妾倃ujie.pa:153390-153430`闁挎稑鐣璏ainPage` 闁告瑦鍨电粩鐤亹閵忕姴缍侀柣妯垮煐閳ь兛绶氶崑鍛存煂瀹€瀣
      // ```ts
      //   AppStorage.setOrCreate(K_MORPH_SQUASH, playerPaintsOf(stage) ? true : false);  // 闁?閻忓繗椴稿Σ鍛婃交濞嗗酣鍤嬮悽顖氬暙閻?
      //   if (stage !== MorphStage.LANDING) { this.stopLandAnim(); this.morphSquashY = 1; }
      // ```
      // 闁?`playerPaintsOf(stage) = stage !== MorphStage.LANDING`闁挎稑娼塎orphState.ets`闁挎稑鐣瓀ujie.pa:93205`闁?
      // 闁?**閺?LANDING 闂侇叏绲肩粩鎾礆閺勫繑宕抽柨娑樻湰閹搁亶寮ㄦィ鍐︹偓澶愬极閹绢喓鈧绋夊鍛櫃缂備焦锚閸?*闁?
      // `PlayerPage` 濞撴皜鍡╁殺閻庣懓鍟銊╁及?`pullPaintable = !pullGeomReady ? true : playerPaints(stage)`闁?
      //
      // ## 闁哄牜鍏涚划銊╁储閻斿憡闄?*婵炲备鍓濈敮?*闁挎稑鐗婇鎾⒒椤帞绀?
      // `PlayerExpandState.playerPaints()` 闁哄啠鏅涘銊╁礃濞嗗繈鍋ㄥù婊冩４缁辨獋return stage !== LANDING;`闁挎稑顧€缁?
      // 婵炲鍔戦崳鎾煂鐏炶偐鐦嶉柛鎰懅濞煎啰鈧懓鍟村Σ濠氭儍閸曨剚笑濞寸姭鍋撳☉鏂跨墳缁?
      // > 闁靛棗顒欰NDING = 鐎规瓕灏欑划鈩冪閵堝牏绠风紓浣圭懆缁姵鎷呴悩铏拫闁挎稑鐗嗛顕€寮?`playerPaintsOf = false`闁挎稑顧€缁辩増娼诲▎搴ｎ伇閻㈩垎鍡樺闯闁圭虎鍘介弬浣广亜?
      // >   **濞戞挸绉撮崯鈧柣?*闁挎稑鑻幆渚€宕氬▎搴ｇ獥闁革负鍔忕化鐘虫媴閻樿櫕钂嬮悘蹇庣窔濞肩増绋夋繝鍕畬濞戞挴鍋撳☉?*闁告艾鑻弰鍌溾偓闈涙憸濞堟垵菐鏉堫偄顥忛悘蹇撶箲閺岀喖宕?*闁挎稑鐬煎ú鍧楀礆閹峰矈娼堕柛妤佺摃濞村洭濡撮崒妯峰亾?
      // 濞达絽妫楅悾?*闂傚棜鍩栫粔椋庢嫻绾應鍋?* 闁?闂侇叏绲借ぐ鐐垫嫚濠靛洤浼庨弶鈺傚濞堟垿鎮抽幏宀冩澖濞戞挴鍋撻柣鈺傛綑濠€顏堝矗閹寸姵鏅搁柕鍡楀€介埀?闁告艾鑻弰鍌溾偓闈涙憸濞堟垹浜歌箛鏃€鐓欓柛?闁革负鍔嶆晶婊堝嫉鏉炴壆鐟愭慨婵撶稻濡?
      // **濞戞挴鍋撻柡澶嗏偓宕囧彂闁活収鍠氬▓鎴︽嚄鐏炵偓鐝?*闁挎稑鐗嗛鎰板闯?`scale 闁?0.082` 閼?`clipHeight 闁?683` 闁?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼闁?
      // 330閼?6 闁汇劌瀚晶搴ㄧ嵁瀹曞洨鍙愮憸閭︽緛缁辨岸鍨鹃弬琛″亾?濞戞挸娴烽弫銈夊箣妞嬪寒鍎?闁?闁哄鎵冲亾?*闁哄牆顦抽崕妤呭疾椤栨瑧绋婚柡鍕靛灦閻濐喗鎯旈敂鎯ь棗濞?*闁靛棗绉归埀顒佸姇閻⊙囧触鐠囧弶鍊ら柕?
      //
      // ## 濞戞捁妗ㄧ划鍫熺▕?`.visibility(Hidden)` 闁兼澘濂旂粭澶愬及?`.opacity(0)` 闁瑰瓨鐗楀顖涚閼镐絻顩柡?
      //   鐠?`Hidden` = **濞戞挸绉剁划顖炲礆闊祴鍋撴担椋庣ɑ濞ｅ洦绻勯弳鈧悽顖氬暙閻?* 闁?濞?闁稿绮庨悷?闁告艾濂旂粻鐔兼晬鐏炶偐鐟☉鎾崇Т婵晜绂掔拋宕囩Э闂佹彃绻戠粊?闂佹寧姘ㄩ崑?
      //     闁挎稑娼塯etFrameNodeById` 闁汇劌瀚悡鈺勩亹椤兘鍋撴稊顤祅AreaChange` 濞戞挸锕ユ慨銈夋焾閹存帞鐟濋柛娆愵殔婵傛牠宕蹇曠闁?
      //   鐠?`.opacity(0)` 濞寸姴绉崇槐鎵導閹殿喚甯涢柛鎺戝椤撳摜鐥崠锛勭"闁稿绮庨悷?婵炲备鈧厖绮甸柛鎺戝簻缁辨岸鏁嶅畝鍐ｅ亾鐏炶偐鐟柡鍫墴閵嗗鎯?`.opacity` 鐎规瓕灏欑划锟犲及?
      //     `morphOpacityValue()`闁挎稑鐗婃禍?1闁挎稑鐭侀～鍡涙焽閿濆娅￠柣銊ュ閺佺偤鏌屾繝蹇曠闁?
      //   鐠?闁哄鈧弶顐芥繛鎾冲级閻撳瀵煎顓炍╅柤鍝勫€婚崑锝嗙鎼淬垻鍩愬☉鎾筹攻閹叉娊骞?闁?闂佹彃绻戠粊鏉戔攦閹邦厾啸濠㈣埖鍞荤槐妾侾LAYER_BIG_COVER_ID` 缂佹稑顧€缁辨岸鏁嶅畝鍕垫闂傚嫧鏅涢妵鍥Υ?
      // 闁宠法濯寸粭?闊浂鍋嗛崣搴ㄥ捶?`morphLand()` **濞戞柨顑呮晶?*闁瑰嘲绋勭槐娆戞喆?`closeWithAnimation` 闁汇劌瀚伴妴搴㈡償韫囥儳绀嗛柍?闁哄牜鍓熷Λ顒傜礄鐠囪弓娴烽柡?
      //    闁搞儲鍎抽崙锛勭磼韫囨挸鐓傞柟闈涱儜缁辨繃绋夊鍕獥闁瑰嘲绉撮崺灞剧▔閳ь剙顕ｉ悩纰樻晞闁搞儰鍕橀埀?
      // 闁宠法濯寸粭?濞戞挸锕ｇ粩瀵告暜瑜岀划娑㈠及?LEAVING闁挎稑鐗嗗﹢顏堟偨娴兼瑧绀嗛柍?闁稿繑濞婂Λ鎾礉閵娧勬毎闁哄牜鍓濋棅鈺傜▔瀹ュ懎缍€鐟滄澘宕幖鐑藉Υ?
      .visibility(this.expandState.playerPaints() ? Visibility.Visible : Visibility.Hidden)
      // 閻熶椒绀佹竟鈧紒鎰殔瑜版稒顨囧Ο鍝勵唺 = 闁告瑯鍨甸～瀣殗濡搫顔?/ 缂傚倵鏅滈弬?闁?缂傚倵鏅滈弬渚€宕ユ惔銏╁妧濠靛倽濮ゅΣ鎼佹焽閿濆懏鍋ラ柛娆樺灥椤鎯岄埡浣藉煂
      .height(this.morphClipHeight())
      // 閺夊牆婀遍弲顐ゆ啑娴ｇ顥呴柨娑樼墕濞撳墽鎲撮幒鏃€鏆犻柛姘濞存浠﹂崒婵嗘閻㈩垽璁ｇ槐杈ㄧ▔瀹ュ洦鏆?clipShape闁挎稒鑹鹃悾鐘冲濮樻剚娲柣?borderRadius闁?
      // 闁兼澘濂旂粭鏍偓鐟板暟濞堟垼銇愰姀銏犘﹂悗闈涚秺缂嶅牏鎷犻婵堢枀闁革负鍔嶅Λ銈囨媼閹屾У闁哄啳鍩栭惀鍛枖閺囥垻宕ｉ悹鍥︾筏缁?
      .clip(this.expandState.morphClipping())
      // 闁轰焦鎸抽妴澶岀磽閳哄倹鏉?+ 濞达絽绉朵簺闁挎稒宀稿銈咁潰閵忊檧鍋?scale=1 / translate=0闁挎稑濂旂粭灞解柦閳╁啯绠掗弶鈺傜懃椤ㄦ粓宕濋妸褎鏆伴柡鍐ㄧ埣閳ь剚鍔曢崕姘辨閻樿京顏遍柤?
      //
      // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯灱濞?*闁哄嫭鍎崇槐锟犳煥濮樺崬浠?*闁挎稑顧€缁?
      //   闁哄啰濮烽弲顐︽焽閿濆嫰鍤嬮悗鍦嚀濞呮帡鏁嶉崸鍓媢jie.pa:191400-191415`闁挎稑顦崯鎾绘儍閸曨剚笑
      //     `.scale({ x: expand.scaleValue, y: expand.scaleValue })`
      //   闁兼澘鑻悾鐘绘儍?`initTranslateX/Y` 闁?*闁?缂備焦娲戦懙鎴ｇ疀閸愵亞绱氶柡鈧?闁告瑥绉疯闁告垹鍎ゅ?*闁?
      //   闁挎稑娼塱nitParams` 51524-51575闁挎稒鐡?缂佹劖顨呴鏃堝焾閹跺xW)/2 闁?left` / `(h 闁?h鐠虹椀)/2 闁?top`闁挎稑顦埀顒佹煛閳?
      //   濞戞梻鍠庡銊╁及椤栨繍鍤?*"缂備焦娲戦懙鎴ｇ疀?闁哄嫷鍨伴悾鐘绘儍閸曨偄顤呴柟?*闁挎稑鑻ぐ褔寮伴鐐存祮濮掓稒顭堥濠氬磹閻撳骸骞€闁绘粏鍩囬埀?
      //   闁瑰瓨鍨冲鎴炴交濞嗗海顏卞〒姘€鍕暡闁哄牆顦崵鎴炴媴閺囶亞绀刞initTranslateX/Y`闁靛棔姊梒overHostW/H`闁靛棔绶氶埀顒€妫楄ぐ澶愬箲閵忊€宠吂閻庣數銆嬬槐姘舵偨閵娧勭暠濞戞梻鍠愬Σ?
      //   闁告艾濂旂粩瀛樼▔椤忓嫬顤呴柟缁樺姧缁辨繈骞嶉埀顒佺閵夈劎绠归梺?*闁硅泛锕ら悾鐘诲及閹呯闁告劖鐟ラ崵顓㈠级?*闁挎稒淇洪銏＄▕婢跺瞼鎼煎ù鐘插殩缁辨繃鎷呴崱妯何╅柛瀣穿椤旀洟鏌︽径瀣靛姤 闁炽儲鏌￠埀?
      //   濞戞挸娲ｇ粩瀵镐焊閸℃ɑ闄?ArkUI 闁衡偓闁稓鍟婂娑欘焾椤撳鏌ㄥ鍗炰化闁挎稑鐭佺换鏍ㄧ▔閳ь剛鎮板畝鍐ㄥ幋闁圭硶鈧尙绉?闁轰焦娼欓〃婊堝礄閻樿京绉垮☉鎾亾閻犙呭厴閺佸﹥鎷?闁?
      //   闁宠法濯寸粭?**闁告瑯浜濆﹢?`centerX/centerY` 闁?闁烩晝顭堥顕€鎳涢鍥叐闁汇劌瀚▍銊╁礆閸℃妲?**闁?0% = 闁煎搫鍊婚崑锝夋嚊椤忓嫮绠掗柣銊ュ閼垫垼绠涢崘璺ㄧ闁?
      //     闁圭鍋撳ù鐘劚濠€顏呯鐠佸磭绉块悘蹇撴惈椤曨厽绋夌€ｎ喖鍘寸紒娑橆槷閻滎垱绂?缂備焦娲濋崵婊堢叕椤惵ゅ幀闊?闁?
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

      // 闁粹偓閺傜儤纾?2026-10-16 闁炽儲鏌￠埀?**濞戞挸绉烽々锕傚箮婵犲啳鐧侀柛鏂诲妼閻即鏁嶉崼婵堟闂?婵繂鑻幃鏇㈡晬婢跺鍎旈柛鎺撳缁绘牠鏌屽畝瀣濡炪倗鏁诲浼村冀閸︻參鐛撻柨?*闁?
      //
      // ## 闁瑰瓨鍨跺﹢鐗堟姜椤旇法妲搁弶鈺佹矗缁旀潙鈻庨埥鍛闁规亽鍔岄杈┾偓鐟拌嫰濮樸劑骞橀妶鍛濞存粌妫寸槐娆戞媼妫颁胶鐟撻柡澶堝劚閸樸倕顕ュ鍓х憮婵炲棌鈧啿鏅欓悹鍥ㄦ穿缁?
      // 闁哄啰濮烽弲顐︽儍?*閻忕偛鍊绘?*缁绢収鍠栭悿鍕及?婵炴惌鍠栨慨鈺冧沪閸屾瑧鐟?`playerPane` 闁告艾鐬兼鍥Υ娴ｅ憡韬憸鑸灩瑜板鈧湱鎳撳▍鎺撶▕鐎ｎ亶妯?
      // 闁挎稑娼墂ujie.pa:1861` 闁?builder 濡炪倕鎼花顓犳偘椤帞绐?1 `floatingCover` / 12 `metaRow` /
      //  13 `floatingMeta`闁挎稑鐬奸?**52** 闁归潧绉靛Σ?`playerPane`闁挎稑顦埀顒佹煛閳?
      // 闁圭鍋撳ù鐘劜閸ㄦ粍绋夐埀顒佹償閿旇棄惟閻庣懓鍟幆澶愬礆妫颁胶鍟婇柡鍫墮閻即鏁嶅畝鈧幃濠囨偨鏉堛劍笑"閻㈩垰鍟惇顒勬儎閹哄秶鐟㈤柡瀣ㄥ灱闁伴亶鏌堥悾灞藉季闁?闁?閻熸瑥鍊归崝鍛村矗濡搫顕у☉鎾存そ濞?闁?
      //
      // ## 濞戞捁妗ㄧ划鍫熺▕閸儱浜濆☉鎿冧簽閹﹪鎮?*闁哄嫷鍨堕弫濠囨儍?*
      // 闁哄啰濮烽弲顐︽儍閸曨剝鐧侀柛鏂诲妼閻即鏌屽畝瀣閻忓繋绶氬浼存偨閵娧勭暠闁?*缂佺虎鍨伴崵鎴炴媴?+ 濞戞挴鍋撴繛?`scale`**闁?
      // ```
      //   CoverMorph.scaleAt(t) = lerp(1, lyricScale, t)      // 85856-85743
      //   婵炴挸寮堕悡瀣焊閸濆嫷鍤?= edge 閼?scaleAt(t)                        // 85856 闂侇叏绲肩粩鏉戭浖?
      // ```
      // 闁?*闁瑰瓨鍨冲鎴炴交濞嗗海顏遍悘鐐插€诲▓鎴犱焊娓氣偓濞间即寮?闁告瑦蓱瀹曟彃顕?**闁挎稑娼塋yricFloatLayer` 闂佹彃鐭傞崑鍛偓?
      // `.scale(morph.size / base.size)` + `.translate(...)`闁挎稑鐭侀～鍡涙焽閿濆娅￠柣?闁?闁规亽鍔岄閬嶆晬婢跺棌鍋撻弬琛″亾?
      // 閻庣懓鍟板▓鎴犱沪韫囨挾顔庨悘蹇撴惈椤?= **`morph.size` 閼?閻庡湱鎳撳▍鎺楁儍?`morphScale`**闁靛棗鍊风弧鍐焊鏉堛劍笑閻犲洩鎻槐?
      // ```
      //   閻庡湱鎳撳▍?scale 閺夆晜鐟ょ粩鏉懳?*闁告艾鏈?*閻犳劗鍠曢惌妤佺▔閵堝嫭顐藉ù婊冾儜缁?
      //     闁?闁告劕鎳庨鎰沪閸岋妇绀則opBar/scrubber/transport/婵繂鐭侀惁婵嬫晬婢跺海顎€闁活偀鍋撶紓?闁炽儲鏌￠埀?闁哄啰濮烽弲顐ｇ▕閻斿憡绠掗柨?
      //     闁?婵炴惌鍠栭惇鎵焊娓氣偓濞间即鎯?*閻忓繐鎼?*濞?闁轰礁顕悰銉╂焽閿濆嫮顏卞ù?缂傚倵鏅涢崺?閺夆晞娓圭紞姗€寮堕敓鐘蹭簼濞戞挴鍋撳ù? 闁炽儲鏌￠埀?闁哄啰濮烽弲?*婵炲备鍓濆﹢?*闁挎稑鐗嗛悾鐘绘?scaleAt闁挎稑顦埀?
      // ```
      // 闁?闁硅泛锕ョ拠鐐典沪閸屾稒鍎旈柛鎴濇惈椤旀劙宕抽妸褎鐣遍梺顓ㄧ导缁旀挳宕氭导娆戠闁?閻忓繐褰夊☉顏呯?闁?閻忓繋绶氬浼村捶閵娿儱袟闁汇垼顔婇懙?*婵絾姊归婊呮兜椤斿皷鍋撻悡搴ｆ瘓 `morphScale` 闁?*
      //   闁挎稑娼塵orphScale` 闁革负鍔忛幑锝夊箥鐎ｎ偅顦?闁?0.082 闁?閻忓繋绶氬浼村矗椤忓嫬鈷?8%闁挎稑顦埀?
      //   闂侇叏绲鹃婊堝及?*闁活潿鍔嶉崺娑橆啅閼碱剛鐥呴悗鍦仦缁佸瓨娼?*闁汇劌瀚懜浼存偐鐠佸湱绐?
      //     `PlayerExpandState.morphOverlayBridging()` 闁汇劌瀚弫鐐烘煂婵犲倸鏂ч柡?闁炽儲鏌￠埀?
      //     闁靛棗鏈崹婊勭▔婵犱胶顏遍柣妤€鐗嗛崣褔骞掓径濠勬殜闁靛棔鐒﹂弫鑲╂媼閳哄倹灏￠柡鈧ィ鍐︹偓澶愭煂瀹€鍕簼鐎殿喚濮峰﹢锛勪焊娓氣偓濞间即鎮鍐ㄦ闁瑰灚瀵ф刊鎾晬瀹€鈧划銊╁几濠婂嫭笑闁挎稒鍩冮埀顒婄畳椤洭骞囬悢绋跨亣濞?
      //       闁?*閻忓繋绶氬鐗堢鎼存繄鐟撶€垫壋鍋撳☉鎾筹躬椤?*闁靛棗绋勭槐娆撴偨閵婏箑鐓?2026-10-16 閻庡湱鍋炵粊鎾晬婢跺牃鍋撳蹇曠
      //     濞寸姰鍎卞?`閻忓繋绶氬鎵磽閳哄倸鐏囧☉鎾亾闁绘劕绠嶉埀顑跨閻秴顕ｉ埀顒勫礉閵娧勬毎婵炲备鍓濆﹢浣虹博椤栨粌浠痐 闂侇叏绲介崵鎴濃枎鎺抽埀?
      //
      // ## 缂備焦鎹侀鎴︽晬閸粎鐟撳☉鎾亾濞戞搩浜欏Ч澶愭儎鐎涙ê澶嶉柣鎾楀棛绠归柡澹溿倛娉查柨?
      //   婵炴惌鍠栭惇?*闊洤鎳橀妴蹇涙偩濞嗗繑韬憸鑸灩瑜板鈧湱鎳撳▍鎺楁煂?*闁靛棗鍊瑰Λ銈夋偩鐏炶偐顓洪柟纰樺亾濞寸姰鍎撮崗姗€寮ㄩ幆褎韬鑸电墵濞间即鏁嶇仦鐐﹂柛銉уС鐠愮喓鈧懓鍟板▓?*閻忓繋绶氬浼存嚊椤忓洭鐓?*闁?
      //   缂佺虎鍨伴崵鎴炴媴閺囶亞绀勯悘蹇撴惈椤?濞达絽绉堕悿?闁革箑妫滈～妤呭礂閵娾晛鍔ョ紒鐘愁殔閸ゎ參寮堕妷顖滅濞戞挸绉撮幃鍡樼鐠佸磭绉跨紒浣圭墪閸樻盯宕ｅΟ璇插簥闁挎稑顦埀?
      //   闁?閻熸洑鑳跺﹢鈥愁潰閿濆洤寮鹃柟纰卞墴閸嬪懏绋夐鍕勾缂佺嫏宥囩闁告挸绉堕悿鍡涘级閳ュ弶顐介柡?*闁稿繐鐗婃俊鍝ヤ焊娓氣偓濞间即鎯冮崟顐ｆ閻庨潧鎲″闈涒攦閹邦厽鏆柟?`scaleAt(t)`**
      //     闁? 闁告绮敮鈧?闁告瑦蓱瀹曟彃顕?闂侇叏绲肩粩瀵糕偓?`.scale/.translate`闁挎稑鐭侀鈧?`lyricMorph(t)` 闁烩晛鐡ㄧ敮瀵哥磼?
      //      閻忕偛绻愮粻椋庝焊閸濆嫷鍤熼柨娑橆檧缁辨繈鏌囬敐鍡樞﹀☉鎾亾婵?*閻犳亽鍔嬬粭浣瑰緞?*闁汇劌瀚划銊╁几閸曨剚鏆柛鏃戠厜缁辨繃绋?*闊洤鎳橀妴蹇涘嫉婢跺寒鍟庡璺烘喘閳ь剚鍔曢幎姘舵儑?*闁?
      //   濠㈣泛绉甸悧鎶藉川閹存帗濮㈤柨娑欑摢grep -rn "LyricFloatLayer()" RzdMusic --include=*.ets`
      //     闁挎稑鐗婂﹢锟犲嫉濞戝磭绐楅柛娆樹簼濠€?*閻庡湱鎳撳▍鎺楀礃?*闂侇叏绲肩粩瀛樺緞閸曨喚娈堕柣銏╃厜缁?

      // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁?*闁绘粍婢樺┃鈧柤濂変海閻?*闁挎稑鐗愮换娑㈡倷瑜版帇鈧﹪鏌?3 婵炲棌鈧磭纾婚柛蹇曨劜缁辨繄鎲?`onDiagHotspotTap()` 闁汇劌瀚弫鐐烘煂婵犲繒绀嗛柕?
      //   闁衡偓閹勮含鐟滆埇鍨硅ぐ澶屸偓鍦嚀濞?*濞戞柨顑呴ˇ?*闁挎稑鐗呯粭澶屾偖椤愩倗绱氶柡鈧?閻熶椒绀佹竟鈧柨娑橆檧缁辨繈骞嶉埀顒佺閵夈儳鏆婇柡鍕⒔閵囨岸鎯冮崟顒佹閻庢稒銇炵粭宀€鎷犵紒妯绘闁告艾鑻ぐ娑橆嚗閸曗斁鍋?
      //   闁宠法濯寸粭?鐎垫媽濮ら悥锝夊礂瀹曞洦绲婚柡?`diagText` 濞戞捁娅ｉ埞?闁?闁绘埈鍘肩亸顖炲及?*閻庣懓鑻崣蹇涙焻韫囨梹顫?*闁汇劌瀚粩鎾级鎺抽埀顑跨缁愭﹢寮介崶顒佺ォ婵炴挸寮堕悡瀣Υ?
      this.DiagHotspot()
      if (this.diagBadgeOn) {
        this.DiagBadge()
      }

      // 閻犳亽鍔忛崜濂稿嫉椤掍礁搴婃繝褎鍔欓崯瀣儎椤旇棄绲圭紒鈧悜妯忣參鐛崪鍐闁诡噮鍓氱拠鐐哄捶閵婏附浠樺☉鎾筹躬濞间即鏁?
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }

      // 闁宠法濯寸粭?缂備緡鍙冮ˉ锝囦焊娓氣偓濞间即鏁嶉崸鍑猳rphCoverBridge`闁?*濞戞挸绉村﹢顏呮交濞嗘挸娅?*闁?026-10-15 閻犙冨槻閻ｇ娀鎮界拠鍙夎含**闁告劕鎳庨鎰沪閸屾瑧顓洪柛?*
      //    闁挎稑鐗愰～鍡樼▔婵犲洦妗ㄩ柡?Stack 闂佹彃鐭傞崑鍛枔閸偅鏆堥梺鎻掝煭缁辨岸鍨鹃弬琛″亾?闁汇垼顕у﹢顏呮交濞嗗海顏遍悘鐐插亰缁辨瑩宕橀崨顓у晣濞戞柨顑勭粭鍌炴晬婢跺绐楅柟璺猴梗缁姵绋夌€ｎ亜纾抽悹褔顥撳▓?
      //    閻忓繐绻戦悺鏇犳嫚?闁衡偓閹増顥戦柟绋款樀閹?閺夆晜绋戠€规娊寮?閹煎瓨娲熼崕鎾箰婢舵劖灏﹂柛蹇嬪姂閸忔﹢宕㈢€ｂ晝绉堕柨娑樼灱閺併倝骞嬪畡鎵澖婵?閻忓繐绻戦悺鏇犳嫚瀹ュ嫮鐭ら悘蹇庣窔濞间即鎳楃仦鑺ュ€甸柛鎴ｆ楠炲洭濡存担鐣岀閹艰揪闄勫顖滄偖椤愶絽鐨?闁?
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 闁?濞戞挸顑嗘刊娲绩閹増宕抽柟缁㈠幗閺備線宕抽…鎺旂MusicHome 闁告艾鏈娆愮閵堝嫮闉嶉柨娑橆檧缁辨壆绮╅弽顐ｇ函闁归攱鐗楃€氳法鎹勯悢绋款杹闁衡偓閹増宕抽柨娑樻湰濠㈡骞嶇€ｎ偄鐦婚梻鍐ㄧ墕閳ь剛鍘ч崰鍛偓瑙勮壘楠炴捇鎮惧▎宥佸亾?
    //   闁圭鍊稿﹢顏堝嫉閳ь剚寰勯弽褏婀撮柨娑欑⊕閻℃洜鎷犲澶婁簼缂佸绉磋ぐ鎻掝煥濮橆剙袟閻庢稒鍔樻俊顓㈡倷闁稓绐楅柛蹇撶墛鐢挳宕氶幍顔惧建闁烩晛鐡ㄦ晶婊堝礉閸栵紕绀?
    //   闁圭鍋撳ù鐘劚濠€顏勵潰瀹€鍐Г濞戞挸锕ョ划瀛樼▔瀹ュ嫮绐楅悹鍥跺灥琚濋柛娆愬灦閺佸湱鎸ч崙銈囩ArkUI 闁汇劌瀚晶婊堝礉閸喖鏅繛澶涚節閵嗗孩鎯旇箛銉х獥閻庢稒鍔樻俊顓㈡倷闁稓鍠橀柛蹇撶墳缁辨岸濡?
    .gesture(
      PanGesture(this.panOption)
        // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儍閳ь剙鏈惀鍛枖閺囨氨鐟撻柟宄邦槸閸櫻囨⒒椤撶喐灏￠柡鈧幆褎鐝ら柕鍡楃Ф濞堟垿骞掗幒妤侇唶闂佹寧姘ㄩ崑锝夋晬婢舵稓绐?
        //   闁哄啰濮烽弲顐︽焽閿濆嫬鏁滈柟闈涱儏婵炲秹寮伴姘辨暔 `onActionStart 闁?dragBackStart()` 闁?
        //   闁挎稑娼塤recover/logic-src/鐎殿喒鍋撻柛蹇氭珪閹搁亶寮ㄩ幆褎鐝?闁归潧顑呮繛宥囨崉椤栨氨绐為悗瑙勬皑椤?md` 閹?.3闁挎稒鐡狣own / distance:8` +
        //   闁搞儲绋愰柌婊堝炊閻愬墎娈?start/update/end/cancel 濮掔粯鍔曢崣蹇涙晬婢跺牃鍋撻崒娑樼亯濞寸媭鍓欑敮顐﹀级閵夈儱娑ч柡?update/end
        //   闁?濞戞挴鍋撻柡?濞戞挸顑嗘刊鍝勨柦閳ュ啿鍐€閹?闁?*闁告帒妫旂粭澶娿€掗崨顔叫﹂柟闈涱儏婵炲秴鈻介垾鍐茬厒閺夆晜鐟ｉ埀顑挎祰缁绘洟寮伴姘厒濞存粌妫旂徊鍓ф偖椤愶附锛岄柟绯曞墲鐢偓**闁?
        //   闁绘粍婢樺﹢顏堝箮婵犲倻鏆婇柟鍨尭閸ゎ參寮堕妷顖滅`hdc shell hilog -x | Select-String 'RzdMorph dismiss pan start'`闁挎稑顧€缁?
        //     鐠?濞戞挸顑嗘刊娲籍?*闁瑰灚鎸哥欢閬嶅礄閻戞ɑ闄?* 闁?闁归潧顑呮繛宥囨崉椤栨粍鏆犳慨婵撶到閻栧爼鏁嶅畝鍕紪濡増锚濠€顏堟⒒?闂傚啫鐗嗛埀?
        //       闁挎稑鐗婄敮鎾儓閳ь剟鎯?`RzdMorph dismiss blocked` 濞?`RzdMorph dismiss commit`闁挎稑顧€缁?
        //     鐠?**闁瑰灚鎸风粭澶愬礄閻戞ɑ闄?* 闁?缂佹梹鐗滃ú鍧楀箯閺嵮冃楁繛灞勩倖鍎伴柛鎺斿濠€浼存嚍閸屾粌浠☉鎾愁煭缁辨瑧鎮锛勭憪閻忕偛鍊归崹銊р偓娑欏姇閻即宕ラ崘鈺佺闁挎稑顦崳?閻熸洑鐒﹂弫濂稿箰閸屾繃绁伴柣鎰缁?
        //       闁哄啰濮烽弲顐︽儍閸曨偂绮垫繛澶嬫礃濡叉悂骞愰崒姘含**濡炪倛鍩栭悥顕€鏌囬敐鍕伇闁?Row**闁挎稑鐗撳顏勵煥濮橆剙袟闁靛棔绀佺换鈧悗瑙勭閺佸綊宕氱敮顔剧闁兼澘濂旂粭澶愬及椤栨稒娈诲銈囧仯閳?
        .onActionStart((): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan start isClosing=${this.isClosing} ` +
            `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}`);
        })
        .onActionUpdate((event: GestureEvent): void => {
          // 閻犺櫣鍠愭晶婊堝嫉閻斿吋锛熷☉鏃傚枔缁?velocityY闁挎稒纰嶇€氬宕濋妸銈堝幀閻庣懓鍟╃粭澶庛亹閸楃偞鎯欓柛鎺嬪€曢悾楣冩晬閸繂鐏查悗瑙勮壘瑜把囧捶閵婏附绶遍柟闈涱儔閸嬪懏绋夐埀顒傛暜瑜忛弫銈夋晬婢舵稓绀?
          // 濞磋偐濮剧换姗€宕㈢紒妯恍﹀☉鎾规〃缁繝寮妷銉х闂佹彃鐭侀崗姗€宕ョ仦鐐槯闁活亜顑呴崺?濞达絽绉朵簺 + 闂侇偆鍠庣€?闁汇劌瀚悾顒勫极鐎涙ɑ閿ょ紒鎹愶骏閳?
          this.onDismissDrag(event.offsetY, false, event.velocityY);
        })
        .onActionEnd((event: GestureEvent): void => {
          // 闁?D1闁挎稒纰嶅妤呭箥鐎ｎ厾绠瑰☉鎾亾閻㈩垎鍛暠 `velocityY` 閻忓繗椴稿Σ鎼佹焻閻斿嘲顔婇柟缁樺姃濮橈箓宕氶妶鍛毎闁汇劌瀚欢顓㈠礂閵夘垳绀刞GestureEvent.velocityY`闁?
          //   `gesture.d.ts` @since 10闁挎稑鏈﹢浼村嫉?SDK 鐎圭寮堕悧宕団偓鐢垫嚀閻°劑宕烽…鎺旂闁靛棗鍊婚渚€宕ｉ摎鍌滅憹闁汇垼椴搁崹婊勭椤掆偓娴滐絿鎷嬮幘鍛閻?`onDismissDrag`闁?
          this.onDismissDrag(event.offsetY, true, event.velocityY);
        })
        // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗嗛顔筋瀲閹邦厽锟ラ柣?闁搞儲绋戝ú鏍嫬?闁挎稑顧€缁?*閺夆晜鐟ょ粩鎾绩椤栨瑤绨伴柛鎾崇У濡插摜绱撻搹瑙勭暠**闁?
        //   濠㈢懓鍟块惇浼存焽閿濆嫮鐟忛柡澶嗏偓铏€辩紒顐ょ帛婢ф粓宕?*闂侇喛濮ゅ﹢?*閻?闁炽儲鏌￠埀?`products/default/闁?Index.ets` L1786闁挎稑娼塷nPullOpenCancel()`闁挎稑顦埀?
        //   `MiniBarPlayer.ets` L166闁靛棔姊桯omeMiniBarPlayer.ets` L235 闁?闁告瑥鐗婂Σ?
        //   "**闁告艾濂旂粩纾嬨亹閵忋垹笑闁?N 濠㈣泛瀚ㄩ埀顑跨瑜把囧绩闁稓鍟婂☉鎾亾濠?*"闁挎稑鐓?6.1.6 闂侇叏绲惧顖炲极濞嗘帩鍞查柣銊ュ椤戝洦绂嶇仦缁㈠仹闁绘粍婢橀懜浼存晬婢跺牃鍋?
        //
        //   缂傚倸鎼悾鐘绘儍閸曨偅鍊甸柡瀣矆缁楀本绋夋繝浣侯伇閺夌儐鍠曢幈銊╂儍?`isClosing` 婵炲牆顑囬弳鈧?*闁告艾濂旂粩瀵哥尵?*闁挎稒纰嶆晶婊堝礉閼愁垼娼跺☉鎿冨弮閳ь剚姊规晶锕傚棘椤撶喐顦?
        //   闁挎稑鐗忛柈瀵哥磼閻旂顤侀柛?/ 闁哄鍎抽弫绋课熼鍕暯 / 闁绘牕澧庢鍥箮閵忊€愁杹闁?/ 濡炪倗鏁诲鎵偖椤愩垹鐎奸悹褍搴滅槐姝歰nActionEnd` **婵﹢鏅茬粭澶屾喆閿曗偓瑜?* 闁?
        //     鐠?`dismissMorphActive` 婵炲牆顑囬弳鈧?`true`闁挎稒鐭粭鍛枎閳ヨ尙鐟撻柟宄邦槹濡?`!ended` 闁告帒妫欓弫顔藉?*閻犲搫鐤囩换?
        //       `morphBeginLeaving()`**闁挎稑鐗嗛悾鐘诲矗椤忓嫭韬?`!dismissMorphActive` 闁哄啳鍩栨晶鐘垫導闁垮顤侀柨娑橆槴閸?闁告垹濮崇紞宥嗙▔瀹ュ懎鐓曢柡鍌濆焽閳ь兛娴囩粣锟犲箥鐎ｎ喗鏅╁☉鏃€鍞荤槐?
        //     鐠?闁烩晠鏅茬紞鍛枔鐎ｎ剚娈?`LEAVING` 闁?`morphContainerActive()` 闁诡厽甯炲﹢?闁?
        //       `beginOpenMorphOnClick()` 闁汇劌瀚悾褔宕￠锝呂?闁绘劗鎳撻崵顕€骞嶉幘宕囩；"闁告帇鍊栭崹?**鐎规瓕灏欑划锟犲捶閵娿倗绐楅悹鍥ㄧ箞閸?*"闁兼澘鐬煎ú鍧楀箳?return false
        //       闁?**闁绘劗鎳撻崵顕€骞嶉幘宕囩；闁告瑥鐗撻埀顑藉亾闁告牗鐗楅崹姘烘ィ鍐従闁哄唲鍐ㄐ楅柣?*闁挎稑鐗婇婊堝及椤栨粍鏆忛柟鏉戝槻閻ゅ嫬霉鐎ｎ剚鐣遍梺顓ㄧ稻濞碱垶鎯€閸モ晛笑闁挎稑鐭侀埀顒€濂旂粭鏍ь嚗閸儲顕涘璺虹Ф楠炲洭骞?缂佸鍟块悾楣冨锤?闁挎稑顦埀?
        //
        //   闁哄啰濮烽弲顐︽儍閸曨偄鏅告繛澶嬫礀濮樸劑寮?*闁硅泛锕よぐ鍥р槈閸繄绉奸柟瀛樺姈濠㈡骞?*闁挎稒鐡猳nActionCancel 闁?dragBackEnd(0)`
        //   闁挎稑娼塤recover/logic-src/鐎殿喒鍋撻柛蹇氭珪閹搁亶寮ㄩ幆褎鐝?闁归潧顑呮繛宥囨崉椤栨氨绐為悗瑙勬皑椤?md` 閹?.3闁挎稒鍩冮幉?闂侇叏绲惧顖炲箥鐎ｎ亜鈼㈤柛銉︾◥闁叉粓宕堕悙鍓佹濮掔粯鍔曢崣蹇涙晬?
        //   cancel 閻犙勫濞堟垿寮?`pullEnd(0)`闁挎稒绋堥幊?閻?`dragBackEnd(0)`闁挎稑顦埀?
        //   闁宠法濯寸粭?`velocityY` 闊洤鎳橀妴蹇斿?**0**闁挎稒鑹捐ぐ鍥р槈閸粎鐟濋悹鍥ュ劥椤箒銇愰幘鏉戠亣"闊浂鍋嗛弫?闁兼澘鏈ぐ浣圭閵堝棙鏆悹褍鍤栫槐妾俧astFlick` 閻?闁?00闁挎稑顦埀?
        .onActionCancel((event: GestureEvent): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan cancel offsetY=${event.offsetY.toFixed(1)} ` +
            `dismissMorphActive=${this.dismissMorphActive} ` +
            `stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive}`);
          this.onDismissDrag(event.offsetY, true, 0);
        })
    )
    // 闁宠棄鎳夊Σ?2026-10-15闁?*闁逛勘鍊曞ú鏍ㄧ▔婵犱胶顏遍弶鐑嗗枤濞堟垶绋夐埀顒佸緞閸曨剚鏆柛?*闁挎稑鑻懟鐔煎箮婵犲倸鏂ч柛銉уТ閸熸挸銆?闁炽儲鏌￠埀?閻熸瑤妞掔粭鍛存晬?
    //
    // 濞戞挸锕ｇ粩瀛樻姜椤旇棄鐏夐柛锔哄姀缁绘牠鏌屽畝鍏娼?`.id(MORPH_HOST_ID)`闁挎稑鐬奸幃濠囨偨鏉堛劍笑"闁哄牜鍏涚划銊︾▔閵堝拋妲辨繛澶堝姂閸ｆ挳鏌堥崐鐕佸殯闁归潧顑嗗┃鈧〒姘€鍡欑濞?id
    // 閻忓繗椴稿Σ鎼佸箻椤撶喐鏉瑰銈勭祷閸ゆ粌顔忔潏鈺傜暠闁哄秶鎳撻鎰板闯椤帞绀夐柤鏉挎湰閹搁亶寮ㄦィ鍐︹偓澶嬬鎼淬垻姊鹃柟绋垮€界换鍐偓?闁?*闂侇叏绲奸柌婊堟偠閸℃瑦鏆犻柡鍕靛灦閺佸﹪鎯冮崟鍓佺鐎圭寮堕幐娆撳炊閻愵亖鍋?*
    //
    // 闁活亞鍠撳ù澶愭晬閸喐鎷遍弶鐑嗗枛閸欏繑绂掗幘瀵稿閻庣數娅㈢槐姘舵晬?
    // ```
    //   .id(MORPH_HOST_ID) 闁汇劌瀚划锔锯偓瑙勬皑閸嬶綁鏁?
    //     products/default/.../Index.ets:1796   闁?濠㈢懓鍟块惇?*闁?Stack**闁?*閻㈩垱鎮傞埞?*闁挎稑鐭侀～鍡欌偓鐟板暢閸ゆ粌顔忛柆宥呬簼婵炲牆鐏氶弫鐐烘煂婵犲繒绀?
    //     products/pc/.../Index.ets:345         闁?PC 濠㈢懓鍟块惇浼村冀?Stack闁挎稑鐗嗛悥鑸点仚娴兼瑧绀?
    // ```
    // 闁?闁归潧顑嗗┃鈧?*閻犱警鍨抽弫鍗炍熼垾宕囩**濞戞挸顑戠槐婵嬪箻椤撶喐鏉瑰銈呯仛濡插憡绔熼崘鑼勾闁?Stack 闂佹彃鐭傞崑鍛▔?`HdsNavigation` 闁?*閻庢稒鍔樻俊顓㈡倷?*
    //   闁?濞戞挶鍊撻柌婊堟嚍閸屾粌浠?*闁告艾鏈鍌炲捶閵娧呯煁濞寸姾鍩栭悥鍙夌▔?*闁靛棗鍊规晶宥嗙閵夘垳绐?
    //     鐠?**缂備焦绻€缁楀鎳?*闁革负鍔嶉幐閬嶅绩妤ｅ啨鈧娼诲▎搴ｎ伇閻忕偛鍊搁崯鈧柟绋垮€风粩鏉戔枎?闁炽儲鏌￠埀?闂侇叏绲惧Σ鎼佸Υ?*闁?id 濞戞挶鍊撻崬銈夋嚍閸屾粌浠?*闁靛棗绋勭槐?
    //       闁兼澘鏈﹢鐗堢閹炬剚鍤犻弶鈺傜懁濞嗐垺绂嶇€ｎ偅绠掗柡鍕捣閳ユ鎷嬮弶璺ㄧЭ闁挎稑娼塸roducts/default/.../Index.ets` 闁稿繐鍘栫花?`MINI_BAR_ID` 闁汇劌瀚悮杈ㄥ緞閸曨剚鏆堥梺鎻掝煭缁?
    //       "濞戞挶鍊撻崬銈夊触?id 闁汇劌瀚俊顓㈡倷閻у摜绀塦getRectangleById` 闂佹彃绻愰崺宀勫传椤忓啰顏卞ù鐘冲灊缁楀娑甸鑲╂毎闁挎稑鐭侀幑锝夋倷閻熺増鐨戦柟?闁挎稑顦埀?
    //       
    //     鐠?濞存粌瀛╁Σ?`PlayerExpandState.measureGeometry()` 闂佹彃鐭傞崑鍛▔?
    //       `measureNode(ui, MORPH_HOST_ID)` 闁?*闁归潧顑嗗┃鈧悹渚灣閺佸崬螣閳ュ磭纭€濞?*闂佹彃绻愰崺宀勬儍閸曨剚笑**濠㈢懓鍟块惇浼存焽閿濆嫮顏遍悘?*
    //       闁挎稑鐗愰埀顒€濂旂粭澶愬及椤栨稒灏￠柡鈧ィ鍐︹偓澶愭儍閸曨噮姊块柛鎿冧簽閻涖儵宕ｉ敐蹇曠闁炽儲鏌￠埀?閺夆晜鐟﹀Σ?*閻庨潧婀卞▓鎴﹀Υ娴ｉ鐦嶆慨婵撶稻濡插摜鈧懓鍟崗鍌滄啺娴ｇ儤鐣?*闁?
    //       閻庣懓鍟俊鍝ョ磼閹惧浜柛娆樹簻閸熸挻娼诲☉娆愶級闊洦顨愮槐妾俬ostNode=闁炽儺娉﹂柨娑橆檧缁辨繈鐛張鐢电懍闁革负鍔庨幓锝夋焽閼姐倖鐣辨繛澶堝姂閸ｆ挳鏌屽畝鈧崑锝夊触?
    //       "**缂備焦绻€缁楀鎳楅懞銉ョ憦閻庣懓鍟紞瀣煣閻戞ê濮柣鈺婂枟閻?*闁挎稑鐗撻崑鍛村及椤栨粠鍎戝ù婊勬⒐椤愬ジ鎳涢鍕彨闁?闁?
    //     鐠?濞戞挸锕ｇ粩瀛樻姜椤旇棄鐏夐悹鍥跺灟娴滄帗绋夐悜妯恍?婵犳洖绻戠€? 闁?缂備焦鎹侀鎴犳媼閵忊槅鍔€濞戞挾灏ㄧ槐?*閺夆晜鐟﹀Σ鎼佸礆缂佹ê澹堥柣銊ュ閳ь兛鐒﹂婊呮兜椤旂偓鐣?*闁?
    //
    // 闁宠法濯寸粭?闂侇叏绲肩悮杈ㄥ緞閸曨偄鏅搁柣顐熷亾"闁归潧顑嗗┃鈧〒姘€鍕啊闁衡偓妤ｅ啨鈧寮?Stack 閻忓繗椴稿Σ?`MORPH_HOST_ID`"闁汇劌瀚弫鐐烘煂?*闁哄嫷鍨堕弫濠囨儍?*闁?
    //    鐎瑰憡褰冨銊╁捶閹峰矈鍚傛慨婵撶秶缁辨瑧鎲?`PlayerExpandState.measureGeometry()` 濞?`contentWidthVp/HeightVp` 濞戞挶鍊曢ˇ鈺呮晬婢跺牃鍋?
  }

  /**
   * 鐟滆埇鍨硅ぐ澶愬嫉閻斿吋锛?缂備緡鍙冮ˉ锝囦焊娓氣偓濞?婵炴惌鍠栭惇浼存晬濮橆偆顏辩€殿喚濮鹃崝姘辩矉鐠囪尙顏撮悘鐐╁亾闁靛棔鐒︾€垫粎鈧懓銇樼€靛矂宕搁幇顓犲灱闁硅棄妫欓弬渚€鎯冮崟顐ゆ闂傚牜娼块埀?
   *
   * 闁宠法濯寸粭?**2026-10-15闁挎稒淇虹换鏍ㄧ▔閳ь剙螞閹烘垵鍤掔紓浣哥箲閹宕氶弶鍖＄处閻忕偛鍊圭拠鐐典沪?*闁挎稑娼塈ndex.ets` 闁?`MorphCoverClone()`闁挎稑顧€缁?
   *    闁哄牜鍓熼妴澶愬矗椤忓嫭韬?`hostsMorphOverlay()` 濞戞挸鎼禍锝夋儍閸曨偒鍟忓☉鎾茬串缁辨┊C 濠㈢懓鍟块惇浼存晬婢跺鐟愰弶鈺傤焾閻ㄧ喓鈧?闁炽儲鏌￠埀?
   *    閻犲鍟伴弫銈夋倷闁稓鐟愰柣銊ュ閺佺偤鏌屾繝鍌氭櫢婵炴挸鎳嶇花鈩冪▔鏉炴壆鐭嗗☉鏂跨墑閳ь剙鍊搁崵閬嶅极妫颁胶绉煎ǎ鍥ㄧ箘閺嗏偓闁挎稒鐡岰 闂侇叏绲惧顖滄崉椤栨瑧鐭濋柣鎺戠埣濞撳墎鎲版担鍝ユ殜闁?
   *    闁兼澘濂旂粭鏍礆閻樺啿绔撮悗鐟板暙濮樸劌顕ュΔ鈧幃鎾诲籍鐠哄搫鐏╅柟?PC 闁汇劌瀚惃婵嬫閵忕姷绉兼俊顐ｅ釜缁辨瑩鏌囬敐鍡樞﹂柛娆欑細缁斿瓨绂掗張鐢电殤闁挎稑顦埀?
   *
   * 闂傚牊鐟﹂娑㈠箑?*濞戞挸绉虫鍥偨閻旇埖宕插ù锝嗘礉婵☆參鎮?*闁挎稑娼塵orphBridging()` 濞?false闁挎稑顧€缁辨繈骞嶉埀顒佺閵夈儳鏆婂☉鎾崇Т瑜版煡鎳楅挊澶婎殯闁告繂绉瑰銈夊箑娴ｅ摜顏撮悘鐐╁亾闁?
   * `HitTestMode.None` 闁哄嫷鍨扮换鈧銈堝吹濞堟垿鏁嶅顓熸閻忕偛鍊块幗闈涱煥閳ュ磭娼屾鐐存穿缁辨繃顪€濡鍚囬柛娑欏灊閼垫垿鎯冮崟顔炬▓濞村吋纰嶆俊鎼佸箻椤撶喐鏉瑰銈呯仛婢у秹寮垫径灞戒化闁告垼顕ч幃鍡涘箳婢跺牃鍋?
   */
  @Builder
  MorphCoverBridge() {
    Stack() {
      Image(this.currentCoverSource())
        .width(this.expandState.morphCoverBridge().size)
        // 闁宠法濯寸粭?濡ゅ倹锚鐎?*闁告娲滅€氼參宕?*闁挎稑鐗呯粭澶愬礃瀹ュ懎鏅告慨婵堢帛閸?`size`闁挎稑顧€缁变即骞橀鐔告澒濡炪倝娼ч惃婵嬫閵忕媭妯嗛柡?`layoutWeight(1)` +
        //    `constraintSize(maxWidth/maxHeight)`闁挎稑鐭傞崳娲礆閹殿喗鐣遍柣顓涙櫅閼哥増绋夊鍕閻犲洣鐒﹀Σ绋款潰閿濆棙鐓欑憸閭︽娇閳?
        //    闁圭顦伴婊堝棘閻熸媽鍩岄柣銏ｎ嚙閸ゎ參寮堕妷褎鐣辩紓渚囧弮椤ワ絿浜告笟鈧浼存晬鐎?1 濞存嚎鍊栭ˉ妤冪磼濞嗘垶鍩傞悗鍦仜閻ㄦ繈妫冮姀銏＄暠闂侇叏绲肩粩鎾礆鐠囧弶鐨戝ù鍏间亢閻戯附绋夐埀顒佺▔?
        //    闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儑濞堟垿濡村畝鈧划銊╁级閻斿憡顦ч悘蹇庣窔濞肩増鎷呭鍥╂瀭/濠㈠爢鍐瘓閻犲搫鍘栫粩瀛樼▔鐎ｃ劉鍋撳蹇曠闁?
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
   * 婵繂鐭侀惁婵囥亜閻㈡悶鈧﹪鏌堥妸褎鐣遍柕鍡楄嫰閻ㄦ繈妫?+ 婵繂鑻幃?婵繂鏈晶婊堝Υ瀹ュ棜鐧侀悘鐐插亰缁辨瑧鈧絻顫夐悥锝夊籍閻樺灚娅?`PlayerPage.floatingCover` / `floatingMeta`闁挎稑顦埀?
   *
   * ## 閻庣懓鍟Σ鍛婄閳ь剚绋婇崼顒傜A2闁挎稒纰嶆禒顔藉緞瀹ュ啠鍋撶仦鍓ф憙閻犲洤绉归妴澶嬨亜閸洖鍔ラ柡鍫濐槸閻ㄦ繈妫?+ 婵繂鏈ú鎼佸触瀹ュ泦鐐哄Υ瀹ュ繒绀?
   *
   * 闁哄啰濮烽弲顐︽儍?`playerPane` 闁?`Stack { Swiper{ 閻忓繋绶氬鐗堛亜?; **缂?*婵繂鐭侀惁婵囥亜?} ; floatingCover ; floatingMeta }`
   * 闁炽儲鏌￠埀?閻忓繋绶氬鐗堢▔鎼淬垻鎽冮柛姘У鐎垫洟宕?`Swiper` **濞戞柨顑呴ˇ?*闁挎稑鑻崹蹇涘礆閻楀牏鎽冮悹鍥хЧ閵嗗寮?*闁告艾濂旂粩瀛樼▔椤忓嫬甯楃紒?*缂傚倵鏅涢惃顒勭嵁閸撲絿鈺呭礆娴兼番鈧﹪鏌堥…鎺斿耿
   * 婵繂鐭侀惁婵囥亜閻㈢浜濆☉鎾亾濡炪倕鐏氬﹢浼寸叕椤愩垹娑ч柡?`padding({ top: lyricPadTop() })`闁靛棗鍊界换鏍煂鐏炶姤鐨戦柡鍕靛灦閸嬪懏绋夐埀顒備沪閸屾ǚ鍋?
   *
   * ## 濞戞挸顦柌婊呯棯閿旇姤灏嗛柨娑樼墢瀹歌鲸绋夐埀顒勫级閳ヨ櫕鐨戝ù鍏艰壘閸ゎ參鎳撴担鍦▍闁汇儱鎷戠槐?
   *
   * 1. **闁告艾濂旂粩鎾籍鐠哄搫鐓濋柤宄板暱椤︽寧绋夐埀顒€顕ｉ悩鑼闂?*闁挎稒纰嶅﹢鏉棵归鑲╂勾闁圭鍊藉ù?闁?閻忓繋绶氬鐗堛亜閻㈢浜濆ù鐘垫櫕濠€锛勪焊娓氣偓濞兼壆鎮?`.opacity(0)` 闁芥ê绻楅幑锝夊级?
   *    闁?閻熸洖妫涘ú濠勪沪閸屾稒笑**闁哥儐鍨粩?*闁汇劌瀚惃婵嬫閵徛ゎ洬闁哄本鎹侀埀顒€鎷戠槐?*婵炲备鍓濆﹢?濞戞挶鍊涢埀顒€鎳嶇花鎵偘?閺夆晜鐟ュú鏍ㄧ鐎ｂ晝鍟?*闁挎稑娼塴yricFloatActive()` 鐎瑰憡褰冮崹褰掓晬婢跺牃鍋?
   *    闁挎稑鐗婄拠鐐典沪?`t = 0` 闁活潿鍔庡▓鎴犱焊鏉堛劍笑闁活亞鍠庨惃婵嬫閵忋垺鐣遍柦鈧悾灞戒化闁告垹濮崇紞宥夋晬瀹€鍐炬綄 `PlayerExpandState.lyricMorph`闁挎稑顧€缁?
   * 2. **闂傚牊鐟﹂娑㈠箑娴ｉ鐟濆ù婧犲懏鏅稿鑸电煯缂嶆垿鎳為崒婊冧化**闁挎稒鑹鹃惃婵嬫閵忋們鈧妫冨▎鎰靛壘闁?`lyricMorphT = 0` 闁?闁告瑦蓱瀹曞弶绋夐悜妯硅埅缂佹稑顦埀顑挎缂嶅懐绱旈鐓庣ギ閻㈩垰鍟惇顒佹媴?
   *    闁挎稑娼塴yricFloatActive()` 闂侇叏绲炬俊鎼佹⒒閵娿儱鍤掗柛鎺斿█濞?闁炽儲鏌￠埀?閻熸洖妫涘ú濠勪沪閸屾氨鍩楀閫涚串缁辨繄鎲?閹煎倻绮?2 闁秆勵殣缁辨岸濡?
   *    `if` 闁告帒妫欓弫顕€鎯勭€涙ê澶嶅☉鎾崇Т缂傛捇鎳為崒婊冧化 闁?闂傚牊鐟﹂娑㈠捶閵娿儳娈遍梻鍫涘灲閵嗗寮崜浣割暭闂傚牜婢€缁楀苯鈻介埄鍐╃畳閺夆晜鐟ラ〃婊勭▔濠婂棎鍋?*闂侇偅鍔曢崕姘辨閻樿京顏遍柤?*闁?
   * 3. **濞戞挸绉撮幃鍡欐喆閿旇姤鍤?*闁挎稒鐡狧itTestMode.None`闁挎稑鐗呯粭?`MorphCoverBridge` 闁告艾鏈娆撴晬婢跺棌鍋撻弬琛″亾?
   *    闁轰焦娼欓惇浼存煣閻戞ê濮悘鐐茬箰缁犵兘鏁嶅畝鍕笡閻犱降鍊曢幊鈩冪▔椤撶姵鐣遍悹鍥ㄧ箑缁变即骞庢繝鍐憙閻犲洤绉跺▓鎴濐煥濮橆剙袟濞戞挸娴烽崑锝夊礄鐠囨彃寮块柛姘暞鐢偓闁?
   *
   * ## 濞戞捁妗ㄧ划鍫熺▕閸喎鐦柛锔哄姀缁绘牗绋夐鍐Т缂傚喚鍣槐妾係tack`C 闁汇劌瀚〒鍫曞触鎼存繄顏卞☉鎿冧簻椤掋垻鈧稒鍔х槐姘舵嚀鐏炶偐鐟濋柡鍕靛灠閿涙挾浠?
   *
   * 鐠?**闁秆勫姈閻栵綁宕ｉ敐鍛獮**闁挎稒纰嶅﹢鎵沪閸屾矮绠☉鎾筹龚椤浜告潏銊π︾紒鎰殔瑜版盯宕㈤悢鍝勪化闁挎稑鐗呯粭?`MorphCoverBridge` 闁告艾鐬兼鍥Υ娴ｅ憡鍊遍柛娆欑到缁?闁炽儲鏌￠埀?
   *   閻庣懓鍟€垫粎绮ｅΔ鈧ぐ娑㈠锤閹邦厾鍨?`.position()` 闁解偓閹存帞绉撮柡?*鐎规瓕灏～锕傛儑閻斿憡绨氬Δ鐘茬焷閻﹀娼?*闁汇劌瀚哥槐姘舵晬鐏炴儳顣插ù?`lyricMorph()` 濞存嚎鍊曢崵顓㈡儍?
   *   缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨奸柛娆樺灟娴滄帡鎯勭€涙ê澶嶇憸?`.position()` 闁汇埄鐓夌槐?*闁稿繈鍔戦幗濂告⒖閼搁潧搴婄紒?*闁?
   * 鐠?**闊洤鎳橀妴蹇曟崉閻旂儤绲荤憸鑸灩瑜板绋夐埀顒傛導妞嬪海绱?*闁挎稒鑹鹃悾鐘诲捶閵娿劎绠瑰☉鎿冧海椤?`scale + translate + clip` 闁告瑦蓱瀹曞弶娼婚崶鈺傜暠閻庡湱鎳撳▍鎺楁煂瀹€瀣
   *   闁衡偓閹増宕抽柟缁㈠幗閺備焦銇勯崹顐ｎ槯婵炴惌鍠栭惇鎵崉閻旂儤绲荤紓鍌楁櫔缁遍亶骞愰崒姘厒闁?`Stack`闁挎稑鐗嗚ぐ澶愬箲椤厾顓哄鑸电壄缁辨氨浜搁崣妯肩獥"濡炪倗鏁诲鎵磽閳瑰簱鍋撴担鍝ユ闂傚牜婢€缁楀绱?闁?
   *
   * 闁宠法濯寸粭?婵繂鐭侀惁婵嬪箑鎼存繄鐤勯柣?*濞戞挴鍋撳☉鎿冧簻閻⊙冣柦閳ュ啿袟**闁挎稑娼塋yricsComponent` / `AmllLyricView` 濞戞挸绉堕～顐︽晬婢跺牃鍋?
   */
  @Builder
  private LyricFloatLayer() {
    // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣?`floatingCover`闁挎稑顧€缁?*閻㈩垱鎮傞埞?+ 闁告瑦蓱瀹曟彃顕?*闁?
    //
    //   闁?閻㈩垱鎮傞埞妤呮晬濮橆剛娈遍梻鍫涘灪濡?`playerPane` 闂佹彃濂旂粩瀛樼▔椤忓懍鑸柛锔哄妿濞堟垹鎲伴崱娆愮０閻忕偛鍋婄槐婵嬫?`scale/translate` 闁革负鍔嬬悮杈ㄧ▔椤忓棭浼傞柣鎰秺濡潡骞撻幒鎴斿亾绾绀?
    //      闁圭鍋撳ù鐘劦閵?0 濞戞挸绉撮崯鈧柣銏ｎ嚙閻ㄦ繈妫冮～顔剧闂侇叏缍侀崳宄邦啅閹绘帒鐏?`MusicPlayInfoBlock`闁挎稑顦埀顒佹煛閳?**闁稿繈鍔庨埢濂稿矗椤忓懏绠掑☉鎾亾濞寸姾妫勯惃婵嬫?*闁?
    //   闁?闁告瑦蓱瀹曟彃顕ｈ箛銉х獥閻㈩垰鍟惇顒勫春閸濆嫬娅欓悘蹇撴惈椤曨參宕?`playerCoverGeomRect()`闁?*缂佺虎鍨伴崵鎴炴媴閺囨ǚ鍋撴担椋庣憹闁哄被鍎存俊顓㈡倷?*闁挎稑顧€缁?
    //      闁告瑯浜濆﹢?`scale/translate` 濞村吋纰嶇亸鎾垛偓?闁?`t = 0` 闁?*濞达絽绉堕悿鍡涙偨閸楃偟顏撮悘鐐╁亾闁告劕鍟块悾?*闁?
    //      濞戞挸绉崇槐浼村礄閾忕懓绠?閻庣妫勭€硅櫕绗熷┑濠勵洬濞戞挸锕ユ慨銈夊Υ娴ｉ鐟愰柟韬插劙缁堕鎸ч弽褜鍟嶉幖?闁汇劌瀚鎾偝椤栥倗绀?026-10-15 闂侇叏绲鹃鑲╀焊娓氣偓濞兼澘鈽夐崼婵勪杭闁汇劌瀚┃鈧柛鎺曨啇缁辨岸濡?
    //   闁?**闁轰焦婢橀鐔哥▔婵犱胶鐟㈤柡鈧悷鏉款枀闂侇偅鍔曢崕姘辨閻樼數鎼煎ù鐘插殩缁辨瑦绂掔紒妯哄 `t`闁挎稑濂旂粭澶愬矗?`t=0`闁?* 闁炽儲鏌￠埀?闁规亽鍔岄閬嶆晬閸︽悜kUI 閻㈩垱鐡曢～澶屾嫚椤撴繄鐤呴柨?
    //      `.scale` 缂備焦娲濇俊顓㈡倷闁稖鍘煫鍥у暔閳ь兛姊?translate` 闁革负鍔嶅﹢顓犵磽閳哄倹鏉归柣銊ュ閸╂宕搁幇顓犲灱缂侇垰顭烽崳鐑藉礉閻欏懐绀嗛柨?
    //        scale   = morph.size / base.size
    //        translate = morph.xy 闁?base.xy
    //        婵炴挸寮堕悡瀣焊閸濆嫷鍤?= base.size 閼?scale = morph.size                      闁?
    //        婵炴挸寮堕悡瀣▔椤撶偟濡?= baseCenter + translate
    //                 = (base.xy + base.size/2) + morph.xy 闁?base.xy = morph.xy + morph.size/2
    //        闁?婵炴挸寮堕悡瀣啅閿旇法鐟愰悷?= morph.xy                                        闁?
    //        閻熸瑥妫滈～搴ㄥ捶閸℃凹娼?= (morph.radius / scale) 閼?scale = morph.radius          闁?
    //      闁?**閻忓繋绶氬浼村捶閵娿倖宕插ù锝嗘磻缁斿鏁濞堟垿鎷冮悾灞戒化闁靛棔绀侀妵鍥╀焊韫囧鍋撴担鍛婂閻熸瑦甯￠崗妯荤▔鎼粹€虫枾闁?`.width/.position(lyricFloatRect())` 閻庣懓鑻崣蹇涙儎缁嬫寧鍊?*
    //      闁挎稑娼塨ase` 闁告瑯浜濆Σ?闁告瑥鍊介埀顒€鍟伴柈?闁挎稑鑻悾鐘诲矗閺嶏妇鐭嗗☉鏂跨墕閳ь剙銈搁崗妯荤▔瀹ュ懎顨涢柛婵嗙Ф缁劑寮稿鎰**闁告瑯浜ｉ々锔锯偓鐟板暕缁楀绋?0**闁挎稒绋栫换鏍ь潰閿濆棙笑閻庣懓鍟换鈧銈堝吹閸戜粙宕欓悩杈╃Э闁汇劌瀚敮顐﹀炊閻欏懐绀嗛柕?
    //      闁宠法濯寸粭?濞戞挸锕ュ┃鈧悹鍥╁厴閵嗗酣骞嶇€ｎ兘鈧鎷嬮妶鍕伇婵炲棌妲勭槐鎵焊娓氣偓濞肩増銇勯悽绋夸簼鐎殿喚濮撮妵鍥╀焊娓氣偓濞肩増鎯旈弬鍓х憿闁衡偓閻熸澘顤?*濞戞挴鍋撴俊顖椻偓鑼伇闁?*闁挎稑鐗愮€氥垽宕ｅΟ鍦晩闁挎稑鐭侀鈺呭及?`.translate`
    //         濞?`.scale` 闁汇劌瀚ˇ鏌ュ触閸儯鈧孩鎯旇箛搴ｇ憿濞戞挸锕浼村磻閸ヮ亶鍟庡☉鎾崇Ф椤?闁炽儲鏌￠埀?闂侇叏绲惧Σ鎼佸船椤栨瑧顏遍梻鍥ｅ亾閻熸洑娴囬惃鐔煎极鐎靛憡鐣遍柛瀣穿椤旀洟鏁嶆径鍫氬亾?
    Stack({ alignContent: Alignment.TopStart }) {
      // 闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺?闁宠棄鎳夊Σ?闁哄牜鍓欓惇浼村箣閹邦喚褰岄柟纰樺亾濞撴碍绻嗙粋鍡涙儍?*濞戞挶鍊栧顖炲锤閹邦厾鍨肩紒顖濐嚙婢х娀骞?*闁?026-10-15 閻炴稏鍎撮鍥晬鐏炶棄袟闁归潧顑呮晶鐘虹疀閸涢偊鍤㈤柨娑橆槴閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛閹般劍娅滈柍鐑樺姀閺呮煡鍩￠幇銊︽珳闁崇儤鍔忛弲鏌ュ煛?
      //
      // 闁告挸绉佃ぐ?闁冲墎濯寸槐?*闁哄牜鍓欓惇鎵偖椤愶絽鐦柛?婵犲ň鈧磭娼岄柛鎰噹椤旀劙寮?濞?* 闁?闂侇叏绲奸柌婊呪偓鐟般仒鐎靛矂鎯冮崟顐㈡暥閻庣懓婀卞ú鍛啅閿旇法鐟愰悷?= 缂佹劖顨呰ぐ娑㈠储閻斿搫浠?
      //   闁挎稑娼塒laybackPage.ets:3227` 闂侇叏绲借ぐ?闁哄牜鍓欓惇浼存儍閸曨偂绠☉鎾筹龚椤浜告潏銊π︾紒鎰殔瑜版盯宕㈤悢鍝勪化"閻犲洤顕▓鎴犱焊鏉堛劍笑閻庣懓鍠涚槐?
      //    闁兼澘鑻悾?*闁告瑯浜滈顕€骞嶇€ｎ偅绨氶柡鈧娑樼亣缂?*闁挎稑顦崳?`lyricMorph()` 濞存嚎鍊曢崵顓㈡儍閸曨厾宕堕柛娆欑到濞兼寮介崶褍璁插ù?*闁烩晛鐡ㄧ敮?*闁告劖鐟ㄧ换?`.position()`闁?
      //   闁宠法濯寸粭?闁瑰箍鍨洪崹姘扁偓纭呮閻?闂傚牄鍨哄姗€鎯冮崟顐晱濞戞挷绱槐妾侴ridCol` 闁告劕鎳庨鎰版儎?/ 鐎归潻闄勯悥?`Column`闁挎稑顦?*濞戞挸绉撮崯鈧柟瀛樺姉閻?*闁?
      //      闊洤鎳橀妴蹇涘礂閸繂娅ら柟鍝勵槸椤旀牗绋夌拠韫濞戞挸锕ㄩ～妤呮晬閸у嚤layerExpandState.toHostPoint()` 閻忓繗椴稿Σ鍛婄▔閸濆嫮鏆婇柛鎴濇椤︻剟鎯冮崟鍓佺闁?
      //      闁告熬绠戦崹顖滀焊娓氣偓濞间即寮紙鐘电Ъ闁稿绻嬬粩瀛樼▔椤忓懐鍩夊ù?闁炽儲鏌￠埀?閻?`闁烩晩鍠楅悥锝夊煑?閻庣妫勯惈鍡涙閵忊剝绶茬紓浣哄枍缁?闁哄倽妫勬导鎰板炊閸欍儳鐟㈠Δ鐘叉湰閺?md` 閹? 闁?S3a闁?
      //
      // 闁告挸绉佃ぐ?闁冲灈妲勭槐?*闁哄牜鍓欓惇浼村触鐏炵偓顦ч悶姘煎亜椤ㄦ粓宕烽妸銉ㄥ煂闁告瑦锚椤旀劙宕抽…鎺旂scale + translate + clip闁?*闂?
      //   闁?`.position({x, y})` 闂佹彃鐬煎▓鎴犵玻濡も偓瑜版盯宕搁幇顓犲灱闁告瑯浜滃﹢?`p = 1`闁挎稑鐗嗛鎰板闯閵婏附笑闁诡厽甯為悺鎴﹀矗濡搴婇柨娑橆槹濡?*濞戞挶鍎查悧?*闁解偓閽樺韬紒鎰殔瑜版盯鎯?(x, y)闁?
      //      鐟滆埇鍨硅ぐ澶嬬▔椤撱劎绀刾 < 1闁挎稑顦悾鐘绘儍?*閻庡湱鍋ゅ?*缂佹劖顨呰ぐ娑欐媴瀹ュ洨鏋傚ù鍏间亢椤妇鈧湱鎳撳▍鎺楀矗濡搴婇柟鍓蹭海閾斿濡?
      //   闁?**闁规亽鍔岄閬嶆晬閸粎鐟濋柡鍕靛灟閸欏﹪鎯冮崟鍓佸耿闁告瑦蓱瀹曟煡宕㈤悢鍝勪化闁告瑦鐗曢鎰板闯閵娿倛鍘煫鍥у枦缁?缂備焦娲戦懙鎴ｇ疀閸愵亞绱氶柡鈧?闁?*闁?
      //        閻犱礁澧介悰銉╁矗閿濆懏缍忛柡?y闁挎稑鑻鎰板闯閵娾晝褰?`H`闁挎稑鐗冩晶?閻庣懓銇樼€靛本顨囧鍫㈢闁挎稑鐣璼 = initScale + (1闁愁厽濮昻itScale)鐠虹椂`闁靛棔姊梔 = initTranslateY鐠?1闁愁厽濮?`
      //        缂備焦娲戦懙鎴ｇ疀閸愵亞绱氶柡鈧幘鍛獥`y 闁?H/2 + (y 闁?H/2)鐠虹椀`闁挎稒绋戦崯鈧鐐茬－浜?`d` 闁?`y' = H/2 + (y 闁?H/2)s + d`
      //        濞寸媴绲介崣鍡涘嫉椤戣法娉㈤柣?`initTranslateY = barY 闁?scaledH鐠?1闁愁厽濮昻itScale)/2`闁挎稑娼塻caledH = barH/initScale`闁?
      //        妤犵偞婀归幎?`t = p`闁靛棔姊梜 = H/2 闁?scaledH/2`闁?
      //            y' = k鐠?1闁愁厽濮? + y鐠虹椀 = k(1闁愁厽濮? + y鐠虹椂   闁?  **`y' 闁?t 閼?y`**闁挎稑鐗嗗ú婊勭▔?`k` 濞?`y` 闁告艾鐭傞崳铏圭棯瑜嬮埀顑挎缁楁牠宕?t=1 闁哄啳鍩栨慨宄扳槈閸剛绀?
      //        鐠?`p = 1`闁挎稑鐗愰幆銈嗘媴瀹ュ繒绀嗛柨娑欑摢y' = y` 闁?**婵繐绲惧Σ鍝ユ媼閹规劦鍚€闁?*
      //        鐠?`p = 0.5`闁挎稒鍩冩晶?`y/2`   闁?**闁告瑯浜濆﹢浣烘媼閹规劦鍚€闁稿﹨鍋愬▓鎴炵▔閳ь剟宕?*
      //        鐠?`p = 0`闁挎稒鍩冩晶?`0`        闁?閻犳劖娼欏﹢顏嗏偓鍦嚀濞呮帗绋夋繝鍛彾
      //      闁挎稑鐗婃俊?`y = 250` 濞寸媴缍€缁绘﹢寮甸浣圭皻闂侇叏绲跨划宥団偓鍦仦缁佹挳宕欓悩杈╃Э `initScale 闁?0.082 / scaledH 闁?683 / H 闁?925`闁?
      //        t=1 闁?250 闁翠焦鎸堕埀顑胯緶=0.5 闁?124闁靛棔杈?0 闁?闁? 闁炽儲鏌￠埀?濞?`y' 闁?t鐠虹椊` 闁告俺顕ч幃搴ㄦ晬?
      //   闁?**閺夆晜鐟﹀Σ鍛婄▔閳ь剟寮?闁解偓閹存帞绉撮柡鍐煐椤掓粎娑甸琛″亾娴ｆ瓕鍩岄柛娆惷奸懙鎴﹀磻?闁汇劌瀚ぐ娑橆嚗?*闁挎稑娼塕zdCoverRect` 闁?`base/tx/ty` 闂佹彃绻掑▓鎴犱焊鏉堛劍笑閻庣懓鍠涚槐姘跺Υ?
      //   闁宠法濯寸粭?**2026-10-15 闁告帞绮崜鐗堢▔瀹ュ棙鏆?*闁挎稑鐬奸幃濠囨偨鏉堛劍笑闁衡偓鐟欏嫮銆婇梺顔挎閸戯紕鎮銈嗗焸闁哄牓缂氶惁澶嬪椤忓洨绠栭柨?
      //       鐠?闂侇偄妫楄ぐ澶愬箲閵忕姵绀€濡炪倝娼ч崬鎾锤閹邦厾鍨?闁炽儲鏌￠埀?闁活亞鍠愬┃鈧紓浣规尰閻?閻忓繋绶氬鎵崉閹存繂鐓傜€归潻缂氱粭鍌滄喆?闁挎稑鐗愰～?`morphBridging()` 闂佹彃鐭傞崑鍛枔绾板绐?
      //         `.scale()` 闁汇劌瀚悘鎴炴姜閺夋垹绉奸柡鍐╂构缁楀寮伴娑樼亯濞寸姰鍎扮拹鐔兼儍閸曨偒鍟囬柛锝冨妺閼垫垼绠涢崘璺ㄧ闁?
      //       鐠?闁轰焦娼欓惇浼村箹椤掆偓閸ゎ叀銇愰姀鐘茬秮閻庡湱鎳撳▍?闁炽儲鏌￠埀?濞村吋鑹捐ぐ澶愬箣?濡炪倗鏁诲浼村捶閵娧呯礆闁靛棔绀侀惃婵嬫椤厾鐟濈紓?闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛鏉戭儓缁诲啴鎯冮崟顕呮綆闁规壆鍣︾槐姘跺Υ?
      //   闁宠法濯寸粭?**闁告艾濂旂粩鎾冀閻熺増绀堥柣銊ュ瑜扮喐绋夐埀顒佺閼恒儱顏堕悹鎰箓閸戯紕绱掕箛鎾磋含濠㈢懓鍟块惇?*闁挎稒鐡狪ndex.ets` 闁?`MorphCoverClone()` 濞戞柨顑嗘晶宥嗙閵夘煈娼堕柟纰卞墮閸?
      //      闁圭虎鍘介弬浣广亜绾板绀夋繛澶堝姂閸ｆ挳宕樺▎鎴炵暠婵繐绲惧Σ鍛婃交濞嗗孩顐藉ù婊冾儜缁?闁活厸鏅涢懜浼村础鐎涙ɑ笑缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨?闁?闁告瑯浜濆﹢?p=1 闁归潧绉冲妤呭冀閸忕⒈鍔€缁?闁挎稑顦埀?
      //   闁?缂備焦鎹侀鎴︽晬?*闁归潧顑嗗┃鈧柡鈧娆戠闁归晲鑳堕獮鍥偐?*闁挎稑鐗忛弫銈夊箣瀹勭増韬柣顏嗗枑濠р偓濞戞挸锕悰娆愭交閸ヮ亶娼庨柟鎵枎瑜版煡骞掗妷銉ョ秬闁挎稑顧€缁?
      //      閻庣妫勯惈?闂傚牄鍨哄姗€鏌囬敐鍕伇閺夌儐鍠栭々褔寮稿鍡╂矗濠㈣泛绉堕弫銈夊嫉椤掆偓閻即鏁嶇仦鐣岀畱濡?*闁告艾鏈?*闁告劕鍟块悾鐐交濞嗗海鐟忛柡澶嗏偓鍐差枀闁圭粯鍔栭埀顒€绨肩粻鐐村緞閸曨厽鍊為柨?*濞戞挸绉烽蹇涘矗椤忓懏鍎斿☉鎾亾闁?*闁?
      //   濠㈣泛绉甸悧鎶藉川閹存帗濮㈤柨娑欑摢hdc shell hilog -x | Select-String 'RzdCoverRect'`
      //     闁?闁活亜顑呴懜浼村矗濡鍘?`measured`闁挎稑娼祅AreaChange 缂備焦鐟у▓鎴犳暜閸愩劎婀板ù锝呯▌缁辨碍绋?`base+tx` 闁汇劌瀚Ο濠囨晬?
      //        濞戞挸绨肩粭鍌炴閵忋倕浜濆☉鎾愁槼椤㈡垶锛愰崟顒傘偞闁挎稑娼?1 闁烩晛鎽滈悺?/ p=0.5 闁告垵绻愬畷?/ p=0 閻犳劗顥愰～妤呮晬婢跺鍤犵€电増銇炵粭鍌滀焊鏉堫偒鍤涢柡鍕唉缁绘牠寮堕垾鍐茬稉鐎垫澘瀚换鏇㈠捶閵娧勬櫢闁轰礁鐗勯埀?
      //
      // 婵犲ň鈧磭娼岄悘鐐叉噸閼垫垹鈧湱鎳撳▍鎺楁晬濮橆剛娈遍梻鍫涘灮濞?*閻㈩垰鍟惇顒佹媴瀹ュ洨鏋?*闁挎稑鐗嗚ぐ澶愬箲椤厾顓哄鑸电壄缁辨氨浜告潏銊π?闁糕晛鎼崳顖炴儗閳轰浇鍩?闁汇劌瀚惇铏▔椤撴繄绉?
      // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛弫銈夊箣瀹勬壆鏆伴悹瀣暔閳?*鐟滄媽顕х花鎶芥偂瑜庨幆澶愬触?*闁靛棗绋勭槐姘舵晬?
      //   闁硅泛锕ら惃婵嬫椤厾鐭ら柕?*闁糕晛鎼崳?+ scale/translate**闁靛棗绉甸弫濂稿箣閹邦厽锟ラ柣锝呯焸閸嬪懘寮芥搴㈢暠闁?*缂佺虎鍨伴崵鎴炴媴閺囩姵绾柟鎭掑劥閹倖鎷?*闁靛棗绉查埀?
      //
      // ## 濞戞捁妗ㄧ划鍫熺▕閸綆娲ｉ柛妯肩帛鐢偓闂侇叏绲肩粩瀵糕偓?`scale/translate`
      //
      // 闁告鍠愬鍨交濞嗗海顏遍悘鐐插€瑰Σ鎼佹晬?
      // ```
      //   Image().width(coverLayerBase().size)                     闁?闁糕晛鎼崳顖滀焊閸濆嫷鍤?
      //          .scale(閻庡湱鍋炵粊瀵镐焊閸濆嫷鍤?/ 闁糕晛鎼崳顖滀焊閸濆嫷鍤?                        闁?閻炴稏鍎遍崺?閻庡湱鍋炵粊瀵镐焊閸濆嫷鍤?
      //          .translate(閻庡湱鍋炵粊瀛樻媴?闁?闁糕晛鎼崳顖涙媴?                        闁?閻炴稏鍎遍崺?閻庡湱鍋炵粊瀛樻媴瀹ュ洨鏋?
      // ```
      // 濞存粌瀛╁Σ?*閻忓繋绶氬浼村嫉閳ь剛绱掗崼婊呯Т缂?= 閻庡湱鍋炵粊瀛樻媴瀹ュ洨鏋?*闁挎稑鐭侀埀?閻庡湱鍋炵粊瀛樻媴瀹ュ洨鏋?闁哄鍎撮崵?`onAreaChange` 濞戞挸锕ユ慨銈夋儍?
      // `lyricFloatRect()`闁挎稒鐩崑鍛▔椤忓嫧鍋撻悡搴㈣含闁哄牜鍏涚划?*濞戞挸绉磋ぐ鏌ュ箳瑜嬮埀顑挎缁″啴寮悩宕囥€婄紒鍌濆吹閸ゅ酣寮界粙娆惧殸**闁挎稑鐗忛弫銈夊箣瀹勬壆鏉芥繛?閻忓繋绶氬浼村磻韫囧海绉?闁?
      // 闁兼澘鏈崹婊堝箰婢跺﹦鏆婇柛瀣煯閹广垺鎷呴弴鐔哄ⅰ婵繐缍侀崗妯诲濮樻剚鍞ㄩ悷娆忓€归崝鍛村即閺夋垶鈻?闁炽儲鏌￠埀?閹?4/閹?5/閹?6 濞戞挸顦伴濂告焾閼恒儳澹旈柛锔哄姀缁绘牠寮堕敓鐘虫嚑濞戞挸顭槐姘跺Υ?
      //
      // 闁哄啰濮烽弲顐︽焽閿濆牏鐝?*闁哄秷顫夊﹢鏉库柦閳╁啯绠掗弶鈺傜懄濞碱垶鏌?*闁挎稒鐡猣loatingCover` 闁哄嫷鍨粩瀛樼▔?`Column(center)` 闂佹彃鐬煎▓鎴犱焊娓氣偓濞间即鏁?
      // 閻忓繐鎼?`morph.edge`闁靛棔妞掔紞鍛磾?`morph.tyAt(t)`闁靛棔绀佸〒鍓ф喆?`morph.radiusAt(t)`
      // 闁炽儲鏌￠埀?**闁稿繈鍔戦崕鎾及椤栨粎鏆柛鎴犲劋濞肩敻鎯?*闁挎稑濂旂粭澶愬蓟閵夈倖宕插ù锝嗘礉婵☆參鎮欓惂鍝ョ`PlayerPage閻庣懓鏈弳顤汭閻庤姘ㄩ…?md` 閹?闁挎稑顦埀?
      //
      // 闁?闁绘粍婢樺﹢顏堟偂瑜庨幆澶屸偓鐟板枦缁?*閻忓繐鎼?濞达絽绉堕悿?闁革箑妫滈～妤佺▔閳ь剙顕ョ€ｎ亜绲块柤?`lyricFloatRect()`闁? `lyricMorph(t)`闁?*闁?
      //   濞戞挸绉撮崯鈧☉?`scale`闁靛棔妞掔粭澶愬礃瀹ュ懎顫?`translate`闁靛棔绻杢 = 0`闁挎稑鐗嗛惃婵嬫閵忋們鈧妫冨▎鎰靛壘闁挎稑顦板?`lyricMorph(0)`
      //   閻忓繗椴稿Σ?`playerCoverGeomRect()` 闂侇叏绲肩粩瀛樼?*闁哄啰濮烽弲顐︽儍閸曨厾鏆€殿喖绻掔划銊╁几?* 闁?闁解偓閹存帞绉撮柣銏ｄ含閻ｈ顕ｈ箛搴ｎ伇婵炲棌鈧磭鏆版慨婵囩湽閳?
      Column() {
        Image(this.currentCoverSource())
          // 闁宠棄鎳夊Σ鍕煡?2026-10-16闁挎稑鐗忛弫銈夊箣瀹勬壆鏆伴悹瀣暔閳?*鐟滄媽顕х花鎶芥偂瑜庨幆澶愬触?*闁? 濞ｅ浂鍠曠悮閬嶅级閳ュ磭鏉芥繛鏉戭儜缁辨岸鏁?
          //   **閻忓繐鎼?濞达絽绉堕悿?闁革箑妫滈～妤佺▔閳ь剙顕ョ€ｎ亜绲?`lyricMorph(t)`闁? 闁哄啰濮烽弲?`CoverMorph` 闁汇劌瀚欢顓㈠礄閻氬绀嗛柨?
          //   濞戞挸绉存禒娑欑鐠佸磭绉块柛褎鍔栭悥锝囧寲缂佹ê搴婄紒?*闁挎稑娼塩overLocalRect()` 闁绘粍婢樺﹢顏嗕焊鏉堛劍笑 `lyricFloatRect()` 闁汇劌瀚ú鍧楁焻濮樺墽绀嗛柕?
          //
          //   闁宠法濯寸粭?闁瑰瓨鍨崇粭鍌涚▔閳ь剟鎮ч崼婵囪含閺夆晜鐟╅崳鐑藉礉閻樿櫣绠栧☉鎾亾婵?閻忕偛绻愮粻鐑藉锤閹邦厾鍨?闁?閻庡湱鎳撳▍鎺楀嫉椤掆偓濠€鎾锤閹邦厾鍨?闁?*闂侇偄妫楄ぐ澶愬箲?*
          //     闁挎稑鐗嗘禍锝囨媼?`.scale()` 缂備焦娲栭鎰板闯閵娿倛鍘煫鍥у枦缁辨岸鏁嶅畝鈧﹢锟犲嫉閾忓湱娉㈤柡瀣矋濡?*閻忓繋绶氬鐗堫槹閻愭彃姣夐悘鐐茬箰缁?*闁?
          //     闁哄牜鍏涚划銊р偓鐢殿攰缁绘牠寮堕垾鍏呮捣閻?*闁哄啠鏅滃﹢渚€宕ｅ鍫㈡**闁挎稑娼塵orphCoverRectAt()` 闁汇劌瀚弫鐐烘煂?+ 闁哄牜鍓欓惇鐗堛亜閸洖鍔?
          //     "闁宠法濯寸粭?2026-10-15 闁告帞绮崜鐗堢▔瀹ュ棙鏆?闂侇叏绲肩粩鏉戔枔绾板绐楅柕鍡楃焸閳ь剙妫楄ぐ澶愬箲?闁?闁活亞鍠愬┃鈧紓浣规尰閻忓浜告笟鈧鎵崉閹存繂鐓傜€归潻缂氱粭鍌滄喆閹虹偟绀?
          //     閻犲洤鐡ㄥΣ?`.scale()` 闁汇劌瀚悘鎴炴姜缂堢姷鐟濋柡鍕靛灡閸ㄦ粍绂掗妷銈堢闁汇劌瀚鎰板闯閵娿倛鍘煫鍥у暔閳ь剙绋勭槐姘跺焽?**鐎瑰憡褰冮悾顒勫极鐎涙ɑ瀵甸柛?*闁?
          //     濞戞捁妗ㄧ划鍫熺▕閸繄绉奸柡鍐ㄥ濞堟垹绱掗幘璇″晥闁?濞ｅ洦绻冪€垫棃鎮抽幍顔夹?闁挎稒鑹鹃悾鐘绘惞閻ｅ苯濮?闁解偓閹存帞绉撮柡鍐煐椤掓粎娑甸琛″亾娴ｆ瓕鍩岄柛娆惷奸懙鎴﹀磻?闁?
          //     濞达絽妫楅惃婵嬫閵忊剝笑**閻犺櫣鍠撳鍐偓鍦嚀濞呮帗绋夐埀顒傛導妞嬪海绱?*闁汇劌瀚哥槐娆戞喆閸屾稑濡虫慨婵撶悼閳ユ﹢鏁嶆径娑氱闁兼澘鐭傞埀顒€妫楄ぐ澶愬箲椤厾绐楅柣鈺佺摠鐢挳骞庢繝鍌滄殜闁烩懇鏅涢崵顓犱沪韫囨挾顔庨柕?
          //   闁圭儤甯楅悡锟犲礂閹惰姤鏆涢悗娑欘殣缁辩櫗hdc shell hilog -x | Select-String 'RzdCoverLocal'`
          .width(this.coverLocalRect().size)
          .height(this.coverLocalRect().height)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.coverLocalRect().radius)
          .clip(true)
          // `.position()` 闁?*闁烩晝顭堥顕€鎮ラ崜浣虹煁濞寸姾娉涢崬瀵糕偓鐟版贡濞?*闁汇劌瀚划椋庘偓鐢垫嚀閻ｇ偓鎷呭蹇曞耿闁哄牜鍓欓惇鎵偓鐟般仒鐎靛矂鎯冮崟顐㈡暥閻庣懓婀卞ú鍛啅閿旇法鐟愰悷?
          // = 缂佹劖顨呰ぐ娑㈠储閻斿搫浠柨娑樼墕婢х娀骞撻幇銊﹀枛闁挎稑鐭侀～鍡涘嫉椤掆偓閻増銇勯崼鏇炲姤闁挎稑顦崳?缂佹劖顨呰ぐ娑㈠锤閹邦厾鍨奸柛娆樺灟娴滄帡鎯勭€涙ê澶嶉柛鎰懀閳?
          .position({ x: this.coverLocalRect().x, y: this.coverLocalRect().y })
          // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗呴幈銊╂偨閵婏箑鐓曢悗鍦仦缁佹挳濡?*闁告柣鍔庨弫鐐▔椤撯懇鍋撻弬鍓х獥闁告垼娅ｉ獮鍥ㄧ▔閵堝嫰鍤嬮悘蹇庣窔濞?*闁靛棗绋勭槐姘舵晬?*閻忓繋绶氬鐗堟交濞嗗繒鐐婇煫鍥ф嚇閵嗗繘骞?
          //   `realCoverVisible()` 闂侇叏缍佹禍楣冩⒒?* 闁炽儲鏌￠埀?閻庣懓鍟╃粭灞剧珶閸愯尙婀撮柛蹇擃儔濞堟洜浠﹂崒婊勭暠 `morphOverlayBridging()` 闁?
          //   **濞戞挶鍎查悧鍛婄閹烘泙?*闁汇劌瀚粩瀵糕偓鐢垫缁辨瑩寮甸浣圭€ù?L2665 闂侇叏绲借ぐ鐐测枖閵娾晛娅為柛鎰懅濞堟垹浜告潏銊π﹂弶鈺傜懁濞嗐垺绂嶇€ｅ墎绀嗛柨?
          //     鐠?鐟滆埇鍨硅ぐ澶嬬▔椤撱劎绀刞morphContainerActive()`闁挎稒顑怤TERING/LEAVING/LANDING闁挎稑顦崳?闁哄牜鍓欑槐?*濞戞挸绉堕弫?*闁?
          //       閻忕偛绻嬬粭鍌炴焽閿濆懐鐐婇柣銏犲船閿涙挾浠﹂崒姘脯闂傚懎妫楅惇浼存晬閸у嚜orphCoverClone`闁挎稑顦崬顒傛偘椤帞骞?
          //     鐠?闁解偓閹存帞绉撮柛姘嚱缁辨獨tage = OPEN闁挎稑顦崳?闁哄牜鍓欑槐?*闁?*闁挎稑鑻崢鐘绘⒕閸℃婀撮柛姘湰濡炲倿寮ㄧ捄杞扮矗闁?
          //   闁宠法濯寸粭?闁瑰瓨鍨电敮顐﹀级?*婵犳洖绻嬬花鈩冩交濞嗘挷澹曢梻?* 闁?鐟滆埇鍨硅ぐ澶愬嫉閻斿吋锛?闁稿繐顑夊▓鏇犱沪閸岀偛浜濈€殿喚濞€椤ワ絿鎮板畝鈧▓鎴犱焊娓氣偓濞?濞?濡炪倗鏁诲鐗堟交濞嗗繒鐐婇柦鈧幋鎺旂Т闁汇劌瀚惃婵嬫?
          //      **闁告艾鏈鍌炲捶閵娧勬毎** 闁?闁活潿鍔嶉崺娑㈠箣椤忓嫭绂堥梺鎻掔灱濞堟垶绋夐埀顒€顕ｉ悩鎻掔９/濞戞挶鍊曠槐鍓佷焊娓氣偓濞间即濡?
          //   闁宠法濯寸粭?閺夆晜鐟﹀顖炲捶?`MusicPlayInfoBlock`闁挎稑鐗嗛鏃備沪?/ 闂傚牄鍨哄姗€鏌囬敐鍕拡闁衡偓椤栥倗绀?*濞戞挴鍋撻柣鈺傛尦閸忔﹢寮?*
          //      闁挎稑婀?57 / L510闁挎稒鐡?opacity(this.expandState.realCoverVisible() ? 1 : 0)`闁挎稑顦埀顒佹煛閳?
          //      闁告瑯浜濆﹢渚€骞嶇€ｎ偅绨氶弶鈺傜懁缁旀挳寮ㄩ婊勭暠婵炴惌鍠栭惇鏉款煶韫囧海鍟?闁?闁告瑥鐗呯粩瀛樼瑹鐎ｃ劉鍋?*闁告艾濂旂粩纾嬨亹閵忋垹笑 N 濠㈣泛瀚ㄩ埀顑跨瑜把囧绩闁稓鍟婂☉鎾亾濠?*闁靛棗绋勭槐娆戠箔?4 婵炲棌妲勭槐姘跺Υ?
          //   闁宠法濯寸粭?濞戞挸锕ユ慨銈夋煢閳轰胶鎽嶉柨娑樻綁.id` / `onAreaChange`闁?*濞戞挸绉磋ぐ?opacity 鐟滄澘宕幖?*闁挎稑鐬奸崣搴ｆ暜閹间礁娅ょ€电増顨呴崺?闁翠焦鎸堕埀?
          .opacity(this.expandState.realCoverVisible() ? 1 : 0)
          // 闁?濞戞挸锕ユ慨銈夋煢閳轰胶鎽嶉柟纰卞墮閸╁本娼诲▎鎾虫闁挎稑鐗婂Λ銈夋偩鐏炶偐鐦嶉柡鍕靛灥椤╊偊鎯勯弽褏婀撮柤濂変簻缁讳焦绋夋繝鍐ㄐ撻柨娑欑摢floatingCover.onAreaChange 闁?publishMorphTargets`闁?
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

        // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗忛崣搴ㄥ箹椤掍焦锟ラ柣锝呯焿缁辨岸鏁?*濞戞挴鍋撴俊顖ｄ海椤?*闁挎稑濂旂粭澶愬礃瀹ュ棙笑閻忕偛鎳嶉懙鎴犵博閺嶃劌绗撻柕?
        //   閻庝絻顫夐悥?`PlayerPage閻庣懓鏈弳顤汭閻庤姘ㄩ…?md` 閹?.1 `floatingMeta` + 閹?.2 `metaRow`闁?
        //     鐠?閻忓繐绻愰惃婵嬫閵忕姵韬?*鐎?*闁挎稑鐗嗗銊╁及椤栨瑧鐟愰梻鍫涘灲閸嬪懎顕?`Image`闁挎稑鐬奸弫?`lyricFloatRect()` 闁解偓閹存帞绉撮柛鎺斿閻℃洜鎷犲澶堚偓澶岀博椤栨粌浠柨娑橆檧缁?
        //     鐠?婵繂鑻幃?婵繂鏈晶婊堝捶閵娿儳鏆?*闁告瑥鐤囩粩鐔煎Υ娴ｉ晲绠悗闈涚秺缂?*闁挎稑娼塵etaRow` 闂佹彃鐭傞崑鍛▔閳ь剟宕氬Δ浣剐?`layoutWeight(1)` +
        //       `alignItems(HorizontalAlign.Start)`闁挎稑顧€缁?
        //     鐠?闁告瑥鍘栭弲鍫曟偩濞嗘垹鑸堕柡鈧幆鐗堫棏/闁哄洦娼欓ˇ鍧楁晬閸喐锟ラ柣锝呮湰濡?`SymbolGlyph 闁衡偓閹増顥慲 + `SymbolGlyph 闁哄洦娼欓ˇ绺涢柨娑橆槶閳?
        //   闁宠法濯寸粭?闁告鍠愬鍨交濞嗘挸娅￠柡?`textAlign(Center)` + 闁轰焦娼欏鈥愁潩閺夋垿鎸悘鐐叉噸閼?闁?閻忓繗椴稿Σ鎼佹偨閵婏箑鐓曢柟鎼簻濞存﹢鏌?
        //      "婵炴煡绠栭悡鍓佷沪閸涱剝鍘鍫嗗啰娈遍梻?/ 闁哄啰濮烽弲顐や焊韫囨挾娈遍梻鍫涘灲濞碱剙顔? 闁汇劌瀚伴崑鍛村级閳ヨ櫕鈻曠€殿喖鍊堕埀?
        //   闁宠法濯寸粭?閻忓繋绶氬鎵媼閳衡偓缂嶅懘鎮?`padding.left` 閻炴稏鍔忛幓顏堟晬? 閻忓繋绶氬浼村矗瀹曞洨鍠?+ 12闁挎稑顧€缁?
        //      濞戞挸瀛╁Λ銈夋偩瀹€鍕祮 `floatingCover`/`metaRow` 濞戞挶鍊曢惇鏉课熼鍕€婚梺鎸庣懁缂嶅懏娼忛幆褍鐓傞柣銊ュ缁劑寮稿鍛惣濞寸姵鐏氶埀顑跨閻垱绋夐埀顒備沪閸屾ǚ鍋?
        //
        // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲?`floatingMeta` 闁汇劌瀚悮杈╀沪閸屾俺鍩岄柣?* 闁炽儲鏌￠埀?濞达絽绉风换宥囩不濡ゅ啴鐛撻柛姘湰閻庮垶鏁?
        // ```
        //   濠㈣埖鐗曢惇?Column().width('100%').height(overlayBaseH())
        //                .justifyContent(FlexAlign.Center)        闁?闁告瑯浜ｇ粈瀣嫻?缂佹梹鐗滃ú璺ㄤ沪閸涱剝鍘?
        //                .hitTestBehavior(HitTestMode.Transparent)
        //     闁告劕鎳庨惇?Column().width('100%').alignItems(HorizontalAlign.Start)
        //                  .offset({ y: metaOffsetYAt(swiperProgress) })   闁?闁告瑯浜ｇ粈瀣嫻?闁烩晝顭堥顔句沪閸涱剝鍘柣銊ュ缂嶅懐绮?
        // ```
        // 闁挎稑娼墂ujie.pa:195907-196008`闁挎稑顦崳?闁瑰瓨鍨冲鎴︽偂瑜嶉幃鎾寸▔閳ь剝銇愰姀銏犘﹂柟钘夋４缁辩増寰勯弽褏婀寸紓?*闁糕晛鎼崳顖炴儎?*闁挎稑娼塭stBoxHVp()`闁?
        //   濞?`overlayBaseH()` 闁告艾濂旂粻鐔兼晬濮橆剙璁查柣顫姂閻?闁?闁硅矇鍐ㄧ厬闁告牜灏ㄧ槐姘舵晬鐏炶棄鏁堕悘鐐插€婚弫?`.offset()` 閻犙傚嵆閸嬪懘寮?lerp闁?
        // 闁宠法濯寸粭?闁告垹濮崇紞宥嗙▔婵犱胶鐟㈠☉鎾筹梗缁旀挳鎮ч崼銏＄暠 `.position({y: metaTopGeomY(...)})` **闂侇偅鍔曢崕姘辨閻樼數鎼煎ù?*
        //   闁挎稑娼塵etaOffsetY()` 闂佹彃鑻崙锛勭磼韫囨柨惟"閻忕偛鎳嶉懙鎴炴媴瀹ュ洨鏋?闁告垵绻戠敮鈧ù婊冩４缁辨岸鏁嶇仦鎯у簥闁汇劌瀚ぐ褔寮?*缂備焦鎸婚悗顖涚▔鎼粹€崇稉鐎?*闁?
        //   濞寸姴瀛╅婵囨媴瀹ュ泦鈺呭及?闁烩晝顭堥顕€宕洪崫鍕珯闁烩晜甯婇懙鎴ｇ疀閸愵亝鐣遍柛瀣箳浜?闁挎稑鑻幏浼村籍閻樺灚娅曢柛姘缁斿瓨绋夐鍫濇缂佹崘顕滅槐婵囩▔鐎ｂ晝顏辨慨婵勫劥閻ㄧ喖宕ｉ崒娆戠憹闁活潿鍔岄崯鈧弶鈺傛煥娴兼劙濡?
        Column() {
          Column() {
            Row() {
          Column() {
            Text(this.state.getCurrentSongItem()?.title ?? '', { controller: this.titleController })
              // 闁?缂佹棏鍨抽崑锝嗙▔婵犲啫袚闁挎稑鐗嗙敮?`MusicPlayInfoBlock` 闁汇劌瀚禍瀵告嫻閿濆繒绀嗛柍銉︽煛閳?閻?`publishMetaEndpoint`
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

          // 闁?闁哄啰濮烽弲?`metaRow` 闁告瑥鍘栭弲鍫曟焽閿濆嫯鈷堝☉鎿冧簻濞存﹢寮介崶椋庣`PlayerPage閻庣懓鏈弳顤汭閻庤姘ㄩ…?md` 閹?.2闁挎稑顧€缁?
          //   `SymbolGlyph 闁衡偓閹増顥慲 + `SymbolGlyph 闁哄洦娼欓ˇ绺涢柕?
          //   闁衡偓閹増顥戦柟?`MusicStoreService`闁挎稑鐗呯粭?`MusicPlayInfoBlock` 闁告艾濂旂粩瀛樼附濡ゅ嫷鍤㈤柛鎰懕缁辨岸鏁?
          //   闁哄洦娼欓ˇ鍧楀箥閹惧磭纾绘慨婵嗘湰濞叉悂鎳ｅ鍐ㄧ 闁炽儲鏌￠埀?闂侇叏绲奸柌?sheet 闁?`ControlAreaComponent` 闁活澀绱槐?
          //   闁绘鍩栭埀顑跨閸戯繝骞撻幇顒€纾抽柛鎺斿濠€鐗堛亜绾板绀刞playMenuOpen`闁挎稑顧€缁辨繄鎲存笟鈧崑鍛存煂瀹€鈧▓?`@Param`/`@Event` 閻犲洤鐡ㄥΣ鎴﹀Υ?
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
        // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗呴幈銊╁炊閻愯尙绉洪柨娑橆檧缁辨壆鎮板畝鍕蒋**闊洤鎳橀妴蹇涙偨閵娿劌娈伴棅顒夊亯閸ゆ粓鎮為崼鏇犲蒋閹?*闁挎稑鐗冩晶?4vp闁挎稑顧€缁?
        //   **濞戞挸绉烽崗?*闁?`this.lyricFloatRect().size` 闁炽儲鏌￠埀?闂侇叏绲奸柌婊堝磹閻撳孩韬?`t = 0`闁挎稑鐗嗛惃婵嬫閵忋們鈧鏁嶆径瀣槯闁?
        //   **濠㈠爢鍐闂傚牄鍨肩粩鐔兼⒐閸栵紕绀?28vp闁?*闁挎稑鐭傞崢銈嗙▔?`VerticalAlign.Center` 濞村吋纰嶆俊鍛婄▔閵堝牜鏀介柡鍌氭搐閻⊙囧箳閵娿儱鐓傞弶鈺傜懁缁斿鏁敂鐐暠濞戞搩鍙冨Λ?
        //   闁?**閻忓繋绶氬鐗堛亜閻㈠灚鐣辨慨婵嗚嫰閹洜鎮銏㈢獢濞戞挸顑嗙敮鍦棯?164vp**闁挎稑鐗愰幆銈夊礆閺夎法娼屾鐐存礀缁ㄦ娊鏌堥妸锝傚亾娴ｇ绔鹃柛锔哄妽鐢爼宕氱捄鍝勯殬濞戞挸顭槐姘跺Υ?
        .height(PlaybackPage.LYRIC_META_ROW_H_VP)
        .alignItems(VerticalAlign.Center)
        .padding({
          left: this.lyricMetaLeftInset(),
          right: PlaybackPage.LYRIC_META_SIDE_VP
        })
        // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁绘挆鍕剶闁哄啰濮烽弲顐︽儍閸曨亞绉寸紒澶庮嚙閸欐洖顕ｈ箛鏃€鎷卞ù?* 闁炽儲鏌￠埀?闁告帞濮电敮鈧柡鍫厸缁劑鎳涢鍕毎闁汇劌瀚伴崑鍛村础婵犲啯钂嬬€殿喖绻愰悺娆撴晬?
        //
        // 闁告鍠愬鍨交濞嗘挸娅￠柡鍕靛灲缁?
        // ```
        //   y: lyricMetaMorphY(t) + t 閼?(lyricFloatRect().size 闁?LYRIC_META_ROW_H_VP) / 2
        // ```
        // 濞戞挶鍊撻柌婊堟⒒椤曗偓椤ｄ粙鏁嶉崼銉ュ幋闁?閹?30/閹?31 闂佹彃鐬肩划鐗堢閸℃姣夊璺哄缁辨岸鏁?
        //   闁?`lyricMetaMorphY` 闁?`from` 缂佹棏鍨抽崑锝夋偨閵娧勭暠闁哄嫷鍨卞﹢鐗堢閹剧懓娈伴悗瑙勬皑濞?`LYRIC_META_GAP_VP = 10`
        //      闁挎稑鐗撻崑鍛▔椤忓嫮鍩楅梺鎻掔箳濞堟垵鈻旈妸鈺佹珵闁煎浜滅换渚€宕樺▎鎴炵祷闁靛棗鏈﹢鐗堛亜閸︻厽绐楀ù鍏兼緲閻ｉ箖宕愮涵椋庣闂傚牏鍋ら埀顒€妫楅幃婊堝磹缁楄　鍋撳蹇曠闁?
        //      闁兼澘鏈Λ銈夋偩?`fitPlayerOverlay` 闁?gap 闁?*缁绢収鍓涚槐顏堟儘?50** 闁炽儲鏌￠埀?
        //      閻庣懓鍟伴?6 濞戞搩浜滈悿鍕矗?`chrome().metaGap` **閻炴凹鍋傚☉顏勵嚕?*闁挎稑娼塺efitOverlay` 濞?6 濞戞搩浜楅埀?
        //      `fitPlayerOverlay` 闁告瑯浜濋弫?5 濞戞搩浜风槐姘跺焽?闂侇叏绲奸柌?10 闁哄嫷鍨辨俊?閻炴凹鍋傚☉顏勵嚕閸愵亝鐣遍柛娆忓€归弳?鐟滅増鎸婚崹姘閸℃瑦鍩傞柛濠勵儠閳?
        //   闁?`to` 缂佹棏鍨抽崑锝夋偨閵娧勭暠闁?閻忓繐绻愰惃婵嬫閵忋們鈧﹥娼?闁挎稑鑻惃顖炲箳?`metaTopFixLyric`闁?
        //      闁?`t 閼?(size 闁?rowH)/2` 闂侇叏绲奸柌?閻忕偛鎳嶉懙鎴犳偘閵夈儰缂?闁告瑥鐗婂Σ鎼佸嫉椤戣法娉㈤柤濂変簻閸ㄩ亶鎯冮崟顓у剳濞戞挸顦甸妴宥夊Υ?
        // 闁?闁绘粍婢樺﹢顏堟儎鐎涙ê澶嶉悹?*濞戞挴鍋撳☉?*闁哄牆顦崵顓熷緞閸曨厽鐣遍柛鎴ｅГ閺嗙喖鏁嶉崸鍒磂taTopGeomY`闁挎稑濂旂悮杈╃博椤栨粌浠梺顐ｅ姇閻⊙囧级閵夈劌娈?
        //   `CoverMorph.metaOffsetYAt` + `fitPlayerOverlay`闁挎稑顧€缁辨繈寮甸鍐炬斀濞戞挸绉撮崯鈧柡鍫濐槷閹广垺鎷呴弴鈥虫缂傚倹鐗犻妴宥夊Υ?
        //
        // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁挎稒鐭紞鍛矓?*濞?`.position()` 闁瑰壊浜滈崺灞惧緞閺嵮呮勾闂侇叏绲奸柌?`Column` 闁?`.offset()`**
        //   闁? 闁哄啰濮烽弲?`floatingMeta` 闁汇劌瀚懜浼存偐鐠佸湱绀夐悷娆庢缁楀倿妫冮姀鈥崇祷閺夆晜绋掑鐢告儍閸曨垰浜濆☉鎾卞€曢惇浼存晬婢跺牃鍋?
        //   `metaOffsetY()` = `metaTopGeomY(t, rowH) 闁?(闁糕晛鎼崳顖炴儎閹烘褰?闁?rowH)/2`
        //   闁?濞戞挸楠哥敮顐﹀级閵夆晛浜濋柡?`.position({ y: 闁?})` **闂侇偅鍔曢崕姘辨閻樼數鎼煎ù?*闁挎稑鑻ぐ褔骞戦姀鐘茬稉鐎垫澘瀚ㄩ埀?
        //   闁宠法濯寸粭?闁告鍠愬?`.position` 闂佹彃鐭傞崑鍛枔?缂佹劖顨呰ぐ?闁?濡炪倝娼ч崬鎾箲閵忋垻鏆柨娑樻綁metaTopLocalY`闁?闁汇劌瀚弳鈧悹渚囧幒缁盯鎮為懜鍨畳闁轰礁鐗炵槐?
        //     `metaTopGeomY` 闁汇劌瀚悮杈ㄧ▔椤忓棭浼傞柣?*闁哄牜鍓氬鐢典焊鏉堛劍笑闁解偓閽樺鏆伴柟顑跨閸ゆ垶鎷?*闁挎稑鐗嗛鎰板闯閵婏缚鑸紒娑橆槹濡炲倻绮诲Δ鈧崵顓㈠级閵壯勭暠闁稿﹦銆嬬槐?
        //     闁?**鐎规瓕灏欑划锟犲及椤栫偑鈧宕橀崨顓熺稄闁哄秴娴勭槐婵囩▔瀹ュ牜鍟呴柛鎰С缁?`1/morphScale`**闁挎稑鐗呯粻缁樼閸℃鐨戝ù?闁稿繐鐗撻ˉ锝夊礆閺夎法娈遍梻鍫娇閳ь兛绀侀崯鈧☉鎾愁儐濞?闁挎稑顦埀?

        // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗呴幈銊╂偨閵婏箑鐓曢悗鍦仦缁佹挳濡?*闁告柣鍔庨弫鐐▔椤撯懇鍋撻弬鍓х獥闁告垼娅ｉ獮鍥ㄧ▔閵堝嫰鍤嬫慨婵嗚嫰閹洖顫㈢仦鎯ь杹**闁挎稑鐗婂﹢浣圭▔閳ь剚绋夐鍛︽繛鍫濐儑閺嗏偓闁汇劌瀚ㄩ埀?
        //   濞寸姰鍎辨晶鐘裁烘ィ鍐従闁活潿鍔庡▓鎴濐潰鐏炶姤鍊虫慨婵嗘湰婢ф粍顦伴悙鎻掑汲闁挎稑顦埀顒€绋勭槐姘舵晬?
        //   **閺夆晜鐟ょ粩瀵告偘鐏炶棄鏂ч柡澶堝劜濡叉悂宕樺▎鎰靛姤闁?`.opacity(1)`**闁挎稑鐗婇弫鐐烘煂婵犲嫭鍊為柣銏ｉ哺濡?閻㈩垱鎮傞埞?闁?闁诡厽甯掕ぐ鑼喆娓氬﹦绐楅悘蹇庣窔濞肩増銇勯悽绋夸簼濞寸姾濮ら悺鏇㈠触?
        //   闁告鍠愬鐢告偨?`MusicPlayInfoBlock` 闁活澀绱槐婵堚偓鐟板暙閸戔剝绂掓惔銊ｂ偓?0 缂佸顭峰▍?闁挎稑顦埀顒佹煛閳?闂侇叏绲奸柌婊堟偠閸℃瑦鏆?*闁告瑯浜滈顕€妫冨▎鎰靛壘闁诡兛鐒﹂崹姘辩博?*闁?
        //   閻庣懓鍟俊鍛婄▔鎼粹€冲脯闂傚懎妫楅惇浼存儍?*濞存粍甯楅弸濂告⒒閵娿倗顏遍悹褔鏀辨刊鍫曞箳婢跺鍟?*闁挎稒鑹鹃懜浼村矗濡粯鍩傞梻鍌涙綑閿涙挾浠?`MorphMetaBridge`
        //   闁挎稑鐗嗗銊╁及椤栨粍鏆忛柟瀵告焿椤曗晠鎯?濞寸姰鍎辨晶鐘裁烘ィ鍐従闁活潿鍔庡▓鎴濐潰鐏炶姤鍊虫慨婵嗘湰婢ф粍顦伴悙鎻掑汲"闁挎稑顦﹢顏堟偨婵犳凹妫ч悶娑樺閼垫垿鎯冮崟顒傛憙闁告艾绋勭槐婵嬫嚀鐏炵偓鎷遍悶?*闁告艾鏈鍌炲矗閸繂寮垮ù?*
        //   闁?**濞戞挶鍊曢〃婊冾潰鐏炶姤鍊抽柛姘湰濡炲倿宕烽妸銉︾皻**闁?
        //   闁?闁瑰箍鍨洪崹姘跺籍閻樺灚娅曢梺顓ㄧ秮娴滈箖姊?`targetMetaOpacity()`闁挎稑娼塒layerExpandState` L1325-1335闁挎稑顧€缁?
        //     鐠?stage = OPEN 闁?**1**闁挎稑鐗愰幆銈嗘媴瀹ュ懏鍊甸柟顓熷笒瑜拌尙鎲存笟濠勭閻熸洖妫涘ú?閻忓繋绶氬鐗堛亜閻㈢浜濆ù鐘哄Г閻℃洟宕?闁汇劌瀚禍瀵告嫻?闁翠焦鎼槐姘舵晬?
        //     鐠?鐟滆埇鍨硅ぐ澶嬬▔椤撴繄鐟柛蹇擃儔濞堟洜浠﹂崒娑樺缂佺姭妲勭槐妾俶etaBridgeOwnsPaint()`闁挎稑顦崳?**0**闁挎稑鐗呭锕€螞閹烘梻鑸堕柛蹇擃儔濞堟洜浠﹂崒锔剧闁?
        //     鐠?鐟滆埇鍨硅ぐ澶嬬▔椤撴繄绋婚柛蹇擃儔濞堟洜浠﹂崒娑氭⒕闁规亽鍎抽?闁?闂侇偀鍋撻柛?`pullChromeOpacity()` 闂侇叏绲惧顖毲庨垾鍐插汲闁哄洩灏欓崵搴ㄥΥ?
        //   闁宠法濯寸粭?`MusicPlayInfoBlock`闁挎稑鐗嗛鏃備沪?/ 闂傚牄鍨哄姗€鏌囬敐鍕拡闁衡偓椤栥倗绀?*濞戞挴鍋撻柣鈺侇嚟閺併倝鎯冮崟顐ｇ殤闁哄嫷鍨伴悾?*闁挎稑婀?39 / L411 / L447闁?
        //      闁?闁告艾濂旂粭鍌涚▔閳ь剚寰勯崟顏嗩伇闁哄秴鍤栫槐婵嬪矗閸喐笑闁靛棗鑻幃鎾寸▔閳ь剝銇愰姀銏犘?N 濠㈣泛瀚ㄩ埀顑跨瑜把囧绩闁稓鍟婂☉鎾亾濠㈣泛瀚ㄩ埀顒€绉电槐锟犲箳婢跺本鐣遍梺顓ㄧ导缁斿瓨寰勯崟鈹惧亾?
        .opacity(this.expandState.targetMetaOpacity())
        // 闁宠棄鎳夊Σ鍕煡閸涱亝顫?2026-10-17闁?*闁告帞濮电敮鈧弶鈺傜懇閸ｇ兘鏌囬敐鍡樿拫闁煎浜炵槐顏堟儍?180vp 濞达絽绉朵簺** 闁炽儲鏌￠埀?goal 缂?1 闁哄绱曞▓鎴濐潰閿濆妗ㄩ悷鏇氱劍閻即鏁?
        //
        // 濞戞挸锕ｇ粩鎾偋閸絿绠归梺鎻掓湰濡?`.translate({ y: this.expandState.metaRiseVp() })`闁?
        // `metaRiseVp() = (1 闁?ramp01(p, 0.18, 0.62)) 閼?**RISE_VP(180)** / morphScale`
        // 闁炽儲鏌￠埀?闂侇叏绲奸柌?**180 闁哄嫷鍨卞﹢鐗堢閹剧懓娈伴悗瑙勮壘閳ь剛顑曢埀顑跨劍閻ュ懘寮垫径澶嬪床濞达絾娲栭崵顓熷緞?*闁挎稑娼塕ISE_VP` 闁汇劌瀚弫鐐烘煂婵犲懎娈扮€圭宕崯鎾绘儓閳?閻忕偛绻愮粻鐑芥煂?闁挎稑顦埀?
        //
        // 闁哄啰濮烽弲顐ｆ交濞嗗海顏遍悶娑樼灱濞堟垶鎷呭鍥?*闁告瑯浜濆﹢浣圭▔閳ь剟寮?*闁挎稑鑻銊╁及椤栨瑧鐟愰梻鍫涘灲閸嬪懘寮?`.position()` 闂佹彃鐬煎▓?
        // ```
        //   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
        // ```
        // 闁挎稑娼塁overMorph.ets:205-211`闁挎稑顦埀顒佹煛閳?**lerp 闁哄牜鍓濋棅鈺冧焊鏉堛劍笑闂侇叏绲惧?濡炲鍋樼粭鍌炲级?**闁?
        // t=0 闁?濠㈠爢鍐闂傚牄鍨圭花铏綇?+ 50"闁挎稑顔?1 闁?閻忓繐绻愰惃婵嬫閵忋垻褰ㄩ柣鈺冪節閼垫垼绠?闁挎稑娼塼opYAtLyric + 28`闁?
        // 閻?`META_TOP_FIX_LYRIC_VP`闁挎稑顧€缁?*闁稿繈鍔忛、鎴犵矙鐎ｎ剚鏆?t 濡炵懓宕慨?*闁挎稑濂旂粭澶愭閳ь剛鎲版担绋挎櫃闁告瑧濮崇粩鎾级閿涘嫮宕堕柛鎰噸缂嶅懐绮斿Ч鍥ｅ亾?
        //
        // 闁?闁告帞濮电敮鈧悗鐟板暕缁狅綁宕ユ惔顖滅獥
        //   鐠?闁哄倸娲ら悺褎绋夋惔婵娾拡濞戞搩浜滃ù姗€寮?*闁告艾鑻ˇ鈺傛交濞嗗海顏遍悶?* 闁?濞撴碍绻勯崝?濞戞挴鍋撻悹褏鍏橀ˉ锝嗙▔婵犲啯闄?闁挎稑鐗呯紞鍛磾?lerp 闁告艾鏈花顕€鏁嶆径娑氬耿
        //   鐠?婵烇絺鈧啿寮冲ù鐘茬У鐎?`targetMetaOpacity()`闁挎稑鐗嗛崬鎾触?`pullChromeOpacity` 闁?0.18闁?.62 缂佹劖顨呰ぐ娑㈡晬?
        //     闂侇叏绲惧Σ鎼佹偨閵婏箑鐓曠€规瓕灏欓垾妯兼媼閵堝洦鐣?闁抽婢佺槐姘舵晬?
        //   鐠?濞戞挸瀛╁Λ銈夋偩?*闁告瑯浜滃Ο?閺夆晜绋戠€瑰啿鈹?**闁挎稒纰嶉崹婊勭椤掑倹鏆?`lyricMorphT`闁挎稑鏈Λ銈夋偩瀹€鈧弫?`swiperProgress` 闁炽儲鏌￠埀?
        //     閺夆晜鐟﹂婊堝及椤栨氨鐛﹂柡宥呮川椤戝洭宕楅鈽嗘斀 `metaD`闁挎稑鐗愰鐟邦潰閿濆懏鍊甸柨娑橆槼椤╋箓鏌岃箛鏇熺暠濞戞挻绮忛妶鍧楀Υ?
        //
        // 闁宠法濯寸粭?`earlyRiseVp()` / `contentRiseVp()`闁挎稑鐗嗛惃顒€顫㈠畝鍐Г缂?/ 闁硅矇鍐ㄧ厬闁告牞娅ｇ划宥夋晬?*闁哄牜鍓氶鍏肩▔瀹ュ懎袟**闁?
        //   goal 缂?1 闁哄鈧啿娑ч柣鎰扳偓娑氬晩闁稿繐鍟╂穱濠囧箒椤栨繍鏀介柨娑欑洴閸嬪懏绋夐妶鍥╃煁闁?闁硅矇鍐ㄧ厬闁告牞妗ㄧ划鐘崇▔鐎ｎ亜纾冲☉鎾筹攻濞?闁挎稑鐬奸弫銈夊箣瀹勬澘鍤掔痪顓у枦椤撳鎯?
        //   闁?閻犲洤顕▓鎴犱焊鏉堛劍笑閻庣懓鍟╁鎴︽焽閿濆拋娈伴柡鍐ㄧ埣濡法绮ｅΔ瀣`pullChromeOpacity` 0.18闁?.62 / `pullBottomIn` 0.45闁?.00闁挎稑顦埀?
        //   閻庣懓鍟╁鎴﹀触鐏炲墽澹夐柛娆戝С缁ㄢ剝绋夐埀顒勫级?180vp 闁炽儲鏌￠埀?閻熸洑妞掔粭澶屾啺娴ｉ顏遍悹褍鍢查獮鎾诲箳婢舵稓绀夌紒娑橆槼缁绘牕鈻庨檱椤洭骞囬悢宄板唨濡絽鐗嗛崯鈧悗瑙勭啲缁辨瑧鎲?閹?30闁挎稑顦埀?
          }
          .width(StyleConstants.FULL_WIDTH)
          .alignItems(HorizontalAlign.Start)
          .offset({ y: this.metaOffsetY() })
          // 閳藉應妲勯埥鍛 2026-10-17閿?*閹垹顦?娴犲簼绗呴棃銏犲磳娑撳﹥娼?** 閳ユ柡鈧?閻劍鍩涚€圭偞绁?
          //   閵? 閺€鍦畱娑撳秴顕敍灞绢劀鐢憡鐡曢幍瀣安鐠囥儰绮犳稉瀣桨閸戠儤娼甸妴鍌欑稑閻婀呴弮鐘垫櫕閵嗗稄绱?
          //   閹存垳绗傛稉鈧悧鍫濆涧閸嬫矮绨?閸掝偄甯囨潻娑欏付閸掕泛灏?閻ㄥ嫰鎸搁崚璁圭礉閸楀瓨濡告潻娆庣鐞涘瞼娈?*閸楀洤鍙嗘担宥囆?*娑撱垺甯€娴?
          //   閳?鐎瑰啩绮犵粭顑跨鐢冩皑闁藉婀拃鐣屽仯閵嗕礁褰ч弰顖涜窗閸?閳?鐟欏倹鍔呮稉搴㈡￥閻ｅ苯鐣崗銊ょ瑝閸氬被鈧?
          //   閺冪姷鏅柇锝勭鐞涘本妲?*鐠虹喓娼冮崘鍛啇娑撯偓鐠ц渹绮犳稉瀣窔娑撳﹪顥?*閻ㄥ嫸绱欓弮鍫曟？缁?`WIN_META 0.18閳?.62`閿?
          //   娑?`pullChromeOpacity` 閸氬奔绔存稉顏勫隘闂傝揪绱濇稉銈堚偓鍛倱鐠у嘲鎮撻拃鏂ょ礆閵?
          //   閳?閻劌娲栧Ο鈥崇€烽柌宀€骞囬幋鎰畱 `metaRiseVp()`閿涘潉(1 閳?ramp01(p,0.18,0.62)) 鑴?RISE_VP / scale`閿?
          //     闂堟瑦顒涢幀浣逛航 0閿涘鈧倸鐣犳稉搴濈瑐闂堛垻娈戦柦鍐插煑閺勵垯琚辨禒鏈电皑閿?*閸楀洤鍙?*閺勵垱妞傞梻缈犵瑐閻ㄥ嫸绱?
          //     **闁藉啿鍩?*閸欘亜鍠呯€规俺鎯ら悙鐧哥礉娑撳秷顔忛幎濠呮儰閻愮懓甯囨潻娑欏付閸掕泛灏妴?
          .translate({ y: this.expandState.metaRiseVp() })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(this.expandState.estBoxHVp())
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 闁宠棄鎳夊Σ?2026-10-15闁挎稑鐗呴幈銊╂晬婢舵稓绐楅弶鈺傜懇閸ｇ兘宕㈤悢鍛婇檷闁?`HitTestMode.None` 闁炽儲鏌￠埀?闂侇叏绲惧Σ?**闁煎浜滅换渚€宕仦鐣屾憤闁煎搫鍊婚崑锝夋焾閹存帞鐟濋柛婵嗙Т缁ㄨ尙鎲撮敂鑺ュ殝**"闁?
      //   濞村吋纰嶆俊鎼佹焽閿濆嫮顏遍悶娑樿嫰瑜板憡绗熻濞?*闊洤鍟懜?/ 闁哄洦娼欓ˇ鎸庣▔閵堝嫰鍤嬮柟绋款樀閹告娊鎯冮崟顓炰化闁告垼顔婄粩瀵告導瀹勭増鍊栭柟?*闁挎稑鐗嗗銊╁及椤栨稒鎷遍柛褎顨呴崹浼村礉閻樺灚鐣遍梺顓ㄧ导鐞氳鲸绋夐搴ｇ闁?
      //   闁哄啰濮烽弲顐ｅ緞閺嵮呮勾闁活潿鍔庡▓鎴﹀及?`HitTestMode.Transparent`闁挎稑娼塮loatingCover` / `floatingMeta` 闁?
      //   婵犲ň鈧磭娼岄悗鍦嚀濞呮帡鏌堥懞銉π﹂悗鐟板枦缁辨岸鏁?*缂佸矁娅ｅ▍褎寰勯崟顓涙晬闂侇偄绻愰崺灞剧▔鐎ｎ亞婀撮柕鍡曠閻℃瑩鎳為崒婊冧化闁绘挆鍐煑闁告瑯鍨抽崑?* 闁?閺夆晜鐟╅崳鐑藉绩鐟欏嫬鐏囬柛姘缁斿瓨绋夐鍌楀亾?
      //   闁宠法濯寸粭?閻忓繋绶氬浼存焽閿濆懐鐐婇柛銉﹀礃閸ゆ粌顔忛崣妯肩煗闁绘帟鍩栧Σ?`None`闁挎稑鐗呯粭鍌涚▔閳ь剛浠﹂崒婊勭暠 `Column`闁挎稑顧€缁辨繈骞嶉埀顒佺閵夈儳鏆婂☉鎾崇С缁变即骞愰垾鑼Ф婵犲﹥鍨垫慨鈺呭Υ?
      .hitTestBehavior(HitTestMode.Transparent)
    }
}

/*
 * 闁宠法濯寸粭?闁圭虎鍘介弬浣广亜閻愬厜鍋撶仦鑲╊伇闂傗偓濠婂啫鐓傞幖瀛樻磸閳ь剙绉撮惈宥咁嚕閳ь剟宕濋妸褎鏆伴柣銊ュ瀹稿宕ｇ拠褏绀?026-09-22 / 09-25闁挎稑顦埀顒佹煛閳ь剚鏌ㄩ崯鈧柛鏂诲妽婢ф粓宕滃鍛弗閻犲洩顕ч悾顒勫Υ?
 *
 * 缂佹鍏涚粩鎾偋閸剛绀勭€瑰憡褰冪花鎯ь嚕閸愯法绀嗛柣?path 閻熶椒绀佹竟鈧柟璺猴攻閺嗭絾銇勬担鍐炬⒖闁瑰瓨鍔樼化鐘虫媴閻樿櫕钂嬮梺顓ㄧ导缁犵偞寰勮濞堟垹浜歌箛鏇犲炊闁告瑱绲介崯鈧梺顐ｅ姇閹舵岸姊归崹顔轰海闁挎稑濂旂悮杈ㄧ▔?API 闂侇喛妫勫鏍晬?
 *   1. `clipShape(new PathShape({ commands }))` 闁炽儲鏌￠埀?闁圭虎鍘介弬浣广亜閸偅娈诲☉鎿冧簷缁楀寮伴崜褋浠涢柨娑樼墣閵嗗啴鎮虫０浣界闁瑰灚鎸风粭澶婎嚕閳ь剟鏁嶆径娑氬耿
 *   2. `clip(new Path({ commands }))` 闁炽儲鏌￠埀?闁绘劗鎳撻崵顕€骞橀鐔告澒闁革絻鍔庡ú鍧楀箳閵夈儱骞㈡慨婵囩湽閳?
 *
 * 闁绘粍婢樺﹢顏呮交濞嗘垵顣奸柨娑樼墕椤曨噣寮介崶銊︼骏闁伙絽鐭傞悡鑸电▕?`ExpandAnimation` + `CoverMorph`闁?*闁告瑯鍨抽弫?*闁挎稑顧€缁?
 *   1. **闁轰焦鎸抽妴澶岀磽閳哄倹鏉?+ 缂佹梹鐗滃ú璺ㄦ啑娴ｇ顥呯紒鎰殔瑜?*闁挎稒鐡猦eight / scale / translate / clipShape / opacity`
 *      濞存粍鏌ч柌婊呬沪閻愮补鍋撹缁辨繆銇愰姀銏犘﹂柛娆樹簽閺?*闁革箑妫滈～妤呮儗閳轰浇鍩?*闁挎稑娼塕ectShape`闁挎稑濂旂粭澶愬及?path闁挎稑顦埀顒佹煛閳?
 *      閻?`PlayerExpandState.applyMorphProgress`闁?
 *   2. **婵℃ぜ鍎茬敮瀵镐焊娓氣偓濞?*闁挎稒鑹鹃懜浼村矗濡粯锛嶉柡鍫㈠枎瀹曠喖鎮鍌涙毎濞戞挴鍋撶€殿喚濮撮惃婵嬫椤喚绀夊ù鐘叉唉缁姵鎷呴悩铏拫閻忓繋绶氬鎵磼椤撶偛鐓傞柟缁㈠幗閺備焦銇勯棃娑氭闂?
 *      闁挎稑鐗愰～?`MorphCoverBridge` / `PlayerExpandState.morphCoverBridge`闁挎稑顦埀?
 *
 * 閻庣懓鍟板▓鎴﹀炊濞戞鍤嬮煫鍥ф嚀椤╋箓寮堕垾鍙夘偨闁挎稑鐗忓杈ㄧ▔閳ь剚绋夐鍕殤濞村吋宀搁埀顑藉亾闁告牗鐗楅崹?濮掓稒鍨电花?+ 濞戞挸顑嗛弻鐔虹矚閾忚顏?+ 濞戞挴鍋撻柛褎顨夌换搴☆潰閿濆棙鐓欑憸?闁挎稑顧€缁?
 *   1. **闁圭虎鍘介弬浣广亜閸忓摜鐟㈠Λ锝嗙墵閵嗗绠涢崨娣偓蹇涘捶閵娿儲鍊卞☉鎾亾婵☆偂绲婚～瀣炊閻愵剛鍩愰梺?*闁挎稒鑹鹃懜浼村矗濡粯锛嶉柡鍫㈠枎瑜拌尙鎲撮崱娆戝彁鐟滆埇鍨硅ぐ褔寮垫径搴ｇ濞达絿濮靛顖滀焊娓氣偓濞间即鏌囬敐鍕杽濠㈠爢宥囩
 *      闁稿繑婀圭紞鎴︽焾閵娿儱鐎婚柡鍕靛灦閳ь剙绻戝Σ鎴︽儍閸曞墎绀夐悷鏇氱窔閳ь剙绻愰崵顓熺▔鐎ｎ喗妗ㄩ柣銊ュ椤╃粯銇勯崗鍝ョ憿閺夆晞娓圭紞姗€寮?闁炽儲鏌￠埀?闁?`bindContentCover` 婵☆垪鍓濋埀顑挎缁楀鎮板畝瀣
 *      婵☆垪鍓濋埀顑跨椤旀牗绋夌紒妯恍﹀☉鎾崇Ч閳ь剙绻戝Σ鎴︽儍閸曨亞顏遍悘鐐插亰缁辨繈骞庢繝鍥舵禃濡炪倝娼ч幏鐗堟交閾氬倻绋戦柡澶嗏偓鍐插伎闁烩晜鐗旂紞鍥ㄧ閸℃劏鍋?
 *   2. **"闂佸墽鍎ゅ?闁汇劌瀚ú浼村冀閸ヮ剛褰幖杈剧畱缁烩偓濡炪倗绮Σ鎼佸箒閹哄秷绀嬫繝濞锯偓宕囨綄闁汇劌瀚鏍ㄧ▔鐠囧樊鍟囬柛锝冨妼閻ゅ嫬霉鐎ｎ亜姣夐柡澶堝劤濞?*闁挎稒纰嶇€垫洟宕烽妸顭戞蕉鐟滆埇鍨硅ぐ澶愭儍閸曨垰浜濋悘鐐插€风粭鍌涘濮樺啿娈伴柛?
 *      闁挎稑鐗撻崑鍛沪閸岀偟褰幖杈剧畱濮樸劑寮伴婵愭⒖闁告搩浜為悰銉╁矗閿濆繒绀嗛柨娑樼焷椤?`PlayerExpandState.reportHost`闁?
 *   3. **闁告瑯鍨甸～瀣儗閳轰浇鍩岄柣銊ュ濞叉捇寮堕檱缁旂喖宕ラ崟顔兼闁圭粯甯掗埀?*闁挎稑濂旂粭?*濞戞挸顑堢粩鐔烘啺娴ｇ懓绲归柛鎾崇Х閸掓稒鎯?*闁挎稑鐗愮化鐘虫媴閻樿櫕钂嬬紒鍌濐嚙閻棝鐛弴鐐典亢閺夊牏顢婄换鏇㈠嫉婢跺﹤娈ら柛?vp闁?
 *      閻犺櫣鍠撳鍐棯閹稿簶鍋撹閾斿鎯冮崟顔炬▓闁轰礁鐡ㄩ宀勫礉閵娧勬毎閹煎瓨娲熼崕鎾焾閼恒儲笑缂佸矁娅ｅ▓鎴︽晬婢舵稓骞㈠ù锝呯Ф浜? 闁告瑯鍨甸～瀣啅閿旇法鐟愰悷?闁?(閻㈩垰鍟惇顒勫焾閹烘垵璁查悷?/2闁?
 *      濞戞挸绉烽崗姗€鎮¤婵￠亶寮悩鍨珪闁?闁告帗绻傞～鎰媴瀹ュ泦?閼?(1-p)"闁挎稑鐗忕紓澶愬绩閸欍儴鍘煫鍥у暞濡插摜鈧湱鎳撳▍鎺撶▔椤撶偟濡囬柨娑樿嫰閻栧爼鏌岃箛姣稿宕戞径姝屽幀婵炲牆鍚€缁辩増銇勭捄鍝勬瘔閻忕偛绻愮粻鐑芥晬婢跺牃鍋?
 *   4. **闁革箑妫滈～妤勭疀閸涙番鈧繘鎮?`clipShape` 閻?*闁挎稒鑹捐ぐ褔宕?`.borderRadius + .clip(true)` 闁哄啳顔愮槐?
 *      閻庡湱鎳撳▍鎺楁嚊椤忓洭鐓╂繛灞稿墲濠€渚€鎳楃仦鐐彲闁?闁?闁革箑妫滈～妤佺▔瀹ュ嫮绋婇柣顫妼閸╁瞼鈧稒鍔樻俊顓㈡倷?闁?闁告劕鎳庨鎰沪閸屾瑧顏辨繛鎼枛閸ゎ參寮堕妷銉︾殤闁告瑦蓱閺岀喖宕稿灏栧亾?
 *
 * 鐎规瓕灏欑划鈩冪┍濠靛牊娈岄柣銊ュ缁椼垻鎲查崠锛勭闂侇喛妫勫﹢?common/musicbasic闁挎稑顧€缁?
 *   - `PlayerExpandState`闁挎稑鐗呯悮杈╃博椤栨氨娈遍梻鍫涘灮濞堟垹绮ｅΔ鈧ぐ娑㈡儗閳轰浇鍩?+ 闁烩晠鏅茬紞?+ 閻庡湱鎳撳▍鎺曘亹閵忕姴缍侀柛鎴犲С缂嶅秹鏁嶆径娑氬耿
 *   - `MINI_BAR_COVER_ID` / `PLAYER_BIG_COVER_ID` 濞戞挶鍊撻柌婊呯磼閸曨亝顐?id闁?
 *   - 閺夆晞娓圭紞姗€寮堕垾宕囨闂傚牜婢€缁楀矂骞橀鐔告澒濡炪倝娼ч妵鍥╀焊娓氣偓濞间即宕ラ崟顔兼 `onAreaChange` 濞戞挸锕ユ慨銈囩玻濡も偓瑜版盯鎯岄埡浣藉煂闁汇劌瀚崗姗€宕濆☉鏍ゅ亾?
 */

/** Player content builder mounted by product shells as a full-screen overlay above the shell Stack. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  // **濞戞挸绉堕～顐も偓鐟邦槸閸欏繘宕?*闁挎稒宀搁幗闈涱煥閳ュ弶鍞夌紓浣圭懃閿涙挾浠﹂崒婊呰埗闁汇劌瀚拠鐐典沪閸屾凹鍟囬柛锝庣厜缁辨繃鎯旈弴銏犲姤闁伙絾鐟у▍褔鎮?PlaybackPage 闁告劕鎳橀崕鎾箰?
  // navigationBarBottomVp 闁煎浜滅换渚€宕?padding闁靛棗鍊稿﹢顏呮交濞嗘挸娅￠柛?expandSafeArea / ignoreLayoutSafeArea
  // 濞村吋鑹鹃幏鐗堝緞閺嵮嶇处閻庡湱鎳撳▍鎺楀礃閼碱剛宕愰柨娑樼灱閺嗏偓闁谎嗘瀵粙鎳撶仦钘夌秮濠㈠爢浣插亾?
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
