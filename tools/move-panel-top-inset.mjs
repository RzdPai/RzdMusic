// 一次性整形脚本：把「设置详情」各子面板顶部那一段"状态栏 + HDS 标题栏"的偏移
// 从 **Scroll 自己的 padding** 挪成 **滚动内容里的第一个 Blank**。
//
// 为什么要这样（用户 2026-10-11 明确）：
//   页面要"延伸进状态栏" —— 列表往上滚要能一直画到屏幕最顶端。
//   Scroll 自己的 padding 会让内容区从 padding 之下起排（官方：padding 区域会被裁剪不显示），
//   于是状态栏那一条成了死背景；把偏移放进内容里，静止时位置不变，但滚起来能穿进状态栏。
//
// 用法: node tools/move-panel-top-inset.mjs <file.ets> [--dry]
import { readFileSync, writeFileSync } from 'node:fs';

const file = process.argv[2];
const dry = process.argv.includes('--dry');
if (!file) {
  console.error('usage: node tools/move-panel-top-inset.mjs <file.ets> [--dry]');
  process.exit(2);
}

const text = readFileSync(file, 'utf8');
const nl = text.includes('\r\n') ? '\r\n' : '\n';
const lines = text.split(/\r?\n/);

const scrollIdxs = [];
lines.forEach((l, i) => {
  // 注意：有的面板写成 `private OtherSheet() {    Scroll(this.pageScroller) {`（同一行），
  // 所以**不能**锚行首。
  if (/Scroll\(this\.pageScroller\)\s*\{\s*$/.test(l)) {
    scrollIdxs.push(i);
  }
});

const inserts = [];
for (const si of scrollIdxs) {
  for (let j = si + 1; j <= si + 2 && j < lines.length; j++) {
    if (!/^\s*Column\(\{\s*space:/.test(lines[j])) {
      continue;
    }
    // 已经有 Blank 的（音源管理那条，中间还夹着一段注释）跳过，别插两份
    const head = lines.slice(j + 1, j + 10).join('\n');
    if (head.includes('Blank().height(')) {
      break;
    }
    const indent = (lines[j].match(/^\s*/) ?? [''])[0] + '  ';
    inserts.push({ after: j, text: `${indent}Blank().height(this.panelTopInset())` });
    break;
  }
}

inserts.sort((a, b) => b.after - a.after);
for (const ins of inserts) {
  lines.splice(ins.after + 1, 0, ins.text);
}

let fixed = 0;
for (let i = 0; i < lines.length - 1; i++) {
  if (/^\s*\.padding\(\{ top: this\.panelTopInset\(\) \}\)\s*$/.test(lines[i]) &&
    /^\s*\.align\(Alignment\.Top\)\s*$/.test(lines[i + 1])) {
    lines[i] = lines[i].replace('this.panelTopInset()', '0');
    fixed++;
  }
}

console.log(`scrolls=${scrollIdxs.length} inserts=${inserts.length} scrollPaddingFixed=${fixed}`);
for (const ins of inserts) {
  console.log(`  + Blank after original line ${ins.after + 1}`);
}
if (dry) {
  console.log('(dry run, nothing written)');
} else {
  writeFileSync(file, lines.join(nl), 'utf8');
  console.log('written');
}
