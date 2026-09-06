package com.maeumjaro.app.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import kotlin.coroutines.resume

/** Foreground Activity boundary used only while Play's purchase sheet is launched. */
class AndroidBillingActivityHandle(val activity: Activity) : BillingActivityHandle

/**
 * Android Play Billing adapter. SDK objects stay here; the rest of the app depends on
 * [BillingGateway] and can therefore be tested without Play services.
 */
class AndroidBillingGateway(
    context: Context,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) : BillingGateway {
    private val productDetails = ConcurrentHashMap<String, ProductDetails>()
    private var purchaseListener: (suspend () -> Unit)? = null
    private var purchaseFailureListener: ((String) -> Unit)? = null
    private val billingClient: BillingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener(PurchasesUpdatedListener { result, _ ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                scope.launchPurchaseUpdate { purchaseListener?.invoke() }
            } else {
                purchaseFailureListener?.invoke(result.reason())
            }
        })
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder()
                .enableOneTimeProducts()
                .build(),
        )
        .enableAutoServiceReconnection()
        .build()

    fun setPurchaseUpdateListener(
        listener: (suspend () -> Unit)?,
        onFailure: ((String) -> Unit)? = null,
    ) {
        purchaseListener = listener
        purchaseFailureListener = onFailure
    }

    override suspend fun connect(): BillingCallResult = suspendCancellableCoroutine { continuation ->
        if (billingClient.isReady) {
            continuation.resume(BillingCallResult.Ok)
            return@suspendCancellableCoroutine
        }
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                continuation.resume(result.toCallResult())
            }

            override fun onBillingServiceDisconnected() = Unit
        })
        continuation.invokeOnCancellation { billingClient.endConnection() }
    }

    override suspend fun queryProduct(productId: String): Result<BillingProduct> =
        suspendCancellableCoroutine { continuation ->
            val params = QueryProductDetailsParams.newBuilder()
                .setProductList(
                    listOf(
                        QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(productId)
                            .setProductType(BillingClient.ProductType.INAPP)
                            .build(),
                    ),
                )
                .build()
            billingClient.queryProductDetailsAsync(params) { result, queryResult ->
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    continuation.resume(Result.failure(IllegalStateException(result.reason())))
                } else {
                    val detail = queryResult.productDetailsList.firstOrNull { it.productId == productId }
                    if (detail == null) {
                        continuation.resume(Result.failure(IllegalStateException("product_not_found")))
                    } else {
                        productDetails[productId] = detail
                        continuation.resume(
                            Result.success(
                                BillingProduct(
                                    productId,
                                    detail.oneTimePurchaseOfferDetails != null,
                                ),
                            ),
                        )
                    }
                }
            }
        }

    override suspend fun queryOwnedPurchases(): Result<BillingOwnedPurchases> =
        suspendCancellableCoroutine { continuation ->
            val params = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
            billingClient.queryPurchasesAsync(params) { result, purchases ->
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    continuation.resume(Result.failure(IllegalStateException(result.reason())))
                } else {
                    continuation.resume(Result.success(BillingOwnedPurchases(purchases.map { it.toDomain() })))
                }
            }
        }

    override suspend fun acknowledge(purchaseToken: String): BillingCallResult =
        suspendCancellableCoroutine { continuation ->
            billingClient.acknowledgePurchase(
                AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchaseToken).build(),
            ) { result -> continuation.resume(result.toCallResult()) }
        }

    override suspend fun launchOneTimePurchase(
        product: BillingProduct,
        activity: BillingActivityHandle,
    ): BillingCallResult {
        val host = activity as? AndroidBillingActivityHandle
            ?: return BillingCallResult.Failed("invalid_activity_handle")
        val details = productDetails[product.productId]
            ?: return BillingCallResult.Failed("product_not_loaded")
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(details)
                        .build(),
                ),
            )
            .build()
        return billingClient.launchBillingFlow(host.activity, params).toCallResult()
    }

    private fun Purchase.toDomain(): BillingPurchase = BillingPurchase(
        productId = products.firstOrNull().orEmpty(),
        state = when (purchaseState) {
            Purchase.PurchaseState.PENDING -> BillingPurchaseState.PENDING
            Purchase.PurchaseState.PURCHASED -> BillingPurchaseState.PURCHASED
            else -> BillingPurchaseState.UNSPECIFIED
        },
        purchaseToken = purchaseToken,
        acknowledged = isAcknowledged,
    )

    private fun BillingResult.reason(): String =
        "billing_$responseCode"

    private fun CoroutineScope.launchPurchaseUpdate(block: suspend () -> Unit) {
        launch {
            try {
                block()
            } catch (cancellation: CancellationException) {
                throw cancellation
            } catch (_: Exception) {
                purchaseFailureListener?.invoke("purchase_update_refresh_failed")
            }
        }
    }
}

internal fun BillingResult.toCallResult(): BillingCallResult =
    when (responseCode) {
        BillingClient.BillingResponseCode.OK -> BillingCallResult.Ok
        BillingClient.BillingResponseCode.USER_CANCELED -> BillingCallResult.Cancelled
        else -> BillingCallResult.Failed("billing_$responseCode")
    }
