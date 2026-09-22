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
      await fileIo.write(file.fd, bytes);
      const previous: string = CardImageHelper.cachedPath;
      CardImageHelper.cachedUrl = url;
      CardImageHelper.cachedPath = path;
      if (previous.length > 0 && previous !== path) {
        CardImageHelper.unlink(previous);
      }
      CardImageHelper.keepFd(file.fd);
      return file.fd;
    } catch (_err) {
      return -1;
    }
  }

  private static openCached(): number {
    try {
      const file: fileIo.File = fileIo.openSync(CardImageHelper.cachedPath, fileIo.OpenMode.READ_ONLY);
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
