/*
 * 平台注册表：**平台清单 + 用户勾选 + 排序**的唯一真源。
 *
 * ★ 术语（用户 2026-11-08 定稿，全仓统一）：
 *   - 音源 = 用户导入的 JS 脚本（LX 脚本 / MusicFree 插件）
 *   - 平台 = 搜索页 / 歌单广场上可以单独勾选、单独展示的一栏
 *
 * ★ 2026-11-09 第三次改版（用户：「源和平台都分开」「平台里面显示两个酷我，
 *   一个用洛雪的，一个跟随源显示的名称」）：
 *
 *   1. 平台清单 = **洛雪固定六平台 + 每个 MusicFree 插件各算一个平台**。
 *      - 洛雪六平台是常量，**绝不扫描 LX 脚本的 `sources`**（脚本会虚标）；
 *      - MusicFree 插件一插件一平台，id = `mfplat:<插件id>`，名字跟随插件名
 *        （小蜗 / 元力KW / 元力WY…），所以「酷我」可能出现两行，用户自己勾。
 *   2. 不再有 `verified`（源实际支持平台）这一层 —— 那是把源和平台绑在一起的根源，
 *      已整层删除；源脚本的 `sources` 现在只用于「这个源能不能给某平台供源」的
 *      运行时匹配，以及源卡片「关于」气泡的展示。
 *   3. 勾选 = 该平台要不要出现在搜索 / 广场；排序 = 平台的展示顺序。
 *      两者都只作用在**平台**上，与「源是否启用」完全解耦。
 *
 * ★ 默认勾选（用户口径：「刚导入时就不勾选洛雪已有的平台」）：
 *   MusicFree 插件所属平台能被识别成洛雪六平台之一时，默认**不勾选**；
 *   洛雪没有的平台（哔哩哔哩 / YouTube…）默认勾选。判定只做一次，用户改过就固化。
 *
 * 持久化用独立 preferences（store name = platform_registry）；
 * 存「被取消勾选的平台」而不是「启用列表」—— 新平台默认启用，老用户升级不会全暗。
 *
 * ⚠️ 只用普通单例类（无 UI 装饰器）：UI 侧用 @Local 快照驱动刷新，避免 V1/V2 混用。
 */

import { preferences } from '@kit.ArkData';
import { getAppRuntime, MusicStoreService } from 'musicbasic';
import { LXUserApiInfo } from '../source/Interface';
import { lxSourceManager } from '../source/LXSourceManager';
import {
  isLxSearchPlatform, isMfPlatformId, LX_PLATFORM_ORDER, lxSourceLabel, mfApiIdOf, mfPlatformIdOf,
  normalizePlatformId, platformIdFromLabel
} from './SourceDeclaredInfo';

const STORE_NAME: string = 'platform_registry';
/** v3：平台模型从「逻辑平台 + verified」改成「一来源一平台」，旧键一律不复用。 */
const KEY_DISABLED: string = 'disabled_v3';
const KEY_ORDER: string = 'order_v3';
/** 已经按默认规则处理过的 MusicFree 插件 id（只处理一次，避免每次启动改用户选择）。 */
const KEY_MF_DEFAULTED: string = 'mf_defaulted_v1';

/** 平台来源：洛雪（内置接口 + LX 脚本）/ MusicFree 插件。 */
export type PlatformOrigin = 'lx' | 'musicfree';

/** 平台清单里的一行。 */
export interface PlatformDef {
  /** `kw` / `kg` / … / `mfplat:<插件id>` */
  id: string;
  /** 展示名：洛雪平台用中文名；MusicFree 用插件名（小蜗 / 元力KW）。 */
  label: string;
  origin: PlatformOrigin;
  /** MusicFree 插件 id；洛雪平台为空串。 */
  apiId: string;
  /** 副标题（「洛雪内置」/「MusicFree · 网易」）。 */
  subtitle: string;
  /**
   * 该平台背后的源是否在「音源管理」里启用。
   * 洛雪平台恒 true；MusicFree 源被停用时平台仍列出来（用户要「显示所有平台」），
   * 但勾选框禁用，搜索 / 广场也不会用它。
   */
  sourceEnabled: boolean;
}

function buildBuiltinPlatforms(): PlatformDef[] {
  const out: PlatformDef[] = [];
  for (let i: number = 0; i < LX_PLATFORM_ORDER.length; i++) {
    const id: string = LX_PLATFORM_ORDER[i];
    out.push({
      id: id,
      label: lxSourceLabel(id),
      origin: 'lx',
      apiId: '',
      subtitle: '洛雪内置',
      sourceEnabled: true
    });
  }
  return out;
}

const LX_BUILTIN: PlatformDef[] = buildBuiltinPlatforms();

