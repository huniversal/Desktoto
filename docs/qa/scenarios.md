# QA 시나리오

[릴리스 QA](../rules/qa.md)에서 실행하는 체크리스트다. 릴리스마다 이번 범위의 항목을 QA 이슈로 복사해 결과를 기록한다.

## 읽는 법

- **ID**: `영역-번호`다. QA 이슈와 결함 이슈에서 이 ID로 가리킨다.
- **기대 결과**: Pass와 Fail을 가를 수 있는 상태 문장이다. 하나라도 다르면 Fail이다.
- **smoke**: ✅ 표시 항목은 patch 릴리스와 rc 회귀 확인에서도 항상 실행한다.
- **근거**: 기대 결과를 정한 문서나 소스다. 앱 동작이 바뀌어 근거와 맞지 않으면 QA 전에 이 문서를 고친다.

## 사전 준비

- rc 프리릴리스의 `Desktoto.dmg`. minor 이상이면 덮어 설치 확인용으로 직전 정식 버전도 준비한다.
- 연동 확인용 외부 앱: Claude Code, Codex, Antigravity, iTerm2, Terminal, cmux, VS Code 중 설치된 것. 없는 앱의 항목은 미검증으로 남긴다.
- 노치 봇 항목은 노치가 있는 Mac이 필요하다.
- 세션을 만들 때는 내용이 공개되어도 괜찮은 임시 폴더와 짧은 프롬프트를 쓴다.
- 사용자 환경을 바꾸는 항목(CLAUDE, PREF-01)은 실행 전 원래 상태를 적어 둔다.

## 설치와 첫 실행 (INST)

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| INST-01 | rc 프리릴리스에서 `Desktoto.dmg`를 받아 연다 | dmg 안에 `Desktoto.app`과 `응용 프로그램` 바로가기가 보인다 | ✅ | `docs/ci.md` 릴리스 |
| INST-02 | 앱을 응용 프로그램으로 옮기고 처음 실행한다 | Gatekeeper 경고가 뜨고, 시스템 설정에서 허용하면 실행되어 상단바에 캐릭터가 보인다 | ✅ | `docs/ci.md` 릴리스(ad-hoc 서명, 공증 안 함) |
| INST-03 | 설정을 한 번도 저장하지 않은 Mac에서 처음 실행한다 | 표시 위치 상단바, 캐릭터 토토, 색상 흰색, 테마 시스템 설정에 맞춤, Liquid Glass 보통, 표시할 패널 둘 다 켬이고, 시스템 설정의 로그인 항목에 Desktoto가 등록된다 | | `apps/macos/Sources/Preferences/AppSettings.swift`, `apps/macos/Sources/Preferences/LoginItem.swift` |
| INST-04 | 직전 정식 버전을 쓰다가 rc를 덮어 설치하고 실행한다 | 전에 바꿔 둔 캐릭터, 표시 위치, 테마가 그대로 유지된다 | | `apps/macos/Sources/Preferences/AppSettings.swift` |
| INST-05 | 우클릭 메뉴에서 `Desktoto 종료`를 누른다 (단축키 ⌘Q) | 앱이 종료되고 상단바 캐릭터가 사라진다 | ✅ | `apps/macos/Sources/Preferences/SettingsMenu.swift` |

