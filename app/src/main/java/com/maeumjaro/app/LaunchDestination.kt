package com.maeumjaro.app

enum class LaunchDestination {
    Onboarding,
    Records,
}

fun resolveLaunchDestination(returningSeed: Boolean): LaunchDestination =
    if (returningSeed) LaunchDestination.Records else LaunchDestination.Onboarding
