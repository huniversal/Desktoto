# CLAUDE.md

> Claude Code 진입점이다. 프로젝트 규칙, 스킬 라우팅, 작업 흐름은 모두 AGENTS.md에 있다.

@AGENTS.md

## Claude Code 전용

### 슬래시 명령

`.claude/commands/*.md`는 `.agents/skills/*/SKILL.md`로 연결된 심볼릭 링크다.
사용 가능: `/create-issue`, `/create-pr`, `/logic-design`.

### 스킬 자동 매칭

자연어 요청이 스킬의 `description`과 맞으면 해당 스킬을 사용한다.
예: "이슈 만들어줘" → `create-issue`, "PR 올려줘" → `create-pr`, "설계해줘" → `logic-design`.
