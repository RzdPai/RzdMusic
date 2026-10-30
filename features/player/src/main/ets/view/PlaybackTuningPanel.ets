/*
 * Copyright (c) 2026 RzdPai
 *
 * 「播放设置」面板（可复用组件）。
 *
 * 内容与参考设计一致：播放倍速 / 升降调 / 5 段均衡器（60Hz、230Hz、910Hz、3.6kHz、14kHz）+ 重置，
 * 另外补了一行 EQ 预设（关闭 / 流行 / 摇滚 / 人声 / 重低音）。
 *
 * 全部使用官方组件：`Button(type: Capsule)` 做倍速胶囊、`Slider` 做滑杆（EQ 竖向用 `Axis.Vertical`）。
 * 数据落在 `MusicStoreService`（键 `tuning_pitch` / `tuning_eq_gains`），
 * 改完立刻 `MediaService.refreshTuning()`，走 FFmpeg 的曲目会热更新 `af` 链。
 *
 * 排查日志关键字：`RzdTuning`。
 */

import { AppStorageKeys, MusicAppState, MusicStoreService } from 'musicbasic';
import { AppStorageV2 } from '@kit.ArkUI';
import { MediaService } from '../model/MediaService';
import { appendPlayLog } from 'musicbasic';

/** 倍速档位（与播放页菜单保持一致）。 */
const SPEED_OPTIONS: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/** EQ 频段（Hz）。 */
const EQ_BANDS: number[] = [60, 230, 910, 3600, 14000];

/** EQ 预设：名称 + 5 段增益（dB）。 */
class EqPreset {
  name: string = '';
  gains: number[] = [0, 0, 0, 0, 0];

  constructor(name: string, gains: number[]) {
    this.name = name;
    this.gains = gains;
  }
}

const EQ_PRESETS: EqPreset[] = [
  new EqPreset('关闭', [0, 0, 0, 0, 0]),
  new EqPreset('流行', [2, 1, -1, 1, 2]),
  new EqPreset('摇滚', [4, 2, -2, 2, 4]),
  new EqPreset('人声', [-2, 0, 3, 2, 0]),
  new EqPreset('重低音', [6, 4, 0, 0, -1])
];

/**
 * 播放设置面板。
 * 直接把自身铺满父容器（宽 100%），由调用方决定放在菜单子页还是独立弹窗里。
 */
@ComponentV2
export struct PlaybackTuningPanel {
  @Local speed: number = 1.0;
  @Local pitch: number = 0;
  @Local eqGains: number[] = [0, 0, 0, 0, 0];
  @Local presetName: string = '关闭';

  private store: MusicStoreService = MusicStoreService.getInstance();
  /** 与播放器共享的全局状态（只读倍速用于高亮）。 */
  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  aboutToAppear(): void {
    this.speed = this.appState.playbackRate;
    this.pitch = this.store.getTuningPitch();
    this.eqGains = this.store.getEqGains();
    this.presetName = this.matchPresetName(this.eqGains);
  }

  /** 当前增益对应的预设名（没有匹配则空串）。 */
  private matchPresetName(gains: number[]): string {
    for (let i: number = 0; i < EQ_PRESETS.length; i++) {
      const preset: EqPreset = EQ_PRESETS[i];
      let same: boolean = true;
      for (let k: number = 0; k < gains.length; k++) {
        if (preset.gains[k] !== gains[k]) {
          same = false;
          break;
        }
      }
      if (same) {
        return preset.name;
      }
    }
    return '自定义';
  }

  /** 倍速文案：1.0 → 1x、1.25 → 1.25x。 */
  private speedText(rate: number): string {
    const text: string = rate.toFixed(2).replace(/0$/, '');
    return text + 'x';
  }

  /** 升降调文案：0 → 原调。 */
  private pitchText(): string {
    if (this.pitch === 0) {
      return '原调';
    }
    return (this.pitch > 0 ? '+' : '') + this.pitch.toString();
  }

  /** 应用倍速（AVPlayer 与 FFmpeg 两条路都生效）。 */
  private applySpeed(rate: number): void {
    this.speed = rate;
    MediaService.getInstance().applyPlaybackRate(rate);
    appendPlayLog('[RzdTuning] speed=' + rate);
  }

  /** 应用升降调。 */
  private applyPitch(semitones: number): void {
    this.pitch = semitones;
    this.store.setTuningPitch(semitones);
    MediaService.getInstance().refreshTuning();
    appendPlayLog('[RzdTuning] pitch=' + semitones);
  }

  /** 应用某一段 EQ。 */
  private applyBand(index: number, gain: number): void {
    const next: number[] = this.eqGains.slice();
    next[index] = gain;
    this.eqGains = next;
    this.presetName = this.matchPresetName(next);
    this.store.setEqGains(next);
    MediaService.getInstance().refreshTuning();
    appendPlayLog('[RzdTuning] eq[' + index + ']=' + gain);
  }

  /** 应用预设。 */
  private applyPreset(preset: EqPreset): void {
    this.eqGains = preset.gains.slice();
    this.presetName = preset.name;
    this.store.setEqGains(this.eqGains);
    MediaService.getInstance().refreshTuning();
    appendPlayLog('[RzdTuning] preset=' + preset.name);
  }

