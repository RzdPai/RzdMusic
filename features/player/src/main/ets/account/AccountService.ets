import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { huks } from '@kit.UniversalKeystoreKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { PlatformAccount, LoginSession, QrCodeLoginState, QrCodeLoginResult, AccountLoginResult, PlaylistInfo, PlaylistMutationTrack, PlaylistTrackInfo, PlatformTrackInfo } from './AccountModels';
import { getAccountAvatar } from './providers/KgProvider';
import { TxProvider } from './providers/TxProvider';
import { MusicProvider, providerMap } from './providers/MusicProvider';
import { AccountChangedState } from './AccountChangedState';
import { PlayerConstants } from '../constant/PlayerConstants';

const STORE_NAME: string = 'account_sessions';
const ACCOUNTS_KEY: string = 'accounts';
const KEY_ALIAS: string = 'account_session_key';
const LOG_TAG: string = 'LXAccount';

interface SessionJson {
  source: string;
  cookies: Record<string, string>;
  tokens: Record<string, string>;
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

function base64Decode(value: string): Uint8Array {
  const helper: util.Base64Helper = new util.Base64Helper();
  return helper.decodeSync(utf8Bytes(value));
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const result: Uint8Array = new Uint8Array(a.length + b.length);
  result.set(a, 0);
  result.set(b, a.length);
  return result;
}

function huksAesParams(purpose: number, iv: Uint8Array): Array<huks.HuksParam> {
  const properties: Array<huks.HuksParam> = [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
    { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
    { tag: huks.HuksTag.HUKS_TAG_IV, value: iv },
  ];
  return properties;
}

async function decryptText(encrypted: string): Promise<string> {
  try {
    const parts: string[] = encrypted.split('.');
    if (parts.length !== 3) throw new Error('加密数据格式错误');
    const iv: Uint8Array = base64Decode(parts[0]);
    const cipherText: Uint8Array = base64Decode(parts[1]);
    const authTag: Uint8Array = base64Decode(parts[2]);
    const properties: Array<huks.HuksParam> = huksAesParams(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, iv);
    const handle: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, {
      properties: properties,
      inData: new Uint8Array(0),
    });
    const updateOptions: huks.HuksOptions = { properties: properties, inData: cipherText };
    const updateResult: huks.HuksReturnResult = await huks.updateSession(handle.handle, updateOptions);
    const finishProperties: Array<huks.HuksParam> = huksAesParams(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, iv);
    finishProperties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: authTag });
    const finishOptions: huks.HuksOptions = { properties: finishProperties, inData: new Uint8Array(0) };
    const finishResult: huks.HuksReturnResult = await huks.finishSession(handle.handle, finishOptions);
    const plainText: Uint8Array = concatBytes(updateResult.outData ?? new Uint8Array(0), finishResult.outData ?? new Uint8Array(0));
    return utf8String(plainText);
  } catch (err) {
    const message: string = err instanceof Error ? err.message : String(err);
    hilog.error(0x0000, LOG_TAG, 'decrypt failed: %{public}s', message);
    throw new Error(message);
  }
}

export class AccountService {
  private static store: preferences.Preferences | undefined = undefined;
  private static inMemorySessions: Map<string, LoginSession> = new Map();

  static init(context: common.UIAbilityContext | undefined): void {
    if (AccountService.store !== undefined) return;
    if (context === undefined) return;
    AccountService.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
  }

  private static getStore(): preferences.Preferences {
    if (AccountService.store === undefined) throw new Error('AccountService 未初始化');
    return AccountService.store;
  }

  static async loadAccounts(): Promise<void> {
    const accounts: PlatformAccount[] = AccountService.listAccounts();
    for (let i = 0; i < accounts.length; i++) {
      try {
        const session: LoginSession | undefined = await AccountService.readSession(accounts[i].id);
        if (session !== undefined) AccountService.inMemorySessions.set(accounts[i].id, session);
      } catch (err) {
        const message: string = err instanceof Error ? err.message : String(err);
        hilog.error(0x0000, LOG_TAG, 'readSession failed for %{public}s: %{public}s', accounts[i].id, message);
      }
    }
  }

