/*
 * 内置平台评论（酷我 / 酷狗 / QQ / 咪咕 / 网易）。
 *
 * 移植自洛雪音乐 HarmonyOS 版（lxmusic-harmony，Adamaik）的
 * `entry/src/main/ets/core/music/PlatformComment.ets`：
 * 洛雪自己走的也是内置平台 SDK（`src/utils/musicSdk/{kw,kg,tx,mg,wy}/comment.js`），
 * 而不是「自定义音源」—— 因为源协议里的 action 白名单只有 `musicUrl`，没有「取评论」。
 *
 * 各平台的分页方式差别很大，移植时照洛雪原样保留：
 *   - 酷我：`start = limit * (page - 1)`，最普通；
 *   - 酷狗：同上，外加一个把参数排序后拼 key 的 md5 签名；
 *   - QQ ：最新评论走老 fcg 接口（`pagenum = page - 1`），热门走 musicu 的 GetHotCommentList；
 *   - 咪咕：**游标式** —— 除了 resourceId 还要上一页最后一条评论的 id，按 (歌曲, 页) 记游标；
 *   - 网易：`offset = limit * (page - 1)`，用公开 GET（见 wyComments 的说明）。
 *
 * ⚠️ 与 RzdMusic 歌曲模型的对应关系（很重要，取错 id 就一首评论都拿不到）：
 *   `LXSearchSong.songId` / `SongItem.songId` 在各平台存的东西并不一样 ——
 *     kw → 数字 musicrid（`MUSIC_xxx` 去掉前缀）；kg → **hash**；
 *     tx → **songmid**（所以要先用 musicu 换数字 id）；mg → **copyrightId**；wy → 数字 id。
 *   本文件按上表直接使用 `song.songId`（与 `features/player/.../LXMusicSDK.ets` 的写入保持一致）。
 *   本地音乐（source = 'local'）由宿主先解析成平台身份，见 `core/CommentTarget.ets`。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  asNumber,
  asObjectArray,
  asRecord,
  asString,
  COMMENT_TAG,
  commentGetJson,
  commentPostForm,
  commentPostJson,
  decodeName,
  md5Hex
} from './CommentHttp';

const DOMAIN: number = 0x0000;

/** 请求评论时用到的歌曲身份（在线歌由页面直接给出；本地歌由宿主解析后给出）。 */
export interface CommentSongRef {
  /** 平台 id：'kw' | 'kg' | 'tx' | 'wy' | 'mg'（本地歌为空串或 'local'）。 */
  source: string;
  /** 平台内的歌曲 id，含义见文件头注释。 */
  songId: string;
  /** 歌名（QQ 用 songmid 换数字 id 失败时用不到，仅用于日志）。 */
  name: string;
  /** 歌手（同上）。 */
  singer: string;
}

/** 一条评论（主评论与楼中楼共用一套结构）。 */
export interface LxComment {
  id: string;
  text: string;
  userName: string;
  /** 平台侧的用户 id（各平台给的都加密过，界面上暂时不用）。 */
  userId: string;
  avatar: string;
  /** 已经格式化好的时间文案（「3 分钟前」/「2024-05-06」）；空串 = 平台没给时间。 */
  timeStr: string;
  /** IP 归属地；空串 = 没有。 */
  location: string;
  /** 点赞数；-1 = 平台没给（界面不画这一块，而不是显示 0）。 */
  likedCount: number;
  /** 回复数；-1 = 平台没给。 */
  replyNum: number;
  images: string[];
  /** 楼中楼：平台一般只在主评论里带前几条。 */
  reply: LxComment[];
}

/** 一页评论。 */
export interface CommentPage {
  comments: LxComment[];
  total: number;
  page: number;
  limit: number;
  maxPage: number;
}

/** 「热门」还是「最新」（对应评论面板的两个页签）。 */
export type CommentKind = 'hot' | 'new';

/** 一页拉多少条（与洛雪评论页一致：两个页签都是 15）。 */
export const COMMENT_PAGE_SIZE: number = 15;

/** 有评论接口的平台。 */
export const COMMENT_SUPPORTED_SOURCES: string[] = ['kw', 'kg', 'mg', 'tx', 'wy'];

/** 这个平台有没有评论接口。 */
export function commentsSupported(source: string): boolean {
  return COMMENT_SUPPORTED_SOURCES.indexOf(source) >= 0;
}

// ------------------------------------------------------------------ 小工具

/** 造一条空评论：各平台都往这个骨架上填。 */
function makeComment(id: string, text: string, userName: string): LxComment {
  const comment: LxComment = {
    id: id,
    text: text,
    userName: userName,
    userId: '',
    avatar: '',
    timeStr: '',
    location: '',
    likedCount: -1,
    replyNum: -1,
    images: [],
    reply: []
  };
  return comment;
}

