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

import { TitleBarConstants } from '../constants/Constants';
import { WindowUtil } from './WindowUtil';

/**
 * 页面顶部让位换算 —— 把「内容在本页盒子里该让多少」交给**实测盒顶**决定。
 *
 * ## 为什么需要它（把上一轮"多让/少让一个状态栏"的死结拆开）
 *
 * HDS 标题栏的位置和页面内容的位置是**两套**口径，而且都依赖同一个未知量：
 * **页盒（NavDestination 的内容盒）在窗口里的 y**。
 *
 *   · HDS 标题栏：`avoidLayoutSafeArea: true` 时它自己会按状态栏高度"退回状态栏下方"，
 *     即标题栏顶 = `盒顶 + 状态栏高`；`false` 时贴盒顶（= 沉浸、可延伸进状态栏）。
 *     参考工程 lxmusic-harmony（真机可用）对它开的注释就是
 *     「标题栏默认是沉浸的（与内容层叠、可延伸进状态栏），所以这里给它开 avoidLayoutSafeArea，
 *      让返回键与标题自己退到状态栏下方；内容层再按『标题栏高度 + 状态栏高度』让位」。
 *   · 内容层：让位量是**相对盒顶**的，所以 `盒顶 = 0` 时要让 `状态栏 + 56`（我们两轮都按这个写），
 *     而 `盒顶 = 状态栏`（框架把页面盒子限制在安全区内）时只该让 `56`。
 *
 * 两种盒顶都可能出现（取决于框架/组件链是否真的把安全区顶掉了），**而我们没法在编译期知道**：
 * 上一轮按"盒顶 = 0"写，用户装机后标题/内容仍然整体下移一个状态栏 —— 说明那台机器上盒顶不是 0。
 * 所以这里改成**运行时量一次盒顶**（页根 `onAreaChange` 的 `globalPosition.y`，窗口坐标 vp），
 * 由它推两个量：
 *
 *   · {@link contentOffsetVp}：`内容顶 - 盒顶`，保证内容**永远**落在窗口的
 *     `状态栏 + 56` 那条线上（盒顶 0 → 94；盒顶 38 → 56）；
 *   · {@link avoidLayoutSafeArea}：盒顶已经贴屏幕顶（0）时让 HDS 标题栏自己退回状态栏下方；
 *     盒顶本身就在状态栏下沿（38）时**不能**再让它退，否则标题栏会掉到 `38 + 38`（用户报的「标题下移」）。
 *
 * 量不到之前（`boxTopVp` 默认 0）行为与"盒顶 = 0"完全一致 ⇒ 老机器上的表现不变，不会回退。
 */
export class PageTopInsetHelper {
  /** HDS 标题栏内容行高（vp）。 */
  public static readonly TITLE_BAR_HEIGHT_VP: number = TitleBarConstants.ROW_HEIGHT_VP;

  /**
   * 内容顶**从窗口顶算起**的目标位置（vp）= 状态栏高 + HDS 标题栏高。
   * @param util 可选的 {@link WindowUtil} 实例；不传用单例。
   * @returns 目标内容顶（vp）。
   */
  public static targetContentTopVp(util?: WindowUtil): number {
    const windowUtil: WindowUtil = util ?? WindowUtil.getInstance();
    // 走 resolve：缓存 → 现向窗口量 → 最后一次好值 → 启动快照（绝不用 0 当"还没有"）
    return windowUtil.resolveStatusBarTopVp() + PageTopInsetHelper.TITLE_BAR_HEIGHT_VP;
  }

  /**
   * 本页盒子内部要给内容留的顶部让位（vp）。
   * @param boxTopVp 页根实测盒顶（窗口坐标 vp，取自 `onAreaChange` 的 `globalPosition.y`）。
   * @param util 可选的 {@link WindowUtil} 实例。
   * @returns 让位高度（vp，≥ 0）。
   */
  public static contentOffsetVp(boxTopVp: number, util?: WindowUtil): number {
    const boxTop: number = boxTopVp > 0 ? boxTopVp : 0;
    return Math.max(0, PageTopInsetHelper.targetContentTopVp(util) - boxTop);
  }

  /**
   * 页盒是否已经贴到屏幕顶（据此决定 HDS 标题栏要不要自己退回状态栏下方）。
   *
   * ⚠️ **真机实测后定稿：恒为 `false`**（2026-10-11 第六轮 22:13 的设置页截图量出来的）。
   *
   *   · 截图里标题栏（返回键 + 「设置」）的竖直中心 ≈ 114vp，而"理想位置"（状态栏 38 + 标题栏 56，
   *     中心 66vp）相差 +48vp；换算成坐标就是 **标题栏占 76..132**，即 `38 + 38`；
   *   · 同一张截图里**内容**（搜索框）落在 ≈ 94vp（我们给的让位 94）—— **内容一直是对的**；
   *   · ⇒ HDS 的标题栏容器**本来就在状态栏下沿**（38 起排），`avoidLayoutSafeArea: true` 让它
   *     **又退了一个状态栏**（76..132）。所以正确值是 `false`：标题栏回到 38..94 ✔。
   *
   * 也就是说「标题下移」既不是内容让位的问题（`contentOffsetVp` 是对的），也不是页盒顶边的问题
   * ——是这一个开关。内容让位公式保持不动。
   * @param boxTopVp 页根实测盒顶（窗口坐标 vp）——本方法已恒返回 false，参数只用于日志诊断。
   * @returns 恒为 `false`。
   */
  public static avoidLayoutSafeArea(boxTopVp: number): boolean {
    // boxTopVp 仅用于诊断日志（`RzdPageTopInset` 里已经打出来了），这里不再把它当判据。
    return boxTopVp < -1000000;
  }
}
