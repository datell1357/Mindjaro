package com.maeumjaro.app.feature.settings

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.data.local.DeletionDecision
import com.maeumjaro.app.data.local.InjectionEventRepository
import com.maeumjaro.app.data.local.MaeumjaroDatabase
import com.maeumjaro.app.data.local.RoomInjectionEventRepository
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.data.settings.AppState
import com.maeumjaro.app.data.settings.AppStateGateway
import com.maeumjaro.app.data.settings.EntitlementCache
import com.maeumjaro.app.data.settings.EntitlementStatus
import com.maeumjaro.app.data.settings.LocalDateSource
import com.maeumjaro.app.data.settings.ReconcileTrigger
import com.maeumjaro.app.data.settings.ReconciliationResult
import com.maeumjaro.app.data.settings.TodayTotalsAuthority
import com.maeumjaro.app.data.settings.WidgetProjectionReconciler
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SettingsExportDeleteIntegrationTest {
    private lateinit var database: MaeumjaroDatabase
    private lateinit var repository: InjectionEventRepository

    @Before
    fun createInMemoryRepository() {
        database = MaeumjaroDatabase.inMemory(ApplicationProvider.getApplicationContext<Context>())
        repository = RoomInjectionEventRepository(database)
    }

    @After
    fun closeInMemoryRepository() {
        database.close()
    }

    @Test
    fun confirmedBulkDeleteClearsRoomAndProjectionWithoutChangingSettingsOrEntitlement() = runBlocking {
        val date = LocalDate.parse("2026-09-06")
        repository.insertCompletedEvent(fixture("one", date, 2))
        repository.insertCompletedEvent(fixture("two", date, 4))
        val gateway = FakeStateGateway(
            AppState.newBuilder()
                .setIntensity(5)
                .setHapticEnabled(false)
                .setSoundEnabled(true)
                .setOnboardingCompleted(true)
                .setEntitlementCache(
                    EntitlementCache.newBuilder()
                        .setStatus(EntitlementStatus.ENTITLEMENT_STATUS_PRO)
                        .setProductId("pro_lifetime")
                        .setLastVerifiedAtEpochMillis(100L),
                )
                .setWidgetProjection(
                    com.maeumjaro.app.data.settings.WidgetProjection.newBuilder()
                        .setLocalDate(date.toString())
                        .setCount(2)
                        .setIntensitySum(6),
                )
                .build(),
        )
        val reconciler = WidgetProjectionReconciler(
            authority = TodayTotalsAuthority {
                repository.totalsForStoredDate(date).let { totals ->
                    com.maeumjaro.app.data.settings.TodayTotals(totals.count, totals.intensitySum)
                }
            },
            stateGateway = gateway,
            localDateSource = LocalDateSource { date.toString() },
        )

        assertEquals(com.maeumjaro.app.data.local.DeleteResult.Deleted(2), repository.deleteAllEvents(DeletionDecision.Confirmed))
        assertEquals(0, database.injectionEventDao().rowCount())
        val result = reconciler.reconcile(ReconcileTrigger.BULK_DELETE, 200L)

        assertTrue(result is ReconciliationResult.Success)
        assertEquals(0, gateway.current.widgetProjection.count)
        assertEquals(0, gateway.current.widgetProjection.intensitySum)
        assertEquals(5, gateway.current.intensity)
        assertEquals(false, gateway.current.hapticEnabled)
        assertEquals(true, gateway.current.soundEnabled)
        assertEquals(true, gateway.current.onboardingCompleted)
        assertEquals(EntitlementStatus.ENTITLEMENT_STATUS_PRO, gateway.current.entitlementCache.status)
        assertEquals("pro_lifetime", gateway.current.entitlementCache.productId)
    }

    @Test
    fun canceledBulkDeletePreservesRoomRowsAndTheirTotals() = runBlocking {
        val date = LocalDate.parse("2026-09-06")
        repository.insertCompletedEvent(fixture("cancel", date, 3))

        assertEquals(com.maeumjaro.app.data.local.DeleteResult.Canceled, repository.deleteAllEvents(DeletionDecision.Canceled))
        assertEquals(1, database.injectionEventDao().rowCount())
        assertEquals(1, repository.totalsForStoredDate(date).count)
        assertEquals(3, repository.totalsForStoredDate(date).intensitySum)
    }

    private fun fixture(name: String, date: LocalDate, intensity: Int): StoredInjectionEvent {
        val id = UUID.nameUUIDFromBytes(name.toByteArray())
        val completed = Instant.parse("2026-09-06T00:00:00Z").plusMillis(id.leastSignificantBits and 0xFFL)
        return StoredInjectionEvent(
            id = id,
            startedAtUtc = completed.minusSeconds(2),
            completedAtUtc = completed,
            eventLocalDate = date,
            timezoneOffsetMinutes = 540,
            intensity = requireNotNull(Intensity.from(intensity)),
            source = EntrySource.APP,
            phraseId = PhraseId("fixture-$name"),
            animationDurationMs = 1_800,
            interruptionCount = 0,
            appVersion = "0.1.0",
            createdAtUtc = completed,
        )
    }

    private class FakeStateGateway(initial: AppState) : AppStateGateway {
        private val mutableState = MutableStateFlow(initial)
        override val state: StateFlow<AppState> = mutableState
        val current: AppState get() = mutableState.value

        override suspend fun update(transform: suspend (AppState) -> AppState): AppState =
            transform(current).also { mutableState.value = it }
    }
}
