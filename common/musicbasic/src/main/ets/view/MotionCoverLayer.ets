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
 * 首帧（Apple `previewFrame`）的**最长等待**：等它解码完就立刻放行视频；
 * 万一 `onComplete` 一直不来（图挂了 / 尺寸为 0），到这个时限也放行，不让页面停在静图。
 */
const MOTION_POSTER_WAIT_MS: number = 600;

/**
 * **动态封面**那一层：盖在页面原有的大封面（静图）**之上**。
 *
 * 次序与"有没有过渡"（甲方 2026-10-24 两轮反馈定稿）：
 * ```
 *   页面静图 ──(首帧解码完，直接换)──▶ Apple 首帧 previewFrame ──(视频起播，直接接上)──▶ 视频循环
 * ```
 * **两段都不做淡入**：首帧与视频第一帧是同一张图，中间再叠淡变反而像"画面在动"；
 * 甲方原话：「因为是首帧，播放前不需要淡入吧」。
 *
 * 为什么还要分两层（而不是直接挂 `Video`）：
 * 1. 解析要联网（两次 HTML，~1.5MB），首帧比视频先到，页面不能等；
 * 2. `Video` 在预览帧/第一帧就绪前是**黑底** ⇒ 直接在静图上叠 `Video` 会先闪一下黑；
 *    ⇒ 先让 `Image(previewFrame)` 站住，再让视频层上场。
 *
 * 硬规矩（对应 ArkUI `Video` 官方文档）：
 * - `.muted(true)` **必须**在起播前生效，否则会抢音频焦点（音乐 App 里这是致命的：
 *   动态封面一出声就把正在播的歌顶掉了）；
 * - 用 `previewUri` 给首帧（Apple 的 `previewFrame` 与第一帧对齐）；
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
  /**
   * 首帧（`previewFrame`）真正解码完成时回调一次，参数是海报地址。
   *
   * 宿主页用它**按动态封面重新取色**：页面原有的取色是用平台那张静态照片算的
   * （例：Apple 的艺人图偏绿、平台图偏棕色衣服 ⇒ 页面底色是棕的，和屏幕上的图对不上）。
   */
  @Event onPosterReady: (posterUrl: string) => void = (posterUrl: string): void => {};
  /** 其它设置里的「动态封面」总开关：关掉时整层不渲染，零请求、零解码。 */
  @Local state: MotionCoverState =
    AppStorageV2.connect(MotionCoverState, AppStorageKeys.MOTION_COVER_STATE, () => new MotionCoverState())!;
  @Local cover: MotionCover | undefined = undefined;
  /** 首帧海报**已经解码完**（此后才允许视频层上场）。 */
  @Local posterReady: boolean = false;
  /** 首帧海报加载失败（失败就不再画那一层，退回页面静图）。 */
  @Local posterFailed: boolean = false;
  /** 首帧已经先上场（或确定上不了场）⇒ 此刻才允许视频这一层挂载/起播。 */
  @Local videoAllowed: boolean = false;
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
  /** 首帧 preroll 定时器（-1 = 没在跑）。 */
  private rollTimer: number = -1;
  /** `onPosterReady` 每张海报只报一次（避免布局抖动重复触发宿主取色）。 */
  private posterNotified: boolean = false;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    void this.reload();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.clearRollTimer();
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
    this.posterReady = false;
    this.posterFailed = false;
    this.posterNotified = false;
    this.videoAllowed = false;
    this.clearRollTimer();
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
    this.armVideoAfterPoster();
    hilog.info(0, 'RzdMotionCover',
      'layer kind=%{public}s name=%{public}s hit=%{public}d field=%{public}s',
      this.kind, this.name, resolved !== undefined ? 1 : 0, resolved !== undefined ? resolved.field : 'none');
  }

  /**
   * 等首帧（`previewFrame`）先上场，再让 `Video` 挂载起播。
   *
   * 为什么还要等：`Video` 在预览帧/第一帧就绪之前是黑底 ⇒ 直接在"页面静图"上叠一个
   * `Video`，用户会先看到一下黑。所以先让**首帧**（与视频第一帧同一张图）站住，
   * 视频层再上场；两者之间**不加任何过渡**（甲方 2026-10-24：「因为是首帧，播放前不需要淡入」）。
   *
   * 三种情况直接放行，不让首帧挡住视频：
   * ① 这个实体没有首帧（`posterUrl` 为空）；② 首帧加载失败（`onError` 里放行）；
   * ③ 超过 {@link MOTION_POSTER_WAIT_MS} 还没解码完。
   */
  private armVideoAfterPoster(): void {
    this.videoAllowed = false;
    if (this.cover === undefined || this.cover.posterUrl.length === 0) {
      this.videoAllowed = true;
      return;
    }
    this.clearRollTimer();
    this.rollTimer = setTimeout((): void => {
      this.rollTimer = -1;
      this.videoAllowed = true;
    }, MOTION_POSTER_WAIT_MS);
  }

  /** @returns 当前首帧地址（`onPosterReady` 的入参；没有就空串）。 */
  private coverPosterUrl(): string {
    const cover: MotionCover | undefined = this.cover;
    return cover !== undefined ? cover.posterUrl : '';
  }

  private clearRollTimer(): void {
    if (this.rollTimer !== -1) {
      clearTimeout(this.rollTimer);
      this.rollTimer = -1;
    }
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
      // 首帧（Apple 的 `previewFrame`，= 视频第一帧）自己一层，**不淡入、不淡出**：
      // 解码完直接出现（`Image` 没解码完时什么都不画，底下的页面静图照旧可见）。
      // ★ 2026-10-24 甲方澄清：「因为是首帧，播放前不需要淡入吧」⇒ 这一层与视频之间
      //   不叠任何过渡：首帧出来 → 视频起播 → 视频层直接接上（同图换源，肉眼无变化）。
      if (this.state.enabled && !this.posterFailed && this.cover !== undefined &&
        this.cover.posterUrl.length > 0) {
        Image(this.cover.posterUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .interpolation(ImageInterpolation.Medium)
          .onComplete((): void => {
            this.posterReady = true;
            // 首帧已经出来了 ⇒ 立刻放行视频（不再等 preroll，也不需要淡入）
            this.clearRollTimer();
            this.videoAllowed = true;
            if (!this.posterNotified) {
              this.posterNotified = true;
              this.onPosterReady(this.coverPosterUrl());
            }
          })
          .onError((): void => {
            this.posterFailed = true;
            this.posterReady = false;
            // 首帧不可用 ⇒ 立刻放行视频（否则这一页永远只有静图）
            this.videoAllowed = true;
            hilog.warn(0, 'RzdMotionCover', 'layer poster failed name=%{public}s', this.name);
          })
      }
      if (this.drawable() && this.videoAllowed && this.cover !== undefined) {
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
          // 首帧已经铺在下面了 ⇒ 视频**起播那一刻直接接上**（不加过渡，避免"播放前淡入"）
          .opacity(this.started ? 1 : 0)
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
