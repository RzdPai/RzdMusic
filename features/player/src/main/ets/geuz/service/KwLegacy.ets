/**
 * 酷我**老接口**（`search.kuwo.cn/r.s`）—— 与无界音乐 1.3.3 逐条对齐。
 *
 * ## 为什么单独一个文件
 *
 * 无界（反编译核对，`wujie133.pa`）对酷我**只用** `search.kuwo.cn/r.s` 这一套老接口，
 * **完全没有** `www.kuwo.cn/api/www/*`：
 *
 * | 用途 | 无界用的 URL（`stype` / `ft` 是关键字） |
 * | --- | --- |
 * | 专辑详情 | `r.s?pn=0&rn=N&stype=albuminfo&albumid=ID&show_copyright_off=0&encoding=utf&vipver=MUSIC_9.1.0` |
 * | 歌手信息 | `r.s?stype=artistinfo&artistid=ID&encoding=utf8&vipver=MUSIC_9.1.0…` |
 * | 歌手歌曲 | `r.s?pn=P&rn=N&stype=artist2music&artistid=ID&show_copyright_off=0&encoding=utf&vipver=MUSIC_9.1.0` |
 * | 歌手专辑 | `r.s?pn=P&rn=N&stype=albumlist&artistid=ID&sortby=1&encoding=utf8&vipver=MUSIC_9.1.0` |
 * | 专辑搜索 | `r.s?pn=0&rn=N&all=KW&ft=album&newsearch=1&itemset=web_2013&client=kt&cluster=0` |
 *
 * 而本仓原来走 `api/www/*`（要 cookie+csrf+Secret 三件套，且参数大小写敏感），
 * 实测一路空 ⇒ 酷我"搜不到 / 点进去空的"。
 * 老接口**不需要任何鉴权**，只要 UA/Referer，这也是无界一直好用的原因。
 *
 * 返回体是老式 JSON：**单引号** + **大写键**（`abslist` / `ALBUMID` / `ARTISTID`…），
 * 个别接口会混小写，所以这里统一"规范化 + 多键名兜底"解析。
 */

import { http } from '@kit.NetworkKit'
import { AlbumInfo, AlbumDetailResult, ArtistAlbumPageResult, ArtistInfo, SongInfo, SongPageResult } from '../model/SearchModels'

const KW_UA: string = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36'
const KW_REFERER: string = 'http://www.kuwo.cn/'

/** 老接口固定尾巴（与无界一致）。 */
const TAIL_ALBUM: string = '&show_copyright_off=0&encoding=utf&vipver=MUSIC_9.1.0'
const TAIL_JSON: string = '&rformat=json&encoding=utf8'

/** 把老式「单引号 JSON」规范成标准 JSON（只处理引号，不动内容）。 */
function toStdJson(text: string): string {
  let out: string = ''
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i)
    if (ch === '\\' && i + 1 < text.length && text.charAt(i + 1) === '\'') {
      out = out + '"'
      i = i + 1
      continue
    }
    out = out + (ch === '\'' ? '"' : ch)
  }
  return out
}

async function kwLegacyGet(url: string): Promise<Record<string, Object>> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': KW_UA, 'Referer': KW_REFERER },
      connectTimeout: 15000,
      readTimeout: 15000
    } as http.HttpRequestOptions)
    if (resp.responseCode !== 200 || resp.result === undefined) {
      return {} as Record<string, Object>
    }
    const text: string = typeof resp.result === 'string' ? resp.result : String(resp.result)
    const body: string = text.trim()
    if (body.length === 0) {
      return {} as Record<string, Object>
    }
    try {
      return JSON.parse(body) as Record<string, Object>
    } catch (_e) {
      try {
        return JSON.parse(toStdJson(body)) as Record<string, Object>
      } catch (_e2) {
        return {} as Record<string, Object>
      }
    }
  } catch (_err) {
    return {} as Record<string, Object>
  } finally {
    req.destroy()
  }
}

/** 大小写不敏感地取字段（老接口同一个字段大小写不稳定）。 */
function pick(obj: Record<string, Object>, keys: string[]): string {
  for (let i: number = 0; i < keys.length; i++) {
    const direct: Object | undefined = obj[keys[i]]
    if (direct !== undefined && direct !== null) {
      const s: string = String(direct)
      if (s.length > 0 && s !== 'undefined' && s !== 'null') {
        return s
      }
    }
    const lower: string = keys[i].toLowerCase()
    const upper: string = keys[i].toUpperCase()
    const viaLower: Object | undefined = obj[lower]
    if (viaLower !== undefined && viaLower !== null) {
      const s2: string = String(viaLower)
      if (s2.length > 0 && s2 !== 'undefined' && s2 !== 'null') {
        return s2
      }
    }
    const viaUpper: Object | undefined = obj[upper]
    if (viaUpper !== undefined && viaUpper !== null) {
      const s3: string = String(viaUpper)
      if (s3.length > 0 && s3 !== 'undefined' && s3 !== 'null') {
        return s3
      }
    }
  }
  return ''
}

