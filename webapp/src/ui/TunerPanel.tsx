import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type PointerEvent as ReactPointerEvent,
} from "react";
import { centsFromTarget } from "@scale-pulse/core";
import { playSungMidi } from "../audio/pitch";
import {
  TUNER_TAB_COLUMNS,
  fretLineYPercent,
  centsToColumnShift,
  columnIndexForString,
  customTuningNotation,
  defaultOpenMidi,
  defaultStringTargets,
  isDefaultTuningTarget,
  nutYPercent,
  pitchYOnString,
  readStoredTargets,
  storeTargets,
  tabStringName,
  targetFrequency,
  targetMidiFromTrackY,
  tuningPairLabel,
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

const MATCH_CENTS = 5;
const NUT_Y = nutYPercent();

function formatStringDelta(cents: number): string {
  if (Math.abs(cents) <= MATCH_CENTS) return "✓";
  const n = Math.round(cents);
  return `${n >= 0 ? "+" : ""}${n}¢`;
}

function deltaTone(cents: number): "match" | "flat" | "sharp" | "idle" {
  if (Math.abs(cents) <= MATCH_CENTS) return "match";
  return cents < 0 ? "flat" : "sharp";
}

function trackYPercent(track: HTMLDivElement, clientY: number): number {
  const rect = track.getBoundingClientRect();
  return ((clientY - rect.top) / rect.height) * 100;
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
    const y = trackYPercent(drag.trackEl, e.clientY);
    const midi = targetMidiFromTrackY(id, y);
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
          "--marker-y": `${pitchYOnString(reading.midi, activeTargets[reading.stringId])}%`,
          "--marker-shift": `${centsToColumnShift(reading.cents)}%`,
        } as CSSProperties)
      : undefined;

  const freqLabel = reading ? `${reading.freq.toFixed(1)} Hz` : "— Hz";
  const customNotation =
    mode === "custom" ? customTuningNotation(customTargets) : null;

  const fretMarks = Array.from({ length: 12 }, (_, i) => i + 1);

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

        {customNotation ? (
          <p className="tuner-custom-notation" aria-live="polite">
            {customNotation}
          </p>
        ) : null}

        <div className="tuner-neck" aria-label="六线谱">
          <div className="tuner-heads">
            {TUNER_TAB_COLUMNS.map((id) => {
              const relCents =
                reading != null
                  ? centsFromTarget(reading.midi, activeTargets[id])
                  : null;
              const tone =
                relCents != null ? deltaTone(relCents) : ("idle" as const);
              return (
                <div
                  key={id}
                  className="tuner-head-cell"
                  aria-label={
                    relCents != null
                      ? `${tabStringName(id)} 弦相对当前音 ${formatStringDelta(relCents)}`
                      : undefined
                  }
                >
                  <span
                    className={
                      "tuner-string-head" +
                      (activeString === id && reading != null
                        ? " tuner-string-head--active"
                        : "")
                    }
                  >
                    {tabStringName(id)}
                  </span>
                  <span
                    className={
                      "tuner-string-delta tuner-string-delta--" + tone
                    }
                    aria-hidden={relCents == null}
                  >
                    {relCents != null ? formatStringDelta(relCents) : "—"}
                  </span>
                </div>
              );
            })}
          </div>

          <div className="tuner-board">
            {TUNER_TAB_COLUMNS.map((id) => {
              const targetMidi = activeTargets[id];
              const active = activeString === id && reading != null;
              const pairLabel = tuningPairLabel(id, targetMidi);
              const targetHz = targetFrequency(targetMidi);
              const factoryOpen = defaultOpenMidi(id);
              const pitchY =
                reading != null
                  ? pitchYOnString(reading.midi, targetMidi)
                  : null;
              return (
                <div
                  key={id}
                  className={
                    "tuner-string-col" +
                    (active ? " tuner-string-col--active" : "")
                  }
                >
                  <div
                    className="tuner-string-track"
                    style={{ "--nut-y": `${NUT_Y}%` } as CSSProperties}
                  >
                    <span className="tuner-string-nut" aria-hidden="true" />
                    {fretMarks.map((fret) => (
                      <span
                        key={fret}
                        className="tuner-fret-line"
                        style={
                          { "--fret-y": `${fretLineYPercent(fret)}%` } as CSSProperties
                        }
                        aria-hidden="true"
                      />
                    ))}
                    <span className="tuner-string-wire" aria-hidden="true" />
                    {mode === "custom" &&
                    !isDefaultTuningTarget(id, targetMidi) ? (
                      <span
                        className="tuner-target-preview"
                        style={
                          {
                            "--pitch-y": `${pitchYOnString(targetMidi, factoryOpen)}%`,
                          } as CSSProperties
                        }
                        aria-hidden="true"
                      />
                    ) : null}
                    {reading && pitchY != null ? (
                      <span
                        className={
                          "tuner-pitch-ghost" +
                          (active ? " tuner-pitch-ghost--active" : "")
                        }
                        style={{ "--pitch-y": `${pitchY}%` } as CSSProperties}
                        aria-hidden="true"
                      />
                    ) : null}
                    <button
                      type="button"
                      className={
                        "tuner-target-handle" +
                        (mode === "custom"
                          ? " tuner-target-handle--drag tuner-target-handle--custom"
                          : "")
                      }
                      style={{ "--target-y": `${NUT_Y}%` } as CSSProperties}
                      aria-label={`${pairLabel}，目标 ${targetHz.toFixed(1)} Hz`}
                      onPointerDown={(e) => onTargetPointerDown(id, e)}
                      onPointerMove={(e) => onTargetPointerMove(id, e)}
                      onPointerUp={onTargetPointerUp}
                      onClick={() => {
                        if (mode !== "custom") playReference(id);
                      }}
                    >
                      {mode === "custom" ? (
                        <>
                          <span className="tuner-target-pair">{pairLabel}</span>
                          <span className="tuner-target-hz">
                            {targetHz.toFixed(1)} Hz
                          </span>
                        </>
                      ) : (
                        <span className="tuner-target-note" aria-hidden="true">
                          ♪
                        </span>
                      )}
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
