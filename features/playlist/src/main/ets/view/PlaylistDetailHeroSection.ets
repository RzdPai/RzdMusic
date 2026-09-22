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
import { BreakpointType, isWidthBreakpointLgOrXl } from 'musicbasic';

/**
 * 歌单详情大图 Hero：与歌手/专辑详情页同款——
 * 顶部整幅封面大图 + 底部向页面底色没入的渐变 + 居中大标题 + 圆形毛玻璃播放按钮。
 * 取色（avgColor）与前景色由宿主页面算好通过参数传入，本组件只负责排版。
 */
@ComponentV2
export struct PlaylistDetailHeroSection {
  /** 断点环境，用于封面高度与标题字号的自适应。 */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** 封面图片地址；为空时显示占位图标。 */
  @Param coverUrl: string = '';
  /** 歌单 / 榜单标题。 */
  @Param title: string = '';
  /** 副标题（如「128 首 · 收藏」），为空则不显示。 */
  @Param subtitle: string = '';
  /** 播放按钮点击回调（播放全部）。 */
  @Param onPlayAll: () => void = (): void => {};
  /** 页面取色背景，渐变没入用。 */
  @Param backdropColor: string = '#1f1f22';
  /** 主文字/图标颜色（由宿主按背景明暗给出）。 */
  @Param fgColor: ResourceColor = '#FFFFFF';
  /** 次要文字颜色。 */
  @Param fgSecondaryColor: ResourceColor = '#B3FFFFFF';
  /** 圆形播放按钮底色。 */
  @Param buttonTint: ResourceColor = '#33FFFFFF';
  /** 圆形播放按钮毛玻璃强度。 */
  @Param buttonBlur: BlurStyle = BlurStyle.Regular;

  /** 加载失败后回退到占位图标，避免一片空白。 */
  @Local imageFailed: boolean = false;

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
      if (this.coverUrl.length > 0 && !this.imageFailed) {
        Image(this.coverUrl)
          .width('100%')
          .height(this.heroHeightVp())
          .objectFit(ImageFit.Cover)
          .onError(() => {
            this.imageFailed = true;
          })
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(56)
            .fontWeight(FontWeight.Regular)
            .fontColor([this.fgSecondaryColor])
        }
        .width('100%')
        .height(this.heroHeightVp())
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#1f2328')
      }

      // 渐变：封面下缘没入页面取色背景。高度 150 与歌手页一致（原来是 190/210）。
      Column()
        .width('100%')
        .height(150)
        .linearGradient({
          colors: [[Color.Transparent, 0], [this.backdropColor, 1]],
          angle: 180,
          direction: GradientDirection.Bottom
        })

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
