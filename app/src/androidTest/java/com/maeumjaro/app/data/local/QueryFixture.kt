package com.maeumjaro.app.data.local

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

internal data class QueryFixture(
    val events: List<StoredInjectionEvent>,
    val range: StoredDateRange,
) {
    companion object {
        fun create(): QueryFixture {
            val firstDate = LocalDate.parse("2026-05-17")
            val events = (0 until 112).flatMap { dayIndex ->
                val date = firstDate.plusDays(dayIndex.toLong())
                List(dayIndex % 4) { eventIndex -> event(dayIndex, eventIndex, date) }
            }
            return QueryFixture(events, StoredDateRange(firstDate, firstDate.plusDays(111)))
        }

        fun oracleJson(fixture: QueryFixture): String {
            val grouped = fixture.events
                .groupBy(StoredInjectionEvent::eventLocalDate)
            return encode(fixture.dates().map { date ->
                val events = grouped[date].orEmpty()
                DailyAggregate(date, events.size, events.sumOf { it.intensity.value })
            })
        }

        fun actualJson(fixture: QueryFixture, aggregates: List<DailyAggregate>): String {
            val byDate = aggregates.associateBy(DailyAggregate::date)
            return encode(fixture.dates().map { date -> byDate[date] ?: DailyAggregate(date, 0, 0) })
        }

        private fun encode(aggregates: List<DailyAggregate>): String = buildString {
            append("{\"schema\":\"maeumjaro-query-fixture-v1\",\"days\":[")
            aggregates.forEachIndexed { index, aggregate ->
                if (index > 0) append(',')
                append("{\"date\":\"")
                append(aggregate.date)
                append("\",\"count\":")
                append(aggregate.count)
                append(",\"intensitySum\":")
                append(aggregate.intensitySum)
                append('}')
            }
            append("]}")
        }

        private fun event(dayIndex: Int, eventIndex: Int, date: LocalDate): StoredInjectionEvent {
            val completedAt = 1_700_000_000_000L + dayIndex * 86_400_000L + eventIndex
            return StoredInjectionEvent(
                id = UUID.nameUUIDFromBytes("day-$dayIndex-event-$eventIndex".toByteArray()),
                startedAtUtc = Instant.ofEpochMilli(completedAt - 1_800),
                completedAtUtc = Instant.ofEpochMilli(completedAt),
                eventLocalDate = date,
                timezoneOffsetMinutes = if (dayIndex < 56) -420 else 540,
                intensity = requireNotNull(Intensity.from((dayIndex + eventIndex) % 5 + 1)),
                source = if (eventIndex % 2 == 0) EntrySource.APP else EntrySource.WIDGET,
                phraseId = PhraseId("phrase-${dayIndex % 3}"),
                animationDurationMs = 1_800,
                interruptionCount = eventIndex,
                appVersion = "0.1.0",
                createdAtUtc = Instant.ofEpochMilli(completedAt),
            )
        }
    }

    private fun dates(): List<LocalDate> = generateSequence(range.first) { date ->
        date.plusDays(1).takeIf { it <= range.lastInclusive }
    }.toList()
}
