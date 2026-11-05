import DesignSystem
import SwiftUI

// 의견 입력 창의 내용. 상태는 FeedbackModel이 갖고, 이 View는 보여 주기만 한다.
public struct FeedbackView: View {
    public static let size = CGSize(width: 360, height: 280)
    private static let closeDelay: Duration = .seconds(1.2)

    @Bindable private var model: FeedbackModel
    private let onFinish: @MainActor () -> Void

    public init(model: FeedbackModel, onFinish: @escaping @MainActor () -> Void) {
        self.model = model
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.panelGap) {
            editor
            HStack {
                Text(FeedbackText.notice)
                    .font(DSTypography.caption)
                    .secondaryText()
                Spacer(minLength: DSSpacing.panelGap)
                Text(FeedbackText.characterCount(model.text.unicodeScalars.count))
                    .font(DSTypography.caption)
                    .monospacedDigit()
                    .secondaryText()
            }
            HStack {
                status
                Spacer()
                Button(FeedbackText.sendButton) { model.startSending() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canSend)
            }
        }
        .padding(DSSpacing.rowHorizontal)
        .frame(width: Self.size.width, height: Self.size.height)
        // 보낸 뒤 안내를 잠깐 보여 주고 창을 닫는다. 창이 먼저 닫히면 이 작업도 함께 취소된다.
        .task(id: model.phase) {
            guard model.phase == .sent else { return }
            try? await Task.sleep(for: Self.closeDelay)
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }

    private var editor: some View {
        TextEditor(text: $model.text)
            .font(DSTypography.body)
            .scrollContentBackground(.hidden)
            .padding(DSSpacing.pillHorizontal)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: DSRadius.row))
            .overlay(alignment: .topLeading) {
                if model.text.isEmpty {
                    Text(FeedbackText.placeholder)
                        .font(DSTypography.body)
                        .secondaryText()
                        .padding(.horizontal, DSSpacing.pillHorizontal + 5)
                        .padding(.vertical, DSSpacing.pillHorizontal)
                        .allowsHitTesting(false)
                }
            }
            .disabled(model.phase == .sending || model.phase == .sent)
    }

    @ViewBuilder
    private var status: some View {
        switch model.phase {
        case .editing:
            EmptyView()
        case .sending:
            Text(FeedbackText.sending)
                .font(DSTypography.subheadline)
                .secondaryText()
        case .sent:
            Text(FeedbackText.sent)
                .font(DSTypography.subheadline)
        case .failed(let failure):
            Text(FeedbackText.failureMessage(for: failure))
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColor.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
