import Testing
import MaeumjaroIntents

@Test
func intentErrorsKeepSafeKoreanUserFacingText() {
    #expect(SetStrengthIntentError.invalidParameters.localizedDescription == "강도 하나를 지정하거나 한 단계만 변경해 주세요.")
    #expect(SetStrengthIntentError.invalidTarget(6).localizedDescription == "강도는 1에서 5 사이여야 합니다. 입력값: 6")
}
