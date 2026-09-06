package com.maeumjaro.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

class LaunchRouterTest {
    @Test
    fun `given first icon launch when resolved then onboarding continues to records`() {
        // Given: onboarding has not been completed.
        val onboardingCompleted = false

        // When: the app icon launch is resolved.
        val result = LaunchRouter.resolve(LaunchRequest.AppIcon, onboardingCompleted)

        // Then: onboarding is shown before records.
        assertEquals(LaunchPlan(AppRoute.Onboarding, AppRoute.Records), result)
    }

    @Test
    fun `given returning icon launch when resolved then records opens`() {
        // Given: onboarding has been completed.
        val onboardingCompleted = true

        // When: the app icon launch is resolved.
        val result = LaunchRouter.resolve(LaunchRequest.AppIcon, onboardingCompleted)

        // Then: records opens without onboarding.
        assertEquals(LaunchPlan(AppRoute.Records), result)
    }

    @Test
    fun `given first verified widget launch when resolved then onboarding continues to injection`() {
        // Given: a verified widget launch before onboarding completion.
        val onboardingCompleted = false

        // When: the launch is resolved.
        val result = LaunchRouter.resolve(LaunchRequest.VerifiedWidget, onboardingCompleted)

        // Then: the safety gate continues directly to injection.
        assertEquals(LaunchPlan(AppRoute.Onboarding, AppRoute.Injection), result)
    }

    @Test
    fun `given returning verified widget launch when resolved then injection opens directly`() {
        // Given: onboarding has been completed.
        val onboardingCompleted = true

        // When: the launch is resolved.
        val result = LaunchRouter.resolve(LaunchRequest.VerifiedWidget, onboardingCompleted)

        // Then: injection opens with no records route.
        assertEquals(LaunchPlan(AppRoute.Injection), result)
    }

    @Test
    fun `given malformed external route when parsed then app icon behavior is used`() {
        // Given: untrusted external route data.
        val rawRoute = "widget"

        // When: it is parsed without verification.
        val request = LaunchRequest.parse(rawRoute, verifiedWidget = false)

        // Then: it cannot enter injection.
        assertEquals(LaunchRequest.AppIcon, request)
    }
}
