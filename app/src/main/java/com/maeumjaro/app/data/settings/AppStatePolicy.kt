package com.maeumjaro.app.data.settings

import java.time.LocalDate
import java.time.format.DateTimeParseException

object AppStatePolicy {
    val defaultValue: AppState = AppState.newBuilder()
        .setIntensity(3)
        .setHapticEnabled(true)
        .setSoundEnabled(false)
        .setReducedMotionEnabled(false)
        .setPhraseTone(PhraseTone.PHRASE_TONE_AUTOMATIC)
        .setThemeId("default")
        .build()

    fun normalize(value: AppState): AppState {
        val builder = value.toBuilder()
        if (!value.hasIntensity() || value.intensity !in 1..5) builder.intensity = 3
        if (!value.hasHapticEnabled()) builder.hapticEnabled = true
        if (!value.hasSoundEnabled()) builder.soundEnabled = false
        if (!value.hasReducedMotionEnabled()) builder.reducedMotionEnabled = false
        if (value.intensityUpdatedAtEpochMillis < 0) builder.intensityUpdatedAtEpochMillis = 0
        builder.phraseTone = when (value.phraseTone) {
            PhraseTone.PHRASE_TONE_UNSPECIFIED,
            PhraseTone.UNRECOGNIZED,
            -> PhraseTone.PHRASE_TONE_AUTOMATIC
            PhraseTone.PHRASE_TONE_GENTLE,
            PhraseTone.PHRASE_TONE_NEUTRAL,
            PhraseTone.PHRASE_TONE_FIRM,
            PhraseTone.PHRASE_TONE_AUTOMATIC,
            -> value.phraseTone
        }
        if (value.themeId.isBlank()) builder.themeId = "default"
        builder.clearWidgetPresets()
        value.widgetPresetsList
            .filter { it.appWidgetId > 0 && it.hasIntensity() && it.intensity in 1..5 }
            .associateBy { it.appWidgetId }
            .values
            .forEach(builder::addWidgetPresets)
        val projectionIsValid = if (value.hasWidgetProjection()) {
            val projection = value.widgetProjection
            val dateIsValid = try {
                LocalDate.parse(projection.localDate)
                true
            } catch (_: DateTimeParseException) {
                false
            }
            projection.count >= 0 && projection.intensitySum >= 0 &&
                projection.updatedAtEpochMillis >= 0 && dateIsValid
        } else {
            true
        }
        if (!projectionIsValid) builder.clearWidgetProjection()
        if (value.hasEntitlementCache() && value.entitlementCache.lastVerifiedAtEpochMillis < 0) {
            builder.entitlementCache = value.entitlementCache.toBuilder().setLastVerifiedAtEpochMillis(0).build()
        }
        return builder.build()
    }

}
