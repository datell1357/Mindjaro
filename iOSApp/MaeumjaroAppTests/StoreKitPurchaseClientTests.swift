import Foundation
import StoreKitTest
import XCTest

@testable import Maeumjaro

final class StoreKitPurchaseClientTests: XCTestCase {
    private func makeLocalSession() throws -> SKTestSession {
        let configurationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Maeumjaro/Resources/Maeumjaro.storekit")
        let session = try SKTestSession(contentsOf: configurationURL)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    func testProductContractUsesTheApprovedNonConsumableIdentifier() {
        XCTAssertEqual(StoreKitPurchaseClient.productID, "com.yeoreum.maeumjaro.pro")

        let product = PurchaseProduct(
            id: StoreKitPurchaseClient.productID,
            displayNameKorean: "마음자로 Pro",
            displayNameEnglish: "Maeumjaro Pro",
            displayPrice: "₩9,900",
            isNonConsumable: true
        )

        XCTAssertEqual(product.id, "com.yeoreum.maeumjaro.pro")
        XCTAssertTrue(product.isNonConsumable)
        XCTAssertEqual(product.displayNameKorean, "마음자로 Pro")
        XCTAssertEqual(product.displayNameEnglish, "Maeumjaro Pro")
    }

    func testLocalStoreKitConfigurationContainsOnlyTheProNonConsumable() throws {
        let sourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let configurationURL = sourceDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Maeumjaro/Resources/Maeumjaro.storekit")
        let data = try Data(contentsOf: configurationURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(object["products"] as? [[String: Any]])

        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?["productID"] as? String, StoreKitPurchaseClient.productID)
        XCTAssertEqual(products.first?["type"] as? String, "NonConsumable")
        let localizations = try XCTUnwrap(products.first?["localizations"] as? [[String: Any]])
        let korean = try XCTUnwrap(localizations.first { $0["locale"] as? String == "ko_KR" })
        let english = try XCTUnwrap(localizations.first { $0["locale"] as? String == "en_US" })
        XCTAssertEqual(korean["displayName"] as? String, "마음자로 Pro")
        XCTAssertEqual(english["displayName"] as? String, "Maeumjaro Pro")
        let subscriptionGroups = try XCTUnwrap(object["subscriptionGroups"] as? [[String: Any]])
        XCTAssertTrue(subscriptionGroups.isEmpty)
    }

    func testPurchaseOutcomeModelsKeepUnverifiedAndPendingOutsidePro() {
        let unverified = PurchaseResult.success(.unverified(productID: StoreKitPurchaseClient.productID))
        let pending = PurchaseResult.pending

        XCTAssertEqual(unverified, .success(.unverified(productID: StoreKitPurchaseClient.productID)))
        XCTAssertEqual(pending, .pending)
        XCTAssertNotEqual(unverified, .success(.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 1,
            originalTransactionID: 1
        ))))
    }

    #if DEBUG && MAEUMJARO_QA_FIXTURES
    func testOfflineFixtureFailsClosedForAllCommerceOperations() async {
        let client = QAFailingStoreKitClient()

        do {
            _ = try await client.product()
            XCTFail("Offline fixture must not expose a product")
        } catch {
            XCTAssertEqual(error as? PurchaseClientError, .storeUnavailable)
        }
        let purchaseResult = await client.purchase()
        XCTAssertEqual(purchaseResult, .failed(.storeUnavailable))
        do {
            _ = try await client.currentEntitlements()
            XCTFail("Offline fixture must not claim entitlements")
        } catch {
            XCTAssertEqual(error as? PurchaseClientError, .storeUnavailable)
        }
        do {
            try await client.syncStore()
            XCTFail("Offline fixture sync must fail")
        } catch {
            XCTAssertEqual(error as? PurchaseClientError, .storeUnavailable)
        }

        let store = ProEntitlementStore(client: client)
        let restoreResult = await store.restore()
        XCTAssertEqual(restoreResult, .failure(.storeUnavailable))

        var updates = [TransactionEvidence]()
        for await update in client.transactionUpdates() {
            updates.append(update)
        }
        XCTAssertTrue(updates.isEmpty)
    }
    #endif

    func testLocalStoreKitSessionCreatesVerifiedCurrentEntitlement() async throws {
        let session = try makeLocalSession()
        _ = try await session.buyProduct(identifier: StoreKitPurchaseClient.productID)

        let entitlements = try await StoreKitPurchaseClient().currentEntitlements()

        XCTAssertEqual(entitlements.count, 1)
        guard case .verified(let transaction) = entitlements.first else {
            return XCTFail("Local StoreKit purchase must produce a verified entitlement")
        }
        XCTAssertEqual(transaction.productID, StoreKitPurchaseClient.productID)
    }

    func testLocalStoreKitRefundRemovesCurrentEntitlement() async throws {
        let session = try makeLocalSession()
        _ = try await session.buyProduct(identifier: StoreKitPurchaseClient.productID)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)

        let entitlements = try await StoreKitPurchaseClient().currentEntitlements()

        XCTAssertTrue(entitlements.isEmpty)
    }
}
