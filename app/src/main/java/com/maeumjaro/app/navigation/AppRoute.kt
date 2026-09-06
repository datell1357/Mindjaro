package com.maeumjaro.app.navigation

enum class AppRoute(val path: String) {
    Onboarding("onboarding"),
    Records("records"),
    Settings("settings"),
    Injection("injection"),
    Completion("completion/{eventId}?repairPending={repairPending}"),
    RecordDetail("record-detail/{eventId}"),
    Safety("safety"),
    Pro("pro"),
    Customization("customization"),
    Analytics("analytics"),
}

fun AppRoute.pathForEvent(eventId: String, repairPending: Boolean = false): String = when (this) {
    AppRoute.Completion -> "completion/$eventId?repairPending=$repairPending"
    AppRoute.RecordDetail -> "record-detail/$eventId"
    else -> path
}

sealed interface LaunchRequest {
    data object AppIcon : LaunchRequest
    data object VerifiedWidget : LaunchRequest

    companion object {
        fun parse(rawSource: String?, verifiedWidget: Boolean): LaunchRequest =
            if (rawSource == "widget" && verifiedWidget) VerifiedWidget else AppIcon
    }
}

data class LaunchPlan(
    val start: AppRoute,
    val afterOnboarding: AppRoute = start,
)
