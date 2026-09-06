package com.maeumjaro.app.widget

import com.maeumjaro.app.MainActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.ext.junit.runners.AndroidJUnit4

@RunWith(AndroidJUnit4::class)
class WidgetLaunchIntentContractTest {
    @Test
    fun launchIntentCarriesWidgetSourceWithoutIntensity() {
        val intent = WidgetLaunchIntentFactory.intent()

        assertEquals("widget", intent.getStringExtra(MainActivity.EXTRA_SOURCE))
        assertFalse(intent.extras?.containsKey("intensity") == true)
    }

    @Test
    fun launchIntentUsesSingleTopAndClearTopFlags() {
        val intent = WidgetLaunchIntentFactory.intent()

        assertEquals(
            android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP,
            intent.flags,
        )
    }

    @Test
    fun widgetLaunchProofIsOneUse() {
        val token = WidgetLaunchAuthenticator.issue()

        assertEquals(true, WidgetLaunchAuthenticator.consume(token))
        assertEquals(false, WidgetLaunchAuthenticator.consume(token))
    }
}
