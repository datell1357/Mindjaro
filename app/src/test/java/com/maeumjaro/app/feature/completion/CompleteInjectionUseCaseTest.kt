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
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class CompleteInjectionUseCaseTest {
    private val instant = Instant.parse("2026-09-05T15:00:01Z")
    private val draft = InjectionEventDraft(
        UUID.fromString("00000000-0000-0000-0000-000000000007"), intensity(4), EntrySource.WIDGET,
        Instant.parse("2026-09-05T14:59:58Z"), EventTime.at(instant, ZoneId.of("Asia/Seoul")), 2,
    )

    @Test fun `normal completion maps every draft field and repairs projection then widget`() = runTest {
        val repository = FakeRepository()
        val projection = FakeProjection()
        val widget = FakeWidgetGateway()
        val useCase = useCase(repository, projection = projection, widget = widget)

        val attempt = useCase.prepare(draft, PhraseTone.FIRM)
        val result = useCase.commit(attempt)

        assertTrue(result is CompletionResult.Success)
        assertEquals(1, repository.events.size)
        assertEquals(draft.sessionId, repository.events.values.single().id)
        assertEquals(draft.startedAt, repository.events.values.single().startedAtUtc)
        assertEquals(draft.completedAt.instant, repository.events.values.single().completedAtUtc)
        assertEquals(LocalDate.parse("2026-09-06"), repository.events.values.single().eventLocalDate)
        assertEquals(540, repository.events.values.single().timezoneOffsetMinutes)
        assertEquals(draft.intensity.durationMillis, repository.events.values.single().animationDurationMs)
        assertEquals(EntrySource.WIDGET, repository.events.values.single().source)
        assertEquals("2026-09-06", projection.requestedDate)
        assertEquals(1, widget.updates)
    }

    @Test fun `duplicate and repeated callback leave exactly one event`() = runTest {
        val repository = FakeRepository()
        val useCase = useCase(repository)
        val attempt = useCase.prepare(draft, PhraseTone.AUTOMATIC)

        assertTrue(useCase.commit(attempt) is CompletionResult.Success)
        assertTrue(useCase.commit(attempt) is CompletionResult.Success)
        assertEquals(1, repository.events.size)
    }

    @Test fun `database failure retries same immutable attempt and uuid`() = runTest {
        val repository = FakeRepository(failInsert = true)
        val useCase = useCase(repository)
        val attempt = useCase.prepare(draft, PhraseTone.AUTOMATIC)

        assertTrue(useCase.commit(attempt) is CompletionResult.CommitFailed)
        assertEquals(0, repository.events.size)
        repository.failInsert = false
        assertTrue(useCase.commit(attempt) is CompletionResult.Success)
        assertEquals(draft.sessionId, repository.events.values.single().id)
        assertEquals(listOf(attempt.event, attempt.event), repository.seen)
    }

    @Test fun `projection and widget failures do not roll back database success`() = runTest {
        val repository = FakeRepository()
        val projection = FakeProjection(fail = true)
        val widget = FakeWidgetGateway(fail = true)
        val result = useCase(repository, projection, widget).commit(
            useCase(repository, projection, widget).prepare(draft, PhraseTone.AUTOMATIC),
        ) as CompletionResult.Success

        assertEquals(1, repository.events.size)
        assertTrue(result.pendingRepairs.contains(CompletionRepair.PROJECTION))
        assertTrue(result.pendingRepairs.contains(CompletionRepair.WIDGET))
    }

    @Test fun `ineligible recent pool uses reviewed fallback`() = runTest {
        val repository = FakeRepository()
        val attempt = useCase(repository, phraseIndex = CompletionPhraseIndex(emptyList()))
            .prepare(draft.copy(intensity = intensity(1)), PhraseTone.FIRM)
        assertEquals(SafePhraseCatalog.fallback.id, attempt.event.phraseId)
    }

    @Test fun `recent history failure freezes safe fallback and does not insert until retry`() = runTest {
        val repository = FakeRepository(failLatest = true)
        val useCase = useCase(repository)

        val failure = runCatching { useCase.prepare(draft, PhraseTone.AUTOMATIC) }
            .exceptionOrNull() as CompletionPreparationFailed

        assertEquals(0, repository.events.size)
        assertEquals(SafePhraseCatalog.fallback.id, failure.attempt.event.phraseId)
        repository.failLatest = false
        assertTrue(useCase.commit(failure.attempt) is CompletionResult.Success)
        assertEquals(1, repository.events.size)
    }

    @Test fun `resolver failure freezes fallback attempt and retry reuses every draft field`() = runTest {
        val previous = draft.copy(sessionId = UUID.fromString("00000000-0000-0000-0000-000000000099"))
        val repository = FakeRepository().apply {
            events[previous.sessionId] = storedEvent(previous, SafePhraseCatalog.fallback.id)
        }
        val useCase = useCase(repository, phraseResolver = { error("injected resolver failure") })

        val failure = runCatching { useCase.prepare(draft, PhraseTone.FIRM) }
            .exceptionOrNull() as CompletionPreparationFailed

        assertEquals(draft, failure.attempt.draft)
        assertEquals(draft.sessionId, failure.attempt.event.id)
        assertEquals(SafePhraseCatalog.fallback.id, failure.attempt.event.phraseId)
        assertTrue(useCase.commit(failure.attempt) is CompletionResult.Success)
        assertSame(failure.attempt.event, repository.seen.single())
    }

    @Test fun `custom phrase pool failure freezes fallback attempt and retry reuses same event`() = runTest {
        val repository = FakeRepository()
        val useCase = useCase(repository, phrasePool = { error("injected pool failure") })

        val failure = runCatching { useCase.prepare(draft, PhraseTone.AUTOMATIC) }
            .exceptionOrNull() as CompletionPreparationFailed

        assertEquals(draft, failure.attempt.draft)
        assertEquals(SafePhraseCatalog.fallback.id, failure.attempt.event.phraseId)
        assertTrue(useCase.commit(failure.attempt) is CompletionResult.Success)
        assertEquals(listOf(failure.attempt.event), repository.seen)
    }

    private fun useCase(
        repository: FakeRepository,
        projection: FakeProjection = FakeProjection(),
        widget: FakeWidgetGateway = FakeWidgetGateway(),
        phraseIndex: CompletionPhraseIndex = CompletionPhraseIndex(SafePhraseCatalog.phrases),
        phrasePool: (suspend (Intensity) -> List<com.maeumjaro.app.core.Phrase>)? = null,
        phraseResolver: suspend (com.maeumjaro.app.core.PhraseId) -> com.maeumjaro.app.core.Phrase = {
            SafePhraseCatalog.resolve(it)
        },
    ) = CompleteInjectionUseCase(
        repository = repository,
        projectionReconciler = projection,
        widgetGateway = widget,
        clock = Clock.fixed(instant, ZoneOffset.UTC),
        appVersion = "0.1.0-test",
        phraseIndex = phraseIndex,
        phrasePool = phrasePool,
        phraseResolver = phraseResolver,
        randomIndex = { 0 },
    )

    private fun storedEvent(draft: InjectionEventDraft, phraseId: com.maeumjaro.app.core.PhraseId) = StoredInjectionEvent(
        id = draft.sessionId,
        startedAtUtc = draft.startedAt,
        completedAtUtc = draft.completedAt.instant,
        eventLocalDate = draft.completedAt.localDate,
        timezoneOffsetMinutes = draft.completedAt.offsetSeconds / 60,
        intensity = draft.intensity,
        source = draft.source,
        phraseId = phraseId,
        animationDurationMs = draft.intensity.durationMillis,
        interruptionCount = draft.interruptionCount,
        appVersion = "previous",
        createdAtUtc = instant,
    )

    private class FakeRepository(
        var failInsert: Boolean = false,
        var failLatest: Boolean = false,
    ) : InjectionEventRepository {
        val events = linkedMapOf<UUID, StoredInjectionEvent>()
        val seen = mutableListOf<StoredInjectionEvent>()
        override suspend fun insertCompletedEvent(event: StoredInjectionEvent): EventInsertResult {
            seen += event
            if (failInsert) throw IllegalStateException("injected database failure")
            return if (events.putIfAbsent(event.id, event) == null) EventInsertResult.Inserted else EventInsertResult.AlreadyExists
        }
        override suspend fun totalsForStoredDate(date: LocalDate) = DailyTotals(date, events.values.count { it.eventLocalDate == date }, events.values.filter { it.eventLocalDate == date }.sumOf { it.intensity.value })
        override suspend fun latest(limit: Int): List<StoredInjectionEvent> {
            if (failLatest) error("injected latest failure")
            return events.values.sortedByDescending { it.completedAtUtc }.take(limit)
        }
        override suspend fun eventsInStoredDateRange(range: StoredDateRange) = events.values.filter { it.eventLocalDate in range.first..range.lastInclusive }
        override suspend fun dailyAggregates(range: StoredDateRange): List<DailyAggregate> = emptyList()
        override suspend fun sixteenWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> = emptyList()
        override suspend fun fiftyTwoWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> = emptyList()
        override suspend fun event(id: UUID) = events[id]
        override suspend fun chronologicalExport() = events.values.toList()
        override suspend fun editIntensity(id: UUID, intensity: Intensity) = EditResult.Missing
        override suspend fun deleteEvent(id: UUID, decision: DeletionDecision) = DeleteResult.Canceled
        override suspend fun deleteEvents(ids: Set<UUID>, decision: DeletionDecision) = DeleteResult.Canceled
    }

    private class FakeProjection(var fail: Boolean = false) : WidgetProjectionReconcilerGateway {
        var requestedDate: String? = null
        override suspend fun reconcile(trigger: ReconcileTrigger, updatedAtEpochMillis: Long): ReconciliationResult =
            if (fail) ReconciliationResult.Failure(trigger, IllegalStateException("projection"))
            else ReconciliationResult.Success(trigger, WidgetProjection.getDefaultInstance())

        override suspend fun reconcileForDate(
            trigger: ReconcileTrigger,
            updatedAtEpochMillis: Long,
            localDate: String,
        ): ReconciliationResult {
            requestedDate = localDate
            return reconcile(trigger, updatedAtEpochMillis)
        }
    }

    private class FakeWidgetGateway(var fail: Boolean = false) : CompletionWidgetGateway {
        var updates = 0
        override suspend fun updateAll() { updates++; if (fail) error("widget") }
    }

    private fun intensity(value: Int) = checkNotNull(Intensity.from(value))
}
