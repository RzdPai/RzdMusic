/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源管理列表（唯一实现）：单列勾选 + 长按拖动排序 + 左滑「检查更新 / 删除」。
 *
 * 为什么抽出来：此前 `SettingsDetailPage` 与 `SettingPage` 各写了一份同构列表，
 * 改一处另一处不变（用户报"改了没效果"）。这里统一成一份，两处都调它。
 */

import { appendPlayLog } from 'musicbasic';
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

/** 左滑里的**文字**圆钮（分享用；不依赖 sys.symbol 是否存在）。 */
@Builder
function SwipeTextIcon(label: string, bg: string, action: () => void) {
  Column() {
    Text(label)
      .fontSize(12)
      .fontColor(Color.White)
      .fontWeight(FontWeight.Medium)
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
  @Event onCheckUpdate: (api: LXUserApiInfo) => void = (api: LXUserApiInfo): void => {}
  /** ★ 2026-11-01（用户：左滑加分享，分享的是音源脚本文件本身）。 */
  @Event onShare: (api: LXUserApiInfo) => void = (api: LXUserApiInfo): void => {};
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
    
    // ★ 2026-10-29：持久化记录可能是旧快照（少平台，例如 5 个而引擎上报 6 个 ——
    //   日志实测 `引擎 就绪 ✓ sources=6`）。当前引擎脚本一律以「引擎实时 sources」为准，
    //   只要它比持久化的更全就用它。
    if (api.id === (AppStorage.get<string>('lxEngineScriptId') ?? '')) {
      const json: string = AppStorage.get<string>('lxEngineSources') ?? '';
      // ★ 2026-10-30：把引擎上报的**原始 key**打出来（判断第 6 个平台到底叫什么）
      appendPlayLog('[RzdSource] raw=' + json.substring(0, Math.min(json.length, 220)));
      if (json.length > 2) {
        try {
          const live: LXSourcePlatformInfo[] =
            lxDeclaredPlatforms(JSON.parse(json) as Record<string, LXUserApiSourceInfo>);
          appendPlayLog('[RzdSource] persisted=' + declared.length + ' engine=' + live.length);
          if (live.length > declared.length) {
            return live;
          }
        } catch (err) {
          appendPlayLog('[RzdSource] live sources parse failed');
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
      SwipeTextIcon('分享', '#7B1FA2', (): void => {
        appendPlayLog('[RzdSourceShare] swipe tap id=' + api.id);
        this.onShare(api);
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