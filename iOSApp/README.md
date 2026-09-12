# 마음자로 iOS — Simulator 개발 빌드

Apple Developer 계정 없이 iOS Simulator에서 실행하는 네이티브 SwiftUI 앱이다. 실기기 배포, App Store Connect 및 실제 결제 검증은 포함하지 않는다.

## 실행

1. `iOSApp/Maeumjaro.xcodeproj`를 Xcode에서 연다.
2. Scheme `Maeumjaro`, 실행 기기는 설치된 iPhone Simulator를 선택한다. `Any iOS Device`는 선택하지 않는다.
3. Run(⌘R)을 실행한다. 시뮬레이터 빌드는 ad-hoc 서명이며 Developer Team은 비워 둔다.
4. 온보딩을 마치고 첫 화면의 펜을 누른다. 펜을 좌우로 밀어 잠금을 풀고 손을 뗀 다음 길게 누른다. 손을 떼면 일시정지하며, 완료된 동작만 기록된다. 하단은 홈·기록·설정 순서다. 기록에서 최근 7일 막대그래프를 보고, 세 번째 톱니바퀴 탭에서 전체 화면 설정을 연다.
5. 위젯은 홈 화면 편집 → 위젯 추가 → **마음자로**에서 추가한다. 작은/중간 위젯을 제공한다.

프로젝트 설정의 원본은 `project.yml`이다. 이를 변경했다면 `iOSApp` 디렉터리에서 `xcodegen generate`를 실행한다. Xcode 프로젝트만 수정하면 다음 생성 때 덮어써질 수 있다.

## 구현 범위

- 온보딩, 기록/설정 탭, 비의료적 자기조절 안내
- 제공된 7종 펜 에셋 기반 잠금 해제·연속 진행·일시정지·완료 화면
- SwiftData 기록 저장, 중복 완료 방지, 날짜별 조회·집계·히트맵
- App Group 강도 공유, WidgetKit small/medium, App Intents 강도 변경과 시작 링크
- Pro 접근 정책, StoreKit 2 구매/복원 경로, 내보내기·테마·기록 삭제 화면
- 접근성 대체 조작, 동작 줄이기 대응 및 테스트용 격리 fixture

## 검증 현황 — 2026-09-06

공개 저장소 반영 후속 검사(14:50 KST 시작)는 도구의 300초 응답 제한에 도달했으며 결과가 확정되지 않았다. 브랜드·문자열·기록 모델 선택 검사를 다시 시작하지 않고 기존 프로세스를 추적해야 한다. 성공으로 집계하지 않는다.

한국어 String Catalog를 앱·위젯·공용 패키지에 연결했다. 최신 선택 검사에서 앱/위젯 번들 조회·보간 키 및 기록 모델 **4/4 PASS**. 이 변경 후 전체 테스트·UI·Release 재검증은 아직 미완료다. 아래 외관 아카이브 결과는 로컬라이제이션 변경 전 이력이다. StoreKit 거래2건과 실제 시스템 dark 전파 문제도 미해결이며 출시 준비 완료로 간주하지 않는다.

05:50 추가: 최신 외관 변경 포함 unsigned Release archive 성공. 앱·위젯 QA 외관/fixture 표식 부재, privacy 선언과 펜 원본/runtime PNG 7종 해시 일치 확인. 전체 테스트와 실제 다크 검증은 여전히 별도다. 상세 `.omo/start-work/ios-appearance-release-20260906-0550.md`.

최신 추가 검사: light 기록·설정·의식 화면의 실제 contrast/hitRegion 감사 **1/1 PASS**. Settings 제목 대비를 보완하고, Settings 고유 요소로 실제 화면 진입을 확인한다. 위젯 실제 구성요소 렌더 48조합 및 palette/contrast 검사 **4/4 PASS**는 홈 위젯 호스트 전체 검증과 별개다. 시스템 dark 요청과 앱 UIKit/SwiftUI light 관측 불일치는 미해결이다. 최신 제품 변경 뒤 전체 suite·Release archive는 아직 재검증하지 않았다. 상세 `.omo/start-work/ios-appearance-followup-20260906-0533.md`.

전체 재실행은 **110건 중108 PASS / StoreKit2 FAIL / skip0**, UI24/24 PASS였다. 이후 테마 외관 연결을 보완했으므로 이 전체 결과와 이전 Release archive는 최신 수정의 최종 수용 증거가 아니다. 최신 테마 resolver·위젯 모델 검증은 **7/7 PASS**. 신규 실제 대비 UI 감사는 실패했으며, 시스템 dark 요청에도 앱 환경이 light로 관측되는 문제와 하단 스크롤 페이드 부근 대비 재검증이 남아 있다. 전체 완료·다크 모드 PASS로 표시하지 않는다. 상세 `.omo/start-work/ios-appearance-audit-20260906-0515.md`.

