## 1. Shell redesign foundation

- [x] 1.1 Replace the current app chrome with the cmux-aligned top bar, square-corner shell tokens, and black/gray-black surface hierarchy.
- [x] 1.2 Add top-bar control groups for traffic lights, project add, sidebar collapse, notifications, and card add.
- [x] 1.3 Restyle sidebar and workspace containers so shell dividers, typography, and card boundaries match the new visual rules.

## 2. Project bootstrap flow

- [x] 2.1 Add a Tauri command that opens a native directory picker and returns the selected project path.
- [x] 2.2 Extend workspace state to create or reuse project records from imported paths and bootstrap default layouts.
- [x] 2.3 Wire the left `+` action to the project picker flow and select the imported project/layout on success.

## 3. Pane workspace engine

- [ ] 3.1 Replace the current card layout renderer with a pane split model that supports single-card fill and multi-card auto-tiling.
- [ ] 3.2 Implement draggable pane dividers and persist split ratios per project layout.
- [ ] 3.3 Wire the right `+` action to add a card into the active pane layout and redistribute panes safely.

## 4. Validation and regression control

- [ ] 4.1 Add or update tests for workspace state, pane persistence, and project bootstrap behavior.
- [ ] 4.2 Run `npm test`, `npm run build`, and `npm run tauri:dev` with repeated launch smoke checks for startup restore stability.
- [ ] 4.3 Update task documentation and execution status before apply and after milestone completion.
