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
 * Flat song row for in-memory DB and list UIs (DTO-shaped, no observation).
 */
export class SongRow {
  /** Primary key id in the seeded catalog. */
  public id: number = 0;
  /** Track title (plain string or resource). */
  public title: string | Resource = '';
  /** Artist or performer label. */
  public singer: string | Resource = '';
  /** Small badge or quality icon resource. */
  public mark: Resource = $r('app.string.page_show');
  /** Cover or avatar art resource. */
  public label: Resource = $r('app.string.page_show');
  /** Asset file name or path for playback. */
  public src: string = '';
  /** Zero-based position in a list or queue view. */
  public index: number = 0;
  /** Lyric file path, if any. */
  public lyric: string = '';
}
