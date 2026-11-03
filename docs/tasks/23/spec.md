# 작업 명세: [Deploy] Homebrew cask 배포 구성

## 연결 정보

- 이슈: #23 / https://github.com/huniversal/Desktoto/issues/23
- 브랜치: feat/homebrew-cask/#23
- specRevision: 2
- 대상 ai-run 원본: N/A (배포 작업이며 제품 동작은 바꾸지 않는다)

## 목적

사용자가 터미널에서 `brew install --cask huniversal/tap/desktoto` 한 줄로 앱을 설치하고 `brew upgrade`로 갱신할 수 있게 한다.
Apple Developer 서명과 공증 없이 배포하므로, 내려받은 앱이 처음 실행할 때 막히는 문제를 설치 단계에서 피해야 한다.
터미널이 낯선 사용자를 위해 릴리스 zip 수동 설치 방법도 README에 둔다.

선행 조건: 앱 조립(#11)이 `main`까지 반영되어 릴리스 태그를 만들 수 있어야 한다. 실제 설치 검증(AC-3)은 이 조건이 충족된 뒤에 가능하다.

## 작업 범위

### 포함

- 자체 tap 저장소 `huniversal/homebrew-tap` 생성과 cask 파일(`Casks/desktoto.rb`) 작성
  - 릴리스 zip 주소, sha256, `Desktoto.app` 설치, 설치 후 격리 속성 제거
  - zip 이름 규칙은 [release.yml](../../../.github/workflows/release.yml)이 만드는 `Desktoto-버전.zip`을 따른다.
- 릴리스마다 tap의 버전과 해시를 자동 갱신하는 워크플로 추가 (tap 저장소에 쓰는 권한 방식 결정 포함)
- 깨끗한 환경에서 설치, 실행, 업그레이드, 삭제 확인 (macOS 26에서 경고 없이 열리는지 포함)
- [README.md](../../../README.md) 설치 항목에 Homebrew 명령과 릴리스 zip 수동 설치 방법 추가
- [docs/ci.md](../../ci.md) 릴리스 절 갱신, [install-app.sh](../../../apps/macos/scripts/install-app.sh)의 병행 기간 보호 문구 정리 여부 판단

### 제외

- Apple Developer 서명과 공증
- 자동 업데이트
- 공식 homebrew-cask 등록
- 새 버전 알림 (#24)
- 랜딩 페이지의 설치 안내 (#28). 이 작업에서 명령과 릴리스 zip 주소가 확정되면 #28에서 쓴다.

## 설계 결정

- 파일 구조와 로직의 책임:
  - `huniversal/homebrew-tap` 저장소: `Casks/desktoto.rb`가 설치 정의를 맡는다.
  - Desktoto 저장소: 릴리스 워크플로가 zip과 sha256을 만들고, 그 결과를 tap에 반영하는 단계 또는 워크플로를 둔다.
  - 해시는 릴리스 워크플로가 이미 만드는 `.sha256` 파일 값을 쓴다. 별도로 다시 내려받아 계산하지 않는 방식을 우선 검토한다.
- 상태와 데이터 흐름: 태그 push, 릴리스 생성, tap의 `version`과 `sha256` 갱신 커밋, `brew upgrade`로 반영.
- 선택한 방식과 이유: 공식 homebrew-cask가 아니라 자체 tap을 쓴다. 서명과 공증이 없는 앱은 공식 등록 대상이 아니며, 이슈에서 범위 밖으로 정했다.
- 격리 속성 제거 (specRevision 2에서 확정): cask의 `postflight_steps`에서 `xattr -dr com.apple.quarantine`을 실행한다.
  - Homebrew 7.0.6에서 옛 `postflight` 블록은 deprecated 경고가 나므로 쓰지 않는다.
  - 경로 치환 토큰은 `{{appdir}}`이다. `#{appdir}`는 치환되지 않아 설치가 실패한다.
  - 확인한 형태:

    ```ruby
    postflight_steps do
      run "/usr/bin/xattr",
          args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Desktoto.app"],
          writable_paths: ["{{appdir}}/Desktoto.app"]
    end
    ```
- tap 신뢰: Homebrew 6.0부터 비공식 tap은 신뢰가 필요하다. 전체 이름(`brew install --cask huniversal/tap/desktoto`)으로 설치하면 해당 cask만 자동 신뢰되므로 설치 명령은 한 줄로 유지된다. 짧은 이름으로 설치하려면 `brew trust`가 필요하므로 README에는 전체 이름만 쓴다.
- 예외 처리:
  - 프리릴리스 태그(`-rc.1` 등)를 tap에 반영할지는 미결정 사항이다.
  - tap 갱신이 실패해도 GitHub Release 자체는 유지되어야 하며, 실패는 워크플로 결과에 드러나야 한다.

## 완료 조건

- AC-1: `huniversal/homebrew-tap`에 `Casks/desktoto.rb`가 있고, 릴리스 zip 주소, sha256, `Desktoto.app` 설치, 설치 후 격리 속성 제거가 정의되어 있다.
- AC-2: 새 릴리스가 생성되면 tap의 `version`과 `sha256`이 사람 개입 없이 갱신된다. tap에 쓰는 권한 방식이 정해지고 `docs/ci.md`에 기록되어 있다.
- AC-3: 깨끗한 환경에서 `brew install --cask huniversal/tap/desktoto`로 설치한 앱이 macOS 26에서 Gatekeeper 경고 없이 실행된다.
- AC-4: `brew upgrade`로 새 버전이 설치되고, `brew uninstall --cask desktoto`로 삭제된다.
- AC-5: README 설치 항목에 Homebrew 명령과 릴리스 zip 수동 설치 방법이 있다. zip 수동 설치 방법은 격리 속성 때문에 막힐 때의 해결 방법을 포함한다.
- AC-6: `docs/ci.md` 릴리스 절이 tap 갱신 흐름을 반영한다. `install-app.sh` 병행 기간 보호 문구는 유지 또는 정리 중 하나로 판단하고 이유가 PR에 기록되어 있다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `brew audit --cask --online huniversal/tap/desktoto`, cask 파일 diff 검토 | 오류 없음. 미통과 항목은 원인을 기록 |
| AC-2 | 프리릴리스 태그로 릴리스 워크플로를 실행해 tap 커밋 생성 여부 확인 | tap에 올바른 버전과 해시의 커밋이 생김 |
| AC-3 | 깨끗한 환경(새 사용자 계정 또는 Homebrew와 앱을 지운 Mac)에서 설치 후 Finder 또는 `open`으로 실행. macOS와 Homebrew 버전 기록 | 경고 없이 메뉴바에 앱이 뜬다 |
| AC-4 | 낮은 버전 설치 후 새 버전을 릴리스하고 `brew update && brew upgrade --cask desktoto`, 이후 `brew uninstall --cask desktoto` | 버전이 바뀌고, 삭제 후 `/Applications/Desktoto.app`이 없다 |
| AC-5 | README diff 검토, zip 수동 설치 절차를 그대로 따라 실행 | 문서대로 따라 하면 앱이 열린다 |
| AC-6 | `docs/ci.md` diff 검토, 링크 점검 | 릴리스 절이 실제 워크플로와 일치한다 |

## 미결정 사항

- 격리 속성 제거의 한계: macOS 27.0.1, Homebrew 7.0.6에서 `localhost` 서버로 받은 zip으로 설치와 실행을 확인했다(격리 속성 0개, 앱 정상 실행).
  격리 속성이 붙은 채로 막히는지 대조 실험은 하지 않았고, 실제 GitHub Release 다운로드와 macOS 26에서의 확인은 첫 릴리스 후 AC-3에서 한다. 구현을 막지 않는다.
- tap 쓰기 권한 방식: fine-grained PAT, GitHub App, deploy key 중 선택. tap 저장소 하나에만 contents 쓰기 권한을 주는 최소 권한을 기준으로 정한다. 구현을 막지 않지만 AC-2 전에 정한다.
- 프리릴리스(`-rc.N`) 태그를 tap에 반영할지 여부. 반영하지 않는 쪽을 기본으로 제안하며 합의 전이다.
- tap 저장소 공개 여부와 기본 브랜치 보호 설정. 합의 전이다.
- 자체 tap이 Homebrew 공식 설치 통계에 나오는지는 미확인이다. 다운로드 수는 GitHub Release의 `download_count`로 본다(brew와 zip 직접 설치가 합산되고 사람 수가 아닌 내려받은 횟수).

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 이슈 #23의 Tasks와 범위를 그대로 옮김. 미결정 항목은 확정하지 않음 |
| 2 | 격리 속성 제거를 `postflight_steps`와 `{{appdir}}` 토큰으로 확정, tap 신뢰는 전체 이름 설치로 해소 | Homebrew 7.0.6, macOS 27.0.1에서 로컬 확인. 영향받는 AC: AC-1, AC-3, AC-5 |
