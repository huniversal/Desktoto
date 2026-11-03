import Foundation
import Synchronization
import Testing
@testable import Preferences

private struct RegistrationFailure: Error {}

private final class FakeLoginItemService: LoginItemService {
    enum Call: Equatable {
        case register, unregister, openSystemSettings
    }

    private let state: Mutex<(status: LoginItemStatus, calls: [Call])>
    private let nextStatusAfterRegister: LoginItemStatus?
    private let shouldFail: Bool

    init(status: LoginItemStatus, nextStatusAfterRegister: LoginItemStatus? = nil, shouldFail: Bool = false) {
        state = Mutex((status, []))
        self.nextStatusAfterRegister = nextStatusAfterRegister
        self.shouldFail = shouldFail
    }

    var status: LoginItemStatus { state.withLock { $0.status } }
    var calls: [Call] { state.withLock { $0.calls } }

    func register() throws {
        state.withLock { $0.calls.append(.register) }
        if shouldFail { throw RegistrationFailure() }
        if let nextStatusAfterRegister { state.withLock { $0.status = nextStatusAfterRegister } }
    }

    func unregister() throws {
        state.withLock { $0.calls.append(.unregister) }
        if shouldFail { throw RegistrationFailure() }
        state.withLock { $0.status = .notRegistered }
    }

    func openSystemSettings() {
        state.withLock { $0.calls.append(.openSystemSettings) }
    }
}

struct LoginItemTests {
    // AC-8
    @Test func registersWhenDisabled() {
        let service = FakeLoginItemService(status: .notRegistered, nextStatusAfterRegister: .enabled)
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { _ in })

        loginItem.toggle()

        #expect(service.calls == [.register])
        #expect(loginItem.isEnabled)
    }

    // AC-8
    @Test func unregistersWhenEnabled() {
        let service = FakeLoginItemService(status: .enabled)
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { _ in })

        loginItem.toggle()

        #expect(service.calls == [.unregister])
        #expect(!loginItem.isEnabled)
    }

    // AC-8
    @Test func opensSystemSettingsWhenApprovalIsRequired() {
        let service = FakeLoginItemService(status: .notRegistered, nextStatusAfterRegister: .requiresApproval)
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { _ in })

        loginItem.toggle()

        #expect(service.calls == [.register, .openSystemSettings])
        #expect(!loginItem.isEnabled)
    }

    // AC-8
    @Test func logsFailureAndStillChecksApprovalState() {
        let service = FakeLoginItemService(status: .requiresApproval, shouldFail: true)
        let messages = Mutex<[String]>([])
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { message in messages.withLock { $0.append(message) } })

        loginItem.toggle()

        #expect(service.calls == [.register, .openSystemSettings])
        #expect(messages.withLock { $0 }.count == 1)
    }

    // #23 AC-7
    @Test func enablesOnFirstLaunchAndReportsApplied() {
        let service = FakeLoginItemService(status: .notRegistered, nextStatusAfterRegister: .enabled)
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { _ in })

        let hasApplied = loginItem.enableOnFirstLaunch(hasApplied: false)

        #expect(hasApplied)
        #expect(service.calls == [.register])
        #expect(loginItem.isEnabled)
    }

    // #23 AC-7
    @Test func doesNotReEnableAfterDefaultWasApplied() {
        let service = FakeLoginItemService(status: .notRegistered)
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { _ in })

        let hasApplied = loginItem.enableOnFirstLaunch(hasApplied: true)

        #expect(hasApplied)
        #expect(service.calls.isEmpty)
    }

    // #23 AC-7
    @Test func firstLaunchLeavesAnEnabledItemAlone() {
        let service = FakeLoginItemService(status: .enabled)
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { _ in })

        #expect(loginItem.enableOnFirstLaunch(hasApplied: false))
        #expect(service.calls.isEmpty)
    }

    // #23 AC-7
    @Test func firstLaunchDoesNotOpenSystemSettingsWhenApprovalIsRequired() {
        let service = FakeLoginItemService(status: .notRegistered, nextStatusAfterRegister: .requiresApproval)
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { _ in })

        #expect(loginItem.enableOnFirstLaunch(hasApplied: false))
        #expect(service.calls == [.register])
    }

    // #23 AC-7
    @Test func firstLaunchLogsRegistrationFailureAndStillMarksApplied() {
        let service = FakeLoginItemService(status: .notRegistered, shouldFail: true)
        let messages = Mutex<[String]>([])
        let loginItem = LoginItem(isRunningAsApp: true, service: service, logFailure: { message in messages.withLock { $0.append(message) } })

        #expect(loginItem.enableOnFirstLaunch(hasApplied: false))
        #expect(messages.withLock { $0 }.count == 1)
    }

    // #23 AC-7
    @Test func firstLaunchDoesNothingOutsideAppBundleAndStaysUnapplied() {
        let service = FakeLoginItemService(status: .notRegistered)
        let loginItem = LoginItem(isRunningAsApp: false, service: service, logFailure: { _ in })

        #expect(!loginItem.enableOnFirstLaunch(hasApplied: false))
        #expect(service.calls.isEmpty)
    }

    // AC-8
    @Test func doesNothingOutsideAppBundle() {
        let service = FakeLoginItemService(status: .enabled)
        let loginItem = LoginItem(isRunningAsApp: false, service: service, logFailure: { _ in })

        loginItem.toggle()

        #expect(service.calls.isEmpty)
        #expect(!loginItem.isEnabled)
    }
}
