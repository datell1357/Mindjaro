# maeumjaro-android-app - Work Plan

## TL;DR (For humans)
<!-- Fill this LAST, after the detailed plan below is written, so it summarizes the REAL plan. -->
<!-- Plain English for a non-engineer: NO file paths, NO todo numbers, NO wave/agent/tool names. -->

**What you'll get:** 위젯에서 바로 시작해 길게 누르는 가상 자기조절 의식, 완료 기록, 16주 히트맵과 로컬 데이터 관리까지 갖춘 무료 Android 앱을 먼저 만들고, 이후 1회 구매형 Pro 분석·개인화 기능을 같은 로컬 데이터 위에 추가합니다.

**Why this approach:** Android 전용 범위이므로 네이티브 기술로 앱과 위젯의 상태·시작 성능·접근성을 단순하게 유지합니다. 완료 기록, 위젯 표시 상태, 구매 권한을 서로 다른 원본으로 분리해 중복 기록과 동기화 오류를 차단합니다.

**What it will NOT do:** iOS, 서버, 로그인, 광고, 원격 분석이나 건강 정보 수집은 포함하지 않습니다. 실제 약물·용량·치료·식욕 억제 효과를 표현하지 않으며 참고 자산을 복제하지 않습니다.

**Effort:** XL
**Risk:** High - 실기기 감각 품질, 홈 위젯의 프로세스 경계, client-only Play Billing, 비의료 브랜드 심사가 동시에 출시 품질을 좌우합니다.
**Decisions to sanity-check:** 무료는 최근 30일 목록·16주 히트맵·전체 CSV, Pro는 52주·상세 분석·JSON·개인화입니다. 기록과 설정은 Android cloud/D2D backup에서 제외하며, `com.maeumjaro.app`은 내부 개발용 임시 ID입니다.

Your next move: 계획을 검토한 뒤 실제 구현을 원하면 별도 `$start-work` 작업을 시작하세요. Full execution detail follows below.

---

> TL;DR (machine): XL/high-risk native Android delivery in 15 implementation-and-test Todos, staged Free MVP then one-time Pro, with Room/DataStore/Glance/Billing boundaries and four final evidence gates.

## Scope
### Must have

- `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md`를 규범적 안전/MVP 기준으로, `docs/마음자로_PRD.md`를 상세 수용 기준으로 사용한다. HTML·스크린샷·기능명세 PNG·MP4는 동작과 구도 참고일 뿐 복제 자산이나 구현 증거가 아니다.
- Android 네이티브 단일 앱 모듈로 시작한다: Kotlin, Jetpack Compose, Navigation Compose, Room, Proto DataStore, Jetpack Glance, Play Billing. `compileSdk/targetSdk=36`, `minSdk=26`, Java 17을 현재 기준값으로 두고 실행 시작 시 최신 안정 버전만 version catalog에 잠근다.
- 앱 아이콘 진입은 기록 대시보드, 위젯 진입은 중간 홈 없이 주입 화면이다. 첫 실행만 5단계 온보딩을 거친다.
- 강도 1~5, 기본값 3, 20/40/60/80/100% 내부 모션 매핑, 1.2/1.5/1.8/2.2/3.2초 목표 시간, 길게 누르는 동안만 진행, 놓으면 일시정지, 재누름 재개, 완료 전 백그라운드 이동 시 무기록 초기화를 구현한다. 최종 펜 계약의 좌우 스와이프 잠금 해제·재잠금과 새 pointer sequence 요구를 함께 적용한다.
- 사용자 화면에는 내부 `가상 주입량`을 노출하지 않고 `진행률`로 표현한다. 의약품명, mg, 용량, 처방, 치료, 식욕 억제, 체중 감량, 성공률, 스트릭을 주장하거나 암시하지 않는다.
- 완료 이벤트는 Room에 exactly once로 기록하고, Proto DataStore는 현재 강도·앱 설정·오늘 위젯 projection만 보관한다. Play Billing 소유권은 별도 경계로 둔다.
- 모든 완료 이벤트는 사용자가 삭제할 때까지 기기 안에 보존한다. Free/Pro는 저장 여부가 아니라 조회·표현 범위만 제어하며, Pro 구매 후 이전 기록도 즉시 해금한다.
- Free: 오늘 요약, 최신 10건, 최근 30일 기록 목록, 최근 16주 히트맵, 사용자 실행 CSV 전체 내보내기. Pro: 최근 52주 상세 기록, 3시간대·요일·강도 분포, 4주 비교, JSON 내보내기, 추가 테마, 검증된 사용자 문구, 위젯별 강도 프리셋.
- Glance 위젯은 2x2와 4x2 반응형 크기에서 강도 ±, 현재 강도, 오늘 횟수/누적 강도, 주입 직접 시작을 제공하며 모든 인스턴스가 같은 persisted state를 읽는다.
- `assets/maeumjaro_pen/`의 최종 PNG 7종을 `docs/maeumjaro_pen/integration_contract.json`의 1024×1536 좌표, 레이어 순서, 3D 링 회전, 연속 액체 마스크 계약에 따라 네이티브 Compose에 연결한다. 이 최종 계약은 과거 프로토타입의 펜 타이밍·합성 방식보다 우선한다.
- TalkBack, Switch Access, 200% 글자 크기, 48dp 터치 타깃, 색 외 정보 표현, 동작 줄이기, 햅틱 미지원/비활성 시 시각 대체, 오프라인 동작을 출시 기준으로 검증한다.
- Tests-after로 각 Todo 안에서 구현과 해당 자동 테스트를 함께 끝낸다. 최종 검증은 실제 Android 표면, 실제 launcher 위젯, 실기기 햅틱, Play license tester까지 분리해 증거를 남긴다.

### Must NOT have (guardrails, anti-slop, scope boundaries)

- iOS, Flutter/Drift/Riverpod/Rive, 서버, 앱 계정·로그인, 원격 동기화, 광고, 원격 분석 SDK, Wear OS, 잠금화면 위젯을 추가하지 않는다.
- 위치·연락처·카메라·마이크·광고 ID·체중·질환·처방 정보나 미완료 의식의 원본 이벤트를 저장하지 않는다.
- 위젯이 Room 전체 DB를 열거나, Intent가 전달한 강도 값을 신뢰하거나, 앱/위젯 메모리 캐시를 source of truth로 삼지 않는다.
- 초기부터 멀티모듈·Clean Architecture 프레임워크·서비스 로케이터·네트워크 계층·일별 materialized table을 만들지 않는다. 한 앱 모듈과 명시적 repository/use-case 경계로 충분히 구현한다.
- 참고 이미지·영상·HTML의 자산을 그대로 추출·복제하지 않는다. 특정 의약품·의료 서비스의 상표, 제품 외형, 색상 체계, 카피를 모사하지 않는다.
- 구매 확인 전 Pro를 해제하거나 `PENDING`을 구매 완료로 처리하지 않는다. client-only Billing의 한계를 숨기지 않는다.
- Android backup/D2D를 통한 기록·설정 이전을 허용하지 않는다. 사용자가 시작한 export 외에는 앱 밖으로 상세 기록을 전송하지 않는다.

