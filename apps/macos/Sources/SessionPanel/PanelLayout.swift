import CoreGraphics

// 세션 패널 화면에만 쓰는 배치 값. 디자인 토큰이 아니라서 DesignSystem이 아닌 이 모듈에 둔다.
enum PanelLayout {
    // 줄 하나에 펼쳐지는 상세 줄(간격 9 + 글자 높이 약 14)보다 조금 넉넉한 높이. 한 번에 한 줄만 펼쳐진다.
    static let detailReserve: CGFloat = 26
    static let inlineSpacing: CGFloat = 8
    static let emptyRowVertical: CGFloat = 24
    static let usageLabelWidth: CGFloat = 32
    static let usagePercentWidth: CGFloat = 34
    static let usageResetWidth: CGFloat = 70
    static let finishedDotGap: CGFloat = 3
    // 점 아래쪽을 글자 기준선보다 이만큼 위로 올린다. 점이 글자 윗끝 위쪽에 오는 첨자 위치이고, offset이라서 줄 높이는 늘어나지 않는다.
    static let finishedDotRaise: CGFloat = 9
    static let gapBelowStatusItem: CGFloat = 6
    static let screenEdgeMargin: CGFloat = 8
}
