/*
 * Copyright (c) 2026 RzdPai
 *
 * 汽水音乐（source = 'qs'）的**免登录** H5 SEO 客户端：歌词（逐字 KRC）+ 封面 + 曲目信息 + 评论。
 *
 * ★ 为什么放在 `common/musicbasic`：`features/comment`（评论面板）与 `features/player`（播放链路）
 *   都要用它，而 features **不允许互相依赖**（架构约束 products → features → common）。
 *
 * ============================ 接口事实（都实测过，别再猜） ============================
 * ```
 * GET https://beta-luna.douyin.com/luna/h5/seo_track?track_id=<id>&device_platform=web
 *      User-Agent: 浏览器 UA（不带也行；失败会再裸试一次）
 * 200 → {
 *   "status_info": { log_id, now, status_msg? },      ← 失败时**只有** status_msg，没有其它节点
 *   "lyric": { type: "krc"|"lrc", content: "...", hide_request_lyrics: false },
 *   "seo_track": { track: { name, duration(ms), artists[], album{name,url_cover},
 *                           chorus, lang_codes } },
 *   "comments": { count: 63143,                        ← **总数**（不是本次给的条数）
 *                 comments: [ 5 条热门/精选 ] },       ← 免登录只给前 5 条，且**不带回复**
 *   "track_player": { video_model, … }                 ← 播放用，需 spade 解密，本文件不用
 * }
 * ```
 * · 该接口是给**站外分享页 / 搜索引擎爬虫**用的 SEO 口子，按设计不校验登录；
 * · 实测 `luna/lyric`、`luna/track/lyric`、`luna/app/lyric` 全 404；
 *   `luna/comments` 返回 `200 + Content-Length: 0`（要登录态）⇒ **评论只能走这里的 `comments` 节点**；
 * · 无效 id 也是 200（`status_info.status_msg` 非空、无 `seo_track`）⇒ 判失败且**不缓存**。
 *
 * ============================ 歌词格式：KRC，不是 LRC 也不是 QRC ============================
 * ```
 * 汽水 KRC ：[行起始ms,行持续ms]<词偏移ms,词时长ms,0>字…     ← 偏移**相对行首**
 * QQ  QRC  ：[行起始ms,行持续ms]字(绝对起始ms,词时长ms)…      ← 我们 `amllParseQrc` 只认这个
 * 标准 LRC ：[mm:ss.mmm]整行
 * ```
 * `qsKrcToQrc()` 把 KRC 归一化成 QRC（保住**逐字**时间轴），UI 侧 `amllDetectLyricFormat`
 * 会把它识别成 QRC 并走逐字渲染。直接喂 KRC 原文 = 解析出 **0 行**（看着像"没歌词"）。
 *
 * 排查关键字：`RzdSoda`
 */
import { http } from '@kit.NetworkKit';
import { appendPlayLog } from '../util/LxLogger';

const QS_H5_SEO_TRACK: string = 'https://beta-luna.douyin.com/luna/h5/seo_track';
const QS_TAG: string = '[RzdSoda]';

/** 浏览器 UA：本来不带头也能通，带上更稳（顺带让 `seo_url` 等按 Web 形态返回）。 */
const QS_H5_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ' +
    'Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json'
};

/**
 * 汽水这边所有诊断都走这里：hilog + 应用内「播放日志」**双写**。
 * （只写 console.info 的话，甲方贴的播放日志面板里永远看不到。）
 */
function qsLog(message: string): void {
  const line: string = QS_TAG + ' ' + message;
  console.info(line);
  appendPlayLog(line);
}

function asString(value: Object | undefined): string {
  return typeof value === 'string' ? (value as string) : '';
}

function asNumber(value: Object | undefined): number {
  return typeof value === 'number' ? (value as number) : 0;
}

