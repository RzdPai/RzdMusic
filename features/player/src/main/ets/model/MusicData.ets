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
/** Repeat and navigation policy used by MediaService for next/previous. */
enum MusicPlayMode {
  /** Repeat the current track. */
  SINGLE_CYCLE = 0,
  /** Play queue in order with wrap on next at end. */
  ORDER = 1,
  /** Pick a random next index (excluding current when possible). */
  RANDOM = 2
}

/** Mirror of AVPlayer lifecycle and auxiliary states used inside MediaService. */
enum AudioPlayerState {
  /** Player created or reset; no fdSrc yet. */
  IDLE,
  /** AVPlayer initialized callback state. */
  INITIALIZED,
  /** Reserved / transitional load state. */
  LOAD,
  /** prepare() succeeded; duration and seek are valid. */
  PREPARED,
  /** Actively playing audio. */
  PLAY,
  /** Paused with prepared content retained. */
  PAUSE,
  /** stop() completed. */
  STOP,
  /** Error callback received. */
  ERROR,
  /** Natural end of current item reached. */
  COMPLETED,
  /** release() path. */
  RELEASED,
  /** Reserved playback-speed related state (unused in sample). */
  PROGRESS_SPEED,
  /** Reserved time-update marker (unused in sample). */
  TIME_UPDATE,
  /** Volume changed while playing (reserved). */
  VOLUME_CHANGE,
  /** Unrecognized AVPlayer state string. */
  UNKNOWN
}

export { MusicPlayMode, AudioPlayerState };
