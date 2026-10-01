/*
 * 歌曲平台身份的解析。
 *
 * 取评论要知道「这首歌是哪个平台的哪一首」：
 *   - 在线歌（歌单 / 榜单 / 搜索进来的）：条目自带 `source` + `songId`，直接用；
 *   - 本地音乐 / 云端音乐：条目只有 `source = 'local'`，得先匹配到平台上的一首
 *     （`features/localmusic` 的匹配结果），这一步只有**产品壳层**知道 ——
 *     `player` 不能反向依赖 `localmusic`（会成环），所以这里留一个注册点，
 *     由壳层在启动时注册解析器（与 `MediaService.setLocalLyricResolver` 同一套做法）。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { COMMENT_TAG } from './CommentHttp';
import { CommentSongRef, commentsSupported } from './CommentApi';

const DOMAIN: number = 0x0000;

/** 把一首歌（可能是本地歌）解析成可以取评论的平台身份；解析不出来返回 null。 */
export type CommentTargetResolver = (song: CommentSongRef) => Promise<CommentSongRef | null>;

let targetResolver: CommentTargetResolver | null = null;

/**
 * 注册「本地歌 -> 平台身份」的解析器（由产品壳层调用）。
 * @param resolver 传 null 可取消注册（页面退出时用不到，进程级注册一次即可）。
 */
export function setCommentTargetResolver(resolver: CommentTargetResolver | null): void {
  targetResolver = resolver;
}

/** 这首歌是不是「要先匹配到平台版本」才有评论（本地音乐 / 云端音乐 / 没源信息）。 */
export function needsPlatformMatch(song: CommentSongRef): boolean {
  return !commentsSupported(song.source);
}

/**
 * 解析出可以用来取评论的平台身份。
 *
 * @param song 当前歌（可能是本地歌）。
 * @returns 平台身份；解析不出来返回 null（界面提示「还没匹配到平台上的版本」）。
 */
export async function commentTargetOf(song: CommentSongRef): Promise<CommentSongRef | null> {
  if (commentsSupported(song.source) && song.songId.length > 0) {
    return song;
  }
  if (targetResolver === null) {
    hilog.info(DOMAIN, COMMENT_TAG, 'no target resolver for source=%{public}s', song.source);
    return null;
  }
  try {
    const resolved: CommentSongRef | null = await targetResolver(song);
    if (resolved === null) {
      return null;
    }
    if (!commentsSupported(resolved.source) || resolved.songId.length === 0) {
      return null;
    }
    hilog.info(DOMAIN, COMMENT_TAG, 'local song %{public}s -> %{public}s/%{public}s',
      song.songId, resolved.source, resolved.songId);
    return resolved;
  } catch (err) {
    const e: Error = err as Error;
    hilog.warn(DOMAIN, COMMENT_TAG, 'resolve target failed: %{public}s', e.message ?? '');
    return null;
  }
}
