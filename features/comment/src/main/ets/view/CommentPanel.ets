/*
 * 评论面板（移植自 lxmusic-harmony 的 `views/CommentSheet.ets`）。
 *
 * 对应洛雪的评论页：头部「「歌名」的评论」+「热门 / 最新」两个页签（每页 15 条，
 * 拉到底继续加载），页签右边一颗刷新钮；每条评论带头像、昵称、点赞数、时间与 IP 属地，
 * 长文折叠、楼中楼缩进一层。
 *
 * 与洛雪的两处差异，都是为了贴合本工程的界面结构：
 *   1. **不是路由页**：本工程的路由只有 Navigation + NavPathStack，而评论是「从播放页 /
 *      歌曲菜单里临时盖上来的一层」，做成 sheet 里的内容更简单，也不用往路由表里加页面；
 *   2. **宿主决定标题栏**：`showHeader` 为假时不画自绘标题（宿主 sheet 自带标题与关闭钮），
 *      这样播放页的「更多」弹层和歌曲菜单弹层都能直接复用同一个面板。
 *
 * 数据来自 `core/CommentApi`（内置平台接口），与自定义音源无关。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  COMMENT_PAGE_SIZE,
  CommentKind,
  CommentPage,
  CommentSongRef,
  commentsSupported,
  dedupeComments,
  fetchComments,
  LxComment
} from '../core/CommentApi';
import { commentTargetOf, needsPlatformMatch } from '../core/CommentTarget';
import { COMMENT_TAG } from '../core/CommentHttp';
import { saveImageToLocal } from '../core/CommentImageSaver';
import type { SaveImageResult } from '../core/CommentImageSaver';

const DOMAIN: number = 0x0000;

/** 主评论正文超过这个字数就折起来（洛雪是 160，这里同量级）。 */
const TEXT_LIMIT: number = 140;

/**
 * `Image.onComplete` 回传的信息。
 *
 * 字段与 SDK 里那个匿名对象类型一一对应（少写一个字段就会因「参数类型不兼容」编译失败），
 * 这里只用到原图的 `width` / `height` —— 用来算「铺满宽度」时的高度。
 */
interface CommentImageSize {
  width: number;
  height: number;
  componentWidth: number;
  componentHeight: number;
  loadingStatus: number;
  contentWidth: number;
  contentHeight: number;
  contentOffsetX: number;
  contentOffsetY: number;
}

/**
 * 评论面板。
 *
 * 宿主只要给一首歌（`song`）和一个 `songKey`（值变化时面板会重新加载，用来应对
 * 「面板开着的时候切歌了」），以及可选的关闭回调。
 */
@ComponentV2
export struct CommentPanel {
  /** 当前歌的平台身份（本地歌传 source='local' + songId=<本地 key>）。 */
  @Param song: CommentSongRef = { source: '', songId: '', name: '', singer: '' };
  /**
   * 歌曲标识（`source_songId`）。
   *
   * `@Param song` 是普通对象（不是 @ObservedV2），改字段不会触发任何刷新，
   * 所以「换歌了要重新拉评论」这件事靠这个字符串参数来驱动。
   */
  @Param songKey: string = '';
  /** 是否自绘标题栏（宿主 sheet 已有标题时传 false）。 */
  @Param showHeader: boolean = true;
  /** 宿主关闭回调（自绘标题栏的返回箭头 / 关闭用）。 */
  @Param onClose: (() => void) | null = null;
  /** 底部额外留白（vp）：宿主有悬浮条时用。 */
  @Param bottomInset: number = 0;

  /** 0 = 热门，1 = 最新（默认停在热门）。 */
  @Local kindIndex: number = 0;
  @Local comments: LxComment[] = [];
  @Local loading: boolean = false;
  @Local loadingMore: boolean = false;
  /** 已经拉过的最后一页。 */
  @Local page: number = 0;
  @Local maxPage: number = 1;
  @Local error: string = '';
  /** 两个页签各自的总数（洛雪把总数写在页签文字里）。 */
  @Local hotTotal: number = 0;
  @Local newTotal: number = 0;
  /** 解析出来的平台身份；null = 这首歌看不到评论。 */
  @Local target: CommentSongRef | null = null;
  /** 正在解析平台身份（本地歌要先查匹配记录）。 */
  @Local resolving: boolean = true;
  /** 每次换歌 / 换页签发一个 token，晚回来的旧响应直接丢掉。 */
  private token: number = 0;

