import { MusicStoreService } from 'musicbasic';
import { LXSourceEngine } from './LXSourceEngine';
import { lxSourceManager } from './LXSourceManager';

/**
 * LX 音源引擎宿主：常驻挂载于各产品入口页面。
 * 负责初始化音源脚本存储目录、恢复上次选中的音源。
 * 引擎（隐藏 WebView）在存在音源时才挂载，保证 WebView 页面处于新鲜加载状态，
 * 避免长时间存在的隐藏 WebView 被系统挂起后注入脚本无响应的问题。
 */
@Component
export struct LXSourceHost {
  @StorageLink('lxActiveSource') @Watch('onActiveSourceChanged') lxActiveSource: string = '';
  @State showEngine: boolean = false;

  aboutToAppear(): void {
    let context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      // 幂等：正常路径上 Ability.onCreate 已经初始化过，这里只是兜底
      lxSourceManager.init(context);
    }
    const saved: string = MusicStoreService.getInstance().getActiveSource();
    if (saved.length > 0) {
      AppStorage.setOrCreate('lxActiveSource', saved);
    }
    if (this.lxActiveSource.length > 0) {
      this.showEngine = true;
    }
  }

  onActiveSourceChanged(): void {
    this.showEngine = this.lxActiveSource.length > 0;
  }

  build() {
    Column() {
      if (this.showEngine) {
        LXSourceEngine()
      }
    }
    .width(1)
    .height(1)
    .opacity(0)
  }
}
