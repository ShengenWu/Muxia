import Testing
import Foundation
@testable import MuxiaCore

struct WorkbenchStoreTests {
    @Test func openingProjectSeedsDefaultWorkspaceAndCards() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence)
        }
        let url = temporaryDirectory(named: "seed-project")

        await MainActor.run {
            store.openProject(at: url)
        }

        let project = await MainActor.run { store.selectedProject }
        #expect(project?.workspaces.count == 1)
        #expect(project?.workspaces.first?.cards.count == 6)
    }

    @Test func defaultWorkspaceUsesSplitPaneLayout() async throws {
        let workspace = await MainActor.run {
            WorkbenchStore.makeDefaultWorkspace(name: "Prototype")
        }
        switch workspace.layout {
        case .split(axis: let axis, ratio: _, first: let first, second: _):
            #expect(axis == .horizontal)
            if case .split(axis: let childAxis, ratio: _, first: _, second: _) = first {
                #expect(childAxis == .vertical)
            } else {
                Issue.record("Expected nested vertical split")
            }
        default:
            Issue.record("Expected root split layout")
        }
    }

    @Test func runtimeLifecycleCreatesThreadAndAllowsSwitching() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: MockCodexRuntimeService())
        }
        let url = temporaryDirectory(named: "runtime-project")
        await MainActor.run {
            store.openProject(at: url)
            store.startSession(for: store.agentCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let initialThreads = await MainActor.run { store.threads() }
        #expect(initialThreads.count == 1)

        await MainActor.run {
            store.newThread(from: store.agentCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let afterNew = await MainActor.run { store.threads() }
        #expect(afterNew.count == 2)

        await MainActor.run {
            store.resumePreviousThread(from: store.agentCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let session = await MainActor.run { store.session(for: store.agentCard()!.id) }
        #expect(afterNew.map(\.id).contains(session?.activeThreadID ?? UUID()))
    }

    @Test func snapshotTrackerCreatesFileChanges() async throws {
        let root = temporaryDirectory(named: "tracking-project")
        let file = root.appending(path: "main.swift")
        try "print(\"a\")".write(to: file, atomically: true, encoding: .utf8)
        let tracker = ProjectSnapshotTracker()

        _ = try await tracker.scanProject(at: root)
        try "print(\"b\")".write(to: file, atomically: true, encoding: .utf8)
        let changes = try await tracker.scanProject(at: root)

        #expect(changes.count == 1)
        #expect(changes.first?.before == "print(\"a\")")
        #expect(changes.first?.after == "print(\"b\")")
    }

    @Test func notesRemainWorkspaceScopedAndFollowingCardsUseActiveThread() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: MockCodexRuntimeService())
        }
        let url = temporaryDirectory(named: "notes-project")
        await MainActor.run {
            store.openProject(at: url)
            store.updateWorkspaceNote("remember manual review")
            store.startSession(for: store.agentCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let graphCard = await MainActor.run { store.selectedWorkspace!.cards.first(where: { $0.kind == .threadGraph })! }
        let firstThread = await MainActor.run { store.activeThreadID(for: graphCard) }

        await MainActor.run {
            store.newThread(from: store.agentCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let secondThread = await MainActor.run { store.activeThreadID(for: graphCard) }
        let note = await MainActor.run { store.selectedWorkspace?.note.text }
        #expect(firstThread != secondThread)
        #expect(note == "remember manual review")
    }

    @Test func relaunchRestoresWorkspaceAndFallsBackToDisconnectedWhenReconnectFails() async throws {
        let fileURL = temporaryFileURL()
        let savingStore = await MainActor.run {
            WorkbenchStore(persistence: PrototypePersistenceController(fileURL: fileURL), runtimeEnvironment: MockCodexRuntimeService())
        }
        let url = temporaryDirectory(named: "restore-project")
        await MainActor.run {
            savingStore.openProject(at: url)
            savingStore.startSession(for: savingStore.agentCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let restoringStore = await MainActor.run {
            WorkbenchStore(
                persistence: PrototypePersistenceController(fileURL: fileURL),
                runtimeEnvironment: FailingReconnectRuntimeService()
            )
        }
        await MainActor.run {
            restoringStore.attemptRuntimeRestoration()
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let workspace = await MainActor.run { restoringStore.selectedWorkspace }
        let session = await MainActor.run { restoringStore.runtimeSessions.first }
        #expect(workspace != nil)
        #expect(session?.status == .disconnected)
    }
}

private func temporaryDirectory(named name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: name + "-" + UUID().uuidString, directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func temporaryFileURL() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: UUID().uuidString + ".json")
}
