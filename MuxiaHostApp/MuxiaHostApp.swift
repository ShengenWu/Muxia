import SwiftUI
import MuxiaCore

@main
struct MuxiaHostApp: App {
    @StateObject private var store = WorkbenchStore()

    var body: some Scene {
        WindowGroup("Muxia") {
            HostWorkbenchRootView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
    }
}

private struct HostWorkbenchRootView: View {
    @ObservedObject var store: WorkbenchStore
    @State private var didAttemptRestoration = false

    var body: some View {
        configuredRoot
    }

    @ViewBuilder
    private var configuredRoot: some View {
        let root = WorkbenchRootView(store: store)
            .frame(minWidth: 1320, minHeight: 820)
            .task {
                guard !didAttemptRestoration else { return }
                didAttemptRestoration = true

                // Yield once so restoration starts after the root workbench view is in the scene.
                await Task.yield()
                store.attemptRuntimeRestoration()
            }

        if #available(macOS 15.0, *) {
            root
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .toolbar(removing: .title)
        } else {
            root
        }
    }
}
