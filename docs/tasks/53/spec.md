# 작업 명세: [Feat] 터미널 CLI 환경의 토큰 및 컨텍스트 사용량 확인 지원

## 연결 정보

- 이슈: #53 / https://github.com/huniversal/Desktoto/issues/53
- 브랜치: feat/terminal-cli-usage/#53
- specRevision: 5
- 대상 ai-run 원본: N/A (원본은 iTerm2, Terminal, Orca만 탭 이동을 지원하고 cmux 지원은 없다. 코드는 `apps/macos/Sources/TerminalIntegration/TerminalTabFocuser.swift`의 주석 "다른 터미널은 지원하지 않는다(원본 동작)"로 확인함)

## 목적

데스크탑 앱이 아니라 터미널 앱(iTerm2, Terminal, cmux, Orca)에서 CLI로 Claude Code와 Codex를 쓰는 사용자도
세션별 컨텍스트와 사용 토큰을 확인하고, 세션 줄을 눌러 해당 터미널 탭으로 이동할 수 있게 한다.

2026-11-05에 cmux에서 실측한 결과, 세션 표시와 컨텍스트 값은 이미 터미널 세션에서도 동작한다.
터미널 앱별로 모자란 것은 cmux의 탭 이동 하나다. 이 명세는 실측 결과를 기록하고 cmux 탭 이동의 설계와 완료 조건을 정한다.

## 조사 결과

실측 환경: macOS 27.0.1, cmux 0.62.2, Claude Code 2.1.318(Opus 5.5), Codex CLI 0.166.0-alpha.6(Codex.app에 포함된 CLI), 날짜 2026-11-05.
이 PC의 npm `codex`는 `@openai/codex-darwin-arm64` 의존성이 빠져 실행되지 않아서, 앱에 포함된 CLI로 실행했다. 사용자 환경은 바꾸지 않았다.

### 세션 표시와 컨텍스트 (cmux에서 실측)

- Claude Code: 기록의 `entrypoint == "cli"`로 터미널 세션을 판별한다. 사용 토큰은 가장 최근 응답의 `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`다.
  창 크기는 statusLine이 저장한 `~/.ai-run/status/<세션id>.json`의 `context_window.context_window_size`를 우선 쓴다. 실측에서 1,000,000과 사용률 4%가 나왔고 Desktoto 카드도 4%로 표시했다.
- Codex: 첫 줄의 `originator`가 `codex-tui`이면 터미널 세션이다. 실측에서 `last_token_usage.input_tokens` 23,477과 `model_context_window` 475,000이 나왔고 Desktoto 카드는 `23K / 475K`로 표시했다.
- 두 값은 터미널 화면이 아니라 디스크의 기록 파일에서 읽으므로 터미널 앱과 관계없다. cmux에서 실측했고 iTerm2, Terminal, Orca는 같은 경로라서 이번에 따로 실측하지 않았다.
- cmux는 `claude`를 `--session-id`와 cmux 훅 설정을 붙여 실행한다. 프로세스 이름은 그대로 `claude`라서 기존 프로세스 매칭에 영향이 없었다.

### 터미널 앱별 현황

| | iTerm2 | Terminal | Orca | cmux |
|---|---|---|---|---|
| Claude, Codex 세션과 컨텍스트 표시 | 됨(코드상) | 됨(코드상) | 됨(코드상) | 됨(실측) |
| 카드 클릭 시 탭 이동 | 됨(코드상) | 됨(코드상) | 됨(코드상) | 안 됨(실측, 코드 없음) |

### IDE 통합 터미널 (VS Code에서 실측)

- VS Code 통합 터미널에서 실행한 Claude Code는 카드에 정상 표시됐다(모델 `claude-opus-5-5`, 컨텍스트 47K / 1M). 프로세스 구조는 `claude` <- `zsh` <- `Code Helper` <- `Visual Studio Code`이고 환경에 `TERM_PROGRAM=vscode`가 있다.
- 카드를 눌러도 VS Code가 앞으로 오지 않았다. `TerminalTabFocuser`에 IDE 처리가 없어서 이동하지 못한 것으로 끝난다.
- VS Code에는 외부에서 통합 터미널 탭이나 특정 창을 지정해 포커스하는 방법이 없다. 앱 단위로만 앞으로 가져올 수 있다.
- 이 PC에 설치된 IDE의 번들 식별자: VS Code `com.microsoft.VSCode`, Antigravity IDE `com.google.antigravity-ide`(Antigravity 앱 `com.google.antigravity`와 다른 앱이다). Antigravity IDE와 VS Code의 Codex CLI는 아직 실측하지 않았다.

