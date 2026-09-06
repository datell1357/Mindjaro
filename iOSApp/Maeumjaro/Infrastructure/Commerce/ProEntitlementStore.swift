import Foundation
import MaeumjaroDomain

public actor ProEntitlementStore {
    public static let productID = StoreKitPurchaseClient.productID

    private let client: any StoreKitPurchaseClientProtocol
    private var subscribers: [UUID: AsyncStream<Entitlement>.Continuation] = [:]
    private var observerTask: Task<Void, Never>?
    private var entitlementRevision = 0

    public private(set) var entitlement: Entitlement = .loading

    public init(client: any StoreKitPurchaseClientProtocol) {
        self.client = client
    }

    deinit {
        observerTask?.cancel()
        for continuation in subscribers.values { continuation.finish() }
    }

    public func stateStream() -> AsyncStream<Entitlement> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { [weak self] in
                await self?.addSubscriber(id, continuation: continuation)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(id) }
            }
        }
    }

    @discardableResult
    public func start() -> Task<Void, Never> {
        if let observerTask { return observerTask }

        let client = self.client
        let task = Task { [weak self] in
            await self?.refresh()
            for await evidence in client.transactionUpdates() {
                guard !Task.isCancelled else { return }
                await self?.applyUpdate(evidence)
            }
        }
        observerTask = task
        return task
    }

    public func stop() {
        observerTask?.cancel()
        observerTask = nil
    }

    public func product() async throws -> PurchaseProduct {
        try await client.product()
    }

    public func refresh() async {
        _ = await refreshOutcome()
    }

    private func refreshOutcome() async -> PurchaseClientError? {
        let revisionAtStart = entitlementRevision
        do {
            let evidence = try await client.currentEntitlements()
            guard revisionAtStart == entitlementRevision else { return nil }
            setEntitlement(Self.entitlement(for: evidence))
            return nil
        } catch {
            guard revisionAtStart == entitlementRevision else { return nil }
            setEntitlement(.error)
            if let error = error as? PurchaseClientError { return error }
            return .storeUnavailable
        }
    }

    public func purchase() async -> PurchaseResult {
        let result = await client.purchase()
        switch result {
        case .success(let evidence):
            applyUpdate(evidence)
        case .cancelled:
            if entitlement != .pro { setEntitlement(.free) }
        case .pending:
            if entitlement != .pro { setEntitlement(.pending) }
        case .failed:
            if entitlement != .pro { setEntitlement(.error) }
        }
        return result
    }

    public func restore() async -> RestoreResult {
        let revisionAtStart = entitlementRevision
        do {
            try await client.syncStore()
            if let error = await refreshOutcome() {
                return .failure(error)
            }
            return .success
        } catch {
            let failure = (error as? PurchaseClientError) ?? .storeUnavailable
            if revisionAtStart == entitlementRevision {
                setEntitlement(.error)
            }
            return .failure(failure)
        }
    }

    public func applyUpdate(_ evidence: TransactionEvidence) {
        switch evidence {
        case .verified(let transaction):
            guard transaction.productID == Self.productID else { return }
            setEntitlement(.pro)
        case .unverified(let productID):
            guard productID == Self.productID else { return }
            setEntitlement(.unverified)
        case .revoked(let productID):
            guard productID == Self.productID else { return }
            setEntitlement(.revoked)
        }
    }

    private func setEntitlement(_ next: Entitlement) {
        entitlementRevision += 1
        guard entitlement != next else { return }
        entitlement = next
        for continuation in subscribers.values { continuation.yield(next) }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    private func addSubscriber(_ id: UUID, continuation: AsyncStream<Entitlement>.Continuation) {
        subscribers[id] = continuation
        continuation.yield(entitlement)
    }

    private static func entitlement(for evidence: [TransactionEvidence]) -> Entitlement {
        var next: Entitlement = .free
        for item in evidence {
            switch item {
            case .verified(let transaction) where transaction.productID == Self.productID:
                return .pro
            case .unverified(let productID) where productID == Self.productID:
                if next != .revoked { next = .unverified }
            case .revoked(let productID) where productID == Self.productID:
                next = .revoked
            case .verified, .unverified, .revoked:
                continue
            }
        }
        return next
    }
}
