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
 * 「首页来源平台」刷新总线。
 *
 * 为什么除了 `AppStorageV2` + `@Monitor('homeSourceState.source')` 还要这一条通道：
 * 设置页改平台时，首页那个页面**不在前台**（用户正在「设置」Tab 里），而本项目已经
 * 踩过"常驻 Tab 页只靠 @Monitor 刷新不可靠"（见 features/playlist 的
 * PlaylistRefreshBus 注释）。首页换平台是用户**当场就能看出对不对**的操作，
 * 不能把成败押在一个可能不触发的回调上，所以由写状态的一侧**显式**通知一次。
 *
 * 用法：
 * - 设置页写完 `MusicStoreService.setHomeSource()` + `HomeSourceState.source` 后调
 *   {@link notifyHomeSourceRefresh}；
 * - 首页（features/recommendation 的 RecommendPage）在 `aboutToAppear` 里
 *   {@link registerHomeSourceRefresh}，`aboutToDisappear` 里
 *   {@link unregisterHomeSourceRefresh}。
 *
 * 监听方**必须自己按平台值去重**（@Monitor 与总线可能对同一次修改都触发，
 * 首页那边用 `lastLoadedSource` 挡掉重复加载）。
 */

/** 首页来源平台的刷新回调（无参：监听方自己读当前平台值）。 */
export type HomeSourceRefreshListener = () => void;

/** 当前登记的监听方（首页只有一个，足够的场景不做集合）。 */
let homeSourceListener: HomeSourceRefreshListener | null = null;

/**
 * 登记首页的刷新回调（由首页在自己的 `aboutToAppear` 里调用）。
 *
 * @param listener 收到通知后应重新按当前平台加载首页数据。
 */
export function registerHomeSourceRefresh(listener: HomeSourceRefreshListener): void {
  homeSourceListener = listener;
}

/** 注销首页的刷新回调（首页 `aboutToDisappear` 调用，避免持有已销毁组件）。 */
export function unregisterHomeSourceRefresh(): void {
  homeSourceListener = null;
}

/** 通知首页「来源平台变了」。设置页写完状态后调用。 */
export function notifyHomeSourceRefresh(): void {
  if (homeSourceListener === null) {
    return;
  }
  homeSourceListener();
}
