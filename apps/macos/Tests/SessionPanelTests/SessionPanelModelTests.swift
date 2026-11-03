import Domain
import Foundation
import Testing
@testable import SessionPanel

@MainActor
struct SessionPanelModelTests {
    private func makeModel() -> SessionPanelModel {
        SessionPanelModel(now: Date(timeIntervalSince1970: 0))
    }

    // AC-8
    @Test func openCallsBackOnlyWhenSessionCanBeOpened() {
        let model = makeModel()
        var openedIDs: [String] = []
        model.onOpenSession = { openedIDs.append($0.id) }

        model.open(makeSession(id: "link", openURL: URL(string: "https://example.com")))
        model.open(makeSession(id: "terminal", isTerminalSession: true))
        model.open(makeSession(id: "none"))

        #expect(openedIDs == ["link", "terminal"])
    }

    @Test func justFinishedNeedsFinishedIDAndNotRunning() {
        let model = makeModel()
        model.finishedIDs = ["done", "running"]

        #expect(model.isJustFinished(makeSession(id: "done")))
        #expect(!model.isJustFinished(makeSession(id: "running", isRunning: true)))
        #expect(!model.isJustFinished(makeSession(id: "other")))
    }

    @Test func hoverIsClearedOnlyByTheRowThatHoldsIt() {
        let model = makeModel()
        let first = makeSession(id: "first")
        let second = makeSession(id: "second")

        model.changeHover(of: first, isInside: true)
        model.changeHover(of: second, isInside: true)
        model.changeHover(of: first, isInside: false)
        #expect(model.hoveredID == "second")

        model.changeHover(of: second, isInside: false)
        #expect(model.hoveredID == nil)
    }

    @Test func startsWithOriginalDefaults() {
        let model = makeModel()

        #expect(model.showsUsage)
        #expect(model.showsContext)
        #expect(model.colorMode == .white)
        #expect(model.glassStyle == .regular)
        #expect(model.sessions.isEmpty)
        #expect(model.usages.isEmpty)
    }
}
