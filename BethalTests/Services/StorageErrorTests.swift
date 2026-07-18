import Testing
@testable import Bethal

@Suite("StorageError")
struct StorageErrorTests {
    @Test("errorDescription covers all cases")
    func descriptions() {
        #expect(StorageError.notInitialized.errorDescription?.contains("not initialized") == true)
        #expect(StorageError.invalidMeetingID("x").errorDescription?.contains("x") == true)
        #expect(StorageError.meetingNotFound("m").errorDescription?.contains("m") == true)
        #expect(StorageError.todoNotFound("t").errorDescription?.contains("t") == true)
        #expect(StorageError.corruptFile(path: "/p", reason: "bad").errorDescription?.contains("bad") == true)
        #expect(
            StorageError.unsupportedSchemaVersion(found: 9, supported: 1).errorDescription?.contains("9") == true
        )
        #expect(StorageError.ioFailure("disk full").errorDescription == "disk full")
    }

    @Test("equality")
    func equality() {
        #expect(StorageError.notInitialized == StorageError.notInitialized)
        #expect(StorageError.meetingNotFound("a") != StorageError.meetingNotFound("b"))
    }
}
