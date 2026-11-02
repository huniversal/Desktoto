# Swift 코딩 컨벤션

Swift, SwiftUI, AppKit 소스에 적용한다. [공통 컨벤션](coding-convention.md)과
[macOS 개발 기준](macos-development.md)을 함께 적용한다.
언어 모드와 최소 macOS 버전은 아키텍처 설계 단계에서 확정한다(원본 ai-run은 macOS 26 이상).
다른 언어의 규칙을 자동으로 옮기지 않는다.

## 이름, 파일, 폴더

- 타입과 프로토콜은 `UpperCamelCase`다: `SessionSnapshot`, `UsageReading`.
- 프로퍼티, 변수, 상수, enum case, 함수는 `lowerCamelCase`다: `selectedSessionID`, `maximumLogSize`.
  상수를 `UPPER_SNAKE_CASE`로 만들지 않는다. 타입에 속한 상수는 `static let`을 쓴다.
- Bool은 호출부에서 자연스럽게 읽히게 짓는다: `isActive`, `hasPermission`, `canRetry`.
- 함수는 호출문 전체가 자연스럽도록 동작과 인자 레이블을 정한다: `parse(line:)`, `save(settings:to:)`.
  `get`, `handle`, `Click` 같은 접두사와 접미사를 모든 함수에 일괄 적용하지 않는다.
- 주요 타입의 파일 이름은 타입 이름과 맞춘다: `SessionPanelView.swift`, `SessionSnapshot.swift`.
- 폴더는 Swift Package 관례를 따른다. 모듈과 타입 폴더는 `UpperCamelCase`, 기능 내부 폴더는 해당 기능 이름을 쓴다.
- View를 감싸는 래퍼 컴포넌트는 이름 끝에 `Container`를 붙인다.

## 선언과 타입

- 재할당하지 않는 값은 `let`, 바뀌는 값은 `var`를 쓴다. SwiftUI에 필요한 `var`는 막지 않는다.
- 역할에 맞는 `struct`, `enum`, `class`, `protocol`을 고른다.
- 값 데이터와 상태 선택지는 `struct`와 `enum`을 우선한다. 참조 정체성, 공유 관찰, 상속의 근거가 있을 때 `class`를 쓴다.
- 프로토콜은 실제 경계, 대체 구현, 테스트 필요가 있을 때 도입한다. 모든 타입에 프로토콜이나 ViewModel을 자동으로 만들지 않는다.
- 구현 내부 상태와 헬퍼는 `private`를 우선한다. 무조건 `public`으로 열지 않는다.
- 읽기와 쓰기 권한이 다르면 `private(set)` 등 알맞은 접근 범위를 쓴다.

## 함수, 컬렉션, 문자열

- 이름 있는 동작은 `func`, 동작을 전달하거나 짧은 액션을 표현할 때는 클로저를 쓴다.
- 컬렉션 변환은 `map`, `filter`, `compactMap` 등을 쓴다. `break`, `continue`, 순서가 있는 부작용에는 `for`를 쓸 수 있다.
- 값 삽입은 `"\(count)개"`처럼 문자열 보간을 쓴다.
- 변환과 순회는 명확성을 기준으로 고른다. 짧은 표현 자체가 목적이 아니다.

## SwiftUI 상태와 목록

- View가 소유하는 로컬 상태는 `@State`, 외부 소유 상태를 수정해야 할 때는 `@Binding`을 검토한다.
- 관찰 모델이 필요하면 지원 OS에 맞는 Observation(`@Observable`, 필요하면 `@Bindable`)과 소유 수명을 명확히 한다.
- 여러 View가 같은 상태를 쓰면 단일 소유자를 정하고 명시적 전달이나 환경 주입을 고른다. 모든 모델을 전역 싱글턴으로 두지 않는다.
- View의 `body`는 UI 구성에 집중한다. 분석, 저장, 권한 요청 같은 부작용을 `body` 계산에서 실행하지 않는다.
- 수정되거나 제외되는 목록은 `Identifiable` 또는 명시적인 안정 ID를 쓴다. 배열 인덱스를 기본 ID로 쓰지 않는다.
- ID는 생성 시 한 번 만들고 유지한다. `body` 계산이나 `id` getter에서 매번 새로 만들지 않는다.
- 디자인 토큰(색, 간격, 타이포)은 디자인 시스템 모듈에서만 정의하고 View에서 임의 값을 직접 쓰지 않는다.

## Optional, 오류, 비동기

- `guard let`, `if let` 등 명시적인 Optional 처리를 우선한다. `!`, `try!`, 오류를 버리는 `try?`는 안전성과 의도에 대한 근거가 있을 때만 쓴다.
- 도메인 오류는 원인과 호출부의 처리 방식이 드러나게 표현한다. 실패를 빈 성공 결과로 바꾸지 않는다.
- 비동기는 `async/await`를 쓰고 작업의 소유자, 취소, 재실행, 종료 시점을 정한다.
- UI 상태의 actor 격리를 확인한다. 필요한 경계에 `@MainActor`를 적용하고, 모든 서비스를 일괄 MainActor로 옮기지 않는다.
- `async`라는 이유만으로 무거운 연산이 UI 실행 영역을 벗어났다고 가정하지 않는다.
- actor 사이에 넘기는 데이터의 `Sendable` 조건을 확인한다. 경고를 숨기려고 근거 없이 `@unchecked Sendable`을 쓰지 않는다.
- 취소나 새 입력 이후 오래된 결과가 현재 상태를 덮어쓰지 않게 한다.

## 형식

- 들여쓰기 4칸, 중괄호는 선언과 같은 줄에 둔다.
- 기존 Swift 파일의 간격과 구분 방식을 따른다.
- 빌드와 테스트는 [macOS 개발 기준](macos-development.md)을 따른다.

## 공식 근거

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Swift 기본 문법](https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html)
- [SwiftUI 모델 데이터](https://developer.apple.com/documentation/swiftui/model-data)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
