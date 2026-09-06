package com.maeumjaro.app.data.settings

import android.content.Context
import androidx.datastore.core.DataStoreFactory
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import java.util.UUID
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ProjectionTraceInstrumentedTest {
    @Test
    fun foregroundReconciliationRepairsStaleProjectionAndPreservesSettings() = runBlocking {
        // Given: a real proto file with invalid intensity, yesterday's totals, and durable settings.
        val context = ApplicationProvider.getApplicationContext<Context>()
        val stateFile = File(context.filesDir, "task-4-${UUID.randomUUID()}.pb")
        stateFile.outputStream().use { output -> staleState().writeTo(output) }
        val store = AppStateStore(
            DataStoreFactory.create(
                serializer = AppStateSerializer,
                corruptionHandler = ReplaceFileCorruptionHandler { AppStateSerializer.defaultValue },
                produceFile = { stateFile },
            ),
        )
        val beforeState = store.state.first()
        val before = WidgetSnapshot.from(beforeState, TODAY)
        val reconciler = WidgetProjectionReconciler(
            TodayTotalsAuthority { TodayTotals(AUTHORITY_COUNT, AUTHORITY_SUM) },
            store,
            LocalDateSource { TODAY },
        )

        // When: record deletion and foreground reconciliation ask the narrow authority for today's totals.
        val deletionResult = reconciler.reconcile(ReconcileTrigger.BULK_DELETE, UPDATED_AT - 1)
        val result = reconciler.reconcile(ReconcileTrigger.FOREGROUND, UPDATED_AT)
        val afterState = store.state.first()
        val after = WidgetSnapshot.from(afterState, TODAY)

        // Then: stale output is zero before repair and exact authority values after, without state loss.
        assertTrue(deletionResult is ReconciliationResult.Success)
        assertTrue(result is ReconciliationResult.Success)
        assertEquals(0, before.count)
        assertEquals(0, before.intensitySum)
        assertEquals(3, before.intensity)
        assertEquals(AUTHORITY_COUNT, after.count)
        assertEquals(AUTHORITY_SUM, after.intensitySum)
        assertEquals(true, afterState.onboardingCompleted)
        assertEquals(false, afterState.hapticEnabled)
        assertEquals(EntitlementStatus.ENTITLEMENT_STATUS_PRO, afterState.entitlementCache.status)
        File(context.filesDir, "projection-trace.json").writeText(
            trace(TraceInput(before, after, afterState, deletionResult)),
        )
    }

    private fun staleState(): AppState = AppState.newBuilder()
        .setIntensity(8)
        .setHapticEnabled(false)
        .setOnboardingCompleted(true)
        .setEntitlementCache(
            EntitlementCache.newBuilder()
                .setStatus(EntitlementStatus.ENTITLEMENT_STATUS_PRO)
                .setProductId("maeumjaro_pro")
                .setLastVerifiedAtEpochMillis(70L),
        )
        .setWidgetProjection(
            WidgetProjection.newBuilder()
                .setLocalDate("2026-09-03")
                .setCount(9)
                .setIntensitySum(31)
                .setUpdatedAtEpochMillis(60L),
        )
        .build()

    private fun trace(input: TraceInput): String = JSONObject()
        .put("scenario", "stale-before-foreground-rebuild")
        .put("beforeLocalDate", "2026-09-03")
        .put("today", TODAY)
        .put("zeroBeforeRebuild", input.before.count == 0 && input.before.intensitySum == 0)
        .put("normalizedIntensityBeforeRebuild", input.before.intensity)
        .put("authorityCount", AUTHORITY_COUNT)
        .put("authorityIntensitySum", AUTHORITY_SUM)
        .put("afterCount", input.after.count)
        .put("afterIntensitySum", input.after.intensitySum)
        .put("deletionReconciliationSucceeded", input.deletionResult is ReconciliationResult.Success)
        .put("settingsPreserved", input.state.onboardingCompleted && !input.state.hapticEnabled)
        .put("entitlementPreserved", input.state.entitlementCache.status == EntitlementStatus.ENTITLEMENT_STATUS_PRO)
        .toString(2)

    private data class TraceInput(
        val before: WidgetSnapshot,
        val after: WidgetSnapshot,
        val state: AppState,
        val deletionResult: ReconciliationResult,
    )

    private companion object {
        const val TODAY = "2026-09-04"
        const val AUTHORITY_COUNT = 2
        const val AUTHORITY_SUM = 8
        const val UPDATED_AT = 100L
    }
}
