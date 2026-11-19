import SwiftUI

/// 노치 봇의 표정
public enum NotchBotExpression: Sendable {
    case open
    case blink
    case smile
    /// 마우스를 한동안 안 움직이면 눈꺼풀이 반쯤 내려온다.
    case sleepy
    /// 더 오래 쉬면 눈이 가는 선이 되고 옆으로 "z"가 떠오른다.
    case asleep
}

/// 노치 봇이 그릴 상태. 창 컨트롤러가 값을 바꾸면 뷰가 다시 그려진다.
@MainActor
@Observable
public final class NotchBotModel {
    /// 시선. -1...1 범위이고 가로는 오른쪽, 세로는 아래쪽이 양수다.
    public var gazeX: Double = 0
    public var gazeY: Double = 0
    public var expression: NotchBotExpression = .open
    public var isWorking = false
    /// 바뀔 때마다 눈이 위아래로 통통 튀며 웃는다.
    public var laughCount = 0
    /// 노치가 펼쳐져서 패널을 보여 주는지
    public var isExpanded = false
    /// 펼쳤을 때 패널 내용의 높이. 뷰가 재서 넣고, 창 컨트롤러는 클릭을 받을 영역을 이걸로 잡는다.
    public var contentHeight: CGFloat = 0
    /// 펼쳤을 때 눈이 맨 윗줄 오른쪽 띠에서 어디쯤 있는지. 0이면 노치 바로 오른쪽, 1이면 펼친 몸 오른쪽 끝이다.
    public var roamProgress: Double = 1

    public init() {}
}

/// 노치 봇 창 안의 위치 계산. 창(캔버스)은 펼친 크기를 담을 만큼 크고, 노치 가운데에 맞춰 놓인다.
/// 좌표는 캔버스 왼쪽 위가 원점이고 아래로 갈수록 y가 커진다.
public struct NotchBotLayout: Equatable, Sendable {
    public let notchWidth: CGFloat
    public let botWidth: CGFloat
    public let height: CGFloat
    public let expandedWidth: CGFloat
    public let maxContentHeight: CGFloat
    public let padding: CGFloat

    /// 실제 노치처럼 위쪽 양끝이 화면 가장자리로 오목하게 녹아드는 곡선의 반지름
    public static let flareRadius: CGFloat = 6

    public init(notchWidth: CGFloat, botWidth: CGFloat, height: CGFloat, expandedWidth: CGFloat, maxContentHeight: CGFloat, padding: CGFloat) {
        self.notchWidth = notchWidth
        self.botWidth = botWidth
        self.height = height
        self.expandedWidth = expandedWidth
        self.maxContentHeight = maxContentHeight
        self.padding = padding
    }

    public var canvasSize: CGSize {
        CGSize(width: expandedWidth + padding * 2, height: height + maxContentHeight + padding)
    }

    /// 검정 몸이 차지하는 사각형(위쪽 오목 곡선은 빼고). 접히면 노치와 그 오른쪽 봇, 펼치면 노치 가운데 기준으로 넓어진다.
    public func bodyRect(isExpanded: Bool, contentHeight: CGFloat) -> CGRect {
        if isExpanded {
            return CGRect(x: padding, y: 0, width: expandedWidth, height: height + min(contentHeight, maxContentHeight))
        }
        let notchLeft = padding + expandedWidth / 2 - notchWidth / 2
        return CGRect(x: notchLeft, y: 0, width: notchWidth + botWidth, height: height)
    }

    /// 눈이 있는 봇 자리. 몸의 오른쪽 위다.
    /// 펼쳤을 때 눈이 마우스를 따라 움직일 수 있는 띠. 노치 오른쪽 끝부터 펼친 몸 오른쪽 끝까지, 높이는 노치 높이다.
    public var roamRect: CGRect {
        let collapsed = bodyRect(isExpanded: false, contentHeight: 0)
        let expanded = bodyRect(isExpanded: true, contentHeight: 0)
        let left = collapsed.minX + notchWidth
        return CGRect(x: left, y: 0, width: expanded.maxX - left, height: height)
    }

