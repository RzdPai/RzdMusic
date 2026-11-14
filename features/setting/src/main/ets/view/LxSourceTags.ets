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

import { LXSourcePlatformInfo, probeSummary } from 'player';

/** 小标签的字号（fp）。 */
const CHIP_FONT_SIZE: number = 11;
/** 平台名列宽（vp）：中文四字以内 + 「·」对齐，其余交给右侧说明。 */
const PLATFORM_COL_WIDTH: number = 58;

/** 没检测到声明时的中性提示（**不猜平台**）。 */
function lxMissingDeclaredText(active: boolean): string {
  // ★ 2026-10-29（用户）：括号文案去掉，只留「未检测」
  return '未检测';
}

/**
 * 一条音源条目下面的「声明摘要」：**逐平台一行**（平台 / 音质·动作 / 测试状态）。
 *
 * ★ 2026-11-09（用户：「LX 部分得点两下是不是有点麻烦了，测试里面不就有吗。
 *   把那个删了直接显示测试」）：
 *   旧实现是「一个平台胶囊 + 胶囊内再 bindPopup 看音质/验证结果」—— 看一次信息要点
 *   两下（先点 ⓘ，再点胶囊）。现在把二级气泡整个删掉，直接平铺：
 *   打开「关于」气泡就能看到每个平台的最高音质和测试结论。
 *   胶囊本身也去掉了填充色（红色主题下像"这个源有错"）。
 */
@ComponentV2
export struct LxSourceDeclaredTags {
  /** 所属音源脚本 id（探测状态按脚本隔离）。 */
  @Param apiId: string = '';

  /** 该脚本声明的平台摘要；空数组 = 还没检测到。 */
  @Param items: LXSourcePlatformInfo[] = [];

  /** 单个平台的「最高音质 · 动作」说明（没有就空串）。 */
  private qualityActionOf(item: LXSourcePlatformInfo): string {
    const bits: string[] = [];
    if (item.bestQuality.length > 0) {
      bits.push('最高 ' + item.bestQuality);
    }
    if (item.actions.length > 0) {
      bits.push(item.actions.join('/'));
    }
    const kept: string[] = bits.filter((b: string) => b.length > 0);
    return kept.join(' · ');
  }

  /** 测试结论（已验证 / 未通过 / 未测）；没声明音质的平台不显示。 */
  private probeTextOf(item: LXSourcePlatformInfo): string {
    if (item.bestQuality.length === 0) {
      return '';
    }
    return probeSummary(item.source, this.apiId);
  }

  build() {
    Column({ space: 4 }) {
      ForEach(this.items, (item: LXSourcePlatformInfo) => {
        Row({ space: 6 }) {
          Text(item.label)
            .fontSize(CHIP_FONT_SIZE)
            .fontColor($r('sys.color.font_primary'))
            .width(PLATFORM_COL_WIDTH)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.qualityActionOf(item).length > 0 ? this.qualityActionOf(item) : '音质未声明')
            .fontSize(CHIP_FONT_SIZE)
            .fontColor($r('sys.color.font_tertiary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.probeTextOf(item).length > 0) {
            Text(this.probeTextOf(item))
              .fontSize(CHIP_FONT_SIZE)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
          }
        }
        .width('100%')
      }, (item: LXSourcePlatformInfo) => 'decl_' + item.source)
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
  /** 所属音源脚本 id（探测状态按脚本隔离）。 */
  @Param apiId: string = '';

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
          apiId: this.apiId
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
