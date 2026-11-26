---
name: release-qa
description: Desktoto 정식 릴리스 전 QA를 rc 산출물과 QA 시나리오로 진행한다. "릴리스 QA", "릴리즈 QA", "rc QA" 요청에 사용하며, 범용 qa 스킬 대신 이 스킬을 쓴다. 발견한 결함은 그 자리에서 고치지 않고 결함 이슈로 남긴다.
---

# 릴리스 QA

[릴리스 QA](../../../docs/rules/qa.md)의 절차를 1단계부터 따른다. 절차, 범위, 심각도, 종료 기준은 그 문서가 기준이며 이 스킬에 다시 정의하지 않는다.
확인할 항목은 [QA 시나리오](../../../docs/qa/scenarios.md)에 있다.

## 시작할 때

대화에서 정해지지 않은 것만 묻는다.

- 릴리스할 버전과 종류(major, minor, patch)
- 처음 시작하는 QA인지, 이전 rc의 재테스트와 회귀 확인인지 (이전 rc면 기존 QA 이슈와 Notion 페이지를 이어서 쓴다)
- 사용자가 직접 할 수 있는 환경(노치 Mac, 설치된 외부 앱과 터미널)

## 지킬 것

- rc 태그 push, develop → main 머지, 정식 태그 push는 단계마다 사용자 승인을 받는다. QA 요청만으로 승인된 것으로 보지 않는다.
- QA 중 발견한 결함은 고치지 않는다. [결함 템플릿](../../../.github/ISSUE_TEMPLATE/bug_report.md)으로 이슈를 만들고 QA 이슈에 연결한다. 수정은 [작업 흐름](../../../docs/rules/workflow.md)을 따르는 별도 작업이다.
- 에이전트가 실행할 수 없는 시나리오(Gatekeeper 허용, 소리, 노치나 화면 전환 같은 물리 조작)는 사용자에게 절차와 기대 결과를 주고 결과를 받아 기록한다. 결과를 받지 못하면 미검증으로 남긴다.
- 실제로 실행하지 않은 시나리오를 Pass로 표시하지 않는다.
- GitHub QA 이슈와 Notion 사본을 같은 내용으로 갱신한다(`docs/rules/qa.md`의 Notion 기록).
- 이슈, Notion, 첨부에 세션 내용, 프롬프트, 토큰, 개인 경로, webhook 주소를 남기지 않는다.

## Git 기준

[Git 컨벤션](../../../docs/rules/git-convention.md)의 이슈 제목과 라벨 규칙을 적용한다.
태그 형식은 [릴리스 워크플로](../../../.github/workflows/release.yml)가 받는 `vX.Y.Z-rc.N`과 `vX.Y.Z`만 쓴다.
