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
import { AudioEffects, effectsFromJson, effectsToJson } from '../engine/AudioEffects';
import { isMpvAvailable } from '../engine/KernelFactory';
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

/** 内核选项。 */
class EngineModeOption {
  label: string = '';
  value: string = '';

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

/** 音效开关项（label + key）。 */
/** 自定义 EQ 预设（名称 + 5 段增益）。 */
class CustomEqPreset {
  name: string = '';
  gains: number[] = [0, 0, 0, 0, 0];

  constructor(name: string, gains: number[]) {
    this.name = name;
    this.gains = gains.slice();
  }
}


class EffectToggle {
  label: string = '';
  key: string = '';

  constructor(label: string, key: string) {
    this.label = label;
    this.key = key;
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
  /** 仅用于强制刷新「播放内核」文案（恢复 FFmpeg 后立即变）。 */
  @Local engineTick: number = 0;
  /** 播放内核选择：auto / av / ffmpeg。 */
  @Local engineMode: string = 'auto';
  /** 低音增强（dB，0=关）。 */
  @Local bassDb: number = 0;
  @Local stereoWidenOn: boolean = false;
  @Local vocalRemoveOn: boolean = false;
  @Local nightModeOn: boolean = false;
  @Local reverbOn: boolean = false;
  @Local limiterOn: boolean = false;
  @Local haasOn: boolean = false;
  /** 自定义 EQ 预设（持久化在 eq_custom_presets）。 */
  @Local customPresets: CustomEqPreset[] = [];
  /** 滑杆去抖定时器（拖 EQ/升降调时不逐格下发）。 */
  private tuningTimer: number = -1;

  /** 内核选项表：自动 / 系统播放器 / FFmpeg。 */
  private static readonly ENGINE_MODES: EngineModeOption[] = [
    new EngineModeOption('mpv', 'mpv')
  ];

  /** 音效开关项。 */
  private static readonly EFFECT_TOGGLES: EffectToggle[] = [
    new EffectToggle('立体声增强', 'stereo'),
    new EffectToggle('人声消除', 'vocal'),
    new EffectToggle('夜间模式', 'night'),
    new EffectToggle('混响', 'reverb'),
    new EffectToggle('动态限幅', 'limiter'),
    new EffectToggle('声场展宽', 'haas')
  ];


  private store: MusicStoreService = MusicStoreService.getInstance();
  /** 与播放器共享的全局状态（只读倍速用于高亮）。 */
  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  aboutToAppear(): void {
    this.speed = this.appState.playbackRate;
    this.pitch = this.store.getTuningPitch();
    this.eqGains = this.store.getEqGains();
    this.presetName = this.matchPresetName(this.eqGains);
    this.engineMode = this.store.getEngineMode();
    const fx: AudioEffects = effectsFromJson(this.store.getAudioEffects());
    this.bassDb = fx.bassDb;
    this.stereoWidenOn = fx.stereoWiden !== 1.0;
    this.vocalRemoveOn = fx.vocalRemove;
    this.nightModeOn = fx.nightMode;
    this.reverbOn = fx.reverb;
    this.limiterOn = fx.limiter;
    this.haasOn = fx.haas;
    this.customPresets = this.parseCustomPresets(this.store.getEqPresets());
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
    this.scheduleTuning();
    appendPlayLog('[RzdTuning] pitch=' + semitones);
  }

  /** 应用某一段 EQ。 */
  private applyBand(index: number, gain: number): void {
    const next: number[] = this.eqGains.slice();
    next[index] = gain;
    this.eqGains = next;
    this.presetName = this.matchPresetName(next);
    this.store.setEqGains(next);
    this.scheduleTuning();
    appendPlayLog('[RzdTuning] eq[' + index + ']=' + gain);
  }

  /** @returns 指定音效开关是否开启。 */
  private isEffectOn(key: string): boolean {
    switch (key) {
      case 'stereo':
        return this.stereoWidenOn;
      case 'vocal':
        return this.vocalRemoveOn;
      case 'night':
        return this.nightModeOn;
      case 'reverb':
        return this.reverbOn;
      case 'limiter':
        return this.limiterOn;
      case 'haas':
        return this.haasOn;
      default:
        return false;
    }
  }

  /** 当前音效集合（用于下发与持久化）。 */
  private currentEffects(): AudioEffects {
    const fx: AudioEffects = new AudioEffects();
    fx.bassDb = this.bassDb;
    fx.stereoWiden = this.stereoWidenOn ? 1.6 : 1.0;
    fx.vocalRemove = this.vocalRemoveOn;
    fx.nightMode = this.nightModeOn;
    fx.reverb = this.reverbOn;
    fx.limiter = this.limiterOn;
    fx.haas = this.haasOn;
    return fx;
  }

  /** 持久化 + 去抖下发。 */
  private commitEffects(): void {
    this.store.setAudioEffects(effectsToJson(this.currentEffects()));
    this.scheduleTuning();
  }

  /** 低音增强。 */
  private applyBass(db: number): void {
    this.bassDb = db;
    appendPlayLog('[RzdAf] bass=' + db);
    this.commitEffects();
  }

  /** 切换某个音效开关。 */
  private toggleEffect(key: string): void {
    switch (key) {
      case 'stereo':
        this.stereoWidenOn = !this.stereoWidenOn;
        break;
      case 'vocal':
        this.vocalRemoveOn = !this.vocalRemoveOn;
        break;
      case 'night':
        this.nightModeOn = !this.nightModeOn;
        break;
      case 'reverb':
        this.reverbOn = !this.reverbOn;
        break;
      case 'limiter':
        this.limiterOn = !this.limiterOn;
        break;
      case 'haas':
        this.haasOn = !this.haasOn;
        break;
      default:
        break;
    }
    appendPlayLog('[RzdAf] toggle ' + key);
    this.commitEffects();
  }

  /** 全部关闭音效。 */
  private clearEffects(): void {
    this.bassDb = 0;
    this.stereoWidenOn = false;
    this.vocalRemoveOn = false;
    this.nightModeOn = false;
    this.reverbOn = false;
    this.limiterOn = false;
    this.haasOn = false;
    appendPlayLog('[RzdAf] clear');
    this.commitEffects();
  }

  /** 解析自定义预设 JSON（容错）。 */
  private parseCustomPresets(raw: string): CustomEqPreset[] {
    const out: CustomEqPreset[] = [];
    if (raw.length === 0) {
      return out;
    }
    try {
      const arr: CustomEqPreset[] = JSON.parse(raw) as CustomEqPreset[];
      for (let i: number = 0; i < arr.length; i++) {
        const item: CustomEqPreset = arr[i];
        if (item !== undefined && item.name !== undefined && Array.isArray(item.gains) && item.gains.length === 5) {
          out.push(new CustomEqPreset(item.name, item.gains));
        }
      }
    } catch (err) {
    }
    return out;
  }

  /** 把当前 5 段增益存成自定义预设（最多 6 个，重名自动加序号）。 */
  private saveCurrentAsPreset(): void {
    const list: CustomEqPreset[] = this.customPresets.slice();
    let seq: number = list.length + 1;
    let name: string = '自定义' + seq;
    while (list.some((p: CustomEqPreset): boolean => p.name === name)) {
      seq = seq + 1;
      name = '自定义' + seq;
    }
    list.push(new CustomEqPreset(name, this.eqGains));
    while (list.length > 6) {
      list.shift();
    }
    this.customPresets = list;
    this.store.setEqPresets(JSON.stringify(list));
    appendPlayLog('[RzdAf] 保存 EQ 预设 ' + name);
  }

  /** 应用某个自定义预设。 */
  private applyCustomPreset(preset: CustomEqPreset): void {
    this.eqGains = preset.gains.slice();
    this.presetName = preset.name;
    this.store.setEqGains(this.eqGains);
    this.scheduleTuning();
    appendPlayLog('[RzdAf] 应用自定义预设 ' + preset.name);
  }

  /** 长按删除某个自定义预设。 */
  private removeCustomPreset(preset: CustomEqPreset): void {
    const list: CustomEqPreset[] =
      this.customPresets.filter((p: CustomEqPreset): boolean => p.name !== preset.name);
    this.customPresets = list;
    this.store.setEqPresets(JSON.stringify(list));
    appendPlayLog('[RzdAf] 删除 EQ 预设 ' + preset.name);
  }


  /** 去抖：200ms 内多次改动只下发最后一次。 */
  private scheduleTuning(): void {
    if (this.tuningTimer >= 0) {
      clearTimeout(this.tuningTimer);
    }
    this.tuningTimer = setTimeout((): void => {
      this.tuningTimer = -1;
      MediaService.getInstance().refreshTuning();
    }, 200);
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
          // ★ 2026-11-01（用户：日间模式下胶囊和背景融在一起，看起来空空的）：未选中改用 panel_surface（日间 #F2F3F5 / 夜间 #1C1C1E），不加描边
          .backgroundColor(this.speed === rate ? this.themeStateColor() : $r('app.color.chip_surface'))
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
            // ★ 2026-11-01（用户：不要描边，直接改日间配色）：未选中用 panel_surface（日间 #F2F3F5 / 夜间 #1C1C1E）
            .backgroundColor(this.presetName === preset.name ?
              this.themeStateColor() : $r('app.color.chip_surface'))

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

      // 自定义预设（长按删除）
      if (this.customPresets.length > 0) {
        Row({ space: 8 }) {
          ForEach(this.customPresets, (item: CustomEqPreset) => {
            Button() {
              Text(item.name)
                .fontSize(13)
                .fontColor(this.presetName === item.name ?
                  $r('app.color.page_background') : $r('app.color.font_primary'))
            }
            .type(ButtonType.Capsule)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.presetName === item.name ?
              this.themeStateColor() : $r('app.color.background_secondary'))
            .onClick((): void => {
              this.applyCustomPreset(item);
            })
            .gesture(LongPressGesture().onAction((): void => {
              this.removeCustomPreset(item);
            }))
          }, (item: CustomEqPreset) => 'eq-custom-' + item.name)
        }
        .width('100%')
        .margin({ bottom: 8 })
      }

      Button() {
        Text('＋ 保存当前 EQ')
          .fontSize(13)
          .fontColor($r('app.color.font_primary'))
      }
      .type(ButtonType.Capsule)
      .height(28)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.background_secondary'))
      .margin({ bottom: 10 })
      .onClick((): void => {
        this.saveCurrentAsPreset();
      })

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

      // ===== 音效 =====
      Row() {
        Text('音效')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
        Text('全部关闭')
          .fontSize(12)
          .fontColor($r('app.color.font_tertiary'))
          .onClick((): void => {
            this.clearEffects();
          })
      }
      .width('100%')
      .margin({ top: 16, bottom: 8 })

      // 低音增强
      Row() {
        Text('低音增强')
          .fontSize(14)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
        Text(this.bassDb === 0 ? '关' : '+' + this.bassDb.toFixed(0) + 'dB')
          .fontSize(13)
          .fontColor(this.themeStateColor())
      }
      .width('100%')

      Slider({
        value: this.bassDb,
        min: 0,
        max: 12,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .blockColor(this.themeStateColor())
        .selectedColor(this.themeStateColor())
        .trackColor($r('app.color.background_secondary'))
        .onChange((value: number): void => {
          const db: number = Math.round(value);
          if (db !== this.bassDb) {
            this.applyBass(db);
          }
        })

      // 其它音效开关（胶囊）
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(PlaybackTuningPanel.EFFECT_TOGGLES, (item: EffectToggle) => {
          Button() {
            Text(item.label)
              .fontSize(13)
              .fontColor(this.isEffectOn(item.key) ?
                $r('app.color.page_background') : $r('app.color.font_primary'))
          }
          .type(ButtonType.Capsule)
          .height(30)
          .padding({ left: 14, right: 14 })
          .margin({ right: 8, top: 8 })
          .backgroundColor(this.isEffectOn(item.key) ?
            this.themeStateColor() : $r('app.color.background_secondary'))
          .onClick((): void => {
            this.toggleEffect(item.key);
          })
        }, (item: EffectToggle) => 'effect-' + item.key)
      }
      .width('100%')
      .margin({ top: 6 })

    }
    .width('100%')
    .padding({ top: 12 })
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
