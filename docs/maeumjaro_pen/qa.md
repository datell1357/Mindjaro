# 마음자로 펜 에셋 검증 기록

검수일: 2026-09-04  
검수 브라우저: Aside Browser  
검수 대상: 현재 `assets/maeumjaro_pen/`에 패키징된 2.5D 상태 및 레이어 에셋

## 검증 완료 항목

### 오류 재현과 교정

- 수정 전 실제 포인터: 해제 후 반대 방향 드래그를 하면 `ready → paused`가 되어 다시 잠기지 않았다.
- 원인: `ready`의 새 pointer down을 곧바로 주입 홀드로 예약하고, pointer move는 `swiping`에서만 처리했다.
- 수정 후 실제 포인터: `locked → ready → relocking(left, 50%) → locked`가 한 링의 3D Y축 회전으로 완료됐다. 해제는 `0deg → ±180deg`, 재잠금은 `±180deg → ±360deg`로 이어지며, 두 링 이미지를 좌우로 미는 방식은 제거했다.
- 회귀 테스트: `interaction_contract_test.js`는 수정 전 `Unlocked state must expose a relock transition`으로 실패했고, 수정 후 `interaction contract: 3D relock + continuous liquid layer OK`로 통과했다.

### 액체 연속 감소

- 수정 전에는 완성 펜 이미지의 액체 위로 빈 창 이미지를 확대해 덮었기 때문에 중간 상태가 직선으로 잘린 교체 이미지처럼 보였다.
- 수정 후에는 빈 창을 고정하고 독립 액체 레이어 `maeumjaro_pen_2d_liquid_full.png`의 마스크와 내부 이미지를 서로 반대 방향으로 매 프레임 이동한다.
- 한 번의 실제 3.2초 홀드에서 마스크 위치가 `9.719% → 25.175% → 39.756% → 55.037% → 70.312% → 84.706% → 100.000%`로 연속 증가했고, 액체는 아래쪽에 남은 채 얇은 곡면 수면이 함께 내려갔다.
- 별도 홀드는 실제 29%에서 손을 떼어 `paused`가 됐고 마스크 `28.981%`와 남은 액체 높이가 그대로 유지됐다. 중간 PNG 교체는 없다.

### 반응형·접근성

- 375×812, 768×900, 1280×800에서 `scrollWidth === clientWidth`, `scrollHeight === clientHeight`를 확인했다.
- CDP로 `prefers-reduced-motion: reduce`를 실제 에뮬레이션했고 미디어 쿼리 일치 및 수면 장식 `display: none`을 확인했다.
- 실제 브라우저 QA에서 포인터 입력을 사용했다.
- 두 명의 독립 검수자가 차단 문제 없음으로 판정했다.

## 패키징 확인

- PNG 7종 모두 열기와 디코딩이 가능하다.
- 전체 상태 이미지 3종은 1024×1536, 링 면 2종은 300×112, 액체 레이어 2종은 126×414다.
- 모든 PNG에 알파 채널이 있다.
- `integration_contract.json`은 유효한 JSON이며 에셋 파일명과 일치한다.

## 아직 검증하지 않은 항목

- Android Compose 및 iOS SwiftUI 실제 화면 연결
- 실제 기기의 FPS, 메모리 사용량과 첫 프레임 로딩
- 접근성 서비스가 포함된 네이티브 터치·키보드 동작

과거 생성 초안, 미리보기, 웹 프로토타입과 캡처는 최종 패키징에서 제외했다.
