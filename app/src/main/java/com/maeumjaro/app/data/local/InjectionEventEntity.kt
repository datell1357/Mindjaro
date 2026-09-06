package com.maeumjaro.app.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

@Entity(
    tableName = "injection_events",
    indices = [
        Index(value = ["event_local_date"]),
        Index(value = ["completed_at_utc"], orders = [Index.Order.DESC]),
        Index(value = ["event_local_date", "completed_at_utc"]),
    ],
)
data class InjectionEventEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "started_at_utc") val startedAtUtc: Long,
    @ColumnInfo(name = "completed_at_utc") val completedAtUtc: Long,
    @ColumnInfo(name = "event_local_date") val eventLocalDate: String,
    @ColumnInfo(name = "timezone_offset_minutes") val timezoneOffsetMinutes: Int,
    val intensity: Int,
    val source: String,
    @ColumnInfo(name = "phrase_id") val phraseId: String,
    @ColumnInfo(name = "animation_duration_ms") val animationDurationMs: Long,
    @ColumnInfo(name = "interruption_count") val interruptionCount: Int,
    @ColumnInfo(name = "app_version") val appVersion: String,
    @ColumnInfo(name = "created_at_utc") val createdAtUtc: Long,
)

data class StoredInjectionEvent(
    val id: UUID,
    val startedAtUtc: Instant,
    val completedAtUtc: Instant,
    val eventLocalDate: LocalDate,
    val timezoneOffsetMinutes: Int,
    val intensity: Intensity,
    val source: EntrySource,
    val phraseId: PhraseId,
    val animationDurationMs: Long,
    val interruptionCount: Int,
    val appVersion: String,
    val createdAtUtc: Instant,
)

internal fun StoredInjectionEvent.toEntity() = InjectionEventEntity(
    id = id.toString(),
    startedAtUtc = startedAtUtc.toEpochMilli(),
    completedAtUtc = completedAtUtc.toEpochMilli(),
    eventLocalDate = eventLocalDate.toString(),
    timezoneOffsetMinutes = timezoneOffsetMinutes,
    intensity = intensity.value,
    source = source.name.lowercase(),
    phraseId = phraseId.value,
    animationDurationMs = animationDurationMs,
    interruptionCount = interruptionCount,
    appVersion = appVersion,
    createdAtUtc = createdAtUtc.toEpochMilli(),
)

internal fun InjectionEventEntity.toStoredEvent() = StoredInjectionEvent(
    id = UUID.fromString(id),
    startedAtUtc = Instant.ofEpochMilli(startedAtUtc),
    completedAtUtc = Instant.ofEpochMilli(completedAtUtc),
    eventLocalDate = LocalDate.parse(eventLocalDate),
    timezoneOffsetMinutes = timezoneOffsetMinutes,
    intensity = requireNotNull(Intensity.from(intensity)),
    source = EntrySource.valueOf(source.uppercase()),
    phraseId = PhraseId(phraseId),
    animationDurationMs = animationDurationMs,
    interruptionCount = interruptionCount,
    appVersion = appVersion,
    createdAtUtc = Instant.ofEpochMilli(createdAtUtc),
)
