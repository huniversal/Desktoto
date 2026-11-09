import CoreGraphics

/// 별똥별 구경: 밤하늘을 올려다보다가 별똥별이 지나가면 눈이 커지고, 눈을 감고 소원을 빈다. 40칸이 한 바퀴다.
enum StargazingPieces {
    private static let originY: CGFloat = 4
    private static let starColor = IconColor.calibrated(red: 1.00, green: 0.92, blue: 0.55, alpha: 1)
    private static let streakColor = IconColor.gray(white: 1, alpha: 1)
    private static let wishColor = IconColor.calibrated(red: 1.00, green: 0.85, blue: 0.30, alpha: 1)
    /// 반짝이는 별의 자리. 앞의 둘은 십자 모양이다.
    private static let stars = [(3, 3), (38, 3), (6, 10), (1, 15), (40, 9), (36, 15)]
    private static let crossGlyph = ["010", "111", "010"]

    static func pieces(step: Int, bodyColor: IconColor) -> [IconPiece] {
        let isStreaking = (14...19).contains(step)
        let isWishing = (20...31).contains(step)
        let expression: EyeExpression = isStreaking ? .wide : (isWishing ? .blink : .open)
        var pieces = RestArt.character(gaze: GazeDirection(horizontal: 3, vertical: -4), expression: expression, bodyColor: bodyColor, originY: originY)

        // 별은 저마다 다른 박자로 깜빡인다.
        stars.enumerated().forEach { index, star in
            let isBright = (step + index * 3) % 6 < 4
            let color = starColor.with(alpha: isBright ? 1 : 0.4)
            if index < 2 {
                pieces += RestArt.glyph(crossGlyph, x: star.0 - 1, y: star.1 - 1, color: color)
            } else if let piece = RestArt.visibleCell(star.0, star.1, color) {
                pieces.append(piece)
            }
        }

        // 별똥별은 오른쪽 위에서 왼쪽 아래로 꼬리를 끌며 지나간다.
        if isStreaking {
            let progress = step - 14
            let headX = 41 - progress * 2
            let headY = progress * 2
            if let head = RestArt.visibleCell(headX, headY, streakColor) { pieces.append(head) }
            (1...3).forEach { tail in
                let alpha = 0.85 - 0.22 * CGFloat(tail)
                if let piece = RestArt.visibleCell(headX + tail, headY - tail, streakColor.with(alpha: alpha)) { pieces.append(piece) }
            }
        }

        // 소원을 비는 동안 머리 위에서 금빛 별이 깜빡인다.
        if isWishing, step % 2 == 0 {
            pieces += RestArt.glyph(crossGlyph, x: 20, y: 0, color: wishColor)
        }
        return pieces
    }
}