    /// 눈이 지금 있는 자리. 접혔으면 봇 자리, 펼쳤으면 띠 안에서 roamProgress만큼 간 자리다.
    public func eyeRect(isExpanded: Bool, contentHeight: CGFloat, roamProgress: Double) -> CGRect {
        guard isExpanded else { return botRect(isExpanded: false, contentHeight: contentHeight) }
        let roam = roamRect
        let progress = min(max(roamProgress, 0), 1)
        return CGRect(x: roam.minX + (roam.width - botWidth) * progress, y: 0, width: botWidth, height: height)
    }

    public func botRect(isExpanded: Bool, contentHeight: CGFloat) -> CGRect {
        let body = bodyRect(isExpanded: isExpanded, contentHeight: contentHeight)
        return CGRect(x: body.maxX - botWidth, y: 0, width: botWidth, height: height)
    }
}

/// 노치와 그 오른쪽에 붙은 봇 몸을 하나의 검정 덩어리로 그리고, 봇 부분에 알약 눈을 단다.
/// 작업 중에는 봇 부분의 색이 바뀌고, 펼치면 노치가 커지며 그 안에 패널 내용을 보여 준다.
public struct NotchBotView<Content: View, Header: View>: View {
    private let model: NotchBotModel
    private let layout: NotchBotLayout
    private let content: Content
    private let header: Header

    /// content는 펼친 노치의 노치 아래 영역, header는 펼친 노치 맨 윗줄에서 노치 왼쪽에 남는 자리에 놓인다.
    public init(
        model: NotchBotModel,
        layout: NotchBotLayout,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.model = model
        self.layout = layout
        self.content = content()
        self.header = header()
    }

    /// 맨 윗줄 왼쪽 자리의 안쪽 여백. 아래 카드의 바깥 여백과 맞춘다.
    private static var headerInset: CGFloat { 14 }

    private var height: CGFloat { layout.height }
    private var botWidth: CGFloat { layout.botWidth }


