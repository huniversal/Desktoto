import CoreGraphics

/// 쉬는 동안 메뉴바에서 낚시하는 캐릭터의 그림 목록. 캔버스(42x20칸) 안에 모자, 몸, 낚싯대, 줄, 물고기가 모두 들어온다.
/// 좌표는 캔버스 왼쪽 위를 (0, 0)으로 둔 칸 단위다.
enum FishingPieces {
    /// 낚싯대가 오른쪽으로 뻗어서 서 있을 때보다 왼쪽에 앉는다.
    static let originX: CGFloat = 3
    private static let handPoint = (x: 27, y: 11)
    private static let rodTipX = 38
    private static let legColumns: [CGFloat] = [4, 7, 15, 18]
    private static let legLengths: [[CGFloat]] = [[4, 4, 3, 3], [3, 3, 4, 4]]
    /// 매달린 물고기: 입이 위쪽이다. 1이 칠해지는 칸이다.
    private static let fishRows = ["01110", "11111", "11111", "01110", "10101", "00100"]
    private static let sparkleCenters = [(x: 31, y: 15), (x: 33, y: 18)]

    static func pieces(frame: FishingFrame, bodyColor: IconColor) -> [IconPiece] {
        var pieces: [IconPiece] = []
        let x = originX

        // 다리, 팔, 몸통
        let lengths = legLengths[frame.legSwing % 2]
        zip(legColumns, lengths).forEach { column, length in
            pieces.append(IconPiece(rect: UnitRect(x + column, 16, 2, length), color: bodyColor))
        }
        pieces.append(IconPiece(rect: UnitRect(x, 10, 3, 3), color: bodyColor))
        pieces.append(IconPiece(rect: UnitRect(x + 21, 10, 3, 3), color: bodyColor))
        pieces.append(IconPiece(rect: UnitRect(x + 3, 4, 18, 12), color: bodyColor))

        // 눈
        eyeRects(for: frame.eyes).forEach {
            pieces.append(IconPiece(rect: $0.offsetBy(x: x, y: 0), color: IconPalette.eye))
        }

        // 낚시 모자: 둥근 윗부분, 갈색 띠, 넓은 챙
        pieces.append(IconPiece(rect: UnitRect(x + 6, 0, 12, 3), color: IconPalette.hatCrown))
        pieces.append(IconPiece(rect: UnitRect(x + 6, 2, 12, 1), color: IconPalette.hatBand))
        pieces.append(IconPiece(rect: UnitRect(x + 1, 3, 22, 2), color: IconPalette.hatBrim))

        // 낚싯대
        let tip = rodTip(for: frame.rod)
        rodCells(pose: frame.rod, tip: tip).forEach {
            pieces.append(IconPiece(rect: UnitRect(CGFloat($0.x), CGFloat($0.y), 1, 1), color: IconPalette.rod))
        }

        // 줄은 낚싯대 끝에서 아래로 내려온다. 입질할 때 옆으로 한 칸 떨린다.
        let lineX = tip.x + frame.lineWiggle
        let lineTop = tip.y + 1
        let lineEnd = lineTop + frame.lineLength
        pieces.append(IconPiece(rect: UnitRect(CGFloat(lineX), CGFloat(lineTop), 1, CGFloat(frame.lineLength)), color: IconPalette.fishingLine))

        if frame.hasFish {
            pieces += fishPieces(topLeftX: lineX - 2, topY: lineEnd, haloColor: bodyColor.with(alpha: 0.5))
        } else {
            pieces.append(IconPiece(rect: UnitRect(CGFloat(lineX), CGFloat(lineEnd), 1, 2), color: IconPalette.fishingHook))
            pieces.append(IconPiece(rect: UnitRect(CGFloat(lineX - 1), CGFloat(lineEnd + 1), 1, 1), color: IconPalette.fishingHook))
        }

        // 입질을 알리는 느낌표는 모자 왼쪽에 뜬다.
        if frame.hasBubble {
            pieces.append(IconPiece(rect: UnitRect(1, 1, 2, 4), color: IconPalette.fishingBubble))
            pieces.append(IconPiece(rect: UnitRect(1, 6, 2, 2), color: IconPalette.fishingBubble))
        }
        if frame.isSparkling {
            sparkleCenters.forEach { center in
                pieces.append(IconPiece(rect: UnitRect(CGFloat(center.x), CGFloat(center.y - 1), 1, 3), color: IconPalette.fishingSparkle))
                pieces.append(IconPiece(rect: UnitRect(CGFloat(center.x - 1), CGFloat(center.y), 3, 1), color: IconPalette.fishingSparkle))
            }
        }
        return pieces
    }

