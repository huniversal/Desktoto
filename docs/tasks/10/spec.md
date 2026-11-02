# 작업 명세: [Feat] 세션 패널 UI 구현

## 연결 정보

- 이슈: #10 / https://github.com/huniversal/Desktoto/issues/10
- 브랜치: `feat/session-panel-ui/#10`
- specRevision: 1
- 선행 이슈: #2(모듈 구성), #3(`DesignSystem`), #4(`SessionInfo`), #6(`ToolUsage`), #8(`AppSettings`, 모두 병합 완료)
- 대상 ai-run 원본 (읽기 전용):
  - `~/Desktop/ai-run/Sources/AiRun/SessionPanelView.swift` (전체)
  - `~/Desktop/ai-run/Sources/AiRun/AppDelegate.swift` (`GlassPanel` 10~35행, `updatePanelFrame` 342~356행)
- 동작 문서화 위치: `docs/reverse/session-panel.md`

## 목적

메뉴바 아이콘을 눌렀을 때 열리는 유리 패널 화면을 `SessionPanel` 모듈에 구현한다.
화면 모양, 크기, 문구, 애니메이션, 창 위치는 원본과 같게 유지하고, 내부는 View와 모델, 표시 텍스트 변환, 창 위치 계산으로 나눠 테스트할 수 있게 한다.
View에는 로직을 넣지 않고 표시용 값은 모델과 순수 함수가 만들어 전달한다.

## 작업 범위

### 포함

- `GlassPanel`: 포커스를 빼앗지 않고 Esc를 받는 투명 `NSPanel`
- 창 위치 계산(순수 함수)과 `GlassPanel`에서 이를 적용하는 메서드
- 세션 패널 View: 사용량 카드가 위에 고정되고 아래에 세션 카드, 각 카드는 `glassCard()`
- 세션 행: 제목(없으면 프로젝트 이름), 사용률 또는 승인 대기 알약, 사용률 막대, 확인하지 않은 완료 점, 진행 중 흐르는 배경, 마우스 오버 시 모델 이름과 토큰 수 펼침, 줄 클릭
- 빈 상태("세션 없음"), 창 크기를 유지한 채 유리 모양만 늘어나는 처리(아래 여백 예약, 위쪽 고정)
- 사용량 카드: AI별 5시간, 주간 막대와 퍼센트, 초기화까지 남은 시간, 낡은 값 문구
- 패널 모델: 세션, 사용량, 완료 id, hover id, 줄 클릭 콜백, 표시 설정 4개, 현재 시각
- 표시 텍스트 변환 순수 함수와 단위 테스트
- `docs/reverse/session-panel.md`, `Package.swift`의 `SessionPanelTests` 타깃

### 제외

- 세션 정렬(승인 대기, 진행 중, 방금 끝남, 나머지): 원본 `AppDelegate.refreshPanel` 로직이라 #11
- 패널 열기와 닫기, 페이드, 2초 갱신 타이머, 바깥 클릭 감지, 창 표시 순서: #11
- `Theme`을 창 외관에 적용하는 일(`applyTheme`): #11
- 완료와 대기 알림 트리거, 소리, 아이콘 점 상태, 줄 클릭 시 실제 세션 열기 동작(`openSession`): #11
- `AppSettings`와 모델의 동기화, 세션과 사용량 감시기 연결: #11
- `DesignSystem` 수정. 필요한 토큰이나 컴포넌트가 없으면 이 명세에 기록하고 결정한다.
- 새 기능, 새 문구, 원본에 없는 스타일

## 설계 결정

- 파일 구조와 책임 (`apps/macos/Sources/SessionPanel/`, 의존은 `Domain`, `DesignSystem`):
  - `SessionPanelModel.swift`: `@MainActor`, `@Observable`. 상태만 보관한다.
  - `PanelText.swift`: 표시 텍스트 변환 순수 함수. 토큰 수, 사용률, 초기화까지 남은 시간, 사용 토큰 문구, 승인 대기 문구
  - `PanelFrame.swift`: 창 위치 계산 순수 함수
  - `GlassPanel.swift`: `NSPanel` 서브클래스
  - `SessionPanelView.swift`, `SessionRowView.swift`, `UsageCardView.swift`: View
  - 기존 빈 `SessionPanel.swift`는 삭제한다.
