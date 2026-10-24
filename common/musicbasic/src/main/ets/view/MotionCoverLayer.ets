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
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageKeys } from '../constants/Constants';
import { MotionCover, MotionCoverKind } from '../model/MotionCover';
import { MotionCoverState } from '../model/MotionCoverState';
import { MotionCoverService } from '../services/MotionCoverService';

/**
 * **动态封面**那一层：盖在页面原有的大封面（静图）**之上**，只在视频真的起播后淡入。
 *
 * 为什么这么设计（而不是"用动态封面替换静图"）：
 * 1. 解析要联网、还要抓两次 HTML（~1.5MB）⇒ 首帧一定先有静图，视频晚到；
 *    ⇒ 静图由宿主继续画，本层只负责"视频来了就盖上去"，**任何一步失败都退回静图**，不会白屏；
 * 2. `Video` 起播前是黑底 ⇒ 本层默认 `opacity(0)`，`onStart` 之后才淡入（260ms）。
 *
 * 硬规矩（对应 ArkUI `Video` 官方文档）：
 * - `.muted(true)` **必须**在起播前生效，否则会抢音频焦点（音乐 App 里这是致命的：
 *   动态封面一出声就把正在播的歌顶掉了）；
 * - 用 `previewUri` 给首帧（Apple 的 `previewFrame` 与第一帧对齐，淡入无跳变）；
 * - `onVisibleAreaChange` 里离屏 `pause()`、回屏 `start()`（多实例会抢解码器）；
 * - `HitTestMode.None`：这层只做装饰，不吃触摸（页面上的按钮在它下面/上面都照常点）。
 *
 * 排查关键字：`RzdMotionCover`（本组件只补 `layer` 一类日志）。
 */
