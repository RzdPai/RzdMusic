# 无界 1.2.4 · 「收起变回播放条」这一块的完整反编译代码

> 来源 `_recover/disasm/wujie.pa`（字节码 dump，`MainPage` 模块）。**仅供效果参考**：
> 本仓为了自定义光感改过结构（胶囊 = 我们自己的 MiniBarMaterialCapsule），结构不能照搬。
> 反编译是字节码，读法：`ldobjbyname X, "name"` = 读成员，`stobjbyname` = 写成员，
> `callthis0/1/2` = 调用，`ldlexvar 0x0` = this，`ldexternalmodulevar` = 外部模块（如 ExpandSnapshot）。

## morphGlass  (wujie.pa:148557)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#morphGlass(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@1b*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Stack"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x7, "observeComponentCreation2"
	sta v1
	definefunc 0x9, &entry.src.main.ets.pages.MainPage&.#~@1>@1b*#^1:(any,any,any,any,any), 0x2
	sta v2
	createobjectwithbuffer 0xa, { 2 [ string:"name", string:"MaterialCapsule", ]}
	sta v3
	lda v1
	callthis2 0xb, v0, v2, v3
	tryldglobalbyname 0xd, "Stack"
	sta v0
	ldobjbyname 0xe, "pop"
	callthis0 0x10, v0
	returnundefined
}
```

## morphGlassOpacity  (wujie.pa:148593)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#morphGlassOpacity(any a0, any a1, any a2) <static> {
	ldai 0x0
	sta v0
	ldai 0x1
	sta v1
	lda a2
	ldobjbyname 0x0, "morphT"
	sta v2
	ldexternalmodulevar 0x4c
	sta v3
	throw.undefinedifholewithname "MORPH_GLASS_IN_T"
	lda v3
	div2 0x2, v2
	sub2 0x3, v1
	sta v2
	lda v0
	less 0x4, v2
	jnez jump_label_0
	lda v1
	greater 0x5, v2
	jeqz jump_label_1
	mov v0, v1
	jmp jump_label_0
jump_label_1:
	mov v0, v2
jump_label_0:
	lda v0
	return
}
```

## glassBaseW  (wujie.pa:147644)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassBaseW(any a0, any a1, any a2) <static> {
	lda a2
	ldobjbyname 0x0, "morphInput"
	ldobjbyname 0x2, "capsule"
	ldobjbyname 0x4, "width"
	sta v0
	lda a2
	ldobjbyname 0x6, "getUIContext"
	callthis0 0x8, a2
	sta v1
	ldobjbyname 0xa, "vp2px"
	sta v2
	ldai 0x1
	sta v3
	lda v2
	callthis1 0xc, v1, v3
	div2 0xe, v0
	return
}
```

## glassBaseH  (wujie.pa:147621)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassBaseH(any a0, any a1, any a2) <static> {
	lda a2
	ldobjbyname 0x0, "morphInput"
	ldobjbyname 0x2, "capsule"
	ldobjbyname 0x4, "height"
	sta v0
	lda a2
	ldobjbyname 0x6, "getUIContext"
	callthis0 0x8, a2
	sta v1
	ldobjbyname 0xa, "vp2px"
	sta v2
	ldai 0x1
	sta v3
	lda v2
	callthis1 0xc, v1, v3
	div2 0xe, v0
	return
}
```

## glassRectW  (wujie.pa:147691)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassRectW(any a0, any a1, any a2) <static> {
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	lda v0
	ldobjbyname 0x0, "morphCapsuleRect"
	sta v0
	ldundefined
	stricteq 0x2, v0
	jeqz jump_label_0
	lda a2
	ldobjbyname 0x3, "glassBaseW"
	callthis0 0x5, a2
	jmp jump_label_1
jump_label_0:
	lda v0
	ldobjbyname 0x7, "width"
jump_label_1:
	return
}
```

## glassRectH  (wujie.pa:147667)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassRectH(any a0, any a1, any a2) <static> {
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	lda v0
	ldobjbyname 0x0, "morphCapsuleRect"
	sta v0
	ldundefined
	stricteq 0x2, v0
	jeqz jump_label_0
	lda a2
	ldobjbyname 0x3, "glassBaseH"
	callthis0 0x5, a2
	jmp jump_label_1
jump_label_0:
	lda v0
	ldobjbyname 0x7, "height"
jump_label_1:
	return
}
```

## glassX  (wujie.pa:147815)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassX(any a0, any a1, any a2) <static> {
	ldai 0x2
	sta v0
	ldexternalmodulevar 0x18
	sta v1
	throw.undefinedifholewithname "ExpandSnapshot"
	lda v1
	ldobjbyname 0x0, "morphCapsuleRect"
	sta v1
	ldundefined
	stricteq 0x2, v1
	jeqz jump_label_0
	lda a2
	ldobjbyname 0x3, "morphInput"
	ldobjbyname 0x5, "capsule"
	ldobjbyname 0x7, "left"
	sta v1
	lda a2
	ldobjbyname 0x9, "getUIContext"
	callthis0 0xb, a2
	sta v2
	ldobjbyname 0xd, "vp2px"
	sta v3
	ldai 0x1
	sta v4
	lda v3
	callthis1 0xf, v2, v4
	div2 0x11, v1
	sta v1
	lda a2
	ldobjbyname 0x12, "glassBaseW"
	callthis0 0x14, a2
	sta v2
	lda v0
	div2 0x16, v2
	add2 0x17, v1
	sta v1
	jmp jump_label_1
jump_label_0:
	lda v1
	ldobjbyname 0x18, "left"
	sta v2
	lda v1
	ldobjbyname 0x1a, "width"
	sta v1
	lda v0
	div2 0x1c, v1
	add2 0x1d, v2
	sta v1
