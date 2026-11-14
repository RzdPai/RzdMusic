# 无界 1.2.4 · 播放页进度条（scrubber）反编译参考

> 来源 `_recover/disasm/wujie.pa`。**只参考数值与效果**，结构按本仓。
> 用户口径：「无界播放页进度条比派音更粗，而且拉进度条时还会进一步变粗」。

## PlayerPage.scrubber (wujie.pa:177708)
```
.function any &entry.src.main.ets.pages.PlayerPage&.#~@0>#scrubber(any a0, any a1, any a2, any a3) <static> {
	newlexenv 0x1
	lda a2
	stlexvar 0x0, 0x0
	ldundefined
	stricteq 0x0, a3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1, "observeComponentCreation2"
	sta v1
	definefunc 0x3, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x4, "Column"
	sta v3
	lda v1
	callthis2 0x5, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x7, "observeComponentCreation2"
	sta v1
	definefunc 0x9, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#^1:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0xa, "Stack"
	sta v3
	lda v1
	callthis2 0xb, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0xd, "observeComponentCreation2"
	sta v1
	definefunc 0xf, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#^2:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x10, "Progress"
	sta v3
	lda v1
	callthis2 0x11, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x13, "observeComponentCreation2"
	sta v1
	definefunc 0x15, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#^3:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x16, "Slider"
	sta v3
	lda v1
	callthis2 0x17, v0, v2, v3
	tryldglobalbyname 0x19, "Stack"
	sta v0
	ldobjbyname 0x1a, "pop"
	callthis0 0x1c, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x1e, "observeComponentCreation2"
	sta v1
	definefunc 0x20, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#^4:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x21, "Row"
	sta v3
	lda v1
	callthis2 0x22, v0, v2, v3
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x24, "observeComponentCreation2"
	sta v1
	definefunc 0x26, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#^5:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x27, "Text"
	sta v3
	lda v1
	callthis2 0x28, v0, v2, v3
	tryldglobalbyname 0x2a, "Text"
	sta v0
	ldobjbyname 0x2b, "pop"
	callthis0 0x2d, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x2f, "observeComponentCreation2"
	sta v1
	definefunc 0x31, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#^6:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x32, "Blank"
	sta v3
	lda v1
	callthis2 0x33, v0, v2, v3
	tryldglobalbyname 0x35, "Blank"
	sta v0
	ldobjbyname 0x36, "pop"
	callthis0 0x38, v0
	ldlexvar 0x0, 0x0
	sta v0
	ldobjbyname 0x3a, "observeComponentCreation2"
	sta v1
	definefunc 0x3c, &entry.src.main.ets.pages.PlayerPage&.#~@0>@f*#^7:(any,any,any,any,any), 0x2
	sta v2
	tryldglobalbyname 0x3d, "Text"
	sta v3
	lda v1
	callthis2 0x3e, v0, v2, v3
	tryldglobalbyname 0x40, "Text"
	sta v0
	ldobjbyname 0x41, "pop"
	callthis0 0x43, v0
	tryldglobalbyname 0x45, "Row"
	sta v0
	ldobjbyname 0x46, "pop"
	callthis0 0x48, v0
	tryldglobalbyname 0x4a, "Column"
	sta v0
	ldobjbyname 0x4b, "pop"
	callthis0 0x4d, v0
	returnundefined
}
```

