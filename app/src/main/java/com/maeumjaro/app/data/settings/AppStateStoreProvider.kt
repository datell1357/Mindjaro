package com.maeumjaro.app.data.settings

import android.content.Context
import java.util.IdentityHashMap

/**
 * Owns the process-local AppStateStore instances for each application context.
 *
 * DataStore requires one instance per file in a process. Keeping the lookup here
 * makes app, onboarding, and widget entry points share the same store instead
 * of independently constructing a DataStore for app_state.pb.
 */
object AppStateStoreProvider {
    private val lock = Any()
    private val stores = IdentityHashMap<Context, AppStateStore>()

    fun get(context: Context): AppStateStore {
        val appContext = context.applicationContext ?: context
        synchronized(lock) {
            return stores[appContext] ?: AppStateStore.create(appContext).also { stores[appContext] = it }
        }
    }
}
