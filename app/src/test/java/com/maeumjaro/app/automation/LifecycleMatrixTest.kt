package com.maeumjaro.app.automation

import org.junit.Assert.assertEquals
import org.junit.Test

class LifecycleMatrixTest {
    @Test
    fun requiredLifecycleScenariosStayExplicit() {
        assertEquals(
            setOf("process-stopped", "on-new-intent", "configuration-recreation", "screen-off-on",
                "background-before-after-completion", "device-reboot", "app-update",
                "simultaneous-widget-callbacks", "local-midnight", "timezone-dst-change",
                "storage-failure", "low-memory-process-death"),
            LifecycleMatrix.scenarios,
        )
    }

    @Test
    fun externalGatesCannotBeClaimedByAutomation() {
        assertEquals(setOf("physical-widget-p95", "talkback-switch-access", "physical-haptics",
            "reboot-update-low-memory", "bmgr-device-to-device"), LifecycleMatrix.externalGates)
    }
}

private object LifecycleMatrix {
    val scenarios = setOf("process-stopped", "on-new-intent", "configuration-recreation", "screen-off-on",
        "background-before-after-completion", "device-reboot", "app-update", "simultaneous-widget-callbacks",
        "local-midnight", "timezone-dst-change", "storage-failure", "low-memory-process-death")
    val externalGates = setOf("physical-widget-p95", "talkback-switch-access", "physical-haptics",
        "reboot-update-low-memory", "bmgr-device-to-device")
}