  /** 大图查看层是否可见。 */
  @Local viewerVisible: boolean = false;
  /** 大图查看层里的图片列表（点的是哪条评论就放它的全部图）。 */
  @Local viewerImages: string[] = [];
  /** 大图查看层当前页。 */
  @Local viewerIndex: number = 0;
  /**
   * 大图缩放倍数（相对「铺满宽度」）。
   *
   * 默认**不手动缩放**：按「整图可见」（contain）显示 —— 细长的手机截图一进来就能看全，
   * 想看细节再双指放大 / 双击切到「铺满宽度」。
   * 做法不是 `.scale()`，而是**按倍数改内容尺寸**：外层 `Scroll` 因此在放大后自然获得
   * 两个方向的滚动能力（`ScrollDirection.FREE`），小图时又退回只竖直滚动，
   * 横滑留给 `Swiper` 切图 —— 这样「缩放 + 平移 + 切图」三件事互不抢手势。
   */
  @Local viewerZoom: number = 1;
  /** 用户是否手动缩放过（false = 用「整图可见」的默认比例）。 */
  @Local viewerZoomTouched: boolean = false;
  /** 双指缩放的起始倍数。 */
  private pinchBaseZoom: number = 1;
  /** 大图区域实测尺寸（vp）：按倍数算内容宽度要用到。 */
  @Local viewerAreaW: number = 0;
  @Local viewerAreaH: number = 0;
  /** 每一页自己的 Scroller（缩放后要把它滚到内容中心）。 */
  private viewerScrollers: Scroller[] = [];
  /**
   * 捏合锚点：开始捏合时手指中心在**图片自身坐标系**里的位置（vp）。
   *
   * 图片的坐标系就是内容坐标系，所以「手在哪捏合就在哪缩放」= 让这个内容点
   * 在缩放前后落在视口的同一个位置：`scroll = 锚点 ×(k-1) + 边距差 + 起始滚动量`。
   */
  private zoomAnchorX: number = 0;
  private zoomAnchorY: number = 0;
  /** 捏合开始时的滚动量与居中边距（缩放后要拿它们换算新滚动位置）。 */
  private zoomAnchorScrollX: number = 0;
  private zoomAnchorScrollY: number = 0;
  private zoomAnchorMarginX: number = 0;
  private zoomAnchorMarginY: number = 0;
  /** 每张图的宽高比（`onComplete` 拿到原图尺寸后按 URL 记），「铺满宽度」按它算高度。 */
  @Local viewerRatios: Map<string, number> = new Map<string, number>();
  /** 正在保存某张图（保存按钮显示「保存中…」并防重复点击）。 */
  @Local saving: boolean = false;

  aboutToAppear(): void {
    void this.start();
  }

  /** 换歌了：清空重来（面板被宿主复用、没有重建时靠这里兜住）。 */
  @Monitor('songKey')
  onSongKeyChanged(): void {
    hilog.info(DOMAIN, COMMENT_TAG, 'song changed -> %{public}s', this.songKey);
    this.reset();
    void this.start();
  }

  private reset(): void {
    this.token++;
    this.comments = [];
    this.page = 0;
    this.maxPage = 1;
    this.error = '';
    this.loading = false;
    this.loadingMore = false;
    this.hotTotal = 0;
    this.newTotal = 0;
    this.kindIndex = 0;
    this.target = null;
    this.resolving = true;
  }

  /** 先解析平台身份，再拉第一页评论。 */
  private async start(): Promise<void> {
    if (this.song.songId.length === 0 && this.song.source.length === 0) {
      this.resolving = false;
      this.target = null;
      return;
    }
    this.resolving = true;
    let resolved: CommentSongRef | null = null;
    try {
      resolved = await commentTargetOf(this.song);
    } catch (_err) {
      resolved = null;
    }
    this.resolving = false;
    this.target = resolved;
    if (resolved !== null) {
      void this.load(1, false);
    }
  }

  private kind(): CommentKind {
    return this.kindIndex === 0 ? 'hot' : 'new';
  }

  /** 「看不到评论」时到底为什么：能说得具体就具体，用户才知道下一步做什么。 */
  private unsupportedText(): string {
    if (!needsPlatformMatch(this.song) && this.song.songId.length > 0) {
      return '这个平台看不到评论';
    }
    if (needsPlatformMatch(this.song)) {
      return '这首歌还没匹配到平台上的版本';
    }
    return '这首歌看不到评论';
  }

  private unsupportedHint(): string {
    if (needsPlatformMatch(this.song)) {
      return '评论只存在于音乐平台上，本地音乐要先匹配到平台的那一首：' +
        '在「本地音乐」里搜一次并选中正确的版本，之后评论与歌词都会用它。';
    }
    return '评论来自音乐平台，目前支持酷我、酷狗、QQ 音乐、咪咕与网易。';
  }

  /**
   * 拉一页评论。
   * @param page 页码（从 1 开始）。
   * @param append 追加到现有列表（翻页）还是替换（首屏 / 刷新 / 换页签）。
   */
  private async load(page: number, append: boolean): Promise<void> {
    const info: CommentSongRef | null = this.target;
    if (info === null) {
      return;
    }
    if (append) {
      if (this.loadingMore || this.loading) {
        return;
      }
      this.loadingMore = true;
    } else {
      this.loading = true;
      this.error = '';
      this.page = 0;
    }
    const myToken: number = ++this.token;
    try {
      const result: CommentPage = await fetchComments(info, this.kind(), page, COMMENT_PAGE_SIZE);
      if (myToken !== this.token) {
        return;
      }
      this.comments = append ? dedupeComments(this.comments.concat(result.comments)) : result.comments;
      this.maxPage = result.maxPage;
      this.page = page;
      if (this.kind() === 'hot') {
        this.hotTotal = result.total;
      } else {
        this.newTotal = result.total;
      }
      hilog.info(DOMAIN, COMMENT_TAG, '%{public}s page=%{public}d -> %{public}d comments (total %{public}d)',
        this.kind(), page, result.comments.length, result.total);
    } catch (err) {
      if (myToken !== this.token) {
        return;
      }
      const message: string = (err as Error).message;
      hilog.warn(DOMAIN, COMMENT_TAG, 'load comments failed: %{public}s', message);
      this.error = message;
    } finally {
      if (myToken === this.token) {
        this.loading = false;
        this.loadingMore = false;
      }
    }
  }

