package com.maeumjaro.app.data.local

import androidx.room.withTransaction
import com.maeumjaro.app.core.Intensity
import java.time.LocalDate
import java.util.UUID

interface InjectionEventRepository {
    suspend fun insertCompletedEvent(event: StoredInjectionEvent): EventInsertResult
    suspend fun totalsForStoredDate(date: LocalDate): DailyTotals
    suspend fun latest(limit: Int = 10): List<StoredInjectionEvent>
    suspend fun eventsInStoredDateRange(range: StoredDateRange): List<StoredInjectionEvent>
    suspend fun dailyAggregates(range: StoredDateRange): List<DailyAggregate>
    suspend fun sixteenWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate>
    suspend fun fiftyTwoWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate>
    suspend fun event(id: UUID): StoredInjectionEvent?
    suspend fun chronologicalExport(): List<StoredInjectionEvent>
    suspend fun editIntensity(id: UUID, intensity: Intensity): EditResult
    suspend fun deleteEvent(id: UUID, decision: DeletionDecision): DeleteResult
    suspend fun deleteEvents(ids: Set<UUID>, decision: DeletionDecision): DeleteResult
    suspend fun deleteAllEvents(decision: DeletionDecision): DeleteResult = when (decision) {
        DeletionDecision.Confirmed -> deleteEvents(chronologicalExport().map { it.id }.toSet(), decision)
        DeletionDecision.Canceled -> DeleteResult.Canceled
    }
}

class RoomInjectionEventRepository(private val database: MaeumjaroDatabase) : InjectionEventRepository {
    private val dao = database.injectionEventDao()

    override suspend fun insertCompletedEvent(event: StoredInjectionEvent): EventInsertResult =
        database.withTransaction {
            if (dao.insert(event.toEntity()) == -1L) {
                EventInsertResult.AlreadyExists
            } else {
                EventInsertResult.Inserted
            }
        }

    override suspend fun totalsForStoredDate(date: LocalDate): DailyTotals =
        dao.totals(date.toString()).let { DailyTotals(date, it.count, it.intensitySum) }

    override suspend fun latest(limit: Int): List<StoredInjectionEvent> {
        require(limit > 0)
        return dao.latest(limit).map(InjectionEventEntity::toStoredEvent)
    }

    override suspend fun eventsInStoredDateRange(range: StoredDateRange): List<StoredInjectionEvent> =
        dao.eventsInRange(range.first.toString(), range.lastInclusive.toString())
            .map(InjectionEventEntity::toStoredEvent)

    override suspend fun dailyAggregates(range: StoredDateRange): List<DailyAggregate> =
        dao.dailyAggregates(range.first.toString(), range.lastInclusive.toString()).map {
            DailyAggregate(LocalDate.parse(it.eventLocalDate), it.count, it.intensitySum)
        }

    override suspend fun sixteenWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> =
        aggregatesForWeeks(endingOn, 16)

    override suspend fun fiftyTwoWeekDailyAggregates(endingOn: LocalDate): List<DailyAggregate> =
        aggregatesForWeeks(endingOn, 52)

    override suspend fun event(id: UUID): StoredInjectionEvent? = dao.event(id.toString())?.toStoredEvent()

    override suspend fun chronologicalExport(): List<StoredInjectionEvent> =
        dao.chronologicalExport().map(InjectionEventEntity::toStoredEvent)

    override suspend fun editIntensity(id: UUID, intensity: Intensity): EditResult =
        if (dao.updateIntensity(id.toString(), intensity.value) == 1) EditResult.Updated else EditResult.Missing

    override suspend fun deleteEvent(id: UUID, decision: DeletionDecision): DeleteResult = when (decision) {
        DeletionDecision.Confirmed -> DeleteResult.Deleted(dao.delete(id.toString()))
        DeletionDecision.Canceled -> DeleteResult.Canceled
    }

    override suspend fun deleteEvents(ids: Set<UUID>, decision: DeletionDecision): DeleteResult = when (decision) {
        DeletionDecision.Confirmed -> DeleteResult.Deleted(dao.delete(ids.map(UUID::toString).toSet()))
        DeletionDecision.Canceled -> DeleteResult.Canceled
    }

    override suspend fun deleteAllEvents(decision: DeletionDecision): DeleteResult = when (decision) {
        DeletionDecision.Confirmed -> DeleteResult.Deleted(dao.deleteAll())
        DeletionDecision.Canceled -> DeleteResult.Canceled
    }

    private suspend fun aggregatesForWeeks(endingOn: LocalDate, weeks: Long): List<DailyAggregate> =
        dailyAggregates(StoredDateRange(endingOn.minusWeeks(weeks).plusDays(1), endingOn))
}
