import Foundation

public enum AppBundle {
    // 앱(.app)으로 실행 중인지. 번들이 아닌 개발용 실행(swift run)에서는 UserNotifications와 로그인 항목을 쓸 수 없다.
    public static var isRunningAsApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