  private switchKind(index: number): void {
    if (this.kindIndex === index) {
      return;
    }
    this.kindIndex = index;
    this.comments = [];
    this.page = 0;
    this.maxPage = 1;
    this.error = '';
    void this.load(1, false);
  }

  /** 还有没有下一页：按平台给的 maxPage 判断。 */
  private hasMore(): boolean {
    return this.comments.length > 0 && this.page < this.maxPage;
  }

  private tabLabel(label: string, total: number): string {
    return total > 0 ? `${label} (${total})` : label;
  }

  // ---------------------------------------------------------------------------
  // 大图查看 + 保存到本地
  // ---------------------------------------------------------------------------

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /**
   * 打开大图（点缩略图，或长按菜单里的「查看大图」）。
   * @param images 这条评论的全部图片（大图里可以左右滑着看）。
   * @param index 刚才点的那一张。
   */
  private handleOpenImage(images: string[], index: number): void {
    if (images.length === 0) {
      return;
    }
    this.viewerImages = [...images];
    this.viewerIndex = Math.max(0, Math.min(index, images.length - 1));
    // 默认按「整图可见」显示（细长截图一进来就能看全）
    this.viewerZoomTouched = false;
    this.viewerVisible = true;
    hilog.info(DOMAIN, COMMENT_TAG, 'open image viewer index=%{public}d count=%{public}d',
      this.viewerIndex, this.viewerImages.length);
  }

  private closeViewer(): void {
    this.viewerVisible = false;
    this.viewerImages = [];
    this.viewerZoomTouched = false;
  }

  /** 缩放回「整图可见」（顶部百分比标签点一下就是它）。 */
  private resetViewerZoom(): void {
    this.viewerZoomTouched = false;
    this.recenterViewer();
  }

  /** 当前页的图片地址。 */
  private currentViewerUrl(): string {
    return this.viewerIndex >= 0 && this.viewerIndex < this.viewerImages.length
      ? this.viewerImages[this.viewerIndex] : '';
  }

  /** 取（必要时创建）某一页的 Scroller。 */
  private scrollerFor(index: number): Scroller {
    let scroller: Scroller | undefined = this.viewerScrollers[index];
    if (scroller === undefined) {
      scroller = new Scroller();
      this.viewerScrollers[index] = scroller;
    }
    return scroller;
  }

  /**
   * 「整图可见」相对「铺满宽度」的缩放比例。
   *
   * 铺满宽度时的高度 = 可视宽 / 宽高比；比可视高还高（细长截图）就说明要缩一点才能看全。
   * @returns ≤ 1 的比例；1 表示铺满宽度时本来就能看全（横向的图）。
   */
  private fitScaleFor(url: string): number {
    const areaW: number = this.viewerAreaW > 0 ? this.viewerAreaW : 360;
    const areaH: number = this.viewerAreaH > 0 ? this.viewerAreaH : 640;
    const ratio: number = this.ratioOf(url);
    const heightAtFullWidth: number = areaW / (ratio > 0 ? ratio : 1);
    return heightAtFullWidth > areaH ? areaH / heightAtFullWidth : 1;
  }

  /** 当前生效的缩放：没手动缩放过就是「整图可见」。 */
  private effectiveZoom(url: string): number {
    return this.viewerZoomTouched ? this.viewerZoom : this.fitScaleFor(url);
  }

  /** 缩放下限：比「整图可见」再小一点（用户要的「能缩小」）。 */
  private minZoomFor(url: string): number {
    return Math.max(0.05, this.fitScaleFor(url) * 0.6);
  }

  /** 缩放上限：最多到「两倍屏宽」；本来就很小（很宽的图）时至少给到 3 倍。 */
  private maxZoomFor(url: string): number {
    return Math.max(3, 2 / Math.max(this.fitScaleFor(url), 0.0001));
  }

  /** 缩放收敛到本图允许的区间，并抹掉浮点噪声。 */
  private setZoom(value: number): void {
    const url: string = this.currentViewerUrl();
    if (url.length === 0) {
      return;
    }
    const rounded: number = this.clampZoom(value, url);
    this.viewerZoomTouched = true;
    if (Math.abs(rounded - this.viewerZoom) < 0.001) {
      return;
    }
    this.viewerZoom = rounded;
  }

