import MaeumjaroDomain
import Observation
import SwiftUI

@MainActor
@Observable
public final class DataManagementViewModel {
    public private(set) var events: [InjectionEvent]
    public private(set) var exportMessage: String?
    public private(set) var settingsMessage: String?
    public private(set) var isDeleteConfirmationPresented = false
    public private(set) var selectedTheme: ThemeID

    private let eventRepository: any EventRepository
    private let settingsRepository: any SettingsRepository
    private let exporter: HistoryExporter
    private var entitlement: Entitlement
    private let currentEntitlement: @Sendable () async -> Entitlement
    private let onWidgetThemeChange: @Sendable (ThemeID) async throws -> Void
    private let onEventsDeleted: @Sendable () async throws -> Void
    // The dialog dismisses synchronously when its destructive action is tapped.
    // Keep the explicit confirmation separate from the presentation binding so
    // that the async deletion cannot be mistaken for an unconfirmed request.
    private var deleteConfirmationAccepted = false

    public init(
        events: [InjectionEvent] = [],
        settings: AppSettings,
        entitlement: Entitlement,
        eventRepository: any EventRepository,
        settingsRepository: any SettingsRepository,
        exporter: HistoryExporter = HistoryExporter(),
        onWidgetThemeChange: @escaping @Sendable (ThemeID) async throws -> Void = { _ in },
        onEventsDeleted: @escaping @Sendable () async throws -> Void = {},
        currentEntitlement: @escaping @Sendable () async -> Entitlement = { .free }
    ) {
        self.events = events
        selectedTheme = settings.themeID
        self.entitlement = entitlement
        self.eventRepository = eventRepository
        self.settingsRepository = settingsRepository
        self.exporter = exporter
        self.onWidgetThemeChange = onWidgetThemeChange
        self.onEventsDeleted = onEventsDeleted
        self.currentEntitlement = currentEntitlement
    }

    public var policy: FeatureAccessPolicy { FeatureAccessPolicy(entitlement: entitlement) }
    public var canExport: Bool { policy.canAccess(.csvExport) }
    public var availableThemes: [ThemeID] { [.quietIvory] + (policy.canAccess(.themes) ? [.midnightInk, .forestMist] : []) }

    public func refresh() async {
        entitlement = await currentEntitlement()
        do {
            events = try await eventRepository.fetchAll()
            let settings = try await settingsRepository.load()
            let nextTheme = policy.canAccess(.themes) ? settings.themeID : .quietIvory
            selectedTheme = nextTheme
            settingsMessage = nil
            if nextTheme != settings.themeID {
                var downgraded = settings
                downgraded.themeID = .quietIvory
                try await settingsRepository.save(downgraded)
                do {
                    try await onWidgetThemeChange(.quietIvory)
                } catch {
                    settingsMessage = String(localized: "Pro 상태는 갱신됐지만 위젯을 아직 갱신하지 못했어요.")
                }
            }
        } catch {
            settingsMessage = String(localized: "데이터를 불러오지 못했어요. 다시 시도해 주세요.")
        }
    }

    public func export(format: ExportDocument.Format) async -> ExportDocument? {
        entitlement = await currentEntitlement()
        guard format == .csv ? policy.canAccess(.csvExport) : policy.canAccess(.jsonExport) else {
            exportMessage = String(localized: "Pro에서만 내보낼 수 있어요.")
            return nil
        }
        guard let document = exporter.export(events, format: format) else {
            exportMessage = String(localized: "내보낼 기록이 아직 없어요.")
            return nil
        }
        exportMessage = nil
        return document
    }

    public func presentDeleteConfirmation() {
        deleteConfirmationAccepted = false
        isDeleteConfirmationPresented = true
    }

    public func cancelDelete() {
        isDeleteConfirmationPresented = false
        // SwiftUI also calls the binding setter when the destructive action
        // dismisses the dialog. Preserve that already-consumed confirmation.
    }

    /// Consumes the currently presented confirmation synchronously, before the
    /// view launches the asynchronous repository operation.
    @discardableResult
    public func acceptDeleteConfirmation() -> Bool {
        guard isDeleteConfirmationPresented else { return false }
        deleteConfirmationAccepted = true
        isDeleteConfirmationPresented = false
        return true
    }

