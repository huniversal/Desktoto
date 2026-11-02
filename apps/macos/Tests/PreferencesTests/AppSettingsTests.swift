import DesignSystem
import Foundation
import Observation
import Testing
@testable import Preferences

@MainActor
struct AppSettingsTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "DesktotoPreferencesTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    // AC-1
    @Test func usesOriginalDefaultsWhenNothingIsStored() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        #expect(settings.showsUsage)
        #expect(settings.showsContext)
        #expect(settings.colorMode == .white)
        #expect(settings.theme == .system)
        #expect(settings.glassStyle == .regular)
        #expect(settings.sendsNotifications)
        #expect(settings.connectsClaudeCode)
        #expect(settings.fetchesCodexUsage)
    }

    // AC-1
    @Test func savesEveryChangeImmediatelyUnderOriginalKeys() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        settings.showsUsage = false
        settings.showsContext = false
        settings.colorMode = .color
        settings.theme = .dark
        settings.glassStyle = .tinted
        settings.sendsNotifications = false
        settings.connectsClaudeCode = false
        settings.fetchesCodexUsage = false

        #expect(defaults.object(forKey: "showsUsagePanel") as? Bool == false)
        #expect(defaults.object(forKey: "showsContextPanel") as? Bool == false)
        #expect(defaults.string(forKey: "colorMode") == "color")
        #expect(defaults.string(forKey: "theme") == "dark")
        #expect(defaults.string(forKey: "glassStyle") == "tinted")
        #expect(defaults.object(forKey: "sendsNotifications") as? Bool == false)
        #expect(defaults.object(forKey: "connectsClaudeCode") as? Bool == false)
        #expect(defaults.object(forKey: "fetchesCodexUsage") as? Bool == false)

        let reloaded = AppSettings(defaults: defaults)
        #expect(!reloaded.showsUsage)
        #expect(reloaded.colorMode == .color)
        #expect(reloaded.theme == .dark)
        #expect(reloaded.glassStyle == .tinted)
        #expect(!reloaded.fetchesCodexUsage)
    }

    // AC-2
    @Test(arguments: ["clear", "slightlyClear", "regular", "slightlyTinted", "tinted"])
    func readsEveryStoredGlassStyle(rawValue: String) {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(rawValue, forKey: "glassStyle")

        #expect(AppSettings(defaults: defaults).glassStyle.rawValue == rawValue)
    }

    // AC-2
    @Test func readsStoredThemeAndColorMode() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("light", forKey: "theme")
        defaults.set("color", forKey: "colorMode")
        let settings = AppSettings(defaults: defaults)

        #expect(settings.theme == .light)
        #expect(settings.colorMode == .color)
    }

    // AC-2
    @Test func fallsBackToDefaultsForUnknownOrWrongTypeValues() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("neon", forKey: "glassStyle")
        defaults.set(3, forKey: "theme")
        defaults.set(true, forKey: "colorMode")
        defaults.set("no", forKey: "sendsNotifications")
        defaults.set(0, forKey: "showsUsagePanel")
        defaults.set(0, forKey: "showsContextPanel")
        defaults.set(0, forKey: "connectsClaudeCode")
        defaults.set(1, forKey: "fetchesCodexUsage")
        let settings = AppSettings(defaults: defaults)

        #expect(settings.glassStyle == .regular)
        #expect(settings.theme == .system)
        #expect(settings.colorMode == .white)
        #expect(settings.sendsNotifications)
        #expect(settings.showsUsage)
        #expect(settings.showsContext)
        #expect(settings.connectsClaudeCode)
        #expect(settings.fetchesCodexUsage)
    }

    // AC-3
    @Test(arguments: [
        (true, true, true), (true, false, true), (false, true, true), (false, false, false)
    ])
    func hasVisiblePanelOnlyWhenAtLeastOnePanelIsOn(showsUsage: Bool, showsContext: Bool, expected: Bool) {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        settings.showsUsage = showsUsage
        settings.showsContext = showsContext

        #expect(settings.hasVisiblePanel == expected)
    }

    // AC-4
    @Test func notifiesObserversWhenAValueChanges() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        let changeCount = ChangeCounter()

        withObservationTracking {
            _ = settings.glassStyle
        } onChange: {
            changeCount.increment()
        }
        settings.glassStyle = .clear

        #expect(changeCount.value == 1)
    }
}

private final class ChangeCounter: @unchecked Sendable {
    private(set) var value = 0
    func increment() { value += 1 }
}
