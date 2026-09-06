package com.maeumjaro.app.feature.injection

import android.os.SystemClock
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.changedToUpIgnoreConsumed
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.maeumjaro.app.R
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.collectLatest
import kotlin.math.cos
import kotlin.math.PI
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll

private const val REFERENCE_WIDTH = 1024f
private const val REFERENCE_HEIGHT = 1536f
private const val RING_X = 362f
private const val RING_Y = 136f
private const val RING_WIDTH = 300f
private const val RING_HEIGHT = 112f
private const val LIQUID_X = 449f
private const val LIQUID_Y = 650f
private const val LIQUID_WIDTH = 126f
private const val LIQUID_HEIGHT = 414f

internal fun ringUsesReadyFace(phase: InjectionPhase): Boolean = when (phase) {
    InjectionPhase.READY,
    InjectionPhase.AWAITING_HOLD,
    InjectionPhase.PRESSING,
    InjectionPhase.PAUSED,
    InjectionPhase.COMMITTING,
    InjectionPhase.COMMIT_FAILED,
    InjectionPhase.COMPLETED
    -> true
    InjectionPhase.LOCKED,
    InjectionPhase.UNLOCKING,
    InjectionPhase.RELOCKING
    -> false
}

internal fun ringFaceRotationY(baseRotationY: Float, readyFace: Boolean): Float =
    baseRotationY + if (readyFace) 180f else 0f

@Composable
fun InjectionRoute(
    viewModel: InjectionViewModel,
    modifier: Modifier = Modifier,
    feedbackPlayer: InjectionFeedbackPlayer? = null,
    monotonicMillis: () -> Long = SystemClock::uptimeMillis,
) {
    val state by viewModel.uiState.collectAsState()
    val view = LocalView.current
    val ownsPlayer = feedbackPlayer == null
    val defaultPlayer = remember(view) { AndroidInjectionFeedbackPlayer(view, R.raw.ritual_complete_v1) }
    val player = feedbackPlayer ?: defaultPlayer
    val lifecycleOwner = LocalLifecycleOwner.current

    DisposableEffect(lifecycleOwner, player) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                viewModel.backgrounded()
                player.stop()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            player.stop()
            if (ownsPlayer) defaultPlayer.close()
        }
    }

    LaunchedEffect(viewModel, player) {
        viewModel.feedback.collectLatest { player.play(it, viewModel.uiState.value) }
    }
    LaunchedEffect(state.phase) {
        if (state.phase == InjectionPhase.AWAITING_HOLD || state.phase == InjectionPhase.PRESSING) {
            while (true) withFrameNanos { viewModel.frame(monotonicMillis()) }
        }
    }

    InjectionScreen(
        state = state,
        onPointerDown = viewModel::pointerDown,
        onPointerMoved = viewModel::pointerMoved,
        onPointerUp = viewModel::pointerUp,
        onPointerCancelled = viewModel::pointerCancelled,
        onAccessibilityStart = viewModel::accessibilityStart,
        onAccessibilityPause = viewModel::accessibilityPause,
        monotonicMillis = monotonicMillis,
        modifier = modifier,
    )
}