jump_label_1:
	lda a2
	ldobjbyname 0x1e, "glassBaseW"
	callthis0 0x20, a2
	sta v2
	ldexternalmodulevar 0xa
	sta v3
	throw.undefinedifholewithname "CAPSULE_SLACK_W"
	lda v3
	add2 0x22, v2
	sta v2
	lda v0
	div2 0x23, v2
	sub2 0x24, v1
	return
}
```

## glassY  (wujie.pa:147884)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassY(any a0, any a1, any a2) <static> {
	ldai 0x2
	sta v0
	ldexternalmodulevar 0x18
	sta v1
	throw.undefinedifholewithname "ExpandSnapshot"
	lda v1
	ldobjbyname 0x0, "morphCapsuleRect"
	sta v1
	ldundefined
	stricteq 0x2, v1
	jeqz jump_label_0
	lda a2
	ldobjbyname 0x3, "morphInput"
	ldobjbyname 0x5, "capsule"
	ldobjbyname 0x7, "top"
	sta v1
	lda a2
	ldobjbyname 0x9, "getUIContext"
	callthis0 0xb, a2
	sta v2
	ldobjbyname 0xd, "vp2px"
	sta v3
	ldai 0x1
	sta v4
	lda v3
	callthis1 0xf, v2, v4
	div2 0x11, v1
	sta v1
	lda a2
	ldobjbyname 0x12, "glassBaseH"
	callthis0 0x14, a2
	sta v2
	lda v0
	div2 0x16, v2
	add2 0x17, v1
	sta v1
	jmp jump_label_1
jump_label_0:
	lda v1
	ldobjbyname 0x18, "top"
	sta v2
	lda v1
	ldobjbyname 0x1a, "height"
	sta v1
	lda v0
	div2 0x1c, v1
	add2 0x1d, v2
	sta v1
jump_label_1:
	lda a2
	ldobjbyname 0x1e, "glassBaseH"
	callthis0 0x20, a2
	sta v2
	ldexternalmodulevar 0x9
	sta v3
	throw.undefinedifholewithname "CAPSULE_SLACK_H"
	lda v3
	add2 0x22, v2
	sta v2
	lda v0
	div2 0x23, v2
	sub2 0x24, v1
	return
}
```

## glassScaleX  (wujie.pa:147715)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassScaleX(any a0, any a1, any a2) <static> {
	ldai 0x1
	sta v0
	lda a2
	ldobjbyname 0x0, "glassBaseW"
	callthis0 0x2, a2
	sta v1
	ldai 0x0
	greater 0x4, v1
	jeqz jump_label_0
	lda a2
	ldobjbyname 0x5, "glassRectW"
	callthis0 0x7, a2
	sta v0
	lda v1
	div2 0x9, v0
	sta v0
jump_label_0:
	lda v0
	return
}
```

## glassScaleY  (wujie.pa:147740)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#glassScaleY(any a0, any a1, any a2) <static> {
	ldai 0x1
	sta v0
	lda a2
	ldobjbyname 0x0, "glassBaseH"
	callthis0 0x2, a2
	sta v1
	ldai 0x0
	greater 0x4, v1
	jeqz jump_label_0
	lda a2
	ldobjbyname 0x5, "glassRectH"
	callthis0 0x7, a2
	sta v0
	lda v1
	div2 0x9, v0
	sta v0
jump_label_0:
	lda v0
	return
}
```

## morphOverlay  (wujie.pa:148707)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#morphOverlay(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@19*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "If"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	tryldglobalbyname 0x7, "If"
	sta v0
	ldobjbyname 0x8, "pop"
	callthis0 0xa, v0
	returnundefined
}
```

## morphCover  (wujie.pa:148449)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#morphCover(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@1d*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Stack"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x7, "observeComponentCreation2"
	sta v1
	definefunc 0x9, &entry.src.main.ets.pages.MainPage&.#~@1>@1d*#^1:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0xa, "Column"
	sta v3
	lda v1
	callthis2 0xb, v0, v2, v3
	tryldglobalbyname 0xd, "Column"
	sta v0
	ldobjbyname 0xe, "pop"
	callthis0 0x10, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x12, "observeComponentCreation2"
	sta v1
	definefunc 0x14, &entry.src.main.ets.pages.MainPage&.#~@1>@1d*#^2:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x15, "If"
	sta v3
	lda v1
	callthis2 0x16, v0, v2, v3
	tryldglobalbyname 0x18, "If"
	sta v0
	ldobjbyname 0x19, "pop"
	callthis0 0x1b, v0
	tryldglobalbyname 0x1d, "Stack"
	sta v0
	ldobjbyname 0x1e, "pop"
	callthis0 0x20, v0
	returnundefined
}
```

