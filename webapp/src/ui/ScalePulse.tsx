"use client; no-ssr";

import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import {
  MAJOR_KEYS,
  NATURAL_CYCLE,
  degreesByLetter,
  isMajorKey,
  type MajorKey,
} from "../theory/scales";
import {
  FRET_MAX,
  FRET_MIN,
  POSITIONS,
  getPosition,
  inPosition,
  scaleDots,
  type FretDot,
  type PositionId,
} from "../theory/fretboard";
import { SlideSeg } from "./SlideSeg";
import {
  MetronomeEngine,
  type Subdivision,
  type TickInfo,
  type TimeSignature,
} from "../metro/engine";

import {
  DEFAULT_THEME,
  THEMES,
  readStoredTheme,
  storeTheme,
  themeMeta,
  type ThemeId,
} from "../theme/palettes";
import {
  DEFAULT_SOUND,
  DEFAULT_VOLUME,
  SOUNDS,
  isAudioRunning,
  previewSound,
  readStoredSound,
  readStoredVolume,
  resumeAudio,
  setMasterVolume,
  storeSound,
  storeVolume,
  unlockAudioSync,
  type SoundId,
} from "../audio/voices";
import { playSungMidi, playSungNote } from "../audio/pitch";

const MUTE_UPBEATS_KEY = "scale-pulse-mute-upbeats";

const AUDIO_BLOCKED_HINT =
  "浏览器还没开启声音：请再点一次播放，并确认 iPhone 未开静音、媒体音量已调高。";

function readMuteUpbeats(): boolean {
  try {
    const raw = localStorage.getItem(MUTE_UPBEATS_KEY);
    if (raw === "1" || raw === "true") return true;
    if (raw === "0" || raw === "false") return false;
  } catch {
    /* ignore */
  }
  return false;
}

function storeMuteUpbeats(value: boolean): void {
  try {
    localStorage.setItem(MUTE_UPBEATS_KEY, value ? "1" : "0");
  } catch {
    /* ignore */
  }
}

type AppTab = "metro" | "theory" | "settings";
type TheoryView = "chart" | "fretboard";

const STRING_LABELS = ["e", "B", "G", "D", "A", "E"] as const;
const FRET_MARKERS = new Set([3, 5, 7, 9, 12]);

const CHART_CX = 100;
const CHART_CY = 100;
const CHART_R0 = 52;
const CHART_R1 = 92;
const CHART_LABEL_R = 72;
const CHART_SLICE = 360 / 7;
/** Slight overlap so antialias seams don’t flash */
const CHART_GAP = -0.35;

function polar(r: number, deg: number): [number, number] {
  const rad = (deg * Math.PI) / 180;
  return [CHART_CX + r * Math.cos(rad), CHART_CY + r * Math.sin(rad)];
}

/** Donut wedge; slice 0 centered at top (−90°). */
function donutSlicePath(index: number): string {
  const mid = index * CHART_SLICE - 90;
  const a0 = mid - CHART_SLICE / 2 + CHART_GAP / 2;
  const a1 = mid + CHART_SLICE / 2 - CHART_GAP / 2;
  const [x0, y0] = polar(CHART_R1, a0);
  const [x1, y1] = polar(CHART_R1, a1);
  const [x2, y2] = polar(CHART_R0, a1);
  const [x3, y3] = polar(CHART_R0, a0);
  return [
    `M ${x0.toFixed(2)} ${y0.toFixed(2)}`,
    `A ${CHART_R1} ${CHART_R1} 0 0 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`,
    `L ${x2.toFixed(2)} ${y2.toFixed(2)}`,
    `A ${CHART_R0} ${CHART_R0} 0 0 0 ${x3.toFixed(2)} ${y3.toFixed(2)}`,
    "Z",
  ].join(" ");
}

function sliceLabelPos(index: number): { x: number; y: number; mid: number } {
  const mid = index * CHART_SLICE - 90;
  const [x, y] = polar(CHART_LABEL_R, mid);
  return { x, y, mid };
}

