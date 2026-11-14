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
 * 「动态封面」总开关（其它设置里那一格；**默认开**）。
 *
 * 为什么单独做一份共享状态：开关在设置页，消费方是歌手页 / 专辑页 / 歌单页
 * （`features/setting` 与 `features/playlist` 两个 HAR）。用 `AppStorageV2` 连同一份
 * `@ObservedV2` 状态，翻开关时三页立刻跟着变（不需要重启、也不需要 @Monitor 跨页)。
 * 落盘仍走 `MusicStoreService.getMotionCoverEnabled()/setMotionCoverEnabled()`。
 */
@ObservedV2
export class MotionCoverState {
  /** 是否启用动态封面（歌手 / 专辑 / 歌单页的封面在联网时播放 motion artwork）。 */
  @Trace public enabled: boolean = true;
}
