import SwiftUI

// 막대 채움이 어떤 색으로 그려질지
enum UsageBarFill: Equatable {
    case danger
    case warning
    case gradient
    case plain

    init(ratio: Double, colorMode: ColorMode, thresholds: DSThreshold) {
        if ratio >= thresholds.danger {
            self = .danger
        } else if ratio >= thresholds.warning {
            self = .warning
        } else if colorMode == .color {
            self = .gradient
        } else {
            self = .plain
        }
    }

    var shapeStyle: AnyShapeStyle {
        switch self {
        case .danger: return AnyShapeStyle(DSColor.danger)
        case .warning: return AnyShapeStyle(DSColor.warning)
        case .gradient: return AnyShapeStyle(LinearGradient(colors: DSColor.barGradient, startPoint: .leading, endPoint: .trailing))
        case .plain: return AnyShapeStyle(Color.primary)
        }
    }
}

// ratio가 nil이면 트랙만 그린다. 0이어도 막대 높이만큼은 채워 보인다.
public struct UsageBar: View {
    @Environment(\.barColorMode) private var colorMode
    @Environment(\.colorScheme) private var colorScheme
    private let ratio: Double?
    private let thresholds: DSThreshold

    public init(ratio: Double?, thresholds: DSThreshold = .context) {
        self.ratio = ratio
        self.thresholds = thresholds
    }

    public var body: some View {
        Capsule()
            .fill(Color.primary.opacity(DSOpacity.barTrack))
            .frame(height: DSSize.barHeight)
            .overlay(alignment: .leading) {
                if let ratio {
                    GeometryReader { geometry in
                        Capsule()
                            .fill(UsageBarFill(ratio: ratio, colorMode: colorMode, thresholds: thresholds).shapeStyle)
                            .shadow(color: .black.opacity(colorMode == .white && colorScheme == .dark ? DSOpacity.barFillShadow : 0), radius: 0.5)
                            .frame(width: max(geometry.size.width * ratio, DSSize.barHeight))
                    }
                }
            }
    }
}
