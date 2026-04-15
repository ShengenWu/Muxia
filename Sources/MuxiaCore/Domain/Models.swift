import Foundation

public enum SplitAxis: String, Codable, Hashable, Sendable {
    case horizontal
    case vertical
}

public enum CardKind: String, Codable, CaseIterable, Hashable, Sendable {
    case agentChat
    case threadGraph
    case changeTracking
    case diff
    case editor
    case notes

    public var title: String {
        switch self {
        case .agentChat: "Agent Chat"
        case .threadGraph: "Thread Graph"
        case .changeTracking: "Change Tracking"
        case .diff: "Diff"
        case .editor: "Editor"
        case .notes: "Notes"
        }
    }
}

public enum RuntimeStatus: String, Codable, Hashable, Sendable {
    case starting
    case running
    case ended
    case reconnectable
    case disconnected
}

public enum ThreadState: String, Codable, Hashable, Sendable {
    case active
    case background
    case compacted
    case archived
}

public enum ItemKind: String, Codable, Hashable, Sendable {
    case prompt
    case response
    case command
    case summary
    case fileEdit
}

public enum ArtifactKind: String, Codable, Hashable, Sendable {
    case file
    case directory
    case commandOutput
    case note
}

public struct CardBinding: Codable, Hashable, Sendable {
    public var threadID: UUID?
    public var fileChangeID: UUID?
    public var artifactID: UUID?

    public init(threadID: UUID? = nil, fileChangeID: UUID? = nil, artifactID: UUID? = nil) {
        self.threadID = threadID
        self.fileChangeID = fileChangeID
        self.artifactID = artifactID
    }
}

public struct CardInstance: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: CardKind
    public var title: String
    public var followsActiveThread: Bool
    public var binding: CardBinding

    public init(
        id: UUID = UUID(),
        kind: CardKind,
        title: String? = nil,
        followsActiveThread: Bool,
        binding: CardBinding = CardBinding()
    ) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.title
        self.followsActiveThread = followsActiveThread
        self.binding = binding
    }
}

public indirect enum WorkspaceLayoutNode: Codable, Hashable, Sendable {
    case leaf(UUID)
    case split(axis: SplitAxis, ratio: Double, first: WorkspaceLayoutNode, second: WorkspaceLayoutNode)
}

public struct WorkspaceNote: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var updatedAt: Date

    public init(id: UUID = UUID(), text: String = "", updatedAt: Date = .now) {
        self.id = id
        self.text = text
        self.updatedAt = updatedAt
    }
}

public struct WorkspaceRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var cards: [CardInstance]
    public var layout: WorkspaceLayoutNode
    public var note: WorkspaceNote
    public var focusedCardID: UUID?
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        name: String,
        cards: [CardInstance],
        layout: WorkspaceLayoutNode,
        note: WorkspaceNote = WorkspaceNote(),
        focusedCardID: UUID? = nil,
        lastUpdated: Date = .now
    ) {
        self.id = id
        self.name = name
        self.cards = cards
        self.layout = layout
        self.note = note
        self.focusedCardID = focusedCardID
        self.lastUpdated = lastUpdated
    }
}

public struct ProjectRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var rootPath: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        rootPath: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RuntimeSessionRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var projectID: UUID
    public var status: RuntimeStatus
    public var activeThreadID: UUID?
    public var reconnectToken: String
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        projectID: UUID,
        status: RuntimeStatus,
        activeThreadID: UUID? = nil,
        reconnectToken: String = UUID().uuidString,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.cardID = cardID
        self.projectID = projectID
        self.status = status
        self.activeThreadID = activeThreadID
        self.reconnectToken = reconnectToken
        self.updatedAt = updatedAt
    }
}

public struct CodexThreadRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectID: UUID
    public var title: String
    public var state: ThreadState
    public var createdAt: Date
    public var updatedAt: Date
    public var summary: String?

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        title: String,
        state: ThreadState = .active,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        summary: String? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.summary = summary
    }
}

