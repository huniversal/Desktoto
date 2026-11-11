import CoreGraphics
import Foundation
import Testing
@testable import MiniGame

private let court = RallyCourt(
    bounds: CGRect(x: 0, y: 0, width: 1600, height: 1000),
    serveOrigin: CGPoint(x: 1300, y: 970)
)
private let wideCourt = RallyCourt(
    bounds: CGRect(x: 800, y: 0, width: 800, height: 1000),
    serveOrigin: CGPoint(x: 1300, y: 970),
    characterRange: 900...1500
)
private let farAway = CGPoint(x: -5000, y: -5000)
private let step: TimeInterval = 1.0 / 60

private func middle() -> Double { 0.5 }

/// 서브가 나갈 때까지 시간을 흘린다.
private func makeServedGame(court: RallyCourt = court, bestScore: Int = 0, random: @escaping () -> Double = middle) -> RallyGame {
    var game = RallyGame(court: court, bestScore: bestScore)
    game.update(deltaTime: RallyGame.serveDelay + 0.01, racket: farAway, random: random)
    return game
}

/// 셔틀콕이 y 높이까지 내려오는 데 걸리는 프레임 수. 라켓이 닿기 전에는 셔틀콕이 라켓의 영향을 받지 않아서 미리 알 수 있다.
private func framesUntilShuttleDrops(to y: CGFloat, in game: RallyGame) -> Int {
    var probe = game
    var frames = 0
    while frames < 1200, !(probe.shuttle.y <= y && probe.velocity.dy < 0) {
        probe.update(deltaTime: step, racket: farAway, random: middle)
        frames += 1
    }
    return frames
}

/// frames프레임 뒤의 셔틀콕에 라켓을 갖다 댄다. offset은 셔틀콕이 라켓 중심보다 오른쪽에 있는 거리다.
private func hit(_ game: inout RallyGame, after frames: Int, offset: CGFloat = 0) {
    var probe = game
    (0..<frames).forEach { _ in probe.update(deltaTime: step, racket: farAway, random: middle) }
    let target = probe.shuttle

    for update in 1...frames {
        let racket = update == frames ? CGPoint(x: target.x - offset, y: target.y) : farAway
        game.update(deltaTime: step, racket: racket, random: middle)
    }
}

/// 라켓으로 받아치고, 캐릭터가 다시 쳐 보내서 셔틀콕이 내려오기 시작할 때까지 진행한다.
private func playOneRally(_ game: inout RallyGame, offset: CGFloat = 0) {
    let frames = framesUntilShuttleDrops(to: 640, in: game)
    hit(&game, after: frames, offset: offset)
    for _ in 0..<900 where !(game.velocity.dy < 0 && game.shuttle.y > 800) && game.phase == .rallying {
        game.update(deltaTime: step, racket: farAway, random: middle)
    }
}

// MARK: 서브와 낙하

@Test func gameStartsServingWithASingleLife() {
    let game = RallyGame(court: court)

    #expect(game.phase == .serving(remaining: RallyGame.serveDelay))
    #expect(game.lives == 1)
    #expect(game.score == 0)
}

@Test func serveStartsFromTheCharacterAndHeadsDown() {
    let game = makeServedGame()

    #expect(game.phase == .rallying)
    #expect(game.shuttle == court.serveOrigin)
    #expect(game.velocity.dy < 0)
}

@Test func shuttleFallsUnderGravity() {
    var game = makeServedGame()
    let startY = game.shuttle.y
    let startSpeed = game.velocity.dy

    game.update(deltaTime: 0.1, racket: farAway, random: middle)

    #expect(game.shuttle.y < startY)
    #expect(game.velocity.dy < startSpeed)
}

// MARK: 라켓에 닿으면 돌아간다

@Test func touchingTheShuttleScoresAtOnceAndSendsItUp() {
    var game = makeServedGame()
    let frames = framesUntilShuttleDrops(to: 640, in: game)

    hit(&game, after: frames)

    #expect(game.score == 1)
    #expect(game.combo == 1)
    #expect(game.velocity.dy > 0)
}

