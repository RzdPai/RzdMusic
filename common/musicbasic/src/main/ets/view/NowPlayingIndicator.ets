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
 * 「当前正在播放」的小竖条（三根，播放时跳动，暂停时静止）。
 *
 * 用户 2026-10-19：歌单页 / 收藏页 / 历史页要
 *   ① 当前播放那首歌的**歌名用软件主题色**（用户可自定义颜色）标出来；
 *   ② 旁边几根小竖条，**播放时动态跳动、暂停就停**。
 *
 * 实现要点：
 *   · 三根柱子的高度由 `setInterval` 驱动（抖动幅度小、周期 ~180ms），`playing=false` 时清掉定时器
 *     并把高度复位成静止态 —— 这样"暂停就停"是**真的停**，不占 CPU，也不会和列表滚动抢帧。
 *   · 颜色由调用方传（`color`），统一用 `ThemeState.color`，跟用户自定义强调色走。
 *   · 组件销毁（行被回收）时务必清定时器，否则 LazyForEach 反复创建会累积计时器。
 */
@ComponentV2
export struct NowPlayingIndicator {
  /** 是否正在播放（播放才跳，暂停静止）。 */
  @Param playing: boolean = false;
  /** 柱子上色（一般是 `ThemeState.color`）。 */
  @Param color: ResourceColor = '#FF3B6B';
  /** 柱子高度（vp），三根。 */
  @Local bars: number[] = [4, 10, 6];
  /** 定时器句柄；-1 表示没在跑。 */
  private timerId: number = -1;

  aboutToAppear(): void {
    if (this.playing) {
      this.start();
    }
  }

  aboutToDisappear(): void {
    this.stop();
  }

  /** 播放状态变化：跟手停/起。 */
  @Monitor('playing')
  onPlayingChanged(): void {
    if (this.playing) {
      this.start();
    } else {
      this.stop();
    }
  }

  /** 开始跳动（幂等）。 */
  private start(): void {
    if (this.timerId >= 0) {
      return;
    }
    this.timerId = setInterval((): void => {
      this.bars = [
        4 + Math.floor(Math.random() * 9),
        4 + Math.floor(Math.random() * 9),
        4 + Math.floor(Math.random() * 9)
      ];
    }, 180);
  }

  /** 停止跳动并复位（幂等）。 */
  private stop(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.bars = [4, 10, 6];
  }

  build() {
    Row({ space: 2 }) {
      ForEach([0, 1, 2], (i: number) => {
        Column()
          .width(2.5)
          .height(this.bars[i])
          .borderRadius(1.5)
          .backgroundColor(this.color)
      }, (i: number) => 'bar_' + i)
    }
    .height(14)
    .alignItems(VerticalAlign.Bottom)
  }
}
