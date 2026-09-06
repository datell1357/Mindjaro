import XCTest

@testable import Maeumjaro

final class ProEntitlementStoreTests: XCTestCase {
    func testVerifiedPurchaseUnlocksOnlyTheApprovedProduct() async {
        let client = FakePurchaseClient(purchaseResult: .success(.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 42,
            originalTransactionID: 42
        ))))
        let store = ProEntitlementStore(client: client)

        let result = await store.purchase()

        XCTAssertEqual(result, .success(.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 42,
            originalTransactionID: 42
        ))))
        let entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .pro)
    }

    func testUnverifiedPurchaseCannotUnlockPro() async {
        let client = FakePurchaseClient(purchaseResult: .success(.unverified(
            productID: StoreKitPurchaseClient.productID
        )))
        let store = ProEntitlementStore(client: client)

        _ = await store.purchase()

        let entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .unverified)
        XCTAssertNotEqual(entitlement, .pro)
    }

    func testCancelAndFailureAreFailClosed() async {
        let client = FakePurchaseClient(purchaseResult: .cancelled)
        let store = ProEntitlementStore(client: client)

        _ = await store.purchase()
        var entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .free)

        await client.setPurchaseResult(.failed(.storeUnavailable))
        _ = await store.purchase()
        entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .error)
        XCTAssertNotEqual(entitlement, .pro)
    }

    func testPendingRemainsNonProUntilASeparateVerifiedUpdateArrives() async {
        let client = FakePurchaseClient(purchaseResult: .pending)
        let store = ProEntitlementStore(client: client)

        _ = await store.purchase()
        var entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .pending)

        await store.applyUpdate(.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 99,
            originalTransactionID: 99
        )))

        entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .pro)
    }

    func testCurrentEntitlementsAndRepeatedUpdatesAreIdempotent() async throws {
        let verified = TransactionEvidence.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 7,
            originalTransactionID: 7
        ))
        let client = FakePurchaseClient(currentEntitlements: [verified])
        let store = ProEntitlementStore(client: client)

        let stream = await store.stateStream()
        var iterator = stream.makeAsyncIterator()
        let initialState = await iterator.next()
        XCTAssertEqual(initialState, .loading)

        await store.refresh()
        let refreshedState = await iterator.next()
        XCTAssertEqual(refreshedState, .pro)
        await store.refresh()
        let entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .pro)
        let readCount = await client.currentEntitlementReadCount
        XCTAssertEqual(readCount, 2)
    }

    func testRevocationDowngradesAndAnEmptyRefreshBecomesFree() async {
        let client = FakePurchaseClient(currentEntitlements: [.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 8,
            originalTransactionID: 8
        ))])
        let store = ProEntitlementStore(client: client)

        await store.refresh()
        var entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .pro)

        await store.applyUpdate(.revoked(productID: StoreKitPurchaseClient.productID))
        entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .revoked)

        await client.setCurrentEntitlements([])
        await store.refresh()
        entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .free)
    }

    func testUnrelatedProductAndUnverifiedUpdateNeverUnlockOrRetainStalePro() async {
        let client = FakePurchaseClient(currentEntitlements: [
            .verified(.init(productID: "other.product", transactionID: 1, originalTransactionID: 1))
        ])
        let store = ProEntitlementStore(client: client)

        await store.refresh()
        var entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .free)

        await store.applyUpdate(.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 2,
            originalTransactionID: 2
        )))
        entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .pro)

        await store.applyUpdate(.unverified(productID: StoreKitPurchaseClient.productID))
        entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .unverified)
        XCTAssertNotEqual(entitlement, .pro)
    }

    func testRestoreSyncesThenRecomputesEntitlement() async {
        let client = FakePurchaseClient(currentEntitlements: [])
        let store = ProEntitlementStore(client: client)

        let result = await store.restore()

        XCTAssertEqual(result, .success)
        let syncCount = await client.syncCount
        XCTAssertEqual(syncCount, 1)
        let readCount = await client.currentEntitlementReadCount
        XCTAssertEqual(readCount, 1)
        let entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .free)
    }

    func testRestoreFailureIsVisibleAndFailClosed() async {
        let client = FakePurchaseClient(currentEntitlements: [], syncError: .storeUnavailable)
        let store = ProEntitlementStore(client: client)

        let result = await store.restore()

        XCTAssertEqual(result, .failure(.storeUnavailable))
        let entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .error)
        XCTAssertNotEqual(entitlement, .pro)
    }

    func testStaleRestoreFailureDoesNotOverwriteVerifiedUpdate() async {
        let client = SuspendedRestoreClient()
        let store = ProEntitlementStore(client: client)
        let started = await client.syncStartedStream()
        var startedIterator = started.makeAsyncIterator()

        let restore = Task { await store.restore() }
        _ = await startedIterator.next()
        await store.applyUpdate(.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 123,
            originalTransactionID: 123
        )))
        await client.release()

        let result = await restore.value
        XCTAssertEqual(result, .failure(.storeUnavailable))
        let entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .pro)
    }

    func testRestoreRefreshFailureIsReturnedAndFailClosed() async {
        let client = FakePurchaseClient(currentEntitlements: [], currentError: .storeUnavailable)
        let store = ProEntitlementStore(client: client)

        let result = await store.restore()

        XCTAssertEqual(result, .failure(.storeUnavailable))
        let entitlement = await store.entitlement
        XCTAssertEqual(entitlement, .error)
    }

    func testStateStreamBroadcastsEachTransitionToIndependentSubscribers() async {
        let client = FakePurchaseClient()
        let store = ProEntitlementStore(client: client)
        var first = await store.stateStream().makeAsyncIterator()
        var second = await store.stateStream().makeAsyncIterator()

        let firstInitial = await first.next()
        let secondInitial = await second.next()
        XCTAssertEqual(firstInitial, .loading)
        XCTAssertEqual(secondInitial, .loading)
        await store.applyUpdate(.verified(.init(
            productID: StoreKitPurchaseClient.productID,
            transactionID: 1,
            originalTransactionID: 1
        )))
        let firstUpdate = await first.next()
        let secondUpdate = await second.next()
        XCTAssertEqual(firstUpdate, .pro)
        XCTAssertEqual(secondUpdate, .pro)
    }

    func testStaleRefreshCannotOverwriteUnverifiedUpdateButFreshRefreshCanDowngrade() async {
        let client = SuspendedPurchaseClient()
        let store = ProEntitlementStore(client: client)
        let started = await client.refreshStartedStream()
        var startedIterator = started.makeAsyncIterator()
        let initialRefresh = Task { await store.refresh() }
        _ = await startedIterator.next()

        _ = await store.purchase()
        await client.release(.success([]))
        await initialRefresh.value
        let afterStaleEmpty = await store.entitlement
        XCTAssertEqual(afterStaleEmpty, .unverified)

        await client.setNextOutcome(.failure(.storeUnavailable))
        let staleErrorRefresh = Task { await store.refresh() }
        _ = await startedIterator.next()
        await store.applyUpdate(.unverified(productID: StoreKitPurchaseClient.productID))
        await client.release(.failure(.storeUnavailable))
        await staleErrorRefresh.value
        let afterStaleError = await store.entitlement
        XCTAssertEqual(afterStaleError, .unverified)

        await client.setNextOutcome(.success([]))
        let freshRefresh = Task { await store.refresh() }
        _ = await startedIterator.next()
        await client.release(.success([]))
        await freshRefresh.value
        let afterFreshEmpty = await store.entitlement
        XCTAssertEqual(afterFreshEmpty, .free)
    }
}

