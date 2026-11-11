import AppKit
import CoreGraphics
import DesignSystem
import Testing
@testable import MenuBarIcon

private func pieces(_ frame: IconFrame, colorMode: ColorMode = .white, hasUnseenDone: Bool = false, isWaiting: Bool = false) -> [IconPiece] {
    IconScene.pieces(frame: frame, appearance: IconAppearance(colorMode: colorMode, hasUnseenDone: hasUnseenDone, isWaiting: isWaiting))
}

@Test func waitingBadgeWinsOverUnseenDone() {
    #expect(IconBadge(hasUnseenDone: false, isWaiting: false) == .none)
    #expect(IconBadge(hasUnseenDone: true, isWaiting: false) == .unseenDone)
    #expect(IconBadge(hasUnseenDone: false, isWaiting: true) == .waiting)
    #expect(IconBadge(hasUnseenDone: true, isWaiting: true) == .waiting)
}

@Test func standingCharacterIsCenteredAndDrawnInOriginalOrder() {
    let standing = pieces(.standing)

    // 다리 4, 팔 2, 몸통 1, 눈 2. 배지가 없다.
    #expect(standing.count == 9)
    #expect(standing[0].rect == UnitRect(13, 14, 2, 4))
    #expect(standing[4].rect == UnitRect(9, 8, 3, 3))
    #expect(standing[6].rect == UnitRect(12, 2, 18, 12))
    #expect(standing[7].rect == UnitRect(15, 5, 2, 3))
    #expect(standing[7].color == IconPalette.eye)
}

@Test func colorModeChangesOnlyTheBodyColor() {
    let white = pieces(.standing, colorMode: .white)
    let colorful = pieces(.standing, colorMode: .color)

    #expect(white.map(\.rect) == colorful.map(\.rect))
    #expect(white[6].color == .gray(white: 1, alpha: 1))
    let orange = IconColor.srgb(red: CGFloat(0xDD) / 255, green: CGFloat(0x8B) / 255, blue: CGFloat(0x70) / 255, alpha: 1)
    #expect(colorful[6].color == orange)
    #expect(white[7].color == colorful[7].color)
}

@Test func chiikawaRunsInFrontOfAnAnimeSceneWhoseGrassScrolls() {
    let appearance = IconAppearance(character: .chiikawa)

    // 풍경은 애니 장면 그림이 맡아서 사각형 풍경이나 속도선은 없다.
    let running = IconScene.pieces(frame: .running(phase: 5), appearance: appearance)
    #expect(!running.contains { $0.color == IconPalette.speedLine })
    #expect(running.isEmpty)

    // 달릴 때만 들판이 흘러가고, 멈춘 모습(서 있기, 대기, 잠듦)은 같은 장면이 그대로 깔린다.
    #expect(IconScene.backdrop(frame: .running(phase: 6), appearance: appearance) == BackdropPlacement(grassShift: SceneBackdrop.grassShift(phase: 6)))
    #expect(IconScene.backdrop(frame: .standing, appearance: appearance) == BackdropPlacement(grassShift: nil))
    #expect(IconScene.backdrop(frame: .idle(clip: 1, frame: 3), appearance: appearance) == BackdropPlacement(grassShift: nil))
    #expect(IconScene.backdrop(frame: .sleeping(frame: 0), appearance: appearance) == BackdropPlacement(grassShift: nil))
    #expect(IconScene.backdrop(frame: .standing, appearance: IconAppearance()) == nil)
}

@Test func grassScrollsOneTilePerLoopAndRepeatsSeamlessly() async {
    #expect(SceneBackdrop.grassShift(phase: 0) == 0)
    #expect(SceneBackdrop.grassShift(phase: 12) == SceneBackdrop.grassPeriod / 2)
    #expect(SceneBackdrop.grassShift(phase: 24) == 0)
    #expect(SceneBackdrop.grassShift(phase: 23) < SceneBackdrop.grassPeriod)
    let decoded = await MainActor.run { SceneBackdrop.fieldImage != nil && SceneBackdrop.gateImage != nil && SceneBackdrop.forestImage != nil && SceneBackdrop.grassTileImage != nil }
    #expect(decoded)
}

