# 无界 1.2.4 · 搜索框/搜索页 反编译参考（一镜到底 + 上滑收起成按钮）

> 来源 `_recover/disasm/wujie.pa`。**只参考效果与数值口径**；本仓结构不同，写实现前先读本仓现状。
> 甲方口径：「进入搜索页一镜到底；首页上滑时自动从搜索框变成搜索按钮；还有在搜索页时的样式」。

## MainPage.searchMiniFloating  (wujie.pa:152272)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#searchMiniFloating(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@21*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Stack"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x7, "observeComponentCreation2"
	sta v1
	definefunc 0x9, &entry.src.main.ets.pages.MainPage&.#~@1>@21*#^1:(any,any,any,any,any), 0x2
	sta v2
	createobjectwithbuffer 0xa, { 2 [ string:"name", string:"MaterialCapsule", ]}
	sta v3
	lda v1
	callthis2 0xb, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0xd, "observeComponentCreation2"
	sta v1
	definefunc 0xf, &entry.src.main.ets.pages.MainPage&.#~@1>@21*#^2:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x10, "Column"
	sta v3
	lda v1
	callthis2 0x11, v0, v2, v3
	ldlexvar 0x0, 0x0
	ldobjbyname 0x13, "miniBar"
	sta v0
	ldobjbyname 0x15, "bind"
	sta v1
	ldlexvar 0x0, 0x0
	sta v2
	lda v1
	callthis1 0x17, v0, v2
	callarg0 0x19
	tryldglobalbyname 0x1b, "Column"
	sta v0
	ldobjbyname 0x1c, "pop"
	callthis0 0x1e, v0
	tryldglobalbyname 0x20, "Stack"
	sta v0
	ldobjbyname 0x21, "pop"
	callthis0 0x23, v0
	returnundefined
}
```

## MainPage.searchMiniW  (wujie.pa:152332)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#searchMiniW(any a0, any a1, any a2) <static> {
	lda a2
	ldobjbyname 0x0, "winWVpForMini"
	callthis0 0x2, a2
	sta v0
	wide.ldexternalmodulevar 0xb4
	sta v1
	throw.undefinedifholewithname "topPageSideOf"
	lda v1
	callarg1 0x4, v0
	sta v1
	ldai 0x2
	mul2 0x6, v1
	sub2 0x7, v0
	sta v0
	ldai 0xa
	sub2 0x8, v0
	sta v0
	ldai 0xc8
	greater 0x9, v0
	jnez jump_label_0
	ldlexvar 0x1, 0x5
	sta v0
	throw.undefinedifholewithname "SEARCH_MINI_MIN_W"
jump_label_0:
	lda v0
	return
}
```

## MainPage.searchOpen  (wujie.pa:152364)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#searchOpen(any a0, any a1, any a2) <static> {
	lda a2
	ldobjbyname 0x0, "__searchOpen"
	sta v0
	ldobjbyname 0x2, "get"
	callthis0 0x4, v0
	return
}
```

## MainPage.onSearchOpenChanged  (wujie.pa:149445)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#onSearchOpenChanged(any a0, any a1, any a2) <static> {
	ldlexvar 0x1, 0x0
	sta v0
	throw.undefinedifholewithname "BarHeightModifier"
	mov v1, v0
	newobjrange 0x0, 0x1, v1
	sta v0
	lda a2
	ldobjbyname 0x2, "searchOpen"
	stobjbyname 0x4, "hide", v0
	lda v0
	stobjbyname 0x6, "barHeightMod", a2
	lda a2
	ldobjbyname 0x8, "searchOpen"
	callruntime.isfalse 0xa
	jnez jump_label_0
	lda a2
	ldobjbyname 0xb, "expandMiniBar"
	callthis0 0xd, a2
	returnundefined
jump_label_0:
	lda a2
	ldobjbyname 0xf, "collapse"
	sta v0
	ldobjbyname 0x11, "reset"
	callthis0 0x13, v0
	ldfalse
	stobjbyname 0x15, "miniCollapsed", a2
	returnundefined
}
```