## morphMiniMeta  (wujie.pa:148653)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#morphMiniMeta(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@1e*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Column"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x7, "observeComponentCreation2"
	sta v1
	definefunc 0x9, &entry.src.main.ets.pages.MainPage&.#~@1>@1e*#^1:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0xa, "Text"
	sta v3
	lda v1
	callthis2 0xb, v0, v2, v3
	tryldglobalbyname 0xd, "Text"
	sta v0
	ldobjbyname 0xe, "pop"
	callthis0 0x10, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x12, "observeComponentCreation2"
	sta v1
	definefunc 0x14, &entry.src.main.ets.pages.MainPage&.#~@1>@1e*#^2:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x15, "If"
	sta v3
	lda v1
	callthis2 0x16, v0, v2, v3
	tryldglobalbyname 0x18, "If"
	sta v0
	ldobjbyname 0x19, "pop"
	callthis0 0x1b, v0
	tryldglobalbyname 0x1d, "Column"
	sta v0
	ldobjbyname 0x1e, "pop"
	callthis0 0x20, v0
	returnundefined
}
```

## morphActions  (wujie.pa:148351)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#morphActions(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@1f*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Row"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x7, "observeComponentCreation2"
	sta v1
	definefunc 0x9, &entry.src.main.ets.pages.MainPage&.#~@1>@1f*#^1:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0xa, "Stack"
	sta v3
	lda v1
	callthis2 0xb, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0xd, "observeComponentCreation2"
	sta v1
	definefunc 0xf, &entry.src.main.ets.pages.MainPage&.#~@1>@1f*#^2:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x10, "SymbolGlyph"
	sta v3
	lda v1
	callthis2 0x11, v0, v2, v3
	tryldglobalbyname 0x13, "Stack"
	sta v0
	ldobjbyname 0x14, "pop"
	callthis0 0x16, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x18, "observeComponentCreation2"
	sta v1
	definefunc 0x1a, &entry.src.main.ets.pages.MainPage&.#~@1>@1f*#^3:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x1b, "Stack"
	sta v3
	lda v1
	callthis2 0x1c, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1e, "observeComponentCreation2"
	sta v1
	definefunc 0x20, &entry.src.main.ets.pages.MainPage&.#~@1>@1f*#^4:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x21, "SymbolGlyph"
	sta v3
	lda v1
	callthis2 0x22, v0, v2, v3
	tryldglobalbyname 0x24, "Stack"
	sta v0
	ldobjbyname 0x25, "pop"
	callthis0 0x27, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x29, "observeComponentCreation2"
	sta v1
	definefunc 0x2b, &entry.src.main.ets.pages.MainPage&.#~@1>@1f*#^5:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x2c, "Stack"
	sta v3
	lda v1
	callthis2 0x2d, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x2f, "observeComponentCreation2"
	sta v1
	definefunc 0x31, &entry.src.main.ets.pages.MainPage&.#~@1>@1f*#^6:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x32, "SymbolGlyph"
	sta v3
	lda v1
	callthis2 0x33, v0, v2, v3
	tryldglobalbyname 0x35, "Stack"
	sta v0
	ldobjbyname 0x36, "pop"
	callthis0 0x38, v0
	tryldglobalbyname 0x3a, "Row"
	sta v0
	ldobjbyname 0x3b, "pop"
	callthis0 0x3d, v0
	returnundefined
}
```

## openPlayerMorph  (wujie.pa:149679)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#openPlayerMorph(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	jeqz jump_label_0
	ldlexvar 0x0, 0x0
	ldobjbyname 0x1, "ownMorphSource"
	sta a3
jump_label_0:
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x3, "beginMorphEnter"
	callthis1 0x5, v0, a3
	callruntime.istrue 0x7
	jnez jump_label_1
	ldtrue
	jmp jump_label_2
jump_label_1:
	ldfalse
jump_label_2:
	callruntime.isfalse 0x8
	jnez jump_label_3
	ldlexvar 0x0, 0x0
	ldobjbyname 0x9, "nav"
	sta v0
	ldobjbyname 0xb, "pushPath"
	sta v1
	createobjectwithbuffer 0xd, { 2 [ string:"name", null_value:0, ]}
	sta v2
	ldexternalmodulevar 0x71
	sta v3
	throw.undefinedifholewithname "R_PLAYER"
	lda v3
	definepropertybyname 0xe, "name", v2
	lda v1
	callthis1 0x10, v0, v2
	returnundefined
jump_label_3:
	ldlexvar 0x0, 0x0
	sta v0
	ldfalse
	stobjbyname 0x12, "enterAnimStarted", v0
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	definefunc 0x14, &entry.src.main.ets.pages.MainPage&.#~@1>@5*#:(any,any,any), 0x0
	stobjbyname 0x15, "onPullReady", v0
	returnundefined
}
```

## beginMorphEnter  (wujie.pa:146495)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#beginMorphEnter(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	ldobjbyname 0x0, "miniHasTrack"
	callruntime.istrue 0x2
	jnez jump_label_0
	ldtrue
	jmp jump_label_1
jump_label_0:
	ldfalse
jump_label_1:
	callruntime.isfalse 0x3
	jnez jump_label_2
	ldfalse
	return
jump_label_2:
	lda a3
	stobjbyname 0x4, "morphSrcPinned", a2
	lda a2
	ldobjbyname 0x6, "getUIContext"
	callthis0 0x8, a2
	sta v0
	lda a2
	ldobjbyname 0xa, "pickCapsuleRect"
	callthis1 0xc, a2, v0
	sta v1
	ldundefined
	stricteq 0xe, v1
	jeqz jump_label_3
	ldfalse
	return
jump_label_3:
	lda a2
	ldobjbyname 0xf, "activeMorphSource"
	callthis0 0x11, a2
	stlexvar 0x0, 0x0
	ldexternalmodulevar 0x18
	sta v1
	throw.undefinedifholewithname "ExpandSnapshot"
	lda a2
	ldobjbyname 0x13, "pickCapsuleRect"
	callthis1 0x15, a2, v0
	stobjbyname 0x17, "srcBoxRect", v1
	ldexternalmodulevar 0x18
	sta v1
	throw.undefinedifholewithname "ExpandSnapshot"
	wide.ldexternalmodulevar 0x99
	sta v2
	throw.undefinedifholewithname "getRectByFrameNode"
	ldlexvar 0x0, 0x0
	sta v3
	throw.undefinedifholewithname "src"
	lda v3
	ldobjbyname 0x19, "coverId"
	sta v3
	lda v2
	callargs2 0x1b, v0, v3
	stobjbyname 0x1d, "srcCoverRect", v1
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	definefunc 0x1f, &entry.src.main.ets.pages.MainPage&.#~@1>@c*#:(any,any,any), 0x0
	stobjbyname 0x20, "onRecoverSrc", v0
	ldfalse
	stobjbyname 0x22, "morphTargetsReal", a2
	lda a2
	ldobjbyname 0x24, "setMorph"
	sta v0
	ldexternalmodulevar 0x55
	sta v1
	throw.undefinedifholewithname "MorphStage"
	lda v1
	ldobjbyname 0x26, "ENTERING"
	sta v1
	ldexternalmodulevar 0x52
	sta v2
	throw.undefinedifholewithname "MorphDrive"
	lda v2
	ldobjbyname 0x28, "FINGER"
	sta v2
	lda v0
	callthis2 0x2a, a2, v1, v2
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	lda v0
	ldobjbyname 0x2c, "morphSeq"
	tonumeric 0x2e
	inc 0x2f
	stobjbyname 0x30, "morphSeq", v0
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	ldfalse
	stobjbyname 0x32, "morphGeomReady", v0
	tryldglobalbyname 0x34, "AppStorage"
	sta v0
	ldobjbyname 0x35, "setOrCreate"
	sta v1
	ldexternalmodulevar 0x36
	sta v2
	throw.undefinedifholewithname "K_MORPH_SQUASH"
	ldfalse
	sta v3
	lda v1
	callthis2 0x37, v0, v2, v3
	ldai 0x0
	stobjbyname 0x39, "morphT", a2
	tryldglobalbyname 0x3b, "AppStorage"
	sta v0
	ldobjbyname 0x3c, "setOrCreate"
	sta v1
	ldexternalmodulevar 0x38
	sta v2
	throw.undefinedifholewithname "K_PULL_ACTIVE"
	ldfalse
	sta v3
	lda v1
	callthis2 0x3e, v0, v2, v3
	lda a2
	ldobjbyname 0x40, "buildMorph"
	callthis0 0x42, a2
	createobjectwithbuffer 0x44, { 2 [ string:"pull", u1:1, ]}
	sta v0
	lda a2
	ldobjbyname 0x45, "nav"
	sta v1
	ldobjbyname 0x47, "pushPath"
	sta v2
	createobjectwithbuffer 0x49, { 4 [ string:"name", null_value:0, string:"param", null_value:0, ]}
	sta v3
	ldexternalmodulevar 0x71
	sta v4
	throw.undefinedifholewithname "R_PLAYER"
	lda v4
	definepropertybyname 0x4a, "name", v3
	lda v0
	definepropertybyname 0x4c, "param", v3
	ldfalse
	sta v0
	lda v2
	callthis2 0x4e, v1, v3, v0
	ldtrue
	return
}
```

