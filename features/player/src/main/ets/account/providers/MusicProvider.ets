import { AccountLoginResult, LoginSession, PlaylistInfo, PlaylistMutationTrack, PlaylistTrackInfo, PlatformTrackInfo, QrCodeLoginResult, QrCodeLoginState } from '../AccountModels';
import { KgProvider } from './KgProvider';
import { TxProvider } from './TxProvider';
import { WyProvider } from './WyProvider';

export interface MusicProvider {
  loginByCookie(cookie: string): Promise<AccountLoginResult>;
  createQrCode(): Promise<QrCodeLoginState>;
  checkQrCodeStatus(requestId: string): Promise<QrCodeLoginResult>;
  getUserPlaylists(session: LoginSession | undefined): Promise<PlaylistInfo[]>;
  getPlaylistTrackIds(session: LoginSession | undefined, playlistId: string, dirId: string | undefined): Promise<PlaylistTrackInfo[]>;
  removePlaylistTracks(session: LoginSession | undefined, playlistId: string, dirId: string | undefined, tracks: PlaylistMutationTrack[]): Promise<void>;
  getDailyTrackIds(session: LoginSession | undefined): Promise<string[]>;
  getTrackDetails(session: LoginSession | undefined, ids: string[]): Promise<PlatformTrackInfo[]>;
}

const providerEntries: Array<[string, MusicProvider]> = [
  ['wy', new WyProvider()],
  ['tx', new TxProvider()],
  ['kg', new KgProvider()],
];

export const providerMap: Map<string, MusicProvider> = new Map(providerEntries);
