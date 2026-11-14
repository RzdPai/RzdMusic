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

/** 要查动态封面的实体类型（决定 Apple Music 的搜索/详情页路径）。 */
export enum MotionCoverKind {
  ARTIST = 'artist',
  ALBUM = 'album',
  PLAYLIST = 'playlist'
}

/**
 * 动态封面（Apple Music 的 motion artwork）解析结果。
 *
 * 规格见 `RzdMusic/docs/apple-motion-cover.md`（甲方给的那份纯 SSR 说明）：
 * 全程只抓 `music.apple.com` 的 HTML，不需要 token / 开发者账号。
 *
 * ⚠️ `videoUrl` 是**明文 HLS 清单**（`..._default.m3u8`，无 `EXT-X-KEY`），
 *    与音频的 FairPlay / Widevine 无关，直接喂 ArkUI `Video` 即可。
 */
export class MotionCover {
  /** HLS 清单地址；空串 = 只解析到海报、没有视频（调用方应视为"没有动态封面"）。 */
  public readonly videoUrl: string;
  /** 首帧海报（Apple 的 `previewFrame`，按 900×900 取），做 `Video.previewUri` 与失败兜底。 */
  public readonly posterUrl: string;
  /** 命中的字典键（`motionArtistSquare1x1` / `motionDetailSquare` / …），只给日志排查用。 */
  public readonly field: string;

  public constructor(videoUrl: string, posterUrl: string, field: string) {
    this.videoUrl = videoUrl;
    this.posterUrl = posterUrl;
    this.field = field;
  }

  /** @returns 是否可用（有视频地址才算）。 */
  public usable(): boolean {
    return this.videoUrl.length > 0;
  }
}
