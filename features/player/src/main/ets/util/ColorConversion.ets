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
 * 取色工具已迁到 **common/musicbasic**（`musicbasic` 导出的 `ColorConversion`）。
 *
 * 迁移动因：recommendation / playlist 也需要它（卡片背景取色），而它们只能依赖 common。
 * 这里保留同名再导出，避免改动已有的 `import { ColorConversion } from '../util/ColorConversion'`。
 */
export { ColorConversion } from 'musicbasic';