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

/*
 * 「我的」这一族页面共用的小件（对应参考工程 `entry/src/main/ets/ui/Widgets.ets` 里的 `TopFade`）。
 *
 * 为什么单开一个文件（而不是放在 `MinePage.ets` 里 export）：
 * `MinePage` 要推 `RecordListPage`（要从它那儿拿 `RecordListRouteParam`），如果 `RecordListPage`
 * 反过来再从 `MinePage` 拿这个渐隐件，两个文件就**互相 import** 了。放在这里两边单向引用，
 * 顺带保证渐隐蒙版**只有一份实现**（两份必然发散）。
 *
 * ⚠️ 两个渐变色是**同名双值 token**（`resources/base/element/color.json` 与
 *    `resources/dark/element/color.json` 各一份，终色是同色 alpha 0 的孪生）：
 *    `linearGradient` 的端点不能对资源色算 alpha，直接拿 `Color.Transparent` 当终点会在
 *    浅色底上"穿过黑色"（中途发暗）。起点色必须与**真实页面底色**一致 —— 本族的页面底色
 *    统一是 `app.color.background_secondary`（base `#F1F3F5` = `mine_top_fade` 的不透明值，
 *    dark `#000000` = `mine_top_fade` 的不透明值），所以"蒙版起点 = 页面底色"是**构造上成立**的。
 */

/**
 * 顶栏自绘渐隐蒙版（**照搬**参考工程 `ui/Widgets.ets` 的 `TopFade`）。
 *
 * 从页面底色渐隐到全透明，压在滚动内容之上、HDS 标题栏之下（标题栏是独立图层，
 * 永远在这之上）：内容越靠近顶部越淡，标题「我的 / 最近播放 / 我的收藏」始终清晰。
 *
 * 铺满宽度、**不拦触摸**（`HitTestMode.Transparent`）—— 它只是一层视觉遮罩，
 * 不能影响滚动与点击。
 *
 * ⚠️ 属性名不能叫 `height`（与组件基类自带的同名属性冲突，编译报 not assignable），
 *    所以照搬参考的 `fadeHeight`。
 */
@ComponentV2
export struct MineTopFade {
  /** 蒙版高度（vp）：调用方按「状态栏 + 标题栏 + 一点余量」给。 */
  @Param fadeHeight: number = 120;

  build() {
    Column()
      .width('100%')
      .height(this.fadeHeight)
      .linearGradient({
        // Bottom = 从上往下：0.0 落在顶边（底色本身），越往下越透
        direction: GradientDirection.Bottom,
        colors: [[$r('app.color.mine_top_fade'), 0.0], [$r('app.color.mine_top_fade_end'), 1.0]]
      })
      .hitTestBehavior(HitTestMode.Transparent)
  }
}
