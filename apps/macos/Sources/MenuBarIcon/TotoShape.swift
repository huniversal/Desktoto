import CoreGraphics

/// 메뉴바 토토의 몸 모양. 만두처럼 아래는 넓고 납작하게 둥글고, 양옆은 볼록하게 부풀고, 위는 둥글게 모인다.
/// 좌표는 위쪽이 작은 y인 좌표계(SwiftUI, 뒤집힌 AppKit 그리기)를 쓴다.
enum TotoShape {
    /// 눈을 놓을 자리. 몸이 아래쪽으로 넓어서 정사각형 가운데보다 조금 아래다(정사각형 한 변 대비 y 이동).
    static let eyeCenterOffsetY: CGFloat = 0.08

    /// rect에 맞춘 만두 모양 경로. 가로세로가 다르면 그만큼 납작하거나 길쭉해진다(전환 중 찌그러질 때 쓴다).
    static func path(in rect: CGRect) -> CGPath {
        let point = { (x: CGFloat, y: CGFloat) in CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        let path = CGMutablePath()
        // 아래 가운데에서 시작해 왼쪽 아래 모서리, 볼록한 왼쪽 옆, 둥근 꼭대기, 오른쪽 옆, 오른쪽 아래 모서리를 돈다.
        path.move(to: point(0.5, 0.94))
        path.addCurve(to: point(0.06, 0.7), control1: point(0.16, 0.95), control2: point(0.05, 0.88))
        path.addCurve(to: point(0.5, 0.07), control1: point(0.07, 0.36), control2: point(0.24, 0.07))
        path.addCurve(to: point(0.94, 0.7), control1: point(0.76, 0.07), control2: point(0.93, 0.36))
        path.addCurve(to: point(0.5, 0.94), control1: point(0.95, 0.88), control2: point(0.84, 0.95))
        path.closeSubpath()
        return path
    }
}
