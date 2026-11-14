/*
 * 音源脚本「声明了什么」的只读摘要。
 *
 * 数据来源（唯一真源，不另造一份）：
 *   `LXSourceManager.saveApiSources()` 把脚本 init 事件上报的 `sources`
 *   （`Record<平台id, LXUserApiSourceInfo{ name, type, actions, qualitys }>`）
 *   持久化进 `lx_api_list.json` 的 `apis[].sources`；
 *   引擎就绪时同一份数据也会 JSON 化写进 `AppStorage['lxEngineSources']`。
 *
 * 这一层只做「把声明翻译成人能看的短标签」，**不猜**：
 *   脚本没声明过就是空数组，由界面给中性提示（「未检测」），
 *   不允许因为「LX 一般支持 128k/320k/flac」就补上默认值。
 *
 * 谁在用：`features/setting` 的「音源管理」（SettingsDetailPage / SettingPage）。
 */

import { LXUserApiInfo, LXUserApiSourceInfo, MfSubscriptionInfo } from '../source/Interface';

/**
 * 「这个字符串是不是一个裸域名」——`13413.kstore.vip`、`mf.example.com:8080`。
 *
 * ★ 2026-11-09（用户：「只显示域名太难看了」）：联网订阅的 `name` 就是主机名，
 *   只能拿来去重，不能直接上屏。显示前用这个判一下。
 */
export function looksLikeHostName(name: string): boolean {
  const text: string = name.trim();
  if (text.length === 0 || text.indexOf(' ') >= 0) {
    return false;
  }
  return /^[a-z0-9][a-z0-9-]*(\.[a-z0-9][a-z0-9-]*)+(:\d+)?$/i.test(text);
}

/**
 * 订阅（= 用户眼里的「音源」）的展示名。
 *
 * 优先级：用户备注 > 订阅自带的人类可读名 > 中性兜底。
 * **绝不返回裸域名** —— 域名只在「关于」里作为来源线索出现。
 *
 * @param sub 订阅记录（可能为空：插件是独立导入的）
 * @param ordinal 同列表里的序号（从 1 开始，多份订阅时用于区分）
 * @param total 列表里一共有几份订阅（>1 时中性名才带序号，单份不啰嗦）
 */
export function musicFreeSubscriptionLabel(sub: MfSubscriptionInfo | undefined, ordinal: number = 0,
  total: number = 0): string {
  if (sub === undefined) {
    return '独立导入';
  }
  const rawRemark: string | undefined = sub.remark;
  const remark: string = rawRemark !== undefined ? rawRemark.trim() : '';
  if (remark.length > 0) {
    return remark;
  }
  const name: string = sub.name !== undefined ? sub.name.trim() : '';
  if (name.length > 0 && !looksLikeHostName(name)) {
    return name;
  }
  return total > 1 && ordinal > 0 ? ('MusicFree 订阅 ' + ordinal.toString()) : 'MusicFree 订阅';
}

/**
 * 平台 id 的顺序：与 LX 生态一致（酷我 / 酷狗 / QQ / 网易云 / 咪咕 / 汽水）。
 *
 * ★ 全仓**唯一**的「内置平台清单」定义 —— `PlatformRegistry.builtin()` 也从这里派生，
 *   不要再在别处写第二份 `['kw','kg',...]`。
 */
export const LX_PLATFORM_ORDER: string[] = ['kw', 'kg', 'tx', 'wy', 'mg', 'qs'];
/**
 * 平台 id 别名 → 主 id。
 *
 * ★ 用户 2026-11-08：「汽水 svip 不应该和汽水作为一个吗」——
 *   脚本里同一个平台有多种写法（`qs` / `qsvip` / `soda` / `qishui`），此前被当成
 *   互不相干的平台各占一行。统一在这里折叠，**全仓只此一份**：
 *   平台管理清单、音源标签、PlatformRegistry 的启用/排序/过滤都用它。
 */
const PLATFORM_ALIAS: Record<string, string> = {
  'qsvip': 'qs',
  'qs_vip': 'qs',
  'soda': 'qs',
  'qishui': 'qs'
};

