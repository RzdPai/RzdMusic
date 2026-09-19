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
 * Route parameters for opening the ranking board detail page: a multi-source
 * music board ('kw'|'kg'|'tx'|'wy'|'mg') identified by its source-local id.
 */
export class RankingRouteParam {
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg'). */
  source: string = '';
  /** Board id within the source. */
  boardId: string = '';
  /** Board display name shown in the title bar. */
  boardName: string = '';
}
