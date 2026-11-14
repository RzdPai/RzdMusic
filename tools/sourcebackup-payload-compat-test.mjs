// 载荷格式「上一轮 vs 本轮」的逐字段比对 + id 白名单判据（零构建）。
// 期望值钉死在这里（不从被测源码里抽），上一轮的值来自被删除的 features/sync/.../SourceSync.ets。
import fs from 'node:fs';

const NEW = 'C:\\Users\\Administrator\\Desktop\\RzdProject\\RzdMusic\\features\\player\\src\\main\\ets\\source\\SourceBackupPayload.ets';
const OLD_DELETED = 'C:\\Users\\Administrator\\Desktop\\RzdProject\\RzdMusic\\features\\sync\\src\\main\\ets\\core\\SourceSync.ets';
const src = fs.readFileSync(NEW, 'utf8');

// 算术常量（512 * 1024 这种）要按算式求值：直接 Number() 会得到 NaN。
function evalConst(expr) { return Number(eval(expr)); }
let pass = 0; let fail = 0;
function eq(label, expect, actual) {
  if (expect === actual) { pass++; console.log(`PASS  ${label} = ${JSON.stringify(actual)}`); }
  else { fail++; console.log(`FAIL  ${label}: expect ${JSON.stringify(expect)} got ${JSON.stringify(actual)}`); }
}

// 1) 载荷格式（上一轮已推给用户用过 ⇒ 一个字节都不能变）
eq('SOURCE_SYNC_KEY', 'customSources', (/export const SOURCE_SYNC_KEY: string = '([^']+)'/.exec(src) || [])[1]);
eq('PAYLOAD_KIND', 'rzdmusic-custom-sources', (/const PAYLOAD_KIND: string = '([^']+)'/.exec(src) || [])[1]);
eq('PAYLOAD_VERSION', 1, Number((/const PAYLOAD_VERSION: number = (\d+)/.exec(src) || [])[1]));

// 2) 上限与闸门
eq('MAX_SOURCES', 100, Number((/export const MAX_SOURCES: number = (\d+)/.exec(src) || [])[1]));
eq('MAX_SCRIPT_CHARS', 512 * 1024, evalConst((/export const MAX_SCRIPT_CHARS: number = ([0-9* ]+)/.exec(src) || [])[1]));
eq('MAX_TOTAL_CHARS', 2 * 1024 * 1024, evalConst((/export const MAX_TOTAL_CHARS: number = ([0-9* ]+)/.exec(src) || [])[1]));
eq('MAX_BACKUP_CHARS', 15 * 1024 * 1024, evalConst((/const MAX_BACKUP_CHARS: number = ([0-9* ]+)/.exec(src) || [])[1]));

// 3) 载荷字段名集合（顺序无关，集合必须完全一致）
const want = ['kind', 'v', 'exportedAt', 'device', 'activeId', 'count', 'chars', 'sources'];
const iface = /export interface SourcePayload \{([\s\S]*?)\n\}/.exec(src)[1];
const got = [...iface.matchAll(/^\s{2}([A-Za-z]+)[?]?:/gm)].map((m) => m[1]).sort();
eq('SourcePayload 字段集合', JSON.stringify(want.slice().sort()), JSON.stringify(got));

const wantEntry = ['id', 'name', 'description', 'author', 'homepage', 'version', 'allowShowUpdateAlert', 'script'];
const ifaceE = /export interface SourcePayloadEntry \{([\s\S]*?)\n\}/.exec(src)[1];
const gotE = [...ifaceE.matchAll(/^\s{2}([A-Za-z]+)[?]?:/gm)].map((m) => m[1]).sort();
eq('SourcePayloadEntry 字段集合', JSON.stringify(wantEntry.slice().sort()), JSON.stringify(gotE));

// 4) 旧实现确认已删除（"只有一份实现"）
eq('旧 SourceSync.ets 已删除', false, fs.existsSync(OLD_DELETED));

// 5) id 白名单判据与原实现一致（期望值 = 题目给的 /^[A-Za-z0-9_-]{1,64}$/）
const PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const cases = [
  ['user_api_001_1696000000000', true],
  ['a', true],
  ['A-9_z', true],
  ['../evil', false],
  ['..\\evil', false],
  ['a/b', false],
  ['', false],
  ['x'.repeat(64), true],
  ['x'.repeat(65), false],
  ['id with space', false],
  ['ид', false],
  ['a.js', false],
];
for (const [id, expect] of cases) {
  eq(`id 白名单 ${JSON.stringify(id.length > 12 ? id.slice(0, 12) + '…' : id)}`, expect, PATTERN.test(id));
}

// 6) 三条链路都必须出现挂载调用（上传附加 + 恢复合并）
const files = {
  webdav: 'C:\\Users\\Administrator\\Desktop\\RzdProject\\RzdMusic\\features\\sync\\src\\main\\ets\\core\\WebDavBackupService.ets',
  native: 'C:\\Users\\Administrator\\Desktop\\RzdProject\\RzdMusic\\features\\player\\src\\main\\ets\\account\\HuaweiNativeCloudBackup.ets',
  legacy: 'C:\\Users\\Administrator\\Desktop\\RzdProject\\RzdMusic\\features\\player\\src\\main\\ets\\account\\HuaweiCloudSync.ets',
};
for (const [name, f] of Object.entries(files)) {
  const c = fs.readFileSync(f, 'utf8');
  eq(`${name} 上传附加`, true, c.includes('attachSourcesToSnapshot('));
  eq(`${name} 恢复合并(保守外壳)`, true,
    c.includes('mergeSourcesIntoRestoreResult(') &&
    c.includes('const message: string = await DataBackupService.getInstance().restoreSnapshotText('));
}
// 系统云空间那条：成功判据必须仍在原处（UPLOAD_SUCCESS 等待 + 之后才报成功）
const nat = fs.readFileSync(files.native, 'utf8');
eq('native 仍 await synchronize(uri) 后才报成功', true,
  /await this\.synchronize\(fileUri\.getUriFromPath\(path\)\);\s*\n\s*hilog\.info\(0, TAG, 'backup upload confirmed[\s\S]{0,80}\n\s*return '备份成功';/.test(nat));
// 旧网页云盘那条：expectedBytes 必须等于"实际写上去的文本"的长度
const leg = fs.readFileSync(files.legacy, 'utf8');
eq('legacy expectedBytes 取自附加后的文本', true,
  /const snapshotText: string = await attachSourcesToSnapshot\([\s\S]{0,120}?\);\s*\n\s*const expectedBytes: number = utf8Length\(snapshotText\);/.test(leg));

console.log(`\n总计 pass=${pass} fail=${fail}`);
process.exit(fail === 0 ? 0 : 1);
