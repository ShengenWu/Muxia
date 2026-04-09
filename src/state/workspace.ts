import { useEffect, useMemo, useState } from "react";
import type { Layout } from "react-grid-layout";

export interface WorkspaceLayoutPreset {
  id: string;
  name: string;
  defaultGrid: Layout[];
}

export interface WorkspaceProject {
  id: string;
  name: string;
  layouts: WorkspaceLayoutPreset[];
}

export interface WorkspaceSnapshot {
  projects: WorkspaceProject[];
  activeProjectId: string;
  activeLayoutId: string;
}

const STORAGE_KEY = "new-terminal-workspace";

const operationsLayout: Layout[] = [
  { i: "chat", x: 0, y: 0, w: 4, h: 7 },
  { i: "graph", x: 4, y: 0, w: 4, h: 7 },
  { i: "change_tracking", x: 8, y: 0, w: 4, h: 7 },
  { i: "diff", x: 0, y: 7, w: 7, h: 6 },
  { i: "terminal", x: 7, y: 7, w: 5, h: 6 }
];

const reviewLayout: Layout[] = [
  { i: "chat", x: 0, y: 0, w: 4, h: 6 },
  { i: "change_tracking", x: 4, y: 0, w: 3, h: 6 },
  { i: "diff", x: 7, y: 0, w: 5, h: 8 },
  { i: "graph", x: 0, y: 6, w: 7, h: 7 },
  { i: "terminal", x: 7, y: 8, w: 5, h: 5 }
];

export const DEFAULT_PROJECT_ID = "project_alpha";

const defaultWorkspace = (): WorkspaceSnapshot => ({
  projects: [
    {
      id: DEFAULT_PROJECT_ID,
      name: "Alpha Workbench",
      layouts: [
        { id: "layout_ops", name: "Ops Board", defaultGrid: operationsLayout },
        { id: "layout_review", name: "Review Board", defaultGrid: reviewLayout }
      ]
    }
  ],
  activeProjectId: DEFAULT_PROJECT_ID,
  activeLayoutId: "layout_ops"
});

const isLayoutArray = (value: unknown): value is Layout[] => {
  return Array.isArray(value);
};

const loadWorkspace = (): WorkspaceSnapshot => {
  if (typeof window === "undefined") {
    return defaultWorkspace();
  }

  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    return defaultWorkspace();
  }

  try {
    const parsed = JSON.parse(raw) as WorkspaceSnapshot;
    if (!Array.isArray(parsed.projects) || !parsed.activeProjectId || !parsed.activeLayoutId) {
      return defaultWorkspace();
    }

    const normalizedProjects = parsed.projects
      .map((project) => ({
        ...project,
        layouts: Array.isArray(project.layouts)
          ? project.layouts.filter((layout) => isLayoutArray(layout.defaultGrid))
          : []
      }))
      .filter((project) => project.layouts.length > 0);

    if (normalizedProjects.length === 0) {
      return defaultWorkspace();
    }

    return {
      projects: normalizedProjects,
      activeProjectId: parsed.activeProjectId,
      activeLayoutId: parsed.activeLayoutId
    };
  } catch {
    return defaultWorkspace();
  }
};

export function useWorkspaceState() {
  const [workspace, setWorkspace] = useState<WorkspaceSnapshot>(() => loadWorkspace());

  useEffect(() => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(workspace));
  }, [workspace]);

  const activeProject = useMemo(
    () => workspace.projects.find((project) => project.id === workspace.activeProjectId) ?? workspace.projects[0],
    [workspace]
  );

  const activeLayout = useMemo(() => {
    const project = activeProject ?? workspace.projects[0];
    return project.layouts.find((layout) => layout.id === workspace.activeLayoutId) ?? project.layouts[0];
  }, [activeProject, workspace]);

  const setActiveProject = (projectId: string) => {
    setWorkspace((current) => {
      const project = current.projects.find((item) => item.id === projectId);
      if (!project) {
        return current;
      }

      return {
        ...current,
        activeProjectId: projectId,
        activeLayoutId: project.layouts[0]?.id ?? current.activeLayoutId
      };
    });
  };

  const setActiveLayout = (layoutId: string) => {
    setWorkspace((current) => ({
      ...current,
      activeLayoutId: layoutId
    }));
  };

  return {
    workspace,
    activeProject,
    activeLayout,
    setActiveProject,
    setActiveLayout
  };
}
