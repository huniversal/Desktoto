import CoreGraphics
import Testing
@testable import DesignSystem

@Test func glassStyleRawValuesMatchSavedSettings() {
    #expect(GlassStyle.allCases.map(\.rawValue) == ["clear", "slightlyClear", "regular", "slightlyTinted", "tinted"])
}

@Test func themeRawValuesMatchSavedSettings() {
    #expect(Theme.allCases.map(\.rawValue) == ["light", "dark", "system"])
}

@Test func colorModeRawValuesMatchSavedSettings() {
    #expect(ColorMode(rawValue: "white") == .white)
    #expect(ColorMode(rawValue: "color") == .color)
}

@Test func glassStyleTintOpacityMatchesOriginal() {
    #expect(GlassStyle.clear.tintOpacity == 0.12)
    #expect(GlassStyle.slightlyClear.tintOpacity == 0.35)
    #expect(GlassStyle.regular.tintOpacity == nil)
    #expect(GlassStyle.slightlyTinted.tintOpacity == 0.28)
    #expect(GlassStyle.tinted.tintOpacity == 0.55)
}

@Test func glassStyleClearKindMatchesOriginal() {
    #expect(GlassStyle.allCases.filter(\.isClearGlass) == [.clear, .slightlyClear])
}

@Test func thresholdsMatchOriginal() {
    #expect(DSThreshold.context == DSThreshold(warning: 0.6, danger: 0.85))
    #expect(DSThreshold.usage == DSThreshold(warning: 0.8, danger: 0.95))
}

@Test func rowRadiusIsPanelRadiusMinusInset() {
    let expectedRadius: CGFloat = DSRadius.panel - DSSpacing.panelInset
    #expect(DSRadius.row == expectedRadius)
    #expect(DSRadius.row == 12)
}

@Test(arguments: [
    (0.59, ColorMode.white, UsageBarFill.plain),
    (0.59, ColorMode.color, UsageBarFill.gradient),
    (0.6, ColorMode.white, UsageBarFill.warning),
    (0.84, ColorMode.color, UsageBarFill.warning),
    (0.85, ColorMode.white, UsageBarFill.danger),
    (1.0, ColorMode.color, UsageBarFill.danger)
])
func contextBarFillSwitchesAtThresholds(ratio: Double, colorMode: ColorMode, expected: UsageBarFill) {
    #expect(UsageBarFill(ratio: ratio, colorMode: colorMode, thresholds: .context) == expected)
}

@Test(arguments: [
    (0.79, UsageBarFill.plain),
    (0.8, UsageBarFill.warning),
    (0.94, UsageBarFill.warning),
    (0.95, UsageBarFill.danger)
])
func usageBarFillSwitchesAtThresholds(ratio: Double, expected: UsageBarFill) {
    #expect(UsageBarFill(ratio: ratio, colorMode: .white, thresholds: .usage) == expected)
}