## 상단바 캐릭터 (ICON)

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| ICON-01 | 토토로 두고 Claude Code 세션에 작업을 시킨다 | 작업하는 동안 토토의 몸 색이 파랑과 보라로 돈다 | | `apps/macos/Sources/MenuBarIcon/TotoArt.swift`, `apps/web/index.html` 상태 섹션 |
| ICON-02 | 토토로 두고 세션이 권한 승인을 기다리게 한다 | 몸 색이 주황과 노랑으로 바뀐다 | | `apps/macos/Sources/MenuBarIcon/TotoArt.swift`, `apps/web/index.html` 상태 섹션 |
| ICON-03 | 토토로 두고 작업이 끝날 때까지 패널을 열지 않는다 | 작업 중 색이 빠지고, 확인하지 않은 완료를 뜻하는 민트 초록 몸 색으로 바뀐다. 패널을 열면 민트 초록이 사라진다 (Claude 캐릭터는 아이콘에 점이 생기고 패널을 열면 사라진다) | ✅ | `apps/macos/Sources/MenuBarIcon/TotoArt.swift`, `docs/tasks/11/verification.md` 실제 이벤트 확인 |
| ICON-04 | 작업이 없는 상태에서 120초 동안 캐릭터를 누르지 않는다 | 토토는 졸고, Claude 캐릭터는 여러 쉬는 동작 중 하나를 한다. 캐릭터를 누르면 바로 깬다 | | `apps/macos/Sources/Desktoto/SleepPolicy.swift`, `apps/macos/Sources/Desktoto/MenuBarIconController.swift`, `docs/tasks/61/spec.md` AC-6, AC-9 |
| ICON-05 | 우클릭 메뉴의 `캐릭터`에서 토토, Claude, 치이카와, 하치와레, 우사기를 차례로 고르고 앱을 다시 켠다 | 고를 때마다 상단바 캐릭터가 바뀌고, 다시 켜도 마지막에 고른 캐릭터가 유지된다 | | `apps/macos/Sources/Preferences/SettingsMenu.swift`, `docs/tasks/65/spec.md` AC-1 |
| ICON-06 | Claude 캐릭터로 두고 작업이 없을 때 마우스를 캐릭터 주변에서 움직인다 | 눈이 마우스 방향을 따라가고, 캐릭터 바로 근처에서는 정면을 본다 | | `docs/tasks/61/spec.md` AC-1 |
| ICON-07 | 치이카와, 하치와레, 우사기 중 하나로 두고 승인 대기를 만든다 | 빨간 물음표가 붙는다 | | `docs/tasks/65/spec.md` AC-7 |
| ICON-08 | 우클릭 메뉴의 `색상`에서 흰색과 컬러를 바꾼다 | 캐릭터가 고른 색으로 바뀌고 다시 켜도 유지된다 | | `docs/tasks/11/verification.md` |

## 노치 봇 (NOTCH)

노치가 있는 Mac에서만 실행한다.

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| NOTCH-01 | 토토로 두고 우클릭 메뉴의 `표시 위치`에서 `노치`를 고른다 | 상단바 토토가 노치 쪽으로 튀어 와 붙고, 상단바 캐릭터는 사라지고 노치 오른쪽에 봇이 보인다 | | `docs/tasks/75/spec.md` AC-2, 이슈 #70 |
| NOTCH-02 | 봇을 왼쪽 클릭한다 | 노치가 아래로 펼쳐지며 사용량 카드와 세션 카드가 보인다 | | 이슈 #70 |
| NOTCH-03 | 펼친 노치를 봇 다시 누르기, Esc, 바깥 클릭으로 각각 닫는다 | 세 방법 모두 노치가 접힌다 | | `docs/tasks/75/spec.md` AC-5, 이슈 #70 |
| NOTCH-04 | 봇을 오른쪽 클릭한다 | 설정 메뉴가 봇 아래에 열린다 | | 이슈 #70, `apps/macos/Sources/Desktoto/NotchBotWindowController.swift` |
| NOTCH-05 | 노치 봇 상태에서 작업, 승인 대기, 완료를 차례로 만든다 | 작업 중에는 몸 색이 파랑과 보라로, 승인 대기 중에는 주황과 노랑으로 바뀌고, 작업이 끝나는 순간 잠깐 웃는다 | | 이슈 #70, `apps/macos/Sources/Desktoto/NotchBotWindowController.swift` |
| NOTCH-06 | 토토로 두고 `표시 위치`를 다시 `상단바`로 고른다 | 봇이 늘어나 떨어져 나가 상단바 토토로 바뀌고, 그 뒤 상단바 캐릭터가 정상 동작한다 | | `docs/tasks/75/spec.md` AC-1 |
| NOTCH-07 | 손쉬운 사용의 `동작 줄이기`를 켜고 표시 위치를 바꾼다 | 전환 애니메이션 없이 바로 바뀐다 | | `docs/tasks/75/spec.md` AC-4 |
| NOTCH-08 | 노치 봇을 고른 채 노치가 없는 화면만 쓰는 상태로 바꾼다 (예: 덮개를 닫고 외부 모니터 사용) | 노치 봇 대신 상단바 캐릭터가 보인다 | | 이슈 #70, `docs/tasks/75/spec.md` AC-4 |

