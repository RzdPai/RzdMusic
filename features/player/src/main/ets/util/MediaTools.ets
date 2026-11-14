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
 * Moved from common/mediacommon/src/main/ets/utils/MediaTools.ets
 */

import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from 'musicbasic';

const TAG = 'MediaTools';

/** Image helpers: resource/file to PixelMap and time formatting for the player UI. */
export class MediaTools {

  /**
   * Loads raw media bytes for a resource id and decodes them into a PixelMap.
   *
   * @param context UI host context for ResourceManager.
   * @param name Media resource descriptor (uses name.id).
   * @returns Decoded pixel map.
   * @throws When read fails, buffer is empty, or decode fails.
   */
  public static async getPixelMapFromResource(context: common.UIAbilityContext,
      name: resourceManager.Resource): Promise<PixelMap> {
    const resourceId = name.id;
    let fileData: Uint8Array;
    try {
      fileData = await context.resourceManager.getMediaContent(resourceId);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(TAG,
        `read resource failed, resourceId=${resourceId}, code=${err?.code}, message=${err?.message}`);
      throw new Error(
        `read resource failed, resourceId=${resourceId}, code=${String(err?.code)}, message=${err?.message ?? ''}`);
    }
    if (!fileData || fileData.byteLength === 0) {
      Logger.error(TAG, `resource data empty, resourceId=${resourceId}`);
      throw new Error(`resource data empty: ${resourceId}`);
    }
    const imageSource = image.createImageSource(fileData.buffer as ArrayBuffer);
    try {
      return await imageSource.createPixelMap();
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(TAG,
        `decode pixelMap failed, resourceId=${resourceId}, code=${err?.code}, message=${err?.message}`);
      throw new Error(
        `decode pixelMap failed, resourceId=${resourceId}, code=${String(err?.code)}, message=${err?.message ?? ''}`);
    } finally {
      try {
        imageSource.release();
      } catch (error) {
        const err = error as BusinessError;
        Logger.warn(TAG,
          `imageSource.release failed, resourceId=${resourceId}, code=${err?.code}, message=${err?.message}`);
      }
    }
  }

  /**
   * Validates a filesystem path before passing it to ImageKit.
   *
   * @param path Raw path from caller.
   * @returns Trimmed path safe to pass to {@link image.createImageSource}.
   * @throws Error When path is empty or contains illegal characters.
   */
  private static validatePixelMapFilePath(path: string): string {
    if (path === undefined || path === null) {
      throw new Error('getPixelMapFromFile: path is null or undefined');
    }
    const trimmed: string = path.trim();
    if (trimmed.length === 0) {
      throw new Error('getPixelMapFromFile: path is empty');
    }
    if (trimmed.includes('\u0000')) {
      throw new Error('getPixelMapFromFile: path contains NUL character');
    }
    return trimmed;
  }

  /** Pads a time segment to two digits (e.g. 3 -> "03"). */
  private static fill(value: number): string {
    return value.toString().padStart(2, '0');
  }

  /**
   * Formats milliseconds as D:H:M:S style countdown string (omits zero high units).
   *
   * @param ms Duration in milliseconds; falsy yields "00:00".
   */
  public static msToCountdownTime(ms: number): string {
    if (!ms) {
      return '00:00';
    }
    const days = Math.floor(ms / (1000 * 60 * 60 * 24));
    const hours = Math.floor((ms % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((ms % (1000 * 60)) / 1000);
    return `${(days ? MediaTools.fill(days) + ':' : '')}${(hours ? MediaTools.fill(hours) + ':' : '')}
      ${MediaTools.fill(minutes)}:${MediaTools.fill(seconds)} `.trim();
  }
}

