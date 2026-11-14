# 注入快通道（Phase 0.5）工程说明 —— 2026-11-14

> 对应提交：`5dddbd9`（feat(source): Phase 0 + 0.5 —— 脚本能力探测 + 注入改单请求）
> 对应交接书：`RzdMusic-dual-engine-handover-20261114.md` 的 Phase 0 / Phase 0.5
> 本文只讲**已经落地的这一段**，以及「怎么判断它有没有生效、坏了怎么退」。

---

## 1. 解决的是什么

旧注入路径（仍保留，作为兜底）：

```
载荷 JSON  ──base64(+33%)──▶  按 20000 字符切片  ──▶  N 次串行 runJavaScript
1.6 MB 脚本                 ≈ 2.13 MB                ≈ 114 次跨 ArkTS↔WebView 往返
```

114 次串行往返是**冷启动卡顿的确定来源**，且与用哪个 JS 引擎无关（WebView 路径同样受害）。

新路径（默认）：

```
原生 ──一条极短 JS──▶ window._lx_init_fetch(gen)
桥   ──fetch(虚构地址)──▶ onInterceptRequest ──setResponseData(ArrayBuffer)──▶ 原始 JSON
```

⇒ **1 次往返，体积 2.13 MB → 1.6 MB**。

虚构地址是 `https://rzd-lx-init.invalid/init.json?gen=N`（`.invalid` 是 RFC 2606 保留域，
永远不会真的出网，一律由应用内拦截应答）。

---

## 2. 时序（含三重兜底）

```
onPageEnd ──▶ injectScript(gen, json)
                 │
                 ├─ pinChunked? 或 设置=chunked? ──▶ 分片通道（今天的行为）
                 │
                 └─ 快通道
                      │ runJs(`window._lx_init_fetch(gen)`)
                      │ armFetchAckWatch(1500ms)      ← 只看「载荷是否到手」
                      │ armReadyWatchdog(8~30s)       ← 只看「有没有 init 事件」
                      ▼
                   桥 fetch → onInterceptRequest → 整包 JSON
                      │
                      ├ 先回 initFetchAck  ────────▶ 原生撤掉 ack 计时器（此后绝不再回退）
                      └ 再 JSON.parse → _lx_init(gen, data) → 脚本开始初始化
                                                              │
                                                              └─▶ init 事件（带 injectMs）
```

回退的三个触发点（任一命中就退回分片，功能不受影响、只是没提速）：

| # | 触发 | 判据 |
| --- | --- | --- |
| 1 | 桥报 `initFetchError` | fetch 被拦/CORS、HTTP 非 200、JSON 解析失败 |
| 2 | `initFetchAck` 1.5 s 未到 | 通道不通、请求挂住 |
| 3 | 看门狗：注入后**完全没有** init | 本次会话钉回分片（`pinChunked`，换脚本解除） |

> ★★ **兜底只认「载荷是否到手」，绝不认「脚本是否已就绪」。**
> 桥拿到整包后**先回 ack 再解析**。因为脚本自身启动期的联网校验可能好几秒，
> 若拿「是否 ready」当通道判据 ⇒ 误判成失败 ⇒ 二次注入 ⇒ `_lx_init` 同代际重入
> 重置状态、打断正常初始化。**这正是交接书 §8.2 第 10 项「冷启动脚本双注入」的成因。**

---

## 3. 代码落点

| 文件 | 改动 |
| --- | --- |
| `features/player/src/main/ets/source/ScriptProbe.ets` | **新增** 140 行：`probeScript()` / `canRunWithoutWebView()` / `formatProfile()`，纯静态文本扫描 |
| `features/player/src/main/ets/source/LXSourceEngine.ets` | `injectScript` 拆成 `injectScriptFast` / `injectScriptChunked`；新增 `handleInterceptRequest` / `buildInitResponse` / `armFetchAckWatch` / `fallbackToChunks`；`init` 事件日志加 `injectMs`；新增消息 `initFetchAck` / `initFetchError` |
| `features/player/src/main/resources/rawfile/lx_bridge.html` | **新增**（只做加法，旧分片协议一字未改）：`_lx_init_fetch` / `_lx_init_apply` / `LX_INIT_URL` / `lxFetchGen` |
| `common/musicbasic/src/main/ets/util/MusicStoreService.ets` | 新键 `lx_engine_mode_v1`（auto/webview/quickjs）、`lx_inject_mode_v1`（auto/chunked）+ 两对 get/set |

