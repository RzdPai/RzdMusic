import { connection } from '@kit.NetworkKit';
import { MusicStoreService } from './MusicStoreService';

/** Network defaults are read at each URL resolution; unknown/offline uses cellular policy. */
export class PlaybackPreferenceService {
  static async resolveCurrentNetworkWifi(): Promise<boolean> {
    try {
      const net = await connection.getDefaultNet();
      const caps = await connection.getNetCapabilities(net);
      return caps.bearerTypes.includes(connection.NetBearType.BEARER_WIFI) ||
        caps.bearerTypes.includes(connection.NetBearType.BEARER_ETHERNET);
    } catch (_error) {
      console.warn('[RzdQualityPolicy] network unknown; using cellular');
      return false;
    }
  }

  /** Explicit player selection edits only the currently active network; unknown uses cellular. */
  static async setCurrentNetworkQuality(quality: string): Promise<void> {
    const wifi: boolean = await PlaybackPreferenceService.resolveCurrentNetworkWifi();
    MusicStoreService.getInstance().setNetworkPlayQuality(wifi, quality);
  }

  static async resolveDefaultQuality(): Promise<string> {
    const wifi: boolean = await PlaybackPreferenceService.resolveCurrentNetworkWifi();
    const store = MusicStoreService.getInstance();
    const quality: string = store.getNetworkPlayQuality(wifi);
    console.info('[RzdQualityPolicy] network=' + (wifi ? 'wifi/ethernet' : 'cellular') +
      ' enabled=' + store.getNetworkExtendedEnabled(wifi) +
      ' base=' + store.getNetworkBaseQuality(wifi) +
      ' extension=' + store.getNetworkExtendedQuality(wifi) + ' effective=' + quality);
    return quality;
  }
}
