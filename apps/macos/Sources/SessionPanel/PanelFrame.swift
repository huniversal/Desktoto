import CoreGraphics
import DesignSystem

// 패널 창 위치 계산. 상태바 아이콘 바로 아래에서 아이콘의 왼쪽 끝에 맞춰 시작하되(시스템 메뉴와 같은 위치), 화면 가장자리를 넘지 않게 한다.
enum PanelFrame {
    // size에는 그림자 여백이 포함되어 있으므로, 유리 모양 기준으로 위치를 맞춘다.
    static func origin(buttonFrame: CGRect, visibleFrame: CGRect, size: CGSize) -> CGPoint {
        let margin = DSShadow.panelMargin
        let alignedX = buttonFrame.minX - margin
        let minX = visibleFrame.minX + PanelLayout.screenEdgeMargin - margin
        let maxX = visibleFrame.maxX - size.width - PanelLayout.screenEdgeMargin + margin
        let originX = min(max(alignedX, minX), max(minX, maxX))
        let originY = buttonFrame.minY - PanelLayout.gapBelowStatusItem - size.height + margin
        return CGPoint(x: originX, y: originY)
    }
}
