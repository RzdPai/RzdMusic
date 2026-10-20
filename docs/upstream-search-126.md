# 无界音乐 1.2.6（`无界音乐_1.2.6.app`）· 搜索框位置与结构 反编译证据

> 来源：WebDAV `https://pan.rzdpai.com/dav/无界音乐_1.2.6.app`（3,075,377 B，2026-10-20 13:46 上传）
> 解包：`_wujie126/entry-default.hap` → `ets/modules.abc`（3,671,568 B）
> 反汇编：`D:\command-line-tools\sdk\default\openharmony\toolchains\ark_disasm.exe` → `_wujie126/wujie126.pa`（797,728 行）
> 全部行号均为 `wujie126.pa` 行号。

## 0. 结论先说（本轮用户报的「搜索框位置不对」）

1.2.6 里**首页搜索框不是浮层**，它是**首页内容流里的第一个元素**（在 hero 之前），
用原生 **`Search` 组件**（不是 `Row + TextInput` 手搓），外面套一个玻璃胶囊，
右边并排一个同样胶囊的**识曲按钮**，整体受页面左右留白 `PAGE_H` 与字段下方间距 `FIELD_GAP` 约束。

1.2.4 时期我们按甲方口径实现过「浮层 + 上滑收缩成按钮」，**1.2.6 的字节码里没有这件事**：
`HomeTab.searchField` 的属性闭包里只有 `placeholder / attributeModifier / width('100%') /
focusable(false) / focusOnTouch(false) / defaultFocus(false) / geometryTransition / onTouch`，
**没有任何随滚动变宽/缩放的属性**（见 §2）。

## 1. 首页骨架：`HdsNavigation { List }`

`HomeTab.homeBody`（498247-498352）：

```
HdsNavigation(this.homeNav) {          // @13*#
  List({ scroller: this.scroller }) {  // @13*#^1
    ListItem() { <@13*#deepRenderFunction> }
    LazyForEach('1', this.recoRowsSrc, itemCreation, deepRender)
  }
}
```

`HdsNavigation` 属性闭包 `@13*#`（501010-501152）原文顺序：

| 属性 | 值 | 证据 |
| --- | --- | --- |
| `titleBar({...})` | `avoidLayoutSafeArea:true, enableComponentSafeArea:true` | 501010-501030 |
| `content.title.mainTitle` | `'首页'` | 501022-501024 |
| `content.menu` | `this.titleSearchMenu()` | 501026-501029 |
| `content.stackBuilder` | **`wideHead() ? this.titleHeadBar() : undefined`** | 501031-501041 |
| `style` | `immersiveTitleBarStyle(this.uiDark())` | 501043-501052 |
| `titleMode` | `HdsNavigationTitleMode.MINI` | 501053-501068 |
| `hideBackButton(true)` / `bindToScrollable([this.scroller])` / `mode(NavigationMode.Stack)` / `ignoreLayoutSafeArea([SYSTEM],[TOP,BOTTOM])` / `backgroundColor(this.pal().bg)` | | 501069-501152 |

**所有屏幕形态共用的标题栏 = 只有「首页」一个标题**；搜索/识曲按钮（`titleSearchMenu()`）
在 `!wideHead()` 时直接 `return undefined`（`titleSearchMenu` 502067-502078：
`if (!wideHead()) return undefined;`）。

## 2. 搜索框本体：原生 `Search` 组件

`HomeTab.searchField()`（499340-499361）= `observeComponentCreation2(@10*#, "Search")`。
属性闭包 `@10*#`（500476-500567）原文顺序：

```ets
Search.create({ placeholder: SEARCH_PLACEHOLDER })     // '艺人、歌曲或专辑'，见 §5
  .attributeModifier(searchFieldStyleOnGlassOf(this.uiDark()))
  .width('100%')
  .focusable(false)          // ★ 首页这个是"假"输入框，不聚焦
  .focusOnTouch(false)       // ★
  .defaultFocus(false)       // ★
  .geometryTransition(SEARCH_GEO_ID, { follow: true })
  .onTouch(...)              // → openSearch()（点击去真搜索页）
```

