import AppKit
import MenuBarIcon
import SwiftUI

/// 표시 위치를 노치와 메뉴바 사이에서 바꿀 때, 노치부터 메뉴바 아이콘 자리까지 덮는 투명 창을 잠시 띄워 물방울 전환을 재생한다.
/// 창은 클릭을 통과시키고, 재생이 끝나면 닫는다.
@MainActor
final class PlacementTransitionController {
    /// 노치 오른쪽 끝과 위쪽(화면 좌표), 노치 높이, 노치 밖으로 나온 봇 폭
    struct NotchGeometry {
        let minX: CGFloat
        let maxX: CGFloat
        let top: CGFloat
        let height: CGFloat
        let botWidth: CGFloat
    }

    /// 재생 시간(초). 떨어질 때와 붙을 때 같다.
    static let duration: TimeInterval = 3
    /// 노치 봇 위 물방울 지름(노치 높이 대비)과 메뉴바 토토 지름(메뉴바 아이콘 높이 대비)
    private static let botDropRatio: CGFloat = 0.78
    /// 메뉴바 토토 몸은 아이콘 이미지 높이 20칸 중 18칸이다.
    private static let totoDropRatio: CGFloat = 0.9
    private static let botDropWidthRatio: CGFloat = 0.92
    /// 창 가장자리 여백. 물방울이 튀거나 출렁여도 잘리지 않게 둔다.
    private static let margin: CGFloat = 24

    private var panel: NSPanel?
    private var finishWork: DispatchWorkItem?
    private var pendingCompletion: (() -> Void)?

    var isPlaying: Bool { panel != nil }

    /// 전환을 재생하고 끝나면 completion을 부른다. 재생 중에 다시 부르면 진행 중인 전환을 끝 상태로 마친 뒤 새로 시작한다.
    func play(toNotch: Bool, notch: NotchGeometry, iconFrame: NSRect, tint: PlacementTransitionView.Tint, completion: @escaping () -> Void) {
        finishNow()

        let minX = notch.minX - Self.margin
        let maxX = iconFrame.maxX + Self.margin
        let height = max(notch.height, iconFrame.height) + Self.margin
        let frame = NSRect(x: minX, y: notch.top - height, width: maxX - minX, height: height)
        // 화면 좌표(아래쪽 0)를 창 좌표(위쪽 0)로 바꾼다.
        let toCanvas = { (point: CGPoint) in CGPoint(x: point.x - minX, y: notch.top - point.y) }

        let motion = PlacementTransitionMotion(
            direction: toNotch ? .toNotch : .toMenuBar,
            start: toCanvas(CGPoint(x: notch.maxX + notch.botWidth / 2, y: notch.top - notch.height / 2)),
            end: toCanvas(CGPoint(x: iconFrame.midX, y: iconFrame.midY)),
            // 물방울이 봇 자리(봇 폭 x 노치 높이) 밖으로 불룩하게 나오지 않게 봇 폭 안에 맞춘다.
            startSize: min(notch.height * Self.botDropRatio, notch.botWidth * Self.botDropWidthRatio),
            endSize: iconFrame.height * Self.totoDropRatio,
            botWidth: notch.botWidth,
            duration: Self.duration
        )
        let view = PlacementTransitionView(motion: motion, tint: tint, notchMinX: notch.minX - minX, notchMaxX: notch.maxX - minX, notchHeight: notch.height, startDate: Date())

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // 노치 봇 창과 같은 층이라 메뉴바 위를 지나간다.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel

        pendingCompletion = completion
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.finishNow() }
        }
        finishWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration, execute: work)
    }

    /// 진행 중인 전환을 끝 상태로 마친다.
    func finishNow() {
        finishWork?.cancel()
        finishWork = nil
        // 마지막 장면과 실제 아이콘이 바뀌는 순간 사이에 빈 프레임이 없도록, 실제 아이콘을 먼저 보이게 한 뒤 창을 닫는다.
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
        panel?.orderOut(nil)
        panel = nil
    }
}
