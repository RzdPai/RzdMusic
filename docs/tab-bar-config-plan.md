# 自定义 Tab 栏：改造方案（未落地，等专门一轮）

> 需求（用户 2026-10-31）：主题设置里新增「Tab 栏」分区，参考「音源」页的样式——
> 勾选控制显示、拖动调整顺序，放在主题设置最下面。

## 为什么不能直接改（现状实测）

`products/default/src/main/ets/pages/Index.ets`：

```ts
TabContent() { … }
  .tabBar(this.TabBarItem(0, $r('app.string.tab_home'),        $r('sys.symbol.house_fill')))
TabContent() { … }
  .tabBar(this.TabBarItem(1, $r('app.string.tab_now_playing'), $r('sys.symbol.music_round_triangle_fill')))
TabContent() { … }
  .tabBar(this.TabBarItem(2, $r('app.string.tab_echo'),        $r('sys.symbol.waveform')))
TabContent() { … }
  .tabBar(this.TabBarItem(3, $r('app.string.tab_cafe_listen'), $r('sys.symbol.person_crop_circle_fill_1')))
```

- 底栏是 **4 个固定 `TabContent`**，`TabBarItem(index, …)` **按下标取**标题/图标；
- 全文件 **`tabIndex` 被引用 35 次**：切页、`scrollTopCommand`、回弹触发（`tabBounceTriggers`）、
  导航入栈/出栈、`searchTabBarHidden` 的恢复逻辑都依赖它。

⇒ 一旦「隐藏某个 Tab」或「改变顺序」，所有按下标写的逻辑全部错位：会切到空白页、
搜索返回后落错 Tab、回弹判定失效。**这不是加个 UI 就完事的需求。**

## 落地步骤（建议按顺序，每步单独编译+出包）

### 1. 配置模型 `TabBarConfigService`（common/musicbasic）

```ts
export class TabBarItemConfig {
  id: string = '';        // 'home' | 'now' | 'echo' | 'mine'
  visible: boolean = true;
  order: number = 0;
}
// 键：tab_bar_config（JSON 数组）
// 默认：home(0) / now(1) / echo(2) / mine(3)，全部 visible
```
校验：至少保留 **2 个**可见 Tab；顺序按 `order` 升序稳定排序。

### 2. 映射层 `TabBarRouter`（products/default）

```ts
// 逻辑下标（配置顺序，0..visibleCount-1） ⇄ 物理下标（Index.ets 里 TabContent 的固定顺序）
logicalToPhysical(logical: number): number
physicalToLogical(physical: number): number
```
把 Index.ets 里所有 `tabIndex` 的**读写**改走这两个函数；`selectedIndex` / `TabBarItem()` 的入参也用逻辑下标。

⚠️ 改法要一批改完（35 处），中间态不可编译运行。

### 3. 设置 UI（setting/SettingsDetailPage → ThemeSheet 最下面）

- 顶部标题「Tab 栏」+ 说明「勾选显示的页签，拖动可排序」；
- `List` + `ListItem`：每行 `Checkbox` + 页签名称 + 图标 + 右侧 `≡` 拖拽把手；
- 拖动排序用 `List` 的 `onMove((from: number, to: number) => …)`（如该 API 在目标 SDK 不可用，
  退化为上/下箭头按钮，功能等价）；
- 至少 2 个可见的限制用 Toast 提示：「至少保留两个页签」；
- 改动即写 `tab_bar_config` 并 `AppStorage` 通知壳层重建（`HdsTabs` 需要重新计算 bar 数量）。

### 4. 真机验收清单

1. 隐藏「回响」→ 底栏只剩 3 个，切页正常，**不会切到空白页**；
2. 把「我的」拖到第 2 位 → 底栏顺序变化，点第 2 个 Tab 打开的是「我的」；
3. 在任意 Tab 上触发「搜索」→ 返回后仍落在同一个**逻辑** Tab；
4. 首页列表滚动 → 底部 Tab 回弹/隐藏逻辑仍正确；
5. 重启 App → 配置保持。

## 风险与回退

- 风险集中在第 2 步（35 处下标改写）；建议单独 commit，出问题可 `git revert` 单个提交；
- 若 `List.onMove` 在目标 SDK 上不可用，先用上/下箭头实现排序（用户可接受，功能等价）。
