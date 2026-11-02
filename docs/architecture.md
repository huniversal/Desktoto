# 아키텍처

이슈 #2에서 확정한 구조 결정을 기록한다. 이후 모든 기능 이슈(#3 이후)는 이 문서를 전제로 한다.
결정의 근거와 합의 과정은 [작업 명세](tasks/2/spec.md)에, 원본의 동작 사실은 [원본 동작 개요](reverse/overview.md)에 있다.
이 문서와 `apps/macos/Package.swift`가 어긋나면 이 문서를 먼저 고치고 패키지를 맞춘다.

## 1. 결정 요약

| 항목 | 결정 |
| --- | --- |
| 앱 이름, 실행 파일, 패키지 | `Desktoto` |
| 번들 식별자 | `com.huniverse.desktoto` |
| 데이터 폴더와 스크립트 | `~/.ai-run`, `ai-run-hook.sh`, `ai-run-statusline.sh` 그대로 유지 |
| Swift 언어 모드 | Swift 6 (`swift-tools-version:6.0`) |
| 최소 macOS | 26.0 |
| zstd | 벤더링한 `CZstd` 유지 (v1.5.7, 해독부만) |
| 패키지 위치 | `apps/macos` (모노레포) |
| 모듈 구성 | 기능별 모듈 11개와 보조 타깃 2개 (3장) |
| 외부 경계 | `Boundaries`의 프로토콜 6개와 기능 모듈 안의 단일 기능 서비스 (5장) |

### 이름과 호환성

- 번들 식별자가 원본(`com.huniverse.airun`)과 달라서 macOS는 새 앱을 별개의 앱으로 취급한다.
  알림, 로그인 항목, 자동화(AppleScript) 권한은 새 앱에서 다시 허용해야 한다.
- 원본과 새 앱이 `~/.ai-run`과 `~/.claude/settings.json`을 공유한다. 제품 동작을 같게 유지하고 동등성 검증에서
  두 앱이 같은 입력 파일을 읽게 하기 위한 결정이다. 이름 변경은 동등성 검증 후 별도 이슈에서 다룬다.
- 원본이 이미 훅과 statusLine을 연결해 둔 설정에서는 새 앱이 시작할 때 "이미 연결됨"으로 보고 `settings.json`을 바꾸지 않는다.
  병행 중에는 새 앱의 "Claude 연동" 해제 메뉴를 누르지 않는다(두 앱이 공유하는 훅이 빠진다).
- 번들 식별자가 다르면 `UserDefaults`도 별개라서 새 앱은 설정(색상, 테마, 유리 단계, 패널 표시, 알림, 연동 여부)이 기본값으로 시작한다.
  원본 코드는 `connectsClaudeCode`(기본값 true)가 켜져 있고 훅이나 statusLine이 빠져 있으면 시작할 때 연결하고, 이때 `~/.claude/settings.json`(백업 생성)과 `~/.ai-run/bin`에 쓴다.
  그래서 사용자가 원본에서 연동을 해제한 상태라면 새 앱이 다시 연결할 수 있다. 이를 막으려고 #11에서 새 앱의 `connectsClaudeCode` 미설정 기본값을 false로 정했다. 새 앱은 처음에는 자동 연결하지 않고, 메뉴의 "Claude 연동"을 켠 뒤에만 시작할 때 연결한다.

### 개발 중 지켜야 할 불변 조건

작업이 끝날 때까지 사용자가 쓰는 설치된 `ai-run` 앱, `~/Desktop/ai-run` 소스, `~/.ai-run`, `~/.claude/settings.json`을 변경하지 않는다.

- `apps/macos/scripts/install-app.sh`는 `~/Applications/Desktoto.app`을 지우고 덮어쓰는데, 원본 앱이 같은 경로에 설치되어 있다. 번들 식별자가 다르면 스크립트가 중단하도록 막아 두었지만, 이 기간에는 실행하지 않는다.
  새 앱은 `apps/macos/build/Desktoto.app`을 직접 연다.
