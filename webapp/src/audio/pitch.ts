/** Concert pitches for theory chart (A4 = 440). */

import {
  getAudioContext,
  getMasterVolume,
  resumeAudio,
} from "./voices";

const NATURAL_PC: Record<string, number> = {
  C: 0,
  D: 2,
  E: 4,
  F: 5,
  G: 7,
  A: 9,
  B: 11,
};

/** Parse spelled note (C, F#, Bb, E♭…) → pitch class 0–11. */
export function notePitchClass(note: string): number | null {
  const letter = note[0]?.toUpperCase();
  if (!letter || !(letter in NATURAL_PC)) return null;
  let accidental = 0;
  for (const ch of note.slice(1)) {
    if (ch === "#" || ch === "\u266F") accidental += 1;
    else if (ch === "b" || ch === "\u266D") accidental -= 1;
  }
  return (NATURAL_PC[letter]! + accidental + 120) % 12;
}

/** MIDI note for spelled pitch; default octave 4 (C4–B4). */
export function noteToMidi(note: string, octave = 4): number | null {
  const pc = notePitchClass(note);
  if (pc == null) return null;
  return (octave + 1) * 12 + pc;
}

export function midiToFreq(midi: number): number {
  return 440 * 2 ** ((midi - 69) / 12);
}

/** Soft sung tone at an absolute MIDI pitch. */
export async function playSungMidi(midi: number): Promise<void> {
  const ctx = await resumeAudio();
  const freq = midiToFreq(midi);
  const t = ctx.currentTime + 0.01;
  const master = Math.min(1, Math.max(0, getMasterVolume()));

  const osc = ctx.createOscillator();
  const osc2 = ctx.createOscillator();
  const gain = ctx.createGain();
  const filter = ctx.createBiquadFilter();

  osc.type = "sine";
  osc2.type = "triangle";
  osc.frequency.setValueAtTime(freq, t);
  osc2.frequency.setValueAtTime(freq, t);

  filter.type = "lowpass";
  filter.frequency.setValueAtTime(Math.min(3200, freq * 4), t);

  osc.connect(filter);
  osc2.connect(filter);
  filter.connect(gain);
  gain.connect(ctx.destination);

  const peak = 0.22 * master;
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(peak, t + 0.025);
  gain.gain.exponentialRampToValueAtTime(peak * 0.55, t + 0.18);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.55);

  osc.start(t);
  osc2.start(t);
  osc.stop(t + 0.6);
  osc2.stop(t + 0.6);
}

/** Soft sung tone for the selected tonic / scale degree pitch. */
export async function playSungNote(
  note: string,
  octave = 4,
): Promise<void> {
  const midi = noteToMidi(note, octave);
  if (midi == null) return;
  await playSungMidi(midi);
}
