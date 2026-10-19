# scrubber 14c 核对与加粗（覆盖14b结论）

## 结论与旧值→新值

本仓HEAD原值为固定trackThickness=12vp。14b绘制层静止7/12、按住1倍，确实把静止态变细，违背肉眼加粗目标。
14c保留两同几何Slider绘制/输入分离，绘制目标改为静止14、按住/拖动24，scale.y分别14/12=1.166667和24/12=2。
以原轨道实际绘制厚度T表示：旧T → 静止7T/6 → 按住2T。因此相对原轨道静止增加16.67%，按住增加100%；不是仅比14b更粗。
14/24是本地调参：上游真实7/12统一乘2，保留拖动/静止12/7比例。不是上游静止14或上游12/更大值。
目标vp是按原12vp标称轨道计算的视觉等效值；系统实际像素与祖先裁剪仍待设备验收，不宣称已修复。

## 原文逐寄存器证据

原文绝对路径：C:\Users\Administrator\Desktop\RzdProject\_recover\disasm\wujie.pa。

- scrubber完整函数177708–177819：177738–177743注册Progress回调#^2；177748–177753注册Slider回调#^3。两者同在Stack中，不是环形缓冲条。
- Progress #^2：197244为Progress，197248创建value/total/type。197260的0x7存v4，197262的0xc存v5。total实际由v0写入（197264–197265），type明确ProgressType.Linear（197266–197268）。197312–197319读取scrubbing，false保留v4=7，否则mov v4,v5取12，写strokeWidth。因此7/12属于线性Progress轨道粗细，不是total或ProgressType枚举。
- Slider #^3：197333为Slider；197352的0x7存v5，197354的0xc存v6。max由v0写入（197356–197357），style明确SliderStyle.InSet（197358–197360）。197373取trackThickness方法，197375–197379读取scrubbing，false保留v5=7，否则mov v5,v6取12；197382调用trackThickness(v5)。所以Slider同样scrubbing ? 12 : 7，不能只看立即数出现位置。
- 197385–197417：Slider轨道/选中/block透明，blockSize=0；可见轨道由Progress绘制。本仓保留自己原block与OutSet默认交互，不照抄上游透明block。
- 上游Stack高40：197229–197234。本仓固定16盒保持原样。
- 拖动动画：197631–197637 onChange调用scrub.feed；PREVIEW判断197643–197650；首次scrubbing=false时197675–197689 Context.animateTo使用SP_BOUNCE，回调197815–197819写scrubbing=true，从7切12。
- SEEK判断197697–197704；非Click路径197789–197807清理relax并用SP_BOUNCE动画，197879–197883写scrubbing=false，从12回7。Click路径197752–197786另有短暂true和RELAX_DELAY计时，197852–197894弹回false。本仓保留14b的按住/松手交互，不新增上游Click延迟。
- SP_BOUNCE：Tokens槽0x2e，98170–98178 springMotion(0.4,0.8)。不是按钮pressAnim。

## 实现范围

唯一源码：features/player/src/main/ets/view/ControlAreaComponent.ets。

- 绘制Slider仅轨道可见，block透明、None命中、不可聚焦/无障碍忽略；仅它scale.y。
- 输入Slider仍track12、block资源1vp、height16、原margin/step/seek Begin/End/Click条件；block和父Stack不缩放。
- Down或Begin/Moving进入24；Up/Cancel回14。新增普通scrubberTouchHeld，End/Click检查触摸仍按住就保持粗态，不依赖系统回调先后顺序；组件消失清标志和预览。
- animateTo弹簧闭包只写绘制厚度状态，轨道scale为动画属性；播放预览不放进动画闭包。
- 无mini-bar、PlaybackPage、布局资源、依赖、权限变动。
- grep `RzdScrubberThickness`，本轮应含revision=14c、targetVp=14/24、scaleY=1.166667/2、inputTrackVp=12/inputHeightVp=16/blockVp=1。日志是目标值，不是逐帧像素测量。

## 官方复核

MCP ID：alliance/document/cn/harmonyos-references/ts-basic-components-slider。
https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-slider
本轮核对摘录scrubber-slider-api-14c.txt。trackThickness超过布局宽高会取默认值；因此不直接把24传给16盒，保留原12再做绘制变换。没有声称本机系统已经发生默认回退。

## 验证等级

- default debug assembleHap：exit0，BUILD SUCCESSFUL in 35 s 771 ms；完整日志scrubber-thickness-14c-build.log。工程仍有警告，无构建错误。
- git diff --check通过；tools/check-mini-bar.ps1 A–F全部PASS；git diff --name-only仅ControlAreaComponent.ets，无mini-bar交接代码改动。
- HAP：products/default/build/default/outputs/default/musichomesample-default-signed.hap，23640666字节。
- hdc list targets=[Empty]；仅源码级、编译级、产物生成已过，未做设备视觉验收。
- 上机需确认静止更粗、按住不移动保持粗、拖动/Cancel/快速按放回弹、block不变、24vp视觉溢出未被祖先裁剪/遮挡，时间行和按钮布局不位移。
