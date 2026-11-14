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


import { SongItem } from './SongData';
import { Logger } from '../util/Logger';

/**
 * In-memory {@link IDataSource} for LazyForEach backed by a mutable {@link SongItem} array.
 */
export class SongDataSource implements IDataSource {
  /** Backing list of song items. */
  private dataArray: SongItem[] = [];
  /** Registered ArkUI data change listeners. */
  private listeners: DataChangeListener[] = [];

  /**
   * Copies the given array into this data source.
   * @param element Initial song list.
   */
  public constructor(element: SongItem[]) {
    for (let index = 0; index < element.length; index++) {
      this.dataArray.push(element[index]);
    }
  }

  /**
   * @returns Number of items in the backing array.
   */
  public totalCount(): number {
    return this.dataArray.length;
  }

  /**
   * @param index Zero-based index.
   * @returns Song at the index, or a new empty {@link SongItem} if index is out of range.
   */
  public getData(index: number): SongItem {
    const len = this.dataArray.length;
    if (index < 0 || index >= len) {
      Logger.warn('SongDataSource', `getData out of range: index=${index}, length=${len}`);
      return new SongItem();
    }
    return this.dataArray[index];
  }

  /**
   * Inserts a song at the index and notifies listeners of an add.
   * @param index Insert position (clamped to [0, length] so it matches {@link IDataSource} / LazyForEach).
   * @param data Song to insert.
   */
  public addData(index: number, data: SongItem): void {
    if (data === undefined || data === null) {
      Logger.warn('SongDataSource', 'addData ignored: data is null or undefined');
      return;
    }
    const len: number = this.dataArray.length;
    const insertAt: number = Math.max(0, Math.min(index, len));
    if (insertAt !== index) {
      Logger.warn('SongDataSource', `addData index out of range: requested=${index}, length=${len}, using=${insertAt}`);
    }
    this.dataArray.splice(insertAt, 0, data);
    this.notifyDataAdd(insertAt);
  }

  /**
   * Appends a song and notifies listeners of an add at the new tail index.
   * @param data Song to append.
   */
  public pushData(data: SongItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  /**
   * Registers a listener if not already present.
   * @param listener Data change callback implementation.
   */
  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  /**
   * Removes a previously registered listener.
   * @param listener Same instance passed to {@link registerDataChangeListener}.
   */
  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  /**
   * Notifies all listeners that the whole data set was replaced.
   */
  public notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  /**
   * Notifies listeners that one row was inserted.
   * @param index Index of the new row.
   */
  public notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  /**
   * Notifies listeners that one row’s content changed.
   * @param index Index of the changed row.
   */
  public notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  /**
   * Notifies listeners that one row was removed.
   * @param index Index of the removed row.
   */
  public notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }

  /**
   * Notifies listeners that a row moved from one index to another.
   * @param from Source index before the move.
   * @param to Target index after the move.
   */
  public notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    });
  }
}
