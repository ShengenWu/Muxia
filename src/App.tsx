import { useEffect, useMemo } from "react";
import { isTauriRuntime, onBackendEvent, tauriInvoke } from "./lib/tauri";
import { useAppStore } from "./state/store";
import { CardLayout } from "./components/cards/CardLayout";
import { Sidebar } from "./components/sidebar/Sidebar";
import { useWorkspaceState } from "./state/workspace";

export default function App() {
  const appendEvent = useAppStore((s) => s.appendEvent);
  const sessions = useAppStore((s) => s.sessions);
  const activeSessionId = useAppStore((s) => s.activeSessionId);
  const setActiveSession = useAppStore((s) => s.setActiveSession);
  const { workspace, activeProject, activeLayout, setActiveProject, setActiveLayout } = useWorkspaceState();

  const projectSessions = useMemo(
    () =>
      Object.values(sessions)
        .filter((session) => session.projectId === activeProject.id)
        .sort((a, b) => a.startedAt.localeCompare(b.startedAt)),
    [activeProject.id, sessions]
  );

  useEffect(() => {
    let dispose = () => {};
    void onBackendEvent((event) => {
      appendEvent(event);
    }).then((unlisten) => {
      dispose = unlisten;
    });

    return () => dispose();
  }, [appendEvent]);

  useEffect(() => {
    if (projectSessions.length === 0) {
      return;
    }

    const hasActiveSession = projectSessions.some((session) => session.sessionId === activeSessionId);
    if (!hasActiveSession) {
      setActiveSession(projectSessions[0].sessionId);
    }
  }, [activeSessionId, projectSessions, setActiveSession]);

  useEffect(() => {
    if (!activeSessionId || !isTauriRuntime()) {
      return;
    }

    void tauriInvoke("set_active_session", {
      sessionId: activeSessionId
    }).catch(() => {
      // Ignore sync failures in browser-only mode; state still updates locally.
    });
  }, [activeSessionId]);

  return (
    <main className="app-root">
      <header className="topbar">
        <h1>new-terminal</h1>
        <p>Agent workflow workspace: chat, action graph, diff and terminal.</p>
      </header>
      <div className="workspace-shell">
        <Sidebar
          projects={workspace.projects}
          activeProjectId={activeProject.id}
          activeLayoutId={activeLayout.id}
          sessions={sessions}
          activeSessionId={activeSessionId}
          onProjectChange={setActiveProject}
          onLayoutChange={setActiveLayout}
          onSessionChange={setActiveSession}
        />
        <section className="workspace-main">
          <div className="workspace-status">
            <span className="workspace-badge">{activeProject.name}</span>
            <span className="workspace-badge">{activeLayout.name}</span>
          </div>
          <CardLayout
            storageScope={`${activeProject.id}:${activeLayout.id}`}
            defaultLayout={activeLayout.defaultGrid}
          />
        </section>
      </div>
    </main>
  );
}