- 테스트는 실제 `~/.claude`, `~/.ai-run`을 읽거나 쓰지 않는다(임시 폴더와 가짜 구현만 쓴다).

## 2. 패키지 레이아웃

```
apps/macos/
├── Package.swift
├── Sources/
│   ├── Domain/
│   ├── Boundaries/
│   ├── DesignSystem/
│   ├── SessionMonitoring/
│   ├── UsageMonitoring/
│   ├── ClaudeIntegration/
│   ├── TerminalIntegration/
│   ├── Preferences/
│   ├── MenuBarIcon/
│   ├── SessionPanel/
│   ├── CZstd/            C 라이브러리(벤더링), include/ 와 LICENSE 포함
│   ├── TestSupport/      테스트용 가짜 구현
│   └── Desktoto/         실행 파일(앱 진입점, 조립)
├── Tests/
│   └── 모듈이름Tests/    그 모듈에 코드가 생기는 이슈에서 만든다(골격 단계에는 CZstdTests만 있다)
├── Resources/            앱 번들에 복사할 스크립트(8장 참고)
└── scripts/              패키징 스크립트(#1)
```

이 구조는 `Package.swift`의 타깃 이름과 폴더가 같다는 뜻이다. 모듈 이름에는 `Desktoto` 접두어를 붙이지 않는다
(패키지를 외부에 공개하지 않아 이름 충돌 위험이 낮다).
#1이 CI 검증용으로 둔 임시 타깃(`DesktotoCore`, `DesktotoCoreTests`)은 이 구조로 교체한다.

## 3. 모듈

| 모듈 | 책임 | 의존 | 대응 이슈 | 주요 원본 |
| --- | --- | --- | --- | --- |
| `Domain` | 값 타입: `AiTool`, `SessionInfo`, `SessionRunState`, `WaitingKind`, `ToolUsage`, `UsageWindow`와 기능 사이 연결용 프로토콜 | 없음 | #4, #6 | `SessionWatcher`와 `UsageWatcher`의 타입 선언 |
| `Boundaries` | 외부 경계 프로토콜 5개와 실제(Live) 구현, 두 기능이 쓰는 JSONL 끝부분 읽기 | `Domain`은 쓰지 않음 | 전체 | `LogTail`, 여러 파일에 흩어진 파일, 프로세스, 시간 접근 코드 |
| `DesignSystem` | 디자인 토큰(색, 간격, 곡률, 그림자, 타이포), `GlassStyle`, `Theme`, `ColorMode`, 공용 컴포넌트 | 없음 | #3 | `SessionPanelView`의 상수와 컴포넌트, `AppSettings`의 스타일 타입 |
| `SessionMonitoring` | 기록 탐색, 진행과 완료와 대기 판정, 컨텍스트 창 판정, 승인 대기 신호 읽기 | `Domain`, `Boundaries` | #4 | `SessionWatcher` |
| `UsageMonitoring` | 사용량 소스 4곳(데스크탑 캐시, statusLine 파일, Codex 서버, Codex 기록)과 최신값 선택, zstd 해독 | `Domain`, `Boundaries`, `CZstd` | #6 | `UsageWatcher`, `ClaudeDesktopUsage`, `CodexRateLimitReader` |
| `ClaudeIntegration` | `settings.json`의 훅과 statusLine 연결과 해제, 백업, 스크립트 설치 | `Boundaries` | #7 | `ClaudeIntegration`, `scripts/*.sh` |
| `TerminalIntegration` | CLI 프로세스 탐색, 세션과의 매칭, 터미널 생존 확인, Claude 데스크탑 앱 딥링크 매핑, iTerm2와 Terminal과 Orca 탭 이동, 세션 열기 | `Domain`, `Boundaries` | #5 | `TerminalJumper`, `SessionWatcher`의 생존 확인 |
| `Preferences` | 설정 모델과 저장, 알림, 로그인 항목 | `DesignSystem`, `Boundaries` | #8 | `AppSettings`, `NotificationSender` |
| `MenuBarIcon` | 캐릭터 격자, 프레임 계산, 상태에서 보여 줄 프레임 선택과 진행, 이미지 그리기와 비트맵 묶음 | `Domain`, `DesignSystem` | #9 | `SpriteRenderer`, `AppDelegate`의 아이콘 갱신 |
| `SessionPanel` | 패널 View, 패널 모델, 투명 패널 창과 위치 계산 | `Domain`, `DesignSystem` | #10 | `SessionPanelView`, `AppDelegate`의 `GlassPanel` |
| `Desktoto` | 진입점, 오케스트레이션(감시 타이머, 상태에서 UI로 전달, 알림 트리거, 세션 열기, 시작 시 연동), 우클릭 메뉴 | 위 모듈 중 `CZstd`, `TestSupport`를 제외한 모두 | #11 | `AppDelegate`, `main` |
| `CZstd` | 벤더링한 zstd 해독부 (C) | 없음 | #6 | `Sources/CZstd` |
| `TestSupport` | 테스트용 가짜 구현 | `Boundaries` | 전체 | 없음 |

