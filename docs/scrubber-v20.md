# 第二十次会诊：进度条松手跳动（待上机候选）

## 范围与基线

基线 HEAD `9b294d3`，开工工作树干净。只处理 scrubber 预览与 seek 回写交接。

未修改任何 `*记忆.md`；全局及项目记忆 SHA256 开工/收工一致：

- 全局：`5A897314504FE227002269AB5BB12695C3AA738B76DC551DAE958E6B2A335D7B`
- 项目：`3AD37BD96DAB131DD26D44FC9892A5122E29FE7BB80E8E91AFBB101E6F2481FE`

`PlayerExpandState`、`Index`、`PlaybackPage`、mini-bar 尾窗、`morphSquashY`、`MorphSolidSurface` 均零改动。

## 源码确定的机制

以下旧行号以 HEAD `9b294d3` 为准：

1. `features/player/src/main/ets/view/ControlAreaComponent.ets:708,727`：装饰层和交互层**都**绑定 `scrubberPressed ? scrubberPreviewValue : appState.progress`。不是两层分别独立绑定不同真值。
2. 同文件旧 `737–742`：`onTouch Up/Cancel` 调 `setScrubberPressed(false)`。旧 `72–84` 的 pressed 同时控制视觉粗细和是否使用预览；关闭后，两层一起退回旧 progress。
3. 同文件旧 `744–750`：所有 onChange 更新 preview，但仅 Begin/End/Click 调 seek；End 没有保持独立预览所有权。
4. `PlayerViewModel.ets` 旧 `86–87` → `PlayerDataUtil.ets` 旧 `79–80` → `MediaService.ets` 旧 `1929–1937`：seek 只调用原生 AVPlayer，**不**同步写 progress；旧 `173–180` 的 seekDone 才把实际位置回写。

所以可由应用源码确定的回退窗口是：用户拖动值 → TouchUp 关闭预览门 → 旧 progress → seekDone 后的新 progress。无需假设 ArkUI 的内部重绘顺序即可解释一次回退。

旧 MediaService `1935` 已将 isCurrent=false，旧 `307–309` 仅 isCurrent=true 时写普通 tick。因此不能把“seek 等待期旧 tick 多次抢写”当作已证原因，也不能仅凭源码确定用户设备上每一跳的次数。

另一个应用层可达机制：Begin 与 End 均可提交 seek，旧 seekDone 无条件发布每次中间位置；连续反向拖动可能把前一次请求结果暴露给轨道。若只加目标容差，A→20s、B→80s、C→20s 的早期 A 完成仍会被误认成 C。当前候选用单原生请求在途、待处理目标取最新值消除这个歧义。

## 改动文件、唯一锚点、旧 → 新

| 文件 | 唯一定位锚点 | 旧 → 新 |
| --- | --- | --- |
| `features/player/src/main/ets/view/ControlAreaComponent.ets` | `get scrubberDisplayValue()` | pressed 决定真值/预览 → 独立 `@Local scrubberPreviewActive` 决定；两层 Slider 都绑定同一 `@Computed` 显示值（当前 787/806 行） |
| 同上 | `private onScrubberChange` | Moving 只更新原局部值 → 即时更新共享预览；Begin/End/Click 保持调用 seek；End/Click 持有预览等待确认 |
| 同上 | `private reconcileScrubberPreview` | 松手即交回真值 → 提交后必须有新的 seekDoneRevision，且 `abs(progress-target) <= 250ms` 才交回；250ms 是位置误差，非等待时长 |
| 同上 | `onScrubberTrackChanged` | 无独立预览失效处理 → 换索引、时长变化、seek 失败或重新装载时释放；Cancel 保留最后提交目标，不猜等待时间 |
| `common/musicbasic/src/main/ets/model/MusicAppState.ets` | `seekDoneRevision` / `seekResetRevision` | 无确认/失效信号 → 两个 `@Trace` V2 序号，支持暂停时 seek 到相同数值也通知观察者 |
| `features/player/src/main/ets/model/MediaService.ets` | `private scrubberSeekInFlight` | 重叠请求直接全部提交 → 一次原生 seek 在途，重叠请求只保留最新目标；中间 seekDone 不发布 UI progress，继续最新目标；最终 seekDone 发布 progress+revision |
| 同上 | `public seek(ms: number): boolean` | 静默忽略/void → 返回是否接收，拒绝或同步异常显式释放；error/loadAsset 发 reset 信号；排队目标提交失败恢复 isCurrent 并发布已完成位置 |
| `features/player/src/main/ets/util/PlayerDataUtil.ets` | `public static seek(ms: number): boolean` | void 委托 → 透传接收结果 |
| `features/player/src/main/ets/viewmodel/PlayerViewModel.ets` | `public seek(ms: number): boolean` | void 委托 → 透传接收结果 |

