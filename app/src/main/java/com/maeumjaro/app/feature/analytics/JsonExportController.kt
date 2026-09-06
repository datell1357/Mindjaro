package com.maeumjaro.app.feature.analytics

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

sealed interface JsonExportOperationResult {
    data object Success : JsonExportOperationResult
    data object Failure : JsonExportOperationResult
}

/** Coordinates private payload preparation/cache writing off the UI thread and sharing on main. */
class JsonExportController(
    private val prepare: suspend () -> File,
    private val share: (File) -> Unit,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val mainDispatcher: CoroutineDispatcher = Dispatchers.Main.immediate,
) {
    suspend fun export(): JsonExportOperationResult = try {
        val file = withContext(ioDispatcher) { prepare() }
        withContext(mainDispatcher) { share(file) }
        JsonExportOperationResult.Success
    } catch (cancellation: CancellationException) {
        throw cancellation
    } catch (_: Exception) {
        JsonExportOperationResult.Failure
    }
}
