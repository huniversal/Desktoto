import Testing
@testable import Desktoto

struct NotificationTextTests {
    @Test func 제목이_있으면_제목을_쓴다() {
        let session = makeSession(projectName: "proj", title: "로그인 고치기")

        #expect(NotificationText.title(for: session) == "로그인 고치기")
    }

    @Test func 제목이_없으면_프로젝트_이름을_쓴다() {
        #expect(NotificationText.title(for: makeSession(projectName: "proj")) == "proj")
    }

    @Test func 제목이_빈_문자열이면_프로젝트_이름을_쓴다() {
        #expect(NotificationText.title(for: makeSession(projectName: "proj", title: "")) == "proj")
    }

    @Test func 세션을_모르면_AI를_쓴다() {
        #expect(NotificationText.title(for: nil) == "AI")
    }

    @Test func 제목이_40자를_넘으면_자르고_말줄임표를_붙인다() {
        let title = String(repeating: "가", count: 41)

        let result = NotificationText.title(for: makeSession(title: title))

        #expect(result == "\(String(repeating: "가", count: 40))…")
    }

    @Test func 제목이_정확히_40자면_자르지_않는다() {
        let title = String(repeating: "a", count: 40)

        #expect(NotificationText.title(for: makeSession(title: title)) == title)
    }

    @Test func 대기_종류에_따라_본문이_다르다() {
        #expect(NotificationText.waitingBody(for: .question) == "답변이 필요해요")
        #expect(NotificationText.waitingBody(for: .approval) == "승인이 필요해요")
    }

    @Test func 완료_본문() {
        #expect(NotificationText.finishedBody == "작업이 끝났어요")
    }
}
