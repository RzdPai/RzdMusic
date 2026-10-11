// 只读型「导入/导出交叉核对器」（源码级证据，不编译）
// 用途：核实改动文件里的每一个命名导入，确实被目标模块导出（沿 export ... from 递归）。
// 惯例：任何检查器都要配阴性对照 —— 见文件末尾的 --neg 注入。
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'C:\\Users\\Administrator\\Desktop\\RzdProject\\RzdMusic';
// HAR 包名 -> 入口
const PKG = {
  player: path.join(ROOT, 'features/player/Index.ets'),
  musicbasic: path.join(ROOT, 'common/musicbasic/Index.ets'),
  sync: path.join(ROOT, 'features/sync/Index.ets'),
};

function stripCommentsAndStrings(src) {
  let out = '';
  let i = 0;
  let mode = 'code';
  while (i < src.length) {
    const c = src[i];
    const n = src[i + 1];
    if (mode === 'code') {
      if (c === '/' && n === '/') { mode = 'line'; i += 2; continue; }
      if (c === '/' && n === '*') { mode = 'block'; i += 2; continue; }
      if (c === "'" ) { mode = 'sq'; out += ' '; i++; continue; }
      if (c === '"') { mode = 'dq'; out += ' '; i++; continue; }
      if (c === '`') { mode = 'tpl'; out += ' '; i++; continue; }
      // 正则字面量粗略跳过：仅当上一个非空字符是 ( , = : [ ! & | ? { ; 或行首
      if (c === '/') {
        let j = out.length - 1;
        while (j >= 0 && /\s/.test(out[j])) { j--; }
        const prev = j >= 0 ? out[j] : '';
        if (prev === '' || '(,=:[!&|?{;+'.includes(prev)) {
          let k = i + 1; let cls = false; let ok = false;
          while (k < src.length) {
            const ch = src[k];
            if (ch === '\\') { k += 2; continue; }
            if (ch === '[') { cls = true; }
            if (ch === ']') { cls = false; }
            if (ch === '/' && !cls) { ok = true; break; }
            if (ch === '\n') { break; }
            k++;
          }
          if (ok) { out += ' '; i = k + 1; continue; }
        }
      }
      out += c; i++; continue;
    }
    if (mode === 'line') { if (c === '\n') { mode = 'code'; out += '\n'; } i++; continue; }
    if (mode === 'block') { if (c === '*' && n === '/') { mode = 'code'; i += 2; continue; } i++; continue; }
    if (mode === 'sq' || mode === 'dq' || mode === 'tpl') {
      const q = mode === 'sq' ? "'" : mode === 'dq' ? '"' : '`';
      if (c === '\\') { i += 2; continue; }
      if (c === q) { mode = 'code'; out += ' '; i++; continue; }
      if (c === '\n') { out += '\n'; }
      i++; continue;
    }
  }
  return out;
}

function splitNames(inner) {
  return inner.split(',').map((s) => s.trim()).filter(Boolean).map((s) => {
    // 去掉 type 前缀与 as 别名，取「原模块里的名字」
    let t = s.replace(/^type\s+/, '').trim();
    const m = t.match(/^(\S+)\s+as\s+\S+$/);
    if (m) { t = m[1]; }
    return t;
  }).filter((s) => /^[A-Za-z_$][\w$]*$/.test(s));
}

/** 返回 { names:[{name,from}], reexports:[{names,from}] }
 *  ★ 必须在**原始文本**上匹配（字符串剥成空格后，模块名那对引号就没了 —— 第一版就这么
 *    静默返回 0 条导入、看着像"全部通过"）。所以：在外面剥引号，只在 {} 内部剥注释。 */
function parseImports(src) {
  const names = [];
  const reexports = [];
  const imp = /import\s+(?:type\s+)?\{([\s\S]*?)\}\s*from\s*'([^']+)'/g;
  let m;
  while ((m = imp.exec(src)) !== null) {
    const inner = stripCommentsAndStrings(m[1]);
    splitNames(inner).forEach((n) => names.push({ name: n, from: m[2] }));
  }
  const re = /export\s+(?:type\s+)?\{([\s\S]*?)\}\s*from\s*'([^']+)'/g;
  while ((m = re.exec(src)) !== null) {
    reexports.push({ names: splitNames(stripCommentsAndStrings(m[1])), from: m[2] });
  }
  return { names, reexports };
}

