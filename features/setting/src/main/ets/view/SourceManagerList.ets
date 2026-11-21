/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源管理列表（唯一实现）：**一行一个源**（订阅整包 / 独立脚本），
 * 单列勾选「启用」+ 左滑操作 + 名称右侧「关于」气泡。
 *
 * ★ 2026-11-09 第三次改版（用户：「音源管理直接显示整个订阅源，不用展开显示平台；
 *   平台勾选放进平台管理；源卡片加回查看支持平台，用气泡，别占空间」）：
 *   - 订阅只显示**组头一行**（名字 / 音源数 / 已启用数），不再展开成员插件 ——
 *     平台的事全部归「平台管理」，这里只负责导入、更新、启用、删除；
 *   - 勾选语义只有「这个源启用」，不再出现「备选 N」这种播放链文案（尤其不再套到
 *     MusicFree 插件上）；
 *   - 长按拖动排序**恢复**（2026-11-09 用户：「现在音源没法拖动排序了」）：一行是
 *     订阅整包 / 独立脚本，拖动即整包搬家；行顺序单独持久化（`source_row_order`），
 *     同时换算成播放兜底的源优先级。平台顺序仍在「平台管理」里拖。
 *   - 名称右侧 `ⓘ`：点一下弹气泡看这个源声明的平台（洛雪脚本直接列平台 + 音质 +
 *     测试状态，不再点第二下；MusicFree 显示平台与说明），不占行内空间。
 *
 * 为什么抽出来：此前 `SettingsDetailPage` 与 `SettingPage` 各写了一份同构列表，
 * 改一处另一处不变（用户报"改了没效果"）。这里统一成一份，两处都调它。
 */

import { appendPlayLog,
  immersiveMedium
} from 'musicbasic';
import { lxDeclaredPlatformsOf, LXUserApiInfo, MfSubscriptionInfo, musicFreeSubscriptionLabel } from 'player';
import { LxSourceDeclaredBlock } from './LxSourceTags';
import { shareSourceScript } from '../util/SourceShare';
import { common } from '@kit.AbilityKit';

/** 左滑里的圆钮（只有图标）。 */
@Builder
function SwipeIcon(icon: Resource, bg: ResourceColor, action: () => void) {
  Column() {
    SymbolGlyph(icon)
      .fontSize(20)
      .fontColor([Color.White])
  }
  .width(48)
  .height(48)
  .borderRadius(24)
  .justifyContent(FlexAlign.Center)
  .backgroundColor(bg)
  .onClick(() => {
    action();
  })
}

/** 源管理的一行：订阅（整包），或独立脚本。 */
class SourceRowModel {
  kind: string = 'api';
  api: LXUserApiInfo | undefined = undefined;
  sub: MfSubscriptionInfo | undefined = undefined;
  total: number = 0;
  enabled: number = 0;
}

/** 行 key（持久化排序用）：订阅整包 / 独立脚本两种前缀。 */
function rowKeyOfRow(row: SourceRowModel): string {
  if (row.kind === 'sub' && row.sub !== undefined) {
    return 'sub:' + row.sub.id;
  }
  if (row.api !== undefined) {
    return 'api:' + row.api.id;
  }
  return '';
}

/**
 * 用户可见名：备注 > 插件自报平台名 > 导入时的来源名。
 *
 * ★ 2026-11-09（用户：「现在平台全都显示元力音源」）：`name` 是订阅项名（网易 / 酷我），
 *   `platform` 才是插件自己报的平台名（元力WY / bilibili）。旧版优先 name，
 *   元力 6 个插件名字全一样；现在 platform 优先，name 只在还没识别出来时兜底。
 */
function displayNameOf(api: LXUserApiInfo): string {
  const rawRemark: string | undefined = api.remark;
  const remark: string = rawRemark !== undefined ? rawRemark.trim() : '';
  if (remark.length > 0) {
    return remark;
  }
  const platform: string = api.platform !== undefined ? api.platform.trim() : '';
  if (platform.length > 0) {
    return platform;
  }
  return api.name;
}

