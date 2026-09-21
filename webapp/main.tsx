import { createRoot } from "react-dom/client";
import ScalePulse from "./src/ui/ScalePulse";
import "./src/style.css";

const root = document.getElementById("root");
if (!root) {
  throw new Error("Missing #root");
}

createRoot(root).render(<ScalePulse />);
