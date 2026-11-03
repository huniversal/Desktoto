# Desktoto

AI 코딩 도구(Claude Code, Codex)의 세션 상태와 사용량을 macOS 메뉴바에서 보여 주는 앱이다.
프로토타입 `ai-run`을 리버스 엔지니어링해 제품 동작은 같게 두고, 내부를 문서화, 설계, 테스트가 갖춰진 구조로 다시 만들었다.

## 하는 일

- 메뉴바 캐릭터가 세션 상태에 따라 달리고, 폭죽을 터뜨리고, 오래 쉬면 잠든다. 승인이나 답변을 기다리면 표시가 붙는다.
- 아이콘을 누르면 패널이 열려 Claude와 Codex의 5시간, 주간 사용량과 세션별 컨텍스트 사용률을 보여 준다. 줄을 누르면 그 세션이 있는 앱이나 터미널 탭으로 이동한다.
- 작업이 끝나거나 사람의 응답이 필요해지면 소리와 알림으로 알려 준다.
- 아이콘을 우클릭하면 설정과 종료 메뉴가 열린다(알림, Codex 연동, Claude 연동, 표시할 패널, 색상, 테마, Liquid Glass, 로그인 시 자동 실행).
- 서브 에이전트와 자동 리뷰 세션은 목록에서 제외한다.

## 요구 사항

- macOS 26 이상, Xcode 26.6 이상(Swift 6, Swift Package Manager)
- 이 앱이 읽는 위치: `~/.claude/projects`, `~/.codex/sessions`, `~/.codex/session_index.jsonl`, Claude 데스크탑 앱 캐시, 설치된 `codex`(사용량 조회).

## 빌드와 실행

저장소 루트에서 시작한다.

```bash
cd apps/macos
swift build
swift test
```

앱 번들을 만들고 실행한다.

```bash
cd apps/macos
sh scripts/build-app.sh
open build/Desktoto.app
```

`build-app.sh`는 릴리스 빌드, 번들 구성, 아이콘 생성, ad-hoc 서명과 검증까지만 한다. 다운로드한 앱은 처음 실행할 때 Gatekeeper 경고가 나오고 공증은 하지 않는다.

> 주의: `scripts/install-app.sh`는 `~/Applications/Desktoto.app`을 지우고 덮어쓴다. 원본 `ai-run` 앱이 같은 경로에 설치되어 있으면 번들 식별자가 달라 아무것도 지우지 않고 중단한다. 원본과 나란히 비교하는 동안에는 `build-app.sh`만 쓰고 `build/Desktoto.app`을 직접 연다.

앱은 Claude Code 연동(승인 대기 훅과 statusLine)을 처음에는 자동으로 켜지 않는다. 우클릭 메뉴의 "Claude 연동"을 눌러 켜면 `~/.claude/settings.json`에 훅이 추가되고(변경 전 백업을 만든다), 이후 시작할 때 자동으로 연결한다. 끄면 다시 넣지 않는다.

## 구조

```
apps/macos/Sources/
├── Domain/               값 타입과 모듈 사이 연결용 프로토콜
├── Boundaries/           파일, 프로세스, 시간, AppleScript, URL 경계(프로토콜과 실제 구현)
├── DesignSystem/         디자인 토큰과 공용 컴포넌트
├── SessionMonitoring/    기록 파일 탐색, 진행과 완료와 대기 판정, 컨텍스트 사용률
├── UsageMonitoring/      Claude와 Codex 사용량 수집
├── ClaudeIntegration/    Claude Code 설정의 훅과 statusLine 연결과 해제
├── TerminalIntegration/  터미널 프로세스 탐색, 탭 이동, 세션 열기
├── Preferences/          설정, 알림, 로그인 항목, 설정 메뉴 항목 모델
├── MenuBarIcon/          캐릭터 격자, 프레임, 이미지
├── SessionPanel/         유리 패널 화면과 모델
├── CZstd/                벤더링한 zstd 해독부(C)
├── TestSupport/          테스트용 가짜 구현
└── Desktoto/             앱 진입점과 조립(감시 타이머, 알림, 세션 열기, 설정 메뉴)
```

기능 모듈끼리는 서로 import하지 않고 조립은 `Desktoto`만 한다. 자세한 규칙은 [아키텍처](docs/architecture.md)를 본다.

## 문서

- [아키텍처](docs/architecture.md), [디자인 시스템](docs/design-system.md), [CI와 릴리스](docs/ci.md)
- [원본 동작 기록](docs/reverse/overview.md): 모듈별 원본 동작과 원본과 달라진 점
- [작업 명세](docs/tasks): 이슈별 명세와 검증 기록
- [규칙](docs/rules): 코딩, Git, 작업 흐름, macOS 개발 기준