`recognizeButton()`（499171-499206）属性闭包 `@11*#`（500587-500630）：
`Stack().width(RECOGNIZE_BTN_W).height(SEARCH_FIELD_H).onClick(onOpenRecognize)`
内容 `@11*#^1` = `SymbolGlyph($r('sys.symbol.…')).fontSize(RECOGNIZE_ICON_SIZE).fontColor([pal.label])`。

## 3. 搜索框的宿主链（手机竖屏）

`@13*#deepRenderFunction`（501315-501420）里 `ListItem` 的子节点顺序：

1. `If`（`@13*@a*#^1`） → 搜索行（见下）
2. `this.hero()`                    ← 英雄区在搜索行**下面**
3. `this.feedShelf()`
4. `If` forYou（`^2`） / `If` boardSources（`^3`） / `If` recoSonglists（`^4`）

外层 `Column`（`@13*@a*#`，501884-501952）：`width('100%')`、`justifyContent(Start)`、
**`padding({ top: CONTENT_TOP })`**。

`If` 条件（`@13*@a*#^1`，501929-501988）= **`!compact() && !wideHead()`**：

- `wideHead()` = `widthBpOf(winWvp) >= BP_W_MD`（500343-500360）
- `compact()` = `isCompactDock(winWvp, winH)`（497792-497830）
- ⇒ 宽屏时搜索框搬进**标题栏** `titleHeadBar()`；手机竖屏时在**内容流**里；`compact` 且非宽屏则内容里没有。

手机分支内容 `@13*@a*^1*#`（502124-502199）：

```ets
Column() {                                  // @13*@a*^1**#  width('100%')
  Row({ space: RECOGNIZE_GAP }) {           // @13*@a*^1**#^1  width('100%')
    //   alignItems(VerticalAlign.Center)
    //   margin({ bottom: FIELD_GAP })
    __Common__().layoutWeight(1) {          // @13*@a*^1**#^2
      MaterialGlass({ fixedH: SEARCH_FIELD_H }) {   // @13*@a*^1**#^3
        this.searchField()
      }
    }
    MaterialGlass({ fixedH: SEARCH_FIELD_H }) {     // @13*@a*^1**#^4
      this.recognizeButton()
    }
  }
}
.padding({ left: PAGE_H, right: PAGE_H })       // @13*@a*^1**#  ← 左右留白
```

宽屏分支 `titleHeadBar()`（500007-500219）：

```ets
Row() {                                     // @12*#  width('100%') height('100%')
  //   justifyContent(FlexAlign.End)  alignItems(VerticalAlign.Center)
  //   padding({ right: PAGE_H + pageSideExtraOf(winWvp, PAGE_H) })
  __Common__().width(this.winWvp() / 3) {   // @12*#^1  ← 宽屏搜索框占标题栏 1/3
    MaterialGlass({ fixedH: SEARCH_FIELD_H }) { this.searchField() }      // @12*#^2
  }
  MaterialGlass({ fixedH: SEARCH_FIELD_H }) { this.recognizeButton() }    // @12*#^3
}
```

## 4. 搜索框视觉规格（`design/src/main/ets/theme/SearchField.ets`）

`searchFieldStyleOnGlassOf(uiDark, onGlass?, themed?)` 选 6 个 `SearchFieldStyle` 常量之一
（113243-113288），`SearchFieldStyle.applyNormalAttribute`（113319-113449）原文顺序：

```ets
.height(SEARCH_FIELD_H)
.backgroundColor(onGlass ? Color.Transparent : pal.fill_tertiary)   // 玻璃里透明
.placeholderColor(pal.label_2)
.placeholderFont({ size: $r('app.float.…') })   // 资源 50331744
.textFont({ size: $r('app.float.…') })          // 同资源
.fontColor(pal.label)
.caretStyle({ color: themed ? pal.label : $r('app.color.…') })
.searchIcon({ size: 16, color: pal.label_2 })
.cancelButton({ style: CancelButtonStyle.INPUT, icon: { size: 17, color: pal.label_2 } })
```

