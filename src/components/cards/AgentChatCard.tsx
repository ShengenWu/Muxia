import { FormEvent, useState } from "react";
import { tauriInvoke } from "../../lib/tauri";
import { useAppStore } from "../../state/store";

export function AgentChatCard() {
  const [draft, setDraft] = useState("");
  const [adapter, setAdapter] = useState<"claude" | "codex">("claude");
  const activeSessionId = useAppStore((s) => s.activeSessionId);
  const messages = useAppStore((s) =>
    activeSessionId ? s.messages[activeSessionId] ?? [] : []
  );
  const setActiveSession = useAppStore((s) => s.setActiveSession);

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
      <div className="card-meta-bar">
        {activeSessionId ? (
          <span className="muted">active session {activeSessionId.slice(0, 8)}</span>
        ) : (
          <span className="muted">Create a session to start the chain.</span>
        )}
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
