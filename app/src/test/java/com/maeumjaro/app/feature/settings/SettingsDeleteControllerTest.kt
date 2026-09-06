package com.maeumjaro.app.feature.settings

import com.maeumjaro.app.data.local.DeletionDecision
import com.maeumjaro.app.data.local.DeleteResult
import com.maeumjaro.app.data.local.DailyAggregate
import com.maeumjaro.app.data.local.DailyTotals
import com.maeumjaro.app.data.local.EditResult
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.local.StoredDateRange
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.data.settings.ReconcileTrigger
import com.maeumjaro.app.data.settings.ReconciliationResult
import com.maeumjaro.app.data.settings.WidgetProjection
import com.maeumjaro.app.data.settings.WidgetProjectionReconcilerGateway
import com.maeumjaro.app.feature.completion.CompletionRepair
import com.maeumjaro.app.feature.completion.CompletionRepairTracker
import com.maeumjaro.app.feature.completion.CompletionWidgetGateway
import com.maeumjaro.app.core.Intensity
import java.time.LocalDate
import java.util.UUID
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class SettingsDeleteControllerTest {
    @Test fun `database failure is returned without projection or widget work`() = runBlocking {
        val projection = FakeProjection()
        val widget = FakeWidget()
        val result = controller(FailingRepository(), projection, widget).deleteAll()

        assertEquals(SettingsDeleteResult.DatabaseFailure, result)
        assertFalse(projection.called)
        assertFalse(widget.called)
    }

    @Test fun `projection failure reports pending after room deletion`() = runBlocking {
        val projection = FakeProjection(ReconciliationResult.Failure(ReconcileTrigger.BULK_DELETE, Exception()))
        val tracker = CompletionRepairTracker()
        val result = controller(DeletingRepository(), projection, FakeWidget(), tracker).deleteAll()

        assertEquals(SettingsDeleteResult.ProjectionPending, result)
        assertEquals(setOf(CompletionRepair.PROJECTION), tracker.pending)
    }

    @Test fun `intensity save runs projection and widget refresh`() = runBlocking {
        val projection = FakeProjection()
        val widget = FakeWidget()
        val result = SettingsOperationController(projection, widget, CompletionRepairTracker()) { 1L }
            .intensityChanged { }

        assertEquals(SettingsOperationResult.Success, result)
        assertEquals(true, projection.called)
        assertEquals(true, widget.called)
    }

    @Test fun `intensity refresh failure is retryable without exposing exception`() = runBlocking {
        val result = SettingsOperationController(FakeProjection(), FakeWidget(fail = true), CompletionRepairTracker()) { 1L }
            .intensityChanged { }

        assertEquals(SettingsOperationResult.Failure, result)
    }

    @Test fun `export preparation failure is safe and retryable`() = runBlocking {
        val result = SettingsExportController(
            prepare = { error("path and data details") },
            share = {},
            ioDispatcher = kotlinx.coroutines.Dispatchers.Unconfined,
            mainDispatcher = kotlinx.coroutines.Dispatchers.Unconfined,
        ).export()

        assertEquals(SettingsExportResult.Failure, result)
    }

    @Test fun `export prepares before sharing through injected dispatchers`() = runTest {
        val io = kotlinx.coroutines.Dispatchers.Unconfined
        val main = kotlinx.coroutines.Dispatchers.Unconfined
        val events = mutableListOf<String>()
        val file = java.io.File("history.csv")

        val export = SettingsExportController(
            prepare = { events += "prepare"; file },
            share = { events += "share:${it.name}" },
            ioDispatcher = io,
            mainDispatcher = main,
        )
        assertEquals(SettingsExportResult.Success, export.export())
        assertEquals(listOf("prepare", "share:history.csv"), events)
    }

    private fun controller(
        repository: InjectionEventRepository,
        projection: FakeProjection,
        widget: FakeWidget,
        tracker: CompletionRepairTracker = CompletionRepairTracker(),
    ) = SettingsDeleteController(repository, projection, widget, tracker) { 1L }

    private class FakeProjection(private val result: ReconciliationResult = ReconciliationResult.Success(ReconcileTrigger.BULK_DELETE, WidgetProjection.getDefaultInstance())) : WidgetProjectionReconcilerGateway {
        var called = false
        override suspend fun reconcile(trigger: ReconcileTrigger, updatedAtEpochMillis: Long): ReconciliationResult {
            called = true
            return result
        }
    }

    private class FakeWidget(private val fail: Boolean = false) : CompletionWidgetGateway {
        var called = false
        override suspend fun updateAll() { called = true; if (fail) error("widget details") }
    }

    private class FailingRepository : RepositoryStub() {
        override suspend fun deleteAllEvents(decision: DeletionDecision): DeleteResult = error("db")
    }

    private class DeletingRepository : RepositoryStub() {
        override suspend fun deleteAllEvents(decision: DeletionDecision): DeleteResult = DeleteResult.Deleted(2)
    }

    private abstract class RepositoryStub : InjectionEventRepository {
        override suspend fun insertCompletedEvent(event: StoredInjectionEvent) = error("unused")
        override suspend fun totalsForStoredDate(date: LocalDate): DailyTotals = error("unused")
        override suspend fun latest(limit: Int): List<StoredInjectionEvent> = error("unused")
        override suspend fun eventsInStoredDateRange(range: StoredDateRange): List<StoredInjectionEvent> = error("unused")
        override suspend fun dailyAggregates(range: StoredDateRange): List<DailyAggregate> = error("unused")
        override suspend fun sixteenWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> = error("unused")
        override suspend fun fiftyTwoWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> = error("unused")
        override suspend fun event(id: UUID): StoredInjectionEvent? = error("unused")
        override suspend fun chronologicalExport(): List<StoredInjectionEvent> = error("unused")
        override suspend fun editIntensity(id: UUID, intensity: Intensity): EditResult = error("unused")
        override suspend fun deleteEvent(id: UUID, decision: DeletionDecision): DeleteResult = error("unused")
        override suspend fun deleteEvents(ids: Set<UUID>, decision: DeletionDecision): DeleteResult = error("unused")
    }
}
