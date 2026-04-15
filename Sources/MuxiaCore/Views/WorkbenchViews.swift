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
                    AgentChatCardView(store: store, card: card)
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

private struct AgentChatCardView: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance

    var body: some View {
        let session = store.session(for: card.id)
        let threads = store.threads()

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                StatusPill(text: session?.status.rawValue.capitalized ?? "Idle", isActive: session?.status == .running)
                Spacer()
                Button("Start") { store.startSession(for: card.id) }
                Button("End") { store.endSession(for: card.id) }.disabled(session == nil)
            }

            HStack {
                Button("New") { store.newThread(from: card.id) }.disabled(session == nil)
                Button("Resume") { store.resumePreviousThread(from: card.id) }.disabled(session == nil || threads.count < 2)
                Button("Compact") { store.compactThread(from: card.id) }.disabled(session == nil)
            }
            .buttonStyle(.bordered)

            if let threadID = session?.activeThreadID, let thread = threads.first(where: { $0.id == threadID }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Thread")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(thread.title)
                        .font(.title3.weight(.semibold))
                    Text(thread.state.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Divider()

            Text("Thread History")
                .font(.subheadline.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(threads) { thread in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thread.title)
                                .font(.body.weight(.medium))
                            Text(thread.state.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(thread.id == session?.activeThreadID ? .green : .secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding()
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
