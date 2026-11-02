# 작업 명세: [Chore] 아키텍처 및 프로젝트 골격 세팅

## 연결 정보

- 이슈: #2 / https://github.com/huniversal/Desktoto/issues/2
- 브랜치: `feat/architecture-setup/#2`
- specRevision: 10
- 대상 ai-run 원본: 전체
  - `~/Desktop/ai-run/Package.swift`
  - `~/Desktop/ai-run/Sources/AiRun/*.swift` (13개 파일)
  - `~/Desktop/ai-run/Sources/CZstd`
  - `~/Desktop/ai-run/scripts/*` (`Info.plist`, `ai-run-hook.sh`, `ai-run-statusline.sh`, `build-app.sh`, `make-icon.swift`)
- 동작 문서화 위치: `docs/reverse/overview.md`

## 목적

이후 모든 기능 이슈(#3 이후)가 따를 구조를 먼저 확정한다.
원본의 동작을 입력, 상태, 출력, 외부 의존으로 문서화하고, 그 위에서 모듈 구성과 의존 방향, 외부 경계 처리 방식,
언어 모드, 최소 macOS 버전, zstd 처리, 이름 정리를 결정해 `docs/architecture.md`에 남긴다.
결정이 끝나면 그 결정대로 `Package.swift`와 타깃, 테스트 타깃의 빈 골격을 만든다.
기능 구현은 이 이슈의 범위가 아니다.

## 작업 범위

### 포함

- 원본 전체 동작 개요 문서 `docs/reverse/overview.md` 작성 (완료, 커밋 `95da974`)
- 모듈 구성과 의존 방향 설계 및 `docs/architecture.md` 작성 (도메인 모델, 외부 경계, 기능, 디자인 시스템, 앱)
- 외부 경계(파일 시스템, 프로세스, 시간, AppleScript)를 프로토콜 뒤에 두는 방식과 테스트 전략 결정
- 언어 모드와 최소 macOS 버전 확정
- zstd 처리 방식 결정 (벤더링한 `CZstd` 유지, 시스템 라이브러리, 외부 패키지 중 선택)
- 이름 정리 결정 (앱 이름, 번들 식별자, 실행 파일명, 데이터 폴더 `~/.ai-run` 유지 여부)
- `apps/macos/Package.swift`와 타깃, 테스트 타깃 골격 생성 (#1이 CI 검증용으로 둔 임시 골격 `Desktoto`, `DesktotoCore`, `DesktotoCoreTests`를 교체)
- 확정한 이름을 #1이 만든 `apps/macos/scripts/build-app.sh`의 기본값, `apps/macos/scripts/Info.plist`, `docs/ci.md`에 반영
- `apps/macos/scripts/install-app.sh`가 설치 대상 경로에 번들 식별자가 다른 앱이 있으면 덮어쓰지 않고 중단하는 확인 추가(코드 리뷰 지적 CR-001, 사용자 승인)

### 제외

- 기능 구현 (세션 감시, 사용량, 연동, UI 등은 #3 이후 이슈)
- 디자인 토큰과 컴포넌트 구현 (#3)
- CI와 앱 패키징, 서명 (#1)
- `apps/web`(랜딩) 생성 (#12). 모노레포 레이아웃 중 `apps/macos`는 #1이 만든 구조를 따르고 이 이슈에서 정식 골격으로 교체한다
- 기능별 상세 동작 문서화의 보완 (`overview.md` 9장에 적은 항목은 해당 기능 이슈에서)
- 린터, 포맷터, Git 훅 도입 (합의 전까지 추가하지 않음)
- 앱 소스 폴더 구조 중 `architecture.md`에서 확정하지 않은 부분
- 사용자가 쓰는 설치된 `ai-run` 앱, `~/.ai-run`, `~/.claude/settings.json`의 변경 (불변 조건: 전체 작업이 끝날 때까지 건드리지 않는다)
  - `install-app.sh`는 `~/Applications/Desktoto.app`을 지우고 덮어쓰므로 이 작업에서 실행하지 않는다. 새 앱은 `apps/macos/build/Desktoto.app`을 직접 연다.

## 설계 결정

- 파일 구조와 로직의 책임:
  - `docs/reverse/overview.md`: 원본에서 확인한 사실만 기록한다(설계 없음).
  - `docs/architecture.md`: 이 이슈에서 내린 결정과 그 이유를 기록한다. 이후 이슈의 전제가 된다.
  - `Package.swift`와 `Sources`, `Tests`의 빈 골격: `architecture.md`의 결정을 그대로 반영한다. 로직은 담지 않는다.
- 패키지 위치: 저장소는 모노레포이고 Swift 패키지는 `apps/macos`에 둔다(#1에서 확정, `docs/rules/macos-development.md`와 `docs/ci.md`). 빌드와 테스트는 `cd apps/macos` 뒤에 실행한다.
- 이름(D-1 확정, 사용자 합의): 앱 이름, 실행 파일, 패키지 이름은 `Desktoto`, 번들 식별자는 `com.huniverse.desktoto`다.
  번들 ID를 바꾸면 알림, 로그인 항목, 자동화 권한은 새 앱으로 다시 허용해야 하고, 원본 `ai-run` 앱과는 별개의 앱으로 취급된다(원본 앱은 사용자의 테스트용이며 작업이 끝날 때까지 변경하지 않는다).
- 데이터 폴더와 스크립트(D-2 확정, 사용자 합의): 제품 동작을 원본과 같게 유지하기 위해 `~/.ai-run`, `ai-run-hook.sh`, `ai-run-statusline.sh` 이름을 그대로 쓴다.
  원본과 새 앱을 나란히 실행해 대조할 때 같은 입력 파일을 읽게 하고, 원본이 이미 연결한 설정에서 새 앱이 시작할 때 `settings.json`을 바꾸지 않게 하기 위해서다.
  단 원본에서 연동을 해제한 상태라면 새 앱이 다시 연결하고, 번들 ID가 달라 `UserDefaults`가 기본값으로 시작한다. 이 병행 기간의 첫 실행 동작은 #7과 #11에서 정하며 `architecture.md`의 호환성 절에 기록했다. 이름 변경은 동등성 검증 후 별도 이슈에서 다룬다.
  병행 중 새 앱의 "Claude 연동" 해제 메뉴는 두 앱이 공유하는 훅을 제거하므로 누르지 않는다(PR 설명에 기록).
- 언어 모드(D-3 확정, 사용자가 위임): Swift 6 모드(`swift-tools-version:6.0`)를 쓴다.
  포팅이 아니라 구조를 새로 설계하며 재구현하는 단계라 엄격한 동시성을 처음부터 켜는 비용이 낮고, [Swift 코딩 컨벤션](../../rules/swift-coding-convention.md)의 `Sendable`과 actor 격리 요구를 컴파일러가 강제하게 된다.
  원본은 `async/await`, `@MainActor`, `Sendable` 없이 GCD, `NSLock`, `Timer`로 구성되어 있어 재설계가 필요하다(특히 `CodexRateLimitReader`).
  AppKit 격리 때문에 막히는 타깃은 `swiftLanguageModes`를 타깃 단위로 낮출 수 있고, 그 경우 이유를 `architecture.md`에 적는다.
- 최소 macOS(D-4 확정, 사용자가 위임): macOS 26.0을 유지한다. 원본이 쓰는 Liquid Glass(`GlassEffectContainer`, `glassEffect`, `Glass`)가 26 API이고 Liquid Glass 단계 설정이 제품 기능이다.
  `Package.swift`의 `platforms`와 `Info.plist`의 `LSMinimumSystemVersion`을 같은 값으로 맞춘다. 개발 Mac은 macOS 27.0.1, Xcode 27.1이라 최소 버전 호환은 CI(macos-26, Xcode 26.6)로 확인하고 검증 기록에 로컬 버전을 적는다.
- zstd(D-5 확정, 사용자 합의): 벤더링한 `CZstd`를 유지한다. 용도는 Claude 데스크탑 앱 캐시 응답의 해독뿐이고 쓰는 함수는 스트리밍 해독 5개(`ZSTD_createDStream`, `ZSTD_initDStream`, `ZSTD_DStreamOutSize`, `ZSTD_decompressStream`, `ZSTD_freeDStream`)다.
  사용자 환경과 외부 패키지에 의존하지 않고 CI에서 추가 설정 없이 빌드되며 원본과 같은 zstd v1.5.7을 쓰기 위해서다.
  `apps/macos/Sources/CZstd`에 해독부와 `LICENSE`를 두고 `ZSTD_DISABLE_ASM`, `DEBUGLEVEL=0` 설정을 유지한다. 이 파일은 `ai-run` 앱 코드가 아니라 제3자 라이브러리(BSD)이므로 "코드를 그대로 복사하지 않는다" 원칙의 대상이 아니다.
- 모듈 구성(D-6 확정, 사용자가 추천안을 수락): 기능별로 나눈 모듈 11개와 보조 타깃 2개를 `apps/macos/Sources` 아래에 둔다. 상세 표와 의존 도표는 `docs/architecture.md`에 쓴다.
  - 도메인 모델 `Domain`, 외부 경계 `Boundaries`, 디자인 시스템 `DesignSystem`
  - 기능 `SessionMonitoring`, `UsageMonitoring`, `ClaudeIntegration`, `TerminalIntegration`, `Preferences`
  - UI `MenuBarIcon`, `SessionPanel`
  - 앱 실행 파일 `Desktoto`, 보조 `CZstd`(C), `TestSupport`(가짜 구현)
  - 모듈 이름에는 `Desktoto` 접두어를 붙이지 않는다(패키지를 외부에 공개하지 않아 충돌 위험이 낮다).
  - 의존 규칙(컴파일러가 강제): (1) 기능 모듈끼리 서로 import하지 않고 조립은 `Desktoto` 앱만 한다. (2) UI 모듈은 `Boundaries`를 import하지 않는다. (3) `DesignSystem`은 `Domain`을 모른다. `Domain`은 의존이 없다.
  - 원본에서 `SessionWatcher`가 `TerminalJumper`를 직접 호출하던 교차 의존은, `SessionMonitoring`이 필요한 질문만 담은 프로토콜을 `Domain`에 두고 `TerminalIntegration`이 구현해 앱이 연결하는 방식으로 푼다.
- 외부 경계(D-7 확정, 사용자가 추천안을 수락): 두 개 이상의 기능이 쓰는 경계만 `Boundaries`에 프로토콜로 둔다. 프로토콜 이름에 `Protocol` 접미사는 붙이지 않는다.
  - `FileSystem`, `TimeSource`, `ProcessRunner`, `AppleScriptRunner`, `URLOpener`
  - 한 기능만 쓰는 시스템 서비스(알림 센터, 로그인 항목, 소리)는 그 기능 모듈 안에 프로토콜을 둔다. `UserDefaults`는 이미 주입 가능하므로 별도 프로토콜을 만들지 않는다.
  - 판정과 파싱은 경계에서 분리해 순수 함수로 둔다. 프로토콜은 `Sendable`로 선언하고 오래 떠 있는 프로세스의 출력은 `AsyncStream`으로 준다.
  - 테스트: 합성 데이터와 `TestSupport`의 가짜 구현(`InMemoryFileSystem`, `FixedTimeSource`, `ScriptedProcessRunner`, `RecordingAppleScriptRunner`)을 쓰고, Live 구현은 임시 폴더에서만 통합 테스트한다. 외부 앱 제어는 실제 Mac에서 수동 검증한다. 프레임워크는 현재 골격의 Swift Testing을 유지한다.
- 골격과 스크립트(D-8, D-9 확정, 사용자가 추천안을 수락):
  - 훅과 statusLine 스크립트(`ai-run-hook.sh`, `ai-run-statusline.sh`)는 `apps/macos/Resources`에 두고 앱 번들 `Contents/Resources`에 포함한 뒤 설치 시 `~/.ai-run/bin`으로 복사한다(원본과 같은 방식). 이식과 설치 로직은 #7에서 구현하고, 이 이슈에서는 방향만 정한다.
  - 골격의 각 타깃은 컴파일되는 최소 소스를 가진다. 의미 없는 테스트(항상 통과하는 단언)는 만들지 않는다. 모듈의 테스트 타깃은 그 모듈에 실제 코드가 생기는 이슈에서 코드와 함께 만든다.
  - 골격에서 `swift test`가 실제로 실행됨은 `CZstdTests`로 확인한다. 합성 zstd 프레임(매직, 단일 세그먼트 헤더, 원본 블록으로 만든 14바이트)을 `CZstd`로 해독해 원문과 비교하는 실제 테스트이고, 벤더링이 제대로 되었는지(AC-5)도 같이 확인한다. #1의 임시 `DesktotoCoreTests`는 제거한다.
- 상태와 데이터 흐름: N/A. 문서와 빌드 골격 작업이라 런타임 상태가 없다. 런타임 흐름의 원본 사실은 `overview.md`에 있다.
- 선택한 방식과 이유: 작업 순서를 "개요 문서, 결정, `architecture.md`, `Package.swift` 골격"으로 둔다.
  언어 모드, 최소 macOS, zstd, 이름이 `Package.swift`의 전제이기 때문에 결정이 끝나기 전에는 골격을 만들지 않는다.
  결정 내용 자체는 아래 "미결정 사항"에 두며, 사용자와 합의한 뒤에 확정 요구사항으로 옮긴다.
- 예외 처리: 합의되지 않은 결정은 `architecture.md`에 확정으로 적지 않고 `Package.swift`에도 반영하지 않는다.
  원본의 버그로 보이는 동작을 발견하면 옮기지 않고 이 명세의 "미결정 사항"에 기록한다.

## 완료 조건

- AC-1: `docs/reverse/overview.md`가 입력(로그, 캐시, 훅), 상태, 출력(메뉴바, 패널, 알림), 외부 의존 목록을 담고, 원본 파일과 대응된다.
- AC-2: `docs/architecture.md`가 모듈 구성(도메인 모델, 외부 경계, 기능, 디자인 시스템, 앱)과 모듈 사이의 의존 방향을 정의하고, 의존이 한 방향이며 순환이 없음을 보인다.
- AC-3: `docs/architecture.md`가 외부 경계 4종(파일 시스템, 프로세스, 시간, AppleScript)을 프로토콜 뒤에 두는 방식과 테스트 전략(대체 구현, 합성 데이터)을 기록한다.
- AC-4: `docs/architecture.md`가 Swift 언어 모드와 최소 macOS 버전을 확정해 기록한다.
- AC-5: `docs/architecture.md`가 zstd 처리 방식과 선택 이유를 기록하고, `Package.swift`가 그 결정을 반영한다.
- AC-6: `docs/architecture.md`가 앱 이름, 번들 식별자, 실행 파일명, 데이터 폴더(`~/.ai-run`) 유지 여부를 확정해 기록하고, 기존 사용자(훅 경로, 알림 권한, 로그인 항목)에 미치는 영향과 대응을 함께 적는다.
- AC-7: `apps/macos/Package.swift`와 `architecture.md`에서 정의한 타깃, 테스트 타깃 골격이 있고, `apps/macos`에서 `swift build`가 성공한다.
- AC-8: `swift test`가 테스트 타깃을 실제로 실행하고 실패 없이 끝난다. 실행된 테스트가 없다면 그 사실을 검증 기록에 밝힌다.
- AC-9: `docs/architecture.md`의 결정과 `Package.swift`의 내용(플랫폼, 타깃 이름, 의존)이 서로 일치한다.
- AC-10: 이 이슈에서 만들거나 고친 문서에 가운데점(U+00B7)이 없다.
- AC-11: `apps/macos/scripts/build-app.sh`의 기본값(`APP_NAME`, `EXECUTABLE_NAME`, `BUNDLE_ID`)과 `docs/ci.md`의 이름 설명이 확정한 이름과 일치하고, 새 골격으로 `sh scripts/build-app.sh`가 `.app`을 만들어 `codesign --verify`를 통과한다.
- AC-12: `install-app.sh`는 설치 대상에 번들 식별자가 다른 앱이 있으면 아무것도 지우지 않고 오류 종료하고, 같은 식별자이거나 대상이 없으면 기존처럼 설치한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `overview.md`의 목차와 `ai-run` 원본 파일 목록을 대조 | 입력, 상태, 출력, 외부 의존 절이 있고 원본 13개 소스 파일과 스크립트가 책임 표에 모두 있다 |
| AC-2 | `architecture.md`의 모듈 표와 의존 방향 도표를 읽고, `Package.swift`의 타깃 의존을 대조 | 요구한 5개 구분이 모두 있고 순환 의존이 없다 |
| AC-3 | `architecture.md`의 경계 절 확인 | 4종 경계마다 프로토콜 이름, 대체 방식, 테스트 방법이 있다 |
| AC-4 | `architecture.md`와 `Package.swift`의 `platforms`, `swiftLanguageModes` 대조 | 두 곳의 값이 같다 |
| AC-5 | `architecture.md`의 zstd 절과 `Package.swift`의 zstd 관련 타깃, 의존 대조. `swift test`에서 `CZstdTests` 확인 | 결정이 반영되어 있고, 벤더링을 유지하면 라이선스 파일이 남아 있다. 합성 프레임 해독 테스트가 통과한다 |
| AC-6 | `architecture.md`의 이름 절 확인 | 4가지 항목이 모두 확정되어 있고 호환성 영향 절이 있다 |
| AC-7 | `(cd apps/macos && swift build)` 실행 | 오류 없이 종료한다. 결과를 PR에 붙인다 |
| AC-8 | `(cd apps/macos && swift test)` 실행 | 실패 없이 종료하고 `CZstdTests`가 실행된다. 실행된 테스트 수를 PR에 적는다 |
| AC-9 | `architecture.md`와 `Package.swift`를 나란히 읽고 diff 검토 | 불일치 항목이 없다 |
| AC-10 | `grep -rn $'\xc2\xb7' docs/reverse docs/architecture.md docs/tasks/2` | 결과 없음 |
| AC-11 | `(cd apps/macos && sh scripts/build-app.sh)` 후 `codesign --verify`, `plutil -p`로 번들 ID 확인. 설치와 실행은 하지 않는다 | 검증 통과, `CFBundleIdentifier`가 `com.huniverse.desktoto` |
| AC-12 | 임시 `HOME` 디렉터리와 가짜 `open`, `pkill`(PATH 앞에 둠)로 `install-app.sh`를 세 경우에 실행한다: 다른 번들 ID가 설치됨, 같은 번들 ID가 설치됨, 대상 없음. 실제 `~/Applications`는 사용하지 않는다 | 첫째는 오류 종료(종료 코드 1)하고 대상 앱이 남아 있다. 나머지 둘은 설치 후 종료 코드 0 |

문서와 골격 작업이라 앱 실행과 실기기 동작 검증은 N/A다. 이유는 PR에 적는다.

## 결정 기록

D-1부터 D-12가 모두 해결되어 구현을 막는 미결정은 없다. 각 결정의 근거는 `docs/reverse/overview.md`에 있다.
"막음"은 해결 전에는 `Package.swift` 골격이나 `architecture.md` 확정을 진행할 수 없었다는 뜻이다(기록용).

| 번호 | 결정할 것 | 선택지 | 막음 여부 |
|---|---|---|---|
| D-1 | 이름 정리 | 확정됨(specRevision 2): 앱, 실행 파일, 패키지는 `Desktoto`, 번들 ID는 `com.huniverse.desktoto`. 스크립트 이름은 D-2와 함께 정한다 | 해결 |
| D-2 | 데이터 폴더 `~/.ai-run`과 스크립트 이름 | 확정됨(specRevision 3): `~/.ai-run`, `ai-run-hook.sh`, `ai-run-statusline.sh` 유지. 이름 변경은 동등성 검증 후 별도 이슈 | 해결 |
| D-3 | Swift 언어 모드 | 확정됨(specRevision 4): Swift 6 모드, `swift-tools-version:6.0`. 사용자가 판단을 위임했다 | 해결 |
| D-4 | 최소 macOS 버전 | 확정됨(specRevision 4): macOS 26.0 유지. 사용자가 판단을 위임했다 | 해결 |
| D-5 | zstd 처리 | 확정됨(specRevision 5): 벤더링 `CZstd` 유지. Claude 데스크탑 앱 캐시 해독(`ClaudeDesktopUsage.swift`)용이다 | 해결 |
| D-6 | 모듈 구성안 | 확정됨(specRevision 6): 설계 결정의 "모듈 구성" 참고. 사용자가 추천안을 수락했다 | 해결 |
| D-7 | 외부 경계 프로토콜 설계 | 확정됨(specRevision 7): 설계 결정의 "외부 경계" 참고. 사용자가 추천안을 수락했다 | 해결 |
| D-8 | 훅과 statusLine 스크립트의 위치 | 확정됨(specRevision 8): 설계 결정의 "골격과 스크립트" 참고 | 해결 |
| D-9 | 골격에 스모크 테스트 포함 여부 | 확정됨(specRevision 8): 설계 결정의 "골격과 스크립트" 참고. 사용자가 추천안을 수락했고 추천 내용을 구체화했다 | 해결 |
| D-10 | 이슈 #2 본문 보완 | 확정됨(specRevision 8): 이슈 본문은 이번 작업에서 수정하지 않는다. 완료한 항목의 체크는 PR을 올리기 전에 사용자에게 확인받고 한다 | 해결 |
| D-11 | 번들과 빌드 방식 | 해결: #1에서 `build-app.sh`(빌드, 서명)와 `install-app.sh`(설치, 실행)로 분리했다. 이 이슈는 이름 기본값만 갱신한다 | 해결 |
| D-12 | 패키지 위치 | 해결: #1에서 확정한 모노레포 구조에 따라 `apps/macos/Package.swift`. 이 이슈는 #1의 임시 골격을 교체한다 | 해결 |

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 이슈 #2의 작업 목록과 `overview.md` 조사 결과를 바탕으로 정리. 결정 항목은 사용자와 합의 전이므로 미결정으로 둔다 |
| 2 | D-1 확정, 패키지 위치를 `apps/macos`로 변경, AC-11 추가, D-2에 병행 설치 고려 추가 | 사용자가 이름 결정에 합의했고, #1이 병합되어 모노레포 구조와 임시 골격, 패키징 스크립트가 들어왔다. 영향받는 AC: AC-7, AC-8, AC-11 |
| 3 | D-2 확정(`~/.ai-run`과 스크립트 이름 유지), 제외 항목에 설치된 `ai-run` 앱과 사용자 설정 불변 조건 추가 | 동작을 원본과 같게 하고 동등성 검증 입력을 맞추기 위해 사용자가 합의했다. 영향받는 AC: AC-6(이름 항목에 데이터 폴더와 스크립트가 유지로 기록됨) |
| 4 | D-3 확정(Swift 6 모드, tools-version 6.0), D-4 확정(macOS 26.0 유지) | 사용자가 두 결정을 위임했다. 영향받는 AC: AC-4, AC-7, AC-9 |
| 5 | D-5 확정(벤더링 `CZstd` 유지) | 사용자가 합의했다. 영향받는 AC: AC-5, AC-9 |
| 6 | D-6 확정(기능별 모듈 11개, 접두어 없는 이름, 의존 규칙 3가지) | 사용자가 추천안을 수락했다. 영향받는 AC: AC-2, AC-9 |
| 7 | D-7 확정(`Boundaries` 프로토콜 5개, 단일 기능 서비스는 해당 모듈에 배치, 테스트 전략) | 사용자가 추천안을 수락했다. 영향받는 AC: AC-3 |
| 8 | D-8, D-9, D-10 확정. D-9는 "각 테스트 타깃에 최소 1개"에서 "실제 코드가 있는 `CZstdTests`만 골격에 둔다"로 구체화 | 사용자가 추천안을 수락했다. 항상 통과하는 의미 없는 테스트를 만들지 않고 실제 동작하는 코드만 쓰려는 원칙에 맞췄다. 영향받는 AC: AC-5, AC-8 |
| 9 | 리뷰 반영: `CZstdTests`에 압축 블록 프레임 케이스를 추가(AC-5, AC-8 확인 강화), D-2의 병행 기간 설명 정정(UserDefaults 초기화와 자동 재연결), `apps/web`을 제외에 명시, AC-11 표 서식과 제목 정정 | 코드 리뷰(PR #14)에서 원본 블록 프레임만으로는 해독 경로가 검증되지 않고, "시작 시 settings.json을 바꾸지 않는다"는 서술이 조건부로만 맞는다는 지적을 확인했다. 영향받는 AC: AC-5, AC-6, AC-8, AC-11 |
| 10 | `install-app.sh`의 덮어쓰기 방지 확인을 이 이슈에 포함하고 AC-12를 추가 | 리뷰 지적 CR-001에서 새 앱 이름이 설치된 원본 앱과 같아 충돌하는 경로가 이 이슈의 이름 결정으로 생겼다. 사용자가 이 PR에 넣기로 했다. 영향받는 AC: AC-12 |
