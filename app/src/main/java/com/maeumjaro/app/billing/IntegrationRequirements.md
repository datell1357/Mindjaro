# Billing integration requirements

`AndroidBillingGateway` is the Android/Play adapter. The app composition root must create one
gateway and one `DataStoreBillingEntitlementCache(AppStateStore)` and inject them into
`PlayBillingEntitlementRepository`.

- Call `setPurchaseUpdateListener { repository.onPurchaseUpdated() }` once during composition.
- Call `repository.onForeground()` from the Activity foreground lifecycle and expose `state` to UI.
- Pass `AndroidBillingActivityHandle(this)` from the foreground Activity to `buyPro`.
- A successful `buyPro` result only means the Play sheet was launched. Do not refresh immediately;
  the purchase callback is the authoritative trigger for query, acknowledgement, and cache write.
- `pro_lifetime` is provisional and must be replaced only with the approved Play Console product id.
