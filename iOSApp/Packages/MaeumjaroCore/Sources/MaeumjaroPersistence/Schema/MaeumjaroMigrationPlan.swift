import SwiftData

public enum MaeumjaroMigrationPlan: SchemaMigrationPlan {
    public static let schemas: [any VersionedSchema.Type] = [MaeumjaroSchemaV1.self]
    public static let stages: [MigrationStage] = []
}
