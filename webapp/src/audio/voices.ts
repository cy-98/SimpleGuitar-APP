/** Metronome sound voices — all synthesized via Web Audio (no sample files). */

export type SoundId = "click" | "drum" | "wood" | "clap";

export type SoundMeta = {
  id: SoundId;
  label: string;
  hint: string;
};

export const SOUNDS: readonly SoundMeta[] = [
  { id: "click", label: "滴答", hint: "正拍滴答，反拍轻滴" },
  { id: "drum", label: "鼓声", hint: "底鼓 / 军鼓，反拍用擦" },
  { id: "wood", label: "木鱼", hint: "正拍敲击，反拍轻叩" },
  { id: "clap", label: "拍手", hint: "正拍掌击，反拍轻拍" },
] as const;

export const DEFAULT_SOUND: SoundId = "click";

const STORAGE_KEY = "scale-pulse-sound";
const VOLUME_KEY = "scale-pulse-volume";
export const DEFAULT_VOLUME = 0.85;

export function isSoundId(value: string): value is SoundId {
  return SOUNDS.some((s) => s.id === value);
}

export function readStoredSound(): SoundId {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw && isSoundId(raw)) return raw;
  } catch {
    /* ignore */
  }
  return DEFAULT_SOUND;
}

export function storeSound(id: SoundId): void {
  try {
    localStorage.setItem(STORAGE_KEY, id);
  } catch {
    /* ignore */
  }
}

export function readStoredVolume(): number {
  try {
    const raw = localStorage.getItem(VOLUME_KEY);
    if (raw != null) {
      const n = Number(raw);
      if (Number.isFinite(n)) return Math.min(1, Math.max(0, n));
    }
  } catch {
    /* ignore */
  }
  return DEFAULT_VOLUME;
}

export function storeVolume(value: number): void {
  try {
    localStorage.setItem(
      VOLUME_KEY,
      String(Math.min(1, Math.max(0, value))),
    );
  } catch {
    /* ignore */
  }
}

let sharedCtx: AudioContext | null = null;
let masterGain: GainNode | null = null;
let noiseBuffer: AudioBuffer | null = null;
let masterVolume = DEFAULT_VOLUME;

function createAudioContext(): AudioContext {
  const w = window as Window & {
    webkitAudioContext?: typeof AudioContext;
  };
  const Ctor = w.AudioContext ?? w.webkitAudioContext;
  if (!Ctor) {
    throw new Error("Web Audio API is not available");
  }
  return new Ctor();
}

export function getAudioContext(): AudioContext {
  if (!sharedCtx) {
    sharedCtx = createAudioContext();
  }
  return sharedCtx;
}

export function getAudioContextState(): AudioContextState | "missing" {
  return sharedCtx?.state ?? "missing";
}

/** Play a 1-sample buffer — required by iOS Safari in the same user gesture as resume(). */
function playSilentUnlockPulse(ctx: AudioContext, output: GainNode): void {
  const buffer = ctx.createBuffer(1, 1, ctx.sampleRate);
  const src = ctx.createBufferSource();
  src.buffer = buffer;
  src.connect(output);
  const t = ctx.currentTime;
  src.start(t);
  src.stop(t + 0.002);
}

/**
 * Unlock audio synchronously inside touchstart / pointerdown / click.
 * On iOS, awaiting resume() before this runs often leaves the context suspended.
 */
export function unlockAudioSync(): AudioContext {
  const ctx = getAudioContext();
  const output = getOutput(ctx);
  void ctx.resume();
  try {
    playSilentUnlockPulse(ctx, output);
  } catch {
    /* ignore */
  }
  return ctx;
}

function getOutput(ctx: AudioContext): GainNode {
  if (!masterGain || masterGain.context !== ctx) {
    masterGain = ctx.createGain();
    masterGain.gain.value = masterVolume;
    masterGain.connect(ctx.destination);
  }
  return masterGain;
}

/** Route synthesized tones through the same master volume as the metronome. */
export function getMasterGain(ctx: AudioContext): GainNode {
  return getOutput(ctx);
}

export function setMasterVolume(value: number): void {
  masterVolume = Math.min(1, Math.max(0, value));
  if (masterGain) {
    masterGain.gain.setTargetAtTime(
      masterVolume,
      masterGain.context.currentTime,
      0.02,
    );
  }
}

