package com.maeumjaro.app.feature.injection

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InjectionRingRenderingContractTest {
    @Test
    fun reducedMotionReadyUsesReadyFace() {
        assertTrue(ringUsesReadyFace(InjectionPhase.READY))
        assertTrue(ringUsesReadyFace(InjectionPhase.AWAITING_HOLD))
        assertFalse(ringUsesReadyFace(InjectionPhase.LOCKED))
        assertFalse(ringUsesReadyFace(InjectionPhase.RELOCKING))
    }

    @Test
    fun ringFacesRemainOppositeAcrossContinuousRotation() {
        listOf(-180f, -90f, 0f, 90f, 180f, 270f).forEach { baseRotationY ->
            val lockedRotation = ringFaceRotationY(baseRotationY, readyFace = false)
            val readyRotation = ringFaceRotationY(baseRotationY, readyFace = true)
            assertEquals(180f, readyRotation - lockedRotation, 0f)
        }
    }
}
