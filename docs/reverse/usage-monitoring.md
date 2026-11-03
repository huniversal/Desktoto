# 사용량 수집 원본 동작

이 문서는 #6 구현의 동등성 기준이다. 2026-11-02에 아래 원본을 읽기 전용으로 확인했다.
제품 동작과 외부 입력 계약은 유지하고, 내부 구조만 [아키텍처](../architecture.md)에 맞춰 재구성한다.

## 원본 근거

- `~/Desktop/ai-run/Sources/AiRun/UsageWatcher.swift`: 전체. 모델, 파일 후보 선택, 최신값 선택, 초기화 보정.
- `~/Desktop/ai-run/Sources/AiRun/ClaudeDesktopUsage.swift`: 전체. Simple Cache 탐색, 파싱, zstd 해독.
- `~/Desktop/ai-run/Sources/AiRun/CodexRateLimitReader.swift`: 전체. 실행 파일 탐색, JSON-RPC, 프로세스 수명.
- `~/Desktop/ai-run/Sources/AiRun/AppDelegate.swift`: 사용량 호출부. 패널 열림 30초, 닫힘 300초의 Codex 조회 요청, 닫힌 패널 사용량 30초 사전 읽기, 설정과 종료 연결. 이 앱 조립은 #11 범위다.
- `~/Desktop/ai-run/Sources/CZstd`: #2에서 벤더링한 v1.5.7 해독부를 재사용한다.

## 모델과 통합

- `UsageWindow`: 사용 비율과 선택적인 초기화 시각. 비율은 퍼센트를 100으로 나누고 0 이상 1 이하로 제한한다.
- `ToolUsage`: 도구, 선택적인 5시간 한도와 주간 한도, 선택적인 수신 시각.
- 출력은 읽을 수 있는 도구만 Claude, Codex 순서다. 두 한도를 모두 읽지 못하면 해당 소스는 nil이다.
- Claude는 데스크탑 캐시와 statusLine, Codex는 실시간 응답과 세션 기록 중 수신 시각이 최신인 소스의 전체 값을 선택한다. 한도별로 다른 소스를 합치지 않는다. 시각이 없으면 distantPast로 비교한다. 동률은 원본 후보 순서와 max 비교 동작을 기준으로 합성 테스트에서 고정한다.
- 초기화 시각이 현재 시각 이하이면 사용 비율 0, 초기화 시각 nil로 바꾼다. 시각이 없으면 비율을 유지한다. 저장한 원시 값은 조회할 때마다 다시 보정한다.
- 수신 후 600초 이상이면 정수 단위로 `N분 전 기준`, 60분 이상이면 `N시간 전 기준`, 1440분 이상이면 `N일 전 기준`을 만든다. 수신 시각이 없거나 600초 미만이면 nil이다.

## Claude statusLine과 Codex 세션 기록

- statusLine은 `~/.ai-run/status` 아래 json, Codex는 `~/.codex/sessions` 아래 jsonl을 재귀 탐색한다. 숨김 항목은 제외하고 수정 시각 최신순으로 5개까지만 검사한다. 그중 처음 읽을 수 있는 값을 쓴다.
- statusLine은 `rate_limits.five_hour`, `rate_limits.seven_day`의 `used_percentage`, epoch 초 `resets_at`을 읽는다. 수신 시각은 파일 수정 시각이다.
- Codex 기록은 끝 65,536바이트, 524,288바이트, 4,194,304바이트 순으로 확대한다. 각 범위에서 최신 줄부터 `payload.type == token_count`인 `rate_limits`를 찾는다. 공용 `LogTail`의 줄 처리 동작을 재사용한다.
- Codex 기록의 `primary`, `secondary`에서 `used_percent`, `window_minutes`, epoch 초 `resets_at`을 읽는다. 600분 이하는 5시간, 7200분 이상은 주간이다. 중간 길이는 제외하며 같은 분류가 둘이면 뒤의 secondary가 덮어쓴다.
- 기록 수신 시각은 해당 줄의 `timestamp`다. 경로와 수정 시각으로 파싱 결과(nil 포함)를 캐시하고 이번 조회에서 방문하지 않은 경로는 제거한다.

## Claude 데스크탑 캐시

