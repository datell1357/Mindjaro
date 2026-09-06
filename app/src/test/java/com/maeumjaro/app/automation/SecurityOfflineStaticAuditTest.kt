package com.maeumjaro.app.automation

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Read-only source contract for Todo 14. Device-only claims stay in [ExternalGateContract].
 */
class SecurityOfflineStaticAuditTest {
    private val mainRoot = File("src/main")
    private val manifest = File(mainRoot, "AndroidManifest.xml")
    private val xmlRoot = File(mainRoot, "res/xml")

    @Test
    fun manifestHasNoDangerousOrNetworkPermissions() {
        // Given: the shipped Android manifest.
        val document = parse(manifest)
        val permissions = (0 until document.getElementsByTagName("uses-permission").length)
            .map { index ->
                document.getElementsByTagName("uses-permission").item(index)
                    .attributes.getNamedItem("android:name")?.nodeValue.orEmpty()
            }

        // When: declared capabilities are reduced to permission names.
        val forbidden = permissions.filter { permission ->
            permission.contains("INTERNET") || permission.contains("ACCESS_NETWORK") ||
                permission.contains("READ_EXTERNAL_STORAGE") || permission.contains("WRITE_EXTERNAL_STORAGE") ||
                permission.contains("READ_MEDIA") || permission.contains("CAMERA") ||
                permission.contains("RECORD_AUDIO") || permission.contains("ACCESS_FINE_LOCATION") ||
                permission.contains("ACCESS_COARSE_LOCATION") || permission.contains("READ_CONTACTS") ||
                permission.contains("AD_ID") || permission.contains("BODY_SENSORS")
        }

        // Then: local-only MVP declares no network, storage, health, or sensor permission.
        assertTrue("forbidden permissions: $forbidden", forbidden.isEmpty())
    }

    @Test
    fun productionSourceAndDependenciesHaveNoNetworkSdkOrUrlBoundary() {
        // Given: production Kotlin/Java/proto sources and the app dependency declaration.
        val files = mainRoot.walkTopDown()
            .filter { it.isFile && it.extension in setOf("kt", "java", "proto") }
            .toList() + File("build.gradle.kts")
        val forbidden = Regex(
            "(?i)(okhttp|retrofit|ktor|volley|firebase|workmanager.*network|java\\.net|android\\.net|" +
                "urlconnection|https?://|\\bURL\\s*\\(|Uri\\.parse)",
        )

        // When: every production/dependency file is scanned for a network boundary.
        val matches = files.flatMap { file ->
            forbidden.findAll(file.readText()).map { "${file.path}:${it.value}" }.toList()
        }

        // Then: no network SDK/import/URL is present in the local-only app.
        assertTrue("network boundary found: $matches", matches.isEmpty())
    }

    @Test
    fun productionSourceDoesNotWriteDetailedEventLogs() {
        // Given: production source only (tests and evidence are intentionally excluded).
        val files = File(mainRoot, "java").walkTopDown().filter { it.isFile }.toList()
        val loggingApi = Regex("(?i)(android\\.util\\.Log|Timber\\.|println\\s*\\(|java\\.util\\.logging)")
        val eventDetailFields = Regex(
            "(?i)(completedAtUTC|startedAtUTC|eventLocalDate|timezoneOffsetMinutes|phraseID|eventID|" +
                "animationDurationMs|interruptionCount)",
        )

        // When: logging APIs and event-detail field emissions are scanned.
        val loggingMatches = files.flatMap { file ->
            loggingApi.findAll(file.readText()).map { "${file.path}:${it.value}" }.toList()
        }
        val detailMatches = files.flatMap { file ->
            file.readLines().mapIndexedNotNull { line, text ->
                if (loggingApi.containsMatchIn(text) && eventDetailFields.containsMatchIn(text)) {
                    "${file.path}:${line + 1}"
                } else null
            }
        }

        // Then: no event/detail payload can leak through a production logger.
        assertTrue("logging API found: $loggingMatches", loggingMatches.isEmpty())
        assertTrue("event detail logging found: $detailMatches", detailMatches.isEmpty())
    }

    @Test
    fun backupRulesExcludeRoomDataStoreEventsAndExportsForCloudAndDeviceTransfer() {
        // Given: legacy Auto Backup and Android 12+ extraction rules.
        val legacy = parse(File(xmlRoot, "backup_rules.xml"))
        val modern = parse(File(xmlRoot, "data_extraction_rules.xml"))

        // When: exclusion entries are collected from both rule documents.
        val requiredPaths = setOf("database:.", "file:datastore/", "file:events/", "file:exports/")
        val actual = listOf(legacy, modern).flatMap { document ->
            (0 until document.getElementsByTagName("exclude").length).map { index ->
                val node = document.getElementsByTagName("exclude").item(index)
                "${node.attributes.getNamedItem("domain").nodeValue}:" +
                    node.attributes.getNamedItem("path").nodeValue
            }
        }.toSet()

        // Then: every durable/private/export surface is excluded.
        assertTrue("missing backup exclusions: ${requiredPaths - actual}", actual.containsAll(requiredPaths))
    }

    @Test
    fun manifestWiresBothBackupRuleFormatsAndDisablesBackup() {
        // Given: parsed application attributes.
        val application = parse(manifest).getElementsByTagName("application").item(0)
        val attributes = application.attributes

        // Then: both platform rule formats are wired and backup is disabled.
        assertTrue(attributes.getNamedItem("android:allowBackup").nodeValue == "false")
        assertTrue(attributes.getNamedItem("android:dataExtractionRules").nodeValue == "@xml/data_extraction_rules")
        assertTrue(attributes.getNamedItem("android:fullBackupContent").nodeValue == "@xml/backup_rules")
    }

    private fun parse(file: File) = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
}

internal object ExternalGateContract {
    val requiredRuntimeEvidence = setOf(
        "airplane-mode-core-flow",
        "bmgr-device-to-device",
        "device-reboot-update-low-memory",
        "physical-haptics",
        "talkback-switch-access",
    )
}
