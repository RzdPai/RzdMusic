/**
 * 即将举办的演唱会（Apple Music 私有接口）。
 *
 * 链路（详见《即将举办的演唱会.md》）：
 *   1. 从网页播放器页面抓一个 Bearer token（`iss: AMPWebPlay` 就够）；
 *   2. `search?types=artists` 用歌手名换 Apple artistId；
 *   3. `artists/{id}?views=all-upcoming-concerts` 拿场次 id；
 *   4. `concerts/{id}?include=venues,artists,playlists` 拿场馆/时间。
 *
 * 关键约束：
 *   - 必须带 `Origin: https://music.apple.com`，否则 401；
 *   - 视图名必须是 `all-upcoming-concerts`（带连字符，ArkTS 不能点访问，统一走 Record 读）；
 *   - `cn` 区没有这个视图 → 用 `hk`；拿不到就返回空数组，UI 据此隐藏入口（优雅降级）。
 *
 * 日志关键字：`RzdConcert`
 */
import { http } from '@kit.NetworkKit';

/** 单场演唱会。 */
export interface ConcertItem {
  id: string;
  /** 演出标题；接口常给 null，这里已用「歌手 · 场馆」兜底 */
  title: string;
  /** ISO 8601 UTC 起始时间 */
  startISO: string;
  /** 场馆时区，如 Australia/Sydney */
  timezone: string;
  venueName: string;
  city: string;
  /** 展示用日期，如 11月21日 20:30 */
  whenText: string;
  /** Apple Music 页面（票务信息缺失时的落点） */
  url: string;
}

const HOST: string = 'https://amp-api.music.apple.com';
const WEB_HOST: string = 'https://music.apple.com';
const STOREFRONT: string = 'hk';
const VIEW_KEY: string = 'all-upcoming-concerts';
const UA: string = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/** 通用 JSON 读取：ArkTS 禁止 obj['key']，统一走 Record。 */
function readKey(source: Object | undefined, key: string): Object | undefined {
  if (source === undefined) {
    return undefined;
  }
  const rec: Record<string, Object> = source as Object as Record<string, Object>;
  return rec[key];
}

function readString(source: Object | undefined, key: string): string {
  const v: Object | undefined = readKey(source, key);
  return typeof v === 'string' ? (v as string) : '';
}

function readArray(source: Object | undefined, key: string): Object[] {
  const v: Object | undefined = readKey(source, key);
  return Array.isArray(v) ? (v as Object[]) : [];
}

/** 该歌手即将举办的演唱会列表；失败一律返回空数组。 */
export class ConcertService {
  private static instance: ConcertService | undefined = undefined;
  private token: string = '';
  private cache: Map<string, ConcertItem[]> = new Map<string, ConcertItem[]>();

  public static getInstance(): ConcertService {
    if (ConcertService.instance === undefined) {
      ConcertService.instance = new ConcertService();
    }
    return ConcertService.instance;
  }

  /** 已缓存的结果（undefined = 还没查过）。 */
  public peek(artistName: string): ConcertItem[] | undefined {
    return this.cache.get(artistName);
  }

  public async upcoming(artistName: string): Promise<ConcertItem[]> {
    const cached: ConcertItem[] | undefined = this.cache.get(artistName);
    if (cached !== undefined) {
      return cached;
    }
    const name: string = artistName.trim();
    if (name.length === 0) {
      return [];
    }
    let out: ConcertItem[] = [];
    try {
      await this.ensureToken();
      if (this.token.length === 0) {
        console.info('[RzdConcert] no token, skip');
        this.cache.set(artistName, []);
        return [];
      }
      const artistId: string = await this.findArtistId(name);
      if (artistId.length === 0) {
        console.info('[RzdConcert] artist not found: ' + name);
        this.cache.set(artistName, []);
        return [];
      }
      out = await this.listConcerts(artistId, name);
      console.info('[RzdConcert] artist=' + name + ' id=' + artistId + ' count=' + out.length);
    } catch (error) {
      console.info('[RzdConcert] failed: ' + JSON.stringify(error).substring(0, 120));
      out = [];
    }
    this.cache.set(artistName, out);
    return out;
  }

