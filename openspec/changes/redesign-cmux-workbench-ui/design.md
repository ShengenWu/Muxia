## Context

The current alpha workbench proves cross-pane coordination, session state, and desktop integration, but its shell is visually provisional and its workspace arrangement is still implementation-driven rather than operator-driven. The requested redesign introduces three cross-cutting changes at once: a new cmux-inspired shell, a native project import flow, and a pane-based workspace that supports card composition and resizing. These changes touch frontend presentation, persisted workspace models, and the Tauri command surface.

## Goals / Non-Goals

**Goals:**
- Establish a deterministic visual system: pure black workspace, gray-black sidebar, white typography, dark-orange dividers, and zero corner radius.
- Replace the top bar and sidebar interaction model so project creation, sidebar collapse, notifications, and card creation have stable desktop entry points.
- Add a native directory picker flow that creates a new project record and a default layout set from the chosen local folder.
- Replace the current fixed card arrangement with a pane layout engine that can auto-tile cards and persist user resize adjustments.
- Keep the redesign compatible with the existing Tauri-based desktop shell and current card inventory.

**Non-Goals:**
- Rewriting card internals such as chat rendering, graph rendering, or diff semantics.
- Introducing rounded variants, alternate themes, or platform-specific visual branches beyond the requested macOS traffic-light area.
- Building a fully tmux-compatible terminal multiplexer model; the goal is visual and interaction alignment, not protocol parity.

## Decisions

### 1. Introduce a shell-specific design token layer
The redesign will centralize shell colors, spacing, border widths, and corner rules in top-level CSS variables instead of scattering overrides across card components. This keeps the restyle scoped and makes the “no rounded corners” rule enforceable.

Alternative considered: one-off restyling inside each component. Rejected because it is brittle and guarantees visual drift.

### 2. Split workspace state into project metadata, layout metadata, and pane tree state
The current workspace persistence is sufficient for basic layout selection, but pane resizing requires a more explicit state shape. The redesign will persist:
- project records keyed by local root path
- layout records per project
- pane tree or split descriptors for each layout, including card assignment and split ratios

Alternative considered: deriving pane layout ad hoc from card order. Rejected because resize state and reproducible workspace restoration need explicit persisted geometry.

### 3. Use a native Tauri directory-picker command for project creation
The left `+` action will call a backend command that opens the system directory picker and returns the selected path. The frontend will normalize the returned path into a project record, derive an initial layout set, and select the new project.

Alternative considered: using a plain text path input. Rejected because the requirement explicitly calls for Finder/system dialog integration and because desktop-native selection is materially safer.

### 4. Use a pane split model rather than a dashboard grid model
The main workspace will move from dashboard-style placement to pane-style splits. The implementation should model a layout as recursive horizontal/vertical splits with leaf panes containing cards. This matches the requested “one card fills the view, two cards split, four cards expose adjustable borders” interaction better than a freeform dashboard grid.

Alternative considered: continuing with a CSS grid or generic drag dashboard library. Rejected because it does not naturally express split-handle resizing or terminal-multiplexer-like behavior.

### 5. Restore progressive enhancement around heavy cards
The redesign should preserve the current card-level error boundaries and lazy loading for advanced cards. Workspace shell changes must not regress the recent blank-window fix.

Alternative considered: tightening the redesign around only the shell and removing diagnostics. Rejected because recent failures showed that shell-level stability still depends on visible diagnostics and isolated fallback behavior.

## Risks / Trade-offs

- [Pane layout model adds state complexity] → Mitigation: keep the initial pane schema minimal, only supporting the split patterns needed for current card counts and add-card flows.
- [Native project picker differs across platforms] → Mitigation: define the contract in Tauri at the command boundary and keep the frontend agnostic to platform-specific dialog details.
- [Full visual restyle could leak into card internals] → Mitigation: enforce shell tokens at container boundaries first and only patch card internals where contrast or spacing actually breaks.
- [Resizing interactions can destabilize persistence] → Mitigation: version the persisted pane layout schema and validate it before restore, following the existing startup hardening pattern.
- [More actions in the top bar can crowd narrow widths] → Mitigation: keep controls icon-only and preserve the collapsible sidebar so the workspace remains primary.

## Migration Plan

1. Introduce the new shell tokens and top bar/sidebar structure behind the current app entry.
2. Add the native project picker command and wire project bootstrap to default layout creation.
3. Replace the existing workspace layout renderer with the pane split renderer while preserving existing cards and per-card fallbacks.
4. Migrate persisted workspace/layout records to the new versioned schema, clearing incompatible state during startup recovery if required.
5. Re-run desktop smoke validation, including repeated launches to confirm that restore logic remains stable.

## Open Questions

- Whether notifications in this milestone are only a visual affordance or need a backed-by-state popover immediately.
- Which default card set should be generated for a newly imported project’s first layout: minimal (Chat + Terminal) or full operator preset.
- Whether pane drag interactions should be mouse-only for now or include keyboard resizing in a follow-up change.
