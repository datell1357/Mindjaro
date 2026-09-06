package com.maeumjaro.app.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface CustomPhraseDao {
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(entity: CustomPhraseEntity)

    @Query("SELECT * FROM custom_phrases ORDER BY created_at_utc ASC, id ASC")
    suspend fun all(): List<CustomPhraseEntity>

    @Query("SELECT * FROM custom_phrases WHERE id = :id LIMIT 1")
    suspend fun find(id: String): CustomPhraseEntity?

    @Query("UPDATE custom_phrases SET text = :text, tone = :tone, category = :category, validation_state = :validationState, revision = revision + 1, updated_at_utc = :updatedAtUtc WHERE id = :id AND archived = 0 AND revision = :expectedRevision")
    suspend fun update(id: String, text: String, tone: String, category: String, validationState: String, expectedRevision: Int, updatedAtUtc: Long): Int

    @Query("UPDATE custom_phrases SET archived = 1, revision = revision + 1, updated_at_utc = :updatedAtUtc WHERE id = :id AND archived = 0")
    suspend fun archive(id: String, updatedAtUtc: Long): Int
}
