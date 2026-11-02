import CoreGraphics

public enum DSSize {
    public static let panelWidth: CGFloat = 270
    public static let barHeight: CGFloat = 4
    public static let dividerHeight: CGFloat = 0.5
    public static let finishedDot: CGFloat = 6
}

public enum DSSpacing {
    public static let panelInset: CGFloat = 6
    public static let rowHorizontal: CGFloat = 15
    public static let rowVertical: CGFloat = 12
    public static let rowContent: CGFloat = 9
    public static let rowHighlightVerticalInset: CGFloat = 3
    public static let panelGap: CGFloat = 8
    public static let usageBlockVertical: CGFloat = 10
    public static let usageRow: CGFloat = 8
    public static let pillHorizontal: CGFloat = 8
    public static let pillVertical: CGFloat = 3
}

public enum DSRadius {
    public static let panel: CGFloat = 18
    // 줄 안쪽 강조 영역이 패널 모서리와 같은 곡률 중심을 갖도록 안쪽 반경 = 바깥 반경 - 여백
    public static let row: CGFloat = panel - DSSpacing.panelInset
}

public enum DSShadow {
    // 그림자가 창 밖에서 잘리지 않도록 유리 패널 둘레에 두는 투명 여백
    public static let panelMargin: CGFloat = 36
    public static let radius: CGFloat = 10
    public static let offsetY: CGFloat = 4
    public static let opacity = 0.14
}

public enum DSOpacity {
    public static let divider = 0.08
    public static let barTrack = 0.16
    public static let barFillShadow = 0.18
    public static let approvalPillBackground = 0.35
    public static let secondaryTextLight = 0.85
    public static let gradientLight = 0.22
    public static let gradientDark = 0.2
}
