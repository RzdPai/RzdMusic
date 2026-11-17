/**
 * 无界音乐扩展插件(MusicFree / BakaMusic 格式)—— 2026-10-30
 *
 * 只提供三样契约之外 / 别的插件都没实现的能力, 不做搜索与播放:
 *   · getHotSearch()               热搜词(本应用扩展的方法)
 *   · getSearchSuggestions(kw)     搜索联想词(本应用扩展的方法)
 *   · recognize(pcmB64, sr, ch)    听歌识曲(BakaMusic 契约: 8kHz / 16bit / 单声道 PCM 的 base64)
 *
 * 识曲结果只给歌名 / 歌手 / 专辑 / 封面, 并标上 platform: '酷狗音乐' —— 不带 id:
 *   酷狗识曲接口回的 mixsongid 与取播放地址要的 hash 不是一套 id, 拼出来"看着对、放不出来"。
 *   宿主拿到没有 id 的结果, 会去对应平台搜一次、按换源那套严格判据挑出能播的那条。
 *
 * 来源与许可:
 *   热搜 / 联想: 洛雪音乐移动版 lx-music-mobile(Copyright (c) lyswhut, Apache-2.0)的
 *     src/utils/musicSdk/kw/{hotSearch,tipSearch}.js
 *   识曲: 洛雪音乐桌面增强版 lx-music-desktop-enhanced(Apache-2.0)的
 *     src/main/modules/musicRecognition/kgRecognizer.ts
 *   本文件已修改(Apache-2.0 §4(b)): 改写为 MusicFree 插件格式。
 *
 * ★ 过渡期随 App 内置(rawfile/builtin-plugins, 启动时由 userapi/PluginStore.installBuiltins 自动装上);
 *   平台代码全部挪进来之后再拿出来单独发布。⚠️ 上架前必须从包里拿掉(上架前提: 包里没有平台接口代码)。
 */
'use strict';

const axios = require('axios');
const CryptoJS = require('crypto-js');

// ── 热搜 / 联想(酷我) ───────────────────────────────────────────────────────

const TIP_REFERER = 'http://www.kuwo.cn/';
const HOT_UA = 'Dalvik/2.1.0 (Linux; U; Android 9;)';

async function getHotSearch() {
  const url = 'http://hotword.kuwo.cn/hotword.s?prod=kwplayer_ar_9.3.0.1&corp=kuwo'
    + '&newver=2&vipver=9.3.0.1&source=kwplayer_ar_9.3.0.1_40.apk&p2p=1&notrace=0'
    + '&uid=0&plat=kwplayer_ar&rformat=json&encoding=utf8&tabid=1';
  const res = await axios.get(url, { headers: { 'User-Agent': HOT_UA }, timeout: 10000 });
  const body = typeof res.data === 'string' ? JSON.parse(res.data) : res.data;
  if (!body || body.status !== 'ok' || !Array.isArray(body.tagvalue)) {
    return { data: [] };
  }
  return { data: body.tagvalue.map((it) => it && it.key).filter((k) => typeof k === 'string' && k) };
}

async function getSearchSuggestions(keyword) {
  const kw = String(keyword || '').trim();
  if (!kw) {
    return { data: [] };
  }
  const url = 'https://tips.kuwo.cn/t.s?corp=kuwo&newver=3&p2p=1&notrace=0&c=mbox&w='
    + encodeURIComponent(kw) + '&encoding=utf8&rformat=json';
  const res = await axios.get(url, { headers: { Referer: TIP_REFERER }, timeout: 10000 });
  const body = typeof res.data === 'string' ? JSON.parse(res.data) : res.data;
  if (!body || !Array.isArray(body.WORDITEMS)) {
    return { data: [] };
  }
  return { data: body.WORDITEMS.map((it) => it && it.RELWORD).filter((w) => typeof w === 'string' && w) };
}

// ── 听歌识曲(酷狗: 直接上传原始 PCM, 不需要本地指纹) ─────────────────────────

const ANDROID_KEY = 'OIlwieks28dk2k092lksi2UIkp';
// 设备标识: 上游按 dfid='-' 现算(mid = md5('-') 当无符号大整数, uuid = md5(dfid + mid)), 输入是常量
const DFID = '-';
const MID = '68358509610070717889884130747296293671';
const UUID = '081fffcbe73891679874ed2406088760';
const MAX_RESULTS = 5;

