import AppKit
import MenuBarIcon
import SwiftUI

/// 노치 오른쪽에 붙은 봇 창(실험). 노치가 있는 화면에서만 띄우고, 마우스를 바라보며 깜빡이고, 작업 중이면 몸 색이 바뀐다.
/// 접혀 있을 때는 봇 부분만, 펼쳤을 때는 펼친 노치 전체가 클릭을 받고, 나머지 여백은 클릭이 그대로 뒤로 통과한다.
@MainActor
final class NotchBotWindowController {
    private static let botWidth: CGFloat = 28
    /// 창 가장자리 여백. 펼친 노치의 둥근 모서리가 창 끝에 잘리지 않게 둔다.
    private static let canvasPadding: CGFloat = 16
    private static let topOverlap: CGFloat = 1
    /// 시선 목표가 이만큼 이상 바뀌어야 눈을 옮긴다. 작은 움직임에는 눈이 가만히 있다.
    private static let saccadeThreshold = 0.2
    /// 시선을 이만큼 크게 옮길 때는 절반 확률로 같이 깜빡인다.
    private static let blinkingSaccade = 0.9
    /// 마우스가 이 시간(초) 넘게 멈추면 가끔 다른 곳을 둘러본다.
    private static let idleDelay: TimeInterval = 2
    private static let smileDuration: TimeInterval = 2.5

    private let model = NotchBotModel()
    private var panel: NSPanel?
    private var idleTimer: Timer?
    private var lastMouseMoveTime = ProcessInfo.processInfo.systemUptime
    private var nextIdleLookTime: TimeInterval = 0
    private var blinkTimer: Timer?
    private var smileTimer: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var wasWorking = false
    private var isVisible = false
    private var notchScreen: NSScreen?
    private var layout: NotchBotLayout?
    private var panelContent = AnyView(EmptyView())
    private var expandedWidth: CGFloat = 520
    private var maxContentHeight: CGFloat = 240
    private var outsideClickMonitor: Any?

    /// 봇을 눌렀을 때 부른다. 값은 오른쪽 클릭인지다.
    var onClick: ((Bool) -> Void)?
    /// 펼친 상태에서 바깥을 클릭했을 때 부른다.
    var onDismissRequest: (() -> Void)?
    /// 노치 화면이 생기거나 사라졌을 때 부른다.
    var onAvailabilityChange: (() -> Void)?

    /// 노치가 있는 화면이 있어서 봇을 띄울 수 있는지
    var isAvailable: Bool { notchScreen != nil }

    /// 화면 좌표에서 봇(눈이 있는 자리)이 차지하는 영역. 설정 메뉴를 이 아래에 띄운다.
    var botFrame: NSRect? {
        guard let layout else { return nil }
        return screenRect(of: layout.botRect(isExpanded: model.isExpanded, contentHeight: model.contentHeight))
    }

    /// 지금 클릭을 받는 영역. 접혔으면 봇, 펼쳤으면 펼친 노치 전체다.
    private var clickableFrame: NSRect? {
        guard let layout else { return nil }
        let rect = model.isExpanded
            ? layout.bodyRect(isExpanded: true, contentHeight: model.contentHeight)
            : layout.botRect(isExpanded: false, contentHeight: model.contentHeight)
        return screenRect(of: rect)
    }

    var isExpanded: Bool { model.isExpanded }

    /// 펼쳤을 때 노치 안에 보여 줄 내용과 그 크기
    func setPanelContent<Content: View>(_ content: Content, width: CGFloat, maxHeight: CGFloat) {
        panelContent = AnyView(content)
        expandedWidth = width
        maxContentHeight = maxHeight
        placePanel()
    }

