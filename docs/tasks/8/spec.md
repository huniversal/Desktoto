# 작업 명세: [Feat] 설정, 알림 및 로그인 항목 구현

## 연결 정보

- 이슈: #8 / https://github.com/huniversal/Desktoto/issues/8
- 브랜치: `feat/preferences/#8`
- specRevision: 1
- 선행 이슈: #2(모듈 구성), #3(`ColorMode`, `GlassStyle`, `Theme`, 병합 완료)
- 대상 ai-run 원본 (읽기 전용):
  - `~/Desktop/ai-run/Sources/AiRun/AppSettings.swift`
  - `~/Desktop/ai-run/Sources/AiRun/NotificationSender.swift` (`NotificationSender`, `LoginItem`, `isRunningAsApp`)
  - `~/Desktop/ai-run/Sources/AiRun/AppDelegate.swift` (134~190행 설정 메뉴 구성, 198~206행 설정 토글, 460~462행 알림 발송 조건)
- 동작 문서화 위치: `docs/reverse/preferences.md`

## 목적

사용자가 바꾸는 설정과 시스템 통합(알림, 로그인 항목)을 `Preferences` 모듈에 구현한다.
설정은 바뀌는 즉시 저장하고 UI가 값을 지켜보다가 바로 다시 그리는 원본 동작을 유지한다.
설정 메뉴는 `NSMenu` 조립이 앱 조립 책임이라 #11에 두고, 이 이슈는 메뉴가 쓰는 항목 모델까지 만든다(사용자 합의).

## 작업 범위

### 포함

- 설정 모델과 저장: 색상 모드, 유리 단계, 테마, 사용량 패널 표시, 컨텍스트 패널 표시, Claude Code 연동 여부, Codex 실시간 조회, 알림 여부
- 기본값과 저장값 호환(UserDefaults 키 이름 유지, `clear`, `regular`, `tinted` 값 읽기, 알 수 없는 값은 기본값)
- 패널 표시 상태(둘 다, 하나만, 없음)와 보여줄 패널이 있는지 판정
- 우클릭 설정 메뉴와 종료 메뉴의 항목 모델: 제목, 체크 상태, 활성 여부, 구분선, 하위 메뉴 구조와 한국어 제목(`GlassStyle`, `Theme` 제목 포함)
- 알림 발송: 알림 센터 프로토콜 뒤에서 `UserNotifications` 사용, 알림 클릭 시 세션 id를 콜백으로 전달, 앞에 있을 때도 배너 표시
- 번들(.app)이 없는 개발 실행에서 `AppleScriptRunner`로 알림 대체
- 로그인 항목 켜기와 끄기, 사용자 승인이 필요한 상태에서 시스템 설정 로그인 항목 화면 열기
- 설정 기본값, 저장, 호환, 메뉴 항목 모델, 알림 분기, 로그인 항목 분기 단위 테스트
- `docs/reverse/preferences.md`

### 제외

- `NSMenu`와 `NSStatusItem` 조립, 우클릭 감지, 패널 닫기: #11
- Claude Code 연동의 실제 연결과 해제(`ClaudeIntegration`): #7. 여기서는 `connectsClaudeCode` 값 저장만 한다.
- Codex 실시간 조회의 시작, 중지, 즉시 갱신(`UsageMonitoring`): #6, #11. 여기서는 `fetchesCodexUsage` 값 저장만 한다.
- 완료와 승인 대기 시점의 알림 트리거, 소리 재생, 제목 40자 자르기: #11
- 테마를 패널 창 외관에 적용하는 일(`applyTheme`), 캐릭터 이미지 다시 만들기: #10, #11
- 사용자의 실제 `UserDefaults`, 알림 권한, 로그인 항목 변경을 테스트 준비에 쓰는 일
- 새 설정 항목, 새 메뉴 항목 추가

## 설계 결정

