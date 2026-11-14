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


import { AppStorageV2, UIContext } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppStorageKeys } from '../constants/Constants';

/**
 * Shared UIAbility runtime handles (context, UIContext, media service) stored in AppStorageV2.
 */
@ObservedV2
export class AppRuntimeStorage {
  /** UIAbility context for resources and system APIs. */
  @Trace public context: common.UIAbilityContext | undefined = undefined;
  /** Main window UIContext for layout, px/vp, and breakpoints. */
  @Trace public uiContext: UIContext | undefined = undefined;
  /** Opaque reference to the product-layer media or session service. */
  @Trace public mediaServiceRef: object | undefined = undefined;
}

/**
 * Returns the shared {@link AppRuntimeStorage}, creating it on first connect.
 * @returns Connected observable runtime storage instance.
 */
export function getAppRuntime(): AppRuntimeStorage {
  return AppStorageV2.connect(AppRuntimeStorage, AppStorageKeys.APP_RUNTIME, () => new AppRuntimeStorage())!;
}
