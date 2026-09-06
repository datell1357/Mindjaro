package com.maeumjaro.app

import org.junit.Assert.assertEquals
import org.junit.Test

class LaunchDestinationTest {
    @Test
    fun resolvesOnboardingWhenReturningSeedIsAbsent() {
        // Given: a normal first app launch.
        val returningSeed = false

        // When: the launch destination is resolved.
        val destination = resolveLaunchDestination(returningSeed)

        // Then: onboarding is the visible starting surface.
        assertEquals(LaunchDestination.Onboarding, destination)
    }

    @Test
    fun resolvesRecordsWhenReturningSeedIsPresent() {
        // Given: a deterministic debug returning-user seed.
        val returningSeed = true

        // When: the launch destination is resolved.
        val destination = resolveLaunchDestination(returningSeed)

        // Then: the records placeholder is the visible starting surface.
        assertEquals(LaunchDestination.Records, destination)
    }
}
