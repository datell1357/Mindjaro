package com.maeumjaro.app.feature.history

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.data.local.DailyAggregate
import com.maeumjaro.app.data.local.DailyTotals
import com.maeumjaro.app.data.local.DeleteResult
import com.maeumjaro.app.data.local.DeletionDecision
import com.maeumjaro.app.data.local.EditResult
import com.maeumjaro.app.data.local.EventInsertResult
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.local.StoredDateRange
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.feature.analytics.DebugEntitlementRepository
import com.maeumjaro.app.feature.analytics.Entitlement
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.UUID
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryControllerTest {
    @Test
    fun editRequeriesAndNotifiesWhileCanceledDeleteDoesNeither() = runTest {
        val original = event(3)
        val repository = FakeRepository(mutableListOf(original))
        var changes = 0
        val controller = HistoryController(repository, fixedClock, HistoryMutationObserver { changes++ })

        val canceled = controller.delete(original.id, confirmed = false)
        assertTrue(canceled is HistoryMutationResult.Canceled)
        assertEquals(0, changes)
        assertEquals(3, repository.events.single().intensity.value)

        val edited = controller.correctIntensity(original.id, 5)
        assertTrue(edited is HistoryMutationResult.Applied)
        assertEquals(1, changes)
        assertEquals(5, (edited as HistoryMutationResult.Applied).dashboard.latest.single().intensity.value)

        val deleted = controller.delete(original.id, confirmed = true)
        assertTrue(deleted is HistoryMutationResult.Applied)
        assertEquals(2, changes)
        assertTrue(repository.events.isEmpty())
    }

    @Test
    fun malformedIntensityDoesNotMutateOrNotify() = runTest {
        val original = event(3)
        val repository = FakeRepository(mutableListOf(original))
        var changes = 0
        val controller = HistoryController(repository, fixedClock, HistoryMutationObserver { changes++ })
        assertTrue(controller.correctIntensity(original.id, 0) is HistoryMutationResult.InvalidIntensity)
        assertEquals(0, changes)
        assertEquals(3, repository.events.single().intensity.value)
    }

    @Test
    fun projectionFailureIsReportedWithoutHidingTheAppliedRoomMutation() = runTest {
        val original = event(3)
        val repository = FakeRepository(mutableListOf(original))
        val controller = HistoryController(repository, fixedClock, HistoryMutationObserver { error("projection failed") })

        val result = controller.correctIntensity(original.id, 5)

        assertTrue(result is HistoryMutationResult.ProjectionPending)
        assertEquals(5, repository.events.single().intensity.value)
        assertEquals(5, (result as HistoryMutationResult.ProjectionPending).dashboard.latest.single().intensity.value)
    }

    @Test
    fun proDashboardQueriesAndExposesTheFiftyTwoWeekWindow() = runTest {
        val repository = FakeRepository(mutableListOf(event(3)))
        val controller = HistoryController(
            repository,
            fixedClock,
            entitlements = DebugEntitlementRepository(Entitlement.PRO),
        )
        val dashboard = controller.dashboard()
        assertEquals(Entitlement.PRO, dashboard.entitlement)
        assertEquals(52, dashboard.visibleHeatmapWeeks)
        assertEquals(364, dashboard.heatmap.size)
        assertEquals(364, dashboard.visibleHistoryDays)
        assertEquals(1, dashboard.visibleHistory.size)
    }

    @Test
    fun dashboardRebuildsToTheFreeWindowAfterEntitlementDowngrade() = runTest {
        val repository = FakeRepository(mutableListOf(event(3)))
        val entitlement = DebugEntitlementRepository(Entitlement.PRO)
        val controller = HistoryController(repository, fixedClock, entitlements = entitlement)

        val pro = controller.dashboard()
        assertEquals(52, pro.visibleHeatmapWeeks)
        assertEquals(364, pro.visibleHistoryDays)

        entitlement.entitlement = Entitlement.FREE
        val free = controller.dashboard()
        assertEquals(Entitlement.FREE, free.entitlement)
        assertEquals(16, free.visibleHeatmapWeeks)
        assertEquals(30, free.visibleHistoryDays)
        assertEquals(112, free.heatmap.size)
    }

    private class FakeRepository(val events: MutableList<StoredInjectionEvent>) : InjectionEventRepository {
        override suspend fun insertCompletedEvent(event: StoredInjectionEvent) = EventInsertResult.Inserted
        override suspend fun totalsForStoredDate(date: LocalDate) = DailyTotals(date, events.count { it.eventLocalDate == date }, events.filter { it.eventLocalDate == date }.sumOf { it.intensity.value })
        override suspend fun latest(limit: Int) = events.sortedByDescending { it.completedAtUtc }.take(limit)
        override suspend fun eventsInStoredDateRange(range: StoredDateRange) = events.filter { it.eventLocalDate in range.first..range.lastInclusive }
        override suspend fun dailyAggregates(range: StoredDateRange) = eventsInStoredDateRange(range).groupBy { it.eventLocalDate }.map { (date, values) -> DailyAggregate(date, values.size, values.sumOf { it.intensity.value }) }
        override suspend fun sixteenWeekDailyAggregates(endingOn: LocalDate) = dailyAggregates(StoredDateRange(endingOn.minusWeeks(16).plusDays(1), endingOn))
        override suspend fun fiftyTwoWeekDailyAggregates(endingOn: LocalDate) = dailyAggregates(StoredDateRange(endingOn.minusWeeks(52).plusDays(1), endingOn))
        override suspend fun event(id: UUID) = events.firstOrNull { it.id == id }
        override suspend fun chronologicalExport() = events.sortedBy { it.completedAtUtc }
        override suspend fun editIntensity(id: UUID, intensity: Intensity): EditResult {
            val index = events.indexOfFirst { it.id == id }
            if (index < 0) return EditResult.Missing
            events[index] = events[index].copy(intensity = intensity)
            return EditResult.Updated
        }
        override suspend fun deleteEvent(id: UUID, decision: DeletionDecision): DeleteResult {
            if (decision == DeletionDecision.Canceled) return DeleteResult.Canceled
            val removed = events.removeAll { it.id == id }
            return DeleteResult.Deleted(if (removed) 1 else 0)
        }
        override suspend fun deleteEvents(ids: Set<UUID>, decision: DeletionDecision): DeleteResult = DeleteResult.Canceled
    }

    companion object {
        private val fixedClock = Clock.fixed(Instant.parse("2026-09-05T03:00:00Z"), ZoneOffset.ofHours(9))
        private fun event(intensity: Int) = StoredInjectionEvent(
            id = UUID.fromString("00000000-0000-0000-0000-000000000001"),
            startedAtUtc = Instant.parse("2026-09-05T00:59:58Z"),
            completedAtUtc = Instant.parse("2026-09-05T01:00:00Z"),
            eventLocalDate = LocalDate.parse("2026-09-05"),
            timezoneOffsetMinutes = 540,
            intensity = requireNotNull(Intensity.from(intensity)),
            source = EntrySource.APP,
            phraseId = PhraseId("ground-001"),
            animationDurationMs = 1_800,
            interruptionCount = 0,
            appVersion = "test",
            createdAtUtc = Instant.parse("2026-09-05T01:00:00Z"),
        )
    }
}
