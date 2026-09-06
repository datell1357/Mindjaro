package com.maeumjaro.app.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.feature.customization.CustomPhrase
import com.maeumjaro.app.feature.customization.PhraseValidationState

@Entity(
    tableName = "custom_phrases",
    indices = [Index(value = ["archived"])],
)
data class CustomPhraseEntity(
    @PrimaryKey val id: String,
    val text: String,
    val tone: String,
    val category: String,
    @ColumnInfo(name = "created_at_utc") val createdAtUtc: Long,
    @ColumnInfo(name = "validation_state") val validationState: String,
    val archived: Boolean,
    val revision: Int,
    @ColumnInfo(name = "updated_at_utc") val updatedAtUtc: Long,
)

internal fun CustomPhrase.toEntity(now: Long): CustomPhraseEntity = CustomPhraseEntity(
    id = id.value,
    text = text,
    tone = tone.name,
    category = category.name,
    createdAtUtc = createdAtEpochMillis,
    validationState = validationState.name,
    archived = archived,
    revision = 1,
    updatedAtUtc = now,
)

internal fun CustomPhraseEntity.toCustomPhrase(): CustomPhrase = CustomPhrase(
    id = PhraseId(id),
    text = text,
    tone = PhraseTone.valueOf(tone),
    category = PhraseCategory.valueOf(category),
    createdAtEpochMillis = createdAtUtc,
    validationState = PhraseValidationState.valueOf(validationState),
    archived = archived,
)
