import Foundation
import Combine

@MainActor
public final class WorkbenchStore: ObservableObject {
    @Published public private(set) var snapshot: AppSnapshot
    @Published public private(set) var chatCardStates: [UUID: ChatCardRuntimeState] = [:]

    private let persistence: PrototypePersistenceController
    private let runtimeEnvironment: any CodexRuntimeEnvironment
    private let fileWatcher: ProjectFileWatcher
    private let snapshotTracker: ProjectSnapshotTracker
    private var eventTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        persistence: PrototypePersistenceController = PrototypePersistenceController(),
        runtimeEnvironment: any CodexRuntimeEnvironment = AppServerRuntimeService(),
        fileWatcher: ProjectFileWatcher = ProjectFileWatcher(),
        snapshotTracker: ProjectSnapshotTracker = ProjectSnapshotTracker()
    ) {
        self.persistence = persistence
        self.runtimeEnvironment = runtimeEnvironment
        self.fileWatcher = fileWatcher
        self.snapshotTracker = snapshotTracker
        self.snapshot = persistence.load()
    }

    public var projects: [ProjectDocument] { snapshot.projects }
    public var runtimeSessions: [RuntimeSessionRecord] { snapshot.runtimeSessions }
    public var selectedProject: ProjectDocument? { projectDocument(id: snapshot.selectedProjectID) }
    public var selectedWorkspace: WorkspaceRecord? {
        guard let project = selectedProject else { return nil }
        return project.workspaces.first(where: { $0.id == snapshot.selectedWorkspaceID }) ?? project.workspaces.first
    }

    public func openProject(at url: URL) {
        let path = url.path
        if let existing = snapshot.projects.first(where: { $0.project.rootPath == path }) {
            snapshot.selectedProjectID = existing.project.id
            snapshot.selectedWorkspaceID = existing.lastActiveWorkspaceID ?? existing.workspaces.first?.id
            save()
            startWatchingSelectedProject()
            return
        }

        let project = ProjectRecord(name: url.lastPathComponent, rootPath: path)
        let workspace = Self.makeDefaultWorkspace(name: "Main Workspace")
        let document = ProjectDocument(
            project: project,
            workspaces: [workspace],
            lastActiveWorkspaceID: workspace.id
        )
        snapshot.projects.append(document)
        snapshot.selectedProjectID = project.id
        snapshot.selectedWorkspaceID = workspace.id
        save()
        startWatchingSelectedProject()
    }

    public func selectProject(_ projectID: UUID) {
        snapshot.selectedProjectID = projectID
        let workspaceID = projectDocument(id: projectID)?.lastActiveWorkspaceID
            ?? projectDocument(id: projectID)?.workspaces.first?.id
        snapshot.selectedWorkspaceID = workspaceID
        save()
        startWatchingSelectedProject()
    }

    public func selectWorkspace(_ workspaceID: UUID) {
        snapshot.selectedWorkspaceID = workspaceID
        mutateSelectedProject { project in
            project.lastActiveWorkspaceID = workspaceID
        }
        save()
    }

    public func createWorkspace(named name: String? = nil) {
        mutateSelectedProject { project in
            let workspace = Self.makeDefaultWorkspace(name: name ?? "Workspace \(project.workspaces.count + 1)")
            project.workspaces.append(workspace)
            project.lastActiveWorkspaceID = workspace.id
            snapshot.selectedWorkspaceID = workspace.id
        }
        save()
    }

    public func updateWorkspaceNote(_ text: String) {
        mutateSelectedWorkspace { workspace in
            workspace.note.text = text
            workspace.note.updatedAt = .now
            workspace.lastUpdated = .now
        }
        save()
    }

    public func focusCard(_ cardID: UUID) {
        mutateSelectedWorkspace { workspace in
            workspace.focusedCardID = cardID
            workspace.lastUpdated = .now
        }
        save()
    }

    public func setBinding(for cardID: UUID, binding: CardBinding) {
        mutateSelectedWorkspace { workspace in
            guard let index = workspace.cards.firstIndex(where: { $0.id == cardID }) else { return }
            workspace.cards[index].binding = binding
            workspace.lastUpdated = .now
        }
        save()
    }

    public func openDiff(fileChangeID: UUID, threadID: UUID?, artifactID: UUID) {
        guard let cardID = selectedWorkspace?.cards.first(where: { $0.kind == .diff })?.id else { return }
        setBinding(for: cardID, binding: CardBinding(threadID: threadID, fileChangeID: fileChangeID, artifactID: artifactID))
        focusCard(cardID)
    }

    public func openEditor(artifactID: UUID, threadID: UUID?) {
        guard let cardID = selectedWorkspace?.cards.first(where: { $0.kind == .editor })?.id else { return }
        setBinding(for: cardID, binding: CardBinding(threadID: threadID, artifactID: artifactID))
        focusCard(cardID)
    }

    public func startSession(for cardID: UUID) {
        guard let project = selectedProject?.project else { return }
        chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = nil
        Task {
            let session = await runtimeEnvironment.startSession(for: project, cardID: cardID)
            await MainActor.run {
                if let previous = self.session(for: cardID), previous.id != session.id {
                    eventTasks[previous.id]?.cancel()
                    eventTasks[previous.id] = nil
                    snapshot.runtimeSessions.removeAll { $0.cardID == cardID && $0.id != session.id }
                }
                upsertRuntimeSession(session)
                listenForEvents(session: session)
                save()
            }
        }
    }

    public func endSession(for cardID: UUID) {
        guard let session = session(for: cardID) else { return }
        Task {
            let ended = await runtimeEnvironment.end(session: session)
            await MainActor.run {
                upsertRuntimeSession(ended)
                eventTasks[session.id]?.cancel()
                chatCardStates[cardID, default: ChatCardRuntimeState()].isGenerating = false
                save()
            }
        }
    }

    public func updateDraft(_ text: String, for cardID: UUID) {
        chatCardStates[cardID, default: ChatCardRuntimeState()].draft = text
    }

    public func sendDraftMessage(from cardID: UUID) {
        let draft = chatCardStates[cardID]?.draft.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !draft.isEmpty else { return }
        sendMessage(draft, from: cardID)
    }

    public func sendMessage(_ text: String, from cardID: UUID) {
        guard let session = session(for: cardID) else { return }
        var state = chatCardStates[cardID, default: ChatCardRuntimeState()]
        state.messages.append(ChatMessageRecord(role: .user, text: text))
        state.draft = ""
        state.lastError = nil
        chatCardStates[cardID] = state
        Task {
            do {
                try await runtimeEnvironment.sendUserMessage(text, for: session)
            } catch {
                await MainActor.run {
                    self.chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = error.localizedDescription
                }
            }
        }
    }

    public func interruptTurn(from cardID: UUID) {
        guard let session = session(for: cardID) else { return }
        Task {
            do {
                try await runtimeEnvironment.interruptTurn(for: session)
            } catch {
                await MainActor.run {
                    self.chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = error.localizedDescription
                }
            }
        }
    }

    public func resumeThread(_ thread: CodexThreadRecord, from cardID: UUID) {
        guard let session = session(for: cardID) else { return }
        guard let remoteID = thread.remoteID else { return }
        Task {
            do {
                try await runtimeEnvironment.resumeThread(remoteID: remoteID, for: session)
            } catch {
                await MainActor.run {
                    self.chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = error.localizedDescription
                }
            }
        }
    }

    public func forkActiveThread(from cardID: UUID) {
        guard let session = session(for: cardID), let remoteID = session.activeRemoteThreadID else { return }
        Task {
            do {
                try await runtimeEnvironment.forkThread(remoteID: remoteID, for: session)
            } catch {
                await MainActor.run {
                    self.chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = error.localizedDescription
                }
            }
        }
    }

    public func rollbackActiveThread(from cardID: UUID, droppingTurns turns: Int = 1) {
        guard let session = session(for: cardID) else { return }
        Task {
            do {
                try await runtimeEnvironment.rollbackThread(for: session, droppingTurns: turns)
            } catch {
                await MainActor.run {
                    self.chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = error.localizedDescription
                }
            }
        }
    }

    public func sendShellCommand(_ command: String, from cardID: UUID) {
        guard let session = session(for: cardID) else { return }
        Task {
            do {
                try await runtimeEnvironment.sendShellCommand(command, for: session)
            } catch {
                await MainActor.run {
                    self.chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = error.localizedDescription
                }
            }
        }
    }

    public func resolveApproval(_ approval: ApprovalRequestRecord, decision: ApprovalDecision, from cardID: UUID) {
        guard let session = session(for: cardID) else { return }
        Task {
            do {
                try await runtimeEnvironment.resolveApproval(requestID: approval.requestID, decision: decision, for: session)
            } catch {
                await MainActor.run {
                    self.chatCardStates[cardID, default: ChatCardRuntimeState()].lastError = error.localizedDescription
                }
            }
        }
    }

    public func attemptRuntimeRestoration() {
        for session in snapshot.runtimeSessions where session.status == .running || session.status == .reconnectable || session.status == .disconnected {
            Task {
                let restored = await runtimeEnvironment.reconnect(session: session)
                await MainActor.run {
                    if var restored {
                        restored.status = .running
                        upsertRuntimeSession(restored)
                        listenForEvents(session: restored)
                    } else {
                        var disconnected = session
                        disconnected.status = .disconnected
                        disconnected.updatedAt = .now
                        upsertRuntimeSession(disconnected)
                    }
                    save()
                }
            }
        }
    }

    public func scanSelectedProjectForChanges() {
        guard let project = selectedProject?.project else { return }
        Task {
            let changes = (try? await snapshotTracker.scanProject(at: URL(fileURLWithPath: project.rootPath))) ?? []
            await MainActor.run {
                applyDetectedFileChanges(changes, to: project.id)
            }
        }
    }

    public func codexCard() -> CardInstance? {
        selectedWorkspace?.cards.first(where: { $0.kind == .agentChat })
    }

    public func session(for cardID: UUID) -> RuntimeSessionRecord? {
        snapshot.runtimeSessions.first(where: { $0.cardID == cardID })
    }

    public func chatState(for cardID: UUID) -> ChatCardRuntimeState {
        chatCardStates[cardID, default: ChatCardRuntimeState()]
    }

    public func activeRuntimeSession(projectID: UUID? = nil) -> RuntimeSessionRecord? {
        let effectiveProjectID = projectID ?? selectedProject?.project.id
        return snapshot.runtimeSessions
            .filter { effectiveProjectID == nil || $0.projectID == effectiveProjectID }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    public func threads(for projectID: UUID? = nil) -> [CodexThreadRecord] {
        let effectiveProjectID = projectID ?? selectedProject?.project.id
        guard let effectiveProjectID, let document = projectDocument(id: effectiveProjectID) else { return [] }
        return document.threads.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func turns(for threadID: UUID) -> [CodexTurnRecord] {
        selectedProject?.turns.filter { $0.threadID == threadID }.sorted { $0.index < $1.index } ?? []
    }

    public func items(for turnID: UUID) -> [CodexItemRecord] {
        selectedProject?.items.filter { $0.turnID == turnID }.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    public func fileChanges(for threadID: UUID?) -> [FileChangeRecord] {
        selectedProject?.fileChanges
            .filter { threadID == nil || $0.threadID == threadID }
            .sorted { $0.timestamp > $1.timestamp } ?? []
    }

    public func artifact(for id: UUID) -> ArtifactRecord? {
        selectedProject?.artifacts.first(where: { $0.id == id })
    }

    public func activeThreadID(for card: CardInstance) -> UUID? {
        if card.followsActiveThread, let session = session(for: card.id) {
            return session.activeThreadID
        }
        if card.followsActiveThread {
            return activeRuntimeSession()?.activeThreadID
        }
        return card.binding.threadID ?? session(for: card.id)?.activeThreadID ?? activeRuntimeSession()?.activeThreadID
    }

    public func currentFileChange(for card: CardInstance) -> FileChangeRecord? {
        if let fileChangeID = card.binding.fileChangeID {
            return selectedProject?.fileChanges.first(where: { $0.id == fileChangeID })
        }
        return fileChanges(for: activeThreadID(for: card)).first
    }

    public func currentArtifact(for card: CardInstance) -> ArtifactRecord? {
        if let artifactID = card.binding.artifactID {
            return artifact(for: artifactID)
        }
        if let fileChange = currentFileChange(for: card) {
            return artifact(for: fileChange.artifactID)
        }
        return nil
    }

    public func updateArtifact(_ artifact: ArtifactRecord, contents: String) throws {
        let url = URL(fileURLWithPath: artifact.path)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        scanSelectedProjectForChanges()
    }

    public static func makeDefaultWorkspace(name: String) -> WorkspaceRecord {
        let codex = CardInstance(kind: .agentChat, followsActiveThread: false)
        let graph = CardInstance(kind: .threadGraph, followsActiveThread: true)
        let change = CardInstance(kind: .changeTracking, followsActiveThread: true)
        let diff = CardInstance(kind: .diff, followsActiveThread: true)
        let editor = CardInstance(kind: .editor, followsActiveThread: false)
        let notes = CardInstance(kind: .notes, followsActiveThread: false)

        let cards = [codex, graph, change, diff, editor, notes]
        let leftColumn = WorkspaceLayoutNode.split(
            axis: .vertical,
            ratio: 0.58,
            first: .leaf(codex.id),
            second: .leaf(change.id)
        )
        let rightBottom = WorkspaceLayoutNode.split(
            axis: .horizontal,
            ratio: 0.5,
            first: .leaf(diff.id),
            second: .leaf(editor.id)
        )
        let rightColumn = WorkspaceLayoutNode.split(
            axis: .vertical,
            ratio: 0.42,
            first: .leaf(graph.id),
            second: WorkspaceLayoutNode.split(axis: .vertical, ratio: 0.66, first: rightBottom, second: .leaf(notes.id))
        )
        let root = WorkspaceLayoutNode.split(axis: .horizontal, ratio: 0.34, first: leftColumn, second: rightColumn)
        return WorkspaceRecord(
            name: name,
            cards: cards,
            layout: root,
            focusedCardID: codex.id
        )
    }

    private func listenForEvents(session: RuntimeSessionRecord) {
        eventTasks[session.id]?.cancel()
        eventTasks[session.id] = Task {
            let stream = await runtimeEnvironment.eventStream(for: session)
            for await event in stream {
                await MainActor.run {
                    handle(event, for: session)
                }
            }
        }
    }

    private func handle(_ event: CodexAppServerEvent, for runtimeSession: RuntimeSessionRecord) {
        switch event {
        case .runtimeStatus(let status):
            var updated = session(for: runtimeSession.cardID) ?? runtimeSession
            updated.status = status
            updated.updatedAt = .now
            upsertRuntimeSession(updated)
        case .runtimeError(let message):
            var state = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()]
            state.lastError = message
            state.isGenerating = false
            chatCardStates[runtimeSession.cardID] = state
        case .threadUpdated(let thread):
            mutateProject(id: thread.projectID) { project in
                if let index = project.threads.firstIndex(where: { $0.id == thread.id }) {
                    project.threads[index] = thread
                } else {
                    project.threads.append(thread)
                }
            }
            if var runtime = self.session(for: runtimeSession.cardID) {
                runtime.activeThreadID = thread.id
                runtime.activeRemoteThreadID = thread.remoteID
                runtime.updatedAt = Date.now
                upsertRuntimeSession(runtime)
            }
        case .turnUpdated(let turn):
            mutateProjectContainingThread(turn.threadID) { project in
                if let index = project.turns.firstIndex(where: { $0.id == turn.id }) {
                    project.turns[index] = turn
                } else {
                    project.turns.append(turn)
                }
            }
            chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()].activeTurnID = turn.id
            chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()].activeRemoteTurnID = turn.remoteID
            chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()].isGenerating = true
        case .turnCompleted(let turnID):
            chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()].activeTurnID = nil
            chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()].activeRemoteTurnID = nil
            chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()].isGenerating = false
            if let index = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()].toolProgress.indices.last {
                _ = index
            }
            _ = turnID
        case .itemUpdated(let item):
            mutateProjectContainingTurn(item.turnID) { project in
                if let index = project.items.firstIndex(where: { $0.id == item.id }) {
                    project.items[index] = item
                } else {
                    project.items.append(item)
                }
            }
            if item.kind == .response {
                var state = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()]
                if !state.messages.contains(where: { $0.itemID == item.id }) {
                    state.messages.append(ChatMessageRecord(role: .assistant, text: "", itemID: item.id))
                }
                if
                    !item.detail.isEmpty,
                    let index = state.messages.firstIndex(where: { $0.itemID == item.id }),
                    state.messages[index].text.isEmpty
                {
                    state.messages[index].text = item.detail
                }
                chatCardStates[runtimeSession.cardID] = state
            }
        case .assistantDelta(let itemID, _, let delta):
            var state = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()]
            if let index = state.messages.firstIndex(where: { $0.itemID == itemID }) {
                state.messages[index].text.append(delta)
            } else {
                state.messages.append(ChatMessageRecord(role: .assistant, text: delta, itemID: itemID))
            }
            state.isGenerating = true
            chatCardStates[runtimeSession.cardID] = state
        case .toolProgress(let progress):
            var state = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()]
            state.toolProgress.append(progress)
            chatCardStates[runtimeSession.cardID] = state
        case .shellOutput(let output):
            var state = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()]
            state.shellOutput.append(output)
            chatCardStates[runtimeSession.cardID] = state
        case .approvalRequested(let approval):
            var state = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()]
            state.pendingApprovals.append(approval)
            state.isGenerating = false
            chatCardStates[runtimeSession.cardID] = state
        case .approvalResolved(let requestID, _):
            var state = chatCardStates[runtimeSession.cardID, default: ChatCardRuntimeState()]
            state.pendingApprovals.removeAll { $0.requestID == requestID }
            chatCardStates[runtimeSession.cardID] = state
        case .fileChanged(let change):
            guard let projectID = selectedProject?.project.id else { break }
            applyDetectedFileChanges([change], to: projectID)
        }
        save()
    }

    private func applyDetectedFileChanges(_ changes: [DetectedFileChange], to projectID: UUID) {
        guard !changes.isEmpty else { return }
        mutateProject(id: projectID) { project in
            let activeThreadID = snapshot.runtimeSessions.first(where: { $0.projectID == projectID })?.activeThreadID
            let sourceItemID = project.items.sorted { $0.createdAt > $1.createdAt }.first?.id
            for change in changes {
                let absolutePath = URL(fileURLWithPath: project.project.rootPath).appending(path: change.relativePath).path
                let artifact = upsertArtifact(path: absolutePath, in: &project)
                let fileChange = FileChangeRecord(
                    projectID: projectID,
                    threadID: activeThreadID,
                    artifactID: artifact.id,
                    sourceItemID: sourceItemID,
                    beforeSnapshot: change.before,
                    afterSnapshot: change.after,
                    timestamp: change.timestamp,
                    isFullyAttributed: sourceItemID != nil
                )
                project.fileChanges.insert(fileChange, at: 0)
            }
        }
        save()
    }

    private func upsertArtifact(path: String, in project: inout ProjectDocument) -> ArtifactRecord {
        if let index = project.artifacts.firstIndex(where: { $0.path == path }) {
            project.artifacts[index].updatedAt = .now
            return project.artifacts[index]
        }
        let artifact = ArtifactRecord(projectID: project.project.id, path: path)
        project.artifacts.append(artifact)
        return artifact
    }

    private func startWatchingSelectedProject() {
        guard let project = selectedProject?.project else { return }
        fileWatcher.startWatching(project: project) { [weak self] changes in
            Task { @MainActor [weak self] in
                self?.applyDetectedFileChanges(changes, to: project.id)
            }
        }
    }

    private func mutateSelectedProject(_ update: (inout ProjectDocument) -> Void) {
        guard let projectID = snapshot.selectedProjectID else { return }
        mutateProject(id: projectID, update)
    }

    private func mutateProject(id: UUID, _ update: (inout ProjectDocument) -> Void) {
        guard let index = snapshot.projects.firstIndex(where: { $0.project.id == id }) else { return }
        update(&snapshot.projects[index])
        snapshot.projects[index].project.updatedAt = .now
    }

    private func mutateSelectedWorkspace(_ update: (inout WorkspaceRecord) -> Void) {
        guard let projectID = snapshot.selectedProjectID, let workspaceID = snapshot.selectedWorkspaceID else { return }
        mutateProject(id: projectID) { project in
            guard let index = project.workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
            update(&project.workspaces[index])
        }
    }

    private func mutateProjectContainingThread(_ threadID: UUID, _ update: (inout ProjectDocument) -> Void) {
        guard let index = snapshot.projects.firstIndex(where: { $0.threads.contains(where: { $0.id == threadID }) || $0.project.id == selectedProject?.project.id }) else { return }
        update(&snapshot.projects[index])
    }

    private func mutateProjectContainingTurn(_ turnID: UUID, _ update: (inout ProjectDocument) -> Void) {
        guard let index = snapshot.projects.firstIndex(where: { $0.turns.contains(where: { $0.id == turnID }) || $0.project.id == selectedProject?.project.id }) else { return }
        update(&snapshot.projects[index])
    }

    private func upsertRuntimeSession(_ session: RuntimeSessionRecord) {
        if let index = snapshot.runtimeSessions.firstIndex(where: { $0.id == session.id }) {
            snapshot.runtimeSessions[index] = session
        } else if let index = snapshot.runtimeSessions.firstIndex(where: { $0.cardID == session.cardID }) {
            snapshot.runtimeSessions[index] = session
        } else {
            snapshot.runtimeSessions.append(session)
        }
    }

    private func projectDocument(id: UUID?) -> ProjectDocument? {
        guard let id else { return nil }
        return snapshot.projects.first(where: { $0.project.id == id })
    }

    private func save() {
        persistence.save(snapshot)
    }
}
