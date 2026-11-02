# 원본 동작 개요

> 대상: `~/Desktop/ai-run` (읽기 전용 원본). 이슈 #2의 첫 산출물이다.
> 이 문서는 원본이 하는 일을 입력, 상태, 출력, 외부 의존으로 나눠 기록한다.
> 원본에 있는 사실만 적고 새 설계는 적지 않는다. 설계는 `docs/architecture.md`에서 다룬다.

## 1. 한눈에 보기

Desktoto는 메뉴바에 사는 작은 캐릭터다. Claude Code와 Codex가 남기는 파일을 1초마다 훑어서
"지금 AI가 일하는 중인지, 끝났는지, 사람을 기다리는지"를 캐릭터의 모습과 알림으로 알려 주고,
패널에서 세션별 컨텍스트 사용량과 계정별 5시간, 주간 사용량을 보여 준다.

```
입력(파일, 프로세스)            상태(앱 메모리)              출력
-------------------           ------------------        ------------------
Claude, Codex 세션 기록   -->  세션 진행 상태          -->  메뉴바 아이콘 애니메이션
hook이 남긴 승인 대기 파일      (running, completed,        세션 패널(SwiftUI 유리 창)
statusLine이 남긴 상태 파일      idle) + 대기 이유            우클릭 설정 메뉴
Claude 데스크탑 앱 캐시        컨텍스트 창 크기 판정         macOS 알림과 소리
Codex app-server 응답         사용량 한도(5시간, 주간)      세션 열기(딥링크, 터미널 탭)
사용자 설정(UserDefaults)      아이콘 표시 상태             Claude Code 설정 파일 수정
```

앱은 `NSApplication` 접근 정책 `.accessory`로 뜨는 메뉴바 전용 앱이다(Dock 아이콘 없음).
시작점은 `Sources/AiRun/main.swift`이고, 모든 조립은 `AppDelegate`가 한다.

## 2. 입력

### 2.1 세션 기록 파일

| 항목 | Claude Code | Codex |
| --- | --- | --- |
| 위치 | `~/.claude/projects/**/*.jsonl` | `~/.codex/sessions/**/*.jsonl` |
| 세션 id | 파일 이름(확장자 제외) | 파일 이름(확장자 제외) |
| 대상 | 수정 시각과 기록 안의 마지막 활동 시각이 모두 600초 이내인 파일 | 같음 |
| 진행 판정 | 마지막 `user` 또는 `assistant` 기록의 `stop_reason`이 `end_turn`, `stop_sequence`이면 완료, 아니면 진행 중 | `payload.type`이 `task_complete`이면 완료, `turn_aborted`이면 중단, `task_started` 뒤 기록이 있으면 진행 중 |
| 세션 정보 | `cwd`, `custom-title`, `last-prompt`, `message.model`, `message.usage`, `entrypoint` | 첫 줄 `session_meta`의 `originator`, `cwd`, `id`, 그리고 `token_count`의 `last_token_usage`, `model_context_window` |
| 출처 | `SessionWatcher.swift` | `SessionWatcher.swift` |

읽는 방식은 파일 끝부분만 읽는 꼬리 읽기다(`LogTail.swift`).
기록 끝에 수백 KB짜리 줄이 붙을 수 있어, 작은 창으로 먼저 읽고 못 찾으면 범위를 넓힌다.
상태 판정은 64KB, 512KB, 4MB 순서이고, 세션 정보는 512KB, 4MB, 16MB 순서다.
수정 시각이 같으면 이전 판정을 재사용해서, 1초마다 호출되어도 바뀐 파일만 다시 읽는다.

기록 파일의 마지막 수정 시각은 실제 작업 시각이 아니다(세션을 다시 열거나 백그라운드 명령이 끝나면
앱이 줄을 덧붙인다). 그래서 기록 안의 시각을 따로 읽어 활동 시각으로 쓴다.
제목, 마지막 프롬프트, 비용 같은 부가 기록은 활동으로 치지 않는다.

### 2.2 터미널 세션 생존 확인

