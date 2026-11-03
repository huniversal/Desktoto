# 작업 명세: [Feat] 랜딩 페이지 이식

## 연결 정보

- 이슈: #12 / https://github.com/huniversal/Desktoto/issues/12
- 브랜치: feat/landing-page/#12
- specRevision: 2
- 대상 ai-run 원본: `~/Desktop/ai-run/landing/` 의 `index.html`, `og-source.html`, `og.png`, `serve.py`

## 목적

ai-run의 정적 랜딩 페이지 최신 수정본을 `apps/web`으로 옮기고, 모노레포에서 로컬 확인, CI 검증, Cloudflare Pages 배포가 가능한 상태로 만든다.

## 작업 범위

### 포함

- 원본 4개 파일 이식 (1차 커밋에서 바이트 단위로 동일하게 복사 완료)
- `index.html`을 doctype, `html lang`, charset, viewport를 갖춘 완전한 문서로 변경
- 이름 정리: localStorage 키 `airun-lang`을 `desktoto-lang`으로, `landing/` 경로 주석을 `apps/web/`로 변경
- 파비콘 3종: `favicon.svg`, `favicon.ico`, `apple-touch-icon.png`과 `<link>` 연결
- `og:url`, `og:image`를 `https://desktoto.pages.dev/` 기준으로 변경
- `serve.py` 삭제 (문서 틀 붙이기가 유일한 역할이었음)
- `apps/web/README.md`: 로컬 확인과 Cloudflare Pages 배포 방법
- `.github/scripts/check-web.sh`, `ci.yml`의 Web job, `check-result.sh`의 `check_job web web`, `docs/ci.md` 갱신

### 제외

- 랜딩 페이지의 디자인, 문구, 동작 변경 (위 이름 정리 제외)
- Cloudflare 계정 로그인, 프로젝트 생성, 도메인 연결 (사용자가 직접 수행, 후속 이슈 #26에서 추적)
- 커스텀 도메인 도입
- GitHub Pages 배포 워크플로 (Cloudflare Pages Git 연동으로 대체)

## 설계 결정

- 스택: 정적 HTML 유지. 빌드 단계와 프레임워크를 두지 않는다. 앱과 의존이 없는 한 페이지이기 때문이다.
- 파일 구조: `apps/web/` 바로 아래에 평평하게 둔다. 배포 출력 디렉터리가 `apps/web` 그대로이므로 별도 복사 단계가 없다.
- 문서 틀: 원본은 게시 플랫폼이 틀을 붙인다는 전제였다. Cloudflare Pages는 파일을 그대로 내보내므로 `index.html`이 doctype과 charset을 직접 가진다.
- 파비콘: 기존 인라인 SVG data URI를 `favicon.svg`로 분리한다. `favicon.ico`는 32px, `apple-touch-icon.png`는 180px로 같은 그림에서 만든다.
- 배포: Cloudflare Pages의 Git 연동으로 `main` 병합 시 배포한다. 루트 디렉터리 `apps/web`, 빌드 명령 없음. 주소는 `desktoto.pages.dev`이며, 프로젝트 이름이 이미 쓰이고 있으면 실제 주소로 `og:url`을 고친다.
- 도메인 교체 용이성: 절대 주소가 필요한 곳은 `og:url`과 `og:image`뿐이다. 커스텀 도메인을 붙이면 이 두 줄과 `check-web.sh`의 기대 주소만 바꾼다.
- CI 검증: Node 없이 셸 스크립트로 한다. HTML 문법 검증기는 도입하지 않는다.
- 상태와 데이터 흐름: 페이지의 런타임 로직은 원본 그대로다. localStorage 키 이름만 바뀐다. 이전 키를 읽는 호환 코드는 두지 않는다.
- 예외 처리: 원본은 읽기 전용이다. 복사 이후의 원본 변경은 자동 반영되지 않는다.

## 완료 조건

- AC-1: `apps/web/`에 `index.html`, `og-source.html`, `og.png`, `favicon.svg`, `favicon.ico`, `apple-touch-icon.png`, `README.md`가 있고 `serve.py`는 없다.
- AC-2: `index.html`이 `<!doctype html>`, `<html lang="ko">`, charset, viewport, `<title>`을 가진다.
- AC-3: `apps/web/` 안에 `airun`, `ai-run-landing`, `landing/` 문자열이 없다.
- AC-4: `index.html`이 파비콘 3종을 `<link>`로 연결하고 세 파일이 실제로 존재한다.
- AC-5: `og:url`과 `og:image`가 `https://desktoto.pages.dev/` 기준이고, `og.png`가 1200x630이다.
- AC-6: `python3 -m http.server -d apps/web`으로 `/`와 각 에셋이 200으로 응답하고 페이지가 렌더링된다.
- AC-7: `check-web.sh`가 현재 `apps/web`에서 통과하고, 필수 요소를 하나 빼면 실패한다.
- AC-8: `ci.yml`에 Web job이 있고 `check-result.sh`에 `check_job web web`이 있으며 `docs/ci.md`가 갱신돼 있다.
- AC-9: `README.md`에 로컬 확인과 Cloudflare Pages 설정(루트 `apps/web`, 빌드 명령 없음)이 적혀 있다.
- AC-10: 변경 파일이 `apps/web/`, `docs/tasks/12/`, `docs/ci.md`, `.github/` 아래로 한정된다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `ls apps/web` | 7개 파일 존재, `serve.py` 없음 |
| AC-2 | `grep`으로 각 요소 확인 | 모두 존재 |
| AC-3 | `grep -rnE 'airun\|ai-run-landing\|landing/' apps/web` | 결과 없음 |
| AC-4 | `grep`으로 `<link>` 확인, 파일 존재 확인, `file`로 형식 확인 | 3종 연결과 존재 |
| AC-5 | `grep`으로 og 값 확인, `sips -g pixelWidth -g pixelHeight apps/web/og.png` | 주소 일치, 1200x630 |
| AC-6 | 서버 실행 후 `curl -I`로 각 경로, 브라우저에서 렌더링 확인 | 200, 정상 렌더링 |
| AC-7 | `bash .github/scripts/check-web.sh` 통과, 임시 사본에서 요소를 빼고 실패 확인 | 통과, 실패 |
| AC-8 | `ci.yml`과 `check-result.sh` diff, `detect-changes.sh`와 `check-result.sh` 예시 입력 실행 | 연결 확인, 예시 입력 결과 기대와 일치 |
| AC-9 | README 검토 | 필요한 설정 기재 |
| AC-10 | `git diff --stat origin/develop` | 허용 경로만 변경 |

## 미결정 사항

구현을 막지 않는다.

- 실제 Cloudflare 프로젝트 이름이 `desktoto`와 다르면 `og:url`, `og:image`, `check-web.sh` 기대 주소를 고친다.
- 커스텀 도메인은 도입 시점에 정한다.
- 실제 배포 동작은 Cloudflare 프로젝트를 만든 뒤에만 확인할 수 있다. CI와 로컬 검증으로는 확인하지 못한다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 사용자와 합의한 "수정본 그대로 이식" |
| 2 | 이식 외에 완전한 문서화, 이름 정리, 파비콘, CI Web job, 배포 설계를 범위에 추가. `serve.py` 삭제. 배포는 Cloudflare Pages로 결정 | 사용자가 설계를 제대로 하라고 요청했고, 배포는 Cloudflare, 도메인은 `pages.dev`로 합의. 영향 AC: AC-1 변경, AC-2부터 AC-10 신설 |
