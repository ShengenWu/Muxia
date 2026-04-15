# Muxia Development

## Default Run Target

- Open `Muxia.xcodeproj` at the repository root.
- Run the shared `Muxia` macOS scheme for local development and UI verification.
- Treat the root `Package.swift` as a shared module and test definition only. It is no longer the primary application host.

## Project Boundaries

- `Muxia.xcodeproj` owns the macOS host app target, bundle metadata, assets, and the default shared scheme.
- `MuxiaHostApp/` contains the host-only app entrypoint and bundle resources.
- `Sources/MuxiaCore/` remains the shared package module for domain, state, persistence, runtime mocks, and the workbench root view.
- `Tests/MuxiaCoreTests/` stays package-level so shared logic can still be verified outside the host app target.

## Verification Baseline

Preferred path:

1. Use XcodeBuildMCP against `/Applications/Xcode.app` with project `Muxia.xcodeproj` and scheme `Muxia`.
2. Build the `Muxia` scheme for macOS Debug.
3. Launch the built app and confirm the primary `Muxia` window opens directly into the workbench root view.
4. Verify the main window enforces the v0 minimum usable size of `1320x820`.
5. Run `swift test` to keep the shared package module and tests green.

Fallback when working outside XcodeBuildMCP:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Muxia.xcodeproj -scheme Muxia -configuration Debug -destination 'platform=macOS' build`
- `swift test`
