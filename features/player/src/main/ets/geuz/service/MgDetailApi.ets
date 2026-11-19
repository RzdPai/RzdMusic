import { appendPlayLog } from 'musicbasic'
import { ArtistInfo } from '../model/SearchModels'
import { SongInfo } from '../model/SearchModels'
import { SongPageResult } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { ArtistAlbumPageResult } from '../model/SearchModels'
import { AlbumDetailResult } from '../model/SearchModels'
import { httpGetJson, MG_UA } from './HttpUtils'

interface MgBaseResponse {
  code: string
  data: Object | undefined
}

interface MgContentBlock {
  view: string | undefined
  contents: MgContentBlock[] | undefined
  songItem: MgSongItem | undefined
  txt2: string | undefined
  resId: string | undefined
  img: string | undefined
  txt: string | undefined
  txt3: string | undefined
}

interface MgSongItem {
  songName: string | undefined
  contentId: string | undefined
  duration: number | undefined
  album: string | undefined
  singerList: MgSongSinger[] | undefined
  img1: string | undefined
  img2: string | undefined
  img3: string | undefined
}

interface MgSongSinger {
  name: string | undefined
}

interface MgContentData {
  header: Object | undefined
  contents: MgContentBlock[] | undefined
  /** 搜索类接口的条目（`bmw/search/*`），与 `contents` 不同形状。 */
  items: Object[] | undefined
  hasNext: boolean | undefined
}

interface MgAlbumInfoResponse {
  code: string
  data: MgAlbumInfoData | undefined
}

interface MgAlbumInfoData {
  title: string | undefined
  singer: string | undefined
  singerId: string | undefined
  publishDate: string | undefined
  totalCount: number | undefined
  imgItem: MgImg[] | undefined
}

interface MgImg {
  img: string | undefined
  imgSizeType: string | undefined
}

function pickLargeImg(imgs: MgImg[]): string {
  if (imgs.length === 0) return ''
  for (let i = 0; i < imgs.length; i++) {
    if (imgs[i].imgSizeType === '03') {
      return imgs[i].img ?? ''
    }
  }
  return imgs[imgs.length - 1].img ?? ''
}

function mgCover(img1: string | undefined, img2: string | undefined, img3: string | undefined): string {
  let img = img3 ?? ''
  if (img.length === 0) {
    img = img2 ?? ''
  }
  if (img.length === 0) {
    img = img1 ?? ''
  }
  if (img.startsWith('/')) {
    img = 'https://d.musicapp.migu.cn' + img
  }
  return img.replace('http://', 'https://')
}

interface MgAlbumSongResponse {
  code: string
  data: MgAlbumSongData | undefined
}

interface MgAlbumSongData {
  songList: MgSongItem[] | undefined
  totalCount: number | undefined
}

interface MgSingerIndexResponse {
  code: string
  data: MgSingerIndexData | undefined
}

interface MgSingerIndexData {
  contents: MgContentBlock[] | undefined
}

function findDesc(contents: MgContentBlock[] | undefined): string {
  if (contents === undefined) return ''
  for (let i = 0; i < contents.length; i++) {
    let block = contents[i]
    if (block.view === 'ZJ-Singer-Intro-Scroll') {
      let inner = block.contents ?? []
      for (let j = 0; j < inner.length; j++) {
        if (inner[j].view === 'ZJ-Singer-Intro-Item') {
          return inner[j].txt2 ?? ''
        }
      }
    }
  }
  return ''
}

/**
 * 从咪咕模板里取歌曲条目。
 *
 * ★★★ 2026-11-19（用户：「咪咕列表中能显示有多少首歌曲，但是打开后里面一首歌都没显示」）：
 *   原来**只认 `view === 'ZJ-Singer-Song-Scroll'` 这一个模板名** —— 咪咕这类模板名会变
 *   （A/B 下发、版本升级），名字对不上就一条都取不到，而歌手页上"有多少首"来自搜索接口的
 *   `songNum` ⇒ 表现成"有数量、点进去空的"。
 *   ⇒ 改成两级：先按已知模板名取；**取不到就兜底扫所有层级的 `songItem`**（宁多勿漏，
 *   条目本身带 `songName`，不会把无关东西带进来）。
 */
