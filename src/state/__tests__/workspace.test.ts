import { describe, expect, it } from "vitest";
import {
  createProjectIdFromPath,
  createWorkspaceProjectFromPath,
  upsertProjectFromPath,
  type WorkspaceSnapshot
} from "../workspace";

const baseWorkspace = (): WorkspaceSnapshot => ({
  projects: [createWorkspaceProjectFromPath("/alpha-workbench")],
  activeProjectId: createProjectIdFromPath("/alpha-workbench"),
  activeLayoutId: "layout_ops"
});

describe("workspace project bootstrap", () => {
  it("creates stable project metadata from a path", () => {
    const project = createWorkspaceProjectFromPath("/Users/demo/code/new-terminal");

    expect(project.id).toBe("project_users_demo_code_new_terminal");
    expect(project.name).toBe("new-terminal");
    expect(project.rootPath).toBe("/Users/demo/code/new-terminal");
    expect(project.layouts).toHaveLength(2);
  });

  it("adds a new imported project and activates it", () => {
    const next = upsertProjectFromPath(baseWorkspace(), "/Users/demo/code/cmux-app");

    expect(next.projects).toHaveLength(2);
    expect(next.activeProjectId).toBe("project_users_demo_code_cmux_app");
    expect(next.activeLayoutId).toBe("layout_ops");
  });

  it("reuses an existing project when the same path is imported again", () => {
    const current = upsertProjectFromPath(baseWorkspace(), "/Users/demo/code/cmux-app");
    const next = upsertProjectFromPath(current, "/Users/demo/code/cmux-app");

    expect(next.projects).toHaveLength(2);
    expect(next.activeProjectId).toBe("project_users_demo_code_cmux_app");
  });
});
