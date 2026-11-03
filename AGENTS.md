# AGENTS.md

> AI 에이전트(Claude Code 등)의 진입점이자 라우팅 문서다.
> 이 파일은 어디를 읽을지만 알려 주며, 세부 규칙은 링크된 문서에 있다.

## 프로젝트 요약

Desktoto는 macOS 메뉴바 앱이다. 바이브 코딩으로 만든 프로토타입 `ai-run`(`~/Desktop/ai-run`)을
리버스 엔지니어링해, 제품 동작은 동일하게 두고 내부를 문서화, 설계, 테스트가 갖춰진 구조로 처음부터 다시 만든다.

- 기술 스택: Swift, SwiftUI, AppKit, Swift Package Manager
- 진행 순서: 동작 문서화 → 아키텍처 재설계 → 디자인 시스템 → 구현 → 기존 앱과 동등성 검증
- 목표: 빠르게 진행한다. MVP 동작은 이미 `ai-run`에 있으므로 새로 정할 것은 내부 구조뿐이다.

## 필독 문서

작업 종류에 맞는 문서만 읽는다.

- 코드 변경과 리뷰: [코딩 컨벤션](docs/rules/coding-convention.md) 후 [Swift 코딩 컨벤션](docs/rules/swift-coding-convention.md)
- 브랜치, 커밋, PR, 라벨: [Git 컨벤션](docs/rules/git-convention.md)
- 작업 시작, 명세, 검증, 게시: [작업 흐름](docs/rules/workflow.md)
- macOS 구현과 검증: [macOS 개발 기준](docs/rules/macos-development.md)

## 스킬 라우팅

| 요청 | 스킬 | 트리거 예시 |
|---|---|---|
| GitHub 이슈 생성 | [create-issue](.agents/skills/create-issue/SKILL.md) | "이슈 만들어줘" |
| 구현 설계와 명세 | [logic-design](.agents/skills/logic-design/SKILL.md) | "설계해줘", "명세 써줘" |
| PR 준비와 생성 | [create-pr](.agents/skills/create-pr/SKILL.md) | "PR 올려줘" |

스킬은 작업 방법을 제공할 뿐 실행 권한을 늘리지 않는다.

## 표준 작업 순서

```
1. 이슈          → create-issue
2. 브랜치 생성   → develop에서 feat/작업명/#이슈번호 분기
3. docs 작업 정의 → logic-design (docs/tasks/이슈번호/spec.md), 명세 커밋
4. 개발          → 작은 단위 커밋
5. 검증          → 명세의 완료 조건과 검증 표 확인
6. PR            → create-pr (대상 develop, Closes 또는 Refs)
```

사소한 수정(오타, 1파일 5줄 이하)은 이슈와 명세 없이 선언 후 바로 진행할 수 있다.

## 작업 정책

1. 코드를 만들거나 고치기 전에 수정할 파일과 변경 내용을 미리 말하고 승인을 받는다.
   이미 합의한 범위 안의 작업은 반복 승인받지 않는다.
2. 기본 응답 언어는 한국어다. 사용자가 영어로 쓰면 영어로 답한다.
3. 코드를 언급할 때는 항상 파일 경로를 함께 적는다.
4. 요청한 범위 안에서만 작업한다. 요청 없는 기능, 작업 분해, 이슈, 컨벤션, CI를 만들지 않는다.
5. 에이전트와 서브에이전트는 사용자 승인 없이 실행하지 않는다.
6. `~/Desktop/ai-run`은 읽기 전용 원본이다. 읽기만 하고 절대 수정하지 않는다.
7. `main`, `develop`에 직접 구현하거나 push하지 않는다.
8. 커밋, push, PR, merge는 각각 요청 범위의 권한을 확인한다. PR 요청만으로 merge하지 않는다.
9. 실패, 미실행, 환경 제약을 성공으로 보고하지 않는다.
10. 답변과 새로 쓰거나 고치는 문서, 커밋 메시지, 이슈와 PR 문구에는 가운데점(U+00B7)을 사용하지 않는다.
    나열은 쉼표, 접속사, 문장 분리로 표현한다.

## 폴더 구조

```
Desktoto/
├── AGENTS.md          ← 이 파일 (라우터)
├── CLAUDE.md          ← Claude Code 진입점
├── apps/
│   ├── macos/         ← Desktoto 앱 (Swift Package)
│   └── web/           ← 랜딩 페이지 (스택은 #12에서 결정)
├── docs/
│   ├── rules/         ← 사람이 읽는 규칙 (원본)
│   ├── tasks/         ← 이슈별 작업 명세 (docs/tasks/이슈번호/spec.md)
│   └── ci.md          ← CI와 릴리스 운영
├── .agents/skills/    ← 스킬 원본
├── .claude/commands/  ← 스킬로 연결된 심볼릭 링크
└── .github/           ← 워크플로, CI 스크립트, PR과 이슈 템플릿
```

모노레포다. `apps/macos`의 모듈 구성과 의존 규칙은 [아키텍처](docs/architecture.md)를 따른다.

## 문서 동기화

`docs/`를 먼저 고치고 `.agents/`가 따라간다(한 방향). 스킬 원본을 고치면 심볼릭 링크에 자동 반영된다.
