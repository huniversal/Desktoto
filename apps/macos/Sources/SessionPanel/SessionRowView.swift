import DesignSystem
import Domain
import SwiftUI

struct SessionRowView: View {
    let session: SessionInfo
    let isJustFinished: Bool
    let isHovering: Bool
    let onHoverChange: (Bool) -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.rowContent) {
            HStack(alignment: .firstTextBaseline, spacing: PanelLayout.inlineSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: PanelLayout.finishedDotGap) {
                    Text(PanelText.title(of: session))
                        .font(DSTypography.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isJustFinished {
                        // 확인하지 않은 완료. 메뉴바의 보라색 점과 같은 색이고, 패널을 다시 열면 사라진다.
                        FinishedDot()
                            .offset(y: -PanelLayout.finishedDotRaise)
                            .accessibilityLabel("확인하지 않은 완료")
                    }
                }
                Spacer(minLength: PanelLayout.inlineSpacing)
                if let waitingKind = session.waitingKind {
                    // 눌러서 그 대화로 이동하면 거기서 허용, 거부나 답변을 할 수 있다. 사용률 자리에 알약으로 알린다.
                    StatusPill(PanelText.waitingPill(waitingKind))
                } else {
                    trailingText
                }
            }
            UsageBar(ratio: PanelText.usageRatio(of: session))
            if isHovering {
                HStack(spacing: PanelLayout.inlineSpacing) {
                    Text(PanelText.modelName(of: session))
                        .lineLimit(1)
                    Spacer(minLength: PanelLayout.inlineSpacing)
                    Text(PanelText.tokenUsage(of: session))
                        .monospacedDigit()
                }
                .font(DSTypography.caption)
                .secondaryText()
                .transition(.opacity)
            }
        }
        .padding(.horizontal, DSSpacing.rowHorizontal)
        .padding(.vertical, DSSpacing.rowVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .animation(DSMotion.detail, value: isHovering)
        .onHover(perform: onHoverChange)
        // 열 곳이 있는 세션만 눌러서 이동할 수 있고, 그때만 손가락 모양 포인터가 된다.
        .pointerStyle(session.canOpen ? .link : .default)
        .onTapGesture(perform: onOpen)
        .background {
            // 진행 중인 줄만 안쪽에서 색이 천천히 흐른다. 모양 밖으로는 번지지 않고, 시작과 끝에서 서서히 나타나고 사라진다.
            ZStack {
                if session.isRunning {
                    FlowingGradientBackground()
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.row))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            // 진행 중인 줄이 이어질 때 강조 영역끼리 맞닿아 겹쳐 보이지 않도록 위아래로 살짝 안쪽에 둔다.
            .padding(.vertical, DSSpacing.rowHighlightVerticalInset)
            .animation(DSMotion.stateChange, value: session.isRunning)
        }
    }

    // 사용률은 항상 보여준다. 방금 끝난 줄은 글자 대신 사용률이 기본색으로 또렷해지는 것으로만 알린다.
    @ViewBuilder
    private var trailingText: some View {
        let text = Text(PanelText.trailing(of: session))
            .font(DSTypography.subheadline)
            .monospacedDigit()
        Group {
            if isJustFinished {
                text.foregroundStyle(Color.primary)
            } else {
                text.secondaryText()
            }
        }
        .fixedSize()
        .layoutPriority(1)
    }
}
