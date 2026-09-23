# BPM 测速（Tap Tempo）

## 目标

用户随音乐或心跳 **连续点按**，应用估算 **BPM** 并 **一键写入节拍器**，减少手动拧滑条。

## 用户场景

- 跟原曲练节奏，先 tap 再开节拍器。
- 排练中有人喊「大概 92」，用手点几下校准。

## 范围

### MVP

| 项 | 说明 |
|----|------|
| 入口 | **节拍** Tab：速度区域旁 **「测速」** 或中央舞台 **长按 / 专用 Tap 区**（避免与 Play 冲突） |
| 交互 | 每次 tap 记录 `performance.now()`；**≥2 次** 后开始显示估算 BPM |
| 算法 | 取最近 **4–8 次** tap 间隔的中位数或指数滑动平均；丢弃 **< 100 ms** 或 **> 2000 ms** 的间隔 |
| 范围 | 结果 clamp **40–240**，与 `MetronomeEngine.setBpm` 一致 |
| 写入 | 显式 **「采用」** 按钮或最后一次 tap 后 **1.5 s 无 tap 自动写入**（二选一，实现时选「采用」更可控） |
| 反馈 | 短促 click（复用 `previewSound` 或极轻 tick）可选 |

### 非 MVP

- 从 **麦克风 onset** 估 BPM（与调音器共享音频栈，复杂度高）。
- Tap 历史曲线、抖动提示「再稳一点」。

## 技术要点

### 新模块

`webapp/src/metro/tapTempo.ts`：

```ts
export type TapTempoState = {
  bpm: number | null;
  tapCount: number;
};

export function registerTap(nowMs: number, prev: number[]): { intervals; bpm }
export function resetTaps(): void
```

### UI

- `ScalePulse.tsx` 节拍 panel：状态 `tapHistory`，展示 `— BPM` / `92 BPM（测速）`
- 「采用」→ `syncBpm(bpm)` + `metroRef.current?.setBpm(bpm)`

### 与现有引擎

- 不改动 `MetronomeEngine` 调度逻辑，只改 `bpm` 状态源。

## 验收

- [ ] 稳定 tap 4/4 约 120 BPM，误差 ±3 BPM 内
- [ ] 「采用」后节拍器播放与显示一致
- [ ] Play 中仍可测速但不误触 Play（按钮分区明确）
- [ ] 40 / 240 边界 clamp 正确

## 风险

- 双击 Play 误触 → Tap 区与 Play 分离布局。
- 移动端 `touchstart` 与 `click` 重复 → 用 pointerdown + debounce。
