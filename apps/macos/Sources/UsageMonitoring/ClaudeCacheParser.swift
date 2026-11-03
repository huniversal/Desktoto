import Boundaries
import CZstd
import Domain
import Foundation

public enum ClaudeCacheParser {
    private static func integer(_ bytes: Data, offset: Int, count: Int) -> UInt64 {
        (0..<count).reduce(0) { $0 | UInt64(bytes[bytes.startIndex + offset + $1]) << ($1 * 8) }
    }

    public static func key(in bytes: Data) -> String? {
        guard bytes.count >= 24, integer(bytes, offset: 0, count: 8) == 0xfcfb6d1ba7725c30 else { return nil }
        let length = Int(integer(bytes, offset: 12, count: 4))
        guard length > 0, length <= bytes.count - 24 else { return nil }
        return String(data: bytes.dropFirst(24).prefix(length), encoding: .utf8)
    }

    public static func isUsageKey(_ key: String) -> Bool {
        key.range(of: "/api/organizations/[0-9A-Fa-f-]+/usage$", options: .regularExpression) != nil
    }

    public static func parse(_ bytes: Data, modifiedAt: Date) -> ToolUsage? {
        guard key(in: bytes) != nil else { return nil }
        let offset = 24 + Int(integer(bytes, offset: 12, count: 4))
        let body = Data(bytes.dropFirst(offset))
        let plain: Data?
        if body.starts(with: [0x28, 0xb5, 0x2f, 0xfd]) { plain = decompress(body) } else { plain = body }
        guard let plain, let json = JSONValue.parseObject(from: plain) else { return nil }
        return UsageParser.claude(json, desktop: true, updatedAt: modifiedAt)
    }

    public static func decompress(_ bytes: Data) -> Data? {
        guard let decoder = ZSTD_createDStream() else { return nil }
        defer { ZSTD_freeDStream(decoder) }
        guard ZSTD_isError(ZSTD_initDStream(decoder)) == 0 else { return nil }
        return bytes.withUnsafeBytes { input in
            var source = ZSTD_inBuffer(src: input.baseAddress, size: input.count, pos: 0)
            var result = Data()
            var chunk = [UInt8](repeating: 0, count: ZSTD_DStreamOutSize())
            while source.pos < source.size {
                let code = chunk.withUnsafeMutableBytes { storage in
                    var destination = ZSTD_outBuffer(dst: storage.baseAddress, size: storage.count, pos: 0)
                    let code = ZSTD_decompressStream(decoder, &destination, &source)
                    result.append(contentsOf: storage.bindMemory(to: UInt8.self).prefix(destination.pos))
                    return code
                }
                guard ZSTD_isError(code) == 0, result.count <= 1_048_576 else { return nil }
                if code == 0 { return result }
            }
            return nil
        }
    }
}
