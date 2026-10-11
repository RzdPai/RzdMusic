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

import { LXUserApiInfo, LXUserApiSourceInfo } from '../source/Interface';

/** 平台 id 的顺序：与 LX 生态一致（酷我 / 酷狗 / QQ / 网易云 / 咪咕）。 */
const LX_PLATFORM_ORDER: string[] = ['kw', 'kg', 'tx', 'wy', 'mg'];
/** 平台 id → 中文名；取不到时原样回平台 id（**不要**兜成「酷我」那样会误导）。 */
const LX_SOURCE_NAMES: Record<string, string> = {
  'kw': '酷我',
  'kg': '酷狗',
  'tx': 'QQ',
  'wy': '网易云',
  'mg': '咪咕',
  'local': '本地'
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
  'musicUrl': '取链接',
  'lyric': '歌词',
  'pic': '封面',
  'musicSearch': '搜索'
};

const LX_ACTION_ORDER: string[] = ['musicUrl', 'lyric', 'pic', 'musicSearch'];

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
  const label: string | undefined = LX_SOURCE_NAMES[source];
  return label === undefined ? source : label;
}

/**
 * 平台显示名：内置 id（kw/kg/tx/wy/mg/local）走内置中文名；
 * 声明里出现的内置表之外的平台，退回脚本自己写的 `name`；都没有才回 id。
 */
function lxSourceDisplayLabel(source: string, declaredName: string): string {
  if (LX_SOURCE_NAMES[source] !== undefined) {
    return lxSourceLabel(source);
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
 * 把一条音源脚本声明的 `sources` 收敛成界面用的摘要列表。
 *
 * 顺序：先按 `LX_PLATFORM_ORDER`（酷我 → 酷狗 → QQ → 网易云 → 咪咕），
 * 其余未知平台按声明顺序跟在后面。
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
  for (let i: number = 0; i < keys.length; i++) {
    const source: string = keys[i];
    const info: LXUserApiSourceInfo = sources[source];
    if (info === undefined || info === null) {
      continue;
    }
    const declared: string[] = declaredQualitysOf(info);
    // ⚠️ 两个音质字段都要**过一遍 `lxQualityLabel`**：`bestQualityOf` 返回的是脚本里那个
    //    档位 id（`flac` / `flac24bit` / `atmos_plus`），直接显示就是「最高flac24bit」这种生串。
    const best: string = bestQualityOf(declared);
    const declaredName: string = (info.name !== undefined && info.name !== null) ? info.name : '';
    const item: LXSourcePlatformInfo = {
      source: source,
      label: lxSourceDisplayLabel(source, declaredName),
      defaultQuality: (info.type !== undefined && info.type !== null && info.type.length > 0) ?
        lxQualityLabel(info.type) : '',
      bestQuality: best.length > 0 ? lxQualityLabel(best) : '',
      actions: declaredActionsOf(info)
    };
    out.push(item);
  }
  return out;
}

/**
 * 便捷入口：直接看某条 `LXUserApiInfo`（音源列表里那一项）声明了哪些平台。
 *
 * @param info 音源列表项（`lxSourceManager.getApiList()` 的元素）。
 */
export function lxDeclaredPlatformsOf(info: LXUserApiInfo | undefined): LXSourcePlatformInfo[] {
  if (info === undefined || info === null) {
    return [];
  }
  return lxDeclaredPlatforms(info.sources);
}
