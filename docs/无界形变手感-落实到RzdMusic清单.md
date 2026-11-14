# 无界形变手感 → RzdMusic 落实清单

> **给执行 Agent 的任务书。** 目标：把「无界音乐 1.2.4」逆向出来的形变手感，对齐到 RzdMusic **已有的**实现上。
>
> ## ⚠️ 先读这三条
> 1. **不要重写。** RzdMusic 里已经有一套完整实现（`PlayerExpandState.ets` 2076 行 + `PlaybackPage.ets` 的驱动），
>    **大部分公式与无界一致**（下面「已经对了、别动」那节列了）。本任务只做**差异修补**。
> 2. **RzdMusic 是 V2**（`@ComponentV2` 97 处 / `@Component` 3 处），**不存在 V1→V2 迁移问题**。
>    无界那边全是 V1（`ViewPU`），**照抄它的写法会引入 V1 装饰器 —— 那是错的**，只抄数值和算法。
> 3. **本文所有「无界」数值都有字节码出处**，来源文档见文末。RzdMusic 的行号是实测的，可直接跳转。

---

## 一、权威数值（无界侧，已逆向定稿）

### 1.1 跟手归一化 —— **绝对映射，不累加**

```ts
// 无界 MainPage.pullUpdate(dy)
morphT = clamp(-vp2px(dy) / pullRangePx, 0, 1)

// 分母优先用**实测**的封面顶边距，拿不到才退回窗口比例
pullRangePx = coverRect.top > 0 ? coverRect.top : windowHeight * 0.32   // PULL_RANGE_RATIO
```

**⚠️ 这是位移的纯函数，不读上一帧。** 累加式（`+= 步长`）在快速拖动时会漂移。

### 1.2 提交判定 —— **进度 OR 速度**

```ts
commit = (morphT >= COMMIT_T /*0.32*/) || (velocity <= COMMIT_VELOCITY /*900*/)
```

`velocity` 来自 `PanGesture.velocityY`（**向下为正**）。下拉收起时向下甩 = 取消意图
→ `velocity > 900` 不满足 `<= 900` → 回弹。

### 1.3 两条驱动路径共用的参数（`ExpandAnimation.applyPullProgress`）

全是 `init → final` 的线性插值：

```ts
scaleValue = initScale      + (1 - initScale) * p
translateX = initTranslateX * (1 - p)
translateY = initTranslateY * (1 - p)
clipWidth  = "100%"                                  // 恒定
clipHeight = initClipHeight + (fullClipHeight - initClipHeight) * p
```

`initParams` 的五个公式（**已做几何推导验证，两端严丝合缝**）：

```ts
const s = srcBox.width / WindowInfo.windowWidth_px;
initScale      = s;
initClipHeight = px2vp(srcBox.height / s);
fullClipHeight = px2vp(WindowInfo.windowHeight_px);
initTranslateX = px2vp(srcBox.left - (WindowInfo.windowWidth_px - srcBox.width) / 2);
initTranslateY = px2vp(srcBox.top  - (srcBox.height / s - srcBox.height) / 2);
```

**几何含义**：容器是「整窗大小」的盒子，绕中心缩放 `s`、叠一个 `translate`，
再 `clip` 到 `clipHeight`。`t=0` 时精确覆盖源矩形，`t=1` 时正好铺满整窗。

### 1.4 圆角

```ts
coverVisualRadiusAt(t) = lerp(vp(miniCover.width) / 2, targetCoverRadius, t)   // 起点 = 宽度一半（正圆）
coverRadiusAt(t)       = coverVisualRadiusAt(t) / coverScaleAt(t)              // ★ 必须除 scale
```
**目标圆角是绝对值 `34`**（`doEnter` 的目标态 `radius = 34`），不是比例。

### 1.5 三层淡入窗口 + 两条淡出

| 量 | 无界公式 |
| --- | --- |
| `metaOpacityAt` | `clamp(1 - t/0.35, 0, 1)` |
| `actionsOpacityAt` | `clamp(1 - t/0.20, 0, 1)` |
| `pullBgIn` | `clamp(effT/0.30, 0, 1)`（下限 `PULL_BG_FLOOR = 0.04`） |
| `pullChromeOpacity` | `clamp((effT-0.18)/0.44, 0, 1)` |
| `pullBottomIn` | `clamp((effT-0.45)/0.55, 0, 1)` |

