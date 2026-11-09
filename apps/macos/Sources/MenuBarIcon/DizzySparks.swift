import CoreGraphics

/// 어지러울 때 캐릭터 양옆에서 번갈아 반짝이는 별. 폭죽(작업 완료 신호)과 겹치지 않게 색과 모양을 다르게 한다.
/// 좌표는 캔버스 왼쪽 위를 (0, 0)으로 둔 칸 단위다. 오른쪽 위는 배지 자리라서 오른쪽 별은 아래쪽에만 둔다.
enum DizzySparks {
    struct Mark: Equatable, Sendable {
        let column: CGFloat
        let row: CGFloat
        let isStar: Bool
    }

    /// 십자 모양 별(3x3). 작은 반짝임은 한 칸짜리 점이다.
    static let starGlyph = ["010", "111", "010"]
    static let phaseCount = 2

    static let marks: [[Mark]] = [
        [Mark(column: 3, row: 4, isStar: true), Mark(column: 35, row: 9, isStar: true),
         Mark(column: 6, row: 12, isStar: false), Mark(column: 38, row: 14, isStar: false)],
        [Mark(column: 2, row: 10, isStar: true), Mark(column: 36, row: 14, isStar: true),
         Mark(column: 5, row: 3, isStar: false), Mark(column: 37, row: 9, isStar: false)]
    ]

    static func rects(phase: Int) -> [UnitRect] {
        marks[wrapFrameIndex(phase, count: phaseCount)].flatMap { mark in
            mark.isStar
                ? Glyph.cells(of: starGlyph, column: mark.column, row: mark.row)
                : [UnitRect(mark.column, mark.row, 1, 1)]
        }
    }
}
