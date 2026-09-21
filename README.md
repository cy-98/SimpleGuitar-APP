# Scale Pulse

节拍器 + 大调调内级数练习。仓库按平台拆分源码：

```
scale-pulse/
├── APP.md           # 产品说明（Web / Mobile 共用）
├── webapp/          # Web 应用源码（当前可运行）
├── mobile-app/      # 移动端源码（目录已预留）
├── design-system/   # 设计相关
└── package.json     # 根脚本，转发到 webapp
```

---

## Web（`webapp/`）

```bash
# 在仓库根目录
npm run dev

# 或进入 webapp
cd webapp
npm install
npm run dev
```

生产：

```bash
npm run build
npm start
```

技术栈：[@lazarv/react-server](https://react-server.dev/) + Web Audio。

功能详见 [APP.md](./APP.md)。

---

## Mobile（`mobile-app/`）

目录已预留，工程尚未初始化。说明见 [`mobile-app/README.md`](./mobile-app/README.md)。
