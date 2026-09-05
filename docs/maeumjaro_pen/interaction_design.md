# 마음자로 펜 인터랙션 디자인 명세

## 1. 분위기와 정체성

따뜻한 종이 위에 작은 의식 도구를 올려둔 느낌이다. 특징적인 순간은 손가락을 따라 상단 링이 좌우로 돌며 자물쇠가 열리고, 손을 떼었다가 다시 누르는 두 번의 의식이다. 의료 기기보다 자기 조절 오브제로 인지되어야 한다.

## 2. 색상

| Role | Token | Value | Usage |
|---|---|---|---|
| Canvas | `--surface-canvas` | `#f6f7fb` | 전체 배경 |
| App | `--surface-app` | `#fbfcff` | 앱 화면 |
| Raised | `--surface-raised` | `#ffffff` | 상태 안내, 버튼 |
| Soft | `--surface-soft` | `#f0f2f8` | 프로그레스 트랙 |
| Text primary | `--text-primary` | `#202334` | 제목, 핵심 안내 |
| Text secondary | `--text-secondary` | `#686d7e` | 보조 안내 |
| Border | `--border-subtle` | `#e5e7ef` | 얇은 분리선 |
| Navy | `--accent-navy` | `#24375f` | 락 상태, 텍스트 강조 |
| Mint | `--accent-mint` | `#45d8bd` | 해제, 진행, 완료 |
| Blue | `--accent-blue` | `#3d8eef` | 진행 중간 |
| Violet | `--accent-violet` | `#6d62f3` | 강도 5, 펜 에셋 연결 |
| Focus | `--focus-ring` | `#245eea` | 키보드 포커스 |

액센트는 상태와 조작에만 사용한다. 앱 표면은 파란 기운이 아닌 따뜻한 밝기를 유지한다.

## 3. 타이포그래피

| Level | Token | Size | Weight | Line Height | Usage |
|---|---|---:|---:|---:|---|
| H1 | `--type-h1` | `24px` | 700 | 1.3 | 화면 제목 |
| H2 | `--type-h2` | `20px` | 700 | 1.4 | 핵심 지시 |
| Body | `--type-body` | `16px` | 500 | 1.6 | 상태 안내 |
| Small | `--type-small` | `14px` | 500 | 1.5 | 보조 문구 |
| Caption | `--type-caption` | `12px` | 700 | 1.4 | 단계, 수치 |

기본 서체는 `-apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Noto Sans KR", sans-serif`다.

## 4. 간격과 레이아웃

기본 단위는 4px다.

| Token | Value | Usage |
|---|---:|---|
| `--space-1` | `4px` | 최소 간격 |
| `--space-2` | `8px` | 인라인 간격 |
| `--space-3` | `12px` | 작은 그룹 |
| `--space-4` | `16px` | 화면 기본 |
| `--space-5` | `20px` | 카드 내부 |
| `--space-6` | `24px` | 영역 간격 |
| `--space-8` | `32px` | 큰 구분 |

콘텐츠는 모바일 375px에서 일단으로 보여야 하며, 768px 이상에서는 최대 430px의 앱 표면으로 중앙 정렬한다.

## 5. 컴포넌트

### Ritual Pen Surface
- **Structure**: ready 본체 PNG, 원통형 링 뷰포트, 연속 액체 레벨 레이어, 포인터 입력 표면
- **Variants**: locked, unlocking-left, unlocking-right, ready, relocking-left, relocking-right, holding, paused, complete
- **Spacing**: `--space-4`, `--space-6`
- **States**: locked에서 좌우 드래그하면 해제, ready에서 빠르게 좌우 드래그하면 다시 잠금, ready에서 움직이지 않고 유지한 새 pointer sequence만 긴 누르기, pointer up/cancel은 일시정지
- **Accessibility**: `button`, `aria-live`, ←/→ 해제, Space/Enter 긴 누르기, 명확한 포커스 링
- **Motion**: 하나의 링 오브젝트가 `perspective + rotateY`로 포인터 방향을 따라 180도 돌아 잠긴 앞면에서 열린 뒷면으로 전환된다. 열린 상태에서 다시 밀면 같은 링이 180도를 더 돌아 잠긴 면으로 복귀한다. 두 이미지를 좌우로 미는 교차 이동은 사용하지 않는다. 액체는 빈 창 위에 독립된 액체 레이어를 두고, 마스크 상단을 진행률과 1:1로 내려 실제 액체의 남은 높이를 매 프레임 줄인다. 경계에는 얇은 곡면 수면을 붙여 직선 잘림을 피한다. reduced motion에서는 손을 뗀 시점에 링 최종 상태를 즉시 전환하되 액체 값은 동일하게 연속 갱신한다.
- **Layout**: stack

