# 작업 명세: [Feat] 디자인 시스템 구축

## 연결 정보

- 이슈: #3 / https://github.com/huniversal/Desktoto/issues/3
- 브랜치: `feat/design-system/#3`
- specRevision: 3
- 선행 이슈: #2 (develop에 병합 완료. 모듈 구성, Swift 6 모드, 최소 macOS 26.0 확정)
- 대상 ai-run 원본 (읽기 전용):
  - `~/Desktop/ai-run/Sources/AiRun/SessionPanelView.swift` (17~76행 상수, 163~173행 `GlassCard`, 364~398행 `FlowingGradientBackground`, 400~465행 유리와 보조 글자, 467~489행 `UsageBar`)
  - `~/Desktop/ai-run/Sources/AiRun/AppSettings.swift` (1~44행 `ColorMode`, `GlassStyle`, `Theme`)
  - `~/Desktop/ai-run/Sources/AiRun/SpriteRenderer.swift` (58행 `DONE_DOT_COLOR`)
- 동작 문서화 위치: `docs/reverse/overview.md` (#2에서 작성)

## 목적

원본은 색, 간격, 반경, 그림자, 임계값, 시간 값이 `SessionPanelView.swift` 안의 `private let` 상수와 View 안의 숫자로 흩어져 있다.
이를 디자인 시스템 모듈로 모아, 이후 View(#10 등)가 임의 값을 쓰지 못하게 한다.
값은 원본과 똑같이 옮기고 새 디자인은 만들지 않는다. 동등성 검증(#11)의 기준이 되기 때문이다.

## 작업 범위

### 포함

- 토큰: 색, 간격, 반경, 그림자, 타이포, 모션, 경고와 위험 임계값
- 설정 타입 `GlassStyle`, `Theme`, `ColorMode` (원본 `rawValue` 유지)
- 공용 컴포넌트: 유리 카드, 사용량 막대, 승인 알약, 완료 점, 구분선, 흐르는 그라데이션 배경, 보조 글자 스타일
- 토큰과 순수 로직(막대 색 선택, 유리 단계별 값) 단위 테스트
- `docs/design-system.md` (토큰 표, 컴포넌트 목록, 사용 규칙)
- 라이트와 다크 모드 대비 확인 (수동)

### 제외

- `SessionRow`, `UsageCard`, `ToolUsageBlock`, `UsageWindowRow`, `EmptySessionRow`: 세션과 사용량 도메인 모양이라 #10에서 구현한다.
- 특정 화면의 배치 값: `USAGE_LABEL_WIDTH`, `USAGE_PERCENT_WIDTH`, `USAGE_RESET_WIDTH`, `PANEL_DETAIL_RESERVE`, `FINISHED_DOT_RAISE`, `FINISHED_DOT_GAP`. 해당 화면(#10)에 둔다.
- `TrailingTextStyle`(완료 직후 강조): 세션 줄의 로직이라 #10에 둔다.
- 메뉴바 캐릭터 렌더링과 `SpriteRenderer.swift`의 나머지 색(몸통, 눈, 불꽃, 물음표 등): #9
- `AppSettings`의 저장 로직(`UserDefaults`)과 `showsUsage` 등 다른 설정: 설정 이슈(#8)
- 도메인 문구(`승인 필요`, `5시간`, `세션 없음` 등)
- 랜딩 페이지(`apps/web`) 토큰
- 새 색, 새 컴포넌트, 새 동작 추가

## 설계 결정

- 위치(잠정): `apps/macos/Sources/DesignSystem/`과 `apps/macos/Tests/DesignSystemTests/`. #2의 D-6 확정 후 이름과 위치를 맞춘다.
  `Package.swift`는 타깃 두 개만 추가하도록 최소로 고친다. #2가 같은 파일을 교체하므로 병합 시 충돌은 병합하는 쪽에서 해결한다(사용자 합의).
- 파일 구조와 로직의 책임:
  - `Tokens/`: 값만 담는다. 로직 없음. 이름은 역할로 짓는다.
  - `Appearance/`: `GlassStyle`, `Theme`, `ColorMode`. 유리 단계별 틴트 불투명도(0.12, 0.35, 0.28, 0.55)와 `Glass` 변환은 `GlassStyle` 쪽에 둔다.
  - `Components/`: 값만 받는 View와 ViewModifier. `SessionInfo`, `ToolUsage` 같은 도메인 타입을 알지 못한다.
- 상수 이름은 Swift 컨벤션을 따라 `lowerCamelCase`와 `static let`을 쓴다(원본의 `UPPER_SNAKE_CASE`를 옮기지 않는다).
- 원본 값 대응 (코드 이름은 구현 때 확정하고, 값은 아래와 같아야 한다):

| 구분 | 원본 상수 | 값 |
|---|---|---|
| 크기 | `PANEL_WIDTH` | 270 |
| 크기 | `BAR_HEIGHT` | 4 |
| 크기 | `DIVIDER_HEIGHT` | 0.5 |
| 크기 | `FINISHED_DOT_SIZE` | 6 |
| 반경 | `PANEL_CORNER_RADIUS` | 18 |
| 반경 | `ROW_CORNER_RADIUS` | `PANEL_CORNER_RADIUS - PANEL_INSET` (관계식 유지) |
| 간격 | `PANEL_INSET` | 6 |
| 간격 | `ROW_HORIZONTAL_PADDING` | 15 |
| 간격 | `ROW_VERTICAL_PADDING` | 12 |
| 간격 | `ROW_CONTENT_SPACING` | 9 |
| 간격 | `ROW_HIGHLIGHT_VERTICAL_INSET` | 3 |
| 간격 | `USAGE_PANEL_GAP` | 8 |
| 간격 | `USAGE_BLOCK_VERTICAL_PADDING` | 10 |
| 간격 | `USAGE_ROW_SPACING` | 8 |
| 그림자 | 번짐, 이동, 불투명도, 창 여백 | 10, 4, 0.14, 36 |
| 임계값 | 컨텍스트 경고, 위험 | 0.6, 0.85 |
| 임계값 | 사용량 경고, 위험 | 0.8, 0.95 |
| 막대 | 트랙 불투명도, 채움 그림자 불투명도 | 0.16, 0.18 |
| 구분선 | 불투명도 | 0.08 |
| 간격 | 승인 알약 안쪽 가로, 세로 | 8, 3 |
| 색 | 승인 알약 호박색 | (1.00, 0.78, 0.30), 알약 배경은 불투명도 0.35 |
| 색 | 완료 점 보라 (`DONE_DOT_COLOR`) | (0.68, 0.52, 1.00) |
| 색 | 막대 그라데이션 | (0.45, 0.65, 1.00) 에서 (0.68, 0.50, 1.00) |
| 색 | 파스텔 팔레트 4색 | (1.00, 0.62, 0.78), (1.00, 0.78, 0.62), (0.74, 0.66, 1.00), (0.62, 0.82, 1.00) |
| 색 | 경고, 위험 | 시스템 `orange`, `red` |
| 보조 글자 | 라이트 모드 불투명도 | 0.85 (다크 모드는 시스템 `.secondary`) |
| 그라데이션 | 불투명도 라이트, 다크 | 0.22, 0.2 |
| 그라데이션 | 점 이동 속도, 색 이동 속도, 프레임 간격 | 0.3, 0.1, 1/30초 |
| 모션 | 상태 전환, 상세 | easeInOut 1.5초, 0.25초 |
| 타이포 | 사이즈와 weight 조합 | 11, 11 medium, 11 semibold, 12, 13, 13 semibold, 14 semibold |

- 상태와 데이터 흐름: 토큰은 상태가 없다. 컴포넌트는 값을 받아 그리고, `ColorMode`와 `GlassStyle`은 원본처럼 SwiftUI `Environment`로 전달한다.
- 선택한 방식과 이유: 원본 코드를 복사하지 않고 값과 동작을 옮겨 다시 구현한다(`docs/rules/macos-development.md`). 원본에서 쓰는 것만 가져오고 쓰지 않는 값은 만들지 않는다.
- 예외 처리: `UsageBar`는 원본처럼 `ratio`가 `nil`이면 트랙만 그리고, 채움 폭은 `max(폭 * ratio, 막대 높이)`로 둔다. 원본에 없는 `ratio` 클램프는 넣지 않는다(클램프는 원본에서도 도메인 쪽 `getUsageRatio`에 있다).

## 완료 조건

- AC-1: 위 표의 모든 값이 디자인 시스템 모듈에 토큰으로 있고, 값이 원본과 같다.
- AC-2: `GlassStyle`, `Theme`, `ColorMode`의 case와 `rawValue`가 원본과 같아 이미 저장된 값을 그대로 읽는다.
- AC-3: 컴포넌트 7종(유리 카드, 사용량 막대, 승인 알약, 완료 점, 구분선, 흐르는 그라데이션 배경, 보조 글자 스타일)이 있고, 도메인 타입에 의존하지 않는다.
- AC-4: 컴포넌트 내부에서 색, 간격, 글자 크기 등을 토큰 밖의 임의 값으로 쓰지 않는다.
- AC-5: 막대 색 선택이 임계값 경계에서 원본과 같다 (위험 이상 빨강, 경고 이상 주황, 그 외 모드별 색).
- AC-6: 유리 5단계 각각이 원본과 같은 `Glass` 종류와 틴트 불투명도로 대응한다.
- AC-7: 라이트와 다크 모드에서 컴포넌트 7종을 원본과 나란히 보고 대비와 모양 차이를 확인한다.
- AC-8: `docs/design-system.md`에 토큰 표, 컴포넌트 목록, 사용 규칙이 있다.
- AC-9: `swift build`와 `swift test`가 성공하고 실행된 테스트 수를 기록한다.
- AC-10: 이 이슈에서 만들거나 고친 문서에 가운데점(U+00B7)이 없다.
- AC-11: `~/Desktop/ai-run`, `~/.ai-run`, `~/.claude/settings.json`을 수정하지 않았다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | 설계 결정의 값 표와 토큰 소스를 나란히 대조, 값 테스트 | 불일치 항목 없음 |
| AC-2 | `rawValue` 문자열 테스트 (`clear`, `slightlyClear`, `regular`, `slightlyTinted`, `tinted`, `light`, `dark`, `system`, `white`, `color`) | 원본과 같음 |
| AC-3 | 컴포넌트 파일의 import와 시그니처 확인 | 도메인 타입 없음 |
| AC-4 | 컴포넌트 소스에서 숫자 리터럴과 `Color(` 직접 사용을 검색 | 토큰 외 값 없음 (예외는 사유를 문서에 기록) |
| AC-5 | 막대 색 선택 순수 함수 테스트: 경계값 0.59, 0.6, 0.84, 0.85, 사용량 0.79, 0.8, 0.94, 0.95 | 기대 색과 일치 |
| AC-6 | 유리 단계 매핑 테스트 | 원본 표와 일치 |
| AC-7 | 앱 또는 프리뷰에서 라이트와 다크로 확인. 자동 테스트가 아니라 수동 확인임을 PR에 명시 | 차이를 기록 |
| AC-8 | 문서 목차와 토큰 표를 코드와 대조 | 누락 없음 |
| AC-9 | `(cd apps/macos && swift build && swift test)` | 오류 없음, 테스트 수 기록 |
| AC-10 | `grep -rn $'\xc2\xb7' docs/tasks/3 docs/design-system.md` | 결과 없음 |
| AC-11 | `git status`와 해당 경로 변경 시각 확인 | 변경 없음 |

## 미결정 사항

| 번호 | 결정할 것 | 막음 여부 |
|---|---|---|
| D-1 | 해결: #2가 `DesignSystem` 타깃(`Sources/DesignSystem/`)을 확정했다(`docs/architecture.md`). 의존은 없다 | 해결 |
| D-2 | `GlassStyle.title`, `Theme.title`(메뉴에 보이는 한국어 이름)을 디자인 시스템에 둘지 앱 쪽에 둘지. 도메인 문구를 두지 않는 원칙과 충돌한다 | 막지 않음 (기본안: 앱 쪽) |
| D-3 | 호박색 불일치. 원본 `APPROVAL_PILL_COLOR`는 (1.00, 0.78, 0.30)이고 주석은 메뉴바 물음표와 같은 색이라고 하지만, 실제 `QUESTION_COLOR`(`SpriteRenderer.swift:55`)는 (1.00, 0.80, 0.35)다. 별개 값으로 유지할지 통일할지 | 막지 않음 (기본안: 원본 그대로 두 값 유지, 알약 색만 이 이슈에서 토큰화) |
| D-4 | 해결: #2가 Swift 6 모드와 최소 macOS 26.0으로 확정했다. `Glass`, `MeshGradient`는 macOS 26 이상 API라 전제가 맞다 | 해결 |

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 원본을 읽고 사용자와 합의한 범위. `ratio` 클램프 테스트 제외, 화면 배치 값 제외, `title` 위치는 미결정으로 둠 |
| 2 | 값 표에 승인 알약 안쪽 여백(8, 3) 추가 | 구현 중 원본 View에 박혀 있던 값을 토큰으로 올렸다. 영향받는 AC: AC-1 |
| 3 | D-1, D-4 해결. 위치 잠정 문구 제거 | #2가 develop에 병합되어 모듈 이름과 위치, Swift 6 모드, 최소 macOS가 확정되었다. 영향받는 AC: AC-9(Swift 6 모드에서 빌드와 테스트) |
