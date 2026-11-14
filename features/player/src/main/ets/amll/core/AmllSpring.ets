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

import { amllDerivative } from '../model/AmllMath';

/** 弹簧参数（对应原仓库 packages/core/src/utils/spring.ts） */
export interface AmllSpringParams {
  /** 质量 = 1.0 */
  mass: number;
  /** 阻尼 = 10.0 */
  damping: number;
  /** 刚度 = 100.0 */
  stiffness: number;
  /** 软弹簧 */
  soft: boolean;
}

/** 队列化的弹簧参数（含生效延迟） */
interface AmllQueuedParams {
  mass?: number;
  damping?: number;
  stiffness?: number;
  soft?: boolean;
  time: number;
}

/** 队列化的目标位置（含生效延迟） */
interface AmllQueuedPosition {
  position: number;
  time: number;
}

/** 合并两个部分弹簧参数 */
export function amllMergeSpringParams(
  a: Partial<AmllSpringParams>,
  b: Partial<AmllSpringParams>
): Partial<AmllSpringParams> {
  const result: Partial<AmllSpringParams> = {};
  if (a.mass !== undefined) {
    result.mass = a.mass;
  }
  if (a.damping !== undefined) {
    result.damping = a.damping;
  }
  if (a.stiffness !== undefined) {
    result.stiffness = a.stiffness;
  }
  if (a.soft !== undefined) {
    result.soft = a.soft;
  }
  if (b.mass !== undefined) {
    result.mass = b.mass;
  }
  if (b.damping !== undefined) {
    result.damping = b.damping;
  }
  if (b.stiffness !== undefined) {
    result.stiffness = b.stiffness;
  }
  if (b.soft !== undefined) {
    result.soft = b.soft;
  }
  return result;
}

type Seconds = number;

/**
 * 物理弹簧（忠实移植 AMLL 的 Spring 实现，含队列参数/队列位置延迟逻辑）
 */
export class AmllSpring {
  private currentPosition: number = 0;
  private targetPosition: number = 0;
  private currentTime: number = 0;
  private params: Partial<AmllSpringParams> = {};
  private currentSolver: (t: Seconds) => number;
  private getV: (t: Seconds) => number;
  private getV2: (t: Seconds) => number;
  private queueParams: AmllQueuedParams | undefined = undefined;
  private queuePosition: AmllQueuedPosition | undefined = undefined;

  constructor(currentPosition: number = 0) {
    this.targetPosition = currentPosition;
    this.currentPosition = this.targetPosition;
    this.currentSolver = (): number => this.targetPosition;
    this.getV = (): number => 0;
    this.getV2 = (): number => 0;
  }

  private resetSolver(): void {
    const curV: number = this.getV(this.currentTime);
    this.currentTime = 0;
    this.currentSolver = amllSolveSpring(this.currentPosition, curV, this.targetPosition, 0, this.params);
    this.getV = amllDerivative(this.currentSolver);
    this.getV2 = amllDerivative(this.getV);
  }

  arrived(): boolean {
    return (
      Math.abs(this.targetPosition - this.currentPosition) < 0.01 &&
      Math.abs(this.getV(this.currentTime)) < 0.01 &&
      Math.abs(this.getV2(this.currentTime)) < 0.01 &&
      this.queueParams === undefined &&
      this.queuePosition === undefined
    );
  }

  setPosition(targetPosition: number): void {
    this.targetPosition = targetPosition;
    this.currentPosition = targetPosition;
    this.currentSolver = (): number => this.targetPosition;
    this.getV = (): number => 0;
    this.getV2 = (): number => 0;
  }

  /**
   * 触底回弹：保持当前位置不变，速度反向并按系数衰减。
   * 用于行高类有硬地板（0）的弹簧——产生与自由过冲一致的平滑单次回弹，
   * 避免 |x| 镜像带来的折点与多次弹跳。
   */
  reflectAtCurrentPosition(coefficient: number): void {
    const curV = this.getV(this.currentTime);
    this.currentTime = 0;
    this.currentSolver = amllSolveSpring(
      this.currentPosition,
      -curV * coefficient,
      this.targetPosition,
      0,
      this.params
    );
    this.getV = amllDerivative(this.currentSolver);
    this.getV2 = amllDerivative(this.getV);
  }

  update(delta: number = 0): void {
    this.currentTime += delta;
    this.currentPosition = this.currentSolver(this.currentTime);
    if (this.queueParams !== undefined) {
      this.queueParams.time -= delta;
      if (this.queueParams.time <= 0) {
        this.applyQueuedParams(this.queueParams);
        this.queueParams = undefined;
      }
    }
    if (this.queuePosition !== undefined) {
      this.queuePosition.time -= delta;
      if (this.queuePosition.time <= 0) {
        const pos = this.queuePosition.position;
        this.queuePosition = undefined;
        this.setTargetPosition(pos);
      }
    }
    if (this.arrived()) {
      this.setPosition(this.targetPosition);
    }
  }

