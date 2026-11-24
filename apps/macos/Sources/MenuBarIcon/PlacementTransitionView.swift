import SwiftUI

/// 노치 봇과 메뉴바 토토 사이를 오가는 물방울 전환을 그린다.
/// 노치 밖 봇 몸과 물방울을 흐린 뒤 투명도 경계로 잘라서, 가까우면 서로 끈적하게 이어지고 멀어지면 똑 끊긴다.
/// 노치 봇 창처럼 노치 전체 모양(아래 둥근 모서리, 위쪽 오목 곡선)을 함께 그려서 전환 전후 모양이 이어지게 한다.
public struct PlacementTransitionView: View {
    /// 전환하는 동안 캐릭터 몸 색. 노치 봇과 메뉴바 토토가 띠던 색을 그대로 지닌 채 옮겨 간다.
    public enum Tint: Sendable {
        case none
        case working
        case waiting
    }

    private let motion: PlacementTransitionMotion
    private let tint: Tint
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

    public init(motion: PlacementTransitionMotion, tint: Tint, notchMinX: CGFloat, notchMaxX: CGFloat, notchHeight: CGFloat, startDate: Date) {
        self.motion = motion
        self.tint = tint
        self.notchMinX = notchMinX
        self.notchMaxX = notchMaxX
        self.notchHeight = notchHeight
        self.startDate = startDate
    }

    public var body: some View {
        GeometryReader { geometry in
        TimelineView(.animation) { context in
            let frame = motion.frame(at: context.date.timeIntervalSince(startDate))
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                gooShape(frame: frame)
                // 위쪽 양끝 오목 곡선은 흐림에 지워지지 않도록 필터 없이 그린다. 오른쪽은 봇 몸 끝을 따라가고 몸 색 아래에 깔린다.
                Canvas { canvas, _ in
                    drawFlare(in: &canvas, edgeX: notchMinX, isLeft: true)
                    drawFlare(in: &canvas, edgeX: notchMaxX + frame.attachedWidth, isLeft: false)
                }
                // 몸 색: 같은 끈적한 모양으로 오려 낸 각도 그라데이션을 검정 위에 85%로 얹는다. 노치 쪽은 노치 봇처럼 검정에 스며들게 흐린다.
                if let colors = tintColors {
                    let seconds = context.date.timeIntervalSinceReferenceDate
                    let angle = Angle.degrees(seconds.truncatingRemainder(dividingBy: 6) / 6 * 360)
                    // 노치 봇처럼 물방울 오른쪽 바깥을 중심으로 색이 부채꼴로 퍼진다.
                    let pivot = UnitPoint(x: (frame.center.x + frame.size * 0.8) / max(size.width, 1), y: frame.center.y / max(size.height, 1))
                    let fadeEnd = min(1, notchMaxX / max(size.width, 1))
                    let attachedRatio = min(max(frame.attachedWidth / max(motion.botWidth, 1), 0), 1)
                    let fadeStart = max(0, (notchMaxX - NotchBotStyle.colorFadeWidth) / max(size.width, 1))
                    AngularGradient(colors: colors, center: pivot, angle: angle)
                        // 오른쪽 위 오목 곡선도 봇 몸의 일부라 같은 색을 입힌다.
                        .mask(ZStack(alignment: .topLeading) {
                            gooShape(frame: frame)
                            Canvas { canvas, _ in drawFlare(in: &canvas, edgeX: notchMaxX + frame.attachedWidth, isLeft: false) }
                        })
                        .mask(
                            LinearGradient(
                                // 노치 안쪽으로 스며드는 색은 봇 몸이 노치 밖에 나와 있는 만큼만 진하다. 봇이 떨어지면 노치는 검정으로 돌아간다.
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .clear, location: fadeStart),
                                    .init(color: .black.opacity(attachedRatio), location: fadeEnd),
                                    // 노치 바깥은 늘 제 색이다. 노치 끝에 닿아 버티는 물방울이 어두워지지 않게 3pt 안에 다 물든다.
                                    .init(color: .black, location: min(1, fadeEnd + 3 / max(size.width, 1)))
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(0.85)
                }
                Canvas { canvas, _ in
                    drawEyes(in: &canvas, frame: frame)
                }
            }
        }
        }
        .allowsHitTesting(false)
    }

    private var tintColors: [Color]? {
        switch tint {
        case .none: nil
        case .working: NotchBotStyle.workingColors
        case .waiting: NotchBotStyle.waitingColors
        }
    }

    /// 노치 몸과 물방울을 흐린 뒤 투명도 경계로 잘라 끈적하게 이은 검은 모양
    private func gooShape(frame: PlacementTransitionMotion.Frame) -> some View {
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
                        // 둥근 물방울과 만두 모양을 함께 그려, 흐림과 경계 자르기로 한 모양에서 다른 모양으로 녹아들듯 바뀌게 한다.
                        let rect = dropRect(frame)
                        let roundness = 1 - frame.triangle
                        if roundness > 0.01 {
                            layer.fill(Path(ellipseIn: rect.insetBy(dx: rect.width * 0.2 * frame.triangle, dy: rect.height * 0.2 * frame.triangle)), with: .color(.black))
                        }
                        if frame.triangle > 0.01 {
                            // 만두 모양도 물방울과 같이 가로세로로 늘고 줄어서, 웅크리거나 튀어 오를 때 같은 찌그러짐을 따라간다.
                            let grow = 0.6 + 0.4 * frame.triangle
                            layer.fill(Path(TotoShape.path(in: rect.insetBy(dx: rect.width * (1 - grow) / 2, dy: rect.height * (1 - grow) / 2))), with: .color(.black))
                        }
                    }
        }
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
        // 세로로 긴 알약보다 둥근 쪽에 가까운 눈(폭:높이 약 1:1.6). 물방울일 때는 물방울 크기에 비례한다.
        // 노치 봇 눈은 노치 높이에 비례해서 더 크므로, 봇 몸이 노치 밖으로 채워지는 만큼 노치 봇 눈으로 천천히 바뀐다.
        // 그래서 흡수가 끝나 진짜 노치 봇으로 바뀌는 순간에도, 떨어지기 시작하는 순간에도 눈 크기가 튀지 않는다.
        let attached = min(max(frame.attachedWidth / max(motion.botWidth, 1), 0), 1)
        let botEyeWidth = notchHeight * 0.13
        let eyeWidth = (frame.size * 0.135 + (botEyeWidth - frame.size * 0.135) * attached) * frame.scaleX
        let eyeHeight = (frame.size * 0.215 + (notchHeight * 0.21 - frame.size * 0.215) * attached) * frame.scaleY
        // 노치 봇 눈은 눈 폭의 0.9배만큼 떨어져 있다(가운데 사이 거리는 눈 폭의 1.9배).
        let distance = (frame.size * 0.233 + (botEyeWidth * 1.9 - frame.size * 0.233) * attached) * frame.scaleX
        // 만두 모양일 때는 눈을 가운데보다 조금 아래로 옮긴다.
        canvas.translateBy(x: frame.center.x, y: frame.center.y + TotoShape.eyeCenterOffsetY * frame.size * frame.triangle)
        canvas.rotate(by: .degrees(-12))
        for side in [-1.0, 1.0] {
            let rect = CGRect(x: side * distance / 2 - eyeWidth / 2, y: -eyeHeight / 2, width: eyeWidth, height: eyeHeight)
            canvas.fill(Path(roundedRect: rect, cornerRadius: min(eyeWidth, eyeHeight) / 2), with: .color(.white))
        }
    }
}
