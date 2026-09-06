import MaeumjaroDomain
import Observation
import SwiftUI

@MainActor
@Observable
public final class ProPaywallViewModel {
    public private(set) var entitlement: Entitlement
    public private(set) var product: PurchaseProduct?
    public private(set) var status: String?
    public private(set) var isWorking = false
    private let store: ProEntitlementStore
    private let productLoader: @Sendable () async throws -> PurchaseProduct
    private var observationStarted = false

    public init(
        entitlement: Entitlement = .loading,
        store: ProEntitlementStore,
        productLoader: (@Sendable () async throws -> PurchaseProduct)? = nil
    ) {
        self.entitlement = entitlement
        self.store = store
        self.productLoader = productLoader ?? { try await store.product() }
    }

    public var isPro: Bool { FeatureAccessPolicy(entitlement: entitlement).isPro }
    public var canPurchase: Bool { product != nil && entitlement == .free && !isWorking }

    public func refresh() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await observeEntitlement()
        do {
            async let loadedProduct = productLoader()
            async let loadedEntitlement = store.entitlement
            product = try await loadedProduct
            entitlement = await loadedEntitlement
            status = nil
        } catch {
            entitlement = await store.entitlement
            status = String(localized: "스토어를 확인하지 못했어요.")
        }
    }

    private func observeEntitlement() async {
        guard !observationStarted else { return }
        observationStarted = true
        _ = await store.start()
        let stream = await store.stateStream()
        Task { [weak self] in
            for await state in stream {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.entitlement = state
            }
        }
    }

    public func purchase() async {
        guard canPurchase else { return }
        isWorking = true
        defer { isWorking = false }
        let result = await store.purchase()
        entitlement = await store.entitlement
        switch result {
        case .success where entitlement == .pro: status = String(localized: "Pro가 활성화됐어요.")
        case .success: status = String(localized: "구매를 확인하지 못했어요.")
        case .cancelled: status = String(localized: "구매를 취소했어요.")
        case .pending: status = String(localized: "구매 확인을 기다리고 있어요.")
        case .failed: status = String(localized: "구매를 완료하지 못했어요.")
        }
    }

    public func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let result = await store.restore()
        entitlement = await store.entitlement
        status = (result == .success && entitlement == .pro) ? String(localized: "구매를 복원했어요.") : String(localized: "복원할 Pro 구매를 확인하지 못했어요.")
    }
}

public struct ProPaywallView: View {
    @State private var model: ProPaywallViewModel

    public init(model: ProPaywallViewModel) { _model = State(initialValue: model) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("마음자로 Pro").font(.largeTitle.bold())
                Text("한 번의 구매로 52주 기록, 상세 분석, CSV·JSON 내보내기, 추가 테마를 사용할 수 있어요.")
                if let product = model.product { Text(product.displayPrice).font(.title2.bold()) }
                Button("구매하기") { Task { await model.purchase() } }
                    .buttonStyle(.borderedProminent).disabled(!model.canPurchase)
                Button("구매 복원") { Task { await model.restore() } }.buttonStyle(.bordered)
                if let status = model.status { Text(status).font(.subheadline) }
            }.padding()
        }
        .navigationTitle("Pro")
        .task { await model.refresh() }
    }
}
