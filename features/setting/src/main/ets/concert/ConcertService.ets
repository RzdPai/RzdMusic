/**
 * 即将举办的演唱会（Apple Music 私有接口）。
 *
 * ★ token 是**自动获取**的，不需要用户粘贴：
 *   HTML（`music.apple.com/{cc}/browse`）里没有 token，但页面引用了
 *   `/assets/index~xxxxxxxx.js`（约 3.3MB），那个 bundle 里内联着一枚
 *   `eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IldlYlBsYXlLaWQifQ…`
 *   （payload `{"iss":"AMPWebPlay", …}`，有效期约 70 天）。
 *   抓取成本：冷启动约 5.4MB / 2~4 秒，抓到后写偏好，7 天内不再抓。
 *
 * ★ 两条路对 `Origin` 的要求**相反**（踩过坑）：
 *   - 抓 `music.apple.com` 页面 / JS：**绝对不能带 Origin**（带了 403）
 *   - 调 `amp-api.music.apple.com`：**必须带** `Origin: https://music.apple.com`（不带 401）
 *
 * ★ 其它硬约束：
 *   - 视图名必须是 `all-upcoming-concerts`（带连字符，ArkTS 不能点访问 → 走 Record）；
 *   - `cn` 区不是"空数组"，而是**根本没有 `views` 字段** → 判 `view === undefined`；
 *   - storefront 自动回退：`hk` → `us` → `gb`，哪个先拿到数据用哪个；
 *   - 列表是精简对象（只有 id + 时间），场馆必须再查 `?include=venues,artists,playlists`；
 *   - `name` 常为 null → UI 层用「艺人 · 场馆」兜底。
 *
 * 日志关键字：`RzdConcert`
 */
import { http } from '@kit.NetworkKit';
import { MusicStoreService } from 'musicbasic';

/** 单场演唱会。 */
export interface ConcertItem {
  id: string;
  /** 演出标题；接口常给 null，这里已用「艺人 · 场馆」兜底 */
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
  /** 这条数据来自哪个 storefront（hk/us/gb） */
  storefront: string;
}

const HOST: string = 'https://amp-api.music.apple.com';
const WEB_HOST: string = 'https://music.apple.com';
const VIEW_KEY: string = 'all-upcoming-concerts';
const STOREFRONTS: string[] = ['hk', 'us', 'gb'];
/** token 复用窗口：6 天（官方有效期约 70 天，保守起见 6 天重抓一次） */
const TOKEN_TTL_MS: number = 6 * 24 * 60 * 60 * 1000;
const UA: string = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const JWT_PATTERN: RegExp = /eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}/;
const JS_PATTERN: RegExp = /\/assets\/[A-Za-z0-9_~.\-]+\.js/;

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

/** 该歌手即将举办的演唱会列表；失败一律返回空数组（UI 据此隐藏入口）。 */
export class ConcertService {
  private static instance: ConcertService | undefined = undefined;
  private token: string = '';
  private cache: Map<string, ConcertItem[]> = new Map<string, ConcertItem[]>();
  /** 解析得到的 storefront（拿到数据后固定，减少后续请求） */
  private hitStorefront: string = '';

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

