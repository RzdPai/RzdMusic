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


import { PlaylistSongUi } from './PlaylistUiModels';

/**
 * {@link IDataSource} adapter exposing {@link PlaylistSongUi} rows to LazyForEach lists.
 */
export class PlaylistSongUiDataSource implements IDataSource {
  private dataArray: PlaylistSongUi[] = [];
  private listeners: DataChangeListener[] = [];

  public constructor(element: PlaylistSongUi[]) {
    for (let index = 0; index < element.length; index++) {
      this.dataArray.push(element[index]);
    }
  }

  public reloadData(items: PlaylistSongUi[]): void {
    this.dataArray = [];
    for (let index = 0; index < items.length; index++) {
      this.dataArray.push(items[index]);
    }
    for (let i = 0; i < this.listeners.length; i++) {
      const listener = this.listeners[i];
      listener.onDataReloaded();
    }
  }

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): PlaylistSongUi {
    return this.dataArray[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }
}