터미널(CLI)에서 시작한 세션은 프로세스가 끝나면 기록이 최근이어도 목록에서 뺀다.
데스크탑 앱 세션은 대상이 아니다.

| 도구 | 확인 방법 | 재확인 간격 |
| --- | --- | --- |
| Claude | `~/.claude/sessions/<pid>.json`의 `sessionId`와 `pid`를 읽고 `kill(pid, 0)`으로 생존 확인. 기록의 `entrypoint`가 `cli`일 때만 대상 | 1초 |
| Codex | `ps`로 `codex` CLI 프로세스를 찾고 `lsof`로 작업 폴더를 읽어, 세션의 작업 폴더와 같은 프로세스가 있는지 확인. `originator`가 `codex-tui` 또는 `codex_cli_rs`일 때만 대상 | 5초 |

확인할 수 없으면(폴더가 없는 구버전, 작업 폴더를 못 읽은 프로세스) 닫혔다고 보지 않고 그대로 보여 준다.

### 2.3 Claude Code가 앱에 남기는 파일 (`~/.ai-run`)

| 경로 | 쓰는 쪽 | 내용 | 읽는 쪽과 용도 |
| --- | --- | --- | --- |
| `~/.ai-run/waiting/<세션 id>` | `scripts/ai-run-hook.sh` (Notification, `permission_prompt` hook) | 승인 요청 시각(epoch 초) | `SessionWatcher`: 승인 대기 판정. 1800초가 지나면 무시하고, 그 시각 뒤에 새 대화 기록이 쌓였으면 처리된 것으로 본다 |
| `~/.ai-run/status/<세션 id>.json` | `scripts/ai-run-statusline.sh` (statusLine) | Claude Code가 statusLine에 넘기는 JSON 전체 | `SessionWatcher`: `context_window.context_window_size`, `model.id`. `UsageWatcher`: `rate_limits.five_hour`, `rate_limits.seven_day` |
| `~/.ai-run/config.json` | 사용자가 직접 작성 | `{"windows": {"<모델 접두어>": <토큰 수>}}` | `SessionWatcher`: 컨텍스트 창 크기를 직접 지정 |
| `~/.ai-run/bin/` | `ClaudeIntegration`이 복사 | 훅과 statusLine 스크립트 | Claude Code 설정이 이 경로의 스크립트를 실행 |

두 스크립트는 `jq`와 `sh`에 의존한다. hook 스크립트는 `transcript_path`의 파일 이름을
세션 id로 써서, 앱이 읽는 기록 파일 이름과 맞춘다.

### 2.4 컨텍스트 창 크기 판정 입력

Claude 기록에는 컨텍스트 창 크기가 없어서 아래 순서로 정한다(`SessionWatcher.resolveClaudeWindow`).

1. `~/.ai-run/status/<id>.json`의 `context_window_size` (저장된 모델 id가 현재 모델과 다르면 무시)
2. `~/.ai-run/config.json`의 `windows` (가장 긴 접두어 일치)
3. 추정: Claude 설정과 모델 이름 규칙
   - 설정 읽는 순서: `~/.claude/settings.json`, `<작업 폴더>/.claude/settings.json`, `settings.local.json` (뒤가 앞을 덮어씀)
   - 읽는 값: `model`, `env.CLAUDE_CODE_DISABLE_1M_CONTEXT`, 같은 이름의 환경 변수
   - 규칙: Fable 전체, Sonnet 5 이상, Haiku 5.5 이상, Opus 4.7 이상은 1M이 기본. 그 외는 200K이고, `model` 설정에 `[1m]`이 있으면 1M
4. 사용 토큰이 추정한 창을 넘으면 1M으로 보정

Codex는 기록의 `model_context_window`를 그대로 쓴다.

### 2.5 사용량 입력

| 대상 | 소스 | 비고 |
| --- | --- | --- |
| Claude | (a) Claude 데스크탑 앱 디스크 캐시 `~/Library/Application Support/Claude/Cache/Cache_Data` 안의 `/api/organizations/<uuid>/usage` 응답 (b) statusLine 상태 파일의 `rate_limits` | 두 값 중 받은 시각이 더 최근인 쪽을 쓴다 |
| Codex | (a) 설치된 `codex app-server`에 JSON-RPC로 `account/rateLimits/read` 요청 (b) 세션 기록 `token_count`의 `rate_limits` | 두 값 중 더 최근인 쪽을 쓴다 |

