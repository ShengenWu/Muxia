import { useEffect, useMemo, useState } from "react";
import { isTauriRuntime, onBackendEvent, tauriInvoke } from "./lib/tauri";
import { DiagnosticsPanel } from "./components/system/DiagnosticsPanel";
import { markRuntimeHealthy, runtimeLogger } from "./lib/runtimeDiagnostics";
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
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  const projectSessions = useMemo(
    () =>
      Object.values(sessions)
        .filter((session) => session.projectId === activeProject.id)
        .sort((a, b) => a.startedAt.localeCompare(b.startedAt)),
    [activeProject.id, sessions]
  );

  useEffect(() => {
    runtimeLogger.info("app", "App mounted");
    markRuntimeHealthy();
    let dispose = () => {};
    void onBackendEvent((event) => {
      runtimeLogger.debug("app", "Appending backend event into store", {
        event_type: event.event_type,
        session_id: event.session_id
      });
      appendEvent(event);
    }).then((unlisten) => {
      dispose = unlisten;
    });

    return () => {
      runtimeLogger.info("app", "App unmounted");
      dispose();
    };
  }, [appendEvent]);

  useEffect(() => {
    if (projectSessions.length === 0) {
      return;
    }

    const hasActiveSession = projectSessions.some((session) => session.sessionId === activeSessionId);
    if (!hasActiveSession) {
      runtimeLogger.info("app", "Project session set changed; selecting first session", {
        projectId: activeProject.id,
        sessionId: projectSessions[0].sessionId
      });
      setActiveSession(projectSessions[0].sessionId);
    }
  }, [activeProject.id, activeSessionId, projectSessions, setActiveSession]);

  useEffect(() => {
    if (!activeSessionId || !isTauriRuntime()) {
      return;
    }

    void tauriInvoke("set_active_session", {
      sessionId: activeSessionId
    })
      .then(() => {
        runtimeLogger.info("app", "Synced active session to Tauri backend", { activeSessionId });
      })
      .catch((error) => {
        runtimeLogger.error("app", "Failed to sync active session to Tauri backend", {
          activeSessionId,
          error
        });
        // Ignore sync failures in browser-only mode; state still updates locally.
      });
  }, [activeSessionId]);

  useEffect(() => {
    runtimeLogger.debug("app", "Active workspace context", {
      projectId: activeProject.id,
      layoutId: activeLayout.id,
      activeSessionId
    });
  }, [activeLayout.id, activeProject.id, activeSessionId]);

  const handleProjectCreate = () => {
    runtimeLogger.info("shell", "Project create requested before bootstrap milestone");
  };

  const handleCardCreate = () => {
    runtimeLogger.info("shell", "Card create requested before pane milestone", {
      projectId: activeProject.id,
      layoutId: activeLayout.id
    });
  };

  return (
    <main className="app-root">
      <header className="topbar">
        <div className="topbar-group topbar-group-left">
          <div className="traffic-lights" aria-hidden="true">
            <span className="traffic-light traffic-light-close" />
            <span className="traffic-light traffic-light-minimize" />
            <span className="traffic-light traffic-light-expand" />
          </div>
          <button className="shell-icon-button" type="button" onClick={handleProjectCreate}>
            +
          </button>
          <button
            className="shell-icon-button shell-toggle-button"
            type="button"
            onClick={() => setSidebarCollapsed((current) => !current)}
          >
            {sidebarCollapsed ? "[>]" : "[|]"}
          </button>
        </div>
        <div className="topbar-title">
          <strong>{activeProject.name}</strong>
          <span>{activeLayout.name}</span>
        </div>
        <div className="topbar-group topbar-group-right">
          <button className="shell-icon-button" type="button">
            !
          </button>
          <button className="shell-icon-button" type="button" onClick={handleCardCreate}>
            +
          </button>
        </div>
      </header>
      <div className={sidebarCollapsed ? "workspace-shell sidebar-collapsed" : "workspace-shell"}>
        <Sidebar
          projects={workspace.projects}
          activeProjectId={activeProject.id}
          activeLayoutId={activeLayout.id}
          sessions={sessions}
          activeSessionId={activeSessionId}
          collapsed={sidebarCollapsed}
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
      <DiagnosticsPanel />
    </main>
  );
}
