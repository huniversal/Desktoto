import AppKit
import SwiftUI

// 막대와 캐릭터의 색상. 흰색은 단색이고, 컬러는 막대에 그라데이션이 들어간다.
public enum ColorMode: String {
    case white
    case color
}

// 패널의 테마. 시스템은 macOS의 라이트와 다크 설정을 따른다.
public enum Theme: String, CaseIterable {
    case light
    case dark
    case system
}

// 패널 유리의 투명한 정도 5단계. 이미 저장된 clear, regular, tinted 값은 그대로 읽힌다.
public enum GlassStyle: String, CaseIterable {
    case clear
    case slightlyClear
    case regular
    case slightlyTinted
    case tinted

    // 창 배경색을 입히는 불투명도. 입히지 않는 단계는 nil이다.
    public var tintOpacity: Double? {
        switch self {
        case .clear: return 0.12
        case .slightlyClear: return 0.35
        case .regular: return nil
        case .slightlyTinted: return 0.28
        case .tinted: return 0.55
        }
    }

    // 투명 쪽은 맑은 유리, 진한 쪽은 일반 유리를 쓴다.
    public var isClearGlass: Bool {
        self == .clear || self == .slightlyClear
    }

    public var glass: Glass {
        let base = isClearGlass ? Glass.clear : Glass.regular
        guard let tintOpacity else { return base }
        return base.tint(Color(nsColor: .windowBackgroundColor).opacity(tintOpacity))
    }
}

private struct BarColorModeKey: EnvironmentKey {
    static let defaultValue = ColorMode.white
}

private struct GlassStyleKey: EnvironmentKey {
    static let defaultValue = GlassStyle.regular
}

public extension EnvironmentValues {
    // 막대가 어느 색 모드로 그려질지. 패널 맨 위에서 한 번 넣어 두면 깊이 있는 막대까지 전달된다.
    var barColorMode: ColorMode {
        get { self[BarColorModeKey.self] }
        set { self[BarColorModeKey.self] = newValue }
    }

    var glassStyle: GlassStyle {
        get { self[GlassStyleKey.self] }
        set { self[GlassStyleKey.self] = newValue }
    }
}
