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
  BarLayoutModes,
  BreakpointType,
  getWindowInfoState,
  getNavigationBarBottomVpFromWindowUtil,
  getKeyboardBottomVpFromWindowUtil,
  getPlaylistTransitionState,
  HomeSourceState,
  ImmersiveType,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  Logger,
  MORPH_HOST_ID,
  MorphStage,
  PlaybackIntentState,
  PlayerExpandState,
  MorphDrive,
  MorphMetaBridge,
  // 鈽?2026-10-17锛堢収鎼棤鐣?`MainPage.__shrink`锛夛細闈炴墜鍔垮叧闂殑蹇収鏀剁缉娴眰鐘舵€?
  MorphShrinkState,
  RouterUrlConstants,
  SdkApiUtil,
  SdkConstants,
  ShowMiniLyricState,
  StyleConstants,
  TabSwitchState,
  ThemeState,
  WindowInfo,
  WindowUtil
} from 'musicbasic';
import { dispatchShellPlaybackIntent, LXSourceHost, PlaybackPage, PlaybackPageCoverContent, PlayerViewModel,
  prewarmCurrentSongMesh } from 'player';
import { RecommendPage } from 'recommendation';
import { EchoReviewPage } from 'recommendation';
// 銆岀幇鍦ㄥ氨鍚€嶏細搴曟爮绗?2 涓〉绛撅紙鎺ㄨ崘 / **鐜板湪灏卞惉** / 鍥炲搷 / 鎴戠殑锛夈€?
import { NowPlayingFeedPage } from 'recommendation';
import { HomeMiniBarPlayer, HomeMiniBarPlayerAside, PlaylistTransitionOverlay } from 'playlist';
import { MinePage } from 'setting';
// 鏂版ā鍧楋細鏈湴闊充箰锛堝鍏ヨ澶囬煶棰戝埌娌欑锛変笌娲涢洩鍚屾瀹㈡埛绔€?
// 鈿狅笍 hvigor 瀵?HAR 鏄?*鎸夊紩鐢ㄧ紪璇?*鐨勶細娌℃湁浠讳綍浠ｇ爜 import 瀹冧滑鏃讹紝
//    鍗充娇宸茬櫥璁拌繘 build-profile.json5锛岃繖涓や釜妯″潡涔?*涓嶄細琚紪璇?*锛堟瀯寤虹収鏍风豢锛夈€?
//    鎵€浠ヨ繖閲岀殑 import 鍚屾椂鎵挎媴"鍚姩鍒濆鍖?鍜?鎶婂畠鎷夎繘鏋勫缓鍥?涓や釜浣滅敤銆?
import { localMusic } from 'localmusic';
import type { MatchSongInfo } from 'localmusic';
import { syncManager } from 'sync';
// 姝屾洸璇勮锛堝唴缃钩鍙拌瘎璁猴級锛氬惎鍔ㄦ椂鎶娿€屾湰鍦伴煶涔?-> 骞冲彴韬唤銆嶇殑瑙ｆ瀽娉ㄥ唽杩?comment锛?
// 杩欐牱璇勮闈㈡澘鏃㈣兘鐪嬪湪绾挎瓕鐨勮瘎璁猴紝涔熻兘鐪嬫湰鍦版瓕锛堝尮閰嶈繃鐨勯偅浜涳級鐨勮瘎璁恒€?
import { setCommentTargetResolver } from 'comment';
import type { CommentSongRef } from 'comment';
import { HdsBarLayoutMode, HdsBarStyle, HdsTabs } from '@hms.hds.hdsBaseComponent';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

/**
 * 浜岀骇椤甸潰鎮诞杩蜂綘鏉＄殑鍥哄畾楂樺害锛坴p锛夈€?
 *
 * **涓庨椤靛簳鏍忛噷閭ｆ潯涓€鑷达紙56锛?*锛氬皝闈?44锛坄HomeMiniBarAlbumCover.coverSideLengthVp()` 甯歌鎬侊級
 * + 涓婁笅鍚?6vp 鍐呰竟璺濄€傜敤鎴疯姹備簩绾ч〉闈篃鐢ㄣ€屼富椤甸偅涓珮涓€鐐圭殑銆嶏紝涓嶅啀鐢?30vp 灏侀潰鐨勭煯鑳跺泭銆?
 * 瀹冩槸鎾斁椤靛舰鍙樼殑璧风偣锛屽嚑浣曞彧闅忚繖涓€澶勫父閲忓彉鍖栵紙鍒啀鎸夐椤靛崟鎺?鍙屾帓鍘诲姩瀹冿級銆?
 */
const FLOATING_MINI_BAR_HEIGHT_VP: number = 56;

/** 浜岀骇椤甸潰鎮诞杩蜂綘鏉″湪瀹藉睆涓嬬殑鏈€澶у搴︼紙vp锛夛細鑳跺泭涓嶈閾烘弧鏁翠釜骞虫澘/妗岄潰绐楀彛銆?*/
const FLOATING_MINI_BAR_MAX_WIDTH_VP: number = 560;

/**
 * 搴曟爮銆岀幇鍦ㄥ氨鍚€嶉偅涓€椤电殑椤电涓嬫爣銆?
 *
 * 鈽?鐢ㄦ埛 2026-10-15锛堝弬鑰冨浘瀵规瘮锛夛細**杩欎竴椤佃鎶婃诞鍔ㄥ簳鏍忎笂鏂归偅鏉″皬鎾斁鏉℃暣鏉¤棌鎺?*
 *   鈥斺€?鍙傝€冨浘閲?Tab 鏍忎箣涓婂彧鏈変竴琛岃繘搴︼紙宸﹀綋鍓嶆椂闂?/ 涓粏鏉?/ 鍙虫€绘椂闀匡級锛屾病鏈夎糠浣犳潯銆?
 *   鎵€浠ユ湰椤靛仛涓変欢浜嬶紙**鎺掑竷妯″紡涓€涓瓧閮戒笉鍔?*锛岃 `barLayoutModeForHds()` 鐨勬敞閲婏級锛?
 *   鈶?{@link miniBar} 鏉′欢娓叉煋 鈬?閭ｆ潯杩蜂綘鏉＄殑鍐呭涓虹┖锛孒DS 鎸夊唴瀹归噺楂?鈬?**娌℃湁閭ｄ竴鎺?*锛?
 *   鈶?{@link miniBarStyleForHds} 鎭掑洖 `COLLAPSE` 鈬?鍗充究鐢ㄦ埛姝ゅ墠鎶婅糠浣犳潯灞曞紑杩?
 *      锛坄miniBarExpanded === true`锛夛紝鏈〉涔熶笉浼氱敾鍑轰竴鏉″睍寮€鐨?*绌?*鏍忥紱
 *   鈶?`enableMiniBarBackground` 鍦ㄦ湰椤典负 false 鈬?涓嶄細鐣欎笅涓€鏋氱┖鑳跺泭鑳屾澘銆?
 * 鈿狅笍 **涓嶈**鏀圭敤 `barLayoutMode = HORIZONTAL`锛堣瘯杩囷紝鐪熸満鍙嶉"tab 鏍忕煭涓€鎴?锛夛細
 *   閭ｄ釜妯″紡鏄?椤电涓庤糠浣犳潯**骞舵帓**"锛岃糠浣犳潯绌虹潃鏃堕〉绛句細琚尋鍒板乏杈广€佸彸绔┖鍑轰竴鏍笺€?
 * 鈿狅笍 椤哄簭涓?`HomeTabsPages()` 閲?`TabContent` 鐨勬搴忋€乣tabScrollTopCommands[i]` 鐨?
 *   涓嬫爣鍚箟**蹇呴』涓€鑷?*锛坄tab_now_playing` 閭ｄ竴椤瑰氨鏄畠锛夈€?
 */
const NOW_PLAYING_TAB_INDEX: number = 1;

/**
 * 閿洏寮瑰嚭鏃讹紝浜岀骇椤甸潰鎮诞杩蜂綘鏉?*鍐嶅線涓婃姮澶氬皯**锛坴p锛夌殑涓や釜甯搁噺銆?
 *
 * 鑳屾櫙锛堝畼鏂广€婅嚜瀹氫箟閿洏銆嬶級锛氱郴缁熼粯璁ょ殑閿洏閬胯**鍙繚璇佽緭鍏ユ涓嶈閬尅**锛?
 * 杈撳叆妗嗕笅闈㈢殑缁勪欢锛堟湰鏉℃偓娴挱鏀炬潯灏辨槸锛変細琚敭鐩樺帇浣?鈬?蹇呴』鑷繁鎸夐敭鐩橀珮搴﹂伩璁┿€?
 *
 * 绠楀紡锛坄floatingMiniBarKeyboardLiftVp()`锛夛細
 *   lift = 閿洏楂樺害 + {@link FLOATING_MINI_BAR_KEYBOARD_GAP_VP} 鈭?甯告€佷笅鑳跺泭绂诲睆搴曠殑鏃㈡湁闂撮殭
 * 鍏朵腑"鏃㈡湁闂撮殭"鎸?2026-10-12 鐨勭湡鏈轰袱鐐规爣瀹?`gap 鈮?1.8 脳 barBottomMargin` 鍙嶆帹
 * 锛堣 {@link floatingMiniBar} 閲岄偅涓ゆ潯瀹炴祴璁板綍锛夆€斺€?鍑忔帀瀹冩槸涓轰簡**涓嶈鎶婂凡缁忔湁鐨勯偅浠介棿闅?
 * 閲嶅绠椾竴閬?*锛屽惁鍒欓敭鐩樻€佷細姣斿父鎬佹槑鏄炬诞楂樹竴鎴紙搂29.1 鐢ㄦ埛灏辨姤杩?鎾斁鏉℃诞寰楀お楂?锛夈€?
 *
 * 鈿狅笍 鐪熸満璋冩硶锛堝彧鍔ㄨ繖涓や釜甯搁噺锛屽埆鏀圭畻寮忥級锛?
 *   路 閿洏鎬佸亸楂?鈬?璋?*澶?* FACTOR锛堝鍑忎竴鐐癸級锛涘亸浣?/ 浠嶈鍘嬩綇 鈬?璋?*灏?* FACTOR锛堝噺 0 = 鏁存潯涓婄Щ涓€涓敭鐩橀珮锛夈€?
 *   路 鎯虫暣浣撳啀澶氱暀涓€鐐圭紳 鈬?璋冨ぇ GAP銆?
 */
/**
 * ★★★ 2026-10-18（用户：「二级页面这个播放条直接贴底了，加点空隙，键盘避让更明显」）：
 * 上面那段（含 `CAPSULE_GAP_FACTOR` 的旧推导）**作废**，以后面这两条常量为准。
 *
 * 现场几何（本文件已两处确认，不是假设）：
 *   · 宿主盒 = 本页根 `Stack` 的 100%，而根 `Stack` **没有** `ignoreLayoutSafeArea`
 *     ⇒ 它的底边 = **页盒底** = 窗口底 − 系统避让（`WindowInfo.navigationBarBottomVp`）；
 *   · `.offset({ y })` 的 **+y 向下**。
 *
 * 于是离底空隙必须写进 HDS 的 `barFloatingStyle.barBottomMargin`（HDS 里它就是"条到 tabs 底边的距离"），
 * 键盘抬升写在宿主 `.offset`（负数 = 上抬），两者**各管一段、不重复算**：
 *   常态：条底 = 页盒底 − {@link FLOATING_MINI_BAR_BOTTOM_GAP_VP}(12)
 *   键盘：条底 = 页盒底 − 12 − lift，lift = 键盘高 + {@link FLOATING_MINI_BAR_KEYBOARD_GAP_VP}(24) − 12
 *              = 页盒底 − 键盘高 − 24 ⇒ 比键盘上沿（页盒底 − 键盘高）高 **24vp**。
 *
 * ⚠️ 旧代码的"已占用间距"是 `1.8 × (barBottomMargin / 2) ≈ 25.2`（从旧实测反推的**猜测值**）；
 *   底距改成真值 12 之后再减 25.2，整条会**多压下去 13vp** ⇒ 键盘弹起时反被键盘上沿咬住
 *   （用户说的"键盘避让不明显"）。现在"已占用"直接用 12 这个真值，不再有任何系数。
 */
const FLOATING_MINI_BAR_KEYBOARD_GAP_VP: number = 24;
const FLOATING_MINI_BAR_BOTTOM_GAP_VP: number = 12;

/**
 * 涓婃媺鎵撳紑鎾斁椤电殑**璧锋墜鐑尯**楂樺害锛坴p锛岃创灞忓箷搴曢偅涓€鏉★級銆?
 *
 * 杩蜂綘鏉?56 + 搴曢儴閬胯锛堝鑸潯/灏忕櫧鏉＄害 14~24锛? 8 鐨勮竟璺濓紝鍐嶅線涓婁竴灏忔浣欓噺 鈮?112銆?
 * 鍙湁钀藉湪杩欐潯甯﹂噷鐨勪笂婊戞墠鐢卞３灞傛帴绠★紙璇﹁ `pullOpenStartsNearBottom()`锛夆€斺€?
 * 椤甸潰涓鐨勪笂婊戜氦杩樼粰鍒楄〃锛岄伩鍏嶃€屾垜鐨勯〉浠庢挱鏀惧櫒涓婇潰涓€閮ㄥ垎涓婃粦涔熸墦寮€鎾斁鍣ㄣ€嶃€?
 */
const PULL_OPEN_HANDLE_BAND_VP: number = 112;

/**
 * 鎾斁椤垫诞灞傚湪澹冲眰 Stack 閲岀殑灞傜骇銆?
 *
 * 蹇呴』楂樹簬 HdsTabs锛堣嚜宸?`zIndex(1)`锛屾诞鍔ㄥ簳鏍忎篃鍦ㄥ畠閲岄潰锛夊拰浜岀骇椤甸潰鐨勬偓娴糠浣犳潯銆?
 * 鎾斁椤?*涓嶅啀鐢?`bindContentCover`**锛氭ā鎬佸涓绘槸涓嶉€忔槑鐨勪竴灞傦紝浼氱洊浣忛椤典笌杩蜂綘鏉★紝
 * 鑰?浠庤糠浣犳潯闀垮嚭鏉?鐨勫舰鍙樻伆鎭拌閫忓嚭瀹冧滑锛堣瑙?build() 閲岀殑娉ㄩ噴锛夈€?
 */
const PLAYER_OVERLAY_Z_INDEX: number = 100;

/**
 * 褰㈠彉鍏嬮殕灞傦紙杩蜂綘鏉″壇鏈級鍦ㄥ３灞?Stack 閲岀殑灞傜骇锛氬繀椤?*楂樹簬**鎾斁椤垫诞灞傘€?
 * 鍙嶇紪璇戦噷鍏嬮殕灞傛寕鍦?`MainPage` 鐨勬渶涓婂眰锛堜笁涓?lambda锛夛紝姣旀挱鏀鹃〉瀹瑰櫒鏇撮珮銆?
 */
const PLAYER_CLONE_Z_INDEX: number = 110;
/**
 * 鈽?2026-10-17锛氬揩鐓ф敹缂╂诞灞傦紙`ShrinkOverlayHost`锛夌殑灞傛 鈥斺€?**蹇呴』姣斾笂闈㈡墍鏈夋诞灞傞兘楂?*銆?
 *   瀹冧唬琛?姝ｅ湪娑堝け鐨勯偅涓€灞忔挱鏀鹃〉"锛屽帇鍦ㄥ厠闅嗗眰锛?10锛変笌杩蜂綘鏉′箣涓婃墠涓嶄細琚洊浣忋€?
 *   鈿狅笍 鏃犵晫閭ｄ竴渚у畠涔熸病鏈変笓闂ㄧ殑 z锛坄MainPage` 閲屽畠鎺掑湪娴眰瀹夸富涔嬪悗锛夛紝
 *     杩欓噷鏄惧紡缁欎竴涓€煎彧鏄负浜?*涓嶄緷璧栧０鏄庨『搴?*銆?
 */
const SHRINK_OVERLAY_Z_INDEX: number = 130;

/**
 * 鈽?鎾斁椤靛叆鍙?*鍙岃建寮€鍏?*锛堟柦宸ュ浘绗?1 姝ワ級銆?
 *
 * - `true` 锛氭挱鏀鹃〉浣滀负 **NavDestination** 鎺ㄥ叆锛坄pushPath(..., animated = false)`锛夛紝
 *   瀹屽叏瀵规爣鏃犵晫 1.2.4銆傜郴缁熻浆鍦哄繀椤诲叧鎺?鈥斺€?褰㈠彉鑷繁灏辨槸鍔ㄧ敾锛屼袱濂楀姩鐢诲彔鍦ㄤ竴璧?
 *   灏辨槸鐢ㄦ埛鎶ョ殑"鍔ㄧ敾涓€斿皝闈㈠綊浣?/ 搴曢儴绌轰竴鍧?銆?
 * - `false`锛氭棫璺緞锛屾挱鏀鹃〉浣滀负澹冲眰 Stack 閲岀殑娴眰锛坄isShowPlay` 鏉′欢娓叉煋锛夈€?
 *
 * 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鈽呪槄 2026-10-15锛?*宸叉墦寮€**锛屽洜涓轰笂娆″洖閫€鐨勬牴鍥犳壘鍒颁簡 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
 * **鍘熸潵涓轰粈涔堝洖閫€**锛?026-09-25 涓婃満锛夛細`NavDestination` 娓叉煋鍦?`HdsNavigation` 鍐呴儴锛?
 * 鐢ㄧ殑鏄?**STANDARD** 妯″紡 鈥斺€?閭ｄ釜妯″紡涓嬪畠**鑷甫涓嶉€忔槑搴?*锛?閫忔槑鑳屾櫙涔熷帇涓嶄綇 HDS 鑷甫鐨勫簳"锛?
 * 浜庢槸鍚屽湪璇?Navigation 閲岀殑 **HDS 娴姩搴曟爮锛堣糠浣犳潯鐪熻韩锛夎鏁寸墖鐩栦綇**锛?
 * 鑰屽舰鍙樻伆鎭拌閫忓嚭閭ｆ潯杩蜂綘鏉?鈬?"涓€鎺ㄥ叆灏辨垚涓€鍧椼€佸簳閮ㄥ張缂轰竴鍧?銆?
 *
 * **杩欐鐨勮В鑽紙閫嗗悜寰楀埌锛屽凡鏍稿疄鍒?API 灞傦級**锛?
 * 鏃犵晫鐨勬挱鏀鹃〉 `HdsNavDestination` **璁句簡 `mode(NavDestinationMode.DIALOG)`**
 * 锛坄wujie.pa:190804-190811`锛夈€傚畼鏂硅涔夛紙鏈満 SDK
 * `openharmony/ets/component/nav_destination.d.ts:317-333`锛夛細
 * > "Dialog mode, where the navigation destination is **transparent by default**,
 * >  and adding or removing the navigation destination **does not affect the underlying
 * >  page's lifecycle**."
 * 鈬?**榛樿閫忔槑 + 涓嶅奖鍝嶄笅灞傞〉闈?* 鈬?涓嬪眰棣栭〉涓庤糠浣犳潯**涓嶈鐩栦綇銆佷笉琚殣钘?*锛?
 * 褰㈠彉鍏ㄧ▼**鍙涓斿彲閲?*锛坄expand.init` 姝ｆ槸闈?`getFrameNodeById` 鐨勭煩褰㈢畻璧风偣锛夈€?
 * 杩欎竴鍙ュ凡缁忓姞鍦?`features/player/.../PlaybackPageRoute.ets` 鐨?`.mode(...)` 涓娿€?
 *
 * 鈿狅笍 **DIALOG 鐨勪袱涓唬浠?*锛坄PlaybackPageRoute.ets` 閲屽凡澶勭悊/宸叉敞鏄庯級锛?
 *   鈶?DIALOG 榛樿**涓嶅搷搴旇繑鍥為敭** 鈬?蹇呴』鏄惧紡 `.onBackPressed()`锛堝凡缁欙級锛?
 *   鈶?涓嶅啀鏈夌郴缁熻浆鍦轰笌绯荤粺搴?鈬?椤舵爮/鑳屾櫙/瑁佸壀鍏ㄧ敱鎾斁椤佃嚜宸辩敾锛堟湰璇ュ姝わ級銆?
 *
 * 鈿狅笍 **鍥為€€鏂规硶**锛氭妸杩欓噷鏀瑰洖 `false` 鍗冲彲鍥炲埌"澹冲眰娴眰"閭ｆ潯宸查獙璇佸彲鐢ㄧ殑璺?
 *    锛堟诞灞備唬鐮佷笌鍏嬮殕灞傞兘杩樺湪锛岄殢鍖呯紪璇戯紝涓嶇敤閲嶆柊鎼級銆?
 */
const PLAYER_ROUTE_MODE: boolean = true;

/**
 * 鎾斁椤佃矾鐢卞弬鏁帮紙瀵规爣鍙嶇紪璇戦噷鐨?`param.pull`锛夈€?
 *
 * 鐢ㄧ被鑰屼笉鏄尶鍚嶅璞″瓧闈㈤噺锛欰rkTS 瀵?`NavPathInfo.param`锛坄Object`锛変紶瀛楅潰閲忓鏄撴姤绫诲瀷闂锛?
 * 鏄惧紡绫诲瀷涔熻"杩欐杩涘叆瑕佷笉瑕佽蛋褰㈠彉"杩欎欢浜嬪湪鏃ュ織閲屽彲璇汇€?
 */
class PlayerRouteParam {
  /** true = 杩欐杩涘叆瑕佽蛋褰㈠彉锛堢敱鎵嬫寚鎷栧叆鎴栫偣鍑?鎰忓浘鎵撳紑鏃剁粺涓€缃?true锛夈€?*/
  pull: boolean = true;

  constructor(pull: boolean) {
    this.pull = pull;
  }
}

/** 澹冲眰鏃ュ織鏍囩锛坄hdc shell hilog | grep HomeShell` 鍙崬褰㈠彉/璺敱閾捐矾锛夈€?*/
const RzdShellLogTag: string = 'HomeShell';

/**
 * 涓婃媺鏉炬墜鍚庣殑鏀跺熬鏃堕暱锛坢s锛夆€斺€?**鎻愪氦锛堝闃堝€硷級** 涓?**鍙栨秷锛堜笉澶熼槇鍊硷級** 涓や釜鍊笺€?
 *
 * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋細鏀规垚**瀹冮偅濂楀舰鍙樿嚜宸辩殑甯搁噺**锛夛細
 *   鏃犵晫鐨?`commitPull()` / `cancelPull()` 閮借蛋 `animateMorphT(SETTLE_MS, t, EASE_OUT_STR)`锛?
 *   鑰?**`SETTLE_MS = 400`锛屼笖鎻愪氦涓庡彇娑堟槸鍚屼竴涓€?*
 *   锛坄_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂0 閫熸煡 L25/L26 涓?搂鍏?L219/L220锛?
 *   鍚庤€呴€愭潯缁欎簡瀛楄妭鐮佽鍙?L146973 / L146866锛夈€?
 *
 * 鈿狅笍 鏀瑰墠鏄?**300 / 180**锛屽師娉ㄩ噴鍐欑潃"鍙栨棤鐣?Tokens 閲岀殑 300锛堜富杞満锛? 180锛堝井浜や簰锛? 鈥斺€?
 *   **鍙栭敊浜嗘潵婧?*锛氶偅鏄棤鐣岀殑**閫氱敤璁捐 token**锛岃€岃繖閲岃鐨勬槸**杩欏褰㈠彉鑷繁鐨?*甯搁噺
 *   锛坄MainPage.SETTLE_MS`锛夈€傚悓涓€涓敊璇潵婧愬湪"鍏抽棴鏃堕暱"涓婂凡缁忕姱杩囦竴娆★紙搂56.20锛?
 *   閭ｅ涓嶄粎鏃堕暱鍋忕煭锛岀紦鍔ㄨ繕鏁存潯鎶勬垚浜?鎵撳紑"鐢ㄧ殑閭ｆ潯 鈬?鐢ㄦ埛瀹炴祴銆屽叧闂嚑涔庢病鍔ㄧ敾銆嶏級銆?
 *
 * 鈽?椤哄甫涓€涓闈㈡晥鏋滐細澹冲眰鍙犲姞灞傦紙`MorphCoverClone`锛夎窇鐨勬槸鏃犵晫 `ENTER_MS = 560ms`锛堝凡瀵归綈锛夈€?
 *   鏀瑰墠鎾斁椤?`300 + 20 = 320ms` 灏辫惤浣嶏紝**绂诲彔鍔犲眰鐨?560 宸?240ms**锛堣闈?
 *   `morphOverlayBridging()` 鍏滅潃鎵嶄笉琚垏鏂級锛涙敼鎴?400 鍚庤惤浣嶅湪 `420ms`锛?
 *   **宸窛缂╁埌 140ms** 鈬?琚垏鏂殑椋庨櫓鏇村皬銆?
 *
 * 鈿狅笍 杩欐槸**绾鎰?*鏀瑰姩锛堟棤鍔熻兘褰卞搷锛夈€傝嫢浣犱笂鏈鸿寰?鎵撳紑鍙橀挐浜?銆佷笉濡傚師鏉ヨ窡鎵嬶紝
 *   **鍥為€€灏辨槸鎶婅繖涓よ鏀瑰洖 `300` / `180`** 鈥斺€?涓€澶勪竴琛岋紝浜掍笉褰卞搷銆?
 */
const PULL_OPEN_SETTLE_MS: number = 400;
const PULL_OPEN_ABORT_MS: number = 400;

