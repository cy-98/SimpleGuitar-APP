import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type PointerEvent as ReactPointerEvent,
} from "react";
import { midiToNearestNote } from "@scale-pulse/core";
import { playSungMidi } from "../audio/pitch";
import {
  TUNER_TAB_COLUMNS,
  centsToColumnShift,
  columnIndexForString,
  defaultStringTargets,
  lanePercentForTarget,
  midiToLanePercent,
  percentToMidi,
  readStoredTargets,
  storeTargets,
  tabStringName,
  TunerEngine,
  type StringTargets,
  type TunerReading,
  type TunerStringId,
} from "../audio/tuner";
import { unlockAudioSync } from "../audio/voices";

type MicState = "pending" | "live" | "denied";
type TuningMode = "standard" | "custom";

type Props = {
  onNeedAudioUnlock?: () => void;
};

function midiLabel(midi: number): string {
  const { name, octave } = midiToNearestNote(midi);
  return `${name}${octave}`;
}

export function TunerPanel({ onNeedAudioUnlock }: Props) {
  const engineRef = useRef<TunerEngine | null>(null);
  const dragRef = useRef<{
    stringId: TunerStringId;
    trackEl: HTMLDivElement;
  } | null>(null);

  const [micState, setMicState] = useState<MicState>("pending");
  const [reading, setReading] = useState<TunerReading | null>(null);
  const [mode, setMode] = useState<TuningMode>("standard");
  const [customTargets, setCustomTargets] = useState<StringTargets>(() =>
    typeof window === "undefined" ? defaultStringTargets() : readStoredTargets(),
  );

  const activeTargets =
    mode === "standard" ? defaultStringTargets() : customTargets;

  const syncEngineTargets = useCallback((targets: StringTargets) => {
    engineRef.current?.setTargets(targets);
  }, []);

  useEffect(() => {
    syncEngineTargets(activeTargets);
  }, [activeTargets, syncEngineTargets]);

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
    engine.setTargets(activeTargets);
    engine.onReading = setReading;
    engineRef.current = engine;
    void startMic();
    return () => {
      engine.stop();
      engineRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- mount once
  }, [startMic]);

  useEffect(() => {
    const endDrag = () => {
      dragRef.current = null;
    };
    window.addEventListener("pointerup", endDrag);
    window.addEventListener("pointercancel", endDrag);
    return () => {
      window.removeEventListener("pointerup", endDrag);
      window.removeEventListener("pointercancel", endDrag);
    };
  }, []);

  function updateCustomTarget(id: TunerStringId, midi: number) {
    setCustomTargets((prev) => {
      const next = { ...prev, [id]: midi };
      storeTargets(next);
      return next;
    });
  }

  function yFromPointer(track: HTMLDivElement, clientY: number): number {
    const rect = track.getBoundingClientRect();
    const t = (clientY - rect.top) / rect.height;
    return percentToMidi(t * 100);
  }

  function onTargetPointerDown(
    id: TunerStringId,
    e: ReactPointerEvent<HTMLButtonElement>,
  ) {
    if (mode !== "custom") return;
    const track = e.currentTarget.closest(
      ".tuner-string-track",
    ) as HTMLDivElement | null;
    if (!track) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    dragRef.current = { stringId: id, trackEl: track };
  }

  function onTargetPointerMove(
    id: TunerStringId,
    e: ReactPointerEvent<HTMLButtonElement>,
  ) {
    const drag = dragRef.current;
    if (!drag || drag.stringId !== id) return;
    const midi = Math.round(yFromPointer(drag.trackEl, e.clientY));
    updateCustomTarget(id, midi);
  }

  function onTargetPointerUp(e: ReactPointerEvent<HTMLButtonElement>) {
    if (e.currentTarget.hasPointerCapture(e.pointerId)) {
      e.currentTarget.releasePointerCapture(e.pointerId);
    }
    dragRef.current = null;
  }

  function playReference(id: TunerStringId) {
    unlockAudioSync();
    void playSungMidi(activeTargets[id]).then(() => onNeedAudioUnlock?.());
  }

  function resetCustom() {
    const next = defaultStringTargets();
    setCustomTargets(next);
    storeTargets(next);
  }

  const activeString = reading?.stringId ?? null;
  const markerStyle =
    reading != null
      ? ({
          "--marker-col": columnIndexForString(reading.stringId),
          "--marker-y": `${midiToLanePercent(reading.midi)}%`,
          "--marker-shift": `${centsToColumnShift(reading.cents)}%`,
        } as CSSProperties)
      : undefined;

  const freqLabel = reading ? `${reading.freq.toFixed(1)} Hz` : "— Hz";

  return (
    <section className="panel panel--tuner" aria-label="调音器">
      <div
        className={
          "tuner-stage" +
          (micState === "live" ? " tuner-stage--live" : "") +
          (reading?.inTune ? " tuner-stage--intune" : "")
        }
      >
        <div className="tuner-topbar">
          <div className="tuner-topbar-left">
            <div
              className="tuner-slide-switch"
              data-mode={mode}
              role="group"
              aria-label="调弦模式"
            >
              <span className="tuner-slide-thumb" aria-hidden="true" />
              <button
                type="button"
                className="tuner-slide-option"
                aria-pressed={mode === "standard"}
                onClick={() => setMode("standard")}
              >
                标准
              </button>
              <button
                type="button"
                className="tuner-slide-option"
                aria-pressed={mode === "custom"}
                onClick={() => setMode("custom")}
              >
                特殊
              </button>
            </div>
            {mode === "custom" ? (
              <button type="button" className="tuner-reset-btn" onClick={resetCustom}>
                重置
              </button>
            ) : null}
          </div>
          <p
            className={
              "tuner-freq-readout" + (reading ? " tuner-freq-readout--live" : "")
            }
            aria-live="polite"
          >
            {freqLabel}
          </p>
        </div>

        <div className="tuner-neck" aria-label="六线谱">
          <div className="tuner-heads">
            {TUNER_TAB_COLUMNS.map((id) => (
              <span
                key={id}
                className={
                  "tuner-string-head" +
                  (activeString === id && reading != null
                    ? " tuner-string-head--active"
                    : "")
                }
              >
                {tabStringName(id)}
              </span>
            ))}
          </div>

          <div className="tuner-board">
            {TUNER_TAB_COLUMNS.map((id) => {
              const targetMidi = activeTargets[id];
              const targetY = lanePercentForTarget(targetMidi);
              const active = activeString === id && reading != null;
              const targetNote = midiLabel(targetMidi);
              return (
                <div
                  key={id}
                  className={
                    "tuner-string-col" +
                    (active ? " tuner-string-col--active" : "")
                  }
                >
                  <div className="tuner-string-track">
                    <span className="tuner-string-nut" aria-hidden="true" />
                    <span className="tuner-string-wire" aria-hidden="true" />
                    <button
                      type="button"
                      className={
                        "tuner-target-handle" +
                        (mode === "custom" ? " tuner-target-handle--drag" : "")
                      }
                      style={{ "--target-y": `${targetY}%` } as CSSProperties}
                      aria-label={`${tabStringName(id)} 弦目标音 ${targetNote}`}
                      onPointerDown={(e) => onTargetPointerDown(id, e)}
                      onPointerMove={(e) => onTargetPointerMove(id, e)}
                      onPointerUp={onTargetPointerUp}
                      onClick={() => {
                        if (mode !== "custom") playReference(id);
                      }}
                    >
                      <span className="tuner-target-note" aria-hidden="true">
                        {mode === "custom" ? targetNote : "♪"}
                      </span>
                    </button>
                  </div>
                </div>
              );
            })}

            {reading ? (
              <span
                className="tuner-live-dot"
                style={markerStyle}
                aria-hidden="true"
              />
            ) : null}
          </div>
        </div>

        {reading ? (
          <p className="tuner-float-readout" aria-live="polite">
            <span className="tuner-float-note">
              {reading.note}
              {reading.octave}
            </span>
            <span className="tuner-float-meta">
              {reading.cents >= 0 ? "+" : ""}
              {reading.cents.toFixed(0)}¢
            </span>
          </p>
        ) : null}
      </div>

      {micState === "denied" ? (
        <div className="tuner-foot">
          <p className="tuner-error" role="alert">
            无法使用麦克风，请在系统设置中允许访问。
          </p>
          <button
            type="button"
            className="tuner-retry-btn"
            onClick={() => void startMic()}
          >
            重新授权
          </button>
        </div>
      ) : null}
    </section>
  );
}
