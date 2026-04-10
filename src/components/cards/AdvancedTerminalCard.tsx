import { FitAddon } from "@xterm/addon-fit";
import { Terminal } from "@xterm/xterm";
import "@xterm/xterm/css/xterm.css";
import { useEffect, useRef, useState } from "react";
import { runtimeLogger } from "../../lib/runtimeDiagnostics";
import { onBackendEvent, tauriInvoke } from "../../lib/tauri";
import { useAppStore } from "../../state/store";
import { TerminalFallbackView } from "./TerminalFallbackView";

export function AdvancedTerminalCard() {
  const activeSessionId = useAppStore((s) => s.activeSessionId);
  const mountRef = useRef<HTMLDivElement | null>(null);
  const terminalRef = useRef<Terminal | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!mountRef.current) {
      return;
    }

    try {
      runtimeLogger.info("terminal", "Initializing xterm terminal");
      const terminal = new Terminal({
        fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
        fontSize: 13,
        rows: 24,
        cols: 80,
        convertEol: true
      });
      const fitAddon = new FitAddon();
      terminal.loadAddon(fitAddon);
      terminal.open(mountRef.current);
      fitAddon.fit();
      terminalRef.current = terminal;

      const resizeObserver = new ResizeObserver(() => fitAddon.fit());
      resizeObserver.observe(mountRef.current);

      return () => {
        resizeObserver.disconnect();
        terminal.dispose();
        terminalRef.current = null;
      };
    } catch (error) {
      runtimeLogger.error("terminal", "Failed to initialize xterm; falling back", error);
      setFailed(true);
      return;
    }
  }, []);

  useEffect(() => {
    if (failed || !activeSessionId) {
      return;
    }

    const terminal = terminalRef.current;
    if (!terminal) {
      return;
    }

    terminal.clear();
    terminal.writeln(`[session ${activeSessionId}] connected`);

    let dispose = () => {};
    void onBackendEvent((event) => {
      if (event.session_id !== activeSessionId) {
        return;
      }
      if (event.event_type === "message_assistant") {
        const payload = event.payload as { content: string };
        terminal.writeln(`\r\n${payload.content}`);
      }
      if (event.event_type === "action_tool_call") {
        const payload = event.payload as { tool_name?: string; kind?: string; title: string };
        terminal.writeln(`\r\n[action:${payload.tool_name ?? payload.kind ?? "tool_call"}] ${payload.title}`);
      }
    })
      .then((unlisten) => {
        dispose = unlisten;
      })
      .catch((error) => {
        runtimeLogger.error("terminal", "Failed to subscribe terminal backend events", error);
        setFailed(true);
      });

    const onDataDispose = terminal.onData((data) => {
      void tauriInvoke("write_pty", {
        sessionId: activeSessionId,
        data
      }).catch((error) => {
        runtimeLogger.error("terminal", "write_pty failed", { activeSessionId, error });
      });
    });

    return () => {
      onDataDispose.dispose();
      dispose();
    };
  }, [activeSessionId, failed]);

  if (failed) {
    return <TerminalFallbackView />;
  }

  return (
    <section className="card-shell terminal-shell">
      <header className="card-header">
        <h2>Terminal</h2>
        <span className="muted">interactive PTY stream</span>
      </header>
      <div className="terminal-host" ref={mountRef} />
    </section>
  );
}
