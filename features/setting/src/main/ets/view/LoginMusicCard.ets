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

/*
 * 「我的」页顶部的账号卡 = **原本那个大设置页**（`SettingPage`）顶上那张「登录音乐」大卡片。
 *
 * ★ 用户 2026-10-11 明确：我的页顶部那张卡**不是**同步设置页里那张（那是华为账号 + 云备份），
 *   而是**我们原本整个大设置页顶上那张「登录音乐」**的样式 —— 所以这里做的是**原样抽取**，
 *   不是重新设计：
 *
 *   | 本文件 | 原来的位置 |
 *   | --- | --- |
 *   | `build()` 里那一整块 | `SettingPage.ets` 的 `LoginAccountCard()`（原文件倒数第二个 Builder） |
 *   | 64vp 圆头像 / 昵称 20fp / 副标题 12fp / chevron 20 / 行高 80 / 圆角 16 / padding 8·12 | 逐字照抄，一个数值都没改 |
 *   | 卡面 `app.color.comp_background_list_card` + `sys.float.corner_radius_level16` | 逐字照抄 |
 *
 * ★ 与原件的三处**有意**差异（都是"离开设置页"这一语境下才成立，逐条写清）：
 *   1. 原件的 `if (this.rowVisible('登录音乐', …))` 是**设置页顶部搜索框**的过滤条件；
 *      我的页没有搜索框 ⇒ 该条件恒为真 ⇒ 这里直接渲染，不留一个永远为真的判断。
 *   2. 原件的行底色 / 标题色带 `this.selectedIndex === 2 ? … : …` —— 那是"宽屏设置页右栏
 *      选中态"的高亮。我的页没有右栏、没有选中态 ⇒ 恒走 else 分支
 *      （`Color.Transparent` + `sys.color.font_primary`），也就是设置页上**未选中**时那一版观感。
 *   3. 点击行为：原件走 `openSettingSheet(2)`（宽屏切右栏 / 窄屏推 `SettingsDetailPage`）。
 *      我的页没有设置页那套弹窗状态机 ⇒ 这里**直接弹出** `AccountManageSheet`，
 *      用的就是原位那个面板本身（`SettingSheetBuilder` 的 case 2 渲染的是同一个组件、
 *      同一份实现，sheet 高度 620 也与那儿逐字相同），**没有第二份账号面板**。
 *
 * ★ 取色口径（用户明确：我的页取色不能照搬参考工程 —— 我们有自定义主题色）：
 *   卡面 / 文字 / 图标全部走 `$r('app.color.*')` / `$r('sys.color.*')`，深浅色由 HDS 色板
 *   自动适配，**没有任何写死的十六进制**；这张卡里也没有强调色元素（原件那张卡就没有），
 *   所以不涉及 `ThemeState.color`，用户改主题色时这一页不需要额外的重绘路径。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LocalCoverImage } from 'musicbasic';
import { HuaweiAccountService, HuaweiAccountState, PlayerConstants } from 'player';
import { AccountManageSheet } from '../account/AccountManageSheet';

/** 卡片圆角（与原来那张卡逐字一致）。 */
const ACCOUNT_CARD_RADIUS: number = 16;
/** 卡片行高（与原来那张卡逐字一致：80）。 */
const ACCOUNT_CARD_HEIGHT: number = 80;
/** 头像边长（与原来那张卡逐字一致：64，圆形即 radius 32）。 */
const ACCOUNT_AVATAR_SIZE: number = 64;
/** 平台账号弹窗高度（与 `SettingPage` 里 activeSettingSheet === 2 那一档逐字一致）。 */
const ACCOUNT_SHEET_HEIGHT: number = 620;
/** 日志域与标签（真机排查：`hdc shell hilog | findstr RzdMineAccount`）。 */
const DOMAIN: number = 0x0000;
const TAG: string = 'RzdMineAccount';

/**
 * 「登录音乐」账号卡（未登录时是"登录音乐"大卡；登录华为账号后显示头像 + 昵称）。
 *
 * 放在「我的」页最上面（见 `MinePage` 的 ① 账号卡），**不再**出现在设置页里。
 */
