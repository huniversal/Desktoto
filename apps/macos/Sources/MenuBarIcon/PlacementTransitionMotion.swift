import CoreGraphics

/// 노치 봇과 메뉴바 토토 사이를 물방울처럼 오가는 전환의 움직임. AppKit 없이 값만 계산해서 테스트할 수 있다.
/// 좌표는 전환 창 왼쪽 위가 원점이고 아래로 갈수록 y가 커진다. 랜딩 페이지 데모(apps/web/index.html)의 움직임을 옮겼다.
public struct PlacementTransitionMotion: Sendable {
    public enum Direction: Sendable {
        /// 노치에서 떨어져 메뉴바 토토 자리에 앉는다.
        case toMenuBar
        /// 메뉴바 토토 자리에서 튀어 올라 노치에 빨려 붙는다.
        case toNotch
    }

    /// 한 순간의 물방울 모습
    public struct Frame: Equatable, Sendable {
        /// 물방울 가운데
        public var center: CGPoint
        /// 찌그러지기 전 지름
        public var size: CGFloat
        /// 가로, 세로로 늘어난 비율
        public var scaleX: CGFloat
        public var scaleY: CGFloat
        /// 노치 오른쪽에 붙은 봇 몸이 노치 밖으로 나와 있는 폭. 봇 폭이면 다 붙었고 0이면 다 떨어졌다.
        public var attachedWidth: CGFloat
    }

    public let direction: Direction
    /// 봇 자리 가운데와 토토 자리 가운데
    public let start: CGPoint
    public let end: CGPoint
    /// 봇 자리에서의 물방울 지름과 토토 지름
    public let startSize: CGFloat
    public let endSize: CGFloat
    /// 노치 밖으로 나와 있는 봇 폭
    public let botWidth: CGFloat
    /// 재생 시간(초)
    public let duration: Double

    public init(direction: Direction, start: CGPoint, end: CGPoint, startSize: CGFloat, endSize: CGFloat, botWidth: CGFloat, duration: Double) {
        self.direction = direction
        self.start = start
        self.end = end
        self.startSize = startSize
        self.endSize = endSize
        self.botWidth = botWidth
        self.duration = duration
    }

    /// 재생 중 elapsed초 지점의 모습. 범위 밖은 처음이나 끝 모습이다.
    public func frame(at elapsed: Double) -> Frame {
        let progress = min(max(elapsed / duration, 0), 1)
        var frame = switch direction {
        case .toMenuBar: detachFrame(progress)
        case .toNotch: attachFrame(progress)
        }
        // 노치 밖 봇 몸은 물방울이 봇 자리에서 오른쪽으로 벗어난 만큼 줄어든다(돌아올 때는 들어온 만큼 는다).
        frame.attachedWidth = min(max(botWidth - (frame.center.x - start.x), 0), botWidth)
        return frame
    }

    // MARK: - 떨어지기

    /// 구간 비율. 웅크리기, 끙끙 버티기(두 번 당김), 튀어 가며 자리 잡기다.
    private static let crouchEnd = 0.08
    private static let tugEnd = 0.6
    private static let tugCount = 2
    /// 버티는 구간 중 당겼다 놓기를 반복하는 비율. 나머지는 마지막 당김이다.
    private static let tugShare = 0.84
    /// 마지막 당김으로 튕겨 나가는 거리
    private static let yank: CGFloat = 30
    /// 튀어 가는 구간 중 바닥에 닿기 전까지의 비율. 그 뒤는 미끄러지며 출렁인다.
    private static let landShare = 0.78

    private func detachFrame(_ progress: Double) -> Frame {
        if progress < Self.crouchEnd {
            // 나가기 전에 제자리에서 살짝 웅크린다.
            let crouch = CGFloat(sin(progress / Self.crouchEnd * .pi))
            return Frame(center: start, size: startSize, scaleX: 1 - 0.06 * crouch, scaleY: 1 + 0.06 * crouch, attachedWidth: 0)
        }
        if progress < Self.tugEnd {
            return tugFrame((progress - Self.crouchEnd) / (Self.tugEnd - Self.crouchEnd))
        }
        return hopAndSettleFrame((progress - Self.tugEnd) / (1 - Self.tugEnd))
    }

