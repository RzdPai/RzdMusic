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

import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * Compares the running device's SDK API level against app constants (e.g. feature gating by API).
 */
export class SdkApiUtil {
  /**
   * @param maxSdkApi Upper bound (inclusive). Compare to {@link SdkConstants} in app code.
   * @returns True when the device API level is at most maxSdkApi.
   */
  public static isSdkApiAtMost(maxSdkApi: number): boolean {
    return deviceInfo.sdkApiVersion <= maxSdkApi;
  }

  /**
   * @param minSdkApi Lower bound (inclusive).
   * @returns True when the device API level is at least minSdkApi.
   */
  public static isSdkApiAtLeast(minSdkApi: number): boolean {
    return deviceInfo.sdkApiVersion >= minSdkApi;
  }
}
