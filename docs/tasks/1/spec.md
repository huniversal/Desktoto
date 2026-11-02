# 작업 명세: [Chore] CI/CD 및 앱 패키징 세팅

## 연결 정보

- 이슈: #1 / https://github.com/huniversal/Desktoto/issues/1
- 브랜치: feat/ci-cd-setup/#1
- specRevision: 1
- 대상 ai-run 원본: scripts/build-app.sh, scripts/Info.plist, scripts/make-icon.swift

## 목적

이후 모든 PR이 자동으로 빌드와 테스트를 거치게 하고, 태그 push로 설치 가능한 앱 zip을 릴리스할 수 있게 한다.
저장소는 모노레포(`apps/macos`, `apps/web`)로 구성한다. 구조는 ttak-workspace의 CI를 참고하되
Node 기반 보조 스크립트 없이 워크플로 안의 셸 스크립트로 단순하게 유지한다.

## 작업 범위

### 포함

- `.github/workflows/ci.yml`
  - 트리거: `main`, `develop` 대상 PR
  - `Changes` job: PR 전체 변경 경로를 보고 `macos`, `web`, `workflow` 대상을 판정
  - `macOS Build` job: `apps/macos`에서 `swift build`, `swift test` (macos-26, Xcode 26.6)
  - `CI Result` job: 선택된 job의 결과를 하나로 취합 (필수 검사 후보)
  - 액션은 전체 커밋 SHA로 고정하고 권한은 읽기 전용
- `.github/workflows/release.yml`: `v*` 태그 push 시 앱 번들을 빌드해 ad-hoc 서명 zip을 GitHub Release에 업로드 (공증 제외)
- `apps/macos/scripts/`: 패키징 스크립트 이식 (`build-app.sh`, `Info.plist`, `make-icon.swift`). 원본의 설치와 실행 동작은 분리
- 임시 최소 패키지 `apps/macos/Package.swift`와 한 개의 실행 타깃, 한 개의 테스트 (CI 동작 검증용, #2에서 교체)
- `docs/ci.md`: CI와 릴리스 운영 문서
- `AGENTS.md`의 폴더 구조와 이슈 #2, #12 본문을 모노레포 구조에 맞게 갱신

### 제외

- web job의 실제 검사 (랜딩 스택이 정해지는 #12에서 추가). 이번에는 변경 감지의 `web` 플래그와 `CI Result`의 입력 자리만 준비
- 코드 포맷터와 린터 검사 (도입 합의 전)
- 코드 서명 인증서, 공증, 자동 업데이트
- 브랜치 보호 규칙 적용 (CI Result가 한 번 성공한 뒤 별도 승인 후 진행)
- 앱 이름, 번들 식별자, 데이터 폴더 확정 (#2)

## 설계 결정

- 파일 구조와 로직의 책임: 변경 감지는 `Changes` job의 셸 스크립트가 출력한 플래그를 후속 job이 `needs`로 읽는다. 결과 취합은 `CI Result`가 맡는다.
- 상태와 데이터 흐름: PR 전체 diff(merge-base부터 head까지)로 대상을 판정한다. 마지막 커밋만 보지 않는다.
- 선택한 방식과 이유: 워크플로 전체에 경로 필터를 걸지 않고 job을 조건부 실행한다. 그래야 필수 검사 대기 문제가 생기지 않고, 모든 대상이 생략돼도 `CI Result`가 통과한다.
- 예외 처리: 감지 실패, 알 수 없는 상태, 선택된 job의 실패와 취소는 모두 `CI Result` 실패로 처리한다. 실패를 변경 없음으로 바꾸지 않는다.
- 패키징: 앱 이름과 실행 파일명은 변수로 받는다. 이름 확정(#2) 후 값만 바꾸면 되게 한다. 앱 번들 Resources에는 지정한 디렉터리 내용을 복사해 훅 스크립트 포함은 #7에서 맞춘다.
- 실행 환경: macos-26 러너, `DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer`로 Xcode 고정

## 완료 조건

- AC-1: PR 생성과 추가 커밋에서 CI가 실행되고, `apps/macos`가 바뀌면 `macOS Build`가 `swift build`와 `swift test`를 통과한다.
- AC-2: `apps/macos`와 `apps/web`이 모두 바뀌지 않은 PR(문서만 변경)에서는 `macOS Build`가 생략되고 `CI Result`가 통과한다.
- AC-3: 선택된 job이 실패하면 `CI Result`가 실패한다.
- AC-4: 워크플로 파일 자체를 바꾸면 전체 대상이 선택된다.
- AC-5: 패키징 스크립트로 `.app`을 만들고 ad-hoc 서명 검증(`codesign --verify`)을 통과한다. 스크립트는 설치와 실행을 하지 않는다.
- AC-6: `v*` 태그 push 시 릴리스 워크플로가 zip을 만들어 GitHub Release에 올린다.
- AC-7: `docs/ci.md`에 실행 조건, 대상 선택표, 로컬 확인 방법, 릴리스 절차가 있다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | 이 작업의 PR에서 Actions 실행 확인 | `macOS Build`와 `CI Result` 성공 |
| AC-2 | 변경 감지 스크립트를 로컬에서 문서만 바꾼 diff로 실행 | `macos=false`, 결과 취합 통과 |
| AC-3 | 결과 취합 로직을 실패 입력으로 로컬 실행 | 비정상 종료 |
| AC-4 | 변경 감지 스크립트를 `.github/workflows` 변경 diff로 실행 | 모든 대상 `true` |
| AC-5 | `sh apps/macos/scripts/build-app.sh` 후 `codesign --verify` | 검증 통과, 설치와 실행 없음 |
| AC-6 | 릴리스 워크플로는 정적 점검과 로컬 단계 실행. 실제 태그 릴리스는 병합 후 별도 확인 | 병합 전에는 미검증으로 보고 |
| AC-7 | 문서의 링크와 명령 점검 | 링크 오류 없음 |

## 미결정 사항

- 릴리스 워크플로의 실제 태그 실행은 병합 후에만 확인할 수 있다. 구현을 막지 않는다.
- 브랜치 보호 규칙 적용 시점 (CI Result 성공 후 사용자 승인으로 결정).

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 사용자와 합의한 작업 범위 |