### 의존 방향

위가 아래를 쓰고, 아래는 위를 모른다.

```
                        Desktoto (App)
   ┌────────────┬────────────┬────┴───────┬────────────┬──────────────┐
SessionPanel MenuBarIcon Preferences SessionMonitoring UsageMonitoring
     │            │          │        ClaudeIntegration  TerminalIntegration
     │            │          │              │                 │
     └─────┬──────┘          │              └────────┬────────┘
      DesignSystem ◄─────────┤                       │
                             └───────── Boundaries ◄─┘
Domain ◄── SessionMonitoring, UsageMonitoring, TerminalIntegration, MenuBarIcon, SessionPanel
CZstd  ◄── UsageMonitoring
```

### 의존 규칙

컴파일러가 강제하도록 `Package.swift`의 타깃 의존으로 표현한다.

1. 기능 모듈(`SessionMonitoring`, `UsageMonitoring`, `ClaudeIntegration`, `TerminalIntegration`, `Preferences`)끼리 서로 import하지 않는다. 조립은 `Desktoto` 앱만 한다.
2. UI 모듈(`SessionPanel`, `MenuBarIcon`)은 `Boundaries`를 import하지 않는다. 파일, 프로세스, 시간에 접근하지 못하고, 표시용 데이터는 모델로 전달받는다.
3. `DesignSystem`은 `Domain`을 모른다. `Domain`은 의존이 없다.

### 기능 사이의 연결

원본에서 `SessionWatcher`는 터미널 세션이 살아 있는지 확인하려고 `TerminalJumper.listCLIProcesses`를 직접 호출했다.
이 교차 의존은 아래처럼 푼다.

- `Domain`에 질문만 담은 프로토콜을 둔다(예: 세션이 속한 터미널 프로세스가 살아 있는지 묻는 프로토콜).
- `SessionMonitoring`은 이 프로토콜을 주입받아 쓴다.
- `TerminalIntegration`이 구현하고 `Desktoto` 앱이 연결한다.

프로토콜은 #5에서 `Domain`에 `TerminalSessionChecker`(터미널 세션이 닫혔는지)와 `SessionLinkResolver`(Claude 세션의 데스크탑 앱 링크)로 정했다.

## 4. 책임 배치 원칙

- 도메인 로직은 해당 기능 모듈에 둔다. 두 기능 이상이 실제로 쓰는 로직만 공용 모듈로 옮긴다.
  이 원칙을 적용한 결과, 기록 파일 끝부분을 읽어 JSON 줄로 해석하는 `LogTail`은 `SessionMonitoring`과 `UsageMonitoring`(Codex 기록의 사용량)이
  함께 쓰므로 `Boundaries`에 둔다.
