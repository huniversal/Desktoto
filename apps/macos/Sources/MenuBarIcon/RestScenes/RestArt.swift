import CoreGraphics

/// 쉬는 일의 그림을 그릴 때 공통으로 쓰는 도구. 좌표는 캔버스 왼쪽 위를 (0, 0)으로 둔 칸 단위다.
enum RestArt {
    /// 서 있는 캐릭터의 가로 위치
    static let originX = CharacterGrid.standingOriginX

    static func character(
        gaze: GazeDirection = .center,
        expression: EyeExpression = .open,
        bodyColor: IconColor,
        originY: CGFloat
    ) -> [IconPiece] {
        IconScene.characterPieces(
            pose: .standing,
            gaze: gaze,
            expression: expression,
            bodyColor: bodyColor,
            originX: originX,
            originY: originY
        )
    }

    static func cell(_ x: Int, _ y: Int, _ color: IconColor) -> IconPiece {
        IconPiece(rect: UnitRect(CGFloat(x), CGFloat(y), 1, 1), color: color)
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: IconColor) -> IconPiece {
        IconPiece(rect: UnitRect(x, y, width, height), color: color)
    }

    /// 캔버스 안에 있는 칸만 돌려준다. 가장자리에서 잘리는 알갱이를 걸러 낸다.
    static func visibleCell(_ x: Int, _ y: Int, _ color: IconColor) -> IconPiece? {
        guard x >= 0, y >= 0, CGFloat(x) < CharacterGrid.canvasWidth, CGFloat(y) < CharacterGrid.canvasHeight else { return nil }
        return cell(x, y, color)
    }

    static func glyph(_ rows: [String], x: Int, y: Int, color: IconColor) -> [IconPiece] {
        rows.enumerated().flatMap { rowIndex, line in
            line.enumerated().compactMap { columnIndex, character in
                character == "1" ? visibleCell(x + columnIndex, y + rowIndex, color) : nil
            }
        }
    }
}
