import type { CSSProperties, ReactNode } from "react";

export type SlideSegOption<T extends string | number> = {
  value: T;
  label: ReactNode;
};

type Props<T extends string | number> = {
  value: T;
  options: readonly SlideSegOption<T>[];
  onChange: (value: T) => void;
  className?: string;
  columns?: number;
  optionRole?: "button" | "option";
  "aria-label"?: string;
  "aria-labelledby"?: string;
};

export function SlideSeg<T extends string | number>({
  value,
  options,
  onChange,
  className = "",
  columns: columnsProp,
  optionRole = "button",
  "aria-label": ariaLabel,
  "aria-labelledby": ariaLabelledBy,
}: Props<T>) {
  const count = options.length;
  const columns = columnsProp ?? count;
  const rows = Math.max(1, Math.ceil(count / columns));
  const activeIndex = Math.max(
    0,
    options.findIndex((o) => o.value === value),
  );
  const col = activeIndex % columns;
  const row = Math.floor(activeIndex / columns);

  const style = {
    "--slide-col": col,
    "--slide-row": row,
    "--slide-columns": columns,
    "--slide-rows": rows,
  } as CSSProperties;

  return (
    <div
      className={`slide-seg ${className}`.trim()}
      role="group"
      data-cols={columns}
      data-rows={rows}
      aria-label={ariaLabel}
      aria-labelledby={ariaLabelledBy}
      style={style}
    >
      <span className="slide-seg-thumb" aria-hidden="true" />
      {options.map((o) => {
        const selected = value === o.value;
        return (
          <button
            key={String(o.value)}
            type="button"
            className="slide-seg-option"
            role={optionRole === "option" ? "option" : undefined}
            aria-pressed={optionRole === "button" ? selected : undefined}
            aria-selected={optionRole === "option" ? selected : undefined}
            onClick={() => onChange(o.value)}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
