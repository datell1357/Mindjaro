package com.maeumjaro.app.feature.completion

import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.data.local.EventInsertResult
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.data.settings.ReconcileTrigger
import com.maeumjaro.app.data.settings.ReconciliationResult
import com.maeumjaro.app.data.settings.WidgetProjectionReconcilerGateway
import java.time.Clock
import kotlinx.coroutines.CancellationException
import kotlin.random.Random

fun interface CompletionWidgetGateway {
    suspend fun updateAll()

    companion object {
        val None = CompletionWidgetGateway { }
    }
}

class CompletionPhraseIndex(private val phrases: List<Phrase>) {
    val allPhrases: List<Phrase> get() = phrases
    fun choose(
        draft: InjectionEventDraft,
        preferredTone: PhraseTone,
        recentIds: List<PhraseId>,
        previousCategory: PhraseCategory?,
        randomIndex: (Int) -> Int,
    ): Phrase {
        val recent = recentIds.take(10).toSet()
        val eligible = phrases.filter { phrase ->
            phrase.safetyReviewed &&
                draft.intensity in phrase.intensities &&
                phrase.id !in recent &&
                phrase.category != previousCategory
        }
        if (eligible.isEmpty()) return SafePhraseCatalog.fallback
        val tonePreferred = if (preferredTone == PhraseTone.AUTOMATIC) eligible else eligible.filter { it.tone == preferredTone }
        val candidates = tonePreferred.ifEmpty { eligible }
        return candidates[randomIndex(candidates.size).mod(candidates.size)]
    }
}

class CompleteInjectionUseCase(
    private val repository: InjectionEventRepository,
    private val projectionReconciler: WidgetProjectionReconcilerGateway,
    private val widgetGateway: CompletionWidgetGateway,
    private val clock: Clock,
    private val appVersion: String,
    private val phraseIndex: CompletionPhraseIndex = CompletionPhraseIndex(SafePhraseCatalog.phrases),
    private val phrasePool: (suspend (Intensity) -> List<Phrase>)? = null,
    private val phraseResolver: suspend (PhraseId) -> Phrase = { SafePhraseCatalog.resolve(it) },
    private val randomIndex: (Int) -> Int = { Random.Default.nextInt(it) },
    private val diagnosticSink: CompletionDiagnosticSink = CompletionDiagnosticSink.None,
) {
    suspend fun prepare(draft: InjectionEventDraft, preferredTone: PhraseTone): CompletionAttempt {
        return try {
            prepareAttempt(draft, preferredTone)
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (failure: CompletionPreparationFailed) {
            throw failure
        } catch (error: Exception) {
            throw CompletionPreparationFailed(attempt(draft, SafePhraseCatalog.fallback), error)
        }
    }

    private suspend fun prepareAttempt(
        draft: InjectionEventDraft,
        preferredTone: PhraseTone,
    ): CompletionAttempt {
        val recent = try {
            repository.latest(10)
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Exception) {
            val attempt = attempt(draft, SafePhraseCatalog.fallback)
            throw CompletionPreparationFailed(attempt, error)
        }
        val previousCategory = recent.firstOrNull()?.phraseId?.let { phraseResolver(it).category }
        val phrase = CompletionPhraseIndex(phrasePool?.invoke(draft.intensity) ?: phraseIndexPhrases()).choose(
            draft = draft,
            preferredTone = preferredTone,
            recentIds = recent.map { it.phraseId },
            previousCategory = previousCategory,
            randomIndex = randomIndex,
        )
        return attempt(draft, phrase)
    }

    private fun phraseIndexPhrases(): List<Phrase> = phraseIndex.allPhrases

    private fun attempt(draft: InjectionEventDraft, phrase: Phrase): CompletionAttempt {
        val event = StoredInjectionEvent(
            id = draft.sessionId,
            startedAtUtc = draft.startedAt,
            completedAtUtc = draft.completedAt.instant,
            eventLocalDate = draft.completedAt.localDate,
            timezoneOffsetMinutes = draft.completedAt.offsetSeconds / 60,
            intensity = draft.intensity,
            source = draft.source,
            phraseId = phrase.id,
            animationDurationMs = draft.intensity.durationMillis,
            interruptionCount = draft.interruptionCount,
            appVersion = appVersion,
            createdAtUtc = clock.instant(),
        )
        return CompletionAttempt(draft, phrase, event)
    }

    suspend fun commit(attempt: CompletionAttempt): CompletionResult {
        val insertResult = try {
            repository.insertCompletedEvent(attempt.event)
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Exception) {
            return CompletionResult.CommitFailed(attempt, error)
        }

        val repairs = buildSet {
            val projectionFailed = try {
                projectionReconciler.reconcileForDate(
                    ReconcileTrigger.COMPLETION,
                    attempt.event.completedAtUtc.toEpochMilli(),
                    attempt.event.eventLocalDate.toString(),
                ) is ReconciliationResult.Failure
            } catch (cancellation: CancellationException) {
                throw cancellation
            } catch (_: Exception) {
                true
            }
            if (projectionFailed) add(CompletionRepair.PROJECTION)
            try {
                widgetGateway.updateAll()
            } catch (cancellation: CancellationException) {
                throw cancellation
            } catch (_: Exception) {
                add(CompletionRepair.WIDGET)
            }
        }
        diagnosticSink.recordPending(repairs)
        return CompletionResult.Success(attempt, insertResult, repairs)
    }
}
