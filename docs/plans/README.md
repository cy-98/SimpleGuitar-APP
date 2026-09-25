# 功能计划（Guitar / Jita）

待实现方向的详细说明。实现前以这里为准对齐范围与验收。

| 计划 | 文件 | 摘要 |
|------|------|------|
| 变调夹 | [capo.md](./capo.md) | 虚拟 capo，环图 / 指板 / 调音目标联动移调 |
| BPM 测速 | [tap-tempo.md](./tap-tempo.md) | 点按测 BPM，写入节拍器 |
| 节奏练习生成 | [rhythm-practice.md](./rhythm-practice.md) | 按拍号 / 细分生成练习型，驱动现有节拍引擎 |

当前产品基线见 [`APP.md`](../../APP.md)。

**建议实现顺序（依赖少 → 多）：** BPM 测速 → 变调夹 → 节奏练习生成。
