// 汇总 .ets 的“结构性”语法错误（忽略 ArkUI DSL 在 @Builder 里造成的 TS 误报）。
// 用法: node tools/ets-syntax-probe.mjs <file.ets> 之后，
//       用本脚本看哪些诊断是模板串/注释被吞掉的典型症状。
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire('file:///D:/command-line-tools/hvigor/hvigor/node_modules/');
const ts = require('typescript');

const file = process.argv[2];
const text = readFileSync(file, 'utf8');
const src = text.replace(/^(\s*)(export\s+|default\s+)?struct\s+/gm, '$1$2class ');
const sf = ts.createSourceFile('probe.ts', src, ts.ScriptTarget.ES2021, false, ts.ScriptKind.TS);
const lines = src.split(/\r?\n/);
const SUSPECT = new Set([1443, 1127, 1434, 1109]); // 模板/注释被吞掉的典型症状
let bad = 0;
for (const d of sf.parseDiagnostics ?? []) {
  if (!SUSPECT.has(d.code)) {
    continue;
  }
  const pos = ts.getLineAndCharacterOfPosition(sf, d.start);
  console.log(`L${pos.line + 1}:${pos.character + 1} TS${d.code} ${ts.flattenDiagnosticMessageText(d.messageText, ' ')}`);
  console.log(`    | ${(lines[pos.line] ?? '').trim().slice(0, 120)}`);
  bad++;
}
console.log(`suspect=${bad}`);
