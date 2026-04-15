# Repository Guidelines

## Project Overview

This repository is for **Muxia**, a new macOS-native product under active development at the repo root. The current v0 product and architecture guidance lives under `.docs/`, especially `.docs/v0-codex-only/`. Treat `.docs/` as the source of truth for high-level product direction, interaction rules, and MVP boundaries.

## Documentation Structure

- `.docs/`: top-level product guidance, v0 PRD, architecture, state model, frontend interaction, and technical planning documents.
- `openspec/`: finer-grained planning artifacts generated through OpenSpec. This tree stores `spec`, `change`, `task`, and `plan` level documents used to drive implementation.
- `cmux-example/`: reference codebase only. Muxia is being rebuilt in the current repository root, not developed in-place inside `cmux-example/`.

## Working With `cmux-example`

Use `cmux-example/` as a source of implementation ideas, reusable low-level logic, and UI assets where the behavior is intentionally aligned. Do not treat it as the live app architecture. When code, assets, or interaction patterns are migrated closely from `cmux-example/`, explicitly note that the implementation is derived from `cmux`.

## Coding and Change Rules

Match surrounding style and keep edits narrow. Prefer Swift/macOS-native patterns for the product code at the repo root. If a change is behaviorally significant, update the relevant `.docs/` or `openspec/` artifact in the same line of work so implementation and planning stay aligned.

## Commit Guidelines

Use Git with focused, imperative conventional commits such as `feat:`, `fix:`, `docs:`, and `chore:`. Example: `fix: preserve focused tab after split close`. Keep commits scoped to one meaningful change and call out any migrated `cmux` logic in the commit body or PR description when relevant.