아래 04:57 및 그 이전 결과는 이력이다.

최종 추가 회귀 **12/12 PASS**(handoff9·두 크기 cold 완료1·기본/최대 글자UI2), 별도 위젯 결합 **3/3 PASS**(cold취소·cold완료·warm완료/삭제 동기화). 일반 무인자 앱 재실행 PID58759와 기록 화면 확인, 일반 SQLite 기록/설정 전후동일. 전체 suite 재실행과 StoreKit2건 해결은 아직 별도다.

최신 추가 검증: 앱 종료 후 작은·중간 위젯에서 각각 시작 → 중단·재개 → 완료 → 두 크기 요약 갱신 UI 통과. 두 격리 SQLite 모두 정확히1행(`source=widget`, 강도5, 3200ms, 중단1회)이며 일반 기록/설정 전후 동일. QA handoff 회귀9건 PASS. 새 unsigned Release archive 성공, 신규 QA 표식 제외·privacy·PNG7종 검증 PASS. 상세 `.omo/start-work/ios-cold-widget-completion-20260906-0446.md`. 아래 날짜별 결과는 이력이며 전체 최종 승인은 아니다.

최신 갱신(04:29): 모션 반영 전체 `Maeumjaro` 플랜 **97건 중95 PASS/StoreKit2 FAIL/skip0**, UI22/22 PASS. 추가 background hosted/UI 실행7/7 PASS(실제 UI paused 진행률18% 유지·close기록0·재진입0, hosted99% 중단/재개). `MaeumjaroStoreKit` 플랜77건 중75 PASS/동일2 FAIL. 최신 unsigned Release archive/privacy/Release fixture 제외/7PNG PASS. 정상 Simulator 실행PID36689. 상세 `.omo/start-work/ios-post-motion-regression-20260906-0424.md`. 아래 표는 이전 이력이며, 이번 전체97건에는 동시 추가한3개 테스트가 포함되지 않는다.

| 검증 | 실제 결과 |
| --- | --- |
| 최신 시뮬레이터 빌드·설치·실행 | 성공, 03:20 KST; 일반 실행 PID 69820 |
| MaeumjaroCore 패키지 | 03:23 재실행 94건 통과, 실패 0 |
| 전체 앱·위젯·UI 테스트 | 03:30 최신 85건 중 83 PASS, StoreKit 거래 2 FAIL, skip 0. 결과 `test_sim_2026-09-05T18-20-37-286Z_pid86149_d7798165.xcresult` |
| UI 테스트 | 최신 전체 실행 20/20 PASS: 기존 기능·데이터 관리 접근성·딥링크·위젯·시작 측정 포함 |
| 작은·중간 위젯 콜드 진입 | 03:41 추가 1건 PASS: 앱 `.notRunning` → 각각 위젯 시작 → 의식 화면 → 닫기 → 오늘 기록 수 불변. 콜드 완료·저장 증거는 아님. `test_sim_2026-09-05T18-40-28-835Z_pid86149_69f5d6e1.xcresult` |
| 위젯 테스트 결합 회귀 | 03:43 콜드 진입·취소 및 기존 warm 완료·두 크기 삭제 동기화 2/2 PASS, skip 0. `test_sim_2026-09-05T18-41-46-927Z_pid86149_0d9889f4.xcresult` |
| 추가 위젯 완료 UI 테스트 | 00:23 재검증 통과: 위젯 시작→의식 완료→앱 오늘 기록 1회→홈 화면 오늘 1회 |
| 두 크기 위젯 삭제 동기화 | 01:38 확장 UI 테스트 1건 통과: 위젯 시작→의식 완료→작은·중간 모두 오늘 1회→격리 기록 전체 삭제→앱 빈 기록→두 위젯 모두 오늘 0회. `test_sim_2026-09-05T16-36-59-308Z_pid86149_39a5c90e.xcresult` |
| 펜 제스처 경계 UI | 01:47 확장 1건 통과: 현재 interactionWidth 320 설정에서 44pt 가로 잠금 유지, 56pt 가로 해제, 잠금 상태의 56×80pt 세로 우세 거부, 준비 상태의 빠른 세로 이동 후 진행률 0 유지, 새 포인터의 반대 방향 재잠금·해제, 기록 0 유지. `test_sim_2026-09-05T16-46-22-023Z_pid86149_d58304d0.xcresult` |
| Pro 기록 UI | 테스트용 Pro fixture로 히트맵·시간대/요일/강도 분포 표시 통과; 실제 구매 증거와 별개 |
| Free 기록·오프라인 UI | 무료 30일 목록·히트맵 비노출, 스토어 실패 상황의 의식 완료·1건 저장 통과 |
| 공유·삭제·테마 유지 UI | 01:09 통과: CSV/JSON 네이티브 공유 취소, 삭제 취소 시 기록 유지, 전체 삭제 후 재실행 시 빈 기록·Forest Mist·온보딩 유지 |
| 개별 삭제·오프라인 결제 안내 UI | 01:27 추가 2건 통과: 개별 삭제 취소/확인/재실행, 스토어 장애 시 구매 비활성화와 복원 실패 안내; 기존 전체 suite와 별도 실행 |
| 작은 위젯 수동 확인 | 홈 화면 표시, 강도 3→4, 시작→펜 화면 이동 확인 |
| 중간 위젯 수동 확인 | 갤러리에서 추가, 강도 5 선택 시 작은·중간 위젯 모두 갱신 |
| 서명 없는 generic iOS archive | 최신 데이터 관리 수정 포함 성공; release-audit-data-layout-20260906 |
| 아카이브 개인정보·리소스 검사 | 앱/위젯 tracking false·수집 항목 0·UserDefaults 사유 확인, 펜 PNG 7종 해시 일치 |
| Release 실행 파일 검사 | 지정된 테스트 fixture 문자열 미검출 |

