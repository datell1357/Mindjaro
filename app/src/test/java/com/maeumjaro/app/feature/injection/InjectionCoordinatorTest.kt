package com.maeumjaro.app.feature.injection

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class InjectionCoordinatorTest {
    private val clock = Clock.fixed(Instant.parse("2026-09-05T00:00:00Z"), ZoneOffset.UTC)
    private val sessionId = UUID.fromString("00000000-0000-0000-0000-000000000006")

    @Test
    fun `all intensities expose their exact duration and initial fill`() {
        val expected = listOf(1 to (1_200L to .2), 2 to (1_500L to .4), 3 to (1_800L to .6), 4 to (2_200L to .8), 5 to (3_200L to 1.0))
        expected.forEach { (value, mapping) ->
            val coordinator = coordinator(value)
            assertEquals(mapping.first, coordinator.uiState.durationMillis)
            assertEquals(mapping.second, coordinator.uiState.initialFill, 0.0)
        }
    }

    @Test
    fun `progress starts only after unlock release and 120ms new pointer gate`() {
        val coordinator = coordinator(1)
        coordinator.pointerDown(1, 0)
        coordinator.pointerMoved(56f, 0f, 400f)
        coordinator.pointerUp(1, 10)
        coordinator.pointerDown(2, 20)
        coordinator.frame(139)
        assertEquals(InjectionPhase.AWAITING_HOLD, coordinator.uiState.phase)
        coordinator.frame(140)
        assertEquals(InjectionPhase.PRESSING, coordinator.uiState.phase)
        coordinator.frame(340)
        assertEquals(200.0 / 1200.0, coordinator.uiState.progress, 0.0001)
    }

    @Test
    fun `a new gesture sequence may reuse the same platform pointer id`() {
        val coordinator = coordinator(1)
        coordinator.pointerDown(0, 0)
        coordinator.pointerMoved(56f, 0f, 400f)
        coordinator.pointerUp(0, 10)
        coordinator.pointerDown(0, 20)
        coordinator.frame(139)
        assertEquals(InjectionPhase.AWAITING_HOLD, coordinator.uiState.phase)
        coordinator.frame(140)
        assertEquals(InjectionPhase.PRESSING, coordinator.uiState.phase)
    }

    @Test
    fun `ready state ignores horizontal jitter until movement exceeds eight pixels`() {
        val coordinator = coordinator(1)
        coordinator.pointerDown(0, 0)
        coordinator.pointerMoved(56f, 0f, 400f)
        coordinator.pointerUp(0, 10)
        coordinator.pointerDown(0, 20)
        coordinator.pointerMoved(1f, 0f, 400f)
        assertEquals(InjectionPhase.AWAITING_HOLD, coordinator.uiState.phase)
        coordinator.pointerMoved(8f, 0f, 400f)
        assertEquals(InjectionPhase.AWAITING_HOLD, coordinator.uiState.phase)
        coordinator.pointerMoved(9f, 0f, 400f)
        assertEquals(InjectionPhase.RELOCKING, coordinator.uiState.phase)
    }

    @Test
    fun `release pauses exactly and secondary pointer never owns progress`() {
        val coordinator = pressingCoordinator()
        coordinator.pointerDown(9, 150)
        coordinator.frame(320)
        coordinator.pointerUp(9, 330)
        assertEquals(180.0 / 1200.0, coordinator.uiState.progress, 0.0001)
        coordinator.pointerUp(2, 340)
        assertEquals(InjectionPhase.PAUSED, coordinator.uiState.phase)
        assertEquals(200.0 / 1200.0, coordinator.uiState.progress, 0.0001)
        coordinator.frame(900)
        assertEquals(200.0 / 1200.0, coordinator.uiState.progress, 0.0001)
    }

    @Test
    fun `secondary pointer release cannot terminate unlock or relock`() {
        val coordinator = coordinator(1)
        coordinator.pointerDown(0, 0)
        coordinator.pointerMoved(30f, 0f, 400f)
        assertEquals(InjectionPhase.UNLOCKING, coordinator.uiState.phase)
        coordinator.pointerUp(9, 5)
        assertEquals(InjectionPhase.UNLOCKING, coordinator.uiState.phase)
        coordinator.pointerMoved(56f, 0f, 400f)
        coordinator.pointerUp(0, 10)

        coordinator.pointerDown(0, 20)
        coordinator.pointerMoved(9f, 0f, 400f)
        assertEquals(InjectionPhase.RELOCKING, coordinator.uiState.phase)
        coordinator.pointerUp(9, 25)
        assertEquals(InjectionPhase.RELOCKING, coordinator.uiState.phase)
    }

    @Test
    fun `cancel pauses and repeated cancel does not increment or drift`() {
        val coordinator = pressingCoordinator()
        coordinator.frame(240)
        coordinator.pointerCancelled(2, 250)
        val frozen = coordinator.uiState.progress
        coordinator.pointerCancelled(2, 900)
        coordinator.frame(1_000)
        assertEquals(InjectionPhase.PAUSED, coordinator.uiState.phase)
        assertEquals(110.0 / 1200.0, frozen, 0.0001)
        assertEquals(frozen, coordinator.uiState.progress, 0.0)
    }

    @Test
    fun `ready horizontal intent relocks only when threshold commits on pointer up`() {
        val coordinator = coordinator(3)
        coordinator.pointerDown(1, 0)
        coordinator.pointerMoved(56f, 0f, 400f)
        coordinator.pointerUp(1, 10)
        coordinator.pointerDown(2, 20)
        coordinator.pointerMoved(-60f, 1f, 400f)
        assertEquals(InjectionPhase.RELOCKING, coordinator.uiState.phase)
        coordinator.pointerUp(2, 30)
        assertEquals(InjectionPhase.LOCKED, coordinator.uiState.phase)
    }

    @Test
    fun `accessibility start and pause use threshold and resume from the frozen value`() {
        val coordinator = coordinator(1)
        coordinator.accessibilityStart(0)
        coordinator.frame(119)
        assertEquals(InjectionPhase.AWAITING_HOLD, coordinator.uiState.phase)
        coordinator.frame(120)
        coordinator.frame(320)
        coordinator.accessibilityPause(320)
        assertEquals(200.0 / 1200.0, coordinator.uiState.progress, 0.0001)
        coordinator.accessibilityStart(400)
        coordinator.frame(519)
        assertEquals(InjectionPhase.AWAITING_HOLD, coordinator.uiState.phase)
        coordinator.frame(520)
        coordinator.frame(620)
        assertEquals(300.0 / 1200.0, coordinator.uiState.progress, 0.0001)
    }

    @Test
    fun `reduced motion preserves numeric progress and removes intermediate ring rotation`() {
        val coordinator = coordinator(1)
        coordinator.updatePreferences(reducedMotion = true, hapticsEnabled = false, soundEnabled = false)
        coordinator.pointerDown(1, 0)
        coordinator.pointerMoved(30f, 0f, 400f)
        assertEquals(0f, coordinator.uiState.ringRotationY)
        coordinator.pointerMoved(56f, 0f, 400f)
        coordinator.pointerUp(1, 10)
        assertEquals(180f, coordinator.uiState.ringRotationY)
        assertFalse(coordinator.uiState.hapticsEnabled)
    }

    @Test
    fun `ring relock keeps the same rotationY axis and settles to the locked face`() {
        val coordinator = coordinator(1)
        coordinator.pointerDown(1, 0)
        coordinator.pointerMoved(56f, 0f, 400f)
        coordinator.pointerUp(1, 10)
        assertEquals(180f, coordinator.uiState.ringRotationY)
        coordinator.pointerDown(2, 20)
        coordinator.pointerMoved(-30f, 0f, 400f)
        assertEquals(83.57143f, coordinator.uiState.ringRotationY, 0.0001f)
        coordinator.pointerMoved(-56f, 0f, 400f)
        assertEquals(0f, coordinator.uiState.ringRotationY)
        coordinator.pointerUp(2, 30)
        assertEquals(InjectionPhase.LOCKED, coordinator.uiState.phase)
    }

    @Test
    fun `liquid remaining is derived from the contract fill and continuous progress`() {
        val coordinator = pressingCoordinator()
        coordinator.frame(440)
        assertEquals(.2, coordinator.uiState.initialFill, 0.0)
        assertEquals(coordinator.uiState.initialFill * (1.0 - coordinator.uiState.progress), coordinator.uiState.liquidRemaining, 0.000001)
        coordinator.pointerUp(2, 450)
        assertEquals(coordinator.uiState.initialFill * (1.0 - coordinator.uiState.progress), coordinator.uiState.liquidRemaining, 0.000001)
    }

    @Test
    fun `preference changes are frozen after a session starts`() {
        val coordinator = pressingCoordinator()
        assertFalse(coordinator.updatePreferences(reducedMotion = true, hapticsEnabled = false, soundEnabled = true))
        assertFalse(coordinator.uiState.reducedMotion)
        assertTrue(coordinator.uiState.hapticsEnabled)
        assertFalse(coordinator.uiState.soundEnabled)
    }

    @Test
    fun `completion emits one draft and malformed frames cannot duplicate it`() {
        val coordinator = pressingCoordinator()
        coordinator.frame(1_340)
        val first = coordinator.takeCompletionDraft()
        assertTrue(coordinator.uiState.progress == 1.0)
        assertEquals(sessionId, first?.sessionId)
        assertNull(coordinator.takeCompletionDraft())
        coordinator.frame(Long.MAX_VALUE)
        coordinator.pointerUp(2, Long.MAX_VALUE)
        assertNull(coordinator.takeCompletionDraft())
    }

    @Test
    fun `pointer up exactly at duration commits and retains one completion draft`() {
        val coordinator = pressingCoordinator()
        coordinator.pointerUp(2, 1_340)
        assertEquals(InjectionPhase.COMMITTING, coordinator.uiState.phase)
        assertEquals(sessionId, coordinator.takeCompletionDraft()?.sessionId)
        assertNull(coordinator.takeCompletionDraft())
    }

    @Test
    fun `background clears stale incomplete state and settings apply only when idle`() {
        val coordinator = pressingCoordinator()
        assertFalse(coordinator.setIntensity(requireNotNull(Intensity.from(5))))
        coordinator.backgrounded()
        assertEquals(InjectionPhase.READY, coordinator.uiState.phase)
        assertEquals(0.0, coordinator.uiState.progress, 0.0)
        assertTrue(coordinator.setIntensity(requireNotNull(Intensity.from(5))))
        assertEquals(3_200L, coordinator.uiState.durationMillis)
    }

    private fun coordinator(value: Int) = InjectionCoordinator(
        initialIntensity = requireNotNull(Intensity.from(value)),
        source = EntrySource.APP,
        wallClock = clock,
        zoneId = ZoneOffset.UTC,
        sessionIdFactory = { sessionId },
    )

    private fun pressingCoordinator(): InjectionCoordinator = coordinator(1).apply {
        pointerDown(1, 0)
        pointerMoved(56f, 0f, 400f)
        pointerUp(1, 10)
        pointerDown(2, 20)
        frame(140)
    }
}
