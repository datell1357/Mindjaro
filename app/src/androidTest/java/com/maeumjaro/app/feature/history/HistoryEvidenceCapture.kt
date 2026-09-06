package com.maeumjaro.app.feature.history

import android.app.UiAutomation
import android.content.ContentValues
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.StringWriter
import org.xmlpull.v1.XmlSerializer

internal fun captureHistoryEvidence(name: String): String {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val automation = instrumentation.uiAutomation
    ParcelFileDescriptor.AutoCloseInputStream(
        automation.executeShellCommand("screencap -p /sdcard/Download/$name.png"),
    ).use { it.readBytes() }
    val xml = automation.accessibilityHierarchyXml()
    val context = instrumentation.targetContext
    val file = File.createTempFile("$name-", ".xml", context.cacheDir).apply { writeText(xml) }
    val values = ContentValues().apply {
        put(MediaStore.MediaColumns.DISPLAY_NAME, "$name.xml")
        put(MediaStore.MediaColumns.MIME_TYPE, "application/xml")
        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
    }
    val uri = checkNotNull(context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values))
    context.contentResolver.openOutputStream(uri, "wt").use { output ->
        checkNotNull(output).use { it.write(file.readBytes()) }
    }
    check(file.delete())
    return xml
}

private fun UiAutomation.accessibilityHierarchyXml(): String {
    val writer = StringWriter()
    val serializer = android.util.Xml.newSerializer().apply {
        setOutput(writer)
        startDocument("UTF-8", true)
    }
    rootInActiveWindow?.writeXml(serializer)
    serializer.endDocument()
    return writer.toString()
}

private fun AccessibilityNodeInfo.writeXml(serializer: XmlSerializer) {
    val bounds = android.graphics.Rect().also(::getBoundsInScreen)
    serializer.startTag(null, "node")
    serializer.attribute(null, "class", className?.toString().orEmpty())
    serializer.attribute(null, "text", text?.toString().orEmpty())
    serializer.attribute(null, "content-desc", contentDescription?.toString().orEmpty())
    serializer.attribute(null, "enabled", isEnabled.toString())
    serializer.attribute(null, "selected", isSelected.toString())
    serializer.attribute(null, "bounds", bounds.toShortString())
    for (index in 0 until childCount) getChild(index)?.let { child -> child.writeXml(serializer) }
    serializer.endTag(null, "node")
}
