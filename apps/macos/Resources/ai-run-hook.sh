#!/bin/sh
# Claude Code의 Notification(permission_prompt) hook용 스크립트.
# 승인을 기다리는 세션의 id를 ~/.ai-run/waiting/<세션 id> 파일에 현재 시각(초)과 함께 기록해서,
# Desktoto 앱이 어느 세션이 승인 대기인지 알 수 있게 한다. 승인하거나 거부하면 기록 파일에 새 내용이 쌓이므로
# 앱이 알아서 해제하고, 이 스크립트는 지우지 않는다.
input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# 앱이 읽는 기록 파일 이름과 같은 id를 쓴다.
if [ -n "$transcript" ]; then
  id=$(basename "$transcript" .jsonl)
else
  id="$session_id"
fi
[ -z "$id" ] && exit 0

dir="$HOME/.ai-run/waiting"
mkdir -p "$dir"
date +%s > "$dir/$id"
exit 0
