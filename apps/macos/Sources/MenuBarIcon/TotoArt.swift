import AppKit
import DesignSystem

/// 토토의 모습. 검은 원 안에 노치 봇과 같은 알약 눈 두 개가 있다.
/// 원은 캔버스 가운데에 고정하고, 상태는 눈 모양과 몸 색으로만 보여 준다.
struct TotoPose: Equatable, Sendable {
    var expression: EyeExpression = .open
    var direction: GazeDirection = .center
    /// 작업 중이면 몸 색이 도는 단계(IconTiming.totoColorStepCount 단계 중 하나), 아니면 nil이다.
    var colorPhase: Int?
    /// 몸 색이 물든 정도(0...1)
    var colorStrength: CGFloat = 1
    /// 잠, 낚시, 쉬는 장면 대신 눈을 가는 선으로 감고 있다.
    var isAsleep = false

    init(frame: IconFrame) {
        switch frame {
        case .standing, .idle: break
        case .gazing(let direction): self.direction = direction
        case .expression(let expression, let direction):
            self.expression = expression
            self.direction = direction
        // 달리기 단계(24)를 몸 색 단계(48)로 옮긴다.
        case .running(let phase): colorPhase = phase * IconTiming.totoColorStepCount / IconTiming.runningFrameCount
        case .working(let phase, let fade, let expression, let direction):
            colorPhase = phase
            colorStrength = CGFloat(min(max(fade, 0), IconTiming.totoFadeStepCount)) / CGFloat(IconTiming.totoFadeStepCount)
            self.expression = expression
            self.direction = direction
        case .sleeping, .fishing, .rest: isAsleep = true
        }
    }
}

/// 토토를 칸 단위 좌표로 그린다. 그리기 좌표는 위쪽이 0인 뒤집힌 좌표다.
@MainActor
enum TotoArt {
    /// 원 지름(칸). 캔버스 높이 20칸에서 위아래 1칸씩 남긴다.
    private static let diameter: CGFloat = 18
    private static let centerX = CharacterGrid.standingOriginX + CharacterGrid.characterWidth / 2
    private static let centerY = CharacterGrid.canvasHeight / 2
    private static let eyeWidth: CGFloat = 2.2
    private static let eyeHeight: CGFloat = 5
    /// 두 눈 중심 사이 거리
    private static let eyeDistance: CGFloat = 4.2
    /// 노치 봇처럼 눈을 살짝 기울인다.
    private static let eyeTilt: CGFloat = -12
    /// 끝까지 옆이나 위아래를 볼 때 눈이 움직이는 거리(칸)
    private static let gazeTravelX: CGFloat = 2.4
    private static let gazeTravelY: CGFloat = 1.6
    /// 어두운 메뉴바에서 원이 배경에 묻히지 않도록 두르는 아주 옅은 테두리
    private static let rimColor = NSColor(white: 1, alpha: 0.22)
    /// 작업 중 몸 색. 노치 봇과 같은 블루 퍼플 계열이고, 검정 위에 85%로 얹는다.
    private static let workingColors: [NSColor] = [
        NSColor(srgbRed: 0.16, green: 0.56, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.22, green: 0.36, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.38, green: 0.27, blue: 0.88, alpha: 1),
        NSColor(srgbRed: 0.58, green: 0.30, blue: 0.94, alpha: 1),
        NSColor(srgbRed: 0.74, green: 0.30, blue: 0.86, alpha: 1),
        NSColor(srgbRed: 0.42, green: 0.44, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.16, green: 0.56, blue: 0.96, alpha: 1)
    ]
    private static let workingOpacity: CGFloat = 0.85
    /// 승인 대기 중 몸 색. 주황에서 노랑 사이를 오간다.
    private static let waitingColors: [NSColor] = [
        NSColor(srgbRed: 1.00, green: 0.55, blue: 0.15, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.68, blue: 0.20, alpha: 1),
        NSColor(srgbRed: 0.98, green: 0.80, blue: 0.28, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.62, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.96, green: 0.48, blue: 0.14, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.74, blue: 0.24, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.55, blue: 0.15, alpha: 1)
    ]

    /// isWaiting이면 몸 색이 승인 대기 색(주황과 노랑)으로 돈다.
    static func draw(frame: IconFrame, isWaiting: Bool, unit: CGFloat) {
        let pose = TotoPose(frame: frame)
        // 어지러울 때는 몸이 좌우로 살짝 흔들린다.
        var shakeX: CGFloat = 0
        if case .dizzy(let phase) = pose.expression { shakeX = phase.isMultiple(of: 2) ? -0.6 : 0.6 }
        let center = CGPoint(x: (centerX + shakeX) * unit, y: centerY * unit)
        let radius = diameter / 2 * unit
        let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

        NSColor.black.setFill()
        circle.fill()
        if let phase = pose.colorPhase, pose.colorStrength > 0 {
            drawWorkingColor(in: circle, center: center, radius: radius, phase: phase, strength: pose.colorStrength, colors: isWaiting ? waitingColors : workingColors)
        }
        rimColor.setStroke()
        circle.lineWidth = 0.35 * unit
        circle.stroke()

        drawEyes(pose: pose, center: center, unit: unit)
    }

