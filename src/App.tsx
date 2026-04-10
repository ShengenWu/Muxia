import { useEffect, useMemo, useState } from "react";
import { CardLayout } from "./components/cards/CardLayout";
import { Sidebar } from "./components/sidebar/Sidebar";
import { DiagnosticsPanel } from "./components/system/DiagnosticsPanel";
import { runtimeLogger, markRuntimeHealthy } from "./lib/runtimeDiagnostics";
import { isTauriRuntime, onBackendEvent, tauriInvoke } from "./lib/tauri";
import { useAppStore } from "./state/store";
import { useWorkspaceState } from "./state/workspace";

export default function App() {
  const appendEvent = useAppStore((s) => s.appendEvent);
  const sessions = useAppStore((s) => s.sessions);
  const activeSessionId = useAppStore((s) => s.activeSessionId);
  const setActiveSession = useAppStore((s) => s.setActiveSession);
  const {
    workspace,
    activeProject,
    activeLayout,
    setActiveProject,
    setActiveLayout,
    createOrActivateProjectFromPath
  } = useWorkspaceState();
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
      });
  }, [activeSessionId]);

  useEffect(() => {
    runtimeLogger.debug("app", "Active workspace context", {
      projectId: activeProject.id,
      layoutId: activeLayout.id,
      activeSessionId
    });
  }, [activeLayout.id, activeProject.id, activeSessionId]);

  const handleProjectCreate = async () => {
    if (!isTauriRuntime()) {
      runtimeLogger.warn("shell", "Project import requested outside Tauri runtime");
      return;
    }

    try {
      const response = await tauriInvoke<{ path: string | null }>("pick_project_directory");
      if (!response.path) {
        runtimeLogger.info("shell", "Project import canceled by user");
        return;
      }
      createOrActivateProjectFromPath(response.path);
    } catch (error) {
      runtimeLogger.error("shell", "Failed to import project directory", { error });
    }
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
          <button
            className="shell-icon-button"
            type="button"
            onClick={() => void handleProjectCreate()}
            title="Add project"
          >
            +
          </button>
          <button
            className="shell-icon-button shell-toggle-button"
            type="button"
            onClick={() => setSidebarCollapsed((current) => !current)}
            title={sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            {sidebarCollapsed ? ">" : "<"}
          </button>
        </div>
        <div className="topbar-title">
          <strong>{activeProject.name}</strong>
          <span>{activeLayout.name}</span>
        </div>
        <div className="topbar-group topbar-group-right">
          <button className="shell-icon-button" type="button" title="Notifications">
            !
          </button>
          <button className="shell-icon-button" type="button" onClick={handleCardCreate} title="Add card">
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
            <span className="workspace-badge">project:{activeProject.id}</span>
            <span className="workspace-badge">layout:{activeLayout.id}</span>
            <span className="workspace-badge">sessions:{projectSessions.length}</span>
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
