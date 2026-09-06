package com.maeumjaro.app.feature.export

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ExportShareIntentTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun fileProviderIsNonExportedAndGrantsUriPermissions() {
        val info = context.packageManager.getProviderInfo(
            android.content.ComponentName(context, "androidx.core.content.FileProvider"), 0,
        )

        assertEquals(false, info.exported)
        assertEquals(true, info.grantUriPermissions)
    }

    @Test
    fun shareIntentCarriesContentUriAndReadGrant() {
        val file = File(context.cacheDir, "exports/test-share.csv").apply {
            parentFile!!.mkdirs()
            writeText("test")
        }

        val intent = ExportShareIntent.create(context, file)

        assertEquals(Intent.ACTION_SEND, intent.action)
        assertEquals("text/csv", intent.type)
        assertNotNull(intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM))
        assertTrue(intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
        assertEquals("content", intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)!!.scheme)
    }

    @Test
    fun emptyExportDoesNotProduceAFileToShare() {
        val fileStore = ExportFileStore(context)

        val result = fileStore.writeCsv(emptyList())

        assertEquals(null, result)
    }
}
