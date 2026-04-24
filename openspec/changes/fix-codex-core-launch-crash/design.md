## Context

Muxia v0 uses the Codex Card as the primary entry point into `codex app-server`. The current runtime path creates a `SubprocessAppServerTransport`, runs `/usr/bin/env codex app-server --listen stdio://`, reads JSON-RPC envelopes from stdout, and performs `initialize` / `initialized` before marking the session `running`.

The reported failure happens immediately after clicking `Start Codex` and includes Codex core diagnostics:

- `fopen failed for data file: errno = 2 (No such file or directory)`
- `Errors found! Invalidating cache...`
- `Unable to obtain a task name port right for pid 411: (os/kern) failure (0x5)`
- `Debug session ended with code 13: Terminated due to signal 13`

The current transport assigns stderr to an unobserved `Pipe`, does not retain startup diagnostics, and only clears internal stream state on non-zero termination. That makes the user-visible card state too generic and makes it hard to distinguish missing runtime resources, Codex binary failure, JSON-RPC handshake failure, and a normal stream close.

## Goals / Non-Goals

**Goals:**

- Keep `Start Codex` from crashing or collapsing the Muxia debug session when Codex core exits early.
- Capture bounded stderr output and process termination details from `codex app-server`.
- Surface actionable startup diagnostics through the existing runtime error and Codex Card error path.
- Preserve the existing project, card, and thread bindings so the user can retry from the same card after fixing the underlying Codex environment.
- Add tests that exercise startup failure without launching a real Codex binary.

**Non-Goals:**

- Do not replace `codex app-server` with CLI TUI automation.
- Do not attempt to repair Codex core caches or OS task-port permissions from Muxia.
- Do not redesign the Codex Card chat UI beyond showing the failure reason already carried by runtime state.
- Do not introduce a new external logging dependency.

## Decisions

### 1. Treat subprocess diagnostics as runtime data

`SubprocessAppServerTransport` should retain stderr output in a bounded buffer and expose startup/termination failures as typed transport errors. When the process exits before or during the initialize handshake, the runtime should emit a `.runtimeError` that includes the executable, arguments, exit status or signal, and the most relevant stderr lines.

Alternative considered: log stderr only to the Xcode console. This is insufficient because the user starts Codex from the card and needs the card state to explain why startup failed.

### 2. Keep process ownership inside the transport, but notify the runtime on abnormal termination

The transport should remain responsible for `Process`, pipes, stdout decoding, and cleanup. The runtime service should consume failures through the existing async stream/request path and map them to `runtimeStatus(.disconnected)` plus a user-visible error.

Alternative considered: move `Process` ownership into `AppServerRuntimeService`. That would broaden the runtime actor and make mock transport testing harder, while the transport already owns the relevant lifecycle.

### 3. Make handshake timeout/failure explicit

`bootstrapSession` currently waits for `initialize` to resolve and then sends `initialized`. If the child exits before responding, pending continuations can be left without a clear startup reason. The implementation should ensure pending requests are completed on stream close or process termination with a transport error, so `bootstrapSession` can reliably transition to disconnected.

Alternative considered: rely on stdout line decoding to finish the stream. This misses cases where stderr explains the failure and stdout never emits a JSON-RPC response.

### 4. Preserve retry semantics on the same session/card

After abnormal startup failure, the Codex Card should remain present with status `disconnected` and `lastError` populated. A later `Start Codex` or reconnect path should create a fresh subprocess transport rather than reusing a poisoned closed stream.

Alternative considered: automatically retry in a loop. That risks hammering a broken Codex installation and obscuring the original diagnostic.

## Risks / Trade-offs

- [Risk] Stderr may contain noisy low-level platform messages. -> Mitigation: keep a bounded recent-lines buffer and include only startup-relevant diagnostics in the card error.
- [Risk] Transport errors could expose local filesystem paths. -> Mitigation: this is a local developer tool; keep diagnostics local in the app and avoid persistence beyond existing session state unless explicitly added later.
- [Risk] Race conditions between termination handler, stdout reader, and pending JSON-RPC requests. -> Mitigation: centralize stream-failure finalization inside the transport actor and add tests for early close and failed initialize.
- [Risk] The exact Codex core failure may be environment-specific. -> Mitigation: specify generic early-exit/diagnostic handling and test with mock transports rather than depending on the reported OS error.

## Migration Plan

1. Extend transport error modeling to represent process launch failure, abnormal termination, stream decoding failure, and handshake failure with captured diagnostics.
2. Update subprocess transport cleanup so all pending startup consumers observe a terminal error instead of hanging or silently disconnecting.
3. Update runtime bootstrap to map terminal startup errors into `.runtimeError` followed by `.runtimeStatus(.disconnected)`.
4. Keep existing successful app-server behavior and mock runtime behavior unchanged.
5. Add test transports that simulate stderr plus early termination, initialize error response, and stream close before handshake.

Rollback is straightforward: the change is isolated to the runtime transport/service and Codex Card error display. If needed, the app can fall back to the existing mock runtime while preserving the current UI.

## Open Questions

- Whether `Start Codex` should be hidden while a session is already `starting`, or whether repeated clicks should cancel and recreate the startup attempt.
- Whether the card should include a secondary “copy diagnostics” affordance once the error payload becomes more detailed.
