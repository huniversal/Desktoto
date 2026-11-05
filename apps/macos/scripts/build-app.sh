#!/bin/sh
# 앱 번들(.app)을 만들고 ad-hoc 서명한다. 설치와 실행은 하지 않는다(install-app.sh 참고).
# 사용법: sh scripts/build-app.sh
# 환경 변수(모두 선택): APP_NAME, EXECUTABLE_NAME, BUNDLE_ID, VERSION, BUILD_NUMBER, RESOURCES_DIR, FEEDBACK_WEBHOOK_URL
#   RESOURCES_DIR: 기본 Resources 폴더의 내용을 번들의 Contents/Resources에 복사한다.
#   FEEDBACK_WEBHOOK_URL: 문의하기가 의견을 보낼 Discord webhook 주소. 있으면 Info.plist의 FeedbackWebhookURL에 넣는다.
#     없으면 키를 넣지 않고, 그 빌드에서는 문의하기 메뉴 항목이 보이지 않는다. 주소는 저장소에 두지 않고 출력하지도 않는다.
set -e
cd "$(dirname "$0")/.."

APP_NAME="${APP_NAME:-Desktoto}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-Desktoto}"
BUNDLE_ID="${BUNDLE_ID:-com.huniverse.desktoto}"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
RESOURCES_DIR="${RESOURCES_DIR:-Resources}"

BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "1/4 릴리스 빌드"
swift build -c release --product "$EXECUTABLE_NAME"
BIN_DIR=$(swift build -c release --show-bin-path)

# plist 값으로 넣을 문자열을 XML 내용으로 안전하게 바꾸고(& < >), sed 치환 문자열에서도 그대로 쓰이게 한다(\ & |).
convert_to_plist_value() {
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
    | sed -e 's/[\\&|]/\\&/g'
}

echo "2/4 앱 패키지 구성"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
sed \
  -e "s|__APP_NAME__|$(convert_to_plist_value "$APP_NAME")|g" \
  -e "s|__BUNDLE_ID__|$(convert_to_plist_value "$BUNDLE_ID")|g" \
  -e "s|__EXECUTABLE_NAME__|$(convert_to_plist_value "$EXECUTABLE_NAME")|g" \
  -e "s|__VERSION__|$(convert_to_plist_value "$VERSION")|g" \
  -e "s|__BUILD_NUMBER__|$(convert_to_plist_value "$BUILD_NUMBER")|g" \
  scripts/Info.plist > "$APP_DIR/Contents/Info.plist"
plutil -lint "$APP_DIR/Contents/Info.plist"
# 서명(4단계) 전에 넣어야 번들 검증이 유지된다. 값은 인자로만 넘기고 출력하지 않는다.
if [ -n "${FEEDBACK_WEBHOOK_URL:-}" ]; then
  plutil -insert FeedbackWebhookURL -string "$FEEDBACK_WEBHOOK_URL" "$APP_DIR/Contents/Info.plist"
  plutil -lint "$APP_DIR/Contents/Info.plist"
  echo "문의하기 webhook 주소를 번들에 넣었습니다."
else
  echo "FEEDBACK_WEBHOOK_URL이 없어 문의하기 항목이 없는 번들을 만듭니다."
fi
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