    /// 젤리처럼 끙끙대며 당긴다. 갈수록 세게 당기고, 가장 늘어났을 때 부르르 떨고, 놓치면 튕겨 돌아오며 위아래로 불룩해진다.
    /// 왼쪽 끝은 노치에 붙인 채 몸만 오른쪽으로 늘어나고(최대 1.7배), 마지막에 쭉 당겨지며 목이 끊긴다.
    private func tugFrame(_ phase: Double) -> Frame {
        if phase < Self.tugShare {
            let local = phase / Self.tugShare * Double(Self.tugCount)
            let tug = min(Int(local), Self.tugCount - 1)
            let within = local - Double(tug)
            let strength = 0.45 + 0.55 * Double(tug) / Double(max(Self.tugCount - 1, 1))
            let shape = within < 0.6 ? smoothStep(within / 0.6) : 1 - 0.85 * easeOut((within - 0.6) / 0.4)
            let quiver = (within > 0.35 && within < 0.7) ? 0.05 * strength * sin(within * .pi * 40) : 0
            let recoil = within > 0.6 ? 0.12 * strength * sin((within - 0.6) / 0.4 * .pi) : 0
            let stretch = 0.06 + 0.64 * strength * shape
            let scaleX = CGFloat(1 + stretch + quiver - recoil)
            let scaleY = CGFloat(1 - stretch * 0.42 - quiver + recoil)
            // 노치 안에서 작게 시작한 물방울이 끙끙대는 동안 조금씩 부풀며 밖으로 맺혀 나온다.
            let size = lerp(startSize * 0.72, startSize, CGFloat(smoothStep(phase / Self.tugShare)))
            let x = start.x + size * (scaleX - 1) / 2 + CGFloat(3 * strength * shape) + (startSize - size) * 0.5
            let y = start.y + CGFloat(1.5 * sin(local * .pi * 2) * strength)
            return Frame(center: CGPoint(x: x, y: y), size: size, scaleX: scaleX, scaleY: scaleY, attachedWidth: 0)
        }
        // 마지막 당김. 목이 가늘어지며 눈물방울처럼 길쭉해졌다가 똑 끊긴다.
        let yankProgress = easeOut((phase - Self.tugShare) / (1 - Self.tugShare))
        let snap = CGFloat(0.65 * sin(yankProgress * .pi) * (1 - yankProgress * 0.3))
        let fromX = start.x + startSize * 0.07
        let x = lerp(fromX, start.x + Self.yank, CGFloat(yankProgress))
        return Frame(center: CGPoint(x: x, y: start.y), size: startSize, scaleX: 1 + snap, scaleY: 1 - snap * 0.45, attachedWidth: 0)
    }

    /// 튀어 가기와 자리 잡기를 한 감속 곡선으로 잇는다. 세 번 튀고, 바닥에 닿은 뒤 미끄러지며 출렁이다 토토 자리에 멈춘다.
    private func hopAndSettleFrame(_ phase: Double) -> Frame {
        let travel = 1 - pow(1 - phase, 2.4)
        let fromX = start.x + Self.yank
        let x = lerp(fromX, end.x, CGFloat(travel))
        let baseY = lerp(start.y, end.y, CGFloat(travel))
        let size = lerp(startSize * 0.92, endSize, CGFloat(smoothStep(travel)))
        if travel < Self.landShare {
            let hop = hop(travel / Self.landShare)
            // 끊긴 반동으로 몸이 가로세로로 몇 번 출렁이다 둥글게 자리 잡는다.
            let ring = CGFloat(0.22 * exp(-7 * phase) * sin(phase * .pi * 9))
            return Frame(center: CGPoint(x: x, y: baseY - hop.lift), size: size, scaleX: hop.scaleX - ring, scaleY: hop.scaleY + ring, attachedWidth: 0)
        }
        let landPhase = 1 - pow(1 - Self.landShare, 1 / 2.4)
        let settle = (phase - landPhase) / (1 - landPhase)
        let wobble = CGFloat(0.18 * exp(-4 * settle) * cos(settle * .pi * 4))
        return Frame(center: CGPoint(x: x, y: baseY), size: size, scaleX: 1 + wobble, scaleY: 1 - wobble, attachedWidth: 0)
    }

    // MARK: - 붙기

    /// 구간 비율. 웅크리기, 튀어 오기, 노치 옆에서 천천히 밀고 들어오기다.
    private static let attachCrouchEnd = 0.1
    private static let attachHopEnd = 0.41
    /// 튀어 와서 멈추는 노치 옆 자리(봇 자리 가운데에서 오른쪽으로)
    private static let nearOffset: CGFloat = 40

