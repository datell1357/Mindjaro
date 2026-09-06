import Foundation
import SwiftData
import Testing
#if os(macOS)
import Darwin
#endif

import MaeumjaroPersistence

@Test
@MainActor
func inMemoryContainerUsesOnlyTheV1Entities() throws {
    let container = try ModelContainerFactory.makeInMemory()

    #expect(container.schema.entities.count == 3)
    #expect(MaeumjaroSchemaV1.models.count == 3)
    #expect(MaeumjaroSchemaV1.models.contains { String(describing: $0).contains("Event") })
    #expect(MaeumjaroSchemaV1.models.contains { String(describing: $0).contains("Settings") })
    #expect(MaeumjaroSchemaV1.models.contains { String(describing: $0).contains("Phrase") })
}

@Test
@MainActor
func persistentStoreDirectoryIsExcludedFromBackupAfterReadBack() throws {
    let root = ProcessInfo.processInfo.environment["MAEUMJARO_TASK6_EVIDENCE"]
        .map(URL.init(fileURLWithPath:))
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("maeumjaro-task6", isDirectory: true)
    let storeURL = root
        .appendingPathComponent("model-container-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("store.sqlite", isDirectory: false)
    _ = try ModelContainerFactory.makePersistent(at: storeURL)

    let directory = storeURL.deletingLastPathComponent()
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
    #expect(readBackSucceeded)
    #expect(storeURL.path.contains("group.com.yeoreum.maeumjaro") == false)
}
