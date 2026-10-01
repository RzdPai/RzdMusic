import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { DataBackupService, MusicStoreService } from 'musicbasic';

export class WebDavConfig {
  url: string = '';
  user: string = '';
  password: string = '';
}

/** Immutable generation names prevent accidental overwrite and concurrent-device conflicts. */
export class WebDavBackupService {
  static readConfig(): WebDavConfig {
    try {
      const config = JSON.parse(MusicStoreService.getInstance().getWebDavConfig()) as WebDavConfig;
      if (config === null || typeof config.url !== 'string' || typeof config.user !== 'string' ||
        typeof config.password !== 'string') {
        return new WebDavConfig();
      }
      return config;
    } catch (_error) {
      return new WebDavConfig();
    }
  }

  static saveConfig(config: WebDavConfig): void {
    WebDavBackupService.validate(config);
    MusicStoreService.getInstance().setWebDavConfig(JSON.stringify(config));
  }

  private static validate(config: WebDavConfig): void {
    if (!/^https:\/\//i.test(config.url.trim()) || /[?#]/.test(config.url) || /https:\/\/[^/]*@/i.test(config.url)) {
      throw new Error('请输入无查询参数和内嵌凭据的 HTTPS WebDAV目录地址');
    }
    if (config.user.length === 0 || config.password.length === 0) {
      throw new Error('请填写用户名和密码');
    }
  }

  private static async request(config: WebDavConfig, name: string, method: http.RequestMethod,
    body: string = ''): Promise<http.HttpResponse> {
    WebDavBackupService.validate(config);
    if (!/^rzdmusic-backup-[a-zA-Z0-9-]+\.json$/.test(name)) {
      throw new Error('备份名必须为 rzdmusic-backup-… .json，不能包含路径');
    }
    const req = http.createHttp();
    try {
      const bytes = new util.TextEncoder().encodeInto(config.user + ':' + config.password);
      const authorization: string = 'Basic ' + new util.Base64Helper().encodeToStringSync(bytes);
      const headers: Record<string, string> = {
        'Authorization': authorization,
        'Content-Type': 'application/json; charset=utf-8'
      };
      if (method === http.RequestMethod.PUT) {
        headers['If-None-Match'] = '*';
      }
      console.info('[RzdWebDAV] request method=' + method);
      const response = await req.request(config.url.trim().replace(/\/+$/, '') + '/' + encodeURIComponent(name), {
        method: method,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        maxLimit: 16 * 1024 * 1024
      });
      console.info('[RzdWebDAV] response=' + response.responseCode);
      if (response.responseCode === 401 || response.responseCode === 403) {
        throw new Error('WebDAV认证或写入权限失败');
      }
      if (response.responseCode === 412) {
        throw new Error('远端已存在同名备份，已安全中止，未覆盖');
      }
      return response;
    } finally {
      req.destroy();
    }
  }

  static async backup(config: WebDavConfig): Promise<string> {
    const name: string = 'rzdmusic-backup-' + Date.now() + '-' +
      Math.floor(Math.random() * 1000000000).toString(36) + '.json';
    const text: string = DataBackupService.getInstance().exportSnapshotText();
    const response = await WebDavBackupService.request(config, name, http.RequestMethod.PUT, text);
    if (response.responseCode !== 200 && response.responseCode !== 201 && response.responseCode !== 204) {
      throw new Error('备份失败 HTTP ' + response.responseCode + '，请确认目录已存在');
    }
    return name;
  }

  static async fetch(config: WebDavConfig, name: string): Promise<string> {
    const response = await WebDavBackupService.request(config, name.trim(), http.RequestMethod.GET);
    if (response.responseCode !== 200 || typeof response.result !== 'string') {
      throw new Error('读取备份失败 HTTP ' + response.responseCode);
    }
    return response.result as string;
  }

  static async restore(text: string): Promise<string> {
    return await DataBackupService.getInstance().restoreSnapshotText(text);
  }
}