## 세션 감지와 상태 (SESS)

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| SESS-01 | 임시 폴더에서 Claude Code 세션을 실행하고 패널을 연다 | 세션이 목록에 제목(첫 프롬프트)과 함께 보인다 | ✅ | `docs/tasks/11/verification.md` 실제 이벤트 확인 |
| SESS-02 | 세션의 마지막 활동 뒤 10분을 기다린다 | 그 세션이 목록에서 사라진다 | | `apps/macos/Sources/SessionMonitoring/SessionMonitoringPolicy.swift`, `docs/tasks/11/verification.md` |
| SESS-03 | Codex 세션을 실행하고 서브 에이전트나 자동 리뷰가 도는 작업을 시킨다 | 목록에 Codex 스레드 이름이 제목으로 보이고, 서브 에이전트와 자동 리뷰 세션은 보이지 않는다 | | `docs/tasks/11/verification.md` 서브 에이전트와 Codex 제목 |
| SESS-04 | Antigravity 앱에서 대화를 만든다 | 목록에 제목과 마지막 활동이 보이고 작업 중, 승인 대기, 끝남이 구분된다 | | `docs/tasks/52/spec.md` AC-1, AC-2 |
| SESS-05 | 세션이 승인을 기다리게 한다 (질문이면 답을 기다리게 한다) | 해당 줄에 `승인 필요`(질문이면 `답변 필요`) 알약이 붙고 목록 맨 위로 올라온다 | | `apps/macos/Sources/SessionPanel/PanelText.swift`, `docs/tasks/11/verification.md` |
| SESS-06 | 10분 안에 활동한 세션이 없을 때 패널을 연다 | `세션 없음`이 보인다 | | `apps/macos/Sources/SessionPanel/SessionPanelView.swift` |

## 세션 패널 (PANEL)

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| PANEL-01 | 상단바 캐릭터를 왼쪽 클릭하고, 다시 클릭, 바깥 클릭, Esc로 각각 닫는다 | 캐릭터 바로 아래에 유리 패널이 열리고, 세 방법 모두 닫힌다 | ✅ | `docs/tasks/11/verification.md`, `apps/macos/Sources/Desktoto/PanelController.swift` |
| PANEL-02 | `표시할 패널`에서 사용량만 켜기, 컨텍스트만 켜기, 둘 다 끄기를 차례로 한다 | 켠 쪽 카드만 보이고, 둘 다 끄면 캐릭터를 눌러도 패널이 열리지 않는다 | | `docs/tasks/11/verification.md` 새 앱 단독 확인 |
| PANEL-03 | `테마`를 라이트, 다크, 시스템 설정에 맞춤으로 바꾸고 `Liquid Glass` 다섯 단계를 바꾼다 | 패널의 밝기와 유리 투명도가 고른 값대로 바뀌고 다시 켜도 유지된다 | | `apps/macos/Sources/Preferences/SettingsMenu.swift`, `docs/tasks/11/verification.md` |
| PANEL-04 | 패널을 열어 둔 채 2분 이상 기다린다 | 사용량 카드의 초기화까지 남은 시간이 실제 시간만큼 줄어든다 | | `docs/tasks/11/verification.md` 남은 시간이 멈춤 |

## 사용량과 컨텍스트 (USAGE)

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| USAGE-01 | Claude와 Codex를 쓰는 상태에서 패널을 연다 | Claude와 Codex 사용량 카드에 5시간과 주간 사용률, 초기화까지 남은 시간이 보인다 | | `docs/tasks/11/verification.md` |
| USAGE-02 | 같은 시각에 Codex가 보여 주는 사용량과 패널의 Codex 카드를 비교한다 | 사용률과 초기화 시각이 같다 | | `docs/tasks/11/verification.md` 남은 시간이 멈춤 |
| USAGE-03 | 진행 중인 세션이 있을 때 패널의 세션 줄을 본다 | 줄마다 컨텍스트 사용률이 보인다 | | `docs/tasks/11/verification.md` |
| USAGE-04 | `Codex 연동`을 끄고 앱을 다시 켠 뒤 다시 켠다 | 체크 상태가 바꾼 대로 저장되어 다시 켜도 유지된다 | | `docs/tasks/11/verification.md` 새 앱 단독 확인 |

