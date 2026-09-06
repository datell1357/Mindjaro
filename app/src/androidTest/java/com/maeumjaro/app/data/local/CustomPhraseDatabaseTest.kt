package com.maeumjaro.app.data.local

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.feature.customization.CustomPhrase
import com.maeumjaro.app.feature.customization.PhraseValidationState
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CustomPhraseDatabaseTest {
    private lateinit var database: MaeumjaroDatabase
    private lateinit var repository: RoomCustomPhraseRepository

    @Before
    fun setUp() {
        database = MaeumjaroDatabase.inMemory(ApplicationProvider.getApplicationContext<Context>())
        repository = RoomCustomPhraseRepository(database) { 1_000L }
    }

    @After
    fun tearDown() = database.close()

    @Test
    fun saveRevalidatesAndRejectsBuiltInOrFallbackIds(): Unit {
        runBlocking {
            val phrase = phrase(RoomCustomPhraseRepository.newId(), "  잠시 멈춰 바라봐요  ")
            assertEquals(PhraseValidationState.VALID, repository.save(phrase).validationState)
            assertEquals("잠시 멈춰 바라봐요", repository.all().single().text)
            assertThrows(IllegalArgumentException::class.java) {
                runBlocking { repository.save(phrase(PhraseId("ground-001"), "안전한 문장")) }
            }
            assertNull(repository.resolve(PhraseId("builtin-safe-fallback")))
        }
    }

    @Test
    fun unsafePhraseIsStoredButNeverResolvedAsSelectorInput(): Unit {
        runBlocking {
            val saved = repository.save(phrase(RoomCustomPhraseRepository.newId(), "치료 효과가 있습니다"))
            assertEquals(PhraseValidationState.UNSAFE, saved.validationState)
            assertEquals(PhraseValidationState.UNSAFE, repository.all().single().validationState)
        }
    }

    @Test
    fun updateCreatesNewIdentityAndPreservesTheHistoricalPhrase(): Unit {
        runBlocking {
            val id = RoomCustomPhraseRepository.newId()
            repository.save(phrase(id, "처음 문장"))

            val updated = repository.update(phrase(id, "  바뀐 문장  "))

            assertEquals(true, repository.resolve(id)?.archived)
            assertEquals("처음 문장", repository.resolve(id)?.text)
            assertEquals("바뀐 문장", updated.text)
            assertEquals(false, updated.archived)
            assertEquals(false, updated.id == id)
        }
    }

    @Test
    fun archivedPhraseCannotBeUpdatedAndRemainsResolvableForHistory(): Unit {
        runBlocking {
            val id = RoomCustomPhraseRepository.newId()
            repository.save(phrase(id, "기록으로 남길 문장"))
            repository.archive(id)
            assertEquals(true, repository.resolve(id)?.archived)
            assertThrows(IllegalArgumentException::class.java) {
                runBlocking { repository.update(phrase(id, "바꾸려는 문장")) }
            }
            Unit
        }
    }

    @Test
    fun migrationCreatesCustomTableWithoutDroppingInjectionEvents() {
        val columns = database.openHelper.readableDatabase.query("PRAGMA table_info(custom_phrases)").use { cursor ->
            buildList {
                val index = cursor.getColumnIndexOrThrow("name")
                while (cursor.moveToNext()) add(cursor.getString(index))
            }
        }
        assertEquals(true, columns.containsAll(listOf("id", "text", "revision", "archived")))
        assertEquals(true, database.openHelper.readableDatabase.query("SELECT * FROM injection_events").use { !it.moveToFirst() })
    }

    private fun phrase(id: PhraseId, text: String) = CustomPhrase(
        id = id,
        text = text,
        tone = PhraseTone.NEUTRAL,
        category = PhraseCategory.AUTONOMY,
        createdAtEpochMillis = 1_000L,
    )
}
