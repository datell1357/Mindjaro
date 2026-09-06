package com.maeumjaro.app.data.settings

import androidx.datastore.core.CorruptionException
import androidx.datastore.core.Serializer
import com.google.protobuf.InvalidProtocolBufferException
import java.io.InputStream
import java.io.OutputStream

object AppStateSerializer : Serializer<AppState> {
    override val defaultValue: AppState = AppStatePolicy.defaultValue

    override suspend fun readFrom(input: InputStream): AppState = try {
        AppStatePolicy.normalize(AppState.parseFrom(input))
    } catch (error: InvalidProtocolBufferException) {
        throw CorruptionException("Cannot read app state proto.", error)
    }

    override suspend fun writeTo(t: AppState, output: OutputStream) {
        AppStatePolicy.normalize(t).writeTo(output)
    }
}