模块常量（`func_main_0`，113450-113546）：
`SEARCH_GEO_ID = 'wanting_search_field'`、`SEARCH_PLACEHOLDER = '艺人、歌曲或专辑'`。

## 5. 一镜到底

两处 `geometryTransition`，id 同源：

- 首页假框：`HomeTab@10*#` 500549-500553
- 搜索页真框：`SearchPageNew@b*#` 597636-597640

`SearchPageNew.searchBar()`（586014）= `Row { MaterialGlass{…} }`，
`SearchPageNew.searchField()`（597341）= 原生 `Search`，同样带 `geometryTransition(SEARCH_GEO_ID, {follow:true})`。

## 6. 点击与关闭

- `HomeTab.openSearch()`（498636-498689）= `animateMorph(uiContext, SP_SEARCH, SP_SEARCH_SETTLE_MS, () => …)`；
  颜色模式还在收敛时打 `hilog` `"openSearch hard-cut (color mode still settling)"`。
- `HomeTab.closeSearch()`（497734）同理；`onSearchOpenFlip()`（498612-498621）：
  `if (searchOpen()) titleSearchShown = false;`
- `openSearchDirect()`（498694+）= `MorphGuard…` 直通分支。

## 7. 历史待核记录（已由 §12 纠正，不再作为当前数值结论）

> 本节原先写的是「纯 `export const` 模块取不到值」——**这个结论是错的**，正确做法见 §12 与
> `docs/reverse-toolkit.md` §3：`stmodulevar` 槽位 = 模块 record 里 `LOCAL_EXPORT` 的排列顺序，
> 因此 Tokens 的每个常量都能解出来（`PAGE_H=16`、`FIELD_GAP=16`、`CONTENT_TOP=0`、`SEARCH_FIELD_H=40`…）。
> 下面这段只作错误留档，别再引用：

| Token | 用途 | 候选（来自 Tokens `stmodulevar` 数值集合） |
| --- | --- | --- |
| `SEARCH_FIELD_H` | 首页搜索框/玻璃胶囊高度 | **40**（§8 已核：搜索页玻璃胶囊 = 40，两侧框同源） |
| `PAGE_H` | 页面左右留白 | 16（`Tokens` 里 16 出现两次；本仓 `BreakpointType(16,24,32,32)` 同源） |
| `FIELD_GAP` | 搜索行下边距 | 12 / 14（**未取证**） |
| `RECOGNIZE_GAP` | 首页搜索框与识曲胶囊间距 | **10**（§11 已核，HomeTab 局部常量） |
| `RECOGNIZE_BTN_W`（首页识曲胶囊宽） | **= `SEARCH_FIELD_H`**（方形胶囊） | 同 slot 13 = `ldexternalmodulevar …SEARCH_FIELD_H`（508101-508105） |
| `RECOGNIZE_ICON_SIZE` | **24** | 同 slot 14 |
| `CONTENT_TOP` | 内容顶部内边距 | **未取证**（候选 148） |

取数方法见 `docs/reverse-toolkit.md` §3（`func_main_0` 的 `ldai → stlexvar` + 方法体
`ldlexvar + throw.undefinedifholewithname` 两次扫描）。`Tokens` 这类**纯 export const 模块取不到值**。

补充（`HomeTab.func_main_0` 508095-508214 原样读出）：

```ets
const SHOW_HERO_CARD = false;
const RECOGNIZE_GAP = 10;
const RECOGNIZE_BTN_W = SEARCH_FIELD_H;      // ← 方形胶囊，别再当 10 用
const RECOGNIZE_ICON_SIZE = 24;
const HERO_COVER = 90;
const HERO_PAD = 10;
const HERO_CARD_H = HERO_PAD * 2 + HERO_COVER;   // = 110
const HERO_BTN_SIZE = 40, HERO_BTN_BOX = 46, HERO_BTN_MR = 6;
const SEARCH_PAGE_TRANSITION = TransitionEffect.asymmetric(
  TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Friction }),
  TransitionEffect.OPACITY.animation({ duration: 120, curve: Curve.Sharp }));
const HOME_BRANCH_TRANSITION = TransitionEffect.asymmetric(
  TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Friction }),
  TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -56 }))
    .animation({ duration: 120, curve: Curve.Sharp }));
```