export function getMasterVolume(): number {
  return masterVolume;
}

function waitForRunning(ctx: AudioContext, timeoutMs: number): Promise<void> {
  if (ctx.state === "running") return Promise.resolve();
  return new Promise((resolve) => {
    const finish = () => {
      ctx.removeEventListener("statechange", onState);
      clearTimeout(timer);
      resolve();
    };
    const onState = () => {
      if (ctx.state === "running") finish();
    };
    const timer = window.setTimeout(finish, timeoutMs);
    ctx.addEventListener("statechange", onState);
  });
}

export async function resumeAudio(): Promise<AudioContext> {
  const ctx = unlockAudioSync();
  if (ctx.state === "running") {
    getOutput(ctx);
    return ctx;
  }
  try {
    await ctx.resume();
  } catch {
    /* ignore */
  }
  await waitForRunning(ctx, 300);
  if (ctx.state !== "running") {
    try {
      await ctx.resume();
    } catch {
      /* ignore */
    }
    await waitForRunning(ctx, 300);
  }
  getOutput(ctx);
  return ctx;
}

/** True when Web Audio is active enough to schedule sounds. */
export function isAudioRunning(): boolean {
  return sharedCtx?.state === "running";
}

/** Preview selected voice: accent downbeat (+ light upbeat). */
export async function previewSound(id: SoundId): Promise<void> {
  const ctx = await resumeAudio();
  const t = ctx.currentTime + 0.02;
  playTick(id, ctx, t, true, false);
  playTick(id, ctx, t + 0.22, false, true);
}

function getNoiseBuffer(ctx: AudioContext): AudioBuffer {
  if (noiseBuffer && noiseBuffer.sampleRate === ctx.sampleRate) {
    return noiseBuffer;
  }
  const length = Math.floor(ctx.sampleRate * 0.25);
  const buffer = ctx.createBuffer(1, length, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < length; i++) {
    data[i] = Math.random() * 2 - 1;
  }
  noiseBuffer = buffer;
  return buffer;
}

/** Classic square-wave metronome click. */
export function playClick(
  ctx: AudioContext,
  time: number,
  accent: boolean,
): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.connect(gain);
  gain.connect(getOutput(ctx));

  osc.type = "square";
  osc.frequency.setValueAtTime(accent ? 1400 : 900, time);

  const peak = accent ? 0.28 : 0.14;
  gain.gain.setValueAtTime(0.0001, time);
  gain.gain.exponentialRampToValueAtTime(peak, time + 0.002);
  gain.gain.exponentialRampToValueAtTime(
    0.0001,
    time + (accent ? 0.055 : 0.035),
  );

  osc.start(time);
  osc.stop(time + 0.07);
}

/** Kick on accent (downbeat), snare on other beats ? all synth. */
export function playDrum(
  ctx: AudioContext,
  time: number,
  accent: boolean,
): void {
  if (accent) {
    playKick(ctx, time);
  } else {
    playSnare(ctx, time);
  }
}

function playKick(ctx: AudioContext, time: number): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.connect(gain);
  gain.connect(getOutput(ctx));

  osc.type = "sine";
  osc.frequency.setValueAtTime(160, time);
  osc.frequency.exponentialRampToValueAtTime(42, time + 0.09);

  gain.gain.setValueAtTime(0.0001, time);
  gain.gain.exponentialRampToValueAtTime(0.55, time + 0.004);
  gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.22);

  osc.start(time);
  osc.stop(time + 0.25);
}

function playSnare(ctx: AudioContext, time: number): void {
  const noise = ctx.createBufferSource();
  noise.buffer = getNoiseBuffer(ctx);
  const filter = ctx.createBiquadFilter();
  filter.type = "bandpass";
  filter.frequency.setValueAtTime(1800, time);
  filter.Q.setValueAtTime(0.9, time);
  const noiseGain = ctx.createGain();
  noise.connect(filter);
  filter.connect(noiseGain);
  noiseGain.connect(getOutput(ctx));

  noiseGain.gain.setValueAtTime(0.0001, time);
  noiseGain.gain.exponentialRampToValueAtTime(0.32, time + 0.003);
  noiseGain.gain.exponentialRampToValueAtTime(0.0001, time + 0.12);
  noise.start(time);
  noise.stop(time + 0.14);

  const osc = ctx.createOscillator();
  const oscGain = ctx.createGain();
  osc.type = "triangle";
  osc.frequency.setValueAtTime(200, time);
  osc.connect(oscGain);
  oscGain.connect(getOutput(ctx));
  oscGain.gain.setValueAtTime(0.0001, time);
  oscGain.gain.exponentialRampToValueAtTime(0.18, time + 0.002);
  oscGain.gain.exponentialRampToValueAtTime(0.0001, time + 0.08);
  osc.start(time);
  osc.stop(time + 0.1);
}

