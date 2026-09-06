package com.maeumjaro.app.core

import kotlin.math.abs

private const val HOLD_DELAY_MILLIS = 120L
private const val HORIZONTAL_DOMINANCE = 1.25

fun reduce(state: RitualState, event: InteractionEvent): RitualState = when (state) {
    is Locked -> reduceLocked(state, event)
    is Unlocking -> reduceUnlocking(state, event)
    is Ready -> reduceReady(state, event)
    is AwaitingFirstPress -> reduceAwaitingFirst(state, event)
    is Relocking -> reduceRelocking(state, event)
    is Pressing -> reducePressing(state, event)
    is Paused -> reducePaused(state, event)
    is AwaitingResume -> reduceAwaitingResume(state, event)
    is Committing -> reduceCommitting(state, event)
    is CommitFailed -> if (event === RetryCommit) Committing(state.draft) else state
    is Completed -> state
}

private fun reduceLocked(state: Locked, event: InteractionEvent): RitualState = when (event) {
    is PointerDown -> Unlocking(state.intensity, state.source, event.pointerId)
    is PointerMoved, is PointerUp, is PointerCancelled, is HoldThresholdReached, is Tick,
    Backgrounded, RetryCommit, is CommitResult -> state
}

private fun reduceUnlocking(state: Unlocking, event: InteractionEvent): RitualState = when (event) {
    is PointerMoved -> state.copy(
        horizontalDeltaPx = event.horizontalDeltaPx,
        verticalDeltaPx = event.verticalDeltaPx,
        touchTargetWidthPx = event.touchTargetWidthPx,
    )
    is PointerUp -> if (event.pointerId == state.pointerId && state.gestureCommits()) {
        Ready(state.intensity, state.source, state.pointerId)
    } else Locked(state.intensity, state.source)
    is PointerCancelled -> if (event.pointerId == state.pointerId) Locked(state.intensity, state.source) else state
    Backgrounded -> Locked(state.intensity, state.source)
    is PointerDown, is HoldThresholdReached, is Tick, RetryCommit, is CommitResult -> state
}

private fun reduceReady(state: Ready, event: InteractionEvent): RitualState = when (event) {
    is PointerDown -> if (event.pointerId == state.previousPointerId) state else AwaitingFirstPress(
        state.intensity, state.source, event.pointerId, event.monotonicMillis,
    )
    is PointerMoved, is PointerUp, is PointerCancelled, is HoldThresholdReached, is Tick,
    Backgrounded, RetryCommit, is CommitResult -> state
}

private fun reduceAwaitingFirst(state: AwaitingFirstPress, event: InteractionEvent): RitualState = when (event) {
    is PointerMoved -> if (event.isHorizontalIntent()) Relocking(
        state.intensity, state.source, state.pointerId, event.horizontalDeltaPx, event.verticalDeltaPx, event.touchTargetWidthPx,
    ) else state
    is HoldThresholdReached -> if (event.pointerId == state.pointerId && event.monotonicMillis - state.downMonotonicMillis >= HOLD_DELAY_MILLIS) {
        Pressing(
            InjectionSession(event.sessionStart.sessionId, state.intensity, state.source, event.sessionStart.wallInstant, 0, 0),
            state.pointerId,
            event.monotonicMillis,
        )
    } else state
    is PointerUp -> if (event.pointerId == state.pointerId) Ready(state.intensity, state.source, state.pointerId) else state
    is PointerCancelled -> if (event.pointerId == state.pointerId) Ready(state.intensity, state.source, state.pointerId) else state
    Backgrounded -> Ready(state.intensity, state.source, state.pointerId)
    is PointerDown, is Tick, RetryCommit, is CommitResult -> state
}

private fun reduceRelocking(state: Relocking, event: InteractionEvent): RitualState = when (event) {
    is PointerMoved -> state.copy(
        horizontalDeltaPx = event.horizontalDeltaPx,
        verticalDeltaPx = event.verticalDeltaPx,
        touchTargetWidthPx = event.touchTargetWidthPx,
    )
    is PointerUp -> if (event.pointerId == state.pointerId && state.gestureCommits()) {
        Locked(state.intensity, state.source)
    } else Ready(state.intensity, state.source, state.pointerId)
    is PointerCancelled -> if (event.pointerId == state.pointerId) Ready(state.intensity, state.source, state.pointerId) else state
    Backgrounded -> Ready(state.intensity, state.source, state.pointerId)
    is PointerDown, is HoldThresholdReached, is Tick, RetryCommit, is CommitResult -> state
}

