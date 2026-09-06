package com.maeumjaro.app.benchmark

import android.content.Intent
import androidx.benchmark.macro.junit4.BaselineProfileRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MaeumjaroBaselineProfile {
    @get:Rule
    val profileRule = BaselineProfileRule()

    @Test
    fun startupAndCoreNavigation() = profileRule.collect(TARGET_PACKAGE) {
        pressHome()
        startActivityAndWait()
        startActivityAndWait(widgetLaunchIntent())
        check(device.wait(Until.hasObject(By.text(INJECTION_TITLE)), APP_READY_TIMEOUT_MS)) {
            "Verified widget launch did not resolve to the injection route"
        }
    }

    private fun widgetLaunchIntent(): Intent = Intent().apply {
        setClassName(TARGET_PACKAGE, MAIN_ACTIVITY)
        putExtra(SOURCE_EXTRA, WIDGET_SOURCE)
        putExtra(DEBUG_VERIFIED_WIDGET_EXTRA, true)
        putExtra(DEBUG_SEED_RETURNING_EXTRA, true)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }

    private companion object {
        const val TARGET_PACKAGE = "com.maeumjaro.app"
        const val MAIN_ACTIVITY = "$TARGET_PACKAGE.MainActivity"
        const val SOURCE_EXTRA = "$TARGET_PACKAGE.SOURCE"
        const val WIDGET_SOURCE = "widget"
        const val DEBUG_VERIFIED_WIDGET_EXTRA = "$TARGET_PACKAGE.debug.VERIFIED_WIDGET"
        const val DEBUG_SEED_RETURNING_EXTRA = "$TARGET_PACKAGE.debug.SEED_RETURNING"
        const val INJECTION_TITLE = "마음 정리"
        const val APP_READY_TIMEOUT_MS = 5_000L
    }
}
