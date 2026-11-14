# Apple Music 动态封面（motion artwork）—— 实现规格与落点

> 本文是甲方给的纯 SSR 规格原文（原文件名 歌手页.md），本仓落点见文末「§本仓落点」。

---

# Apple Music 封面 / 动态封面 —— 纯 SSR 实现规格

> 给实现方（人或 Agent）的技术说明。
>
> **输入一个歌手名，输出他的封面图和动态封面视频。全程只抓 `music.apple.com` 的 HTML，不需要任何 token、不需要 Apple Developer 账号。**

## 0. 为什么不走 iTunes Search API

`itunes.apple.com/search` 虽然公开、免 token、还带 `Access-Control-Allow-Origin: *`，但它的返回里**没有** `editorialVideo` 字段，无论怎么组合参数都拿不到动态封面。它只能给基础信息和 30 秒试听。

所以本方案完全不用它。所有数据从网页 SSR 里取。

## 1. 整体流程

```
输入 "周杰伦"
   ↓  请求 1：搜索页
GET https://music.apple.com/cn/search?term=周杰伦
   ↓  正则解析
artistId = 300117743, 名字 = 周杰伦, 封面 = https://is1-ssl.mzstatic.com/...
   ↓  请求 2：艺人页
GET https://music.apple.com/cn/artist/300117743
   ↓  正则解析
motion.video = https://mvod.itunes.apple.com/.../xxx_default.m3u8
motion.poster = https://is1-ssl.mzstatic.com/.../900x900bb.jpg
```

两个请求，约 1.5MB，1~2 秒。之后按 `artistId` 缓存。

## 2. 请求 1：搜索页（名字 → id + 封面）

```http
GET https://music.apple.com/{storefront}/search?term={urlencoded_name}
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36
Accept-Language: zh-CN,zh;q=0.9
```

- `storefront`：`cn` `hk` `tw` `us` `jp`
- 返回约 **878KB** 的完整 HTML，搜索结果直接在 DOM 里（不是客户端渲染）

### 2.1 提取 artistId 与名字

HTML 里的结构：

```html
<a data-testid="click-action" class="click-action svelte-c0t0j2"
   href="https://music.apple.com/cn/artist/%E5%91%A8%E6%9D%B0%E4%BC%A6/300117743"
   aria-label="周杰伦 · 艺人"></a>
```

用 href 里的 slug 解码拿名字，**不要用 aria-label**——它中间是 `U+2004`（三分空格），不是普通空格，正则很容易写错。

```
正则：href="https://music\.apple\.com/([a-z]{2})/artist/([^"/]+)/(\d+)"
```

取**第一个匹配**（页面顶部的 top result）。

- 组 1 = storefront（`cn`）
- 组 2 = URL 编码的 slug，`decodeURIComponent` 后得到 `周杰伦`
- 组 3 = `artistId`（`300117743`）

> 一个搜索页里有 30+ 个 `/artist/` 链接（推荐、相关艺人）。第一个是精确匹配结果，其余不是。建议对组 2 解码后的名字做一次包含性校验，防止搜"陈奕迅"却拿到别人。

### 2.2 提取封面

在匹配位置往后 2600 字符内找第一个 mzstatic 图片：

```
正则：https://is\d-ssl\.mzstatic\.com/[^"\s]+
```

得到的是模板：

```
https://is1-ssl.mzstatic.com/image/thumb/AMCArtistImages211/v4/6d/53/0e/.../ami-identity-xxx.png/{w}x{h}bb.jpg
```

替换占位符才是可用的图：

```
{w} → 600    {h} → 600    {c} → bb    {f} → jpg
```

> 艺人页 / 专辑页的模板是 `{w}x{h}{c}.{f}`（四个占位符），搜索结果里也可能出现 `bb.jpg` 这种三占位符形式。统一按四个都替换，多余的无副作用。

## 3. 请求 2：艺人页（id → 动态封面）

```http
GET https://music.apple.com/{storefront}/artist/{artistId}
```

- 返回 470~690KB HTML
- 动态封面在 SSR 的 JSON 里，字段和官方 API 一致，但引号被转义（`\"`）

### 3.1 结构

```html
"videoArtwork":{"dictionary":{"motionArtistSquare1x1":{
  "previewFrame":{"url":"https://is1-ssl.mzstatic.com/.../{w}x{h}{c}.{f}"},
  "video":"https://mvod.itunes.apple.com/.../P1325649700_default.m3u8"}}}
```

可用字段（按优先级）：

```
motionArtistSquare1x1        1:1   3840×3840   手机竖屏
motionArtistWide16x9         16:9  3840×2160   平板/横屏
motionArtistFullscreen16x9   16:9  3840×2160
```

专辑页（`/{cc}/album/{albumId}`）用另一组：

```
videoArtwork.dictionary.motionDetailSquare        1:1
tallVideoArtwork.dictionary.motionDetailTall      3:4
```

### 3.2 解析步骤