function parseLocalExports(src) {
  const code = stripCommentsAndStrings(src);
  const out = new Set();
  const pats = [
    // ★ async/abstract/declare 都要认：第一版漏了 `export async function`，
    //   于是 attachSourcesToSnapshot 被误报成"不在导出面里"（读不到 ≠ 不存在）。
    /export\s+(?:default\s+)?(?:abstract\s+)?(?:declare\s+)?(?:async\s+)?(?:class|interface|enum|struct|function|let|const|var)\s+([A-Za-z_$][\w$]*)/g,
    /export\s+type\s+([A-Za-z_$][\w$]*)/g,
  ];
  for (const p of pats) { let m; while ((m = p.exec(code)) !== null) { out.add(m[1]); } }
  // 本地 export { A, B }（不带 from）也要算
  const bare = /export\s*\{([^}]*)\}\s*(?!from)/g;
  let m2;
  while ((m2 = bare.exec(code)) !== null) { splitNames(m2[1]).forEach((n) => out.add(n)); }
  return out;
}

function resolve(fromFile, spec, pkgOf) {
  if (PKG[spec]) { return PKG[spec]; }
  if (!spec.startsWith('.')) { return null; }
  const base = path.resolve(path.dirname(fromFile), spec);
  const cands = [base, base + '.ets', base + '.ts', path.join(base, 'Index.ets')];
  for (const c of cands) { if (fs.existsSync(c) && fs.statSync(c).isFile()) { return c; } }
  return null;
}

function exportsOf(file, seen = new Set()) {
  if (seen.has(file)) { return new Set(); }
  seen.add(file);
  const src = fs.readFileSync(file, 'utf8');
  const local = parseLocalExports(src);
  const { reexports } = parseImports(src);
  for (const r of reexports) {
    const target = resolve(file, r.from);
    if (target === null) { r.names.forEach((n) => local.add(n)); continue; } // 解析不了就当它在（别报假 MISSING）
    const inner = exportsOf(target, seen);
    for (const n of r.names) { if (inner.has(n)) { local.add(n); } }
  }
  return local;
}

if (process.argv.includes('--selftest')) {
  const probe = "import { A } from 'x';\nexport { B, C } from './y';\nconst s = 'import { Z } from \\'q\\'';\n";
  console.log('SELFTEST stripped=[' + JSON.stringify(stripCommentsAndStrings(probe)) + ']');
  const p = parseImports(probe);
  console.log('SELFTEST names=', JSON.stringify(p.names.map((n) => n.name)));
  console.log('SELFTEST reexports=', JSON.stringify(p.reexports.map((r) => r.names)));
  const ok = p.names.length === 1 && p.names[0].name === 'A' && p.reexports.length === 1 && p.reexports[0].names.length === 2;
  console.log('SELFTEST', ok ? 'PASS' : 'FAIL');
  process.exit(ok ? 0 : 2);
}

const targets = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const NEG = process.argv.includes('--neg');
let problems = 0;
let checked = 0;
for (const t of targets) {
  const file = path.resolve(t);
  const src = fs.readFileSync(file, 'utf8');
  const { names } = parseImports(src);
  if (NEG) { names.push({ name: 'thisNameDoesNotExistAnywhere', from: 'player' }); }
  for (const item of names) {
    checked++;
    const target = resolve(file, item.from);
    if (target === null) { console.log(`SKIP  ${path.basename(file)}: ${item.name} (未解析的模块 '${item.from}')`); continue; }
    const ex = exportsOf(target);
    if (!ex.has(item.name)) { problems++; console.log(`MISSING ${path.basename(file)}: '${item.name}' 不在 ${path.relative(ROOT, target)} 的导出面里`); }
  }
}
console.log(`\n命名导入核对：checked=${checked} problems=${problems}${NEG ? '  (阴性对照模式：期望 problems>=1)' : ''}`);
process.exit(NEG ? (problems > 0 ? 0 : 2) : (problems === 0 ? 0 : 1));
