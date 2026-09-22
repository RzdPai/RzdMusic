import { LoginSession } from './AccountModels';

export function formatSeconds(seconds: number): string {
  const total: number = Math.max(0, Math.floor(seconds));
  return `${Math.floor(total / 60).toString().padStart(2, '0')}:${(total % 60).toString().padStart(2, '0')}`;
}

export function requireSourceSession(session: LoginSession | undefined, source: string, label: string): LoginSession {
  if (session === undefined || session.source !== source) throw new Error(`${label}登录状态不存在或已失效`);
  return session;
}