⚠️ 这个 slot 的教训：我的第一个解码脚本不认 `ldexternalmodulevar`，把
`RECOGNIZE_BTN_W = SEARCH_FIELD_H` 误读成 `10`。**任何“取到的值”都要回头看一遍原始几行字节码**。


## 8. 搜索页本体（`SearchPageNew`）的结构 —— 上一版我们做错的地方

`SearchPageNew.initialRender`（579425 区段的 extract 行 5349-5385；原 `.pa` 584733）：

```
HdsNavigation(this.nav) {              // @2a*#
  If (this.wide()) { 两列 columnList }  // @2a*^1*#   （宽屏）
  Else            { 单列 … }           // @2a*^1*#^1
}
```

`HdsNavigation` 属性闭包 `@2a*#`（extract 17090-17233）原文顺序：

```ets
.titleBar({
  avoidLayoutSafeArea: true,
  enableComponentSafeArea: true,
  content: {
    stackBuilder: () => this.searchBar(),                  // ★ 搜索框整行在标题栏里
    bottomBuilder: {
      builder: () => this.typeBar(),                        // ★ 综合/单曲/… 类型栏在标题栏底栏
      height: this.wide() ? undefined : TYPE_BAR_H,          // TYPE_BAR_H = 40（已核）
      showType: BottomBuilderShowType.DIRECTLY_SHOW
    }
  },
  style: immersiveTitleBarStyle(this.uiDark())
})
.titleMode(HdsNavigationTitleMode.MINI)
.mode(NavigationMode.Stack)
.hideBackButton(true)
.bindToScrollable(this.wide() ? this.scrollersWide : this.scrollersNarrow)
.ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
```

`searchBar()`（586014）→ 属性闭包 `@8*#` / `@8*#^1` / `@8*#^2` / `@8*#^3` / `@8*#^4`
（extract 17613-17896）：

```ets
Row({ space: SEARCH_ROW_GAP }) {           // =10
  //  width('100%')  height(SEARCH_BAR_H) =56  alignItems(VerticalAlign.Center)
  //  padding({ left: PAGE_H + pageSideExtraOf(winWVp, PAGE_H),
  //            right: PAGE_H + pageSideExtraOf(winWVp, PAGE_H) })
  MaterialGlass({ fixedH: SEARCH_GLASS_H }) { this.backButton() }        // =40   ← 返回玻璃胶囊
  __Common__().layoutWeight(1) {
    MaterialGlass({ fixedH: SEARCH_GLASS_H }) { this.searchField() }     // 搜索框玻璃胶囊
  }
  MaterialGlass({ fixedH: SEARCH_GLASS_H }) { this.sourcePill() }        // 音源胶囊（纠正旧版取消误读）
}
```

`searchField()`（586119）→ 属性闭包 `@b*#`（extract 18189-18305）原文顺序：

```ets
Search({ value: this.keyword(), placeholder: SEARCH_PLACEHOLDER, controller: this.searchCtl })
  .id('searchField')
  .attributeModifier(searchFieldStyleOnGlassOf(this.uiDark()))   // §4 那套样式
  .layoutWeight(1)
  .geometryTransition(SEARCH_GEO_ID, { follow: true })           // ★ 一镜到底这一端
  .responseRegion({ x: 0, y: -4, width: '100%', height: HIT })    // 扩大点击区
  .onFocus(...)  .onBlur(...)  .onChange(...)  .onSubmit(...)
```

⇒ **上一轮的错**：把首页那侧挂在"内容流里的自绘 header + 我们自己的搜索页（内容里的自绘搜索条）"上，
搜索页那侧根本没有"标题栏 stackBuilder 里的原生 Search"这个结构，两端几何/宿主都对不上，
`geometryTransition` 自然没有效果。

## 9. 首页"上滑后标题栏出现搜索按钮" —— 机制已找到

