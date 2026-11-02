---
name: logic-design
description: Desktoto의 구현 계획과 완료 조건을 정리해 이슈별 명세를 작성하고 갱신한다. 설계나 구현 계획 요청에 사용하며 일반 설명을 확정 요구사항으로 저장하지 않는다.
---

# 구현 설계

[작업 흐름](../../../docs/rules/workflow.md)을 읽는다.
관련 이슈, 코드, 기존 명세, 사용자 변경을 확인하고 목적, 포함과 제외, AC, 검증 방법을 정리한다.
macOS 작업은 [macOS 개발 기준](../../../docs/rules/macos-development.md)을 읽는다.
리버스 엔지니어링 작업이면 대상 `ai-run` 원본 파일을 읽기 전용으로 확인하고 명세에 원본 경로를 적는다.
이미 합의된 범위는 재사용하고 불분명한 제품 동작만 논의한다.
연결 이슈가 있으면 [템플릿](../../../docs/tasks/_template/spec.md)으로 `docs/tasks/이슈번호/spec.md`를 작성한다.
읽기 전용이면 대화에만 정리하고, 이슈와 연결되지 않은 설계에서는 임의의 이슈 폴더를 만들지 않는다.
합의가 바뀌면 specRevision, AC, 검증 영향을 갱신한다. 새 아키텍처나 컨벤션을 자동으로 확정하지 않는다.

## 컨벤션 적용

[공통 코딩 컨벤션](../../../docs/rules/coding-convention.md)과
[Swift 코딩 컨벤션](../../../docs/rules/swift-coding-convention.md)을 읽는다.
컨벤션을 스킬에 중복 정의하지 않는다.
