package com.maeumjaro.app.core

import java.nio.file.Files
import java.nio.file.Path
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class InjectionSessionTest {
    private val intensity = Intensity.from(5)!!
    private val start = Instant.parse("2026-09-04T14:59:30Z")
    private val id = UUID.fromString("11111111-2222-3333-4444-555555555555")

    @Test fun `Given locked ritual When swipe commits and same pointer holds Then a new pointer is required`() {
        val unlocking = reduce(Locked(intensity, EntrySource.APP), PointerDown(7, 0))
        assertTrue(unlocking is Unlocking)
        val moved = reduce(unlocking, PointerMoved(60.0, 2.0, 300.0))
        val ready = reduce(moved, PointerUp(7, 10))
        assertTrue(ready is Ready)
        assertSame(ready, reduce(ready, HoldThresholdReached(7, 130, sessionStart())))
        val awaiting = reduce(ready, PointerDown(8, 20))
        assertTrue(reduce(awaiting, HoldThresholdReached(8, 139, sessionStart())) is AwaitingFirstPress)
        assertTrue(reduce(awaiting, HoldThresholdReached(8, 140, sessionStart())) is Pressing)
    }

    @Test fun `Given ready ritual When horizontal gesture commits Then it relocks`() {
        val ready = Ready(intensity, EntrySource.APP, previousPointerId = 7)
        val awaiting = reduce(ready, PointerDown(8, 0))
        val relocking = reduce(awaiting, PointerMoved(56.0, 1.0, 400.0))
        assertTrue(relocking is Relocking)
        assertTrue(reduce(relocking, PointerUp(8, 20)) is Locked)
    }

    @Test fun `Given active press When released cancelled and resumed Then progress and interruptions are exact`() {
        val first = pressing(pointerId = 1, monotonic = 1_000)
        val paused = reduce(reduce(first, tick(1_920, 800)), PointerUp(1, 1_920)) as Paused
        assertEquals(800L, paused.session.accumulatedMillis)
        assertEquals(1, paused.session.interruptionCount)
        assertSame(paused, reduce(paused, PointerUp(1, 1_900)))
        val waiting = reduce(paused, PointerDown(2, 2_000))
        val resumed = reduce(waiting, HoldThresholdReached(2, 2_120, sessionStart())) as Pressing
        val cancelled = reduce(reduce(resumed, tick(2_420, 1_100)), PointerCancelled(2, 2_420)) as Paused
        assertEquals(1_100L, cancelled.session.accumulatedMillis)
        assertEquals(2, cancelled.session.interruptionCount)
    }

    @Test fun `Given incomplete ritual When backgrounded Then it resets without a draft`() {
        val backgrounded = reduce(reduce(pressing(), tick(500, 500)), Backgrounded)
        assertTrue(backgrounded is Ready)
    }

    @Test fun `Given primary press When secondary input arrives Then state is unchanged`() {
        val pressing = pressing(pointerId = 3)
        assertSame(pressing, reduce(pressing, PointerDown(4, 10)))
        assertSame(pressing, reduce(pressing, PointerUp(4, 20)))
        val awaiting = reduce(Ready(intensity, EntrySource.APP, 1), PointerDown(2, 100))
        assertSame(awaiting, reduce(awaiting, PointerCancelled(3, 110)))
    }

    @Test fun `Given completed progress When input and background arrive Then commit remains locked`() {
        val committing = reduce(pressing(), tick(3_320, 3_200)) as Committing
        listOf<InteractionEvent>(PointerDown(2, 4_000), PointerUp(1, 4_000), PointerCancelled(1, 4_000), Backgrounded)
            .forEach { assertSame(committing, reduce(committing, it)) }
    }

    @Test fun `Given frozen draft When commit fails and retries Then UUID and draft are reused until success`() {
        val committing = reduce(pressing(), tick(3_320, 3_200)) as Committing
        val failed = reduce(committing, CommitResult.Failed) as CommitFailed
        val retryOne = reduce(failed, RetryCommit) as Committing
        val failedAgain = reduce(retryOne, CommitResult.Failed) as CommitFailed
        val retryTwo = reduce(failedAgain, RetryCommit) as Committing
        assertSame(committing.draft, retryOne.draft)
        assertSame(committing.draft, retryTwo.draft)
        assertEquals(id, retryTwo.draft.sessionId)
        assertTrue(reduce(retryTwo, CommitResult.Inserted) is Completed)
        assertTrue(reduce(retryTwo, CommitResult.AlreadyExists) is Completed)
    }

    @Test fun `Given deterministic intensity five flow When traced Then one draft survives retries`() {
        val states = mutableListOf<RitualState>(Locked(intensity, EntrySource.WIDGET))
        fun apply(event: InteractionEvent) { states += reduce(states.last(), event) }
        apply(PointerDown(1, 0)); apply(PointerMoved(60.0, 0.0, 300.0)); apply(PointerUp(1, 10))
        apply(PointerDown(2, 20)); apply(HoldThresholdReached(2, 140, sessionStart())); apply(tick(1_740, 1_600)); apply(PointerUp(2, 1_740))
        apply(PointerDown(3, 2_000)); apply(HoldThresholdReached(3, 2_120, sessionStart())); apply(tick(3_720, 3_200))
        apply(CommitResult.Failed); apply(RetryCommit); apply(CommitResult.Failed); apply(RetryCommit); apply(CommitResult.Inserted)
        val drafts = states.mapNotNull { it.frozenDraftOrNull() }
        assertEquals(1, drafts.distinctBy { System.identityHashCode(it) }.size)
        assertEquals(1, drafts.first().interruptionCount)
        assertEquals(setOf(id), drafts.map { it.sessionId }.toSet())
        assertTrue(states.last() is Completed)
        val workingDirectory = Path.of(System.getProperty("user.dir"))
        val workspace = if (workingDirectory.fileName.toString() == "app") workingDirectory.parent else workingDirectory
        val path = workspace.resolve(".omo/evidence/task-2/state-transition-trace.json")
        Files.createDirectories(path.parent)
        Files.write(path, traceJson(states).toByteArray())
    }

    private fun pressing(pointerId: Int = 1, monotonic: Long = 0): Pressing {
        val ready = Ready(intensity, EntrySource.APP, previousPointerId = 99)
        val awaiting = reduce(ready, PointerDown(pointerId, monotonic))
        return reduce(awaiting, HoldThresholdReached(pointerId, monotonic + 120, sessionStart())) as Pressing
    }

    private fun sessionStart() = SessionStart(id, start)
    private fun tick(monotonic: Long, wallOffset: Long) = Tick(monotonic, EventTime.at(start.plusMillis(wallOffset), ZoneId.of("Asia/Seoul")))
}
