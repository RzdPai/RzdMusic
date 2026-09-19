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
 * AMLL 播放器常量（对应原仓库 packages/core/src/lyric-player/base/consts.ts）
 */
import { AmllOptimizeLyricOptions } from '../model/AmllTypes';

/** 歌词中不雅用语的掩码模式 */
export enum AmllMaskObsceneWordsMode {
  /** 禁用任何不雅用语掩码 */
  Disabled = '',
  /** 完全掩码所有不雅用语 */
  FullMask = 'full-mask',
  /** 保留首尾字符，屏蔽中间字符 */
  PartialMask = 'partial-mask'
}
/** 布局对齐锚点 */
export enum AmllLayoutAlignAnchor {
  Top = 'top',
  Center = 'center',
  Bottom = 'bottom'
}

/** 触发排版布局更新的原因场景 */
export enum AmllLayoutReason {
  /** 正常播放时间推进 */
  PlaybackTick = 'playback-tick',
  /** 容器或窗口尺寸调整 */
  Resize = 'resize',
  /** 用户交互挂起开始（触摸/滚轮触发） */
  InteractionStart = 'interaction-start',
  /** 连续高频滚动（手指触摸滑动或松手后的惯性滑动） */
  ContinuousScroll = 'continuous-scroll',
  /** 离散单步滚动（鼠标滚轮单次滚动） */
  DiscreteScroll = 'discrete-scroll',
  /** 用户交互结束并恢复自动对齐 */
  InteractionEnd = 'interaction-end',
  /** 跳转播放进度 */
  Seek = 'seek',
  /** 重新构建歌词视图 */
  RebuildView = 'rebuild-view',
  /** 视图结构或样式配置改变 */
  ConfigChange = 'config-change'
}

/** 排版执行策略 */
export interface AmllLayoutStrategy {
  /** 是否禁用阶梯交错动画 */
  disableStagger: boolean;
  /** 是否重置间奏圆点动画 */
  resetInterlude: boolean;
  /** 是否瞬移 Y 轴位置而不经过弹簧动画 */
  snapPosY: boolean;
}

/** 排版原因到排版执行策略的映射 */
export function amllLayoutStrategyFor(reason: AmllLayoutReason): AmllLayoutStrategy {
  switch (reason) {
    case AmllLayoutReason.PlaybackTick:
      return { disableStagger: false, resetInterlude: false, snapPosY: false };
    case AmllLayoutReason.InteractionEnd:
      return { disableStagger: false, resetInterlude: false, snapPosY: false };
    case AmllLayoutReason.ContinuousScroll:
      return { disableStagger: true, resetInterlude: true, snapPosY: true };
    case AmllLayoutReason.DiscreteScroll:
      return { disableStagger: true, resetInterlude: true, snapPosY: false };
    case AmllLayoutReason.InteractionStart:
      return { disableStagger: true, resetInterlude: true, snapPosY: false };
    case AmllLayoutReason.Seek:
      return { disableStagger: true, resetInterlude: true, snapPosY: false };
    case AmllLayoutReason.RebuildView:
      return { disableStagger: true, resetInterlude: true, snapPosY: false };
    case AmllLayoutReason.Resize:
      return { disableStagger: true, resetInterlude: false, snapPosY: false };
    case AmllLayoutReason.ConfigChange:
      return { disableStagger: true, resetInterlude: false, snapPosY: false };
    default:
      return { disableStagger: false, resetInterlude: false, snapPosY: false };
  }
}

/** 歌词数据配置选项 */
export interface AmllLyricDataConfig {
  optimizeOptions?: AmllOptimizeLyricOptions;
  maskMode?: AmllMaskObsceneWordsMode;
  maskChar?: string;
}

