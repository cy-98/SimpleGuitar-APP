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