Claude 데스크탑 캐시 읽기(`ClaudeDesktopUsage.swift`)의 특징:
- Chromium Simple Cache 형식이다. 항목 파일은 머리 24바이트(매직 `0xfcfb6d1ba7725c30`, 버전, 키 길이, 키 해시)와 키, 그 뒤 응답 본문으로 이뤄진다.
- 본문이 zstd 압축이라 매직 `28 B5 2F FD`를 확인하고 `CZstd`(벤더링한 facebook/zstd v1.5.7)로 푼다. 풀린 크기는 최대 1MB.
- 항목 찾기: 크기 500B 이상 64KB 이하인 파일 중 수정 시각이 가장 최근인 600개의 키를 확인한다. 못 찾으면 120초 간격으로만 다시 찾고, 찾기는 백그라운드 큐에서 한다.
- 로그인 정보와 네트워크는 쓰지 않는다. 형식이 바뀌어 못 읽으면 `nil`을 돌려주고 호출하는 쪽이 다른 값을 쓴다.

Codex app-server 조회(`CodexRateLimitReader.swift`)의 특징:
- codex 실행 파일 후보 경로 7곳(`/Applications/Codex.app/...`, `/opt/homebrew/bin/codex`, `~/.local/bin/codex` 등)을 순서대로 찾는다.
- 요청이 있을 때만 `codex app-server`를 켜고, 마지막 요청 뒤 60초가 지나면 끈다. 요청 제한 시간은 15초.
- 실행 파일이 없으면 600초, 조회에 실패하면 120초 동안 다시 시도하지 않는다.
- 사용자가 설정에서 끄면 실행 중인 프로세스도 바로 끈다. 앱 종료 때도 정리한다.
- Codex 한도는 창 길이(분)로 구분한다: 600분 이하는 5시간, 7200분 이상은 주간.

### 2.6 세션 열기 링크 입력

| 대상 | 방법 |
| --- | --- |
| Claude 데스크탑 앱 대화 | `~/Library/Application Support/Claude/claude-code-sessions/**/*.json`의 `cliSessionId`와 `sessionId`를 짝지어, `claude://claude.ai/epitaxy/<sessionId>`로 연다. 10초 간격으로 다시 읽는다 |
| Codex 데스크탑 앱 대화 | 첫 줄의 `originator`가 `Codex Desktop`이면 `codex://threads/<id>` |
| 터미널 세션 | `ps -axo pid=,tty=,etime=,comm=`와 `lsof -d cwd`로 프로세스를 찾고 작업 폴더와 시작 시각(허용 오차 120초)으로 세션과 맞춘다 |

### 2.7 사용자 설정

`UserDefaults.standard`에 즉시 저장한다(`AppSettings.swift`). 기본값은 두 패널 표시, 흰색, 시스템 테마, 보통 유리, 알림 켬, 연동 켬이다.

| 키 | 타입 | 기본값 |
| --- | --- | --- |
| `showsUsagePanel` | Bool | true |
| `showsContextPanel` | Bool | true |
| `colorMode` | `white`, `color` | white |
| `theme` | `light`, `dark`, `system` | system |
| `glassStyle` | `clear`, `slightlyClear`, `regular`, `slightlyTinted`, `tinted` | regular |
| `sendsNotifications` | Bool | true |
| `connectsClaudeCode` | Bool | true |
| `fetchesCodexUsage` | Bool | true |

환경 변수 `AIRUN_SLEEP_AFTER`(초)로 잠드는 시간을 바꿀 수 있다(확인용).

## 3. 상태

### 3.1 세션 상태

| 상태 | 뜻 |
| --- | --- |
| `running` | 마지막 작업이 아직 끝나지 않았고 마지막 활동이 600초 이내 |
| `completed` | 응답이 정상 종료됨 (완료 알림 대상) |
| `idle` | 그 외. 중단, 판단할 기록 없음, 진행 중이었지만 시간이 지나 만료된 경우 |
| 대기 이유 | `approval`(도구 사용이나 계획 승인), `question`(질문에 대한 답). 대기 중이면 `running`으로 세지 않는다 |

