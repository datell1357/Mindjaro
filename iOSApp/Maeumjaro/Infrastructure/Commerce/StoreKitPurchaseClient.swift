import Foundation
import MaeumjaroDomain
import MaeumjaroShared
import StoreKit

public struct PurchaseProduct: Equatable, Sendable {
    public let id: String
    public let displayNameKorean: String
    public let displayNameEnglish: String
    public let displayPrice: String
    public let isNonConsumable: Bool

    public init(
        id: String,
        displayNameKorean: String,
        displayNameEnglish: String,
        displayPrice: String,
        isNonConsumable: Bool
    ) {
        self.id = id
        self.displayNameKorean = displayNameKorean
        self.displayNameEnglish = displayNameEnglish
        self.displayPrice = displayPrice
        self.isNonConsumable = isNonConsumable
    }
}

public struct VerifiedTransactionEvidence: Equatable, Hashable, Sendable {
    public let productID: String
    public let transactionID: UInt64
    public let originalTransactionID: UInt64

    public init(productID: String, transactionID: UInt64, originalTransactionID: UInt64) {
        self.productID = productID
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
    }
}

public enum TransactionEvidence: Equatable, Sendable {
    case verified(VerifiedTransactionEvidence)
    case unverified(productID: String)
    case revoked(productID: String)
}

public enum PurchaseClientError: Error, Equatable, Sendable {
    case productUnavailable
    case productTypeMismatch
    case storeUnavailable
    case transactionUnverified
}

public enum PurchaseResult: Equatable, Sendable {
    case success(TransactionEvidence)
    case cancelled
    case pending
    case failed(PurchaseClientError)
}

public enum RestoreResult: Equatable, Sendable {
    case success
    case failure(PurchaseClientError)
}

public protocol StoreKitPurchaseClientProtocol: Sendable {
    func product() async throws -> PurchaseProduct
    func purchase() async -> PurchaseResult
    func currentEntitlements() async throws -> [TransactionEvidence]
    func transactionUpdates() -> AsyncStream<TransactionEvidence>
    func syncStore() async throws
}

public struct StoreKitPurchaseClient: StoreKitPurchaseClientProtocol, Sendable {
    public static let productID = AppIdentifiers.proProductID

    public init() {}

    public func product() async throws -> PurchaseProduct {
        let products: [Product]
        do {
            products = try await Product.products(for: [Self.productID])
        } catch {
            throw PurchaseClientError.storeUnavailable
        }

        guard let product = products.first(where: { $0.id == Self.productID }) else {
            throw PurchaseClientError.productUnavailable
        }
        guard product.type == .nonConsumable else {
            throw PurchaseClientError.productTypeMismatch
        }
        return PurchaseProduct(
            id: product.id,
            displayNameKorean: product.displayName,
            displayNameEnglish: product.displayName,
            displayPrice: product.displayPrice,
            isNonConsumable: product.type == .nonConsumable
        )
    }

    public func purchase() async -> PurchaseResult {
        let product: Product
        do {
            let products = try await Product.products(for: [Self.productID])
            guard let resolved = products.first(where: { $0.id == Self.productID }) else {
                return .failed(.productUnavailable)
            }
            guard resolved.type == .nonConsumable else {
                return .failed(.productTypeMismatch)
            }
            product = resolved
        } catch {
            return .failed(.storeUnavailable)
        }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    let evidence = Self.evidence(for: verification)
                    await transaction.finish()
                    return .success(evidence)
                case .unverified(let transaction, _):
                    return .success(.unverified(productID: transaction.productID))
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(.storeUnavailable)
            }
        } catch {
            return .failed(.storeUnavailable)
        }
    }

    public func currentEntitlements() async throws -> [TransactionEvidence] {
        var evidence: [TransactionEvidence] = []
        for await verification in Transaction.currentEntitlements {
            evidence.append(Self.evidence(for: verification))
        }
        return evidence
    }

    public func transactionUpdates() -> AsyncStream<TransactionEvidence> {
        AsyncStream { continuation in
            let observer = Task {
                for await verification in Transaction.updates {
                    switch verification {
                    case .verified(let transaction):
                        continuation.yield(Self.evidence(for: verification))
                        await transaction.finish()
                    case .unverified:
                        continuation.yield(Self.evidence(for: verification))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in observer.cancel() }
        }
    }

    public func syncStore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw PurchaseClientError.storeUnavailable
        }
    }

    private static func evidence(for verification: VerificationResult<Transaction>) -> TransactionEvidence {
        switch verification {
        case .verified(let transaction):
            if transaction.revocationDate != nil {
                return .revoked(productID: transaction.productID)
            }
            return .verified(VerifiedTransactionEvidence(
                productID: transaction.productID,
                transactionID: transaction.id,
                originalTransactionID: transaction.originalID
            ))
        case .unverified(let transaction, _):
            return .unverified(productID: transaction.productID)
        }
    }
}
