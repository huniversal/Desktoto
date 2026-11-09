import CoreGraphics

/// 비 오는 날: 우산을 쓰고 서 있고, 우산 밖으로 빗방울이 떨어진다. 8칸이 한 바퀴다.
enum RainPieces {
    private static let originY: CGFloat = 3
    private static let canopy = IconColor.calibrated(red: 0.45, green: 0.70, blue: 1.00, alpha: 1)
    private static let canopyEdge = IconColor.calibrated(red: 0.30, green: 0.50, blue: 0.85, alpha: 1)
    private static let pole = IconColor.gray(white: 0.80, alpha: 1)
    private static let drop = IconColor.calibrated(red: 0.62, green: 0.82, blue: 1.00, alpha: 0.9)
    /// 빗방울이 내리는 가로 자리와 떨어지는 시작 위치(칸)
    private static let dropColumns = [(1, 0), (4, 9), (7, 17), (35, 5), (38, 13), (41, 21)]
    /// 한 칸마다 내려가는 거리와, 한 줄기가 다시 위로 돌아가기까지의 높이
    private static let fallPerStep = 3
    private static let loopHeight = 24

    static func pieces(step: Int, bodyColor: IconColor) -> [IconPiece] {
        var pieces = RestArt.character(bodyColor: bodyColor, originY: originY)

        // 우산 손잡이는 오른손이 쥔다.
        pieces.append(RestArt.rect(32, 4, 1, 8, pole))
        // 우산 윗부분: 위로 갈수록 좁은 반원
        pieces.append(RestArt.rect(15, 0, 13, 1, canopy))
        pieces.append(RestArt.rect(12, 1, 19, 1, canopy))
        pieces.append(RestArt.rect(10, 2, 23, 1, canopy))
        // 가장자리는 물결 모양으로 끊어서 우산살 느낌을 낸다.
        (10..<33).filter { ($0 - 10) % 4 != 3 }.forEach { pieces.append(RestArt.cell($0, 3, canopyEdge)) }

        // 우산 밖의 빗방울: 두 칸짜리 세로 줄이 아래로 떨어진다.
        dropColumns.forEach { column, phase in
            let top = (step * fallPerStep + phase) % loopHeight - 3
            (0..<2).forEach { offset in
                if let piece = RestArt.visibleCell(column, top + offset, drop) { pieces.append(piece) }
            }
        }
        return pieces
    }
}
