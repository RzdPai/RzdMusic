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
 * 播放页流光背景取自封面动态取色的两个颜色。
 *
 * HDS 的 `UV_BACKGROUND_FLOW_LIGHT` 只吃一组 `colorSource`（流光本体）+ 可选
 * `colorTarget`（流光扫过后的底色）。这里放的就是这一对颜色，由
 * `PlaybackPage` 在每次换歌、取色完成后写入；换歌时先用封面主色兜底、
 * 取色成功后再覆盖，避免换歌瞬间流光闪一下默认色。
 *
 * 只在 AppStorageV2 里共享给播放页内部用，不做持久化（颜色本来就跟歌走）。
 */
@ObservedV2
export class CoverTintState {
  /** 流光本体的颜色，通常取封面占比最大的颜色。 */
  @Trace public sourceColor: string = '#4A4A52';
  /** 流光扫过后的底色，通常取同一色的深色版本。 */
  @Trace public targetColor: string = '#141416';
  /** 递增令牌：颜色每次更新都自增，播放页据此决定是否重设着色器参数。 */
  @Trace public version: number = 0;
}
