package com.maeumjaro.app.billing

import java.security.MessageDigest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** The provisional Play Console product id. Keep the final id as an external release gate. */
const val PRO_LIFETIME_PRODUCT_ID: String = "pro_lifetime"

enum class BillingPurchaseState { PENDING, PURCHASED, UNSPECIFIED }

data class BillingPurchase(
    val productId: String,
    val state: BillingPurchaseState,
    val purchaseToken: String,
    val acknowledged: Boolean,
)

data class BillingProduct(val productId: String, val oneTimeProduct: Boolean)

sealed interface BillingCallResult {
    data object Ok : BillingCallResult
    data object Cancelled : BillingCallResult
    data class Failed(val reason: String) : BillingCallResult
}

sealed interface BillingEntitlementState {
    data class Unknown(val cachedPro: Boolean = false) : BillingEntitlementState
    data object Free : BillingEntitlementState
    data object Pending : BillingEntitlementState
    data class Pro(val acknowledgementPending: Boolean = false) : BillingEntitlementState
    data class Error(val reason: String, val cachedPro: Boolean) : BillingEntitlementState
}

/** A confirmed local marker only; Play account identity is intentionally not persisted. */
data object CachedProEntitlement

/** Deliberately stores no purchase token. Tokens are only held in memory during a Play call. */
interface BillingEntitlementCache {
    suspend fun readConfirmedPro(): CachedProEntitlement?
    suspend fun writeConfirmedPro()
    suspend fun clearConfirmedPro()
}

interface BillingGateway {
    suspend fun connect(): BillingCallResult
    suspend fun queryProduct(productId: String): Result<BillingProduct>
    suspend fun queryOwnedPurchases(): Result<BillingOwnedPurchases>
    suspend fun acknowledge(purchaseToken: String): BillingCallResult
    suspend fun launchOneTimePurchase(product: BillingProduct, activity: BillingActivityHandle): BillingCallResult
}

data class BillingOwnedPurchases(
    val purchases: List<BillingPurchase>,
)

/** Opaque host supplied by the foreground Activity boundary. */
interface BillingActivityHandle

/**
 * Billing 9.1 boundary. A thin Android adapter can translate BillingClient callbacks into
 * [BillingGateway], keeping Play SDK classes out of domain code and tests.
 */