  /** 把缩放夹到本图允许的区间并去掉浮点噪声（捏合时要拿这个夹过的值算锚点）。 */
  private clampZoom(value: number, url: string): number {
    const clamped: number = Math.min(this.maxZoomFor(url), Math.max(this.minZoomFor(url), value));
    return Math.round(clamped * 100) / 100;
  }

  /** 内容比视口窄时，水平居中留下的左边距（vp）。 */
  private viewerLeftMargin(zoom: number): number {
    const areaW: number = this.viewerAreaW > 0 ? this.viewerAreaW : 360;
    return Math.max(0, (areaW - areaW * zoom) / 2);
  }

  /** 内容比视口矮时，垂直居中留下的上边距（vp）。 */
  private viewerTopMargin(zoom: number, url: string): number {
    const areaW: number = this.viewerAreaW > 0 ? this.viewerAreaW : 360;
    const areaH: number = this.viewerAreaH > 0 ? this.viewerAreaH : 640;
    const ratio: number = this.ratioOf(url);
    const contentH: number = areaW * zoom / (ratio > 0 ? ratio : 1);
    return Math.max(0, (areaH - contentH) / 2);
  }

  /**
   * 记下捏合锚点（手势开始时调一次）。
   * @param startZoom 手势开始时的缩放。
   * @param anchorX 手指中心在图片自身坐标系里的 x（= `pinchCenterX`）。
   * @param anchorY 同上，y。
   */
  private beginZoomAnchor(startZoom: number, anchorX: number, anchorY: number): void {
    const scroller: Scroller | undefined = this.viewerScrollers[this.viewerIndex];
    const offset: OffsetResult = scroller !== undefined ? scroller.currentOffset() : { xOffset: 0, yOffset: 0 };
    const url: string = this.currentViewerUrl();
    this.zoomAnchorX = anchorX;
    this.zoomAnchorY = anchorY;
    this.zoomAnchorScrollX = offset.xOffset;
    this.zoomAnchorScrollY = offset.yOffset;
    this.zoomAnchorMarginX = this.viewerLeftMargin(startZoom);
    this.zoomAnchorMarginY = this.viewerTopMargin(startZoom, url);
  }

  /**
   * 保持锚点不动地把内容滚到新位置（缩放后调）—— 这就是「手在哪捏合就在哪缩放」。
   *
   * 不这么做的话内容会从左上角重新铺，观感是「一缩放就跳到左上角」；
   * 之前那版是**松手后**才把内容滚到中心，于是变成「一松手就跑到屏幕中间」，也不对。
   */
  private applyZoomAnchor(targetZoom: number, startZoom: number): void {
    const scroller: Scroller | undefined = this.viewerScrollers[this.viewerIndex];
    if (scroller === undefined || startZoom <= 0) {
      return;
    }
    const url: string = this.currentViewerUrl();
    const k: number = targetZoom / startZoom;
    const x: number = Math.max(0, this.zoomAnchorX * (k - 1) +
      this.viewerLeftMargin(targetZoom) - this.zoomAnchorMarginX + this.zoomAnchorScrollX);
    const y: number = Math.max(0, this.zoomAnchorY * (k - 1) +
      this.viewerTopMargin(targetZoom, url) - this.zoomAnchorMarginY + this.zoomAnchorScrollY);
    const apply = (): void => {
      try {
        scroller.scrollTo({ xOffset: x, yOffset: y });
      } catch (_err) {
        // 内容尺寸还没更新完；下一帧那次会兜住
      }
    };
    apply();
    // 内容尺寸是这一帧才变的，再补一次确保落到位（两次都滚到同一个目标，不会跳动）
    setTimeout(apply, 0);
  }

  /**
   * 大图内容宽度（vp）= 可视宽 × 缩放倍数。
   *
   * 图片按这个宽度 + 原图宽高比排版：默认（整图可见）时图比屏幕窄/矮，四周留黑；
   * 放大后内容比视口大 → 外层 Scroll 出现双向滚动。
   */
  private viewerContentWidthVp(url: string): number {
    const base: number = this.viewerAreaW > 0 ? this.viewerAreaW : 360;
    return Math.max(1, base * this.effectiveZoom(url));
  }

  /** 内容容器宽度：不小于可视宽，这样图比屏幕窄时能**水平居中**（否则会贴在左边）。 */
  private viewerColumnWidthVp(url: string): number {
    const areaW: number = this.viewerAreaW > 0 ? this.viewerAreaW : 360;
    return Math.max(areaW, this.viewerContentWidthVp(url));
  }