/** 接口返回码比较：有的平台给数字、有的给字符串，统一当字符串比。 */
function codeIs(value: Object | undefined, expected: string): boolean {
  return asString(value) === expected;
}

/** 平台给的是空值时算「没有点赞数」（界面不画），而不是 0。 */
function likedCountOf(value: Object | undefined): number {
  return asNumber(value, -1);
}

/** 评论图片地址的百分号解码；地址坏了不该把整页评论带崩，所以就地吞掉。 */
function safeDecode(uri: string): string {
  try {
    return decodeURIComponent(uri);
  } catch (_err) {
    return uri;
  }
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : String(value);
}

/** `YYYY-MM-DD`。 */
function dateOnly(ms: number): string {
  const date = new Date(ms);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/**
 * 相对时间（照洛雪 `date_format_second/minute/hour` 的档位与文案）。
 *
 * 一分钟内「N 秒前」、一小时内「N 分钟前」、一天内「N 小时前」，再往前只给日期。
 * 时间戳异常（0 / 未来）返回空串，界面就不显示这一块。
 */
export function relativeTime(ms: number): string {
  if (ms <= 0) {
    return '';
  }
  const differ: number = Math.trunc((Date.now() - ms) / 1000);
  if (differ < 0) {
    return '刚刚';
  }
  if (differ < 60) {
    return `${differ} 秒前`;
  }
  if (differ < 3600) {
    return `${Math.trunc(differ / 60)} 分钟前`;
  }
  if (differ < 86400) {
    return `${Math.trunc(differ / 3600)} 小时前`;
  }
  return dateOnly(ms);
}

/**
 * `YYYY-MM-DD HH:mm:ss` -> 毫秒（酷狗 / 咪咕给的是这种字符串）。
 *
 * 不用 `new Date(text)`：这种非 ISO 格式在不同引擎里的解析结果不一致，
 * 手写解析至少结果可预期；解析不出来给 0，界面按「没有时间」处理。
 */
function parseDateTime(text: string): number {
  const match = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})/.exec(text);
  if (match === null) {
    return 0;
  }
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]),
    Number(match[4]), Number(match[5]), Number(match[6])).getTime();
}

/** 按平台给的秒级时间戳转毫秒（QQ 的 time 字段是秒）。 */
function secondsToMs(value: Object | undefined): number {
  const text: string = asString(value);
  // 只认 10 位以上的时间戳（秒）；短于此的当没有时间
  if (text.length < 10) {
    return 0;
  }
  const seconds: number = asNumber(value, 0);
  return seconds > 0 ? seconds * 1000 : 0;
}

function capPage(total: number, limit: number): number {
  return Math.ceil(total / limit) || 1;
}

// ------------------------------------------------------------------ 酷我

const KW_HEADERS: Record<string, string> = {
  'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 9;)'
};

const KG_COMMENT_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) ' +
    'Chrome/107.0.0.0 Safari/537.36 Edg/107.0.1418.24'
};

export function parseKwComments(rawList: Object[]): LxComment[] {
  const out: LxComment[] = [];
  for (let i: number = 0; i < rawList.length; i++) {
    const item: Record<string, Object> = asRecord(rawList[i]);
    const comment: LxComment = makeComment(
      asString(item['id']), asString(item['msg']), asString(item['u_name']));
    comment.avatar = asString(item['u_pic']);
    comment.timeStr = relativeTime(asNumber(item['time'], 0) * 1000);
    comment.likedCount = likedCountOf(item['like_num']);
    const pic: string = asString(item['mpic']);
    if (pic.length > 0) {
      comment.images = [safeDecode(pic)];
    }
    const children: Object[] = asObjectArray(item['child_comments']);
    for (let j: number = 0; j < children.length; j++) {
      const child: Record<string, Object> = asRecord(children[j]);
      const reply: LxComment = makeComment(
        asString(child['id']), asString(child['msg']), asString(child['u_name']));
      reply.avatar = asString(child['u_pic']);
      reply.timeStr = relativeTime(asNumber(child['time'], 0) * 1000);
      reply.likedCount = likedCountOf(child['like_num']);
      const childPic: string = asString(child['mpic']);
      if (childPic.length > 0) {
        reply.images = [childPic];
      }
      comment.reply.push(reply);
    }
    out.push(comment);
  }
  return out;
}

async function kwComments(songId: string, kind: CommentKind, page: number,
  limit: number): Promise<CommentPage> {
  if (songId.length === 0) {
    throw new Error('这首歌缺少酷我歌曲 id，拿不到评论');
  }
  const type: string = kind === 'hot' ? 'get_rec_comment' : 'get_comment';
  const url: string = 'http://ncomment.kuwo.cn/com.s?f=web&type=' + type +
    '&aapiver=1&prod=kwplayer_ar_10.5.2.0&digest=15&sid=' + encodeURIComponent(songId) +
    `&start=${limit * (page - 1)}&msgflag=1&count=${limit}&newver=3&uid=0`;
  const body: Record<string, Object> = await commentGetJson(url, KW_HEADERS, '获取评论');
  if (!codeIs(body['code'], '200')) {
    throw new Error(`获取评论失败（酷我接口返回 ${asString(body['code'])}）`);
  }
  const listKey: string = kind === 'hot' ? 'hot_comments' : 'comments';
  const countKey: string = kind === 'hot' ? 'hot_comments_counts' : 'comments_counts';
  const total: number = asNumber(body[countKey], 0);
  return {
    comments: parseKwComments(asObjectArray(body[listKey])),
    total: total,
    page: page,
    limit: limit,
    maxPage: capPage(total, limit)
  };
}