class PlayBillingEntitlementRepository(
    private val gateway: BillingGateway,
    private val cache: BillingEntitlementCache,
    private val productId: String = PRO_LIFETIME_PRODUCT_ID,
    initialCachedPro: Boolean = false,
) {
    private val mutableState = MutableStateFlow<BillingEntitlementState>(
        BillingEntitlementState.Unknown(initialCachedPro),
    )
    private val acknowledgedTokenDigests = mutableSetOf<String>()
    private val acknowledgementMutex = Mutex()
    val state: StateFlow<BillingEntitlementState> = mutableState.asStateFlow()

    suspend fun refresh(): BillingEntitlementState {
        val cached = cache.readConfirmedPro()
        val connected = gateway.connect()
        if (connected is BillingCallResult.Failed) {
            return publishError(connected.reason, cached != null)
        }
        val product = gateway.queryProduct(productId).getOrElse {
            return publishError("product_unavailable", cached != null)
        }
        if (!product.isValidFor(productId)) {
            return publishError("product_mismatch", cached != null)
        }
        val owned = gateway.queryOwnedPurchases().getOrElse {
            return publishError("purchase_query_failed", cached != null)
        }
        return reconcile(owned)
    }

    suspend fun onForeground(): BillingEntitlementState = refresh()

    suspend fun restore(): BillingEntitlementState = refresh()

    suspend fun buyPro(activity: BillingActivityHandle): BillingCallResult {
        val connected = gateway.connect()
        if (connected is BillingCallResult.Failed) {
            publishError(connected.reason, cache.readConfirmedPro() != null)
            return connected
        }
        val product = gateway.queryProduct(productId).getOrElse {
            publishError("product_unavailable", cache.readConfirmedPro() != null)
            return BillingCallResult.Failed("product_unavailable")
        }
        if (!product.isValidFor(productId)) {
            publishError("product_mismatch", cache.readConfirmedPro() != null)
            return BillingCallResult.Failed("product_mismatch")
        }
        val result = gateway.launchOneTimePurchase(product, activity)
        if (result is BillingCallResult.Failed) {
            publishError(result.reason, cache.readConfirmedPro() != null)
        }
        // A successful launch is not proof of ownership. The purchase callback
        // must arrive before the authoritative query/acknowledgement refresh.
        return result
    }

    /** Handles purchase-update callbacks; querying remains authoritative after the callback. */
    suspend fun onPurchaseUpdated(): BillingEntitlementState = refresh()

    /** Makes a callback-boundary failure visible without exposing purchase data. */
    fun onPurchaseUpdateFailed(reason: String): BillingEntitlementState {
        val cachedPro = when (val current = mutableState.value) {
            is BillingEntitlementState.Pro -> true
            is BillingEntitlementState.Unknown -> current.cachedPro
            is BillingEntitlementState.Error -> current.cachedPro
            BillingEntitlementState.Free,
            BillingEntitlementState.Pending,
            -> false
        }
        return publishError(reason, cachedPro)
    }

    private suspend fun reconcile(owned: BillingOwnedPurchases): BillingEntitlementState {
        // Play can return purchases for other products owned by the same account.
        // Only the configured Pro product participates in this entitlement.
        val exact = owned.purchases.filter { it.productId == productId }
        val purchased = exact.filter { it.state == BillingPurchaseState.PURCHASED }
        if (purchased.isNotEmpty()) {
            if (purchased.any { it.purchaseToken.isBlank() || it.productId.isBlank() }) {
                cache.clearConfirmedPro()
                return publishError("invalid_purchase", cachedPro = false)
            }
            val pendingAck = purchased.map { acknowledgeIfNeeded(it) }.any { it }
            cache.writeConfirmedPro()
            return mutableState.emitAndGet(BillingEntitlementState.Pro(pendingAck))
        }
        if (exact.any { it.state == BillingPurchaseState.PENDING }) {
            // A pending transaction is not proof of ownership and must invalidate stale Pro.
            cache.clearConfirmedPro()
            return mutableState.emitAndGet(BillingEntitlementState.Pending)
        }
        // A successful authoritative query is allowed to revoke a stale local cache.
        cache.clearConfirmedPro()
        return mutableState.emitAndGet(BillingEntitlementState.Free)
    }

    private suspend fun acknowledgeIfNeeded(purchase: BillingPurchase): Boolean {
        if (purchase.acknowledged) return false
        val digest = digest(purchase.purchaseToken)
        return acknowledgementMutex.withLock {
            if (digest in acknowledgedTokenDigests) return@withLock false
            when (gateway.acknowledge(purchase.purchaseToken)) {
                BillingCallResult.Ok -> {
                    acknowledgedTokenDigests += digest
                    false
                }
                BillingCallResult.Cancelled -> true
                is BillingCallResult.Failed -> true
            }
        }
    }

    private fun publishError(reason: String, cachedPro: Boolean): BillingEntitlementState {
        val state = BillingEntitlementState.Error(reason, cachedPro)
        mutableState.value = state
        return state
    }

    private fun digest(token: String): String = MessageDigest.getInstance("SHA-256")
        .digest(token.toByteArray(Charsets.UTF_8))
        .joinToString("") { byte -> "%02x".format(byte) }

    private fun BillingProduct.isValidFor(expectedId: String): Boolean =
        expectedId.isNotBlank() && productId.isNotBlank() && productId == expectedId && oneTimeProduct

    private fun <T> MutableStateFlow<T>.emitAndGet(value: T): T {
        this.value = value
        return value
    }
}

/** In-memory fake for unit tests and UI previews; it never writes raw tokens to disk. */
class InMemoryBillingEntitlementCache(
    private var value: CachedProEntitlement? = null,
) : BillingEntitlementCache {
    override suspend fun readConfirmedPro(): CachedProEntitlement? = value
    override suspend fun writeConfirmedPro() { value = CachedProEntitlement }
    override suspend fun clearConfirmedPro() { value = null }
}
