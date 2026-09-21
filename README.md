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
# 开发（react-server）
npm run dev

# 静态站构建（GitHub Pages / Vite）
npm run build:pages
```

生产 Pages 地址（部署后）：

https://cy-98.github.io/SimpleGuitar-APP/

---

## Mobile（`mobile-app/`）

目录已预留，工程尚未初始化。说明见 [`mobile-app/README.md`](./mobile-app/README.md)。
