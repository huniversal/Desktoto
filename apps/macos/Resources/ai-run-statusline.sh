#!/bin/sh
# Claude Code의 statusLine용 스크립트.
# 세션 상태(컨텍스트, 사용량 한도 포함)를 ~/.ai-run/status/<세션 id>.json에 저장해서 Desktoto 앱이 읽을 수 있게 한다.
# 사용자가 원래 쓰던 statusLine 명령이 있으면 첫 번째 인자로 받아서, 같은 입력으로 그대로 실행해 화면 표시를 넘긴다.
# 사용법: ai-run-statusline.sh [원래 statusLine 명령]
input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
if [ -n "$session_id" ]; then
  dir="$HOME/.ai-run/status"
  mkdir -p "$dir"
  printf '%s' "$input" > "$dir/$session_id.json.tmp" && mv "$dir/$session_id.json.tmp" "$dir/$session_id.json"
fi

if [ -n "$1" ]; then
  printf '%s' "$input" | sh -c "$1"
fi
exit 0
