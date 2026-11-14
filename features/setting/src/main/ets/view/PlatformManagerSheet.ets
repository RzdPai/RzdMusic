/*
 * 「平台管理」面板（音源管理右上角菜单打开的半模态内容）。
 *
 * ★ 术语统一（用户定稿，全仓遵守）：
 *   - 音源 = 用户导入的 JS 脚本（LX 脚本 / MusicFree 插件）
 *   - 平台 = 搜索页 / 歌单广场上能单独勾选、单独展示的一栏
 *
 * ★ 2026-11-09 第三版（用户：「平台里面显示两个酷我，一个用洛雪的，一个跟随源名」）：
 *   一行 = 一个来源。洛雪固定六行；每个 MusicFree 插件再各占一行，名字跟源走
 *   （小蜗 / 元力KW / 元力WY）。勾哪些就显示哪些，两个都勾就是共存。
 *   平台清单只来自 PlatformRegistry，本组件不扫描脚本声明、不自己拼平台。
 *
 * 本组件**只是一块面板内容**：标题由宿主的半模态 `bindSheet` 按 HDS 规范提供，
 * 两侧间距也由宿主统一给。
 *
 * ⚠️ 只用 V2 装饰器（@ComponentV2 / @Param / @Local）。
 *    V2 对数组内部变更不敏感 —— 所有勾选/排序都重建数组再赋值，才能触发刷新。
 */

import {
  backfillMusicFreePlatforms, LXUserApiInfo, MfSubscriptionInfo, musicFreeSubscriptionLabel, PlatformDef,
  platformRegistry
} from 'player';

@ComponentV2
export struct PlatformManagerSheet {
  /** 已导入的音源脚本列表（MusicFree 插件据此各成一行）。 */
  @Param apis: LXUserApiInfo[] = [];
  /** 已导入的订阅（用来标注 MusicFree 平台「来自哪个源」，同名插件靠它区分）。 */
  @Param subscriptions: MfSubscriptionInfo[] = [];
  /** 主题色（用户可改，不能写死）。 */
  @Param accentColor: ResourceColor = '#E60012';
  /** 平台名回填完成后通知宿主刷新（源列表 / 搜索页跟着变准）。 */
  @Event onPlatformsChanged: () => void = (): void => {};

  /** 当前平台清单（已按用户排序）。 */
  @Local platforms: PlatformDef[] = [];
  /** 被取消勾选的平台 id（勾选态来源）。 */
  @Local disabledIds: string[] = [];

  aboutToAppear(): void {
    this.reload();
    this.ensurePlatformNames();
  }

  /** 平台名后台回填 / 订阅改备注后，宿主会换一份 `apis` / `subscriptions`，这里跟着重建。 */
  @Monitor('apis', 'subscriptions')
  onApisChanged(): void {
    this.reload();
  }

  /**
   * 元力系插件的平台名只有运行时才知道（`platform` 是加密的），旧数据还被写成了
   * 品牌名「元力音源」。打开平台管理时后台补一轮，回来就显示「元力WY / 元力KG」。
   */
  private ensurePlatformNames(): void {
    if (this.platforms.length === 0) {
      return;
    }
    void backfillMusicFreePlatforms(this.apis).then((count: number): void => {
      if (count <= 0) {
        return;
      }
      this.reload();
      this.onPlatformsChanged();
    });
  }

  private reload(): void {
    this.platforms = platformRegistry.allPlatforms(this.apis);
    this.disabledIds = platformRegistry.disabled();
  }

  private enabledOf(id: string): boolean {
    return this.disabledIds.indexOf(id) < 0;
  }

  /** 平台背后的插件属于哪份订阅（找不到 = 独立导入）。 */
  private apiOf(apiId: string): LXUserApiInfo | undefined {
    for (let i: number = 0; i < this.apis.length; i++) {
      if (this.apis[i].id === apiId) {
        return this.apis[i];
      }
    }
    return undefined;
  }

  /** 该插件是否属于某份订阅（订阅表 / 插件侧双向兜底）。 */
  private hasSubscriptionOfApi(apiId: string): boolean {
    return this.subOfApi(apiId) !== undefined;
  }

  /** 插件 → 订阅（插件侧 `subId` 优先，老数据只有订阅侧 `apiIds` 也算）。 */
  private subOfApi(apiId: string): MfSubscriptionInfo | undefined {
    const api: LXUserApiInfo | undefined = this.apiOf(apiId);
    const subId: string = api !== undefined ? api.subId : '';
    for (let s: number = 0; s < this.subscriptions.length; s++) {
      const sub: MfSubscriptionInfo = this.subscriptions[s];
      if ((subId.length > 0 && sub.id === subId) || sub.apiIds.indexOf(apiId) >= 0) {
        return sub;
      }
    }
    return undefined;
  }

