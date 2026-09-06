package com.maeumjaro.app.data.settings

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupRulesTest {
    @Test
    fun `excludes durable and exported data from cloud and device transfer`() {
        // Given: both platform backup rule resources.
        val resources = listOf("backup_rules.xml", "data_extraction_rules.xml").map {
            File("src/main/res/xml/$it")
        }

        // When: exclusion domains and paths are parsed.
        val exclusions = resources.flatMap { file ->
            val document = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
            val nodes = document.getElementsByTagName("exclude")
            (0 until nodes.length).map { index ->
                val attributes = nodes.item(index).attributes
                attributes.getNamedItem("domain").nodeValue to attributes.getNamedItem("path").nodeValue
            }
        }.toSet()

        // Then: databases, DataStore, event/export files, and caches are excluded.
        val requiredDomains = setOf("database", "file", "sharedpref", "root", "device_database", "device_file", "device_sharedpref", "device_root")
        assertTrue(requiredDomains.all { domain -> exclusions.any { it.first == domain } })
        assertTrue(exclusions.any { it.second.contains("datastore") })
        assertTrue(exclusions.any { it.second.contains("export") })
        assertTrue(exclusions.any { it.second.contains("event") })
    }
}
