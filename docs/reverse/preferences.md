# 설정, 알림, 로그인 항목 동작

이슈 #8에서 원본 `~/Desktop/ai-run/Sources/AiRun/`의 `AppSettings.swift`, `NotificationSender.swift`, `AppDelegate.swift`(설정 메뉴와 알림 발송 조건)를 읽고 정리한 동작이다.
구현은 `apps/macos/Sources/Preferences/`에 있다.

## 1. 설정과 저장

설정은 바뀌는 즉시 `UserDefaults`에 저장하고, 패널(SwiftUI)이 값을 지켜보다가 바로 다시 그린다.

| 설정 | 키 | 기본값 | 값 |
| --- | --- | --- | --- |
| 사용량 패널 표시 | `showsUsagePanel` | true | Bool |
| 컨텍스트 패널 표시 | `showsContextPanel` | true | Bool |
| 색상 모드 | `colorMode` | `white` | `white`, `color` |
| 테마 | `theme` | `system` | `light`, `dark`, `system` |
| 유리 단계 | `glassStyle` | `regular` | `clear`, `slightlyClear`, `regular`, `slightlyTinted`, `tinted` |
| 알림 | `sendsNotifications` | true | Bool |
| Claude Code 연동 | `connectsClaudeCode` | true | Bool |
| Codex 실시간 조회 | `fetchesCodexUsage` | true | Bool |

- 저장된 값이 없거나 형식이 맞지 않으면(알 수 없는 문자열, 다른 타입) 기본값을 쓴다.
- 유리 단계는 예전에 3단계(`clear`, `regular`, `tinted`)였고, 그 값은 그대로 읽힌다.
- 두 패널이 모두 꺼져 있으면 보여줄 것이 없어서 패널을 열지 않는다.
- 번들 식별자가 달라 새 앱은 원본의 저장값을 읽지 못하고 기본값으로 시작한다(`docs/architecture.md` 1장).
- `connectsClaudeCode`와 `fetchesCodexUsage`는 값만 저장한다. 연결과 해제, 조회 시작과 중지는 각각 #7, #11에서 한다.

## 2. 우클릭 설정 메뉴

상태바 아이콘을 우클릭하면 패널을 닫고 아래 메뉴를 연다. 항목의 체크 표시는 현재 설정을 따른다.

1. 로그인 시 자동 실행 (앱으로 실행 중일 때만 활성)
2. 알림 보내기
3. Codex 연동
4. Claude 연동 (Claude Code가 설치된 경우에만)
5. 구분선
6. 표시할 패널: 사용량, 컨텍스트
7. 색상: 흰색, 컬러
8. 테마: 라이트, 다크, 시스템 설정에 맞춤
9. Liquid Glass: 투명, 조금 투명, 보통, 조금 진하게, 틴트
10. 구분선
11. Desktoto 종료 (키 q)

원본의 종료 항목 제목은 앱 이름만 바뀌었다. 새 구현은 항목 모델(`SettingsMenu`)까지만 만들고, `NSMenu` 조립은 #11에서 한다.

## 3. 알림

- 번들(.app)로 실행 중이면 `UserNotifications`를 쓴다. 시작할 때 델리게이트를 등록하고 `.alert` 권한을 요청한다. 권한 결과는 무시한다.
- 알림에는 소리를 달지 않는다. 소리는 앱이 직접 재생한다.
- 알림 내용에 `sessionID`를 담고, 알림을 누르면 그 세션 id로 콜백을 호출한다(메인 스레드).
- 앱이 앞에 있을 때도 배너를 보여준다.
- 번들이 없는 개발 실행(`swift run`)에서는 알림 센터에 접근하는 것만으로 앱이 종료되어서 AppleScript `display notification`으로 대신한다. 제목과 본문의 `\`와 `"`를 이스케이프하고 실행 오류는 무시한다.
- 알림 설정이 꺼져 있으면 배너를 보내지 않는다. 소리와 아이콘 표시는 이 설정과 무관하다(호출하는 쪽, #11).

## 4. 로그인 항목

- `SMAppService.mainApp`을 쓰며 번들로 실행 중일 때만 동작한다. 번들이 없으면 상태는 꺼짐이고 변경은 무시한다.
- 켜져 있으면 해제하고, 꺼져 있으면 등록한다. 실패는 로그만 남긴다.
- 변경 후 상태가 `requiresApproval`이면 시스템 설정의 로그인 항목 화면을 연다. 이 확인은 등록 실패 뒤에도 수행한다.

## 5. 외부 의존

| 대상 | 용도 | 비고 |
| --- | --- | --- |
| `UserDefaults` | 설정 저장 | 새 앱은 번들 식별자가 달라 별개 저장소 |
| `UserNotifications` | 알림 배너 | 번들 필요, 권한 거부 시 배너가 안 보일 뿐 오류는 아님 |
| `ServiceManagement` (`SMAppService`) | 로그인 항목 | 번들 필요, 승인 필요 상태 있음 |
| AppleScript | 개발 실행 알림 대체 | 자동화 권한 거부는 무시 |

## 6. 새 구현의 차이와 확인 필요

- 원본의 `ObservableObject`와 전역 `isRunningAsApp`을 `@Observable`과 주입으로 바꿨다. 동작은 같다.
- 실제 .app 번들에서 알림 배너, 알림 클릭 동작, 로그인 항목 켜기와 끄기는 단위 테스트로 검증할 수 없다. 앱 진입점이 #11에 있어 #11 이후 실제 Mac에서 확인한다.
