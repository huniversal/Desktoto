# 릴리스 QA

정식 릴리스 전에 실제 릴리스 산출물로 제품 전체를 확인하는 절차다.
이슈 하나의 검증은 [작업 흐름](workflow.md)의 명세 AC와 검증 표가 맡고,
릴리스 QA는 여러 이슈가 합쳐진 뒤 다른 기능이 깨지지 않았는지 보는 회귀 확인과 출시 판단을 맡는다.
확인할 시나리오는 [QA 시나리오](../qa/scenarios.md)에 있다.

## 왜 rc 산출물로 하는가

로컬 빌드(`swift run`, `build-app.sh`)로는 사용자가 받는 앱과 같은 조건을 만들 수 없다.
ad-hoc 서명과 Gatekeeper 경고, 릴리스 빌드에만 들어가는 `Info.plist` 값(`FeedbackWebhookURL`), dmg 구성은 릴리스 워크플로가 만든 산출물에서만 확인된다.

`vX.Y.Z-rc.N` 태그는 [릴리스 워크플로](../../.github/workflows/release.yml)가 프리릴리스로 올린다.
프리릴리스는 다음 경로에서 모두 제외되므로 main에 머지하기 전 develop 커밋에 달아도 사용자에게 나가지 않는다.

- 앱의 새 버전 알림: GitHub `releases/latest` API를 읽는다(`apps/macos/Sources/UpdateCheck/ReleaseFetcher.swift`).
- 랜딩 페이지 다운로드: `releases/latest/download/Desktoto.dmg`를 쓴다.
- Homebrew: `update-tap` job이 프리릴리스를 건너뛴다.

GitHub Releases 페이지에는 "Pre-release"로 보인다.

## 절차

태그 push, develop → main 머지, 정식 태그 push는 단계마다 사용자 승인을 받고 진행한다.

1. **릴리스 범위 확인**: 직전 정식 태그 이후 develop에 들어온 변경을 보고 릴리스 종류(major, minor, patch)와 QA 범위를 정한다.

   ```bash
   git fetch origin --tags
   git log --oneline v이전버전..origin/develop
   ```

2. **rc 태그**: develop의 릴리스 후보 커밋에 rc 태그를 단다. 같은 버전의 첫 후보는 `rc.1`이다.

   ```bash
   git tag v0.4.0-rc.1 origin/develop
   git push origin v0.4.0-rc.1
   ```

   릴리스 워크플로가 성공했는지 Actions에서 확인한다. 실패하면 QA를 시작하지 않고 원인을 고친다.

3. **QA 이슈 작성**: 제목 `[Deploy] v0.4.0 릴리스 QA`, 라벨 `🚀 Deploy`로 이슈를 만든다.
   본문에 rc 태그, 릴리스 종류, 환경(macOS 버전, Mac 모델과 노치 유무, 설치 방법, 연동할 외부 앱과 버전)을 적고,
   이번 범위의 시나리오를 [QA 시나리오](../qa/scenarios.md)에서 체크리스트로 복사한다.
   rc 번호가 바뀌어도 같은 이슈를 계속 쓴다.

4. **산출물 설치**: 프리릴리스 페이지에서 `Desktoto.dmg`를 받아 설치한다.
   필요하면 같은 페이지의 `.sha256`과 비교한다(`shasum -a 256 Desktoto.dmg`).
   minor 이상이면 기존 버전 위에 덮어 설치하는 경우를 함께 확인한다.

5. **시나리오 실행**: 시나리오대로 실행하고 항목마다 Pass, Fail, 미검증 중 하나를 기록한다.
   Fail은 결함 이슈 번호를, 미검증은 이유를 함께 적는다.

6. **결함 등록**: Fail마다 [결함 템플릿](../../.github/ISSUE_TEMPLATE/bug_report.md)으로 이슈를 만들고 QA 이슈 번호를 적는다.
   재현 절차와 첨부(스크린샷, 녹화, 로그)로 다른 사람도 같은 결과를 볼 수 있게 한다.

7. **수정과 다음 rc**: 결함은 [작업 흐름](workflow.md)대로 이슈 브랜치에서 고쳐 develop에 머지한다.
   수정이 모이면 rc 번호를 올려(`v0.4.0-rc.2`) 2단계부터 다시 하되, QA는 아래 두 가지만 한다.
   - 재테스트: Fail이었던 시나리오를 같은 절차로 다시 실행해 고쳐졌는지 본다.
   - 회귀 확인: 수정한 기능 주변의 시나리오와 smoke 시나리오를 다시 실행해 다른 곳이 깨지지 않았는지 본다.

8. **종료 판단**: 아래 [종료 기준](#종료-기준)을 QA 이슈에 적고 출시 여부를 정한다.

9. **main 머지와 정식 태그**: develop → main PR을 머지한 뒤, main이 마지막으로 QA한 rc와 같은 코드인지 확인하고 정식 태그를 단다.

   ```bash
   git fetch origin
   git diff --stat v0.4.0-rc.2 origin/main
   git tag v0.4.0 origin/main
   git push origin v0.4.0
   ```

   `git diff`에 차이가 나오면 정식 태그를 달지 않는다. 그 차이를 포함한 새 rc로 다시 QA한다.
   정식 릴리스와 Homebrew 갱신이 끝나면 QA 이슈에 결과를 남기고 닫는다.

## 릴리스 종류별 범위

| 릴리스 | 예 | QA 범위 |
|---|---|---|
| major, minor | v0.3.1 → v0.4.0 | 전체 시나리오 |
| patch | v0.4.0 → v0.4.1 | 바뀐 기능과 그 주변 시나리오, smoke 시나리오 |
| 다음 rc | rc.1 → rc.2 | 재테스트와 회귀 확인 (절차 7단계) |

## 결함 심각도

| 심각도 | 기준 |
|---|---|
| 치명 | 앱이 실행되지 않음, 크래시, 사용자 파일이나 설정 손상 |
| 높음 | 핵심 기능이 동작하지 않고 우회 방법이 없음 |
| 중간 | 기능 오류가 있지만 우회 방법이 있음 |
| 낮음 | 외관, 문구 |

`~/.claude/settings.json` 같은 사용자 파일을 잘못 바꾸는 결함은 우회 방법이 있어도 치명이다.

## 종료 기준

- 치명과 높음 결함이 0건이다.
- 이번 범위의 시나리오가 전부 Pass다.
- 중간과 낮음 결함은 다음 버전 이슈로 남기고 출시할 수 있다. QA 이슈에 그 이슈 번호를 적는다.

시나리오 수가 적어서 통과율 같은 비율 기준은 쓰지 않는다.

## 미검증 처리

환경 때문에 실행하지 못한 시나리오(노치가 없는 Mac, 설치되지 않은 터미널 등)는 Pass로 표시하지 않는다.
미검증과 이유를 기록하고, 미검증이 남은 상태로 출시할지는 사용자가 판단한다.

## QA 기록과 개인정보

QA는 실제 Mac의 실제 세션으로 하지만 기록은 공개 저장소의 이슈에 남는다.
이슈와 첨부에 세션 내용, 프롬프트, 토큰, 개인 경로, webhook 주소를 남기지 않는다.
스크린샷과 녹화에 이런 내용이 보이면 가리거나 합성 세션으로 다시 찍는다.

사용자 환경을 바꾸는 시나리오(Claude 연동, 로그인 항목)는 실행 전에 원래 상태를 적어 두고 끝난 뒤 되돌린다.