## animateMorphT  (wujie.pa:145608)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#animateMorphT(any a0, any a1, any a2, any a3, any a4, any a5, any a6) <static> {
	newlexenv 0x3
	lda a2
	stlexvar 0x0, 0x2
	lda a3
	stlexvar 0x0, 0x0
	lda a6
	stlexvar 0x0, 0x1
	ldlexvar 0x0, 0x2
	sta v0
	ldobjbyname 0x0, "stopMorphAnim"
	callthis0 0x2, v0
	ldlexvar 0x0, 0x2
	ldobjbyname 0x4, "morphT"
	sta v0
	ldlexvar 0x0, 0x0
	stricteq 0x6, v0
	jeqz jump_label_0
	ldlexvar 0x0, 0x1
	callarg0 0x7
	returnundefined
jump_label_0:
	ldlexvar 0x0, 0x2
	sta v1
	ldobjbyname 0x9, "getUIContext"
	callthis0 0xb, v1
	sta v1
	ldobjbyname 0xd, "createAnimator"
	sta v2
	createobjectwithbuffer 0xf, { 16 [ string:"duration", null_value:0, string:"easing", null_value:0, string:"delay", i32:0, string:"fill", string:"forwards", string:"direction", string:"normal", string:"iterations", i32:1, string:"begin", null_value:0, string:"end", null_value:0, ]}
	sta v3
	lda a4
	definepropertybyname 0x10, "duration", v3
	lda a5
	definepropertybyname 0x12, "easing", v3
	lda v0
	definepropertybyname 0x14, "begin", v3
	ldlexvar 0x0, 0x0
	definepropertybyname 0x16, "end", v3
	lda v2
	callthis1 0x18, v1, v3
	sta v0
	definefunc 0x1a, &entry.src.main.ets.pages.MainPage&.#~@1>@d*#:(any,any,any,any), 0x1
	stobjbyname 0x1b, "onFrame", v0
	definefunc 0x1d, &entry.src.main.ets.pages.MainPage&.#~@1>@d*#^1:(any,any,any), 0x0
	stobjbyname 0x1e, "onFinish", v0
	ldlexvar 0x0, 0x2
	sta v1
	lda v0
	stobjbyname 0x20, "morphAnim", v1
	lda v0
	ldobjbyname 0x22, "play"
	callthis0 0x24, v0
	returnundefined
}
```

## startReverseMorph  (wujie.pa:153984)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#startReverseMorph(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x0, "adoptSnap"
	callthis1 0x2, v0, a3
	ldlexvar 0x0, 0x0
	ldobjbyname 0x4, "morph"
	sta v0
	ldundefined
	stricteq 0x6, v0
	jeqz jump_label_0
	ldfalse
	return
jump_label_0:
	wide.ldexternalmodulevar 0xae
	sta v0
	throw.undefinedifholewithname "reverseIntentOf"
	ldlexvar 0x0, 0x0
	ldobjbyname 0x7, "morphStage"
	sta v1
	ldlexvar 0x0, 0x0
	ldobjbyname 0x9, "morphDrive"
	sta v2
	ldlexvar 0x0, 0x0
	ldobjbyname 0xb, "morph"
	sta v3
	ldundefined
	strictnoteq 0xd, v3
	sta v3
	lda v0
	callargs3 0xe, v1, v2, v3
	sta v0
	wide.ldexternalmodulevar 0x80
	sta v1
	throw.undefinedifholewithname "ReverseIntent"
	lda v1
	ldobjbyname 0x10, "NONE"
	stricteq 0x12, v0
	jeqz jump_label_1
	ldfalse
	return
jump_label_1:
	wide.ldexternalmodulevar 0x80
	sta v1
	throw.undefinedifholewithname "ReverseIntent"
	lda v1
	ldobjbyname 0x13, "ALREADY"
	stricteq 0x15, v0
	jeqz jump_label_2
	ldtrue
	return
jump_label_2:
	wide.ldexternalmodulevar 0x80
	sta v1
	throw.undefinedifholewithname "ReverseIntent"
	lda v1
	ldobjbyname 0x16, "ABORT_AND_POP"
	stricteq 0x18, v0
	jeqz jump_label_3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x19, "abortMorphNow"
	callthis0 0x1b, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1d, "shellOnTop"
	callthis0 0x1f, v0
	callruntime.istrue 0x21
	jnez jump_label_4
	ldtrue
	jmp jump_label_5
jump_label_4:
	ldfalse
jump_label_5:
	callruntime.isfalse 0x22
	jnez jump_label_6
	ldlexvar 0x0, 0x0
	sta v0
	ldtrue
	stobjbyname 0x23, "popAfterPlayerGone", v0
jump_label_6:
	ldtrue
	return
jump_label_3:
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x25, "retargetToLiveCover"
	callthis0 0x27, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x29, "setMorph"
	sta v1
	ldexternalmodulevar 0x55
	sta v2
	throw.undefinedifholewithname "MorphStage"
	lda v2
	ldobjbyname 0x2b, "LEAVING"
	sta v2
	ldexternalmodulevar 0x52
	sta v3
	throw.undefinedifholewithname "MorphDrive"
	lda v3
	ldobjbyname 0x2d, "ANIM"
	sta v3
	lda v1
	callthis2 0x2f, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x31, "setMiniOut"
	sta v1
	ldtrue
	sta v2
	lda v1
	callthis1 0x33, v0, v2
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x35, "animateMorphT"
	sta v1
	ldlexvar 0x0, 0x0
	sta v2
	ldobjbyname 0x37, "reverseMs"
	sta v3
	ldlexvar 0x0, 0x0
	ldobjbyname 0x39, "morphT"
	sta v4
	lda v3
	callthis1 0x3b, v2, v4
	sta v2
	ldlexvar 0x1, 0x0
	sta v3
	throw.undefinedifholewithname "MainPage"
	lda v3
	ldobjbyname 0x3d, "REVERSE_EASING"
	sta v3
	definefunc 0x3f, &entry.src.main.ets.pages.MainPage&.#~@1>@10*#:(any,any,any), 0x0
	sta v4
	ldai 0x0
	sta v5
	mov v6, v0
	mov v7, v5
	mov v8, v2
	mov v9, v3
	mov v10, v4
	lda v1
	callthisrange 0x40, 0x4, v6
	ldtrue
	return
}
```

