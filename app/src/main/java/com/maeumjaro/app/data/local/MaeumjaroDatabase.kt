package com.maeumjaro.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [InjectionEventEntity::class, CustomPhraseEntity::class],
    version = MaeumjaroDatabase.VERSION,
    exportSchema = true,
)
abstract class MaeumjaroDatabase : RoomDatabase() {
    abstract fun injectionEventDao(): InjectionEventDao
    abstract fun customPhraseDao(): CustomPhraseDao

    companion object {
        const val VERSION = 2

        fun create(context: Context): MaeumjaroDatabase = Room.databaseBuilder(
            context,
            MaeumjaroDatabase::class.java,
            "maeumjaro.db",
        ).addMigrations(*MaeumjaroMigrations.ALL)
            .addCallback(InjectionEventSchema.callback)
            .build()

        fun inMemory(context: Context): MaeumjaroDatabase = Room.inMemoryDatabaseBuilder(
            context,
            MaeumjaroDatabase::class.java,
        ).addCallback(InjectionEventSchema.callback)
            .build()
    }
}
