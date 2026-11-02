import AppKit
import Preferences

/// `SettingsMenu`의 항목 모델을 `NSMenu`로 조립하고, 눌린 항목의 동작을 앱에 전달한다.
@MainActor
final class SettingsMenuBuilder: NSObject {
    var onAction: (@MainActor (SettingsAction) -> Void)?

    func makeMenu(entries: [SettingsMenuEntry]) -> NSMenu {
        let menu = NSMenu()
        entries.forEach { entry in
            switch entry {
            case .item(let item):
                menu.addItem(makeMenuItem(item))
            case .submenu(let title, let items):
                let submenu = NSMenu()
                items.forEach { submenu.addItem(makeMenuItem($0)) }
                let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                parent.submenu = submenu
                menu.addItem(parent)
            case .separator:
                menu.addItem(.separator())
            }
        }
        return menu
    }

    private func makeMenuItem(_ item: SettingsMenuItem) -> NSMenuItem {
        let menuItem = NSMenuItem(title: item.title, action: #selector(handleItemClick(_:)), keyEquivalent: item.keyEquivalent)
        menuItem.target = self
        menuItem.state = item.isOn ? .on : .off
        menuItem.isEnabled = item.isEnabled
        menuItem.representedObject = ActionBox(item.action)
        return menuItem
    }

    @objc private func handleItemClick(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? ActionBox else { return }
        onAction?(box.action)
    }
}

private final class ActionBox: NSObject {
    let action: SettingsAction

    init(_ action: SettingsAction) {
        self.action = action
    }
}
