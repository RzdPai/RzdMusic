/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AppStorageV2, ComponentContent, LengthMetrics, uiObserver } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BlurStrategy, hdsMaterial, HdsNavDestination, HdsNavigationTitleBarOptions, ScrollEffectType, SystemMaterialParams } from '@kit.UIDesignKit';
import {
  AmbientState,
  AppStorageKeys,
  BreakpointConstants,
  BreakpointType,
  getAppRuntime,
  getWindowInfoState,
  GridConstants,
  BoardSongParam,
  ImmersiveType,
  MusicStoreService,
  SdkApiUtil,
  StyleConstants,
  TitleBarConstants,
  ToplistRouteParam,
  WindowInfo
} from 'musicbasic';
import { MusicListPlaybackViewModel } from '../viewmodel/MusicListPlaybackViewModel';
import { PlaylistDetailHeroSection } from './PlaylistDetailHeroSection';
import { PlaylistFloatingMiniBar } from './PlaylistFloatingMiniBar';
import { PlaylistDetailSongListSection } from './PlaylistDetailSongListSection';

/** One LXMusic export song entry. */
const PLAYLIST_LOG_DOMAIN: number = 0x0000;
const PLAYLIST_LOG_TAG: string = 'RzdPlaylistDetail';

interface LxSongJsonMeta {
  songId: string;
  songmid: string;
  picUrl: string;
  albumName: string;
  albumId: string;
}

interface LxSongJson {
  name: string;
  singer: string;
  source: string;
  songId: string;
  songmid: string;
  albumName: string;
  albumId: string;
  interval: string;
  img: string;
  meta: LxSongJsonMeta;
}

/** LXMusic playlist export JSON root shape. */
interface LxPlaylistJson {
  type: string;
  name: string;
  songs: LxSongJson[];
}

/**
 * Full-screen playlist detail page with hero header, song list, and floating mini player.
 */

/** 标题栏「四个点」下拉菜单回调容器：全局 @Builder 通过模块级回调中转。 */
let playlistMoreAction: ((action: string) => void) | null = null;

/** 「四个点」菜单内容（openMenu 用，必须为全局 @Builder + wrapBuilder）。 */
@Builder
function playlistMoreMenuComponent() {
  Menu() {
    MenuItem({ content: '搜索当前歌单' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('search');
        }
      })
    MenuItem({ content: '自定义排序顺序' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('customSort');
        }
      })
    MenuItem({ content: '歌曲去重' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('dedupe');
        }
      })
  }
  .width(200)
}

@ComponentV2
export struct PlaylistDetailPage {
  /** Current window width/height breakpoint from the design system environment. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** View model driving playlist songs and play actions for this page. */
  @Local listVm: MusicListPlaybackViewModel = new MusicListPlaybackViewModel();
  /** QQ music toplist id when this page shows an online toplist; empty for local playlists. */
  @Param topid: string = '';
  /** Display title for the online toplist (used in the title bar). */
  @Param listTitle: string = '';
  /** 'history' or 'favorites' to load local store lists instead of an online toplist. */
  @Param sectionType: string = '';
  /** Playlist id when sectionType is 'playlist'. */
  @Param playlistId: string = '';
  /** Music source id when sectionType is 'onlinePlaylist'. */
  @Param onlineSource: string = '';
  /** Board music source when opening a multi-source ranking board. */
  @Param boardSource: string = '';
  /** Board id within the board source. */
  @Param boardId: string = '';
  /** Prefetched board songs handed over through the route param. */
  @Param boardSongs: BoardSongParam[] = [];
  /** Window chrome and immersive layout information shared app-wide. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** Ambient material level (0 = follow system) for title bar button styling. */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** Hero header area width in pixels, updated from child layout. */
  @Local private headerWidthPx: number = 0;
  /** Hero header area height in pixels, updated from child layout. */
  @Local private headerHeightPx: number = 0;
  /** Curve depth in pixels for the small-screen hero clip shape. */
  @Local private depth: number = 18;
  /** Vertical scroller for the main playlist content. */
  private pageScrollScroller: Scroller = new Scroller();
  /** Dynamic top padding applied while scrolling under the title bar. */
  @Local paddingTop: number = 0;
  /** Available list area height (vp) measured from the host container. */
  @Local songListHeightVp: number = 700;
  /** Whether the in-playlist search sheet is visible. */
  @Local showSearchSheet: boolean = false;
  /** Live search keyword filtering the playlist songs. */
  @Local searchKeyword: string = '';
  /** Sort mode command forwarded to the song list (0 default / 1 title / 2 singer). */
  @Local externalSortMode: number = -1;
  /** 自定义排序顺序指令（递增触发，转发给歌曲列表进入排序模式）。 */
  @Local customSortCommand: number = 0;
  /** 歌曲去重指令（递增触发，转发给歌曲列表执行去重）。 */
  @Local dedupeCommand: number = 0;
  /** 标题栏「四个点」菜单图标 componentId（openMenu 锚点）。 */
  private readonly moreMenuTargetId: string = 'playlist_more_menu_icon';
  /** 缓存菜单内容节点，避免每次点击重复创建。 */
  private moreMenuNode: ComponentContent<Object> | null = null;

