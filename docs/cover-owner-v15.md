# 第十五次会诊：点击展开封面所有权（编译级候选）

基线 HEAD 3862dfc，开工工作区干净。无新增依赖、无新增权限；oh-package.json5/module.json5 均未改。

## 源码证据与根因

以下 PlayerExpandState 行号为修改后行号（新增注释导致后段比基线多一行）。

- PlaybackPage.ets:3724–3726 点击播放页 intro 把 drive 置 ANIM；3753 调用 startGeoDriver；6343–6347 animator.onFrame 逐帧 applyMorphProgress。即真实几何进度 morphP 仍在 0→1。
- Index.ets:1241–1255 的 morphDrive Monitor 调用 focusMorphOverlayForPageIntro；PlayerExpandState.ets:4587–4590 在 animateTo 闭包直接写 morphOverlayP=to（打开 to=1）。这个字段是动画目标，不能作为已经落位的证据。
- 基线 PlayerExpandState.ets:4022–4025：只排除 LEAVING，随后 op>=.999 就返回 false，直接关闭 morphOverlayBridging。
- 基线 :5225–5226 同一 op 判据令 morphSessionDriving=false；基线 :902–903 同一 op 判据令 realCoverVisible=true（前面的 session guard 此时也不再阻挡）。
- 因此点击时 ENTERING、p 尚在中途但 op 已为1：克隆门=false，morphOverlayBridgeOpacity()（现4192）返回0；真实封面门=true。PlaybackPage.ets:7758 的真实封面 alpha 据此变1，挂在页面变换容器内，随页面升入。Index.ets:3008（原2983）仅在 clone门或hdsBarSuppressed时构造克隆，不能挽救关闭的绘制门。
- Index.ets:1733–1734（原1708–1709）克隆 alpha=bridgeOpacity*morphTailOpacity，visibility=morphPaintHidden。#10/#11窗口确实参与克隆，但它由p计算，在p>=.05且来源条隐藏时为1，不能解释整个打开过程；真正先归零的是 bridgeOpacity。
- PlayerExpandState.ets:3982 克隆几何一直用 morphCoverRectAt(morphP)，不是 morphOverlayP。上拉逐帧同步两进度时原门工作正常；点击的目标值与真实进度不一致触发回归。

## 最小改动

PlayerExpandState.ets 三处展开落位判断（902、4025、5226）从 morphOverlayProgress()>=.999 统一改为 morphP>=.999，保留原 LEAVING 排除条件。点击/上拉共用同一公式，不增入口分支、不强制 settle。

Index.ets 增加只读 V2 Monitor，grep `RzdCoverOwnerV15`：p/op/stage/drive/clone/real/cloneAlpha/hidden/snapshot/rect。每5%进度档或所有权/相位变化记录一次，观察op=1而p在中途时clone仍为true、real为false（正常有效几何且非snapshot路径）。

尾部 sourceBarOpacity/morphTailOpacity/morphPaintHidden 和阈值 .02/.03/.05、克隆alpha与visibility逐字保留；不改miniOut、settle、LANDING/squash写入、HDS systemMaterialEffect、表面几何/裁剪、按钮曲线。PlaybackPage零改动。

## 验证

- default assembleHap：exit 0，BUILD SUCCESSFUL in 32 s 449 ms；完整日志 cover-owner-v15-build.log。构建有工程 ArkTS 警告，未当作无警告构建。
- tools/check-mini-bar.ps1：A–F 全PASS；git diff --check通过。
- 已生成 products/default/build/default/outputs/default/musichomesample-default-signed.hap，23642660 bytes。
- hdc list targets=[Empty]。仅源码级、编译级、产物生成级通过，未做设备视觉验证，不称已修复。

## 上机验收

1. 首页与二级页分别点击迷你条：封面必须从迷你条实测封面位置变大飞入，不能跟随整页从底部升起。中段日志应clone=true、real=false、有效rect；p>=.05时cloneAlpha=1、hidden=false；op即使为1也不得提前交棒。
2. 两处上拉展开、停住及反拖：保持原来正常轨迹。相同p与同一实测端点应输出相同封面矩形和alpha，入口不参与公式。p接近1才交真实封面。
3. 关闭按钮、系统返回、下拉关闭及展开中返回：每帧只能一个封面；快照路径snapshot=true时clone=false，活页路径依旧按原门；无闪出第二张。
4. 回拖末段保留原尾部窗口与真HDS交接、落条回弹；grep RzdSingleLayerV11 / RzdSquash / miniOut 对照旧版。窗口空档是保留行为，不能将其误判为本轮新增闪失。