    private func attachFrame(_ progress: Double) -> Frame {
        let near = CGPoint(x: start.x + Self.nearOffset, y: start.y)
        if progress < Self.attachCrouchEnd {
            let crouch = CGFloat(sin(progress / Self.attachCrouchEnd * .pi))
            return Frame(center: end, size: endSize, scaleX: 1 + 0.2 * crouch, scaleY: 1 - 0.22 * crouch, attachedWidth: 0)
        }
        if progress < Self.attachHopEnd {
            let phase = (progress - Self.attachCrouchEnd) / (Self.attachHopEnd - Self.attachCrouchEnd)
            let hop = hop(phase)
            let x = lerp(end.x, near.x, CGFloat(phase))
            let y = lerp(end.y, near.y, CGFloat(phase)) - hop.lift
            let size = lerp(endSize, startSize * 0.9, CGFloat(phase))
            return Frame(center: CGPoint(x: x, y: y), size: size, scaleX: hop.scaleX, scaleY: hop.scaleY, attachedWidth: 0)
        }
        return absorbFrame((progress - Self.attachHopEnd) / (1 - Self.attachHopEnd), near: near)
    }

    /// 물방울이 노치에 흡수된다. 천천히 다가가며 노치 쪽으로 끌려 길어지고, 닿으면 점점 빨라지며 쭉 빨려 들어가
    /// 작아지며 사라지고, 노치 봇 자리가 한두 번 물결치듯 출렁이다 멈춘다.
    private func absorbFrame(_ phase: Double, near: CGPoint) -> Frame {
        let approachEnd = 0.5
        let swallowEnd = 0.8
        // 노치 몸에 막 닿는 자리. 물방울 왼쪽 끝이 봇 자리 오른쪽 끝에 닿는다.
        let touchX = start.x + botWidth / 2 + startSize * 0.3
        if phase < approachEnd {
            let approach = smoothStep(phase / approachEnd)
            let pull = CGFloat(0.18 * approach)
            let x = lerp(near.x, touchX, CGFloat(approach)) - startSize * pull / 2
            return Frame(center: CGPoint(x: x, y: start.y), size: startSize * 0.9, scaleX: 1 + pull, scaleY: 1 - pull * 0.5, attachedWidth: 0)
        }
        if phase < swallowEnd {
            // 점점 빨라지며 빨려 들어간다. 노치 쪽으로 길쭉해졌다가 줄어들며 작아진다.
            let swallow = pow((phase - approachEnd) / (swallowEnd - approachEnd), 2)
            let x = lerp(touchX - startSize * 0.09, start.x, CGFloat(swallow))
            let stretch = CGFloat(0.18 + 0.2 * sin(swallow * .pi))
            let size = lerp(startSize * 0.9, startSize * 0.7, CGFloat(swallow))
            return Frame(center: CGPoint(x: x, y: start.y), size: size, scaleX: 1 + stretch, scaleY: 1 - stretch * 0.5, attachedWidth: 0)
        }
        // 다 빨려 들어간 뒤 봇 자리가 물결치듯 출렁이다 멈춘다. 끝에서는 정확히 봇 자리에 멈춰 노치 봇과 이어진다.
        let ripple = (phase - swallowEnd) / (1 - swallowEnd)
        let wobble = CGFloat(0.14 * exp(-4.5 * ripple) * cos(ripple * .pi * 3)) * (phase >= 1 ? 0 : 1)
        let size = lerp(startSize * 0.7, startSize, CGFloat(smoothStep(ripple)))
        return Frame(center: start, size: size, scaleX: 1 + wobble, scaleY: 1 - wobble, attachedWidth: 0)
    }

    // MARK: - 공통

    /// 통통 세 번 튀는 높이와 찌그러짐. 닿을 때마다 납작해지고 튈수록 낮아진다. 메뉴바 밖으로 나가지 않도록 위로 낮게 튄다.
    private func hop(_ phase: Double) -> (lift: CGFloat, scaleX: CGFloat, scaleY: CGFloat) {
        let hops = 3
        let local = phase * Double(hops)
        let index = min(Int(local), hops - 1)
        let within = local - Double(index)
        let height = 9 * (1 - Double(index) * 0.3)
        let contact = max(0, 1 - min(within, 1 - within) / 0.14)
        return (
            CGFloat(height * 4 * within * (1 - within)),
            CGFloat(1 + 0.22 * contact - 0.04 * (1 - contact)),
            CGFloat(1 - 0.2 * contact + 0.05 * (1 - contact))
        )
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private func smoothStep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func easeOut(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }
}
