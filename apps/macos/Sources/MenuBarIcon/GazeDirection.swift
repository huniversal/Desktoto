import CoreGraphics

/// 대기 중인 캐릭터가 마우스를 바라보는 방향. 가로는 -6...6(13단계), 세로는 -4...4(9단계)이고 한 단계가 눈이 반 칸(화면 픽셀 1개) 움직이는 양이다.
public struct GazeDirection: Equatable, Hashable, Sendable {
    /// 음수는 왼쪽, 양수는 오른쪽
    public let horizontal: Int
    /// 음수는 위쪽, 양수는 아래쪽
    public let vertical: Int

    public static let center = GazeDirection(horizontal: 0, vertical: 0)

    public static let maxHorizontal = 6
    public static let maxVertical = 4
    /// 마우스가 이 거리(pt) 안쪽이면 그 축은 정면으로 본다.
    public static let horizontalDeadZone: CGFloat = 15
    public static let verticalDeadZone: CGFloat = 10
    /// 마우스가 이 거리(pt) 이상 멀어지면 그 축은 끝까지 돌아본 상태다.
    public static let horizontalFullRange: CGFloat = 250
    public static let verticalFullRange: CGFloat = 150

    /// 이미지 묶음에서 쓰는 개수. 위 왼쪽이 0, 아래 오른쪽이 마지막 번호다.
    static let count = (2 * maxHorizontal + 1) * (2 * maxVertical + 1)

    public init(horizontal: Int, vertical: Int) {
        self.horizontal = min(max(horizontal, -Self.maxHorizontal), Self.maxHorizontal)
        self.vertical = min(max(vertical, -Self.maxVertical), Self.maxVertical)
    }

    var index: Int {
        (vertical + Self.maxVertical) * (2 * Self.maxHorizontal + 1) + (horizontal + Self.maxHorizontal)
    }

    /// 번호에서 방향을 되돌린다. index의 역함수다.
    init(index: Int) {
        let columns = 2 * Self.maxHorizontal + 1
        self.init(horizontal: index % columns - Self.maxHorizontal, vertical: index / columns - Self.maxVertical)
    }

    /// 캐릭터 중심에서 마우스까지의 거리로 방향을 정한다. 거리에 비례해 단계가 커진다. 화면 좌표라서 위쪽이 +y다.
    public static func make(offsetX: CGFloat, offsetY: CGFloat) -> GazeDirection {
        GazeDirection(
            horizontal: level(of: offsetX, deadZone: horizontalDeadZone, fullRange: horizontalFullRange, maxLevel: maxHorizontal),
            vertical: -level(of: offsetY, deadZone: verticalDeadZone, fullRange: verticalFullRange, maxLevel: maxVertical)
        )
    }

    private static func level(of value: CGFloat, deadZone: CGFloat, fullRange: CGFloat, maxLevel: Int) -> Int {
        let distance = abs(value) - deadZone
        guard distance > 0 else { return 0 }
        let ratio = min(distance / (fullRange - deadZone), 1)
        let level = Int((ratio * CGFloat(maxLevel)).rounded())
        return value < 0 ? -level : level
    }
}

/// 시선의 실제 위치. 정수 단계 사이를 오가는 소수 값이라서, 목표를 향해 속도를 줄이며 다가가는 움직임을 만든다.
public struct GazePosition: Equatable, Sendable {
    public var horizontal: Double
    public var vertical: Double

    public static let center = GazePosition(horizontal: 0, vertical: 0)
    /// 한 틱에 남은 거리의 이만큼을 간다. 멀수록 빠르고 가까울수록 느려진다.
    public static let easeRate = 0.3
    /// 남은 거리가 반 단계 이하면 화면에 보이는 그림이 같아서 바로 목표에 붙인다.
    static let snapDistance = 0.5

    public init(horizontal: Double, vertical: Double) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// 지금 보여 줄 방향. 가장 가까운 단계로 반올림한다.
    public var direction: GazeDirection {
        GazeDirection(horizontal: Int(horizontal.rounded()), vertical: Int(vertical.rounded()))
    }

    public func hasReached(_ target: GazeDirection) -> Bool {
        horizontal == Double(target.horizontal) && vertical == Double(target.vertical)
    }

    public func eased(toward target: GazeDirection) -> GazePosition {
        GazePosition(
            horizontal: Self.ease(horizontal, toward: Double(target.horizontal)),
            vertical: Self.ease(vertical, toward: Double(target.vertical))
        )
    }

    private static func ease(_ value: Double, toward target: Double) -> Double {
        let distance = target - value
        return abs(distance) <= snapDistance ? target : value + distance * easeRate
    }
}
