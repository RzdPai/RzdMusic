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

/**
 * Route parameters for opening the artist detail page (singer profile).
 * source uses the geuz source code: 0=kg, 1=tx, 2=wy, 3=mg, 4=kw.
 */
export class ArtistRouteParam {
  /** Source code (0=kg,1=tx,2=wy,3=mg,4=kw). */
  source: number = 2;
  /** Artist id within the source; empty when only the name is known. */
  id: string = '';
  /** NetEase/QQ artist mid; empty for sources that use plain ids. */
  mid: string = '';
  /** Artist display name. */
  name: string = '';
  /** Artist photo url. */
  picUrl: string = '';
  /** Number of albums (display only). */
  albumSize: number = 0;
  /** Number of songs (display only). */
  songNum: number = 0;
}

/**
 * Route parameters for opening the album detail page.
 */
export class AlbumRouteParam {
  /** Source code (0=kg,1=tx,2=wy,3=mg,4=kw). */
  source: number = 2;
  /** Album id within the source. */
  id: string = '';
  /** NetEase/QQ album mid; empty for sources that use plain ids. */
  mid: string = '';
  /** Album name. */
  name: string = '';
  /** Album cover url. */
  picUrl: string = '';
  /** Artist name. */
  artistName: string = '';
  /** Track count (display only). */
  size: number = 0;
}