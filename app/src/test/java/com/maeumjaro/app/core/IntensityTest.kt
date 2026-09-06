package com.maeumjaro.app.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class IntensityTest {
    @Test fun `Given valid strengths When parsed Then final motion mappings are exact`() {
        val expected = listOf(1 to (0.2 to 1200L), 2 to (0.4 to 1500L), 3 to (0.6 to 1800L), 4 to (0.8 to 2200L), 5 to (1.0 to 3200L))
        assertEquals(expected, (1..5).map { value -> Intensity.from(value)!!.let { value to (it.initialFill to it.durationMillis) } })
        assertEquals(listOf(1, 2, 3, 4, 5), (1..5).map { Intensity.from(it)!!.hapticThresholdCount })
    }

    @Test fun `Given malformed strengths When parsed Then no domain value is created`() {
        listOf(Int.MIN_VALUE, -1, 0, 6, 99, Int.MAX_VALUE).forEach { assertNull(Intensity.from(it)) }
        listOf(-0.01, 1.01, Double.NaN, Double.POSITIVE_INFINITY).forEach { assertNull(RitualProgress.from(it)) }
    }

    @Test fun `Given touch target widths When threshold requested Then responsive bounds are preserved`() {
        assertEquals(44.0, unlockThresholdPx(100.0), 0.0)
        assertEquals(54.0, unlockThresholdPx(300.0), 0.0)
        assertEquals(56.0, unlockThresholdPx(1000.0), 0.0)
    }
}