// ------------------------------------------------------------------ 酷狗

/**
 * 酷狗评论签名：把查询串按 `&` 拆开、**排序**后拼起来，前后各裹一个固定 key 再 md5
 * （照洛雪 `kg/util.js` 的 `signatureParams`，key 是 android 那一个）。
 */
export function kgSignature(params: string): string {
  const parts: string[] = params.split('&');
  parts.sort();
  return md5Hex(`OIlwieks28dk2k092lksi2UIkp${parts.join('')}OIlwieks28dk2k092lksi2UIkp`);
}

/** 酷狗把「回复某人」写成 `[at=123]`，要换成 `@名字 `（照洛雪 kg/comment.js 的 replaceAt）。 */
function replaceAt(raw: string, atList: Object[]): string {
  let out: string = raw;
  for (let i: number = 0; i < atList.length; i++) {
    const at: Record<string, Object> = asRecord(atList[i]);
    const id: string = asString(at['id']);
    if (id.length === 0) {
      continue;
    }
    out = out.split(`[at=${id}]`).join(`@${asString(at['name'])} `);
  }
  return out;
}

export function parseKgComments(rawList: Object[]): LxComment[] {
  const out: LxComment[] = [];
  for (let i: number = 0; i < rawList.length; i++) {
    const item: Record<string, Object> = asRecord(rawList[i]);
    const content: string = asString(item['content']);
    const atList: Object[] = asObjectArray(item['atlist']);
    const text: string = decodeName(atList.length > 0 ? replaceAt(content, atList) : content);

    const comment: LxComment = makeComment(asString(item['id']), text, asString(item['user_name']));
    comment.avatar = asString(item['user_pic']);
    comment.userId = asString(item['user_id']);
    comment.location = asString(item['location']);
    comment.timeStr = relativeTime(parseDateTime(asString(item['addtime'])));
    comment.likedCount = likedCountOf(asRecord(item['like'])['likenum']);
    comment.replyNum = likedCountOf(item['reply_num']);
    const images: Object[] = asObjectArray(item['images']);
    for (let j: number = 0; j < images.length; j++) {
      const url: string = asString(asRecord(images[j])['url']);
      if (url.length > 0) {
        comment.images.push(url);
      }
    }

    // pcontent 是「这条其实是回复某条评论」时被引用的原文：当成主楼、真正的回复放 reply 里
    const parent: string = asString(item['pcontent']);
    if (parent.length === 0) {
      out.push(comment);
      continue;
    }
    const wrapper: LxComment = makeComment(
      asString(item['id']), decodeName(parent), asString(item['puser']));
    wrapper.userId = asString(item['puser_id']);
    wrapper.reply = [comment];
    out.push(wrapper);
  }
  return out;
}

async function kgComments(hash: string, kind: CommentKind, page: number,
  limit: number): Promise<CommentPage> {
  if (hash.length === 0) {
    throw new Error('这首歌缺少酷狗 hash，拿不到评论');
  }
  const rank: string = kind === 'hot' ? 'topliked' : 'newest';
  const params: string = 'dfid=0&mid=16249512204336365674023395779019' +
    `&clienttime=${Date.now()}&uuid=0&extdata=${hash}` +
    '&appid=1005&code=fc4be23b4e972707f36b8a828a93ba8a' +
    `&schash=${hash}&clientver=11409&p=${page}&clienttoken=&pagesize=${limit}&ver=10&kugouid=0`;
  const url: string = `http://m.comment.service.kugou.com/r/v1/rank/${rank}?${params}` +
    `&signature=${kgSignature(params)}`;
  const body: Record<string, Object> = await commentGetJson(url, KG_COMMENT_HEADERS, '获取评论');
  if (!codeIs(body['err_code'], '0')) {
    throw new Error(`获取评论失败（酷狗接口返回 err_code ${asString(body['err_code'])}）`);
  }
  const total: number = asNumber(body['count'], 0);
  return {
    comments: parseKgComments(asObjectArray(body['list'])),
    total: total,
    page: page,
    limit: limit,
    maxPage: capPage(total, limit)
  };
}

// ------------------------------------------------------------------ 咪咕

const MG_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 ' +
    '(KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1'
};

