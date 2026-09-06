package com.maeumjaro.app.feature.analytics

import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class JsonExportControllerTest {
    @Test fun `preparation and sharing use their injected dispatchers`() = runTest {
        val io = StandardTestDispatcher(testScheduler)
        val main = StandardTestDispatcher(testScheduler)
        val calls = mutableListOf<String>()
        val result = JsonExportController(
            prepare = { calls += "prepare"; File("json") },
            share = { calls += "share" },
            ioDispatcher = io,
            mainDispatcher = main,
        ).export()

        assertEquals(JsonExportOperationResult.Success, result)
        assertEquals(listOf("prepare", "share"), calls)
    }

    @Test fun `preparation and sharing failures are retryable`() = runTest {
        val io = StandardTestDispatcher(testScheduler)
        val preparationFailure = JsonExportController(
            prepare = { error("storage unavailable") },
            share = {},
            ioDispatcher = io,
            mainDispatcher = io,
        ).export()
        val sharingFailure = JsonExportController(
            prepare = { File("json") },
            share = { error("sharesheet unavailable") },
            ioDispatcher = io,
            mainDispatcher = io,
        ).export()

        assertEquals(JsonExportOperationResult.Failure, preparationFailure)
        assertEquals(JsonExportOperationResult.Failure, sharingFailure)
    }

    @Test(expected = CancellationException::class)
    fun `cancellation is not converted to failure`() = runTest {
        val cancellation = CancellationException("cancelled")
        JsonExportController(
            prepare = { throw cancellation },
            share = {},
            ioDispatcher = StandardTestDispatcher(testScheduler),
            mainDispatcher = StandardTestDispatcher(testScheduler),
        ).export()
    }
}