export default function ScalePulse() {
  const [tab, setTab] = useState<AppTab>("metro");
  const [bpm, setBpm] = useState(100);
  const [beatsPerBar, setBeatsPerBar] = useState<TimeSignature>(4);
  const [subdivision, setSubdivision] = useState<Subdivision>(1);
  const [running, setRunning] = useState(false);
  const [tick, setTick] = useState<TickInfo | null>(null);

  const [key, setKey] = useState<MajorKey>("C");
  const [showNoteLetters, setShowNoteLetters] = useState(true);
  const [theoryView, setTheoryView] = useState<TheoryView>("chart");
  const [positionId, setPositionId] = useState<PositionId>("all");
  const [theme, setTheme] = useState<ThemeId>(() =>
    typeof window === "undefined" ? DEFAULT_THEME : readStoredTheme(),
  );
  const [sound, setSound] = useState<SoundId>(() =>
    typeof window === "undefined" ? DEFAULT_SOUND : readStoredSound(),
  );
  const [volume, setVolume] = useState(() =>
    typeof window === "undefined" ? DEFAULT_VOLUME : readStoredVolume(),
  );
  const [muteUpbeats, setMuteUpbeats] = useState(() =>
    typeof window === "undefined" ? false : readMuteUpbeats(),
  );
  const [audioHint, setAudioHint] = useState<string | null>(null);

  const metroRef = useRef<MetronomeEngine | null>(null);
  const playGestureRef = useRef(0);

  function syncAudioHint(): void {
    setAudioHint(isAudioRunning() ? null : AUDIO_BLOCKED_HINT);
  }
  const tonicLetter = key[0]!.toUpperCase();
  const tonicIdx = Math.max(
    0,
    NATURAL_CYCLE.indexOf(tonicLetter as (typeof NATURAL_CYCLE)[number]),
  );
  const degreeByLetter = useMemo(() => degreesByLetter(key), [key]);
  const chartSlices = useMemo(
    () =>
      NATURAL_CYCLE.map((letter, i) => ({
        letter,
        path: donutSlicePath(i),
        label: sliceLabelPos(i),
        degree: degreeByLetter.get(letter),
        tonic: letter === tonicLetter,
      })),
    [degreeByLetter, tonicLetter],
  );
  const fretDots = useMemo(() => scaleDots(key), [key]);
  const fretPosition = useMemo(() => getPosition(positionId), [positionId]);
  const dotsByCell = useMemo(() => {
    const map = new Map<string, FretDot>();
    for (const d of fretDots) {
      map.set(`${d.string}:${d.fret}`, d);
    }
    return map;
  }, [fretDots]);

  useEffect(() => {
    setMasterVolume(volume);
  }, [volume]);

  useEffect(() => {
    const unlockFromGesture = () => {
      unlockAudioSync();
      if (isAudioRunning()) {
        setAudioHint(null);
      }
    };
    const opts: AddEventListenerOptions = { capture: true, passive: true };
    document.addEventListener("touchstart", unlockFromGesture, opts);
    document.addEventListener("pointerdown", unlockFromGesture, opts);
    document.addEventListener("click", unlockFromGesture, opts);
    return () => {
      document.removeEventListener("touchstart", unlockFromGesture, opts);
      document.removeEventListener("pointerdown", unlockFromGesture, opts);
      document.removeEventListener("click", unlockFromGesture, opts);
    };
  }, []);

  useEffect(() => {
    const onVisibility = () => {
      if (document.visibilityState !== "visible") return;
      if (!metroRef.current?.isRunning) return;
      void resumeAudio().then(() => syncAudioHint());
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, []);

  useEffect(() => {
    const meta = themeMeta(theme);
    document.documentElement.dataset.theme = theme;
    const tag = document.querySelector('meta[name="theme-color"]');
    if (tag) tag.setAttribute("content", meta.themeColor);
  }, [theme]);

  useEffect(() => {
    const metro = new MetronomeEngine({
      bpm: 100,
      beatsPerBar: 4,
      subdivision: 1,
      sound: readStoredSound(),
      muteUpbeats: readMuteUpbeats(),
    });
    metro.onTick = (info) => {
      setTick((prev) => {
        if (
          prev &&
          prev.beatIndex === info.beatIndex &&
          prev.subdivIndex === info.subdivIndex &&
          prev.accent === info.accent &&
          prev.audible === info.audible
        ) {
          return prev;
        }
        return info;
      });
    };
    metroRef.current = metro;
    return () => {
      metro.stop();
      metroRef.current = null;
    };
  }, []);

  useEffect(() => {
    metroRef.current?.setSound(sound);
  }, [sound]);

  useEffect(() => {
    metroRef.current?.setBpm(bpm);
  }, [bpm]);

  useEffect(() => {
    metroRef.current?.setBeatsPerBar(beatsPerBar);
    setTick(null);
  }, [beatsPerBar]);

  useEffect(() => {
    metroRef.current?.setSubdivision(subdivision);
    setTick(null);
  }, [subdivision]);

  useEffect(() => {
    metroRef.current?.setMuteUpbeats(muteUpbeats);
  }, [muteUpbeats]);

  function togglePlay() {
    unlockAudioSync();
    const metro = metroRef.current;
    if (!metro) return;
    if (metro.isRunning) {
      metro.stop();
      setRunning(false);
      setTick(null);
      setAudioHint(null);
      return;
    }
    void metro.start().then((started) => {
      if (started) {
        setRunning(true);
        setAudioHint(null);
      } else {
        setRunning(false);
        syncAudioHint();
      }
    });
  }

  function changeKey(next: MajorKey, opts?: { silent?: boolean }) {
    setKey(next);
    if (!opts?.silent) {
      unlockAudioSync();
      void playSungNote(next).then(() => syncAudioHint());
    }
  }

  function selectChartNote(note: string) {
    unlockAudioSync();
    void playSungNote(note).then(() => syncAudioHint());
  }

  function selectFretDot(dot: FretDot) {
    unlockAudioSync();
    void playSungMidi(dot.midi).then(() => syncAudioHint());
    if (dot.isTonic && isMajorKey(dot.degree.note)) {
      setKey(dot.degree.note);
    }
  }

  function syncBpm(value: number) {
    setBpm(Math.min(240, Math.max(40, Math.round(value) || 40)));
  }

  function nudgeBpm(delta: number) {
    syncBpm(bpm + delta);
  }

  function changeTheme(id: ThemeId) {
    setTheme(id);
    storeTheme(id);
  }

  function changeSound(id: SoundId) {
    unlockAudioSync();
    setSound(id);
    storeSound(id);
    metroRef.current?.setSound(id);
    void previewSound(id).then(() => syncAudioHint());
  }

  function changeVolume(value: number) {
    const next = Math.min(1, Math.max(0, value));
    setVolume(next);
    setMasterVolume(next);
    storeVolume(next);
  }

  function changeMuteUpbeats(next: boolean) {
    setMuteUpbeats(next);
    storeMuteUpbeats(next);
    metroRef.current?.setMuteUpbeats(next);
  }

  return (
    <div id="app" data-theme={theme}>
      <div className="phone">
        <main className="screen">
          {tab === "metro" ? (
            <section className="panel panel--metro" aria-label="节拍器">
              <div
                className={
                  "hero-card" + (running ? " hero-card--playing" : "")
                }
                style={
                  {
                    "--beats": beatsPerBar,
                    "--subs": subdivision,
                  } as CSSProperties
                }
              >
                <div className="beat-bg" aria-hidden="true">
                  {Array.from({ length: beatsPerBar }, (_, beat) => {
                    const beatOn = tick?.beatIndex === beat;
                    const showSub = subdivision > 1;

                    if (!showSub || !beatOn) {
                      const classes = [
                        "beat-bg-cell",
                        beatOn ? "on" : "",
                        beatOn && tick?.accent ? "accent" : "",
                      ]
                        .filter(Boolean)
                        .join(" ");
                      return <span key={beat} className={classes} />;
                    }

                    return (
                      <span
                        key={beat}
                        className="beat-bg-cell beat-bg-cell--sub on"
                      >
                        {Array.from({ length: subdivision }, (_, s) => {
                          const subOn = tick?.subdivIndex === s;
                          const classes = [
                            "beat-bg-sub",
                            s === 0 ? "beat-bg-sub--down" : "beat-bg-sub--up",
                            subOn ? "on" : "",
                            subOn && tick?.accent && s === 0 ? "accent" : "",
                            subOn && tick && !tick.audible ? "silent" : "",
                          ]
                            .filter(Boolean)
                            .join(" ");
                          return <span key={s} className={classes} />;
                        })}
                      </span>
                    );
                  })}
                </div>

                <button
                  type="button"
                  className="stage"
                  aria-pressed={running}
                  aria-label={running ? "暂停" : "播放"}
                  onPointerDown={(e) => {
                    if (e.button !== 0) return;
                    unlockAudioSync();
                  }}
                  onPointerUp={(e) => {
                    if (e.button !== 0) return;
                    e.preventDefault();
                    playGestureRef.current = Date.now();
                    togglePlay();
                  }}
                  onClick={(e) => {
                    if (Date.now() - playGestureRef.current < 500) {
                      e.preventDefault();
                    }
                  }}
                  onKeyDown={(e) => {
                    if (e.key !== "Enter" && e.key !== " ") return;
                    e.preventDefault();
                    togglePlay();
                  }}
                >
                  {running ? (
                    <svg
                      className="play-icon play-icon--pause"
                      viewBox="0 0 24 24"
                      aria-hidden="true"
                    >
                      <rect x="5.5" y="4" width="4.5" height="16" rx="2.25" />
                      <rect x="14" y="4" width="4.5" height="16" rx="2.25" />
                    </svg>
                  ) : (
                    <svg
                      className="play-icon play-icon--play"
                      viewBox="0 0 24 24"
                      aria-hidden="true"
                    >
                      <path d="M8.2 5.4c0-1.1 1.2-1.8 2.15-1.2l10.1 6.6c.9.58.9 1.92 0 2.5l-10.1 6.6c-.95.62-2.15-.08-2.15-1.2V5.4Z" />
                    </svg>
                  )}
                </button>
              </div>

              <div className="controls">
                <div className="field">
                  <div className="field-label-row">
                    <span>速度</span>
                    <span className="bpm-inline" aria-live="polite">
                      {bpm} BPM
                    </span>
                  </div>
                  <div className="bpm-stepper">
                    <button
                      type="button"
                      className="step-btn"
                      aria-label="减慢"
                      onClick={() => nudgeBpm(-1)}
                    >
                      <span className="step-icon step-icon--minus" aria-hidden="true" />
                    </button>
                    <input
                      type="range"
                      min={40}
                      max={240}
                      value={bpm}
                      style={
                        {
                          "--progress": `${((bpm - 40) / (240 - 40)) * 100}%`,
                        } as CSSProperties
                      }
                      onChange={(e) => syncBpm(Number(e.target.value))}
                      aria-label="速度"
                    />
                    <button
                      type="button"
                      className="step-btn"
                      aria-label="加快"
                      onClick={() => nudgeBpm(1)}
                    >
                      <span className="step-icon step-icon--plus" aria-hidden="true" />
                    </button>
                  </div>
                </div>

                <div className="field">
                  <span id="meter-label">拍号</span>
                  <SlideSeg
                    aria-labelledby="meter-label"
                    value={beatsPerBar}
                    onChange={setBeatsPerBar}
                    options={([2, 3, 4] as const).map((n) => ({
                      value: n,
                      label: `${n}/4`,
                    }))}
                  />
                </div>

                <div className="field">
                  <span id="subdiv-label">细分</span>
                  <SlideSeg
                    aria-labelledby="subdiv-label"
                    value={subdivision}
                    onChange={setSubdivision}
                    options={(
                      [
                        [1, "四分"],
                        [2, "八分"],
                        [4, "十六分"],
                      ] as const
                    ).map(([n, label]) => ({ value: n, label }))}
                  />
                </div>
              </div>
            </section>
          ) : tab === "theory" ? (
            <section className="panel panel--theory" aria-label="调内级数">
              <div className="tile-head">
                <h2 className="tile-title">{key} 大调</h2>
                <label className="tile-action">
                  <span id="note-letters-label">字母</span>
                  <span className="switch">
                    <input
                      type="checkbox"
                      checked={showNoteLetters}
                      onChange={(e) => setShowNoteLetters(e.target.checked)}
                      aria-labelledby="note-letters-label"
                    />
                    <span className="switch-track" aria-hidden="true" />
                  </span>
                </label>
              </div>

              <div className="key-row" role="listbox" aria-label="选择大调">
                {MAJOR_KEYS.map((k) => (
                  <button
                    key={k}
                    type="button"
                    className="key-chip"
                    role="option"
                    aria-selected={key === k}
                    onClick={() => changeKey(k)}
                  >
                    {k}
                  </button>
                ))}
              </div>

              <div className="chart-slot">
                {theoryView === "chart" ? (
                  <div
                    className="note-chart"
                    role="group"
                    aria-label="音名循环，点击播放唱音"
                    style={
                      {
                        "--chart-rot": `${(-tonicIdx * CHART_SLICE).toFixed(3)}deg`,
                      } as CSSProperties
                    }
                  >
                    <svg
                      className="note-chart-svg"
                      viewBox="0 0 200 200"
                    >
                      <g className="note-chart-wheel">
                        {chartSlices.map((s) => {
                          const spelled = s.degree?.note ?? s.letter;
                          return (
                            <path
                              key={s.letter}
                              className={
                                "note-chart-slice" +
                                (s.tonic ? " note-chart-slice--tonic" : "")
                              }
                              d={s.path}
                              role="button"
                              tabIndex={-1}
                              aria-label={`播放 ${spelled}`}
                              onClick={() => selectChartNote(spelled)}
                            />
                          );
                        })}
                        {chartSlices.map((s) => {
                          const spelled = s.degree?.note ?? s.letter;
                          return (
                            <g
                              key={`lbl-${s.letter}`}
                              className={
                                "note-chart-glyph" +
                                (s.tonic ? " note-chart-glyph--tonic" : "")
                              }
                              transform={`translate(${s.label.x.toFixed(2)} ${s.label.y.toFixed(2)})`}
                              pointerEvents="none"
                            >
                              <g className="note-chart-glyph-keep">
                                {showNoteLetters ? (
                                  <text
                                    className="note-chart-note"
                                    textAnchor="middle"
                                    dominantBaseline="central"
                                    y={s.degree ? "-5" : "0"}
                                  >
                                    {spelled}
                                  </text>
                                ) : null}
                                {s.degree ? (
                                  <text
                                    className="note-chart-deg"
                                    textAnchor="middle"
                                    dominantBaseline="central"
                                    y={showNoteLetters ? "6" : "0"}
                                  >
                                    {String(s.degree.degree)}
                                  </text>
                                ) : null}
                              </g>
                            </g>
                          );
                        })}
                      </g>
                    </svg>

                    <div className="note-chart-hit">
                      {chartSlices.map((s, i) => {
                        const spelled = s.degree?.note ?? s.letter;
                        return (
                          <button
                            key={s.letter}
                            type="button"
                            className={
                              "note-chart-hit-btn" +
                              (s.tonic ? " note-chart-hit-btn--tonic" : "")
                            }
                            style={{ "--i": i } as CSSProperties}
                            aria-label={`播放 ${spelled}`}
                            aria-pressed={s.tonic}
                            onMouseDown={(e) => e.preventDefault()}
                            onClick={() => selectChartNote(spelled)}
                          />
                        );
                      })}
                    </div>

                    <div className="note-chart-hub" aria-hidden="true">
                      <span className="note-chart-hub-key">{key}</span>
                      <span className="note-chart-hub-label">大调</span>
                    </div>
                  </div>
                ) : (
                  <div
                    className="fretboard"
                    role="group"
                    aria-label={`${key} 大调指板`}
                    style={
                      {
                        "--frets": FRET_MAX - FRET_MIN + 1,
                      } as CSSProperties
                    }
                  >
                    <div className="fretboard-grid">
                      {STRING_LABELS.map((label, stringIdx) => (
                        <div
                          key={label}
                          className="fretboard-string"
                          style={{ "--s": stringIdx } as CSSProperties}
                        >
                          <span className="fretboard-string-label">{label}</span>
                          <div className="fretboard-frets">
                            {Array.from(
                              { length: FRET_MAX - FRET_MIN + 1 },
                              (_, fret) => {
                                const dot = dotsByCell.get(
                                  `${stringIdx}:${fret}`,
                                );
                                const dim =
                                  !!dot &&
                                  !inPosition(fret, fretPosition);
                                const marker =
                                  stringIdx === 2 && FRET_MARKERS.has(fret);
                                return (
                                  <div
                                    key={fret}
                                    className={
                                      "fretboard-cell" +
                                      (fret === 0
                                        ? " fretboard-cell--open"
                                        : "") +
                                      (marker
                                        ? " fretboard-cell--marker"
                                        : "")
                                    }
                                  >
                                    {dot ? (
                                      <button
                                        type="button"
                                        className={
                                          "fretboard-dot" +
                                          (dot.isTonic
                                            ? " fretboard-dot--tonic"
                                            : "") +
                                          (dim ? " fretboard-dot--dim" : "")
                                        }
                                        aria-label={`${dot.degree.note} ${dot.degree.degree} 级，第 ${fret} 品`}
                                        onMouseDown={(e) => e.preventDefault()}
                                        onClick={() => selectFretDot(dot)}
                                      >
                                        <span className="fretboard-dot-note">
                                          {showNoteLetters
                                            ? dot.degree.note
                                            : String(dot.degree.degree)}
                                        </span>
                                      </button>
                                    ) : null}
                                  </div>
                                );
                              },
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                    <div className="fretboard-fret-nums" aria-hidden="true">
                      {Array.from(
                        { length: FRET_MAX - FRET_MIN + 1 },
                        (_, fret) => (
                          <span
                            key={fret}
                            className={
                              "fretboard-fret-num" +
                              (FRET_MARKERS.has(fret)
                                ? " fretboard-fret-num--mark"
                                : "")
                            }
                          >
                            {fret === 0 ? "" : fret}
                          </span>
                        ),
                      )}
                    </div>
                  </div>
                )}
              </div>

              {theoryView === "fretboard" ? (
                <SlideSeg
                  className="position-seg"
                  aria-label="把位"
                  value={positionId}
                  onChange={setPositionId}
                  columns={6}
                  options={POSITIONS.map((p) => ({
                    value: p.id,
                    label: p.label,
                  }))}
                />
              ) : null}

              <SlideSeg
                className="theory-view-seg"
                aria-label="级数视图"
                value={theoryView}
                onChange={setTheoryView}
                options={(
                  [
                    ["chart", "环图"],
                    ["fretboard", "指板"],
                  ] as const
                ).map(([id, label]) => ({ value: id, label }))}
              />
            </section>
          ) : (
            <section className="panel panel--settings" aria-label="设置">
              <div className="settings-card">
                <div className="settings-row">
                  <span className="settings-label" id="sound-label">
                    声源
                  </span>
                  <div
                    className="sound-seg-wrap"
                    role="listbox"
                    aria-labelledby="sound-label"
                  >
                    <SlideSeg
                      className="sound-seg"
                      optionRole="option"
                      value={sound}
                      onChange={changeSound}
                      columns={2}
                      options={SOUNDS.map((s) => ({
                        value: s.id,
                        label: s.label,
                      }))}
                    />
                  </div>
                </div>
                <div className="settings-row settings-row--volume">
                  <span className="settings-label" id="volume-label">
                    音量
                  </span>
                  <input
                    type="range"
                    className="volume-slider"
                    min={0}
                    max={100}
                    value={Math.round(volume * 100)}
                    style={
                      {
                        "--progress": `${volume * 100}%`,
                      } as CSSProperties
                    }
                    onChange={(e) => changeVolume(Number(e.target.value) / 100)}
                    aria-labelledby="volume-label"
                  />
                </div>
                <div className="settings-row settings-row--switch">
                  <div className="settings-switch">
                    <span className="settings-label" id="mute-upbeat-label">
                      反拍静音
                    </span>
                    <label className="switch">
                      <input
                        type="checkbox"
                        checked={muteUpbeats}
                        onChange={(e) => changeMuteUpbeats(e.target.checked)}
                        aria-labelledby="mute-upbeat-label"
                      />
                      <span className="switch-track" aria-hidden="true" />
                    </label>
                  </div>
                </div>
              </div>
              <div className="settings-card">
                <div className="settings-row">
                  <span className="settings-label" id="theme-label">
                    配色
                  </span>
                  <div
                    className="theme-list"
                    role="listbox"
                    aria-labelledby="theme-label"
                  >
                    {THEMES.map((t) => (
                      <button
                        key={t.id}
                        type="button"
                        className="theme-option"
                        role="option"
                        aria-selected={theme === t.id}
                        onClick={() => changeTheme(t.id)}
                      >
                        <span
                          className="theme-swatch"
                          style={{
                            background: t.swatch,
                            backgroundBlendMode: t.swatchBlend,
                          }}
                          aria-hidden="true"
                        />
                        <span className="theme-option-text">
                          <span className="theme-option-name">{t.label}</span>
                        </span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </section>
          )}
        </main>

        {audioHint ? (
          <div
            className="audio-hint"
            role="status"
            aria-live="polite"
            onPointerDown={() => {
              unlockAudioSync();
              syncAudioHint();
            }}
          >
            {audioHint}
          </div>
        ) : null}

        <nav className="tabbar-dock" aria-label="主导航">
          <SlideSeg
            className="slide-seg--tabbar"
            aria-label="主导航"
            value={tab}
            onChange={setTab}
            columns={3}
            options={(
              [
                ["metro", "节拍"],
                ["theory", "级数"],
                ["settings", "设置"],
              ] as const
            ).map(([value, label]) => ({ value, label }))}
          />
        </nav>
      </div>
    </div>
  );
}
