import { useEffect, useRef, useState, type CSSProperties } from "react";
import { playSungMidi } from "../audio/pitch";
import {
  stringLabel,
  stringTargetMidi,
  TunerEngine,
  type TunerReading,
  type TunerStringId,
} from "../audio/tuner";
import { unlockAudioSync } from "../audio/voices";

const STRING_ORDER: TunerStringId[] = [6, 5, 4, 3, 2, 1];

type Props = {
  onNeedAudioUnlock?: () => void;
};

export function TunerPanel({ onNeedAudioUnlock }: Props) {
  const engineRef = useRef<TunerEngine | null>(null);
  const [listening, setListening] = useState(false);
  const [reading, setReading] = useState<TunerReading | null>(null);
  const [pinned, setPinned] = useState<TunerStringId | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const engine = new TunerEngine();
    engine.onReading = setReading;
    engineRef.current = engine;
    return () => {
      engine.stop();
      engineRef.current = null;
    };
  }, []);

  useEffect(() => {
    engineRef.current?.setPinnedString(pinned);
  }, [pinned]);

  async function toggleListen() {
    setError(null);
    const engine = engineRef.current;
    if (!engine) return;
    if (engine.isListening) {
      engine.stop();
      setListening(false);
      setReading(null);
      return;
    }
    try {
      await engine.start();
      setListening(true);
    } catch {
      setError("无法使用麦克风，请在浏览器设置中允许访问。");
      setListening(false);
    }
  }

  function selectString(id: TunerStringId) {
    setPinned((prev) => (prev === id ? null : id));
  }

  function playReference(id: TunerStringId) {
    unlockAudioSync();
    void playSungMidi(stringTargetMidi(id)).then(() => onNeedAudioUnlock?.());
  }

  const activeString = pinned ?? reading?.stringId ?? null;
  const cents = reading?.cents ?? 0;
  const clampedCents = Math.max(-50, Math.min(50, cents));
  const needlePct = 50 + clampedCents;

  const statusText = !listening
    ? "点按开始，对着麦克风拨弦"
    : reading
      ? reading.inTune
        ? "音准良好"
        : cents < 0
          ? "偏低"
          : "偏高"
      : "请拨弦…";

  return (
    <section className="panel panel--tuner" aria-label="调音器">
      <div className="tile-head">
        <h2 className="tile-title">调音器</h2>
        <span className="tuner-status" aria-live="polite">
          {statusText}
        </span>
      </div>

      <div
        className={
          "tuner-hero" +
          (reading?.inTune ? " tuner-hero--intune" : "") +
          (listening ? " tuner-hero--live" : "")
        }
      >
        <div className="tuner-display" aria-hidden={!reading}>
          <span className="tuner-note">
            {reading
              ? pinned
                ? stringLabel(pinned)
                : `${reading.note}${reading.octave}`
              : "—"}
          </span>
          <span className="tuner-freq">
            {reading ? `${reading.freq.toFixed(1)} Hz` : " "}
          </span>
        </div>

        <div className="tuner-meter" aria-hidden="true">
          <span className="tuner-meter-mark tuner-meter-mark--flat">♭</span>
          <div className="tuner-meter-track">
            <span className="tuner-meter-center" />
            <span
              className="tuner-meter-needle"
              style={{ "--needle": `${needlePct}%` } as CSSProperties}
            />
          </div>
          <span className="tuner-meter-mark tuner-meter-mark--sharp">♯</span>
        </div>

        <p className="tuner-cents" aria-live="polite">
          {reading
            ? `${cents >= 0 ? "+" : ""}${cents.toFixed(0)} 音分`
            : listening
              ? "等待输入"
              : "\u00a0"}
        </p>

        <button
          type="button"
          className="tuner-listen-btn"
          aria-pressed={listening}
          onClick={() => void toggleListen()}
        >
          {listening ? "停止" : "开始调音"}
        </button>
      </div>

      <div className="field">
        <span id="tuner-string-label">琴弦</span>
        <div
          className="tuner-string-row"
          role="group"
          aria-labelledby="tuner-string-label"
        >
          {STRING_ORDER.map((id) => (
            <div key={id} className="tuner-string-cell">
              <button
                type="button"
                className="tuner-string-btn"
                aria-pressed={activeString === id}
                onClick={() => selectString(id)}
              >
                <span className="tuner-string-num">{id}</span>
                <span className="tuner-string-name">{stringLabel(id)}</span>
              </button>
              <button
                type="button"
                className="tuner-ref-btn"
                aria-label={`播放 ${id} 弦 ${stringLabel(id)} 参考音`}
                onClick={() => playReference(id)}
              >
                ♪
              </button>
            </div>
          ))}
        </div>
        <p className="tuner-hint">
          点选琴弦可锁定目标音；不选则自动匹配最近弦。
        </p>
      </div>

      {error ? (
        <p className="tuner-error" role="alert">
          {error}
        </p>
      ) : null}
    </section>
  );
}
