package com.maeumjaro.app.core

import kotlin.random.Random

@JvmInline value class PhraseId(val value: String)

enum class PhraseCategory { SEPARATION, IMPERMANENCE, AUTONOMY, REDIRECT, NONJUDGMENT }
enum class PhraseTone { GENTLE, NEUTRAL, FIRM, AUTOMATIC }

data class Phrase(
    val id: PhraseId,
    val text: String,
    val category: PhraseCategory,
    val tone: PhraseTone,
    val intensities: Set<Intensity>,
    val safetyReviewed: Boolean,
)

object SafePhraseFallback {
    val phrase = Phrase(
        id = PhraseId("builtin-safe-fallback"),
        text = "잠시 멈추고, 지금의 선택을 천천히 바라봐요.",
        category = PhraseCategory.NONJUDGMENT,
        tone = PhraseTone.NEUTRAL,
        intensities = (1..5).mapNotNull(Intensity::from).toSet(),
        safetyReviewed = true,
    )
}

class PhraseSelector(private val random: Random) {
    fun select(request: PhraseSelection): Phrase {
        val recent = request.recentPhraseIds.takeLast(10).toSet()
        val eligible = request.pool.filter { phrase ->
            phrase.safetyReviewed && request.intensity in phrase.intensities && phrase.id !in recent && phrase.category != request.previousCategory
        }
        return eligible.randomOrNull(random) ?: SafePhraseFallback.phrase
    }
}

data class PhraseSelection(
    val pool: List<Phrase>,
    val intensity: Intensity,
    val recentPhraseIds: List<PhraseId>,
    val previousCategory: PhraseCategory?,
)