## setMorph  (wujie.pa:153382)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#setMorph(any a0, any a1, any a2, any a3, any a4) <static> {
	lda a3
	stobjbyname 0x0, "morphStage", a2
	lda a4
	stobjbyname 0x2, "morphDrive", a2
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	wide.ldexternalmodulevar 0xa3
	sta v1
	throw.undefinedifholewithname "morphLiveOf"
	lda v1
	callarg1 0x4, a3
	stobjbyname 0x6, "morphLive", v0
	tryldglobalbyname 0x8, "AppStorage"
	sta v0
	ldobjbyname 0x9, "setOrCreate"
	sta v1
	ldexternalmodulevar 0x36
	sta v2
	throw.undefinedifholewithname "K_MORPH_SQUASH"
	wide.ldexternalmodulevar 0xa8
	sta v3
	throw.undefinedifholewithname "playerPaintsOf"
	lda v3
	callarg1 0xb, a3
	callruntime.istrue 0xd
	jnez jump_label_0
	ldtrue
	sta v3
	jmp jump_label_1
jump_label_0:
	ldfalse
	sta v3
jump_label_1:
	lda v1
	callthis2 0xe, v0, v2, v3
	ldexternalmodulevar 0x55
	sta v0
	throw.undefinedifholewithname "MorphStage"
	lda v0
	ldobjbyname 0x10, "LANDING"
	strictnoteq 0x12, a3
	jeqz jump_label_2
	lda a2
	ldobjbyname 0x13, "stopLandAnim"
	callthis0 0x15, a2
	ldai 0x1
	stobjbyname 0x17, "morphSquashY", a2
jump_label_2:
	wide.ldexternalmodulevar 0x9b
	sta v0
	throw.undefinedifholewithname "grabberScopeOf"
	lda v0
	callargs2 0x19, a3, a4
	stobjbyname 0x1b, "grabber", a2
	ldexternalmodulevar 0x55
	sta v0
	throw.undefinedifholewithname "MorphStage"
	lda v0
	ldobjbyname 0x1d, "NONE"
	stricteq 0x1f, a3
	callruntime.istrue 0x20
	jnez jump_label_3
	ldexternalmodulevar 0x55
	sta v0
	throw.undefinedifholewithname "MorphStage"
	lda v0
	ldobjbyname 0x21, "OPEN"
	stricteq 0x23, a3
	callruntime.isfalse 0x24
	jnez jump_label_4
jump_label_3:
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	definefunc 0x25, &entry.src.main.ets.pages.MainPage&.#~@1>@11*#:(any,any,any), 0x0
	stobjbyname 0x26, "onPullReady", v0
	ldundefined
	stobjbyname 0x28, "morphSrcPinned", a2
