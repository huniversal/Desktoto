#!/bin/sh
# 앱 번들(.app)을 만들고 ad-hoc 서명한다. 설치와 실행은 하지 않는다(install-app.sh 참고).
# 사용법: sh scripts/build-app.sh
# 환경 변수(모두 선택): APP_NAME, EXECUTABLE_NAME, BUNDLE_ID, VERSION, BUILD_NUMBER, RESOURCES_DIR
#   RESOURCES_DIR: 지정하면 그 폴더의 내용을 번들의 Contents/Resources에 복사한다.
set -e
cd "$(dirname "$0")/.."

APP_NAME="${APP_NAME:-Desktoto}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-Desktoto}"
BUNDLE_ID="${BUNDLE_ID:-com.huniverse.airun}"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
RESOURCES_DIR="${RESOURCES_DIR:-}"

BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "1/4 릴리스 빌드"
swift build -c release --product "$EXECUTABLE_NAME"
BIN_DIR=$(swift build -c release --show-bin-path)

echo "2/4 앱 패키지 구성"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
sed \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
  -e "s|__EXECUTABLE_NAME__|$EXECUTABLE_NAME|g" \
  -e "s|__VERSION__|$VERSION|g" \
  -e "s|__BUILD_NUMBER__|$BUILD_NUMBER|g" \
  scripts/Info.plist > "$APP_DIR/Contents/Info.plist"
plutil -lint "$APP_DIR/Contents/Info.plist"
if [ -n "$RESOURCES_DIR" ]; then
  cp -R "$RESOURCES_DIR"/. "$APP_DIR/Contents/Resources/"
fi

echo "3/4 앱 아이콘 생성"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
swiftc -O scripts/make-icon.swift -o "$BUILD_DIR/make-icon"
"$BUILD_DIR/make-icon" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "4/4 ad-hoc 서명과 검증"
codesign --force --sign - "$APP_DIR"
codesign --verify --verbose=1 "$APP_DIR"

echo "완료: $APP_DIR"
