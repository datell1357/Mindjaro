package com.maeumjaro.app.feature.injection

import com.maeumjaro.app.core.AwaitingFirstPress
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.HoldThresholdReached
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.Locked
import com.maeumjaro.app.core.PointerDown
import com.maeumjaro.app.core.PointerMoved
import com.maeumjaro.app.core.PointerUp
import com.maeumjaro.app.core.Pressing
import com.maeumjaro.app.core.Ready
import com.maeumjaro.app.core.SessionStart
import com.maeumjaro.app.core.reduce
import java.time.Instant
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class InjectionReducerCharacterizationTest {
    @Test
    fun `existing reducer requires swipe release then a new pointer held for 120ms`() {
        val intensity = requireNotNull(Intensity.from(3))
        val locked = Locked(intensity, EntrySource.APP)

        val unlocking = reduce(locked, PointerDown(pointerId = 1, monotonicMillis = 0))
        val moved = reduce(unlocking, PointerMoved(56.0, 0.0, 400.0))
        val readyState = reduce(moved, PointerUp(pointerId = 1, monotonicMillis = 20))
        assertTrue(readyState is Ready)
        val ready = readyState as Ready
        assertEquals(ready, reduce(ready, PointerDown(pointerId = 1, monotonicMillis = 21)))

        val awaitingState = reduce(ready, PointerDown(pointerId = 2, monotonicMillis = 30))
        assertTrue(awaitingState is AwaitingFirstPress)
        val awaiting = awaitingState as AwaitingFirstPress
        val sessionStart = SessionStart(UUID.fromString("00000000-0000-0000-0000-000000000006"), Instant.EPOCH)
        assertEquals(awaiting, reduce(awaiting, HoldThresholdReached(2, 149, sessionStart)))
        assertTrue(reduce(awaiting, HoldThresholdReached(2, 150, sessionStart)) is Pressing)
    }
}
