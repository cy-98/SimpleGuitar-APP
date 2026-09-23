import { describe, expect, it } from "vitest";
import {
  FRET_MAX,
  FRET_MIN,
  getPosition,
  inPosition,
  noteMidiAt,
  scaleDots,
} from "./fretboard";

describe("noteMidiAt", () => {
  it("adds fret to open string MIDI", () => {
    expect(noteMidiAt(0, 0)).toBe(64);
    expect(noteMidiAt(5, 0)).toBe(40);
    expect(noteMidiAt(5, 2)).toBe(42);
  });
});

describe("inPosition", () => {
  it("includes all frets for “全部”", () => {
    const all = getPosition("all");
    expect(inPosition(0, all)).toBe(true);
    expect(inPosition(FRET_MAX, all)).toBe(true);
  });

  it("respects fret windows", () => {
    const open = getPosition("open");
    expect(inPosition(0, open)).toBe(true);
    expect(inPosition(4, open)).toBe(true);
    expect(inPosition(5, open)).toBe(false);
  });
});

describe("scaleDots", () => {
  it("aligns dot MIDI with string and fret", () => {
    const dots = scaleDots("C");
    expect(dots.length).toBeGreaterThan(0);
    for (const d of dots) {
      expect(d.midi).toBe(noteMidiAt(d.string, d.fret));
      expect(d.fret).toBeGreaterThanOrEqual(FRET_MIN);
      expect(d.fret).toBeLessThanOrEqual(FRET_MAX);
    }
  });

  it("marks tonics as degree 1", () => {
    const dots = scaleDots("G");
    const tonics = dots.filter((d) => d.isTonic);
    expect(tonics.length).toBeGreaterThan(0);
    expect(tonics.every((d) => d.degree.degree === 1)).toBe(true);
  });

  it("only uses scale pitch classes", () => {
    const dots = scaleDots("A");
    const pcs = new Set(
      dots.map((d) => ((d.midi % 12) + 12) % 12),
    );
    expect(pcs.size).toBe(7);
  });
});