1. 反转义：`html.replace(/\\"/g, '"')`
2. 定位：`text.indexOf('"motionArtistSquare1x1":')`
3. **从该位置截取 1400 字符**，在片段内分别匹配：
   - `/"video"\s*:\s*"([^"]+)"/`
   - `/"url"\s*:\s*"([^"]+)"/`
4. 图片模板替换 `{w}{h}{c}{f}`

不要用 `/"motionArtistSquare1x1":\{.*?"video"/` 这类跨段的懒匹配——HTML 是一整行压缩的，`.*?` 跨字段误匹配的概率很高。

### 3.3 艺人页还能拿到

- 高清艺人图：`"artwork":{...,"url":"https://is1-ssl.mzstatic.com/.../{w}x{h}{c}.{f}"}`（原图 963×963 起）
- 专辑列表：`"collectionId"` + `"collectionName"`
- 无 `editorialVideo` 时，`videoArtwork` 字段直接不存在

## 4. 输出结构

```json
{
  "id": "300117743",
  "name": "周杰伦",
  "storefront": "cn",
  "artwork": "https://is1-ssl.mzstatic.com/.../600x600bb.jpg",
  "motion": {
    "field": "motionArtistSquare1x1",
    "video": "https://mvod.itunes.apple.com/.../P1325649700_default.m3u8",
    "poster": "https://is1-ssl.mzstatic.com/.../900x900bb.jpg",
    "aspect": "1:1"
  }
}
```

没有动态封面时 `motion` 为 `null`，`artwork` 仍然可用。

## 5. ArkTS 实现骨架

```ts
interface ArtistProfile {
  id: string;
  name: string;
  storefront: string;
  artwork: string;
  motion: MotionClip | null;
}

const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
           '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

async function getHtml(url: string): Promise<string> {
  const req = http.createHttp();
  try {
    const res = await req.request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': UA, 'Accept-Language': 'zh-CN,zh;q=0.9' },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 25000
    });
    return res.result as string;
  } finally {
    req.destroy();
  }
}

function fillTpl(url: string, size: number): string {
  return url.replace('{w}', size.toString())
            .replace('{h}', size.toString())
            .replace('{c}', 'bb')
            .replace('{f}', 'jpg');
}

async function resolveArtist(name: string, cc: string = 'cn'): Promise<ArtistProfile | null> {
  // ---- 1. 搜索页 ----
  const html = await getHtml(
    `https://music.apple.com/${cc}/search?term=${encodeURIComponent(name)}`);

  const m = html.match(/href="https:\/\/music\.apple\.com\/([a-z]{2})\/artist\/([^"\/]+)\/(\d+)"/);
  if (!m) return null;

  const storefront = m[1];
  const id = m[3];
  const displayName = decodeURIComponent(m[2]);

  // 封面：匹配位置后 2600 字符内第一张图
  const at = html.indexOf(m[0]);
  const seg = html.slice(at, at + 2600);
  const am = seg.match(/https:\/\/is\d-ssl\.mzstatic\.com\/[^"\s]+/);
  const artwork = am ? fillTpl(am[0], 600) : '';

  // ---- 2. 艺人页 ----
  const page = await getHtml(`https://music.apple.com/${storefront}/artist/${id}`);
  const text = page.replace(/\\"/g, '"');

  let motion: MotionClip | null = null;
  const keys = ['motionArtistSquare1x1', 'motionArtistWide16x9', 'motionArtistFullscreen16x9'];
  for (const k of keys) {
    const i = text.indexOf('"' + k + '":');
    if (i < 0) continue;
    const block = text.slice(i, i + 1400);
    const v = block.match(/"video"\s*:\s*"([^"]+)"/);
    if (!v) continue;
    const p = block.match(/"url"\s*:\s*"([^"]+)"/);
    motion = {
      field: k,
      video: v[1],
      poster: p ? fillTpl(p[1], 900) : '',
      aspect: k.indexOf('Square') >= 0 ? '1:1' : '16:9'
    };
    break;
  }

  return { id, name: displayName, storefront, artwork, motion };
}
```

## 6. 缓存策略

| 数据 | key | TTL | 说明 |
|---|---|---|---|
| 搜索词 → id | `s_{cc}_{term}` | 7 天 | 艺人 id 基本不变 |
| 艺人页结果 | `a_{cc}_{id}` | 24 小时 | **`motion` 为 null 也要缓存** |
| m3u8 | 不缓存 | — | 交给播放器 / CDN |

负结果缓存很重要：没有投放 motion 的艺人（陈奕迅、林俊杰、五月天）占多数，不缓存的话每次进页面都要重拉 690KB。

## 7. 播放

- m3u8 是**明文 HLS**，清单里没有 `EXT-X-KEY`，不需要任何解密，与音频的 FairPlay / Widevine 无关。
- 原生端：AVPlayer / ArkUI `Video` 组件直接吃 URL，`muted + loop + autoPlay`。
- Web 端：Chrome 需 hls.js，Safari 原生支持。
- 起播优化：hls.js 设 `startLevel: 0`（最低码率先出画面）、`maxBufferLength: 4`。
- 首帧占位：用 `previewFrame`，它与视频第一帧对齐，淡入无跳变。
- 离屏暂停：`onVisibleAreaChange`，多实例会抢解码器。

## 8. 必踩的坑

| 现象 | 原因 | 处理 |
|---|---|---|
| curl 200，浏览器 fetch 403 | 请求带 `Origin`，Apple 用它做防盗链 | **必须不带 Origin**；浏览器端无解，只能原生请求或走代理 |
| 正则匹配不到 `aria-label` | 名字和"艺人"之间是 `U+2004` | 别用 aria-label，用 href 的 slug 解码 |
| 图片 404 | `{c}`（crop code）没替换 | 四个占位符 `{w}{h}{c}{f}` 全部替换 |
| `"video"` 匹配到别处 | HTML 压缩成一行，`.*?` 跨段 | indexOf 定位 + 定长截取 |
| 搜"陈奕迅"拿到别人 | 第一个 artist 链接不一定精确 | 对解码后的名字做包含校验 |
| 名字简繁不一致 | storefront 决定显示语言 | `cn` 返回简体，`hk`/`tw` 返回繁体，属正常 |
| 每次进页面都慢 | 没缓存 null | 负结果也写缓存 |
| 视频一直不出来 | `canplay` 没触发 | 同时监听 `FRAG_LOADED` 和 `canplay` |

## 9. 验收用例

| 输入 | 期望 |
|---|---|
| `周杰伦`（cn） | id `300117743`，封面有值，`motion.field = motionArtistSquare1x1` |
| `邓紫棋`（cn） | id `425208570`，`motion.field = motionArtistSquare1x1` |
| `陈奕迅`（cn） | id `137938148`，封面有值，`motion = null` |
| `Taylor Swift`（us） | 封面有值，`motion = null`（截至 2026-10 无投放） |

验证命令：

```bash
# 1. 搜索页能解析出 id 和名字
curl -s "https://music.apple.com/cn/search?term=%E5%91%A8%E6%9D%B0%E4%BC%A6" \
  | grep -o 'href="https://music.apple.com/[a-z]*/artist/[^"]*"' | head -1

