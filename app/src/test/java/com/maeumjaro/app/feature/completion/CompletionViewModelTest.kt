package com.maeumjaro.app.feature.completion

import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.EventTime
import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.data.local.DailyAggregate
import com.maeumjaro.app.data.local.DailyTotals
import com.maeumjaro.app.data.local.DeleteResult
import com.maeumjaro.app.data.local.DeletionDecision
import com.maeumjaro.app.data.local.EditResult
import com.maeumjaro.app.data.local.EventInsertResult
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.local.StoredDateRange
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.data.settings.ReconcileTrigger
import com.maeumjaro.app.data.settings.ReconciliationResult
import com.maeumjaro.app.data.settings.WidgetProjection
import com.maeumjaro.app.data.settings.WidgetProjectionReconcilerGateway
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class CompletionViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setMain() = Dispatchers.setMain(dispatcher)

    @After fun resetMain() = Dispatchers.resetMain()

    @Test
    fun `fail first retry keeps the frozen attempt and commits exactly one event`() = runTest(dispatcher) {
        val repository = FailFirstRepository()
        val viewModel = CompletionViewModel(useCase(repository))

        viewModel.begin(draft, PhraseTone.AUTOMATIC)
        advanceUntilIdle()

        val failed = viewModel.state.value as CompletionUiState.Failed
        assertEquals(draft.sessionId, failed.attempt.event.id)
        repository.fail = false

        viewModel.retry()
        advanceUntilIdle()

        val completed = viewModel.state.value as CompletionUiState.Completed
        assertEquals(failed.attempt, completed.result.attempt)
        assertEquals(EventInsertResult.Inserted, completed.result.insertResult)
        assertEquals(1, repository.events.size)
        assertEquals(1, repository.attempts.distinctBy { it.id }.size)
    }

    @Test
    fun `repeated completion callback is idempotent for the same frozen uuid`() = runTest(dispatcher) {
        val repository = FailFirstRepository(fail = false)
        val viewModel = CompletionViewModel(useCase(repository))

        viewModel.begin(draft, PhraseTone.AUTOMATIC)
        advanceUntilIdle()
        val first = (viewModel.state.value as CompletionUiState.Completed).result.attempt

        // Repeated callback is represented by the same immutable attempt retained by the route.
        val second = useCase(repository).commit(first)

        assertTrue(second is CompletionResult.Success)
        assertEquals(first.event.id, (second as CompletionResult.Success).attempt.event.id)
        assertEquals(EventInsertResult.AlreadyExists, second.insertResult)
        assertEquals(1, repository.events.size)
    }

    @Test
    fun `activity recreation reuses committing view model and completes one frozen event`() = runTest(dispatcher) {
        val repository = FailFirstRepository(fail = false)
        val store = ViewModelStore()
        val ownerBeforeRotation = object : ViewModelStoreOwner { override val viewModelStore = store }
        val ownerAfterRotation = object : ViewModelStoreOwner { override val viewModelStore = store }
        val factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                CompletionViewModel(useCase(repository)) as T
        }

        val beforeRotation = ViewModelProvider(ownerBeforeRotation, factory)
            .get("completion", CompletionViewModel::class.java)
        beforeRotation.begin(draft, PhraseTone.AUTOMATIC)
        val afterRotation = ViewModelProvider(ownerAfterRotation, factory)
            .get("completion", CompletionViewModel::class.java)

        assertTrue(beforeRotation === afterRotation)
        advanceUntilIdle()
        val completed = afterRotation.state.value as CompletionUiState.Completed
        assertEquals(draft.sessionId, completed.result.attempt.event.id)
        assertEquals(1, repository.events.size)
    }

    private fun useCase(repository: InjectionEventRepository) = CompleteInjectionUseCase(
        repository = repository,
        projectionReconciler = object : WidgetProjectionReconcilerGateway {
            override suspend fun reconcile(trigger: ReconcileTrigger, updatedAtEpochMillis: Long) =
                ReconciliationResult.Success(trigger, WidgetProjection.getDefaultInstance())
        },
        widgetGateway = CompletionWidgetGateway.None,
        clock = Clock.fixed(now, ZoneOffset.UTC),
        appVersion = "view-model-test",
        phraseIndex = CompletionPhraseIndex(SafePhraseCatalog.phrases),
        randomIndex = { 0 },
    )

    private class FailFirstRepository(var fail: Boolean = true) : InjectionEventRepository {
        val events = linkedMapOf<UUID, StoredInjectionEvent>()
        val attempts = mutableListOf<StoredInjectionEvent>()

        override suspend fun insertCompletedEvent(event: StoredInjectionEvent): EventInsertResult {
            attempts += event
            if (fail) error("injected first insert failure")
            return if (events.putIfAbsent(event.id, event) == null) EventInsertResult.Inserted
            else EventInsertResult.AlreadyExists
        }

        override suspend fun totalsForStoredDate(date: LocalDate) = DailyTotals(date, 0, 0)
        override suspend fun latest(limit: Int): List<StoredInjectionEvent> = events.values.toList()
        override suspend fun eventsInStoredDateRange(range: StoredDateRange) = emptyList<StoredInjectionEvent>()
        override suspend fun dailyAggregates(range: StoredDateRange): List<DailyAggregate> = emptyList()
        override suspend fun sixteenWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> = emptyList()
        override suspend fun fiftyTwoWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> = emptyList()
        override suspend fun event(id: UUID) = events[id]
        override suspend fun chronologicalExport() = events.values.toList()
        override suspend fun editIntensity(id: UUID, intensity: Intensity) = EditResult.Missing
        override suspend fun deleteEvent(id: UUID, decision: DeletionDecision) = DeleteResult.Canceled
        override suspend fun deleteEvents(ids: Set<UUID>, decision: DeletionDecision) = DeleteResult.Canceled
    }

    private companion object {
        val now = Instant.parse("2026-09-05T15:00:01Z")
        val draft = InjectionEventDraft(
            sessionId = UUID.fromString("00000000-0000-0000-0000-000000000707"),
            intensity = requireNotNull(Intensity.from(3)),
            source = EntrySource.APP,
            startedAt = now.minusSeconds(4),
            completedAt = EventTime.at(now, ZoneId.of("Asia/Seoul")),
            interruptionCount = 0,
        )
    }
}
