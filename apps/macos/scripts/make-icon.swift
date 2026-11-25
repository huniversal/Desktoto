import AppKit

// 앱 아이콘 생성기. 사용법: make-icon <출력 .iconset 폴더>
// 기본 캐릭터 토토처럼 블루 퍼플 그라데이션 둥근 사각형 위에 흰 알약 눈 두 개를 그려서, macOS가 요구하는 크기별 PNG를 저장한다.
// 웹 파비콘(apps/web/favicon.svg)도 같은 색과 비율을 쓴다.

// macOS 아이콘 규격: 1024 캔버스 안에서 실제 그림은 약 80%이고, 모서리 반경은 그림 폭의 약 22%다.
private let artworkRatio: CGFloat = 0.805
private let cornerRatio: CGFloat = 0.2237
// 노치 봇 작업 색(NotchBotView.swift)에서 고른 그라데이션. 왼쪽 위 하늘빛 파랑에서 오른쪽 아래 자줏빛 보라로 흐른다.
private let gradientColors: [NSColor] = [
    NSColor(srgbRed: 0.16, green: 0.56, blue: 0.96, alpha: 1),
    NSColor(srgbRed: 0.22, green: 0.36, blue: 0.96, alpha: 1),
    NSColor(srgbRed: 0.38, green: 0.27, blue: 0.88, alpha: 1),
    NSColor(srgbRed: 0.58, green: 0.30, blue: 0.94, alpha: 1),
    NSColor(srgbRed: 0.74, green: 0.30, blue: 0.86, alpha: 1)
]
// 눈 크기와 간격(그림 폭 대비). 작은 크기에서도 뭉개지지 않게 노치 봇 눈보다 조금 굵다.
private let eyeWidthRatio: CGFloat = 0.15
private let eyeHeightRatio: CGFloat = 0.24
private let eyeDistanceRatio: CGFloat = 0.21
private let eyeTiltDegrees: CGFloat = -12

private func renderIcon(pixelSize: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.setShouldAntialias(true)

    let size = CGFloat(pixelSize)
    let artworkSize = size * artworkRatio
    let artwork = NSRect(x: (size - artworkSize) / 2, y: (size - artworkSize) / 2, width: artworkSize, height: artworkSize)

    // 배경: 왼쪽 위에서 오른쪽 아래로 흐르는 블루 퍼플 그라데이션 둥근 사각형(이 좌표계는 아래쪽이 0이라 -45도가 왼쪽 위에서 오른쪽 아래다)
    let background = NSBezierPath(roundedRect: artwork, xRadius: artworkSize * cornerRatio, yRadius: artworkSize * cornerRatio)
    NSGradient(colors: gradientColors)?.draw(in: background, angle: -45)

    // 눈: 가운데에 -12도 기울어진 흰 알약 두 개
    let eyeWidth = artworkSize * eyeWidthRatio
    let eyeHeight = artworkSize * eyeHeightRatio
    NSColor.white.setFill()
    [-1.0, 1.0].forEach { side in
        let transform = NSAffineTransform()
        transform.translateX(by: size / 2 + side * artworkSize * eyeDistanceRatio / 2, yBy: size / 2)
        // 아래쪽이 0인 좌표계라 화면에서 시계 반대 방향으로 기울이려면 각도 부호를 뒤집는다.
        transform.rotate(byDegrees: -eyeTiltDegrees)
        NSGraphicsContext.saveGraphicsState()
        transform.concat()
        NSBezierPath(
            roundedRect: NSRect(x: -eyeWidth / 2, y: -eyeHeight / 2, width: eyeWidth, height: eyeHeight),
            xRadius: eyeWidth / 2,
            yRadius: eyeWidth / 2
        ).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

guard CommandLine.arguments.count == 2 else {
    print("사용법: make-icon <출력 .iconset 폴더>")
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// (파일 이름에 쓰는 크기, 배율). iconutil이 요구하는 이름 규칙이다.
let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (base, scale) in variants {
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    guard let data = renderIcon(pixelSize: base * scale) else {
        print("실패: \(name)")
        exit(1)
    }
    try data.write(to: outputDirectory.appendingPathComponent(name))
}
print("아이콘 \(variants.count)장 생성 완료")