`effT` 是**闸门**不是缓动：`get effT() { return this.isMorphTarget() ? this.pullT : 1; }`
`isMorphTarget() = ExpandSnapshot.morphLive && this.mySeq === ExpandSnapshot.morphSeq`

### 1.6 时长/缓动（**两套，别混**）

| 用途 | 时长 | 缓动 |
| --- | --- | --- |
| 播放页内快照（`doEnter`） | **350** | `Curve.EaseInOut` |
| 淡入（`doEnter` 另外两组） | **100**（一组 `delay: 50`） | `Curve.Sharp` |
| 浮层拷贝的 `morphT` 补间（`animateMorphT`） | **560** | `"cubic-bezier(0.23, 1.0, 0.32, 1.0)"` |
| 收起方向 | **460** | `"cubic-bezier(0.85, 0, 0.5, 0.88)"` |

---

## 二、RzdMusic 现状（实测，带行号）

**活的驱动链**：`PlaybackPage.onDismissDrag(offsetY, ended)`

| 位置 | 内容 |
| --- | --- |
| `features\player\src\main\ets\view\PlaybackPage.ets` **L265-316** | `onDismissDrag` 主体 |
| 同文件 **L2248-2256** | `PanGesture(this.panOption).onActionUpdate((e) => onDismissDrag(e.offsetY, false)).onActionEnd((e) => onDismissDrag(e.offsetY, true))` |
| 同文件 **L238-240** | `dismissSpanVp() = deviceHeightVp() * DISMISS_DRAG_SPAN_RATIO` |
| 同文件 **L247-254** | `dismissProgressFromDrag(offsetY) = clamp(offsetY / span * 100, 0, 100)` |
| 同文件 **L226** | `DISMISS_COMMIT_PROGRESS = 38` |
| 同文件 **L224** | `DISMISS_DRAG_SPAN_RATIO = 0.42` |
| 同文件 **L146/158/165** | `MORPH_OPEN_DURATION_MS = 350` / `MORPH_CLOSE_DURATION_MS = 350` / `MORPH_INTRO_DELAY_MS = 50` |
| `common\musicbasic\src\main\ets\model\PlayerExpandState.ets` | 状态与公式（2076 行） |

**两套 API 并存（要注意）**：
- **活的**：`morphUsable` / `morphBeginLeaving()` / `applyMorphProgress(v)` / `morphSettleOpen()` /
  `morphDrive` / `morphGen` / `morphGenAlive(gen)` / `morphSessionDriving()` / `reportBig()` / `reportMini()`
- **像是遗留的**：`pullProgressFrom` / `pullShouldCommit` / `beginPullOpen` / `updatePull` / `endPullOpen` /
  `PULL_COMMIT_PROGRESS = 55` —— **全仓没有任何调用点**（我扫过 features/common/products 下全部 `.ets`）

> **待办第 0 项**：确认那套遗留 API 是否真的死了。若确认，**删掉** —— 两套并存会让后面的人改错地方。

---

## 二·补、★★ 两条**架构级**差异（比第四节的数值差异重要得多）

> 用户指出：「RzdMusic 的 UI 飞入逻辑也和无界明显不一样，还有无界的播放页歌词上面也有歌曲封面和名称」。
> 这两条我实测确认成立，**它们不是调参能解决的，是要先做架构决策**。

---

### A1（架构级）飞入的实现方式根本不同

