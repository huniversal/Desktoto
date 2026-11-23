import SwiftUI

/// 노치 봇과 메뉴바 토토 사이를 오가는 물방울 전환을 그린다.
/// 노치 밖 봇 몸과 물방울을 흐린 뒤 투명도 경계로 잘라서, 가까우면 서로 끈적하게 이어지고 멀어지면 똑 끊긴다.
/// 노치 봇 창처럼 노치 전체 모양(아래 둥근 모서리, 위쪽 오목 곡선)을 함께 그려서 전환 전후 모양이 이어지게 한다.
public struct PlacementTransitionView: View {
    private let motion: PlacementTransitionMotion
    /// 노치 왼쪽, 오른쪽 끝 x와 노치 높이(전환 창 좌표)
    private let notchMinX: CGFloat
    private let notchMaxX: CGFloat
    private let notchHeight: CGFloat
    private let startDate: Date

    /// 흐림 반지름. 클수록 더 멀리서부터 이어진다.
    private static let gooBlur: CGFloat = 3.5
    /// 노치 아래 모서리 반경과 위쪽 오목 곡선 반지름(노치 봇과 같다)
    private static let cornerRadius: CGFloat = 12
    private static let flareRadius: CGFloat = 6

    public init(motion: PlacementTransitionMotion, notchMinX: CGFloat, notchMaxX: CGFloat, notchHeight: CGFloat, startDate: Date) {
        self.motion = motion
        self.notchMinX = notchMinX
        self.notchMaxX = notchMaxX
        self.notchHeight = notchHeight
        self.startDate = startDate
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let frame = motion.frame(at: context.date.timeIntervalSince(startDate))
            ZStack(alignment: .topLeading) {
                Canvas { canvas, _ in
                    canvas.addFilter(.alphaThreshold(min: 0.5, color: .black))
                    canvas.addFilter(.blur(radius: Self.gooBlur))
                    canvas.drawLayer { layer in
                        // 노치와 그 오른쪽에 붙은 봇 몸. 위로 넉넉히 올려 흐림에 위쪽 가장자리가 깎이지 않게 한다.
                        let lift: CGFloat = 20
                        let body = CGRect(x: notchMinX, y: -lift, width: notchMaxX - notchMinX + frame.attachedWidth, height: notchHeight + lift)
                        layer.fill(
                            Path(roundedRect: body, cornerRadii: RectangleCornerRadii(bottomLeading: Self.cornerRadius, bottomTrailing: Self.cornerRadius)),
                            with: .color(.black)
                        )
                        layer.fill(Path(ellipseIn: dropRect(frame)), with: .color(.black))
                    }
                }
                Canvas { canvas, _ in
                    // 위쪽 양끝 오목 곡선은 흐림에 지워지지 않도록 필터 없는 층에 그린다. 오른쪽은 봇 몸 끝을 따라간다.
                    drawFlare(in: &canvas, edgeX: notchMinX, isLeft: true)
                    drawFlare(in: &canvas, edgeX: notchMaxX + frame.attachedWidth, isLeft: false)
                    drawEyes(in: &canvas, frame: frame)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func dropRect(_ frame: PlacementTransitionMotion.Frame) -> CGRect {
        let width = frame.size * frame.scaleX
        let height = frame.size * frame.scaleY
        return CGRect(x: frame.center.x - width / 2, y: frame.center.y - height / 2, width: width, height: height)
    }

    /// 노치 위쪽 끝이 화면 가장자리로 오목하게 녹아드는 곡선. edgeX는 몸의 왼쪽(또는 오른쪽) 끝이다.
    private func drawFlare(in canvas: inout GraphicsContext, edgeX: CGFloat, isLeft: Bool) {
        let flare = Self.flareRadius
        let outerX = isLeft ? edgeX - flare : edgeX + flare
        var path = Path()
        path.move(to: CGPoint(x: outerX, y: 0))
        path.addLine(to: CGPoint(x: edgeX, y: 0))
        path.addLine(to: CGPoint(x: edgeX, y: flare))
        path.addQuadCurve(to: CGPoint(x: outerX, y: 0), control: CGPoint(x: edgeX, y: 0))
        path.closeSubpath()
        canvas.fill(path, with: .color(.black))
    }

    /// 토토와 같은 알약 눈 두 개. 물방울과 함께 늘어나고 -12도 기울어진다.
    private func drawEyes(in canvas: inout GraphicsContext, frame: PlacementTransitionMotion.Frame) {
        let eyeWidth = frame.size * 0.122 * frame.scaleX
        let eyeHeight = frame.size * 0.27 * frame.scaleY
        let distance = frame.size * 0.233 * frame.scaleX
        canvas.translateBy(x: frame.center.x, y: frame.center.y)
        canvas.rotate(by: .degrees(-12))
        for side in [-1.0, 1.0] {
            let rect = CGRect(x: side * distance / 2 - eyeWidth / 2, y: -eyeHeight / 2, width: eyeWidth, height: eyeHeight)
            canvas.fill(Path(roundedRect: rect, cornerRadius: min(eyeWidth, eyeHeight) / 2), with: .color(.white))
        }
    }
}
