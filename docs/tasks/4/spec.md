# 작업 명세: [Feat] 세션 모델 및 로그 감시 코어 구현

## 연결 정보

- 이슈: #4 / https://github.com/huniversal/Desktoto/issues/4
- 브랜치: `feat/session-log-watcher/#4`
- specRevision: 2
- 대상 ai-run 원본:
  - `~/Desktop/ai-run/Sources/AiRun/SessionWatcher.swift` (736줄, 기록 판정 책임만)
  - `~/Desktop/ai-run/Sources/AiRun/LogTail.swift` (25줄)
- 동작 문서화 위치: `docs/reverse/overview.md` 2.1, 2.3, 2.4, 3.1, 3.2장 (이 이슈에서 보완 사항이 생기면 같은 문서에 추가)
- 선행 이슈: #2 (develop에 머지 완료)

## 목적

원본 `SessionWatcher`가 한 클래스에서 맡던 "기록 파일을 읽어 세션의 진행, 완료, 대기를 판정하고 모델과 컨텍스트 사용량을 읽는 일"을
`Domain`, `Boundaries`, `SessionMonitoring` 모듈로 나누어 처음부터 다시 구현한다.
제품 동작(어떤 기록이 어떤 상태가 되는가)은 원본과 같게 두고, 파일 시스템과 현재 시각을 외부 경계로 주입해 합성 데이터로 테스트할 수 있게 한다.

원본이 기록 파일의 수정 시각이 아니라 기록 안의 시각으로 활동을 판단하는 이유는 다음과 같다.
세션을 다시 열거나 백그라운드 명령이 끝나면 앱이 줄을 덧붙여서, 몇 시간 전에 끝난 세션의 수정 시각이 방금으로 바뀐다.
이 근거를 `docs/reverse/overview.md`와 코드 주석에 남긴다.

## 작업 범위

### 포함

이슈 #4의 Tasks 7개를 그대로 포함한다.

1. 도메인 모델: `AiTool`, `SessionInfo`, `SessionRunState`, `WaitingKind` (`Domain`)
2. 기록 파일 끝부분 읽기 `LogTail`: 잘린 줄과 멀티바이트 문자 처리 (`Boundaries`)
3. Claude Code(`~/.claude/projects`)와 Codex(`~/.codex/sessions`) 기록 파일 탐색 (`SessionMonitoring`)
4. 진행, 완료, 대기 판정: 기록 안의 실제 활동 시각 기준, 승인 대기와 질문 대기 구분
5. 세션별 모델과 컨텍스트 사용량(사용 토큰) 읽기
6. hook이 남긴 승인 대기 신호(`~/.ai-run/waiting/<세션 id>`) 읽기와 만료 처리
7. 합성 기록 데이터로 단위 테스트 작성 (`SessionMonitoringTests`, `BoundariesTests`)

이슈 Tasks에는 없지만 `architecture.md` 3장이 `SessionMonitoring`에 배정해 사용자와 합의하고 추가한 항목이다(D-A, D-B).

8. Claude 컨텍스트 창 크기 판정: statusLine 파일, `~/.ai-run/config.json`, `settings.json` 3종, 모델 이름 규칙, 1M 보정 (`SessionInfo.windowTokens`, `isWindowEstimated`)
9. Codex 열기 URL 값 만들기: 첫 줄 `session_meta`의 `originator`가 `Codex Desktop`이면 `codex://threads/<id>`

이를 위해 필요한 최소한의 외부 경계도 함께 만든다.

- `Boundaries`: `FileSystem`(기록 파일 탐색, 끝부분 읽기, 전체 읽기, 수정 시각과 생성 시각 조회, 홈 폴더), `TimeSource`, 실제(Live) 구현
- `TestSupport`: `InMemoryFileSystem`, `FixedTimeSource`

### 제외

- 터미널 세션 생존 확인(`~/.claude/sessions/<pid>.json`, `ps`와 `lsof`로 Codex 프로세스 찾기): #5. 원본의 `isClosedTerminalSession` 계열은 구현하지 않는다.
  #5가 `Domain`에 질문 프로토콜을 정의하면 `SessionMonitoring`이 주입받는다(`architecture.md` 3장 "기능 사이의 연결").
- 세션 열기 동작(터미널 탭 이동)과 Claude 데스크탑 앱 열기 링크 매핑(`claude-code-sessions/**/*.json`의 `cliSessionId`와 `sessionId` 짝짓기, 10초 재읽기): #5.
  이 이슈에서 Claude 세션의 `openURL`은 nil이다. Codex 열기 URL 값 만들기만 포함한다.
