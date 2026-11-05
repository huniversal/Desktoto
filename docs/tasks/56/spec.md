# 작업 명세: [Feat] 설정 메뉴에서 Discord로 피드백 보내기

## 연결 정보

- 이슈: #56 / https://github.com/huniversal/Desktoto/issues/56
- 브랜치: feat/feedback/#56
- specRevision: 1
- 대상 ai-run 원본: N/A (원본에 없는 새 기능이다)

## 목적

사용자가 버그나 추가되었으면 하는 기능을 개발자에게 쉽게 전달할 창구가 없다. 이메일 주소 등을 직접 입력해 보내는 방식은 부담이 크다.
우클릭 설정 메뉴에서 내용만 적어 보내면 개발자가 Discord 채널에서 바로 확인하도록 한다.

단방향 피드백 수집이다. 답장 기능은 없다. 앱이 사용자가 직접 입력한 내용을 밖으로 보내는 첫 기능이다(`UpdateCheck`는 읽기만 한다).
전송은 사용자가 보내기를 누를 때만 일어나고, 자동으로 보내는 정보는 앱 버전과 macOS 버전뿐이다.

## 작업 범위

### 포함

- 설정 메뉴의 `문의하기…` 항목과 작은 입력 창(입력창, 보내기 버튼, 전송 정보 안내 문구)
- Discord webhook으로 의견을 한 번 POST하는 전송 로직. 앱 버전과 macOS 버전을 함께 보낸다
- webhook URL을 소스에 두지 않고 GitHub Secret `FEEDBACK_WEBHOOK_URL`에서 릴리스 빌드 때 `Info.plist`로 주입하는 빌드 변경
- URL이 없거나 올바르지 않은 빌드(개발, CI, 포크)에서는 `문의하기…` 항목을 보여 주지 않는다
- 성공과 실패 처리(실패하면 입력 내용을 유지하고 오류를 알린다)
- 새 모듈 `Feedback` 추가와 문서 갱신(아키텍처, CI 운영)

### 제외

- 답장, 연락처 입력, 첨부 파일과 스크린샷, 분류 선택
- 앱 안의 전송 간격 제한과 스팸 방어(배포 규모가 작아 감수한다. 문제가 생기면 webhook을 재발급하거나 중간 프록시를 검토한다)
- 전송 실패한 의견의 저장과 자동 재시도, 창을 닫았다가 다시 열 때 초안 복원
- Notion 등 다른 수집 경로, 중간 서버
- 랜딩 페이지와 README 개인정보 문구 수정(미결정 사항 참고)
- GitHub Secret 등록과 Discord webhook 생성(저장소 소유자가 직접 한다)

## 설계 결정

- 파일 구조와 로직의 책임:
  - 새 모듈 `Feedback`(`apps/macos/Sources/Feedback/`, 의존은 `DesignSystem`)을 둔다. 한 기능만 쓰는 네트워크 서비스는 그 기능 모듈 안에 둔다는 [아키텍처](../../architecture.md) 5장 원칙을 따르고, `UpdateCheck`의 `ReleaseFetcher`와 같은 모양(주입형 `Load` 클로저, 순수 판정 함수)으로 만든다.
  - 순수 값과 함수: 전송 본문 구성(`FeedbackMessage`: 본문 다듬기, 푸터, 길이 제한, JSON), webhook URL 검증(`FeedbackWebhook`), 응답 상태 코드 판정.
  - 경계: `FeedbackSending` 프로토콜(`Sendable`)과 `URLSession` 기반 `DiscordFeedbackSender`. 테스트는 가짜 `Load`를 주입한다.
  - 상태: `FeedbackModel`(`@MainActor`, `@Observable`)이 입력 글, 전송 단계(대기, 전송 중, 성공, 실패)를 소유한다. 입력 View(`FeedbackView`)는 모델만 보고 비즈니스 로직을 갖지 않으며 디자인 토큰은 `DesignSystem`에서 쓴다. UI 모듈은 `Boundaries`를 import하지 않는다는 의존 규칙을 지킨다.
  - `Preferences`는 메뉴 항목 모델만 맡는다(`SettingsAction.showFeedback`, `SettingsMenuEnvironment.isFeedbackAvailable`). `Desktoto` 앱이 `NSWindow`와 `NSHostingController`로 창을 띄우고 모듈을 조립한다. 모듈끼리 서로 import하지 않는다.
