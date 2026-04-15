import SwiftUI
import MuxiaCore

@main
struct MuxiaHostApp: App {
    @StateObject private var store = WorkbenchStore()

    var body: some Scene {
        WindowGroup("Muxia") {
            HostWorkbenchRootView(store: store)
        }
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
    }
}

private struct HostWorkbenchRootView: View {
    @ObservedObject var store: WorkbenchStore
    @State private var didAttemptRestoration = false

    var body: some View {
        WorkbenchRootView(store: store)
            .frame(minWidth: 1320, minHeight: 820)
            .task {
                guard !didAttemptRestoration else { return }
                didAttemptRestoration = true

                // Yield once so restoration starts after the root workbench view is in the scene.
                await Task.yield()
                store.attemptRuntimeRestoration()
            }
    }
}
