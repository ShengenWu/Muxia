import { useEffect } from "react";
import { onBackendEvent } from "./lib/tauri";
import { useAppStore } from "./state/store";
import { CardLayout } from "./components/cards/CardLayout";
import { Sidebar } from "./components/sidebar/Sidebar";
import { useWorkspaceState } from "./state/workspace";

export default function App() {
  const appendEvent = useAppStore((s) => s.appendEvent);
  const { workspace, activeProject, activeLayout, setActiveProject, setActiveLayout } = useWorkspaceState();

  useEffect(() => {
    let dispose = () => {};
    void onBackendEvent((event) => {
      appendEvent(event);
    }).then((unlisten) => {
      dispose = unlisten;
    });

    return () => dispose();
  }, [appendEvent]);

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
          onProjectChange={setActiveProject}
          onLayoutChange={setActiveLayout}
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
