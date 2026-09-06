package com.maeumjaro.app.feature.completion

import com.maeumjaro.app.core.CommitResult
import com.maeumjaro.app.core.Committing
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.EventTime
import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.reduce
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Test

class CompletionBaselineCharacterizationTest {
    @Test
    fun `inserted and duplicate callbacks both complete the frozen reducer draft`() {
        val draft = InjectionEventDraft(
            UUID.fromString("00000000-0000-0000-0000-000000000007"),
            checkNotNull(Intensity.from(3)),
            EntrySource.APP,
            Instant.parse("2026-09-05T14:59:58Z"),
            EventTime.at(Instant.parse("2026-09-05T15:00:01Z"), ZoneId.of("Asia/Seoul")),
            2,
        )

        assertEquals(draft, (reduce(Committing(draft), CommitResult.Inserted) as com.maeumjaro.app.core.Completed).draft)
        assertEquals(draft, (reduce(Committing(draft), CommitResult.AlreadyExists) as com.maeumjaro.app.core.Completed).draft)
    }
}
