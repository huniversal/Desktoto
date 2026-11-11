import CoreGraphics

/// 비눗방울: 입을 오므려 방울을 불고, 방울이 커지며 오른쪽 위로 떠올라 톡 터진다. 40칸이 한 바퀴다.
enum BubblePieces {
    private static let originY: CGFloat = 3
    private static let lifeSteps = 14
    private static let startSteps = [0, 13, 26]
    private static let smallRing = ["010", "101", "010"]
    private static let bigRing = ["01110", "10001", "10001", "10001", "01110"]
    private static let outline = IconColor.calibrated(red: 0.35, green: 0.72, blue: 1.00, alpha: 1)
    private static let shine = IconColor.gray(white: 1, alpha: 1)
    private static let pop = IconColor.calibrated(red: 0.62, green: 0.85, blue: 1.00, alpha: 0.9)

    static func pieces(step: Int, bodyColor: IconColor) -> [IconPiece] {
        let ages = startSteps.compactMap { start -> Int? in
            let age = step - start
            return (0..<lifeSteps).contains(age) ? age : nil
        }
        // 방울이 커지는 동안은 입을 크게 오므려 불고, 나머지는 작게 오므린다.
        let isBlowing = ages.contains { $0 < 3 }
        var pieces = RestArt.character(expression: .yawn(phase: isBlowing ? 1 : 0), bodyColor: bodyColor, originY: originY)

        ages.forEach { age in
            let x = 24 + age
            let y = 10 - age * 7 / 10
            if age >= 12 {
                // 터지는 순간: 방울이 있던 자리에서 알갱이가 사방으로 퍼진다.
                let centerX = x + 2
                let centerY = y + 2
                [(-2, 0), (2, 0), (0, -2), (0, 2)].forEach { dx, dy in
                    if let piece = RestArt.visibleCell(centerX + dx, centerY + dy, pop) { pieces.append(piece) }
                }
            } else if age < 3 {
                pieces += RestArt.glyph(smallRing, x: x, y: y + 1, color: outline)
            } else {
                pieces += RestArt.glyph(bigRing, x: x, y: y, color: outline)
                if let piece = RestArt.visibleCell(x + 1, y + 1, shine) { pieces.append(piece) }
            }
        }
        return pieces
    }
}
