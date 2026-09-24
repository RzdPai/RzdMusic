/*
 * 封面图（本地文件走 PixelMap，网络地址直接给 Image）。
 *
 * 为什么需要它：自定义歌单封面 / 本地音乐封面是**沙箱文件**（`file://<bundle>/files/...`
 * 或绝对路径）。把这种地址直接塞给 `Image()` 在真机上出现过「地址是对的、图就是不出来」
 * 的情况（同一份代码在有的形态上正常、有的不出来）—— 与其猜 URI 解析差异，
 * 不如自己把文件解码成 `PixelMap` 再显示：解码只看字节，不依赖 URI 解析。
 *
 * 缓存：同一个地址只解码一次（模块级 Map，超过上限就整体清掉，避免常驻太多 PixelMap）。
 */

import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'RzdCover';

/** 已解码的本地封面（键 = 地址）。 */
const coverCache: Map<string, PixelMap> = new Map<string, PixelMap>();
/** 缓存上限（张）。 */
const CACHE_LIMIT: number = 24;

@ComponentV2
export struct LocalCoverImage {
  /** 图片地址：`http(s)://`、`file://`、绝对路径，或空串（空串显示灰底占位）。 */
  @Param src: string = '';
  @Param imageWidth: Length = 44;
  @Param imageHeight: Length = 44;
  /** 圆角（vp）；0 = 不切圆角。 */
  @Param radius: number = 0;
  @Param fit: ImageFit = ImageFit.Cover;
  /** 加载失败回调（宿主想换成自己的占位图时用）。 */
  @Param onFailed: (() => void) | null = null;
  /** 解码出来的位图（仅本地文件用）。 */
  @Local pixelMap: PixelMap | undefined = undefined;

  aboutToAppear(): void {
    void this.loadLocal();
  }

  /** 地址变了：重新解码（也顺带解决「先失败后换封面」的粘性问题）。 */
  @Monitor('src')
  onSrcChanged(): void {
    this.pixelMap = undefined;
    void this.loadLocal();
  }

  /** 本地文件（沙箱 URI 或绝对路径）。 */
  private isLocalFile(): boolean {
    return this.src.startsWith('file://') || this.src.startsWith('/');
  }

  /** 把本地文件解码成 PixelMap（带缓存）。 */
  private async loadLocal(): Promise<void> {
    const url: string = this.src;
    if (url.length === 0 || !this.isLocalFile()) {
      return;
    }
    const cached: PixelMap | undefined = coverCache.get(url);
    if (cached !== undefined) {
      this.pixelMap = cached;
      return;
    }
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(url, fs.OpenMode.READ_ONLY);
      const source: image.ImageSource = image.createImageSource(file.fd);
      try {
        const decoded: PixelMap = await source.createPixelMap();
        if (coverCache.size >= CACHE_LIMIT) {
          coverCache.clear();
        }
        coverCache.set(url, decoded);
        this.pixelMap = decoded;
      } finally {
        source.release();
      }
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(DOMAIN, TAG, 'decode local cover failed: %{public}s', e.message ?? '');
      if (this.onFailed !== null) {
        this.onFailed();
      }
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (_err) {
        }
      }
    }
  }

  /** 解码中 / 失败时的灰底占位（不留白、不闪）。 */
  @Builder
  private Placeholder() {
    Column()
      .width(this.imageWidth)
      .height(this.imageHeight)
      .borderRadius(this.radius)
      .backgroundColor($r('sys.color.background_tertiary'))
  }

  build() {
    if (this.isLocalFile()) {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width(this.imageWidth)
          .height(this.imageHeight)
          .borderRadius(this.radius)
          .objectFit(this.fit)
          .draggable(false)
      } else {
        this.Placeholder()
      }
    } else if (this.src.length > 0) {
      Image(this.src)
        .width(this.imageWidth)
        .height(this.imageHeight)
        .borderRadius(this.radius)
        .objectFit(this.fit)
        .draggable(false)
        .onError(() => {
          if (this.onFailed !== null) {
            this.onFailed();
          }
        })
    } else {
      this.Placeholder()
    }
  }
}
