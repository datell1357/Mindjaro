import Testing
import MaeumjaroPersistence

@Test
func persistenceErrorsKeepKoreanUserFacingText() {
    #expect(PersistenceError.catalogUnavailable.localizedDescription == "문구 카탈로그를 사용할 수 없습니다.")
    #expect(PersistenceError.deletionScopeEmpty.localizedDescription == "삭제 범위가 비어 있습니다.")
}
