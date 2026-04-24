import Foundation

public enum CodexAppServerEvent: Sendable {
    case runtimeStatus(RuntimeStatus)
    case runtimeError(String)
    case threadUpdated(CodexThreadRecord)
    case turnUpdated(CodexTurnRecord)
    case turnCompleted(UUID)
    case itemUpdated(CodexItemRecord)
    case assistantDelta(itemID: UUID, turnID: UUID, delta: String)
    case toolProgress(ToolProgressRecord)
    case shellOutput(ShellOutputRecord)
    case approvalRequested(ApprovalRequestRecord)
    case approvalResolved(requestID: String, decision: ApprovalDecision)
    case fileChanged(DetectedFileChange)
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
    func sendUserMessage(_ text: String, for session: RuntimeSessionRecord) async throws
    func interruptTurn(for session: RuntimeSessionRecord) async throws
    func resumeThread(remoteID: String, for session: RuntimeSessionRecord) async throws
    func forkThread(remoteID: String, for session: RuntimeSessionRecord) async throws
    func rollbackThread(for session: RuntimeSessionRecord, droppingTurns turns: Int) async throws
    func sendShellCommand(_ command: String, for session: RuntimeSessionRecord) async throws
    func resolveApproval(requestID: String, decision: ApprovalDecision, for session: RuntimeSessionRecord) async throws
}

public typealias CodexRuntimeEnvironment = CodexRuntimeClient & CodexAppServerClient & CodexRuntimeControlling

private struct MockSessionState: Sendable {
    var projectID: UUID
    var currentThread: CodexThreadRecord?
    var currentTurn: CodexTurnRecord?
    var threadHistory: [CodexThreadRecord] = []
    var nextTurnIndex: Int = 1
}