## Verification strategy
> 자동 검증은 에이전트가 수행한다. 실기기 감각, 법무·브랜드, 서명, Play Console처럼 외부 권한이 필요한 항목은 별도 OWNER/EXTERNAL GATE로 통과 여부를 기록한다.
- Test decision: tests-after. Pure Kotlin은 JUnit4/kotlin-test, Room은 AndroidX Test의 in-memory DB, Compose는 semantics 기반 Compose UI Test, Glance는 instrumented test와 실제 launcher, 성능은 Macrobenchmark/Perfetto를 사용한다.
- 자동 검증: `./gradlew testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest`와 `./gradlew :benchmark:connectedCheck`; 모든 테스트는 고정 Clock/Zone과 seeded phrase RNG를 사용한다.
- 기준 fixture: 자정 경계 `2026-09-04T23:59:30+09:00 -> 2026-09-05T00:00:05+09:00`, `Asia/Seoul`과 DST offset 사례, intensity 1~5, heatmap 경계 count `0,1,2,4,5,6,7`/sum `0,1,3,4,7,8,12,13,19,20`, 표본수 `0,4,5,9,10,29,30`.
- 기준 성능: Pixel 7급 물리 기기·Android 16·release/profileable 빌드에서 widget 갱신 20회 p95 ≤500ms, warm/cold launcher 진입 각 10회 p95 ≤1.5s/≤3s. 저사양·Samsung 런처 결과는 별도 행으로 기록하고 목표 미달 시 기기/OS와 함께 실패로 남긴다.
- OWNER/EXTERNAL GATE: 실제 햅틱 주관 확인, TalkBack/Switch Access, 최종 브랜드·상표·독립 자산, release `applicationId`·서명, Play 상품/테스터, 개인정보처리방침 URL, Data Safety/Health Apps Declaration은 자동 검증과 별도다. 통과 전에는 `release ready`로 선언하지 않는다.
- Evidence: <attemptDir>/task-<N>-maeumjaro-android-app.<ext> (attemptDir = currentAttemptDir from 'omo ulw-loop status --json', .omo/evidence/ulw/<session>/<goalId>/a<attempt>; outside ulw-loop use .omo/evidence/)

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.

- Wave 1, foundations (Todos 1-5): Todo 1이 빌드 가능한 greenfield project를 만든 뒤 2-5를 병렬 진행한다. 이 단계에서 제품 계약·DB·DataStore·탐색/안전 UI 기반을 잠근다.
- Wave 2, free MVP vertical loop (Todos 6-10): 6·9·10을 병렬 시작하고 7이 완료 저장을 연결한 뒤 8이 실제 Glance end-to-end를 닫는다. Wave 종료 시 무료 핵심 앱이 오프라인에서 동작해야 한다.
- Wave 3, Pro and release hardening (Todos 11-15): 상세 분석과 Billing을 먼저 닫고 Pro 개인화, 접근성/성능, 공개 배포 게이트 순으로 마감한다.
- Final wave F1-F4: 같은 완성 SHA가 존재할 때만 병렬 감사한다. 현재 workspace가 Git이 아니면 SHA 대신 변경 없는 동일 build artifact checksum을 공통 식별자로 기록한다.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | - | 2,3,4,5 | - |
| 2 | 1 | 6,7,9,11,13 | 3,4,5 |
| 3 | 1 | 7,9,10,11,13 | 2,4,5 |
| 4 | 1 | 7,8,10,12,13 | 2,3,5 |
| 5 | 1 | 6,8,9,10,11 | 2,3,4 |
| 6 | 2,5 | 7,14 | 9,10 |
| 7 | 2,3,4,6 | 8,10,14 | 9 |
| 8 | 4,5,7 | 13,14 | 9,10 |
| 9 | 2,3,5 | 11,14 | 6,10 |
| 10 | 3,4,5,7 | 14,15 | 8,9 |
| 11 | 2,3,5,9 | 12,13,14 | - |
| 12 | 4,5,11 | 13,14,15 | - |
| 13 | 2,3,4,5,8,12 | 14,15 | - |
| 14 | 6-13 | 15,F1-F4 | - |
| 15 | 10,12,13,14 | F1-F4 | - |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Bootstrap the native Android workspace and lock the platform contract
  What to do:
  - Create `settings.gradle.kts`, root `build.gradle.kts`, `gradle/libs.versions.toml`, Gradle wrapper, `app/build.gradle.kts`, `app/src/main/AndroidManifest.xml`, and a single-activity Compose app. Use provisional internal namespace/application ID `com.maeumjaro.app`, `minSdk=26`, `compileSdk=36`, `targetSdk=36`, Java/Kotlin 17, and only stable dependency versions verified at execution time.
  - Put UI/data/widget/billing code in packages inside the single `app` module; do not pre-create library modules. Add a separate `benchmark` module only in Todo 14.
  - Configure debug and non-signed release builds, Compose compiler, KSP for Room, lint warnings-as-errors for project code, and deterministic test resources. Do not initialize Git or configure release signing without separate authorization.
  - Copy the seven approved `assets/maeumjaro_pen/` PNGs into Android `drawable-nodpi` resources without resampling or altering their pixels, preserving source files and recording SHA-256 checksums.
  - Record the Android/Google dependency verification URLs and locked versions in `docs/android-dependency-baseline.md`; expected current anchors are Navigation Compose 2.10.0, Room 3.0.2, DataStore 1.2.1, Billing 9.1.0, but current official stable versions win.
  Must NOT do: add Flutter, network/analytics SDKs, DI frameworks, multi-module scaffolding, production signing secrets, or an external deep link.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 2,3,4,5
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:114-177,194-225,891-980,1178-1216`; Android architecture `https://developer.android.com/topic/architecture/recommendations`; target SDK `https://developer.android.com/google/play/requirements/target-sdk`.
  Acceptance criteria:
  - `./gradlew :app:testDebugUnitTest :app:lintDebug :app:assembleDebug` exits 0 from a clean checkout-equivalent directory.
  - `apkanalyzer manifest application-id app/build/outputs/apk/debug/app-debug.apk` returns `com.maeumjaro.app`; manifest reports min 26/target 36 and contains no location, camera, microphone, contacts, advertising ID, or health permissions.
  - The debug APK installs and opens one `MainActivity`; first launch routes to onboarding and a seeded post-onboarding test route opens the record dashboard.
  QA scenarios:
  - Happy: use `adb install -r app/build/outputs/apk/debug/app-debug.apk` then `adb shell am start -W -n com.maeumjaro.app/.MainActivity`; capture launch output and screenshot.
  - Failure: run the same launch after `adb shell pm clear com.maeumjaro.app`; it must return to onboarding without crash or permission dialog.
  - Evidence: `<attemptDir>/task-1-maeumjaro-android-app.txt` plus PNG screenshots.
  Commit: N | workspace is not a Git repository; do not run `git init` implicitly.

