/*
 * Copyright (c) 2026 RzdPai
 *
 * 汽水音乐（source = 'qs'）的**内置**歌词 / 曲目详情（不依赖 LX 脚本，也不需要 App 侧签名）。
 *
 * ★ 依据（外部参考实现 `guowenye/qishui-api` 的 `songDetail()` → `h5SeoTrack()`）：
 *   ```
 *   GET https://beta-luna.douyin.com/luna/h5/seo_track?track_id=<id>&device_platform=web
 *       User-Agent: 浏览器 UA（不是 `Luna/19.1.0 Android`）
 *   200 → {
 *     "lyric":  { "content": "[15971,3799]<0,169,0>如<169,168,0>果…", "type": … },
 *     "seo_track": { "track": { name, duration, artists[], album{name,url_cover} } },
 *     "track_player": { video_model, url_player_info, expire_at }   ← 播放用，需 spade 解密，本轮不接
 *   }
 *   ```
 *
 * ⚠️ **汽水版 QRC 与 QQ 版 QRC 词法不同**，别直接塞给 `amllParseQrc()`：
 *   汽水：`[行起始ms,行时长ms]` + 每词 `<相对偏移ms,词时长ms,标志>字`
 *   QQ  ：`[行起始ms,行时长ms]` + 每词 `字(绝对起始ms,词时长ms)`
 *   我们的解析器只认后者（`AmllLyricFormatParsers.QRC_WORD_PATTERN` = `(.*?)\((\d+),(\d+)\)`），
 *   直接喂汽水原文会解析出 **0 行**（= 看起来"没有歌词"）。所以这里先**归一化**，
 *   输出仍是 QRC —— 保留**逐字**时间轴，比降级成 LRC 更好。
 *
 * 排查关键字：`RzdSoda`（`qsH5SeoTrack` / `qsNormalizeQrc` 各打一行）。
 */
import { http } from '@kit.NetworkKit';

const QS_H5_SEO_TRACK: string = 'https://beta-luna.douyin.com/luna/h5/seo_track';
const QS_TAG: string = '[RzdSoda]';
/** 浏览器 UA：h5/seo_track 只认 Web 侧（用 App 的 `Luna/19.1.0 Android` 会拿不到 lyric）。 */
const QS_H5_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ' +
    'Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json'
};

/** 汽水一首歌的 H5 SEO 详情（只保留我们会用到的那几个字段）。 */
export class QsH5TrackInfo {
  /** 汽水 track id（`songId`）。 */
  trackId: string = '';
  name: string = '';
  /** 多位歌手用 `、` 连接（与汽水 App 内一致）。 */
  singer: string = '';
  album: string = '';
  /** 500×500 封面。 */
  cover: string = '';
  /** 时长（秒）。 */
  durationSec: number = 0;
  /** **已归一化**的 QRC 文本（可直接交给 `amllParseQrc`）；空串 = 这首歌没有歌词。 */
  qrc: string = '';
}

/** 进程内小缓存：`enrichOnlineTrack` 一首歌会跑 2~3 次（loadAsset / resolve / playing），不能每次重下。 */
const QS_H5_CACHE: Map<string, QsH5TrackInfo> = new Map<string, QsH5TrackInfo>();
/** 缓存淘汰顺序（FIFO）。 */
const QS_H5_ORDER: string[] = [];
const QS_H5_CACHE_MAX: number = 12;

function asString(value: Object | undefined): string {
  return typeof value === 'string' ? (value as string) : '';
}

function asNumber(value: Object | undefined): number {
  return typeof value === 'number' ? (value as number) : 0;
}

function asRecord(value: Object | undefined): Record<string, Object> {
  if (value === undefined || value === null || typeof value !== 'object') {
    return {};
  }
  return value as Record<string, Object>;
}

function asArray(value: Object | undefined): Object[] {
  return Array.isArray(value) ? (value as Object[]) : [];
}

/**
 * 汽水版 QRC → **QQ 版 QRC**（我们解析器认的那一份）。
 *
 * 输入一行：`[15971,3799]<0,169,0>如<169,168,0>果<480,297,0>那`
 * 输出一行：`[15971,3799]如(15971,169)果(16140,168)那(16451,297)`
 * （词时间 = 行起始 + 相对偏移；这是汽水的语义，偏移本身可能不连续＝句内有停顿，保留原样）
 * @param raw `lyric.content`
 * @returns 归一化后的 QRC；没有可用行时返回空串。
 */
export function qsNormalizeQrc(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  const lines: string[] = raw.split(/\r?\n/);
  const out: string[] = [];
  let dropped: number = 0;
  for (let i: number = 0; i < lines.length; i++) {
    const line: string = lines[i].trim();
    if (line.length === 0) {
      continue;
    }
    const head: RegExpMatchArray | null = line.match(/^\[(\d+),(\d+)\](.*)$/);
    if (head === null || head.length < 4) {
      dropped++;
      continue;
    }
    const lineStart: number = Number(head[1]);
    const lineDur: number = Number(head[2]);
    const rest: string = head[3];
    let words: string = '';
    const re: RegExp = new RegExp('<([0-9]+),([0-9]+)(?:,[0-9]+)?>([^<]*)', 'g');
    let m: RegExpExecArray | null = re.exec(rest);
    while (m !== null) {
      const offset: number = Number(m[1]);
      const dur: number = Number(m[2]);
      const text: string = m[3];
      if (text.length > 0) {
        words += text + '(' + (lineStart + offset) + ',' + dur + ')';
      }
      m = re.exec(rest);
    }
    if (words.length === 0) {
      dropped++;
      continue;
    }
    out.push('[' + lineStart + ',' + lineDur + ']' + words);
  }
  console.info(QS_TAG + ' qsNormalizeQrc lines=' + out.length + ' dropped=' + dropped +
    ' rawLen=' + raw.length);
  return out.join('\n');
}

