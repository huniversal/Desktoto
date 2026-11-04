# 작업 명세: [Feat] Gemini CLI와 Antigravity 세션 표시 지원

## 연결 정보

- 이슈: #52 / https://github.com/huniversal/Desktoto/issues/52
- 브랜치: feat/gemini-session-support/#52
- specRevision: 11
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
- **`transcript.jsonl`만으로는 승인 대기를 구분할 수 없다**: 승인 창이 떠 있는 동안 마지막 줄은 "도구 호출(`PLANNER_RESPONSE`에 `tool_calls`) 직후"와 같은 모양이고, 모든 줄이 `status: DONE`이다. 줄은 단계가 끝난 뒤에 추가된다.
- **SQLite에는 상태가 있다**(2026-11-04 실측, 승인 창이 뜬 상태의 읽기 전용 사본 조회):
  - `~/.gemini/antigravity/conversation_summaries.db`의 `conversation_summaries` 테이블: `status`(`CASCADE_RUN_STATUS_RUNNING` 또는 `CASCADE_RUN_STATUS_IDLE`), `not_fully_idle`(0 또는 1), `killed`, `step_count`, `last_modified_time`, `last_user_input_time`. 끝난 대화는 `IDLE`과 0, 작업 중과 승인 대기 중은 모두 `RUNNING`과 1이었다. 이 테이블만으로는 승인 대기를 구분하지 못한다.
  - `~/.gemini/antigravity/conversations/<id>.db`의 `steps` 테이블: 단계마다 정수 `status`. 완료된 단계는 모두 `3`이었고, 승인을 기다리는 마지막 단계(`step_type` 132, `run_command`로 추정)만 `9`였다. 사용자가 승인을 눌렀다고 확인한 뒤, 1초 간격 기록에서 같은 단계가 `9`에서 `3`으로 바뀐 것을 확인했다(22:48:35 `9`, 22:48:43 `3`). 값 9의 의미는 문서가 없어 "승인 대기"로 보며, 다른 종류의 대기에도 쓰이는지는 모른다.
  - 응답이 끝난 뒤: 요약 `IDLE`과 `not_fully_idle=0`, `steps`의 모든 단계 `status=3`, `step_count`가 `transcript.jsonl` 줄 수(36)와 같고 마지막 줄은 `tool_calls`가 없는 `PLANNER_RESPONSE`였다.
  - 승인 대기 중에는 `step_count`(35)가 `transcript.jsonl` 줄 수(34)보다 1 컸다. 아직 기록되지 않은 진행 중 단계가 있다는 뜻으로 보인다.
  - 두 DB는 WAL 모드라 원본을 읽기 전용으로 직접 열 수 없었고 파일 세트를 복사해 읽어야 했다. 스키마와 정수 값은 문서화되지 않은 내부 형식이라 버전이 바뀌면 깨질 수 있다.
- 아직 관찰하지 못한 것: 오류일 때의 값, 9가 다른 대기(질문 등)에도 쓰이는지, App의 한도(quota) 신호, 대화가 끝났음을 아는 가장 안정적인 방법.

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

범위는 2026-11-04에 사용자와 합의했다. 대상은 **Antigravity**다(Gemini CLI는 개인 Google 계정 로그인이 막혀 제외).

### 포함

- Antigravity App(데스크탑)의 대화를 세션 목록에 표시한다. 상태는 작업 중, 승인 대기, 끝남으로 구분한다.
- 새 툴 추가에 필요한 도메인과 모니터링 변경, 테스트

### 제외

- Gemini CLI. 개인 계정으로 쓸 수 없고, API 키나 Vertex 인증 유저는 별도로 다룬다.
- Antigravity CLI와 IDE 확장. 폴더 이름이 다르고(`antigravity-cli/`, `antigravity-ide/`) 이 PC에서 확인하지 못했다. 별도 이슈로 다룬다.
- 사용량(한도 게이지). App의 한도 신호를 확인하지 못했고 Gemini의 한도 구조도 달라 별도 설계가 필요하다.
- 사용자의 Antigravity 설정(`hooks.json` 등)을 수정하는 훅 설치. 파일 관찰만 쓴다.

## 설계 결정

