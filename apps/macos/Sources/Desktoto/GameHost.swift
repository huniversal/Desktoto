import AppKit
import DesignSystem
import MenuBarIcon
import QuartzCore

/// 키보드를 받을 수 있게 키 윈도우가 될 수 있는 투명 창. 마우스는 아래 앱으로 그대로 통과시킨다.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 미니게임이 공통으로 쓰는 바탕. 화면 전체를 덮는 투명 창을 띄우고, 메뉴바 오른쪽 아이콘들을 쓸어내고,
/// ESC로 바로 끄고, 끝난 뒤 Space로 다시 시작하는 것을 맡는다. 게임 규칙과 그림은 `GameScene`이 맡는다.
@MainActor
final class GameHost {
    private static let escapeKeyCode: UInt16 = 53
    private static let spaceKeyCode: UInt16 = 49
    private static let returnKeyCode: UInt16 = 36
    private static let frameInterval: TimeInterval = 1.0 / 60
    /// 빈 아이콘이 제자리를 잡기를 기다리는 시간
    private static let settleDuration: TimeInterval = 0.2
    /// 빈 아이콘의 폭이 늘어나며 다른 아이콘을 밀어내는 시간
    private static let sweepDuration: TimeInterval = 0.5
    /// 폭이 다 늘어난 뒤 아이콘들이 자리를 잡기를 기다리는 시간
    private static let afterSweepDuration: TimeInterval = 0.15
    private static let maxClearWidth: CGFloat = 520
    /// 빈 아이콘이 제자리를 잡기를 기다리는 최대 시간
    private static let placementTimeout: TimeInterval = 3

    /// 게임이 끝났을 때(ESC 포함) 불린다. 숨겨 둔 메뉴바 캐릭터를 되돌리는 데 쓴다.
    var onFinish: (@MainActor () -> Void)?

    private var window: OverlayWindow?
    private var scene: (any GameScene)?
    private var sprites: IconImageSet?
    private var timer: Timer?
    private var keyMonitor: Any?
    private let clearer = MenuBarClearer()
    private var lastTick: TimeInterval = 0
    private var startedAt: TimeInterval = 0
    private var clearWidth: CGFloat?
    private var isSceneStarted = false
    private var wasEscapeDown = false
    private var screen: NSScreen?
    private var buttonFrame = NSRect.zero
    private var screenOrigin = CGPoint.zero
    private var scale: CGFloat = 2

    var isRunning: Bool {
        window != nil
    }

    /// 시작하면 true를 돌려준다. 이미 실행 중이거나 화면을 찾지 못하면 false다.
    @discardableResult
    func start(scene: any GameScene, buttonWindow: NSWindow?, colorMode: ColorMode) -> Bool {
        guard !isRunning, let buttonWindow else { return false }
        guard let screen = buttonWindow.screen ?? NSScreen.main else { return false }

        self.screen = screen
        self.scene = scene
        buttonFrame = buttonWindow.frame
        scale = screen.backingScaleFactor
        screenOrigin = screen.frame.origin
        sprites = IconImageSet(appearance: IconAppearance(colorMode: colorMode), scale: scale)

        let overlay = makeWindow(frame: screen.frame)
        window = overlay
        clearWidth = nil
        isSceneStarted = false
        wasEscapeDown = Self.isEscapeDown
        startedAt = ProcessInfo.processInfo.systemUptime
        lastTick = startedAt

        // 키 입력은 창이 키 윈도우일 때 받는다. 다른 곳을 눌러 포커스를 잃어도 끌 수 있게 tick에서 ESC 상태도 확인한다.
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let isHandled = MainActor.assumeIsolated { self?.handleKey(keyCode: keyCode) ?? false }
            return isHandled ? nil : event
        }

