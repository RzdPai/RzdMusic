# MCP 清单：HarmonyOS 开发者知识库（官方文档检索）

> 目录：工程根 `RzdMusic\`
> 用途：把「随手能查鸿蒙官方文档」这件事固定下来——动画/组件/API 语义先查再写。
> 记录时间：2026-09-25（本机实测通过，工具清单与入参 schema 为实测原文）

---

## 1. 标准配置（任何支持 MCP 的客户端都能用）

```json
{
  "mcpServers": {
    "harmonyos_developer_knowledge": {
      "type": "http",
      "url": "https://connect-api.cloud.huawei.com/api/developerknowledge/mcp"
    }
  }
}
```

同一份内容也放在 `tools\mcp.json`，DevEco Studio / Cursor / Claude Desktop 等直接指向它即可。

**装到哪儿：**

| 客户端 | 放哪里 |
| --- | --- |
| Claude Desktop | `%APPDATA%\Claude\claude_desktop_config.json` 的 `mcpServers` 段 |
| Cursor | `.cursor\mcp.json`（项目级）或全局配置的 `mcpServers` 段 |
| DevEco Studio | 设置 → 工具 → MCP / AI 助手（按版本入口不同），填上面的 URL |
| Claude Code | `claude mcp add --transport http harmonyos_developer_knowledge <url>` |

## 2. DSH 侧已经接好（本项目当前会话的用法）

DSH（DeepSeek Harness）0.1.5-rc.2 **自带 MCP 客户端插件** `@deepseek-ai/dsh-mcp-client`，
已把它写进本项目使用的 agent preset：

```
C:\Users\Administrator\.dsh\.agent-presets\rzdmusic\agent.cordis.yml
```

```yaml
- id: mcp-harmonyos-knowledge
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: harmonyos_developer_knowledge
    transport: streamable-http          # 注意：DSH 用的是 transport，不是 type: "http"
    url: https://connect-api.cloud.huawei.com/api/developerknowledge/mcp
    toolCallTimeoutMs: 60000
```

接入后，模型侧直接出现两个**原生工具**（Claude Code / Codex 同款命名）：

- `mcp__harmonyos_developer_knowledge__searchDocuments` —— 关键词检索，返回片段 + 文档标识 `parent`
- `mcp__harmonyos_developer_knowledge__getDocumentsById` —— 按 `parent` 取全文（一次 1~10 篇）

> ⚠️ **生效时机**：preset 是启动时装载的。改完这个 yml 之后，**新开一个会话**（或重启 `dsh web`）才稳。
> 改坏了也不会把 harness 拖死：`failOnStartupError` 默认 `false`，端点不通只是这两个工具不出现 + 一条 error 日志。
> 校验过 YAML 可解析、row 结构正确（`node + js-yaml` 实测 `PARSE-OK`；`!!js` 标签需自定义 Type 才能用 js-yaml 解析）。

## 3. 两个工具的入参（实测 schema，原文）

```jsonc
// searchDocuments
{ "SearchDocumentsReq": { "query": "搜索词" } }

// getDocumentsById
{ "GetDocumentsByIdRequest": { "names": ["document/cn/..."] } }
```

### 踩过的参数坑（照抄，别自己发挥）

1. **必须多嵌一层**：直接传 `{"query":"…"}` 会被服务端以
   `{"code":"400","message":"Check whether your request body meets the tool requirements."}` 拒绝。
2. **`parent` 原样照抄**：检索结果里给的是 `document/cn/harmonyos-guides/...`（**单数 `document`**），
   而 outputSchema 的说明文字里写的是 `documents/...`（复数，**别信**）。取全文时用返回值本身。
3. `getDocumentsById` 一次最多 10 篇；返回正文是 Markdown，一篇动辄 5~10 万字符，**一次别贪多**。
4. 没有 `top` 之类的分页参数：传了被忽略，固定返回 10 条片段。

## 4. 协议层坑（自己写客户端时才会碰到）

| 现象 | 原因 / 做法 |
| --- | --- |
| `GET /mcp` 404、浏览器打开是空白 | 这是 **Streamable HTTP**：只能 `POST` JSON-RPC |
| 响应不是 JSON 而是 `data: {...}` 文本 | SSE 帧；按行取 `data:` 后的内容再 parse |
| 第二个请求开始报错 | 要在响应头取 `mcp-session-id`，后续请求回填 |
| `tools/call` 报未初始化 | `initialize` 之后必须补发一次 `notifications/initialized`（无 id 的通知） |
| 需不需要 token | **不需要**。本机直连 200，无 Authorization 头 |
| 协议版本 | 服务端回 `2025-06-18`（serverInfo `DeveloperCommunity` 1.0.0） |

## 5. 备用入口：脚本直连（不依赖任何 MCP 客户端）

```powershell
# 检索（-Brief 只打印片段摘要）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\mcp-query.ps1 -Query "Navigation pushPath animated 转场动画" -Brief

# 看工具清单
powershell -NoProfile -ExecutionPolicy Bypass -File tools\mcp-query.ps1 -ListTools

# 取全文（单数 document/...，来自上一步的 parent）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\mcp-query.ps1 -Tool getDocumentsById -Ids "document/cn/harmonyos-guides/arkts-shared-element-transition"
```

脚本内部已经把「POST-only + SSE 解析 + session-id + initialized 通知 + 参数多嵌一层」都处理好了，
**这是没有 MCP 客户端时的保底手段**，也是排查端点是否可达的第一手段。

## 6. 本项目的用途分布（先查再写）

动画/几何这块，下面这些问题**都值得先查一次**，不要凭记忆写：

- `clip(true)` 是否把子节点的圆角一起裁；`clipShape` 与 `borderRadius` 谁覆盖谁
- `Area.globalPosition`（布局坐标）与 `FrameNode.getPositionToWindowWithTransform()`（含变换）的口径差异
- `FrameNode.getMeasuredSize()` 的单位（px）与 `px2vp` 转换
- `layoutWeight` / `displayPriority` / `constraintSize({minWidth:0})` 的生效前提
- `NavPathStack.pushPath(info, false)` 关掉系统转场后自绘动画（共享元素转场官方指南里就是这么干的）
- `NavDestination` 的 `mode` / `fullScreenOverlay` / 转场相关属性
- HDS（`@kit.UIDesignKit`）组件的 `systemMaterialEffect`、`barFloatingStyle` 语义

## 7. 实测记录（2026-09-25）

* `tools/list` → 200，返回 2 个工具（schema 已抄进 §3）。
* `searchDocuments`，query = `Navigation pushPath animated 转场动画` → `code:0`，命中含
  `document/cn/harmonyos-guides/arkts-shared-element-transition`：官方共享元素转场指南里明确写着
  「为了避免触发 Navigation 的转场动画，在 `pushPath()` 的时候把动画选项设置成了 false」——
  **正好是无界 1.2.4「pushPath + animated=false + 自绘形变」的官方依据**，可引给这条链路背书。
* `getDocumentsById`，`names = ["document/cn/harmonyos-guides/arkts-shared-element-transition"]`
  → `code:0`，返回全文（约 10.5 万字符），证明**单数 `document/` 才是有效标识**。
* `searchDocuments` 里多传一个 `top` 字段不影响（被忽略），但仍建议只传 `query`。
