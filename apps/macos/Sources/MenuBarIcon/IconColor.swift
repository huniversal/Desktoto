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
    /// 승인 대기 물음표. 눈에 띄도록 완료 점과 다른 호박색을 쓴다.
    static let question = IconColor.calibrated(red: 1.00, green: 0.80, blue: 0.35, alpha: 1)
    /// 확인하지 않은 완료 점. 패널 카드의 점(DSColor.finishedDot)과 같은 값이다.
    static let doneDot = IconColor.calibrated(red: 0.68, green: 0.52, blue: 1.00, alpha: 1)
    static let sleepZ = IconColor.gray(white: 1, alpha: 0.85)
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