  /**
   * Whether the current width breakpoint is small or medium.
   * @returns True when layout is SM or MD.
   */
  private isWidthBreakpointSmOrMd(): boolean {
    const w: WidthBreakpoint = this.breakpointEnv.widthBreakpoint;
    return w === WidthBreakpoint.WIDTH_SM || w === WidthBreakpoint.WIDTH_MD;
  }

  /**
   * Whether this page uses the mainline playlist detail layout (large width, immersive, or legacy SDK).
   * @returns True when hero and list follow the mainline composition rules.
   */
  private isPlaylistDetailMainline(): boolean {
    const w: WidthBreakpoint = this.breakpointEnv.widthBreakpoint;
    return SdkApiUtil.isSdkApiAtMost(22) ||
      this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ||
      w === WidthBreakpoint.WIDTH_LG ||
      w === WidthBreakpoint.WIDTH_XL;
  }

  /**
   * Whether the PC immersive bottom bar should participate in normal column flow.
   * @returns True when immersive decoration is active.
   */
  private isPcImmersiveBottomBarInFlow(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  /**
   * Scroll handler: drives {@link paddingTop} from {@link pageScrollScroller} so content clears the title bar.
   * Mainline + immersive skips dynamic padding (fixed inset handled elsewhere).
   */
  private onPlaylistScrollDidScroll(): void {
    if (this.isPlaylistDetailMainline() && this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return;
    }
    const offset: number = this.pageScrollScroller.currentOffset().yOffset;
    if (offset > 0 && offset < 56) {
      this.paddingTop = offset;
    } else if (offset >= 56) {
      this.paddingTop = 56;
    } else {
      this.paddingTop = 0;
    }
  }

  /**
   * Builds the scrollable grid of hero and song list sections.
   */
  @Builder
  private PlaylistScrollContentRoot() {
    Column() {
      GridRow({
        columns: {
          sm: BreakpointConstants.COLUMN_LG,
          md: BreakpointConstants.COLUMN_LG,
          lg: BreakpointConstants.COLUMN_LG,
          xl: BreakpointConstants.COLUMN_LG
        }
      }) {
        GridCol({
          span: {
            sm: GridConstants.SPAN_TWELVE,
            md: GridConstants.SPAN_TWELVE,
            lg: GridConstants.SPAN_FOUR,
            xl: GridConstants.SPAN_FOUR
          }
        }) {
          PlaylistDetailHeroSection({
            headerWidthPx: this.headerWidthPx,
            headerHeightPx: this.headerHeightPx,
            depth: this.depth,
            onHeaderAreaChange: (widthPx: number, heightPx: number) => {
              this.headerWidthPx = widthPx;
              this.headerHeightPx = heightPx;
            }
          })
        }

        GridCol({
          span: {
            sm: GridConstants.SPAN_TWELVE,
            md: GridConstants.SPAN_TWELVE,
            lg: GridConstants.SPAN_EIGHT,
            xl: GridConstants.SPAN_EIGHT
          }
        }) {
          PlaylistDetailSongListSection({
            listVm: this.listVm,
            listHeightVp: this.songListHeightVp,
            playlistId: this.sectionType === 'playlist' ? this.playlistId : '',
            searchKeyword: this.searchKeyword,
            externalSortMode: this.externalSortMode,
            customSortCommand: this.customSortCommand,
            dedupeCommand: this.dedupeCommand
          })
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .alignItems(ItemAlign.Start)
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  /**
   * Builds the nav destination body: either column+mini bar in flow or stacked mini bar overlay.
   */
  @Builder
  private PlaylistNavDestinationSlot() {
    if (this.isPcImmersiveBottomBarInFlow()) {
      Column() {
        Scroll(this.pageScrollScroller) {
          this.PlaylistScrollContentRoot()
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({
          top: this.isPlaylistDetailMainline() ?
            (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 56 : this.paddingTop) :
            this.paddingTop
        })
        .onDidScroll((): void => {
          this.onPlaylistScrollDidScroll();
        })
        .backgroundColor($r('app.color.playlist_detail_background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        PlaylistFloatingMiniBar()
          .width(StyleConstants.FULL_WIDTH)
          .padding({
            left: 0,
            right: 0
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll(this.pageScrollScroller) {
          this.PlaylistScrollContentRoot()
        }
        .height('100%')
        .scrollBar(BarState.Off)
        .padding({
          top: this.isPlaylistDetailMainline() ? 56 : this.paddingTop
        })
        .onDidScroll((): void => {
          this.onPlaylistScrollDidScroll();
        })
        .backgroundColor($r('app.color.playlist_detail_background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        PlaylistFloatingMiniBar()
          .zIndex(10)
          .margin({
            left: new BreakpointType(16, 24, 32, 32, 9).getWidthValueWithHeightSM(
              this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint),
            right: new BreakpointType(16, 24, 32, 32, 9).getWidthValueWithHeightSM(
              this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint)
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const h: number = Number.parseFloat(newArea.height.toString());
        if (h > 0) {
          // Reserve space for the floating mini bar so the list viewport ends above it.
          this.songListHeightVp = Math.max(200, h - 80);
        }
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  /**
   * Title bar button (back / menu) background: frosted translucent white so the
   * buttons match the translucent system material of the floating bar.
   */
  private ambientTitleButtonBackground(): ResourceColor {
    return $r('app.color.floating_mini_bar_background');
  }

  /** System material for the title bar, following the ambient light level like the home tab bar. */
  private ambientTitleMaterial(): SystemMaterialParams {
    switch (this.ambientState.level) {
      case 1:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.SMOOTH };
      case 2:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.GENTLE };
      case 3:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.EXQUISITE };
      default:
        return { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE };
    }
  }

  /** Exports the current playlist to a user-chosen file in LXMusic JSON format. */
  private exportPlaylist(): void {
    const rt = getAppRuntime();
    const ctx = rt.context;
    const uiContext = rt.uiContext;
    const toast = (message: string): void => {
      if (uiContext !== undefined) {
        uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
      }
    };
    if (ctx === undefined) {
      toast('导出失败');
      return;
    }
    const title: string = this.listTitle.length > 0 ? this.listTitle : '歌单';
    try {
      const safeName: string = title.replace(/[\\/:*?"<>|]/g, '_');
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = ['lx_' + safeName + '_' + Date.now() + '.json'];
      docPicker.save(saveOptions).then((uris: string[]): void => {
        if (uris.length === 0) {
          return;
        }
        try {
          const encoder: util.TextEncoder = new util.TextEncoder();
          const data: Uint8Array = encoder.encodeInto(this.buildExportJson());
          const file: fs.File = fs.openSync(uris[0],
            fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fs.writeSync(file.fd, data.buffer as ArrayBuffer);
          fs.closeSync(file);
          toast('已导出歌单');
        } catch (_err) {
          toast('导出失败');
        }
      }).catch((_err: Object): void => {
        // user cancelled
      });
    } catch (_err) {
      toast('无法打开保存选择器');
    }
  }

  /** 标题栏「四个点」：锚定标题栏图标弹出菜单。 */
  private openMoreMenu(): void {
    if (this.moreMenuNode === null) {
      this.moreMenuNode = new ComponentContent(this.getUIContext(), wrapBuilder(playlistMoreMenuComponent));
    }
    this.getUIContext().getPromptAction().openMenu(this.moreMenuNode, { id: this.moreMenuTargetId })
      .catch((err: BusinessError): void => {
        hilog.error(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG, 'openMenu more failed: %{public}d %{public}s',
          err.code, err.message);
      });
  }

  /** Builds the LXMusic export JSON from the currently displayed playlist songs. */
  private buildExportJson(): string {
    const songs: LxSongJson[] = [];
    const uis = this.listVm.playlistSongUis;
    for (let i = 0; i < uis.length; i++) {
      const s = uis[i];
      const songJson: LxSongJson = {
        name: typeof s.title === 'string' ? s.title : '',
        singer: typeof s.singer === 'string' ? s.singer : '',
        source: s.source,
        songId: s.songId,
        songmid: s.songId,
        albumName: '',
        albumId: '',
        interval: '',
        img: s.coverUrl,
        meta: {
          songId: s.songId, songmid: s.songId, picUrl: s.coverUrl, albumName: '', albumId: ''
        }
      };
      songs.push(songJson);
    }
    const payload: LxPlaylistJson = {
      type: 'musicList',
      name: this.listTitle.length > 0 ? this.listTitle : '歌单',
      songs: songs
    };
    return JSON.stringify(payload);
  }

  /**
   * Builds HDS title bar options for back, menu, padding, and scroll/blur styles for this route.
   * @returns Configured navigation title bar for the current breakpoint and immersive mode.
   */
  private getPlaylistDetailTitleBar(): HdsNavigationTitleBarOptions {
    const startVp: number = new BreakpointType(16, 24, 24, 24, 18).getWidthValueWithHeightSM(
      this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint);
    const endVp: number = this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
      Math.max(0, this.windowInfo.titleButtonWidthVp) + 8 : startVp;
    if (this.isPlaylistDetailMainline()) {
      if (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
        return {
          padding: {
            start: LengthMetrics.vp(startVp),
            end: LengthMetrics.vp(endVp)
          },
          style: {
            originalStyle: {
              backgroundStyle: {
                backgroundColor: $r('app.color.playlist_detail_background')
              }
            },
            scrollEffectStyle: {
              backgroundStyle: {
                backgroundColor: $r('app.color.playlist_detail_background')
              }
            },
            systemMaterialEffect: this.ambientTitleMaterial()
          },
          content: {
            title: {
              mainTitle: this.listTitle
            },
            backIcon: {
              label: 'back',
              icon: $r('sys.symbol.chevron_left'),
              isEnabled: true
            },
            menu: {
              value: [
                {
                  content: {
                    label: 'share',
                    icon: $r('sys.symbol.share'),
                    isEnabled: true,
                    action: (): void => {
                      setTimeout((): void => {
                        this.exportPlaylist();
                      }, 400);
                    }
                  }
                },
                {
                  content: {
                    label: 'more',
                    icon: $r('sys.symbol.dot_grid_2x2'),
                    isEnabled: true,
                    componentId: this.moreMenuTargetId,
                    action: (): void => {
                      this.openMoreMenu();
                    }
                  }
                }
              ]
            }
          }
        };
      }
      return {
        padding: {
          start: LengthMetrics.vp(startVp),
          end: LengthMetrics.vp(endVp)
        },
        style: {
          originalStyle: {
            backgroundStyle: {
              backgroundColor: $r('app.color.playlist_detail_background')
            },
            contentStyle: {
              backIconStyle: {
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: this.ambientTitleButtonBackground()
              },
              menuStyle: {
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: this.ambientTitleButtonBackground()
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: $r('app.color.playlist_detail_background')
            },
            contentStyle: {
              backIconStyle: {
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: this.ambientTitleButtonBackground()
              },
              menuStyle: {
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: this.ambientTitleButtonBackground()
              }
            }
          },
          systemMaterialEffect: this.ambientTitleMaterial()
        },
        content: {
          title: {
            mainTitle: this.listTitle
          },
          backIcon: {
            label: 'back',
            icon: $r('sys.symbol.chevron_left'),
            isEnabled: true
          },
          menu: {
            value: [
              {
                content: {
                  label: 'share',
                  icon: $r('sys.symbol.share'),
                  isEnabled: true,
                  action: (): void => {
                    setTimeout((): void => {
                      this.exportPlaylist();
                    }, 400);
                  }
                }
              },
              {
                content: {
                  label: 'more',
                  icon: $r('sys.symbol.dot_grid_2x2'),
                  isEnabled: true,
                  componentId: this.moreMenuTargetId,
                  action: (): void => {
                    this.openMoreMenu();
                  }
                }
              }
            ]
          }
        }
      };
    }
    return {
      padding: {
        start: LengthMetrics.vp(startVp),
        end: LengthMetrics.vp(endVp)
      },
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          enableScrollEffect: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? false : true,
          enableRefreshOffsetChange: false,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent
          },
          contentStyle: {
            backIconStyle: {
              iconColor: $r('app.color.on_primary90'),
            },
            menuStyle: {
              iconColor: $r('app.color.on_primary90'),
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            blurRadius: 40
          },
          contentStyle: {
            backIconStyle: {
              iconColor: $r('sys.color.font_primary'),
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
            }
          }
        },
        systemMaterialEffect: this.ambientTitleMaterial()
      },
      content: {
        title: {
          mainTitle: this.listTitle
        },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true
        },
        menu: {
          value: [
            {
              content: {
                label: 'share',
                icon: $r('sys.symbol.share'),
                isEnabled: true,
                action: (): void => {
                  setTimeout((): void => {
                    this.exportPlaylist();
                  }, 400);
                }
              }
            },
            {
              content: {
                label: 'more',
                icon: $r('sys.symbol.dot_grid_2x2'),
                isEnabled: true,
                componentId: this.moreMenuTargetId,
                action: (): void => {
                  this.openMoreMenu();
                }
              }
            }
          ]
        }
      }
    };
  }

  /**
   * Runs when the page appears: converts curve depth to px and refreshes playlist data.
   */
  private onPlaylistDetailPageAppear(): void {
    this.depth = this.getUIContext().vp2px(18);
    playlistMoreAction = (action: string): void => {
      this.handleMoreAction(action);
    };
    if (this.boardSource.length > 0 && this.boardId.length > 0) {
      this.listVm.loadBoardSongs(this.boardSongs);
    } else if (this.topid.length > 0) {
      this.listVm.loadOnlineToplist(this.topid);
    } else if (this.sectionType === 'history') {
      this.listVm.loadHistorySongs();
    } else if (this.sectionType === 'favorites') {
      this.listVm.loadFavoriteSongs();
    } else if (this.sectionType === 'queue') {
      this.listVm.loadQueueSongs();
    } else if (this.sectionType === 'playlist') {
      this.listVm.loadPlaylistSongs(this.playlistId);
    } else if (this.sectionType === 'onlinePlaylist' && this.onlineSource.length > 0) {
      this.listVm.loadOnlinePlaylistSongs(this.onlineSource, this.playlistId);
    } else {
      this.listVm.syncPlaylistFromApi();
    }
  }

  /** 标题栏「四个点」菜单项回调分发。 */
  private handleMoreAction(action: string): void {
    if (action === 'search') {
      this.showSearchSheet = true;
    } else if (action === 'customSort') {
      this.customSortCommand++;
    } else if (action === 'dedupe') {
      this.dedupeCommand++;
    }
  }

  /** In-playlist search sheet: live filter over the current song list. */
  @Builder
  private SearchSheet() {
    Column({ space: 16 }) {
      Text('搜索当前歌单')
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({ text: this.searchKeyword, placeholder: '输入歌名或歌手' })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12 })
        .defaultFocus(true)
        .onChange((value: string) => {
          this.searchKeyword = value;
        })

      Button('完成')
        .width('100%')
        .height(40)
        .fontSize($r('sys.float.Body_M'))
        .borderRadius($r('sys.float.corner_radius_level6'))
        .backgroundColor(MusicStoreService.getInstance().getThemeColor())
        .fontColor($r('sys.color.font_on_primary'))
        .onClick(() => {
          this.showSearchSheet = false;
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 32 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /**
   * Composes the HDS nav destination, title bar, and scrollable playlist content.
   */
  build() {
    HdsNavDestination() {
      this.PlaylistNavDestinationSlot()
    }
    .hideTitleBar(false)
    .titleBar(this.getPlaylistDetailTitleBar())
    .bindToScrollable([this.pageScrollScroller])
    .backgroundColor($r('app.color.playlist_detail_background'))
    .systemBarStyle(
      { statusBarContentColor: this.isWidthBreakpointSmOrMd() ? '#FFFFFF' : '#000000' },
      { statusBarContentColor: '#000000' })
    .onAppear((): void => {
      this.onPlaylistDetailPageAppear();
    })
    .onDisAppear((): void => {
      playlistMoreAction = null;
      if (this.moreMenuNode !== null) {
        this.moreMenuNode.dispose();
        this.moreMenuNode = null;
      }
    })
    .bindSheet($$this.showSearchSheet, this.SearchSheet(), {
      height: 220,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('sys.color.background_secondary')
    });
  }
}

/**
 * Global builder entry for routing to {@link PlaylistDetailPage}.
 * @param name Route or page name (unused placeholder for navigation integration).
 * @param param Optional route parameters object ({topid, listTitle} for online toplists).
 */
@Builder
export function PlaylistDetailPageBuilder(name: string, param: Object) {
  PlaylistDetailPage({
    topid: (param as ToplistRouteParam | undefined)?.topid ?? '',
    listTitle: (param as ToplistRouteParam | undefined)?.listTitle ?? '',
    sectionType: (param as ToplistRouteParam | undefined)?.sectionType ?? '',
    playlistId: (param as ToplistRouteParam | undefined)?.playlistId ?? '',
    onlineSource: (param as ToplistRouteParam | undefined)?.onlineSource ?? '',
    boardSource: (param as ToplistRouteParam | undefined)?.boardSource ?? '',
    boardId: (param as ToplistRouteParam | undefined)?.boardId ?? '',
    boardSongs: (param as ToplistRouteParam | undefined)?.boardSongs ?? []
  })
}