## trackThickness 现场（197330-197430）
```
197330| 	sta v0
197331| 	ldai 0x0
197332| 	sta v1
197333| 	tryldglobalbyname 0x0, "Slider"
197334| 	sta v2
197335| 	ldobjbyname 0x1, "create"
197336| 	sta v3
197337| 	createobjectwithbuffer 0x3, { 8 [ string:"value", null_value:0, string:"min", i32:0, string:"max", null_value:0, string:"style", null_value:0, ]}
197338| 	sta v4
197339| 	ldlexvar 0x0, 0x0
197340| 	ldobjbyname 0x4, "displayMs"
197341| 	definepropertybyname 0x6, "value", v4
197342| 	ldlexvar 0x0, 0x0
197343| 	ldobjbyname 0x8, "durMs"
197344| 	sta v5
197345| 	lda v1
197346| 	greater 0xa, v5
197347| 	jeqz jump_label_0
197348| 	ldlexvar 0x0, 0x0
197349| 	ldobjbyname 0xb, "durMs"
197350| 	sta v0
197351| jump_label_0:
197352| 	ldai 0x7
197353| 	sta v5
197354| 	ldai 0xc
197355| 	sta v6
197356| 	lda v0
197357| 	definepropertybyname 0xd, "max", v4
197358| 	tryldglobalbyname 0xf, "SliderStyle"
197359| 	ldobjbyname 0x10, "InSet"
197360| 	definepropertybyname 0x12, "style", v4
197361| 	lda v3
197362| 	callthis1 0x14, v2, v4
197363| 	tryldglobalbyname 0x16, "Slider"
197364| 	sta v0
197365| 	ldobjbyname 0x17, "width"
197366| 	sta v2
197367| 	lda.str "100%"
197368| 	sta v3
197369| 	lda v2
197370| 	callthis1 0x19, v0, v3
197371| 	tryldglobalbyname 0x1b, "Slider"
197372| 	sta v0
197373| 	ldobjbyname 0x1c, "trackThickness"
197374| 	sta v2
197375| 	ldlexvar 0x0, 0x0
197376| 	ldobjbyname 0x1e, "scrubbing"
197377| 	callruntime.isfalse 0x20
197378| 	jnez jump_label_1
197379| 	mov v5, v6
197380| jump_label_1:
197381| 	lda v2
197382| 	callthis1 0x21, v0, v5
197383| 	tryldglobalbyname 0x23, "Slider"
197384| 	sta v0
197385| 	ldobjbyname 0x24, "trackColor"
197386| 	sta v2
197387| 	tryldglobalbyname 0x26, "Color"
197388| 	ldobjbyname 0x27, "Transparent"
197389| 	sta v3
197390| 	lda v2
197391| 	callthis1 0x29, v0, v3
197392| 	tryldglobalbyname 0x2b, "Slider"
197393| 	sta v0
197394| 	ldobjbyname 0x2c, "selectedColor"
197395| 	sta v2
197396| 	tryldglobalbyname 0x2e, "Color"
197397| 	ldobjbyname 0x2f, "Transparent"
197398| 	sta v3
197399| 	lda v2
197400| 	callthis1 0x31, v0, v3
197401| 	tryldglobalbyname 0x33, "Slider"
197402| 	sta v0
197403| 	ldobjbyname 0x34, "blockColor"
197404| 	sta v2
197405| 	tryldglobalbyname 0x36, "Color"
197406| 	ldobjbyname 0x37, "Transparent"
197407| 	sta v3
197408| 	lda v2
197409| 	callthis1 0x39, v0, v3
197410| 	tryldglobalbyname 0x3b, "Slider"
197411| 	sta v0
197412| 	ldobjbyname 0x3c, "blockSize"
197413| 	sta v2
197414| 	createobjectwithbuffer 0x3e, { 4 [ string:"width", i32:0, string:"height", i32:0, ]}
197415| 	sta v3
197416| 	lda v2
197417| 	callthis1 0x3f, v0, v3
197418| 	tryldglobalbyname 0x41, "Slider"
197419| 	sta v0
197420| 	ldobjbyname 0x42, "enabled"
197421| 	sta v2
197422| 	ldlexvar 0x0, 0x0
197423| 	ldobjbyname 0x44, "durMs"
197424| 	sta v3
197425| 	lda v1
197426| 	greater 0x46, v3
197427| 	sta v1
197428| 	lda v2
197429| 	callthis1 0x47, v0, v1
197430| 	tryldglobalbyname 0x49, "Slider"
```