  /**
   * 把当前页滚到「内容中心」。
   *
   * 不做这一步的话，缩放后内容是从 Scroll 的**左上角**开始铺的 ——
   * 观感就是「一缩放图就跑到左上角」。内容比视口小时目标是 (0,0)（此时靠居中约束摆好）。
   */
  private recenterViewer(): void {
    const index: number = this.viewerIndex;
    const url: string = this.currentViewerUrl();
    if (url.length === 0) {
      return;
    }
    const scroller: Scroller | undefined = this.viewerScrollers[index];
    if (scroller === undefined) {
      return;
    }
    const contentW: number = this.viewerContentWidthVp(url);
    const ratio: number = this.ratioOf(url);
    const contentH: number = ratio > 0 ? contentW / ratio : contentW;
    const areaW: number = this.viewerAreaW > 0 ? this.viewerAreaW : 360;
    const areaH: number = this.viewerAreaH > 0 ? this.viewerAreaH : 640;
    const x: number = Math.max(0, (contentW - areaW) / 2);
    const y: number = Math.max(0, (contentH - areaH) / 2);
    // 等这一帧的尺寸变更落地再滚，否则滚的还是旧内容尺寸
    setTimeout((): void => {
      try {
        scroller.scrollTo({ xOffset: x, yOffset: y, animation: { duration: 160, curve: Curve.EaseOut } });
      } catch (_err) {
        // 内容还没更新完（例如刚换图）；下次缩放会再校正
      }
    }, 0);
  }

  /** 还没拿到原图尺寸时占位用的宽高比（竖图比例，避免先撑成方的再跳一下）。 */
  private ratioOf(url: string): number {
    const ratio: number | undefined = this.viewerRatios.get(url);
    return ratio !== undefined && ratio > 0 ? ratio : 0.75;
  }

