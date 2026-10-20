# 无界（wujie）App 反编译取证工具链 · 操作手册

> 目的：任何人（人或模型）都能在**不靠猜**的前提下，从 `无界音乐_x.y.z.app` 里把 ArkUI 的
> 组件树、属性调用顺序、常量数值取出来。本仓 `docs/upstream-*.md` 的结论都是这么来的。
> 这份手册只讲**怎么做**，不代替结论；结论各自记录在对应 `upstream-*.md` 里。

## 0. 本机现成产物（优先复用，别重复解包）

| 东西 | 路径 |
| --- | --- |
| 1.2.6 原始包 | `C:\Users\Administrator\Desktop\_wujie126\wujie126.app`（3,075,377 B） |
| 解出的 hap | 同目录 `entry-default.hap` |
| 解出的 hap 内容 | 同目录 `hap\`（`ets\modules.abc` 3,671,568 B） |
| **1.2.6 反汇编文本** | 同目录 **`wujie126.pa`（797,728 行 / 18.9 MB）** |
| 1.2.4 反汇编（对照用） | `C:\Users\Administrator\Desktop\RzdProject\_recover\disasm\wujie.pa`（16 MB） |
| 反汇编器 | `D:\command-line-tools\sdk\default\openharmony\toolchains\ark_disasm.exe` |

想重新生成（或换了新包）：

```powershell
$env:RZD_DAV_USER='<user>'; $env:RZD_DAV_PASS='<pass>'      # 见 tools\build-and-publish.ps1 里的同名变量
# 1) 拉包（WebDAV 根目录的文件名是中文，要 URL 编码）
curl.exe -sS -u "$env:RZD_DAV_USER`:$env:RZD_DAV_PASS" -o .\wujie.app `
  'https://pan.rzdpai.com/dav/%E6%97%A0%E7%95%8C%E9%9F%B3%E4%B9%90_1.2.6.app'
# 2) .app 是 zip，里面是 hap；hap 也是 zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z=[IO.Compression.ZipFile]::OpenRead("$PWD\wujie.app"); $z.Entries | Select FullName,Length; $z.Dispose()
#    解 entry-default.hap（用 ExtractToFile 循环，ExtractToDirectory 的 3 参重载在 PS5.1 会类型不匹配）
# 3) 反汇编
& 'D:\command-line-tools\sdk\default\openharmony\toolchains\ark_disasm.exe' .\hap\ets\modules.abc .\wujie.pa
```

## 1. `.pa` 的文本结构

```
# source binary: modules.abc
# ====================
# LITERALS
0 0xf4cfa { 10 [ string:"systemMaterialEffect", ... ]}      ← 常量池（createobjectwithbuffer 用）
...
.function any &entry.src.main.ets.views.HomeTab&.#~@0>#titleHeadBar(any a0, ...) <static> {   ← 一个方法
    ...字节码...
}
.function any &entry.src.main.ets.views.HomeTab&.#~@0>@12*#(any a0, ...) <static> {          ← 属性闭包
    tryldglobalbyname 0x0, "Row"      ← 组件类型
    ...
}
```

- `&<module_request>&.<class>#<method>`：模块 / 类（结构体）/ 方法名。
- `&<module>&.#~@0>@<N>*#`：**属性闭包**。ArkUI 的声明式写法会被拆成
  「创建组件的方法」+「按顺序设置属性的闭包」，闭包里的 `ldobjbyname "xxx"` 就是属性名。
  `^1`、`^2`… 是同一个方法里的第 2、3… 个分支/子闭包。
- 模块记录包含 `ModuleTag: REGULAR_IMPORT / LOCAL_EXPORT / INDIRECT_EXPORT`。
  **纠正（本轮经两版和具名函数交叉验证）**：本样本 Tokens、Breakpoint 模块的 LOCAL_EXPORT 顺序
  可从 0 开始对应 `stmodulevar` 槽位；不能因为名字按字母排列就认定与槽位无关。
  必须先用同模块具名 definefunc→stmodulevar 或具名 ldlocalmodulevar 反验，混合别名导出不可盲推。
  证据：1.2.6 10878–10912、99153–99194、99218–99247；Tokens 12404–12456。

## 2. 怎么定位

```powershell
$pa='C:\Users\Administrator\Desktop\_wujie126\wujie126.pa'
$lines=[IO.File]::ReadAllLines($pa,[Text.Encoding]::UTF8)
# 2.1 某个组件有哪些方法
for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match '^\.function .*<ViewName>&\.#~@0>#([A-Za-z0-9_]+)\('){ $Matches[1] } }
# 2.2 搜属性/API 名（geometryTransition / bindToScrollable / onDidScroll / titleBar / stackBuilder / bottomBuilder / MaterialGlass）
#     搜到行号后，往上找最近的 ^\.function 就知道这是谁在调用。
# 2.3 搜中文字符串（'艺人、歌曲或专辑'、'已经到底了~'）最快定位到具体视图。
```

**读组件树的办法**：属性闭包里 `X.create → … → X.pop` 之间是该组件的子节点；
`__Common__` 是「没有真实节点、只挂属性」的容器，常给 `@BuilderParam` 提供宿主；
自定义组件的调用长这样：`ViewPU.create` + `paramsGenerator_` + `definefunc …#content`（内容构建器）。

## 3. ★ 取常量数值（两次都被这条救过）

ArkUI 页面文件里的 `const XXX = 40` 的编译结果是：