function signParamString(params) {
  return Object.keys(params).sort().map((k) => `${k}=${params[k]}`).join('');
}

function first(o, keys) {
  for (const k of keys) {
    const v = o[k];
    if (v !== undefined && v !== null && String(v)) {
      return String(v);
    }
  }
  return '';
}

function albumOf(o) {
  let al = o.album;
  if (Array.isArray(al)) {
    al = al[0];
  }
  if (typeof al === 'string') {
    return al;
  }
  if (al && typeof al === 'object') {
    const n = first(al, ['albumname', 'album_name', 'name']);
    if (n) {
      return n;
    }
  }
  return first(o, ['album_name']);
}

function singerOf(o) {
  const d = first(o, ['singername', 'singer_name']);
  if (d) {
    return d;
  }
  if (!Array.isArray(o.authors)) {
    return '';
  }
  return o.authors.map((a) => first(a || {}, ['name', 'author_name'])).filter(Boolean).join('、');
}

function coverOf(url) {
  // 酷狗封面地址里的 {size} 占位换成 300(与搜索结果行同档)
  return url ? String(url).replace('{size}', '300') : '';
}

async function recognize(audioBase64, sampleRate, channels) {
  if (!audioBase64) {
    return { isEnd: true, data: [] };
  }
  const pcm = Buffer.from(audioBase64, 'base64');
  const now = Date.now();
  const clienttime = Math.floor(now / 1000);
  const params = {
    dfid: DFID, mid: MID, uuid: UUID, appid: '1005', clientver: '20489', clienttime: String(clienttime),
    fpid: String(now), area_code: '1', include_unpublish: '1', useid: '0', multi_result: '1',
  };
  // 签名 = md5(key + 按名排序拼接的参数 + 原始二进制 body + key)
  const words = CryptoJS.enc.Latin1.parse(ANDROID_KEY + signParamString(params))
    .concat(CryptoJS.lib.WordArray.create(new Uint8Array(pcm)))
    .concat(CryptoJS.enc.Latin1.parse(ANDROID_KEY));
  const sign = CryptoJS.MD5(words).toString();
  const query = Object.keys(params).map((k) => `${k}=${encodeURIComponent(params[k])}`).join('&');
  const res = await axios.post(
    `https://gateway.kugou.com/fingerprint.service/v1/music_trackid_mulit?${query}&signature=${sign}`,
    pcm,
    {
      headers: {
        'content-type': 'application/octet-stream',
        'user-agent': 'KuGou/11490 (Android)',
        dfid: DFID,
        mid: MID,
        clienttime: String(clienttime),
        'kg-rc': '1',
        'kg-thash': '5d816a0',
        'kg-rec': '1',
        'kg-rf': 'B9EDA08A64250DEFFBCADDEE00F8F25F',
      },
      timeout: 8000,
    });
  const body = typeof res.data === 'string' ? JSON.parse(res.data) : res.data;
  if (!body || body.status !== 1) {
    return { isEnd: true, data: [] };
  }
  let items = [];
  if (Array.isArray(body.data)) {
    items = body.data;
  } else if (body.data && typeof body.data === 'object') {
    items = body.data.list || body.data.songs || [];
  }
  const out = [];
  for (const o of items) {
    const base = first(o || {}, ['songname', 'song_name']);
    if (!base) {
      continue;
    }
    const suffix = first(o, ['songNameSuffix', 'song_name_suffix']);
    out.push({
      platform: '酷狗音乐',
      title: suffix ? `${base} (${suffix})` : base,
      artist: singerOf(o),
      album: albumOf(o),
      artwork: coverOf(o.union_cover),
    });
    if (out.length >= MAX_RESULTS) {
      break;
    }
  }
  return { isEnd: true, data: out };
}

module.exports = {
  platform: '无界音乐扩展',
  version: '0.1.0',
  author: '无界音乐',
  description: '热搜词、搜索联想词、听歌识曲',
  getHotSearch,
  getSearchSuggestions,
  recognize,
};
