import AppKit
import DesignSystem
import Testing
@testable import MenuBarIcon

private let testScale: CGFloat = 2
/// 격자 좌표를 픽셀로 검사하는 테스트는 한 칸이 정확히 1pt인 20pt 기준으로 고정한다(앱 기본 크기와 무관하다).
private let testPointHeight: CGFloat = 20

/// 원본과 같은 경로(보정 색을 DeviceRGB 비트맵에 칠함)에서 화면 픽셀이 되는 값. 보정 색은 이 과정에서 값이 조금 바뀐다.
@MainActor
private func deviceRGB(_ color: IconColor) -> [CGFloat] {
    guard let converted = color.nsColor.usingColorSpace(.deviceRGB) else { return [] }
    return [converted.redComponent, converted.greenComponent, converted.blueComponent, converted.alphaComponent]
}

@MainActor
private func createBitmap(_ image: NSImage) -> NSBitmapImageRep? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    return NSBitmapImageRep(cgImage: cgImage)
}

/// 픽셀 좌표(왼쪽 위 기준)의 색을 0에서 1 사이 RGBA로 읽는다.
@MainActor
private func readPixel(_ bitmap: NSBitmapImageRep, x: Int, y: Int) -> [CGFloat]? {
    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return nil }
    return [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
}

private func isClose(_ pixel: [CGFloat]?, to expected: [CGFloat], tolerance: CGFloat = 0.05) -> Bool {
    guard let pixel, pixel.count == expected.count else { return false }
    return zip(pixel, expected).allSatisfy { abs($0 - $1) <= tolerance }
}

@MainActor
private func createImage(_ frame: IconFrame, _ appearance: IconAppearance = IconAppearance()) -> NSImage {
    IconRenderer.image(frame: frame, appearance: appearance, scale: testScale, pointHeight: testPointHeight)
}

@MainActor @Test func everyStateUsesTheSameCanvasSizeAndBitmap() throws {
    let frames: [IconFrame] = [.standing, .running(phase: 5), .sleeping(frame: 2)]
    let appearances = [IconAppearance(), IconAppearance(hasUnseenDone: true), IconAppearance(isWaiting: true)]

    for frame in frames {
        for appearance in appearances {
            let image = createImage(frame, appearance)
            #expect(image.size == NSSize(width: 42, height: 20))
            #expect(!image.isTemplate)
            let bitmap = try #require(createBitmap(image))
            #expect(bitmap.pixelsWide == 84)
            #expect(bitmap.pixelsHigh == 40)
        }
    }
}

@MainActor @Test func pointHeightScalesTheWholeCanvas() {
    let image = IconRenderer.image(frame: .standing, appearance: IconAppearance(), scale: testScale, pointHeight: 40)

    #expect(image.size == NSSize(width: 84, height: 40))
}

@MainActor @Test func whiteModePaintsAWhiteBodyAndDarkEyes() throws {
    let bitmap = try #require(createBitmap(createImage(.standing, IconAppearance(colorMode: .white))))

    // 몸통은 (12...30, 2...14)칸, 눈은 (15...17, 5...8)칸이고 한 칸은 2픽셀이다.
    #expect(isClose(readPixel(bitmap, x: 42, y: 16), to: [1, 1, 1, 1]))
    #expect(isClose(readPixel(bitmap, x: 32, y: 13), to: [0.05, 0.05, 0.05, 1], tolerance: 0.1))
    #expect(isClose(readPixel(bitmap, x: 0, y: 0), to: [0, 0, 0, 0]))
}

@MainActor @Test func colorModePaintsTheOrangeBody() throws {
    let bitmap = try #require(createBitmap(createImage(.standing, IconAppearance(colorMode: .color))))

    #expect(isClose(readPixel(bitmap, x: 42, y: 16), to: deviceRGB(IconPalette.colorfulBody), tolerance: 0.03))
}

