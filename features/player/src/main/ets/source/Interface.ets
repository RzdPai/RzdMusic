export type OnlineSource = 'kw' | 'kg' | 'tx' | 'wy' | 'mg' | 'qs'
export type LXSource = OnlineSource | 'local'
export type LXQuality = '128k' | '320k' | 'flac' | 'flac24bit' | '192k' | 'ape' | 'wav'
  | 'hires' | 'atmos' | 'atmos_plus' | 'master'

const VALID_LX_SOURCES: string[] = ['kw', 'kg', 'tx', 'wy', 'mg', 'qs', 'local'];

export function isLXSource(value: string): boolean {
  return VALID_LX_SOURCES.indexOf(value) >= 0;
}

export function toLXSource(value: string): LXSource {
  if (isLXSource(value)) {
    return value as LXSource;
  }
  return 'kw';
}

/**
 * 请求信封里的 `source`：**保留脚本声明的原始键**（别名也原样透传）。
 *
 * ★★★ 2026-11-04（踩到的坑，别退回 `toLXSource`）：`toLXSource()` 会把**不认识的键塌成 `'kw'`**。
 *   实测脚本「全豆要[聚合音源] v9.7」把汽水声明成 `qsvip`（`sourceConfig['qsvip']`，
 *   `on(request)` 里按 `source === 'qsvip'` 路由到 `qishuiHandler`）；
 *   一旦经过 `toLXSource('qsvip')` 就变成 `'kw'` ⇒ 脚本把它当酷我处理，
 *   "平台别名 → qs" 的映射当场失效（请求照样发出去，但拿不到汽水地址）。
 *   脚本只按字符串路由，不需要白名单，透传即可。
 * @param value 脚本声明的平台键（如 `qsvip` / `kw`）；空串回落 `'kw'`
 */
export function toLXSourceKey(value: string): LXSource {
  return (value.length > 0 ? value : 'kw') as LXSource;
}

export interface LXUserApiSourceInfo {
  name: string
  type: string
  actions: string[]
  qualitys: LXQuality[]
}

export interface LXUserApiInfoFull {
  id: string
  name: string
  description: string
  script: string
  allowShowUpdateAlert: boolean
  author: string
  homepage: string
  version: string
  kind: string
  platform: string
  sources: Record<string, LXUserApiSourceInfo>
}

export interface LXUserApiInfo {
  id: string
  name: string
  description: string
  allowShowUpdateAlert: boolean
  author: string
  homepage: string
  version: string
  /**
   * 音源类型：`lx`（洛雪脚本，默认）/ `mf`（MusicFree 插件）。
   *
   * ★ 两者运行时完全不同（LX 是 `window.lx` 事件式，MusicFree 是 CommonJS 模块），
   *   同一个列表里混存，必须能一眼分辨该塞给哪个引擎。
   *   旧数据里没有这个字段，读盘时会补成 `lx`。
   */
  kind: string
  /** MusicFree 插件声明的平台名（`platform` 字段，如「元力WY」）；LX 脚本为空串。 */
  platform: string
  /**
   * 用户手动修正的「这个脚本实际支持哪些平台」（规范 id：kw/kg/tx/wy/mg/qs）。
   *
   * ★ 2026-11-09（用户：「LX 是修改支持的平台，因为源不稳定，平台可能失效」）：
   *   脚本 init 上报的 `sources` 是**声明**，不等于现在还能用。用户裁掉失效平台后，
   *   播放兜底链（`SourceFallbackUtil`）不再把这个脚本派给被裁掉的平台。
   *   缺省 / 空数组 = 不覆盖，按脚本声明来（旧数据没有这个字段）。
   */
  platformOverride?: string[]
  /**
   * 用户给这个源起的**备注**（空串 = 没改过，显示 `name`）。
   *
   * ★ 2026-11-09（用户：「MusicFree 的源支持一下修改备注」）：订阅里多个插件
   *   可能同名（都叫「元力WY」），靠备注区分；必须与 `name` 分开存 ——
   *   `name` 参与「订阅更新时按平台/名字去重」的匹配，被备注覆盖会导不出重复条目。
   *   旧数据没有这个字段，读盘后按空串处理。
   */
  remark?: string
  /**
   * 插件**实现了哪些协议方法**（`media` / `lyric` / `searchSheet` / `toplist` /
   * `recommend` / …，见 `util/MfCapability`）。
   *
   * ★ 2026-11-09（用户：「原版是有屏蔽的，榜单和推荐都只有部分平台」）：
   *   原版 MusicFree 按「插件有没有实现对应方法」决定显示哪些入口，
   *   例如元力的哔哩哔哩只有 `getTopLists`、没有 `getRecommendSheetTags`，
   *   所以只出榜单、不出推荐。导入/读盘时静态扫描写入，UI 用它做能力屏蔽。
   *   缺省 = 未知（旧数据 / 压缩脚本），按「都支持」处理，不误藏。
   */
  caps?: string[]
  /**
   * 归属的 MusicFree 订阅 id；独立导入的脚本为空串。
   *
   * ★ 2026-11-09（用户：「源管理里显示我添加的整个订阅源，方便后续更新」）：
   *   订阅是用户视角的一等对象，插件是它的成员。源管理按它分组，更新整包。
   */
  subId: string
  sources: Record<string, LXUserApiSourceInfo>
}

/**
 * 一份 MusicFree 订阅（用户视角的「源」）。
 *
 * 与插件的区别：订阅是**可更新的整体**（记住 url），插件是它下载下来的成员。
 * 平台细节不进这里 —— 平台统一由 PlatformRegistry 从插件实时派生。
 */
export interface MfSubscriptionInfo {
  id: string
  /**
   * 导入时的来源名（订阅 JSON 的 name / 主机名 / 文件名）。
   * ⚠️ 只作为**去重与追溯**用的稳定值，不要直接拿去显示 —— 联网订阅这里就是域名
   *   （`13413.kstore.vip`），显示请用 `remark` 或 `musicFreeSubscriptionLabel()`。
   */
  name: string
  /**
   * 用户给这份订阅（= 音源本身）起的备注。
   * ★ 2026-11-09（用户：「修改备注是修改音源本身的备注，只显示域名太难看了」）：
   *   左滑「编辑」改的就是它；留空则回退到 name。
   */
  remark?: string
  /** 订阅地址；文件导入的订阅为空串（不能在线更新，只能重新选文件）。 */
  url: string
  /** 当前归属该订阅的音源 id（插件）。 */
  apiIds: string[]
  /** 最近一次导入 / 更新的时间戳（毫秒）。 */
  updatedAt: number
}

export interface LXMusicUrlInfo {
  type: LXQuality
  url: string
}

export interface LXMusicUrlResult {
  source: LXSource
  action: string
  data: LXMusicUrlInfo
}

export interface LXLyricResult {
  source: LXSource
  action: string
  data: LXLyricData
}

export interface LXLyricData {
  lyric: string
  tlyric: string | null
  rlyric: string | null
  lxlyric: string | null
}

export interface LXPicResult {
  source: LXSource
  action: string
  data: string
}

export interface LXSourceInitMessage {
  sources: Record<string, LXUserApiSourceInfo>
}

export interface LXSourceRequestData {
  source: LXSource
  action: string
  info: object
}
