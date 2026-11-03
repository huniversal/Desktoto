# 작업 명세: [Feat] 프로세스 및 터미널 연동 구현

## 연결 정보

- 이슈: #5 / https://github.com/huniversal/Desktoto/issues/5
- 브랜치: `feat/process-terminal-integration/#5`
- specRevision: 2
- 대상 ai-run 원본:
  - `~/Desktop/ai-run/Sources/AiRun/TerminalJumper.swift` (248줄 전체)
  - `~/Desktop/ai-run/Sources/AiRun/SessionWatcher.swift` (터미널 생존 확인 204행 이후, Claude 데스크탑 앱 딥링크 매핑 509행 이후)
  - `~/Desktop/ai-run/Sources/AiRun/AppDelegate.swift` (`openSession`, 112행 이후)
- 동작 문서화 위치: `docs/reverse/overview.md` 2.2장, 4.5장 (추가 문서화가 필요하면 `docs/reverse/`에 보강)

## 목적

세션 목록에서 줄을 눌렀을 때 그 세션이 있는 곳(데스크탑 앱 대화 또는 터미널 탭)으로 이동하고,
이미 닫힌 터미널 세션은 목록에서 제외할 수 있게 한다.
외부 앱 제어와 프로세스 실행은 프로토콜 뒤에 두고, 파싱과 매칭과 선택 로직은 순수 함수로 분리해 단위 테스트한다.

## 진행 단계

#5는 #4(`SessionInfo` 모델)가 병합되기 전에도 일부를 진행할 수 있다. 두 단계로 나눠 진행한다.

