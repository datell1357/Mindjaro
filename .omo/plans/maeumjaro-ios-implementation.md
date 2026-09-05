# maeumjaro-ios-implementation - Work Plan

## 실행 승인 및 최종 에셋 계약 우선 적용 (2026-09-05)

사용자는 최종 PNG 7종과 개발 문서 4종을 전달하고 앱 구현을 명시 승인했다. Apple Developer 계정 없이 Simulator에서 먼저 확인한다. 아래 조항은 본문 모든 Todo/QA의 이전 상충 문구보다 우선한다.

- `docs/maeumjaro_pen/integration_contract.json` schemaVersion 5와 동반 README/interaction_design/qa를 펜 구현의 권위 계약으로 삼는다. `assets/maeumjaro_pen/`의 사용자 제공 최종 7 PNG를 byte-identical 복사하여 번들에 사용한다. 이는 과거 참고 이미지 추출 금지의 명시적 예외이며 새 펜 Shape 생성 지시는 대체된다. 원본 docs/assets는 변경하지 않는다.
- 본체 1024×1536, 링 (362,136,300,112), 액체창 (449,650,126,414)을 단일 비율로 합성한다. 한 링의 앞/뒷면 Y축 회전 180도로 좌우 해제/재잠금을 제공하고 이미지 슬라이드/페이드는 사용하지 않는다. 빈 창+독립 액체 마스크+수면을 연속 갱신한다.
- 초기 상태는 locked이다. 수평 우세 1.25, 임계값 max(44,min(56,입력폭×0.18))pt, release 시 commit이다. ready의 새 pointer sequence에서 120ms hold 대기 중 수평 이동 8pt 초과이면 재잠금으로 전환한다. 해제한 손가락 sequence로 hold를 시작하지 않는다. holding 뒤에는 링 제스처로 바뀌지 않는다.
- 강도 1~5 initialFill은 .2/.4/.6/.8/1.0, durationMs는 1200/1500/1800/2200/3200이다. 액체 남은 높이는 initialFill×(1-progress)로 적용하여 강도별 초기량과 연속 배출을 함께 보장한다.
- release/cancel/background/scene inactive는 현재 진행률을 보존해 paused로 전환하고 기록하지 않는다. foreground 자동 재개는 금지한다. 앱 프로세스 종료 또는 사용자 reset/새 의식만 미완료 session을 버린다. 이전 background→ready reset와 2600ms 테스트/성능 문구를 이 계약으로 대체한다.
- Reduce Motion은 release 시 링 최종 상태 즉시 전환, 연속 액체 숫자 유지, 장식 수면 모션 제거다. 네이티브 접근성 대체 조작은 같은 상태/정확히 한 번 저장 계약을 유지한다.
- Simulator build/install/launch와 실제 터치 핵심 흐름은 필수 완료 기준이다. Apple Developer 등록, 서명 실기기, 실제 촉감/기기 FPS, App Store Connect/제출은 releaseBlockers이며 로컬 구현의 선행조건이 아니다. 이미 명시 승인된 구현을 완료하기 위한 중간 재승인은 요청하지 않는다.
- Android 동시 작업과 `.omo/boulder.json`의 다른 work 항목은 보존한다. Git 초기화는 작업 시점의 실제 상태를 확인하여 한 번만 수행하며 다른 작업 파일은 stage하지 않는다. 개인정보 없는 raw Simulator 식별자는 도구 입력에만 사용하고 공유 보고서에는 기기 종류/OS 또는 해시를 기록한다.


## TL;DR (For humans)

**What you'll get:** 홈 화면 위젯에서 강도를 정하고 곧바로 짧은 자기조절 의식을 실행한 뒤, 완료된 사용만 기기에 기록하는 네이티브 iPhone 앱입니다. 무료 사용자는 오늘 요약과 최근 30일 기본 기록을 보고, 1회 구매 Pro 사용자는 52주 히트맵·상세 패턴·내보내기·추가 테마를 이용합니다.

**Why this approach:** 앱의 실제 기록은 앱 내부 데이터베이스 한 곳에서 관리하고, 위젯에는 강도와 오늘 요약만 공유합니다. 이 경계는 위젯의 별도 프로세스 제약, 중복 기록 위험, 민감한 기록 노출을 동시에 줄이며 브라우저 데모의 `localStorage` 한계를 그대로 옮기지 않습니다.

**What it will NOT do:** 의약품·치료·체중 감량 효과를 주장하지 않으며, 음식·칼로리·체중·실제 용량·성공 여부를 기록하지 않습니다. 로그인, 서버, 클라우드 동기화, 광고, 구독, AI 진단, 센서 권한, Android/Flutter/Rive 구현은 포함하지 않습니다.

**Effort:** XL
**Risk:** High - 신규 앱·위젯·공유 상태·SwiftData·StoreKit·접근성·실기기 햅틱을 함께 검증해야 하고, 현재 CoreSimulatorService가 응답하지 않습니다.
**Approved decisions:** iOS 17 이상, 완전한 네이티브 SwiftUI, 네이티브 Shape/Canvas/mask 애니메이션, 무료 30일/Pro 52주와 Pro 전용 내보내기, 개발용 이름과 식별자는 아래 값으로 확정됐습니다.

Your next move: 이 계획으로 구현을 시작할 때 `omo:start-work maeumjaro-ios-implementation`을 실행합니다. Apple Developer Team·App Store Connect·공개 상표명은 로컬 구현을 막지 않지만 출시 전에 별도 승인해야 합니다. Full execution detail follows below.

---

> TL;DR (machine): XL/high-risk greenfield iOS 17 implementation with SwiftUI, SwiftData, WidgetKit/App Intents, App Group snapshots, StoreKit non-consumable Pro, hybrid RED→GREEN testing, simulator/device evidence, and release-only external gates.

## Scope
### Must have

- 새 구현 루트는 `iOSApp/`이며 XcodeGen 2.46.0의 `iOSApp/project.yml`을 프로젝트 정의의 단일 출처로 사용한다. 생성된 `iOSApp/Maeumjaro.xcodeproj`는 손으로 편집하지 않는다.
- 앱/위젯/상품 식별자는 각각 `com.yeoreum.maeumjaro`, `com.yeoreum.maeumjaro.widget`, `group.com.yeoreum.maeumjaro`, `com.yeoreum.maeumjaro.pro`로 고정한다. URL scheme은 `maeumjaro`, 위젯 진입 URL은 `maeumjaro://inject?source=widget`이다.
- 배포 대상은 iPhone, iOS 17 이상이다. 앱은 SwiftUI·SwiftData·Swift Charts·StoreKit 2·Core Haptics/SwiftUI sensory feedback, 위젯은 WidgetKit·App Intents를 사용한다. 타사 런타임 패키지는 추가하지 않는다.
- 일반 실행은 `기록`/`설정` 2개 탭으로 시작하며 기록 화면 상단에서 의식을 시작할 수 있다. 위젯 실행은 중간 화면 없이 최신 공유 강도로 의식 화면을 연다.
- 온보딩은 제품 목적, 사용법, 기본 강도 1~5(기본 3), 감각 설정, 비의료 면책, 선택 가능한 위젯 안내를 포함하고 로그인·건강 설문·권한 요청을 포함하지 않는다.
- 강도 프로필은 1→20%/1.2초/진행 pulse 1회, 2→40%/1.5초/2회, 3→60%/1.8초/3회, 4→80%/2.2초/4회, 5→100%/2.6초/5회다. 프로필 N의 진행 pulse는 `k/(N+1)`(`k=1...N`)에서 한 번씩 발생한다. 최초 press의 시작 cue 1회와 완료 cue 1회는 N에 포함하지 않으며, pause/resume에는 시작 cue가 없고 이미 지난 threshold는 재생하지 않는다. 앱/시스템 햅틱 OFF 또는 미지원 기기에서는 모든 cue가 0회지만 시각·텍스트 동작은 동일하다. 이 계약은 `IntensityProfile` 한 곳에서만 정의한다.
- 의식은 누르는 동안만 진행하고 release 시 일시정지, 재누름 시 같은 지점부터 재개, 완료 전 background/scene inactive 시 ready로 초기화한다. 100% 첫 통과에서만 이벤트 저장 effect를 한 번 방출한다.
- 프로덕션 그래픽은 SwiftUI Shape/Canvas/mask로 새로 만든 추상적 세로형 의식 오브젝트다. `docs/`의 픽셀, SVG, MP4, 브랜드 외형을 복사하거나 앱 자산으로 포함하지 않는다.
- 문구는 안정적인 ID·카테고리·톤·안전 상태를 가진 최소 100개 한국어 번들 카탈로그다. 현재 강도/선호 톤 필터, 최근 10개 ID 제외, 같은 카테고리 3연속 방지, 안전 fallback을 순서대로 적용한다.
- `InjectionEvent`는 `id`, 시작/완료/생성 UTC, 완료 당시 현지 날짜, timezone offset, 강도, 진입 경로, phrase ID, 목표 애니메이션 시간, 중단 횟수, 앱 버전을 저장한다. 미완료 시 0건, 같은 session ID 재호출 시 정확히 1건이다.
- 앱 sandbox SwiftData DB는 이벤트·문구·강도를 제외한 설정(선택 테마 포함)의 원본이다. 현재 강도의 유일한 원본은 App Group의 `SharedStrengthStore`이고 `AppSettings`에는 강도 필드를 두지 않는다. App Group에는 버전이 붙은 현재 강도와, DB에서 투영한 오늘 요약·위젯 테마의 독립 Data blob만 저장하며 위젯/Intent는 SwiftData를 링크하거나 migration하지 않는다.
- 소형 위젯은 `-`/시작/`+`, 중형은 강도 1~5 직접 선택과 시작 버튼을 제공한다. 강도 App Intent는 공유값 저장과 read-back 확인 뒤 반환하고 WidgetKit의 interactive-intent 후속 timeline 갱신에 맡기며 직접 `WidgetCenter.reloadTimelines`를 호출하지 않는다. 앱은 URL의 강도를 신뢰하지 않고 공유 저장소의 최신 유효값을 읽는다. 앱 프로세스에서 완료·삭제·테마/entitlement 전환으로 snapshot을 바꿀 때만 해당 widget kind를 명시적으로 reload한다.
- 무료는 의식·위젯·오늘 요약·최근 실행·오늘 포함 최근 30개 현지 날짜의 기본 기록/날짜 상세를 제공한다. 모든 이벤트는 계속 보존한다.
- Pro는 StoreKit 비소모성 상품으로 검증된 entitlement에서만 열리며 52주 count/intensity 히트맵, 3시간대·요일·강도 분포, 30건 이상 4주 대 4주 비교, CSV/JSON 내보내기, 추가 테마를 제공한다. 취소·pending·unverified·환불/철회 상태는 fail-closed다.
- 집계는 저장 당시 local date/timezone을 사용한다. active-day average는 `기간 완료 건수 / 완료 1건 이상인 날짜 수`이며 빈 분모는 0이다. 미래 날짜·자정·DST·timezone 변경 fixture를 포함한다.
- 전체 기록 삭제는 취소/확인을 분리하고 이벤트만 삭제한다. 설정·문구·Pro entitlement는 보존하고 오늘 요약/위젯을 0으로 재투영한다. 내보내기는 Pro에서만 사용자 명시 동작 후 OS share sheet로 전달하며 취소 시 외부 전달과 원본 변경이 없다.
- 한국어가 기본이며 모든 사용자 문자열은 String Catalog로 관리한다. 시스템 글꼴만 사용하고 VoiceOver, Voice Control, Switch Control, 최대 Dynamic Type, Differentiate Without Color, Increase Contrast, Reduce Motion, 라이트/다크 모드를 지원한다.
- 앱과 위젯은 네트워크 없이 핵심 루프·기록·집계·삭제가 동작한다. StoreKit 구매/복원만 시스템 StoreKit 연결을 사용하며 앱 자체 backend나 analytics SDK는 없다.
- `docs/` 전체 checksum을 구현 전후 비교해 원본 산출물이 바뀌지 않았음을 증명한다.

### Must NOT have (guardrails, anti-slop, scope boundaries)

- Flutter, Rive, Android, Web 제품 구현, HTML/JS 포팅, 타사 DI/state/analytics 패키지, 범용 clean architecture 프레임워크를 추가하지 않는다.
- 타이머, 음식·칼로리·체중·실제 약물 용량, HealthKit, 카메라, 사진, 마이크, 위치, 알림, 연락처, 생체 센서, 계정, backend, CloudKit, 소셜, 광고, 구독을 추가하지 않는다.
- 식욕 감소, 체중 감량, 치료, 처방, 의약품 대체, 성공·실패·의지력 점수, streak, 질환·생활 습관 추론을 UI·문구·차트·StoreKit 설명에 넣지 않는다.
- 위젯이나 App Intent가 SwiftData DB를 열거나 migration하지 않는다. App Group에 전체 이벤트, 문구 본문, 결제 transaction을 복사하지 않는다.
- 시작·중단·pause·딥링크 진입·background 전환만으로 이벤트를 만들지 않는다. migration 실패 시 DB를 자동 삭제하거나 재생성하지 않는다.
- `docs/` 파일, 사용자의 기존 `.omo/` Android 계획, workspace 외부 파일을 수정·이동·삭제하지 않는다. QA를 위해 Simulator erase, 앱 삭제, 실기기 데이터 삭제를 자동 수행하지 않는다.
- 참고 이미지/영상/브라우저 SVG/예시 데이터/보라색 그라디언트/특정 의약품 펜의 실루엣을 production asset으로 재사용하지 않는다.
- 공개 앱 이름·상표 승인, Apple Developer Team 등록, App Store Connect 상품 생성, 스토어 제출을 구현 완료로 가장하지 않는다.

