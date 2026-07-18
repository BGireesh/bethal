import Foundation

/// Loads and saves `AppSessionPreferences` (onboarding + working directory bookmark).
public final class AppSessionStore: @unchecked Sendable {
    public static let storageKey = "us.gireesh.bethal.sessionPreferences"

    private let keyValueStore: KeyValueStore

    public init(keyValueStore: KeyValueStore = UserDefaultsKeyValueStore()) {
        self.keyValueStore = keyValueStore
    }

    public func load() -> AppSessionPreferences {
        guard let data = keyValueStore.data(forKey: Self.storageKey) else {
            return .empty
        }
        do {
            return try JSONCoding.decode(AppSessionPreferences.self, from: data)
        } catch {
            return .empty
        }
    }

    public func save(_ preferences: AppSessionPreferences) throws {
        let data = try JSONCoding.encode(preferences)
        keyValueStore.setData(data, forKey: Self.storageKey)
    }

    public func clear() {
        keyValueStore.removeValue(forKey: Self.storageKey)
    }
}