    public var body: some View {
        let isExpanded = model.isExpanded
        let flare = NotchBotLayout.flareRadius
        let canvas = layout.canvasSize
        let bodyRect = layout.bodyRect(isExpanded: isExpanded, contentHeight: model.contentHeight)
        let eyeRect = layout.eyeRect(isExpanded: isExpanded, contentHeight: model.contentHeight, roamProgress: model.roamProgress)
        // 몸, 작업 중 색, 눈을 따로 쌓는다. 색은 접힌 봇 자리에 고정해 두고 투명도만 바꿔서,
        // 노치가 접히는 움직임을 따라 한쪽부터 물드는 일 없이 전체가 한꺼번에 은은하게 바뀐다.
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Color.black
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { contentHeight in
                        model.contentHeight = contentHeight
                    }
                    .frame(width: layout.expandedWidth, alignment: .topLeading)
                    .offset(x: flare + (isExpanded ? 0 : layout.padding - bodyRect.minX), y: height)
                    // 펼칠 때는 노치가 거의 다 커진 뒤에 나타나고, 접을 때는 먼저 빠르게 사라진다.
                    .opacity(isExpanded ? 1 : 0)
                    .animation(isExpanded ? .easeOut(duration: 0.2).delay(0.18) : .easeIn(duration: 0.1), value: isExpanded)
                    .allowsHitTesting(isExpanded)
                // 노치 왼쪽에 남는 맨 윗줄. 카메라 노치에 가리지 않도록 노치 왼쪽 끝 전까지만 쓴다.
                header
                    .frame(width: headerWidth, height: height, alignment: .leading)
                    .offset(x: flare + (isExpanded ? 0 : layout.padding - bodyRect.minX) + Self.headerInset)
                    .opacity(isExpanded ? 1 : 0)
                    .animation(isExpanded ? .easeOut(duration: 0.2).delay(0.18) : .easeIn(duration: 0.1), value: isExpanded)
                    .allowsHitTesting(false)
            }
            .frame(width: bodyRect.width + flare * 2, height: bodyRect.height, alignment: .topLeading)
            .clipShape(NotchShape(
                cornerRadius: isExpanded ? NotchBotStyle.expandedRadius : NotchBotStyle.collapsedRadius,
                flareRadius: flare
            ))
            .offset(x: bodyRect.minX - flare)
            collapsedWorkingColor
            eyes
                .frame(width: botWidth, height: height)
                .offset(x: eyeRect.minX)
                // 펼친 동안 눈이 띠 안을 오가는 움직임은 창 컨트롤러가 값을 바꿀 때 직접 애니메이션을 건다.
                // 접으면 노치와 함께 봇 자리로 돌아간다.
            NotchBotSleepMark(isAsleep: model.expression == .asleep, height: height)
                .frame(width: NotchBotSleepMark.width, height: height, alignment: .topLeading)
                .offset(x: eyeRect.maxX + 2)
                .opacity(model.expression == .asleep && !isExpanded ? 1 : 0)
                .animation(.easeInOut(duration: 0.6), value: model.expression)
                .allowsHitTesting(false)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .animation(isExpanded ? NotchBotStyle.expandSpring : NotchBotStyle.collapseSpring, value: isExpanded)
        .animation(NotchBotStyle.collapseSpring, value: model.contentHeight)
    }

    /// 펼친 몸 왼쪽 끝에서 노치 왼쪽 끝까지, 양쪽 여백을 뺀 너비
    private var headerWidth: CGFloat {
        let expandedLeft = layout.bodyRect(isExpanded: true, contentHeight: 0).minX
        let notchLeft = layout.bodyRect(isExpanded: false, contentHeight: 0).minX
        return max(notchLeft - expandedLeft - Self.headerInset * 2, 0)
    }

    /// 접힌 봇 자리에 고정된 작업 중 색. 접힌 몸 모양으로 잘라서 오른쪽 위 오목한 곡선과 아래 둥근 모서리까지 맞춘다.
    private var collapsedWorkingColor: some View {
        let flare = NotchBotLayout.flareRadius
        let fade = NotchBotStyle.colorFadeWidth
        let collapsedBody = layout.bodyRect(isExpanded: false, contentHeight: 0)
        let collapsedBot = layout.botRect(isExpanded: false, contentHeight: 0)
        return workingColor
            .frame(width: botWidth + fade + flare, height: height)
            .offset(x: collapsedBot.minX - fade)
            .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
            .mask(alignment: .topLeading) {
                NotchShape(cornerRadius: NotchBotStyle.collapsedRadius, flareRadius: flare)
                    .frame(width: collapsedBody.width + flare * 2, height: height)
                    .offset(x: collapsedBody.minX - flare)
            }
            .allowsHitTesting(false)
    }

    /// 작업 중에는 봇 부분만 색이 천천히 바뀐다. 왼쪽으로는 검정에 스며들게 흐린다.
    /// 층을 없애고 다시 만들지 않고 투명도만 바꿔서, 시작할 때와 끝날 때 모두 같은 속도로 물들고 빠진다.
    /// 대기 중에는 색이 투명하니 시간 흐름도 멈춰 둔다.
    private var workingColor: some View {
        TimelineView(.animation(paused: !model.isWorking)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(seconds.truncatingRemainder(dividingBy: 6) / 6 * 360)
            Rectangle()
                .fill(AngularGradient(colors: NotchBotStyle.workingColors, center: .trailing, angle: angle))
                .mask(LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: NotchBotStyle.colorFadeWidth / (botWidth + NotchBotStyle.colorFadeWidth + NotchBotLayout.flareRadius))],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        }
        // 검정 몸이 살짝 비쳐서 색이 은은하게 보인다. 대기와 작업 중 사이는 1.5초에 걸쳐 천천히 물들고 빠진다.
        // 노치를 펼친 동안에는 패널 내용에 집중하도록 색을 끈다.
        // 펼칠 때는 바로 빠르게 끄고, 접을 때는 노치가 다 접힌 뒤에 작업 시작 때처럼 은은하게 다시 물들인다.
        // 접히는 도중에 켜면 색 덩어리가 허공에 떠 보여서 기다린다.
        .opacity(model.isWorking && !model.isExpanded ? 0.85 : 0)
        .animation(.easeInOut(duration: 1.5), value: model.isWorking)
        .animation(
            model.isExpanded ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.9).delay(0.5),
            value: model.isExpanded
        )
    }

    private var eyes: some View {
        let eyeWidth = height * 0.12
        let eyeHeight = height * 0.24
        let travelX = botWidth * 0.12
        let travelY = height * 0.1
        let gazeX = model.gazeX
        // 깜빡일 때 눈이 살짝 아래로 내려앉아서 눈꺼풀이 덮는 느낌을 준다.
        let blinkDip = model.expression == .blink ? eyeHeight * 0.08 : 0
        return HStack(spacing: eyeWidth * 0.9) {
            // 끝까지 옆을 보면 그쪽 바깥 눈이 조금 커진다.
            eye(width: eyeWidth, height: eyeHeight, curiosity: max(0, -gazeX))
            eye(width: eyeWidth, height: eyeHeight, curiosity: max(0, gazeX))
        }
        .rotationEffect(.degrees(-12))
        .offset(x: gazeX * travelX, y: model.gazeY * travelY + blinkDip)
        // 시선은 흘러가지 않고 짧게 탁 옮겨 간 뒤 멈춘다.
        .animation(NotchBotStyle.saccade, value: model.gazeX)
        .animation(NotchBotStyle.saccade, value: model.gazeY)
        .animation(Self.animation(for: model.expression), value: model.expression)
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: model.laughCount) { content, lift in
            content.offset(y: lift)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-2.5, duration: 0.09)
                CubicKeyframe(0, duration: 0.09)
                CubicKeyframe(-2, duration: 0.09)
                CubicKeyframe(0, duration: 0.09)
                CubicKeyframe(-1.2, duration: 0.09)
                SpringKeyframe(0, duration: 0.25)
            }
        }
    }


    /// 알약 눈. 웃을 때는 모양을 바꾸지 않고, 볼이 올라오듯 타원이 아래에서 밀고 올라와 눈 아래쪽을 도려낸다.
    private func eye(width: CGFloat, height: CGFloat, curiosity: Double) -> some View {
        let expression = model.expression
        let openness: CGFloat = switch expression {
        case .blink: 0.1
        case .asleep: 0.16
        default: 1
        }
        let cheekCover: CGFloat = expression == .smile ? 0.55 : 0
        // 졸릴 때는 위에서 눈꺼풀이 내려와 눈 위쪽 절반을 도려낸다.
        let lidCover: CGFloat = expression == .sleepy ? 0.5 : 0
        // 볼은 검은색으로 덧그리지 않고 눈에서 도려내기만 해서, 눈 밖으로는 아무것도 비치지 않는다.
        return Capsule()
            .fill(.white)
            .frame(width: width, height: height)
            .mask {
                ZStack(alignment: .top) {
                    Rectangle()
                    Rectangle()
                        // 눈 위로 조금 넘치게 덮어서 눈꺼풀 가장자리에 흰 잔상이 남지 않게 한다.
                        .frame(height: height * lidCover + 2)
                        .offset(y: -2)
                        .blendMode(.destinationOut)
                    Ellipse()
                        .frame(width: width * 1.5, height: height * 0.9)
                        .offset(y: cheekCover > 0 ? height * (1 - cheekCover) : height * 1.4)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .scaleEffect(x: 1, y: openness * (1 + 0.22 * curiosity), anchor: .center)
            .animation(NotchBotStyle.saccade, value: curiosity)
    }

    /// 감을 때는 빠르게, 뜰 때는 조금 더 천천히, 웃을 때는 볼이 살짝 튕기며 올라온다.
    private static func animation(for expression: NotchBotExpression) -> Animation {
        switch expression {
        case .blink: .easeIn(duration: 0.06)
        case .open: .easeOut(duration: 0.12)
        case .smile: .spring(response: 0.3, dampingFraction: 0.7)
        case .sleepy, .asleep: .easeInOut(duration: 0.6)
        }
    }
}

/// 잠든 봇 옆으로 작은 "z" 두 개가 번갈아 비스듬히 떠오르며 사라진다. 잠들지 않은 동안에는 시간 흐름을 멈춰 둔다.
private struct NotchBotSleepMark: View {
    static let width: CGFloat = 14
    private static let cycle: TimeInterval = 2.4

    let isAsleep: Bool
    let height: CGFloat

    var body: some View {
        TimelineView(.animation(paused: !isAsleep)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                letter(progress: (seconds / Self.cycle).truncatingRemainder(dividingBy: 1))
                letter(progress: (seconds / Self.cycle + 0.5).truncatingRemainder(dividingBy: 1))
            }
        }
    }

    private func letter(progress: Double) -> some View {
        Text("z")
            .font(.system(size: height * (0.22 + 0.08 * progress), weight: .bold, design: .rounded))
            .foregroundStyle(Color(white: 0.6))
            .offset(x: Self.width * 0.6 * progress, y: height * (0.45 - 0.35 * progress))
            .opacity(sin(.pi * progress))
    }
}

