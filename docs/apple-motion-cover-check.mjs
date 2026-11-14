// Apple Music 动态封面解析 —— 离线端到端核对（不参与构建）
//
// 目的：把 `MotionCoverService` 的两段纯解析逻辑（`parseSearch` / `extractMotion`）照抄成
// 一份可执行的 Node 版本，直接打真机要打的那两个 URL，确认：
//   ① 搜索页还能用 `/artist/ | /album/ | /playlist/` 定位到实体（id + slug）；
//   ② 详情页还能用 `indexOf + 定长截取` 拿到 `video`(m3u8) 与 `url`(previewFrame)；
//   ③ 规格里那几条验收用例仍然成立（周杰伦 / 邓紫棋 有 motion，陈奕迅 / Taylor Swift 没有）。
//
// 用法：
//   node docs/apple-motion-cover-check.mjs            # 跑内置用例
//   node docs/apple-motion-cover-check.mjs 周杰伦 artist
//
// 说明：ArkTS 侧一行为准的是 `common/musicbasic/src/main/ets/services/MotionCoverService.ets`，
//       本文件只做"算法离线可跑"的等价实现；改那边时记得同步这里（或直接看输出的差异）。

const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const STOREFRONT = 'cn';
const MOTION_BLOCK_LEN = 1600;

function normalize(name) {
  return name
    .split('\u2004').join('').split('\u200b').join('').split('\u3000').join(' ')
    .split('\n').join(' ').split('\r').join(' ').split('\t').join(' ')
    .split('（').join('(').split('）').join(')')
    .replace(/  +/g, ' ')
    .trim()
    .toLowerCase();
}

function fillTemplate(url, size) {
  const n = String(size);
  return url.split('{w}').join(n).split('{h}').join(n).split('{c}').join('bb').split('{f}').join('jpg');
}

function parseHref(href, seg) {
  const out = { storefront: '', slug: '', id: '', pageUrl: '' };
  let path = href;
  const hostAt = path.indexOf('music.apple.com/');
  if (hostAt >= 0) path = path.substring(hostAt + 'music.apple.com/'.length);
  const q = path.indexOf('?');
  if (q >= 0) path = path.substring(0, q);
  const parts = path.split('/');
  if (parts.length < 4 || parts[1] !== seg) return out;
  out.storefront = parts[0];
  try { out.slug = decodeURIComponent(parts[2]); } catch { out.slug = parts[2]; }
  out.id = parts[3];
  const cc = out.storefront || STOREFRONT;
  if (seg === 'artist') out.pageUrl = `https://music.apple.com/${cc}/artist/${out.id}`;
  else if (seg === 'album') out.pageUrl = `https://music.apple.com/${cc}/album/${out.id}`;
  else out.pageUrl = `https://music.apple.com/${cc}/playlist/${encodeURIComponent(out.slug)}/${out.id}`;
  return out;
}

function charCoverage(query, candidate) {
  const skip = ' -_|·・,，.。!！?？()（）[]【】/\\';
  let total = 0;
  let hit = 0;
  for (const ch of query) {
    if (skip.includes(ch)) continue;
    total++;
    if (candidate.includes(ch)) hit++;
  }
  return total > 0 ? hit / total : 0;
}
// 注：`parseSearch` 里**没有**用 `charCoverage`（歌单不做相似度硬凑，理由见 ArkTS 侧注释）。
//     保留它只为排查时能手动量一下"两个名字有多像"。
void charCoverage;

function parseSearch(html, kind, name, artist) {
  const seg = kind === 'artist' ? 'artist' : (kind === 'album' ? 'album' : 'playlist');
  const marker = '/' + seg + '/';
  const artistNeedle = artist ? normalize(artist) : '';
  let best = null;
  let bestScore = 0;
  let from = 0;
  let scanned = 0;
  let accepted = 0;
  while (scanned < 900 && accepted < 40) {
    const at = html.indexOf(marker, from);
    if (at < 0) break;
    scanned++;
    from = at + marker.length;
    const hAt = html.lastIndexOf('href="', at);
    const uAt = html.lastIndexOf('"url":"', at);
    let start = -1;
    let skip = 0;
    if (hAt >= uAt && hAt >= 0) { start = hAt; skip = 6; }
    else if (uAt >= 0) { start = uAt; skip = 7; }
    if (start < 0 || at - start > 96) continue;
    const hrefEnd = html.indexOf('"', at);
    if (hrefEnd < 0) continue;
    const href = html.substring(start + skip, hrefEnd);
    const hit = parseHref(href, seg);
    if (!hit.id || !hit.slug) continue;
    accepted++;
    let score = 0;
    const slugNorm = normalize(hit.slug);
    if (slugNorm.indexOf(name) >= 0 || name.indexOf(slugNorm) >= 0) score += 3;
    if (artistNeedle) {
      const near = html.substring(Math.max(0, start - 1600), Math.min(html.length, hrefEnd + 1600)).toLowerCase();
      if (near.indexOf(artistNeedle) >= 0) score += 2;
    }
    if (score > bestScore) { bestScore = score; best = hit; }
    if (score >= 5) break;
  }
  return bestScore >= 3 ? { hit: best, score: bestScore } : { hit: null, score: bestScore };
}

