const MAX_LOG_LENGTH: number = 20000;
const LOG_KEY: string = 'lxPlayLog';
const ERROR_KEY: string = 'lxLastError';

/**
 * ★ 2026-10-31（用户反馈"历史残留日志刷屏"）：每帧/每动画步都在打的高频标签，
 * 统一在这里做**按标签节流**（默认 300ms 一条），既保留排障信息，又不会把日志刷爆。
 * 新增高频标签时把它加进这个集合即可。
 */
const NOISY_TAGS: string[] = ['RzdCloseChain', 'RzdSearchMorph', 'RzdCoverOwner', 'RzdCloseState', 'RzdCloseSnap'];
const NOISY_WINDOW_MS: number = 300;
/** 每个高频标签上一次真正写入的时间戳。 */
const lastNoisyAt: Map<string, number> = new Map<string, number>();

function formatTime(): string {
  const now: Date = new Date();
  return now.getHours().toString().padStart(2, '0') + ':' +
    now.getMinutes().toString().padStart(2, '0') + ':' +
    now.getSeconds().toString().padStart(2, '0');
}

/**
 * @returns 该消息是否应被节流掉（仅针对 NOISY_TAGS）。
 * @param message 原始日志。
 */
function throttled(message: string): boolean {
  let tag: string = '';
  for (let i: number = 0; i < NOISY_TAGS.length; i++) {
    if (message.indexOf('[' + NOISY_TAGS[i] + ']') >= 0 || message.indexOf('[' + NOISY_TAGS[i] + ' ') === 0) {
      tag = NOISY_TAGS[i];
      break;
    }
  }
  if (tag.length === 0) {
    return false;
  }
  const now: number = Date.now();
  const last: number = lastNoisyAt.get(tag) ?? 0;
  if (now - last < NOISY_WINDOW_MS) {
    return true;
  }
  lastNoisyAt.set(tag, now);
  return false;
}

export function appendPlayLog(message: string): void {
  if (throttled(message)) {
    return;
  }
  const log: string = AppStorage.get<string>(LOG_KEY) ?? '';
  const entry: string = '[' + formatTime() + '] ' + message + '\n';
  const combined: string = log + entry;
  AppStorage.setOrCreate(LOG_KEY, combined.length > MAX_LOG_LENGTH ?
    combined.substring(combined.length - MAX_LOG_LENGTH) : combined);
}

export function appendError(message: string): void {
  const time: string = formatTime();
  AppStorage.setOrCreate(ERROR_KEY, '[' + time + '] ' + message);
  appendPlayLog(message);
}
