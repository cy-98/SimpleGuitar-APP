import { describe, expect, it } from "vitest";
import {
  MAJOR_KEYS,
  degreesByLetter,
  isMajorKey,
  majorScaleDegrees,
  majorScaleNotes,
} from "./scales";

describe("majorScaleNotes", () => {
  it("spells C major with naturals", () => {
    expect(majorScaleNotes("C")).toEqual([
      "C",
      "D",
      "E",
      "F",
      "G",
      "A",
      "B",
    ]);
  });

  it("uses correct enharmonics for sharp keys", () => {
    expect(majorScaleNotes("F#")).toContain("E#");
    expect(majorScaleNotes("F#")).toHaveLength(7);
  });

  it("uses flats for flat keys", () => {
    expect(majorScaleNotes("Bb")).toEqual([
      "Bb",
      "C",
      "D",
      "Eb",
      "F",
      "G",
      "A",
    ]);
  });
});

describe("majorScaleDegrees", () => {
  it("assigns degrees 1–7 and solfege", () => {
    const d = majorScaleDegrees("G");
    expect(d.map((x) => x.degree)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(d[0]!.note).toBe("G");
    expect(d[0]!.solfege).toBe("Do");
  });
});

describe("degreesByLetter", () => {
  it("maps natural letters to scale degrees in key order", () => {
    const map = degreesByLetter("D");
    expect(map.get("D")!.degree).toBe(1);
    expect(map.get("E")!.degree).toBe(2);
    expect(map.get("C")!.degree).toBe(7);
  });
});

describe("isMajorKey", () => {
  it("accepts listed keys only", () => {
    expect(isMajorKey("C")).toBe(true);
    expect(isMajorKey("Db")).toBe(true);
    expect(isMajorKey("Am")).toBe(false);
    expect(MAJOR_KEYS).toContain("F#");
  });
});