- 사용량(5시간, 주간 한도) 읽기: #6
- 완료 알림 판정(이전 틱 `running`, 이번 틱 `completed`), 1초 폴링 타이머, 알림 발송: #11, #8
- 세션 패널 UI, 메뉴바 아이콘: #9, #10
- hook과 statusLine 스크립트 설치: #7. 이 이슈는 스크립트가 남긴 파일을 읽기만 한다.
- 실제 `~/.claude`, `~/.codex`, `~/.ai-run` 읽기와 쓰기 (테스트는 합성 데이터만 쓴다)

## 설계 결정

아래 파일 구조와 타입 이름은 구현 중 필요하면 조정하되, 조정하면 specRevision을 올린다.

### 파일 구조와 로직의 책임

```
apps/macos/Sources/
├── Domain/
│   ├── AiTool.swift            enum AiTool
│   ├── SessionRunState.swift   enum SessionRunState, enum WaitingKind
│   └── SessionInfo.swift       struct SessionInfo
├── Boundaries/
│   ├── FileSystem.swift        protocol FileSystem, FileEntry, FileTail
│   ├── LiveFileSystem.swift    FileManager 기반 실제 구현
│   ├── TimeSource.swift        protocol TimeSource, SystemTimeSource
│   ├── JSONValue.swift         Sendable JSON 값 (기록 한 줄의 해석 결과)
│   └── LogTail.swift           끝부분 읽기(경계 호출)와 줄 해석(순수 함수), LogTailResult
├── SessionMonitoring/
│   ├── SessionMonitoringPolicy.swift  원본의 상수 모음
│   ├── LogFile.swift                  LogFile, LogOutcome, ActivitySnapshot
│   ├── RecordTimestamp.swift          기록의 ISO 8601 시각 해석
│   ├── LogRecordReader.swift          끝부분을 단계적으로 넓혀 읽기
│   ├── ActivityJudge.swift            Claude, Codex 기록에서 활동 시각과 결과 판정(순수)
│   ├── RunStateJudge.swift            결과와 활동 시각에서 SessionRunState 판정(순수)
│   ├── WaitingJudge.swift             기록에서 질문, 계획 승인 대기 판정(순수)
│   ├── WaitingSignalReader.swift      ~/.ai-run/waiting 읽기, 만료와 처리 완료 판정
│   ├── CodexOrigin.swift              Codex 첫 줄(session_meta) 해석과 열기 URL
│   ├── SessionInfoReader.swift        모델, 토큰, 제목, 작업 폴더 읽기
│   ├── ContextWindowResolver.swift    Claude 컨텍스트 창 크기 판정
│   └── SessionMonitor.swift           기록 탐색과 캐시를 소유하고 위 조각을 조립하는 진입점 (actor)
└── TestSupport/
    ├── InMemoryFileSystem.swift
    └── FixedTimeSource.swift
```

- 판정과 해석은 입출력 없는 순수 함수로 둔다. `architecture.md` 5장 "작성 규칙"의 "끝 N바이트 읽기(경계)"와 "바이트에서 JSON 줄 해석(순수 함수)" 분리를 따른다.
- `LogTail`은 두 기능(`SessionMonitoring`, `UsageMonitoring`의 Codex 기록 사용량)이 쓰므로 `architecture.md` 4장에 따라 `Boundaries`에 둔다.
- 원본의 상수는 이름 있는 `static let`으로 한곳에 모은다. 원본에서 600초가 `ACTIVE_WINDOW`(대상 선정 창)와 `CLAUDE_PENDING_WINDOW`(진행 중 유지 창)로 나뉘어 있고 값이 같다. 의미가 달라서 두 상수를 유지한다(D-C).

### 상태와 데이터 흐름

- 기록 한 줄은 `JSONValue`(Sendable)로 해석한다. 원본의 `[String: Any]`는 Swift 6 모드에서 actor 경계를 넘길 수 없다.
- `SessionMonitor`가 캐시(활동 판정은 파일 경로와 수정 시각, 질문 대기 판정은 세션 id와 수정 시각, Codex 첫 줄 정보는 경로)를 소유한다. 수정 시각이 같으면 이전 판정을 재사용해서 1초 폴링에도 바뀐 파일만 다시 읽는다(원본 동작).
  `SessionMonitor`는 `actor`로 시작한다. #11 조립에서 호출 방식이 굳어지면 조정한다(D-D). 캐시는 현재 대상 파일에 없는 항목을 정리한다(D-F).