- 디자인 토큰(색, 간격, 타이포)은 `DesignSystem`에서만 정의하고, UI 모듈은 임의 값을 직접 쓰지 않는다.
- UI 컴포넌트에는 비즈니스 로직을 넣지 않는다.
- 원본의 버그로 보이는 동작은 임의로 고치거나 따라 하지 않고 [작업 명세](tasks/2/spec.md)나 해당 이슈의 명세에 기록한 뒤 결정한다.

## 5. 외부 경계

파일 시스템, 프로세스, 시간, AppleScript 같은 외부 경계는 프로토콜 뒤에 두어 테스트에서 대체할 수 있게 한다.

### 공용 경계 (`Boundaries`)

기본적으로 두 개 이상의 기능이 쓰는 경계를 둔다. 이름에 `Protocol` 접미사는 붙이지 않는다.
설정 파일 쓰기는 #7에서 기존 읽기 경계에 쓰기 권한을 넓히지 않고 공용 가짜 구현으로 실패를 검증하기 위해 별도로 둔다.

| 프로토콜 | 역할 | 쓰는 모듈 |
| --- | --- | --- |
| `FileSystem` | 읽기, 끝부분 읽기, 목록과 시각, 폴더 존재 확인, 홈 폴더 | `SessionMonitoring`, `UsageMonitoring`, `TerminalIntegration`(Claude 터미널 세션 생존 확인에 쓰는 `~/.claude/sessions/*.json`) |
| `SettingsFileSystem` | 읽기 실패와 파일 없음 구별, 제한 읽기, 링크 해석, 원자적 쓰기와 덮어쓰지 않는 복사 | `ClaudeIntegration` |
| `TimeSource` | 현재 시각(`now`). Swift 표준의 `Clock`과 이름이 겹치지 않게 한다. `Timer` 같은 스케줄링은 `Desktoto` 앱이 맡는다 | 거의 전부 |
| `ProcessRunner` | 짧은 명령 실행과 출력 수집, 프로세스 생존 확인. 장기 실행은 아래 보조 경계로 분리 | `TerminalIntegration`(`ps`, `lsof`, Orca CLI, 생존 확인), `UsageMonitoring`(`codex app-server`) |
| `AppleScriptRunner` | 스크립트 문자열 실행 | `TerminalIntegration`, `Preferences` |
| `URLOpener` | URL 열기, 실행 중인 앱 확인 | `TerminalIntegration`, `Desktoto` |

사용처 열은 원본 분석에 따른 현재 예상이며 #4와 #5 구현에서 확정한다. 한 곳만 쓰는 것으로 드러난 경계(예: `URLOpener`)는 그 기능 모듈 안으로 옮긴다.

장기 실행 프로세스는 #6에서 `Boundaries`의 보조 프로토콜 `ProcessLauncher`와 `RunningProcess`로 분리했다.
`ProcessLauncher.launch(executable:arguments:environment:)`가 프로세스를 만들고, `RunningProcess`가 stdin 쓰기, stdout `AsyncStream<Data>`, 종료를 제공한다.
기존 짧은 명령 호출부에 장기 프로세스 수명 관리를 강제하지 않기 위한 분리다.
`UsageMonitoring.CodexRateLimitReader` actor가 요청, 제한 시간, 유휴 종료와 세대 번호를 소유하며 이전 프로세스 출력을 배제한다.
`UsageMonitor` actor는 파일 캐시와 Claude 캐시 탐색 작업을 소유한다.

### 단일 기능 서비스

한 기능만 쓰는 시스템 서비스는 그 기능 모듈 안에 프로토콜을 둔다.

| 서비스 | 위치 |
| --- | --- |
| 알림 센터(`UserNotifications`), 로그인 항목(`SMAppService`) | `Preferences` |
| 소리(`NSSound`) | `Desktoto` |
| `UserDefaults` | 이미 `init(defaults:)`로 주입 가능하므로 프로토콜을 만들지 않는다. 테스트는 `UserDefaults(suiteName:)`를 쓴다 |

