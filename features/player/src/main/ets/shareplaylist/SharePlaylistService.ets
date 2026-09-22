import { SharePlaylistInfo, SharePlaylistSource } from './SharePlaylistTypes';
import { WyShareService } from './WyShareService';
import { TxShareService } from './TxShareService';
import { KwShareService } from './KwShareService';
import { KgShareService } from './KgShareService';
import { MgShareService } from './MgShareService';
import { TextUtils } from './TextUtils';

export class SharePlaylistService {
  private static readonly linkRegex: RegExp = new RegExp('[?&:/]');
  private static readonly txIdRegex1: RegExp = new RegExp('/playlist/(\\d+)');
  private static readonly txIdRegex2: RegExp = new RegExp('id=(\\d+)');
  private static readonly kwIdRegex: RegExp = new RegExp('^.+/playlist(?:_detail)?/(\\d+)');
  private static readonly mgIdRegex1: RegExp = new RegExp('^.+/playlist/(\\d+)(?:\\?.*|&.*$|#.*$|$)');
  private static readonly mgIdRegex2: RegExp = new RegExp('(?:playlistId|id)=(\\d+)');

  static async fetchPlaylist(input: string, source: SharePlaylistSource): Promise<SharePlaylistInfo> {
    const text: string = input.trim();
    const extracted: string = TextUtils.extractUrl(text);
    const resolved: string = extracted.length > 0 ? extracted : text;
    if (source === SharePlaylistSource.Wy) {
      return WyShareService.fetch(resolved);
    }
    if (source === SharePlaylistSource.Kg) {
      return KgShareService.fetch(resolved);
    }
    let id: string = SharePlaylistService.parseId(resolved, source);
    if (id.length === 0) {
      if (source === SharePlaylistSource.Tx) {
        id = await TxShareService.resolveShortLink(resolved);
      } else if (source === SharePlaylistSource.Mg) {
        id = await MgShareService.resolveShortLink(resolved);
      }
    }
    if (id.length === 0) {
      throw new Error('无法解析歌单链接');
    }
    if (source === SharePlaylistSource.Tx) {
      return TxShareService.fetch(id);
    }
    if (source === SharePlaylistSource.Mg) {
      return MgShareService.fetch(id);
    }
    return KwShareService.fetch(id);
  }

  static sourceOptions(): SharePlaylistSource[] {
    return [
      SharePlaylistSource.Wy,
      SharePlaylistSource.Tx,
      SharePlaylistSource.Kw,
      SharePlaylistSource.Kg,
      SharePlaylistSource.Mg
    ];
  }

  static sourceLabel(source: SharePlaylistSource): string {
    switch (source) {
      case SharePlaylistSource.Wy:
        return '网易云';
      case SharePlaylistSource.Tx:
        return 'QQ';
      case SharePlaylistSource.Kw:
        return '酷我';
      case SharePlaylistSource.Kg:
        return '酷狗';
      case SharePlaylistSource.Mg:
        return '咪咕';
      default:
        return String(source);
    }
  }

  private static parseId(input: string, source: SharePlaylistSource): string {
    const text: string = input.trim();
    if (text.length === 0) {
      return '';
    }
    if (!SharePlaylistService.linkRegex.test(text)) {
      return text;
    }
    let match: RegExpExecArray | null = null;
    if (source === SharePlaylistSource.Tx) {
      match = SharePlaylistService.txIdRegex1.exec(text);
      if (match === null) {
        match = SharePlaylistService.txIdRegex2.exec(text);
      }
    } else if (source === SharePlaylistSource.Mg) {
      match = SharePlaylistService.mgIdRegex1.exec(text);
      if (match === null) {
        match = SharePlaylistService.mgIdRegex2.exec(text);
      }
    } else {
      match = SharePlaylistService.kwIdRegex.exec(text);
    }
    if (match === null || match.length < 2) {
      return '';
    }
    return match[1];
  }
}
