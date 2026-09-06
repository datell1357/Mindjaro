package com.maeumjaro.app.feature.analytics

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.data.local.*
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

class JsonHistoryExporterTest {
    @Test fun `free locks before repository access and produces no bytes`() = runTest {
        val result = JsonExport(ThrowingRepository(), DebugEntitlementRepository(Entitlement.FREE)).execute(Instant.EPOCH)
        assertTrue(result === AccessResult.Locked)
    }

    @Test fun `pro export is deterministic except for injected export time and preserves every field`() = runTest {
        val first = event("2026-09-05T00:00:02Z", PhraseId("tone,\"line\nnext"), EntrySource.APP)
        val second = event("2026-09-04T00:00:02Z", PhraseId("second"), EntrySource.WIDGET)
        val repository = FakeRepository(listOf(first, second))
        val useCase = JsonExport(repository, DebugEntitlementRepository(Entitlement.PRO))
        val a = (useCase.execute(Instant.parse("2026-09-06T00:00:00Z")) as AccessResult.Unlocked).value.bytes
        val b = (useCase.execute(Instant.parse("2026-09-06T00:00:00Z")) as AccessResult.Unlocked).value.bytes
        assertArrayEquals(a, b)
        val json = a.toString(Charsets.UTF_8)
        assertTrue(json.startsWith("{\"schemaVersion\":\"maeumjaro-export-v1\",\"exportedAtUtc\":\"2026-09-06T00:00:00Z\",\"events\":["))
        listOf("completedAtUTC", "eventLocalDate", "timezoneOffsetMinutes", "intensity", "source", "phraseID", "eventID", "startedAtUTC", "animationDurationMs", "interruptionCount", "appVersion", "createdAtUTC").forEach { assertTrue(json.contains("\"$it\"")) }
        assertTrue(json.contains("tone,\\\"line\\nnext"))
        assertTrue(json.indexOf(second.id.toString()) < json.indexOf(first.id.toString()))
        val export = (useCase.execute(Instant.parse("2026-09-06T00:00:00Z")) as AccessResult.Unlocked).value
        assertEquals("application/json", export.mimeType)
        assertEquals("maeumjaro-history.json", export.suggestedFileName)
        assertEquals(3, repository.readCount)
    }

    @Test fun `changing injected export time changes only export timestamp`() = runTest {
        val repository = FakeRepository(listOf(event("2026-09-05T00:00:02Z", PhraseId("x"), EntrySource.APP)))
        val useCase = JsonExport(repository, DebugEntitlementRepository(Entitlement.PRO))
        val a = ((useCase.execute(Instant.EPOCH) as AccessResult.Unlocked).value.bytes).toString(Charsets.UTF_8)
        val b = ((useCase.execute(Instant.ofEpochSecond(1)) as AccessResult.Unlocked).value.bytes).toString(Charsets.UTF_8)
        assertEquals(a.replace("1970-01-01T00:00:00Z", "TIME"), b.replace("1970-01-01T00:00:01Z", "TIME"))
    }

    private fun event(completed: String, phrase: PhraseId, source: EntrySource) = StoredInjectionEvent(
        UUID.randomUUID(), Instant.parse(completed).minusSeconds(2), Instant.parse(completed), LocalDate.of(2026, 9, 5), 540,
        requireNotNull(Intensity.from(3)), source, phrase, 1800, 1, "0.1,\"test\"", Instant.parse(completed).plusSeconds(1)
    )

    private open class FakeRepository(private val events: List<StoredInjectionEvent>) : InjectionEventRepository {
        var readCount = 0
        override suspend fun insertCompletedEvent(event: StoredInjectionEvent) = EventInsertResult.Inserted
        override suspend fun totalsForStoredDate(date: LocalDate) = DailyTotals(date, 0, 0)
        override suspend fun latest(limit: Int) = emptyList<StoredInjectionEvent>()
        override suspend fun eventsInStoredDateRange(range: StoredDateRange) = emptyList<StoredInjectionEvent>()
        override suspend fun dailyAggregates(range: StoredDateRange) = emptyList<DailyAggregate>()
        override suspend fun sixteenWeekDailyAggregates(endingOn: LocalDate) = emptyList<DailyAggregate>()
        override suspend fun fiftyTwoWeekDailyAggregates(endingOn: LocalDate) = emptyList<DailyAggregate>()
        override suspend fun event(id: UUID) = null
        override suspend fun chronologicalExport(): List<StoredInjectionEvent> { readCount++; return events }
        override suspend fun editIntensity(id: UUID, intensity: Intensity) = EditResult.Missing
        override suspend fun deleteEvent(id: UUID, decision: DeletionDecision) = DeleteResult.Canceled
        override suspend fun deleteEvents(ids: Set<UUID>, decision: DeletionDecision) = DeleteResult.Canceled
    }

    private class ThrowingRepository : FakeRepository(emptyList()) {
        override suspend fun chronologicalExport(): List<StoredInjectionEvent> = error("Free must not read repository")
    }
}