- 상태와 데이터 흐름:
  - 원본 View는 `AppSettings`를 직접 지켜봤지만 `SessionPanel`은 `Preferences`를 import할 수 없다. 모델에 `showsUsage`, `showsContext`, `colorMode`, `glassStyle`을 필드로 두고 #11이 `AppSettings`와 동기화한다(사용자 합의).
  - 원본의 `Date()`와 `timeIntervalSinceNow`는 UI 모듈에서 시간에 접근하지 않는 규칙(`docs/architecture.md` 3장)에 따라 모델의 `now`로 대체한다. #11이 갱신 때(원본은 2초마다) 값을 넣고, 변환 함수는 `now`를 인자로 받는다.
  - 줄 클릭은 모델의 `onOpenSession` 콜백으로 전달한다. 원본처럼 화면 갱신과 무관해서 관찰 대상에서 제외한다.
  - `finishedIDs`, `hoveredID`는 원본과 같은 의미다. 방금 끝난 줄은 `!session.isRunning && finishedIDs.contains(id)`로 판정한다.
- 원본 값 유지:
  - 색, 간격, 반경, 그림자, 글자 크기, 모션은 `DesignSystem` 토큰만 쓴다(`docs/design-system.md`). 토큰에 없는 화면 배치 값(상세 줄 예약 높이 26, 사용량 열 폭 32, 34, 70, 점 간격 3과 올림 9, 줄 안 간격 8, 창과 상태바 사이 6, 화면 가장자리 8)은 이 모듈 안에 원본 값 그대로 상수로 둔다.
  - 문구는 원본과 같다: "세션 없음", "5시간", "주간", "승인 필요", "답변 필요", "모델 알 수 없음", "확인하지 않은 완료"(접근성).
- 선택한 방식과 이유: 원본 코드를 복사하지 않고 동작을 옮겨 다시 구현한다. 원본은 `ObservableObject`, 파일 전역 `private` 상수, 전역 시간 접근을 쓰지만 새 구현은 `@Observable`, `DesignSystem` 토큰, 주입된 `now`를 쓴다. 보이는 결과는 같게 유지한다.
- 예외 처리 (원본 동작 유지):
  - 사용률 비율은 `usedTokens`와 `windowTokens`가 모두 있고 `windowTokens > 0`일 때만 만들고 1로 자른다. 아니면 비율 없음이고 막대는 트랙만 그리며 오른쪽 글자는 "-"다.
  - 토큰 수 문구는 값이 없으면 "-"다. 1000 이상은 `count / 1000` 정수 나눗셈 K, 100만 이상은 소수 없이 떨어지면 정수 M, 아니면 소수 첫째 자리 M이다.
  - 창 크기를 추정한 값에는 `~`를 붙인다(`isWindowEstimated`).
  - 초기화까지 남은 시간은 분 단위로 내림하고 0 미만은 0으로 한다. `resetsAt`이 없으면 빈 문자열이다.
  - 열 곳이 없는 세션(`canOpen == false`)은 클릭해도 콜백을 호출하지 않고 포인터를 바꾸지 않는다.
  - 원본에 없는 동작은 추가하지 않는다. 원본의 버그로 보이는 점이 구현 중 발견되면 이 명세에 기록한 뒤 결정한다.

## 완료 조건

