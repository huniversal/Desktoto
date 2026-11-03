import SwiftUI

// 확인하지 않은 완료를 알리는 점. 위치와 접근성 문구는 쓰는 쪽에서 정한다.
public struct FinishedDot: View {
    public init() {}

    public var body: some View {
        Circle()
            .fill(DSColor.finishedDot)
            .frame(width: DSSize.finishedDot, height: DSSize.finishedDot)
            .fixedSize()
    }
}