# 2. 艺人页有 motion 字段
curl -s "https://music.apple.com/cn/artist/300117743" \
  | grep -o 'motionArtist[A-Za-z0-9]*' | sort -u

# 3. 带 Origin 必须 403（反证：浏览器直连不可行）
curl -s -o /dev/null -w '%{http_code}\n' -H 'Origin: http://x' \
  https://music.apple.com/cn/artist/300117743
```

---

## §本仓落点（RzdMusic，2026-10-24）

| 层 | 文件 | 职责 |
| --- | --- | --- |
| 设置开关 | `MusicStoreService.getMotionCoverEnabled()/setMotionCoverEnabled()` + `MotionCoverState`（默认**开**） | 「其它设置 → 动态封面」；`AppStorageV2` 共享，三页即时生效 |
| 解析 | `common/musicbasic/src/main/ets/services/MotionCoverService.ets` | 搜索页 → 详情页 → `motion*`；`preferences('rzd_motion_cover')` 二级缓存（搜索 7 天 / 实体 24 小时，**负结果也缓存**） |
| 渲染 | `common/musicbasic/src/main/ets/view/MotionCoverLayer.ets` | 盖在静图之上的 `Video`：`muted + loop + autoPlay + previewUri`，起播后淡入，失败退回静图 |
| 接入点 | `DetailImmersiveBackdrop`（歌手页 / 专辑页）· `PlaylistImmersiveBackdrop`（歌单页） | 三页共用同一套照片层，故"动态封面"只加在这一处 |

### 与规格的差异 / 补充
1. **搜索页里实体地址有两种写法**：`href="https://music.apple.com/…"` 与内嵌 JSON 的 `"url":"…"`。
   前者出现在页面**后半段**（前面几百个 `/artist/`、`/playlist/` 全是 JSON 里的），
   所以"扫描上限（900 个 marker）"与"采纳上限（40 个解析成功的候选）"必须分开计数，
   否则真正的链接还没走到就放弃了（这一条是实测踩出来的）。
2. **歌单不做相似度硬凑**：Apple 的编辑歌单名和我们的歌单名大多不同，
   「华语流行」≠「热播金曲-国语流行」；硬凑会把**别的歌单的封面**播出来。
   ⇒ 只接受包含关系（「国语流行」⊂「热播金曲-国语流行」可以，纯相似度不行）。
3. **Album / 歌单是否动，取决于 Apple 有没有给该实体投放 motion**（与 Apple Music 本身一致）。
   实测（2026-10-24）：周杰伦《最伟大的作品》=hit、Taylor Swift《Midnights》=hit、《范特西》=none。
4. 缓存 key 过 48 字符会折成 `h_<hash>`（`preferences` 的 key 有长度上限，中文实体名很容易超）。

### 离线核对脚本
```bash
node docs/apple-motion-cover-check.mjs          # 走规格 §9 的四个验收用例 + 专辑 + 歌单
node docs/apple-motion-cover-check.mjs 周杰伦 artist
```
脚本 = `MotionCoverService` 两段纯解析逻辑的等价实现，直接打真机要打的那两个 URL。