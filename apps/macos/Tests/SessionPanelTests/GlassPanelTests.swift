import AppKit
import Testing
@testable import SessionPanel

@MainActor
struct GlassPanelTests {
    // AC-6
    @Test func isTransparentNonActivatingPopupPanel() {
        _ = NSApplication.shared
        let panel = GlassPanel()

        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.isOpaque)
        #expect(panel.backgroundColor == .clear)
        #expect(!panel.hasShadow)
        #expect(panel.level == .popUpMenu)
        #expect(panel.collectionBehavior == [.canJoinAllSpaces, .fullScreenAuxiliary, .transient])
        #expect(!panel.isReleasedWhenClosed)
        #expect(panel.canBecomeKey)
    }

    // AC-6
    @Test func cancelOperationCallsOnCancel() {
        _ = NSApplication.shared
        let panel = GlassPanel()
        var cancelCount = 0
        panel.onCancel = { cancelCount += 1 }

        panel.cancelOperation(nil)

        #expect(cancelCount == 1)
    }
}