  private subNameOfApi(apiId: string): string {
    const sub: MfSubscriptionInfo | undefined = this.subOfApi(apiId);
    if (sub === undefined) {
      return '';
    }
    let ordinal: number = 1;
    for (let s: number = 0; s < this.subscriptions.length; s++) {
      if (this.subscriptions[s].id === sub.id) {
        ordinal = s + 1;
        break;
      }
    }
    const label: string = musicFreeSubscriptionLabel(sub, ordinal, this.subscriptions.length);
    // 中性兜底文案不值得上屏（「来自「MusicFree 订阅」」纯噪音）
    return label === 'MusicFree 订阅' ? '' : label;
  }

  /**
   * 平台副标题。
   *
   * ★ 2026-11-09（用户：「平台管理中 MusicFree 的显示一下来自哪个音源，
   *   因为可能会导入多个音源，不好分辨」→ 后来：「只显示域名太难看了」）：
   *   主名一律用**人能读的**名字（订阅备注 / 订阅自带名），域名绝不上屏；
   *   用户改过插件备注时再带上插件原始平台名，避免只看到备注就看不出是哪个平台。
   */
  private subtitleOf(def: PlatformDef): string {
    let text: string = def.subtitle;
    if (def.origin === 'musicfree' && def.apiId.length > 0) {
      const subName: string = this.subNameOfApi(def.apiId);
      if (!this.hasSubscriptionOfApi(def.apiId)) {
        text += ' · 独立导入';
      } else if (subName.length > 0 && subName !== def.label) {
        // 订阅备注恰好就是这一行的名字时再说「来自自己」只是噪音
        text += ' · 来自「' + subName + '」';
      }
      const api: LXUserApiInfo | undefined = this.apiOf(def.apiId);
      if (api !== undefined) {
        const rawRemark: string | undefined = api.remark;
        const remark: string = rawRemark !== undefined ? rawRemark.trim() : '';
        if (remark.length > 0 && api.platform.length > 0 && def.subtitle.indexOf(api.platform) < 0) {
          text += ' · ' + api.platform;
        }
      }
    }
    return def.sourceEnabled ? text : (text + ' · 源已停用');
  }

  private togglePlatform(id: string, checked: boolean): void {
    platformRegistry.setEnabled(id, checked);
    this.disabledIds = platformRegistry.disabled();
  }

  /** 拖动排序：重建数组后写回注册表。 */
  private movePlatform(from: number, to: number): void {
    if (from === to || from < 0 || to < 0 || from >= this.platforms.length || to >= this.platforms.length) {
      return;
    }
    const next: PlatformDef[] = this.platforms.slice();
    const moved: PlatformDef = next.splice(from, 1)[0];
    next.splice(to, 0, moved);
    this.platforms = next;
    const ids: string[] = [];
    for (let i: number = 0; i < next.length; i++) {
      ids.push(next[i].id);
    }
    platformRegistry.setOrder(ids);
  }

  @Builder
  private PlatformRow(def: PlatformDef) {
    Row({ space: 12 }) {
      Checkbox()
        .select(this.enabledOf(def.id) && def.sourceEnabled)
        .selectedColor(this.accentColor)
        .width(20)
        .height(20)
        // 源在「音源管理」里被停用 → 这个平台没有内容，勾了也没用，直接禁用
        .enabled(def.sourceEnabled)
        .onChange((checked: boolean): void => {
          this.togglePlatform(def.id, checked);
        })

      Column({ space: 2 }) {
        Text(def.label)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(def.origin === 'lx' ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.enabledOf(def.id) && def.sourceEnabled ?
            $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subtitleOf(def))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 拖动把手用纯文本，避免依赖不确定的 sys.symbol 资源
      Text('≡')
        .fontSize(20)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.comp_background_list_card'))
    .borderRadius($r('sys.float.corner_radius_level16'))
  }

  build() {
    // ★ 2026-11-09（用户：「平台管理上下那些字（别在下方留空白了）、包括重置，都删掉」）：
    //   面板里只剩平台行本身，列表撑满整个半模态。
    List({ space: 8 }) {
      ForEach(this.platforms, (def: PlatformDef) => {
        ListItem() {
          this.PlatformRow(def)
        }
        // 与全仓其它可拖列表同一套拖拽观感：不缩放、保持圆角、无角标 + 触感
        .dragPreviewOptions({
          mode: [DragPreviewMode.DISABLE_SCALE, DragPreviewMode.ENABLE_DEFAULT_RADIUS],
          numberBadge: false,
          sizeChangeEffect: DraggingSizeChangeEffect.DEFAULT
        }, {
          enableHapticFeedback: true,
          enableEdgeAutoScroll: true
        })
      }, (def: PlatformDef) => 'platform_' + def.id)
        // `onMove` 挂在 ForEach 上（ArkUI 官方拖拽排序写法）；本列表是纯平铺、无组头
        .onMove((from: number, to: number): void => {
          this.movePlatform(from, to);
        })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