1. 首页 `List` 挂了 `onDidScroll`（501261-501268），回调 `@13*^1*#^1`（503127-503152）：

   ```ets
   const y = this.scroller.currentOffset().yOffset;
   const shown = y > SEARCH_FIELD_H / 2;          // ★ 阈值 = 搜索框高度的一半（40/2 = 20vp）
   if (this.titleSearchShown !== shown) {
     this.titleSearchShown = shown;
   }
   ```
2. 标题栏 `menu` = `this.titleSearchMenu()`（501026-501029）。`titleSearchMenu`（500067-500219）逻辑
   （已按 §4 的取反修正复核过）：

   ```ets
   if (this.wideHead()) { /* 宽屏：恒定出菜单 */ }
   else if (!(this.compact() || this.titleSearchShown())) { return undefined; }
   // ⇒ 手机竖屏：静止时没有菜单；滚过 SEARCH_FIELD_H/2 之后才出现 [搜索, 识曲] 两个图标
   ```
   菜单内容：两个 `SymbolGlyphModifier`（`fontSize = 22`，`fontColor = pal.label`），
   符号资源 id `125831500`（放大镜）与 `125831884`（识曲），各自的 `action` 分别走
   `@1*#action`（→ `openSearch()`）与 `@1*#action^1`。
3. 从搜索页回来时复位：`onSearchOpenFlip()`（498612-498621）= `if (searchOpen()) titleSearchShown = false;`
4. 另外首页 `List` 还有：`cachedCount(2)`、`scrollBar(BarState.Off)`、
   `edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })`、`width/height('100%')`、`clip(false)`、
   `onTouch(reportFingerTouch)`（501201-501268）。

## 10. 已核实的常量表（方法见 `docs/reverse-toolkit.md` §3）

| 常量 | 值 | 出处 |
| --- | --- | --- |
| `SEARCH_BAR_H`（搜索页顶栏行高） | **56** | `SearchPageNew.func_main_0` slot 9 |
| `SEARCH_GLASS_H`（玻璃胶囊高） | **40** | 同 slot 10 |
| `SEARCH_ROW_GAP`（三块之间的间距） | **10** | 同 slot 8 |
| `TYPE_BAR_H`（类型栏高） | **40** | 同 slot 15 |
| `RECOGNIZE_GAP`（首页搜索框↔识曲） | **10** | `HomeTab.func_main_0` slot 15 |
| `RECOGNIZE_ICON_SIZE` | **24** | 同 slot 14 |
| `HERO_BTN_SIZE` / `HERO_BTN_BOX` / `HERO_BTN_MR` | 40 / 46 / 6 | 同 slot 8/9/10 |
| `SHOW_HERO_CARD` | false | 同 slot 2 |
| 首页 `List` 的 `SEARCH_PAGE_TRANSITION` / `HOME_BRANCH_TRANSITION` | 对象（过渡参数） | 同 slot 11/12 |

## 11. 待办（下一步要照搬的）

1. 搜索页整页结构按 §8 重排（标题栏 stackBuilder = 搜索行；底栏 = 类型栏）。
2. 首页 §9 的"滚动阈值 → 标题栏搜索/识曲图标"。
3. 本轮已补齐常量，见 §12；入口 body 与宽屏列结构见 §13。

## 12. 本轮重新取证：Tokens 可映射，常量已定

此前“LOCAL_EXPORT 按字母排序所以与槽位无关”的推断错误。本样本 Tokens 的 LOCAL_EXPORT
零基顺序对应 stmodulevar；先用 Breakpoint 具名函数和具名读取反验：
10878–10912 导出记录中 pageSideExtraOf 为 index28；99218–99219 明确 definefunc(pageSideExtraOf)
写 stmodulevar 0x1c。99153–99194 的 BP_W_XS/SM/MD/LG/XL 具名读取也与导出序号匹配。