- [x] 2. Implement pure domain contracts for intensity, ritual state, phrases, time, and aggregation
  What to do:
  - Add immutable models under `app/src/main/java/com/maeumjaro/app/core/`: `Intensity(1..5)`, `EntrySource(widget|app)`, `InjectionSession`, `InjectionEventDraft`, `Phrase`, `PhraseCategory`, heatmap levels, and sample-tier models.
  - Implement the pure state machine `Ready -> Pressing <-> Paused -> Committing -> Completed`, plus `CommitFailed -> Committing`. `Pressing` is the actual advancing state. Create the UUID and started time on the first valid press; reuse both across pause and commit retry. Ignore secondary pointers and input during `Committing/Completed`.
  - Use monotonic elapsed time for progress and an injected wall `Clock` only for event timestamps. Map intensity 1..5 to internal liquid fractions 20/40/60/80/100%, duration 1200/1500/1800/2200/3200ms, and increasing haptic threshold counts.
  - On primary release/cancel, pause at the exact accumulated progress and increment interruption once. On lifecycle background before 100%, clear the in-memory session and return to Ready without a draft. If background occurs after 100% in Committing, finish the already-started insert; never show Completed until Room returns inserted/already-exists. A commit error exposes retry using the same UUID.
  - Implement phrase choice against the intensity tone, excluding the last 10 phrase IDs globally and preventing the immediately previous category from repeating; use a seeded RNG in tests and a safe built-in fallback.
  - Implement pure UTC/local-date/offset conversion, daily count/sum/average, fixed heatmap thresholds, 3-hour buckets, weekday/intensity distribution, and sample tiers 0-4/5-9/10+/30+.
  Must NOT do: access Android UI, Room, DataStore, random/time globals, persist incomplete sessions, or name internal percentages as medication amount.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 6,7,9,11,13 | Can parallelize with: 3,4,5
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:366-410,414-472,600-616,693-715,734-823,827-887,1156-1166`; `docs/마음자로_PRD.md:257-350,357-395,451-518`; `docs/maeumjaro_pen/integration_contract.json`; `docs/maeumjaro_pen/interaction_design.md:78-95`.
  Acceptance criteria:
  - `./gradlew :app:testDebugUnitTest --tests '*IntensityTest' --tests '*InjectionSessionTest' --tests '*PhraseSelectorTest' --tests '*AggregationTest' --tests '*EventTimeTest'` exits 0.
  - Tests cover all intensity mappings, press/release/resume, cancel, background reset, multi-touch ignore, 100% input lock, commit error/retry with same ID, duplicate category/recent-10 fallback, midnight boundary, past-date stability after offset change, heatmap boundary values, ties, and every sample tier.
  QA scenarios:
  - Happy: replay a fake 3.2-second intensity-5 session with one pause and assert one draft with interruptionCount=1.
  - Failure: inject a commit failure after progress=1.0, retry twice, and assert every attempt carries the same UUID while Completed is emitted only after inserted/already-exists.
  - Evidence: `<attemptDir>/task-2-maeumjaro-android-app.xml` and a state-transition trace JSON.
  Commit: N | proposed later commit `feat(core): define ritual and analytics contracts`.

- [x] 3. Build the Room event source of truth and record lifecycle
  What to do:
  - Add `data/local/MaeumjaroDatabase.kt`, `InjectionEventEntity.kt`, DAOs, mappings, migrations, and `InjectionEventRepository.kt`. Schema fields: UUID primary key, started/completed UTC epoch millis, ISO event local date, timezone offset minutes, intensity CHECK 1..5, source CHECK widget/app, stable phrase ID, animation duration, interruption count, app version, created UTC.
  - Index local date, completed time descending, and `(eventLocalDate, completedAtUtc)`. Aggregate on demand; do not add a materialized daily table.
  - `insertCompletedEvent` must be a transaction whose duplicate UUID result is `AlreadyExists`, not a second row. Retain every event until explicit deletion; Free/Pro filtering belongs above the repository.
  - Provide queries for today totals, latest 10, a date range, 16/52-week daily aggregates, one record, and deterministic chronological export. Individual edit may change only intensity 1..5; timestamps/source/phrase stay factual. Individual delete requires a caller-confirmed action. Bulk delete removes events only, not settings or entitlement.
  Must NOT do: store appetite, weight, health outcomes, incomplete attempts, mutable current-time regrouping, or entitlement in Room.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 7,9,10,11,13 | Can parallelize with: 2,4,5
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:620-649,653-759,827-887,922-951,984-1017`; `docs/마음자로_PRD.md:357-450,536-585`.
  Acceptance criteria:
  - `./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.maeumjaro.app.data.local.MaeumjaroDatabaseTest` exits 0.
  - In-memory Room tests prove duplicate UUID inserts one row, invalid intensity fails, today/date-range queries use stored local date, events older than 52 weeks remain stored, purchase state never alters rows, intensity edit and single/bulk delete recalculate query results, and migration fixtures retain all fields.
  QA scenarios:
  - Happy: seed 112 days spanning two offsets and compare DAO aggregates with a pure Kotlin oracle byte-for-byte.
  - Failure: issue two concurrent inserts with one UUID and assert row count=1; cancel delete and assert the DB checksum is unchanged.
  - Evidence: `<attemptDir>/task-3-maeumjaro-android-app.xml` plus exported query fixture JSON.
  Commit: N | proposed later commit `feat(data): add local completion event store`.