private actor FakePurchaseClient: StoreKitPurchaseClientProtocol {
    private var currentValues: [TransactionEvidence]
    private var purchaseValue: PurchaseResult
    private var currentError: PurchaseClientError?
    private var syncFailure: PurchaseClientError?
    private(set) var currentEntitlementReadCount = 0
    private(set) var syncCount = 0
    private let updates: AsyncStream<TransactionEvidence>
    private let updatesContinuation: AsyncStream<TransactionEvidence>.Continuation

    init(
        currentEntitlements: [TransactionEvidence] = [],
        purchaseResult: PurchaseResult = .cancelled,
        currentError: PurchaseClientError? = nil,
        syncError: PurchaseClientError? = nil
    ) {
        currentValues = currentEntitlements
        purchaseValue = purchaseResult
        self.currentError = currentError
        syncFailure = syncError
        (updates, updatesContinuation) = AsyncStream.makeStream(of: TransactionEvidence.self)
    }

    func product() async throws -> PurchaseProduct {
        PurchaseProduct(
            id: StoreKitPurchaseClient.productID,
            displayNameKorean: "마음자로 Pro",
            displayNameEnglish: "Maeumjaro Pro",
            displayPrice: "₩9,900",
            isNonConsumable: true
        )
    }

    func purchase() async -> PurchaseResult { purchaseValue }

    func currentEntitlements() async throws -> [TransactionEvidence] {
        currentEntitlementReadCount += 1
        if let currentError { throw currentError }
        return currentValues
    }

    nonisolated func transactionUpdates() -> AsyncStream<TransactionEvidence> { updates }

    func syncStore() async throws {
        syncCount += 1
        if let syncFailure { throw syncFailure }
    }

    func setPurchaseResult(_ value: PurchaseResult) { purchaseValue = value }

    func setCurrentEntitlements(_ value: [TransactionEvidence]) { currentValues = value }

    func sendUpdate(_ value: TransactionEvidence) {
        updatesContinuation.yield(value)
    }
}

