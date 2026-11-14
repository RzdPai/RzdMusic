// 用 DevEco 自带的 TypeScript 解析 .ets，快速定位语法错误（比等整包构建快得多）。
// 用法: node tools/ets-syntax-probe.mjs <file.ets>
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire('file:///D:/command-line-tools/hvigor/hvigor/node_modules/');
const ts = require('typescript');

const file = process.argv[2];
if (!file) {
  console.error('usage: node tools/ets-syntax-probe.mjs <file.ets>');
  process.exit(2);
}
let text = readFileSync(file, 'utf8');
// .ets 的 UI 语法不是 TS：把行首（可带 export / default）的 `struct X` 换成 `class X`，
// 其余（@Builder / 链式调用 / $$ 双向绑定）TS 都能当普通 TS 解析。
const src = text.replace(/^(\s*)(export\s+|default\s+)?struct\s+/gm, '$1$2class ');
const sf = ts.createSourceFile('probe.ts', src, ts.ScriptTarget.ES2021, false, ts.ScriptKind.TS);
const diags = sf.parseDiagnostics ?? [];
console.log(`parseDiagnostics=${diags.length}`);
for (const d of diags.slice(0, 40)) {
  const pos = ts.getLineAndCharacterOfPosition(sf, d.start);
  const msg = ts.flattenDiagnosticMessageText(d.messageText, ' ');
  const line = src.split(/\r?\n/)[pos.line] ?? '';
  console.log(`L${pos.line + 1}:${pos.character + 1} TS${d.code} ${msg}`);
  console.log(`    | ${line.trim().slice(0, 120)}`);
}
