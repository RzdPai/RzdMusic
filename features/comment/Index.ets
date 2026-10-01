// 歌曲评论（移植自洛雪音乐 HarmonyOS 版 lxmusic-harmony 的内置平台评论）
//
// 导出分两层：
//   core/CommentApi    —— 取评论（酷我 / 酷狗 / QQ / 咪咕 / 网易五个平台的内置接口 + 解析）
//   core/CommentTarget —— 歌曲平台身份（在线歌直接用 source+songId；本地歌由宿主注册解析器）
//   view/CommentPanel  —— 评论面板（热门 / 最新两个页签、分页、楼中楼、展开收起）
//
// ⚠️ 洛雪的「自定义音源」协议里没有「取评论」这个 action（平台源的 action 白名单只有 musicUrl），
//    所以评论只能走内置接口 —— 这条路与本工程的自定义源引擎无关，不受源脚本可用性的影响。

export {
  COMMENT_PAGE_SIZE,
  commentsSupported,
  dedupeComments,
  fetchComments,
  relativeTime,
  COMMENT_SUPPORTED_SOURCES
} from './src/main/ets/core/CommentApi';
export type { CommentKind, CommentPage, CommentSongRef, LxComment } from './src/main/ets/core/CommentApi';

export {
  commentTargetOf,
  needsPlatformMatch,
  setCommentTargetResolver
} from './src/main/ets/core/CommentTarget';
export type { CommentTargetResolver } from './src/main/ets/core/CommentTarget';

export { saveImageToLocal } from './src/main/ets/core/CommentImageSaver';
export type { SaveImageResult } from './src/main/ets/core/CommentImageSaver';

export { CommentPanel } from './src/main/ets/view/CommentPanel';