private fun reducePressing(state: Pressing, event: InteractionEvent): RitualState = when (event) {
    is Tick -> state.advance(event)
    is PointerUp -> if (event.pointerId == state.pointerId) state.pauseAt(event.monotonicMillis) else state
    is PointerCancelled -> if (event.pointerId == state.pointerId) state.pauseAt(event.monotonicMillis) else state
    Backgrounded -> Ready(state.session.intensity, state.session.source, state.pointerId)
    is PointerDown, is PointerMoved, is HoldThresholdReached, RetryCommit, is CommitResult -> state
}

private fun reducePaused(state: Paused, event: InteractionEvent): RitualState = when (event) {
    is PointerDown -> if (event.pointerId == state.previousPointerId) state else AwaitingResume(state.session, event.pointerId, event.monotonicMillis)
    Backgrounded -> Ready(state.session.intensity, state.session.source, state.previousPointerId)
    is PointerMoved, is PointerUp, is PointerCancelled, is HoldThresholdReached, is Tick, RetryCommit, is CommitResult -> state
}

private fun reduceAwaitingResume(state: AwaitingResume, event: InteractionEvent): RitualState = when (event) {
    is HoldThresholdReached -> if (event.pointerId == state.pointerId && event.monotonicMillis - state.downMonotonicMillis >= HOLD_DELAY_MILLIS) {
        Pressing(state.session, state.pointerId, event.monotonicMillis)
    } else state
    is PointerUp -> if (event.pointerId == state.pointerId) Paused(state.session, state.pointerId) else state
    is PointerCancelled -> if (event.pointerId == state.pointerId) Paused(state.session, state.pointerId) else state
    Backgrounded -> Ready(state.session.intensity, state.session.source, state.pointerId)
    is PointerDown, is PointerMoved, is Tick, RetryCommit, is CommitResult -> state
}

private fun reduceCommitting(state: Committing, event: InteractionEvent): RitualState = when (event) {
    CommitResult.Inserted, CommitResult.AlreadyExists -> Completed(state.draft)
    CommitResult.Failed -> CommitFailed(state.draft)
    is PointerDown, is PointerMoved, is PointerUp, is PointerCancelled, is HoldThresholdReached, is Tick,
    Backgrounded, RetryCommit -> state
}

private fun Pressing.advance(event: Tick): RitualState {
    val elapsed = (event.monotonicMillis - pressStartedMonotonicMillis).coerceAtLeast(0)
    val accumulated = (session.accumulatedMillis + elapsed).coerceAtMost(session.intensity.durationMillis)
    if (accumulated < session.intensity.durationMillis) return copy(session = session.copy(accumulatedMillis = accumulated), pressStartedMonotonicMillis = event.monotonicMillis)
    return Committing(InjectionEventDraft(session.id, session.intensity, session.source, session.startedAt, event.completedAt, session.interruptionCount))
}

private fun Pressing.pauseAt(monotonicMillis: Long): Paused {
    val elapsed = (monotonicMillis - pressStartedMonotonicMillis).coerceAtLeast(0)
    val accumulated = (session.accumulatedMillis + elapsed).coerceAtMost(session.intensity.durationMillis)
    return Paused(session.copy(accumulatedMillis = accumulated, interruptionCount = session.interruptionCount + 1), pointerId)
}

private fun PointerMoved.isHorizontalIntent(): Boolean = abs(horizontalDeltaPx) >= abs(verticalDeltaPx) * HORIZONTAL_DOMINANCE

private fun Unlocking.gestureCommits(): Boolean =
    abs(horizontalDeltaPx) >= unlockThresholdPx(touchTargetWidthPx) && abs(horizontalDeltaPx) >= abs(verticalDeltaPx) * HORIZONTAL_DOMINANCE

private fun Relocking.gestureCommits(): Boolean =
    abs(horizontalDeltaPx) >= unlockThresholdPx(touchTargetWidthPx) && abs(horizontalDeltaPx) >= abs(verticalDeltaPx) * HORIZONTAL_DOMINANCE
