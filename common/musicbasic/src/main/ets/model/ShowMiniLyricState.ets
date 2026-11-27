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
 * Whether the playback page shows two mini lyric lines below the cover,
 * shared via AppStorageV2 so the player reacts instantly to the setting.
 */
@ObservedV2
export class ShowMiniLyricState {
  /**
   * 旧开关（只表示"小歌词开/关"）。保留它是因为：云端同步、历史设置都还用这个字段。
   * 新代码请读写 {@link mode}。
   */
  @Trace public enabled: boolean = false;
  /**
   * 播放页封面下方**显示什么**（用户 2026-11-27：「播放页显示小歌词改为播放页显示，
   * 三个选项：无内容 / 小歌词 / 平台音质（和点击标题弹出的气泡内容一样）」）。
   *
   * - 0 = 无内容
   * - 1 = 小歌词
   * - 2 = 平台音质（平台 / 音质 / 音源三行，与 `MetaInfoTip` 同源）
   * - **-1 = 未初始化**（老用户）：此时按 `enabled` 推（开 → 1，关 → 0）。
   */
  @Trace public mode: number = -1;

  /** 实际生效的显示模式（把 -1 的老数据折算掉）。 */
  public effectiveMode(): number {
    if (this.mode >= 0) {
      return this.mode;
    }
    return this.enabled ? 1 : 0;
  }
}