- 파일 구조와 책임 (`apps/macos/Sources/Preferences/`, 의존은 `DesignSystem`, `Boundaries`):
  - `AppSettings.swift`: 설정 값과 저장. `UserDefaults`를 주입받는다.
  - `SettingsMenuModel.swift`: 설정 값을 받아 메뉴 항목 값(제목, 체크, 활성, 하위 항목, 동작 식별자)을 만드는 순수 로직. AppKit을 import하지 않는다.
  - `NotificationSender.swift`와 알림 센터 프로토콜: 번들 여부와 알림 센터를 주입받아 분기한다.
  - `LoginItem.swift`와 로그인 항목 서비스 프로토콜(`SMAppService` 뒤): 상태 조회, 켜기와 끄기, 승인 필요 시 시스템 설정 열기.
  - 프로토콜은 `Preferences` 안에 둔다(`docs/architecture.md` 5장 단일 기능 서비스). `Domain`은 import하지 않는다.
  - `Package.swift`에 `PreferencesTests` 타깃을 추가하고 `TestSupport`의 가짜 구현을 쓴다.
- 상태와 데이터 흐름:
  - `AppSettings`는 `@MainActor`와 `@Observable`로 만들어 SwiftUI가 지켜본다. 값이 바뀌면 즉시 `UserDefaults`에 쓴다.
  - 키 이름은 원본과 같게 유지한다: `showsUsagePanel`, `showsContextPanel`, `colorMode`, `sendsNotifications`, `glassStyle`, `theme`, `connectsClaudeCode`, `fetchesCodexUsage`.
  - 기본값: 두 패널 표시, 흰색, 시스템 테마, 보통 유리, 알림 켬, Claude 연동 켬, Codex 실시간 켬.
  - 번들 식별자가 달라 새 앱은 원본의 저장값을 읽지 못하고 기본값으로 시작한다(`docs/architecture.md` 1장). 이는 이 이슈에서 바꾸지 않는다.
  - 알림 클릭 콜백은 메인 스레드에서 호출한다.
- 선택한 방식과 이유: 원본 코드를 복사하지 않고 동작을 옮겨 다시 구현한다. 원본은 `ObservableObject`와 전역 `isRunningAsApp`을 쓰지만, 새 구현은 `@Observable`과 주입으로 테스트 가능하게 한다. 동작은 같게 유지한다.
- 예외 처리:
  - 저장된 값이 enum 원시값과 맞지 않으면 기본값을 쓴다.
  - 알림 권한 요청 결과는 원본처럼 무시한다. 권한이 없으면 배너가 안 보일 뿐 오류로 다루지 않는다.
  - 번들이 없으면 알림 센터와 로그인 항목을 접근하지 않는다(접근만으로 앱이 종료되므로). 알림은 AppleScript로 대체하고, 로그인 항목은 상태 꺼짐, 변경 무시로 둔다.
  - 로그인 항목 등록과 해제의 실패는 로그만 남기고 이후 상태 확인과 승인 필요 시 시스템 설정 열기는 원본처럼 계속 진행한다.
  - AppleScript 대체는 큰따옴표와 역슬래시를 이스케이프하고, 실행 오류는 원본처럼 무시한다.
  - 원본에 없는 동작은 추가하지 않는다. 원본의 버그로 보이는 점이 구현 중 발견되면 이 명세에 기록한 뒤 결정한다.

## 완료 조건