function asBoolean(value: Object | undefined): boolean {
  return value === true;
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
 * KRC 里的"制作信息行"过滤（参考实现 `guowenye/qishui-api` 的 `isMetadataLine()`）。
 * 实测《小半》没有这类行，但别的歌会把 `作词: xxx` 当成一行歌词塞进来。
 */
function isMetadataLine(text: string): boolean {
  const v: string = text.trim();
  if (v.length === 0) {
    return true;
  }
  if (new RegExp('^(作词|作曲|编曲|制作人|监制|混音|母带|录音|演唱|歌手|艺人)[:：]').test(v)) {
    return true;
  }
  if (new RegExp('^[\\s\\-—.*+=|\\[\\]（）(){}]*$').test(v)) {
    return true;
  }
  if (v === '翻译' || v === '歌词') {
    return true;
  }
  return new RegExp('^(歌词|滚动歌词|翻译)?贡献者').test(v);
}

/**
 * 汽水 KRC → **QQ 版 QRC**（我们 `amllParseQrc` 认的那一份，保留逐字）。
 *
 * 输入：`[15971,3799]<0,169,0>如<169,168,0>果<480,297,0>那`
 * 输出：`[15971,3799]如(15971,169)果(16140,168)那(16451,297)`
 * @param raw `lyric.content`
 * @returns 归一化后的 QRC；没有可用行时返回空串。
 */
export function qsKrcToQrc(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  const lines: string[] = raw.split(/\r?\n/);
  const out: string[] = [];
  let dropped: number = 0;
  let credits: number = 0;
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
    let plain: string = '';
    // 词元：`<偏移,时长[,标志]>文本`（标志位实测为 0，允许缺省）
    const re: RegExp = new RegExp('<([0-9]+),([0-9]+)(?:,[0-9]+)?>([^<]*)', 'g');
    let m: RegExpExecArray | null = re.exec(rest);
    while (m !== null) {
      const offset: number = Number(m[1]);
      const dur: number = Number(m[2]);
      const text: string = m[3];
      if (text.length > 0) {
        words += text + '(' + (lineStart + offset) + ',' + dur + ')';
        plain += text;
      }
      m = re.exec(rest);
    }
    if (words.length === 0) {
      // 纯伴奏行（只有 `[start,dur]` 没有词元）：我们解析器本来也会跳过，这里直接记数
      dropped++;
      continue;
    }
    if (isMetadataLine(plain)) {
      credits++;
      continue;
    }
    out.push('[' + lineStart + ',' + lineDur + ']' + words);
  }
  qsLog('qsKrcToQrc lines=' + out.length + ' dropped=' + dropped + ' credits=' + credits +
    ' rawLen=' + raw.length);
  return out.join('\n');
}

/**
 * 按上游 `lyric.type` 决定怎么交给 UI：
 * `krc` → 归一化；`lrc` → 原样；类型缺失/不认识 → 嗅内容形状，实在认不出就原样返回
 * （宁可让 UI 的自动识别试一次，也别因为"不认识类型"就把歌词丢掉）。
 */
function qsLyricOfType(type: string, raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  const lower: string = type.toLowerCase();
  if (lower === 'krc' || new RegExp('^\\[\\d+,\\d+\\]\\s*<').test(raw)) {
    return qsKrcToQrc(raw);
  }
  if (lower === 'lrc' || new RegExp('^\\[\\d{1,2}:\\d{2}').test(raw)) {
    return raw;
  }
  return raw;
}

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
  /** 上游 `lyric.type`（`krc` / `lrc` / 空）——只用于日志与排查。 */
  lyricType: string = '';
  /** **已归一化**的歌词文本（KRC→QRC，可直接交给 `amllParseQrc`）；空串 = 这首歌没有歌词。 */
  qrc: string = '';
  /** 评论**总数**（上游 `comments.count`）；0 = 没有评论。 */
  commentTotal: number = 0;
  /** 免登录能拿到的**前几条**评论（上游只给 5 条左右，且不带回复）。 */
  comments: QsH5Comment[] = [];
}

/** 汽水一条评论（免登录能拿到的字段就这些）。 */
export class QsH5Comment {
  id: string = '';
  content: string = '';
  /** 点赞数。 */
  diggCount: number = 0;
  /** 回复数（拿不到回复内容，只有数量）。 */
  replyCount: number = 0;
  /** 发布时间（Unix **秒**）。 */
  timeSec: number = 0;
  userName: string = '';
  userId: string = '';
  avatar: string = '';
  /** IP 归属地（上游 `ip_label`），空串 = 没给。 */
  ipLabel: string = '';
}

