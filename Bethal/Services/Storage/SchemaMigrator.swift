import Foundation

/// Applies sequential schema migrations for a working directory.
///
/// v1 is the baseline: no transforms. Future versions add steps in `performStep(to:from:now:)`.
public struct SchemaMigrator: Sendable {
    public init() {}

    /// Migrates `manifest` up to `SchemaManifest.currentVersion` if needed.
    /// - Returns: Updated manifest (may be unchanged).
    public func migrate(
        manifest: SchemaManifest,
        layout: ProjectLayout,
        fileSystem: FileSystemClient,
        now: Date = Date()
    ) throws -> SchemaManifest {
        // Reserved for future file rewrites during migration.
        _ = layout
        _ = fileSystem

        if manifest.schemaVersion > SchemaManifest.currentVersion {
            throw StorageError.unsupportedSchemaVersion(
                found: manifest.schemaVersion,
                supported: SchemaManifest.currentVersion
            )
        }

        var current = manifest
        var version = current.schemaVersion
        while version < SchemaManifest.currentVersion {
            version += 1
            current = try performStep(to: version, from: current, now: now)
        }
        return current
    }

    /// Applies a single step that produces schema `version`.
    public func performStep(
        to version: Int,
        from manifest: SchemaManifest,
        now: Date = Date()
    ) throws -> SchemaManifest {
        switch version {
        case 1:
            return SchemaManifest(
                schemaVersion: 1,
                createdAt: manifest.createdAt,
                lastMigratedAt: now
            )
        default:
            throw StorageError.unsupportedSchemaVersion(
                found: version,
                supported: SchemaManifest.currentVersion
            )
        }
    }
}
