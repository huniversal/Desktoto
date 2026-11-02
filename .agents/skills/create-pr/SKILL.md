---
name: create-pr
description: Desktoto 작업 브랜치의 실제 검증 결과와 게시 권한을 확인해 PR을 준비, 생성, 수정한다. PR 작성과 게시 요청에 사용하며 merge 권한을 추정하지 않는다.
---

# PR 준비와 게시

[작업 흐름](../../../docs/rules/workflow.md)을 따른다.
기준 ref, 연결 이슈, 커밋과 미커밋 변경, 같은 head와 base의 기존 PR을 확인한다.
명세(`docs/tasks/이슈번호/spec.md`)의 완료 조건과 검증 표를 실제 결과와 대조한다.
실패, 빌드 환경 부재, 미검증은 숨기지 않는다. 필요한 검증을 보완하고 환경 예외는 사용자 지시를 받아 구체적으로 밝힌다.
[PR 템플릿](../../../.github/pull_request_template.md)에 실제 최종 변경과 검증 결과를 작성한다.
작업 브랜치의 실제 경로대로 Git Flow를 체크하고 허위로 표시하지 않는다.
권한이 없는 push나 게시를 대신 수행하지 않는다. 권한이 있으면 반복 승인 없이 요청 범위에서 진행한다.
본문 파일과 `gh pr create` 또는 `gh pr edit`의 `--body-file`을 사용하며 기존 설명을 의미 없이 덮어쓰지 않는다.
실제 URL을 보고한다. PR 요청만으로 merge하지 않는다.

## Git 기준

[Git 컨벤션](../../../docs/rules/git-convention.md)의 제목, 이슈 연결, 라벨 규칙을 적용한다.
사용자가 지정한 제목과 범위를 의미 없이 바꾸지 않는다.
