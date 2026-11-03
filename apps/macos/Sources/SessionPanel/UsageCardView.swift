import DesignSystem
import Domain
import SwiftUI

// AI마다 5시간, 주간 사용량을 막대와 초기화까지 남은 시간으로 보여준다.
struct UsageCardView: View {
    let usages: [ToolUsage]
    let now: Date

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(usages.enumerated()), id: \.element.tool) { index, usage in
                if index > 0 {
                    RowDivider()
                }
                ToolUsageBlock(usage: usage, now: now)
            }
        }
        .glassCard()
    }
}

private struct ToolUsageBlock: View {
    let usage: ToolUsage
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.usageRow) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.tool.rawValue)
                    .font(DSTypography.bodySemibold)
                Spacer(minLength: PanelLayout.inlineSpacing)
                if let staleText = usage.createStaleText(now: now) {
                    Text(staleText)
                        .font(DSTypography.caption)
                        .secondaryText()
                }
            }
            if let fiveHour = usage.fiveHour {
                UsageWindowRow(label: "5시간", window: fiveHour, now: now)
            }
            if let weekly = usage.weekly {
                UsageWindowRow(label: "주간", window: weekly, now: now)
            }
        }
        .padding(.horizontal, DSSpacing.rowHorizontal)
        .padding(.vertical, DSSpacing.usageBlockVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UsageWindowRow: View {
    let label: String
    let window: UsageWindow
    let now: Date

    var body: some View {
        HStack(spacing: DSSpacing.usageRow) {
            Text(label)
                .font(DSTypography.caption)
                .secondaryText()
                .frame(width: PanelLayout.usageLabelWidth, alignment: .leading)
            UsageBar(ratio: window.usedRatio, thresholds: .usage)
            Text(PanelText.percent(window.usedRatio))
                .font(DSTypography.captionMedium)
                .monospacedDigit()
                .frame(width: PanelLayout.usagePercentWidth, alignment: .trailing)
            Text(PanelText.resetRemaining(until: window.resetsAt, now: now))
                .font(DSTypography.caption)
                .monospacedDigit()
                .secondaryText()
                .lineLimit(1)
                .frame(width: PanelLayout.usageResetWidth, alignment: .trailing)
        }
    }
}
