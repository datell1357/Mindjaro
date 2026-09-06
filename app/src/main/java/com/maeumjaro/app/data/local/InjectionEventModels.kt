package com.maeumjaro.app.data.local

import java.time.LocalDate

data class StoredDateRange(val first: LocalDate, val lastInclusive: LocalDate) {
    init {
        require(first <= lastInclusive)
    }
}

data class DailyTotals(val date: LocalDate, val count: Int, val intensitySum: Int)
data class DailyAggregate(val date: LocalDate, val count: Int, val intensitySum: Int)

data class DailyAggregateRow(
    @androidx.room.ColumnInfo(name = "event_local_date") val eventLocalDate: String,
    val count: Int,
    @androidx.room.ColumnInfo(name = "intensity_sum") val intensitySum: Int,
)

sealed interface EventInsertResult {
    data object Inserted : EventInsertResult
    data object AlreadyExists : EventInsertResult
}

sealed interface EditResult {
    data object Updated : EditResult
    data object Missing : EditResult
}

enum class DeletionDecision { Confirmed, Canceled }

sealed interface DeleteResult {
    data class Deleted(val count: Int) : DeleteResult
    data object Canceled : DeleteResult
}
