/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * 「我的 → 全部歌单」二级页（**薄壳，没有第二份实现**）。
 *
 * 底栏从四个页签收成两个（推荐 / 我的）之后，「歌单」那个页签被删掉了，但它的
 * **整页能力**（新建 / 重命名 / 删除 / 拖动排序 / 导出 / 网络导入 / 自定义封面 /
 * 进歌单详情 / 本地音乐入口）一样都不能少 —— 那些能力全在 `features/playlist` 的
 * `PlaylistsPage` 里，所以这里只是把它挂到本 HAR 的路由表上，由「我的」页的
 * **自带路由栈**（`MinePage.localStack`）推进来。
 *
 * ★ 为什么不直接把路由名加到 `features/playlist` 的 router_map：
 *   本轮的改动范围被限定在 `features/setting/**` 与两个 product 的壳层，
 *   而且 `features/setting/oh-package.json5` 本来就依赖 `playlist`（`SongMoreMenu` 在用），
 *   在 setting 侧加一层薄壳既不动 playlist，也不会出现两份歌单页实现。
 *
 * ⚠️ 两个导出都要留着：
 *   · `MinePlaylistPageBuilder` 是**系统路由表**要的（`router_map.json` 的 buildFunction，
 *     `@Builder` 函数体里必须含 `NavDestination` —— 这里是 `HdsNavDestination`，
 *     它是 `PlaylistsPage.build()` 的根节点），与同目录的 `MineSettingsPageBuilder` 同构；
 *   · `MinePlaylistPage` 结构体让 `MinePage` 能**直接引用本文件**（HAR 是按引用编译的：
 *     只被 router_map 引用的文件不会被拉进编译图，所以多一个 struct 出口更稳）。
 */

import { PlaylistsPage } from 'playlist';

/** 「全部歌单」二级页本体（= `features/playlist` 的 `PlaylistsPage`）。 */
@ComponentV2
export struct MinePlaylistPage {
  build() {
    PlaylistsPage()
  }
}

/** 路由表里注册的 Builder（`features/setting` 的 router_map.json）。 */
@Builder
export function MinePlaylistPageBuilder(name: string, param: Object) {
  MinePlaylistPage();
}
