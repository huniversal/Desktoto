import CoreGraphics

/// 잠든 캐릭터 위로 떠오르는 z 하나. 위치는 배지 자리 왼쪽과 위쪽 기준 칸이다.
struct SleepMark: Equatable, Sendable {
    let isBig: Bool
    let column: CGFloat
    let row: CGFloat
}

/// 작은 z(4x4)와 큰 z(5x5)가 번갈아 나타났다 사라진다.
enum SleepFrames {
    static let smallGlyph = ["1111", "0010", "0100", "1111"]
    static let bigGlyph = ["11111", "00010", "00100", "01000", "11111"]

    static let marksByFrame: [[SleepMark]] = [
        [SleepMark(isBig: false, column: 0, row: 11)],
        [SleepMark(isBig: false, column: 0, row: 9)],
        [SleepMark(isBig: false, column: 0, row: 9), SleepMark(isBig: true, column: 2, row: 3)],
        [SleepMark(isBig: false, column: 0, row: 9), SleepMark(isBig: true, column: 2, row: 3)],
        [SleepMark(isBig: true, column: 2, row: 2)],
        []
    ]

    static func marks(frame: Int) -> [SleepMark] {
        marksByFrame[wrapFrameIndex(frame, count: IconTiming.sleepFrameCount)]
    }
}
