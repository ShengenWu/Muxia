## ADDED Requirements

### Requirement: Workspace auto-tiles cards as panes
The workbench SHALL render the active layout as panes that automatically distribute available workspace based on the number of cards present.

#### Scenario: Single card fills workspace
- **WHEN** the active layout contains one card
- **THEN** that card occupies the full available workspace area

#### Scenario: Two cards split workspace evenly by default
- **WHEN** the active layout contains two cards
- **THEN** the workspace renders two panes with a 50/50 initial split

### Requirement: Pane boundaries are resizable
The workbench SHALL allow the operator to drag pane boundaries so adjacent panes resize without removing card content.

#### Scenario: Operator resizes adjacent panes
- **WHEN** the operator drags a pane divider
- **THEN** the panes adjacent to that divider change size
- **AND** the cards assigned to those panes remain mounted and visible

### Requirement: Card creation adds a pane to the active layout
The workbench SHALL let the operator add a card from the right-side `+` action and place that card into the active pane layout.

#### Scenario: Adding a card updates active layout
- **WHEN** the operator activates the right `+` action and chooses a card type
- **THEN** the active layout gains a new card pane
- **AND** the workspace redistributes panes to keep all cards visible

### Requirement: Pane layout state is restored per layout
The workbench SHALL persist pane geometry and card placement for each layout and restore it when the operator reopens that layout.

#### Scenario: Reopening a layout restores pane geometry
- **WHEN** the operator returns to a previously edited layout
- **THEN** the workspace restores the saved pane sizes and card assignments for that layout
