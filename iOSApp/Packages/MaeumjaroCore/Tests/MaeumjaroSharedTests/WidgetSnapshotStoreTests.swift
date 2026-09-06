import Foundation
import Testing

import MaeumjaroDomain
import MaeumjaroShared

private func makeWidgetDefaults() -> AppGroupDefaults {
    AppGroupDefaults(storage: MemoryDataStore())
}

@Test
func staleTodaySummaryReturnsZeroValuesWithoutMutatingItsBlob() throws {
    let defaults = makeWidgetDefaults()
    let store = TodaySummaryStore(defaults: defaults)
    let snapshot = TodaySummarySnapshot(
        localDate: "2026-09-04",
        completionCount: 3,
        intensitySum: 11,
        writer: .app,
        updatedAt: Date(timeIntervalSince1970: 1_757_000_000),
        revision: 1
    )
    try store.write(snapshot)
    let originalBytes = defaults.data(forKey: AppGroupDefaults.Keys.todaySummary)

    let stale = store.read(forLocalDate: "2026-09-05")

    #expect(stale.localDate == "2026-09-05")
    #expect(stale.completionCount == 0)
    #expect(stale.intensitySum == 0)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.todaySummary) == originalBytes)
}

@Test
func currentTodaySummaryKeepsItsCountAndSum() throws {
    let defaults = makeWidgetDefaults()
    let store = TodaySummaryStore(defaults: defaults)
    let snapshot = TodaySummarySnapshot(
        localDate: "2026-09-05",
        completionCount: 2,
        intensitySum: 7,
        writer: .app,
        updatedAt: Date(timeIntervalSince1970: 1_757_000_000),
        revision: 1
    )
    try store.write(snapshot)

    let current = store.read(forLocalDate: "2026-09-05")

    #expect(current == snapshot)
}

@Test
func corruptTodaySummaryFallsBackToZeroAndPreservesItsBytes() throws {
    let defaults = makeWidgetDefaults()
    let corrupt = Data([0x00, 0x01, 0x02])
    try defaults.set(corrupt, forKey: AppGroupDefaults.Keys.todaySummary)
    let store = TodaySummaryStore(defaults: defaults)

    let value = store.read(forLocalDate: "2026-09-05")

    #expect(value.completionCount == 0)
    #expect(value.intensitySum == 0)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.todaySummary) == corrupt)
}

@Test
func unknownThemeSchemaFallsBackToQuietIvoryAndPreservesItsBytes() throws {
    let defaults = makeWidgetDefaults()
    let unknown = try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 7,
        "updatedAt": "2026-09-05T00:00:00Z",
        "writer": "app",
        "revision": 2,
        "themeID": "midnightInk"
    ])
    try defaults.set(unknown, forKey: AppGroupDefaults.Keys.widgetTheme)
    let store = WidgetThemeStore(defaults: defaults)

    #expect(store.read() == .default)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.widgetTheme) == unknown)
}

@Test
func themeSnapshotRoundTripsWithAnIndependentKey() throws {
    let defaults = makeWidgetDefaults()
    let store = WidgetThemeStore(defaults: defaults)
    let snapshot = WidgetThemeSnapshot(
        themeID: .forestMist,
        writer: .app,
        updatedAt: Date(timeIntervalSince1970: 1_757_000_000),
        revision: 1
    )

    try store.write(snapshot)

    #expect(store.read() == .forestMist)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.todaySummary) == nil)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.widgetTheme) != nil)
}

