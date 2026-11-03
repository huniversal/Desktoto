# 작업 명세: [Deploy] 랜딩 페이지 Cloudflare Pages 배포

## 연결 정보

- 이슈: #26 / https://github.com/huniversal/Desktoto/issues/26
- 브랜치: feat/cloudflare-deploy/#26
- specRevision: 2
- 대상 ai-run 원본: N/A (배포 작업이다)

## 목적

#12에서 만든 정적 사이트 `apps/web`을 Cloudflare Pages로 실제 공개한다. 배포는 Cloudflare Pages의 Git 연동으로 하므로 저장소에 배포 워크플로가 없고, 계정과 대시보드 설정이 작업의 대부분이다.
공개된 주소에서 페이지와 파비콘, 링크 미리보기 이미지, 다운로드 버튼이 정상 동작하는지 확인하고, 방문자 수를 볼 수 있게 Cloudflare Web Analytics를 켠다.

선행 조건: `apps/web`이 `main`에 반영되어 있어야 프로덕션 배포가 된다(PR 32로 반영됨). 설치 안내가 가리키는 릴리스 `v0.1.0`도 이미 올라가 있다.

## 작업 범위

### 포함

- Cloudflare 대시보드에서 Pages 프로젝트 `desktoto`를 만들고 `huniversal/Desktoto` 저장소를 Git 연동으로 연결한다. 프로덕션 브랜치 `main`, 루트 디렉터리 `apps/web`, 빌드 명령 없음, 빌드 출력 디렉터리 `/`. (사용자가 대시보드에서 직접 한다. 계정 로그인과 GitHub 연결 승인은 대신할 수 없다.)
- 배포 후 실제 주소에서 페이지, 파비콘 3종(`favicon.ico`, `favicon.svg`, `apple-touch-icon.png`), `og.png`가 열리는지 확인한다.
- 실제 주소가 예상(`https://desktoto.pages.dev`)과 다르면 `apps/web/index.html`의 `og:url`, `og:image`와 `.github/scripts/check-web.sh`의 `SITE_ORIGIN` 기본값을 함께 수정한다.
- 링크 미리보기(카카오톡, 슬랙 등)에 `og.png`가 나오는지 확인한다.
- PR 미리보기 배포 사용 여부를 정한다. 기본안은 끄는 것이다(브랜치마다 공개 주소가 생기는 것을 막는다).
- Cloudflare Web Analytics를 켠다(사용자 합의). `pages.dev` 주소는 Cloudflare 계정의 도메인이 아니라서 자동 설치가 되지 않으므로, 대시보드에서 호스트 이름을 등록하고 받은 스크립트를 `index.html`의 `</body>` 앞에 직접 넣는다(코드 변경 있음).
- 배포된 페이지의 다운로드 버튼(`releases/latest/download/Desktoto.dmg`)과 설치 명령이 정상인지 확인한다.
- `apps/web/README.md`의 배포 절을 실제 설정값, 분석 도구, 미리보기 배포 결정으로 갱신한다.

### 제외

- 커스텀 도메인 도입
- 랜딩 페이지의 디자인과 문구 변경
- Google Analytics 등 쿠키를 쓰는 분석 도구

## 설계 결정

- 파일 구조와 로직의 책임: 배포는 Cloudflare Pages의 Git 연동이 `main`의 `apps/web`을 그대로 올리는 방식이다. 저장소에는 배포 워크플로를 두지 않고, 설정값의 기록은 `apps/web/README.md`가 맡는다. 코드 변경은 실제 주소가 예상과 다를 때만 생긴다.
- 상태와 데이터 흐름: `main`에 병합되면 Cloudflare가 자동으로 새로 배포한다. 검사 스크립트(`check-web.sh`)는 CI에서 PR마다 실행되므로, 주소를 바꾸는 변경은 그 검사와 함께 간다.
- 선택한 방식과 이유:
  - 방문자 집계는 Cloudflare Web Analytics로 한다. 쿠키를 쓰지 않아 동의 배너가 필요 없다. 광고 차단기에 덜 걸리고 페이지가 가볍다. 스크립트의 토큰은 공개 식별자라 저장소에 있어도 비밀이 아니다.
  - 버튼 클릭 같은 이벤트는 집계하지 않는다. 실제 다운로드 수는 GitHub Release의 `download_count`로 본다(brew, dmg, zip이 합산되고 내려받은 횟수이지 사람 수가 아니다).
  - 이 페이지는 개인정보를 내세우므로 쿠키를 쓰는 분석 도구는 쓰지 않는다.