- 흐름: `SessionLogFinder`가 파일 목록과 수정 시각을 얻고 600초 안의 파일만 남김 → `ActivityJudge`가 끝부분 64KB, 512KB, 4MB 순으로 읽어 활동 시각과 결과를 판정 → 기록 안의 활동 시각도 600초 안인 파일만 남김 → `RunStateJudge`와 `WaitingSignalReader`와 `WaitingJudge`로 상태 결정 → 상세는 `SessionInfoReader`가 512KB, 4MB, 16MB 순으로 읽어 채움.
- 현재 시각은 항상 `TimeSource`에서 한 번 읽어 한 번의 판정 전체에 같은 값을 쓴다(원본은 호출마다 `Date()`를 새로 읽는다).

### 선택한 방식과 이유

- 원본 동작을 유지하는 것이 우선이다. 판정 규칙은 `docs/reverse/overview.md` 3.1장의 표를 그대로 테스트로 옮긴다.
- 원본과 다르게 하는 것은 구조뿐이다: 클래스 한 개를 책임별 타입으로 분리, 외부 경계 주입, `[String: Any]`를 `JSONValue`로 교체, 캐시 소유 위치 명시.
- `FileSystem`은 `FileManager`를 흉내 내지 않고 이 이슈가 쓰는 동작만 굵게 정의한다(`architecture.md` 5장). 다른 기능이 필요로 하는 동작은 그 이슈에서 추가한다.

### 예외 처리

- 읽지 못하는 파일, 없는 폴더, 깨진 JSON 줄, 잘린 줄은 값 없음으로 처리하고 해당 줄이나 파일만 건너뛴다(원본의 대응 방식 유지, `architecture.md` 5장).
- 기록에서 판단할 줄을 4MB까지 읽고도 못 찾으면 결과는 `stopped`, 활동 시각은 파일 수정 시각으로 둔다(원본 동작).
- 기록 안의 시각이 없거나 해석하지 못하면 파일 수정 시각을 대신 쓴다(원본 동작).
- 승인 대기 신호 파일의 내용이 숫자(초)가 아니면 파일 수정 시각을 쓴다(원본 동작).

### 원본과 같게 유지하는 판정 규칙 (테스트의 기준)

