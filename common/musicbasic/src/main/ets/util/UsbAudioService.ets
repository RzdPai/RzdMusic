/*
 * Copyright (c) 2026 RzdPai
 *
 * USB 音频设备（USB 独占输出）管理。
 *
 * 全部走官方 `@kit.BasicServicesKit` 的 `usbManager`：
 * - `getDevices()` 枚举，按 `clazz === 1`（AUDIO）过滤出 UAC1/UAC2 设备；
 * - `hasRight(name)` / `requestRight(name)` 申请设备访问权限；
 * - `connectDevice(device)` 拿 `USBDevicePipe`，`getFileDescriptor(pipe)` 拿 **fd**（交给 mpv `usb-exclusive-fd`）；
 * - `closePipe(pipe)` 释放；插拔用 `usbManager.on('attach' | 'detach')` 监听。
 *
 * ⚠️ 事实边界（写在这里免得以后误判）：
 * 1. `getFileDescriptor()` 给的是**设备 fd**，能否被 libmpv 的 `usb-exclusive` 直接采用取决于 ROM 的 usbfs 授权；
 *    拿不到/被拒时我们会保持普通输出，并在 UI/日志里写明「设备不支持」，绝不假装成功。
 * 2. 部分商用机型的 `usbManager` 能枚举但不给传输权限，属于设备限制，不是代码问题。
 *
 * 排查日志关键字：`RzdUsb`。
 */

import { usbManager } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { appendPlayLog } from './LxLogger';

/** USB 音频设备摘要（给 UI 用）。 */
@ObservedV2
export class UsbAudioState {
  /** 是否找到 UAC 音频设备。 */
  @Trace present: boolean = false;
  /** 是否已获得访问权限。 */
  @Trace authorized: boolean = false;
  /** 设备名（如 `1-1`）。 */
  @Trace deviceName: string = '';
  /** 产品名（可读）。 */
  @Trace productName: string = '';
  /** VID/PID 文本。 */
  @Trace vidPid: string = '';
  /** 是否已连接并拿到 fd。 */
  @Trace connected: boolean = false;
  /** 当前 fd（-1 表示无）。 */
  @Trace fd: number = -1;
  /** 给用户看的一句话状态。 */
  @Trace statusText: string = '未检测到 USB 音频设备';
}

/** USB 音频设备管理（单例）。 */
export class UsbAudioService {
  private static instance: UsbAudioService | undefined = undefined;
  /** 最近一次枚举到的设备（连接时要用它）。 */
  private device: usbManager.USBDevice | undefined = undefined;
  private pipe: usbManager.USBDevicePipe | undefined = undefined;
  private readonly tag: string = '[RzdUsb]';
  /** 供 UI 绑定的状态。 */
  readonly state: UsbAudioState = new UsbAudioState();

  /** @returns 单例。 */
  static getInstance(): UsbAudioService {
    if (UsbAudioService.instance === undefined) {
      UsbAudioService.instance = new UsbAudioService();
      UsbAudioService.instance.registerListeners();
    }
    return UsbAudioService.instance;
  }

  /** 注册插拔监听（只注册一次）。 */
  private listenersReady: boolean = false;

  /**
   * 启动设备轮询。
   * 说明：本 SDK 的 `@ohos.usbManager.d.ts` **没有 attach/detach 事件**（只有 getDevices/connectDevice/…），
   * 所以用 2 秒轮询模拟热插拔检测；只在设置页打开或独占开启时运行，离开即停，避免常驻耗电。
   */
  private pollTimer: number = -1;

  private registerListeners(): void {
    if (this.listenersReady) {
      return;
    }
    this.listenersReady = true;
    this.startPolling();
  }

  /** 开始轮询（幂等）。 */
  startPolling(): void {
    if (this.pollTimer >= 0) {
      return;
    }
    this.pollTimer = setInterval((): void => {
      void this.refresh();
    }, 2000);
    appendPlayLog(this.tag + ' 设备轮询已启动（2s）');
    void this.refresh();
  }

