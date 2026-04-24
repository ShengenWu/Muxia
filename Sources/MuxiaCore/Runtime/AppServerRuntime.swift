import Foundation
import CryptoKit
import os

public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value): return String(value)
        default: return nil
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        switch self {
        case .number(let value): return Int(value)
        case .string(let value): return Int(value)
        default: return nil
        }
    }
}

public enum JSONRPCID: Hashable, Sendable {
    case int(Int)
    case string(String)

    var jsonValue: JSONValue {
        switch self {
        case .int(let value): return .number(Double(value))
        case .string(let value): return .string(value)
        }
    }

    var rawString: String {
        switch self {
        case .int(let value): return String(value)
        case .string(let value): return value
        }
    }
}

struct JSONRPCWireMessage: Codable, Sendable {
    var jsonrpc: String?
    var id: JSONValue?
    var method: String?
    var params: JSONValue?
    var result: JSONValue?
    var error: JSONRPCErrorPayload?
}

struct JSONRPCErrorPayload: Codable, Sendable {
    var code: Int
    var message: String
}

enum JSONRPCStdioFraming {
    private static let headerSeparator = Data("\r\n\r\n".utf8)

    static func encode(_ message: JSONRPCWireMessage, encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        var body = try encoder.encode(message)
        body.append(0x0A)
        return body
    }

    static func decodeAvailableMessages(
        from buffer: inout Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> [JSONRPCWireMessage] {
        var messages: [JSONRPCWireMessage] = []
        while let message = try decodeNextMessage(from: &buffer, decoder: decoder) {
            messages.append(message)
        }
        return messages
    }

    private static func decodeNextMessage(
        from buffer: inout Data,
        decoder: JSONDecoder
    ) throws -> JSONRPCWireMessage? {
        if let framed = try decodeFramedMessage(from: &buffer, decoder: decoder) {
            return framed
        }
        return try decodeLineDelimitedMessage(from: &buffer, decoder: decoder)
    }

    private static func decodeFramedMessage(
        from buffer: inout Data,
        decoder: JSONDecoder
    ) throws -> JSONRPCWireMessage? {
        guard let separatorRange = buffer.range(of: headerSeparator) else {
            return nil
        }

        let headerData = buffer.subdata(in: 0..<separatorRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw RuntimeTransportError.streamDecodingFailed("Invalid UTF-8 in JSON-RPC headers")
        }

        let contentLength = try parseContentLength(from: headerText)
        let bodyStart = separatorRange.upperBound
        guard buffer.count >= bodyStart + contentLength else {
            return nil
        }

        let bodyRange = bodyStart..<(bodyStart + contentLength)
        let body = buffer.subdata(in: bodyRange)
        buffer.removeSubrange(0..<bodyRange.upperBound)
        return try decoder.decode(JSONRPCWireMessage.self, from: body)
    }

    private static func decodeLineDelimitedMessage(
        from buffer: inout Data,
        decoder: JSONDecoder
    ) throws -> JSONRPCWireMessage? {
        guard
            let newlineIndex = buffer.firstIndex(of: 0x0A),
            let firstByte = buffer.first(where: { !$0.isASCIIWhitespace })
        else {
            return nil
        }

        guard firstByte == UInt8(ascii: "{") || firstByte == UInt8(ascii: "[") else {
            return nil
        }

        let line = buffer.subdata(in: 0..<newlineIndex)
        buffer.removeSubrange(0...newlineIndex)
        let trimmed = line.drop { $0.isASCIIWhitespace }
        guard !trimmed.isEmpty else { return nil }
        return try decoder.decode(JSONRPCWireMessage.self, from: Data(trimmed))
    }

    private static func parseContentLength(from headerText: String) throws -> Int {
        for line in headerText.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "content-length",
               let value = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
            {
                return value
            }
        }
        throw RuntimeTransportError.streamDecodingFailed("Missing Content-Length header")
    }
}

public enum AppServerEnvelope: Sendable {
    case request(id: JSONRPCID, method: String, params: JSONValue?)
    case response(id: JSONRPCID, result: JSONValue?, error: String?)
    case notification(method: String, params: JSONValue?)
}

public protocol AppServerTransporting: Sendable {
    func connect() async throws -> AsyncThrowingStream<AppServerEnvelope, Error>
    func sendRequest(id: JSONRPCID, method: String, params: JSONValue?) async throws
    func sendNotification(method: String, params: JSONValue?) async throws
    func sendResponse(id: JSONRPCID, result: JSONValue?) async throws
    func disconnect() async
}

public enum AppServerExecutableResolver {
    private static let homebrewPaths = [
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex"
    ]

