package com.maeumjaro.app.core

import kotlin.math.min

@JvmInline
value class Intensity private constructor(val value: Int) {
    val initialFill: Double get() = FILLS[value - 1]
    val durationMillis: Long get() = DURATIONS[value - 1]
    val hapticThresholdCount: Int get() = value

    companion object {
        private val DURATIONS = longArrayOf(1200, 1500, 1800, 2200, 3200)
        private val FILLS = doubleArrayOf(0.2, 0.4, 0.6, 0.8, 1.0)
        fun from(value: Int): Intensity? = if (value in 1..5) Intensity(value) else null
    }
}

@JvmInline
value class RitualProgress private constructor(val value: Double) {
    companion object {
        fun from(value: Double): RitualProgress? =
            if (value.isFinite() && value in 0.0..1.0) RitualProgress(value) else null

        internal fun fromElapsed(elapsedMillis: Long, durationMillis: Long): RitualProgress =
            RitualProgress((elapsedMillis.toDouble() / durationMillis).coerceIn(0.0, 1.0))
    }
}

fun unlockThresholdPx(touchTargetWidthPx: Double): Double =
    min(56.0, touchTargetWidthPx * 0.18).coerceAtLeast(44.0)