/**
 * 咪咕「最新评论」是游标分页：第二页要带第一页最后一条评论的 id（`commentId` 参数）。
 * 游标按「歌曲 + 页码」记，换歌或重新拉第一页就清掉。
 */
let mgCursor: Record<string, Record<string, string>> = {};

function mgCursorOf(resourceId: string, page: number): string {
  const perSong: Record<string, string> | undefined = mgCursor[resourceId];
  if (perSong === undefined) {
    return '';
  }
  const id: string | undefined = perSong[String(page)];
  return id !== undefined ? id : '';
}

function mgSetCursor(resourceId: string, page: number, lastId: string): void {
  let perSong: Record<string, string> | undefined = mgCursor[resourceId];
  if (perSong === undefined) {
    perSong = {};
    mgCursor[resourceId] = perSong;
  }
  perSong[String(page)] = lastId;
}

/** 咪咕的用户头像有三档，取能得到的那一档。 */
function mgAvatar(user: Record<string, Object>): string {
  let avatar: string = asString(user['middleIcon']);
  if (avatar.length === 0) {
    avatar = asString(user['bigIcon']);
  }
  if (avatar.length === 0) {
    avatar = asString(user['smallIcon']);
  }
  return avatar;
}

export function parseMgComments(rawList: Object[]): LxComment[] {
  const out: LxComment[] = [];
  for (let i: number = 0; i < rawList.length; i++) {
    const item: Record<string, Object> = asRecord(rawList[i]);
    const user: Record<string, Object> = asRecord(item['user']);
    const comment: LxComment = makeComment(asString(item['commentId']),
      asString(item['commentInfo']), asString(user['nickName']));
    comment.avatar = mgAvatar(user);
    comment.userId = asString(user['userId']);
    comment.timeStr = relativeTime(parseDateTime(asString(item['commentTime'])));
    comment.likedCount = likedCountOf(asRecord(item['opNumItem'])['thumbNum']);
    comment.replyNum = likedCountOf(item['replyTotalCount']);
    const replies: Object[] = asObjectArray(item['replyComments']);
    for (let j: number = 0; j < replies.length; j++) {
      const replyData: Record<string, Object> = asRecord(replies[j]);
      const replyUser: Record<string, Object> = asRecord(replyData['user']);
      const reply: LxComment = makeComment(asString(replyData['replyId']),
        asString(replyData['replyInfo']), asString(replyUser['nickName']));
      reply.avatar = mgAvatar(replyUser);
      reply.userId = asString(replyUser['userId']);
      reply.timeStr = relativeTime(parseDateTime(asString(replyData['replyTime'])));
      comment.reply.push(reply);
    }
    out.push(comment);
  }
  return out;
}

async function mgComments(resourceId: string, kind: CommentKind, page: number,
  limit: number): Promise<CommentPage> {
  if (resourceId.length === 0) {
    throw new Error('这首歌缺少咪咕歌曲 id，拿不到评论');
  }
  const base: string = 'https://app.c.nf.migu.cn/MIGUM3.0/user/comment/stack/v1.0' +
    `?pageSize=${limit}&resourceId=${encodeURIComponent(resourceId)}&resourceType=2`;
  let url: string;
  if (kind === 'hot') {
    url = `${base}&queryType=2&hotCommentStart=${(page - 1) * limit}`;
  } else {
    if (page === 1) {
      // 第一页顺手把这首歌的游标清掉：重新进来时不该拿上一次的游标去翻页
      const empty: Record<string, string> = {};
      mgCursor[resourceId] = empty;
    }
    const cursor: string = mgCursorOf(resourceId, page);
    if (page > 1 && cursor.length === 0) {
      // 没有上一页的游标就翻不动了（如实抛，界面会提示重试）
      throw new Error('咪咕评论需要按顺序翻页，请先加载上一页');
    }
    url = `${base}&queryType=1&commentId=${encodeURIComponent(cursor)}`;
  }
  const body: Record<string, Object> = await commentGetJson(url, MG_HEADERS, '获取评论');
  if (!codeIs(body['code'], '000000')) {
    throw new Error(`获取评论失败（咪咕接口返回 ${asString(body['code'])}）`);
  }
  const data: Record<string, Object> = asRecord(body['data']);
  if (kind === 'hot') {
    const total: number = asNumber(data['cfgHotCount'], 0);
    return {
      comments: parseMgComments(asObjectArray(data['hotComments'])),
      total: total,
      page: page,
      limit: limit,
      maxPage: capPage(total, limit)
    };
  }
  const total: number = asNumber(data['commentNums'], 0);
  const comments: LxComment[] = parseMgComments(asObjectArray(data['comments']));
  // 记下这一页最后一条的 id，供第 page+1 页当游标
  mgSetCursor(resourceId, page + 1, comments.length > 0 ? comments[comments.length - 1].id : '');
  return { comments: comments, total: total, page: page, limit: limit, maxPage: capPage(total, limit) };
}

