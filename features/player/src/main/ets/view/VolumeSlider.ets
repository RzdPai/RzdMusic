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

import {
  ArcSlider,
  ArcSliderLayoutOptions,
  ArcSliderLayoutOptionsConstructorOptions,
  ArcSliderOptions,
  ArcSliderOptionsConstructorOptions,
  ArcSliderPosition,
  ArcSliderStyleOptions,
  ArcSliderStyleOptionsConstructorOptions,
  ArcSliderValueOptions,
  ArcSliderValueOptionsConstructorOptions
} from '@kit.ArkUI';
import { AppStorageV2 } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppStorageKeys, Logger, MusicAppState } from 'musicbasic';
import { MediaService } from '../model/MediaService';

/** Wearable volume control: arc slider bound to MusicAppState.volume and AVPlayer output level. */
@ComponentV2
export struct VolumeSlider {
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  valueOptionsConstructorOptions: ArcSliderValueOptionsConstructorOptions = {
    progress: this.state.volume * 100,
    min: 0,
    max: 100
  };
  layoutOptionsConstructorOptions: ArcSliderLayoutOptionsConstructorOptions = {
    reverse: true,
    position: ArcSliderPosition.RIGHT
  };
  styleOptionsConstructorOptions: ArcSliderStyleOptionsConstructorOptions = {
    trackThickness: 5,
    activeTrackThickness: 8,
    trackColor: '#33f1ebeb',
    selectedColor: '#FE1B48',
    trackBlur: 20
  };
  valueOptions: ArcSliderValueOptions = new ArcSliderValueOptions(this.valueOptionsConstructorOptions);
  layoutOptions: ArcSliderLayoutOptions = new ArcSliderLayoutOptions(this.layoutOptionsConstructorOptions);
  styleOptions: ArcSliderStyleOptions = new ArcSliderStyleOptions(this.styleOptionsConstructorOptions);
  arcSliderOptionsConstructorOptions: ArcSliderOptionsConstructorOptions = {
    valueOptions: this.valueOptions,
    layoutOptions: this.layoutOptions,
    styleOptions: this.styleOptions,
    digitalCrownSensitivity: CrownSensitivity.LOW,
    onChange: (progress: number) => {
      this.state.volume = progress / 100;
      this.setAVPlayerVolume(progress);
    },
  };
  arcSliderOptions: ArcSliderOptions = new ArcSliderOptions(this.arcSliderOptionsConstructorOptions);

  setAVPlayerVolume(progress: number) {
    try {
      MediaService.getInstance().avPlayer?.setVolume(progress / 100);
    } catch (error) {
      Logger.error(`ArcSlider setVolume failed code: ${(error as BusinessError).code}`);
    }
  }

  build() {
    Column() {
      ArcSlider({ options: this.arcSliderOptions })
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
        .zIndex(999)
        .onDigitalCrown((event: CrownEvent) => {
          event.stopPropagation();
          const STEP_DEGREE = 20;
          let newVolume = this.state.volume * 100 + event.degree / STEP_DEGREE;
          newVolume = Math.max(0, Math.min(100, newVolume));
          this.setAVPlayerVolume(newVolume);
        })
      Image($r('app.media.speaker_fill'))
        .width($r('app.float.volume_icon_width'))
        .height($r('app.float.volume_icon_width'))
        .rotate({ angle: '-30deg' })
        .position({
          right: $r('app.float.volume_icon_right'),
          top: $r('app.float.volume_icon_top'),
        })
    }
    .hitTestBehavior(HitTestMode.Transparent)
    .position({
      top: 0,
      right: 0
    })
  }
}