| | **无界** | **RzdMusic（现状）** |
| --- | --- | --- |
| 跨页浮层 | **有** —— `MainPage.MorphOverlayHost`，全屏、由 AppStorage 的 `lx_pull_active` 门控 | **没有** |
| 飞的是什么 | **重绘的一份拷贝**（`morphCover` / `morphMiniMeta` / `morphActions`），挂在浮层里、在 MainPage 坐标系 | **播放页自己的根 Stack 做缩放/位移**（`MORPH_HOST_ID` 注释：「手机侧就是播放页自己的根 Stack」） |
| 迷你条本体 | 被 `emptyMiniSlot()`（空 `Column`）顶掉 | 用 `miniBarOpacity()` 淡出「交棒给播放页」 |
| 下半层 | `ExpandAnimation` 驱动播放页快照（`scaleValue`/`translate`/`clipHeight`），**350ms EaseInOut** | 播放页整体缩放展开 |
| 交接开关 | `AppStorage[lx_pull_active]`（6 个写入点，只有 `setMiniOut` 能写 true） | 无此概念，靠进度驱动 |
| 视觉结果 | **封面横穿屏幕飞过去**（560ms，肉眼看到的是浮层拷贝） | **整页从迷你条位置长大**（迷你条同时淡出） |

**为什么会不同（不是谁写错了）**：迷你条在 `MainPage`、播放页是 Navigation 栈里的**另一个页面**，
两者坐标系不同。无界用**浮层统一坐标系**从而能画出一条真实的飞行轨迹；
RzdMusic 选择**不做跨页浮层**，改成「播放页自己长大」。

**⇒ 这是产品决定，不是 bug。** 执行前必须先定：

- **要 A（对齐无界）**：在**首页**加一个全屏浮层宿主（等价 `MorphOverlayHost`），
  门控用 AppStorage（V2 里对应 `AppStorageV2` + `@Observed`/`@Trace` 或一个单例 store），
  浮层里**重绘**迷你条的封面/meta/actions 三份拷贝；播放页只负责下层就位。
  **工作量大、要动首页结构。**
- **要 B（保持现状）**：接受「整页长大」的观感，只做第四节的数值对齐。
  **然后在文档里写清「有意偏离」**，免得以后有人当成 bug 去修。

**⛔ 别做半套**：只加浮层但不把迷你条本体换成占位，会出现**两份封面同时在屏幕上**。

---

### A2（功能缺失）歌词页顶部没有封面 + 歌曲名称

**无界的做法**（已实测）：

```
playerPane = Stack {
  Swiper {
    Column   ← page 0：封面页
    Column   ← page 1：**空 Column**，只有 padding({top: lyricPadTop()}) + 手势
  }
  Stack { this.floatingCover() ; if(…) ] }     ← ★ 浮层：跨页浮动的封面
  if(…) { this.floatingMeta() }                 ← ★ 浮层：跨页浮动的歌名/歌手
  if(…) { scrubber + transport }
}
```

**关键三点：**
1. **Swiper 的「歌词页」是个空壳** —— 只有 `padding({top: lyricPadTop()})`，**零子组件**（我数过字节码，88 行里没有任何 `observeComponentCreation2`）
2. 封面与歌名是**挂在 Swiper 之外的浮层**（`floatingCover` / `floatingMeta`），
   切到歌词页时**缩小并移到顶部** —— 同一个元素在动，不是两页各画一份
3. 歌词靠 `lyricPadTop()` **按浮层高度让位**：

```ts
lyricPadTop() {
  if (!this.lyricFloat) { return 0; }                       // 不开浮层 → 不预留
  const boxH = this.overlayBoxH();
  return boxH <= 0 ? LYRIC_PAD_TOP_FALLBACK : /* 按 overlay 高度算 */;
}
```

`LyricsView` 在 `PlayerPage` 里出现 **2 次**（宽屏右栏 + 歌词页）。

**RzdMusic 的现状**（已实测）：

| 位置 | 内容 |
| --- | --- |
| `features\player\src\main\ets\view\PlaybackPage.ets` **L1544-1553** | 歌词页 = `Column { LyricsComponent({ … hideLyricsMetaHeader: this.isSmHeightMdLayout(), … }) }` |
| 同文件 **L331-353** | `animateLyricMorph()` —— **`lyricMorphVisible = false` 无条件写死**，等于关掉了整套歌词页封面形变 |
| 同文件 **L1507-1508** | `.opacity(this.lyricMorphVisible ? 0 : 1)` —— 那层门控因为上面恒 false，**是空转的** |
| 全仓 | **搜不到** `lyricFloat` / `overlayBoxH` / `lyricPadTop` / `LYRIC_PAD_TOP` 的任何等价物 |

