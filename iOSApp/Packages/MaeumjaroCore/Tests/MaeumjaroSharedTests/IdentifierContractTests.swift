import Testing
import MaeumjaroShared

@Test
func identifiersAreSingleSourceOfTruthForAppAndWidgetEntry() {
    #expect(AppIdentifiers.appBundleID == "com.yeoreum.maeumjaro")
    #expect(AppIdentifiers.widgetBundleID == "com.yeoreum.maeumjaro.widget")
    #expect(AppIdentifiers.appGroupID == "group.com.yeoreum.maeumjaro")
    #expect(AppIdentifiers.proProductID == "com.yeoreum.maeumjaro.pro")
    #expect(AppIdentifiers.widgetKind == "MaeumjaroWidget")
    #expect(AppIdentifiers.urlScheme == "maeumjaro")
    #expect(AppIdentifiers.scheme == "Maeumjaro")
}
