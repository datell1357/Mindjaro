package com.maeumjaro.app.data.local

import android.content.Context
import android.os.ParcelFileDescriptor
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.room.testing.MigrationTestHelper
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MaeumjaroDatabaseTest {
    private lateinit var database: MaeumjaroDatabase
    private lateinit var repository: InjectionEventRepository

    @Before
    fun givenAnEmptyInMemoryDatabase() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = MaeumjaroDatabase.inMemory(context)
        repository = RoomInjectionEventRepository(database)
    }

    @After
    fun closeDatabase() {
        database.close()
    }

    @Test
    fun insertReturnsAlreadyExistsWhenUuidRepeats() = runBlocking {
        // Given
        val event = fixture("same-id")

        // When
        val results = listOf(repository.insertCompletedEvent(event), repository.insertCompletedEvent(event))

        // Then
        assertEquals(listOf(EventInsertResult.Inserted, EventInsertResult.AlreadyExists), results)
        assertEquals(1, database.injectionEventDao().rowCount())
    }

    @Test
    fun concurrentInsertCreatesExactlyOneRowWhenUuidRepeats() = runBlocking {
        // Given
        val event = fixture("concurrent-id")

        // When
        val results = withContext(Dispatchers.Default) {
            List(2) { async { repository.insertCompletedEvent(event) } }.awaitAll()
        }

        // Then
        assertEquals(1, results.count { it == EventInsertResult.Inserted })
        assertEquals(1, results.count { it == EventInsertResult.AlreadyExists })
        assertEquals(1, database.injectionEventDao().rowCount())
    }

    @Test
    fun sqlRejectsIntensityOutsideOneThroughFive() {
        // Given
        val sql = """
            INSERT INTO injection_events(
                id, started_at_utc, completed_at_utc, event_local_date,
                timezone_offset_minutes, intensity, source, phrase_id,
                animation_duration_ms, interruption_count, app_version, created_at_utc
            ) VALUES ('invalid', 1, 2, '2026-09-05', 540, 6, 'app', 'phrase', 1200, 0, '1', 2)
        """.trimIndent()

        // When
        val failure = assertThrows(Exception::class.java) { database.openHelper.writableDatabase.execSQL(sql) }

        // Then
        assertEquals(true, failure.message?.isNotBlank())
        assertEquals(0, database.injectionEventDao().rowCount())
    }

    @Test
    fun sqlRejectsUnknownCompletionSource() {
        // Given
        val sql = """
            INSERT INTO injection_events(
                id, started_at_utc, completed_at_utc, event_local_date,
                timezone_offset_minutes, intensity, source, phrase_id,
                animation_duration_ms, interruption_count, app_version, created_at_utc
            ) VALUES ('invalid-source', 1, 2, '2026-09-05', 540, 3, 'remote', 'phrase', 1200, 0, '1', 2)
        """.trimIndent()

        // When
        val failure = assertThrows(Exception::class.java) { database.openHelper.writableDatabase.execSQL(sql) }

        // Then
        assertEquals(true, failure.message?.isNotBlank())
        assertEquals(0, database.injectionEventDao().rowCount())
    }

    @Test
    fun storedLocalDateControlsTodayAndRangeAcrossOffsets() = runBlocking {
        // Given
        repository.insertCompletedEvent(
            fixture("seoul").copy(
                eventLocalDate = LocalDate.parse("2026-09-05"),
                timezoneOffsetMinutes = 540,
                intensity = intensity(2),
            ),
        )
        repository.insertCompletedEvent(
            fixture("la").copy(
                eventLocalDate = LocalDate.parse("2026-09-04"),
                timezoneOffsetMinutes = -420,
                intensity = intensity(5),
            ),
        )

        // When
        val today = repository.totalsForStoredDate(LocalDate.parse("2026-09-05"))
        val range = repository.eventsInStoredDateRange(
            StoredDateRange(LocalDate.parse("2026-09-04"), LocalDate.parse("2026-09-05")),
        )

        // Then
        assertEquals(DailyTotals(LocalDate.parse("2026-09-05"), 1, 2), today)
        assertEquals(listOf(eventId("la"), eventId("seoul")), range.map { it.id })
    }

    @Test
    fun eventOlderThanFiftyTwoWeeksRemainsStored() = runBlocking {
        // Given
        repository.insertCompletedEvent(fixture("old").copy(eventLocalDate = LocalDate.parse("2024-01-01")))
        repository.insertCompletedEvent(fixture("recent"))

        // When
        repository.fiftyTwoWeekDailyAggregates(LocalDate.parse("2026-09-05"))

        // Then
        assertEquals(2, database.injectionEventDao().rowCount())
        assertEquals(eventId("old"), repository.event(eventId("old"))?.id)
    }

    @Test
    fun entitlementIsAbsentAndCannotAlterStoredRows() = runBlocking {
        // Given
        repository.insertCompletedEvent(fixture("free-or-pro"))

        // When
        val fields = database.openHelper.readableDatabase.query("PRAGMA table_info(injection_events)").use { cursor ->
            buildList {
                val nameIndex = cursor.getColumnIndexOrThrow("name")
                while (cursor.moveToNext()) add(cursor.getString(nameIndex))
            }
        }

        // Then
        assertEquals(false, fields.any { it.contains("entitlement", ignoreCase = true) || it.contains("pro", ignoreCase = true) })
        assertEquals(1, database.injectionEventDao().rowCount())
    }

    @Test
    fun editIntensityAndConfirmedDeletesRecalculateAggregates() = runBlocking {
        // Given
        repository.insertCompletedEvent(fixture("one").copy(intensity = intensity(2)))
        repository.insertCompletedEvent(fixture("two"))
        val date = LocalDate.parse("2026-09-05")

        // When
        val edit = repository.editIntensity(eventId("one"), intensity(5))
        val singleDelete = repository.deleteEvent(eventId("two"), DeletionDecision.Confirmed)
        val edited = repository.event(eventId("one"))

        // Then
        assertEquals(EditResult.Updated, edit)
        assertEquals(DeleteResult.Deleted(1), singleDelete)
        assertEquals(fixture("one").copy(intensity = intensity(5)), edited)
        assertEquals(DailyTotals(date, 1, 5), repository.totalsForStoredDate(date))
    }

    @Test
    fun canceledAndBulkDeleteHaveExplicitOutcomes() = runBlocking {
        // Given
        repository.insertCompletedEvent(fixture("one"))
        repository.insertCompletedEvent(fixture("two"))
        val checksumBeforeCancel = repository.chronologicalExport().hashCode()

        // When
        val canceled = repository.deleteEvent(eventId("one"), DeletionDecision.Canceled)
        val checksumAfterCancel = repository.chronologicalExport().hashCode()
        val deleted = repository.deleteEvents(setOf(eventId("one"), eventId("two")), DeletionDecision.Confirmed)

        // Then
        assertEquals(DeleteResult.Canceled, canceled)
        assertEquals(checksumBeforeCancel, checksumAfterCancel)
        assertEquals(DeleteResult.Deleted(2), deleted)
        assertEquals(0, database.injectionEventDao().rowCount())
    }

    @Test
    fun confirmedDeleteAllRemovesEveryEventAndLeavesEmptyExport() = runBlocking {
        repository.insertCompletedEvent(fixture("all-one"))
        repository.insertCompletedEvent(fixture("all-two"))

        val result = repository.deleteAllEvents(DeletionDecision.Confirmed)

        assertEquals(DeleteResult.Deleted(2), result)
        assertEquals(0, database.injectionEventDao().rowCount())
        assertEquals(emptyList<StoredInjectionEvent>(), repository.chronologicalExport())
    }

    @Test
    fun canceledDeleteAllPreservesEveryEvent() = runBlocking {
        repository.insertCompletedEvent(fixture("cancel-all-one"))
        repository.insertCompletedEvent(fixture("cancel-all-two"))

        val result = repository.deleteAllEvents(DeletionDecision.Canceled)

        assertEquals(DeleteResult.Canceled, result)
        assertEquals(2, database.injectionEventDao().rowCount())
    }

    @Test
    fun chronologicalExportUsesCompletionTimeThenUuid() = runBlocking {
        // Given
        repository.insertCompletedEvent(
            fixture("z").copy(
                completedAtUtc = Instant.ofEpochMilli(20),
                createdAtUtc = Instant.ofEpochMilli(20),
            ),
        )
        repository.insertCompletedEvent(fixture("b"))
        repository.insertCompletedEvent(fixture("a"))
        val tiesAscending = listOf(eventId("a"), eventId("b")).sortedBy(UUID::toString)

        // When
        val exported = repository.chronologicalExport()

        // Then
        assertEquals(tiesAscending + eventId("z"), exported.map { it.id })
        assertEquals(listOf(eventId("z")) + tiesAscending.reversed(), repository.latest(10).map { it.id })
    }

    @Test
    fun oneHundredTwelveDayFixtureMatchesPureOracleByteForByte() = runBlocking {
        // Given
        val fixture = QueryFixture.create()
        fixture.events.forEach { repository.insertCompletedEvent(it) }

        // When
        val actual = QueryFixture.actualJson(fixture, repository.dailyAggregates(fixture.range))
        val expected = QueryFixture.oracleJson(fixture)

        // Then
        assertEquals(expected, actual)
        val fixturePath = "/sdcard/Download/maeumjaro-task3-query-fixture.json"
        val stagingFile = requireNotNull(
            ApplicationProvider.getApplicationContext<Context>().getExternalFilesDir(null),
        ).resolve("query-fixture.json")
        stagingFile.writeText(actual)
        assertEquals(actual.toByteArray().size.toLong(), stagingFile.length())
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        ParcelFileDescriptor.AutoCloseInputStream(
            automation.executeShellCommand("cp ${stagingFile.absolutePath} $fixturePath"),
        ).use { it.readBytes() }
        Unit
    }

    @Test
    fun schemaOneFixtureRetainsEveryFieldWhenOpenedAtCurrentVersion() = runBlocking {
        // Given
        val helper = MigrationTestHelper(
            InstrumentationRegistry.getInstrumentation(),
            MaeumjaroDatabase::class.java,
        )
        val databaseName = "maeumjaro-migration-${System.nanoTime()}"
        helper.createDatabase(databaseName, 1).apply {
            execSQL(
                """
                INSERT INTO injection_events VALUES (
                    '00000000-0000-0000-0000-000000000001', 111, 222, '2026-09-05',
                    -330, 4, 'widget', 'phrase-migration', 2200, 3, '0.1.0', 223
                )
                """.trimIndent(),
            )
            close()
        }

        // When
        val migrated = helper.runMigrationsAndValidate(
            databaseName,
            MaeumjaroDatabase.VERSION,
            true,
            *MaeumjaroMigrations.ALL,
        )

        // Then
        migrated.query("SELECT * FROM injection_events").use { cursor ->
            assertEquals(true, cursor.moveToFirst())
            assertEquals("00000000-0000-0000-0000-000000000001", cursor.getString(0))
            assertEquals(111L, cursor.getLong(1))
            assertEquals(222L, cursor.getLong(2))
            assertEquals("2026-09-05", cursor.getString(3))
            assertEquals(-330, cursor.getInt(4))
            assertEquals(4, cursor.getInt(5))
            assertEquals("widget", cursor.getString(6))
            assertEquals("phrase-migration", cursor.getString(7))
            assertEquals(2200L, cursor.getLong(8))
            assertEquals(3, cursor.getInt(9))
            assertEquals("0.1.0", cursor.getString(10))
            assertEquals(223L, cursor.getLong(11))
        }
        migrated.query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'custom_phrases'").use { cursor ->
            assertEquals(true, cursor.moveToFirst())
        }
        migrated.query("SELECT COUNT(*) FROM custom_phrases").use { cursor ->
            assertEquals(true, cursor.moveToFirst())
            assertEquals(0, cursor.getInt(0))
        }
        migrated.execSQL(
            "INSERT INTO custom_phrases " +
                "(id, text, tone, category, created_at_utc, validation_state, archived, revision, updated_at_utc) " +
                "VALUES ('custom:00000000-0000-4000-8000-000000000001', '멈춰 바라봐요', 'NEUTRAL', 'AUTONOMY', 1, 'VALID', 0, 1, 1)",
        )
        migrated.query("SELECT text FROM custom_phrases WHERE id = 'custom:00000000-0000-4000-8000-000000000001'").use { cursor ->
            assertEquals(true, cursor.moveToFirst())
            assertEquals("멈춰 바라봐요", cursor.getString(0))
        }
        assertEquals(2, MaeumjaroDatabase.VERSION)
        migrated.close()
    }

    private fun fixture(label: String) = StoredInjectionEvent(
        id = eventId(label),
        startedAtUtc = Instant.ofEpochMilli(8),
        completedAtUtc = Instant.ofEpochMilli(10),
        eventLocalDate = LocalDate.parse("2026-09-05"),
        timezoneOffsetMinutes = 540,
        intensity = intensity(3),
        source = EntrySource.APP,
        phraseId = PhraseId("phrase-stable"),
        animationDurationMs = 1_800,
        interruptionCount = 1,
        appVersion = "0.1.0",
        createdAtUtc = Instant.ofEpochMilli(10),
    )

    private fun eventId(label: String): UUID = UUID.nameUUIDFromBytes(label.toByteArray())

    private fun intensity(value: Int): Intensity = requireNotNull(Intensity.from(value))
}
