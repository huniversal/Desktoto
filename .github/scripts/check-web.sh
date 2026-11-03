#!/usr/bin/env bash
# 랜딩 페이지(apps/web)가 배포 가능한 정적 사이트인지 검사한다. Node 없이 셸만 쓴다.
# 환경 변수: WEB_DIR (기본 apps/web), SITE_ORIGIN (기본 https://desktoto.pages.dev)
# 도메인을 바꾸면 index.html의 og:url, og:image와 이 기본값을 함께 바꾼다.
set -euo pipefail

WEB_DIR=${WEB_DIR:-apps/web}
SITE_ORIGIN=${SITE_ORIGIN:-https://desktoto.pages.dev}
PAGE="$WEB_DIR/index.html"

fail() {
  echo "::error::$1"
  exit 1
}

require_pattern() {
  grep -Eiq "$1" "$PAGE" || fail "$PAGE: $2"
}

for file in index.html og-source.html og-v2.png favicon.svg favicon.ico apple-touch-icon.png; do
  [ -f "$WEB_DIR/$file" ] || fail "필수 파일이 없습니다: $WEB_DIR/$file"
done

head -n 1 "$PAGE" | grep -Eiq '^<!doctype html>' || fail "$PAGE: 첫 줄이 <!doctype html>이 아닙니다"
require_pattern '<html lang="[a-z-]+"' "<html lang> 이 없습니다"
require_pattern '<meta charset="utf-8">' "charset utf-8이 없습니다"
require_pattern '<meta name="viewport" ' "viewport meta가 없습니다"
require_pattern '<title>[^<]+</title>' "<title>이 없습니다"

# 파비콘 링크와 실제 파일의 연결
for link in '/favicon.ico' '/favicon.svg' '/apple-touch-icon.png'; do
  grep -Fq "href=\"$link\"" "$PAGE" || fail "$PAGE: 파비콘 링크가 없습니다: $link"
done

# 링크 미리보기 주소는 배포 도메인 기준이어야 하고, 이미지는 저장소에 있어야 한다.
og_url=$(sed -n 's/.*<meta property="og:url" content="\([^"]*\)".*/\1/p' "$PAGE")
og_image=$(sed -n 's/.*<meta property="og:image" content="\([^"]*\)".*/\1/p' "$PAGE")
[ "$og_url" = "$SITE_ORIGIN/" ] || fail "og:url이 $SITE_ORIGIN/ 이 아닙니다: ${og_url:-없음}"
case "$og_image" in
  "$SITE_ORIGIN"/*) ;;
  *) fail "og:image가 $SITE_ORIGIN/ 아래가 아닙니다: ${og_image:-없음}" ;;
esac
[ -f "$WEB_DIR/${og_image#"$SITE_ORIGIN"/}" ] || fail "og:image가 가리키는 파일이 없습니다: $og_image"

# og-v2.png 크기: PNG 헤더의 너비와 높이(각 4바이트, 16바이트 지점부터)를 읽는다.
read -r width height < <(od -An -tu1 -j16 -N8 "$WEB_DIR/og-v2.png" \
  | awk '{ print $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8 }')
[ "$width" = 1200 ] && [ "$height" = 630 ] || fail "og-v2.png 크기가 1200x630이 아닙니다: ${width}x${height}"

# 설치 안내: 설치 섹션과 헤더 링크, 히어로의 dmg 다운로드 링크가 있어야 한다. 파일 이름에 버전이 없어야 releases/latest/download가 항상 최신을 가리킨다.
DMG_URL='https://github.com/huniversal/Desktoto/releases/latest/download/Desktoto.dmg'
require_pattern '<section id="install"' "설치 섹션(#install)이 없습니다"
require_pattern '<a class="text" href="#install"' "헤더의 설치 링크(#install)가 없습니다"
grep -Fq "href=\"$DMG_URL\"" "$PAGE" || fail "$PAGE: dmg 다운로드 링크가 없습니다: $DMG_URL"
grep -Fq 'brew install --cask huniversal/tap/desktoto' "$PAGE" || fail "$PAGE: Homebrew 설치 명령이 없습니다"

# ai-run 시절 이름이 남아 있으면 실패한다.
if grep -rnE 'airun|ai-run-landing|landing/' "$WEB_DIR"; then
  fail "ai-run 시절 이름이나 경로가 남아 있습니다"
fi

echo "web 검사를 통과했습니다: $WEB_DIR"