`animateLyricMorph` 里的原注释写得很直白：
> `// Lyrics has no cover destination. Do not fabricate a floating thumbnail above its header.`
> `// The real cover remains in Swiper and uses its native slide; all lyric animations stay intact.`

**⇒ 这是「主动关掉」，不是「没做」。** 执行前必须先定：

- **要恢复**：`PlayerExpandState` 里**已经有半成品** —— `lyricMorph()` / `lyricCoverSizeOf()` / `lyricCoverXOf()` / `lyricCoverYOf()` / `lyricGeometryReady()`（L537-612）都在，
  常量 `LYRIC_COVER_SCALE_RATIO = 0.52` / `LYRIC_COVER_TOP_RATIO = 0.06`。
  要做的是：① 让歌词页按浮层高度留出顶部空间（新增 `lyricPadTop()` 等价物）
  ② 切页时把封面/meta 浮层移到「顶部小尺寸」而不是直接 `false`
  ③ 解开 `lyricMorphVisible` 的硬编码
- **不恢复**：把 `animateLyricMorph` 和那批 `lyricMorph*` 半成品**删掉或明确标注废弃** ——
  留着 `lyricMorphVisible ? 0 : 1` 这种恒空转的门控，会让后人以为这条链是活的

⚠️ **注意 `lyricMorph` 与歌词渲染本身不是一回事** —— 用户明确说过**歌词渲染机制不在范围内**。
这里要动的是**封面/歌名浮层的跨页定位**，不碰歌词怎么画。**别顺手去改歌词。**

---

## 三、✅ 已经对了、别动

| 项 | RzdMusic | 无界 | 判定 |
| --- | --- | --- | --- |
| `metaOpacityAt` | `1 - progress/0.35` clamped | `clamp(1 - t/0.35)` | ✅ |
| `actionsOpacityAt` | `1 - progress/0.20` clamped | `clamp(1 - t/0.20)` | ✅ |
| `pullBgIn` | `p/0.30` + `PULL_BG_FLOOR = 0.04` | `clamp(effT/0.30)` + 同下限 | ✅ |
| `pullChromeOpacity` | `(p-0.18)/(0.62-0.18)` | `clamp((effT-0.18)/0.44)` | ✅ |
| `pullBottomIn` | `(p-0.45)/(1-0.45)` | `clamp((effT-0.45)/0.55)` | ✅ |
| **跟手是绝对映射** | `clamp(offsetY/span*100,0,100)` | `clamp(-vp2px(dy)/pullRangePx,0,1)` | ✅ 同构 |
| **代次防竞态** | `morphGen` / `morphGenAlive(gen)` | `animGen` | ✅ 都有 |
| `MorphDrive.FINGER/ANIM` | 有 | 有 | ✅ |
| 无 morph 时的兜底路径 | `if (!morphUsable)` 走 `collapseProgress` | `setFinalStatus()` 无动画落位 | ✅ 都有 |
| 归一化函数在**调用点**做 0-100 → 0-1 反转 | `applyMorphProgress(1 - progress/100)` | `morphT = clamp(-dy/range,0,1)` | ✅ 等价 |

---

## 四、❌ 差异（要改的，按优先级）

### D1（最高）提交判定缺速度项 —— 快甩不生效

**无界**：
```ts
commit = (morphT >= 0.32) || (velocity <= 900)
```
**RzdMusic**（`PlaybackPage.ets` L287、L309）：
```ts
if (progress >= PlaybackPage.DISMISS_COMMIT_PROGRESS) { … }   // 只有进度，没有速度
```
**修法**：`PanGesture` 的 `GestureEvent` 就在手边（L2250/L2253），**`event.velocityY` 现成可用但没传**。
给 `onDismissDrag` 加第三个参数：

