## Why

Clicking `Start Codex` from the Codex Card currently can terminate the debug session with Codex core startup errors such as missing data files, cache invalidation, task port lookup failure, and signal 13. This blocks the primary v0 workflow because the card cannot reliably launch or diagnose the `codex app-server` process that is supposed to be the structured runtime source.

## What Changes

- Make Codex Card startup resilient when `codex app-server` exits early, emits stderr diagnostics, or fails the initialize handshake.
- Capture and surface Codex core startup stderr and termination status in the card/store state instead of losing it behind a generic disconnected state.
- Ensure startup failures leave the Codex Card in a recoverable disconnected state with the existing project, card, and thread bindings intact.
- Add focused coverage for subprocess launch failure, handshake failure, and clean status transitions from `starting` to either `running` or `disconnected`.

## Capabilities

### New Capabilities
- `codex-core-launch-diagnostics`: Covers reliable Codex core/app-server launch from the Codex Card, startup error capture, recoverable failure state, and retry behavior.

### Modified Capabilities

## Impact

- Affects `Sources/MuxiaCore/Runtime/AppServerRuntime.swift`, especially `SubprocessAppServerTransport` and `AppServerRuntimeService` startup/stream handling.
- Affects `Sources/MuxiaCore/State/WorkbenchStore.swift` where runtime errors and status transitions are applied to Codex Card state.
- Affects Codex Card UI error display in `Sources/MuxiaCore/Views/WorkbenchViews.swift` only as needed to present actionable diagnostics.
- Adds or updates runtime tests in `Tests/MuxiaCoreTests/WorkbenchStoreTests.swift` with mock transports for early process exit, stderr, and handshake failure.
