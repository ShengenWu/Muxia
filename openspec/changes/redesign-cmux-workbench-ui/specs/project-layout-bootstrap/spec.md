## ADDED Requirements

### Requirement: Project creation uses native directory selection
The workbench SHALL use a native system directory picker when the operator activates the left-side project creation action.

#### Scenario: Operator creates project from local directory
- **WHEN** the operator activates the left `+` action in the top bar
- **THEN** the system opens a native directory selection dialog
- **AND** selecting a directory returns its local path to the workbench

### Requirement: Imported projects become sidebar entries
The workbench SHALL create a new sidebar project entry from the selected directory and make it available for subsequent layout operations.

#### Scenario: Selected directory becomes active project
- **WHEN** a directory is successfully selected
- **THEN** the workbench creates or reuses a project record for that path
- **AND** the project appears in the sidebar project list
- **AND** the imported project becomes the active project

### Requirement: New projects receive default layouts automatically
The workbench SHALL generate an initial set of layouts for a newly imported project without requiring a separate setup flow.

#### Scenario: New project gets bootstrap layouts
- **WHEN** the workbench imports a directory that does not already exist as a project
- **THEN** it creates the default layouts defined for new projects
- **AND** it selects one of those layouts as the active layout for that project
