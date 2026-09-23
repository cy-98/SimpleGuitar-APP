import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type PointerEvent as ReactPointerEvent,
} from "react";
import { playSungMidi } from "../audio/pitch";
import {
  TUNER_TAB_COLUMNS,
  centsToColumnShift,
  columnIndexForString,
  customTuningNotation,
  defaultOpenMidi,
  defaultStringTargets,
  nutYPercent,
  pitchYOnString,
  readStoredTargets,
  storeTargets,
  tabStringName,
  targetMidiFromTrackY,
  tuningPairLabel,
  tuningTargetName,
  TunerEngine,
  type StringTargets,
  type TunerReading,
  type TunerStringId,
} from "../audio/tuner";
import { unlockAudioSync } from "../audio/voices";
import { SlideSeg } from "./SlideSeg";

type MicState = "pending" | "live" | "denied";
type TuningMode = "standard" | "custom";

type Props = {
  onNeedAudioUnlock?: () => void;
};

const NUT_Y = nutYPercent();

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

  function beginCustomDrag(id: TunerStringId, track: HTMLDivElement) {
    dragRef.current = { stringId: id, trackEl: track };
  }

  function moveCustomDrag(id: TunerStringId, clientY: number) {
    const drag = dragRef.current;
    if (!drag || drag.stringId !== id) return;
    const midi = targetMidiFromTrackY(id, trackYPercent(drag.trackEl, clientY));
    updateCustomTarget(id, midi);
  }

  function onCustomDragStart(
    id: TunerStringId,
    track: HTMLDivElement,
    pointerId: number,
    captureEl: HTMLElement,
    clientY: number,
  ) {
    captureEl.setPointerCapture(pointerId);
    beginCustomDrag(id, track);
    moveCustomDrag(id, clientY);
  }

  function onTrackPointerDown(
    id: TunerStringId,
    e: ReactPointerEvent<HTMLDivElement>,
  ) {
    if (mode !== "custom") return;
    if ((e.target as HTMLElement).closest(".tuner-target-handle")) return;
    onCustomDragStart(id, e.currentTarget, e.pointerId, e.currentTarget, e.clientY);
  }

  function onTrackPointerMove(
    id: TunerStringId,
    e: ReactPointerEvent<HTMLDivElement>,
  ) {
    if (mode !== "custom") return;
    moveCustomDrag(id, e.clientY);
  }

  function onTrackPointerUp(e: ReactPointerEvent<HTMLDivElement>) {
    if (e.currentTarget.hasPointerCapture(e.pointerId)) {
      e.currentTarget.releasePointerCapture(e.pointerId);
    }
    dragRef.current = null;
  }

  function onHandlePointerDown(
    id: TunerStringId,
    e: ReactPointerEvent<HTMLButtonElement>,
  ) {
    if (mode !== "custom") return;
    e.preventDefault();
    e.stopPropagation();
    const track = e.currentTarget.closest(
      ".tuner-string-track",
    ) as HTMLDivElement | null;
    if (!track) return;
    onCustomDragStart(id, track, e.pointerId, e.currentTarget, e.clientY);
  }

  function onHandlePointerMove(
    id: TunerStringId,
    e: ReactPointerEvent<HTMLButtonElement>,
  ) {
    if (mode !== "custom") return;
    moveCustomDrag(id, e.clientY);
  }

  function onHandlePointerUp(e: ReactPointerEvent<HTMLButtonElement>) {
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

  let statusLine = "—";
  if (reading) {
    const c = reading.cents;
    const centStr = `${c >= 0 ? "+" : ""}${c.toFixed(0)}¢`;
    statusLine = `${reading.freq.toFixed(1)} Hz · ${reading.note}${reading.octave} · ${centStr}`;
  } else if (mode === "custom") {
    statusLine = customTuningNotation(customTargets);
  }

  return (
    <section className="panel panel--tuner" aria-label="调音器">
      <div
        className={
          "tuner-stage" +
          (reading?.inTune ? " tuner-stage--intune" : "")
        }
      >
        <div className="tuner-topbar">
          <div className="tuner-topbar-left">
            <SlideSeg
              className="slide-seg--compact"
              aria-label="调弦模式"
              value={mode}
              onChange={setMode}
              options={(
                [
                  ["standard", "标准"],
                  ["custom", "特殊"],
                ] as const
              ).map(([value, label]) => ({ value, label }))}
            />
            {mode === "custom" ? (
              <button type="button" className="tuner-reset-btn" onClick={resetCustom}>
                重置
              </button>
            ) : null}
          </div>
          <p
            className={
              "tuner-status-line" + (reading ? " tuner-status-line--live" : "")
            }
            aria-live="polite"
          >
            {statusLine}
          </p>
        </div>

        <div className="tuner-neck" aria-label="六弦">
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
              const active = activeString === id && reading != null;
              const pairLabel = tuningPairLabel(id, targetMidi);
              const factoryOpen = defaultOpenMidi(id);
              const targetY =
                mode === "custom"
                  ? pitchYOnString(targetMidi, factoryOpen)
                  : NUT_Y;
              const handleLabel =
                mode === "custom"
                  ? `${tabStringName(id)}=${tuningTargetName(targetMidi, factoryOpen)}`
                  : "♪";
              return (
                <div
                  key={id}
                  className={
                    "tuner-string-col" +
                    (active ? " tuner-string-col--active" : "")
                  }
                >
                  <div
                    className={
                      "tuner-string-track" +
                      (mode === "custom" ? " tuner-string-track--custom" : "")
                    }
                    style={{ "--nut-y": `${NUT_Y}%` } as CSSProperties}
                    onPointerDown={(e) => onTrackPointerDown(id, e)}
                    onPointerMove={(e) => onTrackPointerMove(id, e)}
                    onPointerUp={onTrackPointerUp}
                  >
                    <span className="tuner-string-nut" aria-hidden="true" />
                    <span className="tuner-string-wire" aria-hidden="true" />
                    <button
                      type="button"
                      className={
                        "tuner-target-handle" +
                        (mode === "custom"
                          ? " tuner-target-handle--custom"
                          : " tuner-target-handle--standard")
                      }
                      style={{ "--target-y": `${targetY}%` } as CSSProperties}
                      aria-label={pairLabel}
                      onPointerDown={(e) => onHandlePointerDown(id, e)}
                      onPointerMove={(e) => onHandlePointerMove(id, e)}
                      onPointerUp={onHandlePointerUp}
                      onPointerCancel={onHandlePointerUp}
                      onClick={() => {
                        if (mode === "standard") playReference(id);
                      }}
                    >
                      <span className="tuner-target-handle-text">{handleLabel}</span>
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
