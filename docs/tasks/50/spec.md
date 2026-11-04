# 작업 명세: [Hotfix] Claude 계정을 여러 개 쓸 때 사용량이 하나만 표시되는 문제 수정

## 연결 정보

- 이슈: #50 / https://github.com/huniversal/Desktoto/issues/50
- 브랜치: hotfix/claude-multi-account/#50
- specRevision: 2
- 대상 ai-run 원본: `~/Desktop/ai-run/Sources/AiRun/UsageWatcher.swift` (읽기 전용). 원본도 Claude 사용량을 후보 중 `updatedAt`이 가장 최근인 하나로 고르므로(`getClaudeUsage`) 같은 한계를 가진다. 원본의 한계로 보이는 동작이라 따라 하지 않고 이 명세에서 고치는 방향을 정한다.

## 목적

Orca 등으로 Claude 계정을 두 개 이상 쓰는 유저가 패널에서 사용량을 하나만 본다(노션 "배포 후 버그 리스트" 3번).
Claude 사용량은 툴당 하나의 값만 만들고 카드도 툴당 하나라서, 계정이 둘이어도 마지막에 갱신된 한쪽 값만 보인다.
계정이 여러 개이면 계정마다 사용량을 보여 주고, 계정이 하나인 유저의 화면은 지금과 같게 유지한다.

## 작업 범위

### 포함

- 상태 파일(`~/.ai-run/status/<세션 id>.json`)이 어느 설정 폴더(계정)의 값인지 구분할 수 있게 하는 방법 확정과 구현
- 이미 연결된 유저도 앱 업데이트 후 새 상태 스크립트로 교체되게 하기(`ClaudeIntegration.connect`가 `alreadyConnected`에서 끝나 스크립트를 다시 쓰지 않는 문제)
- Claude 사용량을 설정 폴더 단위로 묶어 계정별 `ToolUsage`로 만들고, 패널에서 계정별로 보여 주기. 대상은 statusLine이 설정되어 상태 파일을 쓰는 설정 폴더의 계정이다(Orca는 `~/.claude` 설정을 계정 폴더로 병합하므로 해당될 가능성이 높다).
- 계정이 하나일 때 현재 화면 유지
- 합성 데이터와 가짜 FileSystem을 쓴 테스트 추가

### 제외

- Codex 계정 여러 개 지원. Orca의 managed Codex 계정은 `~/.codex`가 아닌 격리된 홈을 쓰므로 별도 이슈로 다룬다.
- Claude 데스크탑 앱 캐시(`desktop(now:)`)의 계정 구분. 데스크탑 앱은 계정이 하나라고 본다.
- 계정 이메일 표시. 상태 파일에 이메일이 없고 `.claude.json`은 내부 형식이라 읽지 않는다.
- Orca 앱 자체 연동이나 Orca 전용 로직. 설정 폴더가 다르면 모두 같은 규칙으로 다룬다.
- 직접 만든 `CLAUDE_CONFIG_DIR`(예: `~/.claude-work`)에 statusLine을 새로 설치하는 연동. 지금 연동은 `~/.claude/settings.json`만 고치며, 다른 폴더의 settings는 건드리지 않는다. 별도 이슈로 다룬다.

## 설계 결정

공식 문서(Claude Code Authentication, Customize your status line, Hooks)로 확인한 사실과 아직 확인하지 못한 가설을 구분해 적는다.

- 확인된 사실: 계정의 단위는 설정 폴더(`CLAUDE_CONFIG_DIR`, 기본 `~/.claude`)다. 폴더마다 설정, 세션 기록, 로그인이 분리된다. statusLine JSON에는 계정, 이메일 필드가 없고 `session_id`와 `transcript_path`는 있다. 훅 프로세스는 부모 환경을 상속한다.
- 가설(구현 전 실측 필요): statusLine 명령도 `CLAUDE_CONFIG_DIR`를 상속받는다. Orca가 계정 폴더로 실행했을 때 `transcript_path`의 앞부분이 계정마다 달라진다.
- 파일 구조와 로직의 책임: 계정 구분 정보를 기록하는 책임은 `apps/macos/Resources/ai-run-statusline.sh`가, 이미 설치된 스크립트를 새 버전으로 교체하는 책임은 `apps/macos/Sources/ClaudeIntegration/ClaudeIntegration.swift`가, 읽어서 계정별로 묶는 책임은 `apps/macos/Sources/UsageMonitoring/UsageMonitor.swift`와 `UsageParser.swift`가, 표시는 `apps/macos/Sources/SessionPanel/UsageCardView.swift`가 맡는다. 값 타입(`ToolUsage`)에 계정 식별자를 어떻게 담을지는 미결정이다.
- 상태와 데이터 흐름: 상태 파일 후보를 계정 키로 묶고, 계정마다 가장 최근 파일 하나를 고른다. 현재의 "툴당 최신 하나" 선택을 "계정당 최신 하나"로 바꾸는 방향이다.
- 선택한 방식과 이유: 계정 키는 스크립트가 상속받은 `CLAUDE_CONFIG_DIR`(없으면 `~/.claude`)를 상태 파일에 함께 기록하는 방식을 우선 검토한다. `transcript_path`로 설정 폴더를 추정하는 방식은 Orca처럼 히스토리를 링크하는 환경에서 경로가 불확실해 보조 수단으로만 둔다. 최종 선택은 실측 결과로 정한다.
- 예외 처리: 계정 키가 없는 기존 상태 파일(이전 버전 스크립트가 쓴 것)은 기본 계정으로 취급해 지금처럼 동작한다. 계정이 하나면 카드는 하나이고 계정 이름을 표시하지 않는다. 오래된 계정의 값은 기존 `createStaleText`로 "N분 전 기준"을 계정별로 표시한다.

