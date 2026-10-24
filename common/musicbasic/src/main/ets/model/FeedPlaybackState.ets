/*
 * 「现在就听」**自己的播放栈状态**（与播放页那套 `MusicAppState` 解耦）。
 *
 * ## 甲方 2026-10-24 第 ① 条
 * 「现在就听独立出来，不要再用现有的播放逻辑（防止大量 Bug，直接就直接复用现有播放器了）」
 * —— 声明的边界是：**队列 / 索引 / 谁在播这一份** 由本状态拥有；
 *    音频仍然只能经 `MediaService`（全仓唯一出声链路，不重写）；
 *    `MusicAppState` 只作为**镜像**供迷你条 / 播放页显示，feed 不再从它的 `playQueue` 反推身份。
 *
 * ## 为什么只存 source + songId
 * feed 判断"全局队列是不是屏幕上这一份"只比**身份**（`source + songId`），不比标题/封面；
 * 存最小字段可以避免 musicbasic 反向依赖 `features/player` 的类型（`LXSearchSong` 在上层）。
 *
 * 排查：feed 侧 `grep RzdFeed`（`play switch` / `play index=` / `feed stack queue=`）。
 */

/** 队列里的一项：只留身份字段（够做"是不是同一批歌"的比对）。 */
@ObservedV2
export class FeedQueueEntry {
  /** 音源代号（'tx' / 'kg' / 'kw' / 'wy' / 'mg'）。 */
  @Trace public source: string = '';
  /** 该音源内的歌曲 id。 */
  @Trace public songId: string = '';
}

/**
 * 「现在就听」的播放栈：自己的队列 + 当前下标。
 *
 * ⚠️ 用 `AppStorageV2` 存同一份实例，是为了"页面被复用/被重建"时队列不丢
 *    （与 `MusicAppState` 同一个通道机制，但**不是同一个对象**）。
 */
@ObservedV2
export class FeedPlaybackState {
  /** 本页自己的队列（身份快照，与屏幕上的行一一对应）。 */
  @Trace public queue: FeedQueueEntry[] = [];
  /** 队列里的当前下标（-1 = 还没起播）。 */
  @Trace public index: number = -1;
  /** 这份队列是否由本页建立并仍在生效（false = 用户在别处换了队列）。 */
  @Trace public active: boolean = false;
  /** 队列变化计数（排查用，也让依赖它的 UI 能感知"换了"）。 */
  @Trace public version: number = 0;

  /**
   * 用行快照重建队列。
   * @param entries 与屏幕行一一对应的身份列表
   * @param startIndex 起播下标
   */
  public resetTo(entries: FeedQueueEntry[], startIndex: number): void {
    this.queue = entries;
    this.index = startIndex;
    this.active = true;
    this.version++;
  }

  /** 外部（其它页面）换过队列时，把本页栈标为失效，下次播放会重建。 */
  public invalidate(): void {
    this.active = false;
    this.version++;
  }
}