/** 兜底的正则（`Map` 命中不到时才有意义）：从 `seo_track.track` 抠字段。 */
function qsCoverFromAlbum(album: Record<string, Object>): string {
  const pic: Record<string, Object> = asRecord(album['url_cover']);
  const uri: string = asString(pic['uri']);
  if (uri.length === 0) {
    return '';
  }
  if (/^https?:\/\//i.test(uri)) {
    return uri;
  }
  const urls: Object[] = asArray(pic['urls']);
  const base: string = urls.length > 0 ? asString(urls[0]) : '';
  if (base.length === 0) {
    return '';
  }
  if (/\.(jpg|jpeg|png|webp)$/i.test(uri)) {
    return base + uri;
  }
  return base + uri + '~c5_500x500.jpg';
}

/**
 * 拉一首歌的 H5 SEO 详情（含歌词）。网络/解析失败返回 `undefined`（歌词是可选能力，不抛）。
 * @param trackId 汽水 track id（= `SongItem.songId`）。
 */
export async function qsH5SeoTrack(trackId: string): Promise<QsH5TrackInfo | undefined> {
  if (trackId.length === 0) {
    return undefined;
  }
  const cached: QsH5TrackInfo | undefined = QS_H5_CACHE.get(trackId);
  if (cached !== undefined) {
    return cached;
  }
  const url: string = QS_H5_SEO_TRACK + '?track_id=' + trackId + '&device_platform=web';
  let text: string = '';
  try {
    const client = http.createHttp();
    try {
      const resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        header: QS_H5_HEADERS,
        connectTimeout: 10000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        console.info(QS_TAG + ' h5/seo_track http=' + resp.responseCode + ' id=' + trackId);
        return undefined;
      }
      text = typeof resp.result === 'string' ? (resp.result as string) : '';
    } finally {
      client.destroy();
    }
  } catch (err) {
    console.info(QS_TAG + ' h5/seo_track failed id=' + trackId + ' err=' + JSON.stringify(err).substring(0, 80));
    return undefined;
  }
  if (text.length === 0) {
    return undefined;
  }
  const info: QsH5TrackInfo = new QsH5TrackInfo();
  info.trackId = trackId;
  try {
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const lyric: Record<string, Object> = asRecord(root['lyric']);
    info.qrc = qsNormalizeQrc(asString(lyric['content']));
    const seo: Record<string, Object> = asRecord(root['seo_track']);
    const track: Record<string, Object> = asRecord(seo['track']);
    info.name = asString(track['name']);
    const artists: Object[] = asArray(track['artists']);
    const names: string[] = [];
    for (let i: number = 0; i < artists.length; i++) {
      const nm: string = asString(asRecord(artists[i])['name']);
      if (nm.length > 0) {
        names.push(nm);
      }
    }
    info.singer = names.join('、');
    const album: Record<string, Object> = asRecord(track['album']);
    info.album = asString(album['name']);
    info.cover = qsCoverFromAlbum(album);
    // `duration` 是毫秒
    info.durationSec = Math.floor(asNumber(track['duration']) / 1000);
  } catch (err) {
    console.info(QS_TAG + ' h5/seo_track parse failed id=' + trackId);
    return undefined;
  }
  console.info(QS_TAG + ' h5/seo_track ok id=' + trackId + ' name=' + info.name +
    ' singer=' + info.singer + ' qrcLines=' + (info.qrc.length > 0 ? info.qrc.split('\n').length : 0) +
    ' cover=' + (info.cover.length > 0 ? 1 : 0));
  if (QS_H5_CACHE.size >= QS_H5_CACHE_MAX && QS_H5_ORDER.length > 0) {
    // FIFO 淘汰（不用迭代器：ArkTS 下更稳）
    const evict: string = QS_H5_ORDER.shift() as string;
    QS_H5_CACHE.delete(evict);
  }
  QS_H5_CACHE.set(trackId, info);
  QS_H5_ORDER.push(trackId);
  return info;
}

/**
 * @returns 已归一化的 QRC 歌词文本（可直接当 `LyricFullResult.main`）；没有则空串。
 */
export async function qsLyricText(trackId: string): Promise<string> {
  const info: QsH5TrackInfo | undefined = await qsH5SeoTrack(trackId);
  return info !== undefined ? info.qrc : '';
}

/**
 * @returns 500×500 封面地址；没有则空串（`lxGetPicFallback` 的 qs 分支用它）。
 */
export async function qsCoverUrl(trackId: string): Promise<string> {
  const info: QsH5TrackInfo | undefined = await qsH5SeoTrack(trackId);
  return info !== undefined ? info.cover : '';
}