@ComponentV2
export struct LoginMusicCard {
  /**
   * 华为账号登录态：登录过之后这张卡要显示头像与昵称。
   *
   * 与 `SettingPage` 连的是**同一个** AppStorageV2 键（`PlayerConstants.HUAWEI_ACCOUNT_STATE`），
   * 所以两边看到的是同一份状态，不存在两份登录态。
   */
  @Local huaweiState: HuaweiAccountState =
    AppStorageV2.connect(HuaweiAccountState, PlayerConstants.HUAWEI_ACCOUNT_STATE,
      () => new HuaweiAccountState())!;
  /** 平台账号弹窗（`AccountManageSheet`）的开合。 */
  @Local sheetOpen: boolean = false;

  aboutToAppear(): void {
    // 与 `SettingPage.aboutToAppear()` 里那一句同源：静默恢复上次的华为账号登录态，
    // 否则冷启动进来这张卡会先显示"未登录"再跳成头像+昵称
    HuaweiAccountService.getInstance().restore();
    hilog.info(DOMAIN, TAG, 'login music card appear signedIn=%{public}s',
      String(this.huaweiState.signedIn));
  }

  /** 点击这张卡：弹出平台账号面板（扫码 / Cookie 登录、华为账号、各平台账号管理都在里面）。 */
  private openAccountSheet(): void {
    this.sheetOpen = true;
    hilog.info(DOMAIN, TAG, 'open AccountManageSheet');
  }

  /** 平台账号面板的内容（与 `SettingPage.SettingSheetBuilder()` 的 case 2 是同一个组件）。 */
  @Builder
  private AccountSheetContent() {
    Column() {
      AccountManageSheet({
        onClose: (): void => {
          this.sheetOpen = false;
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        // 登录过华为账号：图标与文字都换成华为账号的头像 / 昵称
        if (this.huaweiState.signedIn) {
          if (this.huaweiState.avatarUri.length > 0) {
            // 头像可能已经是沙箱本地图（Account Kit 那条路会先落盘）：走 LocalCoverImage
            LocalCoverImage({
              src: this.huaweiState.avatarUri,
              imageWidth: ACCOUNT_AVATAR_SIZE,
              imageHeight: ACCOUNT_AVATAR_SIZE,
              radius: ACCOUNT_AVATAR_SIZE / 2,
              fit: ImageFit.Cover
            })
          } else {
            Column() {
              SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
                .fontSize(ACCOUNT_AVATAR_SIZE)
                .fontWeight(FontWeight.Regular)
                .height(ACCOUNT_AVATAR_SIZE)
                .fontColor([$r('sys.color.font_tertiary')])
            }
            .width(ACCOUNT_AVATAR_SIZE)
            .height(ACCOUNT_AVATAR_SIZE)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
              .fontSize(ACCOUNT_AVATAR_SIZE)
              .fontWeight(FontWeight.Regular)
              .height(ACCOUNT_AVATAR_SIZE)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width(ACCOUNT_AVATAR_SIZE)
          .height(ACCOUNT_AVATAR_SIZE)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        Column({ space: 2 }) {
          Text(this.huaweiState.signedIn ?
            (this.huaweiState.nickName.length > 0 ? this.huaweiState.nickName : '华为账号') : '登录音乐')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.huaweiState.signedIn ?
            '已登录华为账号 · 网易云 / QQ / 酷狗账号在这里管理' :
            '网易云 / QQ / 酷狗账号，扫码或 Cookie 登录')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontWeight(FontWeight.Regular)
          .height(20)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .height(ACCOUNT_CARD_HEIGHT)
      .borderRadius(ACCOUNT_CARD_RADIUS)
      .padding({ left: 8, right: 12 })
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.openAccountSheet();
      })
      .accessibilityText(this.huaweiState.signedIn ? '账号管理' : '登录音乐')
      .accessibilityLevel('yes')
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    // ★ 与「我的」页其它卡片（快捷入口卡 / 歌单卡 / 入口卡）**同一档**：
    //   圆角用 `MinePage.R_CARD`（16）、底色用 `app.color.card_background`。
    //   原来这里跟着原大设置页用 `sys.float.corner_radius_level16` +
    //   `app.color.comp_background_list_card`，在本页里看起来"颜色和圆角都跟下面不一样"（用户反馈）。
    .borderRadius(ACCOUNT_CARD_RADIUS)
    .backgroundColor($r('app.color.card_background'))
    .bindSheet($$this.sheetOpen, this.AccountSheetContent(), {
      height: ACCOUNT_SHEET_HEIGHT,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.background_secondary'),
      onDisappear: (): void => {
        this.sheetOpen = false;
      }
    })
  }
}
