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
 * ★★★ 2026-10-17（用户实测「点击打开播放页时背景是别的歌的颜色 / 对不上」）：
 * **提前预热当前歌曲的 64×64 网格源**。
 *
 * ## 现场
 * 在线歌的网格要 `http` 下载封面 + 解码成 64×64 + `enhanceColors` + `boxBlurRgba(9,3)`
 * （实测 200~2000ms），而「点击打开」的形变只有 350~400ms ⇒ 形变整段**没有真源**，
 * 屏上画的是 `MeshCoverBg.makeFallback()` 的兜底网格（色相来自 `hueOfSeed(title|singer)`，
 * 与封面无关）⇒ 用户看到"背景是别的歌的颜色"。
 *
 * ## 做法
 * 壳层在**当前曲目变化时**（`appState.selectIndex` / `appState.playQueueIds`）以及**点击打开之前**
 * 调本服务；它把结果按 key 存进 {@link MeshWarmState}（`AppStorageV2` 共享），播放页 `onAppear`
 * 直接采用（比对 key，见 `PlaybackPage.adoptWarmMesh()`）。
 *
 * ⚠️ `key` 口径必须与 `PlaybackPage.currentMeshKey()` **逐字一致**（封面 URL 或 `res:<label.id>`），
 *   否则播放页比对不上，缓存等于没用。
 */

import { UIContext } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger, MeshWarmState, SongItem } from 'musicbasic';
import { SRC_EDGE, boxBlurRgba, enhanceColors } from './MeshSource';

const TAG: string = 'RzdMeshWarm';
/** 与 `PlaybackPage.MESH_BLUR_*` 同一口径（`boxBlurRgba(64,64,9,3)`）。 */
const MESH_BLUR_RADIUS: number = 9;
const MESH_BLUR_PASSES: number = 3;
/** 下载超时（ms）：只是预热，慢就别等了。 */
const FETCH_TIMEOUT_MS: number = 15000;

/** 正在预热的 key（模块级去重：同一首同时只跑一次）。 */
let warmInFlightKey: string = '';
/** 上一次成功写进缓存的 key（避免同一首反复解码）。 */
let warmDoneKey: string = '';

/**
 * @returns 曲目对应的网格缓存 key：封面 URL，或 `res:<label.id>`；空串 = 这一拍没有曲目。
 * 口径与 `PlaybackPage.currentMeshKey()` 保持一致。
 */
export function meshWarmKeyOf(song: SongItem | undefined): string {
  if (song === undefined) {
    return '';
  }
  if (song.cover.length > 0) {
    return song.cover;
  }
  return typeof song.label === 'string' ? song.label : `res:${song.label.id}`;
}

/**
 * 预热当前歌曲的网格源（**同步返回、异步干活**，失败只记日志）。
 *
 * @param ui 调用方的 UIContext（只作为"确实在 UI 上下文里"的显式约定，预热本身不碰 UI 线程）
 * @param song 当前曲目（`state.getCurrentSongItem()`）
 */
export function prewarmCurrentSongMesh(ui: UIContext, song: SongItem | undefined): void {
  if (ui === null || ui === undefined) {
    return;
  }
  void runPrewarm(song);
}

