import { useEffect, useMemo, useState } from "react";
import type { Layout } from "react-grid-layout";
import { runtimeLogger } from "../lib/runtimeDiagnostics";
import { isPaneCardId, type PaneCardId } from "./layoutCards";

export interface WorkspaceLayoutPreset {
  id: string;
  name: string;
  defaultCards: PaneCardId[];
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

interface LegacyWorkspaceLayoutPreset {
  id: string;
  name: string;
  defaultGrid?: Layout[];
  defaultCards?: string[];
}

interface LegacyWorkspaceProject {
  id: string;
  name: string;
  rootPath?: string;
  layouts?: LegacyWorkspaceLayoutPreset[];
}

const STORAGE_KEY = "new-terminal-workspace";
const STORAGE_VERSION = 4;

const operationsLayout: Layout[] = [
  { i: "chat", x: 0, y: 0, w: 4, h: 7 },
  { i: "graph", x: 4, y: 0, w: 4, h: 7 },
  { i: "change_tracking", x: 8, y: 0, w: 4, h: 7 },
  { i: "diff", x: 0, y: 7, w: 7, h: 6 },
  { i: "terminal", x: 7, y: 7, w: 5, h: 6 }
];

const reviewLayout: Layout[] = [
  { i: "diff", x: 0, y: 0, w: 7, h: 8 },
  { i: "terminal", x: 7, y: 0, w: 5, h: 8 }
];

export const DEFAULT_PROJECT_ID = "project_alpha";
const DEFAULT_PROJECT_ROOT = "virtual://alpha-workbench";

const createDefaultLayouts = (): WorkspaceLayoutPreset[] => [
  { id: "layout_ops", name: "Ops Board", defaultCards: ["chat"] },
  { id: "layout_review", name: "Review Board", defaultCards: deriveCardsFromLegacyGrid(reviewLayout) }
];

const defaultWorkspace = (): WorkspaceSnapshot => ({
  projects: [
    {
      id: DEFAULT_PROJECT_ID,
      name: "Alpha Workbench",
      rootPath: DEFAULT_PROJECT_ROOT,
      layouts: createDefaultLayouts()
    }
  ],
  activeProjectId: DEFAULT_PROJECT_ID,
  activeLayoutId: "layout_ops"
});

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

const normalizeRootPath = (rootPath: string): string => {
  return rootPath.replace(/\\/g, "/").replace(/\/+$/, "");
};

const projectNameFromPath = (rootPath: string): string => {
  const normalized = normalizeRootPath(rootPath);
  const segments = normalized.split("/");
  return segments[segments.length - 1] || "Imported Project";
};

const projectIdFromPath = (rootPath: string): string => {
  const normalized = normalizeRootPath(rootPath);
  const slug = normalized
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(-48);
  return `project_${slug || "imported"}`;
};

export const createProjectIdFromPath = (rootPath: string): string => {
  return projectIdFromPath(rootPath);
};

const deriveCardsFromLegacyGrid = (items: Layout[]): PaneCardId[] => {
  return items
    .slice()
    .sort((a, b) => (a.y - b.y) || (a.x - b.x))
    .map((item) => item.i)
    .filter(isPaneCardId);
};

const normalizeCardList = (cards: unknown, legacyGrid?: Layout[]): PaneCardId[] => {
  if (Array.isArray(cards)) {
    const normalizedCards = cards.filter((card): card is PaneCardId => typeof card === "string" && isPaneCardId(card));
    if (normalizedCards.length > 0) {
      return normalizedCards;
    }
  }

  if (Array.isArray(legacyGrid) && legacyGrid.every(isValidLayoutItem)) {
    const gridCards = deriveCardsFromLegacyGrid(legacyGrid);
    if (gridCards.length > 0) {
      return gridCards;
    }
  }

  return ["chat"];
};

export const createProjectFromPath = (rootPath: string): WorkspaceProject => {
  const normalizedRootPath = normalizeRootPath(rootPath);
  return {
    id: projectIdFromPath(normalizedRootPath),
    name: projectNameFromPath(normalizedRootPath),
    rootPath: normalizedRootPath,
    layouts: createDefaultLayouts()
  };
};

export const createWorkspaceProjectFromPath = (rootPath: string): WorkspaceProject => {
  return createProjectFromPath(rootPath);
};

const normalizeWorkspace = (snapshot: WorkspaceSnapshot | { projects: LegacyWorkspaceProject[]; activeProjectId: string; activeLayoutId: string }): WorkspaceSnapshot | null => {
  if (!Array.isArray(snapshot.projects) || !snapshot.activeProjectId || !snapshot.activeLayoutId) {
    return null;
  }

  const normalizedProjects = snapshot.projects
    .map((project) => {
      const layouts = Array.isArray(project.layouts)
        ? project.layouts
            .map((layout) => ({
              id: layout.id,
              name: layout.name,
              defaultCards: normalizeCardList(
                "defaultCards" in layout ? layout.defaultCards : undefined,
                "defaultGrid" in layout ? layout.defaultGrid : undefined
              )
            }))
            .filter((layout) => layout.defaultCards.length > 0)
        : [];

      if (layouts.length === 0) {
        return null;
      }

      return {
        id: project.id,
        name: project.name,
        rootPath:
          typeof project.rootPath === "string" && project.rootPath.length > 0
            ? normalizeRootPath(project.rootPath)
            : `virtual://${project.id}`,
        layouts
      };
    })
    .filter((project): project is WorkspaceProject => project !== null);

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

    const normalized = normalizeWorkspace(snapshot as WorkspaceSnapshot);
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
  const normalizedRootPath = normalizeRootPath(rootPath);
  const existingProject = current.projects.find((project) => project.rootPath === normalizedRootPath);
  if (existingProject) {
    return {
      ...current,
      activeProjectId: existingProject.id,
      activeLayoutId: existingProject.layouts[0]?.id ?? current.activeLayoutId
    };
  }

  const nextProject = createProjectFromPath(normalizedRootPath);
  return {
    projects: [...current.projects, nextProject],
    activeProjectId: nextProject.id,
    activeLayoutId: nextProject.layouts[0]?.id ?? current.activeLayoutId
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
    runtimeLogger.info("workspace", "Importing project from path", { rootPath: normalizeRootPath(rootPath) });
    setWorkspace((current) => upsertProjectFromPath(current, rootPath));
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
