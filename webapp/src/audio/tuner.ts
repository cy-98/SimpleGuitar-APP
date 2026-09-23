/** Live pitch detection from microphone (YIN-style). */

import {
  centsFromTarget,
  freqToMidi,
  GUITAR_OPEN_MIDI,
  midiToNearestNote,
} from "@scale-pulse/core";
import { resumeAudio } from "./voices";

export type TunerStringId = 1 | 2 | 3 | 4 | 5 | 6;

export type StringTargets = Record<TunerStringId, number>;

export type TunerReading = {
  freq: number;
  midi: number;
  note: string;
  octave: number;
  cents: number;
  stringId: TunerStringId;
  inTune: boolean;
  level: number;
};

export type TunerListener = (reading: TunerReading | null) => void;

/** Tab staff top → bottom; columns left → right = 6 弦 … 1 弦. */
export const TUNER_TAB_COLUMNS: readonly TunerStringId[] = [6, 5, 4, 3, 2, 1];

/** Tab notation string names (1 弦 = lowercase e). */
export const TAB_STRING_NAMES: Record<TunerStringId, string> = {
  6: "E",
  5: "A",
  4: "D",
  3: "G",
  2: "B",
  1: "e",
};

const YIN_THRESHOLD = 0.12;
const MIN_FREQ = 65;
const MAX_FREQ = 520;
const IN_TUNE_CENTS = 5;
const RMS_GATE = 0.008;

export const TUNER_MIDI_MIN = GUITAR_OPEN_MIDI[0]! - 6;
export const TUNER_MIDI_MAX = GUITAR_OPEN_MIDI[5]! + 6;

const STORAGE_KEY = "scale-pulse-custom-tuning";

export function defaultStringTargets(): StringTargets {
  return {
    6: GUITAR_OPEN_MIDI[0]!,
    5: GUITAR_OPEN_MIDI[1]!,
    4: GUITAR_OPEN_MIDI[2]!,
    3: GUITAR_OPEN_MIDI[3]!,
    2: GUITAR_OPEN_MIDI[4]!,
    1: GUITAR_OPEN_MIDI[5]!,
  };
}

export function readStoredTargets(): StringTargets {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaultStringTargets();
    const parsed = JSON.parse(raw) as Partial<Record<string, number>>;
    const base = defaultStringTargets();
    for (const id of TUNER_TAB_COLUMNS) {
      const v = parsed[String(id)];
      if (typeof v === "number" && Number.isFinite(v)) {
        base[id] = Math.round(
          Math.max(TUNER_MIDI_MIN, Math.min(TUNER_MIDI_MAX, v)),
        );
      }
    }
    return base;
  } catch {
    return defaultStringTargets();
  }
}

export function storeTargets(targets: StringTargets): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(targets));
  } catch {
    /* ignore */
  }
}

export function tabStringName(id: TunerStringId): string {
  return TAB_STRING_NAMES[id];
}

export function columnIndexForString(id: TunerStringId): number {
  return TUNER_TAB_COLUMNS.indexOf(id);
}

/** 0% = top (high pitch), 100% = bottom. */
export function midiToLanePercent(midi: number): number {
  const span = TUNER_MIDI_MAX - TUNER_MIDI_MIN;
  const t = (TUNER_MIDI_MAX - midi) / span;
  return Math.max(0, Math.min(100, t * 100));
}

export function lanePercentForTarget(midi: number): number {
  return midiToLanePercent(midi);
}

export function percentToMidi(percent: number): number {
  const t = Math.max(0, Math.min(100, percent)) / 100;
  return TUNER_MIDI_MAX - t * (TUNER_MIDI_MAX - TUNER_MIDI_MIN);
}

/** Horizontal nudge within a column (−50…+50 cents → roughly ±42%). */
export function centsToColumnShift(cents: number): number {
  const c = Math.max(-50, Math.min(50, cents));
  return (c / 50) * 42;
}

function rms(buffer: Float32Array): number {
  let sum = 0;
  for (let i = 0; i < buffer.length; i++) {
    const x = buffer[i]!;
    sum += x * x;
  }
  return Math.sqrt(sum / buffer.length);
}