@ComponentV2
export struct MotionCoverLayer {
  /** 实体类型（`artist` / `album` / `playlist`）。 */
  @Param kind: string = 'artist';
  /** 实体名（歌手名 / 专辑名 / 歌单名）。 */
  @Param name: string = '';
  /** 专辑页建议带歌手名（同名专辑靠它挑对）；其余页面留空。 */
  @Param artist: string = '';
  /** 静图封面地址：Apple 海报缺失时拿它当 `previewUri`（首帧不黑屏）。 */
  @Param fallbackPoster: string = '';
  /** 其它设置里的「动态封面」总开关：关掉时整层不渲染，零请求、零解码。 */
  @Local state: MotionCoverState =
    AppStorageV2.connect(MotionCoverState, AppStorageKeys.MOTION_COVER_STATE, () => new MotionCoverState())!;
  @Local cover: MotionCover | undefined = undefined;
  /** 视频准备就绪（此后才允许 `start()`）。 */
  @Local prepared: boolean = false;
  /** 已经真的在播（据此淡入）。 */
  @Local started: boolean = false;
  /** 播放失败 ⇒ 永久退回静图，不再重试（避免每帧报错）。 */
  @Local failed: boolean = false;
  /** 本层是否在可视区域内（离屏要暂停，否则会抢解码器）。 */
  @Local onScreen: boolean = true;
  private controller: VideoController = new VideoController();
  /** 当前查询指纹：异步回来时用它判断"结果是不是还是这一页要的"。 */
  private queryKey: string = '';
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    void this.reload();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.controller.stop();
  }

  @Monitor('kind', 'name', 'artist')
  onQueryChanged(): void {
    void this.reload();
  }

  @Monitor('state.enabled')
  onEnabledChanged(): void {
    void this.reload();
  }

  /** 重新解析（开关关掉/名字为空时立即清空，不发任何请求）。 */
  private async reload(): Promise<void> {
    this.started = false;
    this.prepared = false;
    if (!this.state.enabled || !this.queryable(this.name)) {
      this.cover = undefined;
      this.queryKey = '';
      return;
    }
    const key: string = `${this.kind}|${this.name}|${this.artist}`;
    if (key === this.queryKey && this.cover !== undefined) {
      return;
    }
    this.queryKey = key;
    this.failed = false;
    const resolved: MotionCover | undefined =
      await MotionCoverService.getInstance().resolve(this.kindOf(), this.name, this.artist);
    if (!this.alive || key !== this.queryKey) {
      return;
    }
    this.cover = resolved;
    hilog.info(0, 'RzdMotionCover',
      'layer kind=%{public}s name=%{public}s hit=%{public}d field=%{public}s',
      this.kind, this.name, resolved !== undefined ? 1 : 0, resolved !== undefined ? resolved.field : 'none');
  }

  /**
   * @returns 这个名字值不值得去 Apple Music 搜。
   *
   * 页面在数据回来之前会显示占位名（`歌手` / `专辑` / `歌单`）—— 拿它们去搜
   * 会白拉两次 HTML（~1.5MB）且必然搜不到；单字名字同理（误命中率极高）。
   */
  private queryable(name: string): boolean {
    const trimmed: string = name.trim();
    if (trimmed.length < 2) {
      return false;
    }
    const placeholders: string[] = ['歌手', '专辑', '歌单', '歌曲', '未知', '未知歌手', 'unknown'];
    for (let i = 0; i < placeholders.length; i++) {
      if (trimmed === placeholders[i]) {
        return false;
      }
    }
    return true;
  }

  private kindOf(): MotionCoverKind {
    if (this.kind === 'album') {
      return MotionCoverKind.ALBUM;
    }
    if (this.kind === 'playlist') {
      return MotionCoverKind.PLAYLIST;
    }
    return MotionCoverKind.ARTIST;
  }

  /** 真正可画的条件（开关开 + 有视频 + 没失败）。 */
  private drawable(): boolean {
    return this.state.enabled && !this.failed && this.cover !== undefined && this.cover.videoUrl.length > 0;
  }

  private previewUri(): string {
    const cover: MotionCover | undefined = this.cover;
    if (cover !== undefined && cover.posterUrl.length > 0) {
      return cover.posterUrl;
    }
    return this.fallbackPoster;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.drawable() && this.cover !== undefined) {
        Video({
          src: this.cover.videoUrl,
          previewUri: this.previewUri(),
          controller: this.controller
        })
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          // ⚠️ 静音必须写在 autoPlay 之前：未静音起播会抢音频焦点（把正在播的歌顶掉）
          .muted(true)
          .controls(false)
          .loop(true)
          .autoPlay(true)
          .hitTestBehavior(HitTestMode.None)
          .opacity(this.started ? 1 : 0)
          .animation({ duration: 260, curve: Curve.EaseOut })
          .onPrepared((): void => {
            this.prepared = true;
            if (this.onScreen) {
              this.startVideo();
            }
          })
          .onStart((): void => {
            this.started = true;
            hilog.info(0, 'RzdMotionCover', 'layer start kind=%{public}s name=%{public}s', this.kind, this.name);
          })
          .onError((err: BusinessError): void => {
            this.failed = true;
            this.started = false;
            hilog.warn(0, 'RzdMotionCover', 'layer error kind=%{public}s name=%{public}s msg=%{public}s',
              this.kind, this.name, String(err.message));
          })
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .onVisibleAreaChange([0.0, 0.05], (isVisible: boolean, ratio: number): void => {
      this.onScreen = isVisible;
      if (isVisible) {
        if (this.prepared) {
          this.startVideo();
        }
      } else if (this.started) {
        this.controller.pause();
        this.started = false;
      }
    })
  }

  /** 起播（准备好之前调用会失败，所以只有 `prepared` 之后才走这里）。 */
  private startVideo(): void {
    try {
      this.controller.start();
    } catch (err) {
      hilog.warn(0, 'RzdMotionCover', 'layer start failed name=%{public}s err=%{public}s',
        this.name, JSON.stringify(err));
    }
  }
}
