# USB 独占输出（RzdMusic）

> 结论先行：**这条链路能不能用，取决于机型 ROM 是否把 USB 音频设备的访问权交给应用，以及这个 libmpv 构建里的
> `usb-exclusive` AO 是否被编进来**。代码这边保证：**做不到就明示、绝不假装成功**。

## 一、二进制事实（已核，不是猜测）

对 `features/player/src/main/libs/arm64-v8a/libmpv.so`（39.7 MB）做 ASCII 字符串检索：

| 字符串 | 命中 | 说明 |
| --- | --- | --- |
| `usb-exclusive` | 1 | 该构建**有** usb-exclusive AO |
| `Authorized USB Audio exclusive output` | 1 | AO 自己校验"是否已授权" |
| `USB exclusive %d Hz / %u-bit / %s; hardware volume %s` | 1 | 独占成功后会打印实际参数 |
| `USB strict PCM rejected precision loss: source=%u destination=%u` | 1 | 严格 PCM：拒绝精度损失 |
| `USB URB completion: endpoint=%u status=%d errors=%d` | 1 | AO 自己走 USB 传输 |
| `DAC does not support this exact format, or USB access failed.` | 1 | 失败原因文案 |
| `usb-exclusive-fd` | **0** | ❌ 没有这个选项（所以"把 fd 交给 mpv"是死路，已删） |
| `usb-exclusive-compatible` | **0** | ❌ 同上 |
| `audio-exclusive` | 1 | mpv 内置 `--audio-exclusive` |
| `ohaudio` | 11 | HarmonyOS 官方 AO |

⇒ **结论**：AO 自行打开 USB 设备并做传输，我们不传 fd；我们能做的是**授予应用 USB 设备访问权**，然后 `ao=usb-exclusive`。

## 二、应用侧实现（当前状态）

| 环节 | 实现 | 文件 |
| --- | --- | --- |
| 枚举 UAC 设备 | `usbManager.getDevices()`，按 `clazz === 1`（Audio Class）过滤，显示产品名 / VID / PID / UAC 版本 / 音频流接口数 | `common/musicbasic/.../UsbAudioService.ets` |
| 热插拔 | 本 SDK **无** `attach/detach` 事件 ⇒ 设置页打开时 2 秒轮询 + 手动「重新扫描」 | 同上 |
| 授权 | `hasRight` → 否就 `requestRight`（系统弹窗）；拿到就保持 `USBDevicePipe` 打开 | 同上 |
| 下发内核 | `MpvAudioEngine.setUsbMode('usb' \| 'ohaudio' \| 'off')`：`ao` + `audio-exclusive` + 严格 PCM（`audio-resample=no`、`audio-pitch-correction=no`） | `features/player/.../MpvAudioEngine.ets` |
| 生效校验 | 800ms 后读 mpv `current-ao`，不是独占就级联换 OHAudio 独占，再失败则回落 + Toast + 自动关开关 | `MediaService.tryUsbMode` |
| 换歌/焦点/掉线 | 换歌按上次成功的后端重下发；焦点恢复重下发；设备掉线自动关独占并回落 | `MediaService` |
| 诊断 | 设置页「USB 诊断」→ 日志输出 `ao驱动` / `current-ao` / `输出参数` | `MediaService.diagnoseUsb` |

日志关键字统一 `[RzdUsb]`。

## 三、真机验收清单（需要 USB DAC）

1. 插 DAC → 设置 → 播放设置：状态行出现 `已连接：<产品>（VID/PID，fd=N）· UAC2 · 音频流接口 1 个`；
2. 点「USB 诊断」，日志应有：
   ```
   [RzdUsb] 诊断 设备present=true authorized=true connected=true fd=N
   [RzdUsb] 诊断 ao驱动=…            ← 关键：看有没有 usb-exclusive
   [RzdUsb] 诊断 current-ao=ohaudio
   ```
3. 打开「USB 独占输出」（首次弹系统授权，允许）：
   ```
   [RzdUsb] 连接成功 fd=N
   [RzdUsb] 尝试 ao=usb-exclusive（严格 PCM）
   [RzdUsb] 模式 usb 校验 current-ao=usb-exclusive
   [RzdUsb] 实际输出参数 44100 Hz · s32 · 2ch
   ```
4. **bit-perfect 判定**：44.1k 曲目输出仍是 `44100 Hz`（没有变 48000）⇒ 成立；若是 48k ⇒ 仍在重采样。
5. 拔线：`[RzdUsb] 设备掉线 → 已关闭独占并回落普通输出` + Toast，音乐继续（普通输出）。
6. 重插 → 「重新扫描」→ 再开独占即恢复。
7. 切歌：`[RzdUsb] 换歌后重新应用独占 backend=…`，不应掉回普通输出。
8. 来电/其他 App 抢焦点后恢复：`[RzdUsb] 焦点恢复后重新应用独占 backend=…`。

## 四、可能的失败与对策

| 现象 | 含义 | 处理 |
| --- | --- | --- |
| `ao驱动` 里没有 `usb-exclusive` | 该 libmpv 未编入该 AO | 只能用 OHAudio 独占；UI 说明"该固件不支持" |
| `current-ao=ohaudio` 且 OHAudio 独占也失败 | ROM 不允许独占 | 明确提示并回落，不假装成功 |
| 有独占但无声音 | 授权/权限不足或 DAC 不支持该格式 | 看 `DAC does not support this exact format, or USB access failed.`，提示换格式/换线 |
| 采样率仍 48k | 系统重采样 | 检查严格 PCM 选项是否生效（`audio-resample=no`） |
