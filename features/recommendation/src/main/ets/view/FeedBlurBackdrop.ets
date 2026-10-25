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
 * 横屏（及需要时）用的**封面高斯模糊背景**：直接渲染甲方调好的
 * `resources/rawfile/cover_blur_background.html`，只把 `--cover` 换成当前封面。
 *
 * ★ 为什么用 Web 而不是 ArkUI 复刻（甲方 2026-10-25：「不是让你用 ArkUI 重写，是直接渲染这个 html」）：
 *   那份 HTML 里是"封面 cover 裁剪 + 多层不同模糊半径 + 镜像边缘 tile + mask 羽化"的组合，
 *   ArkUI 属性画不出同样效果；直接把 HTML 渲染出来最省事、也最贴近他调好的成品。
 * ★ 只对**当前可见的两张卡**各挂一个实例（Swiper 的 cachedCount = 1），不做常驻。
 */
@ComponentV2
export struct FeedBlurBackdrop {
  /** 这一屏的封面地址（空串 = 不加载，回落到底色）。 */
  @Param coverUrl: string = '';
  /** 控制器必须每个实例独立，不能共享。 */
  private controller: webview.WebviewController = new webview.WebviewController();
  private lastApplied: string = '';

  /** 页面加载完成（以及封面变了）时把 `--cover` 注入进去。 */
  private applyCover(): void {
    if (this.coverUrl.length === 0 || this.coverUrl === this.lastApplied) {
      return;
    }
    this.lastApplied = this.coverUrl;
    const script: string = `document.documentElement.style.setProperty('--cover','url("${this.coverUrl}")');`;
    this.controller.runJavaScript(script).then((): void => {
      Logger.info(TAG, `cover applied len=${this.coverUrl.length}`);
    }).catch((err: Error): void => {
      Logger.warn(TAG, `cover inject failed: ${err.message ?? ''}`);
    });
  }

  @Monitor('coverUrl')
  onCoverChanged(): void {
    this.applyCover();
  }

  build() {
    Web({ src: $rawfile('cover_blur_background.html'), controller: this.controller })
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
        Logger.info(TAG, `page end, inject cover len=${this.coverUrl.length}`);
        this.lastApplied = '';
        this.applyCover();
      })
  }
}