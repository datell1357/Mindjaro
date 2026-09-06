package com.maeumjaro.app.data.settings

import androidx.datastore.core.DataStoreFactory
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AppStateStoreTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `recovers defaults when the proto file is corrupt`() = runTest {
        // Given: bytes that cannot represent AppState.
        val file = temporaryFolder.newFile("corrupt.pb").apply { writeBytes(byteArrayOf(0x80.toByte())) }
        val store = createStore(file, this)

        // When: the state is first read.
        val state = store.state.first()

        // Then: the corruption handler replaces it with product defaults.
        assertEquals(3, state.intensity)
        assertEquals(true, state.hapticEnabled)
    }

    @Test
    fun `serializes simultaneous writes and keeps the last successful valid write`() = runTest {
        // Given: a first update held inside DataStore's atomic transform.
        val store = createStore(temporaryFolder.newFile("atomic.pb"), this)
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val first = async {
            store.update {
                entered.complete(Unit)
                release.await()
                it.toBuilder().setIntensity(1).build()
            }
        }
        entered.await()

        // When: a second valid write races behind it.
        val second = async { store.setIntensity(IntensityUpdate(5, 2L)) }
        release.complete(Unit)
        first.await()
        second.await()

        // Then: both serialize and the later successful write is retained.
        assertEquals(5, store.state.first().intensity)
    }

    @Test
    fun `persists haptic preference through the typed setter`() = runTest {
        val store = createStore(temporaryFolder.newFile("haptic.pb"), this)

        store.setHapticEnabled(false)

        assertEquals(false, store.state.first().hapticEnabled)
    }

    @Test
    fun `persists sound preference through the typed setter`() = runTest {
        val store = createStore(temporaryFolder.newFile("sound.pb"), this)

        store.setSoundEnabled(true)

        assertEquals(true, store.state.first().soundEnabled)
    }

    @Test
    fun `persists reduced motion preference through the typed setter`() = runTest {
        val store = createStore(temporaryFolder.newFile("reduced-motion.pb"), this)

        store.setReducedMotionEnabled(true)

        assertEquals(true, store.state.first().reducedMotionEnabled)
    }

    @Test
    fun `theme and widget preset setters preserve unrelated settings`() = runTest {
        val store = createStore(temporaryFolder.newFile("prefs.pb"), this)
        store.setHapticEnabled(false)
        store.setThemeId(" dusk ")
        store.setWidgetPreset(42, 5)

        val state = store.state.first()
        assertEquals("dusk", state.themeId)
        assertEquals(false, state.hapticEnabled)
        assertEquals(5, state.widgetPresetsList.single().intensity)
    }

    @Test
    fun `confirmed entitlement cache exposes only a valid pro product`() = runTest {
        val store = createStore(temporaryFolder.newFile("entitlement.pb"), this)
        assertNull(store.confirmedEntitlementCache())

        store.setEntitlementCache(
            EntitlementStatus.ENTITLEMENT_STATUS_FREE,
            "pro_lifetime",
            10L,
        )
        assertNull(store.confirmedEntitlementCache())

        store.setEntitlementCache(
            EntitlementStatus.ENTITLEMENT_STATUS_PRO,
            " pro_lifetime ",
            11L,
        )
        assertEquals("pro_lifetime", store.confirmedEntitlementCache()!!.productId)
        assertEquals(11L, store.confirmedEntitlementCache()!!.lastVerifiedAtEpochMillis)
    }

    @Test
    fun `prepare launch atomically applies pro widget preset and global intensity`() = runTest {
        val store = createStore(temporaryFolder.newFile("launch.pb"), this)
        store.setIntensity(IntensityUpdate(2, 1L))
        store.setEntitlementCache(EntitlementStatus.ENTITLEMENT_STATUS_PRO, "pro_lifetime", 2L)
        store.setWidgetPreset(7, 5)

        assertEquals(StoredPresetLaunchResult.Prepared(5), store.prepareLaunch(7, 3L))
        val state = store.state.first()
        assertEquals(5, state.intensity)
        assertEquals(3L, state.intensityUpdatedAtEpochMillis)
        assertEquals(5, state.widgetPresetsList.single().intensity)
    }

    @Test
    fun `prepare launch reports missing preset and inactive pro explicitly without writing`() = runTest {
        val store = createStore(temporaryFolder.newFile("launch-results.pb"), this)
        store.setIntensity(IntensityUpdate(2, 1L))

        assertEquals(StoredPresetLaunchResult.ProInactive, store.prepareLaunch(7, 3L))
        store.setEntitlementCache(EntitlementStatus.ENTITLEMENT_STATUS_PRO, "pro_lifetime", 2L)
        assertEquals(StoredPresetLaunchResult.NoPreset, store.prepareLaunch(7, 3L))
        assertEquals(2, store.state.first().intensity)
        assertEquals(1L, store.state.first().intensityUpdatedAtEpochMillis)
    }

    @Test
    fun `delete widget preset leaves global intensity and other presets intact`() = runTest {
        val store = createStore(temporaryFolder.newFile("delete-preset.pb"), this)
        store.setIntensity(IntensityUpdate(4, 9L))
        store.setWidgetPreset(1, 2)
        store.setWidgetPreset(2, 3)

        store.deleteWidgetPreset(1)

        val state = store.state.first()
        assertEquals(4, state.intensity)
        assertEquals(1, state.widgetPresetsCount)
        assertEquals(2, state.widgetPresetsList.single().appWidgetId)
    }

    @Test
    fun `delete widget presets removes all requested ids atomically`() = runTest {
        val store = createStore(temporaryFolder.newFile("delete-presets.pb"), this)
        store.setWidgetPreset(1, 2)
        store.setWidgetPreset(2, 3)
        store.setWidgetPreset(3, 4)

        store.deleteWidgetPresets(listOf(1, 3, 99))

        assertEquals(listOf(2), store.state.first().widgetPresetsList.map { it.appWidgetId })
    }

    private fun createStore(file: File, scope: TestScope): AppStateStore = AppStateStore(
        DataStoreFactory.create(
            serializer = AppStateSerializer,
            corruptionHandler = ReplaceFileCorruptionHandler { AppStateSerializer.defaultValue },
            scope = scope.backgroundScope,
            produceFile = { file },
        ),
    )
}