  /**
   * 图片加载完成：记下原图宽高比（「铺满宽度」模式按它算高度）。
   *
   * 按 **URL** 记而不是按下标：换一条评论的图时，下标会重复，
   * 用下标会把上一条评论的比例套到新图上（先按错误比例排版，等加载完再跳一下）。
   */
  private onViewerImageLoaded(url: string, width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }
    const ratio: number = width / height;
    if (this.viewerRatios.get(url) === ratio) {
      return;
    }
    // Map 换新实例触发刷新（V2 不会追踪 Map 内部改动）
    const next: Map<string, number> = new Map<string, number>();
    this.viewerRatios.forEach((value: number, key: string): void => {
      next.set(key, value);
    });
    next.set(url, ratio);
    this.viewerRatios = next;
    hilog.info(DOMAIN, COMMENT_TAG, 'image ratio=%{public}f url=%{public}s', ratio, url);
  }

  /**
   * 保存一张图（缩略图长按菜单、大图层的保存按钮共用同一份逻辑）。
   * @param url 图片地址。
   */
  private async saveImage(url: string): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    this.toast('正在保存…');
    try {
      const result: SaveImageResult = await saveImageToLocal(url, this.song.name);
      this.toast(result.message);
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(DOMAIN, COMMENT_TAG, 'save image failed: %{public}s', e.message ?? '');
      this.toast('保存失败');
    } finally {
      this.saving = false;
    }
  }

  /** 保存大图层当前这一张。 */
  private async saveCurrentImage(): Promise<void> {
    if (this.viewerIndex < 0 || this.viewerIndex >= this.viewerImages.length) {
      return;
    }
    await this.saveImage(this.viewerImages[this.viewerIndex]);
  }

  /**
   * 大图查看层。
   *
   * 盖在面板之上，而不是新开路由或再叠一个系统弹层 —— 评论面板本身就在宿主的
   * sheet 里（播放页「更多」/ 歌曲菜单），再叠系统弹层容易打架。这一层占满整个
   * 面板区域，看图体验已经是「大图」。
   *
   * 看图交互：
   *   - 1x：图片**铺满宽度**（左右不留黑边），比屏幕高的部分上下滑；
   *   - **双指自由缩放**（1x ~ 4x），双击在 1x / 2.5x 之间切；
   *   - 放大后内容比视口大，外层 Scroll 切到 `ScrollDirection.FREE`，两个方向都能拖；
   *     缩回 1x 自动退回只竖直滚动，横滑重新留给 `Swiper` 切图。
   * 这样「缩放 / 平移 / 切图」三件事各用各的手势，不会互相抢。
   */
  @Builder
  private ImageViewer() {
    Column() {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontWeight(FontWeight.Regular)
          .fontColor([Color.White])
          .padding({ left: 14, right: 4, top: 8, bottom: 8 })
          .onClick(() => {
            this.closeViewer();
          })
          .accessibilityText('关闭大图')
          .accessibilityLevel('yes')

        Text(this.viewerImages.length > 1 ? `${this.viewerIndex + 1} / ${this.viewerImages.length}` : '')
          .fontSize($r('sys.float.Body_S'))
          .fontColor('#B3FFFFFF')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 手动缩放过才显示比例（相对铺满宽度），点一下回到「整图可见」
        if (this.viewerZoomTouched) {
          Text(`${Math.round(this.effectiveZoom(this.currentViewerUrl()) * 100)}%`)
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#B3FFFFFF')
            .padding({ left: 8, right: 8, top: 8, bottom: 8 })
            .onClick(() => {
              this.resetViewerZoom();
            })
            .accessibilityText('恢复整图显示')
            .accessibilityLevel('yes')
        }

        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.arrow_down_circle'))
            .fontSize(18)
            .fontWeight(FontWeight.Regular)
            .fontColor([Color.White])
          Text(this.saving ? '保存中…' : '保存')
            .fontSize($r('sys.float.Body_S'))
            .fontColor(Color.White)
        }
        .padding({ left: 8, right: 14, top: 8, bottom: 8 })
        .onClick(() => {
          void this.saveCurrentImage();
        })
        .accessibilityText('保存这张图片到本地')
        .accessibilityLevel('yes')
      }
      .width('100%')
      .height(48)

      Swiper() {
        ForEach(this.viewerImages, (url: string, index: number) => {
          Scroll(this.scrollerFor(index)) {
            Column() {
              Image(url)
                // 宽度 = 可视宽 × 缩放：默认「整图可见」，放大后由外层 Scroll 拖动
                .width(this.viewerContentWidthVp(url))
                .aspectRatio(this.ratioOf(url))
                .objectFit(ImageFit.Contain)
                .draggable(false)
                .onComplete((event?: CommentImageSize): void => {
                  if (event !== undefined) {
                    this.onViewerImageLoaded(url, event.width, event.height);
                  }
                })
                .gesture(
                  GestureGroup(GestureMode.Exclusive,
                    TapGesture({ count: 2 })
                      .onAction(() => {
                        // 双击是「整图 ⇄ 铺满宽度」的模式切换：以视口中心为锚点，不跳到别处
                        const current: number = this.effectiveZoom(url);
                        const fit: number = this.fitScaleFor(url);
                        const target: number = this.clampZoom(
                          Math.abs(current - fit) <= Math.abs(current - 1) ? 1 : fit, url);
                        this.beginZoomAnchor(current,
                          (this.viewerAreaW > 0 ? this.viewerAreaW : 360) / 2,
                          (this.viewerAreaH > 0 ? this.viewerAreaH : 640) / 2);
                        this.setZoom(target);
                        this.applyZoomAnchor(target, current);
                      }),
                    PinchGesture({ fingers: 2 })
                      .onActionStart((event: GestureEvent) => {
                        // 记下手指中心：整段捏合都围着它缩放（松手不归位）
                        const current: number = this.effectiveZoom(url);
                        this.pinchBaseZoom = current;
                        this.beginZoomAnchor(current, event.pinchCenterX ?? 0, event.pinchCenterY ?? 0);
                      })
                      .onActionUpdate((event: GestureEvent) => {
                        const target: number = this.clampZoom(this.pinchBaseZoom * event.scale, url);
                        this.setZoom(target);
                        this.applyZoomAnchor(target, this.pinchBaseZoom);
                      })
                  )
                )
            }
            // 容器宽度不小于可视宽 → 图比屏幕窄时**水平居中**（否则会贴在左边）
            .width(this.viewerColumnWidthVp(url))
            .alignItems(HorizontalAlign.Center)
            // 图比屏幕矮时撑满高度并居中（上下黑边左右对称，不是「偏在上边」）
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          // 放大到超出屏宽后自由滚动（横竖都能拖）；否则只竖直滚，横滑留给 Swiper 切图
          .scrollable(this.effectiveZoom(url) > 1.01 ? ScrollDirection.FREE : ScrollDirection.Vertical)
          // 内容不足一屏时 Scroll 会把子内容垂直居中，这里要顶对齐
          .align(Alignment.Top)
        }, (url: string) => 'viewer-' + url)
      }
      .index(this.viewerIndex)
      // 多图才显示圆点
      .indicator(this.viewerImages.length > 1)
      .loop(false)
      .onChange((index: number) => {
        this.viewerIndex = index;
        // 换图回到默认比例（整图可见），免得上一张的缩放串到下一张
        this.viewerZoomTouched = false;
      })
      .onAreaChange((_oldArea: Area, area: Area): void => {
        const w: number = area.width as number;
        const h: number = area.height as number;
        if (w > 0 && Math.abs(w - this.viewerAreaW) > 0.5) {
          this.viewerAreaW = w;
        }
        if (h > 0 && Math.abs(h - this.viewerAreaH) > 0.5) {
          this.viewerAreaH = h;
        }
      })
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(Color.Black)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  @Builder
  private TabItem(index: number, label: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize($r('sys.float.Subtitle_S'))
        .fontWeight(this.kindIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.kindIndex === index ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
        .maxLines(1)
      // 选中态下面那条短线
      Column()
        .width(this.kindIndex === index ? 18 : 0)
        .height(2)
        .borderRadius(1)
        .backgroundColor($r('sys.color.font_primary'))
    }
    .height(38)
    .padding({ left: 10, right: 10 })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.switchKind(index);
    })
    .accessibilityText(label)
    .accessibilityLevel('yes')
  }

  @Builder
  private Header() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(22)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('sys.color.font_primary')])
        .padding({ left: 6, right: 10, top: 6, bottom: 6 })
        .onClick(() => {
          if (this.onClose !== null) {
            this.onClose();
          }
        })
        .accessibilityText('返回')
        .accessibilityLevel('yes')

      Text(this.song.name.length > 0 ? `「${this.song.name}」的评论` : '评论')
        .fontSize($r('sys.float.Subtitle_M'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(20)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('sys.color.font_tertiary')])
        .padding({ left: 10, right: 6, top: 6, bottom: 6 })
        .onClick(() => {
          void this.load(1, false);
        })
        .accessibilityText('刷新评论')
        .accessibilityLevel('yes')
    }
    .width('100%')
    .height(50)
    .padding({ left: 6, right: 6 })
  }

  @Builder
  private Tabs() {
    Row() {
      this.TabItem(0, this.tabLabel('热门', this.hotTotal))
      this.TabItem(1, this.tabLabel('最新', this.newTotal))
      Blank()
    }
    .width('100%')
    .padding({ left: 6, right: 12 })
  }

  @Builder
  private Footer() {
    if (this.error.length > 0) {
      Column({ space: 6 }) {
        Text(this.error)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
        Text('点击重试')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            // page = 0 表示第一页就没拉起来（重试第一页），否则重试「下一页」
            void this.load(this.page + 1, this.page > 0);
          })
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
    } else if (this.hasMore()) {
      Text(this.loadingMore ? '正在加载更多…' : '上拉加载更多')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 14, bottom: 14 })
    } else if (this.comments.length > 0) {
      Text(`共 ${this.comments.length} 条`)
        .fontSize($r('sys.float.Caption_L'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 14, bottom: 14 })
    }
  }

  /** 居中的提示文字（加载 / 准备中）。 */
  @Builder
  private CenterHint(text: string) {
    Text(text)
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: 40, bottom: 40 })
  }

  /** 空态：图标 + 一句话 + 一句提示。 */
  @Builder
  private EmptyState(icon: Resource, text: string, hint: string) {
    Column({ space: 10 }) {
      SymbolGlyph(icon)
        .fontSize(40)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(text)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Center)
      Text(hint)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_tertiary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .padding({ top: 40, bottom: 40 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private Body() {
    if (this.resolving) {
      this.CenterHint(needsPlatformMatch(this.song) ? '正在查找这首歌的平台版本…' : '正在准备评论…')
    } else if (this.target === null) {
      this.EmptyState($r('sys.symbol.text_bubble_left_2'), this.unsupportedText(), this.unsupportedHint())
    } else if (this.loading && this.comments.length === 0 && this.error.length === 0) {
      Column({ space: 10 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('sys.color.icon_tertiary'))
        Text('正在加载评论…')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .padding({ top: 40, bottom: 40 })
      .justifyContent(FlexAlign.Center)
    } else if (this.comments.length === 0 && this.error.length === 0) {
      this.EmptyState($r('sys.symbol.text_bubble_left_2'), '还没有人评论', '来听这首歌的人还不多，过些时候再看看。')
    } else {
      List() {
        ForEach(this.comments, (item: LxComment) => {
          ListItem() {
            CommentRow({
              comment: item,
              onOpenImage: (images: string[], index: number): void => {
                this.handleOpenImage(images, index);
              },
              onSaveImage: (url: string): void => {
                void this.saveImage(url);
              }
            })
          }
        }, (item: LxComment) => 'c-' + item.id)

        ListItem() {
          this.Footer()
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 16, right: 16 })
      .onReachEnd(() => {
        if (this.hasMore() && !this.loadingMore && !this.loading && this.error.length === 0) {
          void this.load(this.page + 1, true);
        }
      })
    }
  }

  build() {
    // 根节点用 Stack：大图查看层要盖在面板（含自绘标题栏）之上
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        if (this.showHeader) {
          this.Header()
        }
        if (this.target !== null) {
          this.Tabs()
        }
        this.Body()
        if (this.bottomInset > 0) {
          Column()
            .width('100%')
            .height(this.bottomInset + 8)
        }
      }
      .width('100%')
      .height('100%')

      if (this.viewerVisible) {
        this.ImageViewer()
      }
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 一条评论（含楼中楼）。
 *
 * 长文默认折起来：平台上随手写的长评不少，整段铺开会把列表拉得没法扫。
 */
@ComponentV2
struct CommentRow {
  @Param comment: LxComment = {
    id: '', text: '', userName: '', userId: '', avatar: '', timeStr: '', location: '',
    likedCount: -1, replyNum: -1, images: [], reply: []
  };
  /** 楼中楼（缩进一层），字号与头像都小一号。 */
  @Param nested: boolean = false;
  /**
   * 点图片看大图（由 CommentPanel 实现：大图层要盖住整块面板，不能放在行里）。
   * @param images 这条评论的全部图片。
   * @param index 点的那一张。
   */
  @Param onOpenImage: ((images: string[], index: number) => void) | null = null;
  /** 长按菜单里的「保存到本地」。 */
  @Param onSaveImage: ((url: string) => void) | null = null;
  @Local expanded: boolean = false;

  private openImage(index: number): void {
    if (this.onOpenImage !== null) {
      this.onOpenImage(this.comment.images, index);
    }
  }

  private saveImage(url: string): void {
    if (this.onSaveImage !== null) {
      this.onSaveImage(url);
    }
  }

  /**
   * 图片长按菜单。
   *
   * 用 `bindContextMenu(..., ResponseType.LongPress)` 而**不是** `bindMenu`：
   * 后者是单击弹出，会和「点图看大图」互相抢。
   */
  @Builder
  private ImageMenu(url: string, index: number) {
    Menu() {
      MenuItem({ content: '查看大图' })
        .onClick(() => {
          this.openImage(index);
        })
      MenuItem({ content: '保存到本地' })
        .onClick(() => {
          this.saveImage(url);
        })
    }
    .width(180)
  }

  private tooLong(): boolean {
    return this.comment.text.length > TEXT_LIMIT;
  }

  private shownText(): string {
    if (!this.tooLong() || this.expanded) {
      return this.comment.text;
    }
    return `${this.comment.text.substring(0, TEXT_LIMIT)}…`;
  }

  /** 头像：没有头像地址时用昵称首字做一个圆形占位。 */
  @Builder
  private Avatar() {
    if (this.comment.avatar.length > 0) {
      Image(this.comment.avatar)
        .width(this.nested ? 28 : 36)
        .height(this.nested ? 28 : 36)
        .borderRadius(this.nested ? 14 : 18)
        .objectFit(ImageFit.Cover)
        .backgroundColor($r('sys.color.background_tertiary'))
    } else {
      Column() {
        Text(this.comment.userName.length > 0 ? this.comment.userName.substring(0, 1) : '?')
          .fontSize(this.nested ? 13 : 15)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width(this.nested ? 28 : 36)
      .height(this.nested ? 28 : 36)
      .borderRadius(this.nested ? 14 : 18)
      .backgroundColor($r('sys.color.background_tertiary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private Meta() {
    Row({ space: 8 }) {
      Text(this.comment.userName)
        .fontSize(this.nested ? $r('sys.float.Caption_L') : $r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.comment.likedCount >= 0) {
        Row({ space: 3 }) {
          SymbolGlyph($r('sys.symbol.hand_thumbsup'))
            .fontSize(12)
            .fontWeight(FontWeight.Regular)
            .fontColor([$r('sys.color.icon_tertiary')])
          Text(String(this.comment.likedCount))
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .accessibilityLevel('no')
      }
    }
    .width('100%')
  }

  @Builder
  private SubLine() {
    if (this.comment.timeStr.length > 0 || this.comment.location.length > 0) {
      Row({ space: 10 }) {
        if (this.comment.timeStr.length > 0) {
          Text(this.comment.timeStr)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        if (this.comment.location.length > 0) {
          Text(`IP属地：${this.comment.location}`)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
      }
      .width('100%')
      .padding({ top: 3 })
    }
  }

  @Builder
  private Images() {
    if (this.comment.images.length > 0) {
      // 固定方框 + Contain：评论图多是截图，裁掉两边会看不到原意
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.comment.images, (url: string, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor($r('sys.color.background_tertiary'))
            Image(url)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .draggable(false)
          }
          .width(this.nested ? 88 : 110)
          .height(this.nested ? 88 : 110)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .clip(true)
          .margin({ top: 8, right: 8 })
          // 单击看大图、长按弹菜单（查看大图 / 保存到本地）
          .onClick(() => {
            this.openImage(index);
          })
          .bindContextMenu(this.ImageMenu(url, index), ResponseType.LongPress)
          .accessibilityText('查看大图')
          .accessibilityLevel('yes')
        }, (url: string) => 'img-' + this.comment.id + '-' + url)
      }
      .width('100%')
    }
  }

  build() {
    Row({ space: 10 }) {
      this.Avatar()

      Column() {
        this.Meta()
        this.SubLine()
        Text(this.shownText())
          .fontSize(this.nested ? $r('sys.float.Caption_L') : $r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(this.nested ? 20 : 21)
          .width('100%')
          .padding({ top: 5 })
          .textAlign(TextAlign.Start)
        if (this.tooLong()) {
          Text(this.expanded ? '收起' : '展开')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .padding({ top: 4 })
            .onClick(() => {
              this.expanded = !this.expanded;
            })
            .accessibilityText(this.expanded ? '收起这条评论' : '展开这条评论')
            .accessibilityLevel('yes')
        }
        this.Images()

        // 楼中楼：平台一般只给前几条
        if (this.comment.reply.length > 0) {
          Column() {
            ForEach(this.comment.reply, (reply: LxComment) => {
              CommentRow({
                comment: reply,
                nested: true,
                onOpenImage: this.onOpenImage,
                onSaveImage: this.onSaveImage
              })
            }, (reply: LxComment) => 'r-' + this.comment.id + '-' + reply.id)
          }
          .width('100%')
          .margin({ top: 10 })
          .padding({ top: 10 })
          .border({ width: { top: 0.6 }, color: $r('sys.color.background_tertiary'), style: BorderStyle.Dashed })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 0.6 }, color: $r('sys.color.background_tertiary'), style: BorderStyle.Dashed })
  }
}