- [x] 4. Add Proto DataStore settings, widget projection, entitlement cache, and no-backup rules
  What to do:
  - Define `app/src/main/proto/app_state.proto` with intensity/default 3, intensityUpdatedAt, haptic=true, sound=false, reducedMotion, phrase tone, onboarding/widget-guide state, theme ID, widget preset state, projection local date/count/intensity sum/updatedAt, and entitlement cache status/product/last verified time.
  - Wrap Proto DataStore in `AppStateStore`; use atomic `updateData`, validation/corruption fallback, and Flow. Last successfully serialized valid write wins for concurrent app/widget intensity changes.
  - Implement `WidgetProjectionReconciler`: Room is authoritative; rebuild the projection after completion, individual edit/delete, bulk delete, app startup/foreground, and local-date rollover. A stale projection date renders zero in the widget until rebuild; projection failure never rolls back a successful Room commit.
  - Add `res/xml/backup_rules.xml` and `data_extraction_rules.xml` and manifest settings that exclude Room, DataStore, export cache, and event files from Auto Backup and device-to-device transfer. Pro can be restored only through Play purchase query.
  Must NOT do: store Room events in DataStore, query Room from widget composition, retry indefinitely in background, or treat cached entitlement as stronger than a fresh Play result.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 7,8,10,12,13 | Can parallelize with: 2,3,5
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:847-858,953-980,984-1017`; `docs/마음자로_PRD.md:189-251,680-789`; DataStore `https://developer.android.com/topic/libraries/architecture/datastore`; Glance state `https://developer.android.com/develop/ui/compose/glance/glance-app-widget`.
  Acceptance criteria:
  - Unit/instrumented tests cover missing/corrupt/out-of-range intensity -> 3, simultaneous updates, every reconciler trigger, stale-date zero, projection write failure after Room success, and preservation of settings/entitlement on record deletion.
  - `apkanalyzer manifest print app/build/outputs/apk/debug/app-debug.apk` plus compiled XML inspection confirms backup/D2D exclusions and no dangerous runtime permissions.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.data.settings` exits 0.
  QA scenarios:
  - Happy: seed Room today totals, corrupt the projection, foreground the app, and assert DataStore/widget values repair to Room.
  - Failure: simulate midnight with yesterday's projection while the app is stopped and assert the widget model is zero rather than yesterday's count.
  - Evidence: `<attemptDir>/task-4-maeumjaro-android-app.txt` and projection trace JSON.
  Commit: N | proposed later commit `feat(state): synchronize local settings and widget projection`.

- [x] 5. Establish navigation, design tokens, onboarding, safe content, and independent asset gates
  What to do:
  - Create the single-activity route graph: first-run onboarding, records dashboard, settings, injection, completion, record detail, safety/info, Pro, and customization. App icon opens onboarding once then records; only the widget/direct in-app action opens injection.
  - Implement five onboarding steps: non-medical purpose, use flow, default intensity, readable disclaimer, optional widget pin guidance. Use `AppWidgetManager.requestPinAppWidget` only after the user acts and provide a manual fallback.
  - Recreate only the reference hierarchy/tokens using original Compose shapes and the user-approved `assets/maeumjaro_pen/` package: warm light canvas, navy/mint/blue/violet accents, responsive cards, native typography, and the layered non-medical ritual pen. Do not extract SVG/CSS/image assets from older prototypes or mimic a named product.
  - Bundle at least 100 Korean phrases with stable IDs/category/intensity tone and `safetyReviewed=true`, plus a built-in fallback. Add a content-contract test that flags positive medical/drug/dose/weight-loss claims while allowlisting only explicit negative disclaimer contexts.
  - Apply edge-to-edge, predictive back, dark/light theme, 48dp targets, localized semantics, large-text-safe layouts, and no color-only meaning from the first screen.
  Must NOT do: implement an in-app “home screen” copied from the phone mock, expose `가상 주입량`, show ads/login/health survey, or ship unapproved brand/store assets.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 6,8,9,10,11 | Can parallelize with: 2,3,4
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:194-280,366-410,494-552,600-616,1021-1083,1136-1144`; `docs/마음자로_PRD.md:55-170,795-963`; `docs/maeumjaro_interactive_product_plan_v1.html:10-36,1240-1339`; `docs/마음자로_기능명세서.png`; `docs/maeumjaro_pen/README.md`; `docs/maeumjaro_pen/interaction_design.md`.
  Acceptance criteria:
  - Compose tests prove first-run/returning/widget route behavior, onboarding skip/persist, intensity validation, disclaimer accessibility, and no intermediate route for widget injection.
  - Phrase catalog test asserts ≥100 unique stable IDs, valid categories/intensities, reviewed status, recent-10 feasibility, and safe fallback; string/resource scan has no unapproved `마운자로`, `Mounjaro`, dose, efficacy, or weight-loss claim.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest :app:lintDebug` exits 0.
  QA scenarios:
  - Happy: clear app data, finish onboarding with default 4, skip pinning, relaunch, and observe records dashboard with setting 4.
  - Failure: inject a missing/unsafe phrase asset and assert the user sees the built-in safe fallback without internal error text.
  - Evidence: `<attemptDir>/task-5-maeumjaro-android-app.txt`, onboarding screenshots, and semantics dump.
  Commit: N | proposed later commit `feat(app): add onboarding navigation and safe design foundation`.

- [x] 6. Implement the press-driven ritual surface, motion, haptics, sound, and accessible input
  What to do:
  - Build `feature/injection/` with `InjectionViewModel`, immutable UI state, full-screen Compose surface, and the approved layered raster pen: ready base at a 1024×1536 reference canvas, liquid window `(449,650,126,414)`, ring viewport `(362,136,300,112)`, progress-linked liquid mask, pause/continue copy, and strength display. Feed all behavior from the pure domain reducer.
  - Implement the final gesture contract before hold progress: locked swipes horizontally to unlock on pointer-up, ready can horizontally relock before hold starts, hold begins after 120ms only on a new pointer sequence, and the single ring uses `graphicsLayer(rotationY)` rather than opacity fade or sliding faces.
  - Use `awaitEachGesture`/primary pointer ownership so progress advances only while the first pointer is down; additional pointers do nothing. Use frame time, not fixed delay loops. Pointer release/cancel pauses; lifecycle background before completion resets through the reducer.
  - Fire start/progress/completion haptics at intensity-dependent thresholds through capability-checked Android haptic APIs with restrained fallback. Sound is an approved bundled cue, defaults OFF, stops on pause/background, and never replaces visual feedback.
  - Reduced Motion removes bubbles/pulses/large transforms but preserves numeric progress, liquid level, pause state, and completion proximity. Normal motion must stay frame-stable.
  - Add TalkBack semantics for intensity/state/progress and custom accessibility actions `시작/재개` and `일시 정지`. These actions are the accessibility equivalent of physical hold and use the same state machine, duration, interruption, and completion rules. Provide a long-click semantic action for TalkBack; do not add a separate instant-complete path.
  Must NOT do: detect body contact, use camera/mic/proximity/health sensors, vibrate continuously, expose a dose/amount label, or write a completion event in this UI layer.
  Parallelization: Wave 2 | Blocked by: 2,5 | Blocks: 7,14 | Can parallelize with: 9,10
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:366-517,1136-1144,1156-1166`; `docs/마음자로_PRD.md:257-350,654-725`; `docs/maeumjaro_interactive_product_plan_v1.html:1263-1326,1572-1576,1731-1806`; `docs/recording.mp4` (timing/composition reference only); `docs/maeumjaro_pen/integration_contract.json`; `docs/maeumjaro_pen/interaction_design.md:56-95`; `docs/maeumjaro_pen/qa.md:37-41`.
  Acceptance criteria:
  - Compose tests with a controlled frame clock verify all five durations/mappings, start response state within one frame, pause/resume without progress drift, extra-pointer ignore, cancel/background reset, setting changes, reduced-motion state, and accessible custom actions.
  - No Room DAO/repository is imported by `feature/injection` composables; the ViewModel emits one completion draft intent only after 100%.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.feature.injection` exits 0.
  QA scenarios:
  - Happy: on a physical device run intensity 1 and 5, pause once, resume, and capture screen recording plus haptic checklist showing visibly distinct duration/density.
  - Failure: disable system haptics, enable Reduce Motion and 200% font, then finish by TalkBack custom actions; progress and completion intent remain unambiguous with no clipping.
  - Evidence: `<attemptDir>/task-6-maeumjaro-android-app.mp4`, test XML, frame trace, and device/haptic matrix.
  Commit: N | proposed later commit `feat(ritual): implement accessible press-driven interaction`.

- [ ] 7. Connect exact-once completion, phrase selection, event commit, and widget projection
  What to do:
  - Add `CompleteInjectionUseCase`: freeze the draft at 100%, choose an eligible reviewed phrase, insert the event in Room by its session UUID, query current local-date totals, then attempt DataStore projection update and `Glance updateAll`.
  - Treat `Inserted` and `AlreadyExists` as the same domain success. Input remains locked in `Committing`; the completion screen appears only after DB success and shows strength, automatic completion time, safe phrase, `다시 실행`, and `기록 보기`.
  - On DB error enter `CommitFailed` with a retry action using the same UUID and frozen timestamps/phrase; do not emit another draft. If projection/widget update fails after DB success, show completion, record a non-sensitive diagnostic, and let the reconciler repair later.
  - Source is `widget` only for verified widget launch and otherwise `app`. A widget intent never supplies the trusted intensity. Background before 100% clears without save; background after entering Committing does not cancel the already-started insert.
  Must NOT do: save start/pause events, show success before persistence, generate a new UUID on retry, attach detailed events to crash logs, or ask an outcome/food question.
  Parallelization: Wave 2 | Blocked by: 2,3,4,6 | Blocks: 8,10,14 | Can parallelize with: 9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:521-616,827-887,953-968,1156-1166`; `docs/마음자로_PRD.md:298-395`; `docs/maeumjaro_interactive_product_plan_v1.html:1808-1848` (simplified reference; production schema overrides it).
  Acceptance criteria:
  - Integration tests prove normal, double-callback, rotation/recreation, Room duplicate, Room failure/retry, projection failure, widget/app source, midnight crossing, and phrase fallback paths all leave 0 rows before completion and exactly 1 row after successful completion.
  - Persisted event contains every PRD field and uses the completion instant's local date/offset; retry preserves all draft values.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.feature.completion` exits 0.
  QA scenarios:
  - Happy: launch from app and widget, complete each once, then query the debug DB and confirm two events with different sources and refreshed widget totals.
  - Failure: inject a Room exception, confirm no completion screen and a retry affordance, restore DB, retry twice, and confirm one event.
  - Evidence: `<attemptDir>/task-7-maeumjaro-android-app.txt`, DB dump, UI recording, and projection trace.
  Commit: N | proposed later commit `feat(completion): persist one completed ritual event`.

