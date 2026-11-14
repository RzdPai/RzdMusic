# 播放器改动复核与封面残留派工单（2026-11-02，只读分析）

用户范围：复核另一模型的改动，分析“退出播放器封面残留”；本轮不修改应用代码，不编译、不提交、不上传。实施交给后续模型。

复核基线：`HEAD=1200d01cc36981e0b876a0f1f3fbbeb49cd84809`。`49510653` 修改四个源文件；`1200d01c` 仅更新两处构建戳为 `261101-2358`。分析开始时工作树干净。

原始证据：[用户日志，共83行](<C:/Users/Administrator/.dsh/attachments/v1/files/92/920b4827f5c552d5ad1fb17f90d3e5b74ec13ade71c878400e035178d7dcf550/[223651] [卡片] _202611022240_17622.txt>)。附件没有构建戳、提交号与进程会话标识，因此不能锁定它运行的包与本次源码基线完全一致。

## 1. 审查结论

上轮的64ms关闭回调隔离、60ms快照自启动身份检查，以及清空pending握手，方向正确。但“全部跨会话隔离已经完成”“已确认两个真根因”的表述过强，仍有以下缺口。它们不等于此次封面残留的已证实根因。

### P1：挤压代次没有在下一次打开时失效

位置：[PlayerExpandState.ets:5551](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/common/musicbasic/src/main/ets/model/PlayerExpandState.ets#L5551>)、[PlayerExpandState.ets:5578](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/common/musicbasic/src/main/ets/model/PlayerExpandState.ets#L5578>)。

- `squashGen`只在`squashLandAnim()`内部递增。
- 新打开的`prepareMorphEntry()`、`pullOpenBegin()`、`morphReset()`均不使该代次失效。
- 110ms回弹和其后360ms硬写均没有保存定时器句柄。
- 关闭后迅速重新打开，新展开仍可继承上一轮的`morphSquashY=0.86`，旧回调也仍可写共享状态。
- 该值不只用于真迷你条：[Index.ets:2059](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/products/default/src/main/ets/pages/Index.ets#L2059>)的封面克隆同样消费它，迷你条克隆也消费它。

**实施要求：** 新打开的会话边界显式停止旧落地挤压，取消两个timer并作废旧代次，再恢复展开基准。不要在每次正常关闭的`morphReset()`中无条件打断落地回弹；正常的110ms压下、320ms回弹是既定交互。

性质：会话隔离缺口由源码确认；它在真机上的具体视觉影响、与此次持续残留的关系未证实。

### P1风险：页面实例号不等于打开会话号

位置：[PlaybackPage.ets:8710](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L8710>)、[PlaybackPage.ets:3956](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L3956>)、[Index.ets:1212](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/products/default/src/main/ets/pages/Index.ets#L1212>)。

`onDisAppear`现在用`closeInstance === instanceSerial`决定能否清共享的`pullDragging/morphDrive`；但新实例序号直到新页`aboutToAppear()`才更新。此前壳层已可能准备新形变并push。

若旧卸载回调出现在“新形变已准备、新页aboutToAppear尚未执行”的边界，旧实例号仍可通过检查。缓存复用也不能由构造/出现次数自动等同为业务会话。

**实施要求：** 生命周期回调持有并复核打开会话token；会话边界应覆盖新形变准备之前。实例号保留作诊断，不作为唯一共享状态写入授权。顺带检查两个0ms卸载回调与壳层400ms收尾回调。

性质：身份边界不足由源码确认；框架在本次设备上是否发生这个精确交错，附件无法证明。

### P2：静态PixelMap替换仍遗漏释放责任

位置：[PlaybackPage.ets:8754](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L8754>)、[PlaybackPage.ets:8435](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L8435>)、[PlaybackPage.ets:7613](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L7613>)。

关闭时静态缓存保留P；下一次打开先`adoptWarmMeshSync()`，它创建Q并调用`commitMeshSource(Q, this.meshSrc)`。新页本地`meshSrc`通常为空，但静态缓存仍持有P。commit直接覆盖静态P，却只释放传入的本地old，因此遗漏了被替换静态P的显式释放。播放器关闭期间换歌后再commit也有同类路径。

这也说明“下次打开始终复用同一张背景图”并未做到：warm同步采用排在shared采用前。

**实施要求：** 缓存有效时优先复用；统一cache replacement/eviction与借用规则，不能简单在覆盖时立刻release仍被另一页面或RenderNode引用的对象。`isReleased()`只证明检查当刻未释放，不能替代所有权契约。可沿用已有字节缓存，让页面自持PixelMap；也可保留PixelMap缓存并明确借用/退还，但本轮不要无依据扩大架构改造。

性质：显式释放责任遗漏确定；GC回收时机和native占用未测，不能写成永久内存泄漏，更不能据此推断封面残留。64×64 RGBA像素数据单张约16KiB，不是满屏快照大小。

### P2：挤压硬写兜底没有覆盖首段异常

位置：[PlayerExpandState.ets:5582](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/common/musicbasic/src/main/ets/model/PlayerExpandState.ets#L5582>)、[PlayerExpandState.ets:5592](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/common/musicbasic/src/main/ets/model/PlayerExpandState.ets#L5592>)、[PlaybackPage.ets:5435](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L5435>)。

首段`ui.animateTo()`仍未捕获异常，之后才排110ms timer。若首段同步抛错，两条timer都排不到，并中断调用方后面的关闭收尾；2500ms关闭watchdog可能随后兜底，因此不能断言永久锁死。若异常发生在动画闭包执行前，模型值仍为1，不能说此时必卡0.86。

嵌套硬写约在110+320+40=470ms后执行，还受主线程调度影响；它检测模型字段，不是屏上插值值。

**实施要求：** 动画是附加视觉动作，其失败不应中断路由/关闭收尾；异常处理与兜底注册覆盖首段调用。保留正常动画时序，不以再加延时替代完成回调。

## 2. 可以保留的改动

- [Index.ets:1212](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/products/default/src/main/ets/pages/Index.ets#L1212>)在默认端唯一push入口登记`openSerial`；[PlaybackPage.ets:1809](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L1809>)在64ms回调动作前比对；新打开也会取消旧tail。它解决了旧回调仅凭`player`名字操作新路由的结构性风险。
- [PlaybackPage.ets:5015](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L5015>)的60ms快照自启动检查`ownsClose()`，与[MorphShrinkState.ets:257](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/common/musicbasic/src/main/ets/model/MorphShrinkState.ets#L257>)清空pending握手，方向合理。
- [PlaybackPage.ets:370](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L370>)取共享图前判活、卸载时不释放仍归静态缓存的那张，补上了原来明显的死引用路径；缓存替换责任仍须补全。
- 背景不再直接受迷你条挤压值归零，降低了不相关标志令背景整段透明的风险；这一点只能称源码上的风险消除，不能由本附件证明它就是此前“没背景”的发生原因。
- `morphReset()`清`pullMode`可以作为会话结束归位；点击打开也会再次调用`pullOpenBegin()`置true，所以不能把它解释成“从此点击打开走content曲线”。

## 3. 这份日志能确认什么

证据：[附件:48](<C:/Users/Administrator/.dsh/attachments/v1/files/92/920b4827f5c552d5ad1fb17f90d3e5b74ec13ade71c878400e035178d7dcf550/[223651] [卡片] _202611022240_17622.txt#L48>)至第67行。ISO时间`14:35Z`对应本地`22:35`。

| 关闭轮次 | 起手 | START到FINISH | 清理后 | 64ms后 |
| --- | --- | --- | --- | --- |
| instance=1 | live，LEAVING，p=0.276，clone=1 | 约193ms | real=1，clone=0，tail=0，mask=1，NONE/p=1，快照全0 | alive=0，show=0，size=0，idx=-1 |
| instance=2 | live，OPEN，p=1 | 约470ms | 同上 | 同上 |

两轮都正常到达`shrink FINISH`，没有watchdog/fallback/re-pop指纹。耗时与既有反向动画参数量级吻合。采样时逻辑显示意图已关闭，该NavPathStack账面无player。

日志前段是22:36:51启动后的即时日志，关闭证据来自下方“持久诊断（重启保留）”。不能把整份当成同一进程连续跟踪，也不能据此断言发生崩溃。

### 三条必须纠正的日志误读

1. **`removed=-1`不表示pop失败。** [PlaybackPage.ets:1706](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L1706>)把它初始化为-1，栈顶pop分支没有给它赋值。`size=1`也来自pop之前采集的names。不能用这两项证明pop后仍留路由。
2. **`real=1`不等于屏上真封面可见。** [PlayerExpandState.ets:903](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/common/musicbasic/src/main/ets/model/PlayerExpandState.ets#L903>)在reset后的NONE/geometryFinished状态会返回true；但实际竖屏封面[PlaybackPage.ets:9303](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L9303>)还要求`!snapshotFlight && !coverPublishHidden`。日志mask=1理论上令它opacity=0。flat和MusicPlayInfoBlock也有对应mask。
3. **`clone=0 / pix=0`是逻辑状态，不是渲染树巡检。** 它们不证明合成帧已清空；同时这份附件也不支持直接归因“旧快照没清”，因为两轮都是live且快照标志全0。

附件没有新增会话/挤压日志，并不代表新补丁没运行：这些日志只在特定分支命中时输出。本附件也没有构建标识，包版本必须另行记录。

## 4. 封面残留：最优先验证的候选机制

[PlaybackPage.ets:1712](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L1712>)发起pop后，[PlaybackPage.ets:1735](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L1735>)立即`morphReset()`，共享状态恢复NONE、p=1、scale=1、无裁剪。

根节点[PlaybackPage.ets:8866](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L8866>)没有独立的“本次关闭已完成，等待卸载期间不再出图”状态。reset后其`playerPaints()`与无裁剪条件又可放行；[PlaybackPage.ets:8912](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic/features/player/src/main/ets/view/PlaybackPage.ets#L8912>)也不再乘收起尾段透明度。若`introPaintReady`尚未被内层卸载回调清掉，根opacity还可能为1。

因此在路由退场帧尚未完全卸载时，存在**恢复全窗背景/控件的候选窗口**。这是应用侧可定位的操作顺序问题，比继续猜“pop返回-1”更值得验证。

但这条机制目前只解释潜在瞬闪，**不能独自解释持续的大封面**：mask=1仍应压住已经更新到新属性的封面。要确认持续残留，必须辨认实际留下的节点或帧。不可把候选写成已经证实的根因。

另外，`isAlive=false`由内层正文节点的`onDisAppear`写入，不能直接等同于整个NavDestination及所有兄弟层已销毁。

## 5. 给实施模型的任务顺序

1. **先锁定包和日志来源。** 持久日志加build stamp、进程运行id、open session、close token、destination id，避免把重启前的记录与当前即时日志拼成同一轮。
2. **先修已确认的隔离缺口。** 新打开前取消旧squash与旧卸载共享写入；用会话token，不只用页面实例号；补动画异常不阻断关闭收尾的处理。保持正常LANDING回弹、封面交棒及V2/Navigation约束。
3. **补能判断实际绘制身份的有限日志。** 在live finish、pop后、NavDestination的onHidden/onDisAppear、下一帧/约64ms采样中记录：root是否挂载、计算visibility/opacity、introPaintReady、shrinkPageHidden、实际cover mask/opacity、clone mounted与playerRouteAlive、shrink visible/pixmap、几何scale/clip。记录真实唯一节点身份，避免只打一个`real=1`。
4. **按结果修“关闭终态不得重新出图”。** 若证实是旧播放页在reset后恢复全窗，给完成关闭的旧页面建立终态隐藏边界，并由真正的新会话清除；或把复位与真实目的地卸载收口对齐，回调必须校验session。不要把`coverPublishHidden`在关闭收尾清false，也不要强推`morphSettleOpen()`，不要仅多pop或加任意等待时间。
5. **补缓存的替换/回收契约。** cache有效时优先采用；替换时考虑所有借用者，确认不再被页面、RenderNode或异步任务使用后释放。不要把“判活”当所有权。
6. **验收时覆盖不同关闭路径。** live完整关闭、展开中反向、snapshot、关闭后立即重开（<110ms和110–470ms）、转屏后关闭。分别检查短闪和持续残留，不能只看最终栈空。

建议日志关键词：`RzdCloseRender`、`RzdSessionGuard`、`RzdSquash`、`RzdBgPhase`。新增名字是派工建议，本轮未接入代码。

## 6. 上轮结论的证据边界

官方[UIContext指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-global-interface)明确“每个窗口对象都会创建并管理一个UI实例”。组件销毁后重新调用`getUIContext()`可能得到undefined，与先前已捕获的UIContext在NavDestination pop时立即失效不是同一回事。**仅凭页面pop，不能认定回弹必丢。**

官方[NavDestination生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-navdestination)区分逻辑导航、onHidden和从组件树卸载的onDisAppear。路由栈为空也不能替代屏幕帧证据。

官方[PixelMap参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-image-pixelmap)提供`isReleased()`（API22+）；释放前仍须保证异步操作结束且后续不再使用。

[项目记忆§261](<C:/Users/Administrator/Desktop/RzdProject/RzdMusic记忆.md#L6202>)中“UIContext pop后失效”“只剩迷你条使用squash”“所有跨会话隔离已完成”的表述应以上述复核为准；以源码可构造的风险作为待修项，不能把它们当作这份日志已确认的根因。

## 7. 本轮验证范围

已完成源码对照、提交差异复核、附件时间线核对、官方文档核实与独立只读交叉审查。未修改应用源码、依赖、权限或构建配置，未构建或上机复现。只新增本分析文档，并补正项目/全局记忆。应用修复与真机验收仍由实施模型后续执行。

## 8. 后续实机日志复核（附件 2026-11-03）

附件：[第二份日志](<C:/Users/Administrator/.dsh/attachments/v1/files/f9/f9a77cd65acb97d5729b41463864485a09961352cf24f1eb6e924fc3c39cd4fd/[080041] [卡片] _202611031205_33365.txt>)，76行。基线HEAD=`c24fe6dc`，工作区干净。

### 时间与包版本

`MusicStoreService.appendRuntimeDiagnostic()`以`new Date().toISOString()`写持久诊断，所以`2026-11-02T23:57:49Z`/`23:57:54Z`换算成北京时间是**2026-11-03 07:57:49/54**；附件启动行`[08:00:41]`与持久记录`2026-11-03T00:00:41Z`互相印证。

这晚于`261102-2345`上传回读（11/2 23:46:26 +08）和`261103-0101`上传回读（11/3 01:02:37 +08）。**只能说日志事件发生在两次上传之后**；没有About构建戳、安装记录或版本截图，不能说一定运行了哪个包。`RzdCloseRender`采样代码由`32d9e475`加入；该字段只证明运行日志包含这一实现，不区分2345/0101，也不等同安装包身份证明。

### 这份日志实际证明什么

两轮都是live关闭，`shrink START→FINISH`约323ms/474ms；`FINISH→route-remove`约14ms/5ms；pop/reset同毫秒。post-cleanup、内容Column on-disappear、t+64三处都报告：

```text
rootVis=0 realOp=0 clone=0 snap=0 snapPix=0 shrinkHidden=1
```

t+64另有`alive=0 show=0 size=0 idx=-1`。没有watchdog/fallback/re-pop。**结论：未复现持续残留，是强反证，不是屏幕像素层面的排除。**

`intro=1`出现在post-cleanup/on-disappear，但不是可绕过隐藏门的证据：`morphOpacityValue()`虽可能返回1，根节点仍受`shrinkPageHidden=1`的`Visibility.Hidden`门；该内层on-disappear采样发生在稍后`introPaintReady=false`之前，t+64已为0。源码逻辑上intro不能越过根隐藏门，但仍没有真实合成帧采样。

### RzdCloseRender的盲区

`rootVis`、`realOp`、`clone`、`snap`都是ArkTS模型/修饰器条件的计算值，不是组件树探测或屏幕像素：

- `rootVis`对应播放页根visibility表达式；`realOp`对应封面opacity公式；它们不测GPU最后一帧、过渡快照或合成器缓存。
- `clone`只取共享状态`morphOverlayBridging()`；Shell的`MorphCoverClone`另外受builder挂载条件`morphOverlayBridging || hdsBarSuppressed`、`morphPaintHidden`、`playerRouteAlive`及实际opacity控制。该日志未采样这些最终值，也未采`MorphMiniBarClone`、`MorphMetaBridge`、`ShrinkOverlayHost`节点是否真正挂载。
- `snap/pix`是`MorphShrinkState`字段，不是RenderNode/图像内容验证。
- `on-disappear`是正文Column回调，不等同NavDestination的`onHidden/onWillDisappear/onDisAppear`。

源码顺序是pop → reset/共享状态清理 → `shrinkPageHidden=true` → post-cleanup log，调用中没有显式await或timer；**不要声称存在已证实的毫秒级空窗**。但门置位前没有独立采样，关闭动画期间亦无逐帧记录，帧合成期间的短闪、旧合成帧、未检查的Shell层仍未排除。

### 新发现的缓存条件风险

`bgCacheOwner`是单个“最近借用者”编号；同一静态PixelMap可以暂时被多个仍存活的PlaybackPage实例引用。如果B adopt覆盖了A的owner，B先退出会把owner归零；若A仍持有同一PixelMap，此时有第三方commit/track-change按“无主”释放，A就会持有已释放图。

这是**源码上的条件性所有权风险**（中高置信度），本附件没有`adopt/cache-orphan/cache-replace/drop`日志，不能确认发生，更不能将它归因于封面残留。若确认NavPathStack复用/快速重入会造成多借用，实施应改为引用计数/lease集合，或缓存字节、各页独立PixelMap；不要简单加`if(owner===...)`就宣称彻底解决。

### 下一次最小取证

1. 同一次录屏里同时展示设置/关于页构建戳与关闭后残留画面，使故障画面、包版本和运行日志绑定。
2. 导出一轮完整诊断，不要只截最后几行；记录pop前、reset后、`shrinkPageHidden`置位后、下一帧、NavDestination hidden/willDisappear/disappear、+64。
3. 同步采Shell克隆的实际挂载、`playerRouteAlive`、`morphPaintHidden`、最终opacity与快照层节点身份。目标是确认画面属于旧播放页、Shell克隆、快照层，还是其他首页/二级页内容；区分瞬闪和持续残留。

官方边界：[NavDestination生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-navdestination)区分导航隐藏、离场与组件树卸载；路由栈为空和逻辑visibility=Hidden都不能代替屏幕像素证据。

## 9. 实施（2026-11-03，条件：甲方补充"**只有下拉关闭会残留，系统返回正常**"）

### 9.1 分岔点定位：下拉这条路**没有**声明"反向在进行中"

三条关闭入口落进收尾时的状态不一样：

| 入口 | 进 `closeFullScreenPlayback()` 之前 | `reverseInFlight` |
| --- | --- | --- |
| 系统返回 / 顶栏 | `onCollapseRequested()` 里显式置真 | 真 |
| 快照路（落位之后） | `closeWithAnimation()`，不经过 live | 假（也不需要） |
| **下拉** | `onDismissDrag()` 直接调，**没有任何置真** | **假** |

`reverseInFlight` 是壳层"展开收尾"的唯一让路闸，两处放行条件都是
`isShowPlay && morphGeomReadyNow() && morphUsable && !reverseInFlight`：

- `Index.settlePullOpen().onGeometryFinished`（打开后 300~400ms 的那条补间收尾）
- `Index.retrySettleLanding()`（再 12×32ms 轮询）

而 `isShowPlay` 要等关闭收尾（`finishCloseGuard`）才变假。于是**"打开后 ~700ms 内下拉关闭"**
这个只有下拉才会出现的时机，会让 `morphSettleOpen()` 在**关闭动画正中间**被执行：

```text
morphSettleOpen(): stage=OPEN / drive=NONE / applyMorphProgress(1) → morphP=1 / 圆角=0 / 系统条放回
```

即整屏播放页（含封面）被重新写回来，然后才 pop。系统返回因为提前置了 `reverseInFlight`，永远撞不上这条。
这与甲方"只有下拉残留、返回正常"的分岔完全一致。

### 9.2 改动（源码级）

1. `PlaybackPage.closeFullScreenPlayback()`：入口第一件事 `reverseInFlight = true`，
   并打 `RzdCloseEntry src=<entry> path=live ... rev=1`。无论谁触发 live 关闭都成立。
2. `PlayerExpandState` 新增 `@Trace playerSessionClosed` + `markPlayerSessionClosed()/Open()/playerPaintAllowed()`：
   **不看任何几何**的结构判据。`PlaybackPage.finishCloseGuard()` 置真（三条关闭路都必经），
   壳层 `Index.pushPlayerRoute()` 与 `pullOpenBegin()` 置假。
3. 三道渲染门挂上它：播放页根 `visibility`、真封面 `opacity`（两处）、壳层
   `MorphCoverClone` 的 `visibility`+`opacity`、`ShrinkOverlayHost` 的挂载条件。
4. 诊断：`RzdCloseEntry`（入口 + p/drv/intro）、`RzdCloseRender` 增补
   `src=/rev=/drv=/pullMode=/srcBarOp=/hs=/miniOut=/closed=`，并在收尾后 `setTimeout(0)`
   补一条 `t+0` 采样（收尾后真正画出来的第一帧）。
5. `Index.retrySettleLanding()` / `onGeometryFinished` 追加 `playerPaintAllowed()`，双保险。

### 9.3 验证等级

编译级 + 产物级：`assembleHap` 实际执行了 `CompileArkTS`（1min19s），
`musichomesample-default-signed.hap` = 63,086,882 B（构建戳 261103-1239，PROPFIND 回读一致 63,086,882 B），
解包 `ets/modules.abc` 后 `RzdCloseEntry` / `player session closed` / `player session open` / `rev=1`
各命中 1 次，证明新增代码进了产物。**没有真机**（`hdc list targets` 为空），
所以"下拉关闭是否真的不再残留封面"仍未验证——需装包后按下节取证。

### 9.4 下次上机判读（一条 grep 就够）

```text
hdc shell hilog -x | Select-String 'RzdCloseEntry|RzdCloseRender'
```

- 正常：`RzdCloseEntry src=pull ... rev=1` → `RzdCloseRender post-cleanup ... closed=1 rootVis=0 realOp=0 clone=0`
  → `RzdCloseRender t+0 ... rootVis=0`。
- 若 `RzdCloseEntry src=pull` 之后仍出现 `RzdCloseRender ... stage=2 p=1.000 rev=0`：
  说明还有第三条路把 p 拍回 1（不是壳层落位链），查 `morphSettleOpen` 的其它调用者。
- 若 `closed=1` 但 `t+0` 里 `rootVis=1`：说明门又被别的写点放开了，查 `shrinkPageHidden` 的复位点。