@ComponentV2
export struct SourceManagerList {
  /** 全部已导入音源（订阅成员从这里按 subId 取）。 */
  @Param apis: LXUserApiInfo[] = [];
  /** 勾选顺序（第一个 = 默认源）；同时是「启用」集合。 */
  @Param orderIds: string[] = [];
  /** 当前默认源 id。 */
  @Param activeId: string = '';
  /** 主题色。 */
  @Param accentColor: ResourceColor = '#E60012';
  /** 已导入的 MusicFree 订阅（一行一个，不展开）。 */
  @Param subscriptions: MfSubscriptionInfo[] = [];
  /**
   * 行顺序（`sub:<订阅id>` / `api:<源id>`）。
   *
   * ★ 2026-11-09（用户：「现在音源没法拖动排序了」）：订阅整包是一行，
   *   光靠 `orderIds`（只有插件 id）表达不了它的位置，所以单独存一份行顺序。
   *   空数组 = 从未拖过 → 按「订阅在前、独立脚本按启用顺序」的默认排法。
   */
  @Param rowOrder: string[] = [];
  /**
   * 数据版本号（宿主每次刷新自增）。
   *
   * ★ 2026-11-09（用户：「修改备注后列表中名称没刷新，得重进页面」）：备注写的是
   *   数组里**同一个对象**的字段，`apis` / `subscriptions` 的引用可能没变，
   *   V2 就不会下发 @Param。版本号一变就强制重建行。
   */
  @Param dataVersion: number = 0;

  /** 当前展开「关于」气泡的行 key（空 = 全部关闭）。 */
  @Local aboutKey: string = '';
  /**
   * 列表**唯一的数据源**（ForEach 直接遍历它）。
   *
   * ★ 2026-11-09（用户：「拖动有好多 Bug」）：上一版每次 build 都重新 `rowsForRender()`
   *   生成一个新数组，再叠一层 `@Local rowKeys` 镜像；`ForEach.onMove` 需要稳定的
   *   数据源来跟踪拖动项，数组每帧都换新 + 两个排序真源（rowKeys / rowOrder）打架，
   *   就会出现落点错位、松手回弹。现在和原版一样：数据放成员变量，参数变了才重建，
   *   拖动时只改这一份数组。
   */
  @Local rows: SourceRowModel[] = [];
  /** 正在拖动的行下标（onMove 事件回调用；-1 = 没在拖）。 */
  @Local dragIndex: number = -1;
  /** 拖动开始时刻：兜底防止 onDrop 没回调时永远不再刷新。 */
  private dragStartedAt: number = 0;
  /** 拖动期间来过的数据变化，落手后补一次重建。 */
  private rebuildPending: boolean = false;

  aboutToAppear(): void {
    this.rebuildRows();
  }

  /** 入参变化（导入 / 删除 / 勾选 / 排序 / 平台回填 / 改备注）后重建行。 */
  @Monitor('apis', 'subscriptions', 'orderIds', 'rowOrder', 'dataVersion')
  onSourceDataChanged(): void {
    // 拖动中重建数据源会把行数组换掉，ArkUI 的拖拽项跟着丢 ⇒ 落点错位 / 回弹。
    // 拖动期间先记一笔，松手后再补（后台平台名回填正好可能撞上拖动）。
    if (this.isDragging()) {
      this.rebuildPending = true;
      return;
    }
    this.rebuildRows();
  }

  /** 是否正在拖动（30s 兜底：onDrop 偶尔不回调时不能永远卡住刷新）。 */
  private isDragging(): boolean {
    return this.dragIndex >= 0 && (Date.now() - this.dragStartedAt) < 30000;
  }

  private endDrag(index: number): void {
    this.dragIndex = -1;
    if (this.rebuildPending) {
      this.rebuildPending = false;
      this.rebuildRows();
    }
  }

