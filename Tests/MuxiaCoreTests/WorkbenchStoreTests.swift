import Testing
import Foundation
@testable import MuxiaCore

struct WorkbenchStoreTests {
    @Test func jsonRPCStdioFramingEncodesAndDecodesLineDelimitedMessages() throws {
        let message = JSONRPCWireMessage(
            id: .number(1),
            method: "initialize",
            params: .object([
                "clientInfo": .object([
                    "name": .string("Muxia")
                ])
            ]),
            result: nil,
            error: nil
        )

        let framed = try JSONRPCStdioFraming.encode(message)
        let framedText = String(decoding: framed, as: UTF8.self)
        #expect(framedText.hasPrefix("{"))
        #expect(framedText.hasSuffix("\n"))

        var buffer = framed
        let decoded = try JSONRPCStdioFraming.decodeAvailableMessages(from: &buffer)
        #expect(decoded.count == 1)
        #expect(decoded[0].method == "initialize")
        #expect(decoded[0].id?.intValue == 1)
        #expect(buffer.isEmpty)
    }

    @Test func jsonRPCWireMessageDecodesResponsesWithoutExplicitJSONRPCVersion() throws {
        let payload = Data(#"{"id":1,"result":{"userAgent":"Muxia/0.124.0","codexHome":"/Users/shengen/.codex","platformFamily":"unix","platformOs":"macos"}}"#.utf8)
        let decoded = try JSONDecoder().decode(JSONRPCWireMessage.self, from: payload)

        #expect(decoded.id?.intValue == 1)
        #expect(decoded.result?.objectValue?["platformOs"]?.stringValue == "macos")
        #expect(decoded.jsonrpc == nil)
    }

    @Test func appServerExecutableResolverPrefersExplicitExecutable() throws {
        let temporaryCodex = temporaryDirectory(named: "codex-bin").appendingPathComponent("codex")
        FileManager.default.createFile(atPath: temporaryCodex.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporaryCodex.path)

        let resolved = AppServerExecutableResolver.resolveCodexExecutable(
            environment: ["MUXIA_CODEX_EXECUTABLE": temporaryCodex.path]
        )

        #expect(resolved == temporaryCodex.path)
        #expect(AppServerExecutableResolver.defaultArguments(for: resolved) == ["app-server", "--listen", "stdio://"])
    }

    @Test func appServerLaunchEnvironmentIncludesHomebrewPaths() {
        let environment = AppServerExecutableResolver.launchEnvironment(base: ["PATH": "/usr/bin"])
        let path = environment["PATH"] ?? ""

        #expect(path.hasPrefix("/opt/homebrew/bin:/usr/local/bin:"))
        #expect(path.split(separator: ":").filter { $0 == "/usr/bin" }.count == 1)
    }

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
        let codexCard = project?.workspaces.first?.cards.first(where: { $0.kind == .agentChat })
        #expect(codexCard?.title == "Codex")
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
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            store.sendMessage("hello runtime", from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let initialThreads = await MainActor.run { store.threads() }
        #expect(initialThreads.count == 1)

        await MainActor.run {
            store.forkActiveThread(from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let afterNew = await MainActor.run { store.threads() }
        #expect(afterNew.count == 2)

        await MainActor.run {
            store.resumeThread(initialThreads[0], from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let session = await MainActor.run { store.session(for: store.codexCard()!.id) }
        #expect(afterNew.map(\.id).contains(session?.activeThreadID ?? UUID()))
        let messages = await MainActor.run { store.chatState(for: store.codexCard()!.id).messages }
        #expect(messages.contains(where: { $0.role == .assistant }))
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
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        await MainActor.run {
            store.sendMessage("seed first thread", from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let graphCard = await MainActor.run { store.selectedWorkspace!.cards.first(where: { $0.kind == .threadGraph })! }
        let changeCard = await MainActor.run { store.selectedWorkspace!.cards.first(where: { $0.kind == .changeTracking })! }
        let diffCard = await MainActor.run { store.selectedWorkspace!.cards.first(where: { $0.kind == .diff })! }
        let editorCard = await MainActor.run { store.selectedWorkspace!.cards.first(where: { $0.kind == .editor })! }
        let editorBinding = editorCard.binding
        let firstThread = await MainActor.run { store.activeThreadID(for: graphCard) }

        await MainActor.run {
            store.forkActiveThread(from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let secondThread = await MainActor.run { store.activeThreadID(for: graphCard) }
        let changeThread = await MainActor.run { store.activeThreadID(for: changeCard) }
        let diffThread = await MainActor.run { store.activeThreadID(for: diffCard) }
        let editorAfterSwitch = await MainActor.run { store.selectedWorkspace!.cards.first(where: { $0.kind == .editor })! }
        let note = await MainActor.run { store.selectedWorkspace?.note.text }
        #expect(firstThread != secondThread)
        #expect(changeThread == secondThread)
        #expect(diffThread == secondThread)
        #expect(editorAfterSwitch.binding == editorBinding)
        #expect(note == "remember manual review")
    }

    @Test func approvalAndInterruptUpdateChatState() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: MockCodexRuntimeService())
        }
        let url = temporaryDirectory(named: "approval-project")
        await MainActor.run {
            store.openProject(at: url)
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            store.sendMessage("needs approval", from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let pendingBefore = await MainActor.run { store.chatState(for: store.codexCard()!.id).pendingApprovals }
        #expect(pendingBefore.count == 1)

        await MainActor.run {
            store.resolveApproval(pendingBefore[0], decision: .approve, from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let approvalState = await MainActor.run { store.chatState(for: store.codexCard()!.id) }
        #expect(approvalState.pendingApprovals.isEmpty)
        #expect(approvalState.messages.contains(where: { $0.role == .assistant }))

        await MainActor.run {
            store.sendMessage("hold response open", from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let generatingBeforeInterrupt = await MainActor.run { store.chatState(for: store.codexCard()!.id).isGenerating }
        #expect(generatingBeforeInterrupt)

        await MainActor.run {
            store.interruptTurn(from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let generatingAfterInterrupt = await MainActor.run { store.chatState(for: store.codexCard()!.id).isGenerating }
        #expect(!generatingAfterInterrupt)
    }

    @Test func relaunchRestoresWorkspaceAndFallsBackToDisconnectedWhenReconnectFails() async throws {
        let fileURL = temporaryFileURL()
        let savingStore = await MainActor.run {
            WorkbenchStore(persistence: PrototypePersistenceController(fileURL: fileURL), runtimeEnvironment: MockCodexRuntimeService())
        }
        let url = temporaryDirectory(named: "restore-project")
        await MainActor.run {
            savingStore.openProject(at: url)
            savingStore.startSession(for: savingStore.codexCard()!.id)
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

    @Test func appServerRuntimeHandshakeAndSteerFlowUseExplicitProtocolMethods() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let transport = ScriptedAppServerTransport()
        let runtime = AppServerRuntimeService(transportFactory: { transport })
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: runtime)
        }
        let url = temporaryDirectory(named: "scripted-runtime")
        await MainActor.run {
            store.openProject(at: url)
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let sessionAfterHandshake = await MainActor.run { store.session(for: store.codexCard()!.id) }
        #expect(sessionAfterHandshake?.status == .running)

        await MainActor.run {
            store.sendMessage("first prompt", from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            store.sendMessage("follow up", from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let methods = await transport.sentMethods()
        #expect(methods.contains("initialize"))
        #expect(methods.contains("thread/start"))
        #expect(methods.contains("turn/start"))
        #expect(methods.contains("turn/steer"))
        let threadStartParams = await transport.lastParams(for: "thread/start")
        #expect(threadStartParams?.objectValue?["sessionStartSource"]?.stringValue == "startup")

        let messages = await MainActor.run { store.chatState(for: store.codexCard()!.id).messages }
        #expect(messages.contains(where: { $0.role == .assistant && !$0.text.isEmpty }))
    }

    @Test func appServerCompletesTurnFromCompletedResponseItemWithoutExplicitTurnCompleted() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let transport = ScriptedAppServerTransport(startupMode: .itemCompletedOnly)
        let runtime = AppServerRuntimeService(transportFactory: { transport })
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: runtime)
        }
        let url = temporaryDirectory(named: "scripted-item-completed")
        await MainActor.run {
            store.openProject(at: url)
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            store.sendMessage("first prompt", from: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let chatState = await MainActor.run { store.chatState(for: store.codexCard()!.id) }
        #expect(!chatState.isGenerating)
        #expect(chatState.messages.contains(where: { $0.role == .assistant && $0.text == "completed response body" }))
    }

    @Test func appServerHandshakeFailureSurfacesDisconnectedState() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let transport = ScriptedAppServerTransport(startupMode: .failInitialize)
        let runtime = AppServerRuntimeService(transportFactory: { transport })
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: runtime)
        }
        let url = temporaryDirectory(named: "scripted-failure")
        await MainActor.run {
            store.openProject(at: url)
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let session = await MainActor.run { store.session(for: store.codexCard()!.id) }
        let error = await MainActor.run { store.chatState(for: store.codexCard()!.id).lastError }
        let methods = await transport.sentMethods()
        #expect(session?.status == .disconnected)
        #expect(error != nil)
        #expect(error?.contains("initialize failed") == true)
        #expect(!methods.contains("initialized"))
    }

    @Test func appServerEarlyExitSurfacesDiagnosticsAndDisconnectedState() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let transport = ScriptedAppServerTransport(
            startupMode: .failStreamBeforeInitialize([
                "fopen failed for data file: errno = 2 (No such file or directory)",
                "Errors found! Invalidating cache...",
                "Unable to obtain a task name port right for pid 411: (os/kern) failure (0x5)"
            ])
        )
        let runtime = AppServerRuntimeService(transportFactory: { transport })
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: runtime)
        }
        let url = temporaryDirectory(named: "scripted-early-exit")
        await MainActor.run {
            store.openProject(at: url)
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let session = await MainActor.run { store.session(for: store.codexCard()!.id) }
        let error = await MainActor.run { store.chatState(for: store.codexCard()!.id).lastError }
        let project = await MainActor.run { store.selectedProject }
        let workspace = await MainActor.run { store.selectedWorkspace }
        #expect(session?.status == .disconnected)
        #expect(error?.contains("terminated with status 13") == true)
        #expect(error?.contains("fopen failed for data file") == true)
        #expect(project != nil)
        #expect(workspace?.cards.contains(where: { $0.kind == .agentChat }) == true)
    }

    @Test func appServerStartupRetryUsesFreshTransportForSameCodexCard() async throws {
        let persistence = PrototypePersistenceController(fileURL: temporaryFileURL())
        let factory = CountingTransportFactory(startupModes: [
            .failStreamBeforeInitialize(["Debug session ended with code 13: Terminated due to signal 13"]),
            .normal
        ])
        let runtime = AppServerRuntimeService(transportFactory: { factory.makeTransport() })
        let store = await MainActor.run {
            WorkbenchStore(persistence: persistence, runtimeEnvironment: runtime)
        }
        let url = temporaryDirectory(named: "scripted-retry")
        await MainActor.run {
            store.openProject(at: url)
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let failedSessionID = await MainActor.run { store.session(for: store.codexCard()!.id)?.id }
        let failedStatus = await MainActor.run { store.session(for: store.codexCard()!.id)?.status }
        #expect(failedStatus == .disconnected)

        await MainActor.run {
            store.startSession(for: store.codexCard()!.id)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let retriedSession = await MainActor.run { store.session(for: store.codexCard()!.id) }
        let sessionCount = await MainActor.run { store.runtimeSessions.count }
        #expect(retriedSession?.status == .running)
        #expect(retriedSession?.id != failedSessionID)
        #expect(sessionCount == 1)
        #expect(factory.createdCount() == 2)
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

actor ScriptedAppServerTransport: AppServerTransporting {
    enum StartupMode: Sendable {
        case normal
        case itemCompletedOnly
        case failInitialize
        case failStreamBeforeInitialize([String])
    }

    private let startupMode: StartupMode
    private var continuation: AsyncThrowingStream<AppServerEnvelope, Error>.Continuation?
    private var methods: [String] = []
    private var paramsByMethod: [String: JSONValue?] = [:]
    private let threadID = "scripted-thread-1"
    private var activeTurnID = "scripted-turn-1"

    init(startupMode: StartupMode = .normal) {
        self.startupMode = startupMode
    }

    func connect() async throws -> AsyncThrowingStream<AppServerEnvelope, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func sendRequest(id: JSONRPCID, method: String, params: JSONValue?) async throws {
        methods.append(method)
        paramsByMethod[method] = params
        switch method {
        case "initialize":
            switch startupMode {
            case .normal:
                continuation?.yield(.response(id: id, result: .object([:]), error: nil))
            case .itemCompletedOnly:
                continuation?.yield(.response(id: id, result: .object([:]), error: nil))
            case .failInitialize:
                continuation?.yield(.response(id: id, result: nil, error: "initialize failed"))
            case .failStreamBeforeInitialize(let diagnostics):
                continuation?.finish(
                    throwing: RuntimeTransportError.abnormalTermination(
                        executable: "/usr/bin/env",
                        arguments: ["codex", "app-server", "--listen", "stdio://"],
                        status: 13,
                        reason: "signal",
                        diagnostics: diagnostics
                    )
                )
            }
        case "thread/start":
            continuation?.yield(
                .response(
                    id: id,
                    result: .object([
                        "thread": .object([
                            "id": .string(threadID),
                            "title": .string("Scripted Thread"),
                            "status": .string("active")
                        ])
                    ]),
                    error: nil
                )
            )
        case "turn/start":
            activeTurnID = "scripted-turn-1"
            continuation?.yield(
                .response(
                    id: id,
                    result: .object([
                        "turn": .object([
                            "id": .string(activeTurnID),
                            "sequenceNumber": .number(1)
                        ])
                    ]),
                    error: nil
                )
            )
            continuation?.yield(
                .notification(
                    method: "item/started",
                    params: .object([
                        "threadId": .string(threadID),
                        "turnId": .string(activeTurnID),
                        "item": .object([
                            "id": .string("assistant-item-1"),
                            "type": .string("agentMessage"),
                            "title": .string("Assistant")
                        ])
                    ])
                )
            )
            if case .itemCompletedOnly = startupMode {
                continuation?.yield(
                    .notification(
                        method: "item/completed",
                        params: .object([
                            "threadId": .string(threadID),
                            "turnId": .string(activeTurnID),
                            "item": .object([
                                "id": .string("assistant-item-1"),
                                "type": .string("agentMessage"),
                                "title": .string("Assistant"),
                                "text": .string("completed response body")
                            ])
                        ])
                    )
                )
                return
            }
            continuation?.yield(
                .notification(
                    method: "item/agentMessage/delta",
                    params: .object([
                        "threadId": .string(threadID),
                        "turnId": .string(activeTurnID),
                        "itemId": .string("assistant-item-1"),
                        "delta": .string("hello from app server")
                    ])
                )
            )
        case "turn/steer":
            continuation?.yield(.response(id: id, result: .object([:]), error: nil))
            continuation?.yield(
                .notification(
                    method: "item/agentMessage/delta",
                    params: .object([
                        "threadId": .string(threadID),
                        "turnId": .string(activeTurnID),
                        "itemId": .string("assistant-item-1"),
                        "delta": .string(" + steer")
                    ])
                )
            )
            continuation?.yield(.notification(method: "turn/completed", params: .object([:])))
        default:
            continuation?.yield(.response(id: id, result: .object([:]), error: nil))
        }
        _ = params
    }

    func sendNotification(method: String, params: JSONValue?) async throws {
        methods.append(method)
        _ = params
    }

    func sendResponse(id: JSONRPCID, result: JSONValue?) async throws {
        methods.append("response:\(id.rawString)")
        _ = result
    }

    func disconnect() async {
        continuation?.finish()
    }

    func sentMethods() -> [String] {
        methods
    }

    func lastParams(for method: String) -> JSONValue? {
        paramsByMethod[method] ?? nil
    }
}

private final class CountingTransportFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var startupModes: [ScriptedAppServerTransport.StartupMode]
    private var count = 0

    init(startupModes: [ScriptedAppServerTransport.StartupMode]) {
        self.startupModes = startupModes
    }

    func makeTransport() -> any AppServerTransporting {
        lock.lock()
        defer { lock.unlock() }
        let mode = startupModes.isEmpty ? .normal : startupModes.removeFirst()
        count += 1
        return ScriptedAppServerTransport(startupMode: mode)
    }

    func createdCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
