import SwiftUI
import AppKit

public struct WorkbenchRootView: View {
    @ObservedObject var store: WorkbenchStore

    public init(store: WorkbenchStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            if let workspace = store.selectedWorkspace {
                WorkspaceCanvasView(store: store, workspace: workspace)
                    .background(Color(red: 0.07, green: 0.08, blue: 0.09))
            } else {
                ContentUnavailableView("Open A Project", systemImage: "folder.badge.plus", description: Text("Muxia v0 starts from a Project and seeds a default Workspace shell."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
    }
}

private struct SidebarView: View {
    @ObservedObject var store: WorkbenchStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Muxia")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Spacer()
                Button("Open") {
                    openProjectPanel()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal)
            .padding(.top)

            List(selection: Binding(
                get: { store.snapshot.selectedProjectID.map { "\($0.uuidString)" } },
                set: { value in
                    guard let value, let id = UUID(uuidString: value) else { return }
                    store.selectProject(id)
                }
            )) {
                ForEach(store.projects) { project in
                    Section(project.project.name) {
                        ForEach(project.workspaces) { workspace in
                            Button {
                                store.selectProject(project.project.id)
                                store.selectWorkspace(workspace.id)
                            } label: {
                                HStack {
                                    Image(systemName: workspace.id == store.snapshot.selectedWorkspaceID ? "square.fill" : "square.split.2x1")
                                    Text(workspace.name)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Button("New Workspace") {
                store.createWorkspace()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.07))
    }

    private func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.openProject(at: url)
        }
    }
}

private struct WorkspaceCanvasView: View {
    @ObservedObject var store: WorkbenchStore
    let workspace: WorkspaceRecord

    var body: some View {
        RecursiveSplitView(store: store, workspace: workspace, node: workspace.layout)
            .padding(12)
    }
}

private struct RecursiveSplitView: View {
    @ObservedObject var store: WorkbenchStore
    let workspace: WorkspaceRecord
    let node: WorkspaceLayoutNode

    var body: some View {
        switch node {
        case .leaf(let cardID):
            if let card = workspace.cards.first(where: { $0.id == cardID }) {
                CardSurfaceView(store: store, workspace: workspace, card: card)
            } else {
                Color.clear
            }
        case .split(axis: .horizontal, ratio: _, first: let first, second: let second):
            HSplitView {
                RecursiveSplitView(store: store, workspace: workspace, node: first)
                RecursiveSplitView(store: store, workspace: workspace, node: second)
            }
        case .split(axis: .vertical, ratio: _, first: let first, second: let second):
            VSplitView {
                RecursiveSplitView(store: store, workspace: workspace, node: first)
                RecursiveSplitView(store: store, workspace: workspace, node: second)
            }
        }
    }
}

private struct CardSurfaceView: View {
    @ObservedObject var store: WorkbenchStore
    let workspace: WorkspaceRecord
    let card: CardInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.title)
                    .font(.headline)
                Spacer()
                if card.followsActiveThread {
                    Label("Following", systemImage: "dot.scope")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.1, green: 0.11, blue: 0.12))

            Group {
                switch card.kind {
                case .agentChat:
                    CodexCardView(store: store, card: card)
                case .threadGraph:
                    ThreadGraphCardView(store: store, card: card)
                case .changeTracking:
                    ChangeTrackingCardView(store: store, card: card)
                case .diff:
                    DiffCardView(store: store, card: card)
                case .editor:
                    EditorCardView(store: store, card: card)
                case .notes:
                    NotesCardView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.08, green: 0.09, blue: 0.1))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onTapGesture {
            store.focusCard(card.id)
        }
    }
}

private struct CodexCardView: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance
    @State private var isHistoryPresented = false

    var body: some View {
        let session = store.session(for: card.id)
        let chatState = store.chatState(for: card.id)
        let threads = store.threads()
        let activeThread = session?.activeThreadID.flatMap { activeID in
            threads.first(where: { $0.id == activeID })
        }

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(activeThread?.title ?? "Codex session")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(session?.status.rawValue.capitalized ?? "Idle")
                        .font(.caption)
                        .foregroundStyle(session?.status == .running ? .green : .secondary)
                }
                Spacer()
                if chatState.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    isHistoryPresented.toggle()
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .popover(isPresented: $isHistoryPresented) {
                    CodexThreadHistoryPopover(
                        threads: threads,
                        activeThreadID: session?.activeThreadID,
                        selectThread: { thread in
                            store.resumeThread(thread, from: card.id)
                            isHistoryPresented = false
                        }
                    )
                }
                CodexCardActionsMenu(store: store, card: card, session: session, chatState: chatState)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if let error = chatState.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if chatState.messages.isEmpty {
                        ContentUnavailableView(
                            "Start a Codex conversation",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Messages for the current session will appear here.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        ForEach(chatState.messages) { message in
                            CodexMessageBubble(message: message, isGenerating: chatState.isGenerating)
                        }
                    }

                    if chatState.isGenerating && !chatState.messages.contains(where: { $0.role == .assistant }) {
                        CodexMessageBubble(
                            message: ChatMessageRecord(role: .assistant, text: ""),
                            isGenerating: true
                        )
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !chatState.pendingApprovals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Approvals")
                        .font(.subheadline.weight(.semibold))
                    ForEach(chatState.pendingApprovals) { approval in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(approval.title)
                                .font(.body.weight(.medium))
                            Text(approval.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Approve") { store.resolveApproval(approval, decision: .approve, from: card.id) }
                                Button("Deny") { store.resolveApproval(approval, decision: .deny, from: card.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            HStack(spacing: 8) {
                TextField(
                    "Send a message to Codex",
                    text: Binding(
                        get: { store.chatState(for: card.id).draft },
                        set: { store.updateDraft($0, for: card.id) }
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)

                Button("Send") { store.sendDraftMessage(from: card.id) }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(session == nil)
            }
            .padding(14)
            .background(Color.black.opacity(0.18))
        }
    }
}

private struct CodexMessageBubble: View {
    let message: ChatMessageRecord
    let isGenerating: Bool

    var body: some View {
        let isAssistant = message.role == .assistant
        VStack(alignment: .leading, spacing: 5) {
            Text(message.role.rawValue.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isAssistant ? .green : .secondary)
            Text(message.text.isEmpty && isAssistant && isGenerating ? "Thinking..." : message.text)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(isAssistant ? 0.06 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CodexThreadHistoryPopover: View {
    let threads: [CodexThreadRecord]
    let activeThreadID: UUID?
    let selectThread: (CodexThreadRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Codex History")
                .font(.headline)

            if threads.isEmpty {
                Text("No previous sessions yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 280, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(threads) { thread in
                            Button {
                                selectThread(thread)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: thread.id == activeThreadID ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(thread.id == activeThreadID ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(thread.title)
                                            .font(.body.weight(.medium))
                                            .lineLimit(1)
                                        Text(thread.state.rawValue.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(8)
                                .frame(width: 320, alignment: .leading)
                                .background(Color.white.opacity(thread.id == activeThreadID ? 0.08 : 0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
        .padding(14)
    }
}

private struct CodexCardActionsMenu: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance
    let session: RuntimeSessionRecord?
    let chatState: ChatCardRuntimeState

    var body: some View {
        Menu {
            Button("Start Codex") { store.startSession(for: card.id) }
            Button("Interrupt") { store.interruptTurn(from: card.id) }
                .disabled(session == nil || !chatState.isGenerating)
            Button("End Session") { store.endSession(for: card.id) }
                .disabled(session == nil)
            Divider()
            Button("Fork Active Thread") { store.forkActiveThread(from: card.id) }
                .disabled(session?.activeRemoteThreadID == nil)
            Button("Rollback One Turn") { store.rollbackActiveThread(from: card.id) }
                .disabled(session?.activeRemoteThreadID == nil)
            Button("Run pwd") { store.sendShellCommand("pwd", from: card.id) }
                .disabled(session?.activeRemoteThreadID == nil)
            if !chatState.toolProgress.isEmpty || !chatState.shellOutput.isEmpty {
                Divider()
                Text("Recent activity is available in thread history.")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
    }
}

private struct ThreadGraphCardView: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance

    var body: some View {
        let threadID = store.activeThreadID(for: card)
        let turns = threadID.map { store.turns(for: $0) } ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(turns) { turn in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Turn \(turn.index)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                        ForEach(store.items(for: turn.id)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body.weight(.medium))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }

                let changes = store.fileChanges(for: threadID)
                if !changes.isEmpty {
                    Text("File Changes")
                        .font(.subheadline.weight(.semibold))
                    ForEach(changes) { change in
                        Button {
                            store.openDiff(fileChangeID: change.id, threadID: threadID, artifactID: change.artifactID)
                        } label: {
                            HStack {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                Text(store.artifact(for: change.artifactID)?.path ?? change.id.uuidString)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding()
        }
    }
}

private struct ChangeTrackingCardView: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance

    var body: some View {
        let threadID = store.activeThreadID(for: card)
        let changes = store.fileChanges(for: threadID)

        List(changes) { change in
            VStack(alignment: .leading, spacing: 6) {
                Text((store.artifact(for: change.artifactID)?.path ?? "Unknown file").split(separator: "/").suffix(2).joined(separator: "/"))
                    .font(.body.weight(.medium))
                HStack {
                    Text(change.isFullyAttributed ? "Attributed" : "Needs attribution")
                    Text(change.timestamp.formatted(date: .omitted, time: .standard))
                }
                .font(.caption)
                .foregroundStyle(change.isFullyAttributed ? .green : .secondary)

                HStack {
                    Button("Open Diff") {
                        store.openDiff(fileChangeID: change.id, threadID: threadID, artifactID: change.artifactID)
                    }
                    Button("Open Editor") {
                        store.openEditor(artifactID: change.artifactID, threadID: threadID)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.inset)
    }
}

private struct DiffCardView: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance

    var body: some View {
        let change = store.currentFileChange(for: card)

        Group {
            if let change {
                VStack(alignment: .leading, spacing: 12) {
                    if let artifact = store.artifact(for: change.artifactID) {
                        Text(artifact.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Before")
                                .font(.subheadline.weight(.semibold))
                            ScrollView {
                                Text(change.beforeSnapshot ?? "")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("After")
                                .font(.subheadline.weight(.semibold))
                            ScrollView {
                                Text(change.afterSnapshot ?? "")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding()
            } else {
                ContentUnavailableView("No Diff Selected", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}

private struct EditorCardView: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance
    @State private var text: String = ""
    @State private var filePath: String = ""
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let artifact = store.currentArtifact(for: card) {
                HStack {
                    Text(artifact.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Reload") {
                        load(artifact: artifact)
                    }
                    Button("Save") {
                        do {
                            try store.updateArtifact(artifact, contents: text)
                            loadError = nil
                        } catch {
                            loadError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .onAppear {
                        if artifact.path != filePath {
                            load(artifact: artifact)
                        }
                    }
            } else {
                ContentUnavailableView("No File Selected", systemImage: "pencil.and.scribble")
            }

            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private func load(artifact: ArtifactRecord) {
        filePath = artifact.path
        text = (try? String(contentsOf: URL(fileURLWithPath: artifact.path), encoding: .utf8)) ?? ""
    }
}

private struct NotesCardView: View {
    @ObservedObject var store: WorkbenchStore

    var body: some View {
        TextEditor(
            text: Binding(
                get: { store.selectedWorkspace?.note.text ?? "" },
                set: { store.updateWorkspaceNote($0) }
            )
        )
        .padding()
        .font(.body)
    }
}

private struct StatusPill: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
            .foregroundStyle(isActive ? .green : .secondary)
            .clipShape(Capsule())
    }
}