/** Closed hi-hat / ? ? audible on phone speakers. */
export function playHiHat(ctx: AudioContext, time: number): void {
  const noise = ctx.createBufferSource();
  noise.buffer = getNoiseBuffer(ctx);

  const highpass = ctx.createBiquadFilter();
  highpass.type = "highpass";
  highpass.frequency.setValueAtTime(2500, time);

  const band = ctx.createBiquadFilter();
  band.type = "bandpass";
  band.frequency.setValueAtTime(4500, time);
  band.Q.setValueAtTime(0.85, time);

  const gain = ctx.createGain();
  noise.connect(highpass);
  highpass.connect(band);
  band.connect(gain);
  gain.connect(getOutput(ctx));

  gain.gain.setValueAtTime(0.0001, time);
  gain.gain.exponentialRampToValueAtTime(0.38, time + 0.002);
  gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.07);

  noise.start(time);
  noise.stop(time + 0.09);

  const osc = ctx.createOscillator();
  const oscGain = ctx.createGain();
  osc.type = "square";
  osc.frequency.setValueAtTime(5200, time);
  osc.connect(oscGain);
  oscGain.connect(getOutput(ctx));
  oscGain.gain.setValueAtTime(0.0001, time);
  oscGain.gain.exponentialRampToValueAtTime(0.06, time + 0.001);
  oscGain.gain.exponentialRampToValueAtTime(0.0001, time + 0.03);
  osc.start(time);
  osc.stop(time + 0.04);
}

/** Wooden fish / woodblock ? sharp mid knock. */
export function playWood(
  ctx: AudioContext,
  time: number,
  accent: boolean,
): void {
  const f0 = accent ? 980 : 720;
  const peak = accent ? 0.38 : 0.22;

  const osc = ctx.createOscillator();
  const filter = ctx.createBiquadFilter();
  const gain = ctx.createGain();
  osc.type = "triangle";
  osc.frequency.setValueAtTime(f0, time);
  osc.frequency.exponentialRampToValueAtTime(f0 * 0.82, time + 0.04);
  filter.type = "bandpass";
  filter.frequency.setValueAtTime(f0 * 1.1, time);
  filter.Q.setValueAtTime(8, time);
  osc.connect(filter);
  filter.connect(gain);
  gain.connect(getOutput(ctx));

  gain.gain.setValueAtTime(0.0001, time);
  gain.gain.exponentialRampToValueAtTime(peak, time + 0.0015);
  gain.gain.exponentialRampToValueAtTime(0.0001, time + (accent ? 0.09 : 0.06));

  osc.start(time);
  osc.stop(time + 0.12);

  const osc2 = ctx.createOscillator();
  const gain2 = ctx.createGain();
  osc2.type = "sine";
  osc2.frequency.setValueAtTime(f0 * 2.15, time);
  osc2.connect(gain2);
  gain2.connect(getOutput(ctx));
  gain2.gain.setValueAtTime(0.0001, time);
  gain2.gain.exponentialRampToValueAtTime(peak * 0.35, time + 0.001);
  gain2.gain.exponentialRampToValueAtTime(0.0001, time + 0.035);
  osc2.start(time);
  osc2.stop(time + 0.05);
}

/** Hand clap ? filtered noise burst with slight double. */
export function playClap(
  ctx: AudioContext,
  time: number,
  accent: boolean,
): void {
  const peak = accent ? 0.42 : 0.26;
  const bursts = accent ? [0, 0.012, 0.024] : [0, 0.014];

  for (const offset of bursts) {
    const t = time + offset;
    const noise = ctx.createBufferSource();
    noise.buffer = getNoiseBuffer(ctx);
    const band = ctx.createBiquadFilter();
    band.type = "bandpass";
    band.frequency.setValueAtTime(accent ? 1400 : 1100, t);
    band.Q.setValueAtTime(1.2, t);
    const high = ctx.createBiquadFilter();
    high.type = "highpass";
    high.frequency.setValueAtTime(600, t);
    const gain = ctx.createGain();
    noise.connect(high);
    high.connect(band);
    band.connect(gain);
    gain.connect(getOutput(ctx));

    const amp = peak * (offset === 0 ? 1 : 0.55);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(amp, t + 0.002);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.08);
    noise.start(t);
    noise.stop(t + 0.1);
  }
}