function readStringArray(store: preferences.Preferences, key: string): string[] {
  let raw: string = '';
  try {
    raw = store.getSync(key, '') as string;
  } catch (_e) {
    return [];
  }
  if (raw.length === 0) {
    return [];
  }
  try {
    const parsed: Object = JSON.parse(raw) as Object;
    if (!Array.isArray(parsed)) {
      return [];
    }
    const out: string[] = [];
    for (let i: number = 0; i < (parsed as Object[]).length; i++) {
      const v: string = String((parsed as Object[])[i] ?? '');
      if (v.length > 0 && out.indexOf(v) < 0) {
        out.push(v);
      }
    }
    return out;
  } catch (_e) {
    return [];
  }
}

/** MusicFree 插件在平台清单里的名字：用户备注 > 运行时平台名 > 导入时的来源名。 */
function mfLabelOf(api: LXUserApiInfo): string {
  const rawRemark: string | undefined = api.remark;
  const remark: string = rawRemark !== undefined ? rawRemark.trim() : '';
  if (remark.length > 0) {
    return remark;
  }
  // ★ 2026-11-09（用户：「现在平台全都显示元力音源」）：platform 是插件**自己**报的
  //   平台名（元力WY / bilibili），比订阅项名（网易 / qq）更接近 MusicFree 原版；
  //   name 只在平台还没识别出来时兜底，绝不能再反过来盖住 platform。
  const platform: string = api.platform !== undefined ? api.platform.trim() : '';
  if (platform.length > 0) {
    return platform;
  }
  const name: string = api.name !== undefined ? api.name.trim() : '';
  return name.length > 0 ? name : 'MusicFree 插件';
}

/** MusicFree 平台的副标题：能说清「插件对应哪个平台」就说，重复就不说。 */
function mfSubtitleOf(api: LXUserApiInfo): string {
  const platform: string = api.platform !== undefined ? api.platform.trim() : '';
  const name: string = mfLabelOf(api);
  if (platform.length > 0 && platform !== name) {
    return 'MusicFree · ' + platform;
  }
  return 'MusicFree';
}

class PlatformRegistryImpl {
  private static instance: PlatformRegistryImpl | undefined = undefined;
  private store: preferences.Preferences | undefined = undefined;
  private loaded: boolean = false;

  private disabledIds: string[] = [];
  private orderIds: string[] = [];
  private mfDefaulted: string[] = [];
  /** 平台 id → 展示名（allPlatforms 时刷新，供 UI 的 sourceName / 行标签使用）。 */
  private labelCache: Map<string, string> = new Map();

  static getInstance(): PlatformRegistryImpl {
    if (PlatformRegistryImpl.instance === undefined) {
      PlatformRegistryImpl.instance = new PlatformRegistryImpl();
    }
    return PlatformRegistryImpl.instance;
  }

  private getStore(): preferences.Preferences | undefined {
    if (this.store !== undefined) {
      return this.store;
    }
    const ctx = getAppRuntime().context;
    if (ctx === undefined) {
      return undefined;
    }
    try {
      this.store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
    } catch (_e) {
      return undefined;
    }
    return this.store;
  }

  /** 懒加载：context 尚未就绪时不置 loaded，下次调用会重试。 */
  private ensureLoaded(): void {
    if (this.loaded) {
      return;
    }
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    this.disabledIds = readStringArray(store, KEY_DISABLED);
    this.orderIds = readStringArray(store, KEY_ORDER);
    this.mfDefaulted = readStringArray(store, KEY_MF_DEFAULTED);
    this.loaded = true;
  }

