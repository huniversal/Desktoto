# Claude Code 연동 원본 동작

## 조사 대상

- `~/Desktop/ai-run/Sources/AiRun/ClaudeIntegration.swift`
- `~/Desktop/ai-run/Sources/AiRun/AppDelegate.swift`의 connectClaudeCodeIfNeeded와 handleClaudeIntegrationClick
- `~/Desktop/ai-run/scripts/ai-run-hook.sh`
- `~/Desktop/ai-run/scripts/ai-run-statusline.sh`

원본은 읽기 전용이다. 아래 실행 검증은 합성 설정만 사용했고 사용자 설정 파일과 원본 앱은 변경하지 않았다.

## 설정 연결과 해제

원본은 `~/.claude/settings.json`에 Notification permission_prompt hook을 추가한다.
Notification 그룹의 command에 ai-run-hook.sh가 포함되어 있으면 이미 hook이 있다고 판단한다.
해제 시 해당 명령만 제거하고 비어 있는 그룹과 이벤트를 정리한다.

statusLine이 없으면 `sh '<설치 경로>/ai-run-statusline.sh'`를 추가한다.
command 형식의 statusLine이 있으면 원래 명령을 작은따옴표로 인용해 첫 인자로 전달하고 추가 필드는 유지한다.
다른 statusLine 형식은 바꾸지 않는다.
명령에 ai-run-statusline.sh가 있거나 .ai-run/status 표지가 있으면 이미 연결된 것으로 본다.
명령의 공백과 따옴표로 분리한 경로 후보를 읽어 최대 65,536바이트 안에 같은 표지가 있어도 연결된 것으로 본다.

기존 설정을 읽지 못하면 변경하지 않는다. 빈 파일과 공백만 있는 파일은 빈 객체로 취급한다.
설정의 심볼릭 링크는 실제 대상으로 해석한다.
설정에 변경이 없으면 스크립트 설치도 하지 않는다.
연결은 스크립트 복사, 기존 설정 백업, 설정 원자적 저장 순서다.
해제는 설정 백업 후 앱 hook과 statusLine만 제거하거나 복원한다. 설치한 스크립트는 삭제하지 않는다.
백업 이름은 settings.json.ai-run-backup-yyyyMMdd-HHmmss이고 충돌 시 -2부터 번호를 붙인다.
중간 실패를 failed로 반환하지만 이미 복사한 스크립트를 되돌리지는 않는다.

## 스크립트 입출력

두 스크립트는 /bin/sh와 jq에 의존한다.
hook은 표준 입력 JSON의 transcript_path에서 .jsonl을 제외한 파일 이름을 쓰고,
없으면 session_id를 써서 `~/.ai-run/waiting/<id>`에 date +%s 결과를 저장한다.
이 파일을 지우는 책임은 hook에 없다.

statusLine은 표준 입력을 `~/.ai-run/status/<session_id>.json.tmp`에 기록하고 mv로 교체한다.
session_id가 없으면 저장을 건너뛴다. 첫 인자가 있으면 같은 입력을 sh -c에 전달해 원래 statusLine 명령을 실행한다.
원래 명령의 표준 출력은 그대로 통과하지만 스크립트는 마지막에 exit 0을 실행한다.

## 시작과 사용자 의사

원본 AppDelegate는 connectsClaudeCode가 true이고 Claude 폴더와 hook 리소스가 있으면 백그라운드 연결을 시도한다.
해제 메뉴는 connectsClaudeCode를 false로 바꾸고 disconnect를 호출한다.
명시적 연결은 true로 바꾸고 시작 연결 경로를 다시 호출한다.
새 앱은 별도 UserDefaults를 사용하므로 원본의 해제 상태를 그대로 알 수 없다.
새 앱의 최초 자동 연결 동작은 아키텍처 문서에서 #7과 #11의 미결정 사항으로 남겨 두었다.

## 합성 실행으로 확인한 해제 문제

2026-11-02, 원본 ClaudeIntegration.swift와 임시 main.swift를 swiftc로 컴파일해 순수 변환만 실행했다.
컴파일 캐시는 /private/tmp/desktoto-7-original/cache를 사용했다. 실제 셸 명령이나 사용자 설정은 실행하거나 변경하지 않았다.

입력 command:

```text
sh -c "sh '/tmp/ai-run-statusline.sh' 'printf hello'"
```

원본 disconnectingStatusLine은 결과 command를 `printf hello`로 바꿨다.
다른 셸이 감싼 바깥 구조까지 복원하지 않고 ai-run-statusline.sh 뒤의 문자열만 풀어서 외부 명령이 손실된다.
정상적으로 connectingStatusLine이 생성한 형식은 작은따옴표와 큰따옴표가 섞인 원래 명령으로 정확히 돌아왔다.

제안은 앱이 생성한 정확한 형식에 대해서만 복원하고, 외부에서 다시 감싼 형태는 보존하며 복원 불가로 알리는 것이다.
사용자가 이 처리 방안을 승인했으며, #7 명세 specRevision 2에서 확정했다.

## PR #19에서 확인한 원본 스크립트 입력 손실

2026-11-03, 원본과 같은 스크립트를 임시 HOME에서 /bin/sh로 실행해 두 문제를 재현했다.

- ai-run-hook.sh는 echo로 JSON을 jq에 전달한다. JSON 문자열의 역슬래시와 이스케이프가 변형되면 jq가 실패해 waiting 파일이 생성되지 않거나 잘못된 id로 생성된다. 정상 transcript_path와 session_id가 있어도 다른 필드의 이스케이프 때문에 JSON 전체를 읽지 못할 수 있다.
- ai-run-statusline.sh의 input=$(cat)은 마지막 개행을 제거한다. 개행 두 개를 붙인 35바이트 입력은 33바이트로 저장되고 기존 명령에도 33바이트만 전달됐다.

사용자가 두 보정을 승인했다. 새 앱의 hook은 printf '%s'로 JSON을 전달하고, statusLine은 센티널을 붙여 캡처한 뒤 해당 센티널만 제거해 후행 개행을 유지한다.
원본 소스는 변경하지 않는다. 이 보정 이후 새 앱의 두 스크립트는 원본과 바이트 단위로 같지 않다.
