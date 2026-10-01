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
 * 播放页流光背景开关（设置项）。
 *
 * 通过 AppStorageV2 共享：设置页改一下，已经打开的播放页立刻生效，
 * 不需要重新进页面（与 {@link ShowMiniLyricState} 同一套做法）。
 */
@ObservedV2
export class PlaybackFlowLightState {
  /** 是否启用播放页流光背景。 */
  @Trace public enabled: boolean = false;
}