private actor SuspendedPurchaseClient: StoreKitPurchaseClientProtocol {
    private var nextOutcome: Result<[TransactionEvidence], PurchaseClientError> = .success([])
    private let releaseContinuation: AsyncStream<Void>.Continuation
    private let releaseStream: AsyncStream<Void>
    private let startedContinuation: AsyncStream<Void>.Continuation
    private let startedStreamValue: AsyncStream<Void>

    init() {
        (releaseStream, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
        (startedStreamValue, startedContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    nonisolated func product() async throws -> PurchaseProduct {
        PurchaseProduct(id: StoreKitPurchaseClient.productID, displayNameKorean: "마음자로 Pro", displayNameEnglish: "Maeumjaro Pro", displayPrice: "₩9,900", isNonConsumable: true)
    }

    nonisolated func purchase() async -> PurchaseResult {
        .success(.unverified(productID: StoreKitPurchaseClient.productID))
    }

    func currentEntitlements() async throws -> [TransactionEvidence] {
        startedContinuation.yield()
        var iterator = releaseStream.makeAsyncIterator()
        _ = await iterator.next()
        return try nextOutcome.get()
    }

    nonisolated func transactionUpdates() -> AsyncStream<TransactionEvidence> {
        AsyncStream { continuation in continuation.finish() }
    }

    nonisolated func syncStore() async throws {}

    func refreshStartedStream() -> AsyncStream<Void> { startedStreamValue }

    func setNextOutcome(_ outcome: Result<[TransactionEvidence], PurchaseClientError>) {
        nextOutcome = outcome
    }

    func release(_ outcome: Result<[TransactionEvidence], PurchaseClientError>) {
        nextOutcome = outcome
        releaseContinuation.yield()
    }
}

private actor SuspendedRestoreClient: StoreKitPurchaseClientProtocol {
    private let releaseContinuation: AsyncStream<Void>.Continuation
    private let releaseStream: AsyncStream<Void>
    private let startedContinuation: AsyncStream<Void>.Continuation
    private let startedStreamValue: AsyncStream<Void>

    init() {
        (releaseStream, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
        (startedStreamValue, startedContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    nonisolated func product() async throws -> PurchaseProduct {
        PurchaseProduct(id: StoreKitPurchaseClient.productID, displayNameKorean: "마음자로 Pro", displayNameEnglish: "Maeumjaro Pro", displayPrice: "₩9,900", isNonConsumable: true)
    }

    nonisolated func purchase() async -> PurchaseResult {
        .cancelled
    }

    nonisolated func currentEntitlements() async throws -> [TransactionEvidence] {
        []
    }

    nonisolated func transactionUpdates() -> AsyncStream<TransactionEvidence> {
        AsyncStream { continuation in continuation.finish() }
    }

    func syncStore() async throws {
        startedContinuation.yield()
        var iterator = releaseStream.makeAsyncIterator()
        _ = await iterator.next()
        throw PurchaseClientError.storeUnavailable
    }

    func syncStartedStream() -> AsyncStream<Void> {
        startedStreamValue
    }

    func release() {
        releaseContinuation.yield()
    }
}
