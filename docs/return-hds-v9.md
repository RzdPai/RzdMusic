# 第九次会诊：未松手回拖提前交还来源 HDS 条

基线 HEAD=17f6d5a，开工工作区干净。用户要求是不透明，且未松手时已是正常条。本轮为源码/编译候选，设备像素未验证。

## 反编译证据与推测结论

`docs/upstream-collapse-full.md` 中：
- reverseDragEnd:1358-1403：先判手势仍存活，再 setMorph(LEAVING, ANIM)；1404-1498 根据 reverseBaseT-morphT 和速度选择 animateMorphT 到 0 或 1。这是松手收尾，不是回拖更新。
- setMorph:1011-1092：写 stage/drive、morphLive、playerPaintsOf 的反值、grabber；非 LANDING 才 stopLandAnim 和 squash=1。没有 setMiniOut(false)。
- morphGlassOpacity:44-74：clamp(1-morphT/MORPH_GLASS_IN_T)。真实 HDS 克隆只在很小的 p 窗口可见，不能推定来源真条已恢复。

补读绝对路径 `C:\Users\Administrator\Desktop\RzdProject\_recover\disasm\wujie.pa`：
- pullUpdate:150886-150947：ENTERING 下计算 clamp(-vp2px(dy)/pullRangePx)，写 morphT，调用 syncMiniOut，无方向翻转判断。
- syncMiniOut:154627-154644：p>=MINI_OUT_T 时 setMiniOut(true)；154646-154668：miniOut 且 p<=MINI_IN_T 时 setMiniOut(false)。常量154184-154187：OUT=.002，IN=0。因此回拖仍按进度，回到0才恢复，不是反向即恢复。
- finishReverse:147527-147568：收尾 setMorph(NONE/OPEN,NONE)，退出支 popMorphPage，再 setMiniOut(false)。

结论：上游没有材料所假设的“反向那一刻提前恢复真条”。近端看起来像来源条，还涉及真 HDS 的 morphGlass；不能把该克隆等同来源条。仅恢复下层真条也不足：背景公式 .04+.96*clamp(p/.30) 在 p=.50/.20/.05 分别为1/.68/.20，且 #8 的实心层独立承托，均可能遮挡下层 HDS。

## 本仓实现与明确代价

唯一锚点/日志 tag：`RzdReturnHdsV9`。

PlayerExpandState 增加 @Trace returnHdsVisible（仅绘制所有权）。applyMorphProgress 在写p前比较相邻真实 FINGER+pullDragging 样本：进度下降交还真条，进度上升交回播放器；相等保持。独立普通字段记录指针样本，避免起手p=1→0或量测重算被当反向。松手后下降继续保持来源条，commit/reopen上升交回播放器；新会话/reset清理。

sourceBarPaintHidden 为首页/二级宿主、真实内容和元信息统一绘制门。原 sourceBarHidden/miniOut/hdsBarSuppressed 不提前改写。返回时取消封面/meta/actions的形变透明度，克隆停画，PlaybackPage的原表面opacity=0；节点与手势根仍常驻，未增加播放器裁剪。原松手判据和几何继续运行，没有强制 morphSettleOpen，没有新增 morphSquashY 写入。

MiniBarMaterialCapsule 在真 HdsTabs 下增加一层圆角实色承托，复用 #8 的 base/dark morph_mini_solid_surface（FF）。光感只由原 HdsTabs.systemMaterialEffect 输出，没有自绘渐变。实色承托在同一squash父层中。它同时用于正常态和回拖态，避免两者底色差异。

代价：回拖第一帧就切回来源条，播放器大表面会提前消失，不再展示该回程的连续收缩；再向上拖会重新出现当前进度的播放器。这是满足三个停点“已经最终形态”的本仓取舍，不声称上游相同。实色底可能改变HDS背景采样观感，光照强度和私有轮廓仍需真机验收。官方 opacity 文档只确证0完全透明、占布局以及子层透明度相乘，没有据此宣称任何未验证的手势分发行为。

官方参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-opacity （通过官方MCP getDocumentsById读取）。

## 变更文件

- common/musicbasic/src/main/ets/model/PlayerExpandState.ets
- products/default/src/main/ets/pages/Index.ets
- features/player/src/main/ets/view/PlaybackPage.ets
- features/playlist/src/main/ets/view/MiniBarMaterialCapsule.ets
- features/playlist/src/main/ets/view/HomeMiniBarPlayer.ets
- features/playlist/src/main/ets/view/HomeMiniBarPlayerAside.ets
- features/playlist/src/main/ets/view/HomeMiniBarAlbumCover.ets

无新增依赖、无新增权限；oh-package.json5 与各 module.json5 未改。

## 上机判据

先上拖到 p>.50，再向下回拖，手指始终不松，各停住约1秒：

| p | 预期源码状态 | 视觉验收（必须设备确认） |
|---|---|---|
| .50 | owner=source-hds, finger=true, playerPaint=0, clonePaint=0, sourcePaintHidden=false | 完整正常来源条：实心、真HDS光感、原尺寸原位置；无播放器大盘与页签重叠 |
| .20 | 同上，p持续下降 | 同上；按钮/封面/歌名完整出现，不按旧形变窗口消失 |
| .05 | 同上 | 同上；不等松手恢复材质，不露首页字/列表穿透条体 |

停住时不要求刷日志，查看到达停点前最后一条。grep `RzdReturnHdsV9|RzdBarHandoff|RzdSquash|RzdMiniBarRect|RzdHomeMiniBarMaterial`。tag日志是配置/所有权证据，不是实际光感像素或动画插值证明。反向后重上拖、松手commit、取消回0、点击展开、全屏下拉、系统返回、二级页、单双行40/56与深浅色都要回归。回0后原110ms压缩+320ms回弹仍需设备检查。

## 验证

构建日志：docs/return-hds-v9-build.log。hdc list targets=[Empty]；不得声称真机已修复。最终 default assembleHap：BUILD SUCCESSFUL in 1 min 462 ms，exit 0（日志2131行），存在工程ArkTS警告；git diff --check通过。增量差异没有新增V1装饰器、router、morphSettleOpen调用或morphSquashY赋值。签名产物：products/default/build/default/outputs/default/musichomesample-default-signed.hap。
