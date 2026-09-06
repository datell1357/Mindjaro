package com.maeumjaro.app.core

fun traceJson(states: List<RitualState>): String {
    val names = states.map { it::class.simpleName ?: "Unknown" }
    val drafts = states.mapNotNull(RitualState::frozenDraftOrNull)
    val attempts = states.filterIsInstance<Committing>().map { it.draft.sessionId.toString() }
    return buildString {
        append("{\n")
        append("  \"states\": [").append(names.joinToString { "\"$it\"" }).append("],\n")
        append("  \"frozenDraftCount\": ").append(drafts.distinctBy { System.identityHashCode(it) }.size).append(",\n")
        append("  \"interruptionCount\": ").append(drafts.first().interruptionCount).append(",\n")
        append("  \"commitAttemptSessionIds\": [").append(attempts.joinToString { "\"$it\"" }).append("],\n")
        append("  \"terminalState\": \"").append(names.last()).append("\"\n")
        append("}\n")
    }
}
