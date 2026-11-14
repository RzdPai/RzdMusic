# 第十七次会诊：引擎完成后交还封面

验证等级：源码 / default 编译 / HAP 内容级候选；hdc list targets = [Empty]，未上机，不声称已修复。

## 实现

选择完成标志方案，未改成逐帧驱动。点击原 animateTo 仍同步写 morphP=1，但这不再证明几何结束。PlayerExpandState 新增私有 @Trace openGeometryFinished，通过只读 isOpenGeometryFinished() 暴露；起手/新动画置 false，只有匹配代次且仍 ENTERING 的引擎完成回调置 true。reset 使旧代次失效。三个旧 p>=.999 的交棒门统一读该标志。

Index.settlePullOpen 的几何 animateTo 使用 FinishCallbackType.REMOVED/onFinish；原 duration+20 的 commit 收尾改由完成回调调用，保留原 geomReady/usable/reverseInFlight 守卫，不强制 settle。先注册收尾后启动动画，兼容系统关闭动画时官方规定的立即回调。morphSettleOpen 在 ENTERING 且几何未完成时拒绝提前落位。

PlaybackPage 现有 startGeoDriver 的 onFinish 接入同一完成标志，使用 animator 实例身份防止过期完成回调写终点；零时长路径同步完成。不是只判断最后一帧 p，也不依赖毫秒定时器认定完成。

点击：原克隆位置/尺寸仍由 morphCoverRectAt(morphP) 生成可动画属性，引擎插值照旧，整个几何补间期克隆保有所有权。上拉：手指仍逐帧写 p，松手几何时长/曲线原样，完成时交棒。关闭：LEAVING 仍排除打开完成门，snapshotShrinkOwned 互斥保留；展开中系统返回仍走既有排队关闭流程，不提前切出完整真封面。设备视觉尚待验证。

## 保持项

- #16 ControlAreaComponent 原样保留：一个 Slider、14/24vp、springMotion(.4,.8)、原 blockSize/Block/seek。height=32vp：24vp trackThickness 不得超组件高度，留弹簧余量；比旧16vp多16vp布局，设备检查控件间距及裁剪。
- mini-bar .02/.03/.05 尾窗、所有 morphSquashY 写入、LANDING squashLandAnim、播放器表面裁剪与真 HDS systemMaterialEffect 均未改。
- 新增依赖：无；新增权限：无；oh-package.json5/module.json5 无改动。

## 构建和自检

- 最终 default assembleHap debug：exit 0，BUILD SUCCESSFUL in 29 s 650 ms。
- tools/check-mini-bar.ps1 A–F 全 PASS；git diff --check 通过。
- HAP：products/default/build/default/outputs/default/musichomesample-default-signed.hap，23639784 bytes；ets/modules.abc 命中 RzdCoverOwnerV17。
- 构建有仓内 ArkTS 警告，并非零警告构建。日志 cover-owner-v17-build.log。

## 上机判据

抓 hilog，grep `RzdCoverOwnerV17|RzdCoverOwnerV15|RzdClosePath|RzdScrubberV16|RzdSquash`。

1. 点击打开：封面从真实迷你条封面位置放大飞入；`sample=mid commit=true finished=false p=1 clone=true real=false` 是此次同步目标路径的关键证据。随后 `geometry-finish` 才出现 clone=false real=true。日志只证明应用状态，仍需录屏确认轨迹与交接无闪。
2. 上拉展开：跟手、中途停住、反向、松手展开；轨迹与现状一致，完成前只画克隆。p接近1不应提前交棒。
3. 正常关闭与展开中系统返回：每帧只有一个封面，无双封面/空白/闪回整页；snapshot成功时overlayPaint=false。另测快速打开关闭后再次打开，旧token应打印stale而不影响新会话。
4. Slider：静止14vp、按住24vp、松手/Cancel弹回14vp；拖动跟手，滑块不变形；检查32vp占高后的时间行间距和祖先裁剪。
5. 额外检查关闭系统过渡动画后打开/返回，不停在ENTERING。

官方依据：[显式动画 animateTo](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-explicit-animation)，MCP全文存 cover-owner-v17-official.txt。REMOVED：整个动画结束并被移除时回调；LOGICALLY 可能还有长尾，本实现未选。官方说明系统关闭过渡动画或tempo=+∞可立即回调，退后台有限动画也会结束；因此“完成”指引擎完成语义，不推断屏幕已扫描输出某一帧。
