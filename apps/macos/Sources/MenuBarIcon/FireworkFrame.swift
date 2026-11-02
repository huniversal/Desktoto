import CoreGraphics
import Foundation

struct FireworkSpark: Equatable, Sendable {
    let rect: UnitRect
    /// `IconPalette.fireworkSparks`에서 고르는 색의 위치
    let colorIndex: Int
    let alpha: CGFloat
}

struct FireworkFlash: Equatable, Sendable {
    let rect: UnitRect
    let alpha: CGFloat
}

/// 세션이 끝났을 때 캐릭터 뒤에서 터지는 작은 폭죽의 한 프레임(약 1초, 24프레임).
/// 캔버스 가운데에서 알갱이들이 사방으로 퍼지며 작아지고 투명해진다.
struct FireworkFrame: Equatable, Sendable {
    static let sparkCount = 14
    static let centerY: CGFloat = 9
    /// 캐릭터(폭 24칸)가 캔버스 가운데를 가리므로, 몸통 밖(양옆)까지 닿아야 불꽃이 보인다.
    static let reaches: [CGFloat] = [19, 15, 11]
    /// 몸통 뒤에 가려지는 안쪽은 건너뛰고 몸통 가장자리 근처에서 시작한다.
    static let startRadius: CGFloat = 8
    static let verticalScale: CGFloat = 0.5

    let sparks: [FireworkSpark]
    let flash: FireworkFlash?

    init(frame: Int) {
        let count = IconTiming.fireworkFrameCount
        let wrappedFrame = wrapFrameIndex(frame, count: count)
        let progress = CGFloat(wrappedFrame) / CGFloat(count - 1)
        // 처음에 빠르게 퍼지고 점점 느려진다.
        let eased = 1 - pow(1 - progress, 2)
        let alpha = max(0, 1 - pow(progress, 2.4))
        let centerX = CharacterGrid.canvasWidth / 2
        let sparkSize: CGFloat = progress < 0.45 ? 3 : (progress < 0.8 ? 2 : 1)

        sparks = (0..<Self.sparkCount).map { index in
            let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(Self.sparkCount) + 0.3
            let reach = Self.reaches[index % Self.reaches.count]
            let radius = Self.startRadius + (reach - Self.startRadius) * eased
            let sparkX = centerX + cos(angle) * radius
            // 살짝 아래로 처진다.
            let sparkY = Self.centerY + sin(angle) * radius * Self.verticalScale + 4 * progress * progress
            return FireworkSpark(
                rect: UnitRect(sparkX - sparkSize / 2, sparkY - sparkSize / 2, sparkSize, sparkSize),
                colorIndex: index % IconPalette.fireworkSparks.count,
                alpha: alpha
            )
        }

        // 터지는 순간의 작은 섬광
        flash = progress < 0.2
            ? FireworkFlash(rect: UnitRect(centerX - 2, Self.centerY - 2, 4, 4), alpha: 1 - progress / 0.2)
            : nil
    }
}