## 可能与"拖动变粗"相关的常量/函数
```
1861: 2698 0xd7f7f { 56 [ string:"PlayerPage", string:"closeWithAnimation", string:"schedulePublishRetry", string:"pressAnim", string:"aboutToAppear", string:"showChrome", string:"hideChrome", string:"startIdle", string:"availableQualities", string:"motionLayer", string:"immersiveLayer", string:"floatingCover", string:"metaRow", string:"floatingMeta", string:"topBar", string:"scrubber", string:"transport", string:"settingsTitle", string:"onClose", string:"queueTitle", string:"qualityTitle", string:"lyricmatchTitle", string:"versionTitle", string:"versionContent", string:"onPick", string:"paramsLambda", string:"addplaylistTitle", string:"addplaylistContent", string:"lyricmatchContent", string:"queueSheetContent", string:"lyricsetTitle", string:"lyricoffsetTitle", string:"lyricoffsetContent", string:"lyricsetContent", string:"floatMenu", string:"immersiveMenu", string:"lyricAlignMenu", string:"lyricFontMenu", string:"offsetBlock", string:"offsetPill", string:"onPillTouch", string:"qualitySheetContent", string:"forEachItemGenFunction", string:"settingsSheet", string:"cacheQualityList", string:"settingsMain", string:"sleepTitle", string:"sleepContent", string:"customSleepTitle", string:"customSleepSheet", string:"startSleepTick", string:"settingRow", string:"playerPane", string:"wideLyricsPane", string:"initialRender", string:"setupExpandTransition", ]}
175736: .function any &entry.src.main.ets.pages.PlayerPage&.#~@0>#pressAnim(any a0, any a1, any a2, any a3, any a4) <static> {
182007: ldobjbyname 0x0, "pressAnim"
182053: ldobjbyname 0x0, "pressAnim"
168745: lda.str "scrubbing"
168752: stobjbyname 0x140, "__scrubbing", v1
170056: ldobjbyname 0x128, "__scrubbing"
174951: stobjbyname 0xa, "scrubbing", a2
177750: tryldglobalbyname 0x16, "Slider"
197333: tryldglobalbyname 0x0, "Slider"
197358: tryldglobalbyname 0xf, "SliderStyle"
197363: tryldglobalbyname 0x16, "Slider"
1861: 2698 0xd7f7f { 56 [ string:"PlayerPage", string:"closeWithAnimation", string:"schedulePublishRetry", string:"pressAnim", string:"aboutToAppear", string:"showChrome", string:"hideChrome", string:"startIdle", string:"availableQualities", string:"motionLayer", string:"immersiveLayer", string:"floatingCover", string:"metaRow", string:"floatingMeta", string:"topBar", string:"scrubber", string:"transport", string:"settingsTitle", string:"onClose", string:"queueTitle", string:"qualityTitle", string:"lyricmatchTitle", string:"versionTitle", string:"versionContent", string:"onPick", string:"paramsLambda", string:"addplaylistTitle", string:"addplaylistContent", string:"lyricmatchContent", string:"queueSheetContent", string:"lyricsetTitle", string:"lyricoffsetTitle", string:"lyricoffsetContent", string:"lyricsetContent", string:"floatMenu", string:"immersiveMenu", string:"lyricAlignMenu", string:"lyricFontMenu", string:"offsetBlock", string:"offsetPill", string:"onPillTouch", string:"qualitySheetContent", string:"forEachItemGenFunction", string:"settingsSheet", string:"cacheQualityList", string:"settingsMain", string:"sleepTitle", string:"sleepContent", string:"customSleepTitle", string:"customSleepSheet", string:"startSleepTick", string:"settingRow", string:"playerPane", string:"wideLyricsPane", string:"initialRender", string:"setupExpandTransition", ]}
2025: 2851 0xe1f44 { 1 [ string:"ScrubGesture", ]}
4252: 607 0xcf6c4 { 26 [ string:"topBarH", i32:44, string:"gapSwiper", i32:48, string:"gapScrub", i32:28, string:"playSize", i32:72, string:"seekSize", i32:32, string:"sideSize", i32:22, string:"titleSize", i32:20, string:"artistSize", i32:14, string:"favSize", i32:24, string:"metaGap", i32:50, string:"bottomGap", i32:65, string:"lyricScale", i32:1, string:"total", null_value:0, ]}
4267: 620 0xcf7ce { 26 [ string:"topBarH", i32:36, string:"gapSwiper", i32:20, string:"gapScrub", i32:14, string:"playSize", i32:52, string:"seekSize", i32:28, string:"sideSize", i32:20, string:"titleSize", i32:18, string:"artistSize", i32:12, string:"favSize", i32:20, string:"metaGap", i32:28, string:"bottomGap", i32:36, string:"lyricScale", f64:0.86, string:"total", null_value:0, ]}
```
