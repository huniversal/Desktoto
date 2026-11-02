import SwiftUI

// 승인이나 답변을 기다린다고 알리는 알약
public struct StatusPill: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(DSTypography.captionSemibold)
            .padding(.horizontal, DSSpacing.pillHorizontal)
            .padding(.vertical, DSSpacing.pillVertical)
            .background(Capsule().fill(DSColor.approvalPill.opacity(DSOpacity.approvalPillBackground)))
            .fixedSize()
            .layoutPriority(1)
    }
}