  private applyQueuedParams(params: AmllQueuedParams): void {
    const p: Partial<AmllSpringParams> = {};
    if (params.mass !== undefined) {
      p.mass = params.mass;
    }
    if (params.damping !== undefined) {
      p.damping = params.damping;
    }
    if (params.stiffness !== undefined) {
      p.stiffness = params.stiffness;
    }
    if (params.soft !== undefined) {
      p.soft = params.soft;
    }
    this.updateParams(p);
  }

  updateParams(params: Partial<AmllSpringParams>, delay: number = 0): void {
    if (delay > 0) {
      const q: AmllQueuedParams = { time: delay };
      if (params.mass !== undefined) {
        q.mass = params.mass;
      }
      if (params.damping !== undefined) {
        q.damping = params.damping;
      }
      if (params.stiffness !== undefined) {
        q.stiffness = params.stiffness;
      }
      if (params.soft !== undefined) {
        q.soft = params.soft;
      }
      this.queueParams = q;
    } else {
      this.queuePosition = undefined;
      this.params = amllMergeSpringParams(this.params, params);
      this.resetSolver();
    }
  }

  setTargetPosition(targetPosition: number, delay: number = 0): void {
    if (delay <= 0 && Math.abs(this.targetPosition - targetPosition) < 0.001) {
      this.queuePosition = undefined;
      return;
    }
    if (delay > 0) {
      const q: AmllQueuedPosition = {
        position: targetPosition,
        time: delay
      };
      this.queuePosition = q;
    } else {
      this.queuePosition = undefined;
      this.targetPosition = targetPosition;
      this.resetSolver();
    }
  }

  getCurrentPosition(): number {
    return this.currentPosition;
  }

  /** 当前目标位置（用于判断目标是否变化，避免重复设置队列） */
  getTargetPosition(): number {
    return this.targetPosition;
  }

  /** 当前速度（用于触底反弹时判断运动方向，避免每帧重复反射） */
  getCurrentVelocity(): number {
    return this.getV(this.currentTime);
  }
}

/** 解阻尼弹簧（对应原仓库 solveSpring） */
function amllSolveSpring(
  from: number,
  velocity: number,
  to: number,
  delay: Seconds = 0,
  params?: Partial<AmllSpringParams>
): (t: Seconds) => number {
  const soft: boolean = params?.soft ?? false;
  const stiffness: number = params?.stiffness ?? 100;
  const damping: number = params?.damping ?? 10;
  const mass: number = params?.mass ?? 1;
  const delta: number = to - from;
  if (soft || 1.0 <= damping / (2.0 * Math.sqrt(stiffness * mass))) {
    const angularFrequency: number = -Math.sqrt(stiffness / mass);
    const leftover: number = -angularFrequency * delta - velocity;
    return (t: Seconds): number => {
      const tt: number = t - delay;
      if (tt < 0) {
        return from;
      }
      return to - (delta + tt * leftover) * Math.pow(Math.E, tt * angularFrequency);
    };
  }
  const dampingFrequency: number = Math.sqrt(4.0 * mass * stiffness - damping ** 2.0);
  const leftover: number = (damping * delta - 2.0 * mass * velocity) / dampingFrequency;
  const dfm: number = (0.5 * dampingFrequency) / mass;
  const dm: number = -(0.5 * damping) / mass;
  return (t: Seconds): number => {
    const tt: number = t - delay;
    if (tt < 0) {
      return from;
    }
    return (
      to -
      (Math.cos(tt * dfm) * delta + Math.sin(tt * dfm) * leftover) *
      Math.pow(Math.E, tt * dm)
    );
  };
}

// 缓慢模式参数，适用于 Seek 状态、间奏状态、首尾边界等场景（对应 base/spring.ts）
const SLOW_STIFFNESS: number = 90;
const SLOW_DAMPING: number = 15;

const MIN_INTERVAL: number = 100;
const MAX_INTERVAL: number = 800;
const MIN_STIFFNESS: number = 170;
const MAX_STIFFNESS: number = 220;
const DAMPING_MULTIPLIER: number = 2.2;
const INTERVAL_EXPONENT: number = 0.2;

/**
 * 获取歌词行纵向滚动的弹簧物理参数（忠实移植 AMLL 的 getPosYSpringPolicy）
 */
export function amllGetPosYSpringPolicy(
  isSeeking: boolean,
  isInterludeActive: boolean,
  intervalMs?: number
): Partial<AmllSpringParams> {
  if (isSeeking || isInterludeActive || intervalMs === undefined) {
    return {
      stiffness: SLOW_STIFFNESS,
      damping: SLOW_DAMPING
    };
  }
  const clampedInterval: number = Math.min(Math.max(intervalMs, MIN_INTERVAL), MAX_INTERVAL);
  let ratio: number = 1 - (clampedInterval - MIN_INTERVAL) / (MAX_INTERVAL - MIN_INTERVAL);
  ratio = ratio ** INTERVAL_EXPONENT;
  const targetStiffness: number = MIN_STIFFNESS + ratio * (MAX_STIFFNESS - MIN_STIFFNESS);
  const targetDamping: number = Math.sqrt(targetStiffness) * DAMPING_MULTIPLIER;
  return {
    stiffness: targetStiffness,
    damping: targetDamping
  };
}