function firstGroup(block, which) {
  const key = which === 0 ? '"video"' : '"url"';
  const at = block.indexOf(key);
  if (at < 0) return '';
  const colon = block.indexOf(':', at + key.length);
  if (colon < 0) return '';
  let start = colon + 1;
  while (start < block.length && block.charAt(start) === ' ') start++;
  if (block.charAt(start) !== '"') return '';
  start++;
  const end = block.indexOf('"', start);
  return end > start ? block.substring(start, end) : '';
}

const MOTION_KEYS = ['motionArtistSquare1x1', 'motionDetailSquare', 'motionArtistWide16x9',
  'motionDetailTall', 'motionArtistFullscreen16x9', 'motionDetailFullscreen'];

function extractMotion(html) {
  const text = html.split('\\"').join('"');
  for (const k of MOTION_KEYS) {
    const at = text.indexOf('"' + k + '":');
    if (at < 0) continue;
    const block = text.substring(at, Math.min(text.length, at + MOTION_BLOCK_LEN));
    const video = firstGroup(block, 0);
    if (!video) continue;
    const posterRaw = firstGroup(block, 1);
    return { field: k, video, poster: posterRaw ? fillTemplate(posterRaw, 900) : '' };
  }
  return null;
}

async function getHtml(url) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': UA,
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Accept': 'text/html,application/xhtml+xml'
    }
  });
  if (res.status !== 200) return { status: res.status, html: '' };
  return { status: res.status, html: await res.text() };
}

async function check(kind, name, artist = '') {
  const q = normalize(name);
  const t0 = Date.now();
  const searchUrl = `https://music.apple.com/${STOREFRONT}/search?term=${encodeURIComponent(q)}`;
  const search = await getHtml(searchUrl);
  const parsed = parseSearch(search.html, kind, q, artist);
  const row = { kind, name, searchStatus: search.status, searchKB: Math.round(search.html.length / 1024),
    id: '-', slug: '-', motion: 'none', field: '-', ms: 0 };
  if (parsed.hit) {
    row.id = parsed.hit.id;
    row.slug = parsed.hit.slug;
    row.score = parsed.score;
    const page = await getHtml(parsed.hit.pageUrl);
    row.pageStatus = page.status;
    row.pageKB = Math.round(page.html.length / 1024);
    const motion = page.html ? extractMotion(page.html) : null;
    if (motion) {
      row.motion = 'hit';
      row.field = motion.field;
      row.videoTail = motion.video.split('/').pop();
      row.posterTail = motion.poster.split('/').pop();
    }
  }
  row.ms = Date.now() - t0;
  return row;
}

const cases = process.argv.length > 3
  ? [[process.argv[3], process.argv[2], process.argv[4] ?? '']]
  : [
      ['artist', '周杰伦'],
      ['artist', '邓紫棋'],
      ['artist', '陈奕迅'],
      ['artist', 'Taylor Swift'],
      ['album', '范特西', '周杰伦'],
      ['playlist', '华语流行']
    ];

const rows = [];
for (const [kind, name, artist] of cases) {
  try {
    rows.push(await check(kind, name, artist ?? ''));
  } catch (err) {
    rows.push({ kind, name, id: '-', motion: `error: ${err.message}` });
  }
}
console.table(rows);
console.log('\n判据：');
console.log('  1) 周杰伦 / 邓紫棋 应 motion=hit 且 field=motionArtistSquare1x1（规格 §9）');
console.log('  2) 陈奕迅 / Taylor Swift 应 id 有值、motion=none（规格 §9：无投放）');
console.log('  3) album / playlist 行：id 有值即可（有没有 motion 取决于 Apple 是否给该实体投放）');
