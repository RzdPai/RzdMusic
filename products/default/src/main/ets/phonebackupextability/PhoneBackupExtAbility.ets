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

/** Phone product backup extension entry (stub hooks for backup/restore flows). */
export default class PhoneBackupExtAbility extends BackupExtensionAbility {
  /** Invoked when the system requests a backup of this extension's data. */
  async onBackup() {
    Logger.info('PhoneBackupExtAbility: onBackup ok');
  }

  /** Invoked when restoring from backup; receives source bundle version metadata. */
  async onRestore(bundleVersion: BundleVersion) {
    Logger.info(`PhoneBackupExtAbility: onRestore ok ${JSON.stringify(bundleVersion)}`);
  }
}
