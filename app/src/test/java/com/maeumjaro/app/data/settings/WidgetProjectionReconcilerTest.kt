package com.maeumjaro.app.data.settings

import java.io.IOException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetProjectionReconcilerTest {
    @Test
    fun `renders zero when projection belongs to a different local date`() {
        // Given: yesterday's non-zero projection.
        val state = AppState.newBuilder().setIntensity(7).setWidgetProjection(
            WidgetProjection.newBuilder().setLocalDate("2026-09-03").setCount(4).setIntensitySum(17),
        ).build()

        // When: today's widget snapshot is derived without opening Room.
        val snapshot = WidgetSnapshot.from(state, "2026-09-04")

        // Then: stale totals are hidden and invalid intensity is neutral.
        assertEquals(0, snapshot.count)
        assertEquals(0, snapshot.intensitySum)
        assertEquals(3, snapshot.intensity)
    }

    @Test
    fun `rebuilds exact authoritative totals for every trigger`() = runTest {
        // Given: Room authority and a stale projection.
        val gateway = FakeGateway(staleState())
        val reconciler = WidgetProjectionReconciler(
            TodayTotalsAuthority { TodayTotals(6, 21) },
            gateway,
            LocalDateSource { "2026-09-04" },
        )

        // When: each required lifecycle or mutation trigger reconciles.
        val results = ReconcileTrigger.entries.map { reconciler.reconcile(it, 90L) }

        // Then: every trigger succeeds with the exact Room totals.
        assertTrue(results.all { it is ReconciliationResult.Success })
        assertEquals("2026-09-04", gateway.current.widgetProjection.localDate)
        assertEquals(6, gateway.current.widgetProjection.count)
        assertEquals(21, gateway.current.widgetProjection.intensitySum)
    }

    @Test
    fun `reports projection failure without changing durable settings`() = runTest {
        // Given: a completed DB operation followed by a failing projection store.
        val original = staleState().toBuilder()
            .setOnboardingCompleted(true)
            .setEntitlementCache(EntitlementCache.newBuilder().setStatus(EntitlementStatus.ENTITLEMENT_STATUS_PRO))
            .build()
        val gateway = FakeGateway(original, IOException("disk full"))
        val reconciler = WidgetProjectionReconciler(
            TodayTotalsAuthority { TodayTotals(0, 0) },
            gateway,
            LocalDateSource { "2026-09-04" },
        )

        // When: record deletion reconciliation cannot write its projection.
        val result = reconciler.reconcile(ReconcileTrigger.BULK_DELETE, 91L)

        // Then: failure is bounded and unrelated app state remains intact.
        assertTrue(result is ReconciliationResult.Failure)
        assertEquals(true, gateway.current.onboardingCompleted)
        assertEquals(EntitlementStatus.ENTITLEMENT_STATUS_PRO, gateway.current.entitlementCache.status)
    }

    @Test
    fun `bulk deletion rebuild changes only projection`() = runTest {
        // Given: retained settings and entitlement beside yesterday's records projection.
        val original = staleState().toBuilder()
            .setOnboardingCompleted(true)
            .setEntitlementCache(EntitlementCache.newBuilder().setStatus(EntitlementStatus.ENTITLEMENT_STATUS_PRO))
            .build()
        val gateway = FakeGateway(original)
        val reconciler = WidgetProjectionReconciler(
            TodayTotalsAuthority { TodayTotals(0, 0) },
            gateway,
            LocalDateSource { "2026-09-04" },
        )

        // When: successful event deletion reconciliation writes zero authoritative totals.
        reconciler.reconcile(ReconcileTrigger.BULK_DELETE, 92L)

        // Then: projection clears while settings, onboarding, and entitlement survive.
        assertEquals(0, gateway.current.widgetProjection.count)
        assertEquals(4, gateway.current.intensity)
        assertEquals(false, gateway.current.hapticEnabled)
        assertEquals(true, gateway.current.onboardingCompleted)
        assertEquals(EntitlementStatus.ENTITLEMENT_STATUS_PRO, gateway.current.entitlementCache.status)
    }

    private fun staleState(): AppState = AppState.newBuilder()
        .setIntensity(4)
        .setHapticEnabled(false)
        .setWidgetProjection(
            WidgetProjection.newBuilder().setLocalDate("2026-09-03").setCount(9).setIntensitySum(31),
        )
        .build()

    private class FakeGateway(initial: AppState, private val failure: IOException? = null) : AppStateGateway {
        private val mutableState = MutableStateFlow(initial)
        override val state: StateFlow<AppState> = mutableState
        val current: AppState get() = mutableState.value

        override suspend fun update(transform: suspend (AppState) -> AppState): AppState {
            failure?.let { throw it }
            return transform(current).also { mutableState.value = it }
        }
    }
}
