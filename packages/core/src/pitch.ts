/** Concert pitch helpers (A4 = 440). No audio I/O. */

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

/** Continuous MIDI from Hz (A4 = 69 @ 440 Hz). */
export function freqToMidi(freq: number): number | null {
  if (!Number.isFinite(freq) || freq <= 0) return null;
  return 69 + 12 * Math.log2(freq / 440);
}

const SHARP_NAMES = [
  "C",
  "C#",
  "D",
  "D#",
  "E",
  "F",
  "F#",
  "G",
  "G#",
  "A",
  "A#",
  "B",
] as const;

/** Nearest spelled note + cents offset (−50…+50 before wrap). */
export function midiToNearestNote(midi: number): {
  name: string;
  octave: number;
  cents: number;
  midiRounded: number;
} {
  const midiRounded = Math.round(midi);
  const cents = (midi - midiRounded) * 100;
  const pc = ((midiRounded % 12) + 12) % 12;
  const octave = Math.floor(midiRounded / 12) - 1;
  return { name: SHARP_NAMES[pc]!, octave, cents, midiRounded };
}

/** Cents from a target MIDI pitch (e.g. open string). */
export function centsFromTarget(midi: number, targetMidi: number): number {
  return (midi - targetMidi) * 100;
}

/** Standard guitar open strings, thick → thin (6 → 1). */
export const GUITAR_OPEN_MIDI = [40, 45, 50, 55, 59, 64] as const;
