import Foundation
import ServiceManagement

public enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

// 로그인 항목(SMAppService) 경계.
public protocol LoginItemService: Sendable {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

// 로그인할 때 앱이 자동으로 켜지게 하는 macOS 로그인 항목. 앱(.app)으로 실행 중일 때만 쓸 수 있다.
public struct LoginItem: Sendable {
    private let isRunningAsApp: Bool
    private let service: any LoginItemService
    private let logFailure: @Sendable (String) -> Void

    public init(
        isRunningAsApp: Bool = AppBundle.isRunningAsApp,
        service: any LoginItemService = SystemLoginItemService(),
        logFailure: @escaping @Sendable (String) -> Void = { NSLog("%@", $0) }
    ) {
        self.isRunningAsApp = isRunningAsApp
        self.service = service
        self.logFailure = logFailure
    }

    public var isEnabled: Bool {
        isRunningAsApp && service.status == .enabled
    }

    // 켜져 있으면 끄고, 꺼져 있으면 켠다. 사용자 승인이 필요한 상태면 시스템 설정의 로그인 항목 화면을 연다.
    public func toggle() {
        guard isRunningAsApp else { return }
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            logFailure("로그인 항목 변경 실패: \(error.localizedDescription)")
        }
        if service.status == .requiresApproval {
            service.openSystemSettings()
        }
    }
}

public struct SystemLoginItemService: LoginItemService {
    public init() {}

    public var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    public func register() throws {
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
