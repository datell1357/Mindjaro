package com.maeumjaro.app.data.local

import androidx.room.withTransaction
import com.maeumjaro.app.content.ContentPolicy
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.feature.customization.CustomPhrase
import com.maeumjaro.app.feature.customization.CustomPhraseRepository
import com.maeumjaro.app.feature.customization.CustomPhraseValidator
import java.util.UUID

/** Durable custom phrase store. Built-ins and the fallback can never be admitted. */
class RoomCustomPhraseRepository(
    private val database: MaeumjaroDatabase,
    private val clock: () -> Long = { System.currentTimeMillis() },
) : CustomPhraseRepository {
    private val dao = database.customPhraseDao()
    private val validator = CustomPhraseValidator()

    override suspend fun save(phrase: CustomPhrase): CustomPhrase = database.withTransaction {
        requireCustomId(phrase.id)
        val validated = validate(phrase)
        require(!validated.archived) { "archived phrases are immutable" }
        dao.insert(validated.toEntity(clock()))
        validated
    }

    override suspend fun update(phrase: CustomPhrase): CustomPhrase = database.withTransaction {
        requireCustomId(phrase.id)
        val current = dao.find(phrase.id.value) ?: error("missing custom phrase")
        require(!current.archived) { "archived phrases are immutable" }
        check(dao.archive(phrase.id.value, clock()) == 1) { "custom phrase changed concurrently" }
        val revised = validate(phrase.copy(id = newId(), archived = false))
        dao.insert(revised.toEntity(clock()))
        revised
    }

    override suspend fun archive(id: PhraseId) {
        requireCustomId(id)
        dao.archive(id.value, clock())
    }

    override suspend fun all(): List<CustomPhrase> = dao.all().map(CustomPhraseEntity::toCustomPhrase)

    override suspend fun resolve(id: PhraseId): CustomPhrase? =
        if (id.value.startsWith("custom:")) dao.find(id.value)?.toCustomPhrase() else null

    private fun validate(phrase: CustomPhrase): CustomPhrase {
        val result = validator.validate(phrase.text)
        require(phrase.text.trim().length <= 120) { "custom phrase is too long" }
        require(ContentPolicy.violations(phrase.text.trim()).isEmpty() || result.state.name == "UNSAFE")
        return phrase.copy(text = phrase.text.trim(), validationState = result.state)
    }

    private fun requireCustomId(id: PhraseId) {
        require(CUSTOM_ID.matches(id.value)) { "custom phrase id must be custom:<UUID>" }
    }

    companion object {
        private val CUSTOM_ID = Regex("custom:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}")

        fun newId(): PhraseId = PhraseId("custom:${UUID.randomUUID()}")
    }
}