- 파일 구조와 로직의 책임: 미결정. 읽을 원본은 `~/.gemini/antigravity/brain/<conversationId>/.system_generated/logs/transcript.jsonl`(제목, 마지막 활동, 줄 수)과 두 SQLite(`conversation_summaries.db`의 `status`, 대화별 `.db`의 마지막 단계 `status`)다. 기존 `.jsonl` 읽기에 얹을 수 있는지, SQLite 읽기를 어디에 둘지는 구현 전에 정한다. 파일 시스템과 SQLite 접근은 프로토콜 뒤에 두어 테스트에서 대체한다.
- 모델과 사용량(specRevision 9): 모델은 대화별 DB의 `executor_metadata` 바이너리에서 `gemini-`, `claude-`, `gpt-`로 시작하는 문자열을 찾는다(Antigravity는 Gemini 외에 Claude와 GPT-OSS 모델도 쓴다. 실측에서 한 대화가 `claude-sonnet-4-6`이었다). `gen_metadata`는 안내문 같은 긴 텍스트가 섞여 `gemini-api` 같은 문자열을 모델로 잘못 읽을 수 있어 보지 않는다. 프로토콜 버퍼 문자열 필드는 값 바로 앞 바이트가 길이이므로 그 길이만큼만 잘라 뒤따르는 태그 바이트가 이름에 섞이지 않게 한다. 사용량은 `transcript.jsonl`의 가장 최근 모델 응답에서 `input_tokens + cache_read_tokens`를 쓰고, 창 크기는 모델 이름으로 추정한다: `gemini-*`는 1,048,576(Gemini API 문서의 Gemini 3.8 Flash 입력 한도), `claude-*`는 200,000, `gpt-oss*`는 131,072(Claude와 GPT-OSS는 공개된 일반 한도이며 Antigravity에서의 실제 한도는 확인하지 못함). 모델을 모르거나 모르는 계열이면 퍼센트를 계산하지 않는다. 모두 화면에 ~를 붙인다.
- 세션 열기(specRevision 11): `SessionInfo.openURL`에 `Antigravity.app` 번들 경로를 넣는다. `/Applications`, `~/Applications` 순서로 찾고 없으면 nil이다. 터미널 세션이 아니라서 탭 이동은 쓰지 않는다.
- 상태와 데이터 흐름: 작업 중은 요약 `RUNNING`, 끝남은 `IDLE`이고 `not_fully_idle=0`, 승인 대기는 마지막 단계 `status 9`로 구분한다(위 실측). 대화 목록과 제목은 `transcript.jsonl`과 요약 DB에서 읽는다.
- 선택한 방식과 이유: 훅 설치 없이 파일만 관찰한다. 사용자 설정을 건드리지 않고, `transcript.jsonl`만으로는 승인 대기를 구분할 수 없어 SQLite의 단계 상태를 함께 읽는다.
- 예외 처리: WAL 모드 DB는 읽기 전용으로 직접 열리지 않으므로 읽는 방식(파일 세트 복사 또는 대안)을 구현 전에 확정한다. 스키마와 정수 값은 비공개 내부 형식이므로 알 수 없는 값, 없는 테이블, 잘린 파일은 오류 없이 "상태 알 수 없음"으로 처리하고 버전 변경을 PR에 위험으로 적는다.

## 완료 조건

- AC-1: Antigravity App 대화가 세션 목록에 나타나고 제목과 마지막 활동이 표시된다.
- AC-2: 작업 중, 승인 대기, 끝남이 구분되어 표시된다.
- AC-3: DB가 없거나 스키마와 값이 예상과 다를 때 앱이 죽지 않고 상태 알 수 없음으로 표시한다.
- AC-4: 기존 Claude와 Codex 세션 표시가 바뀌지 않는다.
- AC-5: 합성 데이터와 가짜 경계로 단위 테스트가 있고 `swift build`와 `swift test`가 통과한다.
- AC-6: 실제 Antigravity 2.29.0 이상으로 만든 대화에서 표시와 상태 전환을 확인한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | 합성 `transcript.jsonl`과 요약 DB로 단위 테스트, 실제 앱에서 대화를 만들어 패널 확인 | 대화 표시 |
| AC-2 | 상태별 합성 데이터, 실제 앱에서 승인이 필요한 요청을 보내 전환 관찰 | 세 상태 구분 |
| AC-3 | 빈 파일, 없는 테이블, 모르는 `status` 값으로 단위 테스트 | 오류 없이 상태 알 수 없음 |
| AC-4 | 기존 테스트 전체 | 변경 없이 통과 |
| AC-5 | `cd apps/macos && swift build && swift test` | 통과 |
| AC-6 | 사용자가 로그인한 Antigravity App으로 확인 | 로그인이 없으면 미검증으로 기록 |

## 미결정 사항

