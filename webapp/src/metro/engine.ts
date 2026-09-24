import {
  getAudioContext,
  playTick,
  primeMetronomeAudio,
  resumeAudio,
  unlockAudioSync,
  type SoundId,
} from "../audio/voices";

export type TimeSignature = 2 | 3 | 4;

/** 1 = quarter only; 2 = eighths (+ upbeat); 4 = sixteenths (+ upbeats) */
export type Subdivision = 1 | 2 | 4;

export type TickInfo = {
  beatIndex: number;
  subdivIndex: number;
  accent: boolean;
  audible: boolean;
};

export type MetronomeOptions = {
  bpm?: number;
  beatsPerBar?: TimeSignature;
  subdivision?: Subdivision;
  sound?: SoundId;
  /** When true, only downbeats (quarters) click; upbeat visuals still run */
  muteUpbeats?: boolean;
  onTick?: (tick: TickInfo) => void;
};

const LOOKAHEAD_MS = 25;
const SCHEDULE_AHEAD = 0.12;

type PendingTick = {
  when: number;
  info: TickInfo;
};

export class MetronomeEngine {
  bpm = 100;
  beatsPerBar: TimeSignature = 4;
  subdivision: Subdivision = 1;
  sound: SoundId = "click";
  muteUpbeats = false;
  onTick: ((tick: TickInfo) => void) | null = null;

  private running = false;
  private timerId: number | null = null;
  private rafId: number | null = null;
  private nextNoteTime = 0;
  private currentBeat = 0;
  private currentSubdiv = 0;
  private pending: PendingTick[] = [];
  private lastEmittedKey = "";

  constructor(opts: MetronomeOptions = {}) {
    if (opts.bpm != null) this.bpm = opts.bpm;
    if (opts.beatsPerBar != null) this.beatsPerBar = opts.beatsPerBar;
    if (opts.subdivision != null) this.subdivision = opts.subdivision;
    if (opts.sound != null) this.sound = opts.sound;
    if (opts.muteUpbeats != null) this.muteUpbeats = opts.muteUpbeats;
    if (opts.onTick) this.onTick = opts.onTick;
  }

  get isRunning(): boolean {
    return this.running;
  }

  setBpm(bpm: number): void {
    this.bpm = Math.min(240, Math.max(40, Math.round(bpm)));
  }

  setBeatsPerBar(n: TimeSignature): void {
    this.beatsPerBar = n;
  }

  setSubdivision(n: Subdivision): void {
    this.subdivision = n;
  }

  setSound(id: SoundId): void {
    this.sound = id;
  }

  setMuteUpbeats(mute: boolean): void {
    this.muteUpbeats = mute;
  }

  async start(): Promise<boolean> {
    if (this.running) return true;
    unlockAudioSync();
    primeMetronomeAudio(this.sound);
    const ctx = await resumeAudio();
    if (ctx.state !== "running") {
      return false;
    }
    this.running = true;
    this.currentBeat = 0;
    this.currentSubdiv = 0;
    this.pending = [];
    this.lastEmittedKey = "";
    this.nextNoteTime = ctx.currentTime + 0.05;
    this.scheduler();
    this.timerId = window.setInterval(() => this.scheduler(), LOOKAHEAD_MS);
    this.pumpVisual();
    return true;
  }

  stop(): void {
    this.running = false;
    if (this.timerId != null) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
    if (this.rafId != null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
    this.pending = [];
    this.lastEmittedKey = "";
  }

  private secondsPerBeat(): number {
    return 60 / this.bpm;
  }

  private secondsPerTick(): number {
    return this.secondsPerBeat() / this.subdivision;
  }

  private scheduler(): void {
    if (!this.running) return;
    const ctx = getAudioContext();
    if (ctx.state !== "running") {
      unlockAudioSync();
      return;
    }
    while (this.nextNoteTime < ctx.currentTime + SCHEDULE_AHEAD) {
      const beat = this.currentBeat;
      const subdiv = this.currentSubdiv;
      const accent = beat === 0 && subdiv === 0;
      const upbeat = subdiv !== 0;
      const audible = !upbeat || !this.muteUpbeats;
      const when = Math.max(this.nextNoteTime, ctx.currentTime + 0.002);

      if (audible) {
        try {
          playTick(this.sound, ctx, when, accent, upbeat);
        } catch {
          /* ignore schedule glitches */
        }
      }

      this.pending.push({
        when,
        info: { beatIndex: beat, subdivIndex: subdiv, accent, audible },
      });

      this.nextNoteTime += this.secondsPerTick();
      this.currentSubdiv += 1;
      if (this.currentSubdiv >= this.subdivision) {
        this.currentSubdiv = 0;
        this.currentBeat = (this.currentBeat + 1) % this.beatsPerBar;
      }
    }
  }

  /** Align UI flashes to the audio clock via rAF (no per-tick setTimeout). */
  private pumpVisual = (): void => {
    if (!this.running) {
      this.rafId = null;
      return;
    }
    const now = getAudioContext().currentTime;
    let latest: TickInfo | null = null;
    while (this.pending.length > 0 && this.pending[0]!.when <= now + 0.008) {
      latest = this.pending.shift()!.info;
    }
    // Drop stale backlog if tab was throttled
    if (this.pending.length > 24) {
      this.pending.splice(0, this.pending.length - 8);
    }
    if (latest) {
      const key = `${latest.beatIndex}:${latest.subdivIndex}:${latest.accent ? 1 : 0}`;
      if (key !== this.lastEmittedKey) {
        this.lastEmittedKey = key;
        this.onTick?.(latest);
      }
    }
    this.rafId = requestAnimationFrame(this.pumpVisual);
  };
}