- [ ] 8. Deliver the persisted-state Glance widget and direct cold/warm launch
  What to do:
  - Add `widget/MaeumjaroWidget.kt`, receiver, responsive 2x2/4x2 layouts, preview, `ChangeIntensityAction`, direct-start action, and updater. Show brand, current strength, disabled boundary controls, today's count/sum, and the start button with 48dp targets and light/dark contrast.
  - Each ± callback atomically updates Proto DataStore, clamps 1..5, and calls `updateAll`; all placed instances render the same value. Do not keep correctness state in widget memory or a separate process.
  - Start `MainActivity` with only `source=widget`. On cold start and `onNewIntent`, route directly to injection and reread DataStore; invalid/missing/read-failed state becomes intensity 3. Skip onboarding only if it was completed; otherwise preserve the safety onboarding gate, then continue to injection.
  - A stale projection date displays zero totals; app startup/foreground and mutation operations reconcile it. Widget composition never opens Room.
  Must NOT do: use periodic minute refresh, trust a strength extra, show yesterday as today, create one DataStore per widget, or navigate through the records dashboard.
  Parallelization: Wave 2 | Blocked by: 4,5,7 | Blocks: 13,14 | Can parallelize with: 9,10
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:287-362,922-980`; `docs/마음자로_PRD.md:176-251,680-789`; `docs/마음자로_기능명세서.png`; Glance `https://developer.android.com/develop/ui/compose/glance/create-app-widget`, `https://developer.android.com/develop/ui/compose/glance/glance-app-widget`, widget quality `https://developer.android.com/docs/quality-guidelines/widget-quality`.
  Acceptance criteria:
  - Instrumented tests cover 1/5 disabled states, missing/corrupt default 3, rapid concurrent callbacks, multiple widget instances, stale date, app process killed, incomplete onboarding, cold `Intent`, warm `onNewIntent`, and all-instance refresh.
  - Static dependency check confirms widget package has no Room DAO/database import.
  - `./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.widget` exits 0.
  QA scenarios:
  - Happy: add two widget sizes in the actual Pixel launcher, change intensity in one, observe both update, kill the app, tap start, and verify direct injection uses the persisted strength.
  - Failure: place a yesterday projection/corrupt intensity, stop the app, refresh widget, and observe totals 0/intensity 3 without crash; foreground app repairs authoritative totals.
  - Evidence: `<attemptDir>/task-8-maeumjaro-android-app.mp4`, launcher screenshots, logcat, and DataStore snapshot.
  Commit: N | proposed later commit `feat(widget): add synchronized direct-start Glance widget`.

- [x] 9. Build the Free records dashboard, 16-week heatmap, day detail, and record correction
  What to do:
  - Implement dashboard cards for today's count/sum/average, latest 10, a 30-day Free history list, and a Monday-first 16-week contribution-style heatmap with count/intensity toggle and fixed levels. Future cells are disabled.
  - Tapping a cell opens a bottom sheet with date, count, intensity sum/average, and chronological time chips. Empty, 0-4, and 5-9 sample states are neutral and never describe success, failure, appetite, risk, or streak.
  - Record detail shows time, intensity, source, and resolved phrase. Allow correction of intensity only and single-record deletion after confirmation; both recompute dashboard and widget projection. Missing/deprecated phrase IDs display the safe fallback.
  - Follow the screenshot information hierarchy while reimplementing original Compose visuals; the screenshots are not pixel assets.
  Must NOT do: delete or truncate events outside the chosen UI window, change factual timestamps, infer health outcomes, reward higher counts, or lock the 16-week heatmap behind Pro.
  Parallelization: Wave 2 | Blocked by: 2,3,5 | Blocks: 11,14 | Can parallelize with: 6,10
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:620-823`; `docs/마음자로_PRD.md:398-518`; `docs/Screenshot 2.jpg`; `docs/Screenshot 3.jpg`; `docs/maeumjaro_interactive_product_plan_v1.html:1991-2100`.
  Acceptance criteria:
  - Pure aggregate results and rendered labels match seeded Room fixtures for every heatmap boundary, future date, empty state, timezone offset, tied maximum, edit, and delete.
  - Compose semantics identify every cell by date/count/sum rather than color alone; 200% font and narrow screen tests have no clipped primary actions.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.feature.history` exits 0.
  QA scenarios:
  - Happy: load the deterministic 112-day fixture, switch count/intensity, open 2026-09-04 detail, edit one intensity, and verify DB, summary, heatmap, and widget all agree.
  - Failure: cancel edit/delete and assert DB/projection checksums unchanged; open a missing phrase and verify safe fallback.
  - Evidence: `<attemptDir>/task-9-maeumjaro-android-app.txt`, screenshots, semantics dump, and DB/projection diff.
  Commit: N | proposed later commit `feat(history): add factual local records and heatmap`.

