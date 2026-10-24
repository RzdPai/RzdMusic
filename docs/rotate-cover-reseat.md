# 转屏错位（横屏打开播放器 → 切竖屏，封面/歌名/歌手整块偏右上）— 根因与修法

- 日期：2026-10-24
- 基线：`98cc2ad`（上一轮转屏"候选"，甲方实测仍错位）
- 构建：`261024-1349`，`BUILD SUCCESSFUL`，HAP 24,051,396 B，已上传 WebDAV
  `https://pan.rzdpai.com/dav/RzdMusic-default-signed.hap`
- 验证等级：**源码级 + 编译级 + 产物级**（`hdc list targets` = Empty，未上机）

---

## 1. 甲方现象

> 竖屏打开播放器 → 横竖来回切都正常；
> **横屏打开播放器 → 切到竖屏**，封面、歌手、歌名一起往**右上角**偏（截图 `screenshot_20261024_133403`）。

截图逐项对照（预览 840×1904 ↔ 真机 363×823 vp）：

| 项 | 截图里 | 应得 | 说明 |
| --- | --- | --- | --- |
| 封面宽 | ≈ 屏宽 51%（≈ 183vp） | 331vp（91%） | 尺寸还停在**横屏实测** 172.3 × 播放缩放 |
| 封面左缘 | ≈ 150vp | 16vp（水平居中） | x 还停在横屏值 `bigX≈141.4` |
| 歌名行顶 | ≈ 312vp | 517vp | 歌名行 = **封面底边 + 50**，跟着封面一起上移 |
| 顶栏 / 进度条 / 传输键 | 正常 | — | 它们是**流式布局**，不读端点 |

⇒ 症状的形状不是"整体平移"，而是"**读端点的整块（封面 + 歌名 + 歌手 + 小歌词）**用旧朝向的值摆位"。
这正是"顶栏/进度条不偏、只有这一块偏"的原因。

## 2. 根因（两条，缺一不可）

### ① 竖屏那一支的封面**是端点画出来的**，所以"量节点"永远等于量自己

`PlaybackPage.buildControlStack()` 里，手机竖屏走的是：

```
else { Swiper(...) ; if (usesPhoneSwiperLayout() && !usePanelLayout()) { LyricFloatLayer() } }
```

`LyricFloatLayer()` 里那张封面与歌名行的位置/尺寸**全部**来自几何函数：

```
Image().width(coverLocalRect().size).position({ x: coverLocalRect().x, y: coverLocalRect().y })
Column().offset({ y: metaOffsetY() })      // = metaTopGeomY(0,34) − (estBoxHVp()−34)/2
```

而 `coverLocalRect()` → `lyricMorph(t)` → `bigEndpointRect()`：

```
if (endCoverSize > 0 && snapStartW > 0) → morphCoverRectAt(1)   // ← 用 endCover*
else if (playerCoverWidth() > 0)        → { bigX, bigY, bigSize }
else                                    → playerCoverGeomRect()  // 纯几何兜底
```

这张封面自己又挂着 `.onAreaChange → reportPlayerCoverFromOverlay → reportBig()`，
把**它当前的位置**写回 `bigX/bigY/bigSize`。⇒

```
端点 endCover*/big*  →  画在 (x,y,size)  →  onAreaChange 上报 (x,y,size)  →  写回 big*
```

一旦端点是横屏的旧值，画出来的就是旧值，量到的当然还是旧值 —— **自锁**。
上一轮日志就是这个形状（`RzdCoverRect` / `RzdProbe`）：

```
coverReport pos=-88.4 bigX=141.4 win=823x363     （横屏）
coverReport pos=141.5 bigX=-88.4 win=363x823     （转竖屏后，两份数正好互换）
```

### ② `endCover*` 只在形变**起手**时冻结一次，转屏不会重跑它（上一轮修不动的直接原因）

`morphInitParams()`（`:3376-3378`）是**唯一**写 `endCoverX/Y/Size/H` 的地方；
而 `lyricMorph()` 优先读的正是 `endCover*`。上一轮的做法是转屏后调
`measureEndAnchor()` + `measureGeometry()` —— 它们只写 `bigNode*`/`bigX` 之类，
**一个字节都没改到 `endCover*`** ⇒ 屏上那张封面不可能动。
（这也解释了为什么当时日志里 `ok=1`、`big=…` 都正常，画面却不变。）

## 3. 修法（两支分流，互不干扰）

### 3.1 `PlayerExpandState`（`common/musicbasic`）

1. **新增 `reseatBigEndpointForWindow(widthVp, heightVp)`** —— 换窗口时按**纯几何**重建端点：
   - 几何 = `playerCoverGeomRect()`（= 上游 `CoverMorph`/`fitPlayerOverlay` 那套
     `edge = clamp(min(swiperBoxW − 2·pageSide, availH − 2·(gap+metaH+8)), 200, 480)`、
     `metaY = edge/2 + gap + metaH/2`）；
   - 同时写：`bigX/bigY/bigSize/bigRadius`（上报口径）、`bigNodeX/Y/W/H + bigNodeKnown`
     （实测口径）、**`endCoverX/Y/Size/H`（真正决定绘制的那一份）**；
   - `windowWidthVp/HeightVp` 用**调用方给的新窗口**落一层，避免与 `reportWindow()` 的回调先后耦合。
