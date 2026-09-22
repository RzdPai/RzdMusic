/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';

/**
 * Builds the share text for a song: "title - singer" plus a deep link to the
 * source page when the source and id are known.
 * @param title Song title.
 * @param singer Artist line.
 * @param source Music source id ('tx'|'kg'|'kw'|'wy'|'mg').
 * @param songId Song id within the source.
 * @returns Full share text.
 */
export function buildSongShareText(title: string, singer: string, source: string, songId: string): string {
  let link: string = '';
  if (source === 'tx' && songId.length > 0) {
    link = 'https://y.qq.com/n/ryqq/songDetail/' + songId;
  } else if (source === 'kg' && songId.length > 0) {
    link = 'https://www.kugou.com/song/#hash=' + songId;
  } else if (source === 'kw' && songId.length > 0) {
    link = 'https://www.kuwo.cn/play_detail/' + songId;
  } else if (source === 'wy' && songId.length > 0) {
    link = 'https://music.163.com/#/song?id=' + songId;
  } else if (source === 'mg' && songId.length > 0) {
    link = 'https://music.migu.cn/v3/music/song/' + songId;
  }
  let text: string = title + ' - ' + singer;
  if (link.length > 0) {
    text = text + '\n' + link;
  }
  return text;
}

/**
 * Opens the system share panel with the given text content.
 * @param uiContext UIContext of the calling page (used to resolve the host context).
 * @param content Text content to share.
 * @param shareTitle Title shown in the share panel.
 */
export function showSystemShare(uiContext: UIContext | undefined, content: string, shareTitle: string): void {
  if (uiContext === undefined) {
    return;
  }
  try {
    const data = new systemShare.SharedData({
      utd: utd.UniformDataType.PLAIN_TEXT,
      content: content,
      title: shareTitle
    });
    const controller = new systemShare.ShareController(data);
    const context = uiContext.getHostContext() as common.UIAbilityContext;
    if (context === undefined) {
      return;
    }
    controller.show(context, {
      anchor: {
        windowOffset: { x: 0, y: 0 },
        size: { width: 0, height: 0 }
      }
    });
  } catch (_err) {
    // ignore: share panel unavailable
  }
}