### 작성 규칙

- 판정과 파싱은 경계에서 분리해 순수 함수로 둔다. 예를 들어 기록 읽기는 "끝 N바이트 읽기"(경계)와 "바이트에서 JSON 줄 해석"(순수 함수)으로 나눈다.
- 프로토콜은 `Sendable`로 선언한다. 오래 떠 있는 프로세스(`codex app-server`)의 출력은 `AsyncStream`으로 전달한다.
- 외부에서 읽은 데이터(로그, 캐시, 응답)는 미검증 입력이다. 형식 오류와 부분 손상을 코드에서 처리하고, 읽지 못하면 값 없음으로 돌려준다(원본의 대응 방식 유지).
- 시간에 의존하는 로직은 기준 시점을 `TimeSource`로 주입받는다.

## 6. 테스트 전략

| 층 | 방법 |
| --- | --- |
| 순수 함수 | 합성 JSON 줄과 합성 바이트로 단위 테스트한다. 사용자의 실제 세션 로그는 입력으로 커밋하지 않는다 |
| 기능 로직 | `TestSupport`의 가짜 구현을 주입한다: `InMemoryFileSystem`, `FixedTimeSource`, `ScriptedProcessRunner`(명령별 정해진 출력), `RecordingAppleScriptRunner` |
| Live 구현 | 임시 폴더에서만 통합 테스트한다. 실제 `~/.claude`, `~/.ai-run`은 읽거나 쓰지 않는다. 사용자 환경의 파일을 수정하는 동작(설정, 훅 설치)은 테스트 준비 과정에서 실행하지 않는다 |
| 외부 앱 제어 | iTerm2, Terminal, Orca 탭 이동, 알림, 로그인 항목은 실제 Mac에서 수동 검증하고 결과를 PR에 기록한다 |
| 프레임워크 | Swift Testing(`import Testing`) |
| 모듈 경계 | 모듈마다 `모듈이름Tests` 테스트 타깃을 두되, 그 모듈에 실제 코드가 생기는 이슈에서 코드와 함께 만든다. 항상 통과하는 의미 없는 테스트는 만들지 않는다 |
| 골격 단계 | `CZstdTests`가 합성 zstd 프레임 둘(원본 블록 14바이트, `zstd -19`로 만든 압축 블록)을 해독해 원문과 비교하고, 잘리거나 손상된 프레임을 거부하는지 확인한다. 이것으로 `swift test`가 실제로 실행되고 해독 경로(프레임 헤더, 허프만과 FSE, 체크섬)가 `ZSTD_DISABLE_ASM`으로 빌드한 상태에서 동작함을 확인한다 |
| 환경 | 로컬 Mac(macOS 27.0.1, Xcode 27.1)은 최소 버전(26)보다 높다. 최소 버전 호환은 CI(macos-26, Xcode 26.6)가 확인한다 |

## 7. 동시성

Swift 6 모드이므로 컴파일러가 데이터 레이스를 검사한다. 세부 격리 설계는 각 기능 이슈에서 하고, 공통 원칙은 컨벤션을 따른다.

- 값 타입(`Domain`)은 `Sendable`이다.
- UI 상태는 `@MainActor`로 격리한다. 모든 서비스를 일괄 `@MainActor`로 만들지 않는다.
- 비동기 작업은 소유자, 취소, 재실행, 종료 시점을 정하고 오래된 결과가 현재 상태를 덮어쓰지 않게 한다.
- `@unchecked Sendable`은 근거 없이 쓰지 않는다. AppKit 격리 때문에 막히는 타깃은 `swiftLanguageModes`를 타깃 단위로 낮출 수 있고, 그 경우 이유를 이 문서에 적는다.
- 원본은 `async/await`, `@MainActor`, `Sendable` 없이 GCD, `NSLock`, `Timer`로 구성되어 있어 재설계가 필요하다(특히 `CodexRateLimitReader`).

