package com.maeumjaro.app.widget

import com.maeumjaro.app.data.settings.AppState
import com.maeumjaro.app.data.settings.AppStatePolicy
import com.maeumjaro.app.data.settings.WidgetProjection
import com.maeumjaro.app.billing.PRO_LIFETIME_PRODUCT_ID
import androidx.datastore.core.DataStoreFactory
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class WidgetStateTest {
    @Test
    fun `widget launch pipeline refreshes before activity launch`() = runTest {
        val events = mutableListOf<String>()
        WidgetLaunchPipeline(
            prepare = { events += "prepare" },
            refresh = { events += "refresh" },
            launch = { events += "launch" },
        ).run()
        assertEquals(listOf("prepare", "refresh", "launch"), events)
    }
    @get:Rule val temporaryFolder = TemporaryFolder()
    @Test fun `stale projection is zeroed while persisted intensity is retained`() {
        val state = AppState.newBuilder().setIntensity(5).setWidgetProjection(
            WidgetProjection.newBuilder().setLocalDate("2026-09-05").setCount(9).setIntensitySum(31),
        ).build()
        val snapshot = com.maeumjaro.app.data.settings.WidgetSnapshot.from(
            AppStatePolicy.normalize(state), "2026-09-06",
        )
        assertEquals(5, snapshot.intensity)
        assertEquals(0, snapshot.count)
        assertEquals(0, snapshot.intensitySum)
    }

    @Test fun `projection is exposed for current date`() {
        val state = AppState.newBuilder().setIntensity(2).setWidgetProjection(
            WidgetProjection.newBuilder().setLocalDate("2026-09-06").setCount(4).setIntensitySum(8),
        ).build()
        val snapshot = com.maeumjaro.app.data.settings.WidgetSnapshot.from(
            AppStatePolicy.normalize(state), "2026-09-06",
        )
        assertEquals(WidgetState(2, 4, 8), WidgetState(snapshot.intensity, snapshot.count, snapshot.intensitySum))
    }

    @Test fun `widget launch carries source only and no intensity`() {
        assertEquals("widget", WidgetLaunchIntentFactory.SOURCE)
        assertEquals("com.maeumjaro.app.widget.START", WidgetActionContract.ACTION_START)
        assertEquals("com.maeumjaro.app.widget.DELTA", WidgetActionContract.EXTRA_DELTA)
    }
    @Test fun `responsive layout switches at compact boundary`() {
        assertEquals(WidgetLayout.TWO_BY_TWO, WidgetLayoutSpec.forWidthDp(179))
        assertEquals(WidgetLayout.FOUR_BY_TWO, WidgetLayoutSpec.forWidthDp(180))
    }

    @Test
    fun `decreasing intensity clamps at one`() = runTest {
        val store = createStore(1, this)
        val result = DataStoreWidgetStateGateway(store, clock()).changeIntensity(-1)
        assertEquals(1, result.intensity)
        assertEquals(1, store.state.first().intensity)
    }

    @Test
    fun `increasing intensity clamps at five`() = runTest {
        val store = createStore(5, this)
        val result = DataStoreWidgetStateGateway(store, clock()).changeIntensity(1)
        assertEquals(5, result.intensity)
        assertEquals(5, store.state.first().intensity)
    }

    @Test
    fun `widget preset changes only that widget and leaves global intensity unchanged`() = runTest {
        val store = createStore(2, this)
        store.writeConfirmedPro(PRO_LIFETIME_PRODUCT_ID, 2L)
        store.setWidgetPreset(42, 4)

        val result = DataStoreWidgetStateGateway(store, clock(), appWidgetId = 42).changeIntensity(1)
        val persisted = store.state.first()

        assertEquals(5, result.intensity)
        assertEquals(2, persisted.intensity)
        assertEquals(5, persisted.widgetPresetsList.single { it.appWidgetId == 42 }.intensity)
    }

    @Test
    fun `widget renders its preset when confirmed pro entitlement is active`() = runTest {
        val store = createStore(2, this)
        store.writeConfirmedPro(PRO_LIFETIME_PRODUCT_ID, 10L)
        store.setWidgetPreset(42, 5)

        val state = DataStoreWidgetStateGateway(store, clock(), appWidgetId = 42).state.first()

        assertEquals(5, state.intensity)
        assertEquals(true, state.usesPreset)
    }

    @Test
    fun `widget renders global intensity when pro entitlement is inactive`() = runTest {
        val store = createStore(2, this)
        store.setWidgetPreset(42, 5)

        val state = DataStoreWidgetStateGateway(store, clock(), appWidgetId = 42).state.first()

        assertEquals(2, state.intensity)
        assertEquals(false, state.usesPreset)
    }

    @Test
    fun `widget ignores malformed or wrong product entitlement`() = runTest {
        val store = createStore(2, this)
        store.setWidgetPreset(42, 5)

        store.setEntitlementCache(
            com.maeumjaro.app.data.settings.EntitlementStatus.ENTITLEMENT_STATUS_PRO,
            "other_product",
            10L,
        )
        assertEquals(2, DataStoreWidgetStateGateway(store, clock(), 42).state.first().intensity)

        store.setEntitlementCache(
            com.maeumjaro.app.data.settings.EntitlementStatus.ENTITLEMENT_STATUS_PRO,
            "",
            10L,
        )
        assertEquals(2, DataStoreWidgetStateGateway(store, clock(), 42).state.first().intensity)
    }

    @Test
    fun `widget start prepares preset intensity before app launch`() = runTest {
        val store = createStore(2, this)
        store.writeConfirmedPro(PRO_LIFETIME_PRODUCT_ID, 10L)
        store.setWidgetPreset(42, 5)

        val result = store.prepareLaunch(42, 11L)

        assertEquals(com.maeumjaro.app.data.settings.StoredPresetLaunchResult.Prepared(5), result)
        assertEquals(5, store.state.first().intensity)
        assertEquals(11L, store.state.first().intensityUpdatedAtEpochMillis)
    }

    @Test
    fun `widget start does not apply preset when pro entitlement is inactive`() = runTest {
        val store = createStore(2, this)
        store.setWidgetPreset(42, 5)

        val result = store.prepareLaunch(42, 11L)

        assertEquals(com.maeumjaro.app.data.settings.StoredPresetLaunchResult.ProInactive, result)
        assertEquals(2, store.state.first().intensity)
        assertEquals(1L, store.state.first().intensityUpdatedAtEpochMillis)
    }

    @Test
    fun `deleting widget preset does not delete global intensity`() = runTest {
        val store = createStore(3, this)
        store.setWidgetPreset(42, 4)

        store.deleteWidgetPreset(42)
        val persisted = store.state.first()

        assertEquals(3, persisted.intensity)
        assertEquals(0, persisted.widgetPresetsCount)
    }

    @Test
    fun `deleting one widget preset preserves another widget preset`() = runTest {
        val store = createStore(3, this)
        store.setWidgetPreset(41, 1)
        store.setWidgetPreset(42, 5)

        store.deleteWidgetPreset(41)

        assertEquals(mapOf(42 to 5), store.widgetPresets())
    }

    @Test
    fun `widget rejects multi-step intensity delta`() = runTest {
        val store = createStore(3, this)
        assertThrows(IllegalArgumentException::class.java) {
            kotlinx.coroutines.runBlocking {
                DataStoreWidgetStateGateway(store, clock()).changeIntensity(2)
            }
        }
    }

    private fun clock(): Clock = Clock.fixed(Instant.parse("2026-09-06T00:00:00Z"), ZoneOffset.UTC)

    private suspend fun createStore(intensity: Int, scope: TestScope): com.maeumjaro.app.data.settings.AppStateStore {
        val file = temporaryFolder.newFile("widget-$intensity-${System.nanoTime()}.pb")
        return com.maeumjaro.app.data.settings.AppStateStore(
            DataStoreFactory.create(
                serializer = com.maeumjaro.app.data.settings.AppStateSerializer,
                corruptionHandler = ReplaceFileCorruptionHandler {
                    com.maeumjaro.app.data.settings.AppStateSerializer.defaultValue
                },
                scope = scope.backgroundScope,
                produceFile = { file },
            ),
        ).also { store -> store.setIntensity(com.maeumjaro.app.data.settings.IntensityUpdate(intensity, 1L)) }
    }
}
