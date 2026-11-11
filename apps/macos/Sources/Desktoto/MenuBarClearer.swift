import AppKit

/// 게임 중에 메뉴바 오른쪽을 비운다. 메뉴바 맨 오른쪽에 빈 아이콘을 하나 만들고 폭을 늘리면,
/// 그 왼쪽에 있는 다른 아이콘들이 실제로 왼쪽으로 밀려난다(자리가 모자라면 시스템이 가린다).
/// 다른 앱의 아이콘을 옮기거나 설정을 바꾸지 않고, 빈 아이콘을 지우면 모두 원래 자리로 돌아온다.
@MainActor
final class MenuBarClearer {
    private static let autosaveName = "DesktotoGameSpacer"
    private static let positionKey = "NSStatusItem Preferred Position \(autosaveName)"
    /// 이 값 이하면 시계와 컨트롤 센터 바로 왼쪽, 즉 옮길 수 있는 가장 오른쪽 자리에 놓인다.
    private static let rightmostPosition = 20.0

    private var item: NSStatusItem?

    var isActive: Bool {
        item != nil
    }

    /// 빈 아이콘이 놓인 화면 좌표 범위. 놓이기 전에는 nil이다.
    var frame: NSRect? {
        item?.button?.window?.frame
    }


    /// 자리를 보존하려고 폭 1짜리 빈 아이콘을 맨 오른쪽에 만든다.
    func begin() {
        guard item == nil else { return }
        UserDefaults.standard.set(Self.rightmostPosition, forKey: Self.positionKey)
        let created = NSStatusBar.system.statusItem(withLength: 1)
        created.autosaveName = Self.autosaveName
        item = created
    }

    func setWidth(_ width: CGFloat) {
        item?.length = max(width, 1)
    }

    /// 빈 아이콘을 지워서 밀려난 아이콘들이 돌아오게 한다.
    func end() {
        if let item {
            NSStatusBar.system.removeStatusItem(item)
        }
        item = nil
        UserDefaults.standard.removeObject(forKey: Self.positionKey)
    }
}