---

## 4. 官方 API 约束（照抄，别再试错）

1. `setResponseData(data)` 的 `number` = 文件句柄，**由系统的 Web 组件负责关闭**，应用侧别 close。
2. 顺序：`setResponseData` → `setResponseMimeType` → `setResponseEncoding` → `setResponseHeader`
   → `setResponseCode` → `setReasonMessage` → **最后** `setResponseIsReady(true)`。顺序错会让同步 XHR 阻塞。
3. **不能用 `setResponseBody`**：它 @since 26.0.1，工程 `compatibleSdkVersion` 是 24
   （编译期不报错、装 24 设备才炸）。
4. 非目标请求**返回 `null` 放行**（ArkTS 允许；先例 `RzdVideo/entry/.../WebSniffer.ets:78`）。
5. 跨域：页面源是 `resource://rawfile`，响应头要带 `Access-Control-Allow-Origin`。
6. 桥里 fetch **不要**加 `cache:'no-store'`（会带出 `Cache-Control` 请求头 → 非简单请求 →
   触发 CORS 预检 → 还要应答 `Allow-Headers`，白多一个失败点）。URL 带 `?gen=` 已天然不重复。
7. 用 `ArrayBuffer` 而非文件句柄：载荷本来就在内存（`currentInitJson`），落盘再读属于多余 I/O。

---

## 5. 怎么判断生效（设置 → 运行日志）

**生效（快通道）**：

```
引擎 脚本能力 dom=false crypto=false zip=false 可无 DOM 运行=true lxEngineMode=auto
引擎 注入(快通道) gen=1 载荷=1663xxxB
引擎 快通道载荷到达 gen=1 1663xxxB
引擎 init 事件 status=true gen=1 pageGen=1 injectMs=NNNN
```

**自动兜底（功能正常、没提速）**：

```
引擎 快通道失败 gen=1 msg=...
引擎 快通道回退分片(1/2) 原因=桥上报: ...
引擎 注入分片数=NN gen=1
```

`msg=` 是关键线索：若是 CORS/网络类，可把快通道换成 `<script src>` 方案（classic script
不受 CORS 限制），改动只在桥与 `buildInitResponse` 两处。

**验收线**（交接书 §9）：同一音源冷启动一次，`injectMs` 相对旧包下降 ≥ 60%。

---

## 6. 怎么强制退回旧通道（免开新包）

三档，优先级从高到低：

1. **自动**：上面三个回退触发点，用户无感。
2. **本次会话**：看门狗一旦判定「注入后完全没有 init」，自动钉 `pinChunked`（换脚本解除）。
3. **持久**：设置里把注入通道设成 `'chunked'` —— 目前**没有做 UI**，需通过
   `MusicStoreService.getInstance().setLxInjectMode('chunked')` 下发（开发者选项留白，见 §8）。

---

## 7. 验证等级

| 项 | 状态 |
| --- | --- |
| 编译 | ✅ BUILD SUCCESSFUL；改的 3 个文件 0 告警 |
| 桥 JS 语法 | ✅ 抽 `<script>` 块 `node --check` |
| 桥协议时序 | ✅ node 沙箱 4 场景：正常 ack→init、过期代际丢弃、fetch 失败上报、坏 JSON 上报 |
| 探测逻辑 | ✅ node 对照 10 用例；1.45 MB / 4 ms |
| 包内自检 | ✅ 解 HAP 后 `modules.abc` 含新特征串，`lx_bridge.html` 含 `_lx_init_fetch` |
| **真机** | ❌ **未验**（本机无 hdc 设备、无模拟器） |

---

## 8. 有意留白

1. **设置页开发者开关 UI**：自动兜底已保证不会困在坏包，UI 只影响可诊断性。要做就照交接书
   Phase 0 第 3 条（连点版本号 5 次），接现成的 `setLxEngineMode` / `setLxInjectMode`。
2. **`MusicFreeEngine` 没改**：插件多为几十 KB（`MF_CHUNK_SIZE=20000` ⇒ 1~3 片），
   收益远小于 LX 的 114 片。要改时照本套抄。
3. **QuickJS 未接入**：等交接书 §0.1 两条砍线的真机数据（内存差 < 30 MB、`needsDom` 占比 > 50%）。
