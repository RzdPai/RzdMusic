export class PlatformAccount {
  id: string = '';
  source: string = '';
  nickname: string = '';
  avatar: string = '';
}

export class LoginSession {
  source: string = '';
  cookies: Map<string, string> = new Map();
  tokens: Map<string, string> = new Map();
}

export enum QrLoginStatus {
  Waiting = 'waiting',
  Scanned = 'scanned',
  Confirmed = 'confirmed',
  Expired = 'expired',
  Failed = 'failed',
}

export class QrCodeLoginState {
  key: string = '';
  qrUrl: string = '';
  status: QrLoginStatus = QrLoginStatus.Waiting;
  message: string = '';
}

export class QrCodeLoginResult {
  status: QrLoginStatus = QrLoginStatus.Waiting;
  message: string = '';
  account: PlatformAccount | undefined = undefined;
  session: LoginSession | undefined = undefined;
}

export class AccountLoginResult {
  account: PlatformAccount = new PlatformAccount();
  session: LoginSession = new LoginSession();
}

export class PlaylistInfo {
  id: string = '';
  name: string = '';
  source: string = '';
  total: string = '';
  dirId: string = '';
  isEditable: boolean = false;
}

export class PlaylistTrackInfo {
  id: string = '';
  removeId: string = '';
}

export class PlatformTrackInfo {
  id: string = '';
  removeId: string = '';
  name: string = '';
  singer: string = '';
  album: string = '';
  picUrl: string = '';
  interval: string = '';
  source: string = '';
}

export class PlaylistMutationTrack {
  songId: string = '';
  platformId: string = '';
  name: string = '';
  source: string = '';
}

export const SOURCE_NAMES: Map<string, string> = new Map([
  ['wy', '网易云音乐'],
  ['tx', 'QQ音乐'],
  ['kg', '酷狗音乐'],
]);

export function sourceName(source: string): string {
  return SOURCE_NAMES.get(source) ?? source;
}
