import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const rootDir = path.dirname(fileURLToPath(import.meta.url));

/** GitHub Pages project site: https://<user>.github.io/SimpleGuitar-APP/ */
const base = process.env.BASE_PATH || "/SimpleGuitar-APP/";

export default defineConfig({
  base,
  plugins: [react()],
  publicDir: "public",
  resolve: {
    alias: {
      "@scale-pulse/core": path.resolve(rootDir, "../packages/core/src/index.ts"),
    },
  },
  server: {
    fs: {
      allow: [path.resolve(rootDir, "..")],
    },
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
