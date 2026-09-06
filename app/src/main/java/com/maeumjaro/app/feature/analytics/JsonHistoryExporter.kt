package com.maeumjaro.app.feature.analytics

import com.maeumjaro.app.data.local.InjectionEventRepository
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant

class JsonExport(
    private val repository: InjectionEventRepository,
    private val entitlements: EntitlementRepository,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    suspend fun execute(exportedAtUtc: Instant): AccessResult<JsonExportResult> {
        return withContext(ioDispatcher) {
            if (entitlements.current() != Entitlement.PRO) return@withContext AccessResult.Locked
            val events = repository.chronologicalExport().sortedWith(compareBy({ it.completedAtUtc }, { it.id.toString() }))
            val payload = JsonObject(linkedMapOf(
                "schemaVersion" to JsonPrimitive("maeumjaro-export-v1"),
                "exportedAtUtc" to JsonPrimitive(exportedAtUtc.toString()),
                "events" to JsonArray(events.map { event -> JsonObject(linkedMapOf(
                    "completedAtUTC" to JsonPrimitive(event.completedAtUtc.toString()),
                    "eventLocalDate" to JsonPrimitive(event.eventLocalDate.toString()),
                    "timezoneOffsetMinutes" to JsonPrimitive(event.timezoneOffsetMinutes),
                    "intensity" to JsonPrimitive(event.intensity.value),
                    "source" to JsonPrimitive(event.source.name.lowercase()),
                    "phraseID" to JsonPrimitive(event.phraseId.value),
                    "eventID" to JsonPrimitive(event.id.toString()),
                    "startedAtUTC" to JsonPrimitive(event.startedAtUtc.toString()),
                    "animationDurationMs" to JsonPrimitive(event.animationDurationMs),
                    "interruptionCount" to JsonPrimitive(event.interruptionCount),
                    "appVersion" to JsonPrimitive(event.appVersion),
                    "createdAtUTC" to JsonPrimitive(event.createdAtUtc.toString()),
                )) })
            ))
            AccessResult.Unlocked(JsonExportResult(Json.encodeToString(JsonObject.serializer(), payload).toByteArray(Charsets.UTF_8)))
        }
    }
}

/** UI/integration boundary for sharing an already-created JSON payload. */
data class JsonSharePayload(
    val bytes: ByteArray,
    val mimeType: String,
    val fileName: String,
)

fun JsonExportResult.asSharePayload(): JsonSharePayload = JsonSharePayload(bytes, mimeType, suggestedFileName)
