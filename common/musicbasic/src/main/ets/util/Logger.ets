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

import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * App-wide log helper backed by hilog; multiple args are joined with " | ".
 * Uses domain 0x0000 and prefix [musichome].
 */
export class Logger {
  /** HiLog domain id for this module. */
  private static domain: number = 0x0000;
  /** Tag name shown in HiLog output. */
  private static prefix: string = '[musichome]';
  /** Format placeholder; payload is one joined line after joining args with " | ". */
  private static formatSingle: string = '%{public}s, %{public}s';

  /**
   * Writes a debug line to hilog; joins all parts with " | ".
   * @param args Text segments to log.
   */
  public static debug(...args: Object[]): void {
    hilog.debug(Logger.domain, Logger.prefix, Logger.formatSingle, Logger.prefix, args.join(' | '));
  }

  /**
   * Writes an info line to hilog; joins all parts with " | ".
   * @param args Text segments to log.
   */
  static info(...args: Object[]): void {
    hilog.info(Logger.domain, Logger.prefix, Logger.formatSingle, Logger.prefix, args.join(' | '));
  }

  /**
   * Writes a warn line to hilog; joins all parts with " | ".
   * @param args Text segments to log.
   */
  public static warn(...args: Object[]): void {
    hilog.warn(Logger.domain, Logger.prefix, Logger.formatSingle, Logger.prefix, args.join(' | '));
  }

  /**
   * Writes an error line to hilog; joins all parts with " | ".
   * @param args Text segments to log.
   */
  public static error(...args: Object[]): void {
    hilog.error(Logger.domain, Logger.prefix, Logger.formatSingle, Logger.prefix, args.join(' | '));
  }
}

export default new Logger();