import AppKit
import DesignSystem
import MenuBarIcon

/// 아이콘에 반영할 상태. 판정은 앱이 하고, 이 컨트롤러는 이 값에 맞춰 이미지와 타이머만 다룬다.
struct IconState: Equatable {
    var runningCount = 0
    var isWaiting = false
    /// 쉬는 중이면 무엇을 하는지. 2분 동안 캐릭터를 누르지 않으면 정해진다.
    var rest: IconRest?
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
    private var fishing = FishingSession()
    private var fishingTimer: Timer?
    private var lastFishingTick: TimeInterval = 0
    private var shownFishingFrame: FishingFrame?
    /// 스파클라, 음악 같은 정해진 장면의 쉬는 일
    private var restTimer: Timer?
    private var restActivity: IconRest?
    private var restStartedAt: TimeInterval = 0
    private var shownRestFrame: RestFrame?
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
        switch IconSchedule(isRunning: state.runningCount > 0, hasFirework: animation.hasFirework, rest: state.rest) {
        case .running:
            stopSleepAnimation()
            stopFishingAnimation()
            stopRestAnimation()
            stopGazing()
            if animationTimer == nil { startAnimation() }
        case .sleeping:
            if animationTimer != nil { stopAnimation() }
            stopFishingAnimation()
            stopRestAnimation()
            stopGazing()
            startSleepAnimation()
        case .fishing:
            if animationTimer != nil { stopAnimation() }
            stopSleepAnimation()
            stopRestAnimation()
            stopGazing()
            startFishingAnimation()
        case .resting:
            if animationTimer != nil { stopAnimation() }
            stopSleepAnimation()
            stopFishingAnimation()
            stopGazing()
            if let activity = state.rest { startRestAnimation(activity) }
        case .still:
            if animationTimer != nil { stopAnimation() }
            stopSleepAnimation()
            stopFishingAnimation()
            stopRestAnimation()
            startGazing()
            showGaze()
        }
    }

    /// 눌러서 끄는 동안에는 mouseMoved가 오지 않으므로 드래그도 같은 움직임으로 본다.
    private static let pointerMovementEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]

    private static func createBehavior() -> IdleBehavior {
        IdleBehavior(now: ProcessInfo.processInfo.systemUptime, blinkDelay: Double.random(in: IdleBehavior.blinkDelayRange))
    }

    // 하품은 정면을 보고, 나머지 표정은 지금 보는 방향을 유지한다.
    private func showGaze() {
        let image: NSImage
        if case .yawn = displayedExpression {
            image = images.image(for: .expression(displayedExpression, .center))
        } else {
            image = images.image(for: .expression(displayedExpression, gazeDirection))
        }
        // 이미 같은 이미지가 보이면 다시 넣지 않는다. 이미지를 바꿀 때마다 시스템이 메뉴바 스냅샷을 다시 만든다.
        if button?.image !== image { button?.image = image }
    }

    // 대기 중일 때만 마우스를 따라 본다. 방향이 바뀔 때만 이미지를 바꿔 메뉴바 갱신을 최소로 한다.
    private func startGazing() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.pointerMovementEvents) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateGaze() }
        }
        behavior = Self.createBehavior()
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.behaviorInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickBehavior() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.pointerMovementEvents) { [weak self] event in
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

    // 낚시는 규칙이 시간에 따라 모습을 정하고, 모습이 바뀔 때만 메뉴바 이미지를 바꾼다. 깨면 서 있는 모습으로 되돌린다.
    private func startFishingAnimation() {
        guard fishingTimer == nil else { return }
        fishing = FishingSession()
        lastFishingTick = ProcessInfo.processInfo.systemUptime
        shownFishingFrame = nil
        showFishingFrame()
        fishingTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.fishingTickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickFishing() }
        }
    }

    private func tickFishing() {
        let now = ProcessInfo.processInfo.systemUptime
        fishing.update(deltaTime: now - lastFishingTick, random: { Double.random(in: 0...1) })
        lastFishingTick = now
        showFishingFrame()
    }

    private func showFishingFrame() {
        let frame = fishing.frame
        guard frame != shownFishingFrame else { return }
        shownFishingFrame = frame
        button?.image = images.image(for: .fishing(frame))
    }

    private func stopFishingAnimation() {
        guard fishingTimer != nil else { return }
        fishingTimer?.invalidate()
        fishingTimer = nil
        shownFishingFrame = nil
        button?.image = images.image(for: .standing)
    }

    // 정해진 장면이 되풀이되는 쉬는 일은 쉬기 시작한 뒤 지난 시간으로 장면을 정하고, 장면이 바뀔 때만 이미지를 바꾼다.
    private func startRestAnimation(_ activity: IconRest) {
        if restTimer != nil, restActivity == activity { return }
        stopRestAnimation()
        restActivity = activity
        restStartedAt = ProcessInfo.processInfo.systemUptime
        shownRestFrame = nil
        showRestFrame()
        restTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.restTickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.showRestFrame() }
        }
    }

    private func showRestFrame() {
        guard let restActivity else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - restStartedAt
        guard let frame = RestTimeline.frame(activity: restActivity, elapsed: elapsed), frame != shownRestFrame else { return }
        shownRestFrame = frame
        button?.image = images.image(for: .rest(frame))
    }

    private func stopRestAnimation() {
        guard restTimer != nil else { return }
        restTimer?.invalidate()
        restTimer = nil
        restActivity = nil
        shownRestFrame = nil
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
