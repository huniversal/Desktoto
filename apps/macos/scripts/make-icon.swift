import AppKit

// 앱 아이콘 생성기. 사용법: make-icon <출력 .iconset 폴더>
// 어두운 둥근 사각형 위에 흰색 캐릭터를 그려서, macOS가 요구하는 크기별 PNG를 저장한다.

private struct UnitRect {
    let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
}

// 메뉴바 캐릭터(SpriteRenderer.swift)와 같은 도형. 24x16칸.
private let BODY = UnitRect(x: 3, y: 0, width: 18, height: 12)
private let EYES = [UnitRect(x: 6, y: 3, width: 2, height: 3), UnitRect(x: 16, y: 3, width: 2, height: 3)]
private let ARMS = [UnitRect(x: 0, y: 6, width: 3, height: 3), UnitRect(x: 21, y: 6, width: 3, height: 3)]
private let LEGS = [4, 7, 15, 18].map { UnitRect(x: CGFloat($0), y: 12, width: 2, height: 4) }
private let CHARACTER_UNITS_WIDE: CGFloat = 24
private let CHARACTER_UNITS_TALL: CGFloat = 16

// macOS 아이콘 규격: 1024 캔버스 안에서 실제 그림은 약 80%이고, 모서리 반경은 그림 폭의 약 22%다.
private let ARTWORK_RATIO: CGFloat = 0.805
private let CORNER_RATIO: CGFloat = 0.2237
private let CHARACTER_WIDTH_RATIO: CGFloat = 0.60

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
    let artworkSize = size * ARTWORK_RATIO
    let artwork = NSRect(x: (size - artworkSize) / 2, y: (size - artworkSize) / 2, width: artworkSize, height: artworkSize)

    // 배경: 위에서 아래로 살짝 어두워지는 둥근 사각형
    let background = NSBezierPath(roundedRect: artwork, xRadius: artworkSize * CORNER_RATIO, yRadius: artworkSize * CORNER_RATIO)
    NSGradient(
        starting: NSColor(calibratedRed: 0.22, green: 0.23, blue: 0.28, alpha: 1),
        ending: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.13, alpha: 1)
    )?.draw(in: background, angle: -90)

    // 캐릭터: 칸 하나를 정수 픽셀로 맞춰서 선이 또렷하게 한다(작은 크기에서는 소수 크기를 허용한다).
    let rawUnit = artworkSize * CHARACTER_WIDTH_RATIO / CHARACTER_UNITS_WIDE
    let unit = rawUnit >= 1 ? floor(rawUnit) : rawUnit
    let originX = (size - unit * CHARACTER_UNITS_WIDE) / 2
    let originY = (size - unit * CHARACTER_UNITS_TALL) / 2
    let fill = { (rect: UnitRect, color: NSColor) in
        color.setFill()
        // 이 좌표계는 아래쪽이 0이라서, 위에서부터 센 칸 좌표를 뒤집어 그린다.
        NSRect(
            x: originX + rect.x * unit,
            y: originY + (CHARACTER_UNITS_TALL - rect.y - rect.height) * unit,
            width: rect.width * unit,
            height: rect.height * unit
        ).fill()
    }
    LEGS.forEach { fill($0, .white) }
    ARMS.forEach { fill($0, .white) }
    fill(BODY, .white)
    EYES.forEach { fill($0, NSColor(calibratedWhite: 0.05, alpha: 1)) }

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
