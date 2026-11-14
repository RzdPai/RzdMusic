import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys } from '../constants/Constants';
import { MusicAppState } from '../model/MusicAppState';
import { PlayerExpandState } from '../model/PlayerExpandState';
import { Logger } from './Logger';

/**
 * Consume destination back before Navigation pops the page underneath the shell player.
 * Read the shared V2 state at event time, independent of the destination's local path stack.
 * Returning false preserves the destination's original back handling/default pop.
 */
export function guardPlayerBack(source: string): boolean {
  const appState: MusicAppState = AppStorageV2.connect(MusicAppState,
    AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  const expandState: PlayerExpandState = AppStorageV2.connect(PlayerExpandState,
    AppStorageKeys.PLAYER_EXPAND_STATE, () => new PlayerExpandState())!;
  const pending: boolean = expandState.preparing || expandState.animating ||
    expandState.pullDragging || expandState.morphLive();
  if (!appState.isShowPlay && !pending) {
    return false;
  }
  expandState.requestCollapse();
  Logger.info('RzdPlayerBackGuard', `consume source=${source} shown=${appState.isShowPlay}` +
    ` pending=${pending} stage=${expandState.morphStage} collapse=${expandState.collapseVersion}`);
  return true;
}