### cmux 탭 이동 가능성 (실측)

- cmux AppleScript(`focus`, `select tab`)는 `macos-applescript` 설정으로 꺼져 있다. ghostty 설정 파일 세 위치에 `macos-applescript = true`를 넣고 재시작해도 켜지지 않아 이 경로는 쓰지 않는다. 설정은 모두 원래대로 되돌렸다.
- cmux CLI(`/Applications/cmux.app/Contents/Resources/bin/cmux`)는 Unix 소켓으로 제어한다. 기본 모드 "cmux 프로세스만"에서는 cmux 밖의 프로세스가 `Access denied`로 거부된다.
  설정 > 자동화 > 소켓 제어 모드에서 모드를 고를 수 있다. 모드는 끔, cmux 프로세스만(기본), 자동화 모드(같은 macOS 사용자의 외부 로컬 클라이언트 허용, 출처 확인 없음), 비밀번호 모드, 전체 개방 접근이다.
- 자동화 모드로 바꾸고 외부 셸에서 확인했다.
  - `cmux ping`은 `PONG`, `cmux tree --all`은 창, 작업 공간, 패널 구조를 돌려줬다.
  - cmux 터미널 안의 프로세스 환경에 `CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`(그리고 `CMUX_TAB_ID`, `CMUX_PANEL_ID`)가 있고, 값이 `cmux --id-format both tree`의 UUID와 일치했다. 환경은 `ps eww -p <pid>`로 읽혔다.
  - `cmux select-workspace --workspace <UUID>`와 `cmux focus-panel --panel <UUID>`가 해당 작업 공간으로 전환했다(Claude와 Codex 각각 확인). 성공하면 표준 출력이 `OK ...`로 시작했다.
  - 실패(소켓 거부)는 표준 출력이 아니라 오류 출력으로 나왔다(`Error: ...`).
- 검증 뒤 소켓 모드를 기본값으로 되돌렸고, 되돌린 뒤 외부 `ping`이 다시 거부되는 것을 확인했다.
- 확인하지 못한 것: 이동 뒤 cmux 창이 맨 앞으로 오는지, 분할 패널이 여럿인 작업 공간에서의 동작, Desktoto 앱 안에서의 실제 클릭.

## 작업 범위

범위는 2026-11-05에 사용자가 "Claude와 Codex부터"로 정했다. cmux 탭 이동의 포함은 위 실측을 근거로 한 제안이며, 이 명세에 대한 사용자 승인으로 확정한다.

### 포함

- Claude Code와 Codex의 터미널 세션이 iTerm2, Terminal, cmux, Orca에서 컨텍스트와 토큰을 표시하는 현황을 위 표로 명세에 기록한다(작성 완료).
- cmux에서 실행 중인 Claude와 Codex 세션 줄을 누르면 해당 cmux 작업 공간과 패널로 이동하고 cmux를 앞으로 가져온다.
- cmux 소켓 접근이 막혀 있을 때의 처리(이동 실패로 보고).
- IDE 통합 터미널(VS Code, Antigravity IDE)에서 실행 중인 세션 줄을 누르면 그 IDE 앱을 앞으로 가져온다. 창이나 터미널 탭은 지정하지 못한다(specRevision 5).
- 우클릭 설정 메뉴의 "사용 안내…" 항목과 안내 창. 항상 보이며, 터미널과 앱별로 사용자가 알아야 할 제약과 설정 방법을 정리해 보여 준다(specRevision 3).
- 새 로직의 단위 테스트.

### 제외