- 1단계 (#4 없이 진행): `SessionInfo`에 의존하지 않는 부분
- 2단계 (#4 병합 후 진행): `SessionInfo`를 입력으로 받는 부분

## 작업 범위

### 포함: 1단계

- `Boundaries`에 `ProcessRunner`, `AppleScriptRunner`, `URLOpener` 프로토콜과 Live 구현 추가 (시그니처는 미결정 사항 참고)
- `TestSupport`에 `ScriptedProcessRunner`, `RecordingAppleScriptRunner` 등 가짜 구현 추가
- `TerminalIntegration`의 순수 함수
  - `ps -axo pid=,tty=,etime=,comm=` 출력 파싱, `etime` 경과 시간 변환 (`convertElapsedTimeToSeconds`)
  - `lsof -a -p <pid> -d cwd -Fn` 출력에서 작업 폴더 추출
  - 조상 프로세스를 따라 올라가 Orca 앱 경로 찾기 (`findAncestorAppPath`)
  - Orca `terminal list --json` 파싱, 워크트리 폴더 기준 탭 선택, `terminal switch` 성공 판정
  - iTerm2, Terminal.app용 AppleScript 문자열 생성
- 터미널 탭 이동 서비스: tty로 iTerm2와 Terminal.app 탭을 선택하고, 실행 중인 앱에만 요청한다. Orca는 CLI로 탭을 고른다.
- 위 순수 함수와 서비스의 단위 테스트 (`TerminalIntegrationTests`)

### 포함: 2단계 (#4 병합 완료, specRevision 2에서 확정)

- `ProcessRunner`에 프로세스 생존 확인(`isProcessAlive(pid:)`)을 추가한다. `kill(pid, 0)`이 성공하거나 `EPERM`이면 살아 있는 것으로 본다.
- `Domain`에 연결용 프로토콜 2개를 정의한다. 기능 모듈끼리 import하지 않으므로 `SessionMonitoring`은 이 프로토콜만 안다.
  - `TerminalSessionChecker`: 터미널 세션이 닫혔는지 묻는다. `isClosed(sessionID:tool:workingDirectory:) -> Bool`, 판단할 수 없으면 `false`.
  - `SessionLinkResolver`: Claude 세션을 데스크탑 앱에서 여는 링크를 묻는다. `url(forSessionID:) -> URL?`
- `TerminalIntegration`이 두 프로토콜을 구현한다.
  - 터미널 세션 생존 확인: Claude는 `~/.claude/sessions/<pid>.json`의 `sessionId`와 `pid` 생존으로, Codex는 같은 작업 폴더의 터미널 `codex` 프로세스 존재로 판단한다. 원본의 갱신 주기 캐시(Claude 1초, Codex 5초)는 구현체 안에 둔다.
  - 데스크탑 앱 딥링크 매핑: `~/Library/Application Support/Claude/claude-code-sessions/**/*.json`의 `cliSessionId`와 `sessionId`를 짝지어 `claude://claude.ai/epitaxy/<sessionId>`를 만든다. 못 찾았을 때 10초 안에는 다시 읽지 않는다.
- 세션과 CLI 프로세스 매칭: 작업 폴더가 같은 프로세스 중 세션 시작 시각 직전(허용 오차 120초)에 시작된 것을 고른다.
- 세션 열기 진입점 `open(session:)`: `openURL`이 있으면 URL을 열고, 없고 터미널 세션이면 프로세스를 매칭해 탭으로 이동한다.
- `SessionMonitoring` 연결(#4 코드 수정): `SessionMonitor`가 두 프로토콜을 선택 인자로 주입받는다.
  - `TerminalSessionChecker`가 닫혔다고 답한 터미널 세션을 `sessionStates`, `activeSessions` 등 모든 조회 결과에서 제외한다. Claude의 터미널 여부는 기록의 `entrypoint`가 `cli`인지로, Codex는 `originator`로 정한다(#4 구현 재사용).
  - Claude 세션의 `openURL`을 `SessionLinkResolver`로 채운다. 주입하지 않으면 #4의 기존 동작(nil)과 같다.

### 제외

- 세션 기록 판정, `SessionInfo` 정의 (#4)
- 패널 UI와 줄 클릭 연결, 앱 조립 (#10, #11)
- iTerm2, Terminal.app, Orca 이외 터미널 지원 (원본도 지원하지 않음)
- 코드 서명과 자동화 권한 문구 (`Info.plist`) 변경

## 설계 결정

- 파일 구조와 로직의 책임: 코드는 `apps/macos/Sources/TerminalIntegration`에 두고, 외부 경계 프로토콜은 `apps/macos/Sources/Boundaries`, 가짜 구현은 `apps/macos/Sources/TestSupport`에 둔다. 파일 단위 분할은 구현 시 정한다.
- 상태와 데이터 흐름: 프로세스 목록과 Claude 세션 파일은 호출 시점에 읽는다. 원본의 갱신 주기 캐시(Claude 1초, Codex 5초)는 호출하는 쪽(`SessionMonitoring`)의 책임인지 2단계에서 정한다.
- 선택한 방식과 이유: 원본 동작을 유지하되 코드를 복사하지 않고, 프로세스 실행과 AppleScript 호출을 경계 뒤로 빼서 순수 로직을 단위 테스트한다 (`docs/architecture.md` 5장).
- 예외 처리: 외부 출력은 미검증 입력이다. 형식이 틀리면 값 없음이나 `false`로 돌려준다. 작업 폴더를 읽지 못한 Codex 프로세스가 있으면 세션이 닫혔다고 판단하지 않는다 (원본 동작).

## 완료 조건

1단계

- AC-1: `ps` 출력 한 줄을 pid, tty, 경과 시간, 명령 이름으로 파싱하고, tty가 `??`인 줄(데스크탑 앱이 띄운 프로세스)과 형식이 틀린 줄을 제외한다.
- AC-2: `etime`의 `분:초`, `시:분:초`, `일-시:분:초` 형식을 초로 변환하고, 잘못된 형식은 값 없음으로 돌려준다.
- AC-3: `lsof -Fn` 출력에서 작업 폴더를 추출하고, 출력이 비었거나 `n` 줄이 없으면 값 없음으로 돌려준다.
- AC-4: 조상 프로세스를 따라 올라가 Orca 앱 경로를 찾고, 순환하거나 없으면 값 없음으로 돌려준다.
- AC-5: Orca 탭 목록 JSON을 파싱하고, 작업 폴더를 포함하는 워크트리 중 가장 깊은 것을 고르며, 같은 워크트리에 탭이 여럿이면 세션 제목이 겹치는 탭을 우선한다. 형식이 틀린 JSON은 빈 목록이 된다.
- AC-6: 실행 중인 터미널 앱에만 AppleScript를 요청하고, 처음으로 `true`를 돌려준 앱에서 멈춘다. 실행 중인 앱이 없으면 요청하지 않는다.
- AC-7: 위 로직이 실제 프로세스나 AppleScript 없이 가짜 구현만으로 테스트된다.

2단계

- AC-8: 작업 폴더가 같은 프로세스가 여럿이면 세션 시작 시각 직전에 시작된 프로세스를 고르고, 하나면 그것을, 없으면 값 없음을 돌려준다. 시작 시각이 없으면 첫 후보를 고른다.
- AC-9: Claude 세션은 `~/.claude/sessions/*.json` 중 pid가 살아 있는 파일의 `sessionId`에 들어 있으면 열려 있고, 없으면 닫혔다. 폴더를 읽을 수 없거나 없으면 닫혔다고 보지 않는다. 형식이 틀린 파일은 건너뛴다.
- AC-10: Codex 세션은 같은 작업 폴더의 터미널 `codex` 프로세스가 있으면 열려 있고, 없으면 닫혔다. 작업 폴더를 모르는 세션이나 작업 폴더를 읽지 못한 프로세스가 있으면 닫혔다고 보지 않는다.
- AC-11: 데스크탑 앱 매핑이 `cliSessionId`로 `claude://claude.ai/epitaxy/<sessionId>`를 만들고, 매핑이 없거나 파일 형식이 틀리면 값 없음이다. 갱신 주기 안에서는 파일을 다시 읽지 않는다.
- AC-12: `SessionMonitor`는 `TerminalSessionChecker`가 닫혔다고 답한 터미널 세션을 조회 결과에서 제외하고, 터미널 세션이 아니거나 열려 있는 세션은 유지한다. 주입하지 않으면 #4와 같게 동작한다.
- AC-13: `SessionMonitor`는 `SessionLinkResolver`가 돌려준 URL을 Claude 세션의 `openURL`로 채운다. 값이 없으면 nil이다.
- AC-14: `open(session:)`은 `openURL`이 있으면 URL을 열고, 없고 터미널 세션이면 탭 이동을 시도하며, 둘 다 아니면 `false`를 돌려준다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1부터 AC-7 | `cd apps/macos && swift test` (합성 출력과 가짜 구현) | 통과 |
| AC-1부터 AC-7 | `cd apps/macos && swift build` | 경고 없이 성공 |
| 실제 탭 이동 | 실제 Mac에서 iTerm2, Terminal.app, Orca 각각에서 실행 중인 CLI 세션의 탭으로 이동 확인 | 수동 검증 후 macOS, 앱 버전과 결과를 PR에 기록 |
| AC-8부터 AC-14 | `cd apps/macos && swift test` (가짜 `FileSystem`, `ProcessRunner`, `TimeSource`로 합성 입력) | 통과 |
| AC-8부터 AC-14 | `cd apps/macos && swift build` | 경고 없이 성공 |
| AC-9, AC-10, AC-11 | 실제 Mac에서 `ps`, `lsof`, `~/.claude/sessions`, 데스크탑 앱 세션 파일로 생존 확인과 링크 확인 | 수동 검증 후 결과를 PR에 기록 |

## 미결정 사항

- `NSAppleScript`는 메인 스레드에서 호출하는 것이 안전하다. 원본은 줄 클릭 핸들러(메인)에서 호출했다. `SystemAppleScriptRunner`는 스레드를 강제하지 않으므로, 앱에 연결하는 #11에서 `open(session:)`을 메인에서 호출하게 해야 한다. 구현을 막지 않는다.
- `docs/architecture.md` 3장 표는 딥링크 매핑을 `SessionMonitoring` 책임으로 적었지만, #4 명세가 #5로 넘겼고 이 명세는 `TerminalIntegration`에 둔다. 구현 후 표를 맞춰 고친다.
- 원본의 버그로 보이는 동작이 있으면 임의로 고치지 않고 이 절에 기록한다. 아직 발견하지 못했다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계. #4 의존 여부로 1단계와 2단계를 나눔 | 사용자와 합의한 진행 방식 (#4 없이 가능한 작업을 먼저 하고, #4 병합 후 나머지를 진행) |
| 2 | 2단계 확정: `Domain` 프로토콜 2개, `SessionMonitor` 주입, Claude `openURL` 채우기, `ProcessRunner.isProcessAlive` 추가 (AC-8부터 AC-14) | #4 병합 후 `SessionMonitor`가 생존 확인을 하지 않고 Claude `openURL`이 nil이라는 점을 확인. 기능 모듈끼리 import하지 못하므로 `Domain` 프로토콜로 연결 |