function findSongItems(contents: MgContentBlock[] | undefined): MgSongItem[] {
  let list: MgSongItem[] = []
  if (contents === undefined) return list
  const KNOWN_VIEWS: string[] = ['ZJ-Singer-Song-Scroll', 'ZJ-Singer-Song-List', 'ZJ-Singer-Song'];
  for (let i = 0; i < contents.length; i++) {
    let block = contents[i]
    if (block.view === undefined || KNOWN_VIEWS.indexOf(block.view) < 0) continue
    let inner = block.contents ?? []
    for (let j = 0; j < inner.length; j++) {
      let item = inner[j].songItem
      if (item !== undefined && (item.songName ?? '').length > 0) {
        list.push(item)
      }
    }
  }
  if (list.length > 0) return list
  // 兜底：模板名变了 —— 递归扫所有 block，抓到任何 `songItem` 就算
  return collectSongItemsDeep(contents)
}

/** 递归收集所有 `songItem`（只在按模板名取不到时才用）。 */
function collectSongItemsDeep(blocks: MgContentBlock[] | undefined): MgSongItem[] {
  let list: MgSongItem[] = []
  if (blocks === undefined) return list
  for (let i = 0; i < blocks.length; i++) {
    let block = blocks[i]
    let item = block.songItem
    if (item !== undefined && (item.songName ?? '').length > 0) {
      list.push(item)
    }
    let inner: MgContentBlock[] | undefined = block.contents
    if (inner !== undefined && inner.length > 0) {
      let sub = collectSongItemsDeep(inner)
      for (let k = 0; k < sub.length; k++) {
        list.push(sub[k])
      }
    }
  }
  return list
}

function mapMgSongs(rawList: MgSongItem[]): SongInfo[] {
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let albumName = item.album ?? ''
    let author = ''
    if (item.singerList !== undefined && item.singerList.length > 0) {
      author = item.singerList[0].name ?? ''
    }
    let interval = item.duration ?? 0
    let pic = mgCover(item.img1, item.img2, item.img3)
    list.push(new SongInfo(item.contentId ?? String(i), item.songName ?? '', author, albumName, interval, pic))
  }
  return list
}

export async function getArtistDetail(singerId: string): Promise<ArtistInfo> {
  let url = 'https://app.c.nf.migu.cn/bmw/singer/index/v1.0?singerId=' + singerId
  let raw = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgSingerIndexResponse
  if (raw.code !== '000000') throw new Error('获取歌手信息失败')
  let data = raw.data
  if (data === undefined) throw new Error('获取歌手信息失败')
  let desc = findDesc(data.contents)
  return new ArtistInfo(singerId, '', '', '', '', 0, 0, desc)
}

export async function getArtistSongs(singerId: string, order: string, limit: number, offset: number): Promise<SongPageResult> {
  const page: number = limit > 0 ? Math.floor(offset / limit) + 1 : 1
  // ★★★ 2026-11-19（用户："咪咕列表能显示有多少首歌曲，但打开后一首歌都没显示"）：
  //   本机实测（`curl` 同一个接口）：`bmw/singer/song/v1.0` 对**有效的 singerId** 返回的是
  //   `contents[0].view = "ZJ-Singer-Song-Scroll"`、`contents[0].contents[j].songItem` ——
  //   与我们原来的解析**结构一致**。所以问题大概率落在"拿到的 singerId 不对 / 这一档参数被拒"。
  //   这里做三件事，并**把每一档的读数写进应用内运行日志**（关键字 `RzdMgArtist`）：
  //     ① 先按 `type=1` 请求；② 空则去掉 `type` 再请求；③ 仍空则带 `pageSize` 再请求。
  //   哪一档开始有数据，日志会直接告诉我们。
  const urls: string[] = [];
  urls.push('https://app.c.nf.migu.cn/bmw/singer/song/v1.0?pageNo=' + page + '&singerId=' +
    encodeURIComponent(singerId) + '&type=1');
  urls.push('https://app.c.nf.migu.cn/bmw/singer/song/v1.0?pageNo=' + page + '&singerId=' +
    encodeURIComponent(singerId));
  urls.push('https://app.c.nf.migu.cn/bmw/singer/song/v1.0?pageNo=' + page + '&pageSize=' + limit +
    '&singerId=' + encodeURIComponent(singerId) + '&type=1');
  let lastCode: string = '';
  for (let i: number = 0; i < urls.length; i++) {
    try {
      const raw: MgBaseResponse = await httpGetJson(urls[i], { 'User-Agent': MG_UA }) as MgBaseResponse;
      lastCode = String(raw.code);
      const contentData = raw.data as MgContentData;
      const blocks: number = contentData !== undefined && contentData.contents !== undefined
        ? contentData.contents.length : -1;
      const items = findSongItems(contentData !== undefined ? contentData.contents : undefined);
      const list = mapMgSongs(items);
      appendPlayLog('[RzdMgArtist] try' + (i + 1) + ' singer=' + singerId + ' code=' + lastCode +
        ' blocks=' + blocks + ' songs=' + list.length);
      if (list.length > 0) {
        return new SongPageResult(list, list.length, list.length >= limit);
      }
    } catch (err) {
      appendPlayLog('[RzdMgArtist] try' + (i + 1) + ' singer=' + singerId + ' 抛异常: ' +
        JSON.stringify(err).substring(0, 100));
    }
  }
  appendPlayLog('[RzdMgArtist] 三档都空 singer=' + singerId + ' code=' + lastCode);
  return new SongPageResult([], 0, false);
}

