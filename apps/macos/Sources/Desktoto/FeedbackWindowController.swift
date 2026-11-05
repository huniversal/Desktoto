import AppKit
import DesignSystem
import Feedback
import SwiftUI

/// 의견 입력 창의 표시와 수명을 맡는다. 창은 하나만 열고, 이미 열려 있으면 앞으로 가져온다.
/// 보내기를 누르면 바로 창을 닫고(낙관적 업데이트) 전송은 이어 간다. 전송이 실패하면 쓰던 글을 되돌려 창을 다시 연다.
@MainActor
final class FeedbackWindowController: NSObject, NSWindowDelegate {
    private let sender: any FeedbackSending
    private var window: NSWindow?
    private var model: FeedbackModel?
    private var theme: Theme = .system
    // 창을 상태바 아이콘 아래에 띄우기 위한 기준. 실패해서 창을 다시 열 때도 같은 위치를 쓴다.
    private weak var buttonWindow: NSWindow?

    init(sender: any FeedbackSending) {
        self.sender = sender
    }

    func show(theme: Theme, buttonWindow: NSWindow?) {
        self.theme = theme
        self.buttonWindow = buttonWindow
        if let window {
            window.appearance = Self.makeAppearance(for: theme)
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        present(FeedbackModel(
            sender: sender,
            appVersion: FeedbackVersionText.appVersion(from: Bundle.main.infoDictionary),
            osVersion: FeedbackVersionText.osVersion(ProcessInfo.processInfo.operatingSystemVersion)
        ))
    }

    func windowWillClose(_ notification: Notification) {
        model = nil
        window = nil
    }

    private func present(_ model: FeedbackModel) {
        let view = FeedbackView(model: model) { [weak self, model] in self?.submit(model) }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = FeedbackText.windowTitle
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.appearance = Self.makeAppearance(for: theme)
        window.delegate = self
        placeBelowStatusItem(window)
        self.model = model
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    // 세션 패널처럼 아이콘 아래에서 아이콘 왼쪽 끝에 맞춰 오른쪽으로 펼친다. 아이콘 위치를 모르면 화면 가운데에 둔다.
    private func placeBelowStatusItem(_ window: NSWindow) {
        guard let buttonWindow else {
            window.center()
            return
        }
        let visibleFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let origin = FeedbackWindowFrame.origin(buttonFrame: buttonWindow.frame, visibleFrame: visibleFrame, size: window.frame.size)
        window.setFrameOrigin(origin)
    }

    // 전송을 시작하자마자 창을 닫는다. 전송 결과를 기다리는 모델은 이 클로저가 붙잡고 있다.
    private func submit(_ model: FeedbackModel) {
        guard model.canSend else { return }
        model.startSending { [weak self] failure in
            guard let failure else { return }
            self?.restore(model, after: failure)
        }
        window?.close()
    }

    // 실패한 글을 되돌린다. 그 사이에 새 창이 열려 있으면 그 창에 합치고, 없으면 같은 글로 창을 다시 연다.
    private func restore(_ failedModel: FeedbackModel, after failure: FeedbackFailure) {
        if let model {
            model.restore(failedText: failedModel.text, failure: failure)
            NSApp.activate()
            window?.makeKeyAndOrderFront(nil)
        } else {
            present(failedModel)
        }
    }

    private static func makeAppearance(for theme: Theme) -> NSAppearance? {
        switch theme {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
}
