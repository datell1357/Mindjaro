package com.maeumjaro.app.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface InjectionEventDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(entity: InjectionEventEntity): Long

    @Query("SELECT COUNT(*) FROM injection_events")
    fun rowCount(): Int

    @Query("SELECT * FROM injection_events WHERE id = :id")
    suspend fun event(id: String): InjectionEventEntity?

    @Query("SELECT * FROM injection_events ORDER BY completed_at_utc DESC, id DESC LIMIT :limit")
    suspend fun latest(limit: Int): List<InjectionEventEntity>

    @Query(
        """
        SELECT * FROM injection_events
        WHERE event_local_date BETWEEN :first AND :lastInclusive
        ORDER BY completed_at_utc ASC, id ASC
        """,
    )
    suspend fun eventsInRange(first: String, lastInclusive: String): List<InjectionEventEntity>

    @Query(
        """
        SELECT event_local_date, COUNT(*) AS count, COALESCE(SUM(intensity), 0) AS intensity_sum
        FROM injection_events
        WHERE event_local_date BETWEEN :first AND :lastInclusive
        GROUP BY event_local_date
        ORDER BY event_local_date ASC
        """,
    )
    suspend fun dailyAggregates(first: String, lastInclusive: String): List<DailyAggregateRow>

    @Query(
        """
        SELECT :date AS event_local_date, COUNT(*) AS count,
               COALESCE(SUM(intensity), 0) AS intensity_sum
        FROM injection_events WHERE event_local_date = :date
        """,
    )
    suspend fun totals(date: String): DailyAggregateRow

    @Query("SELECT * FROM injection_events ORDER BY completed_at_utc ASC, id ASC")
    suspend fun chronologicalExport(): List<InjectionEventEntity>

    @Query("UPDATE injection_events SET intensity = :intensity WHERE id = :id")
    suspend fun updateIntensity(id: String, intensity: Int): Int

    @Query("DELETE FROM injection_events WHERE id = :id")
    suspend fun delete(id: String): Int

    @Query("DELETE FROM injection_events WHERE id IN (:ids)")
    suspend fun delete(ids: Set<String>): Int

    @Query("DELETE FROM injection_events")
    suspend fun deleteAll(): Int
}
