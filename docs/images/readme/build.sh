#!/bin/sh
# README 이미지를 source.html에서 다시 만든다. 저장소 루트에서 `sh docs/images/readme/build.sh`로 실행한다.
# 슬라이드 이름과 높이(px)는 source.html의 CSS와 같아야 한다. 너비는 1200이고 2배 해상도로 캡처한다.
set -eu

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="docs/images/readme"

capture() {
  "$CHROME" --headless --hide-scrollbars --default-background-color=00000000 \
    --force-device-scale-factor=2 --window-size="1200,$2" --virtual-time-budget=8000 \
    --screenshot="$DIR/$1.png" "file://$PWD/$DIR/source.html#$1" >/dev/null 2>&1
}

capture hero 956
capture install 660
capture problem 376
capture states 510
capture features 1170
capture privacy 680
capture notice 250
