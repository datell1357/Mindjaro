import Foundation
import SwiftData
#if os(macOS)
    import Darwin
#endif

public enum PersistenceError: Error, Equatable, Sendable {
    case applicationSupportUnavailable
    case storeDirectoryCreationFailed(String)
    case backupExclusionFailed(String)
    case containerOpenFailed(String)
    case migrationUnsupported(String)
    case migrationFailed(String)
    case invalidStoredValue(entity: String, field: String)
    case catalogUnavailable
    case catalogDecodingFailed
    case deletionConfirmationRequired
    case deletionScopeEmpty
}

extension PersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            String(localized: "persistence.applicationSupportUnavailable", defaultValue: "앱 저장 공간을 사용할 수 없습니다.", bundle: .module)
        case let .storeDirectoryCreationFailed(reason):
            String(localized: "persistence.storeDirectoryCreationFailed", defaultValue: "저장 폴더를 만들 수 없습니다: \(reason)", bundle: .module)
        case let .backupExclusionFailed(reason):
            String(localized: "persistence.backupExclusionFailed", defaultValue: "저장 백업 제외를 확인할 수 없습니다: \(reason)", bundle: .module)
        case let .containerOpenFailed(reason):
            String(localized: "persistence.containerOpenFailed", defaultValue: "저장 컨테이너를 열 수 없습니다: \(reason)", bundle: .module)
        case let .migrationUnsupported(reason):
            String(localized: "persistence.migrationUnsupported", defaultValue: "저장소 마이그레이션을 지원하지 않습니다: \(reason)", bundle: .module)
        case let .migrationFailed(reason):
            String(localized: "persistence.migrationFailed", defaultValue: "저장소 마이그레이션에 실패했습니다: \(reason)", bundle: .module)
        case let .invalidStoredValue(entity, field):
            String(localized: "persistence.invalidStoredValue", defaultValue: "저장된 \(entity) 값의 \(field) 항목이 올바르지 않습니다.", bundle: .module)
        case .catalogUnavailable:
            String(localized: "persistence.catalogUnavailable", defaultValue: "문구 카탈로그를 사용할 수 없습니다.", bundle: .module)
        case .catalogDecodingFailed:
            String(localized: "persistence.catalogDecodingFailed", defaultValue: "문구 카탈로그를 읽을 수 없습니다.", bundle: .module)
        case .deletionConfirmationRequired:
            String(localized: "persistence.deletionConfirmationRequired", defaultValue: "삭제하려면 확인 토큰이 필요합니다.", bundle: .module)
        case .deletionScopeEmpty:
            String(localized: "persistence.deletionScopeEmpty", defaultValue: "삭제 범위가 비어 있습니다.", bundle: .module)
        }
    }
}

@MainActor
public enum ModelContainerFactory {
    public static let productionDirectoryName = "Maeumjaro"
    public static let productionStoreName = "Maeumjaro.sqlite"

    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(versionedSchema: MaeumjaroSchemaV1.self),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try openContainer(configuration: configuration, persistentURL: nil)
    }

    public static func makeInMemoryContainer() throws -> ModelContainer {
        try makeInMemory()
    }

    public static func productionStoreURL(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw PersistenceError.applicationSupportUnavailable
        }
        return applicationSupport
            .appendingPathComponent(productionDirectoryName, isDirectory: true)
            .appendingPathComponent(productionStoreName, isDirectory: false)
    }

    public static func makeProductionContainer(
        fileManager: FileManager = .default
    ) throws -> ModelContainer {
        try makePersistent(at: productionStoreURL(fileManager: fileManager), fileManager: fileManager)
    }

    public static func makePersistent(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws -> ModelContainer {
        var directory = storeURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw PersistenceError.storeDirectoryCreationFailed(error.localizedDescription)
        }

        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try directory.setResourceValues(resourceValues)
            #if os(macOS)
                let readBackSucceeded = directory.path.withCString { path in
                    "com.apple.metadata:com_apple_backup_excludeItem".withCString { key in
                        getxattr(path, key, nil, 0, 0, 0) > 0
                    }
                }
            #else
                let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
                let readBackSucceeded = values.isExcludedFromBackup == true
            #endif
            guard readBackSucceeded else {
                throw PersistenceError.backupExclusionFailed("read-back was false")
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.backupExclusionFailed(error.localizedDescription)
        }

        let configuration = ModelConfiguration(
            schema: Schema(versionedSchema: MaeumjaroSchemaV1.self),
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try openContainer(configuration: configuration, persistentURL: storeURL)
    }

    public static func open(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws -> ModelContainer {
        try makePersistent(at: storeURL, fileManager: fileManager)
    }

    private static func openContainer(
        configuration: ModelConfiguration,
        persistentURL: URL?
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: MaeumjaroSchemaV1.self),
                migrationPlan: MaeumjaroMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            if let persistentURL,
               FileManager.default.fileExists(atPath: persistentURL.path)
            {
                throw PersistenceError.migrationUnsupported(error.localizedDescription)
            }
            throw PersistenceError.containerOpenFailed(error.localizedDescription)
        }
    }
}
