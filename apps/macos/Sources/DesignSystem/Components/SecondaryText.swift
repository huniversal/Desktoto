import SwiftUI

// 보조 글자는 다크 모드에서는 시스템의 흐린 글자색을 쓰고, 라이트 모드에서는 밝은 유리 위에서 읽히도록 거의 검정으로 한다.
struct SecondaryTextStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(
            colorScheme == .dark
                ? AnyShapeStyle(.secondary)
                : AnyShapeStyle(Color.primary.opacity(DSOpacity.secondaryTextLight))
        )
    }
}

public extension View {
    func secondaryText() -> some View {
        modifier(SecondaryTextStyle())
    }
}