/**
 * 评论头像：`medium_avatar_url.urls` 是**空格分隔**的一串地址，取第一个。
 * 也有 `thumb_avatar_url`（100×100）可降级。
 */
function qsAvatarOf(user: Record<string, Object>): string {
  const medium: Record<string, Object> = asRecord(user['medium_avatar_url']);
  const urls: string = asString(medium['urls']);
  if (urls.length > 0) {
    const first: string = urls.split(' ')[0];
    if (first.length > 0) {
      return first;
    }
  }
  const thumb: Record<string, Object> = asRecord(user['thumb_avatar_url']);
  const thumbUrls: string = asString(thumb['urls']);
  if (thumbUrls.length > 0) {
    return thumbUrls.split(' ')[0];
  }
  return '';
}

function qsCommentOf(raw: Object): QsH5Comment {
  const c: QsH5Comment = new QsH5Comment();
  const rec: Record<string, Object> = asRecord(raw);
  c.id = asString(rec['id']);
  c.content = asString(rec['content']);
  c.diggCount = asNumber(rec['count_digged']);
  c.replyCount = asNumber(rec['count_reply']);
  c.timeSec = asNumber(rec['time_created']);
  c.ipLabel = asString(rec['ip_label']);
  const user: Record<string, Object> = asRecord(rec['user']);
  c.userId = asString(user['id']);
  let name: string = asString(user['nickname']);
  if (name.length === 0) {
    name = asString(user['public_name']);
  }
  c.userName = name.length > 0 ? name : '汽水用户';
  c.avatar = qsAvatarOf(user);
  return c;
}

/** 从 `seo_track.track.album.url_cover` 拼 500×500 封面（与搜索接口同一套拼法）。 */
function qsCoverFromAlbum(album: Record<string, Object>): string {
  const pic: Record<string, Object> = asRecord(album['url_cover']);
  const uri: string = asString(pic['uri']);
  if (uri.length === 0) {
    return '';
  }
  if (new RegExp('^https?://', 'i').test(uri)) {
    return uri;
  }
  const urls: Object[] = asArray(pic['urls']);
  const base: string = urls.length > 0 ? asString(urls[0]) : '';
  if (base.length === 0) {
    return '';
  }
  if (new RegExp('\\.(jpg|jpeg|png|webp)$', 'i').test(uri)) {
    return base + uri;
  }
  return base + uri + '~c5_500x500.jpg';
}

/** 进程内小缓存：一首歌的"歌词+封面+评论"只拉一次（补全链路会跑 2~3 次）。 */
const QS_H5_CACHE: Map<string, QsH5TrackInfo> = new Map<string, QsH5TrackInfo>();
const QS_H5_ORDER: string[] = [];
const QS_H5_CACHE_MAX: number = 12;

/** 发一次 GET，失败/非 200 返回空串（不抛）。`headers` 传 `{}` = 不带任何头。 */
async function qsHttpGet(url: string, headers: Record<string, string>): Promise<string> {
  try {
    const client = http.createHttp();
    try {
      const resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        qsLog('h5/seo_track http=' + resp.responseCode);
        return '';
      }
      return typeof resp.result === 'string' ? (resp.result as string) : '';
    } finally {
      client.destroy();
    }
  } catch (err) {
    qsLog('h5/seo_track failed err=' + JSON.stringify(err).substring(0, 80));
    return '';
  }
}