  /** 从网页播放器页面抓 Bearer token（JWT）。 */
  private async ensureToken(): Promise<void> {
    if (this.token.length > 0) {
      return;
    }
    const html: string = await this.getText(WEB_HOST + '/' + STOREFRONT + '/browse', '');
    if (html.length === 0) {
      return;
    }
    const match: RegExpMatchArray | null =
      html.match(/eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}/);
    if (match !== null && match.length > 0) {
      this.token = match[0];
      console.info('[RzdConcert] token len=' + this.token.length);
    } else {
      console.info('[RzdConcert] token not found');
    }
  }

  private async findArtistId(artistName: string): Promise<string> {
    const path: string = '/v1/catalog/' + STOREFRONT + '/search?term=' +
      encodeURIComponent(artistName) + '&types=artists&limit=1';
    const text: string = await this.getText(HOST + path, this.token);
    if (text.length === 0) {
      return '';
    }
    const root: Object = JSON.parse(text) as Object;
    const results: Object | undefined = readKey(root, 'results');
    const artists: Object | undefined = readKey(results, 'artists');
    const data: Object[] = readArray(artists, 'data');
    if (data.length === 0) {
      return '';
    }
    return readString(data[0], 'id');
  }

  private async listConcerts(artistId: string, artistName: string): Promise<ConcertItem[]> {
    const path: string = '/v1/catalog/' + STOREFRONT + '/artists/' + artistId +
      '?views=' + VIEW_KEY + '&limit[artists:' + VIEW_KEY + ']=10';
    const text: string = await this.getText(HOST + path, this.token);
    if (text.length === 0) {
      return [];
    }
    const root: Object = JSON.parse(text) as Object;
    const data: Object[] = readArray(root, 'data');
    if (data.length === 0) {
      return [];
    }
    const views: Object | undefined = readKey(data[0], 'views');
    const view: Object | undefined = readKey(views, VIEW_KEY);
    if (view === undefined) {
      // cn 区就是这里为空：根本没有该视图
      return [];
    }
    const items: Object[] = readArray(view, 'data');
    const out: ConcertItem[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const concertId: string = readString(items[i], 'id');
      if (concertId.length === 0) {
        continue;
      }
      const detail: ConcertItem | undefined = await this.concertDetail(concertId, artistName);
      if (detail !== undefined) {
        out.push(detail);
      }
    }
    out.sort((a: ConcertItem, b: ConcertItem): number => a.startISO.localeCompare(b.startISO));
    return out;
  }

  private async concertDetail(concertId: string, artistName: string): Promise<ConcertItem | undefined> {
    const path: string = '/v1/catalog/' + STOREFRONT + '/concerts/' + concertId +
      '?include=venues,artists,playlists';
    const text: string = await this.getText(HOST + path, this.token);
    if (text.length === 0) {
      return undefined;
    }
    const root: Object = JSON.parse(text) as Object;
    const data: Object[] = readArray(root, 'data');
    if (data.length === 0) {
      return undefined;
    }
    const concert: Object = data[0];
    const attrs: Object | undefined = readKey(concert, 'attributes');
    const rels: Object | undefined = readKey(concert, 'relationships');
    const venues: Object | undefined = readKey(rels, 'venues');
    const venueList: Object[] = readArray(venues, 'data');
    let venueName: string = '';
    let city: string = '';
    if (venueList.length > 0) {
      const va: Object | undefined = readKey(venueList[0], 'attributes');
      venueName = readString(va, 'name');
      const addr: Object | undefined = readKey(va, 'structuredAddress');
      city = readString(addr, 'city');
    }
    const startISO: string = readString(attrs, 'startISODateTime');
    const timezone: string = readString(attrs, 'timezone');
    let title: string = readString(attrs, 'name');
    if (title.length === 0) {
      title = venueName.length > 0 ? (artistName + ' · ' + venueName) : artistName;
    }
    return {
      id: concertId,
      title: title,
      startISO: startISO,
      timezone: timezone,
      venueName: venueName,
      city: city,
      whenText: formatWhen(startISO, timezone),
      url: readString(attrs, 'url')
    };
  }

  private async getText(url: string, token: string): Promise<string> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {
        'User-Agent': UA,
        'Origin': WEB_HOST
      };
      if (token.length > 0) {
        header['Authorization'] = 'Bearer ' + token;
      }
      const res: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 20000
      });
      if (res.responseCode !== 200) {
        console.info('[RzdConcert] http=' + res.responseCode + ' ' + url.substring(0, 70));
        return '';
      }
      return typeof res.result === 'string' ? (res.result as string) : '';
    } catch (error) {
      console.info('[RzdConcert] request error: ' + JSON.stringify(error).substring(0, 100));
      return '';
    } finally {
      req.destroy();
    }
  }
}

/** ISO(UTC) + 场馆时区 → 「11月21日 20:30」。 */
export function formatWhen(startISO: string, timezone: string): string {
  if (startISO.length === 0) {
    return '';
  }
  const d: Date = new Date(startISO);
  if (isNaN(d.getTime())) {
    return '';
  }
  let month: number = d.getUTCMonth() + 1;
  let day: number = d.getUTCDate();
  let hour: number = d.getUTCHours();
  let minute: number = d.getUTCMinutes();
  if (timezone.length > 0) {
    try {
      const fmt: Intl.DateTimeFormat = new Intl.DateTimeFormat('en-US', {
        timeZone: timezone,
        month: 'numeric',
        day: 'numeric',
        hour: 'numeric',
        minute: 'numeric',
        hour12: false
      });
      const nums: string[] = fmt.format(d).split(/[^0-9]+/)
        .filter((v: string): boolean => v.length > 0);
      if (nums.length >= 4) {
        month = Number(nums[0]);
        day = Number(nums[1]);
        hour = Number(nums[2]);
        minute = Number(nums[3]);
      }
    } catch (error) {
      console.info('[RzdConcert] tz fallback: ' + timezone);
    }
  }
  const hh: string = hour < 10 ? ('0' + hour) : hour.toString();
  const mm: string = minute < 10 ? ('0' + minute) : minute.toString();
  return month + '月' + day + '日 ' + hh + ':' + mm;
}
