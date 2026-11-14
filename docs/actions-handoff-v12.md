# 第十二次会诊：按钮独立交接（编译/产物级候选）

基线 HEAD=5759168，开工工作区干净。只调整三个迷你操作按钮的绘制所有权及同源量测；V11 的表面/背板/封面/meta 淡出窗口保持。

## 原因与落点

原按钮由 products/default/src/main/ets/pages/Index.ets 的 MorphMiniBarClone → MiniBarActions 绘制。克隆 Row 旧 alpha=actionsOpacityAt(p)*morphTailOpacity()，并受 morphPaintHidden()；p≥.20 旧操作窗已为0，尾段则因 V11 表面门归0。

V12 新增 PlayerExpandState.morphActionsOwned()：手机形变宿主、p>0、按钮矩形有效，且会话正在驱动或 HDS 仍受抑制时由克隆拥有按钮。Index 克隆 alpha=1，visibility 只读该门。HomeMiniBarPlayer 的真按钮 paintHidden 使用完全相同的门。p=0 源 alpha=1，源按钮 Visible、克隆 Hidden。Hidden 保留量测布局，不另加异步交接任务。

MiniBarActions 的 actionsNodeId 从带 margin 的内层 Row 移到完整组件根 Stack；源/克隆同一组件根，同一 40vp 按钮、24fp 图标、2vp 间隔、6vp 尾部留白。完整三按钮簇自然宽130vp。measureGeometry 仍量 MINI_BAR_ASIDE_ID / FLOATING_ID，缓存 asideWinX/Y/W/H，克隆直接使用该 rect。图标都直接读共享 MusicAppState.isPlay。没有复制上游结构。

## 改动清单

- common/musicbasic/src/main/ets/model/PlayerExpandState.ets：只加按钮所有权只读函数。
- products/default/src/main/ets/pages/Index.ets：按钮 alpha=1 + 互斥 visibility；V2 Monitor 交接日志。
- features/playlist/src/main/ets/view/HomeMiniBarPlayer.ets：源按钮 paintHidden。
- features/playlist/src/main/ets/view/MiniBarActions.ets：根节点同源 id、paintHidden 参数、矩形/图标诊断。
- tools/check-mini-bar.ps1：增加 F1–F7 按钮独占门与旧 fade 移除检查。
- docs/actions-handoff-v12.md、docs/actions-handoff-v12-build.log：报告及完整构建日志。

无新增依赖、无新增权限；oh-package.json5 / module.json5 无改动。没有新增 morphSettleOpen 调用；不改 LANDING 的 morphSquashY 写入；播放器表面裁剪、真 HDS systemMaterialEffect 保持。

## 手指不松逐点验收

以下为有效形变会话的源码预期，尚未设备验收。首页/二级入口、播放与暂停状态都应各走一遍，末端再往回微拖检查可逆性。

| p | 克隆按钮 alpha | 真按钮 | 真宿主 alpha | 形变族表面 alpha |
| --- | ---: | --- | ---: | ---: |
| .35 | 1 | Hidden | 0 | 1 |
| .15 | 1 | Hidden | 0 | 1 |
| .05 | 1 | Hidden | 0 | 1 |
| .03 | 1 | Hidden | 0 | 0 |
| .02 | 1 | Hidden | 0 | 0 |
| .01 | 1 | Hidden | .5 | 0 |
| 0 | Hidden | Visible | 1 | 0 |

每一点必须看到且只看到一套播放/暂停、下一首、列表按钮；背景按 V11 淡出。p=0 按钮的中心、尺寸、间隔、播放/暂停图标必须与真条一致。不能用日志代替截图/录像确认零跳变。

唯一诊断锚点：RzdActionsHandoffV12。

```powershell
hdc shell hilog -x | Select-String 'RzdActionsHandoffV12|RzdSingleLayerV11|RzdHandoffRectV11|RzdSquash|miniOut'
```

- 所有权行：p>0 owner=clone cloneAlpha=1 sourceButtonsHidden=true；p=0 owner=source cloneAlpha=0 sourceButtonsHidden=false，sourceHostAlpha=1。
- kind=measured：源 id=rzd_mini_bar_aside（或 floating），克隆 id=rzd_morph_actions_clone。对照交接前后 rect 四值，isPlay、iconFp=24、buttonVp=40、gapVp=2 必须一致；窗口坐标单位vp，矩形取自现有 getRectangleById。kind=measure-miss 是量测失败，不能算验收通过。
- RzdSingleLayerV11 / RzdHandoffRectV11 仍描述表面族，不再用 morphHidden 推断按钮是否隐藏。
- RzdSquash / miniOut 检查既有落地写入及交棒顺序。

## 验证

- default assembleHap debug：BUILD SUCCESSFUL in 58 s 736 ms，exit=0。构建保留工程现有 WARN（含 pc 非当前 product 警告），没有编译错误。
- tools/check-mini-bar.ps1：原 A–E 及新增 F1–F7 全 PASS。
- git diff --check：通过。
- 独立只读源码审查：所有权、源/克隆祖先 alpha、root rect 与 V2 订阅未发现具体缺陷。
- 签名 HAP 的 ets/modules.abc 命中 RzdActionsHandoffV12 / morphActionsOwned / sourceButtonsHidden / kind=measured。
- HAP：products/default/build/default/outputs/default/musichomesample-default-signed.hap，23,590,031 bytes。
- SHA256：3BF094372FEB34C7A4420E0584D3818BD7B6A1CFEBD3B7722F6871B06C50FB25。
- hdc list targets：[Empty]。仅源码/编译/产物级通过，未安装、未上机，不能声称已修复或已经像素零跳变。
