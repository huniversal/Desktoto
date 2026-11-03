# 작업 명세: [Feat] 랜딩 페이지 이식

## 연결 정보

- 이슈: #12 / https://github.com/huniversal/Desktoto/issues/12
- 브랜치: feat/landing-page/#12
- specRevision: 1
- 대상 ai-run 원본: `~/Desktop/ai-run/landing/` 의 `index.html`, `og-source.html`, `og.png`, `serve.py`

## 목적

ai-run의 정적 랜딩 페이지 최신 수정본을 내용 변경 없이 `apps/web`으로 옮겨, 모노레포에서 같은 페이지를 로컬로 띄울 수 있게 한다.

## 작업 범위

### 포함

- 위 4개 파일을 `apps/web/` 아래에 바이트 단위로 동일하게 복사

### 제외

이슈 #12의 나머지 Tasks는 이번 범위가 아니다.

- 스택 결정과 CI Web job 추가 (`.github/workflows/ci.yml`, `.github/scripts/check-result.sh`)
- 이름과 문구 정리 (`og:url`, `airun-lang` 키, 주석 경로 포함)
- 로컬 확인 방법 문서화, 배포 방식 결정

## 설계 결정

- 파일 구조와 로직의 책임: `apps/web/` 바로 아래에 원본과 같은 이름으로 평평하게 둔다. 변환과 빌드 단계를 두지 않는다.
- 상태와 데이터 흐름: N/A. 정적 파일 복사이며 런타임 로직은 원본 그대로다.
- 선택한 방식과 이유: 사용자와 "수정본 그대로 가져오기"로 합의했으므로 수정 없이 복사한다. 원본의 옛 이름 잔재는 명세에 기록만 한다.
- 예외 처리: 원본은 읽기 전용이므로 복사만 한다. 복사 이후의 원본 변경은 자동 반영되지 않는다.

## 완료 조건

- AC-1: `apps/web/`에 `index.html`, `og-source.html`, `og.png`, `serve.py`가 있다.
- AC-2: 4개 파일이 원본과 바이트 단위로 동일하다.
- AC-3: `python3 apps/web/serve.py`로 페이지가 로컬에서 열린다.
- AC-4: 변경 파일이 `apps/web/`와 `docs/tasks/12/` 아래로 한정된다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `ls apps/web` | 4개 파일 존재 |
| AC-2 | 원본과 `shasum -a 256` 비교 | 해시 일치 |
| AC-3 | `serve.py` 실행 후 `curl -I http://localhost:5173`, 브라우저 확인 | 200, 페이지 렌더링 |
| AC-4 | `git diff --stat develop` | `apps/web`와 `docs/tasks/12`만 변경 |

## 미결정 사항

구현을 막지 않는다.

- `index.html`의 `og:url`, `og:image`가 `huniversal.github.io/ai-run-landing/`를 가리킨다. 배포 방식 결정 때 갱신한다.
- `index.html`의 localStorage 키 `airun-lang`. 이름 정리 때 갱신 여부를 결정한다.
- `index.html`과 `serve.py` 주석이 `landing/` 경로를 가리킨다.
- 스택(정적 HTML 유지 여부), CI Web job, 로컬 확인 문서화, 배포 방식.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 사용자와 합의한 "수정본 그대로 이식" |
