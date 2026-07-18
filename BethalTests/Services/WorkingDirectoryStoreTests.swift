import Foundation
import Testing
@testable import Bethal

@Suite("WorkingDirectoryStore")
struct WorkingDirectoryStoreTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore(
        root: URL = URL(fileURLWithPath: "/Users/test/BethalData", isDirectory: true),
        fs: InMemoryFileSystem = InMemoryFileSystem()
    ) -> (WorkingDirectoryStore, InMemoryFileSystem) {
        let store = WorkingDirectoryStore(
            root: root,
            fileSystem: fs,
            clock: { fixedNow }
        )
        return (store, fs)
    }

    private func sampleMeeting(id: String = "meet-1", title: String = "Vendor call") -> Meeting {
        Meeting(
            id: id,
            title: title,
            status: .captured,
            captureMode: .audioOnly,
            startedAt: fixedNow.addingTimeInterval(-3600),
            endedAt: fixedNow,
            audioFileName: "audio.m4a",
            createdAt: fixedNow.addingTimeInterval(-3600),
            updatedAt: fixedNow.addingTimeInterval(-3600)
        )
    }

    // MARK: - Initialize

    @Test("operations fail before initialize")
    func notInitialized() throws {
        let (store, _) = makeStore()
        #expect(!store.isInitialized)
        #expect(throws: StorageError.notInitialized) {
            try store.loadSettings()
        }
        #expect(throws: StorageError.notInitialized) {
            try store.listMeetings()
        }
    }

    @Test("initialize creates layout, schema, settings, and empty indexes")
    func initializeCreatesLayout() throws {
        let (store, fs) = makeStore()
        let manifest = try store.initialize()
        #expect(store.isInitialized)
        #expect(manifest.schemaVersion == SchemaManifest.currentVersion)
        #expect(fs.fileExists(atPath: store.layout.schemaFile.path))
        #expect(fs.fileExists(atPath: store.layout.settingsFile.path))
        #expect(fs.fileExists(atPath: store.layout.meetingsIndexFile.path))
        #expect(fs.fileExists(atPath: store.layout.todosIndexFile.path))
        #expect(try store.listMeetings().isEmpty)
        #expect(try store.loadGlobalTodos().isEmpty)
        #expect(try store.loadSettings() == AppSettings.default)
    }

    @Test("initialize is idempotent")
    func initializeIdempotent() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        try store.saveSettings(AppSettings(defaultAIProviderID: "claude"))
        _ = try store.initialize()
        #expect(try store.loadSettings().defaultAIProviderID == "claude")
    }

    @Test("layout initializer shares root")
    func layoutInitializer() throws {
        let root = URL(fileURLWithPath: "/tmp/bethal-root", isDirectory: true)
        let layout = ProjectLayout(root: root)
        let store = WorkingDirectoryStore(layout: layout, fileSystem: InMemoryFileSystem(), clock: { fixedNow })
        _ = try store.initialize()
        #expect(store.layout.root.path == root.standardizedFileURL.path)
    }

    @Test("default clock initializers initialize successfully")
    func defaultClockInitializers() throws {
        let root = URL(fileURLWithPath: "/tmp/bethal-default-clock", isDirectory: true)
        let fs = InMemoryFileSystem()
        let byRoot = WorkingDirectoryStore(root: root, fileSystem: fs)
        _ = try byRoot.initialize()
        #expect(byRoot.isInitialized)

        let fs2 = InMemoryFileSystem()
        let byLayout = WorkingDirectoryStore(layout: ProjectLayout(root: root), fileSystem: fs2)
        _ = try byLayout.initialize()
        #expect(byLayout.isInitialized)
    }

    // MARK: - Settings & schema

    @Test("save and load settings")
    func settingsRoundTrip() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        let settings = AppSettings(
            defaultCaptureMode: .audioVideo,
            defaultAIProviderID: "codex",
            askEveryTimeForProvider: false,
            calendarAutoDetectEnabled: false,
            calendarRemindMinutesBefore: 10
        )
        try store.saveSettings(settings)
        #expect(try store.loadSettings() == settings)
    }

    @Test("loadSchema returns manifest")
    func loadSchema() throws {
        let (store, _) = makeStore()
        let created = try store.initialize()
        let loaded = try store.loadSchema()
        #expect(loaded.schemaVersion == created.schemaVersion)
    }

    @Test("migrateIfNeeded upgrades old schema and rewrites file")
    func migrateUpgrades() throws {
        let (store, fs) = makeStore()
        _ = try store.initialize()
        let old = SchemaManifest(schemaVersion: 0, createdAt: Date(timeIntervalSince1970: 1))
        fs.seedFile(at: store.layout.schemaFile, data: try JSONCoding.encode(old))
        let migrated = try store.migrateIfNeeded()
        #expect(migrated.schemaVersion == SchemaManifest.currentVersion)
        #expect(try store.loadSchema().schemaVersion == SchemaManifest.currentVersion)
    }

    // MARK: - Meetings

    @Test("create, load, list, update meeting")
    func meetingCRUD() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        let meeting = sampleMeeting()
        try store.createMeeting(meeting)

        let loaded = try store.loadMeeting(id: meeting.id)
        #expect(loaded.id == meeting.id)
        #expect(loaded.title == meeting.title)
        #expect(loaded.updatedAt == fixedNow)

        var list = try store.listMeetings()
        #expect(list.count == 1)
        #expect(list[0].id == meeting.id)

        var updated = loaded
        updated.title = "Renamed"
        updated.status = .transcribed
        try store.updateMeeting(updated)
        #expect(try store.loadMeeting(id: meeting.id).title == "Renamed")
        list = try store.listMeetings()
        #expect(list[0].title == "Renamed")
        #expect(list[0].status == .transcribed)
    }

    @Test("listMeetings sorts by startedAt descending")
    func listSorted() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        var older = sampleMeeting(id: "old", title: "Older")
        older.startedAt = fixedNow.addingTimeInterval(-10_000)
        var newer = sampleMeeting(id: "new", title: "Newer")
        newer.startedAt = fixedNow.addingTimeInterval(-100)
        try store.createMeeting(older)
        try store.createMeeting(newer)
        let list = try store.listMeetings()
        #expect(list.map(\.id) == ["new", "old"])
    }

    @Test("duplicate create fails")
    func duplicateCreate() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        try store.createMeeting(sampleMeeting())
        #expect(throws: StorageError.self) {
            try store.createMeeting(sampleMeeting())
        }
    }

    @Test("invalid meeting id rejected")
    func invalidID() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        #expect(throws: StorageError.invalidMeetingID("bad/id")) {
            try store.createMeeting(sampleMeeting(id: "bad/id"))
        }
        #expect(throws: StorageError.invalidMeetingID("..")) {
            _ = try store.loadMeeting(id: "..")
        }
    }

    @Test("update and load missing meeting fail")
    func missingMeeting() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        #expect(throws: StorageError.meetingNotFound("nope")) {
            _ = try store.loadMeeting(id: "nope")
        }
        #expect(throws: StorageError.meetingNotFound("nope")) {
            try store.updateMeeting(sampleMeeting(id: "nope"))
        }
        #expect(throws: StorageError.meetingNotFound("nope")) {
            try store.deleteMeeting(id: "nope")
        }
    }

    @Test("delete meeting removes folder, index, and global todos")
    func deleteMeeting() throws {
        let (store, fs) = makeStore()
        _ = try store.initialize()
        try store.createMeeting(sampleMeeting(id: "del-1"))
        try store.upsertGlobalTodo(
            TodoItem(id: "t1", title: "Task", meetingID: "del-1", meetingTitle: "Vendor call")
        )
        try store.upsertGlobalTodo(
            TodoItem(id: "t2", title: "Other", meetingID: "keep", meetingTitle: "Other call")
        )
        try store.deleteMeeting(id: "del-1")
        #expect(throws: StorageError.meetingNotFound("del-1")) {
            _ = try store.loadMeeting(id: "del-1")
        }
        #expect(try store.listMeetings().isEmpty)
        let todos = try store.loadGlobalTodos()
        #expect(todos.map(\.id) == ["t2"])
        #expect(!fs.fileExists(atPath: store.layout.meetingDirectory(id: "del-1").path))
    }

    // MARK: - Transcript / summary / proposed todos

    @Test("transcript and summary optional load")
    func transcriptAndSummary() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        try store.createMeeting(sampleMeeting())

        #expect(try store.loadTranscript(meetingID: "meet-1") == nil)
        #expect(try store.loadSummary(meetingID: "meet-1") == nil)

        let transcript = Transcript(
            meetingID: "meet-1",
            languageCode: "en",
            segments: [
                TranscriptSegment(id: "s1", startSeconds: 0, endSeconds: 2, text: "Hello"),
            ],
            createdAt: fixedNow
        )
        try store.saveTranscript(transcript)
        #expect(try store.loadTranscript(meetingID: "meet-1") == transcript)

        try store.saveSummary("# Notes\n\nAction items pending.", meetingID: "meet-1")
        #expect(try store.loadSummary(meetingID: "meet-1") == "# Notes\n\nAction items pending.")
    }

    @Test("proposed todos normalize lifecycle and meeting id")
    func proposedTodos() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        try store.createMeeting(sampleMeeting())

        #expect(try store.loadProposedTodos(meetingID: "meet-1").isEmpty)

        let raw = [
            TodoItem(
                id: "p1",
                title: "Send recap",
                meetingID: "wrong",
                meetingTitle: "Vendor call",
                lifecycle: .accepted
            ),
        ]
        try store.saveProposedTodos(raw, meetingID: "meet-1")
        let loaded = try store.loadProposedTodos(meetingID: "meet-1")
        #expect(loaded.count == 1)
        #expect(loaded[0].meetingID == "meet-1")
        #expect(loaded[0].lifecycle == .proposed)
    }

    @Test("artifact writes require existing meeting")
    func artifactsRequireMeeting() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        #expect(throws: StorageError.meetingNotFound("ghost")) {
            try store.saveTranscript(Transcript(meetingID: "ghost"))
        }
        #expect(throws: StorageError.meetingNotFound("ghost")) {
            try store.saveSummary("x", meetingID: "ghost")
        }
        #expect(throws: StorageError.meetingNotFound("ghost")) {
            try store.saveProposedTodos([], meetingID: "ghost")
        }
    }

    // MARK: - Global todos

    @Test("global todo upsert, remove, accept proposed")
    func globalTodos() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        try store.createMeeting(sampleMeeting())

        let proposed = [
            TodoItem(id: "a", title: "Keep", meetingID: "meet-1", meetingTitle: "Vendor call"),
            TodoItem(id: "b", title: "Drop", meetingID: "meet-1", meetingTitle: "Vendor call"),
        ]
        try store.saveProposedTodos(proposed, meetingID: "meet-1")

        let accepted = try store.acceptProposedTodos(ids: ["a"], meetingID: "meet-1")
        #expect(accepted.map(\.id) == ["a"])
        #expect(accepted[0].lifecycle == .accepted)

        var global = try store.loadGlobalTodos()
        #expect(global.map(\.id) == ["a"])

        var updated = global[0]
        updated.title = "Keep (edited)"
        try store.upsertGlobalTodo(updated)
        global = try store.loadGlobalTodos()
        #expect(global.count == 1)
        #expect(global[0].title == "Keep (edited)")

        try store.removeGlobalTodo(id: "a")
        #expect(try store.loadGlobalTodos().isEmpty)
        #expect(throws: StorageError.todoNotFound("a")) {
            try store.removeGlobalTodo(id: "a")
        }
    }

    @Test("saveGlobalTodos forces accepted lifecycle")
    func saveGlobalForcesAccepted() throws {
        let (store, _) = makeStore()
        _ = try store.initialize()
        try store.saveGlobalTodos([
            TodoItem(id: "t", title: "X", meetingID: "m", meetingTitle: "M", lifecycle: .proposed),
        ])
        #expect(try store.loadGlobalTodos()[0].lifecycle == .accepted)
    }

    // MARK: - Corrupt / IO failures

    @Test("corrupt JSON surfaces StorageError.corruptFile")
    func corruptJSON() throws {
        let (store, fs) = makeStore()
        _ = try store.initialize()
        fs.seedFile(at: store.layout.settingsFile, data: Data("not-json".utf8))
        #expect(throws: StorageError.self) {
            _ = try store.loadSettings()
        }
    }

    @Test("write failure maps to ioFailure")
    func writeFailure() throws {
        let (store, fs) = makeStore()
        _ = try store.initialize()
        fs.failNextWrite = true
        #expect(throws: StorageError.self) {
            try store.saveSettings(AppSettings.default)
        }
    }

    @Test("read failure maps to ioFailure")
    func readFailure() throws {
        let (store, fs) = makeStore()
        _ = try store.initialize()
        fs.failNextRead = true
        #expect(throws: StorageError.self) {
            _ = try store.loadSettings()
        }
    }

    @Test("real temp directory round-trip via FoundationFileSystem")
    func realTempDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bethal-store-\(UUID().uuidString)", isDirectory: true)
        let store = WorkingDirectoryStore(root: root, clock: { fixedNow })
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try store.initialize()
        try store.createMeeting(sampleMeeting(id: "disk-1", title: "On disk"))
        try store.saveTranscript(
            Transcript(
                meetingID: "disk-1",
                segments: [TranscriptSegment(id: "s", startSeconds: 0, endSeconds: 1, text: "hi")],
                createdAt: fixedNow
            )
        )
        #expect(try store.loadMeeting(id: "disk-1").title == "On disk")
        #expect(try store.loadTranscript(meetingID: "disk-1")?.fullText == "hi")
        #expect(FileManager.default.fileExists(atPath: store.layout.meetingMetaFile(id: "disk-1").path))
    }
}
