package com.maeumjaro.app.feature.shell

import android.app.UiAutomation
import android.content.ContentValues
import android.os.Environment
import android.provider.MediaStore
import android.util.Xml
import android.view.accessibility.AccessibilityNodeInfo
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.design.MaeumjaroTheme
import java.io.File
import java.io.StringWriter
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CompletionFallbackTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun unsafePhraseRendersSafeFallbackWithoutInternalErrorText() {
        val unsafe = Phrase(
            id = PhraseId("unsafe-instrumentation"),
            text = "효능을 보장합니다",
            category = PhraseCategory.AUTONOMY,
            tone = PhraseTone.NEUTRAL,
            intensities = setOf(checkNotNull(Intensity.from(3))),
            safetyReviewed = false,
        )
        composeRule.setContent {
            MaeumjaroTheme { CompletionShell(onBack = {}, phrase = unsafe) }
        }

        composeRule.onNodeWithText(SafePhraseCatalog.fallback.text).assertIsDisplayed()
        composeRule.onAllNodesWithText("오류", substring = true).assertCountEquals(0)
        composeRule.waitForIdle()
        val uiAutomation = InstrumentationRegistry.getInstrumentation().uiAutomation
        uiAutomation.captureFallbackEvidence(InstrumentationRegistry.getInstrumentation().targetContext)
    }

    private fun UiAutomation.captureFallbackEvidence(context: android.content.Context) {
        val pngPath = "/sdcard/Download/task5-safe-fallback.png"
        executeShellCommand("screencap -p $pngPath").use { }
        val hierarchy = File.createTempFile("task5-safe-fallback-", ".xml", context.cacheDir)
        hierarchy.writeText(accessibilityHierarchyXml())
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "task5-safe-fallback.xml")
            put(MediaStore.MediaColumns.MIME_TYPE, "application/xml")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val uri = checkNotNull(
            context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values),
        )
        context.contentResolver.openOutputStream(uri).use { output ->
            checkNotNull(output).use { it.write(hierarchy.readBytes()) }
        }
        check(hierarchy.delete())
    }

    private fun UiAutomation.accessibilityHierarchyXml(): String {
        val writer = StringWriter()
        val serializer = Xml.newSerializer().apply {
            setOutput(writer)
            startDocument("UTF-8", true)
        }
        rootInActiveWindow?.writeXml(serializer)
        serializer.endDocument()
        return writer.toString()
    }

    private fun AccessibilityNodeInfo.writeXml(serializer: org.xmlpull.v1.XmlSerializer) {
        val bounds = android.graphics.Rect().also(::getBoundsInScreen)
        serializer.startTag(null, "node")
        serializer.attribute(null, "class", className?.toString().orEmpty())
        serializer.attribute(null, "text", text?.toString().orEmpty())
        serializer.attribute(null, "content-desc", contentDescription?.toString().orEmpty())
        serializer.attribute(null, "bounds", bounds.toShortString())
        for (index in 0 until childCount) {
            getChild(index)?.let { child ->
                child.writeXml(serializer)
            }
        }
        serializer.endTag(null, "node")
    }
}
