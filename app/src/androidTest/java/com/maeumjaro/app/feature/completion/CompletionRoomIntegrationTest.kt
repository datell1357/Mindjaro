package com.maeumjaro.app.feature.completion

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.EventTime
import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.data.local.EventInsertResult
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.local.MaeumjaroDatabase
import com.maeumjaro.app.data.local.RoomInjectionEventRepository
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
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CompletionRoomIntegrationTest {
    private lateinit var database: MaeumjaroDatabase
    private lateinit var roomRepository: RoomInjectionEventRepository
    private val now = Instant.parse("2026-09-05T15:00:01Z")

    @Before fun createDatabase() {
        database = MaeumjaroDatabase.inMemory(ApplicationProvider.getApplicationContext<Context>())
        roomRepository = RoomInjectionEventRepository(database)
    }

    @After fun closeDatabase() = database.close()

    @Test fun appAndWidgetDraftsPersistEveryFieldExactlyOnceAcrossRepeatedCallbacks() = runBlocking {
        assertEquals(0, database.injectionEventDao().rowCount())
        listOf(EntrySource.APP, EntrySource.WIDGET).forEachIndexed { index, source ->
            val draft = draft(index, source)
            val useCase = useCase(roomRepository)
            val attempt = useCase.prepare(draft, PhraseTone.AUTOMATIC)
            assertTrue(useCase.commit(attempt) is CompletionResult.Success)
            val duplicate = useCase.commit(attempt) as CompletionResult.Success
            assertEquals(EventInsertResult.AlreadyExists, duplicate.insertResult)

            val stored = requireNotNull(roomRepository.event(draft.sessionId))
            assertEquals(draft.sessionId, stored.id)
            assertEquals(draft.startedAt, stored.startedAtUtc)
            assertEquals(draft.completedAt.instant, stored.completedAtUtc)
            assertEquals(draft.completedAt.localDate, stored.eventLocalDate)
            assertEquals(draft.completedAt.offsetSeconds / 60, stored.timezoneOffsetMinutes)
            assertEquals(draft.intensity, stored.intensity)
            assertEquals(source, stored.source)
            assertEquals(attempt.phrase.id, stored.phraseId)
            assertEquals(draft.intensity.durationMillis, stored.animationDurationMs)
            assertEquals(draft.interruptionCount, stored.interruptionCount)
            assertEquals("integration-test", stored.appVersion)
            assertEquals(now, stored.createdAtUtc)
        }
        assertEquals(2, database.injectionEventDao().rowCount())
    }

    @Test fun failedInsertThenRepeatedRetryKeepsFrozenEventAndCreatesOneRow() = runBlocking {
        val failing = FailFirstRepository(roomRepository)
        val useCase = useCase(failing)
        val attempt = useCase.prepare(draft(7, EntrySource.APP), PhraseTone.AUTOMATIC)

        assertTrue(useCase.commit(attempt) is CompletionResult.CommitFailed)
        assertEquals(0, database.injectionEventDao().rowCount())
        assertTrue(useCase.commit(attempt) is CompletionResult.Success)
        assertTrue(useCase.commit(attempt) is CompletionResult.Success)

        assertEquals(1, database.injectionEventDao().rowCount())
        assertEquals(listOf(attempt.event, attempt.event, attempt.event), failing.seen)
    }

    private fun useCase(repository: InjectionEventRepository) = CompleteInjectionUseCase(
        repository = repository,
        projectionReconciler = object : WidgetProjectionReconcilerGateway {
            override suspend fun reconcile(trigger: ReconcileTrigger, updatedAtEpochMillis: Long) =
                ReconciliationResult.Success(trigger, WidgetProjection.getDefaultInstance())
        },
        widgetGateway = CompletionWidgetGateway.None,
        clock = Clock.fixed(now, ZoneOffset.UTC),
        appVersion = "integration-test",
        phraseIndex = CompletionPhraseIndex(
            listOf(
                Phrase(
                    PhraseId("completion-test"), "지금의 선택을 천천히 바라봐요.",
                    PhraseCategory.NONJUDGMENT, PhraseTone.NEUTRAL,
                    (1..5).mapNotNull(Intensity::from).toSet(), true,
                ),
            ),
        ),
        randomIndex = { 0 },
    )

    private fun draft(index: Int, source: EntrySource) = InjectionEventDraft(
        sessionId = UUID.nameUUIDFromBytes("completion-$index".toByteArray()),
        intensity = checkNotNull(Intensity.from(index.mod(5) + 1)),
        source = source,
        startedAt = now.minusSeconds(4),
        completedAt = EventTime.at(now.plusSeconds(index.toLong()), ZoneId.of("Asia/Seoul")),
        interruptionCount = index,
    )

    private class FailFirstRepository(
        private val delegate: InjectionEventRepository,
    ) : InjectionEventRepository by delegate {
        var shouldFail = true
        val seen = mutableListOf<StoredInjectionEvent>()

        override suspend fun insertCompletedEvent(event: StoredInjectionEvent): EventInsertResult {
            seen += event
            if (shouldFail) {
                shouldFail = false
                error("injected database failure")
            }
            return delegate.insertCompletedEvent(event)
        }
    }
}