UI 테스트 통과는 전체 접근성·크기별 화면 검증을 의미하지 않는다. 최신 전체 결과는 위의 04:29 기록을 따르며 03:41 콜드 진입·04:46 콜드 완료는 별도 실행이다. StoreKit 로컬 구매·환불은 `SKInternalErrorDomain Code=3` / `notEntitled`로 실패하며 원인을 조사 중이다. 실패를 숨기거나 Pro를 실제 구매한 것으로 처리하지 않는다. Scheme Run의 로컬 StoreKit 설정은 연결했지만 거래 테스트 성공은 아직 입증되지 않았다.

공유 화면과 데이터 관리에 명시적인 닫기 버튼을 추가했다. CSV/JSON 네이티브 공유 팝오버에 파일명이 표시되고 외부 전송 없이 닫히는 경로를 확인했다. 삭제 확인창 자동 닫힘이 비동기 삭제를 무효화하던 결함은 단일 사용 확인 토큰으로 수정했다. 삭제·재실행 결합 UI와 관련 모델 테스트 5건이 통과했다(`test_sim_2026-09-05T16-07-24-562Z_pid86149_ffd29920.xcresult`). 위젯 테마는 저장된 설정을 먼저 반영한 후 기록 요약을 복구하도록 수정했으며, 해당 순서에 대한 독립 소스 재검토는 통과했다.

StoreKit 오류가 유료 Apple Developer 계정 부재 때문이라는 근거는 없다. 01:22 직접 `xcodebuild test` 비교에서도 6건 중 거래 2건이 동일하게 실패했다. 따라서 MCP 테스트 실행 방식만의 문제라고 볼 수 없다. Xcode GUI 테스트 플랜 비교는 아직 미실행이며 실제 결제나 계정 추가가 필요한 단계는 아니다. 자세한 근거는 `.omo/start-work/storekit-direct-comparison-20260906.md`에 기록했다.

