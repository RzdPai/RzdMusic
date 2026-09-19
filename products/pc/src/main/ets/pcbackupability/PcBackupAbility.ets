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

import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { Logger } from 'musicbasic';

/**
 * PC product backup extension: backup/restore lifecycle for the desktop bundle.
 */
export default class PcBackupAbility extends BackupExtensionAbility {
  /** Invoked for backup; logs completion placeholder. */
  async onBackup() {
    Logger.info('PcBackupAbility: onBackup ok');
    await Promise.resolve();
  }

  /**
   * Invoked when restoring backup data on PC.
   * @param bundleVersion Version info from the backup framework.
   */
  async onRestore(bundleVersion: BundleVersion) {
    Logger.info(`PcBackupAbility: onRestore ok ${JSON.stringify(bundleVersion)}`);
    await Promise.resolve();
  }
}
