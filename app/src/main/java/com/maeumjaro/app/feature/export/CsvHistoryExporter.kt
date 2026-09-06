package com.maeumjaro.app.feature.export

import com.maeumjaro.app.data.local.StoredInjectionEvent
import java.time.format.DateTimeFormatter

object CsvHistoryExporter {
    const val schemaVersion = "maeumjaro-export-v1"
    private val formatter = DateTimeFormatter.ISO_INSTANT
    private val fields = listOf(
        "completedAtUTC", "eventLocalDate", "timezoneOffsetMinutes", "intensity", "source", "phraseID",
        "eventID", "startedAtUTC", "animationDurationMs", "interruptionCount", "appVersion", "createdAtUTC",
    )

    fun encode(events: List<StoredInjectionEvent>): ByteArray? {
        if (events.isEmpty()) return null
        val rows = buildList {
            add(listOf("schemaVersion", schemaVersion))
            add(fields)
            events.sortedWith(compareBy<StoredInjectionEvent> { it.completedAtUtc }.thenBy { it.id.toString() })
                .forEach { event ->
                    add(
                        listOf(
                            formatter.format(event.completedAtUtc), event.eventLocalDate.toString(),
                            event.timezoneOffsetMinutes.toString(), event.intensity.value.toString(),
                            event.source.name.lowercase(), event.phraseId.value, event.id.toString(),
                            formatter.format(event.startedAtUtc), event.animationDurationMs.toString(),
                            event.interruptionCount.toString(), event.appVersion,
                            formatter.format(event.createdAtUtc),
                        ),
                    )
                }
        }
        val text = rows.joinToString("\r\n") { row -> row.joinToString(",", transform = ::escape) } + "\r\n"
        return byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()) + text.toByteArray(Charsets.UTF_8)
    }

    private fun escape(value: String): String =
        if (value.any { it == ',' || it == '"' || it == '\r' || it == '\n' }) {
            "\"${value.replace("\"", "\"\"")}\""
        } else value
}