## Docs requirement disposition

| 문서 요구/충돌 | 최종 결정 | 구현 Todo / 검증 |
| --- | --- | --- |
| Flutter/Rive 예시 구조 | 승인된 네이티브 SwiftUI/Shape/Canvas 구조가 이를 대체한다. Flutter/Rive 산출물은 만들지 않는다. | 1, 8, 12 / F1, F4 |
| 위젯 미설치 감지 알림 | 공개 API로 설치 여부를 확정하지 않는다. 온보딩과 기록 화면에 사용자가 닫을 때까지 남는 정적 위젯 안내 banner를 제공하고, 설정에는 항상 위젯 도움말을 둔다. “미설치 감지”라고 주장하지 않는다. | 11 / UI test, F3 |
| 기록 상세의 수정·삭제 | 자동 기록의 무결성을 위해 MVP의 개별 “수정”은 제외한다고 명시적으로 supersede한다. 개별 삭제는 날짜 상세 메뉴→확인으로 제공하며 선택한 event만 지운 뒤 오늘 요약을 재투영한다. 전체 삭제는 별도 데이터 관리 흐름이다. | 6, 14–16 / repository·UI·projection tests |
| 세로 화면 중심 | iPhone portrait만 지원하도록 target orientation을 고정하되 모든 지원 iPhone 크기와 Dynamic Type을 검증한다. | 1, 17 / Info·surface matrix |
| 3–6초 전체 흐름 vs 1.2–2.6초 animation | `IntensityProfile`의 1.2–2.6초가 press 진행 시간의 권위값이다. 3–6초는 진입·완료 문구까지 포함한 경험 envelope이며 별도 타이머가 아니다. | 3, 12 / reducer·performance evidence |
| 16주 vs 30일/52주 | Free는 오늘 포함 30 local dates, Pro는 52주이며 Pro 첫 화면 viewport만 최근 16주다. | 5, 14 / fixture exact match |
| 내보내기 무료/Pro 표현 차이 | 승인안대로 CSV/JSON 내보내기는 verified Pro 전용이다. | 9, 15 / access tests |
| “약물/치료” 제목·효능 뉘앙스 | 비의료 자기조절 도구로 재정의하며 실제 약물·용량·치료·효능·성공 판단을 모두 제외한다. | 4, 8, 11–17 / copy scan, F4 |
| 로컬 기록과 백업 | CloudKit/앱 자체 sync는 없다. SwiftData store directory에는 `URLResourceKey.isExcludedFromBackup=true`를 적용해 기기 백업에서 제외한다. App Group에는 full history가 없고 강도/오늘 요약/테마만 있으며 삭제·재설치 시 복원 보장을 하지 않는다. | 6, 7, 17 / URL resource test, privacy checklist |
| 개인정보 매니페스트 | app과 widget 각각 별도 `PrivacyInfo.xcprivacy`를 target에 포함한다. App Group `UserDefaults` 용도는 Apple 승인 사유 `1C8F.1`로 선언하고 실제 archive의 required-reason API 사용과 대조한다. | 1, 7, 17 / plist·archive scan |

## Verification strategy
> Zero human intervention for local implementation gates. Public release gates that require signing, a physical device, account configuration, trademark/asset approval, or tactile judgment remain explicit external blockers.
- Test decision: hybrid RED→GREEN. `MaeumjaroDomain`, `MaeumjaroShared`, `MaeumjaroPersistence`, `MaeumjaroIntents`, completion coordinator, exporter, StoreKit access policy는 Swift Testing/StoreKitTest로 failing test를 먼저 작성한다. SwiftUI 화면은 먼저 부재 상태의 real-surface scenario를 RED로 캡처하고 최소 화면을 만든 뒤 XCTest UI/accessibility wiring을 추가한다.
- Existing behavior pin: greenfield이므로 기존 앱 behavior는 없다. `docs/`는 product baseline이므로 구현 전후 `find docs -type f -print0 | xargs -0 shasum -a 256 | LC_ALL=C sort` 결과가 byte-identical이어야 한다.
- Automated gates: `xcodegen generate --spec iOSApp/project.yml`, `swift test --package-path iOSApp/Packages/MaeumjaroCore`, generic simulator build, 실제 available iPhone UDID 대상 `xcodebuild test` 2개 test plan, warning-free compile, archive preflight 순으로 실행한다.
- Test targets: package tests(`MaeumjaroDomainTests`, `MaeumjaroSharedTests`, `MaeumjaroPersistenceTests`, `MaeumjaroIntentsTests`), app unit tests(`MaeumjaroAppTests`), widget unit tests(`MaeumjaroWidgetTests`), UI/system tests(`MaeumjaroUITests`). Swift Testing과 XCTest API를 한 test file 안에서 섞지 않는다.
- Determinism: clock, calendar, timezone, UUID, random phrase seed, haptic scheduler, StoreKit client, app-side widget reloader를 주입한다. `Task.sleep`이나 무한 retry로 timing test를 통과시키지 않는다.
- Fixture contract: Debug/test build만 `-MaeumjaroFixtureID <uuid>`와 `-MaeumjaroFixture <empty|analytics-reference|free-boundary|pro-boundary|ritual>`을 받는다. SwiftData는 app sandbox `Library/Caches/MaeumjaroQA/<fixtureID>/`에 분리하고 App Group key는 `qa.<fixtureID>.*`로 namespace한다. app이 `qa.activeFixtureID`를 쓰고 widget이 읽는 연결도 `#if DEBUG` 안에만 두며, Release binary/string scan에는 모든 fixture key와 entitlement override가 0건이어야 한다. 각 QA는 새 UUID를 써서 erase/uninstall 없이 fresh state를 얻는다.
- Manual surface: iOS Simulator는 `mcp__cua_repl`의 첫 호출 `let simulator = await cua.getApp("Simulator");`로 실제 UI를 조작하고, 각 단계 뒤 `xcrun simctl io booted screenshot <artifact>` 또는 `recordVideo <artifact>`로 증거를 남긴다. 테스트용 accessibility identifier는 shipped semantic label을 대체하지 않는다.
- Verdict split: `implementationVerdict`는 자동 test, build/archive preflight, Simulator surface가 모두 통과하면 승인할 수 있다. `releaseVerdict`는 signing 가능한 iPhone에서 widget cold launch, 다중 widget/reboot, 실제 haptic event scheduling, frame pacing, share sheet, StoreKit sandbox restore, Voice Control/Switch Control을 직접 확인해야만 PASS다. 기기가 없으면 구현 완료를 막지 않고 `releaseBlockers`에 남기며, 촉감의 주관적 적절성은 사용자 release acceptance 없이는 PASS로 주장하지 않는다.
- Cleanup: recordVideo process는 종료 상태를 확인하고 앱이 연 QA용 task/StoreKit observer는 종료한다. Simulator erase/uninstall, evidence·temporary file 삭제, production App Group clear는 수행하지 않는다. OS가 관리하는 share temporary item은 앱 session 종료 시 자동 폐기되게 구현한다.
- Evidence: `<attemptDir>/task-<N>-maeumjaro-ios-implementation.{log,xcresult,png,mp4,json}`. `<attemptDir>`는 `omo ulw-loop status --json`의 `currentAttemptDir`; ulw-loop 밖에서는 `.omo/evidence/maeumjaro-ios-implementation/`을 사용한다.
- Current environment gate: `xcrun simctl list devices available`가 성공하고 실제 iPhone Simulator UDID가 나올 때까지 simulator build/test/manual QA를 PASS로 기록하지 않는다.

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.

1. Wave 0, project source of truth: Todo 1만 실행해 XcodeGen 정의, app/widget/test targets, configs, schemes, test plans의 소유권을 고정한다.
2. Wave 1, contracts: Todo 2가 값 객체·repository protocol·식별자·access 계약을 동결한다.
3. Wave 2, seven independent core lanes: Todo 3–9를 병렬 실행한다. 각 lane은 자신의 package/app infrastructure/brand 경로만 소유하고 `project.yml`, composition root, feature view를 건드리지 않는다.
4. Wave 3, intent boundary: Todo 10은 Todo 7의 App Group codec/store가 GREEN인 뒤 실행한다.
5. Wave 4, feature surfaces: Todo 11이 먼저 placeholder `RootView`를 온보딩/탭 shell로 연결한다. 그 뒤 Todo 12–15를 병렬 실행하되 fake port와 `ImageRenderer`/preview-host component artifact로만 독립 검증한다. 공용 API나 app composition을 feature lane에서 임의 변경하지 않는다.
6. Wave 5, integration: Todo 16이 `RootView`를 이어받아 composition root, deep-link route, 실제 feature navigation, completion→DB→widget projection, delete/export/entitlement를 단독 조립하고 Wave 4에서 보류한 모든 cross-feature Simulator QA를 수행한다.
7. Wave 6, runtime/release acceptance: Todo 17이 전체 자동 gate와 Simulator/실기기 표면을 수행한다. 그 뒤 F1–F4를 병렬 실행한다.

Team mode verdict: OFF. 같은 계약을 동시에 수정하는 겹친 작업이 아니라 소유 경로가 분리된 lane이며, 계약 변경은 Wave 1에서 먼저 고정한다. 병렬 background workers가 더 단순하고 충돌 위험이 낮다.

### Per-Todo completion gate