  /** 停止轮询。 */
  stopPolling(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
      appendPlayLog(this.tag + ' 设备轮询已停止');
    }
  }

  /** 重新枚举 UAC 音频设备并更新状态（不申请权限）。 */
  async refresh(): Promise<void> {
    try {
      const all: Array<Readonly<usbManager.USBDevice>> = usbManager.getDevices();
      let audio: usbManager.USBDevice | undefined = undefined;
      for (let i: number = 0; i < all.length; i++) {
        const d: Readonly<usbManager.USBDevice> = all[i];
        // clazz === 1 是 USB Audio Class（UAC1/UAC2）
        if (d.clazz === 1) {
          audio = d;
          break;
        }
      }
      if (audio === undefined) {
        this.device = undefined;
        this.state.present = false;
        this.state.deviceName = '';
        this.state.productName = '';
        this.state.vidPid = '';
        this.state.statusText = '未检测到 USB 音频设备（插入 DAC 后自动识别）';
        return;
      }
      this.device = audio;
      this.state.present = true;
      this.state.deviceName = audio.name;
      this.state.productName = audio.productName !== undefined && audio.productName.length > 0 ?
        audio.productName : (audio.manufacturerName ?? 'USB 音频设备');
      this.state.vidPid = 'VID 0x' + audio.vendorId.toString(16) + ' / PID 0x' + audio.productId.toString(16);
      const hasRight: boolean = usbManager.hasRight(audio.name);
      this.state.authorized = hasRight;
      this.state.statusText = hasRight ? '已授权，可开启独占' : '需要授权（点开关会弹系统授权）';
      appendPlayLog(this.tag + ' 设备 name=' + audio.name + ' ' + this.state.vidPid +
        ' right=' + hasRight);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' 枚举失败 code=' + e.code);
      this.state.statusText = 'USB 枚举失败（code=' + e.code + '）';
    }
  }

  /**
   * 申请权限并连接设备，拿到 fd。
   * @returns fd（>0）或 -1（失败/无设备）。
   */
  async connect(): Promise<number> {
    if (this.state.connected && this.state.fd > 0) {
      return this.state.fd;
    }
    if (this.device === undefined) {
      await this.refresh();
    }
    if (this.device === undefined) {
      appendPlayLog(this.tag + ' 连接失败：没有 USB 音频设备');
      return -1;
    }
    const name: string = this.device.name;
    try {
      if (!usbManager.hasRight(name)) {
        const granted: boolean = await usbManager.requestRight(name);
        appendPlayLog(this.tag + ' requestRight=' + granted);
        if (!granted) {
          this.state.statusText = '未获得 USB 权限（系统弹窗被拒绝）';
          return -1;
        }
      }
      this.state.authorized = true;
      const pipe: usbManager.USBDevicePipe = usbManager.connectDevice(this.device);
      this.pipe = pipe;
      const fd: number = usbManager.getFileDescriptor(pipe);
      if (fd < 0) {
        appendPlayLog(this.tag + ' getFileDescriptor 返回 ' + fd + '（ROM 未给 usbfs 权限）');
        this.state.statusText = '设备已连接但未拿到可用的 fd（该机型不给 usbfs 权限）';
        usbManager.closePipe(pipe);
        this.pipe = undefined;
        return -1;
      }
      this.state.connected = true;
      this.state.fd = fd;
      this.state.statusText = '已连接：' + this.state.productName + '（fd=' + fd + '）';
      appendPlayLog(this.tag + ' 连接成功 fd=' + fd + ' name=' + name);
      return fd;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' 连接异常 code=' + e.code + ' msg=' + e.message);
      this.state.statusText = '连接失败（code=' + e.code + '）';
      return -1;
    }
  }

  /** 断开并释放 fd/pipe（幂等）。 */
  disconnect(): void {
    if (this.pipe !== undefined) {
      try {
        usbManager.closePipe(this.pipe);
      } catch (err) {
      }
      appendPlayLog(this.tag + ' 已 closePipe，释放 fd=' + this.state.fd);
      this.pipe = undefined;
    }
    this.state.connected = false;
    this.state.fd = -1;
  }

  /** @returns 当前 fd（-1 表示没有）。 */
  currentFd(): number {
    return this.state.connected ? this.state.fd : -1;
  }
}
