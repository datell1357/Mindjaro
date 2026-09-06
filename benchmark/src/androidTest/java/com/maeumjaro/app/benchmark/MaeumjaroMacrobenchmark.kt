package com.maeumjaro.app.benchmark

import androidx.benchmark.macro.FrameTimingMetric
import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.StartupTimingMetric
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Assume.assumeTrue
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
        setupBlock = { device.pressHome() },
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
        setupBlock = {
            device.pressHome()
            assumeTrue("A real 마음자로 widget must be placed on the launcher", launcherStartButton() != null)
        },
        measureBlock = {
            launcherStartButton()!!.click()
            waitForInjectionRoute()
        },
    )

    @Test
    fun widgetDirectWarmStartup() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.WARM,
        setupBlock = {
            device.pressHome()
            assumeTrue("A real 마음자로 widget must be placed on the launcher", launcherStartButton() != null)
        },
        measureBlock = {
            launcherStartButton()!!.click()
            waitForInjectionRoute()
        },
    )

    @Test
    fun intensityFiveFrameTiming() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(FrameTimingMetric()),
        iterations = 5,
        startupMode = StartupMode.WARM,
        setupBlock = {
            prepareReturningState()
            prepareIntensityFive()
            device.pressBack()
            check(device.wait(Until.hasObject(By.text(RECORDS_TITLE)), APP_READY_TIMEOUT_MS)) {
                "Settings route did not return to the records route"
            }
            device.findObject(By.text(START_INJECTION_LABEL)).click()
            check(device.wait(Until.hasObject(By.text(INJECTION_TITLE)), APP_READY_TIMEOUT_MS)) {
                "Records route did not open the injection route during setup"
            }
        },
        measureBlock = {
            performIntensityFiveRitual()
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

    private fun MacrobenchmarkScope.launcherStartButton() =
        device.findObject(By.desc("마음자로 시작"))

    private fun MacrobenchmarkScope.prepareReturningState() {
        startActivityAndWait()
        if (device.wait(Until.hasObject(By.text(ONBOARDING_TITLE)), APP_READY_TIMEOUT_MS)) {
            repeat(ONBOARDING_NEXT_COUNT) {
                device.findObject(By.text(NEXT_LABEL)).click()
                device.wait(Until.hasObject(By.text(ONBOARDING_STEP_TITLES[it + 1])), APP_READY_TIMEOUT_MS)
            }
            device.findObject(By.text(LATER_LABEL)).click()
        }
        if (!device.wait(Until.hasObject(By.text(RECORDS_TITLE)), APP_READY_TIMEOUT_MS)) {
            device.pressBack()
        }
        check(device.wait(Until.hasObject(By.text(RECORDS_TITLE)), APP_READY_TIMEOUT_MS)) {
            "Could not establish the persisted returning state through the real onboarding UI"
        }
    }

    private fun MacrobenchmarkScope.prepareIntensityFive() {
        check(device.wait(Until.hasObject(By.text(SETTINGS_LABEL)), APP_READY_TIMEOUT_MS)) {
            "Records route did not expose the Settings action"
        }
        device.findObject(By.text(SETTINGS_LABEL)).click()
        check(device.wait(Until.hasObject(By.desc(SETTINGS_INTENSITY_DESC)), APP_READY_TIMEOUT_MS)) {
            "Settings intensity control was not available"
        }
        val slider = device.findObject(By.desc(SETTINGS_INTENSITY_DESC))
        val bounds = slider.visibleBounds
        device.click(bounds.right - 2, bounds.centerY())
        check(device.wait(Until.hasObject(By.text(SETTINGS_INTENSITY_FIVE)), APP_READY_TIMEOUT_MS)) {
            "Real settings interaction did not set intensity to 5"
        }
    }

    /** Executes the production gesture contract: unlock, release, then hold for intensity 5. */
    private fun MacrobenchmarkScope.performIntensityFiveRitual() {
        device.swipe(500, 900, 620, 900, 24)
        check(device.wait(Until.hasObject(By.text(READY_STATE_LABEL)), APP_READY_TIMEOUT_MS)) {
            "Unlock gesture did not reach the ready state"
        }
        // Include the 120 ms hold-recognition delay before the 3.2 s level-5 ritual.
        // UiDevice steps are approximately 5 ms; 4 s also leaves room for frame scheduling.
        device.swipe(500, 900, 501, 900, 800)
        check(device.wait(Until.hasObject(By.text(COMPLETED_STATE_LABEL)), APP_READY_TIMEOUT_MS)) {
            "Intensity-5 hold did not complete the production ritual"
        }
    }

    private companion object {
        const val TARGET_PACKAGE = "com.maeumjaro.app"
        const val ONBOARDING_TITLE = "마음을 멈추고 다시 선택해요"
        val ONBOARDING_STEP_TITLES = listOf(
            "마음을 멈추고 다시 선택해요",
            "밀어서 열고, 새로 길게 눌러요",
            "기본 강도를 정해요",
            "안전 안내를 확인해요",
            "필요한 순간에 바로 열어요",
        )
        const val NEXT_LABEL = "다음"
        const val LATER_LABEL = "나중에"
        const val ONBOARDING_NEXT_COUNT = 4
        const val RECORDS_TITLE = "나의 기록"
        const val START_INJECTION_LABEL = "마음 정리 시작"
        const val SETTINGS_LABEL = "설정"
        const val SETTINGS_INTENSITY_DESC = "기본 강도"
        const val SETTINGS_INTENSITY_FIVE = "기본 강도 5"
        const val INJECTION_TITLE = "마음 정리"
        const val READY_STATE_LABEL = "준비됐어요. 손을 떼었다가 새로 길게 눌러 주세요."
        const val COMPLETED_STATE_LABEL = "마음 정리를 마쳤어요"
        const val APP_READY_TIMEOUT_MS = 5_000L
    }
}
