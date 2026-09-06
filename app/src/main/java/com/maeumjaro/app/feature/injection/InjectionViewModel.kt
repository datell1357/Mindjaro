package com.maeumjaro.app.feature.injection

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.feature.completion.CompleteInjectionUseCase
import com.maeumjaro.app.feature.completion.CompletionResult
import com.maeumjaro.app.feature.completion.CompletionPreparationFailed
import com.maeumjaro.app.feature.completion.CompletionUiState
import java.time.Clock
import java.time.ZoneId
import java.util.UUID
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

class InjectionViewModel(
    initialIntensity: Intensity = requireNotNull(Intensity.from(3)),
    source: EntrySource = EntrySource.APP,
    clock: Clock = Clock.systemUTC(),
    zoneId: ZoneId = ZoneId.systemDefault(),
    sessionIdFactory: () -> UUID = UUID::randomUUID,
    reducedMotion: Boolean = false,
    hapticsEnabled: Boolean = true,
    soundEnabled: Boolean = false,
    private val completionUseCase: CompleteInjectionUseCase? = null,
    private val preferredTone: suspend () -> PhraseTone = { PhraseTone.AUTOMATIC },
) : ViewModel() {
    private val coordinator = InjectionCoordinator(
        initialIntensity, source, clock, zoneId, sessionIdFactory, reducedMotion, hapticsEnabled, soundEnabled,
    )
    private val mutableUiState = MutableStateFlow(coordinator.uiState)
    private val mutableCompletionDrafts = MutableSharedFlow<InjectionEventDraft>(extraBufferCapacity = 1)
    private val mutableFeedback = MutableSharedFlow<InjectionFeedback>(extraBufferCapacity = 8)
    private val mutableCompletionState = MutableStateFlow<CompletionUiState>(CompletionUiState.Idle)

    val uiState: StateFlow<InjectionUiState> = mutableUiState.asStateFlow()
    val completionDrafts: SharedFlow<InjectionEventDraft> = mutableCompletionDrafts.asSharedFlow()
    val feedback: SharedFlow<InjectionFeedback> = mutableFeedback.asSharedFlow()
    val completionState: StateFlow<CompletionUiState> = mutableCompletionState.asStateFlow()

    fun pointerDown(pointerId: Int, monotonicMillis: Long) = update { coordinator.pointerDown(pointerId, monotonicMillis) }
    fun pointerMoved(dx: Float, dy: Float, widthPx: Float) = update { coordinator.pointerMoved(dx, dy, widthPx) }
    fun pointerUp(pointerId: Int, monotonicMillis: Long) = update { coordinator.pointerUp(pointerId, monotonicMillis) }
    fun pointerCancelled(pointerId: Int, monotonicMillis: Long) = update { coordinator.pointerCancelled(pointerId, monotonicMillis) }
    fun frame(monotonicMillis: Long) = update { coordinator.frame(monotonicMillis) }
    fun backgrounded() = update { coordinator.backgrounded() }
    fun accessibilityStart(monotonicMillis: Long) = update { coordinator.accessibilityStart(monotonicMillis) }
    fun accessibilityPause(monotonicMillis: Long) = update { coordinator.accessibilityPause(monotonicMillis) }
    fun setIntensity(intensity: Intensity): Boolean {
        val accepted = coordinator.setIntensity(intensity)
        publish()
        return accepted
    }
    fun updatePreferences(reducedMotion: Boolean, hapticsEnabled: Boolean, soundEnabled: Boolean): Boolean {
        val accepted = coordinator.updatePreferences(reducedMotion, hapticsEnabled, soundEnabled)
        publish()
        return accepted
    }
    fun commitSucceeded(alreadyExisted: Boolean = false) = update { coordinator.commitSucceeded(alreadyExisted) }
    fun commitFailed() = update { coordinator.commitFailed() }
    fun retryCommit() = update { coordinator.retryCommit() }

    fun retryCompletion() {
        val failed = mutableCompletionState.value as? CompletionUiState.Failed ?: return
        coordinator.retryCommit()
        mutableCompletionState.value = CompletionUiState.Committing(failed.attempt)
        viewModelScope.launch { commit(failed.attempt) }
        publish()
    }

    fun resetCompletion() {
        if (mutableCompletionState.value !is CompletionUiState.Committing) {
            mutableCompletionState.value = CompletionUiState.Idle
        }
    }

    private inline fun update(action: () -> Unit) {
        action()
        publish()
    }

    private fun publish() {
        mutableUiState.value = coordinator.uiState
        coordinator.takeCompletionDraft()?.let { draft ->
            mutableCompletionDrafts.tryEmit(draft)
            if (completionUseCase != null && mutableCompletionState.value is CompletionUiState.Idle) {
                viewModelScope.launch {
                    val tone = try {
                        preferredTone()
                    } catch (cancellation: CancellationException) {
                        throw cancellation
                    } catch (_: Exception) {
                        PhraseTone.AUTOMATIC
                    }
                    try {
                        commit(completionUseCase.prepare(draft, tone))
                    } catch (failure: CompletionPreparationFailed) {
                        coordinator.commitFailed()
                        mutableCompletionState.value = CompletionUiState.Failed(failure.attempt)
                        publish()
                    }
                }
            }
        }
        while (true) mutableFeedback.tryEmit(coordinator.takeFeedback() ?: break)
    }

    private suspend fun commit(attempt: com.maeumjaro.app.feature.completion.CompletionAttempt) {
        val useCase = checkNotNull(completionUseCase)
        mutableCompletionState.value = CompletionUiState.Committing(attempt)
        when (val result = useCase.commit(attempt)) {
            is CompletionResult.Success -> {
                coordinator.commitSucceeded(result.insertResult == com.maeumjaro.app.data.local.EventInsertResult.AlreadyExists)
                mutableCompletionState.value = CompletionUiState.Completed(result)
            }
            is CompletionResult.CommitFailed -> {
                coordinator.commitFailed()
                mutableCompletionState.value = CompletionUiState.Failed(result.attempt)
            }
        }
        publish()
    }
}
