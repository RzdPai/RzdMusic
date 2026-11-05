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
 * 横屏背景：直接渲染 `resources/rawfile/cbg.html`。
 *
 * ★ 甲方口径（2026-10-25）：
 *   1. HTML 里原本那张**测试照片已经删掉**（`--cover` 现在是 `none`），结构/层叠全部保留；
 *   2. App 只做一件事 —— **传入封面**（设一次 `--cover`），不要逐元素改 `background-image`；
 *   3. 方形舞台做**居中 cover 裁剪**：`scale = max(vw,vh)/min(vw,vh)`，任意比例铺满不变形。
 */
@ComponentV2
export struct FeedBlurBackdrop {
  /** 当前这一屏的封面地址。 */
  @Param coverUrl: string = '';
  /**
   * 封面主色（`rgb(r, g, b)`）：HTML 里 `--solid` 是**那张测试图**的取色（默认 `#a0377b` 洋红），
   * 用在 `.bg .br` 等处 ⇒ 不传就会永远露一块紫色。这里用当前屏自己的主色覆盖它。
   */
  @Param solidColor: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  /** 上次已注入的封面（避免重复注入）。 */
  private applied: string = '';

  /** 传入封面 + 方形居中裁剪。 */
  private applyCover(): void {
    if (this.coverUrl.length === 0) {
      return;
    }
    const url: string = this.coverUrl;
    this.applied = url + '|' + this.solidColor;
    const solid: string = this.solidColor.length > 0 ? this.solidColor : '#00000000';
    const script: string =
      `(function(){` +
      `document.documentElement.style.setProperty('--cover',${JSON.stringify('url("' + url + '")')});` +
      `document.documentElement.style.setProperty('--solid',${JSON.stringify(solid)});` +
      `var d=document.documentElement,b=document.body;` +
      `d.style.overflow='hidden';b.style.overflow='hidden';b.style.margin='0';` +
      `var s=document.querySelector('.stage');` +
      `if(s){` +
      `var k=Math.max(window.innerWidth,window.innerHeight)/Math.min(window.innerWidth,window.innerHeight);` +
      // 裁剪锚点 = **上方**（甲方：从上方裁剪）：top 对齐、水平居中，超出部分裁在下方
      `s.style.position='fixed';s.style.left='50%';s.style.top='0';` +
      `s.style.width='100vmin';s.style.height='100vmin';` +
      `s.style.transformOrigin='top center';` +
      `s.style.transform='translateX(-50%) scale('+k+')';}` +
      `return 'ok';` +
      `})();`;
    this.controller.runJavaScript(script).then((ret: string): void => {
      Logger.info(TAG, `inject ok ret=${ret} urlLen=${url.length}`);
    }).catch((err: Error): void => {
      Logger.warn(TAG, `inject fail err=${err.message ?? ''}`);
    });
  }

  @Monitor('coverUrl', 'solidColor')
  onCoverChanged(): void {
    if ((this.coverUrl + '|' + this.solidColor) !== this.applied) {
      this.applied = '';
      this.applyCover();
    }
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
        this.applied = '';
        this.applyCover();
      })
  }
}