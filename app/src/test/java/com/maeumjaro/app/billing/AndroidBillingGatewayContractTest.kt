package com.maeumjaro.app.billing

import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidBillingGatewayContractTest {
    @Test
    fun `user canceled maps to a neutral cancelled result`() {
        assertEquals(
            BillingCallResult.Cancelled,
            billingResult(BillingClient.BillingResponseCode.USER_CANCELED, "user data").toCallResult(),
        )
    }

    @Test
    fun `non ok billing errors expose only a stable code`() {
        val result = billingResult(BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE, "account@example.com")
            .toCallResult()

        assertEquals(
            BillingCallResult.Failed("billing_${BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE}"),
            result,
        )
        assertTrue(result is BillingCallResult.Failed && "account@example.com" !in result.reason)
    }

    private fun billingResult(responseCode: Int, debugMessage: String): BillingResult =
        BillingResult.newBuilder()
            .setResponseCode(responseCode)
            .setDebugMessage(debugMessage)
            .build()
}
