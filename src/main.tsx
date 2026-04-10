import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { AppErrorBoundary } from "./components/system/AppErrorBoundary";
import { installRuntimeDiagnostics, runtimeLogger } from "./lib/runtimeDiagnostics";
import "./styles.css";

installRuntimeDiagnostics();
runtimeLogger.info("bootstrap", "main.tsx loaded");

const rootElement = document.getElementById("root");

if (!rootElement) {
  runtimeLogger.error("bootstrap", "Missing #root element");
  throw new Error("Missing #root element");
}

try {
  runtimeLogger.info("bootstrap", "Rendering React root");
  ReactDOM.createRoot(rootElement).render(
    <React.StrictMode>
      <AppErrorBoundary>
        <App />
      </AppErrorBoundary>
    </React.StrictMode>
  );
} catch (error) {
  runtimeLogger.error("bootstrap", "React root render failed", error);
  throw error;
}
