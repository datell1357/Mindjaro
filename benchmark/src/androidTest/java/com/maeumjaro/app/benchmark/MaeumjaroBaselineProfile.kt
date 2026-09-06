package com.maeumjaro.app.benchmark

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
        if (device.wait(Until.hasObject(By.text(ONBOARDING_TITLE)), APP_READY_TIMEOUT_MS)) {
            repeat(ONBOARDING_NEXT_COUNT) {
                device.findObject(By.text(NEXT_LABEL)).click()
                device.wait(Until.hasObject(By.text(ONBOARDING_STEP_TITLES[it + 1])), APP_READY_TIMEOUT_MS)
            }
            device.findObject(By.text(LATER_LABEL)).click()
        }
        check(device.wait(Until.hasObject(By.text(RECORDS_TITLE)), APP_READY_TIMEOUT_MS)) {
            "App-icon startup did not resolve to the records route"
        }
        device.findObject(By.text(START_INJECTION_LABEL)).click()
        check(device.wait(Until.hasObject(By.text(INJECTION_TITLE)), APP_READY_TIMEOUT_MS)) {
            "Records route did not open the injection route"
        }
    }

    private companion object {
        const val TARGET_PACKAGE = "com.maeumjaro.app"
        val ONBOARDING_STEP_TITLES = listOf(
            "마음을 멈추고 다시 선택해요",
            "밀어서 열고, 새로 길게 눌러요",
            "기본 강도를 정해요",
            "안전 안내를 확인해요",
            "필요한 순간에 바로 열어요",
        )
        const val ONBOARDING_TITLE = "마음을 멈추고 다시 선택해요"
        const val NEXT_LABEL = "다음"
        const val LATER_LABEL = "나중에"
        const val ONBOARDING_NEXT_COUNT = 4
        const val RECORDS_TITLE = "나의 기록"
        const val START_INJECTION_LABEL = "마음 정리 시작"
        const val INJECTION_TITLE = "마음 정리"
        const val APP_READY_TIMEOUT_MS = 5_000L
    }
}
