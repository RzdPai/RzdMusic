# 第十三次会诊：三按钮上游淡出曲线

基线：36c4e0a，开工工作区干净。仅恢复按钮 alpha 曲线，保留 #12 单一所有权。

## 上游证据（行号均为原文件行号）

完整 dump：`C:\Users\Administrator\Desktop\RzdProject\_recover\disasm\wujie.pa`。

1. `MainPage.morphActions`：dump 148351；仓内 `docs/upstream-collapse-full.md:493–510`：148361 的 `definefunc ... MainPage.#~@1>@1f*#` 注册 Row builder。32 函数摘录未包含其完整回调体，故继续读原 dump。
2. `MainPage.#~@1>@1f*#`：dump 156574；156674–156690：
   ```text
   156676 ldobjbyname 0x53, "opacity"
   156679 ldobjbyname 0x55, "morph"
   156681 ldobjbyname 0x57, "actionsOpacityAt"
   156684 ldobjbyname 0x59, "morphT"
   156687 callthis1 0x5b, v2, v4
   156690 callthis1 0x5d, v0, v2
   ```
   即 `Row.opacity(this.morph.actionsOpacityAt(this.morphT))`。156663–156673 独立设置 `scale({ x: 1, y: morphSquashY })`。
3. `design.src.main.ets.logic.MiniMorph.actionsOpacityAt`：dump 92039–92060：
   ```text
   92040 ldai 0x0
   92041 sta v0
   92042 ldai 0x1
   92043 sta v1
   92044 fldai 2.000000e-01
   92045 div2 0x0, a3
   92046 sub2 0x1, v1
   92047 sta v2
   92048 lda v0
   92049 less 0x2, v2
   92050 jnez jump_label_0
   92051 lda v1
   92052 greater 0x3, v2
   92053 jeqz jump_label_1
   92054 mov v0, v1
   92055 jmp jump_label_0
   92056 jump_label_1:
   92057 mov v0, v2
   92058 jump_label_0:
   92059 lda v0
   92060 return
   ```
   还原：`v = 1 - p / 0.20; return v < 0 ? 0 : (v > 1 ? 1 : v)`。
   `alpha(p) = clamp(1 - p / 0.20, 0, 1)`，0.20 是直接读出的浮点立即数，不是调参窗口。开/收共用进度映射，无额外时间 easing。

仓内 `PlayerExpandState.actionsOpacityAt`（544–547）与上述完全一致，保持零改动。meta 的独立曲线本轮不改。

## 最小实现

`products/default/src/main/ets/pages/Index.ets` 的 `MorphMiniBarClone`：

```typescript
.opacity(PlayerExpandState.actionsOpacityAt(this.expandState.morphP))
.visibility(this.expandState.morphActionsOwned() ? Visibility.Visible : Visibility.Hidden)
```

旧值：`.opacity(1)`。新值：上游曲线。不乘 `morphTailOpacity()`，不套 `morphPaintHidden()`。

`HomeMiniBarPlayer` 保持 `paintHidden: morphActionsOwned()`、`actionsOpacity: 1`。
有效形变 p>0 且锚点有效时克隆独占；p=0 克隆 Hidden、真条接管。曲线极限 alpha→1，真条及其宿主在 p=0 alpha=1，源码数值连续。零 alpha 的所有者仍只有克隆，不补第二套可见按钮。

唯一新增日志锚点：`RzdActionsFadeV13`，记录 p / owner / curveAlpha / cloneAlpha / sourceButtonsHidden / sourceHostAlpha / surfaceAlpha / isPlay / rect / squash。原 `RzdActionsHandoffV12 kind=measured` 继续提供簇量测和图标状态。

未改：#11 背景/背板/封面/meta 窗口、PlayerExpandState、任何 settle/miniOut/squash 写入、播放器表面几何与裁剪、真 HDS systemMaterialEffect。无新增依赖或权限，oh-package.json5 与各 module.json5 无改动。

## 手指不松的逐点验收

正常形变且锚点有效；展开与回拖均在各点停住：

| p | 曲线 alpha | 所有者 | 实际按钮 alpha | sourceButtonsHidden |
| --- | --- | --- | --- | --- |
| .35 | 0 | clone | 0 | true |
| .25 | 0 | clone | 0 | true |
| .20 | 0 | clone | 0 | true |
| .15 | .25 | clone | .25 | true |
| .05 | .75 | clone | .75 | true |
| 0 | 1 | source | 1 | false |

每点最多一套绘制；alpha=0 时三按钮应完全不可见。回拖从 .20 到 0 逐渐显现，展开反向淡出。p=0 真条位置、图标与满 alpha 应连续；像素连续性待设备验收。

日志过滤：`RzdActionsFadeV13|RzdActionsHandoffV12|RzdSingleLayerV11|RzdSquash|miniOut`。重点核对 curveAlpha 与上表、cloneAlpha 在 p0 为0、owner=source、sourceHostAlpha=1。表面日志不代表按钮 alpha。

## 验证记录

- `tools/check-mini-bar.ps1` A–F 全 PASS；F7 更新为上游曲线与 V11 门独立检查。
- `git diff --check` 通过。
- `hdc list targets` 返回 `[Empty]`；仅可报告源码/编译/产物级，未进行设备像素或持续手势验收。
- default debug `assembleHap`：BUILD SUCCESSFUL in 1 min 42 s 945 ms，exit 0。CompileArkTS 58 s 745 ms。构建日志同目录 `actions-fade-v13-build.log`（2130 行成功标记）。
- 签名 HAP：`products/default/build/default/outputs/default/musichomesample-default-signed.hap`，23,589,698 bytes；SHA256 `5A1C30C0A36B7E5BB64F6D9DBDF06B4D61322561DFF5F1835F66B7BB331ADD59`。包内 `ets/modules.abc` 已命中新锚点 `RzdActionsFadeV13`，确认本轮代码进入产物。
- 仓内改动清单：Index.ets、tools/check-mini-bar.ps1、本报告、本轮构建日志。仓外更新全局/项目记忆。未创建提交。