2. `playerCoverGeomRect()` 拆成 `coverGeomFor(w, h)` + 一行转发（几何只有一份实现）。
3. **`endCoverX/Y/Size/H` 改 `@Trace`**：读它们的 `lyricMorph()`/`metaTopGeomY()` 是**纯函数链**，
   链上没有别的 `@Trace` 属性 ⇒ 不标 `@Trace` 时写进去不会触发重绘（看起来像"没生效"）。

### 3.2 `PlaybackPage`（`features/player`）

1. 新增 `usesFloatingCoverLayout()`，判据与渲染处**逐字一致**
   （`usesPhoneSwiperLayout() && !usePanelLayout()`）——"屏上那张封面是谁画的"决定用哪支口径。
2. 新增 `reseatFloatingCover(reason)`：把 `windowInfo.windowSize`（px）换成 vp 交给
   `reseatBigEndpointForWindow()`，并打 `RzdRotate cover-reseat`。
3. `refreshBgMeshOnResize()` 拆成两段：**先** `refitCoverOnWindowChange(w,h)`（端点重建），
   **再**处理背景网格。原来写在背景分支里的 `return` 会把端点重建整段跳过（背景有没有缓存
   与封面在哪儿无关）。
   - `refitCoverOnWindowChange()`：
     - 竖屏浮层那一支 → `reseatFloatingCover('rotate')` + `+200ms` 再算一次（纯函数幂等，
       等让位量测 `statusBarTopVp`/`pageBoxTopVp` 落定后更准）；
     - 横屏左栏 / 平板分栏（流式布局封面）→ 原逻辑 `measureEndAnchor()` + `measureGeometry()`
       + `syncBigSizeFromNode()`。
4. 新增 `@Monitor('windowInfo.windowSize')` → `refreshBgMeshOnResize()`。
   原因：根节点 `onAreaChange` 与 `windowInfo` 更新**没有先后保证**；根节点那一拍读到旧 px 就早退，
   等 `windowInfo` 更新后根节点矩形已经不变 ⇒ `onAreaChange` 不再触发 ⇒ **一次都不修**。
5. 删掉上一轮的成套补丁（它们改的是 `bigX`，与 `endCover*` 无关，逻辑上不可能生效）：
   `anchorFixUntil` 冷静期 / `80·240·480ms` 反复重设 `bigX` / `coverLayerMounted` 重挂浮层 /
   `flatCoverBox*` 清零 / `hide=0` 的 `window-anchor-invalidate` / `+48ms`、`+150ms` 补量。

## 4. 离线复算（`docs/rotate-cover-geometry-check.mjs`）

```
node docs/rotate-cover-geometry-check.mjs
```

| 场景（363×823 vp） | 封面 (x, y, edge) | 占屏宽 | 歌名行顶 |
| --- | --- | --- | --- |
| 修前（端点=横屏实测 172.3） | (141.4, 60, 172.3) | 47% | 282 |
| 修后（纯几何） | **(16.0, 136, 331)** | **91%** | **517** |

⇒ 与截图的三处偏差（偏小、偏右、歌名偏高）逐项吻合。

## 5. 上机怎么验（甲方一步）

1. 装 `RzdMusic-default-signed.hap`（构建戳 `261024-1349`，设置→关于可见）；
2. **横屏**打开播放器 → 等 1 秒 → 转竖屏：封面应回到"水平居中、宽 ≈ 91%"、歌名在封面下方；
   再切回横屏、再切回竖屏，重复几轮都应稳定；
3. 设置 → 运行日志，看这两行（`grep` 关键字）：
   - `RzdRotate cover-reseat rotate cover=(16.0,136.0,331.0) win=363x823`
     —— `cover=` 三个数应等于上表"修后"；`rotate+200` 那一行应与之一致（不一致说明让位量测在 200ms 内还在变）；
   - `RzdBgPhase window-anchor-remeasure`：**竖屏浮层这一支不应再出现**（它只跑横屏/平板）。

## 6. 已知边界（如实记）

1. **转屏发生在形变动画中途**（ENTERING/LEAVING/LANDING）时不重建端点（`atRest` 门）：
   此时重建会把动画目标/起点搬走。`ENTERING` 那条由 `PlayerExpandState.abortTransitionOnResize()`
   直接落位兜底；`LEAVING` 中途转屏仍是老行为（未验证）。
2. 纯几何里 `topInsetVp()` 依赖让位量测（`statusBarTopVp` / `pageBoxTopVp`），它们**可能**比转屏晚到；
   所以安排了 `+200ms` 的第二次重算。若真机上第一个日志 `cover=` 与第二个不同，把 200 改大即可
   （纯函数重算没有副作用）。
3. 本轮**没有设备**（`hdc list targets` Empty），所有结论为源码/编译/产物级；
   像素级是否与"竖屏正常打开"完全一致，仍需甲方上机比对。

## 7. 改动文件

| 文件 | 改动 |
| --- | --- |
| `common/musicbasic/src/main/ets/model/PlayerExpandState.ets` | `reseatBigEndpointForWindow()` 新增；`playerCoverGeomRect()` → `coverGeomFor(w,h)`；`endCover*` 改 `@Trace` |
| `features/player/src/main/ets/view/PlaybackPage.ets` | `usesFloatingCoverLayout()` / `reseatFloatingCover()` / `refitCoverOnWindowChange()` 新增；`@Monitor('windowInfo.windowSize')` 新增；删上一轮 5 处补丁 |
| `docs/rotate-cover-geometry-check.mjs` | 离线复算脚本（不参与构建） |
| `features/setting/.../string.json` ×2 | 构建戳 `261024-1349` |

无新增依赖、无新增权限。