승인 대기 판정 우선순위: (1) hook 파일이 있고 유효하면 `approval`, (2) 없으면 기록에서 찾는다.
기록 판정: 마지막 기록이 `assistant`이고 도구 호출에 `AskUserQuestion`이 있으면 `question`, `ExitPlanMode`가 있으면 `approval`,
턴이 정상 종료됐고 그 턴에 비어 있지 않은 `ask`를 가진 `wrap_up` 도구 호출이 있으면 `question`.
사용자가 답하면 새 입력이 쌓여서 자동으로 풀린다. Codex는 기록 기반 대기 판정을 하지 않는다.

완료로 인정하는 조건: 이전 틱에 `running`이었고 이번 틱에 `completed`이며 대기 중이 아닌 세션.
시간이 지나 만료된 세션과 질문을 남기고 끝난 세션은 완료로 보지 않는다.

### 3.2 세션 정보

`SessionInfo`: id, 도구(Claude, Codex), 프로젝트 이름(작업 폴더의 마지막 경로), 제목, 모델 이름,
사용 토큰, 창 토큰, 창 크기가 추정인지, 진행 여부, 대기 이유, 열기 URL, 작업 폴더, 시작 시각, 터미널 세션 여부.
Claude 사용 토큰은 마지막 `assistant` 기록의 `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`,
Codex는 `last_token_usage.input_tokens`다. 목록은 활동 시각 최신순으로 최대 10개.

### 3.3 사용량 상태

`ToolUsage`: 도구, 5시간 한도, 주간 한도(각각 사용 비율 0 이상 1 이하와 초기화 시각), 값을 받은 시각.
초기화 시각이 지난 한도는 사용 비율 0으로 본다. 받은 지 600초가 지난 값은 화면에 "N분 전 기준"(시간, 일 단위로 환산)을 붙인다.

### 3.4 앱 표시 상태 (`AppDelegate`)

- 확인하지 않은 완료 id 집합과 "완료 점" 표시 여부
- 승인 대기 중인 세션이 있는지, 이전 틱의 대기 id 집합(새로 대기에 들어간 세션만 알리기 위해)
- 진행 중 세션 수, 달리기 프레임 번호, 폭죽 프레임(재생 중이 아니면 없음)
- 잠듦 여부와 잠듦 프레임. 마지막 활동(달리기, 대기, 완료)에서 600초가 지나면 잠든다. 시작할 때도 활동이 없으면 그때부터 센다
- 패널의 열림 여부, 마우스가 올라간 세션 id, 방금 끝난 세션 id

패널 정렬 순위: 승인 또는 질문 대기(0), 진행 중(1), 방금 끝난 세션(2), 나머지(3). 같은 순위는 최근 활동순.

## 4. 출력

### 4.1 메뉴바 아이콘 (`SpriteRenderer.swift`, `AppDelegate`)

| 모습 | 조건 |
| --- | --- |
| 서 있음 | 기본 |
| 달리기 | 진행 중인 세션이 1개 이상. 24단계를 24fps로 재생 |
| 폭죽 | 세션이 끝났을 때 캐릭터 뒤에 합성해서 한 번 재생 |
| 잠듦 | 진행, 대기, 폭죽이 없고 600초 동안 활동이 없을 때. 눈을 감고 z가 떠오른다 |
| 완료 점 | 패널을 열기 전에 끝난 세션이 있을 때. 패널을 열면 지운다 |
| 승인 대기 표시 | 대기 중인 세션이 있을 때 |

색상 모드: 흰색이면 캐릭터가 흰색, 컬러이면 Claude Code 주황색(`#DD8B70`)이고 패널 막대에 그라데이션이 들어간다.
표시 상태가 바뀔 때만 이미지를 다시 만든다.

### 4.2 세션 패널 (`SessionPanelView.swift`, `GlassPanel`)

