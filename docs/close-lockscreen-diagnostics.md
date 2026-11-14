# 关闭链与锁屏后台播放诊断

基线：dcaea94 / e81b6d3 / bba9105。开工仅有未跟踪 docs/upstream-search.md，保留。所有 *记忆.md 只读，禁止覆盖；指定 mini-bar 尾窗、morphSquashY 写入、MorphSolidSurface、openGeometryFinished 判据和进度条 v19/v20 保持不变。

## 持久诊断

MusicStoreService：KEY_RUNTIME_DIAGNOSTICS=runtime_diagnostics_v1，沿用 music_store Preferences；5000字符、整行截断、ISO时间戳。appendRuntimeDiagnostic 同时写 appendPlayLog 与控制台 RzdRuntimeDiag。XML Preferences putSync 只改内存，串行异步 flush 才落盘；失败进入内存日志/控制台，后续事件重试。进程被杀在 flush 完成前，最后事件仍可能缺失，不承诺崩溃同步刷盘。

SettingPage 与 SettingsDetailPage 的 refresh 将持久串接到现有运行日志尾部，标为“持久诊断（重启保留）”，原复制功能一并包含。仅加展示，无新增 UI 操作、依赖或权限。持久日志不进入备份业务设置的序列化。

官方依据（MCP 已取正文）：[通过用户首选项实现数据持久化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-preferences)，doc ID alliance/document/cn/harmonyos-guides/data-persistence-by-preferences。

## A 候选与修改

源码可达候选：snapshot 的 waitUntilRenderFinished 回调缺失或同步异常后，isClosing 已锁且 isShowPlay 未清；全屏 DIALOG 留在栈内。live 原先依赖时长+20ms收尾，且旧回调先判死亡再判代次，可能写坏共享状态。设备上实际命中哪一支，仍需持久日志证实。

唯一锚点 `RzdCloseChain`。2500ms 总截止远长于现有350ms快照动画和约460ms live反向动画，给渲染/调度留余量；不是系统超时承诺，也不代表动画固定耗时。正常由 shrink onDone / 几何 animator onFinish 收尾；异常截止才 path=fallback。关闭token和页面instance共同校验，重新打开撤销旧所有权；过期回调只记 stale-callback-dropped，释放晚到的无主 PixelMap。快照动画在页面卸载后由Index承载，因此不能onDisappear撤销正常快照结束。

风险：看门狗依赖主线程事件循环，无法救援主线程本身完全阻塞；路由移除API自身失败须依日志route-remove-failed调查。兜底可能跳过动画末尾，目标优先解除残留DIALOG和所有权。

## B 审计与修改

唯一锚点 `RzdLockScreenB`。MediaService 保留已有 prepared / playing / loadAsset / resume 调用，单曲循环统一 startPlayback，捕获 play Promise 拒绝；初始化等待 createSession / activate / 后台模式 / launch WantAgent 后再消费挂起装载。仅恢复曲目而不播放的 loadOnly 不申请长时任务。系统 paused 事件也取消任务，下一次 playing 再申请。EntryAbility.onBackground 原本就调用媒体服务，本轮加持久入口与错误日志。

BackgroundUtil 旧调用 fire-and-forget：并行 WantAgent 请求可重复 start，setting off 的 stop 可先于旧 start 完成。改为串行 reconcile，执行时使用最新 requested，在 WantAgent 返回后再检查；running 去重，失败不置 running，下次 playing / onBackground / setting 再试。监听 continuousTaskCancel 清 running，记录系统取消；订阅失败独立捕获，不阻塞 start。WantAgent 使用运行时 abilityInfo 的 bundle/module/name，START_ABILITY 单目标精确化；旧 START_ABILITIES 本身不判为无效。首次申请失败写 lxLastError 提示查看运行日志。

权限 KEEP_BACKGROUND_RUNNING、audioPlayback backgroundModes、getLockScreenPlay 缺省 true、AVSession.activate、setBackgroundPlayMode 均已存在，不能当成这轮新补的根因。检索仅 SettingsDetailPage 调 setter，备份/云同步业务序列化没有这个键；操作系统恢复整个 Preferences 仍可能保留 false，以持久 enabled 和 setting-write 区分。本次没有找到日间/网格/流光绘制与后台申请直接因果调用，不能将视觉改动定性为锁屏根因。

官方依据（MCP全文）：[后台播放场景](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avsession-background-scene)、[本地媒体会话常见问题](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avsession-faq-local)。要求音乐后台有会话与长时任务、播放重新申请/暂停取消、模式与开关一致。SDK continuousTaskCancel API15声明已核。候选风险：等待会话链增加冷启动延迟；取消订阅失败仍可播但缓存可能不知外部取消；只在生命周期/播放事件重试，不循环抢保活。

## 改动文件与唯一锚点

- features/player/src/main/ets/view/PlaybackPage.ets：RzdCloseChain / beginCloseGuard / finishCloseGuard / startGeoDriver optional onDone。
- products/default/src/main/ets/pages/Index.ets：cancelPendingCloseForOpen / route-remove source=Index。
- features/player/src/main/ets/model/MediaService.ets、util/BackgroundUtil.ets、products/default/src/main/ets/entryability/EntryAbility.ets：RzdLockScreenB。
- common/musicbasic/src/main/ets/util/MusicStoreService.ets：KEY_RUNTIME_DIAGNOSTICS / appendRuntimeDiagnostic / getRuntimeDiagnostics / event=setting-write。
- features/setting/src/main/ets/view/SettingPage.ets、SettingsDetailPage.ets：持久诊断（重启保留）。

依赖与权限：oh-package.json5、module.json5 均无修改。沿用 @kit.ArkData / @kit.AbilityKit / @kit.BackgroundTasksKit，以及已有 KEEP_BACKGROUND_RUNNING + audioPlayback。

## 设备验证

1. 打开播放页→关闭→触摸原页面并再次打开。grep RzdCloseChain，按 instance/close 分组：snapshot-request→snapshot-callback ok→shrink START→route-remove→shrink FINISH→reset；如回调缺失，应有 path=fallback watchdog-fire→route-remove→reset。旧回调只能 stale-callback-dropped，不能再改新会话。
2. 关闭后重启 App→设置→运行日志。确认“持久诊断（重启保留）”出现上一进程 ISO 时间戳和上述 instance/close。普通内存日志重启消失不影响此区。
3. 启播→锁屏/息屏。grep RzdLockScreenB，确认 lockscreen enabled=true、avsession=active、background-mode=ok、start-continuous(err=0)、onBackground(playing=true)。若 enabled=false，先查 setting-write；若 start-continuous 非0，按 stage/err 查申请；若 system-cancel，调查取消原因。仅所有申请成功仍停播时，才继续取系统策略、音频焦点或AVPlayer状态证据，不能凭“代码看着全”归因系统。

最终验证：default debug assembleHap exit 0，BUILD SUCCESSFUL in 37s973ms（全链首次通过56s178ms，最后追加Index实际移除日志后重跑通过）。日志 docs/close-lockscreen-build.log。git diff --check通过；tools/check-mini-bar.ps1 A–F全部通过；PlayerExpandState与ControlAreaComponent无差异。hdc list targets=[Empty]，仅源码/编译/产物级，未实机验证，不称已修复。签名产物 products/default/build/default/outputs/default/musichomesample-default-signed.hap。
