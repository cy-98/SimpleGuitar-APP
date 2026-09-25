# Jita

节拍器 + 大调调内级数练习。

```
scale-pulse/
├── APP.md             # 产品说明
├── docs/plans/        # 待做功能计划（capo / tap tempo / 节奏练习）
├── packages/core/     # Web 共享 theory / pitch（TypeScript）
├── webapp/            # Web 应用
├── ios/               # SwiftUI（需 Mac + Xcode）
├── design-system/
└── package.json
```

功能路线图：[docs/plans/README.md](./docs/plans/README.md)

---

## Web（`webapp/`）

```bash
npm run dev
npm run build:pages
```

Pages：https://cy-98.github.io/SimpleGuitar-APP/

---

## iOS（`ios/`）

SwiftUI。**需 macOS + Xcode**。

```bash
cd ios
xcodegen generate
open ScalePulse.xcodeproj
```

详见 [`ios/README.md`](./ios/README.md)。

---

## Shared core（`packages/core/`）

Web 用的大调 / 指板 / pitch。iOS 侧有对等 Swift 实现（`ios/ScalePulse/Theory/`）。