```pa
# 文件级初始化（函数名以 .func_main_0 结尾）
.function any &entry.src.main.ets.views.SearchPageNew&.func_main_0(...) {
	newlexenv 0x13            ← 常量个数
	ldai 0x38                 ← 56
	stlexvar 0x0, 0x9         ← slot 9
	ldai 0x28                 ← 40
	stlexvar 0x0, 0xa
	...
# 方法体内读它：
	ldlexvar 0x1, 0x9         ← (level, slot)
	throw.undefinedifholewithname "SEARCH_BAR_H"     ← ★ 名字在这里
```

⇒ **两步走**：
1. 扫方法体：`ldlexvar <lvl>, <slot>` 紧跟 `throw.undefinedifholewithname "NAME"` ⇒ 建立 `slot → NAME`；
2. 扫该模块的 `func_main_0`：`ldai/lda.str → stlexvar 0x0, <slot>` ⇒ 建立 `slot → 值`。

合并即得 `NAME → 值`。例（1.2.6 `SearchPageNew`，已核实）：
`SEARCH_BAR_H=56`、`SEARCH_GLASS_H=40`、`SEARCH_ROW_GAP=10`、`TYPE_BAR_H=40`、`HIT` 等。

⚠️ **`stlexvar` 的右边不一定是个数字**，也可能是另一个模块的常量：
```pa
ldexternalmodulevar 0x2c
throw.undefinedifholewithname "SEARCH_FIELD_H"
lda v1
stlexvar 0x0, 0xd             ← slot 13 = SEARCH_FIELD_H（不是我第一版脚本读出的 10）
```
写脚本时**必须认 `ldexternalmodulevar` / `lda vN` / `lda.str` / `ldtrue/ldfalse` / `lda vN; add2/mul2`
这些取值路径**，否则会把"引用"当成"上一条 `ldai` 的残留值"。我第一版就因此把
`RECOGNIZE_BTN_W`（其实是 `SEARCH_FIELD_H`）读成了 `10`。⇒ **每个取到的值都回头看一眼原始 3~5 行**。


⚠️ 两种 module 形态别混：
- **页面/结构体文件**的 `const` 走 `newlexenv + stlexvar`（能拿到值）；
- **纯导出常量模块**（如 `design/src/main/ets/theme/Tokens.ets`）的 `export const` 走 `stmodulevar`。
  **它们的槽位 = 模块 record 里 `LOCAL_EXPORT` 的零基排列顺序**（编译器按名字排序），
  所以照样能解：把「导出名按序」与「`func_main_0` 里 `ldai/lda.str → stmodulevar <slot>`」两条一对即可。
  本样本已取到 `PAGE_H=16`、`FIELD_GAP=16`、`CONTENT_TOP=0`、`SEARCH_FIELD_H=40`（1.2.6 行
  12404–12456 + 113552–113593；1.2.4 行 11231–11283 + 98055–98097 复核一致）。

⚠️ **列导出名时窗口必须精确**：Tokens 的 record 前面紧挨着上一个模块（HeroPull）的两条
`LOCAL_EXPORT`（`heroStickyTop` / `resetHeroPull`）。窗口多带这两行，整张表就**整体错位 2 格**
（我曾因此把 `SEARCH_FIELD_H` 读成 34、把 `FIELD_GAP` 读成 44）。
**错位自检锚点**：`D_PRESS/D_FAST/D_BASE/D_SHEET` 必须是 `110/180/300/420`，
`EASE_IN_STR/EASE_OUT_STR` 必须是两条 `cubic-bezier(…)` 字符串，`RANK_GOLD=#FFE9A8`、
`ROW_COVER=52` —— 对不上就是错位，别往下用。

## 4. ★ 分支条件别读反（血的教训）

`callruntime.isfalse X` 压的是 `!X`；`jnez L` 在**栈顶为真**时跳。所以

```pa
callruntime.isfalse X
jnez L
<body>
L:
```
真实语义是 **“X 为真时执行 body”**（X 为假才跳走）。写成 `if (!X) goto L` 会读成相反的结论
——`HomeTab.titleSearchMenu` 的条件我第一遍就读反了，导致"上滑出现搜索按钮"这条被漏掉一整轮。

稳妥做法：把 `istrue/isfalse` 后面紧跟的 `ldtrue/ldfalse` 也一起展开
（`istrue(X) → ldtrue/ldfalse` 这种是**再取反一次**），最后用一条**能自证**的结论反验
（例如"手机竖屏标题栏静止时没有搜索按钮、滚动后才出现"能用交互现象验证）。

## 5. 资源值反查

`$r('app.float.xxx')` 在 `.pa` 里是 `{ id: 50331744, type: 10002, … }`（10001=color，10002=float，
40000=sys.symbol）。`resources.index` + `resources/base/element/*.json` 可反查名字与数值。

## 6. 产物符号自检（改完必做）

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z=[IO.Compression.ZipFile]::OpenRead('<...>-default-signed.hap')
[IO.Compression.ZipFileExtensions]::ExtractToFile(($z.Entries|?{$_.FullName -eq 'ets/modules.abc'}), "$env:TEMP\m.abc", $true); $z.Dispose()
$t=[IO.File]::ReadAllText("$env:TEMP\m.abc",[Text.Encoding]::UTF8)
[regex]::Matches($t,'你的新日志tag').Count    # 0 = 新代码没进包（先清 build\default\cache 再编）
```

## 7. 铁律

1. **能取证就别猜**；取不到就写"未取证 + 候选集合"，不许把猜的数写成"上游原值"。
2. 同一个结论尽量有**两处独立证据**（例如两版 `.pa` 都有、或和交互现象对得上）。
3. 结论落盘到 `docs/upstream-*.md`，带**行号**；下一个人才不用重解。
