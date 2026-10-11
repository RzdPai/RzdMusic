/**
 * RzdMusic 自定义音源（音源脚本）的跨设备搬运层
 *
 * ★★ 为什么不是"洛雪同步"——先看这段，再看代码（用户报的"洛雪同步没把音源同步上去"）
 *
 * 官方洛雪同步协议里**没有音源这个模块**，音源走不了 `getEnabledFeatures` 协商出来的那条通道。
 * 已逐条核对上游源码（2026-10 核对，均为官方仓库当前 master/main）：
 *   - 服务端 `lyswhut/lx-music-sync-server/src/constants.ts`：
 *       `export const FeaturesList = ['list', 'dislike'] as const`
 *   - 服务端 `src/modules/index.ts`：
 *       `export const featureVersion = { list: 1, dislike: 1 } as const`，`modules` 只有 list / dislike
 *   - 服务端 `src/types/sync_common.d.ts`（**线上契约**）：客户端可实现的动作只有
 *       `getEnabledFeatures` / `finished` + `list_sync_get_md5|get_sync_mode|get_list_data|set_list_data|finished|onListSyncAction`
 *       + `dislike_sync_*`（同名一整套），**没有任何 source_* 动作**
 *   - 桌面端 `lyswhut/lx-music-desktop/src/main/modules/sync/client/modules/index.ts`：
 *       `modules = { list, dislike }`、`featureVersion = { list: 1, dislike: 1 }`
 *       （同一文件里还留着一行注释掉的 `// export * as theme from './theme'` —— "再加一个模块"
 *        就长这个样子，而 source 不在其中）
 *   - 官方文档 `lxmusic.toside.cn/mobile/faq/sync`：同步功能只讲"同步各端收藏的歌曲"
 *
 * 而且服务端是**它自己遍历 `FeaturesList` 驱动整个同步流程**的（`src/server/sync/sync.ts`），
 * 客户端单方面多报一个 feature 只会被忽略；客户端能主动调用的方法也只有服务端注册的那几个
 * （`src/modules/index.ts` 的 `callObj` = list + dislike 的 handler），所以**没有任何办法**
 * 让音源搭上这条连接。至于把音源塞进 `list` 载荷里"走私"：服务端的快照 key 是列表 JSON 的 md5，
 * 一塞就与官方客户端对不上，两边会反复弹合并框 —— 那等于毁掉互操作性，不能做。
 *
 * ⇒ 音源只能在**我们自己的载荷**里搬。本模块里已经有一个自有的跨设备通道：
 *   `WebDavBackupService`（`rzdmusic-backup-*.json`，同一个 WebDAV 账号，按钮就在设置页
 *   「数据同步」面板里）。音源就搭它走：备份时并进同一份 JSON 的 `customSources` 段，
 *   恢复时按 id 保守合并。字段名全是**我们自己定的**，不冒充洛雪协议字段；
 *   旧版本客户端读到未知键会忽略，旧备份没有该键时按"没有音源"处理 ⇒ 双向兼容。
 *
 * 冲突策略（保守，一条都不许"静默丢"，每条跳过的都要有日志）：
 *   同 id + 脚本内容相同   → 跳过（本来就一样）
 *   同 id + 脚本内容不同   → **保留本机那一份**，只记日志（把两边 version 打出来）
 *   本机没有该 id          → 落盘（id 原样保留，两台设备才认得出是同一份音源）
 *   本机有、远端没有       → **一律不删**（远端只是没带，不代表用户想删）
 *   远端 activeId 且本机当前没有选中、且合并后本地确有该 id → 才把本机选中切过去
 */

import { Logger, MusicStoreService } from 'musicbasic';
import { lxSourceManager } from 'player';
import type { LXUserApiInfoFull } from 'player';
import { defaultDeviceName } from './SyncStore';

const TAG: string = 'RzdSyncSources';

/** 备份 JSON 里放音源的那一段（我们自己定的键名）。 */
export const SOURCE_SYNC_KEY: string = 'customSources';

