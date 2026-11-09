import SwiftData

/// Version 1 of the NextStep schema.
///
/// Every persisted model belongs to this versioned schema from day one so future lightweight
/// migrations can be expressed as new `VersionedSchema` values.
nonisolated enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Application.self,
            JobPosting.self,
            InterviewRound.self,
            StatusChange.self,
            UserProfile.self,
        ]
    }
}
