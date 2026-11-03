# Desktoto

AI 코딩 도구(Claude Code, Codex)의 세션 상태와 사용량을 macOS 메뉴바에서 보여 주는 앱이다.
프로토타입 `ai-run`을 리버스 엔지니어링해 제품 동작은 같게 두고, 내부를 문서화, 설계, 테스트가 갖춰진 구조로 다시 만들었다.

## 하는 일

- 메뉴바 캐릭터가 세션 상태에 따라 달리고, 폭죽을 터뜨리고, 오래 쉬면 잠든다. 승인이나 답변을 기다리면 표시가 붙는다.
- 아이콘을 누르면 패널이 열려 Claude와 Codex의 5시간, 주간 사용량과 세션별 컨텍스트 사용률을 보여 준다. 줄을 누르면 그 세션이 있는 앱이나 터미널 탭으로 이동한다.
- 작업이 끝나거나 사람의 응답이 필요해지면 소리와 알림으로 알려 준다.
- 아이콘을 우클릭하면 설정과 종료 메뉴가 열린다(알림, Codex 연동, Claude 연동, 업데이트 확인, 표시할 패널, 색상, 테마, Liquid Glass, 로그인 시 자동 실행).
- 서브 에이전트와 자동 리뷰 세션은 목록에서 제외한다.
- 새 버전이 나오면 우클릭 메뉴 맨 위에 안내가 나타난다. 앱이 시작할 때와 이후 24시간마다 GitHub의 최신 정식 릴리스를 읽기만 하며(보내는 정보는 없다), 메뉴의 "업데이트 확인"으로 끌 수 있다. Homebrew로 설치했다면 `brew upgrade --cask desktoto`를, 아니면 릴리스 페이지를 안내하고, 앱 안에서 자동으로 내려받아 교체하지는 않는다.

## 요구 사항

- macOS 26 이상, Apple Silicon Mac(arm64). Intel Mac은 지원하지 않는다.
- 소스에서 빌드할 때만: Xcode 26.6 이상(Swift 6, Swift Package Manager)
- 이 앱이 읽는 위치: `~/.claude/projects`, `~/.codex/sessions`, `~/.codex/session_index.jsonl`, Claude 데스크탑 앱 캐시, 설치된 `codex`(사용량 조회).

## 설치

Apple Developer 서명과 공증 없이 배포하는 앱이라 설치 방법에 따라 처음 실행할 때 경고가 나올 수 있다.
처음 실행하면 로그인 시 자동 실행, 알림 보내기, Codex 연동, Claude 연동이 켜진 상태로 시작하고, 우클릭 메뉴에서 언제든 끌 수 있다.
로그인 시 자동 실행은 시스템 등록이 실패하거나 승인이 필요하면 꺼진 상태로 남고 다시 시도하지 않는다. 이미 설정을 저장한 사용자는 첫 실행으로 보지 않는다.

### Homebrew

```bash
brew install --cask huniversal/tap/desktoto
```

설치 직후 다운로드 표시(격리 속성)를 제거하므로 처음 실행할 때 경고가 나오지 않는다. 갱신은 `brew upgrade`, 삭제는 `brew uninstall --cask desktoto`이다.

### dmg로 직접 설치

1. [`Desktoto.dmg`](https://github.com/huniversal/Desktoto/releases/latest/download/Desktoto.dmg)를 받아 열고, `Desktoto`를 `응용 프로그램` 폴더로 끌어다 놓는다. 릴리스 페이지에는 압축 파일(`Desktoto-버전.zip`)도 있다. zip은 압축을 풀고 나온 `Desktoto.app`을 `응용 프로그램` 폴더로 옮기면 된다.
2. 처음 열면 "확인할 수 없음" 같은 경고가 뜬다. 창을 닫고 시스템 설정, 개인정보 보호 및 보안 맨 아래에서 `그래도 열기`를 누른 뒤 암호를 입력한다.
3. 다시 열면 메뉴바에 캐릭터가 나타난다.

터미널이 편하면 아래 명령으로 다운로드 표시를 지우고 바로 열 수 있다.

```bash
xattr -dr com.apple.quarantine /Applications/Desktoto.app
```

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

앱은 Claude Code 연동(승인 대기 훅과 statusLine)을 처음 실행할 때 자동으로 켠다. `~/.claude`가 있으면 `~/.claude/settings.json`에 훅이 추가되고(변경 전 백업을 만든다), 이후 시작할 때 자동으로 연결한다. 우클릭 메뉴의 "Claude 연동"을 눌러 끄면 다시 넣지 않는다.

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
├── UpdateCheck/          새 버전 확인(최신 릴리스 조회, 버전 비교, 확인 주기, 설치 방식 판별)
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
