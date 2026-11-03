import AppKit
import DesignSystem
import SessionPanel
import SwiftUI

/// 유리 패널 창의 표시와 숨김, 바깥 클릭 감지, 테마 적용을 맡는다. 무엇을 보여 줄지는 앱이 모델에 넣는다.
@MainActor
final class PanelController {
    static let fadeDuration: TimeInterval = 0.15

    let model: SessionPanelModel
    /// Esc나 바깥 클릭으로 닫아 달라는 요청
    var onDismissRequest: (@MainActor () -> Void)?

    private let panel = GlassPanel()
    private var outsideClickMonitor: Any?

    init(now: Date) {
        model = SessionPanelModel(now: now)
        panel.contentView = NSHostingView(rootView: SessionPanelView(model: model))
        panel.onCancel = { [weak self] in self?.onDismissRequest?() }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    /// 패널 창의 외관을 정한다. nil이면 macOS 설정을 따라가고, 유리와 글자 색도 이 외관에 맞춰 바뀐다.
    func applyTheme(_ theme: Theme) {
        switch theme {
        case .light: panel.appearance = NSAppearance(named: .aqua)
        case .dark: panel.appearance = NSAppearance(named: .darkAqua)
        case .system: panel.appearance = nil
        }
    }

    /// 상태바 아이콘 바로 아래에서 아이콘의 왼쪽 끝에 맞춰 시작하되, 화면 가장자리를 넘지 않게 한다.
    func updateFrame(buttonWindow: NSWindow?) {
        guard let buttonWindow else { return }
        let visibleFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.updateFrame(buttonFrame: buttonWindow.frame, visibleFrame: visibleFrame)
    }

    func show(buttonWindow: NSWindow?) {
        updateFrame(buttonWindow: buttonWindow)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 1
        }
        startOutsideClickMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        stopOutsideClickMonitor()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.finishHiding() }
        })
    }

    // 사라지는 도중 다시 열렸다면 숨기지 않는다.
    private func finishHiding() {
        guard panel.alphaValue == 0 else { return }
        panel.orderOut(nil)
        model.finishedIDs = []
        // 창이 숨겨질 때 hover 종료가 전달되지 않을 수 있어서, 다음에 열 때 줄이 펼쳐진 채 나오지 않게 직접 비운다.
        model.hoveredID = nil
    }

    // 메뉴바 전용 앱이라 다른 앱을 클릭해도 패널이 저절로 닫히지 않으므로, 전역 클릭으로 직접 닫는다.
    // 이 앱 안에서 일어난 클릭(상태바 아이콘 등)은 전역 모니터로 오지 않는다.
    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onDismissRequest?() }
        }
    }

    private func stopOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}
