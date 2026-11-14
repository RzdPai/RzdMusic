// 扫描 .ets 的 token 流，列出所有模板串 token（定位“未闭合模板”的起点）。
// 用法: node tools/ets-template-scan.mjs <file.ets>
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire('file:///D:/command-line-tools/hvigor/hvigor/node_modules/');
const ts = require('typescript');

const file = process.argv[2];
const text = readFileSync(file, 'utf8');
const sf = ts.createSourceFile('probe.ts', text, ts.ScriptTarget.ES2021, false, ts.ScriptKind.TS);
const scanner = ts.createScanner(ts.ScriptTarget.ES2021, false, ts.LanguageVariant.Standard, text);
const names = new Map([
  [ts.SyntaxKind.TemplateHead, 'TemplateHead'],
  [ts.SyntaxKind.TemplateMiddle, 'TemplateMiddle'],
  [ts.SyntaxKind.TemplateTail, 'TemplateTail'],
  [ts.SyntaxKind.NoSubstitutionTemplateLiteral, 'NoSubTemplate'],
  [ts.SyntaxKind.OpenBraceToken, 'OpenBrace'],
  [ts.SyntaxKind.CloseBraceToken, 'CloseBrace'],
]);
const lines = text.split(/\r?\n/);
let count = 0;
for (;;) {
  const kind = scanner.scan();
  if (kind === ts.SyntaxKind.EndOfFileToken) {
    break;
  }
  const label = names.get(kind);
  if (label !== undefined && label !== 'OpenBrace' && label !== 'CloseBrace') {
    const lc = ts.getLineAndCharacterOfPosition(sf, scanner.getTokenPos());
    console.log(`${label}  L${lc.line + 1}:${lc.character + 1}  raw=${JSON.stringify(scanner.getTokenText().slice(0, 40))}`);
    count++;
    if (count > 200) {
      break;
    }
  }
}
console.log(`total template tokens=${count}`);