/**
 * **按歌手名搜歌**（咪咕歌手页的兜底）。
 *
 * 为什么需要：`bmw/singer/song/v1.0` 在部分 `singerId` 下会返回 `code:000000` 但 `contents` 为空
 * （本机实测：有效 id `953012` 有 30 首，另一个 id 就是空），而**搜索接口一直可用**。
 * ⇒ 歌手页拿不到歌时，用"按名字搜"补齐，并按 `singerList` 过滤只留这位歌手的歌。
 * @param artistName 歌手名
 * @param limit 每页条数
 * @param offset 偏移
 */
export async function getArtistSongsByName(artistName: string, limit: number,
  offset: number): Promise<SongPageResult> {
  const name: string = artistName.trim();
  if (name.length === 0) {
    return new SongPageResult([], 0, false);
  }
  const page: number = limit > 0 ? Math.floor(offset / limit) + 1 : 1;
  const url: string = 'https://app.c.nf.migu.cn/bmw/search/song/v1.0?pageNo=' + page +
    '&text=' + encodeURIComponent(name);
  try {
    const raw: MgBaseResponse = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgBaseResponse;
    const data = raw.data as MgContentData;
    const rows: Record<string, Object>[] = data !== undefined && data.items !== undefined
      ? data.items as Record<string, Object>[] : [];
    const out: SongInfo[] = [];
    for (let i: number = 0; i < rows.length && out.length < limit; i++) {
      const item = rows[i]['song'] as Record<string, Object> | undefined;
      if (item === undefined || item === null) {
        continue;
      }
      const singers = item['singerList'] as Record<string, Object>[] | undefined;
      let singerHit: boolean = false;
      let singerLine: string = '';
      if (singers !== undefined) {
        for (let k: number = 0; k < singers.length; k++) {
          const sn: string = String(singers[k]['name'] ?? '');
          if (sn.length === 0) {
            continue;
          }
          singerLine = singerLine.length === 0 ? sn : (singerLine + '/' + sn);
          if (sn === name || sn.indexOf(name) >= 0 || name.indexOf(sn) >= 0) {
            singerHit = true;
          }
        }
      }
      if (!singerHit) {
        continue;
      }
      const id: string = String(item['contentId'] ?? '');
      const songName: string = String(item['songName'] ?? '');
      if (id.length === 0 || songName.length === 0) {
        continue;
      }
      const album: string = String(item['album'] ?? '');
      const dur: number = Number(item['duration'] ?? 0);
      const img1: string = String(item['img1'] ?? item['img2'] ?? '');
      const pic: string = img1.length > 0 && img1.startsWith('/')
        ? 'https://d.musicapp.migu.cn' + img1 : img1;
      out.push(new SongInfo(id, songName, singerLine, album, dur, pic));
    }
    appendPlayLog('[RzdMgArtist] byName name=' + name + ' rows=' + rows.length + ' songs=' + out.length);
    return new SongPageResult(out, out.length, out.length >= limit);
  } catch (err) {
    appendPlayLog('[RzdMgArtist] byName 抛异常 name=' + name + ' ' +
      JSON.stringify(err).substring(0, 100));
    return new SongPageResult([], 0, false);
  }
}

