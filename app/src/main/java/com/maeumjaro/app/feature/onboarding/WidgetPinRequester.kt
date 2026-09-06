package com.maeumjaro.app.feature.onboarding

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

fun interface WidgetPinRequester {
    fun request(): Boolean
}

class AndroidWidgetPinRequester(context: Context) : WidgetPinRequester {
    private val appContext = context.applicationContext

    override fun request(): Boolean {
        val manager = AppWidgetManager.getInstance(appContext)
        if (!manager.isRequestPinAppWidgetSupported) return false
        val provider = ComponentName(appContext.packageName, WIDGET_RECEIVER_CLASS)
        return manager.requestPinAppWidget(provider, null, null)
    }

    private companion object {
        const val WIDGET_RECEIVER_CLASS = "com.maeumjaro.app.widget.MaeumjaroWidgetReceiver"
    }
}
