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

import { MusicStoreService } from '../util/MusicStoreService';
import { PlayedSongRecord } from './PlayedSongRecord';

/** Data pushed to the desktop card form. */
export interface MusicCardSnapshot {
  title: string;
  singer: string;
  cover: string;
  playing: boolean;
  lyric: string;
}

/**
 * Bridges playback changes to the desktop card: the entry module registers an
 * updater (which talks to FormKit) and playback code calls {@link notify}.
 */
export class MusicCardBridge {
  private static updater: ((snapshot: MusicCardSnapshot) => void) | undefined = undefined;

  static setUpdater(updater: (snapshot: MusicCardSnapshot) => void): void {
    MusicCardBridge.updater = updater;
  }

  static snapshot(): MusicCardSnapshot {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const record: PlayedSongRecord | undefined = store.getLastRecord();
    return {
      title: record !== undefined && record.name.length > 0 ? record.name : '暂无播放',
      singer: record !== undefined ? record.singer : '',
      cover: record !== undefined ? record.img : '',
      playing: store.getCardPlaying(),
      lyric: store.getCardLyric()
    };
  }

  static notify(): void {
    const updater = MusicCardBridge.updater;
    if (updater === undefined) {
      return;
    }
    updater(MusicCardBridge.snapshot());
  }
}
