import Foundation

/// 앱이 생성한 POSIX 셸 인자만 읽는다. 임의의 셸 표현식은 해석하거나 실행하지 않는다.
enum ShellQuote {
    static func encode(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func decodePrefix(_ text: Substring) -> (value: String, rest: Substring)? {
        guard text.first == "'" else { return nil }
        var cursor = text.index(after: text.startIndex)
        var value = ""
        while cursor < text.endIndex {
            if text[cursor...].hasPrefix("'\\''") {
                value.append("'")
                cursor = text.index(cursor, offsetBy: 4)
            } else if text[cursor] == "'" {
                return (value, text[text.index(after: cursor)...])
            } else {
                value.append(text[cursor])
                cursor = text.index(after: cursor)
            }
        }
        return nil
    }

    static func decode(_ text: String) -> String? {
        guard let decoded = decodePrefix(text[...]), decoded.rest.isEmpty else { return nil }
        return decoded.value
    }
}