- AC-1: 토큰 수 문구가 원본과 같다(999, 1000, 1500, 999999, 1000000, 1500000, 2000000 경계 포함).
- AC-2: 세션 오른쪽 글자(사용률 퍼센트, 비율 없음 "-", 추정 `~`)와 hover 펼침 문구("사용 / 창", 값 없음 "-", 모델 이름 없음 "모델 알 수 없음")가 원본과 같다.
- AC-3: 초기화까지 남은 시간 문구가 원본과 같다(분, 시간과 분, 일과 시간, 과거 시각은 0분, 시각 없음은 빈 문자열).
- AC-4: 승인 대기 알약 문구가 대기 종류에 따라 "승인 필요", "답변 필요"로 나뉜다.
- AC-5: 창 위치 계산이 원본과 같다(아이콘 왼쪽 끝 정렬, 그림자 여백 보정, 아이콘 아래 6, 화면 좌우 8 안쪽으로 제한, 오른쪽 한계가 왼쪽 한계보다 작을 때 왼쪽 우선).
- AC-6: `GlassPanel`이 테두리 없음, 활성화하지 않음, 투명, 시스템 그림자 없음, 팝업 메뉴 수준, 모든 스페이스와 전체 화면 보조, 키 창 가능이며 Esc에서 `onCancel`을 호출한다.
- AC-7: 세션 패널 View가 원본 구조를 따른다: 사용량 카드(표시 설정이 켜져 있고 사용량이 비어 있지 않을 때)가 위, 세션 카드(컨텍스트 표시 설정이 켜져 있을 때)가 아래, 줄 사이 구분선, 빈 상태 문구, 진행 중인 줄만 흐르는 배경, 완료 점, 알약, hover 펼침, 아래 여백 예약.
- AC-8: 줄 클릭이 `canOpen`일 때만 `onOpenSession`을 호출한다.
- AC-9: `docs/reverse/session-panel.md`에 원본 동작과 상수가 기록되어 있다.
- AC-10: `(cd apps/macos && swift build && swift test)`가 성공하고 실행된 테스트 수를 기록한다.
- AC-11: 실제 화면에서 원본과 나란히 비교한다. 앱 조립이 #11이라 가능하지 않으면 미검증으로 PR에 밝힌다.
- AC-12: 이 이슈에서 만들거나 고친 문서와 주석에 가운데점(U+00B7)이 없다.
- AC-13: `~/Desktop/ai-run`, `~/.ai-run`, `~/.claude/settings.json`, 실제 `UserDefaults`를 수정하지 않았다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `PanelText` 토큰 수 변환 테스트 | 경계값 문구가 기대와 일치 |
| AC-2 | 합성 `SessionInfo`로 오른쪽 글자와 펼침 문구 테스트 | 기대와 일치 |
| AC-3 | 고정 `now`와 `resetsAt` 조합 테스트 | 기대와 일치 |
| AC-4 | 대기 종류 두 가지 테스트 | 기대와 일치 |
| AC-5 | 합성 아이콘 프레임과 화면 영역으로 위치 계산 테스트(왼쪽 한계, 오른쪽 한계, 중간, 좁은 화면) | 원본 식과 같은 좌표 |
| AC-6 | `GlassPanel` 속성 테스트와 `cancelOperation` 호출 테스트 | 속성 일치, 콜백 호출 |
| AC-7 | 원본 코드와 줄 단위 대조, `swift build` | 구조와 값이 일치, 빌드 성공 |
| AC-8 | 모델 콜백 연결 로직 단위 테스트(`canOpen` 참과 거짓) | 참일 때만 호출 |
| AC-9 | 문서와 원본 대조 | 누락 없음 |
| AC-10 | `(cd apps/macos && swift build && swift test)` | 오류 없음, 테스트 수 기록 |
| AC-11 | 가능하면 `apps/macos/scripts/build-app.sh`로 만든 앱에서 확인. 불가능하면 PR에 미검증 명시 | 결과 기록 |
| AC-12 | `grep -rn $'\xc2\xb7' docs/tasks/10 docs/reverse/session-panel.md apps/macos/Sources/SessionPanel apps/macos/Tests/SessionPanelTests` | 결과 없음 |
| AC-13 | `git status`로 변경 파일 확인 | 대상 외 변경 없음 |

## 미결정 사항

| 번호 | 결정할 것 | 막음 여부 |
|---|---|---|
| D-1 | 해결: 표시 설정은 모델 필드로 두고 #11이 동기화(사용자 합의) | 해결 |
| D-2 | 해결: 현재 시각은 모델의 `now`로 주입(사용자 합의) | 해결 |
| D-3 | 해결: 세션 정렬은 #11(사용자 합의) | 해결 |
| D-4 | 해결: 열기와 닫기, 페이드, 타이머, 바깥 클릭, 테마 적용은 #11(사용자 합의) | 해결 |
| D-5 | View 본문의 시각적 일치를 자동으로 검증하기 어렵다. 스냅샷 도구를 새로 들이지 않고 원본 대조와 수동 비교로 확인한다 | 막지 않음 |
| D-6 | `now`를 갱신하지 않는 동안 남은 시간이 멈춘다. 원본도 화면 갱신 때만 계산하므로 같다. 열려 있는 동안 갱신은 #11의 2초 타이머가 맡는다 | 막지 않음 |

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 원본을 읽고 사용자와 합의한 범위. 정렬, 열기와 닫기, 테마 적용은 #11 |
