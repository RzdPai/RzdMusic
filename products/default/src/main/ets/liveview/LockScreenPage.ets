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

import { commonEventManager, BusinessError } from '@kit.BasicServicesKit';
import { LiveViewConst, Logger } from 'musicbasic';
import { LiveViewLyricPayload } from 'player';

const TAG = 'LockScreenPage';

/**
 * Lock screen immersive live view page (锁屏沉浸实况窗歌词页).
 * Rendered by LiveViewExtAbility in an independent process. Reads the initial
 * payload from the LocalStorage seeded by the ability, then keeps in sync via
 * common events published by the app process.
 */
@Entry({ useSharedStorage: true })
@ComponentV2
struct LockScreenPage {
  /** Song title. */
  @Local title: string = '';
  /** Artist name. */
  @Local artist: string = '';
  /** Current lyric line. */
  @Local curLine: string = '';
  /** Next lyric line. */
  @Local nextLine: string = '';
  /** Whether audio is playing. */
  @Local isPlaying: boolean = true;
  /** Common event subscriber; unsubscribed on page exit. */
  private subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;

  aboutToAppear(): void {
    this.loadInitialData();
    this.subscribeLyricEvent();
  }

  aboutToDisappear(): void {
    this.unsubscribeLyricEvent();
  }

  /** Reads the initial payload from the LocalStorage passed by the ability. */
  private loadInitialData(): void {
    try {
      const storage: LocalStorage | undefined = this.getUIContext().getSharedLocalStorage();
      if (storage === undefined) {
        return;
      }
      const raw: string | undefined = storage.get<string>(LiveViewConst.LS_INIT_DATA_KEY);
      if (raw !== undefined && raw.length > 0) {
        this.applyPayload(JSON.parse(raw) as LiveViewLyricPayload);
      }
    } catch (_err) {
      Logger.warn(TAG, 'loadInitialData failed');
    }
  }

  /** Applies a lyric payload to the page state. */
  private applyPayload(payload: LiveViewLyricPayload): void {
    this.title = payload.title;
    this.artist = payload.artist;
    this.curLine = payload.curLine;
    this.nextLine = payload.nextLine;
    this.isPlaying = payload.isPlaying;
  }

  /** Subscribes to lyric update events from the app process. */
  private subscribeLyricEvent(): void {
    try {
      const info: commonEventManager.CommonEventSubscribeInfo = {
        events: [LiveViewConst.LIVE_VIEW_LYRIC_EVENT]
      };
      commonEventManager.createSubscriber(info).then((sub: commonEventManager.CommonEventSubscriber) => {
        this.subscriber = sub;
        sub.on('receive', (event: commonEventManager.CommonEventData): void => {
          const data: string | undefined = event.data;
          if (data !== undefined && data.length > 0) {
            try {
              this.applyPayload(JSON.parse(data) as LiveViewLyricPayload);
            } catch (_err) {
              Logger.warn(TAG, 'parse payload failed');
            }
          }
        });
      }).catch((err: BusinessError): void => {
        Logger.warn(TAG, 'createSubscriber failed: ' + err.code + ' ' + err.message);
      });
    } catch (_err) {
      Logger.warn(TAG, 'subscribeLyricEvent error');
    }
  }

  /** Unsubscribes from lyric update events. */
  private unsubscribeLyricEvent(): void {
    const sub: commonEventManager.CommonEventSubscriber | undefined = this.subscriber;
    this.subscriber = undefined;
    if (sub === undefined) {
      return;
    }
    try {
      sub.off('receive');
    } catch (_err) {
      // best effort
    }
    try {
      commonEventManager.unsubscribe(sub);
    } catch (_err) {
      // best effort
    }
  }

  build() {
    Stack() {
      Column({ space: 24 }) {
        Column({ space: 8 }) {
          Text(this.title)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.artist)
            .fontSize(16)
            .fontColor('#99FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 16 }) {
          Text(this.curLine.length > 0 ? this.curLine : '暂无歌词')
            .fontSize(32)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
          Text(this.nextLine)
            .fontSize(20)
            .fontColor('#66FFFFFF')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
        }
        .width('100%')

        Text(this.isPlaying ? '正在播放' : '已暂停')
          .fontSize(14)
          .fontColor('#99FFFFFF')
      }
      .width('100%')
      .padding({ left: 32, right: 32, top: 48, bottom: 48 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#E6000000')
  }
}
