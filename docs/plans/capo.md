# 变调夹（Capo）

## 目标

在 **不改编和弦指法形状** 的前提下，让用户选择「第几品夹 capo」，界面上的 **调性、音名、指板圆点、调音目标** 按移调后呈现，方便用开放把位弹「看起来仍是 C 形、实际已是别的调」的练习。

## 用户场景

- 歌曲标注 Capo 2，想在该品上练级数 / 找调内音。
- 用 G 形开放和弦时，需要知道 **听感调（ sounding key）** 与 **形状调（ chord shape key）** 的关系（MVP 可只强调听感调 + 指板移位）。

## 范围

### MVP（第一版）

| 项 | 说明 |
|----|------|
| Capo 品数 | **0–7** 品（0 = 无 capo）；步进 ±1 |
| 作用页 | **级数**（环图 + 指板）；可选同步 **调音器** 空弦目标（见下） |
| 显示逻辑 | `effectiveKey = transposeKey(selectedKey, capoFret)`；环图 / 芯片标题显示 **听感调**（如 Capo 2 + 选 C → 显示 **D 大调** 或「C 形 · D 大调」二选一，UI 定稿时选简洁方案） |
| 指板 | 视觉上 capo 条画在对应品；**0 品开放弦音高** 按 capo 升高；圆点级数仍按 **听感大调** 计算 |
| 持久化 | `localStorage` 存 `capoFret` |
| 音频 | `playSungNote` / 指板 MIDI 仍按 **实际音高**（含 capo 半音偏移） |

### 非 MVP（后续）

- 「和弦形状调」与「听感调」双行文案（C 形 / D 调）。
- 与 **特殊调弦** 叠加时的规则说明（先禁止叠加或只支持标准调弦 + capo）。
- iOS SwiftUI  parity。

## 技术要点

### `packages/core`

新增纯函数（无 UI）：

- `transposeKey(key: MajorKey, semitones: number): MajorKey`
- `capoSemitones(fret: number): number`（即 `fret`）
- `applyCapoToMidi(midi: number, capoFret: number): number`（指板播放用）
- 指板：`fretboard.ts` 中 `scaleDots` 传入 **听感 key**；开放弦 / 品位计算加 capo 偏移

### Webapp

- 级数页顶部或指板上方：**Capo 步进器**（与调芯片风格一致）。
- `ScalePulse.tsx`：`key` 仍为「形状调」或改为只存听感调 — **推荐**：内部存 `(shapeKey, capoFret)`，展示与 scale 用 `effectiveKey`。
- 调音器（可选 MVP+1）：标准模式下空弦目标 = 开放弦 + capo（每弦 +capo 半音）。

## 验收

- [ ] Capo 0 与现行为完全一致
- [ ] Capo 2 + C 大调：环图级数与指板圆点对应 **D 大调** 音集
- [ ] 点扇区 / 指板发音高为移调后实际音高
- [ ] 刷新后 capo 品数保留
- [ ] 切换 Tab 再回来 capo 不丢

## 风险

- 用户混淆「选的调芯片」与「听感调」→ 标题或副标题必须写清。
- F# / Bb 等等 enharmonic 拼写沿用现有 `scales.ts` 规则。