jump_label_4:
	returnundefined
}
```

## squashLand  (wujie.pa:153727)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#squashLand(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x2
	lda a2
	stlexvar 0x0, 0x1
	lda a3
	stlexvar 0x0, 0x0
	ldlexvar 0x0, 0x1
	sta v0
	ldobjbyname 0x0, "setMorph"
	sta v1
	ldexternalmodulevar 0x55
	sta v2
	throw.undefinedifholewithname "MorphStage"
	lda v2
	ldobjbyname 0x2, "LANDING"
	sta v2
	ldexternalmodulevar 0x52
	sta v3
	throw.undefinedifholewithname "MorphDrive"
	lda v3
	ldobjbyname 0x4, "ANIM"
	sta v3
	lda v1
	callthis2 0x6, v0, v2, v3
	wide.ldexternalmodulevar 0x9e
	sta v0
	throw.undefinedifholewithname "hilog"
	lda v0
	ldobjbyname 0x8, "info"
	sta v1
	ldlexvar 0x2, 0x1
	sta v2
	throw.undefinedifholewithname "DOMAIN"
	ldlexvar 0x2, 0x2
	sta v3
	throw.undefinedifholewithname "TAG"
	lda.str "DIAG squash begin"
	sta v4
	lda v1
	callthis3 0xa, v0, v2, v3, v4
	ldlexvar 0x0, 0x1
	sta v0
	ldobjbyname 0xc, "animateSquash"
	sta v1
	ldlexvar 0x1, 0x0
	sta v2
	throw.undefinedifholewithname "MainPage"
	lda v2
	ldobjbyname 0xe, "SQUASH_Y"
	sta v2
	ldlexvar 0x1, 0x0
	sta v3
	throw.undefinedifholewithname "MainPage"
	lda v3
	ldobjbyname 0x10, "SQUASH_MS"
	sta v3
	ldexternalmodulevar 0x16
	sta v4
	throw.undefinedifholewithname "EASE_OUT_STR"
	definefunc 0x12, &entry.src.main.ets.pages.MainPage&.#~@1>@9*#:(any,any,any), 0x0
	sta v5
	mov v6, v0
	mov v7, v2
	mov v8, v3
	mov v9, v4
	mov v10, v5
	lda v1
	callthisrange 0x13, 0x4, v6
	returnundefined
}
```

## animateSquash  (wujie.pa:145667)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#animateSquash(any a0, any a1, any a2, any a3, any a4, any a5, any a6) <static> {
	newlexenv 0x3
	lda a2
	stlexvar 0x0, 0x2
	lda a3
	stlexvar 0x0, 0x0
	lda a6
	stlexvar 0x0, 0x1
	ldlexvar 0x0, 0x2
	sta v0
	ldobjbyname 0x0, "stopLandAnim"
	callthis0 0x2, v0
	ldlexvar 0x0, 0x2
	ldobjbyname 0x4, "morphSquashY"
	sta v0
	ldlexvar 0x0, 0x0
	stricteq 0x6, v0
	jeqz jump_label_0
	ldlexvar 0x0, 0x1
	callarg0 0x7
	returnundefined
jump_label_0:
	ldlexvar 0x0, 0x2
	sta v1
	ldobjbyname 0x9, "getUIContext"
	callthis0 0xb, v1
	sta v1
	ldobjbyname 0xd, "createAnimator"
	sta v2
	createobjectwithbuffer 0xf, { 16 [ string:"duration", null_value:0, string:"easing", null_value:0, string:"delay", i32:0, string:"fill", string:"forwards", string:"direction", string:"normal", string:"iterations", i32:1, string:"begin", null_value:0, string:"end", null_value:0, ]}
	sta v3
	lda a4
	definepropertybyname 0x10, "duration", v3
	lda a5
	definepropertybyname 0x12, "easing", v3
	lda v0
	definepropertybyname 0x14, "begin", v3
	ldlexvar 0x0, 0x0
	definepropertybyname 0x16, "end", v3
	lda v2
	callthis1 0x18, v1, v3
	sta v0
	definefunc 0x1a, &entry.src.main.ets.pages.MainPage&.#~@1>@a*#:(any,any,any,any), 0x1
	stobjbyname 0x1b, "onFrame", v0
	definefunc 0x1d, &entry.src.main.ets.pages.MainPage&.#~@1>@a*#^1:(any,any,any), 0x0
	stobjbyname 0x1e, "onFinish", v0
	ldlexvar 0x0, 0x2
	sta v1
	lda v0
	stobjbyname 0x20, "landAnim", v1
	lda v0
	ldobjbyname 0x22, "play"
	callthis0 0x24, v0
	returnundefined
}
```

## stopLandAnim  (wujie.pa:154203)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#stopLandAnim(any a0, any a1, any a2) <static> {
	lda a2
	ldobjbyname 0x0, "landAnim"
	sta v0
	ldnull
	stricteq 0x2, v0
	jeqz jump_label_0
	returnundefined
jump_label_0:
	ldnull
	stobjbyname 0x3, "landAnim", a2
	definefunc 0x5, &entry.src.main.ets.pages.MainPage&.#~@1>@b*#:(any,any,any), 0x0
	stobjbyname 0x6, "onFrame", v0
	definefunc 0x8, &entry.src.main.ets.pages.MainPage&.#~@1>@b*#^1:(any,any,any), 0x0
	stobjbyname 0x9, "onFinish", v0
	lda v0
	ldobjbyname 0xb, "cancel"
	callthis0 0xd, v0
	returnundefined
}
```

## pullStart  (wujie.pa:150849)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#pullStart(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	jeqz jump_label_0
	ldlexvar 0x0, 0x0
	ldobjbyname 0x1, "ownMorphSource"
	sta a3
jump_label_0:
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x3, "beginMorphEnter"
	callthis1 0x5, v0, a3
	callruntime.istrue 0x7
	jnez jump_label_1
	ldtrue
	jmp jump_label_2
jump_label_1:
	ldfalse
jump_label_2:
	callruntime.isfalse 0x8
	jnez jump_label_3
	returnundefined
jump_label_3:
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	definefunc 0x9, &entry.src.main.ets.pages.MainPage&.#~@1>@16*#:(any,any,any), 0x0
	stobjbyname 0xa, "onPullReady", v0
	returnundefined
}
```

## commitPull  (wujie.pa:146973)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#commitPull(any a0, any a1, any a2) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x0, "animateMorphT"
	sta v1
	ldlexvar 0x1, 0x0
	sta v2
	throw.undefinedifholewithname "MainPage"
	lda v2
	ldobjbyname 0x2, "SETTLE_MS"
	sta v2
	ldexternalmodulevar 0x16
	sta v3
	throw.undefinedifholewithname "EASE_OUT_STR"
	definefunc 0x4, &entry.src.main.ets.pages.MainPage&.#~@1>@17*#:(any,any,any), 0x0
	sta v4
	ldai 0x1
	sta v5
	mov v6, v0
	mov v7, v5
	mov v8, v2
	mov v9, v3
	mov v10, v4
	lda v1
	callthisrange 0x5, 0x4, v6
	returnundefined
}
```

