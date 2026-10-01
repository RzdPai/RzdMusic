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
 * 全屏播放页的 **NavDestination 路由壳**（施工图第 1 步）。
 *
 * 无界 1.2.4 的播放页就是一个被 `nav.pushPath({name, param:{pull:true}}, false)` 推入的
 * `HdsNavDestination`（第二参 animated = false，系统转场关掉）——这里照搬这个形状：
 *
 *   · `hideTitleBar(true)`   —— 播放页没有标题栏，形变容器要从迷你条一路长到整屏；
 *   · 背景**透明**            —— ★ 关键：形变早期可视矩形只有迷你条封面那么大，
 *                               其余区域必须透出下层的首页与迷你条，否则又是
 *                               "一块黑底 + 下方空白"（用户实测过的那两个 bug）；
 *   · 模式保持默认 Stack       —— 播放页永远整屏覆盖，不做分栏。
 *
 * 官方依据：`document/cn/harmonyos-guides/arkts-shared-element-transition` 明确写
 * "为了避免触发 Navigation 的转场动画，在 pushPath() 的时候把动画选项设置成了 false"。
 *
 * ⚠️ 这里**只放壳**：播放页本体、形变几何、克隆层都在原有位置
 *    （`PlaybackPage` / 壳层 `products/…/pages/Index.ets`），不重复实现。
 *    "先量目标节点、再压到起点"的顺序由 `PlaybackPage.playExpandIntro()`（onAppear 起，
 *    带 12×32ms 重试）负责，等价于反编译里 `setupExpandTransition` 的那一刻。
 */

import { guardPlayerBack } from 'musicbasic';
import { HdsNavDestination } from '@kit.UIDesignKit';
import { PlaybackPageCoverContent } from './PlaybackPage';

/**
 * 路由构建函数（`router_map.json` 的 `buildFunction` 指向它）。
 */
@Builder
export function PlaybackPageBuilder(): void {
  HdsNavDestination() {
    PlaybackPageCoverContent()
  }
  .onBackPressed((): boolean => guardPlayerBack('PlaybackPageRoute'))
  .hideTitleBar(true)
  .backgroundColor(Color.Transparent)
  .width('100%')
  .height('100%')
}
