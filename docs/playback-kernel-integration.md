# 播放内核接入清单（FFmpeg 已接 / mpv 待接）

> 目标：把「第三方解码内核」做成可替换插件。汽水分片 mp4、均衡器/升降调、将来的 USB 独占都挂在同一层。
>
> 现状（2026-10-31）：
> - **AVPlayer**：系统内核，默认路径，万能但不支持「分片 mp4 边下边播」和音效。
> - **FFmpeg（`@ohos/ijkplayer` 2.0.13，LGPLv2.1+）**：已接入，纯音频通道，负责汽水与「开启音效」的曲目。
> - **mpv**：接口与工厂已就位（`MpvAudioEngine` 为占位实现），**缺 `libmpv.so`(arm64) + `libmpvnative` NAPI 包装**。

## 1. 代码结构

| 文件 | 作用 |
| --- | --- |
| `features/player/src/main/ets/engine/AudioKernel.ets` | 接口 `AudioKernel`、`PlaybackKernelKind`、`AudioInterruptKind`、`kernelName()`、`logKernelSwitch()` |
| `features/player/src/main/ets/engine/IjkAudioEngine.ets` | FFmpeg 实现（`@ohos/ijkplayer` 的 `setAudioId()` 纯音频通道） |
| `features/player/src/main/ets/engine/MpvAudioEngine.ets` | **mpv 占位实现**（接口齐全、全部报「未接入」，文件头写了接入三步） |
| `features/player/src/main/ets/engine/KernelFactory.ets` | `preferredKernel()`（mpv 可用则 mpv，否则 FFmpeg）、`createKernel()`、`isMpvAvailable()` |
| `features/player/src/main/ets/model/MediaService.ets` | 唯一状态机；持有 `AudioKernel`，路由 play/pause/seek/位置/时长/音效 |

`MediaService` 已不引用任何具体内核类，接 mpv 时**它一行都不用改**。

## 2. 路线 A：FFmpeg（已落地，无需动作）

- 依赖：`features/player/oh-package.json5` → `"@ohos/ijkplayer": "2.0.13"`。
- 体积：HAP 25.6MB → 47.5MB（arm64 so 28.1MB；`products/default/build-profile.json5` 已用
  `buildOption.nativeLib.filter.excludes: ["**/x86_64/**"]` 剔掉 x86_64）。
- 音效：`IjkAudioEngine.applyTuning()` 组 `af` 链（`equalizer=f=<hz>:t=o:w=1:g=<dB>` + `rubberband=pitch=<2^(n/12)>`），
  `player.setOption('4', 'af', chain)` 在 `prepare` 前下发；不支持的 FFmpeg 构建只会警告。

## 3. 路线 B：mpv（待接，按下面做就能一次通）

### 3.1 拿到 `libmpv.so`（唯一的硬前置）

来源只有两个：
1. 作者仓 `Yebingiscn/libmpv-ohos-ErBW_s-5en` 的 **GitHub Actions artifact**（`libmpv_aarch64.zip` → `libmpv.so`，需登录）；
2. 自己在 **Linux/macOS/WSL** 里跑 `MPV_BUILD_ARCH=arm64 ./bundle.sh`（README 明确 Windows 不支持；本机未装 WSL/Docker）。

> 本机网络实测：`github.com` / `gitclone.com` / `kkgithub` / `ghproxy` 全部不通，所以**只能由外部提供二进制**。

### 3.2 放进工程

```
features/player/src/main/libs/arm64-v8a/libmpv.so          ← 新建目录
features/player/src/main/cpp/…                              ← NAPI 包装源码（CMake）
```

`features/player/build-profile.json5` 需要加：

```json5
"buildOption": {
  "externalNativeOptions": {
    "path": "./src/main/cpp/CMakeLists.txt",
    "arguments": "-DOHOS_STL=c++_shared -DCMAKE_BUILD_TYPE=RelWithDebInfo",
    "abiFilters": ["arm64-v8a"]
  }
}
```

### 3.3 NAPI 包装最小面（对齐 SweetVideo 的 `Index.d.ts`）

SweetVideo 默认分支 `sweet_video_rebase` 里 `entry/src/main/cpp/types/libmpvnative/Index.d.ts`（15.6KB）是现成参考。
最小可用集合：

```ts
// libmpvnative.so
create(): number;                                  // mpv_create + initialize，返回句柄
destroy(handle: number): void;                     // mpv_terminate_destroy
command(handle: number, args: string[]): void;     // mpv_command_string
setOption(handle: number, key: string, value: string): void;
observeProperty(handle: number, name: string, cb: (value: any) => void): void;
setWakeup(cb: () => void): void;                   // mpv_set_wakeup_callback
```

关键 mpv 侧属性/命令：

| 用途 | 调用 |
| --- | --- |
| 播放地址 | `command(['loadfile', url])` |
| 播放/暂停 | `setProperty('pause', 'no'/'yes')` |
| 跳转 | `command(['seek', seconds, 'absolute'])` |
| 音量 | `setProperty('volume', 0..100)` |
| 变速 | `setProperty('speed', rate)` |
| 均衡器 | `setProperty('af', 'equalizer=f=910:t=o:w=1:g=6')`（多段用逗号连） |
| 升降调 | `setProperty('af', 'rubberband=pitch=<ratio>')` |
| 进度 | `observeProperty('time-pos')` / `duration` |
| 完成 | `observeProperty('eof-reached')` |

### 3.4 接到 `MpvAudioEngine`（唯一要改的 ArkTS 文件）

```ts
static isAvailable(): boolean {
  // 改成真实探测：try { mpvNative.create(); return true } catch { return false }
}
```
其余方法把「日志 + 空实现」换成 NAPI 调用即可；`MediaService`、播放设置面板、内核选择器自动生效
（`preferredKernel()` 会返回 `MPV`）。

### 3.5 USB 独占（mpv 到位后可做）

来自 libmpv 那份 README 的事实：
- `ao=usb-exclusive`，配合 `usb-exclusive-fd` 传 USBManager 授权的文件描述符；
- 绕过 OHAudio/系统混音，**不改系统音量**；UAC1/UAC2 支持，严格模式下不做重采样；
- `usb-exclusive-compatible=yes` 才允许格式协商（float→int、立体声下混、48/96k 重采样）；
- `audio-spdif=dop` + `usb-exclusive-dsd-mode=dop` → DoP 输出；`native-dsd` → 原生 DSD；
- NAPI 侧还需 `checkUsbFileDescriptor(fd)`（返回 0 表示句柄有效）；
- 应用侧要做：探测后端选项、严格模式关音效/重采样、播放期间持有 descriptor、USB 断开回退普通输出。

## 4. 真机验收（两种内核都要过一遍）

见项目记忆 §137 的清单。关键日志：

- 内核选择：`[RzdKernel] A → B reason=…`、`[RzdTuning] engineMode=…`
- FFmpeg：`[RzdIjk] create/load/prepared/流信息/af=…`、`[播放] 汽水 → FFmpeg（ijk） 引擎 gen=…`
- 失败自愈：`[RzdIjk] 连续失败 N 次 → 已降级到系统播放器`、`[RzdIjk] 12s 未就绪（静默失败）→ 降级系统播放器`
- mpv（接入后）：`[RzdMpv] create/prepare/…`
