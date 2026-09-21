/** Concert pitches for theory chart (A4 = 440) + Web Audio sung tones. */

import { midiToFreq, noteToMidi } from "@scale-pulse/core";
import {
  getAudioContext,
  getMasterVolume,
  resumeAudio,
} from "./voices";

export { notePitchClass, noteToMidi, midiToFreq } from "@scale-pulse/core";

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
