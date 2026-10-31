/*
 * Copyright (c) 2026 RzdPai
 *
 * 自定义 Tab 栏模型（只承载「现在就听」「回响」两项，首页/我的固定）。
 *
 * 约定 JSON：`{"now":true,"echo":true,"nowFirst":true}`
 * - `now` / `echo`：是否显示；
 * - `nowFirst`：true = 现在就听在前，false = 回响在前。
 *
 * 壳层接线用的映射（物理=Index.ets 里 TabContent 的固定顺序 0/1/2/3，逻辑=底栏上看到的顺序）：
 * ```ts
 * const cfg: TabBarConfigModel = TabBarConfigModel.parse(raw);
 * const phys: number[] = cfg.physicalOrder();  // 例：[0,2,1,3]
 * const logicalOf: number = phys.indexOf(physicalIndex);
 * const physicalOf: number = phys[logicalIndex];
 * ```
 * ⚠️ 本文件只提供模型与映射，**不改任何 UI**；壳层改造必须一次改完（含 35 处 `tabIndex` 读取）。
 */

/** Tab 栏配置（可变字段 + 解析/序列化/映射）。 */
export class TabBarConfigModel {
  /** 是否显示「现在就听」。 */
  now: boolean = true;
  /** 是否显示「回响」。 */
  echo: boolean = true;
  /** true = 现在就听在前。 */
  nowFirst: boolean = true;

  /**
   * 解析 JSON（容错：坏数据一律回默认）。
   * @param raw 存储里的字符串。
   * @returns 配置对象。
   */
  static parse(raw: string): TabBarConfigModel {
    const out: TabBarConfigModel = new TabBarConfigModel();
    if (raw.length === 0) {
      return out;
    }
    try {
      const obj: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      out.now = obj.now !== false;
      out.echo = obj.echo !== false;
      out.nowFirst = obj.nowFirst !== false;
    } catch (err) {
    }
    // 至少保留一个（两个都关会让底栏只剩 2 个，下标全乱）
    if (!out.now && !out.echo) {
      out.now = true;
    }
    return out;
  }

  /**
   * @returns 序列化后的 JSON。
   */
  toJson(): string {
    const payload: Record<string, Object> = {};
    payload.now = this.now;
    payload.echo = this.echo;
    payload.nowFirst = this.nowFirst;
    return JSON.stringify(payload);
  }

  /**
   * 物理顺序（Index.ets 里 TabContent 的固定下标）：0=首页 1=现在就听 2=回响 3=我的。
   * @returns 按逻辑顺序排列的物理下标数组。
   */
  physicalOrder(): number[] {
    const out: number[] = [0];
    if (this.now && this.echo) {
      if (this.nowFirst) {
        out.push(1, 2);
      } else {
        out.push(2, 1);
      }
    } else if (this.now) {
      out.push(1);
    } else if (this.echo) {
      out.push(2);
    }
    out.push(3);
    return out;
  }

  /**
   * @param physical 物理下标（0..3）。
   * @returns 逻辑下标；隐藏时返回 -1。
   */
  logicalOf(physical: number): number {
    return this.physicalOrder().indexOf(physical);
  }

  /**
   * @param logical 逻辑下标。
   * @returns 物理下标；越界返回 0（首页兜底）。
   */
  physicalOf(logical: number): number {
    const order: number[] = this.physicalOrder();
    if (logical < 0 || logical >= order.length) {
      return 0;
    }
    return order[logical];
  }
}