- (해결, specRevision 8) SQLite 읽기 방식: macOS 시스템 `SQLite3`를 `Boundaries`의 `SQLiteDatabase` 경계로 감싸 읽기 전용으로 연다. WAL 파일 때문에 열리지 않으면 파일 묶음을 본인만 접근하는 임시 폴더로 복사해 사본을 읽고 바로 지운다. 새 외부 의존은 없다.
- 세션 줄을 누르면 Antigravity 앱을 열어 앞으로 가져온다. 기존 대화를 id로 여는 링크는 공식 문서에 없어서(`antigravity://`는 마켓플레이스와 프롬프트가 채워진 새 대화용이다) 그 대화 자체로 이동하지는 못한다. 모델 이름은 대화별 DB의 바이너리에서 길이 바이트로 잘라 읽으며 파일에 없으면 "모델 알 수 없음"이다(실측에서 한 대화는 모델 문자열이 어디에도 없었다). 컨텍스트 창 크기는 파일에 없어 모델 이름으로 추정하고 화면에 ~를 붙인다. 값 9가 승인 대기 외의 대기(질문 등)에도 쓰이는지, 오류와 취소 때의 값. 구현을 막지는 않지만 상태 표시 정확도에 영향을 준다.
- Antigravity CLI와 IDE 지원 시점. 제외했으므로 구현을 막지 않는다.
- 제보자가 쓰는 것이 App인지 CLI인지. 구현을 막지는 않지만 제보 해결 여부에 영향을 준다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 작성. 조사 결과만 확정하고 설계와 범위는 제안과 미결정으로 둠 | 실제 세션 형식을 확인하기 전이며 범위가 합의되지 않음 |
| 2 | 범위를 Gemini CLI 세션 표시로 확정. Antigravity, 사용량, 훅 설치는 제외 | 사용자와 합의(2026-11-04) |
| 3 | 실측 결과 반영: 현재 형식이 JSONL(헤더, 메시지, `$set` 갱신 줄)임을 확인, Google 계정 로그인 불가와 그에 따른 전제 재확인 항목 추가 | 0.66.0 실행에서 확인 |
| 4 | Antigravity CLI의 statusLine 조사 결과 추가, 대상을 Antigravity CLI로 바꾸는 방향을 미결정으로 제안 | 공식 문서 확인. 사용자와 합의 전이라 범위는 바꾸지 않음 |
| 5 | Antigravity App 실측 결과 반영: `transcript.jsonl` 존재와 줄 형식, 훅 이벤트 확인. 범위는 합의 전이라 바꾸지 않음 | 사용자가 Antigravity App에서 Gemini로 대화한 뒤 파일 변화를 비교 |
| 6 | 승인 대기와 진행 중을 구분할 수 있는 SQLite 신호 조사 결과 반영. 범위는 합의 전이라 바꾸지 않음 | 승인 창이 뜬 상태, 승인 직후, 응답이 끝난 뒤의 상태를 비교(사용자가 승인과 종료를 확인) |
| 7 | 대상을 Antigravity App으로 확정. Gemini CLI, Antigravity CLI와 IDE, 사용량, 훅 설치는 제외. 설계, 완료 조건, 검증을 새로 작성 | 사용자와 합의(2026-11-04). Gemini CLI는 개인 계정 로그인이 막혔고 Antigravity App은 파일로 상태를 읽을 수 있음 |
| 8 | 구현 결정 반영: SQLite 경계(`SQLiteDatabase`)와 임시 사본 읽기, 요약 DB에서 대화 목록과 제목과 작업 폴더를 읽고 대화별 DB의 마지막 단계 `status`로 승인 대기 판정, 승인 대기는 10분이 지나도 30분까지 표시, 모델과 사용량과 세션 열기는 비움 | 실제 구현과 이 PC의 실제 Antigravity 데이터 확인 |
| 9 | 모델 이름과 컨텍스트 사용량 표시 추가(창 크기는 추정). 실제 앱 확인에서 캐릭터는 작업 중에 뛰고 승인 대기가 감지됨을 관찰 | 사용자가 앱에서 모델과 사용량이 비어 있다고 확인 |
| 10 | 모델 이름 접두어를 `claude-`와 `gpt-`까지 넓히고 `gen_metadata`는 읽지 않음. 창 크기를 모델별로 추정하고 모르는 모델은 퍼센트를 계산하지 않음 | 사용자가 Claude 모델 대화에서 모델이 안 나온다고 확인. 실제 파일에서 `claude-sonnet-4-6`을 확인 |
| 11 | 세션 줄 클릭 시 Antigravity 앱을 연다(대화별 이동은 불가). | 사용자가 줄을 눌러도 아무 일이 없다고 확인. 기존 대화를 여는 링크가 문서에 없음 |