- [ ] 10. Finish settings, privacy controls, CSV export, and destructive-action safeguards
  What to do:
  - Implement settings for default intensity, haptics, sound, Reduce Motion, bundled phrase tone, widget setup help, full disclaimer, Pro entry, data export, and all-record deletion. Every setting writes DataStore and immediately affects app/widget where applicable.
  - CSV export is available to all users and includes all locally retained events, not only the visible 30 days: schema marker `maeumjaro-export-v1`, UTF-8 with BOM, RFC 4180 escaping, chronological ascending order, and the complete event fields from Todo 3. Create it in app cache and expose only via scoped `FileProvider`/Android Sharesheet after an explicit user tap.
  - Empty export creates no file. Cancellation/failure leaves source records untouched. Bulk deletion requires a clear confirmation, deletes Room events only, refreshes dashboard/widget to zero, and preserves settings/onboarding/Pro entitlement.
  - Add non-sensitive error messages and ensure temp export files are not backed up; never log row contents or automatic-share a target.
  Must NOT do: request storage/media permissions, automatically upload/share, delete settings or purchases, or make CSV a Pro gate.
  Parallelization: Wave 2 | Blocked by: 3,4,5,7 | Blocks: 14,15 | Can parallelize with: 8,9
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:207-225,984-1017,1315-1336`; `docs/마음자로_PRD.md:118-170,523-648`.
  Acceptance criteria:
  - Tests verify each default/persistence rule, complete deterministic CSV bytes, Korean/quote/newline escaping, empty/cancel/failure behavior, FileProvider URI grants, delete confirmation/cancel, and settings/entitlement preservation.
  - Manifest/runtime permission inspection finds no broad storage permission; no export or delete occurs before explicit confirmation.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.feature.settings` exits 0.
  QA scenarios:
  - Happy: export seeded events through the Android Sharesheet to local Files, reopen the CSV, then bulk-delete and verify records/widget are zero while settings remain.
  - Failure: cancel Sharesheet and deletion confirmation; compare DB/DataStore hashes before/after and assert no external delivery claim.
  - Evidence: `<attemptDir>/task-10-maeumjaro-android-app.mp4`, exported CSV, test XML, and before/after hashes.
  Commit: N | proposed later commit `feat(settings): add local data controls and CSV export`.

- [ ] 11. Add Pro-gated 52-week history, factual pattern analysis, comparison, and JSON export
  What to do:
  - Introduce an `EntitlementRepository` interface and use-case-level gates, initially backed by a debug fake. Free remains exactly as Todo 9/10; Pro unlocks a 52-week history/detail range, eight 3-hour time buckets, Monday-Sunday distribution, intensity 1..5 distribution, and recent 4 weeks versus previous 4 weeks.
  - Enforce sample contracts: 0-4 `기록이 더 필요해요`, 5-9 preliminary facts only, 10+ time/weekday summaries, 30+ four-week comparison. Ties list all tied buckets or use neutral copy; never pick an arbitrary winner or infer appetite/success/risk.
  - JSON export is Pro-only and covers every locally retained event in chronological order with top-level `schemaVersion=maeumjaro-export-v1`, `exportedAtUtc`, and `events`. CSV remains Free and unchanged.
  - Put entitlement checks in use cases (`VisibleHistoryRange`, `DetailedPatterns`, `JsonExport`) as well as navigation; locked screens never compute or leak Pro result data. Buying Pro later reveals existing records without migration.
  Must NOT do: collect new health data, delete records older than visible windows, expose Pro data before entitlement, or copy the browser prototype's fixed-112-day average bug.
  Parallelization: Wave 3 | Blocked by: 2,3,5,9 | Blocks: 12,13,14
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:653-823,1087-1132,1315-1336`; `docs/마음자로_PRD.md:451-518,588-648`; `docs/Screenshot 2.jpg`; `docs/Screenshot 3.jpg`; `docs/maeumjaro_interactive_product_plan_v1.html:1991-2100`.
  Acceptance criteria:
  - Tests assert Free/Pro matrices, all sample thresholds, ties, zero data, 3-hour boundaries, weekdays from stored local date, intensity ratios, two non-overlapping 4-week windows, purchase-later unlock, and no row mutation.
  - JSON bytes are deterministic apart from injected export time and preserve all event fields; Free invocation returns a typed Locked result without generating a file.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.feature.analytics` exits 0.
  QA scenarios:
  - Happy: seed 52+ weeks, switch fake entitlement Free→Pro, verify 16→52 week views, threshold copy, distributions, comparison, and exported JSON.
  - Failure: use 4/9/29 events and tied buckets, confirming neutral low-sample/tie copy and no medical or success interpretation.
  - Evidence: `<attemptDir>/task-11-maeumjaro-android-app.txt`, screenshots, JSON, and aggregate oracle diff.
  Commit: N | proposed later commit `feat(pro): add gated local pattern analysis`.