- 위치: `~/Library/Application Support/Claude/Cache/Cache_Data`. 바로 아래 숨김 제외 항목 중 이름이 `_0`으로 끝나고 크기 500 이상 65,536바이트 이하인 파일을 수정 시각 최신순으로 최대 600개 검사한다.
- 머리 24바이트와 최대 512바이트의 키 영역을 읽는다. little endian 매직은 `0xfcfb6d1ba7725c30`, 키 길이 위치는 offset 12다. 키는 `/api/organizations/[0-9A-Fa-f-]+/usage$`와 일치해야 한다.
- 찾은 경로는 기억하고 파일 수정 시각이 바뀔 때만 본문을 다시 파싱한다. 파싱 실패도 캐시한다. 파일이 사라지면 경로와 캐시를 버린다. 탐색은 중복 실행하지 않고 120초 간격으로 제한하며 기본 동작은 백그라운드 탐색이다. 완료 전에는 nil을 반환할 수 있다.
- 본문은 머리와 키 다음부터다. zstd 매직 `28 B5 2F FD`가 있으면 스트리밍 해독하여 첫 프레임 완료에서 멈춘다. 뒤에 캐시 메타데이터가 있어도 첫 프레임만 사용한다. 잘림, 해독 오류, 해독 결과 1,048,576바이트 초과는 nil이다. 평문은 JSON으로 읽는다.
- `five_hour`, `seven_day`의 `utilization`과 ISO 8601 `resets_at`을 읽는다. 날짜의 소수 초를 제거하고 해석한다. 수신 시각은 파일 수정 시각이다.

## Codex 실시간 조회

- 홈 기준 실행 후보 순서: `Applications/Codex.app/Contents/Resources/codex-cli/bin/codex`, `.local/bin/codex`, `.npm-global/bin/codex`, `.bun/bin/codex`.
- 이후 절대 경로 순서: `/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`. 실행 가능한 첫 파일을 선택한다.
- 인자는 `app-server`. 기존 PATH 뒤에 `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`을 추가한다. stderr는 버린다.
- 첫 연결은 `initialize` 요청(clientInfo name `ai-run`, version `1`), `initialized` 알림, `account/rateLimits/read` 요청 순서다. 프로세스를 재사용하면 초기화를 반복하지 않는다.
- 개행으로 끝나는 JSON만 처리하고 미완성 조각은 다음 출력까지 보관한다. 숫자 요청 ID로 응답을 연결하며 오류 응답은 실패다. `account/rateLimits/updated` 알림도 저장한다.
- 응답 `rateLimits.primary/secondary`의 `usedPercent`, `windowDurationMins`, epoch 초 `resetsAt`을 읽는다. 창 분류와 비율 제한은 기록과 같다. 수신 시각은 응답 처리 시각이다.
- 중복 조회와 전달받은 최소 간격 이내 조회를 건너뛴다. 요청 제한 시간은 15초, 실행 파일 없음은 600초, 기타 실패는 120초 재시도 대기다.
- 성공한 뒤 60초 동안 새 요청이 없으면 프로세스를 종료한다. 실패, 비활성화, stop에서도 정리한다. 응답 대기 요청을 실패로 해제하고 출력과 초기화 상태를 비운다.
- 실패와 비활성화는 마지막 성공 값을 지우지 않는다. 최신 기록이 있으면 기록이 선택될 수 있다. 성공 또는 갱신 알림은 호출자에게 변경을 통지한다.
- 종료된 stdin 쓰기는 앱 종료 신호로 이어지지 않게 처리한다. 원본은 SIGPIPE 무시를 사용한다. 새 구현의 수단은 경계 설계에서 정하되 앱 생존 동작을 유지한다.
- 앱이 인증 정보나 HTTP API를 직접 다루지 않는다. 설치된 codex가 자신의 인증으로 요청하는 것은 원본과 같다.

## 구현 전 주의점

동일 시각 후보, 날짜 실패, 한도 일부 누락, 재시도 경계, 종료와 늦은 응답 경합을 합성 입력으로 고정한다. 원본에서 버그로 의심되는 결과가 확인되면 임의 변경하거나 그대로 이식하지 않고 #6 명세의 미결정 사항에 근거와 영향을 기록한 뒤 결정한다.
