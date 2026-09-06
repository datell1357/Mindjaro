# Android 출시 소유자·외부 게이트

이 체크리스트는 내부 준비 상태와 외부 승인 상태를 분리한다. 체크하지 않은 항목이 하나라도 있으면 `release ready`, 제출, 승인으로 표현하지 않는다.

## 현재 내부 확인

- [x] 임시 namespace/applicationId는 `com.maeumjaro.app`로 소스에 존재한다.
- [x] 현재 버전은 `versionCode 1`, `versionName 0.1.0`이다.
- [x] 현재 빌드 설정은 비서명 debug와 비서명 release를 허용한다.
- [x] 앱 소스 매니페스트에 `INTERNET`, 위치, 카메라, 마이크 권한을 직접 선언하지 않는다. 최종 병합 매니페스트는 전이 의존성까지 별도 확인한다.
- [x] 백업 규칙에서 Room/DataStore 기록과 export cache 제외 설정을 확인했다.
- [x] 스토어 문안과 면책문구 초안을 작성했다.
- [ ] 최종 release AAB의 병합 매니페스트와 전이 의존성을 검사해 `INTERNET`·Billing 관련 권한/SDK 및 네트워크 경로를 개인정보처리방침·Data Safety 선언과 대조한다.

## 소유자 승인 필요

- [ ] 최종 브랜드명과 `마음자로` 상표·유사 상표 검토
- [ ] 최종 applicationId 및 패키지 소유권 승인
- [ ] 독립 아이콘·위젯·ritual 에셋의 최종 브랜드/법무 승인
- [ ] 지원 이메일·운영 주체·문의 주소 확정
- [ ] 비의료 문구와 스토어 카테고리 최종 승인
- [ ] 가격·통화·환불 문구를 포함한 Pro 상품 카피 승인

## 외부 시스템 게이트

- [ ] 공개 접근 가능한 개인정보처리방침 URL 게시 및 접속 확인
- [ ] Google Play Console 앱 생성 및 최종 package ID 연결
- [ ] Play App Signing 소유자와 키 관리 방식 확정
- [ ] `pro_lifetime` 최종 상품 ID·가격·판매 가능 상태 확정
- [ ] license tester 계정과 내부/비공개 테스트 track 확정
- [ ] 실제 기기 QA 및 접근성 QA 수락
- [ ] release-derived 설치, Billing 복원, 내보내기, 삭제 시나리오 수락
- [ ] Data Safety·Health Apps·Content rating 선언 제출 및 결과 확인
- [ ] Play 업로드·게시의 명시적 소유자 승인

## 금지 사항

이 작업에서 keystore, 비밀번호, 구매 토큰, Play 영수증을 만들거나 저장하지 않는다. 로컬 AAB가 생겨도 Play에 업로드되었거나 심사·승인된 것으로 간주하지 않는다.