// ------------------------------------------------------------------ QQ 音乐

const TX_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ' +
    'Chrome/113.0.0.0 Safari/537.36 Edg/113.0.0.0',
  'referer': 'https://y.qq.com/',
  'origin': 'https://y.qq.com'
};

/** QQ 老 fcg 接口（最新评论）与补 songId 用的老式 UA。 */
const TX_FCG_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)'
};

/** QQ 评论里的表情码（`[em]e400846[/em]`），照洛雪 tx/comment.js 的 emojis 表。 */
const TX_EMOJIS: Record<string, string> = {
  'e400846': '😘', 'e400874': '😴', 'e400825': '😃', 'e400847': '😙', 'e400835': '😍',
  'e400873': '😳', 'e400836': '😎', 'e400867': '😭', 'e400832': '😊', 'e400837': '😏',
  'e400875': '😫', 'e400831': '😉', 'e400855': '😡', 'e400823': '😄', 'e400862': '😨',
  'e400844': '😖', 'e400841': '😓', 'e400830': '😈', 'e400828': '😆', 'e400833': '😋',
  'e400822': '😀', 'e400843': '😕', 'e400829': '😇', 'e400824': '😂', 'e400834': '😌',
  'e400877': '😷', 'e400132': '🍉', 'e400181': '🍺', 'e401067': '☕️', 'e400186': '🥧',
  'e400343': '🐷', 'e400116': '🌹', 'e400126': '🍃', 'e400613': '💋', 'e401236': '❤️',
  'e400622': '💔', 'e400637': '💣', 'e400643': '💩', 'e400773': '🔪', 'e400102': '🌛',
  'e401328': '🌞', 'e400420': '👏', 'e400914': '🙌', 'e400408': '👍', 'e400414': '👎',
  'e401121': '✋', 'e400396': '👋', 'e400384': '👉', 'e401115': '✊', 'e400402': '👌',
  'e400905': '🙈', 'e400906': '🙉', 'e400907': '🙊', 'e400562': '👻', 'e400932': '🙏',
  'e400644': '💪', 'e400611': '💉', 'e400185': '🎁', 'e400655': '💰', 'e400325': '🐥',
  'e400612': '💊', 'e400198': '🎉', 'e401685': '⚡️', 'e400631': '💝', 'e400768': '🔥',
  'e400432': '👑'
};

const TX_EMOJI_TAG: RegExp = /\[em\](e\d+)\[\/em\]/g;

/** 正文里的表情码换成 emoji、`\n`（字面上的反斜杠 n）换成真换行。 */
function txText(raw: string): string {
  const replaced: string = raw.replace(TX_EMOJI_TAG, (_tag: string, code: string): string => {
    const emoji: string | undefined = TX_EMOJIS[code];
    return emoji !== undefined ? emoji : '';
  });
  return replaced.split('\\n').join('\n');
}

/** QQ 的昵称前面带一个不可见的控制字符（洛雪统一 substring(1) 去掉）。 */
function txNick(raw: string): string {
  return raw.length > 1 ? raw.substring(1) : '';
}

export function parseTxComments(rawList: Object[]): LxComment[] {
  const out: LxComment[] = [];
  for (let i: number = 0; i < rawList.length; i++) {
    const item: Record<string, Object> = asRecord(rawList[i]);
    const rootText: string = asString(item['rootcommentcontent']);
    const isRoot: boolean = asString(item['rootcommentid']) === asString(item['commentid']);
    const comment: LxComment = makeComment(
      `${asString(item['rootcommentid'])}_${asString(item['commentid'])}`,
      txText(rootText), txNick(asString(item['rootcommentnick'])));
    comment.avatar = asString(item['avatarurl']);
    comment.userId = asString(item['encrypt_rootcommentuin']);
    comment.likedCount = likedCountOf(item['praisenum']);
    // 时间只跟着「本条」走：被引用进来的原文不报时间
    if (isRoot) {
      comment.timeStr = relativeTime(secondsToMs(item['time']));
    }
    const middles: Object[] = asObjectArray(item['middlecommentcontent']);
    for (let j: number = 0; j < middles.length; j++) {
      const replyData: Record<string, Object> = asRecord(middles[j]);
      const reply: LxComment = makeComment(
        `sub_${asString(item['rootcommentid'])}_${asString(replyData['subcommentid'])}`,
        txText(asString(replyData['subcommentcontent'])),
        txNick(asString(replyData['replynick'])));
      reply.avatar = asString(replyData['avatarurl']);
      reply.userId = asString(replyData['encrypt_replyuin']);
      reply.likedCount = likedCountOf(replyData['praisenum']);
      comment.reply.push(reply);
    }
    out.push(comment);
  }
  return out;
}

