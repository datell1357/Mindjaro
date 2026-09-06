package com.maeumjaro.app.data.settings

import android.content.ContextWrapper
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppStateStoreProviderTest {
    @Test
    fun applicationContext_wrappers_share_one_store_instance() {
        val applicationContext = ApplicationProvider.getApplicationContext<android.content.Context>()
        val wrappedContext = ContextWrapper(applicationContext)

        assertSame(
            AppStateStoreProvider.get(applicationContext),
            AppStateStoreProvider.get(wrappedContext),
        )
    }
}