## MainPage.closeSearchMorph  (wujie.pa:146915)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#closeSearchMorph(any a0, any a1, any a2) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	wide.ldexternalmodulevar 0x92
	sta v0
	throw.undefinedifholewithname "animateMorph"
	ldlexvar 0x0, 0x0
	sta v1
	ldobjbyname 0x0, "getUIContext"
	callthis0 0x2, v1
	sta v1
	wide.ldexternalmodulevar 0x83
	sta v2
	throw.undefinedifholewithname "SP_SEARCH"
	wide.ldexternalmodulevar 0x84
	sta v3
	throw.undefinedifholewithname "SP_SEARCH_SETTLE_MS"
	definefunc 0x4, &entry.src.main.ets.pages.MainPage&.#~@1>@4*#:(any,any,any), 0x0
	sta v4
	mov v5, v1
	mov v6, v2
	mov v7, v3
	mov v8, v4
	lda v0
	callrange 0x5, 0x4, v5
	callruntime.istrue 0x7
	jnez jump_label_0
	ldtrue
	jmp jump_label_1
jump_label_0:
	ldfalse
jump_label_1:
	callruntime.isfalse 0x8
	jnez jump_label_2
	wide.ldexternalmodulevar 0x9e
	sta v0
	throw.undefinedifholewithname "hilog"
	lda v0
	ldobjbyname 0x9, "info"
	sta v1
	ldlexvar 0x2, 0x1
	sta v2
	throw.undefinedifholewithname "DOMAIN"
	ldlexvar 0x2, 0x2
	sta v3
	throw.undefinedifholewithname "TAG"
	lda.str "closeSearch hard-cut (color mode still settling)"
	sta v4
	lda v1
	callthis3 0xb, v0, v2, v3, v4
jump_label_2:
	returnundefined
}
```

## HomeTab.openSearch  (wujie.pa:411644)
```
.function any &entry.src.main.ets.views.HomeTab&.#~@0>#openSearch(any a0, any a1, any a2) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldexternalmodulevar 0x37
	sta v0
	throw.undefinedifholewithname "animateMorph"
	ldlexvar 0x0, 0x0
	sta v1
	ldobjbyname 0x0, "getUIContext"
	callthis0 0x2, v1
	sta v1
	ldexternalmodulevar 0x2f
	sta v2
	throw.undefinedifholewithname "SP_SEARCH"
	ldexternalmodulevar 0x30
	sta v3
	throw.undefinedifholewithname "SP_SEARCH_SETTLE_MS"
	definefunc 0x4, &entry.src.main.ets.views.HomeTab&.#~@0>@3*#:(any,any,any), 0x0
	sta v4
	mov v5, v1
	mov v6, v2
	mov v7, v3
	mov v8, v4
	lda v0
	callrange 0x5, 0x4, v5
	callruntime.istrue 0x7
	jnez jump_label_0
	ldtrue
	jmp jump_label_1
jump_label_0:
	ldfalse
jump_label_1:
	callruntime.isfalse 0x8
	jnez jump_label_2
	ldexternalmodulevar 0x38
	sta v0
	throw.undefinedifholewithname "hilog"
	lda v0
	ldobjbyname 0x9, "info"
	sta v1
	ldlexvar 0x2, 0x0
	sta v2
	throw.undefinedifholewithname "DOMAIN"
	ldlexvar 0x2, 0x1
	sta v3
	throw.undefinedifholewithname "TAG"
	lda.str "openSearch hard-cut (color mode still settling)"
	sta v4
	lda v1
	callthis3 0xb, v0, v2, v3, v4
jump_label_2:
	returnundefined
}
```

## HomeTab.closeSearch  (wujie.pa:410696)
```
.function any &entry.src.main.ets.views.HomeTab&.#~@0>#closeSearch(any a0, any a1, any a2) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldexternalmodulevar 0x37
	sta v0
	throw.undefinedifholewithname "animateMorph"
	ldlexvar 0x0, 0x0
	sta v1
	ldobjbyname 0x0, "getUIContext"
	callthis0 0x2, v1
	sta v1
	ldexternalmodulevar 0x2f
	sta v2
	throw.undefinedifholewithname "SP_SEARCH"
	ldexternalmodulevar 0x30
	sta v3
	throw.undefinedifholewithname "SP_SEARCH_SETTLE_MS"
	definefunc 0x4, &entry.src.main.ets.views.HomeTab&.#~@0>@4*#:(any,any,any), 0x0
	sta v4
	mov v5, v1
	mov v6, v2
	mov v7, v3
	mov v8, v4
	lda v0
	callrange 0x5, 0x4, v5
	callruntime.istrue 0x7
	jnez jump_label_0
	ldtrue
	jmp jump_label_1
