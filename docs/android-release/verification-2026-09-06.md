# Android 후속 검증 — 2026-09-06

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
