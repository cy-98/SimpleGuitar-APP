/** Standard guitar fretboard helpers for scale-degree practice. */

import {
  majorScaleDegrees,
  type MajorKey,
  type ScaleDegree,
} from "./scales";
import { notePitchClass } from "./pitch";

/** String index 0 = high E (top of diagram), 5 = low E (bottom). */
export type StringIndex = 0 | 1 | 2 | 3 | 4 | 5;

/** Open-string MIDI (A4=440): high E4 … low E2 */
export const STANDARD_TUNING_MIDI: readonly number[] = [
  64, // E4
  59, // B3
  55, // G3
  50, // D3
  45, // A2
  40, // E2
] as const;

export const FRET_MIN = 0;
export const FRET_MAX = 12;

export type PositionId =
  | "all"
  | "mid-low"
  | "mid"
  | "mid-high"
  | "high";

export type FretPosition = {
  id: PositionId;
  label: string;
  fretFrom: number;
  fretTo: number;
};

/** Fret windows for first-version position practice (overlapping boxes). */
export const POSITIONS: readonly FretPosition[] = [
  { id: "all", label: "全部", fretFrom: FRET_MIN, fretTo: FRET_MAX },
  { id: "mid-low", label: "3–7", fretFrom: 3, fretTo: 7 },
  { id: "mid", label: "5–9", fretFrom: 5, fretTo: 9 },
  { id: "mid-high", label: "7–11", fretFrom: 7, fretTo: 11 },
  { id: "high", label: "9–12", fretFrom: 9, fretTo: 12 },
] as const;

export type FretDot = {
  string: StringIndex;
  fret: number;
  midi: number;
  degree: ScaleDegree;
  isTonic: boolean;
};

export function getPosition(id: PositionId): FretPosition {
  return POSITIONS.find((p) => p.id === id) ?? POSITIONS[0]!;
}

export function inPosition(fret: number, pos: FretPosition): boolean {
  if (pos.id === "all") return true;
  return fret >= pos.fretFrom && fret <= pos.fretTo;
}

export function noteMidiAt(string: StringIndex, fret: number): number {
  return STANDARD_TUNING_MIDI[string]! + fret;
}

function degreeByPitchClass(key: MajorKey): Map<number, ScaleDegree> {
  const degrees = majorScaleDegrees(key);
  const map = new Map<number, ScaleDegree>();
  for (const d of degrees) {
    const pc = notePitchClass(d.note);
    if (pc != null) map.set(pc, d);
  }
  return map;
}

export function scaleDots(key: MajorKey): FretDot[] {
  const byPc = degreeByPitchClass(key);
  const dots: FretDot[] = [];
  for (let s = 0; s < 6; s++) {
    for (let fret = FRET_MIN; fret <= FRET_MAX; fret++) {
      const midi = noteMidiAt(s as StringIndex, fret);
      const pc = ((midi % 12) + 12) % 12;
      const degree = byPc.get(pc);
      if (!degree) continue;
      dots.push({
        string: s as StringIndex,
        fret,
        midi,
        degree,
        isTonic: degree.degree === 1,
      });
    }
  }
  return dots;
}