- Gemini CLI와 Antigravity CLI(`agy`)의 토큰과 컨텍스트 읽기. 이슈 본문에는 있으나 이번에는 Claude와 Codex부터 하기로 해서 제외한다. 후속으로 다룬다.
- 누적 토큰 표시. 기록에 누적 값이 있으나(`total_token_usage`, statusLine의 `total_input_tokens`) 현재 화면은 마지막 턴의 컨텍스트 값만 쓰며, 요청된 적이 없다.
- 사용자의 cmux 설정 변경이나 설치. 앱이 cmux의 소켓 모드를 바꾸지 않는다.
- cmux AppleScript 경로.
- iTerm2, Terminal, Orca의 기존 탭 이동 변경.
- IDE의 특정 창이나 통합 터미널 탭 지정. 외부에서 지정할 방법이 없다.
- VS Code와 Antigravity IDE 외의 IDE(Cursor, JetBrains 등). 설치되어 있지 않아 번들 식별자와 프로세스 구조를 확인하지 못했다.

## 설계 결정

- 파일 구조와 로직의 책임:
  - `apps/macos/Sources/TerminalIntegration/CmuxTerminalSelector.swift`(새 파일): `ps eww -p <pid>` 출력에서 `CMUX_SURFACE_ID`를 UUID 형식으로 검증해 뽑는 순수 로직, 그리고 `cmux focus-panel` 성공 출력(`OK`로 시작)을 판정하는 순수 로직.
  - `apps/macos/Sources/TerminalIntegration/TerminalTabFocuser.swift`: 프로세스의 조상 중에 `cmux.app`이 있으면(Orca와 같은 방식, `ProcessListParser.findAncestorAppPath`) cmux 경로로 이동을 시도하고, 성공하면 `com.cmuxterm.app`을 앞으로 가져온다. 조상이 아니면 기존 순서를 그대로 쓴다.
  - 외부 실행은 기존 `ProcessRunner` 경계로만 한다. 새 경계는 만들지 않는다.
- IDE 앱 앞으로(specRevision 5): `apps/macos/Sources/TerminalIntegration/TerminalTabFocuser.swift`에서 Orca와 cmux 다음에, 프로세스 조상에 `Visual Studio Code.app`(`com.microsoft.VSCode`) 또는 `Antigravity IDE.app`(`com.google.antigravity-ide`)이 있으면 그 앱을 활성화하고 true를 돌려준다. 앱 단위이며 창과 탭은 지정하지 않는다. 판정은 기존 `ProcessListParser.findAncestorAppPath`를 쓰고 새 경계는 없다.
- 상태와 데이터 흐름: 세션 줄 클릭 -> 기존 `SessionOpener`가 작업 폴더, 도구 이름, 시작 시각으로 프로세스를 찾음 -> `TerminalTabFocuser.focus`가 조상에서 `cmux.app`을 찾음 -> 그 프로세스의 환경에서 `CMUX_SURFACE_ID`를 읽음 -> `<cmux.app>/Contents/Resources/bin/cmux focus-panel --panel <UUID>` 실행 -> 출력이 `OK`면 cmux를 활성화하고 true. 저장하는 상태는 없다.
- 선택한 방식과 이유: 작업 폴더와 제목으로 탭을 추측하는 Orca 방식 대신, cmux가 프로세스 환경에 넣어 주는 식별자로 패널을 직접 지정한다. 같은 폴더에 세션이 여럿이어도 정확하다. AppleScript는 기본으로 꺼져 있고 켜는 방법을 찾지 못해 제외했다.
- 예외 처리:
  - 환경에서 `CMUX_SURFACE_ID`를 읽지 못하거나 UUID 형식이 아니면 이동을 시도하지 않고 false.
  - cmux CLI 실행 실패, 소켓 거부(`OK`가 아닌 출력), 빈 출력이면 false로 처리하고 앱은 죽지 않는다. 오류는 표준 출력에 나오지 않을 수 있어 "`OK`로 시작하지 않으면 실패"로 판정한다.
  - cmux 안에서 실행 중이 아닌 프로세스(다른 터미널)는 기존 경로를 쓴다.
  - 환경변수 값은 외부 입력이므로 UUID 정규식으로 검증한 뒤에만 명령 인자로 쓴다.
