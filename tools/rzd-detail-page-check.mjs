// 括号平衡 + 关键改写标记核对（源码级自检，零构建）
// 用法: node tools/rzd-detail-page-check.mjs
import { readFileSync } from 'node:fs';

const FILES = [
  'features/setting/src/main/ets/view/DetailImmersiveBackdrop.ets',
  'features/setting/src/main/ets/view/ArtistDetailPage.ets',
  'features/setting/src/main/ets/view/AlbumDetailPage.ets',
  'products/default/src/main/ets/pages/Index.ets',
];

/** 剥掉注释 / 字符串 / 模板串 / 正则字面量，返回同样长度的空白替换文本。 */
function strip(src) {
  const out = src.split('');
  let i = 0;
  const n = src.length;
  const blank = (from, to) => {
    for (let k = from; k < to && k < n; k++) {
      if (out[k] !== '\n') {
        out[k] = ' ';
      }
    }
  };
  let prevSignificant = '';
  while (i < n) {
    const c = src[i];
    const c2 = src[i + 1];
    if (c === '/' && c2 === '/') {
      const end = src.indexOf('\n', i);
      blank(i, end < 0 ? n : end);
      i = end < 0 ? n : end;
      continue;
    }
    if (c === '/' && c2 === '*') {
      const end = src.indexOf('*/', i + 2);
      blank(i, end < 0 ? n : end + 2);
      i = end < 0 ? n : end + 2;
      continue;
    }
    if (c === "'" || c === '"' || c === '`') {
      const quote = c;
      let j = i + 1;
      while (j < n) {
        if (src[j] === '\\') {
          j += 2;
          continue;
        }
        if (src[j] === quote) {
          break;
        }
        j++;
      }
      blank(i + 1, j);
      i = j + 1;
      prevSignificant = quote;
      continue;
    }
    if (c === '/' && /[=(,:;[!&|?{}]/.test(prevSignificant === '' ? '(' : prevSignificant)) {
      // 正则字面量：/^.../ 之类，读到未转义的 /
      let j = i + 1;
      let cls = false;
      while (j < n) {
        if (src[j] === '\\') {
          j += 2;
          continue;
        }
        if (src[j] === '[') {
          cls = true;
        } else if (src[j] === ']') {
          cls = false;
        } else if (src[j] === '/' && !cls) {
          break;
        } else if (src[j] === '\n') {
          break;
        }
        j++;
      }
      blank(i, j);
      i = j + 1;
      continue;
    }
    if (!/\s/.test(c)) {
      prevSignificant = c;
    }
    i++;
  }
  return out.join('');
}

let problems = 0;

for (const f of FILES) {
  const raw = readFileSync(f, 'utf8');
  const clean = strip(raw);
  const pairs = { '{': '}', '(': ')', '[': ']' };
  const stack = [];
  let bad = null;
  for (let i = 0; i < clean.length && bad === null; i++) {
    const c = clean[i];
    if (pairs[c] !== undefined) {
      stack.push({ c, i });
    } else if (c === '}' || c === ')' || c === ']') {
      const top = stack.pop();
      if (top === undefined || pairs[top.c] !== c) {
        bad = `unbalanced '${c}' at offset ${i}`;
      }
    }
  }
  if (bad === null && stack.length > 0) {
    bad = `unclosed '${stack[stack.length - 1].c}' at offset ${stack[stack.length - 1].i}`;
  }
  if (bad !== null) {
    problems++;
    console.log(`FAIL  ${f}: ${bad}`);
  } else {
    console.log(`OK    ${f}  (lines=${raw.split('\n').length})`);
  }
}

// ---- 关键改写标记（阴性对照：把期望值钉在这里，不从源码抽） ----
const EXPECT = [
  ['features/setting/src/main/ets/view/DetailImmersiveBackdrop.ets', [
    ['pageHeightVp', true],
    ['LayoutPolicy.matchParent', false],
  ]],
  ['features/setting/src/main/ets/view/ArtistDetailPage.ets', [
    ['buildTitleMaterial(this.ambientState.level)', true],
    ['materialType: hdsMaterial.MaterialType.NONE', false],
    ['BlurStrategy.ENABLE', true],
    ['hdsMaterial', false],
    ['pageHeightVp: this.pageContentHeightVp()', true],
  ]],
  ['features/setting/src/main/ets/view/AlbumDetailPage.ets', [
    ['buildTitleMaterial(this.ambientState.level)', true],
    ['materialType: hdsMaterial.MaterialType.NONE', false],
    ['BlurStrategy.ENABLE', true],
    ['hdsMaterial', false],
    ['pageHeightVp: this.pageContentHeightVp()', true],
  ]],
];

for (const [f, checks] of EXPECT) {
  const clean = strip(readFileSync(f, 'utf8'));
  for (const [needle, want] of checks) {
    const hit = clean.includes(needle);
    const ok = hit === want;
    if (!ok) {
      problems++;
    }
    console.log(`${ok ? 'OK  ' : 'FAIL'}  ${f}  ${want ? 'must have' : 'must NOT have'} "${needle}"  -> hit=${hit}`);
  }
}

console.log(problems === 0 ? '\nALL PASS' : `\n${problems} PROBLEM(S)`);
process.exit(problems === 0 ? 0 : 1);
