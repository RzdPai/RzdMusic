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
 * 歌单多选（批量操作）共享选择状态。
 *
 * 用 `@Trace` 而不是把选择状态放在行的 `@Param` 里：勾选时只刷新读取它的
 * 勾选圈/操作条节点，不会重建整行，从而避免封面重新加载导致的闪烁。
 * 选择键用 `PlaylistSongUi.selectionKey()`（即 `source_songId`），
 * 因为行模型里的 `id` 多数情况下是行序号，不稳定。
 */
@ObservedV2
export class PlaylistBatchSelectionStore {
  /** 是否处于多选模式。 */
  @Trace public batchMode: boolean = false;
  /** 已选中的业务键（`source_songId`）列表，保持点击顺序。 */
  @Trace public keys: string[] = [];

  /** 清空选择并退出多选模式。 */
  public exit(): void {
    this.batchMode = false;
    this.keys = [];
  }

  /**
   * 判断某个键是否已选中。
   * @param key 行的业务键。
   * @returns True 表示已选中。
   */
  public has(key: string): boolean {
    return this.keys.indexOf(key) >= 0;
  }

  /**
   * 切换某一行（增删后整体替换数组，保证 V2 能观察到变化）。
   * @param key 行的业务键。
   */
  public toggle(key: string): void {
    const idx: number = this.keys.indexOf(key);
    if (idx >= 0) {
      const next: string[] = [...this.keys];
      next.splice(idx, 1);
      this.keys = next;
      return;
    }
    this.keys = [...this.keys, key];
  }
}
