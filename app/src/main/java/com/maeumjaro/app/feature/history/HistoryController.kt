package com.maeumjaro.app.feature.history

import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.data.local.DeleteResult
import com.maeumjaro.app.data.local.DeletionDecision
import com.maeumjaro.app.data.local.EditResult
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.local.StoredDateRange
import com.maeumjaro.app.feature.analytics.AnalyticsPeriod
import com.maeumjaro.app.feature.analytics.DebugEntitlementRepository
import com.maeumjaro.app.feature.analytics.Entitlement
import com.maeumjaro.app.feature.analytics.EntitlementRepository
import com.maeumjaro.app.feature.customization.CustomPhraseResolver
import com.maeumjaro.app.feature.customization.InMemoryCustomPhraseRepository
import java.time.Clock
import java.time.LocalDate
import java.util.UUID
import kotlinx.coroutines.CancellationException

/** Integration-ready history API. Room remains authoritative; this class retains no view-state cache. */
class HistoryController(
    private val repository: InjectionEventRepository,
    private val clock: Clock,
    private val mutationObserver: HistoryMutationObserver = HistoryMutationObserver.None,
    private val entitlements: EntitlementRepository = DebugEntitlementRepository(),
    private val phraseResolver: CustomPhraseResolver = CustomPhraseResolver(InMemoryCustomPhraseRepository()),
) {
    suspend fun dashboard(): HistoryDashboardState {
        val entitlement = entitlements.current()
        return dashboard(entitlement)
    }

    /** Builds a snapshot for the entitlement observed by the canonical billing flow. */
    suspend fun dashboard(entitlement: Entitlement): HistoryDashboardState {
        val today = LocalDate.now(clock)
        val period = AnalyticsPeriod.forPlan(entitlement, today)
        val heatmapStart = period.viewportStart
        val historyStart = period.start
        return HistoryStateBuilder.build(
            today = today,
            aggregates = repository.dailyAggregates(StoredDateRange(heatmapStart, period.end)),
            latest = repository.latest(10),
            lastThirtyDays = repository.eventsInStoredDateRange(StoredDateRange(historyStart, today)),
            historyWindowStart = historyStart,
            heatmapWeeks = if (entitlement == Entitlement.PRO) 52 else 16,
            entitlement = entitlement,
        )
    }

    suspend fun day(date: LocalDate): DayDetailState =
        HistoryStateBuilder.dayDetail(date, repository.eventsInStoredDateRange(StoredDateRange(date, date)))

    suspend fun record(id: UUID): RecordDetailState? = repository.event(id)?.let { event ->
        HistoryStateBuilder.recordDetail(event, phraseResolver.resolve(event.phraseId))
    }

    suspend fun correctIntensity(id: UUID, rawIntensity: Int): HistoryMutationResult {
        val intensity = Intensity.from(rawIntensity) ?: return HistoryMutationResult.InvalidIntensity(dashboard())
        return when (repository.editIntensity(id, intensity)) {
            EditResult.Updated -> {
                val projectionSynchronized = notifyMutationObserver()
                val dashboard = dashboard()
                if (projectionSynchronized) HistoryMutationResult.Applied(dashboard)
                else HistoryMutationResult.ProjectionPending(dashboard)
            }
            EditResult.Missing -> HistoryMutationResult.NotFound(dashboard())
        }
    }

    suspend fun delete(id: UUID, confirmed: Boolean): HistoryMutationResult {
        val decision = if (confirmed) DeletionDecision.Confirmed else DeletionDecision.Canceled
        return when (val result = repository.deleteEvent(id, decision)) {
            DeleteResult.Canceled -> HistoryMutationResult.Canceled(dashboard())
            is DeleteResult.Deleted -> if (result.count > 0) {
                val projectionSynchronized = notifyMutationObserver()
                val dashboard = dashboard()
                if (projectionSynchronized) HistoryMutationResult.Applied(dashboard)
                else HistoryMutationResult.ProjectionPending(dashboard)
            } else {
                HistoryMutationResult.NotFound(dashboard())
            }
        }
    }

    private suspend fun notifyMutationObserver(): Boolean =
        try {
            mutationObserver.recordsChanged()
            true
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            // Room already contains the factual change. A projection/integration layer can reconcile later.
            false
        }
}
