import { FormEvent, useMemo, useState } from "react";
import { tauriInvoke } from "../../lib/tauri";
import { useAppStore } from "../../state/store";

export function AgentChatCard() {
  const [draft, setDraft] = useState("");
  const [adapter, setAdapter] = useState<"claude" | "codex">("claude");
  const activeSessionId = useAppStore((s) => s.activeSessionId);
  const sessions = useAppStore((s) => s.sessions);
  const messages = useAppStore((s) =>
    activeSessionId ? s.messages[activeSessionId] ?? [] : []
  );
  const setActiveSession = useAppStore((s) => s.setActiveSession);

  const orderedSessions = useMemo(
    () => Object.values(sessions).sort((a, b) => a.startedAt.localeCompare(b.startedAt)),
    [sessions]
  );

  const onCreateSession = async () => {
    const created = await tauriInvoke<{ sessionId: string }>("create_session", {
      adapter,
      cwd: "."
    });
    setActiveSession(created.sessionId);
  };

  const onSend = async (event: FormEvent) => {
    event.preventDefault();
    if (!activeSessionId || !draft.trim()) {
      return;
    }

    const content = draft;
    setDraft("");
    await tauriInvoke("send_user_message", {
      sessionId: activeSessionId,
      content
    });
  };

  return (
    <section className="card-shell">
      <header className="card-header">
        <h2>Agent Chat</h2>
        <div className="row gap">
          <select value={adapter} onChange={(e) => setAdapter(e.target.value as "claude" | "codex") }>
            <option value="claude">Claude</option>
            <option value="codex">Codex</option>
          </select>
          <button type="button" onClick={onCreateSession}>
            New Session
          </button>
        </div>
      </header>
      <div className="session-list">
        {orderedSessions.map((session) => (
          <button
            className={session.sessionId === activeSessionId ? "session-pill active" : "session-pill"}
            key={session.sessionId}
            onClick={() => setActiveSession(session.sessionId)}
            type="button"
          >
            {session.agentType}:{session.sessionId.slice(0, 8)}
          </button>
        ))}
      </div>
      <div className="chat-log">
        {messages.map((message) => (
          <div className={message.role === "user" ? "bubble user" : "bubble agent"} key={message.id}>
            <span className="bubble-role">{message.role}</span>
            <p>{message.content}</p>
          </div>
        ))}
      </div>
      <form className="chat-input" onSubmit={onSend}>
        <input
          onChange={(e) => setDraft(e.target.value)}
          placeholder="Describe the next task..."
          value={draft}
        />
        <button disabled={!activeSessionId || !draft.trim()} type="submit">
          Send
        </button>
      </form>
    </section>
  );
}