async function runPrewarm(song: SongItem | undefined): Promise<void> {
  try {
    const key: string = meshWarmKeyOf(song);
    if (key.length === 0) {
      // ★ 出口日志（逐个出口都打，真机一眼能看出"预热到底跑了没"）：
      //   `hdc shell hilog -x | Select-String 'RzdMeshWarm'`
      Logger.info(TAG, 'RzdMeshWarm skip-empty (no current song)');
      return;
    }
    const warm: MeshWarmState = MeshWarmState.connect();
    if (warmDoneKey === key && warm.key === key && warm.bytes !== undefined) {
      Logger.info(TAG, `RzdMeshWarm skip-done key=${key.substring(0, 48)}`);
      return;
    }
    if (warmInFlightKey === key) {
      Logger.info(TAG, `RzdMeshWarm skip-inflight key=${key.substring(0, 48)}`);
      return;
    }
    // 只有在线封面需要预热：本地文件/资源封面解码是毫秒级，播放页自己的链路够快。
    if (!key.startsWith('http://') && !key.startsWith('https://')) {
      Logger.info(TAG, `RzdMeshWarm skip-local key=${key.substring(0, 48)}`);
      return;
    }
    warmInFlightKey = key;
    Logger.info(TAG, `RzdMeshWarm start key=${key.substring(0, 48)}`);
    const bytes: Uint8Array | undefined = await loadMeshBytes(key);
    if (bytes === undefined) {
      Logger.warn(TAG, `RzdMeshWarm decode-fail key=${key.substring(0, 48)} (见上一条 http-code)`);
      return;
    }
    const tint: string = averageTintOf(bytes);
    warm.put(key, bytes, tint);
    warmDoneKey = key;
    Logger.info(TAG, `RzdMeshWarm done key=${key.substring(0, 48)} tint=${tint} ` +
      `bytes=${bytes.length} v=${warm.version}`);
  } catch (err) {
    const e = err as BusinessError;
    Logger.warn(TAG, `RzdMeshWarm failed code=${e?.code} msg=${e?.message}`);
  } finally {
    warmInFlightKey = '';
  }
}

/**
 * 下载封面 → 解成 64×64 RGBA_8888 → `enhanceColors` → `boxBlurRgba(9,3)`。
 * @returns 处理好的 64×64 RGBA 字节；任一步失败返回 `undefined`。
 */
async function loadMeshBytes(url: string): Promise<Uint8Array | undefined> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await req.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      readTimeout: FETCH_TIMEOUT_MS
    });
    if (resp.responseCode !== 200 || resp.result === undefined) {
      // ★ 出口日志：把 http 码打出来（401/403 = referer/UA 被拒；404 = 封面 URL 过期）
      Logger.warn(TAG, `RzdMeshWarm http-code=${resp.responseCode} ` +
        `hasResult=${resp.result !== undefined ? 1 : 0} url=${url.substring(0, 48)}`);
      return undefined;
    }
    const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
    try {
      const pm: image.PixelMap = await src.createPixelMap({
        desiredSize: { width: SRC_EDGE, height: SRC_EDGE },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
      try {
        const buf: ArrayBuffer = new ArrayBuffer(pm.getPixelBytesNumber());
        pm.readPixelsToBufferSync(buf);
        const u8: Uint8Array = new Uint8Array(buf);
        enhanceColors(u8);
        boxBlurRgba(u8, SRC_EDGE, SRC_EDGE, MESH_BLUR_RADIUS, MESH_BLUR_PASSES);
        return u8;
      } finally {
        pm.release();
      }
    } finally {
      src.release();
    }
  } finally {
    req.destroy();
  }
}

/**
 * @returns 整张网格的**平均色**（`#RRGGBB`），给 `MeshCoverBg.fallbackColor` 当兜底色相用。
 */
function averageTintOf(u8: Uint8Array): string {
  let sr: number = 0;
  let sg: number = 0;
  let sb: number = 0;
  let n: number = 0;
  for (let i = 0; i + 3 < u8.length; i += 4) {
    sr += u8[i];
    sg += u8[i + 1];
    sb += u8[i + 2];
    n++;
  }
  if (n === 0) {
    return '';
  }
  return formatHex(Math.round(sr / n), Math.round(sg / n), Math.round(sb / n));
}

/** 单个通道 → 两位十六进制（自动夹到 0..255）。 */
function hex2(v: number): string {
  const c: number = v < 0 ? 0 : (v > 255 ? 255 : Math.round(v));
  const s: string = c.toString(16);
  return s.length < 2 ? `0${s}` : s;
}

/** @returns `#RRGGBB`。 */
function formatHex(r: number, g: number, b: number): string {
  return `#${hex2(r)}${hex2(g)}${hex2(b)}`;
}
