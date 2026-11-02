import DesignSystem
import SwiftUI

// 패널 전체가 하나의 Liquid Glass이고, 세션은 카드 없이 가는 구분선으로 나뉜 줄로 보여준다.
// 평소에는 제목, 사용률, 막대만 보이고, 모델과 토큰 수는 마우스를 올렸을 때만 펼쳐진다.
public struct SessionPanelView: View {
    private let model: SessionPanelModel

    public init(model: SessionPanelModel) {
        self.model = model
    }

    public var body: some View {
        // 사용량 카드와 세션 카드는 각각 하나의 유리 카드이고, 사용량 카드가 위에 고정된다.
        GlassEffectContainer(spacing: DSSpacing.panelGap) {
            VStack(spacing: DSSpacing.panelGap) {
                if model.showsUsage, !model.usages.isEmpty {
                    UsageCardView(usages: model.usages, now: model.now)
                }
                if model.showsContext {
                    sessionCard
                }
            }
        }
        .environment(\.barColorMode, model.colorMode)
        .environment(\.glassStyle, model.glassStyle)
        .padding(.top, DSShadow.panelMargin)
        .padding(.horizontal, DSShadow.panelMargin)
        // 상세 줄이 펼쳐질 자리를 창에 미리 확보한다. 창 크기는 그대로 두고 유리 모양만 부드럽게 늘었다 줄어든다.
        .padding(.bottom, DSShadow.panelMargin + PanelLayout.detailReserve)
        // 내용 높이가 변해도 위쪽 가장자리는 고정하고 아래로만 늘고 줄게 한다. 이게 없으면 내용이 창 가운데에 맞춰져 위아래로 흔들린다.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DSMotion.detail, value: model.hoveredID)
    }

    private var sessionCard: some View {
        VStack(spacing: 0) {
            if model.sessions.isEmpty {
                EmptySessionRow()
            }
            ForEach(Array(model.sessions.enumerated()), id: \.element.id) { index, session in
                if index > 0 {
                    RowDivider()
                }
                SessionRowView(
                    session: session,
                    isJustFinished: model.isJustFinished(session),
                    isHovering: model.hoveredID == session.id,
                    onHoverChange: { isInside in model.changeHover(of: session, isInside: isInside) },
                    onOpen: { model.open(session) }
                )
            }
        }
        .glassCard()
    }
}

private struct EmptySessionRow: View {
    var body: some View {
        Text("세션 없음")
            .font(DSTypography.body)
            .secondaryText()
            .frame(maxWidth: .infinity)
            .padding(.vertical, PanelLayout.emptyRowVertical)
    }
}
