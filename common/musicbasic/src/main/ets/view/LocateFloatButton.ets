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

import { motion } from '@kit.MultimodalAwarenessKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'RzdLocateGrip';

/**
 * 「定位到当前播放」浮动圆按钮（**智感握姿**：跟着握持/交互手换边）。
 *
 * ## 用户口径（2026-10-19）
 * ① 图标要跟**播放器内播放列表**那颗定位按钮一致（`app.media.ic_locate_current`，
 *    与 `QueuePlaylistSheet` 里那颗同一个 SVG：圆圈 + 十字准星）；
 * ② **不要蓝色底**：原来是一颗 52vp 的圆，底色 `sys.color.background_emphasize`（蓝）；
 *    现在改成**材质背板 + 主题色图标**，直径 40vp、图标 22vp（用户说「太大」）；
 * ③ 要**智感握姿**（跟手换边，拇指够得着）。
 *
 * ## 智感握姿为什么能三方实现（与之前结论不同，这里改正）
 * 之前本仓注释写过"智感握姿没对三方开放"——那是**只看了 HDS 的 `adaptToHandedness`
 * （那是 HDS 组件专用属性）**。系统另有公开能力：
 * `@kit.MultimodalAwarenessKit` 的 `motion`（`SystemCapability.MultimodalAwareness.Motion`）：
 * - `getRecentOperatingHandStatus()` —— 最近一次**操作手**（`LEFT_HAND_OPERATED` / `RIGHT_HAND_OPERATED`）；
 * - `on('operatingHandChanged', cb)` —— 操作手变化（API 15）；
 * - `on('holdingHandChanged', cb)` —— **握持手**变化（API 20），操作手未知时的兜底。
 * 官方建议换侧用 `TransitionEffect.move(edge)` 做侧滑动画，本组件照做。
 *
 * 优先级：**操作手 > 握持手 > 默认右侧**（操作手一旦识别过就不再被握持手覆盖，
 * 否则用户抬手操作时会把球拽回握持侧，来回抖）。
 *
 * 排查日志关键字：`RzdLocateGrip`（`hilog | grep RzdLocateGrip`，
 * 会打 `side=left/right source=recent|operating|holding`）。
 */
@ComponentV2
export struct LocateFloatButton {
  /** 图标（默认与播放列表那颗定位按钮同一个 SVG）。 */
  @Param icon: Resource = $r('app.media.ic_locate_current');
  /** 图标着色（一般传 `ThemeState.color`）。 */
  @Param tint: ResourceColor = $r('sys.color.font_primary');
  /** 距底部距离（vp）：要避开壳层那条悬浮播放条（56 + 间距）。 */
  @Param bottomInset: number = 96;
  /** 距屏幕左右边距（vp）。 */
  @Param sideMargin: number = 18;
  /** 是否可用（没有正在播放时可传 false，视觉不变但点不动）。 */
  @Param clickable: boolean = true;
  /** 点击回调。 */
  @Event onTap: () => void = (): void => {
  };
  /** 当前在右侧还是左侧（智感握姿驱动）。 */
  @Local rightSide: boolean = true;

  /** 操作手是否已经识别过（识别过就不再听握持手）。 */
  private operatingKnown: boolean = false;

  /** 操作手变化回调。 */
  private handCb: Callback<motion.OperatingHandStatus> = (status: motion.OperatingHandStatus): void => {
    if (status === motion.OperatingHandStatus.LEFT_HAND_OPERATED) {
      this.operatingKnown = true;
      this.rightSide = false;
      hilog.info(DOMAIN, TAG, 'side=left source=operating');
    } else if (status === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
      this.operatingKnown = true;
      this.rightSide = true;
      hilog.info(DOMAIN, TAG, 'side=right source=operating');
    }
  };

  /** 握持手变化回调（仅在操作手未知时生效）。 */
  private holdCb: Callback<motion.HoldingHandStatus> = (status: motion.HoldingHandStatus): void => {
    if (this.operatingKnown) {
      return;
    }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      this.rightSide = false;
      hilog.info(DOMAIN, TAG, 'side=left source=holding');
    } else if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      this.rightSide = true;
      hilog.info(DOMAIN, TAG, 'side=right source=holding');
    }
  };

  aboutToAppear(): void {
    if (!canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      hilog.info(DOMAIN, TAG, 'motion syscap unavailable, keep right side');
      return;
    }
    try {
      const recent: motion.OperatingHandStatus = motion.getRecentOperatingHandStatus();
      if (recent === motion.OperatingHandStatus.LEFT_HAND_OPERATED) {
        this.operatingKnown = true;
        this.rightSide = false;
        hilog.info(DOMAIN, TAG, 'side=left source=recent');
      } else if (recent === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
        this.operatingKnown = true;
        this.rightSide = true;
        hilog.info(DOMAIN, TAG, 'side=right source=recent');
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getRecentOperatingHandStatus failed: %{public}s', (e as BusinessError).message);
    }
    try {
      motion.on('operatingHandChanged', this.handCb);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'on operatingHandChanged failed: %{public}s', (e as BusinessError).message);
    }
    try {
      motion.on('holdingHandChanged', this.holdCb);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'on holdingHandChanged failed: %{public}s', (e as BusinessError).message);
    }
  }

  aboutToDisappear(): void {
    if (!canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      return;
    }
    try {
      motion.off('operatingHandChanged', this.handCb);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'off operatingHandChanged failed: %{public}s', (e as BusinessError).message);
    }
    try {
      motion.off('holdingHandChanged', this.holdCb);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'off holdingHandChanged failed: %{public}s', (e as BusinessError).message);
    }
  }

  /** 圆按钮本体：材质背板 + 主题色图标 + 点光 + 换侧侧滑动画。 */
  @Builder
  private Ball(edge: TransitionEdge) {
    Column() {
      Image(this.icon)
        .width(22)
        .height(22)
        .fillColor(this.tint)
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    // ★ 不要蓝色底：材质背板（浅色下是半透明白、深色下是半透明黑，并跟随背后画面）
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.AVERAGE
    })
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 14, color: 'rgba(0, 0, 0, 0.28)', offsetX: 0, offsetY: 4 })
    .enabled(this.clickable)
    .opacity(this.clickable ? 1 : 0.45)
    .transition(TransitionEffect.move(edge).animation({ duration: 250, curve: Curve.Friction }))
    .onClick((): void => {
      hilog.info(DOMAIN, TAG, 'tap side=%{public}s', this.rightSide ? 'right' : 'left');
      this.onTap();
    })
  }

  build() {
    Column() {
      Blank()
      Row() {
        if (this.rightSide) {
          this.Ball(TransitionEdge.END)
        } else {
          this.Ball(TransitionEdge.START)
        }
      }
      .width('100%')
      .justifyContent(this.rightSide ? FlexAlign.End : FlexAlign.Start)
      .padding({ left: this.sideMargin, right: this.sideMargin, bottom: this.bottomInset })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
