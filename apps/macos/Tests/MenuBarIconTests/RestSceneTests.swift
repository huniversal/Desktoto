import CoreGraphics
import Foundation
import Testing
@testable import MenuBarIcon

private let timelineActivities = IconRest.allCases.filter { RestTimeline.cycleSteps(for: $0) != nil }

private func pieces(_ activity: IconRest, step: Int) -> [IconPiece] {
    RestScenes.pieces(frame: RestFrame(activity: activity, step: step), bodyColor: IconPalette.whiteBody)
}

@Test func allRestActivitiesExistAndOnlySleepingAndFishingMoveOnTheirOwn() {
    #expect(IconRest.allCases.count == 8)
    #expect(Set(timelineActivities) == [.sparkler, .music, .drink, .stargazing, .rain, .bubbles])
    #expect(RestTimeline.cycleSteps(for: .sleeping) == nil)
    #expect(RestTimeline.cycleSteps(for: .fishing) == nil)
}

@Test func timelineStepsAdvanceWithTimeAndLoop() {
    timelineActivities.forEach { activity in
        let count = RestTimeline.cycleSteps(for: activity) ?? 0
        let first = RestTimeline.frame(activity: activity, elapsed: 0)
        let second = RestTimeline.frame(activity: activity, elapsed: RestTimeline.stepInterval + 0.01)
        let wrapped = RestTimeline.frame(activity: activity, elapsed: RestTimeline.stepInterval * Double(count) + 0.01)

        #expect(first?.step == 0)
        #expect(second?.step == 1)
        #expect(wrapped?.step == 0)
    }
    #expect(RestTimeline.frame(activity: .sleeping, elapsed: 5) == nil)
    #expect(RestTimeline.frame(activity: .sparkler, elapsed: -3)?.step == 0)
}

@Test func everySceneStaysInsideTheCanvasAtEveryStep() {
    timelineActivities.forEach { activity in
        (0..<(RestTimeline.cycleSteps(for: activity) ?? 0)).forEach { step in
            let list = pieces(activity, step: step)
            #expect(!list.isEmpty)
            list.forEach { piece in
                let rect = piece.rect
                #expect(rect.x >= 0, "\(activity) \(step)")
                #expect(rect.y >= 0, "\(activity) \(step)")
                #expect(rect.x + rect.width <= CharacterGrid.canvasWidth, "\(activity) \(step)")
                #expect(rect.y + rect.height <= CharacterGrid.canvasHeight, "\(activity) \(step)")
            }
        }
    }
}

@Test func everySceneKeepsTheCharacterBody() {
    timelineActivities.forEach { activity in
        (0..<(RestTimeline.cycleSteps(for: activity) ?? 0)).forEach { step in
            let bodyPieces = pieces(activity, step: step).filter { $0.color == IconPalette.whiteBody }
            #expect(bodyPieces.count >= 5, "\(activity) \(step)")
        }
    }
}

@Test func everySceneAnimatesInsteadOfStandingStill() {
    timelineActivities.forEach { activity in
        let count = RestTimeline.cycleSteps(for: activity) ?? 0
        let distinct = Set((0..<count).map { step in pieces(activity, step: step).map { "\($0.rect.x),\($0.rect.y),\($0.rect.width),\($0.rect.height)" }.joined(separator: ";") })

        #expect(distinct.count >= 4, "\(activity)")
    }
}

@Test func sparklerStickShortensAndSparksStopWhenItGoesOut() {
    func stickCount(_ step: Int) -> Int { pieces(.sparkler, step: step).filter { $0.color == IconColor.gray(white: 0.78, alpha: 1) }.count }
    func sparkCount(_ step: Int) -> Int {
        pieces(.sparkler, step: step).filter {
            $0.color == IconColor.calibrated(red: 1.00, green: 0.88, blue: 0.40, alpha: 1) || $0.color == IconColor.calibrated(red: 1.00, green: 0.60, blue: 0.20, alpha: 1)
        }.count
    }

    #expect(stickCount(5) > stickCount(30))
    #expect(sparkCount(10) > 0)
    #expect(sparkCount(38) == 0)
}