## 8. 스크립트와 리소스

훅과 statusLine 스크립트(`ai-run-hook.sh`, `ai-run-statusline.sh`)는 `apps/macos/Resources`에 두고 앱 번들 `Contents/Resources`에 포함한다.
앱이 Claude Code 설정에 연동을 넣을 때 `~/.ai-run/bin`으로 복사한다(원본과 같은 방식).
이식과 설치 로직은 #7의 `ClaudeIntegration`이 맡는다. 번들 구성은 `scripts/build-app.sh`의 `RESOURCES_DIR` 옵션을 쓰며 기본값은 `Resources`다.
설정 쓰기는 `Boundaries/SettingsFileSystem.swift`의 별도 경계로 분리한다. 기존 읽기 전용 `FileSystem`은 유지한다.
`ClaudeIntegrationTests`는 설정 변환, 백업과 쓰기 실패, 임시 HOME에서 스크립트 실행을 검증한다.
자동 연결 허용 여부(`AppSettings.connectsClaudeCode`)의 영속 저장과 앱 조립은 #11에서 했다. 미설정 기본값은 false이고, false이면 시작 연결은 파일을 조회하거나 변경하지 않는다. 같은 번들 식별자의 이전 빌드가 true를 저장해 둔 경우에는 시작할 때 연결하므로, 병행 검증 전에 저장값을 확인한다.

## 9. 이후 이슈로 넘기는 것

- 모듈별 타입과 프로토콜의 상세 시그니처: 각 기능 이슈(#4 이후)의 명세
- 디자인 토큰 값과 컴포넌트 목록: #3과 `docs/design-system.md`
- 캐릭터 프레임 규칙, 패널 레이아웃 상수, 캐시와 JSON-RPC 세부 동작: 해당 기능 이슈에서 원본을 다시 읽고 `docs/reverse/`에 추가한다([원본 동작 개요](reverse/overview.md) 9장)
- 원본 statusLine을 외부 명령이 감싼 경우 해제 시 바깥 명령이 손실됨을 #7에서 합성 실행으로 확인했다. 승인된 방식은 정확한 생성 형식만 복원하고 나머지는 설정 전체를 보존하며 복원 불가를 알리는 것이다. 상세 입력은 `reverse/claude-integration.md`에 기록한다.

## 10. 원본 파일과 모듈 대응

| 원본 파일 | 이동할 모듈 |
| --- | --- |
| `AppDelegate.swift` | `Desktoto`(오케스트레이션, 메뉴), `SessionPanel`(`GlassPanel`, 패널 위치), `MenuBarIcon`(아이콘 갱신 입력) |
| `SessionWatcher.swift` | `SessionMonitoring`(기록 판정), `TerminalIntegration`(터미널 생존 확인) |
| `SessionPanelView.swift` | `SessionPanel`(View와 모델), `DesignSystem`(토큰과 컴포넌트) |
| `SpriteRenderer.swift` | `MenuBarIcon` |
| `CodexRateLimitReader.swift`, `ClaudeDesktopUsage.swift`, `UsageWatcher.swift` | `UsageMonitoring` |
| `ClaudeIntegration.swift`, `scripts/ai-run-*.sh` | `ClaudeIntegration` |
| `TerminalJumper.swift` | `TerminalIntegration` |
| `AppSettings.swift` | `Preferences`(설정), `DesignSystem`(`ColorMode`, `GlassStyle`, `Theme`) |
| `NotificationSender.swift` | `Preferences`(알림, 로그인 항목) |
| `LogTail.swift` | `Boundaries` |
| `main.swift` | `Desktoto` |
| `Sources/CZstd` | `CZstd` |
| `scripts/build-app.sh`, `scripts/Info.plist`, `scripts/make-icon.swift` | #1에서 `apps/macos/scripts`로 이식 완료(이름 기본값만 #2에서 갱신) |
| `landing/` | #12 (`apps/web`) |
