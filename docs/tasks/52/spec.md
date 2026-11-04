# 작업 명세: [Feat] Gemini CLI와 Antigravity 세션 표시 지원

## 연결 정보

- 이슈: #52 / https://github.com/huniversal/Desktoto/issues/52
- 브랜치: feat/gemini-session-support/#52
- specRevision: 5
- 대상 ai-run 원본: N/A (원본에 Gemini와 Antigravity 언급이 없다. `~/Desktop/ai-run`의 `Sources`와 `landing`을 검색해 확인함)

## 목적

배포 후 제보(노션 "배포 후 버그 리스트" 4번)로, Gemini CLI와 Antigravity를 쓰는 유저에게 Desktoto가 표시되지 않는다.
버그가 아니라 미지원이다. `apps/macos/Sources/Domain/AiTool.swift`는 `claude`와 `codex`만 정의하고,
`apps/macos/Sources/SessionMonitoring/SessionMonitor.swift`의 탐색 경로도 `~/.claude/projects`와 `~/.codex/sessions`의 `.jsonl`로 고정되어 있다.
이 명세는 조사 결과를 기록하고, 사용자와 합의할 범위를 정리하는 첫 버전이다. 합의되지 않은 항목은 확정하지 않는다.

## 조사 결과

확인한 날짜는 2026-11-04이고, 설치한 Gemini CLI는 0.66.0, Antigravity는 2.29.0이다.

### 공식 문서로 확인된 것 (Gemini CLI)

