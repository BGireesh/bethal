import Foundation

/// Tracks the on-disk schema for a working directory (`.bethal/schema.json`).
public struct SchemaManifest: Codable, Equatable, Sendable {
    /// Current schema version written by this app build.
    public static let currentVersion = 1

    public var schemaVersion: Int
    public var createdAt: Date
    public var lastMigratedAt: Date?

    public init(
        schemaVersion: Int = SchemaManifest.currentVersion,
        createdAt: Date = Date(),
        lastMigratedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.lastMigratedAt = lastMigratedAt
    }
}
