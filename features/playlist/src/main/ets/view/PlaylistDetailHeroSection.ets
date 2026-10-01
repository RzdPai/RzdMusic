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


import { uiObserver } from '@kit.ArkUI';

/**
 * 歌单详情 Hero —— **与歌手页 (ArtistDetailPage.ArtistHero) 完全同一种写法**：
 * 这里只画「标题 + 播放按钮」这一层前景内容，**不画图片、不画蒙版**。
 *
 * 照片与从上到下（纯透明 → 页面取色不透明）的遮罩**只由页面级装饰层
 * `PlaylistImmersiveBackdrop` 负责**，它用 matchParent + ignoreLayoutSafeArea(TOP)
 * 把照片铺到状态栏，并跟随列表滚动平移。
 *
 * ⚠️ 曾经这里自己也画了一张 320vp 的封面 + 一条 320vp 的渐变：
 *    结果页面上就是**两张图**（装饰层一张 320+56+状态栏高、Hero 一张 320），
 *    两张图 ImageFit.Cover 的裁切不一样，接缝与双层蒙版叠在一起非常难看。
 *    歌手页之所以好看，就是因为它只画前景这一层。
 *
 * 转场（一镜到底的封面飞行）不受影响：真正的落点锚点 `PLAYLIST_HERO_COVER_ID`
 * 挂在装饰层的照片盒子上（见 `PlaylistImmersiveBackdrop`），落点矩形与装饰层照片
 * 完全重合，飞行结束交棒时不会有任何跳变。
 */
@ComponentV2
export struct PlaylistDetailHeroSection {
  /** 断点环境，用于封面高度与标题字号的自适应。 */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /**
   * 封面地址。**本组件不再绘制它**（照片由页面级装饰层画），
   * 保留参数是为了让宿主页面那条 `coverVersion` 重建信号依然被读取。
   */
  @Param coverUrl: string = '';
  /** 转场 token（本组件不再使用，由装饰层与页面共用）。 */
  @Param transitionToken: number = 0;
  /** 歌单 / 榜单标题。 */
  @Param title: string = '';
  /** 副标题（如「128 首 · 收藏」），为空则不显示。 */
  @Param subtitle: string = '';
  /** 播放按钮点击回调（播放全部）。 */
  @Param onPlayAll: () => void = (): void => {};
  /** 页面取色背景（遮罩由装饰层负责，这里只为将来微调保留）。 */
  @Param backdropColor: string = '#1f1f22';
  /** 主文字/图标颜色（由宿主按背景明暗给出）。 */
  @Param fgColor: ResourceColor = '#FFFFFF';
  /** 次要文字颜色。 */
  @Param fgSecondaryColor: ResourceColor = '#B3FFFFFF';
  /** 圆形播放按钮底色。 */
  @Param buttonTint: ResourceColor = '#33FFFFFF';
  /** 圆形播放按钮毛玻璃强度。 */
  @Param buttonBlur: BlurStyle = BlurStyle.Regular;

  /**
   * 封面高度（vp）。
   *
   * 与歌手页**完全一致（320）**：歌手页（ArtistDetailPage）看起来没有任何问题，
   * 所以这里不再按断点做 260/320/340 的差异化 —— 差异化正是"样式还有问题"的来源之一。
   */
  private heroHeightVp(): number {
    return 320;
  }

  /** 标题字号（fp）：与歌手页一致（28）。 */
  private titleFontSize(): number {
    return 28;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // Hero 大标题现在是页面的**唯一**标题（HDS 标题栏已不放文字，见
        // PlaylistDetailPage.getPlaylistDetailTitleBar），所以允许折两行。
        Text(this.title.length > 0 ? this.title : '歌单')
          .fontSize(this.titleFontSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(this.fgColor)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ left: 20, right: 20 })

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize($r('sys.float.Caption_L'))
            .fontColor(this.fgSecondaryColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ left: 20, right: 20, top: 6 })
        }

        Row() {
          Row() {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(26)
              .fontWeight(FontWeight.Regular)
              .height(26)
              .fontColor([this.fgColor])
          }
          .width(60)
          .height(60)
          .borderRadius(30)
          .backgroundColor(this.buttonTint)
          .backgroundBlurStyle(this.buttonBlur)
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.onPlayAll();
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height(this.heroHeightVp())
  }
}
