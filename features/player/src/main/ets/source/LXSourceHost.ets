import {AppStorageKeys,  MusicStoreService } from 'musicbasic';
import { LXSourceEngine } from './LXSourceEngine';
import { MusicFreeEngine } from './MusicFreeEngine';
import { lxSourceManager } from './LXSourceManager';
import { LXUserApiInfo } from './Interface';

/**
 * 音源引擎宿主：常驻挂载于各产品入口页面。
 *
 * 两套引擎各挂各的：
 *   · LX 引擎（隐藏 WebView + `window.lx` 桥）：存在 LX 脚本且选了 active 源时挂；
 *   · MusicFree 引擎（隐藏 WebView + CommonJS 运行时）：列表里只要有一个 `kind='mf'`
 *     的插件就挂 —— 它只负责「按需加载某个插件」，空挂状态不跑任何 JS。
 *
 * 引擎必须由产品入口常驻挂载（而不是各页面分别建）：WebView 一旦被页面卸载销毁，
 * 注入过的插件状态就全丢了，再进来要重新加载 130KB 脚本 + 重跑初始化。
 */
@Component
export struct LXSourceHost {
  @StorageLink('lxActiveSource') @Watch('onActiveSourceChanged') lxActiveSource: string = '';
  /** 是否需要 MusicFree 运行时（有 mf 插件才挂，避免白白多一个 WebView）。 */
  @StorageLink('mfEngineNeeded') mfEngineNeeded: boolean = false;
  @State showEngine: boolean = false;

  aboutToAppear(): void {
    let context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      // 幂等：正常路径上 Ability.onCreate 已经初始化过，这里只是兜底
      lxSourceManager.init(context);
    }
    const saved: string = MusicStoreService.getInstance().getActiveSource();
    // ★ 2026-11-09（用户：「播放 LX 的音乐一直提示音源未就绪」）：
    //   `lxActiveSource` 是 LX 引擎的「当前脚本」，但历史版本允许把 MusicFree 插件选成
    //   当前源并持久化下来。启动时把它喂给 LX 引擎只会 `setReady(false)` 并一直卡住，
    //   之后每次播洛雪平台都被判「音源未就绪」。这里直接忽略插件 id（真正播插件时
    //   MusicFree 走自己的运行时，不依赖这个字段）。
    if (saved.length > 0 && !this.isMfPlugin(saved)) {
      AppStorage.setOrCreate(AppStorageKeys.LX_ACTIVE_SOURCE, saved);
    }
    if (this.lxActiveSource.length > 0) {
      this.showEngine = true;
    }
    this.syncMusicFreeNeeded();
  }

  /**
   * 保存的 active 是否已经明确是 MusicFree 插件。
   *
   * ⚠️ 只有**查到且确认是插件**才返回 true：列表还没读出来（filesDir 刚就绪 / 备份恢复中）
   *    时不能把一切当成插件，否则用户原来的 LX 脚本会静默丢失。
   */
  private isMfPlugin(id: string): boolean {
    const list: LXUserApiInfo[] = lxSourceManager.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i].kind === 'mf';
      }
    }
    return false;
  }

  onActiveSourceChanged(): void {
    this.showEngine = this.lxActiveSource.length > 0;
    this.syncMusicFreeNeeded();
  }

  /** 列表里有任意 MusicFree 插件 ⇒ 需要运行时。 */
  private syncMusicFreeNeeded(): void {
    if (this.mfEngineNeeded) {
      return;
    }
    const list: LXUserApiInfo[] = lxSourceManager.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].kind === 'mf') {
        this.mfEngineNeeded = true;
        return;
      }
    }
  }

  build() {
    Column() {
      if (this.showEngine) {
        LXSourceEngine()
      }
      if (this.mfEngineNeeded) {
        MusicFreeEngine()
      }
    }
    .width(1)
    .height(1)
    .opacity(0)
  }
}
