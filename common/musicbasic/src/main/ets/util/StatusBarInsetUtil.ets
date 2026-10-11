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


import { WindowUtil } from './WindowUtil';

/**
 * Reads status-bar top inset in vp from {@link WindowUtil}’s shared {@link WindowInfo}.
 *
 * ⚠️ 走 `resolveStatusBarTopVp()` 而不是直接读 `mainWindowInfo.statusBarTopVp`：后者在避让区
 * 一时给不出来时（avoidArea 还没上报 / UIContext 还没 cache / 窗口进出 layout-full-screen）
 * 会是 **0**，而它是**布局输入**（页顶让位 = 状态栏 + HDS 标题栏高度）。0 会让整页内容上移
 * 一个状态栏的高度、顶进标题栏，表现为「标题下移 / 内容压住标题」。
 * resolve 版本保证「缓存有就用缓存 → 现向窗口量 → 最后一次量到的好值 → 启动快照」，
 * 且**只读**（不在 build 期间写状态），可以安全地在 `build()` 里调用。
 * @param util Optional util instance; uses singleton when omitted.
 * @returns Status bar top padding in vp.
 */
export function getStatusBarTopVpFromWindowUtil(util?: WindowUtil): number {
  const windowUtil = util ?? WindowUtil.getInstance();
  return windowUtil.resolveStatusBarTopVp();
}

/**
 * Reads home-indicator / nav-bar bottom inset in vp; resolution rules match
 * {@link getStatusBarTopVpFromWindowUtil}.
 * @param util Optional util instance; uses singleton when omitted.
 * @returns Nav bar bottom padding in vp.
 */
export function getNavigationBarBottomVpFromWindowUtil(util?: WindowUtil): number {
  const windowUtil = util ?? WindowUtil.getInstance();
  return windowUtil.resolveNavigationBarBottomVp();
}