- 메뉴바 아이콘 좌클릭으로 연다. 아이콘 아래, 아이콘 왼쪽 끝에 맞춰 열고 화면 가장자리를 넘지 않게 한다. 두 패널이 모두 꺼져 있으면 열지 않는다.
- 포커스를 빼앗지 않는 투명 `NSPanel`(너비 270). Esc로 닫고, 바깥을 클릭하면 전역 클릭 감시로 닫는다. 열고 닫을 때 0.15초 페이드.
- 사용량 블록: 도구별 이름, 낡은 값 표시, "5시간"과 "주간" 줄(퍼센트, 막대, 초기화까지 남은 시간). 경고 0.8, 위험 0.95.
- 컨텍스트 목록: 줄마다 제목(없으면 프로젝트 이름), 컨텍스트 사용 비율 막대(경고 0.6, 위험 0.85), "승인 필요" 또는 "답변 필요" 표시, 확인하지 않은 완료 점.
  마우스를 올린 줄만 모델 이름과 "사용 토큰 / 창 토큰"을 펼치고, 창 크기가 추정이면 표시를 붙인다.
- 줄을 누르면 패널을 닫고 해당 세션을 연다.
- 패널이 열려 있는 동안 2초마다 갱신하고 줄 수가 바뀌면 창 크기를 맞춘다.
- 테마(라이트, 다크, 시스템)는 패널의 외관으로 적용하고, Liquid Glass 5단계가 유리 투명도를 정한다.

### 4.3 우클릭 설정 메뉴

로그인 시 자동 실행(앱으로 실행 중일 때만 활성), 알림 보내기, Codex 연동, Claude 연동(Claude Code가 설치된 경우에만 표시),
표시할 패널(사용량, 컨텍스트), 색상(흰색, 컬러), 테마, Liquid Glass 단계, "Desktoto 종료".

### 4.4 알림과 소리 (`NotificationSender.swift`)

| 사건 | 소리 | 배너 문구 |
| --- | --- | --- |
| 세션 완료 | `Glass` (여러 세션이 동시에 끝나도 한 번) | "작업이 끝났어요" |
| 새로 대기 시작 | `Ping` | "승인이 필요해요" 또는 "답변이 필요해요" |

- 배너 제목은 세션 제목, 없으면 프로젝트 이름, 없으면 `AI`이고 40자를 넘으면 잘라서 `…`를 붙인다.
- `.app` 번들로 실행 중이면 `UserNotifications`로 보내고, 번들이 아닌 개발 실행(`swift run`)이면 AppleScript `display notification`으로 대신한다.
- 배너를 누르면 그 세션을 연다(세션 id를 `userInfo`에 담는다). 앱이 앞에 있어도 배너를 보여 준다.
- 설정에서 알림을 꺼도 소리와 아이콘 표시는 그대로다.

### 4.5 세션 열기 (`TerminalJumper.swift`)

- 데스크탑 앱 세션: 딥링크를 `NSWorkspace`로 연다.
- 터미널 세션: iTerm2와 Terminal.app은 AppleScript로 tty가 같은 탭을 선택한다(실행 중인 앱에만 요청). Orca는 조상 프로세스에서 Orca 앱을 찾아 `orca terminal list`, `orca terminal switch` CLI로 탭을 고른다.
- 찾지 못하면 아무것도 하지 않는다.

### 4.6 외부 파일에 쓰는 출력

- `~/.claude/settings.json`에 Notification(`permission_prompt`) hook과 `statusLine`을 넣고 뺀다(`ClaudeIntegration.swift`).
  - 이미 쓰는 statusLine이 command 형식이면 지우지 않고 우리 스크립트의 인자로 감싸서 원래 명령도 실행되게 한다. 다른 형식은 건드리지 않는다.
  - 수정 전에 `<파일 이름>.ai-run-backup-<시각>` 백업을 만들고, 읽을 수 없는 파일은 건드리지 않는다.
  - 해제하면 우리가 넣은 것만 걷어내고 `connectsClaudeCode`를 false로 해서 다시 넣지 않는다.
  - 시작할 때 `connectsClaudeCode`가 켜져 있고 Claude Code가 설치돼 있고 번들 리소스에 hook 스크립트가 있으면 백그라운드에서 한 번 연결한다.
