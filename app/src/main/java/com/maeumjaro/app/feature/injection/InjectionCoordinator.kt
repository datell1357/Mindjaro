package com.maeumjaro.app.feature.injection

import com.maeumjaro.app.core.AwaitingFirstPress
import com.maeumjaro.app.core.AwaitingResume
import com.maeumjaro.app.core.Backgrounded
import com.maeumjaro.app.core.CommitFailed
import com.maeumjaro.app.core.CommitResult
import com.maeumjaro.app.core.Committing
import com.maeumjaro.app.core.Completed
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.EventTime
import com.maeumjaro.app.core.HoldThresholdReached
import com.maeumjaro.app.core.InjectionEventDraft
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.Locked
import com.maeumjaro.app.core.Paused
import com.maeumjaro.app.core.PointerCancelled
import com.maeumjaro.app.core.PointerDown
import com.maeumjaro.app.core.PointerMoved
import com.maeumjaro.app.core.PointerUp
import com.maeumjaro.app.core.Pressing
import com.maeumjaro.app.core.Ready
import com.maeumjaro.app.core.Relocking
import com.maeumjaro.app.core.RetryCommit
import com.maeumjaro.app.core.RitualState
import com.maeumjaro.app.core.SessionStart
import com.maeumjaro.app.core.Tick
import com.maeumjaro.app.core.Unlocking
import com.maeumjaro.app.core.reduce
import com.maeumjaro.app.core.unlockThresholdPx
import java.time.Clock
import java.time.ZoneId
import java.util.UUID
import kotlin.math.abs

enum class InjectionPhase { LOCKED, UNLOCKING, READY, AWAITING_HOLD, RELOCKING, PRESSING, PAUSED, COMMITTING, COMMIT_FAILED, COMPLETED }

internal const val RING_SETTLE_DURATION_MILLIS = 260

data class InjectionUiState(
    val phase: InjectionPhase,
    val intensity: Int,
    val durationMillis: Long,
    val initialFill: Double,
    val progress: Double,
    val liquidRemaining: Double,
    val ringRotationY: Float,
    val reducedMotion: Boolean,
    val hapticsEnabled: Boolean,
    val soundEnabled: Boolean,
) {
    val isAdvancing: Boolean get() = phase == InjectionPhase.PRESSING
    val stateLabel: String get() = when (phase) {
        InjectionPhase.LOCKED -> "잠김 상태입니다. 펜을 좌우로 밀어 열어 주세요."
        InjectionPhase.UNLOCKING -> "열기 중"
        InjectionPhase.READY -> "준비됐어요. 손을 떼었다가 새로 길게 눌러 주세요."
        InjectionPhase.AWAITING_HOLD -> "길게 누르기 준비 중"
        InjectionPhase.RELOCKING -> "다시 잠그기 중"
        InjectionPhase.PRESSING -> "마음을 정리하는 중"
        InjectionPhase.PAUSED -> "일시 정지됐어요. 새로 길게 눌러 이어가세요."
        InjectionPhase.COMMITTING -> "완료를 준비하는 중"
        InjectionPhase.COMMIT_FAILED -> "완료를 저장하지 못했어요."
        InjectionPhase.COMPLETED -> "마음 정리를 완료했어요."
    }
}

sealed interface InjectionFeedback {
    data object Started : InjectionFeedback
    data class Progress(val ordinal: Int) : InjectionFeedback
    data object Completed : InjectionFeedback
    data object Paused : InjectionFeedback
    data object Reset : InjectionFeedback
}

