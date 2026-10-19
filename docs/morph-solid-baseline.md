# b30fc58 基线重做：实心承托候选

## 基线与材料

开工 git status --short 为空，git log HEAD=b30fc58。README、oh-package.json5、build-profile.json5、Index/MiniBarMaterialCapsule/PlaybackPage/PlayerExpandState 已读。
`docs/upstream-collapse-full.md` 已全文读取。指定的 `docs/upstream-glass-reference.md` 在工作区不存在。补读实际 `C:\Users\Administrator\Desktop\RzdProject\_recover\disasm\wujie.pa` 的相关回调与常量（只读审查）。旧记忆里的七八轮候选已回退，不作为本轮实现依据。

## 上游真实口径

- 基准 Bw/Bh=input.capsule 像素尺寸除以 vp2px(1)。R=morphCapsuleRect 已是vp；不存在则退回输入胶囊。glassX=centerX(R)-(Bw+10)/2，glassY=centerY(R)-(Bh+20)/2。父 Stack.scale={x:R.w/Bw,y:R.h/Bh*squashY}，默认中心缩放；子 MaterialCapsule 固定 Bw/Bh，外盒含10/20 slack，真实 HdsTabs 画材质。不能把外盒边界当可见胶囊边界。
- R来自播放器 expand.visibleCapsuleRect/pullVisibleRect：s=s0+(1-s0)p，h=h0+(H-h0)p，tx=tx0(1-p)，ty=ty0(1-p)，R=((1-s)W/2+tx,(1-s)h/2+ty,sW,sh)。高度通常是二次函数，不能直接线性插值目标矩形。
- MORPH_GLASS_IN_T=0.03（dump 52310-52311），glass alpha=clamp(1-p/.03)。p>=.03时所谓大块由播放器背景表面绘制，并非玻璃克隆全程可见。
- 播放器背景 alpha=.04+.96*clamp(effT/.30)，前提geomReady且不在squash。玻璃与背景alpha不互补。即使互补，SRC_OVER也不能推导总覆盖恒1。
- animateMorphT/animateSquash 使用 animator.onFrame。收起至0后进入LANDING，克隆压至.86/110ms，再320ms过冲回1，结束才finishReverse→NONE→pop→恢复来源条。当前仓库先交还真条、真条自己回弹，与上游不同；本轮遵照约束不改现有时序。
- 文档中多个函数只有observeComponentCreation2/definefunc注册，缺builder回调与完成回调正文；这些细节来自dump补读，不能只凭文档函数名推定。

## 从零方案及实际落点

本仓起手已隐藏HDS真条，克隆只有封面/meta/actions，缺少实心承托。保留这条已经验证好的几何与状态路径，在PlaybackPage既有背景Stack最底增加 MorphSolidSurface：整窗恒定内容尺寸，继承原播放器表面的scale/clipHeight/translate/radius。实心主题底alpha=FF；歌曲取色层按contentP覆盖，原网格仍按原背景alpha显现。于是同一表面连续缩放与变色，承托自身覆盖区域不再透出首页。没有新建盘去裁播放器，没有新增独立几何轨迹或交接标志。

- Index.miniBar()/克隆层：零改动，沿用已有真身隐藏/恢复、封面/meta/actions克隆。
- MiniBarMaterialCapsule：零改动，保留真实HdsTabs/systemMaterialEffect和整根squash。
- PlaybackPage：唯一代码改动，增加不透明承托及节流日志；不改变形变判据或任何squash写入点。
- musicbasic base/dark color：新增morph_mini_solid_surface，分别FFF1F3F5/FF202224，按既有sheet token的RGB去掉透明度；不修改既有token。
- 无新增依赖、无新增权限，oh-package.json5/module.json5不变。

## 无法保证的目标与代价

不能保证“p=0自绘颜色、圆角、几何逐像素等于HDS”。HDS材质含私有采样/光照/边缘算法；现仓barWin量的是内容/宿主，二级含slack，播放器小端也可能沿用宿主盒。补实心底可能更清楚暴露该小端轮廓差。完全一致需要复用同一个HDS材质绘制节点或引入经真机校准的胶囊矩形及材质快照，还可能需要改交棒时序；不应在当前硬约束下偷偷加入。

本候选取舍：维持基线正常打开/关闭、封面和落地回弹；解决绘制覆盖缺口，但p0端点像素一致性与无色差交棒需设备确认，不能声称全部验收通过。

## 上机判据

手指始终不松，上拉后反拖，在p≈.75/.50/.25/.05/0停住并微动：

| p | 应观察 |
|---|---|
| .75 | 大播放器表面，背景网格已显现，不透首页，克隆按钮已退场 |
| .50 | 同一表面连续缩小，没有第二个盘轮廓 |
| .25 | 背景仍有歌曲色，主题实心底承托，不能看见首页文字穿过 |
| .05 | 接近迷你条，主题底占主要观感，不闪白、不碎片；检查外沿是否含slack |
| 0 | 保持手指时检查小端与真条边界/色差；松手后原交棒路径恢复HDS。不能仅凭日志判像素相等 |

落地：观察整条（材质与内容）110ms压到.86、320ms过冲回1，确认不透底。还需回归点击打开、全屏下拉关闭、系统返回、二级页、浅/深色和40/56高两档。

日志grep：`RzdMorphSolid|RzdSquash|RzdHomeMiniBarMaterial|RzdMiniBarCapsule|miniOut`。RzdMorphSolid输出contentP/stage/solid/scale/clipH/radius/tx/ty/sourceHidden/miniOut/squash；非端点80ms节流。animateTo状态直接写终点，因此日志不是渲染逐帧像素或回弹实际插值的证明。

## 验证

default assembleHap：BUILD SUCCESSFUL in 50 s 529 ms，exit 0，见 morph-solid-build.log（包含现有ArkTS警告，无ERROR）。git diff --check 已通过。hdc list targets=[Empty]，只可报告源码/编译/产物级，不可声称真机已修复。