@Composable
fun InjectionScreen(
    state: InjectionUiState,
    onPointerDown: (Int, Long) -> Unit,
    onPointerMoved: (Float, Float, Float) -> Unit,
    onPointerUp: (Int, Long) -> Unit,
    onPointerCancelled: (Int, Long) -> Unit,
    onAccessibilityStart: (Long) -> Unit,
    onAccessibilityPause: (Long) -> Unit,
    modifier: Modifier = Modifier,
    monotonicMillis: () -> Long = SystemClock::uptimeMillis,
) {
    val now = monotonicMillis
    val injectionTitle = stringResource(R.string.injection_title)
    val startLabel = if (state.phase == InjectionPhase.PAUSED) "재개" else "시작"
    val semantics = Modifier.semantics(mergeDescendants = true) {
        contentDescription = "$injectionTitle, 강도 ${state.intensity}"
        stateDescription = "${state.stateLabel}, 진행률 ${(state.progress * 100).toInt()}%"
        progressBarRangeInfo = ProgressBarRangeInfo(state.progress.toFloat(), 0f..1f)
        customActions = listOf(
            CustomAccessibilityAction(startLabel) { onAccessibilityStart(now()); true },
            CustomAccessibilityAction("일시 정지") { onAccessibilityPause(now()); true },
        )
        onLongClick(startLabel) { onAccessibilityStart(now()); true }
        role = Role.Button
    }

    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).background(MaterialTheme.colorScheme.background).padding(horizontal = 20.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(injectionTitle, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.injection_body), style = MaterialTheme.typography.bodyMedium)
            Text(state.stateLabel, style = MaterialTheme.typography.bodyLarge)
        }
        BoxWithConstraints(
            Modifier.fillMaxWidth().heightIn(min = 360.dp, max = 560.dp).then(semantics).focusable().onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.DirectionLeft, Key.DirectionRight -> {
                        if (state.phase != InjectionPhase.LOCKED) return@onPreviewKeyEvent false
                        val pointerId = Int.MIN_VALUE + 7
                        onPointerDown(pointerId, now())
                        onPointerMoved(if (event.key == Key.DirectionLeft) -56f else 56f, 0f, 400f)
                        onPointerUp(pointerId, now())
                        true
                    }
                    Key.Enter, Key.Spacebar -> {
                        if (state.phase == InjectionPhase.PRESSING) onAccessibilityPause(now()) else onAccessibilityStart(now())
                        true
                    }
                    else -> false
                }
            }.pointerInput(Unit) {
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    val primaryId = down.id
                    val primary = primaryId.value.toInt()
                    val origin = down.position
                    onPointerDown(primary, now())
                    try {
                        while (true) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull { it.id == primaryId }
                            if (change == null) {
                                onPointerCancelled(primary, now())
                                break
                            }
                            if (change.changedToUpIgnoreConsumed()) {
                                onPointerUp(primary, now())
                                change.consume()
                                break
                            }
                            val delta = change.position - origin
                            onPointerMoved(delta.x, delta.y, size.width.toFloat())
                            change.consume()
                        }
                    } catch (cancelled: CancellationException) {
                        onPointerCancelled(primary, now())
                        throw cancelled
                    }
                }
            }, contentAlignment = Alignment.Center) {
            val artboardWidth = minOf(maxWidth, maxHeight / 1.5f, 430.dp)
            RitualPen(
                state = state,
                width = artboardWidth,
            )
        }
        Text("강도 ${state.intensity}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        LinearProgressIndicator(
            progress = { state.progress.toFloat() },
            modifier = Modifier.fillMaxWidth().height(8.dp),
        )
        Spacer(Modifier.height(6.dp))
        Text("진행률 ${(state.progress * 100).toInt()}%", style = MaterialTheme.typography.bodyLarge)
        if (!state.hapticsEnabled) Text("촉각 피드백 끄짐 · 화면에서 진행 상태를 확인하세요", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun RitualPen(state: InjectionUiState, width: Dp, modifier: Modifier = Modifier) {
    val scale = width.value / REFERENCE_WIDTH
    val height = width * (REFERENCE_HEIGHT / REFERENCE_WIDTH)
    Box(modifier.width(width).height(height), contentAlignment = Alignment.TopStart) {
        val baseResource = when (state.phase) {
            InjectionPhase.LOCKED, InjectionPhase.UNLOCKING, InjectionPhase.RELOCKING -> R.drawable.maeumjaro_pen_2d_locked
            InjectionPhase.COMPLETED -> R.drawable.maeumjaro_pen_2d_complete
            else -> R.drawable.maeumjaro_pen_2d_ready
        }
        Image(painterResource(baseResource), null, Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
        LayerImage(R.drawable.maeumjaro_pen_2d_window_empty, LIQUID_X, LIQUID_Y, LIQUID_WIDTH, LIQUID_HEIGHT, scale)
        val settledRotation = if (state.reducedMotion) {
            state.ringRotationY
        } else {
            animateFloatAsState(
                targetValue = state.ringRotationY,
                animationSpec = tween(
                    if (state.phase == InjectionPhase.UNLOCKING || state.phase == InjectionPhase.RELOCKING) {
                        0
                    } else {
                        RING_SETTLE_DURATION_MILLIS
                    },
                ),
                label = "ring-settle",
            ).value
        }
        Box(
            Modifier.offset((LIQUID_X * scale).dp, (LIQUID_Y * scale).dp).size((LIQUID_WIDTH * scale).dp, (LIQUID_HEIGHT * scale).dp).clipToBounds(),
            contentAlignment = Alignment.TopStart,
        ) {
            Image(
                painterResource(R.drawable.maeumjaro_pen_2d_liquid_full),
                null,
                Modifier.fillMaxWidth().requiredHeight((LIQUID_HEIGHT * scale).dp)
                    .offset(y = (LIQUID_HEIGHT * scale * (1f - state.liquidRemaining.toFloat())).dp),
                contentScale = ContentScale.FillBounds,
            )
        }
        Box(
            Modifier.offset((RING_X * scale).dp, (RING_Y * scale).dp).size((RING_WIDTH * scale).dp, (RING_HEIGHT * scale).dp)
        ) {
            if (state.reducedMotion) {
                Image(
                    painterResource(
                        if (ringUsesReadyFace(state.phase)) R.drawable.maeumjaro_pen_2d_ring_ready
                        else R.drawable.maeumjaro_pen_2d_ring_locked,
                    ),
                    null,
                    Modifier.fillMaxSize(),
                    contentScale = ContentScale.FillBounds,
                )
            } else {
                RingFace(
                    resource = R.drawable.maeumjaro_pen_2d_ring_locked,
                    rotationY = ringFaceRotationY(settledRotation, readyFace = false),
                )
                RingFace(
                    resource = R.drawable.maeumjaro_pen_2d_ring_ready,
                    rotationY = ringFaceRotationY(settledRotation, readyFace = true),
                )
            }
        }
    }
}

@Composable
private fun RingFace(resource: Int, rotationY: Float) {
    val facingCamera = cos(rotationY * PI.toFloat() / 180f) > 0f
    Image(
        painterResource(resource),
        null,
        Modifier.fillMaxSize().graphicsLayer {
            this.rotationY = rotationY
            alpha = if (facingCamera) 1f else 0f
            cameraDistance = 12f * density
        },
        contentScale = ContentScale.FillBounds,
    )
}

@Composable
private fun LayerImage(resource: Int, x: Float, y: Float, width: Float, height: Float, scale: Float) {
    Image(
        painterResource(resource),
        null,
        Modifier.offset((x * scale).dp, (y * scale).dp).size((width * scale).dp, (height * scale).dp),
        contentScale = ContentScale.FillBounds,
    )
}