### Progress Track
- **Structure**: 배경 트랙 + 제스처 진행률을 나타내는 fill
- **States**: empty, active, paused, complete
- **Accessibility**: `role="progressbar"`, `aria-valuenow`, 상태 문구 병행
- **Motion**: transform scaleX만 사용, reduced motion에서도 값은 즉시 반영

### Quiet Action
- **Structure**: 양식 버튼
- **Variants**: reset
- **States**: default, hover, active, focus, disabled
- **Accessibility**: 44px 이상 터치 영역, 명확한 레이블
- **Motion**: active `scale(.97)`, 120ms

## 6. 모션과 인터랙션

| Token | Value | Usage |
|---|---|---|
| `--motion-feedback` | `120ms ease-out` | 포인터 반응, 버튼 |
| `--motion-settle` | `260ms cubic-bezier(0.22, 1, 0.36, 1)` | 링 복귀/해제 |
| `--motion-crossfade` | `180ms ease-out` | 상태 이미지 |
| `--hold-delay` | `120ms` | 긴 누르기 시작 피드백 |

- 해제 임계값: 56px 또는 입력 폭의 18% 중 더 작은 값, 최소 44px.
- 수평 의도: `abs(dx) >= abs(dy) * 1.25`.
- 같은 pointer sequence에서 해제와 주입을 연속 실행하지 않는다. 해제 후 pointer up/cancel이 발생한 다음의 pointer down이 필수다.
- ready에서 새 pointer down 후 120ms 안에 수평 의도가 감지되면 주입 예약을 취소하고 다시 잠그기 제스처로 전환한다. 홀드가 시작된 뒤에는 링 제스처로 바뀌지 않는다.
- 상단 링의 위치는 제스처 진행률과 1:1로 연결한다. 포인터를 반대로 움직이면 즉시 역전한다.
- 링 회전은 locked/ready 두 면을 한 3D 링의 앞면과 뒷면으로 배치하고, 전체 링에 `rotateY(0deg → ±180deg)`를 적용한다. 다시 잠글 때는 같은 방향 계약으로 `±180deg → ±360deg`를 적용한다. opacity 페이드나 좌우 이미지 슬라이드는 사용하지 않는다.
- 주입 진행률은 중간 상태 PNG나 커지는 흰 덮개를 사용하지 않는다. 빈 창과 액체를 분리하고 액체 마스크의 `translateY`를 진행률과 1:1로 연결하여 0~100% 전 구간에서 실제 액체 높이가 연속 감소하게 한다.
- 모든 움직임은 transform/opacity만 사용한다.
- `prefers-reduced-motion: reduce`에서 링 회전을 없애고 locked/ready 상태를 즉시 교체한다.

## 7. 깊이와 표면

Strategy: mixed. 앱 구조는 얇은 테두리와 톤 차이를 쓰고, 기존 2.5D 펜 에셋의 빛과 음영은 보존한다. 데스크톱에서만 앱 표면에 저불명도 다중 음영을 사용해 배경과 분리한다.

## 8. 접근성과 적용 경계

- WCAG 2.2 AA 목표, 모든 조작은 키보드로 재현, 동작 축소 선호 반영.
- 상태는 색만으로 전달하지 않고 문장과 진행률을 함께 표시.
- 현재 에셋은 2.5D 원통 회전 계약을 제공한다. 앱에서는 Compose `graphicsLayer(rotationY)` 또는 SwiftUI `rotation3DEffect`로 같은 동작을 구현할 수 있다.
- 실제 메시 수준의 광원 변화와 시차가 필요하면 같은 상태 계약을 유지한 채 Rive 또는 네이티브 메시로 교체한다.
- 실제 앱 소스 연결, 기기 FPS와 첫 프레임 로딩은 아직 검증되지 않았다.
