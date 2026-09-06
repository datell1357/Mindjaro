# 마음자로 브랜드·개인정보 체크리스트

기준일: 2026-09-06

## 관찰된 archive 근거

- [x] App `PrivacyInfo.xcprivacy`: `NSPrivacyTracking=false`, collected data empty, UserDefaults reason `1C8F.1`
- [x] Widget `PrivacyInfo.xcprivacy`: 동일 값
- [x] Release app/widget executable fixture 문자열 scan: `MaeumjaroFixture`, `MAEUMJARO_QA_FIXTURES`, `qa.activeFixture`, `QAFixture`, `DebugFixture` 미검출
- [x] 사용자 제공 7개 PNG source↔iOS asset catalog SHA-256 7/7 일치: `.omo/evidence/ulw/maeumjaro-ios-simulator-20260905/G001-implement-approved-omo-plans-maeumja/a1/release-audit-deletion-fixed-20260906/asset-hashes.txt`

## 확인 대기

- [x] Simulator hosted UUID 격리 SwiftData 디렉터리에서 backup exclusion true 및 SQLite 존재 read-back. `PersistenceBackupTests` 1 PASS; `test_sim_2026-09-05T17-24-46-185Z_pid86149_24406432.xcresult`, 첨부 `a1/backup-readback-0224/A5FCC5BE-A422-47AA-A7D5-5E27868DE6D8.json`. 기존 production DB 자체의 속성을 조사한 증거 또는 실기기 백업 검증은 아니다.
- [ ] visible app/widget/store copy에서 의료 효능·치료·체중 감량 등 금지 주장 0
- [ ] independent asset provenance 및 공개 이름·상표 검토
- [x] `AppPrivacyDraft.md`에 로컬 기록/App Group/StoreKit/사용자 내보내기/삭제 경계를 소스 기준으로 대조. 공개 정책·App Store 제출·전이 SDK 최종 감사는 미완료.
- [ ] production asset 및 App Store 제출 자료 외부 승인

정적 archive와 좁은 범위의 Simulator 결과만으로 개인정보·브랜드 릴리스 승인을 주장하지 않는다. visible copy 및 privacy 대조는 로컬 수용 검증으로 남고, 공개 이름·상표·제출 승인은 별도 `releaseBlockers`로 유지한다.