    private static let bundledAppPath = "/Applications/Codex.app/Contents/Resources/codex"

    public static func resolveCodexExecutable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String {
        if
            let override = environment["MUXIA_CODEX_EXECUTABLE"],
            !override.isEmpty,
            fileManager.isExecutableFile(atPath: override)
        {
            return override
        }

        for path in homebrewPaths where fileManager.isExecutableFile(atPath: path) {
            return path
        }

        if fileManager.isExecutableFile(atPath: bundledAppPath) {
            return bundledAppPath
        }

        return "/usr/bin/env"
    }

    public static func defaultArguments(for executable: String) -> [String] {
        if executable == "/usr/bin/env" {
            return ["codex", "app-server", "--listen", "stdio://"]
        }
        return ["app-server", "--listen", "stdio://"]
    }

    public static func launchEnvironment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = base
        let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existingPath = environment["PATH"] ?? ""
        let mergedPath = (searchPaths + existingPath.split(separator: ":").map(String.init))
            .reduce(into: [String]()) { paths, path in
                if !path.isEmpty, !paths.contains(path) {
                    paths.append(path)
                }
            }
            .joined(separator: ":")
        environment["PATH"] = mergedPath
        return environment
    }
}

public actor SubprocessAppServerTransport: AppServerTransporting {
    private let executable: String
    private let arguments: [String]
    private let environment: [String: String]
    private nonisolated let logger = Logger(subsystem: "com.muxia.host", category: "AppServerRuntime")
    private let maxDiagnosticLines = 24
    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var outputStream: AsyncThrowingStream<AppServerEnvelope, Error>?
    private var stderrLines: [String] = []
    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()

    public init(
        executable: String = AppServerExecutableResolver.resolveCodexExecutable(),
        arguments: [String]? = nil,
        environment: [String: String] = AppServerExecutableResolver.launchEnvironment()
    ) {
        self.executable = executable
        self.arguments = arguments ?? AppServerExecutableResolver.defaultArguments(for: executable)
        self.environment = environment
    }

    public func connect() async throws -> AsyncThrowingStream<AppServerEnvelope, Error> {
        if let outputStream {
            return outputStream
        }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            logger.info("Launching Codex App Server: \(RuntimeTransportError.commandDescription(executable: self.executable, arguments: self.arguments), privacy: .public)")
            try process.run()
        } catch {
            logger.error("Failed to launch Codex App Server: \(error.localizedDescription, privacy: .public)")
            throw RuntimeTransportError.launchFailed(executable: executable, arguments: arguments, underlying: error.localizedDescription)
        }
        self.process = process
        self.inputHandle = stdin.fileHandleForWriting
        self.outputHandle = stdout.fileHandleForReading
        self.errorHandle = stderr.fileHandleForReading
        self.stderrLines = []
        self.stdoutBuffer = Data()
        self.stderrBuffer = Data()

        let decoder = JSONDecoder()
        let stream = AsyncThrowingStream<AppServerEnvelope, Error> { continuation in
            stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                Task {
                    await self?.handleStdoutReadable(data, decoder: decoder, continuation: continuation)
                }
            }
            stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                Task {
                    await self?.handleStderrReadable(data)
                }
            }
        }

        process.terminationHandler = { [weak self] process in
            Task {
                await self?.handleTermination(status: process.terminationStatus)
            }
        }

        self.outputStream = stream
        return stream
    }

    public func sendRequest(id: JSONRPCID, method: String, params: JSONValue?) async throws {
        try send(JSONRPCWireMessage(id: id.jsonValue, method: method, params: params))
    }

    public func sendNotification(method: String, params: JSONValue?) async throws {
        try send(JSONRPCWireMessage(id: nil, method: method, params: params))
    }

    public func sendResponse(id: JSONRPCID, result: JSONValue?) async throws {
        try send(JSONRPCWireMessage(id: id.jsonValue, method: nil, params: nil, result: result, error: nil))
    }

    public func disconnect() async {
        outputHandle?.readabilityHandler = nil
        errorHandle?.readabilityHandler = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        inputHandle = nil
        outputHandle = nil
        errorHandle = nil
        outputStream = nil
        stderrLines = []
        stdoutBuffer = Data()
        stderrBuffer = Data()
    }

    private func send(_ message: JSONRPCWireMessage) throws {
        guard let inputHandle else {
            throw RuntimeTransportError.notConnected
        }

        let data = try JSONRPCStdioFraming.encode(message)
        if let method = message.method {
            logger.debug("Sending Codex App Server message method=\(method, privacy: .public) id=\(message.id?.stringValue ?? "none", privacy: .public)")
        }
        try inputHandle.write(contentsOf: data)
    }

    private func handleTermination(status: Int32) async {
        if status != 0 {
            logger.error("Codex App Server terminated with status \(status, privacy: .public). Diagnostics: \(self.stderrLines.joined(separator: "\n"), privacy: .public)")
            outputStream = nil
        } else {
            logger.info("Codex App Server terminated normally")
        }
    }

    private func appendDiagnosticLine(_ line: String) {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        logger.warning("Codex App Server stderr: \(line, privacy: .public)")
        stderrLines.append(line)
        if stderrLines.count > maxDiagnosticLines {
            stderrLines.removeFirst(stderrLines.count - maxDiagnosticLines)
        }
    }

    private func logDecodedPayload(_ payload: JSONRPCWireMessage) {
        if let method = payload.method, let id = payload.id?.stringValue {
            logger.debug("Codex App Server request method=\(method, privacy: .public) id=\(id, privacy: .public)")
        } else if let method = payload.method {
            logger.debug("Codex App Server notification method=\(method, privacy: .public)")
        } else if let id = payload.id?.stringValue {
            logger.debug("Codex App Server response id=\(id, privacy: .public)")
        } else {
            logger.debug("Codex App Server payload without method or id")
        }
    }

    private func handleStdoutReadable(
        _ data: Data,
        decoder: JSONDecoder,
        continuation: AsyncThrowingStream<AppServerEnvelope, Error>.Continuation
    ) async {
        guard !data.isEmpty else {
            logger.info("Codex App Server stdout stream closed")
            outputHandle?.readabilityHandler = nil
            if let error = terminationErrorIfNeeded() {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
            return
        }

        stdoutBuffer.append(data)
        do {
            let payloads = try JSONRPCStdioFraming.decodeAvailableMessages(from: &stdoutBuffer, decoder: decoder)
            for payload in payloads {
                logDecodedPayload(payload)
                if let idValue = payload.id.flatMap(Self.makeID), let method = payload.method {
                    continuation.yield(.request(id: idValue, method: method, params: payload.params))
                } else if let idValue = payload.id.flatMap(Self.makeID) {
                    continuation.yield(.response(id: idValue, result: payload.result, error: payload.error?.message))
                } else if let method = payload.method {
                    continuation.yield(.notification(method: method, params: payload.params))
                }
            }
        } catch {
            continuation.finish(throwing: RuntimeTransportError.streamDecodingFailed(error.localizedDescription))
        }
    }

    private func handleStderrReadable(_ data: Data) async {
        guard !data.isEmpty else {
            errorHandle?.readabilityHandler = nil
            if !stderrBuffer.isEmpty {
                flushStderrBuffer()
            }
            return
        }

        stderrBuffer.append(data)
        flushStderrBuffer()
    }

    private func flushStderrBuffer() {
        while let newlineIndex = stderrBuffer.firstIndex(of: 0x0A) {
            let lineData = stderrBuffer.subdata(in: 0..<newlineIndex)
            stderrBuffer.removeSubrange(0...newlineIndex)
            let line = String(decoding: lineData, as: UTF8.self)
                .trimmingCharacters(in: .newlines)
            appendDiagnosticLine(line)
        }
    }

    private func terminationErrorIfNeeded() -> RuntimeTransportError? {
        guard let process, !process.isRunning, process.terminationStatus != 0 else { return nil }
        return .abnormalTermination(
            executable: executable,
            arguments: arguments,
            status: process.terminationStatus,
            reason: process.terminationReason.description,
            diagnostics: stderrLines
        )
    }

    private static func makeID(from value: JSONValue) -> JSONRPCID? {
        switch value {
        case .string(let string):
            return .string(string)
        case .number(let number):
            return .int(Int(number))
        default:
            return nil
        }
    }
}