async function getMgAlbumCount(id: string, retryNum: number = 0): Promise<number> {
  if (retryNum > 2 || id.length === 0) return 0
  try {
    let raw = await httpGetJson('https://app.c.nf.migu.cn/MIGUM3.0/resource/dalbum/v2.0?dAlbumId=' + id, { 'User-Agent': MG_UA }) as MgAlbumInfoResponse
    if (raw.code === '000000' && raw.data !== undefined) {
      let total = raw.data.totalCount ?? 0
      if (total > 0) return total
    }
    let raw2 = await httpGetJson('https://app.c.nf.migu.cn/MIGUM3.0/resource/album/song/v2.0?albumId=' + id + '&pageNo=1', { 'User-Agent': MG_UA }) as MgAlbumSongResponse
    if (raw2.code === '000000' && raw2.data !== undefined) {
      let total = raw2.data.totalCount ?? 0
      if (total > 0) return total
    }
    return getMgAlbumCount(id, retryNum + 1)
  } catch (e) {
    return getMgAlbumCount(id, retryNum + 1)
  }
}

export async function getArtistAlbums(singerId: string, limit: number, offset: number): Promise<ArtistAlbumPageResult> {
  let page = Math.floor(offset / limit) + 1
  let url = 'https://app.c.nf.migu.cn/bmw/singer/album/v1.0?singerId=' + singerId + '&pageNo=' + page
  let raw = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgBaseResponse
  if (raw.code !== '000000') throw new Error('获取歌手专辑列表失败')
  let contentData = raw.data as MgContentData
  let list: AlbumInfo[] = []
  let blocks = contentData.contents ?? []
  for (let i = 0; i < blocks.length; i++) {
    let item = blocks[i]
    let id = item.resId ?? ''
    if (id.length === 0) continue
    let picUrl = (item.img ?? '').replace('http://', 'https://')
    list.push(new AlbumInfo(id, '', item.txt ?? '', picUrl, 0, item.txt2 ?? '', 0, item.txt3 ?? ''))
  }
  let hasMore = false
  if (contentData.header !== undefined) {
    let hdr = contentData.header as Record<string, Object>
    let nextUrl = hdr['nextPageUrl'] as string
    if (nextUrl !== undefined && nextUrl.length > 0) {
      hasMore = true
    }
  }
  if (list.length > 0) {
    let toFetch = list.length > 30 ? list.slice(0, 30) : list
    let promises: Promise<number>[] = []
    for (let i = 0; i < toFetch.length; i++) {
      promises.push(getMgAlbumCount(toFetch[i].id))
    }
    let counts = await Promise.all(promises)
    for (let i = 0; i < toFetch.length; i++) {
      toFetch[i].size = counts[i]
    }
  }
  return new ArtistAlbumPageResult(list, hasMore)
}

export async function getAlbum(albumId: string): Promise<AlbumDetailResult> {
  let infoUrl = 'https://app.c.nf.migu.cn/MIGUM3.0/resource/dalbum/v2.0?dAlbumId=' + albumId
  let infoRaw = await httpGetJson(infoUrl, { 'User-Agent': MG_UA }) as MgAlbumInfoResponse
  if (infoRaw.code !== '000000') throw new Error('获取专辑信息失败')
  let infoData = infoRaw.data
  let name = ''
  let picUrl = ''
  let authorName = ''
  let publishDate = ''
  let total = 0
  if (infoData !== undefined) {
    name = infoData.title ?? ''
    let imgs = infoData.imgItem ?? []
    if (imgs.length > 0) {
      picUrl = pickLargeImg(imgs).replace('http://', 'https://')
    }
    authorName = infoData.singer ?? ''
    publishDate = infoData.publishDate ?? ''
    total = infoData.totalCount ?? 0
  }

  let songUrl = 'https://app.c.nf.migu.cn/MIGUM3.0/resource/dalbum/song/v2.0?dAlbumId=' + albumId
  let songRaw = await httpGetJson(songUrl, { 'User-Agent': MG_UA }) as MgAlbumSongResponse
  if (songRaw.code !== '000000') throw new Error('获取专辑歌曲失败')
  let songData = songRaw.data
  let list = songData !== undefined ? mapMgSongs(songData.songList ?? []) : []
  if (picUrl.length > 0) {
    for (let i = 0; i < list.length; i++) {
      if (list[i].picUrl.length === 0) {
        list[i].picUrl = picUrl
      }
    }
  }
  let size = total > 0 ? total : list.length
  let info = new AlbumInfo(albumId, '', name, picUrl, 0, authorName, size, publishDate)
  return new AlbumDetailResult(info, list)
}