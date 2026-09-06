# 마음자로 iOS 접근성 체크리스트

기준일: 2026-09-06  
원칙: 정적 label 존재와 실제 시스템 순회는 별도 게이트다.

## 수동 검증 매트릭스

- [ ] VoiceOver 실제 focus 순서: `강도 조절` → `의식 시작` → hold region → 기록 날짜 → 삭제 확인
- [ ] 각 control의 label/value/hint 및 activate 동작
- [ ] 최대 Dynamic Type에서 clipping·가려진 CTA 0
- [ ] Reduce Motion에서 완료 상태 즉시 전환 및 장식 모션 제거
- [ ] Increase Contrast
- [ ] Differentiate Without Color: 강도·상태를 숫자/기호/텍스트로 구분
- [ ] Light/Dark
- [ ] 최소 44pt target
- [ ] 권한 prompt 없음
- [ ] signed device Voice Control 번호 보기 및 Switch Control 자동 스캔

## 현재 상태

05:09 상태 정정: 아래 03:53의 링 settle·meniscus 누락은 수정 전 이력이다. `.omo/start-work/ios-motion-repair-20260906-0400.md`에 구현과 scoped 테스트 증거가 있으며, 04:56에는 QA 표식을 cold 화면에만 제한한 뒤 기본/최대 글자 크기 UI 및 cold/hosted 결합12건이 통과했다. 실제 시스템 Reduce Motion·VoiceOver·색상 구별 전체 행을 이 결과로 체크하지 않는다. 최신 근거 `.omo/start-work/ios-cold-widget-completion-20260906-0446.md`.

03:53 완료 화면 추가 1 PASS: 실제 완료 후 시스템 Dynamic Type/textClipped 감사, 완료 영역 스크롤 후 기록 보기 버튼 전체 표시, 버튼 이동 후 오늘 1회 확인. 최대 크기/VoiceOver/모션 검증과는 별개다. 별도 소스 대조에서 링 release settle·액체 meniscus 누락을 확인했으므로 모션 행은 계속 미완료다. 상세 `.omo/start-work/ios-completion-accessibility-20260906-0353.md`.

03:19 데이터 관리 ScrollView/semantic header/상단 고정 닫기로 수정 후 최신 관련 5건 PASS, 실패/skip 0. 기본·최대 감사와 실제 닫기, 설정/Pro 최대 감사 및 공유·삭제·재실행까지 포함한다. 체크마크·명시적 메뉴·inline title 포함 최종 소스다. 상세 `.omo/start-work/ios-data-management-layout-20260906-0317.md`. 아래 기록은 수정 전 실패 이력이며 전체 수동 매트릭스는 여전히 미완료다.

03:08 정정: 첫 실패에서 중단하지 않고 모든 issue를 실패로 수집하자 원본 기본 크기에서 close와 기록 삭제 header가 동시에 확인됐다. 최대 크기는 close/nil, 총 2 tests/4 failures. 이전 '실패 대상 변경'은 불완전한 첫 issue 관찰이었다. 감사 뒤 닫기 label/tap/dismiss는 두 조건 모두 assertion 실패 없이 완료했다. 제품 변경 없음. 상세 `.omo/start-work/ios-settings-accessibility-20260906-0308.md`.

03:04 기본/최대 A/B: 원본 기본 크기에서도 close 감사 실패. icon trial은 기록 삭제 header/nil로 실패 대상이 바뀌었고, header semantic font trial도 2 FAIL이었다. 제품 수정은 전부 원복했다. 기본 크기 회귀 테스트 및 실패 첨부를 보존했다. 상세 `.omo/start-work/ios-settings-accessibility-20260906-0304.md`. 감사 뒤 닫기 검사에는 도달하지 못했다.

02:52 추가 범위: 최대 Dynamic Type 설정/Pro 감사 2 PASS, 데이터 관리 1 FAIL. `data-management-close` 버튼이 최초 issue로 특정됐으며 세 가지 좁은 UI 실험은 해결되지 않아 원복했다. 새 테스트/실패 첨부는 유지한다. 상세 `.omo/start-work/ios-settings-accessibility-20260906-0252.md`. 전체 자동 suite 재실행 전이며 이전 UI14 PASS를 새 3건까지 포함한 결과로 해석하지 않는다.

`SummaryCardsView`와 `RitualView` 접근성 수정 후 unsigned Release archive가 성공했고 archive 정적 fixture/privacy 검사가 통과했다. 단, 위 수동/실기기 행은 새 screenshot/video와 직접 시스템 조작 근거가 없어 미완료다. 자동 테스트 또는 archive 결과를 실제 VoiceOver/Voice Control/Switch Control PASS로 대체하지 않는다. 증거: `.omo/evidence/ulw/maeumjaro-ios-simulator-20260905/G001-implement-approved-omo-plans-maeumja/a1/release-audit-accessibility-20260906/audit-summary.md`

## 01:54 접근성 결함 재현 및 수정 중

- 시스템 `.dynamicType` + `.textClipped` 첫 실행은 기록 요약 숫자에서 실패: `test_sim_2026-09-05T16-49-27-063Z_pid86149_6b30f22c.xcresult`. 원본 issue와 화면을 `a1/accessibility-red-0149`에 보존했다.
- 최대 글자 크기 실행의 단순 reachability 테스트는 통과했지만 실제 화면에서 의식 안내·문구 말줄임이 확인됐다(`a1/accessibility-max-0152`). 좁은 테스트 통과를 화면 완성으로 간주하지 않았다.
- SummaryCards는 접근성 크기에서 세로 배치, RitualView는 접근성 크기에서 ScrollView 및 안내/문구의 수직 intrinsic size 보존을 적용했다. 일반 크기의 제스처 컨테이너는 유지한다.
- 수정 후 시스템 audit 1건 통과. 최대 크기 여백 스크롤 검증은 처음 실패(`test_sim_2026-09-05T16-53-26-753Z_pid86149_0bd66ed6.xcresult`); 여백 hit region을 추가하고 회귀 검증 중이다.
- 최대 크기 전체 화면, Pro/완료/설정, VoiceOver 실제 순회는 여전히 미완료다.

## 01:58 수정 후 확인

- 최신 접근성 2건 PASS, 실패/건너뜀 0: `test_sim_2026-09-05T16-58-01-636Z_pid86149_9216b740.xcresult`.
- 기록/의식 시스템 Dynamic Type·textClipped 검사 및 최대 크기의 텍스트 영역 스크롤 후 진행률 접근이 통과했다. 여백 스크롤은 통과한 것으로 주장하지 않는다.
- 일반 크기 잠금 임계값/재잠금과 pause/resume 정확히 1건 저장은 직전 4건 실행에서 각각 PASS(`test_sim_2026-09-05T16-55-25-152Z_pid86149_c88c4be6.xcresult`). 해당 실행 전체는 최대 크기 스크롤 실패로 3 PASS / 1 FAIL이었다.
- 요약 카드 분기는 ViewThatFits 외부로 명시했으며, 의식 종료 cleanup은 안정적인 바깥 컨테이너로 이동해 크기별 레이아웃 교체와 분리했다.
- 02:03 최신 제품 소스 unsigned archive 재검증은 PASS(`a1/release-audit-accessibility-20260906`), 소스 해시 일치 확인. 02:08 전체 suite는 78건 중 76 PASS / StoreKit 2 FAIL, UI 14/14 PASS(`test_sim_2026-09-05T17-00-49-960Z_pid86149_d3a78422.xcresult`). 위 수동 체크리스트 전체를 PASS 처리하지 않는다.
