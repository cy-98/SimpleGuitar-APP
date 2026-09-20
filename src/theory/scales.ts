/** Pitch-class of natural letter names (C=0). */
const NATURAL_PC: Record<string, number> = {
  C: 0,
  D: 2,
  E: 4,
  F: 5,
  G: 7,
  A: 9,
  B: 11,
}

const LETTERS = ['C', 'D', 'E', 'F', 'G', 'A', 'B'] as const

/** Major scale: W W H W W W H in semitones from root. */
export const MAJOR_INTERVALS = [0, 2, 4, 5, 7, 9, 11] as const

export const SOLFEGE = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti'] as const

/** Common major keys (sharp-side then flat-side). */
export const MAJOR_KEYS = [
  'C',
  'G',
  'D',
  'A',
  'E',
  'B',
  'F#',
  'F',
  'Bb',
  'Eb',
  'Ab',
  'Db',
] as const

export type MajorKey = (typeof MAJOR_KEYS)[number]

export type ScaleDegree = {
  degree: number
  solfege: string
  note: string
}

function parseRoot(root: string): { letter: string; accidental: number } {
  const letter = root[0]!.toUpperCase()
  const rest = root.slice(1)
  let accidental = 0
  for (const ch of rest) {
    if (ch === '#' || ch === '\u266F') accidental += 1
    else if (ch === 'b' || ch === '\u266D') accidental -= 1
  }
  if (!(letter in NATURAL_PC)) {
    throw new Error(`Invalid root: ${root}`)
  }
  return { letter, accidental }
}

function formatAccidental(n: number): string {
  if (n === 0) return ''
  if (n > 0) return '#'.repeat(n)
  return 'b'.repeat(-n)
}

function normalizeAccidental(delta: number): number {
  let d = ((delta % 12) + 12) % 12
  if (d > 6) d -= 12
  return d
}

/** Spell a major scale with correct enharmonic letters for the key. */
export function majorScaleNotes(root: string): string[] {
  const { letter, accidental } = parseRoot(root)
  const rootPc = (NATURAL_PC[letter]! + accidental + 120) % 12
  const startIdx = LETTERS.indexOf(letter as (typeof LETTERS)[number])

  return MAJOR_INTERVALS.map((semitones, i) => {
    const scaleLetter = LETTERS[(startIdx + i) % 7]!
    const naturalPc = NATURAL_PC[scaleLetter]!
    const targetPc = (rootPc + semitones) % 12
    const acc = normalizeAccidental(targetPc - naturalPc)
    return `${scaleLetter}${formatAccidental(acc)}`
  })
}

export function majorScaleDegrees(root: string): ScaleDegree[] {
  const notes = majorScaleNotes(root)
  return notes.map((note, i) => ({
    degree: i + 1,
    solfege: SOLFEGE[i]!,
    note,
  }))
}

export function isMajorKey(value: string): value is MajorKey {
  return (MAJOR_KEYS as readonly string[]).includes(value)
}
