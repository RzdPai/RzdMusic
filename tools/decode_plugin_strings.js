// Decode the obfuscated string-builder functions found in the lx-music plugin.
// Usage: node decode_plugin_strings.js <plugin.js> <line> <colStart> <colEnd>
const fs = require('fs');

const file = process.argv[2];
const line = parseInt(process.argv[3] || '0', 10); // 0-based line index
const src = fs.readFileSync(file, 'utf8').split('\n')[line];

// Find every immediately-invoked decoder arrow in the line and print its result.
const re = /(\(\(r,e,t\)=>\{[\s\S]*?\}\)\(\[[^\]]*\],\[[^\]]*\],-?\d+\))|(\(r,e,t\)=>\{[\s\S]*?\}\)\(\[[^\]]*\],\[[^\]]*\],-?\d+\))/g;
let m;
let i = 0;
while ((m = re.exec(src)) !== null) {
  const code = m[0];
  try {
    const fn = eval(code);
    const out = fn;
    console.log(`[${i++}] @${m.index} => ${JSON.stringify(out)}`);
  } catch (e) {
    console.log(`[${i++}] @${m.index} => ERR ${e.message}`);
  }
}
console.log('total=' + i);
