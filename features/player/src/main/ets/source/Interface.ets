export type OnlineSource = 'kw' | 'kg' | 'tx' | 'wy' | 'mg'
export type LXSource = OnlineSource | 'local'
export type LXQuality = '128k' | '320k' | 'flac' | 'flac24bit' | '192k' | 'ape' | 'wav'
  | 'hires' | 'atmos' | 'atmos_plus' | 'master'

const VALID_LX_SOURCES: string[] = ['kw', 'kg', 'tx', 'wy', 'mg', 'local'];

export function isLXSource(value: string): boolean {
  return VALID_LX_SOURCES.indexOf(value) >= 0;
}

export function toLXSource(value: string): LXSource {
  if (isLXSource(value)) {
    return value as LXSource;
  }
  return 'kw';
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