交互层仍 HitTestMode.Block，装饰层仍 None；14vp 固定厚度、24/14 scale、32vp 盒、blockSize、margin 与 springMotion 原样保留。pressed 动画闭包仅写 pressed，不再更换轨道数值来源。无新增 setTimeout 或其它猜测时长。

串行策略会合并原生 seek 尚未完成期间的重复提交（保留最新目标），但组件触发 seek 的条件仍严格是 Begin/End/Click；Moving 不调用 seek。此策略也适用于调用同一 MediaService.seek 的歌词/系统定位，需上机确认快速定位体验。

## 应用内日志

通过既有 `appendPlayLog` 写入应用日志，搜索/grep `RzdScrubberV20`，不需要 hdc。

组件日志包含 `mode/value/progress/preview/active/display/editing/pending/target/seq/reason`。服务日志含 `mode/value/progress/preview=component-owned`，服务不持有 UI 的 preview；查看相邻组件日志中的数值即可。

- `Moving ... reason=preview-only`：display 应跟 value，progress 可以仍旧。
- `End` 或 `Click ... reason=seek-submit`：preview=最新 value，active=true。
- `TouchRelease ... reason=pressed-visual-only`：只影响粗细，不清 active。
- `SeekIntermediate ... next=...`：旧请求完成，结果尚未向 UI 发布，继续最新请求。
- `SeekDone ... ack=...`：最终实际回写。
- `reason=hold-until-target`：确认尚未满足，继续画 preview。
- `reason=handoff-near-target`：仅此处正常交棒，active=false，随后读真值。
- `reason=seek-rejected` 或 `reset-track-duration-or-seek-failure`：明确失败/装载失效释放，不是成功交棒。

示意序列（不是设备实测日志）：End value=80000 progress=20000 preview=80000 active=true → TouchRelease 仍 active=true → SeekDone value≈80000 → handoff-near-target active=false。

## 官方资料与边界

通过工程 `tools/mcp-query.ps1` 获取官方 Slider 全文，核对 SliderOptions.value、onChange 与 SliderChangeMode。来源：

https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-slider

未假定 TouchUp 与 End 的系统调用先后：任一顺序下，Up 都只改按压视觉，数值交棒由确认路径负责。本报告不宣称系统内部绘制时序已经测量。

250ms 容差为本候选位置判据，不是所有媒体 seek 精度的系统保证；若最终实际位置始终偏离目标超过该容差，会继续保留预览，并输出 hold 日志。需要用实际媒体上机确认此边界，不用定时器强行放开。

## 验证

- `git diff --check` 通过；改动仅上述五个业务源码及本 docs 报告/构建日志。
- V2：新增状态仅 @Local/@Computed/@Monitor/@Trace，无新增 V1。
- `tools/check-mini-bar.ps1` A–F 全部 PASS；冻结区域无源码改动。
- default/debug assembleHap 最终退出码 0，`BUILD SUCCESSFUL in 32 s 887 ms`；结果见同目录 `scrubber-v20-build.log`（已从 PowerShell UTF-16 日志转为 UTF-8）。
- 最终签名 HAP：`products/default/build/default/outputs/default/musichomesample-default-signed.hap`，23,662,352 字节；包内 `ets/modules.abc` 命中 `RzdScrubberV20`。
- `hdc list targets` 返回 `[Empty]`。本轮仅源码/编译/产物级，**没有设备视觉验证，不声称已修复**。
- 无新增依赖、无新增权限，`oh-package.json5` 和 module 权限清单均无改动。

## 上机判据

1. 播放时前拖、后拖并按住：装饰轨道和滑块一直跟手，Moving 的 display=preview=value。
2. 松手：只收细，不能先返回拖动前位置；End/TouchRelease 后等待期 active 保持 true，最终只有一次 handoff-near-target。
3. 连续来回拖两次（第一次回写前立即反拖），再补测 20→80→20 的重复目标：不得显示中间旧目标；日志允许 SeekIntermediate，但中间完成不能导致 handoff。
4. 快速点击轨道不同位置：最终位置跟最后一次点击，Click 立即建立预览；暂停时也测试，seek 到相同位置仍可通过 revision 正常交棒。
5. 播放器未就绪、报错或换歌时定位：允许明确失败释放，但不能把失败误报为成功；恢复后轨道不能永久冻结。

若仍跳动，请导出应用日志中一次操作前后完整的 RzdScrubberV20 序列；日志证明的是应用输入/状态交接，屏幕是否发生像素回退仍以设备观察为准。
