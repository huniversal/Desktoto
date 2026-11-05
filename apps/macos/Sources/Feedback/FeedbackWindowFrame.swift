import CoreGraphics

// 입력 창 위치 계산. 세션 패널처럼 상태바 아이콘 바로 아래에서 아이콘의 왼쪽 끝에 맞춰 시작해 오른쪽으로 펼치고,
// 화면 가장자리를 넘지 않게 한다. 좌표는 AppKit 기준이라 원점이 왼쪽 아래다.
public enum FeedbackWindowFrame {
    // 아이콘 아래 간격과 화면 가장자리 간격은 세션 패널과 같은 값이다.
    static let gapBelowStatusItem: CGFloat = 6
    static let screenEdgeMargin: CGFloat = 8

    public static func origin(buttonFrame: CGRect, visibleFrame: CGRect, size: CGSize) -> CGPoint {
        let minX = visibleFrame.minX + screenEdgeMargin
        let maxX = visibleFrame.maxX - size.width - screenEdgeMargin
        // 화면이 창보다 좁으면 왼쪽 끝을 우선한다.
        let originX = min(max(buttonFrame.minX, minX), max(minX, maxX))
        let originY = buttonFrame.minY - gapBelowStatusItem - size.height
        return CGPoint(x: originX, y: originY)
    }
}