  @Event onToggle: (apiId: string) => void = (apiId: string): void => {};
  /** 订阅整包启用 / 停用。 */
  @Event onToggleSubscription: (sub: MfSubscriptionInfo, enabled: boolean) => void =
    (sub: MfSubscriptionInfo, enabled: boolean): void => {};
  @Event onSelect: (apiId: string) => void = (apiId: string): void => {};
  @Event onDelete: (apiId: string) => void = (apiId: string): void => {};
  @Event onCheckUpdate: (api: LXUserApiInfo) => void = (api: LXUserApiInfo): void => {}
  /** 左滑分享（分享的是音源脚本文件本身）。 */
  @Event onShare: (api: LXUserApiInfo) => void = (api: LXUserApiInfo): void => {};
  @Event onProbe: (apiId: string) => void = (apiId: string): void => {};
  /** 修改 MusicFree 源的备注（用户可见名）。 */
  @Event onEditRemark: (api: LXUserApiInfo) => void = (api: LXUserApiInfo): void => {};
  /**
   * 修改 LX 脚本「实际支持的平台」。
   *
   * ★ 2026-11-09（用户：「LX 是修改支持的平台，因为源不稳定，平台可能失效」）：
   *   脚本声明的 6 个平台不一定都还能用，用户可以在这里裁掉失效的那些，
   *   播放兜底链就不会再把这首歌交给这个脚本的这个平台。
   */
  @Event onEditPlatforms: (api: LXUserApiInfo) => void = (api: LXUserApiInfo): void => {};
  /** 拖动排序后的行顺序（`sub:` / `api:` 前缀）。 */
  @Event onReorderRows: (keys: string[]) => void = (keys: string[]): void => {};
  /** 订阅级操作（整包更新 / 删除）。 */
  @Event onUpdateSubscription: (sub: MfSubscriptionInfo) => void = (sub: MfSubscriptionInfo): void => {};
  /** 订阅整包「编辑」：订阅里可能有很多插件，先去选一个再改备注。 */
  @Event onEditSubscription: (sub: MfSubscriptionInfo) => void = (sub: MfSubscriptionInfo): void => {};
  @Event onDeleteSubscription: (sub: MfSubscriptionInfo) => void = (sub: MfSubscriptionInfo): void => {};

  private inOrder(apiId: string): boolean {
    return this.orderIds.indexOf(apiId) >= 0;
  }

  /**
   * 订阅（音源本身）的展示名。
   *
   * ★ 2026-11-09（用户：「只显示域名太难看了」）：联网订阅的 name 是主机名，
   *   上屏只认备注 / 订阅自带的名字，都没有才用中性文案。
   */
  private subLabel(sub: MfSubscriptionInfo): string {
    let ordinal: number = 1;
    for (let i: number = 0; i < this.subscriptions.length; i++) {
      if (this.subscriptions[i].id === sub.id) {
        ordinal = i + 1;
        break;
      }
    }
    return musicFreeSubscriptionLabel(sub, ordinal, this.subscriptions.length);
  }

  /** 该订阅下的插件（按导入顺序）。 */
  private apisOfSub(sub: MfSubscriptionInfo): LXUserApiInfo[] {
    const out: LXUserApiInfo[] = [];
    for (let i: number = 0; i < this.apis.length; i++) {
      const api: LXUserApiInfo = this.apis[i];
      // 老数据可能只有订阅侧记着 apiIds、插件侧 subId 还是空串 —— 两边都认，
      // 否则这些插件既不在组里、又会被当成「独立脚本」重复出现一次。
      if (api.subId === sub.id || (api.subId.length === 0 && sub.apiIds.indexOf(api.id) >= 0)) {
        out.push(api);
      }
    }
    return out;
  }

  /** 没有订阅归属的独立脚本（LX 脚本 / 单独导入的插件）。 */
  private looseApis(): LXUserApiInfo[] {
    const subIds: string[] = [];
    const memberIds: string[] = [];
    for (let s: number = 0; s < this.subscriptions.length; s++) {
      subIds.push(this.subscriptions[s].id);
      for (let k: number = 0; k < this.subscriptions[s].apiIds.length; k++) {
        memberIds.push(this.subscriptions[s].apiIds[k]);
      }
    }
    const out: LXUserApiInfo[] = [];
    for (let i: number = 0; i < this.apis.length; i++) {
      const api: LXUserApiInfo = this.apis[i];
      const ownedBySub: boolean = api.subId.length > 0 && subIds.indexOf(api.subId) >= 0;
      const legacyOwned: boolean = api.subId.length === 0 && memberIds.indexOf(api.id) >= 0;
      if (!ownedBySub && !legacyOwned) {
        out.push(api);
      }
    }
    return out;
  }

