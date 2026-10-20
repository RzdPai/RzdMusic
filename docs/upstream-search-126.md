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

## 7. 尚未定死（诚实标注）

`design` 的 `Tokens` 模块是**纯常量模块**（`func_main_0` 113551-113763 只做 `stmodulevar`，
模块内没有函数读它们），ark_disasm 输出里**没有 module var 槽位 → 名字的映射表**，
所以下列 vp 数值**没有从字节码取到确切值**，只能给候选集合：

| Token | 用途 | 候选（来自 Tokens `stmodulevar` 数值集合） |
| --- | --- | --- |
| `SEARCH_FIELD_H` | 搜索框/玻璃胶囊高度 | 40 / 44 |
| `PAGE_H` | 页面左右留白 | 16（断点更大时另有值；本仓 `BreakpointType(16,24,32,32)` 同源） |
| `FIELD_GAP` | 搜索行下边距 | 12 / 14 |
| `RECOGNIZE_GAP` | 搜索框与识曲按钮间距 | 8 / 12 |
| `RECOGNIZE_BTN_W` | 识曲胶囊宽度 | 与高同（方形胶囊）或在 40~56 之间 |
| `CONTENT_TOP` | 内容顶部内边距 | 148（候选集合里唯一的大值） |

实现时按本仓既有断点常量取值，并把它们收敛成**单个命名常量**，后续取值确定时只改一处。
