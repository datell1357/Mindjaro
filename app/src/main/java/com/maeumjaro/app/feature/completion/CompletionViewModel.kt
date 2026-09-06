package com.maeumjaro.app.feature.completion

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.PhraseTone
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CompletionViewModel(
    private val useCase: CompleteInjectionUseCase,
) : ViewModel() {
    private val mutableState = MutableStateFlow<CompletionUiState>(CompletionUiState.Idle)
    val state: StateFlow<CompletionUiState> = mutableState.asStateFlow()

    fun begin(draft: InjectionEventDraft, preferredTone: PhraseTone) {
        if (mutableState.value !is CompletionUiState.Idle) return
        viewModelScope.launch {
            try {
                val attempt = useCase.prepare(draft, preferredTone)
                mutableState.value = CompletionUiState.Committing(attempt)
                commit(attempt)
            } catch (failure: CompletionPreparationFailed) {
                mutableState.value = CompletionUiState.Failed(failure.attempt)
            }
        }
    }

    fun retry() {
        val failed = mutableState.value as? CompletionUiState.Failed ?: return
        mutableState.value = CompletionUiState.Committing(failed.attempt)
        viewModelScope.launch { commit(failed.attempt) }
    }

    fun reset() {
        if (mutableState.value !is CompletionUiState.Committing) mutableState.value = CompletionUiState.Idle
    }

    private suspend fun commit(attempt: CompletionAttempt) {
        mutableState.value = CompletionUiState.Committing(attempt)
        mutableState.value = when (val result = useCase.commit(attempt)) {
            is CompletionResult.Success -> CompletionUiState.Completed(result)
            is CompletionResult.CommitFailed -> CompletionUiState.Failed(result.attempt)
        }
    }
}
