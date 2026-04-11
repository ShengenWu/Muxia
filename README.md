# new-terminal

Agent workflow-first terminal workspace.

## Stack
- Tauri v2 (Rust backend)
- React + TypeScript frontend
- xterm.js terminal card
- Monaco diff card
- SQLite event history

## Run frontend build/test
```bash
npm install
npm run build
npm test
```

## Run desktop app
Requires Rust toolchain and Tauri prerequisites.

```bash
npm run tauri:dev
```

## Implemented MVP skeleton
- Card layout with persistence (Chat, Session Graph, Diff, Terminal)
- Typed cross-layer event model (`session.started`, `action.detected`, `diff.updated`, ...)
- Rust commands: `create_session`, `send_user_message`, `write_pty`, `end_session`
- PTY spawn and line parsing adapters for Claude/Codex CLI output
- Workspace file watcher and diff snapshot emission
- SQLite persistence for events and diff artifacts