```ts
// L265
private onDismissDrag(offsetY: number, ended: boolean, velocityY: number = 0): void {
// L287 / L309 的判定改为：
const fastFlick: boolean = velocityY >= PlaybackPage.DISMISS_COMMIT_VELOCITY;   // 新常量，无界是 900
if (progress >= PlaybackPage.DISMISS_COMMIT_PROGRESS || fastFlick) { … }
// L2251 / L2254
this.onDismissDrag(event.offsetY, false, event.velocityY);
this.onDismissDrag(event.offsetY, true,  event.velocityY);
```

⚠️ **符号要先实测**：无界那边 `velocity` 向下为正、`<= 900` 是"不甩"。
RzdMusic 是**下拉收起**，方向与无界相反 —— 先打日志确认 `event.velocityY` 在"快速下拉"时的符号，
再决定常量用 `+900` 还是 `-900` 比较。**别照抄正负号。**

### D2 归一化分母用固定比例，不用实测

**无界**：`pullRangePx = coverRect.top > 0 ? coverRect.top : winH * 0.32`
—— **优先实测**封面的顶边距，只有在拿不到（≤0）时才退回比例。

**RzdMusic**（L238-240）：`dismissSpanVp() = deviceHeightVp() * 0.42` —— **只用比例**。

**影响**：不同机型/不同布局下"拉多远算拉满"不一致，与无界手感对不上。
**修法**：让 `dismissSpanVp()` 优先返回**实测的收起目标位移**（等价于无界的 `coverRect.top`），
拿不到再退回 `deviceHeightVp() * RATIO`。比例值也应从 `0.42` 调成无界的 `0.32`
（**除非**你实测下来 0.42 更好 —— 那就保留，但要写清「有意偏离」）。

### D3 圆角算法不同

**无界**：`visualRadius = lerp(vp(miniCover.width)/2, targetRadius, t)`，`radius = visualRadius / scale`
—— **两端点插值**，终点是**绝对值 34**。

**RzdMusic**（`PlayerExpandState.ets` L504-515）：
```ts
const scaled = base * (size / mini);
const cap = base * 1.6;
return Math.min(scaled, cap);
```
—— **按尺寸比例放大 + 1.6 倍上限**，不是两端插值。

**影响**：中间态圆角曲线不同（无界是线性插值，RzdMusic 是比例 + 封顶）。
**修法**：若要严格对齐，改成两端点 lerp 并除以 `scale`。**但这处要你判断** ——
RzdMusic 的注释说明它是有意避开 `onAreaChange` 时序问题的（见 L523-527），
**改成无界那样可能引入时序敏感**。**建议：保留现算法，只在文档里标注差异。**

### D4 打开时长：只有一套 350，没有 560

**无界**有**两层**：
- 播放页内快照：`350ms Curve.EaseInOut`
- 浮层拷贝的 `morphT`：`560ms cubic-bezier(0.23,1.0,0.32,1.0)`

**RzdMusic**：`MORPH_OPEN_DURATION_MS = 350` / `MORPH_CLOSE_DURATION_MS = 350` —— **两层都是一套值**。

**影响**：无界的"飞"看起来更从容（560ms 且是快出慢收的曲线），RzdMusic 更快更"硬"。
**修法**：如果 RzdMusic 的两层结构（播放页快照 + 浮层）与无界对应，
则把**浮层那层**的时长改成 `560` + `cubic-bezier(0.23, 1.0, 0.32, 1.0)`，内层保持 `350 EaseInOut`。
⚠️ **先确认 RzdMusic 是不是两层**（`MORPH_HOST_ID` 注释说"手机侧就是播放页自己的根 Stack"，
可能只有一层）—— 只有一层的话这条**不适用**。

### D5 遗留 API 清理

`pullProgressFrom` / `pullShouldCommit` / `beginPullOpen` / `updatePull` / `endPullOpen` / `PULL_COMMIT_PROGRESS`
—— 无调用点。确认后删掉，避免后人改错地方。

---

## 五、不要照抄的部分（无界是 V1，且架构不同）