- [ ] 12. Integrate one-time Play Billing entitlement and restoration
  What to do:
  - Add `billing/PlayBillingEntitlementRepository.kt` for a non-consumable one-time product with provisional internal ID `pro_lifetime`; the final Play Console ID is an OWNER/EXTERNAL GATE before release.
  - Model `Unknown`, `Free`, `Pending`, `Pro`, and `Error`. Query owned purchases when Billing connects, on app foreground, after purchase callback, and explicit `구매 복원`. Grant only verified `PURCHASED`; never grant `PENDING`. Acknowledge eligible purchases within three days and make processing idempotent by purchase token.
  - Cache only the last confirmed Pro entitlement for offline continuity. A connection/query error preserves last confirmed Pro but exposes refresh state; a successful authoritative query with no owned product returns Free and handles refund/revocation. No app account or health data participates.
  - Provide fake repository tests for every state and Play Billing license-tester instructions/evidence checklist. Core ritual, Free history, delete, and CSV must remain usable when Billing is offline or broken.
  - Document the accepted client-only limitation: no server verification, weaker tamper/refund freshness, corrected on the next successful Play query.
  Must NOT do: create a subscription/consumable, use cached Pro as proof for a new purchase, grant Pending/Error, add a backend, or block Free surfaces on Play availability.
  Parallelization: Wave 3 | Blocked by: 4,5,11 | Blocks: 13,14,15
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:1315-1336`; `docs/마음자로_PRD.md:588-648`; Billing integration `https://developer.android.com/google/play/billing/integrate`; one-time products `https://developer.android.com/google/play/billing/one-time-products`; Billing test `https://developer.android.com/google/play/billing/test`.
  Acceptance criteria:
  - Unit/instrumented tests cover connect failure, product unavailable, success, cancel, error, Pending→Purchased, duplicate callback, acknowledgement retry, foreground query, explicit restore, offline cached Pro, successful no-purchase downgrade, reinstall/restore, and wrong Play account.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.billing` exits 0.
  - On an authorized internal Play track, a license tester proves purchase, pending transition, cancel/failure, no repurchase of owned non-consumable, reinstall restore, and acknowledgement; without this external state the task is implemented but not release-verified.
  QA scenarios:
  - Happy: purchase with license tester, kill/reinstall, tap restore, and observe Pro history without loss of local-only Free behavior assumptions.
  - Failure: force Play offline/Pending/cancel; Pro stays locked or cached according to the state table while ritual/Free/CSV remain usable.
  - Evidence: `<attemptDir>/task-12-maeumjaro-android-app.txt`, entitlement trace, and Play test screenshots/receipt state with tokens redacted.
  Commit: N | proposed later commit `feat(billing): add one-time Pro entitlement`.

- [ ] 13. Implement Pro themes, locally validated custom phrases, and per-widget intensity presets
  What to do:
  - Add a small approved theme catalog and let Pro select it; Free keeps the default. Theme changes must preserve contrast, semantics, reduced-motion behavior, and independent branding.
  - Add `custom_phrases` Room storage with local ID, text, tone/category, created time, validation state, and archived flag. Validate locally against explicit positive medical/dose/efficacy/weight-loss patterns before making a phrase eligible. Invalid text remains editable but is never selected; selection falls back safely. If a referenced phrase is deleted, archive it so historical phrase resolution remains possible.
  - Extend phrase selection so valid active custom phrases join the built-in pool without bypassing recent-10/category rules. Export events retains only `phraseId`; custom text is not automatically shared.
  - Add per-`appWidgetId` optional preset intensity in DataStore. This is an explicit Stage-B override of the Free all-widgets-same-strength rule: widgets without a preset follow global intensity; a preset widget displays its fixed strength. Starting from a preset first atomically writes that strength to global intensity, refreshes non-preset widgets, then launches so the app rereads the same value. Delete per-instance state in receiver `onDeleted`.
  - Manage presets from settings and clearly label fixed versus global widgets. Keep today's projection shared across all widgets.
  Must NOT do: allow user text to claim app efficacy on completion, upload custom text, let a preset Intent bypass DataStore, weaken the Free widget behavior, or add downloadable themes.
  Parallelization: Wave 3 | Blocked by: 2,3,4,5,8,12 | Blocks: 14,15
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:600-616,1287-1303,1315-1336`; `docs/마음자로_PRD.md:865-963`; widget preset requirement `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:1289-1294`.
  Acceptance criteria:
  - Tests cover entitlement gates, contrast/token contracts, custom phrase safe/unsafe/missing/archived/recent-10/category cases, no text in export, per-widget preset/global state, preset launch ordering, multiple instances, and deleted widget cleanup.
  - `./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=com.maeumjaro.app.feature.customization` exits 0.
  QA scenarios:
  - Happy: create a neutral phrase, select a Pro theme, assign intensity 5 to one of two widgets, launch it, and confirm app/global widget=5 while the other fixed preset stays unchanged.
  - Failure: enter a prohibited efficacy/dose phrase and revoke Pro; the phrase is never selected, default theme/Free surfaces remain usable, and no local event is deleted.
  - Evidence: `<attemptDir>/task-13-maeumjaro-android-app.mp4`, screenshots, phrase validation report, and widget-state dump.
  Commit: N | proposed later commit `feat(pro): add safe local customization`.

- [ ] 14. Harden accessibility, offline behavior, lifecycle correctness, backup isolation, and performance
  What to do:
  - Add `benchmark/` with startup Macrobenchmarks and Baseline Profile generation. Measure widget-to-injection cold/warm launch, Compose frame timing during intensity-5 motion, and actual launcher widget refresh on the reference device contract in Verification strategy.
  - Run the full lifecycle matrix: process stopped, `onNewIntent`, configuration recreation, screen off/on, background before/after 100%, device reboot, app update, two simultaneous widget callbacks, local midnight, timezone/DST change, storage failure, and low-memory/process death. No case may create a partial/duplicate event or stale “today” count.
  - Run accessibility on every major surface with Compose UI Check, Accessibility Scanner, TalkBack, Switch Access, 200% font, dark/light, reduced motion, haptics off/unsupported, sound off, and narrow/large screens. Preserve a visible/announced alternative for every state.
  - Run airplane-mode core flow, inspect manifest/network traffic/logcat for prohibited data and permissions, verify no detailed event in logs/crash artifacts, and verify backup/D2D exclusion with `bmgr`/device-to-device test where supported.
  - Treat product KPIs only as development/closed-beta QA measurements. Do not persist raw incomplete attempts in production Room or add telemetry; use test harness counters and benchmark outputs.
  Must NOT do: relax requirements to hit timing, fake launcher/widget evidence with an in-app mock, claim subjective haptic quality from emulator, or call static manifest inspection a complete backup test.
  Parallelization: Wave 3 | Blocked by: 6-13 | Blocks: 15,F1-F4
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:333-362,1087-1166,1178-1216`; `docs/마음자로_PRD.md:654-789`; Compose testing `https://developer.android.com/develop/ui/compose/testing`; accessibility testing `https://developer.android.com/guide/topics/ui/accessibility/testing`; core quality `https://developer.android.com/docs/quality-guidelines/core-app-quality`.
  Acceptance criteria:
  - `./gradlew testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest :benchmark:connectedCheck` exits 0 and the generated baseline profile is packaged in release artifacts.
  - Reference-device p95 satisfies widget update ≤500ms, warm ≤1.5s, cold ≤3s; frame trace has no persistent jank during intensity-5. Failed device rows stay failed and include cause/action.
  - Automated permission/content/log scans are clean; backup/D2D restore contains no Room/DataStore records; core app runs in airplane mode; accessibility audit has no blocker.
  QA scenarios:
  - Happy: complete the documented core flow from real widget in airplane mode with TalkBack off/on and capture database/widget/semantics evidence.
  - Failure: interrupt at every lifecycle boundary and inject projection/Billing/storage failures; verify no duplicate/partial event, no stale date, no Free lockout, and safe fallback UI.
  - Evidence: `<attemptDir>/task-14-maeumjaro-android-app/` containing benchmark JSON, Perfetto trace, TalkBack video, Accessibility Scanner report, network/log scan, and device matrix.
  Commit: N | proposed later commit `test(android): harden lifecycle accessibility and performance`.

