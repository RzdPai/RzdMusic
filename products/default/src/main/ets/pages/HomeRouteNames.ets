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
 * 首页 / 搜索页两条路由的名字。
 *
 * 为什么要有这两个名字：一镜到底（`geometryTransition`）要成对，必须**两端都是同一个
 * `Navigation` 的路由页** —— 一个随页面转场离开、另一个同一帧出现。
 * 官方示例见 `transitions-collection` 的
 * `SearchLongTakeTransition/SearchLongTakeTransitionPageOne.ets`（源页，NavDestination）
 * 与 `.../PageTwo.ets`（目标页，NavDestination），
 * 两者都由同一个 `Navigation` 的 `pageInfos` 推入。
 *
 * 本仓首页原来挂在 `HdsNavigation` 的**导航栏内容区**（HdsTabs 的 TabContent），
 * push 路由时它不会消失，两端永远配不成一对 —— 这就是"一镜到底一直没动画"的结构性原因。
 * ⇒ 首页 Tab 里再放一个内层 `Navigation`，首页与搜索页都作为它的路由页。
 */
export const HOME_ROUTE_NAME: string = 'RzdHomeRoute';

export const SEARCH_ROUTE_NAME: string = 'RzdHomeSearchRoute';
