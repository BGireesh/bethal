import Foundation

/// Minimal key-value surface for session preferences (UserDefaults in production).
public protocol KeyValueStore: Sendable {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
    func removeValue(forKey key: String)
}

/// Production store backed by `UserDefaults`.
public struct UserDefaultsKeyValueStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func setData(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

/// In-memory store for unit tests.
public final class InMemoryKeyValueStore: KeyValueStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    public init(storage: [String: Data] = [:]) {
        self.storage = storage
    }

    public func data(forKey key: String) -> Data? {
        storage[key]
    }

    public func setData(_ data: Data?, forKey key: String) {
        if let data {
            storage[key] = data
        } else {
            storage.removeValue(forKey: key)
        }
    }

    public func removeValue(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}
