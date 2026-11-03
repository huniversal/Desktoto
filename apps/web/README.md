# Desktoto 랜딩 페이지

빌드 단계가 없는 정적 HTML 한 페이지다. `index.html`이 문서 전체이고, 나머지는 링크 미리보기와 파비콘 파일이다.

| 파일 | 역할 |
| --- | --- |
| `index.html` | 랜딩 페이지 본문 (스타일과 스크립트 포함) |
| `og-source.html` | 링크 미리보기 이미지의 원본. 1200x630으로 캡처해 `og-v2.png`로 쓴다 |
| `og-v2.png` | 링크 미리보기 이미지 |
| `favicon.svg` | 파비콘 원본. `favicon.ico`와 `apple-touch-icon.png`는 같은 그림으로 만든다 |
| `favicon.ico` | 32x32 파비콘 |
| `apple-touch-icon.png` | 180x180 iOS 홈 화면 아이콘 |

## 로컬 확인

저장소 루트에서 실행한다. 파일을 고치고 브라우저를 새로고침하면 바로 반영된다.

```bash
python3 -m http.server 5173 -d apps/web
```

http://localhost:5173 을 연다.

## 검사

CI의 Web job과 같은 검사다. 필수 파일, 문서 틀, 파비콘 연결, 링크 미리보기 주소와 이미지 크기, 설치 섹션과 dmg 다운로드 링크와 Homebrew 명령을 확인한다.

```bash
bash .github/scripts/check-web.sh
```

## 링크 미리보기 이미지 다시 만들기

`og-source.html`을 고친 뒤 저장소 루트에서 실행한다.

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars --window-size=1200,630 --virtual-time-budget=8000 --screenshot=apps/web/og-v2.png "file://$PWD/apps/web/og-source.html"
```

## 배포

Cloudflare Pages의 Git 연동으로 배포한다. 설정은 Cloudflare 대시보드에서 직접 한다.

| 항목 | 값 |
| --- | --- |
| 프로덕션 브랜치 | `main` |
| 루트 디렉터리 | `apps/web` |
| 빌드 명령 | 없음 |
| 빌드 출력 디렉터리 | `/` (루트 디렉터리 그대로) |
| 기본 주소 | `https://desktoto.pages.dev` |

2026-11-03에 프로젝트 `desktoto`를 만들어 위 값으로 배포했고, 실제 주소가 `https://desktoto.pages.dev`로 예상과 같았다.
`main`에 병합되면 Cloudflare가 자동으로 다시 배포한다(Automatic deployments: Enabled).

프로젝트 이름이 이미 쓰이고 있어 주소가 다르게 나오면, `index.html`의 `og:url`, `og:image`와
[check-web.sh](../../.github/scripts/check-web.sh)의 `SITE_ORIGIN` 기본값을 실제 주소로 함께 바꾼다.
커스텀 도메인을 붙일 때도 같은 세 곳을 바꾼다.

## 방문자 집계

Cloudflare Web Analytics로 방문자 수를 센다. 쿠키를 쓰지 않고 개인을 식별하지 않는다.
`pages.dev` 주소는 Cloudflare 계정의 도메인이 아니라서 자동으로 켜지지 않으므로, 대시보드(Observability, Analytics, Web analytics)에서
호스트 이름을 등록하고 받은 스크립트를 `index.html`의 `</body>` 앞에 직접 넣었다. 스크립트의 토큰은 페이지에 그대로 노출되는 공개 식별자라 비밀이 아니다.
호스트 이름이 바뀌면(커스텀 도메인 등) 대시보드에서 새로 등록하고 스크립트를 교체한다.
버튼 클릭 같은 이벤트는 집계하지 않는다. 실제 다운로드 수는 GitHub Release의 `download_count`로 본다.
