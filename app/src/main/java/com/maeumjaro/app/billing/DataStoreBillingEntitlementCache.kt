package com.maeumjaro.app.billing

import com.maeumjaro.app.data.settings.AppStateStore

/** Persists only a confirmed Pro marker; raw Play purchase tokens never leave memory. */
class DataStoreBillingEntitlementCache(
    private val appStateStore: AppStateStore,
    private val nowEpochMillis: () -> Long = { System.currentTimeMillis() },
) : BillingEntitlementCache {
    override suspend fun readConfirmedPro(): CachedProEntitlement? =
        appStateStore.confirmedEntitlementCache()
            ?.takeIf { it.productId == PRO_LIFETIME_PRODUCT_ID }
            ?.let { CachedProEntitlement }

    override suspend fun writeConfirmedPro() {
        appStateStore.writeConfirmedPro(PRO_LIFETIME_PRODUCT_ID, nowEpochMillis().coerceAtLeast(0L))
    }

    override suspend fun clearConfirmedPro() {
        appStateStore.clearConfirmedEntitlementCache()
    }
}