function yinPitch(
  buffer: Float32Array,
  sampleRate: number,
  threshold = YIN_THRESHOLD,
): number | null {
  const size = buffer.length;
  const half = Math.floor(size / 2);
  const yin = new Float32Array(half);
  yin[0] = 1;

  let running = 0;
  for (let tau = 1; tau < half; tau++) {
    let sum = 0;
    for (let i = 0; i < half; i++) {
      const d = buffer[i]! - buffer[i + tau]!;
      sum += d * d;
    }
    yin[tau] = sum;
    running += yin[tau]!;
    yin[tau] = running > 0 ? (yin[tau]! * tau) / running : 1;
  }

  const minTau = Math.max(2, Math.floor(sampleRate / MAX_FREQ));
  const maxTau = Math.min(half - 1, Math.ceil(sampleRate / MIN_FREQ));

  let bestTau = -1;
  for (let tau = minTau; tau <= maxTau; tau++) {
    if (yin[tau]! < threshold) {
      while (tau + 1 <= maxTau && yin[tau + 1]! < yin[tau]!) {
        tau++;
      }
      bestTau = tau;
      break;
    }
  }

  if (bestTau < 0) {
    let minVal = Infinity;
    for (let tau = minTau; tau <= maxTau; tau++) {
      if (yin[tau]! < minVal) {
        minVal = yin[tau]!;
        bestTau = tau;
      }
    }
    if (minVal >= threshold * 1.4) return null;
  }

  const x0 = bestTau > 0 ? bestTau - 1 : bestTau;
  const x2 = bestTau + 1 < half ? bestTau + 1 : bestTau;
  const s0 = yin[x0]!;
  const s1 = yin[bestTau]!;
  const s2 = yin[x2]!;
  const denom = 2 * s1 - s2 - s0;
  const betterTau =
    Math.abs(denom) > 1e-6 ? bestTau + (s2 - s0) / (2 * denom) : bestTau;

  const freq = sampleRate / betterTau;
  if (!Number.isFinite(freq) || freq < MIN_FREQ || freq > MAX_FREQ) return null;
  return freq;
}

function nearestString(midi: number, targets: StringTargets): TunerStringId {
  let best: TunerStringId = 6;
  let bestDist = Infinity;
  for (const id of TUNER_TAB_COLUMNS) {
    const dist = Math.abs(midi - targets[id]);
    if (dist < bestDist) {
      bestDist = dist;
      best = id;
    }
  }
  return best;
}

export class TunerEngine {
  private stream: MediaStream | null = null;
  private source: MediaStreamAudioSourceNode | null = null;
  private analyser: AnalyserNode | null = null;
  private buffer: Float32Array | null = null;
  private raf = 0;
  private smoothMidi: number | null = null;
  private targets: StringTargets = defaultStringTargets();

  onReading: TunerListener | null = null;

  get isListening(): boolean {
    return this.raf !== 0;
  }

  setTargets(targets: StringTargets): void {
    this.targets = { ...targets };
  }

  async start(): Promise<void> {
    if (this.isListening) return;
    const ctx = await resumeAudio();
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
      },
      video: false,
    });
    this.stream = stream;
    this.source = ctx.createMediaStreamSource(stream);
    this.analyser = ctx.createAnalyser();
    this.analyser.fftSize = 4096;
    this.analyser.smoothingTimeConstant = 0;
    this.source.connect(this.analyser);
    this.buffer = new Float32Array(this.analyser.fftSize);
    this.smoothMidi = null;
    const tick = () => {
      this.sample();
      this.raf = requestAnimationFrame(tick);
    };
    this.raf = requestAnimationFrame(tick);
  }

  stop(): void {
    if (this.raf) {
      cancelAnimationFrame(this.raf);
      this.raf = 0;
    }
    this.source?.disconnect();
    this.source = null;
    this.analyser = null;
    this.buffer = null;
    if (this.stream) {
      for (const track of this.stream.getTracks()) track.stop();
      this.stream = null;
    }
    this.smoothMidi = null;
    this.emit(null);
  }

  private emit(reading: TunerReading | null): void {
    this.onReading?.(reading);
  }

  private sample(): void {
    if (!this.analyser || !this.buffer) return;
    this.analyser.getFloatTimeDomainData(this.buffer);
    const level = rms(this.buffer);
    if (level < RMS_GATE) {
      this.smoothMidi = null;
      this.emit(null);
      return;
    }

    const freq = yinPitch(this.buffer, this.analyser.context.sampleRate);
    if (freq == null) {
      this.emit(null);
      return;
    }

    const midiRaw = freqToMidi(freq);
    if (midiRaw == null) {
      this.emit(null);
      return;
    }

    const alpha = 0.35;
    this.smoothMidi =
      this.smoothMidi == null
        ? midiRaw
        : this.smoothMidi + alpha * (midiRaw - this.smoothMidi);

    const midi = this.smoothMidi;
    const nearest = midiToNearestNote(midi);
    const stringId = nearestString(midi, this.targets);
    const targetMidi = this.targets[stringId];
    const cents = centsFromTarget(midi, targetMidi);

    const reading: TunerReading = {
      freq,
      midi,
      note: nearest.name,
      octave: nearest.octave,
      cents,
      stringId,
      inTune: Math.abs(cents) <= IN_TUNE_CENTS,
      level,
    };
    this.emit(reading);
  }
}