- 세션 위치: `~/.gemini/tmp/<project_hash>/chats/`. 세션은 프로젝트별이다(`docs/cli/session-management.md`).
- 보존: 기본 30일(`general.sessionRetention.maxAge`), 개수 제한은 기본 없음. 세션을 지우면 관련 데이터도 함께 지워진다.
- 훅 이벤트: `SessionStart`, `SessionEnd`, `BeforeAgent`, `AfterAgent`, `BeforeToolSelection`, `BeforeTool`, `AfterTool`, `Notification`(`ToolPermission`). 입력 JSON에 `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `timestamp`가 있다(`docs/hooks/reference.md`).
- 한도: 인증 방식과 요금제별 **하루 요청 수**(예: Google AI Pro 1,500, Gemini API 무료 250). 5시간이나 주간 창은 문서에 없다(`docs/resources/quota-and-pricing.md`).

### 공식 문서로 확인된 것 (Antigravity CLI)

Antigravity는 Antigravity App(데스크탑), Antigravity CLI, IDE 확장, SDK로 나뉘며 로그인은 공유된다(`antigravity.google/docs/install`).
**Antigravity CLI는 Claude Code와 구조가 거의 같은 statusLine을 제공한다**(`antigravity.google/docs/cli/statusline`).

- 설정: `~/.gemini/antigravity-cli/settings.json`의 `statusLine`(`type: command`, `command`). CLI가 상태가 바뀔 때마다 명령을 `sh -c`로 실행하고 세션 JSON을 stdin으로 넘긴다. 최소 300ms 간격, 5초 초과 시 중단, 연속 30회 실패 시 비활성.
- 입력 JSON의 주요 필드: `session_id`(= `conversation_id`), `transcript_path`(예: `~/.gemini/antigravity/brain/<id>/.system_generated/logs/transcript.jsonl`), `cwd`, `workspace`, `model`, `context_window`, `agent_state`(`idle`, `working`, `tool_use`, `reviewing`, `authenticating`, `initializing`, `error`), `tool_confirmation_pending`(도구 확인 대기), `pending_input_count`, `quota`(버킷 ID별 `remaining_fraction`, `reset_time`, `reset_in_seconds`; 예시는 `gemini-weekly`), `plan_tier`, `email`, `product`(`antigravity`).
- 이 구조는 이 앱이 Claude에 쓰는 상태 스크립트 방식(`ai-run-statusline.sh`가 stdin JSON을 `~/.ai-run/status`에 저장)과 같게 적용할 수 있고, 상태 판별(`agent_state`, `tool_confirmation_pending`)과 주간 한도(`quota`)까지 얻을 수 있다.
- Antigravity App(데스크탑)과 IDE는 별도 제품이며 `~/.gemini/antigravity/conversations/*.pb` 바이너리를 쓴다. statusLine이 CLI 문서에만 있어 App 쪽 신호는 확인하지 못했다.
- 확인하지 못한 것: CLI 설치 명령과 실행 파일 이름, 이 PC에서의 실제 동작, 제보자가 쓰는 것이 CLI인지 App인지.

### Antigravity App 실측 (2026-11-04, Antigravity 2.29.0, Gemini 모델로 짧은 대화 1회)

- **대화마다 JSONL 기록이 생긴다**: `~/.gemini/antigravity/brain/<conversationId>/.system_generated/logs/transcript.jsonl`(같은 내용의 `transcript_full.jsonl`과 `chunks/` 아래 조각도 있다). 앞서 `.pb`만 있다고 본 것은 옛 파일 기준이었다.
- 줄 형식: `step_index`, `source`, `type`, `status`, `created_at`, `content`와 모델 응답 줄의 `input_tokens`, `cache_read_tokens`, `output_tokens`. 관찰한 줄은 `type`이 `USER_INPUT`, `PLANNER_RESPONSE`이고 `status`는 둘 다 `DONE`이다.
- 그 밖에 생긴 것: `conversation_summaries.db`(SQLite), `conversations/<id>.db`(SQLite)와 기존 `.pb`, `presence/<id>.lock`, `daemon/hub_<pid>.json`(포트와 토큰이 들어 있어 읽지 않는다), 설정은 `~/.gemini/config/`. 앱이 `antigravity-ide/`와 `antigravity-backup/`에 옛 데이터를 복사해 두었다.
- 제품마다 폴더 이름이 다르다(훅 문서 기준): App은 `antigravity/`, CLI는 `antigravity-cli/`, IDE는 `antigravity-ide/`.
- 훅은 `hooks.json`에서 `SessionStart`, `PreToolUse`, `PostToolUse`, `PreInvocation`, `PostInvocation`, `Stop`을 지원하고 stdin JSON에 `conversationId`, `transcriptPath`, `workspacePaths`, `modelName`, `lastUserInput`이 있다. 동기 실행으로 에이전트 루프를 막으며 `command` 타입만 된다. 사용자 설정 수정이 필요해 이번 범위에서는 쓰지 않는다.
- 아직 관찰하지 못한 것: 실행 중, 도구 승인 대기, 오류일 때의 `status`와 `type` 값, App의 한도(quota) 신호, 대화가 끝났음을 아는 방법.

### 이 PC에서 직접 본 것

- 현재 형식(0.66.0, 2026-11-04 실측): `~/.gemini/tmp/<프로젝트 폴더 이름의 소문자>/chats/session-<날짜>-<8자리>.jsonl`. **한 줄씩 추가되는 JSONL**이며 줄은 세 종류다.
  - 첫 줄(헤더): `sessionId`, `projectHash`(64자리 16진수), `startTime`, `lastUpdated`, `kind`(`main`)
  - 메시지 줄: `id`, `timestamp`, `type`, `content`. 관찰한 `type`은 `user`(content가 배열)와 `info`(content가 문자열)다.
  - 갱신 줄: `{"$set":{"lastUpdated":...}}`. 메시지가 추가될 때마다 뒤따른다.
- 프로젝트 폴더 안에 `.project_root`(작업 폴더 경로)와 `logs.json`이 있다. 폴더 이름은 문서의 `<project_hash>`가 아니라 작업 폴더 이름이다.
- 문서의 단일 JSON(`messages` 배열)은 2026-03의 옛 파일에서만 보였고, 0.66.0은 JSONL이다. 두 형식이 섞여 있을 수 있다.
- **Google 계정 로그인 불가**: 0.66.0에서 "Sign in with Google"이 "This client is no longer supported for Gemini Code Assist for individuals. To continue using Gemini, please migrate to the Antigravity suite of products"로 실패했다. 개인 Google 계정으로는 더 이상 쓸 수 없고, 남은 인증은 Gemini API 키와 Vertex AI다.
- Antigravity: 대화가 `~/.gemini/antigravity/conversations/<uuid>.pb`로 저장된다. JSON이 아닌 **바이너리(protobuf)** 이고 형식 문서를 찾지 못했다.

### 확인하지 못한 것

- 모델 응답과 도구 승인 대기 상태의 메시지 `type`. 로그인 실패로 모델 응답이 없어 `user`와 `info`만 관찰했다.
- 응답 중, 입력 대기(도구 승인 대기 포함), 종료를 파일만으로 구분할 수 있는지.
- API 키로 쓴 세션이 같은 형식인지.
- Antigravity가 훅이나 다른 신호를 제공하는지.
- 제보자가 실제로 어떤 툴을 어떤 방식으로 쓰는지.

## 작업 범위

범위는 2026-11-04에 사용자와 합의했다(Gemini CLI만).

### 포함

- Gemini CLI 세션을 세션 목록에 표시한다. 상태 판별 방식은 실측 후 확정한다.
- 새 툴 추가에 필요한 도메인과 모니터링 변경, 테스트

### 제외

- Antigravity 지원. 바이너리 형식이라 파일 읽기만으로는 어렵고 형식 문서가 없다. 별도 이슈로 다룬다.
- 사용량(한도 게이지). Gemini의 한도는 하루 요청 수라서 현재의 5시간과 주간 구조(`UsageWindow`)와 맞지 않는다. 필요하면 별도로 설계한다.
- 사용자의 Gemini 설정 파일을 수정하는 훅 설치. 합의하지 않았으므로 파일 관찰 방식만 검토한다.

## 설계 결정

- 파일 구조와 로직의 책임: 미결정. 기존 `.jsonl` 로그 읽기가 한 줄씩 추가되는 파일을 전제로 하므로, 단일 JSON을 통째로 다시 쓰는 Gemini 형식이 같은 읽기 경로에 맞는지 확인해야 한다.
- 상태와 데이터 흐름: 미결정. 파일의 `lastUpdated` 변화와 `messages`의 마지막 `type`으로 판별하는 방식, 또는 훅(`Notification`, `AfterAgent`)을 설치하는 방식 중 선택한다. 훅 방식은 사용자의 Gemini 설정 파일을 수정하게 되어 별도 합의가 필요하다.
- 선택한 방식과 이유: 미결정. 위 실측 결과에 달려 있다.
- 예외 처리: 미결정. 잘린 JSON, 프로젝트 폴더 이름 규칙 변화, 보존 기간으로 인한 세션 삭제를 검토한다.

## 완료 조건

범위가 합의되면 확정한다. 현재 후보는 아래와 같다.

- AC-1: Gemini CLI 세션이 세션 목록에 나타나고, 프로젝트 이름과 마지막 활동이 표시된다.
- AC-2: 실행 중과 입력 대기와 종료가 구분되어 표시된다(방식은 미결정).
- AC-3: 기존 Claude와 Codex 세션 표시가 바뀌지 않는다.
- AC-4: 합성 데이터와 가짜 FileSystem으로 단위 테스트가 있고, `swift build`와 `swift test`가 통과한다.
- AC-5: 실제 Gemini CLI 0.66.0 이상으로 만든 세션에서 표시를 확인한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | 합성 세션 JSON으로 단위 테스트, 실제 Gemini CLI 세션으로 패널 확인 | 세션 표시 |
| AC-2 | 상태별 합성 데이터와 실제 세션에서 상태 전환 관찰 | 상태 구분 |
| AC-3 | 기존 테스트 전체 | 변경 없이 통과 |
| AC-4 | `cd apps/macos && swift build && swift test` | 통과 |
| AC-5 | 사용자가 로그인한 Gemini CLI로 짧은 대화를 만든 뒤 확인 | 로그인이 없으면 미검증으로 기록 |

## 미결정 사항

- **방향 전환 후보(실측으로 강화됨)**: Antigravity App과 CLI는 `transcript.jsonl`(JSONL, `status` 필드 포함)을 남기므로 훅 설치 없이 파일 관찰로 대화를 볼 수 있다. 대상을 Gemini CLI에서 Antigravity(`transcript.jsonl`)로 바꾸는 것을 제안한다. 사용자와 합의가 필요하다.
- **(이전 기록)**: Gemini CLI는 개인 계정으로 쓸 수 없고, Antigravity CLI는 statusLine으로 상태와 주간 한도를 얻을 수 있어 대상을 Gemini CLI에서 Antigravity CLI로 바꾸는 것을 제안한다. 사용자와 합의가 필요하며, 그 경우 위의 "포함", "제외", 완료 조건을 다시 쓴다. 구현을 막는다.
- **전제 재확인**: 개인 Google 계정으로 Gemini CLI를 쓸 수 없게 되어 제보의 "Gemini CLI" 유저가 어떤 인증으로 쓰는지(API 키, Vertex, Workspace)와, 실제로 Antigravity(바이너리 `.pb`)를 쓰는 것은 아닌지 제보자에게 확인해야 한다. 이 답에 따라 Gemini CLI만 지원하는 것이 제보를 해결하는지 달라진다. 구현을 막는다.
- 상태 판별 방식. 훅 설치는 제외했으므로 파일 관찰로 구분할 수 있는지 실측이 필요하며 구현을 막는다. 구분이 어렵다면 "세션 표시"까지만 할지 다시 정한다.
- 제보자의 실제 환경. 구현을 막지는 않지만 범위 판단에 영향을 준다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 작성. 조사 결과만 확정하고 설계와 범위는 제안과 미결정으로 둠 | 실제 세션 형식을 확인하기 전이며 범위가 합의되지 않음 |
| 2 | 범위를 Gemini CLI 세션 표시로 확정. Antigravity, 사용량, 훅 설치는 제외 | 사용자와 합의(2026-11-04) |
| 3 | 실측 결과 반영: 현재 형식이 JSONL(헤더, 메시지, `$set` 갱신 줄)임을 확인, Google 계정 로그인 불가와 그에 따른 전제 재확인 항목 추가 | 0.66.0 실행에서 확인 |
| 4 | Antigravity CLI의 statusLine 조사 결과 추가, 대상을 Antigravity CLI로 바꾸는 방향을 미결정으로 제안 | 공식 문서 확인. 사용자와 합의 전이라 범위는 바꾸지 않음 |
| 5 | Antigravity App 실측 결과 반영: `transcript.jsonl` 존재와 줄 형식, 훅 이벤트 확인. 범위는 합의 전이라 바꾸지 않음 | 사용자가 Antigravity App에서 Gemini로 대화한 뒤 파일 변화를 비교 |
