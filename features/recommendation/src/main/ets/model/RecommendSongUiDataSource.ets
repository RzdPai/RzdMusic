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


import { RecommendPrivateSongUi } from './RecommendUiModels';

/**
 * IDataSource implementation for lazy lists (LazyForEach) of RecommendPrivateSongUi rows.
 */
export class RecommendSongUiDataSource implements IDataSource {
  private dataArray: RecommendPrivateSongUi[] = [];
  private listeners: DataChangeListener[] = [];

  /**
   * Copies the given songs into an internal array for lazy list rendering.
   *
   * @param element - Initial private song rows.
   */
  public constructor(element: RecommendPrivateSongUi[]) {
    for (let index = 0; index < element.length; index++) {
      this.dataArray.push(element[index]);
    }
  }

  /**
   * @returns Number of items in the data source.
   */
  public totalCount(): number {
    return this.dataArray.length;
  }

  /**
   * @param index - Zero-based index into the backing array.
   * @returns Song UI model at the given index.
   */
  public getData(index: number): RecommendPrivateSongUi {
    return this.dataArray[index];
  }

  /**
   * Registers a data change listener if not already present.
   *
   * @param listener - Listener to notify on data changes.
   */
  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  /**
   * Unregisters a previously registered data change listener.
   *
   * @param listener - Listener instance to remove.
   */
  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }
}