  static listAccounts(): PlatformAccount[] {
    const raw: string = AccountService.getStore().getSync(ACCOUNTS_KEY, '') as string;
    if (raw.length === 0) return [];
    try {
      return JSON.parse(raw) as PlatformAccount[];
    } catch (err) {
      return [];
    }
  }

  static async saveAccount(account: PlatformAccount, session: LoginSession): Promise<void> {
    const store: preferences.Preferences = AccountService.getStore();
    const accounts: PlatformAccount[] = AccountService.listAccounts();
    let replaced: boolean = false;
    for (let i = 0; i < accounts.length; i++) {
      if (accounts[i].id === account.id) {
        accounts[i] = account;
        replaced = true;
        break;
      }
    }
    if (!replaced) accounts.push(account);
    store.putSync(ACCOUNTS_KEY, JSON.stringify(accounts));
    store.putSync(`session:${account.id}`, AccountService.sessionToJson(session));
    await store.flush();
    AccountService.inMemorySessions.set(account.id, session);
    AccountService.bumpAccountChanged();
  }

  static async removeAccount(id: string): Promise<void> {
    const store: preferences.Preferences = AccountService.getStore();
    const accounts: PlatformAccount[] = AccountService.listAccounts().filter((account: PlatformAccount) => account.id !== id);
    store.putSync(ACCOUNTS_KEY, JSON.stringify(accounts));
    store.deleteSync(`session:${id}`);
    await store.flush();
    AccountService.inMemorySessions.delete(id);
    AccountService.bumpAccountChanged();
  }

  private static bumpAccountChanged(): void {
    const state: AccountChangedState | undefined = AppStorageV2.connect(AccountChangedState,
      PlayerConstants.ACCOUNT_CHANGED_STATE, () => new AccountChangedState());
    if (state !== undefined) {
      state.version++;
    }
  }

  static async getSession(id: string): Promise<LoginSession | undefined> {
    if (AccountService.inMemorySessions.has(id)) return AccountService.inMemorySessions.get(id);
    try {
      const session: LoginSession | undefined = await AccountService.readSession(id);
      if (session !== undefined) AccountService.inMemorySessions.set(id, session);
      return session;
    } catch (err) {
      return undefined;
    }
  }

  static async refreshKgAvatars(): Promise<void> {
    const accounts: PlatformAccount[] = AccountService.listAccounts();
    for (let i = 0; i < accounts.length; i++) {
      const account: PlatformAccount = accounts[i];
      if (account.source !== 'kg' || account.avatar.length > 0) continue;
      const session: LoginSession | undefined = AccountService.inMemorySessions.get(account.id);
      if (!session) continue;
      try {
        const avatar: string = await getAccountAvatar(session);
        if (avatar.length === 0) continue;
        const current: LoginSession | undefined = AccountService.inMemorySessions.get(account.id);
        if (current !== session) continue;
        account.avatar = avatar;
        await AccountService.saveAccount(account, session);
      } catch (err) {
        // 单个头像获取失败不阻断
      }
    }
  }

  private static async readSession(id: string): Promise<LoginSession | undefined> {
    const raw: string = AccountService.getStore().getSync(`session:${id}`, '') as string;
    if (raw.length === 0) return undefined;
    let json: string = raw;
    if (raw.indexOf('{') !== 0) {
      try {
        json = await decryptText(raw);
      } catch (err) {
        const message: string = err instanceof Error ? err.message : String(err);
        hilog.error(0x0000, LOG_TAG, 'legacy session decrypt failed for %{public}s: %{public}s', id, message);
        return undefined;
      }
    }
    const parsed: SessionJson = JSON.parse(json) as SessionJson;
    const session: LoginSession = new LoginSession();
    session.source = parsed.source;
    for (const key of Object.keys(parsed.cookies)) {
      session.cookies.set(key, parsed.cookies[key]);
    }
    for (const key of Object.keys(parsed.tokens)) {
      session.tokens.set(key, parsed.tokens[key]);
    }
    if (raw !== json) {
      AccountService.getStore().putSync(`session:${id}`, json);
    }
    return session;
  }