class InjectionCoordinator(
    initialIntensity: Intensity,
    source: EntrySource,
    private val wallClock: Clock = Clock.systemUTC(),
    private val zoneId: ZoneId = ZoneId.systemDefault(),
    private val sessionIdFactory: () -> UUID = UUID::randomUUID,
    reducedMotion: Boolean = false,
    hapticsEnabled: Boolean = true,
    soundEnabled: Boolean = false,
) {
    private var ritualState: RitualState = Locked(initialIntensity, source)
    private var currentSessionStart: SessionStart? = null
    private var completionDraft: InjectionEventDraft? = null
    private var emittedDraftId: UUID? = null
    private var milestoneCount = 0
    private var accessibilityPointer = Int.MIN_VALUE + 1
    private var gestureSequence = 0
    private var activePlatformPointerId: Int? = null
    private var activeSequencePointerId: Int? = null
    private val feedbackQueue = ArrayDeque<InjectionFeedback>()
    private var reducedMotion = reducedMotion
    private var hapticsEnabled = hapticsEnabled
    private var soundEnabled = soundEnabled

    val uiState: InjectionUiState get() = ritualState.toUiState(reducedMotion, hapticsEnabled, soundEnabled)

    fun pointerDown(pointerId: Int, monotonicMillis: Long) {
        if (!ritualState.acceptsNewGesture()) return
        val sequencePointerId = nextGestureSequence()
        activePlatformPointerId = pointerId
        activeSequencePointerId = sequencePointerId
        dispatch(PointerDown(sequencePointerId, monotonicMillis.safeTime()))
    }

    fun pointerMoved(horizontalDeltaPx: Float, verticalDeltaPx: Float, touchTargetWidthPx: Float) {
        if (activeSequencePointerId == null) return
        val horizontal = horizontalDeltaPx.safeDouble()
        if (ritualState is AwaitingFirstPress && abs(horizontal) <= RELOCK_INTENT_SLOP_PX) return
        dispatch(PointerMoved(horizontal, verticalDeltaPx.safeDouble(), touchTargetWidthPx.safeDouble()))
    }

    fun pointerUp(pointerId: Int, monotonicMillis: Long) {
        val safeMillis = monotonicMillis.safeTime()
        val ownsGesture = pointerId == activePlatformPointerId
        if (!ownsGesture) return
        val sequencePointerId = activeSequencePointerId ?: return
        if (ritualState is Pressing) {
            dispatch(Tick(safeMillis, EventTime.at(wallClock.instant(), zoneId)))
        }
        dispatch(PointerUp(sequencePointerId, safeMillis))
        clearActiveGesture()
    }

    fun pointerCancelled(pointerId: Int, monotonicMillis: Long) {
        val ownsGesture = pointerId == activePlatformPointerId
        if (!ownsGesture) return
        val sequencePointerId = activeSequencePointerId ?: return
        dispatch(PointerCancelled(sequencePointerId, monotonicMillis.safeTime()))
        clearActiveGesture()
    }

    fun frame(monotonicMillis: Long) {
        val safeMillis = monotonicMillis.safeTime()
        when (val state = ritualState) {
            is AwaitingFirstPress -> if (safeMillis - state.downMonotonicMillis >= HOLD_DELAY_MILLIS) {
                dispatch(HoldThresholdReached(state.pointerId, safeMillis, sessionStart()))
            }
            is AwaitingResume -> if (safeMillis - state.downMonotonicMillis >= HOLD_DELAY_MILLIS) {
                dispatch(HoldThresholdReached(state.pointerId, safeMillis, SessionStart(state.session.id, state.session.startedAt)))
            }
            is Pressing -> dispatch(Tick(safeMillis, EventTime.at(wallClock.instant(), zoneId)))
            else -> Unit
        }
    }

    fun backgrounded() {
        dispatch(Backgrounded)
        clearActiveGesture()
        currentSessionStart = null
        feedbackQueue.add(InjectionFeedback.Reset)
    }

    fun setIntensity(intensity: Intensity): Boolean {
        ritualState = when (val state = ritualState) {
            is Locked -> state.copy(intensity = intensity)
            is Ready -> state.copy(intensity = intensity)
            else -> return false
        }
        return true
    }

    fun updatePreferences(reducedMotion: Boolean, hapticsEnabled: Boolean, soundEnabled: Boolean): Boolean {
        if (ritualState !is Locked && ritualState !is Ready) return false
        this.reducedMotion = reducedMotion
        this.hapticsEnabled = hapticsEnabled
        this.soundEnabled = soundEnabled
        return true
    }

    fun takeCompletionDraft(): InjectionEventDraft? = completionDraft.also { completionDraft = null }
    fun takeFeedback(): InjectionFeedback? = feedbackQueue.removeFirstOrNull()
    fun commitSucceeded(alreadyExisted: Boolean = false) = dispatch(if (alreadyExisted) CommitResult.AlreadyExists else CommitResult.Inserted)
    fun commitFailed() = dispatch(CommitResult.Failed)
    fun retryCommit() = dispatch(RetryCommit)

    fun accessibilityStart(monotonicMillis: Long) {
        val time = monotonicMillis.safeTime()
        accessibilityPointer = if (accessibilityPointer == Int.MIN_VALUE + 1) Int.MIN_VALUE + 2 else Int.MIN_VALUE + 1
        when (ritualState) {
            is Locked -> {
                pointerDown(ACCESSIBILITY_UNLOCK_POINTER, time)
                pointerMoved(56f, 0f, 400f)
                pointerUp(ACCESSIBILITY_UNLOCK_POINTER, time)
                pointerDown(accessibilityPointer, time)
            }
            is Ready, is Paused -> pointerDown(accessibilityPointer, time)
            else -> Unit
        }
    }

    fun accessibilityPause(monotonicMillis: Long) {
        if (ritualState is Pressing) activePlatformPointerId?.let { pointerUp(it, monotonicMillis.safeTime()) }
    }

    private fun RitualState.acceptsNewGesture(): Boolean = this is Locked || this is Ready || this is Paused

    private fun nextGestureSequence(): Int {
        gestureSequence = if (gestureSequence == Int.MAX_VALUE) 1 else gestureSequence + 1
        return gestureSequence
    }

    private fun clearActiveGesture() {
        activePlatformPointerId = null
        activeSequencePointerId = null
    }

    private fun sessionStart(): SessionStart = currentSessionStart ?: SessionStart(sessionIdFactory(), wallClock.instant()).also {
        currentSessionStart = it
    }

    private fun dispatch(event: com.maeumjaro.app.core.InteractionEvent) {
        val before = ritualState
        val beforeProgress = before.progressValue()
        val after = reduce(before, event)
        ritualState = after
        val afterProgress = after.progressValue()

        if (before !is Pressing && after is Pressing) feedbackQueue.add(InjectionFeedback.Started)
        if (before is Pressing && after is Paused) feedbackQueue.add(InjectionFeedback.Paused)
        enqueueMilestones(after, beforeProgress, afterProgress)
        if (after is Committing && emittedDraftId != after.draft.sessionId) {
            emittedDraftId = after.draft.sessionId
            completionDraft = after.draft
            feedbackQueue.add(InjectionFeedback.Completed)
        }
    }

    private fun enqueueMilestones(state: RitualState, before: Double, after: Double) {
        val count = state.intensity().hapticThresholdCount
        if (after <= before || count <= 1) return
        val reached = (1 until count).count { after >= it.toDouble() / count }
        while (milestoneCount < reached) {
            milestoneCount += 1
            feedbackQueue.add(InjectionFeedback.Progress(milestoneCount))
        }
    }

    private fun RitualState.toUiState(reducedMotion: Boolean, hapticsEnabled: Boolean, soundEnabled: Boolean): InjectionUiState {
        val intensity = intensity()
        val progress = progressValue().coerceIn(0.0, 1.0)
        return InjectionUiState(
            phase = phase(),
            intensity = intensity.value,
            durationMillis = intensity.durationMillis,
            initialFill = intensity.initialFill,
            progress = progress,
            liquidRemaining = intensity.initialFill * (1.0 - progress),
            ringRotationY = ringRotation(reducedMotion),
            reducedMotion = reducedMotion,
            hapticsEnabled = hapticsEnabled,
            soundEnabled = soundEnabled,
        )
    }

    private fun RitualState.intensity(): Intensity = when (this) {
        is Locked -> intensity; is Unlocking -> intensity; is Ready -> intensity; is AwaitingFirstPress -> intensity
        is Relocking -> intensity; is Pressing -> session.intensity; is Paused -> session.intensity
        is AwaitingResume -> session.intensity; is Committing -> draft.intensity; is CommitFailed -> draft.intensity; is Completed -> draft.intensity
    }

    private fun RitualState.progressValue(): Double = when (this) {
        is Pressing -> session.progress.value; is Paused -> session.progress.value; is AwaitingResume -> session.progress.value
        is Committing, is CommitFailed, is Completed -> 1.0
        else -> 0.0
    }

    private fun RitualState.phase(): InjectionPhase = when (this) {
        is Locked -> InjectionPhase.LOCKED; is Unlocking -> InjectionPhase.UNLOCKING; is Ready -> InjectionPhase.READY
        is AwaitingFirstPress, is AwaitingResume -> InjectionPhase.AWAITING_HOLD; is Relocking -> InjectionPhase.RELOCKING
        is Pressing -> InjectionPhase.PRESSING; is Paused -> InjectionPhase.PAUSED; is Committing -> InjectionPhase.COMMITTING
        is CommitFailed -> InjectionPhase.COMMIT_FAILED; is Completed -> InjectionPhase.COMPLETED
    }

    private fun RitualState.ringRotation(reducedMotion: Boolean): Float = when (this) {
        is Locked -> 0f
        is Unlocking -> if (reducedMotion) 0f else (horizontalDeltaPx / unlockThresholdPx(touchTargetWidthPx)).coerceIn(-1.0, 1.0).toFloat() * 180f
        is Ready, is AwaitingFirstPress, is Pressing, is Paused, is AwaitingResume, is Committing, is CommitFailed, is Completed -> 180f
        is Relocking -> if (reducedMotion) 180f else 180f + (horizontalDeltaPx / unlockThresholdPx(touchTargetWidthPx)).coerceIn(-1.0, 1.0).toFloat() * 180f
    }

    private fun Float.safeDouble(): Double = if (isFinite()) toDouble() else 0.0
    private fun Long.safeTime(): Long = coerceAtLeast(0L)

    private companion object {
        const val HOLD_DELAY_MILLIS = 120L
        const val ACCESSIBILITY_UNLOCK_POINTER = Int.MIN_VALUE
        const val RELOCK_INTENT_SLOP_PX = 8.0
    }
}