| 항목 | 규칙 |
| --- | --- |
| 대상 파일 | `.jsonl`, 숨김 파일 제외, 수정 시각과 기록 안 마지막 활동 시각이 모두 600초 미만 |
| Claude 활동 기록 종류 | `user`, `assistant`, `api-request`, `attachment`, `system`, `queue-operation` (제목, 마지막 프롬프트 같은 부가 기록은 제외) |
| Claude 결과 | 마지막 `user` 또는 `assistant` 기록이 `assistant`이고 `stop_reason`이 `end_turn` 또는 `stop_sequence`이면 완료, 아니면 진행 중 |
| Codex 결과 | 가장 최근 생명주기(`task_started`, `task_complete`, `turn_aborted`)가 `task_complete`이면 완료, `turn_aborted`이면 중단, `task_started`이면 진행 중. 활동 시각은 완료와 중단이면 그 기록의 시각, 진행 중이면 가장 최근 기록의 시각 |
| 상태 | 완료면 `completed`, 중단이면 `idle`, 진행 중이면 활동 시각이 600초 이내일 때 `running`, 아니면 `idle` |
| 승인 대기 우선순위 | hook 파일이 유효하면 `approval`, 아니면 기록 판정 |
| hook 유효 조건 | 신호 시각이 1800초 미만, 그리고 신호 시각보다 새로운 대화 기록이 없음 |
| 기록 판정 | 마지막 대화 기록이 `assistant`: 도구 호출에 `AskUserQuestion`이면 `question`, `ExitPlanMode`이면 `approval`, 턴이 정상 종료됐고 그 턴에 비어 있지 않은 `ask`를 가진 `wrap_up` 도구 호출이 있으면 `question`. Codex는 기록 판정을 하지 않는다 |
| 대기 중 진행 여부 | 대기 이유가 있으면 `isRunning`은 false |
| 토큰 | Claude는 마지막 `usage`가 있는 `assistant` 기록의 `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, Codex는 `last_token_usage.input_tokens` |
| 정렬과 개수 | 활동 시각 최신순, 최대 10개 |

## 완료 조건

- AC-1: `AiTool`, `SessionInfo`, `SessionRunState`, `WaitingKind`가 `Domain` 모듈에 있고 `Sendable`이다. `Domain`은 다른 모듈에 의존하지 않는다.
- AC-2: `LogTail`이 파일 끝 N바이트에서 유효한 JSON 객체 줄을 최신순으로 돌려준다. 읽기 시작 위치가 줄이나 멀티바이트 문자 중간이면 첫 줄을 버리고, 깨진 줄과 객체가 아닌 줄은 건너뛴다.
- AC-3: 기록 탐색이 `~/.claude/projects`와 `~/.codex/sessions` 아래의 `.jsonl` 파일을 찾고, 수정 시각과 기록 안 활동 시각이 모두 600초 이내인 파일만 대상으로 삼는다. 파일 수정 시각이 최근이어도 기록 안 활동이 오래됐으면 제외한다.
- AC-4: Claude와 Codex 기록 각각에서 위 표대로 `running`, `completed`, `idle`이 판정된다.
- AC-5: hook 신호가 유효하면 `approval`, 1800초가 지났거나 그 뒤에 새 대화 기록이 있으면 무시된다. 기록 기반으로 `AskUserQuestion`과 `wrap_up`의 `ask`는 `question`, `ExitPlanMode`는 `approval`로 구분된다. 대기 중인 세션의 `isRunning`은 false다.
- AC-6: 세션별 모델 이름과 사용 토큰(Claude, Codex 각각의 계산식), 프로젝트 이름, 제목, 작업 폴더를 읽는다. 읽을 수 없으면 해당 값은 nil이다.
- AC-7: 활동 판정은 수정 시각이 같으면 파일을 다시 읽지 않는다.
- AC-8: 파일 시스템과 현재 시각을 주입받아, 테스트가 실제 `~/.claude`, `~/.codex`, `~/.ai-run`에 접근하지 않는다.
- AC-9: Claude 컨텍스트 창 크기가 원본 순서대로 정해진다: statusLine 파일(저장된 모델이 다르면 무시), `config.json`(가장 긴 접두어), 설정 파일과 모델 이름 규칙 추정, 사용 토큰이 추정 창을 넘으면 1M 보정. 추정이면 `isWindowEstimated`가 true다. Codex는 기록의 `model_context_window`를 쓴다.
- AC-10: Codex 세션은 첫 줄 `originator`가 `Codex Desktop`일 때만 `codex://threads/<id>`를 `openURL`로 갖고, 터미널 세션 여부는 `originator`가 `codex-tui` 또는 `codex_cli_rs`인지로 정한다. Claude는 기록의 `entrypoint`가 `cli`이면 터미널 세션이고 `openURL`은 nil이다.
- AC-11: `swift build`와 `swift test`가 통과하고, 위 AC를 확인하는 단위 테스트가 합성 데이터로 존재한다. `architecture.md`의 의존 규칙(`SessionMonitoring`은 `Domain`, `Boundaries`만 import)이 `Package.swift`로 유지된다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
| --- | --- | --- |
| AC-1 | `cd apps/macos && swift build` | 빌드 성공. Swift 6 모드에서 `Sendable` 경고와 오류가 없음 |
| AC-2 | `BoundariesTests`: 합성 바이트로 줄 중간 시작, 한글 3바이트 중간 시작, 마지막 줄 개행 없음, 빈 파일, 없는 파일, 깨진 JSON 줄, 배열 줄 | 모든 케이스에서 기대한 기록 목록, 크래시 없음 |
| AC-3 | `SessionMonitoringTests`: `InMemoryFileSystem`에 두 루트의 파일, 숨김 파일, `.txt`, 599초와 600초 경계, 수정 시각은 최근이고 기록 시각은 오래된 파일 구성 | 대상 파일 집합이 기대와 일치 |
| AC-4 | `SessionMonitoringTests`: Claude(`end_turn`, `stop_sequence`, `tool_use`, 마지막이 `user`, 부가 기록만 새로움), Codex(`task_complete`, `turn_aborted`, `task_started` 뒤 다른 기록, 생명주기 없음) | 표대로 상태 판정 |
| AC-5 | `SessionMonitoringTests`: 신호 파일(유효, 1800초 경과, 숫자가 아닌 내용, 뒤에 새 기록 있음), 질문과 계획 승인 도구 호출, `wrap_up` ask 있음과 없음과 빈 문자열, 도구 결과만 있는 `user`, 턴 경계 | 대기 이유와 `isRunning`이 표대로 |
| AC-6 | `SessionMonitoringTests`: 모델과 토큰이 큰 줄 뒤에 있어 64KB 창 밖에 있는 경우를 포함한 합성 기록 | 모델, 토큰, 프로젝트 이름, 제목이 기대와 일치. 창을 넓혀 찾음 |
| AC-7 | `SessionMonitoringTests`: 읽기 횟수를 세는 `FileSystem` 대체 구현으로 같은 수정 시각에 두 번 판정 | 두 번째에 본문 읽기 횟수가 늘지 않음 |
| AC-8 | `FixedTimeSource`와 `InMemoryFileSystem`만으로 `SessionMonitoringTests` 실행. `Sources/SessionMonitoring`과 `Tests/SessionMonitoringTests`에서 `FileManager`와 `Date()` 직접 사용 검색 | 직접 사용 없음. `Boundaries`의 `LiveFileSystem` 통합 테스트만 임시 폴더에서 `FileManager`를 쓴다 |
| AC-9 | `SessionMonitoringTests`: 각 단계별 합성 파일(statusLine 일치와 불일치, config 접두어 둘 중 긴 쪽, `[1m]` 설정, `CLAUDE_CODE_DISABLE_1M_CONTEXT`, 모델 이름 경계 `opus-4-6`과 `opus-4-7`, `sonnet-5`, `haiku-5-4`와 `haiku-5-5`, 토큰 초과 보정). 환경 변수는 주입 | 단계 우선순위와 추정 여부가 표대로 |
| AC-10 | `SessionMonitoringTests`: Codex 첫 줄 `Codex Desktop`, `codex-tui`, `codex_cli_rs`, 첫 줄이 1MB를 넘거나 개행 없음, Claude `entrypoint` 유무 | `openURL`과 터미널 세션 여부가 기대와 일치 |
| AC-11 | `cd apps/macos && swift build && swift test`, `Package.swift` diff 검토 | 모두 통과, 테스트 개수와 결과를 PR에 기록 |

