import CoreGraphics
import Foundation

/// 달리기 한 프레임의 위치와 포즈.
/// 위치는 한 바퀴를 프레임 수로 등분해 마지막 프레임이 첫 프레임과 겹치지 않게 하고, 다리는 3프레임마다 교대한다.
/// 몸은 그 사이에 코사인 곡선으로 낮은 자세와 높은 자세를 오간다.
struct RunningFrame: Equatable, Sendable {
    /// 이 프레임 수마다 다리가 교대한다(약 0.125초)
    static let framesPerLegStep = 3

    let originX: CGFloat
    let originY: CGFloat
    let pose: LegPose

    init(phase: Int) {
        let count = IconTiming.runningFrameCount
        let wrappedPhase = wrapFrameIndex(phase, count: count)
        let progress = CGFloat(wrappedPhase) / CGFloat(count)
        let legStep = Double(wrappedPhase) / Double(Self.framesPerLegStep)

        originX = progress * CharacterGrid.travelWidth
        originY = CharacterGrid.maxBobHeight * CGFloat(0.5 + 0.5 * cos(Double.pi * legStep))
        pose = Int(legStep) % 2 == 0 ? .runningA : .runningB
    }
}

/// 캐릭터 뒤에 따라오는 속도선.
enum SpeedLines {
    /// (행 오프셋, 길이, 캐릭터와의 간격)
    static let lines: [(row: CGFloat, length: CGFloat, gap: CGFloat)] = [(2, 7, 3), (6, 4, 4), (10, 7, 3)]
    static let thickness: CGFloat = 2

    /// 캔버스 왼쪽 밖으로 나가는 부분은 그리지 않는다.
    static func rects(originX: CGFloat, originY: CGFloat) -> [UnitRect] {
        lines.compactMap { line in
            let endColumn = originX - line.gap
            let startColumn = max(0, endColumn - line.length)
            guard endColumn > startColumn else { return nil }
            return UnitRect(startColumn, originY + line.row, endColumn - startColumn, thickness)
        }
    }
}
