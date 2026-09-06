package com.maeumjaro.app.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

class EventTimeTest {
    @Test fun `Given KST midnight instants When converted Then stored dates cross on local midnight`() {
        val zone = ZoneId.of("Asia/Seoul")
        val before = EventTime.at(Instant.parse("2026-09-04T14:59:30Z"), zone)
        val after = EventTime.at(Instant.parse("2026-09-04T15:00:05Z"), zone)
        assertEquals(LocalDate.parse("2026-09-04"), before.localDate)
        assertEquals(LocalDate.parse("2026-09-05"), after.localDate)
        assertEquals(9 * 3600, before.offsetSeconds)
    }

    @Test fun `Given stored DST event When current zone changes Then local date hour and offset stay stable`() {
        val stored = EventTime.at(Instant.parse("2026-11-01T05:30:00Z"), ZoneId.of("America/New_York"))
        val viewedElsewhere = stored.localDateTime
        assertEquals(LocalDate.parse("2026-11-01"), viewedElsewhere.toLocalDate())
        assertEquals(1, viewedElsewhere.hour)
        assertEquals(-4 * 3600, stored.offsetSeconds)
    }
}