private extension UInt8 {
    var isASCIIWhitespace: Bool {
        self == 0x20 || self == 0x09 || self == 0x0A || self == 0x0D
    }
}

public enum RuntimeTransportError: LocalizedError {
    case notConnected
    case launchFailed(executable: String, arguments: [String], underlying: String)
    case abnormalTermination(executable: String, arguments: [String], status: Int32, reason: String, diagnostics: [String])
    case streamClosed
    case streamDecodingFailed(String)
    case handshakeFailed(String?)
    case requestTimedOut(method: String, seconds: Double)
    case missingThread
    case missingTurn
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Codex App Server transport is not connected."
        case .launchFailed(let executable, let arguments, let underlying):
            return "Failed to launch Codex App Server: \(Self.commandDescription(executable: executable, arguments: arguments)). \(underlying)"
        case .abnormalTermination(let executable, let arguments, let status, let reason, let diagnostics):
            var message = "Codex App Server exited before it was ready: \(Self.commandDescription(executable: executable, arguments: arguments)) terminated with status \(status) (\(reason))."
            if !diagnostics.isEmpty {
                message += "\n" + diagnostics.joined(separator: "\n")
            }
            return message
        case .streamClosed:
            return "Codex App Server stream closed before startup completed."
        case .streamDecodingFailed(let message):
            return "Codex App Server stream decoding failed: \(message)"
        case .handshakeFailed(let message):
            if let message, !message.isEmpty {
                return "Codex App Server initialize handshake failed: \(message)"
            }
            return "Codex App Server initialize handshake failed."
        case .requestTimedOut(let method, let seconds):
            return "Codex App Server request timed out after \(seconds)s: \(method)"
        case .missingThread:
            return "No active thread is bound to the chat card."
        case .missingTurn:
            return "No active turn is available for this action."
        case .requestFailed(let message):
            return message
        }
    }

    static func commandDescription(executable: String, arguments: [String]) -> String {
        ([executable] + arguments).joined(separator: " ")
    }
}