/**
 * 璺熸墜鏈熼棿琛ラ噺"缁灏侀潰缁堢偣"鐨勯噸璇曟鏁?/ 闂撮殧锛坢s锛夈€?
 *
 * 涓?`PlaybackPage` 鐨?12 脳 32ms 鍚屼竴濂楃獥鍙ｏ紙瀵规爣鍙嶇紪璇?`schedulePublishRetry`锛夛細
 * 鎾斁椤垫槸**璧锋墜閭ｄ竴鍒?*鎵嶆寕杞界殑锛屽畠鐨勫ぇ灏侀潰浠€涔堟椂鍊欏彲閲忓彇鍐充簬甯冨眬甯ф暟銆?
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
   * 鏀惰捣璇锋眰閫氶亾锛堜笌鎾斁椤靛叡鐢級銆?
   *
   * 绯荤粺杩斿洖瑕佹眰鍏抽棴鎾斁椤垫ā鎬佹椂锛屽３灞傚彧鍦ㄨ繖閲?`requestCollapse()`锛?
   * 鐪熸鐨勬敹璧峰姩鐢荤敱鎾斁椤垫挱锛屾挱瀹屽畠鑷繁鎶?`isShowPlay` 缃?false銆?
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /**
   * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`MainPage` 鐨?`__shrink` + `shrinkPixmap`锛夛細
   * 銆岄潪鎵嬪娍鍏抽棴銆嶏紙鍏抽棴鎸夐挳 / 绯荤粺杩斿洖锛夐偅涓€妫掔殑**婊＄獥蹇収娴眰**銆?
   *
   * 鏃犵晫閭ｄ竴渚ц繖涓ゆ牱閮芥寕鍦?`MainPage` 涓婏紙`wujie.pa:143995` / `144006`锛夛紝
   * 娓叉煋鐐逛篃鍦?`MainPage`锛坄162465-162707`锛夆€斺€?鎵€浠ユ湰浠撳悓鏍风敱**澹冲眰**鎸佹彙涓庢覆鏌撱€?
   * 鎾斁椤佃礋璐?鎷嶅揩鐓?+ `start(...)`"锛堝畠鎵嶇煡閬撲粈涔堟椂鍊欒鍏筹級锛屽３灞傝礋璐ｇ敾銆?
   */
  @Local shrinkState: MorphShrinkState =
    AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
  /** Cached window metrics (safe areas, size) for layout padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /**
   * 褰撳墠瀵艰埅鏍堟繁搴︼紙0 = 杩樺湪棣栭〉 Tab 涓婏紝>0 = 宸茬粡鎺ㄥ叆浜嗕簩绾ч〉闈級銆?
   *
   * 鍙敤鏉ュ喅瀹氥€屽叏灞€鎮诞杩蜂綘鎾斁鏉°€嶆槸鍚︽樉绀猴細棣栭〉閭ｄ唤杩蜂綘鏉″湪 HDS 娴姩搴曟爮閲岋紝
   * 浜岀骇椤甸潰浼氭妸鏁翠釜娴姩搴曟爮鐩栦綇锛屾墍浠ヤ簩绾ч〉闈㈤渶瑕佸湪鏈€澶栧眰鍐嶆寕涓€浠斤紙瑙?
   * {@link floatingMiniBar}锛夈€?
   *
   * 鈿狅笍 涓嶈鍐嶆嬁瀹冨幓鏀瑰簳閮ㄥ鑸殑 `barHeight` / `barFloatingStyle`锛堣瘯杩囷紝搴曟爮鐩存帴鍧忔帀锛夈€?
   */
  @Local navDepth: number = 0;
  /**
   * 褰㈠彉鍏嬮殕灞傜敤鐨勬挱鏀惧櫒 VM銆?
   *
   * 鍏嬮殕灞傝鐢昏糠浣犳潯鍙充晶閭ｄ竴鍧楃殑**鍓湰**锛堟瓕鍚?姝屾墜 + 鎾斁鎸夐挳锛夛紝瀹冭璇诲綋鍓嶆洸鐩笌鎾帶鐘舵€侊紱
   * 涓庣湡瀹炶糠浣犳潯鍚勮嚜鎸佹湁涓€涓?VM 瀹炰緥鏄畨鍏ㄧ殑锛圴M 鍙槸 `MusicAppState`/`MediaService` 鐨勯棬闈紝
   * 鐘舵€佹湰韬粛鐒跺彧鏈変竴浠斤級銆?
   */

  /**
   * 绐楀彛瀹藉害锛坴p锛夛紝鐢ㄤ簬缁欐偓娴糠浣犳潯绠椾竴涓?*绋冲畾鐨勬樉寮忓搴?*銆?
   *
   * 鎮诞鏉℃槸鍙犲湪椤甸潰涓婄殑鐙珛鑺傜偣锛屽搴﹀繀椤昏嚜宸辩畻鍑嗭細闈?`width('100%')` + 澶栧眰 padding
   * 鍦ㄩ儴鍒嗗舰鎬佷笅浼氱畻閿欙紙hugging 鍒板彸杈?/ 鎾戞垚鏁存潯澶ч暱鏂瑰舰锛夛紝鑰岀櫨鍒嗘瘮瀹藉害鍙堜細鍦?
   * 绐楀彛灏哄鍙樺寲鏃惰烦鍙樸€傝繖閲屽彧鍦ㄩ娆″拰灏哄鐪熸鍙樺寲鏃舵洿鏂般€?
   */
  @Local viewportWidthVp: number = 0;
  /** 瑙嗗彛楂樺害锛坴p锛夛細涓婃媺鎵撳紑鐨?璧锋墜鏄惁鍦ㄥ簳閮?鍒ゅ畾涓庝綅绉绘槧灏勯兘瑕佺敤瀹冦€?*/
  @Local viewportHeightVp: number = 0;
  /** 涓婃媺鎵撳紑鎵嬪娍锛堢珫鐩存柟鍚戯級銆?*/
  @Local miniBarViewModel: PlayerViewModel = new PlayerViewModel();
  private pullOpenOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /**
   * 璇婃柇闂革細鏈疆鎵嬪娍鏄惁**宸茬粡璁拌繃涓€娆?*"璺熸墜鏇存柊琚垽鎹嫆鎺?銆?
   *
   * 涓轰粈涔堥渶瑕佸畠锛堣€屼笉鏄瘡娆￠兘璁帮級锛歚onPullOpenUpdate` 鐢辨瘡涓Е鎽哥Щ鍔ㄤ簨浠惰皟鐢紝
   * 鑰岃鏁拌惤鍦?`PlayerExpandState` 鐨?`@Trace` 瀛楁涓?鈬?姣忔閮藉啓浼氳寰芥爣閭ｄ釜
   * 13 琛?`Text` 姣忓抚閲嶅缓锛?*璇婃柇鏈韩浼氭妸鎵嬫劅鎼呮祽**銆傝瘖鏂彧闇€瑕?杩欎竴杞湁娌℃湁琚嫆"
   * 杩欎竴涓簨瀹?鈬?涓€娆℃墜鍔垮彧璁颁竴娆★紙`onPullOpenStart` 閲屾竻闆讹級銆?
   * 璇绘暟锛氬窘鏍囩鍗佽 `pd=<璧锋墜鎷?/<鏇存柊鎷?/<鏉炬墜鎷?`锛岃 `PlayerExpandState.pullDropBegin`銆?
   */
  private pullDropCountedThisGesture: boolean = false;

  /**
   * 涓€寮犳埅鍥惧氨鑳芥嬁鍒?x/y/w/h锛屼笅涓€杞寜鏁板瓧鏀瑰畬鍗冲垹銆?
   */
  private tabsController: HdsTabsController = new HdsTabsController();
  /**
   * 杩涘嚭浜岀骇椤甸潰鏈熼棿鎶戝埗 HDS 鐨勬牱寮忓洖璋冿紙杩涗簩绾ч〉闈笉鍐嶆敼甯冨眬鐘舵€侊紝鍙敤浜庡嚭椤甸潰鏃剁殑骞傜瓑瀵归綈锛夈€?
   */
  private restoringHomeBar: boolean = false;

  /**
   * 澹冲眰姝ゅ埢鏄惁**鑷繁**鎸佹湁娴眰閭ｄ竴妫掔殑琛ラ棿锛坄MorphCoverClone` 鐨?`morphOverlayP`锛夈€?
   *
   * 鐢ㄩ€斿彧鏈変竴涓細缁?`@Monitor('expandState.morphDrive')` 璁╄矾 鈥斺€?
   * `settlePullOpen` 璧峰畬澹冲眰鐨勬诞灞傝ˉ闂翠箣鍚庝細鎶?`morphDrive` 缃垚 `ANIM`锛?
   * 閭ｄ竴鐬洃鎺у洖璋冧篃浼氳瑙﹀彂锛涗笉鍥炶鐨勮瘽瀹冧細鍐嶈捣涓€鏉℃柟鍚戠浉鍙嶇殑娴眰琛ラ棿
   * 锛?鏉炬墜娌¤繃闃堝€笺€佸皝闈㈠凡缁忓線鍥炶ˉ浜嗭紝鍙堣鎷藉埌钀戒綅"锛夈€?
   * 娉ㄦ剰瀹?*涓嶆槸**娓叉煋闂紙娓叉煋闂ㄥ湪 `PlayerExpandState.morphOverlayBridging()` 閲岋級銆?
   */
  private shellOwnsOverlayTween: boolean = false;

  /** Initializes play queue ids from local DB for the session. */
  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto) => dto.id);
    // 鈽?椤电浠?4 涓敹鎴?2 涓紙鎺ㄨ崘 / 鎴戠殑锛変箣鍚庯紝`TabSwitchState.tabIndex` 鍙兘鏄笂涓€鐗堢暀涓嬬殑
    //   瓒婄晫涓嬫爣锛堟瘮濡傛棫鐨勩€屾垜鐨勩€? 2銆併€岃缃€? 3锛夆€斺€?HdsTabs 鎷垮埌瓒婄晫涓嬫爣浼氳惤鍦ㄧ┖鐧介〉涓娿€?
    //   鍏变韩鐘舵€侀噷娌℃湁"椤电鏁?杩欎釜姒傚康锛屾墍浠ュ湪杩欓噷澶逛竴娆★細瓒婄晫鍗冲洖棣栭〉銆?
    // 鈽?2026-10-15锛氥€岀幇鍦ㄥ氨鍚€嶆彃鍒般€屾帹鑽愩€嶄笌銆屽洖鍝嶃€嶄箣闂?鈬?椤电鏁板彉 4锛屼笂鐣?2 鈫?3銆?
    //   鈿狅笍 杩欎竴灞傛病鏈夊崟涓€鐪熸簮锛氭彃/鍒犻〉绛惧繀椤?*鍚屾椂**鏀瑰洓缁勬寜涓嬫爣鍙栫殑鍦版柟 鈥斺€?
    //     鈶?杩欓噷锛堣秺鐣屽す鍙栦笂鐣岋級锛涒憽 `tabScrollTopCommands` 闀垮害锛?
    //     鈶?`tabBounceTriggers` 闀垮害锛涒懀 `TabBarItem(i,鈥?` 涓庡悇椤?`scrollTopCommand` 鐨勪笅鏍囥€?
    //   婕忎竴缁勫氨鏄?閿欎綅 / 涓嶅脊 / 涓嶅浣?銆?
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
    // 鏈湴闊充箰搴撲笌鍚屾瀹㈡埛绔湪鍚姩鏃跺垵濮嬪寲锛氭湰鍦伴煶涔愯寤烘矙绠辩洰褰曞苟杞藉叆绱㈠紩锛?
    // 鍚屾瀹㈡埛绔璇诲洖鏈嶅姟鍣ㄥ湴鍧€涓庡紑鍏筹紙寮€鍏充负鍏虫椂涓嶈繛鏈嶅姟绔級銆?
    //
    // 鈿狅笍 涓や釜閮藉寘 try/catch锛氬畠浠?*涓嶆槸**鎾斁鐨勫墠缃潯浠讹紝浣嗛兘鍦?`aboutToAppear` 閲屻€?
    //    涓€鏃﹁繖閲屾姏鍑哄幓锛宍aboutToAppear` 浼氫腑鏂紝鍚庨潰锛堜互鍙婂皢鏉ュ姞鍦ㄨ繖閲岀殑锛夊垵濮嬪寲
    //    鍏ㄨ璺宠繃 鈥斺€?閭ｄ細琛ㄧ幇鎴?鑾悕鍏跺鏁翠釜鎾斁閮界敤涓嶄簡"锛屾帓鏌ヨ捣鏉ラ潪甯哥粫銆?
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
    // 璇勮闈㈡澘瑕佽兘澶勭悊鏈湴闊充箰锛氭妸銆屾湰鍦版瓕 -> 骞冲彴韬唤銆嶇殑瑙ｆ瀽浜ょ粰 comment
    // 锛坈omment / player 閮戒笉鑳藉弽鍚戜緷璧?localmusic锛屾墍浠ヨ繖涓槧灏勫彧鑳界敱澹冲眰鎷硷級銆?
    setCommentTargetResolver((song: CommentSongRef): Promise<CommentSongRef | null> => {
      return Promise.resolve(this.resolveCommentTarget(song));
    });
    this.syncViewportWidthVp();
    // ★★★ 2026-10-17（⑤「点击打开背景仍对不上」的第一条）：`@Monitor` 只在**变化**时触发。
    //   冷启动这一拍：`playQueueIds` 刚从库里读回（上面第 2 行）、`selectIndex` 还是 0，
    //   若持久化恢复出来的 selectIndex 恰好也是 0，则**没有任何变化事件** ⇒ 预热一次都没跑过
    //   ⇒ 播放页 `adoptWarmMesh()` 永远比对不上 ⇒ 用户看到的就是兜底网格（别的歌的颜色）。
    //   ⇒ 这里显式补一次（幂等：`MeshWarmService` 内部有 in-flight / done 去重）。
    prewarmCurrentSongMesh(this.getUIContext(), this.appState.getCurrentSongItem());
  }

  /**
   * 鏈湴闊充箰 -> 骞冲彴韬唤锛堣瘎璁洪潰鏉垮唴閮ㄤ細璋冪敤锛夈€?
   *
   * 鏈湴姝屽彧瀛樹簡鏈湴 key锛岃鍙栬瘎璁哄緱鍏堢煡閬撳畠鍖归厤鍒板钩鍙颁笂鐨勫摢涓€棣栵細
   * 鐢?`localMusic.matchOf` 璇诲尮閰嶈褰曪紙鑷姩鍖归厤鎴愬姛鎴栫敤鎴峰湪銆屽尮閰嶆瓕璇嶃€嶉噷鎵嬮€夌殑閭ｆ潯锛夈€?
   * 娌℃湁璁板綍灏辫繑鍥?null锛岃瘎璁洪潰鏉夸細鎻愮ず銆岃繖棣栨瓕杩樻病鍖归厤鍒板钩鍙颁笂鐨勭増鏈€嶃€?
   *
   * @param song 璇勮闈㈡澘缁欑殑姝屾洸韬唤锛堟湰鍦版瓕鐨?songId 灏辨槸鏈湴 key锛夈€?
   * @returns 骞冲彴韬唤锛屾垨 null銆?
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
   * 璁板綍绐楀彛瀹藉害锛坴p锛夛紝渚涙偓娴糠浣犳潯绠楀搴︺€?
   *
   * 鍙湪杩欓噷绠椾竴娆°€佸苟鍦?`onAreaChange` 閲屽埛鏂帮細鎮诞鏉℃槸鍙犲湪椤甸潰涓婄殑鐙珛鑺傜偣锛?
   * 鐩存帴璇?`windowInfo.windowSize`锛坧x锛夊湪 build 閲屾崲绠椾細甯﹁繘涓€涓笉绋冲畾鐨勪緷璧栥€?
   * @returns 瀹藉害锛坴p锛夈€?
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
    // 楂樺害涓€璧峰埛锛堝悓涓€浠?windowSize锛屼笉澶氳姳浠ｄ环锛?
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
      // 鐩存帴鎸傝捣鎾斁椤靛嵆鍙細灞曞紑鍔ㄧ敾鐢辨挱鏀鹃〉鑷繁鎾紙瑙?playExpandIntro / morphScaleValue锛夈€?
      this.appState.isShowPlay = true;
    });
  }

  /**
   * 閿洏閬胯璇婃柇锛氳蒋閿洏寮瑰嚭 / 鏀惰捣鏃舵墦涓€琛岋紙`hdc shell hilog | grep RzdKeyboardAvoid`锛夈€?
   *
   * 鈿狅笍 **涓嶈鍦ㄥ３灞傚啀鎸備竴浠界獥鍙ｇ洃鍚?*锛歚TYPE_KEYBOARD` 鐨勯伩璁╁尯鐢?
   * `common/musicbasic` 鐨?`WindowUtil.updateWindowInfo()` 缁熶竴鐩戝惉锛堝叏杩涚▼鍞竴涓€澶勶級锛?
   * 杩欓噷鍙槸**璇?*瀹冨啓杩?`WindowInfo.avoidKeyboard`锛坄@Trace`锛夌殑缁撴灉 鈥斺€?
   * 璇?`@Trace` 灞炴€ф棦鑳介┍鍔ㄦ湰鏉℃偓娴潯鐨勯噸鏂板竷灞€锛屼篃姝ｅソ鏄繖涓瘖鏂柇鐐广€?
   */
  @Monitor('windowInfo.avoidKeyboard')
  onKeyboardAvoidAreaChanged(): void {
    Logger.info('RzdKeyboardAvoid',
      `shell secondary bar keyboardVp=${this.keyboardBottomVp()} ` +
        `lift=${this.floatingMiniBarKeyboardLiftVp()} offsetY=${this.floatingMiniBarHostOffsetYVp()} ` +
        `bottomGap=${FLOATING_MINI_BAR_BOTTOM_GAP_VP} keyGap=${FLOATING_MINI_BAR_KEYBOARD_GAP_VP}`);
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鎾斁椤靛叆鍙ｏ細`isShowPlay` 鈫?NavDestination 鎺ㄥ叆 / 寮瑰嚭 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // 鈽?鏂藉伐鍥剧 1 姝ョ殑鍋氭硶锛?*涓嶉€愪釜鏀硅皟鐢ㄧ偣**銆?
  //   宸ョ▼閲?鎵撳紑鎾斁椤?鐨勫啓娉曟湁浜斿叚澶勶紙杩蜂綘鏉＄偣鍑汇€佹挱鏀炬剰鍥俱€佽捣鎾剰鍥俱€佷笂鎷夋澗鎵嬧€︼級锛?
  //   "鍏抽棴"涔熸湁涓夊锛堟挱鏀鹃〉杩斿洖鎸夐挳銆佷笅鎷夋敹璧峰畬鎴愩€丆ontrolArea锛夛紝
  //   涓庡叾閫愪釜鏇挎崲鎴?push/pop锛堟紡涓€涓氨鏄?鏈夌殑鍏ュ彛杩樻槸鏃у姩鐢?锛夛紝涓嶅鍦ㄥ３灞傛妸
  //   `MusicAppState.isShowPlay` 杩欎釜**鏃㈡湁鍞竴鐪熸簮**缈昏瘧鎴愯矾鐢卞姩浣滐細
  //       isShowPlay: false 鈫?true   鈬?鎺ㄥ叆鎾斁椤佃矾鐢?
  //       isShowPlay: true  鈫?false  鈬?寮瑰嚭鎾斁椤佃矾鐢?
  //   鏃㈡湁璋冪敤鐐逛竴琛岄兘涓嶇敤鏀癸紝鏂板鍏ュ彛涔熻嚜鍔ㄨ鐩栥€?

  /** 鎾斁椤垫寕杞?鍗歌浇鐨勫敮涓€鏀跺彛锛堟墍鏈?`isShowPlay` 鍐欏叆鏈€缁堥兘浼氳蛋鍒拌繖閲岋級銆?*/
  @Monitor('appState.isShowPlay')
  onShowPlayChanged(): void {
    if (!PLAYER_ROUTE_MODE) {
      Logger.info('RzdPlayerRoute', `overlay visible=${this.appState.isShowPlay} retainedPaths=${JSON.stringify(this.pageIndexInfos.getAllPathName())}`);
      return;
    }
    if (this.appState.isShowPlay) {
      // 鈽呪槄鈽?2026-10-16锛?*鍏抽棴杩囩▼榛戝專瀛?路 鍞竴鑳借 `OPN` 鐨勫湴鏂瑰氨鏄繖閲?*锛夛細
      //   鐢ㄦ埛鎶ョ殑銆屽叧闂悗鍙堢獊鐒舵斁涓€閬嶅睍寮€銆嶁€斺€?澶村彿瀚岀枒鏄?*澹冲眰鎶婃挱鏀鹃〉鍙堟帹浜嗕竴娆?*
      //   锛坄isShowPlay` 鍦ㄥ叧闂€斾腑琚皝鍐欏洖 true 鈬?鏈?`@Monitor` 鏀跺埌 false鈫抰rue
      //   鈬?`beginOpenMorphOnClick()` + `pushPlayerRoute()` 鈬?鏂板疄渚嬨€佹柊灞曞紑鍔ㄧ敾锛夈€?
      //   杩欎竴绗?*鍙湁澹冲眰鑳借**锛堟挱鏀鹃〉閭ｄ竴鍒诲凡缁?pop 浜嗭級锛屾墍浠ヤ簨浠舵棩蹇楀仛鎴愪簡 public static
      //   锛堣 `PlaybackPage.evLog` 鐨勮鏄庯級銆傝娉曡鑷瘉寰芥爣绗崄涓夎锛氭甯稿叧闂悗閲嶆柊鎵撳紑锛?
      //   鏃ュ織閲?*鍙簲鏈変竴鏉?`OPN`**锛涜嫢鍏抽棴娈典箣鍚庣揣璺熶竴鏉?`OPN` 鑰岀敤鎴峰苟娌℃湁鐐瑰紑 鈬?灏辨槸瀹冦€?
      PlaybackPage.ev('OPN', `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
      // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*鐐瑰嚮鎵撳紑涔熷繀椤昏蛋褰㈠彉**銆?
      //   鏃犵晫閲屻€岀偣鍑绘挱鏀炬潯銆嶅拰銆屼笂婊戞墜鍔裤€?*鍏辩敤鍚屼竴涓?`beginMorphEnter`**
      //   锛堝叏鍖呭彧鏈?`openPlayerMorph` 涓?`pullStart` 涓や釜璋冪敤鑰咃紝瑙?
      //   `_recover/logic-src/鐐瑰嚮鎵撳紑鎾斁鍣ㄥ舰鍙橀摼璺?md` 搂涓€锛夈€傛鍓嶈繖閲屽彧鎺ㄨ矾鐢便€?
      //   涓嶅惎鍔ㄥ舰鍙?鈬?鐐瑰嚮璧扮殑鏄挱鏀鹃〉閲岄偅濂?*娲鹃煶鑷挱**锛坄collapseProgress`锛夛紝
      //   涓庝笂婊戠殑澹冲眰褰㈠彉鏄袱鏉′簰涓嶇浉骞茬殑鍔ㄧ敾 鈥斺€?鐢ㄦ埛瀹炴祴銆岀偣鍑绘墦寮€鎾斁鍣ㄦ病鏈夊姩鐢汇€?
      //   銆岃儗鏅笉瀵广€嶅氨鏄畠銆傞『搴忓榻愭棤鐣岋細鈶?閲忔簮骞惰繘鐩镐綅 鈫?鈶?鎺ㄨ矾鐢辨寕杞?
      //   鈫?鈶?閲忕粓鐐癸紙`onPullReady` 绛変环鐗╋級鈫?鈶?鏀跺熬琛ラ棿 `commitPull()` 绛変环鐗┿€?
      // ★★★ 2026-10-17（用户实测「点击打开播放页时背景是别的歌的颜色」）：
      //   形变只有 350~400ms，而在线歌的 64×64 网格要下载 + 解码（200~2000ms）⇒
      //   在**启动形变之前**再踢一次预热（曲目变化时也踢，见 onCurrentTrackForMeshPrewarm）。
      //   预热是"同步返回、异步干活"，这里不会被它拖住首帧。
      prewarmCurrentSongMesh(this.getUIContext(), this.appState.getCurrentSongItem());
      const morphStarted: boolean = this.beginOpenMorphOnClick();
      this.pushPlayerRoute();
      if (morphStarted) {
        // 鈽呪槄鈽?2026-10-16锛?*鐐瑰嚮鎵撳紑娌℃湁灏侀潰鍔ㄧ敾**鐨勬渶鍚庝竴鍧楁嫾鍥撅級锛?
        //   鏄惧紡鎶娿€屾诞灞傞偅涓€妫掋€嶏紙澹冲眰 `MorphCoverClone` = 缁灏侀潰锛夎捣璧锋潵锛?
        //   **涓嶅啀鍙緷璧?* `@Monitor('expandState.morphDrive')`銆?
        //
        // ## 涓轰粈涔堝繀椤绘樉寮?
        //
        // 灏侀潰閭ｄ竴妫掓湁**涓ゆ潯鐙珛鐨勮繘搴?*锛?
        //   路 鎾斁椤甸偅灞傦紙`morphP`锛夆€斺€?瀹瑰櫒 scale/translate/clip锛?*鑳屾櫙涔熷湪閲岄潰**锛?
        //   路 娴眰閭ｅ眰锛坄morphOverlayP`锛夆€斺€?澹冲眰鐨勭画椋炲皝闈紝**灏侀潰灏遍潬瀹冮**銆?
        // 涓ゆ潯椹卞姩璺緞锛?
        //   路 鎵嬫寚璺熸墜锛歚onPullOpenUpdate` 鈫?`syncMorphOverlayFromPage()`锛?*涓€姣斾竴鍚屾**锛夆湏
        //   路 鐐瑰嚮/鏉炬墜锛歚settlePullOpen` 鈫?`morphOverlayTweenTo()`锛?
        //     浠ュ強 `@Monitor('expandState.morphDrive')` 鈫?`focusMorphOverlayForPageIntro()`銆?
        // 鈿狅笍 鍚庤€呮槸 **V2 寮傛鍥炶皟**锛岃€?`focusMorphOverlayForPageIntro()` 閲屾湁涓ら亾**闈欓粯 return**
        //   锛坄morphDrive !== MorphDrive.ANIM` / `!morphContainerActive()`锛夆€斺€?瀹?*涓嶅啓鏃ュ織**锛?
        //   涓€鏃﹂偅涓€鍒荤浉浣嶈繕娌″氨浣嶏紝杩欎竴妫掑氨**鏁存涓嶆挱銆佽€屼笖鏌ヤ笉鍑烘潵**銆?
        //   鐢ㄦ埛瀹炴祴銆?*鐐瑰嚮鎾斁鏉℃墦寮€鎾斁鍣?/ 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖鍏抽棴閮芥病鏈夊皝闈㈠姩鐢?*銆?
        //   鑰屻€屼笂鎷夋墦寮€姝ｅ父銆嶏紝宸紓姝ｆ槸"璺熸墜閭ｆ潯鍚屾璺蛋閫氫簡銆侀潪鎵嬪娍杩欐潯璺病璧伴€?銆?
        //
        // 鈬?杩欓噷鍦?*鎺ㄨ矾鐢变箣鍚庛€佺浉浣嶅凡灏变綅**鐨勪綅缃樉寮忓枈涓€澹?
        //   锛堜笌 `PlaybackPage.closeFullScreenPlayback()` 閲?鍚屾椹卞姩娴眰"閭ｆ潯**鍚屾鍋氭硶**锛?
        //     瑙侀偅杈?2358-2370 琛岀殑闀挎敞閲?鈥斺€?瀹冨綋鏃朵慨鐨勬鏄?鍏抽棴娌℃湁灏侀潰鍔ㄧ敾"锛夈€?
        //   鈿狅笍 骞傜瓑锛歚focusMorphOverlayForPageIntro()` 鐨勪袱閬撳畧鍗?+ `morphOverlayTweenTo()`
        //     鐨?璧风偣==缁堢偣鐩存帴杩斿洖" / `morphOverlayAnimating` 涓嶆姠 鈬?閲嶅璋冪敤瀹夊叏銆?
        this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
        this.schedulePullAnchorRemeasure(0);
        // 瀹冭嚜甯?婧愬嚑浣曡繕娌￠噺榻愬氨 32ms 閲嶈瘯"閭ｆ潯绐楀彛锛岀瓑浠蜂簬鏃犵晫鐨?`ExpandSnapshot.onPullReady`銆?
        this.settlePullOpen(true);
      }
    } else {
      this.popPlayerRoute();
    }
  }

  /**
   * ★★★ 2026-10-17（用户实测「点击打开播放页时背景是别的歌的颜色 / 对不上」）：
   * **当前曲目一变就预热 64×64 网格源**（结果存 `MeshWarmState`，播放页 `onAppear` 直接采用）。
   *
   * 为什么放在壳层：壳层是唯一"曲目切换一定会走到"的地方；播放页在形变开始前才挂载，
   * 那时已经来不及下载了。预热失败只记日志，不影响播放。
   */
  @Monitor('appState.selectIndex', 'appState.playQueueIds')
  onCurrentTrackForMeshPrewarm(): void {
    prewarmCurrentSongMesh(this.getUIContext(), this.appState.getCurrentSongItem());
  }

  /**
   * 鐐瑰嚮鎵撳紑锛?*闈炴墜鍔垮叆鍙?*锛夌殑褰㈠彉鍚姩 鈥斺€?瀵规爣鏃犵晫 `MainPage.openPlayerMorph(src)`銆?
   *
   * 鏃犵晫鐨勫師鏂囷紙`鐐瑰嚮鎵撳紑鎾斁鍣ㄥ舰鍙橀摼璺?md` 搂涓€ + 鍗烽鏇存锛夛細
   * ```ts
   * openPlayerMorph(src?) {
   *   const s = src ?? this.ownMorphSource;
   *   if (!this.beginMorphEnter(s)) { this.enterAnimStarted = false;
   *                                   this.nav.pushPath({ name: R_PLAYER }); return; }  // 閫€鍖栵細鏃犲舰鍙?
   *   // beginMorphEnter 鍐呴儴宸茬粡 pushPath({name, param:{pull:true}}, animated=false)
   *   ExpandSnapshot.onPullReady = 位;      // 灏辩华 鈫?commitPull() 鈫?animateMorphT(400, t=1)
   * }
   * ```
   * 鏈柟娉曞彧鍋氣憼銆岄噺婧愬苟杩涚浉浣嶃€嶈繖涓€鍗婏紱鈶℃帹璺敱鍦ㄨ皟鐢ㄧ偣绱ц窡鍏跺悗锛屸憿鈶ｄ篃鐢辫皟鐢ㄧ偣鍙戣捣
   * 锛堝洜涓?`pushPath` 鏄３灞傜殑绉佹湁鍔ㄤ綔锛屼笉鑳借鏈柟娉曞弽璋冿級銆傝繖鏍风偣鍑讳笌涓婃粦
   * **鍏辩敤鍚屼竴浠藉嚑浣曘€佸悓涓€涓浉浣嶃€佸悓涓€鏉℃敹灏捐ˉ闂?*锛屽睆涓婂彧鍙兘鏈変竴涓姩鐢讳富銆?
   *
   * 鈿狅笍 涓夋潯瀹堝崼锛岀己涓€鏉″氨浼氬拰鎵嬪娍鎴栧凡鏈変細璇濇墦鏋讹紙姣忎竴鏉￠兘鏈夊疄娴嬩緷鎹級锛?
   *   路 `pullDragging` 鈥斺€?鎵嬫寚姝ｅ湪椹卞姩锛坄onPullOpenStart` 閭ｆ潯璺級锛岃缁欏畠锛岃皝涔熷埆鎶紱
   *   路 `morphContainerActive()` 鈥斺€?宸茬粡鍦ㄤ竴涓舰鍙樹細璇濋噷锛堜笂婊戦偅鏉¤矾鍦?
   *     `onPullOpenStart` 閲屽凡缁?`pullOpenBegin` 杩囷紝涓?`isShowPlay` 涔熸槸瀹冪疆鐨勶級
   *     鈬?鍐?begin 涓€娆′細鎶婂垰閲忓埌鐨勫嚑浣曚綔搴燂紝閭ｅ氨鏄?瑕嗙洊灞傚弽澶嶅綊闆?鐨勬潵婧愶紱
   *   路 `pullOpenBegin` 杩斿洖鍋囷紙杩蜂綘鏉℃病鎸傝浇 / 瀹夸富娌″昂瀵革級鈥斺€?閫€鍖栨垚"鐩存帴閾烘弧"銆?
   *     杩欎笌鏃犵晫閲忎笉鍒拌兌鍥婃椂鎵?`morph: 閲忎笉鍒拌兌鍥?barId=鈥?鈬?鏈閫€鍥炴櫘閫?push(鏃犲舰鍙?`
   *     鏄悓涓€褰㈢姸锛?*瀹佸彲涓嶅仛鍔ㄧ敾锛屼篃涓嶈兘鎶婃挱鏀鹃〉鍘嬫垚涓€鏉＄粏缂?*銆?
   * @returns true = 褰㈠彉宸茶繘鍏ョ浉浣嶏紙璋冪敤鏂瑰簲缁х画 鈶⑩懀锛夛紱false = 宸查€€鍖栦负鏃犲姩鐢昏惤浣?
   */
  private beginOpenMorphOnClick(): boolean {
    this.expandState.resetMorphTrace('clickOpen');
    // 鈽呪槄鈽?2026-10-16锛?*缁欒繖鏉″畧鍗ˉ鑷剤** 鈥斺€?瀹冩鍓嶄細"姘镐箙"鎸′綇鐐瑰嚮鎵撳紑锛夛細
    //   鍘熷垽鎹槸 `pullDragging || morphContainerActive()`銆備袱鏉￠兘浼?*娈嬬暀**锛?
    //   路 `pullDragging`锛氭墜鍔胯鎵撴柇涓旀病璧板埌鏀跺熬锛堢郴缁熸姠鎵嬪娍 / 椤甸潰琚垏璧帮級锛?
    //   路 `morphContainerActive()`锛氱浉浣嶆畫鐣?`ENTERING/LEAVING/LANDING`銆?
    //   鈿狅笍 鑰?*鐩镐綅娈嬬暀涓嶆槸"鐢ㄦ埛杩樺湪鐢ㄦ挱鏀鹃〉"**锛氱敤鎴风偣"鎵撳紑"鏃?`isShowPlay`
    //      **蹇呯劧鍒氫粠 false 鍙樻垚 true**锛坄onShowPlayChanged` 灏辨槸瀹冭Е鍙戠殑锛夈€?
    //      鈬?鍙"鏈疆寮€濮嬫椂鎾斁椤?*杩樻病鏄剧ず**"锛岄偅涓ゆ潯娈嬬暀灏遍兘鏄?*涓婁竴杞殑鍨冨溇**锛?
    //        搴斿綋**娓呮帀骞剁户缁?*锛岃€屼笉鏄妸杩欎竴娆℃墦寮€鍒ゆ垚"閲嶅 / 宸插湪浼氳瘽閲?銆?
    //   鈿狅笍 鍘熸敞閲婏紙鏈枃浠?4332-4336 琛岋級宸茬粡鐐瑰嚭杩欎釜褰㈢姸浼氬鑷?
    //     銆?*鐐瑰嚮鎵撳紑鍙堥€€鍖栨垚娲鹃煶鏃у姩鐢?*銆嶏紝浣嗗畠鍙粰 `dismissMorphActive` 鍋氫簡鑷剤锛?
    //      **杩欐潯瀹堝崼鏈韩娌″仛**銆傗噿 杩欏氨鏄?鐐逛簡娌″姩鐢?閲屾渶闅惧鐜扮殑閭ｄ竴绉嶃€?
    // 鈽呪槄鈽?2026-10-17锛?*鍒ゆ嵁璁㈡ 路 绗簩娆?*锛氱涓€鐗堟妸**涓婃媺鎵嬪娍**鎵撴柇浜?鈥斺€?鐢ㄦ埛瀹炴祴銆屼笂婊戜笉鑳借嚜鐢变簡銆嶏級
    //
    // ## 绗竴鐗堥敊鍦ㄥ摢锛堝繀椤昏涓嬫潵锛?
    //   绗竴鐗堟妸鍒ゆ嵁浠?`this.appState.isShowPlay`锛堟亽鐪燂級鎹㈡垚 `playerRouteIndex() >= 0`锛?
    //   鐢ㄦ剰鏄 `staleClr` 鑷剤鐪熺殑鑳借窇鍒般€備絾**涓婃媺鎵撳紑杩欐潯璺篃璧版湰鍑芥暟**锛?
    //   ```ts
    //   // 澹冲眰 onPullOpenStart锛?
    //   this.expandState.pullDragging = false;
    //   const morphOk = this.expandState.pullOpenBegin(...);   // 鈫?閲岄潰鎶?pullDragging 缃?true
    //   if (!this.appState.isShowPlay) { this.appState.isShowPlay = true; }   // 鈫?瑙﹀彂鏈?Monitor
    //   ```
    //   鈬?璧板埌杩欓噷鏃?`pullDragging === true`锛堟墜鎸囨鍦ㄩ┍鍔級鑰?*璺敱杩樻病 push**
    //     鈬?鏂板垽鎹畻鍑?`routeOnStack === false` 鈬?钀借繘 `staleClr` 鏀?
    //     鈬?**`pullDragging = false` + `morphReset()`** 鈬?璺熸墜浼氳瘽琚嚜宸辨帎姝?
    //     鈬?銆屼笂婊戜笉鑳借嚜鐢变簡銆嶃€?鏃т唬鐮佸垽鎹亽鐪?鈬?璧?`skip` 鈬?姝墦姝ｇ潃鍦版姢浣忎簡鎵嬪娍銆?
    //
    // ## 璁㈡鍚庣殑缁撴瀯锛?*涓や欢浜嬪垎寮€鍒?*锛岃繖鎵嶆槸鍘熸敞閲婄湡姝ｆ兂琛ㄨ揪鐨勬剰鎬濓級
    //   路 鍘熸敞閲婅嚜宸卞啓鐫€銆屼笂鎷夋墜鍔垮湪棣栭〉璧锋墜鏃惰矾鐢辫繕娌?push銆備絾閭ｆ椂 `pullDragging === true`
    //     鈬?涓婇潰閭ｆ潯瀹堝崼浼氬厛 return锛堜笉褰卞搷鎵嬪娍锛夈€嶁€斺€?**"鎵嬫寚鍦ㄩ┍鍔ㄥ氨鏀捐"鏄師鏈夋剰鍥?*锛?
    //     鍙槸琚亽鐪熺殑鏍囧織瀹炵幇鍧忎簡銆?
    //   路 鎵€浠ワ細**`pullDragging === true` 鈬?涓€寰嬫斁琛岋紙閭ｆ槸娲讳細璇濓紝涓嶆槸娈嬬暀锛?*锛?
    //     鍙湁"鐩镐綅娈嬬暀**涓?*娌℃湁鎵嬫寚鍦ㄩ┍鍔?鎵嶈疆鍒板垽"鏄笉鏄湡宸茬粡鍦ㄦ挱鏀鹃〉閲?銆?
    //   鈿狅笍 绗簩灞傚垽鎹粛鐢?*纭鏁?* `playerRouteIndex() >= 0`锛堜笌涓嬮潰 `leakClr` 鍚屽彛寰勶級鈥斺€?
    //     鍥犱负 `isShowPlay` 鍦ㄥ敮涓€璋冪敤鐐逛笂蹇呯劧宸叉槸 true锛岃瀹冪瓑浜庢病鍒ゃ€?
    //   鈿狅笍 杩欎竴灞傛槸蹇呴渶鐨勶細鏈疆鎶婂叧闂敹灏剧殑 `morphReset()` 鏀规垚"绛?pop 涔嬪悗鍐嶅浣?
    //     锛坄PlaybackPage.scheduleMorphResetAfterPop`锛岃 `RzdMusic璁板繂.md` 搂125锛?
    //     鈬?鍏抽棴鍚庡埌澶嶄綅鍓嶉偅涓€灏忔鐩镐綅浠嶆槸 `LANDING`锛涚偣寮€鏃跺繀椤昏兘娓呮帀瀹冦€?
    if (this.expandState.pullDragging) {
      // 鎵嬫寚姝ｅ湪椹卞姩锛堜笂鎷?涓嬫媺璺熸墜锛夛細**娲讳細璇?*锛岃皝涔熷埆鍔ㄥ畠
      this.expandState.pushMorphTrace('skip');
      Logger.info(RzdShellLogTag,
        `open morph: skip (finger driving; stage=${this.expandState.morphStage} ` +
        `routeOnStack=${this.playerRouteIndex() >= 0 ? 1 : 0})`);
      return false;
    }
    if (this.expandState.morphContainerActive()) {
      // 鐩镐綅娈嬬暀浣嗘病鏈夋墜鎸囧湪椹卞姩 鈬?鍒?鐢ㄦ埛鏄笉鏄湡鐨勫凡缁忓湪鎾斁椤甸噷"
      if (this.playerRouteIndex() >= 0) {
        // 鐪熺殑宸茬粡鍦ㄦ挱鏀鹃〉閲岋紙閲嶅瑙﹀彂锛夆噿 淇濇寔鍘熻涓猴細璁╃粰宸叉湁浼氳瘽
        this.expandState.pushMorphTrace('skip');
        Logger.info(RzdShellLogTag,
          `open morph: skip (already in player; stage=${this.expandState.morphStage})`);
        return false;
      }
      // 娈嬬暀鍨冨溇 + 鐢ㄦ埛纭疄瑕佹墦寮€ 鈬?**鍏堟竻骞插噣鍐嶇户缁?*
      this.expandState.pushMorphTrace('staleClr');
      Logger.warn(RzdShellLogTag,
        `open morph: clearing STALE session (stage=${this.expandState.morphStage} ` +
        `drive=${this.expandState.morphDrive} routeOnStack=0)`);
      this.expandState.morphReset();
    }
    // 鈽呪槄鈽?2026-10-16锛?*鍒ゆ嵁璁㈡锛氱粰"涓婁竴浼氳瘽"琛ヤ竴鏉＄‖鏉′欢**锛夛細
    //   鍘熸潵鍙湁涓婇潰閭ｆ潯 `pullDragging || morphContainerActive()` 瀹堝崼銆備笂涓€杞妸
    //   `aboutToDisappear()` 閲岄偅鍙ユ棤鏉′欢 `morphReset()` 鍔犱簡闂紙"浼氳瘽娲荤潃灏变笉娓?锛変箣鍚庯紝
    //   **浼氳瘽娉勬紡**鍙樻垚鍙兘锛歚morphSessionStarted` 娈嬬暀涓?true锛岃€?`pullDragging` /
    //   `morphContainerActive()` 閮藉凡鏄亣 鈬?涓婇潰閭ｆ潯瀹堝崼**鐪嬩笉瑙佸畠** 鈬?涓嬩竴杞偣鍑?
    //   璇诲埌 `isFreshSession = false` 鈬?璧?鏀惧純浼氳瘽"鍒嗘敮 鈬?**鍙堟病鍔ㄧ敾**銆?
    //
    //   鈬?琛ヤ竴鏉?*纭潯浠?*锛歚playerRouteIndex() < 0`锛堟挱鏀鹃〉璺敱**涓嶅湪**鏍堥噷锛夈€?
    //     鍏ㄥ伐绋?8 澶?`isShowPlay = true` 閮?*涓嶈嚜宸?push**锛宲ush 鍙敱鏈枃浠剁殑
    //     `pushPlayerRoute()` 鍋?鈬?**"璺敱涓嶅湪鏍堥噷"灏辨槸"涓婁竴杞細璇濆凡缁忕粨鏉?鐨勭‖璇佹嵁**
    //     锛堟棤璁烘槸姝ｅ父鍏抽棴杩樻槸琚腑闂存墦鏂級銆?
    //     鈿狅笍 鍞竴瑕佹敞鎰忥細涓婃媺鎵嬪娍鍦?*棣栭〉**璧锋墜鏃惰矾鐢变篃杩樻病 push銆備絾閭ｆ椂
    //       `pullDragging === true` 鈬?涓婇潰閭ｆ潯瀹堝崼浼氬厛 return锛堜笉褰卞搷鎵嬪娍锛夛紱
    //       鑰?鐐瑰嚮鎵撳紑"璧锋墜鏃?`isShowPlay` 鍒氬彉 true銆乣pullDragging` 蹇呬负鍋?
    //       鈬?钀藉埌杩欓噷娓呬竴娆℃槸瀹夊叏鐨勶紙娓呭畬 `pullOpenBegin` 绔嬪埢閲嶅缓锛夈€?
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
    // 鈽呪槄鈽?2026-10-16锛?*璁颁綇"杩欎竴杞槸涓嶆槸鏂颁細璇?**锛屽畠鍐冲畾 `false` 鎬庝箞澶勭悊锛夛細
    //   `pullOpenBegin()` 鎶?`morphSessionStarted` 缃湡鐨勯偅涓€姝ュ氨鏄?浼氳瘽寤虹珛"銆?
    //   鍦ㄥ畠涔嬪墠璇诲埌 false 鈬?杩欐槸**鍏ㄦ柊涓€杞?*锛堢敤鎴风湡鐨勮鎵撳紑鎾斁鍣級銆?
    const isFreshSession: boolean = !this.expandState.morphSessionStarted;
    const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0);
    this.expandState.pushMorphTrace(ok ? 'beginOk' : 'beginNo');
    if (!ok && isFreshSession) {
      // 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮鎵撳紑娌℃湁鍔ㄧ敾"鐨勬渶鍚庝竴鍧楁嫾鍥?*锛夛細
      //   杩欎竴娈靛師鏉ユ槸"`false` 鈬?`pullDragging=false` + `morphReset()` + `morphSettleOpen()`
      //   + `return false`"锛屼篃灏辨槸**鏁存鏀惧純褰㈠彉浼氳瘽**銆?
      //   鈿狅笍 鑰?`pullOpenBegin` 杩斿洖 `false` 鐨?*鍞竴**鍘熷洜鏄?杩欎竴鎷嶉噺涓嶅埌涓滆タ"鈥斺€?
      //   鐐瑰嚮鎵撳紑鏃惰繖**蹇呯劧**鍙戠敓锛堟挱鏀鹃〉杩樻病鎸傝浇銆佸皝闈㈣妭鐐逛笉瀛樺湪锛夛紝
      //   浜庢槸杩欎竴娆℃墦寮€琚案涔呭垽鎴?鍑犱綍娌￠噺鍒?鈬?鏃犲舰鍙樿惤浣?锛?
      //   **杩炰竴娆¤ˉ閲忛兘娌¤瘯杩?*锛堢敤鎴峰疄娴嬨€岀偣鍑绘墦寮€鎾斁鍣ㄦ病鏈夊皝闈?鑳屾櫙鍔ㄧ敾銆嶏級銆?
      //   鏃犵晫鐨勫舰鐘讹紙`MainPage.openPlayerMorph` 149679锛夛細`beginMorphEnter` 杩斿洖 false 鏃?
      //   **涓嶆斁寮?*锛岃€屾槸
      // ```ts
      //     this.enterAnimStarted = false;
      //     ExpandSnapshot.onPullReady = () => { 鈥?};   // 鈫?娉ㄥ唽鍥炶皟锛岀瓑鎾斁椤典笂鎶ュ嚑浣曞啀鎺ョ潃璺?
      // ```
      //   鈬?鎴戜滑鐨勭瓑浠风墿灏辨槸**璁╄ˉ閲忛摼鎺ユ墜**锛氫繚鎸?`ENTERING/FINGER` 涓?`pullDragging`锛?
      //     鐢?`settlePullOpen` 鐨?12脳32ms 琛ラ噺鎶婄粓鐐归噺鍥炴潵锛岄噺鍒伴偅涓€鎷?
      //     锛坄measureMiniDuringPull` 閲岋級鎶?`morphGeomReady` 缃湡銆佸鍣ㄧ涓€娆¤惤浣嶃€?
      //   鈿狅笍 鍙湪 `isFreshSession` 鏃惰繖鏍峰仛锛?*宸茬粡鍦ㄤ細璇濋噷**锛堥噸澶嶈Е鍙?/ 娈嬬暀锛変粛鐒惰蛋鍘熸潵鐨?
      //     淇濆畧鍒嗘敮锛屽厤寰楁妸鐢ㄦ埛姝ｅ湪鐪嬬殑閭ｄ竴杞細璇濇竻鎺夈€?
      this.expandState.pushMorphTrace('awaitGeom');
      Logger.warn(RzdShellLogTag,
        `open morph: geometry not measurable yet 鈬?keep the session and retry ` +
        `(stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive} ` +
        `bigKnown=${this.expandState.bigCoverAnchored()})`);
      return true;
    }
    if (!ok) {
      Logger.warn(RzdShellLogTag,
        'open morph: mini bar / host rect unavailable 鈬?plain landing (no morph)');
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
      this.expandState.pushMorphTrace('noMorph');
      this.expandState.morphStage = MorphStage.OPEN;
      this.expandState.morphP = 1;
      // 内容时间线与几何时间线在静止态必须同值（见 `PlayerExpandState.contentP` 的说明）。
      this.expandState.contentP = 1;
      return false;
    }
    Logger.info(RzdShellLogTag, 'open morph: begin from click entry (align Wujie openPlayerMorph)');
    // 鈽?澹冲眰娴眰閭ｄ竴妫掔殑杩涘害涔熷帇鍥炶捣鐐癸細瀹冪殑闈欐鎬佸垵鍊兼槸 1锛?宸茶惤浣?璇箟锛夛紝
    //   涓嶅帇鍥?0 鐨勮瘽娴眰绗竴甯т細鎸?钀戒綅鐨勫ぇ灏侀潰"鐢讳竴娆★紙= 鍔ㄧ敾閲屽嚭鐜扮浜屽紶灏侀潰锛夈€?
    this.expandState.morphOverlayReset();
    // 鈿狅笍 **涓嶈鍦ㄨ繖閲?*璧锋诞灞傞偅涓€妫掔殑琛ラ棿锛氭鍒?`morphContainerActive()` 杩樻槸鍋?
    //   锛坄pullOpenBegin` 鍙妸鐩镐綅缃垚 ENTERING 鐨勫墠涓€姝ワ級锛宍focusMorphOverlayForPageIntro()`
    //   浼氶潤榛?return銆傛诞灞傜殑鏄惧紡椹卞姩鏀惧湪 `onShowPlayChanged` 閲岋紙鎺ㄨ矾鐢变箣鍚庯級銆?
    return true;
  }

  /** 鎾斁椤佃矾鐢卞湪鏍堥噷鐨勪笅鏍囷紙涓嶅湪鏍堥噷杩斿洖 -1锛夈€?*/
  private playerRouteIndex(): number {
    const names: string[] = this.pageIndexInfos.getAllPathName();
    if (names === undefined || names.length === 0) {
      return -1;
    }
    return names.indexOf(RouterUrlConstants.PLAYER_PAGE);
  }

  /**
   * 鎺ㄥ叆鎾斁椤佃矾鐢便€?
   *
   * 鈿狅笍 绗簩鍙?`animated` **蹇呴』鏄?false**锛氬舰鍙樿嚜宸卞氨鏄姩鐢伙紝绯荤粺杞満浼氬拰瀹冨彔鍔?
   *    锛堟棤鐣?1.2.4 鍏虫帀浜嗗畠锛涘畼鏂广€婂叡浜厓绱犺浆鍦恒€嬫寚鍗楀悓鏍疯姹?`pushPath()` 鍏冲姩鐢伙級銆?
   * `param.pull = true` = 杩欐杩涘叆瑕佽蛋褰㈠彉锛堝鏍囧弽缂栬瘧閲岀殑 `param.pull`锛夈€?
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
   * 绉婚櫎鎾斁椤佃矾鐢憋細鏀惰捣鍔ㄧ敾宸茬粡鐢辨挱鏀鹃〉鎾畬锛岃繖閲屼笉鍐嶅甫绯荤粺杞満銆?
   *
   * 鈿狅笍 涓嶈兘鍐欐垚"鏄爤椤舵墠 pop"锛歚ControlAreaComponent` 閲屽瓨鍦?鍏?`isShowPlay = false`
   *    鍐?`pushPathByName(鑹轰汉椤?鎼滅储椤?`"鐨勫啓娉曪紝涓や釜鍔ㄤ綔鐨勫厛鍚庨『搴忎笉纭畾銆?
   *    鎵€浠ヨ繖閲屾寜**鍚嶅瓧鎵句笅鏍?*鍐嶅垹锛氬畠鍦ㄦ爤椤跺氨 pop锛屼笉鍦ㄦ爤椤跺氨 `removeByIndexes`锛?
   *    涓ょ椤哄簭閮藉緱鍒版纭粨鏋滐紝涔熶笉浼氱暀涓嬩竴鏉″兊灏告挱鏀鹃〉璺敱銆?
   */
  private popPlayerRoute(): void {
    const idx: number = this.playerRouteIndex();
    if (idx < 0) {
      PlaybackPage.ev('REM', 'noIdx');
      return;
    }
    const names: string[] = this.pageIndexInfos.getAllPathName();
    Logger.info(RzdShellLogTag, `route: remove player at index=${idx} (top=${names.length - 1})`);
    // 鈽呪槄鈽?2026-10-16锛?*鍏抽棴杩囩▼榛戝專瀛?路 绗笁绗?*锛夛細璁?璺敱鐪熺殑琚垹鎺変簡"杩欎竴鍒汇€?
    //   涓轰粈涔堝繀椤昏锛氱幇鍦ㄥ叧闂摼璺殑鏀跺熬鏄?*鍚屼竴涓?tick 閲岃繛鐫€鍋?*鐨?鈥斺€?
    //   `isShowPlay=false`锛堚啋 鏈嚱鏁帮紝浣?V2 `@Monitor` 鏄?*寮傛**鍥炶皟锛夆啋 `morphReset()`
    //   锛?*鍚屾**鎶?`morphP` 澶嶄綅鎴?1銆佺浉浣嶆竻鎴?NONE 鈬?瀹瑰櫒涓嶅啀瑁佸壀/缂╂斁 = 婊″睆锛夈€?
    //   鈬?涓よ€呬箣闂村彧瑕侀殧浜嗗摢鎬曚竴甯э紝灞忎笂灏辨槸"宸茬粡缂╂垚灏忓渾鐐逛簡" 鈫?绐佺劧**婊″睆鎾斁椤?*
    //     鈫?鍐嶈 pop 鐨勮浆鍦哄甫璧般€傜敤鎴锋姤鐨勩€屽姩鐢荤粨鏉熶簡**绐佺劧鏉ヤ釜灞曞紑鎾斁鍣ㄧ殑鍔ㄧ敾**銆嶆鏄繖涓舰鐘躲€?
    //   鍒よ锛歚RST` 涓?`REM` 涔嬮棿鐨?`t+` 宸?> ~16ms 鈬?鑷冲皯鏈変竴甯ф弧灞忎腑闂存€?鈬?灏辨槸瀹冦€?
    PlaybackPage.ev('REM', `idx=${idx} top=${names.length - 1}`);
    if (idx === names.length - 1) {
      this.pageIndexInfos.pop(false);
    } else {
      this.pageIndexInfos.removeByIndexes([idx]);
    }
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 涓婃媺鎵撳紑鎾斁椤碉紙璺熸墜锛屽３灞備晶锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // 涓轰粈涔堟墜鍔垮繀椤诲湪**澹冲眰**鑰屼笉鏄挱鏀鹃〉锛氭挱鏀鹃〉鍦?`bindContentCover` 鐨勬ā鎬侀噷锛?
  // 鑰屾ā鎬佸湪 `isShowPlay` 涓?false 鏃?*鏍规湰涓嶅瓨鍦?* 鈥斺€?娌℃寕杞界殑椤甸潰鏀朵笉鍒版墜鎸囦簨浠躲€?
  // 鎵€浠ラ摼璺槸锛?
  //
  //   澹冲眰 onActionStart锛堜粠搴曢儴璧锋墜锛夆啋 鎸傝浇妯℃€侊紙杩涘害 100 = 杩蜂綘鏉￠偅涓€灏忓潡锛?
  //   鈫?澹冲眰 onActionUpdate 鍐?transitionProgress 鈫?鎾斁椤?@Monitor 闀滃儚鎴?collapseProgress
  //   鈫?楂樺害/缂╂斁/浣嶇疆/鍦嗚/閫忔槑搴﹀叏閮ㄨ窡鐫€鎵嬫寚璧?
  //   鈫?澹冲眰 onActionEnd 杩囬槇鍊煎垯琛ラ棿鍒?0锛堝畬鍏ㄥ睍寮€锛夛紝鍚﹀垯琛ラ棿鍒?100 骞跺嵏杞?

  /**
   * 涓婃媺鎵撳紑锛氳捣鎵嬬偣鏄惁钀藉湪銆岃糠浣犳潯閭ｄ竴鏉″甫銆嶉噷锛堣糠浣犳潯 = 閭ｄ釜鎶婃墜锛夈€?
   *
   * 鈿狅笍 鏃ц鍒欐槸銆屼粠灞忓箷涓嬪崐閮ㄥ垎锛堚墺60% 灞忛珮锛夎捣鎵嬪氨鎺ョ銆嶏紝鐢ㄦ埛瀹炴祴锛?026-10-11锛夛細
   *   銆屾垜鐨勯〉鎴戜粠鎾斁鍣ㄤ笂闈竴閮ㄥ垎鐨勪綅缃笂婊戜篃浼氭墦寮€鎾斁鍣紙鍙湁鎴戠殑椤典細鍑虹幇锛夈€嶃€?
   *   鍘熷洜锛氭棫瑙勫垯鎶?*鏁翠釜涓嬪崐灞?*閮藉垝鎴愭媺浼告墜鍔跨殑鐑尯銆傚埆鐨勯〉闈㈠湪閭ｄ竴甯︽濂芥槸闀垮垪琛?/
   *   婊氬姩瑙嗗浘锛岀珫鐩存嫋鍔ㄨ鍒楄〃鍏堝悆鎺夛紝澹冲眰杩欐潯 `.gesture(PanGesture)`锛堝啋娉￠樁娈碉紝浼樺厛绾?
   *   浣庝簬瀛愮粍浠讹級鏍规湰鏀朵笉鍒帮紱鑰屻€屾垜鐨勩€嶉〉鍐呭涓嶆弧涓€灞忥紙鎴栧凡缁忔粴鍒板簳锛夋椂鍒楄〃涓嶆秷璐规嫋鍔紝
   *   浜庢槸鎵嬪娍鍐掓场涓婃潵銆佹挱鏀惧櫒琚『鎵嬫媺寮€ 鈥斺€?鎵€浠ュ彧鏈夊畠銆屾紡銆嶃€?
   *   鏀剁揣鎴愶細璧锋墜鐐瑰繀椤昏惤鍦?*搴曢儴閭ｄ竴鏉″甫**锛堣糠浣犳潯 56 + 搴曢儴閬胯 + 涓婃部浣欓噺锛夊唴銆?
   *   椤甸潰涓銆佸垪琛ㄥ尯鍩熺殑涓婃粦涓€寰嬩氦杩樼粰婊氬姩瑙嗗浘锛堣繖涔熷拰"杩蜂綘鏉℃槸鎶婃墜"鐨勪氦浜掔洿瑙変竴鑷达級銆?
   * @param fingers 璧锋墜鎵嬫寚鍒楄〃锛堢獥鍙ｅ潗鏍?globalY锛寁p锛夈€?
   * @returns 鏄惁鐢卞３灞傛帴绠¤繖娆℃嫋鍔ㄣ€?
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

  /** 涓婃媺寮€濮嬶細杩涘叆 ENTERING 闃舵锛堝彲璺熸墜锛夊苟鎸傝浇鎾斁椤点€?*/
  private onPullOpenStart(fingers: FingerInfo[]): void {
    // 鈽?璇婃柇锛氭柊涓€杞墜鍔垮紑濮?鈬?娓呮帀"鏈鎵嬪娍宸茶杩囦竴娆℃嫆缁?鐨勯椄锛堣 `onPullOpenUpdate`锛夈€?
    this.pullDropCountedThisGesture = false;
    // 鈿狅笍 鎾斁椤靛凡缁忓紑鐫€灏卞埆鎺ョ锛氭挱鏀鹃〉鐜板湪鏄３灞?Stack 閲岀殑鏅€氭诞灞傦紙涓嶅啀鏄ā鎬侊級锛?
    //    澹冲眰杩欐潯鎵嬪娍鍦ㄥ畠涓婇潰渚濈劧鏀跺緱鍒?鈥斺€?涓嶆尅涓€涓嬶紝鐢ㄦ埛鍦ㄦ挱鏀鹃〉閲屼粠涓嬪崐灞忓線涓婃嫋
    //    浼氭妸褰㈠彉杩涘害澶嶄綅鍒?0锛堟挱鏀鹃〉"鍟?鍦扮缉鍥炶糠浣犳潯锛夛紝
    //    鑰屾挱鏀鹃〉鑷繁鐨勪笅鎷夋敹璧锋墜鍔垮悓鏃跺湪璺戯紝涓ゅ鍔ㄧ敾鐩存帴鎵撴灦銆?
    if (this.appState.isShowPlay) {
      return;
    }
    // 鈿狅笍 娈嬬暀鍦?true 鐨?`pullDragging` 浼?*璁╃偣鍑绘墦寮€姘歌繙璺宠繃褰㈠彉鍒濆鍖?*锛堥〉闈㈤偅杈规寜瀹?
    //    鍒ゆ柇"鎵嬫寚姝ｅ湪椹卞姩"锛夈€傝捣鎵嬭繖涓€鍒荤粺涓€娓呬竴娆★紝淇濊瘉姣忔鎵撳紑閮芥槸浠庡共鍑€鐘舵€佸紑濮嬨€?
    this.expandState.pullDragging = false;
    if (!this.pullOpenStartsNearBottom(fingers)) {
      return;
    }
    // 鈽?鍏堥噺涓€娆¤糠浣犳潯涓庡涓荤殑**娓叉煋鐭╁舰**锛坄getRectangleById`锛屽彛寰?px 鈫?vp锛夛細
    //   `onAreaChange` 缁欑殑鏄竷灞€鍑犱綍銆佷笉鍚鍏?transform锛孒DS 娴姩搴曟爮閭ｇ偣鍋忕Щ
    //   浼氳鍔ㄧ敾璧风偣鏁翠綋鍋忥紙鐢ㄦ埛瀹炴祴鐨?浠庡皝闈㈠亸宸︿笅瑙掑紑濮?锛夈€?
    const morphOk: boolean = this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0);
    if (!this.appState.isShowPlay) {
      this.appState.isShowPlay = true;
    }
    if (!morphOk) {
      // 鍑犱綍娌￠噺榻愶紙杩蜂綘鏉℃病鎸傝浇 / 瀹夸富娌″昂瀵革級锛氱洿鎺ラ摵婊★紝鍒‖鍋氬舰鍙?
      // 鈥斺€?纭仛鐨勮瘽鎾斁椤典細琚帇鎴愪竴鏉＄粏缂濓紙瑙?PlayerExpandState.morphUsable锛夈€?
      // 鈽?璇婃柇璁℃暟锛堝窘鏍囩鍗佽 `pd=` 鐨勭涓€涓暟锛夛細杩欎釜鏁版定 鈬?涓婃媺**娌℃湁璺熸墜鍔ㄧ敾**锛?
      //   鍘熷洜鏄?璧锋墜閭ｄ竴鍒诲嚑浣曟病閲忛綈"锛屼笌 `pullDragging` 閭ｆ潯璺棤鍏筹紙瑙?`pullDropBegin`锛夈€?
      this.expandState.notePullDropBegin();
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
      this.expandState.morphSettleOpen();
      return;
    }
    // 鈽?璧锋墜閭ｄ竴鍒绘挱鏀鹃〉鍒氭寕杞斤紝"缁灏侀潰"鐨勭粓鐐癸紙瀹冪殑澶у皝闈級杩橀噺涓嶅埌 鈥斺€?琛ラ噺銆?
    //   涓庤糠浣犳潯鑷繁閭ｆ潯鎵嬪娍閲岀殑琛ラ噺鍚屼竴濂楃獥鍙ｏ紙12 脳 32ms锛屽鏍囧弽缂栬瘧 `onPullReady`锛夈€?
    this.schedulePullAnchorRemeasure(0);
    // 鈽?澹冲眰娴眰閭ｄ竴妫掞紙`MorphCoverClone`锛変篃鍘嬪洖璧风偣銆傚畠鐨勮繘搴?`morphOverlayP`
    //   闈欐鎬佸垵鍊兼槸 1锛?宸茬粡鍦ㄨ惤浣?鐨勮涔夛級锛屼笉鍘嬪洖 0 鐨勮瘽娴眰绗竴甯т細鐢绘垚澶у皝闈€?
    this.expandState.morphOverlayReset();
  }

  /**
   * 璺熸墜鏈熼棿琛ラ噺"缁灏侀潰"鐨勭粓鐐归敋鐐癸紙鎾斁椤靛ぇ灏侀潰锛夈€?
   *
   * 鈿狅笍 `attempt` **蹇呴』甯﹂粯璁ゅ€?`0`**锛屽苟涓旇鎸′綇 `undefined`/`NaN`锛?
   * `attempt >= PULL_ANCHOR_RETRY_MAX` 瀵?`undefined` 鍜?`NaN` **閮芥槸 false**锛?
   * 浜庢槸鏃犲弬璋冪敤锛堟垨鏌愪竴灞備紶浜?`attempt + 1` 绠楀嚭 NaN锛変細璁╄繖鏉?32ms 閫掑綊**姘镐笉鍋滄**
   * 锛坄features/playlist` 鐨勫彟涓や唤鍓湰鍘熸潵灏辨槸杩欎釜褰㈢姸锛?026-10-15 宸插榻愶紱瑙佹棤鐣屽悓姝?搂72锛夈€?
   * @param attempt 宸插皾璇曟鏁?
   */
  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (!Number.isFinite(attempt) || attempt >= PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    setTimeout((): void => {
      // 鈽呪槄鈽?2026-10-16锛?*鍚屼竴褰㈢姸鐨勭 4 澶?*锛歚morphGenAlive` 瀹堝崼 鈥斺€?鍓?3 澶勫凡鍦?搂102/搂104 淇繃锛?
      //   杩欓噷鍘熸潵鏄?`if (!pullDragging || !morphGenAlive(gen)) return;`锛屽叾涓?
      //   `gen` 鏄?*鍙戣捣閭ｄ竴鍒?*鎹曡幏鐨?`morphGen`銆?
      //
      // ## 涓轰粈涔堝畠鍦ㄧ偣鍑昏繖鏉¤矾涓婃槸閿欑殑
      //   `morphGen` 鐨勮涔夋槸"杩欎竴杞舰鍙樹細璇濈殑缂栧彿"锛屽畠琚?`morphReset()` **鎺ㄩ珮**銆?
      //   鑰岀偣鍑绘墦寮€鏃讹紝`pushPath` 浼氳**鏃ч〉闈㈠疄渚嬪嵏杞?*锛屾棫瀹炰緥鐨?`onDisAppear` 浼氳蛋
      //   锛堥偅鏉¤矾涓婄洰鍓嶅彧鏈?`morphUsable` 涓虹湡灏辫烦杩?杩欎竴灞備繚鎶わ紝瑙?`PlaybackPage.onDisAppear`锛?
      //   鈥斺€?涓€鏃﹀畠鐪熺殑璋冨埌浜?`morphReset()`锛屾湰鍑芥暟鐨勪笘浠ｅ彿绔嬪埢杩囨湡
      //   鈬?**姣忎竴鎷嶉兘鍦ㄧ 2 琛岄潤榛?return**锛堜笉鍐欐棩蹇楋紝鏌ヤ笉鍑烘潵锛夈€?
      //   杩欎笌 搂102 淇帀鐨勩€佷互鍙?搂104 淇殑**瀹屽叏鍚屼竴涓舰鐘?*锛?
      //     > 鐢?浼氳瘽缂栧彿"鍘诲垽"鐢ㄦ埛杩樻兂涓嶆兂鐪嬫挱鏀鹃〉" 鈥斺€?涓よ€呮棤鍏炽€?
      //
      // ## 鏀规硶锛堝垽鎹崲鎴愭洿鏃┿€佹洿鐩存帴鐨勪簨瀹烇級
      //   `pullDragging` 琛ㄧず"杩欎竴杞窡鎵?鏀跺熬杩樻病璧板畬"锛坄settlePullOpen` 浼氫竴鐩翠繚鎸佸畠锛?
      //   鐩村埌琛ラ棿璧疯窇閭ｄ竴鍒绘墠缃?false锛夆€斺€?杩欐鏄?杩樿涓嶈缁х画琛ラ噺"鐨勭湡鍒ゆ嵁銆?
      //   涓栦唬鍙峰湪杩欓噷娌℃湁浠讳綍姝ｇ‘鐢ㄩ€旓細琛ラ噺鍙渶瑕?鍑犱綍杩樻病榻?+ 鐢ㄦ埛杩樺湪绛?銆?
      //   鈬?鍘绘帀 `gen`锛屽彧鍒?`pullDragging`锛涘啀琛ヤ竴鏉?`isShowPlay`锛堢敤鎴峰凡绂诲紑灏卞埆閲忎簡锛夈€?
      if (!this.expandState.pullDragging) {
        return;
      }
      // 鐢ㄦ埛宸茬粡绂诲紑鎾斁椤碉紙`popPath` 閭ｆ潯璺級鈬?鍐嶈ˉ閲忎篃娌′汉鐪嬶紝鏀跺伐銆?
      // 鈿狅笍 鍒ゆ嵁鐢?`isShowPlay` 鑰?*涓嶆槸**涓栦唬鍙凤紙涓栦唬鍙蜂細琚棤鍏崇殑浜嬫帹楂橈紝瑙佷笂闈㈤偅娈碉級銆?
      if (!this.appState.isShowPlay) {
        return;
      }
      if (this.expandState.measureMiniDuringPull(this.getUIContext(), this.navDepth > 0)) {
        return;
      }
      this.schedulePullAnchorRemeasure(attempt + 1);
    }, PULL_ANCHOR_RETRY_MS);
  }

  /** 璺熸墜鏇存柊锛氫綅绉?鈫?杩涘害 0鈥?锛?*绾挎€?*锛岃窡鎵嬮樁娈典笉鍔犵紦鍔級銆?*/
  private onPullOpenUpdate(offsetY: number): void {
    if (!this.expandState.pullDragging) {
      // 鈽?璇婃柇璁℃暟锛堝窘鏍囩鍗佽 `pd=` 鐨勪腑闂撮偅涓暟锛夆€斺€?瑙?`PlayerExpandState.pullDropUpdate`锛?
      //   "鎵嬫寚鍦ㄥ姩浣嗚繘搴︿笉璺?鏃讹紝杩欎釜鏁颁細娑紝骞惰鏄庢槸**鍒ゆ嵁**鎷掔殑锛堣€屼笉鏄簨浠舵病鍒帮級銆?
      // 鈿狅笍 **涓€娆℃墜鍔垮彧璁颁竴娆?*锛氭湰鍑芥暟鐢辨瘡涓?`onActionUpdate` 璋冪敤锛堚増60~120 娆?绉掞級锛?
      //   鑰岃鏁板啓鐨勬槸 `@Trace` 瀛楁 鈬?姣忔閮藉啓浼氳寰芥爣閭ｄ釜 `Text` 姣忓抚閲嶅缓锛?
      //   鎭板ソ鎶?鎵嬫劅"鎼呮祽锛堣瘖鏂湰韬彉鎴愬共鎵版簮锛夈€傝瘖鏂彧闇€瑕?杩欎竴杞湁娌℃湁琚嫆"杩欎竴涓簨瀹炪€?
      if (!this.pullDropCountedThisGesture) {
        this.pullDropCountedThisGesture = true;
        this.expandState.notePullDropUpdate();
      }
      return;
    }
    this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(offsetY));
    // 鈽?鎵嬫寚璺熸墜閭ｆ潯璺笂锛屾诞灞傛嫹璐濈殑杩涘害涓庢挱鏀鹃〉杩涘害**涓€姣斾竴鍚屾**锛堜笉璺戣ˉ闂达級锛?
    //   涓ゅ眰鍦ㄨ窡鎵嬫湡蹇呴』鏄悓涓€涓€硷紝鍚﹀垯鏉炬墜琛ラ棿鏃朵細鍏?璺?鍒版诞灞傝嚜宸遍偅涓繘搴︿笂銆?
    //   涓ゆ潯鎵嬪娍锛堝３灞傝繖鏉?+ 杩蜂綘鏉￠偅鏉★級閮藉啓 `morphP`锛屾墍浠ユ诞灞傚繀椤?*璺熺潃 morphP 璧?*
    //   鑰屼笉鏄瓑鏌愪釜鍏ュ彛鍘昏 鈥斺€?杩欐牱涓嶇鍝潯鎵嬪娍鎺ュ埌鐨勯兘鑳藉涓娿€?
    this.expandState.syncMorphOverlayFromPage();
  }

  /**
   * 鏉炬墜锛?*鎻愪氦鍒ゆ嵁浜ょ粰 `PlayerExpandState.pullOpenShouldCommit()`**锛堟竻鍗?搂涓€ 1.2
   * 銆岃繘搴?OR 閫熷害銆嶏級鈥斺€?杩囬槇鍊硷紙鎴栧揩閫熶笂鐢╋級琛ラ棿鍒?1锛堝睍寮€锛夛紝鍚﹀垯鍥炲埌 0 骞跺嵏杞姐€?
   *
   * 鈿狅笍 杩欓噷**涓嶈鍐嶅啓 `morphP >= 0.45`**锛氶偅鏉″垽鎹師鏉ュ湪涓変釜鏂囦欢閲屽悇鍐欎簡涓€閬?
   *    锛堟湰鏂囦欢 + 涓や釜杩蜂綘鏉★級锛屾敹鏁涘埌 `PlayerExpandState` 涓€澶勪箣鍚庯紝
   *    鏀归槇鍊煎彧鏀归偅涓€涓父閲忥紝涓嶄細鍑虹幇"涓ゆ潯鎵嬪娍涓寸晫鍊间笉涓€鏍?銆?
   * @param offsetY 鏉炬墜鏃剁殑绔栫洿浣嶇Щ锛坴p锛屼笂鎷変负璐燂級鈥斺€?鍙敤鏉ュ垽**鏂瑰悜**
   * @param velocityY 鏉炬墜鏃剁殑绔栫洿閫熷害锛坄GestureEvent.velocityY`锛夆€斺€?鍙敤鏉ュ垽**蹇敥**
   */
  private onPullOpenEnd(offsetY: number, velocityY: number): void {
    if (!this.expandState.pullDragging) {
      // 鈽?璇婃柇璁℃暟锛堝窘鏍囩鍗佽 `pd=` 鐨勬渶鍚庨偅涓暟锛夆€斺€?瑙?`PlayerExpandState.pullDropEnd`銆?
      this.expandState.notePullDropEnd();
      return;
    }
    this.settlePullOpen(
      this.expandState.pullOpenShouldCommit(this.expandState.morphP, offsetY, velocityY));
  }

  /**
   * 杩蜂綘鏉¤嚜宸遍偅鏉℃墜鍔垮彂鏉ョ殑鏀跺熬璇锋眰锛堟澗鎵嬫椂瀹冨彧鍙戣姹傦紝琛ラ棿鐢卞３灞傛挱 鈥斺€?瑙?
   * `PlayerExpandState.requestPullOpenSettle`锛夈€?
   */
  @Monitor('expandState.pullSettleVersion')
  onPullSettleRequested(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    this.settlePullOpen(this.expandState.pullSettleCommit);
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 澹冲眰娴眰閭ｄ竴妫掞紙缁灏侀潰锛夌殑**鐙珛鏃堕棿绾?*锛?60ms锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // 缁撴瀯锛堝鏍囨棤鐣?1.2.4 鐨?`MainPage.MorphOverlayHost`锛夛細
  //   路 涓?灞?= 鎾斁椤佃嚜宸憋細`morphP`锛?*350ms `Curve.EaseInOut`**锛堜竴澶勬病鍔級锛?
  //   路 涓?灞?= **澹冲眰娴眰**锛坄MorphCoverClone()`锛夛細`morphOverlayP`锛?*560ms + 蹇嚭鎱㈡敹**銆?
  //
  // 涓轰粈涔堢敤 `@Monitor` 鍘昏拷銆屾挱鏀鹃〉閭ｄ竴灞傚紑濮嬫挱浜嗐€嶏細
  //   鐐瑰嚮鎵撳紑閭ｆ潯璺殑琛ラ棿鍦ㄦ挱鏀鹃〉閲岋紙`PlaybackPage.playMorphOpenIntro`锛夛紝
  //   鑰?*鎾斁椤电殑 350ms 鏄槑浠や笉璁稿姩鐨?*锛沗@Monitor` 鏄?V2 鐨?*寮傛鐩戝惉**锛?
  //   鍥炶皟钀藉湪鎾斁椤甸偅娆＄姸鎬佸啓鍏ョ殑鍚屼竴杞噷 鈬?涓ゅ眰"鍚岃捣"锛屾挱鏀鹃〉涓€琛岄兘涓嶇敤鏀广€?
  //   涓ゆ潯璺悇鑷懡涓竴涓瓧娈碉細
  //     路 鐐瑰嚮鎵撳紑 鈫?`morphDrive` 鍙樻垚 `ANIM`锛坄playMorphOpenIntro` 绗竴琛岋級锛?
  //     路 棣栭〉/浜岀骇椤佃繑鍥炪€佷笅鎷夋彁浜?鈫?`morphStage` 鍙樻垚 `LEAVING`锛坄morphBeginLeaving`锛夈€?
  //   鈿狅笍 鎵嬫寚璺熸墜閭ｆ潯璺?*涓嶈蛋杩欓噷**锛堝畠鍦?`onPullOpenUpdate` 閲屼竴姣斾竴鍚屾锛夛紝
  //      鎵€浠ヨ繖閲屼笉蹇呭垽 `pullDragging`銆?

  /** 鎾斁椤靛紑濮?*灞曞紑**琛ラ棿 鈬?娴眰杩欎竴灞備篃璧疯嚜宸遍偅 560ms銆?*/
  @Monitor('expandState.morphDrive')
  onMorphDriveChanged(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    // 鈽?2026-10-17 鐜板満璇绘暟锛氳繖涓€鏀埌搴曟湁娌℃湁琚嚜宸辩殑瀹堝崼鎸′綇锛坄own=1` = 璁╃粰澹冲眰閭ｆ潯锛?
    PlaybackPage.ev('OVI', `drive=${this.expandState.morphDrive} stage=${this.expandState.morphStage} ` +
      `p=${this.expandState.morphOverlayProgress().toFixed(3)} own=${this.shellOwnsOverlayTween ? 1 : 0}`);
    // 鈿狅笍 澹冲眰鑷繁鍒氳捣杩囨诞灞傝ˉ闂达紙`settlePullOpen`锛夋椂**璁╃粰瀹?*锛?
    //    鍚﹀垯鏉炬墜"娌¤繃闃堝€?閭ｆ潯璺細琚繖閲屽弽鍚戣鐩?鈥斺€?澹冲眰鍦ㄦ妸娴眰琛ュ埌 0锛堝洖寮癸級锛?
    //    鑰岃繖閲屽張琛ュ埌 1锛屼袱灞傛柟鍚戠浉鍙嶃€佽鎰熸槸"灏侀潰涓嶈偗鍥炲幓"銆?
    if (this.shellOwnsOverlayTween) {
      return;
    }
    this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
  }

  /** 鎾斁椤靛紑濮?*鏀惰捣** 鈬?娴眰杩欎竴灞備篃鎸夎嚜宸遍偅 560ms 鏀跺洖璧风偣銆?*/
  @Monitor('expandState.morphStage')
  onMorphStageChanged(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    if (this.expandState.morphStage !== MorphStage.LEAVING) {
      return;
    }
    // 鈽?2026-10-17 鐜板満璇绘暟锛氭敹璧疯繖涓€鏀殑娴眰杩涘害涓?鏄惁宸茶鍗犵敤"
    PlaybackPage.ev('OVC', `stage=${this.expandState.morphStage} ` +
      `p=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
      `bridging=${this.expandState.morphOverlayBridging() ? 1 : 0}`);
    this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
  }

  /**
   * 鏀跺熬琛ラ棿锛歝ommit = 鎺ㄥ埌閾烘弧骞惰惤瀹氾紱鍚﹀垯琛ラ棿鍥炶捣鐐广€佷氦杩樿糠浣犳潯銆佸嵏杞芥挱鏀鹃〉銆?
   *
   * 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮鎵撳紑娌℃湁灏侀潰/鑳屾櫙鍔ㄧ敾"鐨勭湡鏂偣**锛夛細
   *   鍘熸潵鐨勯噸璇曞垎鏀暱杩欐牱锛?
   * ```ts
   *   if (!morphUsable) {
   *     pullDragging = true; morphDrive = FINGER;
   *     if (!measureMiniDuringPull(鈥?) { 鈥﹂噸璇?鏀惧純鈥? return; }   // 鈫?澶辫触鎵?return
   *     // 琛ラ噺鎴愬姛 鈬?鎺夊嚭 if锛?*钀藉埌涓嬮潰璧疯ˉ闂?* 鉁?
   *   }
   * ```
   *   鐪嬬潃娌￠棶棰橈紝**浣嗚繖鏉?`return` 鍦ㄥ灞?*锛坄if (!morphUsable)` 閭ｄ竴灞傦級鈥斺€?
   *   鎴戣婧愮爜鏃跺厛鐪嬫垚浜?鎴愬姛涔?return"銆傚璇荤‘璁わ細**琛ラ噺鎴愬姛鍚庣‘瀹炰細钀藉埌璧疯ˉ闂撮偅涓€娈?*锛?
   *   鎵€浠ヨ繖鏉′笉鏄柇鐐广€傦紙鐣欒繖娈垫敞閲婃槸涓轰簡璁颁笅"鎴戜竴搴﹁鍒よ繃涓€娆?銆傦級
   *
   * 鈿狅笍 鐪熸瑕佽鐨勬槸锛?*杩欐潯閲嶈瘯閾撅紙12脳32ms锛夋槸鐐瑰嚮璺緞鍞竴鑳芥妸 `morphUsable` 鍙樼湡鐨勫湴鏂?*
   *   鈥斺€?鐐瑰嚮鏃?`pullOpenBegin` 璺戝湪"鎾斁椤佃繕娌℃寕杞?閭ｄ竴鍒伙紝缁堢偣閿氱偣蹇呯劧閲忎笉鍒般€?
   *   鎵€浠?`morphUsable` 鍙樼湡涔嬪悗**蹇呴』**鏈変笢瑗挎妸娴眰閭ｄ竴妫掍篃璧疯捣鏉ワ紱
   *   鎾斁椤典晶鐨?`onAppear` 琛ラ噺锛坄PlaybackPage` 搂96.1锛変笌杩欓噷鐨勯噸璇曟槸**涓ゆ潯骞惰璺緞**锛?
   *   璋佸厛鎴愬姛閮界敱鍚勮嚜璐熻矗璧锋锛堝箓绛夛紝閲嶅璋冪敤瀹夊叏锛夈€?
   * @param commit 鏄惁鎻愪氦灞曞紑
   */
  private settlePullOpen(commit: boolean, attempt: number = 0): void {
    this.expandState.pushMorphTrace(`settle${attempt}${commit ? 'C' : 'A'}`);
    // 鈽呪槄鈽?2026-10-16锛?*琛ラ噺閾剧殑闂ㄦ崲浜嗕釜閲?*锛夛細鍘熸潵鏄?`if (!morphUsable)`銆?
    //   `morphUsable` 鏄?`morphInitParams()` 鐨?绠楀嚭鏉ヤ簡"锛堜細鍥犱负閫€鍥?`onAreaChange`
    //   鍏滃簳鍊笺€佺敋鑷充笂涓€杞暀涓嬬殑鍊艰€屼负鐪燂級鈬?鐢ㄥ畠褰?杩樿涓嶈琛ラ噺"鐨勫垽鎹紝琛ラ噺閾句細
    //   **鎻愬墠鏀跺伐**锛岃€岀湡姝ｈ鍒ょ殑鏄?**缁堢偣閿氱偣杩欐鍒板簳閲忓埌娌℃湁**"銆?
    //   鈬?鎹㈡垚 `morphEndAnchorReady()`锛涚湡姝ｇ殑"鍙互钀戒綅"闂ㄦ槸 `morphGeomReadyNow()`銆?
    if (!this.expandState.morphUsable || !this.expandState.morphEndAnchorReady()) {
      // 蹇€熸澗鎵嬩篃瑕佸畬鎴愬師灏哄閿氱偣琛ラ噺锛涗笉鑳藉厛鍒?ANIM 瀵艰嚧琛ラ噺鍋滄銆?
      this.expandState.pullDragging = true;
      this.expandState.morphDrive = MorphDrive.FINGER;
      // 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮/杩斿洖娌℃湁鍔ㄧ敾"鐨勬渶鍚庝竴鏉″洜鏋滈摼**锛夛細
      //   杩欎竴娈靛厛鍋氫袱姝?*鎶㈡晳**锛屽啀鍋氬師鏉ラ偅娆¤ˉ閲忥紙椤哄簭寰堥噸瑕侊級锛?
      //   鈶?鑻?褰㈠彉浼氳瘽"宸茬粡琚竻鎺夛紙`morphSessionStarted === false`锛夆€斺€?
      //      鍏稿瀷鏉ユ簮锛氭挱鏀鹃〉鎸傝浇閭ｄ竴鍒伙紝**鏃ч〉闈㈠疄渚嬬殑 `onDisappear`** 瑙﹀彂浜?
      //      鏃犳潯浠剁殑 `morphReset()`锛坄morphGen++`銆乣morphUsable=false`銆?
      //      **`morphSessionStarted=false`**锛夆€斺€?灏卞厛**閲嶆柊璧蜂竴娆″叆鍙?*锛?
      //      鎶?`stage/drive` 鎽嗗洖 `ENTERING/FINGER`锛?
      //   鈶?鐒跺悗璋冨師鏉ラ偅娆?`measureMiniDuringPull` 琛ラ噺锛堝畠瑕佹眰 `stage=ENTERING &&
      //      drive=FINGER`锛屾墍浠モ憼蹇呴』鍦ㄥ墠锛夈€?
      //   鈿狅笍 椤哄簭鍙嶄簡 鈬?琛ラ噺鐩存帴琚畧鍗嫤鎺夛紙闈欓粯杩斿洖 false锛夆噿 閲嶈瘯 12 娆″叏搴熴€?
      if (!this.expandState.morphSessionStarted) {
        this.expandState.pushMorphTrace('reEnter');
        Logger.info(RzdShellLogTag,
          `pull settle: re-enter morph session (was reset by an onDisappear) attempt=${attempt}`);
        if (!this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0)) {
          // 鍑犱綍杩樻槸閲忎笉鍒帮細淇濇寔 `ENTERING/FINGER`锛岃涓嬮潰鐨勮ˉ閲忔彁鍓?return 鍘绘帓闃熼噸璇?
          this.expandState.pullDragging = true;
          this.expandState.morphDrive = MorphDrive.FINGER;
        }
      }
      if (!this.expandState.measureMiniDuringPull(this.getUIContext(), this.navDepth > 0)) {
        if (attempt < PULL_ANCHOR_RETRY_MAX) {
          setTimeout((): void => {
            // 鈽呪槄鈽?2026-10-16锛?*"鐐瑰嚮/杩斿洖娌℃湁鍔ㄧ敾"鐨勬渶鍚庝竴鏉″洜鏋滈摼**锛夛細
            //   杩欓噷鍘熸潵鏄?`if (isShowPlay && morphGenAlive(pendingGen))`銆?
            //   鈿狅笍 `morphGenAlive` 鍦ㄦ湰鍦烘櫙涓?*蹇呯劧涓哄亣**锛屼簬鏄暣鏉￠噸璇曢摼鍦ㄧ 1 鎷嶅氨鏂帀銆?
            //   鈬?淇硶锛?*瀹堝崼涓嶈鎸備笘浠ｅ彿**銆備笘浠ｅ彿鍦ㄨ繖閲岀殑璇箟鏄?杩欎竴杞細璇濇槸鍚﹁繕鏈夋晥"锛?
            //     鑰?鐢ㄦ埛杩樺湪鎾斁椤?锛坄isShowPlay`锛夋墠鏄湡姝ｇ殑鏈夋晥鎬у垽鎹紱
            //     涓€旇 `morphReset()` 娓呰繃涓€娆★紝閲嶈瘯鎺ョ潃鎶婂嚑浣曢噺鍥炴潵鍗冲彲銆?
            //     鈿狅笍 鍙湪 `!isShowPlay`锛堢敤鎴峰凡缁忕寮€鎾斁椤碉級鏃舵墠鏀惧純銆?
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
          // 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫鎶?鍑犱綍姘歌繙娌￠噺鍒?褰撻€€鍖栬矾寰?*锛夛細
          //   杩欐鍘熸潵鏄?`morphReset()` + commit 鏃跺啀 `morphSettleOpen()`"鈥斺€?
          //   鑷浉鐭涚浘锛歚morphReset()` 鎶婂嚑浣曟竻鎴愭亽绛夛紙`morphUsable = false`锛夛紝
          //   绱ф帴鐫€鐨?`morphSettleOpen()` 鍐呴儴 `applyMorphProgress(1)` 鍙堝洜涓?
          //   `morphGeomReady` 涓哄亣鑰?*浠€涔堥兘涓嶅仛** 鈬?瀹瑰櫒鍋滃湪鎭掔瓑銆佺浉浣嶅嵈鏄?OPEN銆?
          //   鏃犵晫鐨勫彛寰勬洿骞插噣锛坄wujie.pa` 鐨?`pickCapsuleRect` 閭ｆ锛氶噺涓嶅埌灏?
          //   銆?*鏈閫€鍥炴櫘閫?push(鏃犲舰鍙?**銆嶏級锛?*閲忎笉鍒板氨褰诲簳涓嶈杩欏鍔ㄧ敾**锛?
          //   璁╂挱鏀鹃〉浠ユ亽绛夊嚑浣曘€丱PEN 鐩镐綅姝ｅ父鏄剧ず锛岃€屼笉鏄暀涓€涓崐姝荤殑褰㈠彉浼氳瘽銆?
          this.expandState.pushMorphTrace('noGeom');
          this.expandState.morphReset();
          this.expandState.morphStage = MorphStage.OPEN;
          this.expandState.morphP = 1;
          // 同值落位（`contentP` = 上游 `PlayerPage.pullT` ≡ `MainPage.morphT`）。
          this.expandState.contentP = 1;
          if (!commit) {
            this.appState.isShowPlay = false;
          }
        }
        return;
      }
      // 琛ラ噺鎴愬姛 鈬?鏁呮剰**涓?return**锛岃惤涓嬪幓璧烽偅涓ゆ潯琛ラ棿锛堣涓婇潰閭ｆ娉ㄩ噴锛夈€?
      this.expandState.pushMorphTrace('measOk');
      Logger.info(RzdShellLogTag,
        `pull settle: remeasured at attempt=${attempt} usable=${this.expandState.morphUsable} ` +
        `stage=${this.expandState.morphStage}`);
    }
    const duration: number = commit ? PULL_OPEN_SETTLE_MS : PULL_OPEN_ABORT_MS;
    // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`MorphGuard.animateMorph` 鐨勭涓€鍙ワ級锛氭妸"閰嶈壊瀹夐潤绐楀彛"
    //   鎺ㄥ埌**杩欐潯琛ラ棿缁撴潫**锛坄quietMs` 鐢ㄨˉ闂磋嚜宸辩殑鏃堕暱 鈥斺€?鏃犵晫閭ｄ晶涔熸槸鎸夎皟鐢ㄧ偣浼犵殑锛?
    //   鏈娌℃湁浠讳綍鏂伴€犲父閲忥級銆傗噿 灞曞紑鍔ㄧ敾璺戠潃鐨勬椂鍊?涓婅壊"寰€鍚庢尓锛屼笉浼氬湪鍔ㄧ敾涓€旇烦鑹?
    //   锛堝彇鑹叉槸寮傛鐨勶紝鎹㈡瓕閭ｄ竴鎷嶅畠鏋佸彲鑳芥濂借惤鍦ㄥ睍寮€鍔ㄧ敾涓棿锛夈€?
    this.expandState.markMorphQuiet(duration);
    this.expandState.pushMorphTrace('tween');
    this.expandState.pullDragging = false;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // 鈽呪槄 娴眰鎷疯礉杩欎竴灞傝蛋**瀹冭嚜宸?*鐨勬椂闀?鏇茬嚎锛?60ms + 蹇嚭鎱㈡敹锛屽鏍囨棤鐣?`animateMorphT`锛夛紝
    //   涓庝笅闈㈣繖鏉?300/180ms 鐨?*鎾斁椤?*琛ラ棿**鍚岃捣**锛堝悓涓€甯с€佸悓涓€涓换鍔￠噷涓や釜 `animateTo`锛夈€?
    //   鈿狅笍 鎾斁椤甸偅鏉?*鍙︽湁涓€濂楁暟鍊?*锛歚PULL_OPEN_SETTLE_MS` / `PULL_OPEN_ABORT_MS`
    //      锛?026-10-15 璧?= 鏃犵晫 `SETTLE_MS` 400 / 400锛岃閭ｄ袱涓父閲忕殑娉ㄩ噴锛夈€?
    //   璧风偣鍙栨诞灞?*褰撳墠**杩涘害锛堣窡鎵嬪仠鍦ㄥ摢鍎垮氨浠庡摢鍎挎帴鐫€璧帮級銆?
    this.expandState.morphOverlayTweenTo(commit, this.getUIContext());
    // 鈽?2026-10-17锛?*娴眰杩欎竴妫掔殑鐜板満璇绘暟** 鈥斺€?鐢ㄦ埛銆屽皝闈㈣窡鐫€鎾斁鍣ㄨ蛋銆佹病鏈夌嫭绔嬮琛屻€嶅畾鎬х敤锛?
    //   `from=` 鏄繖涓€妫?*璧锋墜閭ｄ竴鍒?*鐨勬诞灞傝繘搴︼紱`p=` 鏄挱鏀鹃〉杩涘害锛?
    //   鑻?`from=0` 鑰?commit=1 鈬?瀹冩湰璇ヤ粠杩蜂綘鏉″渾鍦堥鍒版挱鏀鹃〉灏侀潰锛?鈫?锛夛紱
    //   鑻?`from=1` 鈬?宸茬粡璐村湪澶у皝闈綅缃紙琛ラ棿浼氳 `|to-from|<1e-4` 鏃╅€€鎺夛紝绛変簬**涓嶉**锛夈€?
    PlaybackPage.ev('OVS', `commit=${commit ? 1 : 0} from=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
      `p=${this.expandState.morphP.toFixed(2)} bridging=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
      `host=${this.expandState.hostsMorphOverlay() ? 1 : 0}`);
    // 鏍囪"娴眰杩欎竴妫掔殑琛ラ棿鐢卞３灞傚彂璧?锛歚@Monitor('expandState.morphDrive')` 鍦ㄤ笅闈㈤偅琛?
    // 鎶?drive 缃垚 ANIM 涔嬪悗**涔熶細**琚Е鍙戯紝娌℃湁杩欎釜鏍囪鐨勮瘽瀹冧細鍐嶈捣涓€鏉?*鏂瑰悜鍙兘鐩稿弽**鐨?
    // 娴眰琛ラ棿锛堝洖寮归偅鏉¤矾姝ｆ槸濡傛锛夈€傛爣璁板湪琛ラ棿缁撴潫/琚柊琛ラ棿鍙栦唬鏃舵竻鎺夈€?
    this.shellOwnsOverlayTween = true;
    setTimeout((): void => {
      this.shellOwnsOverlayTween = false;
    }, PlayerExpandState.MORPH_OVERLAY_DURATION_MS + 20);
    // 鈽?2026-10-16锛氳繖閲屽師鏉ヨ繕鎹曡幏浜嗕竴涓?`gen` 渚涗袱澶勫畧鍗敤锛涢偅涓ゅ瀹堝崼宸叉寜 搂102/搂103
    //   鏀规垚鍒?`isShowPlay`锛堜笘浠ｅ彿浼氳"鏃у疄渚嬪嵏杞界殑 morphReset"鎺ㄩ珮锛屼笌鐢ㄦ埛鎰忓浘鏃犲叧锛?
    //   鈬?`gen` 涓嶅啀闇€瑕侊紝鍒犳帀澹版槑锛圓rkTS 瀵规湭浣跨敤鐨勫眬閮ㄥ彉閲忚緝涓ユ牸锛岀暀鐫€浼氳闈欐€佸憡璀︼級銆?
    this.getUIContext().animateTo({
      // 鏃犵晫 Tokens 鐨勬爣鍑嗘椂闀匡細180ms 寰氦浜?/ 300ms 涓昏浆鍦?
      duration: duration,
      curve: curves.cubicBezierCurve(commit ? 0.23 : 0.68, 1.0, commit ? 0.32 : 0.77, 1.0)
    }, (): void => {
      this.expandState.applyMorphProgress(commit ? 1 : 0);
    });
    if (commit) {
      // 鈿狅笍 鐩镐綅鍦?*琛ラ棿涔嬪**鏀癸細`morphSettleOpen()` 浼氭妸"鏄惁瑁佸壀"缈绘垚 false锛?
      //    鏀捐繘 animateTo 闂寘閲屼細璁╄繖绉嶇鏁ｅ睘鎬т篃鍘诲悆琛ラ棿銆?
      setTimeout((): void => {
        // 鈽呪槄鈽?2026-10-16锛?*鍚屼竴鏉″洜鏋滈摼鐨勭鍥涘**锛夛細
        //   杩欓噷鍘熸潵鏄?`if (isShowPlay && morphGenAlive(gen))`銆?*涓庨噸璇曢偅鏉″畧鍗悓涓€涓瘺鐥?*锛?
        //   `morphGen` 浼氳"鏃ч〉闈㈠疄渚嬬殑 `onDisappear` 鏃犳潯浠?`morphReset()`"鎺ㄩ珮锛?
        //   鑰岄偅涓師鍥犱笌"鐢ㄦ埛杩樻兂涓嶆兂鐪嬫挱鏀鹃〉"姣棤鍏崇郴銆?
        //   鈬?涓€鏃﹀畠鍙橈紝`morphSettleOpen()` 琚烦杩?鈬?**鐩镐綅鍋滃湪 ENTERING銆乣morphUsable` 淇濇寔鐪?*
        //     鈬?`morphClipping()` 鎭掔湡 鈬?瀹瑰櫒涓€鐩村仠鍦ㄦ渶鍚庨偅涓€甯х殑 `scale/translate/clip`
        //     鈬?瑙傛劅灏辨槸銆?*鑳屾櫙鏁村睆銆佸皝闈綅缃笉瀵?*銆嶃€?
        //   鈬?鏀规硶锛氬彧鍒?`isShowPlay`锛涘啀琛ヤ竴鏉?`geomReady` 鈥斺€?**鍑犱綍娌″氨缁椂涓嶈兘钀戒綅**
        //     锛堝惁鍒欎細鎶婁竴甯?娌￠噺榻?鐨勪腑闂存€佸浐瀹氫笅鏉ワ級銆?
        //   鈽呪槄 2026-10-16锛堜簩娆¤姝ｏ級锛氳繖涓€鏉″垽鎹師鏉ユ槸 `morphUsable`銆備絾 `morphUsable`
        //     浼氬洜涓?閫€鍥?`onAreaChange` 鍏滃簳鍊?鑰屼负鐪燂紙瑙?`morphIntroAnchorsReady` 鐨勬敞閲婏級锛?
        //     瀹?*涓嶈冻浠?*璇存槑"缁堢偣閿氱偣鐪熺殑閲忓埌浜?銆俙morphGeomReady()` 鎵嶆槸鏃犵晫
        //     `pullGeomReady` 鐨勭瓑浠风墿锛堝彧鍦?`measureMiniDuringPull` 閲忓埌缁堢偣閭ｄ竴鎷嶇疆浣嶏級
        //     鈬?钀戒綅闂ㄥ繀椤荤敤瀹冿紝鍚﹀垯浼氭妸"鍗婁唤鍑犱綍"钀藉畾鎴?OPEN銆?
        if (this.appState.isShowPlay && this.expandState.morphGeomReadyNow() &&
          this.expandState.morphUsable) {
          this.expandState.pushMorphTrace('settled');
          this.expandState.morphSettleOpen();
        } else {
          this.expandState.pushMorphTrace('settleSkip');
          Logger.info(RzdShellLogTag,
            `pull settle: skip morphSettleOpen showPlay=${this.appState.isShowPlay} ` +
            `usable=${this.expandState.morphUsable} geomReady=${this.expandState.morphGeomReadyNow()} ` +
            `stage=${this.expandState.morphStage}`);
          // 鈽呪槄鈽?2026-10-16锛堜笌涓婇潰"end anchor unavailable"閭ｆ潯**鍚屼竴鏉¤鍒?*锛夛細
          //   鍑犱綍濮嬬粓娌￠噺鍒?鈬?鏃犵晫鐨勫彛寰勬槸銆屾湰娆￠€€鍥炴櫘閫?push(鏃犲舰鍙?銆嶁€斺€?
          //   蹇呴』鎶婄浉浣嶄粠 ENTERING 鏀跺洖鏉ャ€傚師鏉ユ槸**鍙墦鏉℃棩蹇椼€佷粈涔堥兘涓嶅仛**锛?
          //   鐩镐綅姘歌繙鍋滃湪 ENTERING銆乣morphContainerActive()` 鎭掔湡 鈬?
          //   鎾斁椤甸偅鏉¤矾鍙兘鎸傜潃涓€涓崐姝荤殑褰㈠彉浼氳瘽锛堢敤鎴峰疄娴嬬殑"鑳屾櫙鏁村睆 / 娌℃湁鍔ㄧ敾"锛夈€?
          //   鈿狅笍 鍙湪"鐢ㄦ埛鍦ㄦ挱鏀鹃〉"锛坄isShowPlay`锛夋椂鎵嶆敹 鈥斺€?鐢ㄦ埛宸茬粡绂诲紑鏃剁敱 `popPlayerRoute`
          //     閭ｆ潯璺嚜宸辨敹锛坄morphReset` 宸插湪 `onDisAppear` 閲岃窇杩囷級銆?
          if (this.appState.isShowPlay && !this.expandState.morphGeomReadyNow()) {
            this.expandState.pushMorphTrace('degrade');
            Logger.warn(RzdShellLogTag,
              'pull settle: geometry never ready 鈬?degrade to a plain full-screen player');
            this.expandState.morphReset();
            this.expandState.morphStage = MorphStage.OPEN;
            this.expandState.morphP = 1;
            // 同值落位（降级路径也不许两条时间线分叉）。
            this.expandState.contentP = 1;
          }
        }
      }, duration + 20);
      return;
    }
    // 娌¤繃闃堝€硷細琛ラ棿鍥炶捣鐐癸紝**鍔ㄧ敾鎾畬**鍐嶄氦杩樿糠浣犳潯骞跺嵏杞姐€?
    // 鈿狅笍 `morphLand()` 涓嶈兘鍦ㄨˉ闂翠箣鍓嶈皟锛歀ANDING 涔嬪悗鎾斁椤垫暣椤典笉鍐嶇粯鍒?
    //    锛坄morphPageOpacity()` 鍦?LANDING 杩斿洖 0锛涒槄 瑙佸畠鑷繁鐨勬敞閲?鈥斺€?閭ｄ釜鍑芥暟
    //     **鐩墠娌℃湁娑堣垂鑰?*锛屾墍浠?涓嶇敾"瀹為檯鐢?`.visibility(isCollapsing)` 涓?
    //     `morphClipping()` 閭ｆ潯瑁佸壀闂ㄥ叡鍚屽疄鐜帮級锛屾彁鍓嶈皟灏辩湅涓嶅埌"缂╁洖鍘?鐨勮繃绋嬩簡銆?
    setTimeout((): void => {
      // 鈽呪槄鈽?2026-10-16锛?*鍚屼竴鏉″洜鏋滈摼鐨勭浜斿**锛夛細涓庝笂闈㈤偅鏉″悓娆捐姝?鈥斺€?
      //   鍘绘帀 `morphGenAlive`锛堝畠浼氳"鏃ч〉闈㈠疄渚嬪嵏杞芥椂鐨?`morphReset()`"鎺ㄩ珮锛?
      //   涓?鐢ㄦ埛杩樻兂涓嶆兂鎵撳紑鎾斁椤?鏃犲叧锛夈€傝嫢杩欓噷琚鎷︼紝鎵嬪娍娌″埌闃堝€肩殑鍥炲脊
      //   灏变細**鍋滃湪鍗婅矾**锛堟挱鏀鹃〉鎸傚湪涓€鍧椾腑闂村ぇ灏忕殑绐楀彛涓娿€佽糠浣犳潯涔熶笉浜よ繕锛夈€?
      if (!this.appState.isShowPlay) {
        return;
      }
      this.expandState.morphLand();
      this.appState.isShowPlay = false;
      this.expandState.morphReset();
    }, duration + 20);
  }

  /** 鎵嬪娍琚郴缁熸姠璧帮細鍥炲脊鍒拌捣鐐瑰苟鍗歌浇锛堝惁鍒欐挱鏀鹃〉浼氫竴鐩存寕鍦ㄨ糠浣犳潯閭ｄ竴灏忓潡涓婏級銆?*/
  private onPullOpenCancel(): void {
    if (!this.expandState.pullDragging) {
      // 鈽?涓?`onPullOpenEnd` 鍚屾棌锛堥兘鏄?鏀跺熬琚嫆"锛夆噿 璁″埌鍚屼竴涓暟涓婏紝瑙?`pullDropEnd`銆?
      this.expandState.notePullDropEnd();
      return;
    }
    this.settlePullOpen(false);
  }

  /**
   * 鈽呪槄鈽呪槄 2026-10-17锛堢収鎼棤鐣?`MainPage` 鐨勫揩鐓ф敹缂╂诞灞傦紝`wujie.pa:162465-162707`锛夛細
   * 銆岄潪鎵嬪娍鍏抽棴銆? 鎶婃挱鏀鹃〉鏍硅妭鐐圭殑涓€寮?*婊＄獥蹇収**缂╁埌杩蜂綘鏉¤兌鍥婏紝鍚屾椂娣″嚭銆?
   *
   * ## 涓轰粈涔堝繀椤绘槸杩欐牱锛堢敤鎴风 鈶?鏉°€屾湁鑳屾櫙浣嗘槸楂樺害鐗逛綆銆嶇殑姝ｈВ锛?
   * 鎴戜滑鍘熸潵锛堜互鍙婄幇鍦?*涓嬫媺**閭ｆ潯璺粛鐒讹級鏄?*鍔ㄦ椿鐨勬挱鏀鹃〉**锛氭敼瑁佸壀绐楀彛 + 缂╂斁銆?
   * 鍙"瑁佸壀绐楀彛楂樺害"涓?缂╂斁"鏈変竴鐐逛笉鍚屾锛屽睆涓婂氨鏄?鏈夎儗鏅€佷絾鍙墿寰堢煯鐨勪竴鏉?銆?
   * 鏃犵晫鐨勯潪鎵嬪娍鍏抽棴**鏍规湰涓嶅姩娲婚〉闈?*锛氬畠鍦?`closeWithAnimation()` 閲?
   * `componentSnapshot.get(PLAYER_ROOT_ID, 位)` 鎷嶄竴寮犲浘锛岀劧鍚?`nav.pop(false)` 鎶婇〉闈㈠嵏鎺夛紝
   * 鍐嶈**杩欏紶鍥?*缂╀笅鍘?鈬?鍥鹃噷鐨勮儗鏅笌灏侀潰**鍚屾瘮渚嬩竴璧风缉** 鈬?閭ｇ褰㈢姸**涓嶅彲鑳?*鍑虹幇銆?
   *
   * ## 閫愭潯瀵圭収锛堝叏閮ㄧ洿璇伙紝瑙?`MorphShrinkState` 鏂囦欢澶达級
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
   *           .width(鏁寸獥瀹?.height(鏁寸獥楂?                          // 162829-162862锛堝浘鎭掍负鏁寸獥锛?
   *           .objectFit(ImageFit.Cover)                            // 162863-162871
   *           .syncLoad(true) }                                     // 162872-162879
   *   }
   * ```
   * 鈿狅笍 閭ｄ釜 `Column` 鐨勫搴︽槸 `'100%'`锛? 鏁寸獥瀹斤級**涓旈潬鐖?`Stack` 鐨勫乏涓婅瀵归綈**
   *    鈥斺€?`MorphShrinkState` 閲岄偅缁?`endTx/endTy` 姝ｆ槸鎸?缁曡嚜韬腑蹇冪缉鏀?鍙嶈В鍑烘潵鐨勶紝
   *    涓よ€呮槸涓€瀵癸紝**涓嶈**缁欏畠鍔?`.position()` 鎴栨敼瀵归綈鏂瑰紡銆?
   * 鈿狅笍 鏁村眰涓嶅悆浜嬩欢锛堝叧鎾斁鍣ㄧ殑鐬棿锛屼笅闈㈢殑棣栭〉瑕佺珛鍒诲彲鐢級銆?
   */
  @Builder
  private ShrinkOverlayHost() {
    if (this.shrinkState.visible && this.shrinkState.pixmap !== undefined) {
      // 鈿狅笍 澶栧眰 `Stack` 蹇呴』鏄?**`Alignment.TopStart` + 鏁寸獥鐩?*锛?
      //   `MorphShrinkState` 閭ｇ粍 `endTx/endTy` 鏄寜"`Column` 鏈缉鏀炬椂鍗?`x鈭圼0,W], y鈭圼0,C]`"
      //   鍙嶈В鍑烘潵鐨勶紙瑙侀偅涓枃浠跺ご鐨勫璐︼級鈥斺€?闈犵埗瀹瑰櫒鐨?*宸︿笂瑙掑榻?*鎵嶆垚绔嬨€?
      //   鐩掑昂瀵哥敤**瀹炴祴绐楀彛灏哄**鏄惧紡缁欙紙涓庡彟澶栦笁涓诞灞傚悓涓€澶勪慨姝ｏ細涓嶇粰灏卞彧绛変簬瀹夊叏鍖轰箣鍐呴偅鍧楋級銆?
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          Image(this.shrinkState.pixmap)
            // 鍥炬亽涓?*鏁寸獥**锛堟棤鐣?`162829-162862` 灏辨槸 `px2vp(windowWidth_px/Height_px)`锛?
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
   * 褰㈠彉鍏嬮殕灞傦細杩蜂綘鏉￠偅鏉?鍏冧俊鎭?+ 鎿嶄綔鍖?鐨?*鍓湰**锛岄拤鍦ㄥ畠鍘熸潵鐨勪綅缃紝闅忚繘搴︿綅绉诲苟娣″嚭銆?
   *
   * 鍙嶇紪璇戜緷鎹紙`MiniMorph娓叉煋鏂逛笌椤跺簳鏍忔贰鍏ュ叕寮?md`锛夛細
   *   路 `位1e` 鍏冧俊鎭厠闅嗭細`position(miniMetaLeft, miniMetaTop)` + `translate({x: coverRightShiftAt(t)})`
   *     + `opacity(metaOpacityAt(t))`锛坄clamp(1 - t/0.35)`锛?
   *   路 `位1f` 鎿嶄綔鍖哄厠闅嗭細`translate({y: coverRiseAt(t)})` + `opacity(actionsOpacityAt(t))`
   *     锛坄clamp(1 - t/0.20)`锛屾瘮鍏冧俊鎭洿鏃╂秷澶?鈥斺€?"鍙充晶涓変釜鎸夐挳鎱㈡參闅愯棌"灏辨槸杩欐潯锛?
   *   路 闈㈤偅涓€妫掞紙灏侀潰鍏嬮殕锛?*涔熷湪杩欎釜澹冲眰閲?*浜?鈥斺€?瑙?{@link MorphCoverClone}
   *     锛?026-10-15 浠?`PlaybackPage.MorphCoverBridge` 鎼潵锛涗袱渚х煩褰㈠悓婧愶級銆?
   *
   * 浣嶇Щ閲忔槸**鐩稿閲?*锛坄coverRightShiftAt = coverRight(t) - coverRight(0)`锛夛紝
   * 鎵€浠ュ畠鍙細"琚皝闈㈡帹鐫€寰€鍙宠蛋銆佽窡鐫€灏侀潰寰€涓婃姮"锛屼笉浼氳烦鍒板埆鐨勪綅缃€?
   */
  @Builder
  private MorphMiniBarClone() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 鈿狅笍 蹇呴』鍖呬竴灞?*瀹氬鐨?Row**锛堜笉鏄?Column锛夛細`HomeMiniBarPlayerAside` 鐨勬牴鑺傜偣甯?
      //    `.layoutWeight(1)`锛屽畠鍙湪 Row/Column 閲岀敓鏁堬紝鑰屼笖**鏂瑰悜瑕佸** 鈥斺€?
      //    鏀捐繘 Column 浼氳瀹冩寜"绔栫洿鍓╀綑绌洪棿"鍒嗛厤銆佹í鍚戦€€鍖栨垚 wrap-content锛?
      //    缁撴灉灏辨槸鍙充晶閭ｄ笁涓寜閽暣浣撳乏绉伙紙鐢ㄦ埛瀹炴祴涓ゆ閮芥槸杩欎釜鐥囩姸锛夈€?
      Row() {
        HomeMiniBarPlayerAside({
          playerViewModel: this.miniBarViewModel,
          showPreviousTrack: false,
          // 鍏冧俊鎭紙姝屽悕/姝屾墜锛夌敤 `clamp(1 - t/0.35)`锛屼笌鎿嶄綔鍖洪偅涓€妗ｅ垎寮€锛?
          // 瀹冨悓鏃惰灏侀潰"鎺ㄧ潃寰€鍙宠蛋"锛坄coverRightShiftAt`锛屽弽缂栬瘧 位1e锛?
          isMorphClone: true,
          metaOpacity: 0,
          metaShiftX: this.expandState.coverRightShiftAt(this.expandState.morphP)
        })
      }
      .width(this.expandState.asideWinW)
      .height(this.expandState.asideWinH)
      .alignItems(VerticalAlign.Center)
      .position({ x: this.expandState.asideWinX, y: this.expandState.asideWinY })
      // 鎿嶄綔鍖洪偅涓€妗ｏ細鏁村潡鎸?`clamp(1 - t/0.20)` 娣″嚭锛堟寜閽厛娌°€佹枃瀛楀悗娌★級
      .opacity(PlayerExpandState.actionsOpacityAt(this.expandState.morphP))
      // 鈿狅笍 鍙仛**绾靛悜**浣嶇Щ锛堝弽缂栬瘧 位1f 鐨?`coverRiseAt`锛夈€?
      //    妯悜鐨?`coverRightShiftAt` 鏄粰**鍏冧俊鎭?*閭ｄ竴灞傜殑锛屽鍒版寜閽笂浼氳鎸夐挳
      //    妯潃婊戝嚭鍘?鈥斺€?鏀惰捣鏃惰〃鐜版垚"涓€涓殏鍋滄寜閽粠灞忓箷澶栭杩涙潵"銆?
      .translate({ y: 0 })
    }
    // 鈽呪槄鈽?2026-10-16锛堜笌 `MorphCoverClone()` **鍚屼竴澶勪慨姝?*锛岀悊鐢遍€愬瓧鐩稿悓锛夛細
    //   杩欓噷鍘熸潵鏄?`LayoutPolicy.matchParent` 脳2 鈬?鎷跨殑鏄?*澹冲眰鏍?`Stack`** 鐨勫昂瀵革紝
    //   鑰屾牴 `Stack` **娌℃湁 `ignoreLayoutSafeArea`** 鈬?杩欎竴灞傜殑鐩掑瓙鍙瓑浜?瀹夊叏鍖轰箣鍐?閭ｅ潡銆?
    //   鑰屽畠鐨勫瓙鑺傜偣锛堜笂闈㈤偅涓?`Row`锛夌敤鐨勬槸 `.position({x: asideWinX, y: asideWinY})`
    //   鈥斺€?**鍏ㄧ獥鍙ｅ潗鏍?*锛堜笌杩蜂綘鏉￠噺娴嬪悓鍙ｅ緞锛夆噿 褰撹糠浣犳潯闈犺繎灞忓箷搴曢儴锛坄asideWinY 鈮?850`锛?
    //   鏃讹紝杩欎竴鍧椾細钀藉湪灞傜洅瀛?*涔嬪** 鈬?琚鎺?鈬?瑙傛劅鏄?鍏抽棴鏃?*鎿嶄綔鍖洪偅涓変釜鎸夐挳涓嶈浜?*"銆?
    //   鈬?鐢?*瀹炴祴绐楀彛灏哄**鏄惧紡缁欙紙閲忎笉鍒版椂閫€鍥?`'100%'`锛屼笌鏀瑰姩鍓嶉€愬瓧涓€鑷达級銆?
    .width(this.expandState.windowWidthVp > 0 ? this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
    .height(this.expandState.windowHeightVp > 0 ? this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // 鏁村眰涓嶅悆浜嬩欢锛氫笅闈㈠氨鏄挱鏀鹃〉锛岀帺瀹剁殑鐐瑰嚮蹇呴』鐓у父钀藉埌鎾斁椤典笂
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

  /**
   * 鈽呪槄 褰㈠彉**娴眰**锛氱画椋炲皝闈㈢殑**澹冲眰鍏嬮殕**锛堝鏍囨棤鐣?`MainPage.MorphOverlayHost.morphCover`锛夈€?
   *
   * 杩欎竴妫掑師鏉ョ敾鍦ㄦ挱鏀鹃〉鍐呴儴锛坄PlaybackPage.MorphCoverBridge`锛夈€傛惉鍒拌繖閲岀殑鍘熷洜鏄?*鍧愭爣绯?*锛?
   * 鎾斁椤甸偅涓€鐗堣鐢诲湪**琚?scale+translate 鍙樻崲杩囥€佽繕甯?`.clip()` 涓庡姩鎬?`.height(morphClipHeight())`
   * 鐨勫鍣?*閲岋紝鑰屽畠鎷垮埌鐨勭煩褰㈡槸**绐楀彛鍧愭爣** 鈬?鍙湁 p=1锛堟亽绛夊彉鎹級鏃朵弗鏍兼纭€?
   * 鍘嗗彶涓婂畠鍙嶅鍑洪棶棰橈紙"灏侀潰鍓嶅崐娈电湅涓嶈""鍧愭爣鍙ｅ緞鎺ㄩ敊""琚埆鐨勫厓绱犳尅浣?锛夐兘鍑哄湪杩欎釜鍓嶆彁涓娿€?
   * 娴眰杩欎竴浠?*涓嶅湪閭ｄ釜瀹瑰櫒閲?*锛氬畠鐩存帴韬哄湪澹冲眰杩欎釜婊″睆 Stack 涓婏紝`morphOverlayCoverBridge()`
   * 缁欑殑绐楀彛鍧愭爣灏辨槸瀹冪殑缁樺埗鍧愭爣锛?*涓嶅仛浠讳綍"椤靛唴 鈫?绐楀彛"鎹㈢畻**銆?
   *
   * 涓ゅ眰鍚勮嚜鐨勬椂闀?鏇茬嚎锛堣繖鏄?涓ゅ眰"鐨勫叧閿級锛?
   *   路 鎾斁椤甸偅涓€灞傦細`morphP`锛?50ms `Curve.EaseInOut`锛?*娌″姩**锛夛紱
   *   路 杩欎竴灞傦細`morphOverlayP`锛?60ms `cubic-bezier(0.23, 1.0, 0.32, 1.0)`锛堝揩鍑烘參鏀讹級銆?
   *
   * 鈿狅笍 鏄鹃殣闂ㄧ敤 `morphOverlayBridging()`锛? `morphBridging()` 鈭?瀹夸富纭疄鎺ョ浜嗚繖涓€妫掞級锛?
   *    **涓嶆槸**鏂伴€犱竴鎶婇棬锛涗笁涓壇鏈紙灏侀潰 / 姝屽悕姝屾墜 / 鎿嶄綔鍖猴級鑳戒笉鑳藉悓鏃舵垚绔嬶紝
   *    浠ュ強"杩蜂綘鏉℃湰浣撹鍗犱綅椤舵帀銆佹挱鏀鹃〉鐪熷皝闈笉鐢?杩欎笁鏉′笉鍙橀噺瑙佷换鍔℃姤鍛娿€?
   * 鈿狅笍 鏁村眰涓嶅悆浜嬩欢锛堜笅闈㈠氨鏄挱鏀鹃〉锛岀偣鍑?鎵嬪娍蹇呴』鐓у父钀藉埌鎾斁椤典笂锛夈€?
   */
  @Builder
  private MorphCoverClone() {
    Stack() {
      Image(this.miniBarViewModel.songCoverUrl().length > 0 ?
        this.miniBarViewModel.songCoverUrl() : this.miniBarViewModel.songCover())
        // 鈿狅笍 鐭╁舰鐩存帴鏉ヨ嚜鍏变韩鐘舵€侊紙vp锛?*绐楀彛鍧愭爣**锛夛細瀹姐€侀珮**鍒嗗紑鍙?* 鈥斺€?
        //    鎾斁椤靛皝闈㈠鏈?`layoutWeight(1)` + `constraintSize`锛岄噺鍒扮殑鐭╁舰涓嶄繚璇佹槸姝ｆ柟褰紝
        //    鎸夋鏂瑰舰鐢讳細鍦ㄨ惤浣嶄氦妫掗偅涓€鍒昏烦涓€涓嬶紙鐢ㄦ埛瀹炴祴杩囩殑"缁撴潫鏃跺皝闈㈠ぇ灏忚烦涓€涓?锛夈€?
        .width(this.expandState.morphOverlayCoverBridge().size)
        .height(this.expandState.morphOverlayCoverBridge().height)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.expandState.morphOverlayCoverBridge().radius)
        .clip(true)
        .position({
          x: this.expandState.morphOverlayCoverBridge().x,
          y: this.expandState.morphOverlayCoverBridge().y
        })
    }
    // 鈽呪槄鈽?2026-10-16锛?*鐓ф棤鐣屾妸杩欎竴灞傛樉寮忛摵婊″叏绐楀彛**锛夛細
    //   鍘熸潵杩欓噷鏄?`LayoutPolicy.matchParent` 脳2 鈥斺€?閭ｆ槸鎷?*鐖跺鍣紙澹冲眰鏍?`Stack`锛夌殑灏哄**锛?
    //   鑰?*鏍?`Stack` 鑷繁骞舵病鏈?`ignoreLayoutSafeArea`**锛堣瀹冪殑灞炴€ц〃锛氬彧鏈?`.width/.height('100%')`
    //   + `.id(MORPH_HOST_ID)` + 鎵嬪娍 + `onAreaChange`锛夆噿 杩欎竴灞傜殑鐩掑瓙鍙瓑浜?**瀹夊叏鍖轰箣鍐?*"閭ｅ潡锛?
    //   姣旂獥鍙ｅ皬锛堜笂涓嬪悇灏戜竴涓畨鍏ㄥ尯锛夈€?
    //
    //   鈿狅笍 鑰?`.position({x, y})` 鐢ㄧ殑鏄?*鍏ㄧ獥鍙ｅ潗鏍?*锛坄morphCoverRectAt()` 鐨勮緭鍑恒€?
    //      涓庤糠浣犳潯/鎾斁椤靛皝闈㈢殑閲忔祴鍚屽彛寰勶級鈬?褰撳皝闈㈠湪**灞忎笂閮?*锛堝皝闈㈤〉閭ｄ竴绔?`y 鈮?136`锛?
    //      鎴?*灞忎笅閮?*锛堣糠浣犳潯閭ｄ竴绔?`y 鈮?850`锛夋椂锛岄兘浼氳惤鍦ㄨ繖灞傜洅瀛?*涔嬪**
    //      鈬?琚鎺?/ 涓嶇粯鍒?鈬?**瑙傛劅灏辨槸"娌℃湁灏侀潰鍔ㄧ敾"**銆?
    //
    //   鈬?鐢?*瀹炴祴绐楀彛灏哄**鏄惧紡缁欙紙涓?`PlaybackPageRouteShell.boxWidth/boxHeight()` 鍚屾鍋氭硶锛?
    //     閭ｆ槸鏈粨宸茬粡楠岃瘉杩囩殑"閾烘弧绐楀彛"鍐欐硶锛夛紝骞朵繚鐣?`ignoreLayoutSafeArea` 鍙屼繚闄┿€?
    //     鈿狅笍 閲忎笉鍒扮獥鍙ｆ椂閫€鍥?`'100%'`锛堜笌鏀瑰姩鍓嶉€愬瓧涓€鑷达紝涓嶄細鏇村樊锛夈€?
    .width(this.expandState.windowWidthVp > 0 ? this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
    .height(this.expandState.windowHeightVp > 0 ? this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .opacity(this.expandState.morphOverlayBridgeOpacity())
    // 鏁村眰涓嶅悆浜嬩欢锛氫笅闈㈠氨鏄挱鏀鹃〉锛岀帺瀹剁殑鐐瑰嚮蹇呴』鐓у父钀藉埌鎾斁椤典笂
    .hitTestBehavior(HitTestMode.None)
    .zIndex(PLAYER_CLONE_Z_INDEX)
  }

  /**
   * 鍏夋劅鏍囬鏍忔潗璐紙HDS 瀹樻柟 `systemMaterialEffect`锛夛紝璺熼殢鐜鍏夋。浣嶃€?
   *
   *
   * 鈿狅笍 杩欎釜鍑芥暟**鍙兘**鍠傜粰 HDS 鐨?`titleBar.style.systemMaterialEffect` 鎴?
   *    `HdsTabs` 鐨?`barFloatingStyle.systemMaterialEffect`銆傚畼鏂广€婃矇娴稿厜鎰熷姛鑰椾紭鍖栥€嬪師鏂囷細
   *      銆屽叾浠栫粍浠朵粎鍦?Navigation/NavDestination 鏍囬鏍忔垨妯悜 Tabs 涓?barPosition 涓?
   *        BarPosition.End 鐨勫簳閮?TabBar 涓敓鏁堛€傚湪鍏朵粬鍖哄煙涓缃矇娴稿厜鎰熸晥鏋滀笉鐢熸晥銆傘€?
   *    鈬?鐩存帴鎶婂畠鎸傚埌鏅€氬鍣紙姣斿涓嬮潰閭ｆ潯 `floatingMiniBar` 鐨?Column锛変笂**鏄笉鐢熸晥鐨?*锛?
   *    涓嶈閭ｆ牱鍐欍€傜暀鐫€瀹冿紝鏄负浜嗗湪"鎶婁簩绾ф挱鏀炬潯鎼繘 HdsTabs 鐨?miniBar"閭ｆ潯璺?
   *    锛堣 {@link floatingMiniBar} 鐨勮鏄庯級閲岃兘鐩存帴澶嶇敤鍚屼竴濂楁。浣嶃€?
   * @returns HDS 鏉愯川鍙傛暟锛坄@since 6.1.0(23)`锛宒efault/pc 鐨?compatible 鍧?鈮?23锛夈€?
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
   * 鍗曚釜椤电琚偣鍑?閫変腑鏃剁殑寮硅烦瑙﹀彂璁℃暟锛堟瘡涓〉绛句竴涓級銆?
   *
   * `symbolEffect(effect, trigger)` 鏄€宼rigger 鍙樺寲灏辨挱涓€娆°€嶏紝鎵€浠ユ瘡涓〉绛惧繀椤?
   * **鍚勭敤鍚勭殑璁℃暟** 鈥斺€?鍏辩敤涓€涓殑璇濅袱涓浘鏍囦細涓€璧峰脊锛堣璁¤鑼冭鐨勬槸銆岄€変腑鎬併€嶉偅涓€棰楀脊锛夈€?
   *
   * 鈿狅笍 闀垮害蹇呴』绛変簬椤电鏁帮紙鐜板湪鏄?**4**锛氭帹鑽?/ 鐜板湪灏卞惉 / 鍥炲搷 / 鎴戠殑锛夛細`TabBarItem` 鎸変笅鏍囧彇銆?
   */
  @Local tabBounceTriggers: number[] = [0, 0, 0, 0];
  /**
   * 銆屽洖鍒伴《閮ㄣ€嶆寚浠わ紙姣忎釜椤电涓€涓紝閫掑瑙﹀彂锛夈€?
   *
   * 璁捐瑙勮寖锛氱偣鍑?*褰撳墠**椤电瑕佹妸鐣岄潰鍥炴粴鍒伴《閮?鎸囧畾浣嶇疆銆俙onTabBarClick` 鍦?
   * 鐐瑰凡閫変腑椤电鏃朵篃浼氳Е鍙戯紝鎵€浠ヤ笉闇€瑕佸湪椤电閲岃嚜宸卞姞 onClick锛堥偅浼氭墦鏂〉绛惧垏鎹級銆?
   *
   * 鈿狅笍 闀垮害蹇呴』绛変簬椤电鏁帮紙鐜板湪鏄?**4**锛夛細`HomeTabsPages()` 鎸変笅鏍囧彇銆?
   */
  @Local tabScrollTopCommands: number[] = [0, 0, 0, 0];

  /** 椤电閫変腑鎬佸脊璺筹紙BounceSymbolEffect + EffectDirection.DOWN锛岃搴曢儴椤电璁捐瑙勮寖锛夈€?*/
  private playTabBounce(index: number): void {
    const next: number[] = [...this.tabBounceTriggers];
    next[index] = (next[index] ?? 0) + 1;
    this.tabBounceTriggers = next;
  }

  /** 璁╃ index 涓〉绛剧殑椤甸潰鍥炲埌椤堕儴锛堣椤佃嚜宸辩洃鍚繖涓鏁帮級銆?*/
  private requestTabScrollTop(index: number): void {
    const next: number[] = [...this.tabScrollTopCommands];
    next[index] = (next[index] ?? 0) + 1;
    this.tabScrollTopCommands = next;
  }

  /** 鐐归〉绛撅細鍒囧埌鍒殑椤电鐢?onChange 澶勭悊锛涚偣褰撳墠椤电鍒欏洖婊氬埌椤堕儴銆?*/
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
        // 閫変腑鎬佸脊璺筹細`trigger` 鍙樺寲鍗虫挱涓€娆★紙鍙湁杩欎釜椤电鐨勮鏁板湪鍙橈紝鎵€浠ュ彧鏈夊畠寮癸級
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
   * HDS 鍥炶皟锛氳糠浣犳潯鏍峰紡鍙樺寲锛堜笌 musicfreeOH 鐨?`onBarStyleChange` 鍚屾**鍙楁帶**鍐欐硶锛夈€?
   *
   * USER_CLICK 鐐瑰嚮鍗曞眰鍦嗗舰鑳跺泭鏃舵仮澶嶅畬鏁村弻鎺掋€?
   * NORMAL/APP_TRIGGER 浠呮姤鍛婅緭鍑猴紝涓嶈兘鍙嶅悜绡℃敼鍞竴甯冨眬鐘舵€併€?
   * miniBarStyle鍙楁帶锛涙帶鍒跺櫒涓庡竷灞€鍚屾鍒囨崲銆?
   */
  private onMiniBarStyleChangeFull(miniBarStyle: HdsBarStyle, mode: HdsTabsBarChangeMode): void {
    if (this.navDepth > 0 || this.restoringHomeBar) {
      return;
    }
    if (mode === HdsTabsBarChangeMode.USER_CLICK &&
      this.appState.hdsBarLayoutMode === BarLayoutModes.HORIZONTAL) {
      // HDS expands the round tab inside a horizontal row; restore the entire two-row layout instead.
      this.getUIContext().animateTo({ duration: 300, curve: Curve.Smooth }, (): void => {
        this.appState.hdsBarLayoutMode = BarLayoutModes.VERTICAL;
        this.appState.miniBarExpanded = false;
      });
      this.tabsController.applyMiniBarStyle(HdsBarStyle.COLLAPSE);
      Logger.info(RzdShellLogTag, 'home bar user click restored two rows');
      return;
    }
    const expectedStyle: HdsBarStyle = this.appState.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE;
    Logger.info(RzdShellLogTag, `home bar callback style=${miniBarStyle} expected=${expectedStyle} mode=${mode}`);
    // NORMAL/APP_TRIGGER reports are output, not a second source of layout state.
  }

  /**
   * 浼犵粰 HDS 鐨勬帓甯冩ā寮忋€?
   *
   * `barLayoutMode` / `HdsBarLayoutMode` 鏄?**@since 6.1.1(24)** 鈥斺€?鎵€浠ュ伐绋嬪繀椤绘妸
   * `targetSdkVersion` 鎻愬埌 24 浠ヤ笂锛堟湰椤圭洰宸叉敼涓?6.1.1(24)锛宍compatibleSdkVersion`
   * 淇濇寔 6.1.0(23) 涓嶅奖鍝嶈澶囪鐩栵級銆傚湪 target 23 鐨勫伐绋嬮噷杩欎釜瀛楁涓嶅瓨鍦紝
   * 浼犺繘鍘讳篃涓嶇敓鏁堬紝搴曟爮灏卞彧鑳芥槸鍗曟帓 鈥斺€?杩欐鏄箣鍓?涓ゆ帓淇笉鍑烘潵"鐨勬牴鍥犮€?
   *
   * 浣庨厤璁惧锛堝彂琛岀増 < 6.1.1(24)锛変笂浼?undefined锛氬瓧娈典笉鍙敤锛岀敱 HDS 鑷鍐冲畾銆?
   * @returns HdsBarLayoutMode 鎴?undefined銆?
   */
  private barLayoutModeForHds(): HdsBarLayoutMode | undefined {
    if (!this.supportsTwoRowLayout()) {
      return undefined;
    }
    // 鈽呪槄 2026-10-15 鐪熸満鍙嶉**涓嶈**鍦ㄨ繖涓€椤垫妸瀹冨帇鎴?HORIZONTAL锛堟垜涓婁竴鐗堝氨鏄偅涔堝啓鐨勶紝閿欎簡锛夛細
    //   `HORIZONTAL` 鏄?椤电涓庤糠浣犳潯**骞舵帓**鍦ㄥ悓涓€鎺?鐨勬帓甯?鈬?杩蜂綘鏉￠偅涓€鏍肩┖鐫€鏃讹紝
    //   椤电琚尋鍒板乏杈广€佸彸杈圭暀鍑轰竴鏍?鈥斺€?鐢ㄦ埛鍘熻瘽銆屽簳閮?tab 鏍忓垏鎹㈠埌杩欎釜椤甸潰鐨勬椂鍊?*浼氱煭涓€鎴?*
    //   锛堝儚鏄互鍓嶉偅涓?*宸︿晶 Tab 鏍忥紝鍙充晶鍦嗗舰鎾斁鍣?*鐨勭増鏈級銆嶈鐨勫氨鏄畠銆?
    //   姝ｈВ锛?*鎺掑竷妯″紡瀹屽叏涓嶅姩**锛堣窡鍒殑椤电閫愬瓧涓€鑷达級锛屽彧鎶?{@link miniBar} 鐨勫唴瀹硅瀹冮噺鎴?0 楂?
    //   锛圚DS 鏄寜鍐呭閲忛珮搴︾殑锛岀┖ builder 鈬?娌℃湁閭ｄ竴鎺掞紝瑙?`miniBar()` 鐨勬敞閲婏級銆?
    return this.appState.hdsBarLayoutMode === BarLayoutModes.HORIZONTAL ?
      HdsBarLayoutMode.HORIZONTAL : HdsBarLayoutMode.VERTICAL;
  }

  /** 璁惧鍙戣鐗堟槸鍚︽敮鎸?`barLayoutMode`锛?.1.1(24) 璧凤級銆?*/
  private supportsTwoRowLayout(): boolean {
    return SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE);
  }

  /**
   * 浼犵粰 HDS 鐨勮糠浣犳潯鏍峰紡銆?
   *
   * 鈽呫€岀幇鍦ㄥ氨鍚€嶉〉鎭掍负 `COLLAPSE`锛氶偅涓€椤垫棦娌℃湁杩蜂綘鏉″唴瀹癸紙{@link miniBar} 涓嶆覆鏌擄級锛?
   *   鍙堣 {@link barLayoutModeForHds} 鍘嬫垚鍗曟帓 鈥斺€?鑰?鍗曟帓 + `EXPAND`"鏄凡鐭ョ殑閿欒缁勫悎
   *   锛堝簳鏍忎細鍙樻垚銆岄暱鏉?Tab + 鍦嗗舰鎾斁鍣ㄣ€嶏級銆傝 {@link NOW_PLAYING_TAB_INDEX}銆?
   * @returns 杩蜂綘鏉℃牱寮忋€?
   */
  private miniBarStyleForHds(): HdsBarStyle {
    if (this.tabState.tabIndex === NOW_PLAYING_TAB_INDEX) {
      return HdsBarStyle.COLLAPSE;
    }
    return this.appState.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE;
  }

  /**
   * 鍙屽眰搴曟爮鍗犳嵁鐨勯澶栧簳閮ㄩ珮搴︺€?
   *
   * 鎭掍负 0锛氭帓甯冪敱 HDS 鑷繁澶勭悊锛岄〉闈㈠啀棰濆棰勭暀灏变細澶氬嚭涓€鍧楃┖鐧姐€?
   * @returns 棰濆搴曢儴棰勭暀锛坴p锛夈€?
   */
  private twoRowExtraBottomVp(): number {
    return 0;
  }

  /**
   * HDS 娴姩搴曟爮閲岀殑杩蜂綘鎾斁鏉°€?
   *
   * 鈿狅笍 **浜岀骇椤甸潰鍦ㄦ爤涓婃椂涓嶆覆鏌?*锛坄navDepth > 0`锛夛細浜岀骇椤甸潰鏈夎嚜宸辩殑瀹樻柟娴姩鏍?
   * 锛堣 {@link floatingMiniBar}锛夛紝涓よ竟娓叉煋鐨勬槸鍚屼竴涓?`HomeMiniBarPlayer`锛?
   * 瀹冪‖缂栫爜 `.id(MINI_BAR_ID)` 鈥斺€?鍚屾椂瀛樺湪灏变細鏈変袱浠藉悓 id 鐨勮妭鐐癸紝
   * 鑰屾挱鏀鹃〉褰㈠彉鐨勮捣鐐规槸 `getRectangleById(MINI_BAR_ID)` 閲忕殑锛岄噺鍒板摢涓€浠戒笉纭畾銆?
   * 2026-10-01 閭ｆ鍥為€€灏辨槸杩欎釜鍧戯紙璁板繂 搂17.3 / 搂17.4-3锛氥€屼袱澶勫彧鑳界暀涓€澶勩€嶏級銆?
   *
   * **涓嶈缁欏畠鍥哄畾楂樺害**锛堝師鏉ュ啓姝?`.height(56)`锛夛細musicfreeOH 鐨?`PlayBar` 鏍硅妭鐐?
   * 鍙湁涓€涓?`.width('100%')`锛岄珮搴︽槸 HDS 閲忓嚭鏉ョ殑銆佸苟鐢辫糠浣犳潯鑷繁 `onAreaChange` 璇诲洖銆?
   * 鍐欐楂樺害浼氳 HDS 鍦ㄣ€屼笂涓嬩袱鎺掋€嶆椂鎷夸笉鍒版纭殑鍐呭楂樺害锛屾帓甯冨氨閫€鍖栥€?
   */
  @Builder
  private miniBar() {
    // 鈽?鐢ㄦ埛 2026-10-15锛氬簳鏍忋€岀幇鍦ㄥ氨鍚€嶉偅涓€椤?*涓嶇敾**杩欐潯杩蜂綘鏉★紙鍙傝€冨浘閲?Tab 鏍忎箣涓婂彧鏈夎繘搴﹁锛夈€?
    //   瑙?{@link NOW_PLAYING_TAB_INDEX}銆傜敤鏉′欢娓叉煋鑰屼笉鏄?`Visibility.Hidden`锛?
    //   淇濈暀鍗犱綅鐨勮瘽 HDS 浼氱户缁寜"涓ゆ帓"鎺掑竷锛孴ab 鑳跺泭浼氳椤堕珮銆佸簳涓嬬暀涓嬩竴鍧楃┖妗ｃ€?
    //   鈿狅笍 **鎺掑竷妯″紡涓嶈璺熺潃鏀?*锛坄barLayoutModeForHds()` 閲岄偅娈电殑鍧戯級锛?
    //     HORIZONTAL 鏄?椤电涓庤糠浣犳潯骞舵帓"锛屼細璁╅〉绛捐鎸ゅ埌宸﹁竟銆佸彸绔┖涓€鏍硷紙鐢ㄦ埛鐪嬪埌鐨?鐭竴鎴?锛夈€?
    //     杩欓噷鍙 HDS **閲忓埌 0 楂?*锛堝畠鏄寜鍐呭閲忛珮搴︾殑锛夛紝鎺掑竷妯″紡涓庡埆鐨勯〉绛鹃€愬瓧涓€鑷淬€?
    //   鈿狅笍 浠ｄ环锛氳繖涓€椤典笂 `getRectangleById(MINI_BAR_ID)` 閲忎笉鍒拌糠浣犳潯 鈬?褰㈠彉璧风偣鍙兘璧板厹搴曞嚑浣曘€?
    //     鍙互鎺ュ彈锛氭湰椤?*涓嶄細鎵撳紑鎾斁椤?*锛坄NowPlayingFeedPage` 鐨?`playAt` 璧?
    //     `openPlayer=false` / `PlaybackIntentState.openPlayerUi=false`锛夛紝
    //     鑰岃兘寮€鍒版挱鏀鹃〉鐨勫叆鍙ｏ紙搴曟爮杩蜂綘鏉＄偣鍑汇€佺郴缁熷獟浣撴帶鍒讹級鍦ㄦ湰椤典篃涓嶅瓨鍦?涓嶅舰鍙樸€?
    if (this.navDepth <= 0) {
      if (this.tabState.tabIndex === NOW_PLAYING_TAB_INDEX || this.navDepth > 0) {
        // 鈽呪槄鈽呪槄 2026-10-17锛?*淇敤鎴峰疄娴嬨€屼簩绾ч〉闈細鍑虹幇涓や釜鎾斁鏉°€?*锛?
        //   鍘熸潵杩欓噷鍙垽 `tabIndex === 姝ｅ湪鎾斁`锛?*娌″垽 `navDepth`** 鈥斺€?浜岀骇椤靛湪鏍堜笂鏃讹紝
        //   浜岀骇椤佃嚜宸遍偅鏉″畼鏂规诞鍔ㄦ爮锛坄floatingMiniBar`锛夊凡缁忓湪鐢伙紝棣栭〉杩欐潯鍙堟病鍗歌浇
        //   鈬?灞忎笂涓ゆ潯鎾斁鏉°€傛湰鏂囦欢 L1617 鐨勬敞閲婃棭灏卞啓鏄庤繖鏉′笉鍙橀噺
        //   銆屸殸锔?浜岀骇椤甸潰鍦ㄦ爤涓婃椂涓嶆覆鏌擄紙`navDepth > 0`锛夈€嶁€斺€?浠ｇ爜娌¤窡涓娿€?
        //   鈬?琛ヤ笂 `navDepth > 0`锛氫簩绾ч〉鍦ㄦ爤涓婃椂杩欎竴鏉″悓鏍风粰 0 楂橈紙**涓嶅嵏杞?*锛?
        //     淇濅綇 `MINI_BAR_ID` 浠嶅湪鏍戜笂锛屽舰鍙樿捣鐐硅繕鑳介噺寰楀埌锛夈€?
        // 鈽呪槄 杩欎竴椤?*鏄惧紡缁?0 楂?*锛堣€屼笉鏄?鏁翠釜 builder 涓嶆覆鏌?锛夛細
        //   瀹樻柟銆婅缃〉绛炬爮鐨勬偓娴牱寮忋€嬪師鏂団€斺€旇糠浣犳爮鏄嚜瀹氫箟鍖哄煙锛?*璺熼〉绛炬爮楂樺害鐩哥瓑涓旀按骞冲榻?*锛?
        //   鏈伐绋嬬敤 `barLayoutMode = VERTICAL` 鎶婂畠鏀规垚涓婁笅涓ゆ帓锛岃€?HDS 鍦ㄩ偅涓€妗ｆ槸**鎸夊唴瀹归噺楂?*鐨?
        //   锛堣 `miniBar()` 涓婇潰閭ｆ"涓嶈缁欏畠鍥哄畾楂樺害"鐨勮褰曪級鈬?缁欎竴涓?0 楂樺鍣紝
        //   "涓婇潰閭ｄ竴鎺?楂樺害灏辨槸 0锛岄〉绛捐兌鍥婄殑鍑犱綍涓庡埆鐨勯〉绛?*閫愬瓧涓€鑷?*銆?
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(0)
      } else {
        // 鈽呪槄 2026-10-15锛堝洖閫€鍚庨噸鍋氾級**涓嶅彉閲?*锛氫竴娆″舰鍙樹細璇濇湡闂达紝杩蜂綘鏉?*鐪熻韩涓嶅弬涓庣粯鍒?*锛?
        //   鐢卞３灞傚厠闅嗗眰锛坄MorphMiniBarClone` / `MorphMetaBridge`锛変笌鎾斁椤靛唴鐨勭画椋炲皝闈唬琛ㄥ畠銆?
        //   `sourceBarHidden` 鐢变細璇濇嫢鏈夎€呭敮涓€鍐欙紙`morphBeginEntering` / `morphBeginLeaving` 缃?true锛?
        //   `morphLand` / `morphReset` 缃?false锛夆噿 涓夋潯鎵撳紑璺兘鎴愮珛銆?
        //   涓嶈繖涔堝仛鐨勮瘽锛氭挱鏀鹃〉褰㈠彉鏈熼棿鏄?*鍗婇€忔槑**鐢诲嚭鏉ョ殑锛岀湡韬細浠庡簳涓嬮€忓嚭鏉?鈥斺€?
        //   涓€杈规槸鍏嬮殕灞傜敾鐨勫壇鏈€佷竴杈规槸鐪熻韩锛岀敤鎴风湅鍒扮殑姝ｆ槸"杩蜂綘鏉″帇鍦ㄦ挱鏀鹃〉涓?锛堥噸鍙狅級銆?
        //   鈿狅笍 蹇呴』鐢?`Visibility.Hidden`锛堜繚鐣欏竷灞€锛夛細褰㈠彉璧风偣瑕?`getRectangleById` 閲忚繖鏉℃爮锛?
        //   鐢?`None` 浼氶噺涓嶅埌 鈬?鍔ㄧ敾鐩存帴閫€鍖栥€?
        HomeMiniBarPlayer({ showPreviousTrack: false })
          .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
      }
    }
  }

  /**
   * 浜岀骇椤甸潰鐨勬偓娴糠浣犳挱鏀炬潯锛?*瀹樻柟 HDS 娴姩鏍?+ 娌夋蹈鍏夋劅鏉愯川**锛堢敤鎴?2026-10-11 鎷嶆澘鐨勭粨鏋勬敼閫狅級銆?
   *
   * 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲 涓轰粈涔堝繀椤绘槸"涓€涓崟椤电鐨?HdsTabs"鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
   *
   * 瀹樻柟銆婃矇娴稿厜鎰熷姛鑰椾紭鍖栥€嬪師鏂囷細銆屽叾浠栫粍浠朵粎鍦?Navigation/NavDestination 鏍囬鏍忔垨妯悜 Tabs 涓?
   * barPosition 涓?BarPosition.End 鐨勫簳閮?TabBar 涓敓鏁堛€?*鍦ㄥ叾浠栧尯鍩熶腑璁剧疆娌夋蹈鍏夋劅鏁堟灉涓嶇敓鏁堛€?*銆?
   * 涔熷氨鏄锛氬厜鎰熸潗璐ㄥ彧鏈?*鏍囬鏍?*涓?*搴曢儴 TabBar**涓や釜鍚堟硶瀹夸富銆傛棫鍐欐硶锛堝３灞?Stack 閲屼竴涓櫘閫?
   * Column 鎸?`backgroundEffect`锛?*姘歌繙鎷夸笉鍒板畼鏂规潗璐?*锛屽彧鑳界畻鑷粯杩戜技 鈥斺€?鐢ㄦ埛鏄庣‘鍚︽帀浜嗗畠銆?
   *
   * 鐜板湪鐨勫仛娉曪紙= 鍙傝€冨伐绋?`lxmusic-harmony` 鐨?`views/PanePage.ets` 鍚屼竴濂楋級锛?*鍙湁涓€涓〉绛剧殑
   * HdsTabs**锛岄〉绛炬爮鐨勫唴瀹癸紙CustomBuilder锛夊氨鏄挱鏀惧櫒鏈綋锛屽啀鍔犱笂瀹樻柟涓夋潯浠?
   *   `barPosition(End)` + `barOverlap(true)` + `vertical(false)`
   * 鈬?杩欐潯鏍忓氨钀藉湪"搴曢儴 TabBar"杩欎釜鍚堟硶瀹夸富閲岋紝`systemMaterialEffect` 鐪熺敓鏁堛€?
   * 鏉愯川妗ｄ綅澶嶇敤鏍囬鏍忛偅涓€浠斤紙{@link ambientTitleMaterial}锛夛紝涓嶈鍐嶅唴鑱斾竴濂椾笁鐩€?
   *
   * 瀹夸富鏀惧湪**澹冲眰 Stack 鐨勫簳閮?*锛堜笌鏃ц兌鍥婂悓涓€涓綅缃€佸悓涓€濂楃畻鏈級锛屾墍浠ヤ簩绾ч〉
   * 锛坄NavDestination`锛夌洊涓嶄綇瀹?鈥斺€?杩欐鏄畠鑳芥浛鎺夋棫鑳跺泭鐨勫師鍥犮€?
   *
   * 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲 鈽?涓€鏉＄‖绾︽潫锛氬叏灞?*鍙兘瀛樺湪涓€鏉?*杩蜂綘鏉?鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
   *
   * 2026-10-01 09:39 璇曡繃鍚屼竴濂楀涓伙紝鍥為€€浜嗭紝鍘熷洜灏辨槸**鍚?id 鎾炶溅**锛?
   * 棣栭〉搴曟爮鐨?`miniBar` 涓庤繖鏉′簩绾ф爮娓叉煋鐨勬槸鍚屼竴涓?`HomeMiniBarPlayer`锛屽畠纭紪鐮?
   * `.id(MINI_BAR_ID)`锛堣繛甯?`MINI_BAR_COVER_ID` / `MINI_BAR_ASIDE_ID`锛夈€備簩绾ч〉鍦ㄦ爤涓婃椂
   * 棣栭〉搴曟爮骞舵病鏈夊嵏杞?鈬?灞忓箷涓婂嚭鐜?*涓や唤鍚?id** 鐨勮妭鐐癸紝鑰屾挱鏀鹃〉褰㈠彉鐨勮捣鐐规槸
   * `getRectangleById(MINI_BAR_ID)` 閲忕殑 鈥斺€?閲忓埌鍝竴浠戒笉纭畾锛岃捣鐐瑰氨鎶栥€?
   * 鈬?鎵€浠?{@link miniBar}锛堥椤甸偅鏉★級鍦?`navDepth > 0` 鏃?*涓嶆覆鏌?*锛屼袱澶勫彧鐣欎竴澶勩€?
   *    鏀硅繖閲屼箣鍓嶅厛鐪嬮偅鏉℃敞閲娿€?
   *
   * 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲 灏哄 / 瑙︽懜 / 褰㈠彉璇箟锛堣繖浜?*涓嶈兘**鍔級鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
   *
   * 褰㈡€佺敤**棣栭〉涓ゆ帓 Tab 鏃朵笂闈㈤偅鏉?*鐨勫啓娉曪細鍚屼竴涓?
   * `HomeMiniBarPlayer({ showPreviousTrack: false, followAppMiniBarExpanded: false })`銆?
   *
   * 涓や釜灏哄**鏄惧紡**缁欙細
   *   - 楂樺害锛?6vp锛堝皝闈?44 + 涓婁笅鍚?6vp锛夈€傚畠鏄挱鏀鹃〉褰㈠彉鐨勮捣鐐癸紝鍑犱綍鍙殢
   *     `FLOATING_MINI_BAR_HEIGHT_VP` 杩欎竴涓父閲忓彉鍖栥€?
   *   - 瀹藉害锛?*浜ょ粰 HDS**锛堝涓婚摵婊″搴︼紝鏍忎綋/鑳跺泭鐨勫搴︿笌灞呬腑鐢卞畼鏂规诞鍔ㄦ爮鑷繁绠楋級銆?
   *     浠ュ墠鎴戜滑鍐欐杩囧搴︼紙`width(绐楀彛瀹?鈭?杈硅窛)` + `barFloatingStyle.barWidth`锛夛紝
   *     鐪熸満鍙嶉鏄?瑕佷箞璐村埌灞忓箷鍙宠竟銆佽涔堟拺鎴愭暣鏉″ぇ闀挎柟褰紝寰堜笐"鈥斺€?閭ｆ槸鍜?HDS 鐨勮浣嶅姩鐢绘墦鏋?
   *     锛?026-10-01 閭ｆ瀹為獙鐨勬暀璁級锛岀幇鍦ㄤ笉鍐嶈嚜宸辩畻銆?
   *   `clip(false)` 瑕佺暀鐫€锛氳浜嗕細鎶?HDS 鐨勮儗鏉?鎶樺皠涓€璧疯鎺夈€?
   *
   * 瑙︽懜锛氭暣灞?Stack 蹇呴』 `HitTestMode.Transparent` 鈥斺€?榛樿鐨?Default 浼氭妸浜岀骇椤甸潰鐨?
   * 鐐瑰嚮鍏ㄥ悆鎺夛紙韪╄繃锛夛紱Transparent 琛ㄧず鑷繁涓嶅悆浜嬩欢浣嗗瓙鑺傜偣鐓у父鍝嶅簲銆?
   */
  @Builder
  private floatingMiniBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      /**
       * 鈽呪槄 鍏抽敭锛歚TabContent()` **涓嶈兘鏄┖鐨?*銆?
       *
       * 2026-10-01 閭ｆ瀹為獙灏辨槸"绌?TabContent + 鎾斁鍣ㄥ綋 tabBar"锛岀湡鏈轰笂**娌℃湁鑳跺泭鑳屾澘**
       * 锛堜綔鑰呭綋鏃跺彧鑳借ˉ涓€鍧楄嚜缁樿儗鏉垮厹搴曪級銆?026-10-11 澶嶇幇浜嗗悓涓€涓幇璞★細鐢ㄦ埛鎶?
       * 銆屽簳涓嬫挱鏀炬潯鏄€忔槑鐨勶紝鍙湅寰楄灏侀潰鍜屾寜閽€嶃€傜幇鍦ㄥ線 TabContent 閲屾斁涓€涓?*鐪熷疄鐨?
       * 婊″昂瀵稿鍣?*锛岃 HDS 璁や负杩欐潯鏍忔湁鍐呭锛屼粠鑰屾寜鎮诞鏍峰紡鐢诲嚭鑷繁鐨勮兌鍥婅儗鏉?+ 鏉愯川銆?
       *
       * 鍙﹀ `barFloatingStyle` 鐨勯敭**涓庨椤甸偅鏉″畼鏂瑰簳鏍忎繚鎸佷竴鑷?*锛堝彧缁?
       * `barBottomMargin` / `adaptToHandedness` / `systemMaterialEffect`锛夛細
       * 涓婁竴鐗堝浼犵殑 `barWidth` / `barSideMargin: 0` / `gradientMask: {maskHeight: 0}` 鏄?
       * 2026-10-01 瀹為獙閭ｅ锛?*褰撴椂姝ｆ槸閰嶇潃閭ｅ潡鑷粯鑳屾澘鐢ㄧ殑**锛夛紝鐜板湪涓€寰嬩笉浼狅紝閬垮厤浠讳綍
       * "鑷繁鎺ョ鏍忎綋"鐨勬殫绀猴紝鑳屾澘/鏉愯川鍏ㄤ氦缁?HDS銆?
       */
      // ★★★★ 2026-10-17（用户：「二级页面那个大的删了啊」+「小的是自绘的，大小也小一些」）
      //   原来这里是 `HdsTabs`（一个空 TabContent + 我们的播放器当 tabBar）：
      //   **大的是 HDS 自己画的浮动胶囊背板**，小的是我们那条内容 ⇒ 屏上一大一小。
      //   ⇒ 去掉 HDS 这一层，直接渲染 `HomeMiniBarPlayer`（它自带 `MiniBarBackplate()` 自绘背板）
      //     ⇒ 只剩这一个，宽度 = `floatingMiniBarWidthVp()`、高度 = `FLOATING_MINI_BAR_HEIGHT_VP`，
      //        与首页那条同一套尺寸口径（不再有"一大一小"）。
      // ★★★ 2026-10-18（用户：「这个播放条加上沉浸光感」）：把这条搬回 **HDS 浮动底栏**。
      //   本机 SDK 逐行核过（`D:\command-line-tools\sdk\default\hms\ets\api\@hms.hds.hdsBaseComponent.d.ets`）：
      //   `systemMaterialEffect` 在 API 23/24 档只有两个合法载体，都 @since 6.1.0(23)：
      //     · `TitleBarStyleOptions.systemMaterialEffect`（:1472）← Navigation/NavDestination 标题栏；
      //     · `HdsTabsFloatingStyle.systemMaterialEffect`（:5357）← `HdsTabs.barFloatingStyle`（:5582）。
      //   `CommonMethod` 上没有这个属性，挂在普通 `Column`/`Stack` 上**根本写不出来**；
      //   而官方《沉浸光感功能优化》又把它限制在「Navigation/NavDestination 标题栏」或
      //   「横向 Tabs 且 barPosition == BarPosition.End 的底部 TabBar」里 ⇒ 结论：
      //   这条浮动条只有住进 `HdsTabs` 的浮动底栏，才拿得到真正的官方材质。
      //   ⚠️ 单 Tab + **非空** TabContent：空 TabContent 在真机上 HDS 不画胶囊背板（2026-10-01 实测过）。
      HdsTabs({ barPosition: BarPosition.End }) {
        TabContent() {
          // 非空占位：只为让 HDS 认下"这条栏有内容"。它整屏铺开，所以必须
          // `hitTestBehavior(None)` —— 不许吃掉下面 NavDestination 的点击。
          Column()
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .hitTestBehavior(HitTestMode.None)
        }
        .tabBar(this.floatingMiniBarTabBarBox())
      }
      // 官方三条件（与首页那条 HdsTabs 底栏同一套）：barPosition(End) + barOverlap(true) + vertical(false)。
      .barMode(BarMode.Fixed)
      .barHeight(FLOATING_MINI_BAR_HEIGHT_VP)
      .barPosition(BarPosition.End)
      .barOverlap(true)
      .vertical(false)
      // 只有一个页签、没有可切的东西：关掉左右滑动，别让内容区的 Swiper 抢页面的手势。
      .scrollable(false)
      // `barOverlap` 自带一层隐式厚模糊，会盖住材质背板 ⇒ 一律关掉，材质交回 HDS 自己画。
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .barFloatingStyle({
        // 宽度口径：与内容**同一个函数**（`floatingMiniBarContent()` 里也是 `floatingMiniBarWidthVp()`），
        // 三档同值 ⇒ 胶囊与内容严格重合，不会再有「HDS 一大只 + 我们小一圈」的一大一小。
        barWidth: {
          smallWidth: this.floatingMiniBarWidthVp(),
          mediumWidth: this.floatingMiniBarWidthVp(),
          largeWidth: this.floatingMiniBarWidthVp()
        },
        // 条底到页盒底的距离（宿主盒 = 页盒 100%；页盒底 = 窗口底 − 系统避让）。
        barBottomMargin: FLOATING_MINI_BAR_BOTTOM_GAP_VP,
        // 不跟随握持手左右偏置：两侧留白已由 barWidth 精确给出。
        adaptToHandedness: false,
        // 材质档位复用标题栏那一份（`ambientTitleMaterial()`：跟随环境光档位、IMMERSIVE 家族）。
        systemMaterialEffect: this.ambientTitleMaterial()
      })
      // 宿主盒给满页盒：HDS 按 `barBottomMargin` 把它自己的胶囊放到盒底之上 12vp 处。
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 涓庨椤靛簳鏍忓悓涓€灞忓箷浣嶇疆锛氭暣鍧楀涓诲悜涓嬭鍑哄簳閮ㄩ伩璁╅偅涓€浠斤紙barBottomMargin 宸插綊闆讹級
      // 鈽?閿洏閬胯锛堢敤鎴?2026-10-12銆屼簩绾ч〉闈㈡挱鏀炬潯鍔犱笂閿洏閬胯銆嶏級锛氶敭鐩樺脊鍑烘椂鍦ㄨ繖浠藉亸绉讳笂
      //   鍐嶅噺鎺?`floatingMiniBarKeyboardLiftVp()`锛? 閿洏楂樺害 + 8 鈭?甯告€佹棦鏈夐棿闅欙級鈬?鏁存潯瀹夸富
      //   杩炲悓 HDS 鑳跺泭涓€璧蜂笂鎶埌閿洏涓婃部涔嬩笂锛涢敭鐩樻敹璧峰悗 lift 鎭掍负 0 鈬?杩欎竴琛?*閫愬瓧绛変簬**
      //   鏀瑰姩鍓嶇殑 `homeTabBarBottomMarginVp()`锛堝洖褰掔孩绾匡紝瑙侀偅涓嚱鏁扮殑娉ㄩ噴锛夈€?
      // 键盘避让：整条宿主（连同 HDS 画的胶囊）再上抬 lift。常态 lift=0（离底那 12vp 由 barBottomMargin 给）。
      .offset({ y: this.floatingMiniBarHostOffsetYVp() })
      // 涓嶈瑁侊細HDS 鐨勬潗璐ㄨ儗鏉?鎶樺皠鑼冨洿姣斿唴瀹圭洅澶э紝瑁佷簡浼氱己涓€鍦堛€?
      .clip(false)
      .onAppear((): void => {
        // ⚠️ 这行必须与代码**同义**：`hds-systemMaterialEffect` + `officialRegion=yes` 只有在
        //    宿主真的是 `HdsTabs` 浮动底栏时才成立（否则就是假日志，§183 踩过）。
        Logger.info('RzdSecondaryMiniMaterial',
          `mode=hds-systemMaterialEffect officialRegion=yes host=single-tab-hdstabs ` +
            `tabContent=nonEmpty barHeight=${FLOATING_MINI_BAR_HEIGHT_VP} ` +
            `barWidth=${this.floatingMiniBarWidthVp()} bottomGap=${FLOATING_MINI_BAR_BOTTOM_GAP_VP} ` +
            `keyGap=${FLOATING_MINI_BAR_KEYBOARD_GAP_VP} selfPlate=off ` +
            `ambient=${this.ambientLevelIndex()} singleVisibleBar=true`);
      })
      .onAreaChange((_oldArea: Area, area: Area): void => {
        // 这里的 width/height 是**宿主盒**（= 页盒 100%），不是胶囊；胶囊口径看 barWidth/barHeight 两项。
        Logger.info('RzdSecondaryMiniMaterial',
          `hostBox width=${area.width} height=${area.height} barWidth=${this.floatingMiniBarWidthVp()} ` +
            `barHeight=${FLOATING_MINI_BAR_HEIGHT_VP} bottomGap=${FLOATING_MINI_BAR_BOTTOM_GAP_VP} ` +
            `keyGap=${FLOATING_MINI_BAR_KEYBOARD_GAP_VP} keyboardVp=${this.keyboardBottomVp()} ` +
            `lift=${this.floatingMiniBarKeyboardLiftVp()} offsetY=${this.floatingMiniBarHostOffsetYVp()} ` +
            `ambient=${this.ambientLevelIndex()}`);
      })
      // 鈿狅笍 **涓嶈**鍦ㄨ繖閲屽啀鍐欎竴涓?`.margin({ bottom: ... })`锛氱搴曡窛绂诲凡缁忕敱
      //    `barFloatingStyle.barBottomMargin` 缁欎簡锛堜笌棣栭〉閭ｆ潯瀹樻柟搴曟爮鍚屼竴鍙ｅ緞锛夈€?
      //    涓や釜涓€璧峰啓 = 绂诲簳璺濈缈诲€嶏紝鐪熸満涓婄湅鐫€灏辨槸"鎾斁鏉℃诞寰楀お楂?锛堢敤鎴?2026-10-11 璁╃湅鐨勯偅鏉★級銆?
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignContent(Alignment.Bottom)
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(20)
    // Hidden preserves anchors/layout and hides the floating bar with its controls immediately.
    .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
  }

  /**
   * HDS 浮动底栏的 tabBar 内容盒：宽 = 胶囊宽（与 `barFloatingStyle.barWidth` 同一个函数）、高 = 56vp。
   *
   * 为什么还要这层显式盒子：HDS 是按**页签栏内容**去排胶囊的，而内容是 60vp（封面 44 + 上下各 8），
   * 不写死高度，胶囊会自己长到 60；写死 56 之后胶囊高度就是 `FLOATING_MINI_BAR_HEIGHT_VP`，与改动前一致
   * （`MINI_BAR_ID` 量到的高度也与改动前一致 —— 它同时是播放页形变的起点，见 §17.3）。
   * ⚠️ 多出来的 4vp 是设计上明确让步的余量：**不要**改成 `clip(true)` 去夹它（会切掉封面一圈）。
   */
  @Builder
  private floatingMiniBarTabBarBox() {
    Column() {
      this.floatingMiniBarContent()
    }
    .width(this.floatingMiniBarWidthVp())
    .height(FLOATING_MINI_BAR_HEIGHT_VP)
  }

  /**
   * 瀹樻柟娴姩鏍忛噷**鍞竴鍙鐨勫唴瀹?*锛堥〉绛炬爮 CustomBuilder锛夈€?
   *
   * 灏哄涓?{@link floatingMiniBar} 鐨勫涓荤洅涓ユ牸涓€鑷达細瀹夸富鏄?56vp 楂橈紝杩欓噷鍐嶅啓姝讳竴娆★紝
   * 鍏嶅緱 HDS 鐨勬帓甯冨彉鍖栵紙涓ゆ帓/鍗曟帓锛夋妸灏侀潰浠?44 缂╂垚 30銆?
   *
   * 鈽?2026-10-15锛?鎾斁鏉℃洿绮?閭ｆ潯锛夛細`HomeMiniBarPlayer` 鑷繁鐨勯珮搴﹀凡缁忔定鍒?56vp
   *   锛堝皝闈?40 + 涓婁笅鍚?8 鈥斺€?瑙?`HomeMiniBarAlbumCover.coverSideLengthVp()` 涓?
   *   `HomeMiniBarPlayer.sidePadVp()` 鐨勬敞閲婏級锛屾墍浠ヨ繖涓€妗ｏ紙灏侀潰 44锛夊湪鏈?Builder 閲?
   *   绠楀嚭鏉ョ殑楂樺害鏄?44 + 8脳2 = **60vp**锛屾瘮瀹夸富妲介珮 4vp 鈥斺€?浜ょ粰 HDS 灞呬腑鍗冲彲
   *   锛堝鍑烘潵鐨?4vp 鏄璁′笂鏄庣‘璁╂鐨勪綑閲忥紝涓嶈鍐嶅姞鍥哄畾 height 鍘诲す瀹冿紝
   *    2026-10-12 閭ｆ"寮鸿瀹?56vp 鈬?鏁存帓鍏冪礌浣?6~8vp"鐨勬暀璁氨鍦ㄤ笅闈㈤偅鏉℃敞閲婇噷锛夈€?
   * 涓婃媺/鐐瑰嚮鎵撳紑鎾斁椤电殑鎵嬪娍鍦?`HomeMiniBarPlayer` 鍐呴儴锛岃繖閲屼笉瑕侀噸澶嶆寕銆?
   */
  @Builder
  private floatingMiniBarContent() {
    HomeMiniBarPlayer({
      showPreviousTrack: false,
      followAppMiniBarExpanded: false,
      // ★★★ 2026-10-18：这条住在 HDS 浮动底栏里，胶囊与材质由 `barFloatingStyle.systemMaterialEffect`
      //   画（官方材质）⇒ 自绘背板必须关掉。不关就是「真材质 + 一层 #30F1F3F5 + 一层模糊」两层叠着，
      //   材质被洗白 —— 上一轮用户说的「大的（HDS 胶囊）和小一圈的（自绘）」也是这个叠法。
      //   （首页那条在 `barFloatingStyle.miniBar` 里、`enableMiniBarBackground: false`
      //      ⇒ 仍然靠自绘背板跟着 `morphSquashY` 一起弹，走默认 true，不动。）
      showSelfDrawnBackplate: false
    })
      // 鈽呪槄 鐢ㄦ埛 2026-10-11 瀹氳锛氥€岄敊浣嶇殑鏄挱鏀炬潯涓婄殑**鍏冪礌**鑰屼笉鏄挱鏀炬潯鏈韩銆嶃€?
      //   鑳跺泭瀹藉害鐢?`barFloatingStyle.barWidth` 缁欏嚭锛? 绐楀彛瀹?鈭?涓や晶鐣欑櫧 side锛夛紝HDS 鎶婂畠**灞呬腑**鐢伙紱
      //   鑰岃繖閲屽師鏉ュ啓 `width('100%')`锛? 瀹夸富鐩掑叏瀹斤級鈬?鍐呭姣旇兌鍥婂 2脳side锛?
      //   灏侀潰璐寸潃鑳跺泭宸︾紭銆佸彸渚ф寜閽《鍒拌兌鍥婂彸缂?鈬?鐪嬬潃灏辨槸"鍏冪礌閿欎綅"銆?
      //   鐜板湪鎶婂唴瀹瑰搴︿篃瀹氭垚鑳跺泭瀹藉害锛堝悓涓€鍑芥暟銆佸悓涓€鍙ｅ緞锛夛紝HDS 灞呬腑鍚庝袱鑰?*瀹屽叏閲嶅悎**銆?
      // 鈽呪槄 2026-10-12 鏂规 A 瀹為獙锛氬唴瀹瑰 = 鑳跺泭瀹斤紙涓?barFloatingStyle.barWidth 鍚屼竴鍑芥暟鍚屽彛寰勶級
      //   璇婃柇渚濇嵁锛堝彟涓€妯″瀷浜ゅ弶璇荤爜锛夛細鍐呭鐩掑師鏈?= 瀹夸富鐩?= 绐楀彛瀹斤紝姣旇兌鍥婂 2脳side 涓斿乏瀵归綈锛?
      //   鍙充晶鎸夐挳绨囪鎺ㄥ埌鑳跺泭鍙崇紭涔嬪 鈬?銆屽厓绱犺窇鍒板彸涓嬭銆嶃€傗憽 鑻ヨ繖鐗堜粛鐒舵洿绯燂紝涓€鍙ヨ瘽鎴戠珛鍒诲洖閫€銆?
      .width(this.floatingMiniBarWidthVp())
      // 鈽呪槄 鐢ㄦ埛 2026-10-11锛氥€屼簩绾ч〉闈㈡挱鏀惧櫒渚濇棫閿欎綅鈥﹀畠鏄窇鍒板彸涓嬭浜嗐€嶁€斺€?
      //   缁撹锛?*涓嶈鏀瑰唴瀹圭殑瀹介珮**锛堜竴鏀瑰氨涓?HDS 鐨勮兌鍥婂畾浣嶆墦鏋讹紝鍏冪礌鏁翠綋鍙充笅鍋忥級锛?
      // 鈽呪槄 GLM5.3锛坧rovider=zai锛夎瘖鏂?2026-10-12锛欻DS 娴姩鑳跺泭缁?tabBar 鐨?*鍐呭妲藉彧鏈夎兌鍥婇偅涔堥珮锛堚増40vp锛?*锛?
      //   鑰岃繖閲屾妸鍐呭寮鸿瀹氭垚 56vp锛堝皝闈?44 + 涓婁笅 padding 6+6锛夆噿 鍐呭姣旀Ы楂?~16vp锛?
      //   浜庢槸鏁存帓鍏冪礌鐩稿鑳跺泭涓績**浣庣害 6~8vp**锛堢湡鏈洪噺鍒?6vp锛屼笌鎴浘涓€鑷达級銆?
      //   鈬?涓嶅啀寮哄埗楂樺害锛屼氦缁?HDS 鎸夌湡瀹炴Ы浣嶈嚜閲忓苟灞呬腑锛涘搴︿粛鎸夎兌鍥婂锛堟柟妗?A锛屽凡瑙佹晥锛夈€?
  }

  // 鈿狅笍 杩欓噷鍘熸潵鎶?鑷繁绠楁爮瀹?鐨勪袱涓緟鍔╁嚱鏁板垹鎺夎繃锛?026-10-11 涓婂崍锛夛紝鐞嗙敱鏄?鏍忓浜ょ粰 HDS"锛?
  //    鐪熸満璇佹槑**涓嶈**锛欻DS 榛樿瀹藉害鍙湁涓€灏忓潹锛屾挱鏀惧櫒鍐呭鏁翠釜婧㈠嚭鑳跺泭澶栵紙鐢ㄦ埛鎴浘"涓€鍧?锛?
  //    鈬?鐜板湪鎸夊畼鏂?`barWidth` 涓夋。鏄惧紡缁欏洖鏉ワ紙瑙?`floatingMiniBar()`锛夈€?

  /** 鎮诞杩蜂綘鏉＄殑宸﹀彸闂磋窛锛坴p锛夛細鍙湪灏忓睆缁欎竴鐐硅竟璺濓紝瀹藉睆灞呬腑鐣欑櫧銆?*/
  private floatingMiniBarSideMarginVp(): number {
    return new BreakpointType(12, 16, 96, 160, 9).getWidthValueWithHeightSM(
      this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint);
  }

  /**
   * 鎮诞杩蜂綘鏉″搴︼紙vp锛夛細鍐欒繘 `barFloatingStyle.barWidth` 鐨勪笁妗ｃ€?
   *
   * 鎵嬫満锛氱獥鍙ｅ 鈭?涓や晶杈硅窛锛?2 / 16锛夛紱瀹藉睆锛氬す鍦?{@link FLOATING_MINI_BAR_MAX_WIDTH_VP} 鍐呭眳涓€?
   * 閲忎笉鍒扮獥鍙ｅ鏃剁粰 336 鍏滃簳锛堟棫鑳跺泭鍚屽彛寰勶級銆?
   * @returns 瀹藉害锛坴p锛夈€?
   */
  private floatingMiniBarWidthVp(): number {
    const side: number = this.floatingMiniBarSideMarginVp();
    if (this.viewportWidthVp <= 0) {
      return 336;
    }
    const full: number = this.viewportWidthVp - side * 2;
    const isWide: boolean = this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_MD;
    return isWide ? Math.min(FLOATING_MINI_BAR_MAX_WIDTH_VP, full) : Math.max(220, full);
  }

  /**
   * 鎮诞杩蜂綘鏉℃槸鍚﹀彲瑙併€?
   *
   * 棣栭〉涓嶆樉绀猴紙HDS 搴曟爮閲岀殑杩蜂綘鏉¤礋璐ｏ級锛涙鍦ㄦ挱鏀惧叏灞忛〉鎴栧浜庢壒閲忛€夋嫨妯″紡鏃朵篃涓嶆樉绀恒€?
   * @returns True 琛ㄧず鏄剧ず澹冲眰杩欐潯鎮诞杩蜂綘鏉°€?
   */
  private shouldShowFloatingMiniBar(): boolean {
    if (this.navDepth <= 0) {
      return false;
    }
    // 鈿狅笍 褰㈠彉鏈熼棿**蹇呴』缁х画鏄剧ず**锛氭挱鏀鹃〉娴眰鏄粠杩欐潯杩蜂綘鏉￠偅閲岄暱鍑烘潵鐨勶紝
    //    璧锋墜閭ｄ竴甯ф挱鏀鹃〉**鍑犱箮鐪嬩笉瑙?*锛堝畠姝ゅ埢鍙崰"杩蜂綘鏉￠偅涔堝ぇ鐨勮鍓獥鍙?锛?
    //    鑰岀獥鍙ｉ噷鐢荤殑鍙堟槸鍒氳捣姝ョ殑缂╂斁鍐呭 鈥斺€?鈽?涓嶆槸"鏁撮〉娣″叆"锛?
    //    `morphPageOpacity()` 閭ｄ釜鍑芥暟**鐩墠娌℃湁娑堣垂鑰?*锛岃瀹冭嚜宸辩殑娉ㄩ噴锛夛紝
    //    杩欐椂鍊欐妸杩蜂綘鏉¤棌浜嗭紝鐢ㄦ埛鐪嬪埌鐨勫氨鏄?灞忓箷涓嬫柟绐佺劧绌轰簡涓€鍧?鍐嶅啋鍑轰竴涓柟鍧椼€?
    //    瀹冭嚜宸卞湪褰㈠彉鏈熼棿浼氭贰鍑猴紙`miniBarOpacity`锛夛紝浜ゆ缁欐挱鏀鹃〉銆?
    if (this.appState.isShowPlay && !this.expandState.morphContainerActive()) {
      return false;
    }
    // 鈽?浜岀骇椤甸潰涓?HDS 娴姩搴曟爮涓嶅彲瑙侊紙琚?NavDestination 鐩栦綇锛夛紝鎾斁鍣ㄥ彧鑳界敱澹冲眰杩欎竴鏉¤礋璐?鈥斺€?
    //   鎵€浠?*灞曞紑鎬佷篃蹇呴』鏄剧ず**銆傛棫浠ｇ爜鍦ㄨ繖閲?`miniBarExpanded` 涓虹湡灏辫繑鍥?false锛?
    //   浜庢槸杩涗簩绾ч〉闈㈡椂蹇呴』鎶?`miniBarExpanded` 寮鸿鏀跺洖鎶樺彔鎬侊紝
    //   鑰?HDS 鐨?barLayoutMode 杩樻槸 HORIZONTAL 鈬?搴曟爮鍙樻垚銆岄暱鏉ab + 鍦嗗舰鎾斁鍣ㄣ€嶈繖绉嶉敊璇粍鍚堬紝
    //   鍙兘鍦ㄩ€€鍑轰簩绾ч〉闈㈡椂鍐嶇籂姝ｄ竴娆★紙鐢ㄦ埛鍙嶉鐨勫姩鐢诲紓甯稿氨鏄繖涔堟潵鐨勶級銆?
    //   鐜板湪涓嶅啀鏀讹細浜岀骇椤甸潰鐓у父鏄剧ず杩欐潯鎾斁鍣紙瀹冨悓鏃舵槸鎾斁椤靛舰鍙樼殑璧风偣锛夈€?
    return true;
  }

  /**
   * 鎮诞杩蜂綘鏉¤窛搴曢儴闂磋窛銆?
   *
   * 浜岀骇椤甸潰娌℃湁娴姩椤电锛屾墍浠ュ彧闇€閬垮紑绯荤粺瀵艰埅鏍?+ 灏戦噺鐣欑櫧锛?
   * 姣旈椤甸偅鏉★紙鍦ㄥ簳鏍忓唴锛夋槑鏄炬洿闈犱笅銆?
   * @returns 搴曢儴闂磋窛锛坴p锛夈€?
   */
  private floatingMiniBarBottomMarginVp(): number {
    // 鈽?璧?`getNavigationBarBottomVpFromWindowUtil()`锛氬畠銆岀紦瀛?鈫?鐜板悜绐楀彛閲?鈫?鏈€鍚庝竴娆″ソ鍊?鈫?
    //   鍚姩蹇収銆嶉€愮骇鍏滃簳銆傝€佷唬鐮佸彧璇荤紦瀛?+ 鍚姩蹇収锛屼袱鑰呴兘涓?0 鏃讹紙閬胯鍖轰竴娆￠兘娌′笂鎶ユ垚鍔燂級
    //   杈硅窛浼氶€€鍖栨垚 12锛岃兌鍥婅创鐫€灞忓箷搴曘€佸帇鍦ㄧ郴缁熸墜鍔挎潯涓?鈥斺€?鐢ㄦ埛鐪嬪埌鐨勩€屽簳閮ㄦ挱鏀惧櫒閿欎綅銆嶃€?
    const systemInset: number = getNavigationBarBottomVpFromWindowUtil();
    return Math.max(12, systemInset + 8);
  }

  /**
   * 杞敭鐩橀珮搴︼紙vp锛夛細娌℃湁閿洏鏃?0銆?
   *
   * 鍞竴鐩戝惉鐐瑰湪 `common/musicbasic` 鐨?`WindowUtil`锛坄on('avoidAreaChange')` 鐨?
   * `TYPE_KEYBOARD` 鍒嗘敮鍐?`WindowInfo.avoidKeyboard`锛夛紱鏈嚱鏁板彧鏄彧璇婚棬闈紝
   * 璇荤殑鏄?`@Trace` 瀛楁 鈬?閿洏寮瑰嚭/鏀惰捣浼氳嚜鍔ㄩ┍鍔ㄥ３灞傞噸鏂板竷灞€銆?
   */
  private keyboardBottomVp(): number {
    return getKeyboardBottomVpFromWindowUtil();
  }

  /**
   * 閿洏寮瑰嚭鏃讹紝浜岀骇椤甸潰鎮诞杩蜂綘鏉?*鍐嶅線涓婃姮**鐨勮窛绂伙紙vp锛夛紱鏃犻敭鐩樻椂**鎭掍负 0**銆?
   *
   * 鍙綔鐢ㄤ簬浜岀骇椤甸潰閭ｆ潯鎮诞鏉★紙{@link floatingMiniBar}锛夛細棣栭〉閭ｆ潯杩蜂綘鏉″湪 HDS 娴姩搴曟爮閲屻€?
   * 鐢卞畼鏂规爮浣撹礋璐ｈ浣嶏紝**涓嶈**鎶婃湰鍊煎杺缁欏畠銆?
   *
   * 绠楀紡涓庝袱涓父閲忔€庝箞璋冿紝瑙?{@link FLOATING_MINI_BAR_KEYBOARD_GAP_VP} 澶翠笂閭ｆ銆?
   * @returns 涓婃姮璺濈锛坴p锛夛紱鏃犻敭鐩樻椂涓?0锛堟鏃惰皟鐢ㄦ柟绠楀紡閫愬瓧绛変簬鏀瑰姩鍓嶇殑鍊硷級銆?
   */
  private floatingMiniBarKeyboardLiftVp(): number {
    const keyboardVp: number = this.keyboardBottomVp();
    if (keyboardVp <= 0) {
      // 无键盘时恒为 0：常态那 12vp 离底由 `barFloatingStyle.barBottomMargin` 负责，这里一点不承担。
      return 0;
    }
    // ★★★ 2026-10-18：`lift = 键盘高 + 24 − 12`（"已占用"用真值 12，见常量的推导注释）。
    //   旧式的 1.8 × (homeTabBarBottomMargin / 2) ≈ 25.2 是猜测值 ⇒ 会多压 13vp，键盘弹起时反被咬住。
    const lift: number = keyboardVp + FLOATING_MINI_BAR_KEYBOARD_GAP_VP - FLOATING_MINI_BAR_BOTTOM_GAP_VP;
    return lift > 0 ? lift : 0;
  }

  /**
   * 浜岀骇椤甸潰鎮诞杩蜂綘鏉?*瀹夸富**鐨勭旱鍚戝亸绉伙紙vp锛夈€?
   *
   * 鈿狅笍 鏃犻敭鐩樻椂蹇呴』**閫愬瓧绛変簬** `homeTabBarBottomMarginVp()` 鈥斺€?杩欐槸鍥炲綊绾㈢嚎锛?
   *    閿洏閬胯鍙厑璁稿湪"鐪熺殑寮逛簡閿洏"鏃舵敼鍙樿繖鏉℃爮鐨勪綅缃€?
   * @returns 瀹夸富 offset.y锛坴p锛夈€?
   */
  private floatingMiniBarHostOffsetYVp(): number {
    // ★★★ 2026-10-18：`.offset({ y })` 的 **+y 是向下** ⇒ "往上抬"一律写负数。
    //   旧写法 `homeTabBarBottomMarginVp() − lift` 的常态值逐字等于系统导航条高（≈28vp），
    //   等于把宿主盒往下推满那条让位 ⇒ 条底正好落在**窗口底**，用户看到的就是「直接贴底」。
    //   现在本函数**只**承担键盘抬升；"离底 12vp" 交给 `barFloatingStyle.barBottomMargin`，
    //   两处各管一段（HDS 侧再写一次 = 离底距离翻倍）。
    //   条底 = 页盒底 − FLOATING_MINI_BAR_BOTTOM_GAP_VP(barBottomMargin) − lift(本函数)。
    return -this.floatingMiniBarKeyboardLiftVp();
  }

  /**
   * 搴曢儴椤电锛?*鍙墿涓や釜** 鈥斺€?鎺ㄨ崘 / 鎴戠殑銆?
   *
   * 涓轰粈涔堟槸杩欎袱涓紙鐢ㄦ埛 2026-10-11 鏄庣‘瑕佹眰"搴曟爮鍙墿涓や釜 Tab"锛屽彟涓€涓敱鎴戜滑鑷繁鍒ゆ柇锛夛細
   *   - 銆屾帹鑽愩€嶆槸鍐呭涓婚潰锛堥椤垫帹鑽愭祦锛夛紝涔熸槸鍏ㄥ満鎵€鏈?鍘婚椤?鍔ㄤ綔鐨勮惤鐐癸紝鍒犳帀瀹冨簲鐢ㄥ氨娌′簡鍏ュ彛锛?
   *   - 銆屾垜鐨勩€嶆槸鍙傝€冨伐绋?lxmusic-harmony 鐨勫仛娉曪細瀹冭嚜宸变篃**浠庡洓涓〉绛撅紙鎺ㄨ崘/姝屽崟/鎴戠殑/璁剧疆锛?
   *     鏀舵垚浜嗕笁涓紙鎺ㄨ崘/鍚功/鎴戠殑锛?*锛岀悊鐢遍€愬瓧鍚屾瀯 鈥斺€?姝屽崟涓庤缃殑**鍐呭閮芥惉杩涗簡銆屾垜鐨勩€嶉〉**
   *     锛堝揩鎹峰叆鍙?+ 姝屽崟鍗?+ 璁剧疆鍗★級锛屽啀鐣欑潃閭ｄ袱涓〉绛惧氨鏄?鍚屼竴浠朵簨涓や釜鍏ュ彛"銆?
   *     鎴戜滑娌℃湁銆屽惉涔︺€嶏紝鎵€浠ユ濂芥槸**涓や釜**銆?
   *
   * 琚垹鎺夌殑涓や釜椤电锛岃兘鍔涢兘鏈夋柊鍏ュ彛锛堜竴鏉￠兘娌′涪锛夛細
   *   - 銆岃缃€嶁啋銆屾垜鐨勩€嶉〉閭ｅ紶**鍏ュ彛鍗?*鐨勩€岃缃€嶈 鈫?`SettingPage` 浜岀骇椤?
   *     锛?*灏辨槸鎴戜滑鍘熸潵閭ｄ釜澶ц缃〉鏈綋**锛氭悳绱㈡ + 鍏粍璁剧疆椤?+ 骞冲彴璐﹀彿/骞冲彴闊充箰/涓嬭浇绠＄悊锛?
   *      椤朵笂閭ｅ紶銆岀櫥褰曢煶涔愩€嶅崱宸叉惉鍒般€屾垜鐨勩€嶉〉椤堕儴锛岃 `LoginMusicCard.ets`锛?
   *      鐐硅繘鍘荤殑璇︽儏浠嶆槸鍚屼竴涓?`SettingsDetailPage`锛夛紱
   *   - 銆屾瓕鍗曘€嶁啋銆屾垜鐨勩€嶉〉閭ｅ紶**姝屽崟鍗?*锛氬崱鍐呯洿鎺ュ垪姝屽崟锛堢偣杩涜鎯?/ 闀挎寜閲嶅懡鍚嵚峰垹闄わ級銆?
   *     鍔ㄤ綔鍖恒€屾柊寤烘瓕鍗曘€嶏紙灏卞湴寮瑰眰锛夈€併€屾瓕鍗曞鍏ャ€嶄笌鍗″ご銆屽叏閮ㄣ€嶁啋 `MinePlaylistPage`
   *     浜岀骇椤碉紙钖勫３锛屾覆鏌撶殑浠嶆槸 `PlaylistsPage` 鏁撮〉锛氭帓搴?/ 瀵煎嚭 / 鏀瑰皝闈?/ 缃戠粶瀵煎叆閮藉湪锛夈€?
   * 鈿狅笍 鎵€鏈変簩绾ч〉閮芥帹**澹冲眰鍏变韩鏍?* `pageIndexInfos`锛坄MinePage` 鑷甫鐨勯偅涓唴灞?Navigation
   *    宸插湪 2026-10-11 绗崄浜岃疆鍒犻櫎锛岀悊鐢辫 `MinePage` 鏂囦欢澶达級銆?
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

    // 鈽?鐢ㄦ埛 2026-10-15锛氥€孴ab 鐨勬帹鑽愬拰鍥炲搷涓棿鍔犱釜**鐜板湪灏卞惉**锛屼笂涓嬫粦鍔ㄥ垏鎹㈡瓕鏇层€傘€?
    //   涓€灞忎竴棣栨瓕銆佺珫鍚?Swiper 鎹㈡瓕锛涙湭鐧诲綍璧板綋鍓嶅钩鍙版鍗曘€佺櫥褰曡蛋璇ュ钩鍙版瘡鏃ユ帹鑽?
    //   锛堜袱鏉￠€氶亾閮藉湪 `NowPlayingFeedPage` 閲岋紝瑙佽鏂囦欢澶达級銆?
    //   鍥炬爣 `sys.symbol.music_note_circle_fill` 涓庡彟澶栦笁鏋氬悓涓?fill 绯伙紙宸插湪鏈満
    //   `sysResource.js` 鐨?symbol 琛ㄩ噷鏍稿疄瀛樺湪锛夈€?
    TabContent() {
      Column() {
        NowPlayingFeedPage({
          // 搴曢儴璁╀綅涓庝笂闈€屾帹鑽愩€嶉〉鍚屼竴鍒ゆ嵁锛圚DS 娴姩鑳跺泭搴曟爮 6.1.1(24)/60100 璧锋墠瀛樺湪锛夛細
          // 56 = 鑳跺泭楂橈紝+16 = `barBottomMargin` 鐨勫父瑙勫€笺€傚畠鍔犲湪**婊戝姩鍗＄墖鑷繁**韬笂锛?
          // 杩欐牱姣忎竴灞忛兘鑳芥濂借翰寮€搴曟爮锛堣 `NowPlayingFeedPage.FEED_DEFAULT_BOTTOM_RESERVE_VP`锛夈€?
          bottomReserveVp: deviceInfo.distributionOSApiVersion >= 60100 ? 56 + 16 : 56,
          scrollTopCommand: this.tabScrollTopCommands[1],
          // 鈽呪槄 2026-10-15 鐢ㄦ埛锛氥€屾垜鍚姩搴旂敤杩囦竴浼氬氨浼氳嚜鍔ㄥ紑濮嬫挱鏀撅紝**鑷姩寮€濮嬫挱鏀剧殑閫昏緫搴旇鏄垜鎵撳紑
          //    閭ｄ釜鐜板湪灏卞惉鐨勯〉闈㈢殑鏃跺€?*銆嶃€傛牴鍥犳槸 `HdsTabs` 鐨?`TabContent` 瀛愰〉闈?*鍚姩鏃跺氨鎸傝浇**
          //    鈬?椤甸潰閲岀殑 `applyRows()` 涓€鍒版暟鎹氨璧锋挱浜嗭紙鐢ㄦ埛杩樺湪棣栭〉锛夈€?
          //    鈬?涓嬪彂**鏈〉鍦ㄥ簳鏍忛噷鐨勪笅鏍?*锛堟槸涓父閲忥級锛岄〉闈㈣嚜宸辫繛 `TabSwitchState` 鍒?鐜板湪鍦ㄤ笉鍦ㄥ睆骞曚笂"
          //      锛坄@Monitor('tabState.tabIndex')`锛夛紝鍙湁鍦ㄥ墠鍙版墠璧锋挱銆?
          //    鈿狅笍 **涓嶈鏀规垚"澹冲眰浼?`isActive: this.tabState.tabIndex === 鈥"**锛欰rkUI V2 鏄?璇绘墠璁㈤槄"锛?
          //      鍒囬〉绛炬椂閲嶇粯鐨勬槸璇讳簡 `tabIndex` 鐨勯偅鍑犱釜 `TabBarItem` 鑺傜偣锛屾湰椤佃繖涓?`@Param`
          //      **涓嶄繚璇佽閲嶆柊姹傚€?* 鈬?`isActive` 浼氫竴鐩村仠鍦ㄥ垵鍊硷紙闈欓粯澶辨晥锛夈€?
          //    鈿狅笍 鍙傛暟鍚?*涓嶈兘鍙?`tabIndex`**锛歚CustomComponent` 鑷繁鏈変竴涓悓鍚嶆柟娉?
          //      锛堥€氱敤灞炴€?`tabIndex(index)`锛夛紝鑷畾涔夌粍浠堕噷鍚屽悕浼?**缂栬瘧澶辫触**锛堟湰鏈哄疄娴嬶細
          //      `Property 'tabIndex' 鈥?is not assignable to the same property in base type 'CustomComponent'`锛夈€?
          barTabIndex: NOW_PLAYING_TAB_INDEX
        })
          .layoutWeight(1)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(1, $r('app.string.tab_now_playing'), $r('sys.symbol.music_round_triangle_fill')))

    // 鈽?鐢ㄦ埛 2026-10-12锛氬簳鏍忎腑闂村姞涓€椤点€屽洖鍝嶃€嶏紙鏈堝害鍚瓕鎶ュ憡锛?
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
            // 鈿狅笍 涓嶈浼?barWidth銆?
            // musicfreeOH 鐨勬诞鍔ㄥ簳鏍忓彧鏈?barBottomMargin / systemMaterialEffect /
            // adaptToHandedness / miniBar 鍥涗釜閿?鈥斺€?娌℃湁 barWidth銆傛垜浠師鏉ヤ紶鐨勪笁妗?
            // 锛坰mallWidth = 绐楀彛瀹?鈭?96 / 284 / 328锛変細璁╂暣鏉″簳鏍忔槑鏄剧獎浜庡睆骞曪紝
            // 銆屼笂涓嬩袱鎺掋€嶆椂涓や晶灏辩暀鍑哄緢澶х┖闅欙紙鐢ㄦ埛鍙嶉鐨勫氨鏄繖涓級銆?
            barBottomMargin: this.homeTabBarBottomMarginVp(),
            // 鈽?杩欐潯鏄?*瀹樻柟鐪熷疄鍏夋劅**锛欻dsTabs 鐨勬诞鍔ㄥ簳鏍忥紙barOverlap + !vertical +
            //   barPosition(End) 涓夋潯浠跺悓鏃舵弧瓒筹級+ `systemMaterialEffect`銆?
            //   妗ｄ綅涓庢爣棰樻爮鍏辩敤 ambientTitleMaterial()锛屼笉瑕佸啀鍦ㄦ湰澶勫唴鑱斾竴濂椾笁鐩€?
            systemMaterialEffect: this.ambientTitleMaterial(),
            // 鏅烘劅鎻″Э锛氳窡闅忔彙鎸佹墜璋冩暣娴姩鏉″乏鍙冲亸缃?
            adaptToHandedness: true,
            miniBar: {
              miniBarBuilder: (): void => {
                this.miniBar();
              },
              // 鈽?鍙屽眰搴曟爮鐨勫叧閿細`barLayoutMode = VERTICAL` 鎵嶆妸杩蜂綘鏉′笌椤电鎺掓垚涓婁笅涓ゆ帓銆?
              //   璇ュ瓧娈垫槸 @since 6.1.1(24)锛屾墍浠ュ伐绋?targetSdkVersion 蹇呴』 鈮?24
              //   锛堟湰椤圭洰宸茬敱 6.1.0(23) 鎻愬埌 6.1.1(24)锛宑ompatibleSdkVersion 淇濇寔 23锛?
              //     璁惧瑕嗙洊涓嶅彉锛夈€備綆閰嶅彂琛岀増涓婁紶 undefined銆?
              //   鈿狅笍銆岀幇鍦ㄥ氨鍚€嶉〉鐢?`barLayoutModeForHds()` 寮哄埗 HORIZONTAL锛堣瀹冨拰
              //     `NOW_PLAYING_TAB_INDEX` 鐨勬敞閲婏級锛氶偅涓€椤典笉璁告湁杩蜂綘鏉￠偅涓€鎺掋€?
              barLayoutMode: this.barLayoutModeForHds(),
              // 鍙楁帶灞炴€э細鎶樺彔鎬?= 绐勮兌鍥婏紝鐐瑰嚮鍚庣敱 onBarStyleChange 閫忓嚭鍐嶅洖鐏?
              // 鈿狅笍 鍗曟帓锛圚ORIZONTAL锛夐厤 `EXPAND` 鏄?*宸茬煡鐨勯敊璇粍鍚?*锛堝簳鏍忎細鍙樻垚
              //   銆岄暱鏉?Tab + 鍦嗗舰鎾斁鍣ㄣ€嶏紝瑙?`onMiniBarStyleChangeFull` 鐨勬敞閲婏級鈬?
              //   鍦ㄣ€岀幇鍦ㄥ氨鍚€嶉〉涓€骞舵妸鏍峰紡鍘嬪洖 `COLLAPSE`銆?
              //
              // 鈽呪槄鈽?2026-10-16锛?*鏂规 A锛氳糠浣犳潯鏀硅嚜缁樿儗鏉?*锛屼慨鐢ㄦ埛瀹炴祴
              //   銆屽叧闂挱鏀惧櫒鍙湁鍐呭浼氬脊锛?*鎾斁鏉¤儗鏅笉寮?*銆嶏級锛?
              //   `enableMiniBarBackground` 鏄?HDS 缁?*杩蜂綘鏉￠偅涓€鍧?*鐨勮儗鏉垮紑鍏?
              //   锛堥〉绛捐兌鍥婇偅鍧楄儗鏉挎槸**鍙︿竴鍧?*锛屼笉鍙楀畠褰卞搷锛夈€?
              //   缃?`false` 鈬?HDS 涓嶅啀缁欒糠浣犳潯鐢昏儗鏉?鈬?鑳屾澘鏀圭敱
              //   `HomeMiniBarPlayer.MiniBarBackplate()` 鑷粯锛屼簬鏄畠涓庡唴瀹瑰湪**鍚屼竴妫靛瓙鏍?*閲岋紝
              //   鑳借窡鐫€ `morphSquashY` 涓€璧峰帇/涓€璧峰脊銆?
              //   鈿狅笍 涓?`HomeMiniBarPlayer` 閲岄偅涓€灞?*蹇呴』鎴愬**锛氬彧鍏充笉鐢?鈬?杩蜂綘鏉″簳涓嬬┖涓€鍧椼€?
              enableMiniBarBackground: false,
              miniBarStyle: this.miniBarStyleForHds(),
              onBarStyleChange: (miniBarStyle: HdsBarStyle, _tabStyle: HdsBarStyle,
                _miniWidth: number, _tabWidth: number, mode: HdsTabsBarChangeMode): void => {
                this.onMiniBarStyleChangeFull(miniBarStyle, mode);
              }
            }
          })
          .onChange((index: number) => {
            if (index !== this.tabState.tabIndex) {
              this.tabState.tabIndex = index;
              // 鍒囧埌鏂伴〉绛撅細閫変腑鎬佸脊涓€涓嬶紙鐐瑰嚮涓庢粦鍔ㄥ垏鎹㈤兘浼氳蛋杩欓噷锛?
              this.playTabBounce(index);
              // 鈽?杩蜂綘鏉℃樉闅愯瘖鏂紙`hdc shell hilog | grep RzdMiniBarHide`锛夛細
              //   鍒囧埌銆岀幇鍦ㄥ氨鍚€嶅簲鎵撳嚭 `hidden=true barLayout=HORIZONTAL style=COLLAPSE`锛?
              //   鍒囧洖鏉ュ簲鎵撳嚭 `hidden=false`銆傚彧鑳界湅鏃ュ織锛屾棤璁惧楠岃瘉銆?
              Logger.info(RzdShellLogTag,
                `RzdMiniBarHide tab=${index} hidden=${index === NOW_PLAYING_TAB_INDEX} ` +
                  `barLayout=${this.barLayoutModeForHds()} style=${this.miniBarStyleForHds()} ` +
                  `navDepth=${this.navDepth}`);
            }
          })
          // 鐐归〉绛撅細鐐圭殑鏄?*褰撳墠**椤电鏃跺洖鍒伴《閮紙鍒囬〉绛句氦缁?onChange锛?
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
      // 鎾斁椤?*涓嶅啀鐢?`bindContentCover`**锛氱洿鎺ヤ綔涓烘湰 Stack 鐨勬诞灞傛寕杞斤紙瑙佷笅闈㈤偅娈垫敞閲婏級銆?
      // 妯℃€侀偅鏉¤矾璧拌繃寰堜箙锛岀粨璁烘槸瀹冨拰"浠庤糠浣犳潯闀垮嚭鏉?鐨勫舰鍙樻牴鏈笉鍏煎锛?
      //   路 `ModalTransition.DEFAULT` 鑷甫"浠庡簳閮ㄦ帹涓婃潵"鐨勪綅绉伙紝浼氬拰褰㈠彉鐨勪綅绉诲彔鍔狅紱
      //   路 `ModalTransition.NONE` 铏界劧娌℃湁浣嶇Щ锛屼絾妯℃€佸涓绘槸涓嶉€忔槑鐨勪竴灞傦紝
      //     鎶婇椤靛拰杩蜂綘鏉″叏鐩栦綇锛堝舰鍙樿閫忓嚭鏉ョ殑姝ｆ槸瀹冧滑锛夛紝浜庢槸鍙墿"榛戝簳 + 涓嬫柟绌虹櫧"銆?
      .onNavBarStateChange((isVisible: boolean): void => {
        // 姣忔瀵艰埅鏍忓彲瑙佹€у彉鍖栭兘鍒锋柊鏍堟繁搴︼紙鎺ㄥ叆/寮瑰嚭浜岀骇椤甸潰閮戒細瑙﹀彂锛?
        this.syncNavDepth();
      })

      // 鈽?鎾斁椤碉細**涓嶇敤妯℃€侊紝鐩存帴鎸傚湪澹冲眰鐨?Stack 閲?*锛堝鏍囨棤鐣岋細鎾斁椤典笌棣栭〉鍦ㄥ悓涓€涓?
      //   瑙嗗浘鏍戦噷锛汸C 澹冲眰鏈潵灏辨槸杩欎箞鎸傜殑锛夈€?
      //
      // 涓轰粈涔堟妸 `bindContentCover` 鎹㈡帀锛堜笁涓敤鎴峰疄娴?bug 鐨勬牴鍥犻兘鍦ㄨ繖閲岋級锛?
      //   1. 妯℃€佺殑瀹夸富鏄?*涓嶉€忔槑**鐨勪竴灞傦紝瀹冪洊浣忎簡棣栭〉鍜岃糠浣犳潯 鈥斺€?鑰屽舰鍙樼殑瑙傛劅闈犵殑姝ｆ槸
      //      "杩蜂綘鏉″湪閭ｃ€佸畠鎱㈡參鍙樺ぇ"锛氳糠浣犳潯琚洊浣忓悗锛屽墿涓嬬殑灏辨槸"涓€鍧楅粦鑳屾櫙 + 涓嬫柟绌虹櫧"
      //      锛堟ā鎬佽嚜宸辩殑搴曡壊锛夛紝璺熸棤鐣岀殑"鎾斁鏉￠€愭笎鍙樺ぇ"瀹屽叏涓嶆槸涓€鍥炰簨锛?
      //   2. 褰㈠彉鏃╂湡鍙鐭╁舰鍙湁杩蜂綘鏉″皝闈㈤偅涔堝ぇ锛屾ā鎬佸叾浣欓儴鍒嗘槸妯℃€佸簳鑹诧紝涓嶆槸棣栭〉
      //      鈥斺€?浜庢槸灞忓箷涓婃槸涓€鍧楅粦銆佷竴鍧楃┖锛?
      //   3. 鎵嬪娍锛氭ā鎬佸湪 `isShowPlay=false` 鏃舵牴鏈笉瀛樺湪锛堜笂鎷夋墦寮€蹇呴』鍦ㄥ３灞傦級锛?
      //      鑰屽畠瀛樺湪鏃跺張浼氭妸澹冲眰鐨勬墜鍔垮叏鍚冩帀锛屽鑷磋窡鎵嬮€昏緫涓ゅご鍙楀埗銆?
      //   鎸傚湪澹冲眰 Stack 閲屽氨娌℃湁杩欎簺闂锛氫笅灞傜殑棣栭〉/杩蜂綘鏉¤繕鍦ㄧ敾锛屽舰鍙樼殑閫忔槑鍖哄煙
      //   閫忓嚭鏉ョ殑灏辨槸棣栭〉 鈥斺€?"鎾斁鏉￠€愭笎鍙樺ぇ銆侀鑹查€愭笎鍙樻垚鑳屾櫙銆佹參鎱㈡嫇灞曞埌鏁村睆"銆?
      //
      // 绯荤粺杩斿洖涓嶅啀鐢辨ā鎬佺殑 `onWillDismiss` 鎷︿簡锛屾敼鐢辨湰椤电殑 `onBackPress` 鎷︼紙瑙佹枃浠舵湯灏撅級銆?
      //
      // 鈿狅笍 `PLAYER_ROUTE_MODE = true` 鏃惰繖涓€娈?*涓嶆覆鏌?*锛氭挱鏀鹃〉鐢?NavDestination 璐熻矗
      //    锛堣 pushPlayerRoute锛夈€備袱鏉¤矾閮戒繚鐣欙紝鍥為€€鍙渶鏀逛笂闈㈤偅涓父閲忋€?
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
        // 鐩栦綇 HdsTabs锛堝畠鑷繁鏄?zIndex(1)锛変笌浜岀骇椤甸潰鐨勬偓娴糠浣犳潯
        .zIndex(PLAYER_OVERLAY_Z_INDEX)
        .id('rzd_player_overlay_viewport')
        .onAreaChange((_oldArea: Area, area: Area): void => {
          Logger.info('RzdPlayerViewport', `overlay=${area.width}x${area.height} window=${this.viewportWidthVp}x${this.viewportHeightVp} top=${this.windowInfo.statusBarTopVp} bottom=${this.windowInfo.navigationBarBottomVp}`);
        })
      }

      // 鈽?褰㈠彉**鍏嬮殕灞?*锛堝鏍囧弽缂栬瘧閲?`MainPage` 涓婇偅涓変釜 lambda锛氬皝闈㈠厠闅?/ 鍏冧俊鎭厠闅?/
      //   鎿嶄綔鍖哄厠闅嗭級銆傚弽缂栬瘧鏄庣‘锛氬厠闅嗗眰鎸傚湪 **MainPage**锛堝３灞傦級鑰屼笉鏄挱鏀鹃〉锛?
      //   鑰屼笖鏄?鐢讳竴涓壇鏈?銆佷笉鏄粰鐪熷疄灏侀潰鍔?transform銆?
      //   瀹冨繀椤诲湪**鎾斁椤垫诞灞備箣涓?*锛氳糠浣犳潯鐪熻韩鍦ㄦ诞灞備箣涓嬶紝鑳屾櫙涓€涓嶉€忔槑灏辫鐩栨帀浜嗭紝
      //   鎵€浠?璧风偣鐪嬭捣鏉ヨ繕鏄偅鏉¤糠浣犳潯"闈犵殑灏辨槸杩欎竴灞傚壇鏈€?
      //
      // 鈿狅笍 娓叉煋闂ㄧ敤 `morphSessionDriving()`锛?*鐪熺殑鍦ㄦ挱**锛夛紝涓嶆槸 `morphContainerActive()`锛?
      //    鐐瑰嚮鎵撳紑浼氬厛杩?ENTERING銆佸啀閲嶈瘯鏈€澶?12脳32ms锛堚増400ms锛夌瓑缁堢偣閿氱偣灏辩华锛?
      //    杩欐"鍋囧姩鐢?閲屽舰鍙樺叾瀹炶繕娌″紑濮嬶紝浣?`morphP` 宸茶鍘嬪埌 0 鈬?
      //    `actionsOpacityAt(0) = 1` 鈬?鍏嬮殕灞傚叏浜湴鎸傚湪灞忎笂婕?鈥斺€?
      //    鐢ㄦ埛瀹炴祴鐨?涓変釜鎸夐挳涓€鐩存紓绉?灏辨槸杩欎竴娈点€?
      if (this.expandState.morphSessionDriving() && this.expandState.asideWinW > 0) {
        this.MorphMiniBarClone()
      }
      MorphMetaBridge()
        .zIndex(PLAYER_CLONE_Z_INDEX)
        .hitTestBehavior(HitTestMode.None)

      // 鈽呪槄 绗笁浠芥嫹璐?= **缁灏侀潰**锛?026-10-15 浠庢挱鏀鹃〉鎼潵鐨勯偅涓€妫掞級銆?
      //    瀹冩湁鑷繁鐨勬椂闂寸嚎锛坄morphOverlayP`锛?60ms + 蹇嚭鎱㈡敹锛夛紝涓庡彟涓や唤鍚屽眰锛坺Index 110锛夈€?
      //    椤剁偣/缁堢偣閲忔祴涓庡彟澶栦袱浠藉悓婧愶紙`reportMini` / `reportBig`锛夛紝鎵€浠ヤ笁鑰呮槸涓€璧疯蛋鐨勩€?
      //    娓叉煋闂ㄥ啓鍦?builder 閲岋紙`morphOverlayBridging()`锛夈€?
      if (this.expandState.morphOverlayBridging()) {
        this.MorphCoverClone()
      }

      // 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`MainPage` 鐨?`If (shrink.visible && shrinkPixmap)`锛夛細
      //   銆岄潪鎵嬪娍鍏抽棴銆嶉偅涓€妫掞細涓€寮犳弧绐楀揩鐓х缉鍒拌糠浣犳潯鑳跺泭 + 娣″嚭銆?
      //   鏀惧湪**鏈€涓婇潰**锛坺Index 130锛夛細瀹冨氨鏄?姝ｅ湪娑堝け鐨勯偅涓€灞忔挱鏀鹃〉"銆?
      this.ShrinkOverlayHost()

      // 鍏ㄥ眬鎮诞杩蜂綘鎾斁鏉★細鍙湪浜岀骇椤甸潰娓叉煋锛堥椤甸偅浠藉湪 HDS 娴姩搴曟爮閲岋級銆?
      // 鏉′欢娓叉煋鑰屼笉鏄父椹?+ visibility 鈥斺€?甯搁┗鐨勬暣灞忛€忔槑鑺傜偣浼氬悆鎺夊簳鏍忔墜鍔裤€?
      if (this.shouldShowFloatingMiniBar()) {
        this.floatingMiniBar()
      }

      // Persistent hidden LX source engine host (webview sandbox for user API scripts).
      LXSourceHost()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 褰㈠彉瀹夸富锛歚getRectangleById(MORPH_HOST_ID)` 閲忕殑灏辨槸杩欏眰鐨勬覆鏌撶煩褰?
    .id(MORPH_HOST_ID)
    // 鈽?涓婃媺鎵撳紑鎾斁椤碉紙璺熸墜锛屽鏍囨棤鐣?ExpandAnimation.applyPullProgress锛夈€?
    //   蹇呴』鎸傚湪**澹冲眰**锛氭挱鏀鹃〉鍦?`isShowPlay` 涓?false 鏃惰繕娌℃寕杞斤紝鏀朵笉鍒版墜鎸囦簨浠躲€?
    //   涓庢挱鏀鹃〉閲岀殑涓嬫媺鏀惰捣鏂瑰悜鐩稿弽锛屼袱鏉℃墜鍔夸簰涓嶅啿绐侊紱
    //   骞朵笖鍙湁"浠庡睆骞曚笅鍗婇儴鍒嗚捣鎵?鎵嶆帴绠★紝涓棿鍖哄煙鐨勪笂婊戠収鏃т氦缁欏垪琛?姝岃瘝婊氬姩銆?
    .gesture(
      PanGesture(this.pullOpenOption)
        .onActionStart((event: GestureEvent): void => {
          this.onPullOpenStart(event.fingerList);
        })
        .onActionUpdate((event: GestureEvent): void => {
          this.onPullOpenUpdate(event.offsetY);
        })
        .onActionEnd((event: GestureEvent): void => {
          // 鈽?閫熷害椤逛篃瑕佷紶杩涘幓锛堟竻鍗?搂涓€ 1.2銆岃繘搴?OR 閫熷害銆嶏紱鍒ゆ嵁鍦?
          //   `PlayerExpandState.pullOpenShouldCommit()` 閲岋紝鏂瑰悜鐢变綅绉诲垽銆佸ぇ灏忓彇 abs锛?
          this.onPullOpenEnd(event.offsetY, event.velocityY);
        })
        .onActionCancel((): void => {
          this.onPullOpenCancel();
        })
    )
    // 绐楀彛灏哄鍙樺寲锛堟姌鍙犲睍寮€ / PC 娴獥鎷栨嫿锛夋椂鍒锋柊鎮诞鏉＄畻瀹界敤鐨勮鍙ｅ搴?
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      // 鈿狅笍 瑙嗗彛瀹介珮锛堟墜鍔块槇鍊肩敤锛変粛鐒跺彧鐢?`syncViewportWidthVp` 浠?windowSize 鍙栨暣绐楀彛寰勶紝
      //    杩欓噷**涓嶈**鍐嶆寜鏈鍣ㄧ殑楂樺害瑕嗙洊瀹冿細閭ｆ槸"鍐呭鍖洪珮搴?锛屼笌 `globalY`锛堢獥鍙ｅ潗鏍囷級
      //    涓嶆槸涓€涓彛寰勶紝娣风敤浼氳"浠庝笅鍗婂睆璧锋墜"鐨勫垽瀹氬亸绉诲嚑鍗?vp銆?
      this.syncViewportWidthVp();
      // 鈽?褰㈠彉鍑犱綍鐨?*灏哄**鍙湁鍞竴鐨勬潈濞佹潵婧愶細**绐楀彛灏哄**銆?
      //   鈿狅笍 鍗冧竾鍒嬁鏈鍣紙鎴栦换浣曞弬涓庡舰鍙樼殑灞傦級鐨勫疄娴嬮珮搴﹀綋"閾烘弧鐩爣"锛氶偅绉嶈嚜鍣凡缁?
      //      韪╄繃涓夋锛堝簳閮ㄧ己涓€鍧?/ 涓€鍧楄繎姝ｆ柟褰㈣儗鏅?/ 榛戝簳灞曚笉寮€锛夆€斺€?琚舰鍙樼殑閭ｅ眰锛?
      //      瀹冭嚜宸辩殑灏哄灏辨槸瑁佸壀绐楀彛锛屽杺鍥炲幓绛変簬璁╃洰鏍囪拷鐫€鑷繁鐨勪腑闂存€佽窇銆?
      //      鏈鍣ㄥ彧鍦?*闈欐鎬?*鎵嶇瓑浜庣獥鍙ｅぇ灏忥紝褰㈠彉鏈熼棿骞朵笉绛変簬锛屾墍浠ヨ繛瀹冧篃涓嶈兘淇°€?
      this.expandState.reportWindow(this.viewportWidthVp, this.viewportHeightVp,
        this.windowInfo.statusBarTopVp, this.windowInfo.navigationBarBottomVp);
      this.expandState.updateChromeTier(this.viewportWidthVp);
    })
  }

  /**
   * 绯荤粺杩斿洖锛堣繑鍥為敭 / 杩斿洖鎵嬪娍锛夛細鎾斁椤靛紑鐫€灏卞厛鎾敹璧峰姩鐢伙紝骞?*娑堣垂鎺?*杩欐杩斿洖銆?
   *
   * 鈿狅笍 浠ュ墠杩欎竴姝ユ槸妯℃€佺殑 `onWillDismiss` 骞茬殑锛涙挱鏀鹃〉鏀规垚澹冲眰 Stack 閲岀殑鏅€氭诞灞備箣鍚庯紝
   *    蹇呴』鍦ㄨ繖閲屾嫤锛屽惁鍒欒繑鍥炰細鐩存帴閫€鍑哄簲鐢紙鎴栬€呮妸鎾斁椤靛簳涓嬬殑浜岀骇椤甸潰寮规帀锛夈€?
   * @returns true = 宸叉秷璐癸紝涓嶅啀璧伴粯璁よ繑鍥為€昏緫
   */
  onBackPress(): boolean {
    if (!this.appState.isShowPlay) {
      return false;
    }
    // 鐪熸鐨勬敹璧峰姩鐢荤敱鎾斁椤垫挱锛堝畠鐩戝惉 collapseVersion锛夛紝鎾畬鑷繁鎶?isShowPlay 缃?false
    this.expandState.requestCollapse();
    return true;
  }

  /**
   * 鍚屾瀵艰埅鏍堟繁搴︺€?
   *
   * 鏀惧湪 `onNavBarStateChange` 鐨勪笅涓€甯э細璇ュ洖璋冭Е鍙戞椂鏍堝彲鑳借繕娌″畬鎴愭帹鍏ワ紝
   * 绔嬪埢璇?`size()` 浼氭嬁鍒版棫鍊硷紝瀵艰嚧杩蜂綘鏉′笉鍑虹幇 / 涓嶆秷澶便€?
   *
   * 鈿狅笍 **涓嶈鍖?animateTo**锛歚animateTo` 浼氭妸"鑺傜偣鍒氳鍒涘缓"杩欎欢浜嬩篃涓€璧疯ˉ闂?鈥斺€?
   * 澹冲眰鎮诞杩蜂綘鏉℃槸鏉′欢娓叉煋鍑烘潵鐨勬柊鑺傜偣锛屽寘杩涘姩鐢诲氨鎴愪簡娣″叆锛岀敤鎴锋槑纭笉瑕併€?
   * 杩蜂綘鏉＄殑鏄鹃殣蹇呴』涓€甯у唴鐩存帴鍒囨崲锛涢渶瑕佸姩鏁堢殑鍙湁 `miniBarExpanded` 鐨勬敹璧枫€?
   */
  private syncNavDepth(): void {
    setTimeout((): void => {
      // 鈽?`navDepth` 鐨勫彛寰勬槸"**浜岀骇椤甸潰**娣卞害"锛?*涓嶅惈鎾斁椤?*锛?
      //   褰㈠彉鍏ュ彛鏀规垚 NavDestination 涔嬪悗鎾斁椤佃嚜宸卞崰涓€鏍兼爤娣憋紝濡傛灉鎶婂畠绠楄繘鏉ワ紝
      //   锛?锛夋挱鏀鹃〉搴曚笅浼氬嚟绌哄啋鍑轰竴鏉℃偓娴糠浣犳潯锛坄shouldShowFloatingMiniBar`锛夛紝
      //   锛?锛夎繘鎾斁椤典細鎶婄敤鎴峰睍寮€鐨勮糠浣犺兌鍥婂己琛屾敹鍥炴姌鍙犳€侊紙涓嬮潰閭ｆ锛夛紝
      //   涓ゆ潯閮戒細鐮村潖褰㈠彉鐨勮捣鐐瑰嚑浣曘€傛墍浠ョ粺涓€鍦ㄨ繖閲屾墸鎺夈€?
      const playerIdx: number = this.playerRouteIndex();
      const depth: number = this.pageIndexInfos.size() - (playerIdx >= 0 ? 1 : 0);
      if (depth === this.navDepth) {
        return;
      }
      const previousDepth: number = this.navDepth;
      this.navDepth = depth;
      if (depth > 0) {
        // 鈽?杩涗簩绾ч〉闈?*涓嶅啀**鎶婅糠浣犳潯寮鸿鏀跺洖鎶樺彔鎬侊紙鏃ф柟妗堬級銆?
        //   鏃ф柟妗堬細`miniBarExpanded = false` 鑰?`hdsBarLayoutMode` 淇濇寔 HORIZONTAL
        //   鈬?HDS 杩涘叆銆岄暱鏉ab + 鍦嗗舰鎾斁鍣ㄣ€嶈繖绉嶉敊璇粍鍚堬紝搴曟爮鍔ㄧ敾鐪嬬潃灏变笉瀵癸紝
        //   杩樺緱鍦ㄩ€€鍑轰簩绾ч〉闈㈡椂鍐嶇籂姝ｅ洖銆岄暱鏉℃挱鏀惧櫒 + 鍦嗗舰Tab銆嶃€?
        //   鐜板湪淇濇寔 (barLayoutMode, miniBarExpanded) 杩欎竴瀵规湰鏉ュ氨涓€鑷寸殑鐘舵€佷笉鍔細
        //     HORIZONTAL + EXPAND 浠嶆槸銆岄暱鎾斁鍣?+ 鍦員ab銆嶏紱VERTICAL + COLLAPSE 浠嶆槸鍙屽眰銆?
        //   浜岀骇椤甸潰涓婄殑鎾斁鍣ㄧ敱澹冲眰鎮诞鏉¤礋璐ｆ樉绀猴紙瑙?shouldShowFloatingMiniBar锛夈€?
        Logger.info(RzdShellLogTag,
          `enter secondary depth=${depth} keep mode=${this.appState.hdsBarLayoutMode} expanded=${this.appState.miniBarExpanded}`);
      } else if (previousDepth > 0) {
        // 鍑轰簩绾ч〉闈細鐘舵€佸叏绋嬫病琚敼杩囷紝杩欓噷鍙窡 HDS 閲嶆柊瀵归綈涓€娆★紙骞傜瓑锛屼笉浜х敓"绾犳"璺冲彉锛?
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
