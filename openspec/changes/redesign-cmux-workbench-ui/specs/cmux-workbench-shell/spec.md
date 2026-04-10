## ADDED Requirements

### Requirement: Cmux-aligned shell styling
The desktop shell SHALL render a cmux-aligned chrome that uses white foreground text, black primary workspace surfaces, dark-orange divider lines, a gray-black sidebar surface, and square corners across shell-level controls and containers.

#### Scenario: Shell renders required palette and shape language
- **WHEN** the workbench window renders
- **THEN** the main workspace surface is black
- **AND** the sidebar surface is visually distinct gray-black
- **AND** shell text is white
- **AND** shell divider lines use dark orange
- **AND** shell containers and controls do not render rounded corners

### Requirement: Top bar provides fixed control placement
The desktop shell SHALL render a top bar whose left side contains the macOS traffic-light controls, a project creation action, and a sidebar collapse/expand action, and whose right side contains a notifications action and a card creation action.

#### Scenario: Top bar renders expected control groups
- **WHEN** the shell header is visible
- **THEN** the left header group shows traffic-light controls, a `+` project action, and a sidebar toggle
- **AND** the right header group shows a notifications action and a `+` card action

### Requirement: Sidebar supports collapse without breaking workspace access
The desktop shell SHALL allow the operator to collapse and re-expand the sidebar while keeping the workspace visible and interactive.

#### Scenario: Sidebar collapse toggles shell layout
- **WHEN** the operator activates the sidebar collapse control
- **THEN** the sidebar width is reduced or hidden
- **AND** the workspace expands to consume the released space
- **AND** activating the control again restores sidebar visibility