03:50 환경 대조: Xcode 26.6(17F113), 설치된 Simulator는 iOS 26.5(23F77) 하나다. [Apple 포럼의 관련 보고](https://developer.apple.com/forums/thread/826971)에는 같은 Simulator 빌드의 후속 재현이 있지만, 이 앱의 원인 확정 또는 해결 증거는 아니다. 런타임·계정·서명 설정은 변경하지 않았다. 상세 `.omo/start-work/storekit-runtime-correlation-20260906-0350.md`.

## 남은 수용 검증

04:14 모션 보완: 링은 직접 포인터 추종과 release-only 260ms 정착을 분리하고, 보간 중 면 전환·PNG 뒤집힘·마지막 release 방향을 보정했다. 액체 수면 곡면과 Reduce Motion 대응을 추가했다. 수직 우세 unlock은 즉시 취소한다. 최신 Core 96 PASS, 링·액체·실제 의식 UI 결합 12 PASS/0 FAIL/0 skip. 일반 Simulator 재빌드·설치·실행 성공(PID 23994). 상세 `.omo/start-work/ios-motion-repair-20260906-0400.md`. 아래 03:53의 모션 누락은 보완 전 이력이다. 전체 suite·archive는 이번 제품 변경 뒤 아직 재실행하지 않았으며 StoreKit 실패와 전체 수용 게이트는 그대로 남아 있다.

03:53 완료 화면 접근성 추가 1 PASS: 완료 후 감사·스크롤·기록 보기 버튼 전체 표시·오늘 1회 확인. 별도 모션 계약 대조에서 링 260ms release settle과 액체 수면 표현이 빠진 점을 확인했다. 시각 계약 전체 준수로 판정하지 않으며 보완이 필요하다. 상세 `.omo/start-work/ios-completion-accessibility-20260906-0353.md`.

03:19 데이터 관리 접근성 수정 완료: 닫기·섹션 제목의 확장 가능한 레이아웃, 테마 선택 체크마크, 명시적 형식 메뉴를 적용했다. 관련 5건 모두 PASS(기본/최대 데이터 감사, 설정/Pro 최대 감사, CSV/JSON 공유 취소·삭제·테마 유지·재실행). 이후 전체 suite와 archive도 재실행했으며 결과는 위 표의 03:30 기록을 따른다. 상세 `.omo/start-work/ios-data-management-layout-20260906-0317.md`. 아래 03:04/02:52는 수정 전 실패 이력이다.

03:04 기본/최대 글자 크기 비교에서도 데이터 관리 감사 실패가 재현됐다. icon 및 Section header 수정은 해결되지 않아 원복했다. 현재 제품 UI는 변경 전과 동일하며 기본 크기 회귀 검사를 추가했다. 상세 `.omo/start-work/ios-settings-accessibility-20260906-0304.md`.

02:52 접근성 추가 3건에서 설정/Pro 2 PASS, 데이터 관리 Dynamic Type audit 1 FAIL. 최초 실패 요소는 닫기 툴바 버튼(60.3×36pt). 시험한 UI 변경은 해결되지 않아 원복했으며 회귀 테스트는 유지했다. 상세 `.omo/start-work/ios-settings-accessibility-20260906-0252.md`.

02:30 시작 성능 추가 측정: `XCTApplicationLaunchMetric` 3회 평균 1.697초, 별도 테스트 1 PASS. 새 empty fixture의 앱 시작만 측정했으며 위젯 진입·터치 지연·hitch 및 전체 성능 목표는 미검증이다. 실제 build log에 UI 테스트 번들 App Intents metadata 경고 1개가 있어 warning 0 판정은 하지 않는다. 상세 `.omo/start-work/ios-launch-performance-20260906-0230.md`.

02:24 백업 제외 추가 검증 PASS: 실제 Simulator 호스트 앱의 UUID 격리 Application Support에 SQLite를 생성하고, 캐시를 비운 URL에서 `isExcludedFromBackup=true`와 파일 존재를 확인했다. `PersistenceBackupTests` 1건 통과, 결과 `test_sim_2026-09-05T17-24-46-185Z_pid86149_24406432.xcresult`. 기존 전체 실행과 별도이며 기존 사용자 DB를 변경하지 않았다. 남은 범위는 `.omo/start-work/ios-acceptance-gap-matrix-20260906-0216.md`에 기록했다.

02:13 딥링크 추가 검증 PASS: 실제 OS URL로 잘못된 host를 열어도 기록/의식 route가 생기지 않으며, URL의 `intensity=1`은 무시하고 저장 강도 3을 사용한다. widget/app 출처로 각각 완료한 후 격리 SQLite를 읽기 전용 조회해 정확히 2행, 출처 각각 1개, 강도 3·1800ms·시간대/날짜/문구/버전을 확인했다. 결과 `test_sim_2026-09-05T17-12-18-107Z_pid86149_07e15367.xcresult`, 상세 `a1/deep-link-0213/source-integrity.json`. 기존 전체 78건 실행과 별도 추가 테스트다.

01:58 접근성 수정: 큰 글자에서 요약 카드를 세로로 배치하고 의식 화면의 안내 말줄임을 없애며 스크롤을 지원했다. 시스템 Dynamic Type/textClipped와 최대 글자 진행률 접근 테스트 2건이 통과했다. 02:08 전체 78/76(UI 14/14) 및 최신 archive 재검증을 마쳤다. 전체 실행은 도구의 300초 응답 제한 뒤에도 계속 실행됐으며, 동일 프로세스의 종료 로그와 xcresult를 직접 읽어 결과를 확인했다. 상세 실패→수정 기록은 `QA/AccessibilityChecklist.md`에 있다.

- StoreKit 로컬 구매·환불 2건 해결 및 전체 자동 테스트 재실행
- 위젯 강도 변경·테마·권한 철회의 전체 경로 결합 검증(두 크기 cold 완료·요약 갱신은 별도 통과)
- 실제 Pro 철회 후 홈 위젯 동기화 및 독립 수동 재검증(전체 삭제 후 두 크기 동기화는 UI 테스트 통과)
- Dynamic Type, VoiceOver 실제 순회, Reduce Motion, 화면 크기별 전체 매트릭스
- 계획서 Todo 16/17 및 독립 최종 검증: 미완료. 구현 존재와 최종 승인 완료를 구분한다.

원본 `docs/maeumjaro_pen`과 `assets/maeumjaro_pen`은 유지한다. Android 작업과 기존 staged 에셋은 이 iOS 검증과 별개이며, 이 작업에서는 커밋·푸시하지 않았다.
