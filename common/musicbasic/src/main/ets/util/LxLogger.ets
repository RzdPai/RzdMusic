const MAX_LOG_LENGTH: number = 20000;
const LOG_KEY: string = 'lxPlayLog';
const ERROR_KEY: string = 'lxLastError';

function formatTime(): string {
  const now: Date = new Date();
  return now.getHours().toString().padStart(2, '0') + ':' +
    now.getMinutes().toString().padStart(2, '0') + ':' +
    now.getSeconds().toString().padStart(2, '0');
}

export function appendPlayLog(message: string): void {
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
