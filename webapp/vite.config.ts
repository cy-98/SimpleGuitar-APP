import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

/** GitHub Pages project site: https://<user>.github.io/SimpleGuitar-APP/ */
const base = process.env.BASE_PATH || "/SimpleGuitar-APP/";

export default defineConfig({
  base,
  plugins: [react()],
  publicDir: "public",
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