## cancelPull  (wujie.pa:146866)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#cancelPull(any a0, any a1, any a2) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x0, "animateMorphT"
	sta v1
	ldlexvar 0x1, 0x0
	sta v2
	throw.undefinedifholewithname "MainPage"
	lda v2
	ldobjbyname 0x2, "SETTLE_MS"
	sta v2
	ldexternalmodulevar 0x16
	sta v3
	throw.undefinedifholewithname "EASE_OUT_STR"
	definefunc 0x4, &entry.src.main.ets.pages.MainPage&.#~@1>@18*#:(any,any,any), 0x0
	sta v4
	ldai 0x0
	sta v5
	mov v6, v0
	mov v7, v5
	mov v8, v2
	mov v9, v3
	mov v10, v4
	lda v1
	callthisrange 0x5, 0x4, v6
	returnundefined
}
```

## reverseDragEnd  (wujie.pa:151761)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#reverseDragEnd(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x2
	lda a2
	stlexvar 0x0, 0x1
	wide.ldexternalmodulevar 0xad
	sta v0
	throw.undefinedifholewithname "reverseGestureAliveOf"
	ldlexvar 0x0, 0x1
	ldobjbyname 0x0, "morphStage"
	sta v1
	ldlexvar 0x0, 0x1
	ldobjbyname 0x2, "morphDrive"
	sta v2
	lda v0
	callargs2 0x4, v1, v2
	callruntime.istrue 0x6
	jnez jump_label_0
	ldtrue
	jmp jump_label_1
jump_label_0:
	ldfalse
jump_label_1:
	callruntime.isfalse 0x7
	jnez jump_label_2
	returnundefined
jump_label_2:
	ldlexvar 0x0, 0x1
	sta v0
	ldobjbyname 0x8, "setMorph"
	sta v1
	ldexternalmodulevar 0x55
	sta v2
	throw.undefinedifholewithname "MorphStage"
	lda v2
	ldobjbyname 0xa, "LEAVING"
	sta v2
	ldexternalmodulevar 0x52
	sta v3
	throw.undefinedifholewithname "MorphDrive"
	lda v3
	ldobjbyname 0xc, "ANIM"
	sta v3
	lda v1
	callthis2 0xe, v0, v2, v3
	ldlexvar 0x0, 0x1
	ldobjbyname 0x10, "reverseBaseT"
	sta v0
	ldlexvar 0x0, 0x1
	ldobjbyname 0x12, "morphT"
	sub2 0x14, v0
	sta v0
	ldlexvar 0x0, 0x1
	sta v1
	ldobjbyname 0x15, "reverseQuitDelta"
	callthis0 0x17, v1
	greatereq 0x19, v0
	sta v0
	callruntime.istrue 0x1a
	jnez jump_label_3
	ldlexvar 0x1, 0x0
	sta v0
	throw.undefinedifholewithname "MainPage"
	lda v0
	ldobjbyname 0x1b, "COMMIT_VELOCITY"
	neg 0x1d
	greatereq 0x1e, a3
	sta v0
jump_label_3:
	ldai 0x1
	sta v1
	ldai 0x0
	sta v2
	lda v0
	stlexvar 0x0, 0x0
	ldlexvar 0x0, 0x0
	sta v0
	throw.undefinedifholewithname "quit"
	lda v0
	callruntime.isfalse 0x1f
	jnez jump_label_4
	mov v0, v2
	jmp jump_label_5
jump_label_4:
	mov v0, v1
jump_label_5:
	ldlexvar 0x0, 0x1
	sta v2
	ldobjbyname 0x20, "animateMorphT"
	sta v3
	ldlexvar 0x0, 0x1
	sta v4
	ldobjbyname 0x22, "reverseMs"
	sta v5
	ldlexvar 0x0, 0x0
	sta v6
	throw.undefinedifholewithname "quit"
	lda v6
	callruntime.isfalse 0x24
	jnez jump_label_6
	ldlexvar 0x0, 0x1
	ldobjbyname 0x25, "morphT"
	sta v1
	jmp jump_label_7
jump_label_6:
	ldlexvar 0x0, 0x1
	ldobjbyname 0x27, "morphT"
	sub2 0x29, v1
	sta v1
jump_label_7:
	lda v5
	callthis1 0x2a, v4, v1
	sta v1
	ldlexvar 0x0, 0x0
	sta v4
	throw.undefinedifholewithname "quit"
	lda v4
	callruntime.isfalse 0x2c
	jnez jump_label_8
	ldlexvar 0x1, 0x0
	sta v4
	throw.undefinedifholewithname "MainPage"
	lda v4
	ldobjbyname 0x2d, "REVERSE_EASING"
	sta v4
	jmp jump_label_9
jump_label_8:
	ldexternalmodulevar 0x16
	sta v4
	throw.undefinedifholewithname "EASE_OUT_STR"
jump_label_9:
	definefunc 0x2f, &entry.src.main.ets.pages.MainPage&.#~@1>@f*#:(any,any,any), 0x0
	sta v5
	mov v7, v2
	mov v8, v0
	mov v9, v1
	mov v10, v4
	mov v11, v5
	lda v3
	callthisrange 0x30, 0x4, v7
	returnundefined
}
```