    public func confirmDeleteAll() async {
        guard deleteConfirmationAccepted else { return }
        deleteConfirmationAccepted = false
        exportMessage = nil
        do {
            try await eventRepository.deleteAll()
            events = []
            exportMessage = String(localized: "모든 기록을 삭제했어요.")
            do {
                try await onEventsDeleted()
            } catch {
                exportMessage = String(localized: "기록은 삭제됐지만 위젯을 아직 갱신하지 못했어요.")
            }
        } catch {
            exportMessage = String(localized: "기록을 삭제하지 못했어요. 다시 시도해 주세요.")
        }
    }

    public func selectTheme(_ theme: ThemeID) async {
        entitlement = await currentEntitlement()
        let previous = selectedTheme
        let next = availableThemes.contains(theme) ? theme : .quietIvory
        selectedTheme = next
        do {
            var settings = try await settingsRepository.load()
            settings.themeID = next
            try await settingsRepository.save(settings)
            do {
                try await onWidgetThemeChange(next)
            } catch {
                settingsMessage = String(localized: "테마는 저장됐지만 위젯을 아직 갱신하지 못했어요.")
            }
        } catch {
            selectedTheme = previous
            settingsMessage = String(localized: "테마를 저장하지 못했어요. 이전 테마를 유지합니다.")
        }
    }
}

public struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: DataManagementViewModel
    @State private var selectedFormat: ExportDocument.Format = .csv
    @State private var shareDocument: ExportDocument?

    public init(model: DataManagementViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            dataSection("데이터 내보내기") {
                Picker("형식", selection: $selectedFormat) {
                    Text("CSV").tag(ExportDocument.Format.csv)
                    Text("JSON").tag(ExportDocument.Format.json)
                }
                .pickerStyle(.menu)
                Button("내보내기") {
                    Task { shareDocument = await model.export(format: selectedFormat) }
                }.disabled(!model.canExport)
                    .frame(minHeight: 44)
                if let message = model.exportMessage { Text(message).foregroundStyle(.secondary) }
            }
            dataSection("테마") {
                ForEach(model.availableThemes, id: \.self) { theme in
                    Button { Task { await model.selectTheme(theme) } } label: {
                        HStack {
                            Text(LocalizedStringKey(theme.displayName))
                            Spacer()
                            if model.selectedTheme == theme {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                        .accessibilityAddTraits(model.selectedTheme == theme ? .isSelected : [])
                }
            }
            dataSection("기록 삭제") {
                Button("모든 기록 삭제", role: .destructive) { model.presentDeleteConfirmation() }
                    .frame(minHeight: 44)
                Text("설정, 문구, Pro 상태는 유지됩니다.").font(.footnote).foregroundStyle(.secondary)
            }
            if let message = model.settingsMessage { Text(message).foregroundStyle(.secondary) }
          }
          .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("데이터 관리")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: {
                    Text("닫기")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44)
                }
                    .accessibilityIdentifier("data-management-close")
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .task { await model.refresh() }
        .sheet(item: $shareDocument) { document in
            NavigationStack {
                ShareLink(item: document, preview: SharePreview(document.filename)) {
                    Label("공유", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("export-share")
                .padding()
                .navigationTitle("기록 내보내기")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { shareDocument = nil }
                            .accessibilityIdentifier("export-close")
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "모든 기록을 삭제할까요?",
            isPresented: Binding(
                get: { model.isDeleteConfirmationPresented },
                set: { if !$0 { model.cancelDelete() } }
            )
        ) {
            Button("삭제", role: .destructive) {
                guard model.acceptDeleteConfirmation() else { return }
                Task { await model.confirmDeleteAll() }
            }
            Button("취소", role: .cancel) { model.cancelDelete() }
        } message: {
            Text("삭제한 기록은 되돌릴 수 없어요.")
        }
    }

    private func dataSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 12, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private extension ThemeID {
    var displayName: String {
        switch self {
        case .quietIvory: "Quiet Ivory"
        case .midnightInk: "Midnight Ink"
        case .forestMist: "Forest Mist"
        }
    }
}
