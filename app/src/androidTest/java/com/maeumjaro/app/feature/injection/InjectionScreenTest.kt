package com.maeumjaro.app.feature.injection

import android.app.UiAutomation
import android.content.ContentValues
import android.os.Environment
import android.provider.MediaStore
import android.util.Xml
import android.view.accessibility.AccessibilityNodeInfo
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertRangeInfoEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.geometry.Offset
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.design.MaeumjaroTheme
import java.io.File
import java.io.StringWriter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InjectionScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun screenExposesStrengthStateProgressAndAccessibleActions() {
        var started = 0
        var paused = 0
        val state = fixture(progress = .42, hapticsEnabled = false)
        compose.setContent {
            InjectionScreen(
                state = state,
                onPointerDown = { _, _ -> },
                onPointerMoved = { _, _, _ -> },
                onPointerUp = { _, _ -> },
                onPointerCancelled = { _, _ -> },
                onAccessibilityStart = { started++ },
                onAccessibilityPause = { paused++ },
            )
        }

        compose.onNodeWithText("강도 3").assertIsDisplayed()
        compose.onNodeWithText("진행률 42%").assertIsDisplayed()
        compose.onNodeWithText("촉각 피드백 끄짐 · 화면에서 진행 상태를 확인하세요").assertIsDisplayed()
        val surface = compose.onNodeWithContentDescription("마음 정리, 강도 3")
        surface.assertRangeInfoEquals(ProgressBarRangeInfo(.42f, 0f..1f))
        val stateDescription = surface.fetchSemanticsNode().config[SemanticsProperties.StateDescription]
        assertTrue(stateDescription.contains(state.stateLabel))
        assertTrue(stateDescription.contains("진행률 42%"))
        val actions = surface.fetchSemanticsNode().config[SemanticsActions.CustomActions]
        compose.runOnIdle {
            require(actions.first { it.label == "시작" }.action())
            require(actions.first { it.label == "일시 정지" }.action())
        }
        assertEquals(1, started)
        assertEquals(1, paused)
    }

    @Test
    fun pausedSurfaceRenamesAccessibleActionToResume() {
        val state = fixture(phase = InjectionPhase.PAUSED)
        compose.setContent {
            InjectionScreen(state, { _, _ -> }, { _, _, _ -> }, { _, _ -> }, { _, _ -> }, { _ -> }, { _ -> })
        }
        val actions = compose.onNodeWithContentDescription("마음 정리, 강도 3")
            .fetchSemanticsNode().config[SemanticsActions.CustomActions]
        assertEquals("재개", actions.first().label)
    }

    @Test
    fun onePhysicalGestureHasOnePrimaryOwnerAndOneRelease() {
        var downs = 0
        var ups = 0
        var cancels = 0
        var time = 1_000L
        compose.setContent {
            InjectionScreen(
                state = fixture(phase = InjectionPhase.LOCKED),
                onPointerDown = { _, observed -> downs++; assertEquals(time, observed) },
                onPointerMoved = { _, _, _ -> },
                onPointerUp = { _, observed -> ups++; assertEquals(time, observed) },
                onPointerCancelled = { _, _ -> cancels++ },
                onAccessibilityStart = { _ -> },
                onAccessibilityPause = { _ -> },
                monotonicMillis = { time },
            )
        }
        compose.onNodeWithContentDescription("마음 정리, 강도 3").performTouchInput {
            down(center)
            moveBy(Offset(70f, 0f))
            up()
        }
        compose.runOnIdle {
            assertEquals(1, downs)
            assertEquals(1, ups)
            assertEquals(0, cancels)
        }
    }

    @Test
    fun controlledRouteUnlocksHoldsPausesResumesAndCapturesVisualFallback() {
        var time = 0L
        val viewModel = InjectionViewModel(requireNotNull(Intensity.from(1)), EntrySource.APP)
        viewModel.updatePreferences(reducedMotion = true, hapticsEnabled = false, soundEnabled = false)
        compose.setContent {
            MaeumjaroTheme {
                InjectionRoute(
                    viewModel = viewModel,
                    feedbackPlayer = SilentInjectionFeedbackPlayer,
                    monotonicMillis = { time },
                )
            }
        }
        compose.runOnIdle {
            viewModel.pointerDown(1, time)
            viewModel.pointerMoved(56f, 0f, 400f)
            viewModel.pointerUp(1, time)
            viewModel.pointerDown(2, time)
            time = 120
            viewModel.frame(time)
            time = 420
            viewModel.frame(time)
            viewModel.pointerUp(2, time)
        }
        compose.onNodeWithText("진행률 25%").assertIsDisplayed()
        assertProgressSemantics(25, .25f)
        captureEvidence("task6-injection-paused")
        compose.runOnIdle {
            time = 500
            viewModel.pointerDown(3, time)
            time = 620
            viewModel.frame(time)
            time = 1_520
            viewModel.frame(time)
        }
        compose.onNodeWithText("진행률 100%").assertIsDisplayed()
        assertProgressSemantics(100, 1f)
        captureEvidence("task6-injection-complete")
    }

    @Test
    fun routeStopResetsAnIncompleteSessionAndItsVisibleProgress() {
        var time = 0L
        val viewModel = InjectionViewModel(requireNotNull(Intensity.from(1)), EntrySource.APP)
        val owner = TestLifecycleOwner()
        compose.setContent {
            CompositionLocalProvider(LocalLifecycleOwner provides owner) {
                InjectionRoute(
                    viewModel = viewModel,
                    feedbackPlayer = SilentInjectionFeedbackPlayer,
                    monotonicMillis = { time },
                )
            }
        }
        compose.runOnIdle {
            owner.moveTo(Lifecycle.Event.ON_START)
            viewModel.pointerDown(1, time)
            viewModel.pointerMoved(56f, 0f, 400f)
            viewModel.pointerUp(1, time)
            viewModel.pointerDown(2, time)
            time = 120
            viewModel.frame(time)
            time = 420
            viewModel.frame(time)
            owner.moveTo(Lifecycle.Event.ON_STOP)
        }
        compose.onNodeWithText("진행률 0%").assertIsDisplayed()
        assertEquals(InjectionPhase.READY, viewModel.uiState.value.phase)
    }

    private fun fixture(
        phase: InjectionPhase = InjectionPhase.READY,
        progress: Double = 0.0,
        hapticsEnabled: Boolean = true,
    ) = InjectionUiState(
        phase = phase,
        intensity = 3,
        durationMillis = 1_800,
        initialFill = .6,
        progress = progress,
        liquidRemaining = .6 * (1 - progress),
        ringRotationY = 180f,
        reducedMotion = false,
        hapticsEnabled = hapticsEnabled,
        soundEnabled = false,
    )

    private fun assertProgressSemantics(expectedPercent: Int, expectedProgress: Float) {
        val surface = compose.onNodeWithContentDescription("마음 정리, 강도 1")
        surface.assertRangeInfoEquals(ProgressBarRangeInfo(expectedProgress, 0f..1f))
        val stateDescription = surface.fetchSemanticsNode().config[SemanticsProperties.StateDescription]
        assertTrue("progress semantics must expose $expectedPercent%", stateDescription.contains("진행률 $expectedPercent%"))
    }

    private fun captureEvidence(name: String) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val automation = instrumentation.uiAutomation
        automation.executeShellCommand("screencap -p /sdcard/Download/$name.png").use { }
        val context = instrumentation.targetContext
        val hierarchy = File.createTempFile("$name-", ".xml", context.cacheDir).apply {
                writeText(automation.accessibilityHierarchyXml())
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "$name.xml")
            put(MediaStore.MediaColumns.MIME_TYPE, "application/xml")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val uri = checkNotNull(context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values))
        context.contentResolver.openOutputStream(uri).use { output ->
            checkNotNull(output).use { it.write(hierarchy.readBytes()) }
        }
        check(hierarchy.delete())
    }

    private fun UiAutomation.accessibilityHierarchyXml(): String {
        val root = rootInActiveWindow ?: return ""
        root.refresh()
        val writer = StringWriter()
        val serializer = Xml.newSerializer().apply {
            setOutput(writer)
            startDocument("UTF-8", true)
        }
        root.writeXml(serializer)
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
        for (index in 0 until childCount) getChild(index)?.let { child -> child.writeXml(serializer) }
        serializer.endTag(null, "node")
    }

    private class TestLifecycleOwner : LifecycleOwner {
        private val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle = registry

        fun moveTo(event: Lifecycle.Event) = registry.handleLifecycleEvent(event)
    }
}
