# 锁屏播放停止：按官方文档定位到的根因（音频焦点模式）

时间：2026-10-20 夜十。症状（甲方口径）：**锁屏后声音直接停了，进度也不走**（不是"进度走但没声"）。

## 1. 先排除的东西（官方三篇逐条核对，全部已满足）

依据（MCP 取正文，已落盘）：`docs/official-lockscreen-faq.md`、`docs/official-avsession-bg.md`、
`docs/official-continuous-task.md`、`docs/official-bgtask-ref.md`。

《本地媒体会话常见问题》「应用退至后台后音视频被强制暂停」的 5 条可能原因：

| 原因 | 本仓状态 |
| --- | --- |
| 未接入 AVSession | ✅ `createAVSession(ctx, 'SESSION_NAME', 'audio')` + `activate()` |
| 未申请 AUDIO_PLAYBACK 长时任务 | ✅ `KEEP_BACKGROUND_RUNNING` + `backgroundModes:["audioPlayback"]` + `startBackgroundRunning` |
| AVSession 实例被回收 | ✅ 会话是 `MediaService` 的**类成员**（单例持有） |
| 会话创建失败 | ✅ 有 `avsession=active activate=ok` 持久诊断 |
| `setBackgroundPlayMode` 与开关不一致 | ✅ 起播/退后台都下发，且跟随 `getLockScreenPlay()` |

⇒ 这 5 条都不是。继续往下找，问题落在**音频焦点模式**。

## 2. 根因（官方原文）

官方《处理音频焦点变化》（`alliance/document/cn/harmonyos-guides/audio-playback-concurrency`，已落
`docs/official-audio-focus.md`）：

- 焦点模式表：「SHARE_MODE（默认，推荐）……**不由系统进行焦点决策**，应用自行决定各流的播放、暂停、压低等操作」；
  「INDEPENDENT_MODE……**由系统进行焦点决策**，按应用间焦点策略管理」。
- 第 236 行：「**推荐使用共享焦点模式（SHARE_MODE）。应用可按需自行管控各流的播放、暂停、恢复等操作，
  避免系统默认策略（如 STOP）导致音频流无法恢复。**」
- 第 282 行：「独立焦点模式（INDEPENDENT_MODE）下，**音乐与音乐之间为停止策略**——后播的流会停止前播的流，
  且前播的流**不会收到恢复事件，无法自动恢复**。」
- 第 132 行（焦点策略表）：「先播音乐 / 后播音乐 ⇒ 后播音乐正常播放，**先播音乐停止播放**，UI 变成停止播放状态」。

本仓原实现（`MediaService.initAudioPlayer()`）：

```ts
const mixEnabled: boolean = MusicStoreService.getInstance().getAudioMix();
this.avPlayer.audioInterruptMode = mixEnabled ?
  audio.InterruptMode.SHARE_MODE : audio.InterruptMode.INDEPENDENT_MODE;   // ← 混音关（默认）时是 INDEPENDENT
```

⇒ 默认路径（混音关）把播放器放进了 **INDEPENDENT_MODE = 系统决策 + 停止策略 + 不恢复**。
一旦出现后续音乐类音频流（锁屏音/别的应用/自家的第二路流），AVPlayer 直接被**停止**：
声音没了、`currentTime` 不再前进 ⇒ 正好是"声音停了、进度也不走"，而且是**收不到恢复事件**的那种停。

## 3. 上游无界音乐怎么做的（照搬依据）

反汇编 `C:\Users\Administrator\Desktop\_wujie126\wujie126.pa`：

- 全文搜不到 `audioInterruptMode` / `InterruptMode`（只有 `StreamUsage`、录制用的 `audioRendererInfo`）
  ⇒ 上游**从不设焦点模式**，保持默认 SHARE_MODE。
- 上游的"混音"走的是另一条路：`entry.src.main.ets.player.AudioFocusPolicy`（约 312 万字节附近）

  ```
  applyBeforeStream():  wanted 为 false 直接返回; 已激活则返回;
                        否则 activateAudioSession({ concurrencyMode: CONCURRENCY_MIX_WITH_OTHERS })
  deactivate():         isAudioSessionActivated() ? deactivateAudioSession() : 返回
  ```

  （识别方式：`grep` `activateAudioSession` / `CONCURRENCY_MIX_WITH_OTHERS` / `AudioFocusPolicy`）

## 4. 本轮改动

`features/player/src/main/ets/model/MediaService.ets`

1. `initAudioPlayer()`：焦点模式**恒为 `SHARE_MODE`**（官方默认 + 上游做法），并落一条持久诊断
   `[RzdLockScreenB] audio-interrupt-mode=share (...)`。混音开关保持原样（`applyAudioSession` →
   `activateAudioSession(CONCURRENCY_MIX_WITH_OTHERS)`），与上游一致。
2. `stateChange` 的 `'stopped'` 分支：落持久诊断
   `event=stopped origin=<app|avsession|system> pos= bg= task req= run=`，并按官方要求**取消长时任务**。
   （原来是 `Logger.info`，hilog 拿不到 ⇒ 等于没有证据。）
3. `'paused'` 分支：`event=paused origin=...`（`app` = 应用内点的，`avsession` = 锁屏/耳机/播控，
   `system` = 不是我们调的）。
4. `onApplicationBackground()` / 新增 `onApplicationForeground()`：进出后台各记一条
   `bg-enter …` / `bg-leave(stall|keep) wall= pos-delta= …`；`EntryAbility.onForeground` 调用后者，
   并在回前台时按官方《后台播放》**补一次长时任务申请**（被打断/被取消后重启播放要重新申请）。
5. `BackgroundUtil`：新增 `snapshot()`（`task req= run=`）；`continuousTaskCancel` 落 `reason=<枚举>`。

## 5. 上机验证（一次复现即可定性）

播放 → 锁屏 10 秒 → 解锁 → 设置 → 运行日志 → 复制「持久诊断（重启保留）」段。

grep 关键字与判读：

| 日志 | 判读 |
| --- | --- |
| `audio-interrupt-mode=share` | 本轮修复已生效（旧构建没有这行） |
| `bg-leave(keep) pos-delta≈wall` | 后台确实在放 ⇒ 问题只剩锁屏卡片/播控那条线 |
| `bg-leave(stall) pos-delta≈0` + `event=paused origin=system` | 被系统暂停（焦点/管控），看同段有没有 `event=audioInterrupt` |
| `bg-leave(stall)` + `event=stopped origin=system` | 被焦点策略**停止**（本轮修复针对的正是这支，应不再出现） |
| `bg-leave(stall)` + 没有任何 event 行 + `task run=0` | 进程被冻结：查 `stop-continuous system-cancel reason=` |

## 6. 验证等级

`hdc list targets` = `[Empty]`（无设备）⇒ 仅 **编译级**（`assembleHap` BUILD SUCCESSFUL）、
**产物级**（hap 已上传 WebDAV）、**源码级**（`tools/check-mini-bar.ps1` A–F、`tools/check-lock-screen-play.ps1` A–D
全 PASS，`git diff --check` 干净）。**未上机，不称"已修复"**。
