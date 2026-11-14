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

import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys } from '../constants/Constants';

/**
 * ★★★ 2026-10-17（用户实测「点击打开播放页时背景是别的歌的颜色 / 对不上」）：
 * **当前歌曲 64×64 网格的预热缓存**（跨页面共享，`AppStorageV2`）。
 *
 * ## 为什么需要
 * 在线歌的网格源要 `http` 下载封面再解码成 64×64（实测 200~2000ms），而「点击打开」的形变
 * 只有 350~400ms ⇒ 形变整段拿不到真源 ⇒ 屏上是 `MeshCoverBg.makeFallback()` 的兜底网格。
 * ⇒ 壳层在**当前曲目变化时**就先把它算好（见 `features/player/.../util/MeshWarmService`），
 *   播放页 `onAppear` 直接吃缓存，形变一开始就有真源。
 *
 * ## 为什么存 `Uint8Array` 而不是 `PixelMap`
 * `PixelMap` 跨页面持有会在某一侧 `release()` 后变成悬空引用（上一轮就是这么炸的）；
 * 字节数组可以自由 `slice()`，每侧各自 `createPixelMap`。
 *
 * ## ⚠️ 绝不能"挂载那一拍就盲用"
 * `state.getCurrentSongItem()` 在挂载那一拍可能还是**上一首** ⇒ 必须比对 {@link key}；
 * 缓存更新时 `@Trace version` 会加 1，播放页再取一次（此时 key 已经是当前歌）。
 */
@ObservedV2
export class MeshWarmState {
  /** 缓存对应的曲目 key（封面 URL，或 `res:<label.id>`）。 */
  @Trace public key: string = '';
  /** 递增令牌：每次写入都 +1，播放页据此重新尝试采用。 */
  @Trace public version: number = 0;
  /** 取样色（`#RRGGBB`），给 `MeshCoverBg.fallbackColor` 兜底用。 */
  @Trace public tint: string = '';
  /** 64×64 RGBA 字节（已 `enhanceColors` + `boxBlurRgba(9,3)`）。**不做 @Trace**（大数组）。 */
  public bytes: Uint8Array | undefined = undefined;

  /** @returns 字节的**副本**（调用方可以拿去做 `createPixelMap`，不受后续覆盖影响）。 */
  public snapshot(): Uint8Array | undefined {
    const src: Uint8Array | undefined = this.bytes;
    if (src === undefined) {
      return undefined;
    }
    return src.slice();
  }

  /** 写入一份新的预热结果（同时把 `version` 加 1）。 */
  public put(key: string, bytes: Uint8Array, tint: string): void {
    this.key = key;
    this.bytes = bytes.slice();
    this.tint = tint;
    this.version = this.version + 1;
  }

  /** 清空（换失败 / 退出登录之类的场景；同样会把 `version` 加 1 让读者重算）。 */
  public clearWarm(): void {
    this.key = '';
    this.bytes = undefined;
    this.tint = '';
    this.version = this.version + 1;
  }

  public static connect(): MeshWarmState {
    return AppStorageV2.connect(MeshWarmState, AppStorageKeys.MESH_WARM_STATE,
      (): MeshWarmState => new MeshWarmState())!;
  }
}
