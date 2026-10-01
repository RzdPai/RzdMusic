import { AppStorageV2, UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MORPH_HOST_ID } from './PlayerExpandState';

function playlistLengthToVp(value: Length | undefined): number {
  if (value === undefined) {
    return 0;
  }
  const result: number = typeof value === 'number' ? value : Number.parseFloat(value.toString());
  return Number.isFinite(result) ? result : 0;
}

export const PLAYLIST_HERO_COVER_ID: string = 'rzd_playlist_hero_cover';
export const PLAYLIST_TRANSITION_HOST_ID: string = 'rzd_playlist_transition_host';

export class PlaylistTransitionRect {
  public x: number = 0;
  public y: number = 0;
  public width: number = 0;
  public height: number = 0;
}

/** Playlist-only bridge. Session ownership survives entry settlement, not a new entry. */
@ObservedV2
export class PlaylistTransitionState {
  @Trace public hostReady: boolean = false;
  @Trace public active: boolean = false;
  @Trace public returning: boolean = false;
  @Trace public progress: number = 1;
  @Trace public cover: string = '';
  @Trace public source: PlaylistTransitionRect = new PlaylistTransitionRect();
  @Trace public target: PlaylistTransitionRect = new PlaylistTransitionRect();
  @Trace public hostX: number = 0;
  @Trace public hostY: number = 0;
  private generation: number = 0;
  private session: number = 0;
  private claimed: boolean = false;
  private sourceId: string = '';
  private running: boolean = false;
  private destinationId: string = '';
  private proxyEpoch: number = 0;
  @Trace public returnPageOpacity: number = 1;

  private currentCover: () => string = (): string => '';

  public bindDestination(token: number, id: string, currentCover: () => string): void {
    if (this.owns(token)) {
      this.destinationId = id;
      this.currentCover = currentCover;
    }
  }

  /** Navigation-level ownership of BOTH sides: no default NavBar slide, no extra POP. */
  public navigationReturn(ui: UIContext, from: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    if (operation !== NavigationOperation.POP || from.navDestinationId !== this.destinationId ||
      this.destinationId.length === 0 || !this.owns(this.session)) {
      return undefined;
    }
    const token: number = this.session;
    const epoch: number = ++this.proxyEpoch;
    let settled: boolean = false;
    return {
      timeout: 1400,
      transition: (proxy: NavigationTransitionProxy): void => {
        this.cancel('proxy-begin');
        this.returnPageOpacity = 1;
        // The receiving page is retained by the framework during this transaction.
        // Yield layout, then bounded remeasure. Only this SAME proxy is ever finished.
        const finish = (): void => {
          if (!settled && epoch === this.proxyEpoch) {
            settled = true;
            proxy.finishTransition();
          }
        };
        const attempt = (count: number): void => {
          if (settled || epoch !== this.proxyEpoch || !this.owns(token)) {
            return;
          }
          const generation: number = this.prepareReturn(ui, this.currentCover(), token);
          if (generation === 0 && count < 12) {
            setTimeout((): void => {
              attempt(count + 1);
            }, 32);
            return;
          }
          hilog.info(0, 'RzdPlaylistTransition', 'proxy layout ready session=%{public}d attempt=%{public}d clone=%{public}d',
            token, count, generation > 0 ? 1 : 0);
          ui.animateTo({
            duration: generation > 0 ? 360 : 180,
            curve: Curve.EaseInOut,
            onFinish: (): void => {
              if (epoch === this.proxyEpoch && this.owns(token)) {
                this.finishReturn(token, generation);
                finish();
              }
            }
          }, (): void => {
            this.driveReturn(token, generation);
            this.returnPageOpacity = 0;
          });
        };
        setTimeout((): void => {
          attempt(0);
        }, 0);
      },
      onTransitionEnd: (success: boolean): void => {
        if (epoch === this.proxyEpoch) {
          settled = true;
          this.proxyEpoch++;
          this.cancel(success ? 'proxy-finished' : 'proxy-cancelled');
          this.returnPageOpacity = 1;
          hilog.info(0, 'RzdPlaylistTransition', 'proxy end session=%{public}d success=%{public}s', token, String(success));
        }
      }
    };
  }

  private measure(ui: UIContext, id: string): PlaylistTransitionRect | undefined {
    try {
      const node = ui.getFrameNodeById(id);
      if (node === null) {
        return undefined;
      }
      const position: Position = node.getPositionToWindowWithTransform();
      const size: Size = node.getMeasuredSize();
      const rect: PlaylistTransitionRect = new PlaylistTransitionRect();
      rect.x = playlistLengthToVp(position.x);
      rect.y = playlistLengthToVp(position.y);
      rect.width = ui.px2vp(size.width);
      rect.height = ui.px2vp(size.height);
      return Number.isFinite(rect.x) && Number.isFinite(rect.y) &&
        rect.width > 0 && rect.height > 0 ? rect : undefined;
    } catch (err) {
      hilog.warn(0, 'RzdPlaylistTransition', 'measure failed id=%{public}s %{public}s', id, String(err));
      return undefined;
    }
  }