@Test func usagiDancesInPlaceInFrontOfTheForestScene() {
    let appearance = IconAppearance(character: .usagi)
    let frameCount = CharacterArt.frameCount(of: .usagi, pose: .running)
    let placements = (0..<IconTiming.runningFrameCount).compactMap { IconScene.imagePlacement(frame: .running(phase: $0), appearance: appearance) }

    // 춤 11장을 한 바퀴에 모두 거치고, 가로 위치는 서 있을 때와 같다.
    #expect(frameCount == 11)
    #expect(Set(placements.map(\.frame)) == Set(0..<frameCount))
    #expect(Set(placements.map(\.centerX)) == [IconScene.imagePlacement(frame: .standing, appearance: appearance)?.centerX ?? -1])
    #expect(IconScene.pieces(frame: .running(phase: 3), appearance: appearance).isEmpty)
    #expect(IconScene.pieces(frame: .standing, appearance: appearance).isEmpty)
    // 숲속 장면은 대기 중이든 작업 중이든 고정으로 깔린다.
    for frame in [IconFrame.standing, .idle(clip: 1, frame: 0), .running(phase: 3), .sleeping(frame: 0)] {
        #expect(IconScene.backdrop(frame: frame, appearance: appearance) == BackdropPlacement(scene: .forest, grassShift: nil))
    }
}

@Test func onlyHachiwareRunsAtHalfSpeed() {
    #expect(IconTiming.runningFrameInterval(for: .claude) == IconTiming.runningFrameInterval)
    #expect(IconTiming.runningFrameInterval(for: .chiikawa) == IconTiming.runningFrameInterval)
    #expect(IconTiming.runningFrameInterval(for: .usagi) == IconTiming.runningFrameInterval)
    #expect(IconTiming.runningFrameInterval(for: .hachiware) == IconTiming.runningFrameInterval * 2)
}

@Test func characterArtDecodes() async {
    let hasAll = await MainActor.run {
        IconCharacter.allCases.filter { $0 != .claude }.allSatisfy { character in
            ([ArtPose.resting, .running] + CharacterArt.idleClips(of: character).indices.map { ArtPose.idle(clip: $0) }).allSatisfy { pose in
                (0..<CharacterArt.frameCount(of: character, pose: pose)).allSatisfy { CharacterArt.image(of: character, pose: pose, frame: $0) != nil }
            }
        }
    }
    #expect(hasAll)
    #expect(IconScene.imagePlacement(frame: .standing, appearance: IconAppearance(character: .chiikawa))?.character == .chiikawa)
}

@Test func standingBadgesSitAtTheRightOfTheCharacter() {
    let waiting = pieces(.standing, isWaiting: true).filter { $0.color == IconPalette.question }
    let done = pieces(.standing, hasUnseenDone: true).filter { $0.color == IconPalette.doneDot }

    // 물음표는 5x7 격자에서 10칸을 칠하고 완료 점은 4x4 한 덩어리다. 위치는 9 + 24 + 1 = 34칸부터다.
    #expect(waiting.count == 10)
    #expect(waiting.allSatisfy { $0.rect.x >= 34 && $0.rect.x < 39 && $0.rect.y >= 0 && $0.rect.y < 7 })
    #expect(done.map(\.rect) == [UnitRect(34, 0, 4, 4)])
    #expect(done.count == 1)
}

@Test func waitingBadgeReplacesTheDoneDotWhenBothExist() {
    let both = pieces(.standing, hasUnseenDone: true, isWaiting: true)

    #expect(both.contains { $0.color == IconPalette.question })
    #expect(!both.contains { $0.color == IconPalette.doneDot })
}

@Test func runningBadgeFollowsTheCharacterHorizontallyButNotTheBob() {
    let phase = 12
    let originX = RunningFrame(phase: phase).originX
    let done = pieces(.running(phase: phase), hasUnseenDone: true).filter { $0.color == IconPalette.doneDot }

    #expect(done.map(\.rect) == [UnitRect(originX + 25, 0, 4, 4)])
}

