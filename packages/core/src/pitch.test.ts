import { describe, expect, it } from "vitest";
import {
  GUITAR_OPEN_MIDI,
  centsFromTarget,
  freqToMidi,
  midiToFreq,
  midiToNearestNote,
  notePitchClass,
  noteToMidi,
} from "./pitch";

describe("notePitchClass", () => {
  it("parses naturals and accidentals", () => {
    expect(notePitchClass("C")).toBe(0);
    expect(notePitchClass("F#")).toBe(6);
    expect(notePitchClass("Bb")).toBe(10);
    expect(notePitchClass("E♭")).toBe(3);
  });

  it("returns null for invalid input", () => {
    expect(notePitchClass("")).toBeNull();
    expect(notePitchClass("X")).toBeNull();
  });
});

describe("noteToMidi", () => {
  it("maps spelled notes to MIDI (default octave 4)", () => {
    expect(noteToMidi("A")).toBe(69);
    expect(noteToMidi("C", 4)).toBe(60);
  });
});

describe("A4 = 440 Hz", () => {
  it("converts MIDI 69 to 440 Hz", () => {
    expect(midiToFreq(69)).toBeCloseTo(440, 5);
  });

  it("converts 440 Hz to MIDI 69", () => {
    expect(freqToMidi(440)).toBeCloseTo(69, 5);
  });

  it("round-trips open low E", () => {
    const midi = GUITAR_OPEN_MIDI[0]!;
    const freq = midiToFreq(midi);
    expect(freqToMidi(freq)).toBeCloseTo(midi, 4);
  });
});

describe("freqToMidi", () => {
  it("rejects non-positive or non-finite input", () => {
    expect(freqToMidi(0)).toBeNull();
    expect(freqToMidi(-1)).toBeNull();
    expect(freqToMidi(Number.NaN)).toBeNull();
  });
});

describe("centsFromTarget", () => {
  it("is zero at target and ±100 per semitone", () => {
    expect(centsFromTarget(69, 69)).toBe(0);
    expect(centsFromTarget(69.5, 69)).toBe(50);
    expect(centsFromTarget(68, 69)).toBe(-100);
  });
});

describe("midiToNearestNote", () => {
  it("names A4 at MIDI 69", () => {
    const n = midiToNearestNote(69);
    expect(n.name).toBe("A");
    expect(n.octave).toBe(4);
    expect(n.midiRounded).toBe(69);
  });
});

describe("GUITAR_OPEN_MIDI", () => {
  it("matches standard EADGBE from 6 → 1", () => {
    expect([...GUITAR_OPEN_MIDI]).toEqual([40, 45, 50, 55, 59, 64]);
  });
});