/** 不是「在线音乐平台」的 sources key：本地文件不是平台，不进平台管理。 */
const NON_PLATFORM_IDS: string[] = ['local'];

/**
 * 平台 id 归一化：小写 + 别名折叠。
 * 例：`qsvip` → `qs`，`Soda` → `qs`，`kw` → `kw`。
 */
export function normalizePlatformId(id: string): string {
  const trimmed: string = id.trim();
  // ★ MusicFree 平台 id 是 `mfplat:` + 插件 id（旧版是 `mf:` + 插件名），
  //   大小写有意义（「元力B站」的 B 不能降成 b）—— 这里原样保留，否则注册与勾选永远对不上。
  if (trimmed.startsWith(MF_PLATFORM_PREFIX) || trimmed.startsWith('mf:')) {
    return trimmed;
  }
  const key: string = trimmed.toLowerCase();
  const mapped: string | undefined = PLATFORM_ALIAS[key];
  return mapped !== undefined ? mapped : key;
}

/** 该 sources key 是否算「在线平台」（`local` 之类不算）。 */
export function isOnlinePlatformId(id: string): boolean {
  const normalized: string = normalizePlatformId(id);
  return normalized.length > 0 && NON_PLATFORM_IDS.indexOf(normalized) < 0;
}

/**
 * 平台名 → 项目内的平台 id（MusicFree 插件 / LX 脚本共用的唯一识别入口）。
 *
 * 插件声明的 `platform` 五花八门（「元力WY」「元力QQ」「网易」「酷gou」「哔哩哔哩」…），
 * 这里做**保守**推断：认不出来就返回空串，由调用方决定是否作为动态平台
 * （`mf:<label>`）呈现 —— **不要**硬塞成酷我，那会让换源彻底走错。
 *
 * ★ 2026-11-09：从 MusicFreeAdapter 移到 util 层 —— 平台注册表与搜索路由都要用，
 *   放 source 层会造成 `PlatformRegistry → MusicFreeAdapter → LXSourceManager → PlatformRegistry`
 *   的循环依赖。
 */
export function platformIdFromLabel(label: string): string {
  const s: string = label.trim().toUpperCase();
  if (s.length === 0) {
    return '';
  }
  // 先看「元力XX」这类短代号（元力KW / 元力WY / 元力QQ / 元力MG / 元力KG）
  const short: RegExpExecArray | null = /元力\s*([A-Z]{2,4})/.exec(s);
  const token: string = short !== null ? short[1] : s;
  if (token.indexOf('WY') >= 0 || token.indexOf('WYY') >= 0 || s.indexOf('网易') >= 0 ||
    s.indexOf('NETEASE') >= 0) {
    return 'wy';
  }
  if (token.indexOf('KW') >= 0 || s.indexOf('酷我') >= 0 || s.indexOf('KUWO') >= 0) {
    return 'kw';
  }
  if (token.indexOf('KG') >= 0 || s.indexOf('酷狗') >= 0 || s.indexOf('KUGOU') >= 0 ||
    s.indexOf('酷GOU') >= 0) {
    return 'kg';
  }
  if (token.indexOf('QQ') >= 0 || token.indexOf('TX') >= 0 || s.indexOf('QQ音乐') >= 0 ||
    s.indexOf('TENCENT') >= 0) {
    return 'tx';
  }
  if (token.indexOf('MG') >= 0 || s.indexOf('咪咕') >= 0 || s.indexOf('MIGU') >= 0) {
    return 'mg';
  }
  if (token.indexOf('QS') >= 0 || s.indexOf('汽水') >= 0 || s.indexOf('SODA') >= 0 ||
    s.indexOf('QISHUI') >= 0) {
    return 'qs';
  }
  // MusicFree 生态里常见的「LX 六平台之外」的平台：保留为独立平台（用户要它们共存）
  if (s.indexOf('BILI') >= 0 || s.indexOf('B站') >= 0 || s.indexOf('哔哩') >= 0) {
    return 'bilibili';
  }
  if (s.indexOf('YOUTUBE') >= 0 || s.indexOf('YT') === 0 || s.indexOf('油管') >= 0) {
    return 'youtube';
  }
  if (s.indexOf('SPOTIFY') >= 0) {
    return 'spotify';
  }
  if (s.indexOf('APPLE') >= 0 || s.indexOf('ITUNES') >= 0) {
    return 'apple';
  }
  if (s.indexOf('XM') >= 0 || s.indexOf('喜马拉雅') >= 0 || s.indexOf('XIMALAYA') >= 0) {
    return 'xm';
  }
  return '';
}

