# App Privacy 대조 초안

2026-09-06. 현재 iOS 소스의 데이터 흐름을 설명하는 개발용 초안이다. App Store Connect에 입력하거나 공개한 개인정보처리방침이 아니며 법률·제출 승인을 뜻하지 않는다.

| 데이터/동작 | 현재 구현의 경계 | 근거 |
| --- | --- | --- |
| 완료 기록 | SwiftData 로컬 저장. 완료 시각·현지 날짜·시간대·강도·진입 출처·문구 ID·기간·중단 횟수·버전을 저장하며 미완료는 저장하지 않는 계약 | `Packages/MaeumjaroCore/Sources/MaeumjaroPersistence/Schema/MaeumjaroSchemaV1.swift`, `Store/ModelContainerFactory.swift` |
| 백업/동기화 | ModelConfiguration의 cloudKitDatabase는 none. 저장 디렉터리를 백업 제외로 설정하고 read-back 실패를 오류 처리 | `ModelContainerFactory.makePersistent` |
| 위젯 공유 | 앱과 위젯이 App Group UserDefaults로 강도, 오늘 요약, 테마를 공유. 개발자 서버 전송을 위한 저장소가 아님 | `Packages/MaeumjaroCore/Sources/MaeumjaroShared/Storage`, `Strength`, `Widget` |
| 구매/복원 | StoreKit Product/Transaction/AppStore API 사용. 검증된 거래로 Pro 접근을 결정. 의식 기록을 StoreKit API에 전달하는 구현은 없음 | `Maeumjaro/Infrastructure/Commerce/StoreKitPurchaseClient.swift` |
| 사용자 내보내기 | Pro 사용자가 CSV/JSON을 생성하고 시스템 공유 화면으로 선택 전달. 완료 UTC·현지 날짜·시간대·강도·출처·문구 ID가 포함됨. 공유 후 수신 앱/사용자 복사본은 본 앱의 삭제 범위가 아님 | `Maeumjaro/Infrastructure/Export/HistoryExporter.swift`, `Features/Settings/DataManagementView.swift` |
| 삭제 | 확인 후 로컬 기록 삭제 및 위젯 요약 재계산. 설정과 Pro 구매 이력 삭제 또는 Apple 거래 환불이 아님 | `DataManagementViewModel.confirmDeleteAll`, `Packages/MaeumjaroCore/Sources/MaeumjaroPersistence/Maintenance/EventDeletionService.swift` |

## 매니페스트 대조

앱과 위젯의 `PrivacyInfo.xcprivacy` 모두 tracking=false, collected data 배열 비어 있음, UserDefaults required-reason `1C8F.1`을 선언한다. 이는 현재 선언값이며 Apple 승인 또는 모든 required-reason API에 대한 최종 독립 감사가 아니다.

제품 소스(`Maeumjaro`, `MaeumjaroWidget`, Core package Sources)에서 `URLSession`, `import Network`, `NWConnection`, `CKContainer`, `HealthKit`, `HKHealth`, `AVCapture`, `requestAuthorization` 검색 일치 0을 관찰했다. 이 좁은 문자열 검사는 네트워크 packet capture·SDK 전이 의존성 전수감사나 StoreKit 통신 부재의 증명이 아니다. Apple 구매 서비스와 사용자가 선택한 공유 대상의 데이터 처리는 개발자 서버 수집과 분리한다.

## 실제 검증과 남은 항목

- Simulator hosted UUID 격리 저장소에서 SQLite 존재 및 fresh URL backup exclusion true: `test_sim_2026-09-05T17-24-46-185Z_pid86149_24406432.xcresult`. 기존 production DB/실기기 백업 동작의 전수 검증은 아님.
- 기존 UI 테스트에서 CSV/JSON 공유 취소를 확인했으며 외부 수신자에게 전송한 증거는 없음.
- 실제 StoreKit local 거래 테스트 2건은 notEntitled 실패 상태. 데이터 경계의 소스 설명을 구매 성공 증거로 사용하지 않음.
- 공개 정책 URL, 지원 연락처, 최종 App Store Connect 답변, 전이 SDK/required-reason 최종 감사, 서명된 실기기 검증은 미완료.
- 공개 문구에서 '모든 데이터는 절대로 기기 밖으로 나가지 않는다'고 표현하지 않는다. 사용자 내보내기와 Apple StoreKit 처리를 제외하지 못하는 절대적 주장이다.