## 터미널 이동 (TERM)

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| TERM-01 | 패널에서 Claude Code 세션 줄을 누른다 | 패널이 닫히고 그 세션이 있는 앱이 앞으로 온다 | ✅ | `docs/tasks/11/verification.md` |
| TERM-02 | iTerm2, Terminal, Orca에서 실행 중인 세션 줄을 각각 누른다 | 해당 터미널이 앞으로 오고 그 세션의 탭이 선택된다 | | `docs/tasks/53/spec.md` AC-6 |
| TERM-03 | cmux 소켓을 자동화 모드로 두고 같은 폴더의 cmux 세션 두 개 중 하나를 누른다 | cmux가 앞으로 오고 누른 세션의 작업 공간과 패널로 이동한다 | | `docs/tasks/53/spec.md` AC-2, AC-4 |
| TERM-04 | VS Code나 Antigravity IDE의 통합 터미널에서 실행 중인 세션 줄을 누른다 | 그 IDE 앱이 앞으로 온다 | | `docs/tasks/53/spec.md` AC-10 |
| TERM-05 | 우클릭 메뉴의 `사용 안내…`를 누른다 | 안내 창이 뜨고 cmux 탭 이동 설정 방법, Antigravity 한도 미지원, IDE 터미널에서는 앱만 앞으로 온다는 내용이 있다 | | `docs/tasks/53/spec.md` AC-8, AC-9 |

## Claude Code 연동 (CLAUDE)

`~/.claude/settings.json`을 바꾸는 항목이다. 실행 전에 이 파일을 따로 복사해 두고 끝나면 원래대로 되돌린다.

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| CLAUDE-01 | Desktoto 설정을 한 번도 저장하지 않았고 Claude Code가 설치된 Mac에서 처음 실행한다 | `settings.json`에 앱의 훅과 statusLine이 연결되고 같은 폴더에 변경 전 백업 파일이 생긴다. 우클릭 메뉴의 `Claude 연동`이 체크되어 있다 | | `apps/macos/Sources/Preferences/AppSettings.swift`(연동 기본값 켬), `apps/macos/Sources/Desktoto/AppDelegate.swift`, `docs/tasks/7/spec.md` AC-5 |
| CLAUDE-02 | Claude Code가 설치된 Mac에서 우클릭 메뉴를 연다 | `Claude 연동` 항목이 보이고, 체크 상태가 `settings.json`에 앱의 훅과 statusLine이 연결되어 있는지와 같다 | | `apps/macos/Sources/Preferences/SettingsMenu.swift`, `docs/tasks/11/verification.md` 연동 판정 |
| CLAUDE-03 | `Claude 연동`을 끈다 | `settings.json`에서 앱의 훅이 빠지고 statusLine은 연결 전 상태로 돌아가며, 다른 훅과 사용자 설정은 그대로다. 같은 폴더에 변경 전 백업 파일이 생긴다 | | `docs/tasks/7/spec.md` AC-1, AC-2, AC-5 |
| CLAUDE-04 | `Claude 연동`을 다시 켠다 | 앱의 `permission_prompt` 훅과 statusLine이 중복 없이 추가되고, 기존에 쓰던 statusLine 명령의 출력이 그대로 보인다 | | `docs/tasks/7/spec.md` AC-1, AC-2 |
| CLAUDE-05 | 연동을 켠 상태에서 Claude Code가 권한을 묻게 한다 | 캐릭터와 패널에 승인 대기가 표시된다 (ICON-02, SESS-05와 같은 표시) | | `docs/tasks/11/verification.md` 실제 이벤트 확인 |

## 알림과 소리 (NOTI)

