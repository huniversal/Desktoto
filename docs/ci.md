# CI와 릴리스 운영

모노레포(`apps/macos`, `apps/web`)를 [하나의 GitHub Actions 워크플로](../.github/workflows/ci.yml)로 검증하고,
태그 push로 [릴리스 워크플로](../.github/workflows/release.yml)를 실행한다.
구조는 ttak-workspace의 CI를 참고했고, Node 기반 보조 도구 없이 셸 스크립트로 단순하게 유지한다.
코드 포맷터와 린터 검사는 도입 합의 전이라 포함하지 않는다.

## CI 실행 조건과 검사

`main`, `develop` 대상 PR의 생성, 추가 커밋, 다시 열기에서 실행한다. 같은 PR의 새 실행은 이전 실행을 취소한다.
기본 checkout 동작으로 PR 브랜치와 대상 브랜치의 임시 merge commit을 검사한다. 모든 job은 저장소 읽기 권한만 쓴다.

| 검사 이름 | 환경 | 실행 내용 | 제한 시간 |
| --- | --- | --- | --- |
| `Changes` | Ubuntu 24.04 | PR 전체 변경을 분류해 검사 대상 결정 | 5분 |
| `macOS Build` | macOS 26, Xcode 26.6 | `apps/macos`에서 `swift build`, `swift test`, 앱 번들 패키징 | 20분 |
| `CI Result` | Ubuntu 24.04 | 선택된 job의 결과를 하나로 취합 | 5분 |

`Web` job은 랜딩 스택이 정해지는 #12에서 추가한다. 변경 감지는 이미 `web` 플래그를 출력한다.

## 변경 감지

[detect-changes.sh](../.github/scripts/detect-changes.sh)가 PR의 merge-base부터 head까지 전체 변경을 읽는다.
마지막 커밋만 보지 않으며, 이동한 파일은 이전 경로와 새 경로를 모두 분류한다.
Git 실패나 입력 누락은 스크립트 실패이고, 그 결과 `CI Result`도 실패한다.

| 변경 경로 | 실행할 검사 |
| --- | --- |
| `apps/macos/*` | macOS Build |
| `apps/web/*` | Web (job 추가 전에는 플래그만 출력) |
| `.github/workflows/*`, `.github/scripts/*` | 전체 |
| `docs/*`, `.agents/*`, `.claude/*`, `.github` 아래의 나머지 파일, `AGENTS.md`, `CLAUDE.md`, `README.md`, `.gitignore` | 검사 생략 |
| 위에 없는 모든 경로 | 전체 (생략하지 않고 안전하게 검사) |

여러 대상이 바뀌면 합집합을 실행한다. 선택 결과는 Actions의 step summary에 표로 남는다.
새 최상위 경로를 추가하면 이 표와 스크립트의 분류를 함께 갱신한다.

## 결과 취합

[check-result.sh](../.github/scripts/check-result.sh)는 `toJSON(needs)`를 읽어 판정한다.

- 변경 감지는 `success`여야 하고 `macos`, `web` 플래그는 정확히 `true` 또는 `false`여야 한다.
- 선택된 job은 `success`여야 한다. 실패, 취소, 예상 밖 생략, 결과 누락은 실패다.
- 선택되지 않은 job은 `skipped`여야 한다.
- 문서만 바꿔 모든 검사를 생략해도 감지 성공과 의도된 생략을 확인한 뒤 통과한다.

워크플로 전체에 경로 필터를 두지 않고 job을 조건부로 실행한다. 그래서 필수 검사가 영원히 대기하는 일이 없다.
필수 검사로 연결할 이름은 `CI Result` 하나다. 브랜치 보호 규칙은 아직 적용하지 않았고, `CI Result`가 한 번 성공한 뒤 적용한다.

## 환경과 버전

- 러너는 `macos-26`이고 Xcode는 `DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer`로 고정한다.
  러너 이미지에서 이 Xcode가 사라지면 환경 확인 단계가 실패한다.
  [macOS 26 러너 설치 목록](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)을 확인한다.
- `actions/checkout`은 v7.0.1을 전체 커밋 SHA로 고정했다. 갱신할 때 공식 태그와 변경 내용을 확인하고 SHA와 버전 주석을 함께 바꾼다.
- 의존성 캐시는 쓰지 않는다. 외부 패키지가 생기면 캐시를 검토한다.

## 앱 패키징

[build-app.sh](../apps/macos/scripts/build-app.sh)는 릴리스 빌드, 번들 구성, 아이콘 생성, ad-hoc 서명과 검증까지만 한다.
설치와 실행은 로컬 개발용 [install-app.sh](../apps/macos/scripts/install-app.sh)가 따로 맡는다.

```bash
cd apps/macos
sh scripts/build-app.sh
sh scripts/install-app.sh
```

값은 환경 변수로 바꾼다: `APP_NAME`, `EXECUTABLE_NAME`, `BUNDLE_ID`, `VERSION`, `BUILD_NUMBER`, `RESOURCES_DIR`.
`Info.plist`는 `__APP_NAME__` 같은 자리 표시자가 있는 템플릿이다. 앱 이름과 번들 식별자는 #2에서 확정하며,
그때 스크립트 기본값만 바꾸면 된다. `RESOURCES_DIR`를 지정하면 그 폴더가 번들의 `Contents/Resources`로 복사된다(훅 스크립트 포함은 #7).

## 릴리스

`v1.2.3` 또는 `v1.2.3-rc.1` 형식의 태그를 push하면 실행한다. 다른 형식의 태그는 실패한다.
`-rc.1` 같은 접미사가 있으면 프리릴리스로 올린다.

1. `main`에서 태그를 만든다: `git tag v1.0.0 && git push origin v1.0.0`
2. 워크플로가 `swift test`, 앱 패키징, zip 생성, SHA-256 체크섬 생성을 하고 GitHub Release에 올린다.
3. 릴리스 노트는 자동 생성한다.

산출물은 `Desktoto-버전.zip`과 `.sha256` 파일이다. 서명은 ad-hoc이라 다운로드한 앱은 처음 실행할 때
Gatekeeper 경고가 나오며, 공증은 하지 않는다. 릴리스 job만 저장소 쓰기 권한(`contents: write`)을 쓴다.

## 로컬 확인

```bash
# 빌드와 테스트
cd apps/macos && swift build && swift test

# 변경 감지 (base와 head 커밋을 지정)
BASE_SHA=$(git merge-base origin/develop HEAD) HEAD_SHA=HEAD bash .github/scripts/detect-changes.sh

# 결과 취합 (실패 입력 예시, 종료 코드 1)
NEEDS_JSON='{"changes":{"result":"success","outputs":{"macos":"true","web":"false"}},"macos-build":{"result":"failure"}}' \
  bash .github/scripts/check-result.sh
```

실패한 PR 검사는 상세 로그에서 실패 단계와 종료 코드를 먼저 확인한다. 코드 문제는 수정 커밋으로 다시 검사하고,
일시적인 러너 장애일 때만 재실행한다. 실패를 무시하는 설정으로 우회하지 않는다.

## 후속 작업

- Web job: #12에서 랜딩 스택을 정한 뒤 추가하고 `check-result.sh`에 `check_job web web`을 더한다.
- 브랜치 보호: `main`, `develop`에 PR 필수와 `CI Result` 필수 검사를 적용한다.
- 코드 서명 인증서와 공증, 자동 업데이트.
