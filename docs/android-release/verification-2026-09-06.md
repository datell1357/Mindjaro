# Android 후속 검증 — 2026-09-06

## 추가 구현 및 재검증

- 사용자 문구 편집 폼과 기존 ID 기반 저장을 연결했다. 문구별 편집·보관 버튼에 대상 문구 접근성 설명을 추가했다.
- 작은 위젯에 불투명 배경과 명시적 글자색, 횟수·강도 합계를 적용했다. 고정 높이 안의 두 줄 강도 표시는 한 줄로 줄이고 고정/전역 구분은 접근성 설명에 보존했다.
- release 코드·리소스 축소를 활성화했다.
- 최종 수정 후 `:app:testDebugUnitTest :app:lintDebug :app:connectedDebugAndroidTest :app:assembleDebug :app:bundleRelease :benchmark:assembleBenchmark` 성공(6분 10초).
- 단위 테스트 183개, API 29 기기 테스트 55개: 실패·오류·스킵 0. `git diff --check`와 오프라인·백업 정적 게이트도 통과했다.
- 최종 비서명 AAB SHA-256: `7778b0109433ea22060958a3076c2eb04c554bff0785be4c58c20dc88f4698d4`.
- 축소된 AAB에 `baseline.prof` 10,516바이트, `baseline.profm` 1,155바이트 및 난독화 매핑이 포함됐다. AAB 빌드는 출시 파생 APK의 실제 설치 검증을 대체하지 않는다.
- API 37 홈 화면에서 compact 위젯 2개가 강도 5로 함께 갱신되고 실제 시작 버튼이 마음 정리 화면을 여는 것을 확인했다. 아래의 이전 위젯 목록 ANR 기록과 구분한다. 증거는 `.omo/evidence/finish-widget-runtime/01-warm-two-widgets-show-5.png`, `02-start-opens-injection.png`이다. 이후 에뮬레이터 재부팅으로 최종 큰 글꼴·크기 변경·cold 경로 수락은 별도 QA가 필요하다.
- 첫 축소 빌드는 생성에 성공했지만 실제 실행에서 protobuf `intensity_` 필드 이름 변경으로 초기화 충돌했다. 따라서 위 해시의 AAB는 배포 대상으로 사용하지 않는다. 생성된 lite 메시지 필드 보존 규칙을 추가해 재검증한다.

### 축소 실행 충돌 수정 후

- protobuf lite 생성 메시지의 필드명을 보존해 시작 충돌을 수정했다.
- 수정 후 AAB SHA-256: `c406aafd8bdef417fac7085b0d94a4b145a60613a306547ac2b04f02c49d9f4f`.
- `baseline.prof` 10,593바이트와 `baseline.profm` 1,146바이트가 포함됐다.
- 동일 축소 설정의 `benchmarkRelease` 앱에서 cold/warm 시작 각 10회 통과. 초기 표시 시간 중앙값은 cold 1,218.89ms, warm 251.15ms였다. API 29 에뮬레이터 측정이며 실제 기기 성능 목표 통과를 의미하지 않는다.
- 위젯 cold/warm 성능 2개는 측정 기기에 실제 위젯이 없어 스킵됐다. 미검증 게이트로 유지한다.
- 실제 강도 5 측정에서 완료 확인이 실패해 두 테스트 조건을 수정했다. 누르기 인식 지연 120ms를 포함하도록 입력을 3.3초에서 4초로 늘렸고, 저장 직후 자동 이동하는 완료 화면의 제목을 확인하도록 했다. 앱의 강도별 진행 시간과 완료 로직은 변경하지 않았다.
- 수정 후 `intensityFiveFrameTiming` 단독 실행 통과(2분 58초, 5회 반복, 스킵 없음). 실제 unlock → hold → 저장 후 완료 화면까지 확인했다.
- 프레임 CPU 시간 P50 56.63ms, P95 98.00ms, P99 139.19ms. 측정 실행은 성공했지만 이 결과를 60fps 또는 성능 목표 달성으로 표현하지 않는다. 실제 기기 프로파일링과 성능 수락은 남아 있다.
- 마지막 회귀/축소 실행/프레임 로그와 프레임 JSON은 `.omo/evidence/finish-android-verification/`에 보존했다. API 37은 `sys.boot_completed=1` 이후에도 부팅 화면·런처 부재가 지속되어 추가 위젯 QA를 완료하지 못했다. 데이터 초기화는 하지 않았다.

아래는 이전 프로파일 수집 시점 기록이며, 위 최종 AAB 해시·크기와 구분한다.

## 통과

- `:app:generateReleaseBaselineProfile`: API 29 에뮬레이터 `AIQuotaFixQA20260905`에서 성공. 실제 온보딩 → 기록 → 마음 정리 진입 경로를 사용했다.
- 생성한 `app/src/release/generated/baselineProfiles/baseline-prof.txt`: 20,150줄, `Lcom/maeumjaro/`를 포함하는 규칙 1,222줄.
- `:app:bundleRelease :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --no-daemon --no-parallel --no-configuration-cache --offline`: 성공.
- 단위 테스트 XML 합계: 183개, 실패·오류·스킵 0개.
- AAB에 `baseline.prof`(25,398바이트), `baseline.profm`(2,119바이트) 포함. 병합 프로파일에도 앱 규칙 1,222줄 존재.
- `tools/automation/verify_android_gates.sh` 정적 검사와 `git diff --check` 성공.

## 산출물

- 비서명 AAB: `app/build/outputs/bundle/release/app-release.aab`
- AAB SHA-256: `852d522aeb64b757a683d932a90cb80d05aa9387c91170ce7e95069921aafca2`
- 생성 프로파일 SHA-256: `473d407d9de03d98b70215d2ce2215177bf4ebe2610bbcde5f625e94b8ed79ae`

## 아직 통과하지 않은 항목

- 프로파일 수집 작업에서는 Macrobenchmark 시간 측정 5개가 스킵되었다. 수집 성공은 시작 시간·프레임·위젯 갱신 성능 목표 달성의 증거가 아니다.
- 별도 startup profile은 생성하지 않았다. 앱 아이콘 진입 프로파일이지 위젯 경로 프로파일이 아니다.
- Baseline Profile 플러그인 `1.5.0-rc02`는 release candidate다. 현재 AGP `9.3.2`와의 로컬 구성·빌드·수집 성공만 확인했다.
- 위젯의 responsive 크기 선택과 48dp 조작 영역을 보완했으나, API 37 Pixel 런처에서 위젯 목록 탐색 중 런처 ANR이 발생했다. 두 크기 배치·동시 갱신·실제 위젯 cold/warm 진입은 미완료다. 원인을 마음자로 앱으로 단정하지 않는다.
- 이번 실행에서 전체 앱 connected 테스트는 재실행하지 않았다. 기존 108개 통과 기록을 이번 수정 후 실행 결과로 재사용하지 않는다.
- 실제 기기 햅틱·TalkBack·Play Billing·서명·스토어 제출은 미검증이다.

로컬 런처 캡처는 `.omo/evidence/resume-widget-runtime/root-maeumjaro-list.png`에 보존했다. 증거 폴더와 AAB는 Git 추적 대상이 아니다.
