/**
 * MusicFree 插件「能力标记」——**唯一识别入口**。
 *
 * ★ 2026-11-09（用户：「我看原版好像是有屏蔽的，因为榜单和推荐都只有部分平台
 *   （比如元力的哔哩就没有推荐，只有榜单）」）：
 *   MusicFree 协议里，插件**实现了哪些方法**就代表它支持哪些功能：
 *     · `getTopLists` + `getTopListDetail` ⇒ 有榜单；
 *     · `getRecommendSheetTags` + `getRecommendSheetsByTag` ⇒ 有推荐歌单（歌单广场）；
 *     · `searchSheet` ⇒ 能搜歌单；`getMusicSheetInfo` ⇒ 能取歌单歌曲。
 *   原版就是据此决定「这个平台显不显示推荐 / 榜单」的。
 *
 * 为什么要**静态扫描**而不是等插件跑起来：能力标记要在 UI 首帧就用到（决定平台胶囊、
 * 空态文案），而加载一个插件要重载 WebView + 注入 100KB+ JS，6 个插件串行要好几秒。
 * 插件都是 `module.exports = { ... }` 字面量，方法名直接写在源码里，扫一遍足够准。
 */
import { LXUserApiInfo } from '../source/Interface';

export const MF_CAP_MEDIA: string = 'media';
export const MF_CAP_LYRIC: string = 'lyric';
export const MF_CAP_SEARCH: string = 'search';
export const MF_CAP_SEARCH_SHEET: string = 'searchSheet';
export const MF_CAP_SHEET: string = 'sheet';
export const MF_CAP_TOP_LIST: string = 'toplist';
export const MF_CAP_RECOMMEND: string = 'recommend';
export const MF_CAP_ALBUM: string = 'album';
export const MF_CAP_ARTIST: string = 'artist';

/**
 * 源码里是否存在这个方法的定义。
 *
 * 只认「名字后面紧跟 `(` 或 `:`」：
 *   · `async getTopLists() {}`   → 命中；
 *   · `getTopLists: async () =>` → 命中；
 *   · 注释里的 "调用 getTopLists 取榜单" → **不**命中（后面是空格/汉字）。
 */
function definesMethod(src: string, name: string): boolean {
  const re: RegExp = new RegExp('(^|[^A-Za-z0-9_$])' + name + '\\s*[:(]');
  return re.test(src);
}

/**
 * 扫描插件源码，得出能力列表。
 * @param script 插件 JS 原文（`gz_` 压缩过的读出来是空串 ⇒ 返回空数组 = 未知）
 */
export function scanMfCaps(script: string): string[] {
  const out: string[] = [];
  if (script.length === 0) {
    return out;
  }
  if (definesMethod(script, 'getMediaSource')) {
    out.push(MF_CAP_MEDIA);
  }
  if (definesMethod(script, 'getLyric')) {
    out.push(MF_CAP_LYRIC);
  }
  if (definesMethod(script, 'search')) {
    out.push(MF_CAP_SEARCH);
  }
  if (definesMethod(script, 'searchSheet')) {
    out.push(MF_CAP_SEARCH_SHEET);
  }
  if (definesMethod(script, 'getMusicSheetInfo')) {
    out.push(MF_CAP_SHEET);
  }
  // 榜单是**一对**方法：只实现 getTopLists 拿不到歌，等于不可用
  if (definesMethod(script, 'getTopLists') && definesMethod(script, 'getTopListDetail')) {
    out.push(MF_CAP_TOP_LIST);
  }
  // 推荐歌单同样是**一对**：标签 + 按标签拉歌单
  if (definesMethod(script, 'getRecommendSheetTags') &&
    definesMethod(script, 'getRecommendSheetsByTag')) {
    out.push(MF_CAP_RECOMMEND);
  }
  if (definesMethod(script, 'getAlbumInfo')) {
    out.push(MF_CAP_ALBUM);
  }
  if (definesMethod(script, 'getArtistWorks')) {
    out.push(MF_CAP_ARTIST);
  }
  return out;
}

/**
 * 插件是否具备某个能力。
 *
 * ⚠️ 能力**未知**（旧数据没存 / 压缩脚本扫不出来）时一律返回 true：
 *    宁可多显示一个入口（点进去是空态），也不要把能用的功能藏起来。
 */
export function mfHasCap(api: LXUserApiInfo, cap: string): boolean {
  const caps: string[] | undefined = api.caps;
  if (caps === undefined || caps === null || caps.length === 0) {
    return true;
  }
  return caps.indexOf(cap) >= 0;
}
