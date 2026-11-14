/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源脚本文件分享（用户 2026-11-01：左滑「分享」分享的是脚本文件本身）。
 *
 * ★ 为什么放在独立 util 而不是组件事件里：之前用 `@Event onShare` 从 SettingPage 转发，
 *   实测"左滑点击有日志、转发后无日志"，说明跨组件的 @Event 没接上（或实例不是同一个）。
 *   改成 **左滑动作里直接调用本函数**，不再经过事件中转，链路只有一次跳转。
 *
 * 官方依据（HarmonyOS 文档《分享数据创建及分享面板拉起》）：
 * `ShareController.show(context, options)` 返回 Promise，必须 then/catch，否则失败时"静默无反应"。
 *
 * 排查日志关键字：`[RzdSourceShare]`。
 */

import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { appendPlayLog } from 'musicbasic';
import { LXUserApiInfo, lxSourceManager } from 'player';

/**
 * 把音源脚本导出成 cache 里的 `<音源名>_v<版本>.js` 并拉起系统分享面板。
 * @param ctx UIAbility 上下文（组件里用 `this.getUIContext().getHostContext()` 取）
 * @param api 音源信息
 */
export async function shareSourceScript(ctx: common.UIAbilityContext, api: LXUserApiInfo): Promise<void> {
  appendPlayLog('[RzdSourceShare] start id=' + api.id + ' name=' + api.name);
  try {
    const raw: string = await lxSourceManager.getScript(api.id);
    appendPlayLog('[RzdSourceShare] script len=' + raw.length);
    if (raw.length === 0) {
      return;
    }
    const bad: RegExp = new RegExp('[\\\\/:*?"<>|]', 'g');
    const safeName: string = (api.name.length > 0 ? api.name : 'source').replace(bad, '_');
    const ver: string = api.version.length > 0 ? ('_v' + api.version.replace(bad, '_')) : '';
    const fileName: string = safeName + ver + '.js';
    const path: string = ctx.cacheDir + '/' + fileName;
    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, raw);
    fs.closeSync(file);
    const uri: string = fileUri.getUriFromPath(path);
    appendPlayLog('[RzdSourceShare] file=' + fileName + ' uri=' + uri);
    try {
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        uri: uri,
        title: fileName
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      await controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
      appendPlayLog('[RzdSourceShare] sharekit ok');
      return;
    } catch (e1) {
      appendPlayLog('[RzdSourceShare] sharekit failed ' + JSON.stringify(e1).substring(0, 160));
    }
    const want: Want = {
      action: 'ohos.want.action.sendData',
      uri: uri,
      type: 'text/plain',
      flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
    };
    await ctx.startAbility(want);
    appendPlayLog('[RzdSourceShare] sendData ok');
  } catch (err) {
    appendPlayLog('[RzdSourceShare] failed ' + JSON.stringify(err).substring(0, 160));
  }
}
