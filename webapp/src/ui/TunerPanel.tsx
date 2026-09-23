import { useCallback, useEffect, useRef, useState, type CSSProperties } from "react";
import { playSungMidi } from "../audio/pitch";
import {
  TUNER_LANE_ORDER,
  centsToCrossPercent,
  lanePercentForString,
  midiToLanePercent,
  stringLabel,
  stringTargetMidi,
  TunerEngine,
  type TunerReading,
  type TunerStringId,
} from "../audio/tuner";
import { unlockAudioSync } from "../audio/voices";

type MicState = "pending" | "live" | "denied";

type Props = {
  onNeedAudioUnlock?: () => void;
};

export function TunerPanel({ onNeedAudioUnlock }: Props) {
  const engineRef = useRef<TunerEngine | null>(null);
  const [micState, setMicState] = useState<MicState>("pending");
  const [reading, setReading] = useState<TunerReading | null>(null);

  const startMic = useCallback(async () => {
    const engine = engineRef.current;
    if (!engine) return;
    setMicState("pending");
    unlockAudioSync();
    try {
      await engine.start();
      setMicState("live");
    } catch {
      setMicState("denied");
      setReading(null);
    }
  }, []);

  useEffect(() => {
    const engine = new TunerEngine();
    engine.onReading = setReading;
    engineRef.current = engine;
    void startMic();
    return () => {
      engine.stop();
      engineRef.current = null;
    };
  }, [startMic]);

  function playReference(id: TunerStringId) {
    unlockAudioSync();
    void playSungMidi(stringTargetMidi(id)).then(() => onNeedAudioUnlock?.());
  }

  const activeString = reading?.stringId ?? null;
  const cents = reading?.cents ?? 0;

  const statusText =
    micState === "pending"
      ? "正在请求麦克风…"
      : micState === "denied"
        ? "需要麦克风权限"
        : reading
          ? reading.inTune
            ? `${activeString} 弦 · 音准良好`
            : `${activeString} 弦 · ${cents < 0 ? "偏低" : "偏高"}`
          : "请拨弦";

  const markerStyle =
    reading != null
      ? ({
          "--marker-y": `${midiToLanePercent(reading.midi)}%`,
          "--marker-x": centsToCrossPercent(reading.cents),
        } as CSSProperties)
      : undefined;

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
          "tuner-stage" +
          (micState === "live" ? " tuner-stage--live" : "") +
          (reading?.inTune ? " tuner-stage--intune" : "")
        }
      >
        <div className="tuner-lanes" aria-label="六弦基线">
          {TUNER_LANE_ORDER.map((id) => {
            const active = activeString === id && reading != null;
            return (
              <div
                key={id}
                className={"tuner-lane" + (active ? " tuner-lane--active" : "")}
                style={
                  { "--lane-y": `${lanePercentForString(id)}%` } as CSSProperties
                }
              >
                <div className="tuner-lane-label">
                  <span className="tuner-lane-num">{id}</span>
                  <span className="tuner-lane-note">{stringLabel(id)}</span>
                  <button
                    type="button"
                    className="tuner-lane-ref"
                    aria-label={`播放 ${id} 弦 ${stringLabel(id)} 参考音`}
                    onClick={() => playReference(id)}
                  >
                    ♪
                  </button>
                </div>
                <div className="tuner-lane-track">
                  <span className="tuner-lane-center" />
                </div>
              </div>
            );
          })}

          {reading ? (
            <span className="tuner-marker" style={markerStyle} />
          ) : null}
        </div>

        <div className="tuner-readout" aria-live="polite">
          <span className="tuner-readout-note">
            {reading ? `${reading.note}${reading.octave}` : "—"}
          </span>
          <span className="tuner-readout-meta">
            {reading
              ? `${reading.freq.toFixed(1)} Hz · ${cents >= 0 ? "+" : ""}${cents.toFixed(0)} 音分`
              : micState === "live"
                ? "等待声音"
                : "\u00a0"}
          </span>
        </div>
      </div>

      {micState === "denied" ? (
        <div className="tuner-foot">
          <p className="tuner-error" role="alert">
            无法使用麦克风。请在浏览器或系统设置中允许本站访问麦克风。
          </p>
          <button
            type="button"
            className="tuner-retry-btn"
            onClick={() => void startMic()}
          >
            重新授权
          </button>
        </div>
      ) : (
        <p className="tuner-hint">
          六条基线为各弦空弦音；圆点随音高在基线间移动，左右表示偏高或偏低。
        </p>
      )}
    </section>
  );
}