1. Executor는 pre-change RED, 최소 GREEN 구현, 해당 real/data-shaped surface, adversarial probe, cleanup receipt를 완료하고 `DoneClaim`을 만든다.
2. Git master는 해당 Todo 소유 파일만 stage해 primary commit을 만들고 full SHA·diff·명령·artifact path를 기록한다.
3. Executor와 다른 independent verifier가 그 full SHA의 전체 현재 상태를 읽고 `stale_state`, `dirty_worktree`, `misleading_success_output`을 포함해 계획의 acceptance/QA/cleanup을 검증한다. `confirmed` 전에는 checkbox를 완료하지 않는다.
4. `failure`이면 같은 executor가 원인별 새 RED→GREEN과 영향 surface를 수행하고 최소 fix commit을 만든 뒤, 새 full SHA로 독립 검증을 반복한다. timeout/inconclusive는 PASS가 아니다.
5. 각 판정은 `.omo/start-work/ledger.jsonl`에 Todo, full SHA, DoneClaim, verdict, command 결과, artifact, dirty-worktree 경계를 append한다. 후속 commit은 이전 SHA의 판정을 무효화한다.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | - | 2 | - |
| 2 | 1 | 3–9 | - |
| 3 | 2 | 12,16 | 4–9 |
| 4 | 2 | 11,12,16 | 3,5–9 |
| 5 | 2 | 13–16 | 3,4,6–9 |
| 6 | 2 | 11,12,14–16 | 3–5,7–9 |
| 7 | 2 | 10–13,16 | 3–6,8,9 |
| 8 | 2 | 11–15 | 3–7,9 |
| 9 | 2 | 11,14–16 | 3–8 |
| 10 | 7 | 13,16 | - |
| 11 | 4,6–9 | 12–16 | - |
| 12 | 3,4,6,8,11 | 16 | 13–15 |
| 13 | 5,7,8,10,11 | 16 | 12,14,15 |
| 14 | 5,6,8,9,11 | 16 | 12,13,15 |
| 15 | 5,6,8,9,11 | 16 | 12–14 |
| 16 | 10–15 | 17 | - |
| 17 | 16 | F1–F4 | - |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [ ] 1. XcodeGen 기반 iOS 17 프로젝트와 검증 target 골격 생성
  What to do:
  - 실행 시작 시 `git rev-parse --is-inside-work-tree` 실패를 확인한 뒤 `git init -b main`으로 이 workspace만 새 저장소로 만든다. `.gitignore`에는 `.DS_Store`, Xcode DerivedData, user-specific workspace state, build 산출물만 넣고 `docs/`, `.omo/plans/`, source는 추적한다. 기존 파일 hash를 기록한 후 `chore: establish 마음자로 planning baseline` 초기 commit을 만든다.
  - 실패 우선 증거로 `xcodegen generate --spec iOSApp/project.yml`을 파일 생성 전에 실행해 “spec 없음” 실패를 `<attemptDir>/task-1-red.log`에 캡처한다.
  - `iOSApp/project.yml`, `iOSApp/Configurations/{Base,App-Debug,App-Release,Widget-Debug,Widget-Release,Tests}.xcconfig`, `iOSApp/Maeumjaro.xctestplan`, `iOSApp/MaeumjaroStoreKit.xctestplan`, `iOSApp/Packages/MaeumjaroCore/Package.swift`를 만든다.
  - XcodeGen project에 `Maeumjaro` app, `MaeumjaroWidgetExtension`, `MaeumjaroAppTests`, `MaeumjaroWidgetTests`, `MaeumjaroUITests` target과 shared scheme을 선언한다. app/widget deployment target은 iOS 17.0, supported destination은 iPhone, orientation은 portrait만 허용하고 Swift 6 language mode, warnings-as-errors는 Debug CI/test 구성에서 켠다.
  - 최소 compile 가능한 `iOSApp/Maeumjaro/App/MaeumjaroApp.swift`, `RootView.swift`, `iOSApp/MaeumjaroWidget/MaeumjaroWidgetBundle.swift`, `MaeumjaroWidget.swift`, app/widget `Info.plist`, entitlements, empty asset catalogs를 만든다. app privacy manifest는 `iOSApp/Maeumjaro/Resources/PrivacyInfo.xcprivacy`, widget manifest는 `iOSApp/MaeumjaroWidget/Resources/PrivacyInfo.xcprivacy`로 분리하고 각 target에 정확히 하나씩 포함한다. 두 manifest는 `NSPrivacyTracking=false`, collected data 0, UserDefaults required-reason `1C8F.1`을 선언한다.
  - package에 `MaeumjaroDomain`, `MaeumjaroShared`, `MaeumjaroPersistence`, `MaeumjaroIntents`, 개발 전용 executable `MaeumjaroCoreProbe` target과 대응 test targets를 선언한다. `Package.swift`의 host/test 플랫폼은 `.iOS(.v17)`과 `.macOS(.v14)`이며 macOS는 probe/test host일 뿐 제품 target이 아니다. Probe는 app에 링크하지 않는다.
  - Debug/test target만 `MAEUMJARO_QA_FIXTURES` compile condition을 켜고 Release에는 켜지 않는다. fixture launch argument와 App Group namespace 구현은 이후 Todo가 채우되 이 target boundary를 여기서 고정한다.
  - app/widget bundle ID, App Group, URL scheme을 승인된 값으로 설정한다. Apple Developer Team ID는 비워 로컬 signing-off build가 가능해야 한다.
  Must NOT do: `.pbxproj`를 손으로 편집, 타사 runtime package 추가, `docs/` 수정, signing/team 추정, UI 기능 선구현, 기존 Android 계획을 iOS 계획으로 덮어쓰기.
  Parallelization: Wave 0 | Blocked by: none | Blocks: 2
  References: `.omo/drafts/maeumjaro-ios-implementation.md:54-84`; `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:891-939,953-980`; [Apple App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups); [Apple privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk); [Apple required-reason values](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
  Acceptance criteria:
  - `xcodegen generate --spec iOSApp/project.yml` exits 0 and regeneration produces no semantic project diff.
  - `xcodebuild -list -project iOSApp/Maeumjaro.xcodeproj`가 다섯 target을 보이고 `xcodebuild -showTestPlans -project iOSApp/Maeumjaro.xcodeproj -scheme Maeumjaro`가 `Maeumjaro`, `MaeumjaroStoreKit` 두 plan을 보인다.
  - `xcodebuild build -project iOSApp/Maeumjaro.xcodeproj -scheme Maeumjaro -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` exits 0.
  - `plutil -p`가 exact bundle/App Group/URL identifier, iPhone-only portrait orientation, app/widget별 privacy manifest의 target membership와 `1C8F.1`을 보인다. app/widget entitlements는 이 계획의 shared App Group만 가진다.
  QA scenarios:
  - Auxiliary surface: run `xcodegen generate --spec iOSApp/project.yml && xcodebuild -list -project iOSApp/Maeumjaro.xcodeproj`; PASS iff target/scheme inventory matches this task exactly. Evidence `<attemptDir>/task-1-project-inventory.log`.
  - Failure surface: temporarily feed an invalid deployment target in a copied QA spec, not the source spec; PASS iff XcodeGen/build fails and the production spec remains byte-identical. Preserve copied spec as `<attemptDir>/task-1-invalid-spec.yml`; no deletion.
  Commit: Y | baseline `chore: establish 마음자로 planning baseline`; scaffold `build(ios): create XcodeGen app and widget targets`

- [ ] 2. 공용 값 객체·식별자·repository 계약 동결
  What to do:
  - 먼저 `iOSApp/Packages/MaeumjaroCore/Tests/MaeumjaroDomainTests/IntensityTests.swift`와 `ModelContractTests.swift`에 강도 0/6 거부, 기본 3, source app/widget, 필수 event field, 개발 식별자 equality, `AppSettings`에 intensity가 없음을 작성하고 RED를 캡처한다.
  - `Sources/MaeumjaroDomain/Models/{Intensity,EventSource,InjectionEvent,Phrase,ThemeID,AppSettings}.swift`, `Ports/{EventRepository,SettingsRepository,PhraseRepository,CompletionRecording}.swift`, `Support/{Clock,UUIDGenerator}.swift`를 만든다. `CompletionRecording`은 session ID와 완성 event request를 받아 idempotent 기록 결과를 돌려주는 feature-facing port이며 구현은 Todo 16이 소유한다.
  - `Sources/MaeumjaroShared/Identifiers/AppIdentifiers.swift`에 bundle/widget/App Group/product ID, widget kind `MaeumjaroWidget`, scheme `maeumjaro`를 한 번만 정의한다.
  - `InjectionEvent` 필드는 `id`, `startedAtUTC`, `completedAtUTC`, `createdAtUTC`, `eventLocalDate`, `timezoneOffsetMinutes`, `intensity`, `source`, `phraseID`, `animationDurationMilliseconds`, `interruptedCount`, `appVersion`으로 고정한다.
  - `AppSettings`에는 onboarding, haptic, sound, reduceMotion, phraseTone, `ThemeID`만 두고 intensity를 절대 저장하지 않는다. `ThemeID`는 `quietIvory`, `midnightInk`, `forestMist`의 closed enum이고 기본값은 `quietIvory`다. 현재 강도는 `SharedStrengthStore`만 제공한다.
  Must NOT do: SwiftUI/SwiftData/WidgetKit/StoreKit import를 Domain에 넣기, 범용 DI container, 실제 약물 단위, optional로 계약 누락을 숨기기.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 3–9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:366-410,827-887`; `docs/마음자로_PRD.md:357-396,728-789`
  Acceptance criteria:
  - `swift test --package-path iOSApp/Packages/MaeumjaroCore --filter IntensityTests --filter ModelContractTests`는 구현 전 올바른 assertion 이유로 실패하고 구현 후 exit 0이다.
  - `swift package show-dependencies --package-path iOSApp/Packages/MaeumjaroCore`에서 외부 package가 0개다.
  - Domain source에 `SwiftUI|SwiftData|WidgetKit|StoreKit|AppIntents` import가 없다.
  - model/port contract test가 `AppSettings`에 intensity 필드가 없고 `ThemeID`가 exact 3값/default `quietIvory`이며 모든 app/widget entry가 `SharedStrengthStore`를 요구함을 고정해 이중 원본을 방지한다.
  QA scenarios:
  - Auxiliary surface: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe contracts --intensity 0,1,3,5,6`; PASS iff JSON은 1/3/5만 valid, default 3, source enum 두 값, exact identifier 다섯 개를 출력한다. Evidence `<attemptDir>/task-2-contracts.json`.
  - Malformed input: 같은 probe에 `--intensity abc`를 전달; PASS iff nonzero exit와 `invalid-intensity` 오류이며 event 출력은 없다. Evidence `<attemptDir>/task-2-malformed.log`.
  Commit: Y | `feat(core): define 마음자로 domain contracts`

- [ ] 3. 강도별 의식 reducer와 정확히 한 번 완료 effect 구현
  What to do:
  - `Tests/MaeumjaroDomainTests/RitualReducerTests.swift`에 ready→pressing→paused→resumed→completed, release 정지, background reset, post-completion input 무시, 동일 session completion effect 1회, monotonic clock rollback 내성과 cue schedule을 RED로 작성한다.
  - `Sources/MaeumjaroDomain/Ritual/{IntensityProfile,RitualState,RitualAction,RitualEffect,RitualReducer}.swift`를 구현한다. 첫 press에서 UUID session을 만들고, monotonic elapsed time으로 progress를 계산하며 100% 첫 통과에만 `.persistCompletion`을 방출한다.
  - 강도별 액체량/시간/진행 pulse 수는 `IntensityProfile`의 단일 exhaustive switch/table에 둔다. N개의 진행 threshold는 `k/(N+1)`이고, 최초 press의 start cue와 first completion의 completion cue를 별도 effect로 방출한다. pause/resume에는 start cue가 없고 이미 지난 threshold effect는 재방출하지 않는다. background/scene inactive는 완료 전 ready로 초기화하고 row를 만들지 않는다.
  Must NOT do: wall clock `Date`로 progress 계산, `Task.sleep` 기반 상태 머신, release 시 0으로 reset, reducer에서 SwiftData/haptic/UI 호출, 미완료 event 생성.
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 12,16 | Can parallelize: 4–9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:366-410,414-472,1150-1166`; `docs/마음자로_PRD.md:257-351`; `docs/recording.mp4` 00:04–00:11
  Acceptance criteria:
  - RED suite가 source 부재/behavior mismatch로 실패하고 GREEN suite는 모든 intensity/profile/state/idempotency case를 통과한다.
  - 99.9% release/background는 completion effect 0, 100% 동시 callback 2회는 effect 1이다.
  - intensity 1...5는 각각 progress pulse N회, start cue 1회, completion cue 1회이고 pause/resume/repeated tick으로 지난 cue가 중복되지 않는다.
  - progress 시작 effect는 injected clock 기준 150ms 이내이고 clock이 뒤로 가도 progress가 감소하지 않는다.
  QA scenarios:
  - Auxiliary surface: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe ritual --intensity 3 --actions press,advance:0.9,release,advance:1.0,press,advance:0.9`; PASS iff state trace는 paused에서 고정, resume 후 completed, persist effect count 1이다. Evidence `<attemptDir>/task-3-ritual.json`.
  - Repeated interruption: probe에 `press/release` 20회와 final completion을 전달; PASS iff interruptedCount 20, completion 1, event request 1이다. Evidence `<attemptDir>/task-3-interruptions.json`.
  Commit: Y | `feat(ritual): add deterministic completion state machine`

- [ ] 4. 안전한 100개 문구 카탈로그와 선택 정책 구현
  What to do:
  - `Tests/MaeumjaroDomainTests/PhraseSelectorTests.swift`와 `PhraseSafetyTests.swift`에 최근 10개 제외, 같은 category 3연속 금지, tone/intensity filter, seeded determinism, 전부 제외된 후보 fallback, stable ID, 금지어·판단어 검사를 RED로 만든다.
  - `Sources/MaeumjaroDomain/Phrases/PhraseSelector.swift`와 `Sources/MaeumjaroPersistence/Resources/PhraseCatalog.ko.json`을 만든다. 카탈로그는 욕구/행동 분리, 충동의 일시성, 자기결정권, 주의 전환, 비판단 태도의 5개 category와 부드러움/중립/단호함 tone을 균형 있게 포함한다.
  - 최소 100개 항목 각각 `phraseID`, `category`, `tone`, `minimumIntensity`, `maximumIntensity`, `textKO`, `safetyStatus=approved`, `contentVersion=1`을 갖는다. 카탈로그와 history가 후보를 모두 막으면 번들 safe fallback을 반환한다.
  Must NOT do: HTML의 25개 문구 복사, 직전 1개만 제외, 성공/실패/의지력/식욕 감소/체중/치료/약물 효과 문구, 사용자 custom phrase.
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 11,12,16 | Can parallelize: 3,5–9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:521-616`; `docs/마음자로_PRD.md:153-170,315-325`; `docs/maeumjaro_interactive_product_plan_v1.html:1576-1612,1842-1848`
  Acceptance criteria:
  - JSON schema decode와 exact 100+ unique IDs, 5 category coverage, 3 tone coverage, approved-only selection이 GREEN이다.
  - 10개 history와 2개 category tail fixture에서 반환 phrase가 두 제약을 모두 만족한다.
  - 금지어 fixture를 mutation으로 삽입하면 safety test가 RED가 되고 원복 후 GREEN이다; production catalog는 모든 안전 검사 통과다.
  QA scenarios:
  - Auxiliary surface: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe phrases --intensity 5 --tone neutral --seed 42 --history fixture:last10`; PASS iff 선택 ID가 last10 밖이고 category tail과 다르며 safetyStatus approved다. Evidence `<attemptDir>/task-4-phrase-selection.json`.
  - Exhausted pool: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe phrases --fixture all-excluded`; PASS iff stable safe fallback ID가 반환되고 empty/crash가 아니다. Evidence `<attemptDir>/task-4-phrase-fallback.json`.
  Commit: Y | `feat(content): add safe completion phrase policy`

- [ ] 5. 시간대 안전 집계·30/52주 access policy 구현
  What to do:
  - `Tests/MaeumjaroDomainTests/{AnalyticsAggregatorTests,FeatureAccessPolicyTests}.swift`에 local-date count/sum, active-day average, empty 0, heatmap 고정 bucket, 3시간 분포, Monday-first weekday, 표본 threshold, 4주 비교, Free 30일/Pro 52주 경계를 RED로 작성한다.
  - `Sources/MaeumjaroDomain/Analytics/{AnalyticsModels,AnalyticsAggregator,HeatmapScale}.swift`, `Access/{HistoryWindow,FeatureAccessPolicy}.swift`를 구현한다.
  - 완료 당시 `eventLocalDate`와 offset을 보존해 재집계한다. Free window는 오늘 포함 30 local dates, Pro heatmap은 현재 주 월요일을 포함한 52주이며 초기 viewport는 최근 16주다.
  - count bucket은 `0/1/2/3-4/5-6/7+`, intensity sum bucket은 `0/1-3/4-7/8-12/13-19/20+`. 0–4건은 표본 부족, 5–9건은 사실 요약만, 10+는 패턴 문장, 30+만 최근4주/이전4주 비교다.
  Must NOT do: `/112` 고정 분모, 현재 timezone으로 과거 local date 재작성, streak/성공/식욕/질환 추론, entitlement에 따라 row 삭제.
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 13–16 | Can parallelize: 3,4,6–9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:620-824,1315-1336`; `docs/Screenshot 2.jpg`; `docs/Screenshot 3.jpg`; `docs/maeumjaro_interactive_product_plan_v1.html:1991-2008`
  Acceptance criteria:
  - fixtures include 23:59 start→00:00 completion, leap day, DST, UTC-12, UTC+14, same UTC/different stored offset, timezone change, clock rollback, future event, empty set.
  - 모든 fixture 결과가 expected local-day/week/bucket과 일치하고 active-day denominator가 zero일 때 0이다.
  - Free policy가 31일 전 결과를 숨겨도 repository row count는 변하지 않고, Pro 전환 시 기존 52주 row가 즉시 집계된다.
  QA scenarios:
  - Auxiliary surface: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe analytics --fixture timezone-boundaries --access free`; PASS iff JSON에 최근30일만 있고 average denominator가 activeDays다. Evidence `<attemptDir>/task-5-free-analytics.json`.
  - Same fixture with `--access pro`; PASS iff 52주/초기16주 viewport/3시간·요일·강도 분포와 sample threshold가 exact expected다. Evidence `<attemptDir>/task-5-pro-analytics.json`.
  Commit: Y | `feat(analytics): add local-date aggregation and access policy`

- [ ] 6. 앱 전용 SwiftData V1·migration·repository·삭제 구현
  What to do:
  - `Tests/MaeumjaroPersistenceTests/{ModelContainerFactoryTests,EventRepositoryTests,SettingsRepositoryTests,PhraseCatalogSeederTests,MigrationPlanTests,EventDeletionServiceTests}.swift`에 in-memory CRUD, incomplete 0, duplicate UUID 1, intensity 없는 settings singleton, seed idempotency, V1 reopen, 개별/전체 deletion 취소·확정, store backup exclusion을 RED로 작성한다.
  - `Sources/MaeumjaroPersistence/Schema/{MaeumjaroSchemaV1,MaeumjaroMigrationPlan}.swift`, `Store/ModelContainerFactory.swift`, `Mapping/InjectionEventMapper.swift`, `Repositories/{SwiftDataEventRepository,SwiftDataSettingsRepository,SwiftDataPhraseRepository}.swift`, `Seed/PhraseCatalogSeeder.swift`, `Maintenance/EventDeletionService.swift`를 구현한다.
  - production store는 app sandbox Application Support 아래에 두고 App Group에 두지 않는다. main app만 container open/migration한다. store directory 생성 직후 `URLResourceKey.isExcludedFromBackup=true`를 설정하고 read-back으로 확인한다. V1 entity는 event, settings, phrase 세 개이며 settings에는 intensity가 없다. future schema는 새 VersionedSchema와 ordered stage로만 추가한다.
  - container open/migration 실패는 store를 지우지 않고 typed error를 app에 반환한다. 삭제는 확인 token 이후 선택 event 또는 전체 event만 transactionally 삭제하고 settings/phrases는 보존한다.
  Must NOT do: widget/intents target에 persistence product 연결, migration 실패 시 file 삭제/reset, App Group DB, entitlement를 SwiftData boolean 원본으로 저장, settings 삭제.
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 11,12,14–16 | Can parallelize: 3–5,7–9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:827-980,1006-1017,1150-1177`; `docs/마음자로_PRD.md:357-396,523-558`
  Acceptance criteria:
  - in-memory suite와 preserved file-backed migration fixture 모두 GREEN이다. migration fixture DB는 `<attemptDir>/task-6-migration-fixture/`에 증거로 남기고 삭제하지 않는다.
  - duplicate session UUID concurrent insert 결과 row count 1; incomplete/cancel/background action 결과 0.
  - event deletion confirmation 후 events 0, settings/phrases unchanged; cancel path는 모든 count unchanged.
  - 선택 event 삭제는 해당 ID 한 행만 줄이고 나머지 event/settings/phrases는 byte-equivalent이며, production store directory의 backup exclusion read-back이 true다.
  - static dependency audit에서 Widget/Intents가 `MaeumjaroPersistence`를 링크/import하지 않는다.
  QA scenarios:
  - Auxiliary surface: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe persistence --store <attemptDir>/task-6-probe.sqlite --scenario complete-twice`; PASS iff parsed store dump는 row 1과 exact fields를 보인다. Evidence `<attemptDir>/task-6-store-dump.json`.
  - Failure surface: 같은 probe에 unsupported schema fixture를 읽힌다; PASS iff nonzero typed `migration-unsupported`, source store hash unchanged, 자동 삭제/재생성이 없다. Evidence `<attemptDir>/task-6-migration-failure.json`.
  Commit: Y | `feat(storage): add SwiftData event repository and migration plan`

- [ ] 7. App Group 최소 스냅샷과 딥링크 계약 구현
  What to do:
  - `Tests/MaeumjaroSharedTests/{SharedStrengthStoreTests,WidgetSnapshotStoreTests,MaeumjaroDeepLinkTests}.swift`에 valid/default/corrupt/out-of-range/version mismatch, writer별 Data blob, read-back, stale summary date, URL source parse, URL 강도 무시를 RED로 만든다.
  - `Sources/MaeumjaroShared/Storage/AppGroupDefaults.swift`, `Strength/{SharedStrengthEnvelope,SharedStrengthStore}.swift`, `Widget/{TodaySummarySnapshot,TodaySummaryStore,WidgetThemeSnapshot,WidgetThemeStore}.swift`, `Routing/MaeumjaroDeepLink.swift`를 구현한다.
  - key는 `shared.strength.v1`, `shared.todaySummary.v1`, `shared.widgetTheme.v1` 세 개다. 각 blob에 schemaVersion/updatedAt/writer를 넣고 서로 다른 owner가 다른 key를 쓴다. 손상/unknown version은 덮어쓰지 않고 UI fallback 3/0/default theme를 반환한다.
  - 딥링크는 `maeumjaro://inject?source=widget|app`만 허용한다. 강도 query가 있어도 무시하고 이벤트는 생성하지 않는다.
  - `MAEUMJARO_QA_FIXTURES`/`#if DEBUG`에서만 `-MaeumjaroFixtureID <uuid>`를 `qa.activeFixtureID`에 쓰고 `qa.<fixtureID>.*` key prefix를 만드는 namespace adapter를 제공한다. Release에는 이 문자열과 adapter symbol이 없어야 하며 production key는 테스트가 쓰지 않는다.
  Must NOT do: event/history/phrase text/entitlement transaction을 App Group에 저장, 여러 key를 하나의 read-modify-write 객체로 병합, URL strength 신뢰, 외부 scheme/host 허용.
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 10–13,16 | Can parallelize: 3–6,8,9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:333-362,953-968`; `docs/마음자로_PRD.md:216-251,728-789`; [Apple WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy)
  Acceptance criteria:
  - test suite는 unique test suite name을 사용하고 production App Group을 건드리지 않는다.
  - 두 privacy manifest의 UserDefaults declaration은 App Group 전용 Apple reason `1C8F.1`이고, package/source scan에서 다른 UserDefaults reason을 요구하는 접근이 발견되면 실제 사용에 맞춰 manifest test를 RED로 갱신한다.
  - valid sequential app/intent writes에서 last successful read-back value가 1...5이고 corrupt/version mismatch는 3 fallback이다.
  - summary date가 현재 local date가 아니면 count/sum 0으로 읽히며 원본 blob은 보존된다.
  QA scenarios:
  - Auxiliary surface: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe shared --suite group.com.yeoreum.maeumjaro.qa.task7 --writes app:2,intent:5 --read app,widget`; PASS iff 두 reader가 5와 동일 revision을 출력한다. Evidence `<attemptDir>/task-7-shared.json`.
  - Malformed blob: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe shared --fixture corrupt-v2`; PASS iff fallback 3/0/default, source hash unchanged, event fields absent. Evidence `<attemptDir>/task-7-corrupt.json`.
  Commit: Y | `feat(shared): add App Group snapshots and deep links`

- [ ] 8. 네이티브 디자인 토큰·독립 브랜드 자산·안전 manifest 구현
  What to do:
  - `iOSApp/Maeumjaro/DesignSystem/{DesignTokens,ThemePalette,IntensityControlStyle,HeatmapColorScale}.swift`, app/widget asset catalogs, `iOSApp/Brand/AssetManifest.json`, `iOSApp/Brand/README.md`를 만든다.
  - 시스템 글꼴만 사용한다. Free theme ID `quietIvory`는 background `#F5F1E8`, surface `#FFFCF7`, ink `#1F2328`, accent `#4F7D75`, highlight `#E9856B`로 고정한다. Pro theme ID `midnightInk`는 `#0E1418/#182127/#F2F4EF/#73B7A9/#F09A7C`, `forestMist`는 `#EEF3ED/#FAFCF8/#1D2B24/#3E7460/#C77C67`의 같은 token 순서를 사용한다. 시스템 dark/high-contrast variant는 이 semantic token에서 파생하되 참고 JPG의 보라색 gradient를 복제하지 않는다.
  - 의식 오브젝트는 code-defined Shape/Canvas layer specification(외곽, chamber, liquid mask, plunger, highlight, reduced-motion fallback)로 만들고 실제 주사기 펜의 비율·버튼·눈금·라벨을 모방하지 않는다.
  - 앱 아이콘은 필수이며 worker는 `imagegen` skill을 읽고 참조 이미지 없이 독립 생성해 `iOSApp/Maeumjaro/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`와 `Contents.json`을 만든다. 완료음은 독립 합성한 `iOSApp/Maeumjaro/Resources/Audio/ritual-complete-v1.caf`, 편집 가능한 원본은 `iOSApp/Brand/Audio/ritual-complete-v1-source.wav`로 고정하며 Todo 12는 이 CAF만 소비한다.
  - `AssetManifest.json`은 icon/chime 및 모든 release asset에 assetID/version/authoring tool/date/license/source path/SHA-256, `implementationReviewStatus`, `releaseReviewStatus`를 기록한다. 독립 verifier가 implementation review를 PASS할 수 있지만 공개 자산/상표 승인이 없으면 release status는 pending이고 release asset 승인으로 가장하지 않는다.
  - `iOSApp/MaeumjaroAppTests/BrandSafetyTests.swift`에 forbidden user-visible term, asset manifest completeness, duplicated reference hash 검사를 먼저 RED로 만든다.
  Must NOT do: docs 파일에서 crop/extract/trace, 특정 의료제품 외형, 외부 폰트/이미지 package, pixel-perfect HTML/JPG 복제, 색상만으로 상태 표시.
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 11–15 | Can parallelize: 3–7,9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:474-499,1021-1083,1136-1144`; `docs/마음자로_PRD.md:795-963`; `docs/Screenshot 2.jpg`; `docs/Screenshot 3.jpg`; `docs/recording.mp4`
  Acceptance criteria:
  - 필수 app icon과 완료음이 exact path에 있고 manifest의 모든 release asset이 source/license/hash/two-stage review status를 가지며 `docs/` 파일 hash와 일치하지 않는다.
  - 일반 text contrast 4.5:1+, large text 3:1+, 모든 interaction min 44×44pt 토큰을 자동 검사한다.
  - forbidden term mutation은 test RED, 원복 후 GREEN; 허용어 `가상`, `앱 안의 연출`, `자기조절 의식`, `패턴 기록`은 차단하지 않는다.
  QA scenarios:
  - Visual artifact: `view_image`로 app icon 1024px, light/dark/high-contrast ritual preview, small/medium widget preview PNG를 원본 해상도로 열어 검토한다. PASS iff 독립 심볼 체계, 상태 비색상 cue, 의료제품 유사 요소 없음. Evidence `<attemptDir>/task-8-brand-review.json`과 PNG들.
  - Reference separation: `find docs iOSApp/Brand iOSApp/Maeumjaro/Resources/Assets.xcassets iOSApp/MaeumjaroWidget/Resources/Assets.xcassets -type f -print0 | xargs -0 shasum -a 256 | LC_ALL=C sort` 결과를 비교; PASS iff production bitmap/audio가 docs media hash와 일치하지 않고 docs baseline hash가 unchanged다. Evidence `<attemptDir>/task-8-hashes.log`.
  Commit: Y | `feat(design): add independent native visual system`

- [ ] 9. StoreKit 2 비소모성 Pro 권한 원본과 로컬 상품 구성 구현
  What to do:
  - `iOSApp/MaeumjaroAppTests/{StoreKitPurchaseClientTests,ProEntitlementStoreTests}.swift`에 product lookup, verified purchase, cancel/fail/pending/unverified, repeated updates, revoke/refund, restore, Free fail-closed를 RED로 작성한다.
  - `iOSApp/Maeumjaro/Infrastructure/Commerce/{StoreKitPurchaseClient,ProEntitlementStore}.swift`, `iOSApp/Maeumjaro/Resources/Maeumjaro.storekit`를 구현한다. 상품은 `com.yeoreum.maeumjaro.pro`, non-consumable, 표시 문구는 1회 구매다.
  - launch에서 verified `Transaction.currentEntitlements`, 실행 중 `Transaction.updates`를 관찰하고 검증된 transaction만 unlock한다. 성공 purchase transaction은 finish하며 restore는 `AppStore.sync()` 후 entitlement를 다시 계산한다.
  - entitlement store는 verified Pro→Free/loading/error/unverified/revoked 전환을 포함한 idempotent state stream을 app composition에 제공한다. App Group이나 widget을 직접 import하지 않고, Todo 16이 이 신호를 받아 Free theme snapshot으로 되돌린다.
  - local cache는 loading/error UX용 파생값일 뿐 access 원본이 아니다. offline 시 마지막 검증 entitlement는 StoreKit API 결과 범위 안에서만 사용하며 user-writable boolean으로 우회하지 않는다.
  Must NOT do: subscription/ads, purchase 전 unlock, unverified transaction 승인, 이벤트 삭제/업로드, App Group에 entitlement 복사, App Store Connect configured라고 주장.
  Parallelization: Wave 2 | Blocked by: 2 | Blocks: 11,14–16 | Can parallelize: 3–8
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:1315-1336`; `docs/마음자로_PRD.md:588-648`; [Apple StoreKit API choice](https://developer.apple.com/documentation/storekit/choosing-a-storekit-api-for-in-app-purchases); [Transaction.currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
  Acceptance criteria:
  - StoreKitTest/local configuration에서 success/cancel/fail/pending/unverified/revoke/restore 모두 exact expected entitlement를 반환한다.
  - app 재실행과 repeated update에도 entitlement transition이 idempotent하며 Free/Pro가 event row count를 바꾸지 않는다.
  - verified Pro→revoked/unverified/Free transition이 한 번의 downgrade state를 방출하고, app-side consumer가 stale Pro theme를 정리할 수 있다.
  - StoreKit file에 상품 1개, exact product ID, non-consumable type, 한국어/영어 이름이 있고 subscription group은 없다.
  QA scenarios:
  - Auxiliary configuration surface: `plutil -convert json -o - iOSApp/Maeumjaro/Resources/Maeumjaro.storekit`을 parsed inspection; PASS iff exact one non-consumable product, no subscription group, exact identifier다. Evidence `<attemptDir>/task-9-storekit-config.json`.
  - Transaction sequence probe: `xcodebuild test -project iOSApp/Maeumjaro.xcodeproj -scheme Maeumjaro -destination 'platform=iOS Simulator,id=<actual-iPhone-UDID>' -only-testing:MaeumjaroAppTests/ProEntitlementStoreTests -resultBundlePath <attemptDir>/task-9-storekit.xcresult`; tests 외에 xcresult transaction attachment를 `xcresulttool`로 추출해 verified/unverified/revoked state trace가 expected인지 확인한다. Evidence `<attemptDir>/task-9-entitlement-trace.json`.
  Commit: Y | `feat(pro): add verified non-consumable entitlement`

- [ ] 10. 강도 변경 App Intent의 저장·read-back 계약 구현
  What to do:
  - `Tests/MaeumjaroIntentsTests/SetStrengthIntentTests.swift`에 ± 경계, 직접 1~5, corrupt fallback, persist/read-back 순서, no-op revision 보존, write failure, DB/WidgetCenter dependency 부재를 RED로 작성한다.
  - `Sources/MaeumjaroIntents/{MaeumjaroAppIntentsPackage,SetStrengthIntent,IntentDependencies}.swift`를 구현한다. Intent parameter는 exact target 또는 delta를 명시하며 결과는 항상 1...5로 clamp가 아니라 validate한다. 1에서 -/5에서 +는 no-op 성공이다.
  - `perform()`은 shared store 저장을 await하고 read-back으로 확인한 뒤 반환한다. interactive widget은 intent 반환 뒤 WidgetKit이 timeline update를 요청하는 시스템 계약을 사용하므로 직접 `WidgetCenter.reloadTimelines`를 호출하지 않는다. 실패 시 이전 값 유지, 사용자에게 실패 result를 반환한다. 앱을 여는 intent가 아니므로 `openAppWhenRun=false`다.
  - app/extension 모두 같은 package product를 링크하며 production dependency는 App Group strength store 하나뿐이다.
  Must NOT do: SwiftData/WidgetKit/WidgetCenter import·link, explicit timeline reload, fire-and-forget 저장, 앱 열기, 강도 URL 전달, 네트워크 요청.
  Parallelization: Wave 3 | Blocked by: 7 | Blocks: 13,16
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:284-362`; `docs/마음자로_PRD.md:194-251,728-789`; [Apple interactive widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities); [Apple App Intents Testing](https://developer.apple.com/documentation/appintentstesting)
  Acceptance criteria:
  - fake dependency trace가 `persist → readBack → return` 순서를 보이고 persist/read-back failure는 explicit failure다.
  - 1/-와 5/+는 value/revision을 바꾸지 않고 성공하며 malformed target은 explicit failure다.
  - dependency graph와 source scan에서 `MaeumjaroPersistence|SwiftData|WidgetKit|WidgetCenter`가 0건이다.
  QA scenarios:
  - Auxiliary surface: `swift run --package-path iOSApp/Packages/MaeumjaroCore MaeumjaroCoreProbe intent --current 4 --delta 1 --trace`; PASS iff JSON 순서가 persist(5), readBack(5), return(success)이고 explicit reload가 없다. Evidence `<attemptDir>/task-10-intent-trace.json`.
  - Failure surface: 같은 probe에 `--fail-write`; PASS iff current 4와 revision 유지, typed error, WidgetCenter invocation 0이다. Evidence `<attemptDir>/task-10-intent-failure.json`.
  Commit: Y | `feat(widget): add shared strength App Intent`

- [ ] 11. 앱 셸·온보딩·설정·안전 진입점 구현
  What to do:
  - UI 전 RED로 현재 placeholder app을 실제 Simulator에서 열어 온보딩/2-tab/settings 부재를 `<attemptDir>/task-11-red.png`로 캡처한다.
  - Todo 1의 placeholder `iOSApp/Maeumjaro/App/{MaeumjaroApp,RootView}.swift`를 이 Todo가 처음 이어받아 shell에 연결한다. `App/{AppShellDependencies,AppRouter,AppRoute,AppShellView,PersistenceFailureView,QAFixtureConfiguration}.swift`, `Features/Onboarding/{OnboardingView,OnboardingViewModel}.swift`, `Features/Home/{HomeView,HomeViewModel}.swift`, `Features/Settings/{SettingsView,SettingsViewModel,WidgetHelpView,SafetyNoticeView}.swift`, `Resources/Localizable.xcstrings`를 구현한다. `AppShellDependencies`는 실제 settings repository와 shared strength store만 조립하고 Todo 16에서 full `AppCompositionRoot`로 대체된다. `QAFixtureConfiguration`은 `MAEUMJARO_QA_FIXTURES` 안에서만 compile된다.
  - first launch 6단계는 제품 목적→3단계 사용법→강도 선택 기본3→햅틱/사운드OFF/동작줄이기→비의료 면책→skip 가능한 위젯 안내다. 완료 뒤 `기록`/`설정` 두 탭으로 진입한다.
  - 기록 탭 상단에 앱 source 의식 route를 요청하는 버튼을 두되 Todo 16 전에는 명시적 준비중 placeholder를 보여준다. `AppRouter`는 typed route만 받고 URL parsing/주입은 Todo 16 `DeepLinkHandler`가 소유한다. persistence open 실패는 store를 삭제하지 않고 재시도/지원 화면을 보인다.
  - settings에 기본 강도, 햅틱, 사운드, 앱+시스템 Reduce Motion, 문구 톤, 위젯 안내, Pro, 데이터 관리, 면책을 노출한다. 저장은 즉시 repository에 반영하되 기본 강도는 App Group strength가 단일 원본이다.
  - 온보딩과 기록 화면에는 사용자가 닫을 때까지 남는 정적 `위젯 추가 방법` banner를 제공하고 설정에는 도움말을 항상 둔다. widget 설치 여부를 감지하거나 미설치 경고라고 표현하지 않는다.
  - Debug/test launch는 exact 형식 `-MaeumjaroFixtureID <uuid> -MaeumjaroFixture <name>`을 파싱해 fixture별 store/App Group namespace를 선택한다. entitlement override는 StoreKit test plan에서만 제공하고 일반 Release launch는 이를 인식하지 않는다.
  - UI 완료 후 `iOSApp/MaeumjaroUITests/OnboardingUITests.swift`, `iOSApp/MaeumjaroAppTests/{AppRouterTests,SettingsViewModelTests}.swift`를 추가한다.
  Must NOT do: 권한 요청/로그인/건강 설문, 자동 widget 설치, 딥링크 query 강도 신뢰, persistence failure 시 reset, 3번째 탭, 외부 폰트.
  Parallelization: Wave 4a | Blocked by: 4,6–9 | Blocks: 12–16
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:194-280,984-1017`; `docs/마음자로_PRD.md:52-170,795-834`; `docs/maeumjaro_interactive_product_plan_v1.html:1212-1224`
  Acceptance criteria:
  - 신규 설치 fixture에서 6단계 순서, 기본 강도 3, sound false, skip 가능한 widget 안내, permission prompt 0이다.
  - onboarding 완료 재실행은 기록 탭으로 바로 가며 settings의 값이 유지된다.
  - widget 안내 banner dismissal은 유지되고 설정 도움말은 계속 접근 가능하며, 설치 상태를 나타내는 문구/API call은 없다.
  - typed app-source request는 준비중 placeholder route에 도달하고 URL/deep-link parsing은 이 Todo에서 주장하지 않는다.
  - Accessibility Extra Extra Large에서도 면책/버튼이 잘리지 않고 모든 control은 semantic label/value/hint를 가진다.
  QA scenarios:
  - Computer-use: `xcrun simctl launch booted com.yeoreum.maeumjaro --args -MaeumjaroFixtureID <new-uuid> -MaeumjaroFixture empty`로 연 뒤 `let simulator = await cua.getApp("Simulator");`로 `시작`, `다음`, 강도 `5`, `확인`, `나중에`를 accessibility label로 순서대로 조작한다. 각 단계 뒤 `xcrun simctl io booted screenshot <attemptDir>/task-11-onboarding-<step>.png`; PASS iff 6단계, no permission prompt, 기록 탭 도착, 강도5 유지다.
  - Shell route: 기록 탭의 `의식 시작`을 탭한다. PASS iff 준비중 placeholder와 돌아가기 control이 보이고 event/summary는 0이며, 실제 ritual/deep-link 완료를 주장하지 않는다. Evidence `<attemptDir>/task-11-shell-route.png`와 router trace.
  Commit: Y | `feat(app): add onboarding shell and settings`

- [ ] 12. 네이티브 길게 누르기 의식·애니메이션·감각·완료 화면 구현
  What to do:
  - UI 전 RED로 `maeumjaro://inject?source=app` 실행 시 의식 화면이 없는 상태를 영상/스크린샷으로 캡처한다.
  - `Features/Ritual/{RitualView,RitualViewModel,RitualAccessibilityContent,InjectionCanvas,LiquidMask,RitualCompletionView,HapticEngine,SoundEngine}.swift`와 대응 app tests를 구현한다. ViewModel은 Todo 2의 `CompletionRecording` port만 알고 tests에서는 fake recorder를 사용한다. `RitualAccessibilityContent`가 view가 소비할 label/value/hint 문자열을 순수 값으로 만든다. 실제 persistence/projection coordinator와 UI accessibility tree 검증은 Todo 16만 소유한다.
  - `DragGesture(minimumDistance:0)`/명시적 gesture phase를 reducer action에 연결하고 `TimelineView(.animation)`이 보내는 tick마다 injected `ContinuousClock`의 monotonic elapsed를 reducer에 전달해 progress를 그린다. progress 하나가 liquid height, plunger, highlight, percentage, haptic thresholds의 원본이다.
  - ready/pressing/paused/resumed/background-reset/saving/completed state마다 정확한 안내 문구를 표시한다. 완료 effect 수신 시 입력을 차단하고 `CompletionRecording`을 같은 session ID로 한 번 호출해 결과가 성공일 때만 completed 화면으로 전환한다.
  - 햅틱은 최초 press start cue 1회, `k/(N+1)`의 progress pulse N회, 최초 완료 completion cue 1회다. pause에는 cue가 없고 resume은 start cue를 반복하지 않으며 crossed threshold를 replay하지 않는다. 앱/시스템 OFF 또는 unsupported이면 모든 cue가 0회다. 시스템 또는 앱 Reduce Motion이면 bubble/glow/scale/bounce를 제거하고 linear liquid/number는 유지한다. sound 기본 off이며 exact `iOSApp/Maeumjaro/Resources/Audio/ritual-complete-v1.caf`만 사용한다.
  - 완료 화면은 `강도 N 가상 주입 완료`, `자동 기록 HH:MM`, 안전 문구, `다시 실행`, `기록 보기`를 제공하고 VoiceOver live region은 한 번만 읽는다.
  Must NOT do: MP4/GIF/Rive, 실제 제품 외형, progress polling sleep, 완료 전 저장, 햅틱/색상/모션만으로 상태 전달, `mg`/처방/효능 표현.
  Parallelization: Wave 4b | Blocked by: 3,4,6,8,11 | Blocks: 16 | Can parallelize: 13–15
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:414-517,521-552,1136-1166`; `docs/마음자로_PRD.md:257-396,654-725`; `docs/recording.mp4` 00:04–00:11
  Acceptance criteria:
  - component harness의 press action 주입 후 visual progress state 생성이 150ms 이내이고 release 시 exact pause, re-press resume, background before 100% fake completion 0, first 100% fake completion 1이다. 실제 touch-to-visual latency와 DB row는 Todo 16에서 검증한다.
  - intensity 1/5의 initial fill, duration, progress pulse 1/5회와 별도 start/completion cue가 profile과 일치한다. pause/resume 중복 cue가 없고 haptics/sound off 경로에서도 같은 시각·텍스트 완료가 가능하다.
  - completion double callback, 빠른 다시 실행, scene transition 경합에서도 fake `CompletionRecording` 호출이 session당 1회다. 실제 row/projection exactly-once는 Todo 16에서 검증한다.
  - Reduce Motion, maximum Dynamic Type, dark/light component render에서 progress와 완료를 텍스트/숫자로 이해할 수 있다. 실제 VoiceOver tree/focus는 Todo 16/17에서 판정한다.
  QA scenarios:
  - Component surface: `RitualView`를 fake clock/`CompletionRecording`/haptic/sound로 구동하는 app unit test가 ready, 50% pressing, paused, saving, completed를 `ImageRenderer` PNG로 출력한다. PASS iff pause 숫자가 고정되고 resume progress가 연속이며 fake completion 호출 1회다. Evidence `<attemptDir>/task-12-ritual-states-*.png`와 state trace JSON.
  - Lifecycle contract: reducer+ViewModel harness가 99% scene inactive를 주입한다. PASS iff ready reset, 완료 문구 없음, fake completion call 0이다. 실제 Simulator Home/foreground와 repository dump는 Todo 16에서 수행한다. Evidence `<attemptDir>/task-12-background-trace.json`.
  - Accessibility component: Reduce Motion true+haptics false/sound false 환경의 ready/progress/completed view를 최대 Dynamic Type로 `ImageRenderer` 출력하고 `RitualAccessibilityContent` 값을 JSON으로 기록한다. PASS iff nonessential motion cue 0, haptic/sound trace 0, liquid/percentage/text/complete가 보이고 각 state의 exact label/value/hint 모델이 비어 있지 않다. 실제 XCTest accessibility tree/focus는 Todo 16/17에서 검증한다. Evidence `<attemptDir>/task-12-reduced-motion.png`와 `<attemptDir>/task-12-accessibility-content.json`.
  Commit: Y | `feat(ritual): build native hold-to-complete experience`

- [ ] 13. 소형·중형 WidgetKit UI와 최신 상태 동기화 구현
  What to do:
  - UI 전 RED로 widget gallery에서 마음자로 widget이 없거나 placeholder인 상태를 캡처한다.
  - `iOSApp/MaeumjaroWidget/Timeline/{MaeumjaroTimelineEntry,MaeumjaroTimelineProvider}.swift`, `Views/{SmallWidgetView,MediumWidgetView,WidgetIntensityControl,WidgetAccessibilityContent}.swift`, bundle/widget source와 `iOSApp/MaeumjaroWidgetTests/{TimelineProviderTests,WidgetSnapshotTests}.swift`를 구현한다. `WidgetAccessibilityContent`가 widget view가 소비할 label/value/hint를 순수 값으로 제공한다.
  - `StaticConfiguration`으로 small/medium만 지원한다. small은 오늘 요약/강도/−/시작/+; medium은 오늘 요약/강도 1~5 직접 선택/큰 시작 버튼이다. 버튼은 Todo 10 intent, 시작은 `Link(maeumjaro://inject?source=widget)`다.
  - provider는 strength/today/theme blob만 읽는다. summary date가 오늘이 아니면 0으로 보이고 next local midnight 이후 timeline을 요청한다. full event DB/StoreKit에 접근하지 않는다.
  - 민감 요약에는 적절한 privacy redaction/placeholder를 제공한다. 이 Todo는 intent read-back 직후 fake provider가 새 entry를 만드는 계약까지만 검증한다. 실제 WidgetKit post-intent timing과 완료·삭제·테마/entitlement의 app-side targeted reload는 Todo 16/17만 검증한다.
  Must NOT do: widget animation, network, SwiftData, automatic widget installation, URL intensity, 모든 timeline reload, medium 이외 family 확장.
  Parallelization: Wave 4b | Blocked by: 5,7,8,10,11 | Blocks: 16 | Can parallelize: 12,14,15
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:284-362,953-968,1180-1207`; `docs/마음자로_PRD.md:176-251,728-789`; `docs/recording.mp4` 00:00–00:04
  Acceptance criteria:
  - generic build와 widget tests GREEN; supported families exactly small/medium; extension binary에 persistence/storekit dependency 0.
  - initial missing/corrupt state는 strength3/today0, 1에서 - disabled, 5에서 + disabled, multi-instance snapshot 값 동일이다.
  - fake intent→shared read-back→fake provider entry→component render 순서와 값이 정확하고 explicit WidgetCenter invocation은 0이다. 실제 WidgetKit 갱신 시간, app-side reload, 실제 multi-instance 갱신은 Todo 16/17 acceptance에만 속한다.
  QA scenarios:
  - Component surface: deterministic strength/today/theme entries로 small/medium view를 light/dark, strength 1/5, summary 0/nonzero에서 `ImageRenderer` PNG로 출력하고 `WidgetAccessibilityContent` 값을 JSON으로 기록한다. PASS iff bounds disabled, exact values, 44pt layout, privacy placeholder와 nonempty label/value/hint 모델이 정확하다. 실제 accessibility tree/focus는 Todo 16/17에서 검증한다. Evidence `<attemptDir>/task-13-widget-<family>-<state>.png`와 `<attemptDir>/task-13-accessibility-content.json`.
  - Timeline/intent harness: fake App Group을 intent로 4→5 write/read-back한 뒤 fake provider entry를 직접 요청한다. PASS iff trace가 `persist(5)→readBack(5)→providerEntry(5)→render(5)`, explicit WidgetCenter invocation 0이다. 실제 WidgetKit timing, gallery 추가, 다중 instance, cold widget start는 Todo 16/17으로 이동한다. Evidence `<attemptDir>/task-13-timeline-intent.json`.
  Commit: Y | `feat(widget): add small and medium interactive widgets`

- [ ] 14. 무료 기록·Pro 52주 히트맵·패턴 화면 구현
  What to do:
  - UI 전 RED로 fixture launch에서 요약/기록/heatmap이 없는 화면을 캡처한다.
  - `Features/History/{HistoryView,HistoryViewModel,HistoryAccessibilityContent,SummaryCardsView,RecentEventsView,HeatmapGrid,DailyDetailSheet,AdvancedAnalyticsView,DistributionChart,InsightCard}.swift`와 app tests를 구현한다. `HistoryAccessibilityContent`는 카드/날짜/heatmap/chart/detail이 소비할 label/value/hint를 순수 값으로 제공한다.
  - Free는 오늘 count/intensity sum/active-day average, 최근 events, 오늘 포함 최근30일 day grid/list/date detail을 제공한다. Pro 잠금 카드에는 52주·상세 패턴 범위만 설명하고 값을 미리 노출하지 않는다.
  - Pro는 Monday-based 52주 가로 스크롤 heatmap을 열고 초기 viewport는 최근16주다. count/intensity toggle, date detail, 3시간·요일·강도 분포, sample threshold, 4주 비교를 Swift Charts/SwiftUI로 렌더링한다.
  - heatmap cell은 color 외 exact date/count/sum accessibility value를 제공한다. 데스크톱 screenshot을 pixel copy하지 않고 iPhone vertical cards/horizontal heatmap/bottom sheet로 적응한다.
  - 날짜 상세 event menu는 `삭제`만 제공한다. 확인 전 cancel은 no-op이고 확인 시 선택 ID만 삭제 service에 요청하며, 자동 기록 field를 수정하는 UI는 제공하지 않는다. 삭제 후 today summary projection/reload는 Todo 16이 조립한다.
  Must NOT do: 예시 데이터 toggle/237회 고정값, `/112` 평균, 성공/스트릭/식욕 추론, Free에서 31일 이전/Pro 값 노출, hover/print/browser phone frame.
  Parallelization: Wave 4b | Blocked by: 5,6,8,9,11 | Blocks: 16 | Can parallelize: 12,13,15
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:620-824`; `docs/마음자로_PRD.md:398-517`; `docs/Screenshot 2.jpg`; `docs/Screenshot 3.jpg`; `docs/maeumjaro_interactive_product_plan_v1.html:1407-1446,1991-2100`
  Acceptance criteria:
  - deterministic fixture의 카드/30일/52주/heatmap/date detail/chart 값이 domain aggregator output과 exact match하고 개별 삭제 cancel/confirm이 각각 0/1행 변화만 만든다.
  - Free 30일, Pro 52주와 초기16주 viewport, 0–4/5–9/10+/30+ 문구 gating이 정확하다.
  - empty state는 0과 중립 설명이며 maximum Dynamic Type/dark component render에서 clipping·color-only 정보가 없다. `HistoryAccessibilityContent`의 날짜/count/sum/chart/detail label/value/hint는 정확하며 실제 VoiceOver tree/focus는 Todo 16/17에서 판정한다.
  QA scenarios:
  - Component surface: deterministic analytics-reference repository와 Free policy를 `HistoryViewModel`에 주입하고 `HistoryView`/date detail을 `ImageRenderer`로 출력하며 `HistoryAccessibilityContent`를 JSON으로 기록한다. PASS iff 최근30일/정확한 detail/Pro lock, 31일 전 값 부재, exact nonempty label/value/hint 모델이 일치한다. Evidence `<attemptDir>/task-14-free.png`, view-model JSON, `<attemptDir>/task-14-accessibility-content.json`.
  - Pro component: verified-Pro fake policy로 52주/initial16주/count-intensity/3-hour/weekday/intensity chart states를 출력한다. PASS iff domain aggregate JSON과 exact match다. Evidence `<attemptDir>/task-14-pro-*.png`.
  - Empty/malformed component: empty repository를 주입한다. PASS iff 0 state, no crash, no diagnosis/achievement copy. Evidence `<attemptDir>/task-14-empty.png`.
  - Individual delete harness: selected ID deletion을 cancel한 뒤 confirm한다. PASS iff cancel hash는 동일하고 confirm 뒤 selected ID만 사라지며 나머지 row/settings/phrases는 그대로다. 실제 app navigation/projection/reload video는 Todo 16에서 수행한다. Evidence `<attemptDir>/task-14-delete-one.json`.
  Commit: Y | `feat(history): add free records and Pro analytics`

- [ ] 15. Pro paywall·CSV/JSON 내보내기·추가 테마·데이터 관리 UI 구현
  What to do:
  - UI 전 RED로 Free 화면에서 paywall/restore/export gating이 없는 상태를 캡처한다.
  - `Features/Commerce/ProPaywallView.swift`, `Features/Settings/DataManagementView.swift`, `Infrastructure/Export/{HistoryExporter,ExportDocument}.swift`, `MaeumjaroAppTests/{HistoryExporterTests,DataManagementViewModelTests}.swift`를 구현한다.
  - paywall은 1회 구매, 52주 기록, 상세 분석, CSV/JSON 내보내기, 추가 테마를 설명하고 구매/복원/loading/cancel/fail/purchased/restored 상태를 갖는다. monthly/subscription/ad wording은 없다.
  - export schema는 approved fields(`completedAtUTC,eventLocalDate,timezoneOffsetMinutes,intensity,source,phraseID`)만 포함하고 CSV quoting/UTF-8 BOM 정책과 JSON schemaVersion을 고정한다. name/location/contact/advertising/health/internal pause/app version은 export하지 않는다.
  - 빈 기록은 파일을 만들지 않고 설명한다. 명시적 format 선택 뒤 Data-backed `Transferable`을 통해 OS share sheet를 열고 OS-managed temporary item을 사용한다. cancel은 원본/외부 상태를 바꾸지 않는다.
  - 삭제 UI는 1차 설명→명시적 확인→event deletion을 호출하며 cancel은 no-op, success는 widget today summary 0 projection을 Todo16에 요청한다. 설정/phrases/entitlement는 유지한다.
  - theme selector는 exact Free `quietIvory`, Pro `midnightInk`/`forestMist` ID만 사용한다. verified Pro일 때만 `AppSettings.themeID`에 Pro ID 저장과 widget theme projection을 요청하고, Free/loading/error/unverified/revoked 전환에서는 즉시 `AppSettings.themeID=quietIvory`와 같은 widget snapshot을 요청한다. 실제 write/read-back/reload orchestration은 Todo 16이 소유한다.
  Must NOT do: Free export, email/upload/backend share, subscription, record deletion on purchase/refund, arbitrary theme/color editor, agent-driven workspace file deletion.
  Parallelization: Wave 4b | Blocked by: 5,6,8,9,11 | Blocks: 16 | Can parallelize: 12–14
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:984-1017,1315-1336`; `docs/마음자로_PRD.md:523-648`
  Acceptance criteria:
  - exporter RED→GREEN covers Unicode/comma/quote/newline, stable header/order, JSON schemaVersion, approved-field-only, empty no-document, original row hash unchanged.
  - Free cannot invoke export/Pro theme, verified Pro can; cancel/pending/unverified/revoked cannot.
  - verified Pro에서 각 Pro theme 선택 후 revoke/unverified fixture로 전환하면 selected app theme와 requested widget snapshot이 `quietIvory`로 돌아가며 stale Pro palette가 남지 않는다.
  - deletion cancel preserves all; confirm clears events only; settings/phrases/entitlement counts unchanged.
  QA scenarios:
  - Commerce component: purchase/restore/loading/cancel/fail/verified/revoked view-model states를 `ImageRenderer`로 출력한다. PASS iff Pro control은 verified에서만 enabled이고 subscription 문구가 없으며 revoked 화면/theme request는 `quietIvory`다. Evidence `<attemptDir>/task-15-commerce-*.png`와 state trace.
  - Export harness: verified-Pro fake policy로 CSV/JSON `Transferable` payload를 생성하고 share presenter fake를 cancel한다. PASS iff presenter는 명시 동작 후 한 번 호출되고 source row hash unchanged, destination 저장 주장은 없다. Evidence `<attemptDir>/task-15-export-cancel.json`.
  - Delete harness: isolated repository에서 전체 삭제를 cancel 후 confirm한다. PASS iff 첫 counts unchanged, 둘째 event count 0/settings+phrase+entitlement unchanged다. 실제 StoreKit purchase/relaunch/restore, OS share sheet, app projection video는 Todo 16에서 수행한다. Evidence `<attemptDir>/task-15-delete.json`과 rendered confirmation PNG.
  Commit: Y | `feat(pro): add purchase export themes and data controls`

- [ ] 16. Composition root와 completion→기록→widget 전체 경로 조립
  What to do:
  - `iOSApp/Maeumjaro/App/AppCompositionRoot.swift`, `RootView.swift`, `DeepLinkHandler.swift`, `Infrastructure/Completion/EventCompletionCoordinator.swift`, `Infrastructure/WidgetSync/{WidgetProjectionCoordinator,AppWidgetTimelineReloader}.swift`를 단독 소유해 core/feature lane을 조립한다. 이 Todo만 `WidgetCenter`를 app target에서 import한다.
  - `MaeumjaroAppTests/{EventCompletionCoordinatorTests,WidgetProjectionCoordinatorTests,EndToEndIntegrationTests}.swift`, `MaeumjaroUITests/{RitualUITests,DeepLinkUITests,PurchaseGateUITests,AccessibilitySmokeUITests}.swift`에 end-to-end RED를 먼저 만든다.
  - cold/warm deep link→latest strength→ritual→completion effect→`EventCompletionCoordinator`→SwiftData insert one→DB aggregate 기반 today summary projection→`reloadTimelines(ofKind: "MaeumjaroWidget")`→records navigation을 연결한다. app start는 source app, widget link는 source widget이다. Todo 12에는 이 persistence/projection 구현을 중복하지 않는다.
  - onboarding/settings strength write와 widget intent가 같은 shared source를 사용하게 한다. completion/delete 후 projection은 DB aggregate에서 새 snapshot을 만들며 snapshot 쓰기 실패가 event insert를 rollback하지 않는다; 다음 foreground에서 재투영한다.
  - app-side explicit targeted reload는 completion, 개별/전체 delete, app settings의 strength/theme 변경, entitlement downgrade가 snapshot write/read-back을 끝낸 뒤에만 한 번 호출한다. strength App Intent 자체는 explicit reload를 하지 않는다. projection 실패가 event insert를 rollback하지 않으며 다음 foreground에서 재투영한다.
  - entitlement는 presentation/query/export/theme gate만 제어한다. verified Pro→Free/loading/error/unverified/revoked 신호가 오면 app/theme selection과 widget theme snapshot을 `quietIvory`로 쓴 뒤 targeted reload한다. persistence와 core ritual은 entitlement를 모르며 환불/restore가 row를 바꾸지 않는다.
  - `MAEUMJARO_QA_FIXTURES` build만 `-MaeumjaroFixtureID <uuid> -MaeumjaroFixture <name>`을 받아 `Library/Caches/MaeumjaroQA/<fixtureID>/` SwiftData와 `qa.<fixtureID>.*` App Group namespace를 일치시킨다. Release compile에서 fixture code와 test entitlement override가 포함되지 않는지 검증한다.
  - Todo 11의 shell `RootView` 소유권을 이어받아 ritual/history/paywall/settings route를 실제 feature view로 교체한다. Todo 12–15에서 component-only로 남긴 deep-link/lifecycle/widget gallery/records/StoreKit/share/delete/theme cross-feature QA는 이 Todo의 integration matrix로 한 번 수행한다.
  Must NOT do: service locator/global mutable singleton, widget DB access, projection failure event 삭제, URL intensity, duplicate save, Release fixture backdoor.
  Parallelization: Wave 5 | Blocked by: 10–15 | Blocks: 17
  References: 모든 prior todo contract; `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:20-38,891-980,1150-1207`; `docs/마음자로_PRD.md:216-251,357-396,728-789`
  Acceptance criteria:
  - app/widget source 각각 E2E에서 exact event source, strength, phraseID, local date/timezone, duration/interruption/version이 1행 저장된다.
  - completion callback 2회/scene race/rapid again에도 session row 1; incomplete/background 0.
  - event insert 성공+projection failure는 DB row 1/snapshot stale error, foreground repair 후 snapshot exact aggregate다.
  - individual delete confirm은 selected row만 감소하고 전체 delete confirm은 event 0/summary0이며 각각 snapshot write/read-back 뒤 reload1이다. cancel path는 row/snapshot/reload 모두 unchanged다.
  - Pro theme 선택 후 revoked/unverified 전환은 app/widget `quietIvory`, targeted reload1, event rows unchanged이고 stale Pro theme snapshot이 없다.
  - valid widget/app URL은 actual ritual route와 correct source에 도달하고 invalid scheme/host와 injected URL intensity는 route/event를 만들지 않는다.
  - actual Simulator에서 small/medium widget, Free/Pro records, local StoreKit purchase/relaunch/restore, share cancel, individual/full delete를 순회한 결과가 component harness와 동일하다.
  - `AccessibilitySmokeUITests`가 onboarding, ritual, completion, history/detail/delete, paywall/settings의 실제 app tree에서 component `AccessibilityContent`와 같은 label/value/hint를 찾고 주요 control을 activate한다. widget tree/focus와 VoiceOver 실제 순회는 Todo 17 manual matrix가 검증한다.
  - Release binary/string scan에 fixture launch key와 test entitlement override가 없다.
  QA scenarios:
  - Full Simulator surface: widget에서 strength5→start→50% pause→resume→complete→기록 보기→home widget을 computer-use로 순회하고 `recordVideo`; PASS iff 중간 홈 없음, event1, records exact, widget today +1/sum+5. Evidence `<attemptDir>/task-16-e2e-widget.mp4`, DB/snapshot dumps.
  - Widget gallery/cold path: 새 fixture UUID에서 small/medium을 추가하고 1↔5/direct2를 조작한 뒤 app을 terminate하고 widget start를 탭한다. PASS iff bounds, 모든 instance/app strength, WidgetKit 후속 갱신, 3초 이내 latest-strength ready route가 정확하다. Evidence `<attemptDir>/task-16-widget-gallery-cold.mp4`와 timing/provider trace.
  - App/deep-link/lifecycle: records top start→99% background→ready 0 rows, 다시 완료하고 invalid URL 및 intensity payload URL을 연다. PASS iff source app completion 1, invalid route/event 0, URL intensity 무시다. Evidence `<attemptDir>/task-16-e2e-app.mp4`, route/repository dumps.
  - Records/delete: analytics-reference fixture로 Free 30일→verified Pro 52주/chart→개별 delete cancel/confirm→전체 delete cancel/confirm을 조작한다. PASS iff domain JSON과 화면이 일치하고 각 delete의 row/snapshot/reload 계약이 정확하다. Evidence `<attemptDir>/task-16-records-delete.mp4`와 before/after hashes.
  - Commerce/export/theme: local StoreKit purchase→relaunch→restore→Pro theme 선택→CSV share sheet cancel→revoked/unverified transition을 조작한다. PASS iff verified에서만 Pro, source rows unchanged, app/widget이 `quietIvory`로 복귀하고 stale Pro theme가 없다. Evidence `<attemptDir>/task-16-commerce-export-theme.mp4`와 transaction/theme trace.
  - Offline dependency path: 새 fixture UUID와 injected failing/offline StoreKit client로 같은 핵심 경로를 실행한다. PASS iff core loop/record/analysis/delete는 network dependency 없이 동작하고 구매/복원 surface만 offline 설명을 보인다. 정적 dependency audit에서 StoreKit 외 URLSession/Network/backend symbol은 0이다. Evidence `<attemptDir>/task-16-offline.mp4`와 dependency log. 실제 비행기 모드 확인은 Todo 17 real-device release gate다.
  Commit: Y | `feat(app): connect ritual records and widget projection`

- [ ] 17. 전체 자동 gate·Simulator/실기기·접근성·릴리스 사전검증
  What to do:
  - `iOSApp/README.md`, `iOSApp/QA/{ReleaseChecklist,AccessibilityChecklist,BrandAndPrivacyChecklist}.md`에 실행법, exact identifiers, external gates, evidence index를 기록한다.
  - 먼저 Aside가 아닌 native `Simulator` app을 computer-use로 열어 CoreSimulatorService를 정상화한 뒤 `xcrun simctl list devices available`과 `xcodebuild -showdestinations`로 실제 iOS 17+ iPhone UDID를 선택한다. 이름/OS를 임의 가정하지 않는다.
  - 최종 상태에서 다음 command contract를 순서대로 실행한다: `xcodegen generate --spec iOSApp/project.yml` 2회와 diff, `xcodebuild -showTestPlans -project iOSApp/Maeumjaro.xcodeproj -scheme Maeumjaro`, `swift test --package-path iOSApp/Packages/MaeumjaroCore`, generic simulator build, 실제 simulator의 `Maeumjaro`/`MaeumjaroStoreKit` test plan, warning scan, unsigned generic-iOS archive preflight.
  - exact test commands는 `xcodebuild test -project iOSApp/Maeumjaro.xcodeproj -scheme Maeumjaro -destination 'platform=iOS Simulator,id=<actual-iPhone-UDID>' -testPlan Maeumjaro -resultBundlePath <attemptDir>/task-17-maeumjaro.xcresult`와 동일 형식의 `-testPlan MaeumjaroStoreKit -resultBundlePath <attemptDir>/task-17-storekit.xcresult`이다. 각 결과는 `xcrun xcresulttool get test-results summary --path <xcresult> --compact`로 구조화한다.
  - archive는 `xcodebuild archive -project iOSApp/Maeumjaro.xcodeproj -scheme Maeumjaro -destination 'generic/platform=iOS' -archivePath <attemptDir>/Maeumjaro.xcarchive CODE_SIGNING_ALLOWED=NO`로 실행한다. 모든 xcodebuild output은 task log에 보존하고 `rg -n 'warning:|error:' <attemptDir>/task-17-*.log`가 0개인지 검사한다.
  - 각 manual row는 새 UUID로 `xcrun simctl launch booted com.yeoreum.maeumjaro --args -MaeumjaroFixtureID <uuid> -MaeumjaroFixture <name>`을 호출한다. Simulator matrix는 신규 온보딩, settings persistence, small/medium widget 1↔5, warm/cold route, hold/pause/resume/background, exactly-once, WidgetKit 후속 intent 갱신, app-side completion/delete/theme targeted reload, Free/Pro, heatmap/date/chart, export cancel, 개별/전체 delete cancel/confirm, empty state, injected StoreKit offline, light/dark, 최대 Dynamic Type, Reduce Motion, VoiceOver, Increase Contrast, Differentiate Without Color, no permission prompt다.
  - 접근성 세부 row: (a) VoiceOver ON에서 `강도 조절`, `의식 시작`, hold region, 기록 날짜, 삭제 확인을 순서대로 focus/activate하고 label/value/hint·focus order를 녹화한다. (b) Simulator Settings > 손쉬운 사용 > 디스플레이 및 텍스트 크기 > 색상 사용 없이 구별 ON에서 intensity/heatmap/disabled 상태가 숫자·symbol·text로 구분되는 screenshot을 남긴다. (c) 최대 Dynamic Type/Increase Contrast/Reduce Motion 조합에서 clipping, 가려진 CTA, animation-only state가 0인지 캡처한다.
  - Voice Control과 Switch Control은 signed iPhone release row다. Voice Control ON→“번호 보기”→표시 번호로 강도/시작/길게 누르기/기록/삭제를 조작하고, Switch Control ON→자동 스캔으로 같은 control을 traverse/activate한다. focus trap·누락 control·voice label collision이 없어야 하며 device video를 남긴다. 기기가 없으면 `releaseBlockers`에 남기고 local `implementationVerdict`를 실패시키지 않는다.
  - signed iPhone에서 widget cold launch/reboot/multi-widget, haptic ON/OFF와 exact pulse schedule, 실제 airplane mode core flow/StoreKit 설명, screen-size clipping, frame pacing, share sheet, StoreKit sandbox restore를 실행한다. 기기가 없으면 모두 `releaseBlockers`이고 PASS가 아니다.
  - app icon/widget/ritual/완료/스토어 문구에서 independent asset provenance와 forbidden claims를 검토한다. app/widget archive 각각에 `PrivacyInfo.xcprivacy`가 하나씩 있고 `NSPrivacyTracking=false`, collected data 0, `NSPrivacyAccessedAPICategoryUserDefaults` reason `1C8F.1`인지 `find`와 `plutil -p`로 검증한다. archive/API scan이 다른 required-reason 사용을 찾으면 현재 선언을 억지로 유지하지 않고 실제 사용에 맞는 새 RED→GREEN manifest 변경을 요구한다.
  - SwiftData store directory의 `isExcludedFromBackup` read-back이 true인지 probe와 device container evidence로 확인하고 App Privacy 초안을 local-only history/StoreKit boundary와 맞춘다.
  - 구현 전 저장한 docs checksum과 최종 checksum을 비교한다. 원본 차이가 하나라도 있으면 FAIL이며 자동 복원/삭제하지 않고 사용자에게 정확한 path를 보고한다.
  Must NOT do: Simulator erase/uninstall, 실기기 사용자 데이터 삭제, evidence 삭제, App Store 제출/상품 생성/서명 프로필 변경, tactile quality를 자동 승인, test failure suppress/skip.
  Parallelization: Wave 6 | Blocked by: 16 | Blocks: F1–F4
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:1087-1216,1315-1399`; `docs/마음자로_PRD.md:654-963`; `docs/maeumjaro_interactive_product_plan_v1.html:1515-1545`; all visual docs.
  Acceptance criteria:
  - `xcrun simctl list devices available`이 iOS 17+ iPhone을 하나 이상 반환해야 local `implementationVerdict`를 낼 수 있다. 없으면 infrastructure blocker다.
  - `xcodegen generate --spec iOSApp/project.yml` and immediate second generation are stable.
  - `swift test --package-path iOSApp/Packages/MaeumjaroCore` exits 0 with no skipped tests.
  - `xcodebuild build -project iOSApp/Maeumjaro.xcodeproj -scheme Maeumjaro -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` exits 0 with no warnings treated as errors.
  - 두 exact test plan command와 unsigned archive가 exit 0이고 xcresult summary에 failure/skipped 0, warning/error scan 0이다.
  - 두 privacy manifest와 backup exclusion 검사가 GREEN이고 모든 manual Simulator row가 screenshot/video/log 및 cleanup receipt를 가진다. docs checksums는 동일하다.
  - `implementationVerdict=PASS`는 위 local gate만으로 가능하다. `releaseVerdict=PASS`는 signed-device rows, 공개 이름/상표, production asset review, App Store Connect 상품/지원·개인정보 URL까지 모두 관찰된 뒤에만 가능하고, 그 전에는 각 항목을 `releaseBlockers`로 출력한다.
  QA scenarios:
  - Computer-use matrix uses `let simulator = await cua.getApp("Simulator");` and shipped accessibility labels; binary observables are recorded in `<attemptDir>/task-17-manual-matrix.json`, with fixture UUID, state before/after, screenshot/video path, cleanup, `implementationVerdict` per row.
  - Performance: local `implementationVerdict`에는 XCTest launch/signpost metric을 사용하고, `releaseVerdict`에는 signed iPhone의 Instruments Animation Hitches trace를 추가한다. PASS targets: widget tap→ready warm ≤1.5s/cold ≤3s, touch→visual ≤150ms, intensity intent display ≤500ms, 1.2–2.6s ritual의 blocking animation hitch 0. Evidence `<attemptDir>/task-17-performance.{xcresult,trace,csv}`.
  - Privacy/brand: parsed entitlements/Info/app+widget privacy manifests, backup-exclusion receipt, archive inventory, visible-surface walkthrough; PASS iff no unrequested capability/permission, manifest matches actual API use, no medical efficacy/copycat asset, and `implementationReviewStatus=passed`. Public asset/trademark review stays pending in `releaseReviewStatus` until externally approved. Evidence `<attemptDir>/task-17-privacy-brand.json`.
  Commit: Y | `docs(ios): record release and QA evidence`

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit
  - Independent verifier rereads this entire plan, both Markdown PRDs, the HTML source, PNG/JPG/MP4 evidence summaries, and every task ledger entry.
  - PASS iff Todos 1–17 and all acceptance/QA/evidence/cleanup clauses are complete, no skipped/xfail/suppressed failure exists, and every docs 요구가 shipped artifact 또는 `Docs requirement disposition`의 명시적 supersede에 매핑된다. Output `<attemptDir>/final-F1-plan-compliance.md`.
- [ ] F2. Code quality review
  - Run `omo:review-work` with final full SHA, diff, user goal, constraints, exact test/build commands, artifacts, and runtime entry path. All five review lanes must PASS; missing/timeout/inconclusive is failure.
  - Review architecture dependency direction, Swift concurrency/sendability, SwiftData transaction/idempotency, App Group process boundary, StoreKit verification lifecycle, accessibility semantics, error/recovery paths, and absence of unused abstractions.
  - Run a separate `omo:debugging` runtime audit with at least three hypotheses: duplicate completion under lifecycle race, stale/corrupt App Group value, and entitlement revoke/offline transition. Each hypothesis needs distinguishing evidence.
  - Bind every PASS and runtime-audit verdict to `git rev-parse HEAD` in `.omo/start-work/ledger.jsonl`. Output `<attemptDir>/final-F2-code-review.md` and `<attemptDir>/final-F2-runtime-audit.md`.
- [ ] F3. Real manual QA
  - A different `lazycodex-qa-executor` repeats the complete Todo 17 Simulator matrix with new `-MaeumjaroFixtureID <uuid>` values without trusting executor narration. It directly drives `Simulator`, captures screenshots/videos/timing, verifies event/snapshot/export/theme outputs, and records cleanup.
  - `implementationVerdict=PASS` requires small/medium widget, widget/app entry, hold/pause/resume/background, exactly one completion, Free/Pro, export, individual/full delete, injected offline, VoiceOver/Dynamic Type/Reduce Motion/Increase Contrast/Differentiate Without Color/light/dark/no-permission surfaces and all automated local gates.
  - `releaseVerdict=PASS` additionally requires connected signed-device evidence for Voice Control, Switch Control, airplane mode, haptic schedule/feel, widget reboot/cold/multi-widget, frame pacing, share sheet, StoreKit sandbox restore plus remaining external release approvals. Otherwise `implementationVerdict`와 별도로 exact `releaseBlockers`를 출력한다.
  - Output `<attemptDir>/final-F3-manual-qa.json` and referenced media.
- [ ] F4. Scope fidelity
  - Independent reviewer compares final tree/diff with Scope Must have/Must NOT have and docs checksum baseline.
  - PASS iff no Flutter/Rive/Android/backend/cloud/account/ad/subscription/health/sensor/unrequested permission, no medical/efficacy/success inference, no docs mutation/reference asset copy, no release claim without external gates, and only task-owned files were committed.
  - Output `<attemptDir>/final-F4-scope-fidelity.md`.

## Commit strategy

- Delivery mode is direct local implementation; no PR, push, merge, App Store upload, or worktree is requested.
- Todo 1 initializes `main`, commits the untouched planning baseline, then creates the project scaffold primary commit. Each later Todo creates one task-scoped primary commit after its RED→GREEN proof, real/data-shaped surface, adversarial probes, and cleanup receipt; independent verification then binds to that full SHA before the checkbox can complete.
- Before each commit run `git log --oneline -20` and `git log -5 -- <touched paths>`; after the baseline, follow the Conventional Commit subjects already listed per Todo. Add footer `Plan: .omo/plans/maeumjaro-ios-implementation.md` to each implementation commit.
- Stage only that Todo's product/test files and required generated project changes. Do not stage `.DS_Store`, DerivedData, user-specific Xcode state, unrelated `.omo` Android artifacts, or unredacted QA logs.
- Generated `Maeumjaro.xcodeproj` may be committed for Xcode usability, but `project.yml` remains source of truth and the commit must include a second-generation stability check.
- Evidence and start-work ledger must redact signing identities, device names/UDIDs, StoreKit account information, and any credentials. Store only non-sensitive state summaries or hashes.
- Do not amend, rebase, force-push, reset, or delete commits/artifacts. If independent review fails, create only the necessary minimal fix commit after new RED→GREEN and affected surface evidence, then re-run verification at the new SHA. Thus a Todo has one primary commit plus zero or more review-driven minimal fix commits, never a rewritten commit.
- Final F1–F4 and debugging coverage bind to the exact final full commit SHA. Any subsequent product/test commit invalidates those results and requires rerunning applicable lanes.

## Success criteria

1. Project and build
   - `iOSApp/project.yml` deterministically generates a buildable iOS 17 app, interactive widget extension, package modules, app/widget/unit/UI test targets, shared scheme, and two test plans with the approved identifiers and no third-party runtime packages.
   - The final generic simulator build, available-iPhone test plans, StoreKit test plan, warning scan, and archive preflight all exit 0 without skipped tests or suppressed diagnostics.

2. Core ritual and persistence
   - From app or widget, the latest shared intensity 1...5 opens the ready screen; press/release/resume/background rules match the approved state machine and intensity profiles.
   - Incomplete sessions store zero rows; the first 100% completion stores exactly one complete event even under duplicate callback/lifecycle race, then projects the exact today summary to every widget.
   - Intensity N emits exactly N progress pulses at `k/(N+1)` plus separate first-press start and first-completion cues; pause/resume never repeats cues, and haptics off/unsupported emits none without altering visual/text completion.
   - Phrase selection enforces approved catalog, intensity/tone, last-ten exclusion, category repetition limit, and safe fallback.

3. Widget process boundary
   - Small/medium widgets mutate strength through App Intent, persist/read-back before return, rely on WidgetKit's post-intent timeline request, use current App Group values on warm/cold launch, and never link/read/migrate the SwiftData event store. Only app-side completion/delete/theme/settings projection explicitly reloads `MaeumjaroWidget`.
   - Missing/corrupt/unknown shared data falls back to strength3/today0 without overwriting the evidence or creating an event.

4. Records and Pro policy
   - Free shows today/recent/last30 local dates; Pro verified non-consumable unlocks prior retained events across 52 weeks, count/intensity heatmap, initial16-week viewport, distributions, comparisons, export, and approved themes.
   - Every summary/detail/chart matches deterministic timezone-safe aggregator output. Empty/low-sample states remain neutral and never infer craving, success, diagnosis, weight, or treatment.
   - Purchase cancel/fail/pending/unverified/revoke/restore is fail-closed and never mutates events. Pro→Free/unverified/revoked immediately restores app/widget theme `quietIvory` and targeted reloads without stale Pro color. Export and delete require explicit user action; cancel is no-op; individual deletion removes only the selected event and full deletion clears events/summary only.

5. User-visible quality and safety
   - Local surfaces pass VoiceOver, maximum Dynamic Type, minimum 44pt target, contrast, Differentiate Without Color, Reduce Motion, haptics off, sound off, light/dark, and no-permission checks. Signed-device release surfaces additionally pass Voice Control and Switch Control exact traversals.
   - Simulator evidence shows warm ≤1.5s, cold ≤3s, touch→visual ≤150ms, widget mutation display ≤500ms targets. Real-device evidence is required before `releaseVerdict=PASS` for haptic feel/schedule, airplane mode, Voice/Switch Control, widget reboot/cold behavior, and frame pacing.
   - All UI/assets are independently created and provenance-recorded; no reference bitmap/SVG/video, actual medicine appearance, protected drug naming, dose/efficacy/treatment/weight-loss language, or copied gradient is shipped.

6. Evidence and boundaries
   - Each Todo has pre-change RED, post-change GREEN, a real or data-shaped surface artifact, adversarial-class results, cleanup receipt, and an independent confirmed verifier verdict bound to the current full SHA in `.omo/start-work/ledger.jsonl`.
   - Final F1–F4 and debugging audit pass at the same final SHA. `docs/` pre/post checksum manifests are identical.
   - App/widget privacy manifests, UserDefaults reason `1C8F.1`, backup exclusion, Release fixture-string absence, test plans, archive inventory, and local manual matrix must pass for `implementationVerdict=PASS`.
   - Apple Developer Team/App Group registration, App Store Connect product, signed real-device tests, public name/trademark, final production asset approval, privacy-policy/support URLs, and App Store submission remain separately reported `releaseBlockers` until genuinely observed; `releaseVerdict` cannot pass before them.

## TODO summary

| Wave | Todos | Deliverable | Exit gate |
| --- | --- | --- | --- |
| 0 | 1 | XcodeGen source of truth, iOS 17 app/widget/test skeleton, two privacy manifests | deterministic generation, inventory, generic build |
| 1 | 2 | domain values, single-source intensity, ports and identifiers | contract RED→GREEN, dependency audit |
| 2 | 3–9 | reducer/cues, phrases, analytics, SwiftData, App Group, brand assets, StoreKit | lane tests, probes, independent SHA verdicts |
| 3 | 10 | interactive strength intent without explicit reload | out-of-process storage/read-back and no-op/failure proofs |
| 4 | 11–15 | onboarding/settings shell, ritual, widget, records/analytics, Pro/export/themes/delete components | Todo 11 shell Simulator plus Todo 12–15 fake-port/ImageRenderer artifacts and feature tests |
| 5 | 16 | full feature navigation, deep link, exactly-once persistence, projection, app-side reload, entitlement downgrade | all deferred app/widget/StoreKit/DB E2E, projection-failure repair, Release backdoor scan |
| 6 | 17 | full test plans, archive/privacy/accessibility/performance manual matrix | `implementationVerdict` plus exact `releaseBlockers` |
| Final | F1–F4 | compliance, code/runtime review, independent QA, scope fidelity | every lane APPROVE at the same final full SHA |
