# Analytics integration requirements

이 모듈은 Pro 권한이 확인된 뒤에만 `DetailedPatterns.execute()`와 `JsonExport.execute()`를 호출해야 한다. `AccessResult.Locked`는 UI에서 잠금 안내만 표시하고 저장소를 읽거나 파일을 만들지 않는다.

## App/Navigation

- `HistoryController`의 `EntitlementRepository`와 동일한 인스턴스를 analytics use case에 주입한다.
- Pro 화면 진입 전 권한을 확인하고, 화면에는 `AnalyticsReport`만 전달한다. 무료 화면은 기존 30일 목록·16주 히트맵 계약을 유지한다.
- `ProAnalyticsScreen`의 `onExportJson`에서 `JsonExport`를 호출하고, `Unlocked.value.asSharePayload()`의 bytes를 앱 캐시에 명시적으로 기록한 뒤 `application/json` FileProvider Sharesheet를 연다.
- `JsonExportResult` 자체는 파일을 만들거나 공유 대상을 선택하지 않는다. 취소·실패 시 원본 Room 기록은 변경하지 않는다.

## Data and copy

- 시간대는 저장된 `eventLocalDate`와 저장된 offset으로 계산한다. 기록 수, 활동 일수, 분포, 기간 비교 외의 의미를 추론하지 않는다.
- `SampleTier` 문구는 `기록이 더 필요해요`, 예비 사실, 분포, 4주 비교 순서만 사용한다. 의료·효능·성공·위험·식욕·체중 표현은 추가하지 않는다.
- JSON은 모든 로컬 완료 이벤트를 시간순으로 내보내며 phrase text는 포함하지 않고 `phraseID`만 포함한다.