/** 载荷自描述：kind + v 让"这到底是不是我们的音源段"有确定答案，不靠猜键名。 */
const PAYLOAD_KIND: string = 'rzdmusic-custom-sources';
const PAYLOAD_VERSION: number = 1;

/** 一次最多搬多少个音源（多出来的跳过并记日志，不让同步整体挂掉）。 */
export const MAX_SOURCES: number = 100;
/**
 * 单个脚本的长度上限（字符数，UTF-16 code unit，比字节数保守）。
 *
 * 参照：洛雪自定义源文档里给出的脚本体量是几十 KB 级；桌面端 v2.8.0 的更新日志还专门
 * "增大在线导入自定义源文件的大小限制"（issue #1857）。512K 字符对正常脚本绰绰有余，
 * 又能挡住"把别的东西当脚本塞进来"的情况。
 */
export const MAX_SCRIPT_CHARS: number = 512 * 1024;
/** 音源段总长度上限（字符数）。 */
export const MAX_TOTAL_CHARS: number = 2 * 1024 * 1024;
/**
 * 备份 JSON 整体长度闸门。
 *
 * `DataBackupService.restoreSnapshotText` 里硬性写着"备份为空或超过 16MB 限制"，恢复侧
 * `WebDavBackupService.request()` 的 `maxLimit` 也是 16MB。并进来的音源段一旦把整份备份
 * 顶破这两道闸门，**备份/恢复这个既有功能就废了** —— 所以并之前先量整体长度，超了就整段不并
 * （宁可这一次不带音源，也不能把备份搞坏），并记日志。
 */
const MAX_BACKUP_CHARS: number = 15 * 1024 * 1024;

/** 载荷里的一个音源 */
export interface SourcePayloadEntry {
  id: string;
  name: string;
  description: string;
  author: string;
  homepage: string;
  version: string;
  allowShowUpdateAlert: boolean;
  /** 脚本原文（已解压的明文） */
  script: string;
}

/** 音源段载荷（写进备份 JSON 的 `customSources`） */
export interface SourcePayload {
  kind: string;
  v: number;
  exportedAt: number;
  device: string;
  /** 上传方当时选中的音源 id（空串 = 没选） */
  activeId: string;
  /** 实际带上的音源个数（= sources.length） */
  count: number;
  /** 只用于日志/排障：脚本总字符数 */
  chars: number;
  sources: SourcePayloadEntry[];
}

/** 合并结果（数量 + 原因分类，供日志与界面文案） */
export interface SourceMergeReport {
  /** 远端有、本机没有 ⇒ 新落盘 */
  added: number;
  /** 两边同 id 且脚本一致 */
  same: number;
  /** 两边同 id 但脚本不同 ⇒ 保留本机 */
  conflict: number;
  /** 结构非法 / id 非法 / 脚本为空 ⇒ 丢弃 */
  invalid: number;
  /** 落盘失败 */
  failed: number;
  /** 远端一共给了多少条 */
  total: number;
  /** 是否把本机选中的音源切到了远端那个 */
  activeApplied: boolean;
}

function emptyReport(): SourceMergeReport {
  return { added: 0, same: 0, conflict: 0, invalid: 0, failed: 0, total: 0, activeApplied: false };
}

function currentDeviceName(): string {
  try {
    return defaultDeviceName();
  } catch (_err) {
    return '';
  }
}

function activeSourceId(): string {
  try {
    return MusicStoreService.getInstance().getActiveSource();
  } catch (_err) {
    return '';
  }
}

/**
 * 打包本机音源（上行侧）。
 *
 * @returns 载荷；本机一个可用音源都没有时返回 null（调用方就不写这一段，省得往备份里塞空对象）
 */
