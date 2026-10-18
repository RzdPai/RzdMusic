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

import { Logger } from '../util/Logger';
import { curves, UIContext } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { MorphMetaEndpoint, MorphMetaFrame } from './MorphMetaGeometry';

/**
 * 杩蜂綘鏉″皝闈㈢殑缁勪欢 id銆?
 *
 * 鈿狅笍 甯搁噺蹇呴』鏀惧湪鍏叡灞傦細杩蜂綘鏉″湪 `features/playlist`銆佸姩鐢诲涓诲湪 `features/player`锛?
 * 涓よ竟瑕佺敤鍚屼竴涓瓧绗︿覆锛岃€?features 涔嬮棿**绂佹浜掔浉 import**锛堜笁灞傛灦鏋勭‖绾︽潫锛夈€?
 */
export const MINI_BAR_COVER_ID: string = 'rzd_mini_bar_cover';

/** 鎾斁椤靛ぇ灏侀潰鐨勭粍浠?id锛堝悓涓婏紝鏀惧叕鍏卞眰閬垮厤 features 妯悜渚濊禆锛夈€?*/
export const PLAYER_BIG_COVER_ID: string = 'rzd_player_big_cover';

/**
 * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`PLAYER_ROOT_ID`锛夛細**褰㈠彉瀹瑰櫒**锛堝甫 `.scale/.translate/.clip` 閭ｄ釜鑺傜偣锛夌殑 id銆?
 *
 * 鐢ㄩ€斿彧鏈変竴涓細闈炴墜鍔垮叧闂紙鍏抽棴鎸夐挳 / 绯荤粺杩斿洖锛夋椂
 * `componentSnapshot.get(PLAYER_ROOT_ID, 鈥?` **鎷嶇殑灏辨槸杩欎釜鑺傜偣**锛?
 * 鎷嶅埌鐨勫浘浜ょ粰 `MorphShrinkState`锛堢収鎼?`ShrinkOverlay`锛夌缉鍒拌糠浣犳潯鑳跺泭銆?
 * 鍑哄锛歚wujie.pa:191470-191478` 鐨?`.id(PLAYER_ROOT_ID)`
 *   锛堟寕鍦?`.scale` 191400-191415 / `.translate` 191416-191431 / `.clip` 191462-191469 涔嬪悗锛夈€?
 *
 * 鈿狅笍 涓?`PLAYER_BIG_COVER_ID` / `MESH_BG_ID` 绛?*涓嶆槸鍚屼竴涓妭鐐?*锛坕d 鎸夎妭鐐瑰敮涓€锛屽嚑涓簰涓嶅奖鍝嶏級銆?
 * 鈿狅笍 蹇収**蹇呴』**鍦ㄥ舰鍙樺紑濮嬩箣鍓嶆媿锛堥潤姝㈡€佷笅杩欎釜鑺傜偣灏辨槸婊″睆鐨勬挱鏀鹃〉锛夈€?
 */
export const PLAYER_ROOT_ID: string = 'rzd_player_root';

/**
 * 褰㈠彉闃舵锛堝鏍囨棤鐣?`MorphState.MorphStage`锛夈€?
 *
 * ```
 *   NONE 鈫?ENTERING锛堝睍寮€涓紝鍙窡鎵嬶級鈫?OPEN锛堝凡灞曞紑锛夆啋 LEAVING锛堟敹璧蜂腑锛夆啋 LANDING锛堣惤鍥炶糠浣犳潯锛?
 * ```
 */
export enum MorphStage {
  NONE = 0,
  ENTERING = 1,
  OPEN = 2,
  LEAVING = 3,
  LANDING = 4
}

/** 璋佸湪椹卞姩褰㈠彉锛堝鏍?`MorphState.MorphDrive`锛夈€?*/
export enum MorphDrive {
  NONE = 0,
  /** 鎵嬫寚椹卞姩锛氭鏈熼棿**涓嶈兘**璺戜换浣曠粰鍚屼竴鎵瑰睘鎬у仛琛ラ棿鐨?animateTo銆?*/
  FINGER = 1,
  ANIM = 2
}

/** clip 绐楀彛鍦ㄩ潤姝㈡€佸悜澶栨墿寮犵殑浣欓噺锛坴p锛夛細淇濊瘉浠讳綍绐楀彛灏哄閮戒笉浼氳鍒板唴瀹广€?*/
const CLIP_IDLE_MARGIN_VP: number = 120;

/** 杩蜂綘鏉￠偅鏉¤兌鍥婄殑缁勪欢 id锛堝睍寮€鍔ㄧ敾鐨勮捣鐐圭煩褰㈢敱瀹冮噺鍑烘潵锛夈€?*/
export const MINI_BAR_ID: string = 'rzd_mini_bar';

/** 浜岀骇椤甸潰鎮诞杩蜂綘鏉＄殑缁勪欢 id锛堜笌棣栭〉閭ｆ潯鍖哄垎锛岄伩鍏?id 閲嶅悕閲忛敊锛夈€?*/
export const MINI_BAR_FLOATING_ID: string = 'rzd_mini_bar_floating';

/** 浜岀骇椤甸潰鎮诞杩蜂綘鏉″皝闈㈢殑缁勪欢 id锛堥椤甸偅鏉＄敤 {@link MINI_BAR_COVER_ID}锛夈€?*/
export const MINI_BAR_COVER_FLOATING_ID: string = 'rzd_mini_bar_cover_floating';

/** 瀹夸富瀹瑰櫒锛堟亽涓烘弧灞忕殑閭ｅ眰锛夌殑缁勪欢 id锛氬畠鐨勭獥鍙ｇ煩褰㈠氨鏄?閾烘弧"鐨勭洰鏍囦笌鍧愭爣鍘熺偣銆?*/
export const MORPH_HOST_ID: string = 'rzd_morph_host';

/**
 * 鍙鐭╁舰"涓嬭竟鍏堣创搴?鐨勮繘搴︾偣锛?鈥?锛夈€?
 *
 * 杩蜂綘鏉＄瀹夸富搴曡竟杩樻湁鍑犲崄 vp锛圚DS 娴姩搴曟爮鐨勪笅杈硅窛 + 绯荤粺瀵艰埅鏍忛偅涓€鏉★級锛?
 * 杩欎釜绌烘。涓嶈兘璺熺潃绾挎€ц蛋锛氬惁鍒欐暣娈靛姩鐢诲簳閮ㄩ兘鏄┖鐨勶紙鐢ㄦ埛瀹炴祴锛夈€?
 */
/**
 * 杩蜂綘鏉＄殑**鍏冧俊鎭?+ 鎿嶄綔鍖?*锛堟瓕鍚?姝屾墜 + 鎾斁鎸夐挳閭ｄ竴鍧楋級鐨勭粍浠?id銆?
 *
 * 鍙嶇紪璇戜晶 `MainPage` 涓婃湁涓変釜鍏嬮殕灞傦細灏侀潰鍏嬮殕銆佸厓淇℃伅鍏嬮殕銆佹搷浣滃尯鍏嬮殕 鈥斺€?
 * 瀹冧滑閮藉洿鐫€杩欎竴鍧楃敾锛坄miniMeta` / `morphActionsRect`锛夛紝鎵€浠ヨ鑳介噺鍒板畠鐨勭煩褰€?
 */
export const MINI_BAR_ASIDE_ID: string = 'rzd_mini_bar_aside';

/** 浜岀骇椤甸潰鎮诞杩蜂綘鏉＄殑閭ｄ竴鍧楋紙涓庨椤靛尯鍒嗭紝閬垮厤 id 閲嶅悕閲忛敊锛夈€?*/
export const MINI_BAR_ASIDE_FLOATING_ID: string = 'rzd_mini_bar_aside_floating';

/**
 * 缁灏侀潰锛堝弽缂栬瘧渚х殑 `snap*`锛変袱绔偣鐨勯噺鍙栧叆鍙?id銆?
 * 鎾斁椤靛皝闈㈠凡缁忕敤 `PLAYER_BIG_COVER_ID`锛岃繖閲屽彧闇€瑕佽糠浣犳潯閭ｄ竴渚с€?
 */
const MINI_COVER_MEASURE_FALLBACK: number = 0.79;

/**
 * 涓€涓粍浠跺湪绐楀彛閲岀殑鐭╁舰锛坴p锛夈€俙x/y` 鏉ヨ嚜 FrameNode 鐨勭獥鍙ｅ潗鏍囷紝`w/h` 宸蹭粠 px 鎹㈢畻銆?
 * 鍙嶇紪璇戜晶瀵瑰簲 `ComponentRect.getRectByFrameNode`锛氫綅缃敤
 * `getPositionToWindowWithTransform()`锛坴p锛夛紝灏哄鐢?`getMeasuredSize()`锛坧x鈫抳p锛夈€?
 */
interface NodeRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/**
 * 鍙嶇紪璇戜晶 `initParams` 鐨勪笁涓?lerp 璧风偣鍊硷紙杩欓噷鍗曠嫭瀛橈紝鍜屽畠鐨勫瓧娈典竴涓€瀵瑰簲锛夈€?
 * `applyPullProgress` 鍙湪杩欎笁涓€?+ `t` 涓婂仛绾挎€ф彃鍊笺€?
 */
interface MorphInitParams {
  /** `initScale = box.width / 鐩掑`銆?*/
  scale: number;
  /** `initClipHeight = box.height / initScale`銆?*/
  clipHeight: number;
  /** `initTranslateX = box.left - (鐩掑 - box.width) / 2`銆?*/
  translateX: number;
  /** `initTranslateY = box.top - scaledH * (1 - initScale) / 2`銆?*/
  translateY: number;
  /** 璧风偣**鍙**鍦嗚 = `initClipHeight * initScale / 2`锛? 鑳跺泭楂樺害鐨勪竴鍗婏級銆?*/
  radius: number;
}

/** 銆屽睍寮€椤?鈬?姝岃瘝椤点€嶇画椋炴椂灏侀潰鐨勪竴甯х煩褰紙vp锛岀獥鍙ｅ潗鏍囷級銆?*/
export interface LyricMorphRect {
  x: number;
  y: number;
  size: number;
  /**
   * 楂樺害锛坴p锛夈€?
   *
   * 鈿狅笍 蹇呴』涓?`size` 鍒嗗紑瀛橈細鎾斁椤靛皝闈㈢殑瀹瑰櫒鏄?`layoutWeight(1)` + `constraintSize(maxWidth/maxHeight)`
   *    + `aspectRatio(1)`锛?*鎺掑竷涓婁笉淇濊瘉閲忓埌鐨勭煩褰㈡槸姝ｆ柟褰?*銆傛寜 `h = w` 鐢诲嚭鏉ョ殑缁灏侀潰
   *    浼氬湪 p=1 浜ゆ缁欑湡瀹炲皝闈㈢殑閭ｄ竴鍒昏烦涓€涓嬶紙浣嶇疆涓庡ぇ灏忛兘瀵逛笉涓婏級銆?
   */
  height: number;
  radius: number;
}

/**
 * 瀹藉睆 / 闈㈡澘閭ｇ"宸﹀彸涓ゆ爮"甯冨眬閲岋紝涓ゆ爮鐨勭洰鏍囧搴︼紙vp锛夈€?
 *
 * 鈽?2026-10-15锛堢洰鏍?鈶?鐨?S2 姝ワ級锛?*鍙瀹藉害锛屼笉瑁呴棿璺?* 鈥斺€?闂磋窛锛坄gutter` / `space`锛?
 * 鐢辨帴绾跨殑鍚屼竴澶勫父閲忕粰鍑猴紝涓嶅湪杩欓噷鐚滐紙渚濇嵁瑙?`PlayerExpandState.columnWidths()` 鐨勬敞閲婏級銆?
 */
export interface WideColumns {
  /** 宸︽爮锛堝皝闈?+ 姝屽悕锛夌洰鏍囧搴︼紙vp锛夈€?*/
  left: number;
  /** 鍙虫爮锛堟瓕璇?+ 鎺у埗鍖猴級鐩爣瀹藉害锛坴p锛夈€?*/
  right: number;
}

/**
 * 瀹夸富鐩掑唴鐨勪竴涓偣锛坴p锛夈€傝 `PlayerExpandState.toHostPoint()`銆?
 *
 * 鈽?2026-10-15锛堢洰鏍?鈶?鐨?S3 鍓嶇疆浠讹級锛歚.position()` 鏄?*鐩稿鐖剁粍浠跺唴瀹圭洅**鐨勭粷瀵瑰畾浣嶏紝
 * 鑰屾垜浠殑娴眰鍑犱綍婧愶紙`lyricMorph` / `widePlayerRects`锛夌粰鐨勬槸**绐楀彛鍧愭爣** 鈬?
 * 鎹㈠涓绘椂蹇呴』鍑忔帀瀹夸富鑷繁鐨勫乏涓婅銆傛墜鏈哄涓诲乏涓婅 = 绐楀彛鍘熺偣 鈬?鏈粨鏋勬亽涓?`{0, 0}`銆?
 */
export interface HostPoint {
  x: number;
  y: number;
}

/**
 * 鏃犵晫 `PlayerChrome` 鐨勪竴妗ｆ帶鍒跺尯灏哄琛紙**閫愬瓧娈电収鎶?* `wujie.pa:93534 / 93554 / 93574`锛夈€?
 *
 * 瀛楁椤哄簭涓庡弽姹囩紪閲?`createobjectwithbuffer` 鐨勪功鍐欓『搴忎竴鑷达紙`total` 闄ゅ 鈥斺€?瀹冩槸绠楀嚭鏉ョ殑锛?
 * 鑰屼笖**涓嶆槸**"鍓嶉潰鍑犻」鐩稿姞"锛歚wujie.pa:93547-93551` 閲?`v2 = 58` 鏄笁妗ｅ叡鐢ㄧ殑绗簲椤癸級銆?
 *
 * 鈿狅笍 涓嶈缁欎换浣曞瓧娈?琛ヤ竴涓悎鐞嗗€?锛氳〃閲屾病鏈夌殑璇箟锛堜緥濡?缁熶竴鐨勬寜閽棿璺?锛夎鏄?*鏃犵晫娌℃湁瀹?*锛?
 *   鍘嗗彶涓婃垜浠線杩欑被缂哄彛閲屽杩?`18/24/30`锛屽悗鏉ユ暣鏃忓垹闄わ紙瑙?`PlayerExpandState` 閲?
 *   `chromeGapVp` / `chromePaddingVp` 鐨勫垹闄よ褰曪級銆?
 */
export class PlayerChromeSpec {
  /** 椤舵爮閭ｄ竴琛岀殑楂樺害锛坴p锛夈€?*/
  public readonly topBarH: number;
  /** Swiper 涓庢帶鍒跺尯涔嬮棿鐨?*鍗犱綅鏉?*楂樺害锛坴p锛夈€傗殸锔?琛ㄩ噷杩欎竴浠?*鍙湁鍦ㄦ病鏈夊疄娴?`usableH` 鏃舵墠鐢?* 鈥斺€?瀹為檯甯冨眬璧?`playerSwiperGapOf(h)` 鐨勮繛缁叕寮忋€?*/
  public readonly gapSwiper: number;
  /** 杩涘害鏉￠偅涓€琛屼笌浼犺緭鏉′箣闂寸殑**鍗犱綅鏉?*楂樺害锛坴p锛夈€傝繖涓€娈?*娌℃湁**杩炵画鍏紡锛屽氨鏄煡琛ㄣ€?*/
  public readonly gapScrub: number;
  /** 鎾斁/鏆傚仠涓绘寜閽殑鍧楀昂瀵革紙vp锛夈€?*/
  public readonly playSize: number;
  /** 杩涘害鏉￠偅涓€琛岀殑**鍧楀昂瀵?*锛坴p锛夈€傗殸锔?鏄Е鎺у潡銆佷笉鏄建閬撶矖缁嗭紙杞ㄩ亾绮楃粏鐢?`trackThickness(12)` 绠★級銆?*/
  public readonly seekSize: number;
  /** 渚ч敭锛堝惊鐜?/ 鎾斁鍒楄〃锛夊浘鏍囧瓧鍙凤紙fp锛夈€?*/
  public readonly sideSize: number;
  /** 姝屽悕瀛楀彿锛坒p锛夈€?*/
  public readonly titleSize: number;
  /** 姝屾墜鍚嶅瓧鍙凤紙fp锛夈€?*/
  public readonly artistSize: number;
  /** 鏀惰棌 / 鏇村鍥炬爣瀛楀彿锛坒p锛夈€?*/
  public readonly favSize: number;
  /** 姝屽悕琛屼笌灏侀潰涔嬮棿鐨勯棿璺濓紙vp锛夈€?*/
  public readonly metaGap: number;
  /** 搴曢儴瀹夊叏杈硅窛锛坴p锛夈€?*/
  public readonly bottomGap: number;
  /** 姝岃瘝椤垫暣浣撶殑缂╂斁姣斻€?*/
  public readonly lyricScale: number;
  /** 璇ユ。鎺у埗鍖?*鎬婚珮**锛坴p锛? `topBarH + gapSwiper + gapScrub + playSize + 58`銆?*/
  public readonly total: number;

  constructor(topBarH: number, gapSwiper: number, gapScrub: number, playSize: number,
    seekSize: number, sideSize: number, titleSize: number, artistSize: number,
    favSize: number, metaGap: number, bottomGap: number, lyricScale: number, total: number) {
    this.topBarH = topBarH;
    this.gapSwiper = gapSwiper;
    this.gapScrub = gapScrub;
    this.playSize = playSize;
    this.seekSize = seekSize;
    this.sideSize = sideSize;
    this.titleSize = titleSize;
    this.artistSize = artistSize;
    this.favSize = favSize;
    this.metaGap = metaGap;
    this.bottomGap = bottomGap;
    this.lyricScale = lyricScale;
    this.total = total;
  }
}

/**
 * 鎶?`Area` 閲岀殑 `Length` 鍙栨垚 vp 鏁板€笺€?
 *
 * `Area.width` / `Area.globalPosition.x` 鐨勯潤鎬佺被鍨嬫槸 `Length = string | number | Resource`锛?
 * 鐩存帴 `Number()` 鍦?ArkTS 涓嬭繃涓嶄簡绫诲瀷妫€鏌ワ紙Resource 鍒嗘敮娌℃硶杞級锛屾墍浠ユ樉寮忔敹绐勩€?
 * @param value Length 鍊?
 * @returns vp 鏁板€硷紱鏃犳硶瑙ｆ瀽鏃惰繑鍥?0
 */
export function areaLengthToVp(value: Length | undefined): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    const parsed: number = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

/**
 * 鎾斁椤点€屼竴闀滃埌搴曘€嶅睍寮€鍔ㄧ敾鐨?*鍏变韩鍑犱綍 + 鐩镐綅**銆?
 *
 * 涓轰粈涔堟斁鍦?common锛氳糠浣犳潯鍦?`features/playlist`銆佹挱鏀鹃〉/鍔ㄧ敾瀹夸富鍦?`features/player`銆?
 * 瑙﹀彂鐐瑰湪 products 鐨勫３灞?鈥斺€?涓夋柟閮借璇诲啓鍚屼竴浠芥暟鎹紝鍙兘鏀惧叕鍏卞眰
 * 锛堝彧鍚?number / boolean / string锛屼笉寮曞叆浠讳綍 UI 缁勪欢绫诲瀷锛屼笉浼氶€犳垚寰幆渚濊禆锛夈€?
 *
 * ## 瑙傛劅锛堝弬鑰?musicfreeOH 鐨?`PlayerExpandAnim`锛?
 *
 * 鎾斁椤?*褰诲簳涓嶅姩**锛堝缁堥摵鍦ㄧ獥鍙ｅ師浣嶏級锛屽彧鍋氫袱浠朵簨锛?
 *   1. **clip 绐楀彛**浠庛€岃糠浣犳潯灏侀潰閭ｄ釜灏忔柟鍧椼€嶉暱鍒版暣灞?鈥斺€?杩欏氨鏄€屽悜涓婁笅寤朵几閾烘弧銆嶏紱
 *   2. 鍙︾敾涓€寮?*椋炶灏侀潰**锛堣瀹夸富閲岀殑 `Image`锛夛紝浠庤糠浣犳潯灏侀潰鐨勭煩褰㈤€愬抚鎻掑€煎埌
 *      鎾斁椤靛ぇ灏侀潰鐨勭煩褰?鈥斺€?杩欏氨鏄€屽皝闈㈡參鎱㈠彉澶у苟绉诲姩鍒版暣涓ぇ灏侀潰銆嶃€?
 *
 * 杩欐牱鍋氱殑鍏抽敭濂藉锛氭暣椤典笉鍋氱缉鏀?浣嶇Щ锛屾枃瀛椾笌鎺т欢**鍏ㄧ▼涓嶅彉褰?*锛?
 * 鑰屼笖杩蜂綘鏉″皝闈笌鎾斁椤靛ぇ灏侀潰鍦ㄥ姩鐢绘湡闂撮兘琚殣钘忥紝鐢婚潰涓婂彧鏈変竴寮犲皝闈㈠湪椋烇紝
 * 涓嶄細鍑虹幇涓ゅ紶灏侀潰鍚屾椂鍙鐨勯噸褰便€?
 *
 * ## 鐩镐綅
 *
 * ```
 *   绌洪棽         preparing            animating             绌洪棽
 *  progress=1 鈫?progress=0 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈫?progress 0鈫? 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈫?progress=1
 *  锛堟湭鎸傝浇锛?  椤甸潰閫忔槑銆侀噺涓ょ鐭╁舰    椋炶灏侀潰鍙銆佽糠浣犳潯灏侀潰闅愯棌
 * ```
 *
 * `preparing` 鐩镐綅鏄?*闃查棯鐨勫叧閿?*锛氭挱鏀鹃〉宸茬粡鎸傝浇锛堣兘娴嬮噺銆佽兘甯冨眬锛夛紝浣嗘暣椤典笉閫忔槑搴︿负 0锛?
 * 鎵€浠ョ湅涓嶅埌銆屾挱鏀鹃〉鍏堟暣涓脊鍑烘潵銆佸皝闈㈠啀椋炶繃鍘汇€嶇殑鏂眰銆?
 */
@ObservedV2
export class PlayerExpandState {
  /**
   * 鏃ュ織 tag 鐨?*瀵瑰鍓湰**銆?
   *
   * 涓轰粈涔堣鏈夊畠锛氭墜鍔挎彁浜ゅ垽瀹氶偅鏉℃棩蹇楀啓鍦?`PlaybackPage.onDismissDrag` 閲岋紝
   * 鑰岄偅閲岄渶瑕佺殑鏄?*鍚屼竴涓?* tag 鈥斺€?`hilog | grep RzdMorph` 涓€鏉″懡浠よ鑳藉悓鏃舵媺鍒?
   * 銆屽舰鍙樺嚑浣曘€嶄笌銆屾彁浜ゅ垽瀹氥€嶄袱鏉￠摼銆傚師鏉ョ殑 `logTag` 鏄?`private`锛屽埆鐨勭被璇讳笉鍒般€?
   */
  public static readonly LOG_TAG: string = 'RzdMorph';
  /** 鏃ュ織 tag锛氭帓鏌ュ睍寮€褰㈠彉鏃?`hilog | grep RzdMorph`銆?*/
  private static readonly logTag: string = PlayerExpandState.LOG_TAG;

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鐩镐綅 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /** 鎾斁椤靛凡鎸傝浇銆佹鍦ㄦ祴閲忎袱绔煩褰紙姝ゆ湡闂存暣椤典笉閫忔槑搴︿负 0锛夈€?*/
  @Trace public preparing: boolean = false;
  /** 涓€闀滃埌搴曞姩鐢昏繘琛屼腑锛堥琛屽皝闈㈠彲瑙併€佽糠浣犳潯灏侀潰涓庢挱鏀鹃〉澶у皝闈㈤殣钘忥級銆?*/
  @Trace public animating: boolean = false;
  /** 鍔ㄧ敾杩涘害锛? = 鏀跺湪杩蜂綘鏉′綅缃紝1 = 瀹屽叏灞曞紑銆?*/
  @Trace public progress: number = 1;

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 璧风偣锛氳糠浣犳潯灏侀潰锛堢獥鍙ｅ潗鏍?vp锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /** 杩蜂綘鏉″皝闈㈠湪绐楀彛涓殑宸﹁竟鐣岋紙vp锛夈€?*/
  @Trace public miniX: number = 0;
  /** 杩蜂綘鏉″皝闈㈠湪绐楀彛涓殑涓婅竟鐣岋紙vp锛夈€?*/
  @Trace public miniY: number = 0;
  /** 杩蜂綘鏉″皝闈㈣竟闀匡紙vp锛夈€?*/
  @Trace public miniSize: number = 0;
  /** 杩蜂綘鏉″皝闈㈠渾瑙掞紙vp锛夈€?*/
  @Trace public miniRadius: number = 12;

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 缁堢偣锛氭挱鏀鹃〉澶у皝闈紙绐楀彛鍧愭爣 vp锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /** 鎾斁椤靛ぇ灏侀潰鍦ㄧ獥鍙ｄ腑鐨勫乏杈圭晫锛坴p锛夈€?*/
  @Trace public bigX: number = 0;
  /** 鎾斁椤靛ぇ灏侀潰鍦ㄧ獥鍙ｄ腑鐨勪笂杈圭晫锛坴p锛夈€?*/
  @Trace public bigY: number = 0;
  /** 鎾斁椤靛ぇ灏侀潰杈归暱锛坴p锛夈€?*/
  @Trace public bigSize: number = 0;
  /** 鎾斁椤靛ぇ灏侀潰鍦嗚锛坴p锛夈€?*/
  @Trace public bigRadius: number = 12;

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 绐楀彛涓庢椂闀?鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /** 绐楀彛瀹藉害锛坴p锛夛細clip 绐楀彛灞曞紑鐨勭粓鐐广€?*/
  @Trace public windowWidthVp: number = 360;
  /** 绐楀彛楂樺害锛坴p锛夛細clip 绐楀彛灞曞紑鐨勭粓鐐广€?*/
  @Trace public windowHeightVp: number = 780;
  /**
   * 鐘舵€佹爮閬胯鍖洪珮搴︼紙vp锛岀湡瀹炲€硷級鈥斺€?瀵规爣鏃犵晫 `padTop()` 閲岀殑 `avoidTop`銆?
   * 鈿狅笍 鐢卞３灞傚湪 `reportWindow()` 閲屽杺杩涙潵锛?*0 琛ㄧず"杩樻病閲忓埌"**锛屾鏃?`topInsetVp()`
   *   閫€鍥炴瘮渚嬩及绠楋紙瑙侀偅閲岀殑璇存槑锛夈€?
   */
  @Trace public statusBarTopVp: number = 0;
  /**
   * 搴曢儴瀵艰埅鏉￠伩璁╁尯楂樺害锛坴p锛岀湡瀹炲€硷級鈥斺€?瀵规爣鏃犵晫 `padBottom()` 閲岀殑 `avoidBottom`銆?
   * 鈿狅笍 鐩墠**鍙仛鐧昏涓庝笂鎶?*锛岃繕娌℃湁娑堣垂鑰咃紙`padBottom()` 閭ｄ竴鍗婅 搂56.24 寰呭姙锛夈€?
   */
  @Trace public navigationBarBottomVp: number = 0;
  /** 涓€闀滃埌搴曞姩鐢绘椂闀匡紙ms锛夈€?*/
  @Trace public durationMs: number = 460;

  /**
   * 鏀惰捣璇锋眰鐗堟湰鍙枫€?
   *
   * 鎾斁椤电殑杩斿洖鎸夐挳鍙礋璐?`collapseVersion + 1`锛涚湡姝ｇ殑鍙嶅悜鍔ㄧ敾鐢卞姩鐢诲涓?
   * 锛坄PlaybackPageCoverHost`锛夊湪 `@Monitor` 閲屾挱 鈥斺€?鍥犱负鍙湁瀹夸富鍚屾椂鎷ユ湁
   * 銆屾暣椤?clip銆嶅拰銆岄琛屽皝闈€嶈繖涓や釜闇€瑕佷竴璧峰姩鐨勮妭鐐广€?
   */
  @Trace public collapseVersion: number = 0;

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 涓婃姤 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /**
   * 杩蜂綘鏉″皝闈笂鎶ヨ嚜宸卞湪绐楀彛涓殑鐭╁舰锛堢敱 `onAreaChange` 鐨?`globalPosition` + `width` 寰楁潵锛夈€?
   *
   * 鈿狅笍 鐢?`onAreaChange` 鑰屼笉鏄?`getRectangleById`锛氬悗鑰呯殑鏂囨。娌℃湁鍐欏崟浣嶏紙瀹炴祴鍙ｅ緞涓?px锛夛紝
   * 鍓嶈€呮槑纭槸 vp銆傚姩鐢荤殑浣嶇Щ涓庡昂瀵搁兘鐩存帴褰?vp 鐢紝鍗曚綅閿欎簡浼氭暣浣撻敊浣嶄竴鏁翠釜瀵嗗害鍊嶃€?
   * @param x 宸﹁竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級
   * @param y 涓婅竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級
   * @param size 杈归暱锛坴p锛?
   * @param radius 鍦嗚锛坴p锛?
   */
  public reportMini(x: number, y: number, size: number, radius: number): void {
    if (size <= 0) {
      return;
    }
    this.miniX = x;
    this.miniY = y;
    this.miniSize = size;
    this.miniRadius = radius;
  }

  /**
   * 鎾斁椤靛ぇ灏侀潰涓婃姤鑷繁鍦ㄧ獥鍙ｄ腑鐨勭煩褰€傚姩鐢诲涓婚潬瀹冨垽鏂€岀粓鐐归噺鍒颁簡娌℃湁銆嶃€?
   * @param x 宸﹁竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級
   * @param y 涓婅竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級
   * @param size 杈归暱锛坴p锛?
   * @param radius 鍦嗚锛坴p锛?
   */
  public reportBig(x: number, y: number, size: number, radius: number): void {
    if (size <= 0) {
      return;
    }
    this.bigX = x;
    this.bigY = y;
    this.bigSize = size;
    this.bigRadius = radius;
    if (radius > 0) {
      this.bigCoverRadius = radius;
    }
  }

  /**
   * 璁板綍绐楀彛灏哄锛坴p锛夛紝浣滀负 clip 绐楀彛灞曞紑鐨勭粓鐐广€?
   *
   * 鈽?2026-10-15锛?*鎵╀簡涓や釜鍙€夊弬鏁?*锛堢湡瀹為伩璁╁尯楂樺害锛夛紝瀵规爣鏃犵晫 `padTop()`/`padBottom()`
   *   鐨勮緭鍏ャ€傜敤**榛樿鍊?*鑰屼笉鏄?鏂板蹇呭～鍙傛暟"鏄负浜嗚鏃㈡湁璋冪敤鐐癸紙`products/default`銆?
   *   `products/pc` 鍚勪竴澶勶級**涓嶆敼涔熻兘缂栬瘧**锛涢殢鍚庨€愪釜琛ヤ紶鍗冲彲锛?鍚屼竴褰㈢姸 N 澶?閭ｄ釜鑰佹瘺鐥?
   *   鐨勯槻娉曪細鍏堣绛惧悕鍏煎锛屽啀鏁拌皟鐢ㄧ偣锛夈€?
   * @param widthVp 绐楀彛瀹斤紙vp锛?
   * @param heightVp 绐楀彛楂橈紙vp锛?
   * @param statusBarTopVp 鐘舵€佹爮閬胯楂樺害锛坴p锛? = 鏈噺鍒帮級鈥斺€?鍠傜粰 `topInsetVp()`
   * @param navigationBarBottomVp 搴曢儴瀵艰埅鏉￠伩璁╅珮搴︼紙vp锛? = 鏈噺鍒帮級
   */
  public reportWindow(widthVp: number, heightVp: number,
    statusBarTopVp: number = 0, navigationBarBottomVp: number = 0): void {
    if (widthVp > 0 && heightVp > 0) {
      // 鈽呪槄鈽?2026-10-17锛?*鐓ф惉鏃犵晫鐨?`transitionAborted`** 鈥斺€?瑙佷笅闈㈤偅娈碉級
      //   鍏堝垽瀹?杩欎竴娆℃槸鐪熺殑鍙樹簡"锛坄reportWindow` 浼氬湪姣忔甯冨眬鏃惰璋冿紝灏哄娌″彉灏变笉璇ュ仛浠讳綍浜嬶級銆?
      const sizeChanged: boolean = this.windowWidthVp > 0 && this.windowHeightVp > 0 &&
        (Math.abs(this.windowWidthVp - widthVp) > 1 || Math.abs(this.windowHeightVp - heightVp) > 1);
      this.windowWidthVp = widthVp;
      this.windowHeightVp = heightVp;
      this.statusBarTopVp = statusBarTopVp > 0 ? statusBarTopVp : 0;
      this.navigationBarBottomVp = navigationBarBottomVp > 0 ? navigationBarBottomVp : 0;
      if (sizeChanged) {
        this.abortTransitionOnResize();
      }
    }
  }

  /**
   * 鈽呪槄鈽?2026-10-17锛?*鐓ф惉鏃犵晫 `PlayerPage.transitionAborted` + `expand.setFinalStatus()`**锛?
   *
   * ## 鏃犵晫鍘熸枃锛坄wujie.pa:174998-175011`锛屽湪绐楀彛灏哄鍙樺寲閭ｆ潯閾句笂锛?
   * ```ts
   *   this.swiperBoxH = 鈥?
   *   this.refitOverlay();
   *   this.settleWideLayout();
   *   this.transitionAborted = true;      // 鈽?杞満浣滃簾
   *   this.expand.setFinalStatus();       // 鈽?鐩存帴钀藉埌鏈€缁堟€侊紙鏃犲姩鐢伙級
   * ```
   * 鑰?`setFinalStatus()`锛坄ExpandAnimation.ets:346-358`锛夐€愭潯鏄細
   * ```ts
   *   overlayColor = "#00000000"; scaleValue = 1;
   *   translateX = 0; translateY = 0;
   *   clipWidth = "100%"; clipHeight = "100%";
   *   snapOpacity = 0; contentOpacity = 1; radius = 0;
   * ```
   * 鈬?**瀹冭惤鐨勬槸"瀹屽叏灞曞紑"閭ｄ竴鎬?*锛堜笉鐪嬪綋鏃跺湪寰€鍝釜鏂瑰悜璧帮級銆?
   * 璇箟寰堢洿鐧斤細**绐楀彛灏哄鍒氬彉杩?鈬?涔嬪墠閲忓埌鐨勫嚑浣曞叏浣滃簾 鈬?鍒啀婕斿姩鐢讳簡锛屾妸鎾斁椤电洿鎺ユ憡寮€銆?*
   * 锛坄位@37*#^2` 閭ｆ潯娉ㄥ唽鍦?`NavTransition` 涓婄殑鍐呭杞満閲岋紝`transitionAborted` 涓虹湡鏃惰蛋鐨勪篃鏄繖涓€瀵癸細
   *   `expand.setFinalStatus(); proxy.finishTransition();`锛?
   *
   * ## 鏈粨鐨勭瓑浠风墿
   * `morphReset()` + `morphSettleOpen()` 灏辨槸鏈粨鐨?鏃犲姩鐢昏惤浣嶅埌灞曞紑鎬?
   * 锛坄morphSettleOpen` 浼?`applyMorphProgress(1)` 鈬?`scale=1/translate=0/瑁佸壀婊锛?
   *  `morphReset` 璐熻矗鎶婃诞灞備笌鏈疆鍑犱綍涓€璧蜂綔搴燂級鈥斺€?涓?`setFinalStatus` 閭ｄ竴涓查€愭潯瀵瑰簲銆?
   *
   * ## 鈿狅笍 涓庢棤鐣岀殑**涓€澶勫埢鎰忔敹绐?*锛堣鍦ㄦ锛屽埆鍐嶅綋鎴愭紡鎼級
   * 鏃犵晫**涓嶅垎鏂瑰悜**锛屼换浣曠浉浣嶈杩欐灏哄鍙樺寲鎾炰笂閮戒細 `setFinalStatus()`銆?
   * 鏈粨**鍙湪 `ENTERING`锛堟鍦ㄥ睍寮€锛夋椂鍋?*锛岀悊鐢憋細
   * 路 鏈粨鐨勫叧闂摼璺湁**鑷繁鐨勬敹灏惧畾鏃跺櫒**锛坄closeSettleTimer`锛宍morphCloseMs + 20`锛夛紝
   *   瀹冧竴瀹氫細鎶婇〉闈㈣惤浣嶅苟鍗歌浇 鈬?灏哄鍙樺寲鏃?*涓嶉渶瑕?*鍒汉鎻掓墜锛?
   * 路 鑻ラ偅鏃舵妸椤甸潰寮鸿鎽婃垚"瀹屽叏灞曞紑"锛岃€屽嚑鐧炬绉掑悗瀹冨氨瑕佽 pop锛?
   *   灞忎笂浼氬嚭鐜?*婊″睆鎾斁椤甸棯涓€涓?*锛堟鏄敤鎴锋姤杩囩殑绗?鈶?绫诲舰鐘讹級鈬?鍙嶈€屾洿绯熴€?
   * 鈬?鏀剁獎鍒?姝ｅ湪灞曞紑"杩欎竴鏀細閭ｄ竴鏀?*娌℃湁**鏀跺熬瀹氭椂鍣ㄥ厹搴曪紙闈?`settlePullOpen` 鐨勮ˉ閲忛摼锛夛紝
   *   鍑犱綍浣滃簾鏃舵渶瀹规槗鍗″湪鍗婅矾 鈥斺€?鑰?鐩存帴鎽婂紑"姝ｆ槸鏈€瀹夊叏鐨勮惤鐐广€?
   */
  private abortTransitionOnResize(): void {
    if (this.morphStage !== MorphStage.ENTERING) {
      return;
    }
    Logger.warn(PlayerExpandState.logTag,
      `RzdMorphAbort window resized during ENTERING (w=${this.windowWidthVp.toFixed(0)} ` +
      `h=${this.windowHeightVp.toFixed(0)}) 鈬?setFinalStatus (land fully open, no animation)`);
    this.morphReset();
    this.morphSettleOpen();
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?涓€銆侀€愬厓绱?morph锛堝鏍?鏃犵晫 MiniMorph / CoverMorph锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 鏃犵晫閭ｅ鐨勫仛娉曪紙浠庡嚱鏁版竻鍗曡鍑烘潵鐨勶級锛氭墍鏈夐噺閮芥槸 `xxxAt(progress)`锛?
  // 涔熷氨鏄?*涓€涓?progress 椹卞姩鍏ㄩ儴鎻掑€?*锛岃€屼笉鏄粰姣忎釜鍏冪礌鍚勯厤涓€鏉?animation銆?
  // 濂藉锛氫换鎰忔椂鍒绘墦鏂兘鑷唇锛岃窡鎵嬫嫋鍔ㄦ椂涓嶄細鍑虹幇"鏌愪釜鍏冪礌杩樺湪椋?銆?
  // 杩欓噷鎶婂畠鐨勫垎灞傝ˉ涓婏紙鍘熸潵鎴戜滑鍙湁"鏁撮〉 45% 娣″叆"涓€灞傦級銆?

  /** 鏂囧瓧灞傦紙姝屽悕/姝屾墜锛夋贰鍏ュ尯闂磋捣鐐广€?*/
  private static readonly META_FADE_FROM: number = 0.15;
  /** 鏂囧瓧灞傛贰鍏ュ尯闂寸粓鐐广€?*/
  private static readonly META_FADE_TO: number = 0.60;
  /** 鎸夐挳灞傦紙搴曢儴鎺у埗鍖猴級娣″叆鍖洪棿璧风偣 鈥斺€?姣旀枃瀛楁櫄锛屽舰鎴愰敊钀姐€?*/
  private static readonly ACTIONS_FADE_FROM: number = 0.40;
  /** 鎸夐挳灞傛贰鍏ュ尯闂寸粓鐐广€?*/
  private static readonly ACTIONS_FADE_TO: number = 1.0;

  /**
   * 鎶?`progress` 鍦?`[from, to]` 鍖洪棿鍐呭綊涓€鍖栧埌 `0鈥?`锛堝尯闂村澶圭揣锛夈€?
   *
   * 鈽呪槄 2026-10-15锛?*宸插垽瀹氫负姝讳唬鐮?*锛宍RzdMusic璁板繂.md` 搂59锛夛細**闆惰皟鐢ㄨ€?*銆?
   *   瀹冩槸"鎸夎繘搴﹀紑涓€涓瓙绐楀彛"閭ｇ被鍏紡鐨勯€氱敤浠讹紙`clamp((p-a)/(b-a))`锛夛紝
   *   鑰屾湰绫荤幇鍦ㄧ殑姣忎竴鏉＄獥鍙ｉ兘**鍐呰仈灞曞紑**浜嗭紙渚嬪 `pullChromeOpacity`锛?
   *   `clamp((effT-0.18)/0.44)`锛夆€斺€?鎻愬彇鎴愬嚱鏁板弽鑰屾洿闅惧拰鍙嶇紪璇戦€愬瓧瀵圭収锛屾墍浠ユ病鎺ャ€?
   * 鈿狅笍 鐣欑潃鏄负浜?*涓嬩竴澶?*瑕佺敤鏃跺埆鍐嶆墜鍐欎竴閬嶏紙鎵嬪啓灏辨湁鍐欓敊鍖洪棿鐨勯闄╋級锛?
   *    瀹冩槸 `private static` 涓旀槸**绾嚱鏁?*锛屼笉浼氳璇綋鎴愮姸鎬佸叆鍙ｃ€?
   * @param value 杩涘害
   * @param from 鍖洪棿璧风偣
   * @param to 鍖洪棿缁堢偣
   * @returns 褰掍竴鍖栧€?
   * 澶嶆牳鍛戒护锛歚grep -rn 'window01' RzdMusic --include=*.ets`锛堟湡鏈涳細鍙湁鏈瀹氫箟锛?
   */
  private static window01(value: number, from: number, to: number): number {
    if (to <= from) {
      return value >= to ? 1 : 0;
    }
    const t: number = (value - from) / (to - from);
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  /**
   * @returns 姝屽悕/姝屾墜灞傜殑娣″嚭绯绘暟锛堝鏍?`MiniMorph.metaOpacityAt = clamp(1 - t/0.35)`锛夈€?
   *
   * 鈿狅笍 杩欎竴鐗堟寜鍙嶇紪璇戞敼鎴?*娣″嚭**璇箟锛堝師鏉ユ槸鎴戞寜"娣″叆绐楀彛 0.15鈫?.60"鐚滅殑锛岄敊浜嗭級锛?
   *    瀹冩槸**杩蜂綘鏉￠偅涓€渚?*鐨勫厓淇℃伅闅忚繘搴︽贰鍑猴紝涓嶆槸鎾斁椤靛唴瀹圭殑娣″叆锛?
   *    鎾斁椤靛唴瀹圭敱 `contentOpacity`锛堣惤浣嶆墠缃?1锛変笌 `pullChromeOpacity/pullBottomIn` 璐熻矗銆?
   * @param progress 灞曞紑杩涘害 0鈥?
   * @returns 閫忔槑搴?
   */
  public static metaOpacityAt(progress: number): number {
    const v: number = 1 - progress / 0.35;
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /**
   * 鎿嶄綔鍖猴紙鎾斁/涓嬩竴棣栫瓑鎸夐挳锛夌殑娣″嚭绯绘暟
   * 锛堝鏍?`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`锛屾瘮姝屽悕鏇存棭娑堝け锛夈€?
   *
   * 鈽?2026-10-17锛坄MiniMorph` 閫愭潯澶嶆牳 鈥斺€?鏈枃浠舵槸**鏈€鍚庝竴涓?*娌″杩囩殑鎾斁鍣ㄤ笂娓告ā鍧楋級锛?
   * ```
   *   MiniMorph.actionsOpacityAt(t)      = clamp(1 鈭?t / 0.2 , 0, 1)   鉁?涓庢湰鍑芥暟閫愬瓧涓€鑷?
   *   MiniMorph.metaOpacityAt(t)         = clamp(1 鈭?t / 0.35, 0, 1)   鉁?涓庝笂闈㈤偅涓€愬瓧涓€鑷?
   *   MiniMorph.coverVisualRadiusAt(t)   = lerp(vp(miniCover.width)/2, targetCoverRadius, t)
   *        鈬?杩欐槸**鑳跺泭閭ｄ竴渚?*鐨勫渾瑙掓彃鍊硷紙涓?`CoverMorph.radiusAt` 涓嶆槸涓€鍥炰簨锛屽埆娣凤級
   *   MiniMorph.coverBoxEdge/Left/Top/Right/Scale/VisualEdge/CenterX/CenterY/Rise/RightShift
   *        鈬?鑳跺泭绔偣鐨勯€愰」鍑犱綍锛屾湰浠撳搴?`miniX` / `miniY` / `miniSize` / `barWin鈥 /
   *          `cover鈥hiftAt` / `coverRiseAt`锛堚殸锔?鍐欐敞閲婃椂鍒妸鏄熷彿鍜屾枩鏉犺繛鐫€鍐欙紝浼氭彁鍓嶇粨鏉熸敞閲婂潡锛?
   * ```
   * 鈬?**鏈粨杩欎笁鏉￠兘涓庝笂娓镐竴鑷?* 鉁擄紙璁板湪杩欓噷锛屽厤寰椾笅涓€杞啀浠庡ご鏍?`MiniMorph`锛夈€?
   */
  public static actionsOpacityAt(progress: number): number {
    const v: number = 1 - progress / 0.20;
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 涓夊眰娣″叆绐楀彛锛堝弽缂栬瘧 `entry/pages/PlayerPage.ets` 鐨勪笁涓?@Computed锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  //   pullBgIn          = clamp(effT / 0.30, 0, 1)                 鑳屾櫙锛? 鈫?0.30 娣″叆
  //   pullChromeOpacity = paintable ? clamp((effT-0.18)/0.44) : 0  椤舵爮锛?.18 鈫?0.62
  //   pullBottomIn      = clamp((effT - 0.45) / 0.55, 0, 1)        搴曟爮锛?.45 鈫?1.00
  //
  // 涓夎€呴兘浣滅敤鍦?`effT` 涓婏紝鑰?`effT = 浼氳瘽涓?? pullT : 1` 鈥斺€?鎵€浠?*涓嶅湪褰㈠彉浼氳瘽鏃跺叏閮ㄤ负 1**
  // 锛堥潤姝㈡€侀€愬儚绱犱笉鍙橈紝杩欐槸纭姹傦級銆?

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鍏冪礌鏃堕棿绐楄〃锛堚槄 鍞竴涓€浠斤紱p 鐨勭函鍑芥暟 鈬?灞曞紑/鏀惰捣澶╃劧浜掗€嗭級鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
  //
  // 鈽呪槄 2026-10-15 鐢ㄦ埛瀹氳皟锛氥€屼笉瑕佹贰鍏ユ贰鍑恒€?銆屾晥鏋滄渶濂姐€嶏紝骞?*浜插彛缁欏畾浜嗗垎缁勪笌椤哄簭**锛?
  //     銆?*杩涘害鏉″拰涓嬮潰鐨勯偅鍫嗘寜閽竴璧烽鍏ワ紝鍏堥鍏ョ殑鏄皬姝岃瘝鍜屾敹钘忔寜閽?*锛堟妸杩涘害鏉℃崲鎴愯繖涓や釜锛夈€?
  //      鈬?鍙湁**涓ょ粍**瑕?浠庝笅鍗囪捣"锛屼笖椤哄簭鏄細
  //        鈶?灏忔瓕璇?+ 鏀惰棌鎸夐挳锛堝厛锛?
  //        鈶?杩涘害鏉?+ 涓嬮潰閭ｄ竴鍫嗘寜閽?= **鏁寸墖鎺у埗鍖?*锛堝悗锛屼綔涓轰竴缁勶紝鍐呴儴涓嶅啀鍒嗗厛鍚庯級
  //      鈬?鏃堕棿绐楀彧鍐欏湪杩欓噷涓€浠斤紝**鎵€鏈夊彇鍊奸兘鏄?`p` 鐨勭函鍑芥暟**锛堜笉鍚柟鍚戝垽鏂€佷笉鍚┍鍔ㄦ簮鍒ゆ柇锛夛細
  //         灞曞紑 = p 浠?0 璧板埌 1锛涙敹璧?= p 浠?1 璧板洖 0 鈬?**鍚屼竴寮犺〃澶╃劧浜掗€?*锛?
  //         鏃㈡弧瓒?涓嬫媺鏀惰捣涓€鐩存槸瀵圭殑"锛屽張涓嶉渶瑕佷负鏀惰捣鍐嶅啓涓€濂椼€?
  //
  // 鈿狅笍 涓轰粈涔堜袱缁勯兘瑕?*闈犲悗**锛氱画椋炲皝闈㈢敾鍦ㄦ暣椤靛唴瀹?*涔嬩笂**锛埪?7 鐨勬暀璁細鎸埌鍐呭灞備箣涓嬩細琚〉闈㈡尅锛夛紝
  //    鑰屼笖瀹?*蹇呴』涓€鐩撮鍒?p=1**锛堝畠鐨勭煩褰㈡槸绐楀彛鍧愭爣锛屽彧鏈?p=1 鐨勬亽绛夊彉鎹笅鎵嶈惤寰楀噯锛夈€?
  //    鎵€浠?涓嶈灏侀潰鐩栦綇"鍙兘闈?*閿欏嘲**锛氱瓑灏侀潰椋炲埌涓婂崐灞忎箣鍚庯紝搴曚笅杩欎袱缁勫啀渚濇鍗囦笂鏉ャ€?

  /**
   * 姝屽悕/姝屾墜閭ｄ竴琛岋紙+ 鏀惰棌/鏇村涓や釜鍥炬爣锛夌殑鏃堕棿绐?鈥斺€?**鐓ф妱鏃犵晫 `pullChromeOpacity`**銆?
   *
   * 鈽呪槄鈽?2026-10-16锛堢敤鎴峰疄娴嬶細銆?*鏃犵晫鐨勬敹钘忓拰姝屾洸鑿滃崟鏄窡鐫€鏍囬姝屾墜涓€璧烽涓婃潵鐨?*銆嶏級锛?
   *   鏃犵晫閭ｄ竴灞傜殑鍏紡锛坄MiniMorph娓叉煋鏂逛笌椤跺簳鏍忔贰鍏ュ叕寮?md` 搂2锛屽瓧鑺傜爜锛夛細`clamp((t 鈭?0.18) / 0.44)`
   *   鈬?绐楀彛 = **0.18 鈫?0.62**銆?
   *   鈿狅笍 鎴戜滑鍘熸潵**娌℃湁**缁欒繖涓€琛?鍗囪捣"浣嶇Щ锛堝彧鏈?`pullChromeOpacity` 娣″叆锛夛紝
   *      鑰屾敹钘?鏇村涓や釜鍥炬爣涔熷湪鍚屼竴琛岄噷 鈬?瀹冧滑**鍙兘娣″叆銆佷笉浼氳窡鐫€椋炰笂鏉?*銆?
   *   鈬?鐜板湪缁欐暣琛屽姞鍚岀獥浣嶇Щ锛堣 `metaRiseVp()`锛夛紝骞朵繚鐣欐棦鏈夌殑 `pullChromeOpacity` 娣″叆
   *     锛堟贰鍏ョ獥鍙ｄ笌瀹?*鍚屼竴涓尯闂?*锛屼袱鑰呭悓璧峰悓钀斤級銆?
   */
  public static readonly WIN_META_START: number = 0.18;
  public static readonly WIN_META_END: number = 0.62;

  /**
   * 绗竴缁勶紙灏忔瓕璇嶏級鐨勬椂闂寸獥銆?
   *
   * 鈿狅笍 椤哄簭渚濇嵁锛堢敤鎴?2026-10-15 鍘熻瘽锛夛細銆?*鍏堥鍏ョ殑鏄皬姝岃瘝鍜屾敹钘忔寜閽?*銆嶃€?
   * 鈽?2026-10-16 淇锛氭敹钘?鏇村宸叉寜鏃犵晫褰掑埌**姝屽悕閭ｄ竴琛?*锛堟瘮灏忔瓕璇?*鏇存棭**锛夛紝
   *   鎵€浠ヨ繖涓€缁勭幇鍦ㄥ彧鍓╁皬姝岃瘝 鈥斺€?瀹冭惤鍦ㄩ《鏍?0.18鈥?.62)涓庡簳鏍?0.45鈥?.00)涔嬮棿銆?
   */
  public static readonly WIN_A_START: number = 0.30;
  public static readonly WIN_A_END: number = 0.52;
  /**
   * 绗簩缁勶紙杩涘害鏉?+ 搴曢儴鎸夐挳 = 鏁寸墖鎺у埗鍖猴級鐨勬椂闂寸獥 鈥斺€?**鐓ф妱鏃犵晫 `pullBottomIn`**銆?
   *
   * 鈽呪槄鈽?2026-10-16锛堢敤鎴峰疄娴嬶細銆?*涓嬮潰閭ｅ爢鎸夐挳锛屾棤鐣屾槸鏁翠釜鍔ㄧ敾缁撴潫鍚庨瀹岋紝
   *   娲鹃煶鐜板湪鏄揩缁撴潫鐨勬椂鍊欏氨椋炲畬浜嗭紝鐒跺悗鏈€鍚庝竴鐐瑰氨浼氭湁涓斁澶х殑杩囩▼**銆嶏級锛?
   *   鏃犵晫閭ｄ竴灞傜殑鍏紡锛堝悓鏂囨。 搂3锛屽瓧鑺傜爜锛夛細`clamp((t 鈭?0.45) / 0.55)`
   *   鈬?绐楀彛 = **0.45 鈫?1.00** 鈥斺€?**姝ｅソ鍦ㄨ惤浣嶉偅涓€鍒绘墠椋炲畬**銆?
   *   鈿狅笍 鎴戜滑鍘熸潵鏄?`0.60 鈫?0.90` 鈬?鎺у埗鍖哄湪 90% 灏卞埌浣嶏紝鏈€鍚?10% 鍙墿"鏁撮〉鏀惧ぇ"
   *     鈬?瑙傛劅灏辨槸鐢ㄦ埛璇寸殑"鏈€鍚庝竴鐐规湁涓斁澶х殑杩囩▼"銆?
   */
  public static readonly WIN_B_START: number = 0.45;
  public static readonly WIN_B_END: number = 1.00;
  /** "浠庝笅鍗囪捣"鐨勫箙搴︼紙灞忓箷 vp锛屽舰鍙樻湡闂存寜 `1/scale` 鍙嶇畻鎴愰〉鍐呬綅绉伙級銆?*/
  public static readonly RISE_VP: number = 180;

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?澹冲眰娴眰杩欎竴灞傜殑**鐙珛鏃堕暱/鏇茬嚎**锛堝鏍囨棤鐣?`animateMorphT`锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 鏃犵晫鏄?*涓ゅ眰**锛氭挱鏀鹃〉鍐呭揩鐓?350ms `Curve.EaseInOut`锛坄doEnter`锛? 娴眰鎷疯礉鐨?`morphT`
  //  560ms `cubic-bezier(0.23, 1.0, 0.32, 1.0)`锛坄animateMorphT`锛夈€?
  // RzdMusic 鐜板湪涔熷垎鎴愪袱灞傦細**鎾斁椤甸偅灞傜殑 350ms 涓€涓瓧閮戒笉鍔?*锛坄PlaybackPage.MORPH_OPEN_DURATION_MS`锛夛紝
  // 澹冲眰娴眰杩欎竴灞傚崟鐙蛋涓嬮潰杩欏 560ms + 蹇嚭鎱㈡敹鐨勮礉濉炲皵銆?
  //
  // 鈿狅笍 鍙湁**娴眰鎷疯礉**鍚冭繖涓€濂楋紱`morphP`锛? 鎾斁椤靛嚑浣曪級缁х画鐢卞師璋冪敤鏂规寜 350ms 琛ラ棿銆?

  /** 娴眰鎷疯礉鐨勮ˉ闂存椂闀匡紙ms锛屽鏍囨棤鐣?`ENTER_MS = 560`锛夈€?*/
  public static readonly MORPH_OVERLAY_DURATION_MS: number = 560;

  /**
   * **内容时间线**的进入补间时长（ms）—— 上游 `MainPage.ENTER_MS`。
   *
   * 字节码证据：
   * ```
   *   wujie.pa:154167-154169   MainPage&.#~@1>#static_initializer
   *                            ldai 0x230                                  // 0x230 = 560
   *                            definepropertybyname 0x0, "ENTER_MS", a2
   *   wujie.pa:163524-163547   点击迷你条 → onPullReady 续接（λ@5**# 的 onDone = finishEnter）
   *                            ldobjbyname 0x1d, "animateMorphT"
   *                            ldobjbyname 0x1f, "ENTER_MS"
   *                            ldexternalmodulevar 0x16  "EASE_OUT_STR"
   *                            ldai 0x1                                    // 目标 1
   * ```
   * 曲线 `EASE_OUT_STR` = `"cubic-bezier(0.23, 1.0, 0.32, 1.0)"`
   * （`_recover/logic-src/consts.json:1501`、`设计常量总表.md` 第 15 项 `Tokens[15]`）。
   *
   * ⚠️ 这与 {@link MORPH_OVERLAY_DURATION_MS} 数值相同是**有原因的**：上游那两层（浮层克隆 /
   *   内容窗口）本来就是同一条 `morphT`；而容器几何那层是另一条 **350ms + `Curve.EaseInOut`**
   *   （`ExpandAnimation.doEnter`），在本仓对应 {@link morphP}。
   */
  public static readonly MORPH_CONTENT_DURATION_MS: number = 560;
  /** 娴眰鎷疯礉**鏀惰捣**鏂瑰悜鐨勫熀纭€鏃堕暱锛坢s锛夆€斺€?瀵规爣鏃犵晫 `MainPage.REVERSE_MS = 460`銆?*/
  public static readonly MORPH_OVERLAY_REVERSE_MS: number = 460;
  /** 娴眰鎷疯礉鏀惰捣鏃堕暱鐨勪笅闄愭瘮渚?鈥斺€?瀵规爣鏃犵晫 `MainPage.REVERSE_MIN_RATIO = 0.4`銆?*/
  public static readonly MORPH_OVERLAY_REVERSE_MIN_RATIO: number = 0.4;

  // 鈽呪槄鈽?2026-10-15锛圧ound 27锛夛細**鏀惰捣鏂瑰悜鏀规垚涓庢挱鏀鹃〉"鍚屼竴鏉″叕寮?+ 鍚屼竴鏉℃洸绾?**銆?
  //
  // 鏃犵晫 `MainPage` 閭ｄ竴灞傛湁涓€瀵瑰父閲忥紙`寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂0 閫熸煡 L27/L29 +
  // 搂鍏?甯搁噺琛?L620-631锛涘嚭澶勪氦鍙夎 `ExpandAnimation椹卞姩涓庤ˉ闂村畾绋?md` 搂涓?
  // 銆屼袱濂楁椂闀胯〃鐨勭湡瀹炲叧绯汇€嶁€斺€擿ENTER_MS`/`REVERSE_MS` **鍚屽睘 MainPage 閭ｄ竴灞?*锛夛細
  //   路 杩涘叆锛歚ENTER_MS = 560` + `EASE_OUT_STR (0.23,1,0.32,1)`
  //   路 鏀惰捣锛歚animateMorphT(reverseMs, t=0, REVERSE_EASING)`锛屽叾涓?
  //     `reverseMs = round(REVERSE_MS(460) 脳 max(REVERSE_MIN_RATIO(0.4), morphT))`銆?
  //     `REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`
  //
  // 鈿狅笍 鏈枃浠舵棭鍏堣杩囦竴鏉?**鏈夋剰涓嶈惤鍦?*"鐨勫喅瀹氾紝鐞嗙敱鏄噺鍖栬繃鐨?12% 灏捐烦"锛?
  //   娴眰鍙椿鍒?`morphLand()`锛岃€岄偅鏃舵挱鏀鹃〉閭ｅ眰鏄?`MORPH_CLOSE_DURATION_MS = 350` + 20
  //   鈬?娴眰鍙湁 ~370ms 鍙敾锛涜嫢娴眰鏀圭敤 460 + `(0.85,0,0.5,0.88)`锛屽湪 370/460 = 80% 澶?
  //   鍙蛋鍒?鈮?7% 鈬?鎾ゆ帀鐬棿璺?~12% 琛岀▼銆?
  //   鈽?**璇ュ墠鎻愬凡缁忎笉瀛樺湪**锛毬?6.20 鎶婃挱鏀鹃〉鍏抽棴鏀规垚浜?
  //     `round(460 脳 max(0.4, morphT))` + `REVERSE_EASING`锛坄MORPH_CLOSE_DURATION_MS` 宸插垹锛夈€?
  //   鈬?璁╂诞灞傜敤**鍚屼竴鏉″叕寮?+ 鍚屼竴鏉℃洸绾?*涔嬪悗锛?
  //     路 涓ゅ眰**鍚岃捣鍚岃惤**锛堝悓涓€甯ц捣銆佸悓涓€鏃堕暱銆佸悓涓€鏇茬嚎銆佽捣鐐归兘鏄悇鑷殑褰撳墠杩涘害锛?
  //       鈬?**缁撴瀯涓婁笉鍙兘涓嶅悓姝?*锛?灏捐烦"杩欎釜闂**浠庢牴涓婃秷澶?*锛堜笉鏄?璺冲緱鏇村皬"锛夛紱
  //     路 杩欎篃姝ｆ槸鏃犵晫 `MainPage` 灞傜殑鍘熷啓娉曪紙`animateMorphT(reverseMs, 0, REVERSE_EASING)`锛夈€?
  //
  // 鈿狅笍 鏂瑰悜鍒ゅ畾鐢ㄥ舰鍙?`progress`锛坱rue = 灞曞紑鍒?1锛沠alse = 鏀跺洖 0锛夛紝**涓嶈**鍐欐垚
  //   `to > from`锛氳ˉ闂翠腑琚墦鏂椂 `from` 宸茬粡鍔ㄨ繃锛岀敤瀹冨垽鏂瑰悜浼氳鍒ゃ€?
  //
  // 鈿狅笍 杩欓噷**娌℃湁** `morphOverlayCurve()` 杩欑被杩斿洖 `ICurve`/`UIShape` 鐨勫寘瑁呭嚱鏁?鈥斺€?鏁呮剰鐨勶細
  //   鏈満 SDK 閲?`ICurve`锛坄component/common.d.ts:4154`锛?*鍞嫭瀹冩病鍐?`declare`**
  //   锛堝悓鏂囦欢鍏跺畠鎺ュ彛閮芥槸 `declare interface`锛夆噿 瀹冧笉鏄叏灞€鍙鐨勶紱`@kit.ArkUI` 涔?*娌℃湁**
  //   瀵煎嚭 `UIShape`锛堢紪璇戝疄娴嬶細`Module '"@kit.ArkUI"' has no exported member 'UIShape'`锛夈€?
  //   鈬?鏇茬嚎**灏卞湪鍞竴閭ｄ釜 `animateTo` 鐨勮皟鐢ㄧ偣涓婂唴鑱斿啓**锛堟湰娆℃敼鎴愭寜 `progress` 璧颁袱鍒嗘敮鐨勪笁鍏冿級锛?
  //   涓庡伐绋嬮噷鏃㈡湁鐨勪袱澶勫悓娆撅紙`products/default .../Index.ets`銆乣PlaybackPage.ets`锛夛細
  //       curve: curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
  //   鏀规洸绾垮彧鏀归偅**涓€澶?*锛坄morphOverlayTweenTo` 閲岋級锛屼笉瑕佸彟璧峰寘瑁呫€?

  /** @returns 绐楀彛 [start, end] 鍐呯殑绾挎€ц繘搴?0鈥?锛堢獥鍙ｅ澶圭揣锛夈€?*/
  public static ramp01(p: number, start: number, end: number): number {
    if (end <= start) {
      return p >= end ? 1 : 0;
    }
    const v: number = (p - start) / (end - start);
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /**
   * @returns 绗竴缁勩€屽皬姝岃瘝 + 鏀惰棌鎸夐挳銆嶇殑绾靛悜浣嶇Щ锛?*椤靛唴** vp锛夈€?
   *
   * 绐楀唴浠?180vp 鍗囧埌浣嶏紙灞忓箷閲忥級锛岄潤姝㈡€?闈炲舰鍙樻湡鎭?0銆?
   * 鈿狅笍 闄や互 `morphScale`锛氳繖涓€灞備細琚灞傚舰鍙樺鍣ㄧ缉鏀撅紝鍙嶇畻鍚庡睆涓婁綅绉绘墠鎭掑畾銆?
   */
  public earlyRiseVp(): number {
    if (!this.morphClipping()) {
      return 0;
    }
    // 升入窗口取**内容时间线**（上游 `pullChromeOpacity` / `pullBottomIn` 都吃 `effT = pullT`）
    const w: number = PlayerExpandState.ramp01(this.contentProgress(),
      PlayerExpandState.WIN_A_START, PlayerExpandState.WIN_A_END);
    const scale: number = Math.max(0.05, this.morphScale);
    return (1 - w) * PlayerExpandState.RISE_VP / scale;
  }

  /**
   * @returns 绗簩缁勩€屾暣鐗囨帶鍒跺尯锛堣繘搴︽潯 + 搴曢儴鎸夐挳锛夈€嶇殑绾靛悜浣嶇Щ锛?*椤靛唴** vp锛夈€?
   *
   * 鈽?2026-10-16锛氱獥鍙ｅ凡鎸夋棤鐣?`pullBottomIn` 鏀规垚 **0.45 鈫?1.00**锛堣 `WIN_B_*` 鐨勬敞閲婏級
   *   鈬?灞曞紑鏃舵帶鍒跺尯**鍒拌惤浣嶉偅涓€鍒绘墠椋炲畬**锛屾渶鍚庝笉鍐嶆湁"鍙墿鏀惧ぇ"鐨勯偅涓€娈点€?
   */
  public contentRiseVp(): number {
    if (!this.morphClipping()) {
      return 0;
    }
    // 升入窗口取**内容时间线**（上游 `pullChromeOpacity` / `pullBottomIn` 都吃 `effT = pullT`）
    const w: number = PlayerExpandState.ramp01(this.contentProgress(),
      PlayerExpandState.WIN_B_START, PlayerExpandState.WIN_B_END);
    const scale: number = Math.max(0.05, this.morphScale);
    return (1 - w) * PlayerExpandState.RISE_VP / scale;
  }

  // ═══════════════ 底栏（进度条 + 传输行）位移：逐字照搬上游 `pullBottom*` 三件套 ═══════════════
  //
  // 这一组是"关闭播放页时传输行两颗图标（播放模式/播放列表）下移一点点"这条真机反馈的收口。
  // 上一轮补了 `Row.alignItems(Center)` 与"方盒同口径"（静态对齐已对），但**关闭路上仍在下移**
  // ⇒ 说明位移来自**时间线**，不是静态对齐。回原文核出三件事：
  //
  // ```
  //   pullBottomIn()        wujie.pa:176377-176410
  //     const t = (effT() - 0.45) / (1 - 0.45);
  //     return 0 < t ? (1 > t ? t : 1) : 0;
  //
  //   pullBottomOpacity()   wujie.pa:176411-176429
  //     return !pullMode ? 1 : pullBottomIn();
  //
  //   pullBottomY()         wujie.pa:176430-176470
  //     let y = 0;
  //     if (!pullMode) { return y; }        // 176434-176437 callruntime.isfalse + jnez
  //     y = 1 - pullBottomIn();             // 176445-176448 ldai 0x1 + sub2
  //     y = y * 200;                        // 176449-176453 ldai 0xc8(=200) + mul2
  //     return y;
  // ```
  //
  // ⚠️ 反汇编操作数语义：`.pa` 里 `OP reg` 读作 `reg = reg OP acc`（见 `全局记忆.md`），
  //   所以 `sub2 ... v2` = `v2 = v2 - acc`；`less/greater` 同理。按此读出的式子与
  //   `_recover/logic-src/pullT写入算式与形变枚举.md:334` 的 `clamp((effT-0.45)/0.55, 0, 1)` 一致。
  // ⚠️ 上游 `effT()`（`wujie.pa:171535-171548`）= `isMorphTarget() ? 1 : pullT`；
  //   本仓等价量就是 {@link morphP}（0 = 迷你条，1 = 播放页展开）。
  // ⚠️ 上游**不除 `morphScale`**：这 200vp 与卡片一起被外层 `Stack` 的 `.scale()` 缩放
  //   （`wujie.pa:191400-191415`），屏幕上的位移随卡片一起变小。
  //   ⛔ 旧实现 `contentRiseVp()` 除以了 `morphScale` ⇒ 屏幕上**恒为 180vp、不随卡片收缩**，
  //      于是收起来时整排控制区相对卡片底部一路下沉（180 常数 vs 上游 `200 × scale`）——
  //      这就是"两颗图标下移一点点"的量化来源。本方法按上游改成 200 且不除 scale。

  /** `pullBottomY()` 的幅度（`wujie.pa:176449` 的 `ldai 0xc8` = 200，vp）。 */
  public static readonly PULL_BOTTOM_Y_VP: number = 200;

  // ⚠️ `pullBottomIn()` 本类**早就有了**（下面 `pullChromeOpacity()` 那一族，门是 `morphLive()`）：
  //    `clamp01((morphP − 0.45) / (1 − 0.45))`，`!morphLive() → 1` ⇒ 与上游
  //    `wujie.pa:176377-176410` 逐字同式，**直接复用，别再加第二个**
  //    （本轮第一版加了一份，编译报 `Duplicate function implementation` @ 743/934）。
  //    值域语义：形变中 = 底栏入场进度（0 = 还没出场 / 1 = 已落位）；不在形变 = 1（已落位）。
  //    ⇒ 位移取 `1 − 它`，非形变时正好 0。

  /**
   * 上游 `PlayerPage.pullBottomY()`（`wujie.pa:176430-176470`）——**底栏（scrubber + transport）的
   * 竖直位移**，逐字：
   * ```
   *   pullBottomY = pullMode ? 200 × (1 − pullBottomIn()) : 0
   * ```
   * 上游把这个值挂**两处**（两处取的是同一个式子）：
   * `scrubber` 的 `Column().translate({y: pullBottomY()})`（`wujie.pa:197161`）与
   * `transport` 的 `Row().translate({y: pullBottomY()})`（`wujie.pa:181213`）。
   * 本仓把进度条与传输行画在同一层里 ⇒ 只需在那一层挂一次，等价。
   *
   * ⚠️ 门控：上游是 `pullMode`（下拉/形变会话，`wujie.pa:168193` 初值 false，
   *   `:179312` 在 `setupExpandTransition` 里置真）；本仓等价量是形变是否在跑
   *   （{@link morphClipping}，与旧实现同一个门），所以这里沿用它。
   * ⛔ **不接** `pullBottomOpacity()`（`wujie.pa:176411-176429`，`!pullMode ? 1 : pullBottomIn()`）：
   *   用户明确要求"关闭期间这两颗一直在"（上一轮修的正是"关闭时两颗消失"），
   *   接了会在 `morphP<0.45` 附近淡没。
   * @returns 底栏竖直位移（vp，向下为正；0 = 已在落位）
   */
  public pullBottomYVp(): number {
    if (!this.morphClipping()) {
      return 0;
    }
    return (1 - this.pullBottomIn()) * PlayerExpandState.PULL_BOTTOM_Y_VP;
  }

  /**
   * @returns 銆屾瓕鍚?姝屾墜 + 鏀惰棌/鏇村銆嶉偅涓€琛岀殑绾靛悜浣嶇Щ锛?*椤靛唴** vp锛夈€?
   *
   * 鈽呪槄鈽?2026-10-16锛堜慨鐢ㄦ埛瀹炴祴锛氥€?*鏃犵晫鐨勬敹钘忓拰姝屾洸鑿滃崟鏄窡鐫€鏍囬姝屾墜涓€璧烽涓婃潵鐨?*銆嶏級锛?
   *   杩欎竴琛屽師鏉?*鍙湁 `pullChromeOpacity` 娣″叆銆佹病鏈変换浣曚綅绉?* 鈬?鏀惰棌/鏇村涓や釜鍥炬爣
   *   鍙兘"娣″嚭鏉?锛屼笉浼?璺熺潃椋炰笂鏉?銆?
   *   鈬?鎸夋棤鐣?`pullChromeOpacity` 鐨勭獥鍙ｏ紙**0.18 鈫?0.62**锛屽悓涓€鍖洪棿涔熸槸瀹冪殑娣″叆鍖洪棿锛?
   *     缁欐暣琛屽姞鍚岀獥浣嶇Щ锛屼袱涓浘鏍囦笌鏂囧瓧鍥犳**鍚屼竴缁勩€佸悓鏃堕涓婃潵**銆?
   */
  public metaRiseVp(): number {
    if (!this.morphClipping()) {
      return 0;
    }
    // 升入窗口取**内容时间线**（上游 `pullChromeOpacity` / `pullBottomIn` 都吃 `effT = pullT`）
    const w: number = PlayerExpandState.ramp01(this.contentProgress(),
      PlayerExpandState.WIN_META_START, PlayerExpandState.WIN_META_END);
    const scale: number = Math.max(0.05, this.morphScale);
    return (1 - w) * PlayerExpandState.RISE_VP / scale;
  }

  /**
   * @returns 鎾斁椤?*鐪熷皝闈?*鏄惁璇ョ敾銆?
   *
   * 鈽呪槄鈽?2026-10-16锛堢敤鎴峰疄娴嬩袱鏉★紝鏈鏄畠浠?*鍏卞悓鐨勬牴**锛夛細
   *   銆?*涓嬫媺鐨勬椂鍊欏皝闈㈠湪鍔ㄧ敾缁撴潫鎵嶆敹璧?*銆?銆?*鐐瑰嚮鎵撳紑鎾斁鍣ㄥ皝闈㈢洿鎺ュ氨鍒扮粨鏉熶綅缃簡**銆?
   *
   * ## 鍘熸潵涓轰粈涔堜袱鏉￠兘鍧?
   *
   * 鍘熷垽鎹槸 `!morphContainerActive()` 鈥斺€?鍙**鐩镐綅**涓€杩?ENTERING/LEAVING/LANDING
   * 灏辩珛鍒绘妸鐪熷皝闈㈣棌璧锋潵锛屾敼鐢?*澹冲眰鍏嬮殕灞?*锛坄MorphCoverClone`锛変唬琛ㄥ皝闈㈤銆?
   * 浣嗗厠闅嗗眰鐨勬樉闅愰棬鏄?`morphOverlayBridging()`锛? 娴眰杩涘害 `morphOverlayP` 鍦?(0,1) 涔嬮棿锛夛紝
   * **涓よ€呬笉鏄簰琛ュ叧绯?* 鈬?鍙娴眰閭ｆ潯琛ラ棿娌¤窇璧锋潵锛堟垨宸茶窇鍒?0锛夛紝灏变細鎺夎繘
   * **"鐪熷皝闈笉鐢?+ 鍏嬮殕灞備笉鐢?鐨勭┖妗?*锛?
   *   路 涓嬫媺鍏抽棴锛氱┖妗ｉ噷灞忎笂**娌℃湁灏侀潰**锛屼竴鐩寸瓑鍒版挱鏀鹃〉钀戒綅锛坄morphLand()` 涔嬪悗
   *     `morphContainerActive()` 杞亣锛夌湡灏侀潰鎵嶅啋鍑烘潵 鈬?瑙傛劅"灏侀潰**鍒板姩鐢荤粨鏉熸墠鏀惰捣**"锛?
   *   路 鐐瑰嚮鎵撳紑锛氬悓鐞嗭紝璧锋墜閭ｄ竴娈垫病鏈夊皝闈紝鑰岄〉闈㈠凡缁忛摵寮€ 鈬?瑙傛劅"灏侀潰**鐩存帴灏卞埌缁撴潫浣嶇疆**"銆?
   *
   * ## 鐜板湪鐨勫垽鎹細**涓庡厠闅嗗眰涓ユ牸浜掕ˉ**
   *
   * ```
   *   鍏嬮殕灞傚湪鐢伙紙瑕嗙洊灞傞偅涓€妫掞級鈬?鐪熷皝闈笉鐢伙紙閬垮厤涓や唤锛?
   *   鍏嬮殕灞備笉鍦ㄧ敾              鈬?鐪熷皝闈㈢敾锛堥〉闈㈣嚜宸卞甫瀹冧竴璧风缉鏀?瑁佸壀锛屾案杩滀笉绌烘。锛?
   * ```
   * 鈬?鏃犺娴眰琛ラ棿璧锋病璧锋潵锛?*灞忎笂姘歌繙鎭板ソ鏈変竴寮犲皝闈?*锛屼笖瀹冭窡鐫€椤甸潰涓€璧风缉灏?鏀惧ぇ銆?
   * 鈿狅笍 杩欐潯鍚屾椂娑堟帀浜嗗師娉ㄩ噴鎷呭績鐨?涓や唤灏侀潰"锛氫袱浠藉彧鍦?鍏嬮殕灞傚湪鐢?鏃跺彲鑳介噸鍚堬紝
   *    鑰岄偅鏃剁湡灏侀潰琚繖鏉℃尅浣忋€?
   */
  /** @returns 娴眰閭ｄ唤灏侀潰**涓ょ鍑犱綍閮芥湁鏁?*锛堝惁鍒欏畠鐢诲嚭鏉ユ槸 0脳0锛岀瓑浜庢病鐢伙級銆?*/
  private overlayCoverDrawable(): boolean {
    if (this.snapStartW <= 0 || this.endCoverSize <= 0) {
      return false;
    }
    const rect: LyricMorphRect = this.morphOverlayCoverBridge();
    return rect.size > 0 && rect.height > 0;
  }

  public realCoverVisible(): boolean {
    // 鈽呪槄鈽?2026-10-16锛?*鎭㈠**锛涙垜涓棿涓ょ増鎶婂畠鏀瑰潖杩囦袱娆★級
    //
    // ## 鍒ゆ嵁 = 涓庡３灞傛诞灞?*涓ユ牸浜掕ˉ**锛堟诞灞傚湪鐢?鈬?鐪熷皝闈㈣浣嶏級
    //
    // ```
    //   娴眰鍦ㄧ敾杩欎竴妫掞紙`morphOverlayBridging()`锛夆噿 鐪熷皝闈笉鐢伙紙閬垮厤涓や唤锛?
    //   娴眰涓嶅湪鐢?                             鈬?鐪熷皝闈㈢敾锛堥潤姝㈡€佸氨闈犲畠锛?
    // ```
    //
    // ## 鎴戣繖鍑犵増鍒嗗埆閿欏湪鍝紙閮藉埆鍐嶇姱锛?
    //
    // | 鐗堟湰 | 鎴戝啓鐨勫垽鎹?| 鐢ㄦ埛瀹炴祴 |
    // | --- | --- | --- |
    // | 鈶?| `!morphContainerActive()` | 銆屼笅鎷夋椂灏侀潰鍒板姩鐢荤粨鏉熸墠鏀惰捣銆嶏紡銆岀偣鍑绘墦寮€鐩存帴灏卞埌缁撴潫浣嶇疆銆?|
    // | 鈶?| `!morphOverlayBridging()` + **鍚屾椂鎶婃诞灞傚叧鎺?* | 銆屽叧/寮€鎾斁鍣?*娌℃湁灏侀潰鍔ㄧ敾**銆?|
    // | 鈶?| 鎭?`true`锛堝彇娑堜氦妫掋€佺湡灏侀潰鐙媴锛?| 銆屽皝闈?*浠庝笅鏂归涓婃潵**銆嶏紙瀹瑰櫒鍙樻崲鎶婂熀鍑嗕綅鎼埌浜嗗睆骞曢《閮級 |
    // | 鈶?| `!morphOverlayBridging()`锛堟仮澶嶏級 | 姝ｇ‘鏂瑰悜 |
    //
    // 鈬?**鈶犻偅鏉℃敞閲婇噷鎷呭績鐨?涓よ€呬笉鏄簰琛?鏄湡鐨?*锛屼絾姝ｈВ鏄?*鎶婃诞灞傞偅浠借ˉ闂翠慨濂?*
    //   锛堝畠宸茬粡淇ソ浜嗭細瑙?`morphOverlayBridging()` 鐨勪笁鏉″垽鎹級锛?*涓嶆槸**鎶婄湡灏侀潰鏀规垚鎭掔敾銆?
    // 鈿狅笍 鍏抽敭浜嬪疄锛堜粠瀹瑰櫒鍑犱綍璇诲嚭鏉ョ殑锛屽埆鍐嶇敤"鎺ㄥ"鎺ㄧ炕瀹冿級锛?
    //   褰㈠彉涓鍣ㄨ创鍦?*灞忓箷椤堕儴閭ｄ竴鏉?*锛坄morphTy 鈮?+844`銆乣scale 鈮?0.082`锛?
    //   鑰岃糠浣犳潯鍦?*灞忓箷搴曢儴** 鈬?鍩哄噯浣嶇殑灏侀潰鍦ㄥ鍣ㄩ噷浼氳鎼埌椤堕儴鍘?鈬?
    //   **鐪熷皝闈㈠湪褰㈠彉鏈熶笉鑳戒唬琛?涓€闀滃埌搴?**锛岄偅鏄诞灞傜殑鑱岃矗銆?
    //
    // 鈽呪槄鈽?2026-10-16锛?*鍔犲浐锛氫笌"娴眰瀹為檯鍦ㄧ敾"浜掕ˉ锛岃€屼笉鏄笌"闂ㄤ负鐪?浜掕ˉ**锛夛細
    //   涓婇潰閭ｇ増鏄?`!morphOverlayBridging()`銆備絾"闂ㄤ负鐪?涓?鐪熺殑鐢诲嚭鏉ヤ簡"鏄袱浠朵簨锛?
    //   娴眰鍙兘鍥犱负**鍒殑鍘熷洜**鐢讳笉鍑烘潵锛坄morphCoverRectAt` 涓ょ鍑犱綍涓?0 鈬?0脳0銆?
    //   瀹夸富 `hostsMorphOverlay()` 鍦ㄨ繍琛屾湡杩斿洖鍋囥€佹诞灞傝妭鐐硅繕娌℃寕涓娾€︼級銆?
    //   閭ｅ氨浼氬嚭鐜扮敤鎴锋姤杩囩殑閭ｄ釜褰㈢姸锛?*`real=0 clone=0` 鈬?涓よ竟閮戒笉鐢?鈬?灞忎笂娌℃湁灏侀潰**銆?
    //   鈬?鐜板湪鎶婂垽鎹敹绱у埌"**娴眰纭疄鍦ㄧ敾**"锛?
    //     `morphOverlayBridging() && morphOverlayBridgeOpacity() > 0 && 涓ょ鍑犱綍闈為浂`
    //   鈬?鍙娴眰杩欎竴妫?*浠讳綍涓€鐜笉鎴愮珛**锛岀湡灏侀潰灏遍《涓婏紙瀹佸彲浣嶇疆涓嶅畬缇庯紝涔熺粷涓嶇暀绌烘礊锛夈€?
    //   鈿狅笍 闈欐鎬佹诞灞傞棬鎭掑亣 鈬?鏈嚱鏁版亽鐪?鈬?涓庢敼鍔ㄥ墠**閫愬儚绱犱竴鑷?*锛堝洖褰掔孩绾匡級銆?
    // 鈽呪槄鈽?2026-10-17锛?*涓?`morphOverlayBridging()` 涓ユ牸浜掕ˉ** 鈥斺€?淇€屼袱涓皝闈㈤殢鏈哄嚭鐜般€嶏級
    //   鍙"浼氳瘽鍦ㄩ┍鍔?+ 澹冲眰鎺ョ + 娴眰涓ょ鍑犱綍鏈夋晥"锛岄鐨勯偅涓€寮犲氨鏄?*鍞竴鐢诲**
    //   鈬?鐪熷皝闈?*鎭掍笉鐢?*銆傝繖鏉′笌 `morphOverlayBridging()` 閲屾柊澧炵殑閭ｆ潯鏄悓涓€涓潯浠剁殑姝ｅ弽闈紝
    //   鎵€浠ュ睆涓婃案杩滄伆濂戒竴寮狅紝涓?*涓嶄緷璧栦袱鏉¤ˉ闂磋皝鍏堣捣**锛堥偅姝ｆ槸"闅忔満"鐨勬潵婧愶級銆?
    if (this.hostsMorphOverlay() && this.morphSessionDriving() && this.overlayCoverDrawable()) {
      return false;
    }
    if (!this.morphOverlayBridging()) {
      return true;
    }
    if (this.morphOverlayBridgeOpacity() <= 0) {
      return true;
    }
    // 娴眰杩欎竴妫掕兘涓嶈兘鐪熺殑鐢诲嚭鏉ワ細涓ょ鍑犱綍蹇呴』闈為浂锛堝惁鍒欑敾鐨勬槸 0脳0锛?
    const rect: LyricMorphRect = this.morphOverlayCoverBridge();
    if (rect.size <= 0 || rect.height <= 0) {
      return true;
    }
    return false;
  }
  // 鈿狅笍 2026-10-15 鏁欒锛堝埆鍐嶇姱锛夛細**涓嶈**鎶婃瓕鍚?姝屾墜杩欎竴琛屾敼鎴?p 鐨勭嫭绔嬬獥鍙?
  //    锛堟垜璇曡繃 `ramp01(p, 0.18, 0.34)` 璁╁畠鍦ㄦ挱鏀鹃〉閲屾棭鍑虹幇銆佸苟璁╁３灞傚厠闅嗗眰鍦?0.38 鍓嶆贰瀹岋級銆?
  //    閭ｆ牱鍋氱殑缁撴灉鏄細鍏嬮殕灞傛贰鍑烘椂锛屾挱鏀鹃〉鑷繁閭ｄ竴琛岃繕鍘嬪湪**缂╁皬甯冨眬**閲岀湅涓嶈 鈬?
  //    鐢ㄦ埛瀹炴祴銆屾瓕鏇插悕鍜屾瓕鎵嬪埌涓棿灏辨秷澶变簡銆嶃€傝繖涓€娈?*淇濇寔鍘熸潵鐨?鎵€鏈夋潈浜ゆ帴"璇箟**锛?
  //    瑙?`targetMetaOpacity()`锛氬厠闅嗗眰鎺ョ鏈熼棿璇ヨ涓?0锛屼氦鍥炵粰鎾斁椤垫椂鎵嶆樉绀恒€?

  /** 鑳屾櫙鏈€浣庝笉閫忔槑搴﹀厹搴曪紙鍙嶇紪璇?`PlayerPage.PULL_BG_FLOOR`锛夈€?*/
  private static readonly PULL_BG_FLOOR: number = 0.04;

  /**
   * @returns 鑳屾櫙灞備笉閫忔槑搴︼細0 鈫?0.30 娣″叆鍒版弧锛堜笅闄?{@link PULL_BG_FLOOR}锛夈€?
   *
   * 鈿狅笍 杩欎竴灞?*涓嶆槸**"瀹瑰櫒鏁翠綋涓嶉€忔槑搴?锛氬鍣ㄦ湰韬笉娣★紝娣＄殑鏄儗鏅眰銆?
   *    璧风偣涔嬫墍浠ョ湅璧锋潵"鏈変笢瑗?锛岄潬鐨勬槸缁灏侀潰閭ｅ嚑涓厠闅嗗眰锛堣 shell 鐨勫舰鍙樺厠闅嗗眰锛夈€?
   *
   * 鈿狅笍鈿狅笍 **2026-10-15 琛ュ厖锛氭湰鍑芥暟銆愭晠鎰忔病鏈夎皟鐢ㄧ偣銆戯紝涓嶈鍘?鎺ヤ笂瀹?銆?*
   *   閫嗗悜缁撹纭疄鏄畠锛坄pullBgIn = clamp(effT / 0.30)`锛宍effT = 褰㈠彉涓?? morphT : 1`锛夛紝
   *   浣嗘挱鏀鹃〉鑳屾櫙灞傜敤鐨勬槸 `PlaybackPage.backgroundRevealOpacity()`锛?
   *   ```
   *   morphContainerActive() ? 0.25 + 0.75 * morphP : 1        // 绾挎€с€佷粠 25% 璧枫€佸埌钀戒綅鎵嶆弧
   *   ```
   *   **涓轰粈涔堟崲鎺?*锛氳繖鏉℃洸绾挎槸**鐢ㄦ埛鏄庣‘瑕佹眰**"鏁翠釜鏁堟灉灏辨槸鍗婇€忔槑杩囨浮鍒颁笉閫忔槑"鏃跺畾鐨勩€?
   *   鑰?`pullBgIn` 鍦?`p = 0.30` 灏?*婊′笉閫忔槑**锛屽彲閭ｆ椂褰㈠彉瑁佸壀绐楀彛杩樺彧鏈変竴灏忓潡"鍙鐭╁舰"
   *   鈬?绐楀彛閲屼粠绗?30% 璧峰氨鏄?*涓€鏁村潡涓嶉€忔槑搴曡壊**锛岀敤鎴峰疄娴嬫姤杩囩殑
   *   銆?*灞曞紑涓儗鏅槸榛戣壊鐨?*銆嶆鏄繖涓舰鐘讹紙璁板綍瑙?`韪╁潙鎬昏〃-RzdMusic褰㈠彉鍔ㄧ敾.md` 3.4锛夈€?
   *   鈬?**淇濇寔 `backgroundRevealOpacity()`**锛涙湰鍑芥暟鐣欎綔"閫嗗悜瀵圭収鐗?涓?鑻ュ摢澶╄鍥炲埌閫愬抚 effT 鍙ｅ緞"鐨勫弬鑰冦€?
   *   缃戞牸鑳屾櫙锛坄MeshCoverBg`锛変篃**鍚屾牱**鐢?`backgroundRevealOpacity()`锛屾病鏈変緥澶栥€?
   */
  public pullBgIn(): number {
    if (!this.morphLive()) {
      return 1;
    }
    // 内容窗口取**内容时间线**（上游 `effT = isMorphTarget() ? 1 : pullT`，`wujie.pa:171535-171548`）
    const p: number = this.contentProgress();
    const v: number = p / 0.30;
    const clamped: number = v > 1 ? 1 : v;
    return clamped < PlayerExpandState.PULL_BG_FLOOR ? PlayerExpandState.PULL_BG_FLOOR : clamped;
  }

  /** @returns 椤舵爮锛圱opArea锛変笉閫忔槑搴︼細0.18 鈫?0.62 娣″叆鍒版弧锛堟湭灏辩华鏃朵负 0锛夈€?*/
  public pullChromeOpacity(): number {
    if (!this.morphLive()) {
      return 1;
    }
    // 内容窗口取**内容时间线**（上游 `effT = isMorphTarget() ? 1 : pullT`，`wujie.pa:171535-171548`）
    const p: number = this.contentProgress();
    const v: number = (p - 0.18) / (0.62 - 0.18);
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /** @returns 搴曟爮锛堟帶鍒跺尯锛変笉閫忔槑搴︼細0.45 鈫?1.00 娣″叆鍒版弧銆?*/
  public pullBottomIn(): number {
    if (!this.morphLive()) {
      return 1;
    }
    // 内容窗口取**内容时间线**（上游 `effT = isMorphTarget() ? 1 : pullT`，`wujie.pa:171535-171548`）
    const p: number = this.contentProgress();
    const v: number = (p - 0.45) / (1 - 0.45);
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /** 鏂囧瓧灞傚悜涓婂亸绉伙紙vp锛夛細浠?+8 婊戝埌浣嶏紝鏀跺熬鏃剁湅璧锋潵鏄?娴笂鏉?銆?*/
  public static metaOffsetYAt(progress: number): number {
    return (1 - PlayerExpandState.metaOpacityAt(progress)) * 8;
  }

  /** @returns 姝屽悕/姝屾墜灞傞€忔槑搴︼紙鍩轰簬鍐呴儴 `progress`锛屼粎鍦ㄤ笌鍐呴儴鐩镐綅鍚屾簮鏃朵娇鐢級銆?*/
  public metaOpacity(): number {
    if (this.preparing) {
      return 0;
    }
    if (!this.animating) {
      return 1;
    }
    return PlayerExpandState.metaOpacityAt(this.progress);
  }

  /**
   * 瑙嗚鍦嗚锛氬皝闈㈣绛夋瘮缂╂斁鏃讹紝鍦嗚涔熻璺熺潃缂╂斁锛屽惁鍒欏皬灏哄涓嬪渾瑙掓樉寰楄繃澶с€?
   * 澶у昂瀵镐笅鏄惧緱杩囧皬锛堣繖灏辨槸鏃犵晫 `visualRadiusAt` / `coverVisualRadiusAt` 鐨勪綔鐢級銆?
   *
   * 鈿狅笍 **D3锛氫笌鏃犵晫绠楁硶涓嶅悓锛屾澶勫埢鎰忎繚鐣欙紝鍙爣娉ㄥ樊寮?*锛堜緷鎹?
   *    `docs\鏃犵晫褰㈠彉鎵嬫劅-钀藉疄鍒癛zdMusic娓呭崟.md` 搂鍥?D3銆屽缓璁細淇濈暀鐜扮畻娉曪紝鍙湪鏂囨。閲屾爣娉ㄥ樊寮傘€嶏級銆?
   *   路 鏃犵晫锛歚visualRadius = lerp(vp(miniCover.width) / 2, 鐩爣鍦嗚缁濆鍊?34, t)`锛?
   *     鍐?`radius = visualRadius / scale` 鈥斺€?**涓ょ鐐圭嚎鎬ф彃鍊?*锛?
   *   路 鏈疄鐜帮細`base * (size / miniSize)` 鍐嶅皝椤?`base * 1.6` 鈥斺€?**鎸夊昂瀵告瘮渚嬫斁澶?+ 涓婇檺**銆?
   *   涓よ€呭湪涓棿鎬佺殑鏇茬巼涓嶅悓锛屼絾鏈疄鐜?*涓嶄緷璧?`onAreaChange` 鐨勬椂搴?*锛堣涓嬮潰閭ｄ袱鏉℃敞閲婏級锛?
   *   鏀规垚涓ょ鐐?lerp 浼氭妸鏃跺簭鏁忔劅閲嶆柊寮曡繘鏉?鈬?淇濈暀銆?
   *
   * 鈽呪槄 澶嶆牳锛?026-10-15锛屽垽鎹 `git grep -n coverVisualRadius -- "*.ets"`锛夛細
   *    **鏈嚱鏁板叏浠撻浂璋冪敤鐐?*锛堝彧鏈夎繖涓€澶勫畾涔?+ 涓ゅ娉ㄩ噴锛夛紝鎵€浠?D3 璁扮殑杩欐潯宸紓
   *    **骞朵笉鍦ㄦ椿鐨勬覆鏌撹矾寰勪笂**銆傛椿鐨勫渾瑙掓槸杩欎袱鏉★細
   *    路 **褰㈠彉瀹瑰櫒**锛歚applyMorphProgress()` 閲?`morphRadius = visualRadius / scale`锛?
   *      鑰?`visualRadius = initRadiusVisual * (1 - t)`锛坄initRadiusVisual = 鑳跺泭楂?/ 2`锛?
   *      鈥斺€?杩?*宸茬粡灏辨槸鏃犵晫鐨勫舰鐘?*锛氫袱绔偣绾挎€ф彃鍊?+ **闄や互 scale**
   *      锛堟竻鍗?搂涓€ 1.4 鐨?`coverRadiusAt = coverVisualRadiusAt / coverScaleAt`锛夛紱
   *      宸殑鍙槸缁堢偣鍊硷紙鎴戜滑 0銆佹棤鐣?34锛屼笖鍙ｅ緞涓嶅悓锛氭垜浠畻**鏁撮〉瀹瑰櫒**锛屾棤鐣岀畻**灏侀潰鏈韩**锛夛紱
   *    路 **灏侀潰鏈韩**锛氬睍寮€椤靛皝闈㈢殑鍦嗚鏉ヨ嚜**鐢ㄦ埛璁剧疆** `CoverRadiusState`
   *      锛坄MusicPlayInfoBlock` 鈫?`AppStorageV2.connect(CoverRadiusState 鈥?`锛?
   *      鈬?鏃犵晫閭ｄ釜"缁濆鍊?34"**缁濅笉鑳界収鎶?*锛岀収鎶勪細瑕嗙洊鐢ㄦ埛鍦ㄨ缃噷鐨勯€夋嫨銆?
   *    鈬?缁撹涓庢竻鍗?搂鍥?D3 涓€鑷达紙淇濈暀鐜扮畻娉曘€佸彧鏍囧樊寮傦級锛屼絾宸紓鐨勮惤鐐规槸**姝讳唬鐮?*锛?
   *      鏈嚱鏁板彧涓?璁板綍鏃犵晫鍙ｅ緞"鑰岀暀锛?*涓嶈**涓轰簡瀵归綈瀹冨幓鏀瑰渾瑙掋€?
   * @returns 琛ュ伩鍚庣殑鍦嗚锛坴p锛夈€傗殸锔?鏃犺皟鐢ㄧ偣锛堣涓婏級銆?
   */
  public coverVisualRadius(): number {
    const base: number = this.coverRadius();
    const mini: number = this.miniSize;
    const size: number = this.coverSize();
    if (mini <= 0 || size <= 0) {
      return base;
    }
    // 浠ヨ糠浣犳潯閭ｄ竴绔负鍩哄噯绛夋瘮缂╂斁锛涘睍寮€绔殑鍦嗚鏈韩灏辨槸璁捐鍊硷紝涓嶉渶瑕佽ˉ鍋?
    const scaled: number = base * (size / mini);
    const cap: number = base * 1.6;
    return Math.min(scaled, cap);
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?浜屻€佸皝闈㈢画椋炲埌姝岃瘝椤碉紙瀵规爣 CoverMorph 鍙岀鐐癸級鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
  //
  // 鏃犵晫閭ｅ鐨?CoverMorph 鏈?*涓ゅ绔偣**锛歚topYAtPlayer/tyAt/scaleAt/radiusAt`锛堟挱鏀鹃〉锛?
  // 涓?`topYAtLyric/bottomYAtLyric/tyLyric/lyricVisualEdge`锛堟瓕璇嶉〉锛夆€斺€?
  // 璇存槑姝岃瘝椤电殑灏侀潰涓嶆槸"鍙︿竴椤电殑鍏冪礌"锛岃€屾槸**鍚屼竴寮犲皝闈㈢户缁杩囧幓鐨?*銆?
  //
  // 鎴戜滑杩欒竟**鍒绘剰涓嶉潬杩愯鏃舵祴閲?*锛氭瓕璇嶉〉灏侀潰鐨勪綅缃洿鎺ョ敱绐楀彛灏哄绠楀嚭鏉?
  // 锛坄LYRIC_COVER_EDGE_VP` + 鍑犱釜姣斾緥锛夛紝杩欐牱锛?
  //   1. 涓嶄緷璧?`onAreaChange` 鐨勬椂搴忥紙閭ｄ釜鍦ㄥ垏椤靛姩鐢婚噷寰堝鏄撴嬁鍒颁腑闂存€侊級锛?
  //   2. 浠绘剰鏃跺埢鎵撴柇閮借嚜娲斤紱
  //   3. 绐勫睆/瀹藉睆閮借窡鐫€绐楀彛璧帮紝涓嶇敤涓烘瘡绉嶆柇鐐瑰悇閰嶄竴濂椼€?

  /**
   * 姝岃瘝椤靛皬灏侀潰鐨?*缁濆杈归暱**锛坴p锛夈€?
   *
   * 鈽?瀵规爣鏃犵晫 `PlayerPage.CoverMorph` 鐨?`LYRIC_COVER_EDGE = 48.72`
   *   锛坄func_main_0` 闂寘妲?`0x05`锛宍wujie.pa:197901` 璧凤紱鍚屼竴澶勮繕鏈?`0x04 = -40` 鐨?
   *   `tyPlayer`銆乣0x14 = 0.32` 鐨?`COMMIT_T`锛夈€?
   *
   * **鏃犵晫杩欓噷鏄釜纭笉鍙橀噺**锛歚lyricScale = 48.72 / edge` 鈬?
   * **`edge 脳 lyricScale 鈮?48.72`** 鈥斺€?姝岃瘝椤甸偅鏋氬皬灏侀潰涓庛€屾湰椤靛ぇ灏侀潰澶氬銆?*鏃犲叧**锛?
   * 鎭掑畾 48.72vp銆俙edge` 鐨勫父鎬佸€兼槸 328锛? `coverEdgeMaxOf` 鐨勪骇鐗╋紝**涓嶆槸榛樿鐨?348**锛夛紝
   * 鈬?`lyricScale 鈮?0.1485`锛涙瀯閫犲櫒閭ｄ釜鍏滃簳 `0.14` 姝ｅソ = `48.72 / 348`锛屽嵆榛樿 `edge` 閭ｄ竴妗?
   * 锛堜袱鏉¤矾鑷唇锛屽彲浣滀氦鍙夐獙璇侊級銆?
   *
   * 鈿狅笍 鏈疆涔嬪墠杩欓噷鏄竴涓?*姣斾緥**锛坄LYRIC_COVER_SCALE_RATIO = 0.52`锛岄殢澶у皝闈竴璧峰彉澶э級鈥斺€?
   *   鏈疆涓や唤鏂版枃妗ｉ兘鐐瑰悕"閲忕翰涓嶅悓銆佷笉鍙鍙?銆佸苟**鐩存帴缁欎簡鏀规硶**锛?
   *   路 `_recover\logic-src\鏃犵晫vs娲鹃煶-宸紓鍒嗘瀽.md` 搂銆囥€屾牴鍥犲凡纭锛堟湰杞柊瑙ｏ紝鐩存帴鍙妱锛夈€?
   *     鈥斺€?姝岃瘝椤靛皝闈細鏃犵晫灏忋€佹淳闊冲眳涓ぇ"鐨勬牴鍥狅紱
   *   路 `_recover\logic-src\姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` 搂7.2 / 搂7.4銆屾渶鐭敼鍔ㄥ缓璁€嶇 1 鏉?
   *     鈥斺€?鎶?`lyricCoverSizeOf()` 浠庢瘮渚嬫敼鎴愬父閲?`48.72`锛? 琛岋級"銆?
   *   楠屾敹鍒ゆ嵁锛堝悓鏂囨。 搂6锛夛細`edge 脳 lyricScale === 48.72`锛堟诞鐐?卤0.01锛夈€?
   *
   * 鈿狅笍 **鍗曟簮**锛歚_recover\logic-src\浜や粯鐗╀氦鍙夋牳瀵硅褰?md` 搂9.9 鎶?姝岃瘝椤垫诞灞傛暣鏃?
   *   鍒椾负鍗曟簮鏈鏍?鈬?鏈疆**鍙惤浜嗚繖涓€涓暟**锛涘悓涓€浠芥枃妗?搂7.4 寤鸿鐨勫彟涓ゆ潯
   *   锛坄lyricMetaYOf()` 閿氱偣鏀规垚"灏侀潰椤惰竟 鈭?26"銆佽ˉ OFF/AUTO/濮嬬粓寮€鍚?鐢ㄦ埛妗ｄ綅锛?*娌¤惤**锛?
   *   鐞嗙敱瑙佽鏂?搂8 鐨?U1锛堝潗鏍囩郴姝т箟锛変笌"灞炴柊澧炲姛鑳姐€侀潪鏁板€煎榻?銆?
   *
   * 鈽呪槄 2026-10-15锛圧ound 23 瀵圭潃瀹氱閫愭潯澶嶆牳锛?*缁撹锛氶敋鐐硅繖涓€鍗婂凡缁忓浜嗭紝`鈭?6` 涓嶈鎸夌粷瀵?Y 鐢?*锛夛細
   *   路 **閿氱偣宸插銆佷笉瑕佹敼**锛氬畾绋?L1417 鐨勫師鏂囨槸
   *     銆屾瓕鍚嶇殑缁堢偣閿氬湪"**灏忓皝闈㈤《杈?*"涓婏紝涓嶆槸"鐩掗《"銆嶏紝鑰?`lyricMetaYOf()` 鐜板湪姝ｆ槸
   *     `return this.lyricCoverYOf()`锛堜笌灏侀潰**鍚岄《杈?*銆佸苟鎺掓憜鏀撅級鈬?涓?L1417 涓€鑷淬€?
   *   路 **`鈭?6` 涓嶈兘鐩存帴鐢?*锛氬畾绋?L870 / L1100 缁欏嚭鐨勬槸
   *     `metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)`
   *     鈥斺€?`鈭?6` 鏄?*杩欎釜 lerp 缁堢偣鐨?浣嶇Щ閲?**锛坄metaTopFixLyric`锛夛紝**涓嶆槸缁濆 Y**锛?
   *     鑰屽彟涓€绔?`metaYPlayer` 鍑鸿嚜 `fitPlayerOverlay` 鐨?
   *     `metaY = curMetaY + edge/2 + gap + metaH/2`锛堝甫 `+ metaH/2` 鈬?閭ｆ槸**涓績**锛夈€?
   *     鎶?灏侀潰椤惰竟 鈭?26"褰撴垚**椤惰竟**濉炶繘鎴戜滑鐨?*缁濆瀹氫綅**锛坄.position({ y })`锛変綋绯伙紝
   *     浼氳姝屽悕鏁村潡鍐嶄笂绉荤害 `26 + 琛岄珮/2 鈮?43vp`锛堣窇鍒板皬灏侀潰涓婃柟锛夈€?
   *   路 瀹氱 搂8 鐨?**U1 鑷充粖鏈‘璁?*锛坄META_Y_PLAYER_MAX(-214)` 涓?`fitPlayerOverlay`
   *     鐨勭粨鏋滄槸鍚﹀悓涓€鍧愭爣绯伙級鈬?**鍧愭爣绯绘病瀹氫箣鍓嶄笉璁稿姩杩欎釜鏁?*銆?
   *   鈬?瑕佸姩瀹冿紝鍏堟嬁涓€娆?*涓婃満瑙傛祴瀹氬潗鏍?*锛氳鐢ㄦ埛鐪?姝岃瘝椤垫瓕鍚嶇浉瀵瑰皬灏侀潰鍋忛珮杩樻槸鍋忎綆"锛?
   *     鍐嶆嵁姝ょ粰鍋忕Щ閲忋€傚畬鏁存帹鐞嗚 `RzdMusic璁板繂.md` 搂56.18銆?
   */
  private static readonly LYRIC_COVER_EDGE_VP: number = 48.72;
  /** 姝岃瘝椤靛皝闈㈤《閮ㄧ浉瀵瑰睍寮€椤靛皝闈㈤《閮ㄧ殑涓嬬Щ姣斾緥锛堝崰灞曞紑椤靛皝闈㈤珮搴︼級銆?*/
  private static readonly LYRIC_COVER_TOP_RATIO: number = 0.06;
  /** 姝岃瘝椤甸偅涓€妯鐨勯《杈?= 绐楀彛楂樺害鐨勮繖涓瘮渚嬶紙鐘舵€佹爮浼扮畻锛?*鍔犱笂**椤舵爮楂樺害銆?*/
  private static readonly LYRIC_COVER_TOP_RATIO_STATUS: number = 0.07;
  /** 椤舵爮楂樺害锛坴p锛夆€斺€斾笌 `TopAreaComponent.height(56)` / 鏃犵晫 `Tokens.BAR_H = 56` 鍚屽€笺€?*/
  private static readonly LYRIC_ROW_TOPBAR_H_VP: number = 56;
  /**
   * 椤堕儴璁╀綅鐨?*涓嬮檺**锛坴p锛夆€斺€?瀵规爣鏃犵晫 `PlayerPage.PLAYER_TOP_FALLBACK = 56`
   * 锛坄姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` L1295锛沗padTop()` 閲屽綋"涓嬮檺"鐢紝瑙?`topInsetVp()`锛夈€?
   */
  private static readonly PLAYER_TOP_FALLBACK_VP: number = 56;
  /**
   * 姝岃瘝椤靛皬灏侀潰鐨?*宸﹁竟鐣?*锛坴p锛夈€?
   *
   * 鈽?2026-10-15锛堢収鎼棤鐣岋級锛氭瓕璇嶉〉鏄?`[灏忓皝闈[姝屽悕/姝屾墜][鏀惰棌][鏇村]` 涓€妯锛?
   *   灏侀潰璐磋棣栥€傚彇鍊间笌 `PlaybackPage.LYRIC_META_SIDE_VP`锛堥偅涓€琛岀殑宸﹀彸鐣欑櫧锛?*蹇呴』涓€鑷?*锛?
   *   鍚﹀垯灏侀潰涓庢瓕鍚嶄細閿欏紑涓€鏉＄紳銆?
   */
  private static readonly LYRIC_COVER_LEFT_VP: number = 16;
  /** 鍏滃簳灏侀潰杈归暱涓婇檺锛堟棤鐣?`CoverMorph` 妯″潡甯搁噺 `COVER_EDGE_CAP = 480`锛夈€?*/
  private static readonly COVER_EDGE_CAP_VP: number = 480;
  /** 鍏滃簳灏侀潰杈归暱涓嬮檺锛堟棤鐣?`COVER_EDGE_MIN = 200`锛夈€?*/
  private static readonly COVER_EDGE_MIN_VP: number = 200;
  /** 鍏滃簳灏侀潰杈归暱 = 绐楀彛鐭竟鐨勮繖涓瘮渚嬶紙鏃犲疄娴嬫椂鐨勯噺绾т及璁★紱浠呭厹搴曪紝姝ｅ父璺緞鐢ㄤ笉鍒帮級銆?*/
  private static readonly COVER_EDGE_FALLBACK_RATIO: number = 0.62;
  /** `fitPlayerOverlay` 鐨勯珮搴﹂绠楁墸鍑忛」锛堟棤鐣岋細`availH 鈭?2路(gap + metaH + 8)`锛夈€?*/
  private static readonly COVER_FIT_META_H_VP: number = 60;
  /**
   * 鈿狅笍 2026-10-16锛?*宸蹭笉鍐嶄娇鐢?*锛夛細杩欐槸 `fitPlayerOverlay` 閲岄偅涓?纭紪鐮?8"鐨?*鏃т及绉?*锛?
   *   鎴戝師鏉ヨ繕澶氱紪浜嗕竴涓?`COVER_FIT_GAP_VP = 20`锛?*鏃犵晫娌℃湁杩欎釜鍊?*锛屽畠鐨?gap 榛樿鏄?50锛夈€?
   *   鐜板湪 `playerCoverGeomRect()` 宸查€愬瓧鐓ф妱鏃犵晫 鈬?鐢?`COVER_FIT_META_GAP_VP(50)`
   *   涓?`COVER_FIT_BOUND_INSET_VP(8)`锛屾湰甯搁噺涓?`COVER_FIT_INSET_VP` 涓€璧?*涓嬬嚎**銆?
   *   淇濈暀澹版槑鏄负浜嗕笉鐗靛姩鍒锛涗笅涓€娆℃竻鐞嗘椂鍙竴骞跺垹闄ゃ€?
   */
  private static readonly COVER_FIT_GAP_VP: number = 20;
  /** 鈿狅笍 宸蹭笉鍐嶄娇鐢紙鏀圭敤 {@link COVER_FIT_BOUND_INSET_VP}锛夛紝鐞嗙敱鍚屼笂銆?*/
  private static readonly COVER_FIT_INSET_VP: number = 8;
  /**
   * 灏侀潰鍦嗚鍗犲叾鐭竟鐨勬瘮渚嬶紙灞曞紑椤甸偅涓€绔級銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋細淇敤鎴峰疄娴嬨€?*鏃犵晫灞曞紑鎾斁鍣ㄦ椂鍦嗚鏇村ぇ**銆嶏級锛?
   *   鏃犵晫閭ｄ竴绔殑鍦嗚鏄?`CoverMorph.radiusPlayer = 8`锛坴p锛?*缁濆鍊?*锛?
   *   `_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` 搂浜?鐨勭被瀛楁琛?+ `85481 ldai 0x8`锛夛紝
   *   鑰屽叾 `edge` 榛樿 348锛坄ldai 0x15c`锛夆噿 **姣斾緥 = 8 / 348 鈮?0.02299**銆?
   *   鈬?杩欓噷鐢?*鍚屼竴涓瘮渚?*鑰屼笉鏄媿涓€涓暟锛歚edge` 鍙橈紙涓嶅悓鏈哄瀷锛夋椂鍦嗚鍚屾瘮璧帮紝
   *     涓庢棤鐣?缁濆鍊兼亽瀹氥€佹瘮渚嬮殢 edge 娴姩"鍙湪榛樿 edge 涓婄瓑浠?鈥斺€?浣嗗鎴戜滑杩欑
   *     `edge` 鐢?fitPlayerOverlay 绠楀嚭鏉ョ殑瀹炵幇锛屾瘮渚嬪啓娉曟洿绋筹紙涓嶄細鍦ㄥ皬灞忎笂鎶婂渾瑙掑帇鎴?0锛夈€?
   *   鈿狅笍 鏀瑰墠鏄?0.06锛堚増 22vp @edge 369锛夆€斺€?姣旀棤鐣屽ぇ 2.6 鍊嶏紝瑙傛劅灏辨槸"鍦嗚鏄庢樉鏇村ぇ/鏇存柟鍦?銆?
   *      鍘熷€兼寜"鏃犵晫閭?348 / 8"涓€绠楀嵆鍙鐜帮細`8 / 348`銆?
   */
  private static readonly COVER_RADIUS_RATIO: number = 8 / 348;

  /**
   * 灏侀潰鍦ㄣ€屽睍寮€椤碉紙灏侀潰椤碉級銆嶉偅涓€绔殑鍦嗚锛坴p锛?*缁濆鍊?*锛夆€斺€?鐓ф妱鏃犵晫 `CoverMorph.radiusPlayer`銆?
   *
   * 鍑哄锛歚wujie.pa:85471`锛堣榛樿鍊硷級鈫?`85481 ldai 0x8` 鈬?**8**锛?
   *   绫诲瓧娈佃〃瑙?`_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md`锛坄radiusPlayer = 8`锛夈€?
   *
   * 鈽呪槄鈽?2026-10-17锛堢敤鎴凤細**銆屾垜浠殑杞欢閲岄潰鏈変釜鑷畾涔夊皝闈㈠渾瑙掍篃鍒犱簡鍚с€?*锛?
   *   鈬?鏈父閲忕幇鍦ㄦ槸**灏侀潰鍦嗚鐨勫敮涓€鏉ユ簮**锛堝唴缃挱鏀鹃〉銆佹诞灞傚厠闅嗐€佸灞?闈㈡澘涓夊閮藉彇瀹冿級锛?
   *     璁剧疆椤甸偅涓€椤逛笌 `MusicStoreService.getCoverCornerRadius()` **涓嶅啀鍙備笌浠讳綍娓叉煋**銆?
   *   鈿狅笍 杩欎篃涓€骞朵慨鎺変簡"鍔ㄧ敾缁撴潫鏃跺皝闈㈠渾瑙掔獊鐒惰烦涓€涓?锛氫袱绔悓鍊?鈬?浜ゆ娌℃湁宸€?
   */
  public static readonly COVER_RADIUS_PLAYER_VP: number = 8;

  /**
   * 灏侀潰鍦ㄣ€屾瓕璇嶉〉銆嶉偅涓€绔殑鍦嗚锛?*瑙嗚鍊?*锛寁p锛夆€斺€?鐓ф妱鏃犵晫 `CoverMorph.radiusLyricVisual`銆?
   *
   * 鍑哄锛歚wujie.pa:85486`锛堣榛樿鍊硷級鈫?`85494-85496` 鐨?`mov`/鍏滃簳 鈬?榛樿 **12**銆?
   *
   * 鈽呪槄鈽?2026-10-16锛堢敤鎴峰疄娴嬶細銆?*姝岃瘝椤甸潰鐨勫皝闈㈠渾瑙掑お灏忎簡**銆嶏級锛?
   *   鏃犵晫鐨勪袱绔渾瑙掓槸 **`lerp(radiusPlayer 8, radiusLyricVisual 12, t)`**
   *   锛坄wujie.pa:85731-85743` 鐨?`visualRadiusAt`锛岃皟鐨勬槸鏈枃浠剁殑 `lerp`锛夛紝
   *   鐒跺悗 `radiusAt = visualRadiusAt / scaleAt`锛坄85604-85613`锛夈€?
   *
   *   鈿狅笍 鎴戜滑鏀瑰墠鐢ㄧ殑鏄?`radius = lerp(fromRect.radius, toSize 脳 COVER_RADIUS_RATIO 8/348, t)`锛?
   *     `toSize` 鏄瓕璇嶉〉閭ｅ紶灏忓皝闈㈢殑杈归暱锛堚増244vp锛夆噿 缁堢偣鍦嗚鍙湁 **鈮?.6vp**锛?
   *     鑰屾棤鐣屾槸 **12vp** 鈬?宸竴鍊嶅锛岃繖灏辨槸"鍦嗚澶皬"銆?
   *   鈿狅笍 閭ｄ釜 `8/348` 姣斾緥鏄?*灞曞紑椤?*閭ｄ竴绔殑鍙ｅ緞锛坄edge` 澶э級锛屾妸瀹冨鍒?*姝岃瘝椤靛皬灏侀潰**
   *     涓婃槸鎶婁袱涓鐐圭敤閿欎簡鍚屼竴涓叕寮?鈥斺€?鍏稿瀷"鍚屼竴褰㈢姸涓ゅ鍙ｅ緞娣风敤"銆?
   *   鈬?鐜板湪涓ょ鍚勮嚜鍙?*鑷繁鐨勭粷瀵瑰€?*鍐嶆彃鍊硷紝涓庢棤鐣岄€愬瓧涓€鑷淬€?
   *   鈿狅笍 鐢ㄦ埛璁剧疆閲岀殑 `CoverRadiusState`锛堣 `MusicPlayInfoBlock`锛?*涓嶅彈褰卞搷**锛?
   *     瀹冪鐨勬槸"灞曞紑椤甸潤姝㈡€佺敤鎴烽€夌殑鍦嗚"锛屾湰鍑芥暟鍙湪 `t > 0`锛堟瓕璇嶉〉閭ｄ竴瓒燂級鍙備笌銆?
   */
  private static readonly COVER_RADIUS_LYRIC_VISUAL_VP: number = 12;

  /** 姝岃瘝椤靛皝闈㈢煩褰㈡槸鍚︽湁鏁堬紙绐楀彛灏哄鎷垮埌浜嗘墠绠楀緱鍑烘潵锛夈€?*/
  public lyricGeometryReady(): boolean {
    return this.bigSize > 0 || (this.windowWidthVp > 0 && this.windowHeightVp > 0);
  }

  /**
   * @returns 灞曞紑椤靛皝闈㈢殑瀹藉害锛坴p锛夆€斺€?**涓婃姤鍊?OR 瀹炴祴鍊?*锛堜袱鏉℃潵婧愶紝缂轰竴涓嶅彲锛夈€?
   *
   * 鈽呪槄鈽?2026-10-17锛?*鐢ㄦ埛鎴浘瀹氫綅鍒扮殑鐪?bug**锛氬窘鏍囦笂 `lcEdge=0.0` + `float=0`
   *   鑰?`end=331/331` 鈥斺€?缁堢偣閿氱偣鏄庢槑閲忓埌浜嗭紝姝岃瘝椤靛皝闈㈠嵈绠椾笉鍑烘潵锛夈€?
   *
   * ## 涓轰粈涔堝師鏉ュ彧鏈?`bigSize` 杩欎竴鏉℃潵婧愭槸涓嶈鐨?
   * ```
   *   `bigSize` 鐨勫敮涓€鏉ユ簮 = 瑕嗙洊灞傚皝闈?Image 鐨?`onAreaChange` 鈫?`reportPlayerCoverFromOverlay`
   *   鑰岄偅鏉′笂鎶ユ湁涓ら亾闂細
   *     鈶?`lyricMorphT > 0.001 鈬?return`锛堝彧鍦ㄥ皝闈㈤〉闈欐鏃舵姤锛夛紱
   *     鈶?`coverAnchorMeasurable()`锛?*褰㈠彉涓竴寰嬩笉鎶?*锛夈€?
   *   鈬?鎵撳紑鎾斁椤垫椂锛氶〉闈竴鎸傝浇灏辫繘褰㈠彉锛圗NTERING锛夛紝閭ｄ竴鍒荤殑 `onAreaChange` **琚?鈶犫憽 鎷掓帀**锛?
   *     褰㈠彉缁撴潫钀戒綅涔嬪悗锛屽皝闈㈣妭鐐圭殑**闈㈢Н涓嶅啀鍙樺寲** 鈬?`onAreaChange` **涓嶄細鍐嶈Е鍙?*
   *     鈬?**`bigSize` 鏁村満閮芥槸 0**锛堢敤鎴烽偅涓ゅ紶鎴浘灏辨槸 `lcEdge=0.0`锛夈€?
   * ```
   * ## 鍚庢灉锛堝氨鏄敤鎴锋姤鐨勭 1銆? 鏉★級
   * ```
   *   `lyricCoverSizeOf()` 杩斿洖 0 鈬?`lyricFloat()` = false
   *     鈬?姝岃瘝椤甸偅灞傛诞灞傦紙灏忓皝闈?+ 姝屽悕锛?*鏁村満涓嶅惎鐢?* 鈬?銆岀 1 娆℃粦鍒版瓕璇嶉〉灏侀潰浼氭秷澶便€?
   *     鈬?鑰屼笖 `lyricMorph(1)`锛堟瓕璇嶉〉绔偣锛変篃璺熺潃鏃犳晥 鈬?鍒囬〉鏃跺皝闈㈡病鏈夊悎娉曠粓鐐?
   * ```
   * ## 鏀规硶锛?*涓嶆槸鏂板彂鏄?*锛氱粓鐐归偅涓€渚ф棭灏辨槸杩欎箞鍐欑殑锛?
   *   `endCoverSize` 鐨勫彇鍊煎湪 `measureEndAnchor` 涓€甯﹀氨鏄?
   *   ```ts
   *     this.endCoverSize = this.bigNodeKnown && this.bigNodeW > 0 ? this.bigNodeW : this.bigSize;
   *   ```
   *   鈥斺€?"**瀹炴祴鍊间紭鍏堬紝涓婃姤鍊煎厹搴?*"銆傛湰鍑芥暟鍘熸潵鍙涓婃姤鍊?鈬?涓庡畠涓嶅悓鍙ｅ緞銆?
   *   鈬?鐜板湪瀵归綈鎴愬悓涓€鏉″彛寰勶紙`bigNodeW` 鏄?FrameNode 瀹炴祴瀹藉害锛屾湰鏉ュ氨鏈夈€佷笖宸茶缁堢偣閭ｄ晶鐢ㄧ潃锛夈€?
   *   鈿狅笍 `lyricCoverSizeOf()` 閭ｉ亾 `<= 0 鈬?杩斿洖 0` 鐨勯棬**淇濈暀涓嶅姩**锛堣涔変笉鍙橈細
   *      "澶у皝闈㈠搴︾‘瀹炴湭鐭?鈬?娴眰涓嶅惎鐢?锛夛紝鍙槸鐜板湪"宸茬煡"鐨勫垽鎹笉鍐嶅彧渚濊禆閭ｄ竴鏉′笂鎶ャ€?
   */
  private playerCoverWidth(): number {
    if (this.bigNodeKnown && this.bigNodeW > 0) {
      return this.bigNodeW;
    }
    if (this.bigSize > 0) {
      return this.bigSize;
    }
    return 0;
  }

  /**
   * @returns 姝岃瘝椤靛皝闈㈣竟闀匡紙vp锛夆€斺€?鎭掑畾鐨?{@link PlayerExpandState.LYRIC_COVER_EDGE_VP}銆?
   *
   * 鈿狅笍 **"澶у皝闈㈣繕娌￠噺鍒板氨杩斿洖 0"杩欐潯闂ㄥ繀椤讳繚鐣?*锛歿@link lyricFloat} 鐢ㄥ畠褰?鍑犱綍灏辩华"鐨?
   *    绗簩闂紙`lyricCoverSizeOf() > 0`锛夆€斺€?澶у皝闈㈡湭涓婃姤鏃惰嫢杩樿繑鍥炲父閲忥紝娴眰浼氭彁鍓嶅惎鐢ㄣ€?
   *    璁╂瓕璇嶅嚟绌哄鍑轰竴娈甸《閮ㄧ暀鐧姐€?
   */
  public lyricCoverSizeOf(): number {
    if (this.playerCoverWidth() <= 0) {
      return 0;
    }
    return PlayerExpandState.LYRIC_COVER_EDGE_VP;
  }

  /**
   * @returns 姝岃瘝椤靛皝闈㈠乏杈圭晫銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*闈犲乏**锛屼笉鍐嶆槸姘村钩灞呬腑銆?
   *   鏃犵晫鐨勬瓕璇嶉〉鏄?*涓€妯** `[灏忓皝闈[姝屽悕/姝屾墜][鏀惰棌][鏇村]`锛坄metaRow`锛岃
   *   `PlayerPage瀹屾暣UI瀹氱.md` 搂6.2锛夛紝灏侀潰鍦ㄨ鐨勬渶宸︾銆佷笌姝屽悕骞舵帓 鈥斺€?
   *   鍘熸潵杩欓噷杩斿洖 `(winW - size) / 2`锛堝眳涓級锛屾墍浠ユ淳闊崇湅璧锋潵鏄?灞呬腑灏忓皝闈?+ 姝屽悕鍦ㄥ畠涓嬮潰"锛?
   *   鑰屾瓕鍚嶉偅鍧楀張琚帓鍒板皝闈?*涓嬫柟**锛堣 `lyricMetaYOf`锛夆噿 涓庢棤鐣屽畬鍏ㄤ笉鍚屻€?
   */
  public lyricCoverXOf(): number {
    return PlayerExpandState.LYRIC_COVER_LEFT_VP;
  }

  /**
   * @returns 姝岃瘝椤靛皝闈笂杈圭晫锛? 閭ｄ竴妯鐨勯《杈癸級銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*璐村湪椤舵爮涔嬩笅**銆?
   *
   * 鍘熸潵鏄?灞曞紑椤靛皝闈㈤《杈?+ 灏侀潰楂樺害鐨?6%" 鈬?鍦?780 楂樻満鍨嬩笂 鈮?**246vp**锛?
   * 钀藉湪灞忓箷绾?1/3 澶勶紱鑰屾棤鐣屾埅鍥鹃噷灏忓皝闈㈢殑椤惰竟涓庨《鏍忕殑 `鈱刞 **澶ц嚧榻愬钩**锛堚増 110vp锛夈€?
   * 鐜板湪锛濈姸鎬佹爮浼扮畻鍊?+ 椤舵爮楂樺害锛坄topBarH = 56`锛屼笌娲鹃煶 `TopAreaComponent.height(56)` 鍚屽€硷級銆?
   *
   * 鈿狅笍 杩欐潯鍚屾椂鍐冲畾 `lyricMetaYOf()`锛堝苟鎺?鈬?鍚岄《杈癸級涓?`lyricPadTop()`锛堟瓕璇嶈浣嶉珮搴︼級锛?
   *    鎵€浠ユ敼瀹冧細鏁翠綋涓婄Щ鈥斺€斾笁澶勫彛寰勯兘璺熺潃璧帮紝涓嶄細鎵撴灦銆?
   */
  public lyricCoverYOf(): number {
    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋紱淇敤鎴峰疄娴嬨€?*鍐呭娌″欢浼歌繘鐘舵€佹爮**銆嶏級锛?
    //   杩欓噷鍘熸潵鏄?`windowHeightVp 脳 LYRIC_COVER_TOP_RATIO_STATUS(0.07)` 鈥斺€?
    //   涓€涓?*鐘舵€佹爮浼扮畻姣斾緥**锛?25vp 楂樼殑灞忎笂绠楁垚 鈮?5vp锛岃€岀湡鏈虹姸鎬佹爮閫氬父鍙湁 30~40vp锛?
    //   鈬?椤堕儴鍑┖澶氳浣?~25~35vp銆傜幇鍦ㄦ敼璧?`topInsetVp()`锛? 鏃犵晫鐨?`padTop()`锛夈€?
    const topInset: number = this.topInsetVp();
    return topInset + PlayerExpandState.LYRIC_ROW_TOPBAR_H_VP;
  }

  /**
   * 鎾斁椤靛唴瀹圭浉瀵圭獥鍙ｉ《杈圭殑**椤堕儴璁╀綅**锛坴p锛夆€斺€?瀵规爣鏃犵晫 `PlayerPage.padTop()`銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛氭棤鐣岄偅涓や釜鍑芥暟
   *   锛坄wujie.pa:175250-175353`锛岃浆鍐欒 `_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md`
   *   L506 / L509 / L790 / L791锛夋槸锛?
   * ```
   *   padTop()    = max(avoidTop,    PLAYER_TOP_FALLBACK = 56)   // 鐪熷疄鐘舵€佹爮閬胯鍖猴紝涓嬮檺 56
   *   padBottom() = max(avoidBottom, FULL.bottomGap      = 65)   // 鐪熷疄瀵艰埅鏉￠伩璁╁尯锛屼笅闄?65
   *   usableH()   = winHVp() - padTop() - padBottom()
   * ```
   *   鈬?**鐢?鐪熷疄閬胯鍖?+ 涓嬮檺"**锛屼笉鏄瘮渚嬩及绠椼€?
   *   鈿狅笍 鎴戜滑鐨?*闈㈡澘鍒嗘敮鏃╁氨鍦ㄧ敤鐪熷疄鍊?*锛坄PlaybackPage` 閭ｆ潯
   *      `.padding({ top: windowInfo.statusBarTopVp, bottom: windowInfo.navigationBarBottomVp })`锛夛紝
   *      鍙湁鎵嬫満杩欎竴鏀繕鍦ㄧ敤姣斾緥 鈬?灞?*鍐呴儴鍒嗗弶**锛屾湰杞粺涓€鍒?鐪熷疄鍊?+ 涓嬮檺"銆?
   *
   * 鈿狅笍 閲忎笉鍒帮紙`statusBarTopVp <= 0`锛氱獥鍙ｄ俊鎭繕娌″洖璋?/ 鏌愪簺绐楀彛褰㈡€侊級鏃?*閫€鍥炲師鏉ョ殑姣斾緥浼扮畻**锛?
   *   淇濊瘉涓庢敼鍓嶈涓轰竴鑷?鈥斺€?涓嶄細鍥犱负"閲忎笉鍒?灏辨妸鍐呭椤惰繘鐘舵€佹爮閲屻€?
   * 鈿狅笍 `padBottom()` 閭ｄ竴鍗婏紙涓嬮檺 65锛?*鏈疆娌℃帴**锛氬畠瑕佹敼鐨勬槸搴曢儴/鎺у埗鍖虹殑璁╀綅锛?
   *   涓?椤堕儴"鏄袱浠朵簨锛岀櫥璁颁负寰呭姙锛堣 `RzdMusic璁板繂.md` 搂56.24锛夈€?
   * @returns 椤堕儴璁╀綅锛坴p锛?
   */
  /**
   * 鎾斁椤?*椤电洅椤惰竟**鍦ㄧ獥鍙ｉ噷鐨?y锛坴p锛屽疄娴嬶紱0 = 杩樻病閲忓埌锛夆€斺€?鍠傜粰 {@link topInsetVp}銆?
   *
   * 鈽呪槄 2026-10-15锛坄RzdMusic璁板繂.md` 搂56.50锛夛細**杩欐槸"鍙岄噸璁╀綅"鐨勮В鑽紝鑰屼笖鏈粨鏃╂湁鍏堜緥** 鈥斺€?
   *   `common/musicbasic/.../PageTopInsetHelper.ets` 鐨勭被娉ㄩ噴灏辨槸涓?*鍚屼竴涓?bug** 鍐欑殑
   *   锛?026-10-11 閭ｈ疆鐪熸満鎴浘閲忓埌 `+48vp`锛屽苟鏄庣‘鍐欍€岃浣嶉噺鏄?*鐩稿鐩掗《**鐨勶細
   *   `鐩掗《 = 0` 鏃惰璁?`鐘舵€佹爮 + 56`锛岃€?`鐩掗《 = 鐘舵€佹爮` 鏃跺彧璇ヨ `56`銆嶏級銆?
   *
   * 鈿狅笍 鎴戜滑鍘熸潵鐨?`topInsetVp()` **姝ｆ槸閭ｅ彞娉ㄩ噴鐐瑰悕鐨勯敊娉?*锛堟寜"鐩掗《 = 0"鍐欙級鈥斺€?
   *   鍦?妗嗘灦鎶婇〉鐩掗《鍒板畨鍏ㄥ尯鍐?鐨勬満鍣ㄤ笂灏变細**澶氳涓€涓姸鎬佹爮** 鉁?
   *   锛堟湰鏈哄疄娴嬫繁鑹插甫 47/45vp銆侀《鏍?112 鈮?47 + 56锛屽畬鍏ㄥ搴旓級銆?
   *
   * 鈽?涓轰粈涔堟妸瀹冨仛鎴?**鑷€傚簲淇**"鑰屼笉鏄洿鎺ユ敼鎴愮洅鍐呮崲绠楋細
   *   `topInsetVp()` 鐨勭洰鏍囨槸璁?*鍐呭椤惰竟钀藉湪绐楀彛鐨?`max(鐘舵€佹爮,56)` 閭ｆ潯绾夸笂**锛?
   *   鑰?鍐呭椤惰竟 = 鐩掗《 + 璁╀綅" 鈬?`璁╀綅 = target 鈭?鐩掗《` 鈬?**瀵圭洅椤跺彇 0 鎴?47 閮界粰鍑哄悓涓€涓粨鏋?*锛?
   *     路 鐩掗《 0锛堥〉鏍规墿灞曠敓鏁堬級鈬?璁╀綅 56 鈬?椤惰竟 56 鉁?
   *     路 鐩掗《 47锛堟墿灞曟病鐢熸晥锛夆噿 璁╀綅 9  鈬?椤惰竟 56 鉁?
   *   鈬?**涓嶄細鍙岄噸鎵ｅ噺**锛屽彧璁╃粨鏋滃"鎵╁睍鍒板簳鏈夋病鏈夌敓鏁?鍏嶇柅 鉁?
   *   锛堣繖姝ｆ槸 搂56.50 閲岀暀鐨勫厹搴?(b)锛屾湰杞殑鎺ョ嚎灏辨槸瀹冦€傦級
   */
  /**
   * 鈽呪槄鈽?2026-10-17锛?*鐓ф惉鏃犵晫 `MorphGuard`锛氬舰鍙樻湡闂翠笉璁告敼閰嶈壊鐨?瀹夐潤绐楀彛"**锛?
   *
   * ## 鏃犵晫閭ｄ袱鏉★紙`design/src/main/ets/logic/MorphGuard.ets`锛宍wujie.pa:92721-92815`锛?
   * ```ts
   *   // 妯″潡绾х姸鎬侊紙鍒濆€奸兘鏄?0锛夛細
   *   MorphGuard.morphQuietUntil = 0;
   *   MorphGuard.colorSettleUntil = 0;
   *
   *   function animateMorph(ui, 鈥? quietMs, onBlocked): boolean {
   *     const now = Date.now();
   *     MorphGuard.morphQuietUntil = now + quietMs;            // 鈽?璧疯ˉ闂存椂鎶?瀹夐潤绐楀彛"鎺ㄥ埌鏈潵
   *     if (!(now >= MorphGuard.colorSettleUntil)) {           // 閰嶈壊杩樻病瀹夊畾
   *       onBlocked(); return false;                           // 鈽?杩欐褰㈠彉**涓嶈捣**
   *     }
   *     ui.animateTo({ curve }, 鈥?; return true;
   *   }
   *   colorApplyAllowed(now, until) = now >= until;
   *   colorApplyWaitMs(now, until) = until - now;
   * ```
   * 鑰?*閰嶈壊搴旂敤渚?*锛坄MainPage`锛宍wujie.pa:145945-145989`锛夛細
   * ```ts
   *   const wait = colorApplyWaitMs(Date.now(), MorphGuard.morphQuietUntil);
   *   if (wait > 0) {                                   // 鈽?杩樺湪瀹夐潤绐楀彛閲?
   *     if (!this.colorModeRetryQueued) {
   *       this.colorModeRetryQueued = true;
   *       setTimeout(位, wait + 32);                     // 鈽?0x20 = 32ms 浣欓噺锛岀◢鍚庨噸璇曚竴娆?
   *     }
   *     return;                                         // 鈽?鏈涓嶄笂鑹?
   *   }
   *   鈥︽甯镐笂鑹测€?
   *   // 閲嶈瘯 位锛坵ujie.pa:157930-157939锛夛細colorModeRetryQueued = false; syncReportChrome();
   * ```
   * 鈬?璇箟锛?*褰㈠彉鍔ㄧ敾璺戠潃鐨勬椂鍊欙紝閰嶈壊涓€寰嬪線鍚庢尓**锛堟敼鑹蹭細鎵撴柇/姹℃煋姝ｅ湪璺戠殑琛ラ棿锛?
   *   瑙傛劅灏辨槸"鍔ㄧ敾涓€旇儗鏅壊绐佺劧璺充竴涓?锛夛紝绐楀彛涓€杩囪嚜鍔ㄨˉ涓€娆°€?
   *
   * ## 鏈粨鐨勬槧灏?
   * 路 鍐欎晶锛歿@link markMorphQuiet}锛屽湪鍚勫**璧峰舰鍙樿ˉ闂?*鐨勯偅涓€鍒昏皟锛?
   *   `quietMs` **灏辩敤閭ｆ潯琛ラ棿鑷繁鐨勬椂闀?*锛堟棤鐣岄偅渚т篃鏄寜璋冪敤鐐逛紶鐨勶紝
   *   渚嬪 `closeSearchMorph` 浼?`SP_SEARCH_SETTLE_MS`锛夆噿 **娌℃湁浠讳綍鏂伴€犲父閲?*锛?
   * 路 璇讳晶锛歿@link colorApplyAllowed} / {@link colorApplyWaitMs}锛?
   *   鐢?`PlaybackPage` 鐨勪袱澶?涓婅壊鐐?锛堟祦鍏?shader 鍙傛暟 / 缃戞牸鑳屾櫙婧愶級鏌ヨ銆?
   *
   * 鈿狅笍 涓?`colorSettleUntil`锛?閰嶈壊杩樻病瀹夊畾灏卞埆璧峰舰鍙?閭ｅ崐鏉★級**鏈疆娌℃帴** 鈥斺€?
   *   鏈粨娌℃湁"閰嶈壊瀹夊畾鏃跺埢"杩欎釜姒傚康锛堝彇鑹叉槸寮傛鐨勶紝娌℃湁 settled 鍥炶皟锛夛紝
   *   瑕佹帴寰楀厛瀹氫箟"浠€涔堢畻瀹夊畾"銆傝鍦?`RzdMusic璁板繂.md` 搂140 鐨勫緟鍔為噷銆?
   */
  private morphQuietUntilMs: number = 0;

  /**
   * 鎶?閰嶈壊瀹夐潤绐楀彛"鎺ㄥ埌 `durationMs` 涔嬪悗 鈥斺€?鐓ф惉 `MorphGuard.animateMorph` 鐨勭涓€鍙ャ€?
   * @param durationMs **姝ｅ湪璧风殑杩欐潯褰㈠彉琛ラ棿鐨勬椂闀?*锛堜笉瑕佸彟閫犲父鏁帮級
   */
  public markMorphQuiet(durationMs: number): void {
    if (durationMs <= 0) {
      return;
    }
    this.morphQuietUntilMs = Date.now() + durationMs;
  }

  /** @returns 鐜板湪鑳戒笉鑳戒笂鑹诧紙= 瀹夐潤绐楀彛宸茶繃锛夆€斺€?鐓ф惉 `MorphGuard.colorApplyAllowed`銆?*/
  public colorApplyAllowed(): boolean {
    return Date.now() >= this.morphQuietUntilMs;
  }

  /** @returns 杩樿绛夊涔呮墠鑳戒笂鑹诧紙ms锛? = 鐜板湪灏辫兘锛夆€斺€?鐓ф惉 `MorphGuard.colorApplyWaitMs`銆?*/
  public colorApplyWaitMs(): number {
    const wait: number = this.morphQuietUntilMs - Date.now();
    return wait > 0 ? wait : 0;
  }

  @Trace public pageBoxTopVp: number = 0;

  /**
   * 鈽呪槄鈽?2026-10-17锛?*涓?`lyricPadTop()` 鎹㈡棤鐣屽紡瀛?琛ョ殑鏈€鍚庝竴鍧楁祴閲?*锛夛細
   * **姝岃瘝椤甸偅涓€妫?`Column`锛圫wiper 椤?1 鐨勫唴瀹圭洅锛夌殑绐楀彛椤惰竟**锛坴p锛屽疄娴嬶紱0 = 杩樻病閲忓埌锛夈€?
   *
   * ## 涓轰粈涔堣瀹?
   * 鏃犵晫 `lyricPadTop() = overlayBoxH()/2 + morph.bottomYAtLyric() + 23`
   * 锛坄wujie.pa:172855-172890`锛岄€愭潯宸茶В锛夈€傛妸褰掓。绗旇閭ｇ粍瀹炴祴鍊间唬杩涘幓
   * 锛坄700/2 + (鈭?75.28) + 23 = 197.72`锛夊弽瑙ｏ細
   * ```
   *   bottomYAtLyric = 鈭?75.28  鈬? 瀹?*涓嶆槸**绐楀彛鍧愭爣锛堝惁鍒欐诞灞傝窇鍒板睆骞曞锛?
   *   boxH/2 + bottomYAtLyric = 350 鈭?175.28 = 174.72
   *   鈬?鍗?**娴眰搴曡竟鐩稿鐩掗《**" 鈥斺€?涔熷氨鏄偅涓€椤瑰害閲忕殑鏄?*浠ョ洅涓績涓哄師鐐?*鐨?y锛?
   *     鍐嶉潬 `boxH/2` 鎹㈢畻鎴?浠庣洅椤堕噺璧?
   * ```
   * 鈬?閭ｄ釜寮忓瓙鐨?*鏈綋**灏辨槸銆屾诞灞傚簳杈癸紙鐩稿鐩掗《锛?+ 23銆嶏紝涓?`.padding({top})` 鐨勫彛寰勪竴鑷?
   *   锛坄padding` 鏈潵灏辨槸**鐩掑唴鐩稿閲?*锛夈€?
   *
   * ## 鈽呪槄鈽?缁撹锛?026-10-17 鏀跺熬锛?*杩欎竴鏉″凡闂悎锛氫笉闇€瑕佹崲绠楋紝寮忓瓙涓嶆敼**锛?
   *
   * 鏈粨 `lyricCoverYOf() + lyricCoverSizeOf() + 23` 宸茬粡灏辨槸"娴眰搴曡竟锛堜粠**鐩掗《**閲忚捣锛?+ 23"锛?
   * 鍥犱负**閭ｄ釜鐩掔殑椤惰竟鍦ㄧ粨鏋勪笂鎭掔瓑浜庣獥鍙ｉ《杈?*銆傝瘉鎹摼锛堝叏閮ㄥ彲鍦ㄦ簮鐮侀噷澶嶆牳锛夛細
   * ```
   *   鈶?`overlayBoxH()` = `swiperBoxH`锛坄wujie.pa:172866`锛夆噿 閭ｄ釜"鐩?灏辨槸 **Swiper 鐨勭洅**锛?
   *   鈶?Swiper 鎸傚湪鎵嬫満鏀殑 `Column` 閲岋紝璇?`Column` 鍙湁
   *      `.width(FULL_WIDTH) .height(FULL_HEIGHT)`銆?*娌℃湁浠讳綍 padding/margin**
   *      锛坄PlaybackPage.ets:4185` 璧枫€乣4624-4626` 鏀跺熬锛夆噿 Swiper 鐨勫唴瀹圭洅椤惰竟 = 璇?`Column` 鐨勯《杈癸紱
   *   鈶?璇?`Column` 涓?`LyricFloatLayer()`锛坄PlaybackPage.ets:5841`锛?*鏄悓涓€涓?`Stack` 鐨勫瀛?*
   *      锛堝悓涓€涓?`Stack({alignContent: TopStart})`锛屽叾鑷韩涔熷彧鏈?`.width/.height`锛宍5844-5845`锛夛紱
   *   鈶?鑰?`LyricFloatLayer` 鎶?`lyricMorph()` 浜ゅ嚭鐨?*绐楀彛鍧愭爣鐩存帴鍐欒繘 `.position()`**
   *      涓旇惤鐐规纭紙鐢ㄦ埛宸茬‘璁?鈶犮€屽皝闈㈠嚑浣曠幇鍦ㄦ甯镐簡銆嶏級鈬?**閭ｄ釜 `Stack` 鐨勫唴瀹圭洅宸︿笂瑙掑氨鏄獥鍙ｅ師鐐?*锛?
   *   鈶?浜庢槸 鈶♀憿鈶?涓茶捣鏉ワ細**Swiper 鐩掗《 = 绐楀彛椤?= 0** 鈬?`lyricBoxTopVp` 鎭掍负 0
   *      鈬?鏈粨鐨?绐楀彛鍧愭爣"涓庢棤鐣岀殑"鐩稿鐩掗《"鏄?*鍚屼竴涓暟**銆?
   * ```
   * 锛堟暟鍊间笂涔熻嚜娲斤細鏃犵晫閭ｄ唤 `boxH/2 + bottomYAtLyric()` 鐨勮涔夋槸"鎶?*浠ョ洅涓績涓哄師鐐?*鐨?
   *   morph 灞€閮?y 鎹㈢畻鎴愪粠鐩掗《閲忚捣"锛岃€?`lyricCoverYOf()` 鏈潵灏辨槸绐楀彛 y 鈥斺€?瑙佷笂闈?鈶ゃ€傦級
   *
   * 鈿狅笍鈿狅笍 **缁濆涓嶈**鎶婅繖涓瓧娈垫嬁鍘诲弬涓?`lyricPadTop()` 鐨勮绠楋紙鍝€曞啓鎴?
   *   `(lyricOverlayHeight() 鈭?lyricBoxTopVp) + 23` 鐪嬭捣鏉ユ洿"涓ヨ皑"锛夛細
   *   鏈瓧娈垫槸 `onAreaChange` 鐨?`globalPosition.y`锛岃€屾瓕璇嶉〉閭ｄ竴妫?`Column` **鍦ㄥ舰鍙樺鍣ㄩ噷闈?*
   *   锛堝鍣ㄦ湁 `.scale/.translate/.clip`锛夆噿 **褰㈠彉杩囩▼涓繖涓鏁版槸琚彉鎹㈣繃鐨?*锛堜細鍛ㄦ湡鎬у湴鏄庢樉闈?0锛?
   *   鈬?鐢ㄥ畠浼氳 `lyricPadTop()` 鍦ㄥ姩鐢讳腑鎶栧姩銆?*瀹冩槸"缁撴瀯涓嶅彉閲?鐨勫摠鍏碉紝涓嶆槸杈撳叆銆?*
   *
   * 鈬?淇濈暀瀹冪殑鍞竴鐢ㄩ€旓細**鍝ㄥ叺**銆傝嫢灏嗘潵鏈変汉鍦?`Column`/`Stack` 涓婂姞浜嗕竴灞?padding锛?
   *   杩欓噷浼氳鍒版槑鏄鹃潪 0锛堟棩蹇楀叧閿瓧 `RzdLyricBoxTop`銆佸窘鏍囩鍏 `lBox=`锛夆噿 閭ｆ椂鎵嶉渶瑕佹崲绠椼€?
   *   甯告€佸簲褰撴槸 `0.0`銆?
   */
  @Trace public lyricBoxTopVp: number = 0;

  /**
   * 姝岃瘝椤靛唴瀹圭洅椤惰竟涓婃姤锛堢敱姝岃瘝椤甸偅妫?`Column` 鐨?`onAreaChange` 鍠傦紝`globalPosition.y`锛夈€?
   * @param topVp 鐩掗《锛坴p锛岀獥鍙ｅ潗鏍囷級
   */
  public reportLyricBoxTop(topVp: number): void {
    const v: number = topVp > 0 ? topVp : 0;
    if (Math.abs(v - this.lyricBoxTopVp) > 0.5) {
      this.lyricBoxTopVp = v;
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdLyricBoxTop top=${v.toFixed(1)} 鈬?lyricPadTop=${this.lyricPadTop().toFixed(1)} ` +
        `(overlayBottom=${(this.lyricCoverYOf() + this.lyricCoverSizeOf()).toFixed(1)})`);
    }
  }

  /**
   * 鎾斁椤甸〉鐩掗《杈逛笂鎶ワ紙鐢辫矾鐢卞３鐨?`onAreaChange` 鍠傦紝`area.position.y`锛夈€?
   * @param boxTopVp 椤电洅椤讹紙vp锛岀獥鍙ｅ潗鏍囷級
   */
  public reportPageBoxTop(boxTopVp: number): void {
    const v: number = boxTopVp > 0 ? boxTopVp : 0;
    if (Math.abs(v - this.pageBoxTopVp) > 0.5) {
      this.pageBoxTopVp = v;
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdPageBoxTop boxTop=${v.toFixed(1)} 鈬?topInset=${this.topInsetVp().toFixed(1)} ` +
        `(target=${Math.max(this.statusBarTopVp, PlayerExpandState.PLAYER_TOP_FALLBACK_VP).toFixed(1)})`);
    }
  }

  public topInsetVp(): number {
    // 鐩爣锛?*鍐呭椤惰竟**钀藉湪绐楀彛鐨?`max(鐘舵€佹爮, 56)` 閭ｆ潯绾夸笂锛? 鏃犵晫 `padTop()` 鐨勫彛寰勶級銆?
    const target: number = this.statusBarTopVp > 0
      ? Math.max(this.statusBarTopVp, PlayerExpandState.PLAYER_TOP_FALLBACK_VP)
      : this.windowHeightVp * PlayerExpandState.LYRIC_COVER_TOP_RATIO_STATUS;
    // 鈽?鑷€傚簲锛氳浣嶆槸"**鐩稿鐩掗《**"鐨?鈬?鍑忓幓瀹炴祴鐩掗《锛堥噺涓嶅埌鏃舵寜 0锛屼笌鏀瑰墠瀹屽叏涓€鑷达級銆?
    const boxTop: number = this.pageBoxTopVp > 0 ? this.pageBoxTopVp : 0;
    const off: number = target - boxTop;
    return off > 0 ? off : 0;
  }

  /**
   * 灞曞紑椤?鈬?姝岃瘝椤典袱濂楃鐐逛箣闂存彃鍊笺€?
   * @param t 0 = 灞曞紑椤碉紙鐢ㄥ疄娴嬬殑 `big*`锛夛紝1 = 姝岃瘝椤碉紙鐢ㄧ畻鍑烘潵鐨勪綅缃級
   * @returns 灏侀潰鐨勪竴甯х煩褰紙vp锛岀獥鍙ｅ潗鏍囷級
   */
  public lyricMorph(t: number): LyricMorphRect {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    const fromRect: LyricMorphRect = this.bigEndpointRect();
    const fromSize: number = fromRect.size;
    const toSize: number = this.lyricCoverSizeOf();
    const size: number = this.lerp(fromSize, toSize, p);
    const height: number = this.lerp(fromRect.height, toSize, p);
    return {
      x: this.lerp(fromRect.x, this.lyricCoverXOf(), p),
      y: this.lerp(fromRect.y, this.lyricCoverYOf(), p),
      size: size,
      // 姝岃瘝椤甸偅涓€绔槸绠楀嚭鏉ョ殑姝ｆ柟褰紱灞曞紑椤甸偅涓€绔部鐢ㄥ疄娴嬬殑钀界偣鐭╁舰锛堝彲鑳戒笉鏄鏂瑰舰锛?
      height: height,
      // 鈽呪槄鈽?2026-10-16锛堢収鎶勬棤鐣?`CoverMorph.visualRadiusAt`锛夛細**涓ょ鐐?lerp**
      radius: this.lerp(PlayerExpandState.COVER_RADIUS_PLAYER_VP,
        PlayerExpandState.COVER_RADIUS_LYRIC_VISUAL_VP, p)
    };
  }

  /**
   * @returns 銆屽睍寮€椤甸偅涓€绔€嶇殑灏侀潰鐭╁舰锛坴p锛岀獥鍙ｅ潗鏍囷級銆?
   *
   * 鈿狅笍 **蹇呴』涓庛€岀画椋炲皝闈?p = 1 鐨勮惤鐐广€嶉€愬儚绱犵浉鍚?*锛坄morphCoverRectAt(1)` 鐢ㄧ殑灏辨槸鍚屼竴娈电畻寮忥級锛?
   *    姝岃瘝椤垫诞灞傚湪鍥炴潵鐨勯偅涓€瓒熺粓鐐逛細**鍗歌浇鑷繁骞舵妸鐪熷皝闈㈡斁鍑烘潵**锛屼袱绔笉涓€鑷村氨浼氬湪浜ゆ閭ｄ竴甯?
   *    璺充竴涓嬶紙5% 鐨勮瑙夌缉鏀惧樊灏卞鐪嬭浜?鈥斺€?鐪熷皝闈㈡挱鏀炬€佽寮圭哀鏀惧ぇ 1.05 / 鏆傚仠鎬?0.95锛夈€?
   *    鎵€浠ヨ繖閲?*涓嶇洿鎺ョ敤** `bigX/bigY/bigSize`锛堥偅鏄竷灞€鐭╁舰銆佷笉鍚瑙夌缉鏀撅級锛?
   *    鑰屾槸澶嶇敤鍚屼竴娈电鐐瑰嚑浣曪紱鍑犱綍杩樻病灏辩华鏃舵墠閫€鍥?`reportBig` 鐨勪笂鎶ュ€笺€?
   */
  private bigEndpointRect(): LyricMorphRect {
    if (this.endCoverSize > 0 && this.snapStartW > 0) {
      return this.morphCoverRectAt(1);
    }
    const fallbackSize: number = this.playerCoverWidth();
    if (fallbackSize > 0) {
      return {
        x: this.bigX,
        y: this.bigY,
        size: fallbackSize,
        height: fallbackSize,
        radius: this.bigRadius > 0
          ? this.bigRadius
          : fallbackSize * PlayerExpandState.COVER_RADIUS_RATIO
      };
    }
    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣?`CoverMorph`锛夛細瀹炴祴缂哄け鏃剁粰**绾嚑浣曞厹搴?*锛?
    //   缁濅笉璁╃鐐瑰彉鎴?0脳0銆?
    //   鏃犵晫鐨勫皝闈㈢鐐规湰鏉ュ氨鏄?*绠楀嚭鏉ョ殑**锛坄CoverMorph` 鐢?`fitPlayerOverlay` 鐨?
    //   `edge / metaY` 鏋勯€狅紝鍏ㄧ▼涓嶆煡鑺傜偣锛夛紱娲鹃煶杩欒竟闈?`MusicPlayInfoBlock` 鐨?
    //   `onAreaChange 鈫?reportBig` 涓婃姤锛?*涓婃姤娌℃潵**锛堟崲姝岀灛闂淬€佺粍浠惰鏇挎崲銆?
    //   閲忔祴鏃跺簭閿欏紑锛夋椂 `bigSize = 0` 鈬?`lyricMorph()` 璧风偣鎴愰浂鐭╁舰
    //   鈬?**灏侀潰缂╂垚涓€鐐广€佸睍寮€鍔ㄧ敾娌℃湁绔偣**锛?026-10-15 閭ｆ"灏侀潰娑堝け + 鍔ㄧ敾鍏ㄥ簾"
    //   灏辨槸杩欎釜褰㈢姸鐨勬瀬绔増锛夈€?
    //   鈿狅笍 鍙湪瀹炴祴缂哄け鏃剁敓鏁堬紙`bigSize > 0` / `bigX/bigY` 鏈夋晥鏃朵竴瀛椾笉鏀癸級
    //      鈬?姝ｅ父璺緞涓庨潤姝㈡€?*閫愬儚绱犱笉鍙?*銆?
    return this.fallbackBigRect();
  }

  /**
   * @returns 鎾斁椤靛皝闈?*甯冨眬鍩哄噯鐭╁舰**锛坴p锛岀獥鍙ｅ潗鏍囷級鈥斺€?**绾嚑浣曘€佷笉鏌ヤ换浣曡妭鐐?*銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岀殑 `CoverMorph`锛夛細杩欐槸"鍙樻崲寮忚鐩栧眰"鐨?*鍩哄噯灏哄**銆?
   *
   * 涓轰粈涔堝繀椤绘湁瀹冿細鏃犵晫鐨?`floatingCover` 鏄竴涓?*婊″睆灞呬腑甯冨眬**鐨勫鍣紝
   * 灏侀潰鍦ㄩ噷闈?*鎸夊竷灞€灏哄鎺?*锛屽彧鏈?`scale / translate` 浼氭妸瀹冩尓璧?鈬?
   * `t = 0`锛堝皝闈㈤〉锛夋椂鍙樻崲鏄亽绛夈€佷綅缃敱**甯冨眬**鍐冲畾銆傛淳闊冲師鏉ョ殑瑕嗙洊灞傛槸
   * `.width(lyricMorph(t).size).position(lyricMorph(t).x鈥?` 鈥斺€?**浣嶇疆鍜屽昂瀵搁兘鐢卞舰鍙樼粰**
   * 鈬?涓€鏃﹁瀹冨綋鍞竴娓叉煋鑰咃紝灏卞彉鎴?瀹藉害渚濊禆涓婃姤銆佷笂鎶ヤ緷璧栧搴?锛?
   * 鍒濆涓婃姤 0 鏃?*涓嶅姩鐐归€€鍖栧湪 0**锛?026-10-15 閭ｆ"灏侀潰娑堝け + 鍔ㄧ敾鍏ㄥ簾"鐨勬満鍒讹級銆?
   *
   * 灏哄鍙ｅ緞鐓ф妱鏃犵晫 `fitPlayerOverlay`锛?
   * ```
   * edge = clamp(min(winW 鈭?2路sidePad, winH 鈭?2路(gap + metaH + 8)), COVER_EDGE_MIN 200, CAP 480)
   * ```
   * 锛坄winW 鈭?2路sidePad` 灏辨槸鏃犵晫 `coverEdgeMaxOf(swiperBoxW, pageSide, winWVp)` 鐨勪骇鐗?鈥斺€?
   *   360 瀹芥満鍨嬩笂 鈮?328锛屼笌 `鎾斁椤佃儗鏅?*.md` 璁板綍鐨?`edge` 甯告€?鈮?328"涓€鑷淬€傦級
   * 姘村钩/绔栫洿閮藉眳涓紙鏃犵晫鐨?`floatingCover` 鏄?`Column(center, center)`锛夈€?
   */
  /** `fitPlayerOverlay` 鐨?`META_GAP_BELOW_COVER`锛堝瓧鑺傜爜榛樿鍊?50锛夈€?*/
  private static readonly COVER_FIT_META_GAP_VP: number = 50;
  /** `fitPlayerOverlay` 閲岄偅涓?纭紪鐮?+8"锛堜笂鐣屽す绱х敤锛夈€?*/
  private static readonly COVER_FIT_BOUND_INSET_VP: number = 8;
  /**
   * `CoverMorph.metaTopFixLyric` 鐨勯粯璁ゅ€硷紙vp锛夆€斺€?**鍏冧俊鎭潡姝岃瘝椤电閿氱偣鐨勪慨姝ｉ噺**銆?
   *
   * 鈽呪槄鈽?2026-10-17锛?*鍥炲師濮嬪瓧鑺傜爜閲嶈锛岃姝ｄ笂涓€鐗?*锛夛細
   *
   * ```
   *   85527  ldai 0x1c        鈫?0x1c = **28**
   *   85528  sta v0
   *   85531  ldobjbyname 0x55, "metaTopFixLyric"      ; acc = a3.metaTopFixLyric
   *   85534  ldnull / stricteq 鈫?jnez L19             ; 浼?null 鈬?鐢ㄩ粯璁?
   *   85537  ldundefined / stricteq 鈫?jnez L19        ; 浼?undefined 鈬?鐢ㄩ粯璁?
   *   85540  mov v0, v1                               ; 鍚﹀垯鐢ㄨ皟鐢ㄦ柟缁欑殑
   *   85542  lda v0 / 85543 stobjbyname "metaTopFixLyric"
   * ```
   *   鈬?**榛樿鍊?= `+28`锛岃€屼笖 `85527` 涔嬪悗銆愭病鏈?`neg`銆戙€?*
   *
   * 鈿狅笍 **鏈粨涓婁竴鐗堝啓鐨勬槸 `鈭?6`**锛屽嚭澶勬槸褰掓。绗旇
   *   `_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md:858`銆岄粯璁?-26锛坄ldai 0x1a / neg`锛夈€?
   *   涓庡悓鏂囦欢 `:1356`銆?*-26** 鈫?`85527 ldai 0x1c`銆嶁€斺€?
   *   杩欎袱琛?*浜掔浉鐭涚浘**锛堜竴澶勮 `0x1a`+`neg`锛屼竴澶勮 `0x1c`锛夛紝**閮戒笉鑳界敤**銆?
   *
   * 鈽?璐熷彿鍦ㄦ湰鏂囦欢鎵€渚濊禆鐨勯偅浠藉弽姹囩紪閲?*涓€瀹氬啓鎴?`ldai <缁濆鍊? / neg`**锛堝彲澶嶇幇鐨勪袱澶勯搧璇侊級锛?
   * ```
   *   txLyric 榛樿 鈭?51锛?5462 ldai 0x97 + 85463 neg        锛?x97 = 151锛?
   *   tyPlayer 榛樿 鈭?0 锛氾紙鍚屾棌锛孋overMorph 鏋勯€犲嚱鏁伴噷 `v0 = (-(40))`锛?
   * ```
   *   鈬?`85527 ldai 0x1c` 鏃?`neg` 鈬?**+28**锛屼笉鏄?鈭?8 涔熶笉鏄?鈭?6銆?
   *
   * 鈽?**璇箟锛堣繖涓€鏉℃瘮鏁板€兼洿瀹规槗鎼為敊锛?*锛歚metaOffsetYAt(t)` 杩斿洖鐨勬槸鍏冧俊鎭潡鐨?*涓績 Y**锛?
   *   涓嶆槸椤惰竟 鈥斺€?瑙?`CoverMorph.metaOffsetYAt` 鐨勪袱涓鐐癸細
   * ```
   *   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
   *   路 metaYPlayer 鈥斺€?`fitPlayerOverlay` 缁欑殑 `coverBottom + gap + metaH/2` **锛堜腑蹇冿級**
   *   路 topYAtLyric() + 28 鈥斺€?`coverTop + 28`锛涘皬灏侀潰鍙杈?鈮?48.72 鈬?鍏朵腑蹇?= coverTop + 24.36
   *     鈬?**`coverTop + 28` 鈮?灏忓皝闈㈢殑绔栫洿涓績** 鉁?涓ょ鐐?*鍚屼负"涓績"**锛岃嚜娲姐€?
   * ```
   *   鈬?鏈粨鍦ㄧ敤鍊硷紙椤惰竟锛夎涓庡畠瀵规瘮锛屽繀椤诲厛 `鈭?rowH/2` 鎹㈡垚椤惰竟锛堣 `metaTopGeomY`锛夈€?
   */
  public static readonly META_TOP_FIX_LYRIC_VP: number = 28;
  /**
   * `CoverMorph.tyPlayer` 鐨勯粯璁ゅ€硷紙= 鎾斁椤电灏侀潰涓績鐨勫熀鍑嗗亸绉伙級銆?
   *
   * 鈿狅笍 瀹冪浉瀵?*璋?*鎴?*濮嬬粓娌¤鍑?*锛氭寜 `topYAtPlayer() = tyPlayer 鈭?edge/2` 浼氱畻鍑?
   *   `鈭?0 鈭?164 = 鈭?04`锛堝湪灞忓箷澶栵級锛屼笌鏃犵晫鎴浘锛堝皝闈㈠湪灞忓箷涓婇儴锛夌煕鐩俱€?
   * 鈬?**鏈疄鐜颁笉鐢ㄥ畠**锛屾敼鐢?浠庡唴瀹归《杈瑰線涓嬫帹"鐨勭瓑浠峰紡锛堣 `playerCoverGeomRect()` 鐨勬敞閲婏級銆?
   *   鏈父閲忎繚鐣欏彧涓鸿褰曢€嗗悜鍊笺€佸苟缁欎笅涓€杞暀绾跨储銆?
   *
   * 鈽呪槄 2026-10-16锛?*璁㈡绗﹀彿锛氬疄涓?`+40`锛屼笉鏄?`鈭?0`**锛夛細
   *   褰掓。绗旇 `_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md:581` 鍘熸枃鍐欑殑鏄?
   *   @@COVER_TY_PLAYER,                    // = 40   鈫?鈽?绗簲涓弬鏁帮紝涓嶆槸 metaGap锛丂@
   *   鑰?`topYAtPlayer() = tyPlayer 鈭?edge/2`锛坄wujie.pa:85656-85667`锛夆噿 `40 鈭?164 = 鈭?24`
   *   浠嶇劧鍦ㄥ睆澶栵紝璇存槑 **`tyPlayer` 鐨勫熀鍑嗕笉鏄獥鍙ｉ《杈?*锛堣繖鏉℃帹鏂笌鏈嚱鏁板ご娉ㄩ噴涓€鑷达級銆?
   *   鈬?鍊兼敼鎴?**+40** 浠ュ厤涓嬩竴涓汉鎸?鈭?0 澶嶇畻锛?*鏈疄鐜颁粛鐒朵笉鐢ㄥ畠**锛堢敤绛変环寮忥級銆?
   */
  private static readonly COVER_TY_PLAYER_VP: number = 40;

  /**
   * @returns 鍏冧俊鎭潡**椤惰竟**鐨?*鏃犵晫绠楀紡鍊?*锛坴p锛岀獥鍙ｅ潗鏍囷級銆?
   *
   * 鈽呪槄鈽?2026-10-16锛坓oal 绗?1 鏉°€屽厓淇℃伅琛岀収鎼?`floatingMeta`銆嶇殑**鍙牳瀵瑰寲** 鈥斺€?绗簩鐗堬級
   *
   * ## 鈿狅笍 绗竴鐗堢粫杩滀簡锛堣嚜璁帮級
   * 鎴戠涓€鐗堝啓鎴?`lyricMorph(1).y + metaTopFixLyric` 鈥斺€?閭ｆ槸"浠?*灏侀潰绔偣**鍙嶆帹"锛?
   * 缁曡繃浜?`fitPlayerOverlay` 鑷繁绠楀嚭鏉ョ殑 `metaY`銆?*姝ｇ‘鍋氭硶鏄粠绠楀紡鐩存帴鎺?*锛堝涓嬶級銆?
   *
   * ## 鏃犵晫鐨勭畻寮忛摼锛堥€愬瓧锛?
   * ```ts
   *   // 鈶?CoverMorph 鐨勮捣鐐癸紙wujie.pa:177459-177464锛?
   *   metaYPlayer = fit.metaY          // 鐢?refitOverlay 鍐欏叆
   *   // 鈶?灏侀潰涓績锛坧layerCoverGeomRect 鐨?鈶?姝ュ凡缁忕畻鍑烘潵锛?
   *   centerY = contentTop + metaY     鍏朵腑 metaY = curMetaY(0) + edge/2 + gap + metaH/2
   *   // 鈶?姝岃瘝椤甸偅涓€绔殑鍏冧俊鎭潡椤惰竟锛坵ujie.pa:85582-85599锛?
   *   metaOffsetYAt(1) = topYAtLyric + metaTopFixLyric
   *   // 鈶?鍏冧俊鎭潡**涓績**闅?t 璧扮殑閭ｆ潯绾?
   *   //    t=0 鏃跺叾涓績 = centerY 鈭?edge/2 鈭?META_GAP_BELOW_COVER
   *   metaCenterY(t) = lerp(centerY(t) 鈭?edge(t)/2 鈭?gap, topYAtLyric(t) + metaTopFixLyric(), t)
   * ```
   *
   * ## 鈽?鍏抽敭鎭掔瓑寮忥紙鏈疆闈欐€佹牳鍑烘潵鐨勶紝涓ょ閮芥垚绔嬶級
   * ```
   *   t = 0锛歮etaTop(0) = centerY 鈭?edge/2 鈭?gap + metaH/2 鈭?metaH/2 = 灏侀潰搴曡竟 + gap(50)
   *   t = 1锛歮etaTop(1) = topYAtLyric + metaTopFixLyric
   *                     = (topInset + 48.72) + (鈭?6) = topInset + 22.72
   *          鎴戜滑鐨勶細     = lyricCoverYOf() = topInset + LYRIC_ROW_TOPBAR_H_VP(56)
   *          涓よ€呭樊 26 鏄?*璁捐宸?*锛屼笉鏄噺娴嬪樊 鈥斺€?瑙佷笅闈?閭?26vp 鍒板簳鏄粈涔?銆?
   * ```
   *
   * ## 閭?26vp 鍒板簳鏄粈涔堬紙鍒啀鐢?K 姣斿崱鐗囩煯"鍘昏В閲婂畠锛?
   * 杩?26 鏄?*涓ょ閿氭硶鍦ㄥ悓涓€涓崱鐗囬珮搴︿笅鐨勫繀鐒跺樊**锛?
   * ```
   *   鎴戜滑鐨勭鐐瑰湪"灏侀潰**椤惰竟**"锛堝苟鎺掑竷灞€锛氭枃瀛椾笌灏侀潰绔栫洿灞呬腑锛岃楂?= 灏侀潰杈归暱锛?
   *   鏃犵晫鐨勭鐐瑰湪"灏侀潰椤惰竟 鈭?26"锛坄metaTopFixLyric`锛?
   *   鈬?鍙灏侀潰杈归暱 = 48.72锛屼袱鑰呭氨**鎭掑樊 26**锛屼笌鍗＄墖鐪熷疄楂樺害鏃犲叧銆?
   * ```
   * 鈿狅笍 鎵€浠?璇ヤ笉璇ュ噺鎺夎繖 26"**涓嶈兘闈犵畻寮忓垽**锛堢畻寮忕粰浜嗕袱鏉″悓鏍疯嚜娲界殑璺級锛?
   *    鍙兘闈?*瑙傛劅**锛氬畠鍐冲畾"姝岃瘝椤甸偅涓€琛屾枃瀛椾笌宸﹁竟灏忓皝闈㈡槸**椤跺榻?*杩樻槸**灞呬腑**"銆?
   *    鈬?杩欐鏄?goal 閲岄偅鍙ャ€屸殸锔?鎷?`LyricFloatLayer` 鏃朵笉瑕佺宸查獙璇佸ソ鐨勯偅閮ㄥ垎銆嶇殑閫傜敤鍦哄悎銆?
   *    鈬?鏈疆鎶婂畠**閲忓嚭鏉?*锛堝窘鏍?`metaD`锛夛紝**涓嶆敼**銆?
   *
   * @param t 褰㈠彉杩涘害锛? = 灏侀潰椤电 / 1 = 姝岃瘝椤电锛?
   * @param rowH 鍏冧俊鎭鑷韩楂樺害锛坄PlaybackPage.LYRIC_META_ROW_H_VP`锛夆€斺€?
   *        鐢ㄦ潵鎶婃棤鐣岀殑**涓績**鎹㈢畻鎴愭湰浠撳璐︾敤鐨?*椤惰竟**锛堣涓嬮潰閭ｆ璁㈡锛?
   * @returns 鍏冧俊鎭潡**椤惰竟**锛坴p锛岀獥鍙ｅ潗鏍囷級鈥斺€?涓庢湰浠撳湪鐢ㄥ€?*鍚屽彛寰?*锛屽彲鐩存帴鐩稿噺
   *
   * 鈽呪槄鈽?2026-10-17锛?*璁㈡锛氭棤鐣岄偅涓ょ鏄?涓績"锛屾湰鍑芥暟鍘熸潵鏄嬁瀹冨綋"椤惰竟"鐢ㄧ殑**锛?
   *
   * `CoverMorph.metaOffsetYAt`锛坄design__src__main__ets__logic__CoverMorph.ets:205-211`锛夛細
   * ```
   *   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
   * ```
   * 鑰?`metaYPlayer` 鍑鸿嚜 `fitPlayerOverlay`锛歚coverBottom + gap + metaH/2` **锛堜腑蹇冿級**锛?
   * 鍙︿竴绔?`topYAtLyric() + 28` 鈮?灏忓皝闈㈢殑绔栫洿涓績锛堣 `META_TOP_FIX_LYRIC_VP` 鐨勬帹瀵硷級
   * 鈬?**涓ょ鐐归兘鏄?鍏冧俊鎭潡鐨勪腑蹇?Y"**锛屾墍浠ワ細
   * ```
   *   fromTop = coverBottom + gap                    锛? 涓績 鈭?rowH/2锛?
   *   toTop   = lyricCoverTop + 28 鈭?rowH/2          锛? 涓績 鈭?rowH/2锛?
   * ```
   * 鏈嚱鏁拌繑鍥?*椤惰竟**锛堝湪鐢ㄧ殑閭ｆ潯 `.position().y` 灏辨槸椤惰竟锛夆噿 鐩存帴鍙瘮銆?
   *
   * 鈿狅笍 涓婁竴鐗堝啓鐨勬槸 `toTop = lyric.y 鈭?26` 鈥斺€?**鏁板€奸敊锛堚垝26 搴斾负 +28锛夈€佸彛寰勪篃閿欙紙鎶婁腑蹇冨綋椤惰竟锛?*锛?
   *   浜庢槸寰芥爣绗叚琛岀殑 `metaD` 涓€鐩村湪鎶ヤ竴涓?*骞朵笉瀛樺湪**鐨勫亸宸€?
   *   璁㈡鍚庯細`metaD = metaTop 鈭?metaExp` 鍦?**t=0 涓?t=1 涓ょ閮藉簲 鈮?0**
   *   锛堜袱绔紡瀛愮幇鍦ㄩ€愬瓧鍚屾簮锛夛紱**涓**鑻ヤ笉涓?0锛岄偅鏄?浣嶇疆 lerp 鐨勮繘搴︽簮涓嶅悓"
   *   锛堟垜浠敤 `lyricMorphT`锛屾棤鐣岀敤 `swiperProgress`锛夛紝閭ｆ墠鏄湡姝ｈ鐪嬬殑涓滆タ銆?
   */
  public metaTopGeomY(t: number, rowH: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    // 鈽?2026-10-17锛歚from` 閭ｄ竴绔敼鐢?`bigEndpointRect()`锛? 涓?*缁灏侀潰钀界偣**鍚屼竴涓煩褰紝
    //   鍜?`lyricMorph()` 璧风偣鍚屾簮 鈬?姝屽悕涓庡皝闈㈠湪灏侀潰椤甸偅涓€绔?*閫愬儚绱犲榻?*锛?
    //   涓嶄細鍑虹幇"灏侀潰鎸?A 鐭╁舰钀姐€佹瓕鍚嶆寜 B 鐭╁舰鎽?锛夈€傚畠鍐呴儴宸茬粡甯︾函鍑犱綍鍏滃簳銆?
    const fromRect: LyricMorphRect = this.bigEndpointRect();
    if (fromRect.size <= 0) {
      return 0;
    }
    const gap: number = PlayerExpandState.COVER_FIT_META_GAP_VP;      // 50锛堟棤鐣岄粯璁わ級
    const halfRow: number = rowH > 0 ? rowH / 2 : 0;
    // 鈶?t = 0 閭ｄ竴绔細灏侀潰搴曡竟 + gap锛? `fitPlayerOverlay` 鐨?metaY 鈭?metaH/2锛?
    const fromTop: number = fromRect.y + fromRect.height + gap;
    // 鈶?t = 1 閭ｄ竴绔細灏忓皝闈㈤《杈?+ metaTopFixLyric(+28) 鈭?rowH/2
    const lyric: LyricMorphRect = this.lyricMorph(1);
    const toTop: number = lyric.y + PlayerExpandState.META_TOP_FIX_LYRIC_VP - halfRow;
    return this.lerp(fromTop, toTop, p);
  }

  /** @returns 鍏冧俊鎭潡椤惰竟鐨?*鍦ㄧ敤鍊?*锛? 鎴戜滑鍦?`.position()` 閲岀湡姝ｇ敤鐨勯偅涓級鈥斺€?缁欏窘鏍囧璐︾敤銆?*/
  public metaTopInUseY(): number {
    return this.lyricMetaYOf();
  }

  /**
   * @returns 鍏冧俊鎭潡椤惰竟鐨?*鍦ㄧ敤鍊硷紙甯?t锛?* 鈥斺€?涓?`PlaybackPage` 閲岄偅鏉?`.position()` 琛ㄨ揪寮?
   *          **閫愬瓧鍚屼竴浠?*锛堝惈閭ｉ噷閭ｄ釜"绔栫洿灞呬腑琛ュ伩"椤癸級锛屼緵寰芥爣閫愬抚瀵硅处銆?
   *
   * 鍑哄锛歚PlaybackPage.LyricFloatLayer()` 閲?meta 閭ｄ竴琛岀殑
   * ```ts
   *   y: lyricMetaMorphY(t) + t 脳 (lyricFloatRect().size 鈭?LYRIC_META_ROW_H_VP) / 2
   * ```
   * 鈿狅笍 涓よ€?*蹇呴』鍚屾鏀?*锛堣繖閲屾槸鍞竴鍏佽澶嶅埗閭ｆ潯琛ㄨ揪寮忕殑鍦版柟锛屽鍒剁洰鐨勬槸瀵硅处锛夈€?
   * @param t 褰㈠彉杩涘害
   * @param rowH 鍏冧俊鎭鑷韩楂樺害锛坄PlaybackPage.LYRIC_META_ROW_H_VP`锛?
   */
  public metaTopInUseYAt(t: number, rowH: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return this.lyricMetaMorphY(p) + p * (this.lyricMorph(p).size - rowH) / 2;
  }

  /**
   * @returns 鎾斁椤靛皝闈?*閿氬畾鐭╁舰**锛坴p锛岀獥鍙ｅ潗鏍囷級銆?
   *
   * 鈽呪槄鈽?2026-10-16锛?*鐓х敤鎴锋寚绀恒€岀洿鎺ョ収鎼棤鐣屻€嶏紝鎶婄畻寮忔崲鎴愭棤鐣岀殑绾嚑浣?*锛?
   *
   * ## 鏃犵晫鐨勭畻寮忥紙閫愬瓧锛宍姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md` 搂4.2 / 搂4.1锛?
   *
   * ```ts
   * // 鈶?杈归暱涓婇檺锛歝overEdgeMaxOf(swiperBoxW, pageSide) 鈥斺€?"Swiper 瀹?鈭?2脳椤甸潰鐣欑櫧"
   * const curEdgeMax = clamp(swiperBoxW - 2*pageSide, 200, 480);
   * // 鈶?fitPlayerOverlay(availH, metaH=60, curEdgeMax, _unused, curMetaY, gap=50)
   * const maxForBox = availH - 2*(gap + metaH + 8);
   * let edge = curEdgeMax;  if (!(curEdgeMax < maxForBox)) edge = maxForBox;
   * if (edge < 200) edge = 200;
   * const metaY = curMetaY + edge/2 + gap + metaH/2;
   * const bound = (availH/2 - metaH/2) - 8;
   * metaY = metaY > bound ? bound : metaY;
   * // 鈶?灏侀潰涓績 = 鍐呭椤惰竟 + metaY
   * ```
   * 鍏朵腑 `availH = 绐楀彛楂?鈭?padTop(56) 鈭?padBottom(65)`銆乣curMetaY = 0`
   * 锛? "浠庡唴瀹归《杈瑰線涓嬫帹"锛屼緷鎹細`META_Y_PLAYER_MAX` 閭ｇ被**璐熷€?*甯搁噺璇存槑 `curMetaY` 鐨勫熀鍑嗘槸"鍐呭椤惰竟"锛夈€?
   *
   * ## 鎵嬫満涓婇€愪綅鏍稿锛?60脳780 绐楀彛锛?
   *
   * ```
   *   availH = 780 鈭?56 鈭?65 = 659              锛堚殸锔?杩欎竴姝ユ槸鍏抽敭锛?*涓嶈兘**鎶婃暣绐楅珮褰?availH锛?
   *   swiperBoxW 鈭?2脳16 = 328  鈬?curEdgeMax = 328
   *   maxForBox = 659 鈭?2脳(50+60+8) = 423 鈮?328 鈬?edge = 328
   *   metaY = 0 + 164 + 50 + 30 = 244 鈮?bound(291) 鈬?244
   *   灏侀潰涓績 = 56 + 244 = **300**锛岄《杈?= 300 鈭?164 = **136vp**
   * ```
   * 鈽呪槄 2026-10-16锛?*璁㈡涓€澶勭畻寮?*锛夛細涓婇潰 `metaY` 閭ｈ鍘熸潵鍐?`= 244`锛屼絾
   *   `0 + 164 + 50 + 30 = **234**`锛?64+50+30=244 鏄妸 `edge/2` 涓?`metaH/2` 鐩稿姞鏃剁畻閿欎簡锛夈€?
   *   鈿狅笍 **浠ｇ爜鏈韩涓€鐩存槸瀵圭殑**锛堜唬鐮佸氨鏄?`edge/2 + gap + metaH/2`锛夛紝閿欑殑鍙槸杩欒娉ㄩ噴銆?
   *   鈿狅笍 鐢?234 浠ｅ叆鍚庯細灏侀潰涓績 = `56 + 234 = **290**`銆侀《杈?= `290 鈭?164 = **126vp**`銆?
   *   鎴?*涓嶆嵁姝ゆ敼浠ｇ爜** 鈥斺€?鐢ㄦ埛宸插湪鐪熸満楠屾敹灏侀潰浣嶇疆"鐜板湪姝ｅ父浜?锛岄潤姝㈡€佷綅缃互**瀹炴祴涓哄噯**锛?
   *   鑰?`+10` 杩欎釜宸笌 `bounds`/`estBoxH` 鐨勫彛寰勬湁鍏筹紝**闇€瑕佸疄娴嬫墠鑳藉畾**锛堣
   *   `estBoxHVp()` 閭ｆ"涓轰粈涔堝彧鐢ㄨ瘖鏂?鐨勮鏄庯級銆?
   *   澶嶆牳鍏ュ彛锛氬窘鏍?*绗叚琛?*鐨?`metaTop` / `metaExp` / `metaD`锛堣 {@link metaTopGeomY}锛夈€?
   * 鈬?鐩稿"鍦ㄧ獥鍙ｉ噷灞呬腑"锛堜腑蹇?390銆侀《杈?226锛?*涓婄Щ 90vp** 鈥斺€?杩欏氨鏄敤鎴疯鐨?楂樹竴浜?銆?
   *
   * ## 涓轰粈涔堣繖娆¤兘瀹氫綇锛堜笌 搂72 閭ｆ澶辫触鐨勫尯鍒級
   *
   * 搂72 鎴戞敼鐨勪篃鏄繖涓嚱鏁帮紝浣?*鍚屾椂**鎶?瀹介绠?鎹㈡垚浜?`swiperBoxW` 骞堕厤涓婁簡涓€涓?
   * `COVER_FIT_GAP_VP = 20`锛堟垜鑷繁缂栫殑 gap锛夆噿 涓や釜鏀瑰姩鍙犲湪涓€璧枫€佷笖 gap 鏄敊鐨勩€?
   * 杩欐**鍙収鎶勭畻寮?*锛歚gap = 50`锛堟棤鐣岄粯璁わ級銆乣metaH = 60`锛堟棤鐣屽厹搴曪級銆?
   * `availH = 楂?鈭?涓婁笅璁╀綅`锛堟棤鐣岀殑 `availH` 瀹氫箟锛夆€斺€?涓夊閮芥湁瀛楄妭鐮佸嚭澶勩€?
   *
   * 鈿狅笍 浠嶇劧**娌℃湁**鐢?`tyPlayer`锛堣涓婇潰閭ｄ釜甯搁噺鐨勬敞閲婏級锛沗curMetaY = 0` 鏄瓑浠锋浛浠ｃ€?
   * 鈿狅笍 `x` 浠嶇劧鏄?姘村钩灞呬腑"锛堟棤鐣?`floatingCover` 鏄?`Column(center)`锛夆噿 鏈敼琛屼负銆?
   */
  public playerCoverGeomRect(): LyricMorphRect {
    const w: number = this.windowWidthVp;
    const h: number = this.windowHeightVp;
    if (w <= 0 || h <= 0) {
      return { x: 0, y: 0, size: 0, height: 0, radius: 0 };
    }
    // 鈶?`availH` = 鏃犵晫鐨勫彲鐢ㄩ珮搴︼紙**鎵ｆ帀涓婁笅璁╀綅**锛屼笉鏄暣绐楅珮锛?
    const availH: number = Math.max(1, h - this.topInsetVp() - this.navigationBarBottomVp);
    // 鈶?`coverEdgeMaxOf(swiperBoxW, pageSide)`
    const pageSide: number = PlayerExpandState.LYRIC_COVER_LEFT_VP;
    const swiperBoxW: number = Math.max(1, Math.min(w, availH));
    let curEdgeMax: number = swiperBoxW - 2 * pageSide;
    if (curEdgeMax > PlayerExpandState.COVER_EDGE_CAP_VP) {
      curEdgeMax = PlayerExpandState.COVER_EDGE_CAP_VP;
    }
    if (curEdgeMax < PlayerExpandState.COVER_EDGE_MIN_VP) {
      curEdgeMax = PlayerExpandState.COVER_EDGE_MIN_VP;
    }
    // 鈶?`fitPlayerOverlay`
    const metaH: number = PlayerExpandState.COVER_FIT_META_H_VP;      // 60锛堟棤鐣屽厹搴曪級
    const gap: number = PlayerExpandState.COVER_FIT_META_GAP_VP;      // 50锛堟棤鐣岄粯璁わ級
    const inset: number = PlayerExpandState.COVER_FIT_BOUND_INSET_VP; // 8锛堟棤鐣岀‖缂栫爜锛?
    const maxForBox: number = availH - 2 * (gap + metaH + inset);
    let edge: number = curEdgeMax;
    if (!(curEdgeMax < maxForBox)) {
      edge = maxForBox;
    }
    if (edge < PlayerExpandState.COVER_EDGE_MIN_VP) {
      edge = PlayerExpandState.COVER_EDGE_MIN_VP;
    }
    if (edge > curEdgeMax) {
      edge = curEdgeMax;
    }
    if (edge < 0) {
      edge = 0;
    }
    // 鈶?`metaY`锛坄curMetaY = 0` 鈬?"浠庡唴瀹归《杈瑰線涓嬫帹"锛夊啀琚笂鐣屽す浣?
    const metaYRaw: number = edge / 2 + gap + metaH / 2;
    const bound: number = (availH / 2 - metaH / 2) - inset;
    const metaY: number = metaYRaw > bound ? bound : metaYRaw;
    // 鈶?灏侀潰涓績 = 鍐呭椤惰竟 + metaY
    const centerY: number = this.topInsetVp() + metaY;
    return {
      x: (w - edge) / 2,
      y: centerY - edge / 2,
      size: edge,
      height: edge,
      radius: edge * PlayerExpandState.COVER_RADIUS_RATIO
    };
  }

  /**
   * @returns 鎾斁椤靛皝闈㈢鐐圭殑**绾嚑浣曞厹搴?*锛氱洿鎺ュ鐢?{@link playerCoverGeomRect}
   *          锛堝彛寰勭粺涓€鍦ㄤ竴澶勶紝閬垮厤"涓や釜鍑犱綍鍊?鎵撴灦锛夈€?
   */
  private fallbackBigRect(): LyricMorphRect {
    return this.playerCoverGeomRect();
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 浜屄疯ˉ锛圓2锛夛細姝岃瘝椤甸《閮ㄧ殑銆屽皝闈?+ 姝屽悕銆嶆诞灞?鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // 瀵规爣鏃犵晫 `PlayerPage`锛氬皝闈笌姝屽悕**鎸傚湪 Swiper 涔嬪鐨勬诞灞?*涓婏紝鍒囧埌姝岃瘝椤垫椂
  // 銆屽悓涓€涓厓绱犮€嶇缉灏忓苟绉诲埌椤堕儴锛涙瓕璇嶆鏂囬潬 `lyricPadTop()` 鎸夋诞灞傞珮搴﹁浣嶃€?
  // 杩欓噷鍙彁渚?*鍑犱綍**锛屾€庝箞鐢荤敱 `PlaybackPage.LyricFloatLayer()` 鍐冲畾銆?

  /**
   * 姝岃瘝椤垫诞灞傞噷銆屽皝闈㈠簳杈?鈫?姝屽悕鍧楅《杈广€嶇殑闂磋窛锛坴p锛夈€傗殸锔?鏈」鐩及瀹氬€硷紝闈為€嗗悜鍊笺€?
   *
   * 鈽?2026-10-17锛?*瀹冪幇鍦ㄥ彧鍓╀竴涓敤閫?* 鈥斺€?寰芥爣绗叚琛?`metaOld=` 閭ｆ潯**鏃у紡瀛?*
   *   锛坄lyricMetaFromYOf()` 鈫?`lyricMetaMorphY()` 鈫?`metaTopInUseYAt()`锛夌殑瀵硅处銆?
   *   姝屽悕鍧楃殑**鐪熷疄娓叉煋浣嶇疆**鍦?搂131 宸叉敼鎴?`metaTopGeomY(t, rowH)`锛岄偅閲岀敤鐨勬槸
   *   鏃犵晫鐨?`COVER_FIT_META_GAP_VP(50)`锛?*涓嶆槸杩欎釜 10** 鈥斺€?瑙?搂131.2锛?
   *   杩欎釜 10 鏄妸"琚涪寮冪殑妗ｄ綅 `metaGap`"褰撴垚浜嗙湡鍊硷級銆?
   *   鈿狅笍 鍥犳**涓嶈**鍐嶆嬁瀹冨幓鍙備笌浠讳綍娓叉煋璁＄畻銆?
   */
  private static readonly LYRIC_META_GAP_VP: number = 10;
  /** 姝岃瘝椤垫诞灞傞噷銆屾瓕鍚?+ 姝屾墜銆嶄袱琛屾墍鍗犻珮搴︼紙vp锛夈€傗殸锔?鏈」鐩及瀹氬€硷紝闈為€嗗悜鍊笺€?*/
  private static readonly LYRIC_META_BLOCK_H_VP: number = 44;
  /** 姝岃瘝椤垫诞灞傚簳杈逛笌姝岃瘝姝ｆ枃涔嬮棿鐨勫懠鍚搁棿璺濓紙vp锛夈€傗殸锔?鏈」鐩及瀹氬€硷紝闈為€嗗悜鍊笺€?*/
  /**
   * 姝岃瘝椤垫鏂囪浣嶇殑**鍛煎惛闂磋窛**锛坴p锛夆€斺€?鏃犵晫 `lyricPadTop()` 閲岄偅涓瓧闈㈤噺 **`+23`**銆?
   *
   * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣岋紝`wujie.pa:172888`锛夛細`ldai 0x17` = **23**銆?
   *   ```ts
   *     lyricPadTop() {
   *       if (!this.lyricFloat) return 0;
   *       const boxH = this.overlayBoxH();
   *       if (boxH <= 0) return LYRIC_PAD_TOP_FALLBACK;      // 96
   *       return boxH / 2 + this.morph.bottomYAtLyric() + 23;
   *     }
   *   ```
   * 鈿狅笍 鏈粨鍘熸潵鍐欑殑鏄?**10**锛堣嚜瀹氬€硷級銆?
   * 鈿狅笍 瑙?`lyricBoxTopVp` 鐨勬敞閲婏細**杩欎釜甯搁噺涓?鐩掑唴鐩稿閲?鏄悓涓€浠朵簨鐨勪袱鍗?* 鈥斺€?
   *   鏃犵晫閭ｄ釜 `boxH/2 + bottomYAtLyric()` 鍚堣捣鏉ュ氨鏄?**娴眰搴曡竟鐩稿鐩掗《**"锛堟帹瀵艰閭ｉ噷锛夛紝
   *   鏈粨鐩墠鐩存帴缁?娴眰搴曡竟锛堢獥鍙ｅ潗鏍囷級+ 鏈父閲?锛屼袱鑰?*鍙湪 `lyricBoxTopVp 鈮?0` 鏃剁瓑浠?*銆?
   *   娴嬮噺宸叉帴涓婏紙寰芥爣绗叚琛?`lBox=`锛夆噿 鎷垮埌璇绘暟鍐嶅喅瀹氳涓嶈鎹㈡垚鐩掑唴鐩稿閲忋€?
   */
  private static readonly LYRIC_PAD_GAP_VP: number = 23;
  /**
   * 姝岃瘝椤垫诞灞傚嚑浣曟嬁涓嶅埌鏃剁殑**鍏滃簳椤堕儴鐣欑櫧**锛坴p锛夈€?
   *
   * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`LYRIC_PAD_TOP_FALLBACK`锛夛細**96**锛堟湰浠撳師鏉ユ槸 **150**锛岃嚜瀹氬€硷級銆?
   *
   * 鍑哄锛歚PlayerPage.lyricPadTop()` 鐨勫厹搴曟敮璧扮殑鏄枃浠剁骇 lexenv 妲?**`0x06`**
   * 锛坄wujie.pa:172872-172874`锛歚ldlexvar 0x1, 0x6` + `throw.undefinedifholewithname
   * "LYRIC_PAD_TOP_FALLBACK"`锛夛紝鑰屾Ы浣嶈〃涓庡彇鍊煎湪褰掓。绗旇閲屽凡缁忔牳杩囷細
   * `_recover/logic-src/姝岃瘝椤垫诞灞傚皝闈笌姝屽悕瀹氱.md:1299`
   * 銆宍0x06` | `LYRIC_PAD_TOP_FALLBACK` | **96** | `lyricPadTop()` 鍏滃簳銆嶃€?
   * 鍚屼竴浠界瑪璁扮殑宸紓琛?`:1448` 涔熸棭宸叉爣鍑恒€屾淳闊?150 vs 鏃犵晫 96 鈥斺€?涓嶄竴鑷翠絾褰卞搷灏忋€嶃€?
   *
   * 鈿狅笍 杩欐潯鍏滃簳涓€鏃﹀懡涓紝瑙傛劅灏辨槸"**姝岃瘝椤朵笂澶氫竴鍧楃┖鐧?*"锛堢瑪璁?`:1434` 鐨勫師璇濓級
   *   鈬?150 姣?96 澶?54vp 鐨勭┖鐧斤紝灞炰簬**璇ヤ慨鐨勮嚜瀹氬€?*銆?
   */
  private static readonly LYRIC_PAD_TOP_FALLBACK: number = 96;

  /**
   * @returns 姝岃瘝椤垫诞灞傦紙灏侀潰 + 姝屽悕/姝屾墜锛夋槸鍚﹀惎鐢ㄣ€?
   *
   * 涓庢棤鐣岀殑 `lyricFloat` 鍚屼箟锛?*涓嶅紑娴眰 鈬?`lyricPadTop()` 蹇呴』杩斿洖 0**锛堜笉棰勭暀绌洪棿锛?
   * 鐗堥潰涓庢病鏈夎繖濂椾笢瑗挎椂閫愬儚绱犱竴鑷达級銆?
   *
   * 鈿狅笍 闄や簡"鍑犱綍灏辩华"锛岃繕瑕佹眰**灏侀潰灏哄宸茬粡涓婃姤**锛坄lyricCoverSizeOf() > 0`锛夛細
   *    鎾斁椤靛ぇ灏侀潰杩樻病閲忓埌鏃讹紝姝岃瘝椤靛皝闈㈢畻鍑烘潵鏄?0 脳 0 鈥斺€?閭ｆ椂鑻ヨ繕鎸夋诞灞傝浣嶏紝
   *    灏变細鍑┖澶氬嚭涓€娈甸《閮ㄧ暀鐧姐€傛鏃舵暣濂楁诞灞?*鏁翠綋涓嶅惎鐢?*锛岄€€鍥?鍘熺敓 Swiper 婊戝姩"鐨勮€佹牱瀛愩€?
   */
  public lyricFloat(): boolean {
    return this.lyricGeometryReady() && this.lyricCoverSizeOf() > 0;
  }

  /**
   * @returns 姝岃瘝椤垫瓕鍚嶅潡鐨勯《杈癸紙vp锛岀獥鍙ｅ潗鏍囷級銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛?*涓庡皝闈㈠悓涓€涓《杈?*锛堝苟鎺掞級锛屼笉鍐嶆槸"灏侀潰搴曡竟 + 闂磋窛"銆?
   *   鏃犵晫 `metaRow` 涓?`floatingCover` 鍦ㄦ瓕璇嶉〉鍗犲悓涓€鏉℃按骞冲甫锛氬皝闈㈠湪宸︺€佹枃瀛楀湪鍙筹紝
   *   鏂囧瓧涓庡皝闈?*绔栫洿灞呬腑**瀵归綈锛坄PlaybackPage` 閭ｈ竟鎶婅楂樿鎴愬皝闈㈣竟闀挎潵淇濊瘉杩欎竴鐐癸級銆?
   *   鈿狅笍 鎵€浠ユ瓕鍚嶅潡鐨?y 涓庡皝闈?y 鐩稿悓锛屾í鍚戠敱**琛岀殑宸﹀唴杈硅窛**锛堝皝闈㈠彸缂?+ 12锛夎寮€銆?
   */
  public lyricMetaYOf(): number {
    return this.lyricCoverYOf();
  }

  /** @returns **灞曞紑椤甸偅涓€绔?*姝屽悕鍧楃殑椤惰竟锛坴p锛岀獥鍙ｅ潗鏍囷級= 钀界偣鐭╁舰搴曡竟 + 闂磋窛銆?*/
  public lyricMetaFromYOf(): number {
    const r: LyricMorphRect = this.bigEndpointRect();
    return r.y + r.height + PlayerExpandState.LYRIC_META_GAP_VP;
  }

  /**
   * @returns 姝屽悕鍧楅《杈圭殑涓€甯т綅缃紙vp锛岀獥鍙ｅ潗鏍囷級銆?
   *
   * 涓庡皝闈㈢敤**鍚屼竴涓繘搴?*鎻掑€?鈬?灏侀潰涓庢瓕鍚嶆槸"鍚屼竴涓厓绱犲湪鍔?锛堝鏍囨棤鐣?
   * `floatingCover` + `floatingMeta` 鍚屽睘涓€灞傛诞灞傘€佷竴璧风缉灏忕Щ鍒伴《閮級锛?
   * 鑰屼笉鏄?鍒囨崲鐨勪袱椤靛悇鐢讳竴浠?銆?
   * @param t 0 = 灞曞紑椤典綅缃紝1 = 姝岃瘝椤甸《閮?
   */
  public lyricMetaMorphY(t: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return this.lerp(this.lyricMetaFromYOf(), this.lyricMetaYOf(), p);
  }

  /**
   * @returns 姝岃瘝椤垫诞灞傦紙灏侀潰 + 姝屽悕鍧楋級鐨?*搴曡竟**锛坴p锛屼粠绐楀彛椤惰竟閲忚捣锛夈€?
   *
   * 姝屽悕涓庡皝闈㈠湪姝岃瘝椤垫槸**骞舵帓**鐨?鈬?娴眰鐨勫簳杈瑰氨鏄?*灏侀潰搴曡竟**
   * 锛堜笉鑳界敤 `lyricMetaYOf() + LYRIC_META_BLOCK_H_VP` 鈥斺€?閭ｆ槸"姝屽悕鎺掑湪灏侀潰涓嬫柟"鏃剁殑绠楁硶锛?
   *  骞舵帓涔嬪悗浼氭妸鐣欑櫧绠楀涓€鏁村潡锛夈€?
   *
   * 鈽呪槄鈽?2026-10-17锛?*璁㈡锛氳繖閲屽師鏉ュ鍙犱簡涓€涓?`+ LYRIC_META_GAP_VP(10)`**锛夛細
   *   瀹冨敮涓€鐨勬秷璐硅€呮槸 {@link lyricPadTop}锛岃€?`lyricPadTop` 鑷繁鍙堜細鍔犱竴涓懠鍚搁棿璺?
   *   锛坄LYRIC_PAD_GAP_VP`锛夆噿 **鍚屼竴涓?娴眰搴曡竟涔嬪悗鐨勯棿璺?琚姞浜嗕袱娆?*锛?3 = 10 + 23锛夈€?
   *   鑰屽弽瑙ｅ嚭鏉ョ殑鏃犵晫寮忓瓙鍙湁**涓€娆?*锛堣 `lyricPadTop` 鐨勬敞閲婏級锛?
   * ```
   *   lyricPadTop = boxH/2 + bottomYAtLyric() + 23
   *                 鈹斺攢鈹€鈹€鈹€鈹€鈹€鈹攢鈹€鈹€鈹€鈹€鈹€鈹?
   *              杩欎袱椤瑰悎璧锋潵 = "娴眰搴曡竟锛堢浉瀵圭洅椤讹級"锛?*涓嶅惈浠讳綍棰濆闂磋窛**
   * ```
   *   鈬?鏈嚱鏁板彧杩斿洖**娴眰搴曡竟**锛?鍛煎惛闂磋窛"涓€寰嬬敱 {@link lyricPadTop} 閭ｄ竴灞傚姞銆?
   */
  public lyricOverlayHeight(): number {
    if (!this.lyricFloat()) {
      return 0;
    }
    const size: number = this.lyricCoverSizeOf();
    if (size <= 0) {
      return 0;
    }
    return this.lyricCoverYOf() + size;
  }

  /**
   * @returns 姝岃瘝椤垫鏂囧繀椤昏浣嶇殑**椤堕儴鍐呰竟璺?*锛坴p锛夆€斺€?绛変环鏃犵晫鐨?`lyricPadTop()`
   *          锛坄wujie.pa:172855-172890`锛岄€愭潯宸茶В锛夈€?
   *
   * ```ts
   *   lyricPadTop() {
   *     if (!this.lyricFloat) return 0;
   *     const boxH = this.overlayBoxH();                    // = swiperBoxH > 0 ? swiperBoxH : estBoxH()
   *     if (boxH <= 0) return LYRIC_PAD_TOP_FALLBACK;        // 96
   *     return boxH / 2 + this.morph.bottomYAtLyric() + 23;  // 0x17 = 23
   *   }
   * ```
   * 鈽?鍓嶄袱椤?*鍚堣捣鏉ュ氨鏄?娴眰搴曡竟锛堢浉瀵圭洅椤讹級"**锛堟妸褰掓。瀹炴祴鍊?`700/2 + (鈭?75.28) + 23 = 197.72`
   *   浠ｈ繘鍘诲弽瑙ｅ緱 `boxH/2 + bottomYAtLyric = 174.72`锛岃 `lyricBoxTopVp` 鐨勬敞閲婏級
   *   鈬?鏈粨鍐欐垚"娴眰搴曡竟 + `LYRIC_PAD_GAP_VP`"锛?*宸茬粡鏄悓涓€涓彛寰?*锛?
   *
   * 鉁?**鏇剧粡鎸傚湪杩欓噷鐨勯偅涓?鏈棴鍚堢殑涓€姝?宸查棴鍚堬紙2026-10-17 鏀跺熬锛?*锛?
   *   鍘熸潵鍐欑殑鏄€屾湰浠?`lyricOverlayHeight()` 鏄?*绐楀彛**鍧愭爣锛岃€屾棤鐣岄偅涓€椤规槸**鐩稿鐩掗《**
   *   鈬?涓よ€呭彧鍦?`lyricBoxTopVp 鈮?0` 鏃剁瓑浠凤紝绛夊窘鏍囩鍏 `lBox=` 鐨勮鏁板啀瀹氥€嶃€?
   *   鐜板湪**涓嶉渶瑕侀偅涓鏁颁簡** 鈥斺€?缁撴瀯涓婂彲璇?`lBox 鈮?0`锛?
   *   閭ｄ釜"鐩?灏辨槸 Swiper 鐨勭洅锛岃€?Swiper 鎵€鍦ㄧ殑 `Column` 涓?`LyricFloatLayer()`
   *   鏄?*鍚屼竴涓?`Stack` 鐨勫瀛?*銆佷袱鑰呴兘涓嶅甫 padding锛屼笖璇?`Stack` 鐨勫唴瀹圭洅宸︿笂瑙?
   *   宸茶璇佹槑灏辨槸绐楀彛鍘熺偣锛堢敤鎴峰凡纭灏侀潰钀界偣姝ｇ‘锛夆噿 **鐩掗《 = 绐楀彛椤?*銆?
   *   瀹屾暣璇佹嵁閾撅紙鍚?`PlaybackPage.ets` 琛屽彿锛夎 {@link lyricBoxTopVp} 鐨?JSDoc銆?
   *   鈬?`lyricBoxTopVp` 浠庢鍙綋**缁撴瀯涓嶅彉閲忓摠鍏?*锛堝父鎬?`0.0`锛夛紝**涓嶈**鍙備笌鏈嚱鏁扮殑璁＄畻
   *     锛堝畠鏄?`globalPosition.y`锛屽舰鍙樻湡闂磋瀹瑰櫒鍙樻崲杩囷紝鐢ㄥ畠浼氳 padding 鎶栧姩锛夈€?
   *
   * 鈿狅笍 涓棿鐨?`boxH <= 0` 鏄?*闃插尽鍒嗘敮**锛屾寜鏃犵晫閭ｄ唤缁撴瀯淇濈暀
   *   锛坄lyricFloat()` 宸茶姹傚皝闈㈠昂瀵?> 0锛屾甯告祦绋嬭蛋涓嶅埌锛夈€?
   */
  public lyricPadTop(): number {
    if (!this.lyricFloat()) {
      // ★ 2026-10-17: first entry has lyricFloat()==false (cover width not reported yet)
      //   => return the fallback padding instead of 0 (lyrics were pinned to the very top)
      return PlayerExpandState.LYRIC_PAD_TOP_FALLBACK;
    }
    const overlayBottom: number = this.lyricOverlayHeight();
    if (overlayBottom <= 0) {
      return PlayerExpandState.LYRIC_PAD_TOP_FALLBACK;
    }
    return overlayBottom + PlayerExpandState.LYRIC_PAD_GAP_VP;
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?涓夌偣浜斻€佹暣椤靛舰鍙樻斁澶э紙瀵规爣鏃犵晫 ExpandAnimation 鐨?閫愭笎褰㈠彉鏀惧ぇ濉弧"锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 鏃犵晫鐨勫睍寮€涓嶆槸"浠庡簳閮ㄥ脊涓婃潵涓€鍧?锛岃€屾槸**鎾斁椤典粠杩蜂綘鏉￠偅涓綅缃€愭笎鏀惧ぇ閾烘弧鏁村睆**銆?
  // 鎴戜滑杩欒竟鎸変笅杩版柟寮忕瓑浠峰疄鐜帮紙鍙敤 `scale` 鐨?`centerX/centerY`锛屼笉纰颁换浣曞舰鐘惰鍓?鈥斺€?
  // 杩欐槸鏈枃浠堕噷鍙嶅寮鸿皟鐨勭孩绾匡細鎾斁椤电殑 path 瑁佸壀鍘嗗彶涓婃妸椤甸潰鎼炲潖杩囦袱娆★級锛?
  //
  //   1. **璧风偣灏哄**锛氳糠浣犳潯灏侀潰杈归暱 / 绐楀彛鐭竟 鈥斺€?缂╂斁浠庤繖涔堝皬寮€濮嬶紱
  //   2. **閿氱偣**锛氳糠浣犳潯灏侀潰鐨勪腑蹇冨湪**鏈〉鍧愭爣绯?*閲岀殑鐧惧垎姣斾綅缃?鈥斺€?缂╂斁鍥寸粫瀹冨彂鐢燂紝
  //      瑙嗚涓婂氨鏄?浠庤糠浣犳潯閭ｄ竴灏忓潡闀垮嚭鏉?锛岃€屼笉鏄粠灞忓箷涓績鎴栧簳閮ㄥ脊鍑恒€?
  //
  // 涔嬫墍浠ヨ兘绠楋細`reportMini()`锛堣糠浣犳潯灏侀潰锛夊拰 `reportWindow()`锛堟湰椤靛昂瀵革級閮藉凡缁忔帴涓婁簡銆?

  /** 璧风偣缂╂斁鐨勪笅闄愶細杩蜂綘鏉″皝闈㈠啀灏忎篃涓嶄細灏忎簬绐楀彛鐭竟鐨勮繖涓瘮渚嬶紙闃叉绠楁垚 0 瀹屽叏鐪嬩笉瑙侊級銆?*/
  private static readonly MORPH_MIN_SCALE: number = 0.14;

  /** @returns 褰㈠彉鏀惧ぇ鎵€闇€鐨勫嚑浣曟槸鍚﹂綈浜嗭紙杩蜂綘鏉″皝闈㈠凡涓婃姤 + 鏈〉灏哄宸茬煡锛夈€?*/
  public morphGeometryReady(): boolean {
    return this.miniSize > 0 && this.windowWidthVp > 0 && this.windowHeightVp > 0;
  }

  /**
   * @returns 璧风偣缂╂斁姣斾緥锛堟暣椤典粠杩欎箞澶у紑濮嬫斁澶э紝鏈€鍚庡埌 1锛夈€?
   *
   * 鐢ㄧ獥鍙?*鐭竟**鍋氬垎姣嶏細杩蜂綘鏉″皝闈㈠湪涓や釜鏂瑰悜涓婂崰鐨勬瘮渚嬩笉鍚岋紝鍙栫煭杈硅兘寰楀埌
   * "涓嶄細灏忓埌鐪嬩笉瑙併€佷篃涓嶈嚦浜庡ぇ鍒扮湅涓嶅嚭鍔ㄧ敾"鐨勯偅涓€妗ｃ€?
   *
   * 鈽呪槄 2026-10-15锛?*宸插垽瀹氫负姝讳唬鐮?*锛宍RzdMusic璁板繂.md` 搂59锛夛細闆惰皟鐢ㄨ€呫€?
   *   瀹冨拰绱ч偦鐨?{@link morphCenterXPercent} / {@link morphCenterYPercent} 鏄?*鍚屼竴鏃?*锛?
   *   "鏁撮〉 `scale` + 缁曡糠浣犳潯涓績缂╂斁"閭ｅ**鏃╂湡褰㈠彉**鐨勬畫鐣欍€傛椿鐨勫舰鍙樿蛋
   *   `applyMorphProgress()` 鐨?缂╂斁 + 绔栫洿瑁佸壀绐楀彛"锛坄morphScale/morphTx/morphTy/morphClipHeight`锛?
   *   鈬?杩欎竴鏃?*浠庢潵娌¤鎺ョ嚎**锛坄MORPH_MIN_SCALE` 涔熷彧琚畠璇伙級銆?
   * @deprecated 闆惰皟鐢ㄨ€呫€傛椿鐨勫舰鍙樿捣鐐硅 {@link applyMorphProgress} 涓?`morphInitParams()`銆?
   * 澶嶆牳鍛戒护锛歚grep -rn 'morphStartScale\|morphCenterXPercent\|MORPH_MIN_SCALE' RzdMusic --include=*.ets`
   */
  public morphStartScale(): number {
    if (!this.morphGeometryReady()) {
      return 1;
    }
    const shortSide: number = Math.min(this.windowWidthVp, this.windowHeightVp);
    const raw: number = this.miniSize / shortSide;
    return Math.max(PlayerExpandState.MORPH_MIN_SCALE, Math.min(1, raw));
  }

  /**
   * @returns 缂╂斁閿氱偣 X锛?*鏈〉鍧愭爣绯?*涓嬬殑鐧惧垎姣斿瓧绗︿覆锛堝 `'12%'`锛夈€?
   * @param progress 灞曞紑杩涘害 0鈥?锛堢粓鐐规椂閿氱偣鍥炲埌灞呬腑锛岄伩鍏嶉潤姝㈡€佸亸蹇冿級
   * @deprecated 闆惰皟鐢ㄨ€咃紱涓?{@link morphStartScale} 鍚屽睘"鏃╂湡缁曢敋鐐圭缉鏀?閭ｄ竴鏃忔畫鐣欍€?
   * 澶嶆牳鍛戒护锛歚grep -rn 'morphCenterXPercent' RzdMusic --include=*.ets`锛堟湡鏈涳細鍙湁鏈瀹氫箟锛?
   */
  public morphCenterXPercent(progress: number): string {
    const target: number = this.windowWidthVp > 0 ? (this.miniX + this.miniSize / 2) / this.windowWidthVp : 0.5;
    const p: number = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    // 璧风偣鐢ㄨ糠浣犳潯鐨勪綅缃紝缁堢偣鍥炲埌 50%锛堥潤姝㈡€佷笉鍋忓績锛?
    const percent: number = (target + (0.5 - target) * p) * 100;
    return percent.toFixed(2) + '%';
  }

  /**
   * @returns 缂╂斁閿氱偣 Y锛屾湰椤靛潗鏍囩郴涓嬬殑鐧惧垎姣斿瓧绗︿覆銆?
   * @param progress 灞曞紑杩涘害 0鈥?
   */
  public morphCenterYPercent(progress: number): string {
    const target: number = this.windowHeightVp > 0
      ? (this.miniY + this.miniSize / 2) / this.windowHeightVp
      : 0.5;
    const p: number = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    const percent: number = (target + (0.5 - target) * p) * 100;
    return percent.toFixed(2) + '%';
  }

  /**
   * 鈽呪槄 2026-10-15锛?*宸插垽瀹氫负姝讳唬鐮?*锛宍RzdMusic璁板繂.md` 搂59锛夛細娉ㄩ噴閲岄偅涓?`setDragUpdate`
   * **鍏ㄤ粨涓嶅瓨鍦?*锛坄grep -rn 'setDragUpdate' RzdMusic --include=*.ets` 鏃犲懡涓級鈬?鏈瓧娈?
   * 鏃㈡病鏈夊啓鑰呬篃娌℃湁璇昏€呫€傚畠灞炰簬涓婁竴鐗?鎶婅窡鎵嬪洖璋冨杩涘叡浜姸鎬?鐨勫皾璇曪紝
   * 鑰屾椿鐨勯偅鏉¤矾鏄?*澹冲眰/杩蜂綘鏉″悇鑷寔鎵嬪娍銆佺洿鎺ヨ皟 `applyMorphProgress()`**锛堣涓嬮潰 搂浜旂偣浜?閭ｆ锛夈€?
   *
   * @deprecated 闆惰鑰呴浂鍐欒€呫€傝窡鎵嬭繘搴﹁璧?{@link applyMorphProgress}銆?
   * 澶嶆牳鍛戒护锛歚grep -rn 'dragUpdateToken\|setDragUpdate' RzdMusic --include=*.ets`
   */
  @Trace public dragUpdateToken: number = 0;

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?浜旂偣浜斻€佷笂鎷夋墦寮€锛堝鏍囨棤鐣?ExpandAnimation.applyPullProgress锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 鏃犵晫閭ｅ鏄?*鎵嬪娍椹卞姩**鐨勶細`onDown / onMove(205 鏉? / onUp` 鎶婃墜鎸囦綅绉绘槧灏勬垚涓€涓繘搴︼紝
  // 鏉炬墜鍚庢寜闃堝€?`doEnter`锛堝畬鎴愬睍寮€锛夋垨 `doBack`锛堝洖寮癸級锛岃窡鎵嬮樁娈佃繘搴?*鍙互鍋滃湪涓棿**銆?
  // 杩欓噷绛変环瀹炵幇锛氬３灞傦紙products锛夎礋璐ｆ墜鍔匡紝鏈被鍙瓨杩涘害涓庣浉浣嶃€?
  //
  // 鈿狅笍 娲荤殑鍏ュ彛鏄?**`pullOpenBegin()`**锛堣捣鎵嬶細閲忓嚑浣?+ 鍘嬪埌璧风偣锛変笌
  //    `morphBeginLeaving()` / `applyMorphProgress()` / `morphSettleOpen()`銆?
  //    涓嬮潰杩欎笁涓瓧娈垫槸瀹冧滑鐨勭姸鎬侊紱鍚屾閲屽師鏉ラ偅濂?`beginPullOpen/updatePull/endPullOpen/
  //    pullProgressFrom/pullShouldCommit` 宸叉寜 D5 鍒犻櫎锛堥浂璋冪敤鐐癸級銆?

  /**
   * 涓婃媺杩涘害锛?*0 = 瀹屽叏灞曞紑锛?00 = 杩樺湪杩蜂綘鏉￠偅涓€灏忓潡**锛堜笌 `collapseProgress` 鍚屽悜锛夈€?
   *
   * 澹冲眰鍦ㄨ窡鎵嬫椂鐩存帴鏀瑰畠锛屾挱鏀鹃〉鎶婂畠闀滃儚杩涜嚜宸辩殑 `collapseProgress`锛?
   * 浜庢槸"楂樺害 / 缂╂斁 / 浣嶇疆 / 鍦嗚 / 閫忔槑搴?鍏ㄩ儴璺熺潃鎵嬫寚璧般€?
   */
  @Trace public transitionProgress: number = 0;
  /** 鏄惁姝ｅ湪璺熸墜涓婃媺锛堟嫋鍔ㄦ湡闂翠笉璺戜换浣曡ˉ闂达紝杩涘害瀹屽叏鐢辨墜鎸囧喅瀹氾級銆?*/
  @Trace public pullDragging: boolean = false;
  /**
   * 鏈璺熸墜浼氳瘽鐨勮捣鎵嬫椂闂达紙ms锛宍Date.now()`锛夈€?
   *
   * 瀛樺湪鐨勬剰涔夛細`pullDragging` 涓€鏃︽畫鐣欙紙鏌愯疆鎵嬪娍娌¤蛋鍒版敹灏撅級锛岀偣鍑绘墦寮€灏变細**璺宠繃褰㈠彉
   * 鍒濆鍖?*銆侀€€鍖栨垚鑰佸姩鐢汇€傛湁浜嗚捣鎵嬫椂闂村氨鑳藉垽瀹?杩欎釜鏍囪鏄惁宸茬粡杩囨湡"鈥斺€?
   * 涓€娆¤窡鎵嬩笉鍙兘鎸佺画鍑犵锛岃秴杩囬槇鍊间竴瀹氭槸娈嬬暀銆?
   */
  @Trace public pullStartedAtMs: number = 0;

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 璺熸墜"琚嫆"璁℃暟锛堚槄 绾瘖鏂細涓嶅弬涓庝换浣曞垽鏂紝鍙笂寰芥爣锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // ## 涓轰粈涔堥渶瑕侊紙goal 绾緥銆屽厛鐢汇€庡叆鍙?脳 鍒ゆ柇銆忓鐓ц〃锛屽啀鍔ㄦ墜銆嶇殑钀界偣锛?
  //
  // 鐢ㄦ埛鎶ョ殑鐥囩姸鏄€?*涓婃粦涓嶈兘鑷敱浜?*銆? 鎵嬫寚鍦ㄥ姩銆佽繘搴︿笉璺熴€傚彲鑳界殑鏈哄埗鍙湁涓ょ被锛?
  //   (a) **鏇存柊琚煇涓垽鎹嫆鎺?*锛堟湰浠撹窡鎵嬮摼涓婂叡 3 涓?鎷掔粷鐐?锛岃涓嬶級锛?
  //   (b) 浜嬩欢鏈韩娌″埌锛堟墜鍔胯瘑鍒?/ 鍛戒腑鍖?/ 鐗堝紡闂锛夆€斺€?閭ｄ笌鐘舵€佹満鏃犲叧銆?
  // 涓よ€呬慨娉曞畬鍏ㄤ笉鍚岋紝鑰?*娌℃湁璁惧灏卞垎涓嶅嚭鏉?*锛堢敤鎴蜂笉鑳界敤 hdc锛夈€?
  // 鈬?鎶?(a) 鐨勪笁涓嫆缁濈偣**璁℃暟**骞舵樉绀哄湪寰芥爣涓婏紙闆惰涓哄彉鍖栵紝鍙姞涓変釜鑷锛夛細
  //     鐢ㄦ埛鍦ㄥ窘鏍囧紑鐫€鐨勬儏鍐典笅鍋氫竴娆′笂鎷夛紝鐪嬭繖涓変釜鏁?*鏈夋病鏈夊彉**锛?
  //       路 鍙樹簡 鈬?灏辨槸 (a)锛屽苟鐩存帴鎸囧嚭鏄摢涓€涓垽鎹紙涓嬮潰涓変釜瀛楁鐨勬敞閲婄粰浜嗗悇鑷惈涔夛級锛?
  //       路 涓€涓兘娌″彉 鈬?鍒ゆ嵁鍏ㄧ▼鏀捐 鈬?闂鍦?(b)锛屽幓鏌ユ墜鍔?鍛戒腑鍖猴紝**涓嶈鍐嶆敼鐘舵€佹満**銆?
  //
  // 鈽?涓変釜瀛楁**涓嶆竻闆?*锛堢疮璁″€硷級锛氱敤鎴蜂笉蹇?鍏堝紑寰芥爣鍐嶅鐜?锛岄殢鏃舵墦寮€灏辫兘鐪嬶紱
  //   鑻ユ煇娆¤捣鎵嬪氨澶辫触锛岀疮璁″€间篃浼?+1 骞朵竴鐩寸暀鐫€锛堥噸鍚?App 鎵嶅綊闆讹級銆?
  //   寰芥爣璇绘暟浣嶇疆锛?*绗崄琛?*灏鹃儴 `pd=<璧锋墜鎷?/<鏇存柊鎷?/<鏉炬墜鎷?`銆?

  /** 璧锋墜琚垽鎹嫆鎺夌殑娆℃暟锛坄pullOpenBegin` 杩斿洖 false 鈬?鐩存帴閾烘弧銆佹棤璺熸墜鍔ㄧ敾锛夈€?*/
  @Trace public pullDropBegin: number = 0;
  /** 璺熸墜鏇存柊琚?`pullDragging` 鎷掓帀鐨勬鏁帮紙鎵嬫寚鍦ㄥ姩浣嗚繘搴︿笉璺?鈥斺€?鏈潯鏈€鐩存帴锛夈€?*/
  @Trace public pullDropUpdate: number = 0;
  /** 鏉炬墜锛堟彁浜?鍥炲脊鍒ゅ畾锛夎 `pullDragging` 鎷掓帀鐨勬鏁般€?*/
  @Trace public pullDropEnd: number = 0;

  /** 璁颁竴娆?璧锋墜琚嫆"锛堣瘖鏂敤锛涜 {@link pullDropBegin} 鐨勮鏄庯級銆?*/
  public notePullDropBegin(): void {
    this.pullDropBegin = this.pullDropBegin + 1;
  }

  /** 璁颁竴娆?璺熸墜鏇存柊琚嫆"锛堣瘖鏂敤锛涜 {@link pullDropUpdate} 鐨勮鏄庯級銆?*/
  public notePullDropUpdate(): void {
    this.pullDropUpdate = this.pullDropUpdate + 1;
  }

  /** 璁颁竴娆?鏉炬墜琚嫆"锛堣瘖鏂敤锛涜 {@link pullDropEnd} 鐨勮鏄庯級銆?*/
  public notePullDropEnd(): void {
    this.pullDropEnd = this.pullDropEnd + 1;
  }

  // 鈿狅笍 **D5锛氳繖閲屽師鏉ヨ繕鏈変竴濂椼€屼笂鎷夋墦寮€銆嶇殑閬楃暀 API锛屽凡鍒?*锛?026-10-15 澶嶆牳锛岃
  //    `docs\鏃犵晫褰㈠彉鎵嬫劅-钀藉疄鍒癛zdMusic娓呭崟.md` 搂浜?寰呭姙绗?0 椤?/ 搂鍥?D5锛夛細
  //      `PULL_COMMIT_PROGRESS (=55)` / `pullProgressFrom()` / `pullShouldCommit()` /
  //      `beginPullOpen()` / `updatePull()` / `endPullOpen()`
  //    鍏ㄤ粨锛坄git grep -n 鈥?-- "*.ets" "*.ts"`锛屽惈 features / common / products锛?*闆惰皟鐢ㄧ偣**锛?
  //    鍙湪瀹氫箟澶勫嚭鐜般€傛椿鐨勯┍鍔ㄩ摼鏄?`morphUsable` / `morphBeginLeaving()` / `applyMorphProgress()` /
  //    `morphSettleOpen()` / `morphDrive` / `morphGen` / `morphGenAlive()` / `morphSessionDriving()`銆?
  //    鈬?涓ゅ骞跺瓨浼氳鍚庢潵鐨勪汉鏀归敊鍦版柟锛屾晠涓€骞跺垹闄わ紱涓婇潰涓変釜**浠嶅湪鐢?*鐨勫瓧娈?
  //    锛坄transitionProgress` / `pullDragging` / `pullStartedAtMs`锛変繚鐣欍€?
  //
  // 鈿狅笍 **D5 缁煡锛?026-10-15锛屽悓涓€鍙ｅ緞锛歚git grep -n "<鍚嶅瓧>" -- "*.ets"`锛?
  //    鍛戒腑鍏ㄩ儴钀藉湪鏈枃浠惰嚜宸辩殑瀹氫箟/娉ㄩ噴閲?= 闆惰皟鐢ㄧ偣锛?*锛氫笅闈㈣繖浜?public 鎴愬憳
  //    **浠嶆槸闆惰皟鐢ㄧ偣锛屼絾鏈疆銆屼繚鐣?+ 鐧昏銆嶈€屼笉鏄垹闄?*锛屼袱鏉＄悊鐢憋細
  //      鈶?娓呭崟 搂涓?鎶婂叾涓殑**鍏紡**锛坄pullBottomIn`锛夊垪涓恒€屽凡缁忓浜嗐€佸埆鍔ㄣ€嶁€斺€?
  //         瀹冩槸涓庢棤鐣屽璐︾殑鍙傝€冨叕寮忥紝鍒犳帀灏辨病鏈夊鐓х墿浜嗭紙搂47.2 褰撳垵涔熸槸杩欎箞瀹氱殑锛夛紱
  //      鈶?鍏朵綑鏄?鏁撮〉缂╂斁 / 鍘嬫墎鍐呭灞?閭ｄ竴鐗堬紙鐜拌绗?5 鐗堜箣鍓嶏級鐨勬棫 API銆?
  //         缁熶竴鐧昏鍦ㄨ繖閲岋紝**鍚庢潵鐨勪汉鍒啀鐓у畠鍐?* 鈥斺€?D5 瑕侀槻鐨勫氨鏄?鏀归敊鍦版柟"銆?
  //      路 鍦嗚 / 灏侀潰鏃у彛寰勶細`coverVisualRadius()`銆乣coverX()`銆乣coverY()`銆?
  //        `coverSize()`銆乣coverRadius()`銆乣coverOpacity()`
  //      路 灏侀潰涓ゆ。閫忔槑搴︾殑鏃у彛寰勶細`miniCoverOpacity()`銆乣innerCoverOpacity()`
  //      路 鏃ф暣椤甸€忔槑搴?/ 瑁佸壀璺緞锛歚pageOpacity()`銆乣clipCommands()`
  //      路 鏃х浉浣嶉棬锛歚hasGeometry()`銆乣armExpand()`銆乣beginAnimating()`銆乣finishAnimating()`
  //      路 鏃?鎺у埗鍖鸿嚜鍔ㄦ敹璧?锛歚chromeShouldAutoHide()`銆乣collapseChrome()`銆?
  //        `revealChrome()`銆佷互鍙?*鏈被**鐨?`touchChrome()`
  //        锛堚殸锔?`PlaybackPage` 閲屽彟鏈変竴涓?*鍚屽悕鐨勭鏈夋柟娉?*锛岄偅涓槸**娲荤殑** 鈥斺€?
  //         瀹冩寕鍦?`onTouch` 涓婇噸缃嚜鍔ㄦ敹璧疯鏃跺櫒锛屽埆娣凤級
  //        鈽呪槄鈽?2026-10-16锛?*杩欏洓涓凡鎸夋湰鏉℃墽琛屽垹闄?*锛堝惈 `lastChromeTouchMs` 涓?
  //        `CHROME_AUTO_HIDE_MS(3000)`锛夈€傜暀涓?`revealChrome()` / `touchChrome()` 鐨?*绠€鍖栫増**
  //        锛堝彧缈?`chromeCollapsed`锛屼笉鍐嶈鏃堕棿鎴筹級锛屽洜涓?`PlaybackPage` 浼氳皟瀹冧滑銆?
  //        鈿狅笍 涔嬫墍浠ュ繀椤诲垹锛氶偅瀵?3000ms 涓庢椿鐨勯偅鏉?`PlaybackPage.CHROME_AUTO_HIDE_MS(5000)` 鏄?
  //        **鍚屼竴涓姛鑳界殑涓ゅ鍊?* 鈬?鍚庢潵浜烘寜 3000 鏍稿浼氬緱鍑?涓庢棤鐣屼笉涓€鑷?鐨勯敊璇粨璁恒€?
  //      路 鏃ф贰鍏ユ贰鍑猴細瀹炰緥鏂规硶 `metaOpacity()`锛堚殸锔?涓庢鍚屽悕鐨?
  //        `miniBarMetaOpacity()` 鏄?*娲荤殑**锛屽埆娣凤級銆乣pullBottomIn()`
  //    鈿狅笍 **涓や釜"鏈夎皟鐢ㄧ偣浣嗙瓑浜庡父閲?鐨勫埆璇垽**锛歚chromeOpacity()` / `chromeOffsetY()`
  //      纭疄琚?`PlaybackPage` 鐨勬帶鍒跺尯璇诲埌锛屼絾**鍐欏叆鏂?*锛堜笂闈㈤偅缁?`chrome*`锛夐浂璋冪敤鐐?
  //      鈬?瀹冧滑鎭掍负 1 / 0锛岃鍒颁笉浜х敓浠讳綍鏁堟灉锛埪?7.4 / 搂48.6 璁扮殑灏辨槸杩欎欢浜嬶級銆?

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?浜旂偣鍏€佽鍓鍣ㄥ舰鍙橈紙瀵规爣鏃犵晫 ExpandAnimation.applyPullProgress锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 杩欐槸鏃犵晫閭ｅ鐨勬牳蹇冩墜娉曪紝涔熸槸鎴戝墠闈㈠嚑鐗?*娌″仛鍒颁綅**鐨勬牴鏈師鍥狅細
  //
  //   瀹冧笉鐢ㄣ€岄€愬厓绱犵畻鍧愭爣銆嶏紝鑰屾槸鈥斺€?
  //     1. 鎶婃暣涓挱鏀鹃〉褰撴垚**涓€涓ぇ瀹瑰櫒**锛屾寜 `initScale` 缂╁皬銆佸钩绉诲埌杩蜂綘鏉′綅缃紱
  //     2. 鍚屾椂鐢ㄤ竴涓?*绔栫洿瑁佸壀绐楀彛**鍙湶鍑轰笂闈竴灏忔埅锛坄clipHeight`锛夛紝
  //        閭ｄ竴鎴濂借惤鍦ㄨ糠浣犳潯灏侀潰涓娿€?
  //   3. progress 鎺ㄨ繘鏃讹細瀹瑰櫒鏀惧ぇ鍥?1銆佷綅绉诲洖 0銆佽鍓獥鍙ｉ暱鍒版弧灞忋€佸渾瑙掍粠 16 鍒?0銆?
  //
  // 浜庢槸"鎾斁鍣ㄤ粠杩蜂綘鏉￠偅涓€灏忓潡閫愭笎闀挎弧鍏ㄥ睆"鏄?*涓€涓缉鏀?+ 涓€灞傝鍓?*鐨勭粨鏋滐紝
  // 涓嶉渶瑕佺粰姣忎釜瀛愬厓绱犲崟鐙畻璧锋鐐癸紝涔熶笉浼氬洜涓哄瓙鍏冪礌甯冨眬宸紓鑰岄敊浣嶃€?
  //
  // 鍙嶇紪璇戝嚭鐨勫叕寮忥紙`applyPullProgress`锛宲rogress 0鈥?锛夛細
  //   scale      = initScale + (1 - initScale) * p
  //   translateX = initTranslateX * (1 - p)
  //   translateY = initTranslateY * (1 - p)
  //   clipHeight = initClipHeight + (fullClipHeight - initClipHeight) * p
  //   radius     = (initClipHeight*initScale/2 + (鍗婂緞澧為噺)*p) / scale   鈫?娉ㄦ剰闄や互 scale
  //
  // 浠ュ強 `initParams` 鐨勬帹瀵硷紙鍏ㄦ槸**瀹炴祴**锛岃 reportMini / reportWindow锛夛細
  //   initScale      = 杩蜂綘鏉″皝闈㈠ / 绐楀彛瀹?
  //   initClipHeight = px2vp(杩蜂綘鏉″皝闈㈤珮 / initScale)
  //   initTranslateX = px2vp(capsuleLeft - (绐楀彛瀹?- 灏侀潰瀹? / 2)
  //   initTranslateY = px2vp(capsuleTop - (灏侀潰楂?- 灏侀潰楂?initScale) / 2)

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?褰㈠彉绐楀彛锛堣捣鐐?= 杩蜂綘鏉￠偅鏉¤兌鍥婏紝缁堢偣 = 鏁村睆锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 妯″瀷锛堣繖鏄鍥涚増锛屽墠涓夌増鐨勬暀璁啓鍦ㄦ枃浠舵湯灏撅級锛?
  //
  //   1. **绐楀彛**锛氫竴涓创搴曠殑瀹瑰櫒锛屽昂瀵镐粠"杩蜂綘鏉￠偅鏉¤兌鍥?闀垮埌"鏁村睆"锛屽渾瑙掍粠鑳跺泭鍦嗚鏀跺埌 0銆?
  //      瀹?*姘歌繙搴曡竟瀵归綈**锛屾墍浠ュ睆骞曞簳閮ㄤ笉鍙兘鍑虹幇绌烘。 鈥斺€?杩欐槸"搴曢儴绌虹櫧"鐨勭粨鏋勬€цВ娉?
  //      锛堜箣鍓嶉潬绠椾綅绉诲幓琛ワ紝鎬绘槸宸潃杩蜂綘鏉＄搴曡竟閭ｅ嚑鍗?vp锛夈€?
  //   2. **鍐呭灞?*锛氬昂瀵告亽涓?`瀹夸富灏哄`锛堜粠涓嶉殢绐楀彛鍙樺寲 鈫?**鍏ㄧ▼闆堕噸鎺?*锛夛紝鎸?
  //      `min(绐楀彛瀹?瀹夸富瀹? 绐楀彛楂?瀹夸富楂?` 绛夋瘮缂╂斁鍚庡眳涓€傜獥鍙ｆ棭鏈熷張瀹藉張鎵侊紝
  //      姝ゆ椂鍐呭灞傚畬鍏ㄩ€忔槑锛堣 `MORPH_CONTENT_FADE_FROM_SCALE`锛夛紝绛夐〉闈㈠澶т簡鎵嶆诞鐜般€?
  //   3. **妗ユ帴灏侀潰**锛氫竴寮犺劚绂诲竷灞€鐨勫皝闈紝浠庤糠浣犳潯灏侀潰鐭╁舰璧板埌鎾斁椤靛皝闈㈢煩褰紝
  //      **p = 1 鏃舵墠钀戒綅**锛涙挱鏀鹃〉鑷繁閭ｅ紶灏侀潰鍦ㄥ舰鍙樻湡闂翠笉鐢伙紙鍚﹀垯浼氬嚭鐜颁袱寮犲皝闈級銆?
  //
  // 鍏ㄩ儴鐘舵€侀兘鏄?*鍩虹绫诲瀷**鐨?`@Trace` 瀛楁锛氳窡鎵嬫椂姣忎竴甯ч兘瑕侀噸缁橈紝
  // 瀵硅薄瀛楁锛坄@Trace morph: SomeInterface`锛夊湪鏌愪簺鐗堟湰涓婁笉浼氳Е鍙戝埛鏂帮紝韪╄繃銆?

  /** Source stays mounted for measurement; only paint ownership changes. */
  @Trace public sourceBarHidden: boolean = false;
  @Trace public metaBridgeActive: boolean = false;
  @Trace public metaBridgeGeneration: number = 0;
  private sourceTitle: MorphMetaEndpoint | undefined = undefined;
  private sourceSinger: MorphMetaEndpoint | undefined = undefined;
  private floatingTitle: MorphMetaEndpoint | undefined = undefined;
  private floatingSinger: MorphMetaEndpoint | undefined = undefined;
  private metaSourceFloating: boolean = false;
  private targetTitle: MorphMetaEndpoint | undefined = undefined;
  private targetSinger: MorphMetaEndpoint | undefined = undefined;
  public metaStartTitle: MorphMetaEndpoint = new MorphMetaEndpoint();
  public metaStartSinger: MorphMetaEndpoint = new MorphMetaEndpoint();
  public metaEndTitle: MorphMetaEndpoint = new MorphMetaEndpoint();
  public metaEndSinger: MorphMetaEndpoint = new MorphMetaEndpoint();

  public registerMorphMeta(source: boolean, singer: boolean, endpoint: MorphMetaEndpoint,
    floating: boolean = false): void {
    if (source && floating) {
      if (singer) {
        this.floatingSinger = endpoint;
      } else {
        this.floatingTitle = endpoint;
      }
    } else if (source) {
      if (singer) {
        this.sourceSinger = endpoint;
      } else {
        this.sourceTitle = endpoint;
      }
    } else if (singer) {
      this.targetSinger = endpoint;
    } else {
      this.targetTitle = endpoint;
    }
  }

  public invalidateMorphMetaTarget(title: TextController, singer: TextController): void {
    // A disappearing old subtree must not unregister the replacement Text endpoints.
    if (this.targetTitle?.controller === title) {
      this.targetTitle = undefined;
    }
    if (this.targetSinger?.controller === singer) {
      this.targetSinger = undefined;
    }
    this.logMorphOwnership('target-subtree-disappear');
  }

  public cancelMetaForTrackChange(): void {
    if (!this.metaBridgeActive) {
      return;
    }
    // Preserve container/lyric animation; only the stale frozen text relinquishes ownership.
    this.metaBridgeActive = false;
    Logger.info('RzdMetaMorph', `track changed: release stale text gen=${this.morphGen}`);
  }

  /** Freeze both real Text nodes before any container transform or ownership change. */
  public freezeMorphMeta(ui: UIContext): boolean {
    if (this.metaBridgeActive) {
      return true;
    }
    // Never replace frozen endpoints using a partially translated/scaled live frame.
    if (this.morphStage === MorphStage.LEAVING ||
      (this.morphLive() && this.morphDrive === MorphDrive.ANIM)) {
      return false;
    }
    const st = (this.metaSourceFloating ? this.floatingTitle : this.sourceTitle)?.measure(ui);
    const ss = (this.metaSourceFloating ? this.floatingSinger : this.sourceSinger)?.measure(ui);
    const et = this.targetTitle?.measure(ui, true);
    const es = this.targetSinger?.measure(ui, true);
    if (st === undefined || ss === undefined || et === undefined || es === undefined ||
      st.content !== et.content || ss.content !== es.content) {
      Logger.info('RzdMetaMorph', `pending real endpoints gen=${this.morphGen}`);
      return false;
    }
    this.metaStartTitle = st;
    this.metaStartSinger = ss;
    this.metaEndTitle = et;
    this.metaEndSinger = es;
    this.metaBridgeGeneration = this.morphGen;
    this.metaBridgeActive = true;
    this.sourceBarHidden = true;
    this.logMorphOwnership('freeze-natural-endpoints');
    Logger.info('RzdMorphOwnership', `acquire gen=${this.morphGen} sourceHidden=1 targetHidden=1`);
    Logger.info('RzdMetaMorph', `endpointdimensions gen=${this.morphGen} trueendnatural=1 ` +
      `title=${et.width}x${et.height} endbaseline=${et.baselineVp} endWindowBaseline=${et.y + et.baselineVp} ` +
      `singer=${es.width}x${es.height} endbaseline=${es.baselineVp} endWindowBaseline=${es.y + es.baselineVp} ` +
      `targetLineHeightFp=${et.lineHeightFp},${es.lineHeightFp} baselineSpace=paragraph-local`);
    Logger.info('RzdMetaMorph', `freeze gen=${this.morphGen} title=(${st.x},${st.y},${st.width},${st.height},${st.fontFp}fp,b=${st.baselineVp})->(${et.x},${et.y},${et.width},${et.height},${et.fontFp}fp,b=${et.baselineVp}) singer=(${ss.x},${ss.y},${ss.width},${ss.height},${ss.fontFp}fp,b=${ss.baselineVp})->(${es.x},${es.y},${es.width},${es.height},${es.fontFp}fp,b=${es.baselineVp})`);
    return true;
  }

  public morphMetaFrame(singer: boolean): MorphMetaFrame {
    const start = singer ? this.metaStartSinger : this.metaStartTitle;
    const end = singer ? this.metaEndSinger : this.metaEndTitle;
    const p = this.morphP;
    const frame = new MorphMetaFrame();
    frame.x = start.x + (end.x - start.x) * p;
    frame.y = start.y + (end.y - start.y) * p;
    frame.width = start.width + (end.width - start.width) * p;
    frame.height = start.height + (end.height - start.height) * p;
    // Keep target typography/layout fixed; only paint scale interpolates with cover P.
    // This avoids per-frame font reflow and guarantees the genuine p=1 text endpoint.
    frame.fontFp = end.fontFp;
    // Interpolate start/end ratio, not resolved Resource px. At p=1 scale is exactly 1.
    frame.scale = end.fontFp > 0 ? start.fontFp / end.fontFp +
      (1 - start.fontFp / end.fontFp) * p : 1;
    // Clone keeps the real target's default line-height policy; do not synthesize it
    // from glyph metrics. Full target layout space is independent of the paint frame.
    frame.baselineVp = start.baselineVp + (end.baselineVp - start.baselineVp) * p;
    frame.opacity = start.opacity + (end.opacity - start.opacity) * p;
    return frame;
  }

  private logMetaFont(singer: boolean, event: string): void {
    const declared = singer ? this.targetSinger : this.targetTitle;
    const end = singer ? this.metaEndSinger : this.metaEndTitle;
    const frame = this.morphMetaFrame(singer);
    const renderRatio = declared !== undefined && declared.fontFp > 0 ?
      frame.fontFp * frame.scale / declared.fontFp : 0;
    Logger.info('RzdMetaFont', `event=${event} gen=${this.morphGen} singer=${singer} ` +
      `p=${this.morphP} declaredFp=${declared?.fontFp ?? 0} endFp=${end.fontFp} ` +
      `bridgefontFp=${frame.fontFp} paintScale=${frame.scale} renderRatio=${renderRatio} ` +
      `fontScaleAppliedByTextOnly=1`);
  }

  /**
   * @returns **澹冲眰姝屽悕鍏嬮殕灞?*锛坄MorphMetaBridge`锛夌幇鍦ㄨ涓嶈鎺ョ缁樺埗銆?
   *
   * 鈽呪槄鈽?2026-10-16锛堢敤鎴峰疄娴嬶細銆?*閭ｄ釜姝屾洸鍚嶅拰姝屾墜鍚嶇幇鍦ㄦ€庝箞杩樻槸涔嬪墠鐨勪竴闀滃埌搴曠殑椋炲叆锛?
   *   鏀规垚鏃犵晫涓€鏍风殑**銆嶏級鈬?**鏈柟娉曟敼鎴愭亽 `false`**銆?
   *
   * ## 涓轰粈涔堝師鏉ラ偅濂楁槸"涓€闀滃埌搴曠殑椋炲叆"锛堣€屽畠涓嶆槸鏃犵晫鐨勫仛娉曪級
   *
   * 鍘熸潵 `metaBridgeOwnsPaint()` 涓虹湡鏃讹細
   * ```
   *   路 澹冲眰 MorphMetaBridge 鍦ㄣ€愮獥鍙ｅ潗鏍囥€戠敾涓€浠芥瓕鍚?姝屾墜鍏嬮殕锛?
   *     鐢?morphMetaFrame() 鐨?x/y + 瀛楀彿脳scale 浠?杩蜂綘鏉￠偅涓€琛?涓€璺彃鍊奸鍒?钀界偣閭ｄ竴琛?锛?
   *   路 鎾斁椤佃嚜宸遍偅涓€琛屽悓鏃惰 targetMetaOpacity() 鍘嬫垚 0锛堜氦妫掞級銆?
   * ```
   * 鈬?瑙傛劅灏辨槸**涓€涓瓕鍚嶄粠杩蜂綘鏉′綅缃暱閫旈鍒拌惤鐐?*锛堢敤鎴疯鐨?涓€闀滃埌搴曠殑椋炲叆"锛夈€?
   *
   * ## 鏃犵晫閭ｈ竟鏄粈涔堟牱
   *
   * `floatingMeta` 閲?*鍙湁涓€琛?* `metaRow`锛坄PlayerPage瀹屾暣UI瀹氱.md` 搂6.1/搂6.2锛夛細
   * ```
   *   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)   // 浣嶇Щ鎻掑€?
   *   瀛楀彿 = lerp(chrome().titleSize 脳 sizeK, 15 脳 sizeK, metaProgress)          // 瀛楀彿鎻掑€?
   *   opacity = pullChromeOpacity = clamp((t 鈭?0.18) / 0.44)                     // 0.18鈫?.62 娣″叆
   * ```
   * 鈬?**娌℃湁绗簩涓厓绱犲湪椋?*锛氶偅涓€琛屽氨鏄?鍘熷湴娣″叆 + 璺熺潃褰㈠彉杩涘害寰皟浣嶇疆"銆?
   *
   * ## 鎵€浠ユ湰澶勬€庝箞鏀?
   *
   * 鎭掕繑鍥?`false` 鈬?鍏嬮殕灞?*涓嶅啀鐢?*锛岀粯鍒舵潈涓€鐩寸暀鍦?*鎾斁椤佃嚜宸遍偅涓€琛?*锛坄targetMetaOpacity()`
   * 闅忎箣鎭掕蛋 `pullChromeOpacity()` 鍒嗘敮锛夈€傞偅涓€琛岀幇鍦ㄧ殑鍔ㄧ敾鏄細
   * ```
   *   路 涓嶉€忔槑搴?= pullChromeOpacity = clamp((p 鈭?0.18) / 0.44)   鈫?涓庢棤鐣屽悓涓€涓獥鍙?
   *   路 浣嶇Щ     = metaRiseVp() = (1 鈭?ramp01(p, 0.18, 0.62)) 脳 180vp / scale
   *                鈫?浠庝笅鍗囪捣 180vp锛堢敤鎴?10-15 瀹氳皟銆屼笉瑕佹贰鍏ユ贰鍑猴紝鐢ㄤ綅绉诲嚭鍦恒€嶏級
   * ```
   * 鈬?涓庢棤鐣屽悓鏋勶細**涓€琛屻€佸師鍦般€佹贰鍏?+ 鍗囪捣**锛屾病鏈夐暱閫旈琛屻€?
   *
   * 鈿狅笍 鍏抽棴瀹冪殑**浠ｄ环**锛堝瀹炵櫥璁帮級锛氬舰鍙樻湡闂撮偅涓€琛屽湪**琚缉鏀剧殑瀹瑰櫒閲?*锛屽瓧浼氳涓€璧风缉灏忋€?
   *   鍦ㄦ棭鏈燂紙p < 0.4锛夊畠寰堝皬锛屼絾鍥犱负 `pullChromeOpacity` 鍦?p = 0.18 鎵嶈捣姝ャ€?.62 鎵嶆弧锛?
   *   瑙傛劅鏄?闅忕潃椤甸潰闀垮ぇ鑰屾贰鍏? 鈥斺€?涓庢棤鐣岀殑"璺熺潃褰㈠彉杩涘害娣″叆"鍚屾棌銆?
   *   鈿狅笍 鑻ョ湡鏈轰笂鏄惧緱"瀛椾竴寮€濮嬪お灏?锛岄偅璇存槑璇ユ妸杩欎竴琛?*涔熸惉鍒板舰鍙樺鍣ㄤ箣澶?*
   *   锛? 鏃犵晫 `floatingMeta` 鐨勪綅缃細涓?`playerPane` 鍚岀骇锛夛紝閭ｆ槸涓€娆＄嫭绔嬬殑缁撴瀯鏀瑰姩銆?
   */
  public metaBridgeOwnsPaint(): boolean {
    return false;
  }

  public targetMetaOpacity(): number {
    // Stable OPEN is unconditional TARGET ownership, even after a stale callback.
    if (this.morphStage === MorphStage.OPEN) {
      return 1;
    }
    // 鈽呪槄鈽呪槄 2026-10-17锛堢敤鎴凤細銆?*姝屽悕/姝屾墜閭ｄ竴琛岀殑椋炲叆杩樻槸鏈夐棶棰?*銆嶏級
    //
    // 鍘熸潵杩欓噷鏄細
    // ```
    //   return this.metaBridgeOwnsPaint() ? 0 : this.pullChromeOpacity();
    // ```
    // 涔熷氨鏄?鍏嬮殕灞傛帴绠℃湡闂磋繖涓€琛屼负 0"銆備絾**鏈粨鐨勫厠闅嗗眰鍙敾灏侀潰**
    // 锛坄MorphCoverClone()` 閲屽彧鏈変竴寮?`Image`锛沗metaBridgeOwnsPaint()` 鐨勬敞閲婅嚜宸变篃鍐欑潃
    //  "娴眰杩欎竴灞傚湪鏈粨鍙敾灏侀潰"锛夆噿 閭ｄ釜 `? 0` **浠€涔堜篃娌℃崲鍥炴潵**锛?
    // 鍙槸鎶婅繖涓€琛屽湪**鏁存褰㈠彉閲岃棌璧锋潵** 鈬?鐢ㄦ埛鐪嬪埌鐨勫氨鏄?姝屽悕鐨勯鍏ヤ笉瀵?涓€旀病鏈夊畠"銆?
    // 鏃犵晫閭ｈ竟锛歚floatingMeta` 鐨勬樉闅愬彧鐢?`motionImmersive` 閭ｄ釜 `If` 绠★紝
    // 褰㈠彉鏈熺殑娣″叆璧?`pullChromeOpacity = clamp((effT鈭?.18)/0.44)`锛? 鐢ㄦ埛宸茬‘璁ょ殑 鈶級銆?
    // 鈬?鐓ф惉锛?*涓嶅啀鍥犱负"鍏嬮殕灞傛帴绠?鑰岀疆 0**锛屼竴寰嬫寜娣″叆绐楄蛋銆?
    return this.pullChromeOpacity();
  }

  public logMorphOwnership(event: string): void {
    Logger.info('RzdMorphOwnership', JSON.stringify({ event: event, gen: this.morphGen,
      metaGen: this.metaBridgeGeneration, stage: this.morphStage, drive: this.morphDrive,
      p: this.morphP, driving: this.morphSessionDriving(), metaActive: this.metaBridgeActive,
      bridgePaint: this.metaBridgeOwnsPaint(), sourceHidden: this.sourceBarHidden,
      targetOpacity: this.targetMetaOpacity(), contentOpacity: this.morphContentOpacity }));
  }

  private releaseMorphOwnership(toMini: boolean): void {
    this.metaBridgeActive = false;
    this.sourceBarHidden = !toMini;
    Logger.info('RzdMorphOwnership', `release gen=${this.morphGen} toMini=${toMini} sourceHidden=${this.sourceBarHidden}`);
  }

  /** 褰㈠彉闃舵銆?*/
  @Trace public morphStage: MorphStage = MorphStage.NONE;
  /** 褰㈠彉椹卞姩鑰咃紙鎵嬫寚 / 鍔ㄧ敾锛夈€?*/
  @Trace public morphDrive: MorphDrive = MorphDrive.NONE;
  /** 璺熸墜杩涘害 0鈥?锛? = 杩樻槸杩蜂綘鏉￠偅鏉¤兌鍥婏級銆?*/
  @Trace public morphP: number = 1;

  /**
   * **内容时间线**进度 0~1 —— 上游 `PlayerPage.pullT`，与 {@link morphP}（几何时间线）**分开两条**。
   *
   * ## 上游为什么是两条（逐条证据）
   * ```
   *   容器几何（scale / translateX/Y / clipHeight / radius / overlayColor）
   *       ← ExpandAnimation.doEnter = 350ms + Curve.EaseInOut
   *         （_recover/logic-src/展开收起动画时间轴定稿.md §一；ExpandAnimation驱动与补间定稿.md:480）
   *   内容窗口（歌名行 / 收藏更多 / 小歌词 / 进度条 / 传输行 / 背景）
   *       ← MainPage.morphT = animateMorphT(1, ENTER_MS, EASE_OUT_STR, λ) = 560ms + 快出慢收
   *         （wujie.pa:154167-154169 `ldai 0x230` → `definepropertybyname "ENTER_MS"`
   *           wujie.pa:163524-163547 `animateMorphT` + `ENTER_MS` + `EASE_OUT_STR`
   *           wujie.pa:145608-145661 `animateMorphT` = createAnimator + onFrame 逐帧写 `morphT`）
   * ```
   * 关键一环：`PlayerPage` 自己拿不到 `MainPage.morphT`，它读的是同一份 AppStorage 键
   * （`_recover/logic-src/pullT写入算式与形变枚举.md:24-81`，字节码 L168180-168190 / L144036-144048）：
   * ```
   *   PlayerPage: pullT  = createStorageProp(K_PULL_T, …, "pullT")   // 单向读
   *   MainPage:   morphT = createStorageLink(K_PULL_T, "morphT")     // 双向写
   *   ⇒ pullT ≡ morphT
   * ```
   * 而 `effT()`（`wujie.pa:171535-171548`）= `isMorphTarget() ? 1 : pullT`，三个内容窗口都吃它：
   * `pullBgIn = clamp(effT/0.30)`（`wujie.pa:176295-176326`）、
   * `pullChromeOpacity = clamp((effT−0.18)/0.44)`（`wujie.pa:176459-176505`，`fldai 1.8e-1` / `6.2e-1`）、
   * `pullBottomIn = clamp((effT−0.45)/0.55)`（`wujie.pa:176377-176406`，`fldai 4.5e-1`）。
   *
   * ⛔ 本仓原来把几何与内容都挂在 `morphP`（350ms / `Curve.EaseInOut`）上 ⇒ 所有窗口在墙钟时间上
   *    比上游**早 37%**（350/560）跑完，这正是用户实测「进度条和下面几个控件飞入比无界早了很多」。
   *
   * ⚠️ 取值一律走 {@link contentProgress}（内容补间没在跑时它与 `morphP` 严格同值 ⇒ 静止态 / 关闭态
   *    / 外部直接写 `morphP` 的路径取值与改动前**逐值相同**）。
   */
  @Trace public contentP: number = 1;
  /** 内容补间的世代号：新补间 / 取消之后，旧的收尾回调直接丢弃。 */
  private contentGen: number = 0;
  /** 内容时间线是否正由自己的 560ms 补间驱动（true ⇒ 取值读 `contentP`，false ⇒ 读 `morphP`）。 */
  private contentTweenOwned: boolean = false;

  /**
   * @returns 内容时间线当前进度 0~1（**所有内容窗口的唯一取值口**）。
   *
   * 内容补间在跑 ⇒ `contentP`（上游 `pullT`，560ms + `EASE_OUT_STR`）；
   * 其余一切时刻 ⇒ `morphP`（与几何同一条线：静止 / 关闭 / 手势跟手都逐值一致）。
   */
  public contentProgress(): number {
    const raw: number = this.contentTweenOwned ? this.contentP : this.morphP;
    return raw < 0 ? 0 : (raw > 1 ? 1 : raw);
  }

  /**
   * 起内容补间前调用：先把 `contentP` 对齐到几何当前进度，再接管取值口。
   *
   * ⚠️ 顺序是硬约束：**先赋 `contentP`、再置 owned** —— 反了的话补间第一帧会从旧值起跳。
   * @returns 本次补间的世代号（收尾时原样交给 {@link endContentTween}）
   */
  public beginContentTween(): number {
    this.contentGen = this.contentGen + 1;
    const from: number = this.morphP < 0 ? 0 : (this.morphP > 1 ? 1 : this.morphP);
    this.contentP = from;
    this.contentTweenOwned = true;
    Logger.info(PlayerExpandState.logTag,
      `morph content tween begin from=${from.toFixed(3)} gen=${this.contentGen} ` +
        `ms=${PlayerExpandState.MORPH_CONTENT_DURATION_MS} curve=EASE_OUT_STR`);
    return this.contentGen;
  }

  /**
   * 内容补间收尾：只有世代号仍是本次才生效（被打断 / 取消的旧回调直接丢弃）。
   *
   * 收尾后取值口回到 `morphP` —— 此时几何早已落位（350ms < 560ms），两者同为终点值。
   */
  public endContentTween(gen: number, landed: number): void {
    if (gen !== this.contentGen) {
      return;
    }
    this.contentTweenOwned = false;
    if (this.contentP !== landed) {
      this.contentP = landed;
    }
    Logger.info(PlayerExpandState.logTag,
      `morph content tween done contentP=${this.contentP.toFixed(3)} ` +
        `morphP=${this.morphP.toFixed(3)} gen=${gen}`);
  }

  /** 取消内容时间线（关闭 / 复位 / 异常路）：立刻交还给 `morphP`，并作废旧收尾回调。 */
  public cancelContentTween(): void {
    this.contentGen = this.contentGen + 1;
    this.contentTweenOwned = false;
  }
  /**
   * 褰㈠彉**涓栦唬鍙?*锛堝鏍囧弽缂栬瘧閲岀殑 `animGen`锛夈€?
   *
   * 姣忔杩涘叆/绂诲紑褰㈠彉閮?+1锛涙墍鏈夊欢鏃跺洖璋冿紙琛ラ棿鏀跺熬銆佸嵏杞姐€丩ANDING锛夐兘瑕佸厛姣斿瀹冿紝
   * 涓嶇浉绛夊氨涓㈠純銆傚弽缂栬瘧閭ｈ竟涓撻棬寮鸿皟浜嗚繖鏉★細"蹇€熻繛缁垏鎹紙杩炵画鐐瑰紑/鏀惰捣锛夋椂锛?
   * 鏃у姩鐢荤殑鍥炶皟涓嶄細姹℃煋鏂扮姸鎬侊紝涓嶅甫杩欎釜鏈哄埗蹇€熸嫋鍔ㄤ細鐘舵€侀敊涔?銆?
   */
  @Trace public morphGen: number = 0;

  /** 褰㈠彉绐楀彛锛? 鏁撮〉缂╂斁鍚庣殑鍙鐭╁舰锛夌殑缂╂斁銆?*/
  @Trace public morphScale: number = 1;
  /** 褰㈠彉瀹瑰櫒鐨勪綅绉?x锛坴p锛夛細璁?鍙宸︿笂瑙?钀藉湪绠楀嚭鏉ョ殑浣嶇疆涓娿€?*/
  @Trace public morphTx: number = 0;
  /** 褰㈠彉瀹瑰櫒鐨勪綅绉?y锛坴p锛夈€?*/
  @Trace public morphTy: number = 0;
  /** 褰㈠彉瀹瑰櫒鐨勮鍓珮搴︼紙vp锛屽竷灞€鍗曚綅锛夛細鍙楂樺害 / 缂╂斁銆?*/
  @Trace public morphClipHeight: number = 0;
  /** 褰㈠彉瀹瑰櫒鍦嗚锛坴p锛屽竷灞€鍗曚綅锛夛細**宸茬粡闄や互缂╂斁**锛屽睆涓婄殑鍙鍦嗚鎵嶆槸璁捐鍊笺€?*/
  @Trace public morphRadius: number = 0;
  /** 鍐呭灞備笉閫忔槑搴︼紙鍙鐭╁舰鎺ヨ繎鏁村睆鎵嶆诞鐜帮級銆?*/
  @Trace public morphContentOpacity: number = 1;

  /**
   * **澹冲眰娴眰鎷疯礉**鐨勭嫭绔嬭繘搴?0鈥?锛堝彧鏈夋诞灞傞偅涓€浠藉皝闈㈠厠闅嗗悆瀹冿級銆?
   *
   * 涓轰粈涔堣涓?`morphP` 鍒嗗紑锛氬鏍囨棤鐣岀殑**涓ゅ眰缁撴瀯** 鈥斺€?鎾斁椤靛唴蹇収 350ms銆?
   * 娴眰鎷疯礉 560ms 涓旀洸绾夸笉鍚岋紙蹇嚭鎱㈡敹锛夈€備袱鑰呭悓璧枫€佸悇鑷埌鐐广€?
   * **鎾斁椤电殑鍑犱綍浠嶇劧鍙敱 `morphP` 椹卞姩**锛屾湰瀛楁涓嶅弬涓庝换浣曢〉鍐呮憜鏀俱€?
   *
   * 鍐欏叆鐐癸紙鍙湁杩欎笁涓紝鍒啀鍔狅級锛?
   *   鈶?鎵嬫寚璺熸墜锛歚syncMorphOverlayFromPage()`锛堜笌 `morphP` 涓€姣斾竴鍚屾锛屼笉璺戣ˉ闂达級锛?
   *   鈶?琛ラ棿锛歚morphOverlayTweenTo()`锛堝敮涓€涓€澶?animateTo锛?60ms + 蹇嚭鎱㈡敹锛夛紱
   *   鈶?澶嶄綅锛歚morphOverlayReset()`锛坄morphReset` / 浼氳瘽寮€濮嬶級銆?
   */
  @Trace public morphOverlayP: number = 1;
  /** 娴眰鎷疯礉琛ラ棿鐨勪笘浠ｅ彿锛堟柊琛ラ棿/澶嶄綅鍚庢棫鍥炶皟鐩存帴涓㈠純锛夈€?*/
  private morphOverlayGen: number = 0;
  /** 娴眰鎷疯礉姝ゅ埢鏄惁鏈夎ˉ闂村湪璺戯紙闃叉鍚屼竴娈靛姩鐢昏閲嶅璧蜂竴閬嶏級銆?*/
  private morphOverlayAnimating: boolean = false;
  /**
   * 鏈疆鏀惰捣鏄笉鏄?*宸茬粡鏈変汉**鎶婃诞灞傞偅涓€妫掕捣杩囦簡锛堝敮涓€娓呴浂鐐?= {@link morphOverlayReset}锛夈€?
   * 瑙?`focusMorphOverlayForPageCollapse()` 閲岀殑骞傜瓑鎶ゆ爮璇存槑銆?
   */
  private morphOverlayCollapseOwned: boolean = false;
  /**
   * 鈽呪槄鈽?2026-10-17锛氳繖涓€鍏虫槸**蹇収鏀剁缉**锛坄closeWithAnimation` 鎴愬姛鏀級鏀剁殑 鈬?娴眰涓嶈鍐嶇敾灏侀潰銆?
   * 鍞竴缃湡鐐?= {@link beginSnapshotShrink}锛涘敮涓€娓呴浂鐐?= {@link morphOverlayReset}銆?
   * 瑙?{@link morphOverlayBridging} 椤堕儴閭ｆ锛堝惁鍒?蹇収閲岄偅寮?+ 鍏嬮殕灞傞偅寮?= 涓や釜灏侀潰锛夈€?
   */
  private snapshotShrinkOwned: boolean = false;
  /**
   * 鈽呪槄鈽?2026-10-17锛堢収鎼棤鐣?`MainPage.pullMode`锛夛細鏈褰㈠彉浼氳瘽**鏄笉鏄粠涓嬫媺閭ｆ潯璺捣鐨?*銆?
   *
   * 鏃犵晫鑳屾櫙灞傜殑涓嶉€忔槑搴︽寜瀹冨垎娴侊紙`wujie.pa:192161-192176`锛夛細
   * ```
   *   __Common__().opacity(pullMode ? pullBgOpacity() : expand.contentOpacity)
   * ```
   * 鍐欑偣鍙湁涓や釜锛歚pullOpenBegin()` 缃?*鐪?*銆乣morphReset()` 缃?*鍋?*銆?
   * 鈿狅笍 涓嶈鐢?`morphDrive === FINGER` 浠ｆ浛锛氭澗鎵嬫彁浜や箣鍚?`morphDrive` 浼氬彉鎴?`ANIM`锛?
   *   鑰屾棤鐣岀殑 `pullMode` 鍦ㄦ暣娈佃窡鎵?+ 鎻愪氦琛ラ棿閲?*涓€鐩存槸鐪?*銆?
   */
  @Trace public pullMode: boolean = false;

  /**
   * @returns 鏃犵晫閭ｄ釜 `effT()`锛歚褰㈠彉涓?? morphT : 1`锛坄wujie.pa:176295-176326` 鐨勫叆鍙傦級銆?
   * 闈欐鎬佹亽 1 鈬?涓€鍒?鎸?effT 绠?鐨勫叕寮忓湪闈欐鎬侀兘鍙栨弧鍊笺€?
   */
  public effT(): number {
    // ★ 2026-10-18 更正（此前这条注释的极性写反了）：上游是
    //   `effT() = isMorphTarget() ? pullT : 1`（`wujie.pa:171535-171549`：
    //   `ldai 0x1` 起手，`isMorphTarget()` 为**假**才跳出去用 1，为真才改读 `pullT`）——
    // `pullT` ≡ `MainPage.morphT`（560ms + `EASE_OUT_STR`）⇒ 这里读**内容时间线**。
    return this.morphContainerActive() ? this.contentProgress() : 1;
  }

  /** @returns 娴眰鎷疯礉鐨勮ˉ闂存槸鍚︽鍦ㄨ窇锛堝彧璇伙紝缁欐挱鏀鹃〉鐨勬棩蹇椾笌鎶ゆ爮鐢級銆?*/
  public overlayTweenAnimating(): boolean {
    return this.morphOverlayAnimating;
  }
  /** `hostsMorphOverlay()` 鐨勭紦瀛橈細-1 = 杩樻病鍒よ繃锛? = 鍚︼紝1 = 鏄紙瑙佽鍑芥暟鐨勮鏄庯級銆?*/
  private morphOverlayHostCached: number = -1;

  /**
   * 褰㈠彉鍑犱綍鏄惁鍙敤锛坄morphInitParams()` 鐨勭粨璁猴級銆?
   *
   * 鈿狅笍 蹇呴』鏄惧紡璁颁笅鏉ワ細鍑犱綍娌￠綈鏃舵部鐢ㄩ粯璁ゅ€间細鎶婃挱鏀鹃〉寮勬垚涓€鏉＄粏缂?
   *    鈥斺€?閭ｅ氨鏄?涓婃媺鎵撳紑鎾斁鍣紝灞忓箷涓婄湅涓嶅埌涓滆タ"銆?
   */
  @Trace public morphUsable: boolean = false;
  /**
   * 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫 `PlayerPage.__pullGeomReady`**锛夛細
   * 鏈疆褰㈠彉鐨?*缁堢偣鍑犱綍**鏄惁宸茬粡閲忓埌锛? 鍙互鎸夊叕寮忕粰瀹瑰櫒钀介潪鎭掔瓑鐨?`scale/translate/clip`锛夈€?
   *
   * ## 涓轰粈涔堝繀椤绘湁杩欎竴鏉★紙瀹冩槸銆岀偣鍑绘墦寮€ / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖 娌℃湁鍔ㄧ敾銆嶇殑鏈€鍚庝竴鎶婇攣锛?
   *
   * 鏃犵晫渚э紙`wujie.pa` 鍘熸枃锛岄€愭潯瀵瑰簲锛夛細
   * ```
   *   PlayerPage.__pullGeomReady                          // 168236锛堝垵鍊?false锛?
   *   ExpandAnimation.applyPullProgress:                  // 50930-50946
   *       if (!pullReady) { this.initParams(ui); pullReady = true; }   // 鈫?鍙湁杩欎竴绉嶈繘娉?
   *       ...scale/translate/clip 鐨勬彃鍊?..
   *   PlayerPage.publishMorphTargets:                     // 175872-176232
   *       if (swiperProgress > 0.02) return;               // 鍙湁**灏侀潰椤?*鎵嶄笂鎶?
   *       if (!isMorphTarget()) return;
   *       ...閲?playerCoverRect / playerMetaRect锛岃秺鐣屾垨閲忎笉鍒?鈫?schedulePublishRetry()...
   *       ExpandSnapshot.playerCoverRect = cover; playerMetaRect = meta;
   *       if (!pullMode) {                                 // 鐐瑰嚮鎵撳紑锛歱ullMode === false
   *         if (!pullGeomReady) { pullGeomReady = true;    // 鈫?缃綅
   *                               expand.applyPullProgress(ui, pullT); } }
   *   PlayerPage.onPullTChanged:                          // 174826-174850
   *       if (!pullMode) return;
   *       if (!pullGeomReady) return;                      // 鈫?**鍑犱綍娌￠綈灏变笉钀藉睘鎬?*
   *       expand.applyPullProgress(ui, effT());
   * ```
   * 涓夋潯閮藉湪璇村悓涓€浠朵簨锛?*`applyPullProgress` 鍙湪缁堢偣鍑犱綍閲忓埌涔嬪悗鎵嶅厑璁告敼瀹瑰櫒鍑犱綍**銆?
   *
   * 鎴戜滑杩欒竟鐨勬柇鐐癸紙鏈疆璇诲嚭鏉ョ殑锛夛細`applyMorphProgress()` 鍦?`!morphUsable` 鏃?
   * **鎶婂鍣ㄥ啓鍥炴亽绛?*锛坄PlaybackPage:morphClipping()` 闅忎箣涓哄亣 鈬?楂樺害 `'100%'`銆?
   * 涓嶈鍓級锛岃€岀偣鍑?杩斿洖杩欐潯璺笂銆屾挱鏀鹃〉閭ｄ竴鍒昏繕娌℃寕杞姐€嶁噿 `pullOpenBegin` 閲?
   * `prepareMorphEntry` 鐨勭粓鐐归敋鐐瑰繀鐒堕噺涓嶅埌 鈬?`morphUsable === false`
   * 鈬?瀹瑰櫒**鏁存鍋滃湪鎭掔瓑** 鈬?鐢ㄦ埛鐪嬪埌鐨勬鏄€屾病鏈夊皝闈?鑳屾櫙鍔ㄧ敾銆嶃€?
   * 璺熸墜閭ｆ潯璺箣鎵€浠ュソ锛屾槸鍥犱负涓婃媺鏃舵挱鏀鹃〉宸茬粡鎸傝浇銆佺涓€鎷嶅氨閲忓埌浜嗐€?
   *
   * 鈬?淇硶 = 鎶娿€屽嚑浣曟病榻愩€嶇殑璇箟浠?鍐欏洖鎭掔瓑"鏀规垚**鏃犵晫閭ｆ牱鐨?浠€涔堥兘涓嶅仛"**锛?
   *   瀹瑰櫒淇濇寔褰撳墠鍊硷紙鍒濇 = 鎭掔瓑锛屼笌"娌℃湁杩欏鍔ㄧ敾"閫愬儚绱犱竴鑷达級锛?
   *   绛夌粓鐐归敋鐐硅ˉ閲忔垚鍔熼偅涓€甯у啀绗竴娆¤惤闈炴亽绛夊嚑浣曘€?
   */
  @Trace public morphGeomReady: boolean = false;
  /** 褰㈠彉鐢ㄧ殑瀹夸富灏哄锛坴p锛夛細鍐呭灞傜殑鍥哄畾灏哄锛屼篃鏄?閾烘弧"鐨勭洰鏍囥€?*/
  private morphBoxW: number = 0;
  private morphBoxH: number = 0;
  /**
   * `initParams` 绠楀嚭鏉ョ殑涓変釜 lerp 璧风偣锛?*閫愭潯瀵瑰簲**鍙嶇紪璇戠殑瀛楁鍚嶏級銆?
   * `applyPullProgress` 鍙湪杩欎簺鍊间笌 `t` 涓婂仛绾挎€ф彃鍊硷紝鎵€浠ュ畠浠槸褰㈠彉鐨勫叏閮ㄨ緭鍏ャ€?
   */
  private initScale: number = 1;
  private initClipHeight: number = 0;
  private initTranslateX: number = 0;
  private initTranslateY: number = 0;
  /** 璧风偣鐨?*鍙**鍦嗚 = `initClipHeight * initScale / 2`锛? 鑳跺泭楂樺害鐨勪竴鍗婏級銆?*/
  private initRadiusVisual: number = 0;

  /**
   * 褰㈠彉瀹瑰櫒鍦嗚鍦?**t = 1** 閭ｄ竴绔殑**鍙鍊?*锛坴p锛夆€斺€?鐓ф妱鏃犵晫 `doEnter` 琛ラ棿鐨?radius 绔偣銆?
   *
   * 鍑哄锛歚wujie.pa` 鐨?`ExpandAnimation.doEnter` 閲岄偅鏉′富鍑犱綍琛ラ棿锛宍radius` 绔偣鏄?`34`锛?
   * 琛ラ棿璺戝畬鐢?`位1onFinish` 鎶?`radius` **褰?0**锛堣 `morphSettleOpen()`锛夈€?
   * 鈿狅笍 瀹冧笉鏄?钀藉畾鎬佸渾瑙?锛堣惤瀹氭亽 0锛夛紝鍙槸**琛ラ棿缁堢偣**銆?
   */
  private static readonly MORPH_RADIUS_END_VP: number = 34;
  /** 杩蜂綘鏉¤兌鍥婄殑鍘熷涓婃姤鍊硷紙vp锛?*绐楀彛鍧愭爣**锛涘楂樹负 0 琛ㄧず娌￠噺鍒帮級銆?*/
  @Trace public barWinX: number = 0;
  @Trace public barWinY: number = 0;
  @Trace public barWinW: number = 0;
  @Trace public barWinH: number = 0;
  @Trace public barWinRadius: number = 0;
  /** 璧风偣锛氳糠浣犳潯閭ｆ潯鑳跺泭鐨勭煩褰紙vp锛?*瀹夸富鍧愭爣**锛岀敱 `morphInitParams` 鎹㈢畻锛夈€?*/
  private barX: number = 0;
  private barY: number = 0;
  private barW: number = 0;
  private barH: number = 0;
  private barRadius: number = 12;
  /** 璧风偣锛氳糠浣犳潯灏侀潰鐭╁舰锛坴p锛屽涓诲潗鏍囷級鈥斺€?妗ユ帴灏侀潰鐨勮捣鐐广€?*/
  private miniCoverX: number = 0;
  private miniCoverY: number = 0;
  private miniCoverSize: number = 0;
  private miniCoverRadius: number = 12;

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 缁灏侀潰锛堝弽缂栬瘧渚х殑 `snap*` 涓€鏁村绔偣锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // `initParams` 閲屽彟鏈変竴瀵圭鐐癸紙`snapStart*` / `snapEnd*`锛夛細
  //   路 璧风偣 = 杩蜂綘鏉″皝闈紙`srcRect`锛歭eft/top/width 鈫?px2vp锛?
  //   路 缁堢偣 = 鎾斁椤靛皝闈㈢殑 FrameNode锛歚getPositionToWindowWithTransform()`锛坴p锛?
  //            + `getMeasuredSize().width`锛坧x 鈫?px2vp锛?
  // 灞曞紑杩囩▼涓睆涓?灏侀潰"杩欎竴妫掑氨鏄畠锛?*绾挎€?*浠庤捣鐐规彃鍒扮粓鐐癸紙`doEnter` 閲岀洿鎺?
  // animateTo 杩欎袱涓瓧娈碉紱鎷栧姩璺緞鐢?`applyPullProgress` 涔嬪鐨勫湴鏂归┍鍔級銆?
  /** 缁灏侀潰璧风偣锛坴p锛屽涓诲潗鏍囷級涓庤捣鐐瑰渾瑙掞紙鍙嶇紪璇戜晶鐨?`snapStart*`锛夈€?*/
  private snapStartX: number = 0;
  private snapStartY: number = 0;
  private snapStartW: number = 0;
  private snapStartRadius: number = 12;
  /**
   * 鎾斁椤靛皝闈?*鑺傜偣**鐨勭獥鍙ｇ煩褰紙vp锛夛細鍙嶇紪璇戜晶 `initParams` 鐢?
   * `getFrameNodeById(targetId).getPositionToWindowWithTransform()` + `getMeasuredSize()`
   * 閲忓畠褰撶画椋炲皝闈㈢殑缁堢偣銆俙snapEnd*` 浼樺厛鐢ㄥ畠锛岄噺涓嶅埌鎵嶉€€鍥?`onAreaChange` 鐨?`big*`銆?
   */
  private bigNodeX: number = 0;
  private bigNodeY: number = 0;
  private bigNodeW: number = 0;
  /**
   * 鎾斁椤靛皝闈㈣妭鐐圭殑**瀹為檯楂樺害**锛坴p锛夈€?
   *
   * 鈿狅笍 涓嶈兘鍐嶅亣璁?灏侀潰鏄鏂瑰舰"锛坄h = w`锛夛細灏侀潰澶栭潰濂楃潃 `constraintSize(maxWidth/maxHeight 100%)`
   *    + `layoutWeight(1)` 鐨勫鍣紝瀹為檯閲忓埌鐨勭煩褰笉淇濊瘉 1:1銆傛ˉ鎺ュ皝闈㈡寜 `h = w` 钀戒綅锛?
   *    鐪熷疄灏侀潰鎸夊竷灞€钀戒綅 鈥斺€?涓よ€呭樊澶氬皯锛宲=1 浜ゆ閭ｄ竴鍒诲氨"璺?澶氬皯锛堢敤鎴峰疄娴嬬殑
   *    銆岀粨鏉熸椂灏侀潰浣嶇疆/澶у皬璺充竴涓嬨€嶏級銆?
   */
  private bigNodeH: number = 0;
  /**
   * 鎾斁椤靛皝闈㈠綋鍓嶇殑**瑙嗚缂╂斁**锛坄MusicPlayInfoBlock` 鐨勬挱鏀炬€佸脊绨э細鎾斁 1.05 / 鏆傚仠 0.95锛夈€?
   *
   * 鈿狅笍 `getPositionToWindowWithTransform()` 閲忓埌鐨勬槸**鍚 transform** 鐨勭煩褰€傚鏋滃彧鎶婂畠褰?
   *    "甯冨眬鐭╁舰 脳 1.0"瀛樹笅鏉ワ紝p=1 浜ゆ缁欑湡瀹炲皝闈紙鐪熷疄灏侀潰鏄?1.05锛夊氨浼氳烦 5%銆?
   *    鎵€浠ラ噺娴嬫椂鍏堟妸 transform 闄ゆ帀瀛?甯冨眬鐭╁舰"锛岀粯鍒舵ˉ鎺ュ皝闈㈡椂鍐嶆妸褰撳墠缂╂斁涔樺洖鍘?鈥斺€?
   *    涓ょ鐢ㄧ殑閮芥槸**瀹炴椂鍊?*锛屽脊绨ф鍦ㄥ姩鐨勬椂鍊欎篃璺熺潃鍔ㄣ€?
   */
  private bigNodeScaleX: number = 1;
  private bigNodeScaleY: number = 1;
  private bigNodeKnown: boolean = false;
  /** 鎾斁椤靛皝闈㈠渾瑙掞紙vp锛屾潵鑷?`reportBig`锛夈€?*/
  private bigCoverRadius: number = 0;
  /**
   * 杩蜂綘鏉?鍏冧俊鎭?+ 鎿嶄綔鍖?閭ｄ竴鍧楃殑绐楀彛鐭╁舰锛坴p锛夆€斺€斿厠闅嗗眰鐨勫涓荤煩褰€?
   * 鍙嶇紪璇戜晶瀵瑰簲 `miniMeta` + `morphActionsRect` 鐨勬潵婧愩€?
   */
  @Trace public asideWinX: number = 0;
  @Trace public asideWinY: number = 0;
  @Trace public asideWinW: number = 0;
  @Trace public asideWinH: number = 0;
  /** 缁灏侀潰鐨?*缁堢偣**锛坴p锛屽涓诲潗鏍囷級锛氭挱鏀鹃〉灏侀潰鑺傜偣閲忓埌鐨勭煩褰紝閲忎笉鍒板氨閫€鍥?`big*`銆?*/
  private endCoverX: number = 0;
  private endCoverY: number = 0;
  private endCoverSize: number = 0;
  /** 缁灏侀潰缁堢偣鐨?*楂樺害**锛坴p锛夛細涓?`endCoverSize` 涓€璧锋瀯鎴愯惤鐐圭煩褰紝闈炴鏂瑰舰鏃朵笉鑳藉啀褰撴柟鐨勩€?*/
  private endCoverH: number = 0;

  /**
   * 鈽呪槄鈽?2026-10-16 鏂板锛氱粰**鐜板満鑷瘉寰芥爣**锛坄PlaybackPage.DiagBadge()`锛夌敤鐨勫彧璇昏鏁般€?
   *
   * 涓轰粈涔堣蛋鏂规硶鑰屼笉鏄妸瀛楁鏀?public锛氭湰浠撴棦鏈夌殑鍋氭硶灏辨槸"绉佹湁瀛楁 + 鍏紑鍙鍏ュ彛"
   * 锛堝悓 `morphContainerActive()` / `morphClipping()` 閭ｄ竴鏃忥紝瑙?搂59 鐨勬竻鐞嗚褰曪級銆?
   * 鈿狅笍 绾彧璇伙細杩欎簺鏂规硶**涓嶅啓浠讳綍鐘舵€?*锛屼笉瑕佸湪閲岄潰鍔犲壇浣滅敤銆?
   * @returns 缁灏侀潰**璧风偣瀹藉害**锛坴p锛岃糠浣犳潯灏侀潰锛?
   */
  public snapStartWVp(): number {
    return this.snapStartW;
  }

  /** @returns 缁灏侀潰**缁堢偣瀹藉害**锛坴p锛屾挱鏀鹃〉灏侀潰锛夆€斺€?涓?0 琛ㄧず缁堢偣閿氱偣娌￠噺鍒般€?*/
  public endCoverSizeVp(): number {
    return this.endCoverSize;
  }

  /** @returns 缁灏侀潰**缁堢偣楂樺害**锛坴p锛夆€斺€?闈炴鏂瑰舰灏侀潰涓嶈兘褰撴柟鐨勭敤銆?*/
  public endCoverHVp(): number {
    return this.endCoverH;
  }

  /** @returns 褰撳墠妗ｄ綅鐨?`bottomGap`锛坴p锛夆€斺€?缁欒嚜璇佸窘鏍囨牳"搴曢儴璁╀綅涓嬮檺"鐢ㄣ€?*/
  public chromeBottomGapVp(): number {
    return this.chromeOf().bottomGap;
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鈽呪槄鈽?鐜板満鑷瘉锛?*鍔ㄤ綔杞ㄨ抗**锛堜笉渚濊禆 hdc 涔熻兘鐪嬪嚭"璋佸厛璋佸悗"锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // ## 涓轰粈涔堥渶瑕佸畠
  //
  // 銆岀偣鍑绘墦寮€ / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖娌℃湁鍔ㄧ敾銆嶈繖鏉￠摼涓婏紝**椤哄簭**鏈韩灏辨槸鑷彉閲忕殑鏈€澶у€硷細
  // 鍚屼竴涓嚱鏁板厛璋冭繕鏄悗璋冿紝缁撴灉瀹屽叏涓嶅悓锛埪?3 鐨?`onAppear` 璇垽銆伮?03 鐨?`onDisappear`
  // 璇潃锛岄兘鏄?椤哄簭"闂锛夈€傝€屽窘鏍囧師鏉ュ彧鏄剧ず**褰撳墠鍊?*锛岀湅涓嶅嚭**椤哄簭**銆?
  //
  // 鈬?鍦ㄥ叡浜姸鎬佷笂鐣欎竴鏉?*鏈€杩?6 涓姩浣?*鐨勮建杩癸紝澹冲眰涓庢挱鏀鹃〉涓よ竟閮藉線閲屽啓锛?
  //   寰芥爣鐩存帴鏄剧ず 鈬?涓€娆″氨鑳界湅鍑?璋佸厛璋佸悗銆佽皝娌℃潵"銆?
  //
  // 鈿狅笍 **缁濅笉褰卞搷琛屼负**锛氬彧鍦?`pushMorphTrace()` 閲屾嫾瀛楃涓诧紱涓嶅弬涓庝换浣曞垽鏂€?
  // 鈿狅笍 涓婇檺 6 娈碉紙姣忔鏈€澶氬崄鍑犲瓧绗︼級鈬?瀛楃涓查暱搴﹀彲鎺с€?
  @Trace public morphTrace: string = '';

  /**
   * 璁板綍涓€涓舰鍙樺姩浣滐紙鍙粰鑷瘉寰芥爣鐢級銆?
   * @param tag 鐭爣绛撅紙**淇濇寔 6 瀛楃浠ュ唴**锛屼究浜庝竴鐪兼壂杩囷級
   */
  public pushMorphTrace(tag: string): void {
    const parts: string[] = this.morphTrace.length > 0 ? this.morphTrace.split('>') : [];
    parts.push(tag);
    while (parts.length > 6) {
      parts.shift();
    }
    this.morphTrace = parts.join('>');
  }

  /**
   * 娓呯┖杞ㄨ抗锛堝湪涓€娆?*鏂扮殑鎵撳紑鍔ㄤ綔寮€濮?*鏃惰皟锛岄伩鍏嶄笌涓婁竴娆＄殑杞ㄨ抗娣峰湪涓€璧凤級銆?
   * 鈿狅笍 鍙湪"鐢ㄦ埛鍙戣捣浜嗘柊鐨勬墦寮€/鍏抽棴"杩欑被**浼氳瘽杈圭晫**涓婅皟锛屼笉瑕佸湪娓叉煋璺緞涓婅皟銆?
   */
  public resetMorphTrace(tag: string): void {
    this.morphTrace = tag;
  }

  /**
   * 璁板綍杩蜂綘鏉￠偅鏉?*鑳跺泭**鐨勭獥鍙ｇ煩褰€?
   *
   * 鐢?*瀹炴祴**锛坄measureMini`锛岃蛋 `getRectangleById`锛夎€屼笉鏄?`onAreaChange` 鐨?
   * `globalPosition`锛氬悗鑰呯粰鐨勬槸**甯冨眬**浣嶇疆锛孒DS 娴姩搴曟爮濡傛灉瀵硅兌鍥婂仛杩囧钩绉?鍋忕疆锛?
   * 閲忓嚭鏉ョ殑璧风偣灏变細鏁翠綋鍋忥紙鐢ㄦ埛瀹炴祴鍒扮殑"浠庡皝闈㈠亸宸︿笅瑙掑紑濮?灏辨槸杩欎釜锛夈€?
   * @param x 宸﹁竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級
   * @param y 涓婅竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級
   * @param w 瀹藉害锛坴p锛?
   * @param h 楂樺害锛坴p锛?
   * @param radius 鍦嗚锛坴p锛?
   */
  public reportMiniBar(x: number, y: number, w: number, h: number, radius: number): void {
    if (w <= 0 || h <= 0) {
      return;
    }
    this.barWinX = x;
    this.barWinY = y;
    this.barWinW = w;
    this.barWinH = h;
    this.barWinRadius = radius > 0 ? radius : h / 2;
  }

  /**
   * 鐢?`getRectangleById` 閲忎竴娆¤糠浣犳潯锛堣兌鍥?+ 灏侀潰锛変笌瀹夸富锛屾崲鎴?vp 瀛樿捣鏉ャ€?
   *
   * 涓轰粈涔堜笉鐢?`onAreaChange`锛氬畠缁欑殑鏄竷灞€鍑犱綍锛?*涓嶅惈绁栧厛鐨?transform**锛涜€?HDS 娴姩
   * 搴曟爮鐨勮兌鍥婁綅缃?鍦嗚涓嶆槸鎴戜滑鑳藉畬鍏ㄦ帉鎻＄殑锛岄噺閿欎竴鐐规暣娈靛姩鐢荤殑璧风偣灏卞亸銆?
   * `getRectangleById` 缁欑殑鏄?*娓叉煋鍚?*鐨勭獥鍙ｇ煩褰紙鍙ｅ緞 px锛夛紝鎹㈢畻鎴?vp 灏辨槸鎵€瑙佸嵆鎵€寰椼€?
   * @param ui UIContext锛堝彇鑷Е鍙戝姩鐢荤殑閭ｄ竴灞傦級
   * @param preferFloating true = 浼樺厛閲忎簩绾ч〉闈㈤偅鏉℃偓娴糠浣犳潯锛堝畠鍙湪浜岀骇椤甸潰鎵嶅瓨鍦紝
   *                       鎵€浠?浼樺厛 + 鎵句笉鍒板氨閫€鍥?杩欎竴鏉¤鍒欏湪涓ょ椤甸潰涓婇兘鎴愮珛锛?
   * @returns 鏄惁閲忓埌浜嗚糠浣犳潯锛堟病閲忓埌灏遍€€鍥?`onAreaChange` 鐨勫€硷級
   */
  public measureGeometry(ui: UIContext, preferFloating: boolean, force: boolean = false): boolean {
    let ok: boolean = false;
    // 鈿狅笍 瀹夸富鍙敤鏉?*鏍稿**锛堟棩蹇楅噷鎵撳嚭鏉ワ級锛屽昂瀵哥殑鍞竴鏉冨▉鏄?`reportWindow`锛堢獥鍙ｅ昂瀵革級銆?
    //    韪╄繃鐨勫潙锛氬湪褰㈠彉涓殑瀹夸富鑺傜偣涓婇噺灏哄鍠傚洖鍘?= 璁?閾烘弧鐩爣"杩界潃鑷繁鐨勪腑闂存€佽窇
    //    锛堣鍓獥鍙ｉ珮搴?鈫?鐩爣楂樺害锛岃秺璺戣秺鐭紝灞忎笂灏辨槸"涓€鍧楅粦搴曘€佹挱鏀鹃〉灞曚笉寮€"锛夈€?
    // 杩蜂綘鏉¤兌鍥婏紙浼樺厛閭ｆ潯鎸夊弬鏁板喅瀹氾紝鎵句笉鍒板氨鎹㈠彟涓€鏉★級
    const barIds: string[] = preferFloating ? [MINI_BAR_FLOATING_ID, MINI_BAR_ID] : [MINI_BAR_ID, MINI_BAR_FLOATING_ID];
    for (const id of barIds) {
      const bar: NodeRect | undefined = this.measureNode(ui, id);
      if (bar !== undefined) {
        this.metaSourceFloating = id === MINI_BAR_FLOATING_ID;
        this.reportMiniBar(bar.x, bar.y, bar.w, bar.h, bar.h / 2);
        ok = true;
        break;
      }
    }
    // 杩蜂綘鏉″皝闈紙涓庤兌鍥婂悓涓€濂椾紭鍏堥『搴忥級
    const coverIds: string[] = preferFloating ?
      [MINI_BAR_COVER_FLOATING_ID, MINI_BAR_COVER_ID] : [MINI_BAR_COVER_ID, MINI_BAR_COVER_FLOATING_ID];
    for (const id of coverIds) {
      const cover: NodeRect | undefined = this.measureNode(ui, id);
      if (cover !== undefined) {
        this.reportMini(cover.x, cover.y, cover.w, cover.w / 2);
        ok = true;
        break;
      }
    }
    // 杩蜂綘鏉?鍏冧俊鎭?+ 鎿嶄綔鍖?閭ｄ竴鍧楋紙鍏嬮殕灞傝鐢ㄥ畠鐨勭煩褰級
    // 鈿狅笍 姣忚疆璧锋墜閮?*閲嶉噺涓€娆?*锛氳繖涓搴︽槸 HDS 娴姩搴曟爮鎸夋帓甯冪畻鍑烘潵鐨勶紝
    //    鏀惰捣/鎹㈡墜/鏂偣鍙樺寲閮戒細鍙橈紱鐢ㄤ笂涓€杞殑鍐荤粨瀹藉害浼氳鍏嬮殕灞傜浉瀵圭湡韬í鍚戝亸绉汇€?
    const asideIds: string[] = preferFloating ?
      [MINI_BAR_ASIDE_FLOATING_ID, MINI_BAR_ASIDE_ID] : [MINI_BAR_ASIDE_ID, MINI_BAR_ASIDE_FLOATING_ID];
    for (const id of asideIds) {
      const aside: NodeRect | undefined = this.measureNode(ui, id);
      if (aside !== undefined) {
        this.asideWinX = aside.x;
        this.asideWinY = aside.y;
        this.asideWinW = aside.w;
        this.asideWinH = aside.h;
        break;
      }
    }
    // 鎾斁椤靛皝闈?*鑺傜偣**锛堢画椋炲皝闈㈢殑缁堢偣锛?
    // 鈿狅笍 **榛樿鍙湪"娌″湪褰㈠彉涓?鏃舵墠閲?*锛氬舰鍙樻湡闂存挱鏀鹃〉鏄缂╂斁/瑁佸壀鐨勶紝閲忓埌鐨勬槸
    //    "琚帇鎵佺殑閭ｄ竴甯?锛堝彲鑳藉彧鏈夊嚑鍗?vp锛夛紝鍐欒繘缁堢偣灏变細"澶у皬涓嶅彉鍙Щ鍔ㄤ綅缃?銆?
    //    `force = true` 鏄粰**鐐瑰嚮灞曞紑鐨勯噸璇曠獥鍙?*鐢ㄧ殑锛氶偅鏃?`morphStage` 铏界劧宸叉槸 ENTERING锛?
    //    浣嗛〉闈㈣繕娌¤鍘嬪埌璧风偣锛坄applyMorphProgress(0)` 鍙啓鐘舵€侊紝瑁佸壀绐楀彛瑕佷笅涓€甯ф墠鐢熸晥锛夛紝
    //    姝ゅ埢閲忓埌鐨勪粛鏄師灏哄 鈥斺€?杩欐鏄棤鐣?鍏堥噺鍚庣缉"瑕佺殑閭ｄ釜鍊笺€?
    //    涓婁竴鐗堟病鏈夎繖涓叆鍙ｏ紝閲嶈瘯鏈熸案杩滆ˉ涓嶅埌缁堢偣 鈬?鐐瑰嚮璺緞蹇呯劧閫€鍖栨垚鏃犲姩鐢昏惤浣嶃€?
    if (force || !this.morphLive()) {
      this.measureEndAnchor(ui);
    }
    // Measurement never acquires paint ownership. OPEN must remain TARGET-owned.
    // Closing explicitly freezes while OPEN, before beginLeaving changes any transform.
    // 瀹夸富鐭╁舰鍙繘鏃ュ織銆?
    // 鈽呪槄 2026-10-15 璁㈡锛?*鍘熷厛杩欓噷鍐欑殑鏄?`MORPH_HOST_ID` 鍦ㄦ墜鏈哄３閲屽氨鏄挱鏀鹃〉鑷繁鐨勬牴 Stack"锛?
    //    閭ｅ彞鏄敊鐨勶紝鑰屼笖瀹冭瀵艰繃涓€杞敼鍔?* 鈥斺€?瑙佷笅锛夛細
    //   `.id(MORPH_HOST_ID)` 鐨勫疄闄呯粦瀹氱偣**鍙湁涓や釜锛岄兘鍦?products 澹冲眰鐨勬牴 Stack 涓?*
    //   锛坄products/default/.../Index.ets:1796`銆乣products/pc/.../Index.ets:345`锛夛紝
    //   涓よ€呴兘**甯搁┗**锛涜€屾墜鏈鸿矾鐢辨ā寮忎笅鎾斁椤垫槸澹冲眰閲?`HdsNavigation` 鐨?*瀛愯妭鐐?*
    //   鈬?閲忓埌鐨勬槸**澹冲眰閭ｄ竴灞?*锛堟弧灞忥級锛?*涓嶆槸**鎾斁椤甸偅涓鍓獥鍙ｃ€?
    // 鈬?鎵€浠ヨ繖閲岄噺鍒扮殑 `hostNode=` 鏄?澹冲眰婊″睆鐩?锛?*瀹冧粛鐒剁粷涓嶈兘褰撻摵婊＄洰鏍?*
    //   锛堟墜鏈轰晶閾烘弧鐩爣璧?`reportWindow()`锛岃 `contentWidthVp/HeightVp` 閭ｆ锛夛紝
    //   浣?瀹冪殑楂樺害灏辨槸瑁佸壀绐楀彛楂樺害"杩欎釜鐞嗙敱**涓嶆垚绔?*锛堢湡姝ｇ殑鍘熷洜鏄埆鎷夸换浣?*鍙備笌褰㈠彉**鐨勫眰褰撶洰鏍囷級銆?
    // 鈿狅笍 **涓嶈鍦ㄦ挱鏀鹃〉閭ｄ竴灞傚啀琛?`.id(MORPH_HOST_ID)`** 鈥斺€?閭ｄ細閫犲嚭"鍚?id 涓や唤鑺傜偣"锛?
    //   鑰屾湰浠撳杩欎欢浜嬫湁鏄庣‘璁板綍锛坄MINI_BAR_ID` 閭ｄ袱澶勬敞閲婏細"閲忓埌鍝竴浠戒笉纭畾锛岃捣鐐瑰氨鎶?锛夈€?
    const host: NodeRect | undefined = this.measureNode(ui, MORPH_HOST_ID);
    const hostText: string = host !== undefined
      ? `${host.w.toFixed(1)}x${host.h.toFixed(1)}@(${host.x.toFixed(1)},${host.y.toFixed(1)})`
      : 'none';
    Logger.info(PlayerExpandState.logTag,
      `measure floating=${preferFloating} force=${force} ok=${ok} bar=(${this.barWinX.toFixed(1)},` +
      `${this.barWinY.toFixed(1)},${this.barWinW.toFixed(1)}x${this.barWinH.toFixed(1)}) cover=(${this.miniX.toFixed(1)},` +
      `${this.miniY.toFixed(1)},${this.miniSize.toFixed(1)}) bigNode=(${this.bigNodeX.toFixed(1)},` +
      `${this.bigNodeY.toFixed(1)},${this.bigNodeW.toFixed(1)}x${this.bigNodeH.toFixed(1)},` +
      `s=${this.bigNodeScaleX.toFixed(3)},known=${this.bigNodeKnown}) bigFallback=${this.bigSize.toFixed(1)} ` +
      `aside=(${this.asideWinX.toFixed(1)},${this.asideWinY.toFixed(1)},` +
      `${this.asideWinW.toFixed(1)}x${this.asideWinH.toFixed(1)}) hostNode=${hostText} ` +
      `box=${this.morphBoxWidth().toFixed(1)}x${this.morphBoxHeight().toFixed(1)}`);
    return ok;
  }

  /**
   * 鎾斁椤靛皝闈㈠綋鍓嶇殑**瑙嗚缂╂斁**锛坄MusicPlayInfoBlock` 鐨勬挱鏀炬€佸脊绨э細鎾斁 1.05 / 鏆傚仠 0.95锛夈€?
   *
   * 鐢?`MusicPlayInfoBlock` 鍐欒繘鏉ワ紙涓庡皝闈㈠悓婧愶紝鏀逛竴澶勪袱杈归兘鍙橈級锛涙病鍐欒繘鏉ユ椂鎸?1 澶勭悊
   * 鈥斺€?閭ｆ牱鏈€宸彧鏄惤浣嶆椂宸脊绨ч偅 5%锛屼笉浼氭妸绔偣绠楅銆?
   *
   * 鈿狅笍 蹇呴』鏄?`@Trace`锛氬脊绨у湪鍔ㄧ敾鏈熼棿杩樺湪鍔紝妗ユ帴灏侀潰鐨勭粓鐐硅璺熺潃瀹冮€愬抚璧帮紝
   *    鍚﹀垯 p=1 浜ゆ缁欑湡瀹炲皝闈㈢殑閭ｄ竴鍒诲氨浼氳烦涓€涓嬶紙鐢ㄦ埛瀹炴祴"缁撴潫鏃跺皝闈㈠ぇ灏忚烦涓€涓?锛夈€?
   */
  @Trace public coverScaleRaw: number = 1;

  /**
   * @returns 鏂藉姞鍦ㄦ挱鏀鹃〉灏侀潰涓婄殑**瑙嗚缂╂斁**銆?
   *
   * `bigNodeScaleX` 鏄噺娴嬮偅涓€鍒荤殑缂╂斁锛坄getPositionToWindowWithTransform()` 宸茬粡鍚畠锛夛紝
   * 杩欓噷鎶?褰撳墠 / 閲忔祴鏃?鐨勬瘮鍊间箻鍥炲幓 鈥斺€?浜庢槸"瀛樼殑鏄竷灞€鐭╁舰銆佺敾鐨勬槸褰撳墠瑙嗚鐭╁舰"銆?
   */
  private coverVisualScale(): number {
    return this.coverScaleLive();
  }

  /** 渚?`MusicPlayInfoBlock` 鎶婂皝闈笂褰撳墠鐢熸晥鐨勭缉鏀惧啓鍥炴潵銆?*/
  public setCoverScaleLive(scale: number): void {
    const s: number = scale > 0.01 ? scale : 1;
    if (Math.abs(s - this.coverScaleRaw) > 0.0005) {
      this.coverScaleRaw = s;
    }
  }

  /** @returns 灏侀潰褰撳墠瑙嗚缂╂斁锛堥粯璁や负 1锛夈€?*/
  public coverScaleLive(): number {
    return this.coverScaleRaw > 0.01 ? this.coverScaleRaw : 1;
  }

  /**
   * 褰㈠彉鐢ㄧ殑**鍐呭鍖哄昂瀵?*锛坴p锛夆€斺€?涔熷氨鏄?閾烘弧"鐨勭洰鏍囦笌缂╂斁鍒嗘瘝銆?
   *
   * 鈿狅笍 杩欐槸韪╄繃鐨勬渶澶х殑鍧戯紝浜斾釜鐢ㄦ埛鍙鐨?bug 閮藉嚭鑷繖閲岋紙鑷櫖锛屽凡韪╀簲娆★級锛?
   *   1. 鎶?`onAreaChange` 鎸傚湪**琚舰鍙樼殑閭ｅ眰瀹瑰櫒**涓婏紙閭ｅ眰鐨勯珮搴﹀氨鏄鍓獥鍙ｉ珮搴︼紝
   *      褰㈠彉鏈熼棿浠?杩蜂綘鏉″皝闈㈤偅涔堥珮"闀垮埌婊″睆锛夈€備簬鏄笂鎶ュ洖鏉ョ殑"鍐呭鍖洪珮搴?鍏跺疄鏄?
   *      **瑁佸壀楂樺害**锛屼竴娆′笂鎷変箣鍚庡畠灏辫鍐欐垚 ~360锛堚増涓€涓睆瀹斤級锛岃€屽畠鍚屾椂鍙堟槸
   *      `clipHeight` 鐨勭洰鏍囦笌缂╂斁鍒嗘瘝 鈥斺€?鑷櫖锛氱洰鏍囬珮搴﹁鑷繁鐨勪腑闂存€佽鐩栵紝
   *      涔嬪悗鎵€鏈夊睍寮€閮藉彧鑳介暱鍒?360vp锛?搴曢儴缂轰竴鍧?/"涓€鍧楄繎姝ｆ柟褰㈢殑鑳屾櫙"锛夈€?
   *   2. 鎵嬫満渚?`PlaybackPage` 鑷繁鐨勬牴 Stack 涓婁篃鏈?`.height(morphClipHeight())`
   *      鈥斺€?**鍚屼竴涓潙鎹簡涓綅缃張韪╀竴娆?*锛堛€屼竴鍧楅粦搴?+ 鎾斁椤靛睍涓嶅紑銆嶏級銆?
   *      鈽?2026-10-15 璁㈡锛氳繖閲屽師鏉ュ啓鐨勬槸"鎵嬫満渚?`PlaybackPage` 鑷繁鐨勬牴 Stack **灏辨槸**
   *      `MORPH_HOST_ID`" 鈥斺€?**閭ｅ彞鏄敊鐨?*锛歚MORPH_HOST_ID` 鐨勫疄闄呯粦瀹氱偣鍙湁涓や釜锛?
   *      閮藉湪 products 澹冲眰鐨勬牴 Stack 涓婏紙甯搁┗锛夛紝鎾斁椤甸偅涓€灞?*浠庢潵娌℃湁鎸傝繃**瀹冦€?
   *      浣?*鏁欒涓嶅彉銆佽€屼笖鏇磋创鍒?*锛氱湡姝ｇ殑闂涓嶆槸"瀹冨彨浠€涔?id"锛岃€屾槸
   *      **浠讳綍鍙備笌褰㈠彉鐨勫眰閮戒笉鑳藉綋"閾烘弧鐩爣"** 鈥斺€?鎾斁椤垫牴 Stack 鐨勯珮搴︽槸**瑁佸壀绐楀彛楂樺害**锛?
   *      涓嶇瀹冩寕涓嶆寕閭ｄ釜 id锛屾妸瀹冨杺鍥?`reportHost()` 閮戒細鑷櫖銆?
   *   鈬?**鍞竴鏉冨▉ = 绐楀彛灏哄**锛氱敱 {@link reportWindow} 浠?`windowSize` 鍐欏叆銆?
   *     鍙備笌褰㈠彉鐨勪换浣曡妭鐐归兘涓嶈鍐欒繖涓や釜瀛楁銆?
   */
  @Trace public contentWidthVp: number = 0;
  @Trace public contentHeightVp: number = 0;

  /**
   * 璁板綍瀹夸富鐨?*灏哄**锛圥C 澹冲眰鐢細閭ｅ眰鐨勬牴瀹瑰櫒鎭掍负婊″睆銆佷笉鍙備笌褰㈠彉锛夈€?
   *
   * 鈿狅笍 鎵嬫満澹冲眰涓嶈璋冨畠 鈥斺€?鎵嬫満渚х殑 `MORPH_HOST_ID` 灏辨槸鎾斁椤佃嚜宸辩殑鏍瑰鍣紝
   *    瀹冪殑楂樺害鏄?*瑁佸壀绐楀彛楂樺害**锛屽杺鍥炴潵浼氳嚜鍣紙绗簲娆★級銆傛墜鏈轰晶鐨勫昂瀵告潵婧愭槸
   *    {@link reportWindow}锛堢獥鍙ｅ昂瀵革級銆?
   * @param widthVp 瀹藉害锛坴p锛?
   * @param heightVp 楂樺害锛坴p锛?
   */
  public reportHost(widthVp: number, heightVp: number): void {
    if (widthVp > 0) {
      this.contentWidthVp = widthVp;
    }
    if (heightVp > 0) {
      this.contentHeightVp = heightVp;
    }
    // 鈽?璺熸墜闃舵瀹夸富鎵嶉噺鍒板昂瀵革紙鎾斁椤垫槸涓婃媺璧锋墜涔嬪悗鎵嶆寕杞界殑锛宍morphBeginEntering()`
    //   褰撴椂鍙兘鎷夸笂涓€娆＄殑灏哄/绐楀彛榛樿鍊肩畻锛夛細杩欓噷绔嬪埢閲嶇畻涓€閬嶅嚑浣曞苟鎸夊綋鍓嶈繘搴﹂噸钀藉睘鎬э紝
    //   鍏嶅緱"閾烘弧"鐨勭洰鏍囬珮搴﹀樊鐫€鐘舵€佹爮閭ｅ嚑鍗?vp锛屾敹灏炬椂鐪嬪緱鍑烘潵璺充竴涓嬨€?
    //   鍙湪**鎵嬫寚椹卞姩**鏃跺仛锛氬姩鐢婚┍鍔ㄤ腑鏀圭洰鏍囦細璁╄ˉ闂翠腑閫旀敼閬撱€?
    if (this.morphStage === MorphStage.ENTERING && this.morphDrive === MorphDrive.FINGER &&
      this.bigNodeKnown) {
      if (this.morphInitParams()) {
        this.applyMorphProgress(this.morphP);
      }
    }
  }

  /** @returns 褰㈠彉鐢ㄧ殑鍐呭鍖哄昂瀵革細浼樺厛瀹炴祴锛屽厹搴曠敤绐楀彛灏哄銆?*/
  private morphBoxWidth(): number {
    return this.contentWidthVp > 0 ? this.contentWidthVp : this.windowWidthVp;
  }

  private morphBoxHeight(): number {
    return this.contentHeightVp > 0 ? this.contentHeightVp : this.windowHeightVp;
  }

  /**
   * 鐢ㄥ疄娴嬪嚑浣曠畻褰㈠彉鐨勪袱涓鐐广€?
   *
   * ## 鈽?鍧愭爣鍙ｅ緞锛氬叏閾?*缁熶竴绐楀彛鍧愭爣**锛?026-09-25 浜屾淇锛?
   *
   * 璧风偣鐨?`barWin*` / `mini*`銆佺粓鐐圭殑 `bigNode*` / `big*` 鍏ㄩ儴鏉ヨ嚜
   * `getPositionToWindowWithTransform()` 鎴?`Area.globalPosition`锛?*閮芥槸绐楀彛鍧愭爣**锛?
   * 鑰屽３灞傚厠闅嗗眰鐢ㄧ殑鏄?`.position({ x: asideWinX, y: asideWinY })` 鈥斺€?鐩存帴钀藉湪
   * 鎾斁椤甸偅涓弧灞?Stack 閲岋紝**涔熸槸绐楀彛鍧愭爣**銆?
   *
   * 鎵€浠ヨ繖閲?*涓嶅啀鍋氫换浣?鍑忓涓诲師鐐?鐨勬崲绠?*銆傚師鏉ラ偅濂楋紙鍏堝噺 origin銆佸厠闅嗗眰鍗翠笉鍑忥級
   * 鏄?璧风偣/鎸夐挳鏁翠綋鍋忎竴涓?origin"鐨勬牴鍥狅細鍙 `originY 鈮?0`锛堥〉闈㈤伩璁╃姸鎬佹爮鏃跺氨涓嶆槸 0锛夛紝
   * 鍏嬮殕灞傚氨鐩稿鐪熻韩鏁翠綋閿欎綅锛岃€屽舰鍙樺鍣ㄦ寜鎵ｆ帀鍘熺偣鐨勫潗鏍囪蛋 鈥斺€?涓よ竟瀵逛笉涓娿€?
   * 鍧愭爣鍙ｅ緞**鍙厑璁告湁涓€涓?*锛氱獥鍙ｅ潗鏍囥€?
   *
   * 璧风偣 = 杩蜂綘鏉￠偅鏉?*鑳跺泭**锛坄barWin*`锛? 鑳跺泭閲岀殑**灏侀潰**锛坄mini*`锛夛紱
   * 缁堢偣 = 鎾斁椤靛皝闈紙`bigNode*`锛岄噺涓嶅埌閫€鍥?`big*`锛夈€?
   * 娌℃湁瀹炴祴鍊兼椂杩斿洖 false锛岃皟鐢ㄦ柟搴旀斁寮冨舰鍙樸€佺洿鎺ラ摵婊★紙瀹佸彲娌″姩鐢讳篃涓嶈兘閿欎綅锛夈€?
   * @returns 鍑犱綍鏄惁榻愬
   */
  public morphInitParams(): boolean {
    const boxW: number = this.morphBoxWidth();
    const boxH: number = this.morphBoxHeight();
    if (boxW <= 0 || boxH <= 0) {
      this.morphUsable = false;
      Logger.error(PlayerExpandState.logTag,
        `morph init FAIL: box ${boxW.toFixed(1)}x${boxH.toFixed(1)} ` +
        `(contentW=${this.contentWidthVp.toFixed(1)} winW=${this.windowWidthVp.toFixed(1)})`);
      return false;
    }
    // 璧风偣鐭╁舰锛氫紭鍏堢敤杩蜂綘鏉¤兌鍥婄殑瀹炴祴鍊硷紱娌￠噺鍒板氨鎸?灏侀潰 + 涓€鍦堝唴杈硅窛"浼扮畻锛?
    // 淇濊瘉浠讳綍鎯呭喌涓嬮兘鏈変竴鏉?浠庤糠浣犳潯閭ｉ噷闀垮嚭鏉?鐨勫姩鐢伙紝鑰屼笉鏄共鑴嗘病鏈夊姩鐢汇€?
    // 涓嬮潰鎵€鏈夊€奸兘鏄?*绐楀彛鍧愭爣**锛堜笌閲忔祴銆佷笌鍏嬮殕灞傜殑 `.position()` 鍚屼竴鍙ｅ緞锛夈€?
    const fallbackBarW: number = this.miniSize > 0 ? this.miniSize * 7.6 : boxW * 0.9;
    const fallbackBarH: number = this.miniSize > 0 ? this.miniSize + 12 : 56;
    const barW: number = this.barWinW > 0 ? this.barWinW : fallbackBarW;
    const barH: number = this.barWinH > 0 ? this.barWinH : fallbackBarH;
    if (barW <= 0 || barH <= 0 || boxH <= barH) {
      this.morphUsable = false;
      Logger.error(PlayerExpandState.logTag,
        `morph init FAIL: bar ${barW.toFixed(1)}x${barH.toFixed(1)} boxH=${boxH.toFixed(1)}`);
      return false;
    }
    if (this.barWinW > 0) {
      this.barX = this.barWinX;
      this.barY = this.barWinY;
      this.barRadius = this.barWinRadius > 0 ? this.barWinRadius : barH / 2;
    } else {
      // 鍙噺鍒板皝闈細鑳跺泭鎸?灏侀潰宸﹁竟鐣?12銆佷笂涓嬪眳涓?鎺ㄥ嚭鏉?
      this.barX = this.miniX - 12;
      this.barY = this.miniY - (barH - this.miniSize) / 2;
      this.barRadius = barH / 2;
    }
    this.barW = barW;
    this.barH = barH;
    // 灏侀潰鐭╁舰锛堢画椋炲皝闈㈢殑璧风偣锛?
    if (this.miniSize > 0) {
      this.miniCoverX = this.miniX;
      this.miniCoverY = this.miniY;
      this.miniCoverSize = this.miniSize;
      this.miniCoverRadius = this.miniRadius > 0 ? this.miniRadius : this.miniSize / 2;
    } else {
      // 杩炲皝闈㈤兘娌￠噺鍒帮細閫€鍥炶兌鍥婂乏渚х殑涓€灏忓潡锛堣嚦灏戝姩鐢荤殑璧风偣杩樺湪杩蜂綘鏉′笂锛?
      const side: number = barH * 0.79;
      this.miniCoverX = this.barX + (barH - side) / 2;
      this.miniCoverY = this.barY + (barH - side) / 2;
      this.miniCoverSize = side;
      this.miniCoverRadius = side / 2;
    }
    // 缁灏侀潰鐨?*璧风偣**锛堝弽缂栬瘧渚х殑 snapStart锛夛細杩蜂綘鏉″皝闈紝宸茬粡绠楀ソ浜?
    this.snapStartX = this.miniCoverX;
    this.snapStartY = this.miniCoverY;
    this.snapStartW = this.miniCoverSize;
    this.snapStartRadius = this.miniCoverRadius;
    // 缁灏侀潰鐨?*缁堢偣**锛氫紭鍏堢敤 FrameNode 閲忓埌鐨勬挱鏀鹃〉灏侀潰锛堝弽缂栬瘧 `snapEnd*`锛夛紝
    // 閲忎笉鍒板氨閫€鍥?`onAreaChange` 涓婃姤鐨?`big*`锛堢涓€娆″睍寮€鏃跺彧鑳介潬瀹冿級
    this.endCoverX = this.bigNodeKnown ? this.bigNodeX : this.bigX;
    this.endCoverY = this.bigNodeKnown ? this.bigNodeY : this.bigY;
    this.endCoverSize = this.bigNodeKnown && this.bigNodeW > 0 ? this.bigNodeW : this.bigSize;
    // 鈿狅笍 楂樺害**涓嶈兘**鍐嶅綋姝ｆ柟褰紙`h = size`锛夛細鐪熷疄灏侀潰澶栨湁 `layoutWeight` + `constraintSize`锛?
    //    閲忓埌鐨勭煩褰㈡湭蹇?1:1銆傞噺涓嶅埌灏遍€€鍥炴鏂瑰舰锛堟棫琛屼负锛夛紝閲忓埌浜嗗氨鐢ㄧ湡瀹為珮搴︺€?
    this.endCoverH = this.bigNodeKnown && this.bigNodeH > 0
      ? this.bigNodeH
      : this.endCoverSize;
    this.morphBoxW = boxW;
    this.morphBoxH = boxH;
    // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ `initParams` 鐨勪笁涓?lerp 璧风偣锛堥€愭潯鐓ф妱鍙嶇紪璇戯級鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    //   initScale      = box.width / 鐩掑
    //   scaledH        = box.height / initScale
    //   initClipHeight = scaledH
    //   initTranslateX = box.left - (鐩掑 - box.width) / 2
    //   initTranslateY = box.top  - scaledH * (1 - initScale) / 2
    //   initRadiusVisual = initClipHeight * initScale / 2  锛? 鑳跺泭楂樺害鐨勪竴鍗婏級
    // 娉細鍙嶇紪璇戦噷 `fullClipHeight = px2vp(windowHeight_px)`锛堟暣绐楅珮锛夛紱鎴戜滑杩欓噷鏄?
    //     `boxH`锛堝涓婚珮搴︼級锛屽洜涓烘挱鏀鹃〉鏄?*宓屽湪椤甸潰閲?*鐨勬诞灞傝€屼笉鏄獥鍙ｇ骇娴眰锛?
    //     鐢ㄦ暣绐楅珮浼氬湪 t=1 鏃舵瘮瀹夸富楂樺嚭涓€鎴€佽鐖跺眰瑁佹帀銆?
    this.initScale = barW / boxW;
    const scaledH: number = barH / this.initScale;
    this.initClipHeight = scaledH;
    this.initTranslateX = this.barX - (boxW - barW) / 2;
    this.initTranslateY = this.barY - scaledH * (1 - this.initScale) / 2;
    this.initRadiusVisual = scaledH * this.initScale / 2;
    this.morphUsable = true;
    // 褰㈠彉鍑犱綍鏄?鐪嬩笉瑙佷絾閿欎簡灏卞叏閿?鐨勯偅绫诲弬鏁帮細鎶婅繖涓€浠芥墦鍒版棩蹇楅噷锛?
    // 鍑洪棶棰樻椂 `hdc shell hilog | grep RzdMorph` 涓€鐪煎氨鑳界湅鍑烘槸鍝竴椤归噺姝簡銆?
    Logger.info(PlayerExpandState.logTag,
      `morph init box=${boxW.toFixed(1)}x${boxH.toFixed(1)} bar=(${this.barX.toFixed(1)},` +
      `${this.barY.toFixed(1)},${barW.toFixed(1)}x${barH.toFixed(1)}) r=${this.barRadius.toFixed(1)} ` +
      `cover=(${this.miniCoverX.toFixed(1)},${this.miniCoverY.toFixed(1)},` +
      `${this.miniCoverSize.toFixed(1)}) end=(${this.endCoverX.toFixed(1)},${this.endCoverY.toFixed(1)},` +
      `${this.endCoverSize.toFixed(1)}x${this.endCoverH.toFixed(1)},src=${this.endAnchorSource()}) ` +
      `initScale=${this.initScale.toFixed(4)} ` +
      `initClipH=${this.initClipHeight.toFixed(1)} initTx=${this.initTranslateX.toFixed(1)} ` +
      `initTy=${this.initTranslateY.toFixed(1)} initR=${this.initRadiusVisual.toFixed(1)}`);
    return true;
  }

  /** @returns 缁堢偣閿氱偣锛堟挱鏀鹃〉澶у皝闈級鏄惁鏈変竴浠藉彲鐢ㄥ€硷紙FrameNode 閲忓埌锛屾垨 onAreaChange 鍏滃簳锛夈€?*/
  private endAnchorKnown(): boolean {
    return (this.bigNodeKnown && this.bigNodeW > 0) || this.bigSize > 0;
  }

  /**
   * @returns 缁堢偣閿氱偣鏄惁宸插氨缁紙缁欒皟鐢ㄦ柟鍒?杩樿涓嶈缁х画琛ラ噺"鐢級銆?
   *
   * 鈿狅笍 **涓嶈**鐢?`morphUsable` 浠ｆ浛瀹冿細`morphUsable` 浼氬洜涓?閫€鍥?`onAreaChange` 鍏滃簳鍊?
   * 锛堢敋鑷?涓婁竴杞暀涓嬬殑鍊?锛夎€屼负鐪燂紝鐢ㄥ畠褰?杩樿涓嶈琛ラ噺"鐨勫垽鎹細璁╄ˉ閲忛摼**鎻愬墠鏀跺伐**
   * 鈥斺€?閭ｆ鏄偣鍑绘墦寮€鏃?`morphGeomReady` 姘歌繙鏄亣鐨勫師鍥犱箣涓€銆?
   * 鐪熸鐨?鍙互钀戒綅"鍒ゆ嵁鏄?{@link morphGeomReadyNow}銆?
   */
  public morphEndAnchorReady(): boolean {
    return this.endAnchorKnown();
  }

  /** @returns 缁堢偣鐨勬潵婧愶紙鍙粰鏃ュ織鐢細鍖哄垎 FrameNode 閲忓埌 / onAreaChange 鍏滃簳 / 閮芥病鏈夛級銆?*/
  private endAnchorSource(): string {
    if (this.bigNodeKnown && this.bigNodeW > 0) {
      return 'frameNode';
    }
    if (this.bigSize > 0) {
      return 'areaChange';
    }
    return 'none';
  }

  /**
   * @returns 涓ょ鐨勫嚑浣曟槸鍚﹂兘閲忓埌浜嗭紙鍙互璧板舰鍙樿矾寰勶級銆?
   *
   * 鈽呪槄 2026-10-15锛?*宸插垽瀹氫负姝讳唬鐮?*锛宍RzdMusic璁板繂.md` 搂60锛夛細**闆惰皟鐢ㄨ€?*銆?
   *   瀹冭姹?`bigSize > 0`锛堥偅鏄?`reportBig` **涓婃姤鍊?*锛夛紝鑰屾椿鐨勫垽鎹槸
   *   {@link morphIntroAnchorsReady}锛?*鍚屾椂鎺ュ彈** `bigNodeKnown`锛團rameNode 閲忓埌鐨勶紝鏈€鍑嗭級
   *   涓?`bigSize`锛堜笂鎶ュ厹搴曪級锛屽苟涓旇繕瑕佹眰 `morphUsable && endCoverSize > 0`銆?
   *   鈬?鏈嚱鏁版槸閭ｆ潯鍒ゆ嵁**鏇存棭銆佹洿寮?*鐨勭増鏈細鐪熸帴涓婂畠浼氳"FrameNode 閲忓埌浜嗕絾 areaChange
   *     杩樻病涓婃姤"閭ｄ竴甯ц璇垽鎴?鍑犱綍娌￠綈" 鈬?鐐瑰嚮鎵撳紑閫€鍖栨垚鏃犲姩鐢昏惤浣嶏紙搂56.15 淇繃鐨勯偅涓潙锛夈€?
   * @deprecated 闆惰皟鐢ㄨ€呫€傚垽鎹鐢?{@link morphIntroAnchorsReady}銆?
   * 澶嶆牳鍛戒护锛歚grep -rn 'morphReady(' RzdMusic --include=*.ets`锛堟湡鏈涳細鍙湁鏈瀹氫箟锛?
   */
  public morphReady(): boolean {
    return this.miniSize > 0 && this.bigSize > 0 && this.morphBoxWidth() > 0 && this.morphBoxHeight() > 0;
  }

  /** @returns 褰㈠彉绐楀彛褰撳墠鏄惁鏈夋晥锛堥潤姝㈡€?false锛岃皟鐢ㄦ柟璇ョ敤 `'100%'`锛夈€?*/
  public morphClipping(): boolean {
    return this.morphUsable && this.morphContainerActive();
  }

  /**
   * @returns 瀹夸富锛? 鍐呭灞傚浐瀹氬昂瀵革級瀹藉害锛坴p锛夈€?
   * @deprecated 闆惰皟鐢ㄨ€咃紙`RzdMusic璁板繂.md` 搂59锛夈€傚涓诲昂瀵稿湪**鍐呴儴**鐢?`morphBoxWidth()`
   *   鐩村彇锛涘澶栨病鏈夋秷璐硅€呫€傚鏍革細`grep -rn 'morphHostW' RzdMusic --include=*.ets`
   */
  public morphHostW(): number {
    return this.morphBoxW > 0 ? this.morphBoxW : this.morphBoxWidth();
  }

  /**
   * @returns 瀹夸富锛? 鍐呭灞傚浐瀹氬昂瀵革級楂樺害锛坴p锛夈€?
   * @deprecated 闆惰皟鐢ㄨ€咃紙鍚?{@link morphHostW}锛夈€?
   */
  public morphHostH(): number {
    return this.morphBoxH > 0 ? this.morphBoxH : this.morphBoxHeight();
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 璺熸墜鎵撳紑锛氫袱鏉℃墜鍔垮叡鐢ㄥ悓涓€濂楅┍鍔?鏀跺熬 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // 瑙︽懜鍙兘钀藉湪**杩蜂綘鏉¤嚜宸?*锛堝畠鐨勬墜鍔匡級鎴?*澹冲眰鏍硅妭鐐?*锛堝彟涓€鏉℃墜鍔匡級涓婏紝
  // 璋佹帴鍒拌皝椹卞姩锛涗絾鍑犱綍鍙湁涓€浠姐€佹敹灏捐ˉ闂村彧鏈変竴澶勶紙澹冲眰锛屽洜涓哄畠鎷ユ湁 `isShowPlay`锛夈€?

  /**
   * 鈽?**褰㈠彉璧锋墜鐨勫敮涓€姝ｇ‘椤哄簭**锛堢偣鍑讳笌璺熸墜涓ゆ潯璺兘璧板畠锛夛細
   * ```
   *   1. invalidateEndAnchor()  鈥斺€?鎶婁笂涓€杞殑缁堢偣浣滃簾锛堢粓鐐规槸"褰撳墠"鐭╁舰锛屼笉鑳芥部鐢級
   *   2. measureGeometry()      鈥斺€?**姝ゅ埢鎾斁椤佃繕鏄師灏哄**锛岄噺鍒扮殑鏄共鍑€鐨勫師灏哄鐭╁舰
   *   3. morphBeginEntering()   鈥斺€?鍐嶆妸绐楀彛鍘嬪埌璧风偣锛坧 = 0锛?
   * ```
   * 椤哄簭鍙嶄簡灏辨槸涓婁竴鐗堢殑 bug锛氬厛鍘嬭捣鐐瑰啀閲?鈫?閲忓埌鍘嬫墎甯э紱鎴栬€呴噺瀹屽張琚?
   * `morphBeginEntering` 鎶规帀 鈫?缁堢偣姘歌繙琛ヤ笉鍥炴潵 鈫?鐐瑰嚮璺緞閫€鍖栨垚鏃犲姩鐢昏惤浣嶃€?
   *
   * 鈿狅笍 宸茬粡鍦ㄦ湰杞細璇濋噷锛坄morphSessionStarted`锛夊氨涓嶈閲嶅绗?1 姝ワ細
   *    閲嶈瘯鏈熼棿瑕佷繚浣忓凡缁忛噺鍒扮殑缁堢偣銆?
   * @param ui UIContext
   * @param preferFloating 瑙?{@link measureGeometry}
   * @returns 褰㈠彉鍑犱綍鏄惁鍙敤
   */
  public prepareMorphEntry(ui: UIContext, preferFloating: boolean): boolean {
    if (!this.morphSessionStarted) {
      this.invalidateEndAnchor();
      // 鈽呪槄鈽?2026-10-17锛?*浼氳瘽璧风偣蹇呴』鏀炬帀"涓婁竴娆℃槸蹇収鏀剁缉"鐨勬墍鏈夋潈**锛?
      //   瀹冨湪 `PlaybackPage.closeWithAnimation()` 鐨勫揩鐓ф垚鍔熸敮琚疆鐪燂紙閭ｄ竴鍏虫诞灞備笉鐢诲皝闈級銆?
      //   姝ｅ父鐢?`morphReset()` 娓咃紝浣嗛偅涓竻鐐瑰甫闂紙"浼氳瘽杩樻椿鐫€灏变笉娓?锛夆噿 涓囦竴鏌愭鍏抽棴娌¤蛋鍒?
      //   reset锛岃繖涓爣璁颁細娈嬬暀 鈬?**涓嬩竴娆℃墦寮€鐨勭画椋炲皝闈㈡暣涓笉鐢?*锛堟瘮"涓ゅ紶灏侀潰"鏇翠弗閲嶏級銆?
      //   鈬?鍦?*姣忎竴娆℃墦寮€**鐨勪細璇濊捣鐐规棤鏉′欢鏀炬帀锛堝箓绛夛級銆?
      this.snapshotShrinkOwned = false;
      // 鈽呪槄鈽?2026-10-16锛?*鏂颁細璇濆繀椤绘妸"閿氱偣鐢ㄩ噺"涔熸竻闆?*锛夛細
      //   `bigSize` 鏄?`MusicPlayInfoBlock.reportBig()`锛坄onAreaChange`锛変笂鎶ョ殑**璺ㄤ細璇濇畫鐣欏瓧娈?*
      //   鈥斺€?`morphReset()` 涓嶆竻瀹冦€備簬鏄?缁堢偣閿氱偣鏄惁閲忓埌"锛坄morphEndAnchorReady()`锛夊湪
      //   鏂颁竴杞殑**绗竴鎷?*灏变細璇诲埌**涓婁竴杞?*鐨勫€?鈬?琛ラ噺閾句互涓哄凡缁忓氨缁?鈬?鎻愬墠鏀跺伐
      //   鈬?`morphGeomReady` 姘歌繙鏄亣 鈬?瀹瑰櫒鎭掔瓑 鈬?鐐瑰嚮鎵撳紑娌℃湁鍔ㄧ敾銆?
      //   鏃犵晫渚ф病鏈夎繖涓棶棰橈紙瀹冪殑 `ExpandSnapshot.playerCoverRect` 姣忚疆鐢辨挱鏀鹃〉**閲嶆柊涓婃姤**锛夛紝
      //   鎵€浠ヨ繖閲屽彧闇€鍦ㄤ細璇濊竟鐣屾妸"杩欎竴娆￠噺鍒扮殑"娓呴浂鍗冲彲銆?
      this.bigSize = 0;
      this.morphSessionStarted = true;
    }
    // 绛夊緟甯冨眬鏈熼棿淇濇寔鍘熷昂瀵搞€備笉鑳藉厛鍘嬪埌 p=0 鍐嶈法甯цˉ閲忥細涓嬩竴甯у凡缁忔槸缂╁皬甯冨眬銆?
    this.measureGeometry(ui, preferFloating, true);
    this.morphInitParams();
    if (!this.bigNodeKnown || !this.morphIntroAnchorsReady()) {
      Logger.info(PlayerExpandState.logTag, 'entry pending: keep full-size layout until end anchor ready');
      return false;
    }
    this.freezeMorphMeta(ui);
    return this.morphBeginEntering();
  }

  /** 鏈褰㈠彉浼氳瘽鏄惁宸茬粡寮€濮嬭繃锛堣 {@link prepareMorphEntry} 鐨勭 1 姝ワ級銆?*/
  @Trace public morphSessionStarted: boolean = false;

  /**
   * 鎵嬫寚璺熸墜鎵撳紑锛氳捣鎵?鈥斺€?閲忓嚑浣?+ 鎶婄獥鍙ｅ帇鍒拌捣鐐癸紝骞舵爣璁?鎵嬫寚姝ｅ湪椹卞姩"銆?
   *
   * 鈿狅笍 `pullDragging` **蹇呴』鍦ㄩ噺娴嬩箣鍓?*缃綅锛氶噸璇曟湡闂存挱鏀鹃〉閭ｈ竟瑕侀潬瀹冩斁琛岀粯鍒?
   *    锛堣 `PlaybackPage.morphOpacityValue`锛夆€斺€?椤哄簭鍙嶄簡浼氬嚭鐜?鎵嬫寚宸茬粡鎸変綇銆?
   *    鎾斁椤佃繕鏄叏閫忔槑"鐨勯偅涓€涓ゅ抚銆?
   * @param ui UIContext锛堝彇鑷帴鍒版墜鍔跨殑閭ｄ竴灞傦級
   * @param preferFloating 瑙?{@link measureGeometry}
   * @returns 鍑犱綍鏄惁鍙敤锛坒alse 鏃惰皟鐢ㄦ柟搴旂洿鎺ラ摵婊★紝鍒‖鍋氬舰鍙橈級
   */
  public pullOpenBegin(ui: UIContext, preferFloating: boolean): boolean {
    this.pullDragging = true;
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫锛氳繘鍏?涓嬫媺妯″紡"** 鈥斺€?`MainPage.pullMode`锛?
    //   鏃犵晫鑳屾櫙灞傜殑涓嶉€忔槑搴︽槸鍒嗕袱濂楀彇鍊肩殑锛坄wujie.pa:192161-192176`锛夛細
    // ```
    //   __Common__().opacity(pullMode ? pullBgOpacity() : expand.contentOpacity)
    // ```
    //   鈬?**涓嬫媺閭ｆ潯**鎵嶈蛋 `pullBgOpacity`锛? `PULL_BG_FLOOR + pullBgIn脳0.96`锛夛紱
    //     鍏朵綑鎵€鏈夊叆鍙ｏ紙鐐瑰嚮鎵撳紑 / 鍏抽棴 / 绯荤粺杩斿洖锛夎蛋 **`expand.contentOpacity`**銆?
    //   鎴戜滑涔嬪墠鎶婁袱鏉¤矾閮芥寜 `pullBgOpacity` 绠?鈬?琛ラ棿璺紙`morphP` 琚竴娆℃€у啓鎴?0锛?
    //   涓嶉€忔槑搴︾洿鎺ユ帀鍒?0.04 鈬?鐢ㄦ埛鐪嬪埌鐨?灞曞紑涓€鐩撮粦 / 鍏抽棴榛?灏辨槸瀹冦€?
    //   鏈瓧娈靛彧鏈変袱澶勫啓锛?*杩欓噷缃湡**銆乣morphReset()` 缃亣銆?
    this.pullMode = true;
    // 璁颁笅璧锋墜鏃跺埢锛氭畫鐣欐爣璁伴潬瀹冨垽瀹氳繃鏈燂紙瑙?`pullStartedAtMs` 鐨勮鏄庯級
    this.pullStartedAtMs = Date.now();
    const ready: boolean = this.prepareMorphEntry(ui, preferFloating);
    if (!ready) {
      this.morphGen = this.morphGen + 1;
      this.morphStage = MorphStage.ENTERING;
      this.morphDrive = MorphDrive.FINGER;
      this.morphUsable = false;
      this.morphP = 0;
      // 内容时间线同步落起点（静止态两条线必须一致；见 contentP 的说明）。
      this.contentP = 0;
      // 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫"杩涚浉浣嶆椂灏辫惤璧风偣鍑犱綍"** 鈥斺€?淇?鐐瑰嚮鎵撳紑棣栧抚闂竴鏁村睆"锛夛細
      //
      // ## 鏃犵晫鏄€庝箞鍋氱殑
      // ```
      //   beginMorphEnter(src)                              wujie.pa 146495
      //       setMorph(ENTERING, FINGER)                    // 鈶?杩涚浉浣?
      //       pushPath({name, param:{pull:true}})           // 鈶?鎺ㄨ矾鐢?
      //   鈥︽挱鏀鹃〉鎸傝浇銆乸ublishMorphTargets 閲忓埌缁堢偣鈥?
      //       pullGeomReady = true
      //       expand.applyPullProgress(ui, pullT)           // 鈶?绗竴娆″氨钀?**pullT = 0** 鐨勫嚑浣?
      //                                                     //    锛? 杩蜂綘鏉￠偅涓€灏忓潡锛屼笉鏄亽绛夛紒锛?
      // ```
      //   鈬?鏃犵晫鐨?`pullVisibleRect` **浠庣涓€甯ц捣灏辨案杩滄槸閭ｄ釜灏忕煩褰?*锛屼粠涓嶇瓑浜庢亽绛夈€?
      //
      // ## 鎴戜滑鍘熸潵鐨勬牱瀛愶紙杩欏氨鏄?鐐逛簡浼氶棯涓€涓嬪叏灞?鐨勬潵婧愶級
      //   `prepareMorphEntry` 鍦ㄧ粓鐐归敋鐐圭己澶辨椂**鎻愬墠 return false**锛屼簬鏄?
      //   `morphBeginEntering()` 鈫?`applyMorphProgress(0)` **鏍规湰娌¤窇鍒?*
      //   鈬?瀹瑰櫒鍋滃湪**鎭掔瓑**锛堟暣灞忥級鈬?鎾斁椤垫寕杞介偅涓€鍒诲氨鏄?涓€鏁村睆鎾斁椤?锛?
      //     瑕佺瓑 32ms 鍚庤ˉ閲忔垚鍔熸墠"鍟?鍦扮缉鍒拌糠浣犳潯鍐嶅線鍓嶉暱 鈥斺€?瑙傛劅鏄?*闂竴甯у叏灞忓啀鏀跺洖鍘?*銆?
      //
      // ## 鏀规硶锛堝垽鎹彇鑷洿鏃╃殑浜嬪疄锛?
      //   璧风偣鍑犱綍锛堣糠浣犳潯鑳跺泭 + 瀹夸富灏哄锛夊湪**杩欎竴鍒绘槸閲忓緱鍒扮殑**锛坄morphInitParams()` 宸茬粡鎴愬姛杩囷級锛?
      //   鍙湁**缁堢偣**閲忎笉鍒?鈬?閭ｅ氨鍏堟寜缁堢偣缂哄け鎶?*璧风偣鍑犱綍**钀戒笅鍘伙細
      //   `applyMorphProgress(0)` 鍙渶瑕?`initScale/initTranslate*/initClipHeight`锛?
      //   瀹冧滑鍏ㄩ儴鐢?`morphInitParams()` 濉ソ 鈥斺€?**涓嶉渶瑕佺粓鐐?*銆?
      //   鈿狅笍 `morphUsable` 浠嶄繚鎸?false锛氭洿鏂板畠鐨勬槸鐪熸鐨勮ˉ閲忥紙`measureMiniDuringPull`锛夛紝
      //      瀹冩槸涓嬫父涓€鍫嗛棬鐨勫垽鎹紝杩欓噷**涓嶅姩瀹?*锛堢涓€杞邯寰嬶細涓嶈鐢ㄤ竴涓竷灏旀壙鎷呬袱绉嶈涔夛級銆?
      //   鈿狅笍 钀藉嚑浣曡涓存椂寮€闂紙`morphGeomReady`锛夛紝钀藉畬**蹇呴』鍘熸牱鍏冲洖鍘?* 鈥斺€?鍚﹀垯
      //      "鏈€鍚庝竴娆￠噺鍒扮殑 initScale" 浼氳鏃犵晫鐨勯棬鏀捐鍘荤敾涓€涓茶繃鏈熷嚑浣曘€?
      const startGeomOk: boolean = this.morphInitParams();
      if (startGeomOk) {
        // 鈿狅笍 `applyMorphProgress` 鐜板湪鏈変竴閬?`morphGeomReady` 闂紙瑙侀偅涓瓧娈碉級锛?
        //    鑰岃繖涓€鍒?缁堢偣杩樻病閲忓埌"鈬?闂ㄤ笂鍐欑潃"涓嶈钀戒綅"銆?
        //    璧风偣鍑犱綍鏄?*鍙︿竴浠朵簨**锛氬畠鍙渶瑕佽兌鍥婁笌瀹夸富灏哄锛堥兘宸茬粡閲忓埌浜嗭級銆?
        //    鈬?涓存椂寮€闂ㄨ惤涓€娆★紝钀藉畬**鍘熸牱鍏冲洖鍘?*锛堢粷涓嶈兘璁?鏈€鍚庝竴娆￠噺鍒扮殑 initScale"
        //      琚綋鎴?鏈疆宸插氨缁?鑰屾斁琛屼竴涓茶繃鏈熷嚑浣曪級銆?
        const prevReady: boolean = this.morphGeomReady;
        this.morphGeomReady = true;
        this.applyMorphProgress(0);
        this.morphGeomReady = prevReady;
      }
      Logger.info(PlayerExpandState.logTag,
        `RzdMorphStart bake start geometry: initOk=${startGeomOk} geomReady=${this.morphGeomReady} ` +
        `initScale=${this.initScale.toFixed(4)} clipH=${this.initClipHeight.toFixed(1)} ` +
        `tx=${this.initTranslateX.toFixed(1)} ty=${this.initTranslateY.toFixed(1)}`);
    }
    // 宸叉湁璧风偣灏辩户缁瓑寰呯洰鏍囨寕杞斤紝璋冪敤鏂逛笉鑳芥妸棣栨涓婃媺鐩存帴钀戒綅銆?
    // 鈽呪槄 2026-10-15 璇婃柇閿氱偣锛坄hdc shell hilog -x | Select-String 'RzdMorphStart'`锛夆€斺€?
    //   涓€娆℃墦鍑?*褰㈠彉璧风偣**鐨勫叏閮ㄩ噺锛岀敤鏉ュ垽瀹氱敤鎴锋姤鐨勩€?*鍔ㄧ敾璧峰浣嶇疆鍋忎笅**銆嶅睘浜庡摢涓€绉嶏細
    //     路 `bar`  = 閲忓埌鐨勮糠浣犳潯**鑳跺泭**娓叉煋鐭╁舰锛坄getRectangleById`锛?*绐楀彛鍧愭爣**銆佸惈绁栧厛 transform锛?
    //     路 `mini` = 閲忓埌鐨勮糠浣犳潯**灏侀潰**鐭╁舰 鈥斺€?**褰㈠彉涓ユ牸鐢ㄧ殑灏辨槸瀹?*锛坄miniY/miniSize`锛?
    //     路 `win`  = 绐楀彛灏哄锛沗pad` = 鐪熷疄閬胯鍖猴紙涓?/ 涓嬶級锛沗usable` = 涓ょ閿氱偣鏄惁榻?
    //   **鍒ゆ嵁锛堥厤鍚堝３灞傜殑 `RzdPlayerViewport` 閭ｆ潯涓€璧风湅锛?*锛?
    //     路 鑻?`RzdPlayerViewport` 鐨?`overlay` 楂樺害 **灏忎簬** `window` 楂樺害锛堝樊 鈮?pad 涔嬪拰锛?
    //       鈬?**鍐呭鐩掓病閾烘弧绐楀彛** 鈬?褰㈠彉鍏ㄨ蛋绐楀彛鍧愭爣鏃跺氨鏁翠綋鍋忎笅 鈬?褰掗〉鏍归偅鏉?
    //         `expandSafeArea + ignoreLayoutSafeArea`锛?4 閭ｅ淇锛夌锛?
    //     路 鑻?`overlay == window` 鑰岃繖閲岀殑 `mini.y` 涓庤糠浣犳潯鍦ㄥ睆涓婄殑**瀹為檯**浣嶇疆涓嶄竴鑷?
    //       鈬?**閲忔祴鍙ｅ緞**闂锛堣鐢ㄦ覆鏌撲綅鑰屼笉鏄竷灞€浣嶏級銆?
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMorphStart ready=${ready} preferFloating=${preferFloating} ` +
      `bar=(${this.barWinX.toFixed(1)},${this.barWinY.toFixed(1)},` +
      `${this.barWinW.toFixed(1)},${this.barWinH.toFixed(1)}) ` +
      `mini=(${this.miniX.toFixed(1)},${this.miniY.toFixed(1)},${this.miniSize.toFixed(1)}) ` +
      `win=${this.windowWidthVp.toFixed(0)}x${this.windowHeightVp.toFixed(0)} ` +
      `pad=${this.topInsetVp().toFixed(1)}/${this.navigationBarBottomVp.toFixed(1)} ` +
      `usable=${this.morphUsable} bigKnown=${this.bigNodeKnown} ` +
      `endKnown=${this.endAnchorKnown()} geomReady=${this.morphGeomReady}`);
    // 鈽呪槄鈽?2026-10-16锛?*杩斿洖鍊艰涔夎姝ｏ細`false` 鍙唬琛?璧风偣鍑犱綍涔熸病鏈?**锛夛細
    //   鍘熸潵鏄?`ready || (barWinW > 0 && miniSize > 0)` 鈥斺€?鍗曠湅娌￠棶棰橈紝浣嗗畠涓庤皟鐢ㄦ柟
    //   `Index.beginOpenMorphOnClick` 鐨?`false` 鈬?绔嬪埢 `morphReset()` + 鏃犲舰鍙樿惤浣?
    //   鍚堣捣鏉ュ氨鏄偅涓潙锛氱偣鍑绘墦寮€鏃?*缁堢偣**锛堟挱鏀鹃〉澶у皝闈級蹇呯劧杩樻病鎸傝浇锛?
    //   鑰岃皟鐢ㄦ柟浼氭妸"缁堢偣娌￠噺鍒?褰撴垚"杩欏鍔ㄧ敾鍋氫笉浜?鈬?**琛ラ噺閾捐鏁存璺宠繃**
    //   鈬?`morphGeomReady` 姘歌繙涓哄亣 鈬?瀹瑰櫒鎭掔瓑 鈬?
    //   鐢ㄦ埛瀹炴祴銆岀偣鍑绘墦寮€ / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖 閮芥病鏈夊姩鐢汇€嶃€?
    //   鏃犵晫鐨勫舰鐘讹紙`MainPage.beginMorphEnter` 146495 璧?+ `openPlayerMorph` 149679锛夛細
    //   **閲忓埌璧风偣灏?`true` 骞舵帹璺敱**锛岀粓鐐圭敱**鎾斁椤垫寕杞藉悗鑷繁涓婃姤**
    //   锛坄publishMorphTargets` 鈫?`pullGeomReady = true` 鈫?`onPullReady` 鍥炶皟鎺ョ潃璺戯級銆?
    //   鈬?鎵€浠ヨ繖閲屼繚鎸?璧风偣灏辩华鍗?true"锛涚粓鐐圭己澶辩敱琛ラ噺閾捐礋璐ｏ紙璋冪敤鏂?*涓嶅啀**鍥?
    //     `false` 鑰屾斁寮冧細璇濓紝瑙侀偅杈?`isFreshSession` 閭ｄ竴娈碉級銆?
    //   `false` 鐜板湪鍙搴?杩炶糠浣犳潯鑳跺泭閮芥病閲忓埌"杩欎竴绉嶇湡姝ｆ病鏁戠殑鎯呭喌銆?
    return ready || (this.barWinW > 0 && this.miniSize > 0);
  }

  /**
   * 璺熸墜璧锋墜**涔嬪悗**鐨勮ˉ閲忥細鎾斁椤垫槸涓婃媺璧锋墜閭ｄ竴鍒绘墠鎸傝浇鐨勶紝绗竴甯ч噺涓嶅埌瀹冪殑灏侀潰鑺傜偣銆?
   *
   * 鍙嶇紪璇戜晶涔熸槸杩欎釜椤哄簭锛坄onPullReady` 鍥炶皟閲岃ˉ閲忎竴娆★級锛涙垜浠繖閲岀敱杩蜂綘鏉?澹冲眰鐨?
   * 瀹氭椂鍣ㄨ皟銆傚彧鍦ㄦ墜鎸囬┍鍔ㄦ湡闂寸敓鏁堬紝閬垮厤鎶婂凡缁忓紑璺戠殑琛ラ棿涓€旀敼閬撱€?
   * @param ui UIContext
   * @param preferFloating 瑙?{@link measureGeometry}
   * @returns 缁堢偣閿氱偣鏄惁琛ラ噺鎴愬姛
   */
  public measureMiniDuringPull(ui: UIContext, preferFloating: boolean): boolean {
    if (this.morphStage !== MorphStage.ENTERING || this.morphDrive !== MorphDrive.FINGER) {
      return false;
    }
    if (this.bigNodeKnown && this.morphUsable) {
      return true;
    }
    if (!this.measureEndAnchor(ui)) {
      return false;
    }
    // 鐩爣棣栨鎸傝浇鏃朵繚鎸佸師灏哄閲忔祴锛涢噺榻愬悗鍐嶇敤宸茬粡绱鐨勬墜鍔胯繘搴﹂┍鍔ㄨ鍓€?
    const pendingProgress: number = this.morphP;
    this.freezeMorphMeta(ui);
    this.sourceBarHidden = true;
    this.morphInitParams();
    // 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫 `publishMorphTargets` 鏈€鍚庨偅涓夎**锛宍wujie.pa` 176216-176233锛夛細
    //   缁堢偣鍑犱綍鍒氬垰閲忓埌 鈬?杩欏氨鏄?鍑犱綍灏辩华"閭ｄ竴鍒伙紝**鍦ㄨ繖涓€鎷?*鎶婂鍣ㄥ嚑浣曠涓€娆¤惤鍒?
    //   `applyMorphProgress(pendingProgress)`銆傚湪姝や箣鍓?`applyMorphProgress` 浼氫富鍔ㄤ粈涔堥兘涓嶅仛
    //   锛堣閭ｈ竟鐨?`morphGeomReady` 闂級鈬?瀹瑰櫒涓€鐩翠繚鎸佹亽绛夛紝涓嶄細鍑虹幇"鎻愬墠鎸夊崐浠藉嚑浣曡惤浣?銆?
    if (!this.morphGeomReady) {
      this.morphGeomReady = true;
      this.pushMorphTrace('geomReady');
      Logger.info(PlayerExpandState.logTag,
        `morph geom ready: end=(${this.endCoverX.toFixed(1)},${this.endCoverY.toFixed(1)},` +
        `${this.endCoverSize.toFixed(1)}x${this.endCoverH.toFixed(1)},src=${this.endAnchorSource()}) ` +
        `start=(${this.miniCoverX.toFixed(1)},${this.miniCoverY.toFixed(1)},${this.miniCoverSize.toFixed(1)}) ` +
        `initScale=${this.initScale.toFixed(4)} p=${pendingProgress.toFixed(3)}`);
    }
    this.applyMorphProgress(pendingProgress);
    return true;
  }

  /**
   * @returns 璺熸墜杩涘害 0鈥?锛堢珫鍚戜綅绉伙紝涓婃媺涓烘锛夈€?
   *
   * **閫愭潯鐓ф妱鍙嶇紪璇戠殑涓荤畻寮?*锛坄MainPage.pullUpdate`锛夛細
   * ```
   *   morphT = clamp(-vp2px(dy) / pullRangePx, 0, 1)
   *   pullRangePx = rect.top > 0 ? rect.top : windowHeight * PULL_RANGE_RATIO
   * ```
   * 涔熷氨鏄?**缁濆鏄犲皠**锛氫綅绉荤殑绾嚱鏁帮紝娌℃湁绱姞銆佹病鏈夐樆灏笺€佹病鏈夋儻鎬?鈥斺€?
   * 褰掍竴鍖栧垎姣嶆槸**鑳跺泭鐨?top**锛堜粠涓婃媺鍒拌糠浣犳潯浣嶇疆闇€瑕佺殑琛岀▼锛夈€?
   * 鎴戣繖閲岀敤 vp 缁熶竴鍙ｅ緞锛堝垎瀛愬垎姣嶅悓鏃舵槸 vp锛屾瘮鍊肩瓑浠凤級锛屾墍浠ヤ笉鐢?`vp2px`銆?
   */
  public pullOpenFraction(offsetY: number): number {
    const ratio: number = (-offsetY) / this.pullSpanVp();
    return ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  }

  /**
   * @returns 璺熸墜浣嶇Щ鐨勫綊涓€鍖栬绋嬶紙vp锛夛細**浼樺厛瀹炴祴**鑳跺泭 top锛? 鏃犵晫鐨?`coverRect.top`锛夛紝
   *   閲忎笉鍒版墠閫€鍥炵獥鍙ｉ珮搴︾殑 0.55銆?
   *
   * 鈿狅笍 **鍏滃簳姣斾緥 0.55 鈮?鏃犵晫鐨?`PULL_RANGE_RATIO = 0.32`锛屾湁鎰忎繚鐣欍€佸彧鏍囨敞**
   *   锛堜緷鎹?`docs\鏃犵晫褰㈠彉鎵嬫劅-钀藉疄鍒癛zdMusic娓呭崟.md` 搂鍏?绗?6 鏉★細姣斾緥鍊?鏀逛簡瑕佸疄娴嬫墜鎰熷啀瀹?锛?
   *   涓嶈鎸夋棤鐣岀殑鍊肩洿鎺ヨ鐩栵級锛?
   *   路 涓昏矾寰?*鎭掍负瀹炴祴 `barY`**锛坄morphInitParams()` 鎴愬姛鏃?`barY > 0`锛夛紝
   *     鍏滃簳鍒嗘敮鍙湪"鍑犱綍鍏ㄦ病閲忓埌"鏃惰蛋 鈥斺€?閭ｇ鎯呭喌涓嬫墜鍔挎湰鏉ュ氨閫€鍖栵紙璧锋墜鍗?`!ok` 钀戒綅锛夛紝
   *     0.55 涓?0.32 閮戒笉鍙備笌鐪熷疄鎵嬫劅锛?
   *   路 鍒ゆ嵁琛岋細鐪熸満涓婅嫢鐪嬪埌 `morph init FAIL: bar 鈥 鎴?`morph init box=鈥?bar=(0,0,鈥?`锛?
   *     璇存槑璧扮殑鏄厹搴?鈥斺€?閭ｆ椂鍐嶈皥瑕佷笉瑕佹妸瀹冨榻愬埌 0.32銆?
   */
  public pullSpanVp(): number {
    if (this.barY > 0 && this.barH > 0) {
      return this.barY;
    }
    const h: number = this.windowHeightVp > 0 ? this.windowHeightVp : 800;
    return Math.max(1, h * 0.55);
  }

  /**
   * @returns 璺熸墜琛岀▼鏄惁**璧扮殑鏄疄娴嬮偅涓€鏀?*锛坄barY`/`barH` 閮芥湁鍊硷級銆?
   *
   * 鍙粰鏃ュ織鐢細`RzdMorph dismiss commit` / `RzdMorph pull commit` 涓ゆ潯鍒ゆ嵁鏃ュ織閲岄兘瑕佸甫
   * "杩欎釜鍒嗘瘝鏄噺鐨勮繕鏄厹搴曠殑"銆?*涓轰粈涔堥潪瑕佸畠**锛歚娲鹃煶鍔ㄧ敾Bug娓呭崟.md` 搂6.5 绔嬭繃涓€鏉♀€斺€?
   * 鍙墦"姣斿€?vs 闃堝€?浼氭妸銆屼袱涓柟鍚戠殑鍒嗘瘝涓嶆槸鍚屼竴涓暱搴︺€嶈繖浠朵簨缁х画钘忚捣鏉ワ紝
   * 浜庢槸涓嬩竴涓汉鍙堜細鎶婃敹璧风殑 `38%` 鎹㈢畻鎴?`1 鈭?0.38 = 0.62` 鍘诲拰鎵撳紑鐨?`0.45` 姣斻€?
   * 涓や釜鍒嗘瘝锛坄pullSpanVp()` / `PlaybackPage.dismissSpanVp()`锛夊繀椤讳笌涓や釜闃堝€?*鍚岃鎵撳嵃**銆?
   */
  public pullSpanIsMeasured(): boolean {
    return this.barY > 0 && this.barH > 0;
  }

  /**
   * **鎻愪氦闃堝€?`COMMIT_T`**锛?鈥?锛夆€斺€?瀵规爣鏃犵晫 `MainPage.COMMIT_T = 0.32`銆?
   *
   * 鈽呪槄 2026-10-15锛堢敤鎴锋寚绀恒€?*鎵嬫劅瀵归綈鏃犵晫**銆嶅悗钀藉湴锛夛細鍊间粠 `0.45` 鏀规垚 **`0.32`**銆?
   *   鈿狅笍 杩欐潯**鎺ㄧ炕浜?*鏈枃浠舵鍓嶇殑涓€鏉℃寚浠わ紙鍘熸枃锛?鏃犵晫鏄?`COMMIT_T = 0.32`锛岃繖閲屼繚鎸?
   *   0.42 / 0.45锛屾爣娉ㄣ€庡緟瀹炴祴銆忊€?*涓嶈鎸夋棤鐣岀殑鍊肩洿鎺ヨ鐩?*"锛夆€斺€?閭ｆ潯鐨勯【铏戞槸"娌′笂鏈哄疄娴?
   *   灏变笉鍔ㄦ墜鎰?锛岃€岀幇鍦?*鐢ㄦ埛鏄庣‘瑕佹眰鎵嬫劅瀵归綈鏃犵晫**锛岃椤捐檻鐨勬潯浠朵笉鍐嶆垚绔?鈬?鎸夋棤鐣岃惤鍦般€?
   *
   * 鈽?**涓や釜鏂瑰悜鍏辩敤鍚屼竴涓?`T`**锛堟棤鐣屽氨鏄繖鏍凤級锛?
   *   路 鎵撳紑锛歚morphT >= COMMIT_T`锛堟湰鏂囦欢 `pullOpenShouldCommit()`锛夛紱
   *   路 鍏抽棴锛?*鐩稿閲?* `delta >= max(baseT/2, COMMIT_T)`锛坄PlaybackPage.onDismissDrag`锛?
   *     瀵规爣鏃犵晫 `reverseQuitDelta()`锛夆€斺€?**涓嶆槸**"缂╁埌鏌愪釜鐧惧垎姣斿氨鍏?銆?
   *   鈬?婊″睍寮€璧锋墜鍏抽棴鏃堕槇鍊?= `max(0.5, 0.32) = 0.5`锛堣鎷夊洖鍘?50% 鎵嶅叧锛夈€?
   */
  public static readonly PULL_OPEN_COMMIT_FRACTION: number = 0.32;
  /**
   * 涓婃媺鎵撳紑鐨?*閫熷害**鎻愪氦闃堝€硷紙vp/s锛夈€?
   *
   * 鍑哄涓?`PlaybackPage.DISMISS_COMMIT_VELOCITY` 鏄?*鍚屼竴涓暟**锛?
   *   `docs\鏃犵晫褰㈠彉鎵嬫劅-钀藉疄鍒癛zdMusic娓呭崟.md` 搂涓€ 1.2銆屾彁浜ゅ垽瀹?鈥斺€?杩涘害 OR 閫熷害銆?
   *   鈬?`commit = (morphT >= COMMIT_T 0.32) || (velocity <= COMMIT_VELOCITY 900)`
   *   鈬?鏃犵晫鐨?`COMMIT_VELOCITY = 900`銆?
   * 鑰屼笖閭ｄ竴鏉℃湰鏉ュ氨鏄?*鎵撳紑鏂瑰悜**鐨勫垽鎹細`morphT` 姝ｆ槸鏃犵晫
   *   `MainPage.pullUpdate` 绠楀嚭鏉ョ殑**涓婃媺鎵撳紑**杩涘害锛坄clamp(-vp2px(dy)/pullRangePx)`锛夈€?
   *   鏀惰捣鏂瑰悜閭ｆ潯锛坄PlaybackPage.onDismissDrag`锛孌1锛夋槸 RzdMusic 鐨勫弽鍚戞墜鍔匡紝
   *   宸茬粡鎸夊悓涓€鏁伴钀藉湴锛涜繖閲屾妸**鎵撳紑**鏂瑰悜涔熻ˉ榻?鈬?涓ゆ潯鎵嬪娍鐨勬彁浜ゅ垽鎹悓婧愬悓棰濄€?
   *
   * 鈿狅笍 **涓嶇収鎶勭鍙?*锛堟竻鍗?搂鍏?绗?3 鏉★級锛歋DK 鐨?`GestureEvent.velocityY` 娌℃壙璇烘柟鍚戙€?
   *   杩欓噷涓?D1 鍚屾缁曞紑锛?*鏂瑰悜鐢变綅绉诲垽锛堜笂鎷?鈬?`offsetY < 0`锛夈€佸ぇ灏忓彇 `Math.abs(velocityY)`**
   *   鈬?鏃犺绯荤粺缁欑殑鏄?+900 杩樻槸 鈭?00锛屽垽瀹氱粨鏋滈兘涓€鏍枫€?
   */
  private static readonly PULL_OPEN_COMMIT_VELOCITY: number = 900;

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲 寮€ / 鍏充袱鍚戠殑鎻愪氦鍒ゆ嵁锛?*鍙湪杩欓噷瀹氫箟涓€浠?*锛堟湰杞敹鏁涳級 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 鏀舵暃鐨勭敱鏉ワ紙`_recover\logic-src\娲鹃煶鍔ㄧ敾Bug娓呭崟.md` P0-1 + 搂6.5锛夛細
  //   鍘熸潵杩欎袱涓暟**鍒嗗眳涓や釜鏂囦欢**锛堟墦寮€鍦?`PlayerExpandState`銆佹敹鍦?`PlaybackPage`锛夛紝
  //   娌℃湁浠讳綍浜ゅ弶鏍￠獙 鈥斺€?鑰屽畠浠槸**浜掗€嗙殑涓ゆ潯鎵嬪娍**锛屾敼涓€涓笉鏀瑰彟涓€涓氨浼氬湪涓寸晫浣嶇疆鎵撴灦
  //   锛堟墜鎰熶笂鏄?鐢╀笉涓婂幓锛屼竴鏉炬墜鍙堟帀涓嬫潵"锛夈€?
  //   搂6.5 鐨勫缃粨璁猴細**鎬ц川鏄?涓ゅ鍚勫啓涓€閬?+ 浠庢湭瀹氭"**锛堜笉鏄?鏂瑰悜鍙嶄簡"锛?
  //   閭ｅ彞"鏀惰捣鏂瑰悜鐨勯棬姣旀墦寮€鏂瑰悜楂?39%"鏄妸涓ゆ妸涓嶅悓鐨勫昂瀛愶紙`barY` / `miniY`锛夋崲绠楅敊浜嗭級銆?
  //
  // 鈿狅笍鈿狅笍 **鍘嗗彶璁板綍锛堝凡琚?2026-10-15 鐨?鎵嬫劅瀵归綈鏃犵晫"鍙栦唬锛岀暀妗ｄ笉鍐嶆墽琛岋級**锛?
  //   杩欓噷鍘熸潵鍐欑潃"杩欎袱涓暟涓?`PULL_OPEN_COMMIT_FRACTION` 鍙兘涓€璧锋敼锛岃€屼笖**蹇呴』鍏堜笂鏈哄疄娴?*锛?
  //   鏃犵晫鏄?0.32锛岃繖閲屼繚鎸?0.42 / 0.45鈥?*涓嶈鎸夋棤鐣岀殑鍊肩洿鎺ヨ鐩?*"锛屽苟缁欏嚭褰撴椂鐨勯噺绾э細
  //     鎵撳紑鎻愪氦 鈮?`0.45 脳 barY`锛涙敹璧锋彁浜?鈮?`0.38 脳 miniY`锛坄barY 鈮?miniY`锛?
  //   鈬?褰撴椂鐨勭粨璁烘槸銆屾敹璧峰叾瀹炴瘮鎵撳紑鏇村鏄擄紙绾?鈭?6%锛夛紝涓嶆槸"鏀惰捣鏇撮毦"銆嶃€?
  //   **鐢ㄦ埛 2026-10-15 鏄庣‘鎸囩ず"鎵嬫劅瀵归綈鏃犵晫"** 鈬?閭ｆ潯椤捐檻锛?娌″疄娴嬪氨涓嶈瑕嗙洊鎵嬫劅"锛夌殑鍓嶆彁娑堝け锛?
  //     鎵撳紑闃堝€?鈫?`0.32`锛涘叧闂?鈫?鐩稿閲?`max(baseT/2, 0.32)`锛堟弧灞曞紑璧锋墜 鈬?瑕佹媺鍥?50% 鎵嶅叧锛夈€?
  //   鈬?**鏂瑰悜鍙嶈繃鏉ヤ簡**锛氱幇鍦ㄦ槸"鎵撳紑鏇村鏄撱€佸叧闂洿涓嶆槗璇叧"锛屼笌鏃犵晫涓€鑷淬€?

  /**
   * 涓嬫媺鏉炬墜鏃剁殑**杩涘害**鎻愪氦闃堝€硷紙0鈥?00锛夆€斺€?鈿狅笍 **鍙粰"閫€鍖栬矾寰?鐢?*銆?
   *
   * 鈽呪槄 2026-10-15锛堟墜鎰熷榻愭棤鐣岋級锛?*褰㈠彉璺緞宸茬粡涓嶇敤瀹冧簡** 鈥斺€?閭ｆ潯璺敼鎴愭棤鐣岀殑
   *   **鐩稿閲?*鍒ゆ嵁 `delta >= max(baseT/2, COMMIT_T)`锛堣 `PlaybackPage.onDismissDrag`
   *   涓?`PULL_OPEN_COMMIT_FRACTION` 鐨勬敞閲婏級銆?
   *   鏈父閲忕幇鍦ㄥ彧鏈嶅姟"**閲忎笉鍒板嚑浣?*锛坄morphUsable === false`锛夐偅鏉￠€€鍖栧垎鏀?锛?
   *   閭ｉ噷娌℃湁 `morphT` 鍙畻 `delta`锛屽彧鑳戒粛鏃ф寜"缂╁埌澶氬皯"鍒ゃ€?
   *   鈬?瀹冩槸**闄嶇骇璺緞鐨勫厹搴?*銆佷笉鏄富鍒ゆ嵁锛涙棤鐣屾病鏈夊搴斿垎鏀紙瀹冩€昏兘閲忓埌鍑犱綍锛夈€?
   */
  public static readonly DISMISS_COMMIT_PROGRESS: number = 38;

  /**
   * 涓嬫媺鏀惰捣锛氭嫋鎷藉灏戣窛绂荤畻"鎷夊埌搴?锛堢浉瀵圭獥鍙ｉ珮搴︼級銆?
   *
   * 鈿狅笍 **鏃犵晫鏄?0.32锛岃繖閲屼繚鎸?0.42锛屾爣娉?寰呭疄娴?** 鈥斺€?渚濇嵁
   *   `docs\鏃犵晫褰㈠彉鎵嬫劅-钀藉疄鍒癛zdMusic娓呭崟.md` 搂鍏?绗?6 鏉?
   *   锛?鏀逛簡瑕佸疄娴嬫墜鎰熷啀瀹?锛屼笉璁告寜鏃犵晫鐨勫€肩洿鎺ヨ鐩栵級銆?
   *   瀹冪幇鍦ㄥ彧鏄?*鍏滃簳**锛歚PlaybackPage.dismissSpanVp()` 浼樺厛鐢ㄥ疄娴嬬殑鏀惰捣琛岀▼锛坄miniY`锛夛紝
   *   鍙湁閲忎笉鍒帮紙`miniY <= 0`锛夋椂鎵嶉€€鍥炶繖涓瘮渚嬨€?
   */
  public static readonly DISMISS_DRAG_SPAN_RATIO: number = 0.42;

  /**
   * 涓婃媺鏉炬墜锛?*鏄惁鎻愪氦**锛? 灞曞紑鍒板簳鑰屼笉鏄洖寮瑰嵏杞斤級銆?
   *
   * 鈽?杩欐槸**鍞竴**鐨勬彁浜ゅ垽鎹紙娓呭崟 搂涓€ 1.2 鐨勩€岃繘搴?OR 閫熷害銆? 搂鍥?D1锛夈€?
   *   涓ゆ潯鐞嗙敱锛岀己涓€鏉￠兘涓嶈鎶婂畠鍋氭垚鍑芥暟锛?
   *   1. **琛ラ€熷害椤?*锛氬師鏉?`>= 0.45` 鍙湅杩涘害 鈥斺€?"浣嶇Щ涓嶅ぇ銆佷絾鐢╁緱寰堝揩"涓嶆彁浜わ紝
   *      鎵嬫劅涓婂氨鏄?**杞荤敥鎵撲笉寮€**"锛圖1 鍦ㄦ敹璧锋柟鍚戜慨鎺夌殑鏄悓涓€涓瘺鐥咃級锛?
   *   2. **鍒ゆ嵁鍙湁涓€浠?*锛氬師鏉ヨ繖鏉?`>= 0.45` 鍦?*涓変釜鏂囦欢閲屽悇鍐欎竴閬?*
   *      锛坄Index.onPullOpenEnd` / `HomeMiniBarPlayer` / `MiniBarPlayer`锛夛紝
   *      鑰屾湰宸ョ▼鐨勬棦鏈夋暀璁槸銆?*鍚屼竴涓噺鍦ㄤ袱澶勫悇绠椾竴閬嶏紝灏变細鍦ㄤ复鐣屽€间笂鎵撴灦**銆?
   *      锛堟瓕鍗曢〉榛戠櫧瀛楅偅娆★級鈬?鏀舵暃鍒拌繖閲岋紝涓夊鍙紶鍙傘€佷笉鍐嶅悇鑷垽銆?
   *
   * 鈿狅笍 鍒ゆ嵁鍏ㄩ儴鏄?*鍏ュ弬鐨勭函鍑芥暟**锛氫笉璇讳笂涓€甯с€佷笉鍋氱疮鍔狅紙娓呭崟 搂涓€ 1.1 鐨勫悓涓€鏉¤姹傦級銆?
   * @param progress 褰撳墠涓婃媺杩涘害 0鈥?锛堜紶 `morphP` 鈥斺€?**灞忎笂鐪熸鍦ㄧ敤鐨勯偅涓€?*锛?
   *   鑰屼笉鏄嬁 `offsetY` 閲嶇畻涓€閬嶏細璧锋墜涓€旇ˉ閲忚繃閿氱偣鏃?`pullSpanVp()` 浼氬彉锛?
   *   閲嶇畻鍑虹殑鍊间笌鐢婚潰涓嶄竴鑷达級
   * @param offsetY 鏉炬墜鏃剁殑绔栫洿浣嶇Щ锛坴p锛?*涓婃媺涓鸿礋**锛?
   * @param velocityY 鏉炬墜鏃剁殑绔栫洿閫熷害锛坄GestureEvent.velocityY`锛寁p/s锛?
   * @returns true = 灞曞紑鍒板簳锛沠alse = 鍥炲脊骞跺嵏杞?
   */
  public pullOpenShouldCommit(progress: number, offsetY: number, velocityY: number): boolean {
    const reached: boolean = progress >= PlayerExpandState.PULL_OPEN_COMMIT_FRACTION;
    const opening: boolean = offsetY < 0;
    const speed: number = Math.abs(velocityY);
    const fastFlick: boolean = opening && speed >= PlayerExpandState.PULL_OPEN_COMMIT_VELOCITY;
    const commit: boolean = reached || fastFlick;
    // 涓婃満鎺掓煡锛歚hdc shell hilog -x | Select-String 'RzdMorph pull commit'`
    // 鈿狅笍 杩欎竴琛?*涓?`PlaybackPage.onDismissDrag` 閭ｆ潯鍚屾瀯**锛氶兘鎶?*涓や釜鏂瑰悜鐨勯槇鍊?+ 涓や釜鍒嗘瘝**
    //    鎵撳湪鍚屼竴琛岋紙瑙?`pullSpanIsMeasured()` 鐨勬敞閲婏級鈥斺€?鍙墦"姣斿€?vs 闃堝€?浼氱户缁棌浣?
    //    "涓や釜鍒嗘瘝涓嶆槸鍚屼竴涓暱搴?杩欎欢浜嬶紝涓嬫杩樹細鏈変汉鎶婃敹璧风殑 38% 鎹㈢畻鎴?0.62 鍘诲拰 0.45 姣斻€?
    Logger.info(PlayerExpandState.logTag,
      `RzdMorph pull commit progress=${progress.toFixed(3)}/${
        PlayerExpandState.PULL_OPEN_COMMIT_FRACTION} offsetY=${offsetY.toFixed(1)} ` +
      `velocityY=${velocityY.toFixed(1)} absVelocity=${speed.toFixed(1)} ` +
      `dir=${opening ? 'open' : 'close'} fastFlick=${fastFlick} ` +
      `velocityThreshold=${PlayerExpandState.PULL_OPEN_COMMIT_VELOCITY} ` +
      `span=${this.pullSpanVp().toFixed(1)} spanSrc=${
        this.pullSpanIsMeasured() ? 'measured' : 'ratio'} ` +
      `dismissThreshold=${PlayerExpandState.DISMISS_COMMIT_PROGRESS} dismissSpan=${
        this.miniY.toFixed(1)} dismissSpanSrc=${
        this.miniY > 0 ? 'measured' : 'ratio'} commit=${commit}`);
    return commit;
  }

  /** 鏉炬墜璇锋眰鐗堟湰鍙凤紙澹冲眰 `@Monitor` 瀹冩潵鎾敹灏捐ˉ闂达級銆?*/
  @Trace public pullSettleVersion: number = 0;
  /** 鏈鏉炬墜鏄惁鎻愪氦锛坱rue = 灞曞紑鍒板簳锛宖alse = 鍥炲脊骞跺嵏杞斤級銆?*/
  @Trace public pullSettleCommit: boolean = false;

  /**
   * 鎵嬫寚璺熸墜鎵撳紑锛氭澗鎵?鈥斺€?鍙彂"璇锋眰"锛岀湡姝ｇ殑琛ラ棿鐢卞３灞傛挱銆?
   *
   * 涓轰粈涔堜笉璁╂墜鍔挎柟鑷繁鎾細琛ラ棿瑕佺敤 `UIContext.animateTo`锛岃€?*鎸傝浇/鍗歌浇鎾斁椤垫诞灞?*
   * 鍙湁澹冲眰鑳藉仛锛坄isShowPlay` 鍦ㄥ３灞傦級銆傚垎鎴?鎵嬪娍椹卞姩 + 澹冲眰鏀跺熬"涓ゆ锛?
   * 杩蜂綘鏉￠偅鏉℃墜鍔垮拰澹冲眰閭ｆ潯鎵嬪娍灏遍兘鑳界敤鍚屼竴濂楁敹灏鹃€昏緫銆?
   * @param commit true = 灞曞紑鍒板簳锛沠alse = 鍥炲脊鍥炶糠浣犳潯骞跺嵏杞?
   */
  public requestPullOpenSettle(commit: boolean): void {
    this.pullDragging = false;
    this.pullSettleCommit = commit;
    this.pullSettleVersion = this.pullSettleVersion + 1;
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 妗ユ帴灏侀潰锛堝鏍囨棤鐣?CoverMorph 鐨?璧风偣鈭堣糠浣犳潯"閭ｄ竴鍗婏級鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // 涓轰粈涔堥渶瑕佸畠锛氭暣椤靛舰鍙樻槸"鎶婃挱鏀鹃〉鏁翠綋缂╂斁"锛岀缉鏀惧悗鐨勯〉闈㈠湪 p 寰堝皬鏃跺彧闇插嚭**椤甸潰椤堕儴**
  // 閭ｄ竴灏忔埅 鈥斺€?閭ｆ椂鍊欒兘鐪嬪埌鐨勫綋鐒朵笉鏄皝闈㈢殑浣嶇疆銆傚彲鐢ㄦ埛瑕佺殑鏄?
  // 銆屽皝闈粠灏忔挱鏀惧櫒閭ｅ紶**閫愭笎鏀惧ぇ銆佹敼浣嶇疆銆佹敼鍦嗚**锛屼竴闀滃埌搴曟垚鎾斁椤点€嶃€?
  // 鎵€浠ュ舰鍙樻棭鏈熷崟鐙敾涓€寮?缁灏侀潰"锛氫粠杩蜂綘鏉″皝闈㈢殑鐭╁舰璧板埌**褰撳墠甯ф挱鏀鹃〉灏侀潰**
  // 鍦ㄥ睆骞曚笂鐨勭煩褰紙鎶婃挱鏀鹃〉灏侀潰鎸夊鍣ㄧ殑鍙樻崲鎹㈢畻杩囧幓锛夛紝涓庡唴瀹瑰眰閲岄偅寮犵湡灏侀潰鍚屼綅浜ゆ帴銆?

  /**
   * @returns 鏄惁璇ョ敾妗ユ帴灏侀潰銆?
   *
   * 鍙湪褰㈠彉杩涜涓紙涓嶅惈 LANDING 鈥斺€?閭ｄ竴鍒诲皝闈㈠凡缁忎氦杩樼粰杩蜂綘鏉★級涓斿唴瀹瑰眰杩樻病鏄惧嚭鏉ユ椂鐢汇€?
   */
  public morphBridging(): boolean {
    if (!this.morphClipping()) {
      return false;
    }
    // LANDING = 宸茬粡浜よ繕缁欒糠浣犳潯锛堥偅涓€鍒昏糠浣犳潯鑷繁閭ｅ紶灏侀潰灏卞湪鍘熷湴锛屽埆鍐嶅彔涓€寮狅級
    if (this.morphStage === MorphStage.LANDING) {
      return false;
    }
    // 璧风偣锛堣糠浣犳潯灏侀潰锛変笌缁堢偣锛堟挱鏀鹃〉灏侀潰锛夐兘閲忓埌浜嗘墠鐢伙紝鍚﹀垯瀹佸彲娌℃湁杩欎竴妫?
    // 鈿狅笍 缁堢偣**蹇呴』鏈夊€?*锛氱粓鐐规槸"闈欐鎬佺湡瀹炵煩褰?锛岀粓鐐逛负 0 鏃朵細椋炲悜灞忓箷宸︿笂瑙?
    //
    // 鈽呪槄 2026-10-15 **鍥為€€鎴戣嚜宸辩殑"鏃堕棿绐?鏀瑰姩**锛氳繖涓€妫掑繀椤?*涓€鐩撮鍒?p=1**銆?
    //   鍘熷洜锛堢湡鏈哄疄娴嬶級锛氬畠鐨勭煩褰㈡槸**绐楀彛鍧愭爣**锛岃€岃鐢诲湪**琚?scale+translate 鍙樻崲杩囩殑瀹瑰櫒閲?*锛?
    //   鍙湁 p=1锛堝鍣ㄦ槸鎭掔瓑鍙樻崲锛夋椂绐楀彛鍧愭爣鎵嶇瓑浜庡畠瑕佽惤鐨勪綅缃紱
    //   鑻ュ湪 p=0.55 灏辨妸瀹冭鎺?浜ゆ锛岄偅涓€甯у畠杩樺湪鍗婅矾銆佺湡灏侀潰鍦ㄨ嚜宸辩殑甯冨眬浣嶄笂 鈬?**浼氳烦**銆?
    //   鎴戜竴搴﹁瘯杩?閫嗗彉鎹㈠洖椤靛唴鍧愭爣"鏉ユ彁鍓嶈惤浣嶏紝鐪熸満缁撴灉鏄?灏侀潰璺戝埌宸︿笂瑙?
    //   锛堣鏄?`.scale()` 鐨勬灑杞翠笉鏄垜浠ヤ负鐨勫鍣ㄤ腑蹇冿級鈬?璇ユ柟妗堜綔搴燂紝鍒啀璇曘€?
    return this.snapStartW > 0 && this.endCoverSize > 0;
  }

  /**
   * @returns 缁灏侀潰鐨勪笉閫忔槑搴︺€?
   *
   * 鎭掍负 1锛氬弽缂栬瘧閲屽厠闅嗗眰锛堝皝闈?鍏冧俊鎭?鎿嶄綔鍖猴級鏄?*鐢诲湪瀹瑰櫒涔嬩笂**鐨勪竴灞傚壇鏈紝
   * 瀹冧笉娣?鈥斺€?娣＄殑鏄儗鏅眰锛坄pullBgIn`锛変笌杩蜂綘鏉￠偅渚х殑涓ゆ。閫忔槑搴?
   * 锛坄metaOpacityAt` 0.35 / `actionsOpacityAt` 0.20锛夈€?
   * 璧风偣涔嬫墍浠ヤ笉鍐嶅嚭鐜?涓や釜鎾斁鍣?锛氬厠闅嗙殑灏侀潰涓庣湡瀹炶糠浣犳潯灏侀潰**鍚屼綅缃悓鍥?*锛?
   * 鑰岀湡瀹炵殑杩蜂綘鏉″湪娴眰涔嬩笅銆侀殢鍚庤涓嶉€忔槑璧锋潵鐨勮儗鏅洊鎺夈€?
   */
  public morphBridgeOpacity(): number {
    return this.morphBridging() ? 1 : 0;
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鍏嬮殕灞傜殑浣嶇Щ閲忥紙鍙嶇紪璇?`MiniMorph.coverRightShiftAt / coverRiseAt`锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  //   coverVisualEdgeAt(t) = lerp(杩蜂綘灏侀潰瀹? 鐩爣灏侀潰瀹? t)
  //   coverCenterXAt(t)    = lerp(杩蜂綘灏侀潰涓績X, 鐩爣灏侀潰涓績X, t)
  //   coverRightAt(t)      = coverCenterXAt(t) + coverVisualEdgeAt(t) / 2
  //   coverRightShiftAt(t) = coverRightAt(t) - coverRightAt(0)      鈫?鐩稿璧风偣鐨?*鍙崇Щ閲?*
  //   coverRiseAt(t)       = coverCenterYAt(t) - coverCenterYAt(0)  鈫?鐩稿璧风偣鐨?*涓婂崌閲?*
  //
  // 鍏冧俊鎭眰鐢ㄥ畠鍋?`translate({x})`锛?鎺ㄦ尋"鍙充晶鍐呭锛夛紝鎿嶄綔鍖哄眰鐢ㄥ畠鍋?`translate({y})`銆?

  /** @returns 灏侀潰鍙瀹藉害鐨勪腑蹇?X锛坴p锛屽涓诲潗鏍囷級鎻掑€笺€?*/
  private coverCenterXAt(t: number): number {
    const from: number = this.miniCoverX + this.miniCoverSize / 2;
    const to: number = this.endCoverX + this.endCoverSize / 2;
    return from + (to - from) * t;
  }

  /** @returns 灏侀潰鍙瀹藉害鐨勪腑蹇?Y锛坴p锛屽涓诲潗鏍囷級鎻掑€笺€?*/
  private coverCenterYAt(t: number): number {
    const from: number = this.miniCoverY + this.miniCoverSize / 2;
    const to: number = this.endCoverY + this.endCoverSize / 2;
    return from + (to - from) * t;
  }

  /** @returns 灏侀潰鍙瀹藉害锛坴p锛夋彃鍊硷細`lerp(杩蜂綘灏侀潰瀹? 鐩爣灏侀潰瀹? t)`銆?*/
  private coverVisualEdgeAt(t: number): number {
    return this.miniCoverSize + (this.endCoverSize - this.miniCoverSize) * t;
  }

  /** @returns 鐩稿璧风偣鐨勫彸绉婚噺锛坴p锛夛細缁欏厓淇℃伅鍏嬮殕灞傚仛 `translate({x})`銆?*/
  public coverRightShiftAt(p: number): number {
    const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
    const now: number = this.coverCenterXAt(t) + this.coverVisualEdgeAt(t) / 2;
    const at0: number = this.coverCenterXAt(0) + this.coverVisualEdgeAt(0) / 2;
    return now - at0;
  }

  /** @returns 鐩稿璧风偣鐨勪笂鍗囬噺锛坴p锛夛細缁欐搷浣滃尯鍏嬮殕灞傚仛 `translate({y})`銆?*/
  public coverRiseAt(p: number): number {
    const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
    return this.coverCenterYAt(t) - this.coverCenterYAt(0);
  }

  /**
   * @returns 妗ユ帴灏侀潰鐨勪竴甯х煩褰紙vp锛?*瀹夸富鍧愭爣**锛夈€?
   *
   * - 璧风偣锛氳糠浣犳潯灏侀潰锛坄MiniMorph` 閭ｄ竴鍗婏紝瀹炴祴锛夛紱
   * - 缁堢偣锛氭挱鏀鹃〉灏侀潰鍦?*褰撳墠甯?*鐨勫睆骞曠煩褰?鈥斺€?鍐呭灞傛槸"鍥哄畾瀹夸富灏哄 + 灞呬腑绛夋瘮缂╂斁 s"锛?
   *   鎵€浠ラ〉鍐呭潗鏍?(x, y) 鏄犲皠鍒?`鍐呭灞傚乏涓婅 + (x, y) * s`锛岃€屽唴瀹瑰眰宸︿笂瑙掑張鐢?
   *   绐楀彛锛堣创搴曞眳涓€佸昂瀵?`morphWinW/H`锛変笌 `s` 鍐冲畾銆倀 = 1 鏃剁獥鍙?= 瀹夸富銆乻 = 1锛?
   *   浜庢槸缁堢偣姝ｅソ鏄疄娴嬬殑 (bigX, bigY, bigSize) 鈥斺€?**鍔ㄧ敾瀹屾垚閭ｄ竴鍒绘墠褰掍綅**銆?
   */
  public morphCoverBridge(): LyricMorphRect {
    return this.morphCoverRectAt(this.morphP);
  }

  /**
   * @returns **浠绘剰杩涘害**涓嬬殑缁灏侀潰鐭╁舰锛坴p锛?*绐楀彛鍧愭爣**锛夈€?
   *
   * 鈿狅笍 涓や唤鍙ｅ緞鍒嗗紑銆佷笉瑕佹贩鍦ㄤ竴涓嚱鏁伴噷锛?
   *   路 `morphCoverBridge()`          鈥斺€?鎾斁椤甸偅浠斤紝杩涘害 = `morphP`锛?50ms 閭ｅ眰锛夛紱
   *   路 `morphOverlayCoverBridge()`   鈥斺€?**澹冲眰娴眰**閭ｄ唤锛岃繘搴?= `morphOverlayP`锛?60ms 閭ｅ眰锛夈€?
   * 涓よ€呭叡鐢ㄤ笅闈㈣繖娈电函鍑犱綍锛堣捣鐐?缁堢偣/鐩寸嚎鎻掑€硷級锛屽彧宸竴涓?`t`銆?
   *
   * @param progress 0 = 杩蜂綘鏉″皝闈紝1 = 鎾斁椤靛皝闈紙闈欐鎬佸疄娴嬬煩褰級
   */
  private morphCoverRectAt(progress: number): LyricMorphRect {
    // 鈽呪槄 2026-10-15 **鍥為€€"椤靛唴鍧愭爣閫嗗彉鎹?**锛氱湡鏈哄疄娴嬮偅鏍峰仛浼氭妸灏侀潰鐢诲埌宸︿笂瑙?
    //   锛堣鏄?`.scale()` 鐨勬灑杞翠笉鏄鍣ㄤ腑蹇冿紝鎴戠殑鎹㈢畻鍓嶆彁涓嶆垚绔嬶級銆?
    //   鐜板湪鍥炲埌"**绐楀彛鍧愭爣鐩寸嚎鎻掑€?*"鈥斺€旀贰鍏ユ贰鍑虹増閲屽氨鏄繖鏍凤紝鐢ㄦ埛瀹炴祴"灏侀潰鏄甯哥殑"锛?
    //   涓ょ鍦?p=0 / p=1 閮藉锛坧=1 鏃剁獥鍙ｅ潗鏍?= 椤靛唴鍧愭爣锛夛紝涓棿娈垫槸杩戜技浣嗚鎰熸甯搞€?
    //   鈿狅笍 鎵€浠ュ畠**蹇呴』涓€鐩撮鍒?p=1**锛堣 `morphBridging()` 閲岀殑璇存槑锛夛紝涓嶈鎻愬墠浜ゆ銆?
    const t: number = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    // 鈿狅笍 **鐩寸嚎鎻掑€?*锛堝鏍囧弽缂栬瘧 `MiniMorph`锛氫腑蹇?杈归暱鍚勪竴鏉?`lerpN`锛夛細
    //    `coverCenterXAt/YAt(t)`銆乣coverVisualEdgeAt(t)`銆乣coverVisualRadiusAt(t)`銆?
    //    鈿狅笍 涔嬪墠鎴戞嬁"瀹瑰櫒鍙樻崲鍚庣殑褰撳墠甯х煩褰?褰撶粓鐐癸紝浜庢槸璧风偣閭ｄ竴娈电粓鐐逛細**寰€涓嬭窇**
    //    锛堝鍣ㄧ缉鏀句腑蹇?+ 浣嶇Щ鍦?p 灏忔椂鎶婄洰鏍囨嫿鍒板睆骞曚笅鏂癸級鈥斺€?鐢ㄦ埛瀹炴祴鐨?
    //    "灏侀潰鍏堝線涓嬪啀寰€涓?灏辨槸杩欎釜銆傜洿绾挎彃鍊间袱绔兘鏄?*闈欐鎬佺殑鐪熷疄鐭╁舰**锛屼笉浼氭嫄寮€?
    // 鈽?缁堢偣灏哄瑕佷箻涓?*瀹炴椂**鐨勫皝闈㈣瑙夌缉鏀撅細瀛樹笅鏉ョ殑鏄?甯冨眬鐭╁舰 脳 閲忔祴鏃剁殑缂╂斁"锛?
    //   鑰岀湡瀹炲皝闈㈡鍒绘槸 脳(鎾斁 1.05 / 鏆傚仠 0.95)銆備笉涔樺洖鏉ワ紝p=1 浜ゆ灏辫烦閭?5%
    //   锛堢敤鎴峰疄娴嬬殑"缁撴潫鏃跺皝闈㈠ぇ灏忚烦涓€涓?锛夈€?
    // Freeze the visual endpoint once per session, never chase a spring/scale frame.
    const s: number = this.bigNodeKnown ? this.bigNodeScaleX : this.coverVisualScale();
    const endSize: number = this.endCoverSize * s;
    const endH: number = (this.endCoverH > 0 ? this.endCoverH : this.endCoverSize) * s;
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鍦嗚鍙湁涓€涓潵婧?* 鈥斺€?淇敤鎴峰疄娴嬨€屽姩鐢荤粨鏉熸椂灏侀潰鍦嗚绐佺劧鍙樺寲銆嶏級
    //
    // 鍘熸潵杩欓噷鏄細
    // ```
    //   const coverR = bigCoverRadius > 0 ? bigCoverRadius : (bigRadius > 0 ? bigRadius : endSize * 0.06);
    //   const endRadius = Math.min(coverR * s, 鈥?;
    // ```
    // 鑰?`bigCoverRadius / bigRadius` 鏄?`reportBig(..., coverRadiusState.radius)` 浼犺繘鏉ョ殑
    // 鈥斺€?**鐢ㄦ埛璁剧疆閲岀殑"鑷畾涔夊皝闈㈠渾瑙?**銆備簬鏄細
    // ```
    //   鍔ㄧ敾缁堢偣锛堟诞灞傚厠闅嗛偅寮狅級= 鐢ㄦ埛璁剧殑鍦嗚锛堜緥濡?16/24/32锛?
    //   钀戒綅鍚庯紙鎾斁椤甸偅寮犵湡灏侀潰锛? `lyricMorph(0).radius` = COVER_RADIUS_PLAYER_VP = 8
    //   鈬?**浜ゆ閭ｄ竴甯у渾瑙掕烦涓€涓?* = 鐢ㄦ埛璇寸殑"绐佺劧鍦嗚鍙樺寲銆佹瘮杈冨壊瑁?
    // ```
    // 鈬?鐜板湪涓ょ閮藉彇**鏃犵晫閭ｄ竴涓粷瀵瑰€?*锛坄CoverMorph.radiusPlayer = 8`锛宍wujie.pa:85481`锛夛紝
    //   骞朵笖闅忚瑙夌缉鏀?`s` 璧帮紙涓?涓績涓嶅彉銆佽竟闀夸箻 s"鍚屽彛寰勶級鈬?**鍔ㄧ敾缁堢偣 = 闈欐鎬?*锛屼笉璺炽€?
    //   鈿狅笍 鐢ㄦ埛瑕佹眰鍒犳帀"鑷畾涔夊皝闈㈠渾瑙?璁剧疆 鈬?杩欓噷涓嶅啀鏈変换浣曠敤鎴峰€煎弬涓庛€?
    const endRadius: number = Math.min(PlayerExpandState.COVER_RADIUS_PLAYER_VP * s,
      Math.min(endSize, endH) / 2);
    const startRadius: number = Math.min(this.snapStartRadius, this.snapStartW / 2);
    // 缁堢偣鏄?*鎸夊昂瀵哥缉鏀?*鐨勶細浣嶇疆闅忎腑蹇冧笉鍙樸€佽竟闀夸箻 s 鈥斺€?涓庣湡瀹炲皝闈㈢殑
    // `scale({centerX:'50%',centerY:'50%'})` 瀹屽叏鍚屽彛寰勩€?
    const endX: number = this.endCoverX + (this.endCoverSize - endSize) / 2;
    const endY: number = this.endCoverY + (this.endCoverH - endH) / 2;
    return {
      x: this.snapStartX + (endX - this.snapStartX) * t,
      y: this.snapStartY + (endY - this.snapStartY) * t,
      size: this.snapStartW + (endSize - this.snapStartW) * t,
      height: this.snapStartW + (endH - this.snapStartW) * t,
      radius: startRadius + (endRadius - startRadius) * t
    };
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?澹冲眰娴眰鎷疯礉锛堝鏍囨棤鐣?`MainPage.MorphOverlayHost` 閲岀殑 `morphCover`锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 缁撴瀯锛?*涓ゅ眰**锛屼袱涓繘搴﹀悇鑷埌鐐癸級锛?
  //   路 涓?灞?= 鎾斁椤佃嚜宸憋細`morphP` 椹卞姩鐨勬暣椤?scale/translate/clip锛?*350ms `Curve.EaseInOut`**
  //     锛堣皟鐢ㄧ偣娌″姩锛歚PlaybackPage.MORPH_OPEN_DURATION_MS`锛夛紱
  //   路 涓?灞?= **澹冲眰娴眰**锛坄products/default .../Index.ets` 鐨?`MorphCoverClone()`锛夛細
  //     `morphOverlayP` 椹卞姩锛?*560ms + `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)`**銆?
  //
  // 涓轰粈涔堟诞灞傞偅浠借鍗曠嫭涓€涓繘搴︼細瀹?*涓嶅湪鎾斁椤电殑褰㈠彉瀹瑰櫒閲?*锛堜笉鍙?scale/translate/clip 褰卞搷锛?
  // 鐩存帴鎸夌獥鍙ｅ潗鏍囨憜鍦ㄥ３灞傜殑婊″睆 Stack 涓婏級锛屾墍浠ュ畠鍙互鏄畬鍏ㄤ笉鍚岀殑涓€鏉℃椂闂寸嚎锛?
  // 瀵归綈鏃犵晫涔嬪悗瑙傛劅灏辨槸"灏侀潰妯┛灞忓箷椋炶繃鍘?鑰屼笉鏄?鏁撮〉浠庤糠浣犳潯浣嶇疆闀垮ぇ"銆?

  /** @returns 娴眰鎷疯礉鐨勮繘搴︼紙澶圭揣鍒?0鈥?锛夈€?*/
  public morphOverlayProgress(): number {
    const p: number = this.morphOverlayP;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  /**
   * @returns 澹冲眰娴眰閭ｄ唤缁灏侀潰鐨勭煩褰紙vp锛?*绐楀彛鍧愭爣**锛夈€?
   *
   * 杩涘害 = `morphOverlayP`锛?60ms 閭ｅ眰锛夛紝涓?`morphCoverBridge()`锛堟挱鏀鹃〉閭ｄ唤锛岃繘搴?= `morphP`锛?
   * **鍏辩敤鍚屼竴娈电函鍑犱綍**锛坄morphCoverRectAt`锛夛紝鍙槸鎻掑€煎弬鏁颁笉鍚屻€?
   * 鈿狅笍 澹冲眰鐩存帴鎷垮畠褰?`.position()` / `.width()` 鐢紝**涓嶅仛浠讳綍"椤靛唴 鈫?绐楀彛"鎹㈢畻**銆?
   */
  public morphOverlayCoverBridge(): LyricMorphRect {
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫鐨勫皝闈㈢粨鏋?* 鈥斺€?鐢ㄦ埛鎸囩ず銆屼綘搴旇鐓ф惉鏃犵晫鐨勩€嶏級
    //
    // ## 鏃犵晫鏄?*涓€寮犲皝闈€佷竴鏉℃椂闂寸嚎**
    // ```
    //   floatingCover锛堢敾鍦?playerPane 閲屻€佺敤 .position/.width 鎽嗭級
    //     灏哄 = edge 脳 scaleAt(t)      鈫?CoverMorph 绾嚑浣曪紝85856 閭ｄ竴妗?
    //     浣嶇疆 = tyAt(t) / txAt(t)      鈫?绾嚑浣?
    //     鍦嗚 = radiusAt(t)
    //   鈬?瀹?*涓嶅彈浠讳綍瀹瑰櫒 scale 褰卞搷**锛岃繘搴?t 涓€甯т竴鍙?鈬?澶╃劧"涓€闀滃埌搴?
    // ```
    // ## 鎴戜滑涔嬪墠涓轰粈涔堝儚"灏侀潰璺熺潃鎾斁椤佃蛋"
    // ```
    //   灏侀潰鐢诲湪 LyricFloatLayer 閲岋紝鑰岄偅涓€灞?*鍦ㄥ舰鍙樺鍣ㄥ唴閮?*
    //   鈬?瀹冭"绾嚑浣?鎽嗗ソ涔嬪悗**鍙堣瀹瑰櫒鐨?morphScale 缂╀簡涓€娆?*
    //   鈬?灞忎笂鐪嬪埌鐨勬槸"椤甸潰鍦ㄧ缉銆佸皝闈㈣窡鐫€椤甸潰涓€璧风缉" = 鐢ㄦ埛璇寸殑銆岃窡闅忕潃鎾斁鍣ㄣ€?
    // ```
    // ## 鐓ф惉鍋氭硶锛堟湰鍑芥暟灏辨槸閭ｄ竴妫掞級
    //   澹冲眰杩欎唤"缁灏侀潰"**鍦ㄥ鍣ㄤ箣澶?*锛堟弧灞?Stack 涓婏級锛岀敤**绐楀彛鍧愭爣**鐩存帴钀戒綅
    //   鈬?鍙鎶婂畠鐨勮繘搴︽帴鎴?*椤甸潰杩涘害 `morphP`**锛屽氨绛変簬鏃犵晫閭ｅ紶 `floatingCover`锛?
    //     涓€寮犲皝闈€佷竴鏉℃椂闂寸嚎銆佺函鍑犱綍銆佷笉鍙楀鍣ㄥ彉鎹€?
    //   鈿狅笍 浠嶇劧淇濈暀 `morphOverlayProgress()` 閭ｆ潯鐙珛鏃堕棿绾跨殑**鑳藉姏**锛坄morphOverlayP`
    //     鏄３灞?`settlePullOpen` 鐢ㄧ殑 560ms 蹇嚭鎱㈡敹閭ｄ竴妫掞級锛涜繖閲屾敼鐨勬槸**钀戒綅鎵€鐢ㄥ嚑浣?*锛?
    //     涓嶆槸搴熷純閭ｄ竴妫掞細`morphP` 鏄富椹卞姩锛屽姩鐢绘湡闂翠袱鑰呭悓鍚戞帹杩涖€?
    //   鈿狅笍 鍙?`morphP` 鑰?*涓嶆槸** `morphOverlayP` 鐨勫師鍥狅細鍚庤€呭湪寮傚父璺緞涓婁細鍋滃湪 0
    //     锛堣 `morphOverlayTweenTo` 鐨?`|to-from|<1e-4` 鏃╅€€锛夆噿 灏侀潰浼氫竴鍔ㄤ笉鍔ㄥ湴璐村湪杩蜂綘鏉′笂銆?
    return this.morphCoverRectAt(this.morphP);
  }

  /**
   * @returns 澹冲眰娴眰瑕佷笉瑕佺敾杩欎唤灏侀潰鎷疯礉銆?
   *
   * 涓や釜鏉′欢锛?
   *   1. `morphBridging()` 鈥斺€?涓庢挱鏀鹃〉閭ｄ竴妫?*瀹屽叏鍚屼竴鎶婇棬**锛堢浉浣?涓ょ鐭╁舰鐨勬棦鏈夊垽鎹竴涓瓧娌℃敼锛夛紱
   *   2. `hostsMorphOverlay()` 鈥斺€?瀹夸富澹冲眰杩欐鏄笉鏄湡鐨勬帴绠′簡杩欎竴妫掞紙PC 澹冲眰杩樻病鎺?鈬?涓嶇敾锛?
   *      鍚﹀垯浼氬嚭鐜?鎾斁椤典篃涓嶇敾銆佹诞灞備篃涓嶇敾"鐨?*鏃犲皝闈?*绌烘。锛夈€?
   *
   * 鈿狅笍 **2026-10-15 璁㈡**锛氳繖閲屽師鏉ュ啓鐫€"娴眰杩欎竴妫?*鏃╀簬**鎾斁椤佃惤浣嶏紙560 vs 350锛?鈥斺€?
   *   **璇村弽浜?*锛?60 > 320锛屾诞灞傛槸**鏅?*鐨勯偅涓€鏉°€傛鍥犱负鍐欏弽浜嗭紝鎵嶆紡鎺変簡
   *   "鎾斁椤佃惤浣嶆椂鎶婃诞灞傛帎鏂?杩欎釜 bug锛堣涓嬮潰绗簩涓垽鎹殑娉ㄩ噴锛夈€?
   */
  public morphOverlayBridging(): boolean {
    // 鈽呪槄鈽呪槄 2026-10-17锛?*蹇収鏀剁缉閭ｆ潯璺笂锛屾诞灞備笉璁稿啀鐢讳竴寮犲皝闈?* 鈥斺€?
    //   淇敤鎴峰疄娴嬨€屽叧闂椂浼氬嚭鐜颁袱涓皝闈紝涓€涓槸璺熼殢鎾斁鍣ㄧ殑锛屽彟涓€涓槸姝ｅ父椋炲洖鍘荤殑銆嶏級
    //
    // 鏈哄埗锛氶潪鎵嬪娍鍏抽棴锛堝叧闂寜閽?/ 绯荤粺杩斿洖锛夎蛋 `PlaybackPage.closeWithAnimation()` =
    //   鐓ф惉鏃犵晫鐨?鎷嶆弧绐楀揩鐓?鈫?缂╁埌鑳跺泭"锛坄wujie.pa:171054-171095`锛夈€傞偅鏉¤矾涓?
    //   **鐢婚潰宸茬粡鍦ㄤ竴寮犲揩鐓ч噷**锛堝綋鐒朵篃鍖呭惈灏侀潰锛夛紝鑰屽畠闅忓悗浼?`morphLand()` 鎶婄浉浣嶇疆鎴?
    //   `LANDING` 鈥斺€?鑰?`LANDING` 鍦?`morphContainerActive()` 閲岀畻"鐪熺殑鍦ㄦ挱" 鈬?
    //   涓嬮潰鏈€鍚庨偅鏉?鐩镐綅鍏滃簳"浼氭妸**澹冲眰鍏嬮殕灞?*涔熷彨璧锋潵 鈬?
    //   **蹇収閲岄偅寮犲皝闈?+ 鍏嬮殕灞傞偅寮犲皝闈㈠悓鏃堕** = 鐢ㄦ埛鐪嬪埌鐨勪袱涓皝闈€?
    //   鈬?鐢?`beginSnapshotShrink()` 缃綅鏈熼棿锛屾湰鍑芥暟鎭掑亣锛?*蹇収鑷繁灏辨槸閭ｄ竴妫?*銆?
    //   鈿狅笍 鍙湪蹇収**鎴愬姛**閭ｄ竴鏀疆浣嶏紙澶辫触鏀€€鍥炴椿椤靛舰鍙橈紝浠嶉渶瑕佹诞灞傞偅涓€妫掞級銆?
    //   鈿狅笍 浼氳瘽杈圭晫鐢?`morphReset()` 娓呮帀锛屼笉浼氭畫鐣欍€?
    if (this.snapshotShrinkOwned) {
      return false;
    }
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫锛氬３灞傚厠闅嗗眰鍙湪"涓嬫媺浼氳瘽"閲屽瓨鍦?* 鈥斺€?
    //   淇敤鎴峰疄娴嬨€屼袱涓皝闈?*闅忔満**鍑虹幇锛岀害涓€鍗婃鐜囥€嶏級
    //
    // ## 涓婃父鐨勫舰鐘讹紙璇昏嚜褰掓。 `Cover鏃忎笌娆＄骇UI瀹氱.md` 搂5.2 + `MainPage`锛?
    // ```
    //   MorphOverlayHost({ content: this.cbMorphOverlay })     鈫?MainPage 閭ｄ竴灞?椋炶灏侀潰"
    //     @StorageProp(K_PULL_ACTIVE) on                        鈫?闂?= **涓嬫媺浼氳瘽鏄惁娲荤潃**
    //     build() { if (this.on) { this.content.bind(this)() } }
    //   鈬?鍙湁 `lx_pull_active` 涓虹湡鏃舵墠鐢婚偅涓€寮狅紱鍏跺畠鍏ュ彛锛堢偣鍑诲叧闂?/ 绯荤粺杩斿洖锛?
    //     璧?**蹇収鏀剁缉**锛屽睆涓?*鍙湁蹇収閲岄偅涓€寮?*銆?
    // ```
    //   鏈粨鐨勭瓑浠风墿灏辨槸 `pullMode`锛坄pullOpenBegin` 缃湡 / `morphReset` 缃亣锛夈€?
    //   鎴戜滑鍘熸潵鐢?鍑犱綍/杩涘害/鐩镐綅"涓夋潯**璁＄畻寮?*鍘荤寽"娴眰鏄笉鏄偅涓€妫?锛岃€屽畠涓庡３灞傞偅鏉?
    //   琛ラ棿鐨勮捣鎵嬫椂鍒讳笉鍚岄挓 鈬?鎬绘湁涓€鍗婄殑鍏抽棴浼氳俯杩涚┖妗?鈬?鐢ㄦ埛鐪嬪埌鐨?闅忔満涓ゅ紶灏侀潰"銆?
    //   鈬?鐜板湪鐓т笂娓革細**涓嶆槸涓嬫媺浼氳瘽灏变竴寰嬩笉鐢辨诞灞傜敾**锛岀敱椤甸潰鑷繁鐨勫皝闈?蹇収璐熻矗銆?
    // 鉀?2026-10-17锛?*鎸夊叆鍙ｅ垎娴侀偅涓€鐗堝凡鎾ゅ洖** 鈥斺€?鐢ㄦ埛瀹炴祴銆岀幇鍦ㄤ笉浼氭湁灏侀潰椋炲叆椋炲嚭锛屽彧浼氳窡闅?
    //   鎾斁鍣紝鏃犵晫閭ｄ釜鍙湁椋炲叆椋炲嚭銆嶏級
    //   鎴戞浘鐓?`MorphOverlayHost` 鐨?`lx_pull_active` 闂ㄦ妸闈炰笅鎷夊叆鍙ｄ篃鎸℃帀锛岀粨鏋滅偣鍑绘墦寮€/鍏抽棴鏃?
    //   鏍规湰娌℃湁浜?椋?灏侀潰 鈬?涓庢棤鐣屽畬鍏ㄤ笉鍚屻€傛棤鐣岀殑瑙傛劅鏄細**褰㈠彉鏈熼棿閭ｅ紶灏侀潰姘歌繙鏄鐨勯偅涓€寮?*
    //   锛坄floatingCover` 鎸夌函鍑犱綍 `txAt/tyAt` 鎻掑€硷紝鏈韩涓嶈窡鐫€瀹瑰櫒缂╂斁锛夈€?
    //   鈬?銆岄殢鏈轰袱寮犲皝闈€嶇殑姝ｇ‘娌绘硶鏄?*璁╃湡灏侀潰鍦ㄤ細璇濇湡闂存亽涓嶇敾**锛坄realCoverVisible()`锛夛紝
    //     鑰屼笉鏄妸椋炵殑閭ｄ竴寮犲叧鎺夈€?
    // 鈽呪槄鈽?2026-10-17锛堢収杩欐潯淇€屽彧浼氳窡闅忔挱鏀惧櫒銆嶏級锛?*鍙浼氳瘽鍦ㄩ┍鍔ㄣ€佷笖娴眰涓ょ鍑犱綍鏈夋晥锛?
    //   娴眰灏辨槸鍞竴鐢诲**锛堜笌 `realCoverVisible()` 鐨勯偅涓€鏉′弗鏍间簰琛ワ級銆?
    if (this.hostsMorphOverlay() && this.morphSessionDriving() && this.overlayCoverDrawable()) {
      return true;
    }


    // 鈿狅笍 涓嬮潰杩欐鏄?*涓婁竴鐗?*銆岀敤浼氳瘽姝ｅ湪椹卞姩鏉ュ厹鏃跺簭绌烘。銆嶇殑鍒ゆ嵁锛岀幇宸茬敱涓婇潰閭ｆ潯
    //   `pullMode` 鍙栦唬锛堜笂娓稿氨鏄繖涔堥棬鐨勶級銆傜暀鐫€杩欐璇存槑鏄负浜嗗埆鍐嶉€€鍥炲幓锛?
    //   闈炴墜鍔垮叧闂?*涓嶄竴瀹?*閮借兘鎷嶅埌蹇収 鈥斺€?澶辫触鏀細閫€鍥炴椿椤靛舰鍙橈紙`closeLiveMorphFallback`锛夛紱
    //   閭ｆ潯璺笂椤甸潰 350ms銆佹诞灞?560ms 涓ゆ潯琛ラ棿**涓嶅悓閽?*锛堟诞灞傜敱 `@Monitor` 寮傛璧凤級锛?
    //   鎵€浠?鐢ㄨ绠楀紡鐚滆皝鍦ㄧ敾"蹇呯劧鏈変竴鍗婅俯杩涚┖妗?鈬?鐢ㄦ埛鐪嬪埌鐨?闅忔満涓ゅ紶灏侀潰"銆?
    //   鈬?鐜板湪涓ゆ潯璺兘鏄?*缁撴瀯涓婄‘瀹?*鐨勶細
    //     路 `pullMode`锛堜笅鎷変細璇濓級鈬?娴眰鐢伙紝鎾斁椤电湡灏侀潰璁╀綅锛坄realCoverVisible()` 鍙嶇潃鏉ワ級锛?
    //     路 鍏跺畠鍏ュ彛 鈬?娴眰**鎭掍笉鐢?*锛氬揩鐓ф垚鍔熼偅鏉″彧鏈夊揩鐓ч噷閭ｄ竴寮狅紱蹇収澶辫触閫€娲婚〉褰㈠彉鏃?
    //       鐢?*鎾斁椤佃嚜宸辩殑灏侀潰**璺熺潃瀹瑰櫒璧帮紙`realCoverVisible()` 鎭掔湡锛夈€?
    // 鈽呪槄鈽?2026-10-16锛?*鎭㈠**锛涙垜涓婁竴鐗堟妸瀹冩亽缃?`false`锛岄偅鏄釜閿欒锛?
    //
    // ## 涓轰粈涔堝繀椤绘仮澶嶏細杩欐墠鍙?鐓ф惉鏃犵晫鐨勫皝闈?
    //
    // 鏃犵晫鐨勫皝闈㈡槸**涓€闀滃埌搴?*锛岃€屽畠闈犵殑鏄?*灏侀潰鐢诲湪涓€涓病鏈夐澶栧彉鎹㈢殑娴眰閲?*銆?
    // 鐢?*绐楀彛鍧愭爣鎻掑€?*椋炶繃鍘伙紙`CoverMorph` 鍏ㄧ▼涓嶆煡浠讳綍鑺傜偣銆佷篃涓嶅彈 `playerPane`
    // 閭ｅ scale/translate 褰卞搷锛夈€?
    // 鎴戜滑杩欎竴渚?*鏈潵灏辨湁鍚屾瀯鐨勪竴灞?*锛歚products/default/.../Index.ets` 鐨?
    // `MorphCoverClone()` 鈥斺€?瀹冧笌鎾斁椤靛舰鍙樺鍣?*鍚岀骇**锛堝湪澹冲眰婊″睆 `Stack` 涓婏級锛?
    // 鎷?`morphOverlayCoverBridge()`锛? `morphCoverRectAt(morphOverlayP)`锛岀獥鍙ｅ潗鏍囷級
    // 鐩存帴褰?`.position()` 鐢ㄣ€?*杩欎竴灞傚湪鐪熸満涓婃槸濂界殑**锛堢敤鎴锋鍓嶉獙鏀惰繃"灏侀潰姝ｅ父"锛夈€?
    //
    // 鎴戜笂涓€鐗堝叧鎺夊畠銆佹敼璁╂挱鏀鹃〉閲岄偅寮犵湡灏侀潰鐙嚜鎵挎媴锛岀粨鏋滄槸锛氱湡灏侀潰鎸傚湪**琚?scale 鍙樻崲杩?*
    // 鐨勫舰鍙樺鍣ㄩ噷锛岃€屽鍣ㄥ舰鍙樹腑"璐村湪灞忓箷椤堕儴閭ｄ竴鏉?锛坄morphTy 鈮?+844`銆乣scale 鈮?0.082`锛?
    // 鈬?鍩哄噯浣嶇殑灏侀潰琚惉鍒?*灞忓箷椤堕儴**銆佽€岃糠浣犳潯鍦?*灞忓箷搴曢儴** 鈬?瑙傛劅鎴愪簡
    // 銆?*灏侀潰浠庝笅寰€涓婇**銆嶏紙鐢ㄦ埛 2026-10-16 瀹炴祴锛夈€?
    //
    // 鈬?鎭㈠"娴眰鐢汇€佺湡灏侀潰璁╀綅"杩欏浜ゆ銆?*杩欐墠鏄棤鐣岀殑缁撴瀯銆?*
    // 鈿狅笍 閭ｄ袱鏉?浜ゆ鍥烘湁姣涚梾"锛堜袱鏉¤ˉ闂翠笉鍚岄挓 / 鐪熷皝闈㈢獥鍙ｅ潗鏍囪鍙樻崲鎷夊亸锛?*鏄湡鐨?*锛?
    //   浣嗗畠浠凡缁忚涓嬮潰涓夋潯鍒ゆ嵁鍏滀綇浜嗭紙瑙佺浜屼釜鍒ゆ嵁鐨勬敞閲婏級鈥斺€?*涓嶈**鍥犱负閭ｄ袱鏉″氨鍐嶅叧涓€娆°€?
    // 鈿狅笍 `metaBridgeOwnsPaint()` 浠嶇劧鎭?`false`锛堟瓕鍚?姝屾墜**涓?*璺熺潃椋烇紝鐢ㄦ埛鏄庣‘瑕佹眰杩囷級锛?
    //   涓よ€呬笉鍐茬獊锛氭诞灞傝繖涓€灞傚湪鏈粨**鍙敾灏侀潰**锛坄MorphCoverClone` 閲屽彧鏈変竴寮?`Image`锛夈€?
    if (!this.hostsMorphOverlay()) {
      return false;
    }
    if (this.morphBridging()) {
      return true;
    }
    // 鈽呪槄 2026-10-15锛堢収鎼棤鐣屻€屼袱灞傚悇璺戝悇鐨勩€佷簰涓嶆墦鏂€嶏級锛?
    //   鎾斁椤佃惤浣嶄箣鍚?*涓嶈**绔嬪埢鎾ゆ帀娴眰銆?
    //
    //   瀹炴祴鏃跺簭锛堥兘鍦ㄨ繖浠戒唬鐮侀噷锛夛細
    //     路 鎾斁椤甸偅鏉?= `Index.settlePullOpen` 鐨?`PULL_OPEN_SETTLE_MS + 20`
    //       鈬?**320ms** 灏?`morphSettleOpen()`锛宍morphBridging()` 闅忎箣鍙樺亣锛?
    //     路 娴眰閭ｆ潯   = `MORPH_OVERLAY_DURATION_MS(560)`銆?
    //   鈬?鍘熸潵娴眰鍦?320/560 鈮?**57% 澶勮鎾ゆ帀**锛岃鎰熷氨鏄?钀戒綅閭ｄ竴甯у皝闈㈣烦涓€涓?
    //      锛堟棤鐣屾病鏈夎繖涓瘺鐥咃細瀹冪殑鍐呭眰涓庢诞灞傛槸**涓ゆ潯鐙珛琛ラ棿**锛岃皝鍏堝埌璋佸厛鍋滐紝涓嶄簰鐩稿彇娑堬級銆?
    //
    //   鍒ゆ嵁鏀规垚"**娴眰鑷繁杩樺湪鍗婅矾灏辩户缁敾**"锛?
    //     路 灞曞紑璺戝埌 p = 1銆佹敹璧疯窇鍒?p = 0 鎵嶅仠绗旓紱
    //     路 闈欐鎬佷笉浼氬鐢讳竴寮狅紙灞曞紑鎬?p = 1銆佹敹璧锋€?p = 0锛屼袱绔兘琚帓闄わ級锛?
    //     路 涓?`morphBridging()` 鏄?*鎴?*鍏崇郴锛屾墍浠ヨ捣鎵嬮偅涓€甯э紙p 鎭板ソ涓?0锛変粛鐢卞畠鍏滀綇锛?
    //       涓嶄細鍑虹幇"涓よ竟閮戒笉鐢?鐨勭┖妗ｃ€?
    const p: number = this.morphOverlayProgress();
    if (p > 0.001 && p < 0.999) {
      return true;
    }
    // 鈽呪槄 2026-10-15锛堜慨鐢ㄦ埛瀹炴祴銆?*涓嬫媺鍏抽棴鏃跺皝闈㈠姩鐢诲彉鎴愬睍寮€閭ｄ竴濂?*銆?銆?*绯荤粺杩斿洖鍏抽棴娌℃湁灏侀潰鍔ㄧ敾**銆嶏級锛?
    //   涓婇潰閭ｆ潯"娴眰鑷繁杩樺湪鍗婅矾"鐨勫垽鎹湁涓€涓?*鏂瑰悜鎬ф紡娲?* 鈥斺€?瀹冨彧鐪?`morphOverlayP`銆?
    //   鑰屾敹璧疯矾涓婃渶瀹规槗鍑虹幇鐨勬儏鍐垫伆鎭版槸"涓ゆ潯琛ラ棿鍚岃捣鍚岃惤銆佹诞灞傝繘搴﹀湪**鍚屼竴甯?*灏辫
    //   鎾斁椤甸偅鏉¤惤浣嶉摼璺竻鍥?0"锛坄morphLand()` 鈫?`releaseMorphOwnership` 鈫?`morphReset()`锛夛紝
    //   閭ｄ竴鍒?`p` 宸茬粡绛変簬 0 鈬?鏈嚱鏁拌繑鍥?false 鈬?**灏侀潰涓村埌钀戒綅鍓嶈鎺愭帀**锛?
    //     路 鐢ㄦ埛鐪嬪埌鐨勫氨鏄?灏侀潰娌℃湁鎸夋敹璧烽偅涓€濂楃缉鍥炶糠浣犳潯"锛堢瓑浜庢病鏈夊皝闈㈠姩鐢伙級锛?
    //     路 鑰屾挱鏀鹃〉閭ｄ竴灞備粛鍦?460ms 閲岀缉鏀撅紝浜庢槸"鐪嬭捣鏉ュ儚灞曞紑閭ｄ竴濂?銆?
    //   鈬?琛ヤ竴鏉?*涓庤繘搴︽棤鍏炽€佸彧鐪嬬浉浣?*鐨勫厹搴曪細鍙褰㈠彉瀹瑰櫒杩樻椿鐫€
    //     锛圗NTERING / LEAVING / LANDING锛夛紝杩欎竴妫掑氨**蹇呴』缁х画鐢?*銆?
    //     闈欐鎬侊紙OPEN / NONE锛変粛鐒朵笉鐢?鈬?涓嶄細澶氱暀涓€寮犲皝闈€?
    //   鈿狅笍 涓?`morphBridging()` 浠嶆槸"鎴?鍏崇郴锛氬嚑浣曟病閲忛綈锛坄snapStartW/endCoverSize` 涓?0锛夋椂
    //      鏈嚱鏁颁篃鐢讳笉鍑烘潵锛堢煩褰㈠紡瀛愬叏鏄?0锛夛紝鎵€浠ヤ笉浼氱敾鍑?0脳0 鐨勫皝闈?銆?
    return this.morphContainerActive() && this.snapStartW > 0 && this.endCoverSize > 0;
  }

  /**
   * @returns 褰㈠彉瀹瑰櫒鐨?*鑷韩灏哄**锛坴p锛岀獥鍙ｅ潗鏍囧彛寰勶級鈥斺€?鍙粰 {@link coverLocalRectFor} 鍋氬弽鍙樻崲鐢ㄣ€?
   *
   * 瀹瑰櫒鏄?鏁村 + 瑁佸壀绐楀彛楂?锛坄PlaybackPage.build()` 閲?`.height(morphClipHeight())`锛夛細
   * 褰㈠彉涓珮搴?= `morphClipHeight`锛岄潤姝㈡€?= 绐楀彛楂樸€?
   * 鈿狅笍 杩欎袱涓噺涓?`applyMorphProgress()` 閲岀畻 `morphTx/morphTy` 鐢ㄧ殑鏄?*鍚屼竴缁勮緭鍏?*
   *   锛坄morphBoxWidth/Height` 閭ｄ竴妗ｏ級锛屾敼涓€澶勫繀椤绘敼鍙︿竴澶勶紝鍚﹀垯鍙嶅彉鎹細宸竴鎴€?
   */
  private coverHostW(): number {
    // 瀹瑰櫒鏄?`.width('100%')`锛? 瀹夸富婊″睆瀹斤級鈬?鐩存帴鍙栫獥鍙ｅ銆?
    // 鈿狅笍 **涓嶈**鐢?`morphBoxWidth()`锛氶偅涓槸"琚噺鍒扮殑鍐呭瀹?锛坄contentWidthVp`锛夛紝
    //   涓庡鍣ㄨ嚜宸辩殑甯冨眬瀹戒笉鏄悓涓€涓噺锛屾贩鐢ㄤ細璁╁弽鍙樻崲妯悜宸竴鎴€?
    return this.windowWidthVp;
  }

  private coverHostH(): number {
    if (this.morphClipping() && this.morphClipHeight > 0) {
      return this.morphClipHeight;
    }
    return this.windowHeightVp;
  }

  /**
   * 鎶?*灞忓箷鍧愭爣**鐨勫皝闈㈢煩褰紝鎹㈢畻鎴愬舰鍙樺鍣?*鏈湴**鐨?`.position()` / `.width()` 鍊笺€?
   *
   * @deprecated **闆惰皟鐢ㄨ€咃紝涓旀柟娉曟湰韬湪鐪熸満涓婅璇佷吉杩?鈥斺€?涓嶈鎺ヤ笂瀹冦€?*
   *
   * ## 涓轰粈涔堢暀鐫€瀹冿紙鑰屼笉鏄垹鎺夛級
   *
   * 瀹冪殑鎺ㄥ鏈韩鏄?*瀵圭殑**锛堝氨鏄鍣ㄥ彉鎹?`y_灞?= H/2 + (y_鏈?鈭?H/2)s + d` 鐨勯€嗭級锛?
   * 浣嗗畠渚濊禆涓€涓?*鍦ㄦ湰浠撲笉鎴愮珛鐨勫墠鎻?*锛歚.scale()` 缁?*瀹瑰櫒涓績**銆?
   *
   * 鐪熸満鍙嶈瘉锛堟湰浠撴湁涓ゆ鐙珛璁板綍锛夛細
   * 路 `morphCoverRectAt()` 鐨勬敞閲婏細閫嗗彉鎹㈠洖椤靛唴鍧愭爣 鈬?鐪熸満缁撴灉"**灏侀潰璺戝埌宸︿笂瑙?*"
   *   锛堣鏄?`.scale()` 鐨勬灑杞翠笉鏄垜浠ヤ负鐨勫鍣ㄤ腑蹇冿級锛?
   * 路 2026-10-16 `PlaybackPage.coverLocalRect()`锛氭垜鍘熷湴閲嶈俯涓€閬嶏紝鐢ㄦ埛瀹炴祴
   *   銆?*灏侀潰鏄鍒板睆骞曞**銆嶁噿 鍐嶆璇佹槑璇ュ墠鎻愪笉鎴愮珛銆?
   *
   * 鈬?鐜板湪鐨勫仛娉曟槸 `PlaybackPage.coverLocalRect()` **鐩存帴杩斿洖 `lyricFloatRect()`**
   *   锛堢函鍑犱綍銆侀浂鎹㈢畻锛夈€傜暀杩欎釜鍑芥暟鏄负浜嗕笅娆℃湁浜烘兂"閫嗗彉鎹竴涓?鏃讹紝
   *   鑳藉厛鐪嬪埌**涓ゆ鐪熸満鍙嶈瘉**鍐嶅喅瀹氾紝鑰屼笉鏄涓夋閲嶈俯銆?
   */
  public coverLocalRectFor(screen: LyricMorphRect): LyricMorphRect {
    const s: number = Math.max(0.05, this.morphScale);
    const w: number = this.coverHostW();
    const h: number = this.coverHostH();
    const tx: number = this.morphTx;
    const ty: number = this.morphTy;
    return {
      x: w / 2 + (screen.x - w / 2 - tx) / s,
      y: h / 2 + (screen.y - h / 2 - ty) / s,
      size: screen.size / s,
      height: screen.height / s,
      radius: screen.radius / s
    };
  }

  /** @returns 娴眰鎷疯礉鐨勪笉閫忔槑搴︼紙涓庢挱鏀鹃〉閭ｄ唤鍚屽彛寰勶細鐢荤殑鏃跺€欐亽 1锛夈€?*/
  public morphOverlayBridgeOpacity(): number {
    return this.morphOverlayBridging() ? 1 : 0;
  }

  /**
   * @returns 褰撳墠 shell 鏄惁鑷繁閲嶇粯浜嗙画椋炲皝闈紙= 鎾斁椤靛簲**鍋滅敤**鑷繁鐨?`MorphCoverBridge`锛夈€?
   *
   * 鍒ゆ嵁鐢?*璁惧绫诲瀷**锛坄2in1` = PC/骞虫澘绗旂數褰㈡€侊級锛氭湰杞殑娴眰鍙惤鍦?`products/default`
   * 澹冲眰锛孭C 澹冲眰锛坄products/pc/.../Index.ets`锛夋病鏈?`MorphMiniBarClone`锛屼篃娌℃帴杩欎唤娴眰 鈬?
   * 鍦?PC 涓?*缁х画鐢辨挱鏀鹃〉鑷繁鐢?*锛堣涓轰笌鏀瑰姩鍓嶉€愬瓧涓€鑷达級锛岄伩鍏?涓よ竟閮戒笉鐢?銆?
   *
   * 鈿狅笍 杩欐鏄?*涓存椂鑴氭墜鏋?*锛氱瓑娴眰涔熻惤鍒?PC 澹冲眰鍚庯紝鎶婅繖閲屾敼鎴愬父閲?`true`
   *   锛堟垨鐩存帴鍒犳帀杩欎釜鍑芥暟涓庡畠鐨勮皟鐢ㄧ偣锛夈€?
   */
  public hostsMorphOverlay(): boolean {
    // 鈿狅笍 缁撴灉瑕?*缂撳瓨**锛氳繖涓嚱鏁板湪娓叉煋闂ㄩ噷琚€愬抚璋冪敤锛坄MorphCoverClone` 閭ｄ釜 `if`锛夛紝
    //    鑰?`deviceInfo.deviceType` 鏄郴缁熷睘鎬ц鍙栵紝涓嶈姣忓抚闂竴娆°€?
    //    璁惧绫诲瀷涓€娆¤繍琛屽唴涓嶄細鍙橈紝缂撳瓨鏄畨鍏ㄧ殑銆?
    if (this.morphOverlayHostCached < 0) {
      try {
        this.morphOverlayHostCached = deviceInfo.deviceType !== '2in1' ? 1 : 0;
      } catch (err) {
        // 鍙栦笉鍒拌澶囩被鍨嬫椂鎸?鎾斁椤佃嚜宸辩敾"澶勭悊锛氬畞鍙涓€灞備篃涓嶈涓€寮犻兘娌℃湁
        Logger.warn(PlayerExpandState.logTag, `hostsMorphOverlay: deviceType unavailable ${err}`);
        this.morphOverlayHostCached = 0;
      }
    }
    return this.morphOverlayHostCached === 1;
  }

  /**
   * 浼氳瘽寮€濮?澶嶄綅锛氭妸娴眰杩涘害鍘嬪洖璧风偣骞朵腑鏂畠鑷繁鐨勮ˉ闂淬€?
   *
   * 鈿狅笍 璧锋墜閭?*涓€甯?*寰堝叧閿細`morphOverlayP` 鐨勫垵鍊兼槸 1锛堥潤姝㈡€佽涔夛級锛岃嫢涓嶅帇鍥?0锛?
   * 娴眰鐨勭涓€甯у氨浼氱敾鎴愬ぇ灏侀潰锛堣鎰熸槸"闂竴涓嬪ぇ鍥?锛夈€?
   */
  public morphOverlayReset(): void {
    this.morphOverlayGen = this.morphOverlayGen + 1;
    this.morphOverlayAnimating = false;
    // 鈽?浼氳瘽杈圭晫锛氭妸"鏈疆鏀惰捣宸茶璧疯繃"鐨勬爣璁颁篃鏀炬帀锛屽惁鍒欎笅涓€娆℃敹璧蜂細闈欓粯璺宠繃娴眰閭ｄ竴妫?
    this.morphOverlayCollapseOwned = false;
    // 鈽?2026-10-17锛?*杩欓噷涓嶅啀娓?`snapshotShrinkOwned`**
    //   鐢ㄦ埛瀹炴祴銆岀郴缁熻繑鍥炲叧闂?*鏈夋椂鍊?*浼氬嚭鐜颁袱涓皝闈€嶁€斺€?蹇収閭ｅ紶 + 鍏嬮殕灞傞偅寮犮€?
    //   鍘熷洜灏辨槸杩欓噷锛氬揩鐓ц捣鏉ヤ箣鍚庨摼鏉￠噷杩樹細璧板埌涓€娆?`morphOverlayReset()`锛堜緥濡?`morphLand()`
    //   鎴栧嵏杞介摼锛夛紝鎶?杩欎竴鍏冲綊蹇収"鐨勬爣璁版竻鎺?鈬?鍏嬮殕灞傚張娲讳簡 鈬?绗簩寮犲皝闈㈠嚭鐜般€?
    //   鐜板湪璇ユ爣璁?*鏁磋疆浼氳瘽绮樹綇**锛屽彧鍦?{@link prepareMorphEntry}锛? 涓嬩竴娆℃墦寮€锛夐噷娓呫€傘€?
    this.morphOverlayP = 0;
    Logger.info(PlayerExpandState.logTag,
      `morph overlay reset gen=${this.morphOverlayGen} overlayP=0`);
  }

  /**
   * 鈽呪槄鈽呪槄 2026-10-17锛?*澹版槑"杩欎竴鍏虫槸蹇収鑷繁缂╁洖鍘荤殑"** 鈬?澹冲眰鍏嬮殕灞備笉鍐嶇敾灏侀潰銆?
   *
   * 璋冪敤鐐瑰彧鏈変竴涓細`PlaybackPage.closeWithAnimation()` 鐨?*蹇収鎴愬姛鏀?*锛坄morphLand()` 涔嬪墠锛夈€?
   * 瑙?{@link morphOverlayBridging} 椤堕儴閭ｆ璇存槑锛堝惁鍒欎細鍑虹幇涓ゅ紶灏侀潰鍚屾椂椋烇級銆?
   */
  /** @returns 銆岃繖涓€鍏虫槸鍚﹀綊蹇収銆嶁€斺€?鍙粰璇婃柇/鏃ュ織鐢紙浜嬩欢鏃ュ織 `CLO` 鐨?`ss=`锛夈€?*/
  public snapshotShrinkOwnedFlag(): boolean {
    return this.snapshotShrinkOwned;
  }

  public beginSnapshotShrink(): void {    if (this.snapshotShrinkOwned) {
      return;
    }
    this.snapshotShrinkOwned = true;
    Logger.info(PlayerExpandState.logTag, 'morph overlay off: snapshot shrink owns the cover');
  }

  /**
   * 璺熸墜鏈熼棿鎶婃诞灞傝繘搴︿笌鎾斁椤佃繘搴?*涓€姣斾竴鍚屾**锛堜笉璺戜换浣曡ˉ闂达級銆?
   *
   * 鎵嬫寚閭ｆ潯璺笂涓ゅ眰蹇呴』鏄悓涓€涓€硷紝鍚﹀垯鏉炬墜鏃朵細"琛?涓€涓嬶紙涓€灏忔鐬Щ锛夈€?
   * 琛ラ棿璺紙`morphOverlayTweenTo`锛変笉璧拌繖閲岋細閭ｆ潯璺笂涓ゅ眰鍒绘剰涓嶅悓姝ワ紙杩欐墠鏄袱灞傜殑鎰忎箟锛夈€?
   */
  public syncMorphOverlayFromPage(): void {
    if (this.morphOverlayAnimating) {
      return;
    }
    this.morphOverlayP = this.morphP;
  }

  /**
   * 鎾斁椤典晶寮€濮?*灞曞紑**琛ラ棿浜?鈬?澹冲眰娴眰涔熻捣鑷繁鐨?560ms 閭ｄ竴鐗堛€?
   *
   * 鈿狅笍 涓轰粈涔堢敱**澹冲眰**璋冿紙`@Monitor('expandState.morphDrive')`锛夈€佽€屼笉鏄鎾斁椤佃皟锛?
   *   娴眰涓庡畠閭ｄ唤杩涘害鏁翠釜灞炰簬澹冲眰锛坄products/default .../Index.ets`锛夛紝
   *   `@Monitor` 鏄?V2 鐨?*寮傛鐩戝惉**锛屽洖璋冨彂鐢熷湪鎾斁椤甸偅娆＄姸鎬佸啓鍏ョ殑**鍚屼竴杞?*
   *   鈬?涓ゅ眰绠?鍚岃捣"锛岃€屾挱鏀鹃〉閭?350ms 鐨勪唬鐮?*涓€琛岄兘涓嶇敤鍔?*銆?
   *   鎺掓煡鍏抽敭瀛楋細`grep RzdMorphOverlay`锛坄page-intro` / `page-collapse` / `shell-settle` 涓夎锛夈€?
   * @param ui 澹冲眰鐨?UIContext锛堣ˉ闂村繀椤诲湪瀹冧笂闈㈣捣锛?
   */
  public focusMorphOverlayForPageIntro(ui: UIContext): void {
    if (!this.hostsMorphOverlay()) {
      return;
    }
    if (this.morphDrive !== MorphDrive.ANIM || !this.morphContainerActive()) {
      return;
    }
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鐢ㄦ埛绗?2/3 鏉＄殑鏍瑰洜**锛夛細**鍙湁"姝ｅ湪灞曞紑"鎵嶈璧疯繘鍦鸿ˉ闂?*銆?
    //
    // ## 鐥囩姸锛堢敤鎴峰師璇濓級
    // ```
    //   鈶?涓嬫媺鍏抽棴锛氬皝闈㈢洿鎺ュ氨鏄渶鍒濋偅涓皬鍦嗗舰锛屽姩鐢荤粨鏉熷悗**绐佺劧鏉ヤ竴涓?鍙樺ぇ鍒颁腑闂村ぇ灏侀潰"鐨勬牱寮?*锛岀劧鍚庢秷澶?
    //   鈶?绯荤粺杩斿洖鍏抽棴锛?*鍑虹幇涓や釜灏侀潰** 鈥斺€?涓€涓窡闅忔挱鏀鹃〉寰€涓嬶紝
    //      杩樻湁涓€涓?*浠庡皬鍦嗗湀鍙樺ぇ鍒版挱鏀惧櫒閭ｄ釜浣嶇疆**
    // ```
    // ## 鏈哄埗锛堣浠ｇ爜鍗冲緱锛屼笉鏄寽锛?
    // ```
    //   鏀惰捣閭ｄ竴渚э細`closeFullScreenPlayback()` 鈫?`focusMorphOverlayForPageCollapse()`锛堟妸娴眰琛ュ埌 **0**锛?
    //              鈫?`morphBeginLeaving()` 鎶?`morphDrive` 缃垚 **ANIM**锛圠EAVING 鐩镐綅锛?
    //   澹冲眰鐩戝惉锛歚@Monitor('expandState.morphDrive') onMorphDriveChanged()`
    //              鈫?鏈嚱鏁般€傚畠鍙垽 `morphDrive === ANIM && morphContainerActive()`锛?
    //                **瀹屽叏涓嶇湅鐩镐綅** 鈬?鏀惰捣杩欎竴璺?*涔熶細鍛戒腑** 鈬?璧蜂竴鏉?**0 鈫?1 鐨?杩涘満"琛ラ棿**
    //              鈫?鑰屼笖鏈嚱鏁颁笅闈㈣繕浼氭妸 `morphOverlayCollapseOwned` **娓呮垚 false**
    //                锛堥偅鏉℃姢鏍忔湰鏉ユ槸"鍚屼竴鏂瑰悜鍙璧蜂竴娆?锛?
    //   鈬?鍚屼竴杞噷涓ゆ潯鏂瑰悜鐩稿弽鐨勮ˉ闂存墦鍦?*鍚屼竴涓?`morphOverlayP`** 涓婏紝鍚庤捣鐨勮繘鍦鸿耽
    //     鈬?澹冲眰娴眰閭ｄ唤"缁灏侀潰"鍦?*鍏抽棴杩囩▼涓湞鎾斁椤甸偅涓ぇ灏侀潰椋炲洖鍘?*
    //     鈬?灏辨槸 鈶?鐨?鏈熬绐佺劧鏉ヤ竴涓彉澶у埌涓棿閭ｄ釜澶у皝闈?銆佲憿 鐨?绗簩涓皝闈粠灏忓渾鍦堝彉澶?
    // ```
    // ## 鏀规硶
    //   鐩镐綅蹇呴』鏄?**ENTERING**锛?姝ｅ湪灞曞紑"锛夋墠鏀捐 鈥斺€?涓庝笂娓稿悓鏋勶細
    //   涓婃父閭ｄ釜娴眰鎸傚湪 `K_PULL_ACTIVE`锛坄lx_pull_active`锛変笂锛岃€屽畠**鍙敱 `setMiniOut(out)` 鍐?*锛?
    //   鏀惰捣閭ｄ竴璺蛋鐨勬槸鍙︿竴鏀紙`retargetToLiveCover()`锛夛紝**涓嶅瓨鍦ㄤ袱鏉℃柟鍚戠浉鍙嶇殑琛ラ棿鍚屾椂璺?*銆?
    //   鈿狅笍 鐐瑰嚮鎵撳紑閭ｆ潯璺粛鐒舵槸 ENTERING锛坄playMorphOpenIntro` 缃?ANIM 鏃剁浉浣嶅氨鏄?ENTERING锛?
    //     鈬?**涓嶅奖鍝嶅凡纭濂界殑"鐐瑰嚮鎵撳紑/涓婃媺鎵撳紑"**銆?
    if (this.morphStage !== MorphStage.ENTERING) {
      Logger.info(PlayerExpandState.logTag,
        `morph overlay page-intro refused (stage=${this.morphStage} drive=${this.morphDrive}) ` +
        `overlayP=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
      return;
    }
    Logger.info(PlayerExpandState.logTag,
      `morph overlay page-intro from=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
    // 杩涘叆鏂瑰悜涓€寮€璺戯紝灏辨妸"鏈疆鏀惰捣宸茶璧疯繃"鐨勬爣璁版斁鎺夛細鍚屼竴杞細璇濆唴鍏堝悗缁忓巻
    // "灞曞紑 鈫?鏀惰捣"鏃朵笉浼氳涓婁竴娆＄殑鎶ゆ爮鎸′綇锛堟姢鏍忕殑璇箟鏄?鍚屼竴鏂瑰悜鍙璧蜂竴娆?锛夈€?
    this.morphOverlayCollapseOwned = false;
    this.morphOverlayTweenTo(true, ui);
  }

  /**
   * 鎾斁椤典晶寮€濮?*鏀惰捣**浜?鈬?娴眰涔熻窡鐫€鍥炶捣鐐癸紙璧板畠鑷繁鐨?460ms锛夈€?
   *
   * 鈿狅笍 **骞傜瓑鎶ゆ爮**锛?026-10-15锛夛細鏈嚱鏁扮幇鍦ㄦ湁**涓や釜**璋冪敤鐐?鈥斺€?
   *   路 鎾斁椤电殑 `closeFullScreenPlayback()`锛?*鍚屾**锛岃捣琛ラ棿涔嬪墠锛岃繖鏄潈濞佽皟鐢ㄧ偣锛夛紱
   *   路 澹冲眰鐨?`@Monitor('expandState.morphStage')`锛?*寮傛**锛屽厹浣?鐩镐綅琚埆浜烘敼鎴?LEAVING"
   *     閭ｇ璺緞锛屾瘮濡傝糠浣犳潯/澹冲眰鑷繁鍙戣捣鐨勬敹璧凤級銆?
   *   涓や釜閮借窇灏变細**鍚勮捣涓€鏉?* `animateTo`锛氬悗璧风殑閭ｆ潯浼氭妸鍏堣捣鐨勯偅鏉¤鐩栨帀锛?
   *   鑰屽畠鐨?`from` 宸茬粡鏄?鍒氳蛋浜嗗嚑姣鐨勮繘搴? 鈬?瑙傛劅鏄皝闈㈠洖椋?*鍗′竴涓?*銆?
   *   鈬?鐢?`morphOverlayCollapseOwned` 鍋?鏈疆鏀惰捣鍙璧蜂竴娆?鐨勬爣璁帮紱
   *     瀹冪敱 {@link morphOverlayReset}锛堜細璇濈粨鏉燂級鍞竴娓呮帀銆?
   * @param ui 澹冲眰鐨?UIContext
   */
  public focusMorphOverlayForPageCollapse(ui: UIContext): void {
    if (!this.hostsMorphOverlay()) {
      return;
    }
    if (this.morphOverlayCollapseOwned) {
      Logger.info(PlayerExpandState.logTag,
        `morph overlay page-collapse skipped (owned) overlayP=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
      return;
    }
    if (this.morphOverlayAnimating) {
      // 琛ラ棿姝ｅ湪璺戯紙渚嬪澹冲眰 `settlePullOpen` 璧风殑閭ｆ潯鏂瑰悜涓€鑷寸殑锛夛細涓嶈鎶?
      Logger.info(PlayerExpandState.logTag,
        `morph overlay page-collapse skipped (animating) overlayP=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
      return;
    }
    this.morphOverlayCollapseOwned = true;
    Logger.info(PlayerExpandState.logTag,
      `morph overlay page-collapse from=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
    this.morphOverlayTweenTo(false, ui);
  }

  /**
   * 娴眰鎷疯礉鐨勮ˉ闂达紙**鍞竴涓€澶?* `animateTo`锛夈€?
   *
   * 璧风偣 = 褰撳墠娴眰杩涘害锛堝彲鑳芥槸鎵嬫寚鍋滃湪涓棿銆佷篃鍙兘鏄笂涓€娆¤ˉ闂寸殑涓棿鎬侊級锛?
   * 缁堢偣 = `progress`锛涙椂闀?560ms銆佹洸绾?`cubic-bezier(0.23, 1.0, 0.32, 1.0)`锛堝揩鍑烘參鏀讹級銆?
   * 涓栦唬鍙蜂繚璇?鏂拌ˉ闂?澶嶄綅"涔嬪悗鏃у洖璋冪洿鎺ヤ涪寮冦€?
   *
   * 鈿狅笍 **涓や釜鏂瑰悜鍏辩敤杩欎竴濂楁椂闀?鏇茬嚎鏄埢鎰忕殑**锛堟棤鐣屾敹璧锋柟鍚戝彟鏈変竴璇?`460` +
   *   `"cubic-bezier(0.85, 0, 0.5, 0.88)"`锛夆€斺€?涓轰粈涔堜笉鐓ф惉銆佷互鍙婇偅涓?12% 灏捐烦"鐨勭畻寮忥紝
   *   瑙佷笂闈?`MORPH_OVERLAY_DURATION_MS` 鍚庨潰閭ｆ璇存槑銆?*鍒彧鏀硅繖閲岀殑 `duration`銆?*
   * @param progress true = 灞曞紑鍒?1锛沠alse = 鏀跺洖 0
   * @param ui 璧疯ˉ闂寸敤鐨?UIContext
   */
  public morphOverlayTweenTo(progress: boolean, ui: UIContext): void {
    this.morphOverlayGen = this.morphOverlayGen + 1;
    const gen: number = this.morphOverlayGen;
    const from: number = this.morphOverlayProgress();
    const to: number = progress ? 1 : 0;
    if (Math.abs(to - from) < 0.0001) {
      // 宸茬粡鍦ㄧ粓鐐癸細涓嶈捣琛ラ棿锛堥伩鍏嶆瘡娆¤繘鎾斁椤甸兘鐧借窇涓€娈?560ms 鐨勭┖鍔ㄧ敾锛?
      this.morphOverlayAnimating = false;
      this.morphOverlayP = to;
      return;
    }
    if (ui === undefined) {
      // 鎷夸笉鍒?UIContext锛氱洿鎺ヨ惤浣嶃€?*缁濅笉鑳芥暣娈佃烦杩?* 鈥斺€?鍚﹀垯娴眰浼氬仠鍦ㄤ腑閫斾笉钀戒綅銆?
      Logger.warn(PlayerExpandState.logTag,
        `morph overlay tween no UIContext, jump from=${from.toFixed(3)} to=${to}`);
      this.morphOverlayAnimating = false;
      this.morphOverlayP = to;
      return;
    }
    // 璧疯ˉ闂翠箣鍓嶅厛鎶?璧风偣"鍚屾鏍囪剰锛堜笌 `PlaybackPage.playMorphOpenIntro` 鍚屼竴鏉″畼鏂瑰彛寰勶細
    // V2 鐘舵€佹槸**寮傛鏍囪剰**銆佽€?`animateTo` 浼氱珛鍒诲埛鏂板凡鏍囪剰鑺傜偣鏉ュ喅瀹氶甯э級銆?
    // 杩欓噷涓嶉渶瑕?`UIUtils.applySync`锛氭诞灞傜殑璧风偣灏辨槸瀛楁褰撳墠鍊硷紝animateTo 鐨勯棴鍖呭彧鍐欑粓鐐广€?
    this.morphOverlayAnimating = true;
    // 鈽呪槄 2026-10-15锛圧ound 27锛夛細鏃堕暱/鏇茬嚎**鎸夋柟鍚戝垎寮€**锛屾敹璧锋柟鍚戜笌鎾斁椤?*鍚屼竴鏉″叕寮?*銆?
    //   鏀惰捣锛歚round(460 脳 max(0.4, from))` 鈥斺€?`from` 灏辨槸娴眰璧锋墜鏃剁殑褰撳墠杩涘害锛?
    //   涓庢挱鏀鹃〉 `closeFullScreenPlayback` 閲岀敤鐨?`morphP` 鏄?*鍚屼竴涓噺**锛堜袱灞傛湰灏卞悓姝ユ帹杩涳級
    //   鈬?涓ゅ眰鍚岃捣鍚岃惤锛?灏捐烦"浠庢牴涓婁笉鍙兘鍑虹幇銆傝繘鍏ワ細缁存寔 560锛堜笉鍙橈級銆?
    const overlayMs: number = progress ? PlayerExpandState.MORPH_OVERLAY_DURATION_MS
      : Math.round(PlayerExpandState.MORPH_OVERLAY_REVERSE_MS *
        (from < PlayerExpandState.MORPH_OVERLAY_REVERSE_MIN_RATIO
          ? PlayerExpandState.MORPH_OVERLAY_REVERSE_MIN_RATIO : from));
    Logger.info(PlayerExpandState.logTag,
      `morph overlay tween start from=${from.toFixed(3)} to=${to} ` +
        `ms=${overlayMs} dir=${progress ? 'enter(560+EASE_OUT_STR)' : 'reverse(460*max(0.4,from)+REVERSE_EASING)'} ` +
        `gen=${gen}`);
    ui.animateTo({
      duration: overlayMs,
      // 鈽?娴眰杩欎竴灞?*鍗曠嫭**鐨勬椂闀?鏇茬嚎锛?
      //   杩涘叆 = 鏃犵晫 `ENTER_MS(560)` + `EASE_OUT_STR`锛?
      //   鏀惰捣 = 鏃犵晫 `MainPage.animateMorphT(reverseMs, 0, REVERSE_EASING)`
      //          锛坄reverseMs = 460 脳 max(0.4, morphT)`銆乣REVERSE_EASING = (0.85,0,0.5,0.88)`锛?
      //          鈥斺€?涓庢挱鏀鹃〉閭ｄ竴灞?*閫愬瓧鍚屾簮**锛屾墍浠ヤ袱灞備笉浼氫笉鍚屾銆?
      //   鈿狅笍 鏇茬嚎鍐呰仈鍐欏湪杩欓噷锛屽埆鎶芥垚杩斿洖 `ICurve`/`UIShape` 鐨勫寘瑁呭嚱鏁帮紙閭ｄ袱涓被鍨嬪湪鏈満 SDK
      //      閲岄兘涓嶆槸鍏ㄥ眬鍙鐨勶紝瑙佹枃浠堕《閮?`MORPH_OVERLAY_DURATION_MS` 鏃佽竟閭ｆ璇存槑锛夈€?
      curve: progress
        ? curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
        : curves.cubicBezierCurve(0.85, 0, 0.5, 0.88)
    }, (): void => {
      // 鈿狅笍 鐩爣鍊?*鐩存帴鍐欏瓧娈?*锛屼笉瑕佽蛋 `syncMorphOverlayFromPage()`锛氶偅涓細琚?
      //    `morphOverlayAnimating` 鎸℃帀锛堟鏃跺畠涓?true锛夛紝鍐欎笉杩涘幓灏辩瓑浜庢病鍔ㄧ敾銆?
      this.morphOverlayP = to;
    });
    setTimeout((): void => {
      if (gen !== this.morphOverlayGen) {
        // 宸茶鏂拌ˉ闂?澶嶄綅鍙栦唬锛氫粈涔堥兘鍒姩
        return;
      }
      this.morphOverlayAnimating = false;
      this.morphOverlayP = to;
      Logger.info(PlayerExpandState.logTag, `morph overlay tween done overlayP=${to} gen=${gen}`);
    }, PlayerExpandState.MORPH_OVERLAY_DURATION_MS + 20);
  }

  /**
   * 閲忎竴涓粍浠剁殑绐楀彛鐭╁舰锛坴p锛夈€?
   *
   * 杩欏氨鏄弽缂栬瘧渚?`ComponentRect.getRectByFrameNode` 鐨勫仛娉曪細
   * `getFrameNodeById` 鈫?`getPositionToWindowWithTransform()`锛坴p锛? `getMeasuredSize()`锛坧x鈫抳p锛夈€?
   * 鐢?FrameNode 鑰屼笉鏄?`getComponentUtils().getRectangleById`锛氬墠鑰呮槸**娓叉煋鍚?*鐨勪綅缃?
   * 锛堝惈绁栧厛 transform锛夛紝鍚庤€呬箣鍓嶅湪 HDS 娴姩搴曟爮涓婇噺鍑烘潵鏄亸鐨勩€?
   *
   * 鈽呪槄鈽?2026-10-17锛?*鍥炲師濮嬪瓧鑺傜爜澶嶆牳娴嬮噺杩欎竴灞?* 鈥斺€?涓夋潯缁撹锛屽埆鍐嶉噸澶嶆煡锛?
   *
   * **(a) 涓婃父**鏈?*涓や釜**娴嬮噺鍔╂墜锛岃涔変笉鍚岋紝鍒贩**锛坄ComponentRect.ets`锛夛細
   * ```
   *   getRectByFrameNode(id)  = getPositionToWindow**WithTransform** + getMeasuredSize   鈫?鍚彉鎹㈢殑浣嶇疆
   *   getRectById(id)         = getRectangleById(...) + **涓€涓?scale 淇**
   * ```
   * 閭ｄ釜淇鏄繖涓€浠斤紙`wujie.pa:50532` 璧凤紝閫愭潯瑙ｅ嚭鏉ワ級锛?
   * ```ts
   *   const halfW = info.size.width  * (1 - info.scale.x) / 2;   // 鈽?缁曚腑蹇冪缉鏀?鈬?宸﹁竟鐣屽線閲屾敹鍗婁釜宸?
   *   const halfH = info.size.height * (1 - info.scale.y) / 2;
   *   rect.left   = info.translate.x + info.screenOffset.x + halfW;
   *   rect.top    = info.translate.y + info.screenOffset.y + halfH;
   *   rect.right  = info.translate.x + info.screenOffset.x + info.size.width  - halfW;
   *   rect.bottom = info.translate.y + info.screenOffset.y + info.size.height - halfH;
   * ```
   *   鈬?**鍥犱负 `getMeasuredSize()` 缁欑殑鏄?甯冨眬灏哄"锛堜笉鍚?scale锛夛紝鑰屽惈鍙樻崲鐨勪綅缃妸 scale 绠楄繘鍘讳簡**
   *     鈬?涓嶅仛杩欎釜淇锛?浣嶇疆"涓?灏哄"灏?*涓嶆槸鍚屼竴涓潗鏍囩郴**銆?
   *
   * **(b) 鏈粨鐨勫搴斿叧绯?*锛氭湰鍑芥暟灏辨槸 (a) 閲岀殑 `getRectByFrameNode`
   *   锛坄naturalLayout=false` 鈬?鍚彉鎹㈢殑浣嶇疆 + 甯冨眬灏哄锛夛紝
   *   **骞朵笖**鎴戜滑缁欏彲缂╂斁鐨勯偅涓秷璐硅€咃紙鎾斁椤靛ぇ灏侀潰锛夎蛋浜?`naturalLayout=true`
   *   锛坄measureEndAnchor` 鐢?`getPositionToWindow()` = 涓嶅惈鍙樻崲 鈬?涓?甯冨眬灏哄"鑷唇 鉁擄級锛?
   *   鍙︽妸缂╂斁**鍗曠嫭瀛?*锛坄bigNodeScaleX/Y`锛夊湪缁樺埗鏃朵箻鍥炲幓 鈥斺€?涓庝笂娓?鎶?scale 闄ゆ帀鍐嶄箻鍥炴潵"鍚屾簮銆?
   *   鈿狅笍 鎵€浠?*娌℃湁**鐓ф惉 (a) 閭ｄ釜 `halfW/halfH` 鏄?*鏈夋剰鐨?*锛氭垜浠殑璋冪敤鐐硅涔堜笉甯?scale锛?
   *     瑕佷箞宸茬粡鎹㈡垚 `naturalLayout=true` 杩欐潯鑷唇璺緞銆?
   *
   * **(c) 鍞竴鍙兘韪╁埌鐨勫湴鏂癸紙璁颁笅鏉ワ紝鍒綋涓嶇煡閬擄級**锛?*杩蜂綘鏉¤兌鍥?*锛坄measureGeometry` 閲?
   *   `measureNode(ui, MINI_BAR_*)`锛岃蛋鐨勬槸鍚彉鎹㈢殑榛樿璺緞锛夊湪
   *   **钀戒綅鎸ゅ帇寮圭哀**锛堣糠浣犳潯鐨?`.scale({y: morphSquashY})`锛?.86鈫? 鍏?430ms锛?*姝ｅ湪璺?*鏃惰閲忓埌锛?
   *   瀹冪殑 `y` 浼氬甫涓?`h脳(1鈭?.86)/2 鈮?3.9vp` 鐨勫亸绉伙紝鑰?`h` 浠嶆槸鏈缉鏀剧殑甯冨眬楂?鈬?宸?~4vp銆?
   *   瀹炴祴涓?*鍩烘湰韪╀笉鍒?*锛氳兌鍥婂彧鍦?鎵撳紑璧锋墜 / 鍏抽棴璧锋墜"琚噺锛岃€岄偅涓ゅ埢寮圭哀鏃╁凡褰掍綅
   *   锛堟尋鍘嬪彧鍦ㄥ叧闂惤浣嶅悗 430ms 鍐呭亸绂?1锛夈€?
   *   鈬?鑻ュ皢鏉ュ嚭鐜?鏌愭鎵撳紑鏃跺皝闈?鑳屾櫙璧风偣鏁翠綋鍋忓嚑 vp"锛?*鍏堟煡杩欓噷**锛堣鏁帮細寰芥爣绗簩琛?
   *     `snap=`/`end=`銆佺鍗佷笁琛岀殑 `CLO:鈥?bar=WxH`锛夈€?
   *
   * **(d) 涓婃父 `MainPage.visualRect(鈥? baseRect)`锛?瑙嗚鐭╁舰淇"锛夆€斺€?缁撹锛氭湰浠?*鏃犳硶鐓ф惉**锛?
   * 涓嶅啓鏄?*鏈夋剰鐨?*锛屽埆鍐嶅綋鍓嶇疆浠诲姟鎸傚湪閭ｅ効銆?* 鍘熷瀛楄妭鐮?
   * 锛坄_recover/disasm/wujie.pa:143042`锛?4~95 鏉℃寚浠わ紝閫愭潯瑙ｅ畬锛夐€昏緫鏄細
   * ```ts
   *   const vis = getRectById(鈥?;                  // 鈫?闇€瑕?*鍙︿竴涓?*娴嬮噺鏉ユ簮锛堝惈 scale 淇閭ｆ潯锛?
   *   if (vis === undefined)                       { return baseRect; }   // 閲忎笉鍒?鈬?鍘熸牱杩斿洖
   *   if (baseRect.width <= 0)                     { return baseRect; }
   *   const k = vis.width / baseRect.width;
   *   if (k <= 0)                                  { return baseRect; }
   *   if (Math.abs(k - 1) < 0.01)                  { return baseRect; }   // 鈽?鑷甫"鍒嗘 <1% 灏变笉淇?鎶ゆ爮
   *   const out = new RectInPx();                  // 娉ㄦ剰锛氫綅缃彇 base銆佸昂瀵稿彇 k 鍊?
   *   out.left = baseRect.left;  out.top = baseRect.top;
   *   out.width  = baseRect.width  * k;            // = vis.width
   *   out.height = baseRect.height * k;
   *   out.right = out.left + out.width;  out.bottom = out.top + out.height;
   *   return out;
   * ```
   * 鈬?**瑕佺収鎼氨蹇呴』鍦?鍚屼竴娆℃祴閲忛噷"鍚屾椂鎷垮埌 `getRectById(...)`**锛岃€?
   * `getRectangleById` 鍦?HDS 娴姩搴曟爮涓婇噺鍑烘潵鐨勫€兼湰韬槸鍋忕殑锛堣鏈嚱鏁板紑澶达級
   * 鈬?鎴戜滑娌℃湁鍙俊鐨勫悓杞绗簩鏉ユ簮锛?*纭噾涓€涓彧浼氭槸鑷垱鏁板€?*锛堣繚鍙?鐓ф惉"绾㈢嚎锛夈€?
   * 鈬?鎴戜滑鐪熸鐨勭瓑浠风墿鏄?(b) 閭ｆ潯锛歚naturalLayout` + 鍗曠嫭淇濆瓨鐨?`bigNodeScaleX/Y`
   * 鈥斺€?鐢?*鑷唇鐨勫彛寰?*浠ｆ浛"涓や釜鏉ユ簮浜掔浉鏍℃"锛屾瘮鐓ф惉鏇寸ǔ銆?
   * 鈬?鈽?椤哄甫纭瘉锛?*涓婃父鑷繁璁や负"涓や釜鏉ユ簮宸?<1% 灏变笉蹇呬慨"**锛堥偅鏉?`1e-2` 鎶ゆ爮锛?
   * 鈬?鎴戜滑娴嬮噺閾句笂 `<1%` 鐨勫嚭鍏?*涓嶆槸 bug**锛屼笉瑕佷负瀹冩敼鍏紡銆?
   * @param ui UIContext
   * @param id 缁勪欢 id
   * @param naturalLayout true = 鐢?*涓嶅惈鍙樻崲**鐨?`getPositionToWindow()`锛堜笌"甯冨眬灏哄"鑷唇锛?
   *        缁?*甯?scale 鐨勮妭鐐?*鐢紱涓婃父瀵瑰簲 `getRectByFrameNode`锛?
   * @returns 绐楀彛鐭╁舰锛涢噺涓嶅埌杩斿洖 undefined
   */
  private measureNode(ui: UIContext, id: string, naturalLayout: boolean = false): NodeRect | undefined {
    if (id.length === 0) {
      return undefined;
    }
    try {
      const node = ui.getFrameNodeById(id);
      if (node === null) {
        return undefined;
      }
      const pos: Position = naturalLayout ? node.getPositionToWindow() : node.getPositionToWindowWithTransform();
      const size: Size = node.getMeasuredSize();
      const w: number = ui.px2vp(size.width);
      const h: number = ui.px2vp(size.height);
      if (w <= 0 || h <= 0) {
        return undefined;
      }
      // `Position.x/y` 鐨勯潤鎬佺被鍨嬫槸 `Length`锛岀敤鐜版垚鐨勬敹绐勫嚱鏁板彇鎴?vp
      return { x: areaLengthToVp(pos.x), y: areaLengthToVp(pos.y), w: w, h: h };
    } catch (err) {
      Logger.warn(PlayerExpandState.logTag, `measureNode('${id}') failed: ${err}`);
      return undefined;
    }
  }

  /**
   * @returns 鏁撮〉涓嶉€忔槑搴︼細0锛堣繕鍦ㄨ糠浣犳潯閭ｄ竴灏忓潡銆佷笉鍙锛夆啋 1锛堝畬鍏ㄩ摵寮€锛夈€?
   *
   * 鈽呪槄 2026-10-15锛?*宸插垽瀹氫负姝讳唬鐮?*锛宍RzdMusic璁板繂.md` 搂59锛夛細**闆惰皟鐢ㄨ€?* 鈥斺€?
   *   鍙湁 `products/default/.../Index.ets` 鐨?*娉ㄩ噴**閲屾彁鍒板畠锛圠837 / L1431锛夛紝浠ｇ爜閲屾病璋冦€?
   * 鈿狅笍 杩欎竴鏉℃瘮鍚屾棌鐨勫叾浠栧嚑涓洿鍊煎緱璁颁竴绗旓細**娉ㄩ噴鎶婂畠璇存垚"娲荤殑"**锛?
   *    璇绘敞閲婄殑浜轰細浠ヤ负"鎾斁椤靛湪褰㈠彉鏃╂湡鏄贰鍏ョ殑"銆傚疄闄呬笉鏄?鈥斺€?鎾斁椤垫槸**鍗婇€忔槑鐢诲嚭鏉?*鐨?
   *    锛堢粯鍒剁殑瑙傛劅鐢?鏁撮〉缂╂斁 + 瑁佸壀绐楀彛 + 鑳屾櫙灞?`backgroundRevealOpacity`"涓夎€呭叡鍚屽喅瀹氾級锛?
   *    鑰屾暣椤靛苟娌℃湁涓€涓?`.opacity(morphPageOpacity())`銆?
   * 鈬?涓ゆ潯鍑鸿矾锛岄兘闇€瑕佺湡鏈哄垽瑙傛劅锛屾墍浠ユ湰杞?*鍙爣娉ㄣ€佷笉鏀?*锛?
   *   锛坅锛夋帴涓婂畠锛堝姞涓€娆℃暣椤垫贰鍏ワ級鈥斺€?浼氭敼鍙樿鎰燂紝涓斾笌"涓嶈娣″叆娣″嚭"鐨勭敤鎴峰畾璋冨彲鑳藉啿绐侊紱
   *   锛坆锛夋妸閭ｆ娉ㄩ噴鏀规帀锛堣娓?娌℃湁鏁撮〉娣″叆"锛夆€斺€?闆堕闄╋紝浣嗗睘浜庢枃妗ｆ暣鐞嗐€?
   * @deprecated 闆惰皟鐢ㄨ€呫€?
   * 澶嶆牳鍛戒护锛歚grep -rn 'morphPageOpacity' RzdMusic --include=*.ets`锛堟湡鏈涳細鍙湁娉ㄩ噴鍛戒腑锛?
   */
  public morphPageOpacity(): number {
    if (!this.morphUsable) {
      return 1;
    }
    // LANDING = 宸茬粡浜よ繕缁欒糠浣犳潯锛堝鏍?`playerPaintsOf = false`锛夛細杩欎竴甯ц捣鎾斁椤?
    // **涓嶅啀鐢?*锛屽惁鍒欎細鍦ㄨ糠浣犳潯灏侀潰涓婄暀涓€涓悓灏哄鐨勬繁鑹插皬鏂瑰潡锛岀洿鍒拌鍗歌浇銆?
    if (this.morphStage === MorphStage.LANDING) {
      return 0;
    }
    if (this.morphStage !== MorphStage.ENTERING && this.morphStage !== MorphStage.LEAVING) {
      return 1;
    }
    // 鈿狅笍 蹇呴』**鏃╀簬**杩蜂綘鏉＄殑娣″嚭锛坄miniBarOpacity`锛?锝?0%锛夎蛋瀹岋細
    //    涓よ竟閮藉湪娣＄殑鏃跺€欎腑闂翠細鍑虹幇"鍗婇€忔槑鐨勮糠浣犳潯 + 鍗婇€忔槑鐨勬挱鏀鹃〉"锛?
    //    鍙犺捣鏉ユ槸鍧楀彂鐏扮殑绯婃枒銆傝繖閲?12% 灏卞埌浣嶏紝涔嬪悗鐢辨挱鏀鹃〉閭ｅ眰鎺ョ銆?
    return Math.min(1, this.contentProgress() / 0.12);
  }

  /**
   * @returns 杩蜂綘鏉＄殑娣″嚭绯绘暟锛堝鏍?`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`锛夈€?
   *
   * 鈿狅笍 鍙嶇紪璇戦噷杩蜂綘鏉℃湁**涓ゆ。**娣″嚭锛?*鎿嶄綔鍖猴紙鍙充晶鎸夐挳锛?.20 鍏堟秷澶?*銆?
   * **鍏冧俊鎭紙姝屽悕/姝屾墜锛?.35 鍚庢秷澶?* 鈥斺€?鍋氬嚭鏉ュ氨鏄?鎸夐挳鍏堟病銆佹枃瀛楀悗娌?銆?
   * 杩欐潯鏄搷浣滃尯閭ｄ竴妗ｏ紝鐢ㄥ湪 `*Aside`锛堟寜閽級涓娿€?
   */
  public miniBarOpacity(): number {
    if (!this.morphUsable) {
      return 1;
    }
    if (this.morphStage !== MorphStage.ENTERING && this.morphStage !== MorphStage.LEAVING) {
      return 1;
    }
    // 内容窗口取**内容时间线**（上游 `effT = isMorphTarget() ? 1 : pullT`，`wujie.pa:171535-171548`）
    const p: number = this.contentProgress();
    const a: number = 1 - p / 0.20;
    return a < 0 ? 0 : a;
  }

  /**
   * @returns 杩蜂綘鏉?*鍏冧俊鎭?*锛堟瓕鍚?姝屾墜銆佷互鍙婂皝闈㈤偅涓€鍧楋級鐨勬贰鍑虹郴鏁般€?
   *
   * 瀵规爣 `MiniMorph.metaOpacityAt = clamp(1 - t/0.35)`锛氭瘮鎿嶄綔鍖烘櫄娑堝け锛?
   * 浜庢槸瑙傛劅鏄?鎸夐挳鍏堟病銆佹枃瀛楀悗娌?锛堢敤鎴峰疄娴嬬殑鎻忚堪锛夈€?
   */
  public miniBarMetaOpacity(): number {
    if (!this.morphUsable) {
      return 1;
    }
    if (this.morphStage !== MorphStage.ENTERING && this.morphStage !== MorphStage.LEAVING) {
      return 1;
    }
    // 内容窗口取**内容时间线**（上游 `effT = isMorphTarget() ? 1 : pullT`，`wujie.pa:171535-171548`）
    const p: number = this.contentProgress();
    const a: number = 1 - p / 0.35;
    return a < 0 ? 0 : a;
  }

  /**
   * 璺熸墜/鍔ㄧ敾鎺ㄨ繘锛氭妸 `progress`(0鈥?) 钀藉埌"缂╂斁瀹瑰櫒"鐨勫嚑浣曚笂銆?
   *
   * **鍙湁鍑犱綍杩愮畻锛屼笉鍚换浣曞畾鏃?* 鈥斺€?璺熸墜闃舵鐢辨墜鎸囪皟銆佹敹灏剧敱璋冪敤鏂圭殑 animateTo 璋冦€?
   *
   * 鈿狅笍 杩欎竴鐗堝洖鍒?鏁撮〉缂╂斁 + 绔栫洿瑁佸壀绐楀彛"锛堢浜旂増锛夛紝鍘熷洜鏄浜旂増涔嬪墠鐨?
   *   "璐村簳绐楀彛 + 鍐呭绛夋瘮缂╂斁灞呬腑"铏界劧缁撴瀯涓婃病鏈変簡搴曢儴绌烘。锛屼絾鍐呭灞?*姣旂獥鍙ｅ皬**锛?
   *   灞忎笂灏辨槸"涓€鍧楀簳鑹茬獥鍙?+ 涓棿涓€涓缉灏忕殑鎾斁椤?锛堢敤鎴峰疄娴嬶細"榛戠獥鍙ｏ紝涓棿鏄挱鏀惧櫒"锛夈€?
   *   杩欎竴鐗堣**鍙鐭╁舰涓庡唴瀹瑰眰涓ユ牸鍚屽昂瀵?*锛氬唴瀹规案杩滃～婊″彲瑙嗙煩褰紝涓嶅瓨鍦ㄧ暀鐧姐€?
   *
   * 涓夋潯涓嶅彉閲忥細
   *   1. 鍙鐭╁舰鍥涜竟鍚勮嚜鎻掑€硷細宸?涓?鈫?0銆佸彸/涓?鈫?瀹夸富灏哄锛?*璧风偣 = 杩蜂綘鏉￠偅鏉¤兌鍥?*
   *      锛堢敤鎴疯鐨?鏁翠釜鎾斁鏉″欢浼搁摵寮€"锛夛紝涓嬭竟鍦ㄥ墠 25% 鍏堣创鍒板涓诲簳杈癸紙鍚﹀垯搴曢儴閭?
   *      鍑犲崄 vp 鏁存鍔ㄧ敾閮界┖鐫€锛夛紱
   *   2. 鍐呭灞傞珮搴?= 瑁佸壀楂樺害 = 鍙楂樺害 / 缂╂斁 鈬?鍙鐭╁舰閲?*姝ｅソ**鏄暣椤碉紝
   *      娌℃湁鐣欑櫧銆佷篃娌℃湁瑁佸垏锛?
   *   3. 鍐呭灞傜瓑鍙鐭╁舰鎺ヨ繎鏁村睆锛堝楂樻瘮鎺ヨ繎椤甸潰锛夋墠娴幇锛岄伩鍏嶄腑娈电湅鍒拌鍘嬫墎鐨勯〉闈€?
   * @param p 0 = 杩蜂綘鏉￠偅鏉¤兌鍥婏紝1 = 婊″睆
   */
  public applyMorphProgress(p: number): void {
    const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
    // 鈽呪槄鈽呪槄 2026-10-17锛?*璁?`morphP` 鎴愪负鐪熸鐨勯┍鍔ㄩ噺** 鈥斺€?鐓ф惉鏃犵晫"涓€涓?morphT 椹卞姩涓€鍒?锛?
    //
    // ## 涓轰粈涔堝繀椤昏繖鏍凤紙鐢ㄦ埛涓よ疆瀹炴祴閮芥寚鍚戝畠锛?
    //   路 銆屾棤鐣屽垰鍥炲埌鍔ㄧ敾璧峰浣嶇疆鏄?*姝ｅ父鐨勯鑹?*锛屾垜浠幇鍦ㄤ竴寮€灏辨槸鑳屾櫙銆嶁€斺€?
    //     涓婃父鑳屾櫙涓嶉€忔槑搴?= `PULL_BG_FLOOR + pullBgIn 脳 0.96`锛岃€?`pullBgIn = clamp(morphT/0.30)`
    //     鈬?**morphT 浠?0 杩炵画闀胯捣鏉?*锛屽ご 30% 鎵嶆贰鍒版弧 鈬?璧峰閭ｄ竴甯у嚑涔庨€忔槑锛岀湅鍒扮殑鏄糠浣犳潯鏈韩銆?
    //   路 鎴戜滑鐨勮ˉ闂磋矾鏄?`animateTo(() => applyMorphProgress(0|1))`锛氶棴鍖呴噷**涓€娆℃€?*鎶?
    //     `morphP` 鍐欐垚缁堢偣 鈬?`pullBgIn` 绔嬪埢 0 鎴?1 鈬?璧峰灏辨槸婊′笉閫忔槑锛堟垨鍏ㄧ▼ 0.04 = 榛戯級銆?
    //   鈬?鐜板湪鎶婅ˉ闂寸洰鏍囨敼鎴?*鍙啓 `morphP`**锛坄animateTo(() => { morphP = 1 })`锛夛紝
    //     鐢变笅闈㈢殑 `@Monitor('morphP')` 鍦?*姣忎竴甯?*鎶婂嚑浣曢噸绠椾竴娆?
    //     鈥斺€?涓庝笂娓?姣忓抚 `applyPullProgress(effT())`"鍚屾瀯銆?
    //   鈿狅笍 `morphPApplying` 鏄槻鍥炵幆鐨勶細鏈柟娉曡嚜宸卞啓 `morphP` 鏃朵笉瑕佽鑷繁鐨?monitor 鍐嶇畻涓€閬嶃€?
    this.morphPApplying = true;
    if (this.morphP !== t) {
      this.morphP = t;
    }
    // ★ 两条时间线在「内容补间没在跑」时**严格同值**（回归红线：静止态 / 落位 / 复位取值逐值不变）。
    //   手势跟手这条路上游本来就是一个量（手指写 `MainPage.morphT`，`expand.applyPullProgress(effT())`
    //   跟着走，`wujie.pa:174862` 那条 `effT`），所以这里把 `contentP` 一起写成 `t`。
    //   ⚠️ 内容补间（560ms + `EASE_OUT_STR`）在跑时**不抢**：否则会把内容窗口钉回几何进度，
    //      用户实测的「飞入比无界早」就回来了。
    if (!this.contentTweenOwned && this.contentP !== t) {
      this.contentP = t;
    }
    this.applyMorphGeometry(t);
    this.morphPApplying = false;
  }

  /** `applyMorphProgress` 鐨勯噸鍏ユ姢鏍忥紙瑙侀偅閲岀殑璇存槑锛夈€?*/
  private morphPApplying: boolean = false;

  /**
   * 鈽呪槄鈽呪槄 2026-10-17锛?*`morphP` 琚ˉ闂撮€愬抚鎻掑€兼椂锛屽嚑浣曡窡鐫€閲嶇畻**锛堢収鎼笂娓?涓€涓?morphT 椹卞姩"锛夈€?
   *
   * `animateTo({...}, () => { expandState.morphP = 1 })` 涔嬪悗锛孉rkUI 浼氶€愬抚鎻掑€?`morphP`锛?
   * 鏈?monitor 鍦ㄦ瘡涓€甯ф妸瀹冮噸鏂板杺缁欏嚑浣曡绠?鈬?`scale/translate/clipHeight/radius/contentOpacity`
   * 浠ュ強鎵€鏈?鎸?`morphP` 鍙栧€?鐨勬淳鐢熼噺锛堣儗鏅笉閫忔槑搴?`pullBgIn`銆佸悇娈垫贰鍏ョ獥鍙ｏ級閮借窡鐫€鍔ㄣ€?
   * 鈿狅笍 涓嶈鍦ㄨ繖閲屽仛"璧疯ˉ闂?钀戒綅"杩欑被**鐘舵€佹満**鍔ㄤ綔 鈥斺€?閭ｄ竴寰嬬暀鍦ㄩ〉闈晶锛堟湰鏂规硶鍙畻鍑犱綍锛夈€?
   */
  @Monitor('morphP')
  onMorphPDriven(): void {
    if (this.morphPApplying) {
      return;
    }
    const p: number = this.morphP;
    this.morphPApplying = true;
    this.applyMorphGeometry(p < 0 ? 0 : (p > 1 ? 1 : p));
    this.morphPApplying = false;
  }

  /** 鍙畻鍑犱綍锛堜笉鍐?`morphP`锛夆€斺€?`applyMorphProgress` 涓?`@Monitor('morphP')` 鍏辩敤杩欎竴娈点€?*/
  private applyMorphGeometry(t: number): void {
    // 鈽呪槄 2026-10-15锛?*鍒犻櫎浜?闈炲舰鍙樻湡鑷姩澶嶄綅娴眰"閭ｄ竴娈?*锛屼緷鎹鏈潯锛夛細
    //   鍘熸潵鏄?`if (!morphContainerActive()) { this.morphOverlayReset(); }` 鈥斺€?
    //   鏈剰鏄厹浣?寮傚父璺緞鐩存帴钀戒綅/鍗歌浇"锛屼絾瀹冨悓鏃?*鍚冩帀浜嗘甯告敹璧疯矾涓婄殑閭ｄ竴妫?*锛?
    //   `closeFullScreenPlayback()` 鐨勮ˉ闂寸洰鏍囨槸 `applyMorphProgress(0)`锛岃€?
    //   `morphLand()`锛圠ANDING锛変笌 `morphReset()`锛圢ONE锛夐兘浼氬湪**鍚屼竴鎵逛换鍔?*閲屽啀璋冧竴娆?
    //   `applyMorphProgress(1)` / 鐩存帴澶嶄綅 鈬?娴眰杩涘害琚?*鐬棿**娓呭洖 0锛?
    //   灏侀潰鐨勫洖椋炲湪鏈€鍚庝竴娈佃鎺愭柇 鈥斺€?鐢ㄦ埛瀹炴祴鐨勩€屽叧闂椂灏侀潰鍔ㄧ敾涓嶅 / 娌℃湁灏侀潰鍔ㄧ敾銆嶃€?
    //   鈿狅笍 鐜板湪澶嶄綅鍙敱涓ゅ**鏄惧紡**璐熻矗锛岃涔夋竻鏅颁笖閮藉湪浼氳瘽杈圭晫涓婏細
    //     路 `morphReset()`锛堜細璇濈粨鏉?/ 鍗歌浇锛夆€斺€?閲岄潰宸茬粡璋冧簡 `morphOverlayReset()`锛?
    //     路 璧锋墜閭ｄ竴甯х敱澹冲眰/杩蜂綘鏉℃樉寮忓帇 0锛坄onPullOpenStart` / `settlePullOpen`锛夈€?
    //   娓叉煋闂紙`morphOverlayBridging()`锛夎嚜宸变繚璇侀潤姝㈡€佷笉鐢伙紝鎵€浠ヤ笉浼氭畫鐣欎竴寮犲皝闈€?
    // 鈽呪槄鈽?2026-10-16锛?*鐓ф惉鏃犵晫 `onPullTChanged` / `applyPullProgress` 鐨勯偅閬撻棬**锛夛細
    //   `wujie.pa` 174839-174850锛?
    // ```ts
    //   if (!pullGeomReady) { return; }        // 鈫?缁堢偣鍑犱綍娌￠噺鍒?鈬?杩欎竴甯т粈涔堥兘涓嶅仛
    //   expand.applyPullProgress(ui, effT());
    // ```
    //   **涓嶆槸**"鍐欏洖鎭掔瓑"锛岃€屾槸**淇濇寔瀹瑰櫒褰撳墠鍊间笉鍔?*銆?
    //   涓轰粈涔堝繀椤昏繖鏍凤紙鏈粨鐨勭湡瀹炴柇鐐癸級锛氱偣鍑绘墦寮€ / 鐐瑰嚮鍏抽棴 / 绯荤粺杩斿洖杩欎笁鏉¤矾涓婏紝
    //   鎾斁椤靛湪 `pullOpenBegin` 閭ｄ竴鍒昏繕娌℃寕杞?鈬?缁堢偣閿氱偣閲忎笉鍒?鈬?`morphUsable === false`
    //   鈬?鍘熸潵杩欓噷鎶婂鍣ㄥ啓鍥炴亽绛?鈬?**鏁存鍔ㄧ敾閮芥病鏈?*锛堢敤鎴峰疄娴嬶級銆?
    //   鏀规垚"浠€涔堥兘涓嶅仛"涔嬪悗锛屽鍣ㄤ竴鐩村仠鍦ㄦ亽绛夛紙= 涓?娌℃湁杩欏鍔ㄧ敾"閫愬儚绱犱竴鑷达級锛?
    //   鐩村埌 `measureMiniDuringPull()` 閲忓埌缁堢偣閭ｄ竴甯ф墠绗竴娆¤惤闈炴亽绛夊嚑浣?鈬?
    //   琛ラ棿閭ｄ竴甯ц捣鐢熸晥锛坄animateTo` 鐨勯棴鍖呬細鎶婄粓鐐瑰€煎啓杩涘幓锛孉rkUI 鑷繁琛ラ棿锛夈€?
    //   鈿狅笍 **椤哄簭鏄‖绾︽潫**锛氳繖涓€鏉″繀椤诲湪涓嬮潰 `!morphUsable` 閭ｆ潯**涔嬪墠** 鈥斺€?
    //      `morphUsable === false` 姝ｆ槸"鍑犱綍娌￠噺鍒?鐨勪富鍦烘櫙锛屾帓鍦ㄥ畠鍚庨潰绛変簬娌″姞闂ㄣ€?
    //   鈿狅笍 鎭掔瓑鐨勫厹搴曚粛鐒剁敱 `morphReset()` 鎵挎媴锛堝畠鏄惧紡鎶婁簲涓嚑浣曞瓧娈靛啓鍥炴亽绛夛級鈥斺€?
    //      閭ｄ篃鏄?浼氳瘽缁撴潫"鐨勫敮涓€杈圭晫锛屾瘮"姣忓抚鍐欏洖"绮剧‘寰楀銆?
    if (!this.morphGeomReady) {
      return;
    }
    if (!this.morphUsable) {
      // 鍑犱綍娌￠噺鍒帮細涓嶈鍓€佷笉缂╂斁銆佷笉閫忔槑 鈥斺€?鐩存帴褰?娌℃湁杩欏鍔ㄧ敾"
      this.morphScale = 1;
      this.morphTx = 0;
      this.morphTy = 0;
      this.morphClipHeight = 0;
      this.morphRadius = 0;
      this.morphContentOpacity = 1;
      return;
    }
    // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 浠ヤ笅**閫愭潯鐓ф妱**鍙嶇紪璇戠殑 `applyPullProgress` 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    //   scaleValue = initScale + (1 - initScale) * t
    //   translateX = initTranslateX * (1 - t)      translateY = initTranslateY * (1 - t)
    //   clipWidth  = "100%"
    //   clipHeight = initClipHeight + (fullClipHeight - initClipHeight) * t
    // 涓夋潯閮芥槸 t 鐨勭嚎鎬у嚱鏁?鈬?**鍙鐭╁舰鐨勫洓鏉¤竟鍚屾椂绾挎€ц蛋鍒板睆骞曞洓杈?*
    // 锛堢敤鎴峰疄娴嬶細"鏁翠釜鐭╁舰鍥涗釜杈规槸鍚屾椂鍒拌揪灞忓箷鍥涜竟鐨?锛夈€?
    // 鈿狅笍 涓婁竴鐗堟垜鍦ㄤ笅杈瑰姞浜?鎻愬墠璐村簳"鐨勮ˉ涓?鈥斺€?閭ｄ細璁╀笅杈瑰厛鍒般€佸叾浣欎笁杈瑰悗鍒帮紝
    //    姝ｅソ鐮村潖杩欎釜鎬ц川锛屽凡缁忓垹鎺夈€?
    const scale: number = this.initScale + (1 - this.initScale) * t;
    const clipHeight: number = this.initClipHeight + (this.morphBoxH - this.initClipHeight) * t;
    // 鍦嗚锛歚radius = (initClipHeight*initScale/2 + delta*t) / scaleValue`锛?
    // 璧风偣鍙鍦嗚 = 鑳跺泭楂樺害鐨勪竴鍗婏紙= 杩蜂綘鏉¤兌鍥婄殑鍦嗚锛夛紝缁堢偣 0銆?
    // 鈽呪槄鈽呪槄 2026-10-17锛?*鐓ф惉鏃犵晫 `visualRadiusAt`** 鈥斺€?鐢ㄦ埛鐐瑰悕銆屽渾瑙掑暐鐨勯兘涓嶄竴鏍枫€嶏級
    // ```
    //   鏃犵晫锛歷isualRadius = lerp(vp(miniCover.width)/2, 鐩爣鍦嗚缁濆鍊?34, t)   // 涓ょ鐐?lerp
    //         鐒跺悗 radius = visualRadius / scale                              // wujie.pa:85604-85613
    //         鏀跺熬 位1onFinish 鍐嶆妸 radius 褰?0                                 // 钀藉畾 = 0 鍦嗚
    //   鎴戜滑鍘熸潵锛歷isualRadius = initRadiusVisual * (1 - t)   鈫?鐩寸嚎寰€ 0 鏀讹紝涓姣斾笂娓稿皬
    // ```
    // 鈬?鏀规垚**涓ょ鐐?lerp**锛堣捣鐐?= 鑳跺泭楂?2锛岀粓鐐?= 涓婃父鐨?34锛夛紝鏀跺熬褰?0 瑙?`morphSettleOpen()`銆?
    //   鈿狅笍 璧风偣鐨?34 鏄?*涓婃父甯搁噺**锛坄wujie.pa` 閲?`doEnter` 閭ｆ潯琛ラ棿鐨?radius 绔偣锛夛紝涓嶆槸鎴戜滑鎷嶇殑鏁般€?
    const visualRadius: number = this.lerp(this.initRadiusVisual,
      PlayerExpandState.MORPH_RADIUS_END_VP, t);
    this.morphScale = scale;
    this.morphClipHeight = Math.max(1, clipHeight);
    this.morphTx = this.initTranslateX * (1 - t);
    this.morphTy = this.initTranslateY * (1 - t);
    this.morphRadius = scale > 0 ? visualRadius / scale : 0;
    // 鍐呭灞傦紙灏侀潰椤甸噷鐨勬瓕璇?灏忔瓕璇嶉偅鍑犲锛夛細
    // 鈽呪槄 2026-10-15锛堝洖閫€鍚庨噸鍋氾級鏀规垚 **p 鐨勭函鍑芥暟**銆?
    //   鍘熸潵杩欓噷鏄?`LEAVING ? pullBottomIn() : (t >= 1 ? 1 : 0)` 鈥斺€?甯?*鏂瑰悜鍒ゆ柇**锛?
    //   灞曞紑鏃跺叏绋?0锛堥樁璺冨埌钀戒綅鎵?1锛夈€佹敹璧锋椂鎸?[0.45,1] 绾挎€ф贰銆?
    //   鍚屼竴鏉?`p` 涓ょ鍍忕礌瀹屽叏涓嶅悓 鈬?"灞曞紑 鈮?鏀惰捣鍊掓斁"鐨勭‖璇佹嵁锛屼篃鏄敹璧锋椂
    //   "鍏冪礌鍏堟病銆侀〉闈㈠啀鏀?鐨勪竴鍗婃潵婧愩€傜幇鍦ㄦ寜鐢ㄦ埛瀹氳皟銆屼笉瑕佹贰鍏ユ贰鍑恒€嶏細
    //   鎭掍负 1锛屽嚭鍦哄畬鍏ㄤ氦缁欎綅绉伙紙`earlyRiseVp` / `contentRiseVp`锛変笌瑁佸壀绐楀彛銆?
    //   灏侀潰涓嶅湪杩欓噷绠★細瀹冩湁 `realCoverVisible()` 涓?`morphBridging()` 閭ｄ竴瀵逛弗鏍间簰琛ョ殑闂ㄣ€?
    this.morphContentOpacity = 1;
  }

  /**
   * 杩涘叆灞曞紑闃舵锛堝彲璺熸墜锛夈€?
   *
   * 鈿狅笍 **瀹冧笉鍐嶈嚜宸变綔搴熺粓鐐归敋鐐?*锛?026-09-25 浜屾淇锛夈€?
   *
   * 涓婁竴鐗堟妸 `bigNodeKnown = false` 鏀惧湪杩欓噷锛岀洿鎺ユ墦鏂簡涓€鏉￠摼锛?
   * ```
   *   measureMini()        鈫?姝ゅ埢椤甸潰杩樻槸鍘熷昂瀵革紝bigNode 閲忓埌锛宐igNodeKnown = true
   *   morphBeginEntering() 鈫?绔嬪埢 bigNodeKnown = false        鈫?鍒氶噺鍒扮殑琚墧鎺?
   *   morphIntroAnchorsReady() 鈫?鎭?false锛堣姹?bigNodeKnown锛?
   *   鈫?12脳32ms 閲嶈瘯锛涗絾 morphStage 宸叉槸 ENTERING 鈬?morphLive() 涓虹湡
   *   鈫?measureMini 閲屻€?morphLive() 鎵嶉噺 bigNode銆嶆妸琛ラ噺姘镐箙鎸℃
   *   鈫?閲嶈瘯鐢ㄥ敖 鈫?鏃犲姩鐢昏惤浣嶃€?*鐐瑰嚮鎵撳紑杩欐潯璺粠鏉ユ病杩涜繃 playMorphOpenIntro()**
   * ```
   * 鐜板湪鎶?浣滃簾"鎻愬埌璋冪敤鏂癸紝椤哄簭鐢?{@link prepareMorphEntry} 鍥哄畾涓?
   * **浣滃簾 鈫?鍦ㄥ師灏哄鏃堕噺 鈫?鍐嶅帇璧风偣**锛坄invalidateEndAnchor()` 蹇呴』鍏堜簬 `measureGeometry()`锛夈€?
   * @returns 鍑犱綍鏄惁鍙敤锛歠alse 鏃惰皟鐢ㄦ柟搴旀敼璧?涓嶅舰鍙?鐨勫厹搴曡矾寰?
   *          锛堝惁鍒欎細鎶婃挱鏀鹃〉鍘嬫垚 1vp 鐨勪竴鏉＄粏缂濓級銆?
   */
  public morphBeginEntering(): boolean {
    this.morphStage = MorphStage.ENTERING;
    this.morphDrive = MorphDrive.FINGER;
    this.morphGen = this.morphGen + 1;
    this.metaBridgeGeneration = this.morphGen;
    const ok: boolean = this.morphInitParams();
    this.sourceBarHidden = ok;
    Logger.info('RzdMorphOwnership', `enter gen=${this.morphGen} sourceHidden=${ok} meta=${this.metaBridgeActive}`);
    this.applyMorphProgress(0);
    Logger.info(PlayerExpandState.logTag,
      `morph entering usable=${ok} anchorsReady=${this.morphIntroAnchorsReady()} p=0 gen=${this.morphGen}`);
    return ok;
  }

  /**
   * 浣滃簾缁灏侀潰鐨?*缁堢偣閿氱偣**锛坄bigNodeKnown`锛夈€?
   *
   * 涓轰粈涔堝繀椤讳綔搴燂細缁堢偣鏄?鎾斁椤靛皝闈?*褰撳墠**鐨勭獥鍙ｇ煩褰?锛岃€岀獥鍙ｅ昂瀵?/ 鏂偣 / Swiper 椤?/
   * 鎾斁鎬佸脊绨ч兘鍙兘鍙樿繃锛涙部鐢ㄥ嚑杞箣鍓嶇殑鏃х煩褰紝灏变細"椋炶繃鍘讳簡鍗存病钀藉埌灏侀潰涓?銆?
   *
   * 鈿狅笍 **璋冪敤椤哄簭鏄‖绾︽潫**锛氭湰鏂规硶蹇呴』鍦?`measureGeometry()` **涔嬪墠**璋冿紝
   *    鍚﹀垯鍒氶噺鍒扮殑缁堢偣鍙堜細琚姽鎺夛紙涓婁竴鐗堝氨鏄繖涔堟妸鐐瑰嚮璺緞鎵撴鐨勶級銆?
   */
  public invalidateEndAnchor(): void {
    this.bigNodeKnown = false;
    // 鈽?2026-10-16锛堢収鎼棤鐣岋級锛氱粓鐐逛綔搴?鈬掋€屽嚑浣曞氨缁€嶄篃涓€骞朵綔搴燂紙`beginMorphEnter` 閲?
    //   `morphSeq++` 涓?`morphGeomReady = false` 鏄悓涓よ锛宍wujie.pa` 146581-146589锛夈€?
    //   鍚﹀垯涓婁竴杞噺鍒扮殑缁堢偣浼氳褰撴垚鏈疆鐨?鈬?瀹瑰櫒鎸夎繃鏈熷嚑浣曡惤浣嶏紙"椋炶繃鍘讳簡鍗存病钀藉埌灏侀潰涓?锛夈€?
    this.morphGeomReady = false;
  }

  /**
   * 閲忎竴娆?缁灏侀潰鐨勭粓鐐归敋鐐?锛堟挱鏀鹃〉鐨勫ぇ灏侀潰锛夈€?
   *
   * 鈿狅笍 涓?{@link measureGeometry} 鍒嗗紑銆佷笖**涓嶅彈 `morphLive()` 闂ㄩ檺鍒?*锛?
   *    鐐瑰嚮灞曞紑鏃?`morphStage` 宸茬粡鏄?ENTERING锛堥噸璇曠獥鍙ｉ噷锛夛紝浣嗛偅 1~2 甯ф挱鏀鹃〉
   *    **杩樻病琚帇鍒拌捣鐐?*锛坄applyMorphProgress(0)` 鍙槸鎶婄姸鎬佸啓濂斤紝鐪熸鐨勮鍓獥鍙?
   *    瑕佺瓑涓嬩竴甯ф覆鏌擄級锛屾鍒婚噺鍒扮殑浠嶆槸**鍘熷昂瀵?*鐨勫皝闈㈢煩褰?鈥斺€?杩欐鏄棤鐣?
   *    `setupExpandTransition` 閲?鍏堥噺鍚庣缉"瑕佺殑閭ｄ釜鍊笺€?
   *    閲嶈瘯鏈熼棿鍙嶅璋冨畠鏄畨鍏ㄧ殑锛氶噺鍒板氨瀹堢潃锛坄morphInitParams` 浼氱敤瀹冪畻缁堢偣锛夈€?
   * @param ui UIContext
   * @returns 鏄惁閲忓埌浜嗙粓鐐归敋鐐?
   */
  public measureEndAnchor(ui: UIContext): boolean {
    const node: NodeRect | undefined = this.measureNode(ui, PLAYER_BIG_COVER_ID, true);
    if (node === undefined || node.w <= 0) {
      return false;
    }
    // 鎶?甯冨眬鐭╁舰"涓?鏂藉姞鍦ㄥ皝闈笂鐨勮瑙夌缉鏀?鎷嗗紑瀛橈紙瑙?bigNodeScaleX/Y 鐨勮鏄庯級锛?
    //   `getPositionToWindowWithTransform()` 宸茬粡鎶?scale 绠楄繘浣嶇疆涓庡昂瀵镐簡锛?
    //   杩欓噷闄ゆ帀瀹冿紝缁樺埗妗ユ帴灏侀潰鏃跺啀涔樺洖鏉?鈥斺€?寮圭哀鍦ㄥ姩鐨勬椂鍊欎袱绔篃涓€鑷淬€?
    const s: number = this.coverScaleLive();
    this.bigNodeScaleX = s;
    this.bigNodeScaleY = s;
    // 瀹樻柟锛歡etMeasuredSize 鏄竷灞€澶у皬锛坧x锛夛紝涓嶅惈 scale锛涘彧鏈夌獥鍙ｄ綅缃惈缁樺埗鍙樻崲銆?
    this.bigNodeW = node.w;
    this.bigNodeH = node.h;
    // Natural layout coordinates exclude both cover scale and ancestor container/chrome transforms.
    this.bigNodeX = node.x;
    this.bigNodeY = node.y;
    this.bigNodeKnown = true;
    return true;
  }

  /**
   * @returns 褰㈠彉灞曞紑鎵€闇€鐨?*涓や釜閿氱偣**鏄惁閮界湡鐨勫氨缁紙璧风偣 = 杩蜂綘鏉★紝缁堢偣 = 鎾斁椤靛皝闈級銆?
   *
   * 涓轰粈涔堝崟鐙垽瀹冿紙杩欐槸"绗竴娆″睍寮€娌℃湁灏侀潰椋炲叆 / 鐐瑰嚮鎵撳紑鍍忔棫鍔ㄧ敾"鐨勫叧閿級锛?
   *   路 鍙垽"杩蜂綘鏉￠噺鍒颁簡銆佸涓荤鏈夊昂瀵?灏卞紑璺戞椂锛?*缁堢偣閿氱偣**锛堟挱鏀鹃〉灏侀潰锛夊線寰€杩樻病甯冨眬瀹?
   *     鈥斺€?`endCoverSize` 涓?0 鈫?`morphBridging()` 涓?false 鈫?鍏ㄧ▼娌℃湁灏侀潰杩欎竴妫掞紱
   *   路 鎾斁椤甸偅鏉″皝闈㈠壇鏈張鏄?钀戒綅鎵嶇幇"锛坄morphContentOpacity`锛夛紝浜庢槸澶翠竴涓ゆ灞曞紑
   *     瑙傛劅灏辨槸"鐐瑰紑鈫掍粈涔堥兘娌℃湁鈫掑暘涓€涓嬪埌浣?锛屽拰鏃у姩鐢诲嚑涔庡垎涓嶅嚭鏉ャ€?
   * 鎵€浠ヨ皟鐢ㄦ柟锛坄PlaybackPage.playExpandIntro`锛夊繀椤荤瓑杩欎釜鏉′欢鎴愮珛鎵嶅紑濮嬪舰鍙橈紱
   * 绛変笉鍒板氨缁х画 12脳32ms 閲嶈瘯锛岀敤灏芥墠鏃犲姩鐢昏惤浣嶃€?
   */
  public morphIntroAnchorsReady(): boolean {
    // 鈿狅笍 鍒ゆ嵁瑕?*鍚屾椂鎺ュ彈涓ゆ潯鏉ユ簮**锛堜笂涓€鐗堝彧璁?`bigNodeKnown`锛屾妸鐐瑰嚮璺緞鍒ゆ浜嗭級锛?
    //   路 `bigNodeKnown` 鈥斺€?璧?FrameNode 閲忓埌鐨勶紙鏈€鍑嗭紝鎹㈢畻杩囪瑙夌缉鏀撅級锛?
    //   路 `bigSize > 0`   鈥斺€?`MusicPlayInfoBlock.reportBig()` 鐢?`onAreaChange` 涓婃姤鐨勫厹搴曞€笺€?
    //     鍙嶇紪璇戜晶涔熶細閫€鍥?`onAreaChange` 鐨勫€硷紝鑰?绗竴娆℃墦寮€"鏃堕〉闈㈠垰鎸傝浇銆?
    //     FrameNode 鍙兘杩樻嬁涓嶅埌 鈥斺€?鍙鍓嶈€呯殑璇濊繖涓€娆″氨蹇呯劧閫€鍖栥€?
    const endKnown: boolean = (this.bigNodeKnown && this.bigNodeW > 0) || this.bigSize > 0;
    return this.morphUsable && endKnown && this.endCoverSize > 0;
  }

  /** @returns 鎾斁椤靛皝闈紙褰㈠彉缁堢偣锛夎繖涓敋鐐规槸鍚﹂噺鍒拌繃 鈥斺€?鍙粰鏃ュ織鐢紝鎺掓煡"娌℃湁灏侀潰椋炲叆"銆?*/
  public bigCoverAnchored(): boolean {
    return this.bigNodeKnown;
  }

  /** @returns 涓栦唬鍙锋槸鍚﹁繕鏄崟鑾锋椂閭ｄ竴涓紙寤舵椂鍥炶皟鐢ㄥ畠涓㈠純杩囨湡鍔ㄤ綔锛夈€?*/
  public morphGenAlive(gen: number): boolean {
    return gen === this.morphGen;
  }

  /** 灞曞紑鏀跺熬瀹屾垚锛氳繘鍏ョǔ瀹氬睍寮€鎬併€?*/
  public morphSettleOpen(): void {
    this.morphStage = MorphStage.OPEN;
    this.morphDrive = MorphDrive.NONE;
    // 落定 = 内容时间线也收尾（两条线回到同一档；`applyMorphProgress(1)` 会把 `contentP` 一并写 1）。
    this.cancelContentTween();
    this.applyMorphProgress(1);
    // 鈽呪槄鈽?2026-10-17锛?*鐓ф惉鏃犵晫 `位1onFinish`**锛夛細琛ラ棿璺戝埌 1 鏃跺渾瑙掔鐐硅繕鏄?34锛?
    //   鐢?onFinish 鎶婂畠**褰?0** 鈥斺€?涓婃父閭ｄ袱琛屽氨鏄?`radius = 0`锛坄overlayColor` 鍚屾椂褰掗€忔槑锛夈€?
    //   涓嶅綊 0 鐨勮瘽锛岃惤瀹氬悗灞忎笂浼氱暀 34vp 澶у渾瑙掞紙= 鐢ㄦ埛浠ュ墠鎶ヨ繃鐨?鍦嗚涓嶄竴鏍?锛夈€?
    this.morphRadius = 0;
    if (this.metaBridgeActive) {
      this.logMetaFont(false, 'complete');
      this.logMetaFont(true, 'complete');
    }
    this.releaseMorphOwnership(false);
    this.logMorphOwnership('settled-open');
    Logger.info(PlayerExpandState.logTag, 'morph open (settled)');
  }

  /** 寮€濮嬫敹璧枫€?*/
  public morphBeginLeaving(): void {
    this.sourceBarHidden = true;
    this.morphStage = MorphStage.LEAVING;
    this.morphDrive = MorphDrive.ANIM;
    // ★ 关闭：先交还内容取值口。上游关闭那条 `animateMorphT(reverseMs, 0, REVERSE_EASING)`
    //   驱动的是**同一条** `morphT` ⇒ 交还之后 `contentProgress()` 直接读 `morphP`，
    //   两层共用播放页那条 `460 × max(0.4, morphT)` + `REVERSE_EASING` 的补间（不拆成两条）。
    this.cancelContentTween();
    this.morphGen = this.morphGen + 1;
    this.metaBridgeGeneration = this.morphGen;
    this.logMorphOwnership('begin-leaving');
    Logger.info(PlayerExpandState.logTag,
      `morph leaving from p=${this.morphP.toFixed(3)} gen=${this.morphGen}`);
  }

  /** 钀藉洖杩蜂綘鏉★紙瀵规爣 LANDING锛氭鏃?*涓嶅啀閲嶇粯鎾斁椤靛唴瀹?*锛屽彧鐣欒糠浣犳潯锛夈€?*/
  public morphLand(): void {
    this.morphStage = MorphStage.LANDING;
    this.morphDrive = MorphDrive.NONE;
    this.releaseMorphOwnership(true);
    this.logMorphOwnership('land-mini');
    Logger.info(PlayerExpandState.logTag, 'morph land (hand back to mini bar)');
  }

  /** 澶嶄綅鍒?娌℃湁杩欏鍔ㄧ敾"鐨勯潤姝㈡€侊紙鍑犱綍缂哄け銆佸嵏杞姐€佸紓甯告椂閮借蛋杩欓噷锛夈€?*/
  public morphReset(): void {
    this.releaseMorphOwnership(true);
    this.morphGen = this.morphGen + 1;
    this.morphStage = MorphStage.NONE;
    this.morphDrive = MorphDrive.NONE;
    this.morphP = 1;
    // ★ 内容时间线一起复位（会话结束 ⇒ 两条线都回到"已落位"这一档；静止态必须同值）。
    this.cancelContentTween();
    this.contentP = 1;
    // 鈽?娴眰閭ｄ竴灞傦紙`morphOverlayP`锛?60ms 閭ｆ潯鏃堕棿绾匡級**涔熷繀椤诲湪杩欓噷娓?*锛?
    //   浼氳瘽缁撴潫/鍗歌浇涔嬪悗瀹冪殑琛ラ棿杩樺彲鑳芥寕鍦ㄩ偅 560ms 鐨勫熬宸翠笂锛屼笉娓呯殑璇?
    //   涓嬩竴杞捣鎵嬬涓€甯т細鎸?娈嬬暀杩涘害"鐢讳竴娆℃诞灞傚皝闈紙瑙傛劅鏄棯涓€涓嬪ぇ鍥撅級銆?
    this.morphOverlayReset();
    // 鍑犱綍涔熶竴璧蜂綔搴燂細涓嬫灞曞紑蹇呴』閲嶆柊閲忎竴閬嶏紙瀹夸富灏哄/杩蜂綘鏉′綅缃兘鍙兘鍙樹簡锛?
    this.morphUsable = false;
    // 鈽?2026-10-16锛堢収鎼棤鐣岋級锛氳繛鍚?鍑犱綍灏辩华"涓€璧蜂綔搴?鈥斺€?涓嬩竴杞繀椤婚噸鏂伴噺鍒扮粓鐐规墠瀹硅
    //   钀介潪鎭掔瓑鍑犱綍锛坄applyMorphProgress` 鐨勯偅閬撻棬锛夈€傗殸锔?涓嶆竻鐨勮瘽锛岀偣鍑绘墦寮€鏃?
    //   "鏃у疄渚嬪嵏杞界殑 morphReset"涔嬪悗锛屾柊涓€杞細鍦?*娌℃湁缁堢偣**鐨勬儏鍐典笅琚斁琛?鈬?鍙堝洖鍒版棫 bug銆?
    this.morphGeomReady = false;
    // 浼氳瘽缁撴潫锛氫笅涓€杞睍寮€瑕佷粠"浣滃簾缁堢偣 鈫?鍦ㄥ師灏哄鏃堕噺 鈫?鍘嬭捣鐐?閲嶆柊璧颁竴閬?
    this.morphSessionStarted = false;
    this.morphScale = 1;
    this.morphTx = 0;
    this.morphTy = 0;
    this.morphClipHeight = 0;
    this.morphRadius = 0;
    this.morphContentOpacity = 1;
    Logger.info(PlayerExpandState.logTag, 'morph reset');
  }

  /**
   * @returns **鐪熺殑鍦ㄦ挱褰㈠彉**锛堜笉鏄?閲嶈瘯绐楀彛閲屾寕鐫€"锛夈€?
   *
   * 鈿狅笍 澹冲眰鍏嬮殕灞傜敤瀹冨綋娓叉煋闂紝鍒敤 `morphContainerActive()`锛?
   *    鐐瑰嚮鎵撳紑鏃朵細鍏堣繘 ENTERING 鍐嶉噸璇曟渶澶?12脳32ms锛堚増400ms锛夛紝杩欐绐楀彛閲?
   *    褰㈠彉鍏跺疄杩樻病寮€濮嬶紝浣?`morphContainerActive()` 宸茬粡鏄?true銆乣morphP` 宸茬粡鏄?0
   *    鈬?`actionsOpacityAt(0) = 1` 鈬?**鍏嬮殕灞傚湪灞忎笂鍏ㄤ寒鍦版紓浜?400ms**
   *    锛堢敤鎴峰疄娴嬬殑"涓変釜鎸夐挳涓€鐩存紓绉?灏辨槸杩欎釜"鍋囧姩鐢?娈碉級銆?
   *    鍙湁"鎵嬫寚姝ｅ湪椹卞姩"鎴?琛ラ棿鍔ㄧ敾椹卞姩"鎵嶇畻鐪熷湪鎾€?
   */
  public morphSessionDriving(): boolean {
    if (!this.morphUsable || !this.morphContainerActive()) {
      return false;
    }
    if (this.morphDrive === MorphDrive.ANIM) {
      return true;
    }
    return this.morphDrive === MorphDrive.FINGER &&
      (this.pullDragging || this.morphStage === MorphStage.LEAVING);
  }

  /** @returns 鐜板湪鏄惁闇€瑕佺粰鎾斁椤靛瑁佸壀瀹瑰櫒锛堥潤姝㈡€?false = 瀹屽叏涓嶈鍓級銆?*/
  public morphContainerActive(): boolean {
    return this.morphStage === MorphStage.ENTERING || this.morphStage === MorphStage.LEAVING ||
      this.morphStage === MorphStage.LANDING;
  }

  /**
   * @returns 鏈疆褰㈠彉鐨?*缁堢偣鍑犱綍**鏄惁宸查噺鍒帮紙= 瀹瑰櫒鍙互钀介潪鎭掔瓑 `scale/translate/clip`锛夈€?
   *
   * 瀵规爣鏃犵晫 `PlayerPage.pullGeomReady`锛坄wujie.pa` 168236 / 176221 / 176232锛夛細
   * 閭ｄ袱涓皟鐢ㄧ偣锛坄onPullTChanged` 鐨勯棬銆乣publishMorphTargets` 鐨勭疆浣嶏級灏辨槸瀹冪殑鍏ㄩ儴璇箟
   * 鈥斺€?**"鍑犱綍娌￠綈灏卞埆鍔ㄥ鍣?**銆?
   *
   * 鈿狅笍 涓?{@link morphUsable} 鐨勫垎宸ワ細
   *   路 `morphUsable` 鈥斺€?`morphInitParams()` 绠楀嚭鏉ヤ簡锛堜袱涓鐐归兘鏈変竴浠藉€硷級锛?
   *   路 `morphGeomReady` 鈥斺€?**鏈細璇濈湡鐨勯噺鍒颁簡缁堢偣閿氱偣**锛屽彲浠ヨ惤浣嶃€?
   *   鍓嶈€呬細鍥犱负"閫€鍥?onAreaChange 鍏滃簳鍊?鑰屼负鐪燂紝鍚庤€呬笉浼?鈥斺€?钀戒綅闂ㄥ繀椤荤敤鍚庤€呫€?
   * 鎺掓煡鍏抽敭瀛楋細`grep morph geom ready`锛坄hdc shell hilog -x | Select-String 'morph geom ready'`锛夈€?
   */
  public morphGeomReadyNow(): boolean {
    return this.morphGeomReady;
  }

  /**
   * 缁?*鏀惰捣**閭ｄ竴渚х敤鐨勫厹搴曪細鎶?鍑犱綍灏辩华"杩欎竴浣嶆斁琛屻€?
   *
   * 渚濇嵁锛氭棤鐣岀殑鏀惰捣鏄粠**宸茬粡钀戒綅鐨勬墦寮€鎬?*鍙嶅悜璺戝悓涓€鏉″叕寮?
   * 锛坄MainPage.closeWithAnimation` 鈫?`animateMorphT(reverseMs, 0, REVERSE_EASING)`锛夛紝
   * 閭ｆ椂瀹瑰櫒鏈潵灏辨槸 identity銆佷袱绔殑绔偣鍑犱綍鏃╁氨鏈変簡锛涘畠**涓嶄細**鍦ㄦ敹璧疯矾涓婂啀鍘婚噺涓€閬嶇粓鐐广€?
   * 鎴戜滑杩欒竟澶氫竴閬?`morphGeomReady` 闂紙涓轰簡鎸′綇"鐐瑰嚮鎵撳紑鏃剁敤鍗婁唤鍑犱綍钀戒綅"锛夛紝
   * 鎵€浠ユ敹璧峰墠蹇呴』纭杩欎竴浣嶆槸寮€鐨?鈥斺€?鍚﹀垯 `applyMorphProgress(0)` 浼氳鎸℃帀 鈬?
   * 鏀惰捣琛ラ棿**鏁存鏄┖杞?*锛堢敤鎴峰疄娴嬨€岀偣鍑诲叧闂?/ 绯荤粺杩斿洖鍏抽棴娌℃湁鍔ㄧ敾銆嶏級銆?
   *
   * 鈿狅笍 鍙湪"杩欎竴浣嶅洜涓哄紓甯歌矾寰勬病寮€銆佷絾绔偣鍑犱綍鍏跺疄鎷垮緱鍒?鏃舵墠鐢辫皟鐢ㄦ柟璋冨畠锛?
   *    `morphInitParams()` 杩斿洖 false锛堣繛鐩掑瓙/鑳跺泭閮芥病閲忓埌锛夋椂**涓嶇疆浣?*锛?
   *    璁╂敹璧疯惤鍒?鏃犲舰鍙?鐨勯€€鍖栬矾寰勪笂锛堝畞鍙病鍔ㄧ敾涔熶笉瑕侀閿欎綅缃級銆?
   * @returns 鏄惁宸插氨缁?
   */
  public ensureMorphGeomForClose(): boolean {
    if (this.morphGeomReady) {
      return true;
    }
    if (!this.morphInitParams()) {
      return false;
    }
    this.morphGeomReady = true;
    this.pushMorphTrace('geomReadyClose');
    Logger.info(PlayerExpandState.logTag, 'morph geom ready (close path fallback)');
    return true;
  }

  /** @returns 褰㈠彉鏄惁"娲荤潃"锛堝鏍?`morphLiveOf`锛欵NTERING / LEAVING / LANDING锛夈€?*/
  public morphLive(): boolean {
    return this.morphStage === MorphStage.ENTERING || this.morphStage === MorphStage.LEAVING ||
      this.morphStage === MorphStage.LANDING;
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鍏抽棴钀藉湴鐨?*鎾斁鏉℃尋鍘嬪洖寮?*锛堝鏍囨棤鐣?`squashLand` / `animateSquash`锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 鈽呪槄 2026-10-15锛堜慨鐢ㄦ埛瀹炴祴銆?*鏃犵晫鍏抽棴鏃舵挱鏀炬潯浼氬脊涓€涓?*銆嶏級锛?
  //   鏃犵晫 1.2.4 鐨勬敹璧疯惤浣嶄笉鏄?鍟竴涓嬩氦杩樿糠浣犳潯"锛岃€屾槸**鍏堝帇鎵併€佸啀寮瑰洖**锛?
  //   ```
  //     squashLand()  L153727-153800
  //       setMorph(LANDING, ANIM)                       // 杩欎竴甯ф挱鏀鹃〉涓嶅啀缁樺埗
  //       animateSquash(SQUASH_Y=0.86, SQUASH_MS=110, EASE_OUT_STR)   // 鈫?鍘嬪埌 0.86
  //         onDone 鈫?finishReverse(true)
  //     绱ч殢鍏跺悗鐨勫洖寮癸紙L163786-163855锛岀幓鐠冭兌鍥?瑙﹀簳寮瑰洖"锛?
  //       animateSquash(鈫?, SQUASH_BACK_MS=320, SQUASH_BACK_EASING="cubic-bezier(0.34,1.56,0.64,1)")
  //   ```
  //   鍑哄锛歚_recover/logic-src/寮€鍏虫挱鏀惧櫒-鎵嬪娍璺緞瀹氱.md` 搂4 鍏ㄨ〃锛圠465-468 閭ｄ笁琛岋級
  //   + `褰㈠彉寮曟搸-婧愭敞鍐屼笌鍙傛暟鎬昏〃.md` L153-156 鐨勫父閲忚〃銆?
  //   鈿狅笍 `SQUASH_Y` 鏄?*绾靛悜姣斾緥**锛屼箻鍦?*杩蜂綘鏉¤兌鍥?*涓婏紙涓嶆槸鎾斁椤碉級鈥斺€?鏃犵晫閭ｄ竴渚?
  //      `PlayerPage` 鍙妸瀹冨綋"鏄惁杩樼敾"鐨勫竷灏旈棬璇伙紙`morphSquashing`锛孶2 宸查棴鍚堬級锛?
  //      鐪熸鐨?`脳 0.86` 钀藉湪 `MainPage` 鐨勮兌鍥婁笂銆傛墍浠ヨ繖閲屼篃鏄姞鍦ㄨ糠浣犳潯涓娿€?
  /** 鎸ゅ帇鏃剁殑绾靛悜姣斾緥锛堟棤鐣?`SQUASH_Y = 0.86`锛夈€?*/
  public static readonly SQUASH_Y: number = 0.86;
  /** 鍘嬩笅鍘荤殑鏃堕暱锛坢s锛屾棤鐣?`SQUASH_MS = 110`锛夈€?*/
  public static readonly SQUASH_MS: number = 110;
  /** 寮瑰洖鏉ョ殑鏃堕暱锛坢s锛屾棤鐣?`SQUASH_BACK_MS = 320`锛夈€?*/
  public static readonly SQUASH_BACK_MS: number = 320;

  /**
   * 杩蜂綘鏉¤兌鍥婄殑**绾靛悜鎸ゅ帇姣斾緥**锛? = 鍘熸牱锛夈€?
   *
   * 鐢辨挱鏀鹃〉鍦?鏀惰捣钀戒綅"閭ｄ竴鍒昏捣涓ゆ潯琛ラ棿锛堣 {@link squashLandAnim}锛夐┍鍔紱
   * 闈欐鎬佹亽涓?1 鈬?涓嶆敼鍙樹换浣曢潤鎬佺増闈€?
   */
  @Trace public morphSquashY: number = 1;

  /**
   * 璺戜竴娆℃棤鐣岀殑"钀藉湴鎸ゅ帇 鈫?鍥炲脊"锛坄squashLand` 鐨勯偅涓ゆ潯琛ラ棿锛夈€?
   *
   * 鈿狅笍 涓ゆ潯**鍏辩敤鍚屼竴涓?`animateTo` 闂寘鍐欏悓涓€涓瓧娈?*鏄埢鎰忕殑锛歚morphSquashY` 鍙槸涓€鏉?
   *   绔栫洿绾夸笂鐨勬爣閲忥紝鍏堝悗涓ゆ鍚勮嚜鐢辨椂闀夸笌鏇茬嚎鍐冲畾褰㈢姸锛涘垎鎴愪袱涓ˉ闂存槸鍥犱负鏃犵晫鐨?
   *   `SQUASH_MS(110)` 涓?`SQUASH_BACK_MS(320)` **涓嶆槸鍚屼竴娈?*锛堝帇涓庡脊鍚勮嚜璁℃椂锛夈€?
   * 鈿狅笍 蹇呴』鍦?*鎾斁椤靛凡缁忚繘鍏?LANDING 涔嬪悗**璋冪敤锛堟棤鐣?`squashLand` 鐨勯『搴忓氨鏄?
   *    `setMorph(LANDING)` 鈫?`animateSquash`锛夆€斺€?鍚﹀垯浼氱湅鍒?鎾斁椤佃繕鍦ㄧ敾銆佽糠浣犳潯鍏堝脊"銆?
   * @param ui 璧疯ˉ闂寸敤鐨?UIContext锛堟挱鏀鹃〉鑷繁鐨勶級
   */
  public squashLandAnim(ui: UIContext): void {
    if (ui === undefined) {
      // 鎷夸笉鍒?UIContext锛氫笉寮逛篃涓嶈兘鎶婅兌鍥婃案涔呭帇鍦?0.86 涓?
      this.morphSquashY = 1;
      return;
    }
    this.morphSquashY = 1;
    // 鈶?鍘嬪埌 SQUASH_Y锛?10ms锛孍ASE_OUT_STR锛?
    ui.animateTo({
      duration: PlayerExpandState.SQUASH_MS,
      curve: curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
    }, (): void => {
      this.morphSquashY = PlayerExpandState.SQUASH_Y;
    });
    // 鈶?寮瑰洖 1锛?20ms锛宍cubic-bezier(0.34, 1.56, 0.64, 1)` 鈥斺€?閭ｆ潯 >1 鐨勬帶鍒剁偣灏辨槸"杩囧啿鍥炲脊"锛?
    setTimeout((): void => {
      ui.animateTo({
        duration: PlayerExpandState.SQUASH_BACK_MS,
        curve: curves.cubicBezierCurve(0.34, 1.56, 0.64, 1)
      }, (): void => {
        this.morphSquashY = 1;
      });
    }, PlayerExpandState.SQUASH_MS);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdSquash land squashY=${PlayerExpandState.SQUASH_Y} down=${PlayerExpandState.SQUASH_MS}ms ` +
      `back=${PlayerExpandState.SQUASH_BACK_MS}ms easing=(0.34,1.56,0.64,1)`);
  }

  /** @returns 鏄惁鍏佽璺熸墜涓婃媺锛堝鏍?`pullGestureAliveOf`锛?*浠?ENTERING**锛夈€?*/
  public pullGestureAlive(): boolean {
    return this.morphStage === MorphStage.ENTERING;
  }

  /** @returns 鏄惁杩樿閲嶇粯鎾斁椤靛唴瀹癸紙瀵规爣 `playerPaintsOf`锛歀ANDING 鏃跺仠绗旓級銆?*/
  public playerPaints(): boolean {
    return this.morphStage !== MorphStage.LANDING;
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?涓夈€佹帶鍒跺尯锛堝鏍?PlayerChrome 鍒嗘。 + BarCollapse 鑷姩鏀惰捣锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 璇存槑锛?*涓嬫媺璺熸墜鏀惰捣**娲鹃煶宸茬粡瀹炵幇锛堣 `PlaybackPage.collapseProgress` + `PanGesture`锛夛紝
  // 鎵€浠ヨ繖閲屽彧琛ユ棤鐣屾湁銆佹垜浠病鏈夌殑涓や欢锛氭帶鍒跺尯**鎸夋。浣嶅彇灏哄**銆?*闈欐鑷姩鏀惰捣**銆?

  /** 鎺у埗鍖烘。浣嶏細0=COMPACT 1=MEDIUM 2=FULL 鈥斺€?**瀵规爣鏃犵晫 `PlayerChrome` 鐨勪笁妗?*銆?*/
  @Trace public chromeTier: number = 2;

  /**
   * 鈽呪槄鈽?2026-10-16锛堢収鎶勬棤鐣?`PlayerPage.padBottom()`锛宍wujie.pa:175250-175309`锛夛細
   *
   * ```
   *   padBottom = avoidBottom > 0 ? avoidBottom
   *                               : px2vp(WindowInfo.navIndicatorHeight_px)      // 175251-175276
   *   鈥﹀啀鎶埌锛歮ax(padBottom, playerChromeOf(playerChromeTierFor(usableH())).bottomGap)
   *                                                                             // 175277-175308
   * ```
   * 鈬?**搴曢儴璁╀綅鏈変竴涓?妗ｄ綅琛?`bottomGap`"鐨勪笅闄?*锛團ULL 65 / MEDIUM 48 / COMPACT 36锛夈€?
   *
   * 鈿狅笍 杩欓噷鏈変釜**寰幆**锛歚padBottom 鈫?tier 鈫?usableH 鈫?padBottom`銆傛棤鐣岄偅杈瑰畠鏄潬
   *   `playerChromeTierFor` **鑷繁涓嶅惈 `padBottom`**锛堝彧鍚?`usableH` 涓€涓弬鏁帮級瑙ｅ紑鐨勶紱
   *   鏈粨鐓у悓涓€鏉¤矾瑙ｏ細鍏堢敤**鍙墸瀹炴祴閬胯鍖?*鐨?`u0` 瀹氭。锛屽啀鎷块偅涓€妗ｇ殑 `bottomGap` 鎶簳銆?
   *   `tier` 鏄?0/1/2 涓夊€?鈬?杩欎釜閫掓帹**涓€瀹氭敹鏁?*锛堟渶澶氫笁绾э級銆?
   *
   * 鈿狅笍 鏀瑰墠鎴戜滑鐨勫啓娉曟槸**鍙敤瀹炴祴閬胯鍖?*锛堟敞閲婇噷鍐欑潃"涓嶅彇閭ｄ釜 floor 鏄负浜嗛伩鍏嶅惊鐜緷璧?锛夆€斺€?
   *   浣嗗惊鐜叾瀹炴槸鍙В鐨勶紝鑰屾棤鐣岀殑涓嬮檺鏄?*瀹炲疄鍦ㄥ湪**鐨勶細鏈満 `avoidBottom`锛? 鎴戜滑閲忓埌鐨?
   *   `navigationBarBottomVp`锛夐€氬父鍙湁 30~50vp锛岃€?FULL 妗ｄ笅闄愭槸 **65vp**
   *   鈬?鎴戜滑姣旀棤鐣?*灏戜簡 15~35vp 鐨勫簳閮ㄨ浣?*锛屾帶鍒跺尯鏁翠綋鍋忎綆銆乣usableH` 鍋忓ぇ銆?
   *
   * 鈿狅笍 **涓嶅奖鍝嶅皝闈㈠嚑浣?*锛歚playerCoverGeomRect()` 鐢ㄧ殑鏄?raw `navigationBarBottomVp`
   *   锛?217 琛岋級锛岃€屾棤鐣岀殑 `fitPlayerOverlay` 鏀剁殑鏄?**`overlayBoxH()`**锛? 瀹炴祴 `swiperBoxH`锛?
   *   `wujie.pa:177265-177268`锛夆€斺€?**涓ゆ潯閮戒笉鏄?`usableH()`** 鈬?鏈鏀瑰姩鍙姩"鎺у埗鍖洪绠?銆?
   * @returns 搴曢儴璁╀綅楂樺害锛坴p锛?
   */
  public padBottomVp(): number {
    // 鏃犵晫鐨?`avoidBottom` 鍒嗘敮锛氭湰浠撶殑绛変环鐗╁氨鏄疄娴嬮伩璁╁尯锛堥噺涓嶅埌鏃舵寜 0锛?
    const avoid: number = this.navigationBarBottomVp > 0 ? this.navigationBarBottomVp : 0;
    // 鈿狅笍 鐢?*鍙墸瀹炴祴閬胯鍖?*鐨?u0 瀹氭。锛堜笌鏃犵晫"tier 涓嶅惈 padBottom"鍚屾瀯锛?
    const u0: number = Math.max(0, this.windowHeightVp - this.topInsetVp() - avoid);
    const floor: number = this.chromeOf(this.tierForUsableH(u0)).bottomGap;
    return floor > avoid ? floor : avoid;
  }

  /**
   * 鍙敤楂樺害锛坴p锛夆€斺€?瀵规爣鏃犵晫 `PlayerPage.usableH()`锛?
   * `usableH = winHVp() 鈭?padTop() 鈭?padBottom()`锛坄wujie.pa:180610-180625`锛夈€?
   *
   * 鈽?2026-10-16锛歚padBottom()` 鐜板湪鎸夋棤鐣屽彇**妗ｄ綅琛?`bottomGap` 鐨勪笅闄?*锛堣 {@link padBottomVp}锛夈€?
   * @returns 鍙敤楂樺害锛坴p锛屸墺0锛?
   */
  public usableHVp(): number {
    const u: number = this.windowHeightVp - this.topInsetVp() - this.padBottomVp();
    return u > 0 ? u : 0;
  }

  // ═══════════ 上游 `padTop()` / `padBottom()` 的同名映射（给"背景宿主"那一层用） ═══════════
  //
  // 上游 `wujie.pa:191756-191800` 的那个 `Column()` 逐个属性（**直读字节码 `_recover/tmp/r191740.txt`**）：
  // ```
  //   191756  .function @36***#^5                        ← 正文列（playerPane 的父）
  //   191761-191771  Column().width(this.winWVp())
  //   191772-191782  .height(this.winHVp())
  //   191783-191800  .padding({ top: this.padTop(), bottom: this.padBottom() })
  //   191801-191822  .opacity(this.pullMode ? this.pullChromeOpacity() : this.expand.contentOpacity)
  //   191823-191844  .width(this.winWVp()) .height(this.winHVp())      ← 再写一遍
  // ```
  // 两个取值的原文（同名方法，本仓同名映射见下）：
  // ```
  //   padTop()      wujie.pa:175314-175353
  //     const v = this.avoidTop > 0 ? this.avoidTop
  //                                 : this.getUIContext().px2vp(WindowInfo.topAvoidAreaHeight_px);
  //     return 0 < v ? v : PLAYER_TOP_FALLBACK;          // 0x38 = 56
  //
  //   padBottom()   wujie.pa:175250-175309
  //     const avoid = this.avoidBottom > 0 ? this.avoidBottom
  //                                        : this.getUIContext().px2vp(WindowInfo.navIndicatorHeight_px);
  //     const usable = this.winHVp() - this.padTop() - avoid;
  //     const gap = playerChromeOf(playerChromeTierFor(usable)).bottomGap;
  //     return avoid > gap ? avoid : gap;                // = max(avoid, gap)
  // ```
  // ⚠️ 反汇编尾部 `greater 0x1f, v0` + `jnez` + `mov v0, v1` 就是上面那两个夹取/三元
  //   （`reg = reg OP acc` 语义，见 `全局记忆.md`）。
  //
  // ⛔ **这两个值不接到背景宿主** —— 回原文核清了节点归属：`wujie.pa:191756` 那个带 padding 的列是
  //   **正文列**；`MeshCoverBg`（`wujie.pa:191616` 那支 If，包装 λ 在 `:192088`）是它的**兄弟**，
  //   铺满 `Stack` 的 `clipHeight`，**不吃 padding**。依据：`wujie.pa:190966-190975` 创建 `If` 并立刻
  //   `If.pop()`，`:191008-191012` 才 `Column.create()` —— 两者同一个 λ 体内、且 `If` 先 pop。
  //   详见 `PlaybackPage` 背景宿主那段注释。

  /**
   * 上游 `PlayerPage.padTop()`（`wujie.pa:175314-175353`）⇒ 本仓等价量 {@link topInsetVp}。
   *
   * 上游：`avoidTop > 0 ? avoidTop : px2vp(WindowInfo.topAvoidAreaHeight_px)`，量不到兜
   * `PLAYER_TOP_FALLBACK = 56`；本仓 `topInsetVp()` = `max(statusBarTopVp, PLAYER_TOP_FALLBACK_VP) − pageBoxTop`
   * （同一把尺子：56 下限 + 实测让位，见该方法注释与 `RzdPageBoxTop` 日志）。
   * @returns 顶部让位（vp）
   */
  public bgHostPadTopVp(): number {
    return this.topInsetVp();
  }

  /**
   * 上游 `PlayerPage.padBottom()`（`wujie.pa:175250-175309`）⇒ 本仓等价量 {@link padBottomVp}
   * （`max(avoidBottom, 档位表 bottomGap)`；`bottomGap` = FULL 65 / MEDIUM 48 / COMPACT 36，
   * 见 `CHROME_TABLE` 与 `wujie.pa:93534 / 93554 / 93574`）。
   * @returns 底部让位（vp）
   */
  public bgHostPadBottomVp(): number {
    return this.padBottomVp();
  }

  /**
   * 鏃犵晫 `PlayerChrome` 妗ｄ綅琛ㄧ殑**鍩虹嚎楂樺害**锛坴p锛夆€斺€?鐓ф妱 `wujie.pa:93434` 鐨?`ldai 0x154`銆?
   *
   * ## 瀹冪殑鍚箟锛堣繖鏄湰杞渶鍙嶇洿瑙夌殑涓€鏉★級
   *
   * 鏃犵晫**涓嶆槸**鎷?鍚勬。鑷繁鐨?`total`"鍘诲綋鍒嗙晫鍊肩殑锛岃€屾槸鎷?*涓€涓浐瀹氬熀绾?340** 鍘诲噺
   * 鍚勬。鐨?`total`锛坄playerChromeTierFor`锛宍wujie.pa:93433-93473`锛夛細
   * ```
   *   if (340 >= FULL.total   鈭?usableH) return FULL      // 绛変环锛歶sableH >= 340 鈭?FULL.total
   *   if (340 >= MEDIUM.total 鈭?usableH) return MEDIUM    // 绛変环锛歶sableH >= 340 鈭?MEDIUM.total
   *   return COMPACT
   * ```
   * 鈬?闃堝€?= `340 鈭?total`锛?
   *
   * | 妗?| `total` | 闃堝€?`usableH >= 340 鈭?total` |
   * | --- | --- | --- |
   * | FULL | 250 | **90** |
   * | MEDIUM | 252 | **88** |
   * | COMPACT | 178 | 锛堝厹搴曪紝涓嶅垽锛?|
   *
   * 鈿狅笍 杩欎釜 340 **鏁呮剰涓嶅湪琛ㄩ噷**锛氫笁妗ｇ殑 `total` 閮?鈮?340锛屾墍浠?340 = "姣旀渶瀹芥澗閭ｆ。杩樺"鐨?
   *    鍙傜収楂樺害锛沗usableH` 瓒婃帴杩?340锛屽垎妗ｅ氨瓒婁弗銆?*涓嶈鎶婂畠鍜?`FULL.total` 娣蜂负涓€璋?*
   *    锛堟湰杞箣鍓嶇殑瀹炵幇涓庢敞閲婂氨鏄繖涔堥敊鐨勶紝瑙?`updateChromeTier` 鐨勬敼鍔ㄨ鏄庯級銆?
   */
  private static readonly CHROME_BASELINE_H_VP: number = 340;

  /**
   * 鏃犵晫 `PlayerChrome` 妗ｄ綅琛紙鐓ф妱 `wujie.pa:93534 / 93554 / 93574`锛屼竴琛屼竴妗ｏ級銆?
   *
   * 鈿狅笍 涓嬫爣涓?`chromeTier` **鍚屽簭**锛歚0 = COMPACT`銆乣1 = MEDIUM`銆乣2 = FULL`
   *   锛堣〃鍦ㄥ弽姹囩紪閲岀殑涔﹀啓椤哄簭鏄?FULL鈫扢EDIUM鈫扖OMPACT锛屼笌 `tier` 鐩稿弽 鈥斺€?鍒収涔﹀啓搴忔妱锛夈€?
   * 鈿狅笍 `total` **涓嶆槸**銆屽墠鍑犻」鐩稿姞銆嶏細`v2 = 58` 鏄?FULL/MEDIUM/COMPACT **涓夋。鍏辩敤**鐨勭浜旈」
   *   锛坄wujie.pa:93547-93551`锛夆噿 `total = topBarH + gapSwiper + gapScrub + playSize + 58`銆?
   */
  private static readonly CHROME_TABLE: PlayerChromeSpec[] = [
    // 0 = COMPACT锛坵ujie.pa:93574锛?
    new PlayerChromeSpec(36, 20, 14, 52, 28, 20, 18, 12, 20, 28, 36, 0.86, 178),
    // 1 = MEDIUM锛坵ujie.pa:93554锛?
    new PlayerChromeSpec(40, 32, 20, 62, 30, 21, 19, 13, 22, 38, 48, 0.92, 252),
    // 2 = FULL锛坵ujie.pa:93534锛?
    new PlayerChromeSpec(44, 48, 28, 72, 32, 22, 20, 14, 24, 50, 65, 1, 250)
  ];

  /** 鎸夋。鍙栬〃 鈥斺€?瀵规爣 `playerChromeOf(tier)`锛坄wujie.pa:93404`锛岃秺鐣屼竴寰嬭惤 FULL锛夈€?*/
  private chromeOf(tier: number = this.chromeTier): PlayerChromeSpec {
    if (tier === 0) {
      return PlayerExpandState.CHROME_TABLE[0];
    }
    if (tier === 1) {
      return PlayerExpandState.CHROME_TABLE[1];
    }
    return PlayerExpandState.CHROME_TABLE[2];
  }

  /**
   * `clamp(0.065 脳 h, 16, 56)` 鈥斺€?鐓ф妱鏃犵晫 `playerSwiperGapOf(h)`锛坄wujie.pa:93497-93519`锛夈€?
   *
   * 鈽?瀹冩槸**杩炵画閲?*锛屼笉鏄。浣嶆煡琛細`SWIPER_GAP_MIN = 0x10 = 16`銆乣SWIPER_GAP_MAX = 0x38 = 56`銆?
   * 鈿狅笍 杩欎竴鏉′篃鏄湰杞敤鏉?*閽夋鍙嶆眹缂栨搷浣滄暟鏂瑰悜**鐨勯偅鎶婂昂瀛愶紙瑙?`鍏ㄥ眬璁板繂.md`
   *    銆宍.pa` 閲?`OP dst, src` 鐨勫疄闄呰涔夋槸 `dst OP acc`銆嶏級鈥斺€?涓嶈鍐?椤烘墜鏀规垚鏌ヨ〃"銆?
   */
  private static swiperGapOf(hVp: number): number {
    const raw: number = 0.065 * hVp;
    if (16 < raw) {
      return 56 > raw ? raw : 56;
    }
    return 16;
  }

  /** 鎺у埗鍖?*涓夋缁撴瀯**閲?Swiper 涓庤繘搴︽潯涔嬮棿"閭ｆ牴鍗犱綅鏉＄殑**楂樺害**锛坴p锛夛細`playerSwiperGapOf(usableH)`銆?*/
  public swiperGapVp(): number {
    return PlayerExpandState.swiperGapOf(this.usableHVp());
  }

  /** 鎺у埗鍖?*涓夋缁撴瀯**閲?杩涘害鏉′笌浼犺緭鏉′箣闂?閭ｆ牴鍗犱綅鏉＄殑**楂樺害**锛坴p锛夛細`chrome().gapScrub`銆?*/
  public chromeGapScrubVp(): number {
    return this.chromeOf().gapScrub;
  }

  /**
   * 鎺у埗鍖?*瀹為檯鍗犵敤楂樺害**锛坴p锛夆€斺€?瀵规爣鏃犵晫 `playerChromeTotalOf(tier, h)`锛坄wujie.pa:93478`锛夛細
   * ```
   *   playerChromeTotalOf = playerChromeOf(tier).total 鈭?playerChromeOf(tier).gapSwiper
   *                                                      + playerSwiperGapOf(h)
   * ```
   * 璇箟锛氳〃閲岀殑 `total` 鐢ㄧ殑鏄?*璇ユ。鍥哄畾鐨?* `gapSwiper`锛岃€屽疄闄呴偅鏍瑰崰浣嶆潯璧扮殑鏄?*杩炵画**鍏紡
   * 鈬?鎶婅〃閲岄偅涓€浠芥崲鎴愬疄闄呴偅涓€浠姐€?*杩欎袱澶勫繀椤绘垚瀵瑰嚭鐜?*锛屽彧鏀逛竴澶村氨鏄?鎺у埗鍖洪珮搴︾畻閿欏嚑鍗?vp"銆?
   */
  public chromeTotalVp(): number {
    const c: PlayerChromeSpec = this.chromeOf();
    return c.total - c.gapSwiper + PlayerExpandState.swiperGapOf(this.usableHVp());
  }

  /**
   * Swiper 瀹瑰櫒锛堝皝闈㈤〉/姝岃瘝椤甸偅涓€鍧楋級鐨?*搴旀湁楂樺害**锛坴p锛夆€斺€?瀵规爣鏃犵晫 `PlayerPage.estBoxH()`
   * 锛坄wujie.pa:171554-171589`锛夛細
   * ```
   *   estBoxH = max(0, usableH() 鈭?playerChromeTotalOf(playerChromeTierFor(usableH()), usableH()))
   * ```
   *
   * 鈿狅笍 鏃犵晫閭ｈ竟瀹冨彧鏄?*鍏滃簳浼扮畻**锛氬鍣ㄧ湡閲忓埌楂樺害锛坄swiperBoxH`锛夋椂涓€寰嬩紭鍏堢敤瀹炴祴
   *   锛坄overlayBaseH()`锛宍wujie.pa:175141`锛夛紝鍙湁 `chromeHidden || swiperProgress 鈮?0.001`
   *   閭ｄ竴灏忔鏃堕棿娌￠噺鍒版墠鐢ㄦ湰鍑芥暟銆傛垜浠繖閲?*鍙妸瀹冨綋璇婃柇閲?*锛堣 `PlaybackPage` 鐨?
   *   `RzdSwiperBox` 鏃ュ織锛夛紝**涓嶅弬涓庡竷灞€** 鈥斺€?鐞嗙敱鍐欏湪涓嬮潰銆?
   *
   * ## 涓轰粈涔堟垜浠?*涓嶈兘**鍍忔棤鐣岄偅鏍锋嬁瀹冨綋纭珮搴?
   *
   * 鏃犵晫鐨?Swiper 瀹瑰櫒鏄?`layoutWeight(1)` + `.height(overlayBaseH())` **涓ゆ潯鑵?*锛氫及绠楀€艰礋璐?
   * "鎺у埗鍖烘敹璧?灞曞紑鏃堕偅涓€娈佃繃娓?锛屽疄娴嬪€间竴閲忓埌灏辨帴绠°€?
   * 鎴戜滑杩欎竴渚х殑 Swiper 涔熸槸 `layoutWeight(1)`锛屼絾鎺у埗鍖洪珮搴︽槸**鐢卞唴瀹规拺鍑烘潵鐨?*
   * 锛坄ControlAreaComponent` 鐨勮嚜鐒堕珮 + 鎴戜滑鐨?`gapSwiper`/`gapScrub` 涓ゆ牴鍗犱綅鏉★級
   * 鈬?鍐嶅彔涓€涓?`estBoxH` 灏辨槸**涓や釜婧愬悓鏃跺喅瀹氬悓涓€娈甸珮搴?*锛屾鏄湰杞箣鍓嶅弽澶嶈俯鐨?
   * "鍚屼竴褰㈢姸涓ゆ潯鍙ｅ緞"鐨勫舰鐘躲€傗噿 鍏堝彧鏀捐瘖鏂紝绛夌湡鏈轰笂閲忓嚭銆屽疄娴?Swiper 楂?vs `estBoxH`銆?
   * 宸灏戯紝鍐嶅喅瀹氭槸鍚︾収鎼偅涓ゆ潯鑵裤€?
   */
  public estBoxHVp(): number {
    const u: number = this.usableHVp();
    const inner: number = u - this.chromeTotalVp();
    return inner > 0 ? inner : 0;
  }

  /**
   * 鎸?*鍙敤楂樺害**鍐冲畾鎺у埗鍖烘。浣?鈥斺€?瀵规爣鏃犵晫 `playerChromeTierFor(usableH)`锛坄wujie.pa:93433-93473`锛夈€?
   *
   * 鈽呪槄鈽?2026-10-16锛?*鏀规涓€澶勭畻閿欑殑鍒ゆ嵁**锛屽瓧鑺傜爜閫愭潯澶嶆牳锛夛細
   *   鏀瑰墠鏄?`u >= 340 ? 2 : (u >= 252 ? 1 : 0)`銆?
   *   鈿狅笍 涓や釜閿欙細
   *     鈶?**340 琚綋鎴愪簡 `FULL.total`** 鈥斺€?瀹冨叾瀹炴槸**鍩虹嚎楂樺害**锛堣 `CHROME_BASELINE_H_VP`锛夛紱
   *     鈶?鍒嗙晫鍊兼柟鍚戝弽浜?鈥斺€?鏃犵晫鏄?`usableH >= 340 鈭?tier.total`锛屼笉鏄?`usableH >= tier.total`銆?
   *   鈬?姝ｇ‘闃堝€?**FULL 90 / MEDIUM 88**锛堟敼鍓嶆槸 340 / 252锛屽樊浜嗕竴涓噺绾э級銆?
   *
   *   鈿狅笍 涓轰粈涔堟敼鍓嶉偅鐗堣兘鍦ㄦ墜鏈轰笂"鐪嬬潃娌′簨"锛氭墜鏈虹珫灞?`usableH 鈮?800`锛?*涓ょ増閮借惤 FULL**
   *     鈬?杩欐槸涓?*鍙湪鐭獥鍙?妯睆鎵嶆毚闇?*鐨勯敊銆傚弽杩囨潵璇达紝鐢ㄦ埛鏈夊彲鑳界湅鍒扮殑鍙樺寲鏄細
   *     鏋佺煯绐楀彛锛坄usableH` 钀藉湪 88~252 涔嬮棿锛変粠"涓。/绱у噾妗?鍙樻垚"瀹芥澗妗?锛? 鎺у埗鍖哄彉澶э級銆?
   *     杩欐鏄棤鐣岀殑琛屼负锛堝畠閭ｈ竟 `usableH < 88` 鎵嶇粰 COMPACT锛夈€?
   *
   *   鈽?鎿嶄綔鏁版柟鍚戞槸鎬庝箞閽夋鐨勶紙鍒嚟鍗拌薄閲嶆帹锛夛細鍏堢敤璇箟宸茬煡鐨?`playerSwiperGapOf`
   *     锛坄clamp(0.065h,16,56)`锛夊弽璇侊紝瑙?`鍏ㄥ眬璁板繂.md`
   *     銆宍.pa` 閲?`OP dst, src` 鐨勫疄闄呰涔夋槸 `dst OP acc`銆嶃€?*鎸夐敊鐨勬柟鍚戣涔熶細寰楀埌涓€缁?
   *     鐪嬭捣鏉ュ畬鍏ㄨ嚜娲界殑闃堝€?*锛屾墍浠ラ偅鏉＄邯寰嬩笉鑳界渷銆?
   * @param _widthVp 鏃х鍚嶄繚鐣欙紙璋冪敤鐐逛紶鐨勫搴?*涓嶅啀鍙備笌瀹氭。**锛夛細瀹藉睆閭ｄ竴鏀殑宸紓
   *   鐢?`鈶?瀹藉睆/闈㈡澘缁熶竴` 閭ｄ竴鍧楄礋璐ｏ紝涓嶅湪杩欓噷娣疯繘鏉ャ€?
   */
  /**
   * @returns 鎸?*鍙敤楂樺害**瀹氭。锛堢函鍑芥暟锛屼笉璇诲瓧娈碉級鈥斺€?瀵规爣 `playerChromeTierFor(usableH)`
   *   锛坄wujie.pa:93433-93473`锛夈€?
   *
   * 鈿狅笍 鎶芥垚绾嚱鏁版槸**蹇呴』**鐨勶細`padBottomVp()` 瑕佺敤瀹冩潵瑙ｉ偅涓?
   *   `padBottom 鈫?tier 鈫?usableH 鈫?padBottom` 鐨勫惊鐜紙瑙侀偅杈圭殑娉ㄩ噴锛夛紝
   *   鑰屽惊鐜噷**涓嶈兘**鍐嶈皟 `usableHVp()`锛堥偅灏辩湡鐨勬垚鐜簡锛夈€?
   * @param u 鍙敤楂樺害锛坴p锛?
   */
  private tierForUsableH(u: number): number {
    const base: number = PlayerExpandState.CHROME_BASELINE_H_VP;
    // 鈿狅笍 椤哄簭 = 鏃犵晫鐨?`if` 椤哄簭锛團ULL 鍏堝垽銆丮EDIUM 娆′箣銆佸惁鍒?COMPACT锛夛紝涓嶈鎸?total 澶у皬閲嶆帓銆?
    if (base >= this.chromeOf(2).total - u) {
      return 2;
    }
    return base >= this.chromeOf(1).total - u ? 1 : 0;
  }

  public updateChromeTier(_widthVp: number = 0): void {
    const u: number = this.usableHVp();
    const base: number = PlayerExpandState.CHROME_BASELINE_H_VP;
    const tier: number = this.tierForUsableH(u);
    if (tier !== this.chromeTier) {
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdChrome tier ${this.chromeTier} 鈫?${tier} usableH=${u.toFixed(1)} ` +
        `thr=${(base - this.chromeOf(2).total).toFixed(0)}/${(base - this.chromeOf(1).total).toFixed(0)} ` +
        `(winH=${this.windowHeightVp.toFixed(1)} padTop=${this.topInsetVp().toFixed(1)} ` +
        `padBottom=${this.padBottomVp().toFixed(1)} avoidBottom=${this.navigationBarBottomVp.toFixed(1)})`);
      this.chromeTier = tier;
    }
  }

  // 鈿狅笍 2026-10-15锛歚chromePaddingVp()`锛堟浘杩斿洖 10 / 14 / 18锛?*宸插垹闄?* 鈥斺€?**闆惰鍙栫偣**
  //   锛堝叏浠?grep 鍙湁瀹冭嚜宸辩殑瀹氫箟锛夛紝鑰屼笖杩欎笁涓€?*涓嶅湪鏃犵晫妗ｄ綅琛ㄩ噷**锛堣〃閲屾病鏈?缁熶竴鍐呰竟璺?
  //   杩欎釜姒傚康锛夆噿 鍙堜竴鏉?鑷繁鍙戞槑 + 娌′汉娑堣垂"鐨勬浠ｇ爜銆傚悓鏃忓凡鍒狅細`chromeGapVp()`锛埪?6.30锛夈€?

  // 鈿狅笍 2026-10-15锛歚chromeGapVp()`锛堟浘杩斿洖 18 / 24 / 30锛?*宸插垹闄?*銆?
  //   涓や釜鍘熷洜锛岀己涓€涓垜閮戒細鐣欑潃瀹冿細
  //   鈶?**瀹冩病鏈変换浣曟秷璐硅€?* 鈥斺€?`PlaybackPage` 鎶婂畠浼犵粰 `ControlAreaComponent` 鐨?`chromeGap`
  //      `@Param`锛岃€岄偅涓弬鏁板湪缁勪欢閲?*鍙湁澹版槑銆佷粠涓嶄娇鐢?*锛坓rep 鍏ㄧ粍浠跺彧鏈夊０鏄庨偅涓€澶勶級
  //      鈬?瀹冩槸**姝荤閬?*锛涜€屼笖瀹?*鏇剧粡璇杩囨垜**锛氭垜鎹浠ヤ负"鎶婃。浣嶄粠瀹藉害鏀规垚楂樺害"
  //      浼氳鎵嬫満涓婄殑鎺у埗鍖洪棿璺濅粠 18 鍙?30锛堝疄闄呮病鏈変换浣曞彲瑙佹晥鏋滐級銆?
  //   鈶?**瀹冪殑鍊间笉鏄棤鐣岀殑** 鈥斺€?妗ｄ綅琛ㄩ噷鏍规湰娌℃湁"缁熶竴鐨勬寜閽棿璺?杩欎釜姒傚康锛?
  //      鍙湁 `gapSwiper`(48/32/20) 涓?`gapScrub`(28/20/14) 涓や釜**璇箟涓嶅悓**鐨勯棿璺?
  //      锛坄wujie.pa:93485` / `190510`锛夆噿 18/24/30 鏄?*鎴戜滑鑷繁鍙戞槑鐨?*銆?
  //   鈬?鐪熸瑕佸仛鐨勬槸 `RzdMusic寰呯‘璁ゆ竻鍗?md` 鐨?**D4**锛氭妸鎺у埗鍖烘寜鏃犵晫鐨勪笁娈电粨鏋?
  //      锛坰wiper / scrubber / transport锛夐噸鎺掞紝鍐嶆寜妗ｅ彇 `gapSwiper` / `gapScrub`銆?

  /**
   * 鏀惰棌 / 鏇村鍥炬爣鐨勫瓧鍙凤紙fp锛夆€斺€?瀵规爣鏃犵晫 `chrome().favSize`锛?*鎸夋。鍙栧€?*銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋紱浠庡瓧鑺傜爜鍙栧埌纭垏鍊硷級锛歚wujie.pa:195193 / 195316` 涓ゅ
   *   锛堟敹钘忎笌鏇村**鐢ㄥ悓涓€涓?* `favSize`锛夛紱妗ｄ綅琛?`wujie.pa:93534/93554/93574`
   *   鈬?**FULL 24 / MEDIUM 22 / COMPACT 20**銆?
   *   鈿狅笍 鎴戜滑鍘熸潵鍐欐 `22`锛堟敞閲婅繕鍐欑潃"鍙栦笌娲鹃煶涓€鑷寸殑涓€妗?锛夆€斺€?灞?鍙栭敊鏉ユ簮"閭ｄ竴鏃忋€?
   * @returns 鍥炬爣瀛楀彿锛坒p锛?
   */
  public chromeFavSize(): number {
    return this.chromeTier === 0 ? 20 : (this.chromeTier === 1 ? 22 : 24);
  }

  /**
   * 鎺у埗鍖?*渚ч敭**锛堝惊鐜?/ 鎾斁鍒楄〃锛夊浘鏍囩殑瀛楀彿锛坒p锛夆€斺€?瀵规爣鏃犵晫 `chrome().sideSize`銆?
   *
   * 鈽呪槄 2026-10-15锛堢収鎼棤鐣岋級锛歚wujie.pa:181333 / 181754` 涓ゅ锛坄.fontSize(chrome().sideSize)`锛夛紱
   *   妗ｄ綅琛?鈬?**FULL 22 / MEDIUM 21 / COMPACT 20**銆?
   *   鈿狅笍 鎴戜滑鍘熸潵鍐欐 `isWidthBreakpointLgOrXl(bp) ? 26 : 24` 鈥斺€?**鎸夊搴?*鍒嗘。锛堝悓 搂56.26 閭ｄ釜
   *      鍙嶄簡鐨勫垽鎹級锛屼笖涓や釜鏁伴兘涓嶆槸鏃犵晫鐨勫€笺€傜幇鍦ㄦ寜鏃犵晫鐨勬。浣嶈〃鍙栥€?
   * @returns 渚ч敭鍥炬爣瀛楀彿锛坒p锛?
   */
  public chromeSideSize(): number {
    return this.chromeTier === 0 ? 20 : (this.chromeTier === 1 ? 21 : 22);
  }

  /**
   * 浼犺緭鏉′笂**涓や釜鏂瑰舰鍥炬爣鎸夐挳**锛堜笂涓€棣?/ 涓嬩竴棣栵級鐨勫搴︼紙vp锛夆€斺€?瀵规爣 `chrome().seekSize`銆?
   *
   * 鈽呪槄鈽?2026-10-16锛?*璁㈡涓€澶勬鍓嶈閿欑殑璇箟**锛夛細
   *   鎴戜箣鍓嶅湪娉ㄩ噴閲屾妸 `seekSize` 鍐欐垚"杩涘害鏉￠偅涓€琛岀殑**鍧楀昂瀵?*"锛屾墍浠ヤ竴鐩磋寰?
   *   "鎴戜滑 16vp 鐨勬粦鍧楄楂?vs 鏃犵晫鐨?32 鈥斺€?涓よ€呬笉鏄悓涓€涓噺锛岃绛夊疄娴?銆?
   *   **鏈疆鎶婁袱澶勬秷璐圭偣璇诲嚭鏉ワ紝璇箟瀹屽叏涓嶆槸閭ｆ牱**锛?
   * ```
   *   wujie.pa:181429   Image().width(chrome().seekSize).aspectRatio(1).objectFit(Contain).opacity(0.86)
   *   wujie.pa:181639   鍚屼笂锛堢浜屽锛?
   * ```
   *   鈥斺€?瀹冩槸**涓や釜鏂瑰舰鍥炬爣鎸夐挳鐨勫搴?*锛坄aspectRatio(1)` 瀹氭垚姝ｆ柟褰級锛?
   *   涓?*杩涘害鏉?Slider 姣棤鍏崇郴**銆?
   *   鈬?"鎴戜滑鐨?`slider_height = 16vp` 鍜屾棤鐣岀殑 32 涓嶆槸涓€涓噺"杩欏彞璇濇槸瀵圭殑锛?
   *     浣嗙粨璁轰笉鏄?闇€瑕佸疄娴?锛岃€屾槸**杩欎袱涓笢瑗挎牴鏈笉鏄悓涓€涓厓绱犮€佷笉蹇呭榻?*銆?
   *
   * 鏈粨鐨勫搴旂墿锛歚ControlAreaComponent` 鐨勪紶杈撴潯閲岄偅涓や釜
   * `Image(...).controlImageBuilder().width(...)` 鈥斺€?
   * 鑰?`controlImageBuilder()`锛坄@Extend(Image)`锛夌殑
   * `{ aspectRatio(1) + opacity(0.86) + objectFit(Contain) }` **涓庢棤鐣岄偅涓ゅ閫愬瓧鐩稿悓**
   * 鈬?瀵瑰簲鍏崇郴鏄‘瀹氱殑锛屽氨鐢ㄦ湰妗ｇ殑 `seekSize`銆?
   *
   * 鈿狅笍 鏀瑰墠鎴戜滑鐢ㄧ殑鏄?`app.float.control_width`(32vp) / `control_width_lg`(36vp)锛?
   *   涓や釜鏁?*鎭板ソ**鏄?FULL / 涓€涓埆鐨勬。鐨勫€硷紝浣?*妗ｄ綅涓€鍙樺畠涓嶅彉**锛堝啓姝讳袱妗ｏ級銆?
   *   鐜板湪鏀逛负**鎸夋。鍙栧€?*锛欶ULL 32 / MEDIUM 30 / COMPACT 28銆?
   *
   * 鈿狅笍 **鎾斁/鏆傚仠涓绘寜閽笉鍦ㄨ繖閲?*锛氬畠鐢ㄧ殑鏄?`playSize`锛?2 / 62 / 52锛夛紝
   *   鑰屾湰浠撻偅涓綅缃槸 `image_play_width = 72vp`锛團ULL 妗ｆ伆濂藉涓婏紱瀹藉睆妗ｇ殑
   *   88 涓庤〃閲岀殑 62/52 涓嶅悓婧愶紝鏆備笉鍔?鈥斺€?瑙?`RzdMusic璁板繂.md` 搂98锛夈€?
   * @returns 鏂瑰舰鍥炬爣鎸夐挳瀹藉害锛坴p锛?
   */
  public chromeSeekSize(): number {
    return this.chromeOf().seekSize;
  }

  // 鈿狅笍 杩欓噷鍘熸潵鏈変竴涓?`TOP_BAR_ROW_H_VP = 56`锛堥《鏍忚楂橈級锛?*2026-10-17 宸插垹闄?*锛?
  //   瀹冩槸鑷紪鍊硷紙浠?`design/Index.BAR_H = 56` 鍊熸潵鐨勶紝鑰岄偅涓?56 鏄?*搴曟爮**楂樺害锛夛紝
  //   鐪熸鐨勮楂樻槸 `chrome().topBarH`锛團ULL 44锛夆噿 宸茬敱 `chromeTopBarH()` 鐩存帴鍙栨。浣嶈〃銆?
  //   鈿狅笍 涓庡畠**鍚屽悕涓嶅悓鐗?*鐨勬槸 `PLAYER_TOP_FALLBACK_VP = 56`锛? `topInsetVp()` 鐨勮浣嶇嚎涓嬮檺锛夛紝
  //      閭ｄ釜**杩樺湪鐢?*銆?*涓嶈**椤烘墜鍒?鈥斺€?涓よ€呭彧鏄暟鍊兼挒浜嗭紝姘歌繙鍒綋鎴愪竴涓噺銆?

  /**
   * 鈽呪槄鈽?2026-10-16锛氬皝闈㈠熀鍑嗙煩褰㈢殑**绔栧悜鏍℃閲?*锛坴p锛岃礋 = 寰€涓婏級銆?
   *
   * ## 瀹冧负浠€涔堝瓨鍦紙杩欐槸"灏侀潰鍋忎綆"鐨?*鍞竴**鍙帶钀界偣锛?
   *
   * 鏈粨鐨勫皝闈㈡槸銆?*閲忔祴 + 鍙樻崲寮?*銆嶏細瑕嗙洊灞傛寜 `scale = 瀹炴祴/鍩哄噯`銆乣translate = 瀹炴祴浣?鈭?鍩哄噯浣峘
   * 浠?*鍩哄噯**琛ュ埌**瀹炴祴**浣嶃€傝€?*瀹炴祴浣嶇敱 `Column` 鐨勬帓甯冨喅瀹?* 鈥斺€?
   * 鐪熷皝闈㈠す鍦?椤堕儴鏃犵暀鐧?+ 涓嬫柟 metA/鎺у埗鍖?涔嬮棿琚?*椤跺埌绐楀彛绔栫洿涓儴**銆?
   * 鏃犵晫閭ｈ竟鏄?*绾嚑浣?*锛坄CoverMorph`锛宍涓績 = padTop + metaY`锛夛紝鎵€浠ュ湪灞忓箷涓婇儴銆?
   *
   * 鈬?瑕佺湡姝ｅ榻愶紝鏈鏀?`Column` 鐨勬帓甯冿紙缁欏皝闈笂涓嬪绉扮暀鐧斤級锛?
   *   浣嗛偅灞炵粨鏋勬敼鍔ㄣ€佷笖**蹇呴』鍦ㄧ湡鏈轰笂閲?*銆傚湪鎷垮埌鐪熸満鏁版嵁涔嬪墠锛?
   *   杩欓噷鐢?*涓€涓父鏁?*鎶婂熀鍑嗘暣浣撲笂绉?鈥斺€?涓変釜閲忥紙`x/y/height`锛夋槸鍘熷鍊硷紝
   *   鍙湁 `y` 骞崇Щ锛?*鍥炲綊椋庨櫓鏈€灏忋€佷笖鍗曡鍙洖閫€**銆?
   *
   * ## 鈿狅笍鈿狅笍 2026-10-16 **鏈潯宸茶璇佷吉涓ゆ锛岀幇鍦ㄥ彇鍊?0锛? 瀹屽叏涓嶈捣浣滅敤锛?*
   *
   * 鎴戞浘缁忕敤鎴浘鐩祴鏍″噯瀹冿細`0 鈫?鈭?03 鈫?鈭?50`锛屼袱娆?*閮借灏侀潰鏇村亸**锛堢敤鎴峰疄娴?
   * "鐜板湪鍋忕Щ瓒婃潵瓒婄嫚浜?锛夆噿 璇存槑**"鎸夋埅鍥剧洰娴嬬殑涓績"鎺ㄦ姌绠楁瘮**杩欎釜鏂规硶鏈韩涓嶅彲闈狅細
   * 灏侀潰鏄?*娣辫壊娴锋姤**锛屼笂涓嬭竟缂樹笌榛戣壊鑳屾櫙铻嶄负涓€浣擄紝鐩祴璇樊 卤30vp 璧锋锛?
   * 鑰屾姌绠楁瘮鍒嗘瘝鍙湁鍑犲崄 vp 鈬?璇樊琚斁澶?4 鍊嶏紝瓒婅皟瓒婅繙銆?
   *
   * 鈬?**褰掗浂锛屽苟鏀硅蛋"鐢ㄧ湡鏈烘棩蹇楁敹鏁?杩欐潯璺?*銆傝鏀舵暃鍙渶瑕佷竴鏉℃棩蹇楅噷鐨勪袱涓暟锛?
   * ```
   *   hdc shell hilog -x | Select-String 'RzdCoverGeom'
   *   鈬?鎵?`y=鈥?centerY=鈥?expectCenter=鈥
   *   璁?delta = centerY 鈭?expectCenter锛堟 = 杩樺亸浣庯紝璐?= 鎶繃澶达級
   *   鍒?鏈父閲忓簲鍙?鈮?鈭抎elta 脳 k锛屽叾涓?**k 鐢变袱娆″疄娴嬫爣瀹?*锛?
   *     璁版湰甯搁噺 = A 鏃惰鍒扮殑 centerY = CA锛屾湰甯搁噺 = B 鏃惰鍒?CB
   *     鍒?k = (CA 鈭?CB) / (B 鈭?A)   鈫?**杩欎釜 k 鎵嶆槸鐪熸姌绠楁瘮**锛屾槸瀹炴祴鍑烘潵鐨勶紝涓嶆槸浼扮殑
   * ```
   *   鐩墠鍙湁涓€娆℃湁鏁堣娴嬶紙`0 鈫?centerY 瀹炴祴寰呰ˉ`锛夛紝鎵€浠?*鍏堝綊闆躲€佺瓑涓€鏉℃棩蹇?*銆?
   *
   * 鈿狅笍 闈欐鎬佸彧褰卞搷灏侀潰 `y`锛沗x`銆乣size`銆乣radius` 涓€寰嬩笉鍔ㄣ€?
   */
  private static readonly COVER_BASE_Y_OFFSET_VP: number = 0;

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鐩爣 鈶?鐨?S1 姝ワ細涓や釜銆屽昂瀵告。浣嶇函鍑芥暟銆嶏紙鍏堣惤鍏紡锛屾殏闆舵秷璐癸級鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
  //
  // 鏂藉伐鍥撅細`_recover/logic-src/鐩爣鈶?瀹藉睆闈㈡澘缁熶竴-鏂藉伐鍥句笌楠屾敹.md` 搂4 鐨?**S1**銆?
  //
  // 鈿狅笍 杩欎竴鏉?*渚嬪鍦板厑璁?鍏堟湁璁块棶鍣ㄣ€佸悗鎺ユ秷璐硅€?**锛屽師鍥犳槸瀹冪殑鍊?*宸茬敱瀛楄妭鐮佺‘璇?*銆?
  //    涓嶆槸鎴戜滑鍙戞槑鐨勶紙搂56.38锛夛紱鑰屽凡鎺ョ嚎鐨勯偅浜?娌′汉鐢ㄧ殑璁块棶鍣?锛堝宸插垹鐨?`chromeGapVp`锛?
  //    鏄垜浠嚜宸辨媿鐨勫€?鈬?閭ｆ墠鏄绠￠亾銆備袱鑰呯殑鍖哄埆灏卞湪"鍊兼湁娌℃湁鍑哄"銆?
  //
  // 鈿狅笍 **鐜板湪娌℃湁浠讳綍娑堣垂鑰?*锛堝灞?闈㈡澘褰㈡€佸湪鏈満涓嶅彲鏋勯€狅級鈬?鍔犺繘鏉?*瀵规墜鏈洪浂褰卞搷**锛?
  //    闈欐€佸嚱鏁颁笉鍙備笌 build()锛屼笉浼氳娓叉煋鐧昏锛屼篃涓嶄細鏀瑰彉浠讳綍甯冨眬銆?

  /**
   * 鏃犵晫 `sizeScaleOf(winWVp)`锛? `sizeK()`锛夆€斺€?鎸?*瀹藉害鏂偣**鐨勯樁姊缉鏀俱€?
   *
   * 鍑哄锛歚wujie.pa:84524-84548`锛堣浆鍐欒 `RzdMusic璁板繂.md` 搂56.38 / 娓呭崟 E5锛夈€?
   * ```
   *   瀹藉害鏂偣 bp >= 4 鈫?1.32 ;  >= 3 鈫?1.24 ;  >= 2 鈫?1.12 ;  else 鈫?1   锛堟墜鏈猴級
   * ```
   * 鈽?**鎵嬫満锛坆p < 2锛夋亽涓?`1`** 鈥斺€?杩欐鏄垜浠叏浠撶敤鍥哄畾 fp/vp 鍦ㄦ墜鏈轰笂**閫愬瓧姝ｇ‘**鐨勫師鍥狅紱
   *   鑰屽钩鏉?PC 浼氭斁澶?12% / 24% / 32%锛屾垜浠殑鍥哄畾鍊煎湪**閭ｉ噷鏁翠綋鍋忓皬** 鈬?褰掔洰鏍?鈶?鐨?S4鈥揝6銆?
   *
   * 鏂偣鍙栧€煎彛寰勶細涓?`updateChromeTier` 鍚屼竴涓?`bp`锛坄WidthBreakpoint`锛?
   * SM=0/1銆丮D=2銆丩G=3銆乆L=4 鈥斺€?瑙佹湰浠?`isWidthBreakpointLgOrXl` 鐨勭敤娉曪級銆?
   * @param winWVp 绐楀彛瀹藉害锛坴p锛?
   * @param widthBp 瀹藉害鏂偣锛坄uiObserver.WindowSizeLayoutBreakpointInfo.widthBreakpoint`锛?
   * @returns 缂╂斁绯绘暟锛堟墜鏈?= 1锛?
   */
  public static sizeScaleOf(winWVp: number, widthBp: number): number {
    // 鏃犵晫鐨勫垽鎹槸**瀹藉害鏂偣**锛屼笉鏄搴︽暟鍊?鈥斺€?鎵€浠ヤ袱鍙傞兘瑕侊紙`winWVp` 鍙敤浜庡厹搴曟棩蹇?鏈潵鎵╁睍锛夈€?
    if (widthBp >= 4) {
      return 1.32;
    }
    if (widthBp >= 3) {
      return 1.24;
    }
    if (widthBp >= 2) {
      return 1.12;
    }
    return 1;
  }

  /**
   * 鏃犵晫 `topPageSideOf(winWVp)` 鈥斺€?椤甸潰宸﹀彸鐣欑櫧锛坴p锛夈€?
   *
   * 鍑哄锛歚wujie.pa:84660-84678`锛埪?6.38 / 娓呭崟 E5锛夈€?
   * ```
   *   winWVp < 600 鈫?16 ;  < 840 鈫?24 ;  else 鈫?32
   * ```
   * 鈽?鎵嬫満锛堚増360~430vp锛夋亽涓?**16** 鈥斺€?涓?`PlaybackPage.LYRIC_META_SIDE_VP = 16`
   *   浠ュ強 `PlayerExpandState.LYRIC_COVER_LEFT_VP = 16` **鍚屽€?* 鈬?鎴戜滑宸茬粡鐢ㄥ浜嗘墜鏈洪偅涓€妗?鉁?
   *   锛堟竻鍗?E5 宸茬‘璁?鎴戜滑鐨?16vp 鏄師鍊?锛夈€?
   * @param winWVp 绐楀彛瀹藉害锛坴p锛?
   * @returns 宸﹀彸鐣欑櫧锛坴p锛?
   */
  public static topPageSideOf(winWVp: number): number {
    if (winWVp < 600) {
      return 16;
    }
    if (winWVp < 840) {
      return 24;
    }
    return 32;
  }

  /**
   * S1 鐨?*鑷瘉**锛氭妸涓や釜绾嚱鏁板湪"鏈満褰撳墠绐楀彛"涓嬬殑鍊兼墦鍑烘潵锛岀敤鏉ユ牳瀵瑰畠浠湪**鎵嬫満妗?*涓?
   * 鏄惁鎭板ソ绛変簬鎴戜滑宸茬粡鍦ㄧ敤鐨勫浐瀹氬€硷紙`sizeK = 1` / `side = 16`锛夈€?
   *
   * 鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdSizeTier'`
   * 鏈熸湜锛堟墜鏈猴級锛歚side=16 sizeK=1`锛屼笖 `fixedOk=true`锛堜袱涓浐瀹氬€间笌妗ｄ綅鍊间竴鑷达級銆?
   * @param widthBp 瀹藉害鏂偣
   */
  public logSizeTier(widthBp: number): void {
    // 閲忎笉鍒扮獥鍙ｅ鏃舵寜 360 鍏滃簳锛堝彧涓烘棩蹇楋紝涓嶅啓鍥炰换浣曠姸鎬侊級銆?
    const w: number = this.windowWidthVp > 0 ? this.windowWidthVp : 360;
    const side: number = PlayerExpandState.topPageSideOf(w);
    const sizeK: number = PlayerExpandState.sizeScaleOf(w, widthBp);
    // "鍥哄畾鍊兼槸鍚︿笌妗ｄ綅鍊间竴鑷?锛氭墜鏈烘。涓や釜閮借鐩哥瓑 鈬?鍙嶈繃鏉ヨ鏄?瀹藉睆瑕?脳1.12~1.32 / side 24~32"杩欐潯宸湪鍝?
    const fixedOk: boolean = sizeK === 1 && side === 16;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdSizeTier winW=${w.toFixed(0)} widthBp=${widthBp} side=${side} sizeK=${sizeK.toFixed(2)} ` +
      `fixedOk=${fixedOk} tier=${this.chromeTier} usableH=${this.usableHVp().toFixed(1)}`);
  }

  // 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鐩爣 鈶?鐨?S2 姝ワ細瀹藉睆 / 闈㈡澘鐨?*鍐呭鍗犳瘮妗ｄ綅**锛堜笉鍚换浣曠寽娴嬬殑闂磋窛锛夆晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
  //
  // 鏂藉伐鍥撅細`_recover/logic-src/鐩爣鈶?瀹藉睆闈㈡澘缁熶竴-鏂藉伐鍥句笌楠屾敹.md` 搂4 鐨?**S2**銆?
  //
  // 鈿狅笍 **S2 涓?S3 鐨勫尯鍒?*锛堣繖閲屽埢鎰忓彧鍋?S2 鐨勯偅涓€鍗婏級锛?
  //   路 鍗犳瘮锛坄GridCol` 鐨?`span`锛夋槸**鎴戜滑鑷繁鐨勫竷灞€鍙傛暟**锛岃€屼笖**灏卞湪浠ｇ爜閲?*锛堣涓嬶級鈬?鑳界‘璇侊紱
  //   路 `Row({space: 鈥)` / `GridRow({gutter: 鈥)` 閭ｇ**闂磋窛鏁板€?*锛?6 / 48锛?*娌℃湁鍑哄**
  //     鈬?涓€寰?*涓嶅幓鐚?*锛堟柦宸ュ浘 搂6 绗?2 鏉★級銆傜湡姝ｇ殑闂磋窛璧?`S3`锛氭妸瀹藉睆鍒嗘敮鎺ユ垚**鍚屼竴涓?
  //     `Row{ layoutWeight }`** 涔嬪悗锛岄棿璺濈敱**鍚屼竴涓父閲?*缁欏嚭锛岄偅鏃跺畠鎵嶅彧鏈変竴涓潵婧愩€?

  /** 瀹藉睆 `GridRow` 鐨?*鍒楁暟鎸夋。涓嶅悓**锛歮d/lg = 4 鍒楋紝xl = 8 鍒椼€?*/
  private static readonly WIDE_COLS_MD_LG: number = 4;
  private static readonly WIDE_COLS_XL: number = 8;

  /**
   * @returns 瀹藉睆锛堥潪闈㈡澘锛夊乏鏍忓崰姣?鈥斺€?**閫愬瓧鍙栬嚜 `PlaybackPage` 鐨?`GridCol` span 鏁扮粍**銆?
   *
   * 鍑哄锛堟湰杞疄璇伙紝涓嶆槸鍥炲繂锛夛細`PlaybackPage.ets` L2128-2151 閭ｄ袱澶勶細
   * ```
   *   GridRow  columns: { md: COLUMN_MD(8), lg: COLUMN_LG(12), xl: COLUMN_LG(12) }
   *   宸︼紙灏侀潰 + 姝屽悕锛? span { md: 4, lg: 5, xl: 4 }
   *   鍙筹紙姝岃瘝锛?     : span { md: 4, lg: COLUMN_LYRIC_LG(7), xl: 8 }
   * ```
   * 鈿狅笍 **涓夋。鐨勫垪鏁板苟涓嶄竴鏍?*锛坄BreakpointConstants`锛歚COLUMN_MD = 8`銆乣COLUMN_LG = 12`锛夛細
   * | 妗?| 鎬诲垪 | 宸?span | 鍙?span | 宸﹀崰姣?|
   * | --- | --- | --- | --- | --- |
   * | md | 8 | 4 | 4 | **1/2** |
   * | lg | 12 | 5 | 7 | **5/12** |
   * | xl | 12 | 4 | 8 | **1/3** |
   * 鈬?杩欎篃鏄?瀹?*鑳借绛変环鏀舵暃鎴愪竴涓袱鍒?`Row`**"鐨勪緷鎹細姣忔。涓ゆ爮鐨?span 閮芥伆濂藉～婊℃€诲垪鏁?
   *   锛?=4+4 / 12=5+7 / 12=4+8锛夛紝**娌℃湁绗笁涓崰浣嶅垪**銆?
   * @param widthBp 瀹藉害鏂偣锛? = LG銆? = XL锛岃 `WidthBreakpoint`锛?
   * @returns 宸︽爮鍗犳瘮锛?鈥?锛?
   */
  public static wideLeftRatio(widthBp: number): number {
    if (widthBp >= 4) {
      // XL锛? / 12锛堟€诲垪鏁?COLUMN_LG = 12锛?
      return 4 / 12;
    }
    if (widthBp >= 3) {
      // LG锛? / 12
      return 5 / 12;
    }
    // MD锛堜篃鍚洿绐勭殑鍏滃簳锛夛細4 / 8
    return 4 / 8;
  }

  /**
   * @returns 瀹藉睆閭ｄ竴妗ｇ殑 `GridRow` 鎬诲垪鏁帮紙鐢ㄤ簬鎹㈢畻涓庢棩蹇楋紝涓嶅弬涓庢覆鏌擄級銆?
   * @param widthBp 瀹藉害鏂偣
   */
  public static wideColumnCount(widthBp: number): number {
    return widthBp >= 4 ? PlayerExpandState.WIDE_COLS_XL : PlayerExpandState.WIDE_COLS_MD_LG;
  }

  /**
   * 鎶?绐楀彛鍧愭爣鐨勭偣"鎹㈡垚"**瀹夸富鐩掑唴鍧愭爣**"鈥斺€?鍗冲噺鍘诲涓荤洅鑷繁鐨勫乏涓婅銆?
   *
   * 鈽?2026-10-15锛堢洰鏍?鈶?鐨?**S3 鍓嶇疆浠?*锛夛細绛夊灞?闈㈡澘瑕佸鐢ㄥ悓涓€浠芥诞灞傦紙`.position()` 鏄?
   *   **鐩稿鐖剁粍浠跺唴瀹圭洅**鐨勭粷瀵瑰畾浣嶏紝涓嶆槸绐楀彛鍧愭爣锛夋椂锛屾诞灞備細琚寕鍒?*涓嶅悓鐨勫涓?*涓嬶細
   * ```
   *   鎵嬫満锛氬涓?= 婊″睆鐨勫唴瀹规爤锛堝乏涓婅 = 绐楀彛鍘熺偣锛夆噿 鍋忕Щ (0, 0)锛屾湰鍑芥暟鏄亽绛夊彉鎹?
   *   闈㈡澘锛氬涓?= 宸︽爮閭ｄ竴鍒?       鈬?鍋忕Щ = (宸︽爮鐨勭獥鍙?x, 鍐呭鐩掗《)
   *   瀹藉睆锛氬涓?= 宸︿晶 GridCol 鍐呭鐩?鈬?鍋忕Щ = 璇ュ垪鍐呭鐩掔殑绐楀彛 x
   * ```
   * 鈬?`position = 绐楀彛鍧愭爣 鈭?瀹夸富鍋忕Щ`銆?
   *
   * 鈿狅笍 **鏈嚱鏁版晠鎰忓彧鍋氳繖涓€浠朵簨**锛堜竴涓噺娉曪級锛屼笉鍙備笌"鍋忕Щ閲忔湰韬€庝箞鏉?鈥斺€?
   *    鍋忕Щ閲忕殑鍞竴鏉ユ簮蹇呴』鏄?*瀹炴祴**锛坄getPositionToWindowWithTransform()` 鍑忓幓
   *    璇ヨ妭鐐硅嚜韬殑甯冨眬鍘熺偣锛夛紝涓嶈鎷?`padding: 56` / `space: 56` 杩欑被瀛楅潰閲忓幓鍑?
   *    锛堣 `鐩爣鈶?瀹藉睆闈㈡澘缁熶竴-鏂藉伐鍥句笌楠屾敹.md` 搂6 绗?2 鏉★細閭ｄ袱涓暟鍊?*娌℃湁鍑哄**锛夈€?
   * 鈿狅笍 **鍋忕Щ涓?(0,0) 鏃跺畠涓庢敼鍓嶉€愬儚绱犵浉鍚?*锛坄x 鈭?0 === x`锛夆噿 鎵嬫満璺緞鎺ヤ笂瀹冧篃鏄浂椋庨櫓鐨勩€?  * @param windowX 绐楀彛鍧愭爣 x锛坴p锛?
   * @param windowY 绐楀彛鍧愭爣 y锛坴p锛?
   * @param hostX 瀹夸富鐩掑乏涓婅鍦ㄧ獥鍙ｉ噷鐨?x锛坴p锛涙墜鏈?= 0锛?
   * @param hostY 瀹夸富鐩掑乏涓婅鍦ㄧ獥鍙ｉ噷鐨?y锛坴p锛涙墜鏈?= 0锛?
   * @returns `{ x, y }` 瀹夸富鐩掑唴鍧愭爣锛坴p锛?
   */
  public static toHostPoint(windowX: number, windowY: number, hostX: number, hostY: number): HostPoint {
    return {
      x: windowX - (hostX > 0 ? hostX : 0),
      y: windowY - (hostY > 0 ? hostY : 0)
    };
  }

  /**
   * 閲忎竴涓妭鐐瑰湪**绐楀彛鍧愭爣**閲岀殑宸︿笂瑙掞紙vp锛夆€斺€?鐢ㄤ綔 {@link toHostPoint} 鐨?`hostX/hostY`銆?
   *
   * 鈽?2026-10-15锛堢洰鏍?鈶?鐨?S3 鍓嶇疆浠?路 绗簩浠讹級锛氳繖鏄?瀹夸富鍋忕Щ**鍞竴鍚堟硶鏉ユ簮**"鐨勫彇鏁板彛銆?
   *   鍋忕Щ閲?*绂佹鐚?*锛坄padding: 56` / `Row({space:56})` / `GridRow({gutter:48})` 閮芥病鏈夊嚭澶勶級锛?
   *   鍙厑璁镐粠杩欓噷閲忥紙鍐呴儴璧版湰绫诲凡鏈夌殑 {@link measureNode}锛屼笌 `reportMini` / `bigNode` 鍚屼竴鏉￠摼锛夈€?
   *
   * 鈿狅笍 **鍙銆佷笉鍐欎换浣曠姸鎬?*锛氬畠涓嶇紦瀛樸€佷笉涓婃姤锛岄噺涓嶅埌灏辫繑鍥?`{x:0, y:0}`锛? 鎭掔瓑鍋忕Щ锛夈€?
   *   鈬?鏈帴绾垮墠璋冪敤瀹冿紝琛屼负涓?鍐欐 (0,0)"**閫愬儚绱犵浉鍚?*銆?
   * 鈿狅笍 鐢?`getPositionToWindowWithTransform()`锛?*娓叉煋鍚?*銆佸惈绁栧厛 transform锛夆€斺€?
   *   涓?`measureNode` 鐨勯粯璁ゅ彛寰勪竴鑷达紱杩欐槸閲?瀹夸富鍐呭鐩掑湪绐楀彛閲岀殑浣嶇疆"鐨勬纭彛寰勩€?
   *   锛堣嫢瀹夸富鐨勭鍏堥噷甯︿簡 scale/translate锛岄噺鍒扮殑灏辨槸**娓叉煋浣?*锛涜繖姝ｆ槸 `.position()` 闇€瑕佺殑鍙傝€冪郴銆傦級
   * @param ui UIContext
   * @param hostId 瀹夸富鐨勭粍浠?id锛堝灞?闈㈡澘鎺ョ嚎鏃剁敱璋冪敤鏂圭粰鍑猴級
   * @returns 瀹夸富宸︿笂瑙掞紙vp锛岀獥鍙ｅ潗鏍囷級锛涢噺涓嶅埌 鈬?`{x:0, y:0}`
   */
  public measureHostOrigin(ui: UIContext, hostId: string): HostPoint {
    const r: NodeRect | undefined = this.measureNode(ui, hostId);
    if (r === undefined) {
      Logger.warn(PlayerExpandState.LOG_TAG,
        `RzdHostOrigin id='${hostId}' not-measured 鈬?(0,0) idempotent`);
      return { x: 0, y: 0 };
    }
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdHostOrigin id='${hostId}' origin=(${r.x.toFixed(1)},${r.y.toFixed(1)}) ` +
      `size=${r.w.toFixed(1)}x${r.h.toFixed(1)} win=${this.windowWidthVp.toFixed(0)}x${this.windowHeightVp.toFixed(0)}`);
    return { x: r.x, y: r.y };
  }

  /**
   * @returns 闈㈡澘锛堟í灞忎袱鏍忥級宸︽爮鍗犳瘮 鈥斺€?**閫愬瓧鍙栬嚜 `PlaybackPage.panelControlContent()`**銆?
   *
   * 鍑哄锛歚panelControlContent()` 閲屼袱涓?`Column().layoutWeight(1)` 鈬?**鍚勫崰涓€鍗?*銆?
   * 鈿狅笍 杩欓噷**娌℃湁**"鎴戜滑鑷繁鐨勬瘮渚?鍙互鎼細`layoutWeight(1)` 鐨勮涔夊氨鏄?骞冲垎鍓╀綑绌洪棿"
   * 鈬?鍞竴姝ｇ‘鐨勫€煎氨鏄?`1/2`锛堝啓鎴愮畻寮忚€屼笉鏄瓧闈㈤噺 0.5锛屾槸涓轰簡璁?瀹冩潵鑷?layoutWeight"鍙锛夈€?
   * @returns 宸︽爮鍗犳瘮锛?鈥?锛?
   */
  public static panelLeftRatio(): number {
    return 1 / (1 + 1);
  }

  /**
   * 鎶?宸﹀彸鍗犳瘮"缈昏瘧鎴?*涓ゆ爮鐨勭洰鏍囧搴?*锛坴p锛夈€?
   *
   * 鈿狅笍 **杩欓噷涓嶇畻闂磋窛**锛坄gutter` / `space` 涓€寰嬩笉鍙備笌锛夛細涓や釜瀹藉害鍔犺捣鏉?= `avail`锛?
   *    涔熷氨鏄**涓ゆ爮绱ц创**銆傜湡姝ｇ殑闂磋窛鐢?S3 涔嬪悗鐨?*鍚屼竴澶?*甯搁噺缁欏嚭 鈥斺€?
   *    閭ｆ椂涓ゆ爮瀹藉害浼氬悇鍑忓幓 `space/2`锛岃€屼笉鏄杩欎釜鍑芥暟鍘荤寽涓€涓暟銆?
   * 鈿狅笍 鎵嬫満妗?*涓嶈鏈嚱鏁?*锛堟柦宸ュ浘閾佸緥锛歋1鈥揝3 瀵规墜鏈洪€愬儚绱犳棤褰卞搷锛夈€?
   * @param avail 鍙敤瀹藉害锛坴p锛?
   * @param leftRatio 宸︽爮鍗犳瘮锛坄wideLeftRatio()` / `panelLeftRatio()`锛?
   * @returns `{ left, right }` 涓ゆ爮鐩爣瀹藉害锛坴p锛?
   */
  public static columnWidths(avail: number, leftRatio: number): WideColumns {
    const a: number = avail > 0 ? avail : 0;
    const r: number = leftRatio < 0 ? 0 : (leftRatio > 1 ? 1 : leftRatio);
    const left: number = a * r;
    return { left: left, right: a - left };
  }

  /**
   * S2 鐨?*鑷瘉**锛氭妸瀹藉睆/闈㈡澘涓ゆ。鍦ㄦ湰鏈虹獥鍙ｄ笅鐨勫崰姣斾笌涓ゆ爮瀹藉害鎵撳嚭鏉ャ€?
   *
   * 鎺掓煡鍏抽敭瀛楋細`hdc shell hilog -x | Select-String 'RzdWideCols'`
   * 鏈熸湜锛堟墜鏈猴紝妯睆闄ゅ锛夛細`isWide=false isPanel=false`锛堜袱鏍忛兘涓嶅弬涓庡竷灞€锛屽彧鏄妸鏁扮畻鍑烘潵澶囨煡锛夈€?
   * @param widthBp 瀹藉害鏂偣
   * @param isPanel 褰撳墠鏄惁璧伴潰鏉垮竷灞€锛坄PlaybackPage.usePanelLayout()`锛?
   * @param ui UIContext锛堢敤浜?`measureHostOrigin()` 閭ｆ潯鎺㈤拡锛涙嬁涓嶅埌鏃舵帰閽堜細璧?閲忎笉鍒?鍒嗘敮锛?
   *   浠嶇劧鎵撳嚭 `hostZero=true` 鈥斺€?杩欐潯鎶ゆ爮鏈韩涔熻鑳借楠岋級
   */
  public logWideColumns(widthBp: number, isPanel: boolean, ui: UIContext): void {
    const w: number = this.windowWidthVp > 0 ? this.windowWidthVp : 360;
    const side: number = PlayerExpandState.topPageSideOf(w);
    const avail: number = w - side * 2;
    const wl: number = PlayerExpandState.wideLeftRatio(widthBp);
    const wc: WideColumns = PlayerExpandState.columnWidths(avail, wl);
    const pc: WideColumns = PlayerExpandState.columnWidths(avail, PlayerExpandState.panelLeftRatio());
    const isWide: boolean = widthBp >= 2;
    // 鈽?S3 鍓嶇疆浠剁殑**鑷瘉**锛氬涓诲亸绉讳负 (0,0)锛? 鎵嬫満閭ｄ釜婊″睆鍐呭鏍堬級鏃跺繀椤绘槸**鎭掔瓑鍙樻崲**銆?
    //   鏈熸湜鎭掍负 `hostId=true` 鈥斺€?瀹冧繚璇?鎺ヤ笂 toHostPoint() 涔嬪悗鎵嬫満閫愬儚绱犱笉鍙?銆?
    const probe: HostPoint = PlayerExpandState.toHostPoint(123.4, 567.8, 0, 0);
    const hostId: boolean = probe.x === 123.4 && probe.y === 567.8;
    // 鈽?S3 鍓嶇疆浠剁浜屼欢锛坄measureHostOrigin()`锛夌殑**鑷瘉**锛?
    //   鎺㈤拡瀹夸富 id 鏁呮剰缁欎竴涓?*涓嶅瓨鍦ㄧ殑** id 鈬?鏈熸湜璺戣繘"閲忎笉鍒?鍒嗘敮銆佹墦鍑?`not-measured 鈬?(0,0)`
    //   涓?`hostZero=true`銆傚畠璇佹槑鐨勬槸"**閲忎笉鍒颁篃缁濅笉浼氳鍋忕Щ鍙樻垚 NaN**"杩欐潯鎶ゆ爮銆?
    //   锛堢湡姝ｇ殑瀹夸富 id 绛?S4/S5 鎺ョ嚎鏃剁敱璋冪敤鏂圭粰锛涢偅鏃惰繖閲岀殑鎺㈤拡鎹㈡垚鐪?id 鍗冲彲銆傦級
    const hostProbe: HostPoint = this.measureHostOrigin(ui, 'rzd_host_origin_probe');
    const hostZero: boolean = hostProbe.x === 0 && hostProbe.y === 0;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdWideCols winW=${w.toFixed(0)} widthBp=${widthBp} cols=${PlayerExpandState.wideColumnCount(widthBp)} ` +
      `side=${side} avail=${avail.toFixed(0)} isWide=${isWide} isPanel=${isPanel} hostId=${hostId} ` +
      `hostProbe=(${hostProbe.x.toFixed(1)},${hostProbe.y.toFixed(1)}) hostZero=${hostZero} ` +
      `wide(left=${wc.left.toFixed(0)},right=${wc.right.toFixed(0)},ratio=${wl.toFixed(3)}) ` +
      `panel(left=${pc.left.toFixed(0)},right=${pc.right.toFixed(0)},ratio=${PlayerExpandState.panelLeftRatio().toFixed(3)})`);
  }

  /**
   * 椤舵爮閭ｄ竴琛岀殑楂樺害锛坴p锛夆€斺€?**鐓ф惉鏃犵晫 `chrome().topBarH`**銆?
   *
   * ## 涓婃父鐨勫敮涓€娑堣垂鐐癸紙鏈疆鍥炲瓧鑺傜爜纭瘉锛?
   *
   * 鏃犵晫閭ｄ釜椤舵爮 Row 鐨勪慨楗扮閾惧湪 `PlayerPage.@e*#`锛坄wujie.pa:196015-196107`锛夐噷锛岄€愭潯瑙ｅ嚭鏉ユ槸锛?
   * ```ts
   *   Row().width('100%').bindSheet(customSleepOpen, {...})
   *        .height(this.chrome().topBarH)                     // 鈽?196068-196079 鈥斺€?鍏?`.pa` 鍞竴娑堣垂鐐?
   *        .alignItems(VerticalAlign.Center)                  // 196080-196088
   *        .padding({ left: this.pageSide(), right: this.pageSide() })   // 196089-196106
   * ```
   * 妗ｄ綅琛紙`wujie.pa:93534/93554/93574`锛夆噿 **FULL 44 / MEDIUM 40 / COMPACT 36**
   * 锛堟墜鏈?`chromeTier` = 2 = FULL 鈬?**44**锛夈€?
   *
   * ## 鏈粨鍘熸潵涓轰粈涔堝啓鎴?56锛屼互鍙婇偅涓悊鐢?*宸茶鎺ㄧ炕**
   *
   * `TopAreaComponent` 鍘熸潵鍐欐 `.height(56)`锛屾敞閲婄粰鐨?涓嶈兘鏀?鐞嗙敱鏄細
   * > 56 = **鍐呭璁╀綅绾挎湰韬?*锛坄PLAYER_TOP_FALLBACK_VP = 56`锛夛紝鐩存帴鎹㈡垚 44 浼?*鍚屾椂**
   * > 鍔ㄥ埌璁╀綅绾夸笌椤舵爮楂樺害锛岃€岃浣嶇嚎琚暣濂楀舰鍙樺嚑浣曚緷璧栥€?
   *
   * 鈽呪槄 2026-10-17锛堟敹灏惧鏍革級锛?*杩欎釜鑰﹀悎鍦ㄦ湰浠撲唬鐮侀噷骞朵笉瀛樺湪** 鈥斺€?
   *   路 璁╀綅绾块偅涓€璺蛋鐨勬槸 **`PLAYER_TOP_FALLBACK_VP`**锛坄topInsetVp()` 鈫?`max(鐘舵€佹爮, 56)`锛夛紝
   *     瀹?*浠庝笉璇?* `TOP_BAR_ROW_H_VP`锛?
   *   路 `TOP_BAR_ROW_H_VP` 鐨勫敮涓€娑堣垂鑰呭氨鏄湰鍑芥暟锛岃€屾湰鍑芥暟鐨勫敮涓€娑堣垂鑰呮槸
   *     `TopAreaComponent.height(...)`锛堝叏浠?grep 杩囷級銆?
   *   鈬?涓よ€呭彧鏄?*鏁板€兼伆濂界浉鍚?*鐨?*涓や釜鐙珛閲?*锛涙棫鐞嗙敱鎶?鍚屽€?璇綋鎴愪簡"鍚屼竴閲?銆?
   *   鈬?鎵€浠ヨ繖閲屽彲浠?*鐩存帴鐓ф惉妗ｄ綅琛?*锛堜笌 `sideSize` / `favSize` / `titleSize` / `artistSize`
   *     閭ｅ嚑涓瓧娈电殑鍋氭硶瀹屽叏涓€鑷达級锛屽苟涓旈『甯︿慨鎺変竴澶?*鑷紪鍊?*锛?
   *     `56` 鍏跺疄鏄粠 `design/Index.BAR_H = 56` 鍊熸潵鐨勶紝鑰屽湪鏃犵晫閭ｈ竟
   *     **`BAR_H` 鏄?搴曟爮锛圚DS 鏍囩鏍忥級楂樺害"**锛坄璁捐甯搁噺鍏ㄩ噺瑙ｇ畻.md`锛氥€孊AR_H = 56 鈫?搴曟爮楂樺害銆嶏紝
   *     娑堣垂鑰呮槸 `SubPageBar` 鐨?`CAPSULE_BOTTOM` / `MINI_CAPSULE_H`锛夛紝**涓嶆槸鎾斁椤甸《鏍忕殑琛岄珮**銆?
   *
   * ## 鈿狅笍 浠?*鏈?*鎺ョ嚎鐨勯偅涓€鍗婏紙鐣欑粰涓嬩竴杞紝鍒綋鎴愬凡缁忓仛瀹岋級
   *
   * 鏃犵晫杩欎釜椤舵爮鎵€鍦ㄧ殑閭ｄ竴灞傝繕鏈変竴涓?*閿氱偣**锛?
   * `Column().height(winHVp()).padding({ top: padTop(), bottom: padBottom() })`锛坄wujie.pa:191783-191800`锛夛紝
   * 鍗抽《鏍忕殑**椤惰竟 = `padTop()`**銆傛湰浠撻偅涓€灞傜敤鐨勬槸
   * `.padding({ top: windowInfo.statusBarTopVp, bottom: windowInfo.navigationBarBottomVp })`
   * 锛坄PlaybackPage.ets:4690-4693`锛夆€斺€?鐢ㄧ殑鏄?*鍘熷绐楀彛鍐呰竟璺?*锛岃€屽嚑浣曚晶鐢ㄧ殑鏄?
   * `topInsetVp()`锛? `max(鐘舵€佹爮, 56) 鈭?鐩掗《`锛変笌 `padBottomVp()`锛? `max(閬胯, bottomGap)`锛夈€?
   * 鈬?甯冨眬渚т笌鍑犱綍渚?*涓嶆槸鍚屼竴涓噺**锛堝樊鍒板崄鍑?vp锛夛紝杩欐槸**涓嬩竴杞殑鐙珛涓€椤?*锛?
   *   瑕佹敼灏辨妸閭ｄ袱涓?padding 鎹㈡垚 `topInsetVp()` / `padBottomVp()`锛堜笌涓婃父鍚屾瀯锛夛紝
   *   浣嗗畠鏄?*鍙浣嶇Щ**銆佷笖浼氬姩鍒?椤舵爮閭ｆ潯鍏抽棴鎵嬪娍甯?鐨勪綅缃?鈬?闇€瑕佷竴娆¤鎰熺‘璁わ紝鍒洸鏀广€?
   * @returns 椤舵爮琛岄珮锛坴p锛?
   */
  public chromeTopBarH(): number {
    // 涓夋。涓€寰嬪彇妗ｄ綅琛?鈥斺€?涓庝笂娓?`chrome().topBarH` 閫愬瓧涓€鑷达紙FULL 44 / MEDIUM 40 / COMPACT 36锛夈€?
    return this.chromeOf().topBarH;
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鏃犵晫 `PlayerChrome` 妗ｄ綅琛細**灏氭湭鎺ョ嚎**鐨?5 涓瓧娈碉紙D4 鍓╅」锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  //
  // 鍑哄锛歚wujie.pa:93534/93554/93574`锛堜笁妗ｅ瓧闈㈤噺瀵硅薄锛夛紝杞啓瑙?
  //       `RzdMusic璁板繂.md` 搂56.26 / 搂56.29 涓?`RzdMusic寰呯‘璁ゆ竻鍗?md` 鐨?D4銆?
  // 宸叉帴绾匡紙6 椤癸級锛歚topBarH`锛堚槄 2026-10-17 璧?*鐩存帴鍙栨。浣嶈〃** = 44/40/36锛涙棫鐞嗙敱
  //               "56 鍚屾椂鏄浣嶇嚎"宸茶鎺ㄧ炕锛岃 `chromeTopBarH()` 鐨勮瘉鎹摼锛?/ `sideSize` / `favSize` /
  //               `titleSize`锛? 灏侀潰椤?20锛岄厤 `metaProgress` 0.75 鈫?姝岃瘝椤?15锛?/
  //               `artistSize`锛? 灏侀潰椤?14 鈫?姝岃瘝椤?12锛?/ `metaGap`锛? 10vp 閭ｄ竴妗ｅ彛寰勶級銆?
  // 鈿狅笍 **涓嬮潰杩?5 椤逛笉鏄?蹇樹簡"锛屾槸"鎺ヤ笉浜?** 鈥斺€?姣忎竴椤归兘瑕佸厛鍔?*缁撴瀯**锛屼笉鏄敼涓€涓暟锛?
  //   路 `gapSwiper` 48/32/20锛氳涔夋槸"灏侀潰/Swiper 閭ｄ竴鍧椾笌涓嬫柟鎺у埗鍧椾箣闂?鐨勯棿璺濓紝
  //     鑰屾垜浠殑鎵嬫満鏀病鏈夎繖涓彲閰嶇殑闂磋窛椤癸紙Swiper 鍚?`layoutWeight(1)`锛?
  //     闂磋窛鏄?鍓╀綑绌洪棿鐨勮嚜鐒剁粨鏋?锛夆噿 瑕佸厛鎸夋棤鐣岀殑涓夋缁撴瀯锛坰wiper / scrubber / transport锛?
  //     閲嶆帓鎺у埗鍖恒€?
  //   路 `gapScrub` 28/20/14锛氬悓涓婏紝鏄?杩涘害鏉￠偅涓€琛屼笌浼犺緭鏉￠偅涓€琛?涔嬮棿鐨勯棿璺濓紱
  //     鎴戜滑鐜板湪鐢?`app.float.slider_margin_bottom`(16vp) 缁?鈬?鐩存帴鏀逛細绉诲姩浼犺緭鏉′綅缃€?
  //   路 `playSize` 72/62/52锛氣槄 **宸茬粡绛変簬鏃犵晫鐨?FULL 鍊?* 鈥斺€?
  //     `app.float.image_play_width = 72vp`锛堟墜鏈烘。锛夈€傗噿 杩欎竴椤?*浜嬪疄涓婂凡瀵归綈**锛?
  //     鍓╀笅鐨勫彧鏄?MEDIUM/COMPACT 妗ｈ缂╁皬"锛屽睘瀹藉睆/骞虫澘锛堣澶囧彈闄愶級銆?
  //   路 `seekSize` 32/30/28锛氣槄 **2026-10-16 璁㈡** 鈥斺€?瀹冪殑璇箟鏄?
  //     **浼犺緭鏉′笂涓や釜鏂瑰舰鍥炬爣鎸夐挳锛堜笂涓€棣?涓嬩竴棣栵級鐨勫搴?*锛坄wujie.pa:181429` / `181639`锛?
  //     `Image().width(chrome().seekSize).aspectRatio(1)`锛夛紝**涓庤繘搴︽潯鏃犲叧**
  //     鈬?宸茶惤鍦颁负 `chromeSeekSize()`锛屾秷璐圭偣 = `ControlAreaComponent` 閭ｄ袱涓?`Image`銆?
  //     鏃ф敞閲婇噷"鎴戜滑缁欑殑鏄?`slider_height = 16vp`锛屼袱鑰呬笉鏄悓涓€涓噺"杩欏彞**缁撹閿欎簡**锛?
  //     瀹冧滑**鏍规湰涓嶆槸鍚屼竴涓厓绱犮€佷笉闇€瑕佸榻?*銆?
  //   路 `bottomGap` 65/48/36锛氣槄 **2026-10-16 宸茶惤鍦?*涓?`padBottomVp()`
  //     锛坄= max(avoidBottom, 妗ｄ綅琛?bottomGap)`锛涢偅涓?寰幆渚濊禆"鏄彲瑙ｇ殑锛岃璇ユ柟娉曟敞閲婏級銆?
  // 鈬?缁撹锛氳繖 5 椤归噷 `gapSwiper` / `gapScrub` / `seekSize` / `bottomGap` 閮藉凡钀藉湴锛?
  //    鍙墿 `playSize` 鐨?MEDIUM/COMPACT 涓ゆ。锛堝睘瀹藉睆/骞虫澘锛岃澶囧彈闄愶級銆?
  //    鈿狅笍 **涓嶈**鍐嶆妸杩欎簺鍋氭垚"鍙妗ｄ綅璁块棶鍣ㄦ斁閭ｅ効娌′汉鐢? 鈥斺€?閭ｆ槸 搂56.30 閭ｆ潯
  //    `chromeGap` 姝荤閬撶殑缈荤増锛堜細鍐嶆璇鍚庢潵浜猴級锛涙瘡涓€椤归兘蹇呴』**鍚屾椂鎺ヤ笂娑堣垂鐐?*銆?

  /** 鎺у埗鍖烘槸鍚﹁鑷姩鏀惰捣锛堝鏍?`BarCollapse.isCollapsed`锛夈€?*/
  @Trace public chromeCollapsed: boolean = false;

  /**
   * 璁板綍涓€娆℃帶鍒跺尯浜や簰锛堢偣鍑?婊戝姩锛夆€斺€?鍙炕杞?鏄惁鏀惰捣"杩欎竴涓姸鎬併€?
   *
   * 鈽呪槄鈽?2026-10-16锛?*鏈疆鍒犳帀浜嗚繖鏉￠摼涓婂彟澶栦袱涓垚鍛?*锛?
   *
   * 鍘熸潵杩欓噷杩樻湁 `lastChromeTouchMs` + `CHROME_AUTO_HIDE_MS(3000)` + `chromeShouldAutoHide()` +
   * `collapseChrome()` 鈥斺€?**鍥涗釜鎴愬憳鍏ㄩ儴闆舵秷璐?*锛堟湰鏂囦欢 :1623 鏃╁氨璁拌繃"鏃ф帶鍒跺尯鑷姩鏀惰捣"鏄鐨勶紝
   * 浣嗕竴鐩存病鍒狅級銆傚畠浠笉鍙槸"娌＄敤"锛岃€屾槸**鏈夊**锛?
   * ```
   *   瀹冧滑璁?鑷姩鏀惰捣"鍦ㄦ湰浠撶湅璧锋潵鏈?*涓ゅ鍊?*锛?
   *     PlayerExpandState.CHROME_AUTO_HIDE_MS = 3000   鈫?闆舵秷璐癸紙鏈疆鍒犻櫎锛?
   *     PlaybackPage.CHROME_AUTO_HIDE_MS      = 5000   鈫?娲荤殑锛? 鏃犵晫 PlayerPage.IDLE_MS锛岃 搂96锛?
   *   鈬?鍚庢潵浜烘寜 3000 鍘绘牳瀵瑰氨浼氬緱鍑?涓庢棤鐣屼笉涓€鑷?鐨勯敊璇粨璁恒€?
   * ```
   * 鈿狅笍 鍙﹀ `chromeCollapsed` 杩欎釜鍚嶅瓧鍦?*涓や釜绫婚噷鍚勬湁涓€涓?*锛堟湰绫?+ `PlaybackPage` 鑷繁鐨?
   *    `@Local chromeCollapsed`锛夆€斺€?鍚庤€呮墠鏄覆鏌撶敤鐨勯偅涓紱鏈被杩欎釜鍙 `chromeOffsetY()` /
   *   鏈柟娉?/ `revealChrome()` 璇诲啓锛坄PlaybackPage` 浼氳皟鍚庝袱涓級銆?
   *    鈬?**涓嶈**鎶婂畠褰撴垚"鎾斁椤甸偅浠?锛屽畠浠槸涓ゅ鐘舵€併€?
   */
  public touchChrome(): void {
    this.chromeCollapsed = false;
  }

  /** 鍞ゅ嚭鎺у埗鍖猴紙`PlaybackPage.touchChrome()` 鐨勬ā鍨嬩晶瀵瑰簲鐗╋級銆?*/
  public revealChrome(): void {
    this.chromeCollapsed = false;
  }

  /** @returns 鎺у埗鍖鸿瑙変綅绉伙紙vp锛夛細鏀惰捣鏃跺悜涓嬬Щ鍑恒€?*/
  public chromeOffsetY(): number {
    return this.chromeCollapsed ? 46 : 0;
  }

  /** @returns 鎺у埗鍖洪€忔槑搴︼細鑷姩鏀惰捣鏃舵贰鍑猴紱闈欐鎬佹亽 1锛堜笉瀛樺湪娈嬬暀鍗婇€忔槑鎬侊級銆?*/
  public chromeOpacity(): number {
    return this.chromeCollapsed ? 0 : 1;
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鐩镐綅鍒囨崲 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /**
   * @returns 涓ょ鐨勫皝闈㈢煩褰㈡槸鍚﹂兘閲忓埌浜嗭紙鍙互寮€璺戝姩鐢伙級銆?
   */
  public hasGeometry(): boolean {
    return this.miniSize > 0 && this.bigSize > 0;
  }

  /**
   * 杩涘叆 `preparing` 鐩镐綅锛氳繘搴﹀綊闆躲€佹暣椤甸€忔槑銆佹竻鎺夋棫鐨勭粓鐐圭煩褰㈤€煎畠閲嶆柊涓婃姤銆?
   *
   * 璧风偣锛堣糠浣犳潯锛?*涓嶆竻**锛氶椤电殑 HDS 杩蜂綘鏉′笉浼氶殢鎾斁椤靛紑鍏抽噸鏂版寕杞斤紝
   * 鎷夸笉鍒版柊鐨勪笂鎶ワ紝娌跨敤涓婁竴娆＄殑鍊煎嵆鍙紙瀹冩湰鏉ュ氨娌″姩杩囷級銆?
   */
  public armExpand(): void {
    this.progress = 0;
    this.bigSize = 0;
    this.preparing = true;
    this.animating = false;
  }

  /** 杩涘叆 `animating` 鐩镐綅锛氶琛屽皝闈㈢櫥鍦猴紝杩蜂綘鏉″皝闈笌鎾斁椤靛ぇ灏侀潰閫€鍦恒€?*/
  public beginAnimating(): void {
    this.preparing = false;
    this.animating = true;
  }

  /** 灞曞紑鍔ㄧ敾鎾畬锛氫氦杩樼粰闈欐€佸竷灞€銆?*/
  public finishAnimating(): void {
    this.animating = false;
    this.progress = 1;
  }

  /** 鍥炲埌銆屽凡灞曞紑鐨勯潤姝㈡€併€嶃€傛祴閲忓け璐ャ€佸涓诲嵏杞姐€佹敹璧风粨鏉熸椂閮借蛋杩欓噷銆?*/
  public reset(): void {
    this.preparing = false;
    this.animating = false;
    this.progress = 1;
  }

  /** 璇锋眰鎾斁鍙嶅悜锛堟敹璧凤級鍔ㄧ敾銆傛挱鏀鹃〉鐨勮繑鍥炴寜閽皟鐢ㄥ畠锛屼笉瑕佽嚜宸辩疆 `isShowPlay`銆?*/
  public requestCollapse(): void {
    this.collapseVersion = this.collapseVersion + 1;
  }

  // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 閫愬抚鍙栧€硷紙build 閲岀洿鎺ヨ皟锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

  /** @returns 褰撳墠杩涘害涓嬮琛屽皝闈㈢殑宸﹁竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級銆?*/
  public coverX(): number {
    return this.lerp(this.miniX, this.bigX, this.progress);
  }

  /** @returns 褰撳墠杩涘害涓嬮琛屽皝闈㈢殑涓婅竟鐣岋紙vp锛岀獥鍙ｅ潗鏍囷級銆?*/
  public coverY(): number {
    return this.lerp(this.miniY, this.bigY, this.progress);
  }

  /** @returns 褰撳墠杩涘害涓嬮琛屽皝闈㈢殑杈归暱锛坴p锛夈€?*/
  public coverSize(): number {
    return this.lerp(this.miniSize, this.bigSize, this.progress);
  }

  /** @returns 褰撳墠杩涘害涓嬮琛屽皝闈㈢殑鍦嗚锛坴p锛夈€?*/
  public coverRadius(): number {
    return this.lerp(this.miniRadius, this.bigRadius, this.progress);
  }

  /**
   * @returns 椋炶灏侀潰涓嶉€忔槑搴︼細鍔ㄧ敾鏈熼棿鍙銆?
   *
   * 鈽呪槄 2026-10-15锛?*宸插垽瀹氫负姝讳唬鐮?*锛宍RzdMusic璁板繂.md` 搂60锛夛細**闆惰皟鐢ㄨ€?*锛?
   *   鑰屼笖瀹冭鐨?`animating` 灞?*鏃ц浆鍦?*閭ｄ竴鏃忥紙鍚?{@link clipActive}锛夆€斺€?
   *   娲荤殑褰㈠彉閲?灏侀潰璋佸湪鐢?鐢?`realCoverVisible()`锛堟挱鏀鹃〉鐪熷皝闈級
   *   涓?`morphOverlayBridging()`锛堝３灞傚厠闅嗗皝闈級**涓ユ牸浜掕ˉ鐨勪竴瀵归棬**鍐冲畾锛?
   *   娌℃湁浠讳綍鍦版柟鐢?鏃ц浆鍦虹殑 `animating`"鏉ユ贰鍏ユ贰鍑哄皝闈€?
   * 鈿狅笍 鍚屾棌鐨?{@link miniCoverOpacity}锛堣鍚屼竴涓?`animating`锛?*涔熸槸闆惰皟鐢ㄨ€?*銆?
   * @deprecated 闆惰皟鐢ㄨ€呫€傚皝闈㈢殑鏄鹃殣璇风敤 {@link realCoverVisible} / {@link morphOverlayBridging}銆?
   * 澶嶆牳鍛戒护锛歚grep -rn 'coverOpacity()\|miniCoverOpacity()' RzdMusic --include=*.ets`
   */
  public coverOpacity(): number {
    return this.animating ? 1 : 0;
  }

  /** @returns 杩蜂綘鏉″皝闈笉閫忔槑搴︼細鍔ㄧ敾鏈熼棿闅愯棌锛岄伩鍏嶄笌椋炶灏侀潰閲嶅奖銆?*/
  public miniCoverOpacity(): number {
    return this.animating ? 0 : 1;
  }

  /** @returns 鎾斁椤靛ぇ灏侀潰涓嶉€忔槑搴︼細鍔ㄧ敾鏈熼棿闅愯棌锛堥琛屽皝闈㈤《鏇垮畠锛夈€?*/
  public innerCoverOpacity(): number {
    return this.animating ? 0 : 1;
  }

  /**
   * @returns 鎾斁椤垫暣椤典笉閫忔槑搴︺€?
   *
   * - `preparing`锛? 鈥斺€?椤甸潰宸叉寕杞戒絾缁濅笉鑳介湶鍑烘潵锛堣繖灏辨槸闃查棯鐨勯偅涓€鐩镐綅锛夛紱
   * - `animating`锛氬墠 45% 娣″叆 鈥斺€?鍚﹀垯鍔ㄧ敾寮€澶磋糠浣犳潯閭ｄ竴灏忓潡閲屼細绯婄潃鎾斁椤靛簳閮ㄦ帶浠讹紱
   * - 鍏朵綑锛?銆?
   */
  public pageOpacity(): number {
    if (this.preparing) {
      return 0;
    }
    if (!this.animating) {
      return 1;
    }
    return Math.min(1, this.progress / 0.45);
  }

  /**
   * 鈽呪槄 2026-10-15锛?*宸插垽瀹氫负姝讳唬鐮?*锛宍RzdMusic璁板繂.md` 搂59锛夛細鏈綋鏄?鏃ц浆鍦?閭ｄ竴鏃忕殑娈嬬暀銆?
   *
   * 鏈被閲?`preparing` / `animating` / `progress` 涓変釜瀛楁锛圠202-206锛夊睘**鏇存棭鐨勯偅濂?
   * 銆屾暣椤垫贰鍏?+ 璐村簳涓婃粦銆嶈浆鍦?*锛涙椿鐨勫舰鍙橀摼璧扮殑鏄?`morphStage` / `morphP` / `applyMorphProgress()`锛?
   * **瀹屽叏涓嶈瀹冧滑**锛堣 L1164 閭ｆ娉ㄩ噴锛夈€傛湰鏂规硶鍙湪瀹冧滑涔嬩笂鍋氫簡涓€娆℃垨杩愮畻 鈬?鍚屾牱娌℃湁璋冪敤鑰呫€?
   *
   * 鈿狅笍 **鏁呮剰淇濈暀鑰屼笉鏄垹闄?*锛氬畠涓?`morphClipping()`锛堟椿鐨勮鍓棬锛夎涔変笂鏈夐噸鍙狅紝
   *    鍒犻櫎鏃惰嫢鏈変汉璇妸璋冪敤鐐逛粠 `morphClipping()` 鎹㈡垚瀹冦€佹垨鍙嶈繃鏉ワ紝灏变細鍔ㄥ埌瑁佸壀琛屼负銆?
   *    鐣欏湪杩欓噷鐨勪唬浠峰彧鏄嚑琛岋紱鎶婂畠鍙樻垚"娲荤殑"鎵嶆槸椋庨櫓銆?
   * @deprecated 鏃犺皟鐢ㄨ€呫€傝鐢ㄨ鍓棬璇风敤 {@link morphClipping}銆?
   * @returns 鏃ц浆鍦虹浉浣嶆槸鍚﹀浜?闇€瑕佽鍓?銆?
   * 澶嶆牳鍛戒护锛歚grep -rn 'clipActive' RzdMusic --include=*.ets`锛堟湡鏈涳細鍙湁鏈瀹氫箟锛?
   */
  public clipActive(): boolean {
    return this.preparing || this.animating;
  }

  /**
   * @returns clip 绐楀彛鐨?SVG path 鍛戒护锛堝崟浣?vp锛屼綔鐢ㄥ湪鎾斁椤靛涓昏嚜宸辩殑鍧愭爣绯讳笂锛夈€?
   *
   * 闈欐鎬佺洿鎺ョ粰涓€涓繙澶т簬绐楀彛鐨勭煩褰細鍙鏈変竴涓昂瀵哥畻閿欏氨浼氭妸鎾斁椤佃鎺変竴鍧楋紝
   * 瀹佸彲涓嶈銆傚姩鐢绘湡闂存墠閫愬抚鍋氬渾瑙掔煩褰㈡彃鍊笺€?
   */
  public clipCommands(): string {
    if (this.progress >= 1) {
      return PlayerExpandState.roundedRectPath(-4000, -4000, 8000, 8000, 0);
    }
    const t: number = this.progress;
    const m: number = CLIP_IDLE_MARGIN_VP;
    const x: number = this.lerp(this.miniX, -m, t);
    const y: number = this.lerp(this.miniY, -m, t);
    const w: number = Math.max(1, this.lerp(this.miniSize, this.windowWidthVp + m * 2, t));
    const h: number = Math.max(1, this.lerp(this.miniSize, this.windowHeightVp + m * 2, t));
    return PlayerExpandState.roundedRectPath(x, y, w, h, this.coverRadius());
  }

  /** @returns 绾挎€ф彃鍊笺€?*/
  private lerp(from: number, to: number, t: number): number {
    return from + (to - from) * t;
  }

  /**
   * 鍦嗚鐭╁舰鐨?SVG path 鍛戒护銆?
   * @param x 宸︿笂瑙?x
   * @param y 宸︿笂瑙?y
   * @param w 瀹?
   * @param h 楂?
   * @param r 鍦嗚锛堜細鑷姩澶瑰埌鐭竟鐨勪竴鍗婁互鍐咃紝鍚﹀垯 path 鑷氦浼氱敾姝級
   * @returns path 鍛戒护瀛楃涓?
   */
  private static roundedRectPath(x: number, y: number, w: number, h: number, r: number): string {
    const x1: number = x + w;
    const y1: number = y + h;
    const safeR: number = Math.max(0, Math.min(r, Math.min(w, h) / 2));
    if (safeR <= 0.01) {
      return `M${x} ${y} H${x1} V${y1} H${x} Z`;
    }
    return `M${x + safeR} ${y} H${x1 - safeR} A${safeR} ${safeR} 0 0 1 ${x1} ${y + safeR} ` +
      `V${y1 - safeR} A${safeR} ${safeR} 0 0 1 ${x1 - safeR} ${y1} H${x + safeR} ` +
      `A${safeR} ${safeR} 0 0 1 ${x} ${y1 - safeR} V${y + safeR} A${safeR} ${safeR} 0 0 1 ${x + safeR} ${y} Z`;
  }
}