| 常量 | 已取值 | 1.2.6 原始证据 |
| --- | --- | --- |
| PAGE_H | 16vp | LOCAL_EXPORT 12434=index30；113552–113555 写 0x1e=16 |
| FIELD_GAP | 16vp | 12420=index16；113586–113587 写 0x10，v0 来自113552–113553=16 |
| CONTENT_TOP | 0vp | 12411=index7；113590–113593 写 0x7=0 |
| COL_NARROW / LEFT / RIGHT | 0 / 1 / 2 | 初始化598440–598461，名称读取596705–596724、596746–596750 |

旧版独立核验：LOCAL_EXPORT11231–11283，初始化98055–98097，以上 Tokens 值相同。
pageSideExtraOf(w,base)=max(topPageSideOf(w)-base,0)，98539–98551、98738–98746；
topPageSideOf 在99071–99088：w<600→16、600≤w<840→24、w≥840→32。
所以 PAGE_H 固定16，附加边距0/8/16，最后总边距16/24/32；不是 PAGE_H 自己随断点变化。
旧版84327–84335、84660–84677一致。首页 List额外边距501165–501200；
搜索行再加PAGE_H502213–502230、下边距FIELD_GAP502268–502280；内容top501910–501922。

## 13. 本轮重新取证：类型栏与三个入口 body、宽屏列

类型栏真实窄屏结构587601–587659为 Row(space10){typeLabel('歌曲');Divider;typeLabel('歌单')}。
587673–587747为Row宽100%、居中、页面侧边距；587753–587794分隔线vertical、高14、宽1。
598218–598299为选中Bold/未选Medium、主/次文字色、上下padding4，无胶囊背景。
**本仓保留综合/单曲/歌单/歌手/专辑五业务模式，使用同一文字分隔结构，五模式不是上游原样。**

窄屏narrowItems入口分支592499–592535：keywordText为空→historyView，否则suggestView。
historyView584510–584538为Column{historyBody;hotBody}；实际挂载592592–592612、592677–592697。
历史header为Row{最近搜索;可选清空}，587969–588145，左右PAGE_H/底4；
无历史文案588360–588426='没有最近搜索'，左右PAGE_H/上10/下14；
非空FlexWrap.Wrap+ForEach(key=q)+wordChip，588432–588536。
热搜仅hotWords非空显示，588561–588652；标题'热门搜索'588658–588733，左右PAGE_H/上18/下10；
FlexWrap.Wrap+ForEach(key=word)+wordChip为588739–588837。
建议为Column+ForEach(key=word)，588897–588961；每项Column{Row{SymbolGlyph;Text};可选Divider}
588967–589039。Row间隔12、最小高ROW_H=56、左右PAGE_H/上下8，589105–589162；点击searchFor(w)589321–589331。

宽屏Row{columnList(COL_LEFT);columnList(COL_RIGHT)}596684–596729；窄屏columnList(COL_NARROW)596735–596751。
columnList580692–580747根List；右列scrollerR，其余scroller596013–596036；
lanes(musicLanes(),0)、关闭滚动条、Spring(alwaysEnabled)、宽高100%、左右extra边距、
layoutWeight(窄0/宽1)、cachedCount(3,true)、clip(false)，596037–596162。
左列入口593023–593059：空关键词historyPaneView（仅historyBody，584482–584504），否则suggestView；
右列入口hotView=hotBody，593437–593457、593552–593572。
本轮仅记录入口body和两列证据，尚未迁移这些既有业务结构；不得把取证完成写成实现完成。

## 14. 官方一镜到底条件

官方原文通过tools/mcp-query.ps1读取：
https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-shared-element-transition
的“图标（搜索框、头像等）展开一镜到底”直接给出 Search 两端同id，
UIContext.animateTo({curve:curves.interpolatingSpring(0,1,342,38)},()=>pushPath({name},false))，
禁用Navigation默认动画。返回同理pop(false)。因此不需要绕开本仓routerMap另建搜索页。
https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-transition-animation-geometrytransition
明确必须animateTo，不能以animation代替；transition保证离场节点不立即析构；
同id最多两个非嵌套节点，follow用于不下树节点跟随。文档未声明stackBuilder是禁区，也未给
HDS标题栏跨宿主的真机保证；本轮保留同一个壳Navigation/UIContext并增加矩形日志，设备行为待验。