@MainActor @Test func badgePixelsUseTheirOwnColors() throws {
    let waiting = try #require(createBitmap(createImage(.standing, IconAppearance(isWaiting: true))))
    let done = try #require(createBitmap(createImage(.standing, IconAppearance(hasUnseenDone: true))))
    let both = try #require(createBitmap(createImage(.standing, IconAppearance(hasUnseenDone: true, isWaiting: true))))
    let none = try #require(createBitmap(createImage(.standing)))

    // 물음표 윗줄은 34칸 오른쪽 한 칸 안쪽(35칸)부터 칠해지고, 완료 점은 34칸부터 4x4다.
    #expect(isClose(readPixel(waiting, x: 71, y: 1), to: deviceRGB(IconPalette.question)))
    #expect(isClose(readPixel(done, x: 72, y: 4), to: deviceRGB(IconPalette.doneDot)))
    #expect(isClose(readPixel(both, x: 71, y: 1), to: deviceRGB(IconPalette.question)))
    #expect(isClose(readPixel(none, x: 71, y: 1), to: [0, 0, 0, 0]))
}

@MainActor @Test func fireworkIsDrawnBehindTheCharacter() throws {
    let base = createImage(.standing)
    let firework = IconRenderer.fireworkImage(base: base, frame: 0, scale: testScale, pointHeight: testPointHeight)
    let bitmap = try #require(createBitmap(firework))

    #expect(firework.size == base.size)
    // 가운데는 캐릭터 몸통이 덮고, 섬광이 있는 첫 프레임에서도 몸통이 위에 남는다.
    #expect(isClose(readPixel(bitmap, x: 42, y: 16), to: [1, 1, 1, 1]))
    // 폭죽은 몸통 밖(양옆)에 닿아 캔버스 왼쪽 끝 근처에 색이 생긴다.
    let outside = (0..<84).contains { x in (readPixel(bitmap, x: x, y: 18)?[3] ?? 0) > 0 && (x < 24 || x > 60) }
    #expect(outside)
}

@MainActor @Test func imageSetBuildsAllFramesOnceAndRebuildsOnlyWhenTheAppearanceChanges() {
    var builtCount = 0
    let imageSet = IconImageSet(appearance: IconAppearance(), scale: testScale, pointHeight: 20) { _, _ in
        builtCount += 1
        return NSImage(size: NSSize(width: 1, height: 1))
    }
    // 서 있기 1장, 시선 117장, 달리기 24장, 잠듦 6장
    #expect(builtCount == 148)

    _ = imageSet.image(for: .standing)
    _ = imageSet.image(for: .running(phase: 3))
    #expect(imageSet.update(appearance: IconAppearance()) == false)
    #expect(builtCount == 148)

    #expect(imageSet.update(appearance: IconAppearance(colorMode: .color)) == true)
    #expect(builtCount == 296)
    #expect(imageSet.update(appearance: IconAppearance(colorMode: .color, hasUnseenDone: true)) == true)
    #expect(imageSet.update(appearance: IconAppearance(colorMode: .color, hasUnseenDone: true, isWaiting: true)) == true)
    #expect(builtCount == 592)
}

@MainActor @Test func imageSetReturnsTheCachedImageAndWrapsFrameNumbers() {
    let imageSet = IconImageSet(appearance: IconAppearance(), scale: testScale, pointHeight: 20) { _, _ in
        NSImage(size: NSSize(width: 1, height: 1))
    }

    #expect(imageSet.image(for: .running(phase: 3)) === imageSet.image(for: .running(phase: 3)))
    #expect(imageSet.image(for: .running(phase: 3)) === imageSet.image(for: .running(phase: 27)))
    #expect(imageSet.image(for: .running(phase: 3)) !== imageSet.image(for: .running(phase: 4)))
    #expect(imageSet.image(for: .sleeping(frame: 1)) === imageSet.image(for: .sleeping(frame: 7)))
}

@MainActor @Test func imageSetRebuildsWithTheNewColorMode() throws {
    let imageSet = IconImageSet(appearance: IconAppearance(colorMode: .white), scale: testScale, pointHeight: testPointHeight)
    let before = try #require(createBitmap(imageSet.image(for: .standing)))
    #expect(isClose(readPixel(before, x: 42, y: 16), to: [1, 1, 1, 1]))

    imageSet.update(appearance: IconAppearance(colorMode: .color))

    let after = try #require(createBitmap(imageSet.image(for: .running(phase: 0))))
    #expect(isClose(readPixel(after, x: 20, y: 16), to: deviceRGB(IconPalette.colorfulBody), tolerance: 0.03))
}
