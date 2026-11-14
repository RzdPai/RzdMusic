// 扫一个 .ets / .ts 文件里的**硬编码颜色**（用户 2026-10-11 明确：我的页取色不能照搬参考工程，
// 必须走我们自己的 token —— $r('app.color.*') / $r('sys.color.*') / ThemeState.color）。
//
// 用法: node tools/theme-color-check.mjs <file.ets> [more files...]
// 说明: 注释里的例子（`#1f1f22` 这种）不算违规，会被跳过；只报**代码里**的十六进制颜色。
import { readFileSync } from 'node:fs';

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('usage: node tools/theme-color-check.mjs <file.ets> [...]');
  process.exit(2);
}

/** 粗略剥掉行注释与块注释（够用：源码里没有含 `//` 的裸字符串）。 */
function stripComments(text) {
  let out = '';
  let i = 0;
  let state = 'code';
  while (i < text.length) {
    const c = text[i];
    const n = text[i + 1];
    if (state === 'code' && c === '/' && n === '/') {
      state = 'line';
      i += 2;
      continue;
    }
    if (state === 'code' && c === '/' && n === '*') {
      state = 'block';
      i += 2;
      continue;
    }
    if (state === 'line') {
      if (c === '\n') {
        state = 'code';
        out += c;
      }
      i++;
      continue;
    }
    if (state === 'block') {
      if (c === '*' && n === '/') {
        state = 'code';
        i += 2;
        continue;
      }
      if (c === '\n') {
        out += c;
      }
      i++;
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

let total = 0;
let paletteHits = 0;
// 参考工程（lxmusic-harmony）那套配色的资源名：照搬版式**不许照搬**它们（用户有自定义主题色）。
const REF_PALETTE = /app\.color\.c_(bg|card|top_fade|text|red|divider|seg|icon|chevron|glass|mask|fill|tab|on_accent|pressed|slider|record)\w*/g;

for (const file of files) {
  const stripped = stripComments(readFileSync(file, 'utf8'));
  const lines = stripped.split(/\r?\n/);
  const hits = [];
  const palette = [];
  lines.forEach((line, idx) => {
    const found = line.match(/#[0-9a-fA-F]{3,8}\b/g) ?? [];
    if (found.length > 0) {
      hits.push(`  L${idx + 1}: ${found.join(' ')}   | ${line.trim().slice(0, 110)}`);
    }
    const refFound = line.match(REF_PALETTE) ?? [];
    if (refFound.length > 0) {
      palette.push(`  L${idx + 1}: ${refFound.join(' ')}   | ${line.trim().slice(0, 110)}`);
    }
  });
  console.log(`=== ${file}`);
  console.log(`  -- 硬编码颜色=${hits.length}`);
  hits.forEach((h) => console.log(h));
  console.log(`  -- 参考工程配色 token=${palette.length}（必须为 0）`);
  palette.forEach((p) => console.log(p));
  total += hits.length;
  paletteHits += palette.length;
}
console.log(`TOTAL hard-coded=${total}  ref-palette=${paletteHits}`);
process.exit(paletteHits === 0 ? 0 : 1);
