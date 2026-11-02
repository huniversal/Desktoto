# 작업 명세: [Chore] 아키텍처 및 프로젝트 골격 세팅

## 연결 정보

- 이슈: #2 / https://github.com/huniversal/Desktoto/issues/2
- 브랜치: `feat/architecture-setup/#2`
- specRevision: 1
- 대상 ai-run 원본: 전체
  - `~/Desktop/ai-run/Package.swift`
  - `~/Desktop/ai-run/Sources/AiRun/*.swift` (13개 파일)
  - `~/Desktop/ai-run/Sources/CZstd`
  - `~/Desktop/ai-run/scripts/*` (`Info.plist`, `ai-run-hook.sh`, `ai-run-statusline.sh`, `build-app.sh`)
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
- `Package.swift`와 타깃, 테스트 타깃 골격 생성

### 제외

- 기능 구현 (세션 감시, 사용량, 연동, UI 등은 #3 이후 이슈)
- 디자인 토큰과 컴포넌트 구현 (#3)
- CI와 앱 패키징, 서명 (#1)
- 기능별 상세 동작 문서화의 보완 (`overview.md` 9장에 적은 항목은 해당 기능 이슈에서)
- 린터, 포맷터, Git 훅 도입 (합의 전까지 추가하지 않음)
- 앱 소스 폴더 구조 중 `architecture.md`에서 확정하지 않은 부분

## 설계 결정

- 파일 구조와 로직의 책임:
  - `docs/reverse/overview.md`: 원본에서 확인한 사실만 기록한다(설계 없음).
  - `docs/architecture.md`: 이 이슈에서 내린 결정과 그 이유를 기록한다. 이후 이슈의 전제가 된다.
  - `Package.swift`와 `Sources`, `Tests`의 빈 골격: `architecture.md`의 결정을 그대로 반영한다. 로직은 담지 않는다.
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
- AC-7: `Package.swift`와 `architecture.md`에서 정의한 타깃, 테스트 타깃 골격이 있고, `swift build`가 성공한다.
- AC-8: `swift test`가 테스트 타깃을 실제로 실행하고 실패 없이 끝난다. 실행된 테스트가 없다면 그 사실을 검증 기록에 밝힌다.
- AC-9: `docs/architecture.md`의 결정과 `Package.swift`의 내용(플랫폼, 타깃 이름, 의존)이 서로 일치한다.
- AC-10: 이 이슈에서 만들거나 고친 문서에 가운데점(U+00B7)이 없다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `overview.md`의 목차와 `ai-run` 원본 파일 목록을 대조 | 입력, 상태, 출력, 외부 의존 절이 있고 원본 13개 소스 파일과 스크립트가 책임 표에 모두 있다 |
| AC-2 | `architecture.md`의 모듈 표와 의존 방향 도표를 읽고, `Package.swift`의 타깃 의존을 대조 | 요구한 5개 구분이 모두 있고 순환 의존이 없다 |
| AC-3 | `architecture.md`의 경계 절 확인 | 4종 경계마다 프로토콜 이름, 대체 방식, 테스트 방법이 있다 |
| AC-4 | `architecture.md`와 `Package.swift`의 `platforms`, `swiftLanguageModes` 대조 | 두 곳의 값이 같다 |
| AC-5 | `architecture.md`의 zstd 절과 `Package.swift`의 zstd 관련 타깃, 의존 대조 | 결정이 반영되어 있고, 벤더링을 유지하면 라이선스 파일이 남아 있다 |
| AC-6 | `architecture.md`의 이름 절 확인 | 4가지 항목이 모두 확정되어 있고 호환성 영향 절이 있다 |
| AC-7 | `swift build` 실행 | 오류 없이 종료한다. 결과를 PR에 붙인다 |
| AC-8 | `swift test` 실행 | 실패 없이 종료한다. 실행된 테스트 수를 PR에 적는다 |
| AC-9 | `architecture.md`와 `Package.swift`를 나란히 읽고 diff 검토 | 불일치 항목이 없다 |
| AC-10 | `grep -rn $'\xc2\xb7' docs/reverse docs/architecture.md docs/tasks/2` | 결과 없음 |

문서와 골격 작업이라 앱 실행과 실기기 동작 검증은 N/A다. 이유는 PR에 적는다.

## 미결정 사항

아래는 사용자와 합의하기 전까지 확정 요구사항이 아니다. 각 항목의 근거는 `docs/reverse/overview.md`에 있다.
"막음"은 해당 결정 전에는 `Package.swift` 골격이나 `architecture.md` 확정을 진행할 수 없다는 뜻이다.

| 번호 | 결정할 것 | 선택지 | 막음 여부 |
|---|---|---|---|
| D-1 | 이름 정리 | 앱 이름은 `Desktoto`(`CFBundleName`)로 통일할지, 번들 ID는 `com.huniverse.airun` 유지 또는 변경, 실행 파일은 `AiRun`에서 변경 여부. 번들 ID를 바꾸면 알림 권한, 로그인 항목, 자동화 권한이 초기화된다 | 막음. #1의 패키징도 이 값에 의존 |
| D-2 | 데이터 폴더 `~/.ai-run` | 유지, 새 경로로 변경, 변경하고 구 경로 병행 읽기 또는 마이그레이션. 사용자의 `~/.claude/settings.json`에 이미 기록된 훅과 statusLine 명령이 구 경로를 가리킨다 | 막음 |
| D-3 | Swift 언어 모드 | Swift 5 모드 또는 Swift 6 모드(엄격한 동시성). 원본은 `swift-tools-version:5.9` | 막음 |
| D-4 | 최소 macOS 버전 | 원본과 같이 26 이상 유지(Liquid Glass 사용) 또는 낮춤 | 막음 |
| D-5 | zstd 처리 | 벤더링 `CZstd` 유지, 시스템 `libzstd`, 외부 Swift 패키지. Claude 데스크탑 앱 캐시 해독(`ClaudeDesktopUsage.swift`)용이다 | 막음 |
| D-6 | 모듈 구성안 | 도메인 모델, 외부 경계, 기능, 디자인 시스템, 앱을 어떤 타깃으로 나누고 어떤 방향으로 의존시킬지 | 막음 |
| D-7 | 외부 경계 프로토콜 설계 | 파일 시스템, 프로세스, 시간, AppleScript 각각의 프로토콜 범위와 대체 구현 방식, 합성 데이터 테스트 전략 | 막음 |
| D-8 | 훅과 statusLine 스크립트의 위치 | 앱 번들 리소스로 포함하고 설치 시 복사하는 방식 등. 구현은 #7에서 하되 방향은 이 이슈에서 정하는 것이 좋다 | 막지 않음 (`architecture.md`에 방향만 기록) |
| D-9 | 골격에 스모크 테스트 포함 여부 | 각 테스트 타깃에 최소 테스트 1개를 두어 `swift test`가 실제로 실행됨을 확인할지, 빈 타깃만 둘지 | 막지 않음 |
| D-10 | 이슈 #2 본문 보완 | 마이그레이션 여부, 언어 모드 문구 구체화, 스크립트 위치, 작업 순서를 이슈 본문에 반영할지 | 막지 않음 |
| D-11 | 번들과 빌드 방식 | 원본의 `scripts/build-app.sh`(ad hoc 서명, `~/Applications` 설치) 방식의 유지 여부. 패키징 세부는 #1과 경계를 정한다 | 막지 않음 |

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 이슈 #2의 작업 목록과 `overview.md` 조사 결과를 바탕으로 정리. 결정 항목은 사용자와 합의 전이므로 미결정으로 둔다 |
