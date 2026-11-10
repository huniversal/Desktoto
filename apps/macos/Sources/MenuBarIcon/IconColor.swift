import CoreGraphics
import DesignSystem

/// 그리기에 쓰는 색. 원본이 쓰던 색 공간을 그대로 유지하려고 종류를 나눠 둔다.
/// AppKit 색(NSColor)으로의 변환은 IconRenderer가 맡는다.
enum IconColor: Equatable, Sendable {
    /// `NSColor(calibratedWhite:alpha:)`
    case gray(white: CGFloat, alpha: CGFloat)
    /// `NSColor(calibratedRed:green:blue:alpha:)`
    case calibrated(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)
    /// `NSColor(srgbRed:green:blue:alpha:)`
    case srgb(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    func with(alpha: CGFloat) -> IconColor {
        switch self {
        case .gray(let white, _):
            return .gray(white: white, alpha: alpha)
        case .calibrated(let red, let green, let blue, _):
            return .calibrated(red: red, green: green, blue: blue, alpha: alpha)
        case .srgb(let red, let green, let blue, _):
            return .srgb(red: red, green: green, blue: blue, alpha: alpha)
        }
    }
}

/// 캐릭터를 그리는 색. 값은 원본 SpriteRenderer.swift와 같다.
/// 캐릭터 안에서만 쓰는 값이라 디자인 시스템이 아닌 여기서 정의한다.
enum IconPalette {
    /// 흰색 모드의 몸 색. 명암이나 반짝임 없이 평평하게 그린다.
    static let whiteBody = IconColor.gray(white: 1, alpha: 1)
    /// 컬러 모드의 몸 색(#DD8B70). Claude Code 캐릭터의 주황색에서 살짝 연하게 한 색이다.
    static let colorfulBody = IconColor.srgb(red: CGFloat(0xDD) / 255, green: CGFloat(0x8B) / 255, blue: CGFloat(0x70) / 255, alpha: 1)
    static let eye = IconColor.gray(white: 0.05, alpha: 1)
    static let speedLine = IconColor.gray(white: 0.8, alpha: 0.9)
    /// 승인 대기 물음표. 사람이 해야 할 일이라 바로 눈에 띄도록 빨간색을 쓴다(원본은 호박색).
    static let question = IconColor.calibrated(red: 1.00, green: 0.23, blue: 0.19, alpha: 1)
    /// 확인하지 않은 완료 점. 패널 카드의 점(DSColor.finishedDot)과 같은 값이다.
    static let doneDot = IconColor.calibrated(red: 0.68, green: 0.52, blue: 1.00, alpha: 1)
    /// 어지러울 때 반짝이는 별. 옅은 노랑이라 빨간 승인 대기 물음표와 구분된다.
    static let dizzySpark = IconColor.calibrated(red: 1.00, green: 0.93, blue: 0.50, alpha: 1)
    static let sleepZ = IconColor.gray(white: 1, alpha: 0.85)
    /// 낚시 모자(윗부분, 띠, 챙), 낚싯대, 줄, 바늘
    static let hatCrown = IconColor.calibrated(red: 0.85, green: 0.70, blue: 0.42, alpha: 1)
    static let hatBrim = IconColor.calibrated(red: 0.78, green: 0.60, blue: 0.31, alpha: 1)
    static let hatBand = IconColor.calibrated(red: 0.48, green: 0.32, blue: 0.19, alpha: 1)
    static let rod = IconColor.calibrated(red: 0.62, green: 0.42, blue: 0.24, alpha: 1)
    static let fishingLine = IconColor.gray(white: 1, alpha: 0.9)
    static let fishingHook = IconColor.gray(white: 0.8, alpha: 1)
    static let fishBody = IconColor.gray(white: 0.03, alpha: 1)
    static let fishEye = IconColor.gray(white: 1, alpha: 1)
    static let fishingBubble = IconColor.calibrated(red: 0.93, green: 0.22, blue: 0.22, alpha: 1)
    static let fishingSparkle = IconColor.calibrated(red: 1.00, green: 0.82, blue: 0.25, alpha: 1)
    static let fireworkFlash = IconColor.gray(white: 1, alpha: 1)
    static let fireworkSparks: [IconColor] = [
        .calibrated(red: 1.00, green: 0.62, blue: 0.78, alpha: 1),
        .calibrated(red: 1.00, green: 0.85, blue: 0.45, alpha: 1),
        .calibrated(red: 0.62, green: 0.82, blue: 1.00, alpha: 1),
        .calibrated(red: 0.74, green: 0.66, blue: 1.00, alpha: 1),
        .calibrated(red: 1.00, green: 1.00, blue: 1.00, alpha: 1)
    ]

    static func bodyColor(for colorMode: ColorMode) -> IconColor {
        colorMode == .color ? colorfulBody : whiteBody
    }
}
