let sharedCtx: AudioContext | null = null

export function getAudioContext(): AudioContext {
  if (!sharedCtx) {
    sharedCtx = new AudioContext()
  }
  return sharedCtx
}

export async function resumeAudio(): Promise<AudioContext> {
  const ctx = getAudioContext()
  if (ctx.state === 'suspended') {
    await ctx.resume()
  }
  return ctx
}

/** Schedule a short click. Accent = downbeat (higher + louder). */
export function playClick(
  ctx: AudioContext,
  time: number,
  accent: boolean,
): void {
  const osc = ctx.createOscillator()
  const gain = ctx.createGain()
  osc.connect(gain)
  gain.connect(ctx.destination)

  osc.type = 'square'
  osc.frequency.setValueAtTime(accent ? 1400 : 900, time)

  const peak = accent ? 0.28 : 0.14
  gain.gain.setValueAtTime(0.0001, time)
  gain.gain.exponentialRampToValueAtTime(peak, time + 0.002)
  gain.gain.exponentialRampToValueAtTime(0.0001, time + (accent ? 0.055 : 0.035))

  osc.start(time)
  osc.stop(time + 0.07)
}
