# 第十九次会诊：进度条按住加粗候选

基线：4c166ed896dcadb5e548b1393b264e908e4078f1（#16/#17）。前三提交：4c166ed、2651c4e、3862dfc。开工已有未跟踪 docs/scrubber-v18-build.log，保留。

## 依据与范围

旧 ControlAreaComponent.ets:69、71–79、707：通过 @Local 14/24 驱动原生 trackThickness；712–718 已有 onTouch，不是 onChange 判按压。727 为 height(32)，24<32，因此不能认定“超过组件高度回默认值”是这份代码的根因。旧路径只有原生 trackThickness 状态重绑，没有独立 scale 绘制，且只打 console 日志，无法由用户应用内运行日志判断 Down 是否到达。

用户已上机确认单 Slider 版本看不见变粗；目前不足以把原因定为原生响应式失效、触摸未收到或祖先裁剪。此次绕开原生厚度动态变化，以装饰轨道 scale 为主；不编造系统行为。

官方资料本轮通过 tools/mcp-query.ps1 getDocumentsById 复核：
- https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-slider
- https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-transformation
- MCP ID 前缀均为 alliance/document/cn/harmonyos-references/。scale 可分别设 x/y 及 centerY；Slider trackThickness 超组件宽高时回默认值。没有将文档解释为本设备动态重绘保证。

## 完整实现所在文件与唯一检索锚点

features/player/src/main/ets/view/ControlAreaComponent.ets；统一 grep `RzdScrubberV19`。

- :68–84：旧 thickness Local → V2 pressed + preview；Down 初始化预览，Up/Cancel 松手，springMotion(0.4, 0.8) 写 pressed；不从 SliderChangeMode 收细。
- :703–722：底层 Slider，固定 trackThickness(14)，透明 block、原 blockSize，以保留相同原生 OutSet 几何；scale({x:1,y:pressed?24/14:1,centerY:'50%'})，None、不聚焦、不参与无障碍。
- :723–753：顶层原生交互 Slider，固定 trackThickness(14)、原 blockSize、height(32)、Block；透明轨道，仅画原滑块。onChange 只新增本地 preview 更新，让装饰层在 Moving 时也跟随；seek 条件仍是 End / Begin / Click，pageShowTime 原样。
- :754–771：公共 Stack，height(32)、原左右 margin，Default 命中，clip(false)。两个 Slider 的 min/max/step/value/高度/布局边距完全同源；只有装饰层有 scale，不对整个 Stack 缩放。公共盒仍占 32vp，时间行与外层 Column 不改。

应用内运行日志 grep `RzdScrubberV19`：
```text
[RzdScrubberV19] pressed=true scaleY=1.7143 idleVp=14 pressedVp=24
[RzdScrubberV19] pressed=false scaleY=1.0000 idleVp=14 pressedVp=24
```
日志记录动画目标，不冒充逐帧或像素量测。无 true 行说明 Down 尚未进入本回调；有 true 但视觉不变则继续查绘制/裁剪。

只改此业务源码文件。openGeometryFinished / settlePullOpen / finish-callback / mini-bar 尾窗 / morphSquashY / 播放器表面零改动。新增依赖：无；新增权限：无；oh-package.json5、权限清单无变化。

## 验证

- git diff --check：通过。
- tools/check-mini-bar.ps1：A–F 全 PASS。
- default debug assembleHap：exit 0，BUILD SUCCESSFUL in 45 s 242 ms；构建日志 docs/scrubber-v19-build.log（含工程警告）。签名 HAP 的 ets/modules.abc 已检出 RzdScrubberV19，产物级确认新代码入包。
- 签名产物：products/default/build/default/outputs/default/musichomesample-default-signed.hap。
- hdc list targets：[Empty]，未执行设备验收。

## 上机判据（待验证）

1. 按住不动即变粗，拖动保持，Up/Cancel 弹回。
2. 滑块不变形，拖动跟手；确认装饰选中轨道与滑块同步。
3. 点击打开封面仍放大飞入。
4. 上拉、关闭、系统返回不回归。

仅交付源码/编译候选，不能声称已修复。
