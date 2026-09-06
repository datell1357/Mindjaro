package com.maeumjaro.app.feature.export

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

object ExportShareIntent {
    const val authority = "com.maeumjaro.app.fileprovider"

    fun create(context: Context, file: File): Intent = Intent(Intent.ACTION_SEND).apply {
        type = if (file.extension.equals("json", true)) "application/json" else "text/csv"
        putExtra(Intent.EXTRA_STREAM, FileProvider.getUriForFile(context, authority, file))
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
}
