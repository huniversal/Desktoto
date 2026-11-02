# 디자인 시스템

Desktoto의 색, 간격, 반경, 그림자, 타이포, 모션과 공용 컴포넌트를 `apps/macos/Sources/DesignSystem/`에 모았다.
값은 원본 `ai-run`의 `SessionPanelView.swift`와 `AppSettings.swift`에서 그대로 옮겼고, 새로 만든 값은 없다.
모듈 구성과 의존 규칙은 [아키텍처 문서](architecture.md)를 따른다. `DesignSystem`은 다른 모듈에 의존하지 않고, UI 모듈이 의존한다.

## 사용 규칙

- View에서 색, 간격, 글자 크기, 시간 값을 직접 쓰지 않고 이 모듈의 토큰을 쓴다.
- 컴포넌트는 값만 받는다. 세션이나 사용량 같은 도메인 타입과 한국어 문구는 넣지 않고 호출하는 쪽이 넘긴다.
- 특정 화면의 배치 값(열 폭, 점 위치 보정 등)은 토큰이 아니라 그 화면에 둔다.
- `ColorMode`와 `GlassStyle`은 패널 맨 위에서 `Environment`(`barColorMode`, `glassStyle`)로 한 번 넣는다.

## 토큰

| 이름 | 값 |
|---|---|
| `DSSize.panelWidth` | 270 |
| `DSSize.barHeight` | 4 |
| `DSSize.dividerHeight` | 0.5 |
| `DSSize.finishedDot` | 6 |
| `DSSpacing.panelInset` | 6 |
| `DSSpacing.rowHorizontal` / `rowVertical` / `rowContent` | 15 / 12 / 9 |
| `DSSpacing.rowHighlightVerticalInset` | 3 |
| `DSSpacing.panelGap` | 8 |
| `DSSpacing.usageBlockVertical` / `usageRow` | 10 / 8 |
| `DSSpacing.pillHorizontal` / `pillVertical` | 8 / 3 |
| `DSRadius.panel` | 18 |
| `DSRadius.row` | `panel - panelInset` (12) |
| `DSShadow.radius` / `offsetY` / `opacity` / `panelMargin` | 10 / 4 / 0.14 / 36 |
| `DSOpacity.divider` | 0.08 |
| `DSOpacity.barTrack` / `barFillShadow` | 0.16 / 0.18 |
| `DSOpacity.approvalPillBackground` | 0.35 |
| `DSOpacity.secondaryTextLight` | 0.85 |
| `DSOpacity.gradientLight` / `gradientDark` | 0.22 / 0.2 |
| `DSThreshold.context` | 경고 0.6, 위험 0.85 |
| `DSThreshold.usage` | 경고 0.8, 위험 0.95 |
| `DSColor.approvalPill` | (1.00, 0.78, 0.30) |
| `DSColor.finishedDot` | (0.68, 0.52, 1.00), calibrated |
| `DSColor.barGradient` | (0.45, 0.65, 1.00) 에서 (0.68, 0.50, 1.00) |
| `DSColor.pastelPalette` | 핑크, 복숭아, 라벤더, 하늘색 4색 |
| `DSColor.warning` / `danger` | 시스템 주황, 빨강 |
| `DSMotion.stateChange` / `detail` | easeInOut 1.5초 / 0.25초 |
| `DSMotion.gradientPointSpeed` / `gradientColorSpeed` / `gradientFrameInterval` | 0.3 / 0.1 / 1/30초 |
| `DSTypography` | caption 11, captionMedium, captionSemibold, subheadline 12, body 13, bodySemibold, title 14 semibold |

## 설정 타입

| 타입 | case (저장된 rawValue와 같다) |
|---|---|
| `ColorMode` | `white`, `color` |
| `Theme` | `light`, `dark`, `system` |
| `GlassStyle` | `clear`, `slightlyClear`, `regular`, `slightlyTinted`, `tinted` |

`GlassStyle`의 틴트 불투명도는 0.12, 0.35, 없음, 0.28, 0.55이고, `clear`와 `slightlyClear`는 맑은 유리, 나머지는 일반 유리다.
메뉴에 보이는 한국어 이름은 앱 쪽에서 정한다.

## 컴포넌트

| 컴포넌트 | 설명 |
|---|---|
| `glassCard()` | 패널을 감싸는 유리 카드(여백, 폭, 유리, 그림자) |
| `UsageBar(ratio:thresholds:)` | 사용률 막대. `ratio`가 `nil`이면 트랙만 그린다. 색 선택은 `UsageBarFill`이 한다 |
| `StatusPill(_:)` | 승인이나 답변 대기 알약 |
| `FinishedDot` | 확인하지 않은 완료 점. 위치와 접근성 문구는 쓰는 쪽이 정한다 |
| `RowDivider` | 줄 사이의 가는 구분선 |
| `FlowingGradientBackground` | 진행 중인 줄 안쪽에서 흐르는 파스텔 메쉬 그라데이션 |
| `secondaryText()` | 보조 글자 스타일. 다크는 시스템 `.secondary`, 라이트는 불투명도 0.85 |

## 토큰이 아닌 내부 값

`FlowingGradientBackground`의 점 이동 폭(0.18, 0.2)과 코사인 속도 비율(0.8), `UsageBar`의 그림자 반경(0.5)은 원본의 계산식에 속한 값이라 토큰으로 올리지 않았다.
`.black`(그림자 색), `Color.primary`, `Color(nsColor: .windowBackgroundColor)`(유리 틴트 색)는 원본과 같은 시스템 색이라 토큰으로 정의하지 않았다.

## 아직 쓰는 곳이 없는 항목

- `Theme`: 설정 값으로만 존재한다. 패널 테마 적용은 앱 쪽(#11)에서 한다.

`DSMotion.stateChange`, `DSMotion.detail`은 #10의 `SessionPanel`이 줄 상태 전환과 상세 줄 펼침 애니메이션에서 쓴다.
화면 배치 값(상세 줄 예약 높이, 사용량 열 폭, 완료 점 위치 보정 등)은 토큰이 아니라 `SessionPanel/PanelLayout.swift`에 둔다.

## 접근 범위

`UsageBarFill`(막대 색 선택)과 `GlassStyle.tintOpacity`, `GlassStyle.isClearGlass`는 모듈 내부용(internal)이다. 필요해지면 그때 공개한다.
