# 第十次会诊：按进度的尾部 HDS 接管（编译级候选）

## 基线与结论

实际开工 HEAD=2552da7、工作区干净。它在用户指定 38f2dcc 之后仅多一条 check-mini-bar.ps1 的 C3 自检修正，本轮保留。

#9 的反向第一帧 returnHdsVisible 闩锁已整套删除。现在同一 p 对应同一透明度，与方向、速度、手指是否松开无关。未修改上游式 syncMiniOut 的 p<=0 恢复条件。

## 绘制分工与取舍

- p>=0.03：来源 HDS 条 alpha=0；播放器原几何、原裁剪继续运行；表面承托补上 backgroundRevealOpacity，与已有网格一样按背景窗口淡出，跟手 effT=p 时该窗口为 0.04+0.96*clamp(p/0.30)。
- 0<p<0.03：来源条（实色承托+真 HDS systemMaterialEffect+完整内容）整体 alpha=1-p/0.03；播放器总绘制 alpha、壳层封面/按钮副本各乘 p/0.03。
- p=0：来源条 alpha=1、播放器及副本尾部系数=0；不依赖 UP/reverseDragEnd/morphLand。松手后的原状态机清理与回弹继续执行。
- 真条透明度仅在一级/二级宿主施加一次。来源封面/按钮自身 alpha=1；内容根仍用零透明度显隐门，保留量测。没有在子树再次乘 sourceAlpha。
- 未引入新 HDS API，未自绘光感；原 MiniBarMaterialCapsule 的 systemMaterialEffect 与实色承托保持。没有新玻璃节点、没有胶囊几何裁播放器。

两种折中：A 严格等 p=0 才显示真条，材质在终点才切换，可能有末帧变化；B 真条在最后3%渐入，允许极短双层交叠，优先透明度连续。本轮选 B；3% 来自用户给定上游玻璃窗口，但让来源真条承担该窗口是本仓推导，不是上游真条提前恢复事实。p=.01 时来源alpha为2/3，并非已经100%最终像素；p=0且手指未松时才100%最终。若要求 .05 就100%最终，与连续缩小到0不兼容，需牺牲尾部连续行程。

透明度互补不意味着 SRC_OVER 合成不透明度恒1。承托与网格是两层，二者各自背景alpha相同，不将最终合成像素alpha冒称为该公式。尾部可能出现短暂双轮廓/明暗变化，HDS私有轮廓与材质采样需要设备验收。官方opacity文档仅支持属性语义，不保证 opacity=0 的持续手势行为；本轮未改手势结构，不声称系统保证。

官方参考（已通过知识库 getDocumentsById 获取）：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-opacity

## 按住慢拖验收

从 p约.85 慢拖到0，不松手，在每个点停一下；一级、二级各验一次，再在.03两侧微幅往返。

| p | 背景窗口值（effT=p） | 真HDS条alpha | 播放器/副本尾部系数 | 判据 |
|---|---:|---:|---:|---|
| .60 | 1 | 0 | 1 | 大表面连续缩小，不能出现固定最终条 |
| .35 | 1 | 0 | 1 | 同上，不能因反向切层 |
| .15 | .52 | 0 | 1 | 原表面继续收缩并渐透 |
| .05 | .20 | 0 | 1 | 已接近小端，但真条尚未出现 |
| .03 | .136 | 0 | 1 | 接管窗口起点，各alpha连续 |
| .01 | .072 | .6667 | .3333 | 真材质逐渐显现，残余表面/副本退出 |
| 0 | .04 | 1 | 0 | 手指仍按住时完整最终条，之后松手仅原收尾 |

日志：`hdc shell hilog -x | grep -E 'RzdTailHandoffV10|RzdMorphSolid|RzdSquash|miniOut|RzdBarHandoff'`。

- RzdTailHandoffV10：p/effT、sourceAlpha、morphAlpha、finger、stage、scale、clipH；80ms节流，切入tail/source强制记录。按住应finger=true。若p=.8时sourceAlpha>0，不符合本方案。
- RzdMorphSolid：bgAlpha/tailAlpha与既有几何，验证背景不再被恒实心承托遮住。
- miniOut=false仍只在p=0恢复；source alpha的尾窗不改该逻辑位。
- RzdSquash/RzdBarHandoff：松手后回弹所有权；本轮没有任何morphSquashY写入变更、没有新增morphSettleOpen调用。

## 变更与验证

完整代码已落在五个ets：PlayerExpandState、PlaybackPage、Index(default)、HomeMiniBarPlayer、HomeMiniBarAlbumCover。没有新增依赖和权限，oh-package.json5/module.json5均未修改。

default assembleHap：BUILD SUCCESSFUL in 56 s 957 ms，退出0；完整日志 tail-handoff-v10-build.log。构建有现有ArkTS警告，非零告警构建。check-mini-bar.ps1 全项通过；git diff --check通过。hdc list targets=[Empty]，仅源码/编译/产物级，不声称已修复。

产物：products/default/build/default/outputs/default/musichomesample-default-signed.hap（23,573,997 bytes）。
