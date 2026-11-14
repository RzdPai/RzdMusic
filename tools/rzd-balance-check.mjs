// 一次性自查脚本：统计 .ets 文件里 {} / () / [] 的配平（跳过字符串、模板串、注释）。
// 用法: node tools/rzd-balance-check.mjs <file...>
import { readFileSync } from 'node:fs';

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('usage: node tools/rzd-balance-check.mjs <file.ets> [...]');
  process.exit(2);
}

for (const f of files) {
  const s = readFileSync(f, 'utf8');
  const stack = [];
  const errs = [];
  let line = 1;
  let inSingle = false;
  let inDouble = false;
  let inTemplate = false;
  let inLineComment = false;
  let inBlockComment = false;
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    const c2 = s.slice(i, i + 2);
    if (c === '\n') {
      line++;
      inLineComment = false;
      i++;
      continue;
    }
    if (inLineComment) {
      i++;
      continue;
    }
    if (inBlockComment) {
      if (c2 === '*/') {
        inBlockComment = false;
        i += 2;
        continue;
      }
      i++;
      continue;
    }
    if (inSingle) {
      if (c === '\\') {
        i += 2;
        continue;
      }
      if (c === "'") {
        inSingle = false;
      }
      i++;
      continue;
    }
    if (inDouble) {
      if (c === '\\') {
        i += 2;
        continue;
      }
      if (c === '"') {
        inDouble = false;
      }
      i++;
      continue;
    }
    if (inTemplate) {
      if (c === '\\') {
        i += 2;
        continue;
      }
      if (c === '`') {
        inTemplate = false;
      }
      i++;
      continue;
    }
    if (c2 === '//') {
      inLineComment = true;
      i += 2;
      continue;
    }
    if (c2 === '/*') {
      inBlockComment = true;
      i += 2;
      continue;
    }
    if (c === "'") {
      inSingle = true;
      i++;
      continue;
    }
    if (c === '"') {
      inDouble = true;
      i++;
      continue;
    }
    if (c === '`') {
      inTemplate = true;
      i++;
      continue;
    }
    if (c === '{' || c === '(' || c === '[') {
      stack.push([c, line]);
    } else if (c === '}' || c === ')' || c === ']') {
      const open = c === ')' ? '(' : (c === ']' ? '[' : '{');
      const top = stack.pop();
      if (top === undefined || top[0] !== open) {
        errs.push(`line ${line}: unexpected ${c}${top === undefined ? ' (stack empty)' : ` (open ${top[0]} at line ${top[1]})`}`);
      }
    }
    i++;
  }
  const unclosed = stack.map((t) => `${t[0]}@L${t[1]}`).join(' ');
  console.log(`${f}\n  {}: ${(s.match(/\{/g) ?? []).length} / ${(s.match(/\}/g) ?? []).length}` +
    `  (): ${(s.match(/\(/g) ?? []).length} / ${(s.match(/\)/g) ?? []).length}` +
    `  []: ${(s.match(/\[/g) ?? []).length} / ${(s.match(/\]/g) ?? []).length}` +
    `  unclosedRaw=${stack.length} errors=${errs.length === 0 ? 'none' : errs.join(' ; ')}` +
    (unclosed.length > 0 ? `\n  stack: ${unclosed}` : ''));
}
