import CoreGraphics

/// 음악 듣기: 헤드폰을 끼고 몸을 까딱이며 눈을 감고, 머리 옆으로 음표가 떠오른다. 16칸이 한 바퀴다.
enum MusicPieces {
    private static let baseY = 3
    private static let band = IconColor.calibrated(red: 1.00, green: 0.45, blue: 0.65, alpha: 1)
    private static let cup = IconColor.calibrated(red: 0.95, green: 0.30, blue: 0.52, alpha: 1)
    private static let noteGlyph = ["0011", "0010", "0010", "1110", "1100"]
    private static let rightNote = IconColor.calibrated(red: 1.00, green: 0.86, blue: 0.35, alpha: 1)
    private static let leftNote = IconColor.calibrated(red: 0.62, green: 0.86, blue: 1.00, alpha: 1)

    static func pieces(step: Int, bodyColor: IconColor) -> [IconPiece] {
        // 두 칸마다 한 칸씩 위아래로 까딱인다. 잠깐 눈을 뜨고 박자를 느낀다.
        let bob = (step / 2) % 2
        let originY = baseY + bob
        let expression: EyeExpression = (6...7).contains(step) ? .open : .blink
        var pieces = RestArt.character(expression: expression, bodyColor: bodyColor, originY: CGFloat(originY))

        // 헤드폰: 머리 위를 덮는 띠와 양쪽 귀덮개
        pieces.append(RestArt.rect(12, CGFloat(originY - 1), 18, 1, band))
        pieces.append(RestArt.rect(10, CGFloat(originY + 1), 3, 5, cup))
        pieces.append(RestArt.rect(29, CGFloat(originY + 1), 3, 5, cup))

        // 음표 둘이 번갈아 떠오른다. 오른쪽은 오른쪽 위로, 왼쪽은 왼쪽 위로 떠오른다.
        let rightProgress = step
        pieces += RestArt.glyph(
            noteGlyph,
            x: 33 + rightProgress / 6,
            y: 11 - rightProgress * 11 / 16,
            color: rightNote
        )
        let leftProgress = (step + 8) % 16
        pieces += RestArt.glyph(
            noteGlyph,
            x: 4 - leftProgress / 8,
            y: 11 - leftProgress * 11 / 16,
            color: leftNote
        )
        return pieces
    }
}
