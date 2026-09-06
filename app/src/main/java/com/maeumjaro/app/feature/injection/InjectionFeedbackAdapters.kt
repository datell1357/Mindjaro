package com.maeumjaro.app.feature.injection

import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.annotation.RawRes

interface InjectionFeedbackPlayer {
    /** Returns false when the device cannot produce the requested feedback. */
    fun play(effect: InjectionFeedback, state: InjectionUiState): Boolean
    fun stop()
}

object SilentInjectionFeedbackPlayer : InjectionFeedbackPlayer {
    override fun play(effect: InjectionFeedback, state: InjectionUiState) = false
    override fun stop() = Unit
}

class AndroidInjectionFeedbackPlayer(
    private val view: View,
    @RawRes completionSound: Int? = null,
) : InjectionFeedbackPlayer, AutoCloseable {
    private val soundPool = completionSound?.let {
        SoundPool.Builder()
            .setMaxStreams(1)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build())
            .build()
    }
    private val soundId = completionSound?.let { soundPool?.load(view.context, it, 1) }
    private var streamId = 0

    override fun play(effect: InjectionFeedback, state: InjectionUiState): Boolean {
        var produced = false
        if (state.hapticsEnabled && view.isHapticFeedbackEnabled && effect !is InjectionFeedback.Reset) {
            val constant = when (effect) {
                InjectionFeedback.Started -> HapticFeedbackConstants.CONTEXT_CLICK
                is InjectionFeedback.Progress -> HapticFeedbackConstants.CLOCK_TICK
                InjectionFeedback.Completed -> if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.LONG_PRESS
                InjectionFeedback.Paused -> HapticFeedbackConstants.VIRTUAL_KEY
                InjectionFeedback.Reset -> HapticFeedbackConstants.VIRTUAL_KEY
            }
            produced = view.performHapticFeedback(constant)
        }
        if (state.soundEnabled && effect is InjectionFeedback.Completed && soundId != null) {
            streamId = soundPool?.play(soundId, 0.24f, 0.24f, 1, 0, 1f) ?: 0
            produced = produced || streamId != 0
        }
        if (effect is InjectionFeedback.Paused || effect is InjectionFeedback.Reset) stop()
        return produced
    }

    override fun stop() {
        if (streamId != 0) soundPool?.stop(streamId)
        streamId = 0
    }

    override fun close() {
        stop()
        soundPool?.release()
    }
}
