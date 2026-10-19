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

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'RzdNowPlaying';

/**
 * 「当前正在播放」的小竖条（**5 根**，播放时跳动，暂停时静止）。
 *
 * ## 用户口径（2026-10-19，本文件第 2 版）
 * - ① 当前播放那首歌的**歌名用软件主题色**标出来（调用方负责上色，见各页面行）；
 * - ② 旁边几根小竖条：**播放时动、暂停就停**；
 * - ③ **要 5 根**（原来 3 根，用户明确要求加到 5 根）；
 * - ④ **动画更平滑**：原来用 `setInterval` 直接改高度 = 每 180ms 硬跳一下；
 *   现在每 tick 的目标高度由一条正弦波推出来，再用 `animateTo` 插值过去 ⇒ 是"流"出来的。
 *
 * ## 为什么是正弦波而不是随机数
 * 随机数 + 插值会得到"每根柱子各跳各的"的杂乱感（5 根时尤其明显）。共享相位的
 * 正弦波 + 每根柱子一个相位偏移（`i * PHASE_STEP`）得到的是**一道波扫过去**的观感。
 *
 * ## ⚠️ 为什么**不**用 ForEach 画柱子（踩过的坑）
 * `ForEach` 按 key 复用节点：key 不变时 **itemGenerator 不会重新执行**，
 * 于是"只改高度"这种更新根本画不出来（这正是上一版 3 根柱子在真机上看着像静止的原因）。
 * 这里改成**手工展开 5 根** + 直接读 `this.bars[i]`：V2 的 `@Local` 依赖收集挂在
 * 真实的属性读取上，`this.bars = next` 一整批赋值会让这 5 个 `@Builder` 全部重跑。
 *
 * ## 省电/省帧
 * - `playing=false` ⇒ 立刻 `clearInterval` 并把高度复位成静止态（**真的停**，不占 CPU）；
 * - 组件销毁（`LazyForEach` 回收行）⇒ `aboutToDisappear` 里清定时器，避免计时器越攒越多。
 *
 * 排查日志关键字：`RzdNowPlaying`（`hilog | grep RzdNowPlaying`，只在起停时各打一条）。
 */
@ComponentV2
export struct NowPlayingIndicator {
  /** 是否正在播放（播放才跳，暂停静止）。 */
  @Param playing: boolean = false;
  /** 柱子上色（一般是 `ThemeState.color`）。 */
  @Param color: ResourceColor = '#FF3B6B';
  /** 整组柱子的高度（vp）；柱子最长 = 这个值。 */
  @Param barHeight: number = 15;
  /** 每根柱子的宽度（vp）。 */
  @Param barWidth: number = 2.5;
  /** 柱子间距（vp）。 */
  @Param barSpace: number = 2;
  /** 当前各柱高度（vp），`@Local` ⇒ 由 `animateTo` 插值。 */
  @Local bars: number[] = [];
  /** 波形相位（0..PHASE_STEPS-1）。 */
  private phase: number = 0;
  /** 定时器句柄；-1 表示没在跑。 */
  private timerId: number = -1;

  /** 柱子根数：**用户要求 5 根**（build 里手工展开 5 根，改这里必须同步改 build）。 */
  private static readonly BAR_COUNT: number = 5;
  /** 一整个波形的 tick 数（越大越慢）。 */
  private static readonly PHASE_STEPS: number = 12;
  /** tick 间隔（ms）。与 `animateTo` 的 duration 取同一量级 ⇒ 曲线首尾相接不顿。 */
  private static readonly TICK_MS: number = 150;
  /** 相邻两根柱子的相位差（以"格"为单位）。 */
  private static readonly PHASE_STEP: number = 0.9;
  /** 最短柱高占比（0 = 贴地）。 */
  private static readonly MIN_RATIO: number = 0.22;

  aboutToAppear(): void {
    this.resetBars();
    if (this.playing) {
      this.start();
    }
  }

  aboutToDisappear(): void {
    this.stop();
  }

  /** 播放状态变化：跟着停 / 起。 */
  @Monitor('playing')
  onPlayingChanged(): void {
    if (this.playing) {
      this.start();
    } else {
      this.stop();
    }
  }

  /** 静止态：一条中间高两边低的斜线（暂停时看着也像"条形图"，不会全平）。 */
  private resetBars(): void {
    const next: number[] = [];
    for (let i: number = 0; i < NowPlayingIndicator.BAR_COUNT; i++) {
      const mod: number = i % 3;
      const ratio: number = mod === 1 ? 0.6 : 0.35;
      next.push(this.barHeight * ratio);
    }
    this.bars = next;
  }

  /** 开始跳动（幂等）。 */
  private start(): void {
    if (this.timerId >= 0) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'start bars=%{public}d playing=%{public}s',
      NowPlayingIndicator.BAR_COUNT, String(this.playing));
    this.tick();
    this.timerId = setInterval((): void => {
      this.tick();
    }, NowPlayingIndicator.TICK_MS);
  }

  /** 停止跳动并复位（幂等）。 */
  private stop(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
      hilog.info(DOMAIN, TAG, 'stop bars=%{public}d', NowPlayingIndicator.BAR_COUNT);
    }
    this.phase = 0;
    this.resetBars();
  }

  /**
   * 推进一格相位，并用 `animateTo` 把高度插值过去。
   *
   * 用 `animateTo` 而不是 `animation()` 属性：这里的目标值是**每 tick 变一次的数组**，
   * `animation()` 挂在属性上要对 5 根柱子各写一条链；`animateTo` 一次包住整批赋值。
   */
  private tick(): void {
    this.phase = (this.phase + 1) % NowPlayingIndicator.PHASE_STEPS;
    const next: number[] = [];
    for (let i: number = 0; i < NowPlayingIndicator.BAR_COUNT; i++) {
      const rad: number =
        (this.phase / NowPlayingIndicator.PHASE_STEPS + i * NowPlayingIndicator.PHASE_STEP) * Math.PI * 2;
      // sin ∈ [-1,1] → [MIN_RATIO,1]
      const ratio: number = NowPlayingIndicator.MIN_RATIO
        + (Math.sin(rad) + 1) / 2 * (1 - NowPlayingIndicator.MIN_RATIO);
      next.push(this.barHeight * ratio);
    }
    this.getUIContext().animateTo({
      duration: NowPlayingIndicator.TICK_MS,
      curve: Curve.EaseInOut
    }, (): void => {
      this.bars = next;
    });
  }

  /** 单根柱子（`@Builder` + 直接读 `this.bars[i]` ⇒ V2 会跟着重跑）。 */
  @Builder
  private Bar(index: number) {
    Column()
      .width(this.barWidth)
      .height(this.bars[index])
      .borderRadius(this.barWidth / 2)
      .backgroundColor(this.color)
  }

  build() {
    Row({ space: this.barSpace }) {
      this.Bar(0)
      this.Bar(1)
      this.Bar(2)
      this.Bar(3)
      this.Bar(4)
    }
    .height(this.barHeight)
    .alignItems(VerticalAlign.Center)
  }
}