/** 热门评论（musicu 的 GetHotCommentList）：字段名与「最新」完全不同（首字母大写）。 */
export function parseTxHotComments(rawList: Object[]): LxComment[] {
  const out: LxComment[] = [];
  for (let i: number = 0; i < rawList.length; i++) {
    const item: Record<string, Object> = asRecord(rawList[i]);
    const comment: LxComment = makeComment(`${asString(item['SeqNo'])}_${asString(item['CmId'])}`,
      txText(asString(item['Content'])), asString(item['Nick']));
    comment.avatar = asString(item['Avatar']);
    comment.userId = asString(item['EncryptUin']);
    comment.location = asString(item['Location']);
    comment.likedCount = likedCountOf(item['PraiseNum']);
    comment.timeStr = relativeTime(secondsToMs(item['PubTime']));
    const pic: string = asString(item['Pic']);
    if (pic.length > 0) {
      comment.images = [pic];
    }
    const subs: Object[] = asObjectArray(item['SubComments']);
    for (let j: number = 0; j < subs.length; j++) {
      const replyData: Record<string, Object> = asRecord(subs[j]);
      const reply: LxComment = makeComment(
        `sub_${asString(replyData['SeqNo'])}_${asString(replyData['CmId'])}`,
        txText(asString(replyData['Content'])), asString(replyData['Nick']));
      reply.avatar = asString(replyData['Avatar']);
      reply.userId = asString(replyData['EncryptUin']);
      reply.likedCount = likedCountOf(replyData['PraiseNum']);
      reply.timeStr = relativeTime(secondsToMs(replyData['PubTime']));
      const replyPic: string = asString(replyData['Pic']);
      if (replyPic.length > 0) {
        reply.images = [replyPic];
      }
      comment.reply.push(reply);
    }
    out.push(comment);
  }
  return out;
}

/** 已经解析过的 QQ 数字 songId，按 songmid 记住（评论接口只要数字 id）。 */
let txSongIds: Record<string, string> = {};

interface TxComm {
  ct: string | number;
  cv: string | number;
  uin: string | number;
  format?: string;
  inCharset?: string;
  outCharset?: string;
  notice?: number;
  platform?: string;
  needNewCode?: number;
}

interface TxSongDetailParam {
  song_type: number;
  song_mid: string;
}

interface TxSongDetailReq {
  module: string;
  method: string;
  param: TxSongDetailParam;
}

interface TxSongDetailPayload {
  comm: TxComm;
  req: TxSongDetailReq;
}

interface TxHotParam {
  BizType: number;
  BizId: string;
  LastCommentSeqNo: string;
  PageSize: number;
  PageNum: number;
  HotType: number;
  WithAirborne: number;
  PicEnable: number;
}

interface TxHotReq {
  module: string;
  method: string;
  param: TxHotParam;
}

interface TxHotPayload {
  comm: TxComm;
  req: TxHotReq;
}

/** 判断一个字符串是不是纯数字 id（QQ 的数字 songId 都是这种）。 */
function isNumericId(value: string): boolean {
  return value.length >= 6 && /^\d+$/.test(value);
}

/**
 * 拿 QQ 的数字 songId。
 *
 * RzdMusic 里 tx 歌曲存的 `songId` 一直是 **songmid**（搜索、榜单、歌单详情三条路都是），
 * 而评论接口要的是数字 id，所以这里用洛雪 tx/musicInfo.js 的 `get_song_detail_yqq` 换一次，
 * 结果按 songmid 缓存。万一条目里已经是数字 id（历史数据 / 手工导入），直接用。
 */
async function txSongId(song: CommentSongRef): Promise<string> {
  if (song.songId.length === 0) {
    throw new Error('这首歌缺少 QQ 歌曲 id，拿不到评论');
  }
  if (isNumericId(song.songId)) {
    return song.songId;
  }
  const cached: string | undefined = txSongIds[song.songId];
  if (cached !== undefined && cached.length > 0) {
    return cached;
  }
  const payload: TxSongDetailPayload = {
    comm: { ct: '19', cv: '1859', uin: '0' },
    req: {
      module: 'music.pf_song_detail_svr',
      method: 'get_song_detail_yqq',
      param: { song_type: 0, song_mid: song.songId }
    }
  };
  const body: Record<string, Object> = await commentPostJson('https://u.y.qq.com/cgi-bin/musicu.fcg',
    payload, TX_FCG_HEADERS, '获取歌曲信息');
  const track: Record<string, Object> = asRecord(asRecord(asRecord(body['req'])['data'])['track_info']);
  const songId: string = asString(track['id']);
  if (songId.length === 0) {
    hilog.warn(DOMAIN, COMMENT_TAG, 'tx numId resolve failed mid=%{public}s name=%{public}s',
      song.songId, song.name);
    throw new Error('拿不到这首歌的 QQ 歌曲 id，评论取不了');
  }
  txSongIds[song.songId] = songId;
  return songId;
}

