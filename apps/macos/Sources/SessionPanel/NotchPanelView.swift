import DesignSystem
import Domain
import SwiftUI

/// 노치 봇 모드에서 노치가 펼쳐질 때 그 안에 보여 주는 패널. 검정 바탕 위에 어두운 카드를 가로로 늘어놓아 낮고 넓게 보여 준다.
/// 왼쪽부터 AI별 사용량 카드, 맨 오른쪽에 가장 넓은 세션 카드가 온다. 데이터는 유리 패널과 같은 SessionPanelModel을 쓴다.
public struct NotchPanelView: View {
    private let model: SessionPanelModel

    /// 펼친 노치 안쪽의 크기. 창과 노치 모양이 이 크기를 기준으로 잡힌다.
    public static let contentWidth: CGFloat = 520
    public static let maxContentHeight: CGFloat = 130

    public init(model: SessionPanelModel) {
        self.model = model
    }

    public var body: some View {
        let isShowingUsage = model.showsUsage && !model.usages.isEmpty
        HStack(alignment: .top, spacing: NotchPanelStyle.cardGap) {
            if isShowingUsage {
                ForEach(model.usages) { usage in
                    NotchUsageCard(usage: usage, title: PanelText.usageTitle(of: usage, among: model.usages), now: model.now)
                }
            }
            if model.showsContext {
                NotchSessionCard(model: model)
                    // 세션 카드가 남는 가로를 가장 많이 차지한다.
                    .layoutPriority(1)
            }
        }
        // 카드들이 가장 높은 카드에 맞춰 같은 높이가 되도록, 줄 높이를 내용의 높이로 고정한다.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, NotchPanelStyle.outerPadding)
        .padding(.bottom, NotchPanelStyle.outerPadding)
        .padding(.top, NotchPanelStyle.topPadding)
        .frame(width: Self.contentWidth, alignment: .topLeading)
        .environment(\.barColorMode, model.colorMode)
        // 노치는 늘 검정이라 글자와 막대를 어두운 모드 색으로 고정한다.
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
    }
}

/// 노치 패널 크기 값. 유리 패널보다 한 단계 작은 글자와 좁은 여백을 쓴다.
private enum NotchPanelStyle {
    static let cardGap: CGFloat = 8
    static let outerPadding: CGFloat = 12
    static let topPadding: CGFloat = 6
    static let cardPadding = EdgeInsets(top: 9, leading: 11, bottom: 9, trailing: 11)
    static let cardRadius: CGFloat = 14
    static let cardColor = Color(white: 0.11)
    static let titleFont = Font.system(size: 12, weight: .semibold)
    static let bodyFont = Font.system(size: 11)
    static let smallFont = Font.system(size: 10)
    static let rowSpacing: CGFloat = 5
    static let usageLabelWidth: CGFloat = 24
    static let percentWidth: CGFloat = 30
    static let usageCardWidth: CGFloat = 118
    /// 세션 카드에 한 번에 보여 줄 줄 수. 넘치면 카드 안에서 스크롤한다.
    static let visibleSessionCount = 2
    static let sessionRowSpacing: CGFloat = 8
}

private extension View {
    func notchCard() -> some View {
        padding(NotchPanelStyle.cardPadding)
            .background(NotchPanelStyle.cardColor, in: RoundedRectangle(cornerRadius: NotchPanelStyle.cardRadius, style: .continuous))
    }
}

/// AI 하나의 5시간, 주간 사용량. 초기화까지 남은 시간은 5시간 기준 하나만 작게 둔다.
private struct NotchUsageCard: View {
    let usage: ToolUsage
    let title: String
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: NotchPanelStyle.rowSpacing) {
            Text(title)
                .font(NotchPanelStyle.titleFont)
                .lineLimit(1)
            if let fiveHour = usage.fiveHour {
                row(label: "5h", window: fiveHour)
            }
            if let weekly = usage.weekly {
                row(label: "주간", window: weekly)
            }
            // 초기화 시각을 모르거나 이미 지나서 비어 있으면 "후 초기화"만 남지 않게 줄을 숨긴다.
            if let fiveHour = usage.fiveHour, let resetsAt = fiveHour.resetsAt, resetsAt > now {
                Text("\(PanelText.resetRemaining(until: resetsAt, now: now)) 후 초기화")
                    .font(NotchPanelStyle.smallFont)
                    .monospacedDigit()
                    .secondaryText()
                    .lineLimit(1)
            }
        }
        .frame(width: NotchPanelStyle.usageCardWidth, alignment: .leading)
        // 옆 카드 중 가장 높은 카드에 맞춰 늘어난다.
        .frame(maxHeight: .infinity, alignment: .top)
        .notchCard()
    }

    private func row(label: String, window: UsageWindow) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(NotchPanelStyle.bodyFont)
                .secondaryText()
                .frame(width: NotchPanelStyle.usageLabelWidth, alignment: .leading)
            UsageBar(ratio: window.usedRatio, thresholds: .usage)
            Text(PanelText.percent(window.usedRatio))
                .font(NotchPanelStyle.bodyFont.weight(.medium))
                .monospacedDigit()
                .frame(width: NotchPanelStyle.percentWidth, alignment: .trailing)
        }
    }
}

/// 세션 목록 카드. 제목 옆에 세션 수를 두고, 줄을 누르면 그 세션으로 이동한다.
private struct NotchSessionCard: View {
    let model: SessionPanelModel
    /// 세션 줄 하나의 실제 높이. 재서 두 줄 높이로 목록을 자른다.
    @State private var rowHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: NotchPanelStyle.rowSpacing + 1) {
            HStack(spacing: 6) {
                Text("세션")
                    .font(NotchPanelStyle.titleFont)
                Text("\(model.sessions.count)")
                    .font(NotchPanelStyle.bodyFont)
                    .monospacedDigit()
                    .secondaryText()
            }
            if model.sessions.isEmpty {
                Text("세션 없음")
                    .font(NotchPanelStyle.bodyFont)
                    .secondaryText()
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: NotchPanelStyle.sessionRowSpacing) {
                        ForEach(model.sessions, id: \.id) { session in
                            NotchSessionRow(
                                session: session,
                                isJustFinished: model.isJustFinished(session),
                                onOpen: { model.open(session) }
                            )
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                rowHeight = max(rowHeight, height)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(maxHeight: visibleListHeight)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .notchCard()
    }

    /// 두 줄이 딱 들어가는 높이. 줄 높이를 재기 전에는 제한하지 않는다.
    private var visibleListHeight: CGFloat {
        guard rowHeight > 0 else { return .infinity }
        let count = CGFloat(NotchPanelStyle.visibleSessionCount)
        return rowHeight * count + NotchPanelStyle.sessionRowSpacing * (count - 1)
    }
}

private struct NotchSessionRow: View {
    let session: SessionInfo
    let isJustFinished: Bool
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(PanelText.title(of: session))
                    .font(NotchPanelStyle.bodyFont.weight(session.isRunning ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if isJustFinished {
                    FinishedDot()
                        .accessibilityLabel("확인하지 않은 완료")
                }
                Spacer(minLength: 6)
                if let waitingKind = session.waitingKind {
                    StatusPill(PanelText.waitingPill(waitingKind))
                } else {
                    Text(PanelText.trailing(of: session))
                        .font(NotchPanelStyle.bodyFont)
                        .monospacedDigit()
                        .secondaryText()
                        .lineLimit(1)
                }
            }
            UsageBar(ratio: PanelText.usageRatio(of: session))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}