- 사용자 안내(specRevision 3): 설정 메뉴에 "사용 안내…" 항목을 항상 둔다. 누르면 안내 창이 뜬다. 앱은 다른 앱의 설정을 바꾸지 않고 방법만 알려 준다. 안내는 cmux 전용이 아니라 도구별 제약을 정리하는 자리이며, 다른 도구의 항목은 실측하고 합의한 뒤 추가한다.
  - cmux: 세션 줄을 눌러도 cmux 탭으로 자동 이동하지 않는다. cmux 설정 > 자동화에서 "소켓 제어 모드"를 "자동화 모드"로 바꾸면 이동한다. 안내 창은 공식 안내문이라 합니다체로 줄바꿈 단위로 짧게 쓰고, 도구 이름을 `[cmux]`, `[Antigravity]`로 구분한다. 보안 설명 같은 부연은 넣지 않는다(사용자 요청).
  - Antigravity: 한도(사용량 게이지)는 표시하지 못한다(#52에서 제외). 컨텍스트는 모델 이름으로 창 크기를 추정한 값이라 `~`를 붙여 표시한다.
  - VS Code, Antigravity IDE: 카드를 누르면 IDE 앱이 앞으로 오지만 터미널 탭은 직접 찾아야 한다.
  - `apps/macos/Sources/Preferences/SettingsMenu.swift`: `SettingsAction.showUsageGuide`와 항상 보이는 항목. `apps/macos/Sources/Desktoto/AppDelegate.swift`: 항목을 누르면 안내 창을 띄운다. 외부 상태를 읽지 않으므로 새 경계나 모듈은 없다.
  - specRevision 2에서 만들었던 조건부 표시(`CmuxSocketChecker`, `needsCmuxSetup`)는 사용자 의견으로 폐기했다. 설정을 마친 사용자에게도 안내를 볼 수 있어야 하고, 안내가 cmux 전용이 아니기 때문이다.

## 완료 조건

- AC-1: 이슈의 첫 번째 할 일(현황표)이 이 명세의 "조사 결과"에 실측 값과 함께 기록되어 있다.
- AC-2: cmux 소켓이 자동화 모드일 때, cmux에서 실행 중인 Claude 세션 줄을 누르면 그 세션의 cmux 작업 공간과 패널로 이동하고 cmux가 앞으로 온다.
- AC-3: 같은 동작이 Codex 세션에서도 된다.
- AC-4: 같은 작업 폴더의 cmux 세션이 둘 이상이어도 누른 세션의 패널로 이동한다.
- AC-5: cmux 소켓이 기본 모드이거나 환경 식별자를 읽지 못해도 앱이 죽지 않고 이동 실패(false)로 끝난다.
- AC-6: iTerm2, Terminal, Orca의 기존 탭 이동과 Claude와 Codex 세션 표시가 바뀌지 않는다.
- AC-7: 합성 데이터와 가짜 `ProcessRunner`로 단위 테스트가 있고 `swift build`와 `swift test`가 통과한다.
- AC-8: 설정 메뉴에 "사용 안내…" 항목이 항상 보인다(cmux 설정 여부와 관계없이).
- AC-9: 그 항목을 누르면 안내 창이 뜨고, cmux의 탭 이동 설정 방법, Antigravity의 사용량(한도) 미지원, IDE 터미널에서는 앱만 앞으로 오고 탭은 직접 찾아야 한다는 내용이 적혀 있다.
- AC-10: VS Code나 Antigravity IDE의 통합 터미널에서 실행 중인 세션 줄을 누르면 그 IDE 앱이 앞으로 온다. IDE가 아닌 터미널의 기존 이동과 표시는 바뀌지 않는다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | 이 명세의 조사 결과와 터미널 앱별 현황 표 검토 | 도구와 터미널 조합, 값, 환경 버전이 기록됨 |
| AC-2 | cmux에서 `claude`를 실행하고 다른 작업 공간을 선택한 상태에서 Desktoto 카드 클릭(소켓은 자동화 모드) | 해당 작업 공간으로 이동하고 cmux가 앞으로 옴 |
| AC-3 | cmux에서 앱에 포함된 Codex CLI를 실행하고 같은 방식으로 클릭 | 해당 작업 공간으로 이동 |
| AC-4 | 같은 폴더에서 cmux 작업 공간 두 개에 각각 `claude`를 실행하고 카드를 각각 클릭 | 누른 카드의 작업 공간으로 이동. 단위 테스트는 같은 폴더의 두 프로세스를 합성 |
| AC-5 | 소켓 기본 모드에서 클릭, 환경 출력이 비었거나 UUID가 아닌 합성 입력, `cmux`가 `OK`가 아닌 출력을 내는 가짜 실행기로 단위 테스트 | 오류 없이 false |
| AC-6 | 기존 `TerminalTabFocuserTests`, `SessionOpenerTests`, `OrcaTerminalSelectorTests`, `SessionMonitoring` 테스트 전체 | 변경 없이 통과 |
| AC-7 | `cd apps/macos && swift build && swift test` | 통과. 새 테스트는 `Tests/TerminalIntegrationTests`와 `Tests/PreferencesTests`에 추가 |
| AC-8 | 메뉴 항목 목록을 단위 테스트(항상 포함, 위치, 동작 값). 실제 앱 우클릭 메뉴 확인 | 항상 표시 |
| AC-9 | 실제 앱에서 항목을 눌러 안내 창 확인 | cmux 설정 방법, Antigravity 제약, IDE 안내가 보임 |
| AC-10 | 조상이 VS Code, Antigravity IDE인 합성 프로세스 트리와 가짜 `URLOpener`로 단위 테스트(활성화되는 번들 식별자, AppleScript 미호출). 실제 VS Code 통합 터미널에서 카드 클릭 | 해당 IDE 앱이 앞으로 옴 |

실제 앱 확인(AC-2, AC-3, AC-4)은 사용자가 로그인한 cmux와 Claude, Codex가 필요하다. 없으면 미검증으로 기록한다.

## 미결정 사항

- (해결, specRevision 3) 소켓이 막혀 있을 때의 안내 방식: 설정 메뉴의 항상 보이는 "사용 안내…" 항목과 안내 창으로 정했다. 카드를 눌러 이동에 실패한 순간의 즉석 알림은 하지 않는다. 필요하면 후속으로 다룬다.
- Antigravity IDE의 통합 터미널과 VS Code의 Codex CLI는 실측하지 않았다. 구현을 막지는 않는다.
- IDE 창이 여러 개일 때 마지막으로 쓴 창이 앞으로 오는 것으로 예상하며 확인하지 않았다.
- iTerm2, Terminal, Orca의 안내 항목. 필요한 설정(예: macOS 자동화 권한)을 실측하지 않았다. 실측한 뒤 안내에 추가한다. 구현을 막지는 않는다.
- 안내 창의 문구는 초안이며 실제 화면을 보고 다듬는다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 작성. 범위를 Claude와 Codex의 터미널 환경으로 정하고, cmux 탭 이동을 `CMUX_SURFACE_ID`와 `cmux focus-panel`로 구현하는 설계 | 사용자가 Claude와 Codex부터 하기로 함(2026-11-05). cmux에서 세션 표시와 자동화 모드의 탭 이동을 실측으로 확인 |
| 2 | 설정 메뉴에 "cmux 탭 이동 설정 방법…" 항목과 안내 창 추가(AC-8, AC-9). 안내 방식 미결정 해결 | 사용자가 직접 테스트해 이동을 확인한 뒤, 설정을 안 켠 사용자를 위한 안내를 메뉴에 넣자고 제안하고 합의(2026-11-05) |
| 3 | 안내 항목을 cmux 전용 조건부 표시에서, 항상 보이는 "연동 안내…"로 변경. 내용은 cmux 탭 이동 설정과 Antigravity 사용량 미지원. `CmuxSocketChecker`와 `needsCmuxSetup` 폐기(AC-8, AC-9 변경) | 사용자가 설정을 마친 뒤에도 안내가 보여야 하고 다른 도구도 정리할 자리라고 정정(2026-11-05) |
| 4 | 메뉴 항목과 안내 창 이름을 "연동 안내…"에서 "사용 안내…"로 변경. 동작 이름은 `showUsageGuide` | 메뉴에 이미 "Codex 연동", "Claude 연동" 토글이 있어 "연동 안내"가 그 설명으로 읽히고, 내용도 연동 설정이 아니라 도구별 사용 제약이라서(사용자와 합의, 2026-11-05) |
| 5 | IDE(VS Code, Antigravity IDE) 통합 터미널 세션을 누르면 IDE 앱을 앞으로 가져오도록 추가(AC-10). 사용 안내에 IDE 항목 추가(AC-9 변경) | 사용자가 VS Code에서 세션은 표시되지만 카드를 눌러도 IDE가 앞으로 오지 않는다고 확인하고, 앱 앞으로 가져오기로 합의(2026-11-05) |
