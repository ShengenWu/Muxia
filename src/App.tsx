import { useEffect, useMemo, useState } from "react";
import { CardLayout } from "./components/cards/CardLayout";
import { Sidebar } from "./components/sidebar/Sidebar";
import { runtimeLogger, markRuntimeHealthy } from "./lib/runtimeDiagnostics";
import { emitFrontendLog, isTauriRuntime, onBackendEvent, tauriInvoke } from "./lib/tauri";
import { ALL_CARD_IDS, type PaneCardId } from "./state/layoutCards";
import { useAppStore } from "./state/store";
import { useWorkspaceState } from "./state/workspace";

export default function App() {
  emitFrontendLog("app", "App function invoked");
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
  const [layoutCards, setLayoutCards] = useState<PaneCardId[]>(activeLayout.defaultCards);
  const [pendingAddCardId, setPendingAddCardId] = useState<PaneCardId | undefined>(undefined);

  const projectSessions = useMemo(
    () =>
      Object.values(sessions)
        .filter((session) => session.projectId === activeProject.id)
        .sort((a, b) => a.startedAt.localeCompare(b.startedAt)),
    [activeProject.id, sessions]
  );

  useEffect(() => {
    const emitLayoutProbe = (stage: string) => {
      const topbar = document.querySelector(".topbar") as HTMLElement | null;
      const sidebar = document.querySelector(".sidebar-shell") as HTMLElement | null;
      const workspace = document.querySelector(".workspace-main") as HTMLElement | null;
      const appRoot = document.querySelector(".app-root") as HTMLElement | null;
      const centerX = Math.max(0, Math.floor(window.innerWidth / 2));
      const centerY = Math.max(0, Math.floor(window.innerHeight / 2));
      const topLeftElement = document.elementFromPoint(20, 20);
      const centerElement = document.elementFromPoint(centerX, centerY);
      const bodyStyle = window.getComputedStyle(document.body);
      const topbarStyle = topbar ? window.getComputedStyle(topbar) : null;
      const styleSheets = [...document.styleSheets].map((sheet) => {
        try {
          return {
            href: sheet.href ?? "inline",
            rules: sheet.cssRules.length
          };
        } catch {
          return {
            href: sheet.href ?? "inline",
            rules: "unavailable"
          };
        }
      });

      emitFrontendLog("app-dom", `Layout probe:${stage}`, {
        viewport: {
          innerWidth: window.innerWidth,
          innerHeight: window.innerHeight,
          outerWidth: window.outerWidth,
          outerHeight: window.outerHeight,
          devicePixelRatio: window.devicePixelRatio
        },
        bodyText: document.body.innerText.slice(0, 160),
        bodyStyle: {
          display: bodyStyle.display,
          visibility: bodyStyle.visibility,
          opacity: bodyStyle.opacity,
          background: bodyStyle.backgroundColor,
          color: bodyStyle.color
        },
        appRoot: appRoot?.getBoundingClientRect().toJSON(),
        topbar: topbar?.getBoundingClientRect().toJSON(),
        topbarStyle: topbarStyle
          ? {
              display: topbarStyle.display,
              visibility: topbarStyle.visibility,
              opacity: topbarStyle.opacity,
              background: topbarStyle.backgroundColor,
              color: topbarStyle.color
            }
          : null,
        sidebar: sidebar?.getBoundingClientRect().toJSON(),
        workspace: workspace?.getBoundingClientRect().toJSON(),
        topLeftElement: topLeftElement
          ? {
              tag: topLeftElement.tagName,
              className: topLeftElement.className,
              text: topLeftElement.textContent?.slice(0, 80)
            }
          : null,
        centerElement: centerElement
          ? {
              tag: centerElement.tagName,
              className: centerElement.className,
              text: centerElement.textContent?.slice(0, 80)
            }
          : null,
        overlays: {
          monacoEditors: document.querySelectorAll(".monaco-editor").length,
          xtermRoots: document.querySelectorAll(".xterm").length,
          canvases: document.querySelectorAll("canvas").length
        },
        styleSheets
      });
    };

    runtimeLogger.info("app", "App mounted");
    emitFrontendLog("app", "App mounted");
    emitLayoutProbe("mount");
    const rafId = window.requestAnimationFrame(() => emitLayoutProbe("raf"));
    const timeoutId = window.setTimeout(() => emitLayoutProbe("settled-500ms"), 500);
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
      window.cancelAnimationFrame(rafId);
      window.clearTimeout(timeoutId);
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

  useEffect(() => {
    setLayoutCards(activeLayout.defaultCards);
    setPendingAddCardId(undefined);
  }, [activeLayout.defaultCards, activeLayout.id]);

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
    const nextCardId = ALL_CARD_IDS.find((cardId) => !layoutCards.includes(cardId));
    if (!nextCardId) {
      runtimeLogger.info("shell", "No additional cards available for active layout", {
        projectId: activeProject.id,
        layoutId: activeLayout.id
      });
      return;
    }

    runtimeLogger.info("shell", "Queueing card add for active layout", {
      projectId: activeProject.id,
      layoutId: activeLayout.id,
      cardId: nextCardId
    });
    setPendingAddCardId(nextCardId);
  };

  return (
    <main className="app-root">
      <header className="topbar" data-tauri-drag-region>
        <div className="topbar-group topbar-group-left">
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
          <CardLayout
            storageScope={`${activeProject.id}:${activeLayout.id}`}
            defaultCards={activeLayout.defaultCards}
            pendingAddCardId={pendingAddCardId}
            onPendingAddHandled={() => setPendingAddCardId(undefined)}
            onCardsChange={setLayoutCards}
          />
        </section>
      </div>
    </main>
  );
}