export async function collectSourcePayload(): Promise<SourcePayload | null> {
  let full: LXUserApiInfoFull[] = [];
  try {
    full = await lxSourceManager.listFullApis();
  } catch (e) {
    Logger.error(TAG, `collect failed: ${(e as Error).message}`);
    return null;
  }
  const entries: SourcePayloadEntry[] = [];
  let chars: number = 0;
  let skippedOverCount: number = 0;
  let skippedBadId: number = 0;
  let skippedEmpty: number = 0;
  let skippedTooLong: number = 0;
  let skippedOverTotal: number = 0;
  for (let i: number = 0; i < full.length; i++) {
    const item = full[i];
    if (entries.length >= MAX_SOURCES) {
      skippedOverCount++;
      continue;
    }
    if (!lxSourceManager.isValidApiId(item.id)) {
      skippedBadId++;
      Logger.error(TAG, `音源同步 跳过 非法 id=${item.id}`);
      continue;
    }
    if (item.script.length === 0) {
      skippedEmpty++;
      Logger.error(TAG, `音源同步 跳过 脚本读不到 id=${item.id}`);
      continue;
    }
    if (item.script.length > MAX_SCRIPT_CHARS) {
      skippedTooLong++;
      Logger.error(TAG,
        `音源同步 跳过 脚本超限 id=${item.id} chars=${item.script.length} limit=${MAX_SCRIPT_CHARS}`);
      continue;
    }
    if (chars + item.script.length > MAX_TOTAL_CHARS) {
      skippedOverTotal++;
      Logger.error(TAG,
        `音源同步 跳过 总量超限 id=${item.id} chars=${chars} + ${item.script.length} > ${MAX_TOTAL_CHARS}`);
      continue;
    }
    chars += item.script.length;
    const entry: SourcePayloadEntry = {
      id: item.id,
      name: item.name,
      description: item.description,
      author: item.author,
      homepage: item.homepage,
      version: item.version,
      allowShowUpdateAlert: item.allowShowUpdateAlert,
      script: item.script
    };
    entries.push(entry);
  }
  const skipped: number = skippedOverCount + skippedBadId + skippedEmpty + skippedTooLong + skippedOverTotal;
  Logger.info(TAG,
    `音源同步 打包 ${entries.length} 个 / 跳过 ${skipped} 个（个数超限=${skippedOverCount} id非法=${skippedBadId} 脚本缺失=${skippedEmpty} 单脚本超限=${skippedTooLong} 总量超限=${skippedOverTotal}）chars=${chars}`);
  if (entries.length === 0) {
    return null;
  }
  const payload: SourcePayload = {
    kind: PAYLOAD_KIND,
    v: PAYLOAD_VERSION,
    exportedAt: Date.now(),
    device: currentDeviceName(),
    activeId: activeSourceId(),
    count: entries.length,
    chars: chars,
    sources: entries
  };
  return payload;
}

/** 远端那一段是不是我们的音源载荷（不认识的键/版本一律当"没有"） */
function isSourcePayload(raw: Object | undefined): boolean {
  if (raw === undefined || raw === null) {
    return false;
  }
  const payload = raw as SourcePayload;
  if (payload.kind !== PAYLOAD_KIND) {
    Logger.error(TAG, `音源同步 忽略 载荷 kind=${payload.kind}`);
    return false;
  }
  if (payload.v !== PAYLOAD_VERSION) {
    Logger.error(TAG, `音源同步 忽略 载荷版本 v=${payload.v}（本机支持 ${PAYLOAD_VERSION}）`);
    return false;
  }
  if (!Array.isArray(payload.sources)) {
    Logger.error(TAG, '音源同步 忽略 载荷 sources 不是数组');
    return false;
  }
  return true;
}

/**
 * 合并远端音源段（下行侧，恢复备份时调用）。
 *
 * ★ 全程只调用 lxSourceManager 的两个方法（listFullApis / importApiWithId），
 *   不在同步模块里另持一份音源状态 —— 音源的唯一真源仍然是 LXSourceManager。
 *
 * @param raw 备份 JSON 里的 `customSources` 段；缺省/不认识 = 没有音源，直接返回空报告
 */