/**
 * MusicFree 平台 id 前缀：`mfplat:` + 插件 id。
 *
 * ★ 2026-11-09（用户：「平台里面显示两个酷我，一个洛雪、一个跟随源名」）：
 *   平台清单改成一来源一条目 —— **每个 MusicFree 插件自己就是一个平台**，
 *   不再把「元力WY / 小蜗WY」折叠成同一个 `wy`。这样用户能在平台管理里
 *   分别勾选，搜索页也能同时展示「酷我（洛雪）」和「元力KW」。
 */
export const MF_PLATFORM_PREFIX: string = 'mfplat:';

/** 插件 id → 平台 id（一插件一平台）。 */
export function mfPlatformIdOf(apiId: string): string {
  return MF_PLATFORM_PREFIX + apiId;
}

/** 平台 id → 插件 id；不是 MusicFree 平台时返回空串。 */
export function mfApiIdOf(platformId: string): string {
  if (platformId.startsWith(MF_PLATFORM_PREFIX)) {
    return platformId.substring(MF_PLATFORM_PREFIX.length);
  }
  // 旧数据兼容：`mf:` + 插件名没有 apiId 语义，交给调用方按名字兜底
  return '';
}

/** 是否为 MusicFree 平台 id。 */
export function isMfPlatformId(id: string): boolean {
  return id.startsWith(MF_PLATFORM_PREFIX) || id.startsWith('mf:');
}

/** 平台 id 的展示名：LX 内置走中文名，`mf:` 前缀取插件自报的名字。 */
export function platformLabel(id: string): string {
  if (isMfPlatformId(id)) {
    // 平台展示名由 PlatformRegistry 按插件名给出；这里只做兜底
    // （`mfplat:` 后面是 apiId，不适合直接当名字显示）
    if (id.startsWith(MF_PLATFORM_PREFIX)) {
      return 'MusicFree';
    }
    const label: string = id.substring(3);
    return label.length > 0 ? label : 'MusicFree';
  }
  const normalized: string = normalizePlatformId(id);
  const fallback: string = lxSourceLabel(normalized);
  const extra: string | undefined = EXTRA_PLATFORM_NAMES[normalized];
  return extra !== undefined ? extra : fallback;
}

/** LX 六平台之外、但已经被识别成稳定 id 的平台中文名（不要散落到 UI 里）。 */
const EXTRA_PLATFORM_NAMES: Record<string, string> = {
  'bilibili': '哔哩哔哩',
  'youtube': 'YouTube',
  'spotify': 'Spotify',
  'apple': 'Apple Music'
};

/** 能否用项目内置搜索（`lxSearch`）直接查这个平台。 */
export function isLxSearchPlatform(id: string): boolean {
  return LX_PLATFORM_ORDER.indexOf(normalizePlatformId(id)) >= 0;
}

/** 平台 id → 中文名；取不到时原样回平台 id（**不要**兜成「酷我」那样会误导）。 */
const LX_SOURCE_NAMES: Record<string, string> = {
  'kw': '酷我',
  'kg': '酷狗',
  'tx': 'QQ',
  'wy': '网易云',
  'qs': '汽水',
  'soda': '汽水',
  'qishui': '汽水',
  'qsvip': '汽水',
  'qs_vip': '汽水',
  'xm': '喜马拉雅',
  'bd': '百度',
  'mg': '咪咕',
  'local': ''
};

