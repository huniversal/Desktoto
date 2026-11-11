import AppKit

/// 미니게임의 그림. 셔틀콕은 메뉴바 캐릭터와 같은 픽셀 아트 모양으로 그린다.
/// 한 번 그려서 비트맵으로 저장해 두고 레이어에 붙여 쓴다(매 프레임 다시 그리지 않는다).
@MainActor
public enum RallyArt {
    /// 픽셀 한 칸의 크기(pt). 2.5pt는 Retina 화면 픽셀 정확히 5개라서 또렷하다.
    static let pixel: CGFloat = 2.5
    public static let shuttleSize = CGSize(width: 7 * pixel, height: 8 * pixel)

    /// 위에서부터 한 줄씩. 1이 칠해지는 칸이다. 깃털 6줄은 형광 연두, 아래 2줄(코르크)은 형광 분홍이다.
    private static let shuttleRows = [
        "1010101",
        "1010101",
        "0111110",
        "0111110",
        "0011100",
        "0011100",
        "0111110",
        "0011100"
    ]
    private static let corkRowStart = 6

    /// 어떤 배경에서도 눈에 띄도록 형광 연두(깃털)와 형광 분홍(코르크)을 쓴다.
    public static let neonFeather = NSColor(calibratedRed: 0.72, green: 1.00, blue: 0.00, alpha: 1)
    public static let neonCork = NSColor(calibratedRed: 1.00, green: 0.10, blue: 0.62, alpha: 1)

    public static func shuttleImage(scale: CGFloat) -> CGImage? {
        createImage(size: shuttleSize, scale: scale) {
            shuttleRows.enumerated().forEach { rowIndex, line in
                (rowIndex >= corkRowStart ? neonCork : neonFeather).setFill()
                line.enumerated().forEach { columnIndex, cell in
                    guard cell == "1" else { return }
                    // 위에서부터 그린 줄을 아래가 0인 좌표로 뒤집는다.
                    let y = shuttleSize.height - CGFloat(rowIndex + 1) * pixel
                    NSRect(x: CGFloat(columnIndex) * pixel, y: y, width: pixel, height: pixel).fill()
                }
            }
        }
    }

    /// 아래쪽이 0인 포인트 좌표로 그린 결과를 화면 배율에 맞춘 비트맵으로 만든다.
    private static func createImage(size: CGSize, scale: CGFloat, draw: () -> Void) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int((size.width * scale).rounded()),
            height: Int((size.height * scale).rounded()),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = .none
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw()
        NSGraphicsContext.current = previous
        return context.makeImage()
    }
}
