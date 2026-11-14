import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { importMusicFreeSubscriptionText, importSourceScriptAuto, parseMusicFreeSubscription } from 'player';

/** 从文件 uri 里取文件名（去掉扩展名），当作订阅名。 */
function fileNameOf(uri: string): string {
  const raw: string = uri.split('/').pop() ?? '';
  const dot: number = raw.lastIndexOf('.');
  const name: string = dot > 0 ? raw.substring(0, dot) : raw;
  return name.length > 0 ? name : 'MusicFree 订阅';
}

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
      // 本地文件可能是：LX 脚本 / MusicFree 插件 / MusicFree 订阅 JSON
      const entries = script.trimStart().startsWith('{') ? parseMusicFreeSubscription(script) : [];
      if (entries.length > 0) {
        // ★ 2026-11-09：订阅整包交给适配层 —— 这样才能建出「订阅」这一层记录
        //   （源管理按订阅分组、之后整包更新），而不是散落成一堆无归属的插件。
        const report = await importMusicFreeSubscriptionText(script, '', fileNameOf(uris[index]));
        if (report.ok) {
          success++;
        } else {
          failures.push(fileNameOf(uris[index]) + '：' + report.message);
        }
        if (report.failed > 0) {
          failures.push('订阅内 ' + report.failed.toString() + ' 个插件失败');
        }
        continue;
      }
      await importSourceScriptAuto(script, '');
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
