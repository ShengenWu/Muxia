import SwiftUI
import AppKit

public struct WorkbenchRootView: View {
    @ObservedObject var store: WorkbenchStore
    @State private var isSidebarExpanded = true

    public init(store: WorkbenchStore) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let workspace = store.selectedWorkspace {
                    WorkspaceCanvasView(
                        store: store,
                        workspace: workspace,
                        leadingInset: isSidebarExpanded ? SidebarMetrics.expandedWidth + SidebarMetrics.canvasGap : SidebarMetrics.collapsedWidth + SidebarMetrics.canvasGap
                    )
                } else {
                    ContentUnavailableView("Open A Project", systemImage: "folder.badge.plus", description: Text("Muxia v0 starts from a Project and seeds a default Workspace shell."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.07, blue: 0.08),
                        Color(red: 0.03, green: 0.04, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            SidebarView(store: store, isExpanded: $isSidebarExpanded)
                .padding(.leading, 18)
                .padding(.top, 12)
        }
        .background(WindowChromeConfigurator())
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .toolbar {
            if isSidebarExpanded {
                ToolbarItemGroup(placement: .navigation) {
                    toolbarButton(systemImage: "folder.badge.plus", help: "Open Project", prominent: true) {
                        openProjectPanel()
                    }

                    toolbarButton(systemImage: "plus", help: "New Workspace") {
                        store.createWorkspace()
                    }
                    .disabled(store.selectedProject == nil)

                    toolbarButton(systemImage: "sidebar.left", help: "Collapse Sidebar") {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                            isSidebarExpanded = false
                        }
                    }
                }
            }
        }
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

    @ViewBuilder
    private func toolbarButton(systemImage: String, help: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        if prominent {
            Button(action: action) {
                Image(systemName: systemImage)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .help(help)
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(help)
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var store: WorkbenchStore
    @Binding var isExpanded: Bool

    var body: some View {
        Group {
            if isExpanded {
                expandedSidebar
            } else {
                collapsedSidebarButton
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isExpanded)
    }

    private var expandedSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if store.projects.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No project loaded")
                            .font(.subheadline.weight(.semibold))
                        Text("Open a local folder to create the first workspace.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(store.projects) { project in
                                VStack(alignment: .leading, spacing: 8) {
                                    Button {
                                        store.selectProject(project.project.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(project.project.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text(project.project.rootPath)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(project.project.id == store.snapshot.selectedProjectID ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(project.workspaces) { workspace in
                                            Button {
                                                store.selectProject(project.project.id)
                                                store.selectWorkspace(workspace.id)
                                            } label: {
                                                HStack(spacing: 8) {
                                                    Image(systemName: workspace.id == store.snapshot.selectedWorkspaceID ? "circle.fill" : "circle")
                                                        .font(.system(size: 8))
                                                        .foregroundStyle(workspace.id == store.snapshot.selectedWorkspaceID ? .green : .secondary)
                                                    Text(workspace.name)
                                                        .lineLimit(1)
                                                    Spacer(minLength: 0)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(workspace.id == store.snapshot.selectedWorkspaceID ? Color.white.opacity(0.09) : Color.clear)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(width: SidebarMetrics.expandedWidth, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 30, y: 18)
    }

    private var collapsedSidebarButton: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                isExpanded = true
            }
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: SidebarMetrics.controlSize, height: SidebarMetrics.controlSize)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("Expand Sidebar")
    }
}

private struct WorkspaceCanvasView: View {
    @ObservedObject var store: WorkbenchStore
    let workspace: WorkspaceRecord
    let leadingInset: CGFloat

    var body: some View {
        RecursiveSplitView(store: store, workspace: workspace, node: workspace.layout)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .padding(.trailing, 20)
            .padding(.leading, leadingInset)
            .overlay(alignment: .topTrailing) {
                FloatingAddCardMenu(store: store, workspace: workspace)
                    .padding(.top, 20)
                    .padding(.trailing, 20)
            }
    }
}

private struct FloatingAddCardMenu: View {
    @ObservedObject var store: WorkbenchStore
    let workspace: WorkspaceRecord

    var body: some View {
        Menu {
            let availableKinds = store.availableCardKinds(for: workspace)

            if availableKinds.isEmpty {
                Text("All cards already added")
            } else {
                ForEach(availableKinds, id: \.self) { kind in
                    Button(kind.title) {
                        store.addCard(kind: kind)
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 16, y: 10)
        }
        .menuStyle(.borderlessButton)
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
                Text(card.displayTitle)
                    .font(.headline)
                Spacer()
                if card.followsActiveThread {
                    Label("Following", systemImage: "dot.scope")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Button {
                    store.closeCard(card.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
                .disabled(!store.canCloseCard(card.id))
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
                .stroke(
                    workspace.focusedCardID == card.id ? Color.green.opacity(0.45) : Color.white.opacity(0.08),
                    lineWidth: workspace.focusedCardID == card.id ? 1.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 12)
        .onTapGesture {
            store.focusCard(card.id)
        }
    }
}

private struct CodexCardView: View {
    @ObservedObject var store: WorkbenchStore
    let card: CardInstance
    @State private var isHistoryPresented = false
    @State private var composerHeight: CGFloat = ComposerMetrics.minHeight

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
                CopyableErrorBanner(error: error)
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

            HStack(alignment: .bottom, spacing: 8) {
                ChatComposerTextView(
                    text: Binding(
                        get: { store.chatState(for: card.id).draft },
                        set: { store.updateDraft($0, for: card.id) }
                    ),
                    height: $composerHeight,
                    onSend: { store.sendDraftMessage(from: card.id) }
                )
                .frame(height: composerHeight)
                .padding(.horizontal, 2)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    if store.chatState(for: card.id).draft.isEmpty {
                        Text("Message Codex")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                            .allowsHitTesting(false)
                    }
                }

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

private struct CopyableErrorBanner: View {
    let error: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: true) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(error, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy error")
        }
        .padding(10)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ChatComposerTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let onSend: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $height)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ComposerNSTextView()
        textView.delegate = context.coordinator
        textView.onSend = onSend
        textView.onHeightChange = { newHeight in
            context.coordinator.updateHeight(newHeight)
        }
        textView.string = text
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.configureComposerMetrics()

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        textView.minSize = NSSize(width: 0, height: ComposerMetrics.minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.scheduleHeightReport()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComposerNSTextView else { return }
        textView.onSend = onSend
        textView.onHeightChange = { newHeight in
            context.coordinator.updateHeight(newHeight)
        }
        if textView.string != text {
            textView.string = text
        }
        textView.configureComposerMetrics()
        textView.scheduleHeightReport()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var height: CGFloat

        init(text: Binding<String>, height: Binding<CGFloat>) {
            self._text = text
            self._height = height
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? ComposerNSTextView else { return }
            text = textView.string
            textView.scheduleHeightReport()
        }

        func updateHeight(_ newHeight: CGFloat) {
            guard abs(height - newHeight) > 0.5 else { return }
            height = newHeight
        }
    }
}

private final class ComposerNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?
    private var pendingHeightReport = false

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        scheduleHeightReport()
    }

    func configureComposerMetrics() {
        let lineHeight = layoutManager?.defaultLineHeight(for: font ?? .systemFont(ofSize: NSFont.systemFontSize)) ?? 17
        let verticalInset = max(5, floor((ComposerMetrics.minHeight - lineHeight) / 2))
        textContainerInset = NSSize(width: 6, height: verticalInset)
    }

    func reportHeightIfNeeded() {
        guard let layoutManager, let textContainer else { return }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let contentHeight = ceil(usedRect.height) + (textContainerInset.height * 2)
        let clampedHeight = min(max(contentHeight, ComposerMetrics.minHeight), ComposerMetrics.maxHeight)
        enclosingScrollView?.hasVerticalScroller = contentHeight > ComposerMetrics.maxHeight + 0.5
        onHeightChange?(clampedHeight)
    }

    func scheduleHeightReport() {
        guard !pendingHeightReport else { return }
        pendingHeightReport = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingHeightReport = false
            self.reportHeightIfNeeded()
        }
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isReturn = keyCode == 36 || keyCode == 76

        if isReturn && !modifiers.contains(.shift) {
            onSend?()
            return
        }

        super.keyDown(with: event)
    }
}

private enum ComposerMetrics {
    static let minHeight: CGFloat = 36
    static let maxHeight: CGFloat = 72
}

private enum SidebarMetrics {
    static let expandedWidth: CGFloat = 320
    static let collapsedWidth: CGFloat = 54
    static let canvasGap: CGFloat = 16
    static let controlSize: CGFloat = 34
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        window.styleMask.insert(.fullSizeContentView)
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