- 상태와 데이터 흐름: 앱이 시작할 때 번들의 `Info.plist`에서 URL을 읽어 `FeedbackWebhook`으로 검증하고, 유효할 때만 `isFeedbackAvailable`을 켠다. 메뉴에서 항목을 누르면 창을 열고(이미 열려 있으면 앞으로 가져온다), 모델이 입력과 전송 단계를 관리한다. 전송 작업은 모델이 소유하며 보내는 중에는 다시 보낼 수 없다. 영속하는 상태는 없다.
- 선택한 방식과 이유:
  - Discord webhook: 서버 없이 앱에서 한 번 POST하면 끝나고, 알림이 바로 와서 확인이 빠르다.
  - URL 주입: 저장소가 public이라 소스와 커밋에 URL을 두지 않는다. `build-app.sh`가 환경 변수 `FEEDBACK_WEBHOOK_URL`이 있을 때만 `plutil -insert`로 `Info.plist`의 `FeedbackWebhookURL` 키에 넣는다. 서명(ad-hoc)은 그 뒤에 하므로 번들 검증이 유지된다. 스크립트는 값을 출력하지 않는다. 릴리스 워크플로는 Secret을 이 환경 변수로 넘긴다.
  - URL 검증: `https://discord.com/api/webhooks/`로 시작하는 값만 받는다. 키가 없거나 빈 값, 다른 호스트면 기능이 없는 것으로 본다(메뉴 숨김). 번들이 잘못 만들어져도 임의의 주소로 사용자 글을 보내지 않기 위함이다.
  - 전송 본문: Discord webhook JSON의 `content`에 사용자 글과 구분선, `Desktoto 버전, macOS 버전`을 담는다. `allowed_mentions`의 `parse`를 빈 배열로 보내 사용자가 `@everyone` 같은 멘션을 써도 채널에서 알림이 울리지 않게 한다. Discord `content`의 2000자 제한을 넘지 않도록 사용자 입력은 1500자까지로 제한한다. 앞뒤 공백은 지우고, 비어 있으면 보낼 수 없다.
  - 버전: 앱 버전은 번들의 `CFBundleShortVersionString`, macOS 버전은 `ProcessInfo.operatingSystemVersion`에서 읽는다. 둘 다 순수 함수에 값을 넘겨 테스트한다.
  - 안내 문구: 창에 "앱 버전과 macOS 버전이 함께 전송돼요. 답장은 드리지 못해요." 정도를 보여 준다(정확한 문구는 구현 때 정한다).
  - 릴리스에서 Secret이 비어 있으면 빌드는 통과하되 Actions 경고(`::warning::`)를 남긴다. 기능이 없는 릴리스가 조용히 나가는 것을 알리기 위함이다.
- 예외 처리: 2xx(Discord는 204)만 성공이다. 429(요청 제한), 그 밖의 4xx와 5xx, 네트워크 오류, 시간 초과(10초)는 실패로 보고 입력 내용을 그대로 둔 채 오류를 보여 주며 사용자가 다시 보낼 수 있다. 삭제된 webhook(404)도 같은 실패로 처리한다. 응답 본문은 쓰지 않고, 사용자 글과 URL을 로그에 남기지 않는다. 창을 닫으면 진행 중인 요청은 취소하고 입력은 버린다.

## 완료 조건

- AC-1: 전송 본문 구성이 순수 함수로 분리되어 있고 단위 테스트가 검증한다. 공백 다듬기, 빈 입력 거부, 1500자 제한, 푸터에 앱 버전과 macOS 버전 포함, `allowed_mentions.parse`가 빈 배열인 JSON, 전체 길이가 2000자를 넘지 않음.
- AC-2: webhook URL 검증이 순수 함수로 분리되어 있다. `https://discord.com/api/webhooks/`로 시작하는 유효한 URL만 받고, 없음, 빈 값, 다른 호스트나 `http`, 잘못된 URL은 거부한다.
- AC-3: 전송은 프로토콜 뒤에 있고 가짜 `Load`로 테스트한다. 204와 2xx는 성공, 429와 404와 5xx와 네트워크 오류와 시간 초과는 실패로 판정한다.
- AC-4: `FeedbackModel`이 상태를 검증한다. 빈 입력이면 보낼 수 없고, 전송 중에는 중복 전송이 안 되며, 성공하면 완료 상태가 되고, 실패하면 입력이 유지되고 오류가 있으며 다시 보낼 수 있다. 창을 닫으면 진행 중인 전송을 취소한다.
- AC-5: 설정 메뉴에 `문의하기…` 항목이 `사용 안내…` 바로 뒤에 있고, 기능이 사용 가능할 때만 보인다. 누르면 창이 열리고 이미 열려 있으면 앞으로 온다.
- AC-6: 창에 입력창과 보내기 버튼과 전송 정보 안내 문구가 있다. 성공하면 전달됐다는 안내 후 창이 닫히고, 실패하면 입력 내용이 남아 있다.
- AC-7: `FEEDBACK_WEBHOOK_URL`을 지정해 `build-app.sh`를 실행하면 `Info.plist`에 `FeedbackWebhookURL`이 들어가고, 지정하지 않으면 키가 없다. 두 경우 모두 `plutil -lint`와 `codesign --verify`가 통과하고, 스크립트 출력에 URL이 나오지 않는다. `release.yml`의 패키징 단계가 Secret을 환경 변수로 전달하고, 비어 있으면 경고를 남긴다.
- AC-8: 저장소 소스, 커밋, 문서에 실제 webhook URL이 없다. Secret이 없는 CI 빌드가 통과하고 그 번들에서는 메뉴 항목이 보이지 않는다.
- AC-9: `Package.swift`와 `docs/architecture.md`(모듈 표, 의존 방향, 외부 경계, 단일 기능 서비스)가 `Feedback` 모듈을 반영하고, `docs/ci.md`에 `FEEDBACK_WEBHOOK_URL` Secret의 용도와 등록과 교체 방법, 로컬 확인 방법을 적는다.
- AC-10: 실제 Mac에서 확인하고 결과를 PR에 기록한다. 테스트용 webhook으로 빌드한 앱에서 전송이 성공해 채널에 의견과 버전 정보가 보이고, 네트워크를 끊으면 오류와 함께 입력이 남고, 삭제한 webhook은 실패로 처리되고, 키 없는 빌드에서는 메뉴 항목이 없다.