시스템 설정의 알림에서 Desktoto 알림이 허용되어 있어야 한다.

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| NOTI-01 | 세션의 작업이 끝날 때까지 기다린다 | macOS 알림이 오고, 제목은 세션 제목(없으면 프로젝트 이름), 본문은 `작업이 끝났어요`다 | ✅ | `apps/macos/Sources/Desktoto/NotificationText.swift` |
| NOTI-02 | 세션이 승인을 기다리게 한다 (질문이면 답을 기다리게 한다) | 본문이 `승인이 필요해요`(질문이면 `답변이 필요해요`)인 알림이 온다 | | `apps/macos/Sources/Desktoto/NotificationText.swift` |
| NOTI-03 | 받은 알림을 누른다 | 그 세션이 있는 앱이 앞으로 온다 | | `docs/tasks/8/spec.md` AC-7, AC-11 |
| NOTI-04 | `알림 보내기`를 끄고 작업을 끝낸다 | 알림이 오지 않는다. 다시 켜면 다음 완료부터 알림이 온다 | | `docs/tasks/11/verification.md` 새 앱 단독 확인 |
| NOTI-05 | 치이카와, 하치와레, 우사기 중 하나로 두고 완료와 승인 대기를 만든다 | 캐릭터별 완료 소리와 승인 대기 소리가 난다 | | `docs/tasks/65/spec.md` AC-6 |

## 설정과 로그인 항목 (PREF)

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| PREF-01 | `로그인 시 자동 실행`을 끄고 켠 뒤 시스템 설정의 로그인 항목을 본다 | 켜면 Desktoto가 로그인 항목에 있고 끄면 없다 | | `docs/tasks/8/spec.md` AC-8, AC-11 |
| PREF-02 | 상단바 캐릭터를 오른쪽 클릭한다 | 설정 메뉴가 열리고 로그인 시 자동 실행, 알림 보내기, Codex 연동, Claude 연동(설치된 경우), 업데이트 확인, 사용 안내…, 문의하기…, 표시할 패널, 색상, 캐릭터, 표시 위치, 테마, Liquid Glass, Desktoto 종료가 이 순서로 보인다 | ✅ | `apps/macos/Sources/Preferences/SettingsMenu.swift` |
| PREF-03 | 체크 항목과 하위 메뉴 값을 몇 가지 바꾸고 앱을 다시 켠다 | 바꾼 값이 모두 유지된다 | | `apps/macos/Sources/Preferences/AppSettings.swift` |

## 새 버전 알림 (UPD)

rc는 직전 정식 버전보다 새 버전이라 rc 앱에는 안내가 나오지 않는다. 안내가 나오는 경우는 직전 정식 버전 앱으로 확인한다.

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| UPD-01 | rc 앱에서 우클릭 메뉴를 연다 | 맨 위에 새 버전 안내 항목이 없다 | | `apps/macos/Sources/Preferences/SettingsMenu.swift`, `apps/macos/Sources/UpdateCheck/ReleaseFetcher.swift` |
| UPD-02 | 직전 정식 버전 앱이 현재 최신 정식 릴리스보다 낮을 때 우클릭 메뉴를 연다 | 맨 위에 `새 버전이 있어요 (v버전)`이 보이고, Homebrew로 설치했으면 뒤에 `brew upgrade --cask desktoto`가 붙는다. 누르면 릴리스 페이지가 열린다 | | `apps/macos/Sources/UpdateCheck/UpdateNoticeText.swift`, `docs/tasks/24/spec.md` AC-5 |
| UPD-03 | `업데이트 확인`을 끄고 다시 켠다 | 끄면 안내 항목이 사라지고, 체크 상태가 다시 켜도 유지된다 | | `docs/tasks/24/spec.md` AC-6 |
| UPD-04 | 네트워크를 끈 채 앱을 실행한다 | 오류 창 없이 실행되고 안내 항목이 없다 | | `docs/tasks/24/spec.md` AC-4 |

## 피드백 (FEED)

릴리스 빌드의 문의하기는 운영 Discord 채널로 보낸다. QA에서는 실제로 보내지 않는다.

| ID | 절차 | 기대 결과 | smoke | 근거 |
|---|---|---|---|---|
| FEED-01 | rc 앱의 우클릭 메뉴를 연다 | `사용 안내…` 바로 뒤에 `문의하기…`가 있다 | | `docs/tasks/56/spec.md` AC-5, AC-8 |
| FEED-02 | `문의하기…`를 누르고, 창이 열린 채 한 번 더 누른다 | 상단바 캐릭터 아래에 입력창, 글자 수, 보내기 버튼이 있는 창이 열리고, 두 번째에는 새 창 없이 그 창이 앞으로 온다 | | `docs/tasks/56/spec.md` AC-5, AC-6 |
| FEED-03 | 입력창을 비우거나 공백만 넣는다 | 보내기를 할 수 없다 | | `docs/tasks/56/spec.md` AC-4 |
