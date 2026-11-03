import SwiftUI

// 3x3 메쉬 그라데이션의 안쪽 점들을 천천히 움직여서 색이 흐르는 것처럼 보이게 한다.
public struct FlowingGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        // 색이 천천히 흐르는 효과라 초당 30번이면 육안으로 같다. 화면 주사율로 그리면 부하만 늘어난다.
        TimelineView(.animation(minimumInterval: DSMotion.gradientFrameInterval)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            let sine = Float(sin(seconds * DSMotion.gradientPointSpeed))
            let cosine = Float(cos(seconds * DSMotion.gradientPointSpeed * 0.8))
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5 + 0.18 * sine, 0], [1, 0],
                    [0, 0.5 + 0.18 * cosine], [0.5 + 0.2 * cosine, 0.5 + 0.2 * sine], [1, 0.5 - 0.18 * sine],
                    [0, 1], [0.5 - 0.18 * cosine, 1], [1, 1]
                ],
                colors: meshColors(seconds: seconds)
            )
        }
        .opacity(colorScheme == .dark ? DSOpacity.gradientDark : DSOpacity.gradientLight)
    }

    // 각 칸의 색이 팔레트를 따라 끊김 없이 다음 색으로 섞여 넘어간다.
    private func meshColors(seconds: Double) -> [Color] {
        let palette = DSColor.pastelPalette
        let phase = seconds * DSMotion.gradientColorSpeed
        let baseIndex = Int(floor(phase))
        let fraction = phase - floor(phase)
        return (0..<9).map { position in
            let fromColor = palette[(position + baseIndex) % palette.count]
            let toColor = palette[(position + baseIndex + 1) % palette.count]
            return fromColor.mix(with: toColor, by: fraction)
        }
    }
}
