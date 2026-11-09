import CoreGraphics

/// 따뜻한 음료: 두 손으로 컵을 쥐고 김이 모락모락 오른다. 가끔 한 모금 마시며 눈을 감는다. 24칸이 한 바퀴다.
enum DrinkPieces {
    private static let originY: CGFloat = 3
    private static let mug = IconColor.calibrated(red: 0.95, green: 0.72, blue: 0.48, alpha: 1)
    private static let mugShade = IconColor.calibrated(red: 0.80, green: 0.55, blue: 0.34, alpha: 1)
    private static let coffee = IconColor.calibrated(red: 0.38, green: 0.22, blue: 0.12, alpha: 1)
    private static let steam = IconColor.gray(white: 1, alpha: 0.85)

    static func pieces(step: Int, bodyColor: IconColor) -> [IconPiece] {
        let isSipping = (14...19).contains(step)
        let lift = isSipping ? 1 : 0
        let mugTop = Int(originY) + 6 - lift
        var pieces = RestArt.character(expression: isSipping ? .blink : .open, bodyColor: bodyColor, originY: originY)

        // 컵: 몸통, 아래쪽 그늘, 위쪽 음료, 오른쪽 손잡이
        pieces.append(RestArt.rect(32, CGFloat(mugTop), 5, 6, mug))
        pieces.append(RestArt.rect(32, CGFloat(mugTop + 5), 5, 1, mugShade))
        pieces.append(RestArt.rect(32, CGFloat(mugTop), 5, 1, coffee))
        pieces.append(RestArt.rect(37, CGFloat(mugTop + 1), 2, 1, mug))
        pieces.append(RestArt.rect(38, CGFloat(mugTop + 2), 1, 2, mug))
        pieces.append(RestArt.rect(37, CGFloat(mugTop + 4), 2, 1, mug))

        // 김: 두 줄기가 구불구불 올라가며 옅어진다.
        [33, 35].enumerated().forEach { columnIndex, baseX in
            (0..<3).forEach { strand in
                let height = (step + strand * 3 + columnIndex * 2) % 9
                let wave = ((height + step / 2) % 4) < 2 ? 0 : 1
                let alpha = max(0.85 - 0.08 * Double(height), 0.2)
                if let piece = RestArt.visibleCell(baseX + wave, mugTop - 1 - height, steam.with(alpha: CGFloat(alpha))) {
                    pieces.append(piece)
                }
            }
        }
        return pieces
    }
}