@Test func runningDrawsSpeedLinesBeforeTheCharacter() {
    let running = pieces(.running(phase: 12))

    #expect(running.prefix(3).allSatisfy { $0.color == IconPalette.speedLine })
    #expect(running.count == 3 + 9)
    #expect(pieces(.running(phase: 0)).count == 9)
}

@Test func sleepingCharacterSinksOneUnitWithClosedEyes() {
    let sleeping = pieces(.sleeping(frame: 5))

    // z가 없는 프레임: 몸통은 서 있을 때보다 1칸 아래이고 눈은 한 줄이다.
    #expect(sleeping.count == 9)
    #expect(sleeping[6].rect == UnitRect(12, 3, 18, 12))
    #expect(sleeping[7].rect == UnitRect(15, 8, 2, 1))
}

@Test func sleepingShowsZAtTheBadgeSlot() {
    let zPieces = pieces(.sleeping(frame: 0)).filter { $0.color == IconPalette.sleepZ }

    // 작은 z(4x4)는 10칸이며 배지 자리 왼쪽(34칸), 위에서 11칸에서 시작한다.
    #expect(zPieces.count == 10)
    #expect(zPieces.first?.rect == UnitRect(34, 11, 1, 1))

    let bigPlusSmall = pieces(.sleeping(frame: 2)).filter { $0.color == IconPalette.sleepZ }
    #expect(bigPlusSmall.count == 10 + 13)
}

@Test func sleepingShowsTheDoneDotInsteadOfZ() {
    let sleeping = pieces(.sleeping(frame: 2), hasUnseenDone: true)

    #expect(!sleeping.contains { $0.color == IconPalette.sleepZ })
    #expect(sleeping.filter { $0.color == IconPalette.doneDot }.map(\.rect) == [UnitRect(34, 0, 4, 4)])
}

@Test func sleepingIgnoresTheWaitingBadgeLikeTheOriginal() {
    let sleeping = pieces(.sleeping(frame: 0), isWaiting: true)

    #expect(!sleeping.contains { $0.color == IconPalette.question })
    #expect(sleeping.contains { $0.color == IconPalette.sleepZ })
}

@Test func everyCharacterFrameStaysInsideTheCanvas() {
    let frames: [IconFrame] = [.standing]
        + (0..<IconTiming.runningFrameCount).map { .running(phase: $0) }
        + (0..<IconTiming.sleepFrameCount).map { .sleeping(frame: $0) }
    let appearances = [
        IconAppearance(),
        IconAppearance(hasUnseenDone: true),
        IconAppearance(isWaiting: true)
    ]

    for frame in frames {
        for appearance in appearances {
            for piece in IconScene.pieces(frame: frame, appearance: appearance) {
                #expect(piece.rect.x >= 0 && piece.rect.x + piece.rect.width <= CharacterGrid.canvasWidth)
                #expect(piece.rect.y >= 0 && piece.rect.y + piece.rect.height <= CharacterGrid.canvasHeight)
            }
        }
    }
}

@Test func fireworkPiecesFadeWithTheFrame() {
    let first = IconScene.fireworkPieces(frame: 0)
    let last = IconScene.fireworkPieces(frame: 23)

    #expect(first.count == FireworkFrame.sparkCount + 1)
    #expect(first.last?.color == .gray(white: 1, alpha: 1))
    #expect(last.count == FireworkFrame.sparkCount)
    #expect(last.allSatisfy { piece in
        if case .calibrated(_, _, _, let alpha) = piece.color { return alpha == 0 }
        return false
    })
}

@Test func chiikawaPlaysEveryGifFrameOncePerRunningLap() {
    let appearance = IconAppearance(character: .chiikawa)
    let frameCount = CharacterArt.frameCount(of: .chiikawa, pose: .running)
    let frames = (0..<IconTiming.runningFrameCount).compactMap { IconScene.imagePlacement(frame: .running(phase: $0), appearance: appearance)?.frame }

    #expect(frameCount == 12)
    #expect(Set(frames) == Set(0..<frameCount))
    // 프레임은 앞으로만 넘어가고, 한 바퀴가 끝나면 처음으로 돌아간다.
    #expect(frames == frames.sorted())
    #expect(IconScene.imagePlacement(frame: .running(phase: IconTiming.runningFrameCount), appearance: appearance)?.frame == 0)
}