| 无界的做法 | 为什么别抄 |
| --- | --- |
| `@StorageProp` / `@StorageLink` / `@Watch` / `@Observed` | **V1 装饰器**。RzdMusic 是 V2，用 `@Local`/`@Param`/`@Monitor`/`@ObservedV2`/`@Trace` |
| `@BuilderParam content` 的开关式浮层宿主 | 那是 V1 写法；V2 用 `@BuilderParam` + `@Local` 布尔同样可行，但语法不同 |
| 收起走**位图快照**（`Image(shrinkPixmap)`） | RzdMusic 现在是**反向跑同一套几何**。架构不同，**除非你想改架构**，否则不动 |
| `AppStorage` 那套（`lx_pull_active` / `lx_pull_t`） | RzdMusic 用 `PlayerExpandState` 的状态分发。**不要引入 AppStorage** |
| `SymbolGlyph` 的具体 symbol id | 那是无界的资源，RzdMusic 有自己的 |

---

## 六、验收方式

改完**必须**能回答这三条（做不到就是没改对）：

1. **快甩能收起**：从播放页**快速小幅**下拉（位移不到 38% 但速度很快）→ 应当收起。
   日志里能看到 `velocityY` 与 `fastFlick` 的判定。
2. **慢拖不过阈值会回弹**：慢慢下拉到 30% 松手 → 弹回完整态，且 `morphGen` 保证不会被过期回调打乱。
3. **跟手无漂移**：快速来回拖动后松手，画面位置应与"手指绝对位移"一致，
   **不出现累积偏移**（这是绝对映射 vs 累加式的判据）。

复现命令：
```powershell
# 构建
powershell -NoProfile -Command "& './tools/build-and-publish.ps1' -SkipSourceSync"   # 在 RzdMusic 目录
# 设备日志（无界的日志域是 WantingMusic-ExpandAnim；RzdMusic 用 PlayerExpandState.logTag）
hdc shell hilog -x | Select-String -Pattern 'RzdMorph|PlaybackPage|morphGen'
```

---

## 七、参考资料（都在这台机器上）

| 文档 | 用途 |
| --- | --- |
| `_recover\logic-src\交付物交叉核对记录.md` | **先读这份** —— 哪些结论互证、哪些单源未复核 |
| `_recover\logic-src\ExpandAnimation驱动与补间定稿.md` | 两条驱动路径、状态字段全集、`initParams` 几何验证 |
| `_recover\logic-src\飞入浮层宿主与几何插值定稿.md` | 浮层五层结构、三份拷贝的运动方式 |
| `_recover\logic-src\封面飞入机理定稿.md` | 完整时序 + 18 条降级路径 |
| `_recover\logic-src\pullT写入算式与形变枚举.md` | `pullT` 算式与 6 个枚举 |
| `_recover\logic-src\播放条三形态完整UI.md` | 胶囊布局与全部常量 |

**行号基准**：无界相关文档的行号全是 `disasm\wujie.pa` 的**绝对行号**（可直接 `Select-String`）。
本文件里 RzdMusic 的行号是实测的，可直接跳转。

---

## 八、执行前请先确认

> **⛔ 先看第二节·补的 A1 / A2 —— 那两条是架构决策，不做决定就别往下改。**
> 第四节的 D1-D5 是数值/接线层面的修补，A1/A2 是「要不要改架构、要不要恢复功能」。

1. **A1：要不要做跨页浮层**（对齐无界的「飞行」）还是保持现在的「整页长大」？
   —— 这条不确定，D4（时长）也无从谈起
2. **A2：要不要恢复歌词页顶部的封面+名称浮层**？（`PlayerExpandState` 里已有半成品）
3. **D1 的 `velocityY` 符号** —— 先打日志实测，别猜
4. **RzdMusic 是几层** —— 决定 D4 是否适用
5. **遗留 API（D5）是否真死了** —— 全仓扫过，但可能有动态调用
6. **`DISMISS_DRAG_SPAN_RATIO` 该不该从 0.42 改 0.32** ——
   无界是 0.32，但 RzdMusic 的参考工程 MusicHome 可能是另一个值；**改了要实测手感再定**

**未确认的不许猜。** 这份清单里凡是标「待确认」的，都要靠实测或读码定案，不能按无界的值直接覆盖。
