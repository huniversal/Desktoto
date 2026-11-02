#!/bin/sh
# build-app.sh로 만든 앱을 ~/Applications에 설치하고 실행한다. 로컬 개발용이다.
# 사용법: sh scripts/build-app.sh && sh scripts/install-app.sh
# 환경 변수(모두 선택): APP_NAME, EXECUTABLE_NAME (build-app.sh와 같은 값을 쓴다)
set -e
cd "$(dirname "$0")/.."

APP_NAME="${APP_NAME:-Desktoto}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-Desktoto}"
APP_DIR="build/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

if [ ! -d "$APP_DIR" ]; then
  echo "$APP_DIR 이 없습니다. 먼저 sh scripts/build-app.sh를 실행하세요." >&2
  exit 1
fi

# 같은 이름으로 설치된 다른 앱(번들 식별자가 다른 앱, 예: 원본 ai-run)을 지우고 덮어쓰지 않도록 먼저 확인한다.
INSTALLED_PLIST="$INSTALL_DIR/$APP_NAME.app/Contents/Info.plist"
if [ -f "$INSTALLED_PLIST" ]; then
  NEW_BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$APP_DIR/Contents/Info.plist")
  INSTALLED_BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$INSTALLED_PLIST" 2>/dev/null || true)
  if [ "$INSTALLED_BUNDLE_ID" != "$NEW_BUNDLE_ID" ]; then
    echo "$INSTALL_DIR/$APP_NAME.app 에 다른 앱(번들 식별자: ${INSTALLED_BUNDLE_ID:-알 수 없음})이 설치되어 있어서 중단합니다." >&2
    echo "설치하려는 앱의 번들 식별자는 $NEW_BUNDLE_ID 입니다. 덮어쓰지 않았습니다." >&2
    exit 1
  fi
fi

pkill -x "$EXECUTABLE_NAME" 2>/dev/null || true
sleep 1
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_DIR" "$INSTALL_DIR/"
open "$INSTALL_DIR/$APP_NAME.app"
echo "설치와 실행 완료: $INSTALL_DIR/$APP_NAME.app"
