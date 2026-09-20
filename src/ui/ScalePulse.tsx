"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  MAJOR_KEYS,
  majorScaleDegrees,
  type MajorKey,
} from "../theory/scales";
import {
  MetronomeEngine,
  type Subdivision,
  type TickInfo,
  type TimeSignature,
} from "../metro/engine";

const DEGREE_ZH = ["一级", "二级", "三级", "四级", "五级", "六级", "七级"];

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j]!, a[i]!];
  }
  return a;
}

function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)]!;
}

function subdivHintText(subdivision: Subdivision): string {
  if (subdivision === 2) return "听四分 · 看静默八分（每拍 2 格）";
  if (subdivision === 4) return "听四分 · 看静默十六分（每拍 4 格）";
  return "只听四分音符";
}

type QuizState = {
  prompt: string;
  answer: string;
  choices: string[];
  locked: boolean;
  feedback: string;
  feedbackState: "" | "ok" | "no";
  picked: string | null;
};

function makeQuiz(key: MajorKey): QuizState {
  const degrees = majorScaleDegrees(key);
  const target = pick(degrees);
  const distractors = shuffle(
    degrees.map((d) => d.note).filter((n) => n !== target.note),
  ).slice(0, 3);
  return {
    prompt: `${key} 大调的${DEGREE_ZH[target.degree - 1]}是什么音？`,
    answer: target.note,
    choices: shuffle([target.note, ...distractors]),
    locked: false,
    feedback: "",
    feedbackState: "",
    picked: null,
  };
}

