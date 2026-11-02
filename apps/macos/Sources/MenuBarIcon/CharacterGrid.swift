import CoreGraphics

/// 칸(유닛) 단위 사각형. 원점은 왼쪽 위이고 한 칸은 기본 1pt다.
struct UnitRect: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    func offsetBy(x offsetX: CGFloat, y offsetY: CGFloat) -> UnitRect {
        UnitRect(x + offsetX, y + offsetY, width, height)
    }
}

enum LegPose: Equatable, Sendable {
    case standing
    case runningA
    case runningB
    case sleeping
}

/// 캐릭터 왼쪽 위 모서리를 (0, 0)으로 둔 부위별 사각형.
struct CharacterRects: Equatable, Sendable {
    let legs: [UnitRect]
    let arms: [UnitRect]
    let body: UnitRect
    let eyes: [UnitRect]
}

/// 캔버스와 캐릭터의 격자 정의. 값은 원본 SpriteRenderer.swift와 같다.
/// 한 칸은 1pt이고 Retina 화면 픽셀 정확히 2개라서 픽셀 아트가 들쭉날쭉해지지 않는다.
enum CharacterGrid {
    static let characterWidth: CGFloat = 24
    static let characterHeight: CGFloat = 17
    /// 달릴 때 캐릭터가 움직이는 구역
    static let trackWidth: CGFloat = 36
    /// 완료 점이나 승인 대기 물음표를 위한 자리. 표시가 없어도 항상 확보해 메뉴바가 흔들리지 않는다.
    static let badgeWidth: CGFloat = 6
    static let canvasWidth: CGFloat = trackWidth + badgeWidth
    /// 캐릭터 17칸 + 위로 튀어오를 여유 2칸 + 아래 여백 1칸
    static let canvasHeight: CGFloat = 20
    static let travelWidth: CGFloat = trackWidth - characterWidth
    /// 서 있을 때는 점 자리까지 포함한 전체의 가운데에 둔다.
    static let standingOriginX: CGFloat = (canvasWidth - characterWidth) / 2
    static let maxBobHeight: CGFloat = 2
    /// 잠들면 몸이 한 칸 내려앉는다.
    static let sleepDropHeight: CGFloat = 1

    static let bodyRect = UnitRect(3, 0, 18, 12)
    static let eyeRects = [UnitRect(6, 3, 2, 3), UnitRect(16, 3, 2, 3)]
    /// 잠든 모습의 감은 눈: 뜬 눈의 맨 아래 한 줄만 남긴다.
    static let closedEyeRects = [UnitRect(6, 5, 2, 1), UnitRect(16, 5, 2, 1)]

    static let armTop: CGFloat = 6
    static let armWidth: CGFloat = 3
    static let armHeight: CGFloat = 3
    static let leftArmColumn: CGFloat = 0
    static let rightArmColumn: CGFloat = 21

    /// 다리 4개: 왼쪽 두 개와 오른쪽 두 개가 짝을 이루고 가운데는 넓게 비어 있다. 길이만 포즈마다 다르다.
    static let legColumns: [CGFloat] = [4, 7, 15, 18]
    static let legTop: CGFloat = 12
    static let legWidth: CGFloat = 2

    static func legLengths(for pose: LegPose) -> [CGFloat] {
        switch pose {
        case .standing: return [4, 4, 4, 4]
        case .runningA: return [5, 3, 5, 3]
        case .runningB: return [3, 5, 3, 5]
        // 몸이 한 칸 내려앉는 만큼 다리가 짧아져서 발 위치는 그대로다.
        case .sleeping: return [3, 3, 3, 3]
        }
    }

    /// 달릴 때 팔이 반대로 한 칸씩 위아래로 흔들린다.
    static func armOffsets(for pose: LegPose) -> (left: CGFloat, right: CGFloat) {
        switch pose {
        case .standing, .sleeping: return (0, 0)
        case .runningA: return (-1, 1)
        case .runningB: return (1, -1)
        }
    }

    static func rects(for pose: LegPose) -> CharacterRects {
        let offsets = armOffsets(for: pose)
        return CharacterRects(
            legs: zip(legColumns, legLengths(for: pose)).map { UnitRect($0, legTop, legWidth, $1) },
            arms: [
                UnitRect(leftArmColumn, armTop + offsets.left, armWidth, armHeight),
                UnitRect(rightArmColumn, armTop + offsets.right, armWidth, armHeight)
            ],
            body: bodyRect,
            eyes: pose == .sleeping ? closedEyeRects : eyeRects
        )
    }
}

/// 문자 격자("1"이 칠해지는 칸)를 칸 단위 사각형으로 바꾼다.
enum Glyph {
    static func cells(of rows: [String], column: CGFloat, row: CGFloat) -> [UnitRect] {
        rows.enumerated().flatMap { rowIndex, line in
            line.enumerated().compactMap { columnIndex, cell in
                cell == "1" ? UnitRect(column + CGFloat(columnIndex), row + CGFloat(rowIndex), 1, 1) : nil
            }
        }
    }
}
