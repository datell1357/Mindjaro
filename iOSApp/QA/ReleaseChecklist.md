# 마음자로 iOS 릴리스 체크리스트

기준일: 2026-09-06  
범위: 로컬 구현 검증과 외부 릴리스 검증을 분리한다.

## 관찰된 로컬 근거

- [x] 최신 데이터 관리 수정 포함 unsigned Release archive exit 0 및 privacy/fixture/7 PNG 검사 PASS: `.omo/evidence/ulw/maeumjaro-ios-simulator-20260905/G001-implement-approved-omo-plans-maeumja/a1/release-audit-data-layout-20260906/audit-summary.md`
- [x] 03:23 Core 94 PASS, 03:30 전체 85건 중 83 PASS/StoreKit 2 FAIL/skip 0, UI 20/20 PASS. 전체 성공 아님. `.omo/start-work/ios-full-regression-20260906-0324.md`
- [x] 02:01 Core package 94건 PASS 재확인. 02:08 전체 테스트 78건 중 76 PASS / StoreKit 2 FAIL / skip 0, UI 14건 PASS: `test_sim_2026-09-05T17-00-49-960Z_pid86149_d3a78422.xcresult`. 전체 성공을 뜻하지 않는다.
- [ ] Simulator 전체 수동 매트릭스 — 이 문서에서 완료 주장하지 않음
- [x] Simulator UUID 격리 SwiftData 디렉터리 backup exclusion read-back — 별도 hosted test 1 PASS, `test_sim_2026-09-05T17-24-46-185Z_pid86149_24406432.xcresult`. 기존 production DB 전체/실기기 백업 검증은 아님.
- [ ] StoreKit 직접 비교 — 6건 중 4 PASS, 2 FAIL(notEntitled), 상세: `.omo/start-work/storekit-direct-comparison-20260906.md`

## 릴리스 차단 게이트

- [ ] Apple Developer Team/서명 프로파일
- [ ] 실기기 Voice Control, Switch Control, haptic feel/schedule, airplane mode, frame pacing
- [ ] widget reboot/cold launch/multi-widget
- [ ] StoreKit sandbox purchase/restore
- [ ] App Store Connect 상품, 지원 URL, 개인정보 URL
- [ ] 공개 이름·상표 및 최종 production asset 승인

`releaseVerdict=PASS`는 위 미관찰 게이트가 모두 확인될 때까지 출력하지 않는다. 이 체크리스트는 전체 제품 완료 또는 제출 승인을 의미하지 않는다.