    /// 노치 봇과 같은 각도 그라데이션. 원 오른쪽 바깥을 중심으로 색이 부채꼴로 퍼지고, 단계마다 그 각도가 조금씩 돌아간다.
    /// AppKit에는 각도 그라데이션이 없어서 가는 부채꼴을 촘촘히 이어 칠한다. 원이 작아서 이음매는 보이지 않는다.
    private static func drawWorkingColor(in circle: NSBezierPath, center: CGPoint, radius: CGFloat, phase: Int, strength: CGFloat, colors: [NSColor]) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let turn = CGFloat(wrapFrameIndex(phase, count: IconTiming.totoColorStepCount)) / CGFloat(IconTiming.totoColorStepCount)
        // 중심점이 원 안에 있으면 색이 한 점으로 모이는 자국이 보여서 원 밖 오른쪽에 둔다.
        let pivot = CGPoint(x: center.x + radius * 1.6, y: center.y)
        let reach = radius * 4
        let sliceAngle = 2 * CGFloat.pi / CGFloat(colorSliceCount)
        context.saveGState()
        circle.addClip()
        // 부채꼴은 서로 겹쳐서 불투명하게 칠하고, 다 칠한 뒤 한꺼번에 투명도를 준다.
        // 부채꼴마다 투명도를 주면 겹친 곳과 이음매가 줄무늬로 비친다.
        context.setAlpha(workingOpacity * strength)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setAlpha(1)
        (0..<colorSliceCount).forEach { slice in
            let start = CGFloat(slice) * sliceAngle
            let slicePath = NSBezierPath()
            slicePath.move(to: pivot)
            // 이웃 부채꼴과 살짝 겹쳐서 틈이 생기지 않게 한다.
            slicePath.appendArc(withCenter: pivot, radius: reach, startAngle: start * 180 / .pi, endAngle: (start + sliceAngle * 1.5) * 180 / .pi)
            slicePath.close()
            color(at: CGFloat(slice) / CGFloat(colorSliceCount) + turn, in: colors).setFill()
            slicePath.fill()
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static let colorSliceCount = 96

    /// 0...1 위치(한 바퀴)에 해당하는 색. 색 목록 사이를 부드럽게 섞는다.
    private static func color(at position: CGFloat, in colors: [NSColor]) -> NSColor {
        let wrapped = position - floor(position)
        let scaled = wrapped * CGFloat(colors.count - 1)
        let lower = min(Int(scaled), colors.count - 2)
        let fraction = scaled - CGFloat(lower)
        return colors[lower].blended(withFraction: fraction, of: colors[lower + 1]) ?? colors[lower]
    }

    private static func drawEyes(pose: TotoPose, center: CGPoint, unit: CGFloat) {
        var gazeX: CGFloat = 0
        var gazeY: CGFloat = 0
        var widthScale: CGFloat = 1
        var heightScale: CGFloat = 1
        /// 눈 위쪽을 눈꺼풀로 덮는 비율
        var lidCover: CGFloat = 0
        /// 어지러울 때 두 눈 높이를 엇갈리게 하는 양(칸)
        var dizzyOffset: CGFloat = 0

        if pose.isAsleep {
            widthScale = 1.3
            heightScale = 0.18
            gazeY = 0.8
        } else {
            gazeX = CGFloat(pose.direction.horizontal) / CGFloat(GazeDirection.maxHorizontal) * gazeTravelX
            gazeY = CGFloat(pose.direction.vertical) / CGFloat(GazeDirection.maxVertical) * gazeTravelY
            switch pose.expression {
            case .open: break
            case .blink: heightScale = 0.15
            case .wide:
                widthScale = 1.15
                heightScale = 1.2
            case .dizzy(let phase): dizzyOffset = phase.isMultiple(of: 2) ? 0.8 : -0.8
            // 오래 가만히 두면 하품 대신 졸린 눈을 한다.
            case .yawn:
                lidCover = 0.5
                gazeX = 0
                gazeY = 0.6
            }
        }

        let width = eyeWidth * widthScale * unit
        let height = eyeHeight * heightScale * unit
        let fullHeight = eyeHeight * unit
        NSColor.white.setFill()
        [(-1.0, -dizzyOffset), (1.0, dizzyOffset)].forEach { side, offsetY in
            let eyeCenter = CGPoint(
                x: center.x + (side * eyeDistance / 2 + gazeX) * unit,
                y: center.y + (gazeY + offsetY) * unit
            )
            let transform = NSAffineTransform()
            transform.translateX(by: eyeCenter.x, yBy: eyeCenter.y)
            transform.rotate(byDegrees: eyeTilt)
            NSGraphicsContext.current?.saveGraphicsState()
            transform.concat()
            if lidCover > 0 {
                // 눈꺼풀이 내려온 만큼 위쪽을 잘라 낸다(위쪽이 0인 좌표라 위가 작은 y다).
                NSBezierPath(rect: NSRect(x: -width, y: -fullHeight / 2 + fullHeight * lidCover, width: width * 2, height: fullHeight)).addClip()
            }
            NSBezierPath(
                roundedRect: NSRect(x: -width / 2, y: -height / 2, width: width, height: height),
                xRadius: width / 2,
                yRadius: min(width, height) / 2
            ).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }
}
