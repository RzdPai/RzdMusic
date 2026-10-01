import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { lxSourceManager } from 'player';

export async function importSourceFiles(context: common.Context): Promise<string> {
  const options = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 100;
  const uris: string[] = await new picker.DocumentViewPicker(context).select(options);
  if (uris.length === 0) {
    return '';
  }
  let success: number = 0;
  const failures: string[] = [];
  for (let index: number = 0; index < uris.length; index++) {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(uris[index], fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(file.fd).size;
      if (size <= 0 || size > 9 * 1024 * 1024) {
        throw new Error('文件为空或超过9MB');
      }
      const buffer = new ArrayBuffer(size);
      const read: number = fs.readSync(file.fd, buffer);
      if (read !== size) {
        throw new Error('文件读取不完整');
      }
      const script = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buffer));
      const result = lxSourceManager.importApi(script);
      if (!result.ok) {
        throw new Error(result.message);
      }
      success++;
      console.info('[RzdSourceImport] file=' + (index + 1) + ' success');
    } catch (error) {
      failures.push('第' + (index + 1) + '个：' + (error as Error).message);
      console.warn('[RzdSourceImport] file=' + (index + 1) + ' failed');
    } finally {
      if (file !== undefined) {
        fs.closeSync(file);
      }
    }
  }
  return '已导入 ' + success + '/' + uris.length + ' 个音源' +
    (failures.length > 0 ? '\n' + failures.join('\n') : '');
}
