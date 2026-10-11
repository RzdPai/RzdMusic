import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { DataBackupService, MusicStoreService } from 'musicbasic';
import { attachSourcesToSnapshot, mergeSourcesFromSnapshot } from './SourceSync';

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
    const snapshotText: string = DataBackupService.getInstance().exportSnapshotText();
    // 这里把「自定义音源脚本」并进同一份备份的 customSources 段：
    // 洛雪同步协议里没有音源模块（详见 SourceSync.ets 文件头的核对结果），这是本工程
    // 现成的、自带账号隔离的跨设备通道。并进去之后**不会**改变 DataBackupService 认得的字段，
    // 旧版本客户端读到未知键会忽略，旧备份没有该键时按「没有音源」处理。
    const text: string = await attachSourcesToSnapshot(snapshotText);
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
    const message: string = await DataBackupService.getInstance().restoreSnapshotText(text);
    // 设置/歌单是「覆盖」，音源是「保守合并」（本机已有同 id 的不覆盖、本机独有的不删）。
    // 音源这段失败不影响上面的恢复结论，所以摘要单独拼。
    const summary: string = await mergeSourcesFromSnapshot(text);
    return summary.length > 0 ? `${message}；${summary}` : message;
  }
}
