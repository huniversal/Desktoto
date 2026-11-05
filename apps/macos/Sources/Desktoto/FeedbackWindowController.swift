import AppKit
import DesignSystem
import Feedback
import SwiftUI

/// 의견 입력 창의 표시와 수명을 맡는다. 창은 하나만 열고, 이미 열려 있으면 앞으로 가져온다.
/// 창을 닫으면 진행 중인 전송을 취소하고 입력은 버린다.
@MainActor
final class FeedbackWindowController: NSObject, NSWindowDelegate {
    private let sender: any FeedbackSending
    private var window: NSWindow?
    private var model: FeedbackModel?

    init(sender: any FeedbackSending) {
        self.sender = sender
    }

    func show(theme: Theme) {
        if let window {
            window.appearance = Self.makeAppearance(for: theme)
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let model = FeedbackModel(
            sender: sender,
            appVersion: FeedbackVersionText.appVersion(from: Bundle.main.infoDictionary),
            osVersion: FeedbackVersionText.osVersion(ProcessInfo.processInfo.operatingSystemVersion)
        )
        let view = FeedbackView(model: model) { [weak self] in self?.window?.close() }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = FeedbackText.windowTitle
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.appearance = Self.makeAppearance(for: theme)
        window.delegate = self
        window.center()
        self.model = model
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model?.cancelSending()
        model = nil
        window = nil
    }

    private static func makeAppearance(for theme: Theme) -> NSAppearance? {
        switch theme {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
}
