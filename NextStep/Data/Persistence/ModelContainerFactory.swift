import SwiftData

/// Creates the app's single SwiftData container.
///
/// Tests and Previews pass `isStoredInMemoryOnly: true`; the app uses the default on-disk store.
nonisolated enum ModelContainerFactory {
    static func makeContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            "NextStep",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: NextStepMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
