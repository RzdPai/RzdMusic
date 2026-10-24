// 转屏封面几何核对（离线复算，不参与构建）
// 目的：把 PlayerExpandState.playerCoverGeomRect() 那套「fitPlayerOverlay 纯几何」在
// 甲方机型（vp 363x823 竖屏 / 823x363 横屏）上算一遍，用来对照：
//   ① 竖屏**正确**的封面矩形应该是什么；
//   ② 如果端点还停在"横屏量到的实测"（`endCover*`），画出来会偏到哪里；
//   ③ 截图里那组观感（封面偏小 + 偏右 + 歌名偏高）是否与 ② 吻合。
// 常量全部照抄 common/musicbasic/src/main/ets/model/PlayerExpandState.ets（行号见注释）。

const K = {
  LYRIC_COVER_TOP_RATIO_STATUS: 0.07, // :1115
  PLAYER_TOP_FALLBACK_VP: 56, // :1122
  LYRIC_COVER_LEFT_VP: 16, // :1130
  COVER_EDGE_CAP_VP: 480, // :1132
  COVER_EDGE_MIN_VP: 200, // :1134
  COVER_FIT_META_H_VP: 60, // :1138
  COVER_FIT_META_GAP_VP: 50, // :1596
  COVER_FIT_BOUND_INSET_VP: 8, // :1598
  COVER_RADIUS_RATIO: 8 / 348, // :1162
};

/** topInsetVp()：:1502-1511 */
function topInsetVp(w, h, statusBar, pageBoxTop) {
  const target = statusBar > 0
    ? Math.max(statusBar, K.PLAYER_TOP_FALLBACK_VP)
    : h * K.LYRIC_COVER_TOP_RATIO_STATUS;
  const off = target - (pageBoxTop > 0 ? pageBoxTop : 0);
  return off > 0 ? off : 0;
}

/** playerCoverGeomRect() / coverGeomFor()：:1828-1877 */
function coverGeom(w, h, statusBar, navBottom, pageBoxTop) {
  const availH = Math.max(1, h - topInsetVp(w, h, statusBar, pageBoxTop) - navBottom);
  const pageSide = K.LYRIC_COVER_LEFT_VP;
  const swiperBoxW = Math.max(1, Math.min(w, availH));
  let curEdgeMax = swiperBoxW - 2 * pageSide;
  if (curEdgeMax > K.COVER_EDGE_CAP_VP) curEdgeMax = K.COVER_EDGE_CAP_VP;
  if (curEdgeMax < K.COVER_EDGE_MIN_VP) curEdgeMax = K.COVER_EDGE_MIN_VP;
  const maxForBox = availH - 2 * (K.COVER_FIT_META_GAP_VP + K.COVER_FIT_META_H_VP + K.COVER_FIT_BOUND_INSET_VP);
  let edge = curEdgeMax;
  if (!(curEdgeMax < maxForBox)) edge = maxForBox;
  if (edge < K.COVER_EDGE_MIN_VP) edge = K.COVER_EDGE_MIN_VP;
  if (edge > curEdgeMax) edge = curEdgeMax;
  if (edge < 0) edge = 0;
  const metaYRaw = edge / 2 + K.COVER_FIT_META_GAP_VP + K.COVER_FIT_META_H_VP / 2;
  const bound = (availH / 2 - K.COVER_FIT_META_H_VP / 2) - K.COVER_FIT_BOUND_INSET_VP;
  const metaY = metaYRaw > bound ? bound : metaYRaw;
  const centerY = topInsetVp(w, h, statusBar, pageBoxTop) + metaY;
  return {
    x: (w - edge) / 2,
    y: centerY - edge / 2,
    size: edge,
    radius: edge * K.COVER_RADIUS_RATIO,
    availH,
  };
}

/** metaTopGeomY(0, rowH)：= 封面底边 + gap(50)（:1724-1741） */
function metaTop(cover) {
  return cover.y + cover.size + K.COVER_FIT_META_GAP_VP;
}

const f = (v) => v.toFixed(1);
const rows = [];
const portrait = { w: 363, h: 823 };
const landscape = { w: 823, h: 363 };

// 三种让位假设（状态栏 0/36/47），横屏按 HarmonyOS 全屏习惯给 0
for (const statusBar of [0, 36, 47]) {
  const p = coverGeom(portrait.w, portrait.h, statusBar, 0, 0);
  const l = coverGeom(landscape.w, landscape.h, 0, 0, 0);
  rows.push({
    statusBar,
    portrait: `cover=(${f(p.x)},${f(p.y)},${f(p.size)}) metaTop=${f(metaTop(p))}`,
    landscape: `cover=(${f(l.x)},${f(l.y)},${f(l.size)}) metaTop=${f(metaTop(l))}`,
  });
}

console.log('=== 纯几何（reseatBigEndpointForWindow 用的就是这套）===');
console.table(rows);

// ② 端点停在横屏实测（真机日志 endAnchor node=172.3x172.3、bigX≈141.4）
const stale = { x: 141.4, y: 60, size: 172.3 };
console.log('\n=== 若端点仍是横屏实测（修之前的样子）===');
console.log(`cover=(${f(stale.x)},${f(stale.y)},${f(stale.size)}) ` +
  `宽占屏 ${(stale.size / portrait.w * 100).toFixed(0)}% 右缘=${f(stale.x + stale.size)} ` +
  `(竖屏右边界 ${portrait.w}) metaTop=${f(stale.y + stale.size + K.COVER_FIT_META_GAP_VP)}`);

const good = coverGeom(portrait.w, portrait.h, 47, 0, 0);
console.log('\n=== 应得（竖屏 363x823、状态栏 47）===');
console.log(`cover=(${f(good.x)},${f(good.y)},${f(good.size)}) ` +
  `宽占屏 ${(good.size / portrait.w * 100).toFixed(0)}% ` +
  `水平居中=${Math.abs(good.x - (portrait.w - good.size) / 2) < 0.5} metaTop=${f(metaTop(good))}`);
