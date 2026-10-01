/*
 * 歌单自定义封面：从相册选一张图，拷进应用沙箱，返回可直接喂给 `Image()` 的 URI。
 *
 * 为什么必须拷进沙箱：相册选出来的是临时授权 URI（`file://media/...`），
 * 授权只在本次会话有效，重启后 `Image()` 会读不到 —— 歌单封面要长期显示，
 * 所以自己存一份（与本地音乐的封面落盘同一套做法，见 features/localmusic 的 getCoverUri）。
 *
 * 免权限：只用 `picker.PhotoViewPicker`（系统选择器），不需要读媒体库权限。
 */

import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Logger, getAppRuntime } from 'musicbasic';

const TAG: string = 'PlaylistCover';

/** 沙箱里存歌单封面的目录（相对 filesDir）。 */
const COVER_DIR_NAME: string = 'playlist_covers';

/** 认得出的图片后缀；认不出来按 jpg 存（解码看内容，后缀只影响文件名）。 */
const KNOWN_EXTENSIONS: string[] = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heif', 'heic'];

/** 选图结果。 */
export interface CoverPickResult {
  /** 是否成功选到并落盘。 */
  ok: boolean;
  /** 沙箱文件的 URI（`file://...`），失败时为空串。 */
  uri: string;
  /** 给用户看的文案。 */
  message: string;
}

/** 从相册 URI 里猜后缀（认不出来给 jpg）。 */
function extensionOf(uri: string): string {
  const noQuery: string = uri.split('?')[0];
  const dot: number = noQuery.lastIndexOf('.');
  if (dot < 0 || dot === noQuery.length - 1) {
    return 'jpg';
  }
  const ext: string = noQuery.substring(dot + 1).toLowerCase();
  return KNOWN_EXTENSIONS.indexOf(ext) >= 0 ? ext : 'jpg';
}

/** 确保封面目录存在。 */
function ensureCoverDir(dir: string): void {
  try {
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
  } catch (_err) {
    // 已存在会抛，忽略
  }
}

/** 整文件复制（改动后的封面要长期留在沙箱，不能用 picker 的临时授权 URI）。 */
function copyToSandbox(srcUri: string, destPath: string): void {
  const src: fs.File = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
  try {
    const dest: fs.File = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      const buffer: ArrayBuffer = new ArrayBuffer(64 * 1024);
      let read: number = fs.readSync(src.fd, buffer);
      while (read > 0) {
        fs.writeSync(dest.fd, buffer, { length: read });
        read = fs.readSync(src.fd, buffer);
      }
    } finally {
      fs.closeSync(dest);
    }
  } finally {
    fs.closeSync(src);
  }
}

/**
 * 让用户选一张图作为歌单封面，并把它拷进沙箱。
 *
 * @param playlistId 歌单 id（文件名里带上，便于排查与清理）。
 * @returns 结果与可以长期使用的沙箱 URI。
 */
export async function pickPlaylistCover(playlistId: string): Promise<CoverPickResult> {
  const context: common.UIAbilityContext | undefined = getAppRuntime().context;
  if (context === undefined) {
    return { ok: false, uri: '', message: '选择失败：拿不到应用上下文' };
  }
  let picked: string[] = [];
  try {
    const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker(context);
    const options: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result: picker.PhotoSelectResult = await photoPicker.select(options);
    picked = result.photoUris;
  } catch (err) {
    const e: Error = err as Error;
    // 用户取消也会走到这里（不同版本行为不一致），统一按「没选」处理
    Logger.warn(TAG, `pick cover cancelled or failed: ${e.message ?? ''}`);
    return { ok: false, uri: '', message: '没有选择图片' };
  }
  if (picked.length === 0 || picked[0].length === 0) {
    return { ok: false, uri: '', message: '没有选择图片' };
  }
  const srcUri: string = picked[0];
  const dir: string = `${context.filesDir}/${COVER_DIR_NAME}`;
  ensureCoverDir(dir);
  const ext: string = extensionOf(srcUri);
  const destPath: string = `${dir}/${playlistId}_${Date.now()}.${ext}`;
  try {
    copyToSandbox(srcUri, destPath);
  } catch (err) {
    const e: Error = err as Error;
    Logger.error(TAG, `copy cover failed: ${e.message ?? ''}`);
    return { ok: false, uri: '', message: '保存封面失败' };
  }
  // 复核一遍：写完之后必须真的能读、且非空 —— 否则界面拿到一个读不到的地址，
  // 表现就是「设置了封面但没生效」（这种失败要在这里就报出来，而不是留给用户猜）。
  try {
    if (!fs.accessSync(destPath)) {
      return { ok: false, uri: '', message: '保存封面失败：文件没写成功' };
    }
    const size: number = fs.statSync(destPath).size;
    if (size <= 0) {
      return { ok: false, uri: '', message: '保存封面失败：图片是空的' };
    }
    Logger.info(TAG, `cover file ok, ${size} bytes`);
  } catch (err) {
    const e: Error = err as Error;
    Logger.error(TAG, `verify cover failed: ${e.message ?? ''}`);
    return { ok: false, uri: '', message: '保存封面失败：文件校验不通过' };
  }
  const uri: string = fileUri.getUriFromPath(destPath);
  Logger.info(TAG, `playlist cover saved: ${uri}`);
  return { ok: true, uri: uri, message: '已设置歌单封面' };
}
