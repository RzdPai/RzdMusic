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
  sources: Record<string, LXUserApiSourceInfo>
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