  private rowsForRender(): SourceRowModel[] {
    const rows: SourceRowModel[] = [];
    for (let s: number = 0; s < this.subscriptions.length; s++) {
      const sub: MfSubscriptionInfo = this.subscriptions[s];
      const members: LXUserApiInfo[] = this.apisOfSub(sub);
      let enabled: number = 0;
      for (let i: number = 0; i < members.length; i++) {
        if (this.inOrder(members[i].id)) {
          enabled++;
        }
      }
      const row: SourceRowModel = new SourceRowModel();
      row.kind = 'sub';
      row.sub = sub;
      row.total = members.length;
      row.enabled = enabled;
      rows.push(row);
    }
    const loose: LXUserApiInfo[] = this.looseApis();
    for (let i: number = 0; i < loose.length; i++) {
      const row: SourceRowModel = new SourceRowModel();
      row.kind = 'api';
      row.api = loose[i];
      rows.push(row);
    }
    return this.sortedByRowOrder(rows);
  }

  private rebuildRows(): void {
    this.rows = this.rowsForRender();
  }

  /**
   * 按持久化的行顺序排。
   *
   * 没出现在 `rowOrder` 里的行（新导入的订阅 / 脚本、老用户升级）保持原相对位置
   * 排在末尾 —— 绝对不能因为排序把新导入的东西藏起来。
   */
  private sortedByRowOrder(rows: SourceRowModel[]): SourceRowModel[] {
    const order: string[] = this.rowOrder;
    if (order.length === 0 || rows.length < 2) {
      return rows;
    }
    const rank: Map<string, number> = new Map();
    for (let i: number = 0; i < order.length; i++) {
      rank.set(order[i], i);
    }
    const known: SourceRowModel[] = [];
    const unknown: SourceRowModel[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      if (rank.has(rowKeyOfRow(rows[i]))) {
        known.push(rows[i]);
      } else {
        unknown.push(rows[i]);
      }
    }
    known.sort((a: SourceRowModel, b: SourceRowModel): number => {
      const ra: number = rank.get(rowKeyOfRow(a)) ?? Number.MAX_SAFE_INTEGER;
      const rb: number = rank.get(rowKeyOfRow(b)) ?? Number.MAX_SAFE_INTEGER;
      return ra - rb;
    });
    for (let i: number = 0; i < unknown.length; i++) {
      known.push(unknown[i]);
    }
    return known;
  }

  /** 拖动落点：直接改这份数组（和原版一致），再交给宿主持久化。 */
  private moveRow(from: number, to: number): void {
    if (from === to || from < 0 || from >= this.rows.length) {
      return;
    }
    const next: SourceRowModel[] = this.rows.slice();
    const moved: SourceRowModel = next.splice(from, 1)[0];
    // 拖到最后一行之外时 ArkUI 可能给 length（原版直接 return ⇒ 落点无效、看着像回弹）
    const target: number = Math.max(0, Math.min(to, next.length));
    next.splice(target, 0, moved);
    this.rows = next;
    const keys: string[] = [];
    for (let i: number = 0; i < next.length; i++) {
      const key: string = rowKeyOfRow(next[i]);
      if (key.length > 0) {
        keys.push(key);
      }
    }
    // 本地已经换好位，宿主持久化后 @Monitor 会按 rowOrder 重建一次（顺序相同，不会回弹）
    this.onReorderRows(keys);
  }