export async function applySourcePayload(raw: Object | undefined): Promise<SourceMergeReport> {
  const report: SourceMergeReport = emptyReport();
  if (raw === undefined || raw === null) {
    return report;
  }
  if (!isSourcePayload(raw)) {
    return report;
  }
  const payload = raw as SourcePayload;
  const remote: SourcePayloadEntry[] = payload.sources as SourcePayloadEntry[];
  report.total = remote.length;
  // 本机现状：id -> 脚本原文。冲突判定靠它，不靠时间戳（两边设备时钟不可信）。
  let local: LXUserApiInfoFull[] = [];
  try {
    local = await lxSourceManager.listFullApis();
  } catch (e) {
    Logger.error(TAG, `音源同步 合并失败：本机列表读不到 ${(e as Error).message}`);
    return report;
  }
  const localScripts: Map<string, string> = new Map<string, string>();
  const localVersions: Map<string, string> = new Map<string, string>();
  for (let i: number = 0; i < local.length; i++) {
    const item = local[i];
    localScripts.set(item.id, item.script);
    localVersions.set(item.id, item.version);
  }
  const seenRemote: Set<string> = new Set<string>();
  for (let i: number = 0; i < remote.length; i++) {
    const entry: SourcePayloadEntry = remote[i];
    if (entry === null || entry === undefined || !lxSourceManager.isValidApiId(entry.id)) {
      report.invalid++;
      Logger.error(TAG, '音源同步 跳过 远端条目 id 非法或缺失');
      continue;
    }
    if (seenRemote.has(entry.id)) {
      report.invalid++;
      Logger.error(TAG, `音源同步 跳过 远端条目重复 id=${entry.id}`);
      continue;
    }
    seenRemote.add(entry.id);
    if (typeof entry.script !== 'string' || entry.script.length === 0) {
      report.invalid++;
      Logger.error(TAG, `音源同步 跳过 远端脚本为空 id=${entry.id}`);
      continue;
    }
    if (entry.script.length > MAX_SCRIPT_CHARS) {
      report.invalid++;
      Logger.error(TAG,
        `音源同步 跳过 远端脚本超限 id=${entry.id} chars=${entry.script.length} limit=${MAX_SCRIPT_CHARS}`);
      continue;
    }
    const localScript: string | undefined = localScripts.get(entry.id);
    if (localScript !== undefined) {
      if (localScript === entry.script) {
        report.same++;
        continue;
      }
      // 同 id 不同内容：**保守 —— 保留本机那份**（本机那份就是用户眼前正在用的那份）
      report.conflict++;
      Logger.info(TAG,
        `音源同步 跳过 冲突，保留本机 id=${entry.id} name=${entry.name} 本机version=${localVersions.get(entry.id)} 远端version=${entry.version}`);
      continue;
    }
    const result = lxSourceManager.importApiWithId({
      id: entry.id,
      script: entry.script,
      name: entry.name,
      description: entry.description,
      author: entry.author,
      homepage: entry.homepage,
      version: entry.version,
      allowShowUpdateAlert: entry.allowShowUpdateAlert
    });
    if (result.outcome === 'added') {
      report.added++;
      Logger.info(TAG, `音源同步 落盘 id=${entry.id} name=${entry.name} version=${entry.version}`);
    } else if (result.outcome === 'exists') {
      // 理论上到不了这里（上面已经按 id 判过），真到了就按"已存在"计数，不当失败
      report.same++;
    } else {
      report.failed++;
      Logger.error(TAG, `音源同步 落盘失败 id=${entry.id} : ${result.message}`);
    }
  }
  report.activeApplied = applyRemoteActive(payload.activeId);
  Logger.info(TAG,
    `音源同步 合并 新增=${report.added} 相同=${report.same} 冲突保留本机=${report.conflict} 丢弃=${report.invalid} 失败=${report.failed} 远端共=${report.total} 切选中=${report.activeApplied ? 1 : 0}`);
  return report;
}

/**
 * 按远端记录恢复"选中的音源"，条件收得很紧：
 *   远端有记录 + 本机当前没选 + 这个 id 现在本机确实存在。
 * 任何一条不满足就什么都不做（不抢用户当前的选择）。
 */