@Test func theCharacterSendsTheShuttleBackDownAndTheRallyContinues() {
    var game = makeServedGame()
    playOneRally(&game)

    #expect(game.phase == .rallying)
    #expect(game.velocity.dy < 0)
    // 캐릭터는 셔틀콕이 올라온 자리에서 쳤다.
    #expect(game.characterX == game.shuttle.x)
}

@Test func anyTouchSendsTheShuttleBackToTheCharacterWhereverTheRacketHitsIt() {
    [-40, -20, 0, 20, 40].forEach { offset in
        var game = makeServedGame(court: wideCourt)
        playOneRally(&game, offset: CGFloat(offset))

        #expect(game.phase == .rallying)
        #expect(game.velocity.dy < 0)
        #expect(game.characterX == game.shuttle.x)
    }
}

@Test func hitPositionOnTheRacketSetsWhichSideTheShuttleGoes() {
    func horizontalVelocity(offset: CGFloat) -> CGFloat {
        var game = makeServedGame(court: wideCourt)
        let frames = framesUntilShuttleDrops(to: 640, in: game)
        hit(&game, after: frames, offset: offset)
        return game.velocity.dx
    }

    // 셔틀콕이 라켓의 오른쪽에 맞으면 오른쪽으로 간다.
    #expect(horizontalVelocity(offset: 30) > horizontalVelocity(offset: -30))
}

@Test func hitPositionMakesTheCharacterRunThatWay() {
    // 셔틀콕이 캐릭터 왼쪽에서 내려오면 오른쪽으로, 오른쪽에서 내려오면 왼쪽으로 보내서 캐릭터가 달려 닿게 한다.
    func target(serveRandom: Double, offset: CGFloat) -> (target: CGFloat, start: CGFloat) {
        var game = makeServedGame(court: wideCourt, random: { serveRandom })
        let frames = framesUntilShuttleDrops(to: 640, in: game)
        hit(&game, after: frames, offset: offset)
        return (game.characterTargetX, game.characterX)
    }

    let toRight = target(serveRandom: 0.5, offset: 30)
    let toLeft = target(serveRandom: 1, offset: -30)

    #expect(toRight.target > toRight.start)
    #expect(toLeft.target < toLeft.start)
}

@Test func theShuttleIsPulledInsideTheCharactersRange() {
    var game = makeServedGame(court: wideCourt)
    let frames = framesUntilShuttleDrops(to: 640, in: game)
    hit(&game, after: frames, offset: -44)

    #expect(wideCourt.characterRange.contains(game.characterTargetX))
}

// MARK: 놓침과 끝

@Test func missingTheShuttleEndsTheGameBecauseThereIsOnlyOneLife() {
    var game = makeServedGame()

    for _ in 0..<600 where game.phase == .rallying {
        game.update(deltaTime: step, racket: farAway, random: middle)
    }

    #expect(game.phase == .over)
    #expect(game.lives == 0)
    #expect(game.combo == 0)
}

@Test func nothingChangesAfterTheGameIsOverUntilRestart() {
    var game = RallyGame(court: court, bestScore: 7)
    for _ in 0..<5000 where game.phase != .over {
        game.update(deltaTime: step, racket: farAway, random: middle)
    }
    #expect(game.phase == .over)

    let revisionBefore = game.revision
    game.update(deltaTime: 1, racket: farAway, random: middle)
    #expect(game.revision == revisionBefore)

    game.restart()
    #expect(game.lives == 1)
    #expect(game.score == 0)
    #expect(game.bestScore == 7)
    #expect(game.phase == .serving(remaining: RallyGame.serveDelay))
}

@Test func bestScoreRisesWithTheScore() {
    var game = makeServedGame(bestScore: 0)
    playOneRally(&game)

    #expect(game.bestScore == 1)
}

