# 작업 명세: [Feat] 프로세스 및 터미널 연동 구현

## 연결 정보

- 이슈: #5 / https://github.com/huniversal/Desktoto/issues/5
- 브랜치: `feat/process-terminal-integration/#5`
- specRevision: 1
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

### 포함: 2단계 (#4 병합 후)

- 세션과 CLI 프로세스 매칭: 작업 폴더가 같은 프로세스 중 세션 시작 시각 직전에 시작된 것을 고른다 (`findProcess`)
- 터미널 세션 생존 확인
  - Claude: `~/.claude/sessions/<pid>.json`의 `pid` 생존 확인 (`FileSystem`과 `ProcessRunner` 사용)
  - Codex: 같은 작업 폴더의 터미널 `codex` 프로세스 존재 확인
- `SessionMonitoring`이 주입받는 생존 확인 질문 프로토콜을 `Domain`에 정의하고 `TerminalIntegration`이 구현 (`docs/architecture.md` 3장)
- Claude 데스크탑 앱 딥링크 매핑 (`claude-code-sessions/**/*.json`의 `cliSessionId`와 `sessionId` 짝짓기, `claude://claude.ai/epitaxy/<id>`)과 URL 열기
- 세션 열기 진입점: `openURL`이 있으면 URL을 열고, 없고 터미널 세션이면 탭으로 이동

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

2단계 (#4 병합 후 이 명세를 개정해 확정)

- AC-8: 작업 폴더가 같은 프로세스 중 세션 시작 시각 직전에 시작된 프로세스를 고른다.
- AC-9: Claude 세션 파일의 `pid`가 살아 있는지로 터미널 세션 생존을 판정한다.
- AC-10: Codex 세션은 같은 작업 폴더의 터미널 `codex` 프로세스가 있는지로 판정한다.
- AC-11: 데스크탑 앱 딥링크 매핑이 `cliSessionId`로 `claude://claude.ai/epitaxy/<id>` URL을 만든다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1부터 AC-7 | `cd apps/macos && swift test` (합성 출력과 가짜 구현) | 통과 |
| AC-1부터 AC-7 | `cd apps/macos && swift build` | 경고 없이 성공 |
| 실제 탭 이동 | 실제 Mac에서 iTerm2, Terminal.app, Orca 각각에서 실행 중인 CLI 세션의 탭으로 이동 확인 | 수동 검증 후 macOS, 앱 버전과 결과를 PR에 기록 |
| AC-8부터 AC-11 | 2단계에서 정의 | 2단계에서 정의 |

## 미결정 사항

- `ProcessRunner`, `AppleScriptRunner`, `URLOpener`의 구체 시그니처. 구현 전에 합의한다. `ProcessRunner`는 `UsageMonitoring`(#6)도 쓰므로 오래 떠 있는 프로세스 실행 부분을 이번에 함께 정의할지, #6으로 미룰지 정해야 한다. 구현을 막는다.
- `FileSystem`과 `TimeSource`는 #4도 `Boundaries`에 추가할 가능성이 높다. 충돌을 피하려고 1단계에서는 만들지 않고, 2단계에서 #4의 결과를 따른다.
- 원본이 `NSAppleScript`를 쓰는 점과 Swift 6 동시성 격리를 어떻게 맞출지. 구현 중 정한다.
- 원본의 버그로 보이는 동작이 있으면 임의로 고치지 않고 이 절에 기록한다. 아직 발견하지 못했다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계. #4 의존 여부로 1단계와 2단계를 나눔 | 사용자와 합의한 진행 방식 (#4 없이 가능한 작업을 먼저 하고, #4 병합 후 나머지를 진행) |