- 스크립트를 `~/.ai-run/bin`에 복사한다.
- 로그인 항목: `SMAppService.mainApp`을 등록, 해제하고, 승인이 필요한 상태면 시스템 설정의 로그인 항목 화면을 연다. 앱으로 실행 중일 때만 가능하다.

## 5. 주기 정리

| 주기 | 하는 일 |
| --- | --- |
| 1초 | 폴링 틱: 세션 상태 판정, 완료와 대기 감지, 알림, 아이콘 상태 갱신 |
| 2초 | 패널이 열려 있는 동안 목록과 사용량 갱신 |
| 24fps | 달리기와 폭죽 애니메이션(진행 중일 때만 타이머 가동) |
| 잠든 동안 느린 타이머 | z 애니메이션 |
| 30초 | 패널이 닫혀 있을 때 사용량 미리 읽기. 패널이 열려 있을 때 Codex 현재 값 조회 |
| 300초 | 패널이 닫혀 있을 때 Codex 현재 값 조회 |
| 10초 | 데스크탑 앱 세션 id 매핑 다시 읽기 |
| 120초 | Claude 데스크탑 캐시 항목 다시 찾기 |

## 6. 외부 의존

| 종류 | 항목 |
| --- | --- |
| Apple 프레임워크 | Foundation, AppKit, SwiftUI(Liquid Glass 포함, 최소 macOS 26), UserNotifications, ServiceManagement |
| 벤더링 C 라이브러리 | `Sources/CZstd` (facebook/zstd v1.5.7의 해독 부분, `ZSTD_DISABLE_ASM`, `DEBUGLEVEL=0`) |
| 시스템 프로그램 | `/bin/ps`, `/usr/sbin/lsof`, `sh`, `jq`(스크립트) |
| 다른 앱의 비공개 형식 | Claude Code 기록과 설정, Claude 데스크탑 앱의 Chromium 캐시와 세션 메타데이터, Codex 기록과 `codex app-server` JSON-RPC, Orca CLI |
| 자동화 권한 | iTerm2, Terminal.app에 대한 AppleScript (`Info.plist`의 설명 문구 있음) |
| 딥링크 스킴 | `claude://`, `codex://` |

다른 앱의 비공개 형식에 기대는 부분은 형식이 바뀌면 읽지 못한다. 원본은 읽지 못하면 `nil`이나 빈 값을 돌려주고
호출하는 쪽이 대체 값을 쓰거나 해당 표시를 생략하는 방식으로 대응한다.

## 7. 원본 파일별 책임

| 파일 | 줄 수 | 책임 |
| --- | --- | --- |
| `AppDelegate.swift` | 548 | 앱 조립, 상태 막대 아이콘, 패널 열고 닫기, 우클릭 메뉴, 폴링 틱, 완료와 대기 처리, 애니메이션 타이머 |
| `SessionWatcher.swift` | 736 | 기록 탐색, 진행 상태와 대기 판정, 세션 정보 추출, 컨텍스트 창 판정, 터미널 생존 확인, 딥링크 매핑 |
| `SessionPanelView.swift` | 499 | 패널 모델, 패널 SwiftUI 화면, 막대와 유리 스타일, 그라데이션 |
| `SpriteRenderer.swift` | 341 | 캐릭터, 폭죽, 잠든 모습의 프레임 이미지 생성 |
| `CodexRateLimitReader.swift` | 286 | `codex app-server` 프로세스 수명과 JSON-RPC 조회 |
| `ClaudeIntegration.swift` | 251 | Claude Code 설정의 hook과 statusLine 연결, 해제, 백업 |
| `TerminalJumper.swift` | 248 | 터미널 프로세스 찾기, iTerm2, Terminal, Orca 탭 이동 |
| `UsageWatcher.swift` | 217 | 두 소스 중 최신 사용량 선택, 초기화 시각 보정 |
| `ClaudeDesktopUsage.swift` | 211 | Chromium 캐시에서 사용량 응답 찾기와 zstd 해독 |
| `AppSettings.swift` | 104 | 설정 저장과 기본값 |
| `NotificationSender.swift` | 90 | 알림, 로그인 항목 |
| `LogTail.swift` | 25 | 기록 파일 꼬리 읽기 |
| `main.swift` | 7 | 앱 시작 |
| `scripts/ai-run-hook.sh`, `scripts/ai-run-statusline.sh` | | 승인 대기와 세션 상태를 `~/.ai-run`에 기록 |
| `scripts/build-app.sh`, `scripts/Info.plist` | | `.app` 번들 생성, 서명(ad hoc), 설치, 실행 |
| `landing/` | | 랜딩 페이지(`index.html`, `serve.py`, OG 이미지) |

