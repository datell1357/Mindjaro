package com.maeumjaro.app.feature.export

import android.content.Context
import java.io.File
import java.util.UUID

class ExportFileStore(private val context: Context) {
    fun writeCsv(events: List<com.maeumjaro.app.data.local.StoredInjectionEvent>): File? {
        val bytes = CsvHistoryExporter.encode(events) ?: return null
        val directory = File(context.cacheDir, "exports").apply { mkdirs() }
        return File(directory, "maeumjaro-history-${UUID.randomUUID()}.csv").also { it.writeBytes(bytes) }
    }

    fun writeJson(bytes: ByteArray, fileName: String): File {
        val directory = File(context.cacheDir, "exports").apply { mkdirs() }
        return File(directory, fileName.replace(Regex("[^A-Za-z0-9._-]"), "_"))
            .also { it.writeBytes(bytes) }
    }
}
