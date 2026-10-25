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
 * ★ 那份 HTML 的结构（甲方调好的效果，别改）：
 *   `.stage > .bg(含 4 个镜像 .tile) + .hero.l2/.l1/.l0`，各自 `background-image: var(--cover)`。
 * ★ 它里面**塞了一张测试用的默认照片**（甲方自己说的），必须换成当前歌曲封面：
 *   这里在页面加载完后做两件事 ——
 *   ① 把 `--cover` 与所有 `.bg / .tile / .hero` 的 `background-image` 直接改成当前封面
 *      （逐元素改，避免某些内核版本对 CSS 变量继承的差异）；
 *   ② 方形舞台做**居中 cover 裁剪**（`scale = max(vw,vh)/min(vw,vh)`），任意比例都铺满不变形。
 */
@ComponentV2
export struct FeedBlurBackdrop {
  /** 当前这一屏的封面（空串 = 保留 HTML 里的默认图，仅用于调试）。 */
  @Param coverUrl: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  /** 上次注入过的封面（避免重复注入）。 */
  private applied: string = '';

  /** 注入封面 + 方形居中裁剪。 */
  private applyBackdrop(): void {
    if (this.coverUrl.length === 0) {
      return;
    }
    const url: string = this.coverUrl;
    this.applied = url;
    const script: string =
      `(function(){` +
      `var u=${JSON.stringify('url("' + url + '")')};` +
      `document.documentElement.style.setProperty('--cover',u);` +
      `var els=document.querySelectorAll('.bg,.tile,.hero');` +
      `for(var i=0;i<els.length;i++){els[i].style.backgroundImage=u;}` +
      `var d=document.documentElement,b=document.body;` +
      `d.style.overflow='hidden';b.style.overflow='hidden';b.style.margin='0';` +
      `var s=document.querySelector('.stage');` +
      `if(s){` +
      `var k=Math.max(window.innerWidth,window.innerHeight)/Math.min(window.innerWidth,window.innerHeight);` +
      `s.style.position='fixed';s.style.left='50%';s.style.top='50%';` +
      `s.style.width='100vmin';s.style.height='100vmin';` +
      `s.style.transformOrigin='center center';` +
      `s.style.transform='translate(-50%,-50%) scale('+k+')';}` +
      `return 'els='+els.length;` +
      `})();`;
    this.controller.runJavaScript(script).then((ret: string): void => {
      Logger.info(TAG, `backdrop applied ${ret} urlLen=${url.length}`);
    }).catch((err: Error): void => {
      Logger.warn(TAG, `backdrop inject failed: ${err.message ?? ''}`);
    });
  }

  @Monitor('coverUrl')
  onCoverChanged(): void {
    if (this.coverUrl !== this.applied) {
      this.applied = '';
      this.applyBackdrop();
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
        Logger.info(TAG, 'page end, inject cover + crop');
        this.applied = '';
        this.applyBackdrop();
      })
  }
}