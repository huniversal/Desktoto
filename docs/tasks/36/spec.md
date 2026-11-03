# 작업 명세: [Fix] Claude 사용량 캐시의 쿼리 변형 항목 인식 및 최신 항목 선택

## 연결 정보

- 이슈: #36 / https://github.com/huniversal/Desktoto/issues/36
- 브랜치: fix/claude-usage-cache-query/#36
- specRevision: 1
- 대상 ai-run 원본: `~/Desktop/ai-run/Sources/AiRun/ClaudeDesktopUsage.swift` (읽기 전용, `KEY_PATTERN`이 `/usage$`만 허용). 이번 작업은 원본과 의도적으로 다르게 동작한다.

## 목적

Claude 사용량이 "N분 전 기준"으로 오래 멈춰 있는 문제를 고친다.

- Claude 앱 디스크 캐시에는 사용량 응답이 URL별로 따로 저장된다. 쿼리 없는 `/usage`는 사용량 팝오버를 열 때만 갱신되는 것으로 보이고, `?skip_spend=1` 같은 쿼리 변형이 더 자주 갱신된다.
- 현재 코드는 `/usage$` 키만 허용하고 처음 찾은 항목 하나를 고정해 읽어서, 더 최신인 변형 항목을 보지 못한다.
- 기대 동작은 쿼리가 붙은 키도 사용량 항목으로 인정하고, 조회마다 수정 시각이 가장 최신인 항목의 값을 쓰는 것이다.

## 작업 범위

### 포함

- `apps/macos/Sources/UsageMonitoring/ClaudeCacheParser.swift`: `isUsageKey`가 `/usage` 뒤에 쿼리 문자열이 붙은 키도 허용
- `apps/macos/Sources/UsageMonitoring/UsageMonitor.swift`: 일치하는 캐시 항목을 모두 찾고, 조회마다 수정 시각이 가장 최신인 항목을 사용
- `apps/macos/Tests/UsageMonitoringTests`: 쿼리가 붙은 키와 여러 항목 중 최신 선택 테스트
- `docs/reverse/usage-monitoring.md`: 키 일치 규칙과 항목 선택 규칙을 새 동작으로 갱신하고, ai-run과 달라진 점을 근거와 함께 기록

### 제외

- 사용량을 Desktoto가 직접 요청해 가져오는 기능(Claude 앱이 요청을 보내지 않으면 값은 갱신되지 않는다)
- Codex 사용량, statusLine 소스, 표시 문구와 UI 변경
- 캐시 파일 포맷 파싱 로직(`parse`, `decompress`) 변경

## 설계 결정

- 파일 구조와 로직의 책임: 키 판정은 `ClaudeCacheParser.isUsageKey`, 항목 탐색과 최신 선택은 `UsageMonitor`가 맡는다. 모듈 경계는 바꾸지 않는다.
- 상태와 데이터 흐름: `UsageMonitor`가 항목 하나(`entry`) 대신 일치하는 항목 목록을 보관한다. 조회마다 각 항목의 수정 시각을 확인해 가장 최신 항목을 고르고, 수정 시각이 바뀐 경우에만 다시 파싱해 캐시한다. 삭제된 항목은 목록에서 뺀다. 탐색 작업은 기존처럼 백그라운드에서 돌리고 세대 번호로 오래된 결과를 버린다.
- 선택한 방식과 이유: 키 패턴은 `/api/organizations/[0-9A-Fa-f-]+/usage(\?.*)?$`로 넓힌다. 앱이 여러 URL로 같은 응답 형태를 저장하므로 가장 최근에 저장된 항목이 현재 값에 가장 가깝다. 값 자체는 이미 `ToolUsage.updatedAt`과 `newest`로 소스 간 최신 비교를 하고 있어 그대로 쓴다.
- 예외 처리: 파싱에 실패한 항목은 건너뛰고 다음으로 최신인 항목을 쓴다. 일치하는 항목이 없으면 지금처럼 nil을 반환하고 120초 간격으로 재탐색한다. 캐시는 외부 입력이므로 형식 오류와 부분 손상은 nil로 처리한다.

## 완료 조건

- AC-1: `isUsageKey`가 `/usage`, `/usage?skip_spend=1`, `/usage?cedar_ember=1&skip_spend=1`을 사용량 키로 인정한다.
- AC-2: `isUsageKey`가 조직 ID가 형식에 맞지 않는 키, `/usage` 뒤에 경로가 더 붙은 키(`/usage/other`), `/usage`가 아닌 키는 거부한다.
- AC-3: 일치하는 항목이 여러 개이면 수정 시각이 가장 최신인 항목의 값을 사용한다.
- AC-4: 더 최신인 변형 항목이 생기거나 기존 항목이 갱신되면 다음 조회에서 새 값으로 바뀐다.
- AC-5: 최신 항목이 손상되어 파싱에 실패하면 다음으로 최신인 유효한 항목의 값을 사용한다.
- AC-6: 항목이 삭제되면 목록에서 제외하고, 일치하는 항목이 없으면 nil이며 재탐색은 120초 간격을 지킨다.
- AC-7: `docs/reverse/usage-monitoring.md`가 새 규칙과 ai-run과의 차이를 기록한다.
- AC-8: 기존 `UsageMonitoringTests`가 모두 통과한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1, AC-2 | `UsageTests`에 키 판정 테스트 추가 후 `swift test --filter UsageMonitoringTests` | 통과 |
| AC-3, AC-4, AC-5, AC-6 | 가짜 `FileSystem`으로 여러 항목, 갱신, 손상, 삭제 시나리오 테스트 | 통과 |
| AC-7 | 문서 diff 검토 | 새 규칙과 차이가 기록됨 |
| AC-8 | `swift build`, `swift test` | 실패 0 |
| 전체 | 실제 Mac에서 Claude 앱을 열어 둔 채 Desktoto 패널의 "N분 전 기준" 문구와 Claude 앱 값을 대조 | 팝오버를 열지 않아도 "기준" 문구가 길게 남지 않고 값이 앱 폴링 주기를 따라간다. 실행하지 못하면 미검증으로 기록 |

## 미결정 사항

- 일치하는 항목이 이미 있을 때 새 변형 항목을 얼마나 자주 재탐색할지: 구현 시 기존 120초 간격을 그대로 쓰는 안으로 진행하며, 더 짧게 해야 하는지는 실제 확인 결과로 판단한다. 구현을 막지 않는다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 사용자와 합의한 작업 범위 |
