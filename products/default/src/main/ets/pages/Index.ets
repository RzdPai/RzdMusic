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

import { AppStorageV2, curves, uiObserver } from '@kit.ArkUI';
import { HdsNavigation, HdsTabsController, HdsTabsBarChangeMode, SystemMaterialParams, hdsMaterial } from '@kit.UIDesignKit';
import {
  AmbientState,
  AppStorageKeys,
  areaLengthToVp,
  BarLayoutModes,
  BreakpointType,
  getWindowInfoState,
  getNavigationBarBottomVpFromWindowUtil,
  getKeyboardBottomVpFromWindowUtil,
  getPlaylistTransitionState,
  HomeSourceState,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  Logger,
  MINI_BAR_ID,
  MORPH_HOST_ID,
  MorphStage,
  PlaybackIntentState,
  PlayerExpandState,
  MorphDrive,
  MorphMetaBridge,
  // 閳?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MainPage.__shrink`閿涘绱伴棃鐐村閸斿灝鍙ч梻顓犳畱韫囶偆鍙庨弨鍓佺級濞搭喖鐪伴悩鑸碘偓?
  MorphShrinkState,
  RouterUrlConstants,
  SdkApiUtil,
  SdkConstants,
  ShowMiniLyricState,
  StyleConstants,
  TabSwitchState,
  ThemeState,
  WindowInfo,
  WindowUtil,
  buildTitleMaterial,
  BarScrollHelper
} from 'musicbasic';
import { dispatchShellPlaybackIntent, LXSourceHost, PlaybackPage, PlaybackPageCoverContent, PlayerViewModel,
  prewarmCurrentSongMesh } from 'player';
import { RecommendPage } from 'recommendation';
import { EchoReviewPage } from 'recommendation';
// 閵嗗瞼骞囬崷銊ユ皑閸氼兙鈧稄绱版惔鏇熺埉缁?2 娑擃亪銆夌粵鎾呯礄閹恒劏宕?/ **閻滄澘婀亸鍗炴儔** / 閸ョ偛鎼?/ 閹存垹娈戦敍澶堚偓?
import { NowPlayingFeedPage } from 'recommendation';
import {
  CAPSULE_SLACK_H,
  CAPSULE_SLACK_W,
  HomeMiniBarPlayer,
  MiniBarActions,
  MiniBarMaterialCapsule,
  PlaylistTransitionOverlay
} from 'playlist';
import { MinePage } from 'setting';
// 閺傜増膩閸ф绱伴張顒€婀撮棅鍏呯閿涘牆顕遍崗銉啎婢跺洭鐓舵０鎴濆煂濞屾瑧顔堥敍澶夌瑢濞叉盯娲╅崥灞绢劄鐎广垺鍩涚粩顖樷偓?
// 閳跨媴绗?hvigor 鐎?HAR 閺?*閹稿绱╅悽銊х椽鐠?*閻ㄥ嫸绱板▽鈩冩箒娴犺缍嶆禒锝囩垳 import 鐎瑰啩婊戦弮璁圭礉
//    閸楀厖濞囧鑼鐠佹媽绻?build-profile.json5閿涘矁绻栨稉銈勯嚋濡€虫健娑?*娑撳秳绱扮悮顐ょ椽鐠?*閿涘牊鐎铏瑰弾閺嶉璞㈤敍澶堚偓?
//    閹碘偓娴犮儴绻栭柌宀€娈?import 閸氬本妞傞幍鎸庡"閸氼垰濮╅崚婵嗩潗閸?閸?閹跺﹤鐣犻幏澶庣箻閺嬪嫬缂撻崶?娑撱倓閲滄担婊呮暏閵?
import { localMusic } from 'localmusic';
import type { MatchSongInfo } from 'localmusic';
import { syncManager } from 'sync';
// 濮濆本娲哥拠鍕啈閿涘牆鍞寸純顔奸挬閸欐媽鐦庣拋鐚寸礆閿涙艾鎯庨崝銊︽閹跺鈧本婀伴崷浼寸叾娑?-> 楠炲啿褰撮煬顐″敜閵嗗秶娈戠憴锝嗙€藉▔銊ュ斀鏉?comment閿?
// 鏉╂瑦鐗辩拠鍕啈闂堛垺婢橀弮銏ｅ厴閻婀痪鎸庣摃閻ㄥ嫯鐦庣拋鐚寸礉娑旂喕鍏橀惇瀣拱閸︾増鐡曢敍鍫濆爱闁板秷绻冮惃鍕亝娴滄冻绱氶惃鍕槑鐠佹亽鈧?
import { setCommentTargetResolver } from 'comment';
import type { CommentSongRef } from 'comment';
import { HdsBarLayoutMode, HdsBarStyle, HdsTabs } from '@hms.hds.hdsBaseComponent';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

/**
 * 娴滃瞼楠囨い鐢告桨閹剚璇炴潻铚傜稑閺夛紕娈戦崶鍝勭暰妤傛ê瀹抽敍鍧磒閿涘鈧?
 *
 * **娑撳酣顩绘い闈涚俺閺嶅繘鍣烽柇锝嗘蒋娑撯偓閼疯揪绱?6閿?*閿涙艾鐨濋棃?44閿涘潉HomeMiniBarAlbumCover.coverSideLengthVp()` 鐢瓕顫夐幀渚婄礆
 * + 娑撳﹣绗呴崥?6vp 閸愬懓绔熺捄婵勨偓鍌滄暏閹寸柉顩﹀Ч鍌欑癌缁狙囥€夐棃顫瘍閻劊鈧奔瀵屾い鐢稿亝娑擃亪鐝稉鈧悙鍦畱閵嗗稄绱濇稉宥呭晙閻?30vp 鐏忎線娼伴惃鍕叝閼宠泛娉妴?
 * 鐎瑰啯妲搁幘顓熸杹妞ら潧鑸伴崣妯兼畱鐠ч鍋ｉ敍灞藉殤娴ｆ洖褰ч梾蹇氱箹娑撯偓婢跺嫬鐖堕柌蹇撳綁閸栨牭绱欓崚顐㈠晙閹稿顩绘い闈涘礋閹?閸欏本甯撻崢璇插З鐎瑰喛绱氶妴?
 */
const FLOATING_MINI_BAR_HEIGHT_VP: number = 56;

/**
 * 鈽?2026-10-20锛氳繖涓父閲?*宸蹭笉鍙備笌甯冨眬**锛堜繚鐣欏父閲忔湰韬彧涓轰笉鏂帀鍘嗗彶寮曠敤锛夈€?
 *
 * 瀹冨師鏈槸"鐚?HDS 缁?tabBar 鐨勬Ы楂?閭ｅ鍐欐硶鐨勬姢鏍忥紙`LayoutPolicy.matchParent` +
 * `constraintSize.maxHeight`锛夈€傜涓夎疆鎶婂唴瀹圭洅鏀规垚"鈮?鑳跺泭鐩?锛堢敱
 * {@link MiniBarMaterialCapsule} 鐨?`barWidth 脳 barHeight` 鍞竴纭畾锛変箣鍚庯紝
 * **鍐嶄篃娌℃湁"妲介珮"杩欎釜閲?*锛屼篃灏辨病鏈?鎾戠垎"鐨勫彲鑳姐€?
 * 鈿狅笍 涓嶈鍐嶆妸瀹冩帴鍥炰换浣?`constraintSize`锛氶偅绛変簬鎶?鐚滄Ы楂?璇峰洖鏉ャ€?
 */
const FLOATING_MINI_BAR_SLOT_MAX_HEIGHT_VP: number = 80;

/** 娴滃瞼楠囨い鐢告桨閹剚璇炴潻铚傜稑閺夆€虫躬鐎硅棄鐫嗘稉瀣畱閺堚偓婢堆冾啍鎼达讣绱檝p閿涘绱伴懗璺烘抄娑撳秷顕氶柧鐑樺姬閺佺繝閲滈獮铏緲/濡楀矂娼扮粣妤€褰涢妴?*/
const FLOATING_MINI_BAR_MAX_WIDTH_VP: number = 560;

/**
 * 杩樻病閲忓埌绐楀彛瀹斤紙棣栧抚锛夋椂杩蜂綘鑳跺泭鐨?*淇濆畧鍏滃簳瀹藉害**锛坴p锛夈€?
 *
 * 鈽呪槄鈽?2026-10-20锛堢鍏疆锛屼慨銆屼簩绾ч〉鎾斁鏉″彸渚ц鍒囥€嶇殑绗竴鏉＄‖鍥狅級锛?
 * 鏃у€兼槸**纭繑鍥?336**锛岃€岃兌鍥婄洅瀹?= `336 + CAPSULE_SLACK_W(10) = 346` 鈬?
 * 浠讳綍绐楀彛瀹?< 360vp 鐨勫満鍚堬紙鎶樺彔灞忓灞?/ 搴旂敤灏忕獥 / 鍒嗗睆涓嬬獥锛変笂锛岀洅姣旂獥鍙ｈ繕瀹?鈥斺€?
 * 鐩掓槸灞呬腑鐨?鈬?**涓や晶鍚屾椂鍑虹晫**锛涜€屽彧瑕佺洅鏄彸閿氱殑锛堥椤甸偅鏉＄敤 `Alignment.BottomEnd`锛夛紝
 * 琛ㄧ幇灏辨槸銆屽乏杈规甯搞€佸彸杈硅灞忓箷鍙崇紭鍒囨帀銆嶃€?20 + 10 = 330 钀藉湪鏈€灏忕殑鎵嬫満绐楀涔嬪唴銆?
 */
const FLOATING_MINI_BAR_FALLBACK_WIDTH_VP: number = 320;

/**
 * 鎼存洘鐖妴宀€骞囬崷銊ユ皑閸氼兙鈧秹鍋呮稉鈧い鐢垫畱妞ょ數顒锋稉瀣垼閵?
 *
 * 閳?閻劍鍩?2026-10-15閿涘牆寮懓鍐ㄦ禈鐎佃鐦敍澶涚窗**鏉╂瑤绔存い浣冾洣閹跺﹥璇為崝銊ョ俺閺嶅繋绗傞弬褰掑亝閺夆€崇毈閹绢厽鏂侀弶鈩冩殻閺壜ゆ閹?*
 *   閳ユ柡鈧?閸欏倽鈧啫娴橀柌?Tab 閺嶅繋绠ｆ稉濠傚涧閺堝绔寸悰宀冪箻鎼达讣绱欏锕€缍嬮崜宥嗘闂?/ 娑擃厾绮忛弶?/ 閸欒櫕鈧粯妞傞梹鍖＄礆閿涘本鐥呴張澶庣碃娴ｇ姵娼妴?
 *   閹碘偓娴犮儲婀版い闈涗粵娑撳娆㈡禍瀣剁礄**閹烘帒绔峰Ο鈥崇础娑撯偓娑擃亜鐡ч柈鎴掔瑝閸?*閿涘矁顫?`barLayoutModeForHds()` 閻ㄥ嫭鏁為柌濠忕礆閿?
 *   閳?{@link miniBar} 閺夆€叉濞撳弶鐓?閳?闁絾娼潻铚傜稑閺夛紕娈戦崘鍛啇娑撹櫣鈹栭敍瀛扗S 閹稿鍞寸€瑰綊鍣烘?閳?**濞屸剝婀侀柇锝勭閹?*閿?
 *   閳?{@link miniBarStyleForHds} 閹帒娲?`COLLAPSE` 閳?閸楀厖绌堕悽銊﹀煕濮濄倕澧犻幎濠呯碃娴ｇ姵娼仦鏇炵磻鏉?
 *      閿涘潉miniBarExpanded === true`閿涘绱濋張顒勩€夋稊鐔剁瑝娴兼氨鏁鹃崙杞扮閺夆€崇潔瀵偓閻?*缁?*閺嶅骏绱?
 *   閳?`enableMiniBarBackground` 閸︺劍婀版い鍏歌礋 false 閳?娑撳秳绱伴悾娆庣瑓娑撯偓閺嬫氨鈹栭懗璺烘抄閼冲本婢橀妴?
 * 閳跨媴绗?**娑撳秷顩?*閺€鍦暏 `barLayoutMode = HORIZONTAL`閿涘牐鐦潻鍥风礉閻喐婧€閸欏秹顩?tab 閺嶅繒鐓稉鈧幋?閿涘绱?
 *   闁絼閲滃Ο鈥崇础閺?妞ょ數顒锋稉搴ょ碃娴ｇ姵娼?*楠炶埖甯?*"閿涘矁绯犳担鐘虫蒋缁岃櫣娼冮弮鍫曘€夌粵鍙ョ窗鐞氼偅灏嬮崚鏉夸箯鏉堝箍鈧礁褰哥粩顖溾敄閸戣桨绔撮弽绗衡偓?
 * 閳跨媴绗?妞ゅ搫绨稉?`HomeTabsPages()` 闁?`TabContent` 閻ㄥ嫭顐兼惔蹇嬧偓涔abScrollTopCommands[i]` 閻?
 *   娑撳鐖ｉ崥顐＄疅**韫囧懘銆忔稉鈧懛?*閿涘潉tab_now_playing` 闁絼绔存い鐟版皑閺勵垰鐣犻敍澶堚偓?
 */
const NOW_PLAYING_TAB_INDEX: number = 1;

/**
 * 闁款喚娲忓鐟板毉閺冭绱濇禍宀€楠囨い鐢告桨閹剚璇炴潻铚傜稑閺?*閸愬秴绶氭稉濠冨М婢舵艾鐨?*閿涘澊p閿涘娈戞稉銈勯嚋鐢悂鍣洪妴?
 *
 * 閼冲本娅欓敍鍫濈暭閺傚箍鈧﹨鍤滅€规矮绠熼柨顔炬磸閵嗗绱氶敍姘遍兇缂佺喖绮拋銈囨畱闁款喚娲忛柆鑳唨**閸欘亙绻氱拠浣界翻閸忋儲顢嬫稉宥堫潶闁喗灏?*閿?
 * 鏉堟挸鍙嗗鍡曠瑓闂堛垻娈戠紒鍕閿涘牊婀伴弶鈩冨亾濞搭喗鎸遍弨鐐蒋鐏忚鲸妲搁敍澶夌窗鐞氼偊鏁惄妯哄竾娴?閳?韫囧懘銆忛懛顏勭箒閹稿鏁惄姗€鐝惔锕備缉鐠佲斂鈧?
 *
 * 缁犳绱￠敍鍧刦loatingMiniBarKeyboardLiftVp()`閿涘绱?
 *   lift = 闁款喚娲忔妯哄 + {@link FLOATING_MINI_BAR_KEYBOARD_GAP_VP} 閳?鐢憡鈧椒绗呴懗璺烘抄缁傝鐫嗘惔鏇犳畱閺冦垺婀侀梻鎾
 * 閸忔湹鑵?閺冦垺婀侀梻鎾"閹?2026-10-12 閻ㄥ嫮婀￠張杞拌⒈閻愯鐖ｇ€?`gap 閳?1.8 鑴?barBottomMargin` 閸欏秵甯?
 * 閿涘牐顫?{@link floatingMiniBar} 闁插矂鍋呮稉銈嗘蒋鐎圭偞绁寸拋鏉跨秿閿涘鈧柡鈧?閸戝繑甯€鐎瑰啯妲告稉杞扮啊**娑撳秷顩﹂幎濠傚嚒缂佸繑婀侀惃鍕亝娴犱粙妫块梾?
 * 闁插秴顦茬粻妞剧闁?*閿涘苯鎯侀崚娆撴暛閻╂ɑ鈧椒绱板В鏂跨埗閹焦妲戦弰鐐癁妤傛ü绔撮幋顏庣礄鎼?9.1 閻劍鍩涚亸杈ㄥГ鏉?閹绢厽鏂侀弶鈩冭癁瀵版銇婃?閿涘鈧?
 *
 * 閳跨媴绗?閻喐婧€鐠嬪啯纭堕敍鍫濆涧閸斻劏绻栨稉銈勯嚋鐢悂鍣洪敍灞藉焼閺€鍦暬瀵骏绱氶敍?
 *   璺?闁款喚娲忛幀浣镐焊妤?閳?鐠?*婢?* FACTOR閿涘牆顦块崙蹇庣閻愮櫢绱氶敍娑樹焊娴?/ 娴犲秷顫﹂崢瀣╃秶 閳?鐠?*鐏?* FACTOR閿涘牆鍣?0 = 閺佸瓨娼稉濠勑╂稉鈧稉顏堟暛閻╂﹢鐝敍澶堚偓?
 *   璺?閹櫕鏆ｆ担鎾冲晙婢舵氨鏆€娑撯偓閻愬湱绱?閳?鐠嬪啫銇?GAP閵?
 */
/**
 * 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆屼簩绾ч〉闈㈣繖涓挱鏀炬潯鐩存帴璐村簳浜嗭紝鍔犵偣绌洪殭锛岄敭鐩橀伩璁╂洿鏄庢樉銆嶏級锛?
 * 涓婇潰閭ｆ锛堝惈 `CAPSULE_GAP_FACTOR` 鐨勬棫鎺ㄥ锛?*浣滃簾**锛屼互鍚庨潰杩欎袱鏉″父閲忎负鍑嗐€?
 *
 * 鐜板満鍑犱綍锛堟湰鏂囦欢宸蹭袱澶勭‘璁わ紝涓嶆槸鍋囪锛夛細
 *   路 瀹夸富鐩?= 鏈〉鏍?`Stack` 鐨?100%锛岃€屾牴 `Stack` **娌℃湁** `ignoreLayoutSafeArea`
 *     鈬?瀹冪殑搴曡竟 = **椤电洅搴?* = 绐楀彛搴?鈭?绯荤粺閬胯锛坄WindowInfo.navigationBarBottomVp`锛夛紱
 *   路 `.offset({ y })` 鐨?**+y 鍚戜笅**銆?
 *
 * 浜庢槸绂诲簳绌洪殭蹇呴』鍐欒繘 HDS 鐨?`barFloatingStyle.barBottomMargin`锛圚DS 閲屽畠灏辨槸"鏉″埌 tabs 搴曡竟鐨勮窛绂?锛夛紝
 * 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆岃繖涓敭鐩橀伩璁╁お楂樹簡鍚э紝鑰屼笖鎬庝箞鏁翠釜搴曚笅鐨勭壒鏁堥兘琚姮涓婃潵浜嗐€嶏級锛?
 * **閿洏鎶崌涓嶅啀鍔ㄥ涓?`.offset`锛屽彧鏀?HDS 鐨?`barBottomMargin`**锛涗笂闈㈤偅濂楁妸"椤电洅搴?鈮?绐楀彛搴?
 * 褰撴垚绔嬶紙婕忎簡绯荤粺閬胯 `I`锛夌殑璐?*鍏ㄩ儴浣滃簾**锛屼互姝ゅ涓哄噯銆?
 *
 * ## 涓€銆佸嚑浣曞彛寰勶紙姣忎竴椤归兘鑳藉湪浠ｇ爜閲屾寚璁わ紝涓嶆槸鍋囪锛?
 *   `H` 绐楀彛楂?vp = `viewportHeightVp`锛堚啇 `WindowInfo.windowSize.height`锛?
 *   `I` 椤电洅搴曞唴缂?vp = {@link pageBottomInsetVp}锛堚啇 `getNavigationBarBottomVpFromWindowUtil()`锛?
 *       鏍?`Stack` 娌℃湁 `ignoreLayoutSafeArea` 鈬?瀹冪殑搴曡竟灏辫惤鍦ㄣ€岀獥鍙ｅ簳 鈭?I銆嶏級
 *   `K` 閿洏楂?vp = {@link keyboardBottomVp}锛堚啇 `getWindowAvoidArea(TYPE_KEYBOARD)`锛?*閲忓埌绐楀彛搴?*锛?
 *   鈬?椤电洅搴?`Ypb = H 鈭?I`锛涢敭鐩樹笂娌?`Ykb = H 鈭?K`
 *
 * ## 浜屻€佹棫绠楀紡涓轰粈涔?澶珮"锛?2vp 鐨勮处锛?
 *   鏃у紡 `lift = K + 24 鈭?12` 绛変簬鍋囪 `I = 0`锛岃€岀湡鏈?`I 鈮?绯荤粺瀵艰埅鏉￠珮锛堚増28vp锛塦
 *   鈬?閿洏鎬佹潯搴?= `Ypb 鈭?12 鈭?lift = H 鈭?K 鈭?I 鈭?24`锛?
 *     绂婚敭鐩樹笂娌跨殑绌虹櫧 = **(H 鈭?K) 鈭?鏉″簳 = I + 24 鈮?52vp** 鈥斺€?鐢ㄦ埛鐪嬪埌鐨?涓€澶ф埅"灏辨槸杩?52銆?
 *
 * ## 涓夈€佺幇鍦ㄧ殑璐︼紙缁撴灉鎭掔瓑浜?GK锛屼竴鐪煎彲绠楋級
 *   甯告€侊細鏉″簳 = `Ypb 鈭?G`锛宍G = FLOATING_MINI_BAR_BOTTOM_GAP_VP`(12)
 *   閿洏锛氭潯搴?= `Ykb 鈭?GK`锛宍GK = FLOATING_MINI_BAR_KEYBOARD_GAP_VP`(10)
 *         闇€棰濆鎶?`L = (Ypb 鈭?G) 鈭?(Ykb 鈭?GK) = K 鈭?I + GK 鈭?G`
 *         鈬?鍐欒繘 HDS锛歚margin = G + L = K 鈭?I + GK`
 *         鈬?閿洏涓婃部鍒版潯搴曠殑绌虹櫧**鎭掔瓑浜?GK = 10vp**锛堣璁″彛寰?8~12锛夛紝`I`/`K` 鍏ㄥ彇鐪熷€笺€?
 *
 * ## 鍥涖€佷负浠€涔堝繀椤诲幓鎺夊涓?`.offset`
 *   `.offset` 浣嶇Щ鐨勬槸**杩欎釜缁勪欢杩炲悓瀹冪敾鐨勫叏閮ㄤ笢瑗?*锛堝涓?= 鏁存潯 HDS 搴曟爮锛氳兌鍥?+
 *   `systemMaterialEffect` 鏉愯川灞?+ 鏍忓簳鑹诧級鈬?鏁村潡涓€鎶紝灏辨槸鐢ㄦ埛璇寸殑"鏁翠釜搴曚笅鐨勭壒鏁堥兘琚姮涓婃潵浜?銆?
 *   鑰?`barBottomMargin` 鍦?SDK 閲岀殑璇箟鏄?鏉″埌 tabs 搴曡竟鐨勮窛绂?
 *   锛坄@hms.hds.hdsBaseComponent.d.ets:5311`锛夆噿 鍙敼鑳跺泭鍦?*瀹夸富鍐呴儴**鐨勪綅缃紝
 *   瀹夸富鐩掍笌瀹冨簳涓嬮偅浜涙暣灞傛晥鏋滃師鍦颁笉鍔紙`.offset` 宸蹭粠 {@link floatingMiniBar} 閲屽垹鎺夛級銆?
 */
const FLOATING_MINI_BAR_KEYBOARD_GAP_VP: number = 10;
const FLOATING_MINI_BAR_BOTTOM_GAP_VP: number = 12;
/**
 * 浜岀骇椤垫诞鍔ㄦ挱鏀炬潯**瀹夸富**锛坄HdsTabs`锛夌殑 id锛氬彧缁欓敭鐩樻€佽瘖鏂噺"瀹夸富鐩掑簳杈?鐢ㄣ€?
 * 鍒ゆ嵁锛氬畠搴斿綋鎭掔瓑浜?`H 鈭?I`锛涜嫢璺熺潃閿洏寰€涓婅窇 鈬?鏁撮〉琚钩绉伙紙`KeyboardAvoidMode.OFFSET`锛夛紝
 * 閭ｇ鎯呭舰涓嬫墜鍔ㄦ姮鍗囧氨鏄弻鎶紝瑙?{@link logKeyboardBarGap}銆?
 */
const SECONDARY_MINI_BAR_HOST_ID: string = 'rzd_secondary_mini_bar_host';

/**
 * 娑撳﹥濯洪幍鎾崇磻閹绢厽鏂佹い鐢垫畱**鐠ч攱澧滈悜顓炲隘**妤傛ê瀹抽敍鍧磒閿涘矁鍒涚仦蹇撶鎼存洟鍋呮稉鈧弶鈽呯礆閵?
 *
 * 鏉╄渹缍橀弶?56 + 鎼存洟鍎撮柆鑳唨閿涘牆顕遍懜顏呮蒋/鐏忓繒娅ч弶锛勫 14~24閿? 8 閻ㄥ嫯绔熺捄婵撶礉閸愬秴绶氭稉濠佺鐏忓繑顔屾担娆撳櫤 閳?112閵?
 * 閸欘亝婀侀拃钘夋躬鏉╂瑦娼敮锕傚櫡閻ㄥ嫪绗傚鎴炲閻㈠崬锛撶仦鍌涘复缁犫槄绱欑拠锕侇潌 `pullOpenStartsNearBottom()`閿涘鈧柡鈧?
 * 妞ょ敻娼版稉顓燁唽閻ㄥ嫪绗傚鎴滄唉鏉╂绮伴崚妤勩€冮敍宀勪缉閸忓秲鈧本鍨滈惃鍕€夋禒搴㈡尡閺€鎯ф珤娑撳﹪娼版稉鈧柈銊ュ瀻娑撳﹥绮︽稊鐔稿ⅵ瀵偓閹绢厽鏂侀崳銊ｂ偓宥冣偓?
 */
const PULL_OPEN_HANDLE_BAND_VP: number = 112;

/**
 * 閹绢厽鏂佹い鍨癁鐏炲倸婀竟鍐茬湴 Stack 闁插瞼娈戠仦鍌滈獓閵?
 *
 * 韫囧懘銆忔妯圭艾 HdsTabs閿涘牐鍤滃?`zIndex(1)`閿涘本璇為崝銊ョ俺閺嶅繋绡冮崷銊ョ暊闁插矂娼伴敍澶婃嫲娴滃瞼楠囨い鐢告桨閻ㄥ嫭鍋撳ù顔跨碃娴ｇ姵娼妴?
 * 閹绢厽鏂佹い?*娑撳秴鍟€閻?`bindContentCover`**閿涙碍膩閹礁顔栨稉缁樻Ц娑撳秹鈧繑妲戦惃鍕鐏炲偊绱濇导姘辨磰娴ｅ繘顩绘い鍏哥瑢鏉╄渹缍橀弶鈽呯礉
 * 閼?娴犲氦绯犳担鐘虫蒋闂€鍨毉閺?閻ㄥ嫬鑸伴崣妯讳紗閹媽顩﹂柅蹇撳毉鐎瑰啩婊戦敍鍫ｎ嚊鐟?build() 闁插瞼娈戝▔銊╁櫞閿涘鈧?
 */
const PLAYER_OVERLAY_Z_INDEX: number = 100;

/**
 * 瑜般垹褰夐崗瀣畷鐏炲偊绱欐潻铚傜稑閺夆€冲閺堫剨绱氶崷銊ワ紦鐏?Stack 闁插瞼娈戠仦鍌滈獓閿涙艾绻€妞?*妤傛ü绨?*閹绢厽鏂佹い鍨癁鐏炲倶鈧?
 * 閸欏秶绱拠鎴﹀櫡閸忓娈曠仦鍌涘瘯閸?`MainPage` 閻ㄥ嫭娓舵稉濠傜湴閿涘牅绗佹稉?lambda閿涘绱濆В鏃€鎸遍弨楣冦€夌€圭懓娅掗弴鎾彯閵?
 */
const PLAYER_CLONE_Z_INDEX: number = 110;
// 鈽呪槄鈽?2026-10-21锛堢鍏疆锛夛細杩欓噷鐨勪簲涓父閲忥紙`HOME_MINI_CAPSULE_Z_INDEX` /
// `HOME_MINI_CAPSULE_GAP_VP` / `HOME_TAB_DOCK_VP` / `HOME_MINI_CAPSULE_SINGLE_ROW_MIN_WIDTH_VP` /
// `HOME_MINI_BAR_CONTENT_PAD_VP`锛?*宸查殢 `homeMiniCapsule()` 涓€璧峰垹闄?* 鈥斺€?
// 瀹冧滑鎻忚堪鐨勬槸"鎾斁鍣ㄦ惉鍑?`miniBar` 妲戒箣鍚庢垜浠緱鑷繁绠楃旱鍚戞帓甯?鍗曞眰瀹藉害"鐨勯偅濂楀嚑浣曘€?
// 鐜板湪涓€绾ч〉鍥炲埌涓婃父缁撴瀯锛堟挱鏀惧櫒浣?`miniBar` 妲姐€佷袱鎺?鍗曟帓鐢?HDS 鐨?`barLayoutMode` 椹卞姩锛夛紝
// 閭ｅ鍑犱綍涓€涓兘涓嶉渶瑕侊紱涓ゆ潯杩蜂綘鏉＄殑鍙楂樺害浠嶇敱 `FLOATING_MINI_BAR_HEIGHT_VP`(56) 鍞竴鍐冲畾銆?
/**
 * 閳?2026-10-17閿涙艾鎻╅悡褎鏁圭紓鈺傝癁鐏炲偊绱檂ShrinkOverlayHost`閿涘娈戠仦鍌涱偧 閳ユ柡鈧?**韫囧懘銆忓В鏂剧瑐闂堛垺澧嶉張澶嬭癁鐏炲倿鍏樻?*閵?
 *   鐎瑰啩鍞悰?濮濓絽婀☉鍫濄亼閻ㄥ嫰鍋呮稉鈧仦蹇旀尡閺€楣冦€?閿涘苯甯囬崷銊ュ帬闂呭棗鐪伴敍?10閿涘绗屾潻铚傜稑閺夆€茬娑撳﹥澧犳稉宥勭窗鐞氼偆娲婃担蹇嬧偓?
 *   閳跨媴绗?閺冪姷鏅柇锝勭娓氀冪暊娑旂喐鐥呴張澶夌瑩闂傘劎娈?z閿涘潉MainPage` 闁插苯鐣犻幒鎺戞躬濞搭喖鐪扮€瑰じ瀵屾稊瀣倵閿涘绱?
 *     鏉╂瑩鍣烽弰鎯х础缂佹瑤绔存稉顏勨偓鐓庡涧閺勵垯璐熸禍?*娑撳秳绶风挧鏍э紣閺勫酣銆庢惔?*閵?
 */
const SHRINK_OVERLAY_Z_INDEX: number = 130;

/**
 * 閳?閹绢厽鏂佹い闈涘弳閸?*閸欏矁寤哄鈧崗?*閿涘牊鏌﹀銉ユ禈缁?1 濮濄儻绱氶妴?
 *
 * - `true` 閿涙碍鎸遍弨楣冦€夋担婊€璐?**NavDestination** 閹恒劌鍙嗛敍鍧刾ushPath(..., animated = false)`閿涘绱?
 *   鐎瑰苯鍙忕€佃鐖ｉ弮鐘垫櫕 1.2.4閵嗗倻閮寸紒鐔绘祮閸﹀搫绻€妞よ鍙ч幒?閳ユ柡鈧?瑜般垹褰夐懛顏勭箒鐏忚鲸妲搁崝銊ф暰閿涘奔琚辨總妤€濮╅悽璇插綌閸︺劋绔寸挧?
 *   鐏忚鲸妲搁悽銊﹀煕閹躲儳娈?閸斻劎鏁炬稉顓⑩偓鏂跨殱闂堛垹缍婃担?/ 鎼存洟鍎寸粚杞扮閸?閵?
 * - `false`閿涙碍妫捄顖氱窞閿涘本鎸遍弨楣冦€夋担婊€璐熸竟鍐茬湴 Stack 闁插瞼娈戝ù顔肩湴閿涘潉isShowPlay` 閺夆€叉濞撳弶鐓嬮敍澶堚偓?
 *
 * 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 閳藉應妲?2026-10-15閿?*瀹稿弶澧﹀鈧?*閿涘苯娲滄稉杞扮瑐濞嗏€虫礀闁偓閻ㄥ嫭鐗撮崶鐘冲閸掗绨?閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
 * **閸樼喐娼垫稉杞扮矆娑斿牆娲栭柅鈧?*閿?026-09-25 娑撳﹥婧€閿涘绱癭NavDestination` 濞撳弶鐓嬮崷?`HdsNavigation` 閸愬懘鍎撮敍?
 * 閻劎娈戦弰?**STANDARD** 濡€崇础 閳ユ柡鈧?闁絼閲滃Ο鈥崇础娑撳鐣?*閼奉亜鐢稉宥夆偓蹇旀鎼?*閿?闁繑妲戦懗灞炬珯娑旂喎甯囨稉宥勭秶 HDS 閼奉亜鐢惃鍕俺"閿?
 * 娴滃孩妲搁崥灞芥躬鐠?Navigation 闁插瞼娈?**HDS 濞搭喖濮╂惔鏇熺埉閿涘牐绯犳担鐘虫蒋閻喕闊╅敍澶庮潶閺佸澧栭惄鏍︾秶**閿?
 * 閼板苯鑸伴崣妯讳紗閹媽顩﹂柅蹇撳毉闁絾娼潻铚傜稑閺?閳?"娑撯偓閹恒劌鍙嗙亸杈ㄥ灇娑撯偓閸фぜ鈧礁绨抽柈銊ュ嫉缂傝桨绔撮崸?閵?
 *
 * **鏉╂瑦顐奸惃鍕掗懡顖ょ礄闁棗鎮滃妤€鍩岄敍灞藉嚒閺嶇鐤勯崚?API 鐏炲偊绱?*閿?
 * 閺冪姷鏅惃鍕尡閺€楣冦€?`HdsNavDestination` **鐠佸彞绨?`mode(NavDestinationMode.DIALOG)`**
 * 閿涘潉wujie.pa:190804-190811`閿涘鈧倸鐣奸弬纭咁嚔娑斿绱欓張顒佹簚 SDK
 * `openharmony/ets/component/nav_destination.d.ts:317-333`閿涘绱?
 * > "Dialog mode, where the navigation destination is **transparent by default**,
 * >  and adding or removing the navigation destination **does not affect the underlying
 * >  page's lifecycle**."
 * 閳?**姒涙顓婚柅蹇旀 + 娑撳秴濂栭崫宥勭瑓鐏炲倿銆夐棃?* 閳?娑撳鐪版＃鏍€夋稉搴ょ碃娴ｇ姵娼?*娑撳秷顫﹂惄鏍︾秶閵嗕椒绗夌悮顐︽閽?*閿?
 * 瑜般垹褰夐崗銊р柤**閸欘垵顫嗘稉鏂垮讲闁?*閿涘潉expand.init` 濮濓絾妲搁棃?`getFrameNodeById` 閻ㄥ嫮鐓╄ぐ銏㈢暬鐠ч鍋ｉ敍澶堚偓?
 * 鏉╂瑤绔撮崣銉ュ嚒缂佸繐濮為崷?`features/player/.../PlaybackPageRoute.ets` 閻?`.mode(...)` 娑撳鈧?
 *
 * 閳跨媴绗?**DIALOG 閻ㄥ嫪琚辨稉顏冨敩娴?*閿涘潉PlaybackPageRoute.ets` 闁插苯鍑℃径鍕倞/瀹稿弶鏁為弰搴礆閿?
 *   閳?DIALOG 姒涙顓?*娑撳秴鎼锋惔鏃囩箲閸ョ偤鏁?* 閳?韫囧懘銆忛弰鎯х础 `.onBackPressed()`閿涘牆鍑＄紒娆欑礆閿?
 *   閳?娑撳秴鍟€閺堝閮寸紒鐔绘祮閸﹁桨绗岀化鑽ょ埠鎼?閳?妞よ埖鐖?閼冲本娅?鐟佷礁澹€閸忋劎鏁遍幘顓熸杹妞や絻鍤滃杈╂暰閿涘牊婀扮拠銉ヮ洤濮濄倧绱氶妴?
 *
 * 閳跨媴绗?**閸ョ偤鈧偓閺傝纭?*閿涙碍濡告潻娆撳櫡閺€鐟版礀 `false` 閸楀啿褰查崶鐐插煂"婢瑰啿鐪板ù顔肩湴"闁絾娼鏌ョ崣鐠囦礁褰查悽銊ф畱鐠?
 *    閿涘牊璇炵仦鍌欏敩閻椒绗岄崗瀣畷鐏炲倿鍏樻潻妯烘躬閿涘矂娈㈤崠鍛椽鐠囨埊绱濇稉宥囨暏闁插秵鏌婇幖顓ㄧ礆閵?
 */
const PLAYER_ROUTE_MODE: boolean = true;

/**
 * 閹绢厽鏂佹い浣冪熅閻㈠崬寮弫甯礄鐎佃鐖ｉ崣宥囩椽鐠囨垿鍣烽惃?`param.pull`閿涘鈧?
 *
 * 閻劎琚懓灞肩瑝閺勵垰灏堕崥宥咁嚠鐠炩€崇摟闂堛垽鍣洪敍娆皉kTS 鐎?`NavPathInfo.param`閿涘潉Object`閿涘绱剁€涙娼伴柌蹇擃啇閺勬挻濮ょ猾璇茬€烽梻顕€顣介敍?
 * 閺勬儳绱＄猾璇茬€锋稊鐔活唨"鏉╂瑦顐兼潻娑樺弳鐟曚椒绗夌憰浣借泲瑜般垹褰?鏉╂瑤娆㈡禍瀣躬閺冦儱绻旈柌灞藉讲鐠囨眹鈧?
 */
class PlayerRouteParam {
  /** true = 鏉╂瑦顐兼潻娑樺弳鐟曚浇铔嬭ぐ銏犲綁閿涘牏鏁遍幍瀣瘹閹锋牕鍙嗛幋鏍仯閸?閹板繐娴橀幍鎾崇磻閺冨墎绮烘稉鈧純?true閿涘鈧?*/
  pull: boolean = true;

  constructor(pull: boolean) {
    this.pull = pull;
  }
}

/** 婢瑰啿鐪伴弮銉ョ箶閺嶅洨顒烽敍鍧刪dc shell hilog | grep HomeShell` 閸欘垱宕ぐ銏犲綁/鐠侯垳鏁遍柧鎹愮熅閿涘鈧?*/
const RzdShellLogTag: string = 'HomeShell';

/**
 * 娑撳﹥濯洪弶鐐閸氬海娈戦弨璺虹啲閺冨爼鏆遍敍鍧閿涘鈧柡鈧?**閹绘劒姘﹂敍鍫濐檮闂冨牆鈧》绱?* 娑?**閸欐牗绉烽敍鍫滅瑝婢剁喖妲囬崐纭风礆** 娑撱倓閲滈崐绗衡偓?
 *
 * 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱伴弨瑙勫灇**鐎瑰啴鍋呮總妤€鑸伴崣妯垮殰瀹歌京娈戠敮鎼佸櫤**閿涘绱?
 *   閺冪姷鏅惃?`commitPull()` / `cancelPull()` 闁€熻泲 `animateMorphT(SETTLE_MS, t, EASE_OUT_STR)`閿?
 *   閼?**`SETTLE_MS = 400`閿涘奔绗栭幓鎰唉娑撳骸褰囧☉鍫熸Ц閸氬奔绔存稉顏勨偓?*
 *   閿涘潉_recover/logic-src/瀵偓閸忚櫕鎸遍弨鎯ф珤-閹靛濞嶇捄顖氱窞鐎规氨顭?md` 鎼? 闁喐鐓?L25/L26 娑?鎼傞崗?L219/L220閿?
 *   閸氬氦鈧懘鈧劖娼紒娆庣啊鐎涙濡惍浣筋攽閸?L146973 / L146866閿涘鈧?
 *
 * 閳跨媴绗?閺€鐟板閺?**300 / 180**閿涘苯甯▔銊╁櫞閸愭瑧娼?閸欐牗妫ら悾?Tokens 闁插瞼娈?300閿涘牅瀵屾潪顒€婧€閿? 180閿涘牆浜曟禍銈勭鞍閿? 閳ユ柡鈧?
 *   **閸欐牠鏁婃禍鍡樻降濠?*閿涙岸鍋呴弰顖涙￥閻ｅ瞼娈?*闁氨鏁ょ拋鎹愵吀 token**閿涘矁鈧矁绻栭柌宀冾洣閻ㄥ嫭妲?*鏉╂瑥顨滆ぐ銏犲綁閼奉亜绻侀惃?*鐢悂鍣?
 *   閿涘潉MainPage.SETTLE_MS`閿涘鈧倸鎮撴稉鈧稉顏堟晩鐠囶垱娼靛┃鎰躬"閸忔娊妫撮弮鍫曟毐"娑撳﹤鍑＄紒蹇曞П鏉╁洣绔村▎鈽呯礄鎼?6.20閿?
 *   闁絽顦╂稉宥勭矌閺冨爼鏆遍崑蹇曠叚閿涘瞼绱﹂崝銊ㄧ箷閺佸瓨娼幎鍕灇娴?閹垫挸绱?閻劎娈戦柇锝嗘蒋 閳?閻劍鍩涚€圭偞绁撮妴灞藉彠闂傤厼鍤戞稊搴㈢梾閸斻劎鏁鹃妴宥忕礆閵?
 *
 * 閳?妞ゅ搫鐢稉鈧稉顏咁劀闂堛垺鏅ラ弸婊愮窗婢瑰啿鐪伴崣鐘插鐏炲偊绱檂MorphCoverClone`閿涘绐囬惃鍕Ц閺冪姷鏅?`ENTER_MS = 560ms`閿涘牆鍑＄€靛綊缍堥敍澶堚偓?
 *   閺€鐟板閹绢厽鏂佹い?`300 + 20 = 320ms` 鐏忚精鎯ゆ担宥忕礉**缁傝褰旈崝鐘茬湴閻?560 瀹?240ms**閿涘牐顩﹂棃?
 *   `morphOverlayBridging()` 閸忔粎娼冮幍宥勭瑝鐞氼偄鍨忛弬顓ㄧ礆閿涙稒鏁奸幋?400 閸氬氦鎯ゆ担宥呮躬 `420ms`閿?
 *   **瀹割喛绐涚紓鈺佸煂 140ms** 閳?鐞氼偄鍨忛弬顓犳畱妞嬪酣娅撻弴鏉戠毈閵?
 *
 * 閳跨媴绗?鏉╂瑦妲?*缁绢垵顫囬幇?*閺€鐟板З閿涘牊妫ら崝鐔诲厴瑜板崬鎼烽敍澶堚偓鍌濆娴ｇ姳绗傞張楦款潕瀵?閹垫挸绱戦崣姗€鎸愭禍?閵嗕椒绗夋俊鍌氬斧閺夈儴绐￠幍瀣剁礉
 *   **閸ョ偤鈧偓鐏忚鲸妲搁幎濠呯箹娑撱倛顢戦弨鐟版礀 `300` / `180`** 閳ユ柡鈧?娑撯偓婢跺嫪绔寸悰宀嬬礉娴滄帊绗夎ぐ鍗炴惙閵?
 */
// 鈽呪槄鈽?2026-10-18锛?*鍗曟椂闂寸嚎鏇存**锛夛細涓婇潰閭ｆ"400 璧锋"鐨勬帹瀵间綔搴熴€?
//   涓婃父銆岀偣鍑昏糠浣犳潯 鈫?鎾斁椤点€嶈繖鏉¤矾涓?*娌℃湁 350ms 閭ｆ潯**锛歚pushPath` 甯?`param.pull=true` + `animated=false`
//   鈬?`setupExpandTransition` 璧?`param.pull===true` 鍒嗘敮锛坄wujie.pa:179258-179317`锛夊彧鍋?`expand.init()` + `pullMode=true`
//   + `return`锛?*涓嶆敞鍐?* `NavTransition`锛坄NavTransition.register` 鍏ㄥ寘鍞竴璋冪敤鐐?`:179419-179434` 鍙湪 `param.srcId` 鍒嗘敮锛?
//   鈬?`ExpandAnimation.doEnter`锛?50ms + `Curve.EaseInOut`锛夊湪鐐瑰嚮璺笂**涓€娆￠兘涓嶈窇**锛?
//   瀹瑰櫒鍑犱綍鏀圭敱 `onPullTChanged 鈫?applyPullProgress(effT())`锛坄:174826-174889`锛夐┍鍔紝
//   鑰?`effT = isMorphTarget() ? pullT : 1`锛坄:171535-171549`锛夈€乣pullT 鈮?MainPage.morphT = animateMorphT(1, 560, EASE_OUT_STR)`
//   锛坄:163524-163547` / `:154167-154169` / `:145608-145661`锛夈€?
//   鈬?**鍏ㄨ矾鍙湁涓€鏉?560ms + cubic-bezier(0.23,1.0,0.32,1.0)**锛屽悓鏃堕┍鍔ㄦ诞灞傛嫹璐?/ 瀹瑰櫒鍑犱綍 / 鍐呭绐楀彛銆?
//   `400` 浼氬湪 420ms 灏辨妸椋炶鎷﹁叞鎴柇锛堟诞灞備笌鍏嬮殕琚挙銆佺湡灏侀潰鎻愬墠鐜帮級锛岃繖灏辨槸"椋炲叆鏃堕棿涓嶅"鐨勪竴閮ㄥ垎銆?
const PULL_OPEN_SETTLE_MS: number = 560;
const PULL_OPEN_ABORT_MS: number = 400;

/**
 * 鐠虹喐澧滈張鐔兼？鐞涖儵鍣?缂侇參顥ｇ亸渚€娼扮紒鍫㈠仯"閻ㄥ嫰鍣哥拠鏇燁偧閺?/ 闂傛挳娈ч敍鍧閿涘鈧?
 *
 * 娑?`PlaybackPage` 閻?12 鑴?32ms 閸氬奔绔存總妤冪崶閸欙綇绱欑€佃鐖ｉ崣宥囩椽鐠?`schedulePublishRetry`閿涘绱?
 * 閹绢厽鏂佹い鍨Ц**鐠ч攱澧滈柇锝勭閸?*閹靛秵瀵曟潪鐣屾畱閿涘苯鐣犻惃鍕亣鐏忎線娼版禒鈧稊鍫熸閸婃瑥褰查柌蹇撳絿閸愬厖绨敮鍐ㄧ湰鐢勬殶閵?
 */
const PULL_ANCHOR_RETRY_MAX: number = 12;
const PULL_ANCHOR_RETRY_MS: number = 32;

/**
 * Default phone shell: tabbed home with recommendation feed, floating mini player (API 601+),
 * and full-screen playback when MusicAppState.isShowPlay is true.
 */
@Entry
@ComponentV2
struct Index {
  /** Navigation stack for HdsNavigation routes and modal playback cover. */
  @Provider('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Reactive window width / height breakpoint from the system. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Index of the selected bottom tab (0 = home), shared for cross-tab navigation. */
  @Local tabState: TabSwitchState =
    AppStorageV2.connect(TabSwitchState, AppStorageKeys.TAB_SWITCH_STATE, () => new TabSwitchState())!;
  /** Bottom-bar immersive material level, reactive to settings changes. */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** App accent color, reactive to settings changes. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** Home recommendation source, reactive to settings changes. */
  @Local homeSourceState: HomeSourceState =
    AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;
  /** Playback page mini lyric switch, reactive to settings changes. */
  @Local miniLyricState: ShowMiniLyricState =
    AppStorageV2.connect(ShowMiniLyricState, AppStorageKeys.SHOW_MINI_LYRIC_STATE, () => new ShowMiniLyricState())!;
  /** Shared playback and UI state (queue, mini bar, full-screen flag). */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** External intents (e.g. deep link) that request opening the player shell. */
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
  /**
   * 閺€鎯版崳鐠囬攱鐪伴柅姘朵壕閿涘牅绗岄幘顓熸杹妞ら潧鍙￠悽顭掔礆閵?
   *
   * 缁崵绮烘潻鏂挎礀鐟曚焦鐪伴崗鎶芥４閹绢厽鏂佹い鍨侀幀浣规閿涘苯锛撶仦鍌氬涧閸︺劏绻栭柌?`requestCollapse()`閿?
   * 閻喐顒滈惃鍕暪鐠у嘲濮╅悽鑽ゆ暠閹绢厽鏂佹い鍨尡閿涘本鎸辩€瑰苯鐣犻懛顏勭箒閹?`isShowPlay` 缂?false閵?
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /**
   * 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MainPage` 閻?`__shrink` + `shrinkPixmap`閿涘绱?
   * 閵嗗矂娼幍瀣◢閸忔娊妫撮妴宥忕礄閸忔娊妫撮幐澶愭尦 / 缁崵绮烘潻鏂挎礀閿涘鍋呮稉鈧Λ鎺旀畱**濠婏紕鐛ヨ箛顐ゅ弾濞搭喖鐪?*閵?
   *
   * 閺冪姷鏅柇锝勭娓氀嗙箹娑撱倖鐗遍柈鑺ュ瘯閸?`MainPage` 娑撳绱檂wujie.pa:143995` / `144006`閿涘绱?
   * 濞撳弶鐓嬮悙閫涚瘍閸?`MainPage`閿涘潉162465-162707`閿涘鈧柡鈧?閹碘偓娴犮儲婀版禒鎾虫倱閺嶉鏁?*婢瑰啿鐪?*閹镐焦褰欐稉搴㈣閺屾挶鈧?
   * 閹绢厽鏂佹い浣冪鐠?閹峰秴鎻╅悡?+ `start(...)`"閿涘牆鐣犻幍宥囩叀闁挷绮堟稊鍫熸閸婃瑨顩﹂崗绛圭礆閿涘苯锛撶仦鍌濈鐠愶絿鏁鹃妴?
   */
  @Local shrinkState: MorphShrinkState =
    AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
  /** Cached window metrics (safe areas, size) for layout padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /**
   * 瑜版挸澧犵€佃壈鍩呴弽鍫熺箒鎼达讣绱? = 鏉╂ê婀＃鏍€?Tab 娑撳绱?0 = 瀹歌尙绮￠幒銊ュ弳娴滃棔绨╃痪褔銆夐棃顫礆閵?
   *
   * 閸欘亞鏁ら弶銉ュ枀鐎规哎鈧苯鍙忕仦鈧幃顒佽癁鏉╄渹缍橀幘顓熸杹閺壜扳偓宥嗘Ц閸氾附妯夌粈鐚寸窗妫ｆ牠銆夐柇锝勫敜鏉╄渹缍橀弶鈥虫躬 HDS 濞搭喖濮╂惔鏇熺埉闁插矉绱?
   * 娴滃瞼楠囨い鐢告桨娴兼碍濡搁弫缈犻嚋濞搭喖濮╂惔鏇熺埉閻╂牔缍囬敍灞惧娴犮儰绨╃痪褔銆夐棃銏ゆ付鐟曚礁婀張鈧径鏍х湴閸愬秵瀵曟稉鈧禒鏂ょ礄鐟?
   * {@link floatingMiniBar}閿涘鈧?
   *
   * 閳跨媴绗?娑撳秷顩﹂崘宥嗗瑏鐎瑰啫骞撻弨鐟扮俺闁劌顕遍懜顏嗘畱 `barHeight` / `barFloatingStyle`閿涘牐鐦潻鍥风礉鎼存洘鐖惄瀛樺复閸у繑甯€閿涘鈧?
   */
  @Local navDepth: number = 0;
  /**
   * 瑜般垹褰夐崗瀣畷鐏炲倻鏁ら惃鍕尡閺€鎯ф珤 VM閵?
   *
   * 閸忓娈曠仦鍌濐洣閻㈡槒绯犳担鐘虫蒋閸欏厖鏅堕柇锝勭閸ф娈?*閸擃垱婀?*閿涘牊鐡曢崥?濮濆本澧?+ 閹绢厽鏂侀幐澶愭尦閿涘绱濈€瑰啳顩︾拠璇茬秼閸撳秵娲搁惄顔荤瑢閹绢厽甯堕悩鑸碘偓渚婄幢
   * 娑撳海婀＄€圭偠绯犳担鐘虫蒋閸氬嫯鍤滈幐浣规箒娑撯偓娑?VM 鐎圭偘绶ラ弰顖氱暔閸忋劎娈戦敍鍦碝 閸欘亝妲?`MusicAppState`/`MediaService` 閻ㄥ嫰妫棃顫礉
   * 閻樿埖鈧焦婀伴煬顐＄矝閻掕泛褰ч張澶夌娴犳枻绱氶妴?
   */

  /**
   * 缁愭褰涚€硅棄瀹抽敍鍧磒閿涘绱濋悽銊ょ艾缂佹瑦鍋撳ù顔跨碃娴ｇ姵娼粻妞剧娑?*缁嬪啿鐣鹃惃鍕▔瀵繐顔旀惔?*閵?
   *
   * 閹剚璇為弶鈩冩Ц閸欑姴婀い鐢告桨娑撳﹦娈戦悪顒傜彌閼哄倻鍋ｉ敍灞筋啍鎼达箑绻€妞ゆ槒鍤滃杈╃暬閸戝棴绱伴棃?`width('100%')` + 婢舵牕鐪?padding
   * 閸︺劑鍎撮崚鍡楄埌閹椒绗呮导姘辩暬闁挎瑱绱檋ugging 閸掓澘褰告潏?/ 閹炬垶鍨氶弫瀛樻蒋婢堆囨毐閺傜懓鑸伴敍澶涚礉閼板瞼娅ㄩ崚鍡樼槷鐎硅棄瀹抽崣鍫滅窗閸?
   * 缁愭褰涚亸鍝勵嚟閸欐ê瀵查弮鎯扮儲閸欐ǜ鈧倽绻栭柌灞藉涧閸︺劑顩诲▎鈥虫嫲鐏忓搫顕惇鐔割劀閸欐ê瀵查弮鑸垫纯閺傝埇鈧?
   */
  @Local viewportWidthVp: number = 0;
  /** 鐟欏棗褰涙妯哄閿涘澊p閿涘绱版稉濠冨閹垫挸绱戦惃?鐠ч攱澧滈弰顖氭儊閸︺劌绨抽柈?閸掋倕鐣炬稉搴濈秴缁夌粯妲х亸鍕厴鐟曚胶鏁ょ€瑰啨鈧?*/
  @Local viewportHeightVp: number = 0;
  /** 娑撳﹥濯洪幍鎾崇磻閹靛濞嶉敍鍫㈢彨閻╁瓨鏌熼崥鎴礆閵?*/
  @Local miniBarViewModel: PlayerViewModel = new PlayerViewModel();
  private pullOpenOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /**
   * 鐠囧﹥鏌囬梻闈╃窗閺堫剝鐤嗛幍瀣◢閺勵垰鎯?*瀹歌尙绮＄拋鎷岀箖娑撯偓濞?*"鐠虹喐澧滈弴瀛樻煀鐞氼偄鍨介幑顔藉珕閹?閵?
   *
   * 娑撹桨绮堟稊鍫ユ付鐟曚礁鐣犻敍鍫ｂ偓灞肩瑝閺勵垱鐦″▎锟犲厴鐠佸府绱氶敍姝歰nPullOpenUpdate` 閻㈣鲸鐦℃稉顏囆曢幗鍝バ╅崝銊ょ皑娴犳儼鐨熼悽顭掔礉
   * 閼板矁顓搁弫鎷屾儰閸?`PlayerExpandState` 閻?`@Trace` 鐎涙顔屾稉?閳?濮ｅ繑顐奸柈钘夊晸娴兼俺顔€瀵拌姤鐖ｉ柇锝勯嚋
   * 13 鐞?`Text` 濮ｅ繐鎶氶柌宥呯紦閿?*鐠囧﹥鏌囬張顒冮煩娴兼碍濡搁幍瀣妳閹煎懏绁?*閵嗗倽鐦栭弬顓炲涧闂団偓鐟?鏉╂瑤绔存潪顔芥箒濞屸剝婀佺悮顐ｅ珕"
   * 鏉╂瑤绔存稉顏冪皑鐎?閳?娑撯偓濞嗏剝澧滈崝鍨涧鐠侀绔村▎鈽呯礄`onPullOpenStart` 闁插本绔婚梿璁圭礆閵?
   * 鐠囩粯鏆熼敍姘獦閺嶅洨顑囬崡浣筋攽 `pd=<鐠ч攱澧滈幏?/<閺囧瓨鏌婇幏?/<閺夌偓澧滈幏?`閿涘矁顫?`PlayerExpandState.pullDropBegin`閵?
   */
  private pullDropCountedThisGesture: boolean = false;

  /**
   * 娑撯偓瀵姵鍩呴崶鎯ф皑閼宠姤瀣侀崚?x/y/w/h閿涘奔绗呮稉鈧潪顔藉瘻閺佹澘鐡ч弨鐟扮暚閸楀啿鍨归妴?
   */
  private tabsController: HdsTabsController = new HdsTabsController();
  /**
   * 鏉╂稑鍤禍宀€楠囨い鐢告桨閺堢喖妫块幎鎴濆煑 HDS 閻ㄥ嫭鐗卞蹇撴礀鐠嬪喛绱欐潻娑楃癌缁狙囥€夐棃顫瑝閸愬秵鏁肩敮鍐ㄧ湰閻樿埖鈧緤绱濋崣顏嗘暏娴滃骸鍤い鐢告桨閺冨墎娈戦獮鍌滅搼鐎靛綊缍堥敍澶堚偓?
   */
  private restoringHomeBar: boolean = false;

  /**
   * 婢瑰啿鐪板銈呭煝閺勵垰鎯?*閼奉亜绻?*閹镐焦婀佸ù顔肩湴闁絼绔村Λ鎺旀畱鐞涖儵妫块敍鍧凪orphCoverClone` 閻?`morphOverlayP`閿涘鈧?
   *
   * 閻劑鈧柨褰ч張澶夌娑擃亷绱扮紒?`@Monitor('expandState.morphDrive')` 鐠佲晞鐭?閳ユ柡鈧?
   * `settlePullOpen` 鐠у嘲鐣竟鍐茬湴閻ㄥ嫭璇炵仦鍌澦夐梻缈犵閸氬簼绱伴幎?`morphDrive` 缂冾喗鍨?`ANIM`閿?
   * 闁絼绔撮惉顒傛磧閹貉冩礀鐠嬪啩绡冩导姘愁潶鐟欙箑褰傞敍娑楃瑝閸ョ偠顔€閻ㄥ嫯鐦界€瑰啩绱伴崘宥堟崳娑撯偓閺夆剝鏌熼崥鎴犳祲閸欏秶娈戝ù顔肩湴鐞涖儵妫?
   * 閿?閺夌偓澧滃▽陇绻冮梼鍫濃偓绗衡偓浣哥殱闂堛垹鍑＄紒蹇撶窔閸ョ偠藟娴滃棴绱濋崣鍫ｎ潶閹疯棄鍩岄拃鎴掔秴"閿涘鈧?
   * 濞夈劍鍓扮€?*娑撳秵妲?*濞撳弶鐓嬮梻顭掔礄濞撳弶鐓嬮梻銊ユ躬 `PlayerExpandState.morphOverlayBridging()` 闁插矉绱氶妴?
   */
  private shellOwnsOverlayTween: boolean = false;

  /** Initializes play queue ids from local DB for the session. */
  aboutToAppear() {
    // 鈽呪槄鈽?2026-10-18锛堢収鎼笂娓镐袱娈靛紡锛氬垽鎰忓浘 鈫?controller 钀藉湴锛夛細婊氬姩渚у彧琛ㄨ揪鎰忓浘锛?
    //   鏍峰紡鍒囨崲涓庡姩鐢婚兘浜ょ粰 HDS锛圫DK `@hms.hds.hdsBaseComponent.d.ets:5729`銆宒efault animation銆嶏級銆?
    BarScrollHelper.expandApplier = (expand: boolean): void => {
      this.applyHomeBarExpanded(expand);
    };
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto) => dto.id);
    // 閳?妞ょ數顒锋禒?4 娑擃亝鏁归幋?2 娑擃亷绱欓幒銊ㄥ礃 / 閹存垹娈戦敍澶夌閸氬函绱漙TabSwitchState.tabIndex` 閸欘垵鍏橀弰顖欑瑐娑撯偓閻楀牏鏆€娑撳娈?
    //   鐡掑﹦鏅稉瀣垼閿涘牊鐦俊鍌涙＋閻ㄥ嫨鈧本鍨滈惃鍕┾偓? 2閵嗕降鈧矁顔曠純顔衡偓? 3閿涘鈧柡鈧?HdsTabs 閹峰灝鍩岀搾濠勬櫕娑撳鐖ｆ导姘虫儰閸︺劎鈹栭惂浠嬨€夋稉濞库偓?
    //   閸忓彉闊╅悩鑸碘偓渚€鍣峰▽鈩冩箒"妞ょ數顒烽弫?鏉╂瑤閲滃鍌氬悍閿涘本澧嶆禒銉ユ躬鏉╂瑩鍣锋径閫涚濞嗏槄绱扮搾濠勬櫕閸楀啿娲栨＃鏍€夐妴?
    // 閳?2026-10-15閿涙哎鈧瞼骞囬崷銊ユ皑閸氼兙鈧秵褰冮崚鑸偓灞惧腹閼芥劑鈧秳绗岄妴灞芥礀閸濆秲鈧秳绠ｉ梻?閳?妞ょ數顒烽弫鏉垮綁 4閿涘奔绗傞悾?2 閳?3閵?
    //   閳跨媴绗?鏉╂瑤绔寸仦鍌涚梾閺堝宕熸稉鈧惇鐔哥爱閿涙碍褰?閸掔娀銆夌粵鎯х箑妞?*閸氬本妞?*閺€鐟版磽缂佸嫭瀵滄稉瀣垼閸欐牜娈戦崷鐗堟煙 閳ユ柡鈧?
    //     閳?鏉╂瑩鍣烽敍鍫ｇШ閻ｅ苯銇欓崣鏍︾瑐閻ｅ矉绱氶敍娑掓喗 `tabScrollTopCommands` 闂€鍨閿?
    //     閳?`tabBounceTriggers` 闂€鍨閿涙稈鎳€ `TabBarItem(i,閳?` 娑撳骸鎮囨い?`scrollTopCommand` 閻ㄥ嫪绗呴弽鍥モ偓?
    //   濠曞繋绔寸紒鍕皑閺?闁挎瑤缍?/ 娑撳秴鑴?/ 娑撳秴顦叉担?閵?
    if (this.tabState.tabIndex < 0 || this.tabState.tabIndex > 3) {
      Logger.warn(RzdShellLogTag, `tab index out of range (${this.tabState.tabIndex}), reset to 0`);
      this.tabState.tabIndex = 0;
    }
    this.ambientState.level = MusicStoreService.getInstance().getAmbientLevel();
    this.themeState.color = MusicStoreService.getInstance().getThemeColor();
    this.homeSourceState.source = MusicStoreService.getInstance().getHomeSource();
    this.miniLyricState.enabled = MusicStoreService.getInstance().getShowMiniLyric();
    AppStorage.setOrCreate('lxPlayQuality', MusicStoreService.getInstance().getPlayQuality());
    AppStorage.setOrCreate('lxPlaybackFlowLight', MusicStoreService.getInstance().getPlaybackFlowLight());
    // 閺堫剙婀撮棅鍏呯鎼存挷绗岄崥灞绢劄鐎广垺鍩涚粩顖氭躬閸氼垰濮╅弮璺哄灥婵瀵查敍姘拱閸︿即鐓舵稊鎰洣瀵ょ儤鐭欑粻杈╂窗瑜版洖鑻熸潪钘夊弳缁便垹绱╅敍?
    // 閸氬本顒炵€广垺鍩涚粩顖濐洣鐠囪娲栭張宥呭閸ｃ劌婀撮崸鈧稉搴＄磻閸忕绱欏鈧崗鍏呰礋閸忚櫕妞傛稉宥堢箾閺堝秴濮熺粩顖ょ礆閵?
    //
    // 閳跨媴绗?娑撱倓閲滈柈钘夊瘶 try/catch閿涙艾鐣犳禒?*娑撳秵妲?*閹绢厽鏂侀惃鍕缂冾喗娼禒璁圭礉娴ｅ棝鍏橀崷?`aboutToAppear` 闁插被鈧?
    //    娑撯偓閺冿箒绻栭柌灞惧閸戝搫骞撻敍瀹峚boutToAppear` 娴兼矮鑵戦弬顓ㄧ礉閸氬酣娼伴敍鍫滀簰閸欏﹤鐨㈤弶銉ュ閸︺劏绻栭柌宀€娈戦敍澶婂灥婵瀵?
    //    閸忋劏顫︾捄瀹犵箖 閳ユ柡鈧?闁絼绱扮悰銊у箛閹?閼绢偄鎮曢崗璺侯浘閺佺繝閲滈幘顓熸杹闁晫鏁ゆ稉宥勭啊"閿涘本甯撻弻銉ㄦ崳閺夈儵娼敮鍝ョ搏閵?
    const hostContext: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (hostContext !== undefined) {
      try {
        localMusic.init(hostContext);
      } catch (err) {
        const e = err as BusinessError;
        Logger.error('RzdShell', `localMusic init failed code=${e.code} msg=${e.message}`);
      }
      try {
        syncManager.init(hostContext);
      } catch (err) {
        const e = err as BusinessError;
        Logger.error('RzdShell', `syncManager init failed code=${e.code} msg=${e.message}`);
      }
    }
    // 鐠囧嫯顔戦棃銏℃緲鐟曚浇鍏樻径鍕倞閺堫剙婀撮棅鍏呯閿涙碍濡搁妴灞炬拱閸︾増鐡?-> 楠炲啿褰撮煬顐″敜閵嗗秶娈戠憴锝嗙€芥禍銈囩舶 comment
    // 閿涘潏omment / player 闁垝绗夐懗钘夊冀閸氭垳绶风挧?localmusic閿涘本澧嶆禒銉ㄧ箹娑擃亝妲х亸鍕涧閼崇晫鏁辨竟鍐茬湴閹风》绱氶妴?
    setCommentTargetResolver((song: CommentSongRef): Promise<CommentSongRef | null> => {
      return Promise.resolve(this.resolveCommentTarget(song));
    });
    this.syncViewportWidthVp();
    // 鈽呪槄鈽?2026-10-17锛堚懁銆岀偣鍑绘墦寮€鑳屾櫙浠嶅涓嶄笂銆嶇殑绗竴鏉★級锛歚@Monitor` 鍙湪**鍙樺寲**鏃惰Е鍙戙€?
    //   鍐峰惎鍔ㄨ繖涓€鎷嶏細`playQueueIds` 鍒氫粠搴撻噷璇诲洖锛堜笂闈㈢ 2 琛岋級銆乣selectIndex` 杩樻槸 0锛?
    //   鑻ユ寔涔呭寲鎭㈠鍑烘潵鐨?selectIndex 鎭板ソ涔熸槸 0锛屽垯**娌℃湁浠讳綍鍙樺寲浜嬩欢** 鈬?棰勭儹涓€娆￠兘娌¤窇杩?
    //   鈬?鎾斁椤?`adoptWarmMesh()` 姘歌繙姣斿涓嶄笂 鈬?鐢ㄦ埛鐪嬪埌鐨勫氨鏄厹搴曠綉鏍硷紙鍒殑姝岀殑棰滆壊锛夈€?
    //   鈬?杩欓噷鏄惧紡琛ヤ竴娆★紙骞傜瓑锛歚MeshWarmService` 鍐呴儴鏈?in-flight / done 鍘婚噸锛夈€?
    prewarmCurrentSongMesh(this.getUIContext(), this.appState.getCurrentSongItem());
  }

  /**
   * 閺堫剙婀撮棅鍏呯 -> 楠炲啿褰撮煬顐″敜閿涘牐鐦庣拋娲桨閺夊灝鍞撮柈銊ょ窗鐠嬪啰鏁ら敍澶堚偓?
   *
   * 閺堫剙婀村灞藉涧鐎涙ü绨￠張顒€婀?key閿涘矁顩﹂崣鏍槑鐠佸搫绶遍崗鍫㈢叀闁挸鐣犻崠褰掑帳閸掓澘閽╅崣棰佺瑐閻ㄥ嫬鎽㈡稉鈧＃鏍电窗
   * 閻?`localMusic.matchOf` 鐠囪灏柊宥堫唶瑜版洩绱欓懛顏勫З閸栧綊鍘ら幋鎰閹存牜鏁ら幋宄版躬閵嗗苯灏柊宥嗙摃鐠囧秲鈧秹鍣烽幍瀣偓澶屾畱闁絾娼敍澶堚偓?
   * 濞屸剝婀佺拋鏉跨秿鐏忚精绻戦崶?null閿涘矁鐦庣拋娲桨閺夊じ绱伴幓鎰仛閵嗗矁绻栨＃鏍ㄧ摃鏉╂ɑ鐥呴崠褰掑帳閸掓澘閽╅崣棰佺瑐閻ㄥ嫮澧楅張顑锯偓宥冣偓?
   *
   * @param song 鐠囧嫯顔戦棃銏℃緲缂佹瑧娈戝灞炬锤闊偂鍞ら敍鍫熸拱閸︾増鐡曢惃?songId 鐏忚鲸妲搁張顒€婀?key閿涘鈧?
   * @returns 楠炲啿褰撮煬顐″敜閿涘本鍨?null閵?
   */
  private resolveCommentTarget(song: CommentSongRef): CommentSongRef | null {
    const matched: MatchSongInfo | null = localMusic.matchOf(song.songId);
    if (matched === null) {
      return null;
    }
    const ref: CommentSongRef = {
      source: matched.source,
      songId: matched.songId,
      name: matched.name.length > 0 ? matched.name : song.name,
      singer: matched.singer.length > 0 ? matched.singer : song.singer
    };
    return ref;
  }

  /**
   * 鐠佹澘缍嶇粣妤€褰涚€硅棄瀹抽敍鍧磒閿涘绱濇笟娑欏亾濞搭喛绯犳担鐘虫蒋缁犳顔旀惔锔衡偓?
   *
   * 閸欘亜婀潻娆撳櫡缁犳ぞ绔村▎掳鈧礁鑻熼崷?`onAreaChange` 闁插苯鍩涢弬甯窗閹剚璇為弶鈩冩Ц閸欑姴婀い鐢告桨娑撳﹦娈戦悪顒傜彌閼哄倻鍋ｉ敍?
   * 閻╁瓨甯寸拠?`windowInfo.windowSize`閿涘潷x閿涘婀?build 闁插本宕茬粻妞剧窗鐢箒绻樻稉鈧稉顏冪瑝缁嬪啿鐣鹃惃鍕贩鐠ф牓鈧?
   * @returns 鐎硅棄瀹抽敍鍧磒閿涘鈧?
   */
  private syncViewportWidthVp(): void {
    const px: number = this.windowInfo.windowSize.width;
    if (px <= 0) {
      return;
    }
    const vp: number = this.getUIContext().px2vp(px);
    if (Math.abs(vp - this.viewportWidthVp) > 1) {
      this.viewportWidthVp = vp;
    }
    // 妤傛ê瀹虫稉鈧挧宄板煕閿涘牆鎮撴稉鈧禒?windowSize閿涘奔绗夋径姘冲С娴狅絼鐜敍?
    const hPx: number = this.windowInfo.windowSize.height;
    if (hPx > 0) {
      const hVp: number = this.getUIContext().px2vp(hPx);
      if (Math.abs(hVp - this.viewportHeightVp) > 1) {
        this.viewportHeightVp = hVp;
      }
    }
  }

  /** Dispatches playback shell intent when {@link PlaybackIntentState.requestVersion} changes. */
  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged() {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      // 閻╁瓨甯撮幐鍌濇崳閹绢厽鏂佹い闈涘祮閸欘垽绱扮仦鏇炵磻閸斻劎鏁鹃悽杈ㄦ尡閺€楣冦€夐懛顏勭箒閹绢叏绱欑憴?playExpandIntro / morphScaleValue閿涘鈧?
      this.appState.isShowPlay = true;
    });
  }

  /**
   * 闁款喚娲忛柆鑳唨鐠囧﹥鏌囬敍姘宠拫闁款喚娲忓鐟板毉 / 閺€鎯版崳閺冭埖澧︽稉鈧悰宀嬬礄`hdc shell hilog | grep RzdKeyboardAvoid`閿涘鈧?
   *
   * 閳跨媴绗?**娑撳秷顩﹂崷銊ワ紦鐏炲倸鍟€閹稿倷绔存禒鐣岀崶閸欙絿娲冮崥?*閿涙瓪TYPE_KEYBOARD` 閻ㄥ嫰浼╃拋鈺佸隘閻?
   * `common/musicbasic` 閻?`WindowUtil.updateWindowInfo()` 缂佺喍绔撮惄鎴濇儔閿涘牆鍙忔潻娑氣柤閸烆垯绔存稉鈧径鍕剁礆閿?
   * 鏉╂瑩鍣烽崣顏呮Ц**鐠?*鐎瑰啫鍟撴潻?`WindowInfo.avoidKeyboard`閿涘潉@Trace`閿涘娈戠紒鎾寸亯 閳ユ柡鈧?
   * 鐠?`@Trace` 鐏炵偞鈧勬＆閼充粙鈹嶉崝銊︽拱閺夆剝鍋撳ù顔芥蒋閻ㄥ嫰鍣搁弬鏉跨鐏炩偓閿涘奔绡冨锝呫偨閺勵垵绻栨稉顏囩槚閺傤厽鏌囬悙骞库偓?
   */
  @Monitor('windowInfo.avoidKeyboard')
  onKeyboardAvoidAreaChanged(): void {
    // 鈽呪槄鈽?2026-10-18锛氶敭鐩樻€佷袱琛岃处锛坄hdc shell hilog | grep RzdKeyboardAvoid`锛?
    //   鈶?`RzdKeyboardAvoid calc`    = 绠楀紡鍙ｅ緞锛欿 / I / margin / 鐩爣绌虹櫧 / 瀹夸富浣嶇Щ锛堟亽 0锛?
    //   鈶?`RzdKeyboardAvoid measure` = 涓€甯у悗**瀹炴祴**鐪熻韩钀界偣锛氶敭鐩樹笂娌?鈭?鏉″簳 = 鐪熷疄绌虹櫧銆?
    //      鑻?ArkUI 榛樿 `KeyboardAvoidMode.OFFSET`锛圫DK `@ohos.arkui.UIContext.d.ts:4389`
    //      鍘熸枃銆孌efault mode: KeyboardAvoidMode.OFFSET銆嶏級鎶婃暣椤典篃骞崇Щ浜嗭紝
    //      `hostBottom` 浼氳窡鐫€寰€涓婅窇锛宍gap` 浼氭槑鏄惧ぇ浜?`keyGap` 鈬?閭ｅ氨鏄弻鎶紝瑕佹寜绗洓鏉″缃€?
    const keyboardVp: number = this.keyboardBottomVp();
    Logger.info('RzdKeyboardAvoid',
      `RzdKeyboardAvoid calc keyboardVp=${keyboardVp} pageBottomInset=${this.pageBottomInsetVp()} ` +
        `barBottomMargin=${this.floatingMiniBarBottomMarginVp()} lift=${this.floatingMiniBarKeyboardLiftVp()} ` +
        `hostOffset=${this.floatingMiniBarHostOffsetYVp()} restGap=${FLOATING_MINI_BAR_BOTTOM_GAP_VP} ` +
        `keyGap=${FLOATING_MINI_BAR_KEYBOARD_GAP_VP} windowH=${this.viewportHeightVp}`);
    if (keyboardVp > 0) {
      // 绛?HDS 鎶婅兌鍥婃寜鏂?margin 鎽嗗畬鍐嶉噺锛堜袱甯ч噺绾э紱鍙噺涓€娆★紝涓嶈繘甯冨眬閾撅級銆?
      setTimeout((): void => {
        this.logKeyboardBarGap(keyboardVp);
      }, 96);
    }
  }

  /**
   * 椤电洅搴曠浉瀵?*绐楀彛搴?*鐨勫唴缂╋紙vp锛夈€?
   *
   * 鏈粨鏃㈡湁鍙ｅ緞锛坄Index.ets` 椤堕儴閭ｆ鍑犱綍璁板綍宸蹭袱澶勭‘璁わ級锛氭牴 `Stack` 娌℃湁 `ignoreLayoutSafeArea`
   * 鈬?瀹冪殑搴曡竟 = 椤电洅搴?= 绐楀彛搴?鈭?绯荤粺閬胯銆傝蛋 `getNavigationBarBottomVpFromWindowUtil()` 鑰屼笉鏄?
   * 鐩存帴璇诲瓧娈碉細瀹冭嚜甯︺€岀紦瀛?鈫?鐜伴噺 鈫?鏈€鍚庝竴娆″ソ鍊?鈫?鍚姩蹇収銆嶅洓绾у厹搴曪紝涓嶄細杩斿洖闄堟棫鐨?0銆?
   * @returns 绯荤粺瀵艰埅鏉?/ 灏忕櫧鏉￠珮搴︼紙vp锛夈€?
   */
  private pageBottomInsetVp(): number {
    return getNavigationBarBottomVpFromWindowUtil();
  }

  /**
   * 涓€娆℃€ц瘖鏂細閲忋€岃糠浣犳潯鐪熻韩銆嶄笌銆屽涓荤洅銆嶇殑绐楀彛鐭╁舰锛岀畻鍑?*鏉″簳鍒伴敭鐩樹笂娌跨殑鐪熷疄绌虹櫧**銆?
   *
   * 鍙ｅ緞鐢?`getComponentUtils().getRectangleById`锛堣繑鍥?*娓叉煋鍚?*绐楀彛鐭╁舰銆佸崟浣?px锛?
   * 涓?`PlayerExpandState.measureNode` 鍚屼竴濂楀彇鏁板彛寰勶級锛屽啀 `px2vp` 鎹㈡垚 vp銆?
   * 鍒よ锛坓rep `RzdKeyboardAvoid measure`锛夛細
   *   路 `gap` 鈮?`expectGap`(10) 鈬?鍒颁綅锛?
   *     `gap` 鏄庢樉**灏?* 鈬?鎶皯锛堥敭鐩樺挰鏉★級锛涙槑鏄?*澶?* 鈬?杩樻湁绗簩鏉℃姮鍗囧湪鍙犲姞锛?
   *   路 `hostBottom` 搴旀亽绛変簬 `windowH 鈭?pageBottomInset`銆傚畠鑻ヨ窡鐫€閿洏寰€涓婅窇锛屽氨鏄?ArkUI 鐨?
   *     `KeyboardAvoidMode.OFFSET` 鎶婃暣椤靛钩绉讳簡 鈬?搴旀妸鎵嬪姩鎶崌鍏虫帀锛坄barBottomMargin` 鍥炲父鎬侊級锛?
   *     鑰屼笉鏄啀鍔?offset 鈥斺€?閭ｆ墠鏄?鏁翠釜搴曚笅閮借鎶笂鏉?鐨勬牴銆?
   * @param keyboardVp 鏈閿洏楂橈紙vp锛夛紝鐢?{@link onKeyboardAvoidAreaChanged} 浼犲叆
   */
  private logKeyboardBarGap(keyboardVp: number): void {
    const windowHVp: number = this.viewportHeightVp;
    const barBottomVp: number = this.measureNodeBottomToWindowVp(MINI_BAR_ID);
    const hostBottomVp: number = this.measureNodeBottomToWindowVp(SECONDARY_MINI_BAR_HOST_ID);
    const keyboardTopVp: number = windowHVp > 0 ? windowHVp - keyboardVp : -1;
    const gapVp: number = (keyboardTopVp > 0 && barBottomVp > 0) ? keyboardTopVp - barBottomVp : -1;
    Logger.info('RzdKeyboardAvoid',
      `RzdKeyboardAvoid measure keyboardVp=${keyboardVp} windowH=${windowHVp} keyboardTop=${keyboardTopVp} ` +
        `barBottom=${barBottomVp} hostBottom=${hostBottomVp} gap=${gapVp} ` +
        `expectGap=${FLOATING_MINI_BAR_KEYBOARD_GAP_VP} pageBottomInset=${this.pageBottomInsetVp()} ` +
        `barBottomMargin=${this.floatingMiniBarBottomMarginVp()}`);
  }

  /**
   * 閲忔煇鑺傜偣**搴曡竟鐨勭獥鍙ｅ潗鏍?*锛坴p锛夛紱閲忎笉鍒拌繑鍥?-1锛堟棩蹇楅噷涓€鐪煎彲瑙侊紝涓嶅繀鐚滐級銆?
   * @param id 鑺傜偣涓婄殑 `.id(...)` 鍊?
   * @returns 搴曡竟 y锛坴p锛夛紝鎴?-1
   */
  private measureNodeBottomToWindowVp(id: string): number {
    try {
      const rect = this.getUIContext().getComponentUtils().getRectangleById(id);
      const bottomPx: number = rect.windowOffset.y + rect.size.height;
      return this.getUIContext().px2vp(bottomPx);
    } catch (error) {
      return -1;
    }
  }

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 閹绢厽鏂佹い闈涘弳閸欙綇绱癭isShowPlay` 閳?NavDestination 閹恒劌鍙?/ 瀵懓鍤?閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
  //
  // 閳?閺傝棄浼愰崶鍓ь儑 1 濮濄儳娈戦崑姘《閿?*娑撳秹鈧劒閲滈弨纭呯殶閻劎鍋?*閵?
  //   瀹搞儳鈻奸柌?閹垫挸绱戦幘顓熸杹妞?閻ㄥ嫬鍟撳▔鏇熸箒娴滄柨鍙氭径鍕剁礄鏉╄渹缍橀弶锛勫仯閸戞眹鈧焦鎸遍弨鐐壈閸ヤ勘鈧浇鎹ｉ幘顓熷壈閸ヤ勘鈧椒绗傞幏澶嬫緱閹靛鈧讣绱氶敍?
  //   "閸忔娊妫?娑旂喐婀佹稉澶婎槱閿涘牊鎸遍弨楣冦€夋潻鏂挎礀閹稿鎸抽妴浣风瑓閹峰鏁圭挧宄扮暚閹存劑鈧竼ontrolArea閿涘绱?
  //   娑撳骸鍙鹃柅鎰嚋閺囨寧宕查幋?push/pop閿涘牊绱℃稉鈧稉顏勬皑閺?閺堝娈戦崗銉ュ經鏉╂ɑ妲搁弮褍濮╅悽?閿涘绱濇稉宥咁洤閸︺劌锛撶仦鍌涘Ω
  //   `MusicAppState.isShowPlay` 鏉╂瑤閲?*閺冦垺婀侀崬顖欑閻喐绨?*缂堟槒鐦ч幋鎰熅閻㈠崬濮╂担婊愮窗
  //       isShowPlay: false 閳?true   閳?閹恒劌鍙嗛幘顓熸杹妞や絻鐭鹃悽?
  //       isShowPlay: true  閳?false  閳?瀵懓鍤幘顓熸杹妞や絻鐭鹃悽?
  //   閺冦垺婀佺拫鍐暏閻愰€涚鐞涘矂鍏樻稉宥囨暏閺€鐧哥礉閺傛澘顤冮崗銉ュ經娑旂喕鍤滈崝銊洬閻╂牓鈧?

  /** 閹绢厽鏂佹い鍨瘯鏉?閸楁瓕娴囬惃鍕暜娑撯偓閺€璺哄經閿涘牊澧嶉張?`isShowPlay` 閸愭瑥鍙嗛張鈧紒鍫ュ厴娴兼俺铔嬮崚鎷岀箹闁插矉绱氶妴?*/
  /**
   * 鍙屽眰搴曟爮銆屾敹璧?/ 灞曞紑銆嶇殑**椹卞姩钀界偣鏃ュ織**锛坄hdc shell hilog | grep RzdHomeBarLayout`锛夈€?
   *
   * 鈽呪槄鈽?2026-10-21锛堢鍏疆锛夛細椹卞姩鏂逛笌钀界偣**閮藉洖鍒?HDS**锛堜笂涓€杞偅濂?鑷繁绠楄兌鍥婂/绂诲簳/鍗曞眰"
   * 鐨勬淳鐢熼噺宸查殢 `homeMiniCapsule()` 涓€璧峰垹闄わ紝鏈嚱鏁板彧浣?*瑙傛祴鐐?*锛夈€?
   *
   * 閾捐矾锛歚BarScrollHelper.notifyScrollDelta` 鍐?`MusicAppState.hdsBarLayoutMode` / `miniBarExpanded`
   * 锛堝垪琛ㄤ笂婊?= 鍗曞眰 `HORIZONTAL`銆佷笅婊?= 鍙屽眰 `VERTICAL`锛?00ms `springMotion` 琛ラ棿锛?
   * 鈬?{@link barLayoutModeForHds} / {@link miniBarStyleForHds} 鈬?澹冲眰 `HdsTabs` 鐨?
   * `barFloatingStyle.miniBar.{barLayoutMode, miniBarStyle}`锛堜袱涓瓧娈典粛鍦紝瑙?{@link miniBar} 鐨勫涓伙級銆?
   * 鍒ゆ嵁涓€鏉★細`singleRow=true`锛? HORIZONTAL锛夋椂 HDS 浼氭妸**椤电鏀舵垚宸︿晶鍦嗗潪**銆佹妸闀挎潯浣嶈缁欒糠浣犳爮锛?
   * 杩蜂綘鏍忎笌椤电鍚屾帓锛沗false` 鏃舵槸涓婁笅涓ゆ帓 鈥斺€?涓や晶閮戒互 `RzdMiniBarGeom content h=` 閭ｈ鐨?
   * `h == cap == 56` 涓哄噯锛堜袱鏉¤矾寰勭殑鍙楂樺害閮芥槸 `FLOATING_MINI_BAR_HEIGHT_VP`锛夈€?
   */
  @Monitor('appState.hdsBarLayoutMode', 'appState.miniBarExpanded')
  onHomeBarLayoutChanged(): void {
    Logger.info('RzdHomeBarLayout',
      `layout=${this.appState.hdsBarLayoutMode} expanded=${this.appState.miniBarExpanded} ` +
        `hdsLayout=${this.barLayoutModeForHds()} hdsStyle=${this.miniBarStyleForHds()} ` +
        `singleRow=${this.barLayoutModeForHds() === HdsBarLayoutMode.HORIZONTAL} ` +
        `cap=${FLOATING_MINI_BAR_HEIGHT_VP} fullW=${this.floatingMiniBarWidthVp()} ` +
        `tabIndex=${this.tabState.tabIndex} navDepth=${this.navDepth} ` +
        `squashY=${this.expandState.morphSquashY}`);
  }

  @Monitor('appState.isShowPlay')
  onShowPlayChanged(): void {
    if (!PLAYER_ROUTE_MODE) {
      Logger.info('RzdPlayerRoute', `overlay visible=${this.appState.isShowPlay} retainedPaths=${JSON.stringify(this.pageIndexInfos.getAllPathName())}`);
      return;
    }
    if (this.appState.isShowPlay) {
      // 閳藉應妲勯埥?2026-10-16閿?*閸忔娊妫存潻鍥┾柤姒涙垵灏堢€?璺?閸烆垯绔撮懗鍊燁唶 `OPN` 閻ㄥ嫬婀撮弬鐟版皑閺勵垵绻栭柌?*閿涘绱?
      //   閻劍鍩涢幎銉ф畱閵嗗苯鍙ч梻顓炴倵閸欏牏鐛婇悞鑸垫杹娑撯偓闁秴鐫嶅鈧妴宥佲偓鏂衡偓?婢舵潙褰跨€氬瞼鏋掗弰?*婢瑰啿鐪伴幎濠冩尡閺€楣冦€夐崣鍫熷腹娴滃棔绔村▎?*
      //   閿涘潉isShowPlay` 閸︺劌鍙ч梻顓⑩偓鏂捐厬鐞氼偉鐨濋崘娆忔礀 true 閳?閺?`@Monitor` 閺€璺哄煂 false閳姲rue
      //   閳?`beginOpenMorphOnClick()` + `pushPlayerRoute()` 閳?閺傛澘鐤勬笟瀣ㄢ偓浣规煀鐏炴洖绱戦崝銊ф暰閿涘鈧?
      //   鏉╂瑤绔寸粭?*閸欘亝婀佹竟鍐茬湴閼冲€燁唶**閿涘牊鎸遍弨楣冦€夐柇锝勭閸掕鍑＄紒?pop 娴滃棴绱氶敍灞惧娴犮儰绨ㄦ禒鑸垫）韫囨浠涢幋鎰啊 public static
      //   閿涘牐顫?`PlaybackPage.evLog` 閻ㄥ嫯顕╅弰搴礆閵嗗倽顕板▔鏇☆潌閼奉亣鐦夊鑺ョ垼缁楊剙宕勬稉澶庮攽閿涙碍顒滅敮绋垮彠闂傤厼鎮楅柌宥嗘煀閹垫挸绱戦敍?
      //   閺冦儱绻旈柌?*閸欘亜绨查張澶夌閺?`OPN`**閿涙稖瀚㈤崗鎶芥４濞堝吀绠ｉ崥搴ｆ彛鐠虹喍绔撮弶?`OPN` 閼板瞼鏁ら幋宄拌嫙濞屸剝婀侀悙鐟扮磻 閳?鐏忚鲸妲哥€瑰啨鈧?
      PlaybackPage.ev('OPN', `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
      // 閳藉應妲?2026-10-15閿涘牏鍙庨幖顒佹￥閻ｅ矉绱氶敍?*閻愮懓鍤幍鎾崇磻娑旂喎绻€妞ゆ槒铔嬭ぐ銏犲綁**閵?
      //   閺冪姷鏅柌灞烩偓宀€鍋ｉ崙缁樻尡閺€鐐蒋閵嗗秴鎷伴妴灞肩瑐濠婃垶澧滈崝瑁も偓?*閸忚京鏁ら崥灞肩娑?`beginMorphEnter`**
      //   閿涘牆鍙忛崠鍛涧閺?`openPlayerMorph` 娑?`pullStart` 娑撱倓閲滅拫鍐暏閼板拑绱濈憴?
      //   `_recover/logic-src/閻愮懓鍤幍鎾崇磻閹绢厽鏂侀崳銊ヨ埌閸欐﹢鎽肩捄?md` 鎼傛稉鈧敍澶堚偓鍌涱劃閸撳秷绻栭柌灞藉涧閹恒劏鐭鹃悽渚库偓?
      //   娑撳秴鎯庨崝銊ヨ埌閸?閳?閻愮懓鍤挧鎵畱閺勵垱鎸遍弨楣冦€夐柌宀勫亝婵?*濞查箖鐓堕懛顏呮尡**閿涘潉collapseProgress`閿涘绱?
      //   娑撳簼绗傚鎴犳畱婢瑰啿鐪拌ぐ銏犲綁閺勵垯琚遍弶鈥茬鞍娑撳秶娴夐獮鑼畱閸斻劎鏁?閳ユ柡鈧?閻劍鍩涚€圭偞绁撮妴宀€鍋ｉ崙缁樺ⅵ瀵偓閹绢厽鏂侀崳銊︾梾閺堝濮╅悽姹団偓?
      //   閵嗗矁鍎楅弲顖欑瑝鐎靛箍鈧秴姘ㄩ弰顖氱暊閵嗗倿銆庢惔蹇擃嚠姒绘劖妫ら悾宀嬬窗閳?闁插繑绨獮鎯扮箻閻╅晲缍?閳?閳?閹恒劏鐭鹃悽杈ㄥ瘯鏉?
      //   閳?閳?闁插繒绮撻悙鐧哥礄`onPullReady` 缁涘鐜悧鈺嬬礆閳?閳?閺€璺虹啲鐞涖儵妫?`commitPull()` 缁涘鐜悧鈹库偓?
      // 鈽呪槄鈽?2026-10-17锛堢敤鎴峰疄娴嬨€岀偣鍑绘墦寮€鎾斁椤垫椂鑳屾櫙鏄埆鐨勬瓕鐨勯鑹层€嶏級锛?
      //   褰㈠彉鍙湁 350~400ms锛岃€屽湪绾挎瓕鐨?64脳64 缃戞牸瑕佷笅杞?+ 瑙ｇ爜锛?00~2000ms锛夆噿
      //   鍦?*鍚姩褰㈠彉涔嬪墠**鍐嶈涪涓€娆￠鐑紙鏇茬洰鍙樺寲鏃朵篃韪紝瑙?onCurrentTrackForMeshPrewarm锛夈€?
      //   棰勭儹鏄?鍚屾杩斿洖銆佸紓姝ュ共娲?锛岃繖閲屼笉浼氳瀹冩嫋浣忛甯с€?
      prewarmCurrentSongMesh(this.getUIContext(), this.appState.getCurrentSongItem());
      const morphStarted: boolean = this.beginOpenMorphOnClick();
      this.pushPlayerRoute();
      if (morphStarted) {
        // 閳藉應妲勯埥?2026-10-16閿?*閻愮懓鍤幍鎾崇磻濞屸剝婀佺亸渚€娼伴崝銊ф暰**閻ㄥ嫭娓堕崥搴濈閸ф瀚鹃崶鎾呯礆閿?
        //   閺勬儳绱￠幎濞库偓灞捐癁鐏炲倿鍋呮稉鈧Λ鎺嬧偓宥忕礄婢瑰啿鐪?`MorphCoverClone` = 缂侇參顥ｇ亸渚€娼伴敍澶庢崳鐠ч攱娼甸敍?
        //   **娑撳秴鍟€閸欘亙绶风挧?* `@Monitor('expandState.morphDrive')`閵?
        //
        // ## 娑撹桨绮堟稊鍫濈箑妞ょ粯妯夊?
        //
        // 鐏忎線娼伴柇锝勭濡帗婀?*娑撱倖娼悪顒傜彌閻ㄥ嫯绻樻惔?*閿?
        //   璺?閹绢厽鏂佹い鐢稿亝鐏炲偊绱檂morphP`閿涘鈧柡鈧?鐎圭懓娅?scale/translate/clip閿?*閼冲本娅欐稊鐔锋躬闁插矂娼?*閿?
        //   璺?濞搭喖鐪伴柇锝呯湴閿涘潉morphOverlayP`閿涘鈧柡鈧?婢瑰啿鐪伴惃鍕敾妞嬬偛鐨濋棃顫礉**鐏忎線娼扮亸閬嶆浆鐎瑰啴顥?*閵?
        // 娑撱倖娼す鍗炲З鐠侯垰绶為敍?
        //   璺?閹靛瀵氱捄鐔稿閿涙瓪onPullOpenUpdate` 閳?`syncMorphOverlayFromPage()`閿?*娑撯偓濮ｆ柧绔撮崥灞绢劄**閿涘婀?
        //   璺?閻愮懓鍤?閺夌偓澧滈敍姝歴ettlePullOpen` 閳?`morphOverlayTweenTo()`閿?
        //     娴犮儱寮?`@Monitor('expandState.morphDrive')` 閳?`focusMorphOverlayForPageIntro()`閵?
        // 閳跨媴绗?閸氬氦鈧懏妲?**V2 瀵倹顒為崶鐐剁殶**閿涘矁鈧?`focusMorphOverlayForPageIntro()` 闁插本婀佹稉銈変壕**闂堟瑩绮?return**
        //   閿涘潉morphDrive !== MorphDrive.ANIM` / `!morphContainerActive()`閿涘鈧柡鈧?鐎?*娑撳秴鍟撻弮銉ョ箶**閿?
        //   娑撯偓閺冿箓鍋呮稉鈧崚鑽ゆ祲娴ｅ秷绻曞▽鈥虫皑娴ｅ稄绱濇潻娆庣濡帒姘?*閺佸瓨顔屾稉宥嗘尡閵嗕浇鈧奔绗栭弻銉ょ瑝閸戠儤娼?*閵?
        //   閻劍鍩涚€圭偞绁撮妴?*閻愮懓鍤幘顓熸杹閺夆剝澧﹀鈧幘顓熸杹閸?/ 閻愮懓鍤崗鎶芥４ / 缁崵绮烘潻鏂挎礀閸忔娊妫撮柈鑺ョ梾閺堝鐨濋棃銏犲З閻?*閵?
        //   閼板被鈧奔绗傞幏澶嬪ⅵ瀵偓濮濓絽鐖堕妴宥忕礉瀹割喖绱撳锝嗘Ц"鐠虹喐澧滈柇锝嗘蒋閸氬本顒炵捄顖濊泲闁矮绨￠妴渚€娼幍瀣◢鏉╂瑦娼捄顖涚梾鐠т即鈧?閵?
        //
        // 閳?鏉╂瑩鍣烽崷?*閹恒劏鐭鹃悽鍙樼閸氬簺鈧胶娴夋担宥呭嚒鐏忓彉缍?*閻ㄥ嫪缍呯純顔芥▔瀵繐鏋堟稉鈧竟?
        //   閿涘牅绗?`PlaybackPage.closeFullScreenPlayback()` 闁?閸氬本顒炴す鍗炲З濞搭喖鐪?闁絾娼?*閸氬本顑欓崑姘《**閿?
        //     鐟欎線鍋呮潏?2358-2370 鐞涘瞼娈戦梹鎸庢暈闁?閳ユ柡鈧?鐎瑰啫缍嬮弮鏈垫叏閻ㄥ嫭顒滈弰?閸忔娊妫村▽鈩冩箒鐏忎線娼伴崝銊ф暰"閿涘鈧?
        //   閳跨媴绗?楠炲倻鐡戦敍姝歠ocusMorphOverlayForPageIntro()` 閻ㄥ嫪琚遍柆鎾崇暓閸?+ `morphOverlayTweenTo()`
        //     閻?鐠ч鍋?=缂佸牏鍋ｉ惄瀛樺复鏉╂柨娲? / `morphOverlayAnimating` 娑撳秵濮?閳?闁插秴顦茬拫鍐暏鐎瑰鍙忛妴?
        this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
        this.schedulePullAnchorRemeasure(0);
        // 鐎瑰啳鍤滅敮?濠ф劕鍤戞担鏇＄箷濞岋繝鍣烘鎰皑 32ms 闁插秷鐦?闁絾娼粣妤€褰涢敍宀€鐡戞禒铚傜艾閺冪姷鏅惃?`ExpandSnapshot.onPullReady`閵?
        this.settlePullOpen(true);
      }
    } else {
      this.popPlayerRoute();
    }
  }

  /**
   * 鈽呪槄鈽?2026-10-17锛堢敤鎴峰疄娴嬨€岀偣鍑绘墦寮€鎾斁椤垫椂鑳屾櫙鏄埆鐨勬瓕鐨勯鑹?/ 瀵逛笉涓娿€嶏級锛?
   * **褰撳墠鏇茬洰涓€鍙樺氨棰勭儹 64脳64 缃戞牸婧?*锛堢粨鏋滃瓨 `MeshWarmState`锛屾挱鏀鹃〉 `onAppear` 鐩存帴閲囩敤锛夈€?
   *
   * 涓轰粈涔堟斁鍦ㄥ３灞傦細澹冲眰鏄敮涓€"鏇茬洰鍒囨崲涓€瀹氫細璧板埌"鐨勫湴鏂癸紱鎾斁椤靛湪褰㈠彉寮€濮嬪墠鎵嶆寕杞斤紝
   * 閭ｆ椂宸茬粡鏉ヤ笉鍙婁笅杞戒簡銆傞鐑け璐ュ彧璁版棩蹇楋紝涓嶅奖鍝嶆挱鏀俱€?
   */
  @Monitor('appState.selectIndex', 'appState.playQueueIds')
  onCurrentTrackForMeshPrewarm(): void {
    prewarmCurrentSongMesh(this.getUIContext(), this.appState.getCurrentSongItem());
  }

  /**
   * 閻愮懓鍤幍鎾崇磻閿?*闂堢偞澧滈崝鍨弳閸?*閿涘娈戣ぐ銏犲綁閸氼垰濮?閳ユ柡鈧?鐎佃鐖ｉ弮鐘垫櫕 `MainPage.openPlayerMorph(src)`閵?
   *
   * 閺冪姷鏅惃鍕斧閺傚浄绱檂閻愮懓鍤幍鎾崇磻閹绢厽鏂侀崳銊ヨ埌閸欐﹢鎽肩捄?md` 鎼傛稉鈧?+ 閸楃兘顩婚弴瀛橆劀閿涘绱?
   * ```ts
   * openPlayerMorph(src?) {
   *   const s = src ?? this.ownMorphSource;
   *   if (!this.beginMorphEnter(s)) { this.enterAnimStarted = false;
   *                                   this.nav.pushPath({ name: R_PLAYER }); return; }  // 闁偓閸栨牭绱伴弮鐘茶埌閸?
   *   // beginMorphEnter 閸愬懘鍎村鑼病 pushPath({name, param:{pull:true}}, animated=false)
   *   ExpandSnapshot.onPullReady = 浣?      // 鐏忚京鍗?閳?commitPull() 閳?animateMorphT(400, t=1)
   * }
   * ```
   * 閺堫剚鏌熷▔鏇炲涧閸嬫埃鎲奸妴宀勫櫤濠ф劕鑻熸潻娑氭祲娴ｅ秲鈧秷绻栨稉鈧崡濠忕幢閳垛剝甯圭捄顖滄暠閸︺劏鐨熼悽銊у仯缁毖嗙閸忚泛鎮楅敍灞告喛閳讹絼绡冮悽杈殶閻劎鍋ｉ崣鎴ｆ崳
   * 閿涘牆娲滄稉?`pushPath` 閺勵垰锛撶仦鍌滄畱缁変焦婀侀崝銊ょ稊閿涘奔绗夐懗鍊燁唨閺堫剚鏌熷▔鏇炲冀鐠嬪喛绱氶妴鍌濈箹閺嶉鍋ｉ崙璁崇瑢娑撳﹥绮?
   * **閸忚京鏁ら崥灞肩娴犺棄鍤戞担鏇樷偓浣告倱娑撯偓娑擃亞娴夋担宥冣偓浣告倱娑撯偓閺夆剝鏁圭亸鎹愃夐梻?*閿涘苯鐫嗘稉濠傚涧閸欘垵鍏橀張澶夌娑擃亜濮╅悽璁冲瘜閵?
   *
   * 閳跨媴绗?娑撳娼€瑰牆宕奸敍宀€宸辨稉鈧弶鈥虫皑娴兼艾鎷伴幍瀣◢閹存牕鍑￠張澶夌窗鐠囨繃澧﹂弸璁圭礄濮ｅ繋绔撮弶锟犲厴閺堝鐤勫ù瀣╃贩閹诡噯绱氶敍?
   *   璺?`pullDragging` 閳ユ柡鈧?閹靛瀵氬锝呮躬妞瑰崬濮╅敍鍧刼nPullOpenStart` 闁絾娼捄顖ょ礆閿涘矁顔€缂佹瑥鐣犻敍宀冪殱娑旂喎鍩嗛幎顫幢
   *   璺?`morphContainerActive()` 閳ユ柡鈧?瀹歌尙绮￠崷銊ょ娑擃亜鑸伴崣妯圭窗鐠囨繈鍣烽敍鍫滅瑐濠婃垿鍋呴弶陇鐭鹃崷?
   *     `onPullOpenStart` 闁插苯鍑＄紒?`pullOpenBegin` 鏉╁浄绱濇稉?`isShowPlay` 娑旂喐妲哥€瑰啰鐤嗛惃鍕剁礆
   *     閳?閸?begin 娑撯偓濞嗏€茬窗閹跺﹤鍨伴柌蹇撳煂閻ㄥ嫬鍤戞担鏇氱稊鎼寸噦绱濋柇锝呮皑閺?鐟曞棛娲婄仦鍌氬冀婢跺秴缍婇梿?閻ㄥ嫭娼靛┃鎰剁幢
   *   璺?`pullOpenBegin` 鏉╂柨娲栭崑鍥风礄鏉╄渹缍橀弶鈩冪梾閹稿倽娴?/ 鐎瑰じ瀵屽▽鈥虫槀鐎甸潻绱氶垾鏂衡偓?闁偓閸栨牗鍨?閻╁瓨甯撮柧鐑樺姬"閵?
   *     鏉╂瑤绗岄弮鐘垫櫕闁插繋绗夐崚鎷屽厡閸ュ﹥妞傞幍?`morph: 闁插繋绗夐崚鎷屽厡閸?barId=閳?閳?閺堫剚顐奸柅鈧崶鐐存珮闁?push(閺冪姴鑸伴崣?`
   *     閺勵垰鎮撴稉鈧ぐ銏㈠Ц閿?*鐎逛礁褰叉稉宥呬粵閸斻劎鏁鹃敍灞肩瘍娑撳秷鍏橀幎濠冩尡閺€楣冦€夐崢瀣灇娑撯偓閺夛紕绮忕紓?*閵?
   * @returns true = 瑜般垹褰夊鑼剁箻閸忋儳娴夋担宥忕礄鐠嬪啰鏁ら弬鐟扮安缂佈呯敾 閳垛懇鎳€閿涘绱眆alse = 瀹告煡鈧偓閸栨牔璐熼弮鐘插З閻㈡槒鎯ゆ担?
   */
  private beginOpenMorphOnClick(): boolean {
    this.expandState.resetMorphTrace('clickOpen');
    // 閳藉應妲勯埥?2026-10-16閿?*缂佹瑨绻栭弶鈥崇暓閸楊偉藟閼奉亝鍓?* 閳ユ柡鈧?鐎瑰啯顒濋崜宥勭窗"濮橀晲绠?閹糕€茬秶閻愮懓鍤幍鎾崇磻閿涘绱?
    //   閸樼喎鍨介幑顔芥Ц `pullDragging || morphContainerActive()`閵嗗倷琚遍弶锟犲厴娴?*濞堝鏆€**閿?
    //   璺?`pullDragging`閿涙碍澧滈崝鑳潶閹垫挻鏌囨稉鏃€鐥呯挧鏉垮煂閺€璺虹啲閿涘牏閮寸紒鐔稿閹靛濞?/ 妞ょ敻娼扮悮顐㈠瀼鐠у府绱氶敍?
    //   璺?`morphContainerActive()`閿涙氨娴夋担宥嗙暙閻?`ENTERING/LEAVING/LANDING`閵?
    //   閳跨媴绗?閼?*閻╅晲缍呭▓瀣殌娑撳秵妲?閻劍鍩涙潻妯烘躬閻劍鎸遍弨楣冦€?**閿涙氨鏁ら幋椋庡仯"閹垫挸绱?閺?`isShowPlay`
    //      **韫囧懐鍔ч崚姘矤 false 閸欐ɑ鍨?true**閿涘潉onShowPlayChanged` 鐏忚鲸妲哥€瑰啳袝閸欐垹娈戦敍澶堚偓?
    //      閳?閸欘亣顩?閺堫剝鐤嗗鈧慨瀣閹绢厽鏂佹い?*鏉╂ɑ鐥呴弰鍓с仛**"閿涘矂鍋呮稉銈嗘蒋濞堝鏆€鐏忛亶鍏橀弰?*娑撳﹣绔存潪顔炬畱閸ㄥ啫婧?*閿?
    //        鎼存柨缍?*濞撳懏甯€楠炲墎鎴风紒?*閿涘矁鈧奔绗夐弰顖涘Ω鏉╂瑤绔村▎鈩冨ⅵ瀵偓閸掋倖鍨?闁插秴顦?/ 瀹告彃婀导姘崇樈闁?閵?
    //   閳跨媴绗?閸樼喐鏁為柌濠忕礄閺堫剚鏋冩禒?4332-4336 鐞涘矉绱氬鑼病閻愮懓鍤潻娆庨嚋瑜般垻濮告导姘嚤閼?
    //     閵?*閻愮懓鍤幍鎾崇磻閸欏牓鈧偓閸栨牗鍨氬ú楣冪叾閺冄冨З閻?*閵嗗稄绱濇担鍡楃暊閸欘亞绮?`dismissMorphActive` 閸嬫矮绨￠懛顏呭墹閿?
    //      **鏉╂瑦娼€瑰牆宕奸張顒冮煩濞屸€充粵**閵嗗倵鍣?鏉╂瑥姘ㄩ弰?閻愰€涚啊濞屸€冲З閻?闁插本娓堕梾鎯ь槻閻滄壆娈戦柇锝勭缁夊秲鈧?
    // 閳藉應妲勯埥?2026-10-17閿?*閸掋倖宓佺拋銏☆劀 璺?缁楊兛绨╁▎?*閿涙氨顑囨稉鈧悧鍫熷Ω**娑撳﹥濯洪幍瀣◢**閹垫挻鏌囨禍?閳ユ柡鈧?閻劍鍩涚€圭偞绁撮妴灞肩瑐濠婃垳绗夐懗鍊熷殰閻㈠彉绨￠妴宥忕礆
    //
    // ## 缁楊兛绔撮悧鍫ユ晩閸︺劌鎽㈤敍鍫濈箑妞ゆ槒顔囨稉瀣降閿?
    //   缁楊兛绔撮悧鍫熷Ω閸掋倖宓佹禒?`this.appState.isShowPlay`閿涘牊浜介惇鐕傜礆閹广垺鍨?`playerRouteIndex() >= 0`閿?
    //   閻劍鍓伴弰顖濐唨 `staleClr` 閼奉亝鍓ら惇鐔烘畱閼冲€熺獓閸掕埇鈧倷绲?*娑撳﹥濯洪幍鎾崇磻鏉╂瑦娼捄顖欑瘍鐠х増婀伴崙鑺ユ殶**閿?
    //   ```ts
    //   // 婢瑰啿鐪?onPullOpenStart閿?
    //   this.expandState.pullDragging = false;
    //   const morphOk = this.expandState.pullOpenBegin(...);   // 閳?闁插矂娼伴幎?pullDragging 缂?true
    //   if (!this.appState.isShowPlay) { this.appState.isShowPlay = true; }   // 閳?鐟欙箑褰傞張?Monitor
    //   ```
    //   閳?鐠ф澘鍩屾潻娆撳櫡閺?`pullDragging === true`閿涘牊澧滈幐鍥劀閸︺劑鈹嶉崝顭掔礆閼?*鐠侯垳鏁辨潻妯荤梾 push**
    //     閳?閺傛澘鍨介幑顔剧暬閸?`routeOnStack === false` 閳?閽€鍊熺箻 `staleClr` 閺€?
    //     閳?**`pullDragging = false` + `morphReset()`** 閳?鐠虹喐澧滄导姘崇樈鐞氼偉鍤滃杈ㄥ笌濮?
    //     閳?閵嗗奔绗傚鎴滅瑝閼冲€熷殰閻㈠彉绨￠妴宥冣偓?閺冄傚敩閻礁鍨介幑顔戒航閻?閳?鐠?`skip` 閳?濮濐亝澧﹀锝囨絻閸︾増濮㈡担蹇庣啊閹靛濞嶉妴?
    //
    // ## 鐠併垺顒滈崥搴ｆ畱缂佹挻鐎敍?*娑撱倓娆㈡禍瀣瀻瀵偓閸?*閿涘矁绻栭幍宥嗘Ц閸樼喐鏁為柌濠勬埂濮濓絾鍏傜悰銊ㄦ彧閻ㄥ嫭鍓伴幀婵撶礆
    //   璺?閸樼喐鏁為柌濠呭殰瀹稿崬鍟撻惈鈧妴灞肩瑐閹峰澧滈崝鍨躬妫ｆ牠銆夌挧閿嬪閺冩儼鐭鹃悽杈箷濞?push閵嗗倷绲鹃柇锝嗘 `pullDragging === true`
    //     閳?娑撳﹪娼伴柇锝嗘蒋鐎瑰牆宕兼导姘帥 return閿涘牅绗夎ぐ鍗炴惙閹靛濞嶉敍澶堚偓宥佲偓鏂衡偓?**"閹靛瀵氶崷銊┾攳閸斻劌姘ㄩ弨鎹愵攽"閺勵垰甯張澶嬪壈閸?*閿?
    //     閸欘亝妲哥悮顐ｄ航閻喓娈戦弽鍥х箶鐎圭偟骞囬崸蹇庣啊閵?
    //   璺?閹碘偓娴犮儻绱?*`pullDragging === true` 閳?娑撯偓瀵板鏂佺悰宀嬬礄闁絾妲稿ú璁崇窗鐠囨繐绱濇稉宥嗘Ц濞堝鏆€閿?*閿?
    //     閸欘亝婀?閻╅晲缍呭▓瀣殌**娑?*濞屸剝婀侀幍瀣瘹閸︺劑鈹嶉崝?閹靛秷鐤嗛崚鏉垮灲"閺勵垯绗夐弰顖滄埂瀹歌尙绮￠崷銊︽尡閺€楣冦€夐柌?閵?
    //   閳跨媴绗?缁楊兛绨╃仦鍌氬灲閹诡喕绮涢悽?*绾剝顕伴弫?* `playerRouteIndex() >= 0`閿涘牅绗屾稉瀣桨 `leakClr` 閸氬苯褰涘鍕剁礆閳ユ柡鈧?
    //     閸ョ姳璐?`isShowPlay` 閸︺劌鏁稉鈧拫鍐暏閻愰€涚瑐韫囧懐鍔у鍙夋Ц true閿涘矁顕扮€瑰啰鐡戞禍搴㈢梾閸掋們鈧?
    //   閳跨媴绗?鏉╂瑤绔寸仦鍌涙Ц韫囧懘娓堕惃鍕剁窗閺堫剝鐤嗛幎濠傚彠闂傤厽鏁圭亸鍓ф畱 `morphReset()` 閺€瑙勫灇"缁?pop 娑斿鎮楅崘宥咁槻娴?
    //     閿涘潉PlaybackPage.scheduleMorphResetAfterPop`閿涘矁顫?`RzdMusic鐠佹澘绻?md` 鎼?25閿?
    //     閳?閸忔娊妫撮崥搴″煂婢跺秳缍呴崜宥夊亝娑撯偓鐏忓繑顔岄惄闀愮秴娴犲秵妲?`LANDING`閿涙稓鍋ｅ鈧弮璺虹箑妞ゆ槒鍏樺〒鍛竴鐎瑰啨鈧?
    if (this.expandState.pullDragging) {
      // 閹靛瀵氬锝呮躬妞瑰崬濮╅敍鍫滅瑐閹?娑撳濯虹捄鐔稿閿涘绱?*濞茶绱扮拠?*閿涘矁鐨濇稊鐔峰焼閸斻劌鐣?
      this.expandState.pushMorphTrace('skip');
      Logger.info(RzdShellLogTag,
        `open morph: skip (finger driving; stage=${this.expandState.morphStage} ` +
        `routeOnStack=${this.playerRouteIndex() >= 0 ? 1 : 0})`);
      return false;
    }
    if (this.expandState.morphContainerActive()) {
      // 閻╅晲缍呭▓瀣殌娴ｅ棙鐥呴張澶嬪閹稿洤婀す鍗炲З 閳?閸?閻劍鍩涢弰顖欑瑝閺勵垳婀￠惃鍕嚒缂佸繐婀幘顓熸杹妞ょ敻鍣?
      if (this.playerRouteIndex() >= 0) {
        // 閻喓娈戝鑼病閸︺劍鎸遍弨楣冦€夐柌宀嬬礄闁插秴顦茬憴锕€褰傞敍澶嗗櫩 娣囨繃瀵旈崢鐔活攽娑撶尨绱扮拋鈺冪舶瀹稿弶婀佹导姘崇樈
        this.expandState.pushMorphTrace('skip');
        Logger.info(RzdShellLogTag,
          `open morph: skip (already in player; stage=${this.expandState.morphStage})`);
        return false;
      }
      // 濞堝鏆€閸ㄥ啫婧?+ 閻劍鍩涚涵顔肩杽鐟曚焦澧﹀鈧?閳?**閸忓牊绔婚獮鎻掑櫍閸愬秶鎴风紒?*
      this.expandState.pushMorphTrace('staleClr');
      Logger.warn(RzdShellLogTag,
        `open morph: clearing STALE session (stage=${this.expandState.morphStage} ` +
        `drive=${this.expandState.morphDrive} routeOnStack=0)`);
      this.expandState.morphReset();
    }
    // 閳藉應妲勯埥?2026-10-16閿?*閸掋倖宓佺拋銏☆劀閿涙氨绮?娑撳﹣绔存导姘崇樈"鐞涖儰绔撮弶锛勨€栭弶鈥叉**閿涘绱?
    //   閸樼喐娼甸崣顏呮箒娑撳﹪娼伴柇锝嗘蒋 `pullDragging || morphContainerActive()` 鐎瑰牆宕奸妴鍌欑瑐娑撯偓鏉烆喗濡?
    //   `aboutToDisappear()` 闁插矂鍋呴崣銉︽￥閺夆€叉 `morphReset()` 閸旂姳绨￠梻顭掔礄"娴兼俺鐦藉ú鑽ゆ絻鐏忓彉绗夊〒?閿涘绠ｉ崥搴礉
    //   **娴兼俺鐦藉▔鍕础**閸欐ɑ鍨氶崣顖濆厴閿涙瓪morphSessionStarted` 濞堝鏆€娑?true閿涘矁鈧?`pullDragging` /
    //   `morphContainerActive()` 闁棄鍑￠弰顖氫海 閳?娑撳﹪娼伴柇锝嗘蒋鐎瑰牆宕?*閻绗夌憴浣哥暊** 閳?娑撳绔存潪顔惧仯閸?
    //   鐠囪鍩?`isFreshSession = false` 閳?鐠?閺€鎯х磾娴兼俺鐦?閸掑棙鏁?閳?**閸欏牊鐥呴崝銊ф暰**閵?
    //
    //   閳?鐞涖儰绔撮弶?*绾剚娼禒?*閿涙瓪playerRouteIndex() < 0`閿涘牊鎸遍弨楣冦€夌捄顖滄暠**娑撳秴婀?*閺嶅牓鍣烽敍澶堚偓?
    //     閸忋劌浼愮粙?8 婢?`isShowPlay = true` 闁?*娑撳秷鍤滃?push**閿涘ush 閸欘亞鏁遍張顒佹瀮娴犲墎娈?
    //     `pushPlayerRoute()` 閸?閳?**"鐠侯垳鏁辨稉宥呮躬閺嶅牓鍣?鐏忚鲸妲?娑撳﹣绔存潪顔荤窗鐠囨繂鍑＄紒蹇曠波閺?閻ㄥ嫮鈥栫拠浣瑰祦**
    //     閿涘牊妫ょ拋鐑樻Ц濮濓絽鐖堕崗鎶芥４鏉╂ɑ妲哥悮顐¤厬闂傚瓨澧﹂弬顓ㄧ礆閵?
    //     閳跨媴绗?閸烆垯绔寸憰浣规暈閹板骏绱版稉濠冨閹靛濞嶉崷?*妫ｆ牠銆?*鐠ч攱澧滈弮鎯扮熅閻㈠彉绡冩潻妯荤梾 push閵嗗倷绲鹃柇锝嗘
    //       `pullDragging === true` 閳?娑撳﹪娼伴柇锝嗘蒋鐎瑰牆宕兼导姘帥 return閿涘牅绗夎ぐ鍗炴惙閹靛濞嶉敍澶涚幢
    //       閼?閻愮懓鍤幍鎾崇磻"鐠ч攱澧滈弮?`isShowPlay` 閸掓艾褰?true閵嗕梗pullDragging` 韫囧懍璐熼崑?
    //       閳?閽€钘夊煂鏉╂瑩鍣峰〒鍛濞嗏剝妲哥€瑰鍙忛惃鍕剁礄濞撳懎鐣?`pullOpenBegin` 缁斿鍩㈤柌宥呯紦閿涘鈧?
    const routeOnStack: boolean = this.playerRouteIndex() >= 0;
    if (!routeOnStack && this.expandState.morphSessionStarted) {
      this.expandState.pushMorphTrace('leakClr');
      Logger.warn(RzdShellLogTag,
        `open morph: clearing LEAKED session (route not on stack; stage=${this.expandState.morphStage} ` +
        `drive=${this.expandState.morphDrive} usable=${this.expandState.morphUsable} ` +
        `geom=${this.expandState.morphGeomReadyNow()})`);
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
    }
    // 閳藉應妲勯埥?2026-10-16閿?*鐠侀缍?鏉╂瑤绔存潪顔芥Ц娑撳秵妲搁弬棰佺窗鐠?**閿涘苯鐣犻崘鍐茬暰 `false` 閹簼绠炴径鍕倞閿涘绱?
    //   `pullOpenBegin()` 閹?`morphSessionStarted` 缂冾喚婀￠惃鍕亝娑撯偓濮濄儱姘ㄩ弰?娴兼俺鐦藉铏圭彌"閵?
    //   閸︺劌鐣犳稊瀣鐠囪鍩?false 閳?鏉╂瑦妲?*閸忋劍鏌婃稉鈧潪?*閿涘牏鏁ら幋椋庢埂閻ㄥ嫯顩﹂幍鎾崇磻閹绢厽鏂侀崳顭掔礆閵?
    const isFreshSession: boolean = !this.expandState.morphSessionStarted;
    const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0);
    this.expandState.pushMorphTrace(ok ? 'beginOk' : 'beginNo');
    if (!ok && isFreshSession) {
      // 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤幍鎾崇磻濞屸剝婀侀崝銊ф暰"閻ㄥ嫭娓堕崥搴濈閸ф瀚鹃崶?*閿涘绱?
      //   鏉╂瑤绔村▓闈涘斧閺夈儲妲?`false` 閳?`pullDragging=false` + `morphReset()` + `morphSettleOpen()`
      //   + `return false`"閿涘奔绡冪亸杈ㄦЦ**閺佸瓨顔岄弨鎯х磾瑜般垹褰夋导姘崇樈**閵?
      //   閳跨媴绗?閼?`pullOpenBegin` 鏉╂柨娲?`false` 閻?*閸烆垯绔?*閸樼喎娲滈弰?鏉╂瑤绔撮幏宥夊櫤娑撳秴鍩屾稉婊嗐偪"閳ユ柡鈧?
      //   閻愮懓鍤幍鎾崇磻閺冩儼绻?*韫囧懐鍔?*閸欐垹鏁撻敍鍫熸尡閺€楣冦€夋潻妯荤梾閹稿倽娴囬妴浣哥殱闂堛垼濡悙閫涚瑝鐎涙ê婀敍澶涚礉
      //   娴滃孩妲告潻娆庣濞嗏剝澧﹀鈧悮顐ｆ娑斿懎鍨介幋?閸戠姳缍嶅▽锟犲櫤閸?閳?閺冪姴鑸伴崣妯挎儰娴?閿?
      //   **鏉╃偘绔村▎陇藟闁插繘鍏樺▽陇鐦潻?*閿涘牏鏁ら幋宄扮杽濞村鈧瞼鍋ｉ崙缁樺ⅵ瀵偓閹绢厽鏂侀崳銊︾梾閺堝鐨濋棃?閼冲本娅欓崝銊ф暰閵嗗稄绱氶妴?
      //   閺冪姷鏅惃鍕埌閻樿绱檂MainPage.openPlayerMorph` 149679閿涘绱癭beginMorphEnter` 鏉╂柨娲?false 閺?
      //   **娑撳秵鏂佸?*閿涘矁鈧本妲?
      // ```ts
      //     this.enterAnimStarted = false;
      //     ExpandSnapshot.onPullReady = () => { 閳?};   // 閳?濞夈劌鍞介崶鐐剁殶閿涘瞼鐡戦幘顓熸杹妞ゅ吀绗傞幎銉ュ殤娴ｆ洖鍟€閹恒儳娼冪捄?
      // ```
      //   閳?閹存垳婊戦惃鍕搼娴犻澧跨亸杈ㄦЦ**鐠佲晞藟闁插繘鎽奸幒銉﹀**閿涙矮绻氶幐?`ENTERING/FINGER` 娑?`pullDragging`閿?
      //     閻?`settlePullOpen` 閻?12鑴?2ms 鐞涖儵鍣洪幎濠勭矒閻愬綊鍣洪崶鐐存降閿涘矂鍣洪崚浼村亝娑撯偓閹?
      //     閿涘潉measureMiniDuringPull` 闁插矉绱氶幎?`morphGeomReady` 缂冾喚婀￠妴浣割啇閸ｃ劎顑囨稉鈧▎陇鎯ゆ担宥冣偓?
      //   閳跨媴绗?閸欘亜婀?`isFreshSession` 閺冩儼绻栭弽宄颁粵閿?*瀹歌尙绮￠崷銊ょ窗鐠囨繈鍣?*閿涘牓鍣告径宥埿曢崣?/ 濞堝鏆€閿涘绮涢悞鎯拌泲閸樼喐娼甸惃?
      //     娣囨繂鐣ч崚鍡樻暜閿涘苯鍘ゅ妤佸Ω閻劍鍩涘锝呮躬閻娈戦柇锝勭鏉烆喕绱扮拠婵囩閹哄鈧?
      this.expandState.pushMorphTrace('awaitGeom');
      Logger.warn(RzdShellLogTag,
        `open morph: geometry not measurable yet 閳?keep the session and retry ` +
        `(stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive} ` +
        `bigKnown=${this.expandState.bigCoverAnchored()})`);
      return true;
    }
    if (!ok) {
      Logger.warn(RzdShellLogTag,
        'open morph: mini bar / host rect unavailable 閳?plain landing (no morph)');
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
      this.expandState.pushMorphTrace('noMorph');
      this.expandState.morphStage = MorphStage.OPEN;
      this.expandState.morphP = 1;
      // 鍐呭鏃堕棿绾夸笌鍑犱綍鏃堕棿绾垮湪闈欐鎬佸繀椤诲悓鍊硷紙瑙?`PlayerExpandState.contentP` 鐨勮鏄庯級銆?
      this.expandState.contentP = 1;
      return false;
    }
    Logger.info(RzdShellLogTag, 'open morph: begin from click entry (align Wujie openPlayerMorph)');
    // 閳?婢瑰啿鐪板ù顔肩湴闁絼绔村Λ鎺旀畱鏉╂稑瀹虫稊鐔峰竾閸ョ偠鎹ｉ悙鐧哥窗鐎瑰啰娈戦棃娆愵剾閹礁鍨甸崐鍏兼Ц 1閿?瀹歌尪鎯ゆ担?鐠囶厺绠熼敍澶涚礉
    //   娑撳秴甯囬崶?0 閻ㄥ嫯鐦藉ù顔肩湴缁楊兛绔寸敮褌绱伴幐?閽€鎴掔秴閻ㄥ嫬銇囩亸渚€娼?閻㈣绔村▎鈽呯礄= 閸斻劎鏁鹃柌灞藉毉閻滄壆顑囨禍灞界炊鐏忎線娼伴敍澶堚偓?
    this.expandState.morphOverlayReset();
    // 閳跨媴绗?**娑撳秷顩﹂崷銊ㄧ箹闁?*鐠ч攱璇炵仦鍌炲亝娑撯偓濡帞娈戠悰銉╂？閿涙碍顒濋崚?`morphContainerActive()` 鏉╂ɑ妲搁崑?
    //   閿涘潉pullOpenBegin` 閸欘亝濡搁惄闀愮秴缂冾喗鍨?ENTERING 閻ㄥ嫬澧犳稉鈧銉礆閿涘畭focusMorphOverlayForPageIntro()`
    //   娴兼岸娼ゆ?return閵嗗倹璇炵仦鍌滄畱閺勬儳绱℃す鍗炲З閺€鎯ф躬 `onShowPlayChanged` 闁插矉绱欓幒銊ㄧ熅閻㈠彉绠ｉ崥搴礆閵?
    return true;
  }

  /** 閹绢厽鏂佹い浣冪熅閻㈠崬婀弽鍫ュ櫡閻ㄥ嫪绗呴弽鍥风礄娑撳秴婀弽鍫ュ櫡鏉╂柨娲?-1閿涘鈧?*/
  private playerRouteIndex(): number {
    const names: string[] = this.pageIndexInfos.getAllPathName();
    if (names === undefined || names.length === 0) {
      return -1;
    }
    return names.indexOf(RouterUrlConstants.PLAYER_PAGE);
  }

  /**
   * 閹恒劌鍙嗛幘顓熸杹妞や絻鐭鹃悽渚库偓?
   *
   * 閳跨媴绗?缁楊兛绨╅崣?`animated` **韫囧懘銆忛弰?false**閿涙艾鑸伴崣妯垮殰瀹稿崬姘ㄩ弰顖氬З閻紮绱濈化鑽ょ埠鏉烆剙婧€娴兼艾鎷扮€瑰啫褰旈崝?
   *    閿涘牊妫ら悾?1.2.4 閸忚櫕甯€娴滃棗鐣犻敍娑樼暭閺傚箍鈧﹤鍙℃禍顐㈠帗缁辩姾娴嗛崷鎭掆偓瀣瘹閸楁鎮撻弽鐤洣濮?`pushPath()` 閸忓啿濮╅悽浼欑礆閵?
   * `param.pull = true` = 鏉╂瑦顐兼潻娑樺弳鐟曚浇铔嬭ぐ銏犲綁閿涘牆顕弽鍥у冀缂傛牞鐦ч柌宀€娈?`param.pull`閿涘鈧?
   */
  private pushPlayerRoute(): void {
    if (this.playerRouteIndex() >= 0) {
      return;
    }
    Logger.info(RzdShellLogTag, 'route: push player (animated=false, param.pull=true)');
    this.pageIndexInfos.pushPath({
      name: RouterUrlConstants.PLAYER_PAGE,
      param: new PlayerRouteParam(true)
    }, false);
  }

  /**
   * 缁夊娅庨幘顓熸杹妞や絻鐭鹃悽鎲嬬窗閺€鎯版崳閸斻劎鏁惧鑼病閻㈣鲸鎸遍弨楣冦€夐幘顓炵暚閿涘矁绻栭柌灞肩瑝閸愬秴鐢化鑽ょ埠鏉烆剙婧€閵?
   *
   * 閳跨媴绗?娑撳秷鍏橀崘娆愬灇"閺勵垱鐖ゆい鑸靛 pop"閿涙瓪ControlAreaComponent` 闁插苯鐡ㄩ崷?閸?`isShowPlay = false`
   *    閸?`pushPathByName(閼硅桨姹夋い?閹兼粎鍌ㄦい?`"閻ㄥ嫬鍟撳▔鏇礉娑撱倓閲滈崝銊ょ稊閻ㄥ嫬鍘涢崥搴ㄣ€庢惔蹇庣瑝绾喖鐣鹃妴?
   *    閹碘偓娴犮儴绻栭柌灞惧瘻**閸氬秴鐡ч幍鍙ョ瑓閺?*閸愬秴鍨归敍姘暊閸︺劍鐖ゆい璺烘皑 pop閿涘奔绗夐崷銊︾垽妞よ泛姘?`removeByIndexes`閿?
   *    娑撱倗顫掓い鍝勭碍闁棄绶遍崚鐗堫劀绾喚绮ㄩ弸婊愮礉娑旂喍绗夋导姘辨殌娑撳绔撮弶鈥冲厞鐏忓憡鎸遍弨楣冦€夌捄顖滄暠閵?
   */
  private popPlayerRoute(): void {
    const idx: number = this.playerRouteIndex();
    if (idx < 0) {
      PlaybackPage.ev('REM', 'noIdx');
      return;
    }
    const names: string[] = this.pageIndexInfos.getAllPathName();
    Logger.info(RzdShellLogTag, `route: remove player at index=${idx} (top=${names.length - 1})`);
    // 閳藉應妲勯埥?2026-10-16閿?*閸忔娊妫存潻鍥┾柤姒涙垵灏堢€?璺?缁楊兛绗佺粭?*閿涘绱扮拋?鐠侯垳鏁遍惇鐔烘畱鐞氼偄鍨归幒澶夌啊"鏉╂瑤绔撮崚姹団偓?
    //   娑撹桨绮堟稊鍫濈箑妞ゆ槒顔囬敍姘卞箛閸︺劌鍙ч梻顓㈡懠鐠侯垳娈戦弨璺虹啲閺?*閸氬奔绔存稉?tick 闁插矁绻涢惈鈧崑?*閻?閳ユ柡鈧?
    //   `isShowPlay=false`閿涘牃鍟?閺堫剙鍤遍弫甯礉娴?V2 `@Monitor` 閺?*瀵倹顒?*閸ョ偠鐨熼敍澶嗗晪 `morphReset()`
    //   閿?*閸氬本顒?*閹?`morphP` 婢跺秳缍呴幋?1閵嗕胶娴夋担宥嗙閹?NONE 閳?鐎圭懓娅掓稉宥呭晙鐟佷礁澹€/缂傗晜鏂?= 濠娾€崇潌閿涘鈧?
    //   閳?娑撱倛鈧懍绠ｉ梻鏉戝涧鐟曚線娈ф禍鍡楁憿閹洑绔寸敮褝绱濈仦蹇庣瑐鐏忚鲸妲?瀹歌尙绮＄紓鈺傚灇鐏忓繐娓鹃悙閫涚啊" 閳?缁愪胶鍔?*濠娾€崇潌閹绢厽鏂佹い?*
    //     閳?閸愬秷顫?pop 閻ㄥ嫯娴嗛崷鍝勭敨鐠ц埇鈧倻鏁ら幋閿嬪Г閻ㄥ嫨鈧苯濮╅悽鑽ょ波閺夌喍绨?*缁愪胶鍔ч弶銉ら嚋鐏炴洖绱戦幘顓熸杹閸ｃ劎娈戦崝銊ф暰**閵嗗秵顒滈弰顖濈箹娑擃亜鑸伴悩韬测偓?
    //   閸掋倛顕伴敍姝歊ST` 娑?`REM` 娑斿妫块惃?`t+` 瀹?> ~16ms 閳?閼峰啿鐨張澶夌鐢勫姬鐏炲繋鑵戦梻瀛樷偓?閳?鐏忚鲸妲哥€瑰啨鈧?
    PlaybackPage.ev('REM', `idx=${idx} top=${names.length - 1}`);
    if (idx === names.length - 1) {
      this.pageIndexInfos.pop(false);
    } else {
      this.pageIndexInfos.removeByIndexes([idx]);
    }
  }

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 娑撳﹥濯洪幍鎾崇磻閹绢厽鏂佹い纰夌礄鐠虹喐澧滈敍灞斤紦鐏炲倷鏅堕敍澶嗘敘閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
  //
  // 娑撹桨绮堟稊鍫熷閸斿灝绻€妞よ婀?*婢瑰啿鐪?*閼板奔绗夐弰顖涙尡閺€楣冦€夐敍姘尡閺€楣冦€夐崷?`bindContentCover` 閻ㄥ嫭膩閹線鍣烽敍?
  // 閼板本膩閹礁婀?`isShowPlay` 娑?false 閺?*閺嶈婀版稉宥呯摠閸?* 閳ユ柡鈧?濞屸剝瀵曟潪鐣屾畱妞ょ敻娼伴弨鏈电瑝閸掔増澧滈幐鍥︾皑娴犺翰鈧?
  // 閹碘偓娴犮儵鎽肩捄顖涙Ц閿?
  //
  //   婢瑰啿鐪?onActionStart閿涘牅绮犳惔鏇㈠劥鐠ч攱澧滈敍澶嗗晪 閹稿倽娴囧Ο鈩冣偓渚婄礄鏉╂稑瀹?100 = 鏉╄渹缍橀弶锟犲亝娑撯偓鐏忓繐娼￠敍?
  //   閳?婢瑰啿鐪?onActionUpdate 閸?transitionProgress 閳?閹绢厽鏂佹い?@Monitor 闂€婊冨剼閹?collapseProgress
  //   閳?妤傛ê瀹?缂傗晜鏂?娴ｅ秶鐤?閸﹀棜顫?闁繑妲戞惔锕€鍙忛柈銊ㄧ閻偓閹靛瀵氱挧?
  //   閳?婢瑰啿鐪?onActionEnd 鏉╁洭妲囬崐鐓庡灟鐞涖儵妫块崚?0閿涘牆鐣崗銊ョ潔瀵偓閿涘绱濋崥锕€鍨悰銉╂？閸?100 楠炶泛宓忔潪?

  /**
   * 娑撳﹥濯洪幍鎾崇磻閿涙俺鎹ｉ幍瀣仯閺勵垰鎯侀拃钘夋躬閵嗗矁绯犳担鐘虫蒋闁絼绔撮弶鈥崇敨閵嗗秹鍣烽敍鍫ｇ碃娴ｇ姵娼?= 闁絼閲滈幎濠冨閿涘鈧?
   *
   * 閳跨媴绗?閺冄嗩潐閸掓瑦妲搁妴灞肩矤鐏炲繐绠锋稉瀣磹闁劌鍨庨敍鍫氬⒑60% 鐏炲繘鐝敍澶庢崳閹靛姘ㄩ幒銉ь吀閵嗗稄绱濋悽銊﹀煕鐎圭偞绁撮敍?026-10-11閿涘绱?
   *   閵嗗本鍨滈惃鍕€夐幋鎴滅矤閹绢厽鏂侀崳銊ょ瑐闂堫澀绔撮柈銊ュ瀻閻ㄥ嫪缍呯純顔荤瑐濠婃垳绡冩导姘ⅵ瀵偓閹绢厽鏂侀崳顭掔礄閸欘亝婀侀幋鎴犳畱妞ゅ吀绱伴崙铏瑰箛閿涘鈧秲鈧?
   *   閸樼喎娲滈敍姘＋鐟欏嫬鍨幎?*閺佺繝閲滄稉瀣磹鐏?*闁棄鍨濋幋鎰娴煎憡澧滈崝璺ㄦ畱閻戭厼灏妴鍌氬焼閻ㄥ嫰銆夐棃銏犳躬闁絼绔寸敮锔筋劀婵傝姤妲搁梹鍨灙鐞?/
   *   濠婃艾濮╃憴鍡楁禈閿涘瞼鐝惄瀛樺珛閸斻劏顫﹂崚妤勩€冮崗鍫濇倖閹哄绱濇竟鍐茬湴鏉╂瑦娼?`.gesture(PanGesture)`閿涘牆鍟嬪▔锟犳▉濞堢绱濇导妯哄帥缁?
   *   娴ｅ簼绨€涙劗绮嶆禒璁圭礆閺嶈婀伴弨鏈电瑝閸掑府绱遍懓灞烩偓灞惧灉閻ㄥ嫨鈧秹銆夐崘鍛啇娑撳秵寮ф稉鈧仦蹇ョ礄閹存牕鍑＄紒蹇旂泊閸掓澘绨抽敍澶嬫閸掓銆冩稉宥嗙Х鐠愯瀚嬮崝顭掔礉
   *   娴滃孩妲搁幍瀣◢閸愭帗鍦烘稉濠冩降閵嗕焦鎸遍弨鎯ф珤鐞氼偊銆庨幍瀣瀵偓 閳ユ柡鈧?閹碘偓娴犮儱褰ч張澶婄暊閵嗗本绱￠妴宥冣偓?
   *   閺€鍓佹彛閹存劧绱扮挧閿嬪閻愮懓绻€妞ゆ槒鎯ら崷?*鎼存洟鍎撮柇锝勭閺夆€崇敨**閿涘牐绯犳担鐘虫蒋 56 + 鎼存洟鍎撮柆鑳唨 + 娑撳﹥閮ㄦ担娆撳櫤閿涘鍞撮妴?
   *   妞ょ敻娼版稉顓燁唽閵嗕礁鍨悰銊ュ隘閸╃喓娈戞稉濠冪拨娑撯偓瀵板姘︽潻妯肩舶濠婃艾濮╃憴鍡楁禈閿涘牐绻栨稊鐔锋嫲"鏉╄渹缍橀弶鈩冩Ц閹跺﹥澧?閻ㄥ嫪姘︽禍鎺旀纯鐟欏绔撮懛杈剧礆閵?
   * @param fingers 鐠ч攱澧滈幍瀣瘹閸掓銆冮敍鍫㈢崶閸欙絽娼楅弽?globalY閿涘瘉p閿涘鈧?
   * @returns 閺勵垰鎯侀悽鍗烇紦鐏炲倹甯寸粻陇绻栧▎鈩冨珛閸斻劊鈧?
   */
  private pullOpenStartsNearBottom(fingers: FingerInfo[]): boolean {
    if (fingers === undefined || fingers.length === 0) {
      return false;
    }
    const h: number = this.viewportHeightVp > 0 ? this.viewportHeightVp : 800;
    const y: number = fingers[0].globalY;
    const bandTop: number = Math.max(h - PULL_OPEN_HANDLE_BAND_VP, h * 0.6);
    return y >= bandTop;
  }

  /** 娑撳﹥濯哄鈧慨瀣剁窗鏉╂稑鍙?ENTERING 闂冭埖顔岄敍鍫濆讲鐠虹喐澧滈敍澶婅嫙閹稿倽娴囬幘顓熸杹妞ょ偣鈧?*/
  private onPullOpenStart(fingers: FingerInfo[]): void {
    // 閳?鐠囧﹥鏌囬敍姘煀娑撯偓鏉烆喗澧滈崝鍨磻婵?閳?濞撳懏甯€"閺堫剚顐奸幍瀣◢瀹歌尪顔囨潻鍥︾濞嗏剝瀚嗙紒?閻ㄥ嫰妞勯敍鍫ｎ潌 `onPullOpenUpdate`閿涘鈧?
    this.pullDropCountedThisGesture = false;
    // 閳跨媴绗?閹绢厽鏂佹い闈涘嚒缂佸繐绱戦惈鈧亸鍗炲焼閹恒儳顓搁敍姘尡閺€楣冦€夐悳鏉挎躬閺勵垰锛撶仦?Stack 闁插瞼娈戦弲顕€鈧碍璇炵仦鍌︾礄娑撳秴鍟€閺勵垱膩閹緤绱氶敍?
    //    婢瑰啿鐪版潻娆愭蒋閹靛濞嶉崷銊ョ暊娑撳﹪娼版笟婵堝姧閺€璺虹繁閸?閳ユ柡鈧?娑撳秵灏呮稉鈧稉瀣剁礉閻劍鍩涢崷銊︽尡閺€楣冦€夐柌灞肩矤娑撳宕愮仦蹇撶窔娑撳﹥瀚?
    //    娴兼碍濡歌ぐ銏犲綁鏉╂稑瀹虫径宥勭秴閸?0閿涘牊鎸遍弨楣冦€?閸?閸︽壆缂夐崶鐐剁碃娴ｇ姵娼敍澶涚礉
    //    閼板本鎸遍弨楣冦€夐懛顏勭箒閻ㄥ嫪绗呴幏澶嬫暪鐠ч攱澧滈崝鍨倱閺冭泛婀捄鎴礉娑撱倕顨滈崝銊ф暰閻╁瓨甯撮幍鎾寸仸閵?
    if (this.appState.isShowPlay) {
      return;
    }
    // 閳跨媴绗?濞堝鏆€閸?true 閻?`pullDragging` 娴?*鐠佲晝鍋ｉ崙缁樺ⅵ瀵偓濮樻瓕绻欑捄瀹犵箖瑜般垹褰夐崚婵嗩潗閸?*閿涘牓銆夐棃銏ゅ亝鏉堣瀵滅€?
    //    閸掋倖鏌?閹靛瀵氬锝呮躬妞瑰崬濮?閿涘鈧倽鎹ｉ幍瀣箹娑撯偓閸掕崵绮烘稉鈧〒鍛濞嗏槄绱濇穱婵婄槈濮ｅ繑顐奸幍鎾崇磻闁姤妲告禒搴″叡閸戔偓閻樿埖鈧礁绱戞慨瀣ㄢ偓?
    this.expandState.pullDragging = false;
    if (!this.pullOpenStartsNearBottom(fingers)) {
      return;
    }
    // 閳?閸忓牓鍣烘稉鈧▎陇绯犳担鐘虫蒋娑撳骸顔栨稉鑽ゆ畱**濞撳弶鐓嬮惌鈺佽埌**閿涘潉getRectangleById`閿涘苯褰涘?px 閳?vp閿涘绱?
    //   `onAreaChange` 缂佹瑧娈戦弰顖氱鐏炩偓閸戠姳缍嶉妴浣风瑝閸氼偆顨涢崗?transform閿涘瓛DS 濞搭喖濮╂惔鏇熺埉闁絿鍋ｉ崑蹇曅?
    //   娴兼俺顔€閸斻劎鏁剧挧椋庡仯閺佺繝缍嬮崑蹇ョ礄閻劍鍩涚€圭偞绁撮惃?娴犲骸鐨濋棃銏犱焊瀹革缚绗呯憴鎺戠磻婵?閿涘鈧?
    const morphOk: boolean = this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0);
    if (!this.appState.isShowPlay) {
      this.appState.isShowPlay = true;
    }
    if (!morphOk) {
      // 閸戠姳缍嶅▽锟犲櫤姒绘劧绱欐潻铚傜稑閺夆剝鐥呴幐鍌濇祰 / 鐎瑰じ瀵屽▽鈥虫槀鐎甸潻绱氶敍姘辨纯閹恒儵鎽靛鈽呯礉閸掝偆鈥栭崑姘埌閸?
      // 閳ユ柡鈧?绾剙浠涢惃鍕樈閹绢厽鏂佹い鍏哥窗鐞氼偄甯囬幋鎰閺夛紕绮忕紓婵撶礄鐟?PlayerExpandState.morphUsable閿涘鈧?
      // 閳?鐠囧﹥鏌囩拋鈩冩殶閿涘牆绐橀弽鍥╊儑閸椾浇顢?`pd=` 閻ㄥ嫮顑囨稉鈧稉顏呮殶閿涘绱版潻娆庨嚋閺佺増瀹?閳?娑撳﹥濯?*濞屸剝婀佺捄鐔稿閸斻劎鏁?*閿?
      //   閸樼喎娲滈弰?鐠ч攱澧滈柇锝勭閸掕鍤戞担鏇熺梾闁插繘缍?閿涘奔绗?`pullDragging` 闁絾娼捄顖涙￥閸忕绱欑憴?`pullDropBegin`閿涘鈧?
      this.expandState.notePullDropBegin();
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
      this.expandState.morphSettleOpen();
      return;
    }
    // 閳?鐠ч攱澧滈柇锝勭閸掔粯鎸遍弨楣冦€夐崚姘瘯鏉炴枻绱?缂侇參顥ｇ亸渚€娼?閻ㄥ嫮绮撻悙鐧哥礄鐎瑰啰娈戞径褍鐨濋棃顫礆鏉╂﹢鍣烘稉宥呭煂 閳ユ柡鈧?鐞涖儵鍣洪妴?
    //   娑撳氦绯犳担鐘虫蒋閼奉亜绻侀柇锝嗘蒋閹靛濞嶉柌宀€娈戠悰銉╁櫤閸氬奔绔存總妤冪崶閸欙綇绱?2 鑴?32ms閿涘苯顕弽鍥у冀缂傛牞鐦?`onPullReady`閿涘鈧?
    this.schedulePullAnchorRemeasure(0);
    // 閳?婢瑰啿鐪板ù顔肩湴闁絼绔村Λ鎺炵礄`MorphCoverClone`閿涘绡冮崢瀣礀鐠ч鍋ｉ妴鍌氱暊閻ㄥ嫯绻樻惔?`morphOverlayP`
    //   闂堟瑦顒涢幀浣稿灥閸婂吋妲?1閿?瀹歌尙绮￠崷銊ㄦ儰娴?閻ㄥ嫯顕㈡稊澶涚礆閿涘奔绗夐崢瀣礀 0 閻ㄥ嫯鐦藉ù顔肩湴缁楊兛绔寸敮褌绱伴悽缁樺灇婢堆冪殱闂堫潿鈧?
    this.expandState.morphOverlayReset();
  }

  /**
   * 鐠虹喐澧滈張鐔兼？鐞涖儵鍣?缂侇參顥ｇ亸渚€娼?閻ㄥ嫮绮撻悙褰掓晪閻愮櫢绱欓幘顓熸杹妞ら潧銇囩亸渚€娼伴敍澶堚偓?
   *
   * 閳跨媴绗?`attempt` **韫囧懘銆忕敮锕傜帛鐠併倕鈧?`0`**閿涘苯鑻熸稉鏃囶洣閹糕€茬秶 `undefined`/`NaN`閿?
   * `attempt >= PULL_ANCHOR_RETRY_MAX` 鐎?`undefined` 閸?`NaN` **闁姤妲?false**閿?
   * 娴滃孩妲搁弮鐘插棘鐠嬪啰鏁ら敍鍫熷灗閺屾劒绔寸仦鍌欑炊娴?`attempt + 1` 缁犳鍤?NaN閿涘绱扮拋鈺勭箹閺?32ms 闁帒缍?*濮橀晲绗夐崑婊勵剾**
   * 閿涘潉features/playlist` 閻ㄥ嫬褰熸稉銈勫敜閸擃垱婀伴崢鐔告降鐏忚鲸妲告潻娆庨嚋瑜般垻濮搁敍?026-10-15 瀹告彃顕鎰剁幢鐟欎焦妫ら悾灞芥倱濮?鎼?2閿涘鈧?
   * @param attempt 瀹告彃鐨剧拠鏇燁偧閺?
   */
  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (!Number.isFinite(attempt) || attempt >= PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    setTimeout((): void => {
      // 閳藉應妲勯埥?2026-10-16閿?*閸氬奔绔磋ぐ銏㈠Ц閻ㄥ嫮顑?4 婢?*閿涙瓪morphGenAlive` 鐎瑰牆宕?閳ユ柡鈧?閸?3 婢跺嫬鍑￠崷?鎼?02/鎼?04 娣囶喛绻冮敍?
      //   鏉╂瑩鍣烽崢鐔告降閺?`if (!pullDragging || !morphGenAlive(gen)) return;`閿涘苯鍙炬稉?
      //   `gen` 閺?*閸欐垼鎹ｉ柇锝勭閸?*閹规洝骞忛惃?`morphGen`閵?
      //
      // ## 娑撹桨绮堟稊鍫濈暊閸︺劎鍋ｉ崙鏄忕箹閺壜ょ熅娑撳﹥妲搁柨娆戞畱
      //   `morphGen` 閻ㄥ嫯顕㈡稊澶嬫Ц"鏉╂瑤绔存潪顔艰埌閸欐ü绱扮拠婵堟畱缂傛牕褰?閿涘苯鐣犵悮?`morphReset()` **閹恒劑鐝?*閵?
      //   閼板瞼鍋ｉ崙缁樺ⅵ瀵偓閺冭绱漙pushPath` 娴兼俺顔€**閺冄囥€夐棃銏犵杽娓氬宓忔潪?*閿涘本妫€圭偘绶ラ惃?`onDisAppear` 娴兼俺铔?
      //   閿涘牓鍋呴弶陇鐭炬稉濠勬窗閸撳秴褰ч張?`morphUsable` 娑撹櫣婀＄亸杈儲鏉?鏉╂瑤绔寸仦鍌欑箽閹躲倧绱濈憴?`PlaybackPage.onDisAppear`閿?
      //   閳ユ柡鈧?娑撯偓閺冿箑鐣犻惇鐔烘畱鐠嬪啫鍩屾禍?`morphReset()`閿涘本婀伴崙鑺ユ殶閻ㄥ嫪绗樻禒锝呭娇缁斿鍩㈡潻鍥ㄦ埂
      //   閳?**濮ｅ繋绔撮幏宥夊厴閸︺劎顑?2 鐞涘矂娼ゆ?return**閿涘牅绗夐崘娆愭）韫囨绱濋弻銉ょ瑝閸戠儤娼甸敍澶堚偓?
      //   鏉╂瑤绗?鎼?02 娣囶喗甯€閻ㄥ嫨鈧椒浜掗崣?鎼?04 娣囶喚娈?*鐎瑰苯鍙忛崥灞肩娑擃亜鑸伴悩?*閿?
      //     > 閻?娴兼俺鐦界紓鏍у娇"閸樿鍨?閻劍鍩涙潻妯诲厒娑撳秵鍏傞惇瀣尡閺€楣冦€? 閳ユ柡鈧?娑撱倛鈧懏妫ら崗鐐解偓?
      //
      // ## 閺€瑙勭《閿涘牆鍨介幑顔藉床閹存劖娲块弮鈹库偓浣规纯閻╁瓨甯撮惃鍕皑鐎圭儑绱?
      //   `pullDragging` 鐞涖劎銇?鏉╂瑤绔存潪顔跨閹?閺€璺虹啲鏉╂ɑ鐥呯挧鏉跨暚"閿涘潉settlePullOpen` 娴兼矮绔撮惄缈犵箽閹镐礁鐣犻敍?
      //   閻╂潙鍩岀悰銉╂？鐠х柉绐囬柇锝勭閸掔粯澧犵純?false閿涘鈧柡鈧?鏉╂瑦顒滈弰?鏉╂顩︽稉宥堫洣缂佈呯敾鐞涖儵鍣?閻ㄥ嫮婀￠崚銈嗗祦閵?
      //   娑撴牔鍞崣宄版躬鏉╂瑩鍣峰▽鈩冩箒娴犺缍嶅锝団€橀悽銊┾偓鏃撶窗鐞涖儵鍣洪崣顏堟付鐟?閸戠姳缍嶆潻妯荤梾姒?+ 閻劍鍩涙潻妯烘躬缁?閵?
      //   閳?閸樼粯甯€ `gen`閿涘苯褰ч崚?`pullDragging`閿涙稑鍟€鐞涖儰绔撮弶?`isShowPlay`閿涘牏鏁ら幋宄板嚒缁傝绱戠亸鍗炲焼闁插繋绨￠敍澶堚偓?
      if (!this.expandState.pullDragging) {
        return;
      }
      // 閻劍鍩涘鑼病缁傝绱戦幘顓熸杹妞ょ绱檂popPath` 闁絾娼捄顖ょ礆閳?閸愬秷藟闁插繋绡冨▽鈥叉眽閻绱濋弨璺轰紣閵?
      // 閳跨媴绗?閸掋倖宓侀悽?`isShowPlay` 閼?*娑撳秵妲?*娑撴牔鍞崣鍑ょ礄娑撴牔鍞崣铚傜窗鐞氼偅妫ら崗宕囨畱娴滃甯规姗堢礉鐟欎椒绗傞棃銏ゅ亝濞堢绱氶妴?
      if (!this.appState.isShowPlay) {
        return;
      }
      if (this.expandState.measureMiniDuringPull(this.getUIContext(), this.navDepth > 0)) {
        return;
      }
      this.schedulePullAnchorRemeasure(attempt + 1);
    }, PULL_ANCHOR_RETRY_MS);
  }

  /** 鐠虹喐澧滈弴瀛樻煀閿涙矮缍呯粔?閳?鏉╂稑瀹?0閳?閿?*缁炬寧鈧?*閿涘矁绐￠幍瀣▉濞堝吀绗夐崝鐘电处閸旑煉绱氶妴?*/
  private onPullOpenUpdate(offsetY: number): void {
    if (!this.expandState.pullDragging) {
      // 閳?鐠囧﹥鏌囩拋鈩冩殶閿涘牆绐橀弽鍥╊儑閸椾浇顢?`pd=` 閻ㄥ嫪鑵戦梻鎾亝娑擃亝鏆熼敍澶嗏偓鏂衡偓?鐟?`PlayerExpandState.pullDropUpdate`閿?
      //   "閹靛瀵氶崷銊ュЗ娴ｅ棜绻樻惔锔跨瑝鐠?閺冭绱濇潻娆庨嚋閺侀绱板☉顭掔礉楠炴儼顕╅弰搴㈡Ц**閸掋倖宓?*閹锋帞娈戦敍鍫ｂ偓灞肩瑝閺勵垯绨ㄦ禒鑸电梾閸掑府绱氶妴?
      // 閳跨媴绗?**娑撯偓濞嗏剝澧滈崝鍨涧鐠侀绔村▎?*閿涙碍婀伴崙鑺ユ殶閻㈣鲸鐦℃稉?`onActionUpdate` 鐠嬪啰鏁ら敍鍫氬60~120 濞?缁夋帪绱氶敍?
      //   閼板矁顓搁弫鏉垮晸閻ㄥ嫭妲?`@Trace` 鐎涙顔?閳?濮ｅ繑顐奸柈钘夊晸娴兼俺顔€瀵拌姤鐖ｉ柇锝勯嚋 `Text` 濮ｅ繐鎶氶柌宥呯紦閿?
      //   閹澘銈介幎?閹靛鍔?閹煎懏绁介敍鍫ｇ槚閺傤厽婀伴煬顐㈠綁閹存劕鍏遍幍鐗堢爱閿涘鈧倽鐦栭弬顓炲涧闂団偓鐟?鏉╂瑤绔存潪顔芥箒濞屸剝婀佺悮顐ｅ珕"鏉╂瑤绔存稉顏冪皑鐎圭偑鈧?
      if (!this.pullDropCountedThisGesture) {
        this.pullDropCountedThisGesture = true;
        this.expandState.notePullDropUpdate();
      }
      return;
    }
    this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(offsetY));
    // 閳?閹靛瀵氱捄鐔稿闁絾娼捄顖欑瑐閿涘本璇炵仦鍌涘鐠愭繄娈戞潻娑樺娑撳孩鎸遍弨楣冦€夋潻娑樺**娑撯偓濮ｆ柧绔撮崥灞绢劄**閿涘牅绗夌捄鎴Ｋ夐梻杈剧礆閿?
    //   娑撱倕鐪伴崷銊ㄧ閹靛婀¤箛鍛淬€忛弰顖氭倱娑撯偓娑擃亜鈧》绱濋崥锕€鍨弶鐐鐞涖儵妫块弮鏈电窗閸?鐠?閸掔増璇炵仦鍌濆殰瀹搁亶鍋呮稉顏囩箻鎼达缚绗傞妴?
    //   娑撱倖娼幍瀣◢閿涘牆锛撶仦鍌濈箹閺?+ 鏉╄渹缍橀弶锟犲亝閺夆槄绱氶柈钘夊晸 `morphP`閿涘本澧嶆禒銉﹁癁鐏炲倸绻€妞?*鐠虹喓娼?morphP 鐠?*
    //   閼板奔绗夐弰顖滅搼閺屾劒閲滈崗銉ュ經閸樻槒顔?閳ユ柡鈧?鏉╂瑦鐗辨稉宥囶吀閸濐亝娼幍瀣◢閹恒儱鍩岄惃鍕厴閼宠棄顕稉濞库偓?
    this.expandState.syncMorphOverlayFromPage();
  }

  /**
   * 閺夌偓澧滈敍?*閹绘劒姘﹂崚銈嗗祦娴溿倗绮?`PlayerExpandState.pullOpenShouldCommit()`**閿涘牊绔婚崡?鎼傛稉鈧?1.2
   * 閵嗗矁绻樻惔?OR 闁喎瀹抽妴宥忕礆閳ユ柡鈧?鏉╁洭妲囬崐纭风礄閹存牕鎻╅柅鐔剁瑐閻⑩晪绱氱悰銉╂？閸?1閿涘牆鐫嶅鈧敍澶涚礉閸氾箑鍨崶鐐插煂 0 楠炶泛宓忔潪濮愨偓?
   *
   * 閳跨媴绗?鏉╂瑩鍣?*娑撳秷顩﹂崘宥呭晸 `morphP >= 0.45`**閿涙岸鍋呴弶鈥冲灲閹诡喖甯弶銉ユ躬娑撳閲滈弬鍥︽闁插苯鎮囬崘娆庣啊娑撯偓闁?
   *    閿涘牊婀伴弬鍥︽ + 娑撱倓閲滄潻铚傜稑閺夆槄绱氶敍灞炬暪閺佹稑鍩?`PlayerExpandState` 娑撯偓婢跺嫪绠ｉ崥搴礉
   *    閺€褰掓閸婄厧褰ч弨褰掑亝娑撯偓娑擃亜鐖堕柌蹇ョ礉娑撳秳绱伴崙铏瑰箛"娑撱倖娼幍瀣◢娑撳鏅崐闂寸瑝娑撯偓閺?閵?
   * @param offsetY 閺夌偓澧滈弮鍓佹畱缁旀牜娲挎担宥囆╅敍鍧磒閿涘奔绗傞幏澶夎礋鐠愮噦绱氶垾鏂衡偓?閸欘亞鏁ら弶銉ュ灲**閺傜懓鎮?*
   * @param velocityY 閺夌偓澧滈弮鍓佹畱缁旀牜娲块柅鐔峰閿涘潉GestureEvent.velocityY`閿涘鈧柡鈧?閸欘亞鏁ら弶銉ュ灲**韫囶偆鏁?*
   */
  private onPullOpenEnd(offsetY: number, velocityY: number): void {
    if (!this.expandState.pullDragging) {
      // 閳?鐠囧﹥鏌囩拋鈩冩殶閿涘牆绐橀弽鍥╊儑閸椾浇顢?`pd=` 閻ㄥ嫭娓堕崥搴ㄥ亝娑擃亝鏆熼敍澶嗏偓鏂衡偓?鐟?`PlayerExpandState.pullDropEnd`閵?
      this.expandState.notePullDropEnd();
      return;
    }
    this.settlePullOpen(
      this.expandState.pullOpenShouldCommit(this.expandState.morphP, offsetY, velocityY));
  }

  /**
   * 鏉╄渹缍橀弶陇鍤滃閬嶅亝閺夆剝澧滈崝鍨絺閺夈儳娈戦弨璺虹啲鐠囬攱鐪伴敍鍫熸緱閹靛妞傜€瑰啫褰ч崣鎴ｎ嚞濮瑰偊绱濈悰銉╂？閻㈠崬锛撶仦鍌涙尡 閳ユ柡鈧?鐟?
   * `PlayerExpandState.requestPullOpenSettle`閿涘鈧?
   */
  @Monitor('expandState.pullSettleVersion')
  onPullSettleRequested(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    this.settlePullOpen(this.expandState.pullSettleCommit);
  }

  // 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓 婢瑰啿鐪板ù顔肩湴闁絼绔村Λ鎺炵礄缂侇參顥ｇ亸渚€娼伴敍澶屾畱**閻欘剛鐝涢弮鍫曟？缁?*閿?60ms閿涘鏀㈤埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧?
  //
  // 缂佹挻鐎敍鍫濐嚠閺嶅洦妫ら悾?1.2.4 閻?`MainPage.MorphOverlayHost`閿涘绱?
  //   璺?娑?鐏?= 閹绢厽鏂佹い浣冨殰瀹告唻绱癭morphP`閿?*350ms `Curve.EaseInOut`**閿涘牅绔存径鍕梾閸旑煉绱氶敍?
  //   璺?娑?鐏?= **婢瑰啿鐪板ù顔肩湴**閿涘潉MorphCoverClone()`閿涘绱癭morphOverlayP`閿?*560ms + 韫囶偄鍤幈銏℃暪**閵?
  //
  // 娑撹桨绮堟稊鍫㈡暏 `@Monitor` 閸樻槒鎷烽妴灞炬尡閺€楣冦€夐柇锝勭鐏炲倸绱戞慨瀣尡娴滃棎鈧稄绱?
  //   閻愮懓鍤幍鎾崇磻闁絾娼捄顖滄畱鐞涖儵妫块崷銊︽尡閺€楣冦€夐柌宀嬬礄`PlaybackPage.playMorphOpenIntro`閿涘绱?
  //   閼?*閹绢厽鏂佹い鐢垫畱 350ms 閺勵垱妲戞禒銈勭瑝鐠佺濮╅惃?*閿涙矖@Monitor` 閺?V2 閻?*瀵倹顒為惄鎴濇儔**閿?
  //   閸ョ偠鐨熼拃钘夋躬閹绢厽鏂佹い鐢稿亝濞嗭紕濮搁幀浣稿晸閸忋儳娈戦崥灞肩鏉烆噣鍣?閳?娑撱倕鐪?閸氬矁鎹?閿涘本鎸遍弨楣冦€夋稉鈧悰宀勫厴娑撳秶鏁ら弨骞库偓?
  //   娑撱倖娼捄顖氭倗閼奉亜鎳℃稉顓濈娑擃亜鐡у▓纰夌窗
  //     璺?閻愮懓鍤幍鎾崇磻 閳?`morphDrive` 閸欐ɑ鍨?`ANIM`閿涘潉playMorphOpenIntro` 缁楊兛绔寸悰宀嬬礆閿?
  //     璺?妫ｆ牠銆?娴滃瞼楠囨い浣冪箲閸ョ偑鈧椒绗呴幏澶嬪絹娴?閳?`morphStage` 閸欐ɑ鍨?`LEAVING`閿涘潉morphBeginLeaving`閿涘鈧?
  //   閳跨媴绗?閹靛瀵氱捄鐔稿闁絾娼捄?*娑撳秷铔嬫潻娆撳櫡**閿涘牆鐣犻崷?`onPullOpenUpdate` 闁插奔绔村В鏂剧閸氬本顒為敍澶涚礉
  //      閹碘偓娴犮儴绻栭柌灞肩瑝韫囧懎鍨?`pullDragging`閵?

  /** 閹绢厽鏂佹い闈涚磻婵?*鐏炴洖绱?*鐞涖儵妫?閳?濞搭喖鐪版潻娆庣鐏炲倷绡冪挧鐤殰瀹搁亶鍋?560ms閵?*/
  @Monitor('expandState.morphDrive')
  onMorphDriveChanged(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    // 閳?2026-10-17 閻滄澘婧€鐠囩粯鏆熼敍姘崇箹娑撯偓閺€顖氬煂鎼存洘婀佸▽鈩冩箒鐞氼偉鍤滃杈╂畱鐎瑰牆宕奸幐鈥茬秶閿涘潉own=1` = 鐠佲晝绮版竟鍐茬湴闁絾娼敍?
    PlaybackPage.ev('OVI', `drive=${this.expandState.morphDrive} stage=${this.expandState.morphStage} ` +
      `p=${this.expandState.morphOverlayProgress().toFixed(3)} own=${this.shellOwnsOverlayTween ? 1 : 0}`);
    // 閳跨媴绗?婢瑰啿鐪伴懛顏勭箒閸掓俺鎹ｆ潻鍥ㄨ癁鐏炲倽藟闂傝揪绱檂settlePullOpen`閿涘妞?*鐠佲晝绮扮€?*閿?
    //    閸氾箑鍨弶鐐"濞屄ょ箖闂冨牆鈧?闁絾娼捄顖欑窗鐞氼偉绻栭柌灞藉冀閸氭垼顩惄?閳ユ柡鈧?婢瑰啿鐪伴崷銊﹀Ω濞搭喖鐪扮悰銉ュ煂 0閿涘牆娲栧鐧哥礆閿?
    //    閼板矁绻栭柌灞藉嫉鐞涖儱鍩?1閿涘奔琚辩仦鍌涙煙閸氭垹娴夐崣宥冣偓浣筋潎閹扮喐妲?鐏忎線娼版稉宥堝仐閸ョ偛骞?閵?
    if (this.shellOwnsOverlayTween) {
      return;
    }
    this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
  }

  /** 閹绢厽鏂佹い闈涚磻婵?*閺€鎯版崳** 閳?濞搭喖鐪版潻娆庣鐏炲倷绡冮幐澶庡殰瀹搁亶鍋?560ms 閺€璺烘礀鐠ч鍋ｉ妴?*/
  @Monitor('expandState.morphStage')
  onMorphStageChanged(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    if (this.expandState.morphStage !== MorphStage.LEAVING) {
      return;
    }
    // 閳?2026-10-17 閻滄澘婧€鐠囩粯鏆熼敍姘暪鐠х柉绻栨稉鈧弨顖滄畱濞搭喖鐪版潻娑樺娑?閺勵垰鎯佸鑼额潶閸楃姷鏁?
    PlaybackPage.ev('OVC', `stage=${this.expandState.morphStage} ` +
      `p=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
      `bridging=${this.expandState.morphOverlayBridging() ? 1 : 0}`);
    this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
  }

  /**
   * 閺€璺虹啲鐞涖儵妫块敍姝漮mmit = 閹恒劌鍩岄柧鐑樺姬楠炴儼鎯ょ€规熬绱遍崥锕€鍨悰銉╂？閸ョ偠鎹ｉ悙骞库偓浣锋唉鏉╂绯犳担鐘虫蒋閵嗕礁宓忔潪鑺ユ尡閺€楣冦€夐妴?
   *
   * 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤幍鎾崇磻濞屸剝婀佺亸渚€娼?閼冲本娅欓崝銊ф暰"閻ㄥ嫮婀￠弬顓犲仯**閿涘绱?
   *   閸樼喐娼甸惃鍕櫢鐠囨洖鍨庨弨顖炴毐鏉╂瑦鐗遍敍?
   * ```ts
   *   if (!morphUsable) {
   *     pullDragging = true; morphDrive = FINGER;
   *     if (!measureMiniDuringPull(閳?) { 閳ワ箓鍣哥拠?閺€鎯х磾閳? return; }   // 閳?婢惰精瑙﹂幍?return
   *     // 鐞涖儵鍣洪幋鎰 閳?閹哄鍤?if閿?*閽€钘夊煂娑撳娼扮挧鐤夐梻?* 閴?
   *   }
   * ```
   *   閻娼冨▽锟犳６妫版﹫绱?*娴ｅ棜绻栭弶?`return` 閸︺劌顦荤仦?*閿涘潉if (!morphUsable)` 闁絼绔寸仦鍌︾礆閳ユ柡鈧?
   *   閹存垼顕板┃鎰垳閺冭泛鍘涢惇瀣灇娴?閹存劕濮涙稊?return"閵嗗倸顦茬拠鑽も€樼拋銈忕窗**鐞涖儵鍣洪幋鎰閸氬海鈥樼€圭偘绱伴拃钘夊煂鐠х柉藟闂傛挳鍋呮稉鈧▓?*閿?
   *   閹碘偓娴犮儴绻栭弶鈥茬瑝閺勵垱鏌囬悙骞库偓鍌︾礄閻ｆ瑨绻栧▓鍨暈闁插﹥妲告稉杞扮啊鐠侀绗?閹存垳绔存惔锕侇嚖閸掋倛绻冩稉鈧▎?閵嗗偊绱?
   *
   * 閳跨媴绗?閻喐顒滅憰浣筋唶閻ㄥ嫭妲搁敍?*鏉╂瑦娼柌宥堢槸闁炬拝绱?2鑴?2ms閿涘妲搁悙鐟板毊鐠侯垰绶為崬顖欑閼宠姤濡?`morphUsable` 閸欐婀￠惃鍕勾閺?*
   *   閳ユ柡鈧?閻愮懓鍤弮?`pullOpenBegin` 鐠烘垵婀?閹绢厽鏂佹い浣冪箷濞屸剝瀵曟潪?闁絼绔撮崚浼欑礉缂佸牏鍋ｉ柨姘卞仯韫囧懐鍔ч柌蹇庣瑝閸掕埇鈧?
   *   閹碘偓娴?`morphUsable` 閸欐婀℃稊瀣倵**韫囧懘銆?*閺堝绗㈢憲鎸庡Ω濞搭喖鐪伴柇锝勭濡帊绡冪挧鐤崳閺夈儻绱?
   *   閹绢厽鏂佹い鍏告櫠閻?`onAppear` 鐞涖儵鍣洪敍鍧凱laybackPage` 鎼?6.1閿涘绗屾潻娆撳櫡閻ㄥ嫰鍣哥拠鏇熸Ц**娑撱倖娼獮鎯邦攽鐠侯垰绶?*閿?
   *   鐠嬩礁鍘涢幋鎰闁晫鏁遍崥鍕殰鐠愮喕鐭楃挧閿嬵棗閿涘牆绠撶粵澶涚礉闁插秴顦茬拫鍐暏鐎瑰鍙忛敍澶堚偓?
   * @param commit 閺勵垰鎯侀幓鎰唉鐏炴洖绱?
   */
  private settlePullOpen(commit: boolean, attempt: number = 0): void {
    this.expandState.pushMorphTrace(`settle${attempt}${commit ? 'C' : 'A'}`);
    // 閳藉應妲勯埥?2026-10-16閿?*鐞涖儵鍣洪柧鍓ф畱闂傘劍宕叉禍鍡曢嚋闁?*閿涘绱伴崢鐔告降閺?`if (!morphUsable)`閵?
    //   `morphUsable` 閺?`morphInitParams()` 閻?缁犳鍤弶銉ょ啊"閿涘牅绱伴崶鐘辫礋闁偓閸?`onAreaChange`
    //   閸忔粌绨抽崐绗衡偓浣烘晪閼峰厖绗傛稉鈧潪顔炬殌娑撳娈戦崐鑹扳偓灞艰礋閻噦绱氶埇?閻劌鐣犺ぐ?鏉╂顩︽稉宥堫洣鐞涖儵鍣?閻ㄥ嫬鍨介幑顕嗙礉鐞涖儵鍣洪柧鍙ョ窗
    //   **閹绘劕澧犻弨璺轰紣**閿涘矁鈧瞼婀″锝堫嚉閸掋倗娈戦弰?**缂佸牏鍋ｉ柨姘卞仯鏉╂瑦顐奸崚鏉跨俺闁插繐鍩屽▽鈩冩箒**"閵?
    //   閳?閹广垺鍨?`morphEndAnchorReady()`閿涙稓婀″锝囨畱"閸欘垯浜掗拃鎴掔秴"闂傘劍妲?`morphGeomReadyNow()`閵?
    if (!this.expandState.morphUsable || !this.expandState.morphEndAnchorReady()) {
      // 韫囶偊鈧喐婢楅幍瀣╃瘍鐟曚礁鐣幋鎰斧鐏忓搫顕柨姘卞仯鐞涖儵鍣洪敍娑楃瑝閼宠棄鍘涢崚?ANIM 鐎佃壈鍤х悰銉╁櫤閸嬫粍顒涢妴?
      this.expandState.pullDragging = true;
      this.expandState.morphDrive = MorphDrive.FINGER;
      // 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤?鏉╂柨娲栧▽鈩冩箒閸斻劎鏁?閻ㄥ嫭娓堕崥搴濈閺夆€虫礈閺嬫粓鎽?*閿涘绱?
      //   鏉╂瑤绔村▓闈涘帥閸嬫矮琚卞?*閹躲垺鏅?*閿涘苯鍟€閸嬫艾甯弶銉╁亝濞喡に夐柌蹇ョ礄妞ゅ搫绨鍫ュ櫢鐟曚緤绱氶敍?
      //   閳?閼?瑜般垹褰夋导姘崇樈"瀹歌尙绮＄悮顐ｇ閹哄绱檂morphSessionStarted === false`閿涘鈧柡鈧?
      //      閸忕鐎烽弶銉︾爱閿涙碍鎸遍弨楣冦€夐幐鍌濇祰闁絼绔撮崚浼欑礉**閺冄囥€夐棃銏犵杽娓氬娈?`onDisappear`** 鐟欙箑褰傛禍?
      //      閺冪姵娼禒鍓佹畱 `morphReset()`閿涘潉morphGen++`閵嗕梗morphUsable=false`閵?
      //      **`morphSessionStarted=false`**閿涘鈧柡鈧?鐏忓崬鍘?*闁插秵鏌婄挧铚傜濞嗏€冲弳閸?*閿?
      //      閹?`stage/drive` 閹藉棗娲?`ENTERING/FINGER`閿?
      //   閳?閻掕泛鎮楃拫鍐ㄥ斧閺夈儵鍋呭▎?`measureMiniDuringPull` 鐞涖儵鍣洪敍鍫濈暊鐟曚焦鐪?`stage=ENTERING &&
      //      drive=FINGER`閿涘本澧嶆禒銉㈡喖韫囧懘銆忛崷銊ュ閿涘鈧?
      //   閳跨媴绗?妞ゅ搫绨崣宥勭啊 閳?鐞涖儵鍣洪惄瀛樺复鐞氼偄鐣ч崡顐ｅ閹哄绱欓棃娆撶帛鏉╂柨娲?false閿涘鍣?闁插秷鐦?12 濞嗏€冲弿鎼寸喆鈧?
      if (!this.expandState.morphSessionStarted) {
        this.expandState.pushMorphTrace('reEnter');
        Logger.info(RzdShellLogTag,
          `pull settle: re-enter morph session (was reset by an onDisappear) attempt=${attempt}`);
        if (!this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0)) {
          // 閸戠姳缍嶆潻妯绘Ц闁插繋绗夐崚甯窗娣囨繃瀵?`ENTERING/FINGER`閿涘矁顔€娑撳娼伴惃鍕夐柌蹇斿絹閸?return 閸樼粯甯撻梼鐔煎櫢鐠?
          this.expandState.pullDragging = true;
          this.expandState.morphDrive = MorphDrive.FINGER;
        }
      }
      if (!this.expandState.measureMiniDuringPull(this.getUIContext(), this.navDepth > 0)) {
        if (attempt < PULL_ANCHOR_RETRY_MAX) {
          setTimeout((): void => {
            // 閳藉應妲勯埥?2026-10-16閿?*"閻愮懓鍤?鏉╂柨娲栧▽鈩冩箒閸斻劎鏁?閻ㄥ嫭娓堕崥搴濈閺夆€虫礈閺嬫粓鎽?*閿涘绱?
            //   鏉╂瑩鍣烽崢鐔告降閺?`if (isShowPlay && morphGenAlive(pendingGen))`閵?
            //   閳跨媴绗?`morphGenAlive` 閸︺劍婀伴崷鐑樻珯娑?*韫囧懐鍔ф稉鍝勪海**閿涘奔绨弰顖涙殻閺夛繝鍣哥拠鏇㈡懠閸︺劎顑?1 閹峰秴姘ㄩ弬顓熷竴閵?
            //   閳?娣囶喗纭堕敍?*鐎瑰牆宕兼稉宥堫洣閹稿倷绗樻禒锝呭娇**閵嗗倷绗樻禒锝呭娇閸︺劏绻栭柌宀€娈戠拠顓濈疅閺?鏉╂瑤绔存潪顔荤窗鐠囨繃妲搁崥锕佺箷閺堝鏅?閿?
            //     閼?閻劍鍩涙潻妯烘躬閹绢厽鏂佹い?閿涘潉isShowPlay`閿涘澧犻弰顖滄埂濮濓絿娈戦張澶嬫櫏閹冨灲閹诡噯绱?
            //     娑擃參鈧棁顫?`morphReset()` 濞撳懓绻冩稉鈧▎鈽呯礉闁插秷鐦幒銉ф絻閹跺﹤鍤戞担鏇㈠櫤閸ョ偞娼甸崡鍐插讲閵?
            //     閳跨媴绗?閸欘亜婀?`!isShowPlay`閿涘牏鏁ら幋宄板嚒缂佸繒顬囧鈧幘顓熸杹妞ょ绱氶弮鑸靛閺€鎯х磾閵?
            if (this.appState.isShowPlay) {
              this.settlePullOpen(commit, attempt + 1);
            } else {
              Logger.info(RzdShellLogTag,
                `pull settle: aborted (player gone) attempt=${attempt}`);
            }
          }, PULL_ANCHOR_RETRY_MS);
        } else {
          Logger.warn(RzdShellLogTag, 'pull settle: end anchor unavailable, immediate landing');
          this.expandState.pullDragging = false;
          // 閳藉應妲勯埥?2026-10-16閿?*閻撗勬儔閺冪姷鏅幎?閸戠姳缍嶅姝岀箼濞岋繝鍣洪崚?瑜版捇鈧偓閸栨牞鐭惧?*閿涘绱?
          //   鏉╂瑦顔岄崢鐔告降閺?`morphReset()` + commit 閺冭泛鍟€ `morphSettleOpen()`"閳ユ柡鈧?
          //   閼奉亞娴夐惌娑氭禈閿涙瓪morphReset()` 閹跺﹤鍤戞担鏇熺閹存劖浜界粵澶涚礄`morphUsable = false`閿涘绱?
          //   缁毖勫复閻偓閻?`morphSettleOpen()` 閸愬懘鍎?`applyMorphProgress(1)` 閸欏牆娲滄稉?
          //   `morphGeomReady` 娑撳搫浜ｉ懓?*娴犫偓娑斿牓鍏樻稉宥呬粵** 閳?鐎圭懓娅掗崑婊冩躬閹帞鐡戦妴浣烘祲娴ｅ秴宓堥弰?OPEN閵?
          //   閺冪姷鏅惃鍕經瀵板嫭娲块獮鎻掑櫍閿涘潉wujie.pa` 閻?`pickCapsuleRect` 闁絾顔岄敍姘跺櫤娑撳秴鍩岀亸?
          //   閵?*閺堫剚顐奸柅鈧崶鐐存珮闁?push(閺冪姴鑸伴崣?**閵嗗稄绱氶敍?*闁插繋绗夐崚鏉挎皑瑜拌绨虫稉宥堫洣鏉╂瑥顨滈崝銊ф暰**閿?
          //   鐠佲晜鎸遍弨楣冦€夋禒銉︿航缁涘鍤戞担鏇樷偓涓盤EN 閻╅晲缍呭锝呯埗閺勫墽銇氶敍宀冣偓灞肩瑝閺勵垳鏆€娑撯偓娑擃亜宕愬鑽ゆ畱瑜般垹褰夋导姘崇樈閵?
          this.expandState.pushMorphTrace('noGeom');
          this.expandState.morphReset();
          this.expandState.morphStage = MorphStage.OPEN;
          this.expandState.morphP = 1;
          // 鍚屽€艰惤浣嶏紙`contentP` = 涓婃父 `PlayerPage.pullT` 鈮?`MainPage.morphT`锛夈€?
          this.expandState.contentP = 1;
          if (!commit) {
            this.appState.isShowPlay = false;
          }
        }
        return;
      }
      // 鐞涖儵鍣洪幋鎰 閳?閺佸懏鍓?*娑?return**閿涘矁鎯ゆ稉瀣箵鐠х兘鍋呮稉銈嗘蒋鐞涖儵妫块敍鍫ｎ潌娑撳﹪娼伴柇锝嗩唽濞夈劑鍣撮敍澶堚偓?
      this.expandState.pushMorphTrace('measOk');
      Logger.info(RzdShellLogTag,
        `pull settle: remeasured at attempt=${attempt} usable=${this.expandState.morphUsable} ` +
        `stage=${this.expandState.morphStage}`);
    }
    const duration: number = commit ? PULL_OPEN_SETTLE_MS : PULL_OPEN_ABORT_MS;
    // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MorphGuard.animateMorph` 閻ㄥ嫮顑囨稉鈧崣銉礆閿涙碍濡?闁板秷澹婄€瑰娼ょ粣妤€褰?
    //   閹恒劌鍩?*鏉╂瑦娼悰銉╂？缂佹挻娼?*閿涘潉quietMs` 閻劏藟闂傜鍤滃杈╂畱閺冨爼鏆?閳ユ柡鈧?閺冪姷鏅柇锝勬櫠娑旂喐妲搁幐澶庣殶閻劎鍋ｆ导鐘垫畱閿?
    //   閺堫剙顦╁▽鈩冩箒娴犺缍嶉弬浼粹偓鐘茬埗闁插骏绱氶妴鍌楀櫩 鐏炴洖绱戦崝銊ф暰鐠烘垹娼冮惃鍕閸?娑撳﹨澹?瀵扳偓閸氬孩灏撻敍灞肩瑝娴兼艾婀崝銊ф暰娑擃參鈧棁鐑﹂懝?
    //   閿涘牆褰囬懝鍙夋Ц瀵倹顒為惃鍕剁礉閹广垺鐡曢柇锝勭閹峰秴鐣犻弸浣稿讲閼宠姤顒滄總鍊熸儰閸︺劌鐫嶅鈧崝銊ф暰娑擃參妫块敍澶堚偓?
    this.expandState.markMorphQuiet(duration);
    this.expandState.pushMorphTrace('tween');
    this.expandState.pullDragging = false;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // 閳藉應妲?濞搭喖鐪伴幏鐤鏉╂瑤绔寸仦鍌濊泲**鐎瑰啳鍤滃?*閻ㄥ嫭妞傞梹?閺囪尙鍤庨敍?60ms + 韫囶偄鍤幈銏℃暪閿涘苯顕弽鍥ㄦ￥閻?`animateMorphT`閿涘绱?
    //   娑撳簼绗呴棃銏ｇ箹閺?300/180ms 閻?*閹绢厽鏂佹い?*鐞涖儵妫?*閸氬矁鎹?*閿涘牆鎮撴稉鈧敮褋鈧礁鎮撴稉鈧稉顏冩崲閸旓繝鍣锋稉銈勯嚋 `animateTo`閿涘鈧?
    //   閳跨媴绗?閹绢厽鏂佹い鐢稿亝閺?*閸欙附婀佹稉鈧總妤佹殶閸?*閿涙瓪PULL_OPEN_SETTLE_MS` / `PULL_OPEN_ABORT_MS`
    //      閿?026-10-15 鐠?= 閺冪姷鏅?`SETTLE_MS` 400 / 400閿涘矁顫嗛柇锝勮⒈娑擃亜鐖堕柌蹇曟畱濞夈劑鍣撮敍澶堚偓?
    //   鐠ч鍋ｉ崣鏍ㄨ癁鐏?*瑜版挸澧?*鏉╂稑瀹抽敍鍫ｇ閹靛浠犻崷銊ユ憿閸庡灝姘ㄦ禒搴℃憿閸庢寧甯撮惈鈧挧甯礆閵?
    this.expandState.morphOverlayTweenTo(commit, this.getUIContext());
    // 閳?2026-10-17閿?*濞搭喖鐪版潻娆庣濡帞娈戦悳鏉挎簚鐠囩粯鏆?* 閳ユ柡鈧?閻劍鍩涢妴灞界殱闂堛垼绐￠惈鈧幘顓熸杹閸ｃ劏铔嬮妴浣圭梾閺堝瀚粩瀣棧鐞涘被鈧秴鐣鹃幀褏鏁ら敍?
    //   `from=` 閺勵垵绻栨稉鈧Λ?*鐠ч攱澧滈柇锝勭閸?*閻ㄥ嫭璇炵仦鍌濈箻鎼达讣绱盽p=` 閺勵垱鎸遍弨楣冦€夋潻娑樺閿?
    //   閼?`from=0` 閼?commit=1 閳?鐎瑰啯婀扮拠銉ょ矤鏉╄渹缍橀弶鈥虫妇閸﹀牓顥ｉ崚鐗堟尡閺€楣冦€夌亸渚€娼伴敍?閳?閿涘绱?
    //   閼?`from=1` 閳?瀹歌尙绮＄拹鏉戞躬婢堆冪殱闂堫澀缍呯純顕嗙礄鐞涖儵妫挎导姘愁潶 `|to-from|<1e-4` 閺冣晠鈧偓閹哄绱濈粵澶夌艾**娑撳秹顥?*閿涘鈧?
    PlaybackPage.ev('OVS', `commit=${commit ? 1 : 0} from=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
      `p=${this.expandState.morphP.toFixed(2)} bridging=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
      `host=${this.expandState.hostsMorphOverlay() ? 1 : 0}`);
    // 閺嶅洩顔?濞搭喖鐪版潻娆庣濡帞娈戠悰銉╂？閻㈠崬锛撶仦鍌氬絺鐠?閿涙瓪@Monitor('expandState.morphDrive')` 閸︺劋绗呴棃銏ゅ亝鐞?
    // 閹?drive 缂冾喗鍨?ANIM 娑斿鎮?*娑旂喍绱?*鐞氼偉袝閸欐埊绱濆▽鈩冩箒鏉╂瑤閲滈弽鍥唶閻ㄥ嫯鐦界€瑰啩绱伴崘宥堟崳娑撯偓閺?*閺傜懓鎮滈崣顖濆厴閻╃寮?*閻?
    // 濞搭喖鐪扮悰銉╂？閿涘牆娲栧褰掑亝閺壜ょ熅濮濓絾妲告俊鍌涱劃閿涘鈧倹鐖ｇ拋鏉挎躬鐞涖儵妫跨紒鎾存将/鐞氼偅鏌婄悰銉╂？閸欐牔鍞弮鑸电閹哄鈧?
    this.shellOwnsOverlayTween = true;
    setTimeout((): void => {
      this.shellOwnsOverlayTween = false;
    }, PlayerExpandState.MORPH_OVERLAY_DURATION_MS + 20);
    // 閳?2026-10-16閿涙俺绻栭柌灞藉斧閺夈儴绻曢幑鏇″箯娴滃棔绔存稉?`gen` 娓氭稐琚辨径鍕暓閸楊偆鏁ら敍娑㈠亝娑撱倕顦╃€瑰牆宕煎鍙夊瘻 鎼?02/鎼?03
    //   閺€瑙勫灇閸?`isShowPlay`閿涘牅绗樻禒锝呭娇娴兼俺顫?閺冄冪杽娓氬宓忔潪鐣屾畱 morphReset"閹恒劑鐝敍灞肩瑢閻劍鍩涢幇蹇撴禈閺冪姴鍙ч敍?
    //   閳?`gen` 娑撳秴鍟€闂団偓鐟曚緤绱濋崚鐘冲竴婢圭増妲戦敍鍦搑kTS 鐎佃婀担璺ㄦ暏閻ㄥ嫬鐪柈銊ュ綁闁插繗绶濇稉銉︾壐閿涘瞼鏆€閻偓娴兼俺顫﹂棃娆愨偓浣告啞鐠€锔肩礆閵?
    this.getUIContext().animateTo({
      // 閺冪姷鏅?Tokens 閻ㄥ嫭鐖ｉ崙鍡樻闂€鍖＄窗180ms 瀵邦喕姘︽禍?/ 300ms 娑撴槒娴嗛崷?
      duration: duration,
      curve: curves.cubicBezierCurve(commit ? 0.23 : 0.68, 1.0, commit ? 0.32 : 0.77, 1.0)
    }, (): void => {
      this.expandState.applyMorphProgress(commit ? 1 : 0);
    });
    if (commit) {
      // 閳跨媴绗?閻╅晲缍呴崷?*鐞涖儵妫挎稊瀣樆**閺€鐧哥窗`morphSettleOpen()` 娴兼碍濡?閺勵垰鎯佺憗浣稿"缂堢粯鍨?false閿?
      //    閺€鎹愮箻 animateTo 闂傤厼瀵橀柌灞肩窗鐠佲晞绻栫粔宥囶瀲閺侊絽鐫橀幀褌绡冮崢璇叉倖鐞涖儵妫块妴?
      setTimeout((): void => {
        // 閳藉應妲勯埥?2026-10-16閿?*閸氬奔绔撮弶鈥虫礈閺嬫粓鎽奸惃鍕儑閸ユ稑顦?*閿涘绱?
        //   鏉╂瑩鍣烽崢鐔告降閺?`if (isShowPlay && morphGenAlive(gen))`閵?*娑撳酣鍣哥拠鏇㈠亝閺夆€崇暓閸楊偄鎮撴稉鈧稉顏呯樅閻?*閿?
        //   `morphGen` 娴兼俺顫?閺冄囥€夐棃銏犵杽娓氬娈?`onDisappear` 閺冪姵娼禒?`morphReset()`"閹恒劑鐝敍?
        //   閼板矂鍋呮稉顏勫斧閸ョ姳绗?閻劍鍩涙潻妯诲厒娑撳秵鍏傞惇瀣尡閺€楣冦€?濮ｎ偅妫ら崗宕囬兇閵?
        //   閳?娑撯偓閺冿箑鐣犻崣姗堢礉`morphSettleOpen()` 鐞氼偉鐑︽潻?閳?**閻╅晲缍呴崑婊冩躬 ENTERING閵嗕梗morphUsable` 娣囨繃瀵旈惇?*
        //     閳?`morphClipping()` 閹帞婀?閳?鐎圭懓娅掓稉鈧惄鏉戜粻閸︺劍娓堕崥搴ㄥ亝娑撯偓鐢呮畱 `scale/translate/clip`
        //     閳?鐟欏倹鍔呯亸杈ㄦЦ閵?*閼冲本娅欓弫鏉戠潌閵嗕礁鐨濋棃顫秴缂冾喕绗夌€?*閵嗗秲鈧?
        //   閳?閺€瑙勭《閿涙艾褰ч崚?`isShowPlay`閿涙稑鍟€鐞涖儰绔撮弶?`geomReady` 閳ユ柡鈧?**閸戠姳缍嶅▽鈥虫皑缂侇亝妞傛稉宥堝厴閽€鎴掔秴**
        //     閿涘牆鎯侀崚娆庣窗閹跺﹣绔寸敮?濞岋繝鍣烘?閻ㄥ嫪鑵戦梻瀛樷偓浣告祼鐎规矮绗呴弶銉礆閵?
        //   閳藉應妲?2026-10-16閿涘牅绨╁▎陇顓瑰锝忕礆閿涙俺绻栨稉鈧弶鈥冲灲閹诡喖甯弶銉︽Ц `morphUsable`閵嗗倷绲?`morphUsable`
        //     娴兼艾娲滄稉?闁偓閸?`onAreaChange` 閸忔粌绨抽崐?閼板奔璐熼惇鐕傜礄鐟?`morphIntroAnchorsReady` 閻ㄥ嫭鏁為柌濠忕礆閿?
        //     鐎?*娑撳秷鍐绘禒?*鐠囧瓨妲?缂佸牏鍋ｉ柨姘卞仯閻喓娈戦柌蹇撳煂娴?閵嗕繖morphGeomReady()` 閹靛秵妲搁弮鐘垫櫕
        //     `pullGeomReady` 閻ㄥ嫮鐡戞禒椋庡⒖閿涘牆褰ч崷?`measureMiniDuringPull` 闁插繐鍩岀紒鍫㈠仯闁絼绔撮幏宥囩枂娴ｅ稄绱?
        //     閳?閽€鎴掔秴闂傘劌绻€妞よ崵鏁ょ€瑰喛绱濋崥锕€鍨导姘Ω"閸楀﹣鍞ら崙鐘辩秿"閽€钘夌暰閹?OPEN閵?
        if (this.appState.isShowPlay && this.expandState.morphGeomReadyNow() &&
          this.expandState.morphUsable && !this.expandState.reverseInFlight) {
          this.expandState.pushMorphTrace('settled');
          this.expandState.morphSettleOpen();
        } else {
          this.expandState.pushMorphTrace('settleSkip');
          Logger.info(RzdShellLogTag,
            `pull settle: skip morphSettleOpen showPlay=${this.appState.isShowPlay} ` +
            `usable=${this.expandState.morphUsable} geomReady=${this.expandState.morphGeomReadyNow()} ` +
            `stage=${this.expandState.morphStage}`);
          // 閳藉應妲勯埥?2026-10-16閿涘牅绗屾稉濠囨桨"end anchor unavailable"闁絾娼?*閸氬奔绔撮弶陇顫夐崚?*閿涘绱?
          //   閸戠姳缍嶆慨瀣矒濞岋繝鍣洪崚?閳?閺冪姷鏅惃鍕經瀵板嫭妲搁妴灞炬拱濞嗭繝鈧偓閸ョ偞娅橀柅?push(閺冪姴鑸伴崣?閵嗗秮鈧柡鈧?
          //   韫囧懘銆忛幎濠勬祲娴ｅ秳绮?ENTERING 閺€璺烘礀閺夈儯鈧倸甯弶銉︽Ц**閸欘亝澧﹂弶鈩冩）韫囨ぜ鈧椒绮堟稊鍫ュ厴娑撳秴浠?*閿?
          //   閻╅晲缍呭姝岀箼閸嬫粌婀?ENTERING閵嗕梗morphContainerActive()` 閹帞婀?閳?
          //   閹绢厽鏂佹い鐢稿亝閺壜ょ熅閸欘垵鍏橀幐鍌滄絻娑撯偓娑擃亜宕愬鑽ゆ畱瑜般垹褰夋导姘崇樈閿涘牏鏁ら幋宄扮杽濞村娈?閼冲本娅欓弫鏉戠潌 / 濞屸剝婀侀崝銊ф暰"閿涘鈧?
          //   閳跨媴绗?閸欘亜婀?閻劍鍩涢崷銊︽尡閺€楣冦€?閿涘潉isShowPlay`閿涘妞傞幍宥嗘暪 閳ユ柡鈧?閻劍鍩涘鑼病缁傝绱戦弮鍓佹暠 `popPlayerRoute`
          //     闁絾娼捄顖濆殰瀹歌鲸鏁归敍鍧刴orphReset` 瀹告彃婀?`onDisAppear` 闁插矁绐囨潻鍥风礆閵?
          if (this.appState.isShowPlay && !this.expandState.morphGeomReadyNow()) {
            this.expandState.pushMorphTrace('degrade');
            Logger.warn(RzdShellLogTag,
              'pull settle: geometry never ready 閳?degrade to a plain full-screen player');
            this.expandState.morphReset();
            this.expandState.morphStage = MorphStage.OPEN;
            this.expandState.morphP = 1;
            // 鍚屽€艰惤浣嶏紙闄嶇骇璺緞涔熶笉璁镐袱鏉℃椂闂寸嚎鍒嗗弶锛夈€?
            this.expandState.contentP = 1;
          }
        }
      }, duration + 20);
      return;
    }
    // 濞屄ょ箖闂冨牆鈧》绱扮悰銉╂？閸ョ偠鎹ｉ悙鐧哥礉**閸斻劎鏁鹃幘顓炵暚**閸愬秳姘︽潻妯跨碃娴ｇ姵娼獮璺哄祻鏉炲鈧?
    // 閳跨媴绗?`morphLand()` 娑撳秷鍏橀崷銊ㄋ夐梻缈犵閸撳秷鐨熼敍姝€ANDING 娑斿鎮楅幘顓熸杹妞ゅ灚鏆ｆい鍏哥瑝閸愬秶绮崚?
    //    閿涘潉morphPageOpacity()` 閸?LANDING 鏉╂柨娲?0閿涙稈妲?鐟欎礁鐣犻懛顏勭箒閻ㄥ嫭鏁為柌?閳ユ柡鈧?闁絼閲滈崙鑺ユ殶
    //     **閻╊喖澧犲▽鈩冩箒濞戝牐鍨傞懓?*閿涘本澧嶆禒?娑撳秶鏁?鐎圭偤妾悽?`.visibility(isCollapsing)` 娑?
    //     `morphClipping()` 闁絾娼憗浣稿闂傘劌鍙￠崥灞界杽閻滃府绱氶敍灞惧絹閸撳秷鐨熺亸杈╂箙娑撳秴鍩?缂傗晛娲栭崢?閻ㄥ嫯绻冪粙瀣╃啊閵?
    setTimeout((): void => {
      // 閳藉應妲勯埥?2026-10-16閿?*閸氬奔绔撮弶鈥虫礈閺嬫粓鎽奸惃鍕儑娴滄柨顦?*閿涘绱版稉搴濈瑐闂堛垽鍋呴弶鈥虫倱濞嗘崘顓瑰?閳ユ柡鈧?
      //   閸樼粯甯€ `morphGenAlive`閿涘牆鐣犳导姘愁潶"閺冄囥€夐棃銏犵杽娓氬宓忔潪鑺ユ閻?`morphReset()`"閹恒劑鐝敍?
      //   娑?閻劍鍩涙潻妯诲厒娑撳秵鍏傞幍鎾崇磻閹绢厽鏂佹い?閺冪姴鍙ч敍澶堚偓鍌濆鏉╂瑩鍣风悮顐ヮ嚖閹凤讣绱濋幍瀣◢濞屸€冲煂闂冨牆鈧偐娈戦崶鐐茶剨
      //   鐏忓彉绱?*閸嬫粌婀崡濠呯熅**閿涘牊鎸遍弨楣冦€夐幐鍌氭躬娑撯偓閸фぞ鑵戦梻鏉戙亣鐏忓繒娈戠粣妤€褰涙稉濞库偓浣界碃娴ｇ姵娼稊鐔剁瑝娴溿倛绻曢敍澶堚偓?
      if (!this.appState.isShowPlay) {
        return;
      }
      this.expandState.morphLand();
      this.appState.isShowPlay = false;
      this.expandState.morphReset();
    }, duration + 20);
  }

  /** 閹靛濞嶇悮顐ら兇缂佺喐濮犵挧甯窗閸ョ偛鑴婇崚鎷屾崳閻愮懓鑻熼崡姝屾祰閿涘牆鎯侀崚娆愭尡閺€楣冦€夋导姘閻╁瓨瀵曢崷銊ㄧ碃娴ｇ姵娼柇锝勭鐏忓繐娼℃稉濠忕礆閵?*/
  private onPullOpenCancel(): void {
    if (!this.expandState.pullDragging) {
      // 閳?娑?`onPullOpenEnd` 閸氬本妫岄敍鍫ュ厴閺?閺€璺虹啲鐞氼偅瀚?閿涘鍣?鐠佲€冲煂閸氬奔绔存稉顏呮殶娑撳绱濈憴?`pullDropEnd`閵?
      this.expandState.notePullDropEnd();
      return;
    }
    this.settlePullOpen(false);
  }

  /**
   * 閳藉應妲勯埥鍛 2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MainPage` 閻ㄥ嫬鎻╅悡褎鏁圭紓鈺傝癁鐏炲偊绱漙wujie.pa:162465-162707`閿涘绱?
   * 閵嗗矂娼幍瀣◢閸忔娊妫撮妴? 閹跺﹥鎸遍弨楣冦€夐弽纭呭Ν閻愬湱娈戞稉鈧?*濠婏紕鐛ヨ箛顐ゅ弾**缂傗晛鍩屾潻铚傜稑閺壜ゅ厡閸ュ绱濋崥灞炬濞ｂ€冲毉閵?
   *
   * ## 娑撹桨绮堟稊鍫濈箑妞ょ粯妲告潻娆愮壉閿涘牏鏁ら幋椋庮儑 閳?閺壜扳偓灞炬箒閼冲本娅欐担鍡樻Ц妤傛ê瀹抽悧閫涚秵閵嗗秶娈戝锝埿掗敍?
   * 閹存垳婊戦崢鐔告降閿涘牅浜掗崣濠勫箛閸?*娑撳濯?*闁絾娼捄顖欑矝閻掕绱氶弰?*閸斻劍妞块惃鍕尡閺€楣冦€?*閿涙碍鏁肩憗浣稿缁愭褰?+ 缂傗晜鏂侀妴?
   * 閸欘亣顩?鐟佷礁澹€缁愭褰涙妯哄"娑?缂傗晜鏂?閺堝绔撮悙閫涚瑝閸氬本顒為敍灞界潌娑撳﹤姘ㄩ弰?閺堝鍎楅弲顖樷偓浣风稻閸欘亜澧垮鍫㈢叝閻ㄥ嫪绔撮弶?閵?
   * 閺冪姷鏅惃鍕姜閹靛濞嶉崗鎶芥４**閺嶈婀版稉宥呭З濞插銆夐棃?*閿涙艾鐣犻崷?`closeWithAnimation()` 闁?
   * `componentSnapshot.get(PLAYER_ROOT_ID, 浣?` 閹峰秳绔村鐘叉禈閿涘瞼鍔ч崥?`nav.pop(false)` 閹跺﹪銆夐棃銏犲祻閹哄绱?
   * 閸愬秷顔€**鏉╂瑥绱堕崶?*缂傗晙绗呴崢?閳?閸ラ箖鍣烽惃鍕剹閺咁垯绗岀亸渚€娼?*閸氬本鐦笟瀣╃鐠ч缂?* 閳?闁絿顫掕ぐ銏㈠Ц**娑撳秴褰查懗?*閸戣櫣骞囬妴?
   *
   * ## 闁劖娼€靛湱鍙庨敍鍫濆弿闁劎娲跨拠浼欑礉鐟?`MorphShrinkState` 閺傚洣娆㈡径杈剧礆
   * ```
   *   If (shrink.visible && shrinkPixmap !== undefined) {          // 162466-162492
   *     Column()
   *       .width('100%')                                            // 162726-162733
   *       .clip(true)                                               // 162734-162741
   *       .height(shrink.clipHeight)                                // 162742-162751
   *       .borderRadius(shrink.radius)                              // 162752-162761
   *       .scale({ x/y: shrink.scaleValue })                        // 162762-162777
   *       .translate({ x: shrink.translateX, y: shrink.translateY })// 162778-162793
   *       .opacity(shrink.opacity)                                  // 162794-162803
   *       .hitTestBehavior(HitTestMode.None)                        // 162804-162812
   *       { Image(shrinkPixmap)                                     // 162820-162828
   *           .width(閺佸鐛ョ€?.height(閺佸鐛ユ?                          // 162829-162862閿涘牆娴橀幁鎺嶈礋閺佸鐛ラ敍?
   *           .objectFit(ImageFit.Cover)                            // 162863-162871
   *           .syncLoad(true) }                                     // 162872-162879
   *   }
   * ```
   * 閳跨媴绗?闁絼閲?`Column` 閻ㄥ嫬顔旀惔锔芥Ц `'100%'`閿? 閺佸鐛ョ€规枻绱?*娑撴棃娼悥?`Stack` 閻ㄥ嫬涔忔稉濠咁潡鐎靛綊缍?*
   *    閳ユ柡鈧?`MorphShrinkState` 闁插矂鍋呯紒?`endTx/endTy` 濮濓絾妲搁幐?缂佹洝鍤滈煬顐¤厬韫囧啰缂夐弨?閸欏秷袙閸戠儤娼甸惃鍕剁礉
   *    娑撱倛鈧懏妲告稉鈧€电櫢绱?*娑撳秷顩?*缂佹瑥鐣犻崝?`.position()` 閹存牗鏁肩€靛綊缍堥弬鐟扮础閵?
   * 閳跨媴绗?閺佹潙鐪版稉宥呮倖娴滃娆㈤敍鍫濆彠閹绢厽鏂侀崳銊ф畱閻剟妫块敍灞肩瑓闂堛垻娈戞＃鏍€夌憰浣虹彌閸掕褰查悽顭掔礆閵?
   */
  @Builder
  private ShrinkOverlayHost() {
    if (this.shrinkState.visible && this.shrinkState.pixmap !== undefined) {
      // 閳跨媴绗?婢舵牕鐪?`Stack` 韫囧懘銆忛弰?**`Alignment.TopStart` + 閺佸鐛ラ惄?*閿?
      //   `MorphShrinkState` 闁絿绮?`endTx/endTy` 閺勵垱瀵?`Column` 閺堫亞缂夐弨鐐閸?`x閳溂0,W], y閳溂0,C]`"
      //   閸欏秷袙閸戠儤娼甸惃鍕剁礄鐟欎線鍋呮稉顏呮瀮娴犺泛銇旈惃鍕嚠鐠愶讣绱氶垾鏂衡偓?闂堢姷鍩楃€圭懓娅掗惃?*瀹革缚绗傜憴鎺戭嚠姒?*閹靛秵鍨氱粩瀣ㄢ偓?
      //   閻╂帒鏄傜€靛摜鏁?*鐎圭偞绁寸粣妤€褰涚亸鍝勵嚟**閺勬儳绱＄紒娆欑礄娑撳骸褰熸径鏍︾瑏娑擃亝璇炵仦鍌氭倱娑撯偓婢跺嫪鎱ㄥ锝忕窗娑撳秶绮扮亸鍗炲涧缁涘绨€瑰鍙忛崠杞扮閸愬懘鍋呴崸妤嬬礆閵?
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          Image(this.shrinkState.pixmap)
            // 閸ョ偓浜芥稉?*閺佸鐛?*閿涘牊妫ら悾?`162829-162862` 鐏忚鲸妲?`px2vp(windowWidth_px/Height_px)`閿?
            .width(this.expandState.windowWidthVp > 0 ?
              this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
            .height(this.expandState.windowHeightVp > 0 ?
              this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
            .objectFit(ImageFit.Cover)
            .syncLoad(true)
        }
        .width(StyleConstants.FULL_WIDTH)
        .clip(true)
        .height(this.shrinkState.clipHeight)
        .borderRadius(this.shrinkState.radius)
        .scale({ x: this.shrinkState.scaleValue, y: this.shrinkState.scaleValue })
        .translate({ x: this.shrinkState.translateX, y: this.shrinkState.translateY })
        .opacity(this.shrinkState.opacity)
      }
      .width(this.expandState.windowWidthVp > 0 ?
        this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
      .height(this.expandState.windowHeightVp > 0 ?
        this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .hitTestBehavior(HitTestMode.None)
      .zIndex(SHRINK_OVERLAY_Z_INDEX)
      .id('rzd_shrink_overlay_host')
    }
  }

  /**
   * 瑜般垹褰夐崗瀣畷鐏炲偊绱版潻铚傜稑閺夛繝鍋呴弶?閸忓啩淇婇幁?+ 閹垮秳缍旈崠?閻?*閸擃垱婀?*閿涘矂鎷ら崷銊ョ暊閸樼喐娼甸惃鍕秴缂冾噯绱濋梾蹇氱箻鎼达缚缍呯粔璇茶嫙濞ｂ€冲毉閵?
   *
   * 閸欏秶绱拠鎴滅贩閹诡噯绱檂MiniMorph濞撳弶鐓嬮弬閫涚瑢妞よ泛绨抽弽蹇旇窗閸忋儱鍙曞?md`閿涘绱?
   *   璺?`浣?e` 閸忓啩淇婇幁顖氬帬闂呭棴绱癭position(miniMetaLeft, miniMetaTop)` + `translate({x: coverRightShiftAt(t)})`
   *     + `opacity(metaOpacityAt(t))`閿涘潉clamp(1 - t/0.35)`閿?
   *   璺?`浣?f` 閹垮秳缍旈崠鍝勫帬闂呭棴绱癭translate({y: coverRiseAt(t)})` + `opacity(actionsOpacityAt(t))`
   *     閿涘潉clamp(1 - t/0.20)`閿涘本鐦崗鍐т繆閹垱娲块弮鈺傜Х婢?閳ユ柡鈧?"閸欏厖鏅舵稉澶夐嚋閹稿鎸抽幈銏″弮闂呮劘妫?鐏忚鲸妲告潻娆愭蒋閿?
   *   璺?闂堛垽鍋呮稉鈧Λ鎺炵礄鐏忎線娼伴崗瀣畷閿?*娑旂喎婀潻娆庨嚋婢瑰啿鐪伴柌?*娴?閳ユ柡鈧?鐟?{@link MorphCoverClone}
   *     閿?026-10-15 娴?`PlaybackPage.MorphCoverBridge` 閹碱剚娼甸敍娑楄⒈娓氀呯叐瑜般垹鎮撳┃鎰剁礆閵?
   *
   * 娴ｅ秶些闁插繑妲?*閻╃顕柌?*閿涘潉coverRightShiftAt = coverRight(t) - coverRight(0)`閿涘绱?
   * 閹碘偓娴犮儱鐣犻崣顏冪窗"鐞氼偄鐨濋棃銏″腹閻偓瀵扳偓閸欏疇铔嬮妴浣界閻偓鐏忎線娼板鈧稉濠冨М"閿涘奔绗夋导姘崇儲閸掓澘鍩嗛惃鍕秴缂冾喓鈧?
   */
  @Builder
  private MorphMiniBarClone() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 閳跨媴绗?韫囧懘銆忛崠鍛鐏?*鐎规艾顔旈惃?Row**閿涘牅绗夐弰?Column閿涘绱癭HomeMiniBarPlayerAside` 閻ㄥ嫭鐗撮懞鍌滃仯鐢?
      //    `.layoutWeight(1)`閿涘苯鐣犻崣顏勬躬 Row/Column 闁插瞼鏁撻弫鍫礉閼板奔绗?*閺傜懓鎮滅憰浣割嚠** 閳ユ柡鈧?
      //    閺€鎹愮箻 Column 娴兼俺顔€鐎瑰啯瀵?缁旀牜娲块崜鈺€缍戠粚娲？"閸掑棝鍘ら妴浣姑崥鎴︹偓鈧崠鏍ㄥ灇 wrap-content閿?
      //    缂佹挻鐏夌亸杈ㄦЦ閸欏厖鏅堕柇锝勭瑏娑擃亝瀵滈柦顔芥殻娴ｆ挸涔忕粔浼欑礄閻劍鍩涚€圭偞绁存稉銈嗩偧闁姤妲告潻娆庨嚋閻ュ洨濮搁敍澶堚偓?
      Row() {
        // 涓婃父鎶婂舰鍙橀敋鐐规寕鍦?*鎿嶄綔鍖?*涓婏紙`lx_mini_actions`锛宍wujie.pa:157092`锛夛紝涓嶆槸 meta 閭ｄ竴鍧椼€?
        // 鏈粨閲嶆瀯鍚?`HomeMiniBarPlayerAside` 鍙敾 meta 鈬?鍏嬮殕灞備篃鏀规垚鐢?`MiniBarActions`锛?
        // 杩欐牱閿氱偣鐭╁舰锛坄asideWinW/H`锛変笌鐪熸鐢诲嚭鏉ョ殑涓滆タ鏄悓涓€涓潡銆?
        MiniBarActions({
          playerViewModel: this.miniBarViewModel,
          actionsNodeId: 'rzd_morph_actions_clone'
        })
      }
      .width(this.expandState.asideWinW)
      .height(this.expandState.asideWinH)
      .alignItems(VerticalAlign.Center)
      .position({ x: this.expandState.asideWinX, y: this.expandState.asideWinY })
      // 閹垮秳缍旈崠娲亝娑撯偓濡楋綇绱伴弫鏉戞健閹?`clamp(1 - t/0.20)` 濞ｂ€冲毉閿涘牊瀵滈柦顔煎帥濞屄扳偓浣规瀮鐎涙鎮楀▽鈽呯礆
      .opacity(PlayerExpandState.actionsOpacityAt(this.expandState.morphP))
      // 閳跨媴绗?閸欘亜浠?*缁鹃潧鎮?*娴ｅ秶些閿涘牆寮界紓鏍槯 浣?f 閻?`coverRiseAt`閿涘鈧?
      //    濡亜鎮滈惃?`coverRightShiftAt` 閺勵垳绮?*閸忓啩淇婇幁?*闁絼绔寸仦鍌滄畱閿涘苯顨滈崚鐗堝瘻闁筋喕绗傛导姘愁唨閹稿鎸?
      //    濡亞娼冨鎴濆毉閸?閳ユ柡鈧?閺€鎯版崳閺冩儼銆冮悳鐗堝灇"娑撯偓娑擃亝娈忛崑婊勫瘻闁筋喕绮犵仦蹇撶婢舵牠顥ｆ潻娑欐降"閵?
      .translate({ y: 0 })
      // 鈽呪槄鈽?2026-10-20锛堢収鎼棤鐣岀殑绾靛悜鎸ゅ帇锛夛細鏃犵晫 `morphMiniMeta` / `morphActions` 閮藉啓浜?
      //   `.scale({ x: 1, y: this.morphSquashY })`锛坄椋炲叆娴眰瀹夸富涓庡嚑浣曟彃鍊煎畾绋?md` 搂浜?搂鍏紝
      //   瀵瑰簲瀛楄妭鐮?`wujie.pa:155740-155743`锛夈€傝繖涓€灞傛槸"鍏冧俊鎭?+ 鎿嶄綔鍖?鐨勫厠闅嗭紝
      //   **蹇呴』**璺熻兌鍥婂厠闅嗗悓涓€涓郴鏁帮紝鍚﹀垯鍏虫挱鏀惧櫒鏃?鑳屾澘鍘嬩簡銆佸唴瀹逛笉鍘?銆?
      //   缂╂斁涓績 = 鏈?`Row` 鐨勫嚑浣曚腑蹇冿紙鏃犵晫涔熸病鍐?centerX/centerY锛夈€?
      .scale({ x: 1, y: this.expandState.morphSquashY })
    }
    // 閳藉應妲勯埥?2026-10-16閿涘牅绗?`MorphCoverClone()` **閸氬奔绔存径鍕叏濮?*閿涘瞼鎮婇悽閬嶁偓鎰摟閻╃鎮撻敍澶涚窗
    //   鏉╂瑩鍣烽崢鐔告降閺?`LayoutPolicy.matchParent` 鑴? 閳?閹疯法娈戦弰?*婢瑰啿鐪伴弽?`Stack`** 閻ㄥ嫬鏄傜€甸潻绱?
    //   閼板本鐗?`Stack` **濞屸剝婀?`ignoreLayoutSafeArea`** 閳?鏉╂瑤绔寸仦鍌滄畱閻╂帒鐡欓崣顏嗙搼娴?鐎瑰鍙忛崠杞扮閸?闁絽娼￠妴?
    //   閼板苯鐣犻惃鍕摍閼哄倻鍋ｉ敍鍫滅瑐闂堛垽鍋呮稉?`Row`閿涘鏁ら惃鍕Ц `.position({x: asideWinX, y: asideWinY})`
    //   閳ユ柡鈧?**閸忋劎鐛ラ崣锝呮綏閺?*閿涘牅绗屾潻铚傜稑閺夛繝鍣哄ù瀣倱閸欙絽绶為敍澶嗗櫩 瑜版捁绯犳担鐘虫蒋闂堢姾绻庣仦蹇撶鎼存洟鍎撮敍鍧刟sideWinY 閳?850`閿?
    //   閺冭绱濇潻娆庣閸фぞ绱伴拃钘夋躬鐏炲倻娲呯€?*娑斿顦?* 閳?鐞氼偉顥嗛幒?閳?鐟欏倹鍔呴弰?閸忔娊妫撮弮?*閹垮秳缍旈崠娲亝娑撳閲滈幐澶愭尦娑撳秷顫嗘禍?*"閵?
    //   閳?閻?*鐎圭偞绁寸粣妤€褰涚亸鍝勵嚟**閺勬儳绱＄紒娆欑礄闁插繋绗夐崚鐗堟闁偓閸?`'100%'`閿涘奔绗岄弨鐟板З閸撳秹鈧劕鐡ф稉鈧懛杈剧礆閵?
    .width(this.expandState.windowWidthVp > 0 ? this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
    .height(this.expandState.windowHeightVp > 0 ? this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // 閺佹潙鐪版稉宥呮倖娴滃娆㈤敍姘瑓闂堛垹姘ㄩ弰顖涙尡閺€楣冦€夐敍宀€甯虹€瑰墎娈戦悙鐟板毊韫囧懘銆忛悡褍鐖堕拃钘夊煂閹绢厽鏂佹い鍏哥瑐
    .hitTestBehavior(HitTestMode.None)
    .zIndex(PLAYER_CLONE_Z_INDEX)
    .id('rzd_player_actions_clone_host')
    .onAreaChange((): void => {
      const node = this.getUIContext().getFrameNodeById('rzd_player_actions_clone_host');
      if (node !== null) {
        const point = node.getPositionToWindowWithTransform();
        const size = node.getMeasuredSize();
        Logger.info('RzdPlayerViewport', `clone origin=${point.x},${point.y} sizePx=${size.width}x${size.height}`);
      }
    })
  }

  // 鈽呪槄鈽?2026-10-21锛堢鍏疆锛夛細`miniBarSlotPlaceholder()` **宸插垹闄?*銆?
  //
  // 瀹冨瓨鍦ㄧ殑鍘熷洜鍙湁涓€鏉★細涓婁竴杞妸鎾斁鍣ㄦ惉鍑轰簡 `miniBar` 妲斤紝妲介噷蹇呴』鐣欎竴鍧?
  // 0 楂橈紙鍙屽眰锛? 56 楂橈紙鍗曞眰锛夌殑**閫忔槑鍗犱綅**鍘婚獥 HDS 鎸夊唴瀹归噺鎺掔増銆?
  // 绗叓杞敳鏂瑰彛寰勫凡鏄庣‘銆屼竴绾ч〉鐨勬挱鏀炬潯鍜屼簩绾ч〉鐨勬挱鏀炬潯涓嶆槸涓€涓笢瑗裤€佺粨鏋勫畬鍏ㄤ笉涓€鏍枫€嶏紝
  // 涓婃父 `MainPage` 閭ｄ竴渚э紙`wujie.pa:157082-157228`锛夋槸**鐩存帴鎶?`MiniPlayer` 鏀捐繘妲介噷**锛?
  // 妲介珮澶╃劧鐢卞唴瀹归噺鍐冲畾 鈬?鍗犱綅娌℃湁瀛樺湪鎰忎箟锛坄miniBarBuilder` 鐜板湪缁欑殑灏辨槸 `this.miniBar()`锛夈€?

  // 锛堜笂闈㈣繖娈?JSDoc 鎻忚堪鐨勬槸**宸插垹闄?*鐨?`homeMiniCapsule()`锛屼繚鐣欎細璇 鈬?鏁存绉婚櫎锛?
  //   瀹冧富寮犵殑"鍏夋劅 + 寮逛竴涓嬪繀椤婚潬鎶?HdsTabs 鎼繘鎴戜滑瀛愭爲"宸茶鐢叉柟 2026-10-21 鐨勭粨璁哄彇浠ｏ細
  //   涓€绾ч〉鎸変笂娓镐綇 `miniBar` 妲斤紝寮硅烦钀藉湪妲藉唴瀹逛笂锛岃儗鏉?鍏夋劅浜ょ粰 HDS銆傦級
  // 鈽呪槄鈽?2026-10-21锛堢鍏疆锛夛細`homeMiniCapsule()` **宸插垹闄?*锛堣繛鍚屽畠鐨?
  // `miniBarSlotPlaceholder` / `homeMiniCapsuleWidthVp` / `homeMiniCapsuleRightMarginVp` /
  // `homeMiniCapsuleBottomVp` / `homeMiniCapsuleBoxWidthVp` / `homeMiniBarSingleRow` /
  // `homeMiniBarSlotHeightVp` / `homeMiniBarCoverSideVp` / `secondaryMiniBarCoverSideVp`锛夈€?
  //
  // 瀹冨瓨鍦ㄧ殑鍞竴鐞嗙敱鏄?鎯宠 HDS 鐢荤殑鏉愯川鑳屾澘涔熶竴璧峰脊"锛?026-10-20 绗笁杞級锛?
  // 鎶?`HdsTabs` 鎼繘鎴戜滑鑷繁鐨勫瓙鏍戯紙`MiniBarMaterialCapsule`锛夛紝鍐嶆妸鏁存潯鐢诲湪澹冲眰 `Stack` 閲屻€?
  // 绗叓杞敳鏂瑰凡鏄庣‘锛?*涓€绾ч〉涓庝簩绾ч〉鏄袱濂楃粨鏋勩€佷笉鑳界粺涓€** 鈥斺€?涓婃父 `MainPage`
  // 锛坄wujie.pa:157082-157228`锛夐椤甸偅鏉?*涓嶆槸** `MaterialCapsule`锛屽畠鐩存帴浣忓湪澹冲眰
  // `HdsTabs` 鐨?`miniBar` 妲介噷 鈬?鏈枃浠跺洖鍒颁笂娓哥粨鏋勶細
  //   路 涓€绾ч〉锛歚barFloatingStyle.miniBar.miniBarBuilder = () => this.miniBar()`
  //     锛堝唴瀹?= `MiniPlayer`锛屽昂瀵镐氦缁欐Ы锛汬DS 鎸夊唴瀹归噺缁欐Ы楂橈紝鑳屾澘/鍏夋劅鐢?HDS 鐢伙級锛?
  //   路 浜岀骇椤碉細{@link floatingMiniBar} 鈫?{@link MiniBarMaterialCapsule}锛堣嚜宸变竴涓?HdsTabs 娴姩鑳跺泭锛夈€?
  // 鎸ゅ帇锛堝脊涓€涓嬶級鐨勮惤鐐逛篃鍥犳浠?鑳跺泭閭ｄ竴灞?鍥炲埌"妲藉唴瀹癸紙`MiniPlayer` 鏍癸級"锛岃 {@link miniBar}銆?

  // 鈽呪槄鈽?2026-10-21锛堢鍏疆锛夛細杩欎竴鏁存"鑷畻鑳跺泭鍑犱綍"鐨勫嚱鏁?*鍏ㄩ儴鍒犻櫎** 鈥斺€?
  //   `homeMiniBarSingleRow()` / `homeMiniCapsuleWidthVp()` / `homeMiniCapsuleRightMarginVp()` /
  //   `homeMiniBarSlotHeightVp()` / `homeMiniCapsuleBottomVp()` / `homeMiniBarCoverSideVp()` /
  //   `secondaryMiniBarCoverSideVp()`銆?
  //
  // 涓轰粈涔堬細瀹冧滑鏄?鎶婃挱鏀惧櫒鎼嚭 `miniBar` 妲?鐨勯厤濂楋紙鑷繁绠楀/绂诲簳/鍗曞眰瀹藉害/灏侀潰妗ｄ綅锛夈€?
  // 绗叓杞挱鏀惧櫒鍥炲埌妲介噷涔嬪悗锛岃繖鍥涚被閲忓悇鏈?*鍞竴鏉冨▉鏉ユ簮**锛屼笉璁稿湪鏈枃浠跺啀绠楃浜岄亶锛?
  //   路 鎺掑竷锛堜袱鎺?/ 鍗曟帓锛夆啋 HDS锛歚miniBar.barLayoutMode` + `miniBar.miniBarStyle`
  //     锛坽@link barLayoutModeForHds} / {@link miniBarStyleForHds}锛屼袱涓瓧娈典粛鍦?`miniBar` 閰嶇疆閲岋級锛?
  //   路 妲介珮 鈫?HDS 鎸夊唴瀹归噺锛堝唴瀹硅閽夊湪 `FLOATING_MINI_BAR_HEIGHT_VP` = 涓婃父 `MINI_H` = 56锛夛紱
  //   路 鑳跺泭妯悜鍑犱綍锛堝乏鍙冲唴璺?/ 灏侀潰瑙嗚妗ｄ綅锛夆啋 `HomeMiniBarPlayer` + `HomeMiniBarAlbumCover`
  //     锛坄sidePad = (鑳跺泭楂?鈭?瑙嗚灏侀潰)/2`锛屽皝闈?= 32 鐩?脳 `scale(capsuleH脳0.8/32)`锛夛紱
  //   路 浜岀骇椤佃兌鍥婂 鈫?{@link floatingMiniBarWidthVp} + {@link miniBarBoxRightMarginVp}锛堜粛鍦ㄧ敤锛夈€?

  /**
   * 閳藉應妲?瑜般垹褰?*濞搭喖鐪?*閿涙氨鐢绘鐐茬殱闂堛垻娈?*婢瑰啿鐪伴崗瀣畷**閿涘牆顕弽鍥ㄦ￥閻?`MainPage.MorphOverlayHost.morphCover`閿涘鈧?
   *
   * 鏉╂瑤绔村Λ鎺戝斧閺夈儳鏁鹃崷銊︽尡閺€楣冦€夐崘鍛村劥閿涘潉PlaybackPage.MorphCoverBridge`閿涘鈧倹鎯夐崚鎷岀箹闁插瞼娈戦崢鐔锋礈閺?*閸ф劖鐖ｇ化?*閿?
   * 閹绢厽鏂佹い鐢稿亝娑撯偓閻楀牐顫﹂悽璇叉躬**鐞?scale+translate 閸欐ɑ宕叉潻鍥モ偓浣界箷鐢?`.clip()` 娑撳骸濮╅幀?`.height(morphClipHeight())`
   * 閻ㄥ嫬顔愰崳?*闁插矉绱濋懓灞界暊閹峰灝鍩岄惃鍕叐瑜般垺妲?*缁愭褰涢崸鎰垼** 閳?閸欘亝婀?p=1閿涘牊浜界粵澶婂綁閹诡澁绱氶弮鏈靛紬閺嶅吋顒滅涵顔衡偓?
   * 閸樺棗褰舵稉濠傜暊閸欏秴顦查崙娲６妫版﹫绱?鐏忎線娼伴崜宥呭磹濞堢數婀呮稉宥堫潌""閸ф劖鐖ｉ崣锝呯窞閹恒劑鏁?"鐞氼偄鍩嗛惃鍕帗缁辩姵灏呮担?閿涘鍏橀崙鍝勬躬鏉╂瑤閲滈崜宥嗗絹娑撳鈧?
   * 濞搭喖鐪版潻娆庣娴?*娑撳秴婀柇锝勯嚋鐎圭懓娅掗柌?*閿涙艾鐣犻惄瀛樺复闊搫婀竟鍐茬湴鏉╂瑤閲滃鈥崇潌 Stack 娑撳绱漙morphOverlayCoverBridge()`
   * 缂佹瑧娈戠粣妤€褰涢崸鎰垼鐏忚鲸妲哥€瑰啰娈戠紒妯哄煑閸ф劖鐖ｉ敍?*娑撳秴浠涙禒璁崇秿"妞ら潧鍞?閳?缁愭褰?閹广垻鐣?*閵?
   *
   * 娑撱倕鐪伴崥鍕殰閻ㄥ嫭妞傞梹?閺囪尙鍤庨敍鍫ｇ箹閺?娑撱倕鐪?閻ㄥ嫬鍙ч柨顕嗙礆閿?
   *   璺?閹绢厽鏂佹い鐢稿亝娑撯偓鐏炲偊绱癭morphP`閿?50ms `Curve.EaseInOut`閿?*濞屸€冲З**閿涘绱?
   *   璺?鏉╂瑤绔寸仦鍌︾窗`morphOverlayP`閿?60ms `cubic-bezier(0.23, 1.0, 0.32, 1.0)`閿涘牆鎻╅崙鐑樺弮閺€璁圭礆閵?
   *
   * 閳跨媴绗?閺勯箖娈ｉ梻銊ф暏 `morphOverlayBridging()`閿? `morphBridging()` 閳?鐎瑰じ瀵岀涵顔肩杽閹恒儳顓告禍鍡氱箹娑撯偓濡帪绱氶敍?
   *    **娑撳秵妲?*閺備即鈧姳绔撮幎濠囨，閿涙稐绗佹稉顏勫閺堫剨绱欑亸渚€娼?/ 濮濆苯鎮曞灞惧 / 閹垮秳缍旈崠鐚寸礆閼虫垝绗夐懗钘夋倱閺冭埖鍨氱粩瀣剁礉
   *    娴犮儱寮?鏉╄渹缍橀弶鈩冩拱娴ｆ捁顫﹂崡鐘辩秴妞よ埖甯€閵嗕焦鎸遍弨楣冦€夐惇鐔风殱闂堫澀绗夐悽?鏉╂瑤绗侀弶鈥茬瑝閸欐﹢鍣虹憴浣锋崲閸斺剝濮ら崨濞库偓?
   * 閳跨媴绗?閺佹潙鐪版稉宥呮倖娴滃娆㈤敍鍫滅瑓闂堛垹姘ㄩ弰顖涙尡閺€楣冦€夐敍宀€鍋ｉ崙?閹靛濞嶈箛鍛淬€忛悡褍鐖堕拃钘夊煂閹绢厽鏂佹い鍏哥瑐閿涘鈧?
   */
  @Builder
  private MorphCoverClone() {
    Stack() {
      Image(this.miniBarViewModel.songCoverUrl().length > 0 ?
        this.miniBarViewModel.songCoverUrl() : this.miniBarViewModel.songCover())
        // 閳跨媴绗?閻晛鑸伴惄瀛樺复閺夈儴鍤滈崗鍙橀煩閻樿埖鈧緤绱檝p閿?*缁愭褰涢崸鎰垼**閿涘绱扮€瑰鈧線鐝?*閸掑棗绱戦崣?* 閳ユ柡鈧?
        //    閹绢厽鏂佹い闈涚殱闂堛垹顦婚張?`layoutWeight(1)` + `constraintSize`閿涘矂鍣洪崚鎵畱閻晛鑸版稉宥勭箽鐠囦焦妲稿锝嗘煙瑜邦澁绱?
        //    閹稿顒滈弬鐟拌埌閻㈣绱伴崷銊ㄦ儰娴ｅ秳姘﹀Λ鎺楀亝娑撯偓閸掓槒鐑︽稉鈧稉瀣剁礄閻劍鍩涚€圭偞绁存潻鍥╂畱"缂佹挻娼弮璺虹殱闂堛垹銇囩亸蹇氱儲娑撯偓娑?閿涘鈧?
        .width(this.expandState.morphOverlayCoverBridge().size)
        .height(this.expandState.morphOverlayCoverBridge().height)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.expandState.morphOverlayCoverBridge().radius)
        .clip(true)
        .position({
          x: this.expandState.morphOverlayCoverBridge().x,
          y: this.expandState.morphOverlayCoverBridge().y
        })
        // 鈽呪槄鈽?2026-10-20锛堢収鎼棤鐣岋級锛歚morphCover` 鐨?`.scale.y = coverScaleAt(t) 脳 morphSquashY`
        //   锛坄椋炲叆娴眰瀹夸富涓庡嚑浣曟彃鍊煎畾绋?md` 搂涓夛紱瀛楄妭鐮?`wujie.pa:155724-155745` 鍚屼竴澶勫啓娉曪級銆?
        //   鎴戜滑杩欎竴灞傜殑灏哄鏄?*鐩存帴缁欏楂?*锛堜笉鏄畾杈圭洅 + coverScale锛夛紝鎵€浠ュ彧鍓?squash 杩欎竴椤广€?
        .scale({ x: 1, y: this.expandState.morphSquashY })
    }
    // 閳藉應妲勯埥?2026-10-16閿?*閻撗勬￥閻ｅ本濡告潻娆庣鐏炲倹妯夊蹇涙懙濠娾€冲弿缁愭褰?*閿涘绱?
    //   閸樼喐娼垫潻娆撳櫡閺?`LayoutPolicy.matchParent` 鑴? 閳ユ柡鈧?闁絾妲搁幏?*閻栬泛顔愰崳顭掔礄婢瑰啿鐪伴弽?`Stack`閿涘娈戠亸鍝勵嚟**閿?
    //   閼?*閺?`Stack` 閼奉亜绻侀獮鑸电梾閺?`ignoreLayoutSafeArea`**閿涘牐顫嗙€瑰啰娈戠仦鐐粹偓褑銆冮敍姘涧閺?`.width/.height('100%')`
    //   + `.id(MORPH_HOST_ID)` + 閹靛濞?+ `onAreaChange`閿涘鍣?鏉╂瑤绔寸仦鍌滄畱閻╂帒鐡欓崣顏嗙搼娴?**鐎瑰鍙忛崠杞扮閸?*"闁絽娼￠敍?
    //   濮ｆ梻鐛ラ崣锝呯毈閿涘牅绗傛稉瀣倗鐏忔垳绔存稉顏勭暔閸忋劌灏敍澶堚偓?
    //
    //   閳跨媴绗?閼?`.position({x, y})` 閻劎娈戦弰?*閸忋劎鐛ラ崣锝呮綏閺?*閿涘潉morphCoverRectAt()` 閻ㄥ嫯绶崙鎭掆偓?
    //      娑撳氦绯犳担鐘虫蒋/閹绢厽鏂佹い闈涚殱闂堛垻娈戦柌蹇旂ゴ閸氬苯褰涘鍕剁礆閳?瑜版挸鐨濋棃銏犳躬**鐏炲繋绗傞柈?*閿涘牆鐨濋棃銏ゃ€夐柇锝勭缁?`y 閳?136`閿?
    //      閹?*鐏炲繋绗呴柈?*閿涘牐绯犳担鐘虫蒋闁絼绔寸粩?`y 閳?850`閿涘妞傞敍宀勫厴娴兼俺鎯ら崷銊ㄧ箹鐏炲倻娲呯€?*娑斿顦?*
    //      閳?鐞氼偉顥嗛幒?/ 娑撳秶绮崚?閳?**鐟欏倹鍔呯亸杈ㄦЦ"濞屸剝婀佺亸渚€娼伴崝銊ф暰"**閵?
    //
    //   閳?閻?*鐎圭偞绁寸粣妤€褰涚亸鍝勵嚟**閺勬儳绱＄紒娆欑礄娑?`PlaybackPageRouteShell.boxWidth/boxHeight()` 閸氬本顑欓崑姘《閿?
    //     闁絾妲搁張顑跨波瀹歌尙绮℃宀冪槈鏉╁洨娈?闁剧儤寮х粣妤€褰?閸愭瑦纭堕敍澶涚礉楠炴湹绻氶悾?`ignoreLayoutSafeArea` 閸欏奔绻氶梽鈹库偓?
    //     閳跨媴绗?闁插繋绗夐崚鎵崶閸欙絾妞傞柅鈧崶?`'100%'`閿涘牅绗岄弨鐟板З閸撳秹鈧劕鐡ф稉鈧懛杈剧礉娑撳秳绱伴弴鏉戞▕閿涘鈧?
    .width(this.expandState.windowWidthVp > 0 ? this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
    .height(this.expandState.windowHeightVp > 0 ? this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .opacity(this.expandState.morphOverlayBridgeOpacity())
    // 閺佹潙鐪版稉宥呮倖娴滃娆㈤敍姘瑓闂堛垹姘ㄩ弰顖涙尡閺€楣冦€夐敍宀€甯虹€瑰墎娈戦悙鐟板毊韫囧懘銆忛悡褍鐖堕拃钘夊煂閹绢厽鏂佹い鍏哥瑐
    .hitTestBehavior(HitTestMode.None)
    .zIndex(PLAYER_CLONE_Z_INDEX)
  }

  /**
   * 閸忓鍔呴弽鍥暯閺嶅繑娼楃拹顭掔礄HDS 鐎规ɑ鏌?`systemMaterialEffect`閿涘绱濈捄鐔兼閻滎垰顣ㄩ崗澶嬨€傛担宥冣偓?
   *
   *
   * 閳跨媴绗?鏉╂瑤閲滈崙鑺ユ殶**閸欘亣鍏?*閸犲倻绮?HDS 閻?`titleBar.style.systemMaterialEffect` 閹?
   *    `HdsTabs` 閻?`barFloatingStyle.systemMaterialEffect`閵嗗倸鐣奸弬骞库偓濠冪焽濞寸鍘滈幇鐔峰閼版ぞ绱崠鏍モ偓瀣斧閺傚浄绱?
   *      閵嗗苯鍙炬禒鏍矋娴犳湹绮庨崷?Navigation/NavDestination 閺嶅洭顣介弽蹇斿灗濡亜鎮?Tabs 娑?barPosition 娑?
   *        BarPosition.End 閻ㄥ嫬绨抽柈?TabBar 娑擃厾鏁撻弫鍫涒偓鍌氭躬閸忔湹绮崠鍝勭厵娑擃叀顔曠純顔界焽濞寸鍘滈幇鐔告櫏閺嬫粈绗夐悽鐔告櫏閵嗗倶鈧?
   *    閳?閻╁瓨甯撮幎濠傜暊閹稿倸鍩岄弲顕€鈧艾顔愰崳顭掔礄濮ｆ柨顩ф稉瀣桨闁絾娼?`floatingMiniBar` 閻?Column閿涘绗?*閺勵垯绗夐悽鐔告櫏閻?*閿?
   *    娑撳秷顩﹂柇锝嗙壉閸愭瑣鈧倻鏆€閻偓鐎瑰喛绱濋弰顖欒礋娴滃棗婀?閹跺﹣绨╃痪褎鎸遍弨鐐蒋閹碱剝绻?HdsTabs 閻?miniBar"闁絾娼捄?
   *    閿涘牐顫?{@link floatingMiniBar} 閻ㄥ嫯顕╅弰搴礆闁插矁鍏橀惄瀛樺复婢跺秶鏁ら崥灞肩婵傛銆傛担宥冣偓?
   * @returns HDS 閺夋劘宸濋崣鍌涙殶閿涘潉@since 6.1.0(23)`閿涘畳efault/pc 閻?compatible 閸?閳?23閿涘鈧?
   */
  private ambientTitleMaterial(): SystemMaterialParams {
    switch (this.ambientLevelIndex()) {
      case 1:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.SMOOTH };
      case 2:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.GENTLE };
      case 3:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.EXQUISITE };
      default:
        return { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE };
    }
  }

  /** Bottom inset (vp) for the floating tab bar; smaller on short-height SM layout. */
  private homeTabBarBottomMarginVp(): number {
    const compactLayout: boolean = this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD;
    const liveInset: number = this.windowInfo.navigationBarBottomVp;
    const systemInset: number = liveInset > 0 ? liveInset :
      WindowUtil.getInstance().getStartupNavigationBarBottomVp();
    const base: number = compactLayout ? 16 : systemInset;
    return Math.max(base, systemInset);
  }

  /** Small-width breakpoint (vp) for floating bar responsive layout. */
  private floatingBarSmallWidthVp(): number {
    const wPx = this.windowInfo.windowSize.width;
    if (wPx > 0) {
      const wVp = this.getUIContext().px2vp(wPx);
      return wVp - 96;
    }
    return 264;
  }

  /** Ambient level (0=follow system, 1=weak, 2=balanced, 3=strong). */
  private ambientLevelIndex(): number {
    return this.ambientState.level;
  }

  /**
   * 閸楁洑閲滄い鐢殿劮鐞氼偆鍋ｉ崙?闁鑵戦弮鍓佹畱瀵鐑︾憴锕€褰傜拋鈩冩殶閿涘牊鐦℃稉顏堛€夌粵鍙ョ娑擃亷绱氶妴?
   *
   * `symbolEffect(effect, trigger)` 閺勵垬鈧rigger 閸欐ê瀵茬亸杈ㄦ尡娑撯偓濞喡扳偓宥忕礉閹碘偓娴犮儲鐦℃稉顏堛€夌粵鎯х箑妞?
   * **閸氬嫮鏁ら崥鍕畱鐠佲剝鏆?* 閳ユ柡鈧?閸忚京鏁ゆ稉鈧稉顏嗘畱鐠囨繀琚辨稉顏勬禈閺嶅洣绱版稉鈧挧宄拌剨閿涘牐顔曠拋陇顫夐懠鍐洣閻ㄥ嫭妲搁妴宀勨偓澶夎厬閹降鈧秹鍋呮稉鈧０妤€鑴婇敍澶堚偓?
   *
   * 閳跨媴绗?闂€鍨韫囧懘銆忕粵澶夌艾妞ょ數顒烽弫甯礄閻滄澘婀弰?**4**閿涙碍甯归懡?/ 閻滄澘婀亸鍗炴儔 / 閸ョ偛鎼?/ 閹存垹娈戦敍澶涚窗`TabBarItem` 閹稿绗呴弽鍥у絿閵?
   */
  @Local tabBounceTriggers: number[] = [0, 0, 0, 0];
  /**
   * 閵嗗苯娲栭崚浼淬€婇柈銊ｂ偓宥嗗瘹娴犮倧绱欏В蹇庨嚋妞ょ數顒锋稉鈧稉顏庣礉闁帒顤冪憴锕€褰傞敍澶堚偓?
   *
   * 鐠佹崘顓哥憴鍕瘱閿涙氨鍋ｉ崙?*瑜版挸澧?*妞ょ數顒风憰浣瑰Ω閻ｅ矂娼伴崶鐐寸泊閸掍即銆婇柈?閹稿洤鐣炬担宥囩枂閵嗕繖onTabBarClick` 閸?
   * 閻愮懓鍑￠柅澶夎厬妞ょ數顒烽弮鏈电瘍娴兼俺袝閸欐埊绱濋幍鈧禒銉ょ瑝闂団偓鐟曚礁婀い鐢殿劮闁插矁鍤滃鍗炲 onClick閿涘牓鍋呮导姘ⅵ閺傤參銆夌粵鎯у瀼閹诡澁绱氶妴?
   *
   * 閳跨媴绗?闂€鍨韫囧懘銆忕粵澶夌艾妞ょ數顒烽弫甯礄閻滄澘婀弰?**4**閿涘绱癭HomeTabsPages()` 閹稿绗呴弽鍥у絿閵?
   */
  @Local tabScrollTopCommands: number[] = [0, 0, 0, 0];

  /** 妞ょ數顒烽柅澶夎厬閹礁鑴婄捄绛圭礄BounceSymbolEffect + EffectDirection.DOWN閿涘矁顫嗘惔鏇㈠劥妞ょ數顒风拋鎹愵吀鐟欏嫯瀵栭敍澶堚偓?*/
  private playTabBounce(index: number): void {
    const next: number[] = [...this.tabBounceTriggers];
    next[index] = (next[index] ?? 0) + 1;
    this.tabBounceTriggers = next;
  }

  /** 鐠佲晝顑?index 娑擃亪銆夌粵鍓ф畱妞ょ敻娼伴崶鐐插煂妞ゅ爼鍎撮敍鍫ｎ嚉妞や絻鍤滃杈╂磧閸氼剝绻栨稉顏囶吀閺佸府绱氶妴?*/
  private requestTabScrollTop(index: number): void {
    const next: number[] = [...this.tabScrollTopCommands];
    next[index] = (next[index] ?? 0) + 1;
    this.tabScrollTopCommands = next;
  }

  /** 閻愬綊銆夌粵鎾呯窗閸掑洤鍩岄崚顐ゆ畱妞ょ數顒烽悽?onChange 婢跺嫮鎮婇敍娑氬仯瑜版挸澧犳い鐢殿劮閸掓瑥娲栧姘煂妞ゅ爼鍎撮妴?*/
  private onTabBarClicked(index: number): void {
    if (index === this.tabState.tabIndex) {
      this.playTabBounce(index);
      this.requestTabScrollTop(index);
    }
  }

  /** Single bottom-tab label: icon + title, styled by selection. */
  @Builder
  private TabBarItem(index: number, title: Resource, symbol: Resource) {
    Column({ space: 4 }) {
      SymbolGlyph(symbol)
        .fontSize(22)
        .fontWeight(FontWeight.Regular)
        .height(22)
        .fontColor([this.tabState.tabIndex === index ? this.themeState.color : $r('sys.color.icon_primary')])
        // 闁鑵戦幀浣歌剨鐠虹绱癭trigger` 閸欐ê瀵查崡铏尡娑撯偓濞嗏槄绱欓崣顏呮箒鏉╂瑤閲滄い鐢殿劮閻ㄥ嫯顓搁弫鏉挎躬閸欐﹫绱濋幍鈧禒銉ュ涧閺堝鐣犲鐧哥礆
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN),
          this.tabBounceTriggers[index])
      Text(title)
        .fontSize(11)
        .fontColor(this.tabState.tabIndex === index ? this.themeState.color : $r('sys.color.icon_primary'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
  }

  /**
   * HDS 閸ョ偠鐨熼敍姘崇碃娴ｇ姵娼弽宄扮础閸欐ê瀵查敍鍫滅瑢 musicfreeOH 閻?`onBarStyleChange` 閸氬本顑?*閸欐甯?*閸愭瑦纭堕敍澶堚偓?
   *
   * USER_CLICK 閻愮懓鍤崡鏇炵湴閸﹀棗鑸伴懗璺烘抄閺冭埖浠径宥呯暚閺佹潙寮婚幒鎺嬧偓?
   * NORMAL/APP_TRIGGER 娴犲懏濮ら崨濠呯翻閸戠尨绱濇稉宥堝厴閸欏秴鎮滅弧鈩冩暭閸烆垯绔寸敮鍐ㄧ湰閻樿埖鈧降鈧?
   * miniBarStyle閸欐甯堕敍娑欏付閸掕泛娅掓稉搴＄鐏炩偓閸氬本顒為崚鍥ㄥ床閵?
   */
  /**
   * 鐓ф惉涓婃父 `onMiniBarStyleChanged`锛坄wujie.pa:149113-149336`锛夛細**鍙暅鍍?HDS 鎶ユ潵鐨勬牱寮?*锛?
   * 涓嶅弽鍚戞敼甯冨眬銆佷笉琛?`animateTo`锛堜笂娓告暣涓?`MainPage` 妯″潡閲?`animateTo` 闆跺懡涓紱
   * 鍒囨崲鍔ㄧ敾鐢?HDS 鍐呴儴榛樿鍔ㄦ晥缁欙紝SDK `@hms.hds.hdsBaseComponent.d.ets:5729` 鍘熸枃
   * "The style switch will be accompanied by a default animation."锛夈€?
   * 鍙︼細涓婃父瀵?`USER_CLICK + COLLAPSE`锛堢偣杩蜂綘鏉℃敹璧凤級**鐩存帴蹇界暐**锛坄:149215` 涓€甯︼級銆?
   * @param miniBarStyle HDS 鎶ュ洖鏉ョ殑鏍峰紡
   * @param mode 鍙樻洿鏉ユ簮
   */
  private onMiniBarStyleChangeFull(miniBarStyle: HdsBarStyle, mode: HdsTabsBarChangeMode): void {
    if (this.navDepth > 0 || this.restoringHomeBar) {
      return;
    }
    const collapsed: boolean = miniBarStyle === HdsBarStyle.COLLAPSE;
    if (collapsed && mode === HdsTabsBarChangeMode.USER_CLICK) {
      Logger.info(RzdShellLogTag, 'home bar user click on mini ignored (upstream :149215)');
      return;
    }
    this.setHomeBarExpandedAnimated(!collapsed);
    Logger.info(RzdShellLogTag, `home bar callback style=${miniBarStyle} mode=${mode} expanded=${!collapsed}`);
  }

  /**
   * 鈽呪槄鈽?2026-10-18锛堢敤鎴风鍗佷竷杞細銆屽畠鍒囨崲鐨勬椂鍊欏張鏄洿鎺ュ彉澶э紝娌℃湁杩囨浮锛岀湅鐫€涓嶅お娴佺晠銆嶏級锛?
   *
   * 涓婁竴鐗堟妸琛ラ棿浜ょ粰鍚勮妭鐐硅嚜宸辩殑 `.animation(BAR_ANIM)`锛屼絾**浠嶆湁灞炴€т笉琛ラ棿**锛?
   *   - `constraintSize` 涓嶅湪鍙姩鐢诲睘鎬ц〃閲岋紙宸插湪 `HomeMiniBarPlayer` 渚у垹鎺夎鐩掗偅鏉★級锛?
   *   - 鏉愯川鐩樼敱鍐呭眰 HDS `HdsTabs` 鐢伙紝`barHeight` 鎹㈡。鏃?HDS 鍐呴儴杩樹細鎸夎嚜宸辩殑榛樿鍔ㄦ晥璧颁竴閬嶏紝
   *     鍜屽灞傞€愯妭鐐瑰姩鐢?*鍚勭畻鍚勭殑**銆?
   *
   * 鈬?鏀逛负鍦?*鍞竴鐨勭姸鎬佸啓鍏ョ偣**鐢ㄤ竴娆?`animateTo` 鏀跺彛锛堝悓涓€涓?`BAR_ANIM = 350ms Friction`锛?
   *   `wujie.pa:70120-70126`锛夛細杩欎竴甯ч噷鎵€鏈変緷璧?`miniBarExpanded` 鐨?*鍙姩鐢?*灞炴€?
   *   锛堟Ы楂?/ 鑳跺泭楂?/ 琛屽唴璺?/ 灏侀潰瑙嗚杈?/ 灏侀潰缂╂斁锛夊悆**鍚屼竴鏉?*鏃堕棿绾匡紝涓嶅啀鏈夌‖璺炽€?
   *   锛堜笂娓告暣妯″潡 `animateTo` 闆跺懡涓槸鍥犱负瀹冮潬 HDS 鑷繁鐨勯粯璁ゅ姩鏁堬紝鑰屾垜浠殑鑳跺泭鐩掓槸鎴戜滑鑷繁鐨勶紝
   *     HDS 鐨勯粯璁ゅ姩鏁堢涓嶅埌 鈬?蹇呴』鑷繁琛ヨ繖涓€灞傘€傦級
   * @param expand true = 鍗曡锛堝睍寮€妗ｏ級锛宖alse = 涓ゆ帓锛堟敹璧锋。锛?
   */
  private setHomeBarExpandedAnimated(expand: boolean): void {
    if (this.appState.miniBarExpanded === expand) {
      return;
    }
    try {
      this.getUIContext().animateTo({
        duration: Index.HOME_BAR_SWITCH_MS,
        curve: Curve.Friction
      }, (): void => {
        this.appState.miniBarExpanded = expand;
      });
    } catch (err) {
      Logger.error(RzdShellLogTag, `animateTo home bar switch failed ${String(err)}`);
      this.appState.miniBarExpanded = expand;
    }
    Logger.info(RzdShellLogTag,
      `home bar switch expand=${expand} dur=${Index.HOME_BAR_SWITCH_MS} curve=Friction`);
  }

  /**
   * 鐓ф惉涓婃父 `applyBarAction`锛坄wujie.pa:145755-145790`锛夌殑钀藉湴鍗婃锛氬彧鎶?*灞曞紑鎰忓浘**浜ょ粰
   * `HdsTabsController.applyMiniBarStyle()`銆備笂娓告暣妯″潡 `animateTo` 闆跺懡涓紝鍔ㄧ敾鐢?HDS
   * 榛樿鍔ㄦ晥缁欙紙SDK `@hms.hds.hdsBaseComponent.d.ets:5729`锛夆噿 杩欓噷涓嶈捣浠讳綍琛ラ棿銆?
   * @param expand true = 杩蜂綘鏉″睍寮€锛圗XPAND 妗ｏ級锛宖alse = 鏀惰捣锛圕OLLAPSE 妗ｏ級
   */
  private applyHomeBarExpanded(expand: boolean): void {
    // 鈽?鍐欏叆璧板甫 `animateTo` 鐨勬敹鍙ｏ紙鍚﹀垯婊氬姩/鐐瑰嚮瑙﹀彂鐨勬崲妗ｆ槸纭烦锛夈€?
    this.setHomeBarExpandedAnimated(expand);
    try {
      this.tabsController.applyMiniBarStyle(expand ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE);
    } catch (err) {
      Logger.error(RzdShellLogTag, `applyMiniBarStyle failed ${String(err)}`);
    }
  }

  /**
   * 娴肩姷绮?HDS 閻ㄥ嫭甯撶敮鍐┠佸蹇嬧偓?
   *
   * `barLayoutMode` / `HdsBarLayoutMode` 閺?**@since 6.1.1(24)** 閳ユ柡鈧?閹碘偓娴犮儱浼愮粙瀣箑妞ょ粯濡?
   * `targetSdkVersion` 閹绘劕鍩?24 娴犮儰绗傞敍鍫熸拱妞ゅ湱娲板鍙夋暭娑?6.1.1(24)閿涘畭compatibleSdkVersion`
   * 娣囨繃瀵?6.1.0(23) 娑撳秴濂栭崫宥堫啎婢跺洩顩惄鏍电礆閵嗗倸婀?target 23 閻ㄥ嫬浼愮粙瀣櫡鏉╂瑤閲滅€涙顔屾稉宥呯摠閸︻煉绱?
   * 娴肩姾绻橀崢璁崇瘍娑撳秶鏁撻弫鍫礉鎼存洘鐖亸鍗炲涧閼宠姤妲搁崡鏇熷笓 閳ユ柡鈧?鏉╂瑦顒滈弰顖欑閸?娑撱倖甯撴穱顔荤瑝閸戠儤娼?閻ㄥ嫭鐗撮崶鐘偓?
   *
   * 娴ｅ酣鍘ょ拋鎯ь槵閿涘牆褰傜悰宀€澧?< 6.1.1(24)閿涘绗傛导?undefined閿涙艾鐡у▓鍏哥瑝閸欘垳鏁ら敍宀€鏁?HDS 閼奉亣顢戦崘鍐茬暰閵?
   * @returns HdsBarLayoutMode 閹?undefined閵?
   */
  /**
   * 涓婃父 `barLayoutMode` 鍦ㄦ暣浠?abc 閲屽彧鏈?4 澶勫啓锛?*鍏ㄦ槸瀵硅薄瀛楅潰閲忋€佸€兼亽 `VERTICAL`**
   * 锛坄wujie.pa:143295` / `:144066` / `:144083` / `:520524`锛夆噿 **鎺掑竷妯″紡杩愯鏈熶粠涓嶅垏鎹?*銆?
   * 鏈粨鍘熸潵闅忔粴鍔ㄥ湪 HORIZONTAL/VERTICAL 涔嬮棿缈?鈥斺€?涓婃父娌℃湁杩欎釜鍔ㄤ綔锛屽凡鐓ф惉銆?
   * @returns HdsBarLayoutMode锛屾垨涓嶆敮鎸佹椂 undefined
   */
  private barLayoutModeForHds(): HdsBarLayoutMode | undefined {
    if (!this.supportsTwoRowLayout()) {
      return undefined;
    }
    return HdsBarLayoutMode.VERTICAL;
  }

  /** 鐠佹儳顦崣鎴ｎ攽閻楀牊妲搁崥锔芥暜閹?`barLayoutMode`閿?.1.1(24) 鐠у嚖绱氶妴?*/
  private supportsTwoRowLayout(): boolean {
    return SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE);
  }

  /**
   * 娴肩姷绮?HDS 閻ㄥ嫯绯犳担鐘虫蒋閺嶅嘲绱￠妴?
   *
   * 閳藉懌鈧瞼骞囬崷銊ユ皑閸氼兙鈧秹銆夐幁鎺嶈礋 `COLLAPSE`閿涙岸鍋呮稉鈧い鍨＆濞屸剝婀佹潻铚傜稑閺夆€冲敶鐎圭櫢绱檣@link miniBar} 娑撳秵瑕嗛弻鎿勭礆閿?
   *   閸欏牐顫?{@link barLayoutModeForHds} 閸樺鍨氶崡鏇熷笓 閳ユ柡鈧?閼?閸楁洘甯?+ `EXPAND`"閺勵垰鍑￠惌銉ф畱闁挎瑨顕ょ紒鍕値
   *   閿涘牆绨抽弽蹇庣窗閸欐ɑ鍨氶妴宀勬毐閺?Tab + 閸﹀棗鑸伴幘顓熸杹閸ｃ劊鈧稄绱氶妴鍌濐潌 {@link NOW_PLAYING_TAB_INDEX}閵?
   * @returns 鏉╄渹缍橀弶鈩冪壉瀵繈鈧?
   */
  private miniBarStyleForHds(): HdsBarStyle {
    if (this.tabState.tabIndex === NOW_PLAYING_TAB_INDEX) {
      return HdsBarStyle.COLLAPSE;
    }
    return this.appState.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE;
  }

  /**
   * `miniBar` 妲介噷姝ゅ埢鏄笉鏄?*鐪熺殑鍦ㄧ敾鎾斁鍣?*锛堜笌 {@link miniBar} 閲岄偅鏉?`if` 閫愬瓧鍚屼箟锛夈€?
   *
   * 涓ゅ娑堣垂瀹冿紙璇箟蹇呴』涓€鑷达紝鍚﹀垯灏辨槸"鑳屾澘鍦ㄣ€佸唴瀹逛笉鍦?鎴栧弽杩囨潵锛夛細
   *   路 `barFloatingStyle.miniBar.enableMiniBarBackground` 鈥斺€?鍙湁鐪熺敾鎾斁鍣ㄦ椂鎵嶈 HDS 鐢昏儗鏉匡紱
   *   路 `RzdHomeMiniBarMaterial` 閭ｈ璇婃柇銆?
   *
   * 涓轰粈涔堜笉鑳芥亽涓?true锛歿@link miniBar} 鍦ㄣ€岀幇鍦ㄥ氨鍦ㄥ惉銆嶉偅涓€椤碉紙`NOW_PLAYING_TAB_INDEX`锛?
   * 涓庝簩绾ч〉鍦ㄦ爤涓婃椂锛坄navDepth > 0`锛夌粰鐨勬槸 **0 楂樺害鍗犱綅 Column**锛堜笉鐢绘挱鏀惧櫒锛夆€斺€?
   * 閭ｆ椂鑻ヨ HDS 鐢昏儗鏉匡紝椤电鑳跺泭涓婃柟浼氬鍑轰竴鏋?*绌鸿兌鍥?*锛堟湰鏂囦欢椤堕儴閭ｆ绗?鈶?鏉″氨鏄杩欎釜锛夈€?
   * @returns True = 杩欎竴鏍兼槸鐪熸鐨勮糠浣犳挱鏀炬潯銆?
   */
  /** 涓婃父 `MiniPlayer` 鐨?`BAR_CONTENT_H = 40`锛堟敹璧锋€佸唴瀹归珮锛宍wujie.pa:67515-67517`锛夈€?*/
  private static readonly BAR_CONTENT_H_VP: number = 40;

  /**
   * 杩蜂綘鏉°€屽崟琛?鈬?涓ゆ帓銆嶆崲妗ｇ殑琛ラ棿鏃堕暱锛坢s锛夈€傜収鎶勪笂娓?
   * `BAR_ANIM = { duration: 350, curve: Curve.Friction }`锛坄wujie.pa:70120-70126`锛夛紝
   * 涓?`HomeMiniBarPlayer.BAR_ANIM` / `MiniBarMaterialCapsule.BAR_ANIM` 鍚屼竴涓暟銆?
   */
  private static readonly HOME_BAR_SWITCH_MS: number = 350;

  /** 涓€绾ч〉 `miniBar` 杩欎竴鏍?*瀹炴祴瀹藉害**锛坴p锛? = 杩樻病閲忓埌锛涢噺鐨勬槸澶栧眰 100% 瀹界殑 `Column`锛夈€?*/
  @Local homeMiniBarSlotWVpRaw: number = 0;

  /**
   * @returns 涓€绾ч〉鑳跺泭/鍐呭/灏侀潰鍏辩敤鐨?*鍩哄噯楂樺害**锛坴p锛夈€?
   *
   * 鈿狅笍 涓嶈兘"瀹炴祴"锛氳兌鍥婃槸鎴戜滑鑷繁鐢荤殑锛屽灞傞噺鍒扮殑灏辨槸鑳跺泭鑷繁鐨勯珮搴?鈬?鑷縺鎴愮幆銆?
   * 璧颁笂娓?杩樻病閲忓埌楂樺害"鐨?*浼扮畻妗?*锛坄wujie.pa:67503-67517`锛夛細
   * `collapsed 鈬?BAR_CONTENT_H(40)`锛屽惁鍒?`40 脳 1.4 = 56`锛涙湰浠撶殑 `collapsed` 绛変环淇″彿鏄?
   * `appState.miniBarExpanded`锛堢敱 HDS `onBarStyleChange` 闀滃儚锛夈€?
   */
  private homeMiniBarSlotHVp(): number {
    // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆屽弻琛岀姸鎬佺殑鐭挱鏀炬潯涔熸樉绀哄ぇ灏侀潰浜嗐€嶏級鈬?妗ｄ綅**淇濇寔涓ゆ。**锛堣繖鎵嶆槸瀵圭殑锛夛細
    //   鏀惰捣锛堝崟灞傚渾鍧烇級= **楂?*鏉?56锛涘弻琛?= **鐭?*鏉?40锛堜笂娓镐及绠楁敮 `wujie.pa:67503-67517`锛夈€?
    //   鉀?鎭?56 鏄敊鐨勶細鍙岃閭ｆ潯鏈潵灏辨槸鐭潯锛屾亽 56 浼氳瀹冧篃椤朵竴涓ぇ灏侀潰銆?
    //   灏侀潰灏哄涓嶅湪杩欓噷瑙ｅ喅 鈥斺€?瑙?`HomeMiniBarPlayer.capsuleBaseHVp()` 鏀逛负**閽変綇鍊间紭鍏?*銆?
    return this.appState.miniBarExpanded ? FLOATING_MINI_BAR_HEIGHT_VP : Index.BAR_CONTENT_H_VP;
  }

  /**
   * @returns 涓€绾ч〉鑳跺泭鐨勫彲瑙佸搴︼紙vp锛? `min(瀹炴祴妲藉, floatingMiniBarWidthVp())`銆?
   * 瀹炴祴妲藉鏄灞?100% `Column` 閲忓埌鐨勶紙= HDS 缁欒繖涓€鏍肩殑瀹斤級锛涘彇灏忓€间繚璇佽兌鍥婁笉浼氭瘮鏍煎瓙瀹姐€?
   */
  private homeMiniBarBarWidthVp(): number {
    const want: number = this.floatingMiniBarWidthVp();
    if (this.homeMiniBarSlotWVpRaw > 0) {
      return Math.min(this.homeMiniBarSlotWVpRaw, want);
    }
    return want;
  }

  private miniBarRendersPlayer(): boolean {
    if (this.navDepth > 0) {
      return false;
    }
    return this.tabState.tabIndex !== NOW_PLAYING_TAB_INDEX;
  }

  /**
   * 閸欏苯鐪版惔鏇熺埉閸楃姵宓侀惃鍕杺婢舵牕绨抽柈銊╃彯鎼达负鈧?
   *
   * 閹帊璐?0閿涙碍甯撶敮鍐暠 HDS 閼奉亜绻佹径鍕倞閿涘矂銆夐棃銏犲晙妫版繂顦绘０鍕殌鐏忓彉绱版径姘毉娑撯偓閸ф鈹栭惂濮愨偓?
   * @returns 妫版繂顦绘惔鏇㈠劥妫板嫮鏆€閿涘澊p閿涘鈧?
   */
  private twoRowExtraBottomVp(): number {
    return 0;
  }

  /**
   * HDS 濞搭喖濮╂惔鏇熺埉闁插瞼娈戞潻铚傜稑閹绢厽鏂侀弶掳鈧?
   *
   * 閳跨媴绗?**娴滃瞼楠囨い鐢告桨閸︺劍鐖ゆ稉濠冩娑撳秵瑕嗛弻?*閿涘潉navDepth > 0`閿涘绱版禍宀€楠囨い鐢告桨閺堝鍤滃杈╂畱鐎规ɑ鏌熷ù顔煎З閺?
   * 閿涘牐顫?{@link floatingMiniBar}閿涘绱濇稉銈堢珶濞撳弶鐓嬮惃鍕Ц閸氬奔绔存稉?`HomeMiniBarPlayer`閿?
   * 鐎瑰啰鈥栫紓鏍垳 `.id(MINI_BAR_ID)` 閳ユ柡鈧?閸氬本妞傜€涙ê婀亸鍙樼窗閺堝琚辨禒钘夋倱 id 閻ㄥ嫯濡悙鐧哥礉
   * 閼板本鎸遍弨楣冦€夎ぐ銏犲綁閻ㄥ嫯鎹ｉ悙瑙勬Ц `getRectangleById(MINI_BAR_ID)` 闁插繒娈戦敍宀勫櫤閸掓澘鎽㈡稉鈧禒鎴掔瑝绾喖鐣鹃妴?
   * 2026-10-01 闁絾顐奸崶鐐衡偓鈧亸杈ㄦЦ鏉╂瑤閲滈崸鎴礄鐠佹澘绻?鎼?7.3 / 鎼?7.4-3閿涙哎鈧奔琚辨径鍕涧閼崇晫鏆€娑撯偓婢跺嫨鈧稄绱氶妴?
   *
   * **娑撳秷顩︾紒娆忕暊閸ュ搫鐣炬妯哄**閿涘牆甯弶銉ュ晸濮?`.height(56)`閿涘绱癿usicfreeOH 閻?`PlayBar` 閺嶇濡悙?
   * 閸欘亝婀佹稉鈧稉?`.width('100%')`閿涘矂鐝惔锔芥Ц HDS 闁插繐鍤弶銉ф畱閵嗕礁鑻熼悽杈碃娴ｇ姵娼懛顏勭箒 `onAreaChange` 鐠囪娲栭妴?
   * 閸愭瑦顒存妯哄娴兼俺顔€ HDS 閸︺劊鈧奔绗傛稉瀣╄⒈閹烘帇鈧秵妞傞幏澶哥瑝閸掔増顒滅涵顔炬畱閸愬懎顔愭妯哄閿涘本甯撶敮鍐ㄦ皑闁偓閸栨牓鈧?
   */
  @Builder
  private miniBar() {
    // 閳?閻劍鍩?2026-10-15閿涙艾绨抽弽蹇嬧偓宀€骞囬崷銊ユ皑閸氼兙鈧秹鍋呮稉鈧い?*娑撳秶鏁?*鏉╂瑦娼潻铚傜稑閺夆槄绱欓崣鍌濃偓鍐ㄦ禈闁?Tab 閺嶅繋绠ｆ稉濠傚涧閺堝绻樻惔锕侇攽閿涘鈧?
    //   鐟?{@link NOW_PLAYING_TAB_INDEX}閵嗗倻鏁ら弶鈥叉濞撳弶鐓嬮懓灞肩瑝閺?`Visibility.Hidden`閿?
    //   娣囨繄鏆€閸楃姳缍呴惃鍕樈 HDS 娴兼氨鎴风紒顓熷瘻"娑撱倖甯?閹烘帒绔烽敍瀛碼b 閼宠泛娉导姘愁潶妞ゅ爼鐝妴浣哥俺娑撳鏆€娑撳绔撮崸妤冣敄濡楋絻鈧?
    //   閳跨媴绗?**閹烘帒绔峰Ο鈥崇础娑撳秷顩︾捄鐔烘絻閺€?*閿涘潉barLayoutModeForHds()` 闁插矂鍋呭▓鐢垫畱閸ф埊绱氶敍?
    //     HORIZONTAL 閺?妞ょ數顒锋稉搴ょ碃娴ｇ姵娼獮鑸靛笓"閿涘奔绱扮拋鈺呫€夌粵鎹愵潶閹搞倕鍩屽锕佺珶閵嗕礁褰哥粩顖溾敄娑撯偓閺嶇》绱欓悽銊﹀煕閻鍩岄惃?閻厺绔撮幋?閿涘鈧?
    //     鏉╂瑩鍣烽崣顏囶唨 HDS **闁插繐鍩?0 妤?*閿涘牆鐣犻弰顖涘瘻閸愬懎顔愰柌蹇涚彯鎼达妇娈戦敍澶涚礉閹烘帒绔峰Ο鈥崇础娑撳骸鍩嗛惃鍕€夌粵楣冣偓鎰摟娑撯偓閼锋番鈧?
    //   閳跨媴绗?娴狅絼鐜敍姘崇箹娑撯偓妞ゅ吀绗?`getRectangleById(MINI_BAR_ID)` 闁插繋绗夐崚鎷岀碃娴ｇ姵娼?閳?瑜般垹褰夌挧椋庡仯閸欘亣鍏樼挧鏉垮幑鎼存洖鍤戞担鏇樷偓?
    //     閸欘垯浜掗幒銉ュ綀閿涙碍婀版い?*娑撳秳绱伴幍鎾崇磻閹绢厽鏂佹い?*閿涘潉NowPlayingFeedPage` 閻?`playAt` 鐠?
    //     `openPlayer=false` / `PlaybackIntentState.openPlayerUi=false`閿涘绱?
    //     閼板矁鍏樺鈧崚鐗堟尡閺€楣冦€夐惃鍕弳閸欙綇绱欐惔鏇熺埉鏉╄渹缍橀弶锛勫仯閸戞眹鈧胶閮寸紒鐔风崯娴ｆ挻甯堕崚璁圭礆閸︺劍婀版い鍏哥瘍娑撳秴鐡ㄩ崷?娑撳秴鑸伴崣妯糕偓?
    if (this.navDepth <= 0) {
      if (this.tabState.tabIndex === NOW_PLAYING_TAB_INDEX || this.navDepth > 0) {
        // 閳藉應妲勯埥鍛 2026-10-17閿?*娣囶喚鏁ら幋宄扮杽濞村鈧奔绨╃痪褔銆夐棃顫窗閸戣櫣骞囨稉銈勯嚋閹绢厽鏂侀弶掳鈧?*閿?
        //   閸樼喐娼垫潻娆撳櫡閸欘亜鍨?`tabIndex === 濮濓絽婀幘顓熸杹`閿?*濞屸€冲灲 `navDepth`** 閳ユ柡鈧?娴滃瞼楠囨い闈涙躬閺嶅牅绗傞弮璁圭礉
        //   娴滃瞼楠囨い浣冨殰瀹搁亶鍋呴弶鈥崇暭閺傝璇為崝銊︾埉閿涘潉floatingMiniBar`閿涘鍑＄紒蹇撴躬閻紮绱濇＃鏍€夋潻娆愭蒋閸欏牊鐥呴崡姝屾祰
        //   閳?鐏炲繋绗傛稉銈嗘蒋閹绢厽鏂侀弶掳鈧倹婀伴弬鍥︽ L1617 閻ㄥ嫭鏁為柌濠冩－鐏忓崬鍟撻弰搴ょ箹閺夆€茬瑝閸欐﹢鍣?
        //   閵嗗备娈搁敂?娴滃瞼楠囨い鐢告桨閸︺劍鐖ゆ稉濠冩娑撳秵瑕嗛弻鎿勭礄`navDepth > 0`閿涘鈧秮鈧柡鈧?娴狅絿鐖滃▽陇绐℃稉濞库偓?
        //   閳?鐞涖儰绗?`navDepth > 0`閿涙矮绨╃痪褔銆夐崷銊︾垽娑撳﹥妞傛潻娆庣閺夆€虫倱閺嶉绮?0 妤傛﹫绱?*娑撳秴宓忔潪?*閿?
        //     娣囨繀缍?`MINI_BAR_ID` 娴犲秴婀弽鎴滅瑐閿涘苯鑸伴崣妯挎崳閻愮绻曢懗浠嬪櫤瀵版鍩岄敍澶堚偓?
        // 閳藉應妲?鏉╂瑤绔存い?*閺勬儳绱＄紒?0 妤?*閿涘牐鈧奔绗夐弰?閺佺繝閲?builder 娑撳秵瑕嗛弻?閿涘绱?
        //   鐎规ɑ鏌熼妴濠咁啎缂冾噣銆夌粵鐐埉閻ㄥ嫭鍋撳ù顔界壉瀵繈鈧甯弬鍥ｂ偓鏂衡偓鏃囩碃娴ｇ姵鐖弰顖濆殰鐎规矮绠熼崠鍝勭厵閿?*鐠虹喖銆夌粵鐐埉妤傛ê瀹抽惄鍝ョ搼娑撴梹鎸夐獮鍐差嚠姒?*閿?
        //   閺堫剙浼愮粙瀣暏 `barLayoutMode = VERTICAL` 閹跺﹤鐣犻弨瑙勫灇娑撳﹣绗呮稉銈嗗笓閿涘矁鈧?HDS 閸︺劑鍋呮稉鈧锝嗘Ц**閹稿鍞寸€瑰綊鍣烘?*閻?
        //   閿涘牐顫?`miniBar()` 娑撳﹪娼伴柇锝嗩唽"娑撳秷顩︾紒娆忕暊閸ュ搫鐣炬妯哄"閻ㄥ嫯顔囪ぐ鏇礆閳?缂佹瑤绔存稉?0 妤傛ê顔愰崳顭掔礉
        //   "娑撳﹪娼伴柇锝勭閹?妤傛ê瀹崇亸杈ㄦЦ 0閿涘矂銆夌粵鎹愬厡閸ュ﹦娈戦崙鐘辩秿娑撳骸鍩嗛惃鍕€夌粵?*闁劕鐡ф稉鈧懛?*閵?
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(0)
      } else {
        // 閳藉應妲?2026-10-15閿涘牆娲栭柅鈧崥搴ㄥ櫢閸嬫熬绱?*娑撳秴褰夐柌?*閿涙矮绔村▎鈥宠埌閸欐ü绱扮拠婵囨埂闂傝揪绱濇潻铚傜稑閺?*閻喕闊╂稉宥呭棘娑撳海绮崚?*閿?
        //   閻㈠崬锛撶仦鍌氬帬闂呭棗鐪伴敍鍧凪orphMiniBarClone` / `MorphMetaBridge`閿涘绗岄幘顓熸杹妞ら潧鍞撮惃鍕敾妞嬬偛鐨濋棃顫敩鐞涖劌鐣犻妴?
        //   `sourceBarHidden` 閻㈠彉绱扮拠婵囧閺堝鈧懎鏁稉鈧崘娆欑礄`morphBeginEntering` / `morphBeginLeaving` 缂?true閿?
        //   `morphLand` / `morphReset` 缂?false閿涘鍣?娑撳娼幍鎾崇磻鐠侯垶鍏橀幋鎰彌閵?
        //   娑撳秷绻栨稊鍫濅粵閻ㄥ嫯鐦介敍姘尡閺€楣冦€夎ぐ銏犲綁閺堢喖妫块弰?*閸楀﹪鈧繑妲?*閻㈣鍤弶銉ф畱閿涘瞼婀￠煬顐＄窗娴犲骸绨虫稉瀣偓蹇撳毉閺?閳ユ柡鈧?
        //   娑撯偓鏉堣妲搁崗瀣畷鐏炲倻鏁鹃惃鍕閺堫兙鈧椒绔存潏瑙勬Ц閻喕闊╅敍宀€鏁ら幋椋庢箙閸掓壆娈戝锝嗘Ц"鏉╄渹缍橀弶鈥冲竾閸︺劍鎸遍弨楣冦€夋稉?閿涘牓鍣搁崣鐙呯礆閵?
        //   閳跨媴绗?韫囧懘銆忛悽?`Visibility.Hidden`閿涘牅绻氶悾娆忕鐏炩偓閿涘绱拌ぐ銏犲綁鐠ч鍋ｇ憰?`getRectangleById` 闁插繗绻栭弶鈩冪埉閿?
        //   閻?`None` 娴兼岸鍣烘稉宥呭煂 閳?閸斻劎鏁鹃惄瀛樺复闁偓閸栨牓鈧?
        // 鈽呪槄鈽?2026-10-18锛堢洰鏍?goal-a29f6835 / 璁板繂 搂197锛夛細涓€绾ч〉涔?*鑷涓讳竴涓?`HdsTabs` 鑳跺泭**
        //   鈥斺€?涓庝簩绾ч〉鍚屾瀯銆傜悊鐢憋紙鏈満 SDK 鍘熸枃锛夛細`systemMaterialEffect` 鍙瓨鍦ㄤ簬
        //   `TitleBarStyleOptions`锛坄@hms.hds.hdsBaseComponent.d.ets:1472`锛変笌 `HdsTabsFloatingStyle`锛坄:5357`锛?
        //   涓や釜缁勪欢閫夐」鎺ュ彛涓婏紝**娌℃湁** CommonAttribute 绾ф潗璐?鈬?鍏夋劅鍙兘鐢?HDS 缁勪欢鐢伙紱
        //   鑰?HDS `miniBar` 妲界敾鐨勮儗鏉垮湪瀹冭嚜宸卞瓙鏍戦噷锛屾垜浠帇涓嶅埌 鈬?鍙湁"鑷涓?HdsTabs"鑳藉悓鏃舵嬁鍒?
        //   銆屾潗璐ㄣ€嶄笌銆屾尋鍘嬨€嶏紙浜岀骇椤靛氨鏄繖鏉¤矾锛夈€?
        //   瀹藉害鍙?*瀹炴祴妲藉**锛堝灞?`Column` 瀹藉害 100%锛岄噺鐨勫氨鏄?HDS 缁欒繖涓€鏍肩殑瀹斤級锛岄珮搴﹀彇浼扮畻妗ｃ€?
        Column() {
          MiniBarMaterialCapsule({
            // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆屽崟琛岀姸鎬佷笅杩樻湁灏忚儗鏅€嶏級锛氬唴灞傝兌鍥婁紶 **HORIZONTAL**
            //   鈬?`isSingleRow()` 涓虹湡 鈬?`capsuleBoxWidthVp(bW, true) = bW`锛坄MiniBarMaterialCapsule.ets:58-60`锛?
            //   鈬?鐩掑 鈮?鑳跺泭瀹斤紝**娌℃湁宸﹀彸鍚?5vp 鐨?slack 绌哄甫**锛堥偅鍦堢┖甯︽鏄?灏忚儗鏅?闇插嚭鏉ョ殑鍦版柟锛夈€?
            //   鈿狅笍 鍙奖鍝?*鎴戜滑鑷繁杩欎釜鐩?*鐨勫锛涘灞?HDS 鐨勬帓甯冩ā寮忎粛鎭?VERTICAL锛堜笂娓稿彛寰勶紝瑙?`barLayoutModeForHds`锛夈€?
            barLayoutMode: HdsBarLayoutMode.HORIZONTAL,
            barWidth: this.homeMiniBarBarWidthVp(),
            barHeight: this.homeMiniBarSlotHVp(),
            bottomMargin: 0,
            material: this.ambientTitleMaterial(),
            fitWinWVp: this.viewportWidthVp,
            fitSideMarginVp: 0
          }) {
            HomeMiniBarPlayer({
              showPreviousTrack: false,
              followAppMiniBarExpanded: true,
              // 鏉愯川鐢卞唴灞?`HdsTabs` 鐢?鈬?鏈綋涓€涓儚绱犻兘涓嶈嚜缁橈紙鍚﹀垯娲楃櫧锛夈€?
              showSelfDrawnBackplate: false,
              // 鎸ゅ帇浜ょ粰鑳跺泭灞傦紙涓庝簩绾ч〉閫愬瓧鐩稿悓锛氬帇鐨勬槸鍚潗璐ㄧ殑閭ｄ竴灞傦級銆?
              contentOwnsSquash: false,
              contentHeightVp: this.homeMiniBarSlotHVp()
            })
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .onAreaChange((_old: Area, area: Area): void => {
          const w: number = areaLengthToVp(area.width);
          if (w > 0 && Math.abs(w - this.homeMiniBarSlotWVpRaw) > 0.5) {
            this.homeMiniBarSlotWVpRaw = w;
            // 閲忓埌妲藉灏辨妸杩欏洓涓暟鎵撳嚭鏉ワ紙瀹藉害鍙ｅ緞鏄惁瀵归綈鍙湅杩欎竴琛岋級锛?
            //   `slotW >= barW` 鎵嶇畻瀵癸紱`capH` 闅忓睍寮€/鏀惰捣鍦?56 / 40 涔嬮棿鍒囥€?
            Logger.info('RzdHomeMiniBarMaterial',
              `material=capsule(systemMaterialEffect) ambient=${this.ambientLevelIndex()} ` +
                `plate=inner-hds-tabs slotW=${w.toFixed(1)} barW=${this.homeMiniBarBarWidthVp().toFixed(1)} ` +
                `capH=${this.homeMiniBarSlotHVp().toFixed(1)} expanded=${this.appState.miniBarExpanded} ` +
                `squashY=${this.expandState.morphSquashY}`);
          }
        })
        .visibility((this.expandState.sourceBarHidden || this.expandState.shrinkHidesBar || this.expandState.miniOut || this.expandState.hdsBarSuppressed) ? Visibility.Hidden : Visibility.Visible)
        .onAppear((): void => {
          Logger.info('RzdHomeMiniBarMaterial',
            `material=capsule(systemMaterialEffect) ambient=${this.ambientLevelIndex()} ` +
              `plate=inner-hds-tabs rendersPlayer=${this.miniBarRendersPlayer()} ` +
              `slotW=${this.homeMiniBarSlotWVpRaw.toFixed(1)} barW=${this.homeMiniBarBarWidthVp().toFixed(1)} ` +
              `capH=${this.homeMiniBarSlotHVp().toFixed(1)} ` +
              `squashY=${this.expandState.morphSquashY}`);
        })
      }
    }
  }

  /**
   * 娴滃瞼楠囨い鐢告桨閻ㄥ嫭鍋撳ù顔跨碃娴ｇ姵鎸遍弨鐐蒋閿?*鐎规ɑ鏌?HDS 濞搭喖濮╅弽?+ 濞屽韫堥崗澶嬪妳閺夋劘宸?*閿涘牏鏁ら幋?2026-10-11 閹峰秵婢橀惃鍕波閺嬪嫭鏁奸柅鐙呯礆閵?
   *
   * 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?娑撹桨绮堟稊鍫濈箑妞ょ粯妲?娑撯偓娑擃亜宕熸い鐢殿劮閻?HdsTabs"閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?
   *
   * 鐎规ɑ鏌熼妴濠冪焽濞寸鍘滈幇鐔峰閼版ぞ绱崠鏍モ偓瀣斧閺傚浄绱伴妴灞藉従娴犳牜绮嶆禒鏈电矌閸?Navigation/NavDestination 閺嶅洭顣介弽蹇斿灗濡亜鎮?Tabs 娑?
   * barPosition 娑?BarPosition.End 閻ㄥ嫬绨抽柈?TabBar 娑擃厾鏁撻弫鍫涒偓?*閸︺劌鍙炬禒鏍у隘閸╃喍鑵戠拋鍓х枂濞屽韫堥崗澶嬪妳閺佸牊鐏夋稉宥囨晸閺佸牄鈧?*閵?
   * 娑旂喎姘ㄩ弰顖濐嚛閿涙艾鍘滈幇鐔告綏鐠愩劌褰ч張?*閺嶅洭顣介弽?*娑?*鎼存洟鍎?TabBar**娑撱倓閲滈崥鍫熺《鐎瑰じ瀵岄妴鍌涙＋閸愭瑦纭堕敍鍫濓紦鐏?Stack 闁插奔绔存稉顏呮珮闁?
   * Column 閹?`backgroundEffect`閿?*濮樻瓕绻欓幏澶哥瑝閸掓澘鐣奸弬瑙勬綏鐠?*閿涘苯褰ч懗鐣岀暬閼奉亞绮潻鎴滄妧 閳ユ柡鈧?閻劍鍩涢弰搴ｂ€橀崥锔藉竴娴滃棗鐣犻妴?
   *
   * 閻滄澘婀惃鍕粵濞夋洩绱? 閸欏倽鈧啫浼愮粙?`lxmusic-harmony` 閻?`views/PanePage.ets` 閸氬奔绔存總妤嬬礆閿?*閸欘亝婀佹稉鈧稉顏堛€夌粵鍓ф畱
   * HdsTabs**閿涘矂銆夌粵鐐埉閻ㄥ嫬鍞寸€圭櫢绱機ustomBuilder閿涘姘ㄩ弰顖涙尡閺€鎯ф珤閺堫兛缍嬮敍灞藉晙閸旂姳绗傜€规ɑ鏌熸稉澶嬫蒋娴?
   *   `barPosition(End)` + `barOverlap(true)` + `vertical(false)`
   * 閳?鏉╂瑦娼弽蹇撴皑閽€钘夋躬"鎼存洟鍎?TabBar"鏉╂瑤閲滈崥鍫熺《鐎瑰じ瀵岄柌宀嬬礉`systemMaterialEffect` 閻喓鏁撻弫鍫涒偓?
   * 閺夋劘宸濆锝勭秴婢跺秶鏁ら弽鍥暯閺嶅繘鍋呮稉鈧禒鏂ょ礄{@link ambientTitleMaterial}閿涘绱濇稉宥堫洣閸愬秴鍞撮懕鏂剧婵傛ぞ绗侀惄顔衡偓?
   *
   * 鐎瑰じ瀵岄弨鎯ф躬**婢瑰啿鐪?Stack 閻ㄥ嫬绨抽柈?*閿涘牅绗岄弮褑鍏岄崶濠傛倱娑撯偓娑擃亙缍呯純顔衡偓浣告倱娑撯偓婵傛鐣婚張顖ょ礆閿涘本澧嶆禒銉ょ癌缁狙囥€?
   * 閿涘潉NavDestination`閿涘娲婃稉宥勭秶鐎?閳ユ柡鈧?鏉╂瑦顒滈弰顖氱暊閼宠姤娴涢幒澶嬫＋閼宠泛娉惃鍕斧閸ョ姰鈧?
   *
   * 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?閳?娑撯偓閺夛紕鈥栫痪锔芥将閿涙艾鍙忕仦?*閸欘亣鍏樼€涙ê婀稉鈧弶?*鏉╄渹缍橀弶?閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?
   *
   * 2026-10-01 09:39 鐠囨洝绻冮崥灞肩婵傛顔栨稉浼欑礉閸ョ偤鈧偓娴滃棴绱濋崢鐔锋礈鐏忚鲸妲?*閸?id 閹剧偠婧?*閿?
   * 妫ｆ牠銆夋惔鏇熺埉閻?`miniBar` 娑撳氦绻栭弶鈥茬癌缁狙勭埉濞撳弶鐓嬮惃鍕Ц閸氬奔绔存稉?`HomeMiniBarPlayer`閿涘苯鐣犵涵顒傜椽閻?
   * `.id(MINI_BAR_ID)`閿涘牐绻涚敮?`MINI_BAR_COVER_ID` / `MINI_BAR_ASIDE_ID`閿涘鈧倷绨╃痪褔銆夐崷銊︾垽娑撳﹥妞?
   * 妫ｆ牠銆夋惔鏇熺埉楠炶埖鐥呴張澶婂祻鏉?閳?鐏炲繐绠锋稉濠傚毉閻?*娑撱倓鍞ら崥?id** 閻ㄥ嫯濡悙鐧哥礉閼板本鎸遍弨楣冦€夎ぐ銏犲綁閻ㄥ嫯鎹ｉ悙瑙勬Ц
   * `getRectangleById(MINI_BAR_ID)` 闁插繒娈?閳ユ柡鈧?闁插繐鍩岄崫顏冪娴犳垝绗夌涵顔肩暰閿涘矁鎹ｉ悙鐟版皑閹舵牓鈧?
   * 閳?閹碘偓娴?{@link miniBar}閿涘牓顩绘い鐢稿亝閺夆槄绱氶崷?`navDepth > 0` 閺?*娑撳秵瑕嗛弻?*閿涘奔琚辨径鍕涧閻ｆ瑤绔存径鍕┾偓?
   *    閺€纭呯箹闁插奔绠ｉ崜宥呭帥閻鍋呴弶鈩冩暈闁插鈧?
   *
   * 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅?鐏忓搫顕?/ 鐟欙附鎳?/ 瑜般垹褰夌拠顓濈疅閿涘牐绻栨禍?*娑撳秷鍏?*閸旑煉绱氶埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜
   *
   * 瑜般垺鈧胶鏁?*妫ｆ牠銆夋稉銈嗗笓 Tab 閺冩湹绗傞棃銏ゅ亝閺?*閻ㄥ嫬鍟撳▔鏇窗閸氬奔绔存稉?
   * `HomeMiniBarPlayer({ showPreviousTrack: false, followAppMiniBarExpanded: false })`閵?
   *
   * 娑撱倓閲滅亸鍝勵嚟**閺勬儳绱?*缂佹瑱绱?
   *   - 妤傛ê瀹抽敍?6vp閿涘牆鐨濋棃?44 + 娑撳﹣绗呴崥?6vp閿涘鈧倸鐣犻弰顖涙尡閺€楣冦€夎ぐ銏犲綁閻ㄥ嫯鎹ｉ悙鐧哥礉閸戠姳缍嶉崣顏堟
   *     `FLOATING_MINI_BAR_HEIGHT_VP` 鏉╂瑤绔存稉顏勭埗闁插繐褰夐崠鏍モ偓?
   *   - 鐎硅棄瀹抽敍?*娴溿倗绮?HDS**閿涘牆顔栨稉濠氭懙濠娾€愁啍鎼达讣绱濋弽蹇庣秼/閼宠泛娉惃鍕啍鎼达缚绗岀仦鍛厬閻㈠崬鐣奸弬瑙勮癁閸斻劍鐖懛顏勭箒缁犳绱氶妴?
   *     娴犮儱澧犻幋鎴滄粦閸愭瑦顒存潻鍥ь啍鎼达讣绱檂width(缁愭褰涚€?閳?鏉堢绐?` + `barFloatingStyle.barWidth`閿涘绱?
   *     閻喐婧€閸欏秹顩弰?鐟曚椒绠炵拹鏉戝煂鐏炲繐绠烽崣瀹犵珶閵嗕浇顩︽稊鍫熸嫼閹存劖鏆ｉ弶鈥炽亣闂€鎸庢煙瑜邦澁绱濆鍫滅瑦"閳ユ柡鈧?闁絾妲搁崪?HDS 閻ㄥ嫯顔€娴ｅ秴濮╅悽缁樺ⅵ閺?
   *     閿?026-10-01 闁絾顐肩€圭偤鐛欓惃鍕殌鐠侇叏绱氶敍宀€骞囬崷銊ょ瑝閸愬秷鍤滃杈╃暬閵?
   *   `clip(false)` 鐟曚胶鏆€閻偓閿涙俺顥嗘禍鍡曠窗閹?HDS 閻ㄥ嫯鍎楅弶?閹舵ê鐨犳稉鈧挧鐤梿閹哄鈧?
   *
   * 鐟欙附鎳滈敍姘殻鐏?Stack 韫囧懘銆?`HitTestMode.Transparent` 閳ユ柡鈧?姒涙顓婚惃?Default 娴兼碍濡告禍宀€楠囨い鐢告桨閻?
   * 閻愮懓鍤崗銊ユ倖閹哄绱欓煪鈺勭箖閿涘绱盩ransparent 鐞涖劎銇氶懛顏勭箒娑撳秴鎮嗘禍瀣╂娴ｅ棗鐡欓懞鍌滃仯閻撗冪埗閸濆秴绨查妴?
   */
  @Builder
  private floatingMiniBar() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      /**
       * 閳藉應妲?閸忔娊鏁敍姝歍abContent()` **娑撳秷鍏橀弰顖溾敄閻?*閵?
       *
       * 2026-10-01 闁絾顐肩€圭偤鐛欑亸杈ㄦЦ"缁?TabContent + 閹绢厽鏂侀崳銊ョ秼 tabBar"閿涘瞼婀￠張杞扮瑐**濞屸剝婀侀懗璺烘抄閼冲本婢?*
       * 閿涘牅缍旈懓鍛秼閺冭泛褰ч懗鍊熕夋稉鈧崸妤勫殰缂佹鍎楅弶鍨幑鎼存洩绱氶妴?026-10-11 婢跺秶骞囨禍鍡楁倱娑撯偓娑擃亞骞囩挒鈽呯窗閻劍鍩涢幎?
       * 閵嗗苯绨虫稉瀣尡閺€鐐蒋閺勵垶鈧繑妲戦惃鍕剁礉閸欘亞婀呭妤勵潌鐏忎線娼伴崪灞惧瘻闁筋喓鈧秲鈧倻骞囬崷銊ョ窔 TabContent 闁插本鏂佹稉鈧稉?*閻喎鐤勯惃?
       * 濠娾€虫槀鐎电顔愰崳?*閿涘矁顔€ HDS 鐠併倓璐熸潻娆愭蒋閺嶅繑婀侀崘鍛啇閿涘奔绮犻懓灞惧瘻閹剚璇為弽宄扮础閻㈣鍤懛顏勭箒閻ㄥ嫯鍏岄崶濠呭剹閺?+ 閺夋劘宸濋妴?
       *
       * 閸欙箑顦?`barFloatingStyle` 閻ㄥ嫰鏁?*娑撳酣顩绘い鐢稿亝閺夆€崇暭閺傜懓绨抽弽蹇庣箽閹镐椒绔撮懛?*閿涘牆褰х紒?
       * `barBottomMargin` / `adaptToHandedness` / `systemMaterialEffect`閿涘绱?
       * 娑撳﹣绔撮悧鍫濐樋娴肩姷娈?`barWidth` / `barSideMargin: 0` / `gradientMask: {maskHeight: 0}` 閺?
       * 2026-10-01 鐎圭偤鐛欓柇锝咁殰閿?*瑜版挻妞傚锝嗘Ц闁板秶娼冮柇锝呮健閼奉亞绮懗灞炬緲閻劎娈?*閿涘绱濋悳鏉挎躬娑撯偓瀵板绗夋导鐙呯礉闁灝鍘ゆ禒璁崇秿
       * "閼奉亜绻侀幒銉ь吀閺嶅繋缍?閻ㄥ嫭娈粈鐚寸礉閼冲本婢?閺夋劘宸濋崗銊ゆ唉缂?HDS閵?
       */
      // 鈽呪槄鈽呪槄 2026-10-17锛堢敤鎴凤細銆屼簩绾ч〉闈㈤偅涓ぇ鐨勫垹浜嗗晩銆?銆屽皬鐨勬槸鑷粯鐨勶紝澶у皬涔熷皬涓€浜涖€嶏級
      //   鍘熸潵杩欓噷鏄?`HdsTabs`锛堜竴涓┖ TabContent + 鎴戜滑鐨勬挱鏀惧櫒褰?tabBar锛夛細
      //   **澶х殑鏄?HDS 鑷繁鐢荤殑娴姩鑳跺泭鑳屾澘**锛屽皬鐨勬槸鎴戜滑閭ｆ潯鍐呭 鈬?灞忎笂涓€澶т竴灏忋€?
      //   鈬?鍘绘帀 HDS 杩欎竴灞傦紝鐩存帴娓叉煋 `HomeMiniBarPlayer`锛堝畠鑷甫 `MiniBarBackplate()` 鑷粯鑳屾澘锛?
      //     鈬?鍙墿杩欎竴涓紝瀹藉害 = `floatingMiniBarWidthVp()`銆侀珮搴?= `FLOATING_MINI_BAR_HEIGHT_VP`锛?
      //        涓庨椤甸偅鏉″悓涓€濂楀昂瀵稿彛寰勶紙涓嶅啀鏈?涓€澶т竴灏?锛夈€?
      // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆岃繖涓挱鏀炬潯鍔犱笂娌夋蹈鍏夋劅銆嶏級锛氭妸杩欐潯鎼洖 **HDS 娴姩搴曟爮**銆?
      //   鏈満 SDK 閫愯鏍歌繃锛坄D:\command-line-tools\sdk\default\hms\ets\api\@hms.hds.hdsBaseComponent.d.ets`锛夛細
      //   `systemMaterialEffect` 鍦?API 23/24 妗ｅ彧鏈変袱涓悎娉曡浇浣擄紝閮?@since 6.1.0(23)锛?
      //     路 `TitleBarStyleOptions.systemMaterialEffect`锛?1472锛夆啇 Navigation/NavDestination 鏍囬鏍忥紱
      //     路 `HdsTabsFloatingStyle.systemMaterialEffect`锛?5357锛夆啇 `HdsTabs.barFloatingStyle`锛?5582锛夈€?
      //   `CommonMethod` 涓婃病鏈夎繖涓睘鎬э紝鎸傚湪鏅€?`Column`/`Stack` 涓?*鏍规湰鍐欎笉鍑烘潵**锛?
      //   鑰屽畼鏂广€婃矇娴稿厜鎰熷姛鑳戒紭鍖栥€嬪張鎶婂畠闄愬埗鍦ㄣ€孨avigation/NavDestination 鏍囬鏍忋€嶆垨
      //   銆屾í鍚?Tabs 涓?barPosition == BarPosition.End 鐨勫簳閮?TabBar銆嶉噷 鈬?缁撹锛?
      //   杩欐潯娴姩鏉″彧鏈変綇杩?`HdsTabs` 鐨勬诞鍔ㄥ簳鏍忥紝鎵嶆嬁寰楀埌鐪熸鐨勫畼鏂规潗璐ㄣ€?
      //   鈿狅笍 鍗?Tab + **闈炵┖** TabContent锛氱┖ TabContent 鍦ㄧ湡鏈轰笂 HDS 涓嶇敾鑳跺泭鑳屾澘锛?026-10-01 瀹炴祴杩囷級銆?
      // 鈽呪槄鈽呪槄 2026-10-20锛堢涓夎疆锛夛細瀹夸富鎹㈡垚 {@link MiniBarMaterialCapsule} 鈥斺€?鏃犵晫
      //   `design/components/MaterialCapsule.ets` 鐨?V2 绉绘锛堢収鎶勶紝涓嶈嚜閫狅級锛?
      //     `HdsTabs` + `TabContent().tabBar(鍐呭)` + `barOverlap(true)` + `barPosition(End)`
      //     + `vertical(false)` + `barHeight(barHeight)` + `barWidth(barWidth)`
      //     + `barFloatingStyle{ systemMaterialEffect, barBottomMargin: slackH/2, gradientMask: 閫忔槑 }`銆?
      //   涓轰粈涔堜笉鍐嶆槸"鎶婂唴瀹瑰杩?HdsTabs 鐨?tabBar 妲?锛?
      //     鈶?鍏夋劅锛氭潗璐ㄤ粛鐒舵潵鑷?`HdsTabsFloatingStyle.systemMaterialEffect`锛圫DK :5357锛屽敮涓€鍚堟硶杞戒綋锛夛紱
      //     鈶?鎸ゅ帇锛氭暣涓?`HdsTabs` 鐜板湪钀藉湪**鎴戜滑鑷繁鐨勫瓙鏍?*閲岋紝鑳跺泭閭ｅ眰 `Stack` 涓婄殑
      //        `.scale({y: morphSquashY})` 鑳?*鍘嬪埌 HDS 鐢荤殑鏉愯川鑳屾澘**锛堟棤鐣?`morphGlass`
      //        `wujie.pa:155724-155745` 灏辨槸杩欎箞鍘嬬殑锛夛紱浣忓湪澹冲眰 `HdsTabs` 鐨?`miniBar` 妲介噷鏃跺仛涓嶅埌
      //        锛堣儗鏉挎槸妲界殑鍏勫紵锛屼笉鍦ㄦ垜浠瓙鏍戦噷锛夆€斺€?涓婁竴杞殑鐥呮牴銆?
      //     鈶?鈶＄骇椤?鍐呭鍋忓彸涓?锛?*鍙鍐呭涓嶅啀鐢诲湪 HDS 鐨?`tabBar` 妲介噷**锛堟Ы鐨勫嚑浣曚笉鍙娴嬶紝
      //        涓婁竴鐗堟嬁瀹冨綋鍐呭鐩?鈬?鐪熸満涓婁粛鍋忓彸涓嬶級銆傜幇鍦ㄥ唴瀹瑰眰 = `barWidth 脳 barHeight`銆?
      //        琚眳涓湪"楂?= barHeight + 2 脳 bottomMargin"鐨勭洅閲?鈬?涓庤兌鍥婄煩褰?*鍚屼竴涓畻寮?*锛?
      //        涓績鎭掔瓑锛屽亸鍙充笅鍦ㄧ粨鏋勪笂涓嶅彲鑳藉彂鐢燂紙瑙?`MiniBarMaterialCapsule` 绫绘敞閲婄浜?涓夎妭锛夈€?
      // 鈿狅笍 ArkTS 闄愬埗锛氬甫灏鹃殢 builder 鐨勭粨鏋勪綋璋冪敤涓嶈兘鍐嶆寕灞炴€ф柟娉?
      //   锛堝惁鍒欐姤 `Declaration or statement expected` + `Cannot find name 'id'`锛?
      //   鈬?澶栭潰濂椾竴灞?`Stack` 鎵胯浇 `.id / .clip / .onAppear / .onAreaChange`銆?
      Stack() {
        MiniBarMaterialCapsule({
          barWidth: this.floatingMiniBarWidthVp(),
          // 鈿狅笍 浜岀骇椤佃繖鏉＄殑楂樺害**鐢ㄦ埛璇?OK**锛堛€?.棣栭〉鏄珮搴︿綆璋冪殑鎾斁鏉°€嶉偅鏉″彧閽堝棣栭〉锛夛紝
          //   鎵€浠ヨ繖閲屼繚鎸佽璁￠珮搴?56锛?*涓嶈**璺熺潃棣栭〉涓€璧锋敼鐭€?
          barHeight: FLOATING_MINI_BAR_HEIGHT_VP,
          // 鏉″簳鍒?鏈粍浠剁洅搴?鐨勮窛绂伙細鐢ㄦ硶涓?`barFloatingStyle.barBottomMargin` 瀹屽叏鍚屼箟
          // 锛圫DK :5311銆宼he distance between tab bar and bottom of tabs銆嶏級鈬?閿洏閬胯鍙ｅ緞涓嶅彉銆?
          // 鈽?2026-10-20锛氬畠鍚屾椂鏄兌鍥婄殑**涓?涓嬬暀鐧?*锛堢洅楂?= barHeight + 2 脳 鏈€硷紝瑙?
          //   `MiniBarMaterialCapsule` 绫绘敞閲婄鍥涜妭锛夆噿 甯告€佺洅楂?= 56 + 2脳12 = **80**锛堜箣鍓?76锛夛紱
          //   澶氬嚭鏉ョ殑 4vp 鏄?*绾€忔槑 slack 鍦ㄨ兌鍥婁笂鏂?*锛岃兌鍥婅嚜韬殑灏哄/绂诲簳锛?2锛変竴涓瓧娌″姩銆?
          bottomMargin: this.floatingMiniBarBottomMarginVp(),
          // 鏉愯川妗ｄ綅涓庨椤甸偅鏉″叡鐢ㄤ竴浠斤紙`ambientTitleMaterial()`锛夆噿 涓ゆ潯鏄悓涓€濂楀厜鎰熴€?
          material: this.ambientTitleMaterial(),
          // 璇婃柇锛坄hdc shell hilog | grep RzdMiniBarFit`锛夛細涓庨椤甸偅鏉?*鍚屼竴浠?*鍏ュ弬銆?
          fitWinWVp: this.viewportWidthVp,
          fitSideMarginVp: this.floatingMiniBarSideMarginVp()
        }) {
          this.floatingMiniBarContent()
        }
      }
      // 鈿狅笍 涓嬮潰杩欎簺 HdsTabs 灞炴€?*宸叉暣娈电Щ璧?*锛氬畠浠幇鍦ㄤ綇鍦?`MiniBarMaterialCapsule`
      //   鑷繁鐨?`build()` 閲岋紙閫愭潯瀵圭収 `wujie.pa:60093-60240`锛岃閭ｄ釜鏂囦欢鐨勭被娉ㄩ噴琛級銆?
      //   杩欓噷**涓嶈**鍐嶅啓涓€閬嶏紙涓ゅ鍚勫啓涓€浠?= 鏃╂櫄婕傜Щ锛夈€?
      // 娑撳酣顩绘い闈涚俺閺嶅繐鎮撴稉鈧仦蹇撶娴ｅ秶鐤嗛敍姘殻閸ф顔栨稉璇叉倻娑撳顔€閸戝搫绨抽柈銊╀缉鐠佲晠鍋呮稉鈧禒鏂ょ礄barBottomMargin 瀹告彃缍婇梿璁圭礆
      // 閳?闁款喚娲忛柆鑳唨閿涘牏鏁ら幋?2026-10-12閵嗗奔绨╃痪褔銆夐棃銏℃尡閺€鐐蒋閸旂姳绗傞柨顔炬磸闁儻顔€閵嗗稄绱氶敍姘舵暛閻╂ê鑴婇崙鐑樻閸︺劏绻栨禒钘変焊缁夎绗?
      //   閸愬秴鍣洪幒?`floatingMiniBarKeyboardLiftVp()`閿? 闁款喚娲忔妯哄 + 8 閳?鐢憡鈧焦妫﹂張澶愭？闂呮瑱绱氶埇?閺佸瓨娼€瑰じ瀵?
      //   鏉╃偛鎮?HDS 閼宠泛娉稉鈧挧铚傜瑐閹额剙鍩岄柨顔炬磸娑撳﹥閮ㄦ稊瀣╃瑐閿涙盯鏁惄妯绘暪鐠у嘲鎮?lift 閹帊璐?0 閳?鏉╂瑤绔寸悰?*闁劕鐡х粵澶夌艾**
      //   閺€鐟板З閸撳秶娈?`homeTabBarBottomMarginVp()`閿涘牆娲栬ぐ鎺斿缁惧尅绱濈憴渚€鍋呮稉顏勫毐閺佹壆娈戝▔銊╁櫞閿涘鈧?
      // 鈽呪槄鈽?2026-10-18锛氳繖閲?*娌℃湁** `.offset` 浜?鈥斺€?閿洏閬胯涓€寰嬭蛋涓婇潰 `barFloatingStyle.barBottomMargin`
      //   锛堝彧鎸兌鍥婏紝瀹夸富鐩掍笌瀹冨簳涓嬮偅灞傛潗璐ㄥ師鍦颁笉鍔級銆傛妸鏈潯閲嶆柊鎺ュ洖 `.offset` = "鏁翠釜搴曚笅琚姮涓婃潵"澶嶇幇銆?
      .id(SECONDARY_MINI_BAR_HOST_ID)
      // 鈽呪槄鈽?2026-10-20锛堢鍏疆锛夛細妯悜鎽嗕綅浜ょ粰**涓庨椤靛悓涓€涓嚱鏁?*锛坽@link miniBarBoxRightMarginVp}锛夈€?
      //   鏈疆涔嬪墠杩欓噷闈?`Alignment.Bottom`锛堢洅灞呬腑锛夆€斺€?缁撴灉瀵癸紝浣?*涓庨椤电殑鍙抽敋 + margin 涓嶆槸鍚屼竴濂楀啓娉?*锛?
      //   鑰岄椤甸偅涓?margin 鐢ㄧ殑鏄兌鍥婂鑰屼笉鏄洅瀹?鈬?涓ゆ潯宸?5vp銆傜幇鍦ㄤ袱鑰呴兘鍐?鍙抽敋 + 鐩掑 margin"锛?
      //   绠楀紡涓€澶勩€佸嚑浣曚竴鑷达細`鑳跺泭鍙崇紭 = winW 鈭?side`銆?
      .margin({ right: this.miniBarBoxRightMarginVp(this.secondaryMiniBarBoxWidthVp(), false) })
      // 娑撳秷顩︾憗渚婄窗HDS 閻ㄥ嫭娼楃拹銊ㄥ剹閺?閹舵ê鐨犻懠鍐ㄦ纯濮ｆ柨鍞寸€瑰湱娲呮径褝绱濈憗浣风啊娴兼氨宸辨稉鈧崷鍫涒偓?
      .clip(false)
      .onAppear((): void => {
        // 鈿狅笍 杩欒蹇呴』涓庝唬鐮?*鍚屼箟**锛堝亣鏃ュ織姣旀病鏃ュ織鏇村浜猴紝搂183 韪╄繃锛夛細
        //   瀹夸富宸蹭笉鏄?澹冲眰 HdsTabs 鐨?tabBar 妲?锛岃€屾槸鎴戜滑瀛愭爲閲岀殑 `MiniBarMaterialCapsule`
        //   锛堝畠鍐呴儴浠嶆槸涓€涓?`HdsTabs` 娴姩搴曟爮锛夆噿 鍏夋劅鏉ユ簮浠嶆槸 `systemMaterialEffect`锛?
        //   浣?瀹樻柟鍖哄煙"杩欏彞璇濆凡涓嶉€傜敤锛屾敼鎴愬瀹炴弿杩般€?
        Logger.info('RzdSecondaryMiniMaterial',
          `mode=capsule-hds-material host=our-subtree-hdstabs ` +
            `barWidth=${this.floatingMiniBarWidthVp()} barHeight=${FLOATING_MINI_BAR_HEIGHT_VP} ` +
            `slackW=${CAPSULE_SLACK_W} slackH=${CAPSULE_SLACK_H} ` +
            `contentBox=barWidth脳barHeight align=stackCenter selfPlate=off ` +
            `contentLayer=own-capsule-rect slotProbe=on ` +
            `bottomGap=${FLOATING_MINI_BAR_BOTTOM_GAP_VP} keyGap=${FLOATING_MINI_BAR_KEYBOARD_GAP_VP} ` +
            `barBottomMargin=${this.floatingMiniBarBottomMarginVp()} ` +
            `ambient=${this.ambientLevelIndex()} squashY=${this.expandState.morphSquashY} singleVisibleBar=true`);
      })
      .onAreaChange((_oldArea: Area, area: Area): void => {
        // 杩欓噷鐨?width/height 鏄?*鑳跺泭缁勪欢鐩?*锛? 鑳跺泭 + 妯悜 slackW + 涓婁笅鍚?`barBottomMargin`锛夛紝
        // 涓嶆槸鑳跺泭鏈韩锛涜兌鍥?= `barWidth 脳 barHeight`锛屼綅缃?= 鐩掑唴灞呬腑锛堟í鍚戙€佺旱鍚戦兘灞呬腑锛?
        // 鍥犱负鐩掗珮鎭掍负 `barHeight + 2 脳 barBottomMargin`锛夈€?
        const boxW: number = areaLengthToVp(area.width);
        const boxH: number = areaLengthToVp(area.height);
        Logger.info('RzdSecondaryMiniMaterial',
          `capsuleBox width=${boxW} height=${boxH} ` +
            `expectW=${this.floatingMiniBarWidthVp() + CAPSULE_SLACK_W} ` +
            `expectH=${FLOATING_MINI_BAR_HEIGHT_VP + 2 * this.floatingMiniBarBottomMarginVp()} ` +
            `barWidth=${this.floatingMiniBarWidthVp()} barHeight=${FLOATING_MINI_BAR_HEIGHT_VP} ` +
            `bottomGap=${FLOATING_MINI_BAR_BOTTOM_GAP_VP} keyGap=${FLOATING_MINI_BAR_KEYBOARD_GAP_VP} ` +
            `keyboardVp=${this.keyboardBottomVp()} lift=${this.floatingMiniBarKeyboardLiftVp()} ` +
            `hostOffset=${this.floatingMiniBarHostOffsetYVp()} ` +
            `barBottomMargin=${this.floatingMiniBarBottomMarginVp()} ` +
            `pageBottomInset=${this.pageBottomInsetVp()} squashY=${this.expandState.morphSquashY} ` +
            `ambient=${this.ambientLevelIndex()}`);
      })
      // 閳跨媴绗?**娑撳秷顩?*閸︺劏绻栭柌灞藉晙閸愭瑤绔存稉?`.margin({ bottom: ... })`閿涙氨顬囨惔鏇＄獩缁傝鍑＄紒蹇曟暠
      //    `barFloatingStyle.barBottomMargin` 缂佹瑤绨￠敍鍫滅瑢妫ｆ牠銆夐柇锝嗘蒋鐎规ɑ鏌熸惔鏇熺埉閸氬奔绔撮崣锝呯窞閿涘鈧?
      //    娑撱倓閲滄稉鈧挧宄板晸 = 缁傝绨崇捄婵堫瀲缂堣鈧稄绱濋惇鐔告簚娑撳﹦婀呴惈鈧亸杈ㄦЦ"閹绢厽鏂侀弶鈩冭癁瀵版銇婃?閿涘牏鏁ら幋?2026-10-11 鐠佲晝婀呴惃鍕亝閺夆槄绱氶妴?
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignContent(Alignment.BottomEnd)
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(20)
    // Hidden preserves anchors/layout and hides the floating bar with its controls immediately.
    .visibility((this.expandState.sourceBarHidden || this.expandState.shrinkHidesBar || this.expandState.miniOut || this.expandState.hdsBarSuppressed) ? Visibility.Hidden : Visibility.Visible)
  }

  /**
   * 鈽呪槄鈽?2026-10-20锛堢涓夎疆锛夛細鍘熸潵杩欓噷鐨?`floatingMiniBarTabBarBox()` **宸插垹闄?*銆?
   *
   * 瀹冪殑鍘嗗彶浣垮懡鏄?鐚?HDS 缁?tabBar 鐨?*妲介珮**"锛坄LayoutPolicy.matchParent` + `constraintSize`
   * 涓婁笅闄?+ `alignContent: Center`锛夛紝鍐嶇敤 `(妲介珮 鈭?56) / 2` 鍙嶆帹鐣欑櫧 鈥斺€?閭ｆ鏄?
   * 銆屽唴瀹瑰亸鍙充笅銆嶇殑鏉ユ簮锛氭Ы楂樹笉绛変簬鑳跺泭楂橈紝灞呬腑瀵硅薄閿欎簡锛屽氨鍙兘闈犺皟鏁板€煎噾銆?
   *
   * 鐜板湪**鍐呭鐩?鈮?鑳跺泭鐩?*锛氬唴瀹圭洿鎺ョ敾鍦?{@link MiniBarMaterialCapsule} 鐨?`tabBar`
   * builder 閲岋紝鐩掑瓙鐢?`barWidth 脳 barHeight` 缁欏嚭锛堝悓涓€涓嚱鏁般€佸悓涓€缁勬暟锛夛紝
   * 鍐呴儴 `Stack(alignContent: Center)` 鈬?灞呬腑鏄竴鐪煎彲绠楃殑锛屼笉闇€瑕佷换浣?妲介珮"鍋囪銆?
   * 鈿狅笍 涓嶈鍐嶆妸 `matchParent` / `constraintSize` 閭ｄ竴濂楁惉鍥炴潵銆?
   */

  /**
   * 鐎规ɑ鏌熷ù顔煎З閺嶅繘鍣?*閸烆垯绔撮崣顖濐潌閻ㄥ嫬鍞寸€?*閿涘牓銆夌粵鐐埉 CustomBuilder閿涘鈧?
   *
   * 鐏忓搫顕稉?{@link floatingMiniBar} 閻ㄥ嫬顔栨稉鑽ゆ磪娑撱儲鐗告稉鈧懛杈剧窗鐎瑰じ瀵岄弰?56vp 妤傛﹫绱濇潻娆撳櫡閸愬秴鍟撳璁崇濞嗏槄绱?
   * 閸忓秴绶?HDS 閻ㄥ嫭甯撶敮鍐ㄥ綁閸栨牭绱欐稉銈嗗笓/閸楁洘甯撻敍澶嬪Ω鐏忎線娼版禒?44 缂傗晜鍨?30閵?
   *
   * 閳?2026-10-15閿?閹绢厽鏂侀弶鈩冩纯缁?闁絾娼敍澶涚窗`HomeMiniBarPlayer` 閼奉亜绻侀惃鍕彯鎼达箑鍑＄紒蹇斿畾閸?56vp
   *   閿涘牆鐨濋棃?40 + 娑撳﹣绗呴崥?8 閳ユ柡鈧?鐟?`HomeMiniBarAlbumCover.coverSideLengthVp()` 娑?
   *   `HomeMiniBarPlayer.sidePadVp()` 閻ㄥ嫭鏁為柌濠忕礆閿涘本澧嶆禒銉ㄧ箹娑撯偓濡楋綇绱欑亸渚€娼?44閿涘婀張?Builder 闁?
   *   缁犳鍤弶銉ф畱妤傛ê瀹抽弰?44 + 8鑴? = **60vp**閿涘本鐦€瑰じ瀵屽Σ浠嬬彯 4vp 閳ユ柡鈧?娴溿倗绮?HDS 鐏炲懍鑵戦崡鍐插讲
   *   閿涘牆顦块崙鐑樻降閻?4vp 閺勵垵顔曠拋鈥茬瑐閺勫海鈥樼拋鈺傤劄閻ㄥ嫪缍戦柌蹇ョ礉娑撳秷顩﹂崘宥呭閸ュ搫鐣?height 閸樿銇欑€瑰喛绱?
   *    2026-10-12 闁絾顐?瀵缚顢戠€?56vp 閳?閺佸瓨甯撻崗鍐娴?6~8vp"閻ㄥ嫭鏆€鐠侇厼姘ㄩ崷銊ょ瑓闂堛垽鍋呴弶鈩冩暈闁插﹪鍣烽敍澶堚偓?
   * 娑撳﹥濯?閻愮懓鍤幍鎾崇磻閹绢厽鏂佹い鐢垫畱閹靛濞嶉崷?`HomeMiniBarPlayer` 閸愬懘鍎撮敍宀冪箹闁插奔绗夌憰渚€鍣告径宥嗗瘯閵?
   */
  @Builder
  private floatingMiniBarContent() {
    HomeMiniBarPlayer({
      showPreviousTrack: false,
      followAppMiniBarExpanded: false,
      // 鈽呪槄鈽?2026-10-18锛氳繖鏉′綇鍦?HDS 娴姩搴曟爮閲岋紝鑳跺泭涓庢潗璐ㄧ敱 `barFloatingStyle.systemMaterialEffect`
      //   鐢伙紙瀹樻柟鏉愯川锛夆噿 鑷粯鑳屾澘蹇呴』鍏虫帀銆備笉鍏冲氨鏄€岀湡鏉愯川 + 涓€灞?#30F1F3F5 + 涓€灞傛ā绯娿€嶄袱灞傚彔鐫€锛?
      //   鏉愯川琚礂鐧?鈥斺€?涓婁竴杞敤鎴疯鐨勩€屽ぇ鐨勶紙HDS 鑳跺泭锛夊拰灏忎竴鍦堢殑锛堣嚜缁橈級銆嶄篃鏄繖涓彔娉曘€?
      //   锛堥椤甸偅鏉?2026-10-18 鏅氫篃鏀规垚鍚屼竴涓彛寰勶細`enableMiniBarBackground: true` + 杩欓噷浼?false锛?
      //      瑙?{@link miniBar}銆備袱澶勭幇鍦ㄦ槸鍚屼竴濂?鈥斺€?"鏉愯川鐢?HDS 鐢伙紝鎴戜滑鍙敾鍐呭"銆傦級
      showSelfDrawnBackplate: false,
      // 鈽呪槄鈽?2026-10-18锛堟櫄锛夛細**鎶婂唴瀹归拤鍦ㄨ璁￠珮搴?* `FLOATING_MINI_BAR_HEIGHT_VP`(56)銆?
      //   `HomeMiniBarPlayer` 鐨勮嚜鐒堕珮搴?= 灏侀潰 + 涓婁笅鍚?8vp 鍐呰窛锛氬父瑙勬€佸皝闈?44 鈬?**60vp**
      //   锛堟矇娴稿紡鑷敱绐楀彛閭ｄ竴妗ｅ皝闈?40 鈬?56vp锛夛紝涓庤璁￠珮搴?56 宸?4vp銆?
      //   涓嶉拤浣忕殑璇?璋佹瘮璋侀珮"鍙栧喅浜庣獥鍙ｈ楗版。浣嶏紱閽変綇涔嬪悗**鍞竴鍙橀噺鍙墿鑳跺泭楂樺害**锛?
      //   鍐呭鐩?= 鑳跺泭鐩?= 56 鈬?涓婁笅鐣欑櫧鎭掍负 0锛堝唴瀹硅嚜宸卞眳涓紝瑙?`MiniBarMaterialCapsule.ContentLayer`锛夈€?
      // 鈽?2026-10-20锛堢浜岃疆锛夛細閽変綇涔嬪悗**鍐呭琛岃嚜宸变篃鍚冨悓涓€涓笂闄?*锛坄HomeMiniBarPlayer` 閲?
      //   Row 涓婄殑 `constraintSize.maxHeight`锛夛紝鍚﹀垯琛?60 > 鐩?56 = "瀛愪欢姣斿鍣ㄥぇ"锛?
      //   鎺掑竷浜ょ粰寮曟搸鍏滃簳 鈥斺€?閭ｆ鏄?2vp 鍚戜笅鍋忓樊鐨勫€欓€夋潵婧愩€?
      contentHeightVp: FLOATING_MINI_BAR_HEIGHT_VP,
      // 鈽呪槄鈽?绗竷杞紙鐢ㄦ埛锛氥€屼簩绾ч〉闈⑩€﹀皝闈㈢宸︿晶澶繙銆嶏級锛氫笌棣栭〉閭ｆ潯**鍚屼竴涓満鍒?* 鈥斺€?
      //   鎶婂皝闈㈢湡瀹炵殑甯冨眬鐩掍紶杩涘幓锛宍sidePad = (鑳跺泭楂?鈭?灏侀潰鐩?/2` 鈬?灏侀潰鍐呮帴浜庤兌鍥?
      //   锛堣瑙夊乏杈硅窛 鈮?涓婁笅鐣欑櫧锛夈€傛湰椤电殑妗ｄ綅涓?`HomeMiniBarAlbumCover` 鍚屽彛寰勶細
      //   `followAppMiniBarExpanded: false` 鏃跺畠涓嶅啀璇?HDS 鏍忔帓甯冿紝鍙墿"娌夋蹈寮?40 / 鍚﹀垯 44"銆?
      // 鈽?2026-10-21锛堢鍏疆锛夛細涓庨椤甸偅鏉?*鍚屼竴涓皝闈㈡満鍒?*锛?2 鐩?脳 `scale(1.4)`锛夆噿 涓嶅啀浼?
      //   `coverSideVp`銆備笂娓镐笁褰㈡€佽〃瀵逛簩绾ч〉閫愰」涓€鑷达細鑳跺泭 56 / 瑙嗚灏侀潰 44.8 / 瑙嗚宸﹁竟璺?5.6锛?
      //   涓夎€呴兘鐢?`HomeMiniBarPlayer.sidePadVp()` + `HomeMiniBarAlbumCover.coverScale()` 鑷畻銆?
      // 鈽呪槄鈽?2026-10-20锛氭尋鍘嬩氦缁?{@link MiniBarMaterialCapsule} 閭ｄ竴灞傦紙瀹冨帇鍦?瀹樻柟鏉愯川鑳屾澘 + 鍐呭"
      //   鍚屼竴涓彉鎹㈠煙涓婏級銆傝繖閲岃嫢鍐嶅帇涓€娆★紝涓や釜 0.86 鐩镐箻 = 0.74 鈥斺€?寮硅繃澶达紝鏄?鏀逛竴鏀瑰氨鍘嬫"鐨勫垽鎹€?
      contentOwnsSquash: false
    })
      // 閳藉應妲?閻劍鍩?2026-10-11 鐎规俺顔戦敍姘モ偓宀勬晩娴ｅ秶娈戦弰顖涙尡閺€鐐蒋娑撳﹦娈?*閸忓啰绀?*閼板奔绗夐弰顖涙尡閺€鐐蒋閺堫剝闊╅妴宥冣偓?
      //   閼宠泛娉€硅棄瀹抽悽?`barFloatingStyle.barWidth` 缂佹瑥鍤敍? 缁愭褰涚€?閳?娑撱倓鏅堕悾娆戞 side閿涘绱滺DS 閹跺﹤鐣?*鐏炲懍鑵?*閻紮绱?
      //   閼板矁绻栭柌灞藉斧閺夈儱鍟?`width('100%')`閿? 鐎瑰じ瀵岄惄鎺戝弿鐎规枻绱氶埇?閸愬懎顔愬В鏃囧厡閸ュ﹤顔?2鑴硈ide閿?
      //   鐏忎線娼扮拹瀵告絻閼宠泛娉锔剧喘閵嗕礁褰告笟褎瀵滈柦顕€銆婇崚鎷屽厡閸ュ﹤褰哥紓?閳?閻娼冪亸杈ㄦЦ"閸忓啰绀岄柨娆庣秴"閵?
      //   閻滄澘婀幎濠傚敶鐎圭懓顔旀惔锔跨瘍鐎规碍鍨氶懗璺烘抄鐎硅棄瀹抽敍鍫濇倱娑撯偓閸戣姤鏆熼妴浣告倱娑撯偓閸欙絽绶為敍澶涚礉HDS 鐏炲懍鑵戦崥搴濊⒈閼?*鐎瑰苯鍙忛柌宥呮値**閵?
      // 閳藉應妲?2026-10-12 閺傝顢?A 鐎圭偤鐛欓敍姘敶鐎圭懓顔?= 閼宠泛娉€规枻绱欐稉?barFloatingStyle.barWidth 閸氬奔绔撮崙鑺ユ殶閸氬苯褰涘鍕剁礆
      //   鐠囧﹥鏌囨笟婵囧祦閿涘牆褰熸稉鈧Ο鈥崇€锋禍銈呭级鐠囪崵鐖滈敍澶涚窗閸愬懎顔愰惄鎺戝斧閺?= 鐎瑰じ瀵岄惄?= 缁愭褰涚€规枻绱濆В鏃囧厡閸ュ﹤顔?2鑴硈ide 娑撴柨涔忕€靛綊缍堥敍?
      //   閸欏厖鏅堕幐澶愭尦缁ㄥ洩顫﹂幒銊ュ煂閼宠泛娉崣宕囩喘娑斿顦?閳?閵嗗苯鍘撶槐鐘虹獓閸掓澘褰告稉瀣潡閵嗗秲鈧倵鎲?閼汇儴绻栭悧鍫滅矝閻掕埖娲跨化鐕傜礉娑撯偓閸欍儴鐦介幋鎴犵彌閸掕娲栭柅鈧妴?
      // 鈽呪槄鈽?2026-10-20锛?*鍐呭鐩?鈮?鑳跺泭鐩?*锛堥兘鍦?`MiniBarMaterialCapsule` 閲岋紝鐢?`barWidth 脳 barHeight`
      //   鍞竴纭畾锛夆噿 杩欓噷鍙渶瑕?閾烘弧鍐呭鐩?锛屽搴?*涓嶅啀**鐢辨湰鏂囦欢绠楃浜岄亶銆?
      //   鍘嗗彶锛氳繖閲屾浘鍐?`width(this.floatingMiniBarWidthVp())`锛堝唴瀹瑰 == 鑳跺泭瀹斤級鈥斺€?
      //   瀹藉害閭ｄ竴缁存槸瀵圭殑锛岄敊鍦ㄩ珮搴﹀悆鐨勬槸 HDS 鐨勬Ы楂樿€屼笉鏄兌鍥婇珮 鈬?瑙傛劅"鍋忓彸涓?銆?
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 閳藉應妲?閻劍鍩?2026-10-11閿涙哎鈧奔绨╃痪褔銆夐棃銏℃尡閺€鎯ф珤娓氭繃妫柨娆庣秴閳ワ箑鐣犻弰顖濈獓閸掓澘褰告稉瀣潡娴滃棎鈧秮鈧柡鈧?
      //   缂佹捁顔戦敍?*娑撳秷顩﹂弨鐟板敶鐎瑰湱娈戠€逛粙鐝?*閿涘牅绔撮弨鐟版皑娑?HDS 閻ㄥ嫯鍏岄崶濠傜暰娴ｅ秵澧﹂弸璁圭礉閸忓啰绀岄弫缈犵秼閸欏厖绗呴崑蹇ョ礆閿?
      // 閳藉應妲?GLM5.3閿涘潷rovider=zai閿涘鐦栭弬?2026-10-12閿涙DS 濞搭喖濮╅懗璺烘抄缂?tabBar 閻?*閸愬懎顔愬Σ钘夊涧閺堝鍏岄崶濠囧亝娑斿牓鐝敍鍫氬40vp閿?*閿?
      //   閼板矁绻栭柌灞惧Ω閸愬懎顔愬楦款攽鐎规碍鍨?56vp閿涘牆鐨濋棃?44 + 娑撳﹣绗?padding 6+6閿涘鍣?閸愬懎顔愬В鏃€蝎妤?~16vp閿?
      //   娴滃孩妲搁弫瀛樺笓閸忓啰绀岄惄绋款嚠閼宠泛娉稉顓炵妇**娴ｅ海瀹?6~8vp**閿涘牏婀￠張娲櫤閸?6vp閿涘奔绗岄幋顏勬禈娑撯偓閼疯揪绱氶妴?
      //   閳?娑撳秴鍟€瀵搫鍩楁妯哄閿涘奔姘︾紒?HDS 閹稿婀＄€圭偞蝎娴ｅ秷鍤滈柌蹇撹嫙鐏炲懍鑵戦敍娑橆啍鎼达缚绮涢幐澶庡厡閸ュ﹤顔旈敍鍫熸煙濡?A閿涘苯鍑＄憴浣规櫏閿涘鈧?
  }

  // 閳跨媴绗?鏉╂瑩鍣烽崢鐔告降閹?閼奉亜绻佺粻妤佺埉鐎?閻ㄥ嫪琚辨稉顏囩窡閸斺晛鍤遍弫鏉垮灩閹哄绻冮敍?026-10-11 娑撳﹤宕嶉敍澶涚礉閻炲棛鏁遍弰?閺嶅繐顔旀禍銈囩舶 HDS"閿?
  //    閻喐婧€鐠囦焦妲?*娑撳秷顢?*閿涙DS 姒涙顓荤€硅棄瀹抽崣顏呮箒娑撯偓鐏忓繐娼归敍灞炬尡閺€鎯ф珤閸愬懎顔愰弫缈犻嚋濠с垹鍤懗璺烘抄婢舵牭绱欓悽銊﹀煕閹搭亜娴?娑撯偓閸?閿?
  //    閳?閻滄澘婀幐澶婄暭閺?`barWidth` 娑撳銆傞弰鎯х础缂佹瑥娲栭弶銉礄鐟?`floatingMiniBar()`閿涘鈧?

  /** 閹剚璇炴潻铚傜稑閺夛紕娈戝锕€褰搁梻纾嬬獩閿涘澊p閿涘绱伴崣顏勬躬鐏忓繐鐫嗙紒娆庣閻愮绔熺捄婵撶礉鐎硅棄鐫嗙仦鍛厬閻ｆ瑧娅ч妴?*/
  private floatingMiniBarSideMarginVp(): number {
    return new BreakpointType(12, 16, 96, 160, 9).getWidthValueWithHeightSM(
      this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint);
  }

  /**
   * 閹剚璇炴潻铚傜稑閺夆€愁啍鎼达讣绱檝p閿涘绱伴崘娆掔箻 `barFloatingStyle.barWidth` 閻ㄥ嫪绗佸锝冣偓?
   *
   * 閹靛婧€閿涙氨鐛ラ崣锝咁啍 閳?娑撱倓鏅舵潏纭呯獩閿?2 / 16閿涘绱辩€硅棄鐫嗛敍姘仚閸?{@link FLOATING_MINI_BAR_MAX_WIDTH_VP} 閸愬懎鐪虫稉顓溾偓?
   * 闁插繋绗夐崚鎵崶閸欙絽顔旈弮鍓佺舶 336 閸忔粌绨抽敍鍫熸＋閼宠泛娉崥灞藉經瀵板嫸绱氶妴?
   * @returns 鐎硅棄瀹抽敍鍧磒閿涘鈧?
   */
  private floatingMiniBarWidthVp(): number {
    const side: number = this.floatingMiniBarSideMarginVp();
    // 鈽呪槄鈽?2026-10-20锛堢鍏疆锛夛細**鎭掑す鍒板彲鐢ㄥ涔嬪唴**銆傛棫瀹炵幇鏈変袱澶勪細瓒婄晫锛?
    //   鈶?`viewportWidthVp <= 0`锛堥甯ц繕娌￠噺鍒扮獥鍙ｅ锛夋椂纭繑鍥?336 鈬?鑳跺泭鐩掑 346
    //      > 浠讳綍 < 360vp 鐨勭獥鍙ｏ紙鎶樺彔灞忓灞?/ 灏忕獥 / 鍒嗗睆锛夆噿 **鐩掑嚭鐣?*锛?
    //   鈶?鎵嬫満妗?`Math.max(220, full)` 鈬?绐楀彛 < 244vp 鏃舵妸鑳跺泭鎾戝埌**姣斿彲鐢ㄥ杩樺**銆?
    //   鐜板湪 `want` 鍏堜笌 `available` 鍙栧皬銆佽繑鍥炲€煎啀涓?`available` 鍙栧皬 鈬?
    //   **`barWidth 鈮?availableW = winW 鈭?2脳side` 鏄粨鏋勬€х殑**锛堜笉鏄皟鏁板€艰皟鍑烘潵鐨勶級銆?
    //   鍒ゆ嵁锛歚grep RzdMiniBarFit` 鐨?`availableW` 涓?`barW` 涓や釜鏁板繀椤诲墠鑰?鈮?鍚庤€呫€?
    const winW: number = this.viewportWidthVp;
    if (winW <= 0) {
      return FLOATING_MINI_BAR_FALLBACK_WIDTH_VP;
    }
    const full: number = winW - side * 2;
    const available: number = full > 0 ? full : winW;
    const isWide: boolean = this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_MD;
    const want: number = isWide ? Math.min(FLOATING_MINI_BAR_MAX_WIDTH_VP, available) : available;
    return Math.min(want, available);
  }

  /**
   * @returns 鑳跺泭**鐩?*瀹斤紙vp锛夆€斺€?涓?`MiniBarMaterialCapsule.capsuleBoxWidthVp()` **鍚屼竴绠楀紡**銆?
   *
   * 涓轰粈涔堣繖閲岃鍐嶅啓涓€閬嶏細鑳跺泭鐩掑鍙湪涓ゅ鐢ㄥ埌锛堜袱鏉″涓荤殑妯悜鎽嗕綅銆佽瘖鏂棩蹇楋級锛?
   * 鑰?`features/playlist/Index.ets` 鐨?barrel锛堟湰杞鏀癸級娌℃湁瀵煎嚭閭ｄ釜鍑芥暟銆?
   * 涓ゅ**蹇呴』**鍚屾锛氬垽鎹湪 `RzdMiniBarFit`锛坄hdc shell hilog | grep RzdMiniBarFit`锛夆€斺€?
   * 瀹炴祴 `boxW` 涓?`barW + slackW`锛堝崟灞傛€?`barW`锛変笉鐩哥瓑锛屽氨璇存槑杩欓噷婕備簡銆?
   * @param barWidth 鑳跺泭鍙瀹藉害锛坴p锛?
   * @param singleRow 鏄惁鍗曞眰鎬侊紙杩蜂綘鏉′笌椤电骞舵帓 鈬?妯悜 slack 褰掗浂锛?
   */
  private miniBarBoxWidthVp(barWidth: number, singleRow: boolean): number {
    return singleRow ? barWidth : barWidth + CAPSULE_SLACK_W;
  }

  // 锛堥椤甸偅鏉″凡缁忎笉鍦ㄨ繖閲岀畻鐩掑浜嗭細瀹冧綇 HDS 鐨?`miniBar` 妲斤紝瀹藉害鐢辨Ы鎸夊唴瀹归噺缁欍€傦級

  /** @returns 浜岀骇椤垫诞鍔ㄨ糠浣犺兌鍥婄殑**鐩?*瀹斤紙vp锛夛紙浜岀骇椤垫亽鍙屽眰 鈬?slack 鐓у姞锛夈€?*/
  private secondaryMiniBarBoxWidthVp(): number {
    return this.miniBarBoxWidthVp(this.floatingMiniBarWidthVp(), false);
  }

  /**
   * @returns 鑳跺泭鐩掔殑**鍙冲杈硅窛**锛坴p锛夆€斺€?涓ゆ潯瀹夸富**鍏辩敤杩欎竴涓畻寮?*锛堢鍏疆鍞竴鐨勬憜浣嶅彛寰勶級銆?
   *
   * ```
   *   鍙屽眰锛歳ightMargin = (winW 鈭?boxW) / 2
   *         鈬?鐩掑彸缂?= winW 鈭?(winW 鈭?boxW)/2 = (winW + boxW)/2
   *         鈬?鑳跺泭鍙崇紭 = 鐩掑彸缂?鈭?(boxW 鈭?barW)/2 = (winW + barW)/2 = winW 鈭?side
   *   鍗曞眰锛歳ightMargin = side 鈬?鐩?鈮?鑳跺泭锛坰lack 褰掗浂锛夆噿 鍙崇紭涓庨〉绛炬帓鍙崇紭榻?
   * ```
   * 鈬?**`鑳跺泭鍙崇紭 = winW 鈭?side` 鏄亽绛夊紡**锛堝弻灞備笌鍗曞眰鍚屼竴涓彸缂橈級锛?
   *   鍗?鍙充晶涓嶄細鍑哄睆"鐨勭畻寮忔簮澶淬€傝 `RzdMiniBarFit` 鐨?`rightGap == side`銆?
   * @param boxW 鐩掑锛坴p锛?
   * @param singleRow 鏄惁鍗曞眰鎬?
   */
  private miniBarBoxRightMarginVp(boxW: number, singleRow: boolean): number {
    if (singleRow) {
      return this.floatingMiniBarSideMarginVp();
    }
    if (this.viewportWidthVp <= 0) {
      return this.floatingMiniBarSideMarginVp();
    }
    const gap: number = this.viewportWidthVp - boxW;
    return gap > 0 ? gap / 2 : 0;
  }

  /**
   * 閹剚璇炴潻铚傜稑閺夆剝妲搁崥锕€褰茬憴浣碘偓?
   *
   * 妫ｆ牠銆夋稉宥嗘▔缁€鐚寸礄HDS 鎼存洘鐖柌宀€娈戞潻铚傜稑閺壜ょ鐠愶綇绱氶敍娑欘劀閸︺劍鎸遍弨鎯у弿鐏炲繘銆夐幋鏍ь槱娴滃孩澹掗柌蹇涒偓澶嬪濡€崇础閺冩湹绡冩稉宥嗘▔缁€鎭掆偓?
   * @returns True 鐞涖劎銇氶弰鍓с仛婢瑰啿鐪版潻娆愭蒋閹剚璇炴潻铚傜稑閺壜扳偓?
   */
  private shouldShowFloatingMiniBar(): boolean {
    if (this.navDepth <= 0) {
      return false;
    }
    // 閳跨媴绗?瑜般垹褰夐張鐔兼？**韫囧懘銆忕紒褏鐢婚弰鍓с仛**閿涙碍鎸遍弨楣冦€夊ù顔肩湴閺勵垯绮犳潻娆愭蒋鏉╄渹缍橀弶锟犲亝闁插矂鏆遍崙鐑樻降閻ㄥ嫸绱?
    //    鐠ч攱澧滈柇锝勭鐢勬尡閺€楣冦€?*閸戠姳绠惇瀣╃瑝鐟?*閿涘牆鐣犲銈呭煝閸欘亜宕?鏉╄渹缍橀弶锟犲亝娑斿牆銇囬惃鍕梿閸擃亞鐛ラ崣?閿?
    //    閼板瞼鐛ラ崣锝夊櫡閻㈣崵娈戦崣鍫熸Ц閸掓俺鎹ｅ銉ф畱缂傗晜鏂侀崘鍛啇 閳ユ柡鈧?閳?娑撳秵妲?閺佹挳銆夊ǎ鈥冲弳"閿?
    //    `morphPageOpacity()` 闁絼閲滈崙鑺ユ殶**閻╊喖澧犲▽鈩冩箒濞戝牐鍨傞懓?*閿涘矁顫嗙€瑰啳鍤滃杈╂畱濞夈劑鍣撮敍澶涚礉
    //    鏉╂瑦妞傞崐娆愬Ω鏉╄渹缍橀弶陇妫屾禍鍡礉閻劍鍩涢惇瀣煂閻ㄥ嫬姘ㄩ弰?鐏炲繐绠锋稉瀣煙缁愪胶鍔х粚杞扮啊娑撯偓閸?閸愬秴鍟嬮崙杞扮娑擃亝鏌熼崸妞尖偓?
    //    鐎瑰啳鍤滃鍗炴躬瑜般垹褰夐張鐔兼？娴兼碍璐伴崙鐚寸礄`miniBarOpacity`閿涘绱濇禍銈嗩棗缂佹瑦鎸遍弨楣冦€夐妴?
    if (this.appState.isShowPlay && !this.expandState.morphContainerActive()) {
      return false;
    }
    // 閳?娴滃瞼楠囨い鐢告桨娑?HDS 濞搭喖濮╂惔鏇熺埉娑撳秴褰茬憴渚婄礄鐞?NavDestination 閻╂牔缍囬敍澶涚礉閹绢厽鏂侀崳銊ュ涧閼崇晫鏁辨竟鍐茬湴鏉╂瑤绔撮弶陇绀嬬拹?閳ユ柡鈧?
    //   閹碘偓娴?*鐏炴洖绱戦幀浣风瘍韫囧懘銆忛弰鍓с仛**閵嗗倹妫禒锝囩垳閸︺劏绻栭柌?`miniBarExpanded` 娑撹櫣婀＄亸杈箲閸?false閿?
    //   娴滃孩妲告潻娑楃癌缁狙囥€夐棃銏℃韫囧懘銆忛幎?`miniBarExpanded` 瀵缚顢戦弨璺烘礀閹舵ê褰旈幀渚婄礉
    //   閼?HDS 閻?barLayoutMode 鏉╂ɑ妲?HORIZONTAL 閳?鎼存洘鐖崣妯诲灇閵嗗矂鏆遍弶顡歛b + 閸﹀棗鑸伴幘顓熸杹閸ｃ劊鈧秷绻栫粔宥夋晩鐠囶垳绮嶉崥鍫礉
    //   閸欘亣鍏橀崷銊┾偓鈧崙杞扮癌缁狙囥€夐棃銏℃閸愬秶绫傚锝勭濞嗏槄绱欓悽銊﹀煕閸欏秹顩惃鍕З閻㈣绱撶敮绋挎皑閺勵垵绻栨稊鍫熸降閻ㄥ嫸绱氶妴?
    //   閻滄澘婀稉宥呭晙閺€璁圭窗娴滃瞼楠囨い鐢告桨閻撗冪埗閺勫墽銇氭潻娆愭蒋閹绢厽鏂侀崳顭掔礄鐎瑰啫鎮撻弮鑸垫Ц閹绢厽鏂佹い闈涜埌閸欐娈戠挧椋庡仯閿涘鈧?
    return true;
  }

  /**
   * 閹剚璇炴潻铚傜稑閺壜ょ獩鎼存洟鍎撮梻纾嬬獩閵?
   *
   * 娴滃瞼楠囨い鐢告桨濞屸剝婀佸ù顔煎З妞ょ數顒烽敍灞惧娴犮儱褰ч棁鈧柆鍨磻缁崵绮虹€佃壈鍩呴弽?+ 鐏忔垿鍣洪悾娆戞閿?
   * 濮ｆ棃顩绘い鐢稿亝閺夆槄绱欓崷銊ョ俺閺嶅繐鍞撮敍澶嬫閺勭偓娲块棃鐘辩瑓閵?
   * @returns 鎼存洟鍎撮梻纾嬬獩閿涘澊p閿涘鈧?
   */
  private floatingMiniBarBottomMarginVp(): number {
    // 閳?鐠?`getNavigationBarBottomVpFromWindowUtil()`閿涙艾鐣犻妴宀€绱︾€?閳?閻滄澘鎮滅粣妤€褰涢柌?閳?閺堚偓閸氬簼绔村▎鈥炽偨閸?閳?
    //   閸氼垰濮╄箛顐ゅ弾閵嗗秹鈧劗楠囬崗婊冪俺閵嗗倽鈧椒鍞惍浣稿涧鐠囪崵绱︾€?+ 閸氼垰濮╄箛顐ゅ弾閿涘奔琚遍懓鍛村厴娑?0 閺冭绱欓柆鑳唨閸栬桨绔村▎锟犲厴濞屸€茬瑐閹躲儲鍨氶崝鐕傜礆
    //   鏉堢绐涙导姘垛偓鈧崠鏍ㄥ灇 12閿涘矁鍏岄崶濠呭垱閻偓鐏炲繐绠锋惔鏇樷偓浣稿竾閸︺劎閮寸紒鐔稿閸旀寧娼稉?閳ユ柡鈧?閻劍鍩涢惇瀣煂閻ㄥ嫨鈧苯绨抽柈銊︽尡閺€鎯ф珤闁挎瑤缍呴妴宥冣偓?
    // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆岃繖涓敭鐩橀伩璁╁お楂樹簡鍚с€嶏級锛氭湰鍑芥暟鐜板湪灏辨槸**鍐欒繘
    //   `barFloatingStyle.barBottomMargin` 鐨勯偅涓€涓暟** 鈥斺€?甯告€?= 绂婚〉鐩掑簳 12vp锛?
    //   閿洏鎬?= 鐢?HDS 鑷繁鎶婅兌鍥婇€佸埌閿洏涓婃部涔嬩笂 `FLOATING_MINI_BAR_KEYBOARD_GAP_VP` 澶勩€?
    //   鎺ㄥ瑙佹枃浠堕《閮ㄥ父閲忛偅娈点€屼笁銆佺幇鍦ㄧ殑璐︺€嶏細
    //       margin = K 鈭?I + GK        锛圞 閿洏楂樸€両 椤电洅搴曞唴缂┿€丟K 鐩爣绌虹櫧 10vp锛?
    //       鈬?鏉″簳 = Ypb 鈭?margin = (H 鈭?I) 鈭?(K 鈭?I + GK) = H 鈭?K 鈭?GK
    //       鈬?鏉″簳鍒伴敭鐩樹笂娌跨殑绌虹櫧**鎭掔瓑浜?GK = 10vp**
    // 鈿狅笍 鏈嚱鏁颁笂闈㈤偅娈垫棫娉ㄩ噴锛坄Math.max(12, systemInset + 8)`锛変綔搴燂細閭ｄ竴鐗堟妸"閬垮紑绯荤粺瀵艰埅鏉?
    //   鍙堢畻浜嗕竴閬嶏紝鑰?HDS 鐨?`barBottomMargin` 宸茬粡鏄?鏉″埌 tabs 搴曡竟"鐨勮窛绂诲彛寰?鈬?閲嶅鍙犲姞銆?
    const restMarginVp: number = FLOATING_MINI_BAR_BOTTOM_GAP_VP;
    const keyboardVp: number = this.keyboardBottomVp();
    if (keyboardVp <= 0) {
      return restMarginVp;
    }
    const keyboardMarginVp: number =
      keyboardVp - this.pageBottomInsetVp() + FLOATING_MINI_BAR_KEYBOARD_GAP_VP;
    return keyboardMarginVp > restMarginVp ? keyboardMarginVp : restMarginVp;
  }

  /**
   * 鏉烆垶鏁惄姗€鐝惔锔肩礄vp閿涘绱板▽鈩冩箒闁款喚娲忛弮?0閵?
   *
   * 閸烆垯绔撮惄鎴濇儔閻愮懓婀?`common/musicbasic` 閻?`WindowUtil`閿涘潉on('avoidAreaChange')` 閻?
   * `TYPE_KEYBOARD` 閸掑棙鏁崘?`WindowInfo.avoidKeyboard`閿涘绱遍張顒€鍤遍弫鏉垮涧閺勵垰褰х拠濠氭，闂堫澁绱?
   * 鐠囪崵娈戦弰?`@Trace` 鐎涙顔?閳?闁款喚娲忓鐟板毉/閺€鎯版崳娴兼俺鍤滈崝銊┾攳閸斻劌锛撶仦鍌炲櫢閺傛澘绔风仦鈧妴?
   */
  private keyboardBottomVp(): number {
    return getKeyboardBottomVpFromWindowUtil();
  }

  /**
   * 闁款喚娲忓鐟板毉閺冭绱濇禍宀€楠囨い鐢告桨閹剚璇炴潻铚傜稑閺?*閸愬秴绶氭稉濠冨М**閻ㄥ嫯绐涚粋浼欑礄vp閿涘绱遍弮鐘绘暛閻╂ɑ妞?*閹帊璐?0**閵?
   *
   * 閸欘亙缍旈悽銊ょ艾娴滃瞼楠囨い鐢告桨闁絾娼幃顒佽癁閺夆槄绱檣@link floatingMiniBar}閿涘绱版＃鏍€夐柇锝嗘蒋鏉╄渹缍橀弶鈥虫躬 HDS 濞搭喖濮╂惔鏇熺埉闁插被鈧?
   * 閻㈠崬鐣奸弬瑙勭埉娴ｆ捁绀嬬拹锝堫唨娴ｅ稄绱?*娑撳秷顩?*閹跺﹥婀伴崐鐓庢澓缂佹瑥鐣犻妴?
   *
   * 缁犳绱℃稉搴濊⒈娑擃亜鐖堕柌蹇斺偓搴濈疄鐠嬪喛绱濈憴?{@link FLOATING_MINI_BAR_KEYBOARD_GAP_VP} 婢剁繝绗傞柇锝嗩唽閵?
   * @returns 娑撳﹥濮捄婵堫瀲閿涘澊p閿涘绱遍弮鐘绘暛閻╂ɑ妞傛稉?0閿涘牊顒濋弮鎯扮殶閻劍鏌熺粻妤€绱￠柅鎰摟缁涘绨弨鐟板З閸撳秶娈戦崐纭风礆閵?
   */
  private floatingMiniBarKeyboardLiftVp(): number {
    // 鈽呪槄鈽?2026-10-18锛氳涔夋敼鎴愩€岄敭鐩樻€?*姣斿父鎬佸鎶簡澶氬皯**銆? `margin 鈭?G`锛? K 鈭?I + GK 鈭?G锛夈€?
    //   瀹夸富宸茬粡娌℃湁 `.offset` 浜嗭紝杩欎釜鏁板彧鐢ㄤ簬鏃ュ織涓庡洖褰掑垽鎹細
    //   路 鏃犻敭鐩樻椂蹇呴』**閫愬瓧涓?0**锛堝绾︿笉鍙橈紝鍥犱负 margin 鍥炶惤鍒?G锛夛紱
    //   路 閿洏鎬佸簲褰?鈮?`閿洏楂?鈭?椤电洅搴曞唴缂?+ 10 鈭?12`銆?
    const lift: number = this.floatingMiniBarBottomMarginVp() - FLOATING_MINI_BAR_BOTTOM_GAP_VP;
    return lift > 0 ? lift : 0;
  }

  /**
   * 娴滃瞼楠囨い鐢告桨閹剚璇炴潻铚傜稑閺?*鐎瑰じ瀵?*閻ㄥ嫮鏃遍崥鎴濅焊缁変紮绱檝p閿涘鈧?
   *
   * 閳跨媴绗?閺冪娀鏁惄妯绘韫囧懘銆?*闁劕鐡х粵澶夌艾** `homeTabBarBottomMarginVp()` 閳ユ柡鈧?鏉╂瑦妲搁崶鐐茬秺缁俱垻鍤庨敍?
   *    闁款喚娲忛柆鑳唨閸欘亜鍘戠拋绋挎躬"閻喓娈戝閫涚啊闁款喚娲?閺冭埖鏁奸崣妯跨箹閺夆剝鐖惃鍕秴缂冾喓鈧?
   * @returns 鐎瑰じ瀵?offset.y閿涘澊p閿涘鈧?
   */
  private floatingMiniBarHostOffsetYVp(): number {
    // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆屾€庝箞鏁翠釜搴曚笅鐨勭壒鏁堥兘琚姮涓婃潵浜嗐€嶏級锛?*瀹夸富涓嶅啀鏁翠綋浣嶇Щ锛屾湰鍑芥暟鎭掕繑鍥?0**銆?
    //   涓婇潰閭ｆ锛?鏃犻敭鐩樻椂蹇呴』閫愬瓧绛変簬 homeTabBarBottomMarginVp()"锛夎繛鍚屽畠鐨勫墠鎻愪竴璧蜂綔搴熴€?
    //   涓轰粈涔堬細`.offset` 浣嶇Щ鐨勬槸杩欎竴涓粍浠?*杩炲悓瀹冪敾鐨勫叏閮ㄤ笢瑗?* 鈥斺€?瀹夸富鏄暣鏉?HDS 娴姩搴曟爮锛?
    //   鑳跺泭銆乣systemMaterialEffect` 鏉愯川灞傘€佹爮搴曡壊鍏ㄥ湪鍏朵腑 鈬?涓€鎶氨鏄?鏁村潡搴曟爮娴┖"銆?
    //   鐜板湪閿洏閬胯鍙敼 `barFloatingStyle.barBottomMargin`锛圫DK `@hms.hds.hdsBaseComponent.d.ets:5311`
    //   銆宼he distance between tab bar and bottom of tabs銆嶏級鈬?鍙姩鑳跺泭**鍦ㄥ涓诲唴閮?*鐨勪綅缃紝
    //   瀹夸富鐩掍笌瀹冨簳涓嬮偅浜涙暣灞傛晥鏋滃師鍦颁笉鍔ㄣ€?
    //   杩斿洖 0 鑰屼笉鏄垹鍑芥暟锛氭棩蹇楅噷 `hostOffset=0` 灏辨槸"娌℃湁鏁翠綋浣嶇Щ"鐨勫垽鎹紝鍚屾椂闃插洖褰?鈥斺€?
    //   **涓嶈**鎶?{@link floatingMiniBarKeyboardLiftVp} 鍐嶆帴鍥?`.offset`銆?
    return 0;
  }

  /**
   * 鎼存洟鍎存い鐢殿劮閿?*閸欘亜澧挎稉銈勯嚋** 閳ユ柡鈧?閹恒劏宕?/ 閹存垹娈戦妴?
   *
   * 娑撹桨绮堟稊鍫熸Ц鏉╂瑤琚辨稉顏庣礄閻劍鍩?2026-10-11 閺勫海鈥樼憰浣圭湴"鎼存洘鐖崣顏勫⒖娑撱倓閲?Tab"閿涘苯褰熸稉鈧稉顏嗘暠閹存垳婊戦懛顏勭箒閸掋倖鏌囬敍澶涚窗
   *   - 閵嗗本甯归懡鎰┾偓宥嗘Ц閸愬懎顔愭稉濠氭桨閿涘牓顩绘い鍨腹閼芥劖绁﹂敍澶涚礉娑旂喐妲搁崗銊ユ簚閹碘偓閺?閸樺顩绘い?閸斻劋缍旈惃鍕儰閻愮櫢绱濋崚鐘冲竴鐎瑰啫绨查悽銊ユ皑濞屸€茬啊閸忋儱褰涢敍?
   *   - 閵嗗本鍨滈惃鍕┾偓宥嗘Ц閸欏倽鈧啫浼愮粙?lxmusic-harmony 閻ㄥ嫬浠涘▔鏇窗鐎瑰啳鍤滃鍙樼瘍**娴犲骸娲撴稉顏堛€夌粵鎾呯礄閹恒劏宕?濮濆苯宕?閹存垹娈?鐠佸墽鐤嗛敍?
   *     閺€鑸靛灇娴滃棔绗佹稉顏庣礄閹恒劏宕?閸氼兛鍔?閹存垹娈戦敍?*閿涘瞼鎮婇悽閬嶁偓鎰摟閸氬本鐎?閳ユ柡鈧?濮濆苯宕熸稉搴ゎ啎缂冾喚娈?*閸愬懎顔愰柈鑺ユ儔鏉╂稐绨￠妴灞惧灉閻ㄥ嫨鈧秹銆?*
   *     閿涘牆鎻╅幑宄板弳閸?+ 濮濆苯宕熼崡?+ 鐠佸墽鐤嗛崡鈽呯礆閿涘苯鍟€閻ｆ瑧娼冮柇锝勮⒈娑擃亪銆夌粵鎯ф皑閺?閸氬奔绔存禒鏈电皑娑撱倓閲滈崗銉ュ經"閵?
   *     閹存垳婊戝▽鈩冩箒閵嗗苯鎯夋稊锔衡偓宥忕礉閹碘偓娴犮儲顒滄總鑺ユЦ**娑撱倓閲?*閵?
   *
   * 鐞氼偄鍨归幒澶屾畱娑撱倓閲滄い鐢殿劮閿涘矁鍏橀崝娑㈠厴閺堝鏌婇崗銉ュ經閿涘牅绔撮弶锟犲厴濞屸€叉丢閿涘绱?
   *   - 閵嗗矁顔曠純顔衡偓宥佸晪閵嗗本鍨滈惃鍕┾偓宥夈€夐柇锝呯炊**閸忋儱褰涢崡?*閻ㄥ嫨鈧矁顔曠純顔衡偓宥堫攽 閳?`SettingPage` 娴滃瞼楠囨い?
   *     閿?*鐏忚鲸妲搁幋鎴滄粦閸樼喐娼甸柇锝勯嚋婢堆嗩啎缂冾噣銆夐張顑跨秼**閿涙碍鎮崇槐銏☆攱 + 閸忣厾绮嶇拋鍓х枂妞?+ 楠炲啿褰寸拹锕€褰?楠炲啿褰撮棅鍏呯/娑撳娴囩粻锛勬倞閿?
   *      妞ゆ湹绗傞柇锝呯炊閵嗗瞼娅ヨぐ鏇㈢叾娑旀劑鈧秴宕卞鍙夋儔閸掕埇鈧本鍨滈惃鍕┾偓宥夈€夋い鍫曞劥閿涘矁顫?`LoginMusicCard.ets`閿?
   *      閻愮绻橀崢鑽ゆ畱鐠囷附鍎忔禒宥嗘Ц閸氬奔绔存稉?`SettingsDetailPage`閿涘绱?
   *   - 閵嗗本鐡曢崡鏇樷偓宥佸晪閵嗗本鍨滈惃鍕┾偓宥夈€夐柇锝呯炊**濮濆苯宕熼崡?*閿涙艾宕遍崘鍛纯閹恒儱鍨灞藉礋閿涘牏鍋ｆ潻娑滎嚊閹?/ 闂€鎸庡瘻闁插秴鎳￠崥宓氬嘲鍨归梽銈忕礆閵?
   *     閸斻劋缍旈崠鎭掆偓灞炬煀瀵ょ儤鐡曢崡鏇樷偓宥忕礄鐏忓崬婀村鐟扮湴閿涘鈧降鈧本鐡曢崡鏇烆嚤閸忋儯鈧秳绗岄崡鈥炽仈閵嗗苯鍙忛柈銊ｂ偓宥佸晪 `MinePlaylistPage`
   *     娴滃瞼楠囨い纰夌礄閽栧嫬锛撻敍灞捐閺屾挾娈戞禒宥嗘Ц `PlaylistsPage` 閺佹挳銆夐敍姘笓鎼?/ 鐎电厧鍤?/ 閺€鐟扮殱闂?/ 缂冩垹绮剁€电厧鍙嗛柈钘夋躬閿涘鈧?
   * 閳跨媴绗?閹碘偓閺堝绨╃痪褔銆夐柈鑺ュ腹**婢瑰啿鐪伴崗鍙橀煩閺?* `pageIndexInfos`閿涘潉MinePage` 閼奉亜鐢惃鍕亝娑擃亜鍞寸仦?Navigation
   *    瀹告彃婀?2026-10-11 缁楊剙宕勬禍宀冪枂閸掔娀娅庨敍宀€鎮婇悽杈潌 `MinePage` 閺傚洣娆㈡径杈剧礆閵?
   */
  @Builder
  private HomeTabsPages() {
    TabContent() {
      Column() {
        RecommendPage({
          shellProvidesFloatingMiniBar: deviceInfo.distributionOSApiVersion >= 60100,
          floatingBarExtraBottomReserveVp: this.twoRowExtraBottomVp(),
          scrollTopCommand: this.tabScrollTopCommands[0]
        })
          .layoutWeight(1)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .tabBar(this.TabBarItem(0, $r('app.string.tab_home'), $r('sys.symbol.house_fill')))

    // 閳?閻劍鍩?2026-10-15閿涙哎鈧ab 閻ㄥ嫭甯归懡鎰嫲閸ョ偛鎼锋稉顓㈡？閸旂姳閲?*閻滄澘婀亸鍗炴儔**閿涘奔绗傛稉瀣拨閸斻劌鍨忛幑銏＄摃閺囧眰鈧倶鈧?
    //   娑撯偓鐏炲繋绔存＃鏍ㄧ摃閵嗕胶鐝崥?Swiper 閹广垺鐡曢敍娑欐弓閻ц缍嶇挧鏉跨秼閸撳秴閽╅崣鐗堫渷閸楁洏鈧胶娅ヨぐ鏇¤泲鐠囥儱閽╅崣鐗堢槨閺冦儲甯归懡?
    //   閿涘牅琚遍弶锟犫偓姘朵壕闁棄婀?`NowPlayingFeedPage` 闁插矉绱濈憴浣筋嚉閺傚洣娆㈡径杈剧礆閵?
    //   閸ョ偓鐖?`sys.symbol.music_note_circle_fill` 娑撳骸褰熸径鏍︾瑏閺嬫艾鎮撴稉?fill 缁紮绱欏鎻掓躬閺堫剚婧€
    //   `sysResource.js` 閻?symbol 鐞涖劑鍣烽弽绋跨杽鐎涙ê婀敍澶堚偓?
    TabContent() {
      Column() {
        NowPlayingFeedPage({
          // 鎼存洟鍎寸拋鈺€缍呮稉搴濈瑐闂堫潿鈧本甯归懡鎰┾偓宥夈€夐崥灞肩閸掋倖宓侀敍鍦欴S 濞搭喖濮╅懗璺烘抄鎼存洘鐖?6.1.1(24)/60100 鐠ч攱澧犵€涙ê婀敍澶涚窗
          // 56 = 閼宠泛娉姗堢礉+16 = `barBottomMargin` 閻ㄥ嫬鐖剁憴鍕偓绗衡偓鍌氱暊閸旂姴婀?*濠婃垵濮╅崡锛勫閼奉亜绻?*闊偂绗傞敍?
          // 鏉╂瑦鐗卞В蹇庣鐏炲繘鍏橀懗鑺ヮ劀婵傚€熺堪瀵偓鎼存洘鐖敍鍫ｎ潌 `NowPlayingFeedPage.FEED_DEFAULT_BOTTOM_RESERVE_VP`閿涘鈧?
          bottomReserveVp: deviceInfo.distributionOSApiVersion >= 60100 ? 56 + 16 : 56,
          scrollTopCommand: this.tabScrollTopCommands[1],
          // 閳藉應妲?2026-10-15 閻劍鍩涢敍姘モ偓灞惧灉閸氼垰濮╂惔鏃傛暏鏉╁洣绔存导姘皑娴兼俺鍤滈崝銊ョ磻婵鎸遍弨鎾呯礉**閼奉亜濮╁鈧慨瀣尡閺€鍓ф畱闁槒绶惔鏃囶嚉閺勵垱鍨滈幍鎾崇磻
          //    闁絼閲滈悳鏉挎躬鐏忓崬鎯夐惃鍕€夐棃銏㈡畱閺冭泛鈧?*閵嗗秲鈧倹鐗撮崶鐘虫Ц `HdsTabs` 閻?`TabContent` 鐎涙劙銆夐棃?*閸氼垰濮╅弮璺烘皑閹稿倽娴?*
          //    閳?妞ょ敻娼伴柌宀€娈?`applyRows()` 娑撯偓閸掔増鏆熼幑顔兼皑鐠ч攱鎸辨禍鍡礄閻劍鍩涙潻妯烘躬妫ｆ牠銆夐敍澶堚偓?
          //    閳?娑撳褰?*閺堫剟銆夐崷銊ョ俺閺嶅繘鍣烽惃鍕瑓閺?*閿涘牊妲告稉顏勭埗闁插骏绱氶敍宀勩€夐棃銏ｅ殰瀹歌精绻?`TabSwitchState` 閸?閻滄澘婀崷銊ょ瑝閸︺劌鐫嗛獮鏇氱瑐"
          //      閿涘潉@Monitor('tabState.tabIndex')`閿涘绱濋崣顏呮箒閸︺劌澧犻崣鐗堝鐠ч攱鎸遍妴?
          //    閳跨媴绗?**娑撳秷顩﹂弨瑙勫灇"婢瑰啿鐪版导?`isActive: this.tabState.tabIndex === 閳ヮ泦"**閿涙rkUI V2 閺?鐠囩粯澧犵拋銏ゆ"閿?
          //      閸掑洭銆夌粵鐐闁插秶绮惃鍕Ц鐠囪绨?`tabIndex` 閻ㄥ嫰鍋呴崙鐘遍嚋 `TabBarItem` 閼哄倻鍋ｉ敍灞炬拱妞や絻绻栨稉?`@Param`
          //      **娑撳秳绻氱拠浣筋潶闁插秵鏌婂Ч鍌氣偓?* 閳?`isActive` 娴兼矮绔撮惄鏉戜粻閸︺劌鍨甸崐纭风礄闂堟瑩绮径杈ㄦ櫏閿涘鈧?
          //    閳跨媴绗?閸欏倹鏆熼崥?*娑撳秷鍏橀崣?`tabIndex`**閿涙瓪CustomComponent` 閼奉亜绻侀張澶夌娑擃亜鎮撻崥宥嗘煙濞?
          //      閿涘牓鈧氨鏁ょ仦鐐粹偓?`tabIndex(index)`閿涘绱濋懛顏勭暰娑斿绮嶆禒鍫曞櫡閸氬苯鎮曟导?**缂傛牞鐦ф径杈Е**閿涘牊婀伴張鍝勭杽濞村绱?
          //      `Property 'tabIndex' 閳?is not assignable to the same property in base type 'CustomComponent'`閿涘鈧?
          barTabIndex: NOW_PLAYING_TAB_INDEX
        })
          .layoutWeight(1)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(1, $r('app.string.tab_now_playing'), $r('sys.symbol.music_round_triangle_fill')))

    // 閳?閻劍鍩?2026-10-12閿涙艾绨抽弽蹇庤厬闂傛潙濮炴稉鈧い鐐光偓灞芥礀閸濆秲鈧稄绱欓張鍫濆閸氼剚鐡曢幎銉ユ啞閿?
    TabContent() {
      Column() {
        EchoReviewPage({ scrollTopCommand: this.tabScrollTopCommands[2] })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(2, $r('app.string.tab_echo'), $r('sys.symbol.waveform')))

    TabContent() {
      Column() {
        MinePage({ scrollTopCommand: this.tabScrollTopCommands[3] })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(3, $r('app.string.tab_cafe_listen'), $r('sys.symbol.person_crop_circle_fill_1')))
  }

  /** Root UI: {@link HdsNavigation} with tabs and optional playback cover. */
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      HdsNavigation(this.pageIndexInfos) {
        if (deviceInfo.distributionOSApiVersion >= 60100) {
          HdsTabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
            this.HomeTabsPages()
          }
          .barMode(BarMode.Fixed)
          .barHeight(56)
          .zIndex(1)
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .vertical(false)
          .scrollable(true)
          .barFloatingStyle({
            // 閳跨媴绗?娑撳秷顩︽导?barWidth閵?
            // musicfreeOH 閻ㄥ嫭璇為崝銊ョ俺閺嶅繐褰ч張?barBottomMargin / systemMaterialEffect /
            // adaptToHandedness / miniBar 閸ユ稐閲滈柨?閳ユ柡鈧?濞屸剝婀?barWidth閵嗗倹鍨滄禒顒€甯弶銉ょ炊閻ㄥ嫪绗佸?
            // 閿涘澃mallWidth = 缁愭褰涚€?閳?96 / 284 / 328閿涘绱扮拋鈺傛殻閺夆€崇俺閺嶅繑妲戦弰鍓х崕娴滃骸鐫嗛獮鏇礉
            // 閵嗗奔绗傛稉瀣╄⒈閹烘帇鈧秵妞傛稉銈勬櫠鐏忚京鏆€閸戝搫绶㈡径褏鈹栭梾娆欑礄閻劍鍩涢崣宥夘洯閻ㄥ嫬姘ㄩ弰顖濈箹娑擃亷绱氶妴?
            barBottomMargin: this.homeTabBarBottomMarginVp(),
            // 閳?鏉╂瑦娼弰?*鐎规ɑ鏌熼惇鐔风杽閸忓鍔?*閿涙dsTabs 閻ㄥ嫭璇為崝銊ョ俺閺嶅骏绱檅arOverlap + !vertical +
            //   barPosition(End) 娑撳娼禒璺烘倱閺冭埖寮х搾绛圭礆+ `systemMaterialEffect`閵?
            //   濡楋絼缍呮稉搴㈢垼妫版ɑ鐖崗杈╂暏 ambientTitleMaterial()閿涘奔绗夌憰浣稿晙閸︺劍婀版径鍕敶閼辨柧绔存總妞剧瑏閻╊喓鈧?
              // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆屽彧鏈夋妸鍏夋劅绛夌骇鏀规垚鎴戜滑鐨勫氨琛屻€嶏級锛?
              //   杞戒綋浠嶆槸 HDS锛堝３灞?`HdsTabs`锛夛紝浣?*鏉愯川妗ｅ悆鏈簲鐢ㄧ殑杞欢璁剧疆**锛?
              //   `buildTitleMaterial(ambientState.level)`锛? 璺熼殢绯荤粺 / 1 SMOOTH / 2 GENTLE / 3 EXQUISITE锛夛紝
              //   涓庢爣棰樻爮鍚屼竴浠芥槧灏勩€?
              // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆屽彧鏈夋妸鍏夋劅绛夌骇鏀规垚鎴戜滑鐨勫氨琛屻€嶏級锛氳浇浣撲粛鏄?HDS锛堝３灞?`HdsTabs`锛夛紝
              //   鏉愯川妗ｅ悆鏈簲鐢ㄨ缃?鈥斺€?鍗虫棦鏈夌殑 `ambientTitleMaterial()`锛? `buildTitleMaterial` 鐨勫悓涓€浠芥槧灏勶細
              //   0 璺熼殢绯荤粺 / 1 SMOOTH / 2 GENTLE / 3 EXQUISITE锛夛紝涓庢爣棰樻爮鍚屼竴鍙ｅ緞銆?
              systemMaterialEffect: this.ambientTitleMaterial(),
            // 閺呯儤鍔呴幓鈥承敍姘崇闂呭繑褰欓幐浣瑰鐠嬪啯鏆ｅù顔煎З閺夆€充箯閸欏啿浜哥純?
            adaptToHandedness: true,
            miniBar: {
              // 鈿狅笍 涓嬮潰銆?026-10-20锛堢涓夎疆锛夈€嶉偅娈碉紙"妲藉彧鐣?0 楂樺害鍗犱綅"锛?*宸蹭綔搴?*锛?
              //   绗叓杞敳鏂圭粨璁烘槸涓€绾ч〉涓庝簩绾ч〉涓ゅ缁撴瀯 鈬?妲介噷鐜板湪鐢荤殑灏辨槸**鎾斁鍣ㄦ湰浣?*锛?
              //   `enableMiniBarBackground` / `enableMiniBarClip` 涔熷洖鍒颁笂娓哥己鐪侊紙涓嶅啓锛夈€?
              //   淇鐞嗙敱瑙佹湰鍧楀唴 2026-10-21 鐨勪笁娈垫敞閲娿€?
              // 鈽呪槄鈽呪槄 2026-10-20锛堢涓夎疆锛夛細`miniBar` 妲?*鍙暀 0 楂樺害鍗犱綅**锛屼笉鍐嶇敾鎾斁鍣ㄣ€?
              //
              //  涓轰粈涔堬紙涓€鍙ヨ瘽锛夛細妲介噷鐨勮儗鏉挎槸**澹冲眰 HdsTabs 鑷繁鐨勫瓙鏍?*锛屾垜浠?`.scale` 鍘嬩笉鍒板畠
              //  鈬?浣忓湪杩欓噷鐨勮糠浣犳潯姘歌繙鎷夸笉鍒?鏉愯川鑳屾澘璺熺潃寮逛竴涓?銆傝€?鍏夋劅"鍙堝彧鑳芥潵鑷?
              //  `HdsTabsFloatingStyle.systemMaterialEffect`锛坄CommonMethod` 涓婃病鏈夎繖涓睘鎬э級
              //  鈬?鍞竴鍑鸿矾鏄?鑳跺泭鑷繁灏辨槸涓€涓?HdsTabs銆佷笖杩欎釜 HdsTabs 鍦ㄦ垜浠殑瀛愭爲閲?
              //  = 鏃犵晫鐨?`MaterialCapsule`锛坄wujie.pa:60082-60279`锛夈€?
              //  鈬?鎾斁鍣ㄦ湰浣撴惉鍒?{@link homeMiniCapsule}锛堝３灞?Stack锛寊Index 19锛夛紝
              //    涓庝簩绾ч〉閭ｆ潯**鍚屼竴涓粍浠躲€佸悓涓€濂楀昂瀵稿彛寰?*銆?
              //
              //  鈿狅笍 `enableMiniBarBackground` 蹇呴』 **false**锛氭Ы閲屽凡缁忔病鏈夋挱鏀惧櫒锛?
              //    寮€鐫€瀹冧細鐣欎笅涓€鏋?*绌鸿兌鍥婅儗鏉?*锛堟湰鏂囦欢椤堕儴绗?鈶?鏉″氨鏄杩欎釜锛夈€?
              //     杩欎篃椤烘墜瑙ｅ喅浜?鍙岃儗鏉?鏉愯川琚礂鐧?鈥斺€旀Ы閲屼竴涓儚绱犻兘涓嶇敾銆?
              //  鈿狅笍 `enableMiniBarClip` 蹇呴』 **false**锛氭垜浠殑鑳跺泭鏈?slack 澶栨孩锛?
              //    鐪熸満涓€鏃﹀紑鍚鍓氨浼氭妸鏉愯川杈圭紭鍒囨帀涓€鍦堛€?
              //  鈿狅笍 妲介珮鐢辫繖鍧?0 楂樺害鐨?Column 鍐冲畾锛圚DS 鎸夊唴瀹归噺楂樺害锛夆噿 鍙墿椤电涓€鎺掞紝
              //    涓庛€岀幇鍦ㄥ氨鍦ㄥ惉銆嶉偅涓€椤?*閫愬瓧鍚屼竴涓啓娉?*锛堥偅鏉¤矾寰勭湡鏈哄凡楠岃繃锛夈€?
              miniBarBuilder: (): void => {
                // 鈽呪槄鈽?2026-10-21锛堢鍏疆锛岀敳鏂圭粨璁猴級锛?*涓€绾ч〉鐨勬挱鏀炬潯灏变綇鍦ㄨ繖涓Ы閲?* 鈥斺€?
                //   涓庝笂娓?`MainPage` 鍚屾瀯锛坄wujie.pa:157082-157228`锛歚__Common__().visibility().gesture(...)`
                //   鐩存帴鍖?`MiniPlayer`锛屾病鏈夎兌鍥婂鍣ㄣ€佹病鏈?slack锛夈€?
                //   鈬?杩欓噷缁欑殑灏辨槸 `MiniPlayer` 鏈綋锛坽@link miniBar}锛夛紝涓婁竴杞偅鍧?0 楂?56 楂?
                //   閫忔槑鍗犱綅锛坄miniBarSlotPlaceholder`锛変笌澹冲眰 `Stack` 閲岀殑鑷缓鑳跺泭瀹夸富
                //   锛坄homeMiniCapsule` 鈫?`MiniBarMaterialCapsule`锛?*閮藉凡鍒犻櫎**銆?
                //   妲介珮鐢?HDS 鎸?*鍐呭閲?*缁欙細鍐呭琚拤鍦?`FLOATING_MINI_BAR_HEIGHT_VP`(56)
                //   = 涓婃父 `MINI_H`锛屼笌椤电鑳跺泭绛夐珮锛堝畼鏂广€岃糠浣犳爮鈥︹€﹁窡椤电鏍忛珮搴︾浉绛変笖姘村钩瀵归綈銆嶏級銆?
                this.miniBar();
              },
              // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆岀幇鍦ㄥ氨鍚〉闈㈠簲璇ラ殣钘忓皬鎾斁鏉★紝鐜板湪鍙殣钘忎簡涓婇潰鐨勫厓绱犮€嶏級锛?
              //   `miniBar()` 鍦ㄩ偅涓€椤?/ 浜岀骇椤靛湪鏍堜笂鏃剁粰鐨勬槸 **0 楂樺害鍗犱綅 Column**锛堜笉鐢绘挱鏀惧櫒锛夛紝
              //   浣?`enableMiniBarBackground` 缂虹渷 **true**锛圫DK `:5169` 鍘熸枃 "follow tab bar"锛?
              //   鈬?HDS 鐓ф牱缁欒繖涓€鏍肩敾鑳屾澘 鈬?椤电鑳跺泭涓婃柟澶氬嚭涓€鏋?*绌鸿兌鍥?*銆?
              //   璇箟涓?`miniBar()` 閲岄偅鏉?if 閫愬瓧鍚屼箟锛?*鍙湁鐪熺敾鎾斁鍣ㄦ椂鎵嶈 HDS 鐢昏儗鏉?*銆?
              // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆岃繕鏄笉浼氶殣钘忋€嶏級锛氳儗鏉夸篃瑕佽窡鍐呭涓€璧疯蛋銆?
              //   `.visibility(Hidden)` 鍙棌**鍐呭**锛孒DS 閭ｅ眰鑳屾澘浠嶆寜杩欎竴鏍肩殑 56 楂樺害鐢?
              //   鈬?鍔ㄧ敾鏈熺湅鐫€"鏉¤繕鍦?銆備笂娓?`morphMiniBar()`锛坄wujie.pa:148626-148645`锛夋槸**鏁翠唤鎹㈤厤缃?*锛?
              //   `searchOpen 鈬?Empty` / `!miniHidden 鈬?NoBg` / 鍚﹀垯 `base`锛屼笁浠藉尯鍒氨鍦?`enableMiniBarBackground`銆?
              //   鈬?杩欓噷璁╄儗鏉垮紑鍏冲悆涓庡唴瀹瑰彲瑙佹€?*鍚屼竴缁勬潯浠?*锛坄miniOut` 鏄笂娓搁偅鏉￠€愬抚涓嶅彉閲忥級銆?
              // 鈽呪槄鈽?2026-10-18锛堜笂娓?`morphMiniBar()` 鍙鎬?= `NoBg`锛宍wujie.pa:148626-148648` /
              //   `:144057-144068`锛夛細HDS **涓嶇敾**鑳屾澘锛岀敱鍐呭鑷粯 鈬?鎸ゅ帇鑳藉帇鍒拌儗鏉匡紝鏁存潯鎵嶄細"寮?銆?
              //   鈿狅笍 涓庝竴绾ч〉 `showSelfDrawnBackplate: true` 蹇呴』鎴愬锛氬彧寮€涓€杈?= 涓ゅ眰鎴栧叏閫忔槑銆?
              enableMiniBarBackground: false,
              // 鈽呪槄鈽?2026-10-20锛堢浜旇疆锛夛細**缁?HDS 鎶ヤ笂"杩蜂綘鏍忓崰澶氬"**锛坄HdsTabsMiniBar.miniBarWidth`
              //   锛歋DK `@hms.hds.hdsBaseComponent.d.ets:5150`锛屼笁妗ｄ笌 `HdsBarWidthRangeOptions` 鍚屽舰锛夈€?
              //   鍗曞眰鎬佸繀椤绘姤锛屽惁鍒?HDS 鎸ら〉绛俱€佽鍑烘潵鐨勯暱鏉′綅瀹藉害涓庢垜浠嚜宸辩敾鐨勮兌鍥婂涓嶄笂銆?
              //   鈿狅笍 杩?*涓嶆槸** `barFloatingStyle.barWidth`锛堥偅涓鏁存潯搴曟爮瀹斤紝鏈枃浠舵槑浠や笉浼狅級銆?
              // 鈽呪槄鈽?2026-10-21锛堢鍏疆锛夛細`miniBarWidth` **涓嶅啀鎶?* 鈥斺€?涓婃父 `MainPage` 鐨?
              //   `floatStyleOf()` 閲屾病鏈夎繖涓敭锛氶椤甸偅鏉＄殑瀹藉害鐢?HDS 鐨?`miniBar` 妲芥寜鍐呭閲?
              //   "璺熼〉绛炬爮鍚屽"缁欙紙`涓婃父-杩蜂綘鏉′笁褰㈡€佷笌棣栭〉浜岀骇椤靛樊寮?md` 搂3.1锛夈€?
              //   涓婁竴杞姤瀹冩槸鍥犱负鎾斁鍣ㄦ惉鍑轰簡妲斤紙瑕佽嚜宸辩畻闀挎潯浣嶏級锛岀幇鍦ㄦ挱鏀惧櫒鍥炲埌妲介噷锛岃繖涓暟澶氫綑銆?
              // 鈽呪槄鈽?2026-10-21锛堢鍏疆锛夛細`enableMiniBarBackground` / `enableMiniBarClip`
              //   **涓€寰嬩笉鍐?*锛堟寜涓婃父缂虹渷锛夈€俙enableMiniBarBackground` 鐨勭己鐪佹槸 `true`
              //   锛坄@hms.hds.hdsBaseComponent.d.ets:5169`锛屾敞閲婂師鏂囥€孍nables mini bar background
              //   follow tab bar銆嶏級鈬?杩蜂綘鏉￠偅鏍肩殑**鑳屾澘 + 娌夋蹈鍏夋劅鐢?HDS 鐢?*锛屽悆鐨勬槸鏈眰
              //   `barFloatingStyle.systemMaterialEffect`锛圫DK `:5357`锛孉PI23/24 鍞竴鍚堟硶杞戒綋涔嬩竴锛夈€?
              //   鈬?銆屽厜鎰熴€嶇殑鎻愪緵鏂?= **澹冲眰 HdsTabs**锛涖€屽脊涓€涓嬨€嶇殑钀界偣 = 妲藉唴瀹癸紙`MiniPlayer` 鏍癸紝
              //     瑙?{@link miniBar} 鐨?`contentOwnsSquash: true`锛夈€備笂娓搁椤甸偅鏉℃鏄繖涓ゆ潯鐨勭粍鍚堛€?
              //   鈿狅笍 濡傚疄璁板綍锛堢湡鏈哄緟楠岋級锛欻DS 鐢荤殑鑳屾澘鍦?*澹冲眰瀛愭爲**閲屻€佸帇涓嶅埌 鈬?鍏抽棴鎾斁鍣ㄦ椂
              //     `morphSquashY` 鍙帇鍐呭銆佷笉鍘嬭儗鏉裤€傜敳鏂瑰凡鏄庣‘"涓€绾ч〉涓庝簩绾ч〉鏄袱濂楃粨鏋勩€佷笉鑳界粺涓€"
              //     鈬?杩欎竴鏉?*鎺ュ彈**锛涜嫢鐪熸満涓?miniBar 娌℃湁鏉愯川/娌℃湁鑳屾澘"锛岃 `BLOCKED`锛?
              //     **涓嶈**鍦?`HomeMiniBarPlayer` 閲屽啀閫犺嚜缁樻潗璐紙閭ｄ細鎶婂畼鏂规潗璐ㄦ礂鐧斤級銆?
              //   鈿狅笍 绗簩涓緟楠岀偣锛氥€岀幇鍦ㄥ氨鍦ㄥ惉銆嶉偅涓€椤?/ 浜岀骇椤靛湪鏍堜笂鏃讹紝`miniBar` 妲介噷缁欑殑鏄?
              //     0 楂?`Column`锛堣 {@link miniBar} 鐨?if/else锛夈€傜己鐪佸紑鐫€鐨?miniBar 鑳屾澘浼氫笉浼氬湪
              //     椤电鑳跺泭涓婃柟鐣欎竴鏋?*绌鸿兌鍥?*锛屽彧鑳界湡鏈虹湅銆傝嫢鍑虹幇浜嗭紝**鍞竴鏀规硶**鏄湪杩欓噷琛?
              //     `enableMiniBarBackground: this.miniBarRendersPlayer(),`锛堜竴琛岋紝璇箟涓?
              //     {@link miniBar} 閲岄偅鏉?if 閫愬瓧鍚屼箟锛夆€斺€旈櫎姝や箣澶栦笉瑕佸幓鍔ㄦ潗璐?鑳屾澘鏉ユ簮銆?
              // 閳?閸欏苯鐪版惔鏇熺埉閻ㄥ嫬鍙ч柨顕嗙窗`barLayoutMode = VERTICAL` 閹靛秵濡告潻铚傜稑閺夆€茬瑢妞ょ數顒烽幒鎺撳灇娑撳﹣绗呮稉銈嗗笓閵?
              //   鐠囥儱鐡у▓鍨Ц @since 6.1.1(24)閿涘本澧嶆禒銉ヤ紣缁?targetSdkVersion 韫囧懘銆?閳?24
              //   閿涘牊婀版い鍦窗瀹歌尙鏁?6.1.0(23) 閹绘劕鍩?6.1.1(24)閿涘畱ompatibleSdkVersion 娣囨繃瀵?23閿?
              //     鐠佹儳顦憰鍡欐磰娑撳秴褰夐敍澶堚偓鍌欑秵闁板秴褰傜悰宀€澧楁稉濠佺炊 undefined閵?
              //   閳跨媴绗嶉妴宀€骞囬崷銊ユ皑閸氼兙鈧秹銆夐悽?`barLayoutModeForHds()` 瀵搫鍩?HORIZONTAL閿涘牐顫嗙€瑰啫鎷?
              //     `NOW_PLAYING_TAB_INDEX` 閻ㄥ嫭鏁為柌濠忕礆閿涙岸鍋呮稉鈧い鍏哥瑝鐠佸憡婀佹潻铚傜稑閺夛繝鍋呮稉鈧幒鎺嬧偓?
              barLayoutMode: this.barLayoutModeForHds(),
              // 閸欐甯剁仦鐐粹偓褝绱伴幎妯哄綌閹?= 缁愬嫯鍏岄崶濠忕礉閻愮懓鍤崥搴ｆ暠 onBarStyleChange 闁繐鍤崘宥呮礀閻?
              // 閳跨媴绗?閸楁洘甯撻敍鍦歄RIZONTAL閿涘鍘?`EXPAND` 閺?*瀹歌尙鐓￠惃鍕晩鐠囶垳绮嶉崥?*閿涘牆绨抽弽蹇庣窗閸欐ɑ鍨?
              //   閵嗗矂鏆遍弶?Tab + 閸﹀棗鑸伴幘顓熸杹閸ｃ劊鈧稄绱濈憴?`onMiniBarStyleChangeFull` 閻ㄥ嫭鏁為柌濠忕礆閳?
              //   閸︺劊鈧瞼骞囬崷銊ユ皑閸氼兙鈧秹銆夋稉鈧獮鑸靛Ω閺嶅嘲绱￠崢瀣礀 `COLLAPSE`閵?
              //
              // 閳藉應妲勯埥?2026-10-16閿?*閺傝顢?A閿涙俺绯犳担鐘虫蒋閺€纭呭殰缂佹鍎楅弶?*閿涘奔鎱ㄩ悽銊﹀煕鐎圭偞绁?
              //   閵嗗苯鍙ч梻顓熸尡閺€鎯ф珤閸欘亝婀侀崘鍛啇娴兼艾鑴婇敍?*閹绢厽鏂侀弶陇鍎楅弲顖欑瑝瀵?*閵嗗稄绱氶敍?
              //   `enableMiniBarBackground` 閺?HDS 缂?*鏉╄渹缍橀弶锟犲亝娑撯偓閸?*閻ㄥ嫯鍎楅弶鍨磻閸?
              //   閿涘牓銆夌粵鎹愬厡閸ュ﹪鍋呴崸妤勫剹閺夋寧妲?*閸欙缚绔撮崸?*閿涘奔绗夐崣妤€鐣犺ぐ鍗炴惙閿涘鈧?
              //   缂?`false` 閳?HDS 娑撳秴鍟€缂佹瑨绯犳担鐘虫蒋閻㈡槒鍎楅弶?閳?閼冲本婢橀弨鍦暠
              //   `HomeMiniBarPlayer.MiniBarBackplate()` 閼奉亞绮敍灞肩艾閺勵垰鐣犳稉搴″敶鐎圭懓婀?*閸氬奔绔村Λ闈涚摍閺?*闁插矉绱?
              //   閼冲€熺閻偓 `morphSquashY` 娑撯偓鐠у嘲甯?娑撯偓鐠у嘲鑴婇妴?
              //   閳跨媴绗?娑?`HomeMiniBarPlayer` 闁插矂鍋呮稉鈧仦?*韫囧懘銆忛幋鎰嚠**閿涙艾褰ч崗鍏呯瑝閻?閳?鏉╄渹缍橀弶鈥崇俺娑撳鈹栨稉鈧崸妞尖偓?
              // 鈽呪槄鈽?2026-10-18锛堢敤鎴凤細銆屼綘鏄笉鏄繕璁扮粰涓婚〉鐨勮繖涓皬鎾斁鏉″姞涓婂厜鎰熶簡銆嶏級鈥斺€斿垽瀹氫笌缁撹锛?
              //   **缁х画鑷粯锛坒alse锛? 鎶婅儗鏉挎崲鎴?璺熶富棰樿蛋"鐨?sheet 闈?*锛岃€屼笉鏄氦缁?HDS 鐢汇€?
              //   鍒ゆ嵁锛坄MiniBarBackplate` 鍒板簳涓鸿皝鑰屽瓨鍦級锛氬畠鐨勬敞閲婁笌鍞竴璋冪敤鐐归兘鍐欐槑"鍙负璁╄儗鏉胯窡鐫€
              //   `morphSquashY` 涓€璧峰帇/涓€璧峰脊"锛坄HomeMiniBarPlayer.ets` 鐨?`MiniBarBackplate()` 鏂囨。
              //   + `build()` 閲岄偅涓寕鐫€ `.scale({ y: morphSquashY })` 鐨?`Stack`锛夛紱HDS 鐢荤殑鑳屾澘鍦?
              //   `miniBar` 妲?*涔嬩笅**銆佷笉鍦ㄦ垜浠殑瀛愭爲閲?鈬?涓€鏃﹀紑 `enableMiniBarBackground: true`锛?
              //   鍏抽棴鎾斁鍣ㄦ椂"鏁存潯鎾斁鏉′竴璧峰脊"灏变細閫€鍥?鍙湁鍐呭寮广€佽儗鏉夸笉鍔?锛埪?6.3 鐢ㄦ埛鎶ヨ繃鐨勫師鐥咃級銆?
              //   鑰?鍏夋劅"骞朵笉缂哄湪瀹夸富涓婏細杩欎竴灞?HdsTabs 鐨?`barFloatingStyle.systemMaterialEffect`
              //   鏈潵灏辨槸 `ambientTitleMaterial()`锛堣鏈枃浠?HomeTabsPages 閭ｅ锛夛紝鏄?SDK 鍏佽鐨勫敮涓€杞戒綋
              //   锛坄@hms.hds.hdsBaseComponent.d.ets:5357`锛夈€傛墍浠ヨ繖涓€杞?*鍙?*鎶婅嚜缁樿儗鏉跨殑棰滆壊鎹㈡垚
              //   浜?鏆楅兘鏈夊彉浣撱€?0% 涓嶉€忔槑搴︾殑 `floating_mini_bar_sheet_background` 鈥斺€?鏃ラ棿涓嶅啀鏄粦鍧楋紝
              //   澶滈棿浠嶆槸娣辫壊锛岃鎰熶笌浜岀骇椤甸偅鏉★紙HDS 鏉愯川锛夊悓涓€濂楄壊绯汇€?
              //   鈿狅笍 鑻ョ敤鎴锋洿鎯宠"HDS 浜叉墜鐢荤殑鏉愯川鑳屾澘"鑰屼笉鍦ㄤ箮鎸ゅ帇寮硅烦锛屽敮涓€鏀规硶鏄妸杩欓噷鏀?`true`
              //   + `HomeMiniBarPlayer({ showSelfDrawnBackplate: false })`锛堜袱鏉″繀椤绘垚瀵癸紝鍚﹀垯鏉愯川琚挋鐗堟礂鐧斤級銆?
              //   鉁?**2026-10-18 鏅氬凡鐓ф鎵ц**锛堜笂闈?缁х画鑷粯"閭ｆ浣滃簾锛屽彧鐣欎綔鏉ラ緳鍘昏剦锛夈€?
              // 鈽呪槄鈽?2026-10-18锛堟櫄锛?*鎺ㄧ炕涓婇潰 2026-10-16 / 10-18 涓ゆ鐨勭粨璁?*锛夛細
              //   鐢ㄦ埛锛氥€屼綘鏄笉鏄繕璁扮粰涓婚〉鐨勮繖涓皬鎾斁鏉″姞涓婂厜鎰熶簡锛?*鍥犱负浜岀骇椤甸潰姝ｅ父**锛夈€嶃€?
              //   渚濇嵁锛堟湰鏈?SDK 閫愯鏍歌繃锛宍D:\command-line-tools\sdk\default\hms\ets\api\@hms.hds.hdsBaseComponent.d.ets`锛夛細
              //     `HdsTabsMiniBar.enableMiniBarBackground`锛?5169锛夋敞閲婂師鏂?
              //     銆孍nables mini bar background **follow tab bar**銆嶏紝`@default true`銆?
              //   鈬?瀹冧竴涓?true锛?*杩蜂綘鏉￠偅涓€鏍肩殑鑳屾澘灏辩敱 HDS 鐢?*锛岃€屾湰椤?`barFloatingStyle` 涓婂凡缁忔湁
              //     `systemMaterialEffect: this.ambientTitleMaterial()`锛?5357锛孲DK 鍏佽鐨勪袱涓悎娉曡浇浣撲箣涓€锛?
              //     鈬?miniBar 鎷垮埌鐨勬槸**鍚屼竴浠藉畼鏂规潗璐?* 鈥斺€?杩欐鏄簩绾ч〉閭ｆ潯姝ｅ父鐨?鍏夋劅"鐨勬潵婧愩€?
              //   浠ｄ环锛堝繀椤昏璐︼級锛欻DS 鐢荤殑鑳屾澘鍦?`miniBar` 妲介噷銆?*涓嶅湪鎴戜滑鐨勫瓙鏍戦噷**
              //     鈬?鍏抽棴鎾斁鍣ㄦ椂 `morphSquashY` 鍙帇鍒?*鍐呭**锛岃儗鏉夸笉鍐嶈窡鐫€涓€璧峰帇/寮癸紙搂86.3 閭ｄ釜鍘熺梾鍥炴潵涓€鍗婏級銆?
              //     鉁?鏈疆宸叉寜"涓よ€呴兘瑕?鏀跺彛锛歚miniBar` 妲界暀绌恒€佹挱鏀惧櫒鎼埌 {@link homeMiniCapsule}
              //        锛堟垜浠瓙鏍戦噷鐨?{@link MiniBarMaterialCapsule}锛夆噿 鍏夋劅涓庡脊璺冲悓鏃舵垚绔嬨€?
              //        涓婇潰杩欎竴鏁存锛?026-10-16 / 10-18 鐨勫弽澶嶏級鍙綔涓烘潵榫欏幓鑴変繚鐣欍€?
              // 鉀?涓婃父涓変唤 miniBar 閰嶇疆閲?*娌℃湁 `miniBarStyle` 杩欎釜閿?*锛坄wujie.pa:143286` / `:144057` / `:144074`锛夛細
              //   鏍峰紡鍙粡 `HdsTabsController.applyMiniBarStyle()` 杩涳紙`wujie.pa:145779` / `:147178`锛夈€?
              //   鈬?杩欓噷涓嶅０鏄庡紡璁撅紝鍒濇€佷氦缁?HDS + 涓婇潰閭ｆ潯 `applyMiniBarStyle`銆?
              onBarStyleChange: (miniBarStyle: HdsBarStyle, _tabStyle: HdsBarStyle,
                _miniWidth: number, _tabWidth: number, mode: HdsTabsBarChangeMode): void => {
                this.onMiniBarStyleChangeFull(miniBarStyle, mode);
              }
            }
          })
          .onChange((index: number) => {
            if (index !== this.tabState.tabIndex) {
              this.tabState.tabIndex = index;
              // 閸掑洤鍩岄弬浼淬€夌粵鎾呯窗闁鑵戦幀浣歌剨娑撯偓娑撳绱欓悙鐟板毊娑撳孩绮﹂崝銊ュ瀼閹广垽鍏樻导姘宠泲鏉╂瑩鍣烽敍?
              this.playTabBounce(index);
              // 閳?鏉╄渹缍橀弶鈩冩▔闂呮劘鐦栭弬顓ㄧ礄`hdc shell hilog | grep RzdMiniBarHide`閿涘绱?
              //   閸掑洤鍩岄妴宀€骞囬崷銊ユ皑閸氼兙鈧秴绨查幍鎾冲毉 `hidden=true barLayout=HORIZONTAL style=COLLAPSE`閿?
              //   閸掑洤娲栭弶銉ョ安閹垫挸鍤?`hidden=false`閵嗗倸褰ч懗鐣屾箙閺冦儱绻旈敍灞炬￥鐠佹儳顦宀冪槈閵?
              Logger.info(RzdShellLogTag,
                `RzdMiniBarHide tab=${index} hidden=${index === NOW_PLAYING_TAB_INDEX} ` +
                  `barLayout=${this.barLayoutModeForHds()} style=${this.miniBarStyleForHds()} ` +
                  `navDepth=${this.navDepth}`);
            }
          })
          // 閻愬綊銆夌粵鎾呯窗閻愬湱娈戦弰?*瑜版挸澧?*妞ょ數顒烽弮璺烘礀閸掍即銆婇柈顭掔礄閸掑洭銆夌粵鍙ユ唉缂?onChange閿?
          .onTabBarClick((index: number): void => {
            this.onTabBarClicked(index);
          })
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
        } else {
          HdsTabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
            this.HomeTabsPages()
          }
          .barMode(BarMode.Fixed)
          .barHeight(56)
          .zIndex(1)
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .vertical(false)
          .scrollable(true)
          .padding({ bottom: WindowUtil.getInstance().getStartupNavigationBarBottomVp() })
          .onChange((index: number) => {
            if (index !== this.tabState.tabIndex) {
              this.tabState.tabIndex = index;
              this.playTabBounce(index);
            }
          })
          .onTabBarClick((index: number): void => {
            this.onTabBarClicked(index);
          })
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
        }
      }
      .mode(NavigationMode.Stack)
      .customNavContentTransition((from: NavContentInfo, _to: NavContentInfo,
        operation: NavigationOperation): NavigationAnimatedTransition | undefined => {
        return getPlaylistTransitionState().navigationReturn(this.getUIContext(), from, operation);
      })
      .backgroundColor($r('app.color.home_page_background'))
      .hideTitleBar(true)
      .hideToolBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 閹绢厽鏂佹い?*娑撳秴鍟€閻?`bindContentCover`**閿涙氨娲块幒銉ょ稊娑撶儤婀?Stack 閻ㄥ嫭璇炵仦鍌涘瘯鏉炴枻绱欑憴浣风瑓闂堛垽鍋呭▓鍨暈闁插绱氶妴?
      // 濡剝鈧線鍋呴弶陇鐭剧挧鎷岀箖瀵板牅绠欓敍宀€绮ㄧ拋鐑樻Ц鐎瑰啫鎷?娴犲氦绯犳担鐘虫蒋闂€鍨毉閺?閻ㄥ嫬鑸伴崣妯荤壌閺堫兛绗夐崗鐓庮啇閿?
      //   璺?`ModalTransition.DEFAULT` 閼奉亜鐢?娴犲骸绨抽柈銊﹀腹娑撳﹥娼?閻ㄥ嫪缍呯粔浼欑礉娴兼艾鎷拌ぐ銏犲綁閻ㄥ嫪缍呯粔璇插綌閸旂媴绱?
      //   璺?`ModalTransition.NONE` 閾忕晫鍔у▽鈩冩箒娴ｅ秶些閿涘奔绲惧Ο鈩冣偓浣割問娑撶粯妲告稉宥夆偓蹇旀閻ㄥ嫪绔寸仦鍌︾礉
      //     閹跺﹪顩绘い闈涙嫲鏉╄渹缍橀弶鈥冲弿閻╂牔缍囬敍鍫濊埌閸欐顩﹂柅蹇撳毉閺夈儳娈戝锝嗘Ц鐎瑰啩婊戦敍澶涚礉娴滃孩妲搁崣顏勫⒖"姒涙垵绨?+ 娑撳鏌熺粚铏规"閵?
      .onNavBarStateChange((isVisible: boolean): void => {
        // 濮ｅ繑顐肩€佃壈鍩呴弽蹇撳讲鐟欎焦鈧冨綁閸栨牠鍏橀崚閿嬫煀閺嶅牊绻佹惔锔肩礄閹恒劌鍙?瀵懓鍤禍宀€楠囨い鐢告桨闁垝绱扮憴锕€褰傞敍?
        this.syncNavDepth();
      })

      // 閳?閹绢厽鏂佹い纰夌窗**娑撳秶鏁ゅΟ鈩冣偓渚婄礉閻╁瓨甯撮幐鍌氭躬婢瑰啿鐪伴惃?Stack 闁?*閿涘牆顕弽鍥ㄦ￥閻ｅ矉绱伴幘顓熸杹妞ゅ吀绗屾＃鏍€夐崷銊ユ倱娑撯偓娑?
      //   鐟欏棗娴橀弽鎴﹀櫡閿涙备C 婢瑰啿鐪伴張顒佹降鐏忚鲸妲告潻娆庣疄閹稿倻娈戦敍澶堚偓?
      //
      // 娑撹桨绮堟稊鍫熷Ω `bindContentCover` 閹广垺甯€閿涘牅绗佹稉顏嗘暏閹村嘲鐤勫ù?bug 閻ㄥ嫭鐗撮崶鐘诲厴閸︺劏绻栭柌宀嬬礆閿?
      //   1. 濡剝鈧胶娈戠€瑰じ瀵岄弰?*娑撳秹鈧繑妲?*閻ㄥ嫪绔寸仦鍌︾礉鐎瑰啰娲婃担蹇庣啊妫ｆ牠銆夐崪宀冪碃娴ｇ姵娼?閳ユ柡鈧?閼板苯鑸伴崣妯兼畱鐟欏倹鍔呴棃鐘垫畱濮濓絾妲?
      //      "鏉╄渹缍橀弶鈥虫躬闁絻鈧礁鐣犻幈銏″弮閸欐ê銇?閿涙俺绯犳担鐘虫蒋鐞氼偆娲婃担蹇撴倵閿涘苯澧挎稉瀣畱鐏忚鲸妲?娑撯偓閸ф绮﹂懗灞炬珯 + 娑撳鏌熺粚铏规"
      //      閿涘牊膩閹浇鍤滃杈╂畱鎼存洝澹婇敍澶涚礉鐠虹喐妫ら悾宀€娈?閹绢厽鏂侀弶锟犫偓鎰瑤閸欐ê銇?鐎瑰苯鍙忔稉宥嗘Ц娑撯偓閸ョ偘绨ㄩ敍?
      //   2. 瑜般垹褰夐弮鈺傛埂閸欘垵顫嬮惌鈺佽埌閸欘亝婀佹潻铚傜稑閺夆€崇殱闂堛垽鍋呮稊鍫濄亣閿涘本膩閹礁鍙炬担娆撳劥閸掑棙妲稿Ο鈩冣偓浣哥俺閼硅绱濇稉宥嗘Ц妫ｆ牠銆?
      //      閳ユ柡鈧?娴滃孩妲哥仦蹇撶娑撳﹥妲告稉鈧崸妤呯拨閵嗕椒绔撮崸妤冣敄閿?
      //   3. 閹靛濞嶉敍姘侀幀浣告躬 `isShowPlay=false` 閺冭埖鐗撮張顑跨瑝鐎涙ê婀敍鍫滅瑐閹峰澧﹀鈧箛鍛淬€忛崷銊ワ紦鐏炲偊绱氶敍?
      //      閼板苯鐣犵€涙ê婀弮璺哄嫉娴兼碍濡告竟鍐茬湴閻ㄥ嫭澧滈崝鍨弿閸氬啯甯€閿涘苯顕遍懛纾嬬閹靛鈧槒绶稉銈呫仈閸欐鍩楅妴?
      //   閹稿倸婀竟鍐茬湴 Stack 闁插苯姘ㄥ▽鈩冩箒鏉╂瑤绨洪梻顕€顣介敍姘瑓鐏炲倻娈戞＃鏍€?鏉╄渹缍橀弶陇绻曢崷銊ф暰閿涘苯鑸伴崣妯兼畱闁繑妲戦崠鍝勭厵
      //   闁繐鍤弶銉ф畱鐏忚鲸妲告＃鏍€?閳ユ柡鈧?"閹绢厽鏂侀弶锟犫偓鎰瑤閸欐ê銇囬妴渚€顤侀懝鏌モ偓鎰瑤閸欐ɑ鍨氶懗灞炬珯閵嗕焦鍙冮幈銏″珖鐏炴洖鍩岄弫鏉戠潌"閵?
      //
      // 缁崵绮烘潻鏂挎礀娑撳秴鍟€閻㈣鲸膩閹胶娈?`onWillDismiss` 閹凤缚绨￠敍灞炬暭閻㈣鲸婀版い鐢垫畱 `onBackPress` 閹凤讣绱欑憴浣规瀮娴犺埖婀亸鎾呯礆閵?
      //
      // 閳跨媴绗?`PLAYER_ROUTE_MODE = true` 閺冩儼绻栨稉鈧▓?*娑撳秵瑕嗛弻?*閿涙碍鎸遍弨楣冦€夐悽?NavDestination 鐠愮喕鐭?
      //    閿涘牐顫?pushPlayerRoute閿涘鈧倷琚遍弶陇鐭鹃柈鎴掔箽閻ｆ瑱绱濋崶鐐衡偓鈧崣顏堟付閺€閫涚瑐闂堛垽鍋呮稉顏勭埗闁插繈鈧?
      PlaylistTransitionOverlay()
        .zIndex(90)
        .hitTestBehavior(HitTestMode.Transparent)

      if (this.appState.isShowPlay && !PLAYER_ROUTE_MODE) {
        Column() {
          PlaybackPageCoverContent()
        }
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        // matchParent expands SIZE too; percent height only moved the overlay and left a bottom gap.
        // Expand ONLY the player overlay; do not relayout the retained Navigation window.
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        // 閻╂牔缍?HdsTabs閿涘牆鐣犻懛顏勭箒閺?zIndex(1)閿涘绗屾禍宀€楠囨い鐢告桨閻ㄥ嫭鍋撳ù顔跨碃娴ｇ姵娼?
        .zIndex(PLAYER_OVERLAY_Z_INDEX)
        .id('rzd_player_overlay_viewport')
        .onAreaChange((_oldArea: Area, area: Area): void => {
          Logger.info('RzdPlayerViewport', `overlay=${area.width}x${area.height} window=${this.viewportWidthVp}x${this.viewportHeightVp} top=${this.windowInfo.statusBarTopVp} bottom=${this.windowInfo.navigationBarBottomVp}`);
        })
      }

      // 閳?瑜般垹褰?*閸忓娈曠仦?*閿涘牆顕弽鍥у冀缂傛牞鐦ч柌?`MainPage` 娑撳﹪鍋呮稉澶夐嚋 lambda閿涙艾鐨濋棃銏犲帬闂?/ 閸忓啩淇婇幁顖氬帬闂?/
      //   閹垮秳缍旈崠鍝勫帬闂呭棴绱氶妴鍌氬冀缂傛牞鐦ч弰搴ｂ€橀敍姘帬闂呭棗鐪伴幐鍌氭躬 **MainPage**閿涘牆锛撶仦鍌︾礆閼板奔绗夐弰顖涙尡閺€楣冦€夐敍?
      //   閼板奔绗栭弰?閻㈣绔存稉顏勫閺?閵嗕椒绗夐弰顖滅舶閻喎鐤勭亸渚€娼伴崝?transform閵?
      //   鐎瑰啫绻€妞よ婀?*閹绢厽鏂佹い鍨癁鐏炲倷绠ｆ稉?*閿涙俺绯犳担鐘虫蒋閻喕闊╅崷銊﹁癁鐏炲倷绠ｆ稉瀣剁礉閼冲本娅欐稉鈧稉宥夆偓蹇旀鐏忚精顫﹂惄鏍ㄥ竴娴滃棴绱?
      //   閹碘偓娴?鐠ч鍋ｉ惇瀣崳閺夈儴绻曢弰顖炲亝閺壜ょ碃娴ｇ姵娼?闂堢姷娈戠亸杈ㄦЦ鏉╂瑤绔寸仦鍌氬閺堫兙鈧?
      //
      // 閳跨媴绗?濞撳弶鐓嬮梻銊ф暏 `morphSessionDriving()`閿?*閻喓娈戦崷銊︽尡**閿涘绱濇稉宥嗘Ц `morphContainerActive()`閿?
      //    閻愮懓鍤幍鎾崇磻娴兼艾鍘涙潻?ENTERING閵嗕礁鍟€闁插秷鐦張鈧径?12鑴?2ms閿涘牃澧?00ms閿涘鐡戠紒鍫㈠仯闁挎氨鍋ｇ亸杈╁崕閿?
      //    鏉╂瑦顔?閸嬪洤濮╅悽?闁插苯鑸伴崣妯哄従鐎圭偠绻曞▽鈥崇磻婵绱濇担?`morphP` 瀹歌尪顫﹂崢瀣煂 0 閳?
      //    `actionsOpacityAt(0) = 1` 閳?閸忓娈曠仦鍌氬弿娴滎喖婀撮幐鍌氭躬鐏炲繋绗傚?閳ユ柡鈧?
      //    閻劍鍩涚€圭偞绁撮惃?娑撳閲滈幐澶愭尦娑撯偓閻╁瓨绱撶粔?鐏忚鲸妲告潻娆庣濞堢偣鈧?
      // 锛?026-10-20 绗笁杞偅娈点€屼富椤甸偅鏉℃敼鐢辨湰灞傛覆鏌?{@link homeMiniCapsule()}銆?*宸蹭綔搴?* 鈥斺€?
      //   鐞嗙敱瑙佷笅闈?2026-10-21 閭ｆ潯銆傦級
      // 鈽呪槄鈽?2026-10-21锛堢鍏疆锛岀敳鏂瑰彛寰勶級锛氳繖閲?*涓嶅啀**娓叉煋 `homeMiniCapsule()`銆?
      //   涓€绾ч〉鐨勬挱鏀炬潯宸叉媶鍥炲３灞?`HdsTabs.barFloatingStyle.miniBar.miniBarBuilder`锛堣 {@link miniBar}锛?
      //   鈥斺€?涓庝笂娓?`MainPage` 鍚屾瀯锛氫竴绾ч〉 = `miniBar` 妲斤紙鏃犺兌鍥婂鍣ㄣ€佹棤 slack锛夛紱
      //   浜岀骇椤?= {@link MiniBarMaterialCapsule}锛堣嚜宸变竴涓?HdsTabs 娴姩鑳跺泭锛屾湰鏂囦欢 {@link floatingMiniBar}锛夈€?
      //   鈬?涓ゆ潯鎾斁鏉′粠姝ゆ槸"鍚屼竴涓唴瀹圭粍浠?+ 涓ゅ瀹夸富"锛屼笉鍐嶅叡鐢ㄥ悓涓€涓涓荤粍浠躲€?
      if ((this.expandState.morphSessionDriving() || this.expandState.hdsBarSuppressed) &&
        this.expandState.asideWinW > 0) {
        this.MorphMiniBarClone()
      }
      MorphMetaBridge()
        .zIndex(PLAYER_CLONE_Z_INDEX)
        .hitTestBehavior(HitTestMode.None)

      // 閳藉應妲?缁楊兛绗佹禒鑺ュ鐠?= **缂侇參顥ｇ亸渚€娼?*閿?026-10-15 娴犲孩鎸遍弨楣冦€夐幖顒佹降閻ㄥ嫰鍋呮稉鈧Λ鎺炵礆閵?
      //    鐎瑰啯婀侀懛顏勭箒閻ㄥ嫭妞傞梻瀵稿殠閿涘潉morphOverlayP`閿?60ms + 韫囶偄鍤幈銏℃暪閿涘绱濇稉搴″綗娑撱倓鍞ら崥灞界湴閿涘澓Index 110閿涘鈧?
      //    妞ゅ墎鍋?缂佸牏鍋ｉ柌蹇旂ゴ娑撳骸褰熸径鏍﹁⒈娴犺棄鎮撳┃鎰剁礄`reportMini` / `reportBig`閿涘绱濋幍鈧禒銉ょ瑏閼板懏妲告稉鈧挧鐤泲閻ㄥ嫨鈧?
      //    濞撳弶鐓嬮梻銊ュ晸閸?builder 闁插矉绱檂morphOverlayBridging()`閿涘鈧?
      if (this.expandState.morphOverlayBridging() || this.expandState.hdsBarSuppressed) {
        this.MorphCoverClone()
      }

      // 閳藉應妲勯埥?2026-10-17閿涘牏鍙庨幖顒佹￥閻?`MainPage` 閻?`If (shrink.visible && shrinkPixmap)`閿涘绱?
      //   閵嗗矂娼幍瀣◢閸忔娊妫撮妴宥夊亝娑撯偓濡帪绱版稉鈧鐘冲姬缁愭鎻╅悡褏缂夐崚鎷岀碃娴ｇ姵娼懗璺烘抄 + 濞ｂ€冲毉閵?
      //   閺€鎯ф躬**閺堚偓娑撳﹪娼?*閿涘澓Index 130閿涘绱扮€瑰啫姘ㄩ弰?濮濓絽婀☉鍫濄亼閻ㄥ嫰鍋呮稉鈧仦蹇旀尡閺€楣冦€?閵?
      this.ShrinkOverlayHost()

      // 閸忋劌鐪幃顒佽癁鏉╄渹缍橀幘顓熸杹閺夆槄绱伴崣顏勬躬娴滃瞼楠囨い鐢告桨濞撳弶鐓嬮敍鍫ヮ浕妞ょ敻鍋呮禒钘夋躬 HDS 濞搭喖濮╂惔鏇熺埉闁插矉绱氶妴?
      // 閺夆€叉濞撳弶鐓嬮懓灞肩瑝閺勵垰鐖舵す?+ visibility 閳ユ柡鈧?鐢悂鈹楅惃鍕殻鐏炲繘鈧繑妲戦懞鍌滃仯娴兼艾鎮嗛幒澶婄俺閺嶅繑澧滈崝瑁も偓?
      if (this.shouldShowFloatingMiniBar()) {
        this.floatingMiniBar()
      }

      // Persistent hidden LX source engine host (webview sandbox for user API scripts).
      LXSourceHost()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 瑜般垹褰夌€瑰じ瀵岄敍姝歡etRectangleById(MORPH_HOST_ID)` 闁插繒娈戠亸杈ㄦЦ鏉╂瑥鐪伴惃鍕閺屾挾鐓╄ぐ?
    .id(MORPH_HOST_ID)
    // 閳?娑撳﹥濯洪幍鎾崇磻閹绢厽鏂佹い纰夌礄鐠虹喐澧滈敍灞筋嚠閺嶅洦妫ら悾?ExpandAnimation.applyPullProgress閿涘鈧?
    //   韫囧懘銆忛幐鍌氭躬**婢瑰啿鐪?*閿涙碍鎸遍弨楣冦€夐崷?`isShowPlay` 娑?false 閺冩儼绻曞▽鈩冨瘯鏉炴枻绱濋弨鏈电瑝閸掔増澧滈幐鍥︾皑娴犺翰鈧?
    //   娑撳孩鎸遍弨楣冦€夐柌宀€娈戞稉瀣閺€鎯版崳閺傜懓鎮滈惄绋垮冀閿涘奔琚遍弶鈩冨閸斿じ绨版稉宥呭暱缁愪緤绱?
    //   楠炴湹绗栭崣顏呮箒"娴犲骸鐫嗛獮鏇氱瑓閸楀﹪鍎撮崚鍡氭崳閹?閹靛秵甯寸粻鈽呯礉娑擃參妫块崠鍝勭厵閻ㄥ嫪绗傚鎴犲弾閺冄傛唉缂佹瑥鍨悰?濮濆矁鐦濆姘З閵?
    .gesture(
      PanGesture(this.pullOpenOption)
        .onActionStart((event: GestureEvent): void => {
          this.onPullOpenStart(event.fingerList);
        })
        .onActionUpdate((event: GestureEvent): void => {
          this.onPullOpenUpdate(event.offsetY);
        })
        .onActionEnd((event: GestureEvent): void => {
          // 閳?闁喎瀹虫い閫涚瘍鐟曚椒绱舵潻娑樺箵閿涘牊绔婚崡?鎼傛稉鈧?1.2閵嗗矁绻樻惔?OR 闁喎瀹抽妴宥忕幢閸掋倖宓侀崷?
          //   `PlayerExpandState.pullOpenShouldCommit()` 闁插矉绱濋弬鐟版倻閻㈠彉缍呯粔璇插灲閵嗕礁銇囩亸蹇撳絿 abs閿?
          this.onPullOpenEnd(event.offsetY, event.velocityY);
        })
        .onActionCancel((): void => {
          this.onPullOpenCancel();
        })
    )
    // 缁愭褰涚亸鍝勵嚟閸欐ê瀵查敍鍫熷閸欑姴鐫嶅鈧?/ PC 濞搭喚鐛ラ幏鏍ㄥ閿涘妞傞崚閿嬫煀閹剚璇為弶锛勭暬鐎圭晫鏁ら惃鍕潒閸欙絽顔旀惔?
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      // 閳跨媴绗?鐟欏棗褰涚€逛粙鐝敍鍫熷閸斿潡妲囬崐鑲╂暏閿涘绮涢悞璺哄涧閻?`syncViewportWidthVp` 娴?windowSize 閸欐牗鏆ｇ粣妤€褰涘鍕剁礉
      //    鏉╂瑩鍣?*娑撳秷顩?*閸愬秵瀵滈張顒€顔愰崳銊ф畱妤傛ê瀹崇憰鍡欐磰鐎瑰喛绱伴柇锝嗘Ц"閸愬懎顔愰崠娲彯鎼?閿涘奔绗?`globalY`閿涘牏鐛ラ崣锝呮綏閺嶅浄绱?
      //    娑撳秵妲告稉鈧稉顏勫經瀵板嫸绱濆ǎ椋庢暏娴兼俺顔€"娴犲簼绗呴崡濠傜潌鐠ч攱澧?閻ㄥ嫬鍨界€规艾浜哥粔璇插殤閸?vp閵?
      this.syncViewportWidthVp();
      // 閳?瑜般垹褰夐崙鐘辩秿閻?*鐏忓搫顕?*閸欘亝婀侀崬顖欑閻ㄥ嫭娼堟繛浣规降濠ф劧绱?*缁愭褰涚亸鍝勵嚟**閵?
      //   閳跨媴绗?閸楀啩绔鹃崚顐ｅ瑏閺堫剙顔愰崳顭掔礄閹存牔鎹㈡担鏇炲棘娑撳骸鑸伴崣妯兼畱鐏炲偊绱氶惃鍕杽濞村鐝惔锕€缍?闁剧儤寮ч惄顔界垼"閿涙岸鍋呯粔宥堝殰閸ｎ剙鍑＄紒?
      //      闊晞绻冩稉澶嬵偧閿涘牆绨抽柈銊у繁娑撯偓閸?/ 娑撯偓閸ф绻庡锝嗘煙瑜般垼鍎楅弲?/ 姒涙垵绨崇仦鏇氱瑝瀵偓閿涘鈧柡鈧?鐞氼偄鑸伴崣妯兼畱闁絽鐪伴敍?
      //      鐎瑰啳鍤滃杈╂畱鐏忓搫顕亸杈ㄦЦ鐟佷礁澹€缁愭褰涢敍灞芥澓閸ョ偛骞撶粵澶夌艾鐠佲晝娲伴弽鍥嫹閻偓閼奉亜绻侀惃鍕厬闂傚瓨鈧浇绐囬妴?
      //      閺堫剙顔愰崳銊ュ涧閸?*闂堟瑦顒涢幀?*閹靛秶鐡戞禍搴ｇ崶閸欙絽銇囩亸蹇ョ礉瑜般垹褰夐張鐔兼？楠炴湹绗夌粵澶夌艾閿涘本澧嶆禒銉ㄧ箾鐎瑰啩绡冩稉宥堝厴娣嚶扳偓?
      this.expandState.reportWindow(this.viewportWidthVp, this.viewportHeightVp,
        this.windowInfo.statusBarTopVp, this.windowInfo.navigationBarBottomVp);
      this.expandState.updateChromeTier(this.viewportWidthVp);
    })
  }

  /**
   * 缁崵绮烘潻鏂挎礀閿涘牐绻戦崶鐐烘暛 / 鏉╂柨娲栭幍瀣◢閿涘绱伴幘顓熸杹妞ら潧绱戦惈鈧亸鍗炲帥閹绢厽鏁圭挧宄板З閻紮绱濋獮?*濞戝牐鍨傞幒?*鏉╂瑦顐兼潻鏂挎礀閵?
   *
   * 閳跨媴绗?娴犮儱澧犳潻娆庣濮濄儲妲稿Ο鈩冣偓浣烘畱 `onWillDismiss` 楠炶尙娈戦敍娑欐尡閺€楣冦€夐弨瑙勫灇婢瑰啿鐪?Stack 闁插瞼娈戦弲顕€鈧碍璇炵仦鍌欑閸氬函绱?
   *    韫囧懘銆忛崷銊ㄧ箹闁插本瀚ら敍灞芥儊閸掓瑨绻戦崶鐐扮窗閻╁瓨甯撮柅鈧崙鍝勭安閻㈩煉绱欓幋鏍偓鍛Ω閹绢厽鏂佹い闈涚俺娑撳娈戞禍宀€楠囨い鐢告桨瀵甯€閿涘鈧?
   * @returns true = 瀹稿弶绉风拹鐧哥礉娑撳秴鍟€鐠т即绮拋銈堢箲閸ョ偤鈧槒绶?
   */
  onBackPress(): boolean {
    if (!this.appState.isShowPlay) {
      return false;
    }
    // 閻喐顒滈惃鍕暪鐠у嘲濮╅悽鑽ゆ暠閹绢厽鏂佹い鍨尡閿涘牆鐣犻惄鎴濇儔 collapseVersion閿涘绱濋幘顓炵暚閼奉亜绻侀幎?isShowPlay 缂?false
    this.expandState.requestCollapse();
    return true;
  }

  /**
   * 閸氬本顒炵€佃壈鍩呴弽鍫熺箒鎼达负鈧?
   *
   * 閺€鎯ф躬 `onNavBarStateChange` 閻ㄥ嫪绗呮稉鈧敮褝绱扮拠銉ユ礀鐠嬪啳袝閸欐垶妞傞弽鍫濆讲閼冲€熺箷濞屸€崇暚閹存劖甯归崗銉礉
   * 缁斿鍩㈢拠?`size()` 娴兼碍瀣侀崚鐗堟＋閸婄》绱濈€佃壈鍤ф潻铚傜稑閺夆€茬瑝閸戣櫣骞?/ 娑撳秵绉锋径渚库偓?
   *
   * 閳跨媴绗?**娑撳秷顩﹂崠?animateTo**閿涙瓪animateTo` 娴兼碍濡?閼哄倻鍋ｉ崚姘愁潶閸掓稑缂?鏉╂瑤娆㈡禍瀣╃瘍娑撯偓鐠х柉藟闂?閳ユ柡鈧?
   * 婢瑰啿鐪伴幃顒佽癁鏉╄渹缍橀弶鈩冩Ц閺夆€叉濞撳弶鐓嬮崙鐑樻降閻ㄥ嫭鏌婇懞鍌滃仯閿涘苯瀵樻潻娑樺З閻㈣姘ㄩ幋鎰啊濞ｂ€冲弳閿涘瞼鏁ら幋閿嬫绾喕绗夌憰浣碘偓?
   * 鏉╄渹缍橀弶锛勬畱閺勯箖娈ｈ箛鍛淬€忔稉鈧敮褍鍞撮惄瀛樺复閸掑洦宕查敍娑㈡付鐟曚礁濮╅弫鍫㈡畱閸欘亝婀?`miniBarExpanded` 閻ㄥ嫭鏁圭挧鏋偓?
   */
  private syncNavDepth(): void {
    setTimeout((): void => {
      // 閳?`navDepth` 閻ㄥ嫬褰涘鍕Ц"**娴滃瞼楠囨い鐢告桨**濞ｅ崬瀹?閿?*娑撳秴鎯堥幘顓熸杹妞?*閿?
      //   瑜般垹褰夐崗銉ュ經閺€瑙勫灇 NavDestination 娑斿鎮楅幘顓熸杹妞や絻鍤滃鍗炲窗娑撯偓閺嶅吋鐖ゅǎ鎲嬬礉婵″倹鐏夐幎濠傜暊缁犳绻橀弶銉礉
      //   閿?閿涘鎸遍弨楣冦€夋惔鏇氱瑓娴兼艾鍤熺粚鍝勫晪閸戣桨绔撮弶鈩冨亾濞搭喛绯犳担鐘虫蒋閿涘潉shouldShowFloatingMiniBar`閿涘绱?
      //   閿?閿涘绻橀幘顓熸杹妞ゅ吀绱伴幎濠勬暏閹村嘲鐫嶅鈧惃鍕碃娴ｇ姾鍏岄崶濠傚繁鐞涘本鏁归崶鐐村閸欑姵鈧緤绱欐稉瀣桨闁絾顔岄敍澶涚礉
      //   娑撱倖娼柈鎴掔窗閻潙娼栬ぐ銏犲綁閻ㄥ嫯鎹ｉ悙鐟板殤娴ｆ洏鈧倹澧嶆禒銉х埠娑撯偓閸︺劏绻栭柌灞惧⒏閹哄鈧?
      const playerIdx: number = this.playerRouteIndex();
      const depth: number = this.pageIndexInfos.size() - (playerIdx >= 0 ? 1 : 0);
      if (depth === this.navDepth) {
        return;
      }
      const previousDepth: number = this.navDepth;
      this.navDepth = depth;
      if (depth > 0) {
        // 閳?鏉╂稐绨╃痪褔銆夐棃?*娑撳秴鍟€**閹跺﹨绯犳担鐘虫蒋瀵缚顢戦弨璺烘礀閹舵ê褰旈幀渚婄礄閺冄勬煙濡楀牞绱氶妴?
        //   閺冄勬煙濡楀牞绱癭miniBarExpanded = false` 閼?`hdsBarLayoutMode` 娣囨繃瀵?HORIZONTAL
        //   閳?HDS 鏉╂稑鍙嗛妴宀勬毐閺夘摎ab + 閸﹀棗鑸伴幘顓熸杹閸ｃ劊鈧秷绻栫粔宥夋晩鐠囶垳绮嶉崥鍫礉鎼存洘鐖崝銊ф暰閻娼冪亸鍙樼瑝鐎电櫢绱?
        //   鏉╂ê绶遍崷銊┾偓鈧崙杞扮癌缁狙囥€夐棃銏℃閸愬秶绫傚锝呮礀閵嗗矂鏆遍弶鈩冩尡閺€鎯ф珤 + 閸﹀棗鑸癟ab閵嗗秲鈧?
        //   閻滄澘婀穱婵囧瘮 (barLayoutMode, miniBarExpanded) 鏉╂瑤绔寸€佃婀伴弶銉ユ皑娑撯偓閼峰娈戦悩鑸碘偓浣风瑝閸旑煉绱?
        //     HORIZONTAL + EXPAND 娴犲秵妲搁妴宀勬毐閹绢厽鏂侀崳?+ 閸﹀摗ab閵嗗稄绱盫ERTICAL + COLLAPSE 娴犲秵妲搁崣灞界湴閵?
        //   娴滃瞼楠囨い鐢告桨娑撳﹦娈戦幘顓熸杹閸ｃ劎鏁辨竟鍐茬湴閹剚璇為弶陇绀嬬拹锝嗘▔缁€鐚寸礄鐟?shouldShowFloatingMiniBar閿涘鈧?
        Logger.info(RzdShellLogTag,
          `enter secondary depth=${depth} keep mode=${this.appState.hdsBarLayoutMode} expanded=${this.appState.miniBarExpanded}`);
      } else if (previousDepth > 0) {
        // 閸戣桨绨╃痪褔銆夐棃顫窗閻樿埖鈧礁鍙忕粙瀣梾鐞氼偅鏁兼潻鍥风礉鏉╂瑩鍣烽崣顏囩 HDS 闁插秵鏌婄€靛綊缍堟稉鈧▎鈽呯礄楠炲倻鐡戦敍灞肩瑝娴溠呮晸"缁剧姵顒?鐠哄啿褰夐敍?
        this.restoringHomeBar = true;
        this.tabsController.applyMiniBarStyle(this.appState.miniBarExpanded ?
          HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE);
        Logger.info(RzdShellLogTag,
          `leave secondary reassert style=${this.appState.miniBarExpanded ? 'EXPAND' : 'COLLAPSE'}`);
        setTimeout((): void => { this.restoringHomeBar = false; }, 400);
      }
    }, 0);
  }
}
