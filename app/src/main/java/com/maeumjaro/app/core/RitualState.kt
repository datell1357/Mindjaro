package com.maeumjaro.app.core

import java.time.Instant
import java.util.UUID

enum class EntrySource { WIDGET, APP }

data class InjectionSession(
    val id: UUID,
    val intensity: Intensity,
    val source: EntrySource,
    val startedAt: Instant,
    val accumulatedMillis: Long,
    val interruptionCount: Int,
) {
    val progress: RitualProgress get() = RitualProgress.fromElapsed(accumulatedMillis, intensity.durationMillis)
}

data class InjectionEventDraft(
    val sessionId: UUID,
    val intensity: Intensity,
    val source: EntrySource,
    val startedAt: Instant,
    val completedAt: EventTime,
    val interruptionCount: Int,
)

sealed interface RitualState
data class Locked(val intensity: Intensity, val source: EntrySource) : RitualState
data class Unlocking(
    val intensity: Intensity,
    val source: EntrySource,
    val pointerId: Int,
    val horizontalDeltaPx: Double = 0.0,
    val verticalDeltaPx: Double = 0.0,
    val touchTargetWidthPx: Double = 0.0,
) : RitualState
data class Ready(val intensity: Intensity, val source: EntrySource, val previousPointerId: Int) : RitualState
data class AwaitingFirstPress(
    val intensity: Intensity,
    val source: EntrySource,
    val pointerId: Int,
    val downMonotonicMillis: Long,
) : RitualState
data class Relocking(
    val intensity: Intensity,
    val source: EntrySource,
    val pointerId: Int,
    val horizontalDeltaPx: Double,
    val verticalDeltaPx: Double,
    val touchTargetWidthPx: Double,
) : RitualState
data class Pressing(val session: InjectionSession, val pointerId: Int, val pressStartedMonotonicMillis: Long) : RitualState
data class Paused(val session: InjectionSession, val previousPointerId: Int) : RitualState
data class AwaitingResume(val session: InjectionSession, val pointerId: Int, val downMonotonicMillis: Long) : RitualState
data class Committing(val draft: InjectionEventDraft) : RitualState
data class CommitFailed(val draft: InjectionEventDraft) : RitualState
data class Completed(val draft: InjectionEventDraft) : RitualState

sealed interface InteractionEvent
data class PointerDown(
    val pointerId: Int,
    val monotonicMillis: Long,
) : InteractionEvent
data class PointerMoved(val horizontalDeltaPx: Double, val verticalDeltaPx: Double, val touchTargetWidthPx: Double) : InteractionEvent
data class PointerUp(val pointerId: Int, val monotonicMillis: Long) : InteractionEvent
data class PointerCancelled(val pointerId: Int, val monotonicMillis: Long) : InteractionEvent
data class SessionStart(val sessionId: UUID, val wallInstant: Instant)
data class HoldThresholdReached(val pointerId: Int, val monotonicMillis: Long, val sessionStart: SessionStart) : InteractionEvent
data class Tick(val monotonicMillis: Long, val completedAt: EventTime) : InteractionEvent
data object Backgrounded : InteractionEvent
data object RetryCommit : InteractionEvent
sealed interface CommitResult : InteractionEvent {
    data object Inserted : CommitResult
    data object AlreadyExists : CommitResult
    data object Failed : CommitResult
}

fun RitualState.frozenDraftOrNull(): InjectionEventDraft? = when (this) {
    is Committing -> draft
    is CommitFailed -> draft
    is Completed -> draft
    is Locked, is Unlocking, is Ready, is AwaitingFirstPress, is Relocking, is Pressing, is Paused, is AwaitingResume -> null
}
