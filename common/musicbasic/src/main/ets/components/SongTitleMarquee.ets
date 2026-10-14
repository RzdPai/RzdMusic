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

/**
 * 歌名跑马灯：**各页面歌曲列表行 / 播放页歌名**的统一出口。
 *
 * ## 为什么要有这个组件
 * 用户要求「各个页面歌曲名过长时改为用跑马灯显示」。工程里歌名原本散落在十几个
 * `Text(...).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })` 上，
 * 如果每处各写一遍 `marqueeOptions`，参数迟早会走散（本仓已有 4 处各写一套的先例，
 * 参数互不相同）。这里把「跑马灯那 5 个参数 + 单行语义」收成一个组件。
 *
 * ## 原生语义（不要再自己算宽度）
 * `TextOverflow.MARQUEE` 的语义就是**只有文本宽度超过组件宽度时才滚动**，否则静止不动。
 * 所以调用方**只需要把宽度定下来**（和原本 `Ellipsis` 时完全一样），不需要测量或比较宽度。
 *
 * ## API 依据（本机 SDK `D:\command-line-tools\sdk`，逐条核对过）
 * - `Text.marqueeOptions(options: Optional<TextMarqueeOptions>): TextAttribute`（**@since 18**，
 *   `openharmony/ets/component/text.d.ts:1615`）。
 * - `TextMarqueeOptions`（同文件 `:2177`）字段：`start: boolean`（**必填**）、`step?: number`、
 *   `loop?: number`、`fromStart?: boolean`、`delay?: number`、`fadeout?: boolean`、
 *   `marqueeStartPolicy?: MarqueeStartPolicy`；`spacing?` / `marqueeUpdatePolicy?` 是 **@since 23**
 *   （本工程 compatible 6.1.1(24) 可用，但默认值已经够用，故不显式设置）。
 * - `TextOverflow.MARQUEE` 与 `MarqueeStartPolicy` 都是 ArkUI 全局枚举，**不需要 import**。
 * - ⚠️ 官方《Text》+ d.ts 注明：设为 `MARQUEE` 时 **`textAlign` 不生效（文本可滚动时）**、
 *   **`maxLines` / `copyOption` 不生效、`clip` 默认 true**。这里仍然显式写 `maxLines(1)`，
 *   理由是**保持与工程内已有那 4 处跑马灯逐字同构**（`SongPage` / `HomeCapsuleHeader` /
 *   `WearableHome` / `OnlineSearchPage`），并且把"本组件只做单行"的意图写在代码里；
 *   它**不是**行高的保证手段 —— 行高由跑马灯自身的单行语义决定。
 *
 * ## 参数取值
 * - `start: true` —— 必须为 true 才会进入播放态。
 * - `step: 4`（vp/帧）—— SDK 默认是 6（`marquee.d.ts` 的 `@default 6`）。默认值在手机宽度下
 *   偏快，4 更接近"读得清"的速度；**且官方注明"step 大于文本宽度时取默认值"**，所以取值安全。
 * - `loop: -1` —— SDK 与官方文档原文：「小于等于 0 时无限循环」（`marquee.d.ts:176`）。
 * - `fromStart: true` —— 每次从开头滚（而不是从尾部往回滚），可读性更好。
 * - `delay: 1000`（ms）—— 停下 1 秒再开始滚，避免列表一屏好几行同时动，视觉很吵。
 * - `fadeout: false` —— 不要首尾淡出（列表行本身有底，淡出会显得脏）。
 * - `marqueeStartPolicy: MarqueeStartPolicy.DEFAULT` —— 保持系统默认的启动时机策略。
 *
 * ## 状态管理
 * 纯展示组件，`@ComponentV2` + 全部 `@Param`（无内部状态）⇒ 不会引入任何 V1 装饰器。
 *
 * ⚠️ 2026-10-15 两条**编译期**教训（写错编译不过，已实测）：
 * 1. `text` 参数必须是 `string | Resource` —— 调用点的歌曲标题字段本来就是 `string | Resource`
 *    （如 `PlaylistDetailSongListSection` / `HomeSongListSection`），收窄成 `string` 会报
 *    `Type 'string | Resource' is not assignable to type 'string'`。
 * 2. **不要把属性链放进 `@Builder` 再在 `build()` 里挂 `.width()`** —— `@Builder` 调用返回 `void`，
 *    会报 `Property 'width' does not exist on type 'void'`。所以下面两个分支各自写完整属性链
 *    （这点重复是**故意的**，换 `@Extend` 就不能用 `this`，反而更绕）。
 */