/** 内置可选音质档 → 短标签（与设置页音质档命名保持一致）。 */
const LX_QUALITY_LABELS: Record<string, string> = {
  '128k': '128K',
  '320k': '320K',
  '192k': '192K',
  'flac': 'FLAC',
  'flac24bit': '24Bit',
  'ape': 'APE',
  'wav': 'WAV',
  'hires': 'Hi-Res',
  'atmos': '全景声',
  'atmos_plus': '全景声+',
  'master': '母带'
};

/** 由高到低；用来把脚本声明的 qualitys 收敛成「最高一档」。 */
const LX_QUALITY_ORDER: string[] = [
  'master', 'atmos_plus', 'atmos', 'hires', 'flac24bit', 'flac',
  '320k', '192k', '128k', 'ape', 'wav'
];

/** 动作 id → 短标签。未列出的动作原样回 id（宁可露英文也不静默丢掉）。 */
const LX_ACTION_LABELS: Record<string, string> = {
  'musicUrl': '',
  'lyric': '歌词',
  'pic': '封面',
  'musicSearch': '搜索'
};

// ★ 用户 2026-10-11：「音质说明的『取链接』删掉」⇒ 动作说明里不再列 musicUrl。
const LX_ACTION_ORDER: string[] = ['lyric', 'pic', 'musicSearch'];

/**
 * 一条音源脚本「声明了哪些平台 / 什么音质 / 能做什么」的摘要。
 */
export interface LXSourcePlatformInfo {
  /** 平台 id（`kw` / `wy` / …）；声明里未知的 id 也原样保留。 */
  source: string;
  /** 平台中文名（未知 id 时依次退回脚本自己写的 `name`、再退回 id）。 */
  label: string;
  /** 默认音质（`info.type`）的中文短标签；未声明为空串。 */
  defaultQuality: string;
  /** 声明支持的最高音质短标签（按 `LX_QUALITY_ORDER` 取第一个命中的）；未声明为空串。 */
  bestQuality: string;
  /** 动作短标签（按 `LX_ACTION_ORDER` 排序）；未声明为空数组。 */
  actions: string[];
}

/** 平台 id → 中文名；取不到时原样返回 id（**不做兜底猜测**）。 */
export function lxSourceLabel(source: string): string {
  const normalized: string = normalizePlatformId(source);
  const label: string | undefined = LX_SOURCE_NAMES[normalized];
  if (label !== undefined) {
    return label;
  }
  // 别名表里没写的自定义平台：原样返回（别把 `qsvip` 硬翻成别的平台名）
  return source.length > 0 ? source : normalized;
}

/**
 * 平台显示名：内置 id（kw/kg/tx/wy/mg/local）走内置中文名；
 * 声明里出现的内置表之外的平台，退回脚本自己写的 `name`；都没有才回 id。
 */
function lxSourceDisplayLabel(source: string, declaredName: string): string {
  const normalized: string = normalizePlatformId(source);
  if (LX_SOURCE_NAMES[normalized] !== undefined) {
    return lxSourceLabel(normalized);
  }
  return declaredName.length > 0 ? declaredName : source;
}

/** 音质 id → 短标签；取不到原样返回。 */
export function lxQualityLabel(quality: string): string {
  const label: string | undefined = LX_QUALITY_LABELS[quality];
  return label === undefined ? quality : label;
}

/** 动作 id → 短标签；取不到原样返回。 */
export function lxActionLabel(action: string): string {
  const label: string | undefined = LX_ACTION_LABELS[action];
  return label === undefined ? action : label;
}

function declaredQualitysOf(info: LXUserApiSourceInfo): string[] {
  const list: string[] = [];
  // ⚠️ 这里的 `null` 判断是**必要的**：`LXUserApiSourceInfo` 是从 JSON.parse 出来的
  //    外部数据（脚本自己写的），类型标注挡不住它缺字段。不要按"类型说有就一定有"删掉。
  if (info.qualitys === undefined || info.qualitys === null) {
    return list;
  }
  for (let i: number = 0; i < info.qualitys.length; i++) {
    const q: string = info.qualitys[i];
    if (q !== undefined && q !== null && q.length > 0) {
      list.push(q);
    }
  }
  return list;
}