  /** 全部重置（倍速回 1x、升降调回原调、EQ 归零）。 */
  private resetAll(): void {
    this.applySpeed(1.0);
    this.pitch = 0;
    this.store.setTuningPitch(0);
    this.eqGains = [0, 0, 0, 0, 0];
    this.presetName = '关闭';
    this.store.setEqGains(this.eqGains);
    MediaService.getInstance().refreshTuning();
    appendPlayLog('[RzdTuning] reset');
  }

  build() {
    Column() {
      // 标题行
      Row() {
        Text('播放设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
        Text('重置')
          .fontSize(14)
          .fontColor(this.themeStateColor())
          .onClick((): void => {
            this.resetAll();
          })
      }
      .width('100%')
      .margin({ bottom: 2 })

      Text('倍速、音调与均衡器调节')
        .fontSize(13)
        .fontColor($r('app.color.font_tertiary'))
        .width('100%')
        .margin({ bottom: 14 })

      // 播放倍速
      Row() {
        Text('播放倍速')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
        Text(this.speedText(this.speed))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeStateColor())
      }
      .width('100%')
      .margin({ bottom: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(SPEED_OPTIONS, (rate: number) => {
          Button() {
            Text(this.speedText(rate))
              .fontSize(14)
              .fontColor(this.speed === rate ? $r('app.color.page_background') : $r('app.color.font_primary'))
          }
          .type(ButtonType.Capsule)
          .height(34)
          .padding({ left: 16, right: 16 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(this.speed === rate ? this.themeStateColor() : $r('app.color.background_secondary'))
          .onClick((): void => {
            this.applySpeed(rate);
          })
        }, (rate: number) => 'tune-speed-' + rate)
      }
      .width('100%')
      .margin({ bottom: 6 })

      // 升降调
      Row() {
        Text('升降调')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
        Text(this.pitchText())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeStateColor())
          .onClick((): void => {
            this.applyPitch(0);
          })
      }
      .width('100%')
      .margin({ top: 8 })

      Slider({
        value: this.pitch,
        min: -12,
        max: 12,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .blockColor(this.themeStateColor())
        .selectedColor(this.themeStateColor())
        .trackColor($r('app.color.background_secondary'))
        .onChange((value: number): void => {
          const semitones: number = Math.round(value);
          if (semitones !== this.pitch) {
            this.applyPitch(semitones);
          }
        })

      // 均衡器
      Row() {
        Text('均衡器（EQ）')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
        Text(this.presetName)
          .fontSize(13)
          .fontColor($r('app.color.font_tertiary'))
      }
      .width('100%')
      .margin({ top: 14, bottom: 8 })

      // EQ 预设
      Scroll() {
        Row({ space: 8 }) {
          ForEach(EQ_PRESETS, (preset: EqPreset) => {
            Button() {
              Text(preset.name)
                .fontSize(13)
                .fontColor(this.presetName === preset.name ?
                  $r('app.color.page_background') : $r('app.color.font_primary'))
            }
            .type(ButtonType.Capsule)
            .height(30)
            .padding({ left: 14, right: 14 })
            .backgroundColor(this.presetName === preset.name ?
              this.themeStateColor() : $r('app.color.background_secondary'))
            .onClick((): void => {
              this.applyPreset(preset);
            })
          }, (preset: EqPreset) => 'eq-preset-' + preset.name)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ bottom: 10 })

      // 5 段竖向滑杆
      Row() {
        ForEach(EQ_BANDS, (hz: number, index: number) => {
          Column() {
            Text(this.eqGains[index].toFixed(0))
              .fontSize(11)
              .fontColor($r('app.color.font_tertiary'))
              .margin({ bottom: 4 })
            Slider({
              value: this.eqGains[index],
              min: -12,
              max: 12,
              step: 1,
              style: SliderStyle.OutSet,
              direction: Axis.Vertical
            })
              .layoutWeight(1)
              .blockColor(this.themeStateColor())
              .selectedColor(this.themeStateColor())
              .trackColor($r('app.color.background_secondary'))
              .onChange((value: number): void => {
                const gain: number = Math.round(value);
                if (gain !== this.eqGains[index]) {
                  this.applyBand(index, gain);
                }
              })
            Text(PlaybackTuningPanel.bandText(hz))
              .fontSize(10)
              .fontColor($r('app.color.font_tertiary'))
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .height(150)
          .alignItems(HorizontalAlign.Center)
        }, (hz: number) => 'eq-band-' + hz)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('倍速立即生效；升降调与均衡器经 FFmpeg 内核（汽水/已开启音效的曲目）生效')
        .fontSize(11)
        .fontColor($r('app.color.font_tertiary'))
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 频段文案：3600 → 3.6kHz。 */
  private static bandText(hz: number): string {
    if (hz >= 1000) {
      const k: number = hz / 1000;
      return (k === Math.floor(k) ? k.toFixed(0) : k.toFixed(1)) + 'kHz';
    }
    return hz.toFixed(0) + 'Hz';
  }

  /** 强调色（用于数值与选中态；跟随应用主题的图标主色）。 */
  private themeStateColor(): ResourceColor {
    return $r('app.color.icon_primary');
  }
}
