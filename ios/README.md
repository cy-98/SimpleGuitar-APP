# Scale Pulse — iOS (SwiftUI)

原生 **Swift / SwiftUI** 客户端，产品对齐 [`../APP.md`](../APP.md)。

> **需要 macOS + Xcode。** Windows 无法编译/模拟 iOS；本目录只维护源码。

## 在 Mac 上打开

推荐用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成工程：

```bash
brew install xcodegen
cd ios
xcodegen generate
open ScalePulse.xcodeproj
```

或手动：Xcode → New iOS App（SwiftUI）→ 把 `ScalePulse/` 下源文件拖进工程，Bundle ID 设为 `app.scalepulse.mobile`。

## 功能

- **节拍**：BPM / 拍号 / 细分、拍位格子、Play/Pause、反拍静音
- **级数**：选调、唱名、七扇区环图（点扇区只播音）、指板 + 把位
- **设置**：声源试听、音量、反拍静音、六套配色（UserDefaults）

音频：`AVAudioEngine` 合成滴答与唱音。节拍按**前台练习**设计。

## 结构

```
ios/
├── project.yml          # XcodeGen
├── ScalePulse/
│   ├── ScalePulseApp.swift
│   ├── RootTabView.swift
│   ├── Theme/
│   ├── Theory/          # scales / fretboard / pitch
│   ├── Audio/
│   ├── Metro/
│   ├── TheoryUI/
│   └── Settings/
└── README.md
```

Web 仍在 `webapp/`；共享 TS 理论包在 `packages/core`（仅 Web 使用）。
