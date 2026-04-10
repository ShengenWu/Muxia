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
  rootPath: string;
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
const STORAGE_VERSION = 3;

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

export const buildDefaultLayouts = (): WorkspaceLayoutPreset[] => [
  { id: "layout_ops", name: "Ops Board", defaultGrid: operationsLayout },
  { id: "layout_review", name: "Review Board", defaultGrid: reviewLayout }
];

const createProjectNameFromPath = (rootPath: string): string => {
  const trimmed = rootPath.replace(/[\\/]+$/, "");
  const segments = trimmed.split(/[\\/]/).filter(Boolean);
  return segments[segments.length - 1] || "Imported Project";
};

export const createProjectIdFromPath = (rootPath: string): string => {
  const normalized = rootPath.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
  return `project_${normalized || "imported"}`;
};

export const createWorkspaceProjectFromPath = (rootPath: string): WorkspaceProject => ({
  id: createProjectIdFromPath(rootPath),
  name: createProjectNameFromPath(rootPath),
  rootPath,
  layouts: buildDefaultLayouts()
});

const defaultWorkspace = (): WorkspaceSnapshot => ({
  projects: [
    {
      id: DEFAULT_PROJECT_ID,
      name: "Alpha Workbench",
      rootPath: "/alpha-workbench",
      layouts: buildDefaultLayouts()
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

const normalizeWorkspace = (snapshot: WorkspaceSnapshot): WorkspaceSnapshot | null => {
  if (!Array.isArray(snapshot.projects) || !snapshot.activeProjectId || !snapshot.activeLayoutId) {
    return null;
  }

  const normalizedProjects = snapshot.projects
    .map((project) => ({
      ...project,
      rootPath: typeof project.rootPath === "string" ? project.rootPath : "",
      layouts: Array.isArray(project.layouts)
        ? project.layouts.filter((layout) => isLayoutArray(layout.defaultGrid))
        : []
    }))
    .filter((project) => project.rootPath && project.layouts.length > 0);

  if (normalizedProjects.length === 0) {
    return null;
  }

  const activeProject = normalizedProjects.find((project) => project.id === snapshot.activeProjectId) ?? normalizedProjects[0];
  const activeLayout = activeProject.layouts.find((layout) => layout.id === snapshot.activeLayoutId) ?? activeProject.layouts[0];

  return {
    projects: normalizedProjects,
    activeProjectId: activeProject.id,
    activeLayoutId: activeLayout.id
  };
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

    const normalized = normalizeWorkspace(snapshot);
    if (!normalized) {
      runtimeLogger.warn("workspace", "Stored workspace snapshot invalid; using defaults", snapshot);
      window.localStorage.removeItem(STORAGE_KEY);
      return defaultWorkspace();
    }

    runtimeLogger.info("workspace", "Loaded workspace snapshot", {
      activeProjectId: normalized.activeProjectId,
      activeLayoutId: normalized.activeLayoutId,
      projectCount: normalized.projects.length
    });
    return normalized;
  } catch {
    runtimeLogger.error("workspace", "Failed to parse workspace snapshot; using defaults");
    window.localStorage.removeItem(STORAGE_KEY);
    return defaultWorkspace();
  }
};

export const upsertProjectFromPath = (current: WorkspaceSnapshot, rootPath: string): WorkspaceSnapshot => {
  const existingProject = current.projects.find((project) => project.rootPath === rootPath);
  if (existingProject) {
    return {
      ...current,
      activeProjectId: existingProject.id,
      activeLayoutId: existingProject.layouts[0]?.id ?? current.activeLayoutId
    };
  }

  const nextProject = createWorkspaceProjectFromPath(rootPath);
  return {
    projects: [...current.projects, nextProject],
    activeProjectId: nextProject.id,
    activeLayoutId: nextProject.layouts[0].id
  };
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

  const createOrActivateProjectFromPath = (rootPath: string) => {
    const normalizedPath = rootPath.trim();
    if (!normalizedPath) {
      runtimeLogger.warn("workspace", "Ignoring empty project import path");
      return;
    }

    runtimeLogger.info("workspace", "Importing project from path", { rootPath: normalizedPath });
    setWorkspace((current) => upsertProjectFromPath(current, normalizedPath));
  };

  return {
    workspace,
    activeProject,
    activeLayout,
    setActiveProject,
    setActiveLayout,
    createOrActivateProjectFromPath
  };
}
