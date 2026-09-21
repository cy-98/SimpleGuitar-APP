/** Color schemes derived from gradient / atmosphere sources */

export type ThemeId =
  | "meadow"
  | "mist"
  | "blush"
  | "graphite"
  | "flare"
  | "tide";

export type ThemeMeta = {
  id: ThemeId;
  label: string;
  /** Representative color stops for docs */
  stops: [string, string];
  themeColor: string;
  /** Full CSS `background` value for swatch + atmosphere */
  swatch: string;
  /** Optional `background-blend-mode` */
  swatchBlend?: string;
};

export const THEMES: readonly ThemeMeta[] = [
  {
    id: "meadow",
    label: "草地",
    stops: ["#d4fc79", "#96e6a1"],
    themeColor: "#eefce3",
    swatch: "linear-gradient(120deg, #d4fc79 0%, #96e6a1 100%)",
  },
  {
    id: "mist",
    label: "薄雾",
    stops: ["#f5f7fa", "#c3cfe2"],
    themeColor: "#f5f7fa",
    swatch: "linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%)",
  },
  {
    id: "blush",
    label: "暮粉",
    stops: ["#d299c2", "#fef9d7"],
    themeColor: "#fef9d7",
    swatch: "linear-gradient(to top, #d299c2 0%, #fef9d7 100%)",
  },
  {
    id: "graphite",
    label: "石墨",
    stops: ["#989898", "#6e6e6e"],
    themeColor: "#989898",
    swatch:
      "linear-gradient(to bottom, rgba(255,255,255,0.15) 0%, rgba(0,0,0,0.15) 100%), radial-gradient(at top center, rgba(255,255,255,0.40) 0%, rgba(0,0,0,0.40) 120%) #989898",
    swatchBlend: "multiply, multiply",
  },
  {
    id: "flare",
    label: "焰橘",
    stops: ["#d4654a", "#f0c4b0"],
    themeColor: "#fff3ee",
    swatch: "linear-gradient(to top, #d4654a 0%, #f0c4b0 100%)",
  },
  {
    id: "tide",
    label: "潮汐",
    stops: ["#209cff", "#68e0cf"],
    themeColor: "#e8f7ff",
    swatch: "linear-gradient(to top, #209cff 0%, #68e0cf 100%)",
  },
] as const;

export const DEFAULT_THEME: ThemeId = "mist";

const STORAGE_KEY = "scale-pulse-theme";

export function isThemeId(value: string): value is ThemeId {
  return THEMES.some((t) => t.id === value);
}

export function readStoredTheme(): ThemeId {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw && isThemeId(raw)) return raw;
  } catch {
    /* ignore */
  }
  return DEFAULT_THEME;
}

export function storeTheme(id: ThemeId): void {
  try {
    localStorage.setItem(STORAGE_KEY, id);
  } catch {
    /* ignore */
  }
}

export function themeMeta(id: ThemeId): ThemeMeta {
  return THEMES.find((t) => t.id === id) ?? THEMES[1]!;
}
