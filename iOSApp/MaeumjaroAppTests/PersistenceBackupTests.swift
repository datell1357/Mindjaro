import Foundation
import MaeumjaroPersistence
import XCTest

@MainActor
final class PersistenceBackupTests: XCTestCase {
    func testPersistentStoreIsExcludedFromBackupAndWrittenToHostApplicationSupport() throws {
        let fileManager = FileManager.default
        let applicationSupport = try XCTUnwrap(
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        )
        let directory = applicationSupport
            .appendingPathComponent("MaeumjaroQA", isDirectory: true)
            .appendingPathComponent("BackupAudit-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent("Maeumjaro.sqlite", isDirectory: false)

        _ = try ModelContainerFactory.makePersistent(at: storeURL, fileManager: fileManager)

        var freshDirectory = URL(fileURLWithPath: directory.path, isDirectory: true)
        freshDirectory.removeAllCachedResourceValues()
        let readBackExcluded = try freshDirectory
            .resourceValues(forKeys: [.isExcludedFromBackupKey])
            .isExcludedFromBackup == true
        let storeFilePresent = fileManager.fileExists(atPath: storeURL.path)
        let relativeContainerPath = String(
            storeURL.path.dropFirst(applicationSupport.path.count + 1)
        )
        let evidence: [String: Any] = [
            "containerPath": relativeContainerPath,
            "backupExcludedReadback": readBackExcluded,
            "storeFilePresent": storeFilePresent
        ]
        let evidenceData = try JSONSerialization.data(
            withJSONObject: evidence,
            options: [.prettyPrinted, .sortedKeys]
        )
        let attachment = XCTAttachment(data: evidenceData, uniformTypeIdentifier: "public.json")
        attachment.name = "persistence-backup-audit.json"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(readBackExcluded)
        XCTAssertTrue(storeFilePresent)
    }
}