export default function ScalePulse() {
  const [bpm, setBpm] = useState(100);
  const [beatsPerBar, setBeatsPerBar] = useState<TimeSignature>(4);
  const [subdivision, setSubdivision] = useState<Subdivision>(1);
  const [running, setRunning] = useState(false);
  const [tick, setTick] = useState<TickInfo | null>(null);
  const [pulseKind, setPulseKind] = useState<"accent" | "weak" | "silent" | null>(
    null,
  );
  const [pulseNonce, setPulseNonce] = useState(0);

  const [key, setKey] = useState<MajorKey>("C");
  const [showSolfege, setShowSolfege] = useState(true);
  const [degreeAnim, setDegreeAnim] = useState(0);
  const [quiz, setQuiz] = useState<QuizState>(() => makeQuiz("C"));

  const metroRef = useRef<MetronomeEngine | null>(null);

  const degrees = useMemo(() => majorScaleDegrees(key), [key]);

  useEffect(() => {
    const metro = new MetronomeEngine({
      bpm: 100,
      beatsPerBar: 4,
      subdivision: 1,
    });
    metro.onTick = (info) => {
      setTick(info);
      setPulseKind(info.audible ? (info.accent ? "accent" : "weak") : "silent");
      setPulseNonce((n) => n + 1);
    };
    metroRef.current = metro;
    return () => {
      metro.stop();
      metroRef.current = null;
    };
  }, []);

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

  async function togglePlay() {
    const metro = metroRef.current;
    if (!metro) return;
    if (metro.isRunning) {
      metro.stop();
      setRunning(false);
      setTick(null);
      setPulseKind(null);
    } else {
      await metro.start();
      setRunning(true);
    }
  }

  function changeKey(next: MajorKey) {
    setKey(next);
    setDegreeAnim((n) => n + 1);
    setQuiz(makeQuiz(next));
  }

  function answerQuiz(note: string) {
    if (quiz.locked) return;
    const ok = note === quiz.answer;
    setQuiz((q) => ({
      ...q,
      locked: true,
      picked: note,
      feedback: ok ? "对了！" : `不对，答案是 ${q.answer}`,
      feedbackState: ok ? "ok" : "no",
    }));
  }

  function syncBpm(value: number) {
    const next = Math.min(240, Math.max(40, Math.round(value) || 40));
    setBpm(next);
  }

  return (
    <div id="app">
      <div className="atmosphere" aria-hidden="true" />
      <div className="shell">
        <header className="brand">
          <p className="brand-name">Scale Pulse</p>
          <p className="tagline">练节拍，记调内级数</p>
        </header>

        <section className="metro" aria-label="节拍器">
          <div
            className={
              "pulse-ring" +
              (pulseKind === "silent"
                ? " tick-silent"
                : pulseKind
                  ? " tick"
                  : "")
            }
            data-active={running ? "true" : "false"}
            data-pulse={pulseKind ?? undefined}
            key={pulseNonce}
          >
            <button
              type="button"
              className="play-btn"
              aria-pressed={running}
              onClick={() => void togglePlay()}
            >
              <span className="play-label">{running ? "停止" : "开始"}</span>
              <span className="bpm-readout">
                <span>{bpm}</span>
                <small>BPM</small>
              </span>
            </button>
          </div>

          <div
            className="beats"
            role="list"
            aria-label="拍位与细分"
            data-subdivision={String(subdivision)}
          >
            {Array.from({ length: beatsPerBar }, (_, beat) => (
              <div
                key={beat}
                className={
                  "beat-group" + (tick?.beatIndex === beat ? " active" : "")
                }
                data-beat={String(beat)}
                role="listitem"
                aria-label={`第 ${beat + 1} 拍`}
              >
                {Array.from({ length: subdivision }, (_, s) => {
                  const on =
                    tick?.beatIndex === beat && tick.subdivIndex === s;
                  const classes = [
                    "beat-dot",
                    s === 0 ? "beat-dot--down" : "beat-dot--sub",
                    on ? "on" : "",
                    on && tick?.accent ? "accent" : "",
                    on && tick && !tick.audible ? "silent" : "",
                  ]
                    .filter(Boolean)
                    .join(" ");
                  return (
                    <span
                      key={s}
                      className={classes}
                      data-beat={String(beat)}
                      data-sub={String(s)}
                    />
                  );
                })}
              </div>
            ))}
          </div>

          <p className="subdiv-hint">{subdivHintText(subdivision)}</p>

          <div className="metro-controls">
            <label className="field">
              <span>速度</span>
              <div className="bpm-row">
                <input
                  type="range"
                  min={40}
                  max={240}
                  value={bpm}
                  onChange={(e) => syncBpm(Number(e.target.value))}
                />
                <input
                  type="number"
                  min={40}
                  max={240}
                  value={bpm}
                  onChange={(e) => syncBpm(Number(e.target.value))}
                />
              </div>
            </label>

            <label className="field">
              <span>拍号</span>
              <div className="seg" role="group" aria-label="拍号">
                {([2, 3, 4] as const).map((n) => (
                  <button
                    key={n}
                    type="button"
                    aria-pressed={beatsPerBar === n}
                    onClick={() => setBeatsPerBar(n)}
                  >
                    {n}/4
                  </button>
                ))}
              </div>
            </label>

            <label className="field">
              <span>静默细分</span>
              <div className="seg" role="group" aria-label="静默细分">
                {(
                  [
                    [1, "四分"],
                    [2, "八分"],
                    [4, "十六分"],
                  ] as const
                ).map(([n, label]) => (
                  <button
                    key={n}
                    type="button"
                    aria-pressed={subdivision === n}
                    onClick={() => setSubdivision(n)}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </label>
          </div>
        </section>

        <section className="scale" aria-label="调内级数">
          <div className="scale-head">
            <h2>调内级数</h2>
            <label className="toggle">
              <input
                type="checkbox"
                checked={showSolfege}
                onChange={(e) => setShowSolfege(e.target.checked)}
              />
              <span>唱名</span>
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
                {k} 大调
              </button>
            ))}
          </div>
          <div className="degree-strip swap" key={degreeAnim}>
            {degrees.map((d) => (
              <div key={d.degree} className="degree-cell">
                <span className="deg-num">{d.degree}</span>
                {showSolfege ? (
                  <span className="deg-sol">{d.solfege}</span>
                ) : null}
                <span className="deg-note">{d.note}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="quiz" aria-label="级数抽问">
          <div className="quiz-head">
            <h2>抽问</h2>
            <button
              type="button"
              className="text-btn"
              onClick={() => setQuiz(makeQuiz(key))}
            >
              换一题
            </button>
          </div>
          <p className="quiz-prompt">{quiz.prompt}</p>
          <div className="quiz-choices">
            {quiz.choices.map((note) => {
              const classes = [
                "choice",
                quiz.locked && note === quiz.answer ? "correct" : "",
                quiz.locked &&
                quiz.picked === note &&
                note !== quiz.answer
                  ? "wrong"
                  : "",
              ]
                .filter(Boolean)
                .join(" ");
              return (
                <button
                  key={note}
                  type="button"
                  className={classes}
                  disabled={quiz.locked}
                  onClick={() => answerQuiz(note)}
                >
                  {note}
                </button>
              );
            })}
          </div>
          <p
            className="quiz-feedback"
            data-state={quiz.feedbackState || undefined}
            aria-live="polite"
          >
            {quiz.feedback}
          </p>
        </section>
      </div>
    </div>
  );
}