  /** 手动覆盖 token（自动抓取失败时的兜底）。 */
  public setTokenOverride(token: string): void {
    this.token = token.trim();
    if (this.token.length > 0) {
      MusicStoreService.getInstance().setConcertToken(this.token);
      console.info('[RzdConcert] token override len=' + this.token.length);
    }
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
        console.info('[RzdConcert] no token, skip: ' + name);
        this.cache.set(artistName, []);
        return [];
      }
      // 先用已知命中的 storefront，再按 hk → us → gb 依次尝试
      const order: string[] = this.storefrontOrder();
      for (let i: number = 0; i < order.length; i++) {
        const storefront: string = order[i];
        out = await this.queryStorefront(name, storefront);
        if (out.length > 0) {
          this.hitStorefront = storefront;
          console.info('[RzdConcert] hit storefront=' + storefront + ' artist=' + name +
            ' count=' + out.length);
          break;
        }
      }
      if (out.length === 0) {
        console.info('[RzdConcert] no concerts artist=' + name);
      }
    } catch (error) {
      console.info('[RzdConcert] failed: ' + JSON.stringify(error).substring(0, 120));
      out = [];
    }
    // ★ 只缓存**有数据**的结果：空结果可能是 token 过期/网络抖动造成的，缓存会让该歌手永久显示"没有场次"
    if (out.length > 0) {
      this.cache.set(artistName, out);
    }
    return out;
  }

  private storefrontOrder(): string[] {
    const order: string[] = [];
    if (this.hitStorefront.length > 0) {
      order.push(this.hitStorefront);
    }
    for (let i: number = 0; i < STOREFRONTS.length; i++) {
      if (STOREFRONTS[i] !== this.hitStorefront) {
        order.push(STOREFRONTS[i]);
      }
    }
    return order;
  }

  private async queryStorefront(artistName: string, storefront: string): Promise<ConcertItem[]> {
    const artistId: string = await this.findArtistId(artistName, storefront);
    if (artistId.length === 0) {
      return [];
    }
    return await this.listConcerts(artistId, artistName, storefront);
  }

  /**
   * 取 token：先读偏好（6 天内有效），否则抓 HTML → JS bundle → JWT。
   * 抓取失败不影响调用方（返回后 token 为空则整块隐藏）。
   */
  private async ensureToken(): Promise<void> {
    if (this.token.length > 0) {
      return;
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    const saved: string = store.getConcertToken();
    const savedAt: number = store.getConcertTokenAt();
    if (saved.length > 0 && Date.now() - savedAt < TOKEN_TTL_MS) {
      this.token = saved;
      console.info('[RzdConcert] token from prefs len=' + saved.length);
      return;
    }
    // ① 抓 HTML（不带 Origin！）
    const html: string = await this.getText(WEB_HOST + '/hk/browse', '', false);
    if (html.length === 0) {
      return;
    }
    const jsHits: RegExpMatchArray | null = html.match(JS_PATTERN);
    if (jsHits === null || jsHits.length === 0) {
      console.info('[RzdConcert] js bundle not found in html');
      return;
    }
    const jsPath: string = jsHits[0];
    // ② HTML 里可能已经内联了 token（少数页面会），先试一次
    const inline: RegExpMatchArray | null = html.match(JWT_PATTERN);
    if (inline !== null && inline.length > 0) {
      this.adoptToken(inline[0], 'html');
      return;
    }
    // ③ 抓 JS bundle（同样不带 Origin）
    const js: string = await this.getText(WEB_HOST + jsPath, '', false);
    if (js.length === 0) {
      return;
    }
    const hit: RegExpMatchArray | null = js.match(JWT_PATTERN);
    if (hit !== null && hit.length > 0) {
      this.adoptToken(hit[0], jsPath);
      return;
    }
    console.info('[RzdConcert] token not found in ' + jsPath + ' (' + js.length + ' bytes)');
  }

  private adoptToken(token: string, source: string): void {
    this.token = token;
    MusicStoreService.getInstance().setConcertToken(token);
    console.info('[RzdConcert] token acquired from ' + source + ' len=' + token.length);
  }

  private async findArtistId(artistName: string, storefront: string): Promise<string> {
    const path: string = '/v1/catalog/' + storefront + '/search?term=' +
      encodeURIComponent(artistName) + '&types=artists&limit=1';
    // amp-api：必须带 Origin
    const text: string = await this.getText(HOST + path, this.token, true);
    if (text.length === 0) {
      return '';
    }
    const root: Object = JSON.parse(text) as Object;
    const data: Object[] = readArray(readKey(readKey(root, 'results'), 'artists'), 'data');
    if (data.length === 0) {
      return '';
    }
    return readString(data[0], 'id');
  }

  private async listConcerts(artistId: string, artistName: string,
    storefront: string): Promise<ConcertItem[]> {
    const path: string = '/v1/catalog/' + storefront + '/artists/' + artistId +
      '?views=' + VIEW_KEY + '&limit[artists:' + VIEW_KEY + ']=10';
    const text: string = await this.getText(HOST + path, this.token, true);
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
      // cn 区就是这里 undefined：没有该视图（不是空数组）
      return [];
    }
    const items: Object[] = readArray(view, 'data');
    const out: ConcertItem[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const concertId: string = readString(items[i], 'id');
      if (concertId.length === 0) {
        continue;
      }
      const detail: ConcertItem | undefined =
        await this.concertDetail(concertId, artistName, storefront);
      if (detail !== undefined) {
        out.push(detail);
      }
    }
    out.sort((a: ConcertItem, b: ConcertItem): number => a.startISO.localeCompare(b.startISO));
    return out;
  }

  private async concertDetail(concertId: string, artistName: string,
    storefront: string): Promise<ConcertItem | undefined> {
    const path: string = '/v1/catalog/' + storefront + '/concerts/' + concertId +
      '?include=venues,artists,playlists';
    const text: string = await this.getText(HOST + path, this.token, true);
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
    const venueList: Object[] = readArray(readKey(rels, 'venues'), 'data');
    let venueName: string = '';
    let city: string = '';
    if (venueList.length > 0) {
      const va: Object | undefined = readKey(venueList[0], 'attributes');
      venueName = readString(va, 'name');
      city = readString(readKey(va, 'structuredAddress'), 'city');
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
      url: readString(attrs, 'url'),
      storefront: storefront
    };
  }

  /**
   * 统一的 GET。
   * @param withOrigin true = 调 amp-api（必须带 Origin）；false = 抓网页/JS（绝不能带）
   */
  private async getText(url: string, token: string, withOrigin: boolean): Promise<string> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {
        'User-Agent': UA,
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
      };
      if (withOrigin) {
        header['Origin'] = WEB_HOST;
        if (token.length > 0) {
          header['Authorization'] = 'Bearer ' + token;
        }
      }
      const res: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (res.responseCode !== 200) {
        console.info('[RzdConcert] http=' + res.responseCode + ' origin=' + withOrigin +
          ' ' + url.substring(0, 70));
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
