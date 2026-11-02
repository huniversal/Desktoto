import CoreGraphics
import DesignSystem

/// 캐릭터를 따라다니는 표시. 승인 대기 물음표가 완료 점보다 우선한다(사람이 해야 할 일이 더 급하다).
public enum IconBadge: Equatable, Sendable {
    case none
    case unseenDone
    case waiting

    public init(hasUnseenDone: Bool, isWaiting: Bool) {
        if isWaiting {
            self = .waiting
        } else if hasUnseenDone {
            self = .unseenDone
        } else {
            self = .none
        }
    }
}

/// 이미지를 만드는 조건. 이 값이 바뀔 때만 이미지를 다시 만든다.
/// 완료 여부와 대기 여부를 따로 들고 있는 이유는, 잠든 모습이 대기를 무시하고 완료 점만 보기 때문이다(원본과 같다).
public struct IconAppearance: Equatable, Sendable {
    public var colorMode: ColorMode
    public var hasUnseenDone: Bool
    public var isWaiting: Bool

    public init(colorMode: ColorMode = .white, hasUnseenDone: Bool = false, isWaiting: Bool = false) {
        self.colorMode = colorMode
        self.hasUnseenDone = hasUnseenDone
        self.isWaiting = isWaiting
    }

    var badge: IconBadge {
        IconBadge(hasUnseenDone: hasUnseenDone, isWaiting: isWaiting)
    }
}

/// 배지 자리의 격자. 캐릭터 오른쪽 위에 붙고 위아래 움직임은 따라가지 않는다.
enum BadgeGrid {
    /// 캐릭터와의 간격
    static let gap: CGFloat = 1
    static let doneDotSize: CGFloat = 4
    /// 승인 대기 물음표(5x7). 1이 칠해지는 칸이다.
    static let questionGlyph = ["01110", "10001", "00001", "00110", "00100", "00000", "00100"]

    static func originX(characterOriginX: CGFloat) -> CGFloat {
        characterOriginX + CharacterGrid.characterWidth + gap
    }
}
