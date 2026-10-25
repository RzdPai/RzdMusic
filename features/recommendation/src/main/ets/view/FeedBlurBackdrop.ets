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

import { webview } from '@kit.ArkWeb';
import { Logger } from 'musicbasic';

const TAG: string = 'RzdFeedBlur';

/**
 * 背景渲染器：直接把 `resources/rawfile/cbg.html` 渲染出来。
 *
 * ★ 甲方 2026-10-25 的明确口径：
 *   1. 那份 HTML **自带封面**（内部已经渲染好），我们**不要**再传 `--cover`、也不要再画一次封面；
 *   2. 它的舞台是**正方形**（甲方刻意这么设计：方形源裁成任意比例都不会形变）；
 *      ⇒ 这里只需在页面加载完后注入一段 CSS 做**居中 cover 裁剪**：
 *      `--s = max(vw, vh) / min(vw, vh)`，`.stage { transform: translate(-50%,-50%) scale(--s) }`，
 *      于是 16:9 / 4:3 / 平板阔屏都能铺满且不变形。
 */
@ComponentV2
export struct FeedBlurBackdrop {
  private controller: webview.WebviewController = new webview.WebviewController();

  /** 覆盖满整块背景：居中 + scale 到短边铺满（等价 CSS 的 `object-fit: cover`）。 */
  private applyCoverCrop(): void {
    const script: string =
      `(function(){` +
      `var d=document.documentElement,b=document.body;` +
      `d.style.overflow='hidden';b.style.overflow='hidden';b.style.margin='0';` +
      `var s=document.querySelector('.stage')||b.firstElementChild;` +
      `if(!s){return 'no-stage';}` +
      `var k=Math.max(window.innerWidth,window.innerHeight)/Math.min(window.innerWidth,window.innerHeight);` +
      `s.style.position='fixed';` +
      `s.style.left='50%';s.style.top='50%';` +
      `s.style.width='100vmin';s.style.height='100vmin';` +
      `s.style.transformOrigin='center center';` +
      `s.style.transform='translate(-50%,-50%) scale('+k+')';` +
      `return 'scale='+k.toFixed(3);` +
      `})();`;
    this.controller.runJavaScript(script).then((ret: string): void => {
      Logger.info(TAG, `cover crop applied ${ret}`);
    }).catch((err: Error): void => {
      Logger.warn(TAG, `cover crop failed: ${err.message ?? ''}`);
    });
  }

  build() {
    Web({ src: $rawfile('cbg.html'), controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(false)
      .fileAccess(false)
      .imageAccess(true)
      .zoomAccess(false)
      .horizontalScrollBarAccess(false)
      .verticalScrollBarAccess(false)
      .width('100%')
      .height('100%')
      // 纯背景：不吃触摸，滑动与点击都交给上层
      .hitTestBehavior(HitTestMode.None)
      .onPageEnd((): void => {
        Logger.info(TAG, 'page end, apply cover crop');
        this.applyCoverCrop();
      })
  }
}