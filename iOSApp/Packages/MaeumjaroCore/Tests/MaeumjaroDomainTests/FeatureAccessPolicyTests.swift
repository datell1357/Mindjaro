import Testing

import MaeumjaroDomain

@Test
func freePolicyShowsOnlyThirtyTodayInclusiveLocalDates() throws {
    let policy = FeatureAccessPolicy(entitlement: .free)
    let window = try #require(policy.historyWindow(today: "2026-09-05"))

    #expect(window.plan == .free)
    #expect(window.startDate == "2026-08-07")
    #expect(window.endDate == "2026-09-05")
    #expect(window.dates.count == 30)
    #expect(policy.canAccess(.todaySummary))
    #expect(policy.canAccess(.basicHistory))
    #expect(policy.canAccess(.heatmap))
    #expect(!policy.canAccess(.detailedPatterns))
    #expect(!policy.canAccess(.comparison))
    #expect(!policy.canAccess(.csvExport))
    #expect(!policy.canAccess(.jsonExport))
    #expect(!policy.canAccess(.themes))
}

@Test
func verifiedProPolicyShowsCurrentMondayInclusiveFiftyTwoWeeksAndSixteenWeekViewport() throws {
    let policy = FeatureAccessPolicy(entitlement: .pro)
    let window = try #require(policy.historyWindow(today: "2026-09-05"))

    #expect(window.plan == .pro)
    #expect(window.startDate == "2025-09-08")
    #expect(window.endDate == "2026-09-06")
    #expect(window.dates.count == 364)
    #expect(window.viewportStartDate == "2026-05-18")
    #expect(window.viewportEndDate == "2026-09-06")
    #expect(policy.canAccess(.heatmap))
    #expect(policy.canAccess(.detailedPatterns))
    #expect(policy.canAccess(.comparison))
    #expect(policy.canAccess(.csvExport))
    #expect(policy.canAccess(.jsonExport))
    #expect(policy.canAccess(.themes))
}

@Test
func nonVerifiedEntitlementsFailClosedWithoutChangingHistoryWindowData() throws {
    for entitlement in [Entitlement.pending, .loading, .error, .unverified, .revoked] {
        let policy = FeatureAccessPolicy(entitlement: entitlement)
        let window = try #require(policy.historyWindow(today: "2026-09-05"))

        #expect(window.plan == .free)
        #expect(window.dates.count == 30)
        #expect(!policy.canAccess(.heatmap))
        #expect(!policy.canAccess(.csvExport))
        #expect(!policy.canAccess(.jsonExport))
    }
}

@Test
func malformedReferenceDatesAreRejectedAndFutureRowsCannotEnterVisibleWindow() {
    #expect(HistoryWindow.free(today: "2026-02-30") == nil)
    #expect(HistoryWindow.pro(today: "not-a-date") == nil)

    let policy = FeatureAccessPolicy(entitlement: .pro)
    let window = policy.historyWindow(today: "2026-09-05")
    #expect(window?.contains("2026-09-06") == false)
    #expect(window?.contains("2025-09-07") == false)
}

@Test
func freeAndProPolicyNeverDeleteOrRewriteRetainedRows() {
    let events = ["2025-01-01", "2026-08-07", "2026-09-05"]
    let freeVisible = events.filter { FeatureAccessPolicy(entitlement: .free).historyWindow(today: "2026-09-05")?.contains($0) == true }
    let proVisible = events.filter { FeatureAccessPolicy(entitlement: .pro).historyWindow(today: "2026-09-05")?.contains($0) == true }

    #expect(events == ["2025-01-01", "2026-08-07", "2026-09-05"])
    #expect(freeVisible == ["2026-08-07", "2026-09-05"])
    #expect(proVisible == ["2026-08-07", "2026-09-05"])
}
