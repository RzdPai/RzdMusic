# tools/

## `qjs-repro.js` —— 没真机时复现「脚本跑 QuickJS 为什么失败」

```bash
node tools/qjs-repro.js /path/to/lx-script.js
```

它做三件事：把 `qjs-prelude.js`（= ArkTS 里 `QuickJsRuntime.PRELUDE` 的自动导出）装进 node、
删掉 node 自带的 `setTimeout`/`window`/`localStorage`/`fetch` 等（模拟 QuickJS 裸环境）、
然后 eval 目标脚本，最后打印：

- 顶层 eval 是否抛错、**栈（含行号）与那一行源码**
- 脚本自己 `console.log` 的内容
- 投递箱里攒下的宿主调用（`request` / `send` 的参数）

### 为什么要有它

QuickJS 侧的宿主环境**全是我们自己用 PRELUDE 仿的**（`console`/`window`/定时器/`localStorage`
在 QuickJS 里都不存在）。脚本一挂，真机日志里只有一句 `TypeError: xxx`，改一次就得麻烦用户装包。

2026-11-15 的实例：两支完全不同的脚本都报
`cannot read property 'request' of undefined`。用这个工具 3 分钟定位到——
脚本第 16 行是

```js
const { EVENT_NAMES, request, on, send, env, version } = globalThis.lx;
```

而我们的 `lx` 少了 `EVENT_NAMES` ⇒ 下一行 `on(EVENT_NAMES.request, …)` 就炸了。
**补上这一个字段，脚本直接跑通**（投递箱正确吐出 `request` + `send/inited`，4 个平台全在）。

### 维护

`qjs-prelude.js` 是**自动导出**的，改了 `QuickJsRuntime.ets` 里的 `PRELUDE` 之后要重新导出：

```bash
python3 - <<'EOF'
import io
s=io.open('features/player/src/main/ets/source/QuickJsRuntime.ets',encoding='utf-8').read()
i=s.find("const PRELUDE: string = "); o=s.find('`', i)
j=s.find("})();\n`;", o); body=s[o+1:j+len("})();\n")]
io.open('tools/qjs-prelude.js','w',encoding='utf-8').write(
  "// 自动生成，别手改。见 tools/README.md。\n"+body)
EOF
```

⚠️ **PRELUDE 是 ArkTS 的模板字符串**，里面一旦出现反引号，模块直接就语法崩。
而且「找第一个反引号」的检查器会因为截断而误判通过 —— 导出时务必确认
`qjs-prelude.js` 的字节数与预期接近（现在约 9 KB），或直接 `node tools/qjs-repro.js` 跑一遍。