실제 Mac에서의 확인: 이 이슈는 UI와 연결되지 않으므로 앱 실행 검증은 N/A다. 단 동등성 검증을 위해 읽기 전용으로
본인 Mac의 실제 기록 파일에 `LiveFileSystem`을 연결한 임시 실행(테스트가 아니라 일회성 실행)으로 원본 앱의 표시와 같은 상태가 나오는지는 #11 이후 나란히 실행 대조에서 확인한다.
이 이슈의 PR에는 "실기기 대조는 #11 이후"라고 명시한다.

## 미결정 사항

없음. 아래는 사용자가 추천안으로 확정한 결정이다.

| 번호 | 결정 |
| --- | --- |
| D-A | Claude 컨텍스트 창 크기 판정을 포함한다. 이슈 Tasks에 항목을 추가한다(이슈 본문 수정은 별도 승인 후). |
| D-B | Codex 열기 URL만 포함하고 Claude 데스크탑 앱 매핑은 #5에서 다룬다. |
| D-C | `ACTIVE_WINDOW`와 `CLAUDE_PENDING_WINDOW` 두 상수를 유지한다. |
| D-D | `SessionMonitor`는 `actor`로 시작하고 #11에서 조정한다. |
| D-E | `LogTail`의 첫 줄 버림은 동등성을 위해 원본대로 두고, 이 사실을 `docs/reverse/overview.md`에 기록한다. 줄 경계 확인으로 고치는 일은 동등성 검증 뒤에 정한다. |
| D-F | 질문 대기 캐시는 현재 대상 파일에 없는 항목을 정리한다. 캐시가 `private`라 단위 테스트는 두지 않는다(메모리 외 영향 없음). |

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
| --- | --- | --- |
| 1 | 최초 설계. 미결정 D-A부터 D-F를 추천안으로 확정해 범위에 Claude 창 크기 판정과 Codex 열기 URL 추가 | 사용자와 합의한 작업 범위 |
| 2 | 파일 구조를 구현에 맞춤(`SessionLogFinder` 없이 탐색을 `SessionMonitor`에 둠, 보조 타입 파일 추가). AC-8 검증 범위 명확화. D-F 테스트 생략 명시 | 탐색이 활동 캐시와 얽혀 있어 분리하면 캐시 소유가 복잡해짐. 코드 리뷰 지적 반영. 영향 AC: AC-8 |