function bestQualityOf(declared: string[]): string {
  for (let i: number = 0; i < LX_QUALITY_ORDER.length; i++) {
    if (declared.indexOf(LX_QUALITY_ORDER[i]) >= 0) {
      return LX_QUALITY_ORDER[i];
    }
  }
  // 全是未知档位：原样报第一个，让用户看到脚本自己的写法
  return declared.length > 0 ? declared[0] : '';
}

function declaredActionsOf(info: LXUserApiSourceInfo): string[] {
  const out: string[] = [];
  if (info.actions === undefined || info.actions === null) {
    return out;
  }
  for (let i: number = 0; i < LX_ACTION_ORDER.length; i++) {
    if (info.actions.indexOf(LX_ACTION_ORDER[i]) >= 0) {
      out.push(lxActionLabel(LX_ACTION_ORDER[i]));
    }
  }
  for (let i: number = 0; i < info.actions.length; i++) {
    const action: string = info.actions[i];
    if (action === undefined || action === null || action.length === 0) {
      continue;
    }
    if (LX_ACTION_ORDER.indexOf(action) < 0) {
      out.push(lxActionLabel(action));
    }
  }
  return out;
}

/**
 * 合并同一平台的两条声明（`qs` + `qsvip`）：
 * 音质取**更高**的一档，动作取并集，名字/默认音质保留先出现的那条。
 */
function mergePlatformInfo(base: LXSourcePlatformInfo, extra: LXSourcePlatformInfo): LXSourcePlatformInfo {
  const baseRank: number = LX_QUALITY_ORDER.indexOf(base.bestQuality);
  const extraRank: number = LX_QUALITY_ORDER.indexOf(extra.bestQuality);
  const bestQuality: string =
    (extraRank >= 0 && (baseRank < 0 || extraRank < baseRank)) ? extra.bestQuality : base.bestQuality;
  const actions: string[] = base.actions.slice();
  for (let i: number = 0; i < extra.actions.length; i++) {
    if (actions.indexOf(extra.actions[i]) < 0) {
      actions.push(extra.actions[i]);
    }
  }
  return {
    source: base.source,
    label: base.label,
    defaultQuality: base.defaultQuality.length > 0 ? base.defaultQuality : extra.defaultQuality,
    bestQuality: bestQuality,
    actions: actions
  };
}

/**
 * 把一条音源脚本声明的 `sources` 收敛成界面用的摘要列表。
 *
 * 顺序：先按 `LX_PLATFORM_ORDER`（酷我 → 酷狗 → QQ → 网易云 → 咪咕），
 * 其余未知平台按声明顺序跟在后面。
 *
 * ★ 2026-11-08：同一平台的别名（`qs` / `qsvip` / `soda`）**合并成一行**，
 *   不再各自占一条（用户：「汽水 svip 不应该和汽水作为一个吗」）。
 *
 * @param sources 脚本 init 上报并已持久化的 `sources`；未检测到时传 `undefined` / `{}`。
 * @returns 每个声明平台一条；**没声明就返回空数组**（界面据此给中性提示）。
 */