  private persist(): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    try {
      store.putSync(KEY_DISABLED, JSON.stringify(this.disabledIds));
      store.putSync(KEY_ORDER, JSON.stringify(this.orderIds));
      store.putSync(KEY_MF_DEFAULTED, JSON.stringify(this.mfDefaulted));
      store.flush();
    } catch (_e) {
      // preferences 写失败不阻断 UI；内存态仍有效，下次操作会重试持久化。
    }
  }

  /** 洛雪固定六平台（返回副本）。 */
  builtin(): PlatformDef[] {
    const out: PlatformDef[] = [];
    for (let i: number = 0; i < LX_BUILTIN.length; i++) {
      out.push({
        id: LX_BUILTIN[i].id,
        label: LX_BUILTIN[i].label,
        origin: LX_BUILTIN[i].origin,
        apiId: '',
        subtitle: LX_BUILTIN[i].subtitle,
        sourceEnabled: true
      });
    }
    return out;
  }

  /** 是否洛雪六平台之一。 */
  isBuiltin(id: string): boolean {
    return isLxSearchPlatform(id) && !isMfPlatformId(id);
  }

  /** 是否 MusicFree 平台（一插件一平台）。 */
  isMfPlatform(id: string): boolean {
    return isMfPlatformId(id);
  }

  /** 平台 id → 插件 id（洛雪平台返回空串）。 */
  apiIdOfPlatform(id: string): string {
    return mfApiIdOf(id);
  }

  /**
   * 默认勾选规则，只对**本次第一次见到**的 MusicFree 插件执行：
   * 插件能归到洛雪六平台 → 默认不勾；洛雪没有的平台 → 默认勾。
   */
  private applyMfDefaults(apis: LXUserApiInfo[]): void {
    const enabledSourceIds: string[] = this.enabledSourceIds(apis);
    let changed: boolean = false;
    for (let i: number = 0; i < apis.length; i++) {
      const api: LXUserApiInfo = apis[i];
      if (api.kind !== 'mf' || api.id.length === 0) {
        continue;
      }
      if (enabledSourceIds.indexOf(api.id) < 0) {
        continue;
      }
      if (this.mfDefaulted.indexOf(api.id) >= 0) {
        continue;
      }
      // 平台名还没识别出来（元力系插件要跑起来才知道）⇒ 先不定默认值，
      // 等后台回填成「元力WY」后再按「洛雪已有 → 不勾」处理；
      // 现在就定会把未知平台当成「洛雪没有」而默认勾上，回填后又不能改。
      const platformName: string = api.platform !== undefined ? api.platform.trim() : '';
      const fallbackName: string = platformIdFromLabel(api.name).length > 0 ? api.name : '';
      const judgeName: string = platformName.length > 0 ? platformName : fallbackName;
      if (judgeName.length === 0) {
        continue;
      }
      this.mfDefaulted.push(api.id);
      const logical: string = platformIdFromLabel(judgeName);
      const lxHasIt: boolean = isLxSearchPlatform(logical);
      const platformId: string = mfPlatformIdOf(api.id);
      const idx: number = this.disabledIds.indexOf(platformId);
      if (lxHasIt && idx < 0) {
        this.disabledIds.push(platformId);
      } else if (!lxHasIt && idx >= 0) {
        this.disabledIds.splice(idx, 1);
      }
      changed = true;
    }
    if (changed) {
      this.persist();
    }
  }

  /** 源管理里勾选「启用」的源 id；从未配置过 = 全部启用（与播放链路口径一致）。 */
  private enabledSourceIds(apis: LXUserApiInfo[]): string[] {
    let order: string[] = [];
    let configured: boolean = false;
    try {
      const store: MusicStoreService = MusicStoreService.getInstance();
      order = store.getSourceScriptOrder();
      configured = store.hasSourceScriptOrderConfig();
    } catch (_e) {
      configured = false;
    }
    if (configured) {
      return order;
    }
    const out: string[] = [];
    for (let i: number = 0; i < apis.length; i++) {
      if (apis[i].id.length > 0) {
        out.push(apis[i].id);
      }
    }
    return out;
  }

  /**
   * 完整平台清单：洛雪固定六平台 → 每个已启用的 MusicFree 插件一项，
   * 再按用户 orderIds 排序（未参与排序的新平台追加在末尾）。
   */
  allPlatforms(apis: LXUserApiInfo[]): PlatformDef[] {
    this.ensureLoaded();
    // ★ 2026-11-09（用户：「源已停用是啥玩意，我源启用了啊」）：
    //   历史数据里会有「订阅只启用了一半成员」的脏状态，平台管理据此把剩下几个
    //   标成「源已停用」且勾选框禁用。这里先按整包口径修一次，再派生平台清单。
    lxSourceManager.repairSourceEnableState();
    this.applyMfDefaults(apis);

    const defs: PlatformDef[] = this.builtin();
    const enabledSources: string[] = this.enabledSourceIds(apis);
    for (let i: number = 0; i < apis.length; i++) {
      const api: LXUserApiInfo = apis[i];
      if (api.kind !== 'mf' || api.id.length === 0) {
        continue;
      }
      // 用户要「平台管理显示 MusicFree 所有平台」——源停用也列出来，
      // 但标记 sourceEnabled=false，界面上勾选框禁用（勾了也没内容）。
      defs.push({
        id: mfPlatformIdOf(api.id),
        label: mfLabelOf(api),
        origin: 'musicfree',
        apiId: api.id,
        subtitle: mfSubtitleOf(api),
        sourceEnabled: enabledSources.indexOf(api.id) >= 0
      });
    }

    const ordered: PlatformDef[] = [];
    for (let o: number = 0; o < this.orderIds.length; o++) {
      const found: PlatformDef | undefined = this.findById(defs, this.orderIds[o]);
      if (found !== undefined && !this.hasId(ordered, found.id)) {
        ordered.push(found);
      }
    }
    for (let d: number = 0; d < defs.length; d++) {
      if (!this.hasId(ordered, defs[d].id)) {
        ordered.push(defs[d]);
      }
    }
    this.labelCache.clear();
    for (let i: number = 0; i < ordered.length; i++) {
      this.labelCache.set(ordered[i].id, ordered[i].label);
    }
    return ordered;
  }

  private hasId(defs: PlatformDef[], id: string): boolean {
    for (let i: number = 0; i < defs.length; i++) {
      if (defs[i].id === id) {
        return true;
      }
    }
    return false;
  }

  private findById(defs: PlatformDef[], id: string): PlatformDef | undefined {
    for (let i: number = 0; i < defs.length; i++) {
      if (defs[i].id === id) {
        return defs[i];
      }
    }
    return undefined;
  }

  /** 平台展示名（搜索页 / 广场 / 记录页共用；缓存命中率极高）。 */
  labelOf(id: string): string {
    this.ensureLoaded();
    const cached: string | undefined = this.labelCache.get(id);
    if (cached !== undefined) {
      return cached;
    }
    if (this.isBuiltin(id)) {
      return lxSourceLabel(normalizePlatformId(id));
    }
    return 'MusicFree';
  }

  /** 被用户取消勾选的平台 id（UI 用来画 Checkbox 选中态）。 */
  disabled(): string[] {
    this.ensureLoaded();
    return this.disabledIds.slice();
  }

  /** 是否勾选：默认启用，只有用户显式取消过的才不启用。 */
  isEnabled(id: string): boolean {
    this.ensureLoaded();
    return this.disabledIds.indexOf(normalizePlatformId(id)) < 0;
  }

  setEnabled(id: string, enabled: boolean): void {
    this.ensureLoaded();
    const key: string = normalizePlatformId(id);
    const idx: number = this.disabledIds.indexOf(key);
    if (enabled && idx >= 0) {
      this.disabledIds.splice(idx, 1);
      this.persist();
    } else if (!enabled && idx < 0) {
      this.disabledIds.push(key);
      this.persist();
    }
  }

  /** 勾选且背后有可用源的平台 id（按当前展示顺序）。 */
  enabledIds(apis: LXUserApiInfo[]): string[] {
    const all: PlatformDef[] = this.allPlatforms(apis);
    const out: string[] = [];
    for (let i: number = 0; i < all.length; i++) {
      if (all[i].sourceEnabled && this.isEnabled(all[i].id)) {
        out.push(all[i].id);
      }
    }
    return out;
  }

  /**
   * 按用户在「平台管理」里拖动出来的顺序重排一组平台 id。
   * orderIds 里没列出的 id 按传入顺序跟在后面。
   */
  sortIds(ids: string[]): string[] {
    this.ensureLoaded();
    const out: string[] = [];
    for (let o: number = 0; o < this.orderIds.length; o++) {
      const orderId: string = normalizePlatformId(this.orderIds[o]);
      for (let i: number = 0; i < ids.length; i++) {
        if (normalizePlatformId(ids[i]) === orderId && out.indexOf(ids[i]) < 0) {
          out.push(ids[i]);
        }
      }
    }
    for (let i: number = 0; i < ids.length; i++) {
      if (out.indexOf(ids[i]) < 0) {
        out.push(ids[i]);
      }
    }
    return out;
  }

  /** 过滤掉用户已取消勾选的平台。 */
  filterEnabled(ids: string[]): string[] {
    this.ensureLoaded();
    const out: string[] = [];
    for (let i: number = 0; i < ids.length; i++) {
      if (this.isEnabled(ids[i])) {
        out.push(ids[i]);
      }
    }
    return out;
  }

  /** 用户拖动排序后写回。 */
  setOrder(ids: string[]): void {
    this.ensureLoaded();
    const cleaned: string[] = [];
    for (let i: number = 0; i < ids.length; i++) {
      const id: string = normalizePlatformId(ids[i]);
      if (id.length > 0 && cleaned.indexOf(id) < 0) {
        cleaned.push(id);
      }
    }
    this.orderIds = cleaned;
    this.persist();
  }

  /** 恢复默认：清空勾选与排序，重新按「洛雪六平台开、同名 MusicFree 关」初始化。 */
  reset(): void {
    this.ensureLoaded();
    this.disabledIds = [];
    this.orderIds = [];
    // 清空后下次 allPlatforms 会重新按默认规则处理一遍
    this.mfDefaulted = [];
    this.persist();
  }
}

/** 进程内单例（与 MusicStoreService 同一用法）。 */
export let platformRegistry: PlatformRegistryImpl = PlatformRegistryImpl.getInstance();
