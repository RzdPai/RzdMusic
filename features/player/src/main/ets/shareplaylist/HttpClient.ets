import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class ShareHttpClient {
  private static readonly hostRegex = new RegExp('https?://([^/]+)');

  static async request(url: string, headers: Record<string, string>,
    method: http.RequestMethod = http.RequestMethod.GET, body: string = '',
    retries: number = 2): Promise<string> {
    let lastError = new Error('未知错误');
    for (let attempt = 0; attempt <= retries; attempt++) {
      const request = http.createHttp();
      try {
        const options: http.HttpRequestOptions = {
          method: method,
          header: headers,
          connectTimeout: 15000,
          readTimeout: 15000,
          expectDataType: http.HttpDataType.STRING,
        };
        if (method === http.RequestMethod.POST && body.length > 0) {
          options.extraData = body;
        }
        const resp: http.HttpResponse = await request.request(url, options);
        if (resp.responseCode !== 200) {
          const hostMatch = ShareHttpClient.hostRegex.exec(url);
          const host = hostMatch !== null && hostMatch.length > 1 ? hostMatch[1] : url;
          lastError = new Error(`请求失败，状态码 ${resp.responseCode}（${host}）`);
        } else {
          return Promise.resolve(resp.result as string);
        }
      } catch (e) {
        const err = e as BusinessError;
        lastError = new Error(`网络请求失败：${err.message ?? '未知错误'}`);
      } finally {
        request.destroy();
      }
    }
    return Promise.reject(lastError);
  }
}
