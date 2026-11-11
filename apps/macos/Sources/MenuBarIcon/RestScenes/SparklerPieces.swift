import CoreGraphics

/// 스파클라: 오른손에 든 막대에 불이 붙어 반짝이고, 점점 짧아지다가 연기를 내며 꺼진다. 40칸이 한 바퀴다.
enum SparklerPieces {
    private static let originY: CGFloat = 4
    /// 손에서 불붙은 끝까지 이어지는 막대 칸
    private static let stickCells = [(33, 10), (34, 9), (35, 8), (36, 7), (37, 6), (38, 5)]
    private static let stick = IconColor.gray(white: 0.78, alpha: 1)
    private static let hotTip = IconColor.calibrated(red: 1.00, green: 0.55, blue: 0.15, alpha: 1)
    private static let burnedTip = IconColor.gray(white: 0.45, alpha: 1)
    private static let sparkColors = [
        IconColor.gray(white: 1, alpha: 1),
        IconColor.calibrated(red: 1.00, green: 0.88, blue: 0.40, alpha: 1),
        IconColor.calibrated(red: 1.00, green: 0.60, blue: 0.20, alpha: 1)
    ]
    private static let smoke = IconColor.gray(white: 0.85, alpha: 0.6)

    /// 끝에서 튀는 불꽃 알갱이: (가로, 세로, 색 번호). 모양을 바꿔 가며 반짝이게 한다.
    private static let sparkPatterns: [[(Int, Int, Int)]] = [
        [(0, -1, 0), (-1, -2, 1), (1, -2, 1), (2, -1, 2), (-2, 0, 2), (0, -3, 1)],
        [(0, -1, 0), (1, -1, 0), (-2, -1, 1), (0, -3, 1), (2, -2, 2), (-1, -3, 2)],
        [(0, -1, 0), (-1, 0, 0), (2, -3, 1), (-2, -2, 2), (1, -4, 1), (3, -1, 2)],
        [(0, -1, 0), (1, 0, 0), (-2, -3, 1), (3, -2, 1), (-1, -1, 2), (2, 0, 2)],
        [(0, -1, 0), (-1, -1, 0), (1, -3, 1), (-3, -1, 1), (2, -2, 2), (0, -4, 2)],
        [(0, -1, 0), (0, -2, 0), (3, -3, 1), (-2, -2, 1), (1, -1, 2), (-1, -4, 2)]
    ]

    static func pieces(step: Int, bodyColor: IconColor) -> [IconPiece] {
        let isIgniting = step < 4
        let isDying = step >= 32 && step < 36
        let isSmoking = step >= 36
        // 막대는 타면서 짧아진다.
        let remaining = step < 4 ? stickCells.count : (step < 32 ? stickCells.count - (step - 4) / 7 : 2)
        let tip = stickCells[remaining - 1]

        // 불꽃을 올려다본다. 불이 붙는 순간에는 눈이 커지고, 꺼진 뒤에는 눈을 감는다.
        let expression: EyeExpression = isIgniting ? .wide : (isSmoking ? .blink : .open)
        var pieces = RestArt.character(gaze: GazeDirection(horizontal: 4, vertical: -3), expression: expression, bodyColor: bodyColor, originY: originY)

        stickCells.prefix(remaining - 1).forEach { pieces.append(RestArt.cell($0.0, $0.1, stick)) }
        pieces.append(RestArt.cell(tip.0, tip.1, isSmoking ? burnedTip : hotTip))

        if !isSmoking {
            let pattern = sparkPatterns[step % sparkPatterns.count]
            let count = (isIgniting || isDying) ? 2 : pattern.count
            pattern.prefix(count).forEach { dx, dy, colorIndex in
                if let piece = RestArt.visibleCell(tip.0 + dx, tip.1 + dy, sparkColors[colorIndex]) { pieces.append(piece) }
            }
        } else {
            // 꺼진 끝에서 연기가 한 줄 올라간다.
            (0...min(step - 36, 2)).forEach { rise in
                if let piece = RestArt.visibleCell(tip.0 + (rise % 2), tip.1 - 1 - rise, smoke) { pieces.append(piece) }
            }
        }
        return pieces
    }
}
