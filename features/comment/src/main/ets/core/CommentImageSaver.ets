/*
 * 评论图片保存到本地。
 *
 * 两条路，按「先相册、后文件」的顺序走：
 *
 *   1. **相册（免权限）**：`photoAccessHelper.showAssetsCreationDialog()` —— 系统弹一个保存对话框，
 *      用户确认后应用就拿到了这一张图的写入授权，全程不需要 `ohos.permission.WRITE_IMAGEVIDEO`
 *      （那是受限权限，普通应用申请不到）。所以先把图下到沙箱 cache，再拿 `fileUri.getUriFromPath()`
 *      得到的沙箱 URI 去唤起对话框，最后把字节写进返回的媒体库 URI。
 *   2. **文件（兜底）**：有些设备/发行版上没走通上面那条（对话框不支持、媒体库拒绝该格式等），
 *      就退回到 `DocumentViewPicker.save()`：同样是免权限方案，用户自己挑一个目录存下来。
 *      这条在本工程里是**已验证过的写法**（歌单导出 `PlaylistDetailPage.exportPlaylist`）。
 *
 * 两条都失败才返回失败，界面据此 toast。
 */

import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppRuntime } from 'musicbasic';
import { COMMENT_TAG } from './CommentHttp';

const DOMAIN: number = 0x0000;

/** 媒体库认得的图片后缀；其它一律按 jpg 处理（拼接 URL 传进来的多半是 jpg）。 */
const KNOWN_IMAGE_EXTENSIONS: string[] = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heif', 'heic'];

/** 保存结果：`ok` 为假时 `message` 直接给用户看。 */
export interface SaveImageResult {
  ok: boolean;
  message: string;
}

/** 从图片地址里猜后缀（去掉 query，认不出来给 jpg）。 */
function extensionOf(url: string): string {
  const noQuery: string = url.split('?')[0].split('#')[0];
  const dot: number = noQuery.lastIndexOf('.');
  if (dot < 0 || dot === noQuery.length - 1) {
    return 'jpg';
  }
  const ext: string = noQuery.substring(dot + 1).toLowerCase();
  return KNOWN_IMAGE_EXTENSIONS.indexOf(ext) >= 0 ? ext : 'jpg';
}

/** 下载图片字节（评论图都在 CDN 上，直接取原图）。 */
async function downloadImage(url: string): Promise<ArrayBuffer> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await req.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 15000,
      readTimeout: 30000
    });
    if (resp.responseCode !== 200 || resp.result === undefined) {
      throw new Error(`HTTP ${resp.responseCode}`);
    }
    return resp.result as ArrayBuffer;
  } finally {
    req.destroy();
  }
}

/** 把字节写进一个 file:// URI（媒体库返回的、或文件选择器返回的都走这里）。 */
function writeToUri(uri: string, data: ArrayBuffer): void {
  const file: fs.File = fs.openSync(uri, fs.OpenMode.WRITE_ONLY);
  try {
    fs.writeSync(file.fd, data);
  } finally {
    fs.closeSync(file);
  }
}

/** 沙箱里落一个临时文件（`showAssetsCreationDialog` 要的是沙箱文件 URI，不是字节）。 */
function writeTempFile(path: string, data: ArrayBuffer): void {
  const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, data);
  } finally {
    fs.closeSync(file);
  }
}

function deleteQuietly(path: string): void {
  try {
    fs.unlinkSync(path);
  } catch (_err) {
    // 临时文件删不掉不影响功能
  }
}

/** 走「相册」那条路；失败时抛错，由调用方决定是否退回文件选择器。 */
async function saveViaGallery(context: common.UIAbilityContext, tempPath: string,
  ext: string, title: string, data: ArrayBuffer): Promise<void> {
  const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
  const srcUri: string = fileUri.getUriFromPath(tempPath);
  const config: photoAccessHelper.PhotoCreationConfig = {
    title: title.length > 0 ? title : '评论图片',
    fileNameExtension: ext,
    photoType: photoAccessHelper.PhotoType.IMAGE,
    subtype: photoAccessHelper.PhotoSubtype.DEFAULT
  };
  const targets: string[] = await helper.showAssetsCreationDialog([srcUri], [config]);
  if (targets.length === 0 || targets[0].length === 0) {
    throw new Error('系统没有返回保存位置');
  }
  writeToUri(targets[0], data);
}

/** 兜底：让用户挑一个目录存（歌单导出同款做法）。 */
async function saveViaPicker(context: common.UIAbilityContext, ext: string, title: string,
  data: ArrayBuffer): Promise<boolean> {
  const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
  const safeTitle: string = (title.length > 0 ? title : 'comment').replace(/[\\/:*?"<>|]/g, '_');
  options.newFileNames = [`${safeTitle}_${Date.now()}.${ext}`];
  const uris: string[] = await docPicker.save(options);
  if (uris.length === 0 || uris[0].length === 0) {
    return false;  // 用户取消
  }
  writeToUri(uris[0], data);
  return true;
}

/**
 * 把一张评论图片保存到本地（优先存进相册，其次让用户挑目录）。
 *
 * @param url 图片地址（评论接口给的原始 URL）。
 * @param title 保存时的文件名（一般传歌名，便于在相册里认出来）。
 * @returns 结果与给用户看的文案。
 */
export async function saveImageToLocal(url: string, title: string): Promise<SaveImageResult> {
  if (url.length === 0) {
    return { ok: false, message: '这张图没有地址，保存不了' };
  }
  const context: common.UIAbilityContext | undefined = getAppRuntime().context;
  if (context === undefined) {
    return { ok: false, message: '保存失败：拿不到应用上下文' };
  }
  const ext: string = extensionOf(url);
  const tempPath: string = `${context.cacheDir}/comment_img_${Date.now()}.${ext}`;
  let data: ArrayBuffer;
  try {
    data = await downloadImage(url);
  } catch (err) {
    const e: Error = err as Error;
    hilog.warn(DOMAIN, COMMENT_TAG, 'download comment image failed: %{public}s', e.message ?? '');
    return { ok: false, message: '图片下载失败，检查一下网络' };
  }
  try {
    writeTempFile(tempPath, data);
  } catch (err) {
    const e: Error = err as Error;
    hilog.warn(DOMAIN, COMMENT_TAG, 'write temp image failed: %{public}s', e.message ?? '');
    return { ok: false, message: '保存失败：写临时文件出错' };
  }
  try {
    try {
      await saveViaGallery(context, tempPath, ext, title, data);
      hilog.info(DOMAIN, COMMENT_TAG, 'comment image saved to gallery ext=%{public}s', ext);
      return { ok: true, message: '已保存到相册' };
    } catch (err) {
      const e: Error = err as Error;
      // 相册那条走不通（常见于模拟器/部分发行版不支持保存对话框）就退回文件选择器
      hilog.warn(DOMAIN, COMMENT_TAG, 'gallery save failed, fallback to picker: %{public}s', e.message ?? '');
      const saved: boolean = await saveViaPicker(context, ext, title, data);
      if (saved) {
        return { ok: true, message: '已保存' };
      }
      return { ok: false, message: '已取消保存' };
    }
  } catch (err) {
    const e: Error = err as Error;
    hilog.warn(DOMAIN, COMMENT_TAG, 'save comment image failed: %{public}s', e.message ?? '');
    return { ok: false, message: '保存失败：' + (e.message ?? '未知错误') };
  } finally {
    deleteQuietly(tempPath);
  }
}