function applyRemoteActive(remoteActiveId: string): boolean {
  if (typeof remoteActiveId !== 'string' || remoteActiveId.length === 0) {
    return false;
  }
  if (!lxSourceManager.hasApi(remoteActiveId)) {
    return false;
  }
  const current: string = activeSourceId();
  if (current.length > 0) {
    return false;
  }
  try {
    AppStorage.setOrCreate('lxActiveSource', remoteActiveId);
    MusicStoreService.getInstance().setActiveSource(remoteActiveId);
    Logger.info(TAG, `音源同步 恢复选中 id=${remoteActiveId}`);
    return true;
  } catch (e) {
    Logger.error(TAG, `音源同步 恢复选中失败 id=${remoteActiveId} : ${(e as Error).message}`);
    return false;
  }
}

/** 合并结果 -> 一句给人看的话（拼在恢复成功提示后面） */
export function describeSourceMerge(report: SourceMergeReport): string {
  if (report.total === 0) {
    return '';
  }
  const parts: string[] = [`音源 新增 ${report.added}`];
  if (report.same > 0) {
    parts.push(`已有 ${report.same}`);
  }
  if (report.conflict > 0) {
    parts.push(`保留本机 ${report.conflict}`);
  }
  if (report.invalid > 0) {
    parts.push(`丢弃 ${report.invalid}`);
  }
  if (report.failed > 0) {
    parts.push(`失败 ${report.failed}`);
  }
  if (report.activeApplied) {
    parts.push('已恢复选中');
  }
  return parts.join(' · ');
}

// ------------------------------------------------------------------ 备份/恢复的挂载点

/**
 * 把音源段并进备份 JSON（上行）。
 *
 * ★ 任何一步不顺利都**原样返回入参**：音源同步再重要，也不能把"备份"这件事本身弄坏。
 */
export async function attachSourcesToSnapshot(snapshotText: string): Promise<string> {
  let payload: SourcePayload | null = null;
  try {
    payload = await collectSourcePayload();
  } catch (e) {
    Logger.error(TAG, `音源同步 打包异常，本次备份不带音源：${(e as Error).message}`);
    return snapshotText;
  }
  if (payload === null) {
    Logger.info(TAG, '音源同步 本机没有可搬运的音源，本次备份不带 customSources 段');
    return snapshotText;
  }
  try {
    const snapshot: Record<string, Object> = JSON.parse(snapshotText) as Record<string, Object>;
    snapshot[SOURCE_SYNC_KEY] = payload as Object;
    const merged: string = JSON.stringify(snapshot);
    if (merged.length > MAX_BACKUP_CHARS) {
      Logger.error(TAG,
        `音源同步 跳过 并进来会顶破备份体积闸门 merged=${merged.length} limit=${MAX_BACKUP_CHARS}`);
      return snapshotText;
    }
    Logger.info(TAG,
      `音源同步 上传 ${payload.count} 个（chars=${payload.chars}，备份长度 ${snapshotText.length} -> ${merged.length}）`);
    return merged;
  } catch (e) {
    Logger.error(TAG, `音源同步 并进备份失败：${(e as Error).message}`);
    return snapshotText;
  }
}

/**
 * 从备份 JSON 里取音源段并保守合并（下行）。
 *
 * @returns 给界面看的一句话摘要；备份里没有音源段（旧备份 / 上传方本机没有音源）时返回空串
 */
export async function mergeSourcesFromSnapshot(snapshotText: string): Promise<string> {
  let raw: Object | undefined = undefined;
  try {
    const snapshot: Record<string, Object> = JSON.parse(snapshotText) as Record<string, Object>;
    raw = snapshot[SOURCE_SYNC_KEY];
  } catch (e) {
    Logger.error(TAG, `音源同步 读备份 JSON 失败：${(e as Error).message}`);
    return '';
  }
  if (raw === undefined) {
    Logger.info(TAG, '音源同步 该备份没有 customSources 段（旧版备份，或上传方本机没有音源）');
    return '';
  }
  try {
    const report: SourceMergeReport = await applySourcePayload(raw);
    return describeSourceMerge(report);
  } catch (e) {
    // 音源合并失败**不能**让设置/歌单的恢复结果变成"失败"
    Logger.error(TAG, `音源同步 合并异常（不影响设置/歌单恢复）：${(e as Error).message}`);
    return '';
  }
}