        clearer.begin()
        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        return true
    }

    func stop() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        clearer.end()
        if isSceneStarted { scene?.end() }
        scene = nil
        window?.orderOut(nil)
        window = nil
        sprites = nil
        onFinish?()
    }

    // MARK: - 창

    private func makeWindow(frame: NSRect) -> OverlayWindow {
        let overlay = OverlayWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        // 메뉴바 아이콘(상태 막대 레벨)보다 위에 둔다.
        overlay.level = .screenSaver
        overlay.ignoresMouseEvents = true
        overlay.isReleasedWhenClosed = false
        overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        overlay.contentView = content
        return overlay
    }

    // MARK: - 입력

    private static var isEscapeDown: Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(escapeKeyCode))
    }

    /// 게임이 처리한 키면 true를 돌려준다(다른 곳으로 넘기지 않는다).
    private func handleKey(keyCode: UInt16) -> Bool {
        switch keyCode {
        case Self.escapeKeyCode:
            stop()
            return true
        case Self.spaceKeyCode, Self.returnKeyCode:
            if isSceneStarted, scene?.isOver == true { scene?.restart() }
            return true
        default:
            return false
        }
    }

    // MARK: - 한 프레임

    private func tick() {
        // 다른 앱을 눌러 포커스를 잃어도 ESC로 끌 수 있다. 눌린 순간만 본다.
        let isEscapeDown = Self.isEscapeDown
        defer { wasEscapeDown = isEscapeDown }
        if isEscapeDown, !wasEscapeDown {
            stop()
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let deltaTime = min(now - lastTick, 1.0 / 20)
        lastTick = now

        guard isSceneStarted else {
            clearMenuBar(elapsed: now - startedAt)
            return
        }

        let mouse = NSEvent.mouseLocation
        scene?.update(
            deltaTime: deltaTime,
            now: now,
            mouse: CGPoint(x: mouse.x - screenOrigin.x, y: mouse.y - screenOrigin.y)
        )
    }

    /// 빈 아이콘이 자리를 잡으면 폭을 늘려 다른 아이콘을 밀어내고, 다 비워지면 장면을 시작한다.
    private func clearMenuBar(elapsed: TimeInterval) {
        guard elapsed >= Self.settleDuration, let screen else { return }

        if clearWidth == nil {
            guard let spacerFrame = clearer.frame else { return }
            // 빈 아이콘이 아직 제자리(오른쪽 영역 안)에 놓이지 않았을 때 읽으면 폭이 엉뚱하게 작아진다.
            // 자리를 잡을 때까지 기다리고, 끝내 못 잡으면 제한 시간 뒤에 있는 그대로 진행한다.
            let minX = usableMinX(of: screen)
            let isPlaced = spacerFrame.maxX > minX + 60 && spacerFrame.maxX <= screen.frame.maxX
            guard isPlaced || elapsed >= Self.placementTimeout else { return }
            // 노치가 있으면 노치 오른쪽, 없으면 화면 오른쪽 절반까지만 비운다.
            let available = spacerFrame.maxX - minX - 4
            clearWidth = max(60, min(Self.maxClearWidth, available))
        }
        guard let clearWidth else { return }

        let progress = min((elapsed - Self.settleDuration) / Self.sweepDuration, 1)
        let eased = 1 - pow(1 - progress, 3)
        clearer.setWidth(clearWidth * CGFloat(eased))

        guard elapsed >= Self.settleDuration + Self.sweepDuration + Self.afterSweepDuration,
              let spacerFrame = clearer.frame,
              let root = window?.contentView?.layer,
              let sprites else { return }

        isSceneStarted = true
        scene?.begin(context: GameSceneContext(
            root: root,
            scale: scale,
            screenSize: screen.frame.size,
            menuBarBottomY: buttonFrame.minY - screenOrigin.y,
            menuBarCenterY: buttonFrame.midY - screenOrigin.y,
            usableMinX: usableMinX(of: screen) - screenOrigin.x,
            clearedMinX: spacerFrame.minX - screenOrigin.x,
            clearedMaxX: spacerFrame.maxX - screenOrigin.x,
            sprites: sprites
        ))
    }

    private func usableMinX(of screen: NSScreen) -> CGFloat {
        screen.auxiliaryTopRightArea?.minX ?? screen.frame.midX
    }
}
