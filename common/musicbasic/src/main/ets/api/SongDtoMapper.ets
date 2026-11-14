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


import { SongItem } from '../model/SongData';
import { SongApiDto } from './MusicApiDtos';

/**
 * Maps API-layer {@link SongApiDto} to UI {@link SongItem} entities.
 */
export class SongDtoMapper {
  /**
   * Copies all song fields from DTO to a new {@link SongItem}.
   * @param dto Source API DTO.
   * @returns New song item for lists and player state.
   */
  public static toSongItem(dto: SongApiDto): SongItem {
    let item = new SongItem();
    item.id = dto.id;
    item.title = dto.title;
    item.singer = dto.singer;
    item.mark = dto.mark;
    item.label = dto.label;
    item.src = dto.src;
    item.index = dto.index;
    item.lyric = dto.lyric;
    return item;
  }
}
