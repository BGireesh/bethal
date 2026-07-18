import Foundation

/// File-backed store for meetings, transcripts, todos, and settings under a working directory.
public final class WorkingDirectoryStore: @unchecked Sendable {
    public let layout: ProjectLayout
    private let fileSystem: FileSystemClient
    private let migrator: SchemaMigrator
    private let clock: () -> Date

    public init(
        root: URL,
        fileSystem: FileSystemClient = FoundationFileSystem(),
        migrator: SchemaMigrator = SchemaMigrator(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.layout = ProjectLayout(root: root)
        self.fileSystem = fileSystem
        self.migrator = migrator
        self.clock = clock
    }

    public init(
        layout: ProjectLayout,
        fileSystem: FileSystemClient = FoundationFileSystem(),
        migrator: SchemaMigrator = SchemaMigrator(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.layout = layout
        self.fileSystem = fileSystem
        self.migrator = migrator
        self.clock = clock
    }

    // MARK: - Lifecycle

    /// Whether `.bethal/schema.json` exists.
    public var isInitialized: Bool {
        fileSystem.fileExists(atPath: layout.schemaFile.path)
    }

    /// Creates required directories, schema, default settings, and empty indexes.
    /// Idempotent if already initialized at the current schema version.
    @discardableResult
    public func initialize() throws -> SchemaManifest {
        try createRequiredDirectories()

        if isInitialized {
            return try migrateIfNeeded()
        }

        let now = clock()
        let manifest = SchemaManifest(schemaVersion: SchemaManifest.currentVersion, createdAt: now)
        try writeJSON(manifest, to: layout.schemaFile)
        try writeJSON(AppSettings.default, to: layout.settingsFile)
        try writeJSON(MeetingsIndex(), to: layout.meetingsIndexFile)
        try writeJSON(TodosDocument(), to: layout.todosIndexFile)
        return manifest
    }

    /// Loads schema and applies migrations when the directory is older than this build.
    @discardableResult
    public func migrateIfNeeded() throws -> SchemaManifest {
        try ensureInitialized()
        let existing = try readJSON(SchemaManifest.self, from: layout.schemaFile)
        let migrated = try migrator.migrate(
            manifest: existing,
            layout: layout,
            fileSystem: fileSystem,
            now: clock()
        )
        if migrated != existing {
            try writeJSON(migrated, to: layout.schemaFile)
        }
        return migrated
    }

    public func loadSchema() throws -> SchemaManifest {
        try ensureInitialized()
        return try readJSON(SchemaManifest.self, from: layout.schemaFile)
    }

    // MARK: - Settings

    public func loadSettings() throws -> AppSettings {
        try ensureInitialized()
        return try readJSON(AppSettings.self, from: layout.settingsFile)
    }

    public func saveSettings(_ settings: AppSettings) throws {
        try ensureInitialized()
        try writeJSON(settings, to: layout.settingsFile)
    }

    // MARK: - Meetings

    public func createMeeting(_ meeting: Meeting) throws {
        try ensureInitialized()
        try validateMeetingID(meeting.id)

        let dir = layout.meetingDirectory(id: meeting.id)
        if fileSystem.fileExists(atPath: layout.meetingMetaFile(id: meeting.id).path) {
            throw StorageError.ioFailure("Meeting already exists: \(meeting.id)")
        }

        try fileSystem.createDirectory(at: dir, withIntermediateDirectories: true)
        var stored = meeting
        stored.updatedAt = clock()
        try writeJSON(stored, to: layout.meetingMetaFile(id: meeting.id))
        try upsertIndexEntry(stored.indexEntry)
    }

    public func updateMeeting(_ meeting: Meeting) throws {
        try ensureInitialized()
        try validateMeetingID(meeting.id)
        guard fileSystem.fileExists(atPath: layout.meetingMetaFile(id: meeting.id).path) else {
            throw StorageError.meetingNotFound(meeting.id)
        }
        var stored = meeting
        stored.updatedAt = clock()
        try writeJSON(stored, to: layout.meetingMetaFile(id: meeting.id))
        try upsertIndexEntry(stored.indexEntry)
    }

    public func loadMeeting(id: String) throws -> Meeting {
        try ensureInitialized()
        try validateMeetingID(id)
        let url = layout.meetingMetaFile(id: id)
        guard fileSystem.fileExists(atPath: url.path) else {
            throw StorageError.meetingNotFound(id)
        }
        return try readJSON(Meeting.self, from: url)
    }

    public func listMeetings() throws -> [MeetingIndexEntry] {
        try ensureInitialized()
        let index = try readJSON(MeetingsIndex.self, from: layout.meetingsIndexFile)
        return index.meetings.sorted { $0.startedAt > $1.startedAt }
    }

    public func deleteMeeting(id: String) throws {
        try ensureInitialized()
        try validateMeetingID(id)
        let dir = layout.meetingDirectory(id: id)
        guard fileSystem.fileExists(atPath: dir.path) else {
            throw StorageError.meetingNotFound(id)
        }
        try fileSystem.removeItem(at: dir)
        try removeIndexEntry(id: id)
        try removeGlobalTodos(forMeetingID: id)
    }

    // MARK: - Transcript / summary / proposed todos

    public func saveTranscript(_ transcript: Transcript) throws {
        try ensureInitialized()
        try validateMeetingID(transcript.meetingID)
        try requireMeetingExists(transcript.meetingID)
        try writeJSON(transcript, to: layout.meetingTranscriptFile(id: transcript.meetingID))
    }

    public func loadTranscript(meetingID: String) throws -> Transcript? {
        try ensureInitialized()
        try validateMeetingID(meetingID)
        let url = layout.meetingTranscriptFile(id: meetingID)
        guard fileSystem.fileExists(atPath: url.path) else { return nil }
        return try readJSON(Transcript.self, from: url)
    }

    public func saveSummary(_ markdown: String, meetingID: String) throws {
        try ensureInitialized()
        try validateMeetingID(meetingID)
        try requireMeetingExists(meetingID)
        let data = Data(markdown.utf8)
        try fileSystem.writeData(data, to: layout.meetingSummaryFile(id: meetingID))
    }

    public func loadSummary(meetingID: String) throws -> String? {
        try ensureInitialized()
        try validateMeetingID(meetingID)
        let url = layout.meetingSummaryFile(id: meetingID)
        guard fileSystem.fileExists(atPath: url.path) else { return nil }
        let data = try fileSystem.readData(from: url)
        return String(data: data, encoding: .utf8)
    }

    public func saveProposedTodos(_ todos: [TodoItem], meetingID: String) throws {
        try ensureInitialized()
        try validateMeetingID(meetingID)
        try requireMeetingExists(meetingID)
        let normalized = todos.map { todo -> TodoItem in
            var copy = todo
            copy.meetingID = meetingID
            copy.lifecycle = .proposed
            return copy
        }
        try writeJSON(TodosDocument(todos: normalized), to: layout.meetingTodosFile(id: meetingID))
    }

    public func loadProposedTodos(meetingID: String) throws -> [TodoItem] {
        try ensureInitialized()
        try validateMeetingID(meetingID)
        let url = layout.meetingTodosFile(id: meetingID)
        guard fileSystem.fileExists(atPath: url.path) else { return [] }
        return try readJSON(TodosDocument.self, from: url).todos
    }

    // MARK: - Global todos

    public func loadGlobalTodos() throws -> [TodoItem] {
        try ensureInitialized()
        return try readJSON(TodosDocument.self, from: layout.todosIndexFile).todos
    }

    public func saveGlobalTodos(_ todos: [TodoItem]) throws {
        try ensureInitialized()
        let normalized = todos.map { todo -> TodoItem in
            var copy = todo
            copy.lifecycle = .accepted
            return copy
        }
        try writeJSON(TodosDocument(todos: normalized), to: layout.todosIndexFile)
    }

    public func upsertGlobalTodo(_ todo: TodoItem) throws {
        try ensureInitialized()
        var todos = try loadGlobalTodos()
        let accepted = todo.acceptedCopy()
        if let index = todos.firstIndex(where: { $0.id == accepted.id }) {
            todos[index] = accepted
        } else {
            todos.append(accepted)
        }
        try saveGlobalTodos(todos)
    }

    public func removeGlobalTodo(id: String) throws {
        try ensureInitialized()
        var todos = try loadGlobalTodos()
        let before = todos.count
        todos.removeAll { $0.id == id }
        guard todos.count < before else {
            throw StorageError.todoNotFound(id)
        }
        try saveGlobalTodos(todos)
    }

    /// Accepts proposed todos into the global list (by id). Missing ids are ignored.
    public func acceptProposedTodos(ids: Set<String>, meetingID: String) throws -> [TodoItem] {
        try ensureInitialized()
        let proposed = try loadProposedTodos(meetingID: meetingID)
        let accepted = proposed.filter { ids.contains($0.id) }.map { $0.acceptedCopy() }
        for item in accepted {
            try upsertGlobalTodo(item)
        }
        return accepted
    }

    // MARK: - Private helpers

    private func createRequiredDirectories() throws {
        for directory in layout.requiredDirectories {
            try fileSystem.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func ensureInitialized() throws {
        guard isInitialized else { throw StorageError.notInitialized }
    }

    private func validateMeetingID(_ id: String) throws {
        guard ProjectLayout.isValidMeetingID(id) else {
            throw StorageError.invalidMeetingID(id)
        }
    }

    private func requireMeetingExists(_ id: String) throws {
        guard fileSystem.fileExists(atPath: layout.meetingMetaFile(id: id).path) else {
            throw StorageError.meetingNotFound(id)
        }
    }

    private func upsertIndexEntry(_ entry: MeetingIndexEntry) throws {
        var index = try readJSON(MeetingsIndex.self, from: layout.meetingsIndexFile)
        if let existing = index.meetings.firstIndex(where: { $0.id == entry.id }) {
            index.meetings[existing] = entry
        } else {
            index.meetings.append(entry)
        }
        try writeJSON(index, to: layout.meetingsIndexFile)
    }

    private func removeIndexEntry(id: String) throws {
        var index = try readJSON(MeetingsIndex.self, from: layout.meetingsIndexFile)
        index.meetings.removeAll { $0.id == id }
        try writeJSON(index, to: layout.meetingsIndexFile)
    }

    private func removeGlobalTodos(forMeetingID meetingID: String) throws {
        var todos = try loadGlobalTodos()
        todos.removeAll { $0.meetingID == meetingID }
        try saveGlobalTodos(todos)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        do {
            let data = try JSONCoding.encode(value)
            try fileSystem.writeData(data, to: url)
        } catch {
            throw StorageError.ioFailure(error.localizedDescription)
        }
    }

    private func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data: Data
        do {
            data = try fileSystem.readData(from: url)
        } catch {
            throw StorageError.ioFailure(error.localizedDescription)
        }
        do {
            return try JSONCoding.decode(type, from: data)
        } catch {
            throw StorageError.corruptFile(path: url.path, reason: error.localizedDescription)
        }
    }
}
