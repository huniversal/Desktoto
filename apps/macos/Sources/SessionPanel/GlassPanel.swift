import AppKit

// 포커스를 빼앗지 않으면서 Esc 키를 받을 수 있는 투명 패널. 모양과 유리 효과는 SwiftUI 쪽이 그린다.
public final class GlassPanel: NSPanel {
    public var onCancel: (@MainActor () -> Void)?

    public init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        // 시스템 그림자는 둥근 유리 모양이 아니라 창의 네모난 경계로 그려지므로 끄고, 그림자는 SwiftUI에서 직접 그린다.
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
    }

    public override var canBecomeKey: Bool { true }

    public override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    // 내용 크기에 맞춰 상태바 아이콘 아래로 창을 옮긴다.
    public func updateFrame(buttonFrame: CGRect, visibleFrame: CGRect) {
        guard let contentView else { return }
        let size = contentView.fittingSize
        let origin = PanelFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)
        setFrame(CGRect(origin: origin, size: size), display: true)
    }
}