async function txComments(song: CommentSongRef, kind: CommentKind, page: number,
  limit: number): Promise<CommentPage> {
  const songId: string = await txSongId(song);
  if (kind === 'hot') {
    const payload: TxHotPayload = {
      comm: {
        cv: 4747474, ct: 24, format: 'json', inCharset: 'utf-8', outCharset: 'utf-8',
        notice: 0, platform: 'yqq.json', needNewCode: 1, uin: 0
      },
      req: {
        module: 'music.globalComment.CommentRead',
        method: 'GetHotCommentList',
        param: {
          BizType: 1, BizId: songId, LastCommentSeqNo: '', PageSize: limit,
          PageNum: page - 1, HotType: 1, WithAirborne: 0, PicEnable: 1
        }
      }
    };
    const body: Record<string, Object> = await commentPostJson('https://u.y.qq.com/cgi-bin/musicu.fcg',
      payload, TX_HEADERS, '获取热门评论');
    const req: Record<string, Object> = asRecord(body['req']);
    if (!codeIs(body['code'], '0') || !codeIs(req['code'], '0')) {
      throw new Error(`获取热门评论失败（QQ 接口返回 ${asString(body['code'])}/${asString(req['code'])}）`);
    }
    const list: Record<string, Object> = asRecord(asRecord(req['data'])['CommentList']);
    const total: number = asNumber(list['Total'], 0);
    return {
      comments: parseTxHotComments(asObjectArray(list['Comments'])),
      total: total,
      page: page,
      limit: limit,
      maxPage: capPage(total, limit)
    };
  }

  const form: Record<string, string> = {
    'uin': '0', 'format': 'json', 'cid': '205360772', 'reqtype': '2', 'biztype': '1',
    'topid': songId, 'cmd': '8', 'needmusiccrit': '1',
    'pagenum': String(page - 1), 'pagesize': String(limit)
  };
  const body: Record<string, Object> = await commentPostForm(
    'http://c.y.qq.com/base/fcgi-bin/fcg_global_comment_h5.fcg',
    form, TX_FCG_HEADERS, '获取评论');
  if (!codeIs(body['code'], '0')) {
    throw new Error(`获取评论失败（QQ 接口返回 ${asString(body['code'])}）`);
  }
  const comment: Record<string, Object> = asRecord(body['comment']);
  const total: number = asNumber(comment['commenttotal'], 0);
  return {
    comments: parseTxComments(asObjectArray(comment['commentlist'])),
    total: total,
    page: page,
    limit: limit,
    maxPage: capPage(total, limit)
  };
}

// ------------------------------------------------------------------ 网易

const WY_HEADERS: Record<string, string> = {
  'Referer': 'https://music.163.com/'
};

/** 网易把表情写成 `[大笑]` 这种标签，照洛雪 wy/comment.js 的表换成 emoji。 */
const WY_EMOJIS: string[][] = [
  ['大笑', '😃'], ['可爱', '😊'], ['憨笑', '☺️'], ['色', '😍'], ['亲亲', '😙'],
  ['惊恐', '😱'], ['流泪', '😭'], ['亲', '😚'], ['呆', '😳'], ['哀伤', '😔'],
  ['呲牙', '😁'], ['吐舌', '😝'], ['撇嘴', '😒'], ['怒', '😡'], ['奸笑', '😏'],
  ['汗', '😓'], ['痛苦', '😖'], ['惶恐', '😰'], ['生病', '😨'], ['口罩', '😷'],
  ['大哭', '😂'], ['晕', '😵'], ['发怒', '👿'], ['开心', '😄'], ['鬼脸', '😜'],
  ['皱眉', '😞'], ['流感', '😢'], ['爱心', '❤️'], ['心碎', '💔'], ['钟情', '💘'],
  ['星星', '⭐️'], ['生气', '💢'], ['便便', '💩'], ['强', '👍'], ['弱', '👎'],
  ['拜', '🙏'], ['牵手', '👫'], ['跳舞', '👯‍♀️'], ['禁止', '🙅‍♀️'], ['这边', '💁‍♀️'],
  ['爱意', '💏'], ['示爱', '👩‍❤️‍👨'], ['嘴唇', '👄'], ['狗', '🐶'], ['猫', '🐱'],
  ['猪', '🐷'], ['兔子', '🐰'], ['小鸡', '🐤'], ['公鸡', '🐔'], ['幽灵', '👻'],
  ['圣诞', '🎅'], ['外星', '👽'], ['钻石', '💎'], ['礼物', '🎁'], ['男孩', '👦'],
  ['女孩', '👧'], ['蛋糕', '🎂'], ['18', '🔞'], ['圈', '⭕'], ['叉', '❌']
];

function wyText(raw: string): string {
  let out: string = raw;
  for (let i: number = 0; i < WY_EMOJIS.length; i++) {
    const pair: string[] = WY_EMOJIS[i];
    out = out.split(`[${pair[0]}]`).join(pair[1]);
  }
  return out;
}