export function lxDeclaredPlatforms(
  sources: Record<string, LXUserApiSourceInfo> | undefined): LXSourcePlatformInfo[] {
  const out: LXSourcePlatformInfo[] = [];
  if (sources === undefined || sources === null) {
    return out;
  }
  const keys: string[] = [];
  for (let i: number = 0; i < LX_PLATFORM_ORDER.length; i++) {
    if (sources[LX_PLATFORM_ORDER[i]] !== undefined) {
      keys.push(LX_PLATFORM_ORDER[i]);
    }
  }
  const all: string[] = Object.keys(sources);
  for (let i: number = 0; i < all.length; i++) {
    if (LX_PLATFORM_ORDER.indexOf(all[i]) < 0) {
      keys.push(all[i]);
    }
  }
  /** 归一化平台 id → out 里的下标（用于合并别名）。 */
  const indexById: Map<string, number> = new Map();
  for (let i: number = 0; i < keys.length; i++) {
    const source: string = keys[i];
    const info: LXUserApiSourceInfo = sources[source];
    if (info === undefined || info === null) {
      continue;
    }
    const normalized: string = normalizePlatformId(source);
    if (normalized.length === 0) {
      continue;
    }
    const declared: string[] = declaredQualitysOf(info);
    // ⚠️ 两个音质字段都要**过一遍 `lxQualityLabel`**：`bestQualityOf` 返回的是脚本里那个
    //    档位 id（`flac` / `flac24bit` / `atmos_plus`），直接显示就是「最高flac24bit」这种生串。
    const best: string = bestQualityOf(declared);
    const declaredName: string = (info.name !== undefined && info.name !== null) ? info.name : '';
    const item: LXSourcePlatformInfo = {
      source: normalized,
      label: lxSourceDisplayLabel(normalized, declaredName),
      defaultQuality: (info.type !== undefined && info.type !== null && info.type.length > 0) ?
        lxQualityLabel(info.type) : '',
      bestQuality: best.length > 0 ? lxQualityLabel(best) : '',
      actions: declaredActionsOf(info)
    };
    const existing: number | undefined = indexById.get(normalized);
    if (existing === undefined) {
      indexById.set(normalized, out.length);
      out.push(item);
    } else {
      out[existing] = mergePlatformInfo(out[existing], item);
    }
  }
  return out;
}

/**
 * 便捷入口：直接看某条 `LXUserApiInfo`（音源列表里那一项）声明了哪些平台。
 *
 * ★ 2026-11-09（用户：「LX 是修改支持的平台」）：用户裁过平台就以
 *   `platformOverride` 为准 —— 界面（关于气泡 / 音源标签）与播放兜底链看到的是同一份。
 *
 * @param info 音源列表项（`lxSourceManager.getApiList()` 的元素）。
 */
export function lxDeclaredPlatformsOf(info: LXUserApiInfo | undefined): LXSourcePlatformInfo[] {
  if (info === undefined || info === null) {
    return [];
  }
  const override: string[] | undefined = info.platformOverride;
  if (override !== undefined && override !== null && override.length > 0) {
    return declaredPlatformsWithOverride(info.sources, override);
  }
  return lxDeclaredPlatforms(info.sources);
}

/**
 * 用「用户勾选的平台」裁一遍声明：只留勾上的，声明里没有的按最简信息补一条。
 *
 * @param sources 脚本 init 上报的声明（可能为空，用户手动补平台时不依赖它）
 * @param override 用户勾选的规范平台 id
 */
function declaredPlatformsWithOverride(
  sources: Record<string, LXUserApiSourceInfo> | undefined,
  override: string[]): LXSourcePlatformInfo[] {
  const declared: LXSourcePlatformInfo[] = lxDeclaredPlatforms(sources);
  const byId: Map<string, LXSourcePlatformInfo> = new Map();
  for (let i: number = 0; i < declared.length; i++) {
    byId.set(declared[i].source, declared[i]);
  }
  const out: LXSourcePlatformInfo[] = [];
  // 先按内置顺序，保证界面顺序稳定；再补 override 里剩下的
  for (let i: number = 0; i < LX_PLATFORM_ORDER.length; i++) {
    const id: string = LX_PLATFORM_ORDER[i];
    if (override.indexOf(id) < 0) {
      continue;
    }
    out.push(byId.get(id) ?? emptyPlatformInfo(id));
  }
  for (let i: number = 0; i < override.length; i++) {
    const id: string = normalizePlatformId(override[i]);
    if (id.length > 0 && LX_PLATFORM_ORDER.indexOf(id) < 0 && !containsPlatform(out, id)) {
      out.push(byId.get(id) ?? emptyPlatformInfo(id));
    }
  }
  return out;
}

function containsPlatform(list: LXSourcePlatformInfo[], id: string): boolean {
  for (let i: number = 0; i < list.length; i++) {
    if (list[i].source === id) {
      return true;
    }
  }
  return false;
}

/** 用户手动补的平台：没有声明数据，只给平台名（音质/动作留空，不猜）。 */
function emptyPlatformInfo(id: string): LXSourcePlatformInfo {
  return {
    source: id,
    label: lxSourceLabel(id),
    defaultQuality: '',
    bestQuality: '',
    actions: []
  };
}
