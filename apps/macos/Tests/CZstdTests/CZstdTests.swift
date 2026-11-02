import CZstd
import Testing

// zstd 명령으로 "hello"를 해독해 확인한 합성 프레임: 매직, 단일 세그먼트 헤더(원문 크기 5), 원본 블록(마지막 블록, 크기 5), 본문.
private let helloFrame: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD, 0x20, 0x05, 0x29, 0x00, 0x00, 0x68, 0x65, 0x6C, 0x6C, 0x6F]

// 압축 블록을 가진 프레임이다. 아래 sampleText를 `zstd -19`로 압축한 결과이고, 압축된 리터럴과 시퀀스(FSE)를 해독하는 경로를 거친다.
// 값은 합성 데이터이며 사용자의 실제 캐시나 기록이 아니다.
private let sampleText = String(repeating: "Desktoto session panel usage cache entry. ", count: 14)
    + "five_hour used_percentage 42.5 resets_at 1760000000 seven_day used_percentage 17.0\n"
private let compressedFrame: [UInt8] = [
    0x28, 0xB5, 0x2F, 0xFD, 0x64, 0x9F, 0x01, 0xFD, 0x02, 0x00, 0x62, 0x06,
    0x14, 0x11, 0x90, 0x7D, 0x00, 0x5A, 0x94, 0x0F, 0xCD, 0xBA, 0xDC, 0xD5,
    0x89, 0xC1, 0xD4, 0xB7, 0xFB, 0xB3, 0x0E, 0x60, 0x88, 0x44, 0x3A, 0x73,
    0xAB, 0x3E, 0xFF, 0x1C, 0x06, 0x4A, 0x24, 0x68, 0xB6, 0xB2, 0xFE, 0xFC,
    0x38, 0x1C, 0x51, 0x4C, 0x78, 0xC8, 0x74, 0xFD, 0x86, 0xFF, 0x2E, 0xF7,
    0x79, 0x07, 0xBC, 0x6D, 0x5C, 0xCF, 0xE5, 0x0B, 0xA2, 0x63, 0x5D, 0x3F,
    0x7C, 0x6C, 0xAC, 0x85, 0x87, 0x2C, 0xEF, 0x40, 0xBF, 0xB2, 0x1B, 0xAA,
    0x95, 0x39, 0x7F, 0x0E, 0x56, 0x5B, 0x3D, 0xF3, 0xAB, 0x03, 0x00, 0x57,
    0x4D, 0x54, 0x17, 0x2B, 0xFA, 0xD0, 0x2A, 0xA5, 0x07, 0x62, 0x27, 0x23,
    0xCD
]

// 앞으로 사용량 읽기가 쓸 스트리밍 해독 함수들(ZSTD_createDStream 등)로 풀어 본다. 오류이면 nil이다.
private func decompress(_ source: [UInt8]) -> [UInt8]? {
    guard let stream = ZSTD_createDStream() else { return nil }
    defer { ZSTD_freeDStream(stream) }
    if ZSTD_isError(ZSTD_initDStream(stream)) != 0 { return nil }

    var output: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: ZSTD_DStreamOutSize())
    return source.withUnsafeBufferPointer { raw in
        var input = ZSTD_inBuffer(src: raw.baseAddress, size: raw.count, pos: 0)
        while true {
            var produced = 0
            let code = chunk.withUnsafeMutableBufferPointer { destination in
                var buffer = ZSTD_outBuffer(dst: destination.baseAddress, size: destination.count, pos: 0)
                let code = ZSTD_decompressStream(stream, &buffer, &input)
                produced = buffer.pos
                return code
            }
            if ZSTD_isError(code) != 0 { return nil }
            output.append(contentsOf: chunk[0..<produced])
            // 0이면 프레임을 끝까지 풀었다. 입력을 다 쓰고도 끝나지 않으면 잘린 프레임이다.
            if code == 0 { return output }
            if input.pos >= input.size && produced == 0 { return nil }
        }
    }
}

@Test func decompressesSyntheticFrame() {
    let decoded = decompress(helloFrame)
    #expect(decoded.map { String(decoding: $0, as: UTF8.self) } == "hello")
}

@Test func decompressesCompressedFrame() {
    let decoded = decompress(compressedFrame)
    #expect(decoded.map { String(decoding: $0, as: UTF8.self) } == sampleText)
}

@Test func rejectsCorruptedCompressedFrame() {
    var broken = compressedFrame
    broken[broken.count - 1] ^= 0xFF
    #expect(decompress(broken) == nil)
}

@Test func rejectsFrameWithWrongMagic() {
    var broken = helloFrame
    broken[0] = 0x00
    #expect(decompress(broken) == nil)
}

@Test func rejectsTruncatedFrame() {
    #expect(decompress(Array(helloFrame.prefix(helloFrame.count - 2))) == nil)
}
