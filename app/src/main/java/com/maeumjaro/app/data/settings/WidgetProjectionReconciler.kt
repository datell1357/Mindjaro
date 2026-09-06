package com.maeumjaro.app.data.settings

import kotlinx.coroutines.CancellationException

fun interface TodayTotalsAuthority {
    suspend fun totalsFor(localDate: String): TodayTotals
}

fun interface LocalDateSource {
    fun currentDate(): String
}

data class TodayTotals(val count: Int, val intensitySum: Int) {
    init {
        require(count >= 0)
        require(intensitySum >= 0)
    }
}

enum class ReconcileTrigger {
    COMPLETION,
    INDIVIDUAL_EDIT,
    INDIVIDUAL_DELETE,
    BULK_DELETE,
    STARTUP,
    FOREGROUND,
    DATE_ROLLOVER,
}

sealed interface ReconciliationResult {
    data class Success(val trigger: ReconcileTrigger, val projection: WidgetProjection) : ReconciliationResult
    data class Failure(val trigger: ReconcileTrigger, val cause: Exception) : ReconciliationResult
}

data class WidgetSnapshot(val intensity: Int, val count: Int, val intensitySum: Int) {
    companion object {
        fun from(state: AppState, localDate: String): WidgetSnapshot {
            val normalized = AppStatePolicy.normalize(state)
            val projection = normalized.widgetProjection
            return if (projection.localDate == localDate) {
                WidgetSnapshot(normalized.intensity, projection.count, projection.intensitySum)
            } else {
                WidgetSnapshot(normalized.intensity, 0, 0)
            }
        }
    }
}

interface WidgetProjectionReconcilerGateway {
    suspend fun reconcile(trigger: ReconcileTrigger, updatedAtEpochMillis: Long): ReconciliationResult

    suspend fun reconcileForDate(
        trigger: ReconcileTrigger,
        updatedAtEpochMillis: Long,
        localDate: String,
    ): ReconciliationResult = reconcile(trigger, updatedAtEpochMillis)
}

class WidgetProjectionReconciler(
    private val authority: TodayTotalsAuthority,
    private val stateGateway: AppStateGateway,
    private val localDateSource: LocalDateSource,
) : WidgetProjectionReconcilerGateway {
    override suspend fun reconcile(trigger: ReconcileTrigger, updatedAtEpochMillis: Long): ReconciliationResult =
        reconcileAt(trigger, updatedAtEpochMillis, localDateSource.currentDate())

    override suspend fun reconcileForDate(
        trigger: ReconcileTrigger,
        updatedAtEpochMillis: Long,
        localDate: String,
    ): ReconciliationResult = reconcileAt(trigger, updatedAtEpochMillis, localDate)

    private suspend fun reconcileAt(
        trigger: ReconcileTrigger,
        updatedAtEpochMillis: Long,
        localDate: String,
    ): ReconciliationResult = try {
        require(updatedAtEpochMillis >= 0)
        val totals = authority.totalsFor(localDate)
        val updated = stateGateway.update { current ->
            current.toBuilder().setWidgetProjection(
                WidgetProjection.newBuilder()
                    .setLocalDate(localDate)
                    .setCount(totals.count)
                    .setIntensitySum(totals.intensitySum)
                    .setUpdatedAtEpochMillis(updatedAtEpochMillis),
            ).build()
        }
        ReconciliationResult.Success(trigger, updated.widgetProjection)
    } catch (cancellation: CancellationException) {
        throw cancellation
    } catch (error: Exception) {
        ReconciliationResult.Failure(trigger, error)
    }
}