    /// 노치를 펼치거나 접는다. 펼친 동안에는 바깥 클릭을 지켜보다가 닫아 달라고 알린다.
    func setExpanded(_ isExpanded: Bool) {
        guard isVisible, model.isExpanded != isExpanded else { return }
        model.isExpanded = isExpanded
        panel?.ignoresMouseEvents = !isExpanded
        if isExpanded {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.onDismissRequest?() }
            }
        } else if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    /// 캔버스 좌표(왼쪽 위 원점, 아래로 +y)를 화면 좌표(왼쪽 아래 원점, 위로 +y)로 바꾼다.
    private func screenRect(of rect: CGRect) -> NSRect? {
        guard isVisible, let frame = panel?.frame else { return nil }
        return NSRect(x: frame.minX + rect.minX, y: frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    func start() {
        placePanel()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.placePanel()
                self?.onAvailabilityChange?()
            }
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateGaze() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.updateGaze() }
            return event
        }
        scheduleBlink()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickIdle() }
        }
    }

    /// 설정에서 노치 봇을 골랐을 때만 보인다.
    func setVisible(_ isVisible: Bool) {
        if !isVisible { setExpanded(false) }
        self.isVisible = isVisible
        placePanel()
    }

    /// 작업 중이면 몸 색을 바꾼다. 작업이 끝나는 순간 잠깐 웃는다.
    func setWorking(_ isWorking: Bool) {
        model.isWorking = isWorking
        if wasWorking, !isWorking { showSmile() }
        wasWorking = isWorking
    }

    private func placePanel() {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
        notchScreen = screen
        guard isVisible, let screen,
              let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            panel?.orderOut(nil)
            return
        }
        // 화면 위로 1pt 더 올려 그려서, 노치와 창 사이에 반 픽셀 틈이 비치지 않게 한다.
        let notchHeight = screen.safeAreaInsets.top + Self.topOverlap
        let notchMinX = screen.frame.minX + leftArea.maxX
        let notchWidth = screen.frame.minX + rightArea.minX - notchMinX
        let layout = NotchBotLayout(
            notchWidth: notchWidth,
            botWidth: Self.botWidth,
            height: notchHeight,
            expandedWidth: expandedWidth,
            maxContentHeight: maxContentHeight,
            padding: Self.canvasPadding
        )
        self.layout = layout
        // 창은 펼친 크기를 담을 만큼 크게 잡고, 노치 가운데에 맞춘다.
        let canvas = layout.canvasSize
        let frame = NSRect(
            x: notchMinX + notchWidth / 2 - canvas.width / 2,
            y: screen.frame.maxY + Self.topOverlap - canvas.height,
            width: canvas.width,
            height: canvas.height
        )
        let panel = panel ?? createPanel()
        let content = panelContent
        panel.contentView = NSHostingView(rootView: NotchBotView(model: model, layout: layout) { content })
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func createPanel() -> NSPanel {
        let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.onClick = { [weak self] isRightClick in self?.onClick?(isRightClick) }
        panel.isBotHit = { [weak self] point in self?.botFrame?.contains(point) ?? false }
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    private func updateGaze() {
        guard let botFrame else { return }
        lastMouseMoveTime = ProcessInfo.processInfo.systemUptime
        let mouse = NSEvent.mouseLocation
        updateClickThrough(mouse: mouse)
        let botCenterX = botFrame.midX
        let botCenterY = botFrame.midY
        let direction = GazeDirection.make(offsetX: mouse.x - botCenterX, offsetY: mouse.y - botCenterY)
        look(
            x: Double(direction.horizontal) / Double(GazeDirection.maxHorizontal),
            y: Double(direction.vertical) / Double(GazeDirection.maxVertical)
        )
    }

    /// 마우스가 클릭 영역 위에 있을 때만 창이 클릭을 받는다. 나머지 영역은 뒤의 메뉴바나 앱으로 클릭이 통과한다.
    private func updateClickThrough(mouse: NSPoint) {
        guard let panel else { return }
        let isOver = clickableFrame?.contains(mouse) ?? false
        if panel.ignoresMouseEvents == isOver { panel.ignoresMouseEvents = !isOver }
    }

    /// 눈을 새 지점으로 한 번에 옮긴다. 움직임이 작으면 무시하고, 크면 가끔 같이 깜빡인다.
    private func look(x: Double, y: Double) {
        let jump = hypot(x - model.gazeX, y - model.gazeY)
        guard jump >= Self.saccadeThreshold else { return }
        if jump >= Self.blinkingSaccade, Bool.random() { blinkOnce() }
        model.gazeX = x
        model.gazeY = y
    }

    /// 마우스가 한동안 멈춰 있으면 몇 초에 한 번씩 주변을 둘러본다.
    private func tickIdle() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastMouseMoveTime > Self.idleDelay, now >= nextIdleLookTime else { return }
        nextIdleLookTime = now + .random(in: 1.5...4)
        look(x: .random(in: -0.7...0.7), y: .random(in: -0.5...0.5))
    }

    private func scheduleBlink() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: .random(in: 2.5...5.5), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.blink() }
        }
    }

    private func blink() {
        blinkOnce()
        if Double.random(in: 0...1) < 0.25 {
            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.blinkOnce() }
            }
        }
        scheduleBlink()
    }

    /// 0.06초에 감고, 0.03초 머물렀다가, 0.12초에 걸쳐 뜬다. 다른 표정 중이면 건너뛴다.
    private func blinkOnce() {
        guard model.expression == .open else { return }
        model.expression = .blink
        Timer.scheduledTimer(withTimeInterval: 0.09, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.model.expression == .blink else { return }
                self.model.expression = .open
            }
        }
    }

    private func showSmile() {
        model.expression = .smile
        model.laughCount += 1
        smileTimer?.invalidate()
        smileTimer = Timer.scheduledTimer(withTimeInterval: Self.smileDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.expression = .open }
        }
    }
}

/// 기본 창은 화면 맨 위 메뉴바 영역에 걸치면 아래로 밀려나서 위쪽에 틈이 생긴다. 노치에 딱 붙도록 위치를 그대로 둔다.
private final class NotchPanel: NSPanel {
    var onClick: ((Bool) -> Void)?
    /// 화면 좌표의 점이 봇 위인지
    var isBotHit: ((NSPoint) -> Bool)?

    // 봇 위의 클릭만 가로채서 앱에 알린다. 메뉴바 캐릭터처럼 손을 뗄 때 반응한다.
    // 펼친 패널 안의 클릭은 그대로 SwiftUI로 보내서 세션 줄을 누를 수 있게 한다.
    override func sendEvent(_ event: NSEvent) {
        let point = convertPoint(toScreen: event.locationInWindow)
        guard isBotHit?(point) == true else {
            super.sendEvent(event)
            return
        }
        switch event.type {
        case .leftMouseUp: onClick?(false)
        case .rightMouseUp: onClick?(true)
        case .leftMouseDown, .rightMouseDown: break
        default: super.sendEvent(event)
        }
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