public actor MockCodexRuntimeService: CodexRuntimeEnvironment {
    private var continuations: [UUID: AsyncStream<CodexAppServerEvent>.Continuation] = [:]
    private var sessions: [UUID: MockSessionState] = [:]

    public init() {}

    public func startSession(for project: ProjectRecord, cardID: UUID) async -> RuntimeSessionRecord {
        let session = RuntimeSessionRecord(cardID: cardID, projectID: project.id, status: .starting)
        sessions[session.id] = MockSessionState(projectID: project.id)
        return session
    }

    public func reconnect(session: RuntimeSessionRecord) async -> RuntimeSessionRecord? {
        guard sessions[session.id] != nil else { return nil }
        var restored = session
        restored.status = .starting
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
        }
    }

    public func sendUserMessage(_ text: String, for session: RuntimeSessionRecord) async throws {
        guard var state = sessions[session.id] else { return }

        if state.currentThread == nil {
            let thread = makeThread(projectID: state.projectID, title: "Primary Thread")
            state.currentThread = thread
            state.threadHistory.append(thread)
            continuations[session.id]?.yield(.threadUpdated(thread))
        }

        guard let thread = state.currentThread else { return }

        let turn = CodexTurnRecord(
            remoteID: "mock-turn-\(session.id.uuidString)-\(state.nextTurnIndex)",
            threadID: thread.id,
            index: state.nextTurnIndex
        )
        state.nextTurnIndex += 1
        state.currentTurn = turn
        continuations[session.id]?.yield(.turnUpdated(turn))

        let prompt = CodexItemRecord(
            remoteID: "mock-item-prompt-\(turn.index)",
            turnID: turn.id,
            kind: .prompt,
            title: "User Prompt",
            detail: text
        )
        continuations[session.id]?.yield(.itemUpdated(prompt))

        if text.localizedCaseInsensitiveContains("approval") {
            let approval = ApprovalRequestRecord(
                requestID: "mock-approval-\(turn.index)",
                itemID: prompt.id,
                kind: .command,
                title: "Mock command approval",
                message: "Approve mock command execution triggered by: \(text)"
            )
            continuations[session.id]?.yield(.approvalRequested(approval))
        } else if text.localizedCaseInsensitiveContains("hold") {
            let item = CodexItemRecord(
                remoteID: "mock-item-response-\(turn.index)",
                turnID: turn.id,
                kind: .response,
                title: "Assistant",
                detail: "Working..."
            )
            continuations[session.id]?.yield(.itemUpdated(item))
            continuations[session.id]?.yield(.assistantDelta(itemID: item.id, turnID: turn.id, delta: "Working..."))
        } else {
            try await emitMockAssistantResponse(text: text, turn: turn, sessionID: session.id)
        }

        sessions[session.id] = state
    }

    public func interruptTurn(for session: RuntimeSessionRecord) async throws {
        guard let turn = sessions[session.id]?.currentTurn else { return }
        continuations[session.id]?.yield(.turnCompleted(turn.id))
        sessions[session.id]?.currentTurn = nil
    }

    public func resumeThread(remoteID: String, for session: RuntimeSessionRecord) async throws {
        guard let thread = sessions[session.id]?.threadHistory.first(where: { $0.remoteID == remoteID }) else { return }
        sessions[session.id]?.currentThread = thread
        sessions[session.id]?.currentTurn = nil
        continuations[session.id]?.yield(.threadUpdated(thread))
    }

    public func forkThread(remoteID: String, for session: RuntimeSessionRecord) async throws {
        guard let current = sessions[session.id]?.threadHistory.first(where: { $0.remoteID == remoteID }) else { return }
        guard var state = sessions[session.id] else { return }
        let fork = makeThread(projectID: current.projectID, title: "\(current.title) Fork")
        state.currentThread = fork
        state.currentTurn = nil
        state.threadHistory = state.threadHistory.map { thread in
            var thread = thread
            if thread.id == current.id {
                thread.state = .background
            }
            return thread
        }
        state.threadHistory.append(fork)
        sessions[session.id] = state
        continuations[session.id]?.yield(.threadUpdated(fork))
    }

    public func rollbackThread(for session: RuntimeSessionRecord, droppingTurns turns: Int) async throws {
        guard var state = sessions[session.id], var thread = state.currentThread else { return }
        thread.state = .compacted
        thread.summary = "Rolled back \(turns) turn(s) in mock runtime."
        state.currentThread = thread
        sessions[session.id] = state
        continuations[session.id]?.yield(.threadUpdated(thread))
    }

    public func sendShellCommand(_ command: String, for session: RuntimeSessionRecord) async throws {
        let output = ShellOutputRecord(stream: "stdout", text: "$ \(command)\nmock shell output")
        continuations[session.id]?.yield(.shellOutput(output))
        continuations[session.id]?.yield(.toolProgress(ToolProgressRecord(label: command, status: "completed")))
    }

    public func resolveApproval(requestID: String, decision: ApprovalDecision, for session: RuntimeSessionRecord) async throws {
        continuations[session.id]?.yield(.approvalResolved(requestID: requestID, decision: decision))
        guard decision == .approve, let currentTurn = sessions[session.id]?.currentTurn else { return }
        try await emitMockAssistantResponse(text: "approval granted", turn: currentTurn, sessionID: session.id)
    }

    private func emitMockAssistantResponse(text: String, turn: CodexTurnRecord, sessionID: UUID) async throws {
        let response = "Mock response to: \(text)"
        let item = CodexItemRecord(
            remoteID: "mock-item-response-\(turn.index)",
            turnID: turn.id,
            kind: .response,
            title: "Assistant",
            detail: response
        )
        continuations[sessionID]?.yield(.itemUpdated(item))
        continuations[sessionID]?.yield(.assistantDelta(itemID: item.id, turnID: turn.id, delta: response))
        continuations[sessionID]?.yield(.turnCompleted(turn.id))
        sessions[sessionID]?.currentTurn = nil
    }

    private func makeThread(projectID: UUID, title: String) -> CodexThreadRecord {
        let remoteID = "mock-thread-\(UUID().uuidString)"
        return CodexThreadRecord(id: UUID(), remoteID: remoteID, projectID: projectID, title: title)
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

    public func sendUserMessage(_ text: String, for session: RuntimeSessionRecord) async throws {}
    public func interruptTurn(for session: RuntimeSessionRecord) async throws {}
    public func resumeThread(remoteID: String, for session: RuntimeSessionRecord) async throws {}
    public func forkThread(remoteID: String, for session: RuntimeSessionRecord) async throws {}
    public func rollbackThread(for session: RuntimeSessionRecord, droppingTurns turns: Int) async throws {}
    public func sendShellCommand(_ command: String, for session: RuntimeSessionRecord) async throws {}
    public func resolveApproval(requestID: String, decision: ApprovalDecision, for session: RuntimeSessionRecord) async throws {}
}
