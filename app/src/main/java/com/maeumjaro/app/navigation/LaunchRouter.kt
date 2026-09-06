package com.maeumjaro.app.navigation

object LaunchRouter {
    fun resolve(request: LaunchRequest, onboardingCompleted: Boolean): LaunchPlan = when {
        onboardingCompleted && request is LaunchRequest.VerifiedWidget -> LaunchPlan(AppRoute.Injection)
        onboardingCompleted -> LaunchPlan(AppRoute.Records)
        request is LaunchRequest.VerifiedWidget -> LaunchPlan(AppRoute.Onboarding, AppRoute.Injection)
        else -> LaunchPlan(AppRoute.Onboarding, AppRoute.Records)
    }
}
