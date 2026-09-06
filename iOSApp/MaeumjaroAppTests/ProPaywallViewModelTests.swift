import MaeumjaroDomain
import XCTest
@testable import Maeumjaro

final class ProPaywallViewModelTests: XCTestCase {
    func testDefaultProductLoaderUsesInjectedStoreClient() async {
        let store = ProEntitlementStore(client: PaywallFakeClient())
        let model = await MainActor.run {
            ProPaywallViewModel(store: store)
        }

        await model.refresh()

        let product = await MainActor.run { model.product }
        XCTAssertEqual(product, PaywallFakeClient.product)
    }

    func testRefreshLoadsProductAndVerifiedEntitlementEnablesPurchase() async {
        let client = PaywallFakeClient()
        let store = ProEntitlementStore(client: client)
        let model = await MainActor.run {
            ProPaywallViewModel(store: store, productLoader: { PaywallFakeClient.product })
        }

        await model.refresh()

        let canPurchase = await MainActor.run { model.canPurchase }
        let displayPrice = await MainActor.run { model.product?.displayPrice }
        XCTAssertTrue(canPurchase)
        XCTAssertEqual(displayPrice, "₩9,900")
    }

    func testUnverifiedPurchaseDoesNotClaimActivation() async {
        let client = PaywallFakeClient(purchaseResult: .success(.unverified(productID: StoreKitPurchaseClient.productID)))
        let store = ProEntitlementStore(client: client)
        let model = await MainActor.run {
            ProPaywallViewModel(entitlement: .free, store: store, productLoader: { PaywallFakeClient.product })
        }
        await model.refresh()
        await model.purchase()

        let entitlement = await MainActor.run { model.entitlement }
        let status = await MainActor.run { model.status }
        XCTAssertEqual(entitlement, .unverified)
        XCTAssertEqual(status, "구매를 확인하지 못했어요.")
    }
}

private struct PaywallFakeClient: StoreKitPurchaseClientProtocol, Sendable {
    nonisolated static let product = PurchaseProduct(id: StoreKitPurchaseClient.productID, displayNameKorean: "마음자로 Pro", displayNameEnglish: "Maeumjaro Pro", displayPrice: "₩9,900", isNonConsumable: true)
    private let result: PurchaseResult
    init(purchaseResult: PurchaseResult = .cancelled) { result = purchaseResult }
    nonisolated func product() async throws -> PurchaseProduct { Self.product }
    nonisolated func purchase() async -> PurchaseResult { result }
    nonisolated func currentEntitlements() async throws -> [TransactionEvidence] { [] }
    nonisolated func transactionUpdates() -> AsyncStream<TransactionEvidence> { AsyncStream { _ in } }
    nonisolated func syncStore() async throws {}
}
