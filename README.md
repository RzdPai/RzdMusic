# RzdMusic

洛雪音乐的鸿蒙版-派音

## 构建与发布

一条命令走完「编译 → 上传 WebDAV → 发推送通知（只报构建完成，不发链接）」：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-and-publish.ps1
```

常用参数：

| 参数 | 作用 |
| --- | --- |
| `-Products default` | 只构建指定 product（默认 `default,pc`） |
| `-SkipBuild` | 跳过编译，直接上传已有产物 |
| `-SkipNotify` | 只构建 + 上传，不发推送 |
| `-DryRun` | 只打印将执行的动作，不上传不推送 |
| `-RemoteSuffix '-pr1'` | 旁支构建用（例如上游 PR 预览），远端名变成 `RzdMusic-default-pr1-signed.hap`，**不覆盖**正式包 |

### 环境要求

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `DEVECO_SDK_HOME` | `D:\command-line-tools\sdk` | HarmonyOS SDK |
| `RZD_JDK_HOME` | `C:\Users\Administrator\Tools\jdk\jdk-17.0.2` | **assembleHap 打包阶段需要 java**；缺了会 `spawn java ENOENT` |
| `HVIGOR_USER_HOME` | `<仓库>\..\.buildcache\hvigor` | 需可写 |
| `npm_config_cache` | `<仓库>\..\.buildcache\npm` | 需可写 |
| `RZD_REPO_ROOT` | 脚本上两级目录 | 指向另一个工作副本（如 upstream PR 的克隆）收集产物 |
| `RZD_DAV_BASE` | `https://pan.rzdpai.com/dav/` | WebDAV 上传目录 |
| `RZD_DAV_USER` / `RZD_DAV_PASS` | **必须自己设**（仓库里不留任何口令/账号） | WebDAV 账号；缺了脚本会在上传前显式报错 |
| `RZD_PUSH_BASE` | `https://api.chuckfang.com/RzdPai` | 推送服务 |
| `RZD_HVIGORW` | `D:\command-line-tools\bin\hvigorw.bat` | hvigor 启动器 |

### 上传行为

1. **上传前先查同名、有同名先删**：`PROPFIND Depth:0` → 存在则 `DELETE`（期望 204）→ 再 `PUT`。
   PUT 本身是覆盖语义，显式 DELETE 是为了避免旧对象在部分 WebDAV 网盘上残留导致配额/列表不刷新。
   PROPFIND 异常时只告警不阻断（PUT 至少能覆盖）。
2. **远端固定文件名**（不带时间戳，便于覆盖更新）：
   - `RzdMusic-default-signed.hap` —— 手机/平板/折叠
   - `RzdMusic-pc-signed.hap` —— PC / 2in1
3. 每个 product 只取该 product `build/` 下**最新的 `*-signed.hap`**。
4. 上传完成（或失败）后发一条推送；正文形如：
   `已上传：RzdMusic-default-signed.hap、RzdMusic-pc-signed.hap` + `合计 35.3 MB`

### 推送服务的两个坑

- **限流 3 秒 1 条**（非会员），返回 `{"status":429,...,"msg":"非会员用户 3 秒内只能发送 1 条消息"}`，脚本里多条产物之间已留间隔。
- **正文里不要放下载直链**：服务端是路径段形式 `/<用户>/<标题>/<正文>`，链接含 `/` 与 `?`，
  普通 `EscapeDataString` 后 `/` 会被当成路径分隔符 → Tomcat 直接 `400 Bad Request`。
  （实测需要把 `%2F` 再编码成 `%252F` 才能发出去；现在的通知不放链接，所以用不到这个绕法。）

## 播放页（全模态 + 流光背景）

- **全模态**：壳层用 `bindContentCover($$appState.isShowPlay, PlaybackPageCoverContent())`
  挂播放页（`products/default`）。不要再换回 `bindSheet` —— 半模态自带 sheet 容器
  （顶部露底、拖动条、圆角、遮罩都由系统接管），会把播放页自己的下滑关闭手势和沉浸背景
  削掉一层，窗口尺寸变化时还得靠 sheet 重新适配。PC 形态本来就是在根 `Stack` 里做覆盖层。
- **流光背景**：设置 →「播放设置」→「播放页流光背景」开关（持久化 key `playback_flow_light`）。
  ⚠️ 设置 tab 实际渲染的是 `SettingsDetailPage`（左侧分类 + 右侧详情），
  `SettingPage.ets` 只是旧版单页实现，加设置项要加在 `SettingsDetailPage` 里。
  实现用 HDS `hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT` 着色器
  （`visualEffect(new HdsEffectBuilder().shaderEffect({...}).buildEffect())`），
  颜色**不是写死的**：`PlaybackPage` 从封面动态取色，经 `ColorConversion.vividFlowColors`
  把主色拉饱和度/亮度后得到 `colorSource`，再派生一个同色系暗色当 `colorTarget`，
  换歌时通过 `ShaderEffectController.setEffectParams()` 更新 uniform（不重建着色器，流光不重启）。
  开关关闭时跳过解封面这一步；打开开关时会为当前曲目补取一次色。
  排查日志：`grep 'flow light tint updated'` / `'flow light colors applied'`。

## 酷我（kw）榜单接口

榜单列表和榜单歌曲**都换成不需要签名的老 PC 接口**，元力音源插件同款：

| 用途 | 接口 |
| --- | --- |
| 榜单列表（含封面） | `http://wapi.kuwo.cn/api/pc/bang/list`，递归取 `child[].child[]` 里带 `sourceid` 的节点 |
| 榜单歌曲 | `http://kbangserver.kuwo.cn/ksong.s?from=pc&fmt=json&pn=0&rn=80&type=bang&data=content&id=<sourceid>&show_copyright_off=0&pcmp4=1&isbang=1&userid=0&httpStatus=1` |

- **不要**再回到 `wbd.kuwo.cn/api/bd/bang/bang_info`（AES + md5 签名那套）：AppId 已被封，
  返回 `{"code":10004,"msg":"AppId错误"}` —— 这就是「酷我排行榜完全不可用」的原因。
- 也**不要**再用写死的 `boardIdList('kw')`：那张表照着老版 PC 页面抄的，酷我换版后大面积失效。
  现在是实时列表优先、写死表兜底（见 `MusicDataService.boardsWithCovers`）。
- 榜单列表有会话级缓存（`kwBangsCache`），切平台来回点不会反复打网络。

## 本地构建

```powershell
$env:DEVECO_SDK_HOME='D:\command-line-tools\sdk'
$env:HVIGOR_USER_HOME='C:\Users\Administrator\Desktop\RzdProject\.buildcache\hvigor'
$env:npm_config_cache='C:\Users\Administrator\Desktop\RzdProject\.buildcache\npm'
$env:JAVA_HOME='C:\Users\Administrator\Tools\jdk\jdk-17.0.2'
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
D:\command-line-tools\bin\hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

## 回归单测（Node，无需设备）

```powershell
node features/player/src/test/md5_test.js          # 42 项：桥内 MD5 与 node:crypto 逐条比对
node features/player/src/test/bridge_init_test.js  # 10 项：桥初始化状态机（代际/闩锁/降级）
```