@Test func revisionChangesOnlyWhenTheScoreChangesOrThePhaseChanges() {
    var game = RallyGame(court: court)
    let initial = game.revision

    game.update(deltaTime: 0.5, racket: farAway, random: middle)
    #expect(game.revision == initial)

    game.update(deltaTime: 0.6, racket: farAway, random: middle)
    #expect(game.revision == initial + 1)
}

@Test func shuttleBouncesOffTheScreenEdges() {
    var game = makeServedGame(random: { 0 })

    for _ in 0..<400 where game.phase == .rallying {
        game.update(deltaTime: step, racket: farAway, random: { 0 })
        #expect(game.shuttle.x >= court.bounds.minX)
        #expect(game.shuttle.x <= court.bounds.maxX)
    }
}

// MARK: 점수가 오를수록 빨라진다

@Test func gameGetsFasterAsTheScoreRises() {
    var game = makeServedGame()
    #expect(game.timeScale == 1)

    var firstReturnSpeed: CGFloat?
    var lastReturnSpeed: CGFloat = 0
    for _ in 0..<12 {
        playOneRally(&game)
        let returnSpeed = abs(game.velocity.dy)
        firstReturnSpeed = firstReturnSpeed ?? returnSpeed
        lastReturnSpeed = returnSpeed
    }

    #expect(game.score >= 12)
    #expect(game.timeScale > 1.2)
    // 캐릭터가 쳐 보내는 속도도 빨라진다.
    #expect(lastReturnSpeed > (firstReturnSpeed ?? .infinity))
}

@Test func timeScaleStopsRisingAtTheCap() {
    var game = makeServedGame()
    for _ in 0..<(RallyGame.maxDifficultyScore + 5) {
        playOneRally(&game)
    }

    #expect(game.score > RallyGame.maxDifficultyScore)
    #expect(game.timeScale == RallyGame.maxTimeScale)
}

// MARK: 캐릭터 이동

@Test func characterStaysPutWithoutARange() {
    var game = makeServedGame()
    (0..<120).forEach { _ in game.update(deltaTime: step, racket: farAway, random: { 0 }) }

    #expect(game.characterX == court.serveOrigin.x)
    #expect(!game.isCharacterRunning)
}

@Test func characterFollowsTheFallingShuttleSideways() {
    var game = makeServedGame(court: wideCourt, random: { 0 })
    let start = game.characterX

    // 셔틀콕은 왼쪽으로 떨어진다. 캐릭터도 왼쪽으로 따라 달린다.
    (0..<20).forEach { _ in game.update(deltaTime: step, racket: farAway, random: { 0 }) }

    #expect(game.shuttle.x < start)
    #expect(game.characterTargetX == max(wideCourt.characterRange.lowerBound, game.shuttle.x))
    #expect(game.characterX < start)
    #expect(game.isCharacterRunning)
}

@Test func characterNeverLeavesItsRange() {
    var game = makeServedGame(court: wideCourt, random: { 0 })

    for _ in 0..<3000 where game.phase != .over {
        game.update(deltaTime: step, racket: farAway, random: { 1 })
        #expect(wideCourt.characterRange.contains(game.characterX))
        #expect(wideCourt.characterRange.contains(game.characterTargetX))
    }
}

@Test func characterMovesTowardTheTargetAtItsRunSpeed() {
    var game = makeServedGame(court: wideCourt)
    let frames = framesUntilShuttleDrops(to: 640, in: game)
    hit(&game, after: frames, offset: 30)
    let start = game.characterX
    let target = game.characterTargetX
    #expect(target != start)

    game.update(deltaTime: 0.1, racket: farAway, random: middle)

    let moved = abs(game.characterX - start)
    #expect(moved > 0)
    #expect(moved <= (RallyGame.baseRunSpeed + RallyGame.extraRunSpeed) * 0.1 * RallyGame.maxTimeScale + 0.001)
    #expect((game.characterX - start) * (target - start) > 0)
}