/** 一条网易评论 -> LxComment；`withTime` 为假表示它只是被引用进来的原文。 */
function wyOne(raw: Object, withTime: boolean): LxComment {
  const item: Record<string, Object> = asRecord(raw);
  const user: Record<string, Object> = asRecord(item['user']);
  const comment: LxComment = makeComment(asString(item['commentId']),
    wyText(asString(item['content'])), asString(user['nickname']));
  comment.avatar = asString(user['avatarUrl']);
  comment.userId = asString(user['userId']);
  comment.likedCount = likedCountOf(item['likedCount']);
  if (withTime) {
    comment.timeStr = relativeTime(asNumber(item['time'], 0));
    comment.location = asString(asRecord(item['ipLocation'])['location']);
  }
  return comment;
}

/**
 * 网易：「这条其实是回复别人」时，`beReplied[0]` 装的是被引用的原文。
 * 翻成「主楼 = 原文，reply = 这条回复」，与 QQ / 酷狗同一套处理。
 */
export function parseWyComments(rawList: Object[]): LxComment[] {
  const out: LxComment[] = [];
  for (let i: number = 0; i < rawList.length; i++) {
    const item: Record<string, Object> = asRecord(rawList[i]);
    const data: LxComment = wyOne(item, true);
    const repliedRaw: Object[] = asObjectArray(item['beReplied']);
    if (repliedRaw.length === 0) {
      out.push(data);
      continue;
    }
    const replied: LxComment = wyOne(repliedRaw[0], false);
    replied.id = data.id;
    replied.reply = [data];
    out.push(replied);
  }
  return out;
}

/**
 * 网易：公开的 `/api/v1/resource/comments/R_SO_4_{id}`（无需登录、无需 weapi 加密）。
 *
 * 洛雪走的是 `weapi/comment/resource/comments/get`（要 weapi 的 AES+RSA），这里沿用本工程
 * 取网易歌词的那条公开 `/api/` 路子 —— 打的是 music.163.com 的公开面，只是路径换成评论那两个。
 */
async function wyComments(songId: string, kind: CommentKind, page: number,
  limit: number): Promise<CommentPage> {
  if (songId.length === 0) {
    throw new Error('这首歌缺少网易歌曲 id，拿不到评论');
  }
  const rid: string = `R_SO_4_${songId}`;
  const offset: number = limit * (page - 1);
  const path: string = kind === 'hot'
    ? 'https://music.163.com/api/v1/resource/hotcomments/' + encodeURIComponent(rid)
    : 'https://music.163.com/api/v1/resource/comments/' + encodeURIComponent(rid);
  const body: Record<string, Object> = await commentGetJson(
    `${path}?limit=${limit}&offset=${offset}`, WY_HEADERS, '获取评论');
  if (!codeIs(body['code'], '200')) {
    throw new Error(`获取评论失败（网易接口返回 ${asString(body['code'])}）`);
  }
  const listKey: string = kind === 'hot' ? 'hotComments' : 'comments';
  const total: number = asNumber(body['total'], 0);
  return {
    comments: parseWyComments(asObjectArray(body[listKey])),
    total: total,
    page: page,
    limit: limit,
    maxPage: capPage(total, limit)
  };
}

// ------------------------------------------------------------------ 入口

/**
 * 按平台取一页评论。
 *
 * 失败一律抛出（不吞成空列表）：评论面板要能区分「真的没人评论」和「接口挂了」，
 * 前者显示空态、后者显示错误与重试。
 *
 * @param song 歌曲的平台身份（本地歌请先用 CommentTarget 解析成平台身份）。
 * @param kind 'hot' 热门 / 'new' 最新。
 * @param page 页码，从 1 开始。
 * @param limit 每页条数，默认 15。
 */
export async function fetchComments(song: CommentSongRef, kind: CommentKind, page: number,
  limit: number = COMMENT_PAGE_SIZE): Promise<CommentPage> {
  if (!commentsSupported(song.source)) {
    throw new Error('该平台暂不支持查看评论');
  }
  if (song.source === 'kw') {
    return await kwComments(song.songId, kind, page, limit);
  }
  if (song.source === 'kg') {
    return await kgComments(song.songId, kind, page, limit);
  }
  if (song.source === 'mg') {
    return await mgComments(song.songId, kind, page, limit);
  }
  if (song.source === 'tx') {
    return await txComments(song, kind, page, limit);
  }
  return await wyComments(song.songId, kind, page, limit);
}

/** 同一页去重（平台会在翻页边界重复返回，洛雪的 filterList 就是干这个的）。 */
export function dedupeComments(list: LxComment[]): LxComment[] {
  const seen: string[] = [];
  const out: LxComment[] = [];
  for (let i: number = 0; i < list.length; i++) {
    const comment: LxComment = list[i];
    if (seen.indexOf(comment.id) >= 0) {
      continue;
    }
    seen.push(comment.id);
    out.push(comment);
  }
  return out;
}
