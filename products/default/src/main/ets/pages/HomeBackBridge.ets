/**
 * 首页返回的"收尾桥"。
 *
 * 为什么需要它（真机日志实证，`RzdMusic记忆.md` §80/§81）：
 *   首页按系统返回时，**页面级的 `onBackPress()` 根本不会被调用**（任何日志里都没有
 *   `RzdHomeBackEnter source=Index` 过），返回被更外层吃掉了；
 *   而 Ability 层又拿不到 `AppStorageV2`（编译不过）。
 * ⇒ 于是用一个与 UI 无关的静态桥：页面在 `aboutToAppear` 里把自己那套"收尾"注册进来，
 *   Ability 的 `onBackPressed()` 直接调它，然后照常把返回交回系统。
 *
 * ⚠️ 只放"收"的动作（清浮层/清会话），**不许**在这里发起任何动画或路由跳转。
 */
export type HomeBackCleanup = () => void;

/**
 * 返回键处理器：由壳层注册，Ability 的 `onBackPressed()` 直接调用。
 * @returns true = 壳层已经处理（吃掉这次返回）；false = 交回系统（退出应用）
 */
export type HomeBackHandler = () => boolean;

export class HomeBackBridge {
  /** 页面层注册的收尾函数（未注册时为 undefined）。 */
  private static cleanup: HomeBackCleanup | undefined = undefined;
  /** 壳层注册的返回键处理器（负责弹栈/切页）。 */
  private static handler: HomeBackHandler | undefined = undefined;
  /** 已调用次数，只给日志用。 */
  public static calls: number = 0;

  /**
   * 页面启动时注册（重复注册以最后一次为准）。
   * @param fn 收尾函数
   */
  public static register(fn: HomeBackCleanup): void {
    HomeBackBridge.cleanup = fn;
  }

  /** 页面卸载时注销，避免持有已销毁页面的 `this`。 */
  public static unregister(): void {
    HomeBackBridge.cleanup = undefined;
    HomeBackBridge.handler = undefined;
  }

  /** 注册返回键处理器（壳层 aboutToAppear 调用）。 */
  public static registerBackHandler(fn: HomeBackHandler): void {
    HomeBackBridge.handler = fn;
  }

  /**
   * 处理一次返回：先让页面做收尾，再问壳层要不要吃掉这次返回。
   * @returns true = 已处理（不要交回系统）
   */
  public static handleBack(): boolean {
    HomeBackBridge.runCleanup();
    const fn: HomeBackHandler | undefined = HomeBackBridge.handler;
    if (fn === undefined) {
      return false;
    }
    try {
      return fn();
    } catch (err) {
      return false;
    }
  }

  /**
   * Ability 层收到"首页返回"时调用。
   * @returns true = 页面层做过收尾；false = 没人注册（页面还没起来）
   */
  public static runCleanup(): boolean {
    const fn: HomeBackCleanup | undefined = HomeBackBridge.cleanup;
    if (fn === undefined) {
      return false;
    }
    HomeBackBridge.calls = HomeBackBridge.calls + 1;
    try {
      fn();
      return true;
    } catch (err) {
      return false;
    }
  }
}
