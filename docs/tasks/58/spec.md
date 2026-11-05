# 작업 명세: [Docs] 릴리즈 업데이트 시 유저 업데이트 방법 안내

## 연결 정보

- 이슈: #58 / https://github.com/huniversal/Desktoto/issues/58
- 브랜치: docs/update-guide/#58
- specRevision: 1
- 대상 ai-run 원본: N/A (원본에 없는 안내 문서다)

## 목적

새 릴리즈가 나왔을 때 유저가 어떻게 업데이트해야 하는지 안내가 없다. 현재는 Homebrew 명령 한 줄만 있고,
dmg로 설치한 유저는 종료 여부, 덮어쓰기 방법, 권한 재설정 필요 여부를 알 수 없다.
실제 동작을 확인한 사실만 골라 정확하게 안내한다.

## 작업 범위

### 포함

- 업데이트 동작 확인 결과 기록 (아래 설계 결정)
- `apps/web/index.html` 설치 섹션에 업데이트 안내 추가 (한국어, 영어 i18n 모두)
- 필요하면 `docs/ci.md`의 릴리스 절에 유저 업데이트 흐름을 한 단락 추가

### 제외

- 앱 코드 변경 (메뉴의 새 버전 안내 문구 포함)
- README 이미지 수정
- 자동 업데이트 기능

## 설계 결정

### 확인한 사실

| 항목 | 결과 | 근거 |
|---|---|---|
| 번들 식별자 | v0.1.0과 v0.1.1이 `com.huniverse.desktoto`로 같다 | 릴리스 zip을 내려받아 `Info.plist` 확인 |
| 서명 | 두 버전 모두 ad-hoc이고 designated requirement가 `cdhash`라 버전마다 값이 다르다 (0.1.0: 98401cb5, 0.1.1: ea99320f) | `codesign -dvvv`, `codesign -d -r-` |
| 릴리스 zip 무결성 | 두 zip 모두 sha256 일치 | `shasum -c` |
| Homebrew | cask는 `app` 설치와 `postflight_steps`의 `xattr -dr com.apple.quarantine`만 한다. 업데이트는 `brew upgrade --cask desktoto` | tap의 `Casks/desktoto.rb` |
| Claude 연결 | 훅 스크립트는 앱 밖인 `~/.ai-run/bin`에 있고, 앱을 업데이트해 실행하면 번들 내용으로 교체된다. settings는 건드리지 않아 다시 연결할 필요가 없다 | `ClaudeIntegration.refreshInstalledScripts` (코드 확인, 실행 검증은 아님) |
| 앱 안 알림 | 새 버전이 있으면 우클릭 메뉴에 "새 버전이 있어요"가 나오고, 누르면 릴리스 페이지가 열린다. Homebrew 설치면 명령도 함께 보인다 | `UpdateNoticeText`, `AppDelegate.openUpdatePage` |

### 아직 확인하지 못한 것

설치본을 실행하면 로그인 항목 등록 같은 부작용이 실제 환경에 남을 수 있고, 권한 저장소(TCC)는 에이전트가 읽을 수 없어 확인하지 못했다.
아래는 유저 환경에서 직접 확인이 필요하다. 확인 전에는 단정하는 문구를 쓰지 않는다.

- 실행 중인 앱 위에 덮어쓸 수 있는지 (확인 전에는 "먼저 종료"를 안내한다)
- 덮어쓴 뒤 터미널 탭 이동에 쓰는 자동화 권한(Apple Events)을 다시 묻는지. ad-hoc `cdhash`가 바뀌므로 다시 물을 가능성이 있다
- 알림 권한과 로그인 항목이 유지되는지
- dmg로 받은 새 앱은 격리 속성이 다시 붙어 첫 실행 경고가 다시 나오는지 (일반적인 macOS 동작이지만 이번에 실측하지 않았다)

## 완료 조건

- AC-1: 웹 설치 섹션에 Homebrew와 dmg 각각의 업데이트 방법이 한국어와 영어로 있다.
- AC-2: 안내의 모든 동작 설명이 확인한 사실이거나, 확인되지 않았다면 단정하지 않는 표현이다.
- AC-3: `check-web.sh`가 통과한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `apps/web/index.html`의 ko와 en 문구 확인, 언어 전환 | 두 언어 모두 표시 |
| AC-2 | 위 표와 문구 대조, 미확인 항목은 유저 환경에서 직접 확인 | 근거 없는 단정 없음 |
| AC-3 | `sh .github/scripts/check-web.sh` | 통과 |

## 미결정 사항

- 위 "아직 확인하지 못한 것" 4개의 실제 동작. 구현을 막는다(문구가 달라진다).

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 사용자와 합의한 작업 범위 |