/** `&nbsp;` 之类的实体与多余空白清理（老接口歌名里常见）。 */
function clean(v: string): string {
  return v.replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim()
}

function toHttps(url: string): string {
  if (url.length === 0) {
    return ''
  }
  return url.startsWith('http://') ? 'https://' + url.substring('http://'.length) : url
}

function asArray(v: Object | undefined): Record<string, Object>[] {
  if (v === undefined || v === null) {
    return []
  }
  const arr = v as Object[]
  const out: Record<string, Object>[] = []
  if (!Array.isArray(arr)) {
    return out
  }
  for (let i: number = 0; i < arr.length; i++) {
    const one = arr[i]
    if (one !== undefined && one !== null) {
      out.push(one as Record<string, Object>)
    }
  }
  return out
}

/** `MUSIC_12345` → `12345`。 */
function ridOf(v: string): string {
  const idx: number = v.indexOf('_')
  return idx >= 0 ? v.substring(idx + 1) : v
}

/**
 * 歌手信息（`stype=artistinfo`）—— 无界 `KwArtist.getArtistInfo` 同源。
 * @param artistId 酷我歌手 id
 * @returns 歌手信息（拿不到就抛，调用方会试下一个来源）
 */
export async function kwLegacyArtist(artistId: string): Promise<ArtistInfo> {
  const url: string = 'http://search.kuwo.cn/r.s?stype=artistinfo&artistid=' + encodeURIComponent(artistId) +
    '&encoding=utf8&vipver=MUSIC_9.1.0&rformat=json'
  const root: Record<string, Object> = await kwLegacyGet(url)
  const name: string = clean(pick(root, ['ARTIST', 'artist', 'NAME', 'name']))
  const pic: string = toHttps(pick(root, ['ARTISTPIC', 'artistpic', 'pic', 'PIC']))
  const desc: string = clean(pick(root, ['DESC', 'desc', 'INFO', 'info', 'INTRO', 'intro']))
  const albumNum: number = Number(pick(root, ['ALBUMNUM', 'albumnum']) || '0')
  const songNum: number = Number(pick(root, ['SONGNUM', 'songnum', 'MUSICNUM', 'musicnum']) || '0')
  return new ArtistInfo(artistId, '', name, pic, '', albumNum, songNum, desc)
}

/**
 * 歌手歌曲（`stype=artist2music`）。
 * @param artistId 歌手 id
 * @param limit 每页条数
 * @param offset 偏移（换算成 pn）
 */
export async function kwLegacyArtistSongs(artistId: string, limit: number, offset: number): Promise<SongPageResult> {
  const pn: number = limit > 0 ? Math.floor(offset / limit) : 0
  const url: string = 'http://search.kuwo.cn/r.s?pn=' + pn + '&rn=' + limit +
    '&stype=artist2music&artistid=' + encodeURIComponent(artistId) + TAIL_ALBUM + TAIL_JSON
  const root: Record<string, Object> = await kwLegacyGet(url)
  const rows: Record<string, Object>[] = asArray(root['abslist'] ?? root['musiclist'])
  const list: SongInfo[] = []
  for (let i: number = 0; i < rows.length; i++) {
    const it: Record<string, Object> = rows[i]
    const rid: string = ridOf(pick(it, ['MUSICRID', 'musicrid', 'DC_TARGETID', 'id']))
    const name: string = clean(pick(it, ['SONGNAME', 'songname', 'NAME', 'name']))
    if (rid.length === 0 || name.length === 0) {
      continue
    }
    const singer: string = clean(pick(it, ['ARTIST', 'artist', 'AARTIST']))
    const album: string = clean(pick(it, ['ALBUM', 'album']))
    const dur: number = Number(pick(it, ['DURATION', 'duration']) || '0')
    const pic: string = toHttps(pick(it, ['web_artistpic', 'ARTISTPIC', 'web_albumpic_short']))
    list.push(new SongInfo(rid, name, singer, album, dur, pic))
  }
  return new SongPageResult(list, list.length, list.length >= limit)
}

/**
 * 歌手专辑（`stype=albumlist`）。
 * @param artistId 歌手 id
 * @param limit 每页条数
 * @param offset 偏移
 */
