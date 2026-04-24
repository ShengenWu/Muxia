## ADDED Requirements

### Requirement: Codex Card startup captures Codex core launch diagnostics
The system SHALL capture Codex app-server startup diagnostics when the Codex Card launches the local Codex core process.

#### Scenario: Codex core emits stderr and exits before handshake
- **WHEN** the user starts Codex from an idle Codex Card and the `codex app-server` child process writes stderr before exiting
- **THEN** the system records a runtime error that includes the relevant stderr diagnostics and process termination status
- **AND** the Codex Card displays the failure through its existing error surface

#### Scenario: Codex core executable cannot be launched
- **WHEN** the user starts Codex from an idle Codex Card and the local Codex executable cannot be launched
- **THEN** the system records a runtime error that identifies the launch failure
- **AND** the Codex Card transitions out of `starting`

### Requirement: Codex Card startup failure is recoverable
The system SHALL keep the Codex Card and its workspace bindings recoverable when Codex app-server startup fails.

#### Scenario: Startup fails before running
- **WHEN** Codex app-server fails before the initialize handshake completes
- **THEN** the bound runtime session transitions to `disconnected`
- **AND** the project, workspace, card, and existing thread bindings remain intact
- **AND** the user can retry starting Codex from the same Codex Card

#### Scenario: Retry after startup failure creates a fresh transport
- **WHEN** the user retries Codex startup after a previous early process exit
- **THEN** the system creates a fresh app-server transport attempt
- **AND** it does not reuse a closed stdout stream or poisoned pending request state from the failed attempt

### Requirement: Codex app-server handshake failures resolve pending startup work
The system SHALL complete or fail all pending startup requests when the Codex app-server stream closes or fails during initialization.

#### Scenario: Stream closes while initialize is pending
- **WHEN** the app-server stdout stream closes before responding to `initialize`
- **THEN** the pending initialize request fails with a runtime transport error
- **AND** the runtime emits a disconnected status instead of leaving the Codex Card stuck in `starting`

#### Scenario: Initialize returns an error response
- **WHEN** Codex app-server responds to `initialize` with a JSON-RPC error
- **THEN** the runtime surfaces that error as the Codex Card startup failure
- **AND** the runtime does not send `initialized`