@Test func theMusicalCharacterWearsHeadphonesAndNotesAreVisible() {
    let list = pieces(.music, step: 3)
    let pink = IconColor.calibrated(red: 0.95, green: 0.30, blue: 0.52, alpha: 1)
    let note = IconColor.calibrated(red: 1.00, green: 0.86, blue: 0.35, alpha: 1)

    #expect(list.contains { $0.color == pink })
    #expect(list.contains { $0.color == note })
}

@Test func steamOnlyRisesAboveTheMug() {
    let steam = IconColor.gray(white: 1, alpha: 0.85)
    (0..<24).forEach { step in
        let mugTop = pieces(.drink, step: step).filter { $0.color == IconColor.calibrated(red: 0.38, green: 0.22, blue: 0.12, alpha: 1) }.map(\.rect.y).min() ?? 99
        pieces(.drink, step: step).filter { $0.color.alphaIsBelowOne }.forEach { piece in
            #expect(piece.rect.y < mugTop, "step \(step)")
        }
        _ = steam
    }
}

@Test func theShootingStarOnlyPassesInTheMiddleOfTheCycle() {
    let streak = IconColor.gray(white: 1, alpha: 1)
    func hasStreakHead(_ step: Int) -> Bool {
        pieces(.stargazing, step: step).contains { $0.color == streak && $0.rect.x >= 31 && $0.rect.y <= 10 && $0.rect.width == 1 }
    }

    #expect(hasStreakHead(15))
    #expect(!hasStreakHead(2))
    #expect(!hasStreakHead(25))
}

@Test func raindropsStayOutsideTheUmbrella() {
    let drop = IconColor.calibrated(red: 0.62, green: 0.82, blue: 1.00, alpha: 0.9)
    (0..<8).forEach { step in
        pieces(.rain, step: step).filter { $0.color == drop }.forEach { piece in
            #expect(piece.rect.x < 10 || piece.rect.x >= 34, "step \(step)")
        }
    }
}

@Test func bubblesAppearGrowAndPop() {
    let outline = IconColor.calibrated(red: 0.35, green: 0.72, blue: 1.00, alpha: 1)
    let pop = IconColor.calibrated(red: 0.62, green: 0.85, blue: 1.00, alpha: 0.9)
    func outlineCount(_ step: Int) -> Int { pieces(.bubbles, step: step).filter { $0.color == outline }.count }

    #expect(outlineCount(1) > 0)
    #expect(outlineCount(8) > outlineCount(1))
    #expect(pieces(.bubbles, step: 12).contains { $0.color == pop })
}

@Test func restSceneKeepsTheUnseenDoneDot() {
    let frame = RestFrame(activity: .sparkler, step: 10)
    let plain = IconScene.pieces(frame: .rest(frame), appearance: IconAppearance())
    let withDot = IconScene.pieces(frame: .rest(frame), appearance: IconAppearance(hasUnseenDone: true))

    #expect(!plain.contains { $0.color == IconPalette.doneDot })
    #expect(withDot.contains { $0.color == IconPalette.doneDot })
}

@Test func scheduleUsesTheRestingTimerForTheTimelineActivities() {
    timelineActivities.forEach { activity in
        #expect(IconSchedule(isRunning: false, hasFirework: false, rest: activity) == .resting)
        #expect(IconSchedule(isRunning: true, hasFirework: false, rest: activity) == .running)
    }
    #expect(IconSchedule.resting.interval == IconTiming.restTickInterval)
}

private extension IconColor {
    var alphaIsBelowOne: Bool {
        switch self {
        case .gray(_, let alpha), .calibrated(_, _, _, let alpha), .srgb(_, _, _, let alpha): return alpha < 1
        }
    }
}
