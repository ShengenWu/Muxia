import type { WorkspaceLayoutPreset, WorkspaceProject } from "../../state/workspace";

interface SidebarProps {
  projects: WorkspaceProject[];
  activeProjectId: string;
  activeLayoutId: string;
  onProjectChange: (projectId: string) => void;
  onLayoutChange: (layoutId: string) => void;
}

export function Sidebar({
  projects,
  activeProjectId,
  activeLayoutId,
  onProjectChange,
  onLayoutChange
}: SidebarProps) {
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
        <p className="sidebar-note">Session binding lands in the next milestone. Current facts remain scoped by `session_id` in the workspace cards.</p>
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
