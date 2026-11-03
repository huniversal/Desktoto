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
| `Web` | Ubuntu 24.04 | `check-web.sh`로 `apps/web`의 필수 파일, 문서 틀, 파비콘 연결, 링크 미리보기 주소와 이미지 크기 검사 | 5분 |
| `CI Result` | Ubuntu 24.04 | 선택된 job의 결과를 하나로 취합 | 5분 |

`Web` 검사는 빌드 없이 셸 스크립트만 쓴다. 배포 도메인을 바꾸면 [check-web.sh](../.github/scripts/check-web.sh)의 `SITE_ORIGIN`도 함께 바꾼다.

## 변경 감지

[detect-changes.sh](../.github/scripts/detect-changes.sh)가 PR의 merge-base부터 head까지 전체 변경을 읽는다.
마지막 커밋만 보지 않으며, 이동한 파일은 이전 경로와 새 경로를 모두 분류한다.
Git 실패나 입력 누락은 스크립트 실패이고, 그 결과 `CI Result`도 실패한다.

| 변경 경로 | 실행할 검사 |
| --- | --- |
| `apps/macos/*` | macOS Build |
| `apps/web/*` | Web |
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
필수 검사로 연결한 이름은 `CI Result` 하나다. 적용한 규칙은 [브랜치 보호](#브랜치-보호)에 기록했다.

## 환경과 버전

- 러너는 `macos-26`이고 Xcode는 `DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer`로 고정한다.
  러너 이미지에서 이 Xcode가 사라지면 환경 확인 단계가 실패한다.
  [macOS 26 러너 설치 목록](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)을 확인한다.
- `actions/checkout`은 v7.0.1을 전체 커밋 SHA로 고정했다. 갱신할 때 공식 태그와 변경 내용을 확인하고 SHA와 버전 주석을 함께 바꾼다.
- 의존성 캐시는 쓰지 않는다. 외부 패키지가 생기면 캐시를 검토한다.

## 브랜치 보호

저장소 설정(Settings, Rules, Rulesets)의 `protect-main-develop` 룰셋(ID 26367609)을 `main`과 `develop`에 적용했다.
이 설정은 저장소 파일이 아니라 GitHub에 있으므로 바꾸면 이 표도 함께 갱신한다.

| 규칙 | 값 |
| --- | --- |
| PR 필수 | 승인 인원 0명 (1인 저장소), 병합 방식은 Merge commit만 허용, 리뷰 스레드 해결은 강제하지 않음 |
| 필수 상태 검사 | `CI Result` (GitHub Actions), 최신 base 반영은 강제하지 않음 |
| 브랜치 삭제와 force push | 차단 |
| bypass 권한자 | 없음 (관리자도 우회 불가) |

보호 대상은 두 브랜치뿐이라 `feat/*` 브랜치는 자유롭게 push하고 force push할 수 있다.
`.github/**` 파일만 따로 보호하는 규칙은 두지 않았다. PR의 CI 정의 변경은 PR 필수와 `CI Result`로만 걸러지며,
워크플로 파일도 PR의 merge commit에서 읽히므로 이 보호에는 한계가 있다.

## 앱 패키징

[build-app.sh](../apps/macos/scripts/build-app.sh)는 릴리스 빌드, 번들 구성, 아이콘 생성, ad-hoc 서명과 검증까지만 한다.
설치와 실행은 로컬 개발용 [install-app.sh](../apps/macos/scripts/install-app.sh)가 따로 맡는다.

```bash
cd apps/macos
sh scripts/build-app.sh
sh scripts/install-app.sh
```

> 주의: `install-app.sh`는 `~/Applications/<앱 이름>.app`을 지우고 덮어쓴다. 대상 경로에 번들 식별자가 다른 앱이 이미 있으면(예: 같은 이름 `Desktoto.app`으로 설치된 원본 `ai-run` 앱)
> 아무것도 지우지 않고 오류로 중단한다. 이 기간에는 `build-app.sh`만 실행하고 `apps/macos/build/Desktoto.app`을 직접 연다.

값은 환경 변수로 바꾼다: `APP_NAME`, `EXECUTABLE_NAME`, `BUNDLE_ID`, `VERSION`, `BUILD_NUMBER`, `RESOURCES_DIR`.
`Info.plist`는 `__APP_NAME__` 같은 자리 표시자가 있는 템플릿이다. 앱 이름과 번들 식별자는 #2에서 확정했고(`Desktoto`, `com.huniverse.desktoto`),
스크립트 기본값이 이 값이다. 원본 `ai-run` 앱(`com.huniverse.airun`)과 별개의 앱으로 취급되도록 원본과 다른 번들 식별자를 유지한다. `RESOURCES_DIR`를 지정하면 그 폴더가 번들의 `Contents/Resources`로 복사된다(훅 스크립트 포함은 #7).

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
# 빌드와 테스트 (서브셸에서 실행해 현재 위치를 바꾸지 않는다)
(cd apps/macos && swift build && swift test)

# 아래 명령은 저장소 루트에서 실행한다
# 랜딩 페이지 검사
bash .github/scripts/check-web.sh

# 변경 감지 (base와 head 커밋을 지정)
BASE_SHA=$(git merge-base origin/develop HEAD) HEAD_SHA=HEAD bash .github/scripts/detect-changes.sh

# 결과 취합 (실패 입력 예시, 종료 코드 1)
NEEDS_JSON='{"changes":{"result":"success","outputs":{"macos":"true","web":"false"}},"macos-build":{"result":"failure"}}' \
  bash .github/scripts/check-result.sh
```

실패한 PR 검사는 상세 로그에서 실패 단계와 종료 코드를 먼저 확인한다. 코드 문제는 수정 커밋으로 다시 검사하고,
일시적인 러너 장애일 때만 재실행한다. 실패를 무시하는 설정으로 우회하지 않는다.

## 후속 작업

- 코드 서명 인증서와 공증, 자동 업데이트.
