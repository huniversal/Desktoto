#!/bin/sh
# 릴리스 노트의 업데이트 안내 GIF(update-brew.gif, update-dmg.gif)를 update-source.html에서 다시 만든다.
# 저장소 루트에서 `sh docs/images/release/build.sh`로 실행한다. 한 장만 만들려면 `sh docs/images/release/build.sh brew`처럼 이름을 준다.
# Chrome(/Applications)과 Python 3의 Pillow(`pip3 install pillow`)가 필요하다. 장면 길이는 build-gif.py의 LENGTHS와 source.html의 SCENES가 같아야 한다.
set -eu

python3 docs/images/release/build-gif.py "$@"
