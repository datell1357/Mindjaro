package com.maeumjaro.app.feature.completion

import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.data.local.EventInsertResult
import com.maeumjaro.app.data.local.StoredInjectionEvent

data class CompletionAttempt(
    val draft: InjectionEventDraft,
    val phrase: Phrase,
    val event: StoredInjectionEvent,
)

class CompletionPreparationFailed(
    val attempt: CompletionAttempt,
    override val cause: Exception,
) : Exception(cause)

enum class CompletionRepair { PROJECTION, WIDGET }

fun interface CompletionDiagnosticSink {
    fun recordPending(repairs: Set<CompletionRepair>)

    companion object {
        val None = CompletionDiagnosticSink { }
    }
}

class CompletionRepairTracker : CompletionDiagnosticSink {
    @Volatile var pending: Set<CompletionRepair> = emptySet()
        private set

    override fun recordPending(repairs: Set<CompletionRepair>) {
        pending = repairs
    }
}

sealed interface CompletionResult {
    data class Success(
        val attempt: CompletionAttempt,
        val insertResult: EventInsertResult,
        val pendingRepairs: Set<CompletionRepair>,
    ) : CompletionResult

    data class CommitFailed(
        val attempt: CompletionAttempt,
        val cause: Exception,
    ) : CompletionResult
}

sealed interface CompletionUiState {
    data object Idle : CompletionUiState
    data class Committing(val attempt: CompletionAttempt) : CompletionUiState
    data class Failed(val attempt: CompletionAttempt) : CompletionUiState
    data class Completed(val result: CompletionResult.Success) : CompletionUiState
}
