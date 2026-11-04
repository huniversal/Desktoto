# 작업 명세: [Feat] Gemini CLI와 Antigravity 세션 표시 지원

## 연결 정보

- 이슈: #52 / https://github.com/huniversal/Desktoto/issues/52
- 브랜치: feat/gemini-session-support/#52
- specRevision: 1
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

### 이 PC에서 직접 본 것

- Gemini CLI 세션 파일: `session-<날짜>-<해시>.json` 단일 JSON 객체. 키는 `sessionId`, `projectHash`, `startTime`, `lastUpdated`, `messages`(각 항목 `id`, `timestamp`, `type`, `content`), `kind`. 2026-03의 옛 파일 하나만 확인했다.
- 이 PC의 프로젝트 폴더 이름은 해시가 아니라 사용자 이름(`~/.gemini/tmp/huniverse/`)이었다. 문서의 `<project_hash>`와 다르다.
- Antigravity: 대화가 `~/.gemini/antigravity/conversations/<uuid>.pb`로 저장된다. JSON이 아닌 **바이너리(protobuf)** 이고 형식 문서를 찾지 못했다.

### 확인하지 못한 것

- 0.66.0이 지금 어떤 형식과 폴더 이름으로 세션을 쓰는지. `gemini -p`를 실행해 봤으나 브라우저 로그인 단계에서 멈췄다(로그인은 사용자가 직접 해야 한다). 로그인 후 새 세션 파일을 확인해야 한다.
- 응답 중, 입력 대기(도구 승인 대기 포함), 종료를 파일만으로 구분할 수 있는지.
- Antigravity가 훅이나 다른 신호를 제공하는지.
- 제보자가 실제로 어떤 툴을 어떤 방식으로 쓰는지.

## 작업 범위

아래는 조사 결과를 바탕으로 한 **제안이며 사용자와 합의 전**이다.

### 포함 (제안)

- Gemini CLI 세션을 세션 목록에 표시한다. 상태 판별 방식은 실측 후 확정한다.
- 새 툴 추가에 필요한 도메인과 모니터링 변경, 테스트

### 제외 (제안)

- Antigravity 지원. 바이너리 형식이라 파일 읽기만으로는 어렵고 형식 문서가 없다. 별도 이슈로 다룬다.
- 사용량(한도 게이지). Gemini의 한도는 하루 요청 수라서 현재의 5시간과 주간 구조(`UsageWindow`)와 맞지 않는다. 필요하면 별도로 설계한다.

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

- 지원 범위: Gemini CLI만 할지, Antigravity까지 할지. 위 제안은 Gemini CLI만이다. 구현을 막는다.
- 사용량 포함 여부: 제안은 제외다. 구현을 막지는 않는다.
- 상태 판별 방식(파일 관찰 대 훅 설치). 실측이 필요하며 구현을 막는다.
- 제보자의 실제 환경. 구현을 막지는 않지만 범위 판단에 영향을 준다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 작성. 조사 결과만 확정하고 설계와 범위는 제안과 미결정으로 둠 | 실제 세션 형식을 확인하기 전이며 범위가 합의되지 않음 |
