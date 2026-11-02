// swift-tools-version:6.0
import PackageDescription

// 모듈 구성과 의존 규칙은 docs/architecture.md를 따른다. 이 파일을 바꾸면 그 문서도 함께 고친다.
// 각 모듈의 소스는 대응하는 기능 이슈(#3 이후)에서 채운다.
let package = Package(
    name: "Desktoto",
    platforms: [.macOS("26.0")],
    targets: [
        // Claude 데스크탑 앱이 캐시에 남기는 사용량 응답이 zstd로 압축되어 있어서, 해독기(facebook/zstd v1.5.7, BSD)만 가져다 쓴다.
        .target(
            name: "CZstd",
            exclude: ["LICENSE"],
            publicHeadersPath: "include",
            cSettings: [.define("ZSTD_DISABLE_ASM"), .define("DEBUGLEVEL", to: "0")]
        ),

        // 도메인 모델과 외부 경계, 디자인 시스템 (다른 모듈이 의존하는 바닥 계층)
        .target(name: "Domain"),
        .target(name: "Boundaries"),
        .target(name: "DesignSystem"),

        // 기능 모듈끼리는 서로 의존하지 않는다. 조립은 Desktoto 앱이 한다.
        .target(name: "SessionMonitoring", dependencies: ["Domain", "Boundaries"]),
        .target(name: "UsageMonitoring", dependencies: ["Domain", "Boundaries", "CZstd"]),
        .target(name: "ClaudeIntegration", dependencies: ["Boundaries"]),
        .target(name: "TerminalIntegration", dependencies: ["Domain", "Boundaries"]),
        .target(name: "Preferences", dependencies: ["DesignSystem", "Boundaries"]),

        // UI 모듈은 Boundaries를 쓰지 않는다.
        .target(name: "MenuBarIcon", dependencies: ["Domain", "DesignSystem"]),
        .target(name: "SessionPanel", dependencies: ["Domain", "DesignSystem"]),

        .target(name: "TestSupport", dependencies: ["Boundaries"]),

        .executableTarget(
            name: "Desktoto",
            dependencies: [
                "Domain", "Boundaries", "DesignSystem",
                "SessionMonitoring", "UsageMonitoring", "ClaudeIntegration", "TerminalIntegration", "Preferences",
                "MenuBarIcon", "SessionPanel"
            ]
        ),

        .testTarget(name: "CZstdTests", dependencies: ["CZstd"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "BoundariesTests", dependencies: ["Boundaries", "TestSupport"]),
        .testTarget(name: "SessionMonitoringTests", dependencies: ["SessionMonitoring", "Domain", "Boundaries", "TestSupport"])
    ],
    swiftLanguageModes: [.v6]
)