/// 노치 봇 뷰의 고정 값. 제네릭 뷰에는 정적 저장 속성을 둘 수 없어서 따로 둔다.
private enum NotchBotStyle {
    static let collapsedRadius: CGFloat = 12
    static let expandedRadius: CGFloat = 22
    /// 작업 중 봇 몸 색. 하늘빛 파랑에서 남색, 보라, 자줏빛 보라까지 블루 퍼플 계열 안에서 폭넓게 오간다.
    /// 85% 투명도로 검정 위에 얹혀서 흰 눈은 계속 잘 보인다.
    static let workingColors: [Color] = [
        Color(red: 0.16, green: 0.56, blue: 0.96),
        Color(red: 0.22, green: 0.36, blue: 0.96),
        Color(red: 0.38, green: 0.27, blue: 0.88),
        Color(red: 0.58, green: 0.30, blue: 0.94),
        Color(red: 0.74, green: 0.30, blue: 0.86),
        Color(red: 0.42, green: 0.44, blue: 0.98),
        Color(red: 0.16, green: 0.56, blue: 0.96)
    ]
    /// 봇 색이 왼쪽 검정으로 스며드는 폭
    static let colorFadeWidth: CGFloat = 14
    /// 노치가 커지고 줄어드는 움직임. 튕기면 가장자리가 목표를 넘었다가 돌아와서 물결치듯 보여서, 펼칠 때와 접을 때 모두 튕기지 않는다.
    static let expandSpring = Animation.spring(response: 0.45, dampingFraction: 1)
    static let collapseSpring = Animation.spring(response: 0.45, dampingFraction: 1)
    // 마우스를 느긋하게 따라가도록 0.6초 남짓에 걸쳐 튕김 없이 옮겨 간다.
    static let saccade = Animation.spring(response: 0.6, dampingFraction: 1)
}

/// 노치 모양. 위쪽 양끝은 바깥으로 오목하게 퍼지며 화면 가장자리에 붙고, 아래쪽 양끝은 둥글다.
private struct NotchShape: Shape {
    var cornerRadius: CGFloat
    let flareRadius: CGFloat

    /// 접힐 때와 펼칠 때 아래 모서리 둥글기가 부드럽게 바뀐다.
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let flare = flareRadius
        let radius = min(cornerRadius, rect.height / 2)
        let left = rect.minX + flare
        let right = rect.maxX - flare
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.minY + flare), control: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: left + radius, y: rect.maxY), control: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: right - radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: right, y: rect.maxY - radius), control: CGPoint(x: right, y: rect.maxY))
        path.addLine(to: CGPoint(x: right, y: rect.minY + flare))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
