/*
 * 「音源管理」条目上的小标签（平台 / 音质 / 动作）。
 *
 * 为什么单独一个文件：**两处**音源管理界面（`SettingsDetailPage` 的二级页、
 * `SettingPage` 的弹窗）必须长得一模一样 —— 抄两份必然走样，所以样式只此一份。
 *
 * 数据不是这里算的：传进来的 `LXSourcePlatformInfo` 由 `player` 的
 * `lxDeclaredPlatforms()` 从「脚本 init 上报并已持久化的 sources」收敛而来；
 * 这里只负责画。
 *
 * ⚠️ 只用 V2 装饰器（@ComponentV2 / @Param）。
 */

import { LXSourcePlatformInfo } from 'player';

/** 小标签的字号（fp）。 */
const CHIP_FONT_SIZE: number = 11;
/** 小标签的圆角（vp）。 */
const CHIP_RADIUS: number = 6;

/** 没检测到声明时的中性提示（**不猜平台**）。 */
function lxMissingDeclaredText(active: boolean): string {
  return active ? '未检测到平台声明（已选中，正在向脚本确认…）' : '未检测（选中一次该音源后显示）';
}

/**
 * 一条音源条目下面的「声明摘要」：一行平台标签 + 一行音质/动作说明。
 *
 * 调用方负责在 `items` 为空时改画中性提示（见 {@link LxSourceDeclaredBlock}）。
 */
@ComponentV2
export struct LxSourceDeclaredTags {
  /** 该脚本声明的平台摘要；空数组 = 还没检测到。 */
  @Param items: LXSourcePlatformInfo[] = [];
  /** 强调色（主题色），用于平台标签的底。 */
  @Param accentColor: ResourceColor = '#E60012';

  /** 一行平台的文字，例如「酷我 · 网易云 · 咪咕」。 */
  private platformText(): string {
    const parts: string[] = [];
    for (let i: number = 0; i < this.items.length; i++) {
      parts.push(this.items[i].label);
    }
    return parts.join(' · ');
  }

  /**
   * 每个平台一段「音质 / 动作」说明，例如「酷我 最高24Bit · 取链接；网易云 最高320K」。
   *
   * 逐平台列出、不把全部档位堆在一起：脚本里各平台的音质集本来就可以不同
   * （实测有的脚本 kw 有 flac、wy 只有 320k），合并会给出错误暗示。
   */
  private qualityActionText(): string {
    const parts: string[] = [];
    for (let i: number = 0; i < this.items.length; i++) {
      const item: LXSourcePlatformInfo = this.items[i];
      const bits: string[] = [];
      if (item.bestQuality.length > 0) {
        bits.push(item.bestQuality);
      }
      if (item.actions.length > 0) {
        bits.push(item.actions.join('/'));
      }
      if (bits.length > 0) {
        // ★ 用户 2026-10-11：「音源管理里面的 · 也去掉」——its 里可能有空段（标签置空的动作/音质），
    //   直接 join 会留下孤零零的分隔符 ⇒ 先过滤空段再拼。
    const kept: string[] = bits.filter((b: string) => b.length > 0);
    parts.push(kept.length > 0 ? item.label + ' ' + kept.join(' · ') : item.label);
      }
    }
    return parts.join('；');
  }

  build() {
    Column({ space: 4 }) {
      Row() {
        Text(this.platformText())
          .fontSize(CHIP_FONT_SIZE)
          .fontColor($r('sys.color.font_on_primary'))
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .borderRadius(CHIP_RADIUS)
          .backgroundColor(this.accentColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      if (this.qualityActionText().length > 0) {
        Text(this.qualityActionText())
          .fontSize(CHIP_FONT_SIZE)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 一条音源条目下面那一块：有声明就画胶囊，没声明就画中性提示。
 *
 * 存在的意义是「把 if/else 收在一处」—— 两个调用点各只写一行。
 */
@ComponentV2
export struct LxSourceDeclaredBlock {
  /** 该脚本声明的平台摘要；空数组 = 还没检测到。 */
  @Param items: LXSourcePlatformInfo[] = [];
  /** 强调色（主题色）。 */
  @Param accentColor: ResourceColor = '#E60012';
  /** 已选中的那条音源。 */
  @Param active: boolean = false;

  build() {
    Column() {
      if (this.items.length === 0) {
        Text(lxMissingDeclaredText(this.active))
          .fontSize(CHIP_FONT_SIZE)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .maxLines(2)
      } else {
        LxSourceDeclaredTags({
          items: this.items,
          accentColor: this.accentColor
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
