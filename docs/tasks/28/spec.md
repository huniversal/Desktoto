# 작업 명세: [Feat] 랜딩 페이지 설치 안내 추가

## 연결 정보

- 이슈: #28 / https://github.com/huniversal/Desktoto/issues/28
- 브랜치: feat/landing-install/#28
- specRevision: 1
- 대상 ai-run 원본: N/A (원본에 없는 랜딩 페이지 작업이다)

## 목적

일반 사용자가 랜딩 페이지에서 바로 앱을 설치하게 한다. 히어로에 다운로드 버튼을 두어 `.dmg`를 바로 받게 하고, 하단에 Homebrew 명령과 dmg 설치 방법을 안내한다.
서명과 공증이 없는 앱이라 처음 실행할 때 경고가 나오므로, 하단 안내에 해결 방법을 함께 적는다. 앱이 Apple Silicon 전용이므로 요구 사항을 정직하게 표기한다.

선행 조건: Homebrew cask 배포 구성(#23)이 `develop`에 반영되어 명령과 격리 속성 해결 방법이 확정되어 있다.

## 작업 범위

### 포함

- 히어로의 주 버튼 "macOS용 다운로드": `https://github.com/huniversal/Desktoto/releases/latest/download/Desktoto.dmg`를 연다. 기존 "GitHub에서 보기"는 보조 버튼으로 바꾼다. 버튼 아래에 요구 사항(macOS 26 이상, Apple Silicon)을 한 줄로 적는다.
- 상단 내비게이션에 "설치" 링크(`#install`) 추가.
- 개인정보 섹션과 푸터 사이에 "설치 방법" 섹션(`#install`) 추가:
  - Homebrew: `brew install --cask huniversal/tap/desktoto`를 코드 블록으로 보여 주고 복사 버튼을 둔다(복사 후 "복사됨" 표시). 설치 직후 경고 없이 열린다는 설명과, 갱신(`brew upgrade`)과 삭제 명령.
  - dmg 설치: 번호가 붙은 단계(dmg 열기, `응용 프로그램`으로 드래그, 처음 열 때 경고 닫기, 시스템 설정의 `그래도 열기`, 다시 열기)와 터미널 대안(`xattr -dr com.apple.quarantine /Applications/Desktoto.app`).
  - "경고 창은 왜 뜨나요?" 안내: 개인이 무료로 만든 앱이라 Apple 유료 개발자 인증(서명과 공증)이 없고, 처음 한 번만 하면 되며, 새 버전은 앱이 알려 준다.
- 새 문구는 한국어와 영어를 모두 추가한다(`data-i18n`과 영어 사전).
- 개인정보 섹션에 새 버전 확인 문구를 추가한다(#24 이후 앱이 GitHub에서 최신 릴리스 정보를 읽는다. 보내는 정보는 없고 메뉴에서 끌 수 있다). 한국어와 영어 모두.
- 릴리스 워크플로(`.github/workflows/release.yml`)에서 dmg를 만들어 `Desktoto.dmg`와 `Desktoto.dmg.sha256`을 릴리스에 올린다. 기존 zip과 `update-tap`은 그대로 둔다.
- `.github/scripts/check-web.sh`에 `#install` 섹션과 dmg 다운로드 링크 존재 검사를 추가한다.
- README 설치 절에 dmg 방법과 Apple Silicon 요구 사항을 반영하고, `docs/ci.md` 릴리스 산출물에 dmg를 추가한다.

### 제외

- 커스텀 도메인, 디자인 전체 개편
- Apple Developer 서명과 공증
- Intel Mac 지원(유니버설 빌드). 별도 작업으로 다룬다.

## 설계 결정

- 파일 구조와 로직의 책임:
  - `apps/web/index.html` 한 파일에 마크업, 스타일, 스크립트를 둔다(빌드 단계가 없는 기존 구조 유지). 기존 토큰(`--btn-bg`, `--line` 등)과 `.btn`, `.btn.ghost`를 재사용하고 새 스타일은 기존 방식대로 같은 `<style>`에 추가한다.
  - 복사 버튼은 `navigator.clipboard.writeText`를 쓰고, 성공하면 버튼 문구를 잠시 "복사됨"으로 바꾼다. 문구는 현재 언어에 맞춘다.
  - dmg 생성은 릴리스 워크플로의 별도 단계로 둔다. 패키징된 `Desktoto.app`과 `/Applications` 바로가기를 임시 폴더에 두고 `hdiutil create -format UDZO`로 만든다. zip 생성 단계와 `update-tap`은 건드리지 않는다.
- 상태와 데이터 흐름: 정적 페이지라 서버 상태는 없다. 언어 상태(`ko`, `en`)는 기존 스크립트가 관리하며, 새 문구도 같은 방식으로 전환한다.
- 선택한 방식과 이유:
  - 버튼 주소는 `releases/latest/download/Desktoto.dmg`로 고정한다. 파일 이름에 버전이 없어야 항상 최신을 가리킬 수 있다.
  - 앱이 arm64 전용이므로(`lipo`로 확인) 요구 사항에 "Apple Silicon"을 적는다. "Intel"을 지원하는 것처럼 쓰지 않는다.
  - dmg는 설치를 편하게 할 뿐 Gatekeeper 경고를 없애지 않는다. 그래서 경고 설명과 `그래도 열기` 절차는 dmg 안내에도 필요하다.
  - Homebrew 안내는 전체 이름(`huniversal/tap/desktoto`)만 쓴다(Homebrew 7의 tap 신뢰 때문, #23에서 확인).
- 예외 처리: 클립보드 쓰기가 실패하거나 지원되지 않으면 오류를 띄우지 않고 "복사됨"을 표시하지 않는다. 명령은 텍스트로 선택해 직접 복사할 수 있다. 첫 릴리스 전에는 다운로드 버튼이 404이며, 이는 릴리스를 만든 뒤에 해소된다.

## 완료 조건

- AC-1: 히어로에 "macOS용 다운로드" 주 버튼이 있고 dmg 고정 주소를 가리킨다. 기존 GitHub 버튼은 보조 버튼이며, 버튼 아래에 macOS 26 이상과 Apple Silicon 요구 사항이 보인다.
- AC-2: 하단 "설치 방법" 섹션에 Homebrew 명령 블록(복사 버튼과 "복사됨" 표시), dmg 설치 단계, 터미널 대안 명령, "경고 창은 왜 뜨나요?" 안내가 있다.
- AC-3: 상단 내비게이션의 "설치" 링크가 `#install`로 이동한다.
- AC-4: 새 문구 전부가 한국어와 영어로 전환된다(복사 버튼 문구 포함).
- AC-5: 모바일 폭(약 375px)에서 명령 블록과 단계가 가로로 넘치지 않고, 라이트와 다크 모드에서 모두 읽힌다.
- AC-6: 개인정보 섹션에 새 버전 확인 문구가 있다(읽기만 하고 보내는 정보가 없으며 끌 수 있다는 내용, 한국어와 영어).
- AC-7: 릴리스 워크플로가 `Desktoto.dmg`와 `Desktoto.dmg.sha256`을 만들어 릴리스에 올린다. dmg에는 `Desktoto.app`과 `응용 프로그램` 바로가기가 들어 있다. 기존 zip과 `update-tap`의 동작은 바뀌지 않는다.
- AC-8: `check-web.sh`가 `#install` 섹션과 dmg 다운로드 링크가 없으면 실패한다.
- AC-9: README 설치 절에 dmg 방법과 Apple Silicon 요구 사항이 있고, `docs/ci.md` 릴리스 산출물에 dmg가 있다.
- AC-10: 첫 릴리스 후 히어로 버튼이 실제 dmg를 내려받고, 안내대로 설치해 앱이 열린다. 실제 `brew install`로 Homebrew 안내도 맞는지 확인한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `python3 -m http.server 5173 -d apps/web`로 열어 브라우저에서 확인 | 버튼 문구, 주소(`href` 속성), 보조 버튼, 요구 사항 문구가 맞다 |
| AC-2 | 같은 방법으로 섹션 확인, 복사 버튼 클릭 후 클립보드 내용 확인 | 명령이 정확히 복사되고 "복사됨"이 잠시 보인다 |
| AC-3 | 내비게이션 링크 클릭 | `#install` 섹션으로 이동한다 |
| AC-4 | KO와 EN 전환 | 새 문구가 모두 바뀌고 빠진 문구가 없다 |
| AC-5 | 브라우저의 모바일 폭과 다크 모드 에뮬레이션 | 가로 스크롤과 넘침이 없고 대비가 충분하다 |
| AC-6 | KO와 EN에서 개인정보 섹션 확인 | 새 버전 확인 문구가 있다 |
| AC-7 | 로컬에서 같은 `hdiutil` 명령으로 dmg를 만들어 마운트해 내용 확인, 워크플로 YAML 구조 파싱 | dmg 안에 `Desktoto.app`과 `Applications` 바로가기가 있다. 워크플로의 실제 실행은 태그를 올려야 확인할 수 있다 |
| AC-8 | `bash .github/scripts/check-web.sh`, 필수 요소를 지웠을 때의 실패 확인 | 통과, 요소가 없으면 실패한다 |
| AC-9 | 문서 diff 검토, 링크 점검 | 문서가 실제 동작과 일치한다 |
| AC-10 | 첫 릴리스 후 버튼으로 dmg 내려받아 설치, `brew install --cask huniversal/tap/desktoto`. macOS와 Homebrew 버전 기록 | 안내대로 설치되고 앱이 열린다 |

## 미결정 사항

- Intel Mac 사용자: 앱이 arm64 전용이라 열리지 않는다. 이 작업에서는 요구 사항을 표기하는 데서 멈춘다. 유니버설 빌드는 별도 작업이다. 막지 않는다.
- Homebrew cask에 `depends_on arch: :arm64`를 추가해 Intel Mac에서 설치 단계에서 막히게 할지(`huniversal/homebrew-tap` 저장소 변경). 제안이며 합의 전이다. 막지 않는다.
- `그래도 열기` 절차의 실제 화면은 macOS 버전에 따라 다를 수 있다. 앞서 사용자가 보여 준 화면은 다른 앱 기준이며, 이 앱의 안내문은 실제 Mac에서 따라 해 본 뒤 확정한다. AC-10에서 확인하며 막지 않는다.
- dmg 창의 배경 이미지나 아이콘 배치 같은 꾸밈은 하지 않는다(단순한 구성). 필요하면 후속 작업이다.
- 이슈 #28 본문에는 dmg 생성이 없다. 이 명세에서 범위를 넓혔으므로 이슈 본문 갱신 여부는 사용자가 정한다.
- 다운로드 버튼과 설치 안내는 첫 릴리스 전에는 404이다. 랜딩 페이지가 `main`에 반영되는 시점과 첫 태그를 가깝게 맞춘다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 이슈 #28의 Tasks와 사용자와 합의한 범위(히어로 dmg 다운로드 버튼, 하단 설치 안내, dmg 생성 포함, Apple Silicon 표기, 개인정보 문구 갱신) |
