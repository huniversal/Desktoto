import AppKit
import DesignSystem
import MenuBarIcon

/// 아이콘에 반영할 상태. 판정은 앱이 하고, 이 컨트롤러는 이 값에 맞춰 이미지와 타이머만 다룬다.
struct IconState: Equatable {
    var runningCount = 0
    var isWaiting = false
    var isSleeping = false
    var hasUnseenDone = false
    var colorMode: ColorMode = .white
}

/// 메뉴바 아이콘의 이미지와 애니메이션 타이머를 소유한다.
@MainActor
final class MenuBarIconController {
    private let button: NSStatusBarButton?
    private let images: IconImageSet
    private var animation = IconAnimation()
    private var state: IconState
    private var animationTimer: Timer?
    private var sleepTimer: Timer?
    private var gazePosition = GazePosition.center
    private var gazeDirection = GazeDirection.center
    private var gazeTarget = GazeDirection.center
    private var gazeTimer: Timer?
    private var behavior = MenuBarIconController.createBehavior()
    private var behaviorTimer: Timer?
    private var displayedExpression = EyeExpression.open
    private var lastMousePoint: NSPoint?
    private var lastMouseTime: TimeInterval = 0
    private var mouseSpeed: Double = 0
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    init(button: NSStatusBarButton?, colorMode: ColorMode) {
        self.button = button
        state = IconState(colorMode: colorMode)
        images = IconImageSet(
            appearance: IconAppearance(colorMode: colorMode),
            scale: NSScreen.main?.backingScaleFactor ?? 2
        )
        button?.image = images.image(for: .standing)
    }

    var hasFirework: Bool {
        animation.hasFirework
    }

    func startFirework() {
        animation.startFirework()
    }

    /// 확인하지 않은 완료나 승인 대기 여부가 바뀌면 이미지를 다시 만들고, 상태에 맞게 애니메이션을 켜고 끈다.
    func apply(_ newState: IconState) {
        state = newState
        images.update(appearance: IconAppearance(
            colorMode: state.colorMode,
            hasUnseenDone: state.hasUnseenDone,
            isWaiting: state.isWaiting
        ))
        switch IconSchedule(isRunning: state.runningCount > 0, hasFirework: animation.hasFirework, isSleeping: state.isSleeping) {
        case .running:
            stopSleepAnimation()
            stopGazing()
            if animationTimer == nil { startAnimation() }
        case .sleeping:
            if animationTimer != nil { stopAnimation() }
            stopGazing()
            startSleepAnimation()
        case .still:
            if animationTimer != nil { stopAnimation() }
            stopSleepAnimation()
            startGazing()
            showGaze()
        }
    }

    private static func createBehavior() -> IdleBehavior {
        IdleBehavior(now: ProcessInfo.processInfo.systemUptime, blinkDelay: Double.random(in: IdleBehavior.blinkDelayRange))
    }

    // 하품은 정면을 보고, 나머지 표정은 지금 보는 방향을 유지한다.
    private func showGaze() {
        if case .yawn = displayedExpression {
            button?.image = images.image(for: .expression(displayedExpression, .center))
        } else {
            button?.image = images.image(for: .expression(displayedExpression, gazeDirection))
        }
    }

    // 대기 중일 때만 마우스를 따라 본다. 방향이 바뀔 때만 이미지를 바꿔 메뉴바 갱신을 최소로 한다.
    private func startGazing() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateGaze() }
        }
        behavior = Self.createBehavior()
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.behaviorInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickBehavior() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated { self?.updateGaze() }
            return event
        }
    }

    private func stopGazing() {
        gazeTimer?.invalidate()
        gazeTimer = nil
        behaviorTimer?.invalidate()
        behaviorTimer = nil
        displayedExpression = .open
        lastMousePoint = nil
        mouseSpeed = 0
        gazeTarget = .center
        gazePosition = .center
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        gazeDirection = .center
    }

    // 마우스는 목표만 정한다. 실제 시선은 타이머가 한 단계씩 따라가고, 목표에 닿으면 타이머가 멈춘다.
    private func updateGaze() {
        guard let frame = button?.window?.frame else { return }
        let mouse = NSEvent.mouseLocation
        trackMouseSpeed(at: mouse)
        gazeTarget = GazeDirection.make(offsetX: mouse.x - frame.midX, offsetY: mouse.y - frame.midY)
        guard gazeTimer == nil, !gazePosition.hasReached(gazeTarget) else { return }
        gazeTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.gazeFrameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickGaze() }
        }
    }

    // 마우스 속도(pt/초)를 이동 평균으로 구한다. 오래 멈췄다가 움직이면 그 간격은 속도로 보지 않는다.
    private func trackMouseSpeed(at point: NSPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        defer {
            lastMousePoint = point
            lastMouseTime = now
        }
        guard let lastMousePoint, now - lastMouseTime < 0.2, now > lastMouseTime else {
            mouseSpeed = 0
            behavior.mouseMoved(speed: 0, now: now)
            return
        }
        let instant = hypot(point.x - lastMousePoint.x, point.y - lastMousePoint.y) / (now - lastMouseTime)
        mouseSpeed = mouseSpeed * 0.5 + instant * 0.5
        behavior.mouseMoved(speed: mouseSpeed, now: now)
    }

    private func tickBehavior() {
        let expression = behavior.tick(
            now: ProcessInfo.processInfo.systemUptime,
            nextBlinkDelay: Double.random(in: IdleBehavior.blinkDelayRange)
        )
        guard expression != displayedExpression else { return }
        displayedExpression = expression
        showGaze()
    }

    private func tickGaze() {
        gazePosition = gazePosition.eased(toward: gazeTarget)
        let direction = gazePosition.direction
        if direction != gazeDirection {
            gazeDirection = direction
            showGaze()
        }
        if gazePosition.hasReached(gazeTarget) {
            gazeTimer?.invalidate()
            gazeTimer = nil
        }
    }

    // 잠든 동안에는 z가 천천히 떠오르도록 느린 타이머만 돌린다. 깨면 stopSleepAnimation이 서 있는 모습으로 되돌린다.
    private func startSleepAnimation() {
        guard sleepTimer == nil else { return }
        button?.image = images.image(for: animation.currentSleepingFrame)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.sleepFrameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickSleeping() }
        }
    }

    private func tickSleeping() {
        button?.image = images.image(for: animation.tickSleeping())
    }

    private func stopSleepAnimation() {
        guard sleepTimer != nil else { return }
        sleepTimer?.invalidate()
        sleepTimer = nil
        animation.resetSleeping()
        button?.image = images.image(for: .standing)
    }

    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.runningFrameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickRunning() }
        }
    }

    // 폭죽은 캐릭터 뒤에 합성한다. 끝까지 재생되고 달리는 세션도 없으면 타이머를 멈춘다.
    private func tickRunning() {
        let tick = animation.tickRunning(isRunning: state.runningCount > 0)
        if let fireworkFrame = tick.fireworkFrame {
            button?.image = images.fireworkImage(over: tick.frame, fireworkFrame: fireworkFrame)
        } else {
            button?.image = images.image(for: tick.frame)
        }
        if tick.shouldStop { stopAnimation() }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        button?.image = images.image(for: .standing)
    }
}
