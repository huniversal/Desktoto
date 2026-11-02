import Boundaries
import Foundation
import Synchronization
import UserNotifications

// 알림 센터(UserNotifications) 경계. 번들이 있는 실행에서만 쓴다.
public protocol NotificationCenterClient: Sendable {
    // 알림을 눌렀을 때 호출할 동작을 등록하고 권한을 요청한다.
    func activate(onOpenSession: @escaping @Sendable (String) -> Void)
    func post(title: String, body: String, userInfo: [String: String])
}

// 알림에 세션 id를 싣고 꺼내는 규칙.
public enum NotificationPayload {
    static let sessionIDKey = "sessionID"

    public static func makeUserInfo(sessionID: String) -> [String: String] {
        [sessionIDKey: sessionID]
    }

    public static func sessionID(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo[sessionIDKey] as? String
    }
}

// .app으로 실행 중이면 정식 알림을 보내고, 알림을 누르면 그 세션으로 이동한다.
// 개발용 swift run처럼 번들이 없으면 알림 센터에 접근하는 것만으로 앱이 종료되므로 AppleScript 알림으로 대신한다.
public struct NotificationSender: Sendable {
    private let isRunningAsApp: Bool
    private let center: any NotificationCenterClient
    private let appleScriptRunner: any AppleScriptRunner

    public init(
        isRunningAsApp: Bool = AppBundle.isRunningAsApp,
        center: any NotificationCenterClient = SystemNotificationCenter(),
        appleScriptRunner: any AppleScriptRunner = SystemAppleScriptRunner()
    ) {
        self.isRunningAsApp = isRunningAsApp
        self.center = center
        self.appleScriptRunner = appleScriptRunner
    }

    // 알림을 눌렀을 때 그 세션 id로 메인 액터에서 호출된다.
    public func setUp(onOpenSession: @escaping @MainActor @Sendable (String) -> Void) {
        guard isRunningAsApp else { return }
        center.activate { sessionID in
            Task { @MainActor in onOpenSession(sessionID) }
        }
    }

    public func send(title: String, body: String, sessionID: String) {
        guard isRunningAsApp else {
            sendWithAppleScript(title: title, body: body)
            return
        }
        center.post(title: title, body: body, userInfo: NotificationPayload.makeUserInfo(sessionID: sessionID))
    }

    private func sendWithAppleScript(title: String, body: String) {
        let script = "display notification \"\(Self.escape(body))\" with title \"\(Self.escape(title))\""
        // 원본처럼 실패(자동화 권한 거부 등)는 무시한다. 알림은 부가 기능이다.
        _ = try? appleScriptRunner.runReturningBoolean(source: script)
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

public final class SystemNotificationCenter: NSObject, NotificationCenterClient, UNUserNotificationCenterDelegate {
    private let onOpenSession = OpenSessionHandler()

    public override init() {
        super.init()
    }

    public func activate(onOpenSession: @escaping @Sendable (String) -> Void) {
        self.onOpenSession.set(onOpenSession)
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        // 소리는 앱이 직접 재생하므로 알림에는 소리를 달지 않는다. 권한 결과는 원본처럼 무시한다.
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    public func post(title: String, body: String, userInfo: [String: String]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil),
            withCompletionHandler: nil
        )
    }

    // 앱이 앞에 있을 때도 배너를 보여준다.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let sessionID = NotificationPayload.sessionID(from: response.notification.request.content.userInfo) else { return }
        onOpenSession.call(sessionID)
    }
}

// 델리게이트가 불리는 스레드와 등록하는 스레드가 달라서 잠금으로 보호한다.
private final class OpenSessionHandler: Sendable {
    private let handler = Mutex<(@Sendable (String) -> Void)?>(nil)

    func set(_ newHandler: @escaping @Sendable (String) -> Void) {
        handler.withLock { $0 = newHandler }
    }

    func call(_ sessionID: String) {
        handler.withLock { $0 }?(sessionID)
    }
}
