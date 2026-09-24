import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';

export class CardImageHelper {
  private static readonly openFds: number[] = [];
  private static cachedUrl: string = '';
  private static cachedPath: string = '';

  static async prepareCover(tempDir: string, url: string, imageName: string): Promise<number> {
    if (url.length === 0) {
      return -1;
    }
    // ★ 本地音乐 / 自定义歌单封面的 cover 是**沙箱文件 URI**（file://...），
    //   拿 http 去下必然失败 —— 那就是「本地歌在桌面卡片上没有封面」的原因。
    //   这种直接以只读方式打开，把 fd 交给卡片（不需要再拷一份）。
    if (url.startsWith('file://') || url.startsWith('/')) {
      const localFd: number = CardImageHelper.openReadOnly(url);
      if (localFd >= 0) {
        CardImageHelper.cachedUrl = url;
        CardImageHelper.cachedPath = '';   // 不是缓存文件，别在下次换图时去 unlink 它
      }
      return localFd;
    }
    if (url === CardImageHelper.cachedUrl && CardImageHelper.exists(CardImageHelper.cachedPath)) {
      return CardImageHelper.openCached();
    }
    const bytes: ArrayBuffer | undefined = await CardImageHelper.download(url);
    if (bytes === undefined) {
      return CardImageHelper.exists(CardImageHelper.cachedPath) ? CardImageHelper.openCached() : -1;
    }
    const path: string = tempDir + '/' + imageName + '.img';
    try {
      const file: fileIo.File = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(file.fd, bytes);
      } finally {
        fileIo.closeSync(file);
      }
      const previous: string = CardImageHelper.cachedPath;
      CardImageHelper.cachedUrl = url;
      CardImageHelper.cachedPath = path;
      if (previous.length > 0 && previous !== path) {
        CardImageHelper.unlink(previous);
      }
      // ★ 交给卡片的必须是**只读、偏移在 0** 的 fd（官方样例就是 `openSync(path, READ_ONLY)`
      //   之后把 fd 塞进 formImages）。之前直接复用刚写完的那个读写 fd：写入偏移停在文件末尾，
      //   系统读图时有概率读到 0 字节 —— 表现就是「换歌后卡片封面第一下是空的」。
      return CardImageHelper.openCached();
    } catch (_err) {
      return -1;
    }
  }

  private static openCached(): number {
    return CardImageHelper.openReadOnly(CardImageHelper.cachedPath);
  }

  /** 以只读方式打开并把 fd 记进「保活列表」（交给卡片的 fd 必须只读、偏移在 0）。 */
  private static openReadOnly(path: string): number {
    if (path.length === 0) {
      return -1;
    }
    try {
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      CardImageHelper.keepFd(file.fd);
      return file.fd;
    } catch (_err) {
      return -1;
    }
  }

  private static async download(url: string): Promise<ArrayBuffer | undefined> {
    const request = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'Mozilla/5.0' },
        connectTimeout: 8000,
        readTimeout: 8000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (response.responseCode === 200 && response.result !== undefined) {
        return response.result as ArrayBuffer;
      }
      return undefined;
    } catch (_err) {
      return undefined;
    } finally {
      request.destroy();
    }
  }

  private static exists(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      fileIo.accessSync(path);
      return true;
    } catch (_err) {
      return false;
    }
  }

  private static keepFd(fd: number): void {
    CardImageHelper.openFds.push(fd);
    while (CardImageHelper.openFds.length > 8) {
      const oldest: number = CardImageHelper.openFds.shift() as number;
      try {
        fileIo.closeSync(oldest);
      } catch (_err) {
      }
    }
  }

  private static unlink(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (_err) {
    }
  }
}
