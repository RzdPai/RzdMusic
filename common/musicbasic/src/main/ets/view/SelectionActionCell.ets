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
 * 多选底部操作条里的**一格**（图标 + 小字）。
 *
 * 用户 2026-10-19 的参考图：底部一条悬浮胶囊，里面是「删除 / 添加至歌单 / 取消收藏 / 取消」
 * 几格，每格 = 图标 + 小字。抽成组件是为了：
 * 1. 本地音乐页、播放历史页、收藏页三处多选条**长得一模一样**（用户明确要求"沿用新样式"）；
 * 2. 光感只有一处出处（材质背板在父容器上，见 `util/BarMaterial.ets`）。
 *
 * ⚠️ 2026-10-20（用户：「接入的是沉浸光感，不是发光，把这堆发光删了」）：
 *   这里原来挂 `hdsEffect` 的**点光**（按下一格发亮）+ 一个 `@Local pressed` 状态，**已删除**。
 *   不要再往这一格上加任何 `.visualEffect(...)`。
 */
@ComponentV2
export struct SelectionActionCell {
  /** 图标（系统符号）。 */
  @Param icon: Resource = $r('sys.symbol.xmark');
  /** 小字（如「删除(3)」）。 */
  @Param label: string = '';
  /** 图标与文字的着色（一般删除用主题色、其余用 `font_primary`）。 */
  @Param tint: ResourceColor = $r('sys.color.font_primary');
  /** 点击回调。 */
  @Event onTap: () => void = (): void => {
  };

  build() {
    Column({ space: 4 }) {
      SymbolGlyph(this.icon)
        .fontSize(20)
        .fontColor([this.tint])
      Text(this.label)
        .fontSize(11)
        .fontColor(this.tint)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick((): void => {
      this.onTap();
    })
  }
}
