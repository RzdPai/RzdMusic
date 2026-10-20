# 搜索标题栏结构重排与验证报告

本轮交付为源码级、编译级、产物级；hdc list targets=[Empty]，没有真机视觉或交互通过结论。

## 1. 独立逆向结果

详见 upstream-search-126.md §12–14，全部行号是 wujie126.pa。

- PAGE_H=16：导出12434=index30，初始化113552–113555。
- FIELD_GAP=16：导出12420=index16，初始化113586–113587，v0来源113552–113553。
- CONTENT_TOP=0：导出12411=index7，初始化113590–113593。
- 页面总左右留白16/24/32：topPageSideOf99071–99088，阈值600/840；extra为总边距减PAGE_H，98539–98551、98738–98746。
- 对照1.2.4导出11231–11283、初始化98055–98097及断点84660–84677一致。
- 原工具文档说纯常量模块无法映射不成立：已用具名Breakpoint函数99218–99247和读取99153–99194反验LOCAL_EXPORT顺序，修正reverse-toolkit.md。
- 类型栏窄屏上游只有歌曲/歌单，587601–587794：Row(space10)、纯文字、竖线14/1；598218–598299：选中Bold主色，未选Medium次色，上下4。保留本仓五模式是业务扩展，不宣称五标签上游原样。
- 入口history/hot/suggest及宽屏左右列证据已记入upstream-search-126.md §13。本轮没有重写入口业务和宽屏两列；已取证不等于已实现。
- 未确证：HDS最终安全区像素偏移、stackBuilder的设备动画表现；没有把候选数字当上游值。历史wordChip/清空控件全部细节尚未完整取证迁移。

## 2. 改造后的结构

```text
HdsNavDestination（MINI，标题显示，原生返回隐藏，bindToScrollable，SYSTEM TOP/BOTTOM忽略）
├─ titleBar.content.stackBuilder
│  └─ searchRow Row(space10,height56,width100%,alignCenter,padding16/24/32)
│     ├─ Stack(height40,width40,SearchGlassModifier){返回SymbolGlyph}
│     ├─ Stack(layoutWeight1,height40,SearchGlassModifier){原生Search}
│     └─ Stack(height40,SearchGlassModifier){取消Text}
├─ titleBar.content.bottomBuilder(height40,DIRECTLY_SHOW)
│  └─ typeBar：水平Scroll{Row(space10){五个纯文字类型标签+竖线；音源菜单入口}}
└─ 原业务内容Stack/List/联想层
   └─ 顶部offset=max(searchRow实际底边,typeBar实际底边)-内容实际顶边
```

音源菜单移出共享Search宽度，位于类型栏末端，是保留本仓音源业务的扩展。三个胶囊与首页共同使用SearchGlassModifier：COMPONENT_THICK、SYSTEM、AVERAGE、#1AFFFFFF、圆角20。

关键标题配置：

```typescript
content: {
  stackBuilder: (): void => { this.searchRow(); },
  bottomBuilder: {
    builder: (): void => { this.typeBar(); },
    height: 40,
    showType: BottomBuilderShowType.DIRECTLY_SHOW
  }
}
```

关键Search属性（完整业务回调见OnlineSearchPage.ets SearchInputBar）：

```typescript
Search({ value: this.query, placeholder: '艺人、歌曲或专辑', controller: this.searchController })
  .id('online_search_input')
  .height(40)
  .backgroundColor(Color.Transparent)
  .placeholderColor($r('sys.color.font_secondary'))
  .placeholderFont({ size: 16 })
  .textFont({ size: 16 })
  .fontColor($r('sys.color.font_primary'))
  .caretStyle({ color: $r('sys.color.font_primary') })
  .searchIcon({ size: 16, color: $r('sys.color.font_secondary') })
  .cancelButton({ style: CancelButtonStyle.INPUT,
    icon: { size: 17, color: $r('sys.color.font_secondary') } })
  .layoutWeight(1)
  .geometryTransition('wanting_search_field', { follow: true })
  .transition(TransitionEffect.OPACITY)
  .responseRegion({ x: 0, y: -4, width: '100%', height: 40 })
  // onFocus / onBlur / onChange / onSubmit：源码保留联想、抑制程序化重搜、停止编辑。
```

