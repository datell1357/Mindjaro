import Testing
import Foundation
@testable import MaeumjaroIntents

@Test
func intentMetadataIsPresentInPackageCatalog() {
    let expected = [
        "intent.title": "강도 변경",
        "intent.description": "마음자로 위젯의 현재 강도를 변경합니다.",
        "intent.parameter.target": "목표 강도",
        "intent.parameter.delta": "강도 변경량"
    ]
    for (key, value) in expected {
        #expect(Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: "Localizable") == value)
    }
    #expect(String(localized: SetStrengthIntent.title) == "강도 변경")
}

@Test
func intentErrorsKeepSafeKoreanUserFacingText() {
    #expect(SetStrengthIntentError.invalidParameters.localizedDescription == "강도 하나를 지정하거나 한 단계만 변경해 주세요.")
    #expect(SetStrengthIntentError.invalidTarget(6).localizedDescription == "강도는 1에서 5 사이여야 합니다. 입력값: 6")
}