  /** Called before push. No delayed route mutations are performed by this state. */
  public prepare(ui: UIContext, sourceId: string, cover: string): boolean {
    this.cancel('new-entry');
    this.session++;
    this.proxyEpoch++;
    this.destinationId = '';
    this.returnPageOpacity = 1;
    this.claimed = false;
    this.sourceId = '';
    if (!this.hostReady || cover.length === 0) {
      return false;
    }
    const source: PlaylistTransitionRect | undefined = this.measure(ui, sourceId);
    const host: PlaylistTransitionRect | undefined = this.measure(ui, MORPH_HOST_ID);
    if (source === undefined || host === undefined) {
      hilog.warn(0, 'RzdPlaylistTransition', 'fallback source/host missing id=%{public}s', sourceId);
      return false;
    }
    this.sourceId = sourceId;
    this.hostX = host.x;
    this.hostY = host.y;
    this.source = source;
    this.target = source;
    this.cover = cover;
    this.progress = 0;
    this.active = true;
    const generation: number = this.generation;
    hilog.info(0, 'RzdPlaylistTransition', 'prepare session=%{public}d gen=%{public}d source=%{public}s rect=%{public}s',
      this.session, generation, sourceId, JSON.stringify(source));
    setTimeout((): void => {
      if (this.generation === generation && this.active && !this.running) {
        this.cancel('target-timeout');
      }
    }, 600);
    return true;
  }

  /** One destination claims the prepared entry; same-cover nested pages cannot steal it. */
  public claim(cover: string): number {
    if (!this.active || this.claimed || this.cover !== cover) {
      return 0;
    }
    this.claimed = true;
    return this.session;
  }

  public owns(token: number): boolean {
    return token > 0 && this.claimed && token === this.session && this.sourceId.length > 0;
  }

  public matches(cover: string, token: number = 0): boolean {
    return this.owns(token) && this.active && cover.length > 0 && this.cover === cover;
  }

  /** Called only by the owning hero, before scaling or translating its page. */
  public start(ui: UIContext, cover: string, token: number, attempt: number = 0): void {
    if (!this.matches(cover, token) || this.running || this.returning) {
      return;
    }
    const generation: number = this.generation;
    const target: PlaylistTransitionRect | undefined = this.measure(ui, PLAYLIST_HERO_COVER_ID);
    if (target === undefined) {
      if (attempt < 12) {
        setTimeout((): void => {
          if (generation === this.generation && this.owns(token)) {
            this.start(ui, cover, token, attempt + 1);
          }
        }, 32);
      } else {
        this.cancel('target-unmeasurable');
      }
      return;
    }
    this.target = target;
    this.running = true;
    hilog.info(0, 'RzdPlaylistTransition', 'entry start session=%{public}d gen=%{public}d target=%{public}s',
      token, generation, JSON.stringify(target));
    ui.animateTo({
      duration: 360,
      curve: Curve.EaseInOut,
      onFinish: (): void => {
        if (this.generation === generation && this.owns(token)) {
          this.cancel('entry-finished');
        }
      }
    }, (): void => {
      this.progress = 1;
    });
  }

  /** POP delegate: measure both current hero and source AGAIN, never fly to entry snapshots. */
  public prepareReturn(ui: UIContext, cover: string, token: number): number {
    if (!this.owns(token) || !this.hostReady || cover !== this.cover) {
      return 0;
    }
    this.cancel('return-prepare');
    const source: PlaylistTransitionRect | undefined = this.measure(ui, this.sourceId);
    const hero: PlaylistTransitionRect | undefined = this.measure(ui, PLAYLIST_HERO_COVER_ID);
    const host: PlaylistTransitionRect | undefined = this.measure(ui, MORPH_HOST_ID);
    // Reject offscreen/recycled source cards; do not reuse a stale frozen entry rect.
    if (source === undefined || hero === undefined || host === undefined ||
      source.x + source.width <= host.x || source.y + source.height <= host.y ||
      source.x >= host.x + host.width || source.y >= host.y + host.height ||
      hero.y + hero.height <= host.y || hero.y >= host.y + host.height) {
      hilog.warn(0, 'RzdPlaylistTransition', 'return fallback session=%{public}d source=%{public}s missing/offscreen/cover-changed',
        token, this.sourceId);
      return 0;
    }
    this.hostX = host.x;
    this.hostY = host.y;
    this.source = source;
    this.target = hero;
    this.progress = 1;
    this.returning = true;
    this.running = true;
    this.active = true;
    hilog.info(0, 'RzdPlaylistTransition', 'return measured session=%{public}d gen=%{public}d source=%{public}s hero=%{public}s host=%{public}s',
      token, this.generation, JSON.stringify(source), JSON.stringify(hero), JSON.stringify(host));
    return this.generation;
  }

  /** Runs INSIDE the system NavDestinationTransition.event animation transaction. */
  public driveReturn(token: number, generation: number): void {
    if (this.owns(token) && this.generation === generation && this.returning) {
      this.progress = 0;
    }
  }

  public finishReturn(token: number, generation: number): void {
    if (this.owns(token) && this.generation === generation) {
      this.cancel('return-finished');
    }
  }

  public release(token: number): void {
    if (this.owns(token)) {
      this.cancel('detail-disappear');
      this.claimed = false;
      this.sourceId = '';
      this.destinationId = '';
      this.currentCover = (): string => '';
    }
  }

  public rect(): PlaylistTransitionRect {
    const rect: PlaylistTransitionRect = new PlaylistTransitionRect();
    const p: number = this.progress;
    rect.x = this.source.x + (this.target.x - this.source.x) * p - this.hostX;
    rect.y = this.source.y + (this.target.y - this.source.y) * p - this.hostY;
    rect.width = this.source.width + (this.target.width - this.source.width) * p;
    rect.height = this.source.height + (this.target.height - this.source.height) * p;
    return rect;
  }

  public cancel(reason: string): void {
    this.generation++;
    this.active = false;
    this.returning = false;
    this.running = false;
    this.progress = 1;
    hilog.info(0, 'RzdPlaylistTransition', 'settle reason=%{public}s gen=%{public}d', reason, this.generation);
  }
}

export function getPlaylistTransitionState(): PlaylistTransitionState {
  return AppStorageV2.connect(PlaylistTransitionState, 'rzdPlaylistTransition',
    (): PlaylistTransitionState => new PlaylistTransitionState())!;
}
