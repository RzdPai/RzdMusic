# 第十六次会诊：进度条回退 A / 最小实现 B

## 验证边界

HEAD=2651c4e，开工工作区干净。hdc list targets=[Empty]。本轮完成源码隔离、两次 default 编译及签名产物生成，未完成设备视觉 A/B，不能宣称封面已修复，也不能宣称回退证明进度条有因果或无因果。

## A：完整回退进度条改动

执行 git restore --source=7c7287a --worktree -- features/player/src/main/ets/view/ControlAreaComponent.ets，随后 git diff --quiet 7c7287a --该文件 exit0。#15 Index / PlayerExpandState 不动。

default assembleHap exit0，BUILD SUCCESSFUL in 34 s 566 ms。
- 产物：slider-v16-a-signed.hap，23636826 bytes
- SHA256：D0953CE583E55C016C9844E774689B99FE57032EB0E4780D3B5E4D04B6E4A1CF
- 日志：slider-v16-a-build.log；回退补丁：slider-v16-a.patch（相对HEAD，仅供复现A，不要直接在B上叠加）。

## B：最终最小实现

唯一源码修改 features/player/src/main/ets/view/ControlAreaComponent.ets。基于7c7287a：仅一个Slider，一个@Local scrubberTrackThicknessVp=14；onTouch Down→24，Up/Cancel→14；animateTo curves.springMotion(0.4,0.8)。保留原onChange seek行为、颜色、blockSize、margin、HitTestMode.Block。无预览值、无进度Monitor、无第二Slider/Stack/scale。

Slider高度16→32vp：官方规定trackThickness超过组件宽高会回退默认值，故必须容纳24vp并留弹簧余量；这是单Slider实现的必要布局变化，会增加该控件占高16vp，需上机确认与时间行布局。未裁播放器表面。显式blockSize不改且不施加scale，滑块视觉仍待上机。

官方来源：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-slider
MCP ID：alliance/document/cn/harmonyos-references/ts-basic-components-slider；本轮全文：slider-v16-official.txt。

default assembleHap exit0，BUILD SUCCESSFUL in 34 s 302 ms。
- 产物：slider-v16-b-signed.hap，23635246 bytes
- SHA256：B69C83C62FEA22AD2B32FA4CADACE93AB79FDB3C997838652EFC571C3BF1DE55
- 日志：slider-v16-b-build.log
- git diff --check通过；tools/check-mini-bar.ps1 A–F全PASS。
- Index / PlayerExpandState / PlaybackPage未修改；mini-bar尾窗、morphSettleOpen调用、morphSquashY写入、播放器表面保持HEAD。无新增依赖或权限，oh-package.json5/module.json5均不变。

## 因果证据与新的定因方向

3862dfc对进度条新增的Monitor只清本地预览，弹簧只写本地厚度；绘制Slider没有onChange。未找到双Slider直接写封面/形变的调用链。它是否通过布局、挂载时序或负载间接触发封面问题：未知；最小实现已避免这些新增结构，仍待设备A/B。

纠正#15记忆中将候选假说表述为“源码根因”的过度定性：点击不保证由页面animator逐帧驱动morphP。
- Index.ets:719–749：beginOpenMorphOnClick→pushPlayerRoute→settlePullOpen(true)。
- Index.ets:1382、1406–1412：置ANIM后在animateTo闭包调用applyMorphProgress(1)。
- PlayerExpandState.ets:4807–4808：直接写morphP=t；#15三门:902/:4025/:5226仍可能立即交还真封面。
- Index锚点不足时:1304–1307置FINGER+pullDragging；PlaybackPage.ets:3627–3633对此直接返回，跳过页面intro。
- 页面另一入口:3677→3753→6343–6347才使用animator.onFrame逐帧applyMorphProgress；上拉Index:1135–1140连续提交中间进度。

这是确定可达的源码路径，是否为本次复现现场路径、是否抢写仍须日志确认。本轮不扩大范围修改状态机。封面共用morphCoverRectAt(morphP)，未发现点击/上拉插值公式分叉。

## 上机 A/B 与判据

同一设备同一歌曲先安装A，点击mini打开并上拉对比；再安装B重复。A若仍跟页上升，可排除3862dfc进度条新增结构作为必要条件；若A正常而B异常，继续隔离单Slider厚度/控件占高；若A、B均正常，支持旧双层实现相关，但具体机制仍未确证。

B验收：①点击打开封面从mini封面位置放大飞入；②上拉展开正常；③静止14vp，按住24vp，松手/取消回弹，拖动跟手，滑块不变形；并确认时间行位置可接受。

日志grep：RzdScrubberV16（pressed/targetVp=24→14）、RzdCoverOwnerV15|RzdMorphGeoTick|RzdMorphOpen|OVS|OVI|expand intro|pull settle。若A仍复现，重点看点击shell settle后p是否立即1且clone=false/real=true、是否缺失GeoTick或有两driver并存。若p/rect连续且clone=true/real=false，再查克隆实际绘制与宿主遮挡。
