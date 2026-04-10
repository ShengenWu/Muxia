import { useEffect, useMemo, useState } from "react";
import type { Layout } from "react-grid-layout";
import { runtimeLogger } from "../lib/runtimeDiagnostics";

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

interface PersistedWorkspaceSnapshot {
  version: number;
  data: WorkspaceSnapshot;
}

const STORAGE_KEY = "new-terminal-workspace";
const STORAGE_VERSION = 2;

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
  return Array.isArray(value) && value.every(isValidLayoutItem);
};

const isValidLayoutItem = (value: unknown): value is Layout => {
  if (!value || typeof value !== "object") {
    return false;
  }

  const item = value as Partial<Layout>;
  return (
    typeof item.i === "string"
    && typeof item.x === "number"
    && typeof item.y === "number"
    && typeof item.w === "number"
    && typeof item.h === "number"
    && Number.isFinite(item.x)
    && Number.isFinite(item.y)
    && Number.isFinite(item.w)
    && Number.isFinite(item.h)
    && item.w > 0
    && item.h > 0
  );
};

const loadWorkspace = (): WorkspaceSnapshot => {
  if (typeof window === "undefined") {
    runtimeLogger.info("workspace", "Loading default workspace outside browser window");
    return defaultWorkspace();
  }

  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    runtimeLogger.info("workspace", "No stored workspace snapshot; using defaults");
    return defaultWorkspace();
  }

  try {
    const parsed = JSON.parse(raw) as PersistedWorkspaceSnapshot | WorkspaceSnapshot;
    const snapshot = "data" in parsed ? parsed.data : parsed;
    const version = "version" in parsed ? parsed.version : 0;

    if (version !== STORAGE_VERSION) {
      runtimeLogger.warn("workspace", "Workspace storage version mismatch; resetting to defaults", {
        version
      });
      window.localStorage.removeItem(STORAGE_KEY);
      return defaultWorkspace();
    }

    if (!Array.isArray(snapshot.projects) || !snapshot.activeProjectId || !snapshot.activeLayoutId) {
      runtimeLogger.warn("workspace", "Stored workspace snapshot invalid; using defaults", snapshot);
      window.localStorage.removeItem(STORAGE_KEY);
      return defaultWorkspace();
    }

    const normalizedProjects = snapshot.projects
      .map((project) => ({
        ...project,
        layouts: Array.isArray(project.layouts)
          ? project.layouts.filter((layout) => isLayoutArray(layout.defaultGrid))
          : []
      }))
      .filter((project) => project.layouts.length > 0);

    if (normalizedProjects.length === 0) {
      runtimeLogger.warn("workspace", "Stored workspace has no valid projects; using defaults");
      window.localStorage.removeItem(STORAGE_KEY);
      return defaultWorkspace();
    }

    runtimeLogger.info("workspace", "Loaded workspace snapshot", {
      activeProjectId: snapshot.activeProjectId,
      activeLayoutId: snapshot.activeLayoutId,
      projectCount: normalizedProjects.length
    });
    return {
      projects: normalizedProjects,
      activeProjectId: snapshot.activeProjectId,
      activeLayoutId: snapshot.activeLayoutId
    };
  } catch {
    runtimeLogger.error("workspace", "Failed to parse workspace snapshot; using defaults");
    window.localStorage.removeItem(STORAGE_KEY);
    return defaultWorkspace();
  }
};

export function useWorkspaceState() {
  const [workspace, setWorkspace] = useState<WorkspaceSnapshot>(() => loadWorkspace());

  useEffect(() => {
    const persistedSnapshot: PersistedWorkspaceSnapshot = {
      version: STORAGE_VERSION,
      data: workspace
    };
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(persistedSnapshot));
    runtimeLogger.debug("workspace", "Persisted workspace snapshot", {
      activeProjectId: workspace.activeProjectId,
      activeLayoutId: workspace.activeLayoutId
    });
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
        runtimeLogger.warn("workspace", "Ignoring unknown project switch", { projectId });
        return current;
      }

      runtimeLogger.info("workspace", "Switching active project", {
        projectId,
        nextLayoutId: project.layouts[0]?.id
      });
      return {
        ...current,
        activeProjectId: projectId,
        activeLayoutId: project.layouts[0]?.id ?? current.activeLayoutId
      };
    });
  };

  const setActiveLayout = (layoutId: string) => {
    runtimeLogger.info("workspace", "Switching active layout", { layoutId });
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
