import { getAudioContext, playClick, resumeAudio } from '../audio/click'

export type TimeSignature = 2 | 3 | 4

/** 1 = quarter only; 2 = silent eighths; 4 = silent sixteenths */
export type Subdivision = 1 | 2 | 4

export type TickInfo = {
  beatIndex: number
  subdivIndex: number
  accent: boolean
  audible: boolean
}

export type MetronomeOptions = {
  bpm?: number
  beatsPerBar?: TimeSignature
  subdivision?: Subdivision
  onTick?: (tick: TickInfo) => void
}

const LOOKAHEAD_MS = 25
const SCHEDULE_AHEAD = 0.12

export class MetronomeEngine {
  bpm = 100
  beatsPerBar: TimeSignature = 4
  subdivision: Subdivision = 1
  onTick: ((tick: TickInfo) => void) | null = null

  private running = false
  private timerId: number | null = null
  private nextNoteTime = 0
  private currentBeat = 0
  private currentSubdiv = 0

  constructor(opts: MetronomeOptions = {}) {
    if (opts.bpm != null) this.bpm = opts.bpm
    if (opts.beatsPerBar != null) this.beatsPerBar = opts.beatsPerBar
    if (opts.subdivision != null) this.subdivision = opts.subdivision
    if (opts.onTick) this.onTick = opts.onTick
  }

  get isRunning(): boolean {
    return this.running
  }

  setBpm(bpm: number): void {
    this.bpm = Math.min(240, Math.max(40, Math.round(bpm)))
  }

  setBeatsPerBar(n: TimeSignature): void {
    this.beatsPerBar = n
  }

  setSubdivision(n: Subdivision): void {
    this.subdivision = n
  }

  async start(): Promise<void> {
    if (this.running) return
    const ctx = await resumeAudio()
    this.running = true
    this.currentBeat = 0
    this.currentSubdiv = 0
    this.nextNoteTime = ctx.currentTime + 0.05
    this.scheduler()
    this.timerId = window.setInterval(() => this.scheduler(), LOOKAHEAD_MS)
  }

  stop(): void {
    this.running = false
    if (this.timerId != null) {
      clearInterval(this.timerId)
      this.timerId = null
    }
  }

  private secondsPerBeat(): number {
    return 60 / this.bpm
  }

  private secondsPerTick(): number {
    return this.secondsPerBeat() / this.subdivision
  }

  private scheduler(): void {
    if (!this.running) return
    const ctx = getAudioContext()
    while (this.nextNoteTime < ctx.currentTime + SCHEDULE_AHEAD) {
      const beat = this.currentBeat
      const subdiv = this.currentSubdiv
      const accent = beat === 0 && subdiv === 0
      const audible = subdiv === 0

      if (audible) {
        playClick(ctx, this.nextNoteTime, accent)
      }

      const when = this.nextNoteTime
      const delayMs = Math.max(0, (when - ctx.currentTime) * 1000)
      window.setTimeout(() => {
        this.onTick?.({ beatIndex: beat, subdivIndex: subdiv, accent, audible })
      }, delayMs)

      this.nextNoteTime += this.secondsPerTick()
      this.currentSubdiv += 1
      if (this.currentSubdiv >= this.subdivision) {
        this.currentSubdiv = 0
        this.currentBeat = (this.currentBeat + 1) % this.beatsPerBar
      }
    }
  }
}