public struct CodexTurnRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var threadID: UUID
    public var index: Int
    public var createdAt: Date

    public init(id: UUID = UUID(), threadID: UUID, index: Int, createdAt: Date = .now) {
        self.id = id
        self.threadID = threadID
        self.index = index
        self.createdAt = createdAt
    }
}

public struct CodexItemRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var turnID: UUID
    public var kind: ItemKind
    public var title: String
    public var detail: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        turnID: UUID,
        kind: ItemKind,
        title: String,
        detail: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.turnID = turnID
        self.kind = kind
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
    }
}

public struct ArtifactRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectID: UUID
    public var path: String
    public var kind: ArtifactKind
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        path: String,
        kind: ArtifactKind = .file,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.path = path
        self.kind = kind
        self.updatedAt = updatedAt
    }
}

public struct FileChangeRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectID: UUID
    public var threadID: UUID?
    public var artifactID: UUID
    public var sourceItemID: UUID?
    public var beforeSnapshot: String?
    public var afterSnapshot: String?
    public var timestamp: Date
    public var isFullyAttributed: Bool

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        threadID: UUID?,
        artifactID: UUID,
        sourceItemID: UUID?,
        beforeSnapshot: String?,
        afterSnapshot: String?,
        timestamp: Date = .now,
        isFullyAttributed: Bool
    ) {
        self.id = id
        self.projectID = projectID
        self.threadID = threadID
        self.artifactID = artifactID
        self.sourceItemID = sourceItemID
        self.beforeSnapshot = beforeSnapshot
        self.afterSnapshot = afterSnapshot
        self.timestamp = timestamp
        self.isFullyAttributed = isFullyAttributed
    }
}

public struct ProjectDocument: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID { project.id }
    public var project: ProjectRecord
    public var workspaces: [WorkspaceRecord]
    public var threads: [CodexThreadRecord]
    public var turns: [CodexTurnRecord]
    public var items: [CodexItemRecord]
    public var artifacts: [ArtifactRecord]
    public var fileChanges: [FileChangeRecord]
    public var lastActiveWorkspaceID: UUID?

    public init(
        project: ProjectRecord,
        workspaces: [WorkspaceRecord],
        threads: [CodexThreadRecord] = [],
        turns: [CodexTurnRecord] = [],
        items: [CodexItemRecord] = [],
        artifacts: [ArtifactRecord] = [],
        fileChanges: [FileChangeRecord] = [],
        lastActiveWorkspaceID: UUID? = nil
    ) {
        self.project = project
        self.workspaces = workspaces
        self.threads = threads
        self.turns = turns
        self.items = items
        self.artifacts = artifacts
        self.fileChanges = fileChanges
        self.lastActiveWorkspaceID = lastActiveWorkspaceID
    }
}

public struct AppSnapshot: Codable, Hashable, Sendable {
    public var projects: [ProjectDocument]
    public var runtimeSessions: [RuntimeSessionRecord]
    public var selectedProjectID: UUID?
    public var selectedWorkspaceID: UUID?

    public init(
        projects: [ProjectDocument] = [],
        runtimeSessions: [RuntimeSessionRecord] = [],
        selectedProjectID: UUID? = nil,
        selectedWorkspaceID: UUID? = nil
    ) {
        self.projects = projects
        self.runtimeSessions = runtimeSessions
        self.selectedProjectID = selectedProjectID
        self.selectedWorkspaceID = selectedWorkspaceID
    }
}

public struct DetectedFileChange: Hashable, Sendable {
    public var relativePath: String
    public var before: String?
    public var after: String?
    public var timestamp: Date

    public init(relativePath: String, before: String?, after: String?, timestamp: Date = .now) {
        self.relativePath = relativePath
        self.before = before
        self.after = after
        self.timestamp = timestamp
    }
}