## 검증 방법

| 완료 조건 | 확인 방법 | 기대 결과 |
|---|---|---|
| AC-1 | `swift test` (`FeedbackTests`의 본문 구성 테스트) | 통과 |
| AC-2 | `swift test` (`FeedbackTests`의 URL 검증 테스트) | 통과 |
| AC-3 | `swift test` (가짜 `Load`로 상태 코드와 오류별 판정) | 통과 |
| AC-4 | `swift test` (`FeedbackModel` 상태 전이, 중복 전송, 취소) | 통과 |
| AC-5 | `swift test` (`PreferencesTests`의 `SettingsMenu` 항목 모델), 실제 Mac에서 메뉴 확인 | 사용 가능할 때만 항목이 보이고 순서가 맞다 |
| AC-6 | 실제 Mac에서 창을 열어 성공과 실패 흐름 확인 | 성공 시 닫히고 실패 시 입력이 남는다 |
| AC-7 | 환경 변수 유무로 `sh scripts/build-app.sh` 두 번 실행, `plutil -extract FeedbackWebhookURL raw`, 출력 검토, 워크플로 diff 검토 | 키 유무가 맞고 출력에 URL이 없다 |
| AC-8 | `git grep`으로 `discord.com/api/webhooks/` 실제 값 검색, 키 없는 번들 실행 | 실제 URL이 없고 메뉴 항목이 숨겨진다 |
| AC-9 | `swift build`, 문서 diff 검토, 링크 점검 | 빌드 통과, 문서가 패키지 구성과 일치 |
| AC-10 | 테스트 채널의 webhook(개인 테스트용)으로 번들을 빌드해 직접 실행, 네트워크 끊기, webhook 삭제 후 전송. macOS와 Xcode 버전 기록 | 각 경우의 기대 동작과 일치 |

## 미결정 사항

- 랜딩 페이지(`apps/web/index.html`의 개인정보 섹션, 한국어와 영어)와 README 개인정보 이미지(`docs/images/readme/privacy.png`)가 "보내는 정보는 없다"는 취지로 쓰여 있다. 이 기능은 사용자가 직접 보낼 때만 글과 버전을 보내므로 "문의하기" 항목을 추가할지, 이번 작업에 넣을지 별도 이슈로 뺄지 정한다. 구현을 막지 않는다.
- 성공 안내의 모양(창 안에 잠깐 표시 후 닫기, 별도 알림 등)과 안내 문구, 창 크기와 배치는 구현 때 디자인 시스템 토큰에 맞춰 정한다. 막지 않는다.
- 첫 릴리스 이후 webhook 재발급이 필요해지면 모든 이전 버전에서 문의하기가 동작하지 않는다. 이 기능이 들어간 버전부터 해당하며 감수한다.
- AC-10의 실제 전송 확인에는 소유자가 만든 테스트용 webhook이 필요하다. 운영 채널의 webhook은 확인에 쓰지 않는다.

## 주요 설계 변경

| specRevision | 변경한 결정 | 이유 |
|---|---|---|
| 1 | 최초 설계 | 이슈 #56의 Tasks와 사용자와 합의한 방향(Discord webhook, 설정 메뉴 입력 창, Secret을 통한 빌드 시 주입, 앱 버전과 macOS 버전 포함, 단방향). 모듈 구성, 본문 형식, 1500자 제한, 멘션 차단, URL 검증은 이 명세에서 제안하는 세부 설계이며 검토가 필요하다 |
