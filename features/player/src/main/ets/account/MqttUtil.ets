import { webSocket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const LOG_TAG: string = 'LXAccount';

export interface MqttConnackInfo {
  serverReference: string;
}

export interface MqttPublishMessage {
  topic: string;
  payload: Uint8Array;
  userProperties: Map<string, string>;
}

export class MqttClientOptions {
  clientId: string = '';
  keepalive: number = 45;
  authenticationMethod: string = '';
  userProperties: Map<string, string> = new Map();
  headers: Map<string, string> = new Map();
  connectTimeout: number = 20000;
}

interface ReadResult {
  value: number;
  size: number;
}

interface ReadStringResult {
  value: string;
  size: number;
}

interface ReadPropertyResult {
  userProperties: Map<string, string>;
  serverReference: string;
  size: number;
}

function encodeVbi(value: number): Uint8Array {
  const bytes: number[] = [];
  let remaining: number = value;
  do {
    let byte: number = remaining % 128;
    remaining = Math.floor(remaining / 128);
    if (remaining > 0) byte |= 0x80;
    bytes.push(byte);
  } while (remaining > 0);
  return new Uint8Array(bytes);
}

function readVbi(bytes: Uint8Array, offset: number): ReadResult {
  let value: number = 0;
  let multiplier: number = 1;
  let size: number = 0;
  for (let i = 0; i < 4; i++) {
    const byte: number = bytes[offset + i];
    value += (byte & 0x7f) * multiplier;
    size++;
    if ((byte & 0x80) === 0) break;
    multiplier *= 128;
  }
  return { value: value, size: size };
}

function utf8Bytes(value: string): Uint8Array {
  const encoder: util.TextEncoder = new util.TextEncoder();
  const buffer: ArrayBuffer = new ArrayBuffer(value.length * 4);
  const view: Uint8Array = new Uint8Array(buffer);
  const result = encoder.encodeInto(value, view);
  return view.slice(0, result.written);
}

function utf8String(bytes: Uint8Array): string {
  const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
  return decoder.decode(bytes);
}

function encodeUtf8String(value: string): Uint8Array {
  const data: Uint8Array = utf8Bytes(value);
  const result: Uint8Array = new Uint8Array(data.length + 2);
  result[0] = (data.length >> 8) & 0xff;
  result[1] = data.length & 0xff;
  result.set(data, 2);
  return result;
}

function readUtf8String(bytes: Uint8Array, offset: number): ReadStringResult {
  const length: number = (bytes[offset] << 8) | bytes[offset + 1];
  const value: Uint8Array = bytes.slice(offset + 2, offset + 2 + length);
  return { value: utf8String(value), size: length + 2 };
}

function readProperties(bytes: Uint8Array, offset: number): ReadPropertyResult {
  const lengthResult: ReadResult = readVbi(bytes, offset);
  const end: number = Math.min(offset + lengthResult.size + lengthResult.value, bytes.length);
  let cursor: number = offset + lengthResult.size;
  const userProperties: Map<string, string> = new Map();
  let serverReference: string = '';
  while (cursor < end) {
    const before: number = cursor;
    const id: number = bytes[cursor];
    cursor++;
    if (id === 0x26) {
      const keyResult: ReadStringResult = readUtf8String(bytes, cursor);
      cursor += keyResult.size;
      const valueResult: ReadStringResult = readUtf8String(bytes, cursor);
      cursor += valueResult.size;
      userProperties.set(keyResult.value, valueResult.value);
    } else if (id === 0x27) {
      const valueResult: ReadStringResult = readUtf8String(bytes, cursor);
      cursor += valueResult.size;
      serverReference = valueResult.value;
    } else if (id === 0x01 || id === 0x19 || id === 0x29) {
      cursor += 1;
    } else if (id === 0x03 || id === 0x04 || id === 0x22) {
      cursor += 2;
    } else if (cursor + 4 <= end && (id === 0x05 || id === 0x06 || id === 0x07 || id === 0x08 || id === 0x09 ||
      id === 0x0a || id === 0x0b || id === 0x0c || id === 0x0d || id === 0x0e ||
      id === 0x0f || id === 0x10 || id === 0x11 || id === 0x1f || id === 0x20 ||
      id === 0x23 || id === 0x28)) {
      cursor += 4;
    } else if (id === 0x12 || id === 0x13 || id === 0x1c || id === 0x21) {
      const skipResult: ReadResult = readVbi(bytes, cursor);
      cursor += skipResult.size;
    } else if (id === 0x15) {
      const keyResult: ReadStringResult = readUtf8String(bytes, cursor);
      cursor += keyResult.size;
      const valueResult: ReadStringResult = readUtf8String(bytes, cursor);
      cursor += valueResult.size;
    } else if (cursor + 2 <= end && (id === 0x16 || id === 0x17 || id === 0x18 || id === 0x1a || id === 0x1b ||
      id === 0x24 || id === 0x25)) {
      const length: number = (bytes[cursor] << 8) | bytes[cursor + 1];
      cursor += 2 + length;
    } else {
      // 未覆盖的 property id：不要静默 break（那会截断后续 userProperties /
      // serverReference 解析），至少留一条线索，并按声明长度跳过。
      hilog.warn(0x0000, LOG_TAG,
        'mqtt 未识别的 property id=0x%{public}s，跳过 %{public}d 字节',
        id.toString(16), Math.max(0, end - before));
      break;
    }
    if (cursor <= before) {
      // 防御：避免解析不前进导致死循环
      hilog.warn(0x0000, LOG_TAG, 'mqtt property 解析未前进，提前结束 id=0x%{public}s', id.toString(16));
      break;
    }
  }
  return { userProperties: userProperties, serverReference: serverReference, size: lengthResult.size + lengthResult.value };
}

function encodeProperties(userProperties: Map<string, string>): Uint8Array {
  let body: Uint8Array = new Uint8Array(0);
  userProperties.forEach((value: string, key: string) => {
    const part: Uint8Array = new Uint8Array(1);
    part[0] = 0x26;
    body = concatBytes(body, part);
    body = concatBytes(body, encodeUtf8String(key));
    body = concatBytes(body, encodeUtf8String(value));
  });
  return concatBytes(encodeVbi(body.length), body);
}

function encodeAuthMethodProperty(value: string): Uint8Array {
  const part: Uint8Array = new Uint8Array(1);
  part[0] = 0x15;
  return concatBytes(part, encodeUtf8String(value));
}

function encodePropertyBody(userProperties: Map<string, string>, authenticationMethod: string): Uint8Array {
  let body: Uint8Array = new Uint8Array(0);
  if (authenticationMethod.length > 0) {
    body = concatBytes(body, encodeAuthMethodProperty(authenticationMethod));
  }
  userProperties.forEach((value: string, key: string) => {
    const part: Uint8Array = new Uint8Array(1);
    part[0] = 0x26;
    body = concatBytes(body, part);
    body = concatBytes(body, encodeUtf8String(key));
    body = concatBytes(body, encodeUtf8String(value));
  });
  return concatBytes(encodeVbi(body.length), body);
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const result: Uint8Array = new Uint8Array(a.length + b.length);
  result.set(a, 0);
  result.set(b, a.length);
  return result;
}

function buildConnectPacket(options: MqttClientOptions): Uint8Array {
  let body: Uint8Array = new Uint8Array(0);
  body = concatBytes(body, new Uint8Array([0x00, 0x04, 0x4d, 0x51, 0x54, 0x54]));
  body = concatBytes(body, new Uint8Array([0x05, 0x02]));
  body = concatBytes(body, new Uint8Array([(options.keepalive >> 8) & 0xff, options.keepalive & 0xff]));
  body = concatBytes(body, encodePropertyBody(options.userProperties, options.authenticationMethod));
  body = concatBytes(body, encodeUtf8String(options.clientId));
  return concatBytes(new Uint8Array([0x10]), concatBytes(encodeVbi(body.length), body));
}

function buildSubscribePacket(packetId: number, topic: string, userProperties: Map<string, string>): Uint8Array {
  let body: Uint8Array = new Uint8Array(0);
  body = concatBytes(body, new Uint8Array([(packetId >> 8) & 0xff, packetId & 0xff]));
  body = concatBytes(body, encodeProperties(userProperties));
  body = concatBytes(body, encodeUtf8String(topic));
  body = concatBytes(body, new Uint8Array([0x00]));
  return concatBytes(new Uint8Array([0x82]), concatBytes(encodeVbi(body.length), body));
}

export class MqttConnectError extends Error {
  code: number = 0;
}

/**
 * 连接过程中的共享可变状态。
 *
 * 必须用对象而不是布尔值：`settled` 曾经以「按值传参」的方式传进
 * `drainPackets` / `handleConnack`，函数内部把形参置 true 并不会改到外层闭包，
 * 于是 `ws.on('error')` 里 `if (settled)` 永远为假 —— CONNACK 成功、订阅也成功
 * 之后，任何一次网络抖动都会走到 `destroy() + reject()`，把一条健康的连接直接
 * 掐断，再触发上层重连退避，最终报「QQ 音乐扫码连接不稳定」。这就是 QQ 登录
 * 失败的决定性原因（其它平台走 HTTP 轮询，没有这条链路）。
 */
interface MqttConnState {
  settled: boolean;
}

export class MqttClient {
  private ws: webSocket.WebSocket | undefined = undefined;
  private buffer: Uint8Array = new Uint8Array(0);
  private pingTimer: number = -1;
  private closed: boolean = false;
  onConnack: ((info: MqttConnackInfo) => void) | undefined = undefined;
  onPublish: ((message: MqttPublishMessage) => void) | undefined = undefined;
  onError: ((err: Error) => void) | undefined = undefined;
  onClose: (() => void) | undefined = undefined;
  /** SUBACK 回调：reason >= 0x80 表示订阅被拒绝，扫码事件永远不会到达。 */
  onSuback: ((reasonCode: number) => void) | undefined = undefined;
  /** CONNACK 拒绝回调（reason !== 0）。 */
  onConnectError: ((reasonCode: number) => void) | undefined = undefined;

  connect(options: MqttClientOptions): Promise<void> {
    const ws: webSocket.WebSocket = webSocket.createWebSocket();
    this.ws = ws;
    this.closed = false;
    return new Promise<void>((resolve, reject) => {
      // 共享对象：所有回调读写的是同一份状态（修复按值传参的闭包 bug）
      const connState: MqttConnState = { settled: false };
      const timer: number = setTimeout(() => {
        if (connState.settled) return;
        connState.settled = true;
        this.destroy();
        reject(new Error('连接扫码服务超时'));
      }, options.connectTimeout);

      ws.on('open', () => {
        ws.send(buildConnectPacket(options).buffer).catch((err: BusinessError) => {
          if (connState.settled) return;
          connState.settled = true;
          clearTimeout(timer);
          this.destroy();
          reject(new Error(`发送连接请求失败：${err.message ?? ''}`));
        });
      });

      ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
        if (err) return;
        let bytes: Uint8Array;
        if (typeof data === 'string') {
          const decoder: util.Base64Helper = new util.Base64Helper();
          bytes = decoder.decodeSync(utf8Bytes(data));
        } else {
          bytes = new Uint8Array(data);
        }
        if (bytes.length === 0) return;
        this.buffer = concatBytes(this.buffer, bytes);
        this.drainPackets(connState, resolve, reject, timer);
      });

      ws.on('error', (err: BusinessError) => {
        hilog.error(0x0000, LOG_TAG, 'mqtt ws error: %{public}s code %{public}d', err.message ?? '', err.code ?? 0);
        if (connState.settled) {
          // 连接已建立：只上报，交给上层重连，绝不在这里 destroy + reject
          if (this.onError) this.onError(new Error(err.message ?? '扫码连接异常'));
          return;
        }
        connState.settled = true;
        clearTimeout(timer);
        this.destroy();
        const connectError: MqttConnectError = new MqttConnectError(`连接扫码服务失败：${err.message ?? ''}`);
        connectError.code = err.code ?? 0;
        reject(connectError);
      });

      ws.on('close', () => {
        hilog.info(0x0000, LOG_TAG, 'mqtt ws closed');
        this.stopPing();
        if (this.onClose) this.onClose();
      });

      const header: Record<string, string> = {};
      options.headers.forEach((value: string, key: string) => {
        header[key] = value;
      });
      const requestOptions: webSocket.WebSocketRequestOptions = {
        header: header,
        proxy: 'no-proxy',
        pingInterval: 0,
      };
      ws.connect('wss://mu.y.qq.com/ws/handshake', requestOptions).catch((err: BusinessError) => {
        if (connState.settled) return;
        connState.settled = true;
        clearTimeout(timer);
        this.destroy();
        reject(new Error(`连接扫码服务失败：${err.message ?? ''}`));
      });
    });
  }

  private drainPackets(
    connState: MqttConnState,
    resolve: () => void,
    reject: (err: Error) => void,
    timer: number,
  ): void {
    while (true) {
      if (this.buffer.length < 2) return;
      const lengthResult: ReadResult = readVbi(this.buffer, 1);
      const total: number = 1 + lengthResult.size + lengthResult.value;
      if (this.buffer.length < total) return;
      const packet: Uint8Array = this.buffer.slice(0, total);
      this.buffer = this.buffer.slice(total);
      const first: number = packet[0];
      const type: number = first >> 4;
      if (type === 0x02) {
        this.handleConnack(packet, connState, resolve, reject, timer);
      } else if (type === 0x03) {
        const message: MqttPublishMessage | undefined = this.parsePublish(packet);
        if (message && this.onPublish) this.onPublish(message);
      } else if (type === 0x09) {
        // SUBACK：旧实现整体丢弃，导致订阅失败时 UI 一直停在"等待扫码"
        this.handleSuback(packet);
      } else if (type === 0x0d) {
        hilog.debug(0x0000, LOG_TAG, 'mqtt pingresp');
      }
    }
  }

  /** SUBACK: [0x90][len][packetId:2][reasonCode...] */
  private handleSuback(packet: Uint8Array): void {
    const reasonCode: number = packet.length > 4 ? packet[4] : -1;
    hilog.info(0x0000, LOG_TAG, 'mqtt suback reason %{public}d', reasonCode);
    if (this.onSuback) this.onSuback(reasonCode);
    if (reasonCode >= 0x80) {
      hilog.error(0x0000, LOG_TAG, '扫码订阅被拒绝 reason=%{public}d', reasonCode);
    }
  }

  private handleConnack(
    packet: Uint8Array,
    connState: MqttConnState,
    resolve: () => void,
    reject: (err: Error) => void,
    timer: number,
  ): void {
    const reasonCode: number = packet.length >= 3 ? packet[2] : -1;
    let info: MqttConnackInfo = { serverReference: '' };
    if (packet.length >= 4) {
      const properties: ReadPropertyResult = readProperties(packet, 3);
      info = { serverReference: properties.serverReference };
    }
    hilog.info(0x0000, LOG_TAG, 'mqtt connack reason %{public}d ref %{public}s', reasonCode, info.serverReference);
    if (!connState.settled) {
      connState.settled = true;
      clearTimeout(timer);
      if (reasonCode !== 0) {
        // 旧实现无论什么 reason 都当成功，认证被拒也会继续 subscribe 并显示"等待扫码"
        if (this.onConnectError) this.onConnectError(reasonCode);
        this.destroy();
        reject(new Error(`扫码服务拒绝连接（reason ${reasonCode}）`));
        return;
      }
      resolve();
      this.startPing();
    }
    if (this.onConnack) this.onConnack(info);
  }

  private parsePublish(packet: Uint8Array): MqttPublishMessage | undefined {
    const flags: number = packet[0] & 0x0f;
    const qos: number = (flags >> 1) & 3;
    let cursor: number = 1;
    const vbi: ReadResult = readVbi(packet, cursor);
    cursor += vbi.size;
    const topicResult: ReadStringResult = readUtf8String(packet, cursor);
    cursor += topicResult.size;
    if (qos > 0) cursor += 2;
    if (cursor >= packet.length) return undefined;
    const properties: ReadPropertyResult = readProperties(packet, cursor);
    cursor += properties.size;
    const payload: Uint8Array = packet.slice(cursor);
    const event: string = properties.userProperties.get('type') ?? '';
    hilog.info(0x0000, LOG_TAG, 'mqtt publish topic %{public}s event %{public}s payload %{public}d bytes', topicResult.value, event, payload.length);
    return {
      topic: topicResult.value,
      payload: payload,
      userProperties: properties.userProperties,
    };
  }

  subscribe(topic: string, userProperties: Map<string, string>): void {
    const ws: webSocket.WebSocket | undefined = this.ws;
    if (!ws || this.closed) return;
    ws.send(buildSubscribePacket(1, topic, userProperties).buffer).catch(() => {
      if (this.onError) this.onError(new Error('订阅扫码状态失败'));
    });
  }

  private startPing(): void {
    if (this.pingTimer >= 0) return;
    this.pingTimer = setInterval(() => {
      const ws: webSocket.WebSocket | undefined = this.ws;
      if (!ws || this.closed) return;
      ws.send(new Uint8Array([0xc0, 0x00]).buffer).catch(() => {});
    }, 20000);
  }

  private stopPing(): void {
    if (this.pingTimer >= 0) {
      clearInterval(this.pingTimer);
      this.pingTimer = -1;
    }
  }

  close(): void {
    this.stopPing();
    this.closed = true;
    const ws: webSocket.WebSocket | undefined = this.ws;
    if (!ws) return;
    try {
      ws.close();
    } catch (err) {
      // 忽略关闭异常
    }
  }

  private destroy(): void {
    this.stopPing();
    this.closed = true;
    const ws: webSocket.WebSocket | undefined = this.ws;
    if (!ws) return;
    try {
      ws.close();
    } catch (err) {
      // 忽略关闭异常
    }
  }
}
