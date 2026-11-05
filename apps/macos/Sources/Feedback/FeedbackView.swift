import DesignSystem
import SwiftUI

// 의견 입력 창의 내용. 상태는 FeedbackModel이 갖고, 이 View는 보여 주기만 한다.
// 보내기를 누르면 `onSubmit`을 부르고, 창을 닫고 전송을 이어 가는 일은 부르는 쪽이 맡는다.
public struct FeedbackView: View {
    public static let size = CGSize(width: 360, height: 240)

    @Bindable private var model: FeedbackModel
    private let onSubmit: @MainActor () -> Void

    public init(model: FeedbackModel, onSubmit: @escaping @MainActor () -> Void) {
        self.model = model
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.panelGap) {
            editor
            if case .failed(let failure) = model.phase {
                Text(FeedbackText.failureMessage(for: failure))
                    .font(DSTypography.subheadline)
                    .foregroundStyle(DSColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                // 한도를 넘으면 자르지 않고 빨갛게 알린다. 줄일 때까지 보낼 수 없다.
                Text(FeedbackText.characterCount(model.textLength))
                    .font(DSTypography.caption)
                    .monospacedDigit()
                    .foregroundStyle(model.isOverLimit ? AnyShapeStyle(DSColor.danger) : AnyShapeStyle(.secondary))
                Button(FeedbackText.sendButton) { onSubmit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canSend)
            }
        }
        .padding(DSSpacing.rowHorizontal)
        .frame(width: Self.size.width, height: Self.size.height)
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
    }
}
