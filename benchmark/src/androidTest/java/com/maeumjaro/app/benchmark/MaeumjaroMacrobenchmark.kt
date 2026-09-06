package com.maeumjaro.app.benchmark

import android.content.Intent
import androidx.benchmark.macro.FrameTimingMetric
import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.StartupTimingMetric
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MaeumjaroMacrobenchmark {
    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun coldStartup() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.COLD,
        setupBlock = { device.pressHome() },
        measureBlock = {
            startActivityAndWait()
            waitForApp()
        },
    )

    @Test
    fun warmStartup() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.WARM,
        measureBlock = {
            startActivityAndWait()
            waitForApp()
        },
    )

    /** Measures the path users take from the real widget action into the app. */
    @Test
    fun widgetDirectColdStartup() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.COLD,
        setupBlock = { device.pressHome() },
        measureBlock = {
            startActivityAndWait(widgetLaunchIntent())
            waitForInjectionRoute()
        },
    )

    @Test
    fun widgetDirectWarmStartup() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.WARM,
        measureBlock = {
            startActivityAndWait(widgetLaunchIntent())
            waitForInjectionRoute()
        },
    )

    @Test
    fun intensityFiveFrameTiming() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(FrameTimingMetric()),
        iterations = 5,
        startupMode = StartupMode.WARM,
        measureBlock = {
            startActivityAndWait(intensityFiveIntent())
            waitForApp()
            // The app owns the gesture contract; this captures the steady-state frame path.
            device.swipe(500, 900, 500, 500, 20)
        },
    )

    private fun MacrobenchmarkScope.waitForApp() {
        check(device.wait(Until.hasObject(By.pkg(TARGET_PACKAGE)), APP_READY_TIMEOUT_MS)) {
            "Timed out waiting for $TARGET_PACKAGE; startup metric is not valid"
        }
    }

    private fun MacrobenchmarkScope.waitForInjectionRoute() {
        waitForApp()
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

    private fun intensityFiveIntent(): Intent = widgetLaunchIntent().apply {
        putExtra(DEBUG_SEED_RETURNING_EXTRA, true)
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
