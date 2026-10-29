/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源管理列表（唯一实现）：单列勾选 + 长按拖动排序 + 左滑「检查更新 / 删除」。
 *
 * 为什么抽出来：此前 `SettingsDetailPage` 与 `SettingPage` 各写了一份同构列表，
 * 改一处另一处不变（用户报"改了没效果"）。这里统一成一份，两处都调它。
 */

import { LXSourcePlatformInfo, LXUserApiInfo, LXUserApiSourceInfo, lxDeclaredPlatforms, lxDeclaredPlatformsOf } from 'player';
import { LxSourceDeclaredBlock } from './LxSourceTags';

/** 左滑里的圆钮（只有图标）。 */
@Builder
function SwipeIcon(icon: Resource, bg: string, action: () => void) {
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

@ComponentV2
export struct SourceManagerList {
  /** 展示顺序：已勾选在前（按用户顺序），未勾选在后。 */
  @Param apis: LXUserApiInfo[] = [];
  /** 勾选顺序（第一个 = 默认源）。 */
  @Param orderIds: string[] = [];
  /** 当前默认源 id。 */
  @Param activeId: string = '';
  /** 主题色。 */
  @Param accentColor: ResourceColor = '#E60012';
  /** 是否可拖动（引擎就绪时才有意义）。 */
  @Param draggableEnabled: boolean = true;

  @Event onToggle: (apiId: string) => void = (apiId: string): void => {};
  @Event onSelect: (apiId: string) => void = (apiId: string): void => {};
  @Event onDelete: (apiId: string) => void = (apiId: string): void => {};
  @Event onCheckUpdate: (api: LXUserApiInfo) => void = (api: LXUserApiInfo): void => {};
  @Event onProbe: (apiId: string) => void = (apiId: string): void => {};
  @Event onMove: (dragId: string, targetId: string) => void = (dragId: string, targetId: string): void => {};

  /** 正在被拖动的音源 id。 */
  @Local dragId: string = '';
  /** 拖拽中的行下标（onItemDragStart/onItemDrop 用）。 */
  @Local dragIdx: number = -1;

  private inOrder(apiId: string): boolean {
    return this.orderIds.indexOf(apiId) >= 0;
  }

  private platformsOf(api: LXUserApiInfo): LXSourcePlatformInfo[] {
    const declared: LXSourcePlatformInfo[] = lxDeclaredPlatformsOf(api);
    if (declared.length > 0) {
      return declared;
    }
    // ★ 2026-10-29（用户：支持汽水的脚本仍显示「未检测」）：
    //   持久化里这条音源还没带上 sources 时，若它正是当前引擎脚本，
    //   直接用引擎 init 上报并缓存在 AppStorage 的 sources 解析 —— 引擎已就绪就一定显示得出平台。
    if (api.id === this.activeId) {
      const json: string = AppStorage.get<string>('lxEngineSources') ?? '';
      if (json.length > 2) {
        try {
          return lxDeclaredPlatforms(JSON.parse(json) as Record<string, LXUserApiSourceInfo>);
        } catch (err) {
          console.info('[RzdSource] live sources parse failed');
        }
      }
    }
    return declared;
  }

  /** 左滑菜单：检查更新（左）+ 删除（右）。 */
  @Builder
  private actions(api: LXUserApiInfo) {
    Row({ space: 8 }) {
      SwipeIcon($r('sys.symbol.waveform'), '#43A047', (): void => {
        this.onProbe(api.id);
      })
      SwipeIcon($r('sys.symbol.arrow_clockwise'), '#1E88E5', (): void => {
        this.onCheckUpdate(api);
      })
      SwipeIcon($r('sys.symbol.trash'), '#E53935', (): void => {
        this.onDelete(api.id);
      })
    }
    .height('100%')
    .padding({ left: 8, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    List({ space: 8 }) {
      ForEach(this.apis, (api: LXUserApiInfo) => {
        ListItem() {
          Row({ space: 6 }) {
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
              Text(api.name)
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Row({ space: 4 }) {
                if (this.inOrder(api.id)) {
                  Text(this.orderIds.indexOf(api.id) === 0 ? '默认源' :
                    ('备选 ' + (this.orderIds.indexOf(api.id) + 1)))
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

              if (api.description.length > 0) {
                Text(api.description)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }

              LxSourceDeclaredBlock({
                items: this.platformsOf(api),
                accentColor: this.accentColor,
                active: this.activeId === api.id,
                apiId: api.id
              })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .onClick(() => {
              this.onSelect(api.id);
            })
          }
          .width('100%')
          .padding(10)
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('app.color.card_background'))
        }
        .swipeAction({
          end: {
            builder: (): void => {
              this.actions(api);
            }
          },
          edgeEffect: SwipeEdgeEffect.Spring
        })
        // ★ 参考 OpenAuthenticator（mroble/Authenticator `Index.ets` 首页令牌列表）：
        //   拖拽预览不缩放、保持圆角、无数量角标，并开触感 + 拖到边缘自动滚动。
        .dragPreviewOptions({
          mode: [DragPreviewMode.DISABLE_SCALE, DragPreviewMode.ENABLE_DEFAULT_RADIUS],
          numberBadge: false,
          sizeChangeEffect: DraggingSizeChangeEffect.DEFAULT
        }, {
          enableHapticFeedback: true,
          enableEdgeAutoScroll: true
        })
      }, (api: LXUserApiInfo) => api.id)
        // ★ 关键：`onMove` 挂在 **ForEach** 上（不是 List，也不是行级 draggable）——
        //   这是 ArkUI 官方的拖拽排序写法，OpenAuthenticator 首页令牌列表就是这么写的。
        .onMove((from: number, to: number) => {
          if (!this.draggableEnabled || from === to || from < 0 || to < 0 ||
            from >= this.apis.length || to >= this.apis.length) {
            return;
          }
          this.onMove(this.apis[from].id, this.apis[to].id);
        }, {
          onLongPress: (index: number): void => {
            this.dragIdx = index;
          },
          onDragStart: (index: number): void => {
            this.dragIdx = index;
          },
          onDrop: (index: number): void => {
            this.dragIdx = index;
          }
        })
    }
    .width('100%')
    .scrollBar(BarState.Off)
  }
}