  /**
   * 左滑菜单：试听探测（仅洛雪脚本）/ 检查更新 / 编辑 / 分享 / 删除。
   *
   * ★ 2026-11-09（用户：「左滑那几个按钮颜色统一成用户选择的主题色，
   *   平台、备注、更新不要用文字了，改用系统自带符号（备注和平台都用编辑）」）：
   *   全部圆钮吃 `accentColor`，不再有文字钮，也不再有写死的蓝 / 红。
   */
  @Builder
  private actions(api: LXUserApiInfo) {
    Row({ space: 8 }) {
      // 「试听」是洛雪引擎的音质探测，对 MusicFree 插件不成立
      if (api.kind !== 'mf') {
        SwipeIcon($r('sys.symbol.waveform'), this.accentColor, (): void => {
          this.onProbe(api.id);
        })
      }
      SwipeIcon($r('sys.symbol.arrow_clockwise'), this.accentColor, (): void => {
        this.onCheckUpdate(api);
      })
      // 编辑两种语义，图标同一个（铅笔）：MusicFree 改备注；洛雪脚本改「实际支持的平台」
      if (api.kind === 'mf') {
        SwipeIcon($r('sys.symbol.square_and_pencil'), this.accentColor, (): void => {
          this.onEditRemark(api);
        })
      } else {
        SwipeIcon($r('sys.symbol.square_and_pencil'), this.accentColor, (): void => {
          this.onEditPlatforms(api);
        })
      }
      SwipeIcon($r('sys.symbol.share'), this.accentColor, (): void => {
        appendPlayLog('[RzdSourceShare] swipe tap id=' + api.id);
        const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
        shareSourceScript(ctx, api).catch((e: Error): void => {
          appendPlayLog('[RzdSourceShare] call failed ' + (e.message ?? ''));
        });
      })
      SwipeIcon($r('sys.symbol.trash'), this.accentColor, (): void => {
        this.onDelete(api.id);
      })
    }
    .height('100%')
    .padding({ left: 8, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private subscriptionActions(sub: MfSubscriptionInfo) {
    Row({ space: 8 }) {
      SwipeIcon($r('sys.symbol.square_and_pencil'), this.accentColor, (): void => {
        this.onEditSubscription(sub);
      })
      SwipeIcon($r('sys.symbol.arrow_clockwise'), this.accentColor, (): void => {
        this.onUpdateSubscription(sub);
      })
      SwipeIcon($r('sys.symbol.trash'), this.accentColor, (): void => {
        this.onDeleteSubscription(sub);
      })
    }
    .height('100%')
    .padding({ left: 8, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  /** 名称右侧的「关于」图标：点一下弹气泡，不占横向空间。 */
  @Builder
  private AboutButton(key: string, row: SourceRowModel) {
    // ★ 2026-11-09（用户：「关于按钮颜色跟随 HDS 日夜间，不要填充，红色看着像这个源有问题」）：
    //   改成描边图标 + 系统三级图标色，日夜主题自动适配，不再吃主题色。
    SymbolGlyph($r('sys.symbol.info_circle'))
      .fontSize(16)
      .fontColor([$r('sys.color.icon_secondary')])
      .bindPopup(this.aboutKey === key, {
        systemMaterial: immersiveMedium(),
        builder: (): void => {
          this.AboutBubble(row)
        },
        placement: Placement.Bottom,
        enableArrow: true,
        radius: 12,
        width: 280,
        onStateChange: (event): void => {
          if (!event.isVisible && this.aboutKey === key) {
            this.aboutKey = '';
          }
        }
      })
      .onClick((): void => {
        this.aboutKey = this.aboutKey === key ? '' : key;
      })
  }

  /** 气泡内容：洛雪脚本看声明平台（复用音源卡片原来的标签组件）；订阅看成员平台清单。 */
  @Builder
  private AboutBubble(row: SourceRowModel) {
    Column({ space: 6 }) {
      if (row.kind === 'sub' && row.sub !== undefined) {
        Text(this.subLabel(row.sub))
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text('MusicFree 订阅 · ' + row.total.toString() + ' 个音源')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
        ForEach(this.apisOfSub(row.sub), (api: LXUserApiInfo) => {
          Row({ space: 6 }) {
            Text(displayNameOf(api))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(api.platform.length > 0 ? api.platform : 'MusicFree')
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
            // 订阅成员不在源列表里单独成行，备注入口就放在这里（点铅笔改名再关气泡）
            SymbolGlyph($r('sys.symbol.square_and_pencil'))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_tertiary')])
              .padding({ left: 6, right: 2, top: 2, bottom: 2 })
              .onClick((): void => {
                this.aboutKey = '';
                this.onEditRemark(api);
              })
          }
          .width('100%')
        }, (api: LXUserApiInfo) => 'about_api_' + api.id)
      } else if (row.api !== undefined) {
        Text(displayNameOf(row.api))
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(row.api.kind === 'mf' ?
          ('MusicFree 插件' + this.authorVersionOf(row.api)) : ('LX 脚本' + this.authorVersionOf(row.api)))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (row.api.kind === 'mf') {
          if (row.api.platform.length > 0) {
            Text('平台：' + row.api.platform)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          if (row.api.description.length > 0) {
            Text(row.api.description)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        } else {
          // 洛雪脚本：直接列出每个声明平台 + 音质 + 测试状态（不再点第二下看）
          LxSourceDeclaredBlock({
            items: lxDeclaredPlatformsOf(row.api),
            apiId: row.api.id,
            accentColor: this.accentColor,
            active: row.api.id === this.activeId
          })
        }
      }
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
  }

  /** 订阅行：名字 + 「N 个音源 · 已启用 M」；勾选整包启用。 */
  @Builder
  private SubscriptionRow(row: SourceRowModel) {
    Row({ space: 12 }) {
      Checkbox()
        .select(row.enabled > 0)
        .selectedColor(this.accentColor)
        .width(20)
        .height(20)
        .onChange((checked: boolean): void => {
          if (row.sub !== undefined && checked !== (row.enabled > 0)) {
            this.onToggleSubscription(row.sub, checked);
          }
        })

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(row.sub !== undefined ? this.subLabel(row.sub as MfSubscriptionInfo) : '')
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          // 与独立脚本同一套徽标：一眼能看出这是 MusicFree 生态的源
          Text('MusicFree')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_tertiary'))
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius($r('sys.float.corner_radius_level2'))
            .backgroundColor($r('sys.color.background_tertiary'))
          this.AboutButton('sub_' + (row.sub !== undefined ? row.sub.id : ''), row)
        }
        .width('100%')

        Text('MusicFree 订阅 · ' + row.total.toString() + ' 个音源' +
          (row.enabled > 0 && row.enabled < row.total ? (' · 已启用 ' + row.enabled.toString()) : ''))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .borderRadius($r('sys.float.corner_radius_level16'))
    .backgroundColor($r('app.color.comp_background_list_card'))
  }

  /** 独立脚本行：名字 + LX/MusicFree 徽标 + 作者/版本 + 描述。 */
  @Builder
  private ApiRow(api: LXUserApiInfo) {
    Row({ space: 12 }) {
      Checkbox()
        .select(this.inOrder(api.id))
        .selectedColor(this.accentColor)
        .width(20)
        .height(20)
        .onChange((checked: boolean) => {
          if (checked !== this.inOrder(api.id)) {
            this.onToggle(api.id);
          }
        })

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(displayNameOf(api))
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          // 两种运行时的脚本格式完全不同，行上标出来才知道它归哪个引擎
          Text(api.kind === 'mf' ? 'MusicFree' : 'LX')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_tertiary'))
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius($r('sys.float.corner_radius_level2'))
            .backgroundColor($r('sys.color.background_tertiary'))
          this.AboutButton('api_' + api.id, this.apiRowOf(api))
        }
        .width('100%')

        Row({ space: 4 }) {
          if (api.id === this.activeId) {
            Text('当前使用')
              .fontSize($r('sys.float.Caption_S'))
              .fontColor(this.accentColor)
          }
          if (this.inOrder(api.id)) {
            Text('已启用')
              .fontSize($r('sys.float.Caption_S'))
              .fontColor(this.accentColor)
          }
          if (api.author.length > 0 || api.version.length > 0) {
            Text((api.author.length > 0 ? api.author : '') +
              (api.version.length > 0 ? ' v' + api.version : ''))
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
          }
        }

        if (api.kind === 'mf') {
          // 备注盖住了原名时把原名留着 —— 订阅更新后仍能对上号
          if (this.hasRemark(api) && api.name.length > 0) {
            Text('来源：' + api.name)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          if (api.description.length > 0) {
            Text(api.description)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          } else if (api.platform.length > 0) {
            Text('平台：' + api.platform)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        } else if (api.description.length > 0) {
          Text(api.description)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        // MusicFree 插件不能当洛雪引擎的「当前源」（引擎不认识它的脚本格式），
        // 点它只当展开区域，不切换 activeSource —— 否则洛雪平台会瞬间"没有源"。
        if (api.kind !== 'mf') {
          this.onSelect(api.id);
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .borderRadius($r('sys.float.corner_radius_level16'))
    .backgroundColor($r('app.color.comp_background_list_card'))
  }

  /** 把单个 api 包成行模型，给「关于」气泡复用同一套 builder。 */
  private apiRowOf(api: LXUserApiInfo): SourceRowModel {
    const row: SourceRowModel = new SourceRowModel();
    row.kind = 'api';
    row.api = api;
    return row;
  }

  /** 「 · 作者 · v版本」小尾巴（作者/版本都可能为空）。 */
  private authorVersionOf(api: LXUserApiInfo): string {
    const bits: string[] = [];
    if (api.author.length > 0) {
      bits.push(api.author);
    }
    if (api.version.length > 0) {
      bits.push('v' + api.version);
    }
    return bits.length > 0 ? ' · ' + bits.join(' · ') : '';
  }

  /** 是否设置过备注（Builder 里不能写语句，判断收进方法）。 */
  private hasRemark(api: LXUserApiInfo): boolean {
    const raw: string | undefined = api.remark;
    return raw !== undefined && raw.trim().length > 0;
  }

  build() {
    List({ space: 8 }) {
      ForEach(this.rows, (row: SourceRowModel) => {
        ListItem() {
          if (row.kind === 'sub') {
            this.SubscriptionRow(row)
          } else if (row.api !== undefined) {
            this.ApiRow(row.api as LXUserApiInfo)
          }
        }
        .swipeAction({
          end: {
            builder: (): void => {
              if (row.kind === 'sub' && row.sub !== undefined) {
                this.subscriptionActions(row.sub as MfSubscriptionInfo)
              } else if (row.api !== undefined) {
                this.actions(row.api as LXUserApiInfo)
              }
            }
          },
          edgeEffect: SwipeEdgeEffect.Spring
        })
        // 与平台管理同一套拖拽观感（不缩放、保持圆角、无角标 + 触感 + 贴边自动滚）
        .dragPreviewOptions({
          mode: [DragPreviewMode.DISABLE_SCALE, DragPreviewMode.ENABLE_DEFAULT_RADIUS],
          numberBadge: false,
          sizeChangeEffect: DraggingSizeChangeEffect.DEFAULT
        }, {
          enableHapticFeedback: true,
          enableEdgeAutoScroll: true
        })
      }, (row: SourceRowModel) => {
        if (row.kind === 'sub') {
          return 'sub_' + (row.sub !== undefined ? row.sub.id : '');
        }
        return 'api_' + (row.api !== undefined ? (row.api as LXUserApiInfo).id : '');
      })
        // ★ 2026-11-09（用户：「拖动有好多 Bug」）：回到原版写法 —— ForEach 上挂 onMove，
        //   数据源是稳定的成员数组，落点只改这一份数组；不再每帧重建 + 本地镜像双真源。
        .onMove((from: number, to: number): void => {
          this.moveRow(from, to);
        }, {
          onLongPress: (index: number): void => {
            this.dragIndex = index;
            this.dragStartedAt = Date.now();
          },
          onDragStart: (index: number): void => {
            this.dragIndex = index;
            this.dragStartedAt = Date.now();
          },
          onDrop: (index: number): void => {
            this.endDrag(index);
          }
        })
    }
    .width('100%')
    .scrollBar(BarState.Off)
  }
}
