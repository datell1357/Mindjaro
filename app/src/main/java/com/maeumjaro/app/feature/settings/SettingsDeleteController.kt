package com.maeumjaro.app.feature.settings

import com.maeumjaro.app.data.local.DeletionDecision
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.settings.ReconcileTrigger
import com.maeumjaro.app.data.settings.ReconciliationResult
import com.maeumjaro.app.data.settings.WidgetProjectionReconcilerGateway
import com.maeumjaro.app.feature.completion.CompletionRepair
import com.maeumjaro.app.feature.completion.CompletionRepairTracker
import com.maeumjaro.app.feature.completion.CompletionWidgetGateway
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

sealed interface SettingsDeleteResult {
    data object DatabaseFailure : SettingsDeleteResult
    data object Deleted : SettingsDeleteResult
    data object ProjectionPending : SettingsDeleteResult
}

sealed interface SettingsOperationResult {
    data object Success : SettingsOperationResult
    data object Failure : SettingsOperationResult
}

class SettingsDeleteController(
    private val repository: InjectionEventRepository,
    private val projectionReconciler: WidgetProjectionReconcilerGateway,
    private val widgetGateway: CompletionWidgetGateway,
    private val repairTracker: CompletionRepairTracker,
    private val now: () -> Long,
) {
    suspend fun deleteAll(): SettingsDeleteResult {
        try {
            repository.deleteAllEvents(DeletionDecision.Confirmed)
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            return SettingsDeleteResult.DatabaseFailure
        }
        val pending = mutableSetOf<CompletionRepair>()
        try {
            when (projectionReconciler.reconcile(ReconcileTrigger.BULK_DELETE, now())) {
                is ReconciliationResult.Success -> Unit
                is ReconciliationResult.Failure -> pending += CompletionRepair.PROJECTION
            }
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            pending += CompletionRepair.PROJECTION
        }
        try {
            widgetGateway.updateAll()
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            pending += CompletionRepair.WIDGET
        }
        if (pending.isNotEmpty()) repairTracker.recordPending(pending)
        return if (pending.isEmpty()) SettingsDeleteResult.Deleted else SettingsDeleteResult.ProjectionPending
    }
}

class SettingsOperationController(
    private val projectionReconciler: WidgetProjectionReconcilerGateway,
    private val widgetGateway: CompletionWidgetGateway,
    private val repairTracker: CompletionRepairTracker,
    private val now: () -> Long,
) {
    suspend fun intensityChanged(save: suspend () -> Unit): SettingsOperationResult {
        try {
            save()
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            return SettingsOperationResult.Failure
        }
        val pending = mutableSetOf<CompletionRepair>()
        try {
            when (projectionReconciler.reconcile(ReconcileTrigger.INDIVIDUAL_EDIT, now())) {
                is ReconciliationResult.Success -> Unit
                is ReconciliationResult.Failure -> pending += CompletionRepair.PROJECTION
            }
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            pending += CompletionRepair.PROJECTION
        }
        try {
            widgetGateway.updateAll()
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            pending += CompletionRepair.WIDGET
        }
        if (pending.isNotEmpty()) {
            repairTracker.recordPending(pending)
            return SettingsOperationResult.Failure
        }
        return SettingsOperationResult.Success
    }
}

sealed interface SettingsExportResult {
    data object Success : SettingsExportResult
    data object Failure : SettingsExportResult
}

class SettingsExportController(
    private val prepare: suspend () -> java.io.File,
    private val share: (java.io.File) -> Unit,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val mainDispatcher: CoroutineDispatcher = Dispatchers.Main.immediate,
) {
    suspend fun export(): SettingsExportResult = try {
        val file = withContext(ioDispatcher) { prepare() }
        withContext(mainDispatcher) { share(file) }
        SettingsExportResult.Success
    } catch (cancellation: CancellationException) {
        throw cancellation
    } catch (_: Exception) {
        SettingsExportResult.Failure
    }
}