@Test func chiikawaAndUsagiHaveSeveralIdleClips() {
    let chiikawa = IconAppearance(character: .chiikawa)
    let clips = CharacterArt.idleClips(of: .chiikawa)

    #expect(clips.count == 8)
    for character in [IconCharacter.chiikawa, .hachiware, .usagi] {
        for (index, clip) in CharacterArt.idleClips(of: character).enumerated() {
            // 순서표는 모든 프레임을 앞에서부터 한 번씩 거친다.
            #expect(clip.sequence == clip.sequence.sorted())
            #expect(Set(clip.sequence) == Set(0..<clip.encodedFrames.count))
            #expect(CharacterArt.frameCount(of: character, pose: .idle(clip: index)) == clip.encodedFrames.count)
        }
    }
    #expect(IconScene.imagePlacement(frame: .idle(clip: 2, frame: 5), appearance: chiikawa)?.pose == .idle(clip: 2))
    #expect(IconScene.imagePlacement(frame: .idle(clip: 2, frame: 5), appearance: chiikawa)?.frame == 5)
    #expect(CharacterArt.idleClips(of: .usagi).count == 5)
    #expect(CharacterArt.idleClips(of: .hachiware).count == 3)
    #expect(CharacterArt.idleClips(of: .claude).isEmpty)
    // 대기 모습의 풍경과 배지는 서 있는 모습과 같다.
    #expect(IconScene.pieces(frame: .idle(clip: 0, frame: 4), appearance: chiikawa) == IconScene.pieces(frame: .standing, appearance: chiikawa))
}

@Test func pictureCharactersFillTheWholeCanvasHeight() {
    let standing = IconScene.imagePlacement(frame: .standing, appearance: IconAppearance(character: .chiikawa))
    let idle = IconScene.imagePlacement(frame: .idle(clip: 3, frame: 0), appearance: IconAppearance(character: .chiikawa))

    for placement in [standing, idle] {
        #expect(placement?.height == CharacterGrid.canvasHeight)
        #expect(placement?.bottom == CharacterGrid.canvasHeight)
    }
}

@Test func runningShowsTheUpperBodyEnlargedToFillTheCanvas() {
    for character in [IconCharacter.chiikawa, .hachiware, .usagi] {
        let placement = IconScene.imagePlacement(frame: .running(phase: 7), appearance: IconAppearance(character: character))
        let visible = CharacterArt.runningVisibleRange(of: character)
        guard let placement else {
            Issue.record("그림 캐릭터는 자리가 있어야 한다")
            continue
        }
        let top = placement.bottom - placement.height

        // 보이는 범위가 캔버스 위쪽 끝(0)부터 바닥(20칸)까지를 정확히 채운다.
        #expect(visible.upperBound - visible.lowerBound < 1)
        #expect(abs(top + visible.lowerBound * placement.height) < 0.0001)
        #expect(abs(top + visible.upperBound * placement.height - CharacterGrid.canvasHeight) < 0.0001)
    }
}

@Test func idleClipChangesOnlyAtTheEndOfALoopAfterTheMinimumTimeAndNeverRepeats() {
    var generator = SystemRandomNumberGenerator()
    var playback = IdlePlayback(clip: 1)
    let stepCount = 30
    var switches: [(step: Int, from: Int, to: Int)] = []
    var previousClip = playback.clip

    for elapsed in 1...600 {
        playback.advance(stepCount: stepCount, clipCount: 5, using: &generator)
        if playback.clip != previousClip {
            switches.append((elapsed, previousClip, playback.clip))
            previousClip = playback.clip
        }
    }

    #expect(!switches.isEmpty)
    for change in switches {
        // 바뀌는 순간은 항상 클립의 첫 칸이고, 같은 클립이 다시 나오지 않는다.
        #expect(change.step % stepCount == 0)
        #expect(change.from != change.to)
    }
    // 최소 재생 시간(80칸) 이상 돌린 뒤에 바뀐다. 30칸 클립은 3바퀴(90칸)마다 바뀐다.
    #expect(switches.first?.step == 90)
    #expect(zip(switches, switches.dropFirst()).allSatisfy { $1.step - $0.step == 90 })
}