## 8. 구조 설계에 영향을 주는 관찰

설계 결정은 이슈 #2의 다음 단계에서 하며, 여기서는 사실만 적는다.

1. `~/.ai-run` 경로는 `SessionWatcher.swift`(waiting, status, config.json), `UsageWatcher.swift`(status), `ClaudeIntegration.swift`(bin, 표지 문자열 `.ai-run/status`), 두 스크립트에 문자열로 박혀 있다.
   사용자의 `~/.claude/settings.json`에 이미 기록된 hook과 statusLine 명령도 이 경로를 가리키고, 이름 판정에 `ai-run-hook.sh`, `ai-run-statusline.sh` 문자열을 쓴다.
2. 번들 식별자는 `com.huniverse.airun`, 실행 파일 이름은 `AiRun`, 표시 이름은 `Desktoto`다. 로그인 항목과 알림 권한이 번들 식별자에 묶여 있다.
3. 파일 시스템, 프로세스, 시간을 직접 쓰는 곳이 많다(`FileManager`, `Date()`, `Timer`, `Process`, `NSAppleScript`).
   일부는 이미 주입할 수 있다. `UsageWatcher`는 두 reader를 init으로 받고, `ClaudeDesktopUsageReader`는 캐시 폴더를, `ClaudeIntegration`은 설정 파일과 `bin` 폴더를 인자로 받으며,
   `TerminalJumper`의 Orca 파싱과 `ClaudeIntegration`의 설정 JSON 변환은 입출력 없이 도는 순수 함수다. `AppSettings`는 `UserDefaults`를 주입받는다.
   반대로 `SessionWatcher`는 홈 폴더, 시각, 프로세스 확인을 내부에서 직접 얻는다.
4. 앱 번들로 실행 중인지(`isRunningAsApp`) 여부가 알림과 로그인 항목의 동작을 가른다. 개발 실행에서는 `UserNotifications`와 `SMAppService`를 쓰지 않는다.
5. 원본에는 이름 기반 상수가 파일마다 흩어져 있다(예: 600초 창과 사용량 한도 분 기준이 `SessionWatcher`, `UsageWatcher`, `CodexRateLimitReader`에 중복).

## 9. 이 문서가 다루지 않은 범위

이번 조사는 `AppDelegate`, `SessionWatcher`, `AppSettings`, `UsageWatcher`, `LogTail`, 두 스크립트, `NotificationSender`를 끝까지 읽었고,
`ClaudeDesktopUsage`, `CodexRateLimitReader`, `TerminalJumper`, `ClaudeIntegration`, `SessionPanelView`는 앞부분과 핵심 함수만 읽었다.
`SpriteRenderer`는 상수와 선언만 확인했다. 아래는 해당 기능 이슈에서 원본 코드를 다시 읽고 보완한다.

- 캐릭터 프레임의 구체적인 그리기 규칙과 폭죽, 잠듦 프레임 수 (이슈 #9)
- 패널 레이아웃, 그라데이션, 유리 스타일별 색 값 (이슈 #10)
- Chromium 캐시의 응답 JSON 필드 파싱과 Codex JSON-RPC의 요청, 응답 세부 (이슈 #6)
- statusLine 감싸기와 백업 파일 이름 규칙의 경계 사례 (이슈 #7)
- Orca 탭 선택 규칙의 세부 (이슈 #5)
