import { useMemo } from "react";
import type { SessionRecord } from "../../types/events";
import type { WorkspaceLayoutPreset, WorkspaceProject } from "../../state/workspace";

interface SidebarProps {
  projects: WorkspaceProject[];
  activeProjectId: string;
  activeLayoutId: string;
  sessions: Record<string, SessionRecord>;
  activeSessionId?: string;
  onProjectChange: (projectId: string) => void;
  onLayoutChange: (layoutId: string) => void;
  onSessionChange: (sessionId: string) => void;
}

export function Sidebar({
  projects,
  activeProjectId,
  activeLayoutId,
  sessions,
  activeSessionId,
  onProjectChange,
  onLayoutChange,
  onSessionChange
}: SidebarProps) {
  const projectSessions = useMemo(
    () =>
      Object.values(sessions)
        .filter((session) => session.projectId === activeProjectId)
        .sort((a, b) => a.startedAt.localeCompare(b.startedAt)),
    [activeProjectId, sessions]
  );

  return (
    <aside className="sidebar-shell">
      <div className="sidebar-section">
        <p className="sidebar-kicker">Project Tree</p>
        {projects.map((project) => (
          <div className="project-block" key={project.id}>
            <button
              className={project.id === activeProjectId ? "nav-item active" : "nav-item"}
              type="button"
              onClick={() => onProjectChange(project.id)}
            >
              <span>{project.name}</span>
              <span className="nav-meta">{project.layouts.length} layouts</span>
            </button>
            {project.id === activeProjectId ? (
              <div className="layout-tree">
                {project.layouts.map((layout) => (
                  <LayoutButton
                    key={layout.id}
                    layout={layout}
                    active={layout.id === activeLayoutId}
                    onClick={onLayoutChange}
                  />
                ))}
              </div>
            ) : null}
          </div>
        ))}
      </div>
      <div className="sidebar-section">
        <p className="sidebar-kicker">Session List</p>
        {projectSessions.length > 0 ? (
          <div className="session-nav-list">
            {projectSessions.map((session) => (
              <button
                key={session.sessionId}
                className={session.sessionId === activeSessionId ? "nav-subitem active" : "nav-subitem"}
                type="button"
                onClick={() => onSessionChange(session.sessionId)}
              >
                <span>{session.agentType}:{session.sessionId.slice(0, 8)}</span>
                <span className="nav-meta">{session.endedAt ? "ended" : "active"}</span>
              </button>
            ))}
          </div>
        ) : (
          <p className="sidebar-note">No sessions for the active project yet. Start one from the chat card.</p>
        )}
      </div>
    </aside>
  );
}

interface LayoutButtonProps {
  layout: WorkspaceLayoutPreset;
  active: boolean;
  onClick: (layoutId: string) => void;
}

function LayoutButton({ layout, active, onClick }: LayoutButtonProps) {
  return (
    <button
      className={active ? "nav-subitem active" : "nav-subitem"}
      type="button"
      onClick={() => onClick(layout.id)}
    >
      {layout.name}
    </button>
  );
}