## startShrinkBack  (wujie.pa:154139)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#startShrinkBack(any a0, any a1, any a2, any a3, any a4) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldlexvar 0x0, 0x0
	sta v0
	lda a3
	stobjbyname 0x0, "shrinkPixmap", v0
	ldlexvar 0x0, 0x0
	ldobjbyname 0x2, "shrink"
	sta v0
	ldobjbyname 0x4, "start"
	sta v1
	ldlexvar 0x0, 0x0
	sta v2
	ldobjbyname 0x6, "getUIContext"
	callthis0 0x8, v2
	sta v2
	definefunc 0xa, &entry.src.main.ets.pages.MainPage&.#~@1>@12*#:(any,any,any), 0x0
	sta v3
	lda v1
	callthis3 0xb, v0, v2, a4, v3
	returnundefined
}
```

## reopenFromSquash  (wujie.pa:151388)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#reopenFromSquash(any a0, any a1, any a2) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x0, "playerOnTop"
	callthis0 0x2, v0
	callruntime.istrue 0x4
	jnez jump_label_0
	ldtrue
	jmp jump_label_1
jump_label_0:
	ldfalse
jump_label_1:
	callruntime.isfalse 0x5
	jnez jump_label_2
	returnundefined
jump_label_2:
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x6, "setMorph"
	sta v1
	ldexternalmodulevar 0x55
	sta v2
	throw.undefinedifholewithname "MorphStage"
	lda v2
	ldobjbyname 0x8, "ENTERING"
	sta v2
	ldexternalmodulevar 0x52
	sta v3
	throw.undefinedifholewithname "MorphDrive"
	lda v3
	ldobjbyname 0xa, "ANIM"
	sta v3
	lda v1
	callthis2 0xc, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0xe, "animateSquash"
	sta v1
	ldlexvar 0x1, 0x0
	sta v2
	throw.undefinedifholewithname "MainPage"
	lda v2
	ldobjbyname 0x10, "SQUASH_BACK_MS"
	sta v2
	ldexternalmodulevar 0x16
	sta v3
	throw.undefinedifholewithname "EASE_OUT_STR"
	definefunc 0x12, &entry.src.main.ets.pages.MainPage&.#~@1>@6*#:(any,any,any), 0x0
	sta v4
	ldai 0x1
	sta v5
	mov v6, v0
	mov v7, v5
	mov v8, v2
	mov v9, v3
	mov v10, v4
	lda v1
	callthisrange 0x13, 0x4, v6
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x15, "animateMorphT"
	sta v1
	ldlexvar 0x1, 0x0
	sta v2
	throw.undefinedifholewithname "MainPage"
	lda v2
	ldobjbyname 0x17, "ENTER_MS"
	sta v2
	ldexternalmodulevar 0x16
	sta v3
	throw.undefinedifholewithname "EASE_OUT_STR"
	definefunc 0x19, &entry.src.main.ets.pages.MainPage&.#~@1>@6*#^1:(any,any,any), 0x0
	sta v4
	mov v6, v0
	mov v7, v5
	mov v8, v2
	mov v9, v3
	mov v10, v4
	lda v1
	callthisrange 0x1a, 0x4, v6
	returnundefined
}
```

## squashDragStart  (wujie.pa:153690)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#squashDragStart(any a0, any a1, any a2) <static> {
	lda a2
	ldobjbyname 0x0, "animateSquash"
	sta v0
	ldlexvar 0x0, 0x0
	sta v1
	throw.undefinedifholewithname "MainPage"
	lda v1
	ldobjbyname 0x2, "SQUASH_BACK_MS"
	sta v1
	ldexternalmodulevar 0x16
	sta v2
	throw.undefinedifholewithname "EASE_OUT_STR"
	definefunc 0x4, &entry.src.main.ets.pages.MainPage&.#~@1>@8*#:(any,any,any), 0x0
	sta v3
	ldai 0x1
	sta v4
	mov v5, a2
	mov v6, v4
	mov v7, v1
	mov v8, v2
	mov v9, v3
	lda v0
	callthisrange 0x5, 0x4, v5
	lda a2
	ldobjbyname 0x7, "reverseDragStart"
	sta v0
	ldundefined
	sta v1
	lda v0
	callthis1 0x9, a2, v1
	returnundefined
}
```

## squashTapCatcher  (wujie.pa:153801)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#squashTapCatcher(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@7*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Column"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	tryldglobalbyname 0x7, "Column"
	sta v0
	ldobjbyname 0x8, "pop"
	callthis0 0xa, v0
	returnundefined
}
```

## pruneMorphStack  (wujie.pa:150683)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#pruneMorphStack(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a3
	stlexvar 0x0, 0x0
	ldexternalmodulevar 0x18
	sta v0
	throw.undefinedifholewithname "ExpandSnapshot"
	lda v0
	ldobjbyname 0x0, "morphStack"
	sta v0
	ldobjbyname 0x2, "length"
	sta v1
	wide.ldexternalmodulevar 0xaa
	sta v2
	throw.undefinedifholewithname "pruneScopeStack"
	definefunc 0x4, &entry.src.main.ets.pages.MainPage&.#~@1>@15*#:(any,any,any,any), 0x1
	sta v3
	lda v2
	callargs2 0x5, v0, v3
	sta v2
	ldai 0x0
	greater 0x7, v2
	jeqz jump_label_0
	wide.ldexternalmodulevar 0x9e
	sta v3
	throw.undefinedifholewithname "hilog"
	lda v3
	ldobjbyname 0x8, "warn"
	sta v4
	ldlexvar 0x2, 0x1
	sta v5
	throw.undefinedifholewithname "DOMAIN"
	ldlexvar 0x2, 0x2
	sta v6
	throw.undefinedifholewithname "TAG"
	lda.str "morph: 僵尸清理 "
	sta v7
	lda v2
	add2 0xa, v7
	sta v2
	lda.str " 条, 栈深 "
	add2 0xb, v2
	sta v2
	lda v1
	add2 0xc, v2
	sta v1
	lda.str " → "
	add2 0xd, v1
	sta v1
	lda v0
	ldobjbyname 0xe, "length"
	add2 0x10, v1
	sta v0
	lda.str ""
	add2 0x11, v0
	sta v0
	lda v4
	callthis3 0x12, v3, v5, v6, v0
jump_label_0:
	returnundefined
}
```

## enterGrabber  (wujie.pa:147149)
```
.function any &entry.src.main.ets.pages.MainPage&.#~@1>#enterGrabber(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.MainPage&.#~@1>@1a*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Column"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	tryldglobalbyname 0x7, "Column"
	sta v0
	ldobjbyname 0x8, "pop"
	callthis0 0xa, v0
	returnundefined
}
```

