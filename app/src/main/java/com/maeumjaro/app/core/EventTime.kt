package com.maeumjaro.app.core

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset

@ConsistentCopyVisibility
data class EventTime private constructor(
    val instant: Instant,
    val localDate: LocalDate,
    val offsetSeconds: Int,
) {
    val localDateTime: LocalDateTime
        get() = LocalDateTime.ofInstant(instant, ZoneOffset.ofTotalSeconds(offsetSeconds))

    companion object {
        fun at(instant: Instant, zoneId: ZoneId): EventTime {
            val zoned = instant.atZone(zoneId)
            return EventTime(instant, zoned.toLocalDate(), zoned.offset.totalSeconds)
        }
    }
}