  private static sessionToJson(session: LoginSession): string {
    const cookies: Record<string, string> = {};
    session.cookies.forEach((value: string, key: string) => {
      cookies[key] = value;
    });
    const tokens: Record<string, string> = {};
    session.tokens.forEach((value: string, key: string) => {
      tokens[key] = value;
    });
    const json: SessionJson = { source: session.source, cookies: cookies, tokens: tokens };
    return JSON.stringify(json);
  }

  private static providerOf(source: string): MusicProvider {
    const provider: MusicProvider | undefined = providerMap.get(source);
    if (provider === undefined) throw new Error('不支持的平台');
    return provider;
  }

  static async loginByCookie(source: string, cookie: string): Promise<PlatformAccount> {
    const result: AccountLoginResult = await AccountService.providerOf(source).loginByCookie(cookie);
    await AccountService.saveAccount(result.account, result.session);
    return result.account;
  }

  static async createQrCode(source: string): Promise<QrCodeLoginState> {
    return AccountService.providerOf(source).createQrCode();
  }

  static async checkQrCodeStatus(source: string, requestId: string): Promise<QrCodeLoginResult> {
    const result: QrCodeLoginResult = await AccountService.providerOf(source).checkQrCodeStatus(requestId);
    if (result.account !== undefined && result.session !== undefined) {
      await AccountService.saveAccount(result.account, result.session);
      result.account = undefined;
      result.session = undefined;
    }
    return result;
  }

  static cancelQrCode(source: string, requestId: string): void {
    if (source !== 'tx') return;
    const provider: MusicProvider | undefined = providerMap.get('tx');
    if (provider instanceof TxProvider) provider.cancelQrCode(requestId);
  }

  static async getUserPlaylists(accountId: string): Promise<PlaylistInfo[]> {
    const session: LoginSession | undefined = await AccountService.getSession(accountId);
    if (!session) throw new Error('账号登录状态不存在或已失效');
    return AccountService.providerOf(session.source).getUserPlaylists(session);
  }

  static async getPlaylistTrackIds(accountId: string, playlistId: string, dirId: string | undefined): Promise<PlaylistTrackInfo[]> {
    const session: LoginSession | undefined = await AccountService.getSession(accountId);
    if (!session) throw new Error('账号登录状态不存在或已失效');
    return AccountService.providerOf(session.source).getPlaylistTrackIds(session, playlistId, dirId);
  }

  static async removePlaylistTracks(accountId: string, playlistId: string, dirId: string | undefined, tracks: PlaylistMutationTrack[]): Promise<void> {
    const session: LoginSession | undefined = await AccountService.getSession(accountId);
    if (!session) throw new Error('账号登录状态不存在或已失效');
    return AccountService.providerOf(session.source).removePlaylistTracks(session, playlistId, dirId, tracks);
  }

  static async getDailyTrackIds(accountId: string): Promise<string[]> {
    const session: LoginSession | undefined = await AccountService.getSession(accountId);
    if (!session) throw new Error('账号登录状态不存在或已失效');
    return AccountService.providerOf(session.source).getDailyTrackIds(session);
  }

  static async getTrackDetails(accountId: string, ids: string[]): Promise<PlatformTrackInfo[]> {
    const session: LoginSession | undefined = await AccountService.getSession(accountId);
    if (!session) throw new Error('账号登录状态不存在或已失效');
    return AccountService.providerOf(session.source).getTrackDetails(session, ids);
  }
}
