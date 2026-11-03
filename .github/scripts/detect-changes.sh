#!/usr/bin/env bash
# PR 전체 변경 경로를 분류해 검사할 대상을 출력한다.
# 입력: BASE_SHA, HEAD_SHA (PR의 base와 head 커밋)
# 출력: macos, web 플래그(true 또는 false)를 GITHUB_OUTPUT에 쓴다. 로컬에서는 표준 출력에 쓴다.
set -euo pipefail

: "${BASE_SHA:?BASE_SHA가 필요합니다}"
: "${HEAD_SHA:?HEAD_SHA가 필요합니다}"

merge_base=$(git merge-base "$BASE_SHA" "$HEAD_SHA")
changed_paths_file=$(mktemp)
trap 'rm -f "$changed_paths_file"' EXIT

# rename 감지를 꺼서 이동한 파일의 이전 경로와 새 경로를 모두 분류한다.
git diff --name-only --no-renames -z "$merge_base" "$HEAD_SHA" > "$changed_paths_file"

macos=false
web=false
summary_lines=()

while IFS= read -r -d '' path; do
  case "$path" in
    apps/macos/*)
      macos=true
      summary_lines+=("| \`$path\` | macOS |") ;;
    apps/web/*)
      web=true
      summary_lines+=("| \`$path\` | Web |") ;;
    .github/workflows/* | .github/scripts/*)
      macos=true
      web=true
      summary_lines+=("| \`$path\` | 전체 (CI 정의 변경) |") ;;
    docs/* | .agents/* | .claude/* | .github/* | AGENTS.md | CLAUDE.md | README.md | .gitignore)
      ;;
    *)
      # 분류표에 없는 경로는 생략하지 않고 전체를 검사한다.
      macos=true
      web=true
      summary_lines+=("| \`$path\` | 전체 (분류되지 않은 경로) |") ;;
  esac
done < "$changed_paths_file"

{
  echo "macos=$macos"
  echo "web=$web"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"

{
  echo "## 변경 감지"
  echo
  echo "- macOS 검사: $macos"
  echo "- Web 검사: $web"
  if [ "${#summary_lines[@]}" -gt 0 ]; then
    echo
    echo "| 변경 경로 | 선택된 대상 |"
    echo "| --- | --- |"
    printf '%s\n' "${summary_lines[@]}"
  fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/stderr}"
