package com.maeumjaro.app.feature.export

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.data.local.StoredInjectionEvent
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CsvHistoryExporterTest {
    @Test fun `empty export creates no bytes`() {
        assertNull(CsvHistoryExporter.encode(emptyList()))
    }

    @Test fun `export is bom csv escaped and chronological`() {
        val event = StoredInjectionEvent(
            id = UUID.fromString("00000000-0000-0000-0000-000000000001"),
            startedAtUtc = Instant.parse("2026-09-05T00:00:00Z"),
            completedAtUtc = Instant.parse("2026-09-05T00:00:02Z"),
            eventLocalDate = LocalDate.parse("2026-09-05"), timezoneOffsetMinutes = 540,
            intensity = requireNotNull(Intensity.from(3)), source = EntrySource.APP,
            phraseId = PhraseId("tone,\"line\nnext"), animationDurationMs = 1800,
            interruptionCount = 1, appVersion = "0.1,\"test\"",
            createdAtUtc = Instant.parse("2026-09-05T00:00:03Z"),
        )
        val expected = "\uFEFFschemaVersion,maeumjaro-export-v1\r\n" +
            "completedAtUTC,eventLocalDate,timezoneOffsetMinutes,intensity,source,phraseID,eventID,startedAtUTC,animationDurationMs,interruptionCount,appVersion,createdAtUTC\r\n" +
            "2026-09-05T00:00:02Z,2026-09-05,540,3,app,\"tone,\"\"line\nnext\",00000000-0000-0000-0000-000000000001,2026-09-05T00:00:00Z,1800,1,\"0.1,\"\"test\"\"\",2026-09-05T00:00:03Z\r\n"
        assertArrayEquals(expected.toByteArray(Charsets.UTF_8), CsvHistoryExporter.encode(listOf(event)))
    }

    @Test fun `export orders multiple rows by completion time then stable id`() {
        val later = fixture("00000000-0000-0000-0000-000000000002", "2026-09-05T00:00:02Z")
        val earlier = fixture("00000000-0000-0000-0000-000000000001", "2026-09-05T00:00:01Z")

        val text = requireNotNull(CsvHistoryExporter.encode(listOf(later, earlier))).toString(Charsets.UTF_8)

        val earlierPosition = text.indexOf(earlier.id.toString())
        val laterPosition = text.indexOf(later.id.toString())
        org.junit.Assert.assertTrue(earlierPosition < laterPosition)
    }

    @Test fun `export is byte deterministic for the same events regardless of input order`() {
        val first = fixture("00000000-0000-0000-0000-000000000001", "2026-09-05T00:00:01Z")
        val second = fixture("00000000-0000-0000-0000-000000000002", "2026-09-05T00:00:02Z")

        val forward = requireNotNull(CsvHistoryExporter.encode(listOf(first, second)))
        val reverse = requireNotNull(CsvHistoryExporter.encode(listOf(second, first)))
        val repeated = requireNotNull(CsvHistoryExporter.encode(listOf(first, second)))

        assertArrayEquals(forward, reverse)
        assertArrayEquals(forward, repeated)
    }

    private fun fixture(id: String, completedAt: String): StoredInjectionEvent = StoredInjectionEvent(
        id = UUID.fromString(id),
        startedAtUtc = Instant.parse("2026-09-05T00:00:00Z"),
        completedAtUtc = Instant.parse(completedAt),
        eventLocalDate = LocalDate.parse("2026-09-05"), timezoneOffsetMinutes = 540,
        intensity = requireNotNull(Intensity.from(3)), source = EntrySource.APP,
        phraseId = PhraseId("phrase-$id"), animationDurationMs = 1800,
        interruptionCount = 0, appVersion = "0.1.0",
        createdAtUtc = Instant.parse(completedAt),
    )
}
