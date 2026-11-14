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


import { common } from '@kit.AbilityKit';
import { Logger } from './Logger';

const TAG = 'StringResourceUtil';

/**
 * Resolves {@link Resource} string ids to plain text using the UIAbility context.
 */
export class StringResourceUtil {
  /**
   * Returns the string as-is when already plain; otherwise loads sync from resource manager.
   * @param context UIAbility context for resource manager.
   * @param value Plain string or string resource reference.
   * @returns Resolved text, or empty string on failure.
   */
  public static resolve(context: common.UIAbilityContext, value: string | Resource): string {
    if (typeof value === 'string') {
      return value;
    }
    try {
      return context.resourceManager.getStringSync(value.id);
    } catch (error) {
      Logger.error(TAG, `resolve failed: ${(error as Error).message ?? String(error)}`);
      return '';
    }
  }
}