export async function kwLegacyArtistAlbums(artistId: string, limit: number,
  offset: number): Promise<ArtistAlbumPageResult> {
  const pn: number = limit > 0 ? Math.floor(offset / limit) : 0
  const url: string = 'http://search.kuwo.cn/r.s?pn=' + pn + '&rn=' + limit +
    '&stype=albumlist&artistid=' + encodeURIComponent(artistId) + '&sortby=1&encoding=utf8&vipver=MUSIC_9.1.0&rformat=json'
  const root: Record<string, Object> = await kwLegacyGet(url)
  const rows: Record<string, Object>[] = asArray(root['abslist'] ?? root['albumlist'])
  const out: AlbumInfo[] = []
  for (let i: number = 0; i < rows.length; i++) {
    const it: Record<string, Object> = rows[i]
    const albumId: string = pick(it, ['ALBUMID', 'albumid'])
    const name: string = clean(pick(it, ['ALBUM', 'album', 'NAME', 'name']))
    if (albumId.length === 0 || name.length === 0) {
      continue
    }
    const artist: string = clean(pick(it, ['ARTIST', 'artist']))
    const pic: string = toHttps(pick(it, ['WEB_ALBUM_PIC', 'web_albumpic', 'web_albumpic_short', 'pic']))
    const time: string = pick(it, ['RELEASEDATE', 'releasedate', 'PUBLICTIME', 'publishtime'])
    out.push(new AlbumInfo(albumId, '', name, pic, 0, artist, 0, time))
  }
  return new ArtistAlbumPageResult(out, out.length >= limit)
}

/**
 * 专辑搜索（`ft=album`）。
 * @param keyword 关键字
 * @param page 页码（1 起）
 * @param pageSize 每页条数
 */
export async function kwLegacySearchAlbum(keyword: string, page: number,
  pageSize: number): Promise<AlbumInfo[]> {
  const url: string = 'http://search.kuwo.cn/r.s?pn=0&rn=' + pageSize +
    '&all=' + encodeURIComponent(keyword) +
    '&ft=album&newsearch=1&itemset=web_2013&client=kt&cluster=0' + TAIL_JSON
  const root: Record<string, Object> = await kwLegacyGet(url)
  const rows: Record<string, Object>[] = asArray(root['abslist'] ?? root['albumlist'])
  const out: AlbumInfo[] = []
  for (let i: number = 0; i < rows.length; i++) {
    const it: Record<string, Object> = rows[i]
    const albumId: string = pick(it, ['ALBUMID', 'albumid'])
    const name: string = clean(pick(it, ['ALBUM', 'album', 'NAME', 'name']))
    if (albumId.length === 0 || name.length === 0) {
      continue
    }
    const artist: string = clean(pick(it, ['ARTIST', 'artist']))
    const pic: string = toHttps(pick(it, ['WEB_ALBUM_PIC', 'web_albumpic', 'web_albumpic_short', 'pic']))
    const time: string = pick(it, ['RELEASEDATE', 'releasedate'])
    out.push(new AlbumInfo(albumId, '', name, pic, 0, artist, 0, time))
  }
  return out
}

/**
 * 专辑详情 + 曲目（`stype=albuminfo`）。
 * @param albumId 酷我专辑 id
 */
export async function kwLegacyAlbum(albumId: string): Promise<AlbumDetailResult> {
  const url: string = 'http://search.kuwo.cn/r.s?pn=0&rn=200&stype=albuminfo&albumid=' +
    encodeURIComponent(albumId) + TAIL_ALBUM + TAIL_JSON
  const root: Record<string, Object> = await kwLegacyGet(url)
  const name: string = clean(pick(root, ['ALBUM', 'album', 'NAME', 'name']))
  const artist: string = clean(pick(root, ['ARTIST', 'artist']))
  const pic: string = toHttps(pick(root, ['WEB_ALBUM_PIC', 'web_albumpic', 'web_albumpic_short', 'pic']))
  const time: string = pick(root, ['RELEASEDATE', 'releasedate', 'PUBLICTIME', 'publishtime'])
  const info: AlbumInfo = new AlbumInfo(albumId, '', name, pic, 0, artist, 0, time)
  const rows: Record<string, Object>[] = asArray(root['musiclist'] ?? root['abslist'])
  const list: SongInfo[] = []
  for (let i: number = 0; i < rows.length; i++) {
    const it: Record<string, Object> = rows[i]
    const rid: string = ridOf(pick(it, ['MUSICRID', 'musicrid', 'DC_TARGETID', 'id']))
    const songName: string = clean(pick(it, ['SONGNAME', 'songname', 'NAME', 'name']))
    if (rid.length === 0 || songName.length === 0) {
      continue
    }
    const singer: string = clean(pick(it, ['ARTIST', 'artist']))
    const albumName: string = clean(pick(it, ['ALBUM', 'album'])) || name
    const dur: number = Number(pick(it, ['DURATION', 'duration']) || '0')
    list.push(new SongInfo(rid, songName, singer, albumName, dur, pic))
  }
  return new AlbumDetailResult(info, list)
}