- AC-1: 설정 8개가 원본과 같은 키 이름과 기본값으로 저장되고, 값이 바뀌면 즉시 저장된다.
- AC-2: 저장된 `GlassStyle`(`clear`, `slightlyClear`, `regular`, `slightlyTinted`, `tinted`), `Theme`, `ColorMode` 값을 읽고, 알 수 없는 값과 타입이 다른 값은 기본값이 된다.
- AC-3: 패널 표시가 둘 다, 하나만, 없음으로 표현되고, 둘 다 꺼진 경우 보여줄 패널이 없다고 판정한다.
- AC-4: 설정이 바뀌면 지켜보는 쪽이 값 변경을 관찰할 수 있다.
- AC-5: 설정 메뉴 항목 모델이 원본과 같은 구성과 순서, 한국어 제목, 체크 상태를 만든다(로그인 시 자동 실행, 알림 보내기, Codex 연동, Claude 연동 조건부, 구분선, 표시할 패널, 색상, 테마, Liquid Glass, 구분선, Desktoto 종료). 번들이 없으면 로그인 항목은 비활성이다.
- AC-6: 알림은 번들 실행에서 알림 센터로 전달되고 세션 id를 담으며, 번들이 없으면 AppleScript 대체로 전달된다.
- AC-7: 알림 클릭 응답에서 세션 id를 꺼내 콜백으로 전달하고, 세션 id가 없는 응답은 콜백을 호출하지 않는다.
- AC-8: 로그인 항목 켜기와 끄기가 상태에 따라 등록과 해제로 분기하고, 승인이 필요한 상태면 시스템 설정 열기를 호출한다. 번들이 없으면 아무것도 호출하지 않는다.
- AC-9: `docs/reverse/preferences.md`에 원본 동작과 외부 의존(알림, 로그인 항목, UserDefaults 키)이 기록되어 있다.
- AC-10: `swift build`와 `swift test`가 성공하고 실행된 테스트 수를 기록한다.
- AC-11: 실제 .app 번들 실행에서 알림 배너, 알림 클릭 세션 이동 호출, 로그인 항목 켜기와 끄기가 동작한다(수동 확인).
- AC-12: 이 이슈에서 만들거나 고친 문서에 가운데점(U+00B7)이 없다.
- AC-13: `~/Desktop/ai-run`, `~/.ai-run`, `~/.claude/settings.json`, 실제 `UserDefaults`를 수정하지 않았다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `UserDefaults(suiteName:)` 임시 도메인으로 기본값 테스트, 값 변경 후 새 인스턴스로 다시 읽는 테스트, 키 이름 문자열 대조 | 기본값과 키가 원본과 같음 |
| AC-2 | 5개 유리 단계 원시값과 이전 값, 잘못된 문자열, 다른 타입 값을 넣고 읽는 테스트 | 기대 값 또는 기본값 |
| AC-3 | 두 패널 조합 4가지 테스트 | 둘 다 꺼진 경우만 보여줄 패널 없음 |
| AC-4 | `withObservationTracking`으로 값 변경 관찰 테스트 | 변경 알림 발생 |
| AC-5 | 항목 모델 테스트: 항목 순서, 제목, 체크 상태, 번들 없음 비활성, Claude Code 미설치 시 Claude 연동 항목 생략 | 원본 메뉴 구성과 일치 |
| AC-6 | 가짜 알림 센터와 `RecordingAppleScriptRunner` 테스트, 이스케이프 입력 | 분기와 스크립트 문자열이 기대와 일치 |
| AC-7 | 가짜 응답으로 콜백 호출과 미호출 테스트 | 기대대로 호출 |
| AC-8 | 가짜 로그인 항목 서비스 테스트: 꺼짐, 켜짐, 승인 필요, 등록 실패, 번들 없음 | 호출 목록이 기대와 일치 |
| AC-9 | 문서와 원본 대조 | 누락 없음 |
| AC-10 | `(cd apps/macos && swift build && swift test)` | 오류 없음, 테스트 수 기록 |
| AC-11 | `apps/macos/scripts/build-app.sh`로 만든 `apps/macos/build/Desktoto.app`을 실행해 확인. macOS와 Xcode 버전을 기록. 앱 연결은 #11 이후에 가능하면 그때 함께 확인하고, 불가능하면 미검증으로 PR에 밝힘 | 동작 결과를 PR에 기록 |
| AC-12 | `grep -rn $'\xc2\xb7' docs/tasks/8 docs/reverse/preferences.md` | 결과 없음 |
| AC-13 | `git status`와 해당 경로 변경 시각 확인, 테스트가 임시 도메인만 쓰는지 확인 | 변경 없음 |

## 미결정 사항

| 번호 | 결정할 것 | 막음 여부 |
|---|---|---|
| D-1 | 해결: 메뉴 조립은 #11, #8은 항목 모델까지(사용자 합의) | 해결 |
| D-2 | 해결: `GlassStyle.title`, `Theme.title`은 `DesignSystem`이 아니라 `Preferences`의 메뉴 모델에 둔다(#3 명세 D-2 기본안) | 해결 |
| D-3 | 메뉴 항목의 동작 식별자 모양(열거형 case)과 #11이 이를 `NSMenuItem`에 연결하는 방식. 구현 시 정하고 `docs/architecture.md` 변경이 필요하면 따로 알린다 | 막지 않음 |
| D-4 | AC-11의 앱 연결 확인을 #8 안에서 어디까지 할지. 앱 진입점이 #11이라 `main.swift` 없이 알림 배너와 로그인 항목을 실제로 확인하기 어려울 수 있다 | 막지 않음 (기본안: 어려우면 미검증으로 PR에 밝히고 #11에서 확인) |

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 원본을 읽고 사용자와 합의한 범위. 메뉴는 항목 모델까지만 #8, `NSMenu` 조립은 #11 |
