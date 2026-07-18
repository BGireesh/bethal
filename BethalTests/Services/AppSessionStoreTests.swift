import Foundation
import Testing
@testable import Bethal

@Suite("AppSessionStore")
struct AppSessionStoreTests {
    @Test("load empty when missing")
    func loadEmpty() {
        let store = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        #expect(store.load() == .empty)
    }

    @Test("save and load round-trip")
    func roundTrip() throws {
        let kv = InMemoryKeyValueStore()
        let store = AppSessionStore(keyValueStore: kv)
        let prefs = AppSessionPreferences(
            hasCompletedOnboarding: true,
            workingDirectoryPath: "/tmp/wd",
            workingDirectoryBookmarkData: Data([9]),
            completedAt: Date(timeIntervalSince1970: 1)
        )
        try store.save(prefs)
        #expect(store.load() == prefs)
    }

    @Test("corrupt data yields empty")
    func corrupt() {
        let kv = InMemoryKeyValueStore()
        kv.setData(Data("not-json".utf8), forKey: AppSessionStore.storageKey)
        let store = AppSessionStore(keyValueStore: kv)
        #expect(store.load() == .empty)
    }

    @Test("clear removes preferences")
    func clear() throws {
        let kv = InMemoryKeyValueStore()
        let store = AppSessionStore(keyValueStore: kv)
        try store.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/x"))
        store.clear()
        #expect(store.load() == .empty)
    }

    @Test("UserDefaults-backed store works with suite")
    func userDefaultsSuite() throws {
        let suiteName = "us.gireesh.bethal.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let kv = UserDefaultsKeyValueStore(defaults: defaults)
        let store = AppSessionStore(keyValueStore: kv)
        try store.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/suite"))
        #expect(store.load().workingDirectoryPath == "/suite")
        store.clear()
        #expect(store.load() == .empty)

        // Cover setData(nil) on both UserDefaults and in-memory stores.
        kv.setData(Data([1]), forKey: "tmp")
        kv.setData(nil, forKey: "tmp")
        #expect(kv.data(forKey: "tmp") == nil)

        let memory = InMemoryKeyValueStore()
        memory.setData(Data([2]), forKey: "m")
        memory.setData(nil, forKey: "m")
        #expect(memory.data(forKey: "m") == nil)
        memory.removeValue(forKey: "missing")
    }
}
