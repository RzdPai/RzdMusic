# 搜索形变候选与验收说明

基线：ba99ace；开工 git status --short 为空。未修改任何 `*记忆.md`。

## 上游证据

行号全部指 `C:\Users\Administrator\Desktop\RzdProject\_recover\disasm\wujie.pa`，已读 `docs/upstream-search.md` 并继续追踪 builder。

- 首页 Search 419141–419151、搜索页 Search 503657–503667：同名 `geometryTransition(SEARCH_GEO_ID, { follow: true })`；ID `wanting_search_field` 在97960–97961。open/close闭包414784–414800仅写searchOpen；418596–418690互斥创建页面。搜索不是播放器的克隆矩形机制。
- SP_SEARCH是 `curves.interpolatingSpring(0,1,342,38)`（98192–98209）。400（98210–98211）为quiet/settle窗口，92721–92767可证不是动画duration。颜色仍settling时上游允许hard-cut，本候选不照搬该分支。
- 页面opacity进入200ms/Friction、退出120ms/Sharp（419363–419395）。
- HomeTab搜索行在Scroll首行411166–411260。Scroll只有onTouch/reportFingerTouch（413079–413150、413673–413681），未找到搜索框→按钮的滚动进度或阈值，不声称本仓映射来自上游。
- 搜索顶栏Row 56vp/space10/左右16加宽屏补偿（503024–503103、504382–504389、98056–98059），三块40vp MaterialGlass：返回、字段、来源（503110–503306）。字段height40（98104–98105）、图标16、清空17（97919–97947）、placeholder“艺人、歌曲或专辑”（97962–97963）。stackBuilder/bottomBuilder由HDS承载（502599–502643）。材质systemMaterialEffect、IMMERSIVE_GRADIENT_BLUR范围0–44（96481–96554）。

## 本仓实现与差异

`SearchExperience.ets` 是独立常驻搜索条，不复制播放器封面/背板、不读写PlayerExpandState。首页与搜索页共享同一个Row和TextInput，以UIContext.createAnimator逐帧写progress；同一矩形 x/y/width 按线性公式插值。属于上游共享元素的应用层等价做法，不声称使用同ID geometryTransition。

首页absolute offset由RecommendPage已有Scroller读数回传；本地新增设计：p=clamp(offset/96,0,1)，从0vp开始、96vp完全收为48vp按钮，回滚反向。首页字段高48vp、左右16vp、y=状态栏让位+64vp；宽从W-32插值到48，右缘始终W-16。只有一个字段节点，文字淡出并裁剪，无双元素切换。为该行给首页内容多留64vp。

打开时冻结当次源矩形：S=(W-16-homeWidth, topInset+64, homeWidth,48)；落点T=(56,topInset+8,max(48,W-128),48)。矩形为SearchExperience局部vp坐标；日志打印当次值。420ms cubic-bezier(0.23,1,0.32,1)是本仓有界动画，不冒充上游spring。关闭从当前progress反向到0，运行中返回可反转，重复关闭被抑制。

搜索内容使用独立HdsNavigation+NavPathStack，pushPath(animated=false)，反向完成后clear(false)，无系统推页。播放器isShowPlay期间整个搜索层Hidden，保留实例与结果、让主Navigation播放器可见；搜索active时仅在壳层阻止新底部上拉入口，未改播放器状态机。搜索进出期间settled=false，结果play入口拒绝操作。PC共享RecommendPage保持旧搜索路由和原留白，不把default新功能接到PC。HdsNavDestination开启systemMaterialEffect，返回/搜索自绘按钮覆盖顶部。保持输入框不重建，只有动画完成才可获焦，避免形变中弹键盘。默认不自动唤起键盘，点击输入框后输入。

样式是基础版：48vp字段、返回按钮、清空、搜索提交；使用现有card_background/background_secondary/sys字体/mini_bar_primary等深浅token。与上游40vp三玻璃块、来源按钮、40vp类型页签、延时350ms获焦不同，本候选优先满足连续进出和可用歌曲搜索。

SearchResults接LXMusicSDK，当前首页来源（qq映射tx）、第一页50首、source:songId去重与LazyForEach稳定key，初始/加载/空/错误/重试、请求代次隔离过期结果、点击复用OnlinePlayUtil。不含分页、联想、历史、类型页签。lxSearch新增第五参数throwOnError=false，仅新页面传true；旧调用仍吞异常返回空列表。网络/解析异常显示错误；provider主动返回空结果仍无法区分业务拒绝与无匹配，空态注明来源暂不可用可能。

## 验证与上机判据

- grep `RzdSearchMorph`：measure、open source/target、frame p/rect、finish。0/0.25/0.5/0.75/1应符合S+(T-S)*p；回程相反。应只有一个输入条轮廓，不发生硬推页或双条闪切。
- grep `RzdSearchResults`：start、stale、complete、failed、play。快速提交A/B只允许最后请求改变结果；离页后响应应丢弃。
- 首页滚动0、24、48、72、96vp分别检查宽度及文字连续淡出；96vp后48vp按钮可点击，回滚展开。首页切Tab、返回重建恢复滚动时需检查收缩同步。
- 浅/深主题检查输入框轮廓、文字与清空；键盘输入、回车/按钮提交、返回收键盘、动画中返回、搜索结果点播后播放器打开/关闭。
- 回归 mini-bar尾窗、squash落地、封面飞入、关闭链日志与进度条v19/v20。本轮不改这些实现。
- 无新增依赖，无新增权限；使用现有INTERNET。oh-package.json5/module.json5无变更。

官方接口检索：MCP `alliance/document/cn/harmonyos-references/ts-transition-animation-geometrytransition`（需animateTo、transition保留离场节点）、`alliance/document/cn/harmonyos-guides/arkts-shared-element-transition`、`alliance/document/cn/harmonyos-references/arkts-apis-uicontext-uicontext`。公开入口：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-transition-animation-geometrytransition 。不把预览器/编译当设备行为证明。

最终default assembleHap exit0，BUILD SUCCESSFUL in 35 s 895 ms。签名HAP 23,957,596 bytes，SHA256 `124F59C106A6E5FA62B59F22BAC589B4D3BF81EF0A0CDDAE9EAA95E8E15C510F`。git diff --check通过；新增两份ets无V1或router引用。保护区文件PlayerExpandState、PlaybackPage、ControlAreaComponent、mini-bar组件与runtime_diagnostics_v1均未修改；Index仅加搜索接线与搜索期间手势入口门。关闭后重开会重新请求旧关键词并重置结果滚动位置；播放器返回时保留的搜索实例/系统返回分发需设备验证。构建结果见 `search-build-final.log`（首轮失败见search-build.log：catch任意类型重抛触发ArkTS检查，已改明确Error）。mini-bar A–F静态检查通过，hdc targets为空；验证等级仅源码/编译/产物级，设备视觉与交互待验。
