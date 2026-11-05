/*
 * Copyright (c) 2026 RzdPai
 *
 * 酷狗分享链接解析（短链 → global_specialid）。
 *
 * 事实（已实测，见项目记忆 §195–§199）：
 * - `https://t1.kugou.com/76Kuhf5G6V2` → 302 →
 *   `https://activity.kugou.com/share/v-a00a45b0/index.html?list_create_listid=1
 *    &global_specialid=collection_3_1554363080_1_0&cType=1`
 * - 该分享页是纯 SPA（无 SSR 数据），曲目要调签名接口：
 *   `GET mobiles.kugou.com/v5/special/info_v2?specialid=0&global_specialid=…&sign=h5&signature=…`
 *   `POST pubsongs.kugou.com/v1/get_list_info` body `[{specialid:0, global_collection_id}]`
 *   签名 = md5(盐 + 排序参数拼接 + 盐)，盐 `NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt`；
 *   我们按此实现后仍返回 `1001`/`20006` ⇒ 仍缺登录态或额外参数。
 *
 * 因此本文件**只做"短链 → global_specialid"这一段**，并给出明确失败原因，
 * 曲目拉取等拿到真实请求样本/走登录后再补。
 *
 * 排查日志关键字：`RzdKgShare`。
 */

import { http } from '@kit.NetworkKit';
import { appendPlayLog } from './LxLogger';

/** 解析结果。 */
export class KugouShareResult {
  /** 是否拿到 global_specialid。 */
  ok: boolean = false;
  /** 形如 `collection_3_1554363080_1_0`。 */
  globalSpecialId: string = '';
  /** 跟随 302 之后的最终地址。 */
  finalUrl: string = '';
  /** 失败原因（给用户看的短句）。 */
  reason: string = '';
}

/** 酷狗分享链接解析器。 */
export class KugouShareResolver {
  private static readonly TAG: string = '[RzdKgShare]';

  /**
   * @param url 用户粘贴的链接（t1.kugou.com 短链或 activity 分享页长链）。
   * @returns 解析结果（含最终 URL 与 global_specialid）。
   */
  static async resolve(url: string): Promise<KugouShareResult> {
    const out: KugouShareResult = new KugouShareResult();
    const trimmed: string = url.trim();
    if (trimmed.length === 0) {
      out.reason = '链接为空';
      return out;
    }
    // 长链里可能直接带 global_specialid，先就地取
    const inline: string = KugouShareResolver.pickGlobalId(trimmed);
    if (inline.length > 0) {
      out.ok = true;
      out.globalSpecialId = inline;
      out.finalUrl = trimmed;
      appendPlayLog(KugouShareResolver.TAG + ' inline gid=' + inline);
      return out;
    }
    // 短链：请求一次拿 302 的 Location
    try {
      const client = http.createHttp();
      const resp: http.HttpResponse = await client.request(trimmed, {
        method: http.RequestMethod.GET,
        connectTimeout: 8000,
        readTimeout: 8000,
        extraData: undefined
      });
      const location: string =
        (resp.header as Record<string, string>)['location'] ?? '';
      client.destroy();
      let finalUrl: string = location;
      if (finalUrl.length === 0) {
        // 部分场景直接给 200 + 页面，从页面里找
        finalUrl = typeof resp.result === 'string' ? (resp.result as string) : '';
      }
      out.finalUrl = finalUrl;
      const gid: string = KugouShareResolver.pickGlobalId(finalUrl);
      if (gid.length > 0) {
        out.ok = true;
        out.globalSpecialId = gid;
        appendPlayLog(KugouShareResolver.TAG + ' short gid=' + gid);
        return out;
      }
      out.reason = '短链里没有 global_specialid（可能不是歌单分享链接）';
      appendPlayLog(KugouShareResolver.TAG + ' fail code=' + resp.responseCode +
        ' url=' + finalUrl.substring(0, Math.min(120, finalUrl.length)));
      return out;
    } catch (err) {
      out.reason = '短链请求失败（网络或链接失效）';
      appendPlayLog(KugouShareResolver.TAG + ' request error');
      return out;
    }
  }

  /**
   * @param text URL 或页面内容。
   * @returns `global_specialid` 值；没有返回空串。
   */
  private static pickGlobalId(text: string): string {
    const m: RegExpMatchArray | null =
      text.match(/global_specialid=([A-Za-z0-9_\-]+)/);
    if (m !== null && m.length > 1) {
      return m[1];
    }
    const m2: RegExpMatchArray | null = text.match(/collection_\d+_\d+_\d+_\d+/);
    if (m2 !== null && m2.length > 0) {
      return m2[0];
    }
    return '';
  }

  /**
   * @param gid `collection_3_1554363080_1_0`。
   * @returns 形如 `1554363080`（用户 id 段），供后续接口使用；解析不出返回空串。
   */
  static uidSegment(gid: string): string {
    const parts: string[] = gid.split('_');
    return parts.length >= 4 ? parts[2] : '';
  }
}
