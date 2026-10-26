/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源管理列表（唯一实现）：单列勾选 + 长按拖动排序 + 左滑「检查更新 / 删除」。
 *
 * 为什么抽出来：此前 `SettingsDetailPage` 与 `SettingPage` 各写了一份同构列表，
 * 改一处另一处不变（用户报"改了没效果"）。这里统一成一份，两处都调它。
 */

import { LXSourcePlatformInfo, LXUserApiInfo, lxDeclaredPlatformsOf } from 'player';
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
  @Event onProbe: () => void = (): void => {};
  @Event onMove: (dragId: string, targetId: string) => void = (dragId: string, targetId: string): void => {};

  /** 正在被拖动的音源 id。 */
  @Local dragId: string = '';

  private inOrder(apiId: string): boolean {
    return this.orderIds.indexOf(apiId) >= 0;
  }

  private platformsOf(api: LXUserApiInfo): LXSourcePlatformInfo[] {
    return lxDeclaredPlatformsOf(api);
  }

  /** 左滑菜单：检查更新（左）+ 删除（右）。 */
  @Builder
  private actions(api: LXUserApiInfo) {
    Row({ space: 8 }) {
      SwipeIcon($r('sys.symbol.waveform'), '#43A047', (): void => {
        this.onProbe();
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
                active: this.activeId === api.id
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
          // 整卡可拖（长按卡片任意位置即可拖动排序）
          .draggable(this.draggableEnabled && this.inOrder(api.id))
          .onDragStart(() => {
            this.dragId = api.id;
          })
          .onDrop(() => {
            this.onMove(this.dragId, api.id);
          })
        }
        .swipeAction({
          end: {
            builder: (): void => {
              this.actions(api);
            }
          },
          edgeEffect: SwipeEdgeEffect.Spring
        })
      }, (api: LXUserApiInfo) => api.id)
    }
    .width('100%')
    .scrollBar(BarState.Off)
    // 拖动：行级 draggable（本 SDK 的 List 无 onMove，List 级拖拽实测不可用）

  }
}