中间容器直接承载Search，width100%补足Stack父容器不分配layoutWeight的情形。

## 3. 一镜到底官方条件与实现

官方文档已通过本机MCP查询脚本读取正文：

- https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-shared-element-transition （图标/搜索框展开案例）
- https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-transition-animation-geometrytransition

要求同id两端、非嵌套、最多两节点，animateTo显式动画环境和transition保留离场节点；follow支持不下树一侧跟随。搜索案例明确禁用Navigation默认动画。

首页openSearch：

```typescript
this.getUIContext().animateTo({
  curve: curves.interpolatingSpring(0, 1, 342, 38),
  onFinish: (): void => { Logger.info('RzdSearchMorph', 'end'); }
}, (): void => {
  this.pageIndexInfos.pushPath({ name: RouterUrlConstants.ONLINE_SEARCH }, false);
});
```

关闭统一先guardPlayerBack，再重复关闭保护、清焦点、同曲线animateTo{pop(false)}。取消/返回/系统返回走同一方法。两Search与两Destination均保留OPACITY transition。本仓routerMap仍负责创建同一个OnlineSearchPage，没有第二搜索页，没有改Index Stack，也没有新增导航依赖。

官方文档未承诺HDS stackBuilder特定宿主跨树的最终表现；现行结构已满足官方通用搜索案例条件，仍待设备确认。菜单入口若源Search已滚出屏幕，不能凭源码保证可见几何连续。

## 4. 首页标题按钮

首页外层改为List{ListItem{原内容Column}}，保留原滚动补位链；List无Scroll.initialOffset属性，移除该属性，恢复依赖既有onAttach/量测/可见性补位链。cachedCount2、Spring(alwaysEnabled)、clip(false)。

```typescript
const shown: boolean = this.pageScroller.currentOffset().yOffset > 20;
if (this.titleSearchShown !== shown) {
  this.titleSearchShown = shown;
}
```

titleSearchShown为@Local，阈值40/2=20vp；SM静止无菜单，超过阈值显示搜索/识曲，非SM保留菜单。两个SymbolGlyphModifier为22fp、sys.color.font_primary，分别openSearch与MUSIC_RECOGNITION。
searchOpen为@Local，openSearch置true，onShown置false；@Monitor('searchOpen')在两次变化中复位titleSearchShown=false。没有恢复HomeTopBar旧常驻按钮。

## 5. 实跑结果

- 最终build-and-publish.ps1：exit0，BUILD SUCCESSFUL；已上传正式default包并同步源码。
- 首次脚本编译成功但上传因进程缺WebDAV环境变量失败；从本机已有配置只在进程注入凭据后重跑成功，凭据未写入仓库。
- 最终HAP：products/default/build/default/outputs/default/musichomesample-default-signed.hap。
- 字节数23,899,966；本机时间2026-10-20 20:07:30，UTC12:07:30。
- modules.abc UTF8字符串命中：RzdSearchHome=1、RzdSearchMorph=6、wanting_search_field=1、SearchGlassModifier=5、RzdSearchTitleMeasure=1。字符串池去重，因此id=1不代表只有一个调用点。
- 新符号非零，无须清hvigor转换缓存。
- check-mini-bar.ps1 A/B/C/D/E/F全部PASS；git diff --check通过。
- hdc list targets为空；没有安装、触摸、键盘、颜色、动画像素验证。
- 发布尾部推送HTTP400，上传与源码同步成功，脚本exit0；通知失败不等于上传失败。

## 6. 文件与边界

改动：HomeSearchRow.ets、RecommendPage.ets、OnlineSearchPage.ets；新增SearchGlassModifier.ets及musicbasic/Index.ets导出；reverse-toolkit.md、upstream-search-126.md和本报告；构建脚本更新base/en_US的build_stamp。
新增依赖/权限：无，oh-package.json5及权限清单无变更。
未改播放页、播放形变、迷你条代码、Index.ets、products/pc；所有记忆文档未修改。

真机grep：RzdSearchHome（入口）、RzdSearchMorph（source/target rect、start/end、close start/end、focus/blur）、RzdSearchTitleMeasure（量测让位）；滚动阈值的实际显示需观察菜单，复位日志为RzdSearchMorph的home search visibility reset。
