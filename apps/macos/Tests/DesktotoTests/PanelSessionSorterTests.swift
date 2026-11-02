import Testing
@testable import Desktoto

struct PanelSessionSorterTests {
    @Test func 대기_진행_방금_끝남_나머지_순서로_정렬한다() {
        let sessions = [
            makeSession(id: "other"),
            makeSession(id: "finished"),
            makeSession(id: "running", isRunning: true),
            makeSession(id: "waiting", waitingKind: .approval)
        ]

        let sorted = PanelSessionSorter.sorted(sessions, finishedIDs: ["finished"])

        #expect(sorted.map(\.id) == ["waiting", "running", "finished", "other"])
    }

    @Test func 같은_순위는_받은_순서를_지킨다() {
        let sessions = ["c", "a", "b"].map { makeSession(id: $0) }

        let sorted = PanelSessionSorter.sorted(sessions, finishedIDs: [])

        #expect(sorted.map(\.id) == ["c", "a", "b"])
    }

    @Test func 대기_중이면서_진행_중인_세션은_대기로_본다() {
        let sessions = [
            makeSession(id: "running", isRunning: true),
            makeSession(id: "both", isRunning: true, waitingKind: .question)
        ]

        let sorted = PanelSessionSorter.sorted(sessions, finishedIDs: [])

        #expect(sorted.map(\.id) == ["both", "running"])
    }

    @Test func 진행_중인_세션은_완료_목록에_있어도_진행_중_순위다() {
        let sessions = [
            makeSession(id: "finished"),
            makeSession(id: "running", isRunning: true)
        ]

        let sorted = PanelSessionSorter.sorted(sessions, finishedIDs: ["finished", "running"])

        #expect(sorted.map(\.id) == ["running", "finished"])
    }

    @Test func 빈_목록은_빈_목록이다() {
        #expect(PanelSessionSorter.sorted([], finishedIDs: []).isEmpty)
    }
}
