import SwiftUI

// 패널 하나를 감싸는 유리 카드. 같은 모양과 그림자를 쓴다.
struct GlassCard: ViewModifier {
    @Environment(\.glassStyle) private var glassStyle

    func body(content: Content) -> some View {
        content
            .padding(DSSpacing.panelInset)
            .frame(width: DSSize.panelWidth)
            .glassEffect(glassStyle.glass, in: .rect(cornerRadius: DSRadius.panel))
            .shadow(color: .black.opacity(DSShadow.opacity), radius: DSShadow.radius, x: 0, y: DSShadow.offsetY)
    }
}

public extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