@Test func idleClipStaysWhenThereIsOnlyOne() {
    var generator = SystemRandomNumberGenerator()
    var playback = IdlePlayback()
    for _ in 0..<300 { playback.advance(stepCount: 10, clipCount: 1, using: &generator) }
    #expect(playback.clip == 0)
    #expect(IdleClipPicker.nextClip(after: 0, count: 1, using: &generator) == 0)
}

@MainActor
@Test func imageSetMapsIdleStepsToClipFrames() {
    let render: @MainActor (IconFrame, IconAppearance) -> NSImage = { frame, _ in
        guard case .idle(let clip, let index) = frame else { return NSImage(size: NSSize(width: 1, height: 1)) }
        return NSImage(size: NSSize(width: clip + 1, height: index + 1))
    }
    let set = IconImageSet(appearance: IconAppearance(character: .chiikawa), scale: 2, pointHeight: 20, makeImage: render)
    let sway = CharacterArt.idleClips(of: .chiikawa)[0]

    #expect(set.idleClipCount == 8)
    #expect(set.idleStepCount(clip: 0) == sway.sequence.count)
    // 50ms 칸마다 순서표의 프레임을 꺼낸다(흔들흔들 클립은 2번 프레임에 8칸 머문다).
    #expect(set.idleImage(clip: 0, step: 4).size == NSSize(width: 1, height: sway.sequence[4] + 1))
    #expect(set.idleImage(clip: 0, step: 4).size == set.idleImage(clip: 0, step: 11).size)
}

@MainActor
@Test func imageSetHasIdleFramesOnlyForPictureCharacters() {
    let render: @MainActor (IconFrame, IconAppearance) -> NSImage = { _, _ in NSImage(size: NSSize(width: 1, height: 1)) }
    #expect(IconImageSet(appearance: IconAppearance(character: .chiikawa), scale: 2, pointHeight: 20, makeImage: render).hasIdleAnimation)
    #expect(IconImageSet(appearance: IconAppearance(character: .usagi), scale: 2, pointHeight: 20, makeImage: render).hasIdleAnimation)
    #expect(!IconImageSet(appearance: IconAppearance(), scale: 2, pointHeight: 20, makeImage: render).hasIdleAnimation)
}

@Test func hachiwareDancesInPlaceInFrontOfTheGateScene() {
    let appearance = IconAppearance(character: .hachiware)
    let frameCount = CharacterArt.frameCount(of: .hachiware, pose: .running)
    let placements = (0..<IconTiming.runningFrameCount).compactMap { IconScene.imagePlacement(frame: .running(phase: $0), appearance: appearance) }

    // 춤 22장을 한 바퀴에 모두 거치고, 가로 위치는 서 있을 때와 같다.
    #expect(frameCount == 22)
    #expect(Set(placements.map(\.frame)) == Set(0..<frameCount))
    #expect(Set(placements.map(\.centerX)) == [IconScene.imagePlacement(frame: .standing, appearance: appearance)?.centerX ?? -1])
    #expect(IconScene.pieces(frame: .running(phase: 4), appearance: appearance).isEmpty)
    // 문 앞 장면은 흘러가지 않는다.
    #expect(IconScene.backdrop(frame: .running(phase: 6), appearance: appearance) == BackdropPlacement(scene: .gate, grassShift: nil))
    #expect(IconScene.backdrop(frame: .idle(clip: 2, frame: 0), appearance: appearance) == BackdropPlacement(scene: .gate, grassShift: nil))
    #expect(IconTiming.runningFrameInterval(for: .hachiware) == IconTiming.runningFrameInterval * 2)
}

@Test func waitingQuestionMarkIsRed() {
    // 승인 대기 물음표는 빨간색이다(빨강이 크고 초록, 파랑은 작다).
    guard case .calibrated(let red, let green, let blue, _) = IconPalette.question else {
        Issue.record("물음표 색이 calibrated 색이 아니다")
        return
    }
    #expect(red > 0.9)
    #expect(green < 0.3)
    #expect(blue < 0.3)
    #expect(pieces(.standing, isWaiting: true).contains { $0.color == IconPalette.question })
}
