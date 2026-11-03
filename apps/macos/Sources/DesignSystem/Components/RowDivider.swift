import SwiftUI

public struct RowDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(DSOpacity.divider))
            .frame(height: DSSize.dividerHeight)
            .padding(.horizontal, DSSpacing.rowHorizontal)
    }
}
