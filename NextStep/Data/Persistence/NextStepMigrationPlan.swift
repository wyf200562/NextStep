import SwiftData

/// Migration plan skeleton for the v1 schema.
///
/// v1.x only allows additive, lightweight changes (optional fields or new models), so no stages
/// exist yet. A destructive change requires clearing the store with an explicit user-facing notice.
nonisolated enum NextStepMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}
