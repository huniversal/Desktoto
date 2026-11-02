import AppKit
import SwiftUI

public enum DSColor {
    // 승인 대기 알약의 호박색
    public static let approvalPill = Color(red: 1.00, green: 0.78, blue: 0.30)
    // 확인하지 않은 완료를 알리는 점의 보라색
    public static let finishedDot = Color(nsColor: NSColor(calibratedRed: 0.68, green: 0.52, blue: 1.00, alpha: 1))
    public static let warning = Color.orange
    public static let danger = Color.red
    // 컬러 모드 막대의 파랑에서 보라로 이어지는 그라데이션
    public static let barGradient: [Color] = [
        Color(red: 0.45, green: 0.65, blue: 1.00),
        Color(red: 0.68, green: 0.50, blue: 1.00)
    ]
    // 흐르는 그라데이션의 파스텔 색: 핑크, 복숭아, 라벤더, 하늘색
    public static let pastelPalette: [Color] = [
        Color(red: 1.00, green: 0.62, blue: 0.78),
        Color(red: 1.00, green: 0.78, blue: 0.62),
        Color(red: 0.74, green: 0.66, blue: 1.00),
        Color(red: 0.62, green: 0.82, blue: 1.00)
    ]
}
