<h1 align="center">Desktoto</h1>

<p align="center">AI가 일하는 동안, 메뉴바에서 지켜보세요.</p>

<p align="center">
  <a href="https://github.com/huniversal/Desktoto/releases"><img src="https://img.shields.io/github/downloads/huniversal/Desktoto/total" alt="총 다운로드 수"></a>
  <a href="https://github.com/huniversal/Desktoto/releases/latest"><img src="https://img.shields.io/github/v/release/huniversal/Desktoto" alt="최신 버전"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B%20%7C%20Apple%20Silicon-black" alt="요구 사항">
</p>

<p align="center">
  <a href="https://desktoto.pages.dev">랜딩 페이지</a> |
  <a href="https://github.com/huniversal/Desktoto/releases/latest/download/Desktoto.dmg">macOS용 다운로드</a>
</p>

Desktoto는 AI Agent(Claude Code, Codex) 세션의 진행 상태를 메뉴바의 작은 캐릭터로 보여줘요.
작업이 끝났는지, 내 답을 기다리는지 창을 열지 않고도 알 수 있어요.

<p align="center">
  <img src="docs/images/readme/hero.png" alt="Desktoto: AI가 일하는 동안, 메뉴바에서 지켜보세요. 메뉴바 캐릭터와 세션 패널" width="860">
</p>

## 설치

macOS 26 이상의 Apple Silicon Mac에서 쓸 수 있어요. Intel Mac은 지원하지 않아요.
Apple Developer 서명과 공증 없이 배포하는 앱이라 설치 방법에 따라 처음 실행할 때 경고가 나올 수 있어요.

### Homebrew로 설치

터미널을 쓴다면 Homebrew가 가장 편해요.

```bash
brew install --cask huniversal/tap/desktoto
```

설치하면서 다운로드 표시를 지워 주어서 처음 실행할 때 경고가 나오지 않아요. 새 버전은 `brew upgrade --cask desktoto`로 받고, 지우려면 `brew uninstall --cask desktoto`를 실행해요.

### dmg로 설치

1. [`Desktoto.dmg`](https://github.com/huniversal/Desktoto/releases/latest/download/Desktoto.dmg)를 받아 열고, `Desktoto`를 `응용 프로그램` 폴더로 끌어다 놓아요. 릴리스 페이지에는 압축 파일(`Desktoto-버전.zip`)도 있어요. zip은 압축을 풀고 나온 `Desktoto.app`을 `응용 프로그램` 폴더로 옮기면 돼요.
2. 처음 열면 개발자를 확인할 수 없다는 경고가 떠요. 창을 닫아요.
3. 시스템 설정, 개인정보 보호 및 보안 맨 아래에서 `그래도 열기`를 누르고 암호를 입력해요.
4. 다시 열면 메뉴바에 캐릭터가 나타나요.

터미널이 편하다면 이 명령으로 다운로드 표시를 지우고 경고 없이 열 수도 있어요.

```bash
xattr -dr com.apple.quarantine /Applications/Desktoto.app
```

처음 실행하면 로그인 시 자동 실행, 알림 보내기, Codex 연동, Claude 연동이 켜진 상태로 시작해요. 아이콘을 우클릭한 메뉴에서 언제든 끌 수 있어요.

## 왜 필요한가요

<p align="center">
  <img src="docs/images/readme/problem.png" alt="세션을 여러 개 돌리면 놓치게 돼요. 끝난 지 한참 뒤에야 알게 되고, 승인 창에서 AI가 멈춘 줄 모르고, 컨텍스트가 얼마나 찼는지 알 수 없어요." width="860">
</p>

## 캐릭터 상태

<p align="center">
  <img src="docs/images/readme/states.png" alt="캐릭터 상태 5가지: 달리는 중, 폭죽(작업 끝), 물음표(승인이나 답변 필요), 보라색 점(확인하지 않은 완료), 졸음(10분 동안 활동 없음)" width="860">
</p>

## 기능

<p align="center">
  <img src="docs/images/readme/features.png" alt="기능: 한 패널에 모든 세션, AI 사용량, 컨텍스트 사용률, 카드를 누르면 그 세션으로 이동, 알림 이동, 색상과 테마와 Liquid Glass 설정" width="860">
</p>

## 개인정보

<p align="center">
  <img src="docs/images/readme/privacy.png" alt="대화 내용은 컴퓨터 밖으로 나가지 않아요. 읽는 것, 하지 않는 것, 새 버전 확인, 설정 파일 안내" width="860">
</p>

개인정보 섹션의 `새 버전 확인`은 앱이 시작할 때와 이후 24시간마다 GitHub의 최신 릴리스 정보를 읽기만 하며, 우클릭 메뉴의 업데이트 확인에서 끌 수 있어요.

## 알아 두세요

Desktoto는 수익을 목적으로 하지 않는 무료 프로젝트예요. 광고도, 결제도 없어요.
캐릭터는 Claude Code의 마스코트에서 영감을 받은 팬 작품이에요. Claude는 Anthropic의, Codex는 OpenAI의 상표이고, Desktoto는 두 회사의 공식 제품이 아니에요.
다운로드 배지는 `Desktoto.dmg`와 zip을 내려받은 횟수의 합이며, 사람 수가 아니에요.

## 개발자용

### 빌드와 실행

소스에서 빌드하려면 Xcode 26.6 이상(Swift 6, Swift Package Manager)이 필요하다. 저장소 루트에서 시작한다.

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

### 구조

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

### 문서

- [아키텍처](docs/architecture.md), [디자인 시스템](docs/design-system.md), [CI와 릴리스](docs/ci.md)
- [원본 동작 기록](docs/reverse/overview.md): 모듈별 원본 동작과 원본과 달라진 점
- [작업 명세](docs/tasks): 이슈별 명세와 검증 기록
- [규칙](docs/rules): 코딩, Git, 작업 흐름, macOS 개발 기준
