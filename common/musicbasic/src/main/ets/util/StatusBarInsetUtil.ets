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
 * @param util Optional util instance; uses singleton when omitted.
 * @returns Status bar top padding in vp.
 */
export function getStatusBarTopVpFromWindowUtil(util?: WindowUtil): number {
  const windowUtil = util ?? WindowUtil.getInstance();
  return windowUtil.mainWindowInfo.statusBarTopVp;
}
