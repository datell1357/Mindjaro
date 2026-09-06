package com.maeumjaro.app.data.local

import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

object MaeumjaroMigrations {
    val MIGRATION_1_2 = object : Migration(1, 2) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS custom_phrases (
                    id TEXT NOT NULL PRIMARY KEY,
                    text TEXT NOT NULL CHECK(length(trim(text)) BETWEEN 1 AND 120),
                    tone TEXT NOT NULL CHECK(tone IN ('GENTLE', 'NEUTRAL', 'FIRM', 'AUTOMATIC')),
                    category TEXT NOT NULL CHECK(category IN ('SEPARATION', 'IMPERMANENCE', 'AUTONOMY', 'REDIRECT', 'NONJUDGMENT')),
                    created_at_utc INTEGER NOT NULL CHECK(created_at_utc >= 0),
                    validation_state TEXT NOT NULL CHECK(validation_state IN ('NOT_VALIDATED', 'VALID', 'UNSAFE')),
                    archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0, 1)),
                    revision INTEGER NOT NULL DEFAULT 1 CHECK(revision >= 1),
                    updated_at_utc INTEGER NOT NULL CHECK(updated_at_utc >= 0)
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX IF NOT EXISTS index_custom_phrases_archived ON custom_phrases(archived)")
        }
    }

    val ALL: Array<Migration> = arrayOf(MIGRATION_1_2)
}

internal object InjectionEventSchema {
    val callback = object : RoomDatabase.Callback() {
        override fun onCreate(db: SupportSQLiteDatabase) {
            db.execSQL("DROP TABLE injection_events")
            db.execSQL(
                """
                CREATE TABLE injection_events (
                    id TEXT NOT NULL PRIMARY KEY,
                    started_at_utc INTEGER NOT NULL,
                    completed_at_utc INTEGER NOT NULL,
                    event_local_date TEXT NOT NULL,
                    timezone_offset_minutes INTEGER NOT NULL,
                    intensity INTEGER NOT NULL CHECK(intensity BETWEEN 1 AND 5),
                    source TEXT NOT NULL CHECK(source IN ('app', 'widget')),
                    phrase_id TEXT NOT NULL,
                    animation_duration_ms INTEGER NOT NULL CHECK(animation_duration_ms >= 0),
                    interruption_count INTEGER NOT NULL CHECK(interruption_count >= 0),
                    app_version TEXT NOT NULL,
                    created_at_utc INTEGER NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX index_injection_events_event_local_date ON injection_events(event_local_date)")
            db.execSQL("CREATE INDEX index_injection_events_completed_at_utc ON injection_events(completed_at_utc DESC)")
            db.execSQL(
                "CREATE INDEX index_injection_events_event_local_date_completed_at_utc " +
                    "ON injection_events(event_local_date, completed_at_utc)",
            )
        }
    }
}
