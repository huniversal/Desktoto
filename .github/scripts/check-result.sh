#!/usr/bin/env bash
# CI의 최종 결과를 판정한다. 필수 검사로 연결하는 `CI Result` job이 실행한다.
# 입력: NEEDS_JSON (워크플로의 toJSON(needs) 값)
set -euo pipefail

: "${NEEDS_JSON:?NEEDS_JSON이 필요합니다}"

fail() {
  echo "::error::$1"
  exit 1
}

read_needs() {
  jq -r "$1" <<< "$NEEDS_JSON"
}

[ "$(read_needs '.changes.result // "missing"')" = "success" ] \
  || fail "변경 감지가 성공하지 못했습니다: $(read_needs '.changes.result // "missing"')"

for flag in macos web; do
  value=$(read_needs ".changes.outputs.$flag // \"missing\"")
  case "$value" in
    true | false) ;;
    *) fail "변경 감지 출력 $flag 값이 올바르지 않습니다: $value" ;;
  esac
done

# 선택된 job은 success, 선택되지 않은 job은 skipped여야 한다.
check_job() {
  local job=$1 flag=$2
  local result selected
  result=$(read_needs ".[\"$job\"].result // \"missing\"")
  selected=$(read_needs ".changes.outputs.$flag")
  case "$selected" in
    true) [ "$result" = "success" ] || fail "$job 결과가 success가 아닙니다: $result" ;;
    false) [ "$result" = "skipped" ] || fail "$job 이 선택되지 않았는데 결과가 skipped가 아닙니다: $result" ;;
  esac
  echo "$job: 선택=$selected 결과=$result"
}

check_job macos-build macos
# Web job을 추가할 때 `check_job web web`을 함께 추가한다.

echo "모든 선택된 검사가 통과했습니다."
