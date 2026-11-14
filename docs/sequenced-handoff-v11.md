# 第十一次会诊：单层顺序交接（编译候选）

基线：0bced58，开工工作区干净。设备列表为空；本文区分源码证明与待设备验证。

## 定位证据（基线行号）

- 真条：首页 Index.ets:2054 的 MiniBarMaterialCapsule，外 Column:2092 sourceBarOpacity，:2093 sourceBarPaintHidden；二级 :2204 同组件，外 Stack:2285/2286 同门。外壳 HDS miniBar enableMiniBarBackground=false，不另画迷你条背板。
- 真条内部有两个背景绘制节点：MiniBarMaterialCapsule.ets:727-733 自算胶囊的 FF 实色 Column（#9 新增），:734-780 真 HdsTabs/systemMaterialEffect。两者同时常驻；前者不是材质。其矩形来自 barWidth/barHeight、capsuleLeft/Top，HDS 轮廓来自 TabBar 排版；不能凭输入相同声称私有材质像素轮廓完全相同。V11 删除额外实色 Column。
- 形变族：PlaybackPage 的 MorphSolidSurface/网格共用原播放器 Column 的 scale/clipHeight/translate/radius；整层 :7588 乘 morphTailOpacity。Index:1538 的 MorphMiniBarClone 只画按钮，rect=asideWinX/Y/W/H，alpha=actionsOpacityAt(p)*morphTailOpacity；无背景，不能单凭“三按钮”断言深色块就是该节点。封面副本 :1682 同乘 tail。
- PlayerExpandState.ets:2294-2312（#10）：来源 alpha=clamp(1-p/.03)，形变 alpha=clamp(p/.03)，所以 0<p<.03 明确同时绘制；sum=1 仍是两套不同轮廓，并非互斥。
- 原 barWin 来自 measureGeometry:2970 的 MINI_BAR_ID/MINI_BAR_FLOATING_ID 内容根；asideWin 来自操作区节点；形变表面基于 morphInitParams 的 barWin 与整窗变换。并未量到 HDS 私有材质轮廓。
- HomeMiniBarPlayer:436 actionsOpacity=1，AlbumCover:298 opacity(1)，并不取消父层透明度；Player 根:474 仍由 sourceBarPaintHidden 隐藏。源码不支持把 alpha=1 判为宿主门失效。
- 若三个隐藏标志同时提前释放，#10 sourceBarOpacity:2298 直接 return 1，绕过 p 窗口，是另一条源码可达风险；本轮把 morphSessionDriving 加入抑制条件，并让形变 alpha 遇到 sourceAlpha>0 立即归零。没有设备日志，未证明截图走了这条分支。
- 对于实际 p>=.03 且上述任一标志仍 true 的稳态，#10 来源 alpha=0 且 Hidden；源码不支持“该条件下真条提前打开”的结论。3% 外的截图解释仍须新日志与画面对应。未将任何未核实系统行为写成根因。

## V11 实现

纯 p 可逆顺序（不判断回拖方向）：

| p | 形变族 alpha | 来源 HDS alpha |
|---|---:|---:|
| p>=.05 | 1 | 0 |
| .03<p<.05 | (p-.03)/.02 | 0 |
| .02<=p<=.03 | 0 | 0 |
| 0<p<.02 | 0 | 1-p/.02 |
| p=0 | 0 | 1 |

来源非零时形变额外强制归零，故任何旗标组合下 alpha 乘积=0、sum<=1。播放器和按钮/封面副本均有硬 visibility 门，不只依赖 opacity。手势节点保留挂载；持续手势的设备行为仍待测。

几何：MiniBarMaterialCapsule 的 ContentLayer 设置唯一 SOURCE_CAPSULE_RECT_ID；它的尺寸/位置与该组件 HDS 配置共用 barWidth/barHeight/capsuleLeft/Top，measureGeometry 优先量这个节点；其它宿主保留旧节点 fallback。播放器几何使用 g=clamp((p-.03)/.97)，p=.03 时已到该源端点；不新增 Path、不拿胶囊裁播放器，只改变原变换插值进度。asideWin 仍只供按钮局部摆位，绝不当整条 rect。

可证明的是应用布局/变换端点同源；HDS 私有材质外延、折射、阴影与输入矩形的像素关系没有可观测证明，必须设备核对，不声称完全像素相等。

未改 morphSettleOpen 调用、commit 判据、syncMiniOut 门槛、任何 morphSquashY 写入、LANDING/squashLandAnim 时序。一级光感依然来自真 systemMaterialEffect；无新增依赖/权限。没有迁移宿主结构。

## 上机判据

手指不松，慢拖并停在 .60/.35/.15/.05/.02/.01/0，再反向微动一次：

| p | sourceAlpha | morphAlpha | sourceHidden / morphHidden |
|---|---:|---:|---|
| .60/.35/.15/.05 | 0 | 1 | true / false |
| .02 | 0 | 0 | true / true |
| .01 | .5 | 0 | false / true |
| 0 | 1 | 0 | false / true |

形变族 alpha 是整族上限，按钮还乘 actionsOpacityAt，网格/实色还乘既有背景窗口，不能当像素覆盖率。p=.02 允许无条；不会显示两个。

`grep -E 'RzdSingleLayerV11|RzdHandoffRectV11|RzdMiniBarRect|RzdSquash|miniOut'`：

- RzdSingleLayerV11：overlap=false，sum<=1，两 alpha 永远不同时>0。finger=true 表示尚未松手。若同时看到两层而该行正确，要检查材质轮廓与绘制树，不再加 cross-fade。
- RzdHandoffRectV11：endpoint=true（p<=.03）时 delta 的 x/y/w/h/r 应为 0（容许浮点舍入 <.01vp），sourceRectId=rzd_source_capsule_rect；仅为变换模型证据。对应 RzdMiniBarRect kind=content/box 的矩形共同核对，不拿 slot 探针冒充材质像素。
- RzdSquash：LANDING 的既有 squashLandAnim 日志继续完整，不能出现新增路径强行写 1；miniOut 仍 p<=0 才 false。

折中：按进度定义的 .02~.03 空档，手指若一直停住会一直保持；它不是“保证几毫秒”的时间动画。可保证到 p=0 最终 HDS 显示，不能承诺所有回拖停点都已是最终形态。保留连续大表面与所有中途点最终形态同时成立有冲突，本轮选择单层和顺序交接。

## 验证

default assembleHap：BUILD SUCCESSFUL in 54 s 818 ms，exit=0；见 sequenced-handoff-v11-build.log（含工程既有警告）。check-mini-bar.ps1 全过，git diff --check 通过；alpha 在 [0,1] 采样 10001 点，交叠/和越界违反数=0。hdc list targets=[Empty]，只能给编译/产物级候选，不声称已修复。
