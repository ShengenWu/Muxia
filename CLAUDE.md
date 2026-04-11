# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agent workflow-first terminal workspace built with Tauri v2 (Rust backend) + React/TypeScript frontend. Provides observable terminal sessions with structured event tracking, file change monitoring, and session graph visualization.

## Development Commands

```bash
# Frontend development
npm install          # Install dependencies
npm run dev          # Vite dev server (frontend only)
npm run build        # TypeScript check + Vite build
npm test             # Run Vitest tests
npm run lint         # ESLint

# Desktop app (requires Rust toolchain)
npm run tauri:dev    # Full desktop app with hot reload
npm run tauri:build  # Production build
```

## Architecture

### Core Data Flow

**Single-direction event pipeline:**
```
PTY/Watcher → Rust EventBus → Frontend Store → Cards
```

**Dual-channel PTY output:**
- Channel A: Raw byte stream → Terminal/Chat display
- Channel B: Adapter parsing → Structured events → Event bus

### Event Contract

All persisted events use `snake_case` naming (e.g., `session_started`, `action_tool_call`, `file_changed`). External adapters may output dot-notation events but must normalize to snake_case before persistence/broadcast.

**Standard event types:**
- Messages: `message_user`, `message_assistant`, `message_system`
- Actions: `action_tool_call`, `action_tool_result`
- Files: `file_changed`, `file_created`, `file_deleted`
- Lifecycle: `session_started`, `session_ended`, `session_error`

### Graph Model

- **Nodes:** Message | Action | Artifact | SessionEvent
- **Edges:** `next | caused_by | reads | writes | validates | updates | branches_to`
- Tool calls that read/write files must create `reads`/`writes` edges to Artifact nodes

### Storage

SQLite is the source of truth for all events. Events table is append-only, indexed by `session_id + timestamp` for replay.

## Code Structure

```
src/
├── components/cards/    # Card implementations (Chat, Graph, Diff, Terminal)
├── state/              # Zustand stores + tests
├── lib/                # Tauri command wrappers
└── types/              # TypeScript event types

src-tauri/src/
├── adapters/           # CLI output parsers (Claude, Codex)
├── pty.rs             # PTY spawn and management
├── event_bus.rs       # Event routing and broadcast
├── graph.rs           # Session graph construction
├── watcher.rs         # File system monitoring
├── db.rs              # SQLite persistence
└── main.rs            # Tauri commands
```

## Coding Conventions

- **TypeScript:** 2-space indent, strict mode, explicit types preferred
- **React:** PascalCase for components/files, camelCase for functions/variables
- **Rust:** Follow `rustfmt` defaults
- **Event naming:** Always `snake_case` for cross-layer contracts
- **Commits:** Conventional Commits format (`feat:`, `fix:`, `chore:`)

## Documentation Organization

- Product spec: `docs/spec.md`
- Architecture: `docs/architecture.md`
- Technical decisions: `docs/decisions/*.md` (ADR format, numbered from 0001)
- Task-specific docs: `docs/tasks/*.md`
- Active implementation plan: `.agent/PLANS.md`
- Implementation constraints: `.agent/IMPLEMENT.md`

## Planning Requirements

**Must update task-specific docs + `.agent/PLANS.md` before coding if:**
- Adding new features or card types
- Making cross-layer changes (src/ + src-tauri/)
- Modifying event contracts, persistence schema, or state models
- Changing 3+ files
- Work requires multiple milestones

## Tauri Commands

**Session management:**
- `start_session`, `write_to_session`, `resize_session`, `end_session`

**Project/layout:**
- `create_project`, `list_projects`, `open_project`
- `save_layout`, `create_card`, `remove_card`, `update_card_state`

Frontend interacts with backend exclusively through typed command wrappers (`src/lib/tauri.ts`) and `backend:event` subscriptions.

## Testing

Run tests before committing:
```bash
npm test              # Frontend unit tests
npm run build         # Type checking
```

## Key Design Principles

1. **Event sourcing:** All state changes flow through events, enabling replay and time-travel debugging
2. **Adapter isolation:** CLI output parsing is isolated in adapters; prefer structured output (e.g., Claude `stream-json`) over regex parsing
3. **Idempotent events:** Events include idempotency keys to handle reordering/replay
4. **Project boundaries:** File watcher respects project scope and ignores `.git/`, `node_modules/`, build artifacts