- 예외 처리: 프로젝트 이름이 이미 쓰이고 있어 주소 뒤에 무작위 글자가 붙으면 실제 주소를 기준으로 `og:url`, `og:image`, `SITE_ORIGIN`을 고친다. 배포가 실패하면 Cloudflare의 빌드 로그를 확인하고, 설정값(루트 디렉터리, 출력 디렉터리)부터 점검한다.

## 완료 조건

- AC-1: Cloudflare Pages 프로젝트가 `huniversal/Desktoto`와 연결되어 있고, 프로덕션 브랜치 `main`, 루트 디렉터리 `apps/web`, 빌드 명령 없음으로 설정되어 있다.
- AC-2: 실제 주소에서 페이지, 파비콘 3종, `og.png`가 모두 200으로 열린다.
- AC-3: 실제 주소가 `og:url`, `og:image`, `check-web.sh`의 `SITE_ORIGIN`과 일치하고 `bash .github/scripts/check-web.sh`가 통과한다.
- AC-4: 링크 미리보기(카카오톡, 슬랙 등)에 `og.png`가 나온다.
- AC-5: PR 미리보기 배포 사용 여부가 정해졌고 설정에 반영되어 있다.
- AC-6: Cloudflare Web Analytics에 `desktoto.pages.dev`가 등록되어 있고 스크립트가 `index.html`에 들어 있으며, 배포된 페이지를 방문했을 때 대시보드에 집계된다.
- AC-7: 배포된 페이지의 다운로드 버튼이 실제 dmg를 내려받는 주소(200)를 가리키고, 설치 명령과 설치 섹션이 보인다.
- AC-8: `apps/web/README.md`의 배포 절이 실제 설정값과 일치한다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | Cloudflare 대시보드의 프로젝트 설정 화면 확인(사용자) | 위 설정값과 일치 |
| AC-2 | `curl -s -o /dev/null -w "%{http_code} %{content_type}"`로 `/`, `/favicon.ico`, `/favicon.svg`, `/apple-touch-icon.png`, `/og.png` 확인 | 모두 200이고 형식이 맞다 |
| AC-3 | 배포된 HTML의 `og:url`, `og:image`와 `SITE_ORIGIN` 비교, `check-web.sh` 실행 | 일치하고 통과한다 |
| AC-4 | 카카오톡 나에게 보내기, 슬랙 등에 주소를 붙여 넣어 미리보기 확인(사용자) | `og.png`가 나온다 |
| AC-5 | 대시보드 설정 확인, 브랜치로 푸시했을 때 미리보기 배포가 생기지 않는지 확인 | 결정한 대로 동작한다 |
| AC-6 | 페이지를 열어 본 뒤 Cloudflare Web Analytics 화면 확인(사용자) | 방문이 집계된다(반영까지 시간이 걸릴 수 있다) |
| AC-7 | 배포된 HTML에서 다운로드 링크와 `#install` 확인, 링크의 HTTP 응답 확인 | 링크가 200이고 섹션이 있다 |
| AC-8 | README diff 검토 | 실제 설정과 일치한다 |

## 미결정 사항

- 실제 배포 주소: 배포 결과 `https://desktoto.pages.dev`로 예상과 같았다(2026-11-03). 코드를 고칠 필요가 없었다. 해소됨.
- 방문자 집계를 사이트에 알릴지: Cloudflare Web Analytics는 쿠키를 쓰지 않고 개인을 식별하지 않지만, 개인정보를 내세우는 페이지라 푸터나 개인정보 섹션에 "방문자 수를 쿠키 없이 집계해요" 같은 한 줄을 넣을지 정해야 한다. 제안이며 합의 전이다. 막지 않는다.
- 커스텀 도메인은 이번 범위가 아니며 필요할 때 별도 작업으로 한다.
- 이슈 #26의 Task 목록에는 분석 항목이 없다. 이 명세에서 범위를 넓혔으므로 이슈 본문 갱신 여부는 사용자가 정한다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 이슈 #26의 Tasks에 사용자와 합의한 Cloudflare Web Analytics 활성화와 다운로드 버튼 확인을 더함 |
| 2 | Cloudflare Pages 배포 완료(주소 예상과 일치). Web Analytics는 `pages.dev`가 계정 도메인이 아니라 스크립트를 `index.html`에 직접 넣는 방식으로 변경 | 실제 설정 과정에서 자동 설치가 안 되는 것을 확인. 영향받는 AC: AC-1, AC-2, AC-3, AC-6 |
