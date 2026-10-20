# 搜索页四条反馈：同页条件分支实现与验证

## 1. 标题栏安全区

`features/setting/src/main/ets/view/OnlineSearchPage.ets:1884` 改为 `avoidLayoutSafeArea: false`，删除 `enableComponentSafeArea`。
搜索行 `onAreaChange`（1525 起）输出 `RzdSearchTitleMeasure`：mode、rowTop、rowBottom、height、status、deltaTop、expectedBottom。内联根（2381 起）输出 inlineRootTop、status、spacer。

目标：`rowTop = status`、`rowBottom = status + 56`、`height = 56`；状态栏若为 38vp，目标为 38..94vp。**38..94 是目标示例，不是本轮实测值**。本机 `hdc list targets` 返回 `[Empty]`，本轮不能取得真机 onAreaChange 值，因此没有伪造让位实测结论。

内联让位为 `max(0, resolveStatusBarTopVp() - inlineRootTopVp)`，再自然排 56vp 搜索行、40vp 类型行和剩余结果内容，防止宿主已经让过安全区时重复补状态栏。

## 2. 两端原生 Search

首页 `HomeSearchRow.ets:19`：

- placeholder `艺人、歌曲或专辑`；height 40；透明背景；系统次级 placeholder 色、主级文字/光标色；placeholderFont/textFont 16fp。
- searchIcon 16；cancelButton INPUT，icon 17；width 100%。
- focusable(false)、focusOnTouch(false)、defaultFocus(false)。
- geometryTransition('wanting_search_field', { follow: true })。
- onAreaChange 来源矩形；onTouch Up 调用打开回调。

搜索页 `OnlineSearchPage.ets:1705`：

- value=this.query（初始空，路由有 query 则预填并搜索）；相同 placeholder；controller=searchController；id=online_search_input。
- height 40；透明背景；相同字体/文字/光标/图标/cancelButton 配置；layoutWeight(1)。
- 相同 geometryTransition id、follow:true；responseRegion x0/y-4/width100%/height40。
- onFocus、onBlur、onChange、onSubmit、onAreaChange，保留原有输入/联想行为。

**两端 Search 均无 transition；两个 NavDestination 也不再挂 opacity transition。** 只有分支容器有转场。

## 3. 音源胶囊

第三块玻璃为 `Stack(SearchGlassModifier) { SourceChip }`；高度40，左右padding12。
`SourceChip.ets:61` 为原生 `Row(space:6) { Circle(10vp渐变圆点); Text(14fp平台名) }`。默认聚合显示“聚合”，有持久化音源时显示该平台。

呈现描述：`[返回] [放大镜 艺人、歌曲或专辑] [橙色圆点 酷我]`。点右侧后竖排六项：

1. 橙色圆点 酷我
2. 蓝色圆点 酷狗
3. 绿色圆点 QQ
4. 红色圆点 网易
5. 粉色圆点 咪咕
6. 灰色圆点 聚合搜索

这是源码布局描述，**不是已拍摄的截图**。选中项有系统三级背景；菜单由 @Local showSources + bindMenu 控制，选择/消失关闭菜单，选择同步 searchSource、兼容索引、勾选音源、持久化并重搜。旧请求未完成时排队最新选择，串行结束后重新搜索，避免新结果被更早请求随后覆盖。日志 `RzdSearchSource` 和 `source-selected`。

品牌色落点 `SourceChip.ets:27–58`：

| 音源 | 起色 | 终色 |
|---|---|---|
| kw 酷我 | #FFB13D | #F5860A |
| kg 酷狗 | #4DA6FF | #1273E6 |
| tx QQ | #4BD97F | #12B04B |
| wy 网易 | #FF5A5A | #D81E17 |
| mg 咪咕 | #FF7BA8 | #E62E6B |
| all 聚合 | #8E97A6 | #5A6472 |

修正 `docs/upstream-search-126.md:247` 旧“取消”误读为 sourcePill。来源证据：本机 1.2.6 `.pa` 的 sourcePill 函数从587074开始；HomeTab分支常量引用在507689、508047。反汇编文件带非UTF8字节，read拒绝；直接grep现成文件取证，未重新解包。

## 4. 同页分支

`RecommendPage.ets:67`：

```typescript
const SEARCH_PAGE_TRANSITION: TransitionEffect = TransitionEffect.asymmetric(
  TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Friction }),
  TransitionEffect.OPACITY.animation({ duration: 120, curve: Curve.Sharp })
);
const HOME_BRANCH_TRANSITION: TransitionEffect = TransitionEffect.asymmetric(
  TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Friction }),
  TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -56 }))
    .animation({ duration: 120, curve: Curve.Sharp })
);
```

`RecommendPage.ets:1002`：

