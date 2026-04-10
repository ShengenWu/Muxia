## Why

The current workbench UI proves the technical slice, but it does not yet provide a coherent operator-facing shell. The desktop surface needs to be redesigned now so the product feels intentional, supports project-first workflows, and aligns with the cmux-inspired interaction model expected for this tool.

## What Changes

- Replace the current visual shell with a cmux-aligned desktop frame using a black primary surface, white typography, dark-orange dividers, and strictly square corners.
- Redesign the top bar so the left side contains macOS traffic lights, a project creation `+` action, and a sidebar collapse toggle, while the right side contains a notifications action and a card creation `+` action.
- Introduce project-first navigation where the left `+` action opens a native directory picker, adds a project to the sidebar, and auto-generates an initial set of layouts for that project.
- Introduce layout-first composition where the right `+` action adds a new card into the active layout.
- Replace the static workspace arrangement with a pane-based tiling workspace that automatically distributes cards, supports drag resize between panes, and expands a single card to fill the available workspace.
- Restyle the left sidebar and workspace surfaces so the workspace remains pure black and the sidebar uses a distinct gray-black treatment.

## Capabilities

### New Capabilities
- `cmux-workbench-shell`: A cmux-inspired shell with top bar, sidebar styling, project creation entry points, and desktop visual rules.
- `project-layout-bootstrap`: Native project import flow that creates sidebar projects and default layouts from a selected local directory.
- `resizable-pane-workspace`: Pane-based card workspace with automatic distribution, resize handles, and add-card behavior for active layouts.

### Modified Capabilities
- None.

## Impact

- Frontend React shell components, global styling, card layout engine, and workspace state models.
- Tauri command surface for native directory selection and any layout bootstrap wiring.
- Validation expectations for desktop UX, including smoke testing of project import and pane resize behavior.
