// swift-tools-version:5.9
import PackageDescription

// CI와 패키징 검증용 임시 골격이다. 모듈 구성은 #2(아키텍처 세팅)에서 교체한다.
let package = Package(
    name: "Desktoto",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "DesktotoCore"),
        .executableTarget(name: "Desktoto", dependencies: ["DesktotoCore"]),
        .testTarget(name: "DesktotoCoreTests", dependencies: ["DesktotoCore"])
    ]
)