export function playVoice(
  id: SoundId,
  ctx: AudioContext,
  time: number,
  accent: boolean,
): void {
  switch (id) {
    case "drum":
      playDrum(ctx, time, accent);
      break;
    case "wood":
      playWood(ctx, time, accent);
      break;
    case "clap":
      playClap(ctx, time, accent);
      break;
    default:
      playClick(ctx, time, accent);
  }
}

/** Downbeat uses selected voice; upbeat matches that voice family. */
export function playTick(
  id: SoundId,
  ctx: AudioContext,
  time: number,
  accent: boolean,
  upbeat: boolean,
): void {
  if (upbeat) {
    playUpbeat(id, ctx, time);
    return;
  }
  playVoice(id, ctx, time, accent);
}

/** Audible + silent pulse while still inside a user gesture (iOS unlock). */
export function primeMetronomeAudio(
  sound: SoundId,
  ctx: AudioContext = getAudioContext(),
): void {
  const output = getOutput(ctx);
  try {
    playSilentUnlockPulse(ctx, output);
  } catch {
    /* ignore */
  }
  try {
    const t = ctx.currentTime + 0.012;
    playTick(sound, ctx, t, true, false);
  } catch {
    /* ignore */
  }
}

function playUpbeat(id: SoundId, ctx: AudioContext, time: number): void {
  switch (id) {
    case "drum":
      playHiHat(ctx, time);
      break;
    case "wood":
      playWoodUpbeat(ctx, time);
      break;
    case "clap":
      playClapUpbeat(ctx, time);
      break;
    default:
      playClickUpbeat(ctx, time);
  }
}

function playClickUpbeat(ctx: AudioContext, time: number): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.connect(gain);
  gain.connect(getOutput(ctx));

  osc.type = "square";
  osc.frequency.setValueAtTime(1250, time);

  gain.gain.setValueAtTime(0.0001, time);
  gain.gain.exponentialRampToValueAtTime(0.18, time + 0.002);
  gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.04);

  osc.start(time);
  osc.stop(time + 0.055);
}

function playWoodUpbeat(ctx: AudioContext, time: number): void {
  const f0 = 1100;
  const osc = ctx.createOscillator();
  const filter = ctx.createBiquadFilter();
  const gain = ctx.createGain();
  osc.type = "triangle";
  osc.frequency.setValueAtTime(f0, time);
  osc.frequency.exponentialRampToValueAtTime(f0 * 0.88, time + 0.03);
  filter.type = "bandpass";
  filter.frequency.setValueAtTime(f0 * 1.1, time);
  filter.Q.setValueAtTime(7, time);
  osc.connect(filter);
  filter.connect(gain);
  gain.connect(getOutput(ctx));

  gain.gain.setValueAtTime(0.0001, time);
  gain.gain.exponentialRampToValueAtTime(0.26, time + 0.0015);
  gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.055);

  osc.start(time);
  osc.stop(time + 0.07);
}

function playClapUpbeat(ctx: AudioContext, time: number): void {
  const noise = ctx.createBufferSource();
  noise.buffer = getNoiseBuffer(ctx);
  const band = ctx.createBiquadFilter();
  band.type = "bandpass";
  band.frequency.setValueAtTime(1300, time);
  band.Q.setValueAtTime(1.1, time);
  const high = ctx.createBiquadFilter();
  high.type = "highpass";
  high.frequency.setValueAtTime(500, time);
  const gain = ctx.createGain();
  noise.connect(high);
  high.connect(band);
  band.connect(gain);
  gain.connect(getOutput(ctx));

  gain.gain.setValueAtTime(0.0001, time);
  gain.gain.exponentialRampToValueAtTime(0.28, time + 0.002);
  gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.07);
  noise.start(time);
  noise.stop(time + 0.09);
}