    /// 눈은 평소 눈(3칸 높이)이 기준이고, 졸 때처럼 감은 눈과 놀라서 커진 눈이 있다. 몸통이 4칸 아래에서 시작해서 그만큼 내려 그린다.
    private static func eyeRects(for eyes: FishingEyes) -> [UnitRect] {
        switch eyes {
        case .closed: return [UnitRect(6, 9, 2, 1), UnitRect(16, 9, 2, 1)]
        case .open: return [UnitRect(6, 7, 2, 3), UnitRect(16, 7, 2, 3)]
        case .wide: return [UnitRect(6, 6, 2, 4), UnitRect(16, 6, 2, 4)]
        }
    }

    static func rodTip(for pose: RodPose) -> (x: Int, y: Int) {
        switch pose {
        case .rest: return (rodTipX, 12)
        case .up: return (rodTipX, 10)
        case .down: return (rodTipX, 13)
        case .bent: return (rodTipX, 11)
        }
    }

    /// 손에서 끝까지 이어지는 칸들. 휘어진 낚싯대는 위로 불룩한 곡선이다.
    private static func rodCells(pose: RodPose, tip: (x: Int, y: Int)) -> [(x: Int, y: Int)] {
        let start = (x: Double(handPoint.x), y: Double(handPoint.y))
        let end = (x: Double(tip.x), y: Double(tip.y))
        let control = pose == .bent ? (x: 32.0, y: 8.0) : (x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        var cells: [(x: Int, y: Int)] = []
        (0...60).forEach { step in
            let t = Double(step) / 60
            let px = (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x
            let py = (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y
            let cell = (x: Int(px.rounded(.down)), y: Int(py.rounded(.down)))
            if !cells.contains(where: { $0 == cell }) { cells.append(cell) }
        }
        return cells
    }

    /// 검은 물고기와 흰 눈. 어두운 메뉴바에서도 보이도록 몸 둘레에 옅은 테두리를 한 칸 두른다.
    private static func fishPieces(topLeftX: Int, topY: Int, haloColor: IconColor) -> [IconPiece] {
        var fishCells = Set<[Int]>()
        fishRows.enumerated().forEach { rowIndex, line in
            line.enumerated().forEach { columnIndex, cell in
                if cell == "1" { fishCells.insert([topLeftX + columnIndex, topY + rowIndex]) }
            }
        }
        var haloCells = Set<[Int]>()
        fishCells.forEach { cell in
            [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach { delta in
                let neighbor = [cell[0] + delta[0], cell[1] + delta[1]]
                if !fishCells.contains(neighbor) { haloCells.insert(neighbor) }
            }
        }
        let halo = haloCells.sorted { ($0[1], $0[0]) < ($1[1], $1[0]) }.map {
            IconPiece(rect: UnitRect(CGFloat($0[0]), CGFloat($0[1]), 1, 1), color: haloColor)
        }
        let body = fishCells.sorted { ($0[1], $0[0]) < ($1[1], $1[0]) }.map {
            IconPiece(rect: UnitRect(CGFloat($0[0]), CGFloat($0[1]), 1, 1), color: IconPalette.fishBody)
        }
        let eye = IconPiece(rect: UnitRect(CGFloat(topLeftX + 1), CGFloat(topY + 1), 1, 1), color: IconPalette.fishEye)
        return halo + body + [eye]
    }
}
