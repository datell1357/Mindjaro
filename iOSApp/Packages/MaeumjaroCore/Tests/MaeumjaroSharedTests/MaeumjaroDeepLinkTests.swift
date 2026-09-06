import Foundation
import Testing

import MaeumjaroShared

@Test
func appAndWidgetInjectionLinksParseIntoTheirTypedSources() {
    let app = MaeumjaroDeepLink.parse(URL(string: "maeumjaro://inject?source=app")!)
    let widget = MaeumjaroDeepLink.parse(URL(string: "maeumjaro://inject?source=widget")!)

    #expect(app == .inject(source: .app))
    #expect(widget == .inject(source: .widget))
}

@Test
func anIntensityQueryIsIgnoredRatherThanUsedAsState() {
    let route = MaeumjaroDeepLink.parse(
        URL(string: "maeumjaro://inject?source=widget&intensity=1")!
    )

    #expect(route == .inject(source: .widget))
}

@Test(arguments: [
    "other://inject?source=app",
    "maeumjaro://other?source=app",
    "maeumjaro://inject?source=app&source=widget",
    "maeumjaro://inject?source=unknown",
    "maeumjaro://inject",
    "maeumjaro:///inject?source=app",
    "maeumjaro://inject/path?source=app"
])
func invalidOrAmbiguousInjectionLinksAreNoOp(urlString: String) {
    let route = MaeumjaroDeepLink.parse(URL(string: urlString)!)

    #expect(route == nil)
}