/**
 * 拉一首歌的 H5 SEO 详情（歌词 + 封面 + 信息 + 评论）。失败返回 `undefined`（不抛）。
 * @param trackId 汽水 track id（= `SongItem.songId`）
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
  let text: string = await qsHttpGet(url, QS_H5_HEADERS);
  if (text.length === 0) {
    // 兜底：实测**不带任何请求头**也能通（万一哪天按 UA 风控了，这条还能救回来）
    text = await qsHttpGet(url, {});
    if (text.length > 0) {
      qsLog('h5/seo_track retried without UA ok id=' + trackId);
    }
  }
  if (text.length === 0) {
    return undefined;
  }
  const info: QsH5TrackInfo = new QsH5TrackInfo();
  info.trackId = trackId;
  try {
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const status: Record<string, Object> = asRecord(root['status_info']);
    const statusMsg: string = asString(status['status_msg']);
    const seo: Record<string, Object> = asRecord(root['seo_track']);
    const track: Record<string, Object> = asRecord(seo['track']);
    const trackName: string = asString(track['name']);
    // ⚠️ 无效 id 也是 200：只有 status_msg、没有 seo_track.track ⇒ 判失败、**不缓存**
    //   （否则一次风控/抖动会被永久固化成"这首歌没歌词/没评论"）
    if (statusMsg.length > 0 || (trackName.length === 0 && asNumber(track['duration']) <= 0)) {
      qsLog('h5/seo_track invalid id=' + trackId + ' statusMsg=' +
        (statusMsg.length > 0 ? statusMsg : '(无)'));
      return undefined;
    }
    info.name = trackName;
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
    info.durationSec = Math.floor(asNumber(track['duration']) / 1000);
    // ---- 歌词 ----
    const lyric: Record<string, Object> = asRecord(root['lyric']);
    info.lyricType = asString(lyric['type']);
    const hidden: boolean = asBoolean(lyric['hide_request_lyrics']);
    const rawLyric: string = asString(lyric['content']);
    if (hidden) {
      qsLog('h5/seo_track lyric hidden id=' + trackId);
    }
    info.qrc = hidden ? '' : qsLyricOfType(info.lyricType, rawLyric);
    // ---- 评论（免登录只给前几条，不带回复）----
    const commentsNode: Record<string, Object> = asRecord(root['comments']);
    info.commentTotal = asNumber(commentsNode['count']);
    const commentList: Object[] = asArray(commentsNode['comments']);
    for (let i: number = 0; i < commentList.length; i++) {
      info.comments.push(qsCommentOf(commentList[i]));
    }
  } catch (err) {
    qsLog('h5/seo_track parse failed id=' + trackId);
    return undefined;
  }
  qsLog('h5/seo_track ok id=' + trackId + ' name=' + info.name + ' singer=' + info.singer +
    ' type=' + (info.lyricType.length > 0 ? info.lyricType : '(空)') +
    ' lyricLines=' + (info.qrc.length > 0 ? info.qrc.split('\n').length : 0) +
    ' cover=' + (info.cover.length > 0 ? 1 : 0) +
    ' comments=' + info.comments.length + '/' + info.commentTotal);
  if (QS_H5_CACHE.size >= QS_H5_CACHE_MAX && QS_H5_ORDER.length > 0) {
    const evict: string = QS_H5_ORDER.shift() as string;
    QS_H5_CACHE.delete(evict);
  }
  QS_H5_CACHE.set(trackId, info);
  QS_H5_ORDER.push(trackId);
  return info;
}

/** @returns 已归一化的歌词文本（可直接当 `LyricFullResult.main`）；没有则空串。 */
export async function qsLyricText(trackId: string): Promise<string> {
  const info: QsH5TrackInfo | undefined = await qsH5SeoTrack(trackId);
  return info !== undefined ? info.qrc : '';
}

/** @returns 500×500 封面地址；没有则空串。 */
export async function qsCoverUrl(trackId: string): Promise<string> {
  const info: QsH5TrackInfo | undefined = await qsH5SeoTrack(trackId);
  return info !== undefined ? info.cover : '';
}

/**
 * 汽水评论（免登录）。
 *
 * ⚠️ 能力边界（写清楚，别让 UI 以为能翻页）：
 *   · 只有**第一页**，且上游只给 5 条左右（精选/热门）；
 *   · **拿不到楼中楼**（只有 `count_reply` 数字）；
 *   · 所以 `maxPage` 恒为 1、`total` 用上游的 `comments.count`（几万条也只显示这几条）。
 * @param trackId 汽水 track id
 * @param page 页码（>1 直接返回空页，避免 UI 无限下拉）
 */
export async function qsComments(trackId: string): Promise<QsH5TrackInfo | undefined> {
  return await qsH5SeoTrack(trackId);
}
