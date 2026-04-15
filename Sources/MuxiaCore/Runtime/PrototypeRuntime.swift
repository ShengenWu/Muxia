import Foundation

public enum CodexAppServerEvent: Sendable {
    case runtimeStatus(RuntimeStatus)
    case threadActivated(CodexThreadRecord)
    case turnCreated(CodexTurnRecord)
    case itemCreated(CodexItemRecord)
}

public protocol CodexRuntimeClient: Sendable {
    func startSession(for project: ProjectRecord, cardID: UUID) async -> RuntimeSessionRecord
    func reconnect(session: RuntimeSessionRecord) async -> RuntimeSessionRecord?
    func end(session: RuntimeSessionRecord) async -> RuntimeSessionRecord
}

public protocol CodexAppServerClient: Sendable {
    func eventStream(for session: RuntimeSessionRecord) async -> AsyncStream<CodexAppServerEvent>
}

public protocol CodexRuntimeControlling: Sendable {
    func newThread(for session: RuntimeSessionRecord) async
    func resumePreviousThread(for session: RuntimeSessionRecord) async
    func compactCurrentThread(for session: RuntimeSessionRecord) async
}

public typealias CodexRuntimeEnvironment = CodexRuntimeClient & CodexAppServerClient & CodexRuntimeControlling

public actor MockCodexRuntimeService: CodexRuntimeEnvironment {
    private var continuations: [UUID: AsyncStream<CodexAppServerEvent>.Continuation] = [:]
    private var threadHistory: [UUID: [CodexThreadRecord]] = [:]
    private var currentThread: [UUID: CodexThreadRecord] = [:]

    public init() {}

    public func startSession(for project: ProjectRecord, cardID: UUID) async -> RuntimeSessionRecord {
        RuntimeSessionRecord(cardID: cardID, projectID: project.id, status: .starting)
    }

    public func reconnect(session: RuntimeSessionRecord) async -> RuntimeSessionRecord? {
        var restored = session
        restored.status = .running
        restored.updatedAt = .now
        return restored
    }

    public func end(session: RuntimeSessionRecord) async -> RuntimeSessionRecord {
        var ended = session
        ended.status = .ended
        ended.updatedAt = .now
        continuations[session.id]?.yield(.runtimeStatus(.ended))
        continuations[session.id]?.finish()
        continuations[session.id] = nil
        return ended
    }

    public func eventStream(for session: RuntimeSessionRecord) async -> AsyncStream<CodexAppServerEvent> {
        AsyncStream { continuation in
            continuations[session.id] = continuation
            continuation.yield(.runtimeStatus(.running))
            Task { await self.seedInitialThread(for: session) }
        }
    }

    public func newThread(for session: RuntimeSessionRecord) async {
        await emitThreadLifecycle(
            title: "New Thread \(threadHistory[session.id, default: []].count + 1)",
            session: session,
            makeBackgroundExisting: true,
            itemTitle: "Started new thread",
            itemDetail: "The runtime opened a fresh Codex thread in the same Agent Chat card."
        )
    }

    public func resumePreviousThread(for session: RuntimeSessionRecord) async {
        guard let history = threadHistory[session.id], history.count > 1 else { return }
        let target = history[history.count - 2]
        currentThread[session.id] = target
        continuations[session.id]?.yield(.threadActivated(target))
        let turn = CodexTurnRecord(threadID: target.id, index: 99)
        continuations[session.id]?.yield(.turnCreated(turn))
        continuations[session.id]?.yield(
            .itemCreated(
                CodexItemRecord(
                    turnID: turn.id,
                    kind: .summary,
                    title: "Resumed thread",
                    detail: "The runtime rebound the Agent Chat card to an earlier thread."
                )
            )
        )
    }

    public func compactCurrentThread(for session: RuntimeSessionRecord) async {
        guard var thread = currentThread[session.id] else { return }
        thread.state = .compacted
        thread.updatedAt = .now
        currentThread[session.id] = thread
        if var history = threadHistory[session.id], let index = history.firstIndex(where: { $0.id == thread.id }) {
            history[index] = thread
            threadHistory[session.id] = history
        }
        continuations[session.id]?.yield(.threadActivated(thread))
        let turn = CodexTurnRecord(threadID: thread.id, index: 100)
        continuations[session.id]?.yield(.turnCreated(turn))
        continuations[session.id]?.yield(
            .itemCreated(
                CodexItemRecord(
                    turnID: turn.id,
                    kind: .summary,
                    title: "Compacted context",
                    detail: "The current thread kept its identity and refreshed its summary state."
                )
            )
        )
    }

    private func seedInitialThread(for session: RuntimeSessionRecord) async {
        if currentThread[session.id] == nil {
            await emitThreadLifecycle(
                title: "Primary Thread",
                session: session,
                makeBackgroundExisting: false,
                itemTitle: "Runtime attached",
                itemDetail: "Codex runtime attached and started sending structured events."
            )
        }
    }

    private func emitThreadLifecycle(
        title: String,
        session: RuntimeSessionRecord,
        makeBackgroundExisting: Bool,
        itemTitle: String,
        itemDetail: String
    ) async {
        if makeBackgroundExisting, var history = threadHistory[session.id] {
            history = history.map {
                var thread = $0
                if thread.state == .active {
                    thread.state = .background
                    thread.updatedAt = .now
                }
                return thread
            }
            threadHistory[session.id] = history
        }

        let thread = CodexThreadRecord(projectID: session.projectID, title: title)
        threadHistory[session.id, default: []].append(thread)
        currentThread[session.id] = thread

        continuations[session.id]?.yield(.threadActivated(thread))
        let turn = CodexTurnRecord(threadID: thread.id, index: 1)
        continuations[session.id]?.yield(.turnCreated(turn))
        continuations[session.id]?.yield(
            .itemCreated(
                CodexItemRecord(
                    turnID: turn.id,
                    kind: .summary,
                    title: itemTitle,
                    detail: itemDetail
                )
            )
        )
    }
}

public actor FailingReconnectRuntimeService: CodexRuntimeEnvironment {
    public init() {}

    public func startSession(for project: ProjectRecord, cardID: UUID) async -> RuntimeSessionRecord {
        RuntimeSessionRecord(cardID: cardID, projectID: project.id, status: .starting)
    }

    public func reconnect(session: RuntimeSessionRecord) async -> RuntimeSessionRecord? {
        nil
    }

    public func end(session: RuntimeSessionRecord) async -> RuntimeSessionRecord {
        var ended = session
        ended.status = .ended
        return ended
    }

    public func eventStream(for session: RuntimeSessionRecord) async -> AsyncStream<CodexAppServerEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func newThread(for session: RuntimeSessionRecord) async {}
    public func resumePreviousThread(for session: RuntimeSessionRecord) async {}
    public func compactCurrentThread(for session: RuntimeSessionRecord) async {}
}
