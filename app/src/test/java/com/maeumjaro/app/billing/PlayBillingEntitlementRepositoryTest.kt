package com.maeumjaro.app.billing

import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import com.maeumjaro.app.feature.analytics.effectiveEntitlement
import com.maeumjaro.app.feature.analytics.Entitlement

class PlayBillingEntitlementRepositoryTest {
    @Test fun `unknown is initial and connect failure exposes cached pro continuity`() = runTest {
        val fake = FakeGateway(connect = BillingCallResult.Failed("offline"))
        val repo = repository(fake, InMemoryBillingEntitlementCache(CachedProEntitlement), initialCachedPro = true)
        assertEquals(BillingEntitlementState.Unknown(true), repo.state.value)
        assertEquals(BillingEntitlementState.Error("offline", true), repo.refresh())
    }

    @Test fun `pending never grants pro`() = runTest {
        val cache = InMemoryBillingEntitlementCache(CachedProEntitlement)
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PENDING)))
        val repo = repository(fake, cache)
        assertEquals(BillingEntitlementState.Pending, repo.refresh())
        assertEquals(null, cache.readConfirmedPro())
    }

    @Test fun `cancelled purchase remains free`() = runTest {
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.UNSPECIFIED)))
        assertEquals(BillingEntitlementState.Free, repository(fake).refresh())
    }

    @Test fun `purchased exact product grants pro and acknowledges once`() = runTest {
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PURCHASED)))
        val repo = repository(fake)
        assertEquals(BillingEntitlementState.Pro(false), repo.refresh())
        repo.onPurchaseUpdated()
        assertEquals(1, fake.acknowledgements)
    }

    @Test fun `cold purchase connects before launching`() = runTest {
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PURCHASED)))
        val repo = repository(fake)
        assertEquals(BillingCallResult.Ok, repo.buyPro(TestActivity))
        assertTrue(fake.connects > 0)
        assertTrue(fake.launched)
        assertEquals(0, fake.ownedQueries)
    }

    @Test fun `purchase callback refreshes authoritative ownership`() = runTest {
        val fake = FakeGateway(purchases = emptyList())
        val repo = repository(fake)

        assertEquals(BillingEntitlementState.Free, repo.onPurchaseUpdated())
        assertEquals(1, fake.ownedQueries)
    }

    @Test fun `cancelled launch stays neutral instead of publishing an error`() = runTest {
        val fake = FakeGateway(launch = BillingCallResult.Cancelled)
        val repo = repository(fake)

        assertEquals(BillingCallResult.Cancelled, repo.buyPro(TestActivity))
        assertEquals(BillingEntitlementState.Unknown(false), repo.state.value)
    }

    @Test fun `purchase callback failure is visible and preserves confirmed pro continuity`() = runTest {
        val repo = repository(FakeGateway(), initialCachedPro = true)

        assertEquals(
            BillingEntitlementState.Error("purchase_update_refresh_failed", true),
            repo.onPurchaseUpdateFailed("purchase_update_refresh_failed"),
        )
    }

    @Test fun `all purchased items are acknowledged`() = runTest {
        val fake = FakeGateway(purchases = listOf(
            purchase(BillingPurchaseState.PURCHASED),
            purchase(BillingPurchaseState.PURCHASED).copy(purchaseToken = "second-token"),
        ))
        assertEquals(BillingEntitlementState.Pro(false), repository(fake).refresh())
        assertEquals(2, fake.acknowledgements)
    }

    @Test fun `acknowledgement attempts every purchased item after an earlier failure`() = runTest {
        val fake = FakeGateway(
            purchases = listOf(
                purchase(BillingPurchaseState.PURCHASED),
                purchase(BillingPurchaseState.PURCHASED).copy(purchaseToken = "second-token"),
            ),
            acknowledge = BillingCallResult.Failed("retry"),
        )
        val repo = repository(fake)
        assertEquals(BillingEntitlementState.Pro(true), repo.refresh())
        assertEquals(2, fake.acknowledgements)
    }

    @Test fun `concurrent refreshes single flight acknowledgement per token`() = runTest {
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PURCHASED)))
        val repo = repository(fake)
        listOf(async { repo.refresh() }, async { repo.refresh() }).awaitAll()
        assertEquals(1, fake.acknowledgements)
    }

    @Test fun `blank token fails closed while unrelated blank identifier is ignored`() = runTest {
        val blankToken = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PURCHASED).copy(purchaseToken = " ")))
        assertEquals(BillingEntitlementState.Error("invalid_purchase", false), repository(blankToken).refresh())
        val blankProduct = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PURCHASED).copy(productId = "")))
        assertEquals(BillingEntitlementState.Free, repository(blankProduct).refresh())
    }

    @Test fun `ack failure is retryable and does not lose pro`() = runTest {
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PURCHASED)), acknowledge = BillingCallResult.Failed("retry"))
        val repo = repository(fake)
        assertEquals(BillingEntitlementState.Pro(true), repo.refresh())
        fake.acknowledgeResult = BillingCallResult.Ok
        assertEquals(BillingEntitlementState.Pro(false), repo.refresh())
        assertEquals(2, fake.acknowledgements)
    }

    @Test fun `successful no purchase downgrades and wrong product fails closed`() = runTest {
        val cache = InMemoryBillingEntitlementCache(CachedProEntitlement)
        val fake = FakeGateway(purchases = emptyList())
        assertEquals(BillingEntitlementState.Free, repository(fake, cache).refresh())
        fake.product = BillingProduct("other", true)
        assertEquals(BillingEntitlementState.Error("product_mismatch", false), repository(fake, cache).refresh())
    }

    @Test fun `owned unrelated product is ignored`() = runTest {
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PURCHASED).copy(productId = "other")))
        assertEquals(BillingEntitlementState.Free, repository(fake).refresh())
    }

    @Test fun `purchased expected product remains pro with unrelated owned product`() = runTest {
        val fake = FakeGateway(
            purchases = listOf(
                purchase(BillingPurchaseState.PURCHASED),
                purchase(BillingPurchaseState.PURCHASED).copy(productId = "other", purchaseToken = "other-token"),
            ),
        )

        assertEquals(BillingEntitlementState.Pro(false), repository(fake).refresh())
        assertEquals(1, fake.acknowledgements)
    }

    @Test fun `pending to purchased remains authoritative without account identity`() = runTest {
        val fake = FakeGateway(purchases = listOf(purchase(BillingPurchaseState.PENDING)))
        val repo = repository(fake)
        assertEquals(BillingEntitlementState.Pending, repo.restore())
        fake.purchases = listOf(purchase(BillingPurchaseState.PURCHASED))
        assertEquals(BillingEntitlementState.Pro(false), repo.restore())
        assertEquals(BillingEntitlementState.Pro(false), repo.restore())
    }

    @Test fun `effective access is fail closed except confirmed pro continuity`() {
        assertEquals(Entitlement.PRO, BillingEntitlementState.Pro().effectiveEntitlement())
        assertEquals(Entitlement.PRO, BillingEntitlementState.Error("offline", true).effectiveEntitlement())
        assertEquals(Entitlement.PRO, BillingEntitlementState.Unknown(true).effectiveEntitlement())
        assertEquals(Entitlement.FREE, BillingEntitlementState.Unknown(false).effectiveEntitlement())
        assertEquals(Entitlement.FREE, BillingEntitlementState.Free.effectiveEntitlement())
        assertEquals(Entitlement.FREE, BillingEntitlementState.Pending.effectiveEntitlement())
        assertEquals(Entitlement.FREE, BillingEntitlementState.Error("bad", false).effectiveEntitlement())
    }

    private fun repository(
        fake: FakeGateway,
        cache: InMemoryBillingEntitlementCache = InMemoryBillingEntitlementCache(),
        initialCachedPro: Boolean = false,
    ) = PlayBillingEntitlementRepository(fake, cache, initialCachedPro = initialCachedPro)

    private fun purchase(state: BillingPurchaseState) = BillingPurchase("pro_lifetime", state, "secret-token", false)
    private object TestActivity : BillingActivityHandle

    private class FakeGateway(
        var connect: BillingCallResult = BillingCallResult.Ok,
        var purchases: List<BillingPurchase> = emptyList(),
        acknowledge: BillingCallResult = BillingCallResult.Ok,
        var launch: BillingCallResult = BillingCallResult.Ok,
    ) : BillingGateway {
        var product = BillingProduct("pro_lifetime", true)
        var acknowledgeResult = acknowledge
        var acknowledgements = 0
        var ownedQueries = 0
        var connects = 0
        var launched = false
        override suspend fun connect(): BillingCallResult { connects++; return connect }
        override suspend fun queryProduct(productId: String) = Result.success(product)
        override suspend fun queryOwnedPurchases(): Result<BillingOwnedPurchases> {
            ownedQueries++
            return Result.success(BillingOwnedPurchases(purchases))
        }
        override suspend fun acknowledge(purchaseToken: String): BillingCallResult { acknowledgements++; return acknowledgeResult }
        override suspend fun launchOneTimePurchase(product: BillingProduct, activity: BillingActivityHandle): BillingCallResult { launched = true; return launch }
    }
}
