# 生成节奏练习（Rhythm Practice）

## 目标

在现有 **节拍器 + 拍号 + 细分** 之上，**自动生成练习型**（哪几拍响、哪几拍休止 / 轻打），帮助练反拍、切分、简单 syncopation，而不是只匀速 click。

## 用户场景

- 四分 + 八分细分下，练「1 和 3 重、2 和 4 轻」或「只打反拍」。
- 固定 4 小节 pattern 循环，练完换下一组。

## 范围

### MVP

| 项 | 说明 |
|----|------|
| 入口 | **节拍** Tab 内子模式：**练习** \| **自由**（自由 = 当前行为） |
| 练习类型（预设） | ① **全打** ② **反拍静音**（已有设置，可复用） ③ **切分 A**：1、&、3 响（八分下） ④ **切分 B**：2、4 重音其余轻 ⑤ **随机稀疏**：每小节随机 2–3 个可听格（种子固定可复现） |
| 参数 | 沿用当前 **拍号、细分、BPM**；练习 **4 小节** 为一轮，轮末可 auto-advance 下一 preset 或循环同一 preset |
| 视觉 | 现有 `beat-bg` 格子；不可听格加 `silent` 类（已有）；练习模式 badge 显示 preset 名 |
| 音频 | 扩展 `MetronomeEngine` 或薄封装：**每 tick 查 pattern 表** 决定是否 `audible` / `accent` |

### 非 MVP

- 用户自定义 pattern 编辑器（网格点选）。
- 导出 / 分享 pattern JSON。
- 与级数页联动（每拍播不同级数——练旋律节奏）。

## 技术要点

### Pattern 表示

`webapp/src/metro/patterns.ts`：

```ts
export type RhythmCell = { audible: boolean; accent: boolean };

/** 长度 = beatsPerBar * subdivision */
export type BarPattern = RhythmCell[];

export function patternForPreset(
  id: PresetId,
  beatsPerBar: TimeSignature,
  subdivision: Subdivision,
  seed?: number,
): BarPattern[];
```

### 引擎

- **方案 A（推荐）**：`MetronomeEngine` 增加可选 `pattern: BarPattern[] | null`；`schedule` 时 `audible = pattern[barIndex % len][cellIndex].audible`
- **方案 B**：外层 hook 在 `onTick` 里 mute——易与 lookahead 不同步，不推荐

### UI

- 练习模式：preset 横向 chips + 「下一轮」
- 与 **反拍静音** 设置：练习模式优先；冲突时以练习 pattern 为准并暂时忽略全局 mute 或合并语义（文档写清）

## 验收

- [ ] 自由模式与现网完全一致
- [ ] 切分 A 在 4/4 八分下听感与格子一致
- [ ] 换拍号 / 细分后 pattern 自动重算，不崩溃
- [ ] 4 小节循环边界正确，无漏拍 / 双拍
- [ ] BPM 40–240 下 scheduler 仍稳定（沿用现有 lookahead）

## 依赖

- 先有稳定 **节拍引擎**（已有）
- **Tap Tempo** 无硬依赖，可并行

## 风险

- Pattern 与 `muteUpbeats` 语义重叠 → MVP 练习模式打开时禁用或覆盖全局反拍静音，UI 提示一句即可。