```typescript
build() {
  HdsNavDestination() {
    if (this.searchOpen) {
      Column() {
        OnlineSearchPage({
          inlineMode: true,
          onClosed: (): void => {
            this.closeSearch();
          }
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .transition(SEARCH_PAGE_TRANSITION)
    } else {
      this.HomeBranch()
    }
  }
  .onBackPressed((): boolean => {
    if (guardPlayerBack('RecommendPage')) {
      return true;
    }
    if (this.searchOpen) {
      this.closeSearch();
      return true;
    }
    return false;
  })
  .hideTitleBar(this.searchOpen)
  .hideBackButton(true)
  .titleBar(this.getTitleBar())
  .titleMode(HdsNavDestinationTitleMode.MINI)
  .bindToScrollable([this.pageScroller])
  .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  .backgroundColor($r('app.color.background_secondary'))
}
```

HomeBranch 是完整首页内容根，末尾 `.transition(HOME_BRANCH_TRANSITION)`。打开/关闭在 spring `interpolatingSpring(0,1,342,38)` animateTo 闭包中仅写 searchOpen=true/false，不 push 搜索路由。日志 `RzdSearchMorph branch=open/close geometry=start/finish`，来源/目标 Search 均有矩形日志。

选择动态 hideTitleBar 的原因：保留现有首页 NavDestination、安全区、滚动绑定和全部原有 Scroll.initialOffset/恢复链；搜索出现时首页标题隐藏，离开搜索后恢复。分支是条件渲染，关闭后搜索组件卸载；未向 Index Stack 添加任何常驻节点。20vp标题搜索按钮阈值保留。

搜索组件增加 @Param inlineMode=false 与 @Event onClosed。内联根是 Column；路由根仍是 HdsNavDestination。searchRow/typeBar/searchContent 三个 Builder 共用，没有复制结果 UI。内联左返回调用 onClosed，系统返回由首页 NavDestination处理。路由左返回仍 pageStack.pop()。

`features/setting/src/main/resources/base/profile/router_map.json` 中 OnlineSearchPageBuilder 路由保持；`ControlAreaComponent.ets:658` 的专辑搜索和 `EchoReviewPage.ets:764` 的评论搜索仍走 ONLINE_SEARCH 路由。未被调用的旧 HomeTopBar 中路由代码未改。

## 5. 构建、发布与产物

实际执行指定 build-and-publish：首次发现 Row 不能套用 StackAttribute 的 SearchGlassModifier，改成 Stack 后编译通过；随后进程缺DAV环境变量，按授权环境注入重跑。最终 exit0，BUILD SUCCESSFUL，WebDAV上传 23,921,114 bytes，源码散文件同步成功。最终通知接口 HTTP400，不影响成功上传。

- HAP：products/default/build/default/outputs/default/musichomesample-default-signed.hap
- 大小：23,921,114 bytes
- 本机时间戳：2026-10-20 20:41:41
- 构建戳：261020-2041
- 下载：https://pan.rzdpai.com/dav/RzdMusic-default-signed.hap
- `tools/check-mini-bar.ps1`：A～F全部PASS（30项），STATIC CHECK OK。
- git diff --check通过；products/pc、features/player、features/playlist、Index壳无diff；未修改记忆文件。
- ohpm install --all后PC锁文件自动产生一条依赖更新，已恢复，最终products/pc无diff。

解本轮HAP的 ets/modules.abc，按UTF8解码字符串计数（字符串池命中，不等于调用次数）：

| 符号/文案 | 命中 |
|---|---:|
| RzdSearchMorph | 5 |
| RzdSearchTitleMeasure | 3 |
| wanting_search_field | 1 |
| SourceChip | 6 |
| 聚合搜索 | 1 |
| 酷我 | 10 |
| 酷狗 | 34 |
| QQ | 110 |
| 网易 | 23 |
| 咪咕 | 9 |
| 艺人、歌曲或专辑 | 1 |

新增依赖仅 recommendation → setting 本地HAR（oh-package.json5 与对应 recommendation/default锁文件），无新增三方依赖、无新增权限、权限清单无变化。

改动清单：推荐模块 RecommendPage/HomeSearchRow、推荐依赖与锁、setting导出、OnlineSearchPage、新SourceChip、default锁、两语言build_stamp资源、上游证据纠错、本文报告。

## 6. 验证等级

源码级、编译级、产物级已过；**没有设备级验证**。必须真机确认：两种模式搜索行窗口坐标与状态栏下沿一致；placeholder形变；首页淡出/搜索淡入无路由滑动；搜索关闭/系统返回；音源菜单颜色和切源重搜；20vp标题菜单；触摸、滚动恢复。不能据编译和ABC命中宣称这四条视觉反馈已经真机修复。