jump_label_0:
	ldfalse
jump_label_1:
	callruntime.isfalse 0x8
	jnez jump_label_2
	ldexternalmodulevar 0x38
	sta v0
	throw.undefinedifholewithname "hilog"
	lda v0
	ldobjbyname 0x9, "info"
	sta v1
	ldlexvar 0x2, 0x0
	sta v2
	throw.undefinedifholewithname "DOMAIN"
	ldlexvar 0x2, 0x1
	sta v3
	throw.undefinedifholewithname "TAG"
	lda.str "closeSearch hard-cut (color mode still settling)"
	sta v4
	lda v1
	callthis3 0xb, v0, v2, v3, v4
jump_label_2:
	returnundefined
}
```

## HomeTab.searchField  (wujie.pa:412145)
```
.function any &entry.src.main.ets.views.HomeTab&.#~@0>#searchField(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.views.HomeTab&.#~@0>@e*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Search"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	tryldglobalbyname 0x7, "Search"
	sta v0
	ldobjbyname 0x8, "pop"
	callthis0 0xa, v0
	returnundefined
}
```

## HomeTab.searchOpen  (wujie.pa:412171)
```
.function any &entry.src.main.ets.views.HomeTab&.#~@0>#searchOpen(any a0, any a1, any a2) <static> {
	lda a2
	ldobjbyname 0x0, "__searchOpen"
	sta v0
	ldobjbyname 0x2, "get"
	callthis0 0x4, v0
	return
}
```

## SearchPageNew.searchBar  (wujie.pa:492850)
```
.function any &entry.src.main.ets.views.SearchPageNew&.#~@0>#searchBar(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.views.SearchPageNew&.#~@0>@8*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Row"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x7, "observeComponentCreation2"
	sta v1
	definefunc 0x9, &entry.src.main.ets.views.SearchPageNew&.#~@0>@8*#^1:(any,any,any,any,any), 0x2
	sta v2
	createobjectwithbuffer 0xa, { 2 [ string:"name", string:"MaterialGlass", ]}
	sta v3
	lda v1
	callthis2 0xb, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0xd, "observeComponentCreation2"
	sta v1
	definefunc 0xf, &entry.src.main.ets.views.SearchPageNew&.#~@0>@8*#^2:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x10, "__Common__"
	sta v3
	lda v1
	callthis2 0x11, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x13, "observeComponentCreation2"
	sta v1
	definefunc 0x15, &entry.src.main.ets.views.SearchPageNew&.#~@0>@8*#^3:(any,any,any,any,any), 0x2
	sta v2
	createobjectwithbuffer 0x16, { 2 [ string:"name", string:"MaterialGlass", ]}
	sta v3
	lda v1
	callthis2 0x17, v0, v2, v3
	tryldglobalbyname 0x19, "__Common__"
	sta v0
	ldobjbyname 0x1a, "pop"
	callthis0 0x1c, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1e, "observeComponentCreation2"
	sta v1
	definefunc 0x20, &entry.src.main.ets.views.SearchPageNew&.#~@0>@8*#^4:(any,any,any,any,any), 0x2
	sta v2
	createobjectwithbuffer 0x21, { 2 [ string:"name", string:"MaterialGlass", ]}
	sta v3
	lda v1
	callthis2 0x22, v0, v2, v3
	tryldglobalbyname 0x24, "Row"
	sta v0
	ldobjbyname 0x25, "pop"
	callthis0 0x27, v0
	returnundefined
}
```

## SearchPageNew.searchField  (wujie.pa:492955)
```
.function any &entry.src.main.ets.views.SearchPageNew&.#~@0>#searchField(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.views.SearchPageNew&.#~@0>@b*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Search"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	tryldglobalbyname 0x7, "Search"
	sta v0
	ldobjbyname 0x8, "pop"
	callthis0 0xa, v0
	returnundefined
}
```

