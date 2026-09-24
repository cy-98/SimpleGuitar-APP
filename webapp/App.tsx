import { ClientOnly } from "@lazarv/react-server/client";
import "./src/style.css";
import ScalePulse from "./src/ui/ScalePulse";

function BootShell() {
  return (
    <div id="app">
      <div className="phone phone--boot" aria-busy="true" />
    </div>
  );
}

export default function App() {
  return (
    <html lang="zh-CN">
      <head>
        <meta charSet="utf-8" />
        <meta
          name="viewport"
          content="width=device-width, initial-scale=1.0, viewport-fit=cover"
        />
        <meta name="theme-color" content="#f5f7fa" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta
          name="apple-mobile-web-app-status-bar-style"
          content="default"
        />
        <title>Jita</title>
        <link
          href="https://api.fontshare.com/v2/css?f[]=switzer@400,500,600,700&display=swap"
          rel="stylesheet"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500&display=swap"
          rel="stylesheet"
        />
        <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
      </head>
      <body>
        <ClientOnly fallback={<BootShell />}>
          <ScalePulse />
        </ClientOnly>
      </body>
    </html>
  );
}