## 완료 조건

- AC-1: 설정 폴더가 다른 두 세션의 상태 파일이 있으면 Claude 사용량이 계정마다 하나씩 나온다.
- AC-2: 상태 파일이 하나의 설정 폴더에서만 나오면 패널의 Claude 카드는 지금과 같은 모양이다(계정 이름 없음).
- AC-3: 계정 키가 없는 기존 상태 파일도 기본 계정으로 읽혀 사용량이 정상 표시된다.
- AC-4: 계정마다 "마지막 갱신" 기준 문구가 따로 표시된다.
- AC-5: 계정을 구분하는 방식(환경변수 상속 여부, `transcript_path` 변화)이 실제 실행으로 확인되어 결과가 이 명세에 기록된다.
- AC-8: 이미 연결된 상태에서 번들 스크립트의 내용이 설치된 스크립트와 다르면 연결 동작이 설치된 스크립트를 새 내용으로 교체하고, 같으면 다시 쓰지 않는다. 사용자의 `settings.json`은 이 과정에서 바뀌지 않는다.
- AC-6: 계정 구분과 선택 로직이 합성 데이터와 가짜 FileSystem으로 단위 테스트된다. 사용자의 실제 상태 파일을 테스트 입력으로 커밋하지 않는다.
- AC-7: `swift build`와 `swift test`가 통과한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | 서로 다른 설정 폴더 값을 가진 상태 파일 두 개로 `UsageMonitor.getUsages` 단위 테스트 | Claude 사용량이 2개 반환 |
| AC-2 | 같은 설정 폴더 상태 파일들로 단위 테스트와 패널 실제 확인 | 사용량 1개, 카드에 계정 이름 없음 |
| AC-3 | 계정 키 필드가 없는 상태 파일로 단위 테스트 | 기본 계정 하나로 정상 파싱 |
| AC-4 | 갱신 시각이 다른 두 계정으로 단위 테스트 | 계정별 갱신 시각이 유지됨 |
| AC-5 | 임시 `CLAUDE_CONFIG_DIR`로 `claude`를 띄워 세션을 만들고 `~/.ai-run/status/`의 새 파일에서 설정 폴더 정보와 `transcript_path`를 확인한다. 로그인은 사용자가 직접 한다. | 환경변수 전달 여부와 경로 변화를 기록 |
| AC-6 | `swift test`에서 신규 테스트 확인 | 신규 테스트 통과 |
| AC-7 | `cd apps/macos && swift build && swift test` | 통과 |
| AC-8 | 가짜 SettingsFileSystem으로 연결된 설정과 옛 스크립트를 두고 `connect()` 단위 테스트 | 스크립트만 교체되고 settings는 그대로, 같은 내용이면 쓰기 없음 |

실제 Orca 환경 검증은 계정 두 개가 필요하다. 검증하지 못하면 PR에 미검증으로 기록하고 통과로 표시하지 않는다.

## 미결정 사항

- 계정 구분 방식 최종 선택(환경변수 기록 대 `transcript_path` 추정). AC-5의 실측 결과에 달려 있어 구현을 막는다.
- 계정별 카드의 이름 표기(설정 폴더 이름을 별칭으로 쓸지 등). 개인정보 노출을 피해야 한다. UI 구현을 막는다.
- 계정이 둘 이상이고 한쪽이 오래된 경우의 표시 방식(숨김 또는 흐리게 표시). 구현을 막지는 않는다.
- 카드 이름은 우선 설정 폴더 이름(예: `.claude-work`, Orca의 `<account>`)을 쓰는 안으로 구현하고, 사용자가 바꾸자고 하면 재논의한다.
- Hotfix 타입은 컨벤션 문서와 라벨에 없다. 이슈는 `[Hotfix]` 제목과 `FIX` 라벨을 썼고, 브랜치는 `hotfix/` 접두어를 썼다. 컨벤션에 반영할지는 별도로 정한다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 이슈 #50의 Tasks와 공식 문서 조사 결과. 미결정 항목은 확정하지 않음 |
| 2 | 스크립트 교체 로직을 포함 범위로 올림(AC-8 추가), 대상을 statusLine이 설정된 폴더의 계정으로 한정, 직접 만든 폴더 연동은 제외 | `connect()`가 이미 연결된 설정에서 스크립트를 다시 쓰지 않아 기존 유저에게 반영되지 않음. 연동이 `~/.claude/settings.json`에만 설치됨 |