@ComponentV2
export struct SongTitleMarquee {
  /** 歌名文本（列表数据里本来就是 `string | Resource`，所以这里也给联合类型）。 */
  @Param text: string | Resource = '';
  /** 字号：与调用点原本的 `fontSize` 完全一致（`fp` 或 `sys.float.*` 资源都支持）。 */
  @Param titleFontSize: string | number | Resource = $r('sys.float.Body_M');
  /** 字色：与调用点原本的 `fontColor` 完全一致。 */
  @Param titleFontColor: ResourceColor = $r('sys.color.font_primary');
  /** 字重：与调用点原本的 `fontWeight` 完全一致。 */
  @Param titleFontWeight: number | FontWeight = FontWeight.Medium;
  /**
   * 滚动步长（vp/帧）。SDK 默认 6，这里取 4（略慢、更好读）。
   * 官方注明「step 大于文本宽度时取默认值」，所以任何取值都不会把滚动卡死。
   */
  @Param marqueeStep: number = 4;
  /** 循环次数，**小于等于 0 = 无限循环**（SDK 原文："infinite loop if it is less than or equal to zero"）。 */
  @Param marqueeLoop: number = -1;
  /** 每一轮之间的等待时间（ms）。 */
  @Param marqueeDelay: number = 1000;
  /** 是否从头部开始滚（false = 从尾部往回）。 */
  @Param marqueeFromStart: boolean = true;
  /** 是否首尾淡出（列表行有底色，淡出会显得脏 ⇒ 默认关）。 */
  @Param marqueeFadeout: boolean = false;
  /**
   * 宽度约束方式。跑马灯**只在"文本宽 > 组件宽"时滚**，所以宽度必须被约束住，两种父容器要两套写法：
   * - `true`（默认，**父容器是 Column/Stack** 时用）：`.width('100%')` —— 占满父容器**交叉轴**宽度；
   * - `false`（**父容器是 Row** 时用）：`.layoutWeight(1)` —— 占主轴**剩余**宽度。
   * ⚠️ 不能在 Row 里用 `width('100%')`（会挤掉右侧的"更多"按钮），
   *    也不能在 Column 里用 `layoutWeight(1)`（那是**竖直**方向分配，语义错位）。
   */
  @Param fillByWidth: boolean = true;

  build() {
    if (this.fillByWidth) {
      // 父容器是 Column/Stack：交叉轴占满
      Text(this.text)
        .fontSize(this.titleFontSize)
        .fontColor(this.titleFontColor)
        .fontWeight(this.titleFontWeight)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .marqueeOptions({
          start: true,
          fromStart: this.marqueeFromStart,
          step: this.marqueeStep,
          loop: this.marqueeLoop,
          delay: this.marqueeDelay,
          fadeout: this.marqueeFadeout,
          marqueeStartPolicy: MarqueeStartPolicy.DEFAULT
        })
        .width('100%')
    } else {
      // 父容器是 Row：主轴吃剩余空间（右侧还有"更多"按钮之类）
      Text(this.text)
        .fontSize(this.titleFontSize)
        .fontColor(this.titleFontColor)
        .fontWeight(this.titleFontWeight)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .marqueeOptions({
          start: true,
          fromStart: this.marqueeFromStart,
          step: this.marqueeStep,
          loop: this.marqueeLoop,
          delay: this.marqueeDelay,
          fadeout: this.marqueeFadeout,
          marqueeStartPolicy: MarqueeStartPolicy.DEFAULT
        })
        .layoutWeight(1)
    }
  }
}