private extension Process.TerminationReason {
    var description: String {
        switch self {
        case .exit:
            return "exit"
        case .uncaughtSignal:
            return "signal"
        @unknown default:
            return "unknown"
        }
    }
}

private struct AppServerSessionState: Sendable {
    var project: ProjectRecord
    var transport: any AppServerTransporting
    var handshakeComplete = false
    var activeRemoteThreadID: String?
    var activeRemoteTurnID: String?
    var activeTurnLocalID: UUID?
    var notificationTask: Task<Void, Never>?
    var requestCounter = 0
    var pendingResponses: [JSONRPCID: CheckedContinuation<JSONValue?, Error>] = [:]
    var pendingApprovalRequests: [String: JSONRPCID] = [:]
    var terminalFailureEmitted = false
}

public actor AppServerRuntimeService: CodexRuntimeEnvironment {
    public typealias TransportFactory = @Sendable () -> any AppServerTransporting

    private let transportFactory: TransportFactory
    private nonisolated let logger = Logger(subsystem: "com.muxia.host", category: "AppServerRuntime")
    private var sessions: [UUID: AppServerSessionState] = [:]
    private var continuations: [UUID: AsyncStream<CodexAppServerEvent>.Continuation] = [:]

    public init(transportFactory: @escaping TransportFactory = { SubprocessAppServerTransport() }) {
        self.transportFactory = transportFactory
    }

    public func startSession(for project: ProjectRecord, cardID: UUID) async -> RuntimeSessionRecord {
        let session = RuntimeSessionRecord(cardID: cardID, projectID: project.id, status: .starting)
        sessions[session.id] = AppServerSessionState(project: project, transport: transportFactory())
        return session
    }

    public func reconnect(session: RuntimeSessionRecord) async -> RuntimeSessionRecord? {
        guard let existing = sessions[session.id] else {
            return nil
        }
        var restored = session
        restored.status = .starting
        restored.updatedAt = .now
        sessions[session.id] = existing
        return restored
    }

    public func end(session: RuntimeSessionRecord) async -> RuntimeSessionRecord {
        await sessions[session.id]?.transport.disconnect()
        sessions[session.id]?.notificationTask?.cancel()
        sessions[session.id] = nil
        continuations[session.id]?.yield(.runtimeStatus(.ended))
        continuations[session.id]?.finish()
        continuations[session.id] = nil
        var ended = session
        ended.status = .ended
        ended.updatedAt = .now
        return ended
    }

    public func eventStream(for session: RuntimeSessionRecord) async -> AsyncStream<CodexAppServerEvent> {
        AsyncStream { continuation in
            continuations[session.id] = continuation
            Task { await self.bootstrapSession(session.id) }
        }
    }

    public func sendUserMessage(_ text: String, for session: RuntimeSessionRecord) async throws {
        try await ensureHandshake(for: session.id)
        let threadID = try await ensureThread(for: session.id)

        let input: JSONValue = .array([
            .object([
                "type": .string("text"),
                "text": .string(text),
                "text_elements": .array([])
            ])
        ])

        if let activeTurnID = sessions[session.id]?.activeRemoteTurnID {
            _ = try await request(
                sessionID: session.id,
                method: "turn/steer",
                params: .object([
                    "threadId": .string(threadID),
                    "expectedTurnId": .string(activeTurnID),
                    "input": input
                ])
            )
        } else {
            let result = try await request(
                sessionID: session.id,
                method: "turn/start",
                params: .object([
                    "threadId": .string(threadID),
                    "input": input
                ])
            )
            if let turnObject = result?.objectValue?["turn"]?.objectValue {
                let turn = makeTurn(from: turnObject, threadID: stableUUID(from: threadID))
                sessions[session.id]?.activeRemoteTurnID = turn.remoteID
                sessions[session.id]?.activeTurnLocalID = turn.id
                continuations[session.id]?.yield(.turnUpdated(turn))
            }
        }
    }

    public func interruptTurn(for session: RuntimeSessionRecord) async throws {
        try await ensureHandshake(for: session.id)
        guard let threadID = sessions[session.id]?.activeRemoteThreadID else { throw RuntimeTransportError.missingThread }
        guard let turnID = sessions[session.id]?.activeRemoteTurnID else { throw RuntimeTransportError.missingTurn }
        _ = try await request(
            sessionID: session.id,
            method: "turn/interrupt",
            params: .object([
                "threadId": .string(threadID),
                "turnId": .string(turnID)
            ])
        )
        if let localTurnID = sessions[session.id]?.activeTurnLocalID {
            continuations[session.id]?.yield(.turnCompleted(localTurnID))
        }
        sessions[session.id]?.activeRemoteTurnID = nil
        sessions[session.id]?.activeTurnLocalID = nil
    }

    public func resumeThread(remoteID: String, for session: RuntimeSessionRecord) async throws {
        try await ensureHandshake(for: session.id)
        let result = try await request(
            sessionID: session.id,
            method: "thread/resume",
            params: .object(["threadId": .string(remoteID)])
        )
        if let threadObject = result?.objectValue?["thread"]?.objectValue {
            let thread = makeThread(from: threadObject, projectID: session.projectID)
            sessions[session.id]?.activeRemoteThreadID = thread.remoteID
            continuations[session.id]?.yield(.threadUpdated(thread))
        }
    }

    public func forkThread(remoteID: String, for session: RuntimeSessionRecord) async throws {
        try await ensureHandshake(for: session.id)
        let result = try await request(
            sessionID: session.id,
            method: "thread/fork",
            params: .object([
                "threadId": .string(remoteID),
                "ephemeral": .bool(false)
            ])
        )
        if let threadObject = result?.objectValue?["thread"]?.objectValue {
            let thread = makeThread(from: threadObject, projectID: session.projectID)
            sessions[session.id]?.activeRemoteThreadID = thread.remoteID
            continuations[session.id]?.yield(.threadUpdated(thread))
        }
    }

    public func rollbackThread(for session: RuntimeSessionRecord, droppingTurns turns: Int) async throws {
        try await ensureHandshake(for: session.id)
        guard let threadID = sessions[session.id]?.activeRemoteThreadID else { throw RuntimeTransportError.missingThread }
        let result = try await request(
            sessionID: session.id,
            method: "thread/rollback",
            params: .object([
                "threadId": .string(threadID),
                "numTurns": .number(Double(turns))
            ])
        )
        if let threadObject = result?.objectValue?["thread"]?.objectValue {
            let thread = makeThread(from: threadObject, projectID: session.projectID)
            sessions[session.id]?.activeRemoteThreadID = thread.remoteID
            continuations[session.id]?.yield(.threadUpdated(thread))
        }
    }

    public func sendShellCommand(_ command: String, for session: RuntimeSessionRecord) async throws {
        try await ensureHandshake(for: session.id)
        guard let threadID = sessions[session.id]?.activeRemoteThreadID else { throw RuntimeTransportError.missingThread }
        _ = try await request(
            sessionID: session.id,
            method: "thread/shellCommand",
            params: .object([
                "threadId": .string(threadID),
                "command": .string(command)
            ])
        )
        continuations[session.id]?.yield(.toolProgress(ToolProgressRecord(label: command, status: "running")))
    }

    public func resolveApproval(requestID: String, decision: ApprovalDecision, for session: RuntimeSessionRecord) async throws {
        guard let rpcID = sessions[session.id]?.pendingApprovalRequests[requestID] else { return }
        let decisionValue = decision == .approve ? "approved" : "denied"
        try await sessions[session.id]?.transport.sendResponse(
            id: rpcID,
            result: .object(["decision": .string(decisionValue)])
        )
        sessions[session.id]?.pendingApprovalRequests.removeValue(forKey: requestID)
        continuations[session.id]?.yield(.approvalResolved(requestID: requestID, decision: decision))
    }

    private func bootstrapSession(_ sessionID: UUID) async {
        guard var state = sessions[sessionID] else { return }

        do {
            let stream = try await state.transport.connect()
            state.notificationTask?.cancel()
            state.notificationTask = Task {
                do {
                    for try await envelope in stream {
                        await self.handle(envelope, sessionID: sessionID)
                    }
                    await self.handleStreamClosed(for: sessionID)
                } catch {
                    await self.handleStreamFailure(error, for: sessionID)
                }
            }
            sessions[sessionID] = state

            logger.info("Starting Codex App Server initialize handshake")
            _ = try await request(
                sessionID: sessionID,
                method: "initialize",
                params: .object([
                    "clientInfo": .object([
                        "name": .string("Muxia"),
                        "version": .string("0.1.0")
                    ]),
                    "capabilities": .object([
                        "experimentalApi": .bool(true)
                    ])
                ]),
                timeoutSeconds: 8
            )
            logger.info("Codex App Server initialize handshake completed")
            try await sessions[sessionID]?.transport.sendNotification(method: "initialized", params: nil)
            logger.info("Codex App Server initialized notification sent")
            sessions[sessionID]?.handshakeComplete = true
            continuations[sessionID]?.yield(.runtimeStatus(.running))
        } catch {
            await emitError(error.localizedDescription, for: sessionID)
        }
    }

    private func handle(_ envelope: AppServerEnvelope, sessionID: UUID) async {
        switch envelope {
        case .response(let id, let result, let error):
            if let continuation = sessions[sessionID]?.pendingResponses.removeValue(forKey: id) {
                if let error {
                    continuation.resume(throwing: RuntimeTransportError.requestFailed(error))
                } else {
                    continuation.resume(returning: result)
                }
            }
        case .notification(let method, let params):
            await handleNotification(method: method, params: params, sessionID: sessionID)
        case .request(let id, let method, let params):
            await handleServerRequest(id: id, method: method, params: params, sessionID: sessionID)
        }
    }

    private func handleNotification(method: String, params: JSONValue?, sessionID: UUID) async {
        if let params {
            logger.debug("Codex App Server notification params=\(self.jsonLogString(for: params), privacy: .public)")
        }
        guard let paramsObject = params?.objectValue else { return }
        switch method {
        case "thread/started":
            if let threadObject = paramsObject["thread"]?.objectValue, let projectID = sessions[sessionID]?.project.id {
                let thread = makeThread(from: threadObject, projectID: projectID)
                sessions[sessionID]?.activeRemoteThreadID = thread.remoteID
                continuations[sessionID]?.yield(.threadUpdated(thread))
            }
        case "turn/started":
            if
                let threadRemoteID = paramsObject["threadId"]?.stringValue,
                let turnObject = paramsObject["turn"]?.objectValue
            {
                let turn = makeTurn(from: turnObject, threadID: stableUUID(from: threadRemoteID))
                sessions[sessionID]?.activeRemoteTurnID = turn.remoteID
                sessions[sessionID]?.activeTurnLocalID = turn.id
                continuations[sessionID]?.yield(.turnUpdated(turn))
            }
        case "turn/completed":
            if let localTurnID = sessions[sessionID]?.activeTurnLocalID {
                continuations[sessionID]?.yield(.turnCompleted(localTurnID))
            }
            sessions[sessionID]?.activeRemoteTurnID = nil
            sessions[sessionID]?.activeTurnLocalID = nil
        case "item/started", "item/completed":
            if
                let turnRemoteID = paramsObject["turnId"]?.stringValue,
                let itemObject = paramsObject["item"]?.objectValue
            {
                let item = makeItem(from: itemObject, turnID: stableUUID(from: turnRemoteID))
                continuations[sessionID]?.yield(.itemUpdated(item))
                if method == "item/completed", item.kind == .response {
                    if sessions[sessionID]?.activeTurnLocalID == stableUUID(from: turnRemoteID) {
                        continuations[sessionID]?.yield(.turnCompleted(stableUUID(from: turnRemoteID)))
                        sessions[sessionID]?.activeRemoteTurnID = nil
                        sessions[sessionID]?.activeTurnLocalID = nil
                    }
                }
            }
        case "item/agentMessage/delta":
            if
                let itemRemoteID = paramsObject["itemId"]?.stringValue,
                let turnRemoteID = paramsObject["turnId"]?.stringValue,
                let delta = paramsObject["delta"]?.stringValue
            {
                continuations[sessionID]?.yield(
                    .assistantDelta(
                        itemID: stableUUID(from: itemRemoteID),
                        turnID: stableUUID(from: turnRemoteID),
                        delta: delta
                    )
                )
            }
        case "item/mcpToolCall/progress":
            let label = paramsObject["itemId"]?.stringValue ?? "tool"
            continuations[sessionID]?.yield(.toolProgress(ToolProgressRecord(label: label, status: "running")))
        case "item/commandExecution/outputDelta":
            if
                let itemRemoteID = paramsObject["itemId"]?.stringValue,
                let deltaBase64 = paramsObject["deltaBase64"]?.stringValue,
                let data = Data(base64Encoded: deltaBase64),
                let text = String(data: data, encoding: .utf8)
            {
                continuations[sessionID]?.yield(.shellOutput(ShellOutputRecord(itemID: stableUUID(from: itemRemoteID), stream: "stdout", text: text)))
            }
        case "item/fileChange/outputDelta":
            if
                let itemRemoteID = paramsObject["itemId"]?.stringValue,
                let delta = paramsObject["delta"]?.stringValue
            {
                continuations[sessionID]?.yield(.toolProgress(ToolProgressRecord(itemID: stableUUID(from: itemRemoteID), label: "fileChange", status: delta)))
            }
        case "fs/changed":
            if let paths = paramsObject["paths"]?.arrayValue {
                for path in paths.compactMap(\.stringValue) {
                    continuations[sessionID]?.yield(.fileChanged(DetectedFileChange(relativePath: path, before: nil, after: nil)))
                }
            }
        default:
            break
        }
    }

    private func handleServerRequest(id: JSONRPCID, method: String, params: JSONValue?, sessionID: UUID) async {
        guard let paramsObject = params?.objectValue else { return }
        let approvalKind: ApprovalKind
        switch method {
        case "item/commandExecution/requestApproval":
            approvalKind = .command
        case "item/fileChange/requestApproval":
            approvalKind = .fileChange
        case "item/permissions/requestApproval":
            approvalKind = .permissions
        default:
            continuations[sessionID]?.yield(.runtimeError("Unhandled server request: \(method)"))
            return
        }

        let requestID = id.rawString
        sessions[sessionID]?.pendingApprovalRequests[requestID] = id
        let itemID = paramsObject["itemId"]?.stringValue.map(stableUUID(from:))
        let message = paramsObject["command"]?.stringValue
            ?? paramsObject["justification"]?.stringValue
            ?? paramsObject["reason"]?.stringValue
            ?? "Approval required by Codex App Server."

        let approval = ApprovalRequestRecord(
            requestID: requestID,
            itemID: itemID,
            kind: approvalKind,
            title: approvalKindTitle(approvalKind),
            message: message
        )
        continuations[sessionID]?.yield(.approvalRequested(approval))
    }

    private func handleStreamClosed(for sessionID: UUID) async {
        failPendingResponses(for: sessionID, with: RuntimeTransportError.streamClosed)
        continuations[sessionID]?.yield(.runtimeStatus(.disconnected))
    }

    private func handleStreamFailure(_ error: Error, for sessionID: UUID) async {
        failPendingResponses(for: sessionID, with: error)
        await emitError(error.localizedDescription, for: sessionID)
    }

    private func emitError(_ message: String, for sessionID: UUID) async {
        guard sessions[sessionID]?.terminalFailureEmitted != true else { return }
        sessions[sessionID]?.terminalFailureEmitted = true
        continuations[sessionID]?.yield(.runtimeError(message))
        continuations[sessionID]?.yield(.runtimeStatus(.disconnected))
    }

    private func failPendingResponses(for sessionID: UUID, with error: Error) {
        let pending = sessions[sessionID]?.pendingResponses ?? [:]
        sessions[sessionID]?.pendingResponses.removeAll()
        for continuation in pending.values {
            continuation.resume(throwing: error)
        }
    }

    private func request(
        sessionID: UUID,
        method: String,
        params: JSONValue?,
        timeoutSeconds: Double? = nil
    ) async throws -> JSONValue? {
        guard var state = sessions[sessionID] else {
            throw RuntimeTransportError.notConnected
        }

        let requestID = JSONRPCID.int(state.requestCounter + 1)
        state.requestCounter += 1
        sessions[sessionID] = state

        return try await withCheckedThrowingContinuation { continuation in
            sessions[sessionID]?.pendingResponses[requestID] = continuation
            Task {
                do {
                    try await self.sessions[sessionID]?.transport.sendRequest(id: requestID, method: method, params: params)
                } catch {
                    let continuation = self.sessions[sessionID]?.pendingResponses.removeValue(forKey: requestID)
                    continuation?.resume(throwing: error)
                }
            }
            if let timeoutSeconds {
                Task {
                    let nanoseconds = UInt64(timeoutSeconds * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanoseconds)
                    self.timeoutPendingResponse(
                        requestID,
                        sessionID: sessionID,
                        method: method,
                        seconds: timeoutSeconds
                    )
                }
            }
        }
    }

    private func timeoutPendingResponse(
        _ requestID: JSONRPCID,
        sessionID: UUID,
        method: String,
        seconds: Double
    ) {
        guard let continuation = sessions[sessionID]?.pendingResponses.removeValue(forKey: requestID) else { return }
        continuation.resume(throwing: RuntimeTransportError.requestTimedOut(method: method, seconds: seconds))
    }

    private func ensureHandshake(for sessionID: UUID) async throws {
        if sessions[sessionID]?.handshakeComplete == true { return }
        await bootstrapSession(sessionID)
        if sessions[sessionID]?.handshakeComplete != true {
            throw RuntimeTransportError.handshakeFailed(nil)
        }
    }

    private func ensureThread(for sessionID: UUID) async throws -> String {
        if let remoteID = sessions[sessionID]?.activeRemoteThreadID {
            return remoteID
        }

        guard let project = sessions[sessionID]?.project else {
            throw RuntimeTransportError.missingThread
        }

        let result = try await request(
            sessionID: sessionID,
            method: "thread/start",
            params: .object([
                "cwd": .string(project.rootPath),
                "ephemeral": .bool(false),
                "sessionStartSource": .string("startup")
            ])
        )

        if let threadObject = result?.objectValue?["thread"]?.objectValue {
            let thread = makeThread(from: threadObject, projectID: project.id)
            sessions[sessionID]?.activeRemoteThreadID = thread.remoteID
            continuations[sessionID]?.yield(.threadUpdated(thread))
            if let remoteID = thread.remoteID {
                return remoteID
            }
        }

        throw RuntimeTransportError.missingThread
    }

    private func makeThread(from object: [String: JSONValue], projectID: UUID) -> CodexThreadRecord {
        let remoteID = object["id"]?.stringValue ?? UUID().uuidString
        let title = object["title"]?.stringValue
            ?? object["summary"]?.stringValue
            ?? "Thread"
        let state = parseThreadState(object["status"]?.stringValue)
        let summary = object["summary"]?.stringValue
        return CodexThreadRecord(
            id: stableUUID(from: remoteID),
            remoteID: remoteID,
            projectID: projectID,
            title: title,
            state: state,
            summary: summary
        )
    }

    private func makeTurn(from object: [String: JSONValue], threadID: UUID) -> CodexTurnRecord {
        let remoteID = object["id"]?.stringValue ?? UUID().uuidString
        let index = object["sequenceNumber"]?.intValue
            ?? object["index"]?.intValue
            ?? object["turnNumber"]?.intValue
            ?? 1
        return CodexTurnRecord(
            id: stableUUID(from: remoteID),
            remoteID: remoteID,
            threadID: threadID,
            index: index
        )
    }

    private func makeItem(from object: [String: JSONValue], turnID: UUID) -> CodexItemRecord {
        let remoteID = object["id"]?.stringValue ?? UUID().uuidString
        let type = object["type"]?.stringValue ?? "summary"
        let kind = parseItemKind(type)
        let title = object["title"]?.stringValue ?? type
        let detail = object["text"]?.stringValue
            ?? object["summary"]?.stringValue
            ?? object["command"]?.stringValue
            ?? object["path"]?.stringValue
            ?? ""
        return CodexItemRecord(
            id: stableUUID(from: remoteID),
            remoteID: remoteID,
            turnID: turnID,
            kind: kind,
            title: title,
            detail: detail
        )
    }

    private func parseThreadState(_ value: String?) -> ThreadState {
        switch value?.lowercased() {
        case "active":
            return .active
        case "archived":
            return .archived
        case "compacted":
            return .compacted
        default:
            return .active
        }
    }

    private func parseItemKind(_ value: String) -> ItemKind {
        switch value.lowercased() {
        case "agentmessage", "response":
            return .response
        case "commandexecution":
            return .command
        case "filechange":
            return .fileEdit
        case "toolcall", "mcptoolcall":
            return .tool
        case "approval":
            return .approval
        case "error":
            return .error
        case "usermessage", "prompt":
            return .prompt
        default:
            return .summary
        }
    }

    private func approvalKindTitle(_ kind: ApprovalKind) -> String {
        switch kind {
        case .command: return "Command Approval"
        case .fileChange: return "File Change Approval"
        case .permissions: return "Permission Approval"
        }
    }

    private func jsonLogString(for value: JSONValue) -> String {
        guard
            let data = try? JSONEncoder().encode(value),
            let text = String(data: data, encoding: .utf8)
        else {
            return "<unencodable>"
        }
        return text
    }
}

private func stableUUID(from value: String) -> UUID {
    let digest = Array(Insecure.MD5.hash(data: Data(value.utf8)))
    let bytes: [UInt8] = Array(digest.prefix(16))
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}
