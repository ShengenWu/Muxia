## 1. Runtime Error Modeling

- [x] 1.1 Add typed transport errors for app-server launch failure, abnormal process termination, stream decoding failure, and initialize handshake failure.
- [x] 1.2 Add a bounded stderr diagnostics buffer to `SubprocessAppServerTransport` and include recent stderr lines in startup failure descriptions.
- [x] 1.3 Ensure transport cleanup completes or fails pending startup consumers when stdout closes or the process terminates before handshake completion.

## 2. Startup Lifecycle Handling

- [x] 2.1 Update `AppServerRuntimeService.bootstrapSession` to emit `.runtimeError` plus `.runtimeStatus(.disconnected)` for launch, stream, and handshake failures.
- [x] 2.2 Ensure failed startup attempts do not leave stale pending responses, closed streams, or active process handles attached to the session.
- [x] 2.3 Ensure retrying from the same Codex Card creates a fresh app-server transport attempt after early exit.

## 3. Codex Card Diagnostics

- [x] 3.1 Verify `WorkbenchStore` preserves project, workspace, card, and thread bindings while applying startup failure errors and disconnected status.
- [x] 3.2 Adjust Codex Card error presentation only as needed so captured startup diagnostics are visible without disrupting the chat-first layout.
- [x] 3.3 Prevent duplicate or conflicting status transitions when startup failure and stream closure arrive close together.

## 4. Verification

- [x] 4.1 Add mock transport tests for stderr plus early process exit before `initialize` completes.
- [x] 4.2 Add mock transport tests for JSON-RPC initialize error response and confirm `initialized` is not sent.
- [x] 4.3 Add store-level tests that startup failure leaves the Codex Card disconnected, recoverable, and retryable.
- [x] 4.4 Run the focused Swift test suite for runtime and store behavior.