- [ ] 15. Prepare the release artifact, privacy declarations, and irreversible owner gates
  What to do:
  - Replace provisional identity only after owner confirmation of final brand, controlled `applicationId`, signing owner, independent icon/ritual/widget assets, and trademark review. Until then create internal artifacts only and label them non-production.
  - Finalize Korean store copy, full non-medical disclaimer, privacy policy document/URL, Data Safety answers, Health Apps Declaration assessment, content rating, screenshots, widget preview, and Pro one-time product copy without medical efficacy/dose language.
  - Configure R8/resource shrinking, reproducible release versioning, signed AAB through an approved secret mechanism, mapping/native symbol artifacts, dependency/license report, and `bundletool` install test. Never place keystore passwords or purchase tokens in the workspace/evidence.
  - OWNER/EXTERNAL GATE checklist: final identity/signing approval, legal/brand/asset approval, privacy URL live, Play product active with license tester, real-device QA matrix accepted, and explicit authorization before any Play upload/publish. A local AAB is not a submitted or accepted release.
  - If authorized, upload only to the approved internal/closed track, then separately capture processing success, install-from-Play, Billing product visibility, pre-launch report, and reviewer receipt. Do not equate button click/upload selection with acceptance.
  Must NOT do: publish publicly, invent ownership of a package/domain/keystore, reuse reference assets, hide client-only Billing limitations, or claim store acceptance without the corresponding observed state.
  Parallelization: Wave 3 | Blocked by: 10,12,13,14 | Blocks: F1-F4
  References: `docs/maeumjaro_minimal_mind_control_app_prd_v3_2026-09-04.md:984-1083,1136-1216,1278-1336`; `docs/마음자로_PRD.md:795-963`; target/API and quality `https://developer.android.com/google/play/requirements/target-sdk`, `https://developer.android.com/docs/quality-guidelines/core-app-quality`.
  Acceptance criteria:
  - `./gradlew clean bundleRelease lintRelease` and `bundletool validate --bundle app/build/outputs/bundle/release/app-release.aab` exit 0 after approved signing configuration.
  - `bundletool build-apks`/install on reference devices passes; manifest permissions, backup rules, content scan, dependency licenses, symbols/mapping, versioning, and privacy declarations match the release artifact checksum.
  - Every external gate has observed evidence or remains explicitly incomplete; no “release ready/submitted/accepted” wording is used while one is open.
  QA scenarios:
  - Happy: install the exact release-derived APK set, run onboarding→widget→ritual→record→export→restore Pro, and match artifact checksum to all reports.
  - Failure: remove product availability or privacy URL and verify the release checklist blocks upload/approval without weakening app behavior.
  - Evidence: `<attemptDir>/task-15-maeumjaro-android-app/` containing AAB checksum, bundletool logs, store metadata, declaration checklist, signed-off asset list, and track receipt if authorized.
  Commit: N | proposed later commit `chore(release): prepare Android store candidate`.

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit
  - Independently map every Must have and every cited PRD acceptance criterion to implementation, automated test, and evidence. Verify the approved Free/Pro override is explicit and no source conflict was silently reintroduced.
  - Run full Gradle verification once against the final SHA/artifact checksum. Verdict must be `APPROVE`; any missing mapping or red test is blocking.
  - Evidence: `<attemptDir>/final-f1-plan-compliance.md`.
- [ ] F2. Code quality review
  - Review the final diff for single-source-of-truth violations, Compose/UDF lifecycle bugs, coroutine leaks, Room/DataStore races, unsafe Billing state, accessibility regressions, secret/PII logging, migration risk, and unnecessary architecture.
  - Require zero P0/P1 findings and resolve P2 correctness findings; stylistic preferences alone do not expand scope. Bind verdict to final SHA or AAB checksum.
  - Evidence: `<attemptDir>/final-f2-code-quality.md`.
- [ ] F3. Real manual QA
  - On actual Android launcher and physical devices, execute first-run onboarding, two widget sizes, cold/warm direct launch, all five intensities, pause/resume, background reset, haptic off/on, Reduce Motion, TalkBack/Switch Access, records/heatmap/edit/delete, CSV, Pro purchase/restore, JSON/customization, airplane mode, reboot/date rollover, and release-derived install.
  - Record the strongest observed state separately for local build, installed artifact, Play upload, processing, install-from-Play, and store acceptance. All required device rows must pass.
  - Evidence: `<attemptDir>/final-f3-manual-qa/` with video, screenshots, device matrix, DB/projection dumps, and receipts.
- [ ] F4. Scope fidelity
  - Prove absence of iOS/Flutter/server/login/ads/remote analytics/dangerous permissions/medical claims/copied reference assets and confirm all external owner gates are either approved with evidence or explicitly incomplete.
  - Compare manifest, dependency graph, network trace, resources, and user-facing copy to Must NOT have. Verdict must be `APPROVE` before release-ready claim.
  - Evidence: `<attemptDir>/final-f4-scope-fidelity.md`.

## Commit strategy

- The workspace is not currently a Git repository. Do not run `git init`, create branches, or claim commits without explicit user authorization.
- If Git is initialized separately before execution, use one conventional commit per completed Todo after its targeted tests pass; never mix unrelated user files or the original `docs/` references into cleanup commits.
- Suggested sequence follows the Todo commit labels. Rebase/squash only on request. Every final audit binds to one full commit SHA; without Git, bind all reports to the same release AAB SHA-256 and source-tree manifest checksum.
- Never commit signing keys, `local.properties`, Play receipts/tokens, exported user data, device logs containing identifiers, or `<attemptDir>` secrets.

## Success criteria

- A native Android app and responsive Glance widget implement the documented core flow without an in-app intermediate home, network dependency, login, ads, health permissions, or medical efficacy/dose claims.
- All five intensities, hold/pause/resume/background behavior, haptic/visual fallbacks, safe phrase selection, and exact-once completion persist correctly across lifecycle and failure cases.
- Room remains the event source of truth; DataStore remains settings/widget projection; Play remains entitlement authority. Reconciliation repairs projection failures without rolling back valid events.
- Free and Pro behave exactly as the approved matrix: all events retained locally; Free 30-day list/16-week heatmap/CSV; Pro 52-week detail/patterns/JSON/themes/custom phrases/widget presets; prior records unlock after purchase.
- Dashboard, heatmap, details, distributions, exports, edits, deletes, and widget totals match deterministic fixtures for midnight/timezone/DST, empty data, thresholds, ties, and large histories.
- Automated suite, lint, debug/release builds, migrations, instrumentation, Macrobenchmark, accessibility checks, offline tests, content/permission/log scans, and backup/D2D exclusion pass against one final artifact identity.
- Reference-device p95 meets widget update ≤500ms, warm direct launch ≤1.5s, cold direct launch ≤3s; real-device haptic and launcher behavior are observed, not inferred from emulator/source.
- Final brand, package ID, signing, independent assets, privacy URL/declarations, Play product, license-tester flow, and release track evidence pass their external gates before any release-ready/submitted/accepted claim.
- F1-F4 all return `APPROVE`, their evidence binds to the final SHA/checksum, and the user gives explicit final acceptance.
